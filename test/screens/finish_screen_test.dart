// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/screens/workouts/finish_screen.dart';
import 'package:daybook/screens/workouts/workout_screen.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../speed/tap_counter.dart';
import 'workouts_harness.dart';

// The finish summary (task 4.3, workout.html frame 6): time and calories from
// the data layer, sets, volume, new records, the planned sets that were not
// logged, the weigh-in behind the calories, the user's own number, Resume and
// Done.

void main() {
  final h = WorkoutHarness()..register();

  late int workoutId;
  late Now started;

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  /// Push A started now and worked for 52 minutes. [logged] of its 6 sets are
  /// logged (bench 175 x 8, 175 x 8, then 180 x 8; press 95 x 8 three times),
  /// and the clock stands one minute after the last. With [weighIn] there is a
  /// weigh-in of 181.8 lb that morning, with [goals] an own calorie goal of
  /// 2,000. The screen is open on the workout.
  Future<void> prepare(
    WidgetTester tester, {
    int logged = 6,
    bool weighIn = true,
    bool goals = false,
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    final ids = await h.seedSample(tester);
    started = h.now;
    final lastSet = Now(utcMs: started.utcMs + 52 * 60000, offsetMinutes: -360);
    workoutId = await h.real(tester, () async {
      if (weighIn) {
        await h.db.saveWeight(
          181.8,
          UnitSystem.imperial,
          at('2026-11-12', 7, 2),
        );
      }
      if (goals) {
        await h.db.saveGoals(
          const GoalInput(
            activity: ActivityLevel.sedentary,
            rate: WeeklyRate.stay,
            ownCalories: 2000,
          ),
          at('2026-11-12', 7, 3),
        );
      }
      final r = await h.db.startRoutine(ids.pushId, started);
      final id = r.workout!.id;
      final rows = (await h.db.loadWorkout(id))!;
      final all = [for (final e in rows.exercises) ...e.sets];
      await h.db.adjustSet(all[2].row.id, weightKg: lbToKg(180), reps: 8);
      for (var i = 0; i < logged; i++) {
        await h.db.logSet(all[i].row.id, lastSet);
      }
      return id;
    });
    h.now = Now(utcMs: lastSet.utcMs + 60000, offsetMinutes: -360);
    await h.openApp(tester, size: size, textScale: scale);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<Workout> row(WidgetTester tester) => h.real(
    tester,
    () => (h.db.select(
      h.db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingle(),
  );

  h.appTest('Finish ends the workout at once and shows the summary of '
      'frame 6', (tester) async {
    await prepare(tester);
    final taps = TapCounter(tester);
    await taps.tap(find.widgetWithText(FilledButton, 'Finish'));
    await settle(tester);
    taps.expectCount(1);

    expect(find.text('Workout done'), findsOneWidget);
    expect(find.text('Push A, Thu, Nov 12'), findsOneWidget);
    // Time runs to the last logged set: 52 minutes.
    expect(find.text('52 min'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // 175 x 8 + 175 x 8 + 180 x 8 + 3 x 95 x 8 = 6,520 lb.
    expect(find.text('6,520'), findsOneWidget);
    expect(find.text('lb'), findsOneWidget);

    expect(find.text('New personal records'), findsOneWidget);
    expect(find.text('Bench press, 180 lb x 8'), findsOneWidget);
    expect(find.text('Heaviest weight: 180 lb (was 175 lb)'), findsOneWidget);
    expect(
      find.text('Estimated 1-rep max: 228 lb (was 222 lb)'),
      findsOneWidget,
    );
    // The press only matched last time: no record.
    expect(find.textContaining('Overhead press,'), findsNothing);

    // 3.5 MET x 181.8 lb x 52 minutes is 250 kcal.
    expect(find.textContaining('250 kcal'), findsOneWidget);
    expect(find.textContaining('estimate'), findsWidgets);
    expect(find.text('MET 3.5, 181.8 lb, 52 min'), findsOneWidget);
    expect(find.text('Planned sets not logged'), findsOneWidget);
    expect(find.text('None. Every planned set was logged.'), findsOneWidget);

    // It ended with no question, at the moment of the tap.
    final w = await row(tester);
    expect(w.endedAtMs, h.now.utcMs);
    expect(w.kcalEstimated, closeTo(250.1, 0.1));
  });

  h.appTest('the finish screen has no back arrow: Resume or Done leave it', (
    tester,
  ) async {
    await prepare(tester);
    await finish(tester);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Resume'), findsOneWidget);
    expect(button('Done'), findsOneWidget);
  });

  h.appTest('planned sets that were not logged are counted first, in plain '
      'words, and nothing else about them is shown', (tester) async {
    await prepare(tester, logged: 4);
    await finish(tester);
    expect(find.text('2 planned sets not logged, removed'), findsOneWidget);
    expect(find.text('None. Every planned set was logged.'), findsNothing);
    expect(find.text('Planned sets not logged'), findsNothing);
    expect(find.text('Not logged'), findsOneWidget);
    // The summary counts the 4 sets that were done.
    expect(find.text('4'), findsOneWidget);
    final list = tester.getTopLeft(
      find.text('2 planned sets not logged, removed'),
    );
    expect(list.dy, lessThan(tester.getTopLeft(find.text('Time')).dy));
  });

  h.appTest('one planned set not logged is said in the singular', (
    tester,
  ) async {
    await prepare(tester, logged: 5);
    await finish(tester);
    expect(find.text('1 planned set not logged, removed'), findsOneWidget);
  });

  h.appTest('Resume brings the planned sets back and the workout runs '
      'again', (tester) async {
    await prepare(tester, logged: 4);
    await finish(tester);
    expect((await row(tester)).endedAtMs, isNotNull);

    await tester.tap(find.text('Resume'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Workout done'), findsNothing);
    expect(find.byType(WorkoutScreen), findsOneWidget);
    final w = await row(tester);
    expect(w.endedAtMs, isNull);
    expect(w.kcalEstimated, isNull);
    // All 6 sets are on screen again, 4 of them done.
    expect(find.text('Done'), findsNWidgets(4));
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    // The user can finish again.
    expect(find.text('Finish'), findsOneWidget);
  });

  h.appTest('Resume is only on the finish screen', (tester) async {
    await prepare(tester);
    expect(find.text('Resume'), findsNothing);
    await finish(tester);
    await tester.tap(button('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await h.openWorkoutsTab(tester);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Start again'), findsOneWidget);
  });

  h.appTest('Done closes the summary and the workout screen with it', (
    tester,
  ) async {
    await prepare(tester);
    await finish(tester);
    final taps = TapCounter(tester);
    await taps.tap(button('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    taps.expectCount(1);
    expect(find.byType(FinishScreen), findsNothing);
    expect(find.byType(WorkoutScreen), findsNothing);
    expect(find.text('Today'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Return'), findsNothing);
  });

  h.appTest('a double tap on Finish finishes once, at the first tap, and '
      'shows one summary', (tester) async {
    await prepare(tester);
    final firstTap = h.now.utcMs;
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    h.now = Now(utcMs: h.now.utcMs + 30000, offsetMinutes: -360);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Finish'),
      warnIfMissed: false,
    );
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FinishScreen), findsOneWidget);
    expect((await row(tester)).endedAtMs, firstTap);
    // Done closes both screens: there was only one summary.
    await tester.tap(button('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FinishScreen), findsNothing);
    expect(find.byType(WorkoutScreen), findsNothing);
  });

  h.appTest('Change takes the user\'s own calories, which win over the '
      'estimate, and the estimate stays visible', (tester) async {
    await prepare(tester);
    await finish(tester);
    await tester.tap(find.text('Change'));
    await settle(tester);
    expect(find.text('Calories for this workout'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '250',
    );
    await tester.enterText(find.byType(TextField), '300');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('300 kcal your number'), findsOneWidget);
    expect(find.text('The estimate was 250 kcal.'), findsOneWidget);
    final w = await row(tester);
    expect(w.kcalOverride, 300);
    expect(w.kcalEstimated, closeTo(250.1, 0.1));

    // Use the estimate again.
    await tester.tap(find.text('Change'));
    await settle(tester);
    await tester.tap(find.text('Use the estimate'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect((await row(tester)).kcalOverride, isNull);
    expect(find.text('250 kcal estimate'), findsOneWidget);
  });

  h.appTest('a negative calorie number is refused in plain words and '
      'nothing is stored', (tester) async {
    await prepare(tester);
    await finish(tester);
    await tester.tap(find.text('Change'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '-50');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Calories cannot be below 0.'), findsOneWidget);
    expect((await row(tester)).kcalOverride, isNull);
    // The sheet is still open with the number.
    expect(find.text('Calories for this workout'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1.2.3');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Enter a number of calories, like 250.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect((await row(tester)).kcalOverride, 0);
    expect(find.text('0 kcal your number'), findsOneWidget);
  });

  h.appTest('with no weigh-in there is no estimate, and it says why', (
    tester,
  ) async {
    await prepare(tester, weighIn: false);
    await finish(tester);
    expect(find.text('No estimate.'), findsOneWidget);
    expect(find.textContaining('needs a weigh-in'), findsOneWidget);
    expect((await row(tester)).kcalEstimated, isNull);
    // An own number still works.
    await tester.tap(find.text('Change'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('200 kcal your number'), findsOneWidget);
  });

  h.appTest('the weigh-in used is shown, with its day when it is not the '
      'workout\'s day', (tester) async {
    await prepare(tester, weighIn: false);
    await h.real(tester, () async {
      await h.db.saveWeight(190, UnitSystem.imperial, at('2026-11-09', 7, 0));
    });
    await finish(tester);
    expect(
      find.text('MET 3.5, 190.0 lb (weighed Nov 9), 52 min'),
      findsOneWidget,
    );
    // 3.5 x 190 lb x 52 min is 261 kcal.
    expect(find.textContaining('261 kcal'), findsOneWidget);
  });

  h.appTest('the calories are added to the day\'s budget only when the '
      'workout is finished, at the add-back setting', (tester) async {
    await prepare(tester, goals: true);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    // Running: nothing is added, even though sets are logged.
    expect(find.text('2,000'), findsOneWidget);
    expect(find.text('Goal 2,000 + exercise 0 - food 0'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    await finish(tester);
    expect(find.text("Added to today's budget at 100%."), findsOneWidget);
    await tester.tap(button('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Goal 2,000 + exercise 250 - food 0'), findsOneWidget);
    expect(find.text('2,250'), findsOneWidget);
  });

  h.appTest('with no goals the summary says the budget needs them', (
    tester,
  ) async {
    await prepare(tester);
    await finish(tester);
    expect(
      find.text('Set your goals to add this to your budget.'),
      findsOneWidget,
    );
  });

  h.appTest('metric shows kilograms everywhere on the summary', (tester) async {
    await h.real(tester, () => h.db.setUnits(UnitSystem.metric));
    await prepare(tester);
    await finish(tester);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('2,957'), findsOneWidget);
    expect(find.text('Bench press, 81.6 kg x 8'), findsOneWidget);
    expect(find.text('Heaviest weight: 81.6 kg (was 79.4 kg)'), findsOneWidget);
    expect(
      find.text('Estimated 1-rep max: 103.4 kg (was 100.5 kg)'),
      findsOneWidget,
    );
    expect(find.text('MET 3.5, 82.5 kg, 52 min'), findsOneWidget);
    expect(find.textContaining(' lb'), findsNothing);
  });

  h.appTest('a workout with nothing logged finishes with no time and no '
      'estimate, and can be resumed', (tester) async {
    await prepare(tester, logged: 0);
    await finish(tester);
    expect(find.text('0 min'), findsOneWidget);
    expect(find.text('No estimate.'), findsOneWidget);
    expect(find.text('6 planned sets not logged, removed'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect((await row(tester)).endedAtMs, isNull);
  });

  h.appTest('Resume is refused in plain words while another workout runs', (
    tester,
  ) async {
    await prepare(tester);
    await finish(tester);
    await tester.runAsync(() => h.db.startEmptyWorkout(h.now));
    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(
      find.textContaining('Another workout is running, so this one cannot'),
      findsOneWidget,
    );
    expect(find.text('Workout done'), findsOneWidget);
  });

  h.appTest('the summary is read from the database: closing the app on it '
      'loses nothing', (tester) async {
    await prepare(tester);
    await finish(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await h.openApp(tester);
    // Finished, so nothing offers a return.
    expect(find.widgetWithText(TextButton, 'Return'), findsNothing);
    final w = await row(tester);
    expect(w.endedAtMs, isNotNull);
    expect(w.kcalEstimated, closeTo(250.1, 0.1));
    await h.openWorkoutsTab(tester);
    expect(find.text('Today'), findsWidgets);
  });

  for (final size in [const Size(344, 700), const Size(673, 700)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp and text scale $scale: no '
          'overflow, every button 48 dp', (tester) async {
        await prepare(tester, logged: 5, size: size, scale: scale);
        await finish(tester);
        for (final f in [
          find.widgetWithText(TextButton, 'Resume'),
          find.widgetWithText(TextButton, 'Change'),
          button('Done'),
        ]) {
          await tester.ensureVisible(f);
          await tester.pump();
          final s = tester.getSize(f);
          expect(s.height, greaterThanOrEqualTo(48), reason: '$f');
          expect(s.width, greaterThanOrEqualTo(48), reason: '$f');
        }
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -3000),
        );
        await tester.pump();
      });
    }
  }
  h.appTest('Change, then Save with the number untouched, writes nothing and '
      'keeps the estimate', (tester) async {
    await prepare(tester);
    await finish(tester);
    await tester.tap(find.text('Change'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect((await row(tester)).kcalOverride, isNull);
    expect(find.text('250 kcal estimate'), findsOneWidget);
  });

  h.appTest('a weigh-in after the workout day is not used, also for a '
      'workout finished after midnight', (tester) async {
    final ids = await h.seedSample(tester);
    final start = at('2026-11-11', 23, 30); // Wed
    final id = await h.real(tester, () async {
      await h.db.saveWeight(181.8, UnitSystem.imperial, at('2026-11-10', 7, 0));
      // Thursday, after the workout's day: must not be used.
      await h.db.saveWeight(250, UnitSystem.imperial, at('2026-11-12', 0, 5));
      final r = await h.db.startRoutine(ids.pushId, start);
      final first = (await h.db.loadWorkout(r.workout!.id))!.nextSet!;
      await h.db.logSet(
        first.row.id,
        Now(utcMs: start.utcMs + 22 * 60000, offsetMinutes: -360),
      );
      return r.workout!.id;
    });
    h.now = at('2026-11-12', 0, 20); // Thu, 00:20
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('MET 3.5, 181.8 lb (weighed Nov 10), 22 min'),
      findsOneWidget,
    );
    expect(find.textContaining('250.0 lb'), findsNothing);
    final w = await h.real(
      tester,
      () => (h.db.select(
        h.db.workouts,
      )..where((x) => x.id.equals(id))).getSingle(),
    );
    expect(w.localDate, '2026-11-11');
    expect(w.kcalEstimated, closeTo(3.5 * lbToKg(181.8) * 22 / 60, 1e-9));
  });
}
