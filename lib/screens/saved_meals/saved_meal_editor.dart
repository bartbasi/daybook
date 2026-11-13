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
import '../../parser/line.dart';
import '../../parser/name_key.dart';
import '../../parser/parse_worker.dart';
import '../../strings.dart';
import '../food/confirm_bar.dart';
import '../food/correction_sheet.dart';
import '../food/food_entry_screen.dart';
import '../food/food_line_tile.dart';

// The saved meal editor (saved-meals.html frame 2).
//
// The items are shown as added lines (grammar 9.3). The empty box under them
// adds more by typing, with the parser worker and the lines of Food entry; the
// typed items join the list when the saved meal is saved. Tapping an item or a
// typed line opens the correction sheet of Food entry, through
// [CorrectionHost].
//
// This is a smaller version of what the food screen does, not a share of it:
// the food screen's box, parser handle and sheet host are part of that
// screen's own state. What it does not have: items under a typed saved meal
// cannot be tapped (the header's own sheet can change its multiplier, swap it
// for a food, or remove it), and nothing is learned (a saved meal is not a
// logged meal).

/// What the editor hands back when it closes with a change.
sealed class SavedMealEditorResult {
  const SavedMealEditorResult();
}

/// The saved meal was written. [saved] is the row read back.
class SavedMealSaved extends SavedMealEditorResult {
  const SavedMealSaved(this.saved);
  final SavedMealDetail saved;
}

/// The saved meal was deleted. [deleted] holds its rows for one Undo.
class SavedMealRemoved extends SavedMealEditorResult {
  const SavedMealRemoved(this.deleted);
  final DeletedSavedMeal deleted;
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

class _Moved implements Exception {
  const _Moved();
}

class SavedMealEditor extends StatefulWidget {
  const SavedMealEditor({super.key, this.saved});

  /// The saved meal to change, or null for a new one.
  final SavedMealDetail? saved;

  @override
  State<SavedMealEditor> createState() => SavedMealEditorState();
}

class SavedMealEditorState extends State<SavedMealEditor>
    implements CorrectionHost {
  late AppDatabase _db;
  late Clock _clock;
  ParserHost? _parser;
  var _ready = false;

  final _name = TextEditingController();
  final _newAlias = TextEditingController();
  final _box = TextEditingController();
  final _focus = FocusNode();

  var _aliases = <String>[];
  var _items = <AddedLine>[];

  // The parser side, as on the food screen (plan rules 2 to 4).
  SessionHandle? _handle;
  ParseResult? _result;
  String? _sentText;
  int _sentCursor = -2;
  int _lastId = 0;
  var _requestFailed = false;
  var _dead = false;
  final _waiters = <(int, String, Completer<ParseResult>)>[];

  var _busy = false;
  var _writing = false;
  var _sheetOpen = false;
  final _changes = _Signal();
  String? _error;
  String? _aliasError;
  String? _note;
  var _guardThrew = false;

  bool get _isNew => widget.saved == null;

  @override
  void initState() {
    super.initState();
    final s = widget.saved;
    if (s != null) {
      _name.text = s.meal.name;
      _aliases = [...s.aliases];
      _items = [
        for (final i in s.items)
          AddedLine(
            Line(
              state: LineState.matched,
              foodRef: i.item.foodRef,
              foodName: i.item.foodName,
              quantity: i.item.quantity,
              unitLabel: i.item.unitLabel,
              baseQuantity: i.item.baseQuantity,
              baseUnit: i.item.baseUnit,
              nutrients: i.nutrients,
            ),
            // Untouched items are written back exactly as stored.
            stored: i.asInput(),
          ),
      ];
    }
    _box.addListener(_onBoxChanged);
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
    _attach();
  }

  @override
  void dispose() {
    _changes.dispose();
    _handle?.close();
    _failWaiters(const _Moved());
    _name.dispose();
    _newAlias.dispose();
    _box.dispose();
    _focus.dispose();
    super.dispose();
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
    _sendText(_cursor());
  }

  void _retry() {
    _handle?.close();
    _handle = null;
    _result = null;
    _sentText = null;
    _sentCursor = -2;
    _lastId = 0;
    _changes.fire();
    setState(() {
      _requestFailed = false;
      _dead = false;
    });
    _attach();
  }

  int _cursor() {
    final sel = _box.selection;
    return sel.isValid ? sel.extentOffset : _box.text.length;
  }

  int _sendText(int cursor) {
    final text = _box.text;
    _sentText = text;
    _sentCursor = cursor;
    return _lastId = _handle!.setText(text, cursor);
  }

  /// Every change to the text and every move of the cursor goes to the parser
  /// at once (rule 3).
  void _onBoxChanged() {
    final h = _handle;
    if (h != null && !h.isClosed) {
      final cursor = _cursor();
      if (_box.text != _sentText || cursor != _sentCursor) _sendText(cursor);
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

  /// Rule 5: the text with no cursor, and its result. Null when the box moved
  /// on or the worker failed.
  Future<ParseResult?> _freshResult() async {
    final text = _box.text;
    final id = _lastId = _handle!.setText(text, -1);
    _sentText = text;
    _sentCursor = -1;
    try {
      final r = await _waitFor(id, text);
      if (!mounted || _box.text != text) return null;
      return r;
    } catch (_) {
      return null;
    }
  }

  // What the editor knows about its lines.

  List<Line> get _typed => _dead ? const [] : (_result?.lines ?? const []);

  bool get _fresh {
    final r = _result;
    return r != null &&
        !_dead &&
        !_requestFailed &&
        r.text == _box.text &&
        r.id >= _lastId;
  }

  List<Line> get _fixLines => [
    for (final l in _typed)
      if (l.state == LineState.notFound && !l.plain) l,
  ];

  /// Item lines under a header count, never the header; not found lines never.
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

  bool get _canSave => _fresh && !_busy;

  String _typedText(Line l) {
    final text = _result?.text ?? '';
    final s = l.span;
    if (s == null || s.start < 0 || s.end > text.length || s.start > s.end) {
      return l.foodText ?? '';
    }
    return text.substring(s.start, s.end).trim();
  }

  List<MealLineInput> _typedInputs(Line l) {
    if (l.state == LineState.notFound) return const [];
    if (l.state == LineState.aliasOrSavedMeal) {
      return [
        for (final i in l.items)
          if (i.state != LineState.notFound) MealLineInput.fromLine(i),
      ];
    }
    return [MealLineInput.fromLine(l)];
  }

  // The other names.

  void _addAlias() {
    final p = _newAlias.text.trim();
    final key = nameKey(p);
    if (key.isEmpty) {
      setState(() => _aliasError = S.savedMealAliasEmpty);
      return;
    }
    if (_aliases.any((a) => nameKey(a) == key)) {
      setState(() => _aliasError = S.savedMealAliasInList(p));
      return;
    }
    setState(() {
      _aliases = [..._aliases, p];
      _aliasError = null;
      _newAlias.clear();
    });
  }

  void _removeAlias(int i) => setState(() {
    _aliases = [..._aliases]..removeAt(i);
    _aliasError = null;
  });

  // Save and delete.

  Future<void> _save() async {
    if (!_canSave) return;
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _aliasError = null;
      _note = null;
    });
    try {
      if (name.isEmpty) {
        setState(() => _error = S.savedMealNameEmpty);
        return;
      }
      final r = await _freshResult();
      if (r == null) return;
      final fix = [
        for (final l in r.lines)
          if (l.state == LineState.notFound && !l.plain) l,
      ];
      if (fix.isNotEmpty) {
        _openSheet(
          LineTap(
            line: fix.first,
            text: r.text,
            typedText: _typedText(fix.first),
          ),
        );
        return;
      }
      final items = [
        for (final a in _items) ...a.toInputs(),
        for (final l in r.lines) ..._typedInputs(l),
      ];
      if (items.isEmpty) {
        setState(() => _error = S.savedMealNeedsItems);
        return;
      }
      final SavedMealResult result;
      setState(() => _writing = true);
      try {
        final s = widget.saved;
        result = s == null
            ? await _db.createSavedMeal(
                name: name,
                items: items,
                now: _clock(),
                aliases: _aliases,
              )
            : await _db.updateSavedMeal(
                s.meal.id,
                name: name,
                items: items,
                aliases: _aliases,
              );
      } catch (_) {
        if (mounted) setState(() => _error = S.savedMealFailed);
        return;
      } finally {
        if (mounted) setState(() => _writing = false);
      }
      if (!mounted) return;
      if (!result.ok) {
        // Nothing was written. Plain words for the first name refused.
        final first = result.problems.entries.first;
        setState(
          () => _aliasError = first.value == AliasProblem.taken
              ? S.savedMealAliasTaken(first.key)
              : S.savedMealAliasBlank,
        );
        return;
      }
      Navigator.of(context).pop(SavedMealSaved(result.saved!));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final s = widget.saved;
    if (s == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deleted = await _db.deleteSavedMeal(s.meal.id);
      if (!mounted) return;
      Navigator.of(context).pop(SavedMealRemoved(deleted));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = S.savedMealDeleteFailed;
        });
      }
    }
  }

  // The correction sheet.

  void _onTap(LineTap tap) {
    if (_busy) return;
    if (tap.text != null && tap.text != _box.text) return;
    unawaited(_openSheet(tap));
  }

  Future<void> _openSheet(LineTap tap) async {
    if (_sheetOpen || !mounted) return;
    final hadFocus = _focus.hasFocus;
    _note = null;
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
    if (mounted && hadFocus) _focus.requestFocus();
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
  String get boxText => _box.text;

  @override
  void sheetNote(String text) {
    if (mounted) setState(() => _note = text);
  }

  @override
  Future<ParseWorker?> sheetWorker() async {
    try {
      return await _parser?.acquire();
    } catch (_) {
      return null;
    }
  }

  Future<T?> _guard<T>(Future<T> Function() f) async {
    _guardThrew = false;
    try {
      return await f();
    } catch (_) {
      _guardThrew = true;
      return null; // never the text or a line
    }
  }

  void _refused(String text) {
    if (_dead || _guardThrew) return;
    sheetNote(text);
  }

  void _stale() {
    if (!_dead) sheetNote(S.foodSheetStale);
  }

  void _setText(String text, int cursor) {
    _box.value = TextEditingValue(
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

  /// Prices [ref] keeping the amount: each of [tries], then the same weight,
  /// then the food's usual amount (reset is then true). A line that comes back
  /// Assumed is a refusal in the first two steps.
  Future<({Line line, bool reset})?> _price(
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

  ({SessionHandle h, String text, Span span})? _typedTarget(LineTap tap) {
    final h = _handle;
    final text = tap.text;
    final span = tap.line.span;
    if (h == null ||
        h.isClosed ||
        text == null ||
        span == null ||
        text != _box.text) {
      _stale();
      return null;
    }
    return (h: h, text: text, span: span);
  }

  /// Replaces an item with [newLine], or removes it when null.
  bool _applyToItem(LineTap tap, Line? newLine) {
    final i = _items.indexWhere((a) => identical(a, tap.added));
    if (i < 0) {
      _stale();
      return false;
    }
    setState(() {
      final list = [..._items];
      if (newLine == null) {
        list.removeAt(i);
      } else {
        list[i] = AddedLine(newLine);
      }
      _items = list;
    });
    return true;
  }

  bool _isItem(LineTap tap) => tap.addedIndex != null;

  @override
  Future<void> sheetPick(
    LineTap tap,
    String ref, {
    Marker marker = Marker.yourPick,
    List<AmountTry> amount = const [],
  }) async {
    if (_isItem(tap)) {
      final old = tap.line;
      if (ref == old.foodRef) {
        if (amount.isEmpty) return;
        return sheetSetAmount(tap, amount);
      }
      final q = old.quantity;
      final priced = await _price(
        ref,
        tries: amount.isNotEmpty
            ? amount
            : [if (q != null) AmountTry(q, old.unitLabel ?? '')],
        grams: amount.isEmpty && old.baseUnit == 'g' ? old.baseQuantity : null,
      );
      if (priced == null) return _refused(S.foodSheetRefusedFood);
      if (_applyToItem(tap, priced.line) && priced.reset) {
        sheetNote(S.foodSheetAmountReset);
      }
      return;
    }
    final t = _typedTarget(tap);
    if (t == null) return;
    final ok = await _guard(
      () => t.h.pick(t.text, t.span, ref, marker: marker),
    );
    if (ok != true) return _stale();
    if (amount.isNotEmpty) await _rewriteTyped(tap, amount);
  }

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
      if (_box.text != t.text) return _stale();
      _setText(out.text, out.cursor);
      return;
    }
    _refused(S.foodSheetRefusedAmount);
  }

  @override
  Future<void> sheetSetAmount(LineTap tap, List<AmountTry> tries) async {
    if (!_isItem(tap)) return _rewriteTyped(tap, tries);
    final ref = tap.line.foodRef;
    if (ref == null) return _refused(S.foodSheetRefusedAmount);
    for (final a in tries) {
      final l = await _foodLine(ref, quantity: a.quantity, unit: a.unit);
      if (l != null && !l.markers.contains(Marker.assumed)) {
        _applyToItem(tap, l);
        return;
      }
    }
    _refused(S.foodSheetRefusedAmount);
  }

  @override
  Future<void> sheetRemove(LineTap tap) async {
    if (_isItem(tap)) {
      _applyToItem(tap, null);
      return;
    }
    final t = _typedTarget(tap);
    if (t == null) return;
    final out = await _guard(() => t.h.removeItem(t.text, _cursor(), t.span));
    if (out == null) return _refused(S.foodSheetRefusedRemove);
    if (_box.text != t.text) return _stale();
    _setText(out.text, out.cursor);
  }

  @override
  Future<void> sheetForget(LineTap tap) async {
    final key = tap.line.learnedKey;
    if (key == null) return;
    final done = await _guard(() => _db.forgetLearnedMatch(key));
    if (done == null) _refused(S.foodSheetForgetFailed);
  }

  @override
  Future<void> sheetUseFood(LineTap tap, String ref, {double? quantity}) async {
    final m = quantity ?? tap.line.multiplier;
    final priced = await _price(
      ref,
      tries: [if (m != null && m != 1) AmountTry(m, '')],
    );
    if (priced == null) return _refused(S.foodSheetRefusedFood);
    final t = _typedTarget(tap);
    if (t == null) return;
    final out = await _guard(() => t.h.removeItem(t.text, _cursor(), t.span));
    if (out == null) return _refused(S.foodSheetRefusedRemove);
    if (_box.text != t.text) return _stale();
    _setText(out.text, out.cursor);
    setState(() => _items = [..._items, AddedLine(priced.line)]);
    if (priced.reset) sheetNote(S.foodSheetAmountReset);
  }

  // Layout.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_writing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? S.savedMealEditNew : widget.saved!.meal.name),
          actions: [
            if (!_isNew)
              PopupMenuButton<String>(
                tooltip: S.savedMealMenu,
                enabled: !_busy,
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(S.savedMealDelete),
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ContentWidth(
                  child: Column(
                    children: [
                      if (_note != null)
                        ConfirmBar(message: _note!, onUndo: null),
                      Expanded(child: _scrollArea(theme)),
                      _boxArea(context),
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

  Widget _scrollArea(ThemeData theme) {
    final typed = _typed;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: S.savedMealName,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(S.savedMealOtherNames, style: theme.textTheme.titleSmall),
        ),
        for (var i = 0; i < _aliases.length; i++) _aliasRow(i),
        _aliasAdd(),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            S.savedMealItemsHeading,
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (_items.isEmpty && typed.isEmpty) const Text(S.savedMealItemsEmpty),
        for (var i = 0; i < _items.length; i++) _itemTile(i),
        for (final l in typed) ..._typedTiles(l),
      ],
    );
  }

  Widget _aliasRow(int i) {
    final p = _aliases[i];
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(child: Text(p)),
          IconButton(
            tooltip: S.savedMealRemoveName(p),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.close),
            onPressed: () => _removeAlias(i),
          ),
        ],
      ),
    );
  }

  Widget _aliasAdd() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newAlias,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addAlias(),
                  decoration: const InputDecoration(
                    labelText: S.savedMealNewName,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _addAlias,
                child: const Text(S.savedMealAddName),
              ),
            ],
          ),
          if (_aliasError != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _aliasError!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemTile(int i) {
    final a = _items[i];
    return FoodLineTile(
      line: a.line,
      onTap: () => _onTap(LineTap(line: a.line, addedIndex: i, added: a)),
    );
  }

  List<Widget> _typedTiles(Line l) {
    final text = _result?.text;
    if (l.state == LineState.aliasOrSavedMeal) {
      return [
        FoodLineTile(
          line: l,
          onTap: () =>
              _onTap(LineTap(line: l, text: text, typedText: _typedText(l))),
        ),
        // The items of a typed saved meal are shown, not tapped.
        for (final item in l.items) FoodLineTile(line: item, indent: true),
      ];
    }
    return [
      FoodLineTile(
        line: l,
        typed: _typedText(l),
        onTap: () =>
            _onTap(LineTap(line: l, text: text, typedText: _typedText(l))),
      ),
    ];
  }

  /// The empty box that adds items by typing, outside the scrolling lines so
  /// it never scrolls away.
  Widget _boxArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Semantics(
        label: S.savedMealBoxLabel,
        child: TextField(
          controller: _box,
          focusNode: _focus,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: S.savedMealBoxHint,
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final theme = Theme.of(context);
    final fix = _fixLines.length;
    final counted = _counted([for (final a in _items) a.line, ..._typed])
        .toList();
    final totals = sumNutrients(counted.map((l) => l.nutrients));
    final none = counted.isEmpty;
    final kcal = none ? 0.0 : totals[Nutrients.energy];
    final p = none ? 0.0 : totals[Nutrients.protein];
    final c = none ? 0.0 : totals[Nutrients.carbs];
    final f = none ? 0.0 : totals[Nutrients.fat];
    final message = _dead
        ? S.foodParserStopped
        : _error ?? (_requestFailed ? S.foodParseFailed : null);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final totalsText = Semantics(
      label: S.spokenTotals(kcal, p, c, f, fix),
      excludeSemantics: true,
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.kcal(kcal), style: bold),
                Text(S.totalsMacros(p, c, f).trim()),
                if (fix > 0) Text(S.itemsNotCounted(fix), style: bold),
              ],
            )
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: S.kcal(kcal), style: bold),
                  TextSpan(text: S.totalsMacros(p, c, f)),
                  if (fix > 0) TextSpan(text: '  ${S.itemsNotCounted(fix)}'),
                ],
              ),
            ),
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
                    if (!_dead) totalsText,
                    if (!_dead) const SizedBox(height: 4),
                    button,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _dead ? const SizedBox.shrink() : totalsText,
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
