// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/app_scope.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/screens/weight/weight_chart.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/screens/weight/weight_tab.dart';
import 'package:daybook/math/weight_trend.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Now at(String date, int h, int m, int offsetMinutes) =>
    Now.fromLocal(date, h * 60 + m, offsetMinutes);

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = at('2026-11-12', 7, 2, -360);

int _noOffset(DateTime local) => -360;

/// Lets a test hold a write, make it fail, or count the updates.
class Gate extends QueryInterceptor {
  Completer<void>? hold;
  bool fail = false;
  int updates = 0;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (fail) throw Exception('disk full');
    await hold?.future;
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (fail) throw Exception('disk full');
    updates++;
    await hold?.future;
    return super.runUpdate(executor, statement, args);
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late AppDatabase db;
  late Gate gate;
  late Now clockNow;

  setUp(() {
    clockNow = nowFixed;
    gate = Gate();
    db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
  });

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

  Future<void> openTab(
    WidgetTester tester, {
    Size size = const Size(400, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        db: db,
        clock: () => nowFixed,
        foodsPath: Future.value(''),
        child: const MaterialApp(
          home: Scaffold(body: WeightTab(offsetAt: _noOffset)),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> seed(
    WidgetTester tester,
    double value,
    String date,
    int h,
    int m, {
    UnitSystem units = UnitSystem.imperial,
  }) =>
      tester.runAsync(() => db.saveWeight(value, units, at(date, h, m, -360)));

  /// The wireframe's five weigh-ins, saved out of order.
  Future<void> seedWireframe(WidgetTester tester) async {
    await seed(tester, 183.1, '2026-11-10', 7, 10);
    await seed(tester, 181.8, '2026-11-08', 8, 30);
    await seed(tester, 181.8, '2026-11-12', 7, 2);
    await seed(tester, 182.1, '2026-11-09', 6, 48);
    await seed(tester, 182.4, '2026-11-11', 6, 55);
  }

  /// A row as an import would write it: straight into the table.
  Future<void> insertImported(
    WidgetTester tester,
    double kg,
    String date,
    int h,
    int m,
    String source,
    String sourceId,
  ) async {
    final when = at(date, h, m, -360);
    await tester.runAsync(
      () => db
          .into(db.weightEntries)
          .insert(
            WeightEntriesCompanion.insert(
              localDate: date,
              measuredAtMs: when.utcMs,
              tzOffsetMinutes: -360,
              weightKg: kg,
              source: Value(source),
              sourceId: Value(sourceId),
              createdAtMs: when.utcMs,
              updatedAtMs: when.utcMs,
            ),
          ),
    );
  }

  Future<List<WeightEntry>> rows(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.weightEntries).get()))!;

  WeightChartData chartData(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(WeightChart),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is WeightChartPainter,
        ),
      ),
    );
    return (paint.painter! as WeightChartPainter).data;
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  Finder field() => find.byType(TextField);
  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  Future<void> tapRow(WidgetTester tester, String when) async {
    await tester.tap(find.text(when));
    await settle(tester);
    expect(find.text('Edit weigh-in'), findsOneWidget);
  }

  appTest('the list is newest first with date, time and weight', (
    tester,
  ) async {
    await seedWireframe(tester);
    // Two on one day: the later time comes first.
    await seed(tester, 180.6, '2026-11-12', 6, 0);
    await openTab(tester);

    final order = [
      'Today, Nov 12, 7:02 am',
      'Today, Nov 12, 6:00 am',
      'Wed, Nov 11, 6:55 am',
      'Tue, Nov 10, 7:10 am',
      'Mon, Nov 9, 6:48 am',
      'Sun, Nov 8, 8:30 am',
    ];
    var previous = -1.0;
    for (final when in order) {
      final top = tester.getTopLeft(find.text(when)).dy;
      expect(top, greaterThan(previous), reason: when);
      previous = top;
    }
    expect(find.text('182.4 lb'), findsOneWidget);
    expect(find.text('183.1 lb'), findsOneWidget);
    expect(find.text('180.6 lb'), findsOneWidget);
    expect(find.text('Weigh-ins'), findsOneWidget);
    // Entered by hand: no source label.
    expect(find.textContaining('from '), findsNothing);
  });

  appTest('the big number is the trend, with the change over the range', (
    tester,
  ) async {
    await seedWireframe(tester);
    await openTab(tester);
    // 181.8, then 181.83, 181.957, 182.001, 181.981.
    expect(find.text('182.0 lb'), findsOneWidget);
    expect(find.text('Trend today'), findsOneWidget);
    expect(find.text('Up 0.2 lb in 5 days'), findsOneWidget);
  });

  appTest('an empty state when there are no weigh-ins', (tester) async {
    await openTab(tester);
    expect(
      find.text('No weigh-ins yet. Tap + Log to add one.'),
      findsOneWidget,
    );
    expect(find.byType(WeightChart), findsNothing);
    expect(find.text('Trend today'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    // The way to add one is still there.
    expect(find.text('+ Log'), findsOneWidget);
  });

  appTest('+ Log adds a weigh-in, confirms from the stored row, and Undo '
      'removes it', (tester) async {
    await openTab(tester);
    await tester.tap(find.text('+ Log'));
    await settle(tester);
    await tester.enterText(field(), '181.84');
    await tester.pump();
    await tester.tap(saveButton());
    await settle(tester);

    expect(find.text('Weight saved: 181.8 lb, today 7:02 am'), findsOneWidget);
    expect(find.text('Today, Nov 12, 7:02 am'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await rows(tester)).single.deletedAtMs, isNotNull);
    expect(
      find.text('No weigh-ins yet. Tap + Log to add one.'),
      findsOneWidget,
    );
  });

  appTest('a fast double tap on + Log opens one sheet', (tester) async {
    await openTab(tester);
    await tester.tap(find.text('+ Log'));
    await tester.tap(find.text('+ Log'), warnIfMissed: false);
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
  });

  appTest('edit saves and shows Saved, built from the stored row', (
    tester,
  ) async {
    await seedWireframe(tester);
    await openTab(tester);
    await tapRow(tester, 'Wed, Nov 11, 6:55 am');

    expect(tester.widget<TextField>(field()).controller!.text, '182.4');
    expect(find.text('Wed, Nov 11'), findsOneWidget);
    expect(find.text('6:55 am'), findsOneWidget);
    expect(
      find.text('Entered by hand. Created Nov 11, 6:55 am.'),
      findsOneWidget,
    );

    await tester.enterText(field(), '182.46');
    await tester.pump();
    await tester.tap(saveButton());
    await settle(tester);

    expect(find.byType(WeightSheet), findsNothing);
    // 182.46 is stored as 182.5, and the message says what was stored.
    expect(
      find.text('Weight saved: 182.5 lb, yesterday 6:55 am'),
      findsOneWidget,
    );
    expect(find.text('182.5 lb'), findsOneWidget);
    expect(find.text('182.4 lb'), findsNothing);
    final all = await rows(tester);
    expect(all.length, 5);
    final edited = all.firstWhere((r) => r.localDate == '2026-11-11');
    expect(edited.weightKg, lbToKg(182.5));
    expect(edited.updatedAtMs, nowFixed.utcMs);
    expect(edited.createdAtMs, at('2026-11-11', 6, 55, -360).utcMs);
    expect(edited.localDate, '2026-11-11');
  });

  appTest('an edit that changes only the time leaves weight_kg bit '
      'identical', (tester) async {
    // 82.37 kg shows as 181.6 lb. Typing that back would store 82.373...
    await insertImported(
      tester,
      82.37,
      '2026-11-11',
      6,
      55,
      'health_connect',
      'abc',
    );
    await openTab(tester);
    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    expect(tester.widget<TextField>(field()).controller!.text, '181.6');

    await tester.tap(find.text('6:55 am'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final boxes = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(boxes.at(0), '9');
    await tester.enterText(boxes.at(1), '30');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('9:30 am'), findsOneWidget);

    await tester.tap(saveButton());
    await settle(tester);

    final stored = (await rows(tester)).single;
    expect(stored.weightKg, 82.37);
    expect(stored.localDate, '2026-11-11');
    expect(stored.measuredAtMs, at('2026-11-11', 9, 30, -360).utcMs);
    expect(stored.source, 'health_connect');
    expect(
      find.text('Weight saved: 181.6 lb, yesterday 9:30 am'),
      findsOneWidget,
    );
  });

  appTest('delete removes the row at once with Undo and no popup, and Undo '
      'brings it back', (tester) async {
    await seedWireframe(tester);
    await openTab(tester);
    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    await tester.tap(find.text('Delete'));
    await settle(tester);

    // Gone from the list at once, with no dialog of any kind.
    expect(find.byType(WeightSheet), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Wed, Nov 11, 6:55 am'), findsNothing);
    expect(find.text('Deleted 182.4 lb from Wed, Nov 11'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    final deleted = (await rows(tester))
        .firstWhere((r) => r.localDate == '2026-11-11');
    expect(deleted.deletedAtMs, nowFixed.utcMs);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('Wed, Nov 11, 6:55 am'), findsOneWidget);
    expect(find.text('182.4 lb'), findsOneWidget);
    final back = (await rows(tester))
        .firstWhere((r) => r.localDate == '2026-11-11');
    expect(back.deletedAtMs, isNull);
  });

  appTest('the trend number changes after a delete and comes back with '
      'Undo', (tester) async {
    await seedWireframe(tester);
    await openTab(tester);
    expect(find.text('182.0 lb'), findsOneWidget);
    expect(find.text('Up 0.2 lb in 5 days'), findsOneWidget);

    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    await tester.tap(find.text('Delete'));
    await settle(tester);
    // Without Nov 11 the last step is 181.957 to 181.941.
    expect(find.text('181.9 lb'), findsOneWidget);
    expect(find.text('182.0 lb'), findsNothing);
    expect(find.text('Up 0.1 lb in 5 days'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(find.text('182.0 lb'), findsOneWidget);
  });

  appTest('Undo that finds the row gone says so in plain words', (
    tester,
  ) async {
    await seedWireframe(tester);
    await openTab(tester);
    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    await tester.tap(find.text('Delete'));
    await settle(tester);

    await tester.runAsync(() => db.delete(db.weightEntries).go());
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(
      find.text('Could not undo. The weigh-in is still deleted.'),
      findsOneWidget,
    );
  });

  appTest('range chips filter what the chart draws', (tester) async {
    await seed(tester, 190.0, '2025-06-01', 7, 0); // before a year
    await seed(tester, 186.0, '2026-03-01', 7, 0); // 256 days ago
    await seed(tester, 184.0, '2026-09-01', 7, 0); // 72 days ago
    await seed(tester, 183.0, '2026-10-20', 7, 0); // 23 days ago
    await seed(tester, 182.0, '2026-11-12', 7, 2); // today
    await openTab(tester);

    List<String> dates() => chartData(tester).dots.map((d) => d.date).toList();

    // 1 month is the default: today and the 29 days before.
    expect(tester.widget<ChoiceChip>(chip('1 month')).selected, isTrue);
    expect(dates(), ['2026-10-20', '2026-11-12']);
    expect(chartData(tester).startDate, '2026-10-14');
    expect(chartData(tester).endDate, '2026-11-12');
    expect(chartData(tester).trend.length, 30);
    // The trend at the left edge carries the whole history: the 10% rule over
    // all five weigh-ins, as of Sep 1, the last one before the range starts.
    // A trend computed only over the visible days would start at 183.0.
    final full = weightTrend([
      (localDate: '2025-06-01', kg: lbToKg(190.0)),
      (localDate: '2026-03-01', kg: lbToKg(186.0)),
      (localDate: '2026-09-01', kg: lbToKg(184.0)),
      (localDate: '2026-10-20', kg: lbToKg(183.0)),
      (localDate: '2026-11-12', kg: lbToKg(182.0)),
    ]);
    final beforeStart = full.firstWhere((p) => p.localDate == '2026-09-01');
    final edge = kgToWeight(beforeStart.trendKg, UnitSystem.imperial);
    expect(chartData(tester).trend.first.date, '2026-10-14');
    expect(chartData(tester).trend.first.value, edge);
    expect(edge, isNot(183.0));
    expect(edge, greaterThan(186.0)); // still pulled up by the older weights

    await tester.tap(chip('3 months'));
    await tester.pump();
    expect(tester.widget<ChoiceChip>(chip('3 months')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(chip('1 month')).selected, isFalse);
    expect(dates(), ['2026-09-01', '2026-10-20', '2026-11-12']);
    expect(chartData(tester).startDate, '2026-08-15');

    await tester.tap(chip('1 year'));
    await tester.pump();
    expect(dates(), ['2026-03-01', '2026-09-01', '2026-10-20', '2026-11-12']);
    expect(chartData(tester).trend.length, 365);

    await tester.tap(chip('All'));
    await tester.pump();
    expect(dates(), [
      '2025-06-01',
      '2026-03-01',
      '2026-09-01',
      '2026-10-20',
      '2026-11-12',
    ]);
    expect(chartData(tester).startDate, '2025-06-01');

    // The list is not filtered by the chips.
    expect(find.text('Sun, Jun 1, 2025, 7:00 am'), findsOneWidget);
    // The trend number does not depend on the range.
    expect(chartData(tester).trend.last.date, '2026-11-12');
  });

  /// The whole app, with a clock a test can move.
  Future<void> openShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DaybookApp(db: db, clock: () => clockNow, foodsPath: Future.value('')),
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Weight'));
    await settle(tester);
  }

  appTest('the Weight tab follows the clock when the app resumes', (
    tester,
  ) async {
    await seed(tester, 181.8, '2026-11-12', 7, 2);
    await seed(tester, 182.4, '2026-11-11', 6, 55);
    await openShell(tester);
    expect(find.text('Today, Nov 12, 7:02 am'), findsOneWidget);
    expect(chartData(tester).endDate, '2026-11-12');
    expect(chartData(tester).startDate, '2026-10-14');

    clockNow = at('2026-11-13', 0, 30, -360);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Thu, Nov 12, 7:02 am'), findsOneWidget);
    expect(find.text('Today, Nov 12, 7:02 am'), findsNothing);
    expect(chartData(tester).endDate, '2026-11-13');
    expect(chartData(tester).startDate, '2026-10-15');
  });

  appTest('the delete message does not follow the user to another tab', (
    tester,
  ) async {
    await seedWireframe(tester);
    await openShell(tester);
    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.text('Deleted 182.4 lb from Wed, Nov 11'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await settle(tester);
    expect(find.text('Deleted 182.4 lb from Wed, Nov 11'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    // Home's action bar is not covered: the Weight button opens the sheet.
    await tester.tap(find.widgetWithText(FilledButton, 'Weight'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
  });

  appTest('the chart says in words what it shows', (tester) async {
    final handle = tester.ensureSemantics();
    await seedWireframe(tester);
    await openTab(tester);
    expect(
      find.bySemanticsLabel(
        'Weight, Oct 14 to Nov 12. Trend from 181.8 to 182.0 lb.',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Dots: weigh-ins. Line: trend, labeled with today's value."),
      findsOneWidget,
    );
    handle.dispose();
  });

  test('chart data: the trend has one point a day and stays flat between '
      'weigh-ins', () async {
    final tdb = db;
    addTearDown(tdb.close);
    await tdb.saveWeight(
      100,
      UnitSystem.metric,
      at('2026-11-01', 7, 0, 0),
      at: at('2026-11-01', 7, 0, 0),
    );
    await tdb.saveWeight(
      90,
      UnitSystem.metric,
      at('2026-11-04', 7, 0, 0),
      at: at('2026-11-04', 7, 0, 0),
    );
    final list = await tdb.select(tdb.weightEntries).get();
    final data = buildChartData(
      rows: list.reversed.toList(),
      today: '2026-11-06',
      rangeDays: 30,
      units: UnitSystem.metric,
    )!;
    expect(data.dots.map((d) => d.value), [100.0, 90.0]);
    expect(data.trend.first.date, '2026-11-01');
    expect(data.trend.last.date, '2026-11-06');
    expect(data.trend.length, 6);
    expect(data.trend[1].value, 100.0);
    expect(data.trend[2].value, 100.0);
    expect(data.trend[3].value, 99.0); // 100 moves 10% toward 90
    expect(data.trend[5].value, 99.0);
    expect(
      buildChartData(
        rows: const [],
        today: '2026-11-06',
        rangeDays: null,
        units: UnitSystem.metric,
      ),
      isNull,
    );
  });

  appTest('imported rows carry a source label', (tester) async {
    await insertImported(
      tester,
      82.5,
      '2026-11-12',
      6,
      30,
      'health_connect',
      'hc-1',
    );
    await insertImported(
      tester,
      82.0,
      '2026-11-11',
      6,
      30,
      'apple_health',
      'ah-1',
    );
    await seed(tester, 181.8, '2026-11-10', 7, 10);
    await openTab(tester);

    expect(find.text('from Health Connect'), findsOneWidget);
    expect(find.text('from Apple Health'), findsOneWidget);
    // The hand entered row has none.
    expect(find.textContaining('from '), findsNWidgets(2));

    await tapRow(tester, 'Today, Nov 12, 6:30 am');
    expect(
      find.text('From Health Connect. Created Nov 12, 6:30 am.'),
      findsOneWidget,
    );
  });

  appTest('metric shows kg on the list, the trend and the sheet', (
    tester,
  ) async {
    await tester.runAsync(() => db.setUnits(UnitSystem.metric));
    await seed(tester, 82.5, '2026-11-11', 6, 55, units: UnitSystem.metric);
    await seed(tester, 81.9, '2026-11-12', 7, 2, units: UnitSystem.metric);
    await openTab(tester);
    expect(find.text('81.9 kg'), findsOneWidget);
    expect(find.text('82.5 kg'), findsOneWidget);
    expect(find.textContaining(' lb'), findsNothing);
    // The trend goes 82.5, then 82.44 (shown 82.4).
    expect(find.text('82.4 kg'), findsOneWidget);
    expect(find.text('Down 0.1 kg in 2 days'), findsOneWidget);

    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    expect(find.text('kg'), findsOneWidget);
    expect(tester.widget<TextField>(field()).controller!.text, '82.5');
  });

  appTest('a failing edit keeps the sheet open and the list as it was', (
    tester,
  ) async {
    await seedWireframe(tester);
    await openTab(tester);
    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    gate.fail = true;
    await tester.enterText(field(), '190.2');
    await tester.pump();
    await tester.tap(saveButton());
    await settle(tester);

    expect(find.byType(WeightSheet), findsOneWidget);
    expect(tester.widget<TextField>(field()).controller!.text, '190.2');
    expect(
      find.text(
        'Could not save. Your 190.2 lb is still here. Tap Save to try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Weight saved'), findsNothing);
    gate.fail = false;
    final stored = (await rows(tester))
        .firstWhere((r) => r.localDate == '2026-11-11');
    expect(stored.weightKg, lbToKg(182.4));
  });

  appTest('a weigh-in deleted elsewhere while its sheet is open gives a plain '
      'message', (tester) async {
    await seedWireframe(tester);
    await openTab(tester);
    await tapRow(tester, 'Wed, Nov 11, 6:55 am');
    await tester.runAsync(() => db.delete(db.weightEntries).go());
    await settle(tester);

    await tester.tap(saveButton());
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
    expect(
      find.text('That weigh-in is no longer in your list.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [344.0, 673.0]) {
    appTest('layout has no overflow at ${width.toInt()} dp, targets are at '
        'least 48 dp', (tester) async {
      await seedWireframe(tester);
      await insertImported(
        tester,
        82.0,
        '2026-11-07',
        6,
        30,
        'health_connect',
        'hc-1',
      );
      await openTab(tester, size: Size(width, 900));
      expect(tester.takeException(), isNull);

      final content = tester.getSize(find.byType(WeightChart)).width;
      expect(content, lessThanOrEqualTo(600));
      for (final f in [
        find.widgetWithText(FilledButton, '+ Log'),
        chip('1 month'),
        chip('3 months'),
        chip('1 year'),
        chip('All'),
        find.byType(ListTile).first,
        find.byType(ListTile).last,
      ]) {
        final s = tester.getSize(f);
        expect(s.height, greaterThanOrEqualTo(48));
        expect(s.width, greaterThanOrEqualTo(48));
      }

      await tapRow(tester, 'Wed, Nov 11, 6:55 am');
      expect(tester.takeException(), isNull);
    });
  }

  appTest('large text does not overflow at 344 dp', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedWireframe(tester);
    await openTab(tester, size: const Size(344, 900));
    expect(tester.takeException(), isNull);
    await tester.tap(chip('All'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Scroll to the rows and open one.
    await tester.scrollUntilVisible(
      find.text('Today, Nov 12, 7:02 am'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Today, Nov 12, 7:02 am'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Today, Nov 12, 7:02 am'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
