// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Grammar 4.5 to 4.7 (docs/parser-grammar.md): typed unit to grams, the default
// amount, what a line stores and nutrient scaling. Each rule is tested alone on
// a small hand-made portion list, then the order between rules, then the real
// bundled database and the worked examples of 11.2. Every reason names the
// grammar rule or example.

import 'dart:io';

import 'package:daybook/data/food_reference.dart';
import 'package:daybook/parser/grams.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/normalize.dart';
import 'package:daybook/parser/portions.dart';
import 'package:daybook/parser/split.dart';
import 'package:daybook/parser/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import 'worked_examples.dart';

UnitDef _u(String label) {
  for (final e in unitTable) {
    if (e.def.label == label) return e.def;
  }
  return UnitDef(label, UnitKind.count, 0);
}

ItemDraft _item({double? q, String? unit, String? size, bool range = false}) =>
    ItemDraft(
      span: const Span(0, 0),
      foodText: '',
      hasFoodWords: true,
      quantity: q,
      unit: unit == null ? null : _u(unit),
      size: size,
      isRange: range,
    );

PortionFood _usda(
  List<(String, double)> rows, {
  Map<int, double> nutrients = const {},
}) => PortionFood.usda(portions: rows, nutrients: nutrients);

PortionFood _local(
  String baseUnit,
  double baseAmount, [
  List<(String, double)> rows = const [],
]) => PortionFood.local(
  baseUnit: baseUnit,
  baseAmount: baseAmount,
  portions: rows,
);

/// Checks an amount against what the rule says. [rule] is the grammar section
/// used in the failure message.
void _amount(
  String rule,
  AmountResult? r, {
  required double base,
  String? label,
  AmountRule? via,
  bool? assumed,
  double? quantity,
  String? baseUnit,
}) {
  expect(r, isNotNull, reason: 'grammar $rule: the amount converts');
  r!;
  expect(r.baseQuantity, closeTo(base, 0.001), reason: 'grammar $rule: base');
  if (label != null) {
    expect(r.unitLabel, label, reason: 'grammar $rule: unit label');
  }
  if (via != null) expect(r.rule, via, reason: 'grammar $rule: rule');
  if (assumed != null) {
    expect(r.assumed, assumed, reason: 'grammar $rule: assumed');
  }
  if (quantity != null) {
    expect(r.quantity, closeTo(quantity, 1e-9), reason: 'grammar $rule: qty');
  }
  if (baseUnit != null) {
    expect(r.baseUnit, baseUnit, reason: 'grammar $rule: base unit');
  }
}

void main() {
  group('4.5 mass unit', () {
    test('4.5 mass: quantity times the factor, whatever the portions', () {
      final f = _usda([('1 cup', 240), ('1 oz, cooked', 99)]);
      _amount(
        '4.5 g',
        convertAmount(_item(q: 150, unit: 'g'), f),
        base: 150,
        label: 'g',
        via: AmountRule.massDirect,
        assumed: false,
      );
      _amount(
        '4.5 kg',
        convertAmount(_item(q: 1.5, unit: 'kg'), f),
        base: 1500,
      );
      _amount('4.5 mg', convertAmount(_item(q: 500, unit: 'mg'), f), base: 0.5);
      _amount(
        '4.5 oz is weight with no fl oz portion',
        convertAmount(_item(q: 6, unit: 'oz'), f),
        base: 170.097,
        label: 'oz',
      );
      _amount(
        '4.5 lb',
        convertAmount(_item(q: 1.25, unit: 'lb'), f),
        base: 566.99,
      );
    });
    test('4.5 mass: zero is a valid quantity and gives 0 g', () {
      _amount(
        '4.5 zero',
        resolveAmount(_item(q: 0, unit: 'g'), _usda([])),
        base: 0,
        assumed: false,
      );
    });
    test('4.5 local foods: a base unit of ml cannot take a mass unit', () {
      final f = _local('ml', 100);
      expect(
        convertAmount(_item(q: 5, unit: 'g'), f),
        isNull,
        reason: 'grammar 4.5 local ml: mass does not convert',
      );
    });
    test('4.5 local foods: a base unit of serving cannot take a mass unit', () {
      expect(
        convertAmount(_item(q: 5, unit: 'g'), _local('serving', 1)),
        isNull,
      );
    });
  });

  group('4.5 volume unit step 1: the food\'s own portion', () {
    test('4.5 volume 1: the first plain portion with the unit', () {
      final f = _usda([('1 tbsp, heaped', 20), ('1 tbsp', 15)]);
      _amount(
        '4.5 volume 1 plain first',
        convertAmount(_item(q: 2, unit: 'tbsp'), f),
        base: 30,
        label: 'tbsp',
        via: AmountRule.volumePortion,
        assumed: false,
      );
    });
    test('4.5 volume 1: else the first portion with the unit', () {
      final f = _usda([('1 tbsp, heaped', 20), ('1 tbsp (level)', 14)]);
      _amount(
        '4.5 volume 1 no plain',
        convertAmount(_item(q: 2, unit: 'tbsp'), f),
        base: 40,
        via: AmountRule.volumePortion,
      );
    });
    test('4.5 volume 1: grams per unit divides by the label amount', () {
      final f = _usda([('2 cups', 480)]);
      _amount(
        '4.5 volume 1 amount',
        convertAmount(_item(q: 3, unit: 'cup'), f),
        base: 720,
      );
    });
    test('4.5 volume 1: a spelling of the unit in the label counts', () {
      final f = _usda([('1 tablespoon', 20)]);
      _amount(
        '4.5 volume 1 spelling',
        convertAmount(_item(q: 1, unit: 'tbsp'), f),
        base: 20,
        via: AmountRule.volumePortion,
      );
    });
  });

  group('4.5 volume unit step 2: derived through milliliters', () {
    test('4.5 volume 2: tbsp from a cup (half and half, 240 g)', () {
      final f = _usda([('1 cup', 240)]);
      _amount(
        '4.5 volume 2',
        convertAmount(_item(q: 1, unit: 'tbsp'), f),
        base: 15,
        label: 'tbsp',
        via: AmountRule.volumeDerived,
        assumed: false,
      );
    });
    test('4.5 volume 2: tsp from a fl oz', () {
      final f = _usda([('1 fl oz', 30)]);
      _amount(
        '4.5 volume 2 fl oz',
        convertAmount(_item(q: 1, unit: 'tsp'), f),
        base: 30 * 4.92892159375 / 29.5735295625,
        via: AmountRule.volumeDerived,
      );
    });
    test('4.5 volume 2: the first plain volume portion is the source', () {
      final f = _usda([
        ('1 cup, chopped', 100),
        ('1 fl oz', 30),
        ('1 cup', 240),
      ]);
      _amount(
        '4.5 volume 2 plain',
        convertAmount(_item(q: 1, unit: 'tsp'), f),
        base: 30 * 4.92892159375 / 29.5735295625,
        via: AmountRule.volumeDerived,
      );
    });
    test('4.5 volume 2: else the first volume portion', () {
      final f = _usda([('1 cup, chopped', 100), ('1 fl oz (iced)', 30)]);
      _amount(
        '4.5 volume 2 no plain',
        convertAmount(_item(q: 1, unit: 'cup'), f),
        base: 100,
        via: AmountRule.volumePortion,
      );
      _amount(
        '4.5 volume 2 no plain, other unit',
        convertAmount(_item(q: 1, unit: 'tbsp'), f),
        base: 100 * 14.78676478125 / 236.5882365,
        via: AmountRule.volumeDerived,
      );
    });
    test('4.5 volume 2: milliliters and liters', () {
      final f = _usda([('2 cups', 480)]);
      _amount(
        '4.5 volume 2 ml',
        convertAmount(_item(q: 100, unit: 'ml'), f),
        base: 240 * 100 / 236.5882365,
      );
      _amount(
        '4.5 volume 2 l',
        convertAmount(_item(q: 1, unit: 'l'), f),
        base: 240 * 1000 / 236.5882365,
      );
    });
    test(
      '4.5 volume 2: an own portion beats a derivation from an earlier one',
      () {
        final f = _usda([('1 cup', 240), ('1 tablespoon', 14)]);
        _amount(
          '4.5 volume order: step 1 before step 2',
          convertAmount(_item(q: 2, unit: 'tbsp'), f),
          base: 28,
          via: AmountRule.volumePortion,
        );
      },
    );
  });

  group('4.5 volume unit step 3: cannot be converted', () {
    test('4.5 volume 3: no volume portion', () {
      expect(
        convertAmount(_item(q: 1, unit: 'cup'), _usda([('1 slice', 30)])),
        isNull,
        reason: 'grammar 4.5 volume 3: only a count portion',
      );
      expect(
        convertAmount(_item(q: 1, unit: 'cup'), _usda([('3 oz', 85)])),
        isNull,
        reason: 'grammar 4.5 volume 3: only a mass portion',
      );
      expect(convertAmount(_item(q: 1, unit: 'cup'), _usda([])), isNull);
    });
    test('4.5 volume 3: the line gets the default amount and is assumed', () {
      final f = _usda([('1 slice', 30), ('Quantity not specified', 25)]);
      final r = resolveAmount(_item(q: 2, unit: 'cup'), f);
      _amount(
        '4.5 volume 3 then 4.6',
        r,
        base: 25,
        via: AmountRule.defaultNotSpecified,
        assumed: true,
      );
    });
  });

  group('4.2 and 4.5 fluid ounces', () {
    test('4.2 oz is a fluid ounce when the food has a fl oz portion', () {
      final f = _usda([('1 cup', 244), ('1 fl oz', 30.5)]);
      _amount(
        '4.2 oz as fl oz',
        convertAmount(_item(q: 8, unit: 'oz'), f),
        base: 244,
        label: 'fl oz',
        via: AmountRule.volumePortion,
      );
    });
    test('4.2 a food with both fl oz and weight oz portions: fluid', () {
      final f = _usda([('1 oz, cooked', 28), ('1 fl oz', 30)]);
      _amount(
        '4.2 both',
        convertAmount(_item(q: 2, unit: 'oz'), f),
        base: 60,
        label: 'fl oz',
      );
    });
    test('4.2 oz is weight when there is no fl oz portion', () {
      final f = _usda([('1 cup (8 fl oz)', 240), ('1 oz', 28.35)]);
      _amount(
        '4.2 oz as weight',
        convertAmount(_item(q: 3, unit: 'oz'), f),
        base: 85.048,
        label: 'oz',
        via: AmountRule.massDirect,
      );
    });
    test('4.2 a typed fl oz is always fluid and derives from a cup', () {
      final f = _usda([('1 cup', 240)]);
      _amount(
        '4.2 fl oz',
        convertAmount(_item(q: 8, unit: 'fl oz'), f),
        base: 240 * 8 * 29.5735295625 / 236.5882365,
        label: 'fl oz',
        via: AmountRule.volumeDerived,
      );
    });
    test(
      '4.2 a typed fl oz on a food with no volume portion cannot convert',
      () {
        expect(
          convertAmount(_item(q: 8, unit: 'fl oz'), _usda([('1 oz', 28)])),
          isNull,
        );
      },
    );
  });

  group('4.5 serving and portion', () {
    test('4.5 serving: the first portion whose phrase has serving', () {
      final f = _usda([('1 cup', 100), ('1 single serving container', 45)]);
      _amount(
        '4.5 serving',
        convertAmount(_item(q: 2, unit: 'serving'), f),
        base: 90,
        label: 'serving',
        via: AmountRule.servingPortion,
        assumed: false,
      );
      _amount(
        '4.5 portion reads the same',
        convertAmount(_item(q: 2, unit: 'portion'), f),
        base: 90,
        label: 'portion',
        via: AmountRule.servingPortion,
      );
    });
    test('4.5 serving: the typed size, then medium or regular, then first', () {
      final f = _usda([
        ('1 small serving', 10),
        ('1 medium serving', 20),
        ('1 large serving', 30),
      ]);
      _amount(
        '4.5 serving size',
        convertAmount(_item(q: 1, unit: 'serving', size: 'large'), f),
        base: 30,
      );
      _amount(
        '4.5 serving medium',
        convertAmount(_item(q: 1, unit: 'serving'), f),
        base: 20,
      );
      final g = _usda([('1 small serving', 10), ('1 large serving', 30)]);
      _amount(
        '4.5 serving first',
        convertAmount(_item(q: 1, unit: 'serving'), g),
        base: 10,
      );
    });
    test('4.5 serving: with no such portion, one default portion (4.6)', () {
      final f = _usda([('1 cup', 100), ('Quantity not specified', 80)]);
      _amount(
        '4.5 serving default',
        convertAmount(_item(q: 2, unit: 'serving'), f),
        base: 160,
        label: 'serving',
        via: AmountRule.servingDefault,
        assumed: false,
      );
    });
    test(
      '4.5 serving: the default portion can be a 4.6 rule 3 to 6 portion',
      () {
        final f = _usda([('1 cup', 100), ('1 medium or regular slice', 28)]);
        _amount(
          '4.5 serving default rule 3',
          convertAmount(_item(q: 2, unit: 'serving'), f),
          base: 56,
        );
        _amount(
          '4.5 serving default rule 6',
          convertAmount(_item(q: 2, unit: 'serving'), _usda([])),
          base: 200,
        );
      },
    );
    test('4.5 serving: a serving portion beats the default portion', () {
      final f = _usda([('Quantity not specified', 80), ('1 serving', 55)]);
      _amount(
        '4.5 serving order',
        convertAmount(_item(q: 1, unit: 'serving'), f),
        base: 55,
        via: AmountRule.servingPortion,
      );
    });
  });

  group('4.5 other household unit', () {
    test('4.5 household: the first portion that names the unit', () {
      final f = _usda([
        ('1 slice, crust not eaten', 13),
        ('1 large or thick slice', 39),
      ]);
      _amount(
        '4.5 household first',
        convertAmount(_item(q: 2, unit: 'slice'), f),
        base: 26,
        label: 'slice',
        via: AmountRule.householdPortion,
        assumed: false,
      );
    });
    test('4.5 household: the typed size word first (3 thick slices)', () {
      final f = _usda([
        ('1 small or thin/very thin slice', 22),
        ('1 medium or regular slice', 25),
        ('1 large or thick slice', 39),
      ]);
      _amount(
        '4.5 household size',
        convertAmount(_item(q: 3, unit: 'slice', size: 'thick'), f),
        base: 117,
      );
      _amount(
        '4.5 household size thin',
        convertAmount(_item(q: 1, unit: 'slice', size: 'thin'), f),
        base: 22,
      );
    });
    test('4.5 household: then medium or regular (2 slices)', () {
      final f = _usda([
        ('1 small or thin/very thin slice', 22),
        ('1 medium or regular slice', 28),
        ('1 large or thick slice', 39),
      ]);
      _amount(
        '4.5 household medium',
        convertAmount(_item(q: 2, unit: 'slice'), f),
        base: 56,
      );
    });
    test('4.5 household: a size word that no portion has falls to medium', () {
      final f = _usda([('1 slice', 10), ('1 medium slice', 25)]);
      _amount(
        '4.5 household unknown size',
        convertAmount(_item(q: 1, unit: 'slice', size: 'jumbo'), f),
        base: 25,
      );
    });
    test('4.5 household: the size word beats medium (order)', () {
      final f = _usda([('1 medium slice', 25), ('1 large slice', 39)]);
      _amount(
        '4.5 household order',
        convertAmount(_item(q: 1, unit: 'slice', size: 'large'), f),
        base: 39,
      );
    });
    test('4.5 household: a slash word in the phrase names the unit', () {
      final f = _usda([('1 piece/slice, any size', 30)]);
      _amount(
        '4.5 household slash',
        convertAmount(_item(q: 2, unit: 'slice'), f),
        base: 60,
      );
    });
    test('4.5 household: the unit in a note or modifier does not count', () {
      final f = _usda([('1 cup, sliced', 100), ('1 egg (as a slice)', 50)]);
      expect(
        convertAmount(_item(q: 1, unit: 'slice'), f),
        isNull,
        reason: 'grammar 4.5 household: the unit phrase only',
      );
    });
    test('4.5 household: can (1 can Dr. Pepper)', () {
      final f = _usda([('1 fl oz', 31), ('1 can (12 fl oz)', 372)]);
      _amount(
        '4.5 household can',
        convertAmount(_item(q: 1, unit: 'can'), f),
        base: 372,
        label: 'can',
      );
    });
    test(
      '4.5 household: no portion for the unit cannot convert (2 slices butter)',
      () {
        final f = _usda([
          ('1 cup', 224),
          ('1 tablespoon', 14),
          ('Quantity not specified', 14),
        ]);
        expect(convertAmount(_item(q: 2, unit: 'slice'), f), isNull);
        _amount(
          '4.5 household none then 4.6',
          resolveAmount(_item(q: 2, unit: 'slice'), f),
          base: 14,
          quantity: 1,
          label: 'tbsp',
          via: AmountRule.defaultNotSpecified,
          assumed: true,
        );
      },
    );
  });

  group('4.5 no unit: a bare count', () {
    test('4.5 count 1: a size word picks a portion that has it', () {
      final f = _usda([
        ('1 egg', 50),
        ('1 large', 60),
        ('Quantity not specified', 45),
      ]);
      _amount(
        '4.5 count 1',
        convertAmount(_item(q: 1, size: 'large'), f, foodWords: ['egg']),
        base: 60,
        label: 'large',
        via: AmountRule.countSize,
        assumed: false,
      );
    });
    test('4.5 count 1 beats count 2 (order)', () {
      final f = _usda([('1 egg', 50), ('1 jumbo', 70)]);
      _amount(
        '4.5 count order 1 before 2',
        convertAmount(_item(q: 2, size: 'jumbo'), f, foodWords: ['egg']),
        base: 140,
        via: AmountRule.countSize,
      );
    });
    test('4.5 count 1: a size no portion has is ignored (2 large eggs)', () {
      final f = _usda([
        ('1 egg', 50),
        ('1 cup', 135),
        ('Quantity not specified', 50),
      ]);
      _amount(
        '4.5 count 1 ignored',
        convertAmount(_item(q: 2, size: 'large'), f, foodWords: ['eggs']),
        base: 100,
        via: AmountRule.countFoodWord,
        assumed: false,
      );
    });
    test('4.5 count 2: a one word phrase that is a food word', () {
      final f = _usda([
        ('1 cup', 135),
        ('1 egg', 50),
        ('Quantity not specified', 40),
      ]);
      _amount(
        '4.5 count 2',
        convertAmount(_item(q: 2), f, foodWords: ['egg']),
        base: 100,
        label: '',
        via: AmountRule.countFoodWord,
      );
    });
    test('4.5 count 2: the food word is compared in the singular', () {
      final f = _usda([('1 banana', 126), ('Quantity not specified', 100)]);
      for (final word in ['bananas', 'banana', 'Banana']) {
        _amount(
          '4.5 count 2 plural "$word"',
          convertAmount(_item(q: 1), f, foodWords: [word]),
          base: 126,
        );
      }
    });
    test('4.5 count 2: a corrected word picks the portion (2 bananna)', () {
      final f = _usda([('1 banana', 126), ('Quantity not specified', 100)]);
      _amount(
        '4.5 count 2 typo',
        convertAmount(_item(q: 2), f, foodWords: ['banana']),
        base: 252,
      );
      _amount(
        '4.5 count 2 uncorrected word does not match',
        convertAmount(_item(q: 2), f, foodWords: ['bananna']),
        base: 200,
        via: AmountRule.countDefaultPortion,
      );
    });
    test('4.5 count 2: a two word phrase does not count (1 Bagel Thin)', () {
      final f = _usda([('1 Bagel Thin', 46), ('Quantity not specified', 105)]);
      _amount(
        '4.5 count 2 two words',
        convertAmount(_item(q: 1), f, foodWords: ['bagel']),
        base: 105,
        via: AmountRule.countDefaultPortion,
      );
    });
    test('4.5 count 2 beats count 3 (order)', () {
      final f = _usda([('Quantity not specified', 40), ('1 egg', 50)]);
      _amount(
        '4.5 count order 2 before 3',
        convertAmount(_item(q: 1), f, foodWords: ['egg']),
        base: 50,
        via: AmountRule.countFoodWord,
      );
    });
    test('4.5 count 3: the default portion (half a bagel)', () {
      final f = _usda([
        ('Quantity not specified', 105),
        ('1 miniature', 26),
        ('1 small', 69),
        ('1 regular', 105),
      ]);
      _amount(
        '4.5 count 3',
        convertAmount(_item(q: 0.5), f, foodWords: ['bagel']),
        base: 52.5,
        label: '',
        via: AmountRule.countDefaultPortion,
        assumed: false,
      );
    });
    test('4.5 count 3 beats count 4 (order)', () {
      final f = _usda([('1 regular', 105), ('Quantity not specified', 99)]);
      _amount(
        '4.5 count order 3 before 4',
        convertAmount(_item(q: 1), f),
        base: 99,
        via: AmountRule.countDefaultPortion,
      );
    });
    test('4.5 count 4: the first medium or regular portion', () {
      final f = _usda([
        ('1 pat', 7),
        ('1 medium or regular slice', 28),
        ('1 regular', 30),
      ]);
      _amount(
        '4.5 count 4',
        convertAmount(_item(q: 2), f),
        base: 56,
        via: AmountRule.countMedium,
      );
    });
    test('4.5 count 4 beats count 5 (order)', () {
      final f = _usda([('1 large', 50), ('1 medium', 40)]);
      _amount(
        '4.5 count order 4 before 5',
        convertAmount(_item(q: 1), f),
        base: 40,
        via: AmountRule.countMedium,
      );
    });
    test('4.5 count 5: the first portion that is neither mass nor volume', () {
      final f = _usda([
        ('1 cup', 100),
        ('1 oz', 28),
        ('1 large', 50),
        ('1 pat', 7),
      ]);
      _amount(
        '4.5 count 5',
        convertAmount(_item(q: 2), f),
        base: 100,
        via: AmountRule.countNonMeasure,
      );
    });
    test('4.5 count 5: a portion with a count unit counts as neither', () {
      final f = _usda([('1 cup', 100), ('1 slice', 6)]);
      _amount('4.5 count 5 slice', convertAmount(_item(q: 1), f), base: 6);
    });
    test('4.5 count 6: nothing fits, so null and then the default (4.6)', () {
      final f = _usda([('1 cup', 100), ('1 oz', 28)]);
      expect(
        convertAmount(_item(q: 2), f),
        isNull,
        reason: 'grammar 4.5 count 6',
      );
      _amount(
        '4.5 count 6 then 4.6',
        resolveAmount(_item(q: 2), f),
        base: 100,
        via: AmountRule.defaultFirstPortion,
        assumed: true,
      );
    });
    test(
      '4.4 and 4.5: the two other "Quantity not specified" labels never count',
      () {
        final f = _usda([
          ('Quantity not specified, if appetizer', 115),
          ('Quantity not specified, if main course in meal', 402),
          ('1 pat', 7),
        ]);
        _amount(
          '4.4 label never counts as a typed unit',
          convertAmount(_item(q: 1), f),
          base: 7,
          via: AmountRule.countNonMeasure,
        );
        expect(
          convertAmount(
            _item(q: 1, unit: 'serving'),
            _usda([
              ('Quantity not specified, if appetizer', 115),
              ('1 cup', 9),
            ]),
          )?.baseQuantity,
          9,
          reason: 'grammar 4.4: serving default is not the appetizer weight',
        );
      },
    );
    test('4.5 count: the exact label is never offered as a unit', () {
      final f = _usda([('Quantity not specified', 50)]);
      expect(
        convertAmount(_item(q: 1, unit: 'specified'), f),
        isNull,
        reason: 'grammar 4.4: the default label is never a typed unit',
      );
      expect(convertAmount(_item(q: 1, unit: 'cup'), f), isNull);
    });
  });

  group('4.6 default amount', () {
    test('4.6 rule 1: the learned amount', () {
      final f = _usda([
        ('1 slice, crust not eaten', 13),
        ('1 medium or regular slice', 29),
        ('Quantity not specified', 29),
      ]);
      final r = defaultAmount(f, learned: const LearnedAmount(2, 'slice'));
      _amount(
        '4.6 rule 1',
        r,
        base: 58,
        quantity: 2,
        label: 'slice',
        via: AmountRule.defaultLearned,
        assumed: true,
      );
    });
    test(
      '4.6 rule 1: a learned bare count, a size, grams and a portion label',
      () {
        final f = _usda([
          ('1 egg', 50),
          ('1 small', 40),
          ('1 cup, cooked', 150),
          ('Quantity not specified', 30),
        ]);
        _amount(
          '4.6 rule 1 bare',
          defaultAmount(
            f,
            learned: const LearnedAmount(3, ''),
            foodWords: ['egg'],
          ),
          base: 150,
          label: '',
          via: AmountRule.defaultLearned,
        );
        _amount(
          '4.6 rule 1 size',
          defaultAmount(f, learned: const LearnedAmount(2, 'small')),
          base: 80,
          via: AmountRule.defaultLearned,
        );
        _amount(
          '4.6 rule 1 grams',
          defaultAmount(f, learned: const LearnedAmount(175, 'g')),
          base: 175,
          label: 'g',
        );
        _amount(
          '4.6 rule 1 portion label',
          defaultAmount(f, learned: const LearnedAmount(2, 'cup, cooked')),
          base: 300,
          label: 'cup, cooked',
          via: AmountRule.defaultLearned,
        );
      },
    );
    test(
      '4.6 rule 1: a learned oz is fluid when the food has a fl oz portion',
      () {
        final f = _usda([('1 fl oz', 30)]);
        _amount(
          '4.6 rule 1 oz',
          defaultAmount(f, learned: const LearnedAmount(4, 'oz')),
          base: 120,
          label: 'fl oz',
        );
      },
    );
    test('4.6 rule 1: a learned unit that does not convert is skipped', () {
      final f = _usda([('1 cup', 100), ('Quantity not specified', 30)]);
      _amount(
        '4.6 rule 1 skipped, rule 2 used',
        defaultAmount(f, learned: const LearnedAmount(2, 'slice')),
        base: 30,
        via: AmountRule.defaultNotSpecified,
      );
    });
    test('4.6 rule 1 beats rule 2 (order)', () {
      final f = _usda([('1 egg', 50), ('Quantity not specified', 50)]);
      final r = defaultAmount(
        f,
        learned: const LearnedAmount(150, 'g'),
        foodWords: ['egg'],
      );
      expect(r.rule, AmountRule.defaultLearned, reason: 'grammar 4.6 order');
    });
    test('4.6 rule 2: shown as quantity 1 and the portion when one weighs the same', () {
      final f = _usda([
        ('1 egg', 50),
        ('1 cup', 135),
        ('Quantity not specified', 50),
      ]);
      _amount(
        '4.6 rule 2 stored',
        defaultAmount(f),
        base: 50,
        quantity: 1,
        label: 'egg',
        via: AmountRule.defaultNotSpecified,
        assumed: true,
      );
    });
    test('4.6 rule 2: the first such portion when several weigh the same', () {
      final f = _usda([
        ('1 small', 360),
        ('1 cup', 360),
        ('Quantity not specified', 360),
      ]);
      _amount(
        '4.6 rule 2 first',
        defaultAmount(f),
        base: 360,
        quantity: 1,
        label: 'small',
      );
    });
    test('4.6 rule 2: otherwise the grams (half and half 20 g)', () {
      final f = _usda([
        ('1 cup', 240),
        ('1 fl oz', 30),
        ('Quantity not specified', 20),
      ]);
      _amount(
        '4.6 rule 2 grams',
        defaultAmount(f),
        base: 20,
        quantity: 20,
        label: 'g',
        via: AmountRule.defaultNotSpecified,
      );
    });
    test('4.6 rule 2: a portion of amount 2 does not count as 1 of it', () {
      final f = _usda([('2 cookies', 50), ('Quantity not specified', 50)]);
      _amount(
        '4.6 rule 2 amount',
        defaultAmount(f),
        base: 50,
        quantity: 50,
        label: 'g',
      );
    });
    test('4.6 rule 2 beats rule 3 (order)', () {
      final f = _usda([
        ('1 medium or regular slice', 28),
        ('Quantity not specified', 20),
      ]);
      expect(defaultAmount(f).rule, AmountRule.defaultNotSpecified);
    });
    test('4.6 rule 3: the first medium or regular portion', () {
      final f = _usda([
        ('1 cup', 100),
        ('1 medium or regular slice', 28),
        ('1 pat', 7),
      ]);
      _amount(
        '4.6 rule 3',
        defaultAmount(f),
        base: 28,
        quantity: 1,
        label: 'medium or regular slice',
        via: AmountRule.defaultMedium,
      );
    });
    test('4.6 rule 3: only the unit phrase counts, not a modifier', () {
      final f = _usda([('1 drink, medium (22 fl oz)', 675), ('1 pat', 7)]);
      expect(defaultAmount(f).rule, AmountRule.defaultNonMeasure);
    });
    test('4.6 rule 3 beats rule 4 (order)', () {
      final f = _usda([('1 pat', 7), ('1 regular', 100)]);
      expect(defaultAmount(f).rule, AmountRule.defaultMedium);
    });
    test('4.6 rule 4: the first portion neither mass nor volume (7up)', () {
      final f = _usda([
        ('1 fl oz', 30.8),
        ('1 drink (12 fl oz)', 368),
        ('1 drink, small (16 fl oz)', 491),
      ]);
      _amount(
        '4.6 rule 4',
        defaultAmount(f),
        base: 368,
        quantity: 1,
        label: 'drink (12 fl oz)',
        via: AmountRule.defaultNonMeasure,
        assumed: true,
      );
    });
    test('4.6 rule 4 beats rule 5 (order)', () {
      final f = _usda([('1 cup', 240), ('1 pat', 7)]);
      expect(defaultAmount(f).rule, AmountRule.defaultNonMeasure);
    });
    test('4.6 rule 5: the first portion', () {
      final f = _usda([('1 cup', 240), ('3 oz', 85)]);
      _amount(
        '4.6 rule 5',
        defaultAmount(f),
        base: 240,
        quantity: 1,
        label: 'cup',
        via: AmountRule.defaultFirstPortion,
      );
    });
    test('4.6 rule 5: a first portion of amount 3 shows as grams', () {
      final f = _usda([('3 oz', 85)]);
      _amount(
        '4.6 rule 5 grams',
        defaultAmount(f),
        base: 85,
        quantity: 85,
        label: 'g',
        via: AmountRule.defaultFirstPortion,
      );
    });
    test('4.6 rule 6: 100 g', () {
      _amount(
        '4.6 rule 6',
        defaultAmount(_usda([])),
        base: 100,
        quantity: 100,
        label: 'g',
        via: AmountRule.defaultHundredGrams,
        assumed: true,
      );
      expect(
        defaultAmount(_usda([('Skin from 1 medium', 5)])).rule,
        AmountRule.defaultHundredGrams,
        reason: 'grammar 4.4 and 4.6 rule 6: no usable portion',
      );
    });
  });

  group('4.6 default amount for a local food', () {
    test('4.6 local: the learned amount first', () {
      final f = _local('serving', 4, [('1 cookie', 20)]);
      _amount(
        '4.6 local learned',
        defaultAmount(f, learned: const LearnedAmount(2, 'serving')),
        base: 2,
        via: AmountRule.defaultLearned,
      );
    });
    test('4.6 local: 1 serving when the base unit is serving', () {
      final f = _local('serving', 4, [('1 cookie', 20)]);
      _amount(
        '4.6 local serving',
        defaultAmount(f),
        base: 1,
        quantity: 1,
        label: 'serving',
        baseUnit: 'serving',
        via: AmountRule.defaultServing,
        assumed: true,
      );
    });
    test('4.6 local: then its first portion', () {
      final f = _local('g', 100, [('1 cookie', 20), ('1 cup', 90)]);
      _amount(
        '4.6 local first portion',
        defaultAmount(f),
        base: 20,
        quantity: 1,
        label: 'cookie',
        baseUnit: 'g',
        via: AmountRule.defaultFirstPortion,
      );
    });
    test('4.6 local: then its base amount and unit', () {
      _amount(
        '4.6 local base g',
        defaultAmount(_local('g', 100)),
        base: 100,
        quantity: 100,
        label: 'g',
        via: AmountRule.defaultBase,
      );
      _amount(
        '4.6 local base ml',
        defaultAmount(_local('ml', 250)),
        base: 250,
        quantity: 250,
        label: 'ml',
        baseUnit: 'ml',
        via: AmountRule.defaultBase,
      );
    });
  });

  group('4.5 local foods: base units ml and serving', () {
    test('4.5 local ml: volume units convert directly', () {
      final f = _local('ml', 100, [('1 cup', 999)]);
      _amount(
        '4.5 local ml cup',
        convertAmount(_item(q: 2, unit: 'cup'), f),
        base: 2 * 236.5882365,
        baseUnit: 'ml',
        label: 'cup',
        via: AmountRule.volumeBase,
        assumed: false,
      );
      _amount(
        '4.5 local ml ml',
        convertAmount(_item(q: 330, unit: 'ml'), f),
        base: 330,
      );
      _amount(
        '4.5 local ml l',
        convertAmount(_item(q: 1.5, unit: 'l'), f),
        base: 1500,
      );
      _amount(
        '4.5 local ml tbsp',
        convertAmount(_item(q: 1, unit: 'tbsp'), f),
        base: 14.78676478125,
      );
    });
    test('4.5 local ml: oz is a weight, so it does not convert', () {
      expect(
        convertAmount(_item(q: 8, unit: 'oz'), _local('ml', 100)),
        isNull,
        reason: 'grammar 4.5 local ml: mass does not convert',
      );
    });
    test('4.5 local ml: household and bare counts use the portions', () {
      final f = _local('ml', 100, [('1 can', 355), ('1 shot', 44)]);
      _amount(
        '4.5 local ml can',
        convertAmount(_item(q: 2, unit: 'can'), f),
        base: 710,
        baseUnit: 'ml',
      );
      _amount(
        '4.5 local ml bare count',
        convertAmount(_item(q: 2), f),
        base: 710,
        baseUnit: 'ml',
        via: AmountRule.countNonMeasure,
      );
    });
    test('4.5 local ml: a failing unit gives the default in ml', () {
      _amount(
        '4.5 local ml default',
        resolveAmount(_item(q: 3, unit: 'g'), _local('ml', 250)),
        base: 250,
        baseUnit: 'ml',
        assumed: true,
        via: AmountRule.defaultBase,
      );
    });
    test(
      '4.5 local serving: serving, portion and a bare count convert directly',
      () {
        final f = _local('serving', 4, [('1 cup', 300)]);
        _amount(
          '4.5 local serving serving',
          convertAmount(_item(q: 2, unit: 'serving'), f),
          base: 2,
          label: 'serving',
          baseUnit: 'serving',
          via: AmountRule.servingBase,
          assumed: false,
        );
        _amount(
          '4.5 local serving portion',
          convertAmount(_item(q: 1.5, unit: 'portion'), f),
          base: 1.5,
        );
        _amount(
          '4.5 local serving bare',
          convertAmount(_item(q: 3), f),
          base: 3,
          label: '',
          baseUnit: 'serving',
          via: AmountRule.servingBase,
        );
      },
    );
    test('4.5 local serving: mass and volume units do not convert', () {
      final f = _local('serving', 4, [('1 cup', 300)]);
      expect(convertAmount(_item(q: 100, unit: 'g'), f), isNull);
      expect(
        convertAmount(_item(q: 1, unit: 'cup'), f),
        isNull,
        reason: 'grammar 4.5 local serving: volume does not convert',
      );
      _amount(
        '4.5 local serving then 4.6',
        resolveAmount(_item(q: 100, unit: 'g'), f),
        base: 1,
        quantity: 1,
        label: 'serving',
        assumed: true,
      );
    });
    test('4.5 local g: the same rules as a USDA food', () {
      final f = _local('g', 100, [('1 cookie', 20), ('1 cup', 90)]);
      _amount(
        '4.5 local g mass',
        convertAmount(_item(q: 50, unit: 'g'), f),
        base: 50,
        baseUnit: 'g',
      );
      _amount(
        '4.5 local g cup',
        convertAmount(_item(q: 2, unit: 'cup'), f),
        base: 180,
      );
      _amount(
        '4.5 local g bare count (2 cookies)',
        convertAmount(_item(q: 2), f, foodWords: ['cookie']),
        base: 40,
        via: AmountRule.countFoodWord,
      );
    });
  });

  group('4.7 resolveAmount: what a line stores', () {
    test('4.7 a typed amount that converts is not assumed', () {
      final f = _usda([('1 medium or regular slice', 28)]);
      _amount(
        '4.7 typed',
        resolveAmount(_item(q: 2, unit: 'slice'), f),
        base: 56,
        quantity: 2,
        label: 'slice',
        baseUnit: 'g',
        assumed: false,
      );
    });
    test('4.7 no quantity gives the default and is assumed', () {
      final f = _usda([('1 egg', 50), ('Quantity not specified', 50)]);
      _amount(
        '4.7 none',
        resolveAmount(_item(), f),
        base: 50,
        quantity: 1,
        label: 'egg',
        assumed: true,
      );
    });
    test('4.7 a range is the midpoint and assumed (3.3)', () {
      final f = _usda([('1 egg', 50)]);
      _amount(
        '4.7 range',
        resolveAmount(_item(q: 2.5, range: true), f, foodWords: ['egg']),
        base: 125,
        quantity: 2.5,
        assumed: true,
      );
    });
    test('4.7 the learned amount is used only when nothing was typed', () {
      final f = _usda([('1 cup', 240), ('Quantity not specified', 30)]);
      const learned = LearnedAmount(2, 'cup');
      _amount(
        '4.7 typed beats learned',
        resolveAmount(_item(q: 100, unit: 'g'), f, learned: learned),
        base: 100,
        assumed: false,
      );
      _amount(
        '4.7 none uses learned',
        resolveAmount(_item(), f, learned: learned),
        base: 480,
        assumed: true,
        via: AmountRule.defaultLearned,
      );
      _amount(
        '4.7 unconvertible uses learned',
        resolveAmount(_item(q: 2, unit: 'slice'), f, learned: learned),
        base: 480,
        assumed: true,
        via: AmountRule.defaultLearned,
      );
    });
    test('4.7 the size word is the unit label for a bare count', () {
      final f = _usda([('1 small', 360), ('1 large', 600)]);
      _amount(
        '4.7 size as unit',
        resolveAmount(_item(q: 1, size: 'large'), f),
        base: 600,
        label: 'large',
        assumed: false,
      );
    });
  });

  group('4.7 nutrient scaling', () {
    test(
      '4.7 USDA values per 100 g are scaled by grams over 100, unrounded',
      () {
        final f = _usda(
          [('1 egg', 50)],
          nutrients: {1008: 176, 1003: 11.8, 1004: 13.9},
        );
        final n = scaleNutrients(f, 100);
        expect(n[1008], closeTo(176, 1e-9));
        expect(n[1003], closeTo(11.8, 1e-9));
        final odd = scaleNutrients(f, 52.5);
        expect(odd[1008], closeTo(176 * 52.5 / 100, 1e-9));
        expect(odd[1004], closeTo(13.9 * 0.525, 1e-9));
      },
    );
    test('4.7 a nutrient the food does not list stays absent, never zero', () {
      final f = _usda([], nutrients: {1008: 100});
      final n = scaleNutrients(f, 250);
      expect(n.containsKey(1003), isFalse);
      expect(n.keys, [1008]);
    });
    test('4.7 a listed zero stays zero', () {
      final f = _usda([], nutrients: {1008: 0});
      expect(scaleNutrients(f, 250), {1008: 0});
    });
    test('4.7 zero grams gives zero amounts of the listed nutrients', () {
      final f = _usda([], nutrients: {1008: 55});
      expect(scaleNutrients(f, 0), {1008: 0});
    });
    test(
      '4.7 a local food is scaled by its base amount (recipe, 4 servings)',
      () {
        final f = PortionFood.local(
          baseUnit: 'serving',
          baseAmount: 4,
          portions: const [],
          nutrients: {1008: 1680},
        );
        expect(scaleNutrients(f, 2)[1008], closeTo(840, 1e-9));
        final per100 = PortionFood.local(
          baseUnit: 'ml',
          baseAmount: 100,
          portions: const [],
          nutrients: {1008: 40},
        );
        expect(scaleNutrients(per100, 330)[1008], closeTo(132, 1e-9));
      },
    );
  });

  group('4.6 which portion a default shows (R25)', () {
    test(
      '4.6 R25 the portion the rule picked, not an equal weight earlier',
      () {
        final f = _usda([('1 cup', 89), ('1 leek', 89)]);
        _amount(
          '4.6 R25 picked portion',
          defaultAmount(f),
          base: 89,
          quantity: 1,
          label: 'leek',
          via: AmountRule.defaultNonMeasure,
        );
      },
    );
    test(
      '4.6 R25 a picked portion of amount 22 shows the first 1 of that weight',
      () {
        final f = _usda([('22 chips', 28.35), ('1 oz', 28.35)]);
        _amount(
          '4.6 R25 chips',
          defaultAmount(f),
          base: 28.35,
          quantity: 1,
          label: 'oz',
          via: AmountRule.defaultNonMeasure,
        );
      },
    );
    test('4.6 R25 otherwise grams in the base unit', () {
      final f = _usda([('22 chips', 28.35), ('1 cup', 100)]);
      _amount(
        '4.6 R25 grams',
        defaultAmount(f),
        base: 28.35,
        quantity: 28.35,
        label: 'g',
      );
    });
  });

  group('4.7 a local food with an unusable base amount (R30)', () {
    for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
      test('no infinite or NaN values for base amount $bad', () {
        final f = PortionFood.local(
          baseUnit: 'g',
          baseAmount: bad,
          portions: const [],
          nutrients: {1008: 100},
        );
        expect(scaleNutrients(f, 50), isEmpty, reason: 'R30 scaling');
        for (final r in [
          defaultAmount(f),
          resolveAmount(_item(), f),
          resolveAmount(_item(q: 2, unit: 'cup'), f),
          resolveAmount(_item(q: 3, unit: 'g'), f),
        ]) {
          expect(r.baseQuantity.isFinite, isTrue, reason: 'R30 $r');
          expect(r.quantity.isFinite, isTrue, reason: 'R30 $r');
        }
      });
    }
    test('a zero or negative base amount on a serving food', () {
      final f = PortionFood.local(
        baseUnit: 'serving',
        baseAmount: 0,
        portions: const [],
        nutrients: {1008: 100},
      );
      expect(scaleNutrients(f, 2), isEmpty);
      expect(resolveAmount(_item(q: 2, unit: 'serving'), f).baseQuantity, 2);
    });
  });

  group('real bundled database', () {
    late Directory dir;
    late FoodReference ref;

    setUpAll(() {
      dir = Directory.systemTemp.createTempSync('daybook_grams');
      final path = '${dir.path}/usda.sqlite';
      File(path).writeAsBytesSync(
        gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
      );
      ref = FoodReference.open(path);
    });
    tearDownAll(() {
      ref.close();
      dir.deleteSync(recursive: true);
    });

    PortionFood food(int id) {
      final f = ref.food(id)!;
      return PortionFood.usda(
        portions: [for (final p in f.portions) (p.label, p.grams)],
        nutrients: f.nutrients,
      );
    }

    PortionFood byRef(String r) {
      if (r == 'local:1') {
        return PortionFood.local(
          baseUnit: 'serving',
          baseAmount: 4,
          portions: const [],
          nutrients: {1008: 1680},
        );
      }
      if (r == 'local:2') {
        return PortionFood.local(
          baseUnit: 'g',
          baseAmount: 100,
          portions: const [('1 cookie', 20)],
        );
      }
      return food(int.parse(r.substring('usda:'.length)));
    }

    test('4.6 egg usda:2707153 default is 50 g, shown as 1 egg', () {
      _amount(
        '4.6 egg default',
        defaultAmount(food(2707153)),
        base: 50,
        quantity: 1,
        label: 'egg',
        via: AmountRule.defaultNotSpecified,
        assumed: true,
      );
    });
    test('4.6 coffee usda:2710373 default is "1 small", 360 g', () {
      _amount(
        '4.6 coffee default',
        defaultAmount(food(2710373)),
        base: 360,
        quantity: 1,
        label: 'small',
        assumed: true,
      );
    });
    test(
      '4.5 and 4.6 half and half usda:2705594: 1 tbsp is 15 g, default 20 g',
      () {
        final f = food(2705594);
        _amount(
          '4.5 volume 2 half and half',
          convertAmount(_item(q: 1, unit: 'tbsp'), f),
          base: 15,
          via: AmountRule.volumeDerived,
        );
        _amount(
          '4.5 volume 2 half and half 2 tbsp',
          convertAmount(_item(q: 2, unit: 'tbsp'), f),
          base: 30,
        );
        _amount(
          '4.6 half and half default',
          defaultAmount(f),
          base: 20,
          quantity: 20,
          label: 'g',
        );
      },
    );
    test('4.5 milk usda:2705384: 500 ml is 515.7 g', () {
      final r = convertAmount(_item(q: 500, unit: 'ml'), food(2705384))!;
      expect(
        r.baseQuantity,
        closeTo(515.7, 0.05),
        reason: 'grammar 4.5 volume 2, example 35',
      );
      expect(r.rule, AmountRule.volumeDerived);
      expect(r.portionLabel, '1 cup');
    });
    test('4.5 sourdough toast usda:2707647: 2 slices is 56 g', () {
      _amount(
        '4.5 household sourdough',
        convertAmount(_item(q: 2, unit: 'slice'), food(2707647)),
        base: 56,
        label: 'slice',
      );
    });
    test('4.4 the food with the two extra "Quantity not specified" labels', () {
      final f = ref.food(2706874)!;
      final labels = [for (final p in f.portions) p.label];
      expect(labels, contains('Quantity not specified, if appetizer'));
      final pf = food(2706874);
      expect(
        pf.portions.usable.where(
          (p) => p.label.startsWith('Quantity not specified'),
        ),
        isEmpty,
        reason: 'grammar 4.4: those labels are never a unit',
      );
      // This food has neither the exact label nor a usable medium portion, so
      // its default is 4.6 rule 5, the first portion.
      expect(pf.portions.defaultPortion, isNull);
      _amount(
        '4.6 rule 5 on the antipasto',
        defaultAmount(pf),
        base: 115,
        quantity: 1,
        label: 'cup',
        via: AmountRule.defaultFirstPortion,
      );
      expect(defaultPortionText, defaultPortionLabel);
    });
    test('4.4 every bundled portion label is read without error', () {
      // Every USDA food: reading a label never throws and the default portion
      // is only the exact label.
      for (final id in [2707153, 2710373, 2705594, 2705384, 2707647, 173205]) {
        final f = food(id);
        for (final p in f.portions.usable) {
          expect(p.amount, greaterThan(0));
          expect(p.gramsPerUnit, isNonNegative);
        }
      }
    });
    test('4.7 nutrients of the real egg: 2 eggs is 176 kcal', () {
      final f = food(2707153);
      final r = resolveAmount(_item(q: 2), f, foodWords: ['egg']);
      expect(scaleNutrients(f, r.baseQuantity)[1008], closeTo(176, 0.5));
    });
    test('4.5 count 2: plural words meet their portion (2 cookies)', () {
      // foodWords are the normalized query words, as the matcher gives them.
      final puertoRican = food(2707992);
      _amount(
        '4.5 count 2 cookies, default 38 g',
        convertAmount(
          _item(q: 2),
          puertoRican,
          foodWords: queryWords('cookies'),
        ),
        base: 38,
        via: AmountRule.countFoodWord,
      );
      _amount(
        '4.5 count 2 fig bars',
        convertAmount(
          _item(q: 2),
          food(172721),
          foodWords: queryWords('cookies'),
        ),
        base: 32,
        via: AmountRule.countFoodWord,
      );
      _amount(
        '4.5 count 2 brownies',
        convertAmount(
          _item(q: 2),
          food(174949),
          foodWords: queryWords('brownies'),
        ),
        base: 48,
        via: AmountRule.countFoodWord,
      );
      _amount(
        '4.5 count 2 pies',
        convertAmount(_item(q: 2), food(167522), foodWords: queryWords('pies')),
        base: 2274,
        via: AmountRule.countFoodWord,
      );
    });
    test('4.6 the leek default shows the portion the rule picked', () {
      _amount(
        '4.6 R25 leek',
        defaultAmount(food(169246)),
        base: 89,
        quantity: 1,
        label: 'leek',
      );
    });

    group('11.2 worked examples: the amount of each line', () {
      // Examples where the typed text does not split into one item per
      // expected line (saved meals and not found lines have no amount here).
      const skipped = {47, 48, 49, 50, 59, 60, 61, 62, 63};

      // What the real caller passes: the normalized query words, with the typo
      // of example 42 already corrected.
      List<String> wordsOf(String text) =>
          queryWords(text.replaceAll('bananna', 'banana'));

      void check(
        WorkedExample ex,
        ExampleSetup setup,
        List<ExpectedLine> lines,
        String label,
      ) {
        final drafts = splitItems(ex.input);
        expect(
          drafts.length,
          lines.length,
          reason: 'example ${ex.number} $label: one item per line',
        );
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          final d = drafts[i];
          final why = 'example ${ex.number} $label line ${i + 1} (${l.ref})';
          final f = byRef(l.ref!);
          LearnedAmount? learned;
          if (setup.learned.isNotEmpty &&
              setup.learned.first.quantity != null) {
            final x = setup.learned.first;
            learned = LearnedAmount(x.quantity!, x.unit ?? '');
          }
          final r = resolveAmount(
            d,
            f,
            foodWords: wordsOf(d.foodText),
            learned: learned,
          );
          if (l.grams != null) {
            expect(
              r.baseQuantity,
              closeTo(l.grams!, 0.05),
              reason: '$why grams',
            );
          }
          if (l.quantity != null) {
            expect(r.quantity, closeTo(l.quantity!, 1e-9), reason: '$why qty');
          }
          if (l.unit != null) {
            expect(r.unitLabel, l.unit, reason: '$why unit');
          }
          expect(
            r.assumed,
            l.markers.contains(ExpectedMarker.assumed) ||
                l.state == ExpectedState.amountAssumed,
            reason: '$why assumed (8.1)',
          );
          if (l.kcal != null) {
            expect(
              scaleNutrients(f, r.baseQuantity)[1008],
              closeTo(l.kcal!, 0.5),
              reason: '$why kcal',
            );
          }
          for (final (id, want) in [
            (1003, l.protein),
            (1005, l.carbs),
            (1004, l.fat),
          ]) {
            if (want == null) continue;
            expect(
              scaleNutrients(f, r.baseQuantity)[id] ?? 0,
              closeTo(want, 0.06),
              reason: '$why nutrient $id',
            );
          }
          switch (l.defaultSource) {
            case DefaultSource.notSpecified:
              expect(
                {
                  AmountRule.defaultNotSpecified,
                  AmountRule.countDefaultPortion,
                  AmountRule.servingDefault,
                },
                contains(r.rule),
                reason: '$why default rule (4.6 rule 2)',
              );
              if (l.defaultGrams != null) {
                expect(
                  f.portions.defaultPortion?.grams,
                  l.defaultGrams,
                  reason: '$why default portion grams',
                );
              }
            case DefaultSource.rule4:
              expect(
                r.rule,
                AmountRule.defaultNonMeasure,
                reason: '$why 4.6 rule 4',
              );
            case DefaultSource.learned:
              expect(
                r.rule,
                AmountRule.defaultLearned,
                reason: '$why 4.6 rule 1',
              );
            case null:
              break;
          }
          final pl = l.portion?.label;
          if (pl != null) {
            expect(r.portionLabel, pl, reason: '$why portion');
          }
        }
      }

      for (final ex in workedExamples) {
        if (skipped.contains(ex.number)) continue;
        test('example ${ex.number}: ${ex.input.replaceAll('\n', '\\n')}', () {
          check(ex, ex.setup, ex.lines, 'main');
          for (final v in ex.variants) {
            check(ex, v.setup, v.lines, v.description);
          }
        });
      }
    });
  });
}
