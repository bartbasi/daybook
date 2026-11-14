// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../clock.dart';
import '../math/training.dart';
import '../util/dates.dart';
import 'database.dart';
import 'food_data.dart' show liveQuery;
import 'goal_data.dart';

// Routines and workouts: what the Workouts tab, the active workout screen,
// the finish screen, exercise detail and weekly volume read and write. No
// user-facing text here, and nothing here looks an exercise up: an exercise
// is a ref ('wger:<id>' or 'local:<id>') plus the name copied when it was
// added, and the caller passes in anything else it knows (muscles).
//
// How a workout is stored (the schema is not changed for it):
// - workouts.localDate is the day the workout STARTED, set once. A workout
//   that runs past midnight stays on its start day, and so do its calories
//   and its sets in weekly volume.
// - A workout is running while endedAtMs is null. Only one runs at a time.
// - Every planned set is a workout_sets row with completedAtMs null from the
//   moment the workout starts. Logging sets completedAtMs, in its own write.
// - workout_sets.position orders the whole workout. The sets of one exercise
//   are next to each other, and exercises appear in order of first position.
// - A workout has no name column. Its name is its routine's name; with no
//   routine (an empty workout) the screen names it by its exercises.
// - Rest time is not stored on a workout. It is read from the workout's
//   routine for that exercise, and is null for an exercise added mid-workout.

/// Why a write was refused. Carries no user data.
enum WorkoutProblem {
  /// Another workout is running (resume, or undoing a delete).
  anotherIsRunning,

  /// The workout is finished, so its sets cannot change. Resume it first.
  notRunning,

  /// The set has no reps yet, so it cannot be logged.
  needsReps,

  /// A weight, reps, rest, set count or calorie number that is negative, not
  /// a number, or (for a set count) zero.
  badNumber,

  /// A routine with no name.
  blankName,

  /// The same exercise twice in one routine or one workout.
  duplicateExercise,
}

class WorkoutRefused implements Exception {
  const WorkoutRefused(this.problem);

  final WorkoutProblem problem;

  @override
  String toString() => 'WorkoutRefused(${problem.name})';
}

/// Weight (kg) and reps of one set. Null weight is a body weight set.
typedef SetValues = ({double? weightKg, int? reps});

/// Muscle names for an exercise ref, given by the caller (who has the
/// exercise library). An unknown exercise gives an empty list.
typedef MusclesOf = Iterable<String> Function(String exerciseRef);

/// Sets a routine exercise or an added exercise gets when none is given.
const defaultSetCount = 3;

// Routines

class RoutineExerciseInput {
  const RoutineExerciseInput({
    required this.exerciseRef,
    required this.exerciseName,
    this.targetSets,
    this.restSeconds,
  });

  final String exerciseRef;
  final String exerciseName;

  /// Null means [defaultSetCount].
  final int? targetSets;

  /// Rest between sets in seconds. Null means the screen's default.
  final int? restSeconds;
}

class RoutineWithExercises {
  const RoutineWithExercises(this.routine, this.exercises);

  final Routine routine;

  /// In order.
  final List<RoutineExercise> exercises;
}

// Workouts

/// A workout for lists: Start again, history, Return to workout.
class WorkoutSummary {
  const WorkoutSummary({
    required this.workout,
    required this.routineName,
    required this.exerciseNames,
    required this.setCount,
    required this.plannedSetCount,
  });

  final Workout workout;

  /// The routine's name, or null (empty workout, or the routine is gone).
  /// Then the screen names the workout by [exerciseNames].
  final String? routineName;

  /// Each exercise once, in order.
  final List<String> exerciseNames;

  /// Completed sets.
  final int setCount;

  /// Sets still planned (not logged). Only a running workout has any.
  final int plannedSetCount;

  int get exerciseCount => exerciseNames.length;
  bool get isRunning => workout.endedAtMs == null;

  /// Finish minus start in milliseconds, or null while running.
  int? get durationMs => workout.endedAtMs == null
      ? null
      : workout.endedAtMs! - workout.startedAtMs;
}

enum StartAgainKind { yesterday, sameWeekdayLastWeek, other }

class StartAgainEntry {
  const StartAgainEntry(this.kind, this.summary);

  final StartAgainKind kind;
  final WorkoutSummary summary;
}

/// The answer to starting or resuming a workout. Exactly one of [workout]
/// and [running] is set.
class StartResult {
  const StartResult.started(Workout this.workout) : running = null;
  const StartResult.refused(WorkoutSummary this.running) : workout = null;

  /// The workout now running.
  final Workout? workout;

  /// Set when nothing was started because this one is running. It names it.
  final WorkoutSummary? running;

  bool get started => workout != null;
}

class SetView {
  const SetView({
    required this.row,
    required this.previous,
    required this.changed,
    required this.record,
  });

  final WorkoutSet row;

  /// The same set number the last time this exercise was done, or null (first
  /// time, or this is a set beyond last time's).
  final SetValues? previous;

  /// A set not yet logged whose weight or reps differ from [previous]: "Changed,
  /// from 175 x 7". Always false once logged.
  final bool changed;

  /// For a logged set: whether it beat every set logged before it.
  final RecordCheck record;

  bool get isDone => row.completedAtMs != null;
}

class ExerciseBlock {
  const ExerciseBlock({
    required this.exerciseRef,
    required this.exerciseName,
    required this.restSeconds,
    required this.lastTimeDate,
    required this.lastTime,
    required this.sets,
  });

  final String exerciseRef;
  final String exerciseName;

  /// From the workout's routine, or null.
  final int? restSeconds;

  /// The day of the last time this exercise was done in another workout, and
  /// its sets in order ("Last time (Nov 5): 175 x 8, ..."). Null and empty the
  /// first time.
  final String? lastTimeDate;
  final List<SetValues> lastTime;

  /// In order.
  final List<SetView> sets;
}

/// A workout with its exercises and sets, for the active screen.
class WorkoutView {
  const WorkoutView({
    required this.workout,
    required this.routineName,
    required this.exercises,
  });

  final Workout workout;
  final String? routineName;
  final List<ExerciseBlock> exercises;

  bool get isRunning => workout.endedAtMs == null;

  /// The first set not yet logged, in order, or null. "Up next" and the set
  /// the list scrolls to.
  SetView? get nextSet {
    for (final e in exercises) {
      for (final s in e.sets) {
        if (!s.isDone) return s;
      }
    }
    return null;
  }

  int get completedSetCount => [
    for (final e in exercises)
      for (final s in e.sets)
        if (s.isDone) s,
  ].length;
}

/// A set just logged and whether it beat the exercise's records.
class LoggedSet {
  const LoggedSet(this.set, this.record);

  final WorkoutSet set;
  final RecordCheck record;
}

/// A record beaten in a workout, with what it replaced (null when there was
/// no earlier set to beat in that kind of record).
class RecordBreak {
  const RecordBreak({
    required this.exerciseRef,
    required this.exerciseName,
    this.heaviest,
    this.heaviestWasKg,
    this.estimate,
    this.estimateWasKg,
  });

  final String exerciseRef;
  final String exerciseName;

  /// Set when this workout has a heavier set than ever before, with its
  /// weight before in [heaviestWasKg].
  final DoneSet? heaviest;
  final double? heaviestWasKg;

  /// Set when this workout has a better estimated one-rep max than ever
  /// before, and the estimate before it (same unit as the weights, kg).
  final DoneSet? estimate;
  final double? estimateWasKg;
}

/// What the finish screen shows.
class WorkoutResult {
  const WorkoutResult({
    required this.workout,
    required this.setCount,
    required this.volumeKg,
    required this.newRecords,
    required this.removedPlannedSets,
  });

  /// Read back, with the estimated and own calories.
  final Workout workout;
  final int setCount;

  /// Weight x reps over the completed sets, in kg.
  final double volumeKg;
  final List<RecordBreak> newRecords;

  /// Planned sets removed at finish that Resume would bring back.
  final int removedPlannedSets;

  /// Finish minus start in milliseconds, or null while running.
  int? get durationMs => workout.endedAtMs == null
      ? null
      : workout.endedAtMs! - workout.startedAtMs;
}

/// One past session of an exercise, for exercise detail.
class ExerciseSession {
  const ExerciseSession({
    required this.workout,
    required this.sets,
    required this.bestEstimate,
  });

  final Workout workout;

  /// Completed sets, in order.
  final List<DoneSet> sets;

  /// The set with the best estimate this session ("228 lb best 180 x 8"), or
  /// null when no set counts.
  final DoneSet? bestEstimate;
}

/// A workout removed by [WorkoutData.deleteWorkout], kept so Undo can put
/// back exactly the same rows. It lives in memory only.
class DeletedWorkout {
  const DeletedWorkout._(this.workout, this.sets, this._stash);

  final Workout workout;
  final List<WorkoutSet> sets;
  final String? _stash;
}

typedef _Plan = ({String ref, String name, int sets});
typedef _Done = ({WorkoutSet set, Workout workout});

extension WorkoutData on AppDatabase {
  // Routines

  /// Saves a new routine, last in the list. Exercises keep the order given.
  /// Throws [WorkoutRefused] (blank name, duplicate exercise, bad number).
  Future<RoutineWithExercises> createRoutine(
    String name,
    List<RoutineExerciseInput> exercises,
    Now now,
  ) {
    _checkRoutine(name, exercises);
    return transaction(() async {
      final last =
          await (select(routines)
                ..orderBy([(r) => OrderingTerm.desc(r.position)])
                ..limit(1))
              .getSingleOrNull();
      final id = await into(routines).insert(
        RoutinesCompanion.insert(
          name: name.trim(),
          position: (last?.position ?? -1) + 1,
          createdAtMs: now.utcMs,
        ),
      );
      await _writeRoutineExercises(id, exercises);
      return (await getRoutine(id))!;
    });
  }

  /// Replaces a routine's name and exercises (the editor's Save). Dragging to
  /// reorder is just a different order in [exercises].
  Future<RoutineWithExercises> updateRoutine(
    int id,
    String name,
    List<RoutineExerciseInput> exercises,
  ) {
    _checkRoutine(name, exercises);
    return transaction(() async {
      final changed = await (update(routines)..where((r) => r.id.equals(id)))
          .write(RoutinesCompanion(name: Value(name.trim())));
      if (changed == 0) throw StateError('No such routine');
      await (delete(
        routineExercises,
      )..where((e) => e.routineId.equals(id))).go();
      await _writeRoutineExercises(id, exercises);
      return (await getRoutine(id))!;
    });
  }

  /// Deletes a routine from the lists. The row is kept (archived) so past
  /// workouts keep its name. [undoDeleteRoutine] brings it back.
  Future<void> deleteRoutine(int id) => _setArchived(id, true);

  Future<void> undoDeleteRoutine(int id) => _setArchived(id, false);

  Future<void> _setArchived(int id, bool archived) async {
    final changed = await (update(routines)..where((r) => r.id.equals(id)))
        .write(RoutinesCompanion(archived: Value(archived)));
    if (changed == 0) throw StateError('No such routine');
  }

  /// A routine, deleted or not, or null.
  Future<RoutineWithExercises?> getRoutine(int id) async {
    final r = await (select(
      routines,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (r == null) return null;
    return RoutineWithExercises(r, await _routineExercises(id));
  }

  /// Routines that are not deleted, in list order, with their exercises.
  Future<List<RoutineWithExercises>> listRoutines() async {
    final rows =
        await (select(routines)
              ..where((r) => r.archived.equals(false))
              ..orderBy([
                (r) => OrderingTerm.asc(r.position),
                (r) => OrderingTerm.asc(r.id),
              ]))
            .get();
    return [
      for (final r in rows)
        RoutineWithExercises(r, await _routineExercises(r.id)),
    ];
  }

  Stream<List<RoutineWithExercises>> watchRoutines() =>
      liveQuery(this, [routines, routineExercises], listRoutines);

  Future<List<RoutineExercise>> _routineExercises(int routineId) =>
      (select(routineExercises)
            ..where((e) => e.routineId.equals(routineId))
            ..orderBy([
              (e) => OrderingTerm.asc(e.position),
              (e) => OrderingTerm.asc(e.id),
            ]))
          .get();

  void _checkRoutine(String name, List<RoutineExerciseInput> exercises) {
    if (name.trim().isEmpty) {
      throw const WorkoutRefused(WorkoutProblem.blankName);
    }
    final refs = <String>{};
    for (final e in exercises) {
      if (!refs.add(e.exerciseRef)) {
        throw const WorkoutRefused(WorkoutProblem.duplicateExercise);
      }
      final sets = e.targetSets, rest = e.restSeconds;
      if ((sets != null && sets < 1) || (rest != null && rest < 0)) {
        throw const WorkoutRefused(WorkoutProblem.badNumber);
      }
    }
  }

  Future<void> _writeRoutineExercises(
    int routineId,
    List<RoutineExerciseInput> exercises,
  ) async {
    for (var i = 0; i < exercises.length; i++) {
      final e = exercises[i];
      await into(routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: routineId,
          position: i,
          exerciseRef: e.exerciseRef,
          exerciseName: e.exerciseName,
          targetSets: Value(e.targetSets),
          restSeconds: Value(e.restSeconds),
        ),
      );
    }
  }

  // Starting

  /// The workout that is running, or null.
  Future<WorkoutSummary?> runningWorkout() async {
    final row = await _runningRow();
    return row == null ? null : (await _summaries([row])).single;
  }

  /// The running workout, again after any change. "Return to workout".
  Stream<WorkoutSummary?> watchRunningWorkout() =>
      liveQuery(this, [workouts, workoutSets, routines], runningWorkout);

  Future<Workout?> _runningRow() =>
      (select(workouts)
            ..where((w) => w.endedAtMs.isNull())
            ..orderBy([
              (w) => OrderingTerm.desc(w.startedAtMs),
              (w) => OrderingTerm.desc(w.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  /// Starts a workout from a routine: its exercises in order, each with its
  /// target sets, every set stored at once, prefilled from the last time that
  /// exercise was done (empty the first time). If a workout is already running
  /// nothing is started and the result names the running one.
  Future<StartResult> startRoutine(int routineId, Now now) =>
      transaction(() async {
        final r = await getRoutine(routineId);
        if (r == null) throw StateError('No such routine');
        return _begin(now, routineId, [
          for (final e in r.exercises)
            (
              ref: e.exerciseRef,
              name: e.exerciseName,
              sets: e.targetSets ?? defaultSetCount,
            ),
        ]);
      });

  /// Starts a workout that copies a past workout's exercises and number of
  /// sets ("Start again"), with the same routine. Sets are prefilled from the
  /// last time each exercise was done, which may be a later workout than the
  /// one copied. Refused like [startRoutine] while one is running.
  Future<StartResult> startAgain(int workoutId, Now now) =>
      transaction(() async {
        final w = await _workoutRow(workoutId);
        final rows = await _setRows(workoutId);
        final plans = <_Plan>[];
        for (final b in _group(rows)) {
          plans.add((
            ref: b.first.exerciseRef,
            name: b.first.exerciseName,
            sets: b.where((s) => s.completedAtMs != null).length,
          ));
        }
        return _begin(now, w.routineId, [
          for (final p in plans)
            if (p.sets > 0) p,
        ]);
      });

  /// Starts a workout with no exercises. Add them with [addExercise].
  Future<StartResult> startEmptyWorkout(Now now) =>
      transaction(() => _begin(now, null, const []));

  Future<StartResult> _begin(Now now, int? routineId, List<_Plan> plans) async {
    final running = await _runningRow();
    if (running != null) {
      return StartResult.refused((await _summaries([running])).single);
    }
    final id = await into(workouts).insert(
      WorkoutsCompanion.insert(
        localDate: now.localDate,
        startedAtMs: now.utcMs,
        tzOffsetMinutes: now.offsetMinutes,
        routineId: Value(routineId),
      ),
    );
    var position = 0;
    for (final p in plans) {
      final last = _lastTime(await _doneRows(p.ref), id);
      for (var i = 0; i < p.sets; i++) {
        final v = _prefill(last, i);
        await _insertSet(id, position++, p.ref, p.name, v);
      }
    }
    return StartResult.started(await _workoutRow(id));
  }

  /// "Start again" rows: yesterday's workout first, the workout from the same
  /// weekday last week second, then other recent workouts, newest first.
  /// [today] is 'YYYY-MM-DD'. Only finished workouts with at least one
  /// completed set are listed. When a day had two workouts, the later one is
  /// the entry for that day and the other is among the others. At most
  /// [limit] rows.
  Future<List<StartAgainEntry>> startAgainList(
    String today, {
    int limit = 10,
  }) async {
    Future<WorkoutSummary?> latestOn(String day) async {
      final rows =
          await (select(workouts)
                ..where(
                  (w) => w.localDate.equals(day) & w.endedAtMs.isNotNull(),
                )
                ..orderBy([
                  (w) => OrderingTerm.desc(w.startedAtMs),
                  (w) => OrderingTerm.desc(w.id),
                ]))
              .get();
      return (await _summaries(rows)).where((s) => s.setCount > 0).firstOrNull;
    }

    final out = <StartAgainEntry>[];
    final y = await latestOn(addDays(today, -1));
    if (y != null) out.add(StartAgainEntry(StartAgainKind.yesterday, y));
    final w = await latestOn(addDays(today, -7));
    if (w != null) {
      out.add(StartAgainEntry(StartAgainKind.sameWeekdayLastWeek, w));
    }
    final used = {for (final e in out) e.summary.workout.id};
    final recent = await _summaries(await _finishedNewestFirst(60));
    for (final s in recent) {
      if (out.length >= limit) break;
      if (s.setCount == 0 || used.contains(s.workout.id)) continue;
      out.add(StartAgainEntry(StartAgainKind.other, s));
    }
    return out.take(limit).toList();
  }

  Stream<List<StartAgainEntry>> watchStartAgainList(
    String today, {
    int limit = 10,
  }) => liveQuery(this, [
    workouts,
    workoutSets,
    routines,
  ], () => startAgainList(today, limit: limit));

  // Reading a workout

  /// A workout with its exercises and sets, or null if it does not exist.
  Future<WorkoutView?> loadWorkout(int id) async {
    final w = await (select(
      workouts,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (w == null) return null;
    final rows = await _setRows(id);
    final routineId = w.routineId;
    String? routineName;
    final rest = <String, int?>{};
    if (routineId != null) {
      final r = await getRoutine(routineId);
      routineName = r?.routine.name;
      for (final e in r?.exercises ?? const <RoutineExercise>[]) {
        rest[e.exerciseRef] = e.restSeconds;
      }
    }
    final blocks = <ExerciseBlock>[];
    for (final group in _group(rows)) {
      final ref = group.first.exerciseRef;
      final done = await _doneRows(ref);
      final last = _lastTime(done, id);
      final allDone = [for (final d in done) _doneSet(d.set)];
      final sets = <SetView>[];
      for (var i = 0; i < group.length; i++) {
        final s = group[i];
        final prev = i < last.sets.length ? last.sets[i] : null;
        final isDone = s.completedAtMs != null;
        sets.add(
          SetView(
            row: s,
            previous: prev,
            changed:
                !isDone &&
                prev != null &&
                (prev.weightKg != s.weightKg || prev.reps != s.reps),
            record: isDone ? recordFor(_doneSet(s), allDone) : RecordCheck.none,
          ),
        );
      }
      blocks.add(
        ExerciseBlock(
          exerciseRef: ref,
          exerciseName: group.first.exerciseName,
          restSeconds: rest[ref],
          lastTimeDate: last.date,
          lastTime: last.sets,
          sets: sets,
        ),
      );
    }
    return WorkoutView(workout: w, routineName: routineName, exercises: blocks);
  }

  /// The workout again after any change to it, and null once it is deleted.
  Stream<WorkoutView?> watchWorkout(int id) => liveQuery(this, [
    workouts,
    workoutSets,
    routines,
    routineExercises,
  ], () => loadWorkout(id));

  // Changing a running workout

  /// Marks the set completed now, with the weight and reps it shows, in its
  /// own committed write (a closed app or a dead phone loses nothing). The
  /// result says whether it beat the exercise's records. Logging a set that is
  /// already logged changes nothing. Throws [WorkoutRefused] when the workout
  /// is finished ([WorkoutProblem.notRunning]) or the set has no reps
  /// ([WorkoutProblem.needsReps]).
  Future<LoggedSet> logSet(int setId, Now now) => transaction(() async {
    final s = await _openSet(setId);
    var row = s;
    if (s.completedAtMs == null) {
      if (s.reps == null || s.reps! < 1) {
        throw const WorkoutRefused(WorkoutProblem.needsReps);
      }
      await (update(workoutSets)..where((x) => x.id.equals(setId))).write(
        WorkoutSetsCompanion(completedAtMs: Value(now.utcMs)),
      );
      row = await _setById(setId);
    }
    final all = [
      for (final d in await _doneRows(s.exerciseRef)) _doneSet(d.set),
    ];
    return LoggedSet(row, recordFor(_doneSet(row), all));
  });

  /// Sets the weight (kg, null for body weight) and reps of a set, before or
  /// after it is logged. Both values are written as given. Throws
  /// [WorkoutRefused] for a negative or non-finite number or a finished
  /// workout.
  Future<WorkoutSet> adjustSet(
    int setId, {
    required double? weightKg,
    required int? reps,
  }) => transaction(() async {
    if ((weightKg != null && !(weightKg.isFinite && weightKg >= 0)) ||
        (reps != null && reps < 0)) {
      throw const WorkoutRefused(WorkoutProblem.badNumber);
    }
    await _openSet(setId);
    await (update(workoutSets)..where((x) => x.id.equals(setId))).write(
      WorkoutSetsCompanion(weightKg: Value(weightKg), reps: Value(reps)),
    );
    return _setById(setId);
  });

  /// Removes a set from this workout only. An exercise left with no sets
  /// leaves the workout.
  Future<void> removeSet(int setId) => transaction(() async {
    await _openSet(setId);
    await (delete(workoutSets)..where((x) => x.id.equals(setId))).go();
  });

  /// Adds one planned set at the end of an exercise ("+ Add set"). It takes
  /// the next set's numbers from the last time, or copies the exercise's last
  /// set when last time had no such set.
  Future<WorkoutSet> addSet(int workoutId, String exerciseRef) =>
      transaction(() async {
        await _openWorkout(workoutId);
        final rows = await _setRows(workoutId);
        final block = rows.where((s) => s.exerciseRef == exerciseRef).toList();
        if (block.isEmpty) throw StateError('No such exercise');
        final last = _lastTime(await _doneRows(exerciseRef), workoutId);
        final n = block.length;
        final SetValues v = n < last.sets.length
            ? last.sets[n]
            : (weightKg: block.last.weightKg, reps: block.last.reps);
        final id = await _insertSet(
          workoutId,
          0,
          exerciseRef,
          block.first.exerciseName,
          v,
        );
        final order = [for (final s in rows) s.id];
        order.insert(order.indexOf(block.last.id) + 1, id);
        await _renumber(order);
        return _setById(id);
      });

  /// Adds an exercise at the end of the workout, with [sets] planned sets
  /// (default: as many as last time, or 3 the first time), prefilled from the
  /// last time. Throws [WorkoutRefused] if it is already in the workout.
  Future<List<WorkoutSet>> addExercise(
    int workoutId,
    String exerciseRef,
    String exerciseName, {
    int? sets,
  }) => transaction(() async {
    await _openWorkout(workoutId);
    if (sets != null && sets < 1) {
      throw const WorkoutRefused(WorkoutProblem.badNumber);
    }
    final rows = await _setRows(workoutId);
    if (rows.any((s) => s.exerciseRef == exerciseRef)) {
      throw const WorkoutRefused(WorkoutProblem.duplicateExercise);
    }
    final last = _lastTime(await _doneRows(exerciseRef), workoutId);
    final count =
        sets ?? (last.sets.isEmpty ? defaultSetCount : last.sets.length);
    final ids = <int>[];
    for (var i = 0; i < count; i++) {
      ids.add(
        await _insertSet(
          workoutId,
          rows.length + i,
          exerciseRef,
          exerciseName,
          _prefill(last, i),
        ),
      );
    }
    return [for (final id in ids) await _setById(id)];
  });

  /// Removes an exercise with all its sets from this workout.
  Future<void> removeExercise(int workoutId, String exerciseRef) =>
      transaction(() async {
        await _openWorkout(workoutId);
        await (delete(workoutSets)..where(
              (s) =>
                  s.workoutId.equals(workoutId) &
                  s.exerciseRef.equals(exerciseRef),
            ))
            .go();
      });

  /// Moves an exercise one place up ([delta] -1) or down (1). At either end
  /// nothing changes.
  Future<void> moveExercise(int workoutId, String exerciseRef, int delta) =>
      transaction(() async {
        await _openWorkout(workoutId);
        final groups = _group(await _setRows(workoutId));
        final from = groups.indexWhere(
          (g) => g.first.exerciseRef == exerciseRef,
        );
        if (from < 0) throw StateError('No such exercise');
        final to = from + (delta < 0 ? -1 : 1);
        if (to < 0 || to >= groups.length) return;
        groups.insert(to, groups.removeAt(from));
        await _renumber([
          for (final g in groups)
            for (final s in g) s.id,
        ]);
      });

  // Finishing and resuming

  /// Ends the workout now. Planned sets that were not logged are deleted (and
  /// kept aside so [resumeWorkout] can bring them back). The estimated
  /// calories are 3.5 MET x the latest weigh-in on or before the workout's
  /// day x hours (finish minus start). With no weigh-in on or before that
  /// day, or with no completed set, the estimate is null, not zero. The
  /// user's own number, if set, is kept. Finishing a finished workout changes
  /// nothing. Returns the row read back.
  Future<Workout> finishWorkout(int id, Now now) => transaction(() async {
    final w = await _workoutRow(id);
    if (w.endedAtMs != null) return w;
    final rows = await _setRows(id);
    final planned = rows.where((s) => s.completedAtMs == null).toList();
    final done = rows.length - planned.length;
    if (planned.isEmpty) {
      await _setStash(id, null);
    } else {
      await _setStash(
        id,
        jsonEncode([
          for (final s in planned)
            {
              'p': s.position,
              'ref': s.exerciseRef,
              'name': s.exerciseName,
              'w': s.weightKg,
              'r': s.reps,
            },
        ]),
      );
      await (delete(
        workoutSets,
      )..where((s) => s.workoutId.equals(id) & s.completedAtMs.isNull())).go();
    }
    final end = now.utcMs < w.startedAtMs ? w.startedAtMs : now.utcMs;
    double? kcal;
    if (done > 0) {
      final weight = await weightOnOrBefore(w.localDate);
      if (weight != null) {
        kcal = workoutKcal(
          bodyWeightKg: weight.weightKg,
          durationMs: end - w.startedAtMs,
        );
      }
    }
    await (update(workouts)..where((x) => x.id.equals(id))).write(
      WorkoutsCompanion(endedAtMs: Value(end), kcalEstimated: Value(kcal)),
    );
    return _workoutRow(id);
  });

  /// Runs a finished workout again: it has no end time, the planned sets
  /// removed at finish come back where they were, and the estimate is cleared
  /// until the next finish. The user's own calorie number stays. If another
  /// workout is running nothing changes and the result names it. Resuming a
  /// running workout does nothing.
  Future<StartResult> resumeWorkout(int id) => transaction(() async {
    final w = await _workoutRow(id);
    if (w.endedAtMs == null) return StartResult.started(w);
    final running = await _runningRow();
    if (running != null) {
      return StartResult.refused((await _summaries([running])).single);
    }
    for (final s in await _readStash(id)) {
      await into(workoutSets).insert(
        WorkoutSetsCompanion.insert(
          workoutId: id,
          position: s.position,
          exerciseRef: s.ref,
          exerciseName: s.name,
          weightKg: Value(s.weightKg),
          reps: Value(s.reps),
        ),
      );
    }
    await _setStash(id, null);
    await (update(workouts)..where((x) => x.id.equals(id))).write(
      const WorkoutsCompanion(
        endedAtMs: Value(null),
        kcalEstimated: Value(null),
      ),
    );
    return StartResult.started(await _workoutRow(id));
  });

  /// Sets the user's own calorie number for a workout (it wins over the
  /// estimate), or clears it with null. Throws [WorkoutRefused] for a negative
  /// or non-finite number. Works on a running or a finished workout.
  Future<Workout> setWorkoutKcal(int id, double? kcal) async {
    if (kcal != null && !(kcal.isFinite && kcal >= 0)) {
      throw const WorkoutRefused(WorkoutProblem.badNumber);
    }
    final changed = await (update(workouts)..where((w) => w.id.equals(id)))
        .write(WorkoutsCompanion(kcalOverride: Value(kcal)));
    if (changed == 0) throw StateError('No such workout');
    return _workoutRow(id);
  }

  /// What the finish screen shows: time, sets, volume, the records this
  /// workout beat (compared with workouts that started before it) and how
  /// many planned sets were removed.
  Future<WorkoutResult> workoutResult(int id) async {
    final w = await _workoutRow(id);
    final rows = (await _setRows(id)).where((s) => s.completedAtMs != null);
    final byRef = <String, List<WorkoutSet>>{};
    for (final s in rows) {
      (byRef[s.exerciseRef] ??= []).add(s);
    }
    final breaks = <RecordBreak>[];
    for (final e in byRef.entries) {
      final earlier = [
        for (final d in await _doneRows(e.key))
          if (d.workout.id != id &&
              (d.workout.startedAtMs < w.startedAtMs ||
                  (d.workout.startedAtMs == w.startedAtMs &&
                      d.workout.id < w.id)))
            _doneSet(d.set),
      ];
      final before = recordsOf(earlier);
      final now = recordsOf(e.value.map(_doneSet));
      final h = now.heaviest, bh = before.heaviest;
      final est = now.bestEstimate, be = before.bestEstimateKg;
      final heavier = h != null && bh != null && h.weightKg! > bh.weightKg!;
      final better =
          est != null && be != null && est.estimateKg! > be + 1e-9 * be;
      if (!heavier && !better) continue;
      breaks.add(
        RecordBreak(
          exerciseRef: e.key,
          exerciseName: e.value.first.exerciseName,
          heaviest: heavier ? h : null,
          heaviestWasKg: heavier ? bh.weightKg : null,
          estimate: better ? est : null,
          estimateWasKg: better ? be : null,
        ),
      );
    }
    return WorkoutResult(
      workout: w,
      setCount: rows.length,
      volumeKg: totalVolumeKg(rows.map(_doneSet)),
      newRecords: breaks,
      removedPlannedSets: (await _readStash(id)).length,
    );
  }

  // Deleting

  /// Deletes a workout with all its sets and returns what Undo needs. The
  /// schema has no deleted mark on workouts, so the rows are really deleted
  /// and held in the returned object (in memory) for [undoDeleteWorkout]. If
  /// the app is closed before Undo, the workout is gone. Ids are never reused.
  Future<DeletedWorkout> deleteWorkout(int id) => transaction(() async {
    final w = await _workoutRow(id);
    final rows = await _setRows(id);
    final stash = await _stashText(id);
    await (delete(workouts)..where((x) => x.id.equals(id))).go();
    await _setStash(id, null);
    return DeletedWorkout._(w, rows, stash);
  });

  /// Puts back a deleted workout with the same ids and values. If it was
  /// running and another workout runs now, throws [WorkoutRefused]
  /// ([WorkoutProblem.anotherIsRunning]) and puts back nothing. A routine
  /// link to a routine that no longer exists is dropped.
  Future<Workout> undoDeleteWorkout(DeletedWorkout deleted) =>
      transaction(() async {
        final w = deleted.workout;
        if (w.endedAtMs == null && await _runningRow() != null) {
          throw const WorkoutRefused(WorkoutProblem.anotherIsRunning);
        }
        final rid = w.routineId;
        final linked =
            rid != null &&
            await (select(
                  routines,
                )..where((r) => r.id.equals(rid))).getSingleOrNull() !=
                null;
        await into(workouts).insert(
          (linked ? w : w.copyWith(routineId: const Value(null))).toCompanion(
            false,
          ),
        );
        for (final s in deleted.sets) {
          await into(workoutSets).insert(s.toCompanion(false));
        }
        await _setStash(w.id, deleted._stash);
        return _workoutRow(w.id);
      });

  // History, records, volume

  /// Finished workouts, newest first.
  Future<List<WorkoutSummary>> workoutHistory({int limit = 50}) async =>
      _summaries(await _finishedNewestFirst(limit));

  Stream<List<WorkoutSummary>> watchWorkoutHistory({int limit = 50}) =>
      liveQuery(this, [
        workouts,
        workoutSets,
        routines,
      ], () => workoutHistory(limit: limit));

  /// Every session of an exercise that has a completed set, newest first.
  Future<List<ExerciseSession>> exerciseHistory(String exerciseRef) async {
    final done = await _doneRows(exerciseRef);
    final byWorkout = <int, List<_Done>>{};
    for (final d in done) {
      (byWorkout[d.workout.id] ??= []).add(d);
    }
    final sessions = <ExerciseSession>[];
    for (final list in byWorkout.values) {
      list.sort(
        (a, b) => a.set.position != b.set.position
            ? a.set.position.compareTo(b.set.position)
            : a.set.id.compareTo(b.set.id),
      );
      final sets = [for (final d in list) _doneSet(d.set)];
      sessions.add(
        ExerciseSession(
          workout: list.first.workout,
          sets: sets,
          bestEstimate: recordsOf(sets).bestEstimate,
        ),
      );
    }
    sessions.sort(
      (a, b) => a.workout.startedAtMs != b.workout.startedAtMs
          ? b.workout.startedAtMs.compareTo(a.workout.startedAtMs)
          : b.workout.id.compareTo(a.workout.id),
    );
    return sessions;
  }

  Stream<List<ExerciseSession>> watchExerciseHistory(String exerciseRef) =>
      liveQuery(this, [
        workouts,
        workoutSets,
      ], () => exerciseHistory(exerciseRef));

  /// An exercise's records over every completed set. See [recordsOf].
  Future<Records> exerciseRecords(String exerciseRef) async =>
      recordsOf((await _doneRows(exerciseRef)).map((d) => _doneSet(d.set)));

  Stream<Records> watchExerciseRecords(String exerciseRef) =>
      liveQuery(this, [workoutSets], () => exerciseRecords(exerciseRef));

  /// Exercises done lately, most recent first, each once with the name it was
  /// last logged under: the picker's list before anything is typed.
  Future<List<({String exerciseRef, String exerciseName})>> recentExercises({
    int limit = 10,
  }) async {
    final rows =
        await (select(workoutSets)
              ..where((s) => s.completedAtMs.isNotNull())
              ..orderBy([
                (s) => OrderingTerm.desc(s.completedAtMs),
                (s) => OrderingTerm.desc(s.id),
              ])
              ..limit(1000))
            .get();
    final seen = <String>{};
    return [
      for (final s in rows)
        if (seen.add(s.exerciseRef))
          (exerciseRef: s.exerciseRef, exerciseName: s.exerciseName),
    ].take(limit).toList();
  }

  /// Completed sets per primary muscle in the Monday to Sunday week that
  /// contains [dayInWeek] ('YYYY-MM-DD'). Sets count on their workout's
  /// start day, from running and finished workouts. [musclesOf] gives each
  /// exercise's primary muscles. See [setsPerMuscle].
  Future<Map<String, int>> weeklyVolume(
    String dayInWeek,
    MusclesOf musclesOf,
  ) async {
    final monday = mondayOf(dayInWeek);
    final q =
        select(workoutSets).join([
          innerJoin(workouts, workouts.id.equalsExp(workoutSets.workoutId)),
        ])..where(
          workoutSets.completedAtMs.isNotNull() &
              workouts.localDate.isBiggerOrEqualValue(monday) &
              workouts.localDate.isSmallerOrEqualValue(addDays(monday, 6)),
        );
    final cache = <String, List<String>>{};
    final sets = <VolumeSet>[];
    for (final r in await q.get()) {
      final ref = r.readTable(workoutSets).exerciseRef;
      sets.add((
        localDate: r.readTable(workouts).localDate,
        muscles: cache[ref] ??= musclesOf(ref).toList(),
      ));
    }
    return setsPerMuscle(sets, dayInWeek);
  }

  Stream<Map<String, int>> watchWeeklyVolume(
    String dayInWeek,
    MusclesOf musclesOf,
  ) => liveQuery(this, [
    workouts,
    workoutSets,
  ], () => weeklyVolume(dayInWeek, musclesOf));

  // Helpers

  DoneSet _doneSet(WorkoutSet s) => DoneSet(
    weightKg: s.weightKg,
    reps: s.reps,
    atMs: s.completedAtMs ?? 0,
    id: s.id,
  );

  Future<Workout> _workoutRow(int id) async {
    final w = await (select(
      workouts,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (w == null) throw StateError('No such workout');
    return w;
  }

  Future<Workout> _openWorkout(int id) async {
    final w = await _workoutRow(id);
    if (w.endedAtMs != null) {
      throw const WorkoutRefused(WorkoutProblem.notRunning);
    }
    return w;
  }

  Future<WorkoutSet> _setById(int id) async {
    final s = await (select(
      workoutSets,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (s == null) throw StateError('No such set');
    return s;
  }

  Future<WorkoutSet> _openSet(int setId) async {
    final s = await _setById(setId);
    await _openWorkout(s.workoutId);
    return s;
  }

  Future<List<WorkoutSet>> _setRows(int workoutId) =>
      (select(workoutSets)
            ..where((s) => s.workoutId.equals(workoutId))
            ..orderBy([
              (s) => OrderingTerm.asc(s.position),
              (s) => OrderingTerm.asc(s.id),
            ]))
          .get();

  /// Sets grouped by exercise, exercises in order of first appearance.
  List<List<WorkoutSet>> _group(List<WorkoutSet> rows) {
    final groups = <String, List<WorkoutSet>>{};
    for (final s in rows) {
      (groups[s.exerciseRef] ??= []).add(s);
    }
    return groups.values.toList();
  }

  Future<int> _insertSet(
    int workoutId,
    int position,
    String ref,
    String name,
    SetValues v,
  ) => into(workoutSets).insert(
    WorkoutSetsCompanion.insert(
      workoutId: workoutId,
      position: position,
      exerciseRef: ref,
      exerciseName: name,
      weightKg: Value(v.weightKg),
      reps: Value(v.reps),
    ),
  );

  Future<void> _renumber(List<int> idsInOrder) async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await (update(workoutSets)..where((s) => s.id.equals(idsInOrder[i])))
          .write(WorkoutSetsCompanion(position: Value(i)));
    }
  }

  /// Every completed set of an exercise with its workout, oldest first.
  Future<List<_Done>> _doneRows(String ref) async {
    final q =
        select(workoutSets).join([
            innerJoin(workouts, workouts.id.equalsExp(workoutSets.workoutId)),
          ])
          ..where(
            workoutSets.exerciseRef.equals(ref) &
                workoutSets.completedAtMs.isNotNull(),
          )
          ..orderBy([
            OrderingTerm.asc(workoutSets.completedAtMs),
            OrderingTerm.asc(workoutSets.id),
          ]);
    return [
      for (final r in await q.get())
        (set: r.readTable(workoutSets), workout: r.readTable(workouts)),
    ];
  }

  /// The last time an exercise was done in a workout other than
  /// [exceptWorkoutId]: the latest started workout with a completed set of it.
  ({String? date, List<SetValues> sets}) _lastTime(
    List<_Done> done,
    int exceptWorkoutId,
  ) {
    Workout? best;
    for (final d in done) {
      final w = d.workout;
      if (w.id == exceptWorkoutId) continue;
      if (best == null ||
          w.startedAtMs > best.startedAtMs ||
          (w.startedAtMs == best.startedAtMs && w.id > best.id)) {
        best = w;
      }
    }
    if (best == null) return (date: null, sets: const []);
    final mine =
        [
          for (final d in done)
            if (d.workout.id == best.id) d.set,
        ]..sort(
          (a, b) => a.position != b.position
              ? a.position.compareTo(b.position)
              : a.id.compareTo(b.id),
        );
    return (
      date: best.localDate,
      sets: [for (final s in mine) (weightKg: s.weightKg, reps: s.reps)],
    );
  }

  /// Set [i] of a new workout: last time's set [i], or last time's last set
  /// when last time had fewer, or empty the first time.
  SetValues _prefill(({String? date, List<SetValues> sets}) last, int i) {
    if (last.sets.isEmpty) return (weightKg: null, reps: null);
    return i < last.sets.length ? last.sets[i] : last.sets.last;
  }

  Future<List<Workout>> _finishedNewestFirst(int limit) =>
      (select(workouts)
            ..where((w) => w.endedAtMs.isNotNull())
            ..orderBy([
              (w) => OrderingTerm.desc(w.localDate),
              (w) => OrderingTerm.desc(w.startedAtMs),
              (w) => OrderingTerm.desc(w.id),
            ])
            ..limit(limit))
          .get();

  Future<List<WorkoutSummary>> _summaries(List<Workout> rows) async {
    if (rows.isEmpty) return [];
    final sets =
        await (select(workoutSets)
              ..where((s) => s.workoutId.isIn([for (final w in rows) w.id]))
              ..orderBy([
                (s) => OrderingTerm.asc(s.position),
                (s) => OrderingTerm.asc(s.id),
              ]))
            .get();
    final routineIds = {
      for (final w in rows)
        if (w.routineId != null) w.routineId!,
    };
    final names = routineIds.isEmpty
        ? <int, String>{}
        : {
            for (final r in await (select(
              routines,
            )..where((r) => r.id.isIn(routineIds))).get())
              r.id: r.name,
          };
    return [
      for (final w in rows)
        () {
          final mine = sets.where((s) => s.workoutId == w.id).toList();
          final done = mine.where((s) => s.completedAtMs != null).length;
          return WorkoutSummary(
            workout: w,
            routineName: names[w.routineId],
            exerciseNames: [for (final g in _group(mine)) g.first.exerciseName],
            setCount: done,
            plannedSetCount: mine.length - done,
          );
        }(),
    ];
  }

  // Planned sets removed at finish are kept in the settings table, because
  // the schema has no place on a workout for them. One key per workout holds a
  // JSON list, so Resume works after the app was closed.

  static String _stashKey(int workoutId) => 'workout_unlogged_sets:$workoutId';

  Future<String?> _stashText(int workoutId) async =>
      (await (select(settings)
                ..where((s) => s.key.equals(_stashKey(workoutId))))
              .getSingleOrNull())
          ?.value;

  Future<void> _setStash(int workoutId, String? text) async {
    if (text == null) {
      await (delete(
        settings,
      )..where((s) => s.key.equals(_stashKey(workoutId)))).go();
    } else {
      await into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: _stashKey(workoutId), value: text),
      );
    }
  }

  Future<
    List<({int position, String ref, String name, double? weightKg, int? reps})>
  >
  _readStash(int workoutId) async {
    final text = await _stashText(workoutId);
    if (text == null) return const [];
    try {
      return [
        for (final m in jsonDecode(text) as List)
          (
            position: (m['p'] as num).toInt(),
            ref: m['ref'] as String,
            name: m['name'] as String,
            weightKg: (m['w'] as num?)?.toDouble(),
            reps: (m['r'] as num?)?.toInt(),
          ),
      ];
    } on Object {
      return const [];
    }
  }
}
