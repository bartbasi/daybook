// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/parser/user_snapshot.dart';
import 'package:daybook/parser/user_snapshot_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Speed budgets of task 2.5, half of the phone targets in grammar 12.3 because
// the test machine is faster than a phone: building the USDA index under 1.5 s,
// a re-parse after one keystroke at p95 under 8 ms while typing the brief's
// example, a parse of 10 new items under 25 ms. The parse is the whole text
// each time: the item cache comes in a later task. Real database, warmed up,
// and a user snapshot with a few hundred names.

const _brief =
    '2 eggs, 2 slices sourdough toast, 1 tbsp butter, '
    'coffee with 2 tbsp half and half';

const _tenItems =
    '2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp '
    'half and half, 1 cup oatmeal, a banana, 200g chicken breast, '
    '1 cup rice, 2 tbsp peanut butter';

const _typos = '2 cups brocolli and mozarellla cheese with spinnach, cappucino';

const _indexBudgetMs = 1500;
const _keystrokeP95Ms = 8.0;
const _tenItemsMs = 25.0;

UserSnapshotData _plausibleData() {
  const words = [
    'protein', 'bar', 'shake', 'chili', 'stew', 'bowl', 'wrap', 'salad',
    'soup', 'pasta', 'burrito', 'smoothie', 'muffin', 'cookie', 'pancake',
    'omelet', 'curry', 'sandwich', 'yogurt', 'granola', //
  ];
  const adj = [
    'turkey', 'spicy', 'homemade', 'green', 'sweet', 'mom', 'quick', 'big',
    'light', 'roasted', //
  ];
  String name(int i) =>
      '${adj[i % adj.length]} ${words[(i ~/ 3) % words.length]}'
      '${i >= 60 ? ' $i' : ''}';
  return UserSnapshotData(
    version: 1,
    foods: [
      for (var i = 0; i < 120; i++)
        UserFoodData(
          ref: 'local:$i',
          name: name(i) + (i % 7 == 0 ? ' and rice' : ''),
          kind: i % 5 == 0 ? 'recipe' : 'custom',
          baseUnit: i % 2 == 0 ? 'g' : 'serving',
          baseAmount: i % 2 == 0 ? 100 : 1,
          portions: [PortionData('1 serving', 150)],
          nutrients: {1008: 100.0 + i, 203: 5, 205: 20, 204: 3},
        ),
    ],
    learned: [
      for (var i = 0; i < 100; i++)
        LearnedMatchData(
          key: 'item$i key',
          foodRef: 'usda:${2705000 + i}',
          foodName: 'x',
        ),
    ],
    aliases: [for (var i = 0; i < 60; i++) AliasData('my meal $i', 1 + i % 40)],
    savedMeals: [
      for (var i = 1; i <= 40; i++)
        SavedMealData(
          id: i,
          name: 'Saved meal $i',
          items: [
            for (var k = 0; k < 4; k++)
              SavedMealItemData(
                foodRef: 'usda:2707153',
                foodName: 'Egg',
                quantity: 1,
                unitLabel: '',
                baseQuantity: 50,
                baseUnit: 'g',
                nutrients: const {1008: 88},
              ),
          ],
        ),
    ],
    historyCounts: {
      'usda:2707153': 40,
      'usda:2710373': 30,
      for (var i = 0; i < 200; i++) 'local:$i': i % 9,
    },
  );
}

double _percentile(List<double> sorted, double p) =>
    sorted[((sorted.length - 1) * p).round()];

/// Typing [text] one character at a time: each prefix is parsed with the
/// cursor at its end. Returns the time of each parse in ms.
List<double> _typeOnce(Parser parser, UserSnapshot snapshot, String text) {
  final times = <double>[];
  for (var n = 1; n <= text.length; n++) {
    final sw = Stopwatch()..start();
    parser.parseMeal(text.substring(0, n), n, snapshot);
    times.add(sw.elapsedMicroseconds / 1000);
  }
  return times;
}

String _stats(List<double> sorted) =>
    'median ${_percentile(sorted, 0.5).toStringAsFixed(2)} ms, p95 '
    '${_percentile(sorted, 0.95).toStringAsFixed(2)} ms, max '
    '${sorted.last.toStringAsFixed(2)} ms';

/// Runs [measure] up to 3 times (stopping early when a run meets [budget]) and
/// returns the run with the lowest 95th percentile, so one busy moment on the
/// machine does not fail the test. The budget itself is not loosened.
({double p95, String message}) _bestOf3(
  String name,
  double budget,
  List<double> Function() measure,
) {
  var best = double.infinity;
  var message = '';
  final runs = <String>[];
  for (var run = 0; run < 3; run++) {
    final times = measure()..sort();
    final p95 = _percentile(times, 0.95);
    runs.add('${times.length} parses, ${_stats(times)}');
    if (p95 < best) best = p95;
    if (best < budget) break;
  }
  message =
      '$name: best p95 ${best.toStringAsFixed(2)} ms '
      '(budget $budget ms); runs: ${runs.join(' | ')}';
  return (p95: best, message: message);
}

void main() {
  late Database db;
  late List<IndexFood> foods;
  late SearchIndex index;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('daybook_bench');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(db.close);
  });

  test('building the USDA index takes under $_indexBudgetMs ms', () {
    // One throwaway build first so the code is compiled and the file is
    // cached by the system, as it would be a second launch. Then the fastest
    // of 3 builds, reading the foods from the database included.
    SearchIndex.build(readUsdaFoods(db));
    var best = 1 << 30;
    final runs = <String>[];
    for (var i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      foods = readUsdaFoods(db);
      final read = sw.elapsedMilliseconds;
      index = SearchIndex.build(foods);
      final total = sw.elapsedMilliseconds;
      runs.add('read $read ms + build ${total - read} ms = $total ms');
      if (total < best) best = total;
    }
    final msg =
        'index of ${foods.length} foods: fastest of 3 $best ms '
        '(budget $_indexBudgetMs ms); ${runs.join(' | ')}';
    printOnFailure(msg);
    expect(best, lessThan(_indexBudgetMs), reason: msg);
  });

  test('re-parsing after a keystroke, p95 under $_keystrokeP95Ms ms', () {
    final loader = SqliteUsdaFoods(db);
    addTearDown(loader.dispose);
    final parser = Parser(index, loader.call);
    final snapshot = UserSnapshot.from(_plausibleData());
    for (var pass = 0; pass < 3; pass++) {
      _typeOnce(parser, snapshot, _brief);
    }
    final r = _bestOf3(
      'keystroke',
      _keystrokeP95Ms,
      () => [
        for (var pass = 0; pass < 10; pass++)
          ..._typeOnce(parser, snapshot, _brief),
      ],
    );
    printOnFailure(r.message);
    expect(r.p95, lessThan(_keystrokeP95Ms), reason: r.message);
  });

  test('typing misspelled words, p95 under $_keystrokeP95Ms ms', () {
    // The slowest path: every new misspelled prefix looks for a near word.
    // Each pass starts cold, with its own index, parser and food loader, so no
    // correction is remembered from an earlier pass.
    final snapshot = UserSnapshot.from(_plausibleData());
    List<double> pass() {
      final ix = SearchIndex.build(foods);
      final loader = SqliteUsdaFoods(db);
      try {
        return _typeOnce(Parser(ix, loader.call), snapshot, _typos);
      } finally {
        loader.dispose();
      }
    }

    pass();
    pass(); // warm the code, not the caches
    final r = _bestOf3(
      'misspelled keystrokes',
      _keystrokeP95Ms,
      () => [for (var i = 0; i < 4; i++) ...pass()],
    );
    printOnFailure(r.message);
    expect(r.p95, lessThan(_keystrokeP95Ms), reason: r.message);
  });

  test('a parse of 10 new items takes under $_tenItemsMs ms', () {
    final snapshot = UserSnapshot.from(_plausibleData());
    // Each timed parse has a fresh parser and a fresh food loader, so loading
    // every food's portions and nutrients from the database is part of it.
    // (The statements are prepared outside the timer: that happens once per
    // app run, not per parse.)
    List<double> run(int n) {
      final times = <double>[];
      for (var i = 0; i < n; i++) {
        final loader = SqliteUsdaFoods(db);
        final parser = Parser(index, loader.call);
        final sw = Stopwatch()..start();
        final lines = parser.parseMeal(_tenItems, -1, snapshot);
        times.add(sw.elapsedMicroseconds / 1000);
        loader.dispose();
        expect(lines, hasLength(10));
      }
      return times;
    }

    run(5);
    final r = _bestOf3('10 new items', _tenItemsMs, () => run(30));
    printOnFailure(r.message);
    expect(r.p95, lessThan(_tenItemsMs), reason: r.message);
  });
}
