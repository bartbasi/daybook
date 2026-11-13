// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The in-memory word index of the food matcher (docs/parser-grammar.md 5.4 and
// 12.3). It is built once from plain data, so the worker isolate can build it
// from the USDA file and the user's foods without this file knowing about the
// database layer or Flutter.

import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'normalize.dart';
import 'tokens.dart';

/// One food as the index needs it. [ref] is `usda:<id>` or `local:<id>`.
class IndexFood {
  const IndexFood({
    required this.ref,
    required this.description,
    required this.dataset,
    this.energy,
    this.kind,
  });

  final String ref;
  final String description;

  /// `fndds`, `sr_legacy` or `foundation` for USDA foods. Anything else, for
  /// example `local`, for the user's own foods.
  final String dataset;

  /// Energy in kcal per 100 g, for the tie rule of 5.5. Null when unknown.
  final double? energy;

  /// Null for a USDA food. `custom`, `recipe` or `off` for a food of the user.
  final String? kind;
}

/// Reads every food of an open USDA reference database, in id order. The
/// database is the one built by tools/build_food_db.py.
List<IndexFood> readUsdaFoods(Database db) {
  final rows = db.select(
    'SELECT f.id, f.description, f.dataset, n.amount '
    'FROM food f LEFT JOIN food_nutrient n '
    'ON n.food_id = f.id AND n.nutrient_id = 1008 ORDER BY f.id',
  );
  return [
    for (final r in rows)
      IndexFood(
        ref: 'usda:${r['id']}',
        description: r['description'] as String,
        dataset: r['dataset'] as String,
        energy: (r['amount'] as num?)?.toDouble(),
      ),
  ];
}

bool _isNsSegment(List<String> seg) =>
    seg.length >= 3 && seg[0] == 'ns' && seg[1] == 'as' && seg[2] == 'to';

/// Source order of 5.4 key 6: local foods, FNDDS, SR Legacy, Foundation.
int _sourceRank(IndexFood f) {
  if (f.kind != null) return 0;
  switch (f.dataset) {
    case 'fndds':
      return 1;
    case 'sr_legacy':
      return 2;
    case 'foundation':
      return 3;
  }
  return 4;
}

/// Word and joined word pair to food positions, plus what ranking needs per
/// food. Immutable once built. Positions are indexes into [foods].
class SearchIndex {
  SearchIndex._(
    this.foods,
    this._postings,
    this._countable,
    this._pairs,
    this._lastWord,
    this._generic,
    this._source,
  ) {
    _sorted = _postings.keys.toList()..sort();
    for (final w in _sorted) {
      (_byLength[w.length] ??= []).add(w);
    }
  }

  /// Builds the index. Foods are kept in the given order.
  factory SearchIndex.build(Iterable<IndexFood> input) {
    final foods = input.toList(growable: false);
    final lists = <String, List<int>>{};
    final countable = List<List<String>>.filled(foods.length, const []);
    final pairs = List<List<String>>.filled(foods.length, const []);
    final last = List<String>.filled(foods.length, '');
    final generic = List<bool>.filled(foods.length, false);
    final source = List<int>.filled(foods.length, 0);

    for (var i = 0; i < foods.length; i++) {
      final f = foods[i];
      final segs = descriptionSegments(f.description);
      final keys = <String>{};
      final count = <String>{};
      final pr = <String>[];
      var isGeneric = false;
      for (final seg in segs) {
        final ns = _isNsSegment(seg);
        if (ns) isGeneric = true;
        for (final w in seg) {
          keys.add(w);
          if (w == 'nfs') isGeneric = true;
          if (!ns && !neutralDescriptionWords.contains(w)) count.add(w);
        }
        if (!ns) {
          for (var k = 0; k + 1 < seg.length; k++) {
            final joined = seg[k] + seg[k + 1];
            keys.add(joined);
            pr
              ..add(joined)
              ..add(seg[k])
              ..add(seg[k + 1]);
          }
        }
      }
      for (final k in keys) {
        (lists[k] ??= []).add(i);
      }
      countable[i] = count.toList(growable: false);
      pairs[i] = pr;
      last[i] = segs.isEmpty || segs.last.isEmpty ? '' : segs.last.last;
      generic[i] = isGeneric;
      source[i] = _sourceRank(f);
    }
    final postings = <String, Int32List>{
      for (final e in lists.entries) e.key: Int32List.fromList(e.value),
    };
    return SearchIndex._(
      foods,
      postings,
      countable,
      pairs,
      last,
      generic,
      source,
    );
  }

  final List<IndexFood> foods;
  final Map<String, Int32List> _postings;
  final List<List<String>> _countable;
  final List<List<String>> _pairs;
  final List<String> _lastWord;
  final List<bool> _generic;
  final List<int> _source;

  late final List<String> _sorted;
  final Map<int, List<String>> _byLength = {};

  int get length => foods.length;

  /// The positions of the foods that have [word] as a word or a joined pair.
  Int32List postings(String word) => _postings[word] ?? _none;

  /// Whether [word] is an indexed word or joined pair.
  bool contains(String word) => _postings.containsKey(word);

  /// Whether some indexed word starts with [prefix].
  bool hasWordStartingWith(String prefix) {
    var lo = 0;
    var hi = _sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_sorted[mid].compareTo(prefix) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < _sorted.length && _sorted[lo].startsWith(prefix);
  }

  /// Indexed words whose length differs from [length] by at most [slack].
  Iterable<String> wordsNearLength(int length, int slack) sync* {
    for (var l = length - slack; l <= length + slack; l++) {
      yield* _byLength[l] ?? const <String>[];
    }
  }

  /// Per-food data for ranking.
  List<String> countableWords(int i) => _countable[i];

  /// Joined pairs of food [i], as triples: the joined word, then its two parts.
  List<String> joinedPairs(int i) => _pairs[i];

  /// The last word of the food's name, after plural removal.
  String lastWord(int i) => _lastWord[i];

  /// True for an "NFS" entry or one with an "NS as to" segment (5.4).
  bool isGeneric(int i) => _generic[i];

  /// 0 for the user's foods, then 1 FNDDS, 2 SR Legacy, 3 Foundation.
  int sourceRank(int i) => _source[i];

  static final Int32List _none = Int32List(0);
}
