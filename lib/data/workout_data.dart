// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

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
//   endedAtMs is the moment Finish was tapped. It is not the workout's
//   length: the length is the start to the last logged set (see below).
// - Every planned set is a workout_sets row with completedAtMs null from the
//   moment the workout starts. Logging sets completedAtMs, in its own write.
// - A FINISHED workout may still hold rows with completedAtMs null. They are
//   the planned sets that were never logged. Finish leaves them in place and
//   Resume only clears endedAtMs (and the estimate), so they are the sets
//   that "come back". For a finished workout every reader here ignores them:
//   the history holds only work that was done. For a running workout they are
//   the sets still to do. Only a running workout can be edited.
// - workout_sets.position orders the whole workout. The sets of one exercise
//   are next to each other and exercises appear in order of first position.
//   Positions may have gaps after removals; only their order counts.
// - A workout has no name column. Its name is its routine's name; with no
//   routine (an empty workout) the screen names it by its exercises.
// - Rest time is not stored on a workout. It is read from the workout's
//   routine for that exercise, and is null for an exercise added mid-workout.
// - Length and calories: a workout's length is its start to the completion
//   time of its LAST LOGGED SET, so a workout left open overnight is not
//   counted as hours it was not worked. With no logged set there is no length
//   and no estimate. After a Resume, the length still runs from the original
//   start to the newest last set, so a workout resumed days later is days
//   long. The schema cannot say how long it was really worked.
// - Records: a set is a record only when a workout that started before its
//   own (then by id) holds a qualifying set that it beats. Sets of the same
//   workout never count against each other, and the first time an exercise
//   is ever done nothing is a record. The flags are worked out when read, so
//   they follow the data as it is now.

/// Why a write was refused. Carries no user data.
enum WorkoutProblem {
  /// Another workout is running (resume, or undoing a delete).
  anotherIsRunning,

  /// The workout is finished, so its sets cannot change. Resume it first.
  notRunning,

  /// The set has no reps yet, so it cannot be logged, and a logged set cannot
  /// lose its reps.
  needsReps,

  /// A weight, reps, rest, set count or calorie number that is negative, not
  /// a number, or (for a set count) zero.
  badNumber,

  /// A routine with no name.
  blankName,

  /// The same exercise twice in one routine or one workout.
  duplicateExercise,

  /// Replace exercise, but a set of the old exercise is already logged. The
  /// user adds an exercise instead.
  loggedSetsInExercise,
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

/// A workout for lists: Start again and Return to workout.
class WorkoutSummary {
  const WorkoutSummary({
    required this.workout,
    required this.routineName,
    required this.exerciseNames,
    required this.setCount,
    required this.plannedSetCount,
    required this.lastSetAtMs,
  });

  final Workout workout;

  /// The routine's name, or null (empty workout, or the routine is gone).
  /// Then the screen names the workout by [exerciseNames].
  final String? routineName;

  /// Each exercise once, in order. For a finished workout only exercises with
  /// a completed set.
  final List<String> exerciseNames;

  /// Completed sets.
  final int setCount;

  /// Sets still planned (not logged). Always 0 for a finished workout.
  final int plannedSetCount;

  /// When the last logged set was completed, or null if none was.
  final int? lastSetAtMs;

  int get exerciseCount => exerciseNames.length;
  bool get isRunning => workout.endedAtMs == null;

  /// The workout's length in milliseconds: start to the last logged set. Null
  /// while running and when no set was logged.
  int? get durationMs =>
      isRunning ? null : workoutLength(workout.startedAtMs, lastSetAtMs);
}

/// Start to last logged set, never negative, or null with no logged set.
int? workoutLength(int startedAtMs, int? lastSetAtMs) {
  if (lastSetAtMs == null) return null;
  final d = lastSetAtMs - startedAtMs;
  return d < 0 ? 0 : d;
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

  /// For a logged set: whether it beat every set of earlier workouts.
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

  /// In order. For a finished workout only the logged sets.
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
/// no earlier set to beat in that kind of record). The sets carry their
/// workout's day in [DoneSet.localDate].
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
    required this.durationMs,
  });

  /// Read back, with the estimated and own calories.
  final Workout workout;
  final int setCount;

  /// Weight x reps over the completed sets, in kg.
  final double volumeKg;
  final List<RecordBreak> newRecords;

  /// Sets planned but not logged when the workout was finished (they are
  /// hidden now and Resume brings them back). 0 for a running workout.
  final int removedPlannedSets;

  /// Start to the last logged set, or null with no logged set.
  final int? durationMs;
}

/// One past session of an exercise, for exercise detail.
class ExerciseSession {
  const ExerciseSession({
    required this.workoutId,
    required this.localDate,
    required this.startedAtMs,
    required this.sets,
    required this.bestEstimate,
  });

  final int workoutId;

  /// The day the workout started: show this, never a day worked out from a
  /// timestamp.
  final String localDate;
  final int startedAtMs;

  /// Completed sets, in order, each with [DoneSet.localDate].
  final List<DoneSet> sets;

  /// The set with the best estimate this session ("228 lb best 180 x 8"), or
  /// null when no set counts.
  final DoneSet? bestEstimate;
}

/// A workout removed by [WorkoutData.deleteWorkout], kept so Undo can put
/// back exactly the same rows. It lives in memory only.
class DeletedWorkout {
  const DeletedWorkout._(this.workout, this.sets);

  final Workout workout;
  final List<WorkoutSet> sets;
}

typedef _Plan = ({String ref, String name, int sets});
typedef _LastTime = ({String? date, List<SetValues> sets});
typedef _DoneRow = ({
  DoneSet set,
  int workoutId,
  int startedAtMs,
  int position,
});

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
  /// sets ("Start again"), with the same routine. Only sets that were logged
  /// are copied. Sets are prefilled from the last time each exercise was
  /// done, which may be a later workout than the one copied. Refused like
  /// [startRoutine] while one is running.
  Future<StartResult> startAgain(int workoutId, Now now) =>
      transaction(() async {
        final w = await _workoutRow(workoutId);
        final rows = (await _setRows(workoutId))
            .where((s) => s.completedAtMs != null)
            .toList();
        return _begin(now, w.routineId, [
          for (final g in _group(rows))
            (
              ref: g.first.exerciseRef,
              name: g.first.exerciseName,
              sets: g.length,
            ),
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
      final last = await _lastTime(p.ref, id);
      for (var i = 0; i < p.sets; i++) {
        await _insertSet(id, position++, p.ref, p.name, _prefill(last, i));
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
    final recent = await _summaries(await _finishedNewestFirst(limit + 20));
    for (final s in recent) {
      if (out.length >= limit) break;
      if (s.setCount == 0 || used.contains(s.workout.id)) continue;
      out.add(StartAgainEntry(StartAgainKind.other, s));
    }
    return out.take(limit).toList();
  }

  /// [startAgainList] again after any change. It is worked out for the [today]
  /// given: the caller must subscribe again after midnight, with the new day.
  Stream<List<StartAgainEntry>> watchStartAgainList(
    String today, {
    int limit = 10,
  }) => liveQuery(this, [
    workouts,
    workoutSets,
    routines,
  ], () => startAgainList(today, limit: limit));

  // Reading a workout

  /// A workout with its exercises and sets, or null if it does not exist. A
  /// finished workout shows only its logged sets.
  Future<WorkoutView?> loadWorkout(int id) async {
    final w = await (select(
      workouts,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    if (w == null) return null;
    final rows = (await _setRows(id)).where((s) => _visible(w, s)).toList();
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
      final last = await _lastTime(ref, id);
      final before = await _bestsBefore(ref, w);
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
            record: isDone
                ? checkRecord(before, _doneSet(s, w.localDate))
                : RecordCheck.none,
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
    final s = await _setById(setId);
    final w = await _openWorkout(s.workoutId);
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
    final before = await _bestsBefore(s.exerciseRef, w);
    return LoggedSet(row, checkRecord(before, _doneSet(row, w.localDate)));
  });

  /// Sets the weight (kg, null for body weight) and reps of a set, before or
  /// after it is logged. Both values are written as given. Throws
  /// [WorkoutRefused] for a negative or non-finite number or a finished
  /// workout, and with [WorkoutProblem.needsReps] when the set is logged and
  /// reps would be missing or below 1.
  Future<WorkoutSet> adjustSet(
    int setId, {
    required double? weightKg,
    required int? reps,
  }) => transaction(() async {
    if ((weightKg != null && !(weightKg.isFinite && weightKg >= 0)) ||
        (reps != null && reps < 0)) {
      throw const WorkoutRefused(WorkoutProblem.badNumber);
    }
    final s = await _setById(setId);
    await _openWorkout(s.workoutId);
    if (s.completedAtMs != null && (reps == null || reps < 1)) {
      throw const WorkoutRefused(WorkoutProblem.needsReps);
    }
    await (update(workoutSets)..where((x) => x.id.equals(setId))).write(
      WorkoutSetsCompanion(weightKg: Value(weightKg), reps: Value(reps)),
    );
    return _setById(setId);
  });

  /// Removes a set from this workout only. An exercise left with no sets
  /// leaves the workout.
  Future<void> removeSet(int setId) => transaction(() async {
    final s = await _setById(setId);
    await _openWorkout(s.workoutId);
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
        final last = await _lastTime(exerciseRef, workoutId);
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
    final last = await _lastTime(exerciseRef, workoutId);
    final count =
        sets ?? (last.sets.isEmpty ? defaultSetCount : last.sets.length);
    // After the highest position: removals leave gaps, so the row count is
    // not a free position.
    final first = rows.isEmpty ? 0 : rows.last.position + 1;
    final ids = <int>[];
    for (var i = 0; i < count; i++) {
      ids.add(
        await _insertSet(
          workoutId,
          first + i,
          exerciseRef,
          exerciseName,
          _prefill(last, i),
        ),
      );
    }
    return [for (final id in ids) await _setById(id)];
  });

  /// Replaces an exercise with another, in the same place in the order and
  /// with the same number of sets, prefilled from the new exercise's own last
  /// time. One transaction. Throws [WorkoutRefused] when the workout is not
  /// running, when any set of the old exercise is already logged
  /// ([WorkoutProblem.loggedSetsInExercise]: the user adds an exercise
  /// instead), or when the new exercise is already in the workout.
  Future<List<WorkoutSet>> replaceExercise(
    int workoutId,
    String oldRef,
    String newRef,
    String newName,
  ) => transaction(() async {
    await _openWorkout(workoutId);
    final rows = await _setRows(workoutId);
    final old = rows.where((s) => s.exerciseRef == oldRef).toList();
    if (old.isEmpty) throw StateError('No such exercise');
    if (old.any((s) => s.completedAtMs != null)) {
      throw const WorkoutRefused(WorkoutProblem.loggedSetsInExercise);
    }
    if (rows.any((s) => s.exerciseRef == newRef)) {
      throw const WorkoutRefused(WorkoutProblem.duplicateExercise);
    }
    final last = await _lastTime(newRef, workoutId);
    for (var i = 0; i < old.length; i++) {
      final v = _prefill(last, i);
      await (update(workoutSets)..where((x) => x.id.equals(old[i].id))).write(
        WorkoutSetsCompanion(
          exerciseRef: Value(newRef),
          exerciseName: Value(newName),
          weightKg: Value(v.weightKg),
          reps: Value(v.reps),
        ),
      );
    }
    return [for (final s in old) await _setById(s.id)];
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

  /// Ends the workout now. Planned sets that were not logged stay in place and
  /// are hidden (see the header). The estimated calories are 3.5 MET x the
  /// latest weigh-in on or before the workout's day x hours, where hours run
  /// from the start to the last logged set, not to now. With no weigh-in on
  /// or before that day, or with no logged set, the estimate is null, not
  /// zero. The user's own number, if set, is kept. endedAtMs is when Finish
  /// was tapped. Finishing a finished workout changes nothing. Returns the row
  /// read back.
  Future<Workout> finishWorkout(int id, Now now) => transaction(() async {
    final w = await _workoutRow(id);
    if (w.endedAtMs != null) return w;
    final lastSet = await _lastSetAt(id);
    final end = now.utcMs < w.startedAtMs ? w.startedAtMs : now.utcMs;
    double? kcal;
    final length = workoutLength(w.startedAtMs, lastSet);
    if (length != null) {
      final weight = await weightOnOrBefore(w.localDate);
      if (weight != null) {
        kcal = workoutKcal(bodyWeightKg: weight.weightKg, durationMs: length);
      }
    }
    await (update(workouts)..where((x) => x.id.equals(id))).write(
      WorkoutsCompanion(endedAtMs: Value(end), kcalEstimated: Value(kcal)),
    );
    return _workoutRow(id);
  });

  /// Runs a finished workout again: it has no end time, its unlogged planned
  /// sets are sets to do again, and the estimate is cleared until the next
  /// finish. The user's own calorie number stays. If another workout is
  /// running nothing changes and the result names it. Resuming a running
  /// workout does nothing.
  Future<StartResult> resumeWorkout(int id) => transaction(() async {
    final w = await _workoutRow(id);
    if (w.endedAtMs == null) return StartResult.started(w);
    final running = await _runningRow();
    if (running != null) {
      return StartResult.refused((await _summaries([running])).single);
    }
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

  /// What the finish screen shows: length, sets, volume, the records this
  /// workout beat (against workouts that started before it, the same rule as
  /// the flag on each set) and how many planned sets were not logged.
  Future<WorkoutResult> workoutResult(int id) async {
    final w = await _workoutRow(id);
    final all = await _setRows(id);
    final rows = all.where((s) => s.completedAtMs != null).toList();
    final breaks = <RecordBreak>[];
    for (final g in _group(rows)) {
      final ref = g.first.exerciseRef;
      final before = await _bestsBefore(ref, w);
      final mine = recordsOf(g.map((s) => _doneSet(s, w.localDate)));
      final h = mine.heaviest, est = mine.bestEstimate;
      final bh = recordsOf(before).heaviest;
      final be = recordsOf(before).bestEstimateKg;
      final heavier = h != null && checkRecord(before, h).heaviest;
      final better = est != null && checkRecord(before, est).estimate;
      if (!heavier && !better) continue;
      breaks.add(
        RecordBreak(
          exerciseRef: ref,
          exerciseName: g.first.exerciseName,
          heaviest: heavier ? h : null,
          heaviestWasKg: heavier ? bh?.weightKg : null,
          estimate: better ? est : null,
          estimateWasKg: better ? be : null,
        ),
      );
    }
    return WorkoutResult(
      workout: w,
      setCount: rows.length,
      volumeKg: totalVolumeKg(rows.map((s) => _doneSet(s, w.localDate))),
      newRecords: breaks,
      removedPlannedSets: w.endedAtMs == null ? 0 : all.length - rows.length,
      durationMs: w.endedAtMs == null
          ? null
          : workoutLength(
              w.startedAtMs,
              rows.isEmpty
                  ? null
                  : rows
                        .map((s) => s.completedAtMs!)
                        .reduce((a, b) => a > b ? a : b),
            ),
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
    await (delete(workouts)..where((x) => x.id.equals(id))).go();
    return DeletedWorkout._(w, rows);
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
        return _workoutRow(w.id);
      });

  // Records, history, volume

  /// Every session of an exercise that has a completed set, newest first.
  Future<List<ExerciseSession>> exerciseHistory(String exerciseRef) async {
    final byWorkout = <int, List<_DoneRow>>{};
    for (final d in await _doneRows(exerciseRef)) {
      (byWorkout[d.workoutId] ??= []).add(d);
    }
    final sessions = <ExerciseSession>[];
    for (final list in byWorkout.values) {
      list.sort(
        (a, b) => a.position != b.position
            ? a.position.compareTo(b.position)
            : a.set.id.compareTo(b.set.id),
      );
      final sets = [for (final d in list) d.set];
      sessions.add(
        ExerciseSession(
          workoutId: list.first.workoutId,
          localDate: sets.first.localDate,
          startedAtMs: list.first.startedAtMs,
          sets: sets,
          bestEstimate: recordsOf(sets).bestEstimate,
        ),
      );
    }
    sessions.sort(
      (a, b) => a.startedAtMs != b.startedAtMs
          ? b.startedAtMs.compareTo(a.startedAtMs)
          : b.workoutId.compareTo(a.workoutId),
    );
    return sessions;
  }

  Stream<List<ExerciseSession>> watchExerciseHistory(String exerciseRef) =>
      liveQuery(this, [
        workouts,
        workoutSets,
      ], () => exerciseHistory(exerciseRef));

  /// An exercise's records over every completed set, each with the set it came
  /// from and that workout's day ([DoneSet.localDate]). See [recordsOf].
  Future<Records> exerciseRecords(String exerciseRef) async =>
      recordsOf((await _doneRows(exerciseRef)).map((d) => d.set));

  Stream<Records> watchExerciseRecords(String exerciseRef) => liveQuery(this, [
    workouts,
    workoutSets,
  ], () => exerciseRecords(exerciseRef));

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
  /// contains [dayInWeek]. Sets count on their workout's start day, from
  /// running and finished workouts. [musclesOf] gives each exercise's primary
  /// muscles. See [setsPerMuscle].
  Future<Map<String, int>> weeklyVolume(
    String dayInWeek,
    MusclesOf musclesOf,
  ) async {
    final monday = mondayOf(dayInWeek);
    final count = workoutSets.id.count();
    final q = selectOnly(
      workoutSets,
    ).join([innerJoin(workouts, workouts.id.equalsExp(workoutSets.workoutId))]);
    q
      ..addColumns([workoutSets.exerciseRef, workouts.localDate, count])
      ..where(
        workoutSets.completedAtMs.isNotNull() &
            workouts.localDate.isBiggerOrEqualValue(monday) &
            workouts.localDate.isSmallerOrEqualValue(addDays(monday, 6)),
      )
      ..groupBy([workoutSets.exerciseRef, workouts.localDate]);
    final cache = <String, List<String>>{};
    final sets = <VolumeSet>[];
    for (final r in await q.get()) {
      final ref = r.read(workoutSets.exerciseRef)!;
      final muscles = cache[ref] ??= musclesOf(ref).toList();
      for (var i = 0; i < r.read(count)!; i++) {
        sets.add((localDate: r.read(workouts.localDate)!, muscles: muscles));
      }
    }
    return setsPerMuscle(sets, dayInWeek);
  }

  /// [weeklyVolume] again after any change to workouts or to the user's
  /// exercises (their muscles can be edited).
  Stream<Map<String, int>> watchWeeklyVolume(
    String dayInWeek,
    MusclesOf musclesOf,
  ) => liveQuery(this, [
    workouts,
    workoutSets,
    exercises,
  ], () => weeklyVolume(dayInWeek, musclesOf));

  // Helpers

  /// A finished workout shows only logged sets.
  bool _visible(Workout w, WorkoutSet s) =>
      w.endedAtMs == null || s.completedAtMs != null;

  DoneSet _doneSet(WorkoutSet s, String localDate) => DoneSet(
    weightKg: s.weightKg,
    reps: s.reps,
    atMs: s.completedAtMs ?? 0,
    id: s.id,
    localDate: localDate,
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

  Future<List<WorkoutSet>> _setRows(int workoutId) =>
      (select(workoutSets)
            ..where((s) => s.workoutId.equals(workoutId))
            ..orderBy([
              (s) => OrderingTerm.asc(s.position),
              (s) => OrderingTerm.asc(s.id),
            ]))
          .get();

  Future<int?> _lastSetAt(int workoutId) async {
    final latest = workoutSets.completedAtMs.max();
    final row =
        await (selectOnly(workoutSets)
              ..addColumns([latest])
              ..where(
                workoutSets.workoutId.equals(workoutId) &
                    workoutSets.completedAtMs.isNotNull(),
              ))
            .getSingle();
    return row.read(latest);
  }

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

  /// The completed sets of an exercise in every workout, with only the columns
  /// needed. Used by exercise detail, not by the active workout.
  Future<List<_DoneRow>> _doneRows(String ref) async {
    final q = selectOnly(
      workoutSets,
    ).join([innerJoin(workouts, workouts.id.equalsExp(workoutSets.workoutId))]);
    q
      ..addColumns([
        workoutSets.id,
        workoutSets.weightKg,
        workoutSets.reps,
        workoutSets.completedAtMs,
        workoutSets.position,
        workouts.id,
        workouts.localDate,
        workouts.startedAtMs,
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
        (
          set: DoneSet(
            weightKg: r.read(workoutSets.weightKg),
            reps: r.read(workoutSets.reps),
            atMs: r.read(workoutSets.completedAtMs)!,
            id: r.read(workoutSets.id)!,
            localDate: r.read(workouts.localDate)!,
          ),
          workoutId: r.read(workouts.id)!,
          startedAtMs: r.read(workouts.startedAtMs)!,
          position: r.read(workoutSets.position)!,
        ),
    ];
  }

  /// What every workout that started before [w] (then by id) holds for an
  /// exercise, as the best weight for each rep count: at most one small row
  /// per distinct rep count, whatever the history. Enough for both records.
  Future<List<DoneSet>> _bestsBefore(String ref, Workout w) async {
    final best = workoutSets.weightKg.max();
    final q = selectOnly(
      workoutSets,
    ).join([innerJoin(workouts, workouts.id.equalsExp(workoutSets.workoutId))]);
    q
      ..addColumns([workoutSets.reps, best])
      ..where(
        workoutSets.exerciseRef.equals(ref) &
            workoutSets.completedAtMs.isNotNull() &
            workoutSets.weightKg.isBiggerThanValue(0) &
            workoutSets.reps.isBiggerOrEqualValue(1) &
            (workouts.startedAtMs.isSmallerThanValue(w.startedAtMs) |
                (workouts.startedAtMs.equals(w.startedAtMs) &
                    workouts.id.isSmallerThanValue(w.id))),
      )
      ..groupBy([workoutSets.reps]);
    return [
      for (final r in await q.get())
        DoneSet(
          weightKg: r.read(best),
          reps: r.read(workoutSets.reps),
          atMs: 0,
        ),
    ];
  }

  /// The last time an exercise was done in a workout other than
  /// [exceptWorkoutId]: the latest started workout with a completed set of
  /// it, and only that workout's sets are read.
  Future<_LastTime> _lastTime(String ref, int exceptWorkoutId) async {
    final q = selectOnly(
      workoutSets,
    ).join([innerJoin(workouts, workouts.id.equalsExp(workoutSets.workoutId))]);
    q
      ..addColumns([workouts.id, workouts.localDate])
      ..where(
        workoutSets.exerciseRef.equals(ref) &
            workoutSets.completedAtMs.isNotNull() &
            workouts.id.equals(exceptWorkoutId).not(),
      )
      ..orderBy([
        OrderingTerm.desc(workouts.startedAtMs),
        OrderingTerm.desc(workouts.id),
      ])
      ..limit(1);
    final top = (await q.get()).firstOrNull;
    if (top == null) return (date: null, sets: const <SetValues>[]);
    final sets =
        await (select(workoutSets)
              ..where(
                (s) =>
                    s.workoutId.equals(top.read(workouts.id)!) &
                    s.exerciseRef.equals(ref) &
                    s.completedAtMs.isNotNull(),
              )
              ..orderBy([
                (s) => OrderingTerm.asc(s.position),
                (s) => OrderingTerm.asc(s.id),
              ]))
            .get();
    return (
      date: top.read(workouts.localDate),
      sets: [for (final s in sets) (weightKg: s.weightKg, reps: s.reps)],
    );
  }

  /// Set [i] of a new workout: last time's set [i], or last time's last set
  /// when last time had fewer, or empty the first time.
  SetValues _prefill(_LastTime last, int i) {
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
          final mine = sets
              .where((s) => s.workoutId == w.id && _visible(w, s))
              .toList();
          final done = mine.where((s) => s.completedAtMs != null).toList();
          return WorkoutSummary(
            workout: w,
            routineName: names[w.routineId],
            exerciseNames: [for (final g in _group(mine)) g.first.exerciseName],
            setCount: done.length,
            plannedSetCount: mine.length - done.length,
            lastSetAtMs: done.isEmpty
                ? null
                : done
                      .map((s) => s.completedAtMs!)
                      .reduce((a, b) => a > b ? a : b),
          );
        }(),
    ];
  }
}
