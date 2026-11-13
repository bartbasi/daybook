// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The body weight flow of speed target 3, written once and used twice: by
// test/speed/weight_speed_test.dart (the whole app, an in-memory database) and
// by integration_test/flows_test.dart (a real build, the real database). It
// finds widgets by type and by their words and uses no mocks, so it cannot
// tell which of the two it is running in.
//
// The flow reads the database through the app's own AppScope, so it works
// with whatever database the app was started with, and it copes with rows that
// are already there: it only looks at the rows its own save added.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/app_scope.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/platform/weight_widget.dart';
import 'package:daybook/screens/home/home_screen.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/strings.dart';
import 'package:daybook/util/dates.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/speed/tap_counter.dart';

/// The database the running app uses.
AppDatabase appDatabase(WidgetTester tester) => tester
    .element(find.byType(HomeShell))
    .getInheritedWidgetOfExactType<AppScope>()!
    .db;

/// Every stored weigh-in, deleted ones too.
Future<List<WeightEntry>> storedWeights(WidgetTester tester) async {
  final db = appDatabase(tester);
  return (await tester.runAsync(() => db.select(db.weightEntries).get()))!;
}

/// Pumps, with real time passing for the database, until [done] is true. Fails
/// with [what] after [tries] rounds, about 0.125 seconds each (twenty-five
/// seconds by default).
Future<void> waitFor(
  WidgetTester tester,
  bool Function() done,
  String what, {
  int tries = 200,
}) async {
  for (var i = 0; i < tries; i++) {
    if (done()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (!done()) fail('Gave up waiting for $what');
}

/// Waits until the weight sheet is on screen and has finished sliding in.
Future<void> waitForWeightSheet(WidgetTester tester) async {
  await waitFor(
    tester,
    () => find.byType(WeightSheet).evaluate().isNotEmpty,
    'the weight sheet to open',
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Tells the running app that the widget was tapped, in the form the home_widget
/// plugin uses, then waits for the sheet. This is the one step of the widget
/// path a test cannot do for real (see integration_test/widget_launch_test.dart).
Future<void> deliverWidgetLink(WidgetTester tester) async {
  // Not awaited: the answer comes through real async code that a widget test
  // cannot run while it waits. The sheet below is what shows it arrived.
  unawaited(
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'home_widget/updates',
      // On iOS the widget's URL carries the plugin's query item.
      const StandardMethodCodec().encodeSuccessEnvelope(
        defaultTargetPlatform == TargetPlatform.android
            ? weightLaunchLink
            : '$weightLaunchLink?homeWidget',
      ),
      (_) {},
    ),
  );
  await waitForWeightSheet(tester);
}

/// From Home: tap Weight, type [type] if given (leave the number alone when
/// null), then save with the Save button, or with the keyboard's done key when
/// [doneKey] is true. Counts one tap to open and one to save. Returns the row
/// that was stored. Waits first for any earlier "Weight saved" bar to go away.
Future<WeightEntry> logWeightFromHome(
  WidgetTester tester,
  TapCounter taps, {
  String? type,
  bool doneKey = false,
}) async {
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.byType(WeightSheet), findsNothing);
  await taps.tap(find.widgetWithText(FilledButton, S.addWeight));
  await waitForWeightSheet(tester);
  return saveOpenWeightSheet(tester, taps, type: type, doneKey: doneKey);
}

/// With the weight sheet already open (the widget link opened it): type
/// [type] if given, then save. Counts one tap, the save. Checks that the sheet
/// closed, that exactly one row was added, and that Home confirms it from the
/// stored row. Returns that row.
Future<WeightEntry> saveOpenWeightSheet(
  WidgetTester tester,
  TapCounter taps, {
  String? type,
  bool doneKey = false,
}) async {
  expect(find.byType(WeightSheet), findsOneWidget);
  // An earlier save's bar stays for ten seconds. If it were still showing,
  // the check below could pass on the old bar, so wait it out first.
  await waitFor(
    tester,
    () => find.textContaining('Weight saved').evaluate().isEmpty,
    'the earlier "Weight saved" bar to go away',
  );
  final before = {for (final r in await storedWeights(tester)) r.id};

  if (type != null) await taps.type(find.byType(TextField), type);
  await tester.pump();
  if (doneKey) {
    await taps.keyboardAction();
  } else {
    await taps.tap(find.widgetWithText(FilledButton, S.save));
  }
  await waitFor(
    tester,
    () => find.byType(WeightSheet).evaluate().isEmpty,
    'the sheet to close after the save',
  );

  final added = [
    for (final r in await storedWeights(tester))
      if (!before.contains(r.id)) r,
  ];
  expect(added, hasLength(1), reason: 'one save adds exactly one row');
  final row = added.single;
  expect(row.deletedAtMs, isNull);
  expect(row.localDate, localDateOf(row.measuredAtMs, row.tzOffsetMinutes));

  // Home says what was stored, read back, not what was typed.
  final db = appDatabase(tester);
  final units = (await tester.runAsync(db.getUnits))!;
  final said =
      'Weight saved: ${formatWeight(row.weightKg, units)} '
      '${S.unitWord(units)}';
  await waitFor(
    tester,
    () => find.textContaining(said).evaluate().isNotEmpty,
    'Home to confirm "$said"',
  );
  return row;
}

/// Speed target 3 on a real build or in the whole app: the device clock, the
/// real database. Does not assume the database is empty, never looks at a date
/// or a time zone, and at the end deletes the rows it added and puts the
/// units setting back. The widget link is sent by hand, as in
/// widget_launch_test.dart: a test cannot tap a home-screen widget.
Future<void> runWeightFlow(WidgetTester tester) async {
  final db = appDatabase(tester);
  final rowsBefore = {for (final r in await storedWeights(tester)) r.id};
  final unitsBefore = (await tester.runAsync(db.getUnits))!;
  // The app's own clock, from its scope: the device clock on a device, the
  // fixed clock in the widget harness. The flow never looks at a date.
  final startedMs = tester
      .element(find.byType(HomeShell))
      .getInheritedWidgetOfExactType<AppScope>()!
      .clock()
      .utcMs;

  /// Checks the row was stored at about the time the app's clock says.
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
    // CI removes the app after each entry file, so this does not matter there.
    // It is for a run on a phone or a simulator that is kept: the rows and the
    // units setting this flow added are taken out, so the next flow in the
    // same run starts from what it expects and nothing of the test is left in
    // the person's data. It uses the handle from the start, not the widget
    // tree, so it works even if a failure left no app on screen.
    await tester.runAsync(() async {
      final added = [
        for (final r in await db.select(db.weightEntries).get())
          if (!rowsBefore.contains(r.id)) r.id,
      ];
      await (db.delete(db.weightEntries)..where((w) => w.id.isIn(added))).go();
    });
    // The screens reload after the delete, and that needs frames. A second
    // write started before they finish would wait for them forever.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => db.setUnits(unitsBefore));
    await tester.pump(const Duration(milliseconds: 500));
  }
}
