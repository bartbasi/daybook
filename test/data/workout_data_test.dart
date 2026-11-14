// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/math/training.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const imp = UnitSystem.imperial;

/// A wall-clock time on a local date at a local offset in hours.
Now at(String date, int h, int m, [double offsetHours = -6]) =>
    Now.fromLocal(date, h * 60 + m, (offsetHours * 60).round());

const bench = 'wger:192';
const press = 'wger:119';
const row = 'wger:109';
const squat = 'wger:111';

RoutineExerciseInput ex(String ref, String name, {int? sets, int? rest}) =>
    RoutineExerciseInput(
      exerciseRef: ref,
      exerciseName: name,
      targetSets: sets,
      restSeconds: rest,
    );

/// One exercise of a finished sample workout: sets as (lb, reps).
typedef Done = (String, String, List<(double, int)>);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<WorkoutView> view(int id) async => (await db.loadWorkout(id))!;

  List<SetView> setsOf(WorkoutView v, String ref) =>
      v.exercises.firstWhere((e) => e.exerciseRef == ref).sets;

  /// Runs a whole workout on a day: every set typed in, logged, then finished
  /// [minutes] later. Returns the workout id.
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
    for (final e in exercises) {
      var v = await view(id);
      if (!v.exercises.any((b) => b.exerciseRef == e.$1)) {
        await db.addExercise(id, e.$1, e.$2, sets: e.$3.length);
        v = await view(id);
      }
      final rows = setsOf(v, e.$1);
      for (var i = 0; i < e.$3.length; i++) {
        await db.adjustSet(
          rows[i].row.id,
          weightKg: lbToKg(e.$3[i].$1),
          reps: e.$3[i].$2,
        );
        await db.logSet(
          rows[i].row.id,
          Now(utcMs: start.utcMs + minutes * 60000, offsetMinutes: -360),
        );
      }
    }
    await db.finishWorkout(
      id,
      Now(utcMs: start.utcMs + minutes * 60000, offsetMinutes: -360),
    );
    return id;
  }

  Future<RoutineWithExercises> pushRoutine() => db.createRoutine('Push A', [
    ex(bench, 'Bench press', sets: 3, rest: 90),
    ex(press, 'Overhead press', sets: 3, rest: 60),
  ], at('2026-11-01', 9, 0));

  group('routines', () {
    test('create keeps the exercises in order with sets and rest', () async {
      final r = await db.createRoutine('Push A', [
        ex(bench, 'Bench press', sets: 3, rest: 90),
        ex(press, 'Overhead press'),
      ], at('2026-11-01', 9, 0));
      expect(r.routine.name, 'Push A');
      expect(r.exercises.map((e) => e.exerciseRef), [bench, press]);
      expect(r.exercises.map((e) => e.position), [0, 1]);
      expect(r.exercises[0].targetSets, 3);
      expect(r.exercises[0].restSeconds, 90);
      expect(r.exercises[1].restSeconds, isNull);
    });

    test(
      'edit renames and reorders; the list follows creation order',
      () async {
        final a = await pushRoutine();
        final b = await db.createRoutine('Legs', [
          ex(squat, 'Squat'),
        ], at('2026-11-01', 9, 1));
        expect((await db.listRoutines()).map((r) => r.routine.name), [
          'Push A',
          'Legs',
        ]);
        final edited = await db.updateRoutine(a.routine.id, 'Push B', [
          ex(press, 'Overhead press', sets: 4, rest: 120),
          ex(bench, 'Bench press', sets: 3),
          ex(row, 'Row'),
        ]);
        expect(edited.routine.name, 'Push B');
        expect(edited.exercises.map((e) => e.exerciseRef), [press, bench, row]);
        expect(edited.exercises[0].targetSets, 4);
        expect(edited.exercises[0].restSeconds, 120);
        expect((await db.getRoutine(b.routine.id))!.exercises, hasLength(1));
      },
    );

    test(
      'delete hides it, Undo brings it back, past workouts keep its name',
      () async {
        final r = await pushRoutine();
        final w = await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8)]),
        ], routineId: r.routine.id);
        await db.deleteRoutine(r.routine.id);
        expect(await db.listRoutines(), isEmpty);
        final v = await view(w);
        expect(v.routineName, 'Push A');
        await db.undoDeleteRoutine(r.routine.id);
        expect(await db.listRoutines(), hasLength(1));
      },
    );

    test(
      'a blank name, a repeated exercise and bad numbers are refused',
      () async {
        Future<WorkoutProblem> problem(Future<void> Function() f) async {
          try {
            await f();
          } on WorkoutRefused catch (e) {
            return e.problem;
          }
          fail('not refused');
        }

        final now = at('2026-11-01', 9, 0);
        expect(
          await problem(() => db.createRoutine('  ', [], now)),
          WorkoutProblem.blankName,
        );
        expect(
          await problem(
            () => db.createRoutine('x', [ex(bench, 'B'), ex(bench, 'B')], now),
          ),
          WorkoutProblem.duplicateExercise,
        );
        expect(
          await problem(
            () => db.createRoutine('x', [ex(bench, 'B', sets: 0)], now),
          ),
          WorkoutProblem.badNumber,
        );
        expect(
          await problem(
            () => db.createRoutine('x', [ex(bench, 'B', rest: -1)], now),
          ),
          WorkoutProblem.badNumber,
        );
        expect(await db.select(db.routines).get(), isEmpty);
      },
    );

    test('the routines stream re-emits on each change', () async {
      final seen = <List<RoutineWithExercises>>[];
      final sub = db.watchRoutines().listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      final r = await pushRoutine();
      await pumpEventQueue();
      expect(seen.last.single.exercises, hasLength(2));
      await db.deleteRoutine(r.routine.id);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await sub.cancel();
    });
  });

  group('starting a workout and prefill', () {
    test('every planned set is stored at once, not completed', () async {
      final r = await pushRoutine();
      final res = await db.startRoutine(r.routine.id, at('2026-11-12', 17, 30));
      expect(res.started, isTrue);
      final rows = await db.select(db.workoutSets).get();
      expect(rows, hasLength(6));
      expect(rows.every((s) => s.completedAtMs == null), isTrue);
      expect(rows.map((s) => s.position).toList()..sort(), [0, 1, 2, 3, 4, 5]);
      final w = res.workout!;
      expect(w.endedAtMs, isNull);
      expect(w.localDate, '2026-11-12');
      expect(w.routineId, r.routine.id);
    });

    test('the first time every set is empty', () async {
      final r = await pushRoutine();
      final id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      final v = await view(id);
      for (final e in v.exercises) {
        expect(e.lastTime, isEmpty);
        expect(e.lastTimeDate, isNull);
        for (final s in e.sets) {
          expect(s.row.weightKg, isNull);
          expect(s.row.reps, isNull);
          expect(s.previous, isNull);
          expect(s.changed, isFalse);
        }
      }
    });

    test('sets take last time across different routines', () async {
      final push = await pushRoutine();
      final upper = await db.createRoutine('Upper', [
        ex(bench, 'Bench press', sets: 3),
        ex(row, 'Row', sets: 2),
      ], at('2026-11-01', 9, 0));
      await doWorkout('2026-11-05', [
        (bench, 'Bench press', [(175, 8), (175, 8), (175, 7)]),
        (press, 'Overhead press', [(95, 8), (95, 8), (95, 8)]),
      ], routineId: push.routine.id);

      final id = (await db.startRoutine(
        upper.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      final v = await view(id);
      final b = setsOf(v, bench);
      expect(b.map((s) => kgToLb(s.row.weightKg!).round()), [175, 175, 175]);
      expect(b.map((s) => s.row.reps), [8, 8, 7]);
      expect(v.exercises.first.lastTimeDate, '2026-11-05');
      // Row was never done: empty.
      expect(
        setsOf(
          v,
          row,
        ).every((s) => s.row.weightKg == null && s.row.reps == null),
        isTrue,
      );
    });

    test(
      'sets take last time from a workout whose sets were adjusted',
      () async {
        final push = await pushRoutine();
        await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8), (175, 8), (175, 7)]),
        ], routineId: push.routine.id);
        await doWorkout('2026-11-08', [
          (bench, 'Bench press', [(175, 8), (180, 8), (185, 5)]),
        ], routineId: push.routine.id);
        final id = (await db.startRoutine(
          push.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!.id;
        final b = setsOf(await view(id), bench);
        expect(b.map((s) => kgToLb(s.row.weightKg!).round()), [175, 180, 185]);
        expect(b.map((s) => s.row.reps), [8, 8, 5]);
      },
    );

    test(
      'a routine with more sets than last time repeats last time\'s last set',
      () async {
        final r = await db.createRoutine('R', [
          ex(bench, 'Bench press', sets: 4),
        ], at('2026-11-01', 9, 0));
        await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8), (170, 7)]),
        ]);
        final id = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!.id;
        final b = setsOf(await view(id), bench);
        expect(b, hasLength(4));
        expect(b.map((s) => s.row.reps), [8, 7, 7, 7]);
      },
    );

    test(
      'the rest time comes from the routine, and is null for an added exercise',
      () async {
        final r = await pushRoutine();
        final id = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!.id;
        await db.addExercise(id, row, 'Row');
        final v = await view(id);
        expect(v.exercises.map((e) => e.restSeconds), [90, 60, null]);
      },
    );

    test('two starts in a row leave one running workout', () async {
      final r = await pushRoutine();
      final first = await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      );
      final second = await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 31),
      );
      expect(first.started, isTrue);
      expect(second.started, isFalse);
      expect(second.running!.workout.id, first.workout!.id);
      expect(second.running!.routineName, 'Push A');
      final running = await (db.select(
        db.workouts,
      )..where((w) => w.endedAtMs.isNull())).get();
      expect(running, hasLength(1));
      expect(await db.select(db.workoutSets).get(), hasLength(6));
    });

    test('two starts at the same moment still leave one', () async {
      final r = await pushRoutine();
      final results = await Future.wait([
        db.startRoutine(r.routine.id, at('2026-11-12', 17, 30)),
        db.startEmptyWorkout(at('2026-11-12', 17, 30)),
        db.startRoutine(r.routine.id, at('2026-11-12', 17, 30)),
      ]);
      expect(results.where((x) => x.started), hasLength(1));
      expect(await db.select(db.workouts).get(), hasLength(1));
    });

    test('a finished workout can be followed by a new one', () async {
      final r = await pushRoutine();
      final a = await db.startRoutine(r.routine.id, at('2026-11-12', 17, 30));
      await db.finishWorkout(a.workout!.id, at('2026-11-12', 18, 0));
      final b = await db.startRoutine(r.routine.id, at('2026-11-13', 17, 30));
      expect(b.started, isTrue);
    });

    test(
      'start again copies exercises and set counts, with the routine',
      () async {
        final push = await pushRoutine();
        final w = await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8), (175, 8)]),
          (squat, 'Squat', [(225, 5)]),
        ], routineId: push.routine.id);
        final res = await db.startAgain(w, at('2026-11-12', 17, 30));
        final v = await view(res.workout!.id);
        expect(res.workout!.routineId, push.routine.id);
        // What was done is copied: bench had 2 sets, the squat 1, and the
        // overhead press was planned but not done, so it is not copied.
        expect(setsOf(v, bench), hasLength(2));
        expect(setsOf(v, squat), hasLength(1));
        expect(v.exercises.map((e) => e.exerciseRef), [bench, squat]);
      },
    );
  });

  group('logging and adjusting', () {
    late int id;
    setUp(() async {
      final r = await pushRoutine();
      await doWorkout('2026-11-05', [
        (bench, 'Bench press', [(175, 8), (175, 8), (175, 7)]),
      ], routineId: r.routine.id);
      id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
    });

    test(
      'one log marks the stored row completed with what was shown',
      () async {
        final s = setsOf(await view(id), bench).first;
        final res = await db.logSet(s.row.id, at('2026-11-12', 17, 32));
        expect(res.set.completedAtMs, at('2026-11-12', 17, 32).utcMs);
        expect(res.set.reps, 8);
        expect(res.set.weightKg, lbToKg(175));
        final stored = await db.select(db.workoutSets).get();
        expect(
          stored.where((x) => x.workoutId == id && x.completedAtMs != null),
          hasLength(1),
        );
      },
    );

    test('logging a logged set changes nothing', () async {
      final s = setsOf(await view(id), bench).first;
      await db.logSet(s.row.id, at('2026-11-12', 17, 32));
      final again = await db.logSet(s.row.id, at('2026-11-12', 17, 40));
      expect(again.set.completedAtMs, at('2026-11-12', 17, 32).utcMs);
    });

    test('a set with no reps cannot be logged', () async {
      final r = await db.createRoutine('Legs', [
        ex(squat, 'Squat', sets: 1),
      ], at('2026-11-01', 9, 0));
      await db.finishWorkout(id, at('2026-11-12', 18, 0));
      final w = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 18, 5),
      )).workout!;
      final s = setsOf(await view(w.id), squat).single;
      await expectLater(
        db.logSet(s.row.id, at('2026-11-12', 18, 6)),
        throwsA(
          isA<WorkoutRefused>().having(
            (e) => e.problem,
            'problem',
            WorkoutProblem.needsReps,
          ),
        ),
      );
      // Typing weight and reps first makes it loggable (the first time).
      await db.adjustSet(s.row.id, weightKg: lbToKg(225), reps: 5);
      expect((await db.logSet(s.row.id, at('2026-11-12', 18, 7))).set.reps, 5);
    });

    test('adjusting before logging shows Changed from last time', () async {
      final set3 = setsOf(await view(id), bench)[2];
      expect(set3.changed, isFalse);
      await db.adjustSet(set3.row.id, weightKg: lbToKg(180), reps: 8);
      final after = setsOf(await view(id), bench)[2];
      expect(after.changed, isTrue);
      expect(after.previous!.reps, 7);
      expect(kgToLb(after.previous!.weightKg!).round(), 175);
      // Back to what it was: no longer changed.
      await db.adjustSet(set3.row.id, weightKg: lbToKg(175), reps: 7);
      expect(setsOf(await view(id), bench)[2].changed, isFalse);
    });

    test('a set can be adjusted after logging', () async {
      final s = setsOf(await view(id), bench).first;
      await db.logSet(s.row.id, at('2026-11-12', 17, 32));
      final changed = await db.adjustSet(
        s.row.id,
        weightKg: lbToKg(180),
        reps: 6,
      );
      expect(changed.reps, 6);
      expect(changed.completedAtMs, isNotNull);
    });

    test('negative or impossible numbers are refused', () async {
      final s = setsOf(await view(id), bench).first;
      for (final bad in [
        () => db.adjustSet(s.row.id, weightKg: -1, reps: 5),
        () => db.adjustSet(s.row.id, weightKg: double.nan, reps: 5),
        () => db.adjustSet(s.row.id, weightKg: 50, reps: -2),
      ]) {
        await expectLater(bad(), throwsA(isA<WorkoutRefused>()));
      }
      expect((await view(id)).exercises.first.sets.first.row.reps, 8);
    });

    test(
      'add a set copies the next set from last time, then the last set',
      () async {
        final a = await db.addSet(id, bench); // set 4: last time had 3
        expect(a.reps, 7);
        final v = await view(id);
        expect(setsOf(v, bench), hasLength(4));
        expect(v.exercises.first.sets.last.row.id, a.id);
        // Positions are in order across the whole workout.
        final order = [
          for (final e in v.exercises)
            for (final s in e.sets) s.row.position,
        ];
        expect(order, [0, 1, 2, 3, 4, 5, 6]);
        // The overhead press (first time) still follows bench.
        expect(v.exercises.map((e) => e.exerciseRef), [bench, press]);
      },
    );

    test(
      'remove a set deletes only that row; no sets left removes the exercise',
      () async {
        final v = await view(id);
        await db.removeSet(setsOf(v, bench)[1].row.id);
        expect(setsOf(await view(id), bench), hasLength(2));
        for (final s in setsOf(await view(id), press)) {
          await db.removeSet(s.row.id);
        }
        expect((await view(id)).exercises.map((e) => e.exerciseRef), [bench]);
      },
    );

    test('add an exercise mid-workout, prefilled and at the end', () async {
      final rows = await db.addExercise(id, squat, 'Squat');
      expect(rows, hasLength(3));
      final again = (await view(id)).exercises.map((e) => e.exerciseRef);
      expect(again, [bench, press, squat]);
      await expectLater(
        db.addExercise(id, squat, 'Squat'),
        throwsA(isA<WorkoutRefused>()),
      );
    });

    test('remove an exercise and move one up or down', () async {
      await db.addExercise(id, squat, 'Squat', sets: 1);
      await db.moveExercise(id, squat, -1);
      expect((await view(id)).exercises.map((e) => e.exerciseRef), [
        bench,
        squat,
        press,
      ]);
      await db.moveExercise(id, bench, -1); // already first: nothing changes
      await db.moveExercise(id, press, 1); // already last: nothing changes
      expect((await view(id)).exercises.map((e) => e.exerciseRef), [
        bench,
        squat,
        press,
      ]);
      await db.removeExercise(id, squat);
      expect((await view(id)).exercises.map((e) => e.exerciseRef), [
        bench,
        press,
      ]);
    });

    test('a finished workout cannot be edited until it is resumed', () async {
      final s = setsOf(await view(id), bench).first;
      await db.logSet(s.row.id, at('2026-11-12', 17, 40));
      await db.finishWorkout(id, at('2026-11-12', 18, 0));
      Matcher notRunning = throwsA(
        isA<WorkoutRefused>().having(
          (e) => e.problem,
          'problem',
          WorkoutProblem.notRunning,
        ),
      );
      await expectLater(
        db.logSet(s.row.id, at('2026-11-12', 18, 1)),
        notRunning,
      );
      await expectLater(
        db.adjustSet(s.row.id, weightKg: 1, reps: 1),
        notRunning,
      );
      await expectLater(db.addExercise(id, squat, 'Squat'), notRunning);
    });

    test('the workout stream re-emits on each change', () async {
      final seen = <WorkoutView?>[];
      final sub = db.watchWorkout(id).listen(seen.add);
      await pumpEventQueue();
      final first = seen.length;
      expect(seen.last!.completedSetCount, 0);
      final s = setsOf(await view(id), bench).first;
      await db.logSet(s.row.id, at('2026-11-12', 17, 32));
      await pumpEventQueue();
      expect(seen.length, greaterThan(first));
      expect(seen.last!.completedSetCount, 1);
      expect(seen.last!.nextSet!.row.id, setsOf(seen.last!, bench)[1].row.id);
      await db.adjustSet(s.row.id, weightKg: lbToKg(180), reps: 8);
      await pumpEventQueue();
      expect(seen.last!.exercises.first.sets.first.row.reps, 8);
      await db.deleteWorkout(id);
      await pumpEventQueue();
      expect(seen.last, isNull);
      await sub.cancel();
    });

    test('the running workout stream follows start and finish', () async {
      final seen = <WorkoutSummary?>[];
      final sub = db.watchRunningWorkout().listen(seen.add);
      await pumpEventQueue();
      expect(seen.last!.workout.id, id);
      expect(seen.last!.routineName, 'Push A');
      expect(seen.last!.plannedSetCount, 6);
      await db.finishWorkout(id, at('2026-11-12', 18, 0));
      await pumpEventQueue();
      expect(seen.last, isNull);
      await sub.cancel();
    });
  });

  group('a logged set survives a closed and reopened database', () {
    late Directory dir;
    late File file;
    final open = <AppDatabase>[];

    AppDatabase openDb() {
      final d = AppDatabase(NativeDatabase(file));
      open.add(d);
      return d;
    }

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      dir = Directory.systemTemp.createTempSync('daybook_workout_');
      file = File('${dir.path}${Platform.pathSeparator}daybook.sqlite');
    });

    tearDown(() async {
      for (final d in open) {
        await d.close();
      }
      open.clear();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      dir.deleteSync(recursive: true);
    });

    test(
      'the workout is still running with every other planned set intact',
      () async {
        final first = openDb();
        final r = await first.createRoutine('Push A', [
          ex(bench, 'Bench press', sets: 3, rest: 90),
          ex(press, 'Overhead press', sets: 3),
        ], at('2026-11-01', 9, 0));
        final w = (await first.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!;
        final rows = await first.select(first.workoutSets).get();
        final sets = rows.where((s) => s.exerciseRef == bench).toList();
        await first.adjustSet(sets[0].id, weightKg: lbToKg(175), reps: 8);
        await first.logSet(sets[0].id, at('2026-11-12', 17, 32));
        final before = await (first.select(
          first.workoutSets,
        )..orderBy([(s) => OrderingTerm.asc(s.id)])).get();
        await first.close();

        final second = openDb();
        final after = await (second.select(
          second.workoutSets,
        )..orderBy([(s) => OrderingTerm.asc(s.id)])).get();
        expect(after, before, reason: 'every column of every row');
        expect(after.where((s) => s.completedAtMs != null), hasLength(1));
        expect(after.where((s) => s.completedAtMs == null), hasLength(5));
        final running = await second.runningWorkout();
        expect(running!.workout.id, w.id);
        expect(running.workout.endedAtMs, isNull);
        expect(running.setCount, 1);
        expect(running.plannedSetCount, 5);
        // And it can go on: log the next set, finish, resume.
        await second.adjustSet(sets[1].id, weightKg: lbToKg(175), reps: 8);
        await second.logSet(sets[1].id, at('2026-11-12', 17, 35));
        await second.finishWorkout(w.id, at('2026-11-12', 18, 0));
        await second.close();
        final third = openDb();
        final res = await third.resumeWorkout(w.id);
        expect(res.started, isTrue);
        expect((await third.select(third.workoutSets).get()), hasLength(6));
      },
    );
  });

  group('finish and resume', () {
    test('2 planned sets not logged are hidden, Resume brings them back, then finish again', () async {
      final r = await pushRoutine();
      final id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      // Log everything except two bench sets.
      final v = await view(id);
      final all = [for (final e in v.exercises) ...e.sets];
      for (final s in all) {
        await db.adjustSet(s.row.id, weightKg: lbToKg(100), reps: 10);
      }
      final skipped = setsOf(v, bench).skip(1).map((s) => s.row.id).toSet();
      for (final s in all) {
        if (!skipped.contains(s.row.id)) {
          await db.logSet(s.row.id, at('2026-11-12', 17, 40));
        }
      }
      final originalRows = await (db.select(
        db.workoutSets,
      )..orderBy([(s) => OrderingTerm.asc(s.position)])).get();

      final finished = await db.finishWorkout(id, at('2026-11-12', 18, 22));
      expect(finished.endedAtMs, at('2026-11-12', 18, 22).utcMs);
      var rows = await db.select(db.workoutSets).get();
      expect(rows, hasLength(6));
      expect(rows.where((s) => s.completedAtMs == null), hasLength(2));
      expect((await view(id)).completedSetCount, 4);
      expect([
        for (final e in (await view(id)).exercises) ...e.sets,
      ], hasLength(4));
      expect((await db.workoutResult(id)).removedPlannedSets, 2);
      expect((await db.workoutResult(id)).setCount, 4);

      final back = await db.resumeWorkout(id);
      expect(back.started, isTrue);
      expect(back.workout!.endedAtMs, isNull);
      rows = await (db.select(
        db.workoutSets,
      )..orderBy([(s) => OrderingTerm.asc(s.position)])).get();
      expect(rows, hasLength(6));
      expect(
        [
          for (final s in rows)
            (
              s.position,
              s.exerciseRef,
              s.weightKg,
              s.reps,
              s.completedAtMs == null,
            ),
        ],
        [
          for (final s in originalRows)
            (
              s.position,
              s.exerciseRef,
              s.weightKg,
              s.reps,
              s.completedAtMs == null,
            ),
        ],
      );
      expect((await db.workoutResult(id)).removedPlannedSets, 0);

      // Finish again: the same two are removed again, and Resume again works.
      await db.finishWorkout(id, at('2026-11-12', 18, 30));
      expect(await db.select(db.workoutSets).get(), hasLength(6));
      expect((await view(id)).completedSetCount, 4);
      expect([
        for (final e in (await view(id)).exercises) ...e.sets,
      ], hasLength(4));
      await db.resumeWorkout(id);
      expect(await db.select(db.workoutSets).get(), hasLength(6));
      // Log the two this time and finish: nothing removed, nothing to resume.
      final again = await view(id);
      for (final s in [for (final e in again.exercises) ...e.sets]) {
        if (!s.isDone) await db.logSet(s.row.id, at('2026-11-12', 18, 31));
      }
      await db.finishWorkout(id, at('2026-11-12', 18, 40));
      expect(await db.select(db.workoutSets).get(), hasLength(6));
      expect((await db.workoutResult(id)).removedPlannedSets, 0);
    });

    test('resume works after the database is closed and reopened', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final dir = Directory.systemTemp.createTempSync('daybook_resume_');
      final file = File('${dir.path}${Platform.pathSeparator}d.sqlite');
      var d = AppDatabase(NativeDatabase(file));
      final r = await d.createRoutine('R', [
        ex(bench, 'Bench press', sets: 3),
      ], at('2026-11-01', 9, 0));
      final w = (await d.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!;
      final s = (await d.select(d.workoutSets).get()).first;
      await d.adjustSet(s.id, weightKg: 80, reps: 8);
      await d.logSet(s.id, at('2026-11-12', 17, 32));
      await d.finishWorkout(w.id, at('2026-11-12', 18, 0));
      await d.close();
      d = AppDatabase(NativeDatabase(file));
      await d.resumeWorkout(w.id);
      expect(await d.select(d.workoutSets).get(), hasLength(3));
      await d.close();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      dir.deleteSync(recursive: true);
    });

    test('finish with nothing logged: ends it, no estimate, no length, planned sets come back on resume', () async {
      await db.saveWeight(180, imp, at('2026-11-12', 7, 0));
      final r = await pushRoutine();
      final id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      final w = await db.finishWorkout(id, at('2026-11-12', 18, 0));
      expect(w.endedAtMs, isNotNull);
      expect(w.kcalEstimated, isNull);
      expect(await db.select(db.workoutSets).get(), hasLength(6));
      expect((await view(id)).exercises, isEmpty);
      expect((await db.workoutResult(id)).durationMs, isNull);
      expect(await db.exerciseKcalForDay('2026-11-12'), 0);
      expect(await db.startAgainList('2026-11-13'), isEmpty);
      expect((await db.workoutResult(id)).removedPlannedSets, 6);
      await db.resumeWorkout(id);
      expect(await db.select(db.workoutSets).get(), hasLength(6));
    });

    test(
      'resume is refused while another workout runs, and names it',
      () async {
        final r = await pushRoutine();
        final a = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!;
        await db.finishWorkout(a.id, at('2026-11-12', 18, 0));
        final b = (await db.startEmptyWorkout(at('2026-11-12', 19, 0)))
            .workout!;
        final res = await db.resumeWorkout(a.id);
        expect(res.started, isFalse);
        expect(res.running!.workout.id, b.id);
        expect((await db.workoutResult(a.id)).workout.endedAtMs, isNotNull);
      },
    );

    test('finishing a finished workout changes nothing', () async {
      final r = await pushRoutine();
      final id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      final one = await db.finishWorkout(id, at('2026-11-12', 18, 0));
      final two = await db.finishWorkout(id, at('2026-11-12', 19, 0));
      expect(two, one);
    });
  });

  group('calories', () {
    Future<int> sampleWorkout(Now start, int minutes) async {
      final id = (await db.startEmptyWorkout(start)).workout!.id;
      await db.addExercise(id, bench, 'Bench press', sets: 1);
      final s = (await db.select(db.workoutSets).get()).first;
      await db.adjustSet(s.id, weightKg: 80, reps: 8);
      await db.logSet(
        s.id,
        Now(
          utcMs: start.utcMs + minutes * 60000,
          offsetMinutes: start.offsetMinutes,
        ),
      );
      await db.finishWorkout(
        id,
        Now(
          utcMs: start.utcMs + minutes * 60000,
          offsetMinutes: start.offsetMinutes,
        ),
      );
      return id;
    }

    Future<Workout> row(int id) =>
        (db.select(db.workouts)..where((w) => w.id.equals(id))).getSingle();

    test(
      'with a weigh-in: 3.5 MET x kg x hours, start to the last set',
      () async {
        await db.saveWeight(181.8, imp, at('2026-11-10', 7, 0));
        final id = await sampleWorkout(at('2026-11-12', 17, 30), 52);
        final kg = (await db.weightOnOrBefore('2026-11-12'))!.weightKg;
        expect(kg, closeTo(lbToKg(181.8), 1e-9));
        // 3.5 x 82.46 kg x 52/60 h
        final kcal = (await row(id)).kcalEstimated!;
        expect(kcal, closeTo(3.5 * kg * 52 / 60, 1e-9));
        expect(kcal.round(), 250);
        expect(await db.exerciseKcalForDay('2026-11-12'), kcal);
      },
    );

    test('with no weigh-in there is no estimate, not zero', () async {
      final id = await sampleWorkout(at('2026-11-12', 17, 30), 52);
      expect((await row(id)).kcalEstimated, isNull);
      expect(await db.exerciseKcalForDay('2026-11-12'), 0);
    });

    test('a weigh-in after the workout day is not used', () async {
      await db.saveWeight(180, imp, at('2026-11-13', 7, 0));
      final id = await sampleWorkout(at('2026-11-12', 17, 30), 52);
      expect((await row(id)).kcalEstimated, isNull);
    });

    test(
      'the latest weigh-in on or before the day is used, even the same day',
      () async {
        await db.saveWeight(200, imp, at('2026-11-01', 7, 0));
        await db.saveWeight(180, imp, at('2026-11-12', 7, 0));
        await db.saveWeight(170, imp, at('2026-11-12', 20, 0));
        final id = await sampleWorkout(at('2026-11-12', 17, 30), 60);
        expect(
          (await row(id)).kcalEstimated!,
          closeTo(3.5 * lbToKg(170), 1e-9),
        );
      },
    );

    test('the user\'s own number wins in exerciseKcalForDay, and clearing it brings the estimate back', () async {
      await db.saveWeight(180, imp, at('2026-11-10', 7, 0));
      final id = await sampleWorkout(at('2026-11-12', 17, 30), 60);
      final est = (await row(id)).kcalEstimated!;
      expect(await db.exerciseKcalForDay('2026-11-12'), est);
      await db.setWorkoutKcal(id, 400);
      expect(await db.exerciseKcalForDay('2026-11-12'), 400);
      expect(
        (await row(id)).kcalEstimated,
        est,
        reason: 'the estimate is kept',
      );
      await db.setWorkoutKcal(id, 0);
      expect(await db.exerciseKcalForDay('2026-11-12'), 0);
      await db.setWorkoutKcal(id, null);
      expect(await db.exerciseKcalForDay('2026-11-12'), est);
    });

    test(
      'a negative or impossible number is refused and nothing changes',
      () async {
        final id = await sampleWorkout(at('2026-11-12', 17, 30), 60);
        await db.setWorkoutKcal(id, 300);
        for (final bad in [-1.0, double.nan, double.infinity]) {
          await expectLater(
            db.setWorkoutKcal(id, bad),
            throwsA(isA<WorkoutRefused>()),
          );
        }
        expect((await row(id)).kcalOverride, 300);
      },
    );

    test('the own number survives resume and a second finish; the estimate is redone', () async {
      await db.saveWeight(180, imp, at('2026-11-10', 7, 0));
      final start = at('2026-11-12', 17, 30);
      final id = await sampleWorkout(start, 30);
      await db.setWorkoutKcal(id, 123);
      await db.resumeWorkout(id);
      expect((await row(id)).kcalEstimated, isNull);
      expect((await row(id)).kcalOverride, 123);
      final more = await db.addSet(id, bench);
      final hourLater = Now(
        utcMs: start.utcMs + 60 * 60000,
        offsetMinutes: -360,
      );
      await db.adjustSet(more.id, weightKg: 80, reps: 8);
      await db.logSet(more.id, hourLater);
      await db.finishWorkout(id, hourLater);
      expect((await row(id)).kcalEstimated!, closeTo(3.5 * lbToKg(180), 1e-9));
      expect((await row(id)).kcalOverride, 123);
    });

    test(
      'a workout that crosses midnight belongs to the day it started',
      () async {
        await db.saveWeight(180, imp, at('2026-11-10', 7, 0));
        final start = at('2026-11-12', 23, 40);
        final id = await sampleWorkout(start, 40); // ends 00:20 on Nov 13
        final w = await row(id);
        expect(w.localDate, '2026-11-12');
        expect(
          Now(utcMs: w.endedAtMs!, offsetMinutes: -360).localDate,
          '2026-11-13',
        );
        expect(await db.exerciseKcalForDay('2026-11-12'), greaterThan(0));
        expect(await db.exerciseKcalForDay('2026-11-13'), 0);
        expect(await db.weeklyVolume('2026-11-12', (_) => ['chest']), {
          'chest': 1,
        });
      },
    );

    test(
      'a time zone change during the workout does not change its length',
      () async {
        await db.saveWeight(180, imp, at('2026-11-10', 7, 0));
        final start = at('2026-11-12', 17, 0, -6);
        final id = (await db.startEmptyWorkout(start)).workout!.id;
        await db.addExercise(id, bench, 'Bench press', sets: 1);
        final s = (await db.select(db.workoutSets).get()).first;
        await db.adjustSet(s.id, weightKg: 80, reps: 8);
        final later = Now(utcMs: start.utcMs + 30 * 60000, offsetMinutes: 60);
        await db.logSet(s.id, later);
        // Finished 30 minutes later, but the phone now says +1 hour.
        await db.finishWorkout(id, later);
        expect(
          (await row(id)).kcalEstimated!,
          closeTo(3.5 * lbToKg(180) * 0.5, 1e-9),
        );
        expect((await row(id)).localDate, '2026-11-12');
      },
    );
  });

  group('Start again', () {
    // Today is Thursday Nov 12, 2026.
    const today = '2026-11-12';

    Future<int> day(String date, {int hour = 17, String? name}) =>
        doWorkout(date, [
          (bench, 'Bench press', [(175, 8)]),
        ], hour: hour);

    test(
      'yesterday first, the same weekday last week second, then the others',
      () async {
        final nov3 = await day('2026-11-03');
        final nov5 = await day('2026-11-05');
        final nov9 = await day('2026-11-09');
        final nov11 = await day('2026-11-11');
        final list = await db.startAgainList(today);
        expect(list.map((e) => e.summary.workout.id), [
          nov11,
          nov5,
          nov9,
          nov3,
        ]);
        expect(list.map((e) => e.kind), [
          StartAgainKind.yesterday,
          StartAgainKind.sameWeekdayLastWeek,
          StartAgainKind.other,
          StartAgainKind.other,
        ]);
      },
    );

    test('with yesterday only, and with last week only', () async {
      final a = await day('2026-11-11');
      expect((await db.startAgainList(today)).map((e) => e.kind), [
        StartAgainKind.yesterday,
      ]);
      await db.deleteWorkout(a);
      final b = await day('2026-11-05');
      final only = await db.startAgainList(today);
      expect(only.single.kind, StartAgainKind.sameWeekdayLastWeek);
      expect(only.single.summary.workout.id, b);
    });

    test('with neither, the others are newest first', () async {
      final a = await day('2026-11-03');
      final b = await day('2026-11-09');
      final c = await day('2026-11-08');
      final list = await db.startAgainList(today);
      expect(list.map((e) => e.summary.workout.id), [b, c, a]);
      expect(list.every((e) => e.kind == StartAgainKind.other), isTrue);
    });

    test('two workouts on one day: the later one is that day\'s entry, the other follows', () async {
      final morning = await day('2026-11-11', hour: 7);
      final evening = await day('2026-11-11', hour: 18);
      final lastWeek = await day('2026-11-05');
      final list = await db.startAgainList(today);
      expect(list.map((e) => e.summary.workout.id), [
        evening,
        lastWeek,
        morning,
      ]);
      expect(list[2].kind, StartAgainKind.other);
    });

    test(
      'a running workout and a finished one with nothing logged are left out',
      () async {
        await day('2026-11-11');
        final empty = (await db.startEmptyWorkout(at('2026-11-10', 9, 0)))
            .workout!;
        await db.finishWorkout(empty.id, at('2026-11-10', 9, 30));
        await db.startEmptyWorkout(at('2026-11-12', 9, 0));
        final list = await db.startAgainList(today);
        expect(list, hasLength(1));
      },
    );

    test(
      'an entry says what to show: routine name, exercises, sets, minutes',
      () async {
        final r = await pushRoutine();
        await doWorkout(
          '2026-11-11',
          [
            (bench, 'Bench press', [(175, 8), (175, 8)]),
            (squat, 'Squat', [(225, 5)]),
          ],
          routineId: r.routine.id,
          minutes: 48,
        );
        final e = (await db.startAgainList(today)).single.summary;
        expect(e.routineName, 'Push A');
        expect(e.exerciseNames, ['Bench press', 'Squat']);
        expect(e.exerciseCount, 2);
        expect(e.setCount, 3);
        expect(e.durationMs, 48 * 60000);
      },
    );

    test('the list stream re-emits when a workout is finished', () async {
      final seen = <List<StartAgainEntry>>[];
      final sub = db.watchStartAgainList(today).listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await day('2026-11-11');
      await pumpEventQueue();
      expect(seen.last, hasLength(1));
      await sub.cancel();
    });

    test('start again from the first row starts with sets prefilled', () async {
      final id = await day('2026-11-11');
      final entry = (await db.startAgainList(today)).first;
      final res = await db.startAgain(
        entry.summary.workout.id,
        at(today, 17, 30),
      );
      expect(res.started, isTrue);
      final s = setsOf(await view(res.workout!.id), bench).single;
      expect(s.row.reps, 8);
      expect(s.row.completedAtMs, isNull);
      expect(id, isNot(res.workout!.id));
    });
  });

  group('records and history', () {
    test(
      'a set that beats the best gets the record flags at once and in the view',
      () async {
        await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8), (175, 8), (175, 7)]),
        ]);
        final id = (await db.startEmptyWorkout(at('2026-11-12', 17, 30)))
            .workout!
            .id;
        await db.addExercise(id, bench, 'Bench press', sets: 3);
        final rows = setsOf(await view(id), bench);
        await db.adjustSet(rows[2].row.id, weightKg: lbToKg(180), reps: 8);
        final a = await db.logSet(rows[0].row.id, at('2026-11-12', 17, 31));
        final b = await db.logSet(rows[1].row.id, at('2026-11-12', 17, 33));
        final c = await db.logSet(rows[2].row.id, at('2026-11-12', 17, 36));
        expect(a.record.any, isFalse, reason: 'ties the best');
        expect(b.record.any, isFalse);
        expect(c.record.heaviest, isTrue);
        expect(c.record.estimate, isTrue);
        final flags = setsOf(await view(id), bench).map((s) => s.record.any);
        expect(flags, [false, false, true]);
      },
    );

    test('the first time an exercise is done nothing is a record', () async {
      final id = (await db.startEmptyWorkout(at('2026-11-12', 17, 30)))
          .workout!
          .id;
      final rows = await db.addExercise(id, squat, 'Squat', sets: 1);
      await db.adjustSet(rows.single.id, weightKg: 100, reps: 5);
      expect(
        (await db.logSet(rows.single.id, at('2026-11-12', 17, 31))).record.any,
        isFalse,
      );
    });

    test(
      'exercise records, with the set each came from, and the sessions',
      () async {
        await doWorkout('2026-10-29', [
          (bench, 'Bench press', [(170, 8)]),
        ]);
        await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8), (175, 8), (175, 7)]),
        ]);
        await doWorkout('2026-11-12', [
          (bench, 'Bench press', [(175, 8), (175, 8), (180, 8)]),
        ]);
        final rec = await db.exerciseRecords(bench);
        expect(kgToLb(rec.heaviest!.weightKg!).round(), 180);
        expect(rec.heaviest!.reps, 8);
        expect(roundOneRepMaxForDisplay(kgToLb(rec.bestEstimateKg!), imp), 228);

        final sessions = await db.exerciseHistory(bench);
        expect(sessions.map((s) => s.localDate), [
          '2026-11-12',
          '2026-11-05',
          '2026-10-29',
        ]);
        expect(sessions.first.sets.map((s) => s.reps), [8, 8, 8]);
        expect(
          sessions.map(
            (s) => roundOneRepMaxForDisplay(
              kgToLb(s.bestEstimate!.estimateKg!),
              imp,
            ),
          ),
          [228, 222, 215],
        );
      },
    );

    test(
      'the finish result lists records beaten, with what they replaced',
      () async {
        await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8), (175, 8), (175, 7)]),
          (press, 'Overhead press', [(95, 8)]),
        ]);
        final id = await doWorkout('2026-11-12', [
          (bench, 'Bench press', [(175, 8), (175, 8), (180, 8)]),
          (press, 'Overhead press', [(95, 8)]),
          (squat, 'Squat', [(225, 5)]),
        ]);
        final r = await db.workoutResult(id);
        expect(r.setCount, 5);
        expect(
          r.newRecords,
          hasLength(1),
          reason: 'press tied, squat is the first time',
        );
        final b = r.newRecords.single;
        expect(b.exerciseName, 'Bench press');
        expect(kgToLb(b.heaviest!.weightKg!).round(), 180);
        expect(kgToLb(b.heaviestWasKg!).round(), 175);
        expect(
          roundOneRepMaxForDisplay(kgToLb(b.estimate!.estimateKg!), imp),
          228,
        );
        expect(roundOneRepMaxForDisplay(kgToLb(b.estimateWasKg!), imp), 222);
        expect(r.durationMs, 50 * 60000);
        // 175x8 + 175x8 + 180x8 + 95x8 + 225x5
        expect(kgToLb(r.volumeKg), closeTo(4240 + 760 + 1125, 1e-6));
      },
    );

    test('recent exercises: most recent first, each once', () async {
      await doWorkout('2026-11-05', [
        (squat, 'Squat', [(225, 5)]),
      ]);
      await doWorkout('2026-11-12', [
        (bench, 'Bench press', [(175, 8)]),
        (press, 'Overhead press', [(95, 8)]),
        (squat, 'Squat', [(225, 5)]),
      ]);
      final names = (await db.recentExercises()).map((e) => e.exerciseName);
      expect(names.toList(), ['Squat', 'Overhead press', 'Bench press']);
      expect(await db.recentExercises(limit: 2), hasLength(2));
    });
  });

  group('weekly volume', () {
    List<String> muscles(String ref) => switch (ref) {
      bench => ['chest'],
      row => ['back'],
      squat => ['quads', 'glutes'],
      _ => const [],
    };

    test(
      'counts completed sets only, per primary muscle, Monday to Sunday',
      () async {
        // Sun Nov 8 is last week. Mon Nov 9 and Thu Nov 12 are this week.
        await doWorkout('2026-11-08', [
          (bench, 'Bench press', [(175, 8), (175, 8)]),
        ]);
        await doWorkout('2026-11-09', [
          (row, 'Row', [(100, 8), (100, 8), (100, 8)]),
        ]);
        await doWorkout('2026-11-12', [
          (squat, 'Squat', [(225, 5)]),
        ]);
        // A workout still running: its logged set counts, its planned ones do not.
        final id = (await db.startEmptyWorkout(at('2026-11-14', 9, 0)))
            .workout!
            .id;
        final rows = await db.addExercise(id, bench, 'Bench press', sets: 3);
        await db.adjustSet(rows[0].id, weightKg: 80, reps: 8);
        await db.logSet(rows[0].id, at('2026-11-14', 9, 5));

        expect(await db.weeklyVolume('2026-11-12', muscles), {
          'back': 3,
          'quads': 1,
          'glutes': 1,
          'chest': 1,
        });
        expect(await db.weeklyVolume('2026-11-03', muscles), {'chest': 2});
        expect(await db.weeklyVolume('2026-11-08', muscles), {'chest': 2});
      },
    );

    test('Monday morning and Sunday night are different weeks', () async {
      await doWorkout('2026-11-15', [
        (bench, 'Bench press', [(175, 8)]),
      ], hour: 23);
      await doWorkout('2026-11-16', [
        (bench, 'Bench press', [(175, 8)]),
      ], hour: 0);
      expect(await db.weeklyVolume('2026-11-15', muscles), {'chest': 1});
      expect(await db.weeklyVolume('2026-11-16', muscles), {'chest': 1});
    });

    test(
      'a week with a daylight saving change keeps every set on its day',
      () async {
        // Clocks went back on Sunday Nov 1, 2026 (offset -5 to -6 hours).
        final a = at('2026-10-31', 22, 0, -5);
        final b = at('2026-11-01', 22, 0, -6);
        for (final start in [a, b]) {
          final id = (await db.startEmptyWorkout(start)).workout!.id;
          final s = (await db.addExercise(
            id,
            bench,
            'Bench press',
            sets: 1,
          )).single;
          await db.adjustSet(s.id, weightKg: 80, reps: 8);
          await db.logSet(s.id, start);
          await db.finishWorkout(
            id,
            Now(
              utcMs: start.utcMs + 3600000,
              offsetMinutes: start.offsetMinutes,
            ),
          );
        }
        // Fri Oct 30 and Sun Nov 1 are the same week (Mon Oct 26 to Sun Nov 1).
        expect(await db.weeklyVolume('2026-10-28', muscles), {'chest': 2});
        expect(await db.weeklyVolume('2026-11-02', muscles), isEmpty);
      },
    );

    test('the volume stream re-emits when a set is logged', () async {
      final seen = <Map<String, int>>[];
      final sub = db.watchWeeklyVolume('2026-11-12', muscles).listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      final id = (await db.startEmptyWorkout(at('2026-11-12', 9, 0)))
          .workout!
          .id;
      final s = (await db.addExercise(
        id,
        bench,
        'Bench press',
        sets: 1,
      )).single;
      await db.adjustSet(s.id, weightKg: 80, reps: 8);
      await db.logSet(s.id, at('2026-11-12', 9, 5));
      await pumpEventQueue();
      expect(seen.last, {'chest': 1});
      await sub.cancel();
    });
  });

  group('deleting a workout and Undo', () {
    test('Undo puts back every row with the same ids', () async {
      await db.saveWeight(180, imp, at('2026-11-10', 7, 0));
      final r = await pushRoutine();
      final id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      final v = await view(id);
      for (final s in [for (final e in v.exercises) ...e.sets].take(2)) {
        await db.adjustSet(s.row.id, weightKg: 80, reps: 8);
        await db.logSet(s.row.id, at('2026-11-12', 17, 40));
      }
      await db.setWorkoutKcal(id, 222);
      await db.finishWorkout(id, at('2026-11-12', 18, 0));
      final workoutBefore = await (db.select(db.workouts)).get();
      final setsBefore = await (db.select(
        db.workoutSets,
      )..orderBy([(s) => OrderingTerm.asc(s.id)])).get();

      final deleted = await db.deleteWorkout(id);
      expect(await db.select(db.workouts).get(), isEmpty);
      expect(await db.select(db.workoutSets).get(), isEmpty);
      expect(await db.exerciseKcalForDay('2026-11-12'), 0);
      expect(await db.exerciseRecords(bench).then((r) => r.heaviest), isNull);

      final back = await db.undoDeleteWorkout(deleted);
      expect(back, workoutBefore.single);
      expect(
        await (db.select(
          db.workoutSets,
        )..orderBy([(s) => OrderingTerm.asc(s.id)])).get(),
        setsBefore,
      );
      expect(await db.exerciseKcalForDay('2026-11-12'), 222);
      // The planned sets removed at finish can still be resumed.
      await db.resumeWorkout(id);
      expect(await db.select(db.workoutSets).get(), hasLength(6));
    });

    test(
      'deleting a running workout and undoing while another runs is refused',
      () async {
        final a = (await db.startEmptyWorkout(at('2026-11-12', 9, 0))).workout!;
        final deleted = await db.deleteWorkout(a.id);
        expect(await db.runningWorkout(), isNull);
        await db.startEmptyWorkout(at('2026-11-12', 10, 0));
        await expectLater(
          db.undoDeleteWorkout(deleted),
          throwsA(
            isA<WorkoutRefused>().having(
              (e) => e.problem,
              'problem',
              WorkoutProblem.anotherIsRunning,
            ),
          ),
        );
        expect(await db.select(db.workouts).get(), hasLength(1));
      },
    );

    test('deleting a workout does not touch its routine', () async {
      final r = await pushRoutine();
      final id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      await db.deleteWorkout(id);
      expect(await db.listRoutines(), hasLength(1));
    });
  });

  group('nothing typed by the user is in an error', () {
    test('refusals and missing rows carry only a fixed problem name', () async {
      const secret = 'zq-secret-name-9f3';
      final errors = <Object>[];
      Future<void> catching(Future<void> Function() f) async {
        try {
          await f();
        } on Object catch (e) {
          errors.add(e);
        }
      }

      final now = at('2026-11-12', 9, 0);
      await catching(
        () => db.createRoutine('   ', [ex('local:$secret', secret)], now),
      );
      await catching(
        () => db.createRoutine(secret, [
          ex('local:$secret', secret),
          ex('local:$secret', secret),
        ], now),
      );
      await catching(
        () => db.createRoutine(secret, [
          ex('local:$secret', secret, sets: 0),
        ], now),
      );
      final id = (await db.startEmptyWorkout(now)).workout!.id;
      await db.addExercise(id, 'local:$secret', secret, sets: 1);
      await catching(() => db.addExercise(id, 'local:$secret', secret));
      await catching(
        () async =>
            db.logSet((await db.select(db.workoutSets).get()).single.id, now),
      );
      await catching(() => db.setWorkoutKcal(id, -1));
      await catching(() => db.deleteWorkout(9999));
      await catching(() => db.loadWorkout(9999));
      await catching(() => db.addSet(id, 'local:other-$secret'));
      await db.finishWorkout(id, now);
      await catching(() => db.removeExercise(id, 'local:$secret'));

      expect(errors, isNotEmpty);
      for (final e in errors) {
        expect(e.toString(), isNot(contains(secret)));
      }
    });
  });

  // Review round: positions, planned rows left in place, time, records.
  group('review fixes', () {
    Future<void> logAll(int id, {double lb = 100, int reps = 5}) async {
      for (final e in (await view(id)).exercises) {
        for (final s in e.sets) {
          if (s.isDone) continue;
          await db.adjustSet(s.row.id, weightKg: lbToKg(lb), reps: reps);
          await db.logSet(s.row.id, at('2026-11-12', 17, 40));
        }
      }
    }

    List<String> refs(WorkoutView v) => [
      for (final e in v.exercises) e.exerciseRef,
    ];

    test(
      'adding an exercise after removed sets goes last, not into the gap',
      () async {
        final r = await db.createRoutine('R', [
          ex(bench, 'Bench press', sets: 6),
          ex(press, 'Overhead press', sets: 3),
        ], at('2026-11-01', 9, 0));
        final id = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!.id;
        for (final s in setsOf(await view(id), bench).take(4)) {
          await db.removeSet(s.row.id);
        }
        await db.addExercise(id, squat, 'Squat', sets: 3);
        final v = await view(id);
        expect(refs(v), [bench, press, squat]);
        final positions = [
          for (final e in v.exercises)
            for (final s in e.sets) s.row.position,
        ];
        expect(positions, [...positions]..sort());
        expect(positions.toSet(), hasLength(positions.length));
      },
    );

    test(
      'order is kept through removes, adds, moves and Start again',
      () async {
        final r = await db.createRoutine('R', [
          ex(bench, 'Bench press', sets: 3),
          ex(press, 'Overhead press', sets: 2),
          ex(row, 'Row', sets: 2),
        ], at('2026-11-01', 9, 0));
        final id = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!.id;
        await db.removeSet(setsOf(await view(id), press).first.row.id);
        await db.addExercise(id, squat, 'Squat', sets: 2);
        await db.moveExercise(id, squat, -1);
        await db.addSet(id, bench);
        await db.removeExercise(id, row);
        await db.addExercise(id, row, 'Row', sets: 1);
        await db.removeSet(setsOf(await view(id), bench).first.row.id);
        await db.moveExercise(id, bench, 1);
        final expected = refs(await view(id));
        expect(expected, [press, bench, squat, row]);
        await logAll(id);
        await db.finishWorkout(id, at('2026-11-12', 18, 0));
        expect(refs(await view(id)), expected);
        final again = await db.startAgain(id, at('2026-11-13', 17, 0));
        expect(refs(await view(again.workout!.id)), expected);
      },
    );

    test(
      'a finished workout keeps its unlogged rows, and no reader shows them',
      () async {
        final r = await pushRoutine();
        final id = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!.id;
        final s = setsOf(await view(id), bench).first;
        await db.adjustSet(s.row.id, weightKg: lbToKg(175), reps: 8);
        await db.logSet(s.row.id, at('2026-11-12', 17, 40));
        await db.finishWorkout(id, at('2026-11-12', 18, 0));

        expect(await db.select(db.workoutSets).get(), hasLength(6));
        final v = await view(id);
        expect(refs(v), [bench]);
        expect(v.exercises.single.sets, hasLength(1));
        expect(v.completedSetCount, 1);
        expect(v.nextSet, isNull);
        final entry = (await db.startAgainList('2026-11-13')).single.summary;
        expect(entry.plannedSetCount, 0);
        expect(entry.exerciseNames, ['Bench press']);
        expect(entry.setCount, 1);
        expect((await db.recentExercises()).map((e) => e.exerciseRef), [bench]);
        expect(await db.exerciseHistory(press), isEmpty);
        expect((await db.exerciseRecords(press)).heaviest, isNull);
        expect(await db.weeklyVolume('2026-11-12', (_) => ['m']), {'m': 1});
        final res = await db.workoutResult(id);
        expect(res.setCount, 1);
        expect(res.removedPlannedSets, 5);
        final copy = await db.startAgain(id, at('2026-11-13', 17, 0));
        expect(refs(await view(copy.workout!.id)), [bench]);
        expect(setsOf(await view(copy.workout!.id), bench), hasLength(1));
      },
    );

    test(
      'finish, resume, finish again leaves the same rows each time',
      () async {
        final r = await pushRoutine();
        final id = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 17, 30),
        )).workout!.id;
        final s = setsOf(await view(id), bench).first;
        await db.adjustSet(s.row.id, weightKg: lbToKg(175), reps: 8);
        await db.logSet(s.row.id, at('2026-11-12', 17, 40));
        final before = await db.select(db.workoutSets).get();
        await db.finishWorkout(id, at('2026-11-12', 18, 0));
        await db.resumeWorkout(id);
        expect(await db.select(db.workoutSets).get(), before);
        expect((await db.runningWorkout())!.plannedSetCount, 5);
        await db.finishWorkout(id, at('2026-11-12', 18, 30));
        expect(await db.select(db.workoutSets).get(), before);
        expect((await db.workoutResult(id)).removedPlannedSets, 5);
        await db.resumeWorkout(id);
        expect(refs(await view(id)), [bench, press]);
      },
    );

    test('on a real file, finish and resume survive a reopen', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final dir = Directory.systemTemp.createTempSync('daybook_fin_');
      final file = File('${dir.path}${Platform.pathSeparator}d.sqlite');
      var d = AppDatabase(NativeDatabase(file));
      final r = await d.createRoutine('R', [
        ex(bench, 'Bench press', sets: 3),
      ], at('2026-11-01', 9, 0));
      final w = (await d.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!;
      final first = (await d.select(d.workoutSets).get()).first;
      await d.adjustSet(first.id, weightKg: 80, reps: 8);
      await d.logSet(first.id, at('2026-11-12', 17, 32));
      await d.finishWorkout(w.id, at('2026-11-12', 18, 0));
      await d.close();
      d = AppDatabase(NativeDatabase(file));
      expect(await d.select(d.workoutSets).get(), hasLength(3));
      expect((await d.workoutResult(w.id)).removedPlannedSets, 2);
      expect((await d.loadWorkout(w.id))!.exercises.single.sets, hasLength(1));
      await d.resumeWorkout(w.id);
      await d.close();
      d = AppDatabase(NativeDatabase(file));
      expect((await d.runningWorkout())!.plannedSetCount, 2);
      expect((await d.loadWorkout(w.id))!.exercises.single.sets, hasLength(3));
      await d.close();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      dir.deleteSync(recursive: true);
    });

    Future<int> oneSetWorkout(
      Now start,
      int setAfterMin,
      int finishAfterMin,
    ) async {
      final id = (await db.startEmptyWorkout(start)).workout!.id;
      final s = (await db.addExercise(
        id,
        bench,
        'Bench press',
        sets: 1,
      )).single;
      await db.adjustSet(s.id, weightKg: 80, reps: 8);
      Now plus(int m) => Now(
        utcMs: start.utcMs + m * 60000,
        offsetMinutes: start.offsetMinutes,
      );
      await db.logSet(s.id, plus(setAfterMin));
      await db.finishWorkout(id, plus(finishAfterMin));
      return id;
    }

    test(
      'calories and duration run to the last logged set, not to Finish',
      () async {
        await db.saveWeight(181.8, imp, at('2026-11-10', 7, 0));
        final start = at('2026-11-12', 17, 30);
        final a = await oneSetWorkout(start, 52, 52);
        final w = (await db.workoutResult(a)).workout;
        expect(w.kcalEstimated, closeTo(3.5 * lbToKg(181.8) * 52 / 60, 1e-9));
        expect(w.kcalEstimated!.round(), 250);
        expect((await db.workoutResult(a)).durationMs, 52 * 60000);
        await db.deleteWorkout(a);
        final b = await oneSetWorkout(start, 52, 52 + 15 * 60);
        final res = await db.workoutResult(b);
        expect(res.workout.kcalEstimated!.round(), 250);
        expect(res.durationMs, 52 * 60000);
        expect(
          res.workout.endedAtMs,
          start.utcMs + (52 + 900) * 60000,
          reason: 'endedAtMs is still when Finish was tapped',
        );
      },
    );

    test(
      'a workout with no logged set has no duration and no estimate',
      () async {
        await db.saveWeight(180, imp, at('2026-11-10', 7, 0));
        final id = (await db.startEmptyWorkout(at('2026-11-12', 17, 30)))
            .workout!
            .id;
        await db.addExercise(id, bench, 'Bench press', sets: 2);
        await db.finishWorkout(id, at('2026-11-12', 19, 30));
        final res = await db.workoutResult(id);
        expect(res.durationMs, isNull);
        expect(res.workout.kcalEstimated, isNull);
      },
    );

    test(
      'Resume after 8 days, one more set, Finish: time runs to the last set',
      () async {
        await db.saveWeight(180, imp, at('2026-11-01', 7, 0));
        final start = at('2026-11-12', 17, 30);
        final id = await oneSetWorkout(start, 50, 55);
        await db.resumeWorkout(id);
        final s = await db.addSet(id, bench);
        final later = at('2026-11-20', 18, 0);
        await db.adjustSet(s.id, weightKg: 80, reps: 8);
        await db.logSet(s.id, later);
        await db.finishWorkout(id, later);
        final res = await db.workoutResult(id);
        expect(res.durationMs, later.utcMs - start.utcMs);
        expect(res.durationMs, greaterThan(7 * 24 * 3600 * 1000));
      },
    );

    test(
      'the first session is never a record, set by set or in the summary',
      () async {
        final id = (await db.startEmptyWorkout(at('2026-11-12', 17, 30)))
            .workout!
            .id;
        final rows = await db.addExercise(id, bench, 'Bench press', sets: 2);
        await db.adjustSet(rows[0].id, weightKg: lbToKg(135), reps: 8);
        await db.adjustSet(rows[1].id, weightKg: lbToKg(155), reps: 8);
        final a = await db.logSet(rows[0].id, at('2026-11-12', 17, 35));
        final b = await db.logSet(rows[1].id, at('2026-11-12', 17, 40));
        expect(a.record.any, isFalse);
        expect(b.record.any, isFalse);
        await db.finishWorkout(id, at('2026-11-12', 17, 45));
        expect((await db.workoutResult(id)).newRecords, isEmpty);
        expect(setsOf(await view(id), bench).map((s) => s.record.any), [
          false,
          false,
        ]);
      },
    );

    test(
      'the per-set flag and the summary agree against an earlier workout',
      () async {
        await doWorkout('2026-11-05', [
          (bench, 'Bench press', [(175, 8)]),
        ]);
        final id = await doWorkout('2026-11-12', [
          (bench, 'Bench press', [(185, 8), (180, 8), (175, 8)]),
        ]);
        // Both 185 and 180 beat the earlier workout; 175 ties it.
        expect(setsOf(await view(id), bench).map((s) => s.record.heaviest), [
          true,
          true,
          false,
        ]);
        final res = await db.workoutResult(id);
        expect(res.newRecords, hasLength(1));
        expect(kgToLb(res.newRecords.single.heaviest!.weightKg!).round(), 185);
      },
    );

    test('flags follow the current data: editing an earlier workout later changes them', () async {
      final a = await doWorkout('2026-11-05', [
        (bench, 'Bench press', [(175, 8)]),
      ]);
      final b = await doWorkout('2026-11-12', [
        (bench, 'Bench press', [(180, 8)]),
      ]);
      expect(setsOf(await view(b), bench).single.record.heaviest, isTrue);
      await db.resumeWorkout(a);
      final s = setsOf(await view(a), bench).single;
      await db.adjustSet(s.row.id, weightKg: lbToKg(190), reps: 8);
      await db.finishWorkout(a, at('2026-11-05', 18, 0));
      expect(setsOf(await view(b), bench).single.record.any, isFalse);
      expect((await db.workoutResult(b)).newRecords, isEmpty);
    });

    test('adjusting a logged set to no reps is refused', () async {
      final id = (await db.startEmptyWorkout(at('2026-11-12', 17, 30)))
          .workout!
          .id;
      final s = (await db.addExercise(
        id,
        bench,
        'Bench press',
        sets: 1,
      )).single;
      await db.adjustSet(s.id, weightKg: 80, reps: 8);
      await db.logSet(s.id, at('2026-11-12', 17, 35));
      for (final bad in [null, 0]) {
        await expectLater(
          db.adjustSet(s.id, weightKg: 80, reps: bad),
          throwsA(
            isA<WorkoutRefused>().having(
              (e) => e.problem,
              'problem',
              WorkoutProblem.needsReps,
            ),
          ),
        );
      }
      expect((await db.select(db.workoutSets).get()).single.reps, 8);
      // A set not yet logged may still be cleared.
      final t = await db.addSet(id, bench);
      expect(
        (await db.adjustSet(t.id, weightKg: null, reps: null)).reps,
        isNull,
      );
    });

    test('records and the flags come back after Delete and Undo', () async {
      await doWorkout('2026-11-05', [
        (bench, 'Bench press', [(175, 8)]),
      ]);
      final b = await doWorkout('2026-11-12', [
        (bench, 'Bench press', [(180, 8)]),
      ]);
      final deleted = await db.deleteWorkout(b);
      expect(
        kgToLb((await db.exerciseRecords(bench)).heaviest!.weightKg!).round(),
        175,
      );
      await db.undoDeleteWorkout(deleted);
      expect(
        kgToLb((await db.exerciseRecords(bench)).heaviest!.weightKg!).round(),
        180,
      );
      expect(setsOf(await view(b), bench).single.record.heaviest, isTrue);
      expect((await db.workoutResult(b)).newRecords, hasLength(1));
    });

    Future<void> trigger(String sql) => db.customStatement(sql);

    test('a failing write inside start leaves nothing behind', () async {
      final r = await pushRoutine();
      await trigger(
        'CREATE TRIGGER stop BEFORE INSERT ON workout_sets '
        'WHEN NEW.position = 4 '
        "BEGIN SELECT RAISE(ABORT, 'stop'); END",
      );
      await expectLater(
        db.startRoutine(r.routine.id, at('2026-11-12', 17, 30)),
        throwsA(anything),
      );
      expect(await db.select(db.workouts).get(), isEmpty);
      expect(await db.select(db.workoutSets).get(), isEmpty);
      await trigger('DROP TRIGGER stop');
      expect(
        (await db.startRoutine(r.routine.id, at('2026-11-12', 17, 31))).started,
        isTrue,
      );
    });

    test('a failing write inside finish and inside resume leaves the database as it was', () async {
      final r = await pushRoutine();
      final id = (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
      final s = setsOf(await view(id), bench).first;
      await db.adjustSet(s.row.id, weightKg: lbToKg(175), reps: 8);
      await db.logSet(s.row.id, at('2026-11-12', 17, 40));
      Future<String> snap() async =>
          '${await db.select(db.workouts).get()}'
          '${await db.select(db.workoutSets).get()}';
      var before = await snap();
      await trigger(
        'CREATE TRIGGER stop BEFORE UPDATE ON workouts '
        'WHEN NEW.ended_at_ms IS NOT NULL '
        "BEGIN SELECT RAISE(ABORT, 'stop'); END",
      );
      await expectLater(
        db.finishWorkout(id, at('2026-11-12', 18, 0)),
        throwsA(anything),
      );
      expect(await snap(), before);
      await trigger('DROP TRIGGER stop');
      await db.finishWorkout(id, at('2026-11-12', 18, 0));
      before = await snap();
      await trigger(
        'CREATE TRIGGER stop BEFORE UPDATE ON workouts '
        'WHEN NEW.ended_at_ms IS NULL '
        "BEGIN SELECT RAISE(ABORT, 'stop'); END",
      );
      await expectLater(db.resumeWorkout(id), throwsA(anything));
      expect(await snap(), before);
    });

    test(
      '200 past workouts: prefill, flags and records are unchanged',
      () async {
        final r = await db.createRoutine('R', [
          ex(bench, 'Bench press', sets: 3),
        ], at('2026-01-01', 9, 0));
        final all = <DoneSet>[];
        var last = <(double, int)>[];
        for (var i = 0; i < 200; i++) {
          final start = at('2026-01-01', 9, 0).utcMs + i * 86400000;
          final wid = await db
              .into(db.workouts)
              .insert(
                WorkoutsCompanion.insert(
                  localDate: Now(utcMs: start, offsetMinutes: -360).localDate,
                  startedAtMs: start,
                  tzOffsetMinutes: -360,
                  endedAtMs: Value(start + 3600000),
                ),
              );
          last = [];
          for (var k = 0; k < 3; k++) {
            final kg = 60.0 + (i * 7 + k * 3) % 41;
            final reps = 3 + (i + k) % 10;
            last.add((kg, reps));
            final at0 = start + 60000 * (k + 1);
            final sid = await db
                .into(db.workoutSets)
                .insert(
                  WorkoutSetsCompanion.insert(
                    workoutId: wid,
                    position: k,
                    exerciseRef: bench,
                    exerciseName: 'Bench press',
                    weightKg: Value(kg),
                    reps: Value(reps),
                    completedAtMs: Value(at0),
                  ),
                );
            all.add(DoneSet(weightKg: kg, reps: reps, atMs: at0, id: sid));
          }
        }
        final id = (await db.startRoutine(
          r.routine.id,
          at('2026-09-01', 9, 0),
        )).workout!.id;
        final b = setsOf(await view(id), bench);
        expect([for (final s in b) (s.row.weightKg, s.row.reps)], last);
        final best = recordsOf(all);
        await db.adjustSet(
          b[0].row.id,
          weightKg: best.heaviest!.weightKg! + 1,
          reps: 5,
        );
        final logged = await db.logSet(b[0].row.id, at('2026-09-01', 9, 5));
        expect(logged.record.heaviest, isTrue);
        expect(setsOf(await view(id), bench)[0].record.heaviest, isTrue);
        final rec = await db.exerciseRecords(bench);
        expect(rec.heaviest!.weightKg, best.heaviest!.weightKg! + 1);
      },
    );
  });

  group('dates on records, replace exercise, volume stream', () {
    test('records and history rows carry their workout\'s day', () async {
      await doWorkout('2026-11-05', [
        (bench, 'Bench press', [(175, 8)]),
      ]);
      // A workout that crosses midnight: its sets belong to the start day.
      final start = at('2026-11-12', 23, 40);
      final id = (await db.startEmptyWorkout(start)).workout!.id;
      final s = (await db.addExercise(
        id,
        bench,
        'Bench press',
        sets: 1,
      )).single;
      await db.adjustSet(s.id, weightKg: lbToKg(180), reps: 8);
      final late = Now(utcMs: start.utcMs + 30 * 60000, offsetMinutes: -360);
      await db.logSet(s.id, late);
      await db.finishWorkout(id, late);
      expect(late.localDate, '2026-11-13');

      final rec = await db.exerciseRecords(bench);
      expect(rec.heaviest!.localDate, '2026-11-12');
      expect(rec.bestEstimate!.localDate, '2026-11-12');
      final sessions = await db.exerciseHistory(bench);
      expect(sessions.map((x) => x.localDate), ['2026-11-12', '2026-11-05']);
      expect(sessions.first.sets.single.localDate, '2026-11-12');
      final res = await db.workoutResult(id);
      expect(res.newRecords.single.heaviest!.localDate, '2026-11-12');
    });

    Future<int> startPush() async {
      final r = await db.createRoutine('Push A', [
        ex(bench, 'Bench press', sets: 3),
        ex(press, 'Overhead press', sets: 2),
        ex(row, 'Row', sets: 1),
      ], at('2026-11-01', 9, 0));
      return (await db.startRoutine(
        r.routine.id,
        at('2026-11-12', 17, 30),
      )).workout!.id;
    }

    test('replace takes the old one\'s place, with the same number of sets, prefilled from its own last time', () async {
      await doWorkout('2026-11-05', [
        (squat, 'Squat', [(225, 5), (230, 4)]),
      ]);
      final id = await startPush();
      final out = await db.replaceExercise(id, press, squat, 'Squat');
      expect(out, hasLength(2));
      final v = await view(id);
      expect(v.exercises.map((e) => e.exerciseRef), [bench, squat, row]);
      final sq = setsOf(v, squat);
      expect(sq.map((s) => s.row.reps), [5, 4]);
      expect(sq.map((s) => s.row.exerciseName).toSet(), {'Squat'});
      expect(v.exercises[1].lastTimeDate, '2026-11-05');
      expect(
        (await db.select(db.workoutSets).get()).where(
          (s) => s.exerciseRef == press,
        ),
        isEmpty,
      );
    });

    test('replace with an exercise never done leaves the sets empty', () async {
      final id = await startPush();
      await db.replaceExercise(id, row, squat, 'Squat');
      final sq = setsOf(await view(id), squat).single;
      expect(sq.row.weightKg, isNull);
      expect(sq.row.reps, isNull);
    });

    test('replace is refused with a logged set, a duplicate, or a finished workout', () async {
      final id = await startPush();
      WorkoutProblem? problem(Object? e) =>
          e is WorkoutRefused ? e.problem : null;
      Future<WorkoutProblem?> tryReplace(String a, String b) async {
        try {
          await db.replaceExercise(id, a, b, 'X');
        } on Object catch (e) {
          return problem(e);
        }
        return null;
      }

      final s = setsOf(await view(id), bench).first;
      await db.adjustSet(s.row.id, weightKg: 80, reps: 8);
      await db.logSet(s.row.id, at('2026-11-12', 17, 40));
      final before = await db.select(db.workoutSets).get();
      expect(
        await tryReplace(bench, squat),
        WorkoutProblem.loggedSetsInExercise,
      );
      expect(await tryReplace(press, row), WorkoutProblem.duplicateExercise);
      expect(await tryReplace(press, press), WorkoutProblem.duplicateExercise);
      expect(await db.select(db.workoutSets).get(), before);
      await db.finishWorkout(id, at('2026-11-12', 18, 0));
      expect(await tryReplace(press, squat), WorkoutProblem.notRunning);
    });

    test('a failing write in the middle of replace changes nothing', () async {
      final id = await startPush();
      final before = (await db.select(db.workoutSets).get()).toString();
      // The second of the two overhead press rows is the one that fails.
      await db.customStatement(
        'CREATE TRIGGER stop BEFORE UPDATE ON workout_sets '
        "WHEN NEW.exercise_ref = 'wger:111' AND NEW.position = 4 "
        "BEGIN SELECT RAISE(ABORT, 'stop'); END",
      );
      await expectLater(
        db.replaceExercise(id, press, squat, 'Squat'),
        throwsA(anything),
      );
      expect((await db.select(db.workoutSets).get()).toString(), before);
    });

    test(
      'the weekly volume stream re-emits when the user\'s exercises change',
      () async {
        var muscle = 'chest';
        final seen = <Map<String, int>>[];
        final sub = db
            .watchWeeklyVolume('2026-11-12', (_) => [muscle])
            .listen(seen.add);
        final id = (await db.startEmptyWorkout(at('2026-11-12', 9, 0)))
            .workout!
            .id;
        final s = (await db.addExercise(
          id,
          bench,
          'Bench press',
          sets: 1,
        )).single;
        await db.adjustSet(s.id, weightKg: 80, reps: 8);
        await db.logSet(s.id, at('2026-11-12', 9, 5));
        await pumpEventQueue();
        expect(seen.last, {'chest': 1});
        // The user edits an exercise's muscles: the stream asks the caller's
        // function again.
        muscle = 'back';
        await db
            .into(db.exercises)
            .insert(ExercisesCompanion.insert(name: 'Mine'));
        await pumpEventQueue();
        expect(seen.last, {'back': 1});
        await sub.cancel();
      },
    );
  });

  group('a workout left running from an earlier day', () {
    final monday = at('2026-11-09', 17, 0);
    final thursday = at('2026-11-12', 18, 0);

    /// Monday's push workout, [logged] of 6 sets done, 30 minutes apart.
    Future<int> forgotten(int logged) async {
      final r = await pushRoutine();
      final id = (await db.startRoutine(r.routine.id, monday)).workout!.id;
      final all = [for (final e in (await view(id)).exercises) ...e.sets];
      for (var i = 0; i < logged; i++) {
        await db.adjustSet(all[i].row.id, weightKg: lbToKg(100), reps: 10);
        await db.logSet(
          all[i].row.id,
          Now(utcMs: monday.utcMs + (i + 1) * 30 * 60000, offsetMinutes: -360),
        );
      }
      return id;
    }

    Future<Workout> row(int id) =>
        (db.select(db.workouts)..where((w) => w.id.equals(id))).getSingle();

    test('Thursday\'s start finishes Monday\'s with its Monday length and calories', () async {
      await db.saveWeight(181.8, imp, at('2026-11-08', 7, 0));
      final id = await forgotten(2);
      final res = await db.startEmptyWorkout(thursday);
      expect(res.started, isTrue);
      expect(res.finishedEarlier!.workout.id, id);
      expect(res.finishedEarlier!.setCount, 2);
      expect(res.finishedEarlier!.durationMs, 60 * 60000);
      final m = await row(id);
      expect(m.endedAtMs, thursday.utcMs, reason: 'Finish happened now');
      expect(m.localDate, '2026-11-09');
      expect(m.kcalEstimated, closeTo(3.5 * lbToKg(181.8) * 1.0, 1e-9));
      expect((await db.workoutResult(id)).durationMs, 60 * 60000);
      expect((await db.workoutResult(id)).removedPlannedSets, 4);
      final running = await db.select(db.workouts).get();
      expect(running.where((w) => w.endedAtMs == null), hasLength(1));
      expect(res.workout!.id, isNot(id));
      expect(await db.exerciseKcalForDay('2026-11-09'), m.kcalEstimated);
      expect(await db.exerciseKcalForDay('2026-11-12'), 0);
    });

    test(
      'with nothing logged on Monday it has no length and no estimate',
      () async {
        await db.saveWeight(181.8, imp, at('2026-11-08', 7, 0));
        final id = await forgotten(0);
        final res = await db.startEmptyWorkout(thursday);
        expect(res.finishedEarlier!.workout.id, id);
        expect(res.finishedEarlier!.durationMs, isNull);
        final m = await row(id);
        expect(m.endedAtMs, isNotNull);
        expect(m.kcalEstimated, isNull);
      },
    );

    test('startRoutine and startAgain do the same', () async {
      final id = await forgotten(1);
      final r = (await db.listRoutines()).single;
      final a = await db.startRoutine(r.routine.id, thursday);
      expect(a.finishedEarlier!.workout.id, id);
      await db.finishWorkout(a.workout!.id, at('2026-11-12', 19, 0));
      final id2 = (await db.startEmptyWorkout(at('2026-11-13', 9, 0)))
          .workout!
          .id;
      final b = await db.startAgain(id, at('2026-11-15', 9, 0));
      expect(b.started, isTrue);
      expect(b.finishedEarlier!.workout.id, id2);
    });

    test(
      'a workout that started earlier today still refuses the start',
      () async {
        final r = await pushRoutine();
        final running = (await db.startRoutine(
          r.routine.id,
          at('2026-11-12', 9, 0),
        )).workout!;
        final res = await db.startEmptyWorkout(at('2026-11-12', 17, 0));
        expect(res.started, isFalse);
        expect(res.running!.workout.id, running.id);
        expect(res.finishedEarlier, isNull);
        expect((await row(running.id)).endedAtMs, isNull);
      },
    );

    test(
      'started at 23:50, a start at 00:10 the next day finishes it',
      () async {
        final late = at('2026-11-12', 23, 50);
        final id = (await db.startEmptyWorkout(late)).workout!.id;
        final res = await db.startEmptyWorkout(at('2026-11-13', 0, 10));
        expect(res.started, isTrue);
        expect(res.finishedEarlier!.workout.id, id);
        expect((await row(id)).endedAtMs, at('2026-11-13', 0, 10).utcMs);
      },
    );

    test(
      'a failing write in the middle leaves Monday running and nothing new',
      () async {
        await db.saveWeight(181.8, imp, at('2026-11-08', 7, 0));
        final id = await forgotten(2);
        final r = (await db.listRoutines()).single;
        final before =
            '${await db.select(db.workouts).get()}'
            '${await db.select(db.workoutSets).get()}';
        await db.customStatement(
          'CREATE TRIGGER stop BEFORE INSERT ON workout_sets '
          "WHEN NEW.position = 3 BEGIN SELECT RAISE(ABORT, 'stop'); END",
        );
        await expectLater(
          db.startRoutine(r.routine.id, thursday),
          throwsA(anything),
        );
        expect(
          '${await db.select(db.workouts).get()}'
          '${await db.select(db.workoutSets).get()}',
          before,
        );
        expect((await row(id)).endedAtMs, isNull);
      },
    );
  });
}
