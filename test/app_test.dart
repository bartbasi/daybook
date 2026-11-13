// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/util/units.dart';
import 'package:daybook/screens/home/home_screen.dart';
import 'package:daybook/screens/more/more_screen.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/screens/weight/weight_tab.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late AppDatabase db;

  // The home_widget plugin, mocked at its channels. `launchLink` is what the
  // plugin says the app was started with.
  String? launchLink;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    launchLink = null;
  });

  /// A tap on the widget while the app is running.
  Future<void> sendLink(WidgetTester tester, String link) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'home_widget/updates',
      const StandardMethodCodec().encodeSuccessEnvelope(link),
      (_) {},
    );
    await settle(tester);
  }

  /// Unmounts the app first, so drift's stream clean-up timer runs, then
  /// closes the database.
  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (call) async => call.method == 'initiallyLaunchedFromHomeWidget'
            ? launchLink
            : null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget/updates'),
        (call) async => null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          null,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget/updates'),
          null,
        );
      });
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(db.close);
    });
  }

  Future<void> openApp(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => Now.fromLocal('2026-11-12', 7 * 60 + 2, -360),
        // Never completes: the Data check screen shows its loading text.
        foodsPath: Completer<String>().future,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }

  NavigationDestination tab(WidgetTester tester, String label) =>
      tester.widget<NavigationDestination>(
        find.widgetWithText(NavigationDestination, label),
      );

  appTest('five tabs, each with an icon and a word', (tester) async {
    await openApp(tester);
    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final label in ['Today', 'Summary', 'Workouts', 'Weight', 'More']) {
      final d = find.widgetWithText(NavigationDestination, label);
      expect(d, findsOneWidget, reason: label);
      expect(
        find.descendant(of: d, matching: find.byType(Icon)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  appTest('tabs that are not built yet are disabled and cannot be '
      'selected', (tester) async {
    await openApp(tester);
    expect(tab(tester, 'Today').enabled, isTrue);
    expect(tab(tester, 'Weight').enabled, isTrue);
    expect(tab(tester, 'More').enabled, isTrue);
    for (final label in ['Summary', 'Workouts']) {
      expect(tab(tester, label).enabled, isFalse, reason: label);
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pump();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
        reason: label,
      );
      expect(find.text('Thursday, Nov 12'), findsOneWidget, reason: label);
    }
    expect(find.textContaining('oon'), findsNothing);
  });

  appTest('Weight opens its tab and Today comes back', (tester) async {
    await openApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Weight'));
    await tester.pumpAndSettle();
    expect(find.byType(WeightTab), findsOneWidget);
    expect(
      find.text('No weigh-ins yet. Tap + Log to add one.'),
      findsOneWidget,
    );
    expect(find.text('Thursday, Nov 12'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await tester.pumpAndSettle();
    expect(find.text('Thursday, Nov 12'), findsOneWidget);
  });

  appTest('an app left open across midnight moves to the new day with no '
      'lifecycle event', (tester) async {
    var now = Now.fromLocal('2026-11-12', 23 * 60 + 59, -360);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => db.saveWeight(181.8, UnitSystem.imperial, now));
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => now,
        foodsPath: Completer<String>().future,
      ),
    );
    await settle(tester);
    expect(find.text('Thursday, Nov 12'), findsOneWidget);
    expect(find.text('Today, 11:59 pm'), findsOneWidget);

    // Midnight passes. No pause, no resume.
    now = Now.fromLocal('2026-11-13', 1, -360);
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();
    expect(find.text('Friday, Nov 13'), findsOneWidget);
    expect(find.text('Thursday, Nov 12'), findsNothing);
    expect(find.text('Yesterday, 11:59 pm'), findsOneWidget);
  });

  appTest('More opens, keeps Home alive, and leads to Data check', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(find.text('Data check'), findsOneWidget);

    await tester.tap(find.text('Data check'));
    // Not pumpAndSettle: the loading spinner never stops.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Getting the food database ready...'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await tester.pumpAndSettle();
    expect(find.text('Thursday, Nov 12'), findsOneWidget);
  });

  Finder sheet() => find.byType(WeightSheet);
  int selectedTab(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  appTest('started from the widget, the weight sheet is open over Today', (
    tester,
  ) async {
    launchLink = 'daybook://weight';
    // The food database never arrives in these tests, and nothing waits for it.
    await openApp(tester);
    await settle(tester);
    expect(selectedTab(tester), 0);
    expect(sheet(), findsOneWidget);
    expect(find.text('Thursday, Nov 12'), findsOneWidget);
  });

  appTest('started any other way, no sheet opens', (tester) async {
    await openApp(tester);
    await settle(tester);
    expect(sheet(), findsNothing);
    launchLink = null;
    await sendLink(tester, 'daybook://something-else');
    expect(sheet(), findsNothing);
  });

  appTest('a link that arrives while the app runs opens the sheet on Today', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Weight'));
    await settle(tester);
    expect(selectedTab(tester), 3);

    await sendLink(tester, 'daybook://weight');
    expect(selectedTab(tester), 0);
    expect(sheet(), findsOneWidget);
  });

  appTest('a second link while the sheet is open does not open a second '
      'sheet', (tester) async {
    await openApp(tester);
    await sendLink(tester, 'daybook://weight');
    await sendLink(tester, 'daybook://weight');
    expect(sheet(), findsOneWidget);

    // Closing it once leaves no sheet underneath.
    await tester.tapAt(const Offset(200, 20));
    await settle(tester);
    expect(sheet(), findsNothing);
  });

  /// The app opened with a clock the test can move.
  Future<void> openAppAt(WidgetTester tester, Now Function() clock) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DaybookApp(db: db, clock: clock, foodsPath: Completer<String>().future),
    );
    await settle(tester);
  }

  void pauseAndResume(WidgetTester tester) {
    final b = tester.binding;
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      b.handleAppLifecycleStateChanged(s);
    }
  }

  appTest('a sheet left open overnight, with the app in the background, '
      'saves the time after the app comes back', (tester) async {
    var now = Now.fromLocal('2026-11-12', 23 * 60, -360);
    await openAppAt(tester, () => now);
    await tester.tap(find.widgetWithText(FilledButton, 'Weight'));
    await settle(tester);
    expect(find.text('Today, 11:00 pm'), findsOneWidget);

    now = Now.fromLocal('2026-11-13', 7 * 60, -360);
    pauseAndResume(tester);
    await tester.pump();
    expect(find.text('Today, 7:00 am'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    final stored = (await tester.runAsync(
      () => db.select(db.weightEntries).get(),
    ))!;
    expect(stored.single.localDate, '2026-11-13');
    expect(stored.single.measuredAtMs, now.utcMs);
    expect(find.text('Weight saved: 181.8 lb, today 7:00 am'), findsOneWidget);
  });

  appTest('a time picked with Change survives the app coming back', (
    tester,
  ) async {
    var now = Now.fromLocal('2026-11-12', 23 * 60, -360);
    await openAppAt(tester, () => now);
    await tester.tap(find.widgetWithText(FilledButton, 'Weight'));
    await settle(tester);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final boxes = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(boxes.at(0), '9');
    await tester.enterText(boxes.at(1), '30');
    // The sheet opened at 11 pm, so the picker starts on pm.
    await tester.tap(find.text('AM'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Thu, Nov 5, 9:30 am'), findsOneWidget);

    now = Now.fromLocal('2026-11-13', 7 * 60, -360);
    pauseAndResume(tester);
    await tester.pump();
    expect(find.text('Thu, Nov 5, 9:30 am'), findsOneWidget);
  });

  appTest('a widget link while the Weight tab add sheet is open leaves one '
      'sheet', (tester) async {
    await openApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Weight'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '+ Log'));
    await settle(tester);
    expect(sheet(), findsOneWidget);

    await sendLink(tester, 'daybook://weight');
    expect(sheet(), findsOneWidget);

    await tester.tapAt(const Offset(200, 20));
    await settle(tester);
    expect(sheet(), findsNothing);

    // The next request opens it again.
    await sendLink(tester, 'daybook://weight');
    expect(sheet(), findsOneWidget);
  });

  appTest('a widget link while an edit sheet is open leaves one sheet', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.saveWeight(
        181.8,
        UnitSystem.imperial,
        Now.fromLocal('2026-11-12', 7 * 60, -360),
      ),
    );
    await openApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Weight'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ListTile, '181.8 lb'));
    await settle(tester);
    expect(sheet(), findsOneWidget);
    expect(find.text('Edit weigh-in'), findsOneWidget);

    await sendLink(tester, 'daybook://weight');
    expect(sheet(), findsOneWidget);
    expect(find.text('Edit weigh-in'), findsOneWidget);
  });

  appTest('a save from the widget sheet shows the confirmation on Home', (
    tester,
  ) async {
    launchLink = 'daybook://weight';
    await openApp(tester);
    await settle(tester);
    await tester.enterText(find.byType(TextField), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(sheet(), findsNothing);
    expect(find.text('Weight saved: 181.8 lb, today 7:02 am'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(selectedTab(tester), 0);
  });

  for (final width in [344.0, 673.0]) {
    appTest('shell and More have no overflow at ${width.toInt()} dp', (
      tester,
    ) async {
      await openApp(tester, width: width);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final row = tester.getSize(find.widgetWithText(ListTile, 'Data check'));
      expect(row.height, greaterThanOrEqualTo(48));
      expect(row.width, lessThanOrEqualTo(600));
    });
  }
}
