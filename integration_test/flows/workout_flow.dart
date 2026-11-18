// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The workout flow (speed targets 4 and 5) on a real build or in the whole
// app, written once and used twice: by test/speed/workout_speed_test.dart (an
// in-memory database) and by integration_test/flows_test.dart (a real build,
// the real database). Like the other flows it finds widgets by type and by
// their words, reads the database through the app's own AppScope, and looks
// only at the rows its own steps added. Every tap goes through the
// TapCounter. Typing is not a tap.
//
// It never taps "Alert me when rest ends": that would ask the phone for a
// permission, and the system dialog would stop the test.
//
// It needs no workout running on the device: a running workout hides every
// Start button. Other history is fine, because the flow looks only at its own
// rows. It checks the database and the workout screen, not Home's calories,
// because goals are not guaranteed to be set. It ends on Home, as the header
// of flows_test.dart says each flow must start from there.

import 'package:daybook/data/database.dart';
import 'package:daybook/screens/workouts/exercise_picker.dart';
import 'package:daybook/screens/workouts/workout_screen.dart';
import 'package:daybook/strings.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/speed/tap_counter.dart';
import 'weight_flow.dart' show appDatabase, waitFor;

late AppDatabase _db;

// The height of the on-screen keyboard to simulate while a text field has the
// cursor. Zero on a device, where the real keyboard comes up by itself.
var _keyboardHeight = 0.0;

Future<void> _keyboard(WidgetTester tester, {required bool up}) async {
  if (_keyboardHeight == 0) return;
  if (up) {
    tester.view.viewInsets = FakeViewPadding(bottom: _keyboardHeight);
  } else {
    tester.view.resetViewInsets();
  }
  await tester.pump(const Duration(milliseconds: 100));
}

const _routineName = 'Flow test routine';

// Two exercises that are in assets/exercises/wger_exercises.json.
const _benchRef = 'wger:73';
const _benchName = 'Bench Press';
const _secondRef = 'wger:184';
const _secondName = 'Deadlifts';

/// Pumps, with real time passing for the database, until [done] answers true.
Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() done,
  String what,
) async {
  for (var i = 0; i < 200; i++) {
    if ((await tester.runAsync(done))!) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Gave up waiting for $what');
}

Future<void> _waitForWidget(WidgetTester tester, Finder f, String what) async {
  await waitFor(tester, () => f.evaluate().isNotEmpty, what);
  // Let a route finish sliding in.
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _waitUntilGone(WidgetTester tester, Finder f, String what) async {
  await waitFor(tester, () => f.evaluate().isEmpty, what);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Whether a touch at the centre of [f] would reach it.
bool _hits(WidgetTester tester, Finder f) {
  final target = tester.renderObject(f);
  final hit = tester.hitTestOnBinding(tester.getCenter(f));
  return hit.path.any((e) => identical(e.target, target));
}

/// With a keyboard up on a small screen, a list also scrolls by itself (the
/// field with the cursor is brought back into view), and a list ignores
/// touches while it scrolls like that. A person would tap again a moment
/// later, so this waits, for up to two seconds, until a touch at the centre
/// of [f] would reach it. It does not scroll.
Future<void> _waitForHit(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 20; i++) {
    if (_hits(tester, f)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('A touch on $f would not reach it after 2 seconds');
}

/// One counted tap on something that may be below the fold of a small phone:
/// it is scrolled into view first, then the tap waits for the target to be
/// hittable (see [_waitForHit]).
Future<void> _tap(WidgetTester tester, TapCounter taps, Finder f) async {
  var ready = false;
  for (var i = 0; i < 20 && !ready; i++) {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 100));
    ready = _hits(tester, f);
  }
  if (!ready) fail('A touch on $f would not reach it after 20 tries');
  await taps.tap(f);
  await tester.pump(const Duration(milliseconds: 100));
}

Finder _startIn(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.widgetWithText(FilledButton, S.start),
);

/// The sets of a workout, in order. Plain database call, for inside _until.
Future<List<WorkoutSet>> _rawSets(int workoutId) =>
    (_db.select(_db.workoutSets)
          ..where((s) => s.workoutId.equals(workoutId))
          ..orderBy([(s) => OrderingTerm.asc(s.position)]))
        .get();

Future<List<WorkoutSet>> _setsOf(WidgetTester tester, int workoutId) async =>
    (await tester.runAsync(() => _rawSets(workoutId)))!;

Future<Workout> _workoutRow(WidgetTester tester, int id) async {
  final db = _db;
  return (await tester.runAsync(
    () => (db.select(db.workouts)..where((w) => w.id.equals(id))).getSingle(),
  ))!;
}

Future<Set<int>> _workoutIds(WidgetTester tester) async {
  final db = _db;
  return (await tester.runAsync(
    () async => {for (final w in await db.select(db.workouts).get()) w.id},
  ))!;
}

/// The one workout that is not in [before]. Waits for it.
Future<int> _newWorkout(WidgetTester tester, Set<int> before) async {
  late Set<int> now;
  await _until(tester, () async {
    final db = _db;
    now = {for (final w in await db.select(db.workouts).get()) w.id};
    return now.difference(before).length == 1;
  }, 'one new workout');
  return now.difference(before).single;
}

/// One counted tap on a target of a speed number: it must already be in view
/// without scrolling, as on a phone, so no scroll is hidden in the count.
Future<void> _tapInView(WidgetTester tester, TapCounter taps, Finder f) async {
  final box = tester.getRect(f);
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(
    box.top >= 0 && box.bottom <= view.height,
    isTrue,
    reason:
        'the target is in view without scrolling: ${box.top} to ${box.bottom} '
        'of ${view.height}',
  );
  await _waitForHit(tester, f);
  await taps.tap(f);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Finishes the open workout and closes its summary: Finish, then Done. Two
/// counted taps. Ends on the Workouts tab.
Future<void> _finishAndClose(WidgetTester tester, TapCounter taps) async {
  await _tap(tester, taps, find.widgetWithText(FilledButton, S.finish));
  await _waitForWidget(tester, find.text(S.finishTitle), 'the summary');
  await _tap(tester, taps, find.widgetWithText(FilledButton, S.finishDone));
  await _waitUntilGone(
    tester,
    find.byType(WorkoutScreen),
    'the workout screen to close',
  );
  await _waitForWidget(tester, find.text(S.startAgainTitle), 'Start again');
}

/// Speed targets 4 and 5, then a short check of the whole path from a new
/// routine to "Start again". Never looks at a date. At the end it deletes the
/// workouts and the routine it made, and goes back to Home.
///
/// [keyboard] is for a run without a device: the height (dp) of a keyboard to
/// show while a text field has the cursor, as a phone does. On a device leave
/// it at zero.
Future<void> runWorkoutFlow(WidgetTester tester, {double keyboard = 0}) async {
  _keyboardHeight = keyboard;
  final db = appDatabase(tester);
  // The screens that are pushed over Home hide it from a finder, so the
  // helpers use this handle, taken while Home is on screen.
  _db = db;
  final routinesBefore = (await tester.runAsync(
    () async => {for (final r in await db.select(db.routines).get()) r.id},
  ))!;
  final workoutsBefore = await _workoutIds(tester);
  var taps = TapCounter(tester);

  try {
    // Workouts tab > + New routine.
    await _tap(
      tester,
      taps,
      find.widgetWithText(NavigationDestination, S.tabWorkouts),
    );
    await _waitForWidget(tester, find.text(S.newRoutine), 'the Workouts tab');
    await _tap(tester, taps, find.text(S.newRoutine));

    // Name it. The field has the cursor already, but a tap makes sure.
    final name = find.widgetWithText(TextField, S.routineNameLabel);
    await _waitForWidget(tester, name, 'the routine editor');
    await taps.tap(name);
    await _keyboard(tester, up: true);
    await tester.pump();
    await taps.type(name, _routineName);

    // + Add exercise, then two exercises from the bundled list.
    await _tap(tester, taps, find.text(S.addExercise));
    final search = find.widgetWithText(TextField, S.pickerSearch);
    await _waitForWidget(tester, search, 'the exercise picker');
    for (final (ref, query) in [
      (_benchRef, _benchName),
      (_secondRef, _secondName),
    ]) {
      await _waitForHit(tester, search);
      await taps.tap(search);
      await tester.pump();
      await taps.type(search, query);
      final add = find.descendant(
        of: find.byKey(ValueKey('row-$ref')),
        matching: find.text(S.pickerAdd),
      );
      await _waitForWidget(tester, add, '$query in the list');
      await _tap(tester, taps, add);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await taps.tap(find.byType(BackButton));
    await _waitUntilGone(
      tester,
      find.byType(ExercisePickerScreen),
      'the picker to close',
    );

    // Save. The editor's name field has the cursor again.
    await _tap(tester, taps, find.widgetWithText(FilledButton, S.routineSave));
    await _keyboard(tester, up: false);
    late int routineId;
    await _until(tester, () async {
      final found = [
        for (final r in await db.select(db.routines).get())
          if (!routinesBefore.contains(r.id) && r.name == _routineName) r.id,
      ];
      if (found.length != 1) return false;
      routineId = found.single;
      return true;
    }, 'the routine to be saved');
    final saved = (await tester.runAsync(
      () =>
          (db.select(db.routineExercises)
                ..where((e) => e.routineId.equals(routineId))
                ..orderBy([(e) => OrderingTerm.asc(e.position)]))
              .get(),
    ))!;
    expect([for (final e in saved) e.exerciseRef], [_benchRef, _secondRef]);

    // Start it: one tap on its row.
    final row = 'routine-$routineId';
    await _waitForWidget(tester, find.byKey(ValueKey(row)), 'the routine row');
    await _tap(tester, taps, _startIn(row));
    final firstId = await _newWorkout(tester, workoutsBefore);
    await _waitForWidget(
      tester,
      find.byType(WorkoutScreen),
      'the workout screen',
    );
    var sets = await _setsOf(tester, firstId);
    expect(sets.map((s) => s.exerciseRef).toSet(), {_benchRef, _secondRef});
    expect(sets.every((s) => s.completedAtMs == null), isTrue);

    // The first set. A first-time set has no reps, so type a weight and reps:
    // tap the reps cell, type, Done. If the exercise was done on this phone
    // before, the set already has its numbers and this step is skipped.
    final firstSet = sets.first;
    final typed = firstSet.reps == null;
    if (typed) {
      await _tap(tester, taps, find.text(S.repsCellEmpty).first);
      final reps = find.widgetWithText(TextField, S.setRepsLabel);
      await _waitForWidget(tester, reps, 'the set sheet');
      await taps.tap(reps);
      await _keyboard(tester, up: true);
      await tester.pump();
      await taps.type(reps, '8');
      final weight = find.widgetWithText(TextField, S.setWeightLabel);
      await _waitForHit(tester, weight);
      await taps.tap(weight);
      await tester.pump();
      await taps.type(weight, '135');
      await _tap(
        tester,
        taps,
        find.widgetWithText(FilledButton, S.setSheetDone),
      );
      await _waitUntilGone(tester, reps, 'the set sheet to close');
      await _keyboard(tester, up: false);
    }
    // Log it.
    await _tap(tester, taps, find.byKey(ValueKey('check-${firstSet.id}')));
    await _until(tester, () async {
      final s = await _rawSets(firstId);
      return s.first.completedAtMs != null;
    }, 'the first set to be logged');
    sets = await _setsOf(tester, firstId);
    expect(sets.first.reps, isNotNull);
    expect(sets.first.reps! >= 1, isTrue);
    if (typed) expect(sets.first.weightKg, isNotNull);
    expect(sets.skip(1).every((s) => s.completedAtMs == null), isTrue);
    final repsLogged = sets.first.reps;
    final weightLogged = sets.first.weightKg;
    if (typed) expect(weightLogged! > 0, isTrue);

    // Finish > Done. The workout is then under "Start again".
    await _finishAndClose(tester, taps);
    final first = await _workoutRow(tester, firstId);
    expect(first.endedAtMs, isNotNull);
    await _waitForWidget(
      tester,
      find.byKey(ValueKey('again-$firstId')),
      'the workout under Start again',
    );

    // Start again: 1 counted tap, and the one set that was logged comes back
    // prefilled from it. Logging that is 1 counted tap.
    taps = TapCounter(tester);
    await _tapInView(tester, taps, _startIn('again-$firstId'));
    taps.expectCount(1, flow: 'Start again');
    final secondId = await _newWorkout(tester, {...workoutsBefore, firstId});
    await _waitForWidget(
      tester,
      find.byType(WorkoutScreen),
      'the second workout screen',
    );
    sets = await _setsOf(tester, secondId);
    expect(sets, hasLength(1), reason: 'only the logged set is copied');
    expect(sets.single.reps, repsLogged);
    expect(sets.single.weightKg, weightLogged);
    expect(sets.single.completedAtMs, isNull);

    taps = TapCounter(tester);
    await _tapInView(
      tester,
      taps,
      find.byKey(ValueKey('check-${sets.single.id}')),
    );
    taps.expectCount(1, flow: 'one prefilled set');
    await _until(tester, () async {
      final s = await _rawSets(secondId);
      return s.single.completedAtMs != null;
    }, 'the prefilled set to be logged');
    sets = await _setsOf(tester, secondId);
    expect(sets.single.reps, repsLogged);
    expect(sets.single.weightKg, weightLogged);

    await _finishAndClose(tester, taps);
    expect((await _workoutRow(tester, secondId)).endedAtMs, isNotNull);
    await _waitForWidget(
      tester,
      find.byKey(ValueKey('again-$secondId')),
      'the second workout under Start again',
    );
  } finally {
    await _keyboard(tester, up: false);
    // CI removes the app after each entry file. This is for a phone or a
    // simulator that is kept: what the flow added is taken out. Each delete
    // is one statement, with frames in between, because the screens reload
    // after a write and a second write started before that waits for them.
    // Workouts go first (their sets go with them), then the routine.
    await tester.runAsync(() async {
      final added = [
        for (final w in await db.select(db.workouts).get())
          if (!workoutsBefore.contains(w.id)) w.id,
      ];
      await (db.delete(db.workouts)..where((w) => w.id.isIn(added))).go();
    });
    await _pumpSome(tester);
    await tester.runAsync(
      () =>
          (db.delete(db.routines)..where(
                (r) =>
                    r.name.equals(_routineName) & r.id.isNotIn(routinesBefore),
              ))
              .go(),
    );
    await _pumpSome(tester);
    // End on Home, whatever the order of the flows (the workout screen closes
    // by itself when its workout is deleted).
    if (find.byType(WorkoutScreen).evaluate().isEmpty &&
        find.byType(NavigationBar).evaluate().isNotEmpty) {
      await taps.tap(find.widgetWithText(NavigationDestination, S.tabToday));
      await _pumpSome(tester);
    }
  }
}

Future<void> _pumpSome(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
