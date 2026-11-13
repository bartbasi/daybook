// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The one way names are compared (grammar 6.1): alias phrases, saved meal names
// and typed food text all go through [nameKey], so a stored name and typed text
// always meet.

import 'clean.dart';
import 'normalize.dart';

final _notWord = RegExp(r'[^\p{L}\p{N}%]+', unicode: true);

/// [text] after the character clean-up of 2.1 (so `pb&j` is `pb and j`, `w/` is
/// `with`, `2-percent` is `2%`, `V-8` is `v8`), then lower case, accents and
/// apostrophes removed (composed or decomposed), other punctuation read as a
/// space, words separated by single spaces. No stemming and no filler removal.
String nameKey(String text) {
  final cleaned = cleanText(text).text;
  return foldText(cleaned)
      .replaceAll(_notWord, ' ')
      .trim()
      .replaceAll(RegExp(r' {2,}'), ' ');
}
