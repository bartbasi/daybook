// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:daybook/screens/workouts/exercise_picker.dart';
import 'package:daybook/screens/workouts/routine_editor.dart';
import 'package:daybook/data/exercise_library.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/app_scope.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_harness.dart';

// The routine editor (task 4.4, routine-editor.html frame 1): name, exercises
// in order, drag or menu to reorder, sets and rest per exercise, Save, Back
// with unsaved changes, delete with Undo.

/// A database that refuses every update while [fail] is true.
class _FailUpdates extends QueryInterceptor {
  var fail = false;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (fail) throw StateError('disk full');
    return super.runUpdate(executor, statement, args);
  }
}

void main() {
  final h = WorkoutHarness()..register();

  Finder nameField() => find.widgetWithText(TextField, 'Name');

  Future<void> openTab(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await h.openApp(tester, size: size, textScale: scale);
    await h.openWorkoutsTab(tester);
  }

  /// The editor of the first routine, or of [routineId].
  Future<void> openEditorOfPush(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
    int? routineId,
  }) async {
    await openTab(tester, size: size, scale: scale);
    final edit = routineId == null
        ? find.text('Edit').first
        : find.descendant(
            of: find.byKey(ValueKey('routine-$routineId')),
            matching: find.text('Edit'),
          );
    for (var i = 0; i < 20 && edit.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pump();
    }
    await tester.ensureVisible(edit);
    await tester.pump();
    await tester.tap(edit);
    await waitFor(tester, nameField());
    // The slide in has to finish before anything is tapped.
    await tester.pump(const Duration(milliseconds: 500));
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

  h.appTest('the real app, start to finish: Workouts > + New routine > '
      '+ Add exercise > Add > Save > Start', (tester) async {
    await openTab(tester);
    await tester.tap(find.text('+ New routine'));
    await settle(tester);
    await tester.enterText(nameField(), 'Chest day');
    await tester.tap(find.text('+ Add exercise'));
    await settle(tester);
    await pickInPicker(tester, 'bench press', 'wger:73');
    await h.back(tester);
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('Routine "Chest day" saved.'));
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await settle(tester);
    expect(find.text('Chest day'), findsWidgets);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    final running = (await h.workoutRows(tester)).single;
    expect(running.endedAtMs, isNull);
    expect((await h.allSets(tester, running.id)).map((s) => s.exerciseRef), [
      'wger:73',
      'wger:73',
      'wger:73',
    ]);
  });

  h.appTest('a routine with no exercises can be saved (the data layer '
      'allows it), and the tab says it has none', (tester) async {
    await openTab(tester);
    await tester.tap(find.text('+ New routine'));
    await settle(tester);
    await tester.enterText(nameField(), 'Blank');
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('Routine "Blank" saved.'));
    final saved = (await h.real(tester, () => h.db.listRoutines())).single;
    expect(saved.exercises, isEmpty);
    expect(find.text('No exercises yet.'), findsOneWidget);
  });

  h.appTest('Back, then more changes, then Back warns again: only a Back '
      'with nothing changed since the warning leaves', (tester) async {
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    const warning =
        'Your changes are not saved. Tap Save, or go back again to leave '
        'without them.';
    await tester.enterText(nameField(), 'Push Z');
    await tester.pump();
    await tester.pageBack();
    await settle(tester);
    expect(find.text(warning), findsOneWidget);

    // Changed again after the warning: Back stays and warns again.
    await tester.enterText(nameField(), 'Push ZZ');
    await tester.pump();
    await tester.pageBack();
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Save'), findsOneWidget);
    expect(find.text(warning), findsOneWidget);

    // Nothing changed since that warning: the next Back leaves.
    await h.back(tester);
    expect(find.text('Save'), findsNothing);
    expect((await routine(tester, ids.pushId)).routine.name, 'Push A');
  });

  h.appTest('the facts line says "no rest" for a rest of 0, and the steppers '
      'stop at 1 and 30 sets and at no rest and 10:00', (tester) async {
    final made = await h.real(
      tester,
      () => h.db.createRoutine('Edges', [
        const RoutineExerciseInput(
          exerciseRef: 'wger:73',
          exerciseName: 'Bench Press',
          targetSets: 1,
          restSeconds: 0,
        ),
      ], h.now),
    );
    await openEditorOfPush(tester, routineId: made.routine.id);
    expect(find.text('1 set, no rest'), findsOneWidget);

    IconButton button(String tip) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tip),
        matching: find.byWidgetPredicate((w) => w is IconButton),
      ),
    );

    await menu(tester, 'Bench Press', 'Number of sets');
    expect(find.text('1 set'), findsWidgets);
    expect(button('One fewer set').onPressed, isNull);
    for (var i = 0; i < 29; i++) {
      await tester.tap(find.byTooltip('One more set'));
      await tester.pump();
    }
    expect(find.text('30 sets'), findsWidgets);
    expect(button('One more set').onPressed, isNull);
    expect(button('One fewer set').onPressed, isNotNull);
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('30 sets, no rest'), findsOneWidget);

    await menu(tester, 'Bench Press', 'Rest time');
    expect(find.text('No rest'), findsOneWidget);
    expect(button('Take 15 seconds off the rest').onPressed, isNull);
    for (var i = 0; i < 40; i++) {
      await tester.tap(find.byTooltip('Add 15 seconds to the rest'));
      await tester.pump();
    }
    expect(find.text('10:00'), findsWidgets);
    expect(button('Add 15 seconds to the rest').onPressed, isNull);
    await tester.tap(find.text('Done'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('30 sets, rest 10:00'), findsOneWidget);
  });

  h.appTest("creating an exercise from the routine editor's picker adds it "
      'to the routine', (tester) async {
    await openTab(tester);
    await tester.tap(find.text('+ New routine'));
    await settle(tester);
    await tester.enterText(nameField(), 'Mine');
    await tester.tap(find.text('+ Add exercise'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search exercises'),
      'Zq press',
    );
    await settle(tester);
    await tester.tap(find.text('+ Create "Zq press" as your own exercise'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await settle(tester);
    await h.back(tester);
    expect(find.text('Zq press'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('Routine "Mine" saved.'));
    final saved = (await h.real(tester, () => h.db.listRoutines())).single;
    expect(saved.exercises.single.exerciseName, 'Zq press');
    expect(saved.exercises.single.exerciseRef, startsWith('local:'));
  });

  h.appTest('a double tap on + Add exercise opens one picker', (tester) async {
    await h.seedSample(tester);
    await openEditorOfPush(tester);
    final add = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '+ Add exercise'),
    );
    // Two presses before the next frame, as two quick taps would be.
    add.onPressed!();
    add.onPressed!();
    await tester.pump();
    expect(
      find.byType(ExercisePickerScreen, skipOffstage: false),
      findsOneWidget,
    );
  });

  h.appTest('a Save the database refuses says so and keeps the editor and '
      'its changes', (tester) async {
    final fail = _FailUpdates();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(fail));
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    await tester.enterText(nameField(), 'Push Z');
    fail.fail = true;
    await tester.tap(find.text('Save'));
    await waitFor(
      tester,
      find.text('Could not save the routine. Nothing was changed.'),
    );
    expect(
      find.text('Could not save the routine. Nothing was changed.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(nameField()).controller!.text, 'Push Z');
    fail.fail = false;
    expect((await routine(tester, ids.pushId)).routine.name, 'Push A');
    // Nothing is stuck: Save works once the database does.
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('Routine "Push Z" saved.'));
    expect((await routine(tester, ids.pushId)).routine.name, 'Push Z');
  });

  h.appTest('Undo that the database refuses says so in plain words', (
    tester,
  ) async {
    final fail = _FailUpdates();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(fail));
    final ids = await h.seedSample(tester);
    await openEditorOfPush(tester);
    await tester.tap(find.byTooltip('More options'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Delete routine'));
    await waitFor(tester, find.text('Routine "Push A" deleted.'));
    fail.fail = true;
    await tester.tap(find.text('Undo'));
    await waitFor(tester, find.text('Could not bring the routine back.'));
    expect(find.text('Could not bring the routine back.'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    fail.fail = false;
    expect((await routine(tester, ids.pushId)).routine.archived, isTrue);
  });

  h.appTest('a routine that is not there says so, and Save is off', (
    tester,
  ) async {
    await tester.runAsync(() => ExerciseLibrary.load());
    await tester.pumpWidget(
      AppScope(
        db: h.db,
        clock: () => h.now,
        foodsPath: Future.value(''),
        child: const MaterialApp(home: RoutineEditor(routineId: 999)),
      ),
    );
    await waitFor(
      tester,
      find.text('Could not read this routine. Go back and try again.'),
    );
    expect(
      find.text('Could not read this routine. Go back and try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp, text scale $scale: '
          'nothing overflows and every target is 48 dp', (tester) async {
        await h.seedSample(tester);
        const long = 'A very long exercise name that goes on and on and on';
        final long1 = await h.real(
          tester,
          () => h.db.createRoutine('Long', [
            const RoutineExerciseInput(
              exerciseRef: 'wger:73',
              exerciseName: long,
            ),
          ], h.now),
        );
        await openEditorOfPush(
          tester,
          size: size,
          scale: scale,
          routineId: long1.routine.id,
        );
        expect(find.text(long), findsOneWidget);
        for (final f in [
          find.widgetWithText(FilledButton, 'Save'),
          find.widgetWithText(OutlinedButton, '+ Add exercise'),
          find.byIcon(Icons.drag_handle),
          find.byWidgetPredicate((w) => w is PopupMenuButton),
        ]) {
          expect(f, findsWidgets);
          for (var i = 0; i < f.evaluate().length; i++) {
            final s = tester.getSize(f.at(i));
            expect(s.height, greaterThanOrEqualTo(48));
            expect(s.width, greaterThanOrEqualTo(48));
          }
        }
        await menu(tester, long, 'Number of sets');
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
