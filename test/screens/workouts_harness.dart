// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/exercise_library.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/platform/rest_alert.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

// What the workout screen tests share (task 4.3): an in memory database, a
// clock the test can move, every platform channel the workout path could use
// recorded, and a sample history. Call [register] once in main.

const bench = 'wger:192';
const press = 'wger:119';
const squat = 'wger:111';
const row = 'wger:109';

/// A local time on a date, at UTC minus 6 unless given.
Now at(String date, int h, int m, [int offset = -360]) =>
    Now.fromLocal(date, h * 60 + m, offset);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Waits (a little at a time, outside the fake clock) until [finder] finds
/// something, for at most 40 rounds.
Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await settle(tester);
  }
}

/// In the open exercise picker: search for [query] and tap Add on the row of
/// [ref].
Future<void> pickInPicker(WidgetTester tester, String query, String ref) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Search exercises'),
    query,
  );
  final add = find.descendant(
    of: find.byKey(ValueKey('row-$ref')),
    matching: find.text('Add'),
  );
  await waitFor(tester, add);
  await tester.tap(add);
  await settle(tester);
}

/// A database that can hold or refuse reads of the exercises table (the user's
/// own exercises), which the exercise library load needs, and nothing else. With [hold] set, the library stays loading until it completes; with
/// [fail] set, the load fails once it is let through.
class ExerciseReads extends QueryInterceptor {
  Completer<void>? hold;
  var fail = false;

  /// How many reads of the table there have been, and the number of the first
  /// one that fails (null for none), for a failure partway through a flow.
  var reads = 0;
  int? failFromRead;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('FROM "exercises"')) {
      reads++;
      await hold?.future;
      if (fail || (failFromRead != null && reads >= failFromRead!)) {
        throw StateError('unreadable');
      }
    }
    return super.runSelect(executor, statement, args);
  }
}

/// One exercise of a sample workout: ref, name, sets as (lb, reps).
typedef Done = (String, String, List<(double, int)>);

/// Channels a permission prompt or a notification could be asked through.
const permissionChannels = [
  'flutter.baseflow.com/permissions/methods',
  'dexterous.com/flutter/local_notifications',
  'dev.fluttercommunity.plus/notifications',
  'permission_handler',
];

/// A rest alert that records what it is asked, for the rest timer tests.
class FakeRestAlert extends RestAlert {
  FakeRestAlert({this.grant = true});

  /// What the user answers when asked for permission.
  bool grant;

  /// `request`, `schedule:` plus the UTC ms, and `cancel`, in order.
  final calls = <String>[];

  /// The times of the schedule calls, in order.
  List<int> get scheduled => [
    for (final c in calls)
      if (c.startsWith('schedule:')) int.parse(c.substring(9)),
  ];

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    return grant;
  }

  @override
  Future<void> schedule(int endUtcMs) async => calls.add('schedule:$endUtcMs');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

class WorkoutHarness {
  AppDatabase? _db;

  AppDatabase get db => _db!;

  /// A test may put its own database in place of the one setUp opened. The
  /// first is closed then, so it does not stay open in memory.
  set db(AppDatabase value) {
    final old = _db;
    _db = value;
    if (old != null && !identical(old, value)) unawaited(old.close());
  }

  late Now now;

  /// Every method called on the platform channel (haptics, system calls).
  final platformCalls = <String>[];

  /// Every call on a channel a permission or notification would use.
  final permissionCalls = <String>[];

  int get vibrations =>
      platformCalls.where((c) => c == 'HapticFeedback.vibrate').length;

  void register() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    setUp(() {
      // Not through the setter: the last test's database is closed already.
      _db = AppDatabase(NativeDatabase.memory());
      now = at('2026-11-12', 17, 29);
      platformCalls.clear();
      permissionCalls.clear();
    });
  }

  /// A test with every channel answered, the app unmounted at the end (so the
  /// rest timer and drift's clean-up timers are gone), and the database closed.
  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      // In a test the notification plugin has not registered itself. With it
      // registered, a real call to it shows up in [permissionCalls].
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      for (final c in ['home_widget', 'home_widget/updates']) {
        messenger.setMockMethodCallHandler(MethodChannel(c), (_) async => null);
      }
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call.method);
        return null;
      });
      for (final c in permissionChannels) {
        messenger.setMockMethodCallHandler(MethodChannel(c), (call) async {
          permissionCalls.add('$c ${call.method}');
          return null;
        });
      }
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(db.close);
        for (final c in [
          'home_widget',
          'home_widget/updates',
          ...permissionChannels,
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(c), null);
        }
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      }
    });
  }

  Future<void> openApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double textScale = 1,
    RestAlert? alert,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // The exercise list is read once and remembered. Read it here, outside the
    // test's fake time, so a read started inside one test cannot be left
    // waiting for a later one.
    await tester.runAsync(() => ExerciseLibrary.load());
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => now,
        foodsPath: Future.value(''),
        restAlert: alert ?? const LocalRestAlert(),
      ),
    );
    await settle(tester);
  }

  Future<void> openWorkoutsTab(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Workouts'));
    await settle(tester);
  }

  /// Back from the open screen, and the end of its slide.
  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  // Sample data

  /// The workout started at [start], every set typed in and logged at
  /// [minutes] after the start, then finished two minutes later. Returns its
  /// id.
  Future<int> doWorkout(
    String date,
    List<Done> exercises, {
    int hour = 17,
    int minutes = 50,
    int? routineId,
  }) async {
    final start = at(date, hour, 0);
    final r = routineId == null
        ? await db.startEmptyWorkout(start)
        : await db.startRoutine(routineId, start);
    final id = r.workout!.id;
    final logAt = Now(
      utcMs: start.utcMs + minutes * 60000,
      offsetMinutes: -360,
    );
    for (final e in exercises) {
      var v = (await db.loadWorkout(id))!;
      if (!v.exercises.any((b) => b.exerciseRef == e.$1)) {
        await db.addExercise(id, e.$1, e.$2, sets: e.$3.length);
        v = (await db.loadWorkout(id))!;
      }
      final rows = v.exercises.firstWhere((b) => b.exerciseRef == e.$1).sets;
      for (var i = 0; i < e.$3.length; i++) {
        await db.adjustSet(
          rows[i].row.id,
          weightKg: lbToKg(e.$3[i].$1),
          reps: e.$3[i].$2,
        );
        await db.logSet(rows[i].row.id, logAt);
      }
    }
    await db.finishWorkout(
      id,
      Now(utcMs: logAt.utcMs + 120000, offsetMinutes: -360),
    );
    return id;
  }

  /// Routines Push A (bench 3 sets with a 120 second rest, overhead press 3
  /// sets with no rest given) and Legs (squat), and two finished workouts:
  /// Legs yesterday (Wed, Nov 11) and Push A last Thursday (Nov 5). Today is
  /// Thu, Nov 12.
  Future<({int pushId, int legsId})> seedSample(WidgetTester tester) async {
    return real(tester, () async {
      final push = await db.createRoutine('Push A', [
        const RoutineExerciseInput(
          exerciseRef: bench,
          exerciseName: 'Bench press',
          targetSets: 3,
          restSeconds: 120,
        ),
        const RoutineExerciseInput(
          exerciseRef: press,
          exerciseName: 'Overhead press',
          targetSets: 3,
        ),
      ], at('2026-11-01', 9, 0));
      final legs = await db.createRoutine('Legs', [
        const RoutineExerciseInput(
          exerciseRef: squat,
          exerciseName: 'Squat',
          targetSets: 3,
        ),
      ], at('2026-11-01', 9, 1));
      await doWorkout(
        '2026-11-05',
        [
          (bench, 'Bench press', [(175, 8), (175, 8), (175, 7)]),
          (press, 'Overhead press', [(95, 8), (95, 8), (95, 8)]),
        ],
        routineId: push.routine.id,
        minutes: 52,
      );
      await doWorkout(
        '2026-11-11',
        [
          (squat, 'Squat', [(225, 5), (225, 5), (225, 5)]),
        ],
        routineId: legs.routine.id,
        minutes: 48,
      );
      return (pushId: push.routine.id, legsId: legs.routine.id);
    });
  }

  Future<List<WorkoutSet>> allSets(WidgetTester tester, int workoutId) => real(
    tester,
    () =>
        (db.select(db.workoutSets)
              ..where((s) => s.workoutId.equals(workoutId))
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get(),
  );

  Future<List<Workout>> workoutRows(WidgetTester tester) =>
      real(tester, () => db.select(db.workouts).get());
}
