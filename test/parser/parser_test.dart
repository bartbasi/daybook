// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/parser/grams.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/parser/user_snapshot.dart';
import 'package:daybook/parser/user_snapshot_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Aliases, saved meals, learned matches, line states and determinism (grammar
// 6, 7.3, 8.1, 9.2), on a small made-up food list so every case is exact. The
// 88 worked examples run on the real database in worked_examples_test.dart.
//
// The spoken labels of 8.2 ("Guess. Cream, half and half. ...") are not made
// by the parser. It gives the state and the markers; the screen builds the
// words from lib/strings.dart.

const _qns = 'Quantity not specified';

class _F {
  const _F(this.id, this.description, this.kcal, this.portions);
  final int id;
  final String description;
  final double kcal;
  final List<(String, double)> portions;
  String get ref => 'usda:$id';
}

const _foods = [
  _F(1, 'Egg, whole, cooked, NS as to cooking method', 150, [
    ('1 egg', 50),
    (_qns, 50),
  ]),
  _F(2, 'Bread, rye, toasted', 270, [('1 slice', 29), (_qns, 29)]),
  _F(3, 'Bread, white, toasted', 270, [('1 slice', 30), (_qns, 30)]),
  _F(4, 'Coffee, NS as to type', 1, [(_qns, 360)]),
  _F(5, 'Oatmeal, NFS', 70, [('1 cup, cooked', 240), (_qns, 240)]),
  _F(6, 'Cheese, NFS', 400, [(_qns, 28)]),
  _F(7, 'Cheese, NS as to type', 200, [(_qns, 28)]),
  _F(8, 'Honey', 300, [('1 tablespoon', 20)]),
];

final _usdaIndex = SearchIndex.build([
  for (final f in _foods)
    IndexFood(
      ref: f.ref,
      description: f.description,
      dataset: 'fndds',
      energy: f.kcal,
    ),
]);

final _parser = Parser(_usdaIndex, (ref) {
  for (final f in _foods) {
    if (f.ref == ref) {
      return PortionFood.usda(portions: f.portions, nutrients: {1008: f.kcal});
    }
  }
  return null;
});

SavedMealItemData _item(int food, double quantity, String unit, double grams) {
  final f = _foods.firstWhere((x) => x.id == food);
  return SavedMealItemData(
    foodRef: f.ref,
    foodName: f.description,
    quantity: quantity,
    unitLabel: unit,
    baseQuantity: grams,
    baseUnit: 'g',
    nutrients: {1008: f.kcal * grams / 100},
  );
}

SavedMealData _meal(int id, String name, [List<SavedMealItemData>? items]) =>
    SavedMealData(
      id: id,
      name: name,
      items: items ?? [_item(1, 2, '', 100), _item(2, 1, 'slice', 29)],
    );

List<Line> _parse(
  String text, {
  UserSnapshotData data = const UserSnapshotData(),
  int cursor = -1,
}) => _parser.parseMeal(text, cursor, UserSnapshot.from(data));

Line _one(String text, {UserSnapshotData data = const UserSnapshotData()}) {
  final lines = _parse(text, data: data);
  expect(lines, hasLength(1), reason: text);
  return lines.single;
}

void main() {
  group('line states (8.1): every combination and its markers', () {
    test('matched: a typed amount that converts, no marker', () {
      final l = _one('2 eggs');
      expect(l.state, LineState.matched);
      expect(l.markers, isEmpty);
      expect(l.foodRef, 'usda:1');
      expect(l.baseQuantity, 100);
      expect(l.nutrients[1008], 150 * 100 / 100);
    });

    test('amount assumed: no amount typed', () {
      final l = _one('oatmeal');
      expect(l.state, LineState.amountAssumed);
      expect(l.markers, {Marker.assumed});
      expect(l.baseQuantity, 240);
    });

    test('amount assumed: a unit the food cannot convert', () {
      final l = _one('2 cups honey');
      expect(l.foodRef, 'usda:8');
      // Honey has only a tablespoon portion, so cups convert through ml.
      expect(l.state, LineState.matched);
      final c = _one('2 slices honey');
      expect(c.state, LineState.amountAssumed);
      expect(c.markers, {Marker.assumed});
    });

    test('amount assumed: a range', () {
      final l = _one('2-3 eggs');
      expect(l.state, LineState.amountAssumed);
      expect(l.markers, {Marker.assumed});
      expect(l.quantity, 2.5);
    });

    test('guess: a typo corrected, with a typed amount', () {
      final l = _one('2 eggz');
      expect(l.state, LineState.guess);
      expect(l.markers, {Marker.guess});
      expect(l.foodRef, 'usda:1');
    });

    test('guess and assumed together: the state is guess', () {
      final l = _one('eggz');
      expect(l.state, LineState.guess);
      expect(l.markers, {Marker.guess, Marker.assumed});
    });

    test('guess: equal matches that differ in calories', () {
      final l = _one('2 oz cheese');
      expect(l.state, LineState.guess);
      expect(l.markers, {Marker.guess});
    });

    test('not found: no candidate, and an amount with no food', () {
      final a = _one('zzzzqq');
      expect(a.state, LineState.notFound);
      expect(a.markers, isEmpty);
      expect(a.foodRef, isNull);
      expect(a.nutrients, isEmpty);
      final b = _one('200 g');
      expect(b.state, LineState.notFound);
    });

    test('alias or saved meal: header with its items', () {
      final l = _one(
        'usual',
        data: UserSnapshotData(savedMeals: [_meal(1, 'Usual')]),
      );
      expect(l.state, LineState.aliasOrSavedMeal);
      expect(l.foodRef, isNull);
      expect(l.items, hasLength(2));
      expect(l.items.every((i) => i.state == LineState.matched), isTrue);
    });

    test('the parser never sets Your pick or Scanned', () {
      for (final t in ['2 eggs', 'eggz', 'oatmeal', 'zzzzqq', '2-3 eggs']) {
        for (final l in _parse(t)) {
          expect(l.markers.contains(Marker.yourPick), isFalse);
          expect(l.markers.contains(Marker.scanned), isFalse);
        }
      }
    });
  });

  group('aliases and saved meals (6)', () {
    UserSnapshotData data({
      List<SavedMealData>? meals,
      List<AliasData>? aliases,
      List<UserFoodData> foods = const [],
    }) => UserSnapshotData(
      savedMeals: meals ?? [_meal(1, 'Usual breakfast')],
      aliases: aliases ?? const [],
      foods: foods,
    );

    test('the name matches exactly after normalizing (6.1)', () {
      final d = data();
      expect(
        _one('Usual   Breakfast', data: d).state,
        LineState.aliasOrSavedMeal,
      );
      expect(
        _one('I had usual breakfast', data: d).state,
        LineState.aliasOrSavedMeal,
      );
      expect(
        _one('usual breakfasts', data: d).state,
        isNot(LineState.aliasOrSavedMeal),
      );
    });

    test('an alias works with a leading "my" kept (2.3, 6.1)', () {
      final d = data(
        meals: [_meal(1, 'Morning oats')],
        aliases: const [AliasData('my oatmeal', 1)],
      );
      final l = _one('I had my oatmeal', data: d);
      expect(l.state, LineState.aliasOrSavedMeal);
      expect(l.foodName, 'Morning oats');
      expect(l.savedMealId, 1);
    });

    test('an alias beats a saved meal name', () {
      final both = data(
        meals: [_meal(1, 'Plan A'), _meal(2, 'Lunch')],
        aliases: const [AliasData('lunch', 1)],
      );
      expect(_one('lunch', data: both).foodName, 'Plan A');
    });

    test('the newest saved meal wins a name tie', () {
      final d = data(
        meals: [
          _meal(3, 'Usual breakfast', [_item(4, 1, '', 360)]),
          _meal(7, 'usual  BREAKFAST', [_item(5, 1, 'cup', 240)]),
          _meal(5, 'Usual breakfast', [_item(8, 1, 'tbsp', 20)]),
        ],
      );
      final l = _one('usual breakfast', data: d);
      expect(l.savedMealId, 7);
      expect(l.items.single.foodRef, 'usda:5');
    });

    test('a saved meal beats an exact food name (6.3)', () {
      final d = data(meals: [_meal(1, 'Oatmeal')]);
      expect(_one('oatmeal', data: d).state, LineState.aliasOrSavedMeal);
    });

    test('a food with a similar name does not take the alias', () {
      final d = data(
        aliases: const [AliasData('usual breakfast', 1)],
        foods: const [
          UserFoodData(
            ref: 'local:1',
            name: 'Usual breakfast burrito',
            kind: 'custom',
            baseUnit: 'g',
            baseAmount: 100,
            nutrients: {1008: 200},
          ),
        ],
      );
      expect(
        _one('usual breakfast', data: d).state,
        LineState.aliasOrSavedMeal,
      );
      final burrito = _one('usual breakfast burrito', data: d);
      expect(burrito.foodRef, 'local:1');
      expect(burrito.state, isNot(LineState.aliasOrSavedMeal));
    });

    test('a food with exactly the alias name loses to the alias', () {
      final d = data(
        aliases: const [AliasData('usual breakfast', 1)],
        foods: const [
          UserFoodData(
            ref: 'local:1',
            name: 'Usual breakfast',
            kind: 'custom',
            baseUnit: 'g',
            baseAmount: 100,
            nutrients: {1008: 200},
          ),
        ],
      );
      expect(
        _one('usual breakfast', data: d).state,
        LineState.aliasOrSavedMeal,
      );
    });

    test('a plain quantity multiplies every item (6.2)', () {
      final d = data();
      final l = _one('half usual breakfast', data: d);
      expect(l.multiplier, 0.5);
      // The item lines are already multiplied, as expandSavedMeal returns them.
      expect(l.items[0].quantity, 1);
      expect(l.items[0].baseQuantity, 50);
      expect(l.items[0].nutrients[1008], 75);
      expect(l.items[1].quantity, 0.5);
      expect(l.items[1].baseQuantity, 14.5);
      // The header holds the subtotal and is not itself a food.
      expect(l.nutrients[1008], 75 + 270 * 14.5 / 100);
      expect(l.foodRef, isNull);
    });

    test('2 times, a multiplier, a range and "serving" (6.2)', () {
      final d = data();
      expect(_one('2 usual breakfast', data: d).multiplier, 2);
      expect(_one('usual breakfast x3', data: d).multiplier, 3);
      expect(_one('2x usual breakfast', data: d).multiplier, 2);
      expect(_one('1 serving usual breakfast', data: d).multiplier, 1);
      expect(_one('2 portions usual breakfast', data: d).multiplier, 2);
      final r = _one('2-3 usual breakfast', data: d);
      expect(r.multiplier, 2.5);
      expect(r.markers, {Marker.assumed});
      expect(_one('usual breakfast', data: d).markers, isEmpty);
    });

    test('any other unit means it is food text (6.2)', () {
      final d = data();
      expect(
        _one('2 cups usual breakfast', data: d).state,
        isNot(LineState.aliasOrSavedMeal),
      );
      expect(
        _one('2 large usual breakfast', data: d).state,
        isNot(LineState.aliasOrSavedMeal),
      );
      expect(
        _one('large usual breakfast', data: d).state,
        isNot(LineState.aliasOrSavedMeal),
      );
    });

    test('a header counts as one line and its items sit under it', () {
      final lines = _parse('usual breakfast, coffee', data: data());
      expect(lines, hasLength(2));
      expect(lines[0].items, hasLength(2));
      expect(lines[1].foodRef, 'usda:4');
    });

    test('an alias to a saved meal that is gone is ignored', () {
      final d = data(
        meals: [_meal(1, 'Other')],
        aliases: const [AliasData('lunch', 9)],
      );
      expect(_one('lunch', data: d).state, LineState.notFound);
    });
  });

  group('learned matches (7.3)', () {
    UserSnapshotData data(List<LearnedMatchData> learned) =>
        UserSnapshotData(learned: learned);

    LearnedMatchData row({
      String key = 'toast',
      String ref = 'usda:3',
      double? quantity,
      String? unit,
    }) => LearnedMatchData(
      key: key,
      foodRef: ref,
      foodName: 'Bread, white, toasted',
      quantity: quantity,
      unitLabel: unit,
    );

    test('without a learned row ranking decides', () {
      expect(_one('toast').foodRef, 'usda:2');
    });

    test('an exact key decides the food and the line is matched', () {
      final l = _one('2 slices toast', data: data([row()]));
      expect(l.foodRef, 'usda:3');
      expect(l.state, LineState.matched);
      expect(l.baseQuantity, 60);
      expect(l.learnedKey, 'toast');
    });

    test('the key ignores size, filler, plurals and word order', () {
      final d = data([row(key: 'sourdough toast')]);
      expect(_one('toast sourdough', data: d).foodRef, 'usda:3');
      expect(_one('2 slices of sourdough toasts', data: d).foodRef, 'usda:3');
      expect(_one('toast', data: d).foodRef, 'usda:2');
    });

    test('a learned row answers its exact key only', () {
      final d = data([row(key: 'coffee')]);
      final l = _one('coffee without sugar', data: d);
      expect(l.learnedKey, 'coffee sugar without');
      expect(l.foodRef, 'usda:4');
    });

    test('a learned amount is the default when nothing is typed', () {
      final l = _one('toast', data: data([row(quantity: 2, unit: 'slice')]));
      expect(l.foodRef, 'usda:3');
      expect(l.state, LineState.amountAssumed);
      expect(l.markers, {Marker.assumed});
      expect(l.quantity, 2);
      expect(l.unitLabel, 'slice');
      expect(l.baseQuantity, 60);
    });

    test('a typed amount that converts beats the learned amount', () {
      final l = _one(
        '3 slices toast',
        data: data([row(quantity: 2, unit: 'slice')]),
      );
      expect(l.state, LineState.matched);
      expect(l.baseQuantity, 90);
    });

    test('a typed unit that cannot convert uses the learned amount', () {
      final l = _one(
        '5 cups toast',
        data: data([row(quantity: 2, unit: 'slice')]),
      );
      expect(l.state, LineState.amountAssumed);
      expect(l.baseQuantity, 60);
    });

    test('a learned food that no longer exists is ignored', () {
      final gone = _one('toast', data: data([row(ref: 'usda:999')]));
      expect(gone.foodRef, 'usda:2');
      final archived = _one('toast', data: data([row(ref: 'local:9')]));
      expect(archived.foodRef, 'usda:2');
      // Its amount is not used either.
      final noAmount = _one(
        'toast',
        data: data([row(ref: 'usda:999', quantity: 2, unit: 'slice')]),
      );
      expect(noAmount.baseQuantity, 29);
    });

    test('a learned row for one of the user\'s own foods', () {
      final d = UserSnapshotData(
        foods: const [
          UserFoodData(
            ref: 'local:4',
            name: 'Mum\'s loaf',
            kind: 'custom',
            baseUnit: 'g',
            baseAmount: 100,
            nutrients: {1008: 250},
          ),
        ],
        learned: [row(ref: 'local:4')],
      );
      final l = _one('2 slices toast', data: d);
      expect(l.foodRef, 'local:4');
      expect(l.foodName, 'Mum\'s loaf');
    });

    test('a saved meal beats a learned match (6.3)', () {
      final d = UserSnapshotData(
        learned: [row()],
        savedMeals: [_meal(1, 'Toast')],
      );
      expect(_one('toast', data: d).state, LineState.aliasOrSavedMeal);
    });
  });

  group('items with no line, and local food rules', () {
    test(
      'an item whose words are all cut by a negation gives no line (R36)',
      () {
        expect(_parse('coffee with no sugar'), hasLength(1));
        expect(_parse('coffee without sugar'), hasLength(1));
        expect(_parse('no sugar'), isEmpty);
        expect(_parse('coffee, no sugar, 2 eggs'), hasLength(2));
        // An ordinary unknown word is still not found.
        expect(_parse('coffee with zzzzqq').last.state, LineState.notFound);
      },
    );

    test('the negation cut does not apply inside a protected name (R39)', () {
      final d = UserSnapshotData(
        foods: const [
          UserFoodData(
            ref: 'local:1',
            name: 'No sugar cola',
            kind: 'custom',
            baseUnit: 'g',
            baseAmount: 100,
            nutrients: {1008: 5},
          ),
        ],
      );
      expect(_one('no sugar cola', data: d).foodRef, 'local:1');
      expect(_one('2 cans no sugar cola', data: d).foodRef, 'local:1');
      expect(
        _parse('coffee with no sugar cola', data: d).last.foodRef,
        'local:1',
      );
      // Without the food the cut still applies.
      expect(_parse('no sugar cola'), isEmpty);
      // The cut still applies outside the name.
      final w = _one('no sugar cola without ice', data: d);
      expect(w.foodRef, 'local:1');
      expect(w.state, LineState.amountAssumed);
      final x = _parse('2 cans no sugar cola with no ice', data: d);
      expect(x, hasLength(1));
      expect(x.single.foodRef, 'local:1');
      expect(_one('coffee without sugar', data: d).foodRef, 'usda:4');
      expect(_one('no sugar cola', data: d).foodRef, 'local:1');
    });

    test('an amount with only negated words is not found (R36, 8.1)', () {
      final l = _one('2 no sugar');
      expect(l.state, LineState.notFound);
      expect(l.span, const Span(0, 10));
      expect(_one('3 without milk').state, LineState.notFound);
      expect(_parse('coffee with no sugar'), hasLength(1));
      expect(_parse('no sugar'), isEmpty);
    });

    test('a scanned product is a protected name only once logged (R40)', () {
      UserSnapshotData data(Map<String, int> history) => UserSnapshotData(
        foods: const [
          UserFoodData(
            ref: 'local:1',
            name: 'Large eggs',
            kind: 'off',
            baseUnit: 'g',
            baseAmount: 100,
            portions: [PortionData('1 egg', 60)],
            nutrients: {1008: 150},
          ),
        ],
        historyCounts: history,
      );
      final never = _one('2 large eggs', data: data(const {}));
      expect(never.foodRef, 'usda:1');
      expect(never.baseQuantity, 100);
      final logged = _one('2 large eggs', data: data(const {'local:1': 1}));
      expect(logged.foodRef, 'local:1');
      // Custom foods are always protected.
      final custom = UserSnapshotData(
        foods: const [
          UserFoodData(
            ref: 'local:1',
            name: 'Large eggs',
            kind: 'custom',
            baseUnit: 'g',
            baseAmount: 100,
            nutrients: {1008: 150},
          ),
        ],
      );
      expect(_one('2 large eggs', data: custom).foodRef, 'local:1');
    });

    test('protected names are compared after accent folding (2.3)', () {
      final d = UserSnapshotData(
        foods: const [
          UserFoodData(
            ref: 'local:1',
            name: 'Café and croissant',
            kind: 'custom',
            baseUnit: 'g',
            baseAmount: 100,
            nutrients: {1008: 300},
          ),
        ],
      );
      for (final t in ['cafe and croissant', 'café and croissant']) {
        final lines = _parse(t, data: d);
        expect(lines, hasLength(1), reason: t);
        expect(lines.single.foodRef, 'local:1', reason: t);
      }
    });

    test('filler only and separators give no line', () {
      expect(_parse('I had'), isEmpty);
      expect(_parse('!!!'), isEmpty);
      expect(_parse(',,, and'), isEmpty);
    });

    test('a local food with a bad base amount is left out (R35)', () {
      UserFoodData food(String ref, double amount) => UserFoodData(
        ref: ref,
        name: 'Zorbo bar',
        kind: 'custom',
        baseUnit: 'g',
        baseAmount: amount,
        nutrients: const {1008: 100},
      );
      final d = UserSnapshotData(
        foods: [
          food('local:1', 0),
          food('local:2', -5),
          food('local:3', double.nan),
          food('local:4', double.infinity),
        ],
      );
      final s = UserSnapshot.from(d);
      expect(s.foods, isEmpty);
      expect(s.index, isNull);
      expect(_one('zorbo bar', data: d).state, LineState.notFound);
      // A good one is kept.
      final ok = UserSnapshot.from(
        UserSnapshotData(foods: [food('local:5', 1)]),
      );
      expect(ok.foods.keys, ['local:5']);
      expect(_parser.parseMeal('zorbo bar', -1, ok).single.foodRef, 'local:5');
    });
  });

  group('the cursor (9.2)', () {
    const text = '2 eggs, zzzz';

    Line last(int cursor) => _parse(text, cursor: cursor).last;

    test('the cursor at the start of the item does not count (9.2)', () {
      final l = _parse('zz, eggs', cursor: 0).first;
      expect(l.state, LineState.notFound);
      expect(l.plain, isFalse);
      expect(_parse('zz, eggs', cursor: 1).first.plain, isTrue);
    });

    test('a not found item with the cursor in it is plain', () {
      for (final c in [9, 10, 12]) {
        final l = last(c);
        expect(l.state, LineState.notFound);
        expect(l.plain, isTrue, reason: 'cursor $c');
      }
    });

    test('the cursor elsewhere leaves it not found', () {
      for (final c in [-1, 0, 3, 6, 7, 8]) {
        expect(last(c).plain, isFalse, reason: 'cursor $c');
      }
    });

    test('only a not found line is ever plain', () {
      for (final l in _parse('2 eggs, 2 slices', cursor: 4)) {
        expect(l.plain, isFalse);
      }
    });

    test('plain keeps the food words and the span', () {
      final l = last(12);
      expect(l.foodText, 'zzzz');
      expect(l.span, const Span(8, 12));
    });
  });

  group('what a typed line carries', () {
    test('span, amount spans, key and food words', () {
      final l = _one('2 slices rye toast');
      expect(l.span, const Span(0, 18));
      expect(l.amountSpans, [const Span(0, 8)]);
      expect(l.learnedKey, 'rye toast');
      expect(l.foodText, 'rye toast');
    });

    test('a header has no learned key', () {
      final l = _one(
        'usual',
        data: UserSnapshotData(savedMeals: [_meal(1, 'Usual')]),
      );
      expect(l.learnedKey, isNull);
    });

    test(
      'not found with food words keeps its key; an amount alone has none',
      () {
        expect(_one('zzzzqq').learnedKey, 'zzzzqq');
        expect(_one('200 g').learnedKey, isNull);
      },
    );
  });

  group('determinism and the prepared snapshot', () {
    String shape(List<Line> lines) => [
      for (final l in lines)
        '${l.state.name} ${l.foodRef} ${l.quantity} ${l.unitLabel} '
            '${l.baseQuantity} ${l.markers.map((m) => m.name).toList()..sort()} '
            '${l.nutrients[1008]} ${l.items.length} ${l.span}',
    ].join('\n');

    test('the same text and data give the same lines, every time', () {
      const text = '2 eggs, toast and coffee with 2 tbsp honey, cheese, zzz';
      final data = UserSnapshotData(
        savedMeals: [_meal(1, 'Usual')],
        historyCounts: const {'usda:7': 2},
      );
      final first = shape(_parse(text, data: data));
      for (var i = 0; i < 5; i++) {
        expect(shape(_parse(text, data: data)), first);
      }
    });

    test('history makes the logged cheese win the tie (5.4 key 4)', () {
      final l = _one(
        'cheese',
        data: const UserSnapshotData(historyCounts: {'usda:7': 3}),
      );
      expect(l.foodRef, 'usda:7');
      expect(l.state, LineState.amountAssumed);
    });

    test('the snapshot keeps its version and is immutable', () {
      final s = UserSnapshot.from(const UserSnapshotData(version: 12));
      expect(s.version, 12);
      expect(() => s.foods.clear(), throwsUnsupportedError);
      expect(() => s.learned.clear(), throwsUnsupportedError);
      expect(() => s.mealsByName.clear(), throwsUnsupportedError);
    });
  });

  group('sqliteUsdaFoods', () {
    test('a food with no portion and no nutrient row is missing', () {
      final db = sqlite3.openInMemory()
        ..execute('CREATE TABLE food (id INTEGER PRIMARY KEY)')
        ..execute(
          'CREATE TABLE food_nutrient '
          '(food_id INTEGER, nutrient_id INTEGER, amount REAL)',
        )
        ..execute(
          'CREATE TABLE food_portion '
          '(food_id INTEGER, seq INTEGER, label TEXT, gram_weight REAL)',
        )
        ..execute('INSERT INTO food VALUES (1)')
        ..execute('INSERT INTO food VALUES (2)')
        ..execute('INSERT INTO food_nutrient VALUES (2, 1008, 10)');
      final load = SqliteUsdaFoods(db);
      expect(load('usda:1'), isNull);
      expect(load('usda:2')!.nutrients, {1008: 10});
      expect(load('usda:2')!.portions.usable, isEmpty);
      load.dispose();
      db.close();
    });

    test('dispose releases the file so it can be deleted', () {
      final dir = Directory.systemTemp.createTempSync('daybook_loader');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/f.sqlite';
      final db = sqlite3.open(path)
        ..execute(
          'CREATE TABLE food_nutrient '
          '(food_id INTEGER, nutrient_id INTEGER, amount REAL)',
        )
        ..execute(
          'CREATE TABLE food_portion '
          '(food_id INTEGER, seq INTEGER, label TEXT, gram_weight REAL)',
        )
        ..execute('INSERT INTO food_nutrient VALUES (1, 1008, 10)');
      final load = SqliteUsdaFoods(db);
      expect(load('usda:1'), isNotNull);
      load.dispose();
      db.close();
      File(path).deleteSync();
      expect(File(path).existsSync(), isFalse);
    });

    late Database db;
    setUp(() {
      db = sqlite3.openInMemory()
        ..execute('CREATE TABLE food (id INTEGER PRIMARY KEY)')
        ..execute(
          'CREATE TABLE food_nutrient '
          '(food_id INTEGER, nutrient_id INTEGER, amount REAL)',
        )
        ..execute(
          'CREATE TABLE food_portion '
          '(food_id INTEGER, seq INTEGER, label TEXT, gram_weight REAL)',
        )
        ..execute('INSERT INTO food VALUES (1)')
        ..execute('INSERT INTO food_nutrient VALUES (1, 1008, 150)')
        ..execute("INSERT INTO food_portion VALUES (1, 2, '1 cup', 240)")
        ..execute("INSERT INTO food_portion VALUES (1, 1, '1 egg', 50)");
    });
    tearDown(() => db.close());

    test('reads nutrients and portions in order, null for a missing food', () {
      final load = sqliteUsdaFoods(db);
      final f = load('usda:1')!;
      expect(f.nutrients, {1008: 150});
      expect(f.portions.usable.map((p) => p.label), ['1 egg', '1 cup']);
      expect(load('usda:2'), isNull);
      expect(load('local:1'), isNull);
      expect(load('usda:x'), isNull);
    });
  });
}
