// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Speed target 3 (log body weight) on a real build: the real app, the real
// database file on the device, the real clock. CI runs it on an Android
// emulator and an iOS simulator. It runs the same flow as
// test/speed/weight_speed_test.dart, from Home and from the widget link.
//
// The widget link is sent by hand, as in widget_launch_test.dart: a test
// cannot tap a home-screen widget. What a real tap on the widget does, and the
// stopwatch times, are for Bart's phones.
//
// Other integration tests share this device database, in any order. So this
// test does not assume it is empty, never looks at a date or a time zone (the
// clock is the device's), and at the end it deletes the rows it added and puts
// the units setting back.

import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/main.dart' as app;
import 'package:daybook/util/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/speed/tap_counter.dart';
import 'flows/weight_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logging weight takes 2 taps from Home and 1 from the widget '
      'link, in pounds and in kilograms', (tester) async {
    app.main();
    await waitFor(
      tester,
      () => find.byType(NavigationBar).evaluate().isNotEmpty,
      'the app to start',
      tries: 480, // about 60 seconds, as in app_launch_test.dart
    );
    final db = appDatabase(tester);
    final rowsBefore = {for (final r in await storedWeights(tester)) r.id};
    final unitsBefore = (await tester.runAsync(db.getUnits))!;
    final startedMs = DateTime.now().millisecondsSinceEpoch;

    /// The device clock, so the test never looks at a date.
    void expectNow(WeightEntry row) {
      expect(
        (row.measuredAtMs - startedMs).abs(),
        lessThan(const Duration(minutes: 10).inMilliseconds),
      );
    }

    try {
      await tester.runAsync(() => db.setUnits(UnitSystem.imperial));

      // Home, typing 181.8: 2 counted taps.
      var taps = TapCounter(tester);
      final typed = await logWeightFromHome(tester, taps, type: '181.8');
      taps.expectCount(2, flow: 'Weight, Save');
      expect(typed.weightKg, lbToKg(181.8));
      expectNow(typed);

      // Home, the weight unchanged from last time: 2 counted taps, no typing.
      taps = TapCounter(tester);
      final same = await logWeightFromHome(tester, taps);
      taps.expectCount(2, flow: 'Weight, Save');
      expect(same.weightKg, typed.weightKg);
      expectNow(same);

      // The widget link, typing: 1 counted tap.
      await deliverWidgetLink(tester);
      taps = TapCounter(tester);
      final fromWidget = await saveOpenWeightSheet(tester, taps, type: '182.2');
      taps.expectCount(1, flow: 'the widget link, then Save');
      expect(fromWidget.weightKg, lbToKg(182.2));
      expectNow(fromWidget);

      // Kilograms: the same flows.
      await tester.runAsync(() => db.setUnits(UnitSystem.metric));
      taps = TapCounter(tester);
      final metric = await logWeightFromHome(tester, taps, type: '82.5');
      taps.expectCount(2, flow: 'Weight, Save, in kg');
      expect(metric.weightKg, 82.5);
      expectNow(metric);

      await deliverWidgetLink(tester);
      taps = TapCounter(tester);
      final metricWidget = await saveOpenWeightSheet(tester, taps);
      taps.expectCount(1, flow: 'the widget link, then Save, in kg');
      expect(metricWidget.weightKg, 82.5);
      expectNow(metricWidget);

      // Everything is on the device, once each.
      final added = [
        for (final r in await storedWeights(tester))
          if (!rowsBefore.contains(r.id)) r.id,
      ];
      expect(added, hasLength(5));
    } finally {
      // The handle from the start, not the widget tree: the cleanup must work
      // even if a failure left no app on screen.
      await tester.runAsync(() async {
        final added = [
          for (final r in await db.select(db.weightEntries).get())
            if (!rowsBefore.contains(r.id)) r.id,
        ];
        await (db.delete(
          db.weightEntries,
        )..where((w) => w.id.isIn(added))).go();
        await db.setUnits(unitsBefore);
      });
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
