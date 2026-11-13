// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Normalizing text for matching (docs/parser-grammar.md 5.2) and applying the
// synonym table (5.3). The same steps run on typed food words and on food
// descriptions, so both sides compare as sets of plain words.

import 'tokens.dart';

const _accents = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'ç': 'c', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', //
  'ñ': 'n', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', //
  'ý': 'y', 'ÿ': 'y', //
  'ß': 'ss', //
};

/// Step 1 of 5.2: lower case, accents removed, apostrophes removed.
String foldText(String s) {
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final r in lower.runes) {
    final ch = String.fromCharCode(r);
    if (ch == "'" || ch == '’' || ch == '‘' || ch == 'ʼ') {
      continue;
    }
    if (r >= 0x300 && r <= 0x36f) continue; // combining accents
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

bool _isWordChar(int c) =>
    (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x25;

/// Step 2 of 5.2: words made of letters, digits and `%`, taken from text that
/// [foldText] has already folded. No plural removal yet.
List<String> rawWords(String folded) {
  final out = <String>[];
  var start = -1;
  for (var i = 0; i < folded.length; i++) {
    final w = _isWordChar(folded.codeUnitAt(i));
    if (w && start < 0) start = i;
    if (!w && start >= 0) {
      out.add(folded.substring(start, i));
      start = -1;
    }
  }
  if (start >= 0) out.add(folded.substring(start));
  return out;
}

/// Step 3 of 5.2: a word of 4 letters or more loses a plural ending.
String stem(String w) {
  if (w.length < 4) return w;
  if (w.endsWith('sses')) return w.substring(0, w.length - 2);
  // 5 letters or more: ies and ie both end in y, so cookie and cookies meet.
  // 4 letters (pies, ties) only lose the s; pie and brie stay as they are.
  if (w.length >= 5 && w.endsWith('ies')) {
    return '${w.substring(0, w.length - 3)}y';
  }
  if (w.length >= 5 && w.endsWith('ie')) {
    return '${w.substring(0, w.length - 2)}y';
  }
  if (w.endsWith('oes')) return w.substring(0, w.length - 2);
  if (w.endsWith('ches') ||
      w.endsWith('shes') ||
      w.endsWith('xes') ||
      w.endsWith('zes')) {
    return w.substring(0, w.length - 2);
  }
  if (w.endsWith('s') &&
      !w.endsWith('ss') &&
      !w.endsWith('us') &&
      !w.endsWith('is')) {
    return w.substring(0, w.length - 1);
  }
  return w;
}

/// A description split into segments at commas and opening brackets (5.2
/// step 2), each segment as stemmed words. Filler words are kept: descriptions
/// need "and", "with" and "of" (the neutral words of 5.4).
List<List<String>> descriptionSegments(String description) {
  final folded = foldText(description);
  final out = <List<String>>[];
  var from = 0;
  void cut(int end) {
    final words = rawWords(folded.substring(from, end));
    if (words.isNotEmpty) out.add([for (final w in words) stem(w)]);
  }

  for (var i = 0; i < folded.length; i++) {
    final c = folded[i];
    if (c == ',' || c == '(' || c == '[' || c == '{') {
      cut(i);
      from = i + 1;
    }
  }
  cut(folded.length);
  return out;
}

class _Syn {
  _Syn(this.words, this.output);
  final List<String> words;
  final List<String> output;
}

/// The synonym rows by their first word, longest phrase first (5.3).
final Map<String, List<_Syn>> _synByFirst = () {
  final m = <String, List<_Syn>>{};
  for (final e in synonyms.entries) {
    final words = rawWords(foldText(e.key));
    m
        .putIfAbsent(words.first, () => [])
        .add(_Syn(words, rawWords(foldText(e.value))));
  }
  for (final l in m.values) {
    l.sort((a, b) => b.words.length.compareTo(a.words.length));
  }
  return m;
}();

/// A typed word matches a synonym word when it is the same, or its plural
/// removed form is ("donuts" finds "donut"). Plurals are not named in 5.3.
bool _sameWord(String typed, String key) => typed == key || stem(typed) == key;

/// One pass over [words], replacing synonym phrases, longest first, left to
/// right. The replacement is not scanned again (5.3).
List<String> applySynonyms(List<String> words) {
  final out = <String>[];
  var i = 0;
  while (i < words.length) {
    _Syn? hit;
    for (final key in {words[i], stem(words[i])}) {
      for (final s in _synByFirst[key] ?? const <_Syn>[]) {
        if (i + s.words.length > words.length) continue;
        var ok = true;
        for (var k = 0; k < s.words.length; k++) {
          if (!_sameWord(words[i + k], s.words[k])) {
            ok = false;
            break;
          }
        }
        if (ok && (hit == null || s.words.length > hit.words.length)) hit = s;
      }
    }
    if (hit == null) {
      out.add(words[i]);
      i++;
    } else {
      out.addAll(hit.output);
      i += hit.words.length;
    }
  }
  return out;
}

final _percent = RegExp(r'(\d+(?:\.\d+)?)\s+percent\b');

/// The query words of an item's food text (5.2 steps 1 to 6, 5.3): folded,
/// negated words cut off, synonyms applied once, filler dropped, plurals
/// removed, repeated words dropped. Order follows the text.
List<String> queryWords(String foodText) {
  final folded = foldText(foodText)
      .replaceAllMapped(_percent, (m) => '${m[1]}%');
  var words = rawWords(folded);
  final neg = words.indexWhere((w) => w == 'without' || w == 'no');
  if (neg >= 0) words = words.sublist(0, neg);
  words = applySynonyms(words);
  final seen = <String>{};
  final out = <String>[];
  for (final w in words) {
    if (fillerWords.contains(w)) continue;
    final s = stem(w);
    if (seen.add(s)) out.add(s);
  }
  return out;
}
