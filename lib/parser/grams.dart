// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// From an item's amount to grams for a given food: typed unit to grams
// (docs/parser-grammar.md 4.5), the default amount (4.6), what a line stores
// (4.7) and nutrient scaling. The food is given; matching text to a food is
// another task. Pure Dart.

import 'line.dart';
import 'portions.dart';
import 'tokens.dart';

/// Which rule gave an amount. Each value names its grammar rule.
enum AmountRule {
  /// 4.5 mass unit: quantity times the factor in 4.1.
  massDirect,

  /// 4.5 volume unit, step 1: the food's own portion with that unit.
  volumePortion,

  /// 4.5 volume unit, step 2: derived from another volume portion through the
  /// milliliter ratio.
  volumeDerived,

  /// 4.5 local foods: a volume unit on a base unit of `ml`, converted directly.
  volumeBase,

  /// 4.5 `serving` or `portion`: a portion whose unit phrase contains serving.
  servingPortion,

  /// 4.5 `serving` or `portion` with no such portion: one default portion.
  servingDefault,

  /// 4.5 local foods: a serving, or a bare count, on a base unit of `serving`.
  servingBase,

  /// 4.5 other household unit: a portion whose unit phrase names it.
  householdPortion,

  /// 4.5 bare count rule 1: a portion whose unit phrase has the size word.
  countSize,

  /// 4.5 bare count rule 2: a one word unit phrase that is a food word.
  countFoodWord,

  /// 4.5 bare count rule 3: the FNDDS default portion.
  countDefaultPortion,

  /// 4.5 bare count rule 4: a medium or regular portion.
  countMedium,

  /// 4.5 bare count rule 5: the first portion that is neither mass nor volume.
  countNonMeasure,

  /// 4.6 rule 1: the learned amount.
  defaultLearned,

  /// 4.6 rule 2: the FNDDS "Quantity not specified" portion.
  defaultNotSpecified,

  /// 4.6 rule 3: the first medium or regular portion.
  defaultMedium,

  /// 4.6 rule 4: the first portion that is neither mass nor volume.
  defaultNonMeasure,

  /// 4.6 rule 5: the first portion.
  defaultFirstPortion,

  /// 4.6 rule 6: 100 g.
  defaultHundredGrams,

  /// 4.6 local foods: 1 serving when the base unit is `serving`.
  defaultServing,

  /// 4.6 local foods: the base amount and unit.
  defaultBase,
}

/// What a line stores for its amount (4.7), and how it got there.
class AmountResult {
  const AmountResult({
    required this.quantity,
    required this.unitLabel,
    required this.baseQuantity,
    required this.baseUnit,
    required this.rule,
    required this.assumed,
    this.portionLabel,
  });

  /// `meal_entries.quantity`: the typed quantity after multipliers, or the
  /// default's quantity.
  final double quantity;

  /// `meal_entries.unit_label`: the canonical unit (`g`, `oz`, `fl oz`, `tbsp`,
  /// `slice`), the size word used as a unit (`large`), the default portion's
  /// unit phrase (`small`, `cup, cooked`) or an empty string for a bare count.
  final String unitLabel;

  /// `base_quantity` and `base_unit`: grams and `g`, or the amount and unit of
  /// a local food whose base unit is `ml` or `serving`.
  final double baseQuantity;
  final String baseUnit;

  /// The rule that produced the amount.
  final AmountRule rule;

  /// True when the line is "amount assumed" (8.1): no amount was typed, the
  /// typed unit could not be converted, or the amount is a range midpoint. The
  /// caller sets the state and the Assumed marker.
  final bool assumed;

  /// The label of the portion the grams came from, when one was used.
  final String? portionLabel;

  @override
  String toString() =>
      'AmountResult($quantity "$unitLabel" = $baseQuantity $baseUnit, '
      '$rule, assumed: $assumed)';
}

/// An amount learned from a correction (7.2): the quantity and the unit label
/// as stored in 4.7.
class LearnedAmount {
  const LearnedAmount(this.quantity, this.unitLabel);
  final double quantity;
  final String unitLabel;
}

/// A food as far as amounts are concerned: its portions, its base unit and
/// amount, and its nutrients per base amount.
class PortionFood {
  /// A USDA reference food: nutrients per 100 g, portions in grams.
  PortionFood.usda({
    required List<(String, double)> portions,
    this.nutrients = const {},
  }) : portions = Portions.read(portions),
       baseUnit = 'g',
       baseAmount = 100,
       isLocal = false;

  /// One of the user's own foods (custom food, recipe, cached product).
  /// [baseUnit] is `g`, `ml` or `serving`; nutrients are per [baseAmount] of
  /// it; each portion's number is an amount in the base unit.
  PortionFood.local({
    required this.baseUnit,
    required this.baseAmount,
    required List<(String, double)> portions,
    this.nutrients = const {},
  }) : portions = Portions.read(portions),
       isLocal = true;

  final Portions portions;
  final String baseUnit;
  final double baseAmount;

  /// Nutrient id to the amount per [baseAmount] of [baseUnit].
  final Map<int, double> nutrients;
  final bool isLocal;
}

/// The nutrients of a line: each nutrient the food lists, scaled to
/// [baseQuantity] of its base unit (USDA values are per 100 g, so value times
/// grams divided by 100). Not rounded. A nutrient the food does not list is
/// absent, never zero.
Map<int, double> scaleNutrients(PortionFood food, double baseQuantity) => {
  for (final e in food.nutrients.entries)
    e.key: e.value * baseQuantity / food.baseAmount,
};

/// The amount of a line (4.5 and 4.6): the typed amount when there is one and
/// it converts for [food], otherwise the default amount. [foodWords] are the
/// item's food words after typo correction, used for the bare count rule 2.
/// [learned] is the learned amount for the item's key, if any (4.6 rule 1).
AmountResult resolveAmount(
  ItemDraft draft,
  PortionFood food, {
  List<String> foodWords = const [],
  LearnedAmount? learned,
}) {
  final q = draft.quantity;
  if (q != null) {
    final r = convertAmount(draft, food, foodWords: foodWords);
    if (r != null) return r;
  }
  return defaultAmount(food, learned: learned, foodWords: foodWords);
}

/// The typed amount of [draft] in the food's base unit (4.5), or null when
/// there is no quantity or the unit cannot be converted for this food. The
/// result is assumed only for a range.
AmountResult? convertAmount(
  ItemDraft draft,
  PortionFood food, {
  List<String> foodWords = const [],
}) {
  final q = draft.quantity;
  if (q == null) return null;
  final c = _convert(food, q, draft.unit, draft.size, foodWords);
  if (c == null) return null;
  return AmountResult(
    quantity: q,
    unitLabel: c.unitLabel,
    baseQuantity: c.base,
    baseUnit: food.baseUnit,
    rule: c.rule,
    assumed: draft.isRange,
    portionLabel: c.portion?.label,
  );
}

/// The default amount (4.6), used when nothing was typed or the typed unit
/// cannot be converted. Always assumed.
AmountResult defaultAmount(
  PortionFood food, {
  LearnedAmount? learned,
  List<String> foodWords = const [],
}) {
  if (learned != null) {
    final c = _convertLabel(
      food,
      learned.quantity,
      learned.unitLabel,
      foodWords,
    );
    if (c != null) {
      return AmountResult(
        quantity: learned.quantity,
        unitLabel: c.unitLabel,
        baseQuantity: c.base,
        baseUnit: food.baseUnit,
        rule: AmountRule.defaultLearned,
        assumed: true,
        portionLabel: c.portion?.label,
      );
    }
  }
  final d = _defaultOf(food);
  return AmountResult(
    quantity: d.quantity,
    unitLabel: d.unitLabel,
    baseQuantity: d.base,
    baseUnit: food.baseUnit,
    rule: d.rule,
    assumed: true,
    portionLabel: d.portion?.label,
  );
}

// Conversion of a typed amount (4.5).

typedef _Conv = ({
  double base,
  String unitLabel,
  AmountRule rule,
  Portion? portion,
});

UnitDef? _flOz;
UnitDef get _flOzDef =>
    _flOz ??= unitTable.firstWhere((e) => e.def.label == 'fl oz').def;

_Conv? _convert(
  PortionFood f,
  double q,
  UnitDef? typed,
  String? size,
  List<String> foodWords,
) {
  var unit = typed;
  // 4.2: oz is a fluid ounce when the food has a "fl oz" portion.
  if (unit != null &&
      unit.kind == UnitKind.mass &&
      unit.label == 'oz' &&
      f.portions.hasFluidOunce) {
    unit = _flOzDef;
  }
  if (unit == null) return _bareCount(f, q, size, foodWords);

  switch (unit.kind) {
    case UnitKind.mass:
      // 4.5 mass unit; a local food whose base unit is not grams cannot.
      if (f.baseUnit != 'g') return null;
      return (
        base: q * unit.factor,
        unitLabel: unit.label,
        rule: AmountRule.massDirect,
        portion: null,
      );
    case UnitKind.volume:
      return _volume(f, q, unit);
    case UnitKind.count:
      return _household(f, q, unit, size);
  }
}

_Conv? _volume(PortionFood f, double q, UnitDef unit) {
  if (f.baseUnit == 'serving') return null;
  if (f.baseUnit == 'ml') {
    return (
      base: q * unit.factor,
      unitLabel: unit.label,
      rule: AmountRule.volumeBase,
      portion: null,
    );
  }
  final usable = f.portions.usable;
  // Step 1: the first plain portion with this unit, else the first one.
  final own = usable.where((p) => p.unit?.label == unit.label).toList();
  if (own.isNotEmpty) {
    final p = own.firstWhere((p) => p.plain, orElse: () => own.first);
    return (
      base: q * p.gramsPerUnit,
      unitLabel: unit.label,
      rule: AmountRule.volumePortion,
      portion: p,
    );
  }
  // Step 2: scale any volume portion by the milliliter ratio.
  final volumes = usable.where((p) => p.unit?.kind == UnitKind.volume).toList();
  if (volumes.isNotEmpty) {
    final p = volumes.firstWhere((p) => p.plain, orElse: () => volumes.first);
    return (
      base: q * p.gramsPerUnit * unit.factor / p.unit!.factor,
      unitLabel: unit.label,
      rule: AmountRule.volumeDerived,
      portion: p,
    );
  }
  return null;
}

_Conv? _household(PortionFood f, double q, UnitDef unit, String? size) {
  final isServing = unit.label == 'serving' || unit.label == 'portion';
  if (isServing && f.baseUnit == 'serving') {
    return (
      base: q,
      unitLabel: unit.label,
      rule: AmountRule.servingBase,
      portion: null,
    );
  }
  final named = f.portions.usable
      .where((p) => p.phraseHasUnit(isServing ? 'serving' : unit.label))
      .toList();
  if (named.isNotEmpty) {
    final p = _pickBySize(named, size);
    return (
      base: q * p.gramsPerUnit,
      unitLabel: unit.label,
      rule: isServing ? AmountRule.servingPortion : AmountRule.householdPortion,
      portion: p,
    );
  }
  if (isServing) {
    // "serving" always converts: one default portion (4.6).
    final d = _defaultOf(f);
    return (
      base: q * d.base,
      unitLabel: unit.label,
      rule: AmountRule.servingDefault,
      portion: d.portion,
    );
  }
  return null;
}

/// 4.5: the first containing the typed size word; else the first containing
/// medium or regular; else the first.
Portion _pickBySize(List<Portion> list, String? size) {
  if (size != null) {
    for (final p in list) {
      if (p.phraseHasSize(size)) return p;
    }
  }
  for (final p in list) {
    if (p.isMediumOrRegular) return p;
  }
  return list.first;
}

_Conv? _bareCount(
  PortionFood f,
  double q,
  String? size,
  List<String> foodWords,
) {
  if (f.baseUnit == 'serving') {
    return (
      base: q,
      unitLabel: '',
      rule: AmountRule.servingBase,
      portion: null,
    );
  }
  final usable = f.portions.usable;
  _Conv hit(Portion p, AmountRule rule, [String unitLabel = '']) =>
      (base: q * p.gramsPerUnit, unitLabel: unitLabel, rule: rule, portion: p);

  // 1. A size word was typed: the first portion whose unit phrase has it. The
  // size word is the unit label (4.7).
  if (size != null) {
    for (final p in usable) {
      if (p.phraseHasSize(size)) return hit(p, AmountRule.countSize, size);
    }
  }
  // 2. A one word unit phrase that is one of the food words.
  final stems = {for (final w in foodWords) _stem(w.toLowerCase())};
  for (final p in usable) {
    final words = p.phraseWords;
    if (words.length == 1 && stems.contains(_stem(words.first))) {
      return hit(p, AmountRule.countFoodWord);
    }
  }
  // 3. The FNDDS default portion.
  final d = f.portions.defaultPortion;
  if (d != null) {
    return (
      base: q * d.grams,
      unitLabel: '',
      rule: AmountRule.countDefaultPortion,
      portion: d,
    );
  }
  // 4. A medium or regular portion.
  for (final p in usable) {
    if (p.isMediumOrRegular) return hit(p, AmountRule.countMedium);
  }
  // 5. The first portion that is neither mass nor volume.
  for (final p in usable) {
    if (_isNeither(p)) return hit(p, AmountRule.countNonMeasure);
  }
  // 6. Cannot be converted.
  return null;
}

bool _isNeither(Portion p) => p.unit == null || p.unit!.kind == UnitKind.count;

/// A learned amount's unit label (4.7) back to an amount: empty is a bare
/// count; a unit spelling is that unit; a size word is a size; anything else
/// (`cup, cooked`, `drink (12 fl oz)`) is a portion with that unit label.
_Conv? _convertLabel(
  PortionFood f,
  double q,
  String label,
  List<String> foodWords,
) {
  final text = label.trim();
  if (text.isEmpty) return _bareCount(f, q, null, foodWords);
  final lower = text.toLowerCase();
  final unit = unitForWord(lower) ?? _singleLetter(text);
  if (unit != null) return _convert(f, q, unit, null, foodWords);
  if (sizeWords.containsKey(lower)) {
    return _bareCount(f, q, sizeWords[lower], foodWords);
  }
  for (final p in f.portions.usable) {
    if (p.unitLabel.toLowerCase() == lower) {
      return (
        base: q * p.gramsPerUnit,
        unitLabel: p.unitLabel,
        rule: AmountRule.defaultLearned,
        portion: p,
      );
    }
  }
  return null;
}

/// The one letter canonical labels (`g`, `l`) that [unitForWord] leaves out.
UnitDef? _singleLetter(String s) {
  for (final e in unitTable) {
    if (e.def.label == s && s.length == 1) return e.def;
  }
  return null;
}

// The default amount (4.6).

typedef _Default = ({
  double quantity,
  String unitLabel,
  double base,
  AmountRule rule,
  Portion? portion,
});

/// 4.6 without the learned amount: rules 2 to 6, or for a local food: 1
/// serving, its first portion, its base amount and unit.
_Default _defaultOf(PortionFood f) {
  final usable = f.portions.usable;

  _Default fromPortion(Portion p, AmountRule rule) {
    // A portion of amount 1 with exactly this weight is shown as quantity 1
    // with its unit phrase; otherwise the grams are shown.
    final g = p.grams;
    for (final u in usable) {
      if (u.amount == 1 && (u.grams - g).abs() < 1e-9) {
        return (
          quantity: 1,
          unitLabel: u.unitLabel,
          base: g,
          rule: rule,
          portion: u,
        );
      }
    }
    return (
      quantity: g,
      unitLabel: f.baseUnit,
      base: g,
      rule: rule,
      portion: p,
    );
  }

  if (f.isLocal) {
    if (f.baseUnit == 'serving') {
      return (
        quantity: 1,
        unitLabel: 'serving',
        base: 1,
        rule: AmountRule.defaultServing,
        portion: null,
      );
    }
    if (usable.isNotEmpty) {
      return fromPortion(usable.first, AmountRule.defaultFirstPortion);
    }
    return (
      quantity: f.baseAmount,
      unitLabel: f.baseUnit,
      base: f.baseAmount,
      rule: AmountRule.defaultBase,
      portion: null,
    );
  }

  final d = f.portions.defaultPortion;
  if (d != null) return fromPortion(d, AmountRule.defaultNotSpecified);
  for (final p in usable) {
    if (p.isMediumOrRegular) return fromPortion(p, AmountRule.defaultMedium);
  }
  for (final p in usable) {
    if (_isNeither(p)) return fromPortion(p, AmountRule.defaultNonMeasure);
  }
  if (usable.isNotEmpty) {
    return fromPortion(usable.first, AmountRule.defaultFirstPortion);
  }
  return (
    quantity: 100,
    unitLabel: 'g',
    base: 100,
    rule: AmountRule.defaultHundredGrams,
    portion: null,
  );
}

// Words.

/// The plural rules of 5.2 step 3, so `eggs` and `egg` compare equal.
String _stem(String w) {
  if (w.length < 4) return w;
  if (w.endsWith('sses')) return '${w.substring(0, w.length - 4)}ss';
  if (w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.endsWith('oes')) return w.substring(0, w.length - 2);
  if (w.endsWith('ches') ||
      w.endsWith('shes') ||
      w.endsWith('xes') ||
      w.endsWith('zes')) {
    return w.substring(0, w.length - 2);
  }
  if (w.endsWith('s') &&
      !w.endsWith('ss') &&
      !w.endsWith('us') &&
      !w.endsWith('is')) {
    return w.substring(0, w.length - 1);
  }
  return w;
}
