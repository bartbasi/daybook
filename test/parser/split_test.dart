// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Grammar 2.2 to 2.7 (docs/parser-grammar.md): hard separators, protected
// phrases, number phrases, soft separators, dictation splitting and the
// brief's example. Expected values are written from the grammar text.

import 'dart:math';

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
      _items('2.6.1 filler then food', 'I had coffee', ['coffee||']);
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
        'bread|2|slice',
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

  group('review fixes', () {
    // R4: a period after a unit word is not a sentence end only when the word
    // is read as a unit there.
    _items(
      'R4 candy bar is a sentence end',
      'I ate a candy bar. Coffee with milk.',
      ['candy bar|1|', 'Coffee||', 'milk||'],
    );
    _items(
      'R4 fillets is a sentence end',
      'I had two fish fillets. Then rice.',
      ['fish fillets|2|', 'rice||'],
    );
    _items('R4 granola bar', 'a granola bar. coffee', [
      'granola bar|1|',
      'coffee||',
    ]);
    _items(
      'R4 a unit after a size word keeps its period',
      '2 large cups. milk',
      ['milk|2|cup'],
    );

    // R10: tokens with no letter or digit are ignored.
    for (final s in ['-', '/', '%', '×', '- - -', 'x /']) {
      _items('R10 symbol only "$s"', s, s == 'x /' ? ['x||'] : []);
    }
    _items('R10 hyphen between items', '2 eggs - coffee', ['eggs coffee|2|']);
    _items('R10 trailing hyphen', 'coffee - black', ['coffee black||']);
    _items('R10 a range with spaces still works', '2 - 3 eggs', ['eggs|2.5|']);

    // R13: never infinite.
    test('R13 400 digits before eggs is not a quantity', () {
      for (final s in [
        '${'9' * 400} eggs',
        'x${'9' * 400} eggs',
        '${'9' * 308} dozen eggs',
        '${'9' * 300} x ${'9' * 300} eggs',
        '1/${'9' * 400} eggs',
      ]) {
        for (final d in splitItems(s)) {
          expect(
            d.quantity == null || d.quantity!.isFinite,
            isTrue,
            reason: 'R13: "${s.substring(0, 12)}..." gave $d',
          );
          expect(d.multiplier == null || d.multiplier!.isFinite, isTrue);
        }
      }
      expect(splitItems('${'9' * 400} eggs').single.quantity, isNull);
      expect(splitItems('${'9' * 308} dozen eggs').single.quantity, isNull);
    });

    test('R12 5,000 digits parse quickly', () {
      final watch = Stopwatch()..start();
      splitItems('${'1' * 5000} eggs');
      splitItems('${'1' * 5000} percent milk');
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });

    // R3: leading filler is dropped with or without an amount.
    _items('R3 filler without an amount', 'I had coffee', ['coffee||']);
    _items('R3 filler with an amount', 'I had 1 coffee', ['coffee|1|']);
    _items('R3 filler after the amount', '2 my oatmeal', ['oatmeal|2|']);
    _items('R3 only filler', 'I had the', []);
    _items('R3 filler after food stays', 'oatmeal made', ['oatmeal made||']);

    // R11: items with no food.
    _items('R11 vitamin a', 'vitamin a', ['vitamin||']);
    _items('R11 a alone', 'a', []);
    _items('R11 an alone', 'an', []);
    _items('R11 some alone', 'some', []);
    _items('R11 a bare amount stays (example 61)', '200 g', ['|200|g']);
    _items('R11 a unit alone stays', 'a cup', ['|1|cup']);
    _items('R11 a number alone stays', '3', ['|3|']);

    // R14, R15, R7.
    _items(
      'R14 size word between number and unit',
      '2 large cups and a half milk',
      ['milk|2.5|cup'],
    );
    _items('R15 eggs 2x', 'eggs 2x', ['eggs|2|']);
    _items('R15 eggs 2 x', 'eggs 2 x', ['eggs|2|']);
    _items('R15 2 eggs 2x', '2 eggs 2x', ['eggs|4|']);
    _items('R15 sign', 'eggs 2×', ['eggs|2|']);
    _items('R7 the es plural is for whole words only', '2 pcses food', [
      'pcses food|2|',
    ]);
    _items('R7 svges', '2 svges food', ['svges food|2|']);
    _items('R7 pcs', '2 pcs food', ['food|2|piece']);
    _items('R7 pkgs', '2 pkgs food', ['food|2|package']);
    _items('R7 pkts', '2 pkts food', ['food|2|packet']);
    _items('R7 svgs', '2 svgs food', ['food|2|serving']);
    _items('R7 pc', '2 pc food', ['food|2|piece']);
    _items('R7 boxes', '2 boxes food', ['food|2|box']);

    // R9: compound amounts take plain number tokens only.
    _items('R9 word numbers do not add', 'one cup two tablespoons milk', [
      'two tablespoons milk|1|cup',
    ]);
    _items('R9 chain', '1 cup 2 tbsp 1 tsp milk', [
      'milk|${1 + 2 * 14.78676478125 / 236.5882365 + 4.92892159375 / 236.5882365}|cup',
    ]);
  });

  group('prepared user names', () {
    List<String> readWith(String text, List<String> names) => [
      for (final d in splitItems(text, names: UserNames.from(names))) _show(d),
    ];

    test('R5 a digit word inside a product name does not stop a quantity', () {
      expect(readWith('330ml milk', ['Coca-Cola 330ml']), ['milk|330|ml']);
      expect(readWith('100g chicken', ['Chicken 100g pack']), [
        'chicken|100|g',
      ]);
    });

    test('R5 names are cleaned like typed text', () {
      expect(readWith('eggs & toast', ['Eggs & toast']), ['eggs and toast||']);
      expect(readWith('eggs and toast', ['Eggs & toast']), [
        'eggs and toast||',
      ]);
      expect(readWith('coffee with milk', ['Coffee w/ milk']), [
        'coffee with milk||',
      ]);
      expect(readWith('1/2 sandwich lunch', ['1/2 sandwich lunch']), [
        '1/2 sandwich lunch||',
      ]);
      expect(readWith('coca cola 330ml', ['Coca-Cola 330ml']), [
        'coca cola 330 ml||',
      ]);
    });

    test('R5 a one word digit name stays whole', () {
      expect(readWith('7up', ['7up']), ['7up||']);
      expect(readWith('2 5guys', ['5guys']), ['5guys|2|']);
    });

    test('R3 protected names are never filler', () {
      expect(readWith('I had my oatmeal', ['my oatmeal']), ['my oatmeal||']);
      expect(readWith('I had 1 my oatmeal', ['my oatmeal']), ['my oatmeal|1|']);
      expect(readWith('2 my oatmeal', ['my oatmeal']), ['my oatmeal|2|']);
      expect(readWith('I had usual breakfast', ['usual breakfast']), [
        'usual breakfast||',
      ]);
      expect(readWith('I had coffee', []), ['coffee||']);
      expect(readWith('my oatmeal', []), ['oatmeal||']);
    });

    test('the prepared object and the plain strings agree', () {
      const names = ['Eggs and toast', 'my oatmeal', '7up'];
      const text = 'eggs and toast, 2 my oatmeal and 7up';
      expect([
        for (final d in splitItems(text, userNames: names)) _show(d),
      ], readWith(text, names));
    });

    test('the empty set only protects the built-in phrases', () {
      expect(
        [
          for (final d in splitItems('half and half', names: UserNames.empty))
            _show(d),
        ],
        ['half and half||'],
      );
    });

    test('R2 splitting with 1,000 prepared names stays fast', () {
      final names = UserNames.from([
        for (var i = 0; i < 1000; i++) 'Food $i and thing',
        'my oatmeal',
      ]);
      const brief =
          '2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half';
      splitItems(brief, names: names); // warm up
      final watch = Stopwatch()..start();
      const runs = 100;
      late List<ItemDraft> items;
      for (var i = 0; i < runs; i++) {
        items = splitItems(brief, names: names);
      }
      final perRun = watch.elapsedMicroseconds / runs / 1000;
      expect(items, hasLength(5));
      // Generous limit so a slow machine cannot make this flaky.
      expect(perRun, lessThan(8), reason: '$perRun ms per split');
    });
  });

  group('spans', () {
    test('R1 a digit glued to a word before a unicode fraction', () {
      final items = splitItems('to1½ couple');
      for (var k = 1; k < items.length; k++) {
        expect(
          items[k].span.start,
          greaterThanOrEqualTo(items[k - 1].span.end),
          reason: 'overlap in $items',
        );
      }
    });

    test('item spans never overlap, stay in bounds, keep surrogate pairs', () {
      final rnd = Random(7);
      const bits = [
        'to',
        '1',
        '2',
        '½',
        '¾',
        ' ',
        ' ',
        ',',
        ';',
        '.',
        '+',
        '\n',
        '-',
        '/',
        '%',
        '&',
        'w/',
        'and',
        'with',
        'eggs',
        'toast',
        'x',
        '×',
        'cup',
        'g',
        '😀',
        'é',
        'a',
        'half',
        'dozen',
        "'",
        '⁄',
        'oz',
        'plus',
        'of',
        '~',
        '12',
        '3.5',
        'T',
        'I had ',
        'percent',
        '\t',
        '\u{1D400}',
        '7up',
        'x3',
        '2x',
      ];
      for (var n = 0; n < 400; n++) {
        final text = [
          for (var k = 0, len = 1 + rnd.nextInt(14); k < len; k++)
            bits[rnd.nextInt(bits.length)],
        ].join();
        final items = splitItems(text);
        var prevEnd = 0;
        for (final d in items) {
          final reason = 'text ${text.runes.toList()} item $d';
          expect(d.span.start, greaterThanOrEqualTo(prevEnd), reason: reason);
          expect(d.span.end, greaterThanOrEqualTo(d.span.start));
          expect(d.span.end, lessThanOrEqualTo(text.length), reason: reason);
          bool lowAt(int i) =>
              i >= 0 &&
              i < text.length &&
              text.codeUnitAt(i) >= 0xDC00 &&
              text.codeUnitAt(i) <= 0xDFFF;
          expect(lowAt(d.span.start), isFalse, reason: reason);
          expect(lowAt(d.span.end), isFalse, reason: reason);
          for (final s in d.amountSpans) {
            expect(s.start, greaterThanOrEqualTo(d.span.start));
            expect(s.end, lessThanOrEqualTo(d.span.end), reason: reason);
            expect(lowAt(s.start), isFalse, reason: reason);
            expect(lowAt(s.end), isFalse, reason: reason);
          }
          prevEnd = d.span.end;
        }
      }
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
