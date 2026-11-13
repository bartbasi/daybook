// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/screens/home/home_screen.dart';
import 'package:daybook/screens/more/more_screen.dart';
import 'package:daybook/screens/weight/weight_tab.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  /// Unmounts the app first, so drift's stream clean-up timer runs, then
  /// closes the database.
  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
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
