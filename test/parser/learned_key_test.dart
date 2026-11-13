// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/parser/learned_key.dart';
import 'package:daybook/parser/split.dart';
import 'package:flutter_test/flutter_test.dart';

// Grammar 7.1: the learned key.

/// The key of the first item of typed text, the way the parser makes it.
String _keyOf(String text) => learnedKey(splitItems(text).first.foodText);

void main() {
  group('the examples of 7.1', () {
    test('toast has the key "toast"', () {
      expect(_keyOf('toast'), 'toast');
    });

    test('2 slices sourdough toast has the key "sourdough toast"', () {
      expect(_keyOf('2 slices sourdough toast'), 'sourdough toast');
    });

    test('toast, sourdough has the same key (sorted)', () {
      expect(learnedKey('toast, sourdough'), 'sourdough toast');
      expect(learnedKey('toast sourdough'), learnedKey('sourdough toast'));
    });

    test('large coffee has the key "coffee"', () {
      expect(_keyOf('large coffee'), 'coffee');
    });
  });

  group('the steps', () {
    test('lower case', () {
      expect(learnedKey('Sourdough TOAST'), 'sourdough toast');
    });

    test('filler words are removed', () {
      expect(learnedKey('a bowl of the oatmeal'), 'bowl oatmeal');
      expect(learnedKey('my oatmeal'), 'oatmeal');
    });

    test('plurals are stemmed', () {
      expect(learnedKey('eggs'), 'egg');
      expect(learnedKey('berries'), 'berry');
      expect(learnedKey('Potatoes, fried'), 'fried potato');
    });

    test('the negation cut is not applied', () {
      expect(learnedKey('coffee without sugar'), 'coffee sugar without');
      expect(learnedKey('coffee'), isNot(learnedKey('coffee without sugar')));
    });

    test('the synonym table is not applied', () {
      expect(learnedKey('burger'), 'burger');
      expect(learnedKey('pb'), 'pb');
    });

    test('words with a percent sign stay whole', () {
      expect(learnedKey('2% milk'), '2% milk');
    });

    test('only filler gives an empty key', () {
      expect(learnedKey('I had a'), '');
    });
  });
}
