// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('units default to imperial', () async {
    expect(await db.getUnits(), UnitSystem.imperial);
  });

  test('setUnits changes the setting and getUnits reads it back', () async {
    await db.setUnits(UnitSystem.metric);
    expect(await db.getUnits(), UnitSystem.metric);
    await db.setUnits(UnitSystem.imperial);
    expect(await db.getUnits(), UnitSystem.imperial);
    expect(
      await (db.select(db.settings)..where((s) => s.key.equals('units'))).get(),
      hasLength(1),
    );
  });

  test('watchUnits emits the current value, then each change', () async {
    final seen = <UnitSystem>[];
    final sub = db.watchUnits().listen(seen.add);
    await pumpEventQueue();
    await db.setUnits(UnitSystem.metric);
    await pumpEventQueue();
    await db.setUnits(UnitSystem.metric); // no change, no emit
    await pumpEventQueue();
    await db.setUnits(UnitSystem.imperial);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [UnitSystem.imperial, UnitSystem.metric, UnitSystem.imperial]);
  });

  test('a missing units row reads as imperial', () async {
    await db.delete(db.settings).go();
    expect(await db.getUnits(), UnitSystem.imperial);
  });
}
