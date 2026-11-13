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

/// Splits [text] into items and reads each item's amount. Deterministic: the
/// same text and [userNames] always give the same items.
///
/// [userNames] are the user's own names (foods, recipes, cached products,
/// saved meals, alias phrases). Those that contain `and`, `with`, `plus`, a
/// number word or a digit are protected phrases (2.3).
List<ItemDraft> splitItems(
  String text, {
  Iterable<String> userNames = const [],
}) {
  final names = userNames.toList();
  final clean = cleanText(text, userNames: names);
  final phrases = _protectedPhrases(names);
  final out = <ItemDraft>[];
  for (final chunk in _hardChunks(clean.text)) {
    final marked = _markProtected(chunk, phrases);
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

// ------------------------------------------------------- hard separators

final _wordRe = RegExp(r'\S+');
final _nonDecimalPeriod = RegExp(r'\.(?!\d)');
final _tokenRe = RegExp(r'[^\s,;+]+|[,;+\n]');

/// Grammar 2.2: cuts the cleaned text at new lines, commas, semicolons, `+` and
/// sentence ends, and splits it into words. The word `plus` is cut later,
/// after protected phrases are marked. A period after a unit spelling or a
/// title abbreviation belongs to the word; a period before a digit is a
/// decimal point; any other period inside a word separates words.
List<List<Tok>> _hardChunks(String s) {
  final chunks = <List<Tok>>[];
  var cur = <Tok>[];
  void cut() {
    if (cur.isNotEmpty) chunks.add(cur);
    cur = [];
  }

  for (final m in _tokenRe.allMatches(s)) {
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
        if (!isUnitSpelling(last) && !titleAbbreviations.contains(last)) cut();
      }
    }
  }
  cut();
  return chunks;
}

// ------------------------------------------------------ protected phrases

final _nameWordRe = RegExp(r'[^\p{L}\d%]+', unicode: true);

List<String> _nameWords(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[\'‘’]'), '')
    .split(_nameWordRe)
    .where((w) => w.isNotEmpty)
    .toList();

bool _isNumberWord(String w) =>
    onesWords.containsKey(w) ||
    teensWords.containsKey(w) ||
    tensWords.containsKey(w) ||
    fractionWords.containsKey(w) ||
    w == 'dozen' ||
    w == 'couple' ||
    RegExp(r'\d').hasMatch(w);

/// The built-in phrases and those user names that contain a separator word, a
/// number word or a digit (2.3), longest first.
List<List<String>> _protectedPhrases(List<String> userNames) {
  final all = <List<String>>[
    for (final p in builtInProtectedPhrases) p.split(' '),
    for (final n in userNames)
      if (_nameWords(n).any(
        (w) => w == 'and' || w == 'with' || w == 'plus' || _isNumberWord(w),
      ))
        _nameWords(n),
  ].where((p) => p.isNotEmpty).toList();
  // A stable sort: longest first, then in the order given.
  final indexed = [for (var i = 0; i < all.length; i++) (i, all[i])];
  indexed.sort((a, b) {
    final c = b.$2.length.compareTo(a.$2.length);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Marks the words of protected phrases, longest match first, left to right.
List<Tok> _markProtected(List<Tok> t, List<List<String>> phrases) {
  final out = List<Tok>.of(t);
  var i = 0;
  while (i < t.length) {
    var hit = 0;
    for (final p in phrases) {
      if (i + p.length > t.length) continue;
      var ok = true;
      for (var k = 0; k < p.length; k++) {
        if (t[i + k].text.toLowerCase() != p[k]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        hit = p.length;
        break;
      }
    }
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

// ------------------------------------------------------------- dictation

/// An item being built while the words of a piece are read left to right.
class _Item {
  _Item(this.start);

  final int start;
  final parts = <(int, int)>[]; // token ranges that make up the amount
  final dropped = <int>{}; // filler before the amount, and "of" after it
  final pendingFiller = <int>[];
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
    dropped.addAll(pendingFiller);
    pendingFiller.clear();
  }

  void addMult(double v, int from, int to) {
    mult = (mult ?? 1) * v;
    parts.add((from, to));
    dropped.addAll(pendingFiller);
    pendingFiller.clear();
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

bool _isFiller(Tok t) => !t.prot && fillerWords.contains(t.text.toLowerCase());

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
      cur.pendingFiller.clear();
      i++;
      continue;
    }
    final lw = tok.text.toLowerCase();

    // A multiplier (`x3`, `x 3`) belongs to the current item (2.6 rule 4).
    final mult = readTrailMultiplier(t, i);
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
          cur.pendingFiller.clear();
          i = end;
          continue;
        }
      }
      if (_isFiller(tok)) {
        if (!cur.measureDone) cur.pendingFiller.add(i);
      } else {
        cur.foodWords++;
        cur.pendingFiller.clear();
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
/// nothing in it but filler words.
ItemDraft? _build(_Item it, int end, List<Tok> t, CleanText clean) {
  if (end <= it.start) return null;
  final inAmount = <int>{
    for (final (a, b) in it.parts)
      for (var k = a; k < b; k++) k,
  };
  final food = <Tok>[
    for (var k = it.start; k < end; k++)
      if (!inAmount.contains(k) && !it.dropped.contains(k)) t[k],
  ];
  final hasFood = food.any((w) => w.prot || !_isFiller(w));
  final double? quantity = it.mult == null
      ? it.base
      : (it.base ?? 1) * it.mult!;
  if (!hasFood && quantity == null) return null;

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
    multiplier: it.mult,
    isRange: it.range,
    unit: it.unit,
    size: it.size,
    amountSpans: amountSpans,
  );
}
