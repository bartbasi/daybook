// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/screens/goals/other_nutrients_screen.dart';
import 'package:daybook/strings.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Other nutrients list (task 3.2), reached from Goals. Daily Values are
// the defaults, the user's changes are kept when Goals is saved.

final nowFixed = Now.fromLocal('2026-11-12', 7 * 60 + 2, -360);
final nov8 = Now.fromLocal('2026-11-08', 8 * 60 + 15, -360);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const channels = ['home_widget', 'home_widget/updates'];
      for (final c in channels) {
        messenger.setMockMethodCallHandler(MethodChannel(c), (_) async => null);
      }
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(db.close);
        for (final c in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(c), null);
        }
      }
    });
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> openList(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    await real(tester, () async {
      await db.saveWeight(181.8, UnitSystem.imperial, nov8);
      await db.saveGoals(
        GoalInput(
          sex: Sex.male,
          birthDate: '1982-05-14',
          heightCm: inToCm(71),
          activity: ActivityLevel.lightlyActive,
          rate: const WeeklyRate(Target.lose, 0.5, UnitSystem.imperial),
        ),
        nov8,
      );
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => nowFixed,
        foodsPath: Completer<String>().future,
      ),
    );
    await settle(tester);
    await tap(tester, find.widgetWithText(NavigationDestination, 'More'));
    await tap(tester, find.text('Goals'));
    await tap(tester, find.text('Other nutrients'));
    expect(find.byType(OtherNutrientsScreen), findsOneWidget);
  }

  Finder row(String name) => find.widgetWithText(ListTile, name);

  Future<void> setGoal(WidgetTester tester, String name, String value) async {
    await tap(tester, row(name));
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      value,
    );
    await tester.pump();
    await tap(
      tester,
      find.descendant(of: find.byType(Dialog), matching: find.text('Save')),
    );
  }

  Future<void> saveGoals(WidgetTester tester) async {
    await tester.pageBack();
    await settle(tester);
    await tap(tester, find.widgetWithText(FilledButton, 'Save'));
  }

  Future<Map<int, double>> stored(WidgetTester tester) =>
      real(tester, () async {
        final rows = await db.select(db.goalNutrients).get();
        return {for (final r in rows) r.nutrientId: r.targetAmount};
      });

  appTest('lists the tracked nutrients with Daily Values as the goals, and '
      'no goal for total sugar and trans fat', (tester) async {
    await openList(tester, size: const Size(400, 3000));
    expect(find.text(S.otherIntro), findsOneWidget);
    // Calories and the macros are set on Goals itself.
    for (final name in ['Calories', 'Protein', 'Carbs', 'Fat']) {
      expect(row(name), findsNothing, reason: name);
    }
    expect(find.text('28 g. Daily Value'), findsOneWidget);
    expect(find.text('2,300 mg. Daily Value'), findsOneWidget);
    expect(find.text('1.7 mg. Daily Value'), findsOneWidget);
    expect(find.text('900 µg. Daily Value'), findsOneWidget);
    for (final name in ['Sugar', 'Trans fat']) {
      await tester.ensureVisible(row(name));
      expect(
        find.descendant(of: row(name), matching: find.text('No goal')),
        findsOneWidget,
        reason: name,
      );
    }
    // Every other tracked nutrient is listed, once.
    for (final n in Nutrients.tracked.skip(4)) {
      expect(row(S.nutrientName(n.id)), findsOneWidget, reason: n.name);
    }
  });

  appTest('a changed goal is kept when Goals is saved, and shows as the '
      'user\'s own', (tester) async {
    await openList(tester);
    await setGoal(tester, 'Sodium', '2000');
    expect(find.text('2,000 mg. Your goal'), findsOneWidget);
    expect(await stored(tester), isEmpty);
    await saveGoals(tester);
    expect(await stored(tester), {Nutrients.sodium: 2000});
    // Opening again shows it.
    await tap(tester, find.text('Other nutrients'));
    expect(find.text('2,000 mg. Your goal'), findsOneWidget);
  });

  appTest('the Daily Value is one tap away again', (tester) async {
    await openList(tester);
    await setGoal(tester, 'Sodium', '2000');
    await tap(tester, row('Sodium'));
    await tap(tester, find.text('Use the Daily Value'));
    expect(find.text('2,300 mg. Daily Value'), findsOneWidget);
    await saveGoals(tester);
    expect(await stored(tester), isEmpty);
  });

  appTest('a nutrient with no default can be given a goal and can lose it '
      'again', (tester) async {
    await openList(tester);
    await setGoal(tester, 'Sugar', '40');
    expect(find.text('40 g. Your goal'), findsOneWidget);
    await tap(tester, row('Sugar'));
    await tap(tester, find.text('Remove my goal'));
    expect(
      find.descendant(of: row('Sugar'), matching: find.text('No goal')),
      findsOneWidget,
    );
  });

  appTest('a goal that is not a number above 0 is refused beside the '
      'field', (tester) async {
    await openList(tester);
    for (final bad in ['0', 'abc', '', '2,300']) {
      await tap(tester, row('Sodium'));
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        bad,
      );
      await tester.pump();
      await tap(
        tester,
        find.descendant(of: find.byType(Dialog), matching: find.text('Save')),
      );
      expect(find.byType(Dialog), findsOneWidget, reason: bad);
      expect(
        find.textContaining(RegExp('Enter a number|without the comma')),
        findsOneWidget,
        reason: bad,
      );
      await tap(tester, find.text('Cancel'));
    }
    expect(find.text('2,300 mg. Daily Value'), findsOneWidget);
  });

  for (final width in [344.0, 673.0]) {
    appTest('no overflow at ${width.toInt()} dp and text x2, rows at least '
        '48 dp', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openList(tester, size: Size(width, 800));
      await tester.scrollUntilVisible(row('Zinc'), 200);
      final s = tester.getSize(row('Zinc'));
      expect(s.height, greaterThanOrEqualTo(48));
      await tap(tester, row('Zinc'));
      expect(tester.takeException(), isNull);
    });
  }

  appTest('rows are read as name, amount and where it comes from', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openList(tester);
    expect(
      find.bySemanticsLabel(RegExp(r'Fiber.*28 g.*Daily Value')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
