// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/app_scope.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/seams.dart';
import 'package:daybook/screens/workouts/workout_screen.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../speed/tap_counter.dart';
import 'workouts_harness.dart';

// The active workout screen (task 4.3, workout.html frames 2, 3 and 5): one
// card per exercise, a check that logs exactly what its row shows, the list
// scrolling to the next set, the exercise menu, and a screen that holds
// nothing the database does not.

void main() {
  final h = WorkoutHarness()..register();

  tearDown(() {
    WorkoutSeams.exercisePicker = null;
    WorkoutSeams.exerciseDetail = null;
  });

  late int pushId;

  /// Push A started now: bench (3 sets, rest 120 s) and overhead press (3
  /// sets, no rest given), prefilled from last Thursday. Returns the workout.
  Future<int> startPush(WidgetTester tester) async {
    final ids = await h.seedSample(tester);
    pushId = ids.pushId;
    final r = await h.real(tester, () => h.db.startRoutine(pushId, h.now));
    return r.workout!.id;
  }

  /// Opens the app and returns to the running workout from Home.
  Future<void> openRunning(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await h.openApp(tester, size: size, textScale: scale);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
  }

  Future<List<WorkoutSet>> sets(WidgetTester tester, int id) =>
      h.allSets(tester, id);

  /// The menu entry that holds [label].
  PopupMenuItem<dynamic> menuItem(WidgetTester tester, String label) =>
      tester.widget<PopupMenuItem<dynamic>>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );

  Finder check(WorkoutSet s) => find.byKey(ValueKey('check-${s.id}'));

  h.appTest('shows every exercise in order with each set as a row, and what '
      'was done last time', (tester) async {
    await startPush(tester);
    await openRunning(tester);

    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Started 5:29 pm, 0 min'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Overhead press'), findsOneWidget);
    expect(
      find.text('Last time (Nov 5): 175 x 8, 175 x 8, 175 x 7'),
      findsOneWidget,
    );
    expect(
      find.text('Last time (Nov 5): 95 x 8, 95 x 8, 95 x 8'),
      findsOneWidget,
    );
    expect(find.text('175 lb'), findsNWidgets(3));
    expect(find.text('8 reps'), findsNWidgets(5));
    expect(find.text('7 reps'), findsOneWidget);
    expect(find.text('+ Add set'), findsNWidgets(2));
    // Nothing is logged yet: no Done, no rest bar.
    expect(find.text('Done'), findsNothing);
    expect(find.textContaining('Rest'), findsNothing);
    final bench = find.text('Bench press');
    final press = find.text('Overhead press');
    expect(tester.getTopLeft(bench).dy, lessThan(tester.getTopLeft(press).dy));
  });

  h.appTest('one counted tap on the check logs exactly what the row shows '
      'and starts the rest with the routine\'s rest', (tester) async {
    final id = await startPush(tester);
    await openRunning(tester);
    final before = await sets(tester, id);
    final taps = TapCounter(tester);

    await taps.tap(check(before.first));
    await settle(tester);
    taps.expectCount(1, flow: 'Log a prefilled set');

    final after = await sets(tester, id);
    final logged = after.first;
    expect(logged.completedAtMs, h.now.utcMs);
    expect(logged.weightKg, before.first.weightKg);
    expect(logged.weightKg, closeTo(lbToKg(175), 1e-9));
    expect(logged.reps, 8);
    expect(after.skip(1).where((s) => s.completedAtMs != null), isEmpty);

    // Done in words, and a rest of 2:00, the routine's rest for bench.
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);
    expect(find.text('Up next: set 2, 175 lb x 8'), findsOneWidget);
  });

  h.appTest('an exercise with no rest in its routine rests 90 seconds', (
    tester,
  ) async {
    final id = await startPush(tester);
    await openRunning(tester);
    final all = await sets(tester, id);
    await tester.tap(check(all[3])); // overhead press, set 1
    await settle(tester);
    expect(find.text('Rest 1:30 of 1:30'), findsOneWidget);
  });

  h.appTest('a logged set shows Done in words and shape, and says so aloud', (
    tester,
  ) async {
    final id = await startPush(tester);
    final handle = tester.ensureSemantics();
    await openRunning(tester);
    final all = await sets(tester, id);
    expect(find.bySemanticsLabel('Log set 1: 175 lb, 8 reps'), findsOneWidget);
    expect(find.bySemanticsLabel('Log set 2: 175 lb, 8 reps'), findsOneWidget);
    await tester.tap(check(all.first));
    await settle(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.bySemanticsLabel('Set 1 done: 175 lb, 8 reps'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(5));
    handle.dispose();
  });

  h.appTest('the check says what it will log, and a set with no reps says '
      'it needs them', (tester) async {
    final id = await startPush(tester);
    final handle = tester.ensureSemantics();
    await openRunning(tester);
    final all = await sets(tester, id);
    expect(
      tester.getSemantics(check(all[2])).label,
      'Log set 3: 175 lb, 7 reps',
    );
    expect(tester.getSemantics(check(all[2])).flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  h.appTest('the check is at least 48 dp, and the next set\'s is heavier', (
    tester,
  ) async {
    final id = await startPush(tester);
    await openRunning(tester);
    final all = await sets(tester, id);
    for (final s in all.take(3)) {
      final size = tester.getSize(check(s));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    BorderSide side(WorkoutSet s) {
      final b = tester.widget<OutlinedButton>(check(s));
      return b.style!.side!.resolve({})!;
    }

    expect(side(all[0]).width, 3); // the next set to do
    expect(side(all[1]).width, 1);
  });

  h.appTest('the list scrolls to the next set after a log', (tester) async {
    final id = await startPush(tester);
    await openRunning(tester, size: const Size(400, 420));
    final all = await sets(tester, id);
    final list = find.byType(SingleChildScrollView).first;
    final listBottom = tester.getRect(list).bottom;
    // Overhead press, set 1, is below the fold.
    expect(tester.getRect(check(all[3])).top, greaterThan(listBottom));

    for (final s in all.take(3)) {
      await tester.ensureVisible(check(s));
      await tester.tap(check(s));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
    }
    final rect = tester.getRect(check(all[3]));
    final box = tester.getRect(find.byType(SingleChildScrollView).first);
    expect(rect.top, greaterThanOrEqualTo(box.top));
    expect(rect.bottom, lessThanOrEqualTo(box.bottom));
  });

  h.appTest('the first time an exercise is done, a set with no reps is not '
      'logged: it asks for the reps in plain words', (tester) async {
    final r = await h.real(tester, () => h.db.startEmptyWorkout(h.now));
    final id = r.workout!.id;
    await h.real(tester, () => h.db.addExercise(id, 'wger:1', 'Dips', sets: 2));
    await openRunning(tester);
    expect(find.text('First time. Add the weight and reps.'), findsOneWidget);
    expect(find.text('Add weight'), findsNWidgets(2));
    expect(find.text('Add reps'), findsNWidgets(2));

    final all = await sets(tester, id);
    await tester.tap(check(all.first));
    await settle(tester);

    expect(
      find.text(
        'Add the reps first. A set needs its reps before it can be logged.',
      ),
      findsOneWidget,
    );
    expect((await sets(tester, id)).first.completedAtMs, isNull);
    expect(find.textContaining('Rest'), findsNothing);
  });

  h.appTest('an empty first-time set logs as body weight with its reps and '
      'no weight', (tester) async {
    final r = await h.real(tester, () => h.db.startEmptyWorkout(h.now));
    final id = r.workout!.id;
    await h.real(tester, () => h.db.addExercise(id, 'wger:1', 'Dips', sets: 1));
    await openRunning(tester);
    final all = await sets(tester, id);
    await tester.tap(check(all.first)); // asks for the reps
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Reps'), '12');
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);

    expect(find.text('Body weight'), findsOneWidget);
    expect(find.text('12 reps'), findsOneWidget);
    await tester.tap(check(all.first));
    await settle(tester);

    final row = (await sets(tester, id)).single;
    expect(row.completedAtMs, isNotNull);
    expect(row.weightKg, isNull);
    expect(row.reps, 12);
  });

  h.appTest('a double tap on the check logs once and starts one rest', (
    tester,
  ) async {
    final id = await startPush(tester);
    await openRunning(tester);
    final all = await sets(tester, id);
    final timer = AppScope.of(tester.element(find.byType(WorkoutScreen)))
        .restTimer!;
    var changes = 0;
    timer.addListener(() => changes++);

    await tester.tap(check(all.first));
    await tester.tap(check(all.first));
    await settle(tester);

    final after = await sets(tester, id);
    expect(after.where((s) => s.completedAtMs != null), hasLength(1));
    expect(changes, 1, reason: 'one rest started, not two');
    expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);
  });

  h.appTest('adding a set puts one more row at the end of that exercise', (
    tester,
  ) async {
    final id = await startPush(tester);
    await openRunning(tester);
    await tester.tap(find.text('+ Add set').first);
    await settle(tester);

    final all = await sets(tester, id);
    expect(all, hasLength(7));
    // Last time had three sets, so the new one copies the last of them.
    expect(all[3].exerciseRef, bench);
    expect(all[3].reps, 7);
    expect(find.text('7 reps'), findsNWidgets(2));
  });

  h.appTest('the exercise menu moves an exercise up or down, and the ends '
      'cannot move past themselves', (tester) async {
    final id = await startPush(tester);
    await openRunning(tester);

    await tester.tap(find.byTooltip('Menu for Bench press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(menuItem(tester, 'Move up').enabled, isFalse);
    expect(menuItem(tester, 'Move down').enabled, isTrue);
    await tester.tap(find.text('Move down'));
    await settle(tester);

    final all = await sets(tester, id);
    expect(all.first.exerciseRef, press);
    expect(all.last.exerciseRef, bench);
    expect(
      tester.getTopLeft(find.text('Overhead press')).dy,
      lessThan(tester.getTopLeft(find.text('Bench press')).dy),
    );
  });

  h.appTest('the exercise menu removes an exercise with its sets', (
    tester,
  ) async {
    final id = await startPush(tester);
    await openRunning(tester);
    await tester.tap(find.byTooltip('Menu for Bench press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Remove exercise'));
    await settle(tester);

    expect(find.text('Bench press'), findsNothing);
    final all = await sets(tester, id);
    expect(all, hasLength(3));
    expect(all.every((s) => s.exerciseRef == press), isTrue);
  });

  h.appTest('replace and details are not in the menu until task 4.4 fills '
      'in their seams', (tester) async {
    await startPush(tester);
    await openRunning(tester);
    await tester.tap(find.byTooltip('Menu for Bench press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Move up'), findsOneWidget);
    expect(find.text('Remove exercise'), findsOneWidget);
    expect(find.text('Replace exercise'), findsNothing);
    expect(find.text('Exercise details'), findsNothing);
    expect(find.text('+ Add exercise'), findsNothing);
  });

  h.appTest('with the seams filled: Add exercise and Replace go through the '
      'picker, and Replace says why it is off once a set is logged', (
    tester,
  ) async {
    final id = await startPush(tester);
    final details = <String>[];
    final picks = <String>[];
    WorkoutSeams.exerciseDetail = (context, ref) => details.add(ref);
    WorkoutSeams.exercisePicker =
        (
          context, {
          required onPick,
          required alreadyIn,
          bool single = false,
        }) async {
          picks.add('${single ? 'one' : 'many'} ${alreadyIn.length}');
          final said = await onPick('wger:1', single ? 'Dips' : 'Chin-up');
          picks.add(said ?? 'ok');
          // The same exercise again is refused in plain words.
          picks.add(await onPick('wger:1', 'Chin-up') ?? 'ok');
        };
    await openRunning(tester);

    await tester.tap(find.text('+ Add exercise'));
    await settle(tester);
    expect(picks, [
      'many 2',
      'ok',
      'That exercise is already in this workout.',
    ]);
    expect(find.text('Chin-up'), findsOneWidget);
    expect(
      (await sets(tester, id)).where((s) => s.exerciseRef == 'wger:1'),
      hasLength(3),
    );

    // Replace overhead press (nothing logged): allowed.
    picks.clear();
    await tester.ensureVisible(find.byTooltip('Menu for Overhead press'));
    await tester.tap(find.byTooltip('Menu for Overhead press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Replace exercise'));
    await settle(tester);
    expect(picks.first, 'one 3');

    // Log a bench set: Replace for bench is off, with the reason.
    final all = await sets(tester, id);
    await tester.ensureVisible(check(all.first));
    await tester.pumpAndSettle();
    await tester.tap(check(all.first));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Menu for Bench press'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu for Bench press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('Not once a set is logged. Add the new exercise instead.'),
      findsOneWidget,
    );
    expect(menuItem(tester, 'Replace exercise').enabled, isFalse);
    await tester.tap(find.text('Exercise details'));
    await settle(tester);
    expect(details, [bench]);
  });

  h.appTest('the screen closes itself when the workout is deleted '
      'somewhere else, and its rest goes with it', (tester) async {
    final id = await startPush(tester);
    await openRunning(tester);
    final all = await sets(tester, id);
    await tester.tap(check(all.first));
    await settle(tester);
    expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);

    await tester.runAsync(() => h.db.deleteWorkout(id));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorkoutScreen), findsNothing);
    expect(find.text('Rest 2:00 of 2:00'), findsNothing);
    expect(find.text('Today'), findsWidgets);
    // Nothing is left running, so Home has no bar.
    expect(find.widgetWithText(TextButton, 'Return'), findsNothing);
  });

  h.appTest('a workout that was finished somewhere else is closed too', (
    tester,
  ) async {
    final id = await startPush(tester);
    await openRunning(tester);
    await tester.runAsync(() => h.db.finishWorkout(id, h.now));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WorkoutScreen), findsNothing);
  });

  h.appTest('closing the app in the middle of a workout loses nothing: a new '
      'app on the same database offers Return with every logged set', (
    tester,
  ) async {
    final id = await startPush(tester);
    await openRunning(tester);
    final all = await sets(tester, id);
    await tester.tap(check(all[0]));
    await settle(tester);
    await tester.tap(check(all[1]));
    await settle(tester);

    // The app is killed: everything above the database is gone.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));

    await h.openApp(tester);
    expect(find.text('Workout running, 0 min'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    expect(find.text('Done'), findsNWidgets(2));
    expect(find.text('Bench press'), findsOneWidget);
    // The rest timer is not kept: it only runs while the app is open.
    expect(find.textContaining('Rest '), findsNothing);
    final rows = await sets(tester, id);
    expect(rows.where((s) => s.completedAtMs != null), hasLength(2));
  });

  h.appTest('the screen reads from the top: title, Finish, then each exercise '
      'and its sets in order', (tester) async {
    final id = await startPush(tester);
    final handle = tester.ensureSemantics();
    await openRunning(tester);
    final all = await sets(tester, id);
    final order = [
      find.text('Push A'),
      find.text('Bench press'),
      check(all[0]),
      check(all[1]),
      check(all[2]),
      find.text('Overhead press'),
      check(all[3]),
    ];
    for (var i = 1; i < order.length; i++) {
      expect(
        tester.getRect(order[i]).top,
        greaterThanOrEqualTo(tester.getRect(order[i - 1]).top),
        reason: 'item $i comes after item ${i - 1}',
      );
    }
    handle.dispose();
  });

  for (final size in [const Size(344, 700), const Size(673, 700)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp and text scale $scale: '
          'nothing overflows, targets are 48 dp', (tester) async {
        final id = await startPush(tester);
        await openRunning(tester, size: size, scale: scale);
        final all = await sets(tester, id);
        await tester.tap(check(all.first));
        await settle(tester);
        for (final s in all.skip(1)) {
          await tester.ensureVisible(check(s));
          await tester.pump();
          final box = tester.getSize(check(s));
          expect(box.width, greaterThanOrEqualTo(48));
          expect(box.height, greaterThanOrEqualTo(48));
        }
        // The two number cells are targets too.
        for (final f in [
          find.text('175 lb').first,
          find.text('8 reps').first,
        ]) {
          final cell = find.ancestor(of: f, matching: find.byType(InkWell));
          expect(tester.getSize(cell.first).height, greaterThanOrEqualTo(48));
        }
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -3000),
        );
        await tester.pump();
      });
    }
  }

  h.appTest('metric users see kilograms in the rows and in last time', (
    tester,
  ) async {
    await h.real(tester, () => h.db.setUnits(UnitSystem.metric));
    await startPush(tester);
    await openRunning(tester);
    expect(find.text('79.4 kg'), findsNWidgets(3)); // 175 lb
    expect(
      find.text('Last time (Nov 5): 79.4 x 8, 79.4 x 8, 79.4 x 7'),
      findsOneWidget,
    );
    expect(find.textContaining(' lb'), findsNothing);
  });
}
