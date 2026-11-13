// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../data/nutrients.dart';
import '../../parser/line.dart';
import '../../parser/parse_session.dart';
import '../../parser/parse_worker.dart';
import '../../strings.dart';
import 'food_entry_screen.dart';

/// What the correction sheet needs from the food entry screen (grammar 8.3).
/// The screen owns the box, the added lines and the parser handle; the sheet
/// only asks questions and asks the screen to act. Every action completes when
/// it is done or has been refused (the screen then shows one plain line), and
/// the sheet closes either way. A [Listenable]: it changes when the box, the
/// newest result or the worker changes.
abstract class CorrectionHost implements Listenable {
  /// The screen's current handle. A sheet for a typed line closes when this is
  /// no longer the handle it was opened with (Try again made a new one).
  SessionHandle? get sheetHandle;

  /// False once the worker is dead; the sheet closes.
  bool get sheetUsable;

  /// The text in the box now.
  String get boxText;

  /// The worker for questions about a food that is not a typed line (rule 3:
  /// asked each time, never kept). Null when there is none.
  Future<ParseWorker?> sheetWorker();

  /// A plain line under the meal chips.
  void sheetNote(String text);

  Future<void> sheetPick(
    LineTap tap,
    String ref, {
    Marker marker = Marker.yourPick,
  });
  Future<void> sheetSetAmount(LineTap tap, double quantity, String unit);
  Future<void> sheetRemove(LineTap tap);
  Future<void> sheetForget(LineTap tap);
  Future<void> sheetUseFood(LineTap tap, String ref);
}

enum _Kind { typed, food, header }

/// The sheet that opens when a line is tapped, and for "Fix N items".
///
/// Three kinds: a typed line (candidates and the unit picker come from the
/// handle, for the span of [tap]), a line that is not typed (an added line or
/// an item of a saved meal: the worker's food level calls), and a saved meal
/// header (its multiplier and "Use a food instead").
///
/// It never acts on a stale span: it was opened for [LineTap.text], and it
/// closes, with one plain line, as soon as the box moves on or the handle
/// changes. A refused action closes it too.
class CorrectionSheet extends StatefulWidget {
  const CorrectionSheet({
    super.key,
    required this.host,
    required this.tap,
    required this.handle,
  });

  final CorrectionHost host;
  final LineTap tap;

  /// The handle the screen had when the sheet opened.
  final SessionHandle? handle;

  @override
  State<CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<CorrectionSheet> {
  late final _Kind _kind;
  Alternatives? _alts;
  var _units = const <UnitChoice>[];
  UnitChoice? _unit0;
  UnitChoice? _unit;
  String? _qtyError;
  final _qty = TextEditingController();
  final _search = TextEditingController();
  var _results = const <FoodChoice>[];
  var _searched = false;
  var _seq = 0;
  var _useFood = false;
  var _closed = false;
  var _busy = false;

  LineTap get _tap => widget.tap;
  Line get _line => _tap.line;
  bool get _notFound => _line.state == LineState.notFound;
  bool get _typedHeader => _kind == _Kind.header && _tap.added == null;

  /// A line whose sheet is about a span of the box's text.
  bool get _hasText => _tap.text != null;

  @override
  void initState() {
    super.initState();
    _kind = _line.state == LineState.aliasOrSavedMeal
        ? _Kind.header
        : (_tap.addedIndex != null || _tap.header != null)
        ? _Kind.food
        : _Kind.typed;
    final q = _kind == _Kind.header ? (_line.multiplier ?? 1) : _line.quantity;
    _qty.text = q == null ? '' : S.quantityText(q);
    if (_kind == _Kind.typed && _notFound) {
      _search.text = _line.foodText ?? _tap.typedText ?? '';
    }
    widget.host.addListener(_check);
    _load();
  }

  @override
  void dispose() {
    widget.host.removeListener(_check);
    _qty.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Closes the sheet when what it was opened for is gone.
  void _check() {
    if (_closed || _busy || !mounted) return;
    if (!widget.host.sheetUsable) return _pop();
    if (!_hasText) return;
    final moved =
        widget.host.boxText != _tap.text ||
        (_kind != _Kind.food &&
            !identical(widget.host.sheetHandle, widget.handle));
    if (moved) {
      widget.host.sheetNote(S.foodSheetStale);
      _pop();
    }
  }

  /// Closes this sheet, not whatever is on top of it (a weight sheet may be).
  void _pop() {
    if (_closed) return;
    _closed = true;
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  Future<void> _load() async {
    try {
      if (_kind == _Kind.typed) {
        final h = widget.handle;
        final text = _tap.text;
        final span = _line.span;
        if (h == null || text == null || span == null) return _pop();
        if (_notFound) {
          setState(() {});
          await _runSearch(_search.text);
          return;
        }
        final alts = await h.alternatives(text, span);
        final units = await h.unitChoices(text, span);
        if (!mounted || _closed) return;
        if (alts.current == null && alts.others.isEmpty) {
          // The box moved on under us: nothing here can be trusted.
          widget.host.sheetNote(S.foodSheetStale);
          return _pop();
        }
        setState(() {
          _alts = alts;
          _setUnits(units);
        });
      } else if (_kind == _Kind.food) {
        final ref = _line.foodRef;
        final w = await widget.host.sheetWorker();
        if (w == null || ref == null) return _pop();
        final units = await w.unitChoicesForFood(ref);
        if (!mounted || _closed) return;
        setState(() {
          _alts = Alternatives(
            FoodChoice(
              ref,
              _line.foodName ?? '',
              ref.startsWith('local:') ? 'local' : '',
              _line.nutrients[Nutrients.energy],
            ),
            const [],
          );
          _setUnits(units);
        });
      }
    } catch (_) {
      _pop(); // a dead worker says so on the screen; nothing is logged here
    }
  }

  void _setUnits(List<UnitChoice> units) {
    _units = units;
    final cur = _line.unitLabel ?? '';
    UnitChoice? found;
    for (final c in units) {
      if (c.unitText == cur || c.label == cur) {
        found = c;
        break;
      }
    }
    _unit0 = _unit = found;
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_seq;
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }
    try {
      final List<FoodChoice> found;
      final h = widget.handle;
      if (_kind == _Kind.typed && h != null) {
        found = await h.search(q, _tap.text!, _line.span!);
      } else {
        final w = await widget.host.sheetWorker();
        if (w == null) return _pop();
        found = await w.search(q);
      }
      if (!mounted || _closed || seq != _seq) return;
      setState(() {
        _results = found;
        _searched = true;
      });
    } catch (_) {
      if (mounted && seq == _seq) _pop();
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy || _closed) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
    _pop();
  }

  Future<void> _choose(FoodChoice f) => _act(
    () => _kind == _Kind.header
        ? widget.host.sheetUseFood(_tap, f.ref)
        : widget.host.sheetPick(_tap, f.ref),
  );

  double? _parseQty(String s) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return v != null && v.isFinite && v > 0 ? v : null;
  }

  Future<void> _done() async {
    if (_busy || _closed) return;
    // An added saved meal has no text to put a multiplier in.
    if (_kind == _Kind.header && !_typedHeader) return _pop();
    final q = _parseQty(_qty.text);
    if (q == null) {
      setState(() => _qtyError = S.sheetQuantityBad);
      return;
    }
    final orig = _kind == _Kind.header
        ? (_line.multiplier ?? 1)
        : _line.quantity;
    final unitChanged = _unit != _unit0;
    if (orig != null && (q - orig).abs() < 1e-9 && !unitChanged) return _pop();
    final unit = _kind == _Kind.header
        ? ''
        : (_unit?.unitText ?? _line.unitLabel ?? '');
    await _act(() => widget.host.sheetSetAmount(_tap, q, unit));
  }

  // Seams for the later tasks. Both are shown on a not found typed line only,
  // between the search box and the buttons.
  //
  // 2.11 "Scan its barcode": a button here. After a scan, send the snapshot
  // that holds the product, wait for this box's result with that snapshot
  // version, then call `widget.host.sheetPick(_tap, ref, marker:
  // Marker.scanned)` inside `_act`, which closes the sheet.
  static const _scanSeam = SizedBox.shrink();

  // 2.12 "Create a food called ...": a button here that opens the custom food
  // editor with `_line.foodText` as the name; when it is saved, send the
  // snapshot, wait the same way, and call `widget.host.sheetPick(_tap, ref)`
  // (marked "Your pick") inside `_act`.
  static const _createSeam = SizedBox.shrink();

  // Layout.

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final body = <Widget>[
      _title(theme),
      if (_kind == _Kind.header)
        ..._headerBody(theme)
      else if (_notFound)
        ..._notFoundBody(theme)
      else
        ..._foodBody(theme),
    ];
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _title(ThemeData theme) {
    final typed = _tap.typedText;
    final big = theme.textTheme.titleLarge;
    if (typed != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.sheetYouTyped, style: theme.textTheme.bodySmall),
          Semantics(header: true, child: Text(S.quoted(typed), style: big)),
        ],
      );
    }
    return Semantics(
      header: true,
      child: Text(_line.foodName ?? '', style: big),
    );
  }

  Widget _footer() {
    final showDone = !_notFound && !(_kind == _Kind.header && !_typedHeader);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          if (_kind == _Kind.typed && _line.fromLearnedMatch)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => _act(() => widget.host.sheetForget(_tap)),
              child: const Text(S.sheetForget),
            ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _act(() => widget.host.sheetRemove(_tap)),
            child: const Text(S.sheetRemove),
          ),
          if (showDone)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
              onPressed: _done,
              child: const Text(S.sheetDone),
            ),
        ],
      ),
    );
  }

  List<Widget> _foodBody(ThemeData theme) {
    final alts = _alts;
    final rows = <Widget>[
      if (alts != null) ...[
        if (alts.current != null) _row(alts.current!, current: true),
        for (final o in alts.others) _row(o, current: false),
      ],
    ];
    return [
      const SizedBox(height: 12),
      _amountRow(),
      const SizedBox(height: 16),
      Semantics(
        header: true,
        child: Text(S.sheetWhichFood, style: theme.textTheme.titleSmall),
      ),
      if (rows.isNotEmpty)
        Semantics(
          label: S.sheetFoodsLabel,
          container: true,
          child: _scrolling(rows),
        ),
      // Never learned for a line that is not typed (7.3) or an item of a
      // saved meal (6.4).
      if (_kind == _Kind.typed && _tap.header == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(S.sheetRemembered, style: theme.textTheme.bodyMedium),
        ),
      ..._searchPart(autofocus: false),
    ];
  }

  List<Widget> _notFoundBody(ThemeData theme) {
    final words = _line.foodText ?? _tap.typedText ?? '';
    return [
      const SizedBox(height: 8),
      if (_searched && _results.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(S.sheetNothingMatches(words)),
        ),
      ..._searchPart(autofocus: true),
      _scanSeam,
      _createSeam,
    ];
  }

  List<Widget> _headerBody(ThemeData theme) {
    return [
      const SizedBox(height: 12),
      if (_typedHeader) ...[
        SizedBox(
          width: 160,
          child: TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
            decoration: InputDecoration(
              labelText: S.sheetMultiplier,
              errorText: _qtyError,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (!_useFood)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => setState(() => _useFood = true),
            child: const Text(S.sheetUseFood),
          ),
        )
      else
        ..._searchPart(autofocus: true),
    ];
  }

  Widget _amountRow() {
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final qty = TextField(
      controller: _qty,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _done(),
      decoration: InputDecoration(
        labelText: S.sheetAmount,
        errorText: _qtyError,
        border: const OutlineInputBorder(),
      ),
    );
    final cur = _line.unitLabel ?? '';
    final unit = _units.isEmpty
        ? null
        : InputDecorator(
            decoration: const InputDecoration(
              labelText: S.sheetUnit,
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UnitChoice>(
                isExpanded: true,
                value: _unit,
                hint: Text(cur.isEmpty ? S.sheetBareCount : cur),
                items: [
                  for (final c in _units)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.label.isEmpty ? S.sheetBareCount : c.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (c) => setState(() => _unit = c),
              ),
            ),
          );
    if (unit == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 160, child: qty),
      );
    }
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [qty, const SizedBox(height: 8), unit],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 112, child: qty),
        const SizedBox(width: 8),
        Expanded(child: unit),
      ],
    );
  }

  /// The search box and what it found, below the list (grammar 8.3).
  List<Widget> _searchPart({required bool autofocus}) {
    return [
      TextField(
        controller: _search,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onChanged: _runSearch,
        decoration: const InputDecoration(
          labelText: S.sheetSearchHint,
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
      if (_searched && _results.isEmpty && !_notFound)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(S.sheetNoResults),
        ),
      if (_results.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _scrolling([
            for (final r in _results) _row(r, current: false, searched: true),
          ]),
        ),
    ];
  }

  /// A list of rows that scrolls inside itself once it is taller than four
  /// rows and a half (frame 4).
  Widget _scrolling(List<Widget> rows) {
    final h = MediaQuery.textScalerOf(context).scale(64) * 4.5;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h),
      child: ListView(primary: false, shrinkWrap: true, children: rows),
    );
  }

  Widget _row(FoodChoice f, {required bool current, bool searched = false}) {
    final amount = searched
        ? ''
        : S.sheetAmountShort(_line.quantity, _line.unitLabel);
    final sub = S.sheetRowSub(
      dataset: S.datasetName(f.dataset.isEmpty ? null : f.dataset),
      amount: amount,
      kcalValue: f.kcal,
      current: current,
    );
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: current,
      label: '${f.name}. $sub',
      hint: S.sheetRowHint,
      excludeSemantics: true,
      onTap: () => _choose(f),
      child: InkWell(
        onTap: () => _choose(f),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Icon(
                    current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(sub, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
