// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Speed target 1 (log a typed 4-item meal) on a real build: the real app, the
// real database file on the device, the real food data and the real clock. CI
// runs it on an Android emulator and an iOS simulator. It runs the same flow
// as test/speed/food_speed_test.dart: tap + Food, type the brief's meal, tap
// Save, and Home shows the meal with its 490 kcal.
//
// Only what has to run on a device is here. Saved meal chips, Same as
// yesterday and editing a meal need nothing from the device that this flow
// does not already use, so they are widget tests only.
//
// Other integration tests share this device database, in any order. So this
// test does not assume it is empty, never looks at a date (the clock is the
// device's), and at the end it deletes the meals it added.

import 'package:daybook/clock.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/speed/tap_counter.dart';
import 'flows/food_flow.dart';
import 'flows/weight_flow.dart' show appDatabase, waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logging the brief meal takes 2 taps from Home, and Home '
      'shows 5 entries worth 490 kcal', (tester) async {
    app.main();
    await waitFor(
      tester,
      () => find.byType(NavigationBar).evaluate().isNotEmpty,
      'the app to start',
      tries: 480, // about 60 seconds, as in app_launch_test.dart
    );
    final db = appDatabase(tester);
    final mealsBefore = await storedMealIds(tester);
    final startedMs = DateTime.now().millisecondsSinceEpoch;

    try {
      final taps = TapCounter(tester);
      final meal = await logTypedMeal(
        tester,
        taps,
        sampleMeal,
        lines: 5,
        kcal: 490,
      );
      taps.expectCount(2, flow: '+ Food, type the meal, Save');

      expect(meal.entries, hasLength(5));
      expect(meal.totals[Nutrients.energy]!.round(), 490);
      expect(meal.meal.sourceText, sampleMeal);
      // The device clock decided the day and the meal, so the test checks
      // them against the same clock and never against a fixed date.
      expect(
        (meal.meal.loggedAtMs - startedMs).abs(),
        lessThan(const Duration(minutes: 10).inMilliseconds),
      );
      final seen = Now(
        utcMs: meal.meal.loggedAtMs,
        offsetMinutes: meal.meal.tzOffsetMinutes,
      );
      expect(meal.meal.localDate, seen.localDate);
      final slot = (await tester.runAsync(
        () => db.defaultMealSlot(seen.minuteOfDay),
      ))!;
      expect(meal.slotName, slot.name);

      // The meal is on the device, once, and Undo takes away only it.
      final added = [
        for (final m in await storedMeals(tester))
          if (!mealsBefore.contains(m.meal.id)) m.meal.id,
      ];
      expect(added, [meal.meal.id]);
      await undoOnHome(tester, TapCounter(tester), meal);
      expect(await storedMealIds(tester), mealsBefore);
    } finally {
      // The handle from the start, not the widget tree: the cleanup must work
      // even if a failure left no app on screen.
      await tester.runAsync(() async {
        await (db.delete(
          db.meals,
        )..where((m) => m.id.isNotIn(mealsBefore))).go();
      });
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
