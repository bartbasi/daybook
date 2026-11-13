// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Finding the food for an item's words (docs/parser-grammar.md 5.2 typos,
// 5.4 candidates and ranking, 5.5 confident match or guess, 5.7 the correction
// sheet's search). Deterministic: the same words, foods and history always
// give the same order, and every tie ends on the food reference text.

import 'dart:typed_data';

import 'line.dart';
import 'normalize.dart';
import 'search_index.dart';

// Kept here for callers that already import it from this file.

/// A candidate food for a query, with the numbers the ranking keys use.
class Candidate {
  const Candidate({
    required this.food,
    required this.matched,
    required this.extra,
    required this.fits,
    required this.timesLogged,
    required this.generic,
    required this.source,
  });

  final IndexFood food;

  /// Key 1: how many query words the food has (as a word or a joined pair).
  final int matched;

  /// Key 3: description words that are neither query words, nor neutral, nor
  /// covered by a joined pair, nor inside an "NS as to" segment.
  final int extra;

  /// Key 2: the user's own food that fits (5.4).
  final bool fits;

  /// Key 4: how many times the user logged this food.
  final int timesLogged;

  /// Key 5: an "NFS" or "NS as to" entry.
  final bool generic;

  /// Key 6: 0 local, 1 FNDDS, 2 SR Legacy, 3 Foundation.
  final int source;

  String get ref => food.ref;
  String get description => food.description;

  @override
  String toString() =>
      '$ref "$description" (words $matched, fits $fits, extra $extra, '
      'logged $timesLogged, generic $generic, source $source)';
}

/// The answer for one item (5.5). [state] is [LineState.matched],
/// [LineState.guess] or [LineState.notFound]. The "amount assumed" state is
/// decided later, from the amount.
class FoodMatch {
  const FoodMatch({
    required this.state,
    required this.words,
    required this.corrected,
    required this.ranked,
    required this.reason,
    this.allNegated = false,
  });

  final LineState state;

  /// True when the item had words but the negation cut (5.2 step 3) removed
  /// every one of them, as in "no sugar". The state is then notFound, but the
  /// parser drops the item instead of showing a not found line (ruling R36).
  final bool allNegated;

  /// The query words after normalizing and typo correction.
  final List<String> words;

  /// True when a typo correction was used (the line is then always a guess).
  final bool corrected;

  /// The best candidates in rank order, at most [Ranker.rankedCount]. The
  /// first is the pick.
  final List<Candidate> ranked;

  /// Which rule of 5.5 made the state, for tests and logs. Holds no user text.
  final String reason;

  Candidate? get top => ranked.isEmpty ? null : ranked.first;
  String? get ref => top?.ref;
}

bool _isLetters(String w) {
  for (var i = 0; i < w.length; i++) {
    final c = w.codeUnitAt(i);
    if (c < 0x61 || c > 0x7a) return false;
  }
  return true;
}

int _compare(Candidate a, Candidate b) {
  if (a.matched != b.matched) return b.matched.compareTo(a.matched); // 1
  if (a.fits != b.fits) return a.fits ? -1 : 1; // 2
  if (a.extra != b.extra) return a.extra.compareTo(b.extra); // 3
  if (a.timesLogged != b.timesLogged) {
    return b.timesLogged.compareTo(a.timesLogged); // 4
  }
  if (a.generic != b.generic) return a.generic ? -1 : 1; // 5
  if (a.source != b.source) return a.source.compareTo(b.source); // 6
  final la = a.description.length;
  final lb = b.description.length;
  if (la != lb) return la.compareTo(lb); // 7
  return a.ref.compareTo(b.ref); // 8
}

bool _tiesOnKeys1To5(Candidate a, Candidate b) =>
    a.matched == b.matched &&
    a.fits == b.fits &&
    a.extra == b.extra &&
    a.timesLogged == b.timesLogged &&
    a.generic == b.generic;

/// Matches item words to foods. Cheap to make: it only holds the indexes, so a
/// new one is made whenever the user's foods or history change, and the large
/// USDA index is reused.
class Ranker {
  /// [usda] is the bundled database, built once. [user] holds the user's own
  /// foods, recipes and cached products (small, rebuilt when they change).
  /// [history] maps a food ref to how many times it was logged.
  Ranker(this.usda, {this.user, this.history = const {}});

  final SearchIndex usda;
  final SearchIndex? user;
  final Map<String, int> history;

  /// A match keeps the pick and up to 7 others for the correction sheet (8.3).
  static const rankedCount = 8;

  /// The sheet's free search lists this many foods (5.7).
  static const searchCount = 20;

  List<SearchIndex> get _parts => [?user, usda];

  /// The best food for an item's food words, and whether it is confident (5.5).
  FoodMatch match(String foodText, {bool negation = true}) {
    final p = _prepare(foodText, negation);
    final q = p.words;
    if (q.isEmpty) {
      return FoodMatch(
        state: LineState.notFound,
        words: const [],
        corrected: false,
        ranked: const [],
        reason: p.allNegated
            ? '5.2 step 3: every word is negated'
            : '5.5: no food words',
        allNegated: p.allNegated,
      );
    }
    final tier = <Candidate>[];
    final ranked = _rank(q, (q.length + 1) ~/ 2, rankedCount, tier);
    if (ranked.isEmpty) {
      return FoodMatch(
        state: LineState.notFound,
        words: q,
        corrected: p.corrected,
        ranked: const [],
        reason: '5.4: no candidate has half of the query words',
      );
    }
    final top = ranked.first;
    String? why;
    if (p.corrected) {
      why = '5.2: a typo was corrected';
    } else if (top.matched < q.length) {
      why = '5.5 rule 1: ${q.length - top.matched} query word(s) not found';
    } else if (top.extra > 0 && top.timesLogged == 0 && !top.fits) {
      why = '5.5 rule 2: ${top.extra} extra word(s), never logged';
    } else {
      final e = top.food.energy;
      if (e != null) {
        final tol = (e.abs() * 0.1) > 5 ? e.abs() * 0.1 : 5.0;
        for (final c in tier) {
          final ce = c.food.energy;
          if (identical(c, top) || ce == null || !_tiesOnKeys1To5(c, top)) {
            continue;
          }
          if ((ce - e).abs() > tol) {
            why =
                '5.5 rule 3: ${c.ref} ties on keys 1 to 5 but its energy '
                '$ce differs from $e by more than 10 percent or 5 kcal';
            break;
          }
        }
      }
    }
    return FoodMatch(
      state: why == null ? LineState.matched : LineState.guess,
      words: q,
      corrected: p.corrected,
      ranked: ranked,
      reason: why ?? '5.5: confident',
    );
  }

  /// The pick plus up to 7 others in rank order, skipping [currentRef] (8.3).
  /// The current pick itself is not in the list: the sheet shows it first.
  List<Candidate> alternatives(FoodMatch m, {String? currentRef}) {
    final out = <Candidate>[];
    for (final c in m.ranked) {
      if (c.ref == currentRef) continue;
      out.add(c);
      if (out.length == rankedCount - 1) break;
    }
    return out;
  }

  /// The correction sheet's search box (5.7): the same normalizing and ranking,
  /// but a food is listed when it has at least one query word. Top [limit].
  List<Candidate> search(String text, {int limit = searchCount}) {
    final q = _prepare(text).words;
    if (q.isEmpty) return const [];
    return _rank(q, 1, limit, null);
  }

  // Typo correction (5.2) and the query words.
  ({List<String> words, bool corrected, bool allNegated}) _prepare(
    String text, [
    bool negation = true,
  ]) {
    final q = readQuery(text, negation: negation);
    var corrected = false;
    final out = <String>[];
    for (final w in q.words) {
      final fix = _correct(w);
      if (fix != null) corrected = true;
      final use = fix ?? w;
      if (!out.contains(use)) out.add(use);
    }
    return (words: out, corrected: corrected, allNegated: q.allNegated);
  }

  // A correction depends only on the word and the two indexes, so it is kept
  // for the life of this Ranker. The indexes keep their own cache of the near
  // words, so a new Ranker for the same USDA index does not start cold.
  final Map<String, String?> _fixes = {};

  /// The closest indexed word for a typed word that is not in the index and is
  /// not the start of an indexed word, or null.
  String? _correct(String w) {
    if (w.length < 4) return null;
    if (_fixes.containsKey(w)) return _fixes[w];
    if (_fixes.length > 1000) _fixes.clear();
    return _fixes[w] = _findFix(w);
  }

  String? _findFix(String w) {
    if (!_isLetters(w)) return null;
    final parts = _parts;
    for (final ix in parts) {
      if (ix.contains(w) || ix.hasWordStartingWith(w)) return null;
    }
    final limit = w.length >= 8 ? 2 : 1;
    final dist = <String, int>{};
    final uses = <String, int>{};
    for (final ix in parts) {
      for (final (c, d) in ix.nearWords(w, limit)) {
        dist[c] = d;
        uses[c] = (uses[c] ?? 0) + ix.postings(c).length;
      }
    }
    String? best;
    for (final c in dist.keys) {
      if (best == null) {
        best = c;
        continue;
      }
      final d = dist[c]!.compareTo(dist[best]!);
      if (d != 0) {
        if (d < 0) best = c;
        continue;
      }
      final u = uses[c]!.compareTo(uses[best]!);
      if (u != 0) {
        if (u > 0) best = c;
        continue;
      }
      if (c.compareTo(best) < 0) best = c;
    }
    return best;
  }

  /// Candidates with at least [need] query words, best [limit] in rank order.
  /// When [topTier] is given it gets every candidate that has as many words as
  /// the best one (the only ones that can tie with it).
  List<Candidate> _rank(
    List<String> q,
    int need,
    int limit,
    List<Candidate>? topTier,
  ) {
    final n = q.length;
    final qset = q.toSet();
    // Candidates by number of matched words: position lists per index.
    final tiers = <List<(SearchIndex, int)>>[
      for (var c = 0; c <= n; c++) <(SearchIndex, int)>[],
    ];
    for (final ix in _parts) {
      final counts = Int32List(ix.length);
      final touched = <int>[];
      for (final w in q) {
        for (final i in ix.postings(w)) {
          if (counts[i] == 0) touched.add(i);
          counts[i]++;
        }
      }
      for (final i in touched) {
        if (counts[i] >= need) tiers[counts[i]].add((ix, i));
      }
    }
    final top = <Candidate>[];
    var first = true;
    for (var c = n; c >= need; c--) {
      final tier = tiers[c];
      if (tier.isEmpty) continue;
      final made = [for (final (ix, i) in tier) _candidate(ix, i, c, n, qset)];
      if (first) {
        topTier?.addAll(made);
        first = false;
      }
      for (final cand in made) {
        _insert(top, cand, limit);
      }
      if (top.length >= limit) break;
    }
    return top;
  }

  void _insert(List<Candidate> top, Candidate c, int limit) {
    if (top.length >= limit && _compare(c, top.last) >= 0) return;
    var lo = 0;
    var hi = top.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_compare(top[mid], c) <= 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    top.insert(lo, c);
    if (top.length > limit) top.removeLast();
  }

  Candidate _candidate(
    SearchIndex ix,
    int i,
    int matched,
    int n,
    Set<String> qset,
  ) {
    final food = ix.foods[i];
    final times = history[food.ref] ?? 0;
    final kind = food.kind;
    final fits =
        kind != null &&
        (kind != 'off' || times > 0) &&
        matched == n &&
        qset.contains(ix.lastWord(i));
    Set<String>? covered;
    final pairs = ix.joinedPairs(i);
    for (var k = 0; k + 2 < pairs.length; k += 3) {
      if (qset.contains(pairs[k])) {
        (covered ??= <String>{})
          ..add(pairs[k + 1])
          ..add(pairs[k + 2]);
      }
    }
    var extra = 0;
    for (final w in ix.countableWords(i)) {
      if (!qset.contains(w) && !(covered?.contains(w) ?? false)) extra++;
    }
    return Candidate(
      food: food,
      matched: matched,
      extra: extra,
      fits: fits,
      timesLogged: times,
      generic: ix.isGeneric(i),
      source: ix.sourceRank(i),
    );
  }
}
