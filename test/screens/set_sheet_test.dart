// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/workout_screen.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../speed/tap_counter.dart';
import 'workouts_harness.dart';

// The adjust sheet (task 4.3, workout.html frame 4): -5 and +5 lb (-2.5 and
// +2.5 kg), -1 and +1 reps, a typed number, Remove set and Done, before and
// after a set is logged.

void main() {
  final h = WorkoutHarness()..register();

  Finder check(WorkoutSet s) => find.byKey(ValueKey('check-${s.id}'));
  Finder step(String label) => find.widgetWithText(OutlinedButton, label);
  Finder done() => find.widgetWithText(FilledButton, 'Done');
  Finder field(String label) => find.widgetWithText(TextField, label);

  late int workoutId;

  Future<List<WorkoutSet>> sets(WidgetTester tester) =>
      h.allSets(tester, workoutId);

  /// Push A running, its screen open.
  Future<void> openPush(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    final ids = await h.seedSample(tester);
    final r = await h.real(tester, () => h.db.startRoutine(ids.pushId, h.now));
    workoutId = r.workout!.id;
    await h.openApp(tester, size: size, textScale: scale);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
  }

  /// Opens the sheet of bench set 3 (175 x 7) by tapping its weight.
  Future<void> openSet3(WidgetTester tester) async {
    await tester.ensureVisible(find.text('175 lb').at(2));
    await tester.pump();
    await tester.tap(find.text('175 lb').at(2));
    await settle(tester);
  }

  h.appTest('the sheet names the set, shows last time and the steppers', (
    tester,
  ) async {
    await openPush(tester);
    await openSet3(tester);
    expect(find.text('Bench press, set 3'), findsOneWidget);
    expect(find.text('Last time: 175 lb x 7'), findsOneWidget);
    expect(find.text('-5'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Remove set'), findsOneWidget);
    expect(done(), findsOneWidget);
    // The numbers are in the fields, in the user's units.
    expect(tester.widget<TextField>(field('Weight')).controller!.text, '175');
    expect(tester.widget<TextField>(field('Reps')).controller!.text, '7');
  });

  h.appTest('175 x 7 to 180 x 8 takes five counted taps: the number, +5, +1, '
      'Done, the check (speed-targets, frame 4)', (tester) async {
    await openPush(tester);
    final taps = TapCounter(tester);

    await taps.tap(find.text('175 lb').at(2));
    await settle(tester);
    await taps.tap(step('+5'));
    await tester.pump();
    await taps.tap(step('+1'));
    await tester.pump();
    await taps.tap(done());
    await settle(tester);

    // Frame 4b: the new numbers and "Changed, from 175 x 7".
    expect(find.text('180 lb'), findsOneWidget);
    expect(find.text('8 reps'), findsNWidgets(6));
    expect(find.text('Changed'), findsOneWidget);
    expect(find.text('Changed, from 175 x 7'), findsOneWidget);
    final stored = (await sets(tester))[2];
    expect(stored.weightKg, closeTo(lbToKg(180), 1e-9));
    expect(stored.reps, 8);
    expect(stored.completedAtMs, isNull);

    await taps.tap(check(stored));
    await settle(tester);
    taps.expectCount(5, flow: 'Change a set, then log it');

    // Frame 5: it beats the record, and only it does.
    final logged = (await sets(tester))[2];
    expect(logged.completedAtMs, isNotNull);
    expect(logged.weightKg, closeTo(lbToKg(180), 1e-9));
    expect(find.text('New record'), findsOneWidget);
    expect(find.text('heaviest, and est. 1-rep max 228 lb'), findsOneWidget);
    // Once logged it no longer says "Changed".
    expect(find.text('Changed'), findsNothing);
  });

  h.appTest('-5 and -1 take a step down', (tester) async {
    await openPush(tester);
    await openSet3(tester);
    await tester.tap(step('-5'));
    await tester.tap(step('-1'));
    await tester.pump();
    await tester.tap(done());
    await settle(tester);
    final row = (await sets(tester))[2];
    expect(row.weightKg, closeTo(lbToKg(170), 1e-9));
    expect(row.reps, 6);
    expect(find.text('Changed, from 175 x 7'), findsOneWidget);
  });

  h.appTest('a number can be typed, with a decimal and with a comma', (
    tester,
  ) async {
    await openPush(tester);
    await openSet3(tester);
    await tester.enterText(field('Weight'), '182,5');
    await tester.enterText(field('Reps'), '10');
    await tester.tap(done());
    await settle(tester);
    final row = (await sets(tester))[2];
    expect(row.weightKg, closeTo(lbToKg(182.5), 1e-9));
    expect(row.reps, 10);
    expect(find.text('182.5 lb'), findsOneWidget);
  });

  h.appTest('a weight that is not changed keeps its stored value exactly', (
    tester,
  ) async {
    await openPush(tester);
    final before = (await sets(tester))[2];
    // 79.45 kg shows as 175.2 lb; changing only the reps must not move it.
    await h.real(
      tester,
      () => h.db.adjustSet(before.id, weightKg: 79.45, reps: 7),
    );
    await settle(tester);
    await tester.tap(find.text('175.2 lb'));
    await settle(tester);
    await tester.tap(step('+1'));
    await tester.tap(done());
    await settle(tester);
    final row = (await sets(tester))[2];
    expect(row.weightKg, 79.45);
    expect(row.reps, 8);
  });

  h.appTest('an empty weight is body weight', (tester) async {
    await openPush(tester);
    await openSet3(tester);
    await tester.enterText(field('Weight'), '');
    await tester.tap(done());
    await settle(tester);
    final row = (await sets(tester))[2];
    expect(row.weightKg, isNull);
    expect(row.reps, 7);
    expect(find.text('Body weight'), findsOneWidget);
  });

  h.appTest('after logging, a set can still be changed, and keeps its '
      'logged time', (tester) async {
    await openPush(tester);
    await tester.tap(check((await sets(tester)).first));
    await settle(tester);
    final logged = (await sets(tester)).first;

    await tester.tap(find.text('175 lb').first);
    await settle(tester);
    await tester.tap(step('+5'));
    await tester.tap(step('+1'));
    await tester.tap(done());
    await settle(tester);

    final after = (await sets(tester)).first;
    expect(after.completedAtMs, logged.completedAtMs);
    expect(after.weightKg, closeTo(lbToKg(180), 1e-9));
    expect(after.reps, 9);
    // The record follows what is stored now: 180 x 9 beats 175 x 8.
    expect(find.text('New record'), findsOneWidget);
    expect(find.text('heaviest, and est. 1-rep max 234 lb'), findsOneWidget);
  });

  h.appTest('a logged set cannot lose its reps: the sheet says so in plain '
      'words and the set keeps them', (tester) async {
    await openPush(tester);
    await tester.tap(check((await sets(tester)).first));
    await settle(tester);

    await tester.tap(find.text('8 reps').first);
    await settle(tester);
    await tester.enterText(field('Reps'), '');
    await tester.tap(done());
    await settle(tester);
    expect(find.text('A logged set needs at least 1 rep.'), findsOneWidget);
    expect(
      find.text('Bench press, set 1'),
      findsOneWidget,
      reason: 'stays open',
    );

    await tester.enterText(field('Reps'), '0');
    await tester.tap(done());
    await settle(tester);
    expect(find.text('A logged set needs at least 1 rep.'), findsOneWidget);
    final row = (await sets(tester)).first;
    expect(row.reps, 8);
    expect(row.completedAtMs, isNotNull);

    // The -1 step stops at 1 rep.
    await tester.enterText(field('Reps'), '1');
    await tester.tap(step('-1'));
    await tester.pump();
    expect(tester.widget<TextField>(field('Reps')).controller!.text, '1');
  });

  h.appTest('Remove set deletes it from today only', (tester) async {
    await openPush(tester);
    await openSet3(tester);
    await tester.tap(find.text('Remove set'));
    await settle(tester);
    final all = await sets(tester);
    expect(all, hasLength(5));
    expect(find.text('7 reps'), findsNothing);
    expect(find.text('Bench press, set 3'), findsNothing);
    // Last Thursday's workout still has all its sets.
    final old = await h.real(
      tester,
      () => (h.db.select(
        h.db.workoutSets,
      )..where((s) => s.exerciseRef.equals(bench))).get(),
    );
    expect(old.where((s) => s.workoutId != workoutId), hasLength(3));
  });

  h.appTest('Remove set offers Undo on the workout screen, and Undo puts the '
      'set back as set 3', (tester) async {
    await openPush(tester);
    final before = await sets(tester);
    await openSet3(tester);
    await tester.tap(find.text('Remove set'));
    await settle(tester);
    expect(find.text('Removed set 3 of Bench press.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await sets(tester), before);
    expect(find.text('7 reps'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  h.appTest('numbers that cannot be used are said so beside the field and '
      'nothing is written', (tester) async {
    await openPush(tester);
    await openSet3(tester);
    await tester.enterText(field('Weight'), '1.2.3');
    await tester.tap(done());
    await settle(tester);
    expect(find.text('Enter a weight like 175 or 62.5.'), findsOneWidget);

    await tester.enterText(field('Weight'), '1,000');
    await tester.tap(done());
    await settle(tester);
    expect(find.textContaining('without the comma'), findsOneWidget);
    expect((await sets(tester))[2].weightKg, closeTo(lbToKg(175), 1e-9));

    // Typing again clears the message.
    await tester.enterText(field('Weight'), '180');
    await tester.pump();
    expect(find.textContaining('without the comma'), findsNothing);
  });

  h.appTest('a double tap on Done writes once and closes only the sheet', (
    tester,
  ) async {
    await openPush(tester);
    await openSet3(tester);
    await tester.tap(step('+5'));
    await tester.pump();
    await tester.tap(done());
    await tester.tap(done(), warnIfMissed: false);
    await settle(tester);
    expect(find.byType(WorkoutScreen), findsOneWidget);
    expect(find.text('Bench press, set 3'), findsNothing);
    expect((await sets(tester))[2].weightKg, closeTo(lbToKg(180), 1e-9));
  });

  h.appTest('a workout deleted while the sheet is open: Done says it could '
      'not save, and nothing is written', (tester) async {
    await openPush(tester);
    await openSet3(tester);
    await tester.tap(step('+5'));
    await tester.pump();
    await tester.runAsync(() => h.db.deleteWorkout(workoutId));
    await settle(tester);
    await tester.tap(done());
    await settle(tester);
    expect(
      find.text('Could not save that. Nothing was changed.'),
      findsOneWidget,
    );
    expect(find.text('Bench press, set 3'), findsOneWidget);
  });

  h.appTest('metric: steps of 2.5 kg, the number in kilograms', (tester) async {
    await h.real(tester, () => h.db.setUnits(UnitSystem.metric));
    await openPush(tester);
    await tester.tap(find.text('79.4 kg').at(2));
    await settle(tester);
    expect(find.text('-2.5'), findsOneWidget);
    expect(find.text('+2.5'), findsOneWidget);
    expect(find.text('Last time: 79.4 kg x 7'), findsOneWidget);
    await tester.enterText(field('Weight'), '80');
    await tester.tap(step('+2.5'));
    await tester.pump();
    expect(tester.widget<TextField>(field('Weight')).controller!.text, '82.5');
    await tester.tap(done());
    await settle(tester);
    expect((await sets(tester))[2].weightKg, 82.5);
    expect(find.text('82.5 kg'), findsOneWidget);
  });

  h.appTest('every stepper says what it does', (tester) async {
    final handle = tester.ensureSemantics();
    await openPush(tester);
    await openSet3(tester);
    for (final label in [
      'Take 5 lb off the weight',
      'Add 5 lb to the weight',
      'Take 1 rep off',
      'Add 1 rep',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Add 5 lb to the weight'))
          .flagsCollection
          .isButton,
      isTrue,
    );
    handle.dispose();
  });

  for (final size in [const Size(344, 700), const Size(673, 700)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp, text scale $scale and the '
          'keyboard up: no overflow, targets are 48 dp', (tester) async {
        await openPush(tester, size: size, scale: scale);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await openSet3(tester);
        await tester.enterText(field('Weight'), '1.2.3');
        await tester.ensureVisible(done());
        await tester.pump();
        await tester.tap(done());
        await settle(tester);
        for (final f in [
          step('-5'),
          step('+5'),
          step('-1'),
          step('+1'),
          done(),
          find.widgetWithText(TextButton, 'Remove set'),
        ]) {
          await tester.ensureVisible(f);
          await tester.pump();
          final s = tester.getSize(f);
          expect(s.height, greaterThanOrEqualTo(48), reason: '$f');
          expect(s.width, greaterThanOrEqualTo(48), reason: '$f');
        }
        expect(find.text('Enter a weight like 175 or 62.5.'), findsOneWidget);
      });
    }
  }
}
