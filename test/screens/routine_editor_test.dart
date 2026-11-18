// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/install_seams.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_harness.dart';

// The routine editor (task 4.4, routine-editor.html frame 1): name, exercises
// in order, drag or menu to reorder, sets and rest per exercise, Save, Back
// with unsaved changes, delete with Undo.

void main() {
  final h = WorkoutHarness()..register();

  setUp(installWorkoutSeams);
  tearDown(clearWorkoutSeams);

  Finder nameField() => find.widgetWithText(TextField, 'Name');

  Future<void> openTab(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await h.openApp(tester, size: size, textScale: scale);
    await h.openWorkoutsTab(tester);
  }

  Future<void> openEditorOfPush(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await openTab(tester, size: size, scale: scale);
    for (var i = 0; i < 20 && find.text('Edit').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Edit').first);
    await tester.pump();
    await tester.tap(find.text('Edit').first);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  Future<void> menu(WidgetTester tester, String name, String item) async {
    await tester.scrollUntilVisible(
      find.byTooltip('Menu for $name'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ReorderableListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Menu for $name'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(item));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<RoutineWithExercises> routine(WidgetTester tester, int id) =>
      h.real(tester, () async => (await h.db.getRoutine(id))!);

  Finder addIn(String ref) => find.descendant(
    of: find.byKey(ValueKey('row-$ref')),
    matching: find.text('Add'),
  );

  h.appTest('a new routine: a blank name is refused beside the field, then '
      'the exercises are added in a row, saved in order and shown from the '
      'row read back', (tester) async {
    await openTab(tester);
    await tester.tap(find.text('+ New routine'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('New routine'), findsOneWidget);
    expect(
      find.text(
        'Weights and reps are not set here. Each workout takes them from the '
        'last time you did each exercise.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Give the routine a name.'), findsOneWidget);
    expect(await h.real(tester, () => h.db.listRoutines()), isEmpty);

    await tester.enterText(nameField(), '  Pull B ');
    await tester.tap(find.text('+ Add exercise'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search exercises'),
      'bench press',
    );
    await settle(tester);
    await tester.tap(addIn('wger:73'));
    await settle(tester);
    await tester.tap(addIn('wger:2536'));
    await settle(tester);
    await h.back(tester);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Bench Press Isometric'), findsOneWidget);
    expect(find.text('3 sets, rest 1:30'), findsNWidgets(2));

    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Routine "Pull B" saved.'), findsOneWidget);
    expect(find.text('Pull B'), findsOneWidget);
    final saved = (await h.real(tester, () => h.db.listRoutines())).single;
    expect(saved.routine.name, 'Pull B');
    expect(saved.exercises.map((e) => e.exerciseRef), ['wger:73', 'wger:2536']);
    expect(saved.exercises.first.targetSets, isNull);
    expect(saved.exercises.first.restSeconds, isNull);
  });

  h.appTest('an existing routine opens with its exercises, sets and rest; '
      'sets and rest are changed in the exercise menu and saved', (
    tester,
  ) async {
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    expect(find.widgetWithText(AppBar, 'Push A'), findsOneWidget);
    expect(tester.widget<TextField>(nameField()).controller!.text, 'Push A');
    expect(find.text('3 sets, rest 2:00'), findsOneWidget); // bench
    expect(find.text('3 sets, rest 1:30'), findsOneWidget); // press, default

    await menu(tester, 'Bench press', 'Number of sets');
    expect(find.text('Sets for Bench press'), findsOneWidget);
    await tester.tap(find.byTooltip('One more set'));
    await tester.pump();
    await tester.tap(find.byTooltip('One more set'));
    await tester.pump();
    expect(find.text('5 sets'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('5 sets, rest 2:00'), findsOneWidget);

    await menu(tester, 'Bench press', 'Rest time');
    await tester.tap(find.byTooltip('Add 15 seconds to the rest'));
    await tester.pump();
    expect(find.text('2:15'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('5 sets, rest 2:15'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final r = await routine(tester, ids.pushId);
    expect(r.exercises.first.targetSets, 5);
    expect(r.exercises.first.restSeconds, 135);
    // The other exercise was not touched.
    expect(r.exercises[1].targetSets, 3);
    expect(r.exercises[1].restSeconds, isNull);
  });

  h.appTest('Move down in the menu and a drag both reorder, and Save keeps '
      'the order', (tester) async {
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    await menu(tester, 'Bench press', 'Move down');
    expect(
      tester.getTopLeft(find.text('Overhead press')).dy,
      lessThan(tester.getTopLeft(find.text('Bench press')).dy),
    );
    // Drag the first row (now Overhead press) below the second.
    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 120),
    );
    await settle(tester);
    expect(
      tester.getTopLeft(find.text('Bench press')).dy,
      lessThan(tester.getTopLeft(find.text('Overhead press')).dy),
    );
    await menu(tester, 'Bench press', 'Move down');
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final r = await routine(tester, ids.pushId);
    expect(r.exercises.map((e) => e.exerciseName), [
      'Overhead press',
      'Bench press',
    ]);
  });

  h.appTest('Remove drops an exercise, and Replace swaps it keeping its '
      'sets and rest', (tester) async {
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    await menu(tester, 'Overhead press', 'Remove exercise');
    expect(find.text('Overhead press'), findsNothing);
    await menu(tester, 'Bench press', 'Replace exercise');
    await tester.enterText(
      find.widgetWithText(TextField, 'Search exercises'),
      'seated bench',
    );
    await settle(tester);
    await tester.tap(addIn('wger:1094'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Seated Bench Press'), findsOneWidget);
    expect(find.text('3 sets, rest 2:00'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final r = await routine(tester, ids.pushId);
    expect(r.exercises, hasLength(1));
    expect(r.exercises.single.exerciseRef, 'wger:1094');
    expect(r.exercises.single.restSeconds, 120);
  });

  h.appTest('Back with changes does not lose them silently: the first Back '
      'says so, the second leaves; Back with no changes leaves at once', (
    tester,
  ) async {
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    await h.back(tester);
    expect(find.text('Save'), findsNothing); // left at once

    await tester.tap(find.text('Edit').first);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    await tester.enterText(nameField(), 'Push Z');
    await tester.pump();
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Save'), findsOneWidget);
    expect(
      find.text(
        'Your changes are not saved. Tap Save, or go back again to leave '
        'without them.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(nameField()).controller!.text, 'Push Z');
    await h.back(tester);
    expect(find.text('Save'), findsNothing);
    expect((await routine(tester, ids.pushId)).routine.name, 'Push A');
  });

  h.appTest('Delete routine offers Undo on the tab, and Undo brings it back', (
    tester,
  ) async {
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    await tester.tap(find.byTooltip('More options'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Delete routine'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Routine "Push A" deleted.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect((await routine(tester, ids.pushId)).routine.archived, isTrue);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await routine(tester, ids.pushId)).routine.archived, isFalse);
    expect(find.text('Undo'), findsNothing);
    expect(find.byKey(ValueKey('routine-${ids.pushId}')), findsOneWidget);
  });

  h.appTest('the routine message goes away after 10 seconds', (tester) async {
    await h.seedSample(tester);
    await openEditorOfPush(tester);
    await tester.enterText(nameField(), 'Push C');
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Routine "Push C" saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('Routine "Push C" saved.'), findsNothing);
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp, text scale $scale: '
          'nothing overflows and every target is 48 dp', (tester) async {
        await h.seedSample(tester);
        await h.real(
          tester,
          () => h.db.createRoutine('Long', [
            const RoutineExerciseInput(
              exerciseRef: 'wger:73',
              exerciseName:
                  'A very long exercise name that goes on and on and on',
            ),
          ], h.now),
        );
        await openEditorOfPush(tester, size: size, scale: scale);
        for (final f in [
          find.widgetWithText(FilledButton, 'Save'),
          find.widgetWithText(OutlinedButton, '+ Add exercise'),
          find.byIcon(Icons.drag_handle),
          find.byType(PopupMenuButton<dynamic>),
        ]) {
          for (var i = 0; i < f.evaluate().length; i++) {
            final s = tester.getSize(f.at(i));
            expect(s.height, greaterThanOrEqualTo(48));
            expect(s.width, greaterThanOrEqualTo(48));
          }
        }
        await menu(tester, 'Bench press', 'Number of sets');
        for (final t in ['One fewer set', 'One more set']) {
          final s = tester.getSize(find.byTooltip(t));
          expect(s.height, greaterThanOrEqualTo(48));
          expect(s.width, greaterThanOrEqualTo(48));
        }
      });
    }
  }

  h.appTest('spoken labels: the drag handle and the exercise menu', (
    tester,
  ) async {
    await h.seedSample(tester);
    await openEditorOfPush(tester);
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('Drag to move Bench press')),
      findsOneWidget,
    );
    expect(find.byTooltip('Menu for Bench press'), findsOneWidget);
    handle.dispose();
  });
}
