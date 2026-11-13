// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Grammar 4.4 (docs/parser-grammar.md): reading a food's portion labels. Each
// case names the part of 4.4 it checks. Expected values are written from the
// grammar text.

import 'package:daybook/parser/portions.dart';
import 'package:daybook/parser/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

Portion _p(String label, [double grams = 100]) {
  final p = readPortion(label, grams);
  expect(p, isNotNull, reason: 'grammar 4.4: "$label" has a leading number');
  return p!;
}

void main() {
  group('4.4 amount: the leading number', () {
    test('4.4 a whole number', () {
      expect(_p('1 cup').amount, 1);
      expect(_p('12 fl oz').amount, 12);
    });
    test('4.4 a decimal number', () {
      expect(_p('0.5 cup').amount, 0.5);
      expect(_p('.5 cup').amount, 0.5);
    });
    test('4.4 a fraction and a mixed number', () {
      expect(_p('1/2 cup').amount, 0.5);
      expect(_p('1 1/2 cup').amount, 1.5);
      expect(_p('2 3/4 cup').amount, 2.75);
    });
    test('4.4 the amount is not part of the unit phrase', () {
      expect(_p('1 1/2 cup').phrase, 'cup');
      expect(_p('0.5 cup').rest, 'cup');
    });
    test('4.4 labels that do not start with a number are skipped', () {
      expect(readPortion('Skin from 1 medium', 5), isNull);
      expect(readPortion('Quantity not specified, if appetizer', 115), isNull);
      expect(
        readPortion('Quantity not specified, if main course in meal', 402),
        isNull,
      );
      expect(readPortion('', 5), isNull);
    });
    test('4.4 labels that start with a number range are skipped', () {
      expect(readPortion('1-3 ring thin pretzel', 8), isNull);
      expect(readPortion('1-3 ring thick pretzel', 8), isNull);
    });
    test('4.4 a number with no space after it is unclear and skipped', () {
      expect(readPortion('1" wedge', 8), isNull);
    });
    test('4.4 a zero amount or a zero denominator is not usable', () {
      expect(readPortion('0 cup', 8), isNull);
      expect(readPortion('1/0 cup', 8), isNull);
    });
  });

  group('4.4 unit phrase', () {
    test('4.4 up to the first comma', () {
      final p = _p('1 cup, chopped');
      expect(p.phrase, 'cup');
      expect(p.plain, isFalse);
    });
    test('4.4 up to the first opening bracket', () {
      final p = _p('1 cup (8 fl oz)');
      expect(p.phrase, 'cup');
      expect(p.plain, isFalse);
    });
    test('4.4 several words with no comma are all the phrase', () {
      final p = _p('1 medium or regular slice');
      expect(p.phrase, 'medium or regular slice');
      expect(p.plain, isTrue);
    });
    test('4.4 a comma after several words', () {
      expect(_p('1 drink, small (16 fl oz)').phrase, 'drink');
      expect(_p('1 slice, crust not eaten').phrase, 'slice');
    });
    test('4.4 plain means nothing follows the unit phrase', () {
      expect(_p('1 cup').plain, isTrue);
      expect(_p('1 tablespoon').plain, isTrue);
      expect(_p('1 cup, cooked').plain, isFalse);
      expect(_p('1 cup (8 fl oz)').plain, isFalse);
    });
    test('4.4 the phrase words split on slashes', () {
      expect(_p('1 small or thin/very thin slice').phraseWords, [
        'small',
        'or',
        'thin',
        'very',
        'thin',
        'slice',
      ]);
    });
  });

  group('4.4 unit', () {
    test('4.4 fl oz when the phrase starts with it', () {
      expect(_p('1 fl oz').unit?.label, 'fl oz');
      expect(_p('1 fl oz (no ice)').unit?.label, 'fl oz');
      expect(_p('2 fl oz, with ice').unit?.label, 'fl oz');
    });
    test('4.4 the first word of the phrase when it is in the unit tables', () {
      expect(_p('1 cup').unit?.label, 'cup');
      expect(_p('1 cup, cooked').unit?.label, 'cup');
      expect(_p('1 tablespoon').unit?.label, 'tbsp');
      expect(_p('3 oz').unit?.label, 'oz');
      expect(_p('1 oz, cooked').unit?.kind, UnitKind.mass);
      expect(_p('1 lb').unit?.label, 'lb');
      expect(_p('1 slice').unit?.label, 'slice');
      expect(_p('2 slices').unit?.label, 'slice');
      expect(_p('1 can (12 fl oz)').unit?.label, 'can');
    });
    test('4.4 unit kinds: volume, mass and count', () {
      expect(_p('1 cup').unit?.kind, UnitKind.volume);
      expect(_p('1 fl oz').unit?.kind, UnitKind.volume);
      expect(_p('1 oz').unit?.kind, UnitKind.mass);
      expect(_p('1 slice').unit?.kind, UnitKind.count);
    });
    test('4.4 only the first word counts, so a later unit word does not', () {
      expect(_p('1 medium or regular slice').unit, isNull);
      expect(_p('1 small or thin/very thin slice').unit, isNull);
      expect(_p('1 large fillet').unit, isNull);
    });
    test('4.4 a word that is not in the tables gives no unit', () {
      expect(_p('1 egg').unit, isNull);
      expect(_p('1 Bagel Thin').unit, isNull);
      expect(_p('1 drink (12 fl oz)').unit, isNull);
      expect(_p('1 small').unit, isNull);
    });
    test('4.4 case does not matter for the first word', () {
      expect(_p('1 Cup').unit?.label, 'cup');
      expect(_p('1 TABLESPOON').unit?.label, 'tbsp');
    });
    test('4.4 a one letter word in a label is not a unit', () {
      expect(_p('1 T').unit, isNull);
      expect(_p('1 c').unit, isNull);
    });
  });

  group('4.4 grams per unit', () {
    test('4.4 gram weight divided by the amount', () {
      expect(_p('1 cup', 240).gramsPerUnit, 240);
      expect(_p('2 cups', 480).gramsPerUnit, 240);
      expect(_p('1 1/2 cup', 360).gramsPerUnit, 240);
      expect(_p('1/2 cup', 120).gramsPerUnit, 240);
      expect(_p('4 oz', 113.4).gramsPerUnit, closeTo(28.35, 1e-9));
    });
    test(
      '4.4 a weight that is not above zero or not finite is not usable (R29)',
      () {
        expect(readPortion('1 cup', -1), isNull);
        expect(readPortion('1 cup', 0), isNull);
        expect(readPortion('1 cup', double.nan), isNull);
        expect(readPortion('1 cup', double.infinity), isNull);
        final ps = Portions.read([
          ('1 cup', 0),
          ('1 slice', double.nan),
          ('1 egg', 50),
          ('Quantity not specified', 0),
        ]);
        expect(ps.usable.map((p) => p.label), ['1 egg']);
        expect(ps.defaultPortion, isNull, reason: 'R29 default row weight');
        expect(
          Portions.read([('Quantity not specified', double.nan)])
              .defaultPortion,
          isNull,
        );
      },
    );
    test(
      '4.1 abbreviations take s only, not es (same table as amount.dart)',
      () {
        expect(_p('2 pkgs').unit?.label, 'package');
        expect(_p('2 pkges').unit, isNull);
        expect(_p('2 pcs').unit?.label, 'piece');
        expect(_p('2 boxes').unit?.label, 'box');
      },
    );
  });

  group('4.4 what a line shows as the unit (4.7)', () {
    test('4.4 the label after the amount, descriptors kept', () {
      expect(_p('1 small').unitLabel, 'small');
      expect(_p('1 cup, cooked').unitLabel, 'cup, cooked');
      expect(_p('1 drink (12 fl oz)').unitLabel, 'drink (12 fl oz)');
      expect(
        _p('1 medium or regular slice').unitLabel,
        'medium or regular slice',
      );
      expect(_p('1 egg').unitLabel, 'egg');
    });
    test('4.4 a leading unit word is written as its canonical label', () {
      expect(_p('1 tablespoon').unitLabel, 'tbsp');
      expect(_p('1 slices, thin').unitLabel, 'slice, thin');
      expect(_p('1 fl oz (no ice)').unitLabel, 'fl oz (no ice)');
    });
  });

  group('4.4 size and unit words in the phrase', () {
    test('4.4 phraseHasSize finds a word and a two word size', () {
      final p = _p('1 small or thin/very thin slice');
      expect(p.phraseHasSize('small'), isTrue);
      expect(p.phraseHasSize('thin'), isTrue);
      expect(p.phraseHasSize('large'), isFalse);
      expect(_p('1 extra large').phraseHasSize('extra large'), isTrue);
      expect(_p('1 extra large').phraseHasSize('large'), isTrue);
    });
    test('4.4 only the unit phrase is searched, not the descriptors', () {
      final p = _p('1 drink, medium (22 fl oz)');
      expect(p.phraseHasSize('medium'), isFalse);
      expect(p.isMediumOrRegular, isFalse);
    });
    test('4.4 phraseHasUnit matches the plural and a slash', () {
      expect(_p('2 slices').phraseHasUnit('slice'), isTrue);
      expect(_p('1 piece/slice, any size').phraseHasUnit('slice'), isTrue);
      expect(_p('1 medium or regular slice').phraseHasUnit('slice'), isTrue);
      expect(_p('1 single serving container').phraseHasUnit('serving'), isTrue);
      expect(_p('1 egg').phraseHasUnit('slice'), isFalse);
    });
    test('4.4 medium or regular', () {
      expect(_p('1 medium or regular slice').isMediumOrRegular, isTrue);
      expect(_p('1 regular').isMediumOrRegular, isTrue);
      expect(_p('1 medium').isMediumOrRegular, isTrue);
      expect(_p('1 large').isMediumOrRegular, isFalse);
    });
  });

  group('4.4 a food\'s portions, in the stored order', () {
    test('4.4 USDA order is kept and unusable rows are left out', () {
      final ps = Portions.read([
        ('1 cup', 240),
        ('Skin from 1 medium', 5),
        ('1 tablespoon', 15),
        ('1-3 ring thin pretzel', 8),
        ('1 slice', 30),
      ]);
      expect(ps.usable.map((p) => p.label), [
        '1 cup',
        '1 tablespoon',
        '1 slice',
      ]);
      expect(ps.defaultPortion, isNull);
    });
    test('4.4 "Quantity not specified" is the default portion and no unit', () {
      final ps = Portions.read([('1 egg', 50), ('Quantity not specified', 45)]);
      expect(ps.usable.map((p) => p.label), ['1 egg']);
      expect(ps.defaultPortion?.grams, 45);
    });
    test('4.4 only the exact label is the default portion', () {
      final ps = Portions.read([
        ('Quantity not specified, if appetizer', 115),
        ('Quantity not specified, if main course in meal', 402),
        ('1 cup', 240),
      ]);
      expect(ps.defaultPortion, isNull);
      expect(ps.usable.map((p) => p.label), ['1 cup']);
    });
    test('4.4 the exact label is the default next to the two other labels', () {
      final ps = Portions.read([
        ('Quantity not specified', 300),
        ('Quantity not specified, if main course in meal', 402),
        ('Quantity not specified, if appetizer', 115),
      ]);
      expect(ps.defaultPortion?.grams, 300);
      expect(ps.usable, isEmpty);
    });
    test('4.4 hasFluidOunce', () {
      expect(Portions.read([('1 fl oz', 30)]).hasFluidOunce, isTrue);
      expect(Portions.read([('1 cup (8 fl oz)', 240)]).hasFluidOunce, isFalse);
      expect(Portions.read([('1 oz', 28)]).hasFluidOunce, isFalse);
    });
    test('4.4 no rows gives nothing', () {
      final ps = Portions.read(const []);
      expect(ps.usable, isEmpty);
      expect(ps.defaultPortion, isNull);
    });
  });
}
