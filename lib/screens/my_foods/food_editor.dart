// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../clock.dart';
import '../../data/database.dart';
import '../../data/food_library_data.dart';
import '../../data/nutrients.dart';
import '../../data/off_client.dart';
import '../../strings.dart';

// The custom food editor (food-editor.html frame 1).
//
// Required: a name, the amount the numbers are for, and calories. Every other
// nutrient may be left empty: an empty one is stored as absent and shown as
// "not listed", while a typed 0 is stored as 0. The numbers are for one
// serving, for 100 g or for 100 ml (or a different amount of these, which is
// worked out per 1 serving or per 100 on the way in, because that is how the
// data layer keeps them).

/// What an editor hands back when it closes with a change.
sealed class MyFoodResult {
  const MyFoodResult();
}

/// The food or recipe was written. [food] is the row read back.
class MyFoodSaved extends MyFoodResult {
  const MyFoodSaved(this.food);
  final FoodDetail food;
}

/// The food or recipe was deleted (archived). [barcode] is the barcode it had,
/// for Undo to put back.
class MyFoodRemoved extends MyFoodResult {
  const MyFoodRemoved(this.food, this.barcode);
  final FoodDetail food;
  final String? barcode;
}

final _plainNumber = RegExp(r'^(\d+\.?\d*|\.\d+)$');

// A whole part that is not 0, a comma, and exactly three digits: "1,000" reads
// as a thousand in some places and as 1 in others, so it is refused.
final _thousandsComma = RegExp(r'^0*[1-9]\d*,\d{3}$');

/// True when [text] looks like a number written with a thousands comma.
bool hasThousandsComma(String text) => _thousandsComma.hasMatch(text.trim());

/// The message for a typed number that [parseFoodNumber] refused: [plain] for
/// anything wrong, or a note about the comma when that is the reason.
String foodNumberProblem(String text, String plain) =>
    hasThousandsComma(text) ? S.foodEditNumberComma : plain;

/// Reads a typed number the way the weight sheet does (a comma counts as the
/// decimal point), without its rounding. Null when it is not a plain number
/// from 0 to 100,000, and for a number with a thousands comma such as "1,000".
double? parseFoodNumber(String text) {
  if (hasThousandsComma(text)) return null;
  final t = text.trim().replaceAll(',', '.');
  if (!_plainNumber.hasMatch(t)) return null;
  final v = double.parse(t);
  return v.isFinite && v <= 100000 ? v : null;
}

/// A typed barcode in its one stored form, or null when it is not one.
String? _storedBarcode(String raw) {
  final t = raw.trim();
  if (!RegExp(r'^\d+$').hasMatch(t)) return null;
  final upcE = isUpcE(t);
  if (!upcE && !barcodeCheckOk(t)) return null;
  return barcodeForm(t, upcE: upcE);
}

/// Closes [context]'s own route and nothing else, whatever is on top of it.
void popRouteOf<T>(BuildContext context, T result) {
  final route = ModalRoute.of(context);
  final nav = Navigator.of(context);
  if (route == null || route.isCurrent) {
    nav.pop(result);
  } else {
    nav.removeRoute(route, result);
  }
}

enum _Unit { serving, g, ml }

class _Portion {
  final name = TextEditingController();
  final weight = TextEditingController();
  void dispose() {
    name.dispose();
    weight.dispose();
  }
}

class FoodEditor extends StatefulWidget {
  const FoodEditor({super.key, this.food, this.name, this.barcode});

  /// The custom food to change, or null for a new one.
  final FoodDetail? food;

  /// For a new food: the name to start with (the words typed in Food entry).
  final String? name;

  /// For a new food: the barcode to start with, in its stored form.
  final String? barcode;

  @override
  State<FoodEditor> createState() => _FoodEditorState();
}

class _FoodEditorState extends State<FoodEditor> {
  late AppDatabase _db;
  late Clock _clock;
  var _ready = false;

  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _amount = TextEditingController(text: '1');
  final _weight = TextEditingController();
  final _values = {
    for (final n in Nutrients.tracked) n.id: TextEditingController(),
  };
  final _portions = <_Portion>[];
  final _nodes = <Object, FocusNode>{};
  var _unit = _Unit.serving;
  var _showMore = false;

  final _errors = <Object, String>{};
  String? _error;
  var _busy = false;
  var _writing = false;

  bool get _isNew => widget.food == null;

  @override
  void initState() {
    super.initState();
    final f = widget.food;
    if (f == null) {
      _name.text = widget.name ?? '';
      _barcode.text = widget.barcode ?? '';
      return;
    }
    _name.text = f.food.name;
    _brand.text = f.food.brand ?? '';
    _barcode.text = f.food.barcode ?? '';
    switch (f.basis) {
      case FoodBasis.perServing:
        _unit = _Unit.serving;
        _amount.text = '1';
      case FoodBasis.per100g:
        _unit = _Unit.g;
        _amount.text = '100';
      case FoodBasis.per100ml:
        _unit = _Unit.ml;
        _amount.text = '100';
    }
    final s = f.servingSize;
    if (s != null) _weight.text = S.numberText(s);
    for (final e in f.nutrients.entries) {
      _values[e.key]?.text = S.numberText(e.value);
    }
    for (final p in f.portions) {
      if (p.label == servingLabel) continue;
      _portions.add(
        _Portion()
          ..name.text = p.label.startsWith('1 ')
              ? p.label.substring(2)
              : p.label
          ..weight.text = S.numberText(p.baseQuantity),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final scope = AppScope.of(context);
    _db = scope.db;
    _clock = scope.clock;
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _barcode, _amount, _weight]) {
      c.dispose();
    }
    for (final c in _values.values) {
      c.dispose();
    }
    for (final p in _portions) {
      p.dispose();
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _node(Object key) => _nodes.putIfAbsent(key, FocusNode.new);

  String get _weightSuffix => _unit == _Unit.ml ? S.unitMl : S.unitG;

  /// Portions need a weight: the base is grams or ml, or a serving that has a
  /// weight. Without one the base is "serving" and nothing can be weighed.
  bool get _portionsOk =>
      _unit != _Unit.serving || parseFoodNumber(_weight.text) != null;

  void _setUnit(_Unit u) {
    if (u == _unit) return;
    setState(() {
      // The amount keeps what the user typed, unless it is still the usual
      // amount for the old unit.
      final usual = _unit == _Unit.serving ? '1' : '100';
      if (_amount.text.trim() == usual) {
        _amount.text = u == _Unit.serving ? '1' : '100';
      }
      _unit = u;
    });
  }

  // Save.

  /// Checks every field and sets the errors beside them. Returns the food to
  /// write, or null when anything is wrong (nothing is written then).
  CustomFoodInput? _check() {
    final errors = <Object, String>{};
    final name = _name.text.trim();
    if (name.isEmpty) errors['name'] = S.foodEditNameEmpty;

    final code = _barcode.text.trim();
    String? barcode;
    if (code.isNotEmpty) {
      barcode = _storedBarcode(code);
      if (barcode == null) errors['barcode'] = S.foodEditBarcodeBad;
    }

    final qty = parseFoodNumber(_amount.text);
    if (qty == null || qty <= 0) {
      errors['amount'] = foodNumberProblem(_amount.text, S.foodEditAmountBad);
    }

    double? serving;
    if (_weight.text.trim().isNotEmpty) {
      serving = parseFoodNumber(_weight.text);
      if (serving == null || serving <= 0) {
        errors['weight'] = foodNumberProblem(_weight.text, S.foodEditWeightBad);
        serving = null;
      }
    }

    final typed = <int, double>{};
    for (final n in Nutrients.tracked) {
      final text = _values[n.id]!.text;
      if (text.trim().isEmpty) {
        if (n.id == Nutrients.energy) errors[n.id] = S.foodEditCaloriesEmpty;
        continue;
      }
      final v = parseFoodNumber(text);
      if (v == null) {
        errors[n.id] = foodNumberProblem(text, S.foodEditNumberBad);
      } else {
        typed[n.id] = v;
      }
    }

    // What the typed values come to in 100 g or 100 ml, when that can be
    // worked out: a serving with no weight has no such check.
    if (qty != null && qty > 0) {
      final per100 = switch (_unit) {
        _Unit.serving => serving == null ? null : 100 / (qty * serving),
        _ => 100 / qty,
      };
      if (per100 != null) {
        final unit = _unit == _Unit.ml ? S.unitMl : S.unitG;
        for (final n in Nutrients.tracked) {
          final v = typed[n.id];
          if (v == null || errors.containsKey(n.id)) continue;
          if (n.id == Nutrients.energy) {
            if (v * per100 > 900) errors[n.id] = S.foodEditKcalTooHigh(unit);
          } else {
            final grams =
                v /
                switch (n.unit) {
                  'mg' => 1000,
                  'µg' => 1000000,
                  _ => 1,
                };
            if (grams * per100 > 100) {
              errors[n.id] = S.foodEditNutrientTooHigh(unit);
            }
          }
        }
      }
    }

    final portions = <PortionInput>[];
    var portionBad = false;
    for (var i = 0; i < _portions.length; i++) {
      final p = _portions[i];
      final label = p.name.text.trim();
      final w = parseFoodNumber(p.weight.text);
      if (label.toLowerCase() == 'serving') {
        errors['portionName$i'] = S.foodEditPortionServing;
      } else if (RegExp(r'^\d').hasMatch(label)) {
        errors['portionName$i'] = S.foodEditPortionDigit;
      } else if (label.isEmpty || w == null || w <= 0) {
        portionBad = true;
      } else {
        portions.add(PortionInput('1 $label', w));
      }
    }
    if (portionBad) {
      errors['portions'] = S.foodEditPortionBad;
    } else if (portions.isNotEmpty && !_portionsOk) {
      errors['portions'] = S.foodEditPortionsNeedWeight;
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _error = errors.isEmpty ? null : S.foodEditFix;
      // A mistake in a nutrient that is out of sight opens the part.
      if (errors.keys.any((k) => k is int && _hiddenByDefault(k))) {
        _showMore = true;
      }
    });
    if (errors.isNotEmpty) {
      _focusFirst(errors.keys);
      return null;
    }

    // The data layer keeps values for one serving, or for 100 g or 100 ml.
    final scale = (_unit == _Unit.serving ? 1 : 100) / qty!;
    return CustomFoodInput(
      name: name,
      brand: _brand.text,
      barcode: barcode,
      basis: switch (_unit) {
        _Unit.serving => FoodBasis.perServing,
        _Unit.g => FoodBasis.per100g,
        _Unit.ml => FoodBasis.per100ml,
      },
      nutrients: {for (final e in typed.entries) e.key: e.value * scale},
      servingSize: serving,
      portions: portions,
    );
  }

  bool _hiddenByDefault(int id) {
    final i = Nutrients.tracked.indexWhere((n) => n.id == id);
    return i >= _mainCount;
  }

  /// Puts the cursor in the first field that has an error, which also scrolls
  /// it into view.
  void _focusFirst(Iterable<Object> keys) {
    final order = <Object>[
      'name',
      'barcode',
      'amount',
      'weight',
      for (final n in Nutrients.tracked) n.id,
      for (var i = 0; i < _portions.length; i++) 'portionName$i',
    ];
    for (final k in order) {
      if (keys.contains(k)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _node(k).requestFocus();
        });
        return;
      }
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    var finished = false;
    try {
      final input = _check();
      if (input == null) return;
      final code = input.barcode;
      if (code != null) {
        final other = await findFoodByBarcode(_db, code);
        if (!mounted) return;
        if (other != null && other.id != widget.food?.food.id) {
          setState(() {
            _errors['barcode'] = S.foodEditBarcodeTaken;
            _error = S.foodEditFix;
          });
          _focusFirst(const ['barcode']);
          return;
        }
      }
      setState(() => _writing = true);
      final FoodDetail saved;
      try {
        final f = widget.food;
        saved = f == null
            ? await _db.createCustomFood(input, _clock())
            : await _db.editCustomFood(f.food.id, input, _clock());
      } catch (_) {
        if (mounted) setState(() => _error = S.myFoodWriteFailed);
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
    final f = widget.food;
    if (f == null || _busy) return;
    setState(() {
      _busy = true;
      _writing = true;
      _error = null;
    });
    try {
      final now = await _db.loadFood(f.food.id);
      final gone = await _db.archiveFood(f.food.id, _clock());
      if (!mounted) return;
      setState(() => _writing = false);
      popRouteOf<MyFoodResult>(context, MyFoodRemoved(gone, now?.food.barcode));
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

  // Layout.

  static const _mainCount = 4;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_writing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? S.foodEditNew : widget.food!.food.name),
          actions: [
            if (!_isNew)
              PopupMenuButton<String>(
                tooltip: S.myFoodsMenu,
                enabled: !_busy,
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text(S.foodDelete)),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: ContentWidth(child: _fields(context))),
              _bar(context),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label, {
    Object? errorKey,
    String? suffix,
    String? hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    errorText: errorKey == null ? null : _errors[errorKey],
    errorMaxLines: 4,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    border: const OutlineInputBorder(),
  );

  static const _numberKeys = TextInputType.numberWithOptions(decimal: true);

  Widget _fields(BuildContext context) {
    final theme = Theme.of(context);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    final others = Nutrients.tracked.length - _mainCount;
    final amount = TextField(
      controller: _amount,
      focusNode: _node('amount'),
      keyboardType: _numberKeys,
      onChanged: (_) => setState(() {}),
      decoration: _decoration(S.foodEditAmount, errorKey: 'amount'),
    );
    final unit = DropdownButtonFormField<_Unit>(
      initialValue: _unit,
      isExpanded: true,
      decoration: _decoration(S.foodEditUnit),
      items: const [
        DropdownMenuItem(value: _Unit.serving, child: Text(S.foodUnitServing)),
        DropdownMenuItem(value: _Unit.g, child: Text(S.foodUnitG)),
        DropdownMenuItem(value: _Unit.ml, child: Text(S.foodUnitMl)),
      ],
      onChanged: (u) {
        if (u != null) _setUnit(u);
      },
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            focusNode: _node('name'),
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(S.foodEditName, errorKey: 'name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _brand,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration(S.foodEditBrand),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _barcode,
            focusNode: _node('barcode'),
            keyboardType: TextInputType.number,
            decoration: _decoration(S.foodEditBarcode, errorKey: 'barcode'),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(S.foodEditFor, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          if (stacked) ...[
            amount,
            const SizedBox(height: 16),
            unit,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: amount),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: unit),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _weight,
            focusNode: _node('weight'),
            keyboardType: _numberKeys,
            onChanged: (_) => setState(() {}),
            decoration: _decoration(
              S.foodEditWeight,
              errorKey: 'weight',
              suffix: _weightSuffix,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _mainCount; i++) _nutrient(Nutrients.tracked[i]),
          ListTile(
            minTileHeight: 56,
            contentPadding: EdgeInsets.zero,
            title: const Text(S.foodEditMore),
            subtitle: Text(S.foodEditMoreHint(others - 3)),
            trailing: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _showMore = !_showMore),
          ),
          if (_showMore)
            for (var i = _mainCount; i < Nutrients.tracked.length; i++)
              _nutrient(Nutrients.tracked[i]),
          const SizedBox(height: 8),
          ..._portionsPart(theme),
        ],
      ),
    );
  }

  Widget _nutrient(Nutrient n) {
    final required = n.id == Nutrients.energy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _values[n.id],
        focusNode: _node(n.id),
        keyboardType: _numberKeys,
        onChanged: (_) => setState(() {}),
        decoration: _decoration(
          S.nutrientName(n.id),
          errorKey: n.id,
          suffix: S.nutrientUnit(n.unit),
          hint: required ? null : S.notListed,
        ),
      ),
    );
  }

  List<Widget> _portionsPart(ThemeData theme) {
    return [
      Semantics(
        header: true,
        child: Text(S.foodEditPortions, style: theme.textTheme.titleSmall),
      ),
      if (_portions.isEmpty) const Text(S.foodEditPortionsNone),
      for (var i = 0; i < _portions.length; i++) _portionRow(i),
      if (_portionsOk)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => setState(() => _portions.add(_Portion())),
            child: const Text(S.foodEditPortionAdd),
          ),
        )
      else
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(S.foodEditPortionsNeedWeight),
        ),
      if (_errors['portions'] != null)
        Semantics(
          liveRegion: true,
          child: Text(
            _errors['portions']!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      const SizedBox(height: 16),
    ];
  }

  Widget _portionRow(int i) {
    final p = _portions[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: p.name,
            focusNode: _node('portionName$i'),
            textCapitalization: TextCapitalization.none,
            decoration: _decoration(
              S.foodEditPortionName,
              errorKey: 'portionName$i',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: p.weight,
                  keyboardType: _numberKeys,
                  decoration: _decoration(
                    S.foodEditPortionWeight,
                    suffix: _weightSuffix,
                  ),
                ),
              ),
              IconButton(
                tooltip: S.foodEditPortionRemove(i + 1),
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.close),
                onPressed: () =>
                    setState(() => _portions.removeAt(i).dispose()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      elevation: 3,
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_error!),
                    ),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
                onPressed: _busy ? null : _save,
                child: const Text(S.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
