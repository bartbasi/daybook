// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Now at(String date, int h, int m, int offsetMinutes) =>
    Now.fromLocal(date, h * 60 + m, offsetMinutes);

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = at('2026-11-12', 7, 2, -360);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Lets a test hold a database write, or the reads the weight sheet makes.
class Gate extends QueryInterceptor {
  Completer<void>? hold;
  Completer<void>? holdReads;
  Completer<void>? holdUnits;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await holdReads?.future;
    if (statement.contains('settings')) await holdUnits?.future;
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await hold?.future;
    return super.runInsert(executor, statement, args);
  }
}

void main() {
  late AppDatabase db;
  late Gate gate;
  late Now clockNow;

  setUp(() {
    gate = Gate();
    clockNow = nowFixed;
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

  Future<void> openApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DaybookApp(db: db, clock: () => clockNow, foodsPath: Future.value('')),
    );
    await settle(tester);
  }

  Future<void> seed(
    WidgetTester tester,
    double value,
    UnitSystem units,
    Now when,
  ) async {
    await tester.runAsync(() => db.saveWeight(value, units, when));
  }

  Finder barButton(String label) => find.widgetWithText(FilledButton, label);
  Finder field() => find.byType(TextField);
  Future<List<WeightEntry>> rows(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.weightEntries).get()))!;

  appTest('shows today, the empty weight row and the action bar', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.text('Thursday, Nov 12'), findsOneWidget);
    expect(find.text('No weight yet. Tap to add.'), findsOneWidget);

    expect(find.text('+ Food'), findsOneWidget);
    expect(find.text('Cardio'), findsOneWidget);
    final food = tester.widget<FilledButton>(barButton('+ Food'));
    expect(food.onPressed, isNull);
    final cardio = tester.widget<FilledButton>(barButton('Cardio'));
    expect(cardio.onPressed, isNull);
    final weight = tester.widget<FilledButton>(barButton('Weight'));
    expect(weight.onPressed, isNotNull);
    expect(find.textContaining('oon'), findsNothing);
  });

  appTest('the weight row shows the latest weight and the trend', (
    tester,
  ) async {
    await seed(
      tester,
      182.4,
      UnitSystem.imperial,
      at('2026-11-11', 6, 55, -360),
    );
    await seed(
      tester,
      181.8,
      UnitSystem.imperial,
      at('2026-11-12', 7, 2, -360),
    );
    await openApp(tester);
    expect(find.text('181.8 lb'), findsOneWidget);
    expect(find.text('Today, 7:02 am'), findsOneWidget);
    // 182.4 moves 10% of the way to 181.8: 182.34, shown as 182.3.
    await settle(tester); // the trend stream starts after the weights arrive
    expect(find.text('Trend 182.3 lb'), findsOneWidget);
    expect(find.text('No weight yet. Tap to add.'), findsNothing);
  });

  appTest('a metric user never sees lb while Home loads', (tester) async {
    await tester.runAsync(() => db.setUnits(UnitSystem.metric));
    await seed(tester, 82.5, UnitSystem.metric, at('2026-11-11', 6, 55, -360));
    // The weights arrive first and the units setting is slow.
    gate.holdUnits = Completer<void>();
    await openApp(tester);
    await settle(tester);
    expect(find.textContaining(' lb'), findsNothing);
    expect(find.textContaining('82.5'), findsNothing);

    gate.holdUnits!.complete();
    await settle(tester);
    expect(find.text('82.5 kg'), findsOneWidget);
    expect(find.textContaining(' lb'), findsNothing);
  });

  appTest('Home follows the clock past midnight when the app resumes', (
    tester,
  ) async {
    await seed(tester, 181.8, UnitSystem.imperial, nowFixed);
    await openApp(tester);
    expect(find.text('Thursday, Nov 12'), findsOneWidget);
    expect(find.text('Today, 7:02 am'), findsOneWidget);

    clockNow = at('2026-11-13', 0, 30, -360);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Friday, Nov 13'), findsOneWidget);
    expect(find.text('Yesterday, 7:02 am'), findsOneWidget);
  });

  appTest('a fast double tap on Weight opens one sheet', (tester) async {
    await openApp(tester);
    // The sheet reads the units and the last weight before it shows. Hold
    // those reads so the second tap lands while the first is still opening.
    gate.holdReads = Completer<void>();
    await tester.tap(barButton('Weight'));
    await tester.tap(barButton('Weight'));
    await tester.tap(find.text('No weight yet. Tap to add.'));
    gate.holdReads!.complete();
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);

    // One tap on the scrim leaves no second sheet underneath.
    await tester.tapAt(const Offset(200, 20));
    await settle(tester);
    expect(find.byType(WeightSheet), findsNothing);

    // Closed again, it can be opened again.
    await tester.tap(find.text('No weight yet. Tap to add.'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
  });

  appTest('the sheet cannot be closed while the save is in flight, and Home '
      'then shows the confirmation', (tester) async {
    await openApp(tester);
    await tester.tap(barButton('Weight'));
    await settle(tester);
    gate.hold = Completer<void>();
    await tester.enterText(field(), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    await tester.tapAt(const Offset(200, 20)); // the scrim
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
    await tester.binding.handlePopRoute(); // the back button
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
    await tester.drag(find.byType(WeightSheet), const Offset(0, 500));
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);

    gate.hold!.complete();
    await settle(tester);
    expect(find.byType(WeightSheet), findsNothing);
    expect(find.text('Weight saved: 181.8 lb, today 7:02 am'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect((await rows(tester)).length, 1);
  });

  appTest('when Undo fails the bar says the weight is still saved', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(barButton('Weight'));
    await settle(tester);
    await tester.enterText(field(), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Undo'), findsOneWidget);

    // The row is gone from the database, so marking it deleted finds nothing.
    await tester.runAsync(() => db.delete(db.weightEntries).go());
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(
      find.text('Could not undo. The weight is still saved.'),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsNothing);
  });

  appTest('metric shows kg on the row and the confirmation', (tester) async {
    await tester.runAsync(() => db.setUnits(UnitSystem.metric));
    await seed(tester, 82.5, UnitSystem.metric, at('2026-11-11', 6, 55, -360));
    await openApp(tester);
    expect(find.text('82.5 kg'), findsOneWidget);
    expect(find.text('Yesterday, 6:55 am'), findsOneWidget);

    await tester.tap(barButton('Weight'));
    await settle(tester);
    await tester.enterText(field(), '81.9');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Weight saved: 81.9 kg, today 7:02 am'), findsOneWidget);
    expect(find.text('81.9 kg'), findsOneWidget);
  });

  appTest('tapping the weight row or the Weight button opens the sheet', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(find.text('No weight yet. Tap to add.'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
    await tester.tapAt(const Offset(200, 20)); // the scrim
    await settle(tester);
    expect(find.byType(WeightSheet), findsNothing);

    await tester.tap(barButton('Weight'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
  });

  appTest('two taps: Weight, then Save, with the number already there', (
    tester,
  ) async {
    await seed(
      tester,
      182.4,
      UnitSystem.imperial,
      at('2026-11-11', 6, 55, -360),
    );
    await openApp(tester);
    await tester.tap(barButton('Weight'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect((await rows(tester)).length, 2);
    expect(find.text('Weight saved: 182.4 lb, today 7:02 am'), findsOneWidget);
  });

  appTest('after a save Home confirms from the stored row, then Undo '
      'marks it deleted', (tester) async {
    await openApp(tester);
    await tester.tap(barButton('Weight'));
    await settle(tester);
    // More digits than the database keeps: the message shows what was stored.
    await tester.enterText(field(), '181.84');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(find.byType(WeightSheet), findsNothing);
    expect(find.text('Weight saved: 181.8 lb, today 7:02 am'), findsOneWidget);
    expect(find.text('181.8 lb'), findsOneWidget); // the weight row
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    final stored = (await rows(tester)).single;
    expect(stored.deletedAtMs, nowFixed.utcMs);
    expect(find.text('Undo'), findsNothing);
    expect(find.textContaining('Weight saved'), findsNothing);
    expect(find.text('No weight yet. Tap to add.'), findsOneWidget);
  });

  appTest('the confirmation goes away after ten seconds', (tester) async {
    await openApp(tester);
    await tester.tap(barButton('Weight'));
    await settle(tester);
    await tester.enterText(field(), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.textContaining('Weight saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.textContaining('Weight saved'), findsNothing);
    expect((await rows(tester)).single.deletedAtMs, isNull);
  });

  for (final width in [344.0, 673.0]) {
    appTest('layout has no overflow at ${width.toInt()} dp', (tester) async {
      await seed(
        tester,
        182.4,
        UnitSystem.imperial,
        at('2026-11-11', 6, 55, -360),
      );
      await openApp(tester, size: Size(width, 700));
      await tester.tap(barButton('Weight'));
      await settle(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.textContaining('Weight saved'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Content stops at 600 dp; the bar's buttons are inside it.
      final bar = tester.getRect(barButton('+ Food')).left;
      final end = tester.getRect(barButton('Cardio')).right;
      expect(end - bar, lessThanOrEqualTo(600));
      for (final f in [
        barButton('+ Food'),
        barButton('Weight'),
        barButton('Cardio'),
        find.widgetWithText(TextButton, 'Undo'),
        find.byType(Card),
      ]) {
        final s = tester.getSize(f);
        expect(s.height, greaterThanOrEqualTo(48));
        expect(s.width, greaterThanOrEqualTo(48));
      }
    });
  }

  appTest('large text does not overflow at 344 dp', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seed(
      tester,
      182.4,
      UnitSystem.imperial,
      at('2026-11-11', 6, 55, -360),
    );
    await openApp(tester, size: const Size(344, 700));
    expect(tester.takeException(), isNull);
  });
}
