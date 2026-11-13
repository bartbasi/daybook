// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/data/food_reference.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/parser/user_snapshot.dart';
import 'package:daybook/parser/user_snapshot_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'worked_examples.dart';

// Tests of the worked examples as data (docs/parser-grammar.md 11.1 and
// 11.2). They do not call the parser. They check that the data is complete,
// that it agrees with the bundled USDA database, and that the fixtures cover
// what the examples use.

/// Tolerances from grammar 11.1. Macros are printed to one decimal in the
/// grammar, so they get half of the last digit.
const _gramsTol = 0.05;
const _kcalTol = 0.5;
const _macroTol = 0.05;
const _eps = 1e-9;

/// Examples that expect no lines at all.
const _expectsNoLines = {63};

/// Weight units a typed amount converts with, in grams.
const _gramsPerWeightUnit = {'g': 1.0, 'oz': 28.349523125, 'lb': 453.59237};

/// Words a typed unit can have in the start of a food's portion label.
const _portionWords = {
  'cup': ['cup'],
  'tbsp': ['tablespoon', 'tbsp'],
  'tsp': ['teaspoon', 'tsp'],
  'slice': ['slice'],
  'can': ['can'],
  'fl oz': ['fl oz'],
};

late String _dir;
late FoodReference _ref;

Iterable<ExpectedLine> _allLines(WorkedExample e) sync* {
  for (final l in e.flatLines) {
    yield l;
  }
  for (final v in e.variants) {
    for (final l in v.lines) {
      yield l;
      yield* l.items ?? const [];
    }
  }
}

String _n(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

/// The problems of one line against the database.
void _checkLine(int number, int index, ExpectedLine l, List<String> problems) {
  final where = 'example $number line ${index + 1}';
  final ref = l.ref;
  if (ref == null || !ref.startsWith('usda:')) return;
  final id = int.tryParse(ref.substring(5));
  final food = id == null ? null : _ref.food(id);
  if (food == null) {
    problems.add('$where: $ref does not exist in the database');
    return;
  }

  // Name, compared exactly.
  if (l.name != null && l.name != food.description) {
    problems.add(
      '$where: name is "${l.name}" but the database has "${food.description}"',
    );
  }

  final energy = food.nutrients[Nutrients.energy];
  final grams = l.grams;
  if (grams != null) {
    void scaled(String label, double? expected, int nutrientId, double tol) {
      if (expected == null) return;
      final per100 = food.nutrients[nutrientId];
      if (per100 == null) {
        problems.add('$where: $ref has no $label value in the database');
        return;
      }
      final actual = per100 * grams / 100;
      if ((actual - expected).abs() > tol + _eps) {
        problems.add(
          '$where: $label is ${_n(expected)} but $per100 per 100 g '
          'x ${_n(grams)} g / 100 = ${actual.toStringAsFixed(3)} '
          '(tolerance ${_n(tol)})',
        );
      }
    }

    if (l.kcal != null && energy == null) {
      problems.add('$where: $ref has no energy in the database');
    } else {
      scaled('kcal', l.kcal, Nutrients.energy, _kcalTol);
    }
    scaled('protein', l.protein, Nutrients.protein, _macroTol);
    scaled('carbs', l.carbs, Nutrients.carbs, _macroTol);
    scaled('fat', l.fat, Nutrients.fat, _macroTol);
  }

  // "(default)": the "Quantity not specified" portion.
  if (l.defaultSource == DefaultSource.notSpecified) {
    final dg = l.defaultGrams;
    final qns = food.portions.where((p) => p.label == defaultPortionLabel);
    if (dg == null) {
      problems.add('$where: marked (default) but no default grams in the data');
    } else if (qns.isEmpty) {
      problems.add(
        '$where: marked (default) but $ref has no "$defaultPortionLabel" '
        'portion (its portions: ${food.portions.map((p) => '"${p.label}" ${_n(p.grams)} g').join(', ')})',
      );
    } else if (!qns.any((p) => (p.grams - dg).abs() <= _gramsTol + _eps)) {
      problems.add(
        '$where: default is ${_n(dg)} g but "$defaultPortionLabel" is '
        '${qns.map((p) => _n(p.grams)).join(', ')} g',
      );
    }
    // The line's grams follow from the default and the quantity.
    if (dg != null && grams != null) {
      final times = (l.unit == 'g' || l.quantity == null) ? 1.0 : l.quantity!;
      if ((dg * times - grams).abs() > _gramsTol + _eps) {
        problems.add(
          '$where: default ${_n(dg)} g x ${_n(times)} = ${_n(dg * times)} g '
          'but the line says ${_n(grams)} g',
        );
      }
    }
  }

  // A portion the example names.
  final portion = l.portion;
  if (portion != null) {
    final label = portion.label;
    final pg = portion.grams;
    if (label != null) {
      final found = food.portions.where((p) => p.label == label).toList();
      if (found.isEmpty) {
        problems.add(
          '$where: portion "$label" is not a portion of $ref (its portions: '
          '${food.portions.map((p) => '"${p.label}" ${_n(p.grams)} g').join(', ')})',
        );
      } else if (pg != null &&
          !found.any((p) => (p.grams - pg).abs() <= _gramsTol + _eps)) {
        problems.add(
          '$where: portion "$label" is ${_n(pg)} g but the database has '
          '${found.map((p) => _n(p.grams)).join(', ')} g',
        );
      }
    } else if (pg != null &&
        !food.portions.any((p) => (p.grams - pg).abs() <= _gramsTol + _eps)) {
      problems.add('$where: no portion of $ref weighs ${_n(pg)} g');
    }
    final q = l.quantity;
    if (!portion.converted && pg != null && q != null && grams != null) {
      if ((q * pg - grams).abs() > _gramsTol + _eps) {
        problems.add(
          '$where: ${_n(q)} x ${_n(pg)} g = ${_n(q * pg)} g but the line '
          'says ${_n(grams)} g',
        );
      }
    }
  }

  // A typed unit that is one of the food's own portions, or a weight unit.
  final unit = l.unit;
  final q = l.quantity;
  if (unit != null && q != null && grams != null) {
    final factor = _gramsPerWeightUnit[unit];
    if (factor != null) {
      if ((q * factor - grams).abs() > _gramsTol + _eps) {
        problems.add(
          '$where: ${_n(q)} $unit = ${(q * factor).toStringAsFixed(3)} g '
          'but the line says ${_n(grams)} g',
        );
      }
    } else if (l.defaultSource == null &&
        !(l.portion?.converted ?? false) &&
        _portionWords.containsKey(unit)) {
      final words = _portionWords[unit]!;
      final matching = food.portions.where((p) {
        final label = p.label.toLowerCase();
        // "1 cup", "1 cup, cooked", "1 medium or regular slice".
        return words.any(
          (w) => RegExp('^1 (?:.* )?$w(?:[ ,(]|\$)').hasMatch(label),
        );
      }).toList();
      if (matching.isNotEmpty &&
          !matching.any(
            (p) => (q * p.grams - grams).abs() <= _gramsTol + _eps,
          )) {
        problems.add(
          '$where: typed unit "$unit" matches portions '
          '${matching.map((p) => '"${p.label}" ${_n(p.grams)} g').join(', ')} '
          'but ${_n(q)} x that is not ${_n(grams)} g',
        );
      }
    }
  }
}

void main() {
  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('daybook_examples');
    addTearDown(() => dir.deleteSync(recursive: true));
    _dir = '${dir.path}/usda.sqlite';
    File(_dir).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    _ref = FoodReference.open(_dir);
    addTearDown(_ref.close);
  });

  group('the data is complete', () {
    test('there are exactly 88 examples, numbered 1 to 88 in order', () {
      expect(workedExamples, hasLength(88));
      expect(workedExamples.map((e) => e.number).toList(), [
        for (var i = 1; i <= 88; i++) i,
      ]);
    });

    test('every example has an input and expected lines', () {
      final problems = <String>[];
      for (final e in workedExamples) {
        if (e.input.trim().isEmpty) {
          problems.add('example ${e.number}: empty input');
        }
        if (e.lines.isEmpty && !_expectsNoLines.contains(e.number)) {
          problems.add('example ${e.number}: no expected lines');
        }
        if (e.lines.isNotEmpty && _expectsNoLines.contains(e.number)) {
          problems.add('example ${e.number}: should expect no lines');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('state, markers and ref are consistent on every line', () {
      final problems = <String>[];
      for (final e in workedExamples) {
        var i = 0;
        for (final l in _allLines(e)) {
          i++;
          final w = 'example ${e.number} line $i';
          switch (l.state) {
            case ExpectedState.matched:
              if (l.markers.isNotEmpty) problems.add('$w: matched has markers');
              if (l.ref == null) problems.add('$w: matched has no ref');
            case ExpectedState.guess:
              if (!l.markers.contains(ExpectedMarker.guess)) {
                problems.add('$w: guess without the Guess marker');
              }
              if (l.ref == null) problems.add('$w: guess has no ref');
            case ExpectedState.amountAssumed:
              if (!l.markers.contains(ExpectedMarker.assumed) ||
                  l.markers.length != 1) {
                problems.add(
                  '$w: amount assumed needs the Assumed marker only',
                );
              }
              if (l.ref == null) problems.add('$w: amount assumed has no ref');
            case ExpectedState.notFound:
              if (l.ref != null) problems.add('$w: not found has a ref');
              if (l.text == null) problems.add('$w: not found has no text');
            case ExpectedState.aliasOrSavedMeal:
              if (l.savedMeal == null) problems.add('$w: header has no name');
          }
          final r = l.ref;
          if (r != null && !RegExp(r'^(usda|local):\d+$').hasMatch(r)) {
            problems.add('$w: ref "$r" is not usda:<id> or local:<id>');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('against the real database', () {
    for (final e in workedExamples) {
      test('example ${e.number} agrees with the database', () {
        final problems = <String>[];
        var i = 0;
        for (final l in e.flatLines) {
          _checkLine(e.number, i++, l, problems);
        }
        for (final v in e.variants) {
          var j = 0;
          for (final l in v.lines) {
            _checkLine(e.number, j++, l, problems);
          }
        }
        // The meal total is the sum of its lines.
        final total = e.mealKcal;
        if (total != null) {
          final parts = e.flatLines.map((l) => l.kcal);
          if (parts.every((k) => k != null)) {
            final sum = parts.fold<double>(0, (a, k) => a + k!);
            if ((sum - total).abs() > _kcalTol + _eps) {
              problems.add(
                'example ${e.number}: meal total ${_n(total)} but the lines '
                'add to ${_n(sum)}',
              );
            }
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    test('the fixtures agree with the database', () {
      final problems = <String>[];
      for (final m in savedMealFixtures) {
        for (final it in m.items) {
          final id = int.parse(it.ref.substring(5));
          final food = _ref.food(id);
          if (food == null) {
            problems.add('fixture ${m.name}: ${it.ref} does not exist');
            continue;
          }
          if (it.name != null && it.name != food.description) {
            problems.add(
              'fixture ${m.name}: name "${it.name}" but the database has '
              '"${food.description}"',
            );
          }
          final per100 = food.nutrients[Nutrients.energy]!;
          final kcal = per100 * it.grams / 100;
          if ((kcal - it.kcal).abs() > _kcalTol + _eps) {
            problems.add(
              'fixture ${m.name} ${it.ref}: ${_n(it.kcal)} kcal but '
              '$per100 per 100 g x ${_n(it.grams)} g / 100 = '
              '${kcal.toStringAsFixed(3)}',
            );
          }
        }
      }
      for (final r in [learnedToastNoAmount, learnedToastTwoSlices]) {
        if (_ref.food(int.parse(r.ref.substring(5))) == null) {
          problems.add('learned row ${r.phrase}: ${r.ref} does not exist');
        }
      }
      for (final e in workedExamples) {
        for (final r in e.setup.history.keys) {
          if (r.startsWith('usda:') &&
              _ref.food(int.parse(r.substring(5))) == null) {
            problems.add('example ${e.number} history: $r does not exist');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('the fixtures cover what the examples use', () {
    final meals = {for (final m in savedMealFixtures) m.name: m};
    final foods = {for (final f in userFoodFixtures) f.ref: f};

    test('every local ref is a user food fixture that is in place', () {
      final problems = <String>[];
      for (final e in workedExamples) {
        for (final r in e.setup.userFoods) {
          if (!foods.containsKey(r)) {
            problems.add('example ${e.number}: setup uses undefined $r');
          }
        }
        for (final l in _allLines(e)) {
          final r = l.ref;
          if (r == null || !r.startsWith('local:')) continue;
          if (!foods.containsKey(r)) {
            problems.add('example ${e.number}: $r is not defined');
          } else if (!e.setup.userFoods.contains(r)) {
            problems.add('example ${e.number}: $r is not in its setup');
          }
          final f = foods[r];
          if (f != null &&
              l.name != null &&
              l.name != f.name &&
              l.kcal != null) {
            problems.add(
              'example ${e.number}: name "${l.name}" but fixture $r is '
              '"${f.name}"',
            );
          }
          if (f?.kcalPerServing != null &&
              l.quantity != null &&
              l.kcal != null &&
              (l.quantity! * f!.kcalPerServing! - l.kcal!).abs() > _kcalTol) {
            problems.add(
              'example ${e.number}: ${_n(l.quantity!)} x '
              '${_n(f.kcalPerServing!)} kcal is not ${_n(l.kcal!)}',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('every saved meal and alias an example uses is defined', () {
      final problems = <String>[];
      for (final e in workedExamples) {
        for (final n in e.setup.savedMeals) {
          if (!meals.containsKey(n)) {
            problems.add('example ${e.number}: setup uses undefined "$n"');
          }
        }
        for (final l in e.lines) {
          final n = l.savedMeal;
          if (n == null) continue;
          final m = meals[n];
          if (m == null) {
            problems.add('example ${e.number}: saved meal "$n" is not defined');
            continue;
          }
          if (!e.setup.savedMeals.contains(n)) {
            problems.add('example ${e.number}: "$n" is not in its setup');
          }
          // The typed text names the meal or its alias.
          final typed = e.input.toLowerCase();
          final names = [m.name.toLowerCase(), ?m.alias];
          if (!names.any(typed.contains)) {
            problems.add(
              'example ${e.number}: the input does not contain "$n" or its '
              'alias',
            );
          }
          // The expansion matches the fixture, times the multiplier.
          final mult = l.multiplier ?? 1;
          final items = l.items;
          if (m.items.isNotEmpty && items != null) {
            if (items.length != m.items.length) {
              problems.add(
                'example ${e.number}: ${items.length} item lines but the '
                'fixture has ${m.items.length}',
              );
            } else {
              var sum = 0.0;
              for (var k = 0; k < items.length; k++) {
                final it = items[k];
                final f = m.items[k];
                final w = 'example ${e.number} item ${k + 1}';
                sum += f.kcal;
                if (it.ref != f.ref) {
                  problems.add(
                    '$w: ref ${it.ref} but the fixture has ${f.ref}',
                  );
                }
                if (it.quantity != null &&
                    (it.quantity! - f.quantity * mult).abs() > _eps) {
                  problems.add(
                    '$w: quantity ${_n(it.quantity!)} but fixture '
                    '${_n(f.quantity)} x ${_n(mult)}',
                  );
                }
                if (it.grams != null &&
                    (it.grams! - f.grams * mult).abs() > _gramsTol + _eps) {
                  problems.add(
                    '$w: ${_n(it.grams!)} g but fixture ${_n(f.grams)} g '
                    'x ${_n(mult)}',
                  );
                }
                if (it.kcal != null &&
                    (it.kcal! - f.kcal * mult).abs() > _kcalTol + _eps) {
                  problems.add(
                    '$w: ${_n(it.kcal!)} kcal but fixture ${f.kcal} kcal '
                    'x ${_n(mult)}',
                  );
                }
              }
              if (l.kcal != null &&
                  (l.kcal! - sum * mult).abs() > _kcalTol + _eps) {
                problems.add(
                  'example ${e.number}: header ${_n(l.kcal!)} kcal but the '
                  'fixture items add to ${sum.toStringAsFixed(1)} x ${_n(mult)}',
                );
              }
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('learned rows and history point at foods the example can see', () {
      final problems = <String>[];
      for (final e in workedExamples) {
        for (final r in e.setup.learned) {
          if (!identical(r, learnedToastNoAmount) &&
              !identical(r, learnedToastTwoSlices)) {
            problems.add('example ${e.number}: learned row is not a fixture');
          }
        }
        if (e.setup.cursorAtEnd && e.number != 62) {
          problems.add('example ${e.number}: unexpected cursor setup');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  // The parser run (the groups above do not call the parser).
  //
  // Pass rule (grammar 11.1), for each example, with its setup installed
  // (saved meals, aliases, user foods, learned rows, history, cursor):
  //   - the number of lines is the same (a saved meal header is one line and
  //     its item lines follow it; WorkedExample.flatLines lists them in
  //     screen order);
  //   - each line has the same state and the same food ref;
  //   - grams are within 0.05;
  //   - kcal is within 0.5, computed as energy (1008) per 100 g x grams / 100.
  // Examples with alternateInputs (63) must give the same result for each
  // input. Examples with variants (74) are run again with the variant's
  // setup. Every failure message names the example number and what differs.
  // Run on the real database. A saved meal header whose example lists no
  // items is compared alone and its items are not counted. Markers are
  // compared too, and `plain` (example 62, cursor at the end; every other
  // example has the cursor outside the text).
  group('the parser gives the expected lines', () {
    late Database db;
    late Parser parser;

    setUpAll(() {
      db = sqlite3.open(_dir, mode: OpenMode.readOnly);
      parser = Parser(
        SearchIndex.build(readUsdaFoods(db)),
        sqliteUsdaFoods(db),
      );
    });
    tearDownAll(() => db.close());

    UserSnapshot snapshotOf(ExampleSetup setup) {
      var id = 0;
      final meals = <SavedMealData>[];
      final aliases = <AliasData>[];
      for (final m in savedMealFixtures) {
        if (!setup.savedMeals.contains(m.name)) continue;
        id++;
        meals.add(
          SavedMealData(
            id: id,
            name: m.name,
            items: [
              for (final it in m.items)
                SavedMealItemData(
                  foodRef: it.ref,
                  foodName: it.name ?? 'food',
                  quantity: it.quantity,
                  unitLabel: it.unit ?? '',
                  baseQuantity: it.grams,
                  baseUnit: 'g',
                  nutrients: {
                    for (final e
                        in _ref
                            .food(int.parse(it.ref.substring(5)))!
                            .nutrients
                            .entries)
                      e.key: e.value * it.grams / 100,
                  },
                ),
            ],
          ),
        );
        if (m.alias != null) aliases.add(AliasData(m.alias!, id));
      }
      return UserSnapshot.from(
        UserSnapshotData(
          foods: [
            if (setup.userFoods.contains('local:1'))
              const UserFoodData(
                ref: 'local:1',
                name: 'Turkey chili',
                kind: 'recipe',
                baseUnit: 'serving',
                baseAmount: 1,
                nutrients: {1008: 420},
              ),
            if (setup.userFoods.contains('local:2'))
              const UserFoodData(
                ref: 'local:2',
                name: 'Peanut butter cookies',
                kind: 'custom',
                baseUnit: 'g',
                baseAmount: 100,
                portions: [PortionData('1 cookie', 20)],
                nutrients: {1008: 450},
              ),
          ],
          learned: [
            for (final l in setup.learned)
              LearnedMatchData(
                key: l.phrase,
                foodRef: l.ref,
                foodName: 'learned',
                quantity: l.quantity,
                unitLabel: l.unit,
              ),
          ],
          aliases: aliases,
          savedMeals: meals,
          historyCounts: setup.history,
        ),
      );
    }

    Set<ExpectedMarker> markersOf(Line l) => {
      for (final m in l.markers)
        switch (m) {
          Marker.guess => ExpectedMarker.guess,
          Marker.assumed => ExpectedMarker.assumed,
          Marker.yourPick => ExpectedMarker.yourPick,
          Marker.scanned => ExpectedMarker.scanned,
        },
    };

    void check(
      int number,
      String input,
      ExampleSetup setup,
      List<ExpectedLine> expected,
      int cursor,
    ) {
      final lines = parser.parseMeal(input, cursor, snapshotOf(setup));
      final flatExpected = [
        for (final l in expected) ...[l, ...?l.items],
      ];
      final flat = <Line>[];
      for (var i = 0; i < lines.length; i++) {
        flat.add(lines[i]);
        final headerOnly =
            i < expected.length &&
            expected[i].state == ExpectedState.aliasOrSavedMeal &&
            expected[i].items == null;
        if (!headerOnly) flat.addAll(lines[i].items);
      }
      final problems = <String>[];
      if (flat.length != flatExpected.length) {
        problems.add(
          'expected ${flatExpected.length} lines but got ${flat.length}',
        );
      }
      for (var i = 0; i < flat.length && i < flatExpected.length; i++) {
        final a = flat[i];
        final e = flatExpected[i];
        final w = 'line ${i + 1}';
        final state = ExpectedState.values[a.state.index];
        if (state != e.state) {
          problems.add('$w: state $state but expected ${e.state}');
        }
        if (e.state == ExpectedState.aliasOrSavedMeal) {
          if (a.foodName != e.savedMeal) {
            problems.add('$w: header "${a.foodName}" not "${e.savedMeal}"');
          }
          if (e.multiplier != null &&
              (a.multiplier == null ||
                  (a.multiplier! - e.multiplier!).abs() > _eps)) {
            problems.add('$w: multiplier ${a.multiplier} not ${e.multiplier}');
          }
        } else {
          if (a.foodRef != e.ref) {
            problems.add('$w: ref ${a.foodRef} but expected ${e.ref}');
          }
          final plain = a.plain;
          if (plain != e.plain) {
            problems.add('$w: plain $plain but expected ${e.plain}');
          }
          final got = markersOf(a);
          if (got.length != e.markers.length || !got.containsAll(e.markers)) {
            problems.add(
              '$w: markers ${markersOf(a)} but expected ${e.markers}',
            );
          }
        }
        final local = e.ref != null && e.ref!.startsWith('local:');
        if (e.grams != null && !local) {
          final g = a.baseQuantity;
          if (g == null || (g - e.grams!).abs() > _gramsTol) {
            problems.add('$w: grams $g but expected ${e.grams}');
          }
        }
        if (e.kcal != null) {
          final k = a.nutrients[Nutrients.energy];
          if (k == null || (k - e.kcal!).abs() > _kcalTol) {
            problems.add('$w: kcal $k but expected ${e.kcal}');
          }
        }
      }
      final got = [for (final l in flat) '${l.state.name} ${l.foodRef}'];
      expect(
        problems,
        isEmpty,
        reason: 'example $number ("$input")\n${problems.join('\n')}\n$got',
      );
    }

    for (final e in workedExamples) {
      test('example ${e.number}', () {
        int cursorFor(String s) => e.setup.cursorAtEnd ? s.length : -1;
        check(e.number, e.input, e.setup, e.lines, cursorFor(e.input));
        for (final alt in e.alternateInputs) {
          check(e.number, alt, e.setup, e.lines, cursorFor(alt));
        }
        for (final v in e.variants) {
          check(e.number, e.input, v.setup, v.lines, cursorFor(e.input));
        }
      });
    }
  });
}
