// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Reading an amount from words: quantities, multipliers, ranges, units, size
// words and "of" (grammar 3 and 4.1 to 4.3). The readers work on a list of
// [Tok] and a start index, and say where they stopped. A protected token
// (grammar 2.3) never matches anything here, so "half and half" is never a
// quantity.

import 'tokens.dart';

/// One word of the cleaned text, with where it sits in that text.
class Tok {
  const Tok(this.text, this.start, this.end, {this.prot = false});

  /// The word as typed after clean-up, case kept, without a trailing period.
  final String text;

  /// The range in the cleaned text.
  final int start;
  final int end;

  /// True when the word belongs to a protected phrase (2.3).
  final bool prot;

  Tok asProtected() => Tok(text, start, end, prot: true);

  @override
  String toString() => prot ? '[$text]' : text;
}

/// A quantity read from [Tok]s: its value, the index after it, and whether it
/// is the midpoint of a range.
typedef QuantityRead = ({double value, int end, bool range});

/// A unit read from [Tok]s.
typedef UnitRead = ({UnitDef def, int end});

/// What [readMeasure] found: a quantity, size and unit, in any combination.
class Measure {
  const Measure({
    required this.quantity,
    required this.isRange,
    required this.unit,
    required this.size,
    required this.amountEnd,
    required this.end,
  });

  /// Null for the vague words ("some", "a few"): no quantity (3.4).
  final double? quantity;
  final bool isRange;
  final UnitDef? unit;
  final String? size;

  /// The index after the amount's own words.
  final int amountEnd;

  /// The index after the amount and a following "of", which is filler.
  final int end;
}

// Lookups.

final Map<String, UnitDef> _unitByWord = {};
final Map<String, UnitDef> _multiWordUnits = {};
final Map<String, UnitDef> _singleLetterUnits = {};

bool _built = false;

void _build() {
  if (_built) return;
  _built = true;
  for (final e in unitTable) {
    for (final s in e.spellings) {
      if (s.length == 1) {
        _singleLetterUnits[s] = e.def;
        continue;
      }
      final key = s
          .toLowerCase()
          .replaceAll('.', '')
          .replaceAll(RegExp(r'\s+'), ' ');
      if (key.contains(' ')) {
        _multiWordUnits[key] = e.def;
      } else {
        _unitByWord[key] = e.def;
      }
    }
  }
  for (final (label, extras) in householdUnits) {
    final def = UnitDef(label, UnitKind.count, 0);
    // Whole words take "s" and "es". Abbreviations take "s" only (R7).
    for (final s in [label, ...extras]) {
      _unitByWord[s] = def;
      _unitByWord['${s}s'] = def;
      if (!householdAbbreviations.contains(s)) _unitByWord['${s}es'] = def;
    }
    final irregular = householdIrregularPlurals[label];
    if (irregular != null) _unitByWord[irregular] = def;
  }
}

/// True when [lower] (lower case, no period) is a unit spelling, or "fl", the
/// first word of `fl. oz.`. A period after these belongs to the word (2.2).
bool isUnitSpelling(String lower) {
  _build();
  return _unitByWord.containsKey(lower) ||
      _singleLetterUnits.containsKey(lower) ||
      _singleLetterUnits.containsKey(lower.toUpperCase()) ||
      lower == 'fl';
}

String? _w(List<Tok> t, int i) =>
    (i < 0 || i >= t.length || t[i].prot) ? null : t[i].text.toLowerCase();

final _integerRe = RegExp(r'^\d+$');
final _decimalRe = RegExp(r'^(\d+\.\d+|\.\d+)$');
final _fractionRe = RegExp(r'^(\d+)/(\d+)$');

/// A whole number, a decimal or a fraction with a non-zero denominator, as one
/// word. Null for anything else.
double? parseNumber(String s) {
  double? v;
  if (_integerRe.hasMatch(s) || _decimalRe.hasMatch(s)) {
    v = double.parse(s);
  } else {
    final m = _fractionRe.firstMatch(s);
    if (m != null) {
      final d = double.parse(m[2]!);
      if (d == 0) return null;
      v = double.parse(m[1]!) / d;
    }
  }
  // A number too large to hold is not a quantity (R13).
  return (v != null && v.isFinite) ? v : null;
}

/// `1-1/2` is a mixed number, `2-3` and `1/2-3/4` are ranges (3.3).
({double value, bool range})? _hyphenForm(String s) {
  final parts = s.split('-');
  if (parts.length != 2) return null;
  final a = parseNumber(parts[0]);
  final b = parseNumber(parts[1]);
  if (a == null || b == null) return null;
  if (_integerRe.hasMatch(parts[0]) && _fractionRe.hasMatch(parts[1])) {
    return (value: a + b, range: false);
  }
  return (value: (a + b) / 2, range: true);
}

// Quantities.

int _skipOf(List<Tok> t, int j) => _w(t, j) == 'of' ? j + 1 : j;

({double value, int end})? _wordNumber(List<Tok> t, int i) {
  final w = _w(t, i);
  if (w == null) return null;
  final one = onesWords[w] ?? teensWords[w];
  if (one != null) return (value: one.toDouble(), end: i + 1);
  final tens = tensWords[w];
  if (tens == null) return null;
  final ones = onesWords[_w(t, i + 1)];
  if (ones != null) return (value: (tens + ones).toDouble(), end: i + 2);
  return (value: tens.toDouble(), end: i + 1);
}

/// A whole number: digits, or a number word such as `five` or `twenty five`.
({double value, int end})? _wholeNumber(List<Tok> t, int i) {
  final w = _w(t, i);
  if (w == null) return null;
  if (_integerRe.hasMatch(w)) return (value: double.parse(w), end: i + 1);
  return _wordNumber(t, i);
}

/// `half`, `a half`, `one half`, `half a`, `half of a`, `a quarter`,
/// `three quarters of a` ... (3.1). The value can be 1 or more only for
/// counted fractions such as `four quarters`.
({double value, int end})? _fractionPhrase(List<Tok> t, int i) {
  int skipOfA(int j) {
    j = _skipOf(t, j);
    final a = _w(t, j);
    return (a == 'a' || a == 'an') ? j + 1 : j;
  }

  var j = i;
  final lead = _w(t, j);
  if ((lead == 'a' || lead == 'one') &&
      fractionWords.containsKey(_w(t, j + 1))) {
    j++;
  }
  final f = _w(t, j);
  if (f != null && fractionWords.containsKey(f)) {
    return (value: fractionWords[f]!, end: skipOfA(j + 1));
  }
  final whole = _wholeNumber(t, i);
  if (whole != null) {
    final c = _w(t, whole.end);
    if (c != null && countedFractionWords.containsKey(c)) {
      return (
        value: whole.value * countedFractionWords[c]!,
        end: skipOfA(whole.end + 1),
      );
    }
  }
  return null;
}

/// A fraction smaller than 1: `1/2`, or a fraction phrase. Used after "and".
({double value, int end})? _fractionPart(List<Tok> t, int i) {
  final w = _w(t, i);
  if (w != null && _fractionRe.hasMatch(w)) {
    final v = parseNumber(w);
    if (v != null && v < 1) return (value: v, end: i + 1);
  }
  final p = _fractionPhrase(t, i);
  if (p != null && p.value < 1) return p;
  return null;
}

bool _isWholeWord(String w) =>
    _integerRe.hasMatch(w) ||
    onesWords.containsKey(w) ||
    teensWords.containsKey(w) ||
    tensWords.containsKey(w);

/// True when [lower] is a quantity word or a size word, so that a unit after
/// it is read as a unit (R4): numbers, number words, `a`, `an`, fraction
/// words, `dozen`, `couple` and size words.
bool isQuantityOrSizeWord(String lower) =>
    _isNumberLike(lower) ||
    fractionWords.containsKey(lower) ||
    countedFractionWords.containsKey(lower) ||
    lower == 'dozen' ||
    lower == 'dozens' ||
    lower == 'couple' ||
    lower == 'fl' ||
    sizeWords.containsKey(lower);

bool _isNumberLike(String w) =>
    w == 'a' ||
    w == 'an' ||
    parseNumber(w) != null ||
    _hyphenForm(w) != null ||
    _isWholeWord(w);

/// True when the `and` at index [k] is part of a number phrase (2.4) and so is
/// not a separator: `1 and 1/2`, `one and a half`, `a cup and a half`.
bool isJoinedAnd(List<Tok> t, int k) {
  if (_w(t, k) != 'and') return false;
  final prev = _w(t, k - 1);
  if (prev != null && _isWholeWord(prev) && _fractionPart(t, k + 1) != null) {
    return true;
  }
  // unit, "and a half"
  final next = _w(t, k + 1);
  if ((next == 'a' || next == 'one') && _w(t, k + 2) == 'half') {
    for (final len in [1, 2]) {
      final u = readUnit(t, k - len, afterNumber: true);
      if (u != null && u.end == k) {
        // A size word may sit between the number and the unit (R14).
        var b = k - len - 1;
        if (_w(t, b) == 'large' && _w(t, b - 1) == 'extra') {
          b -= 2;
        } else if (sizeWords.containsKey(_w(t, b))) {
          b -= 1;
        }
        final before = _w(t, b);
        if (before != null && _isNumberLike(before)) return true;
      }
    }
  }
  return false;
}

/// A number phrase without dozens and ranges (3.1, 2.4). A lone `a` or `an`
/// counts as 1 only when [allowA] says so (2.6 rule 5), but "a" before
/// "dozen" always does.
QuantityRead? _numberPhrase(List<Tok> t, int i, bool allowA) {
  final w = _w(t, i);
  if (w == null) return null;
  if (w == 'a' || w == 'an') {
    final n = _w(t, i + 1);
    if (w == 'a' && (n == 'few' || n == 'little' || n == 'bit')) return null;
    if (n == 'dozen' || n == 'dozens') {
      return (value: 1, end: i + 1, range: false);
    }
    if (w == 'a' && n == 'couple') {
      return (value: 2, end: _skipOf(t, i + 2), range: false);
    }
    final fp = _fractionPhrase(t, i);
    if (fp != null) return (value: fp.value, end: fp.end, range: false);
    return allowA ? (value: 1, end: i + 1, range: false) : null;
  }
  if (w == 'couple') return (value: 2, end: _skipOf(t, i + 1), range: false);
  final fp = _fractionPhrase(t, i);
  if (fp != null) return (value: fp.value, end: fp.end, range: false);

  final whole = _wholeNumber(t, i);
  if (whole != null) {
    if (isJoinedAnd(t, whole.end)) {
      final fr = _fractionPart(t, whole.end + 1);
      if (fr != null) {
        return (value: whole.value + fr.value, end: fr.end, range: false);
      }
    }
    final nextW = _w(t, i + 1);
    if (whole.end == i + 1 && _integerRe.hasMatch(w) && nextW != null) {
      final m = _fractionRe.firstMatch(nextW);
      if (m != null) {
        final f = parseNumber(nextW);
        if (f != null) {
          return (value: whole.value + f, end: i + 2, range: false);
        }
      }
    }
    return (value: whole.value, end: whole.end, range: false);
  }
  final n = parseNumber(w);
  if (n != null) return (value: n, end: i + 1, range: false);
  final h = _hyphenForm(w);
  if (h != null) return (value: h.value, end: i + 1, range: h.range);
  return null;
}

bool _isDozen(String? w) => w == 'dozen' || w == 'dozens';

/// Reads a quantity at [i] (3.1, 3.3): a number in any form, a number word,
/// `dozen`, a fraction phrase, `couple`, a number phrase with "and", or a
/// range (`2 to 3`, `2 or 3`, `2 - 3`, `2-3`) which gives its midpoint.
/// Null when the words at [i] are not a quantity. [allowA] lets a lone `a` or
/// `an` read as 1.
QuantityRead? readQuantity(List<Tok> t, int i, {bool allowA = false}) {
  final w = _w(t, i);
  if (w == null) return null;
  if (_isDozen(w)) return (value: 12, end: _skipOf(t, i + 1), range: false);

  var p = _numberPhrase(t, i, allowA);
  if (p == null) return null;
  var value = p.value;
  var end = p.end;
  var range = p.range;

  final sep = _w(t, end);
  if (sep == 'to' || sep == 'or' || sep == '-') {
    final tail = _numberPhrase(t, end + 1, false);
    if (tail != null) {
      value = (value + tail.value) / 2;
      end = tail.end;
      range = true;
    }
  }
  if (_isDozen(_w(t, end))) {
    value *= 12;
    end = _skipOf(t, end + 1);
  }
  return (value: value, end: end, range: range);
}

/// A multiplier written as `x3`, `x 3`, `×2` at [i]: its value and the index
/// after it (3.2). The number is a plain digit number.
({double value, int end})? readTrailMultiplier(List<Tok> t, int i) {
  final w = _w(t, i);
  if (w != 'x' && w != '×') return null;
  final n = _w(t, i + 1);
  final v = n == null ? null : parseNumber(n);
  return v == null ? null : (value: v, end: i + 2);
}

/// A multiplier written as `2x`, `2 x`, `2×` at [i] (3.2).
({double value, int end})? readLeadMultiplier(List<Tok> t, int i) {
  final n = _w(t, i);
  final v = n == null ? null : parseNumber(n);
  final x = _w(t, i + 1);
  if (v == null || (x != 'x' && x != '×')) return null;
  return (value: v, end: i + 2);
}

// Units.

/// A unit at [i] (4.1, 4.2): one word, or two for `fl oz`, `fl ounce`,
/// `fluid ounce`. One-letter units (`t`, `T`, `c`, `C`, `g`, `G`, `l`, `L`)
/// count only when [afterNumber] is true. Longer spellings ignore case.
UnitRead? readUnit(List<Tok> t, int i, {required bool afterNumber}) {
  _build();
  final w = _w(t, i);
  if (w == null) return null;
  final w2 = _w(t, i + 1);
  if (w2 != null) {
    final d = _multiWordUnits['$w $w2'];
    if (d != null) return (def: d, end: i + 2);
  }
  final raw = t[i].text;
  if (raw.length == 1) {
    if (!afterNumber) return null;
    final d = _singleLetterUnits[raw];
    return d == null ? null : (def: d, end: i + 1);
  }
  final d = _unitByWord[w];
  return d == null ? null : (def: d, end: i + 1);
}

/// A size word at [i] (4.3). `big` is large.
({String label, int end})? readSize(List<Tok> t, int i) {
  final w = _w(t, i);
  if (w == null) return null;
  if (w == 'extra' && _w(t, i + 1) == 'large') {
    return (label: 'extra large', end: i + 2);
  }
  if (w == 'extra') return null;
  final label = sizeWords[w];
  return label == null ? null : (label: label, end: i + 1);
}

/// The vague words (3.4) at [i]: the index after them and a following "of".
int? _readVague(List<Tok> t, int i) {
  for (final phrase in vaguePhrases) {
    final words = phrase.split(' ');
    var ok = true;
    for (var k = 0; k < words.length; k++) {
      if (_w(t, i + k) != words[k]) {
        ok = false;
        break;
      }
    }
    if (ok) return i + words.length;
  }
  return null;
}

// Measures.

/// Reads `quantity [size] [unit [and a half | number unit]] [of]`, or
/// `size [unit] [of]`, or `unit of`, or a vague word (grammar 10.1 `measure`).
/// A size word or a unit followed by "of" with no number means 1 (3.4).
/// Compound amounts of the same kind add up in the first unit (2.6 rule 3):
/// `1 lb 4 oz` is 1.25 lb.
Measure? readMeasure(List<Tok> t, int i, {required bool allowA}) {
  Measure make(
    double? q,
    bool range,
    UnitDef? u,
    String? size,
    int amountEnd,
  ) => Measure(
    quantity: q,
    isRange: range,
    unit: u,
    size: size,
    amountEnd: amountEnd,
    end: _skipOf(t, amountEnd),
  );

  final vague = _readVague(t, i);
  if (vague != null) return make(null, false, null, null, vague);

  final q = readQuantity(t, i, allowA: allowA);
  if (q != null) {
    var j = q.end;
    var value = q.value;
    String? size;
    final s = readSize(t, j);
    if (s != null) {
      size = s.label;
      j = s.end;
    }
    final u = readUnit(t, j, afterNumber: true);
    if (u != null) {
      j = u.end;
      final next = _w(t, j + 1);
      if (isJoinedAnd(t, j) &&
          (next == 'a' || next == 'one') &&
          _w(t, j + 2) == 'half') {
        value += 0.5;
        j += 3;
      } else if (u.def.kind != UnitKind.count) {
        while (true) {
          final n = _w(t, j);
          final v = n == null ? null : parseNumber(n);
          final u2 = v == null ? null : readUnit(t, j + 1, afterNumber: true);
          if (u2 == null || u2.def.kind != u.def.kind) break;
          value += v! * u2.def.factor / u.def.factor;
          j = u2.end;
        }
      }
    }
    return make(value, q.range, u?.def, size, j);
  }

  final s = readSize(t, i);
  if (s != null) {
    var j = s.end;
    final u = readUnit(t, j, afterNumber: false);
    if (u != null) j = u.end;
    return make(1, false, u?.def, s.label, j);
  }

  final u = readUnit(t, i, afterNumber: false);
  if (u != null && _w(t, u.end) == 'of') {
    return make(1, false, u.def, null, u.end);
  }
  return null;
}
