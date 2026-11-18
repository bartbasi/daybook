// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/rendering.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:daybook/data/database.dart';

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:daybook/app_scope.dart';
import 'package:daybook/data/exercise_library.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/exercise_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_harness.dart';

// The exercise picker, create exercise, and More > Exercises (task 4.4,
// routine-editor.html frame 2). Real library, real screens.

const chips = ['Chest', 'Shoulders', 'Back', 'Legs', 'Arms'];

void main() {
  final h = WorkoutHarness()..register();

  Finder rowOf(String ref) => find.byKey(ValueKey('row-$ref'));
  Finder addIn(String ref) =>
      find.descendant(of: rowOf(ref), matching: find.text('Add'));

  /// The scrollable of the top list.
  Finder listScrollable() => find
      .descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      )
      .first;

  Finder searchBox() => find.widgetWithText(TextField, 'Search exercises');

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(searchBox(), text);
    await settle(tester);
  }

  Future<void> openBrowse(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await h.openApp(tester, size: size, textScale: scale);
    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await settle(tester);
    await tester.tap(find.text('Exercises'));
    await settle(tester);
  }

  /// The real picker screen on its own, calling [onPick] for each Add.
  Future<void> pumpPicker(
    WidgetTester tester, {
    required PickExercise onPick,
    bool single = false,
    Set<String> alreadyIn = const {},
  }) async {
    await tester.runAsync(() => ExerciseLibrary.load());
    await tester.pumpWidget(
      AppScope(
        db: h.db,
        clock: () => h.now,
        foodsPath: Future.value(''),
        child: MaterialApp(
          home: ExercisePickerScreen(
            onPick: onPick,
            single: single,
            alreadyIn: alreadyIn,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// An empty workout running, its picker open through "+ Add exercise".
  Future<int> openPick(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    final r = await h.real(tester, () => h.db.startEmptyWorkout(h.now));
    await h.openApp(tester, size: size, textScale: scale);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    await tester.tap(find.text('+ Add exercise'));
    await settle(tester);
    return r.workout!.id;
  }

  h.appTest('More > Exercises lists the whole library with no Add buttons, '
      'and a tap opens the detail', (tester) async {
    await openBrowse(tester);
    expect(find.text('All exercises'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    await type(tester, 'bench press');
    await tester.tap(find.text('Bench Press').first);
    await waitFor(tester, find.textContaining('(primary)'));
    expect(find.widgetWithText(AppBar, 'Bench Press'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Text by sistab2, CC BY-SA 3.0.'),
      300,
      scrollable: listScrollable(),
    );
    expect(find.text('Text by sistab2, CC BY-SA 3.0.'), findsOneWidget);
  });

  h.appTest('the Exercises button on the Workouts tab opens the same list', (
    tester,
  ) async {
    await h.openApp(tester);
    await h.openWorkoutsTab(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Exercises'));
    await settle(tester);
    expect(find.text('All exercises'), findsOneWidget);
    expect(searchBox(), findsOneWidget);
  });

  h.appTest('before anything is typed, recent exercises come first', (
    tester,
  ) async {
    await h.real(
      tester,
      () => h.doWorkout('2026-11-05', [
        ('wger:73', 'Bench Press', [(100, 5)]),
      ]),
    );
    await openPick(tester);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-wger:73')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Recent')).dy,
      lessThan(tester.getTopLeft(find.text('All exercises')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('recent-wger:73'))).dy,
      lessThan(tester.getTopLeft(find.text('All exercises')).dy),
    );
    // Typing leaves the recents behind.
    await type(tester, 'press');
    expect(find.text('Recent'), findsNothing);
    expect(find.text('Results'), findsOneWidget);
  });

  h.appTest('muscle chips filter one at a time, with the search words', (
    tester,
  ) async {
    await openPick(tester);
    final lib = await h.real(tester, () => ExerciseLibrary.load());
    await type(tester, 'press');
    await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
    await tester.pump();
    final chest = lib.search('press', group: 'Chest');
    expect(chest, isNotEmpty);
    expect(rowOf(chest.first.ref), findsOneWidget);
    final shoulders = lib.search('press', group: 'Shoulders');
    final onlyShoulders = shoulders.firstWhere(
      (e) => !chest.any((c) => c.ref == e.ref),
    );
    expect(rowOf(onlyShoulders.ref), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Shoulders'));
    await tester.pump();
    // One at a time: Chest is off now.
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Chest'))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Shoulders'))
          .selected,
      isTrue,
    );
    expect(rowOf(onlyShoulders.ref), findsOneWidget);
  });

  h.appTest('Add keeps the picker open: several in a row, shown as Added, '
      'each written to the workout', (tester) async {
    final id = await openPick(tester);
    await type(tester, 'bench press');
    await tester.tap(addIn('wger:73'));
    await settle(tester);
    expect(find.byType(TextField), findsOneWidget); // still the picker
    expect(
      find.descendant(of: rowOf('wger:73'), matching: find.text('Added')),
      findsOneWidget,
    );
    expect(addIn('wger:73'), findsNothing);
    await tester.tap(addIn('wger:2536'));
    await settle(tester);
    final sets = await h.allSets(tester, id);
    expect(sets.map((s) => s.exerciseRef).toSet(), {'wger:73', 'wger:2536'});
    expect(sets, hasLength(6));

    await h.back(tester);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Bench Press Isometric'), findsOneWidget);
  });

  h.appTest('an exercise already in the workout shows as Added from the '
      'start', (tester) async {
    final id = await h.real(
      tester,
      () async => (await h.db.startEmptyWorkout(h.now)).workout!.id,
    );
    await h.real(tester, () => h.db.addExercise(id, 'wger:73', 'Bench Press'));
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    await tester.tap(find.text('+ Add exercise'));
    await settle(tester);
    await type(tester, 'bench press');
    expect(addIn('wger:73'), findsNothing);
    expect(
      find.descendant(of: rowOf('wger:73'), matching: find.text('Added')),
      findsOneWidget,
    );
    expect(addIn('wger:2536'), findsOneWidget);
  });

  h.appTest('Replace exercise picks one and closes', (tester) async {
    final ids = await h.seedSample(tester);
    final r = await h.real(tester, () => h.db.startRoutine(ids.pushId, h.now));
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    await tester.tap(find.byTooltip('Menu for Bench press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Replace exercise'));
    await settle(tester);
    await type(tester, 'seated bench');
    await tester.tap(addIn('wger:1094'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(searchBox(), findsNothing); // closed
    expect(find.text('Seated Bench Press'), findsOneWidget);
    expect(find.text('Bench press'), findsNothing);
    final sets = await h.allSets(tester, r.workout!.id);
    expect(sets.where((s) => s.exerciseRef == 'wger:1094'), hasLength(3));
  });

  h.appTest('Replace after removing set 3, then Undo, brings the old exercise '
      'back as a one-set exercise beside the new one (accepted, decision D)', (
    tester,
  ) async {
    final ids = await h.seedSample(tester);
    final r = await h.real(tester, () => h.db.startRoutine(ids.pushId, h.now));
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    // Remove set 3 of bench in its sheet.
    await tester.ensureVisible(find.text('175 lb').at(2));
    await tester.pump();
    await tester.tap(find.text('175 lb').at(2));
    await settle(tester);
    await tester.tap(find.text('Remove set'));
    await settle(tester);
    // Replace bench (two sets left) with another exercise.
    await tester.tap(find.byTooltip('Menu for Bench press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Replace exercise'));
    await settle(tester);
    await type(tester, 'seated bench');
    await tester.tap(addIn('wger:1094'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    // Undo is still offered: it puts back the set that was removed.
    await tester.tap(find.text('Undo'));
    await settle(tester);
    final sets = await h.allSets(tester, r.workout!.id);
    expect(sets.where((s) => s.exerciseRef == 'wger:192'), hasLength(1));
    expect(sets.where((s) => s.exerciseRef == 'wger:1094'), hasLength(2));
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Seated Bench Press'), findsOneWidget);
  });

  h.appTest('a refused pick says so in plain words, the row is not marked '
      'Added and the picker stays open', (tester) async {
    await pumpPicker(
      tester,
      onPick: (ref, name) async => 'That did not work, in plain words.',
    );
    await type(tester, 'bench press');
    await tester.tap(addIn('wger:73'));
    await settle(tester);
    expect(find.text('That did not work, in plain words.'), findsOneWidget);
    expect(addIn('wger:73'), findsOneWidget);
    expect(searchBox(), findsOneWidget);
  });

  h.appTest('Create: a blank name and a name already listed are refused '
      'beside the field, and a good one is saved and shown ready to Add', (
    tester,
  ) async {
    final id = await openPick(tester);
    await type(tester, 'Zq press');
    await tester.tap(find.text('+ Create "Zq press" as your own exercise'));
    await settle(tester);
    expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);

    // Blank.
    await tester.enterText(find.widgetWithText(TextField, 'Name'), '   ');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Enter a name for the exercise.'), findsOneWidget);
    // Already listed (accents and case ignored).
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'bench PRESS',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      find.text('An exercise with that name is already in the list.'),
      findsOneWidget,
    );
    expect(await h.real(tester, () => h.db.userExercises()), isEmpty);

    // Good.
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Zq press');
    await tester.tap(find.widgetWithText(FilterChip, 'Chest').first);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Equipment (optional)'),
      200,
      scrollable: listScrollable(),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Equipment (optional)'),
      'Sled',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    final own = await h.real(tester, () => h.db.userExercises());
    expect(own.single.name, 'Zq press');
    expect(own.single.primaryMuscles, ['Chest']);
    expect(own.single.equipment, ['Sled']);
    // Back in the picker: the new exercise is the result, with its words.
    expect(searchBox(), findsOneWidget);
    expect(find.text('Chest. Sled'), findsOneWidget);
    await tester.tap(addIn(own.single.ref));
    await settle(tester);
    final sets = await h.allSets(tester, id);
    expect(sets.map((s) => s.exerciseRef).toSet(), {own.single.ref});
  });

  h.appTest('the weekly card counts a set of an exercise made after the tab '
      'was built, without a restart', (tester) async {
    final id = await openPick(tester);
    await type(tester, 'Zq press');
    await tester.tap(find.text('+ Create "Zq press" as your own exercise'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilterChip, 'Chest').first);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await settle(tester);
    await h.back(tester);
    // The workout: log set 1 (reps first, in the sheet).
    await tester.tap(find.text('Add reps').first);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);
    final sets = await h.allSets(tester, id);
    expect(sets.first.reps, 5);
    await tester.tap(find.byKey(ValueKey('check-${sets.first.id}')));
    await settle(tester);
    expect((await h.allSets(tester, id)).first.completedAtMs, isNotNull);

    await h.back(tester);
    await h.openWorkoutsTab(tester);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Chest'),
      300,
      scrollable: listScrollable(),
    );
    expect(find.text('Chest'), findsOneWidget);
    // Chest is first now: its row says 1 set, the others 0 sets.
    expect(find.text('1 set'), findsOneWidget);
  });

  /// openPick, with the exercises table read through [reads].
  Future<int> openPickWith(WidgetTester tester, ExerciseReads reads) {
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(reads));
    return openPick(tester);
  }

  h.appTest('the picker says the list is loading while it is read, then '
      'shows it', (tester) async {
    final reads = ExerciseReads()..hold = Completer<void>();
    await openPickWith(tester, reads);
    expect(find.text('Loading the exercise list.'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    reads.hold!.complete();
    await waitFor(tester, find.text('Add'));
    expect(find.text('Loading the exercise list.'), findsNothing);
  });

  h.appTest('the picker says so when the list cannot be read, and offers no '
      'Add', (tester) async {
    final reads = ExerciseReads()..fail = true;
    await openPickWith(tester, reads);
    await waitFor(tester, find.text('The exercise list could not be read.'));
    expect(find.text('The exercise list could not be read.'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    // A search shows the same sentence, and no way to create.
    await type(tester, 'bench');
    expect(find.text('The exercise list could not be read.'), findsOneWidget);
    expect(find.textContaining('Create'), findsNothing);
  });

  h.appTest('recent exercises show before the library has loaded', (
    tester,
  ) async {
    final reads = ExerciseReads()..hold = Completer<void>();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(reads));
    await h.real(
      tester,
      () => h.doWorkout('2026-11-05', [
        ('wger:73', 'Bench Press', [(100, 5)]),
      ]),
    );
    await openPick(tester);
    expect(find.text('Loading the exercise list.'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-wger:73')), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    reads.hold!.complete();
    await waitFor(tester, find.byKey(const ValueKey('row-wger:73')));
    expect(find.byKey(const ValueKey('recent-wger:73')), findsOneWidget);
  });

  h.appTest('there is no Create button until something is typed', (
    tester,
  ) async {
    await openPick(tester);
    expect(find.textContaining('Create'), findsNothing);
    await type(tester, '   ');
    expect(find.textContaining('Create'), findsNothing);
    await type(tester, 'Zq');
    expect(find.text('+ Create "Zq" as your own exercise'), findsOneWidget);
  });

  h.appTest('a double press on Add picks once', (tester) async {
    final gate = Completer<String?>();
    final picked = <String>[];
    await pumpPicker(
      tester,
      onPick: (ref, name) {
        picked.add(ref);
        return gate.future;
      },
    );
    await type(tester, 'bench press');
    final add = tester.widget<OutlinedButton>(
      find.ancestor(
        of: addIn('wger:73'),
        matching: find.byType(OutlinedButton),
      ),
    );
    add.onPressed!();
    add.onPressed!();
    await settle(tester);
    gate.complete(null);
    await settle(tester);
    expect(picked, ['wger:73']);
    expect(addIn('wger:73'), findsNothing); // shown as Added
  });

  h.appTest('a refused pick in single mode (Replace) keeps the picker open', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      single: true,
      onPick: (ref, name) async => 'Not that one.',
    );
    await type(tester, 'bench press');
    await tester.tap(addIn('wger:73'));
    await settle(tester);
    expect(find.text('Not that one.'), findsOneWidget);
    expect(searchBox(), findsOneWidget);
    expect(addIn('wger:73'), findsOneWidget);
  });

  h.appTest('if the user exercises cannot be read after a create, the picker '
      'says the list could not be read and nothing is thrown', (tester) async {
    final reads = ExerciseReads();
    await openPickWith(tester, reads);
    await type(tester, 'Zq press');
    await tester.tap(find.text('+ Create "Zq press" as your own exercise'));
    await settle(tester);
    // Saving reads the table twice (the name check and the row read back);
    // the third read, the picker's own refresh, fails.
    reads.failFromRead = reads.reads + 3;
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('The exercise list could not be read.'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('The exercise list could not be read.'), findsOneWidget);
    expect(searchBox(), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The exercise itself was saved.
    reads.failFromRead = null;
    expect(await h.real(tester, () => h.db.userExercises()), hasLength(1));
  });

  /// The form behind "+ Create ...", opened from the picker.
  Future<void> openCreate(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await openPick(tester, size: size, scale: scale);
    await type(tester, 'Zq press');
    await tester.tap(find.text('+ Create "Zq press" as your own exercise'));
    await waitFor(tester, find.text('Primary muscles'));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The chip of [muscle] in the primary or the secondary list, scrolled into
  /// view (the lists are built as they come into view).
  Future<Finder> chipIn(
    WidgetTester tester,
    String muscle, {
    required bool primary,
  }) async {
    final form = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    if (primary) {
      await tester.drag(form, const Offset(0, 5000));
      await tester.pump();
    } else {
      await tester.scrollUntilVisible(
        find.text('Secondary muscles'),
        200,
        scrollable: form,
      );
    }
    final all = find.widgetWithText(FilterChip, muscle);
    final c = primary ? all.first : all.last;
    await tester.ensureVisible(c);
    await tester.pump();
    return c;
  }

  Future<bool> chosen(
    WidgetTester tester,
    String muscle, {
    required bool primary,
  }) async => tester
      .widget<FilterChip>(await chipIn(tester, muscle, primary: primary))
      .selected;

  h.appTest('a muscle is primary or secondary, never both: choosing it in '
      'one list clears it from the other', (tester) async {
    await openCreate(tester);
    await tester.tap(await chipIn(tester, 'Chest', primary: true));
    await tester.pump();
    expect(await chosen(tester, 'Chest', primary: true), isTrue);
    expect(await chosen(tester, 'Chest', primary: false), isFalse);

    await tester.tap(await chipIn(tester, 'Chest', primary: false));
    await tester.pump();
    expect(await chosen(tester, 'Chest', primary: true), isFalse);
    expect(await chosen(tester, 'Chest', primary: false), isTrue);

    await tester.tap(await chipIn(tester, 'Chest', primary: true));
    await tester.pump();
    expect(await chosen(tester, 'Chest', primary: true), isTrue);
    expect(await chosen(tester, 'Chest', primary: false), isFalse);

    // Save keeps what the form shows.
    await tester.tap(await chipIn(tester, 'Triceps', primary: false));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('Chest. Triceps'));
    final own = (await h.real(tester, () => h.db.userExercises())).single;
    expect(own.primaryMuscles, ['Chest']);
    expect(own.secondaryMuscles, ['Triceps']);
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('create exercise at ${size.width.round()} dp, text scale '
          '$scale: nothing overflows, every target is 48 dp and a long muscle '
          'name wraps', (tester) async {
        await openCreate(tester, size: size, scale: scale);
        final form = find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first;
        for (final f in [
          find.widgetWithText(FilledButton, 'Save'),
          find.byType(TextField),
        ]) {
          for (var i = 0; i < f.evaluate().length; i++) {
            final s = tester.getSize(f.at(i));
            expect(s.height, greaterThanOrEqualTo(48));
            expect(s.width, greaterThanOrEqualTo(48));
          }
        }
        // Every chip of both lists, scrolled to. The lists are built as they
        // come into view, so each is looked at from its own heading.
        for (final list in [
          ('Primary muscles', 'first'),
          ('Secondary muscles', 'last'),
        ]) {
          await tester.scrollUntilVisible(
            find.text(list.$1),
            -200,
            scrollable: form,
          );
          await tester.scrollUntilVisible(
            find.text(list.$1),
            200,
            scrollable: form,
          );
          for (final muscle in exerciseMuscleNames) {
            final all = find.widgetWithText(FilterChip, muscle);
            final c = list.$2 == 'first' ? all.first : all.last;
            await tester.scrollUntilVisible(c, 200, scrollable: form);
            expect(tester.getSize(c).height, greaterThanOrEqualTo(48));
            // The label is whole: wrapped onto lines when it does not fit on
            // one, never cut off or faded.
            final label = tester.renderObject<RenderParagraph>(
              find.descendant(of: c, matching: find.text(muscle)).first,
            );
            final natural = label.getMaxIntrinsicWidth(double.infinity);
            if (natural > label.size.width + 0.5) {
              expect(
                label.size.height,
                greaterThanOrEqualTo(label.preferredLineHeight * 1.9),
                reason: '$muscle at ${size.width} dp, scale $scale',
              );
            }
            expect(
              tester.getRect(c).right,
              lessThanOrEqualTo(size.width),
              reason: muscle,
            );
          }
        }
        await tester.scrollUntilVisible(
          find.widgetWithText(TextField, 'Equipment (optional)'),
          200,
          scrollable: form,
        );
        expect(
          find.widgetWithText(TextField, 'Equipment (optional)'),
          findsOneWidget,
        );
      });
    }
  }

  h.appTest('create exercise, spoken: the headings, a muscle chip and its '
      'chosen state, and Save', (tester) async {
    await openCreate(tester);
    final handle = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.text('Primary muscles'))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.text('Secondary muscles'))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    final chest = find.widgetWithText(FilterChip, 'Chest').first;
    expect(tester.getSemantics(chest).label, 'Chest');
    expect(
      tester.getSemantics(chest).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    await tester.tap(chest);
    await tester.pump();
    expect(
      tester.getSemantics(chest).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.bySemanticsLabel('Save'), findsOneWidget);
    handle.dispose();
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp, text scale $scale, '
          'keyboard up: nothing overflows, the search box stays in view, '
          'targets are 48 dp', (tester) async {
        await openPick(tester, size: size, scale: scale);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await type(tester, 'bench');
        final box = tester.getRect(searchBox());
        expect(box.top, greaterThanOrEqualTo(0));
        expect(box.bottom, lessThanOrEqualTo(size.height - 300));
        final adds = find.widgetWithText(OutlinedButton, 'Add');
        expect(adds, findsWidgets);
        for (var i = 0; i < adds.evaluate().length && i < 5; i++) {
          final s = tester.getSize(adds.at(i));
          expect(s.height, greaterThanOrEqualTo(48));
          expect(s.width, greaterThanOrEqualTo(48));
        }
        for (final chip in chips) {
          final s = tester.getSize(find.widgetWithText(FilterChip, chip));
          expect(s.height, greaterThanOrEqualTo(48));
        }
        // The create button is the end of the results.
        await tester.scrollUntilVisible(
          find.text('+ Create "bench" as your own exercise'),
          500,
          scrollable: listScrollable(),
          maxScrolls: 300,
        );
        expect(
          find.text('+ Create "bench" as your own exercise'),
          findsOneWidget,
        );
      });
    }
  }

  h.appTest('spoken labels: a row, its Add button and an added row', (
    tester,
  ) async {
    await openPick(tester);
    final handle = tester.ensureSemantics();
    await type(tester, 'bench press');
    expect(find.bySemanticsLabel(RegExp(r'^Add Bench Press$')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Details for Bench Press\.')),
      findsOneWidget,
    );
    await tester.tap(addIn('wger:73'));
    await settle(tester);
    expect(find.bySemanticsLabel('Bench Press, already added'), findsOneWidget);
    handle.dispose();
  });
}
