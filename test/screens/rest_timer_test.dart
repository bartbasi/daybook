// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/rest_timer_bar.dart';
import 'package:daybook/screens/workouts/workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../speed/tap_counter.dart';
import 'workouts_harness.dart';

// The in-app rest timer (task 4.3, workout.html frame 3): it counts down from
// the exercise's rest by the app's clock, has -15 s, +15 s and Skip, is ended
// and replaced by the next set, survives leaving the screen and switching
// tabs, vibrates once at zero, and never asks for a permission.

void main() {
  final h = WorkoutHarness()..register();

  late int workoutId;

  Finder check(WorkoutSet s) => find.byKey(ValueKey('check-${s.id}'));

  Future<List<WorkoutSet>> sets(WidgetTester tester) =>
      h.allSets(tester, workoutId);

  /// Moves the app's clock and lets the timer's tick see it.
  Future<void> advance(WidgetTester tester, int seconds) async {
    h.now = Now(
      utcMs: h.now.utcMs + seconds * 1000,
      offsetMinutes: h.now.offsetMinutes,
    );
    await tester.pump(const Duration(seconds: 1));
  }

  /// Push A running with its screen open. Bench rests 120 s, overhead press
  /// has no rest in its routine.
  Future<List<WorkoutSet>> openPush(
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
    return sets(tester);
  }

  Future<void> log(WidgetTester tester, WorkoutSet s) async {
    await tester.ensureVisible(check(s));
    await tester.pump();
    await tester.tap(check(s));
    await settle(tester);
  }

  h.appTest('the bar counts down by the app\'s clock, from the exercise\'s '
      'rest', (tester) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);

    await advance(tester, 36);
    expect(find.text('Rest 1:24 of 2:00'), findsOneWidget);
    await advance(tester, 20);
    expect(find.text('Rest 1:04 of 2:00'), findsOneWidget);
    expect(find.text('Up next: set 2, 175 lb x 8'), findsOneWidget);
    // A bar is drawn too: the number is not carried by it alone.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  h.appTest('-15 s and +15 s change this rest only', (tester) async {
    final all = await openPush(tester);
    await log(tester, all.first);

    await tester.tap(find.text('-15 s'));
    await tester.pump();
    expect(find.text('Rest 1:45 of 1:45'), findsOneWidget);
    await tester.tap(find.text('+15 s'));
    await tester.tap(find.text('+15 s'));
    await tester.pump();
    expect(find.text('Rest 2:15 of 2:15'), findsOneWidget);

    // The next set's rest is the exercise's own again.
    await log(tester, all[1]);
    expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);
  });

  h.appTest('-15 s on a rest with less than 15 seconds left ends it quietly', (
    tester,
  ) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    await advance(tester, 110);
    expect(find.text('Rest 0:10 of 2:00'), findsOneWidget);

    await tester.tap(find.text('-15 s'));
    await tester.pump();
    expect(find.text('Rest done'), findsOneWidget);
    expect(h.vibrations, 0, reason: 'the user ended it');
  });

  h.appTest('Skip hides the timer and it never vibrates', (tester) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.textContaining('Rest '), findsNothing);
    expect(find.text('Skip'), findsNothing);

    await advance(tester, 300);
    await advance(tester, 1);
    expect(h.vibrations, 0);
    expect(find.textContaining('Rest '), findsNothing);
  });

  h.appTest('logging the next set ends the rest and starts the next one', (
    tester,
  ) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    await advance(tester, 30);
    expect(find.text('Rest 1:30 of 2:00'), findsOneWidget);

    await log(tester, all[1]);
    expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);
    expect(find.textContaining('Rest '), findsOneWidget, reason: 'one timer');

    // An exercise with no rest of its own gets 90 seconds.
    await log(tester, all[3]);
    expect(find.text('Rest 1:30 of 1:30'), findsOneWidget);
  });

  h.appTest('it vibrates once at zero, shows Rest done, and Hide closes it', (
    tester,
  ) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    await advance(tester, 119);
    expect(h.vibrations, 0);
    expect(find.text('Rest 0:01 of 2:00'), findsOneWidget);

    await advance(tester, 1);
    expect(h.vibrations, 1);
    expect(find.text('Rest done'), findsOneWidget);
    expect(find.text('Up next: set 2, 175 lb x 8'), findsOneWidget);
    expect(find.text('-15 s'), findsNothing);

    await advance(tester, 30);
    await advance(tester, 30);
    expect(h.vibrations, 1, reason: 'once');
    await tester.tap(find.text('Hide'));
    await tester.pump();
    expect(find.textContaining('Rest'), findsNothing);
    expect(h.vibrations, 1);
  });

  h.appTest('it keeps time when the screen is left and when the tab is '
      'changed, and is there when the workout is opened again', (tester) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    await advance(tester, 10);

    await h.back(tester); // leave the screen
    expect(find.byType(WorkoutScreen), findsNothing);
    await advance(tester, 10);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Weight'));
    await settle(tester);
    await advance(tester, 10);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Workouts'));
    await settle(tester);
    await advance(tester, 10);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Today'));
    await settle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    // 40 seconds have passed in all (the settles add no clock time).
    expect(find.text('Rest 1:20 of 2:00'), findsOneWidget);
    expect(h.vibrations, 0);
  });

  h.appTest('a rest that ends while the screen is closed still vibrates '
      'once, and says Rest done on coming back', (tester) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    await h.back(tester);

    await advance(tester, 125);
    expect(h.vibrations, 1);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    expect(find.text('Rest done'), findsOneWidget);
    expect(h.vibrations, 1);
  });

  h.appTest('the bar is below the sets: it does not cover a row', (
    tester,
  ) async {
    final all = await openPush(tester, size: const Size(400, 560));
    await log(tester, all.first);
    final bar = tester.getRect(find.byType(RestTimerBar));
    final list = tester.getRect(find.byType(SingleChildScrollView).first);
    expect(list.bottom, lessThanOrEqualTo(bar.top + 0.5));
    // Every visible row ends above the bar.
    final lastCheck = tester.getRect(check(all[1]));
    expect(lastCheck.bottom, lessThanOrEqualTo(bar.top + 0.5));
  });

  h.appTest('a routine that gives a rest of 0 starts no timer', (tester) async {
    final ids = await h.seedSample(tester);
    final r = await h.real(tester, () async {
      await h.db.updateRoutine(ids.legsId, 'Legs', const [
        RoutineExerciseInput(
          exerciseRef: squat,
          exerciseName: 'Squat',
          targetSets: 3,
          restSeconds: 0,
        ),
      ]);
      return h.db.startRoutine(ids.legsId, h.now);
    });
    workoutId = r.workout!.id;
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    final all = await sets(tester);
    await log(tester, all.first);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('Rest '), findsNothing);
  });

  h.appTest('Finish ends the rest', (tester) async {
    final all = await openPush(tester);
    await log(tester, all.first);
    expect(find.text('Rest 2:00 of 2:00'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await settle(tester);
    await advance(tester, 200);
    expect(h.vibrations, 0);
    expect(find.textContaining('Rest '), findsNothing);
  });

  h.appTest('every control on the bar says what it does, and only the end is '
      'announced', (tester) async {
    final handle = tester.ensureSemantics();
    final all = await openPush(tester);
    await log(tester, all.first);
    for (final label in [
      'Take 15 seconds off the rest',
      'Add 15 seconds to the rest',
      'Skip the rest',
    ]) {
      final f = find.bySemanticsLabel(label);
      expect(f, findsOneWidget, reason: label);
      expect(tester.getSemantics(f).flagsCollection.isButton, isTrue);
    }
    final running = tester.getSemantics(find.text('Rest 2:00 of 2:00'));
    expect(running.flagsCollection.isLiveRegion, isFalse);

    await advance(tester, 120);
    final over = tester.getSemantics(find.text('Rest done'));
    expect(over.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  h.appTest('no permission and no notification is asked for anywhere on the '
      'whole path: start, log, rest, skip, finish (speed target 5)', (
    tester,
  ) async {
    await h.seedSample(tester);
    await h.openApp(tester);
    await h.openWorkoutsTab(tester);
    final taps = TapCounter(tester);
    await taps.tap(find.widgetWithText(FilledButton, 'Start').at(1));
    await settle(tester);
    final running = (await h.workoutRows(tester))
        .singleWhere((w) => w.endedAtMs == null);
    workoutId = running.id;
    final all = await sets(tester);

    final before = taps.count;
    await taps.tap(check(all.first));
    await settle(tester);
    expect(taps.count - before, 1, reason: 'one tap logs a prefilled set');
    await advance(tester, 120);
    await tester.tap(find.text('Hide'));
    await tester.pump();
    await tester.tap(check(all[1]));
    await settle(tester);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);

    expect(h.permissionCalls, isEmpty);
    expect(
      // The framework's own sounds and window title are not the workout's.
      h.platformCalls.where(
        (c) => !c.startsWith('System') && c != 'HapticFeedback.vibrate',
      ),
      isEmpty,
      reason: 'the only platform call is the buzz at the end of a rest',
    );
    expect(h.vibrations, 1);
  });

  test('the workout screens use no permission, notification or timezone '
      'package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final name in [
      'flutter_local_notifications',
      'permission_handler',
      'timezone',
      'vibration',
      'awesome_notifications',
      'workmanager',
    ]) {
      expect(pubspec.contains(name), isFalse, reason: name);
    }
    for (final f in Directory('lib/screens/workouts').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      // Code only: a comment may say that nothing is asked.
      final text = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join(' ')
          .toLowerCase();
      expect(text.contains('permission'), isFalse, reason: f.path);
      expect(text.contains('notification'), isFalse, reason: f.path);
    }
  });

  for (final size in [const Size(344, 600), const Size(673, 600)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('the bar at ${size.width.round()} dp and text scale $scale: no '
          'overflow, every button 48 dp', (tester) async {
        final all = await openPush(tester, size: size, scale: scale);
        await log(tester, all.first);
        for (final label in ['-15 s', '+15 s', 'Skip']) {
          final b = find.widgetWithText(OutlinedButton, label);
          final box = tester.getSize(b);
          expect(box.height, greaterThanOrEqualTo(48), reason: label);
          expect(box.width, greaterThanOrEqualTo(48), reason: label);
        }
        // The sets still have room: the list is not squeezed to nothing.
        expect(
          tester.getSize(find.byType(SingleChildScrollView).first).height,
          greaterThan(40),
        );
        await advance(tester, 120);
        final hide = tester.getSize(
          find.widgetWithText(OutlinedButton, 'Hide'),
        );
        expect(hide.height, greaterThanOrEqualTo(48));
      });
    }
  }
}
