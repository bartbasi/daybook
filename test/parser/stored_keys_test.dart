// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// These are keys the app stores on the user's phone (the learned match key) or
// compares stored names with (the name key). After the first release, changing
// an expected value here means stored rows no longer match, so it needs a
// migration that rewrites or re-keys them.

import 'package:daybook/parser/learned_key.dart';
import 'package:daybook/parser/name_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed inputs and the key each must give, written out by hand.
const nameKeys = <(String, String)>[
  // Case and spaces.
  ('Usual Breakfast', 'usual breakfast'),
  ('MY OATMEAL', 'my oatmeal'),
  ('  extra   spaces  ', 'extra spaces'),
  ('tab\tand\nnewline', 'tab and newline'),
  ('', ''),
  // Apostrophes, straight and curly, and quotes.
  ("mom's", 'moms'),
  ('mom’s', 'moms'),
  ('mom‘s', 'moms'),
  ("O'Brien's potatoes", 'obriens potatoes'),
  ('“usual” breakfast', 'usual breakfast'),
  // The words and, with, without.
  ('pb&j', 'pb and j'),
  ('PB & J', 'pb and j'),
  ('mac & cheese', 'mac and cheese'),
  ('coffee w/ milk', 'coffee with milk'),
  ('coffee w/o sugar', 'coffee without sugar'),
  // Hyphens.
  ('half-and-half', 'half and half'),
  ('hard-boiled egg', 'hard boiled egg'),
  ('V-8 juice', 'v8 juice'),
  ('2-percent latte', '2% latte'),
  ('3-4 eggs', '3 4 eggs'),
  // Percent.
  ('2 percent milk', '2% milk'),
  ('2% milk', '2% milk'),
  ('100% juice', '100% juice'),
  // Digits touching letters.
  ('7up', '7up'),
  ('vitamin b12', 'vitamin b12'),
  ('2eggs', '2 eggs'),
  // Fractions.
  ('1½ cups', '1 1 2 cups'),
  ('½ cup', '1 2 cup'),
  ('1⁄2 cup', '1 2 cup'),
  // Accents, composed and decomposed.
  ('café', 'cafe'),
  ('café', 'cafe'),
  ('crème brûlée', 'creme brulee'),
  ('Jalapeño', 'jalapeno'),
  // Other punctuation.
  ('what?! yes', 'what yes'),
  ('salt, pepper; oil.', 'salt pepper oil'),
  ('chicken (grilled)', 'chicken grilled'),
  ('ben+jerry', 'ben jerry'),
  ('!!!', ''),
];

/// Food words as the amount step leaves them, and the learned key (grammar
/// 7.1: no filler, plurals stemmed, sorted, no synonyms, no negation cut).
const learnedKeys = <(String, String)>[
  // The examples in grammar 7.1.
  ('toast', 'toast'),
  ('sourdough toast', 'sourdough toast'),
  ('toast, sourdough', 'sourdough toast'),
  ('coffee', 'coffee'),
  // Filler words.
  ('the toast', 'toast'),
  ('my oatmeal', 'oatmeal'),
  ('I had eggs', 'egg'),
  ('a toast with butter', 'butter toast'),
  ('the of and', ''),
  // Plurals.
  ('eggs', 'egg'),
  ('oats', 'oat'),
  ('peas', 'pea'),
  ('potatoes', 'potato'),
  ('tomatoes', 'tomato'),
  ('sandwiches', 'sandwich'),
  ('dishes', 'dish'),
  ('boxes', 'box'),
  ('glasses', 'glass'),
  ('cookie', 'cooky'),
  ('cookies', 'cooky'),
  ('brie', 'brie'),
  ('pie', 'pie'),
  ('pies', 'pie'),
  ('berries', 'berry'),
  ('fries', 'fry'),
  ('french fries', 'french fry'),
  ('hummus', 'hummus'),
  ('asparagus', 'asparagus'),
  ('couscous', 'couscous'),
  ('ham', 'ham'),
  // Word order and repeats.
  ('rice and beans', 'bean rice'),
  ('beans and rice', 'bean rice'),
  ('egg egg', 'egg egg'),
  // Negation and synonym words stay as typed.
  ('coffee without sugar', 'coffee sugar without'),
  ('pb', 'pb'),
  ('oj', 'oj'),
  // Numbers.
  ('2% milk', '2% milk'),
  ('v8 juice', 'juice v8'),
  // Accents and case.
  ('Café Latte', 'cafe latte'),
  ('', ''),
];

void main() {
  group('nameKey', () {
    for (final (input, expected) in nameKeys) {
      test('"$input" gives "$expected"', () {
        expect(nameKey(input), expected);
      });
    }

    test('applied twice gives the same key', () {
      for (final (input, _) in nameKeys) {
        expect(nameKey(nameKey(input)), nameKey(input), reason: input);
      }
    });

    test('the table has at least 25 rows', () {
      expect(nameKeys.length, greaterThanOrEqualTo(25));
    });
  });

  group('learnedKey', () {
    for (final (input, expected) in learnedKeys) {
      test('"$input" gives "$expected"', () {
        expect(learnedKey(input), expected);
      });
    }

    test('the table has at least 25 rows', () {
      expect(learnedKeys.length, greaterThanOrEqualTo(25));
    });
  });
}
