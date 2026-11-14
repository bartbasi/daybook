// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/screens/goals/goals_screen.dart';
import 'package:daybook/strings.dart';
import 'package:daybook/screens/food/food_entry_screen.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/screens/weight/weight_tab.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// While set, a read whose statement contains this text fails.
  String? failReadsOf;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await holdReads?.future;
    final bad = failReadsOf;
    if (bad != null && statement.contains(bad)) throw StateError('read failed');
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
      // The home_widget plugin has no handler in tests. Answer its channels.
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (call) async => null,
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
    expect(find.text('No weight yet.'), findsOneWidget);

    expect(find.text('+ Food'), findsOneWidget);
    expect(find.text('Cardio'), findsOneWidget);
    final food = tester.widget<FilledButton>(barButton('+ Food'));
    expect(food.onPressed, isNotNull);
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
    expect(find.text('No weight yet.'), findsNothing);
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
    gate.holdReads!.complete();
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);

    // One tap on the scrim leaves no second sheet underneath.
    await tester.tapAt(const Offset(200, 20));
    await settle(tester);
    expect(find.byType(WeightSheet), findsNothing);

    // Closed again, it can be opened again.
    await tester.tap(barButton('Weight'));
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

  appTest('tapping the weight row opens the Weight tab, and the Weight '
      'button opens the sheet', (tester) async {
    await seed(tester, 182.4, UnitSystem.imperial, nowFixed);
    await openApp(tester);
    await tester.tap(find.text('182.4 lb'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    expect(find.byType(WeightTab), findsOneWidget);
    expect(find.text('Weigh-ins'), findsOneWidget);

    // Back on Today, the Weight button still opens the sheet.
    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await settle(tester);
    await tester.tap(barButton('Weight'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsOneWidget);
  });

  appTest('the empty weight row also opens the Weight tab', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('No weight yet.'));
    await settle(tester);
    expect(find.byType(WeightSheet), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    expect(
      find.text('No weigh-ins yet. Tap + Log to add one.'),
      findsOneWidget,
    );
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
    expect(find.text('No weight yet.'), findsOneWidget);
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
        find.byType(Card).last, // the weight row; the first is the goals card
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

  // The meals.

  MealLineInput line(String name, double kcal, {String ref = 'usda:1'}) =>
      MealLineInput(
        foodRef: ref,
        foodName: name,
        quantity: 1,
        unitLabel: '',
        baseQuantity: 100,
        baseUnit: 'g',
        nutrients: {Nutrients.energy: kcal, Nutrients.protein: 5},
      );

  Future<StoredMeal> seedMeal(
    WidgetTester tester,
    String date,
    int slotId,
    List<MealLineInput> lines,
  ) => tester
      .runAsync(
        () => db.saveMeal(
          now: nowFixed,
          localDate: date,
          slotId: slotId,
          lines: lines,
        ),
      )
      .then((m) => m!);

  appTest('Home lists every meal with its kcal and foods in brief, and a '
      'meal with nothing says so', (tester) async {
    await seedMeal(tester, '2026-11-12', 1, [
      line('Egg, whole, cooked, NS as to cooking method', 176),
      line('Bread, sour dough, toasted', 167),
    ]);
    await seedMeal(tester, '2026-11-11', 2, [line('Yesterday food', 999)]);
    await openApp(tester);
    expect(find.text('Meals'), findsOneWidget);
    for (final slot in ['Breakfast', 'Lunch', 'Dinner', 'Snack']) {
      expect(find.text(slot), findsOneWidget, reason: slot);
    }
    expect(find.text('343 kcal'), findsOneWidget);
    expect(find.text('Egg, Bread'), findsOneWidget);
    // Lunch, Dinner and Snack: nothing logged today.
    expect(find.text('Nothing yet. Tap to add.'), findsNWidgets(3));
    expect(find.text('Yesterday food'), findsNothing);
  });

  appTest('a day with two meals in one slot lists both', (tester) async {
    await seedMeal(tester, '2026-11-12', 1, [line('Apple, raw', 95)]);
    await seedMeal(tester, '2026-11-12', 1, [line('Banana, raw', 105)]);
    await openApp(tester);
    expect(find.text('Breakfast'), findsNWidgets(2));
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Nothing yet. Tap to add.'), findsNWidgets(3));
  });

  appTest('+ Food opens the food screen, and a fast double tap opens one', (
    tester,
  ) async {
    await openApp(tester);
    await tester.tap(barButton('+ Food'));
    await tester.tap(barButton('+ Food'), warnIfMissed: false);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FoodEntryScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing); // a full screen
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FoodEntryScreen), findsNothing);
    expect(find.text('Thursday, Nov 12'), findsOneWidget);
  });

  appTest('tapping a meal opens it for editing, with its entries as added '
      'lines', (tester) async {
    await seedMeal(tester, '2026-11-12', 1, [line('Apple, raw', 95)]);
    await openApp(tester);
    await tester.tap(find.text('Apple'));
    await settle(tester);
    expect(find.byType(FoodEntryScreen), findsOneWidget);
    expect(find.text('Editing Breakfast'), findsOneWidget);
    expect(find.text('Apple, raw'), findsOneWidget);
  });

  appTest('tapping an empty meal opens the food screen with that meal '
      'picked', (tester) async {
    await openApp(tester);
    // The second "Dinner" is the empty row; the chips are not drawn yet.
    await tester.tap(find.text('Dinner'));
    await settle(tester);
    expect(find.byType(FoodEntryScreen), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dinner'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Breakfast'))
          .selected,
      isFalse,
    );
  });

  appTest('the meals follow the day when the app resumes after midnight', (
    tester,
  ) async {
    await seedMeal(tester, '2026-11-12', 1, [line('Apple, raw', 95)]);
    await seedMeal(tester, '2026-11-13', 2, [line('Soup', 200)]);
    await openApp(tester);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Soup'), findsNothing);

    clockNow = at('2026-11-13', 0, 30, -360);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('Friday, Nov 13'), findsOneWidget);
    expect(find.text('Soup'), findsOneWidget);
    expect(find.text('Apple'), findsNothing);
  });

  for (final width in [344.0, 673.0]) {
    appTest('meal rows have no overflow at ${width.toInt()} dp and at 2x '
        'text, and are at least 48 dp tall', (tester) async {
      await seedMeal(tester, '2026-11-12', 1, [
        line('Egg, whole, cooked, NS as to cooking method', 176),
        line('Bread, sour dough, toasted', 167),
        line('Butter, NFS', 104),
        line('Coffee, NS as to type', 4),
        line('Cream, half and half', 39),
      ]);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(tester, size: Size(width, 700));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Egg, Bread, Butter, Coffee, Cream'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      final row = find.ancestor(
        of: find.text('Egg, Bread, Butter, Coffee, Cream'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.scrollUntilVisible(
        find.text('Nothing yet. Tap to add.').first,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      final empty = find.ancestor(
        of: find.text('Nothing yet. Tap to add.').first,
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(empty).height, greaterThanOrEqualTo(48));
    });
  }

  appTest('a double tap on Undo after a weight save marks it deleted once and '
      'shows no false failure', (tester) async {
    await openApp(tester);
    await tester.tap(barButton('Weight'));
    await settle(tester);
    await tester.enterText(field(), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await tester.tap(find.text('Undo'));
    await tester.tap(find.text('Undo'), warnIfMissed: false);
    await settle(tester);
    expect(find.textContaining('Could not undo'), findsNothing);
    expect((await rows(tester)).single.deletedAtMs, isNotNull);
  });

  // The budget card and the macro meters (task 3.2).

  final nov8 = at('2026-11-08', 8, 15, -360);

  /// Own calorie goal [kcal] from [from], with the macros.
  Future<void> seedGoals(
    WidgetTester tester, {
    int kcal = 2138,
    int addBack = 100,
    Now? from,
    MacroMode mode = MacroMode.grams,
    double p = 150,
    double c = 227,
    double f = 70,
  }) => tester.runAsync(
    () => db.saveGoals(
      GoalInput(
        activity: ActivityLevel.lightlyActive,
        rate: WeeklyRate.stay,
        ownCalories: kcal,
        addBackPercent: addBack,
        macroMode: mode,
        protein: p,
        carbs: c,
        fat: f,
      ),
      from ?? nov8,
    ),
  );

  Future<void> seedRun(WidgetTester tester, double kcal) => tester.runAsync(
    () => db
        .into(db.cardioSessions)
        .insert(
          CardioSessionsCompanion.insert(
            localDate: '2026-11-12',
            startedAtMs: nowFixed.utcMs,
            tzOffsetMinutes: -360,
            activityName: 'Running',
            durationSeconds: 1800,
            kcalEstimated: Value(kcal),
          ),
        ),
  );

  MealLineInput macroLine(double kcal, double p, double c, double f) =>
      MealLineInput(
        foodRef: 'usda:1',
        foodName: 'Food',
        quantity: 1,
        unitLabel: '',
        baseQuantity: 100,
        baseUnit: 'g',
        nutrients: {
          Nutrients.energy: kcal,
          Nutrients.protein: p,
          Nutrients.carbs: c,
          Nutrients.fat: f,
        },
      );

  Future<void> sampleDay(WidgetTester tester) async {
    await seedMeal(tester, '2026-11-12', 1, [macroLine(490, 20, 34, 30)]);
    await seedMeal(tester, '2026-11-12', 2, [macroLine(775, 66, 86, 18.5)]);
    await seedRun(tester, 383);
  }

  appTest('before goals exist Home shows the Set your goals card, no '
      'budget, and the card opens Goals', (tester) async {
    await openApp(tester);
    expect(find.text('Set your goals'), findsOneWidget);
    expect(
      find.text('Work out how much you can eat each day.'),
      findsOneWidget,
    );
    expect(find.text('kcal left'), findsNothing);
    expect(find.text('Protein'), findsNothing);
    await tester.tap(find.text('Set your goals'));
    await settle(tester);
    expect(find.byType(GoalsScreen), findsOneWidget);
    // Saving there makes the card go away and the budget come up.
    await tester.ensureVisible(find.text('Use my own calorie goal instead'));
    await tester.pump();
    await tester.tap(find.text('Use my own calorie goal instead'));
    await tester.pump();
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Calories a day',
      ),
      '1800',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Set your goals'), findsNothing);
    expect(find.text('1,800'), findsOneWidget);
    expect(find.text('Goal 1,800 + exercise 0 - food 0'), findsOneWidget);
  });

  appTest('morning with nothing eaten: the whole goal is left and the '
      'meters are empty (frame 1)', (tester) async {
    await seedGoals(tester);
    await openApp(tester);
    expect(find.text('2,138'), findsOneWidget);
    expect(find.text('kcal left'), findsOneWidget);
    expect(find.text('Goal 2,138 + exercise 0 - food 0'), findsOneWidget);
    expect(find.text('Set your goals'), findsNothing);
    expect(find.text('0 of 150 g'), findsOneWidget);
    expect(find.text('0 of 227 g'), findsOneWidget);
    expect(find.text('0 of 70 g'), findsOneWidget);
  });

  appTest('with two meals and a run the line is goal + exercise - food, '
      'built from the shown parts (2,138 + 383 - 1,265 = 1,256)', (
    tester,
  ) async {
    await seedGoals(tester);
    await sampleDay(tester);
    await openApp(tester);
    expect(find.text('1,256'), findsOneWidget);
    expect(find.text('kcal left'), findsOneWidget);
    expect(find.text('Goal 2,138 + exercise 383 - food 1,265'), findsOneWidget);
    // The meters: fat is 48.5, shown as 49.
    expect(find.text('86 of 150 g'), findsOneWidget);
    expect(find.text('120 of 227 g'), findsOneWidget);
    expect(find.text('49 of 70 g'), findsOneWidget);
    final meters = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((m) => m.value!)
        .toList();
    expect(meters[0], closeTo(86 / 150, 0.005));
    expect(meters[1], closeTo(120 / 227, 0.005));
    expect(meters[2], closeTo(48.5 / 70, 0.005));
  });

  appTest('the line always adds up even when the parts round: 191.5 and '
      '1,265.4 show as 192 and 1,265, and left is 1,065', (tester) async {
    await seedGoals(tester, addBack: 50);
    await seedMeal(tester, '2026-11-12', 1, [macroLine(1265.4, 20, 34, 30)]);
    await seedRun(tester, 383);
    await openApp(tester);
    expect(find.text('Goal 2,138 + exercise 192 - food 1,265'), findsOneWidget);
    expect(find.text('1,065'), findsOneWidget);
  });

  for (final (percent, shown) in [(0, 0), (50, 192), (100, 383)]) {
    appTest('add-back $percent% puts $shown in the line, and the left '
        'number follows', (tester) async {
      await seedGoals(tester, addBack: percent);
      await seedMeal(tester, '2026-11-12', 1, [macroLine(1000, 20, 34, 30)]);
      await seedRun(tester, 383);
      await openApp(tester);
      expect(
        find.text('Goal 2,138 + exercise $shown - food 1,000'),
        findsOneWidget,
      );
      expect(find.text(S.count(2138 + shown - 1000)), findsOneWidget);
    });
  }

  appTest('over budget is said in words, with no minus sign', (tester) async {
    await seedGoals(tester);
    await seedMeal(tester, '2026-11-12', 1, [macroLine(2290, 120, 300, 90)]);
    await openApp(tester);
    expect(find.text('152'), findsOneWidget);
    expect(find.text('kcal over'), findsOneWidget);
    expect(find.text('kcal left'), findsNothing);
    expect(find.text('Goal 2,138 + exercise 0 - food 2,290'), findsOneWidget);
    expect(find.textContaining('-152'), findsNothing);
    // A macro past its goal says so in words too.
    expect(find.text('120 of 150 g'), findsOneWidget);
    expect(find.text('300 of 227 g, over'), findsOneWidget);
    expect(find.text('90 of 70 g, over'), findsOneWidget);
  });

  appTest('percent macros show the grams the goal gives', (tester) async {
    await seedGoals(tester, mode: MacroMode.percent, p: 30, c: 40, f: 30);
    await openApp(tester);
    expect(find.text('0 of 160 g'), findsOneWidget);
    expect(find.text('0 of 214 g'), findsOneWidget);
    expect(find.text('0 of 71 g'), findsOneWidget);
  });

  appTest('goals with no macros show the budget and no meters', (tester) async {
    await tester.runAsync(
      () => db.saveGoals(
        const GoalInput(
          activity: ActivityLevel.lightlyActive,
          rate: WeeklyRate.stay,
          ownCalories: 2138,
        ),
        nov8,
      ),
    );
    await openApp(tester);
    expect(find.text('2,138'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  appTest("Home on an earlier day uses that day's goals", (tester) async {
    await seedGoals(tester, kcal: 2000);
    await seedGoals(tester, kcal: 2138, from: at('2026-11-12', 6, 0, -360));
    clockNow = at('2026-11-10', 9, 0, -360);
    await openApp(tester);
    expect(find.text('2,000'), findsOneWidget);
    expect(find.text('Goal 2,000 + exercise 0 - food 0'), findsOneWidget);
  });

  appTest("past midnight Home reads the new day's goals", (tester) async {
    await seedGoals(tester, kcal: 2138);
    await seedGoals(tester, kcal: 1900, from: at('2026-11-13', 0, 0, -360));
    clockNow = at('2026-11-12', 23, 59, -360);
    await openApp(tester);
    expect(find.text('2,138'), findsOneWidget);
    clockNow = at('2026-11-13', 1, 0, -360);
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(find.text('1,900'), findsOneWidget);
    expect(find.text('2,138'), findsNothing);
  });

  appTest('a new meal changes the card at once', (tester) async {
    await seedGoals(tester);
    await openApp(tester);
    expect(find.text('2,138'), findsOneWidget);
    await seedMeal(tester, '2026-11-12', 1, [macroLine(500, 20, 34, 30)]);
    await settle(tester);
    expect(find.text('1,638'), findsOneWidget);
  });

  for (final width in [344.0, 673.0]) {
    appTest('the budget card and meters at ${width.toInt()} dp and text x2 '
        'have no overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await seedGoals(tester);
      await sampleDay(tester);
      await openApp(tester, size: Size(width, 800));
      expect(tester.takeException(), isNull);
      expect(find.text('1,256'), findsOneWidget);
      for (final t in ['86 of 150 g', '120 of 227 g', '49 of 70 g']) {
        expect(find.text(t), findsOneWidget);
      }
    });
  }

  appTest('the Set your goals card is a 48 dp target at 344 dp and text x2', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openApp(tester, size: const Size(344, 700));
    expect(tester.takeException(), isNull);
    final s = tester.getSize(
      find
          .ancestor(
            of: find.text('Set your goals'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(s.height, greaterThanOrEqualTo(48));
  });

  appTest('a screen reader gets the number and the meters in one order, '
      'each meter in words', (tester) async {
    final semantics = tester.ensureSemantics();
    await seedGoals(tester);
    await sampleDay(tester);
    await openApp(tester);
    final card = find.bySemanticsLabel(
      '1,256 kcal left. Goal 2,138 plus exercise 383 minus food 1,265.',
    );
    expect(card, findsOneWidget);
    final protein = find.bySemanticsLabel('Protein, 86 of 150 grams');
    final carbs = find.bySemanticsLabel('Carbs, 120 of 227 grams');
    final fat = find.bySemanticsLabel('Fat, 49 of 70 grams');
    expect(protein, findsOneWidget);
    expect(carbs, findsOneWidget);
    expect(fat, findsOneWidget);
    // Top to bottom, then left to right: the card, then the three meters.
    final c = tester.getRect(card);
    final p = tester.getRect(protein);
    expect(p.top, greaterThanOrEqualTo(c.bottom - 1));
    expect(tester.getRect(carbs).left, greaterThan(p.left));
    expect(tester.getRect(fat).left, greaterThan(tester.getRect(carbs).left));
    semantics.dispose();
  });

  // Streams and scrolling (review round for task 3.2).

  Future<void> deleteAllGoals(WidgetTester tester) async {
    await tester.runAsync(() => db.delete(db.goals).go());
    await settle(tester);
  }

  appTest('goals saved, deleted in the database and saved again: the budget '
      'and the meters come back and nothing is thrown', (tester) async {
    await openApp(tester);
    expect(find.text('Set your goals'), findsOneWidget);
    await seedGoals(tester);
    await settle(tester);
    expect(find.text('0 of 150 g'), findsOneWidget);
    expect(find.text('Set your goals'), findsNothing);

    await deleteAllGoals(tester);
    expect(find.text('Set your goals'), findsOneWidget);
    expect(find.text('0 of 150 g'), findsNothing);
    expect(tester.takeException(), isNull);

    await seedGoals(tester);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Set your goals'), findsNothing);
    expect(find.text('2,138'), findsOneWidget);
    expect(find.text('0 of 150 g'), findsOneWidget);
    expect(find.text('0 of 227 g'), findsOneWidget);
    expect(find.text('0 of 70 g'), findsOneWidget);
  });

  appTest('the only weigh-in deleted and another logged: the weight row '
      'comes back and nothing is thrown', (tester) async {
    await seed(
      tester,
      182.4,
      UnitSystem.imperial,
      at('2026-11-11', 6, 55, -360),
    );
    await openApp(tester);
    await settle(tester);
    expect(find.text('182.4 lb'), findsOneWidget);
    await tester.runAsync(() => db.delete(db.weightEntries).go());
    await settle(tester);
    expect(find.text('No weight yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await seed(tester, 181.8, UnitSystem.imperial, nowFixed);
    await settle(tester);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('181.8 lb'), findsOneWidget);
    expect(find.textContaining('Trend'), findsOneWidget);
  });

  appTest('scrolled far down and back at 344 dp and text x2, every card is '
      'there again and nothing is thrown', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedGoals(tester);
    await sampleDay(tester);
    await seed(
      tester,
      182.4,
      UnitSystem.imperial,
      at('2026-11-11', 6, 55, -360),
    );
    await openApp(tester, size: const Size(344, 700));
    await settle(tester);
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -3000));
    await tester.pump();
    await tester.drag(list, const Offset(0, -3000));
    await tester.pump();
    await tester.drag(list, const Offset(0, 5000));
    await tester.pump();
    await tester.drag(list, const Offset(0, 5000));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('1,256'), findsOneWidget);
    for (final t in ['86 of 150 g', '120 of 227 g', '49 of 70 g']) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.drag(list, const Offset(0, -3000));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('182.4 lb'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
  });

  appTest('a budget read that fails says so in plain words and never '
      '"Set your goals"; the next good read brings the card back', (
    tester,
  ) async {
    await seedGoals(tester);
    await openApp(tester);
    expect(find.text('2,138'), findsOneWidget);

    gate.failReadsOf = 'goals';
    await seedMeal(tester, '2026-11-12', 1, [macroLine(500, 20, 34, 30)]);
    await settle(tester);
    expect(find.text(S.homeBudgetFailed), findsOneWidget);
    expect(find.text('Set your goals'), findsNothing);
    expect(find.text('kcal left'), findsNothing);

    gate.failReadsOf = null;
    await seedMeal(tester, '2026-11-12', 2, [macroLine(100, 5, 5, 5)]);
    await settle(tester);
    expect(find.text(S.homeBudgetFailed), findsNothing);
    expect(find.text('1,538'), findsOneWidget);
  });
}
