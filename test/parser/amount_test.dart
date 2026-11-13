// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Grammar 3 and 4.1 to 4.3 (docs/parser-grammar.md): quantities, multipliers,
// ranges, units, size words and "of", and item count, quantity and unit for
// the worked examples of 11.2 that the plan names for task 2.1. Expected
// values are written from the grammar text, not from the code.

import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/split.dart';
import 'package:flutter_test/flutter_test.dart';

ItemDraft _one(String text, String rule) {
  final items = splitItems(text);
  expect(items, hasLength(1), reason: 'grammar $rule: "$text" is one item');
  return items.single;
}

/// One item with [quantity], [unit] label and optionally more.
void _read(
  String rule,
  String text,
  double? quantity, {
  String? unit,
  String? size,
  String? food,
  bool range = false,
  double? multiplier,
}) {
  test('$rule: "${text.replaceAll('\n', '\\n')}"', () {
    final d = _one(text, rule);
    final why = 'grammar $rule, input "$text", got $d';
    if (quantity == null) {
      expect(d.quantity, isNull, reason: why);
    } else {
      expect(d.quantity, isNotNull, reason: why);
      expect(d.quantity!, closeTo(quantity, 1e-9), reason: why);
    }
    expect(d.unit?.label, unit, reason: why);
    expect(d.size, size, reason: why);
    expect(d.isRange, range, reason: why);
    if (food != null) expect(d.foodText, food, reason: why);
    if (multiplier != null) expect(d.multiplier, multiplier, reason: why);
  });
}

void main() {
  group('3.1 accepted forms', () {
    _read('3.1 whole number', '2 eggs', 2, food: 'eggs');
    _read('3.1 whole number, two digits', '12 eggs', 12);
    _read('3.1 decimal', '1.5 cups milk', 1.5, unit: 'cup');
    _read('3.1 decimal below one', '0.5 cup milk', 0.5, unit: 'cup');
    _read('3.1 decimal with no leading zero', '.5 cup milk', 0.5, unit: 'cup');
    _read('3.1 fraction 1/2', '1/2 cup milk', 0.5, unit: 'cup');
    _read('3.1 fraction 3/4', '3/4 cup milk', 0.75, unit: 'cup');
    _read(
      '3.1 a zero denominator is a plain word',
      '1/0 cup milk',
      null,
      food: '1/0 cup milk',
    );
    _read('3.1 mixed number with a space', '1 1/2 cups milk', 1.5, unit: 'cup');
    _read(
      '3.1 mixed number with a hyphen',
      '1-1/2 cups milk',
      1.5,
      unit: 'cup',
    );
    _read(
      '3.1 mixed number with a unicode fraction',
      '1½ cups milk',
      1.5,
      unit: 'cup',
    );
    _read('3.1 unicode fraction ½', '½ cup milk', 0.5, unit: 'cup');
    _read('3.1 unicode fraction ¾', '¾ cup milk', 0.75, unit: 'cup');
    _read('3.1 fraction slash', '1⁄2 cup milk', 0.5, unit: 'cup');

    group('number words', () {
      const ones = {
        'one': 1,
        'two': 2,
        'three': 3,
        'four': 4,
        'five': 5,
        'six': 6,
        'seven': 7,
        'eight': 8,
        'nine': 9,
      };
      const teens = {
        'ten': 10,
        'eleven': 11,
        'twelve': 12,
        'thirteen': 13,
        'fourteen': 14,
        'fifteen': 15,
        'sixteen': 16,
        'seventeen': 17,
        'eighteen': 18,
        'nineteen': 19,
      };
      const tens = {
        'twenty': 20,
        'thirty': 30,
        'forty': 40,
        'fifty': 50,
        'sixty': 60,
        'seventy': 70,
        'eighty': 80,
        'ninety': 90,
      };
      for (final e in {...ones, ...teens, ...tens}.entries) {
        _read(
          '3.1 number word',
          '${e.key} eggs',
          e.value.toDouble(),
          food: 'eggs',
        );
      }
      _read('3.1 pair with a space', 'twenty five eggs', 25);
      _read('3.1 pair with a hyphen', 'twenty-five eggs', 25);
      _read('3.1 largest pair', 'ninety nine eggs', 99);
      _read('3.1 number word in capitals', 'Two eggs', 2);
    });

    _read('3.1 an', 'an apple', 1, food: 'apple');
    _read('3.1 a', 'a cup of milk', 1, unit: 'cup', food: 'milk');
    _read('3.1 I had a banana', 'I had a banana', 1, food: 'banana');

    group('dozen', () {
      _read('3.1 dozen', 'dozen eggs', 12, food: 'eggs');
      _read('3.1 a dozen', 'a dozen eggs', 12, food: 'eggs');
      _read('3.1 2 dozen', '2 dozen eggs', 24, food: 'eggs');
      _read('3.1 half a dozen', 'half a dozen eggs', 6, food: 'eggs');
      _read('3.1 dozen of', 'dozen of eggs', 12, food: 'eggs');
      _read('3.1 a dozen of', 'a dozen of eggs', 12, food: 'eggs');
      _read('3.1 two dozen of', 'two dozen of eggs', 24, food: 'eggs');
    });

    group('half', () {
      _read('3.1 half', 'half bagel', 0.5, food: 'bagel');
      _read('3.1 a half', 'a half bagel', 0.5, food: 'bagel');
      _read('3.1 one half', 'one half bagel', 0.5, food: 'bagel');
      _read('3.1 half a', 'half a bagel', 0.5, food: 'bagel');
      _read('3.1 half an', 'half an apple', 0.5, food: 'apple');
      _read('3.1 half of a', 'half of a bagel', 0.5, food: 'bagel');
      _read('3.1 half a cup', 'half a cup milk', 0.5, unit: 'cup');
    });

    group('quarter and third', () {
      _read('3.1 a quarter', 'a quarter cup milk', 0.25, unit: 'cup');
      _read('3.1 quarter of a', 'quarter of a pizza', 0.25, food: 'pizza');
      _read('3.1 a third', 'a third cup milk', 1 / 3, unit: 'cup');
      _read('3.1 one third', 'one third cup milk', 1 / 3, unit: 'cup');
    });

    group('counted fractions', () {
      _read('3.1 three quarters', 'three quarters cup milk', 0.75, unit: 'cup');
      _read('3.1 two thirds', 'two thirds cup milk', 2 / 3, unit: 'cup');
      _read(
        '3.1 three quarters of a',
        'three quarters of a pizza',
        0.75,
        food: 'pizza',
      );
      _read(
        '3.1 three quarters of a cup of milk',
        'three quarters of a cup of milk',
        0.75,
        unit: 'cup',
        food: 'milk',
      );
      _read('3.1 digits then thirds', '2 thirds cup milk', 2 / 3, unit: 'cup');
    });

    group('number phrases with "and"', () {
      _read(
        '3.1 one and a half',
        'one and a half cups of milk',
        1.5,
        unit: 'cup',
        food: 'milk',
      );
      _read('3.1 1 and 1/2', '1 and 1/2 cups oatmeal', 1.5, unit: 'cup');
      _read(
        '3.1 a cup and a half',
        'a cup and a half of milk',
        1.5,
        unit: 'cup',
        food: 'milk',
      );
      _read(
        '3.1 2 cups and a half',
        '2 cups and a half milk',
        2.5,
        unit: 'cup',
      );
    });

    group('couple', () {
      _read('3.1 a couple', 'a couple eggs', 2, food: 'eggs');
      _read('3.1 a couple of', 'a couple of eggs', 2, food: 'eggs');
      _read('3.1 couple of', 'couple of eggs', 2, food: 'eggs');
    });
  });

  group('3.2 multipliers', () {
    _read('3.2 2x', '2x eggs', 2, multiplier: 2, food: 'eggs');
    _read('3.2 2 x', '2 x eggs', 2, multiplier: 2, food: 'eggs');
    _read('3.2 x2', 'x2 eggs', 2, multiplier: 2, food: 'eggs');
    _read('3.2 x 2', 'x 2 eggs', 2, multiplier: 2, food: 'eggs');
    _read('3.2 2×', '2× eggs', 2, multiplier: 2, food: 'eggs');
    _read('3.2 ×2', '×2 eggs', 2, multiplier: 2, food: 'eggs');
    _read('3.2 either case: X2', 'X2 eggs', 2, multiplier: 2);
    _read('3.2 either case: 2X', '2X eggs', 2, multiplier: 2);
    _read('3.2 eggs x3', 'eggs x3', 3, multiplier: 3, food: 'eggs');
    _read('3.2 2 eggs x3', '2 eggs x3', 6, multiplier: 3);
    _read(
      '3.2 2x 100g chicken breast',
      '2x 100g chicken breast',
      200,
      unit: 'g',
      multiplier: 2,
      food: 'chicken breast',
    );
    _read(
      '3.2 half usual breakfast x2',
      'half usual breakfast x2',
      1,
      multiplier: 2,
      food: 'usual breakfast',
    );
    _read(
      '3.2 a multiplier with no other quantity is the quantity',
      'x3',
      3,
      multiplier: 3,
      food: '',
    );
    _read(
      '3.2 a multiplier after a unit amount',
      '100 g x2 chicken',
      200,
      unit: 'g',
      multiplier: 2,
      food: 'chicken',
    );
    _read(
      '3.2 a multiplier after a range',
      '2-3 eggs x2',
      5,
      range: true,
      multiplier: 2,
    );
  });

  group('3.3 ranges', () {
    _read('3.3 2-3', '2-3 eggs', 2.5, range: true, food: 'eggs');
    _read('3.3 2 to 3', '2 to 3 eggs', 2.5, range: true, food: 'eggs');
    _read('3.3 2 or 3', '2 or 3 eggs', 2.5, range: true, food: 'eggs');
    _read('3.3 2 - 3 with spaces', '2 - 3 eggs', 2.5, range: true);
    _read('3.3 1/2-1', '1/2-1 cup milk', 0.75, range: true, unit: 'cup');
    _read(
      '3.3 1-1/2 is a mixed number, not a range',
      '1-1/2 cups milk',
      1.5,
      unit: 'cup',
    );
    _read(
      '3.3 1/2-3/4 is a range',
      '1/2-3/4 cup milk',
      0.625,
      range: true,
      unit: 'cup',
    );
    _read('3.3 number words', 'one or two eggs', 1.5, range: true);
    _read(
      '3.3 a range with a unit',
      '2-3 tbsp butter',
      2.5,
      range: true,
      unit: 'tbsp',
    );
    _read(
      '3.3 or between foods is not a range',
      'eggs or toast',
      null,
      food: 'eggs or toast',
    );
    _read('3.3 a plain number is not a range', '2 eggs', 2);
  });

  group('3.4 no quantity, vague words, approximations', () {
    _read('3.4 no quantity at all', 'coffee', null, food: 'coffee');
    _read(
      '3.4 a size word means 1',
      'large coffee',
      1,
      size: 'large',
      food: 'coffee',
    );
    _read(
      '3.4 a unit followed by of means 1',
      'cup of coffee',
      1,
      unit: 'cup',
      food: 'coffee',
    );
    _read(
      '3.4 slice of pizza',
      'slice of pizza',
      1,
      unit: 'slice',
      food: 'pizza',
    );
    _read('3.4 some', 'some eggs', null, food: 'eggs');
    _read('3.4 a few', 'a few almonds', null, food: 'almonds');
    _read('3.4 few', 'few almonds', null, food: 'almonds');
    _read('3.4 a little', 'a little milk', null, food: 'milk');
    _read('3.4 a bit', 'a bit butter', null, food: 'butter');
    _read('3.4 a bit of', 'a bit of butter', null, food: 'butter');
    _read('3.4 some of', 'some of the pizza', null, food: 'pizza');
    _read('3.4 about', 'about 2 cups milk', 2, unit: 'cup', food: 'milk');
    _read('3.4 around', 'around 2 cups milk', 2, unit: 'cup');
    _read('3.4 approximately', 'approximately 2 cups milk', 2, unit: 'cup');
    _read('3.4 roughly', 'roughly 2 cups milk', 2, unit: 'cup');
    _read('3.4 tilde', '~2 cups milk', 2, unit: 'cup', food: 'milk');
    _read('3.4 tilde and space', '~ 2 cups milk', 2, unit: 'cup');
    _read('3.4 zero is a quantity', '0 eggs', 0, food: 'eggs');
    _read('3.4 0 g', '0 g rice', 0, unit: 'g');
    _read(
      '3.4 a percent is part of the name',
      '2% milk',
      null,
      food: '2% milk',
    );
    _read(
      '3.4 100% orange juice',
      '100% orange juice',
      null,
      food: '100% orange juice',
    );
    _read(
      '3.4 percent after a quantity',
      '2 cups 2% milk',
      2,
      unit: 'cup',
      food: '2% milk',
    );
    _read('3.4 2 percent in words', '2 percent milk', null, food: '2% milk');
    test('3.4 hasAmount follows the quantity', () {
      expect(_one('2 eggs', '3.4').hasAmount, isTrue);
      expect(_one('0 eggs', '3.4').hasAmount, isTrue);
      expect(_one('coffee', '3.4').hasAmount, isFalse);
      expect(_one('a few almonds', '3.4').hasAmount, isFalse);
    });
  });

  group('3.5 not supported', () {
    _read(
      '3.5 number words above ninety-nine',
      'two hundred eggs',
      2,
      food: 'hundred eggs',
    );
    _read('3.5 ordinals', 'second helping', null, food: 'second helping');
    test('3.5 a comma is not a decimal point', () {
      final items = splitItems('1,5 kg');
      expect(items, hasLength(2));
      expect(items[0].quantity, 1);
      expect(items[1].quantity, 5);
      expect(items[1].unit?.label, 'kg');
    });
    _read(
      '3.5 quantities written after units are not read as units',
      'cups 2',
      2,
      food: 'cups',
    );
  });

  group('4.1 every unit spelling', () {
    // Written from the tables in 4.1, not taken from tokens.dart.
    const spellings = <String, List<String>>{
      'g': ['g', 'gr', 'gm', 'gms', 'gram', 'grams', 'gramme', 'grammes'],
      'kg': ['kg', 'kgs', 'kilo', 'kilos', 'kilogram', 'kilograms'],
      'mg': ['mg', 'milligram', 'milligrams'],
      'oz': ['oz', 'ozs', 'ounce', 'ounces'],
      'lb': ['lb', 'lbs', 'pound', 'pounds'],
      'tsp': [
        't',
        'tsp',
        'tsps',
        'tspn',
        'teaspoon',
        'teaspoons',
        'teaspoonful',
        'teaspoonfuls',
      ],
      'tbsp': [
        'T',
        'tbsp',
        'tbsps',
        'tbs',
        'tbl',
        'tbls',
        'tblsp',
        'tablespoon',
        'tablespoons',
        'tablespoonful',
        'tablespoonfuls',
      ],
      'cup': ['c', 'C', 'cup', 'cups', 'cupful', 'cupfuls'],
      'fl oz': [
        'fl oz',
        'fl. oz.',
        'fl.oz',
        'floz',
        'fl ounce',
        'fl ounces',
        'fluid ounce',
        'fluid ounces',
      ],
      'pint': ['pint', 'pints', 'pt', 'pts'],
      'quart': ['quart', 'quarts', 'qt', 'qts'],
      'gallon': ['gallon', 'gallons', 'gal', 'gals'],
      'ml': [
        'ml',
        'mls',
        'milliliter',
        'milliliters',
        'millilitre',
        'millilitres',
      ],
      'l': ['l', 'L', 'liter', 'liters', 'litre', 'litres', 'ltr'],
    };
    for (final e in spellings.entries) {
      for (final s in e.value) {
        _read(
          '4.1 "$s" is ${e.key}',
          '3 $s rice',
          3,
          unit: e.key,
          food: 'rice',
        );
        if (s.length > 1) {
          _read(
            '4.1 "${s.toUpperCase()}" is ${e.key} (case does not matter)',
            '3 ${s.toUpperCase()} rice',
            3,
            unit: e.key,
            food: 'rice',
          );
        }
      }
    }
    _read(
      '4.1 a period right after a unit is part of it',
      '2 tbsp. butter',
      2,
      unit: 'tbsp',
      food: 'butter',
    );
    _read('4.1 oz.', '3 oz. salmon', 3, unit: 'oz', food: 'salmon');
    _read('4.1 G is gram (4.2)', '3 G rice', 3, unit: 'g');
    _read('4.1 unit with no space', '3tbsp butter', 3, unit: 'tbsp');

    group('household and count units', () {
      const units = {
        'slice': ['slice'],
        'piece': ['piece', 'pc', 'pcs'],
        'serving': ['serving', 'svg'],
        'portion': ['portion'],
        'can': ['can'],
        'bottle': ['bottle'],
        'glass': ['glass'],
        'mug': ['mug'],
        'bowl': ['bowl'],
        'scoop': ['scoop'],
        'clove': ['clove'],
        'container': ['container'],
        'packet': ['packet', 'pkt'],
        'package': ['package', 'pkg'],
        'bag': ['bag'],
        'box': ['box'],
        'carton': ['carton'],
        'jar': ['jar'],
        'pouch': ['pouch'],
        'tub': ['tub'],
        'bar': ['bar'],
        'stick': ['stick'],
        'pat': ['pat'],
        'strip': ['strip'],
        'link': ['link'],
        'patty': ['patty'],
        'fillet': ['fillet', 'filet'],
        'wedge': ['wedge'],
        'leaf': ['leaf'],
        'stalk': ['stalk'],
        'spear': ['spear'],
        'sprig': ['sprig'],
        'head': ['head'],
        'ear': ['ear'],
        'handful': ['handful'],
        'square': ['square'],
        'cube': ['cube'],
        'sheet': ['sheet'],
        'shot': ['shot'],
        'jigger': ['jigger'],
      };
      for (final e in units.entries) {
        for (final s in e.value) {
          // R7: abbreviations take "s" only; whole words take "s" and "es".
          const abbreviations = {'pc', 'pcs', 'svg', 'pkt', 'pkg'};
          final forms = abbreviations.contains(s)
              ? [s, if (s != 'pcs') '${s}s']
              : [s, '${s}s', '${s}es'];
          for (final form in forms) {
            _read(
              '4.1 "$form" is ${e.key}',
              '2 $form food',
              2,
              unit: e.key,
              food: 'food',
            );
          }
        }
      }
      _read(
        '4.1 leaves is the plural of leaf',
        '2 leaves lettuce',
        2,
        unit: 'leaf',
        food: 'lettuce',
      );
      _read('4.1 patties', '2 patties beef', 2, unit: 'patty');
      _read(
        '4.1 a household unit in capitals',
        '2 SLICES toast',
        2,
        unit: 'slice',
      );
    });

    group('a word is a unit only after a quantity or before "of"', () {
      _read(
        '4.1 plain word: coffee cup',
        'coffee cup',
        null,
        food: 'coffee cup',
      );
      _read('4.1 plain word: bar', 'zorbo bar', null, food: 'zorbo bar');
      _read(
        '4.1 plain word: can after food',
        'chicken can soup',
        null,
        food: 'chicken can soup',
      );
      _read('4.1 before "of"', 'can of tuna', 1, unit: 'can', food: 'tuna');
      _read('4.1 before "of": cup', 'cup of coffee', 1, unit: 'cup');
      _read('4.1 after a quantity', '1 can tuna', 1, unit: 'can');
      _read(
        '4.1 after a quantity and a size word',
        '3 thick slices toast',
        3,
        unit: 'slice',
        size: 'thick',
      );
      _read(
        '4.1 a unit that is not directly after the quantity',
        '2 big eggs cup',
        2,
        size: 'large',
        food: 'eggs cup',
      );
    });

    group('multi-word units', () {
      _read('4.1 fl oz', '8 fl oz milk', 8, unit: 'fl oz', food: 'milk');
      _read('4.1 fluid ounces', '8 fluid ounces milk', 8, unit: 'fl oz');
      _read('4.1 fl alone is not a unit', '8 fl milk', 8, food: 'fl milk');
    });
  });

  group('4.2 ambiguous abbreviations', () {
    _read('4.2 T is a tablespoon', '1 T peanut butter', 1, unit: 'tbsp');
    _read('4.2 t is a teaspoon', '1 t honey', 1, unit: 'tsp');
    _read('4.2 c after a number', '2 c rice', 2, unit: 'cup');
    _read('4.2 C after a number', '2 C rice', 2, unit: 'cup');
    _read('4.2 vitamin c is not a unit', 'vitamin c', null, food: 'vitamin c');
    _read(
      '4.2 vitamin C is not a unit',
      'vitamin C tablet',
      null,
      food: 'vitamin C tablet',
    );
    _read('4.2 g after a number', '100 g rice', 100, unit: 'g');
    _read('4.2 G after a number', '100 G rice', 100, unit: 'g');
    _read('4.2 l after a number', '2 l water', 2, unit: 'l');
    _read('4.2 L after a number', '2 L water', 2, unit: 'l');
    _read(
      '4.2 g is not a unit without a number',
      'g rice',
      null,
      food: 'g rice',
    );
    _read(
      '4.2 L is not a unit without a number',
      'L rice',
      null,
      food: 'L rice',
    );
    _read(
      '4.2 a one-letter unit after a size word is not a unit',
      'large g',
      1,
      size: 'large',
      food: 'g',
    );
    _read('4.2 100g', '100g rice', 100, unit: 'g', food: 'rice');
    _read('4.2 2c', '2c rice', 2, unit: 'cup', food: 'rice');
    _read('4.2 1T', '1T peanut butter', 1, unit: 'tbsp');
    _read('4.2 1t', '1t honey', 1, unit: 'tsp');
    _read('4.2 1/2c', '1/2c milk', 0.5, unit: 'cup');
    _read('4.2 500ml', '500ml milk', 500, unit: 'ml');
    _read('4.2 V8 stays a word', '1 can V8', 1, unit: 'can', food: 'V8');
    _read('4.2 7up stays a word', '7up', null, food: '7up');
    _read('4.2 lb', '2 lb steak', 2, unit: 'lb');
    _read('4.2 lbs is the same unit', '2 lbs steak', 2, unit: 'lb');
    test('4.2 oz is read as ounce and left to the food (weight or fluid)', () {
      final d = _one('8 oz milk', '4.2');
      expect(d.unit?.label, 'oz');
    });
    _read('4.2 fl oz is always fluid ounce', '8 fl oz milk', 8, unit: 'fl oz');
  });

  group('4.3 size words and "of"', () {
    const sizes = {
      'small': 'small',
      'medium': 'medium',
      'large': 'large',
      'big': 'large',
      'extra large': 'extra large',
      'extra-large': 'extra large',
      'xl': 'extra large',
      'jumbo': 'jumbo',
      'mini': 'mini',
      'miniature': 'miniature',
      'regular': 'regular',
      'thin': 'thin',
      'thick': 'thick',
    };
    for (final e in sizes.entries) {
      _read(
        '4.3 "${e.key}" right after a quantity',
        '2 ${e.key} eggs',
        2,
        size: e.value,
        food: 'eggs',
      );
      _read(
        '4.3 "${e.key}" at the start of an item',
        '${e.key} coffee',
        1,
        size: e.value,
        food: 'coffee',
      );
      _read(
        '4.3 "${e.key}" between a quantity and a unit',
        '3 ${e.key} slices toast',
        3,
        size: e.value,
        unit: 'slice',
        food: 'toast',
      );
    }
    _read(
      '4.3 a large coffee',
      'a large coffee',
      1,
      size: 'large',
      food: 'coffee',
    );
    _read(
      '4.3 a size word later in the item is a food word',
      'coffee large',
      null,
      food: 'coffee large',
    );
    _read(
      '4.3 extra alone is not a size',
      'extra cheese',
      null,
      food: 'extra cheese',
    );
    _read(
      '4.3 of after a unit: 2 slices of toast',
      '2 slices of toast',
      2,
      unit: 'slice',
      food: 'toast',
    );
    _read(
      '4.3 of after a quantity: half of a bagel',
      'half of a bagel',
      0.5,
      food: 'bagel',
    );
    _read(
      '4.3 of after a quantity: a couple of eggs',
      'a couple of eggs',
      2,
      food: 'eggs',
    );
    _read(
      '4.3 of after a size: 2 large of eggs',
      '2 large of eggs',
      2,
      size: 'large',
      food: 'eggs',
    );
    _read('4.3 of after a plain number', '2 of the eggs', 2, food: 'eggs');
    test('4.3 the amount spans leave "of" out', () {
      const text = '2 slices of toast';
      final d = _one(text, '4.3');
      expect(
        text.substring(d.amountSpans.single.start, d.amountSpans.single.end),
        '2 slices',
      );
    });
  });

  group('2.6 rule 3 compound amounts of the same kind', () {
    test('1 lb 4 oz is 1.25 lb (567 g)', () {
      final d = _one('1 lb 4 oz steak', '2.6.3');
      expect(d.quantity, closeTo(1.25, 1e-9));
      expect(d.unit?.label, 'lb');
      expect(d.quantity! * d.unit!.factor, closeTo(566.99, 0.01));
    });
    _read(
      '2.6.3 1 cup 2 tbsp is 1.125 cup',
      '1 cup 2 tbsp milk',
      1.125,
      unit: 'cup',
    );
    _read(
      '2.6.3 mass in the other direction',
      '4 oz 1 lb steak',
      20,
      unit: 'oz',
    );
    _read(
      '2.6.3 a decimal second amount',
      '1 lb 2.5 oz steak',
      1.15625,
      unit: 'lb',
    );
    _read(
      '2.6.3 mixed kinds do not add',
      '1 cup 4 oz milk',
      1,
      unit: 'cup',
      food: '4 oz milk',
    );
    _read(
      '2.6.3 mass and volume do not add',
      '1 lb 1 cup rice',
      1,
      unit: 'lb',
      food: '1 cup rice',
    );
  });

  group('worked examples 11.2: item count, quantity and unit', () {
    // (number, input, [(quantity, unit)...]). A null quantity means no amount.
    const cases = <(String, String, List<(double?, String?)>)>[
      (
        '1',
        '2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half',
        [(2, null), (2, 'slice'), (1, 'tbsp'), (null, null), (2, 'tbsp')],
      ),
      (
        '2',
        'two eggs two slices of sourdough toast one tablespoon of butter and coffee with two tablespoons of half and half',
        [(2, null), (2, 'slice'), (1, 'tbsp'), (null, null), (2, 'tbsp')],
      ),
      ('16', '1 and 1/2 cups oatmeal', [(1.5, 'cup')]),
      ('17', 'one and a half cups of milk', [(1.5, 'cup')]),
      ('18', 'a cup and a half of milk', [(1.5, 'cup')]),
      ('19', '1½ cups milk', [(1.5, 'cup')]),
      ('20', '1-1/2 cups milk', [(1.5, 'cup')]),
      ('21', '1 1/2 cups milk', [(1.5, 'cup')]),
      ('22', 'three quarters of a cup of milk', [(0.75, 'cup')]),
      ('23', '.5 cup almonds', [(0.5, 'cup')]),
      ('24', 'half a bagel', [(0.5, null)]),
      ('25', 'a couple of eggs', [(2, null)]),
      ('26', 'an apple', [(1, null)]),
      ('27', 'eggs x3', [(3, null)]),
      ('28', '2x 100g chicken breast', [(200, 'g')]),
      ('29', '2-3 eggs', [(2.5, null)]),
      ('30', 'chicken breast 6 oz', [(6, 'oz')]),
      ('33', '1 T peanut butter, 1 t honey', [(1, 'tbsp'), (1, 'tsp')]),
      ('34', '2c rice', [(2, 'cup')]),
      ('35', '500 ml milk', [(500, 'ml')]),
      ('36', 'a large coffee', [(1, null)]),
      ('37', 'large coffee', [(1, null)]),
      ('38', '2 large eggs', [(2, null)]),
      ('39', '3 thick slices toast', [(3, 'slice')]),
      ('43', 'I had two eggs and a banana', [(2, null), (1, null)]),
      ('44', 'chicken 200g rice 1 cup', [(200, 'g'), (1, 'cup')]),
      ('45', '2 eggs. coffee', [(2, null), (null, null)]),
      (
        '46',
        '2 eggs\n1 banana; black coffee',
        [(2, null), (1, null), (null, null)],
      ),
      ('61', '200 g', [(200, 'g')]),
      ('62', '2 eggs, 2 sl', [(2, null), (2, null)]),
      ('63a', '!!!', []),
      ('63b', ',,, and', []),
      (
        '64',
        'black coffee two eggs and toast',
        [(null, null), (2, null), (null, null)],
      ),
      ('65', 'two eggs a banana', [(2, null), (1, null)]),
      ('66', 'I had a banana', [(1, null)]),
      ('67', 'a dozen eggs', [(12, null)]),
      ('68', 'half a dozen eggs', [(6, null)]),
      ('69', '2 eggs x3', [(6, null)]),
      ('70', '1/2-3/4 cup milk', [(0.625, 'cup')]),
      ('71', '1 can Dr. Pepper', [(1, 'can')]),
      ('76', '2 slices 12 grain bread', [(2, 'slice')]),
      ('77', 'zorbo bar', [(null, null)]),
      ('78', 'leftover pizza', [(null, null)]),
      ('79', 'chicken breast 6 oz grilled', [(6, 'oz')]),
      ('80', 'rice 1 cup cooked', [(1, 'cup')]),
      ('81', 'chicken 200g rice 1 cup cooked', [(200, 'g'), (1, 'cup')]),
      ('82', 'chicken 200g rice', [(200, 'g')]),
      ('83', '1 lb 4 oz steak', [(1.25, 'lb')]),
      ('84', '1 cup 2 tbsp milk', [(1.125, 'cup')]),
      ('85', '2eggs', [(2, null)]),
      ('86', '1/2c milk', [(0.5, 'cup')]),
      ('87', 'a half cup milk', [(0.5, 'cup')]),
      ('88', 'a few almonds', [(null, null)]),
    ];
    for (final (id, input, expected) in cases) {
      test('example $id: "${input.replaceAll('\n', '\\n')}"', () {
        final items = splitItems(input);
        final why = 'worked example $id (11.2), got $items';
        expect(items, hasLength(expected.length), reason: why);
        for (var k = 0; k < expected.length; k++) {
          final (q, u) = expected[k];
          final d = items[k];
          if (q == null) {
            expect(d.quantity, isNull, reason: 'item ${k + 1}: $why');
          } else {
            expect(d.quantity, isNotNull, reason: 'item ${k + 1}: $why');
            expect(
              d.quantity!,
              closeTo(q, 1e-9),
              reason: 'item ${k + 1}: $why',
            );
          }
          expect(d.unit?.label, u, reason: 'item ${k + 1}: $why');
        }
      });
    }

    test('example 36 and 37: the size word is large', () {
      expect(_one('a large coffee', '11.2 ex 36').size, 'large');
      expect(_one('large coffee', '11.2 ex 37').size, 'large');
    });

    test('example 38: the size word is kept for the food to use', () {
      expect(_one('2 large eggs', '11.2 ex 38').size, 'large');
    });

    test('example 39: thick between the number and the unit', () {
      expect(_one('3 thick slices toast', '11.2 ex 39').size, 'thick');
    });

    test('example 29 and 70 are ranges (the Assumed marker)', () {
      expect(_one('2-3 eggs', '11.2 ex 29').isRange, isTrue);
      expect(_one('1/2-3/4 cup milk', '11.2 ex 70').isRange, isTrue);
      expect(_one('1-1/2 cups milk', '11.2 ex 20').isRange, isFalse);
    });

    test('example 61: an amount and no food words', () {
      final d = _one('200 g', '11.2 ex 61');
      expect(d.hasFoodWords, isFalse);
    });

    test('example 62: the half typed last item is an item', () {
      final items = splitItems('2 eggs, 2 sl');
      expect(items[1].foodText, 'sl');
    });

    test('food words of the examples that name them', () {
      expect(_one('1 can Dr. Pepper', 'ex 71').foodText, 'Dr Pepper');
      expect(
        _one('2 slices 12 grain bread', 'ex 76').foodText,
        '12 grain bread',
      );
      expect(
        _one('chicken breast 6 oz grilled', 'ex 79').foodText,
        'chicken breast grilled',
      );
      expect(_one('rice 1 cup cooked', 'ex 80').foodText, 'rice cooked');
      expect(_one('chicken 200g rice', 'ex 82').foodText, 'chicken rice');
      expect(
        splitItems('chicken 200g rice 1 cup cooked')[1].foodText,
        'rice cooked',
      );
      expect(_one('1 lb 4 oz steak', 'ex 83').foodText, 'steak');
      expect(_one('half a bagel', 'ex 24').foodText, 'bagel');
    });
  });
}
