// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The parser off the main thread (grammar 12.3, phase 4 plan 2.7). One
// long-lived isolate for the app opens the USDA file itself, builds the search
// index, keeps the user's data (the snapshot), and runs one ParseSession for
// each typed box that is open: the food entry box, and a recipe or saved meal
// editor that is typed the same way. Each box has its own text, cursor, picks
// and item cache, so two open boxes never touch each other.
//
// The main side talks to the worker through [ParseWorker] (one per app) for
// what needs no box: start, the user's data, dispose, and the questions about a
// food that is not typed (an added line, 9.3). [ParseWorker.open] gives a
// [SessionHandle] for one box: it sends the text and the cursor on every
// change, the picks and the sheet's questions, and gets back the lines, tagged
// with the number of the request that made them; it ignores any result older
// than one it has already used. [SessionHandle.close] frees the box's session.
//
// How the work is split: the sessions, with their item caches and sticky
// corrections, live on the worker side. The main side holds only request and
// box numbers. Typing therefore sends only a string and two ints, a pick sends
// a span and a food ref, and nothing the parser builds (the index, the
// snapshot, the caches) is ever copied back and forth. Requests are handled in
// the order they were sent, so each session sees its text and picks in the
// order the user made them; stale results are dropped on the main side, per
// box, where the newest request number is known.
//
// An inline worker runs the same WorkerCore on the calling isolate and gives
// each result before the call returns. Widget tests use it, because isolates
// do not run in fake time.

import 'dart:async';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'line.dart';
import 'parse_session.dart';
import 'parser.dart';
import 'search_index.dart';
import 'user_snapshot.dart';
import 'user_snapshot_data.dart';

// Messages. Plain classes of numbers, strings, lists and the parser's own
// plain types, so they cross the isolate boundary as they are.

sealed class WorkerRequest {
  const WorkerRequest(this.id);

  /// Counts up on the main side. The reply carries the same number.
  final int id;
}

/// A request for one typed box's session, numbered by [session].
sealed class SessionRequest extends WorkerRequest {
  const SessionRequest(super.id, this.session);
  final int session;
}

/// Opens a session with the worker's current user data. No reply.
class OpenRequest extends SessionRequest {
  const OpenRequest(super.id, super.session);
}

/// Frees a session. No reply.
class CloseRequest extends SessionRequest {
  const CloseRequest(super.id, super.session);
}

/// New text and cursor. Answered with a [ParseResult].
class TextRequest extends SessionRequest {
  const TextRequest(super.id, super.session, this.text, this.cursor);
  final String text;
  final int cursor;
}

/// A pick for the typed line with this span. [text] is the text the span came
/// from: if the session's text is not that, nothing is done. Answered with an
/// [ActionResult].
class PickRequest extends SessionRequest {
  const PickRequest(
    super.id,
    super.session,
    this.text,
    this.line,
    this.foodRef,
    this.marker,
  );
  final String text;
  final Span line;
  final String foodRef;
  final Marker marker;
}

/// Drops the pick of the line with this span, for the same [text] rule.
/// Answered with an [ActionResult].
class ClearPickRequest extends SessionRequest {
  const ClearPickRequest(super.id, super.session, this.text, this.line);
  final String text;
  final Span line;
}

/// The correction sheet's candidates for a line, for the same [text] rule (a
/// text that is not the session's gives none). Answered with an
/// [AlternativesResult].
class AlternativesRequest extends SessionRequest {
  const AlternativesRequest(super.id, super.session, this.text, this.line);
  final String text;
  final Span line;
}

/// The correction sheet's search box for a typed line: the energy of each
/// food is worked out for the line's amount, or left out when [text] is not
/// the session's text. Answered with a [SearchResult].
class LineSearchRequest extends SessionRequest {
  const LineSearchRequest(
    super.id,
    super.session,
    this.query,
    this.text,
    this.line,
  );
  final String query;
  final String text;
  final Span line;
}

/// The unit picker for a line (8.3), for the same [text] rule. Answered with a
/// [UnitChoicesResult].
class UnitChoicesRequest extends SessionRequest {
  const UnitChoicesRequest(super.id, super.session, this.text, this.line);
  final String text;
  final Span line;
}

/// Rewrites the amount of a line in [text] (see
/// [ParseSession.rewriteAmount]). Answered with an [EditResult].
class RewriteRequest extends SessionRequest {
  const RewriteRequest(
    super.id,
    super.session,
    this.text,
    this.cursor,
    this.line,
    this.quantity,
    this.unit,
  );
  final String text;
  final int cursor;
  final Span line;
  final double quantity;
  final String unit;
}

/// Removes a line's item from [text] (see [ParseSession.removeItem]).
/// Answered with an [EditResult].
class RemoveRequest extends SessionRequest {
  const RemoveRequest(
    super.id,
    super.session,
    this.text,
    this.cursor,
    this.line,
  );
  final String text;
  final int cursor;
  final Span line;
}

/// New user data. Every open session parses its text again. Answered with a
/// [SnapshotResult].
class SnapshotRequest extends WorkerRequest {
  const SnapshotRequest(super.id, this.data);
  final UserSnapshotData data;
}

/// The search box for a line that is not typed (no energy). Answered with a
/// [SearchResult].
class SearchRequest extends WorkerRequest {
  const SearchRequest(super.id, this.query);
  final String query;
}

/// The line for a food added without typing (see [foodLineFor]). Answered
/// with a [FoodLineResult].
class FoodLineRequest extends WorkerRequest {
  const FoodLineRequest(super.id, this.foodRef, this.quantity, this.unit);
  final String foodRef;
  final double? quantity;
  final String unit;
}

/// The unit picker for a food that is not typed (see [unitChoicesForFood]).
/// Answered with a [UnitChoicesResult].
class FoodUnitChoicesRequest extends WorkerRequest {
  const FoodUnitChoicesRequest(super.id, this.foodRef);
  final String foodRef;
}

sealed class WorkerReply {
  const WorkerReply();
}

/// The index is built and the worker answers requests.
class ReadyReply extends WorkerReply {
  const ReadyReply();
}

/// The lines of [session] for the newest text, picks and user data it had when
/// the worker answered request [id].
class ParseResult extends WorkerReply {
  const ParseResult(
    this.id,
    this.session,
    this.text,
    this.cursor,
    this.snapshotVersion,
    this.lines,
  );

  final int id;
  final int session;

  /// The text and cursor the lines are for.
  final String text;
  final int cursor;
  final int snapshotVersion;
  final List<Line> lines;
}

/// The answer to new user data: a result for each open session that parsed
/// with it, and a failure for each one that could not (it keeps its old data).
class SnapshotResult extends WorkerReply {
  const SnapshotResult(this.id, this.version, this.results, this.failures);
  final int id;
  final int version;
  final List<ParseResult> results;
  final List<WorkerFailure> failures;
}

/// The answer to a pick or a clear: whether it was done, and the lines after.
class ActionResult extends WorkerReply {
  const ActionResult(this.id, this.applied, this.result);
  final int id;
  final bool applied;
  final ParseResult result;
}

class UnitChoicesResult extends WorkerReply {
  const UnitChoicesResult(this.id, this.choices);
  final int id;
  final List<UnitChoice> choices;
}

/// The new text and cursor of a sheet edit; [text] is null when it was
/// refused.
class EditResult extends WorkerReply {
  const EditResult(this.id, this.text, this.cursor);
  final int id;
  final String? text;
  final int cursor;
}

class FoodLineResult extends WorkerReply {
  const FoodLineResult(this.id, this.line);
  final int id;
  final Line? line;
}

class AlternativesResult extends WorkerReply {
  const AlternativesResult(this.id, this.alternatives);
  final int id;
  final Alternatives alternatives;
}

class SearchResult extends WorkerReply {
  const SearchResult(this.id, this.choices);
  final int id;
  final List<FoodChoice> choices;
}

enum FailureKind {
  /// The USDA file could not be opened or read, or the worker could not start.
  /// The worker is not running.
  startup,

  /// One request failed. The worker is still running.
  request,

  /// The worker stopped by itself.
  crashed,

  /// The typed box was closed before the answer came. Nothing went wrong.
  closed,
}

/// Something went wrong in the worker. It holds no user text: [errorType] is
/// the name of the Dart error class, never its message.
class WorkerFailure extends WorkerReply implements Exception {
  const WorkerFailure(this.id, this.kind, this.errorType, {this.session = 0});

  /// The request that failed, or 0 when none.
  final int id;
  final FailureKind kind;
  final String errorType;

  /// The typed box it belongs to, or 0 for the worker itself.
  final int session;

  @override
  String toString() => 'WorkerFailure($kind, $errorType, request $id)';
}

/// The worker's side: a parser, the user's data, a session per open typed box,
/// and the answer to each request. Used by the isolate and by the inline
/// worker, so both give the same results.
class WorkerCore {
  WorkerCore(this.parser, {this.database, this.loader});

  /// Opens the USDA file at [path] and builds the index.
  factory WorkerCore.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final index = SearchIndex.build(readUsdaFoods(db));
      final loader = SqliteUsdaFoods(db);
      return WorkerCore(
        Parser(index, loader.call),
        database: db,
        loader: loader,
      );
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  final Parser parser;

  /// What [close] releases, when the core opened them.
  final Database? database;
  final SqliteUsdaFoods? loader;

  UserSnapshot _snapshot = UserSnapshot.empty;
  final _sessions = <int, ParseSession>{};

  /// The user's data now.
  UserSnapshot get snapshot => _snapshot;

  /// How many sessions are open.
  int get sessionCount => _sessions.length;

  /// Answers one request, or null for a request that has no answer (open and
  /// close). A failure inside is returned as a [WorkerFailure] with no user
  /// text; the session stays as it was.
  WorkerReply? handle(WorkerRequest r) {
    try {
      switch (r) {
        case OpenRequest():
          _sessions[r.session] = ParseSession(parser, snapshot: _snapshot);
          return null;
        case CloseRequest():
          _sessions.remove(r.session);
          return null;
        case TextRequest():
          final s = _session(r)..setText(r.text, r.cursor);
          return _result(r.id, r.session, s);
        case PickRequest():
          final s = _session(r);
          final ok =
              s.text == r.text &&
              s.pickFood(r.line, r.foodRef, marker: r.marker);
          return ActionResult(r.id, ok, _result(r.id, r.session, s));
        case ClearPickRequest():
          final s = _session(r);
          final ok = s.text == r.text && s.clearPick(r.line);
          return ActionResult(r.id, ok, _result(r.id, r.session, s));
        case AlternativesRequest():
          final s = _session(r);
          return AlternativesResult(
            r.id,
            s.text == r.text ? s.alternatives(r.line) : Alternatives.none,
          );
        case LineSearchRequest():
          final s = _session(r);
          return SearchResult(
            r.id,
            s.search(r.query, forLine: s.text == r.text ? r.line : null),
          );
        case UnitChoicesRequest():
          final s = _session(r);
          return UnitChoicesResult(
            r.id,
            s.text == r.text ? s.unitChoices(r.line) : const [],
          );
        case RewriteRequest():
          final out = _session(r).rewriteAmount(
            r.text,
            r.cursor,
            r.line,
            quantity: r.quantity,
            unit: r.unit,
          );
          return EditResult(r.id, out?.text, out?.cursor ?? r.cursor);
        case RemoveRequest():
          final out = _session(r).removeItem(r.text, r.cursor, r.line);
          return EditResult(r.id, out?.text, out?.cursor ?? r.cursor);
        case SnapshotRequest():
          final next = UserSnapshot.from(r.data);
          _snapshot = next;
          final results = <ParseResult>[];
          final failures = <WorkerFailure>[];
          for (final MapEntry(key: id, value: s) in _sessions.entries) {
            try {
              s.setSnapshot(next);
              results.add(_result(r.id, id, s));
            } catch (e) {
              failures.add(_failure(r.id, e, id));
            }
          }
          return SnapshotResult(r.id, next.version, results, failures);
        case SearchRequest():
          return SearchResult(r.id, [
            for (final c in parser.rankerFor(_snapshot).search(r.query))
              FoodChoice(c.ref, c.description, c.food.dataset, null),
          ]);
        case FoodLineRequest():
          return FoodLineResult(
            r.id,
            foodLineFor(
              parser,
              _snapshot,
              r.foodRef,
              quantity: r.quantity,
              unit: r.unit,
            ),
          );
        case FoodUnitChoicesRequest():
          return UnitChoicesResult(
            r.id,
            unitChoicesForFood(parser, _snapshot, r.foodRef),
          );
      }
    } catch (e) {
      return _failure(r.id, e, r is SessionRequest ? r.session : 0);
    }
  }

  ParseSession _session(SessionRequest r) =>
      _sessions[r.session] ?? (throw StateError('no such session'));

  static WorkerFailure _failure(int id, Object e, int session) => WorkerFailure(
    id,
    FailureKind.request,
    e.runtimeType.toString(),
    session: session,
  );

  static ParseResult _result(int id, int session, ParseSession s) =>
      ParseResult(id, session, s.text, s.cursor, s.snapshot.version, s.lines);

  /// Releases the loader's statements, then closes the database. The order
  /// matters on Windows.
  void close() {
    _sessions.clear();
    loader?.dispose();
    database?.close();
  }
}

/// How the main side reaches the worker. The isolate and the inline worker
/// each have one; a test can give its own to control when replies arrive.
abstract class WorkerLink {
  /// Starts the worker. Replies, [ReadyReply] first, go to [onReply].
  void start(void Function(WorkerReply reply) onReply);

  /// Sends a request. Called only after [start]; the worker answers it once it
  /// is ready.
  void send(WorkerRequest request);

  /// Stops the worker. Completes when it has stopped.
  Future<void> close();
}

/// The main side's handle on the worker. One for the app: it holds the index
/// and the user's data for every typed box ([open]).
class ParseWorker {
  /// A worker in its own isolate. Nothing runs until [start]. [killAfter] is how
  /// long [dispose] waits for the worker to close its database and exit before
  /// it stops the isolate.
  ParseWorker.isolate(
    String usdaPath, {
    Duration killAfter = const Duration(seconds: 3),
  }) : _link = _IsolateLink(usdaPath, killAfter);

  /// A worker on the calling isolate, for widget tests. [start] opens the
  /// file and builds the index at once, and every result is given before the
  /// call that asked for it returns.
  ParseWorker.inline(String usdaPath) : _link = _InlineLink(usdaPath, null);

  /// An inline worker over a parser already built.
  ParseWorker.inlineWith(Parser parser) : _link = _InlineLink(null, parser);

  /// A worker reached through [link].
  ParseWorker.linked(WorkerLink link) : _link = link;

  final WorkerLink _link;
  final _ready = Completer<bool>();
  final _pending = <int, (Completer<WorkerReply>, SessionHandle?)>{};
  final _beforeStart = <WorkerRequest>[];
  final _open = <int, SessionHandle>{};
  var _nextId = 1;
  var _nextSession = 1;
  var _started = false;
  var _isReady = false;
  var _stopped = false;
  WorkerFailure? _dead;

  /// Called with every failure that belongs to no typed box and is not the
  /// answer to a question with its own future: new user data that could not be
  /// read, and the worker failing to start or stopping by itself (every open
  /// box hears of those too). Holds no user text.
  void Function(WorkerFailure failure)? onFailure;

  /// True once the index is built.
  bool get isReady => _isReady;

  /// True after [dispose], or after the worker stopped.
  bool get isStopped => _stopped;

  /// Starts the worker, off the first frame's critical path: the call returns
  /// at once and the future completes with true when the index is built, or
  /// with false when it could not be (the failure goes to [onFailure]).
  /// Requests sent before it is ready, or before this call, are answered once
  /// it is.
  Future<bool> start() {
    if (_started || _stopped) return _ready.future;
    _started = true;
    _link.start(_receive);
    for (final r in _beforeStart) {
      if (_dead == null) _link.send(r);
    }
    _beforeStart.clear();
    return _ready.future;
  }

  /// The user's data changed. Every open box's text is parsed again, and each
  /// gets its result. Returns the request number.
  int setSnapshot(UserSnapshotData data) =>
      _send((id) => SnapshotRequest(id, data));

  /// Opens a session for one typed box, with the user's data as the worker has
  /// it. Results and failures for the box go to [onResult] and [onFailure]
  /// (they can also be set on the handle). Close it when the box goes away.
  SessionHandle open({
    void Function(ParseResult result)? onResult,
    void Function(WorkerFailure failure)? onFailure,
  }) {
    final h = SessionHandle._(this, _nextSession++)
      ..onResult = onResult
      ..onFailure = onFailure;
    if (_stopped || _dead != null) {
      h._shut();
      return h;
    }
    _open[h.id] = h;
    _send((id) => OpenRequest(id, h.id));
    return h;
  }

  /// The search box for a line that is not typed (5.7), with no energy. Fails
  /// with a [WorkerFailure].
  Future<List<FoodChoice>> search(String query) async {
    final r = await _ask((id) => SearchRequest(id, query));
    return (r as SearchResult).choices;
  }

  /// The line for a food added without typing (9.3; see [foodLineFor]), or
  /// null.
  Future<Line?> foodLine(
    String foodRef, {
    double? quantity,
    String unit = '',
  }) async {
    final r = await _ask((id) => FoodLineRequest(id, foodRef, quantity, unit));
    return (r as FoodLineResult).line;
  }

  /// The unit picker for a food that is not typed (9.3; see
  /// [unitChoicesForFood]).
  Future<List<UnitChoice>> unitChoicesForFood(String foodRef) async {
    final r = await _ask((id) => FoodUnitChoicesRequest(id, foodRef));
    return (r as UnitChoicesResult).choices;
  }

  /// Stops the worker and completes when it has stopped. Every open box is
  /// closed, and futures still waiting for an answer fail. Nothing reaches any
  /// onResult or onFailure after the call.
  Future<void> dispose() async {
    if (_stopped) return;
    _stopped = true;
    _isReady = false;
    for (final h in _open.values) {
      h._shut();
    }
    _open.clear();
    _fail(const WorkerFailure(0, FailureKind.crashed, 'disposed'));
    if (!_ready.isCompleted) _ready.complete(false);
    if (_started) await _link.close();
  }

  int _send(WorkerRequest Function(int id) make, [SessionHandle? box]) =>
      _post(make, null, box);

  int _post(
    WorkerRequest Function(int id) make,
    Completer<WorkerReply>? waiting,
    SessionHandle? box,
  ) {
    final id = _nextId++;
    // A stopped or dead worker, or a closed box, answers nothing.
    if (_stopped || _dead != null || (box != null && box._closed)) return id;
    // Registered before sending: an inline worker answers inside the call.
    if (waiting != null) _pending[id] = (waiting, box);
    final r = make(id);
    if (_started) {
      _link.send(r);
    } else {
      _beforeStart.add(r);
    }
    return id;
  }

  Future<WorkerReply> _ask(
    WorkerRequest Function(int id) make, [
    SessionHandle? box,
  ]) {
    if (_stopped) {
      return Future.error(
        const WorkerFailure(0, FailureKind.crashed, 'stopped'),
      );
    }
    final dead = _dead;
    if (dead != null) return Future.error(dead);
    if (box != null && box._closed) {
      return Future.error(
        WorkerFailure(0, FailureKind.closed, 'closed', session: box.id),
      );
    }
    final c = Completer<WorkerReply>();
    _post(make, c, box);
    return c.future;
  }

  void _close(SessionHandle box) {
    if (_open.remove(box.id) == null) return;
    final waiting = [
      for (final MapEntry(key: id, value: (_, b)) in _pending.entries)
        if (identical(b, box)) id,
    ];
    final f = WorkerFailure(0, FailureKind.closed, 'closed', session: box.id);
    for (final id in waiting) {
      _pending.remove(id)!.$1.completeError(f);
    }
    _send((id) => CloseRequest(id, box.id));
  }

  void _fail(WorkerFailure f) {
    final waiting = [..._pending.values];
    _pending.clear();
    for (final (c, _) in waiting) {
      c.completeError(f);
    }
  }

  void _answer(int id, WorkerReply reply) =>
      _pending.remove(id)?.$1.complete(reply);

  void _receive(WorkerReply reply) {
    // After dispose nothing is passed on: the screens may be gone.
    if (_stopped) return;
    switch (reply) {
      case ReadyReply():
        _isReady = true;
        if (!_ready.isCompleted) _ready.complete(true);
      case ParseResult():
        _open[reply.session]?._apply(reply);
      case SnapshotResult():
        for (final r in reply.results) {
          _open[r.session]?._apply(r);
        }
        for (final f in reply.failures) {
          _open[f.session]?.onFailure?.call(f);
        }
      case ActionResult():
        _open[reply.result.session]?._apply(reply.result);
        _answer(reply.id, reply);
      case AlternativesResult():
        _answer(reply.id, reply);
      case SearchResult():
        _answer(reply.id, reply);
      case UnitChoicesResult():
        _answer(reply.id, reply);
      case EditResult():
        _answer(reply.id, reply);
      case FoodLineResult():
        _answer(reply.id, reply);
      case WorkerFailure():
        if (reply.kind != FailureKind.request) {
          // The worker is not running: every later ask fails at once.
          _dead = reply;
          _isReady = false;
          if (!_ready.isCompleted) _ready.complete(false);
          _fail(reply);
          onFailure?.call(reply);
          for (final h in [..._open.values]) {
            h.onFailure?.call(reply);
          }
        } else if (_pending.containsKey(reply.id)) {
          _pending.remove(reply.id)!.$1.completeError(reply);
        } else if (reply.session != 0) {
          _open[reply.session]?.onFailure?.call(reply);
        } else {
          onFailure?.call(reply);
        }
    }
  }
}

/// One typed box's session in the worker (from [ParseWorker.open]): the text,
/// the cursor, the picks and the correction sheet's questions for that box.
/// Every question that takes a [Span] also takes the text the span came from;
/// when the box's text has moved on, the answer is empty, false or null.
class SessionHandle {
  SessionHandle._(this._worker, this.id);

  final ParseWorker _worker;

  /// The box's number in the worker.
  final int id;

  /// Called with each result for this box that is newer than every result
  /// used before it.
  void Function(ParseResult result)? onResult;

  /// Called with every failure of this box that is not the answer to a
  /// question with its own future, and when the worker stops. Holds no user
  /// text.
  void Function(WorkerFailure failure)? onFailure;

  var _newest = 0;
  var _dropped = 0;
  var _closed = false;

  /// True after [close], or after the worker was disposed.
  bool get isClosed => _closed;

  /// How many results were ignored because a newer one had been used.
  int get droppedResults => _dropped;

  /// The text and cursor changed. Returns the request number.
  int setText(String text, int cursor) =>
      _worker._send((r) => TextRequest(r, id, text, cursor), this);

  /// Picks a food for the typed line with this span, which came from [text]
  /// (see [ParseSession.pickFood]). Completes with false, and changes nothing,
  /// when the box's text is no longer [text], when there is no such line, or
  /// when the food is unknown (if it is a new local food, send the snapshot
  /// that holds it first). The lines after it also arrive through [onResult].
  ///
  /// A `Future<bool>` rather than a flag on the result, because the result can
  /// be dropped as stale or replaced by a newer one, and the caller needs its
  /// own answer.
  Future<bool> pick(
    String text,
    Span line,
    String foodRef, {
    Marker marker = Marker.yourPick,
  }) async {
    final r = await _worker._ask(
      (n) => PickRequest(n, id, text, line, foodRef, marker),
      this,
    );
    return (r as ActionResult).applied;
  }

  /// Drops the pick of a line, suspended or not, the same way as [pick].
  Future<bool> clearPick(String text, Span line) async {
    final r = await _worker._ask(
      (n) => ClearPickRequest(n, id, text, line),
      this,
    );
    return (r as ActionResult).applied;
  }

  /// The sheet's candidates for a line of [text]. Empty when the box's text is
  /// no longer [text]. Fails with a [WorkerFailure].
  Future<Alternatives> alternatives(String text, Span line) async {
    final r = await _worker._ask(
      (n) => AlternativesRequest(n, id, text, line),
      this,
    );
    return (r as AlternativesResult).alternatives;
  }

  /// The sheet's search box for a line of [text]: the energy of each food is
  /// worked out for that line's amount, or left out when the box's text is no
  /// longer [text]. Fails with a [WorkerFailure].
  Future<List<FoodChoice>> search(String query, String text, Span line) async {
    final r = await _worker._ask(
      (n) => LineSearchRequest(n, id, query, text, line),
      this,
    );
    return (r as SearchResult).choices;
  }

  /// The unit picker for a line of [text] (8.3; see
  /// [ParseSession.unitChoices]).
  Future<List<UnitChoice>> unitChoices(String text, Span line) async {
    final r = await _worker._ask(
      (n) => UnitChoicesRequest(n, id, text, line),
      this,
    );
    return (r as UnitChoicesResult).choices;
  }

  /// The new text for a changed amount, or for a saved meal header's new
  /// multiplier (see [ParseSession.rewriteAmount]), or null when it is
  /// refused. The box's text is not changed: the screen puts the text in the
  /// field and the usual [setText] follows, which carries the picks through
  /// this exact change.
  Future<({String text, int cursor})?> rewriteAmount(
    String text,
    int cursor,
    Span line, {
    required double quantity,
    String unit = '',
  }) async {
    final r = await _worker._ask(
      (n) => RewriteRequest(n, id, text, cursor, line, quantity, unit),
      this,
    );
    return _edited(r as EditResult);
  }

  /// "Remove from meal" for a typed line (see [ParseSession.removeItem]): the
  /// new text and cursor, or null when the item cannot be removed cleanly.
  /// Like [rewriteAmount], the screen sets the text and [setText] follows.
  Future<({String text, int cursor})?> removeItem(
    String text,
    int cursor,
    Span line,
  ) async {
    final r = await _worker._ask(
      (n) => RemoveRequest(n, id, text, cursor, line),
      this,
    );
    return _edited(r as EditResult);
  }

  /// Frees the box's session in the worker. Nothing reaches [onResult] or
  /// [onFailure] after the call; questions still waiting fail with a
  /// [WorkerFailure] of kind [FailureKind.closed]. Closing twice is fine.
  void close() {
    if (_closed) return;
    _shut();
    _worker._close(this);
  }

  static ({String text, int cursor})? _edited(EditResult r) {
    final t = r.text;
    return t == null ? null : (text: t, cursor: r.cursor);
  }

  void _shut() {
    _closed = true;
    onResult = null;
    onFailure = null;
  }

  // A result older than one already used is dropped, so a slow answer never
  // replaces a newer one.
  void _apply(ParseResult r) {
    if (_closed) return;
    if (r.id > _newest) {
      _newest = r.id;
      onResult?.call(r);
    } else {
      _dropped++;
    }
  }
}

// Inline.

class _InlineLink implements WorkerLink {
  _InlineLink(this._path, this._parser);

  final String? _path;
  final Parser? _parser;
  WorkerCore? _core;
  void Function(WorkerReply)? _onReply;

  @override
  void start(void Function(WorkerReply reply) onReply) {
    _onReply = onReply;
    try {
      _core = _parser != null ? WorkerCore(_parser) : WorkerCore.open(_path!);
    } catch (e) {
      onReply(WorkerFailure(0, FailureKind.startup, e.runtimeType.toString()));
      return;
    }
    onReply(const ReadyReply());
  }

  @override
  void send(WorkerRequest request) {
    final reply = _core?.handle(request);
    if (reply != null) _onReply!(reply);
  }

  @override
  Future<void> close() async {
    _core?.close();
    _core = null;
  }
}

// Isolate.

const _shutdown = 'shutdown';

class _IsolateLink implements WorkerLink {
  _IsolateLink(this._path, this._killAfter);

  final String _path;
  final Duration _killAfter;
  final _early = <WorkerRequest>[];
  final _exited = Completer<void>();
  final _portArrived = Completer<void>();
  ReceivePort? _in;
  SendPort? _worker;
  Future<Isolate?>? _spawn;
  var _closing = false;
  var _reportedStop = false;

  @override
  void start(void Function(WorkerReply reply) onReply) {
    final port = ReceivePort();
    _in = port;
    port.listen((Object? m) {
      if (m is SendPort) {
        _worker = m;
        if (!_portArrived.isCompleted) _portArrived.complete();
        for (final r in _early) {
          m.send(r);
        }
        _early.clear();
      } else if (m is WorkerReply) {
        if (m is WorkerFailure && m.kind == FailureKind.startup) {
          _reportedStop = true;
        }
        onReply(m);
      } else if (m == null) {
        // The isolate exited.
        port.close();
        if (!_exited.isCompleted) _exited.complete();
        if (!_closing && !_reportedStop) {
          _reportedStop = true;
          onReply(const WorkerFailure(0, FailureKind.crashed, 'exited'));
        }
      } else if (!_closing && !_reportedStop) {
        // An error nobody caught: [message, stack]. The text is not passed on.
        _reportedStop = true;
        onReply(const WorkerFailure(0, FailureKind.crashed, 'uncaught'));
      }
    });
    _spawn =
        Isolate.spawn<(SendPort, String)>(
          _workerMain,
          (port.sendPort, _path),
          onError: port.sendPort,
          onExit: port.sendPort,
        ).then<Isolate?>(
          (i) => i,
          onError: (Object e) {
            port.close();
            if (!_exited.isCompleted) _exited.complete();
            _reportedStop = true;
            onReply(
              WorkerFailure(0, FailureKind.startup, e.runtimeType.toString()),
            );
            return null;
          },
        );
  }

  @override
  void send(WorkerRequest request) {
    final w = _worker;
    if (w == null) {
      _early.add(request);
    } else {
      w.send(request);
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    final isolate = await _spawn;
    // The worker sends its port first thing; wait for it, so that the
    // shutdown can reach it and the database is closed properly.
    await Future.any([_portArrived.future, _exited.future]);
    final w = _worker;
    if (w != null) {
      // Even while the index is still being built: the message waits in the
      // worker's inbox, and the worker then closes its database properly. The
      // timeout below stops it if that takes too long.
      w.send(_shutdown);
    } else {
      isolate?.kill(priority: Isolate.immediate);
    }
    await _exited.future.timeout(
      _killAfter,
      onTimeout: () {
        isolate?.kill(priority: Isolate.immediate);
        _in?.close();
      },
    );
  }
}

// The isolate's main function.
void _workerMain((SendPort, String) args) {
  final (toMain, path) = args;
  final inbox = ReceivePort();
  // The main side can send from now on; what it sends waits in the inbox
  // while the index is built.
  toMain.send(inbox.sendPort);
  final WorkerCore core;
  try {
    core = WorkerCore.open(path);
  } catch (e) {
    toMain.send(
      WorkerFailure(0, FailureKind.startup, e.runtimeType.toString()),
    );
    inbox.close();
    return;
  }
  toMain.send(const ReadyReply());
  inbox.listen((Object? m) {
    if (m is WorkerRequest) {
      final reply = core.handle(m);
      if (reply != null) toMain.send(reply);
    } else if (m == _shutdown) {
      core.close();
      inbox.close();
    }
  });
}
