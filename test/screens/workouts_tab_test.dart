// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/seams.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../speed/tap_counter.dart';
import 'workouts_harness.dart';

// The Workouts tab (task 4.3, workout.html frame 1): "Start again" in the data
// layer's order, the routines, an empty workout, the weekly volume card,
// "Return to workout", and the refusals of a start.

void main() {
  final h = WorkoutHarness()..register();

  tearDown(() {
    WorkoutSeams.exercisePicker = null;
    WorkoutSeams.exerciseDetail = null;
    WorkoutSeams.routineEditor = null;
    WorkoutSeams.exercises = null;
    WorkoutSeams.weeklyVolume = null;
  });

  Finder startButton(int index) =>
      find.widgetWithText(FilledButton, 'Start').at(index);

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await settle(tester);
    }
  }

  Future<void> openTab(
    WidgetTester tester, {
    Size? size,
    double scale = 1,
  }) async {
    await h.openApp(
      tester,
      size: size ?? const Size(400, 800),
      textScale: scale,
    );
    await h.openWorkoutsTab(tester);
  }

  h.appTest('the Workouts tab is a real tab now', (tester) async {
    await h.openApp(tester);
    final tab = tester.widget<NavigationDestination>(
      find.widgetWithText(NavigationDestination, 'Workouts'),
    );
    expect(tab.enabled, isTrue);
    await h.openWorkoutsTab(tester);
    expect(find.text('Workouts'), findsWidgets);
  });

  h.appTest('Start again lists yesterday first, then last week, then the '
      'routines, each with the day named', (tester) async {
    await h.seedSample(tester);
    await openTab(tester);

    expect(find.text('Start again'), findsOneWidget);
    expect(find.text('Yesterday, Wed, Nov 11'), findsOneWidget);
    expect(find.text('1 exercise, 3 sets, 48 min'), findsOneWidget);
    expect(find.text('Last Thursday, Nov 5'), findsOneWidget);
    expect(find.text('2 exercises, 6 sets, 52 min'), findsOneWidget);
    final yesterday = tester.getTopLeft(find.text('Yesterday, Wed, Nov 11'));
    final lastWeek = tester.getTopLeft(find.text('Last Thursday, Nov 5'));
    expect(yesterday.dy, lessThan(lastWeek.dy));

    expect(find.text('Routines'), findsOneWidget);
    expect(find.text('Bench press, Overhead press'), findsOneWidget);
    expect(find.text('Empty workout'), findsOneWidget);
    // Four Start buttons: two to start again, two routines.
    expect(find.widgetWithText(FilledButton, 'Start'), findsNWidgets(4));
  });

  h.appTest('one counted tap on a Start again row opens the workout with '
      'every set prefilled from last time (speed target 4)', (tester) async {
    await h.seedSample(tester);
    await openTab(tester);
    final taps = TapCounter(tester);

    await taps.tap(startButton(0)); // yesterday: Legs
    await settle(tester);
    taps.expectCount(1, flow: 'Start yesterday\'s workout');

    // Straight into the active screen.
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('225 lb'), findsNWidgets(3));
    expect(find.text('5 reps'), findsNWidgets(3));
    expect(find.text('Finish'), findsOneWidget);

    final rows = await h.workoutRows(tester);
    final running = rows.where((w) => w.endedAtMs == null).single;
    final sets = await h.allSets(tester, running.id);
    expect(sets, hasLength(3));
    for (final s in sets) {
      expect(s.weightKg, closeTo(lbToKg(225), 1e-9));
      expect(s.reps, 5);
      expect(s.completedAtMs, isNull);
    }
  });

  h.appTest('one counted tap on last week\'s workout starts it prefilled, '
      'and one on a routine does too', (tester) async {
    await h.seedSample(tester);
    await openTab(tester);
    final taps = TapCounter(tester);

    await taps.tap(startButton(1)); // last Thursday: Push A
    await settle(tester);
    taps.expectCount(1, flow: 'Start last week\'s workout');
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('175 lb'), findsNWidgets(3));
    expect(find.text('7 reps'), findsOneWidget);
    expect(find.text('95 lb'), findsNWidgets(3));

    // Back to the tab: a workout is running, so only Return is offered.
    await h.back(tester);
    expect(find.widgetWithText(FilledButton, 'Start'), findsNothing);
    expect(find.text('Return to workout'), findsOneWidget);
  });

  h.appTest('a routine starts in one tap, prefilled from the last time each '
      'exercise was done', (tester) async {
    await h.seedSample(tester);
    await openTab(tester);
    final taps = TapCounter(tester);

    await taps.tap(startButton(3)); // routine Legs
    await settle(tester);
    taps.expectCount(1);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('225 lb'), findsNWidgets(3));
  });

  h.appTest('an empty workout starts with no exercises, and no Add exercise '
      'button until the picker exists', (tester) async {
    await openTab(tester);
    expect(find.text('No routines yet.'), findsOneWidget);
    await tester.tap(find.text('Empty workout'));
    await settle(tester);

    expect(find.text('No exercises yet.'), findsOneWidget);
    expect(find.text('+ Add exercise'), findsNothing);
    final rows = await h.workoutRows(tester);
    expect(rows.single.routineId, isNull);
    expect(rows.single.endedAtMs, isNull);
  });

  h.appTest('the seams to task 4.4 show nothing until they are filled in', (
    tester,
  ) async {
    await h.seedSample(tester);
    await openTab(tester);
    expect(find.text('+ New routine'), findsNothing);
    expect(find.text('Exercises'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });

  h.appTest('a filled seam shows its control and calls through', (
    tester,
  ) async {
    await h.seedSample(tester);
    final calls = <String>[];
    WorkoutSeams.routineEditor = (context, {routineId}) =>
        calls.add('editor $routineId');
    WorkoutSeams.exercises = (context) => calls.add('exercises');
    await openTab(tester);
    await tester.tap(find.text('+ New routine'));
    await tester.tap(find.text('Exercises'));
    await tester.tap(find.text('Edit').first);
    expect(calls, hasLength(3));
    expect(calls[0], 'editor null');
    expect(calls[1], 'exercises');
    expect(calls[2], startsWith('editor '));
    expect(calls[2], isNot('editor null'));
  });

  h.appTest('this week, sets by muscle: every group, most sets first, with '
      'the number beside each bar', (tester) async {
    await h.real(tester, () async {
      await insertUserExercises(h);
      await h.doWorkout('2026-11-09', [
        ('local:1', 'Test press', [(100, 5), (100, 5), (100, 5)]),
      ]);
      await h.doWorkout('2026-11-11', [
        ('local:2', 'Test row', [(100, 5), (100, 5)]),
      ]);
      // The Sunday before this week does not count.
      await h.doWorkout('2026-11-08', [
        ('local:1', 'Test press', [(100, 5)]),
      ]);
    });
    await openTab(tester);
    await waitFor(tester, find.text('This week, sets by muscle'));
    await waitFor(tester, find.text('3 sets'));

    expect(find.text('3 sets'), findsOneWidget);
    expect(find.text('2 sets'), findsOneWidget);
    expect(find.text('0 sets'), findsNWidgets(8));
    final chest = tester.getTopLeft(find.text('Chest')).dy;
    final back = tester.getTopLeft(find.text('Back')).dy;
    final shoulders = tester.getTopLeft(find.text('Shoulders')).dy;
    final abs = tester.getTopLeft(find.text('Abs')).dy;
    expect(chest, lessThan(back));
    expect(back, lessThan(shoulders));
    expect(shoulders, lessThan(abs));
    expect(find.byType(LinearProgressIndicator), findsNWidgets(10));
  });

  h.appTest('the weekly card opens the weekly volume screen only when '
      'task 4.4 has put it there', (tester) async {
    await openTab(tester);
    await waitFor(tester, find.text('This week, sets by muscle'));
    expect(
      find.ancestor(of: find.text('Chest'), matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  h.appTest('a filled weekly volume seam makes the card open that screen', (
    tester,
  ) async {
    var opened = 0;
    WorkoutSeams.weeklyVolume = (context) => opened++;
    await openTab(tester);
    await waitFor(tester, find.text('Chest'));
    await tester.tap(find.text('Chest'));
    await tester.pump();
    expect(opened, 1);
  });

  h.appTest('a workout running from today replaces every Start with one '
      'Return to workout', (tester) async {
    final ids = await h.seedSample(tester);
    await h.real(tester, () => h.db.startRoutine(ids.pushId, h.now));
    await openTab(tester);

    expect(find.widgetWithText(FilledButton, 'Start'), findsNothing);
    expect(find.text('Empty workout'), findsNothing);
    expect(find.text('Start again'), findsNothing);
    expect(find.text('Return to workout'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Workout running, 0 min'), findsOneWidget);

    await tester.tap(find.text('Return to workout'));
    await settle(tester);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });

  h.appTest('a start refused because today\'s workout runs says so and '
      'offers Return, and starts nothing', (tester) async {
    final ids = await h.seedSample(tester);
    await openTab(tester);
    // A workout starts somewhere else after the tab was drawn. The tab still
    // shows its Start buttons for a moment; tapping one is refused.
    await tester.runAsync(() => h.db.startRoutine(ids.pushId, h.now));
    await tester.tap(startButton(0));
    await settle(tester);

    expect(
      find.textContaining('A workout is already running today'),
      findsOneWidget,
    );
    final rows = await h.workoutRows(tester);
    expect(rows.where((w) => w.endedAtMs == null), hasLength(1));
    expect(rows, hasLength(3));

    await tester.tap(find.widgetWithText(TextButton, 'Return to workout').last);
    await settle(tester);
    expect(find.text('Bench press'), findsOneWidget);
  });

  h.appTest('a workout left running from an earlier day is named, still '
      'offered, and finished by a new start, which says so', (tester) async {
    final ids = await h.seedSample(tester);
    final oldId = await h.real(tester, () async {
      final r = await h.db.startRoutine(
        ids.pushId,
        at('2026-11-09', 17, 0), // Monday
      );
      final set = (await h.db.loadWorkout(r.workout!.id))!.nextSet!;
      await h.db.logSet(set.row.id, at('2026-11-09', 17, 10));
      return r.workout!.id;
    });
    await openTab(tester);

    expect(find.text("Return to Monday's workout"), findsOneWidget);
    expect(find.text("Monday's workout is still running."), findsOneWidget);
    // A start is allowed, so the lists stay.
    expect(find.widgetWithText(FilledButton, 'Start'), findsWidgets);

    await tester.tap(startButton(0)); // Legs, yesterday
    await settle(tester);
    expect(find.text('Squat'), findsOneWidget);
    await h.back(tester);

    expect(
      find.text(
        "Monday's workout was still running, so it was finished first. "
        'Nothing was lost.',
      ),
      findsOneWidget,
    );
    final rows = await h.workoutRows(tester);
    final old = rows.firstWhere((w) => w.id == oldId);
    expect(old.endedAtMs, isNotNull);
    final oldSets = await h.allSets(tester, oldId);
    expect(oldSets.where((s) => s.completedAtMs != null), hasLength(1));
    expect(rows.where((w) => w.endedAtMs == null), hasLength(1));
  });

  h.appTest('a double tap on a Start again row starts one workout', (
    tester,
  ) async {
    await h.seedSample(tester);
    await openTab(tester);
    await tester.tap(startButton(0));
    await tester.tap(startButton(0));
    await settle(tester);

    final rows = await h.workoutRows(tester);
    expect(rows, hasLength(3));
    expect(rows.where((w) => w.endedAtMs == null), hasLength(1));
    expect(find.text('Squat'), findsOneWidget);
    // One screen, not two.
    await h.back(tester);
    expect(find.text('Squat'), findsNothing);
    expect(find.text('Return to workout'), findsOneWidget);
  });

  h.appTest('left open past midnight, Start again is worked out for the new '
      'day', (tester) async {
    await h.seedSample(tester);
    await openTab(tester);
    expect(find.text('Yesterday, Wed, Nov 11'), findsOneWidget);

    h.now = at('2026-11-13', 0, 1);
    await tester.pump(const Duration(hours: 7));
    await settle(tester);
    // Wed, Nov 11 is no longer yesterday, and nothing was done on Nov 12.
    expect(find.text('Yesterday, Wed, Nov 11'), findsNothing);
    expect(find.text('Wed, Nov 11'), findsOneWidget);
    expect(find.text('Last Thursday, Nov 5'), findsNothing);
  });

  h.appTest('every Start has a spoken label that says what it starts', (
    tester,
  ) async {
    await h.seedSample(tester);
    final handle = tester.ensureSemantics();
    await openTab(tester);
    expect(
      find.bySemanticsLabel('Start Legs, Yesterday, Wed, Nov 11'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Start Push A, Last Thursday, Nov 5'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Start Push A'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Start Push A'))
          .flagsCollection
          .isButton,
      isTrue,
    );
    handle.dispose();
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp and text scale $scale: '
          'nothing overflows and every target is 48 dp', (tester) async {
        await h.seedSample(tester);
        await h.real(
          tester,
          () => h.doWorkout('2026-11-09', [
            (
              'local:1',
              'A very long exercise name that goes on and on',
              [(100, 5)],
            ),
          ]),
        );
        await openTab(tester, size: size, scale: scale);
        for (final f in [
          find.widgetWithText(FilledButton, 'Start'),
          find.widgetWithText(OutlinedButton, 'Empty workout'),
        ]) {
          for (var i = 0; i < f.evaluate().length; i++) {
            final box = tester.getSize(f.at(i));
            expect(box.height, greaterThanOrEqualTo(48));
            expect(box.width, greaterThanOrEqualTo(48));
          }
        }
        // The page scrolls to the end with nothing cut off.
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
      });
    }
  }

  h.appTest('workout weights follow the units setting', (tester) async {
    await h.real(tester, () => h.db.setUnits(UnitSystem.metric));
    await h.seedSample(tester);
    await openTab(tester);
    await tester.tap(startButton(0));
    await settle(tester);
    // 225 lb is 102.1 kg.
    expect(find.text('102.1 kg'), findsNWidgets(3));
    expect(find.textContaining(' lb'), findsNothing);
  });
}

/// Two exercises of the user's own: a chest one and a back one.
Future<void> insertUserExercises(WorkoutHarness h) async {
  await h.db
      .into(h.db.exercises)
      .insert(
        ExercisesCompanion.insert(
          name: 'Test press',
          primaryMuscles: const Value('Chest'),
        ),
      );
  await h.db
      .into(h.db.exercises)
      .insert(
        ExercisesCompanion.insert(
          name: 'Test row',
          primaryMuscles: const Value('Lats'),
        ),
      );
}
