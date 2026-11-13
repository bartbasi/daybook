// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Grammar 2.2 to 2.7 (docs/parser-grammar.md): hard separators, protected
// phrases, number phrases, soft separators, dictation splitting and the
// brief's example. Expected values are written from the grammar text.

import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/split.dart';
import 'package:daybook/parser/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the items of [text] look like, one string each:
/// `food|quantity|unit`, with empty parts left blank.
List<String> _read(String text, {List<String> names = const []}) => [
  for (final d in splitItems(text, userNames: names)) _show(d),
];

String _show(ItemDraft d) {
  final q = d.quantity == null
      ? ''
      : (d.quantity == d.quantity!.roundToDouble()
            ? d.quantity!.toInt().toString()
            : d.quantity.toString());
  return '${d.foodText}|$q|${d.unit?.label ?? ''}';
}

void _items(
  String rule,
  String text,
  List<String> expected, {
  List<String> names = const [],
}) {
  test('$rule: "${text.replaceAll('\n', '\\n')}"', () {
    expect(
      _read(text, names: names),
      expected,
      reason: 'grammar $rule, input "$text"',
    );
  });
}

List<String> _sources(String text) => [
  for (final d in splitItems(text)) text.substring(d.span.start, d.span.end),
];

void main() {
  group('2.2 hard separators', () {
    _items('2.2 new line', '2 eggs\n1 banana', ['eggs|2|', 'banana|1|']);
    _items('2.2 comma', '2 eggs, 1 banana', ['eggs|2|', 'banana|1|']);
    _items('2.2 semicolon', '2 eggs; 1 banana', ['eggs|2|', 'banana|1|']);
    _items('2.2 plus sign', '2 eggs + 1 banana', ['eggs|2|', 'banana|1|']);
    _items('2.2 plus word', '2 eggs plus 1 banana', ['eggs|2|', 'banana|1|']);
    _items('2.2 plus sign without spaces', 'eggs+toast', ['eggs||', 'toast||']);
    _items('2.2 end of sentence', '2 eggs. coffee', ['eggs|2|', 'coffee||']);
    _items('2.2 end of text period', '2 eggs.', ['eggs|2|']);
    _items('2.2 a decimal point is not a sentence end', '1.5 cups milk', [
      'milk|1.5|cup',
    ]);
    _items('2.2 a leading decimal point', '.5 cup almonds', [
      'almonds|0.5|cup',
    ]);
    _items('2.2 a period after a unit spelling: oz.', '3 oz. salmon', [
      'salmon|3|oz',
    ]);
    _items(
      '2.2 a period after a unit spelling: tbsp.',
      '1 oz cheese, 2 tbsp. peanut butter',
      ['cheese|1|oz', 'peanut butter|2|tbsp'],
    );
    _items('2.2 a period after fl. oz.', '8 fl. oz. milk', ['milk|8|fl oz']);
    _items('2.2 fl.oz without a space', '8 fl.oz milk', ['milk|8|fl oz']);
    for (final a in titleAbbreviations) {
      _items('2.2 title abbreviation "$a."', '1 can $a. Pepper', [
        '$a Pepper|1|can',
      ]);
    }
    _items('2.2 title abbreviation in the brief', '1 can Dr. Pepper', [
      'Dr Pepper|1|can',
    ]);
    _items('2.2 a comma is never a decimal point', '1,5 kg', ['|1|', '|5|kg']);
    _items('2.2 empty chunks are dropped', 'eggs,, ,toast', [
      'eggs||',
      'toast||',
    ]);
    _items('2.2 nothing but separators', ',,, and', []);
    _items('2.2 nothing but symbols', '!!!', []);
    _items('2.2 empty text', '', []);
    _items('2.2 a tilde is ignored', '~2 cups milk', ['milk|2|cup']);
  });

  group('2.3 protected phrases', () {
    for (final p in builtInProtectedPhrases) {
      test('2.3 "$p" stays whole on its own', () {
        final items = splitItems(p);
        expect(items, hasLength(1), reason: 'grammar 2.3: $p');
        expect(items.single.foodText.toLowerCase(), p);
        expect(
          items.single.quantity,
          isNull,
          reason: 'no word of a protected phrase is a quantity',
        );
      });
      test('2.3 "$p" stays whole after "with"', () {
        final items = splitItems('coffee with $p');
        expect(items, hasLength(2), reason: 'grammar 2.3: $p');
        expect(items[1].foodText.toLowerCase(), p);
      });
      test('2.3 "$p" stays whole after an amount', () {
        final items = splitItems('2 cups $p');
        expect(items, hasLength(1), reason: 'grammar 2.3: $p');
        expect(items.single.quantity, 2);
        expect(items.single.foodText.toLowerCase(), p);
      });
    }

    _items('2.3 "a la" is never a quantity', 'chicken a la king', [
      'chicken a la king||',
    ]);
    _items('2.3 "a la" after an amount', '1 slice pie a la mode', [
      'pie a la mode|1|slice',
    ]);
    _items('2.3 half and half in the brief', '2 tbsp half and half', [
      'half and half|2|tbsp',
    ]);
    _items(
      '2.3 longest match first: peanut butter and jelly sandwich',
      'peanut butter and jelly sandwich',
      ['peanut butter and jelly sandwich||'],
    );
    _items('2.3 pb&j goes through the clean-up first', 'pb&j', ['pb and j||']);
    _items('2.3 plus is a separator next to food words', 'rice plus beans', [
      'rice||',
      'beans||',
    ]);

    group('the user\'s own names', () {
      _items(
        '2.3 a name with "and"',
        'eggs and toast, coffee',
        ['eggs and toast||', 'coffee||'],
        names: ['Eggs and toast'],
      );
      _items('2.3 without the name it splits', 'eggs and toast, coffee', [
        'eggs||',
        'toast||',
        'coffee||',
      ]);
      _items(
        '2.3 a name with "with"',
        'chicken with broccoli',
        ['chicken with broccoli||'],
        names: ['chicken with broccoli'],
      );
      _items(
        '2.3 a name with "plus"',
        'protein plus shake',
        ['protein plus shake||'],
        names: ['protein plus shake'],
      );
      _items('2.3 a name with a digit', 'a 7 Up', ['7 Up|1|'], names: ['7 Up']);
      _items(
        '2.3 a name with a number word',
        'two guys burger',
        ['two guys burger||'],
        names: ['two guys burger'],
      );
      _items(
        '2.3 a name without those words is not protected',
        '2 slices toast',
        ['toast|2|slice'],
        names: ['toast'],
      );
      _items(
        '2.3 the name is matched in any case',
        'EGGS AND TOAST',
        ['EGGS AND TOAST||'],
        names: ['eggs and toast'],
      );
      _items(
        '2.3 an apostrophe in the name is ignored',
        'moms eggs and ham',
        ['moms eggs and ham||'],
        names: ["Mom's eggs and ham"],
      );
      _items(
        '2.3 a longer user name wins over a built-in one',
        'half and half cereal',
        ['half and half cereal||'],
        names: ['half and half cereal'],
      );
    });
  });

  group('2.4 number phrases that contain "and"', () {
    _items('2.4 whole and fraction', '1 and 1/2 cups oatmeal', [
      'oatmeal|1.5|cup',
    ]);
    _items('2.4 number words and a half', 'one and a half cups of milk', [
      'milk|1.5|cup',
    ]);
    _items('2.4 two and a quarter', 'two and a quarter cups milk', [
      'milk|2.25|cup',
    ]);
    _items('2.4 one and three quarters', '1 and three quarters cups milk', [
      'milk|1.75|cup',
    ]);
    _items('2.4 unit and a half', 'a cup and a half of milk', ['milk|1.5|cup']);
    _items('2.4 quantity, unit and a half', '2 cups and a half milk', [
      'milk|2.5|cup',
    ]);
    _items('2.4 unit and one half', 'a cup and one half milk', [
      'milk|1.5|cup',
    ]);
    _items('2.4 a unicode fraction after and', '1 and ½ cups milk', [
      'milk|1.5|cup',
    ]);
    _items(
      '2.4 3 is not a fraction, so it splits',
      '2 eggs and 3 slices toast',
      ['eggs|2|', 'toast|3|slice'],
    );
    _items(
      '2.4 a food between the number and "and"',
      '2 eggs and 1/2 avocado',
      ['eggs|2|', 'avocado|0.5|'],
    );
    _items('2.4 a fraction of 1 or more is not joined', '1 and 3/2 cups milk', [
      '|1|',
      'milk|1.5|cup',
    ]);
  });

  group('2.5 soft separators', () {
    _items('2.5 with and a quantity', 'coffee with 2 tbsp half and half', [
      'coffee||',
      'half and half|2|tbsp',
    ]);
    _items('2.5 with and no quantity', 'coffee with milk', [
      'coffee||',
      'milk||',
    ]);
    _items('2.5 and splits', 'chicken and rice', ['chicken||', 'rice||']);
    _items('2.5 chicken with broccoli', 'chicken with broccoli', [
      'chicken||',
      'broccoli||',
    ]);
    _items('2.5 w/ and & split', 'coffee w/ cream & sugar', [
      'coffee||',
      'cream||',
      'sugar||',
    ]);
    _items('2.5 w/o is not a separator', 'coffee without sugar', [
      'coffee without sugar||',
    ]);
    _items('2.5 empty pieces are dropped', 'eggs, and toast', [
      'eggs||',
      'toast||',
    ]);
    _items('2.5 and at both ends', 'and eggs and', ['eggs||']);
    _items('2.5 made with', 'oatmeal made with milk', [
      'oatmeal made||',
      'milk||',
    ]);
    _items('2.5 the word "and" in capitals', 'eggs AND toast', [
      'eggs||',
      'toast||',
    ]);
  });

  group('2.6 dictation: rule by rule', () {
    group('rule 1: food words', () {
      _items('2.6.1 only filler words give no item', 'I had', []);
      _items('2.6.1 more filler words give no item', 'I had the', []);
      _items('2.6.1 filler then food', 'I had coffee', ['I had coffee||']);
      _items('2.6.1 filler before the amount is dropped', 'I had two eggs', [
        'eggs|2|',
      ]);
    });

    group('rule 2: a quantity after the food', () {
      _items(
        '2.6.2 amount after the food with units',
        'chicken 200g rice 1 cup',
        ['chicken|200|g', 'rice|1|cup'],
      );
      _items(
        '2.6.2 a quantity with no unit starts a new item',
        'black coffee two eggs and toast',
        ['black coffee||', 'eggs|2|', 'toast||'],
      );
      _items(
        '2.6.2 an item that has an amount does not take another',
        '2 eggs 2 toast',
        ['eggs|2|', 'toast|2|'],
      );
      _items('2.6.2 a bare quantity at the end is the amount', 'eggs 2', [
        'eggs|2|',
      ]);
      _items(
        '2.6.2 a quantity then only a multiplier is the amount',
        'eggs 2 x3',
        ['eggs|6|'],
      );
      _items(
        '2.6.2 a unit followed by "of" starts a new item',
        'eggs 3 slices of toast',
        ['eggs||', 'toast|3|slice'],
      );
      _items(
        '2.6.2 words after the amount stay with the item',
        'chicken breast 6 oz grilled',
        ['chicken breast grilled|6|oz'],
      );
      _items('2.6.2 trailing words: rice 1 cup cooked', 'rice 1 cup cooked', [
        'rice cooked|1|cup',
      ]);
      _items(
        '2.6.2 trailing words leave with the next amount',
        'chicken 200g rice 1 cup',
        ['chicken|200|g', 'rice|1|cup'],
      );
      _items(
        '2.6.2 trailing words leave with the next amount, and cooked stays',
        'chicken 200g rice 1 cup cooked',
        ['chicken|200|g', 'rice cooked|1|cup'],
      );
      _items(
        '2.6.2 the stated cost: no amount for the rice',
        'chicken 200g rice',
        ['chicken rice|200|g'],
      );
      _items(
        '2.6.2 the next quantity is not an amount after the food',
        'chicken 200g rice 2 eggs',
        ['chicken rice|200|g', 'eggs|2|'],
      );
      _items('2.6.2 a before the next item', 'chicken 200g rice a banana', [
        'chicken rice|200|g',
        'banana|1|',
      ]);
      _items(
        '2.6.2 filler words only after the amount stay with it',
        'chicken 200g the 1 cup',
        ['chicken the|200|g', '|1|cup'],
      );
      _items(
        '2.6.2 a unit followed by "of" is not an amount after the food',
        'chicken 200g of rice',
        ['chicken||', 'rice|200|g'],
      );
      _items(
        '2.6.2 foods with no separator and no quantity stay one item',
        'eggs toast',
        ['eggs toast||'],
      );
    });

    group('rule 3: a second quantity before any food word', () {
      _items('2.6.3 part of the food name', '2 slices 12 grain bread', [
        '12 grain bread|2|slice',
      ]);
      _items(
        '2.6.3 a number after a multiplier is the amount',
        '2x 100g chicken breast',
        ['chicken breast|200|g'],
      );
      _items('2.6.3 compound mass', '1 lb 4 oz steak', ['steak|1.25|lb']);
      _items('2.6.3 compound volume', '1 cup 2 tbsp milk', ['milk|1.125|cup']);
      _items('2.6.3 compound volume, other order', '2 tbsp 1 tsp honey', [
        'honey|2.3333333333333335|tbsp',
      ]);
      _items('2.6.3 mixed kinds do not add', '1 cup 4 oz milk', [
        '4 oz milk|1|cup',
      ]);
      _items('2.6.3 oz counts as mass', '1 oz 1 g cheese', [
        'cheese|${1 + 1 / 28.349523125}|oz',
      ]);
      _items('2.6.3 count units do not add', '1 slice 2 slices toast', [
        '2 slices toast|1|slice',
      ]);
      test('2.6.3 compound 1 lb 4 oz is 567 g', () {
        final d = splitItems('1 lb 4 oz steak').single;
        expect(d.quantity! * d.unit!.factor, closeTo(566.99, 0.01));
      });
    });

    group('rule 4: multipliers after food words', () {
      _items('2.6.4 x3', 'eggs x3', ['eggs|3|']);
      _items('2.6.4 2 eggs x3', '2 eggs x3', ['eggs|6|']);
      _items('2.6.4 multiplication sign', 'eggs × 3', ['eggs|3|']);
      _items('2.6.4 upper case X', 'eggs X3', ['eggs|3|']);
      _items('2.6.4 never a new item', 'eggs x 3 toast', ['eggs toast|3|']);
      _items('2.6.4 after a unit amount', '2 cups milk x2', ['milk|4|cup']);
    });

    group('rule 5: a and an', () {
      _items('2.6.5 a couple of', 'a couple of eggs', ['eggs|2|']);
      _items('2.6.5 a few', 'a few almonds', ['almonds||']);
      _items(
        '2.6.5 only filler before: quantity 1 wins over filler',
        'I had a banana',
        ['banana|1|'],
      );
      _items('2.6.5 after food words a new item starts', 'two eggs a banana', [
        'eggs|2|',
        'banana|1|',
      ]);
      _items('2.6.5 an after food words', 'two eggs an apple', [
        'eggs|2|',
        'apple|1|',
      ]);
      _items('2.6.5 inside "a la" they are food words', 'chicken a la king', [
        'chicken a la king||',
      ]);
      _items('2.6.5 a dozen', 'a dozen eggs', ['eggs|12|']);
      _items('2.6.5 a half', 'a half cup milk', ['milk|0.5|cup']);
      _items('2.6.5 a quarter', 'a quarter cup milk', ['milk|0.25|cup']);
      _items('2.6.5 a bit of', 'a bit of butter', ['butter||']);
      _items('2.6.5 a little', 'a little milk', ['milk||']);
      _items(
        '2.6.5 a phrase after food words starts a new item',
        'two eggs a few almonds',
        ['eggs|2|', 'almonds||'],
      );
      _items('2.6.5 an after the amount is filler', '2 slices an bread', [
        'an bread|2|slice',
      ]);
    });
  });

  group('2.7 the brief example', () {
    const brief =
        '2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half';
    const dictated =
        'two eggs two slices of sourdough toast one tablespoon of butter and coffee with two tablespoons of half and half';
    const expected = [
      'eggs|2|',
      'sourdough toast|2|slice',
      'butter|1|tbsp',
      'coffee||',
      'half and half|2|tbsp',
    ];

    test('2.7 five items, read as the "Read items" column says', () {
      expect(_read(brief), expected);
    });

    test('2.7 the items as the "Items" column says', () {
      expect(_sources(brief), [
        '2 eggs',
        '2 slices sourdough toast',
        '1 tbsp butter',
        'coffee',
        '2 tbsp half and half',
      ]);
    });

    test('2.7 only the second quantity has no amount for the coffee', () {
      final items = splitItems(brief);
      expect(items[3].hasAmount, isFalse);
      expect(items[0].unit, isNull);
      expect(items.every((d) => d.hasFoodWords), isTrue);
    });

    test('2.7 the dictated version gives the same five items (example 2)', () {
      expect(_read(dictated), expected);
      expect(_sources(dictated), [
        'two eggs',
        'two slices of sourdough toast',
        'one tablespoon of butter',
        'coffee',
        'two tablespoons of half and half',
      ]);
    });
  });

  group('spans and amounts', () {
    test('spans point into the typed text, not the cleaned text', () {
      const text = 'coffee w/ milk';
      expect(_sources(text), ['coffee', 'milk']);
      final items = splitItems(text);
      expect(items[1].span, const Span(10, 14));
    });

    test('spans survive unicode fractions and apostrophes', () {
      const text = "1½ cups mom's pie, 2 eggs";
      expect(_sources(text), ["1½ cups mom's pie", '2 eggs']);
    });

    test('amount spans cover the quantity and unit only', () {
      const text = 'I had 2 slices of toast';
      final d = splitItems(text).single;
      expect(d.amountSpans, hasLength(1));
      final s = d.amountSpans.single;
      expect(text.substring(s.start, s.end), '2 slices');
    });

    test('a multiplier after the food is its own amount span', () {
      const text = '2 eggs x3';
      final d = splitItems(text).single;
      expect(
        [for (final s in d.amountSpans) text.substring(s.start, s.end)],
        ['2', 'x3'],
      );
    });

    test('adjacent amount parts are merged', () {
      const text = '2x 100g chicken';
      final d = splitItems(text).single;
      expect(
        [for (final s in d.amountSpans) text.substring(s.start, s.end)],
        ['2x 100g'],
      );
    });

    test('items come out in text order across all separators', () {
      expect(
        _read('apple\nbread; corn, dill + egg plus fig. ham and ice with jam'),
        [
          'apple||',
          'bread||',
          'corn||',
          'dill||',
          'egg||',
          'fig||',
          'ham||',
          'ice||',
          'jam||',
        ],
      );
    });
  });

  test('the same text always gives the same items', () {
    const text =
        'two eggs two slices of sourdough toast one tablespoon of butter and coffee';
    final a = [for (final d in splitItems(text)) d.toString()];
    final b = [for (final d in splitItems(text)) d.toString()];
    expect(a, b);
  });
}
