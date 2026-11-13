// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Grammar 2.1, row by row (docs/parser-grammar.md). Expected values are
// written from the grammar text, not from the code.

import 'package:daybook/parser/clean.dart';
import 'package:daybook/parser/line.dart';
import 'package:flutter_test/flutter_test.dart';

String _clean(String s, {List<String> names = const []}) =>
    cleanText(s, userNames: names).text;

void _row(
  String rule,
  String input,
  String expected, {
  List<String> names = const [],
}) {
  test('2.1 $rule: "$input"', () {
    expect(_clean(input, names: names), expected, reason: 'grammar 2.1, $rule');
  });
}

void main() {
  group('2.1 row 1: unicode fractions', () {
    const fractions = {
      '½': '1/2',
      '⅓': '1/3',
      '⅔': '2/3',
      '¼': '1/4',
      '¾': '3/4',
      '⅕': '1/5',
      '⅖': '2/5',
      '⅗': '3/5',
      '⅘': '4/5',
      '⅙': '1/6',
      '⅚': '5/6',
      '⅐': '1/7',
      '⅛': '1/8',
      '⅜': '3/8',
      '⅝': '5/8',
      '⅞': '7/8',
      '⅑': '1/9',
      '⅒': '1/10',
    };
    for (final e in fractions.entries) {
      _row('fraction alone', e.key, e.value);
      _row('fraction after a digit gets a space', '1${e.key}', '1 ${e.value}');
    }
    _row('example from the grammar', '1½ cups', '1 1/2 cups');
    _row('fraction in a sentence', 'add ¾ cup', 'add 3/4 cup');
  });

  group('2.1 row 2: fraction slash', () {
    _row('U+2044 becomes slash', '1⁄2', '1/2');
  });

  group('2.1 row 3: ampersand', () {
    _row('pb&j', 'pb&j', 'pb and j');
    _row('spaced', 'salt & pepper', 'salt and pepper');
  });

  group('2.1 rows 4 and 5: w/ and w/o', () {
    _row('w/ with a space', 'coffee w/ milk', 'coffee with milk');
    _row('w/ without a space', 'coffee w/milk', 'coffee with milk');
    _row('w/o', 'coffee w/o sugar', 'coffee without sugar');
    _row('w/o at the end', 'tea w/o', 'tea without');
  });

  group('2.1 row 6: percent', () {
    _row('2 percent', '2 percent milk', '2% milk');
    _row('100 percent', '100 percent orange juice', '100% orange juice');
    _row('decimal percent', '1.5 percent milk', '1.5% milk');
    _row('upper case', '2 PERCENT milk', '2% milk');
    _row('percent sign is kept', '2% milk', '2% milk');
  });

  group('2.1 row 7: curly quotes and apostrophes', () {
    _row('apostrophe', "mom's pie", 'moms pie');
    _row('curly apostrophe', 'mom’s pie', 'moms pie');
    _row('curly double quotes', '“pie”', 'pie');
    _row('left single quote', '‘pie', 'pie');
  });

  group('2.1 rows 8 to 10: hyphens', () {
    _row('between letters: half-and-half', 'half-and-half', 'half and half');
    _row('between letters: extra-large', 'extra-large', 'extra large');
    _row('between letters: hard-boiled', 'hard-boiled', 'hard boiled');
    _row('between letters: twenty-five', 'twenty-five', 'twenty five');
    _row('letter then digit: V-8', 'V-8', 'V8');
    _row('digit then letter', '2-eggs', '2 eggs');
    _row('digits both sides: range', '2-3', '2-3');
    _row('digits both sides: mixed number', '1-1/2', '1-1/2');
    _row('digits both sides: fraction range', '1/2-3/4', '1/2-3/4');
    _row('range in a sentence', '2-3 eggs', '2-3 eggs');
  });

  group('2.1 row 11: other characters', () {
    _row('!!! becomes nothing', '!!!', '');
    _row('exclamation after a word', 'eggs!', 'eggs');
    _row('symbols between words', 'a@b#c', 'a b c');
    _row('brackets', 'eggs (large)', 'eggs large');
    _row('colon and star', 'eggs: *2', 'eggs 2');
    _row(
      'kept: comma semicolon period slash percent plus hyphen tilde',
      'a,b;c.d/e%f+1-2~h',
      'a,b;c.d/e%f+1-2~h',
    );
    _row('kept: new line', 'a\nb', 'a\nb');
    _row('multiplication sign is kept as its own word', '2×eggs', '2 × eggs');
    _row('tab becomes a space', 'a\tb', 'a b');
    _row('carriage return becomes a space', 'a\r\nb', 'a\nb');
    _row('runs of spaces collapse', 'a   b', 'a b');
    _row('spaces at the ends go', '  a  ', 'a');
  });

  group('2.1 words that contain digits', () {
    for (final w in ['V8', 'G2', 'B12']) {
      _row('$w stays one word', w, w);
    }
    _row('Gatorade G2', 'Gatorade G2', 'Gatorade G2');
    _row('vitamins B6 and B12', 'vitamins B6 and B12', 'vitamins B6 and B12');
    _row('x3 is a multiplier', 'x3', 'x 3');
    _row('X3 keeps its case', 'X3', 'X 3');
    _row('x12 is a multiplier', 'eggs x12', 'eggs x 12');
    _row('x2.5 is a multiplier', 'x2.5', 'x 2.5');
    _row('multiplication sign then digits', '×3', '× 3');
  });

  group('2.1 a number touching letters is split', () {
    _row('100g', '100g', '100 g');
    _row('2c', '2c', '2 c');
    _row('1T', '1T', '1 T');
    _row('1/2c', '1/2c', '1/2 c');
    _row('2x', '2x', '2 x');
    _row('2eggs', '2eggs', '2 eggs');
    _row('decimal', '1.5kg', '1.5 kg');
    _row('leading decimal point', '.5cup', '.5 cup');
    _row('number, unit and food', '100g chicken', '100 g chicken');
    _row('500ml', '500ml', '500 ml');
    _row('vulgar fraction then unit', '½c', '1/2 c');
    _row('mixed number then unit', '1½c milk', '1 1/2 c milk');
  });

  group('2.1 exceptions: synonym entries, protected phrases, user names', () {
    _row('7up is a synonym entry', '7up', '7up');
    _row('7UP keeps its case', '1 7UP', '1 7UP');
    _row('v8 as a synonym entry', 'v8', 'v8');
    _row(
      'a user name that is one word with digits keeps them',
      '5Guys burger',
      '5Guys burger',
      names: ['5Guys'],
    );
    _row(
      'R5 a digit word inside a longer name does not keep them',
      '330ml milk',
      '330 ml milk',
      names: ['Coca-Cola 330ml'],
    );
    _row(
      'R5 a digit word of a longer name: 5guys',
      '5guys burger',
      '5 guys burger',
      names: ['5Guys Burger'],
    );
    _row('without the name it is split', '5guys burger', '5 guys burger');
    _row(
      'a different word is still split',
      '2eggs',
      '2 eggs',
      names: ['5Guys Burger'],
    );
  });

  group('2.1 case is kept until the units step', () {
    _row('T and t', '1T 1t', '1 T 1 t');
    _row('mixed case words', 'Coffee W/ MILK', 'Coffee with MILK');
  });

  group('the way back to the typed text', () {
    test('an untouched word maps to itself', () {
      final c = cleanText('2 eggs');
      expect(c.text, '2 eggs');
      expect(c.originalSpan(2, 6), const Span(2, 6));
    });

    test('a replaced word maps to what it replaced', () {
      final c = cleanText('coffee w/ milk');
      expect(c.text, 'coffee with milk');
      expect(c.originalSpan(7, 11), const Span(7, 9), reason: '"with" is "w/"');
      expect(c.originalSpan(12, 16), const Span(10, 14), reason: '"milk"');
    });

    test('a unicode fraction maps to the characters that made it', () {
      final c = cleanText('1½ cups');
      expect(c.text, '1 1/2 cups');
      expect(c.originalSpan(0, 5), const Span(0, 2));
      expect(c.originalSpan(6, 10), const Span(3, 7));
    });

    test('removed characters shift what follows', () {
      final c = cleanText("mom's pie");
      expect(c.text, 'moms pie');
      expect(c.originalSpan(5, 8), const Span(6, 9));
    });

    test('an empty range is an empty span', () {
      final c = cleanText('eggs');
      expect(c.originalSpan(2, 2), const Span(2, 2));
      expect(c.originalSpan(4, 4), const Span(4, 4));
    });
  });

  group('hyphen between a digit and a letter', () {
    _row('2-percent', '2-percent milk', '2% milk');
    _row('2-eggs', '2-eggs', '2 eggs');
    _row('3-pack', '3-pack', '3 pack');
    _row('7-up', '7-up', '7 up');
    _row('V-8 still joins', 'V-8', 'V8');
    test('2-percent milk has no quantity of 2', () {
      expect(cleanText('2-percent milk').text, '2% milk');
    });
  });

  group('review fixes', () {
    _row(
      'R12 percent runs after the hyphen rules',
      '2-percent milk',
      '2% milk',
    );
    _row('R12 apostrophe', "mom's", 'moms');
    _row('R12 curly apostrophe', 'mom’s', 'moms');
    _row(
      'R17 a combining accent stays in the word',
      'café au lait',
      'café au lait',
    );
    _row('R17 a hyphen after an accented letter', 'café-au', 'café au');
    test('R1 a unicode fraction maps to its own character', () {
      final c = cleanText('to1½ couple');
      expect(c.text, 'to1 1/2 couple');
      expect(c.originalSpan(2, 3), const Span(2, 3), reason: 'the digit');
      expect(c.originalSpan(4, 7), const Span(3, 4), reason: 'the fraction');
    });
    test('R6 a long run of digits is cleaned quickly', () {
      final watch = Stopwatch()..start();
      cleanText('${'1' * 5000} eggs');
      cleanText('${'1' * 5000} percent');
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });

  test('clean-up is deterministic', () {
    const s = 'Coffee w/ 2 percent milk & 1½ T sugar!!';
    expect(_clean(s), _clean(s));
  });
}
