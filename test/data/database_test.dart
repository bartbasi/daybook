// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/database.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('new database has the default meal slots and time rules', () async {
    final slots = await db.select(db.mealSlots).get();
    expect(slots.map((s) => s.name), ['Breakfast', 'Lunch', 'Dinner', 'Snack']);

    final rules = await db.select(db.mealSlotRules).get();
    final byId = {for (final s in slots) s.id: s.name};
    expect(
      {for (final r in rules) r.startMinute: byId[r.slotId]},
      {
        0: 'Breakfast',
        630: 'Lunch',
        870: 'Snack',
        1020: 'Dinner',
        1260: 'Snack',
      },
    );
  });

  test('a goals row keeps calories in both modes', () async {
    for (final (i, mode) in ['calculated', 'fixed'].indexed) {
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              effectiveFrom: '2026-01-0${i + 1}',
              calorieMode: mode,
              calories: Value(2138 + i),
              activityFactor: 1.375,
              targetKgPerWeek: -0.5,
              macroMode: 'grams',
            ),
          );
    }
    final rows = await (db.select(
      db.goals,
    )..orderBy([(g) => OrderingTerm.asc(g.effectiveFrom)])).get();
    expect([for (final g in rows) (g.calorieMode, g.calories)], [
      ('calculated', 2138),
      ('fixed', 2139),
    ]);
  });

  test('deleting a saved meal sets meals.saved_meal_id to null', () async {
    final savedId = await db
        .into(db.savedMeals)
        .insert(SavedMealsCompanion.insert(name: 'Usual', createdAtMs: 1));
    final slot = (await db.select(db.mealSlots).get()).first;
    final mealId = await db
        .into(db.meals)
        .insert(
          MealsCompanion.insert(
            localDate: '2026-01-02',
            slotId: slot.id,
            loggedAtMs: 1,
            tzOffsetMinutes: 0,
            savedMealId: Value(savedId),
          ),
        );
    var meal = await (db.select(
      db.meals,
    )..where((m) => m.id.equals(mealId))).getSingle();
    expect(meal.savedMealId, savedId);

    await db.delete(db.savedMeals).go();

    meal = await (db.select(
      db.meals,
    )..where((m) => m.id.equals(mealId))).getSingle();
    expect(meal.savedMealId, isNull);
  });

  test('foreign keys are enforced', () async {
    await expectLater(
      db
          .into(db.mealEntries)
          .insert(
            MealEntriesCompanion.insert(
              mealId: 999,
              position: 0,
              foodRef: 'usda:1',
              foodName: 'x',
              quantity: 1,
              unitLabel: 'g',
              baseQuantity: 1,
              baseUnit: 'g',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
