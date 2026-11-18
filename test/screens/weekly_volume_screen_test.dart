// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/exercise_library.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_harness.dart';

// The weekly volume screen (task 4.4, exercise-detail.html frame 2): this week
// so far and the two weeks before, Monday to Sunday, completed sets of each of
// the ten groups, primary muscles only. Today is Thu, Nov 12, so the weeks
// start on Nov 9, Nov 2 and Oct 26.

void main() {
  final h = WorkoutHarness()..register();

  const bench = 'wger:73'; // Chest

  /// A library exercise whose primary muscles are in [group] only.
  Future<LibraryExercise> only(VolumeGroup group) async {
    final lib = await ExerciseLibrary.load();
    return lib.all.firstWhere(
      (e) => e.groups.length == 1 && e.groups.single == group,
    );
  }

  Future<void> seed(WidgetTester tester) => h.real(tester, () async {
    final quads = await only(VolumeGroup.quads);
    await h.doWorkout('2026-11-10', [
      (bench, 'Bench Press', [(100, 5), (100, 5), (100, 5)]),
    ]);
    // Sunday Nov 8 is in the week of Nov 2.
    await h.doWorkout('2026-11-08', [
      (quads.ref, quads.name, [(100, 5)]),
    ]);
    await h.doWorkout('2026-11-03', [
      (bench, 'Bench Press', [(100, 5), (100, 5)]),
    ]);
    await h.doWorkout('2026-10-27', [
      (bench, 'Bench Press', [(100, 5)]),
    ]);
    // Sunday Oct 25 is the week before the three shown.
    await h.doWorkout('2026-10-25', [
      (bench, 'Bench Press', [(100, 5), (100, 5), (100, 5), (100, 5)]),
    ]);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await h.openApp(tester, size: size, textScale: scale);
    await h.openWorkoutsTab(tester);
    await settle(tester);
    for (
      var i = 0;
      i < 20 && find.text('This week, sets by muscle').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('This week, sets by muscle'));
    await tester.pump();
    await tester.tap(find.text('This week, sets by muscle'));
    await waitFor(tester, find.text('Oct 26'));
  }

  h.appTest('a tap on the weekly card opens the table: ten groups, this '
      'week and the two weeks before, with the numbers', (tester) async {
    await seed(tester);
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(find.widgetWithText(AppBar, 'Sets by muscle'), findsOneWidget);
    expect(
      find.text('Completed sets, primary muscles only, Monday to Sunday.'),
      findsOneWidget,
    );
    expect(find.text('This week\nso far'), findsOneWidget);
    expect(find.text('Nov 2'), findsOneWidget);
    expect(find.text('Oct 26'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Chest: this week so far 3 sets, week of Nov 2 2 sets, week of '
        'Oct 26 1 set',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Quads: this week so far 0 sets, week of Nov 2 1 set, week of '
        'Oct 26 0 sets',
      ),
      findsOneWidget,
    );
    // All ten groups are listed, glutes and abs too.
    for (final g in [
      'Chest',
      'Shoulders',
      'Triceps',
      'Back',
      'Biceps',
      'Quads',
      'Hamstrings',
      'Glutes',
      'Calves',
      'Abs',
    ]) {
      expect(find.text(g), findsOneWidget, reason: g);
    }
    handle.dispose();
  });

  h.appTest('the week before the three shown is not counted', (tester) async {
    await seed(tester);
    final handle = tester.ensureSemantics();
    await open(tester);
    // Oct 25 has four sets: none of them appear in any column.
    expect(find.bySemanticsLabel(RegExp(r'Chest.* 4 sets')), findsNothing);
    handle.dispose();
  });

  h.appTest('a set of an exercise of the user counts under its muscle', (
    tester,
  ) async {
    await h.real(tester, () async {
      final lib = await ExerciseLibrary.load();
      final mine = await h.db.createExercise(lib, 'Zq pull', primary: ['Lats']);
      await h.doWorkout('2026-11-10', [
        (mine.ref, mine.name, [(100, 5), (100, 5)]),
      ]);
    });
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(
      find.bySemanticsLabel(
        'Back: this week so far 2 sets, week of Nov 2 0 sets, week of '
        'Oct 26 0 sets',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  h.appTest('completed sets of a workout still running count, and a set '
      'not yet done does not', (tester) async {
    await h.real(tester, () async {
      final id = (await h.db.startEmptyWorkout(h.now)).workout!.id;
      await h.db.addExercise(id, bench, 'Bench Press', sets: 3);
      final rows = (await h.db.loadWorkout(id))!.exercises.single.sets
          .map((s) => s.row.id)
          .toList();
      for (final r in rows.take(2)) {
        await h.db.adjustSet(r, weightKg: 50, reps: 5);
        await h.db.logSet(r, h.now);
      }
    });
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(
      find.bySemanticsLabel(
        'Chest: this week so far 2 sets, week of Nov 2 0 sets, week of '
        'Oct 26 0 sets',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp, text scale $scale: '
          'nothing overflows and every group can be reached', (tester) async {
        await seed(tester);
        await open(tester, size: size, scale: scale);
        final list = find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Abs'),
          200,
          scrollable: list,
        );
        expect(find.text('Abs'), findsOneWidget);
      });
    }
  }
}
