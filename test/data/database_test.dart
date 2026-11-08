// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/database.dart';
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
