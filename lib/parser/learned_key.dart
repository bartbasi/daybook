// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The learned key of grammar 7.1.

import 'normalize.dart';
import 'tokens.dart';

/// The key a learned match is stored under: the item's food words, lower case,
/// split into words, filler removed, plurals stemmed, sorted alphabetically,
/// joined by single spaces. The negation cut and the synonym table are not
/// applied. Repeated words are kept (the grammar does not say to drop them).
/// Pass the item's food words, from which the amount step already removed the
/// quantity, unit and size.
String learnedKey(String foodWords) {
  final words = [
    for (final w in rawWords(foldText(foodWords)))
      if (!fillerWords.contains(w)) stem(w),
  ]..sort();
  return words.join(' ');
}
