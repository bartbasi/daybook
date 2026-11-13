// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/data/off_client.dart';
import 'package:daybook/util/dates.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// A second look at food logging in the data layer, written from the data model
// and the public calls of food_data.dart and food_library_data.dart. It adds
// cases to test/data/food_data_test.dart and does not repeat its tests: a meal
// that spans every kind of food, the exact columns that are stored, edits and
// deletes with their effect on the nutrient rows, a food that changes after it
// was eaten, and the clock (midnight, a change of time zone, daylight saving).

const kcal = Nutrients.energy;
const protein = Nutrients.protein;
const carbs = Nutrients.carbs;
const fat = Nutrients.fat;

/// Local time on a local date, at an offset in minutes from UTC.
Now local(String date, int hour, int minute, int offsetMinutes) =>
    Now.fromLocal(date, hour * 60 + minute, offsetMinutes);

MealLineInput line(
  String ref,
  String name, {
  double q = 1,
  String unit = '',
  double base = 100,
  String baseUnit = 'g',
  Map<int, double> n = const {kcal: 100},
}) => MealLineInput(
  foodRef: ref,
  foodName: name,
  quantity: q,
  unitLabel: unit,
  baseQuantity: base,
  baseUnit: baseUnit,
  nutrients: n,
);

void main() {
  late AppDatabase db;
  late int breakfast;
  late int lunch;
  late int dinner;
  late int snack;

  // Central time, UTC minus 6 in winter and minus 5 in summer.
  const cst = -360;
  const cdt = -300;
  final morning = local('2026-11-12', 7, 40, cst);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    Future<int> slot(String name) async => (await (db.select(
      db.mealSlots,
    )..where((s) => s.name.equals(name))).getSingle()).id;
    breakfast = await slot('Breakfast');
    lunch = await slot('Lunch');
    dinner = await slot('Dinner');
    snack = await slot('Snack');
  });
  tearDown(() => db.close());

  Future<StoredMeal> save(
    List<MealLineInput> lines, {
    String? date,
    int? slot,
    Now? now,
    String? text,
  }) {
    final when = now ?? morning;
    return db.saveMeal(
      now: when,
      localDate: date ?? when.localDate,
      slotId: slot ?? breakfast,
      lines: lines,
      sourceText: text,
    );
  }

  Future<List<MealEntryNutrient>> nutrientRows() =>
      db.select(db.mealEntryNutrients).get();
  Future<List<MealEntry>> entryRows() => db.select(db.mealEntries).get();
  Future<List<Meal>> mealRows() => db.select(db.meals).get();

  /// Every stored row of every table a meal touches, in a form that can be
  /// compared: table name to its rows as plain text, in id order.
  Future<Map<String, List<String>>> snapshot() async {
    final m = [...await mealRows()]..sort((a, b) => a.id.compareTo(b.id));
    final e = [...await entryRows()]..sort((a, b) => a.id.compareTo(b.id));
    final n = [...await nutrientRows()]
      ..sort(
        (a, b) => a.entryId != b.entryId
            ? a.entryId.compareTo(b.entryId)
            : a.nutrientId.compareTo(b.nutrientId),
      );
    return {
      'meals': [for (final r in m) r.toString()],
      'entries': [for (final r in e) r.toString()],
      'nutrients': [for (final r in n) r.toString()],
    };
  }

  group('what is stored', () {
    test(
      'every column of the meal and its entries is what was given',
      () async {
        final when = local('2026-11-12', 7, 40, cst);
        final m = await db.saveMeal(
          now: when,
          localDate: '2026-11-12',
          slotId: lunch,
          sourceText: '2 eggs, toast',
          lines: [
            line(
              'usda:2707153',
              'Egg, whole',
              q: 2,
              unit: 'egg',
              base: 100,
              n: {kcal: 143.5, protein: 12.5},
            ),
            line(
              'usda:1',
              'Toast',
              q: 1.5,
              unit: 'slice',
              base: 40.5,
              n: {kcal: 110},
            ),
          ],
        );
        expect(m.meal.localDate, '2026-11-12');
        expect(m.meal.slotId, lunch);
        expect(m.slotName, 'Lunch');
        expect(m.meal.loggedAtMs, when.utcMs);
        expect(m.meal.tzOffsetMinutes, cst);
        expect(m.meal.sourceText, '2 eggs, toast');
        expect(m.meal.savedMealId, isNull);
        final eggs = m.entries[0].entry;
        expect(eggs.mealId, m.meal.id);
        expect(eggs.position, 0);
        expect(eggs.foodRef, 'usda:2707153');
        expect(eggs.foodName, 'Egg, whole');
        expect(eggs.quantity, 2);
        expect(eggs.unitLabel, 'egg');
        expect(eggs.baseQuantity, 100);
        expect(eggs.baseUnit, 'g');
        expect(m.entries[0].nutrients, {kcal: 143.5, protein: 12.5});
        final toast = m.entries[1].entry;
        expect(toast.position, 1);
        expect(toast.quantity, 1.5);
        expect(toast.baseQuantity, 40.5);
        expect(m.entries[1].nutrients, {kcal: 110});
        // And the same from a fresh read of the tables.
        expect(await db.loadMeal(m.meal.id), isNotNull);
        final rows = await nutrientRows();
        expect(rows, hasLength(3));
      },
    );

    test('a nutrient a food does not have is not stored as zero', () async {
      final m = await save([
        line('a', 'A', n: {kcal: 50, protein: 0}),
        line('b', 'B', n: {kcal: 70}),
      ]);
      expect(m.entries[0].nutrients, {kcal: 50, protein: 0});
      expect(m.entries[1].nutrients, {kcal: 70});
      // A real zero is kept; an absent value stays absent in the day total.
      expect(m.totals, {kcal: 120, protein: 0});
      expect(
        (await db.loadDay('2026-11-12')).totals.containsKey(carbs),
        isFalse,
      );
    });

    test('a line with no nutrients at all still makes an entry', () async {
      final m = await save([line('a', 'A', n: const {})]);
      expect(m.entries.single.nutrients, isEmpty);
      expect(m.totals, isEmpty);
      expect(await nutrientRows(), isEmpty);
    });
  });

  group('read back by day and slot', () {
    test(
      'a day lists its meals by slot order, then by time, then by id',
      () async {
        await save(
          [line('d', 'D')],
          slot: dinner,
          now: local('2026-11-12', 18, 0, cst),
        );
        final b2 = await save([
          line('b2', 'B2'),
        ], now: local('2026-11-12', 9, 0, cst));
        final b1 = await save([
          line('b1', 'B1'),
        ], now: local('2026-11-12', 7, 0, cst));
        // Logged at the same moment as b1: the earlier id first.
        final b1b = await save([
          line('b1b', 'B1b'),
        ], now: local('2026-11-12', 7, 0, cst));
        await save(
          [line('l', 'L')],
          slot: lunch,
          now: local('2026-11-12', 12, 0, cst),
        );
        await save([line('other', 'Other day')], date: '2026-11-13');
        final day = await db.loadDay('2026-11-12');
        expect(
          [for (final m in day.meals) m.entries.single.entry.foodRef],
          ['b1', 'b1b', 'b2', 'l', 'd'],
        );
        expect(b1.meal.id, lessThan(b1b.meal.id));
        expect(b2.meal.loggedAtMs, greaterThan(b1.meal.loggedAtMs));
        expect(day.localDate, '2026-11-12');
        expect(day.totals, {kcal: 500});
      },
    );

    test('a day with no meals is empty, not missing', () async {
      final day = await db.loadDay('2030-01-01');
      expect(day.meals, isEmpty);
      expect(day.totals, isEmpty);
    });

    test('the date the user picked decides the day, not the clock', () async {
      // At 7:40 on the 12th the user logs a meal for the 5th.
      final m = await save([line('a', 'A')], date: '2026-11-05');
      expect(m.meal.localDate, '2026-11-05');
      expect(m.meal.loggedAtMs, morning.utcMs);
      expect((await db.loadDay('2026-11-05')).meals, hasLength(1));
      expect((await db.loadDay('2026-11-12')).meals, isEmpty);
    });

    test('lines keep the order they were saved in, even when a later one sorts first', () async {
      final m = await save([
        line('z', 'Zucchini'),
        line('a', 'Apple'),
        line('m', 'Milk'),
      ]);
      final back = (await db.loadMeal(m.meal.id))!;
      expect(
        [for (final e in back.entries) e.entry.foodName],
        ['Zucchini', 'Apple', 'Milk'],
      );
      expect([for (final e in back.entries) e.entry.position], [0, 1, 2]);
    });

    test('loading a meal that does not exist gives null', () async {
      expect(await db.loadMeal(404), isNull);
    });

    test('a slot that was archived after use still names its meals', () async {
      await save([line('a', 'A')], slot: snack);
      await (db.update(db.mealSlots)..where((s) => s.id.equals(snack))).write(
        const MealSlotsCompanion(archived: Value(true)),
      );
      final day = await db.loadDay('2026-11-12');
      expect(day.meals.single.slotName, 'Snack');
      expect(day.meals.single.entries, hasLength(1));
    });
  });

  group('a meal of every kind of food', () {
    late FoodDetail custom;
    late FoodDetail recipe;
    late int scannedId;

    setUp(() async {
      custom = await db.createCustomFood(
        const CustomFoodInput(
          name: 'Grandma granola',
          basis: FoodBasis.per100g,
          nutrients: {kcal: 400, protein: 10, fat: 15},
        ),
        morning,
      );
      recipe = await db.createRecipe(
        RecipeInput(
          name: 'Turkey chili',
          servings: 4,
          ingredients: [
            line('usda:1', 'Turkey', base: 453, n: {kcal: 680, protein: 100}),
            line('usda:2', 'Beans', base: 436, n: {kcal: 360, protein: 20}),
          ],
        ),
        morning,
      );
      scannedId = await saveOffProduct(
        db,
        const OffProduct(
          barcode: '0123456789012',
          name: 'Plain yogurt',
          brand: 'Dairy Co',
          baseUnit: 'g',
          nutrients: {kcal: 60, protein: 4},
          servingQuantity: 170,
          servingLabel: '1 cup (170 g)',
          rawNutrimentsJson: '{}',
        ),
      );
    });

    List<MealLineInput> everything() => [
      line(
        'usda:2707153',
        'Egg, whole',
        q: 2,
        unit: 'egg',
        base: 100,
        n: {kcal: 143, protein: 12.5},
      ),
      line(
        custom.ref,
        custom.food.name,
        q: 50,
        unit: 'g',
        base: 50,
        n: {kcal: 200, protein: 5, fat: 7.5},
      ),
      line(
        recipe.ref,
        recipe.food.name,
        unit: 'serving',
        base: 1,
        baseUnit: 'serving',
        n: {kcal: 260, protein: 30},
      ),
      line(
        'local:$scannedId',
        'Plain yogurt',
        unit: 'cup',
        base: 170,
        n: {kcal: 102, protein: 6.8},
      ),
    ];

    test('is stored line by line, with each ref and the day total', () async {
      final m = await save(everything());
      expect(
        [for (final e in m.entries) e.entry.foodRef],
        ['usda:2707153', custom.ref, recipe.ref, 'local:$scannedId'],
      );
      expect(m.totals[kcal], 143 + 200 + 260 + 102);
      expect(m.totals[protein], closeTo(12.5 + 5 + 30 + 6.8, 1e-9));
      expect(m.totals[fat], 7.5);
      // The kinds really are four different kinds of food.
      expect(custom.food.kind, 'custom');
      expect(recipe.food.kind, 'recipe');
      expect((await db.loadFood(scannedId))!.food.kind, 'off');
      expect((await db.loadDay('2026-11-12')).totals[kcal], 705);
    });

    test('counts toward the history of each food', () async {
      await save(everything());
      await save([everything()[1]], date: '2026-11-13');
      final counts = await db.historyCounts();
      expect(counts['usda:2707153'], 1);
      expect(counts[custom.ref], 2);
      expect(counts[recipe.ref], 1);
      expect(counts['local:$scannedId'], 1);
    });

    test('is the same meal a day later with Same as yesterday', () async {
      final first = await save(everything());
      final copy = (await db.sameAsYesterday(
        forDate: '2026-11-13',
        slotId: breakfast,
      ))!;
      expect(copy.meal.id, first.meal.id);
      final again = await save([
        for (final e in copy.entries) e.asInput(),
      ], date: '2026-11-13');
      expect(again.meal.id, isNot(first.meal.id));
      expect(again.totals, first.totals);
      expect(
        [for (final e in again.entries) e.entry.foodRef],
        [for (final e in first.entries) e.entry.foodRef],
      );
    });
  });

  group('edit a logged meal', () {
    Future<StoredMeal> three() => save([
      line('a', 'A', n: {kcal: 100, protein: 5}),
      line('b', 'B', q: 2, n: {kcal: 200}),
      line('c', 'C', n: {kcal: 300, fat: 9}),
    ], text: 'a, b, c');

    test('add a line, and the rest keep their ids and values', () async {
      final m = await three();
      final edited = await db.editMeal(
        m.meal.id,
        now: morning,
        lines: [
          for (final e in m.entries) e.asInput(keepId: true),
          line('d', 'D', n: {kcal: 40}),
        ],
      );
      expect(edited.entries, hasLength(4));
      for (var i = 0; i < 3; i++) {
        expect(edited.entries[i].entry, m.entries[i].entry);
        expect(edited.entries[i].nutrients, m.entries[i].nutrients);
      }
      expect(edited.entries[3].entry.position, 3);
      expect(edited.entries[3].entry.id, greaterThan(m.entries[2].entry.id));
      expect(edited.meal, m.meal);
      expect(edited.totals[kcal], 640);
    });

    test('change a line: quantity, grams and nutrients are replaced, nothing else moves', () async {
      final m = await three();
      final b = m.entries[1];
      final edited = await db.editMeal(
        m.meal.id,
        now: morning,
        lines: [
          m.entries[0].asInput(keepId: true),
          line(
            b.entry.foodRef,
            b.entry.foodName,
            q: 3,
            base: 150,
            n: {kcal: 300, carbs: 40},
          ).withId(b.entry.id),
          m.entries[2].asInput(keepId: true),
        ],
      );
      final nb = edited.entries[1];
      expect(nb.entry.id, b.entry.id);
      expect(nb.entry.quantity, 3);
      expect(nb.entry.baseQuantity, 150);
      expect(nb.nutrients, {kcal: 300, carbs: 40});
      expect(edited.entries[0].entry, m.entries[0].entry);
      expect(edited.entries[2].entry, m.entries[2].entry);
      // The old nutrient rows of that entry are gone, not left beside the new.
      final rows = await nutrientRows();
      expect(rows.where((r) => r.entryId == b.entry.id), hasLength(2));
    });

    test('a nutrient taken away from a line is really gone', () async {
      final m = await three();
      final c = m.entries[2];
      final edited = await db.editMeal(
        m.meal.id,
        now: morning,
        lines: [
          m.entries[0].asInput(keepId: true),
          m.entries[1].asInput(keepId: true),
          line(
            c.entry.foodRef,
            c.entry.foodName,
            n: {kcal: 300},
          ).withId(c.entry.id),
        ],
      );
      expect(edited.entries[2].nutrients, {kcal: 300});
      expect(edited.totals.containsKey(fat), isFalse);
    });

    test(
      'remove a line: its entry and nutrient rows go, positions close up',
      () async {
        final m = await three();
        final edited = await db.editMeal(
          m.meal.id,
          now: morning,
          lines: [
            m.entries[0].asInput(keepId: true),
            m.entries[2].asInput(keepId: true),
          ],
        );
        expect([for (final e in edited.entries) e.entry.foodRef], ['a', 'c']);
        expect([for (final e in edited.entries) e.entry.position], [0, 1]);
        final all = await entryRows();
        expect(all.map((e) => e.id), isNot(contains(m.entries[1].entry.id)));
        final ids = {for (final e in all) e.id};
        expect(
          (await nutrientRows()).every((r) => ids.contains(r.entryId)),
          isTrue,
          reason: 'no nutrient row is left for a removed entry',
        );
      },
    );

    test('move a line: only the positions change', () async {
      final m = await three();
      final edited = await db.editMeal(
        m.meal.id,
        now: morning,
        lines: [
          m.entries[2].asInput(keepId: true),
          m.entries[0].asInput(keepId: true),
          m.entries[1].asInput(keepId: true),
        ],
      );
      expect(
        [for (final e in edited.entries) e.entry.foodRef],
        ['c', 'a', 'b'],
      );
      expect(
        [for (final e in edited.entries) e.entry.id],
        [m.entries[2].entry.id, m.entries[0].entry.id, m.entries[1].entry.id],
      );
      expect(edited.totals, m.totals);
    });

    test(
      'add, change and remove together, then the day shows the new total',
      () async {
        final m = await three();
        await db.editMeal(
          m.meal.id,
          now: morning,
          lines: [
            m.entries[1].asInput(keepId: true),
            line('a', 'A', n: {kcal: 150}).withId(m.entries[0].entry.id),
            line('e', 'E', n: {kcal: 5}),
          ],
        );
        final day = await db.loadDay('2026-11-12');
        expect(day.meals.single.entries, hasLength(3));
        expect(day.totals, {kcal: 355});
      },
    );

    test('moving the meal to another day and slot, the logged time and offset stay', () async {
      final m = await three();
      final edited = await db.editMeal(
        m.meal.id,
        now: local('2026-11-14', 20, 0, cst),
        lines: [for (final e in m.entries) e.asInput(keepId: true)],
        localDate: '2026-11-11',
        slotId: dinner,
      );
      expect(edited.meal.localDate, '2026-11-11');
      expect(edited.slotName, 'Dinner');
      expect(edited.meal.loggedAtMs, m.meal.loggedAtMs);
      expect(edited.meal.tzOffsetMinutes, m.meal.tzOffsetMinutes);
      expect((await db.loadDay('2026-11-12')).meals, isEmpty);
      expect((await db.loadDay('2026-11-11')).meals, hasLength(1));
    });

    test('a line from another meal is refused and nothing changes', () async {
      final m = await three();
      final other = await save([line('x', 'X')], slot: lunch);
      final before = await snapshot();
      await expectLater(
        db.editMeal(
          m.meal.id,
          now: morning,
          lines: [
            m.entries[0].asInput(keepId: true),
            other.entries[0].asInput(keepId: true),
          ],
        ),
        throwsStateError,
      );
      expect(await snapshot(), before);
    });

    test(
      'an edit that leaves no lines is refused and nothing changes',
      () async {
        final m = await three();
        final before = await snapshot();
        await expectLater(
          db.editMeal(m.meal.id, now: morning, lines: const []),
          throwsArgumentError,
        );
        expect(await snapshot(), before);
      },
    );

    test('editing a meal that is not there is refused', () async {
      await expectLater(
        db.editMeal(99, now: morning, lines: [line('a', 'A')]),
        throwsStateError,
      );
      expect(await mealRows(), isEmpty);
    });

    test('the edit of one meal never touches another', () async {
      final m = await three();
      final other = await save([
        line('x', 'X', n: {kcal: 9}),
      ], slot: lunch);
      final otherBefore = await db.loadMeal(other.meal.id);
      await db.editMeal(
        m.meal.id,
        now: morning,
        lines: [m.entries[0].asInput(keepId: true)],
      );
      final otherAfter = await db.loadMeal(other.meal.id);
      expect(otherAfter!.meal, otherBefore!.meal);
      expect(otherAfter.entries.single.entry, otherBefore.entries.single.entry);
      expect(otherAfter.entries.single.nutrients, {kcal: 9});
    });
  });

  group('delete and Undo', () {
    test(
      'delete takes out the meal, its entries and its nutrient rows only',
      () async {
        final keep = await save([line('k', 'K')], slot: lunch);
        final gone = await save([line('g', 'G'), line('h', 'H')]);
        await db.deleteMeal(gone.meal.id);
        expect((await mealRows()).map((m) => m.id), [keep.meal.id]);
        expect((await entryRows()).map((e) => e.mealId), [keep.meal.id]);
        expect((await nutrientRows()).map((r) => r.entryId), [
          keep.entries.single.entry.id,
        ]);
        expect((await db.loadDay('2026-11-12')).totals, {kcal: 100});
      },
    );

    test(
      'Undo brings back every column with the same ids, after an edit too',
      () async {
        final m = await save([
          line('a', 'A', n: {kcal: 10, protein: 1}),
          line('b', 'B', n: {kcal: 20}),
        ], text: 'a, b');
        final edited = await db.editMeal(
          m.meal.id,
          now: morning,
          typedText: 'c',
          lines: [
            m.entries[0].asInput(keepId: true),
            line('c', 'C', n: {kcal: 30}),
          ],
        );
        final before = await snapshot();
        final deleted = await db.deleteMeal(edited.meal.id);
        expect(await mealRows(), isEmpty);
        expect(await entryRows(), isEmpty);
        expect(await nutrientRows(), isEmpty);
        await db.undoDeleteMeal(deleted);
        expect(await snapshot(), before);
      },
    );

    test(
      'a meal saved after the delete does not take the deleted meal\'s ids',
      () async {
        final gone = await save([line('g', 'G')]);
        final deleted = await db.deleteMeal(gone.meal.id);
        final fresh = await save([line('f', 'F')]);
        expect(fresh.meal.id, greaterThan(gone.meal.id));
        expect(
          fresh.entries.single.entry.id,
          greaterThan(gone.entries.single.entry.id),
        );
        await db.undoDeleteMeal(deleted);
        expect((await mealRows()).map((m) => m.id), [
          gone.meal.id,
          fresh.meal.id,
        ]);
        expect(
          (await db.loadMeal(gone.meal.id))!.entries.single.entry.foodRef,
          'g',
        );
        expect(
          (await db.loadMeal(fresh.meal.id))!.entries.single.entry.foodRef,
          'f',
        );
      },
    );

    test('Undo removes only what it put back: a second delete and Undo of another meal is independent', () async {
      final a = await save([line('a', 'A')]);
      final b = await save([line('b', 'B')], slot: lunch);
      final da = await db.deleteMeal(a.meal.id);
      final dbb = await db.deleteMeal(b.meal.id);
      await db.undoDeleteMeal(dbb);
      expect((await mealRows()).map((m) => m.id), [b.meal.id]);
      await db.undoDeleteMeal(da);
      expect((await mealRows()).map((m) => m.id), [a.meal.id, b.meal.id]);
    });

    test(
      'a meal logged by Same as yesterday can be undone and leaves yesterday',
      () async {
        final yesterday = await save(
          [
            line('a', 'A', n: {kcal: 80, protein: 3}),
          ],
          date: '2026-11-11',
          now: local('2026-11-11', 7, 30, cst),
        );
        final from = (await db.sameAsYesterday(
          forDate: '2026-11-12',
          slotId: breakfast,
        ))!;
        final copy = await save([for (final e in from.entries) e.asInput()]);
        expect(copy.meal.localDate, '2026-11-12');
        expect(copy.meal.sourceText, isNull);
        expect(copy.totals, yesterday.totals);
        await db.deleteMeal(copy.meal.id);
        expect((await mealRows()).map((m) => m.id), [yesterday.meal.id]);
        final back = (await db.loadMeal(yesterday.meal.id))!;
        expect(back.entries.single.entry, yesterday.entries.single.entry);
        expect(back.entries.single.nutrients, {kcal: 80, protein: 3});
      },
    );
  });

  group('Same as yesterday', () {
    test(
      'yesterday is counted from the day being logged, not from the clock',
      () async {
        await save([line('a', 'A')], date: '2026-11-04');
        await save([line('b', 'B')], date: '2026-11-11');
        final m = await db.sameAsYesterday(
          forDate: '2026-11-05',
          slotId: breakfast,
        );
        expect(m!.entries.single.entry.foodRef, 'a');
      },
    );

    test('it is a snapshot: later changes to yesterday are seen, and a copy is its own meal', () async {
      final y = await save([
        line('a', 'A', n: {kcal: 10}),
      ], date: '2026-11-11');
      await db.editMeal(
        y.meal.id,
        now: morning,
        lines: [
          line('a', 'A', n: {kcal: 99}).withId(y.entries.single.entry.id),
        ],
      );
      final src = (await db.sameAsYesterday(
        forDate: '2026-11-12',
        slotId: breakfast,
      ))!;
      expect(src.totals, {kcal: 99});
      final copy = await save([for (final e in src.entries) e.asInput()]);
      // Editing the copy leaves yesterday alone.
      await db.editMeal(
        copy.meal.id,
        now: morning,
        lines: [
          line('z', 'Z', n: {kcal: 1}),
        ],
      );
      expect((await db.loadMeal(y.meal.id))!.totals, {kcal: 99});
    });

    test('with two meals in the slot yesterday it takes the one logged last, even if the other has a higher id', () async {
      await save(
        [line('late', 'Late')],
        date: '2026-11-11',
        now: local('2026-11-11', 9, 0, cst),
      );
      await save(
        [line('early', 'Early')],
        date: '2026-11-11',
        now: local('2026-11-11', 7, 0, cst),
      );
      final m = await db.sameAsYesterday(
        forDate: '2026-11-12',
        slotId: breakfast,
      );
      expect(m!.entries.single.entry.foodRef, 'late');
    });

    test('over a leap day, the end of a month and the end of a year', () async {
      await save([line('leap', 'Leap')], date: '2028-02-29');
      await save([line('nye', 'NYE')], date: '2026-12-31');
      expect(
        (await db.sameAsYesterday(
          forDate: '2028-03-01',
          slotId: breakfast,
        ))!.entries.single.entry.foodRef,
        'leap',
      );
      expect(
        (await db.sameAsYesterday(
          forDate: '2027-01-01',
          slotId: breakfast,
        ))!.entries.single.entry.foodRef,
        'nye',
      );
      expect(
        await db.sameAsYesterday(forDate: '2028-03-02', slotId: breakfast),
        isNull,
      );
    });
  });

  group('a food that changes after it was eaten', () {
    late FoodDetail custom;
    late StoredMeal meal;

    setUp(() async {
      custom = await db.createCustomFood(
        const CustomFoodInput(
          name: 'House bread',
          basis: FoodBasis.per100g,
          nutrients: {kcal: 250, protein: 8},
        ),
        morning,
      );
      meal = await save([
        line(
          custom.ref,
          'House bread',
          q: 2,
          unit: 'slice',
          base: 60,
          n: {kcal: 150, protein: 4.8},
        ),
      ]);
    });

    test('editing the food leaves the entry as it was', () async {
      final before = await snapshot();
      await db.editCustomFood(
        custom.food.id,
        const CustomFoodInput(
          name: 'Renamed bread',
          basis: FoodBasis.per100g,
          nutrients: {kcal: 999},
        ),
        local('2026-11-13', 8, 0, cst),
      );
      expect(await snapshot(), before);
      final back = (await db.loadMeal(meal.meal.id))!;
      expect(back.entries.single.entry.foodName, 'House bread');
      expect(back.totals, {kcal: 150, protein: 4.8});
      expect((await db.loadFood(custom.food.id))!.food.name, 'Renamed bread');
    });

    test('archiving the food leaves the entry as it was', () async {
      final before = await snapshot();
      await db.archiveFood(custom.food.id, morning);
      expect(await snapshot(), before);
      expect((await db.loadDay('2026-11-12')).totals, {
        kcal: 150,
        protein: 4.8,
      });
    });

    test('removing the food row leaves the entry as it was', () async {
      final before = await snapshot();
      await (db.delete(
        db.foods,
      )..where((f) => f.id.equals(custom.food.id))).go();
      expect(await snapshot(), before);
      final back = (await db.loadMeal(meal.meal.id))!;
      expect(back.entries.single.entry.foodRef, custom.ref);
      // Editing the meal around a missing food keeps the line untouched.
      final edited = await db.editMeal(
        meal.meal.id,
        now: morning,
        lines: [
          for (final e in back.entries) e.asInput(keepId: true),
          line('x', 'X', n: {kcal: 1}),
        ],
      );
      expect(edited.entries.first.entry, meal.entries.single.entry);
      expect(edited.entries.first.nutrients, {kcal: 150, protein: 4.8});
    });

    test(
      'a recipe edited after it was eaten leaves the entry as it was',
      () async {
        final recipe = await db.createRecipe(
          RecipeInput(
            name: 'Stew',
            servings: 2,
            ingredients: [
              line('usda:9', 'Beef', n: {kcal: 400}),
            ],
          ),
          morning,
        );
        final eaten = await save([
          line(
            recipe.ref,
            'Stew',
            unit: 'serving',
            base: 1,
            baseUnit: 'serving',
            n: {kcal: 200},
          ),
        ], slot: dinner);
        await db.editRecipe(
          recipe.food.id,
          RecipeInput(
            name: 'Stew',
            servings: 2,
            ingredients: [
              line('usda:9', 'Beef', n: {kcal: 800}),
            ],
          ),
          morning,
        );
        expect((await db.loadMeal(eaten.meal.id))!.totals, {kcal: 200});
      },
    );

    test('deleting the saved meal a meal came from keeps the meal and clears the link', () async {
      final saved = await db.createSavedMeal(
        name: 'Usual',
        items: [
          line('a', 'A', n: {kcal: 10}),
        ],
        now: morning,
      );
      final id = saved.saved!.meal.id;
      final m = await db.saveMeal(
        now: morning,
        localDate: '2026-11-12',
        slotId: lunch,
        savedMealId: id,
        lines: [
          line('a', 'A', n: {kcal: 10}),
        ],
      );
      expect(m.meal.savedMealId, id);
      await db.deleteSavedMeal(id);
      final back = (await db.loadMeal(m.meal.id))!;
      expect(back.meal.savedMealId, isNull);
      expect(back.entries.single.entry.foodRef, 'a');
      expect(back.totals, {kcal: 10});
    });
  });

  group('the clock and the day', () {
    test(
      'the last minute of the day and the first minute of the next',
      () async {
        final late = local('2026-11-12', 23, 59, cst);
        final first = local('2026-11-13', 0, 0, cst);
        expect(late.localDate, '2026-11-12');
        expect(first.localDate, '2026-11-13');
        expect(first.utcMs - late.utcMs, 60000);
        await save([line('late', 'Late')], now: late);
        await save([line('first', 'First')], now: first);
        expect(
          [
            for (final m in (await db.loadDay('2026-11-12')).meals)
              m.entries.single.entry.foodRef,
          ],
          ['late'],
        );
        expect(
          [
            for (final m in (await db.loadDay('2026-11-13')).meals)
              m.entries.single.entry.foodRef,
          ],
          ['first'],
        );
      },
    );

    test('the last millisecond before midnight is still that day', () async {
      final midnight = local('2026-11-13', 0, 0, cst);
      final justBefore = Now(utcMs: midnight.utcMs - 1, offsetMinutes: cst);
      expect(justBefore.localDate, '2026-11-12');
      expect(justBefore.minuteOfDay, 1439);
      final m = await save([line('a', 'A')], now: justBefore);
      expect(m.meal.localDate, '2026-11-12');
      expect(m.meal.loggedAtMs, midnight.utcMs - 1);
    });

    test('a meal late in the evening is on its own day even when it is already tomorrow in UTC', () async {
      final evening = local('2026-11-12', 21, 30, cst);
      expect(
        DateTime.fromMillisecondsSinceEpoch(evening.utcMs, isUtc: true).day,
        13,
      );
      final m = await save([line('a', 'A')], slot: snack, now: evening);
      expect(m.meal.localDate, '2026-11-12');
      expect((await db.loadDay('2026-11-13')).meals, isEmpty);
    });

    test(
      'travelling to another time zone does not move meals already logged',
      () async {
        final home = await save([
          line('home', 'Home'),
        ], now: local('2026-11-12', 22, 0, cst));
        // Later, in Tokyo (UTC plus 9), the same instant is already the 13th.
        final tokyo = Now(utcMs: home.meal.loggedAtMs, offsetMinutes: 540);
        expect(tokyo.localDate, '2026-11-13');
        expect((await db.loadMeal(home.meal.id))!.meal.localDate, '2026-11-12');
        final away = await save([
          line('away', 'Away'),
        ], now: local('2026-11-13', 8, 0, 540));
        expect(away.meal.tzOffsetMinutes, 540);
        expect(
          (await db.loadDay('2026-11-12')).meals.single.meal.id,
          home.meal.id,
        );
        expect(
          (await db.loadDay('2026-11-13')).meals.single.meal.id,
          away.meal.id,
        );
      },
    );

    test(
      'spring forward: a day of 23 hours holds both sides of the change',
      () async {
        // Sunday 2026-03-08, 2:00 am becomes 3:00 am.
        final before = local('2026-03-08', 1, 59, cst);
        final after = local('2026-03-08', 3, 0, cdt);
        expect(after.utcMs - before.utcMs, 60000);
        expect(before.localDate, after.localDate);
        await save([line('after', 'After')], now: after);
        await save([line('before', 'Before')], now: before);
        final day = await db.loadDay('2026-03-08');
        expect(
          [for (final m in day.meals) m.entries.single.entry.foodRef],
          ['before', 'after'],
        );
        expect([for (final m in day.meals) m.meal.tzOffsetMinutes], [cst, cdt]);
      },
    );

    test('fall back: a wall clock time that happens twice is two meals in the right order', () async {
      // Sunday 2026-11-01, 2:00 am becomes 1:00 am. 1:30 is seen twice.
      final first = local('2026-11-01', 1, 30, cdt);
      final second = local('2026-11-01', 1, 30, cst);
      expect(first.minuteOfDay, second.minuteOfDay);
      expect(second.utcMs - first.utcMs, 3600000);
      await save([line('second', 'Second')], now: second);
      await save([line('first', 'First')], now: first);
      final day = await db.loadDay('2026-11-01');
      expect(
        [for (final m in day.meals) m.entries.single.entry.foodRef],
        ['first', 'second'],
      );
      expect((await db.loadDay('2026-10-31')).meals, isEmpty);
      expect((await db.loadDay('2026-11-02')).meals, isEmpty);
    });

    test(
      'the day after a change day is the next calendar day, whatever the hours',
      () async {
        for (final (day, next) in [
          ('2026-03-07', '2026-03-08'),
          ('2026-03-08', '2026-03-09'),
          ('2026-10-31', '2026-11-01'),
          ('2026-11-01', '2026-11-02'),
        ]) {
          expect(addDays(day, 1), next);
          expect(addDays(next, -1), day);
        }
        await save(
          [line('a', 'A')],
          date: '2026-03-08',
          now: local('2026-03-08', 23, 30, cdt),
        );
        final y = await db.sameAsYesterday(
          forDate: '2026-03-09',
          slotId: breakfast,
        );
        expect(y!.entries.single.entry.foodRef, 'a');
        expect(
          await db.sameAsYesterday(forDate: '2026-03-08', slotId: breakfast),
          isNull,
        );
      },
    );

    test(
      'recent foods count the 30 days by calendar date across a change',
      () async {
        // 2026-10-14 is 29 days before 2026-11-12, over the fall back.
        await save([line('in', 'In')], date: '2026-10-14');
        await save([line('out', 'Out')], date: '2026-10-13');
        final recent = await db.recentFoods(
          slotId: breakfast,
          today: '2026-11-12',
        );
        expect([for (final r in recent) r.foodRef], ['in']);
      },
    );
  });

  group('the default meal by time of day', () {
    test('is read from the clock in the clock\'s own offset', () async {
      // One instant, 14:00 UTC, on three phones.
      final utc = Now(
        utcMs: DateTime.utc(2026, 11, 12, 14).millisecondsSinceEpoch,
        offsetMinutes: 0,
      );
      Now seenAt(int offset) => Now(utcMs: utc.utcMs, offsetMinutes: offset);
      expect(
        (await db.defaultMealSlot(seenAt(cst).minuteOfDay)).name,
        'Breakfast',
      );
      expect((await db.defaultMealSlot(seenAt(0).minuteOfDay)).name, 'Lunch');
      expect((await db.defaultMealSlot(seenAt(540).minuteOfDay)).name, 'Snack');
      expect(
        (await db.defaultMealSlot(seenAt(-540).minuteOfDay)).name,
        'Breakfast',
      );
    });

    test('follows a daylight saving change by the wall clock', () async {
      // 10:29 and 10:30 on the day the clocks go forward, and the day after.
      for (final date in ['2026-03-07', '2026-03-08', '2026-03-09']) {
        final offset = date == '2026-03-07' ? cst : cdt;
        expect(
          (await db.defaultMealSlot(local(date, 10, 29, offset).minuteOfDay))
              .name,
          'Breakfast',
        );
        expect(
          (await db.defaultMealSlot(local(date, 10, 30, offset).minuteOfDay))
              .name,
          'Lunch',
        );
      }
    });

    test('the very first and last minute of the day', () async {
      expect((await db.defaultMealSlot(0)).name, 'Breakfast');
      expect((await db.defaultMealSlot(1439)).name, 'Snack');
    });

    test('a meal saved in the default slot is listed in that slot', () async {
      final at1130 = local('2026-11-12', 11, 30, cst);
      final slot = await db.defaultMealSlot(at1130.minuteOfDay);
      await save([line('a', 'A')], slot: slot.id, now: at1130);
      expect((await db.loadDay('2026-11-12')).meals.single.slotName, 'Lunch');
      expect(slot.id, lunch);
    });

    test(
      'moving a rule moves the boundary, renaming a slot renames the default',
      () async {
        await (db.update(db.mealSlotRules)
              ..where((r) => r.startMinute.equals(630)))
            .write(const MealSlotRulesCompanion(startMinute: Value(660)));
        expect((await db.defaultMealSlot(10 * 60 + 45)).name, 'Breakfast');
        expect((await db.defaultMealSlot(11 * 60)).name, 'Lunch');
        await (db.update(db.mealSlots)..where((s) => s.id.equals(lunch))).write(
          const MealSlotsCompanion(name: Value('Midday')),
        );
        expect((await db.defaultMealSlot(12 * 60)).name, 'Midday');
      },
    );

    test(
      'a slot the user adds with its own start time is picked from then on',
      () async {
        final id = await db
            .into(db.mealSlots)
            .insert(MealSlotsCompanion.insert(name: 'Tea', position: 4));
        await db
            .into(db.mealSlotRules)
            .insert(
              MealSlotRulesCompanion.insert(
                startMinute: const Value(15 * 60),
                slotId: id,
              ),
            );
        expect((await db.defaultMealSlot(14 * 60 + 59)).name, 'Snack');
        expect((await db.defaultMealSlot(15 * 60)).name, 'Tea');
        expect((await db.defaultMealSlot(16 * 60 + 59)).name, 'Tea');
        expect((await db.defaultMealSlot(17 * 60)).name, 'Dinner');
      },
    );
  });
}

extension on MealLineInput {
  /// The same line as an edit of the stored entry [id].
  MealLineInput withId(int id) => MealLineInput(
    foodRef: foodRef,
    foodName: foodName,
    quantity: quantity,
    unitLabel: unitLabel,
    baseQuantity: baseQuantity,
    baseUnit: baseUnit,
    nutrients: nutrients,
    existingId: id,
  );
}
