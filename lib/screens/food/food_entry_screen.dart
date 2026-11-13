// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../../app.dart';
import '../../app_scope.dart';
import '../../clock.dart';
import '../../data/database.dart';
import '../../data/food_data.dart';
import '../../data/food_library_data.dart';
import '../../data/nutrients.dart';
import '../../data/weight_data.dart';
import '../../parser/line.dart';
import '../../parser/parse_worker.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';
import '../weight/weight_sheet.dart';
import 'confirm_bar.dart';
import 'correction_sheet.dart';
import 'food_line_tile.dart';
import 'meal_chips.dart';

// The one-screen food entry (food-entry.html, parser-grammar.md 8 and 9).
//
// How it works. The text box is the source of truth for typed lines. Every
// change to the text or the cursor goes to the parser worker, and the lines
// come back only through [SessionHandle.onResult]; this screen never changes
// a line it received. Added lines (a logged meal being edited, and later the
// chips and barcode scans) live in [_added], outside the box, with their food
// and amount held directly. Save is allowed only when the newest result is for
// exactly the text in the box.
//
// Where later tasks plug in:
//   2.9  [FoodEntryScreenState.onLineTap] opens the correction sheet
//        (correction_sheet.dart) for a [LineTap]; both a tap on a line and
//        "Fix N items" end up there. The sheet asks this screen to act.
//   2.10 The chips row ([MealChips], first in the lines area, under the box).
//        A whole-meal chip logs at once when the screen is empty, and otherwise
//        adds lines with [FoodEntryScreenState.addLines].
//   2.11 [_scanSeam] in the top bar: the Scan button, which also adds lines
//        with [FoodEntryScreenState.addLines].
//   3.2  [_leftTodaySeam] in the totals bar: the "left today" line.

/// A line that is not typed: it holds its food and amount itself (grammar 9.3).
/// Shown from [line]; written from [stored] while it is untouched, so an
/// untouched entry is saved exactly as it was, byte for byte.
class AddedLine {
  const AddedLine(this.line, {this.existingId, this.stored, this.savedMealId});

  /// A stored entry of a logged meal, drawn from its stored values (it is not
  /// parsed again and not priced again). With [copy] it is a new line made
  /// from another meal's entry ("Same as yesterday"): it has no id of its own
  /// to keep, so saving writes it as a new row.
  factory AddedLine.fromEntry(StoredEntry e, {bool copy = false}) {
    final x = e.entry;
    return AddedLine(
      Line(
        state: LineState.matched,
        foodRef: x.foodRef,
        foodName: x.foodName,
        quantity: x.quantity,
        unitLabel: x.unitLabel,
        baseQuantity: x.baseQuantity,
        baseUnit: x.baseUnit,
        nutrients: e.nutrients,
      ),
      existingId: copy ? null : x.id,
      stored: e.asInput(keepId: !copy),
    );
  }

  /// A saved meal chip tapped while there is text or a line: the saved meal
  /// times [SavedMealExpansion.multiplier] as a header with its item lines
  /// (grammar 6.4 and 9.3).
  factory AddedLine.fromExpansion(SavedMealExpansion x) {
    final items = [
      for (final i in x.items)
        Line(
          state: LineState.matched,
          foodRef: i.foodRef,
          foodName: i.foodName,
          quantity: i.quantity,
          unitLabel: i.unitLabel,
          baseQuantity: i.baseQuantity,
          baseUnit: i.baseUnit,
          nutrients: i.nutrients,
        ),
    ];
    return AddedLine(
      Line(
        state: LineState.aliasOrSavedMeal,
        foodName: x.name,
        nutrients: sumNutrients(items.map((l) => l.nutrients)),
        multiplier: x.multiplier,
        items: items,
        savedMealId: x.savedMealId,
      ),
      savedMealId: x.savedMealId,
    );
  }

  final Line line;

  /// The saved meal this line came from: a saved meal chip, or one of its
  /// items after the header was turned into its items. The meal is stored as
  /// made from the first such saved meal in save order.
  final int? savedMealId;

  /// The id of the stored entry this line came from, when editing a meal.
  final int? existingId;

  /// The entry as stored, while nobody has changed it. Null once the line is
  /// replaced by a changed one (task 2.9 builds those with the new Line and
  /// the same [existingId]).
  final MealLineInput? stored;

  /// What is written for this line. A saved meal header becomes one line for
  /// each of its items, marked as items of a saved meal.
  List<MealLineInput> toInputs() {
    final s = stored;
    if (s != null) return [s];
    return _inputsFor(line, existingId: existingId, typed: false);
  }
}

List<MealLineInput> _inputsFor(Line l, {int? existingId, required bool typed}) {
  if (l.state == LineState.notFound) return const [];
  if (l.state == LineState.aliasOrSavedMeal) {
    return [
      for (final i in l.items)
        if (i.state != LineState.notFound)
          MealLineInput.fromLine(i, inSavedMeal: true),
    ];
  }
  // Learning (grammar 7.2, rule 12): only typed lines teach anything, and the
  // data layer ignores a line with no learned key.
  final picked =
      l.markers.contains(Marker.yourPick) || l.markers.contains(Marker.scanned);
  return [
    MealLineInput.fromLine(
      l,
      existingId: existingId,
      pickedFood: typed && picked,
      setAmount: typed && l.assumedAmountSetInSheet,
      fromLearned: typed && l.fromLearnedMatch,
    ),
  ];
}

/// A sticky correction to send again when a closed screen is reopened.
class DraftPick {
  const DraftPick(this.span, this.foodRef, this.marker);

  final Span span;
  final String foodRef;
  final Marker marker;
}

/// Everything needed to open the screen again as it was when it was closed
/// with text in the box (Undo on Home, grammar 9.1 and plan rule 13).
class FoodDraft {
  const FoodDraft({
    required this.date,
    required this.slotId,
    required this.slotName,
    required this.text,
    required this.picks,
    required this.added,
    this.editingMealId,
  });

  final String date;
  final int slotId;
  final String slotName;
  final String text;
  final List<DraftPick> picks;
  final List<AddedLine> added;

  /// Set when the screen was editing a logged meal.
  final int? editingMealId;
}

/// What the screen hands back when it closes.
sealed class FoodEntryResult {
  const FoodEntryResult();
}

/// The meal was written. [meal] is the stored meal read back.
class FoodSaved extends FoodEntryResult {
  const FoodSaved(this.meal, {required this.edited});
  final StoredMeal meal;
  final bool edited;
}

/// A whole-meal chip logged [meal] at once (food-entry frame 12). [what] is
/// what Home names in its message: the saved meal's name, or "same as
/// yesterday".
class FoodLogged extends FoodEntryResult {
  const FoodLogged(this.meal, this.what);
  final StoredMeal meal;
  final String what;
}

/// The meal was deleted. [deleted] holds its rows for one Undo.
class FoodDeleted extends FoodEntryResult {
  const FoodDeleted(this.deleted);
  final DeletedMeal deleted;
}

/// The screen was closed with text in the box. Nothing was written.
class FoodAbandoned extends FoodEntryResult {
  const FoodAbandoned(this.draft);
  final FoodDraft draft;
}

/// A tap on a line, for the correction sheet (task 2.9).
class LineTap {
  const LineTap({
    required this.line,
    this.header,
    this.addedIndex,
    this.added,
    this.text,
    this.typedText,
  });

  /// The line tapped. For a saved meal header this is the header; for one of
  /// its items it is the item.
  final Line line;

  /// The saved meal header an item line is under, or null.
  final Line? header;

  /// The index in the screen's added lines, or null for a typed line.
  final int? addedIndex;

  /// The added line itself (the saved meal header, for one of its items):
  /// the sheet finds it again by identity, not by [addedIndex].
  final AddedLine? added;

  /// For a typed line: the words typed for it (a slice of [text]).
  final String? typedText;

  /// For a typed line: the text of the result its span belongs to. Pass this
  /// text, never the box's current text, with the span (plan rule 6).
  final String? text;
}

class FoodEntryScreen extends StatefulWidget {
  const FoodEntryScreen({
    super.key,
    required this.date,
    this.slotId,
    this.editing,
    this.draft,
  });

  /// The day to log, 'YYYY-MM-DD'. Today when opened from Home.
  final String date;

  /// The meal chosen, or null to choose it from the clock.
  final int? slotId;

  /// A logged meal to edit: its entries show as added lines.
  final StoredMeal? editing;

  /// A closed screen to open again, with its text and picks.
  final FoodDraft? draft;

  @override
  State<FoodEntryScreen> createState() => FoodEntryScreenState();
}

class _Notice {
  const _Notice(this.text, [this.undo]);
  final String text;
  final Future<void> Function()? undo;
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

class _Moved implements Exception {
  const _Moved();
}

class FoodEntryScreenState extends State<FoodEntryScreen>
    implements CorrectionHost {
  /// The food screen on top, if one is open. The widget link uses it: a tap on
  /// the weight widget opens the weight sheet over this screen.
  static FoodEntryScreenState? active;

  static const _noticeTime = Duration(seconds: 10);

  late AppDatabase _db;
  late Clock _clock;
  ParserHost? _parser;
  var _ready = false;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  late String _date;
  int? _slotId;
  var _slots = <MealSlot>[];
  StreamSubscription<List<MealSlot>>? _slotsSub;

  late List<AddedLine> _added;
  int? _editingMealId;
  String _editingSlotName = '';

  // The parser side.
  SessionHandle? _handle;
  ParseResult? _result;
  String? _sentText;
  int _sentCursor = -2;
  int _lastId = 0;
  var _requestFailed = false;
  var _dead = false;
  final _waiters = <(int, String, Completer<ParseResult>)>[];

  // Writes. [_busy] is the whole of Save (the wait for the parser result and
  // the write); [_writing] is only the database write, the one time closing
  // is refused.
  var _busy = false;
  var _writing = false;
  var _closed = false;

  // The correction sheet. [_changes] tells it that the box, the newest result
  // or the worker changed. [_addedChanged] is true once the user changed the
  // added lines of a logged meal being edited (it is then worth a draft).
  var _sheetOpen = false;
  final _changes = _Signal();
  var _addedChanged = false;
  final _currentKey = GlobalKey();
  String? _error;

  _Notice? _notice;
  Timer? _noticeTimer;

  bool get _editing => _editingMealId != null;

  @override
  void initState() {
    super.initState();
    active = this;
    final d = widget.draft;
    final e = widget.editing;
    _date = d?.date ?? e?.meal.localDate ?? widget.date;
    _slotId = d?.slotId ?? e?.meal.slotId ?? widget.slotId;
    _editingMealId = d?.editingMealId ?? e?.meal.id;
    _editingSlotName = d?.slotName ?? e?.slotName ?? '';
    _addedChanged = d?.editingMealId != null;
    _added = d != null
        ? [...d.added]
        : [
            if (e != null)
              for (final x in e.entries) AddedLine.fromEntry(x),
          ];
    if (d != null) {
      _controller.value = TextEditingValue(
        text: d.text,
        selection: TextSelection.collapsed(offset: d.text.length),
      );
    }
    _controller.addListener(_onBoxChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final scope = AppScope.of(context);
    _db = scope.db;
    _clock = scope.clock;
    _parser = scope.parser;
    _slotsSub = _db.watchMealSlots().listen((s) {
      if (mounted) setState(() => _slots = s);
    }, onError: (Object _) {});
    if (_slotId == null) _chooseDefaultSlot();
    _attach(picks: widget.draft?.picks ?? const []);
  }

  @override
  void dispose() {
    if (identical(active, this)) active = null;
    _noticeTimer?.cancel();
    _slotsSub?.cancel();
    _changes.dispose();
    _handle?.close();
    _failWaiters(const _Moved());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _chooseDefaultSlot() async {
    try {
      final slot = await _db.defaultMealSlot(_clock().minuteOfDay);
      if (mounted && _slotId == null) setState(() => _slotId = slot.id);
    } catch (_) {
      // No slot yet: the chips show none chosen and Save stays off.
    }
  }

  // The parser.

  Future<void> _attach({List<DraftPick> picks = const []}) async {
    final ParseWorker worker;
    try {
      final host = _parser;
      if (host == null) return;
      worker = await host.acquire();
    } catch (_) {
      if (mounted) setState(() => _dead = true);
      _changes.fire();
      return;
    }
    if (!mounted) return;
    final h = worker.open(onResult: _onResult, onFailure: _onFailure);
    _handle = h;
    if (h.isClosed) {
      setState(() => _dead = true);
      _changes.fire();
      return;
    }
    final text = _controller.text;
    final id = _sendText(_cursor());
    if (picks.isEmpty) return;
    // Rule 13: wait for the text's result, then send the picks again. They go
    // out together, in order, so nothing can land between two of them.
    try {
      await _waitFor(id, text);
    } catch (_) {
      return; // The box moved on, or the worker stopped: the text is kept.
    }
    for (final p in picks) {
      if (!mounted || h.isClosed) return;
      h
          .pick(text, p.span, p.foodRef, marker: p.marker)
          .then((_) {}, onError: (Object _) {});
    }
  }

  /// "Try again" after the worker died: a new worker, the same text. The
  /// picks are sent again only if the newest result is for exactly this text.
  void _retry() {
    final picks = _picksNow();
    _handle?.close();
    _handle = null;
    _changes.fire();
    _result = null;
    _sentText = null;
    _sentCursor = -2;
    _lastId = 0; // ids start again with a new worker
    setState(() {
      _requestFailed = false;
      _dead = false;
    });
    _attach(picks: picks);
  }

  int _cursor() {
    final sel = _controller.selection;
    return sel.isValid ? sel.extentOffset : _controller.text.length;
  }

  int _sendText(int cursor) {
    final text = _controller.text;
    _sentText = text;
    _sentCursor = cursor;
    return _lastId = _handle!.setText(text, cursor);
  }

  /// Every change to the text and every move of the cursor goes to the
  /// parser at once (rule 3).
  void _onBoxChanged() {
    final h = _handle;
    if (h != null && !h.isClosed) {
      final cursor = _cursor();
      if (_controller.text != _sentText || cursor != _sentCursor) {
        _sendText(cursor);
      }
    }
    if (mounted) setState(() {});
    _changes.fire();
  }

  void _onResult(ParseResult r) {
    _result = r;
    _requestFailed = false;
    for (final w in [..._waiters]) {
      if (r.id < w.$1) continue;
      _waiters.remove(w);
      if (r.text == w.$2) {
        w.$3.complete(r);
      } else {
        w.$3.completeError(const _Moved());
      }
    }
    if (mounted) setState(() {});
    _changes.fire();
    _revealCurrentLine();
  }

  /// Keeps the line for the item under the cursor in view (frame 2). It only
  /// scrolls the lines area: the text box is outside it, so the two never
  /// fight. A line above the view is shown at the start, one below it at the
  /// end, and one taller than the view shows its top. It runs after a result,
  /// never while the user scrolls by hand.
  void _revealCurrentLine() {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      final c = _currentKey.currentContext;
      if (!mounted || c == null) return;
      final box = c.findRenderObject();
      if (box == null || !box.attached) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      final position = Scrollable.maybeOf(c)?.position;
      if (viewport == null || position == null) return;
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final bottom = viewport.getOffsetToReveal(box, 1).offset;
      final here = position.pixels;
      double? to;
      if (bottom > top) {
        to = top; // taller than the view: its top
      } else if (here > top) {
        to = top; // above the view
      } else if (here < bottom) {
        to = bottom; // below the view
      }
      if (to == null) return;
      position.jumpTo(
        to.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
    binding.scheduleFrame();
  }

  void _onFailure(WorkerFailure f) {
    if (f.kind == FailureKind.closed) return;
    if (f.kind == FailureKind.request) {
      _requestFailed = true;
    } else {
      _dead = true;
    }
    for (final w in _waiters) {
      w.$3.completeError(f);
    }
    _waiters.clear();
    if (mounted) setState(() {});
    _changes.fire();
  }

  void _failWaiters(Object error) {
    final waiting = [..._waiters];
    _waiters.clear();
    for (final w in waiting) {
      w.$3.completeError(error);
    }
  }

  Future<ParseResult> _waitFor(int id, String text) {
    final r = _result;
    if (r != null && r.id >= id) {
      return r.text == text ? Future.value(r) : Future.error(const _Moved());
    }
    final c = Completer<ParseResult>();
    _waiters.add((id, text, c));
    return c.future;
  }

  // What the screen knows about its lines.

  /// The lines drawn from the parser. Hidden when the worker is dead.
  List<Line> get _typed => _dead ? const [] : (_result?.lines ?? const []);

  /// Lines that count toward the totals: item lines under a header (never the
  /// header), and every line that is not "not found".
  Iterable<Line> _counted(Iterable<Line> lines) sync* {
    for (final l in lines) {
      if (l.state == LineState.aliasOrSavedMeal) {
        for (final i in l.items) {
          if (i.state != LineState.notFound) yield i;
        }
      } else if (l.state != LineState.notFound) {
        yield l;
      }
    }
  }

  /// "Fix N items" counts the not found lines that are not plain (8.4).
  List<Line> get _fixLines => [
    for (final l in _typed)
      if (l.state == LineState.notFound && !l.plain) l,
  ];

  bool get _fresh {
    final r = _result;
    return r != null &&
        !_dead &&
        !_requestFailed &&
        r.text == _controller.text &&
        r.id >= _lastId;
  }

  bool get _hasLines => _added.isNotEmpty || _typed.isNotEmpty;

  bool get _canSave => _fresh && _hasLines && _slotId != null && !_busy;

  String _typedText(Line l) {
    final text = _result?.text ?? '';
    final s = l.span;
    if (s == null || s.start < 0 || s.end > text.length || s.start > s.end) {
      return l.foodText ?? '';
    }
    return text.substring(s.start, s.end).trim();
  }

  /// The lines to write, in screen order: added lines, then typed lines.
  List<MealLineInput> _inputs(List<Line> typed) => [
    for (final a in _added) ...a.toInputs(),
    for (final l in typed) ..._inputsFor(l, typed: true),
  ];

  /// The first saved meal in this meal, for `meals.saved_meal_id`, in save
  /// order: added lines first (a chip, or a typed saved meal turned into its
  /// items, in the order they were added), then typed lines.
  int? _savedMealId(List<Line> typed) {
    for (final a in _added) {
      if (a.savedMealId != null) return a.savedMealId;
    }
    for (final l in typed) {
      if (l.state == LineState.aliasOrSavedMeal && l.savedMealId != null) {
        return l.savedMealId;
      }
    }
    return null;
  }

  String _slotName() {
    for (final s in _slots) {
      if (s.id == _slotId) return s.name;
    }
    return _editingSlotName;
  }

  /// Adds lines that did not come from typing (chips and scans, tasks 2.10
  /// and 2.11). They are listed before the typed lines, in the order added.
  void addLines(List<AddedLine> lines) => setState(() {
    _added = [..._added, ...lines];
    _addedChanged = true;
  });

  void removeAdded(int index) {
    if (index < 0 || index >= _added.length) return;
    setState(() {
      _added = [..._added]..removeAt(index);
      _addedChanged = true;
    });
  }

  // The correction sheet (task 2.9).

  /// Called when a line is tapped and when "Fix N items" asks for the first
  /// line that was not found. Opens the correction sheet. It is not awaited:
  /// Save, which can call this, must not stay busy while the sheet is open.
  void onLineTap(LineTap tap) {
    // Nothing opens while a save is in progress; Save opens the Fix sheet
    // itself, through [_requestSheet].
    if (_busy) return;
    _requestSheet(tap);
  }

  void _requestSheet(LineTap tap) {
    if (_sheetOpen || !mounted) return;
    // A line drawn for text the box has moved on from is not tapped: the
    // lines are about to catch up (rule 6).
    if (tap.text != null && tap.text != _controller.text) return;
    unawaited(_openSheet(tap));
  }

  /// The keyboard goes down while the sheet is open and comes back, with the
  /// cursor where it was, when it closes (frame 4). It stays down if it was
  /// down (editing a logged meal).
  Future<void> _openSheet(LineTap tap) async {
    final selection = _controller.selection;
    final text = _controller.text;
    final hadFocus = _focus.hasFocus;
    _sheetOpen = true;
    _focus.unfocus();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (_) => CorrectionSheet(host: this, tap: tap, handle: _handle),
      );
    } finally {
      _sheetOpen = false;
    }
    if (!mounted || !hadFocus) return;
    _focus.requestFocus();
    // A rewrite or a removal already set its own cursor.
    if (_controller.text == text && selection.isValid) {
      _controller.selection = selection;
    }
  }

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _changes.removeListener(listener);

  @override
  SessionHandle? get sheetHandle => _handle;

  @override
  bool get sheetUsable => !_dead;

  @override
  String get boxText => _controller.text;

  @override
  void sheetNote(String text) {
    if (mounted) _showNotice(_Notice(text));
  }

  @override
  Future<ParseWorker?> sheetWorker() async {
    try {
      return await _parser?.acquire();
    } catch (_) {
      return null;
    }
  }

  // True when the last worker question threw (the worker stopped): the
  // screen's own dead-worker message is enough then.
  var _guardThrew = false;

  Future<T?> _guard<T>(Future<T> Function() f) async {
    _guardThrew = false;
    try {
      return await f();
    } catch (_) {
      _guardThrew = true;
      return null; // never the text or a line
    }
  }

  /// One plain line for a refusal, unless the worker died (then the screen
  /// already says so).
  void _refused(String text) {
    if (_dead || _guardThrew) return;
    sheetNote(text);
  }

  void _stale() {
    if (!_dead) sheetNote(S.foodSheetStale);
  }

  /// Rule 8: the text and the cursor in one step, so the next text sent to
  /// the parser is exactly this one.
  void _setText(String text, int cursor) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
    );
  }

  Future<Line?> _foodLine(
    String ref, {
    double? quantity,
    String unit = '',
  }) async {
    final w = await sheetWorker();
    if (w == null) return null;
    return _guard<Line?>(() => w.foodLine(ref, quantity: quantity, unit: unit));
  }

  /// Prices [ref] for a line that is not typed, keeping the amount it had:
  /// each of [tries] in turn, then the same weight in grams, and only then
  /// the food's default amount (reset is then true and the caller says so).
  /// A line that comes back Assumed is a refusal in the first two steps: the
  /// food could not take that amount. Null when the food cannot be priced.
  Future<({Line line, bool reset})?> _priceFood(
    String ref, {
    List<AmountTry> tries = const [],
    double? grams,
  }) async {
    for (final t in tries) {
      final l = await _foodLine(ref, quantity: t.quantity, unit: t.unit);
      if (l != null && !l.markers.contains(Marker.assumed)) {
        return (line: l, reset: false);
      }
    }
    if (grams != null) {
      final l = await _foodLine(ref, quantity: grams, unit: 'g');
      if (l != null && !l.markers.contains(Marker.assumed)) {
        return (line: l, reset: false);
      }
    }
    final l = await _foodLine(ref);
    if (l == null) return null;
    return (line: l, reset: tries.isNotEmpty || grams != null);
  }

  /// The handle, text and span of a typed line (or a typed saved meal
  /// header) when they are still good; otherwise a message and null.
  ({SessionHandle h, String text, Span span})? _typedTarget(LineTap tap) {
    final h = _handle;
    final text = tap.text;
    final span = tap.line.span;
    if (h == null ||
        h.isClosed ||
        text == null ||
        span == null ||
        text != _controller.text) {
      _stale();
      return null;
    }
    return (h: h, text: text, span: span);
  }

  /// A line that is an added line, or an item of a saved meal header. These
  /// are changed on the screen's own list, never through the text.
  bool _foodLevel(LineTap tap) => tap.addedIndex != null || tap.header != null;

  /// Turns a saved meal header into its items as added lines for this meal,
  /// and returns them. For a typed header the name's text is removed first
  /// (decision 22 in docs/phase-4-summary.md); on a refusal nothing changes.
  Future<List<AddedLine>?> _explode(LineTap tap) async {
    final header = tap.header!;
    final fresh = [
      for (final i in header.items)
        AddedLine(i, savedMealId: header.savedMealId),
    ];
    if (tap.added != null) {
      final at = _added.indexWhere((a) => identical(a, tap.added));
      if (at < 0) {
        _stale();
        return null;
      }
      setState(() {
        _added = [
          ..._added.sublist(0, at),
          ...fresh,
          ..._added.sublist(at + 1),
        ];
        _addedChanged = true;
      });
      return fresh;
    }
    final span = header.span;
    final text = tap.text;
    final h = _handle;
    if (h == null || h.isClosed || span == null || text == null) {
      _stale();
      return null;
    }
    if (text != _controller.text) {
      _stale();
      return null;
    }
    final out = await _guard(() => h.removeItem(text, _cursor(), span));
    if (out == null) {
      _refused(S.foodSheetRefusedRemove);
      return null;
    }
    if (_controller.text != text) {
      _stale();
      return null;
    }
    _setText(out.text, out.cursor);
    setState(() {
      _added = [..._added, ...fresh];
      _addedChanged = true;
    });
    return fresh;
  }

  /// Replaces an added line (or an item of a saved meal, after the meal was
  /// turned into its items) with [newLine], or removes it when [newLine] is
  /// null. The stored row of a logged meal keeps its id; a changed line no
  /// longer carries its stored values.
  Future<bool> _applyToAdded(LineTap tap, Line? newLine) async {
    AddedLine? target;
    if (tap.header != null) {
      final items = await _explode(tap);
      if (items == null) return false;
      final at = tap.header!.items.indexWhere((i) => identical(i, tap.line));
      if (at < 0 || at >= items.length) {
        _stale();
        return false;
      }
      target = items[at];
    } else {
      target = tap.added;
    }
    final i = _added.indexWhere((a) => identical(a, target));
    if (target == null || i < 0) {
      _stale();
      return false;
    }
    final id = target.existingId;
    final fromSaved = target.savedMealId;
    setState(() {
      final list = [..._added];
      if (newLine == null) {
        list.removeAt(i);
      } else {
        list[i] = AddedLine(newLine, existingId: id, savedMealId: fromSaved);
      }
      _added = list;
      _addedChanged = true;
    });
    return true;
  }

  @override
  Future<void> sheetPick(
    LineTap tap,
    String ref, {
    Marker marker = Marker.yourPick,
    List<AmountTry> amount = const [],
  }) async {
    if (_foodLevel(tap)) {
      final old = tap.line;
      // The line's own food: only a staged amount changes anything.
      if (ref == old.foodRef) {
        if (amount.isEmpty) return;
        return _setAddedAmount(tap, amount);
      }
      // Another food keeps the line's amount, or the amount staged in the
      // sheet; the weight is the next try, the default the last.
      final q = old.quantity;
      final priced = await _priceFood(
        ref,
        tries: amount.isNotEmpty
            ? amount
            : [if (q != null) AmountTry(q, old.unitLabel ?? '')],
        grams: amount.isEmpty && old.baseUnit == 'g' ? old.baseQuantity : null,
      );
      if (priced == null) return _refused(S.foodSheetRefusedFood);
      final applied = await _applyToAdded(tap, priced.line);
      if (applied && priced.reset) sheetNote(S.foodSheetAmountReset);
      return;
    }
    final t = _typedTarget(tap);
    if (t == null) return;
    final ok = await _guard(
      () => t.h.pick(t.text, t.span, ref, marker: marker),
    );
    if (ok != true) return _stale();
    // A pick does not change the text, so the same text and span still hold.
    if (amount.isNotEmpty) await _rewriteTyped(tap, amount);
  }

  /// Rewrites the amount of a typed line: the first of [tries] the text can
  /// express.
  Future<void> _rewriteTyped(LineTap tap, List<AmountTry> tries) async {
    final t = _typedTarget(tap);
    if (t == null) return;
    for (final a in tries) {
      final out = await _guard(
        () => t.h.rewriteAmount(
          t.text,
          _cursor(),
          t.span,
          quantity: a.quantity,
          unit: a.unit,
        ),
      );
      if (_guardThrew) return;
      if (out == null) continue;
      if (_controller.text != t.text) return _stale();
      _setText(out.text, out.cursor);
      return;
    }
    _refused(S.foodSheetRefusedAmount);
  }

  /// Changes the amount of a line that is not typed: the first of [tries]
  /// the food can take without assuming.
  Future<void> _setAddedAmount(LineTap tap, List<AmountTry> tries) async {
    final ref = tap.line.foodRef;
    if (ref == null) return _refused(S.foodSheetRefusedAmount);
    for (final a in tries) {
      final l = await _foodLine(ref, quantity: a.quantity, unit: a.unit);
      if (l != null && !l.markers.contains(Marker.assumed)) {
        await _applyToAdded(tap, l);
        return;
      }
    }
    _refused(S.foodSheetRefusedAmount);
  }

  /// Grammar 6.4: the multiplier of an added saved meal. It has no text, so
  /// the header's item lines are scaled and the header keeps its saved meal.
  Future<void> _setAddedMultiplier(LineTap tap, double multiplier) async {
    final at = _added.indexWhere((a) => identical(a, tap.added));
    if (at < 0) return _stale();
    final old = _added[at];
    final header = old.line;
    final f = multiplier / (header.multiplier ?? 1);
    final items = [
      for (final i in header.items)
        Line(
          state: i.state,
          foodRef: i.foodRef,
          foodName: i.foodName,
          quantity: i.quantity! * f,
          unitLabel: i.unitLabel,
          baseQuantity: i.baseQuantity! * f,
          baseUnit: i.baseUnit,
          nutrients: {for (final e in i.nutrients.entries) e.key: e.value * f},
          markers: i.markers,
        ),
    ];
    setState(() {
      _added = [..._added]
        ..[at] = AddedLine(
          Line(
            state: LineState.aliasOrSavedMeal,
            foodName: header.foodName,
            nutrients: sumNutrients(items.map((l) => l.nutrients)),
            markers: header.markers,
            multiplier: multiplier,
            items: items,
            savedMealId: header.savedMealId,
          ),
          savedMealId: old.savedMealId,
        );
      _addedChanged = true;
    });
  }

  @override
  Future<void> sheetSetAmount(LineTap tap, List<AmountTry> tries) async {
    if (tap.line.state == LineState.aliasOrSavedMeal && tap.added != null) {
      return _setAddedMultiplier(tap, tries.first.quantity);
    }
    if (_foodLevel(tap)) return _setAddedAmount(tap, tries);
    await _rewriteTyped(tap, tries);
  }

  @override
  Future<void> sheetRemove(LineTap tap) async {
    if (_foodLevel(tap)) {
      await _applyToAdded(tap, null);
      return;
    }
    final t = _typedTarget(tap);
    if (t == null) return;
    final out = await _guard(() => t.h.removeItem(t.text, _cursor(), t.span));
    if (out == null) return _refused(S.foodSheetRefusedRemove);
    if (_controller.text != t.text) return _stale();
    _setText(out.text, out.cursor);
  }

  @override
  Future<void> sheetForget(LineTap tap) async {
    final key = tap.line.learnedKey;
    if (key == null) return;
    final done = await _guard(() => _db.forgetLearnedMatch(key));
    // The lines come back through the snapshot, as a new result.
    if (done == null) _refused(S.foodSheetForgetFailed);
  }

  @override
  Future<void> sheetUseFood(LineTap tap, String ref, {double? quantity}) async {
    // "2 usual breakfast" becomes 2 of the food (a bare count); the default
    // amount if that is refused.
    final m = quantity ?? tap.line.multiplier;
    final priced = await _priceFood(
      ref,
      tries: [if (m != null && m != 1) AmountTry(m, '')],
    );
    if (priced == null) return _refused(S.foodSheetRefusedFood);
    final fresh = AddedLine(priced.line);
    if (tap.added != null) {
      final at = _added.indexWhere((a) => identical(a, tap.added));
      if (at < 0) return _stale();
      setState(() {
        _added = [..._added]..[at] = fresh;
        _addedChanged = true;
      });
    } else {
      final t = _typedTarget(tap);
      if (t == null) return;
      final out = await _guard(() => t.h.removeItem(t.text, _cursor(), t.span));
      if (out == null) return _refused(S.foodSheetRefusedRemove);
      if (_controller.text != t.text) return _stale();
      _setText(out.text, out.cursor);
      addLines([fresh]);
    }
    if (priced.reset) sheetNote(S.foodSheetAmountReset);
  }

  /// Tests make picks through the handle until the correction sheet (task
  /// 2.9) does, and read the newest result.
  @visibleForTesting
  SessionHandle? get debugHandle => _handle;

  @visibleForTesting
  ParseResult? get debugResult => _result;

  // The chips row (task 2.10).

  /// True while a whole-meal chip logs at once: no text, no lines, and not
  /// editing a logged meal (food-entry frame 1).
  bool get _logsNow =>
      !_editing && _controller.text.trim().isEmpty && _added.isEmpty;

  /// Logs a whole meal at once into the date and meal the chip was shown for,
  /// through the same guarded write as Save. The flag is set before anything
  /// is awaited, so a second tap, or a tap while a save is running, does
  /// nothing. The screen closes and Home shows the message with Undo.
  Future<void> _logNow(
    Future<({List<MealLineInput> lines, int? savedMealId, String what})?>
    Function()
    choose,
  ) async {
    if (_busy || _closed) return;
    final slotId = _slotId;
    if (slotId == null) return;
    final date = _date;
    setState(() {
      _busy = true;
      _error = null;
    });
    var finished = false;
    try {
      final c = await choose();
      if (c == null || !mounted || _closed) return;
      final stored = await _guardedWrite(
        () => _db.saveMeal(
          now: _clock(),
          localDate: date,
          slotId: slotId,
          lines: c.lines,
          savedMealId: c.savedMealId,
        ),
      );
      if (stored == null || !mounted) return;
      finished = true;
      _popSelf(FoodLogged(stored, c.what));
    } finally {
      if (!finished && mounted) setState(() => _busy = false);
    }
  }

  void _yesterdayChip(StoredMeal m) {
    if (_busy || _closed) return;
    if (_logsNow) {
      unawaited(
        _logNow(
          () async => (
            lines: [for (final e in m.entries) e.asInput()],
            savedMealId: null,
            what: S.chipSameAsYesterdayShort,
          ),
        ),
      );
    } else {
      addLines([for (final e in m.entries) AddedLine.fromEntry(e, copy: true)]);
    }
  }

  Future<void> _savedMealChip(SavedMealDetail meal) async {
    if (_busy || _closed) return;
    final id = meal.meal.id;
    if (_logsNow) {
      return _logNow(() async {
        final x = await _guard(() => _db.expandSavedMeal(id));
        if (x == null || x.items.isEmpty) {
          if (mounted) _showNotice(const _Notice(S.chipSavedMealGone));
          return null;
        }
        return (lines: x.items, savedMealId: x.savedMealId, what: x.name);
      });
    }
    final x = await _guard(() => _db.expandSavedMeal(id));
    if (!mounted || _busy || _closed) return;
    if (x == null || x.items.isEmpty) {
      return _showNotice(const _Notice(S.chipSavedMealGone));
    }
    addLines([AddedLine.fromExpansion(x)]);
  }

  /// A food chip always adds one line, at the amount last logged, priced by
  /// the worker. The amount is refused if the food would only assume it; the
  /// same weight is tried next, and then the food's usual amount with a line
  /// that says so.
  Future<void> _foodChip(RecentFood f) async {
    if (_busy || _closed) return;
    final priced = await _priceFood(
      f.foodRef,
      tries: [AmountTry(f.quantity, f.unitLabel)],
      grams: f.baseUnit == 'g' ? f.baseQuantity : null,
    );
    if (!mounted || _busy || _closed) return;
    if (priced == null) return _refused(S.foodSheetRefusedFood);
    addLines([AddedLine(priced.line)]);
    if (priced.reset) sheetNote(S.foodSheetAmountReset);
  }

  Widget _chips() {
    final slotId = _slotId;
    if (_editing || slotId == null || !_ready) return const SizedBox.shrink();
    return MealChips(
      db: _db,
      date: _date,
      slotId: slotId,
      today: _clock().localDate,
      logsNow: _logsNow,
      enabled: !_busy,
      onYesterday: _yesterdayChip,
      onSavedMeal: (m) => unawaited(_savedMealChip(m)),
      onFood: (f) => unawaited(_foodChip(f)),
    );
  }

  // Save.

  /// Rule 5: sends the text with no cursor, so that nothing counts as still
  /// being typed, and waits for that result. Null when the box moved on, the
  /// worker failed, or the screen is gone: the caller does nothing.
  Future<ParseResult?> _freshResult() async {
    final text = _controller.text;
    final id = _lastId = _handle!.setText(text, -1);
    _sentText = text;
    _sentCursor = -1;
    try {
      final r = await _waitFor(id, text);
      if (!mounted || _closed || _controller.text != text) return null;
      return r;
    } catch (_) {
      return null;
    }
  }

  /// The one guarded write, for Save and for a whole-meal chip: [_writing] is
  /// on for exactly the database write (the one time closing is refused), and
  /// a failure leaves the screen as it was with the message of frame 11.
  /// Null when the write failed.
  Future<StoredMeal?> _guardedWrite(Future<StoredMeal> Function() write) async {
    setState(() => _writing = true);
    try {
      return await write();
    } catch (_) {
      if (mounted) setState(() => _error = S.foodSaveFailed);
      return null;
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var finished = false;
    try {
      final r = await _freshResult();
      if (r == null) return; // nothing is saved
      final text = r.text;
      final fix = [
        for (final l in r.lines)
          if (l.state == LineState.notFound && !l.plain) l,
      ];
      if (fix.isNotEmpty) {
        _requestSheet(
          LineTap(
            line: fix.first,
            text: r.text,
            typedText: _typedText(fix.first),
          ),
        );
        return;
      }
      final inputs = _inputs(r.lines);
      if (inputs.isEmpty) return;
      final slotId = _slotId!;
      final mealId = _editingMealId;
      final stored = await _guardedWrite(
        () => mealId != null
            ? _db.editMeal(
                mealId,
                now: _clock(),
                lines: inputs,
                typedText: text,
                localDate: _date,
                slotId: slotId,
                savedMealId: _savedMealId(r.lines),
              )
            : _db.saveMeal(
                now: _clock(),
                localDate: _date,
                slotId: slotId,
                lines: inputs,
                sourceText: text,
                savedMealId: _savedMealId(r.lines),
              ),
      );
      if (stored == null || !mounted) return;
      finished = true;
      _popSelf(FoodSaved(stored, edited: _editing));
    } finally {
      if (!finished && mounted) setState(() => _busy = false);
    }
  }

  /// Closes this screen's own route and nothing else, whatever is on top of
  /// it (a sheet or a dialog that took the top while a save was running).
  void _popSelf(FoodEntryResult? result) {
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    if (route == null || route.isCurrent) {
      nav.pop(result);
    } else {
      nav.removeRoute(route, result);
    }
  }

  /// Closes the screen. With text in the box, Home offers Undo, which opens
  /// the screen again with the text and the picks. No popup. Refused only
  /// while the database write is in flight; while Save waits for the parser
  /// the screen can be closed, and the save is dropped.
  void _close() {
    if (_writing) return;
    _closed = true;
    _failWaiters(const _Moved());
    FoodEntryResult? result;
    // Added lines count too: for a new meal any of them, for a logged meal
    // only a change to them.
    final worth =
        _controller.text.trim().isNotEmpty ||
        (_editing ? _addedChanged : _added.isNotEmpty);
    if (worth) result = FoodAbandoned(_draft());
    _popSelf(result);
  }

  /// The picks to send again after a reopen or a retry: only from a result
  /// that is for exactly the text in the box, since a span from older text
  /// would land on the wrong words.
  List<DraftPick> _picksNow() {
    final r = _result;
    if (r == null || r.text != _controller.text) return const [];
    return [
      for (final l in r.lines)
        if (l.state != LineState.aliasOrSavedMeal &&
            l.span != null &&
            l.foodRef != null &&
            (l.markers.contains(Marker.yourPick) ||
                l.markers.contains(Marker.scanned)))
          DraftPick(
            l.span!,
            l.foodRef!,
            l.markers.contains(Marker.yourPick)
                ? Marker.yourPick
                : Marker.scanned,
          ),
    ];
  }

  FoodDraft _draft() {
    return FoodDraft(
      date: _date,
      slotId: _slotId ?? 0,
      slotName: _slotName(),
      text: _controller.text,
      picks: _picksNow(),
      added: _added,
      editingMealId: _editingMealId,
    );
  }

  Future<void> _delete() async {
    final id = _editingMealId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deleted = await _db.deleteMeal(id);
      if (!mounted) return;
      _popSelf(FoodDeleted(deleted));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = S.foodDeleteFailed;
        });
      }
    }
  }

  Future<void> _saveAsSavedMeal() async {
    if (_busy || _handle == null) return;
    setState(() => _busy = true);
    final ParseResult? r;
    try {
      r = await _freshResult();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (r == null || !mounted) return;
    // A saved meal is never made from some of the lines.
    if (r.lines.any((l) => l.state == LineState.notFound)) {
      _showNotice(const _Notice(S.savedMealNeedsFix));
      return;
    }
    final items = _inputs(r.lines);
    if (items.isEmpty) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SavedMealDialog(db: _db, clock: _clock, items: items),
    );
    if (name == null || !mounted) return;
    _showNotice(_Notice(S.savedMealCreated(name)));
  }

  // Messages on this screen. They sit under the meal chips, so they never
  // cover the totals bar or Save.

  void _showNotice(_Notice n) {
    _noticeTimer?.cancel();
    _noticeTimer = Timer(_noticeTime, () {
      if (mounted) setState(() => _notice = null);
    });
    setState(() => _notice = n);
  }

  /// A tap on the weight widget while this screen is open: the weight sheet
  /// opens over it, the text in the box is not touched, and the confirmation
  /// with Undo is shown here.
  Future<void> openWeightSheet() async {
    // While Save is running, a sheet on top would take the screen's pop.
    if (_busy) return;
    final saved = await showWeightSheet(context);
    if (saved == null || !mounted) return;
    final row = saved.row;
    final today = _clock().localDate;
    _showNotice(
      _Notice(
        S.weightSaved(
          formatWeight(row.weightKg, saved.units),
          S.unitWord(saved.units),
          S.whenInSentence(
            row.localDate,
            minuteOfDayOf(row.measuredAtMs, row.tzOffsetMinutes),
            today,
          ),
        ),
        () => _undoWeight(row.id),
      ),
    );
  }

  Future<void> _undoWeight(int id) => _db.deleteWeight(id, _clock());

  /// Single flight: the message is taken and cleared before anything is
  /// awaited, so a second tap finds nothing to undo.
  Future<void> _undoNotice() async {
    final undo = _notice?.undo;
    if (undo == null) return;
    _noticeTimer?.cancel();
    setState(() => _notice = null);
    try {
      await undo();
    } catch (_) {
      if (mounted) _showNotice(const _Notice(S.undoFailed));
    }
  }

  // Layout.

  @override
  Widget build(BuildContext context) {
    // At large text the meal chips scroll with the lines; the top row (close,
    // date, menu) and the box always stay put.
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    final header = Column(
      children: [
        _slotChips(context),
        if (_editing)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              S.foodEditing(_slotName()),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ContentWidth(
                  child: Column(
                    children: [
                      _topBar(context),
                      if (!largeText) header,
                      if (_notice != null)
                        ConfirmBar(
                          message: _notice!.text,
                          onUndo: _notice!.undo == null ? null : _undoNotice,
                        ),
                      // What is left is shared by the box and the lines. The
                      // box stays in a fixed area, outside the scrolling
                      // lines, and takes what it needs first.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, room) => Column(
                            children: [
                              _boxArea(context, room.maxHeight),
                              Expanded(
                                child: _scrollArea(
                                  context,
                                  header: largeText ? header : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _bar(context),
            ],
          ),
        ),
      ),
    );
  }

  /// A seam for task 2.11: the Scan button goes here, after the date.
  static const _scanSeam = SizedBox.shrink();

  /// A seam for task 3.2: the "left today" line goes under the totals.
  static const _leftTodaySeam = SizedBox.shrink();

  /// Tapping the date opens a calendar that ends today (frame 1).
  Future<void> _pickDate() async {
    if (_busy) return;
    final today = parseDate(_clock().localDate);
    final day = parseDate(_date);
    final last = DateTime(today.year, today.month, today.day);
    var initial = DateTime(day.year, day.month, day.day);
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _date = formatDate(
        DateTime.utc(picked.year, picked.month, picked.day),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final today = _clock().localDate;
    // At large text the date gets its own row under the buttons, at its full
    // size, and wraps if it must.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final date = Semantics(
      header: true,
      button: true,
      child: InkWell(
        onTap: _pickDate,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Text(
              S.foodDate(_date, today),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
    final children = [
      IconButton(
        tooltip: S.foodClose,
        icon: const Icon(Icons.close),
        onPressed: _writing ? null : _close,
      ),
      IconButton(
        tooltip: S.foodPreviousDay,
        icon: const Icon(Icons.chevron_left),
        onPressed: () => setState(() => _date = addDays(_date, -1)),
      ),
      if (stacked) const Spacer() else Expanded(child: date),
      IconButton(
        tooltip: S.foodNextDay,
        icon: const Icon(Icons.chevron_right),
        // The date stops at today.
        onPressed: _date.compareTo(today) >= 0
            ? null
            : () => setState(() => _date = addDays(_date, 1)),
      ),
      _scanSeam,
      PopupMenuButton<String>(
        tooltip: S.foodMenu,
        enabled: !_busy,
        onSelected: (v) {
          if (v == 'delete') _delete();
          if (v == 'saved') _saveAsSavedMeal();
        },
        itemBuilder: (_) => [
          if (_editing)
            const PopupMenuItem(value: 'delete', child: Text(S.foodDeleteMeal)),
          PopupMenuItem(
            value: 'saved',
            enabled: _fresh && _hasLines && _fixLines.isEmpty,
            child: const Text(S.foodSaveAsSaved),
          ),
        ],
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: stacked
          ? Column(
              children: [
                Row(children: children),
                date,
              ],
            )
          : Row(children: children),
    );
  }

  Widget _slotChips(BuildContext context) {
    final shown = [
      for (final s in _slots)
        if (!s.archived || s.id == _slotId) s,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Semantics(
        label: S.foodMealPicker,
        container: true,
        child: Row(
          children: [
            for (final s in shown)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ChoiceChip(
                    label: Text(s.name),
                    selected: s.id == _slotId,
                    showCheckmark: true,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _slotId = s.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The text box, in a fixed area above the lines. It grows with its text up
  /// to a few lines and then scrolls inside itself, keeping its own caret in
  /// view. [available] is the height of the whole content column: the box
  /// takes at most half of it, so the lines and Save keep room.
  Widget _boxArea(BuildContext context, double available) {
    final lineHeight = MediaQuery.textScalerOf(context).scale(16) * 1.4;
    final fit = ((available * 0.5 - 56) / lineHeight).floor();
    final maxLines = fit.clamp(1, 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ConstrainedBox(
        // Never taller than the room there is (very large text with the
        // keyboard up): the box then scrolls inside itself and the lines get
        // no room, but the box stays on screen.
        constraints: BoxConstraints(maxHeight: (available - 16).clamp(0, 1e9)),
        child: Semantics(
          label: S.foodBoxLabel,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            // Opens with the keyboard up, except when editing a meal: its
            // lines are there to be read first (frame 13).
            autofocus: !_editing,
            keyboardType: TextInputType.multiline,
            minLines: maxLines < 2 ? maxLines : 2,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _editing ? S.foodBoxHintMore : S.foodBoxHint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrollArea(BuildContext context, {Widget? header}) {
    final typed = _typed;
    final added = _added;
    final lines = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _chips(),
          if (added.isNotEmpty) ...[
            _groupLabel(context, S.foodGroupAdded),
            for (var i = 0; i < added.length; i++) _addedTile(i),
          ],
          if (_handle == null && !_dead) const Text(S.foodLoading),
          if (typed.isNotEmpty) ...[
            if (added.isNotEmpty) _groupLabel(context, S.foodGroupTyped),
            for (final l in typed) ..._typedTiles(l),
          ],
        ],
      ),
    );
    return SingleChildScrollView(
      key: linesKey,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: Column(children: [?header, lines]),
    );
  }

  /// The scroll area of the lines, so tests can read its offset.
  @visibleForTesting
  static const linesKey = ValueKey('food-lines');

  Widget _groupLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _addedTile(int i) {
    final added = _added[i];
    final line = added.line;
    return Column(
      children: [
        FoodLineTile(
          line: line,
          onTap: () =>
              onLineTap(LineTap(line: line, addedIndex: i, added: added)),
        ),
        if (line.state == LineState.aliasOrSavedMeal)
          for (final item in line.items)
            FoodLineTile(
              line: item,
              indent: true,
              onTap: () => onLineTap(
                LineTap(line: item, header: line, addedIndex: i, added: added),
              ),
            ),
      ],
    );
  }

  /// The typed line that holds the cursor of the newest result, if that
  /// result is for the text in the box.
  Line? get _currentLine {
    final r = _result;
    if (r == null || _dead || r.text != _controller.text || r.cursor < 0) {
      return null;
    }
    for (final l in r.lines) {
      final s = l.span;
      if (s != null && r.cursor >= s.start && r.cursor <= s.end) return l;
    }
    return null;
  }

  List<Widget> _typedTiles(Line l) {
    final text = _result?.text;
    final current = identical(l, _currentLine);
    Widget keyed(Widget w) =>
        current ? KeyedSubtree(key: _currentKey, child: w) : w;
    if (l.state == LineState.aliasOrSavedMeal) {
      return [
        keyed(
          FoodLineTile(
            line: l,
            current: current,
            onTap: () => onLineTap(
              LineTap(line: l, text: text, typedText: _typedText(l)),
            ),
          ),
        ),
        for (final item in l.items)
          FoodLineTile(
            line: item,
            indent: true,
            onTap: () => onLineTap(LineTap(line: item, header: l, text: text)),
          ),
      ];
    }
    return [
      keyed(
        FoodLineTile(
          line: l,
          typed: _typedText(l),
          current: current,
          onTap: () =>
              onLineTap(LineTap(line: l, text: text, typedText: _typedText(l))),
        ),
      ),
    ];
  }

  Widget _bar(BuildContext context) {
    final theme = Theme.of(context);
    final fix = _fixLines.length;
    final counted = _counted([for (final a in _added) a.line, ..._typed]);
    final totals = sumNutrients(counted.map((l) => l.nutrients));
    // No counted line: zeros. A "-" is only for a food that lists no value.
    final none = counted.isEmpty;
    final kcal = none ? 0.0 : totals[Nutrients.energy];
    final p = none ? 0.0 : totals[Nutrients.protein];
    final c = none ? 0.0 : totals[Nutrients.carbs];
    final f = none ? 0.0 : totals[Nutrients.fat];
    final message = _dead
        ? S.foodParserStopped
        : _error ?? (_requestFailed ? S.foodParseFailed : null);
    // At large text the button goes under the totals, full width, and the
    // kcal and the macros take a line each. Nothing is scaled down.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final totalsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The count of items not counted is in the spoken totals. The seam
        // below is outside the excluded part, so what task 3.2 puts there is
        // read on its own.
        Semantics(
          label: S.spokenTotals(kcal, p, c, f, fix),
          excludeSemantics: true,
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.kcal(kcal), style: bold),
                    Text(S.totalsMacros(p, c, f).trim()),
                  ],
                )
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: S.kcal(kcal), style: bold),
                      TextSpan(text: S.totalsMacros(p, c, f)),
                    ],
                  ),
                ),
        ),
        _leftTodaySeam,
        if (fix > 0)
          ExcludeSemantics(child: Text(S.itemsNotCounted(fix), style: bold)),
      ],
    );
    final button = FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
      onPressed: _canSave ? _save : null,
      child: Text(
        fix > 0 ? S.fixItems(fix) : S.save,
        textAlign: TextAlign.center,
      ),
    );
    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: 3,
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message != null)
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(message),
                        ),
                      ),
                    ),
                    if (_dead)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _retry,
                        child: const Text(S.tryAgain),
                      ),
                  ],
                ),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_dead) totalsColumn,
                    if (!_dead) const SizedBox(height: 4),
                    button,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _dead ? const SizedBox.shrink() : totalsColumn,
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 168),
                      child: button,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a name and makes a saved meal from the lines. One plain field.
/// Typing the name expands the meal (grammar 6.1), so no other name is
/// stored; two saved meals may share a name and the newest wins. The full
/// saved meals screens are task 2.10.
class _SavedMealDialog extends StatefulWidget {
  const _SavedMealDialog({
    required this.db,
    required this.clock,
    required this.items,
  });

  final AppDatabase db;
  final Clock clock;
  final List<MealLineInput> items;

  @override
  State<_SavedMealDialog> createState() => _SavedMealDialogState();
}

class _SavedMealDialogState extends State<_SavedMealDialog> {
  final _name = TextEditingController();
  String? _problem;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = S.savedMealNameEmpty);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final r = await widget.db.createSavedMeal(
        name: name,
        items: widget.items,
        now: widget.clock(),
      );
      if (!mounted) return;
      if (r.ok) {
        Navigator.of(context).pop(r.saved!.meal.name);
        return;
      }
      setState(() {
        _busy = false;
        _problem = S.savedMealFailed;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = S.savedMealFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.savedMealTitle),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: S.savedMealName,
          errorText: _problem,
        ),
        onSubmitted: (_) => _create(),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _busy ? null : _create,
          child: const Text(S.save),
        ),
      ],
    );
  }
}
