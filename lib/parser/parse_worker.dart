// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The parser off the main thread (grammar 12.3, phase 4 plan 2.7). A long-lived
// isolate opens the USDA file itself, builds the search index, and then runs
// one ParseSession for the open food entry screen. The main side sends the
// text and the cursor on every change, and a snapshot of the user's data when
// it changes; it gets back the lines, tagged with the number of the request
// that made them, and ignores any result older than one it has already used.
//
// How the work is split: the whole session, with its item cache and its sticky
// corrections, lives on the worker side. The main side holds only the request
// counter. Typing therefore sends only a string and an int, a pick sends a span
// and a food ref, and nothing the parser builds (the index, the snapshot, the
// cache) is ever copied back and forth. A request is handled in the order it
// was sent, so the session always sees the text and the picks in the order the
// user made them; stale results are dropped on the main side, where the
// newest request number is known.
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

/// New text and cursor. Answered with a [ParseResult].
class TextRequest extends WorkerRequest {
  const TextRequest(super.id, this.text, this.cursor);
  final String text;
  final int cursor;
}

/// New user data. The worker parses the current text again and answers with a
/// [ParseResult].
class SnapshotRequest extends WorkerRequest {
  const SnapshotRequest(super.id, this.data);
  final UserSnapshotData data;
}

/// A pick for the typed line with this span. Answered with a [ParseResult].
class PickRequest extends WorkerRequest {
  const PickRequest(super.id, this.line, this.foodRef, this.marker);
  final Span line;
  final String foodRef;
  final Marker marker;
}

/// Drops the pick of the line with this span. Answered with a [ParseResult].
class ClearPickRequest extends WorkerRequest {
  const ClearPickRequest(super.id, this.line);
  final Span line;
}

/// The correction sheet's candidates for a line. Answered with an
/// [AlternativesResult].
class AlternativesRequest extends WorkerRequest {
  const AlternativesRequest(super.id, this.line);
  final Span line;
}

/// The correction sheet's search box. Answered with a [SearchResult].
class SearchRequest extends WorkerRequest {
  const SearchRequest(super.id, this.text, this.forLine);
  final String text;
  final Span? forLine;
}

sealed class WorkerReply {
  const WorkerReply();
}

/// The index is built and the worker answers requests.
class ReadyReply extends WorkerReply {
  const ReadyReply();
}

/// The lines for the newest text, picks and snapshot the worker had when it
/// answered request [id].
class ParseResult extends WorkerReply {
  const ParseResult(
    this.id,
    this.text,
    this.cursor,
    this.snapshotVersion,
    this.lines,
  );

  final int id;

  /// The text and cursor the lines are for.
  final String text;
  final int cursor;
  final int snapshotVersion;
  final List<Line> lines;
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
}

/// Something went wrong in the worker. It holds no user text: [errorType] is
/// the name of the Dart error class, never its message.
class WorkerFailure extends WorkerReply implements Exception {
  const WorkerFailure(this.id, this.kind, this.errorType);

  /// The request that failed, or 0 when none.
  final int id;
  final FailureKind kind;
  final String errorType;

  @override
  String toString() => 'WorkerFailure($kind, $errorType, request $id)';
}

/// The worker's side: a parser, a session, and the answer to each request. Used
/// by the isolate and by the inline worker, so both give the same results.
class WorkerCore {
  WorkerCore(Parser parser, {Database? database})
    : _db = database,
      session = ParseSession(parser);

  /// Opens the USDA file at [path] and builds the index.
  factory WorkerCore.open(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final index = SearchIndex.build(readUsdaFoods(db));
      return WorkerCore(Parser(index, sqliteUsdaFoods(db)), database: db);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  final ParseSession session;
  final Database? _db;

  /// Answers one request. A failure inside is returned as a [WorkerFailure]
  /// with no user text; the session stays as it was.
  WorkerReply handle(WorkerRequest r) {
    try {
      switch (r) {
        case TextRequest():
          session.setText(r.text, r.cursor);
          return _result(r.id);
        case SnapshotRequest():
          session.setSnapshot(UserSnapshot.from(r.data));
          return _result(r.id);
        case PickRequest():
          session.pickFood(r.line, r.foodRef, marker: r.marker);
          return _result(r.id);
        case ClearPickRequest():
          session.clearPick(r.line);
          return _result(r.id);
        case AlternativesRequest():
          return AlternativesResult(r.id, session.alternatives(r.line));
        case SearchRequest():
          return SearchResult(r.id, session.search(r.text, forLine: r.forLine));
      }
    } catch (e) {
      return WorkerFailure(r.id, FailureKind.request, e.runtimeType.toString());
    }
  }

  ParseResult _result(int id) => ParseResult(
    id,
    session.text,
    session.cursor,
    session.snapshot.version,
    session.lines,
  );

  void close() => _db?.close();
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

/// The main side's handle on the worker. One per open food entry screen, or
/// one for the app.
class ParseWorker {
  /// A worker in its own isolate. Nothing runs until [start].
  ParseWorker.isolate(String usdaPath) : _link = _IsolateLink(usdaPath);

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
  final _pending = <int, Completer<WorkerReply>>{};
  final _beforeStart = <WorkerRequest>[];
  var _nextId = 1;
  var _newest = 0;
  var _started = false;
  var _isReady = false;
  var _stopped = false;
  var _dropped = 0;

  /// Called with each result that is newer than every result used before it.
  void Function(ParseResult result)? onResult;

  /// Called with every failure that is not the answer to [alternatives] or
  /// [search] (those fail their own future). Holds no user text.
  void Function(WorkerFailure failure)? onFailure;

  /// True once the index is built.
  bool get isReady => _isReady;

  /// True after [dispose], or after the worker stopped.
  bool get isStopped => _stopped;

  /// How many results were ignored because a newer one had been used.
  int get droppedResults => _dropped;

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
      _link.send(r);
    }
    _beforeStart.clear();
    return _ready.future;
  }

  /// The text and cursor changed. Returns the request number.
  int setText(String text, int cursor) =>
      _send((id) => TextRequest(id, text, cursor));

  /// The user's data changed. The current text is parsed again.
  int setSnapshot(UserSnapshotData data) =>
      _send((id) => SnapshotRequest(id, data));

  /// Picks a food for the typed line with this span (see
  /// [ParseSession.pickFood]). If the food is a new local one, send the
  /// snapshot that holds it first.
  int pick(Span line, String foodRef, {Marker marker = Marker.yourPick}) =>
      _send((id) => PickRequest(id, line, foodRef, marker));

  int clearPick(Span line) => _send((id) => ClearPickRequest(id, line));

  /// The sheet's candidates for a line. Fails with a [WorkerFailure].
  Future<Alternatives> alternatives(Span line) async {
    final r = await _ask((id) => AlternativesRequest(id, line));
    return (r as AlternativesResult).alternatives;
  }

  /// The sheet's search box. Fails with a [WorkerFailure].
  Future<List<FoodChoice>> search(String text, {Span? forLine}) async {
    final r = await _ask((id) => SearchRequest(id, text, forLine));
    return (r as SearchResult).choices;
  }

  /// Stops the worker and completes when it has stopped. Futures still waiting
  /// for an answer fail.
  Future<void> dispose() async {
    if (_stopped) return;
    _stopped = true;
    _isReady = false;
    _fail(const WorkerFailure(0, FailureKind.crashed, 'disposed'));
    if (!_ready.isCompleted) _ready.complete(false);
    if (_started) await _link.close();
  }

  int _send(
    WorkerRequest Function(int id) make, [
    Completer<WorkerReply>? waiting,
  ]) {
    final id = _nextId++;
    if (_stopped) return id;
    // Registered before sending: an inline worker answers inside the call.
    if (waiting != null) _pending[id] = waiting;
    final r = make(id);
    if (_started) {
      _link.send(r);
    } else {
      _beforeStart.add(r);
    }
    return id;
  }

  Future<WorkerReply> _ask(WorkerRequest Function(int id) make) {
    if (_stopped) {
      return Future.error(
        const WorkerFailure(0, FailureKind.crashed, 'stopped'),
      );
    }
    final c = Completer<WorkerReply>();
    _send(make, c);
    return c.future;
  }

  void _fail(WorkerFailure f) {
    final waiting = [..._pending.values];
    _pending.clear();
    for (final c in waiting) {
      c.completeError(f);
    }
  }

  void _receive(WorkerReply reply) {
    switch (reply) {
      case ReadyReply():
        _isReady = true;
        if (!_ready.isCompleted) _ready.complete(true);
      case ParseResult():
        // A result older than one already used is dropped, so a slow answer
        // never replaces a newer one.
        if (reply.id > _newest) {
          _newest = reply.id;
          onResult?.call(reply);
        } else {
          _dropped++;
        }
      case AlternativesResult():
        _pending.remove(reply.id)?.complete(reply);
      case SearchResult():
        _pending.remove(reply.id)?.complete(reply);
      case WorkerFailure():
        if (reply.kind != FailureKind.request) {
          _isReady = false;
          if (!_ready.isCompleted) _ready.complete(false);
          _fail(reply);
        } else if (_pending.containsKey(reply.id)) {
          _pending.remove(reply.id)!.completeError(reply);
          return;
        }
        if (!_stopped) onFailure?.call(reply);
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
    final core = _core;
    if (core != null) _onReply!(core.handle(request));
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
  _IsolateLink(this._path);

  final String _path;
  final _early = <WorkerRequest>[];
  final _exited = Completer<void>();
  ReceivePort? _in;
  SendPort? _worker;
  Future<Isolate?>? _spawn;
  var _isReady = false;
  var _closing = false;
  var _reportedStop = false;

  @override
  void start(void Function(WorkerReply reply) onReply) {
    final port = ReceivePort();
    _in = port;
    port.listen((Object? m) {
      if (m is SendPort) {
        _worker = m;
        for (final r in _early) {
          m.send(r);
        }
        _early.clear();
      } else if (m is WorkerReply) {
        if (m is ReadyReply) _isReady = true;
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
    final w = _worker;
    if (w != null && _isReady) {
      w.send(_shutdown);
    } else {
      // Still building the index: there is nothing to finish, so stop it.
      isolate?.kill(priority: Isolate.immediate);
    }
    await _exited.future.timeout(
      const Duration(seconds: 3),
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
      toMain.send(core.handle(m));
    } else if (m == _shutdown) {
      core.close();
      inbox.close();
    }
  });
}
