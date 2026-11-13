// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

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
import 'food_line_tile.dart';
import 'meal_slots.dart';

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
//   2.9  [FoodEntryScreenState.onLineTap]: the correction sheet. It receives a
//        [LineTap]; both a tap on a line and "Fix N items" end up there.
//   2.10 [_chipsSeam] in the scroll area, under the box: the chips row. It adds
//        lines with [FoodEntryScreenState.addLines].
//   2.11 [_scanSeam] in the top bar: the Scan button, which also adds lines
//        with [FoodEntryScreenState.addLines].
//   3.2  [_leftTodaySeam] in the totals bar: the "left today" line.

/// A line that is not typed: it holds its food and amount itself (grammar 9.3).
/// Shown from [line]; written from [stored] while it is untouched, so an
/// untouched entry is saved exactly as it was, byte for byte.
class AddedLine {
  const AddedLine(this.line, {this.existingId, this.stored});

  /// A stored entry of a logged meal, drawn from its stored values (it is not
  /// parsed again and not priced again).
  factory AddedLine.fromEntry(StoredEntry e) {
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
      existingId: x.id,
      stored: e.asInput(keepId: true),
    );
  }

  final Line line;

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
  const LineTap({required this.line, this.header, this.addedIndex, this.text});

  /// The line tapped. For a saved meal header this is the header; for one of
  /// its items it is the item.
  final Line line;

  /// The saved meal header an item line is under, or null.
  final Line? header;

  /// The index in the screen's added lines, or null for a typed line.
  final int? addedIndex;

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

class _Moved implements Exception {
  const _Moved();
}

class FoodEntryScreenState extends State<FoodEntryScreen> {
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

  // Writes.
  var _busy = false;
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
    _slotsSub = watchMealSlots(_db).listen((s) {
      if (mounted) setState(() => _slots = s);
    }, onError: (Object _) {});
    if (_slotId == null) _chooseDefaultSlot();
    _attach();
  }

  @override
  void dispose() {
    if (identical(active, this)) active = null;
    _noticeTimer?.cancel();
    _slotsSub?.cancel();
    _handle?.close();
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

  Future<void> _attach() async {
    final ParseWorker worker;
    try {
      final host = _parser;
      if (host == null) return;
      worker = await host.acquire();
    } catch (_) {
      if (mounted) setState(() => _dead = true);
      return;
    }
    if (!mounted) return;
    final h = worker.open(onResult: _onResult, onFailure: _onFailure);
    _handle = h;
    if (h.isClosed) {
      setState(() => _dead = true);
      return;
    }
    final text = _controller.text;
    final id = _sendText(_cursor());
    final picks = widget.draft?.picks ?? const <DraftPick>[];
    if (picks.isEmpty) return;
    // Rule 13: wait for the text's result, then send the picks again.
    try {
      await _waitFor(id, text);
      for (final p in picks) {
        if (!mounted || h.isClosed) return;
        await h.pick(text, p.span, p.foodRef, marker: p.marker);
      }
    } catch (_) {
      // The box moved on, or the worker stopped: the text is kept either way.
    }
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

  /// The first saved meal expanded in this meal, for `meals.saved_meal_id`.
  int? _savedMealId(List<Line> typed) {
    for (final l in [for (final a in _added) a.line, ...typed]) {
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
  void addLines(List<AddedLine> lines) =>
      setState(() => _added = [..._added, ...lines]);

  void removeAdded(int index) {
    if (index < 0 || index >= _added.length) return;
    setState(() => _added = [..._added]..removeAt(index));
  }

  // The seam for the correction sheet (task 2.9).

  /// Called when a line is tapped and when "Fix N items" asks for the first
  /// line that was not found. Task 2.9 opens the correction sheet here. Until
  /// then nothing opens.
  void onLineTap(LineTap tap) {
    lineTapObserver?.call(tap);
  }

  /// Tests watch what the correction sheet would be asked to open.
  @visibleForTesting
  static void Function(LineTap tap)? lineTapObserver;

  /// Tests make picks through the handle until the correction sheet (task
  /// 2.9) does, and read the newest result.
  @visibleForTesting
  SessionHandle? get debugHandle => _handle;

  @visibleForTesting
  ParseResult? get debugResult => _result;

  // Save.

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var finished = false;
    try {
      // Rule 5: send the text with no cursor, so that nothing counts as still
      // being typed, and wait for that result.
      final text = _controller.text;
      final id = _lastId = _handle!.setText(text, -1);
      _sentText = text;
      _sentCursor = -1;
      final ParseResult r;
      try {
        r = await _waitFor(id, text);
      } catch (_) {
        return; // The box moved on or the worker failed: nothing is saved.
      }
      if (!mounted || _controller.text != text) return;
      final fix = [
        for (final l in r.lines)
          if (l.state == LineState.notFound && !l.plain) l,
      ];
      if (fix.isNotEmpty) {
        onLineTap(LineTap(line: fix.first, text: r.text));
        return;
      }
      final inputs = _inputs(r.lines);
      if (inputs.isEmpty) return;
      final slotId = _slotId!;
      final StoredMeal stored;
      try {
        final mealId = _editingMealId;
        if (mealId != null) {
          stored = await _db.editMeal(
            mealId,
            now: _clock(),
            lines: inputs,
            typedText: text,
            localDate: _date,
            slotId: slotId,
            savedMealId: _savedMealId(r.lines),
          );
        } else {
          stored = await _db.saveMeal(
            now: _clock(),
            localDate: _date,
            slotId: slotId,
            lines: inputs,
            sourceText: text,
            savedMealId: _savedMealId(r.lines),
          );
        }
      } catch (_) {
        if (mounted) setState(() => _error = S.foodSaveFailed);
        return;
      }
      if (!mounted) return;
      finished = true;
      Navigator.of(context).pop(FoodSaved(stored, edited: _editing));
    } finally {
      if (!finished && mounted) setState(() => _busy = false);
    }
  }

  /// Closes the screen. With text in the box, Home offers Undo, which opens
  /// the screen again with the text and the picks. No popup.
  void _close() {
    if (_busy) return;
    FoodEntryResult? result;
    if (_controller.text.trim().isNotEmpty) result = FoodAbandoned(_draft());
    Navigator.of(context).pop(result);
  }

  FoodDraft _draft() {
    final lines = _result?.lines ?? const <Line>[];
    return FoodDraft(
      date: _date,
      slotId: _slotId ?? 0,
      slotName: _slotName(),
      text: _controller.text,
      picks: [
        for (final l in lines)
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
      ],
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
      Navigator.of(context).pop(FoodDeleted(deleted));
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
    final r = _result;
    if (r == null) return;
    final items = _inputs(r.lines);
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

  Future<void> _undoWeight(int id) async {
    try {
      await _db.deleteWeight(id, _clock());
      if (!mounted) return;
      _noticeTimer?.cancel();
      setState(() => _notice = null);
    } catch (_) {
      if (mounted) setState(() => _notice = const _Notice(S.undoFailed));
    }
  }

  // Layout.

  @override
  Widget build(BuildContext context) {
    // At large text the date, the meals and the menu would leave too little
    // room above the keyboard, so they scroll with the lines instead.
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    final header = Column(
      children: [
        _topBar(context),
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
                      if (!largeText) header,
                      if (_notice != null)
                        ConfirmBar(
                          message: _notice!.text,
                          onUndo: _notice!.undo == null
                              ? null
                              : () => _notice!.undo!(),
                        ),
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
              _bar(context),
            ],
          ),
        ),
      ),
    );
  }

  /// A seam for task 2.11: the Scan button goes here, after the date.
  static const _scanSeam = SizedBox.shrink();

  /// A seam for task 2.10: the chips row (Same as yesterday, saved meals,
  /// recent foods) goes under the box.
  static const _chipsSeam = SizedBox.shrink();

  /// A seam for task 3.2: the "left today" line goes under the totals.
  static const _leftTodaySeam = SizedBox.shrink();

  Widget _topBar(BuildContext context) {
    final today = _clock().localDate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: S.foodClose,
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : _close,
          ),
          IconButton(
            tooltip: S.foodPreviousDay,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _date = addDays(_date, -1)),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                S.foodDate(_date, today),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
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
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(S.foodDeleteMeal),
                ),
              PopupMenuItem(
                value: 'saved',
                enabled: _fresh && _hasLines && _fixLines.isEmpty,
                child: const Text(S.foodSaveAsSaved),
              ),
            ],
          ),
        ],
      ),
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

  Widget _scrollArea(BuildContext context, {Widget? header}) {
    final typed = _typed;
    final added = _added;
    final lines = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (added.isNotEmpty) ...[
            _groupLabel(context, S.foodGroupAdded),
            for (var i = 0; i < added.length; i++) _addedTile(i),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              label: S.foodBoxLabel,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                // Opens with the keyboard up, except when editing a meal: its
                // lines are there to be read first (frame 13).
                autofocus: !_editing,
                keyboardType: TextInputType.multiline,
                minLines: 2,
                maxLines: 6,
                readOnly: _busy,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _editing ? S.foodBoxHintMore : S.foodBoxHint,
                ),
              ),
            ),
          ),
          if (_handle == null && !_dead) const Text(S.foodLoading),
          _chipsSeam,
          if (typed.isNotEmpty) ...[
            if (added.isNotEmpty) _groupLabel(context, S.foodGroupTyped),
            for (final l in typed) ..._typedTiles(l),
          ],
        ],
      ),
    );
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: Column(children: [?header, lines]),
    );
  }

  Widget _groupLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _addedTile(int i) {
    final line = _added[i].line;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              FoodLineTile(
                line: line,
                onTap: () => onLineTap(LineTap(line: line, addedIndex: i)),
              ),
              if (line.state == LineState.aliasOrSavedMeal)
                for (final item in line.items)
                  FoodLineTile(
                    line: item,
                    indent: true,
                    onTap: () => onLineTap(
                      LineTap(line: item, header: line, addedIndex: i),
                    ),
                  ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            tooltip: S.foodRemove(line.foodName ?? ''),
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => removeAdded(i),
          ),
        ),
      ],
    );
  }

  List<Widget> _typedTiles(Line l) {
    final text = _result?.text;
    if (l.state == LineState.aliasOrSavedMeal) {
      return [
        FoodLineTile(
          line: l,
          onTap: () => onLineTap(LineTap(line: l, text: text)),
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
      FoodLineTile(
        line: l,
        typed: _typedText(l),
        onTap: () => onLineTap(LineTap(line: l, text: text)),
      ),
    ];
  }

  Widget _bar(BuildContext context) {
    final theme = Theme.of(context);
    final fix = _fixLines.length;
    final totals = sumNutrients(
      _counted([for (final a in _added) a.line, ..._typed])
          .map((l) => l.nutrients),
    );
    final kcal = totals[Nutrients.energy];
    final p = totals[Nutrients.protein];
    final c = totals[Nutrients.carbs];
    final f = totals[Nutrients.fat];
    final message = _dead
        ? S.foodParserStopped
        : _error ?? (_requestFailed ? S.foodParseFailed : null);
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
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(message),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _dead
                        ? const SizedBox.shrink()
                        : Semantics(
                            label: S.spokenTotals(kcal ?? 0, p, c, f),
                            excludeSemantics: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: S.kcal(kcal ?? 0),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: '  ${S.macros(p, c, f)}'),
                                    ],
                                  ),
                                ),
                                _leftTodaySeam,
                                if (fix > 0)
                                  Text(
                                    S.itemsNotCounted(fix),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // At large text the label wraps rather than squeezing the
                  // totals out.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 168),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(88, 48),
                      ),
                      onPressed: _canSave ? _save : null,
                      child: Text(
                        fix > 0 ? S.fixItems(fix) : S.save,
                        textAlign: TextAlign.center,
                      ),
                    ),
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
/// The name is also stored as the meal's first other name, so typing it
/// expands the meal, and a name another saved meal already answers to is
/// refused. The full saved meals screens are task 2.10.
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
        aliases: [name],
      );
      if (!mounted) return;
      if (r.ok) {
        Navigator.of(context).pop(r.saved!.meal.name);
        return;
      }
      setState(() {
        _busy = false;
        _problem = r.problems.containsValue(AliasProblem.empty)
            ? S.savedMealNameEmpty
            : S.savedMealNameTaken;
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
