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
import '../../parser/parse_worker.dart';
import '../../strings.dart';
import '../food/confirm_bar.dart';
import '../food/correction_sheet.dart';
import '../food/food_entry_screen.dart';
import '../food/food_line_tile.dart';
import 'food_editor.dart';

// The recipe editor (food-editor.html frame 2).
//
// The ingredients are shown as added lines (grammar 9.3). The empty box under
// them adds more by typing, with the parser worker and the lines of Food
// entry; typed ingredients join the list when the recipe is saved. Tapping an
// ingredient or a typed line opens the correction sheet of Food entry,
// through [CorrectionHost].
//
// This is the saved meal editor's approach with its own copy of the parser
// side (its worker session, the newest result, the waiters, the sheet host).
// Differences: no other names, a "Makes N servings" field, totals per serving
// and for the whole recipe, and delete archives (Undo on the list). A stored
// ingredient has no nutrients (the schema keeps none), so a reopened recipe
// prices each ingredient again from the food data before Save can be used,
// and the stored totals are always the sum of the ingredients shown, never
// carried over. See docs/phase-4-summary.md for what could be shared later.

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

class _Moved implements Exception {
  const _Moved();
}

class RecipeEditor extends StatefulWidget {
  const RecipeEditor({super.key, this.recipe});

  /// The recipe to change, or null for a new one.
  final FoodDetail? recipe;

  @override
  State<RecipeEditor> createState() => RecipeEditorState();
}

class RecipeEditorState extends State<RecipeEditor> implements CorrectionHost {
  late AppDatabase _db;
  late Clock _clock;
  ParserHost? _parser;
  var _ready = false;

  final _name = TextEditingController();
  final _servings = TextEditingController(text: '1');
  final _box = TextEditingController();
  final _focus = FocusNode();

  var _items = <AddedLine>[];

  /// Ingredients that pricing ran for and refused. Only these are drawn as
  /// not found; with the worker down they only show no numbers.
  var _notPriced = <AddedLine>{};

  // The parser side, as on the food screen (plan rules 2 to 4).
  SessionHandle? _handle;
  ParseResult? _result;
  String? _sentText;
  int _sentCursor = -2;
  int _lastId = 0;
  var _requestFailed = false;
  var _dead = false;
  final _waiters = <(int, String, Completer<ParseResult>)>[];

  var _pricing = false;
  var _busy = false;
  var _writing = false;
  var _sheetOpen = false;
  final _changes = _Signal();
  String? _error;
  String? _nameError;
  String? _servingsError;
  String? _note;
  var _guardThrew = false;

  bool get _isNew => widget.recipe == null;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    if (r != null) {
      _name.text = r.food.name;
      _servings.text = S.numberText(r.food.baseAmount);
      // Shown at once with no numbers; priced again as soon as the worker is
      // there. Save waits for that.
      _items = [
        for (final i in r.ingredients)
          AddedLine(
            Line(
              state: LineState.matched,
              foodRef: i.foodRef,
              foodName: i.foodName,
              quantity: i.quantity,
              unitLabel: i.unitLabel,
              baseQuantity: i.baseQuantity,
              baseUnit: i.baseUnit,
            ),
          ),
      ];
      _pricing = r.ingredients.isNotEmpty;
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
    if (_pricing) unawaited(_priceAgain());
  }

  @override
  void dispose() {
    _changes.dispose();
    _handle?.close();
    _failWaiters(const _Moved());
    _name.dispose();
    _servings.dispose();
    _box.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Pricing a reopened recipe's ingredients again.

  /// Each ingredient that has no numbers is priced again from the food data,
  /// by the rules of the food screen ([_price]): its own amount, then the same
  /// weight in grams, then the food's usual amount (with the reset note). One
  /// that cannot be priced stays as it is, marked in words, and Save refuses
  /// until it is removed or changed. Taps and changes to the ingredients are
  /// ignored while this runs (`_pricing`), so the list is the one this started
  /// with when it ends.
  Future<void> _priceAgain() async {
    final start = _items;
    final out = <AddedLine>[];
    final reset = <String>[];
    for (final a in start) {
      final old = a.line;
      final ref = old.foodRef;
      if (old.nutrients.isNotEmpty || ref == null) {
        out.add(a);
        continue;
      }
      final q = old.quantity;
      final priced = await _price(
        ref,
        tries: [if (q != null) AmountTry(q, old.unitLabel ?? '')],
        grams: old.baseUnit == 'g' ? old.baseQuantity : null,
        keepBaseUnit: await _keepBaseUnit(old),
      );
      if (priced == null) {
        out.add(a);
        continue;
      }
      if (priced.reset) reset.add(old.foodName ?? '');
      out.add(AddedLine(priced.line));
    }
    if (!mounted) return;
    setState(() {
      if (identical(_items, start)) _items = out;
      _notPriced = {
        if (!_dead)
          for (final a in out)
            if (a.line.nutrients.isEmpty && a.line.foodRef != null) a,
      };
      _pricing = false;
    });
    if (reset.isNotEmpty) sheetNote(S.recipeAmountReset(reset));
    _changes.fire();
  }

  /// The base unit a re-priced ingredient must still come out in, or null when
  /// any will do. An amount in servings is kept whenever the food still has a
  /// serving, whatever happened to its base unit; an amount in weight, volume
  /// or a bare count must come out in the unit it was stored in.
  Future<String?> _keepBaseUnit(Line stored) async {
    final unit = (stored.unitLabel ?? '').trim().toLowerCase();
    if (unit != 'serving' && unit != 'servings') return stored.baseUnit;
    final ref = stored.foodRef ?? '';
    if (!ref.startsWith('local:')) return null;
    final id = int.tryParse(ref.substring(6));
    final food = id == null ? null : await _guard(() => _db.loadFood(id));
    if (food == null) return stored.baseUnit;
    final hasServing =
        food.food.baseUnit == 'serving' || food.portions.isNotEmpty;
    return hasServing ? null : stored.baseUnit;
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
    final text = _box.text;
    final id = _sendText(_cursor());
    if (picks.isEmpty) return;
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

  /// The picks to send again after a retry: only from a result that is for
  /// exactly the text in the box.
  List<DraftPick> _picksNow() {
    final r = _result;
    if (r == null || r.text != _box.text) return const [];
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

  void _retry() {
    final picks = _picksNow();
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
    _attach(picks: picks);
    // A worker that was dead, or food data that failed, when the recipe
    // opened left ingredients with no numbers: price them again.
    if (!_pricing && _items.any((a) => a.line.nutrients.isEmpty)) {
      setState(() => _pricing = true);
      unawaited(_priceAgain());
    }
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

  bool get _canSave => _fresh && !_busy && !_pricing;

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

  double? get _servingsValue {
    final v = parseFoodNumber(_servings.text);
    return v != null && v > 0 ? v : null;
  }

  // Save and delete.

  Future<void> _save() async {
    if (!_canSave) return;
    final name = _name.text.trim();
    final servings = _servingsValue;
    setState(() {
      _busy = true;
      _error = null;
      _nameError = null;
      _servingsError = null;
      _note = null;
    });
    var finished = false;
    try {
      var bad = false;
      if (name.isEmpty) {
        setState(() => _nameError = S.recipeNameEmpty);
        bad = true;
      }
      if (servings == null) {
        setState(
          () => _servingsError = foodNumberProblem(
            _servings.text,
            S.recipeServingsBad,
          ),
        );
        bad = true;
      }
      if (bad) return;
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
      final ingredients = [
        for (final a in _items) ...a.toInputs(),
        for (final l in r.lines) ..._typedInputs(l),
      ];
      if (ingredients.isEmpty) {
        setState(() => _error = S.recipeNeedsIngredients);
        return;
      }
      final unpriced = ingredients.where((i) => i.nutrients.isEmpty);
      if (unpriced.isNotEmpty) {
        setState(
          () => _error = S.recipeIngredientUnpriced(unpriced.first.foodName),
        );
        return;
      }
      final FoodDetail saved;
      setState(() => _writing = true);
      try {
        final input = RecipeInput(
          name: name,
          servings: servings!,
          ingredients: ingredients,
        );
        final old = widget.recipe;
        saved = old == null
            ? await _db.createRecipe(input, _clock())
            : await _db.editRecipe(old.food.id, input, _clock());
      } on RecipeCycleException catch (e) {
        if (mounted) {
          setState(
            () =>
                _error = S.recipeContainsItself(ingredients[e.index].foodName),
          );
        }
        return;
      } catch (_) {
        if (mounted) setState(() => _error = S.recipeFailed);
        return;
      } finally {
        if (mounted) setState(() => _writing = false);
      }
      if (!mounted) return;
      finished = true;
      popRouteOf<MyFoodResult>(context, MyFoodSaved(saved));
    } finally {
      if (!finished && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final r = widget.recipe;
    if (r == null || _busy) return;
    setState(() {
      _busy = true;
      _writing = true;
      _error = null;
    });
    try {
      final gone = await _db.archiveFood(r.food.id, _clock());
      if (!mounted) return;
      setState(() => _writing = false);
      popRouteOf<MyFoodResult>(context, MyFoodRemoved(gone, null));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _writing = false;
          _error = S.myFoodDeleteFailed;
        });
      }
    }
  }

  // The correction sheet.

  void _onTap(LineTap tap) {
    if (_busy || _pricing) return;
    if (tap.text != null && tap.text != _box.text) return;
    unawaited(_openSheet(tap));
  }

  Future<void> _openSheet(LineTap tap) async {
    if (_sheetOpen || !mounted || _pricing) return;
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
  /// Assumed is a refusal in the first two steps. With [keepBaseUnit] (the
  /// unit an ingredient was stored in), so is a line in another base unit:
  /// the food no longer means by that amount what it meant.
  Future<({Line line, bool reset})?> _price(
    String ref, {
    List<AmountTry> tries = const [],
    double? grams,
    String? keepBaseUnit,
  }) async {
    bool taken(Line? l) =>
        l != null &&
        !l.markers.contains(Marker.assumed) &&
        (keepBaseUnit == null || l.baseUnit == keepBaseUnit);
    for (final t in tries) {
      final l = await _foodLine(ref, quantity: t.quantity, unit: t.unit);
      if (taken(l)) return (line: l!, reset: false);
    }
    if (grams != null) {
      final l = await _foodLine(ref, quantity: grams, unit: 'g');
      if (taken(l)) return (line: l!, reset: false);
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

  /// Replaces an ingredient with [newLine], or removes it when null.
  bool _applyToItem(LineTap tap, Line? newLine) {
    final i = _items.indexWhere((a) => identical(a, tap.added));
    if (_pricing || i < 0) {
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
    if (_pricing) return _stale();
    final t = _typedTarget(tap);
    if (t == null) return;
    final out = await _guard(() => t.h.removeItem(t.text, _cursor(), t.span));
    if (out == null) return _refused(S.foodSheetRefusedRemove);
    if (_box.text != t.text) return _stale();
    _setText(out.text, out.cursor);
    setState(() => _items = [..._items, AddedLine(priced.line)]);
    if (priced.reset) sheetNote(S.foodSheetAmountReset);
  }

  @visibleForTesting
  SessionHandle? get debugHandle => _handle;

  @visibleForTesting
  ParseResult? get debugResult => _result;

  // Layout.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_writing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? S.recipeEditNew : widget.recipe!.food.name),
          actions: [
            if (!_isNew)
              PopupMenuButton<String>(
                tooltip: S.myFoodsMenu,
                enabled: !_busy,
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text(S.recipeDelete)),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ContentWidth(
                  child: LayoutBuilder(
                    builder: (context, room) => Column(
                      children: [
                        if (_note != null)
                          ConfirmBar(message: _note!, onUndo: null),
                        Expanded(child: _scrollArea(theme)),
                        _boxArea(context, room.maxHeight),
                      ],
                    ),
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
          decoration: InputDecoration(
            labelText: S.recipeName,
            errorText: _nameError,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(S.recipeIngredients, style: theme.textTheme.titleSmall),
        ),
        if (_pricing)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                S.recipePricing,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (_items.isEmpty && typed.isEmpty)
          const Text(S.recipeIngredientsEmpty),
        for (var i = 0; i < _items.length; i++) _itemTile(i),
        for (final l in typed) ..._typedTiles(l),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 220,
            child: TextField(
              controller: _servings,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _servingsError = null),
              decoration: InputDecoration(
                labelText: S.recipeMakes,
                suffixText: S.recipeServingsUnit,
                errorText: _servingsError,
                errorMaxLines: 4,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _itemTile(int i) {
    final a = _items[i];
    // An ingredient with no numbers (after pricing) is drawn as a line that
    // was not found: its outline, its words, and "Not counted".
    final unpriced = !_pricing && _notPriced.contains(a);
    return FoodLineTile(
      line: unpriced ? a.line.copyWith(state: LineState.notFound) : a.line,
      typed: a.line.foodName ?? '',
      onTap: _pricing
          ? null
          : () => _onTap(LineTap(line: a.line, addedIndex: i, added: a)),
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

  /// The empty box that adds ingredients by typing, outside the scrolling
  /// lines so it never scrolls away.
  Widget _boxArea(BuildContext context, double available) {
    // As on the food screen: the box takes at most half of the room, grows
    // with its text up to a few lines, and then scrolls inside itself.
    final lineHeight = MediaQuery.textScalerOf(context).scale(16) * 1.4;
    final fit = ((available * 0.5 - 56) / lineHeight).floor();
    final maxLines = fit.clamp(1, 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: (available - 16).clamp(0, 1e9)),
        child: Semantics(
          label: S.recipeBoxLabel,
          child: TextField(
            controller: _box,
            focusNode: _focus,
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: S.recipeBoxHint,
            ),
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
    final servings = _servingsValue;
    double of(int id) => none ? 0.0 : (totals[id] ?? 0.0);
    final whole = of(Nutrients.energy);
    // Totals are worked out from the lines on screen each time they are
    // drawn, never held from before.
    final per = servings ?? 1;
    final kcal = whole / per;
    final p = of(Nutrients.protein) / per;
    final c = of(Nutrients.carbs) / per;
    final f = of(Nutrients.fat) / per;
    final message = _dead
        ? S.foodParserStopped
        : _error ?? (_requestFailed ? S.foodParseFailed : null);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final first = servings == null
        ? S.recipeWhole(whole)
        : S.recipeKcalServing(kcal);
    final second = servings == null
        ? ''
        : '${S.totalsMacros(p, c, f).trim()}. ${S.recipeWhole(whole)}';
    final totalsText = Semantics(
      label: S.recipeSpokenTotals(kcal, p, c, f, whole, fix),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(first, style: bold),
          if (second.isNotEmpty) Text(second),
          if (fix > 0) Text(S.itemsNotCounted(fix), style: bold),
        ],
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
