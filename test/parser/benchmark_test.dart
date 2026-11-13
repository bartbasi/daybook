// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// ignore_for_file: avoid_print

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

void main() {
  late String path;
  late Database db;
  late SearchIndex index;
  late int readMs;
  late int buildMs;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('daybook_bench');
    addTearDown(() => dir.deleteSync(recursive: true));
    path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(db.close);
  });

  test('building the USDA index takes under $_indexBudgetMs ms', () {
    // One throwaway build first so the code is compiled and the file is
    // cached by the system, as it would be a second launch.
    SearchIndex.build(readUsdaFoods(db));
    final sw = Stopwatch()..start();
    final foods = readUsdaFoods(db);
    readMs = sw.elapsedMilliseconds;
    index = SearchIndex.build(foods);
    final total = sw.elapsedMilliseconds;
    buildMs = total - readMs;
    print(
      'index: ${foods.length} foods, read $readMs ms, build $buildMs ms, '
      'total $total ms (budget $_indexBudgetMs ms)',
    );
    expect(total, lessThan(_indexBudgetMs));
  });

  test('re-parsing after a keystroke, p95 under $_keystrokeP95Ms ms', () {
    final parser = Parser(index, sqliteUsdaFoods(db));
    final snapshot = UserSnapshot.from(_plausibleData());
    for (var pass = 0; pass < 3; pass++) {
      for (var n = 1; n <= _brief.length; n++) {
        parser.parseMeal(_brief.substring(0, n), n, snapshot);
      }
    }
    final times = <double>[];
    for (var pass = 0; pass < 10; pass++) {
      for (var n = 1; n <= _brief.length; n++) {
        final sw = Stopwatch()..start();
        parser.parseMeal(_brief.substring(0, n), n, snapshot);
        times.add(sw.elapsedMicroseconds / 1000);
      }
    }
    times.sort();
    final p95 = _percentile(times, 0.95);
    print(
      'keystroke: ${times.length} parses, median '
      '${_percentile(times, 0.5).toStringAsFixed(2)} ms, p95 '
      '${p95.toStringAsFixed(2)} ms, max ${times.last.toStringAsFixed(2)} ms '
      '(budget $_keystrokeP95Ms ms)',
    );
    expect(p95, lessThan(_keystrokeP95Ms));
  });

  test('a parse of 10 items takes under $_tenItemsMs ms', () {
    final parser = Parser(index, sqliteUsdaFoods(db));
    final snapshot = UserSnapshot.from(_plausibleData());
    expect(parser.parseMeal(_tenItems, _tenItems.length, snapshot).length, 10);
    for (var i = 0; i < 5; i++) {
      parser.parseMeal(_tenItems, -1, snapshot);
    }
    final times = <double>[];
    for (var i = 0; i < 30; i++) {
      final sw = Stopwatch()..start();
      parser.parseMeal(_tenItems, -1, snapshot);
      times.add(sw.elapsedMicroseconds / 1000);
    }
    times.sort();
    final p95 = _percentile(times, 0.95);
    print(
      '10 items: median ${_percentile(times, 0.5).toStringAsFixed(2)} ms, '
      'p95 ${p95.toStringAsFixed(2)} ms, max ${times.last.toStringAsFixed(2)} ms '
      '(budget $_tenItemsMs ms)',
    );
    expect(p95, lessThan(_tenItemsMs));
  });

  test('preparing the user snapshot (not a budget, for the record)', () {
    final data = _plausibleData();
    UserSnapshot.from(data);
    final sw = Stopwatch()..start();
    UserSnapshot.from(data);
    print('snapshot prepare: ${sw.elapsedMilliseconds} ms');
  });
}
