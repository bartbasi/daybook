// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/screens/goals/goals_screen.dart';
import 'package:daybook/strings.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Goals screen (task 3.2): the working shown, the low intake notice, the
// user's own number, the add-back, macros, and every refusal in plain words.
// Goals frames 1 to 5 are the sample person: male, born May 14, 1982, 5 ft
// 11 in, 181.8 lb, lightly active, losing 0.5 lb a week.

Now at(String date, int h, int m) => Now.fromLocal(date, h * 60 + m, -360);

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = at('2026-11-12', 7, 2);
final nov8 = at('2026-11-08', 8, 15);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Lets a test hold or fail the writes, and counts the goals inserts.
class Gate extends QueryInterceptor {
  Completer<void>? hold;
  var failWrites = false;
  var goalsInserts = 0;

  Future<void> _check(String statement) async {
    if (failWrites) throw StateError('disk full');
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await hold?.future;
    await _check(statement);
    if (statement.contains('INSERT INTO "goals"')) goalsInserts++;
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await _check(statement);
    return super.runUpdate(executor, statement, args);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Gate gate;
  late Now clockNow;

  setUp(() {
    gate = Gate();
    clockNow = nowFixed;
    db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
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

  Future<void> seedWeight(
    WidgetTester tester,
    double value, {
    UnitSystem units = UnitSystem.imperial,
    Now? at,
  }) => real(tester, () async {
    await db.saveWeight(value, units, at ?? nowFixed);
  });

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.ensureVisible(field(label));
    await tester.pump();
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');

  Future<void> openGoals(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => clockNow,
        foodsPath: Completer<String>().future,
      ),
    );
    await settle(tester);
    await tap(tester, find.widgetWithText(NavigationDestination, 'More'));
    await tap(tester, find.text('Goals'));
    expect(find.byType(GoalsScreen), findsOneWidget);
  }

  Future<void> enterBorn(WidgetTester tester, String typed) async {
    await tap(tester, find.text('Born'));
    final box = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(box, typed);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await settle(tester);
  }

  /// The profile of the sample person, in feet and inches.
  Future<void> fillSample(WidgetTester tester) async {
    await tap(tester, find.text('Male'));
    await enterBorn(tester, '05/14/1982');
    await enter(tester, 'Feet', '5');
    await enter(tester, 'Inches', '11');
    await tester.pump();
  }

  Future<List<Goal>> goalRows(WidgetTester tester) =>
      real(tester, () => db.select(db.goals).get());

  Future<Goal> theGoal(WidgetTester tester) async {
    final rows = await goalRows(tester);
    expect(rows, hasLength(1));
    return rows.single;
  }

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;

  bool radioOn(String level) => find
      .descendant(
        of: find.byKey(ValueKey('activity-$level')),
        matching: find.byIcon(Icons.radio_button_checked),
      )
      .evaluate()
      .isNotEmpty;

  Finder low(bool men) =>
      find.text(men ? S.goalsLowIntakeMen : S.goalsLowIntakeWomen);

  // The goals of the sample person saved on Nov 8 (frame 1 says Nov 8).
  Future<void> saveSampleOnNov8(WidgetTester tester) => real(tester, () async {
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

  group('the sample person', () {
    appTest('the frames inputs give 1,737, 2,388 and 2,138 on screen, and '
        'the saved row holds 2,138', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      // Nothing to work out until the person is filled in.
      expect(find.text(S.goalsNeedProfile), findsOneWidget);
      await fillSample(tester);
      expect(
        find.text('Resting rate (Mifflin-St Jeor): 1,737 kcal'),
        findsOneWidget,
      );
      expect(
        find.text('x 1.375 lightly active: 2,388 kcal to stay the same'),
        findsOneWidget,
      );
      expect(find.text('- 250 to lose 0.5 lb a week'), findsOneWidget);
      expect(find.text('2,138'), findsOneWidget);
      expect(
        find.text(
          'New, from your latest weigh-in (181.8 lb, today). '
          'Kept when you tap Save.',
        ),
        findsOneWidget,
      );
      // The defaults are the frame's: lightly active, lose, 0.5 lb.
      expect(radioOn('lightlyActive'), isTrue);
      expect(chipSelected(tester, '0.5 lb'), isTrue);

      await tap(tester, saveButton());
      final g = await theGoal(tester);
      expect(g.calories, 2138);
      expect(g.calorieMode, 'calculated');
      expect(g.effectiveFrom, '2026-11-12');
      expect(g.activityFactor, 1.375);
      expect(
        g.targetKgPerWeek,
        const WeeklyRate(Target.lose, 0.5, UnitSystem.imperial).kgPerWeek,
      );
      final p = (await real(tester, () => db.getProfile()))!;
      expect(p.sex, 'male');
      expect(p.birthDate, '1982-05-14');
      expect(p.heightCm, closeTo(180.34, 1e-9));
      // Confirmed from the row read back, and the card now says when.
      expect(
        find.text('Saved. Your goal is 2,138 kcal a day, from today.'),
        findsOneWidget,
      );
      expect(find.text('Calculated Nov 12.'), findsOneWidget);
      expect(find.text('Recalculate'), findsOneWidget);
    });

    appTest('each activity level shows its multiplier and its own number, '
        'and stores its factor', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      // Resting 1,736.76 times each factor, less 250.
      const cases = [
        ('sedentary', 'Sedentary', '1.2', 2084, 1834),
        ('lightlyActive', 'Lightly active', '1.375', 2388, 2138),
        ('moderatelyActive', 'Moderately active', '1.55', 2692, 2442),
        ('veryActive', 'Very active', '1.725', 2996, 2746),
        ('extraActive', 'Extra active', '1.9', 3300, 3050),
      ];
      for (final (key, name, factor, stay, goal) in cases) {
        await tap(tester, find.text(name));
        expect(radioOn(key), isTrue, reason: name);
        expect(
          find.text(
            'x $factor ${name.toLowerCase()}: '
            '${S.count(stay)} kcal to stay the same',
          ),
          findsOneWidget,
          reason: name,
        );
        expect(find.text(S.count(goal)), findsOneWidget, reason: name);
        await tap(tester, saveButton());
        final g = (await goalRows(tester)).single;
        expect(g.activityFactor, double.parse(factor), reason: name);
        expect(g.calories, goal, reason: name);
      }
      // The frame's own words for each level are all there.
      for (final note in [
        'Desk job, little walking',
        'On your feet some of the day',
        'On your feet most of the day',
        'Physical job',
        'Hard physical job every day',
      ]) {
        expect(find.text(note), findsOneWidget);
      }
    });

    appTest('each rate chip in pounds is passed as the offered rate and '
        'gives its own goal', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      const cases = [
        ('0.25 lb', 0.25, 125, 2263),
        ('0.5 lb', 0.5, 250, 2138),
        ('1 lb', 1.0, 500, 1888),
        ('1.5 lb', 1.5, 750, 1638),
        ('2 lb', 2.0, 1000, 1388),
      ];
      for (final (label, amount, adj, goal) in cases) {
        await tap(tester, find.widgetWithText(ChoiceChip, label));
        expect(chipSelected(tester, label), isTrue, reason: label);
        expect(
          find.text(
            '- ${S.count(adj)} to lose ${S.numberText(amount)} lb a week',
          ),
          findsOneWidget,
          reason: label,
        );
        await tap(tester, saveButton());
        final g = (await goalRows(tester)).single;
        // Exactly the rate the list offers: lbToKg of the offered amount.
        expect(
          g.targetKgPerWeek,
          WeeklyRate(Target.lose, amount, UnitSystem.imperial).kgPerWeek,
          reason: label,
        );
        expect(g.calories, goal, reason: label);
      }
      // Stay the same and gain.
      await tap(tester, find.text('Stay the same'));
      expect(find.text('2,388'), findsWidgets);
      await tap(tester, saveButton());
      expect((await goalRows(tester)).single.targetKgPerWeek, 0);
      expect((await goalRows(tester)).single.calories, 2388);
      await tap(tester, find.text('Gain'));
      await tap(tester, find.widgetWithText(ChoiceChip, '0.5 lb'));
      expect(find.text('+ 250 to gain 0.5 lb a week'), findsOneWidget);
      await tap(tester, saveButton());
      expect((await goalRows(tester)).single.calories, 2638);
    });

    appTest('each rate chip in kilograms gives its own goal', (tester) async {
      await real(tester, () => db.setUnits(UnitSystem.metric));
      await seedWeight(tester, 82.5, units: UnitSystem.metric);
      await openGoals(tester);
      await tap(tester, find.text('Male'));
      await enterBorn(tester, '05/14/1982');
      await enter(tester, 'Centimeters', '180.34');
      expect(find.text('Feet'), findsNothing);
      const cases = [
        ('0.1 kg', 0.1, 110, 2279),
        ('0.25 kg', 0.25, 275, 2114),
        ('0.5 kg', 0.5, 550, 1839),
        ('0.75 kg', 0.75, 825, 1564),
        ('1 kg', 1.0, 1100, 1289),
      ];
      for (final (label, amount, adj, goal) in cases) {
        await tap(tester, find.widgetWithText(ChoiceChip, label));
        expect(
          find.text(
            '- ${S.count(adj)} to lose ${S.numberText(amount)} kg a week',
          ),
          findsOneWidget,
          reason: label,
        );
        await tap(tester, saveButton());
        final g = (await goalRows(tester)).single;
        expect(
          g.targetKgPerWeek,
          WeeklyRate(Target.lose, amount, UnitSystem.metric).kgPerWeek,
          reason: label,
        );
        expect(g.calories, goal, reason: label);
      }
    });

    appTest('after a switch to metric a goal saved at 0.5 lb shows its rate '
        'as it is, with no chip selected, and Save keeps it', (tester) async {
      await saveSampleOnNov8(tester);
      await real(tester, () => db.setUnits(UnitSystem.metric));
      await openGoals(tester);
      for (final label in ['0.1 kg', '0.25 kg', '0.5 kg', '0.75 kg', '1 kg']) {
        expect(chipSelected(tester, label), isFalse, reason: label);
      }
      expect(
        find.text(
          'Your saved rate is 0.5 lb a week to lose. Pick one of these to '
          'change it.',
        ),
        findsOneWidget,
      );
      await tap(tester, saveButton());
      // Saved again today: Nov 12 is a new row beside the one from Nov 8.
      final g = (await goalRows(tester)).last;
      expect(g.effectiveFrom, '2026-11-12');
      expect(g.targetKgPerWeek, -lbToKg(0.5));
      expect(g.calories, 2138);
      // Picking a kg rate replaces it.
      await tap(tester, find.widgetWithText(ChoiceChip, '0.25 kg'));
      expect(find.textContaining('Your saved rate is'), findsNothing);
      await tap(tester, saveButton());
      expect((await goalRows(tester)).last.targetKgPerWeek, -0.25);
    });
  });

  group('the working', () {
    appTest('a saved goal says when it was calculated and offers '
        'Recalculate', (tester) async {
      await saveSampleOnNov8(tester);
      await openGoals(tester);
      expect(find.text('Calculated Nov 8.'), findsOneWidget);
      expect(find.text('2,138'), findsOneWidget);
      expect(find.text(S.goalsDrifted), findsNothing);
      // The saved inputs are back in the fields.
      expect(radioOn('lightlyActive'), isTrue);
      expect(chipSelected(tester, '0.5 lb'), isTrue);
      expect(tester.widget<TextField>(field('Feet')).controller!.text, '5');
      expect(tester.widget<TextField>(field('Inches')).controller!.text, '11');
    });

    appTest('a weigh-in after the save: the stored goal stays, the steps '
        'use today, one sentence says they do not add up, and Recalculate '
        'updates it', (tester) async {
      await saveSampleOnNov8(tester);
      await seedWeight(tester, 190.0, at: at('2026-11-10', 7, 0));
      await openGoals(tester);
      // The stored goal is the goal shown.
      expect(find.text('2,138'), findsOneWidget);
      expect(find.text(S.goalsDrifted), findsOneWidget);
      // The steps are worked out from the weigh-in of 190 lb now.
      expect(
        find.text('Resting rate (Mifflin-St Jeor): 1,774 kcal'),
        findsOneWidget,
      );
      await tap(tester, find.text('Recalculate'));
      expect(find.text(S.goalsDrifted), findsNothing);
      final rows = await goalRows(tester);
      expect(rows, hasLength(2));
      expect(rows.last.effectiveFrom, '2026-11-12');
      expect(rows.last.calories, 2189);
      expect(
        find.text('Recalculated. Your goal is 2,189 kcal a day, from today.'),
        findsOneWidget,
      );
      expect(find.text('2,189'), findsOneWidget);
      expect(find.text('Calculated Nov 12.'), findsOneWidget);
    });

    appTest('the working never prints an equation that does not add up: '
        'the resting number times the factor can differ by one', (
      tester,
    ) async {
      // 60 kg and 163 cm: resting 1,403.75 shows as 1,404, and 1,404 x 1.375
      // is 1,930.5, but the maintenance shown is 1,930 from the unrounded
      // number.
      await real(tester, () => db.setUnits(UnitSystem.metric));
      await seedWeight(tester, 60.0, units: UnitSystem.metric);
      await openGoals(tester);
      await tap(tester, find.text('Male'));
      await enterBorn(tester, '05/14/1982');
      await enter(tester, 'Centimeters', '163');
      expect(
        find.text('Resting rate (Mifflin-St Jeor): 1,404 kcal'),
        findsOneWidget,
      );
      expect(
        find.text('x 1.375 lightly active: 1,930 kcal to stay the same'),
        findsOneWidget,
      );
      // No equals sign and no product anywhere in the card.
      expect(find.textContaining('='), findsNothing);
      expect(find.textContaining('1,931'), findsNothing);
    });

    appTest('no weigh-in yet: the screen says so in plain words, and Save '
        'is refused beside it with nothing written', (tester) async {
      await openGoals(tester);
      expect(find.text(S.goalsNeedWeight), findsOneWidget);
      await fillSample(tester);
      expect(find.text('2,138'), findsNothing);
      await tap(tester, saveButton());
      expect(await goalRows(tester), isEmpty);
      expect(find.text(S.goalsNeedWeight), findsOneWidget);
      expect(find.text(S.goalsFix), findsOneWidget);
    });

    appTest('the latest weigh-in is shown in the user\'s units', (
      tester,
    ) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      expect(find.text('Latest weigh-in: 181.8 lb, today'), findsOneWidget);
      expect(find.text(S.goalsWeightNote), findsOneWidget);
    });
  });

  group('the low intake notice', () {
    Future<void> own(WidgetTester tester, String calories) async {
      if (!tester.widget<Switch>(find.byType(Switch)).value) {
        await tap(tester, find.text('Use my own calorie goal instead'));
      }
      await enter(tester, 'Calories a day', calories);
    }

    appTest('a man: 1,499 shows the one sentence, 1,500 does not', (
      tester,
    ) async {
      await openGoals(tester);
      await tap(tester, find.text('Male'));
      await own(tester, '1499');
      expect(low(true), findsOneWidget);
      await enter(tester, 'Calories a day', '1500');
      expect(low(true), findsNothing);
      expect(low(false), findsNothing);
    });

    appTest('a woman: 1,199 shows the sentence with 1,200, 1,200 does not', (
      tester,
    ) async {
      await openGoals(tester);
      await tap(tester, find.text('Female'));
      await own(tester, '1199');
      expect(low(false), findsOneWidget);
      expect(low(true), findsNothing);
      await enter(tester, 'Calories a day', '1200');
      expect(low(false), findsNothing);
    });

    appTest('with no sex the lower line is used', (tester) async {
      await openGoals(tester);
      await own(tester, '1199');
      expect(low(false), findsOneWidget);
      await enter(tester, 'Calories a day', '1200');
      expect(low(false), findsNothing);
      await enter(tester, 'Calories a day', '1499');
      expect(low(true), findsNothing);
      expect(low(false), findsNothing);
    });

    appTest('the sentence is plain: no color, no icon, and Save still '
        'works', (tester) async {
      await openGoals(tester);
      await tap(tester, find.text('Male'));
      await own(tester, '1000');
      final notice = find.byKey(const ValueKey('low-intake'));
      expect(notice, findsOneWidget);
      expect(
        find.descendant(of: notice, matching: find.byType(Icon)),
        findsNothing,
      );
      final text = tester.widget<Text>(
        find.descendant(of: notice, matching: find.byType(Text)),
      );
      expect(text.style?.color, isNull);
      expect(find.byType(Chip), findsNothing);
      // Never blocks Save, and no extra tap.
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
      await tap(tester, saveButton());
      final g = await theGoal(tester);
      expect(g.calories, 1000);
      expect(g.calorieMode, 'fixed');
    });

    appTest('a calculated goal is checked by the number shown: 1,499.7 '
        'shows as 1,500 and has no notice', (tester) async {
      // Male, 52.1 kg, 151 cm, sedentary, stay the same, age 44: 1,499.7.
      await real(tester, () => db.setUnits(UnitSystem.metric));
      await seedWeight(tester, 52.1, units: UnitSystem.metric);
      await openGoals(tester);
      await tap(tester, find.text('Male'));
      await enterBorn(tester, '05/14/1982');
      await enter(tester, 'Centimeters', '151');
      await tap(tester, find.text('Sedentary'));
      await tap(tester, find.text('Stay the same'));
      expect(find.text('1,500'), findsOneWidget);
      expect(low(true), findsNothing);
      expect(low(false), findsNothing);
    });

    appTest('a calculated goal under the line shows it in the card (frame '
        '2)', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await tap(tester, find.widgetWithText(ChoiceChip, '2 lb'));
      expect(find.text('1,388'), findsOneWidget);
      expect(low(true), findsOneWidget);
      expect(find.text('- 1,000 to lose 2 lb a week'), findsOneWidget);
    });
  });

  group('your own number', () {
    appTest('turning it on keeps the inputs, and turning it off brings the '
        'calculation back', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await tap(tester, saveButton());
      expect((await theGoal(tester)).calories, 2138);

      await tap(tester, find.text('Use my own calorie goal instead'));
      await enter(tester, 'Calories a day', '1800');
      expect(
        find.text('The calculated goal (2,138) is above, grayed out.'),
        findsOneWidget,
      );
      expect(
        find.text('The calculated 2,138 is not used while this is on.'),
        findsOneWidget,
      );
      await tap(tester, saveButton());
      var g = await theGoal(tester);
      expect(g.calories, 1800);
      expect(g.calorieMode, 'fixed');
      // The inputs are kept in the row.
      expect(g.activityFactor, 1.375);
      expect(
        g.targetKgPerWeek,
        const WeeklyRate(Target.lose, 0.5, UnitSystem.imperial).kgPerWeek,
      );
      // Reopen: the own number is on, the inputs are still there.
      await tester.pageBack();
      await settle(tester);
      await tap(tester, find.text('Goals'));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(
        tester.widget<TextField>(field('Calories a day')).controller!.text,
        '1800',
      );
      expect(radioOn('lightlyActive'), isTrue);
      expect(chipSelected(tester, '0.5 lb'), isTrue);

      // Off again: the calculation comes back from the same inputs.
      await tap(tester, find.text('Use my own calorie goal instead'));
      expect(field('Calories a day'), findsNothing);
      expect(find.text('2,138'), findsOneWidget);
      await tap(tester, saveButton());
      g = await theGoal(tester);
      expect(g.calories, 2138);
      expect(g.calorieMode, 'calculated');
    });

    appTest('an own number needs no profile and no weigh-in', (tester) async {
      await openGoals(tester);
      await tap(tester, find.text('Use my own calorie goal instead'));
      await enter(tester, 'Calories a day', '1800');
      await tap(tester, saveButton());
      final g = await theGoal(tester);
      expect(g.calories, 1800);
      expect(g.calorieMode, 'fixed');
    });

    appTest('an own number of 0 or text is refused beside the field with '
        'nothing written', (tester) async {
      await openGoals(tester);
      await tap(tester, find.text('Use my own calorie goal instead'));
      for (final bad in ['0', 'abc', '1800.5', '']) {
        await enter(tester, 'Calories a day', bad);
        await tap(tester, saveButton());
        expect(find.text(S.goalsOwnBad), findsOneWidget, reason: bad);
        expect(await goalRows(tester), isEmpty, reason: bad);
      }
    });
  });

  group('the exercise add-back', () {
    appTest('0, 50 and 100 change the sentence and what is stored', (
      tester,
    ) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      // 100 is the default.
      expect(
        find.text("A 383 kcal run adds 383 to that day's budget."),
        findsOneWidget,
      );
      for (final (label, shown, stored) in [
        ('50%', 192, 50),
        ('0%', 0, 0),
        ('100%', 383, 100),
      ]) {
        await tap(tester, find.text(label));
        expect(
          find.text("A 383 kcal run adds $shown to that day's budget."),
          findsOneWidget,
          reason: label,
        );
        await tap(tester, saveButton());
        expect(
          (await goalRows(tester)).single.exerciseAddBackPercent,
          stored,
          reason: label,
        );
      }
    });
  });

  group('macros', () {
    appTest('grams: each macro in kcal, the total, and the difference from '
        'the goal', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await enter(tester, 'Protein', '150');
      await enter(tester, 'Carbs', '227');
      await enter(tester, 'Fat', '70');
      expect(find.text('600 kcal'), findsOneWidget);
      expect(find.text('908 kcal'), findsOneWidget);
      expect(find.text('630 kcal'), findsOneWidget);
      expect(find.text('2,138 kcal'), findsOneWidget);
      expect(find.text('Matches your calorie goal.'), findsOneWidget);

      await enter(tester, 'Protein', '170');
      expect(find.text('2,218 kcal'), findsOneWidget);
      expect(
        find.text('That is 80 kcal more than your calorie goal.'),
        findsOneWidget,
      );
      await enter(tester, 'Protein', '140');
      expect(
        find.text('That is 40 kcal less than your calorie goal.'),
        findsOneWidget,
      );
      // Save still works when they do not match.
      await tap(tester, saveButton());
      final g = await theGoal(tester);
      expect(g.macroMode, 'grams');
      expect([g.proteinTarget, g.carbsTarget, g.fatTarget], [140, 227, 70]);
    });

    appTest('percent: 30, 40 and 30 give 160, 214 and 71 g, and are '
        'stored as percents', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await tap(tester, find.text('Percent'));
      await enter(tester, 'Protein', '30');
      await enter(tester, 'Carbs', '40');
      await enter(tester, 'Fat', '30');
      expect(find.text('160 g'), findsOneWidget);
      expect(find.text('214 g'), findsOneWidget);
      expect(find.text('71 g'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('macro-total')),
          matching: find.text('100%'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Grams follow the calorie goal: 30% of 2,138 kcal is 641 kcal, '
          'or 160 g of protein.',
        ),
        findsOneWidget,
      );
      await tap(tester, saveButton());
      final g = await theGoal(tester);
      expect(g.macroMode, 'percent');
      expect([g.proteinTarget, g.carbsTarget, g.fatTarget], [30, 40, 30]);
    });

    appTest('percents that do not add to 100 are refused beside the fields '
        'and nothing is written', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await tap(tester, find.text('Percent'));
      await enter(tester, 'Protein', '30');
      await enter(tester, 'Carbs', '40');
      await enter(tester, 'Fat', '25');
      expect(find.text('Adds to 95%. 5% left.'), findsOneWidget);
      await tap(tester, saveButton());
      expect(await goalRows(tester), isEmpty);
      final error = find.text('The percents must add to 100. They add to 95%.');
      expect(error, findsOneWidget);
      // Right under the three fields.
      final fat = tester.getRect(field('Fat'));
      final at = tester.getRect(error);
      expect(at.top, greaterThanOrEqualTo(fat.bottom - 1));
      expect(at.top - fat.bottom, lessThan(160));
      // Over 100 says so too.
      await enter(tester, 'Fat', '35');
      expect(find.text('Adds to 105%. 5% over.'), findsOneWidget);
    });

    appTest('some macros filled and some not is refused beside them', (
      tester,
    ) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await enter(tester, 'Protein', '150');
      await tap(tester, saveButton());
      expect(find.text(S.goalsMacrosIncomplete), findsOneWidget);
      expect(await goalRows(tester), isEmpty);
    });

    appTest('all three empty means no macro goals', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await tap(tester, saveButton());
      final g = await theGoal(tester);
      expect([g.proteinTarget, g.carbsTarget, g.fatTarget], [null, null, null]);
    });

    appTest('a typed number with a thousands comma or letters is refused '
        'beside its field', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await enter(tester, 'Protein', '1,500');
      await enter(tester, 'Carbs', '227');
      await enter(tester, 'Fat', 'x');
      await tap(tester, saveButton());
      expect(find.text(S.foodEditNumberComma), findsOneWidget);
      expect(find.text(S.foodEditNumberBad), findsOneWidget);
      expect(await goalRows(tester), isEmpty);
    });
  });

  group('every refusal is in plain words, beside its cause', () {
    appTest('needsProfile: sex, birth date and height each say what is '
        'missing', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await tap(tester, saveButton());
      expect(find.text(S.goalsSexMissing), findsOneWidget);
      expect(find.text(S.goalsBornMissing), findsOneWidget);
      expect(find.text(S.goalsHeightBad), findsOneWidget);
      expect(await goalRows(tester), isEmpty);
    });

    appTest('a height that cannot be right is refused', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      await enter(tester, 'Feet', '15');
      await tap(tester, saveButton());
      expect(find.text(S.goalsHeightRange), findsOneWidget);
      expect(await goalRows(tester), isEmpty);
    });

    appTest('badRate and badActivity from Recalculate on a stored row an '
        'import brought in', (tester) async {
      await real(
        tester,
        () => db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                effectiveFrom: '2026-11-01',
                calorieMode: 'calculated',
                calories: const Value(2000),
                activityFactor: 1.375,
                targetKgPerWeek: -0.3,
                macroMode: 'grams',
              ),
            ),
      );
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await tap(tester, find.text('Recalculate'));
      expect(find.text(S.goalsBadRate), findsOneWidget);
      expect((await goalRows(tester)), hasLength(1));

      await real(
        tester,
        () => (db.update(db.goals)).write(
          const GoalsCompanion(
            activityFactor: Value(1.3),
            targetKgPerWeek: Value(-0.45359237 / 2),
          ),
        ),
      );
      await tester.pageBack();
      await settle(tester);
      await tap(tester, find.text('Goals'));
      await tap(tester, find.text('Recalculate'));
      expect(find.text(S.goalsBadActivity), findsOneWidget);
    });

    appTest('noGoals from Recalculate when the goals went away', (
      tester,
    ) async {
      await saveSampleOnNov8(tester);
      await openGoals(tester);
      await real(tester, () => db.delete(db.goals).go());
      await tap(tester, find.text('Recalculate'));
      expect(find.text(S.goalsNoGoals), findsOneWidget);
    });

    test('every problem the data layer can name has its own words', () {
      final seen = <String>{};
      for (final p in GoalProblem.values) {
        final text = goalProblemText(p);
        expect(text, isNotEmpty, reason: p.name);
        expect(seen.add(text), isTrue, reason: '${p.name} repeats a message');
        expect(
          text.contains(String.fromCharCode(0x2014)) ||
              text.contains(String.fromCharCode(0x2013)),
          isFalse,
        );
        expect(
          text.contains(
            '-'
            '-',
          ),
          isFalse,
        );
        // Plain words: no enum names and no digits of the user's.
        expect(text.contains(p.name), isFalse, reason: p.name);
      }
    });
  });

  group('saving', () {
    appTest('a double tap on Save writes once', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      gate.hold = Completer<void>();
      await tester.ensureVisible(saveButton());
      await tester.pump();
      await tester.tap(saveButton());
      await tester.pump();
      await tester.tap(saveButton(), warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
      gate.hold!.complete();
      await settle(tester);
      expect(gate.goalsInserts, 1);
      expect(await goalRows(tester), hasLength(1));
    });

    appTest('a failed write leaves the screen open with a plain message '
        'and the inputs kept', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      await fillSample(tester);
      gate.failWrites = true;
      await tap(tester, saveButton());
      expect(find.byType(GoalsScreen), findsOneWidget);
      expect(find.text(S.goalsSaveFailed), findsOneWidget);
      expect(
        find.text('Saved. Your goal is 2,138 kcal a day, from today.'),
        findsNothing,
      );
      expect(await goalRows(tester), isEmpty);
      expect(tester.widget<TextField>(field('Feet')).controller!.text, '5');
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
      // Try again.
      gate.failWrites = false;
      await tap(tester, saveButton());
      expect(find.text(S.goalsSaveFailed), findsNothing);
      expect((await theGoal(tester)).calories, 2138);
    });

    appTest('a failed Recalculate says so and changes nothing', (tester) async {
      await saveSampleOnNov8(tester);
      await seedWeight(tester, 190.0, at: at('2026-11-10', 7, 0));
      await openGoals(tester);
      gate.failWrites = true;
      await tap(tester, find.text('Recalculate'));
      expect(find.text(S.goalsRecalcFailed), findsOneWidget);
      expect((await goalRows(tester)).single.calories, 2138);
    });

    appTest('the Other nutrients row opens the list', (tester) async {
      await seedWeight(tester, 181.8);
      await openGoals(tester);
      expect(find.text('Other nutrients'), findsOneWidget);
      expect(find.text(S.goalsOtherSub), findsOneWidget);
      await tap(tester, find.text('Other nutrients'));
      expect(find.text(S.otherIntro), findsOneWidget);
    });

    appTest('the bar says goals apply from today', (tester) async {
      await openGoals(tester);
      expect(find.text(S.goalsApplies), findsOneWidget);
    });
  });

  group('layout and spoken labels', () {
    for (final width in [344.0, 673.0]) {
      for (final scale in [1.0, 2.0]) {
        appTest('no overflow at ${width.toInt()} dp, text x$scale, keyboard '
            'up: Save reachable, targets 48 dp', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await saveSampleOnNov8(tester);
          await openGoals(tester, size: Size(width, 800));
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await enter(tester, 'Protein', '150');
          await tester.pump();
          expect(tester.takeException(), isNull);
          final save = tester.getRect(saveButton());
          expect(save.bottom, lessThanOrEqualTo(500));
          expect(save.left, greaterThanOrEqualTo(0));
          expect(save.right, lessThanOrEqualTo(width));
          // Scroll the whole screen: nothing overflows anywhere.
          tester.view.resetViewInsets();
          await tester.pump();
          final scroll = find.byType(SingleChildScrollView).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(scroll, const Offset(0, -400));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          for (final f in [
            saveButton(),
            find.widgetWithText(ChoiceChip, '0.5 lb'),
            find.widgetWithText(ChoiceChip, '50%'),
            find.byType(SwitchListTile),
            find.widgetWithText(ListTile, 'Other nutrients'),
          ]) {
            if (f.evaluate().isEmpty) continue;
            await tester.ensureVisible(f.first);
            await tester.pump();
            final s = tester.getSize(f.first);
            expect(s.height, greaterThanOrEqualTo(48), reason: '$f');
            expect(s.width, greaterThanOrEqualTo(48), reason: '$f');
          }
          // Content stops at 600 dp.
          expect(
            tester.getSize(find.byType(SingleChildScrollView).first).width,
            lessThanOrEqualTo(width),
          );
        });
      }
    }

    appTest('controls that stand alone have spoken labels', (tester) async {
      final semantics = tester.ensureSemantics();
      await saveSampleOnNov8(tester);
      await openGoals(tester);
      for (final label in [
        '0.25 lb a week',
        '0.5 lb a week',
        '2 lb a week',
        'Save',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      for (final label in ['Protein', 'Carbs', 'Fat', 'Feet', 'Inches']) {
        expect(
          find.bySemanticsLabel(RegExp('^$label')),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.bySemanticsLabel(RegExp(r'^Born')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Use my own calorie goal instead'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    appTest('the result card is read first, in one sensible order', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await saveSampleOnNov8(tester);
      await openGoals(tester);
      final big = tester.getRect(find.text('2,138'));
      final resting = tester.getRect(
        find.text('Resting rate (Mifflin-St Jeor): 1,737 kcal'),
      );
      final about = tester.getRect(find.text('About you'));
      // The working, then the number, then the form.
      expect(resting.top, lessThan(big.top));
      expect(big.top, lessThan(about.top));
      semantics.dispose();
    });
  });
}
