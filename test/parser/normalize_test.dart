// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/parser/normalize.dart';
import 'package:daybook/parser/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

// Grammar 5.2 (normalizing text) and 5.3 (synonyms).

void main() {
  group('5.2 step 1: case, accents and apostrophes', () {
    test('lower case and accents removed', () {
      expect(foldText('Café Crème BRÛLÉE'), 'cafe creme brulee');
    });

    test('apostrophes are removed, straight and curly', () {
      expect(foldText("Mom's ’Quote’"), 'moms quote');
      expect(queryWords("mom's soup"), ['mom', 'soup']);
    });
  });

  group('5.2 step 2: words of letters, digits and percent', () {
    test('punctuation splits words, a percent sign stays', () {
      expect(rawWords(foldText('lemon-lime soda, no caffeine')), [
        'lemon',
        'lime',
        'soda',
        'no',
        'caffeine',
      ]);
      expect(rawWords('2% milk (reduced fat)'), [
        '2%',
        'milk',
        'reduced',
        'fat',
      ]);
    });

    test('a description splits into segments at commas and brackets', () {
      expect(descriptionSegments('Milk, reduced fat (2%)'), [
        ['milk'],
        ['reduced', 'fat'],
        ['2%'],
      ]);
      expect(descriptionSegments('Bread, sour dough, toasted'), [
        ['bread'],
        ['sour', 'dough'],
        ['toasted'],
      ]);
    });

    test('descriptions keep their "and", "with" and "of"', () {
      expect(descriptionSegments('Cream, half and half').last, [
        'half',
        'and',
        'half',
      ]);
    });
  });

  group('5.2 step 3: plurals', () {
    final cases = <String, String>{
      'glasses': 'glass', // sses becomes ss
      'berries': 'berry', // ies becomes y
      'potatoes': 'potato', // oes becomes o
      'sandwiches': 'sandwich', // ches
      'dishes': 'dish', // shes
      'boxes': 'box', // xes
      'fizzes': 'fizz', // zes
      'eggs': 'egg', // a final s is dropped
      'peas': 'pea', // 4 letters is enough
      'cheeses': 'cheese',
    };
    cases.forEach((plural, single) {
      test('$plural becomes $single', () {
        expect(stem(plural), single);
      });
    });

    test('5 letters or more ending in ies or ie end in y', () {
      final cases = <String, String>{
        'berries': 'berry',
        'berry': 'berry',
        'fries': 'fry',
        'cookies': 'cooky',
        'cookie': 'cooky',
        'brownies': 'browny',
        'brownie': 'browny',
        'smoothie': 'smoothy',
        'veggies': 'veggy',
        'veggie': 'veggy',
      };
      cases.forEach((w, s) => expect(stem(w), s, reason: '5.2 step 3: $w'));
    });

    test('4 letters ending in ies only lose the s, ie is unchanged', () {
      expect(stem('pies'), 'pie');
      expect(stem('ties'), 'tie');
      expect(stem('pie'), 'pie');
      expect(stem('brie'), 'brie');
    });

    test('singular and plural meet', () {
      for (final (a, b) in [
        ('cookie', 'cookies'),
        ('pie', 'pies'),
        ('brownie', 'brownies'),
        ('berry', 'berries'),
      ]) {
        expect(stem(a), stem(b), reason: '5.2 step 3: $a and $b');
      }
    });

    test('ss, us and is endings stay whole', () {
      for (final w in ['hummus', 'asparagus', 'couscous', 'bass', 'analysis']) {
        expect(stem(w), w, reason: '5.2 step 3: $w stays whole');
      }
    });

    test('words of 3 letters or fewer are left alone', () {
      for (final w in ['egs', 'gas', 'bus', 'oes', 'ies']) {
        expect(stem(w), w);
      }
    });

    test('words without a plural ending are left alone', () {
      for (final w in ['rice', 'milk', '2%', 'v8', 'bread']) {
        expect(stem(w), w);
      }
    });
  });

  group('5.2 step 4: filler words', () {
    test('every filler word is dropped from typed text', () {
      final typed = fillerWords.join(' ');
      expect(queryWords(typed), isEmpty);
    });

    test('a sentence keeps only the food words', () {
      expect(queryWords('I had a bowl of the rice with my chicken'), [
        'bowl',
        'rice',
        'chicken',
      ]);
      expect(queryWords('oatmeal made with milk'), ['oatmeal', 'milk']);
    });

    test('a repeated word counts once', () {
      expect(queryWords('half and half'), ['half']);
    });

    test('an item of filler only has no words', () {
      expect(queryWords('I had'), isEmpty);
      expect(queryWords(''), isEmpty);
    });
  });

  group('5.2 step 6: negation', () {
    test('without and everything after it is left out', () {
      expect(queryWords('coffee without sugar'), ['coffee']);
      expect(queryWords('coffee without sugar or cream'), ['coffee']);
    });

    test('"no" works the same way', () {
      expect(queryWords('coffee with no sugar'), ['coffee']);
      expect(queryWords('pizza no cheese'), ['pizza']);
    });

    test('a negation at the start leaves nothing', () {
      expect(queryWords('no sugar'), isEmpty);
    });
  });

  group('R36: everything negated', () {
    test('words removed by the negation cut, nothing left', () {
      for (final t in ['no sugar', 'without milk', 'no', 'I had no sugar']) {
        final q = readQuery(t);
        expect(q.words, isEmpty, reason: t);
        expect(q.allNegated, isTrue, reason: 'R36: "$t"');
      }
    });

    test('other items are not all negated', () {
      for (final t in ['coffee without sugar', 'coffee', '', 'I had', 'the']) {
        expect(readQuery(t).allNegated, isFalse, reason: '"$t"');
      }
    });
  });

  group('speed of the percent rule', () {
    test('a 5,000 digit input is read quickly', () {
      final text = '1' * 5000;
      final sw = Stopwatch()..start();
      final w = queryWords('$text percent milk');
      sw.stop();
      expect(w, isNotEmpty);
      expect(sw.elapsedMilliseconds, lessThan(2000));
      final sw2 = Stopwatch()..start();
      queryWords('${'1.' * 2500}x');
      queryWords(text);
      expect(sw2.elapsedMilliseconds, lessThan(2000));
    });

    test('a decimal before percent still works', () {
      // A point splits words (5.2 step 2), so "2.5" gives "2" and "5%".
      expect(queryWords('2.5 percent milk'), ['2', '5%', 'milk']);
    });
  });

  group('percent', () {
    test('"2 percent" is the word "2%"', () {
      expect(queryWords('2 percent milk'), ['2%', 'milk']);
      expect(queryWords('2% milk'), ['2%', 'milk']);
      expect(queryWords('100 percent orange juice'), [
        '100%',
        'orange',
        'juice',
      ]);
    });
  });

  group('5.3 synonyms', () {
    // Each row of the table: the typed text and the words it is matched as,
    // after plural removal.
    final expected = <String, List<String>>{
      'french toast': ['french', 'toast'],
      'melba toast': ['melba', 'toast'],
      'toast': ['bread', 'toasted'],
      'black coffee': ['coffee'],
      'dr pepper': ['soft', 'drink', 'pepper', 'type'],
      '7 up': ['lemon', 'lime', 'soda'],
      '7up': ['lemon', 'lime', 'soda'],
      'v8': ['tomato', 'vegetable', 'juice'],
      'fries': ['french', 'fry'],
      'pb and j': ['peanut', 'butter', 'jelly'],
      'pbj': ['peanut', 'butter', 'jelly'],
      'pb': ['peanut', 'butter'],
      'oj': ['orange', 'juice'],
      'evoo': ['olive', 'oil'],
      'mac': ['macaroni'],
      'mayo': ['mayonnaise'],
      'coke': ['cola', 'soft', 'drink'],
      'soda': ['soft', 'drink'],
      'burger': ['hamburger'],
      'yoghurt': ['yogurt'],
      'donut': ['doughnut'],
      'skim milk': ['milk', 'fat', 'free', 'skim'],
      'nonfat milk': ['milk', 'fat', 'free', 'skim'],
      'bbq': ['barbecue'],
      'cooked cereal': ['cooked', 'cereal'], // protects from "cereal"
      'cereal bar': ['cereal', 'bar'], // protects from "cereal"
      'cereal': ['cereal', 'ready', 'eat'], // "to" is a filler word
    };

    test('the test covers every row of the table', () {
      expect(expected.keys.toSet(), synonyms.keys.toSet());
    });

    expected.forEach((typed, words) {
      test('"$typed" is matched as $words', () {
        expect(queryWords(typed), words, reason: '5.3 row "$typed"');
      });
    });

    test('the output is not scanned again (example 73)', () {
      // "7up" gives "lemon lime soda", and that "soda" is not turned into
      // "soft drink".
      expect(queryWords('7up'), isNot(contains('soft')));
      expect(queryWords('7up'), ['lemon', 'lime', 'soda']);
      expect(queryWords('coke'), ['cola', 'soft', 'drink']);
    });

    test('the longest phrase wins', () {
      expect(queryWords('french toast'), ['french', 'toast']); // not "toast"
      expect(queryWords('pb and j'), ['peanut', 'butter', 'jelly']); // not "pb"
      expect(queryWords('black coffee toast'), ['coffee', 'bread', 'toasted']);
    });

    test('a synonym inside a longer text', () {
      expect(queryWords('2% pb mayo'), [
        '2%',
        'peanut',
        'butter',
        'mayonnaise',
      ]);
    });

    test('plural typed forms find the synonym', () {
      expect(queryWords('donuts'), ['doughnut']);
      expect(queryWords('burgers'), ['hamburger']);
      expect(queryWords('sodas'), ['soft', 'drink']);
    });

    test('words after a negation are not replaced', () {
      expect(queryWords('coffee without mayo'), ['coffee']);
    });
  });
}
