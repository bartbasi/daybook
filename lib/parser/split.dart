// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Splitting text into items (grammar 2.2 to 2.7): hard separators, protected
// phrases, number phrases, the soft separators "and" and "with", and the
// dictation rules that start a new item at a quantity. Each item then has its
// amount read (amount.dart).

import 'amount.dart';
import 'clean.dart';
import 'line.dart';
import 'tokens.dart';

/// The user's own names (foods, recipes, cached products, saved meals, alias
/// phrases), prepared once so that splitting does not redo the work on every
/// keystroke. Build one with [UserNames.from] whenever the user's data changes
/// and pass it to [splitItems] and [cleanText].
///
/// Each name goes through the 2.1 clean-up first, so "Eggs & toast" is the
/// phrase `eggs and toast`. It is a protected phrase (2.3) when it has a
/// separator or filler word, a number word or a digit. A name that is one word
/// with digits (`7up`) also stays whole when a number touches letters.
class UserNames {
  const UserNames._(this.keepWhole, this._byFirst);

  /// No user names. Only the built-in phrases are protected.
  static final UserNames empty = UserNames.from(const []);

  factory UserNames.from(Iterable<String> names) {
    final keep = <String>{...baseKeepWhole};
    final phrases = <List<String>>[
      for (final p in builtInProtectedPhrases) p.split(' '),
    ];
    for (final raw in names) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.contains(RegExp(r'\s')) && trimmed.contains(RegExp(r'\d'))) {
        keep.add(trimmed.toLowerCase().replaceAll(RegExp(r'\.+$'), ''));
        continue;
      }
      final words = [
        for (final chunk in _hardChunks(cleanText(trimmed).text))
          for (final t in chunk) t.text.toLowerCase(),
      ];
      if (words.isNotEmpty && words.any(_triggersProtection)) {
        phrases.add(words);
      }
    }
    final byFirst = <String, List<List<String>>>{};
    for (final p in phrases) {
      byFirst.putIfAbsent(p.first, () => []).add(p);
    }
    for (final list in byFirst.values) {
      // Longest first. The sort is stable: ties stay in the order given.
      final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
      indexed.sort((a, b) {
        final c = b.$2.length.compareTo(a.$2.length);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
      list
        ..clear()
        ..addAll([for (final e in indexed) e.$2]);
    }
    return UserNames._(keep, byFirst);
  }

  /// Lower case words with digits that stay whole (`7up`).
  final Set<String> keepWhole;

  final Map<String, List<List<String>>> _byFirst;

  /// The number of words of the longest protected phrase that starts at token
  /// [i], or 0.
  int _matchAt(List<Tok> t, int i) {
    final candidates = _byFirst[t[i].text.toLowerCase()];
    if (candidates == null) return 0;
    for (final p in candidates) {
      if (i + p.length > t.length) continue;
      var ok = true;
      for (var k = 1; k < p.length; k++) {
        if (t[i + k].text.toLowerCase() != p[k]) {
          ok = false;
          break;
        }
      }
      if (ok) return p.length;
    }
    return 0;
  }
}

bool _isNumberWord(String w) =>
    onesWords.containsKey(w) ||
    teensWords.containsKey(w) ||
    tensWords.containsKey(w) ||
    fractionWords.containsKey(w) ||
    w == 'dozen' ||
    w == 'couple' ||
    w.contains(RegExp(r'\d'));

/// A user name is protected when it has a separator or filler word (`and`,
/// `with`, `plus`, `my`), a number word or a digit (2.3).
bool _triggersProtection(String w) =>
    fillerWords.contains(w) || _isNumberWord(w);

/// Splits [text] into items and reads each item's amount. Deterministic: the
/// same text and user names always give the same items.
///
/// Pass [names] prepared once. [userNames] is the slow way to give plain
/// strings: they are prepared again on every call.
List<ItemDraft> splitItems(
  String text, {
  UserNames? names,
  Iterable<String> userNames = const [],
}) {
  final un =
      names ??
      (userNames.isEmpty ? UserNames.empty : UserNames.from(userNames));
  final clean = cleanText(text, names: un);
  final out = <ItemDraft>[];
  for (final chunk in _hardChunks(clean.text)) {
    final marked = _markProtected(chunk, un);
    for (final part in _splitWhere(marked, (t, k) => _isWord(t[k], 'plus'))) {
      final pieces = _splitWhere(
        part,
        (t, k) =>
            _isWord(t[k], 'with') ||
            (_isWord(t[k], 'and') && !isJoinedAnd(t, k)),
      );
      for (final piece in pieces) {
        out.addAll(_scanPiece(piece, clean));
      }
    }
  }
  return out;
}

bool _isWord(Tok t, String w) => !t.prot && t.text.toLowerCase() == w;

/// Splits at every index where [isSep] is true, dropping the separators and
/// empty parts.
List<List<Tok>> _splitWhere(
  List<Tok> t,
  bool Function(List<Tok> t, int k) isSep,
) {
  final out = <List<Tok>>[];
  var cur = <Tok>[];
  for (var k = 0; k < t.length; k++) {
    if (isSep(t, k)) {
      if (cur.isNotEmpty) out.add(cur);
      cur = [];
    } else {
      cur.add(t[k]);
    }
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

// Hard separators.

final _wordRe = RegExp(r'\S+');
final _nonDecimalPeriod = RegExp(r'\.(?!\d)');
final _tokenRe = RegExp(r'[^\s,;+]+|[,;+\n]');

/// Grammar 2.2: cuts the cleaned text at new lines, commas, semicolons, `+` and
/// sentence ends, and splits it into words. The word `plus` is cut later,
/// after protected phrases are marked. A period after a title abbreviation
/// belongs to the word, and so does a period after a unit spelling when the
/// word is read as a unit there: after a quantity or a size word, or before
/// "of" (R4). A period before a digit is a decimal point; any other period
/// inside a word separates words.
List<List<Tok>> _hardChunks(String s) {
  final chunks = <List<Tok>>[];
  var cur = <Tok>[];
  void cut() {
    if (cur.isNotEmpty) chunks.add(cur);
    cur = [];
  }

  final matches = _tokenRe.allMatches(s).toList();
  for (var n = 0; n < matches.length; n++) {
    final m = matches[n];
    final g = m[0]!;
    if (g == ',' || g == ';' || g == '+' || g == '\n') {
      cut();
      continue;
    }
    var core = g.replaceAll('~', ' ');
    var trailing = 0;
    while (core.endsWith('.')) {
      core = core.substring(0, core.length - 1);
      trailing++;
    }
    core = core.replaceAll(_nonDecimalPeriod, ' ');
    final words = _wordRe.allMatches(core).toList();
    for (final w in words) {
      cur.add(Tok(w[0]!, m.start + w.start, m.start + w.end));
    }
    if (trailing > 0) {
      if (words.isEmpty) {
        cut();
      } else {
        final last = words.last[0]!.toLowerCase();
        var absorbed = titleAbbreviations.contains(last);
        if (!absorbed && isUnitSpelling(last)) {
          final prev = cur.length >= 2 ? cur[cur.length - 2].text : null;
          final nextIsOf =
              n + 1 < matches.length &&
              matches[n + 1][0]!.toLowerCase() == 'of';
          absorbed =
              last == 'fl' ||
              nextIsOf ||
              (prev != null && isQuantityOrSizeWord(prev.toLowerCase()));
        }
        if (!absorbed) cut();
      }
    }
  }
  cut();
  return chunks;
}

// Protected phrases.

/// Marks the words of protected phrases, longest match first, left to right.
List<Tok> _markProtected(List<Tok> t, UserNames names) {
  final out = List<Tok>.of(t);
  var i = 0;
  while (i < t.length) {
    final hit = names._matchAt(t, i);
    if (hit == 0) {
      i++;
    } else {
      for (var k = 0; k < hit; k++) {
        out[i + k] = t[i + k].asProtected();
      }
      i += hit;
    }
  }
  return out;
}

// Dictation.

/// An item being built while the words of a piece are read left to right.
class _Item {
  _Item(this.start);

  final int start;
  final parts = <(int, int)>[]; // token ranges that make up the amount
  final dropped = <int>{}; // leading filler, "of" after the amount, symbols
  int foodWords = 0;
  bool measureDone = false;
  double? base;
  double? mult;
  bool range = false;
  UnitDef? unit;
  String? size;

  /// The index after an amount typed after the food, and where the words after
  /// it start (2.6 rule 2). Both are -1 when there is no such amount.
  int postEnd = -1;
  int trailStart = -1;

  bool get hasAmount => measureDone || mult != null;

  void setMeasure(Measure m, int from) {
    measureDone = true;
    base = m.quantity;
    range = m.isRange;
    unit = m.unit;
    size = m.size;
    parts.add((from, m.amountEnd));
    for (var k = m.amountEnd; k < m.end; k++) {
      dropped.add(k);
    }
  }

  void addMult(double v, int from, int to) {
    mult = (mult ?? 1) * v;
    parts.add((from, to));
  }
}

/// True when a quantity that ends at [j] could be an amount after the food:
/// a unit follows that is not followed by "of", or nothing follows except a
/// trailing multiplier (2.6 rule 2).
bool _amountAfterFood(List<Tok> t, int j) {
  final u = readUnit(t, j, afterNumber: true);
  if (u != null) {
    return !(u.end < t.length &&
        !t[u.end].prot &&
        t[u.end].text.toLowerCase() == 'of');
  }
  if (j >= t.length) return true;
  final m = readTrailMultiplier(t, j);
  return m != null && m.end >= t.length;
}

final _hasLetterOrDigit = RegExp(r'[\p{L}\p{M}\d]', unicode: true);

/// A word with no letter or digit: `-`, `/`, `%`, `×` (R10).
bool _isSymbol(Tok t) => !t.prot && !_hasLetterOrDigit.hasMatch(t.text);

bool _isFiller(Tok t) =>
    !t.prot && (fillerWords.contains(t.text.toLowerCase()) || _isSymbol(t));

/// Grammar 2.6: splits one piece into items and reads each amount.
List<ItemDraft> _scanPiece(List<Tok> t, CleanText clean) {
  final out = <ItemDraft>[];
  var cur = _Item(0);

  void finish(_Item it, int end) {
    final d = _build(it, end, t, clean);
    if (d != null) out.add(d);
  }

  var i = 0;
  while (i < t.length) {
    final tok = t[i];
    if (tok.prot) {
      cur.foodWords++;
      i++;
      continue;
    }
    final lw = tok.text.toLowerCase();

    // A multiplier (`x3`, `x 3`) belongs to the current item (2.6 rule 4). So
    // does `2x` after food words at the end of the piece (R8).
    var mult = readTrailMultiplier(t, i);
    if (mult == null && cur.foodWords > 0) {
      final lead = readLeadMultiplier(t, i);
      if (lead != null && lead.end >= t.length) mult = lead;
    }
    if (mult != null) {
      final inTrail = cur.postEnd >= 0 && i == cur.trailStart;
      cur.addMult(mult.value, i, mult.end);
      if (cur.postEnd >= 0) {
        if (inTrail) {
          cur.postEnd = mult.end;
          cur.trailStart = mult.end;
        } else {
          cur.trailStart = -1;
        }
      }
      i = mult.end;
      continue;
    }

    // A word with no letter or digit is ignored once the readers had their
    // chance (R10).
    if (_isSymbol(tok)) {
      cur.dropped.add(i);
      i++;
      continue;
    }

    if (cur.foodWords == 0) {
      if (!cur.measureDone) {
        final lead = cur.mult == null ? readLeadMultiplier(t, i) : null;
        if (lead != null) {
          cur.addMult(lead.value, i, lead.end);
          i = lead.end;
          continue;
        }
        final m = readMeasure(t, i, allowA: true);
        if (m != null) {
          cur.setMeasure(m, i);
          i = m.end;
          continue;
        }
      } else {
        // A second quantity before any food word is part of the name, with a
        // unit right after it (2.6 rule 3).
        final q = readQuantity(t, i);
        if (q != null) {
          var end = q.end;
          final u = readUnit(t, end, afterNumber: true);
          if (u != null) end = u.end;
          cur.foodWords += end - i;
          i = end;
          continue;
        }
      }
      // Leading filler is never part of the food words (R3).
      if (_isFiller(tok)) {
        cur.dropped.add(i);
      } else {
        cur.foodWords++;
      }
      i++;
      continue;
    }

    // After food words.
    if (lw == 'a' || lw == 'an') {
      finish(cur, i);
      cur = _Item(i);
      continue;
    }
    final q = readQuantity(t, i);
    if (q != null) {
      final core = _amountAfterFood(t, q.end);
      if (core && cur.postEnd >= 0 && cur.trailStart >= 0) {
        var trailHasFood = false;
        for (var k = cur.trailStart; k < i; k++) {
          if (t[k].prot || !_isFiller(t[k])) trailHasFood = true;
        }
        if (trailHasFood) {
          final from = cur.trailStart;
          finish(cur, from);
          cur = _Item(from);
          for (var k = from; k < i; k++) {
            if (!_isFiller(t[k])) cur.foodWords++;
          }
        }
      }
      if (core && !cur.hasAmount) {
        final m = readMeasure(t, i, allowA: false)!;
        cur.setMeasure(m, i);
        cur.postEnd = m.end;
        cur.trailStart = m.end;
        i = m.end;
        continue;
      }
      finish(cur, i);
      cur = _Item(i);
      continue;
    }
    if (!_isFiller(tok)) cur.foodWords++;
    i++;
  }
  finish(cur, t.length);
  return out;
}

/// Turns the tokens [it.start, end) into an item, or null when there is
/// nothing in it but filler words, or only a lone "a" or "an" (R11).
ItemDraft? _build(_Item it, int end, List<Tok> t, CleanText clean) {
  if (end <= it.start) return null;
  final inAmount = <int>{
    for (final (a, b) in it.parts)
      for (var k = a; k < b; k++) k,
  };
  final food = <Tok>[
    for (var k = it.start; k < end; k++)
      if (!inAmount.contains(k) && !it.dropped.contains(k) && !_isSymbol(t[k]))
        t[k],
  ];
  final hasFood = food.any((w) => w.prot || !_isFiller(w));

  // A number too large to hold is not a quantity (R13).
  var quantity = it.mult == null ? it.base : (it.base ?? 1) * it.mult!;
  if (quantity != null && !quantity.isFinite) quantity = null;
  final multiplier = (it.mult != null && it.mult!.isFinite) ? it.mult : null;
  if (!hasFood && quantity == null) return null;
  if (!hasFood &&
      it.unit == null &&
      it.size == null &&
      it.mult == null &&
      it.parts.length == 1 &&
      it.parts.single.$2 - it.parts.single.$1 == 1 &&
      (t[it.parts.single.$1].text.toLowerCase() == 'a' ||
          t[it.parts.single.$1].text.toLowerCase() == 'an')) {
    return null;
  }

  // Merge adjacent amount parts into spans of the original text.
  final ranges = it.parts.where((p) => p.$1 < end).toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));
  final amountSpans = <Span>[];
  var k = 0;
  while (k < ranges.length) {
    final a = ranges[k].$1;
    var b = ranges[k].$2;
    while (k + 1 < ranges.length && ranges[k + 1].$1 <= b) {
      k++;
      if (ranges[k].$2 > b) b = ranges[k].$2;
    }
    amountSpans.add(clean.originalSpan(t[a].start, t[b - 1].end));
    k++;
  }

  return ItemDraft(
    span: clean.originalSpan(t[it.start].start, t[end - 1].end),
    foodText: food.map((w) => w.text).join(' '),
    hasFoodWords: hasFood,
    quantity: quantity,
    multiplier: multiplier,
    isRange: it.range,
    unit: it.unit,
    size: it.size,
    amountSpans: amountSpans,
  );
}
