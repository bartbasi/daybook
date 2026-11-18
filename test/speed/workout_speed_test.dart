// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Speed targets 4 and 5 (docs/design/speed-targets.md, sections 4 and 5):
// start yesterday's or last week's workout, or a routine, and log a prefilled
// set, in as few taps as the design promises. The whole app runs here, with an
// in-memory database and a fixed clock (Thu, Nov 12, 2026, 5:29 pm). The same
// flow from a new routine runs on a real build in integration_test/
// flows_test.dart. The last group is crash safety: a workout survives the app
// and the database being closed and opened again on a file.
//
// The prefill rule, as the tests below check it (plan row 4.2, speed-targets.md
// section 4, and what startAgain does): "Start again" takes its exercises and
// each exercise's number of sets from that past workout, and each set's weight
// and reps from the last time that exercise was done, which may be a later
// workout than the one copied. Only sets that were logged are copied.

import 'dart:io';

import 'package:daybook/data/database.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/workout_screen.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/flows/workout_flow.dart';
import '../screens/workouts_harness.dart';
import 'tap_counter.dart';

void main() {
  final h = WorkoutHarness()..register();

  Finder startButtons() => find.widgetWithText(FilledButton, 'Start');
  Finder check(WorkoutSet s) => find.byKey(ValueKey('check-${s.id}'));

  /// The workout that is running, with its sets in order.
  Future<(Workout, List<WorkoutSet>)> runningWorkout(
    WidgetTester tester,
  ) async {
    final running = (await h.workoutRows(tester))
        .singleWhere((w) => w.endedAtMs == null);
    return (running, await h.allSets(tester, running.id));
  }

  /// Every set is not done, in the given order, with these (lb, reps).
  void expectPlanned(List<WorkoutSet> sets, List<(String, double, int)> want) {
    expect(sets, hasLength(want.length));
    for (var i = 0; i < want.length; i++) {
      final (ref, lb, reps) = want[i];
      expect(sets[i].exerciseRef, ref, reason: 'set ${i + 1}');
      expect(
        sets[i].weightKg,
        closeTo(lbToKg(lb), 1e-9),
        reason: 'set ${i + 1}',
      );
      expect(sets[i].reps, reps, reason: 'set ${i + 1}');
      expect(sets[i].completedAtMs, isNull, reason: 'set ${i + 1}');
    }
  }

  /// After a Start: the workout screen is open (no "Return" tap is hidden in
  /// the flow) and shows a prefilled weight.
  void expectWorkoutOpen(String weightText) {
    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect(find.text(weightText), findsWidgets);
  }

  /// Last Thursday's workout is not its routine, and a later session of its
  /// exercises has other numbers, so the readings of "prefilled" differ. The
  /// Thursday session at 19:00 (the entry for that day) has 4 bench sets, 2
  /// press sets and a row of 2, where Push A has 3 and 3. Bench and press were
  /// done again on Mon, Nov 9 with other numbers. The row was last done in
  /// the copied workout itself.
  Future<void> seedDiffering(WidgetTester tester) async {
    await h.seedSample(tester);
    await h.real(tester, () async {
      await h.doWorkout('2026-11-05', [
        (bench, 'Bench press', [(175, 8), (175, 8), (175, 7), (170, 6)]),
        (press, 'Overhead press', [(95, 8), (95, 8)]),
        (row, 'Barbell row', [(130, 10), (130, 8)]),
      ], hour: 19);
      await h.doWorkout('2026-11-09', [
        (bench, 'Bench press', [(180, 5)]),
        (press, 'Overhead press', [(100, 6), (100, 5)]),
      ]);
    });
  }

  /// The button must be in view without scrolling, on a phone 800 dp high.
  void expectInView(WidgetTester tester, Finder f) {
    final r = tester.getRect(f);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(800));
  }

  /// Waits, a few rounds at most, until [f] is inside the set list's visible
  /// part (above the rest bar).
  Future<void> untilInView(WidgetTester tester, Finder f) async {
    final list = find.byType(SingleChildScrollView).first;
    for (var i = 0; i < 10; i++) {
      final r = tester.getRect(f);
      final l = tester.getRect(list);
      if (r.top >= l.top - 0.5 && r.bottom <= l.bottom + 0.5) return;
      await settle(tester);
    }
    fail('The next set was not scrolled into view above the rest bar');
  }

  group('target 4: start a past workout or a routine', () {
    h.appTest('1 counted tap starts yesterday\'s workout, every set prefilled '
        'in the database', (tester) async {
      await h.seedSample(tester);
      await h.openApp(tester);
      await h.openWorkoutsTab(tester);
      // The first Start under "Start again" is yesterday's (Legs).
      expect(find.text('Yesterday, Wed, Nov 11'), findsOneWidget);
      expectInView(tester, startButtons().at(0));
      final taps = TapCounter(tester);
      await taps.tap(startButtons().at(0));
      await settle(tester);
      taps.expectCount(1, flow: 'Start yesterday\'s workout');
      expectWorkoutOpen('225 lb');

      final (w, sets) = await runningWorkout(tester);
      expect(w.localDate, '2026-11-12');
      expectPlanned(sets, [(squat, 225, 5), (squat, 225, 5), (squat, 225, 5)]);
    });

    h.appTest('1 counted tap starts last week\'s workout: its exercises and '
        'set counts, and the numbers from the last time of each', (
      tester,
    ) async {
      await seedDiffering(tester);
      await h.openApp(tester);
      await h.openWorkoutsTab(tester);
      expect(find.text('Last Thursday, Nov 5'), findsOneWidget);
      expectInView(tester, startButtons().at(1));
      final taps = TapCounter(tester);
      await taps.tap(startButtons().at(1));
      await settle(tester);
      taps.expectCount(1, flow: 'Start last week\'s workout');
      expectWorkoutOpen('180 lb');

      final (w, sets) = await runningWorkout(tester);
      expect(w.localDate, '2026-11-12');
      expectPlanned(sets, [
        // 4 bench sets, as in that workout (the routine has 3), with the
        // numbers of the Nov 9 session, whose one set is copied to all four.
        (bench, 180, 5),
        (bench, 180, 5),
        (bench, 180, 5),
        (bench, 180, 5),
        // 2 press sets, with the Nov 9 numbers set by set.
        (press, 100, 6),
        (press, 100, 5),
        // The row is not in the routine. Its last time is that workout.
        (row, 130, 10),
        (row, 130, 8),
      ]);
    });

    h.appTest('1 counted tap on a routine\'s Start prefills each exercise '
        'from the last time that exercise was done', (tester) async {
      final ids = await h.seedSample(tester);
      // Older bench, and a later overhead press of one set, so "the last time
      // each exercise was done" is not simply the last Push A.
      await h.real(tester, () async {
        await h.doWorkout('2026-10-20', [
          (bench, 'Bench press', [(185, 6)]),
        ]);
        await h.doWorkout('2026-11-09', [
          (press, 'Overhead press', [(100, 5)]),
        ]);
      });
      await h.openApp(tester);
      await h.openWorkoutsTab(tester);
      final start = find.descendant(
        of: find.byKey(ValueKey('routine-${ids.pushId}')),
        matching: find.widgetWithText(FilledButton, 'Start'),
      );
      final taps = TapCounter(tester);
      await taps.tap(start);
      await settle(tester);
      taps.expectCount(1, flow: 'Start a routine');
      expectWorkoutOpen('175 lb');

      final (w, sets) = await runningWorkout(tester);
      expect(w.routineId, ids.pushId);
      expectPlanned(sets, [
        (bench, 175, 8),
        (bench, 175, 8),
        (bench, 175, 7),
        // Last time was one set, so the others copy it.
        (press, 100, 5),
        (press, 100, 5),
        (press, 100, 5),
      ]);
    });

    h.appTest('from Home it is 2 counted taps: the Workouts tab, then '
        'Start', (tester) async {
      await h.seedSample(tester);
      await h.openApp(tester); // on Home
      final taps = TapCounter(tester);
      await taps.tap(find.widgetWithText(NavigationDestination, 'Workouts'));
      await settle(tester);
      expectInView(tester, startButtons().at(0));
      await taps.tap(startButtons().at(0));
      await settle(tester);
      taps.expectCount(2, flow: 'Home, Workouts, Start');
      expectWorkoutOpen('225 lb');

      final (_, sets) = await runningWorkout(tester);
      expectPlanned(sets, [(squat, 225, 5), (squat, 225, 5), (squat, 225, 5)]);
    });
  });

  group('target 5: log a prefilled set', () {
    /// Push A running, its screen open.
    Future<List<WorkoutSet>> openPush(
      WidgetTester tester, {
      Size size = const Size(400, 800),
    }) async {
      final ids = await h.seedSample(tester);
      final r = await h.real(
        tester,
        () => h.db.startRoutine(ids.pushId, h.now),
      );
      await h.openApp(tester, size: size);
      await tester.tap(find.widgetWithText(TextButton, 'Return'));
      await settle(tester);
      return h.allSets(tester, r.workout!.id);
    }

    h.appTest('1 counted tap on the check stores the set with its weight, '
        'reps and the time, and starts the rest', (tester) async {
      final all = await openPush(tester);
      expectInView(tester, check(all.first));
      final taps = TapCounter(tester);
      await taps.tap(check(all.first));
      await settle(tester);
      taps.expectCount(1, flow: 'Log a prefilled set');

      final after = await h.allSets(tester, all.first.workoutId);
      expect(after.first.weightKg, closeTo(lbToKg(175), 1e-9));
      expect(after.first.reps, 8);
      expect(after.first.completedAtMs, h.now.utcMs);
      expect(
        after.skip(1).every((s) => s.completedAtMs == null),
        isTrue,
        reason: 'only the one set',
      );
      expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      // Nothing was asked of the phone on the way.
      expect(h.permissionCalls, isEmpty);
    });

    h.appTest('a whole small workout: one tap per set, plus Finish', (
      tester,
    ) async {
      // A short phone, so the list has to scroll to the next set by itself.
      final all = await openPush(tester, size: const Size(400, 600));
      final taps = TapCounter(tester);
      for (final s in all) {
        // After a log the list scrolls to the next set. The scroll starts
        // when the database answers, so wait (a few rounds at most) for it:
        // a tap on a set that is under the rest bar would hit Skip.
        await untilInView(tester, check(s));
        await taps.tap(check(s));
        await settle(tester);
      }
      await taps.tap(find.widgetWithText(FilledButton, 'Finish'));
      await settle(tester);
      taps.expectCount(all.length + 1, flow: '6 sets and Finish');
      expect(all, hasLength(6));

      final after = await h.allSets(tester, all.first.workoutId);
      expect(after.every((s) => s.completedAtMs != null), isTrue);
      expect(
        [for (final s in after) s.reps],
        [8, 8, 7, 8, 8, 8],
        reason: 'the numbers are last time\'s, untouched',
      );
      expect(find.text('Workout done'), findsOneWidget);
      final open = (await h.workoutRows(tester))
          .where((w) => w.endedAtMs == null);
      expect(open, isEmpty, reason: 'Finish ended the workout');
    });
  });

  group('crash safety', () {
    h.appTest('a workout survives the app and the database being closed and '
        'opened again on a file, with two sets done', (tester) async {
      final dir = Directory.systemTemp.createTempSync('daybook_crash_');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      final file = File('${dir.path}${Platform.pathSeparator}daybook.sqlite');
      // The harness opened an in-memory database. Use one on a file instead.
      h.db = AppDatabase(NativeDatabase(file));

      final ids = await h.seedSample(tester);
      final started = await h.real(
        tester,
        () => h.db.startRoutine(ids.pushId, h.now),
      );
      final workoutId = started.workout!.id;
      await h.openApp(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Return'));
      await settle(tester);
      final before = await h.allSets(tester, workoutId);
      // A second connection to the file sees only what is committed, so it
      // shows each set was stored when its tap finished, not at close.
      final reader = AppDatabase(NativeDatabase(file));
      addTearDown(() => reader.close());
      Future<List<WorkoutSet>> committed(WidgetTester tester) => h.real(
        tester,
        () =>
            (reader.select(reader.workoutSets)
                  ..where((s) => s.workoutId.equals(workoutId))
                  ..orderBy([(s) => OrderingTerm.asc(s.position)]))
                .get(),
      );
      expect(
        (await committed(tester)).where((s) => s.completedAtMs != null),
        isEmpty,
      );
      var done = 0;
      for (final s in before.take(2)) {
        await tester.tap(check(s));
        await settle(tester);
        done++;
        expect(
          (await committed(tester)).where((s) => s.completedAtMs != null),
          hasLength(done),
          reason: 'set $done is committed when its tap is over',
        );
      }
      final logged = await h.allSets(tester, workoutId);
      expect(logged.where((s) => s.completedAtMs != null), hasLength(2));
      expect(await committed(tester), logged);

      // The "restart": the app is taken off the screen, the database is
      // closed, and a new database object opens the same file with a new app
      // over it. Nothing is kept in memory, and the rest timer, which lives
      // in the app, is gone with the old one.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(h.db.close);
      h.db = AppDatabase(NativeDatabase(file));
      await h.openApp(tester);

      // Every column of every set is as it was.
      final after = await h.allSets(tester, workoutId);
      expect(after, logged);
      expect(after.where((s) => s.completedAtMs != null), hasLength(2));
      expect(after.where((s) => s.completedAtMs == null), hasLength(4));

      // Home offers Return.
      expect(find.widgetWithText(TextButton, 'Return'), findsOneWidget);
      // So does the Workouts tab, and no Start is offered while it runs.
      await h.openWorkoutsTab(tester);
      expect(find.text('Return to workout'), findsOneWidget);
      expect(startButtons(), findsNothing);

      // It opens with both sets done and the rest still planned, and goes on.
      await tester.tap(find.text('Return to workout'));
      await settle(tester);
      // The rest timer lived in the old app, so no rest shows.
      expect(find.textContaining('Rest '), findsNothing);
      expect(find.text('Done'), findsNWidgets(2));
      for (final s in after.skip(2)) {
        expect(check(s), findsOneWidget);
      }
      await tester.ensureVisible(check(after[2]));
      await tester.pump();
      await tester.tap(check(after[2]));
      await settle(tester);
      final last = await h.allSets(tester, workoutId);
      expect(last.where((s) => s.completedAtMs != null), hasLength(3));
    });
  });

  h.appTest('the device flow runs here as it runs on a device, under the '
      'fixed clock and an in-memory database', (tester) async {
    await h.openApp(tester);
    await runWorkoutFlow(tester);
    expect(h.permissionCalls, isEmpty);
  });
}
