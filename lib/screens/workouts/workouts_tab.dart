// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../clock.dart';
import '../../data/database.dart';
import '../../data/exercise_library.dart';
import '../../data/settings_data.dart';
import '../../data/workout_data.dart';
import '../../strings.dart';
import '../../util/units.dart';
import '../food/confirm_bar.dart';
import 'exercise_picker.dart' show openExerciseList;
import 'routine_editor.dart';
import 'weekly_volume_screen.dart';
import 'workout_screen.dart';
import 'workout_widgets.dart';

/// The Workouts tab (workout.html frame 1): "Start again" in the data layer's
/// order, the routines, an empty workout, and this week's sets by muscle.
/// While a workout is running, "Return to workout" is on top.
///
/// Like Home, each stream is read by one builder that stays above the list and
/// hands plain values down; the cards below never listen.
class WorkoutsTab extends StatefulWidget {
  const WorkoutsTab({super.key, required this.today, required this.selected});

  /// Today's date from the clock. The shell computes it on every redraw.
  final String today;

  /// Whether this is the tab on screen. Choosing the tab from another one
  /// brings its list back to the top.
  final bool selected;

  @override
  State<WorkoutsTab> createState() => _WorkoutsTabState();
}

/// A message above the tab bar, with "Return to workout" when it offers it.
class _Msg {
  const _Msg(this.text, {this.returnId, this.undo});

  final String text;
  final int? returnId;

  /// Brings back a deleted routine.
  final Future<void> Function()? undo;
}

class _WorkoutsTabState extends State<WorkoutsTab> {
  static const _noteTime = Duration(seconds: 10);

  Stream<UnitSystem>? _units;
  Stream<WorkoutSummary?>? _running;
  Stream<List<RoutineWithExercises>>? _routines;
  Stream<List<StartAgainEntry>>? _startAgain;
  Stream<Map<String, int>>? _volume;
  String? _dayFor;

  // The weekly volume needs the exercise library, which is loaded after the
  // first frame and never waited for by a start.
  MusclesOf? _musclesOf;
  StreamSubscription<List<LibraryExercise>>? _userSub;
  var _libraryFailed = false;

  _Msg? _msg;
  Timer? _msgTimer;
  var _starting = false;

  // The tab is kept alive, so it keeps its scroll position. Speed target 4
  // needs "Start again" in view, so the list goes back to the top when the
  // tab is chosen and when a workout opened from it has closed.
  final _scroll = ScrollController();

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.of(context).db;
    if (_units == null) {
      _units = db.watchUnits();
      _running = db.watchRunningWorkout();
      _routines = db.watchRoutines();
      _loadLibrary(db);
    }
    if (_dayFor != widget.today) {
      _dayFor = widget.today;
      _followDay(db);
    }
  }

  @override
  void didUpdateWidget(WorkoutsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) _toTop();
    // A new day (the shell moved past midnight): "Start again" and the week
    // are worked out for it, with new streams.
    if (_dayFor != widget.today) {
      _dayFor = widget.today;
      _followDay(AppScope.of(context).db);
    }
  }

  void _followDay(AppDatabase db) {
    _startAgain = db.watchStartAgainList(widget.today);
    final groups = _musclesOf;
    _volume = groups == null
        ? null
        : db.watchWeeklyVolume(widget.today, groups);
  }

  Future<void> _loadLibrary(AppDatabase db) async {
    try {
      final library = await ExerciseLibrary.load();
      if (!mounted) return;
      // The user's own exercises are followed, so an exercise made after this
      // tab was built counts in the week without a restart.
      _userSub = db.watchUserExercises().listen(
        (own) {
          if (!mounted) return;
          final merged = library.withUser(own);
          setState(() {
            _musclesOf = (ref) => [
              for (final g in merged.groupsOf(ref)) g.name,
            ];
            _followDay(db);
          });
        },
        onError: (Object _) {
          if (mounted) setState(() => _libraryFailed = true);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _libraryFailed = true);
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _msgTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _show(_Msg msg) {
    _msgTimer?.cancel();
    setState(() => _msg = msg);
  }

  /// Keeps the message for a while after the workout screen is closed, so it
  /// is seen on coming back.
  void _fadeMessage() {
    _msgTimer?.cancel();
    _msgTimer = Timer(_noteTime, () {
      if (mounted) setState(() => _msg = null);
    });
  }

  Future<void> _start(
    Future<StartResult> Function(AppDatabase db, Now now) begin,
  ) async {
    // One start at a time: a second tap on a row, or on another row, does
    // nothing while the first is writing or its screen is open.
    if (_starting) return;
    _starting = true;
    final scope = AppScope.of(context);
    try {
      final result = await begin(scope.db, scope.clock());
      if (!mounted) return;
      if (!result.started) {
        _show(_Msg(S.startRefusedToday, returnId: result.running!.workout.id));
        return;
      }
      final earlier = result.finishedEarlier;
      if (earlier != null) {
        // Its rest must not buzz during the new workout.
        scope.restTimer?.clearFor(earlier.workout.id);
        _show(
          _Msg(
            S.finishedEarlier(
              S.earlierWorkoutName(earlier.workout.localDate, widget.today),
            ),
          ),
        );
      } else if (_msg != null) {
        setState(() => _msg = null);
      }
      await openWorkoutScreen(context, result.workout!.id);
      _toTop();
      if (mounted && earlier != null) _fadeMessage();
    } catch (_) {
      if (mounted) _show(const _Msg(S.startFailed));
    } finally {
      _starting = false;
    }
  }

  // One screen at a time: the same guard as a start, so a double tap on
  // Exercises or on the weekly card opens one screen.
  Future<void> _openList() async {
    if (_starting) return;
    _starting = true;
    try {
      await openExerciseList(context);
    } finally {
      _starting = false;
    }
  }

  Future<void> _openWeekly() async {
    if (_starting) return;
    _starting = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const WeeklyVolumeScreen()),
      );
    } finally {
      _starting = false;
    }
  }

  Future<void> _openEditor(int? routineId) async {
    if (_starting) return;
    _starting = true;
    final RoutineEdit? edit;
    try {
      edit = await openRoutineEditor(context, routineId: routineId);
    } finally {
      _starting = false;
    }
    if (!mounted || edit == null) return;
    // From the row read back by the editor.
    switch (edit) {
      case RoutineSaved(:final name):
        _show(_Msg(S.routineSaved(name)));
      case RoutineRemoved(:final id, :final name):
        _show(
          _Msg(
            S.routineDeleted(name),
            undo: () => AppScope.of(context).db.undoDeleteRoutine(id),
          ),
        );
    }
    _fadeMessage();
  }

  /// Single flight: the message is taken and cleared before anything is
  /// awaited.
  Future<void> _undoMsg() async {
    final undo = _msg?.undo;
    if (undo == null) return;
    _msgTimer?.cancel();
    setState(() => _msg = null);
    try {
      await undo();
    } catch (_) {
      if (mounted) _show(const _Msg(S.routineUndoFailed));
    }
  }

  Future<void> _return(int workoutId) async {
    if (_starting) return;
    _starting = true;
    try {
      await openWorkoutScreen(context, workoutId);
      _toTop();
    } finally {
      _starting = false;
    }
  }

  Widget _watch<T>(
    Stream<T>? stream,
    Widget Function(AsyncSnapshot<T> snap) build,
  ) => StreamBuilder<T>(stream: stream, builder: (_, snap) => build(snap));

  @override
  Widget build(BuildContext context) {
    final msg = _msg;
    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            child: _watch<UnitSystem>(
              _units,
              (units) => _watch<WorkoutSummary?>(
                _running,
                (running) => _watch<List<StartAgainEntry>>(
                  _startAgain,
                  (again) => _watch<List<RoutineWithExercises>>(
                    _routines,
                    (routines) => _watch<Map<String, int>>(
                      _volume,
                      (volume) => _list(
                        running: running.data,
                        again: again.data,
                        routines: routines.data,
                        volume: volume.data,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (msg != null)
          ConfirmBar(
            message: msg.text,
            onUndo: msg.undo == null ? null : _undoMsg,
            actionLabel: msg.returnId == null ? null : S.returnToWorkout,
            onAction: msg.returnId == null
                ? null
                : () => _return(msg.returnId!),
          ),
      ],
    );
  }

  Widget _list({
    required WorkoutSummary? running,
    required List<StartAgainEntry>? again,
    required List<RoutineWithExercises>? routines,
    required Map<String, int>? volume,
  }) {
    final theme = Theme.of(context);
    final today = widget.today;
    // A workout from today stops every start: only "Return to workout" is
    // offered. One left from an earlier day does not (a start finishes it).
    final blocked = running != null && running.workout.localDate == today;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    S.workoutsTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _openList,
                child: const Text(S.exercisesButton),
              ),
            ],
          ),
        ),
        if (running != null)
          _RunningCard(
            running: running,
            today: today,
            onReturn: () => _return(running.workout.id),
          ),
        if (!blocked) ...[
          if (again != null && again.isNotEmpty) ...[
            _Heading(S.startAgainTitle),
            for (final e in again)
              _StartRow(
                key: ValueKey('again-${e.summary.workout.id}'),
                when: _when(e.kind, e.summary.workout.localDate, today),
                name: _nameOf(e.summary),
                facts: S.workoutFacts(
                  e.summary.exerciseCount,
                  e.summary.setCount,
                  e.summary.durationMs == null
                      ? null
                      : minutesIn(e.summary.durationMs!),
                ),
                onStart: () => _start(
                  (db, now) => db.startAgain(e.summary.workout.id, now),
                ),
              ),
          ],
          const _Heading(S.routinesTitle),
          if (routines != null && routines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(S.noRoutines),
            ),
          for (final r in routines ?? const <RoutineWithExercises>[])
            _StartRow(
              key: ValueKey('routine-${r.routine.id}'),
              name: r.routine.name,
              facts: r.exercises.isEmpty
                  ? S.routineNoExercises
                  : S.exercisesInBrief([
                      for (final x in r.exercises) x.exerciseName,
                    ], 3),
              onStart: () =>
                  _start((db, now) => db.startRoutine(r.routine.id, now)),
              onEdit: () => _openEditor(r.routine.id),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _openEditor(null),
                  child: const Text(S.newRoutine),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () =>
                      _start((db, now) => db.startEmptyWorkout(now)),
                  child: const Text(S.emptyWorkout),
                ),
              ],
            ),
          ),
        ],
        _Weekly(volume: volume, failed: _libraryFailed, onOpen: _openWeekly),
        const SizedBox(height: 16),
      ],
    );
  }

  static String _when(StartAgainKind kind, String date, String today) =>
      switch (kind) {
        StartAgainKind.yesterday => S.whenYesterday(S.dayShort(date, today)),
        StartAgainKind.sameWeekdayLastWeek => S.whenLastWeekday(
          S.weekdayLong(date),
          S.monthDay(date, today),
        ),
        StartAgainKind.other => S.dayShort(date, today),
      };

  static String _nameOf(WorkoutSummary s) =>
      s.routineName ??
      (s.exerciseNames.isEmpty
          ? S.workoutDefaultName
          : S.exercisesInBrief(s.exerciseNames, 2));
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _RunningCard extends StatelessWidget {
  const _RunningCard({
    required this.running,
    required this.today,
    required this.onReturn,
  });

  final WorkoutSummary running;
  final String today;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final w = running.workout;
    final isToday = w.localDate == today;
    final label = isToday
        ? S.returnToWorkout
        : S.returnToEarlier(S.earlierWorkoutName(w.localDate, today));
    final name =
        running.routineName ??
        (running.exerciseNames.isEmpty
            ? S.workoutDefaultName
            : S.exercisesInBrief(running.exerciseNames, 2));
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            MinuteTick(
              builder: (context) {
                final now = AppScope.of(context).clock();
                final ms = now.utcMs - w.startedAtMs;
                return Text(
                  isToday
                      ? S.workoutRunning(ms <= 0 ? 0 : ms ~/ 60000)
                      : S.earlierStillRunning(
                          S.earlierWorkoutName(w.localDate, today),
                        ),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: onReturn,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of "Start again" or "Routines": the words, and a Start button that
/// starts it in one tap.
class _StartRow extends StatelessWidget {
  const _StartRow({
    super.key,
    required this.name,
    required this.facts,
    required this.onStart,
    this.when,
    this.onEdit,
  });

  final String? when;
  final String name;
  final String facts;
  final VoidCallback onStart;

  /// Set only when task 4.4's routine editor is in place.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (when != null) Text(when!, style: muted),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(facts, style: muted),
              ],
            ),
          ),
          if (onEdit != null)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onEdit,
              child: const Text(S.editRoutine),
            ),
          const SizedBox(width: 8),
          Semantics(
            container: true,
            button: true,
            label: S.startSpoken(name, when),
            excludeSemantics: true,
            onTap: onStart,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
              onPressed: onStart,
              child: const Text(S.start),
            ),
          ),
        ],
      ),
    );
  }
}

/// "This week, sets by muscle": every group with its number of sets, most
/// first. A number and a bar, so the bar is only a picture of the number.
class _Weekly extends StatelessWidget {
  const _Weekly({
    required this.volume,
    required this.failed,
    required this.onOpen,
  });

  final Map<String, int>? volume;
  final bool failed;
  final VoidCallback onOpen;

  /// A bar is full at this many sets, as in the wireframe (6 sets is 60%).
  static const _full = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = volume;
    final head = Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(S.weeklyTitle, style: theme.textTheme.titleMedium),
      ),
    );
    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [head, const Text(S.weeklyUnavailable)],
      );
    }
    if (counts == null) return const SizedBox.shrink();
    final groups = [...VolumeGroup.values]
      ..sort((a, b) {
        final c = (counts[b.name] ?? 0).compareTo(counts[a.name] ?? 0);
        return c != 0 ? c : a.index.compareTo(b.index);
      });
    var biggest = _full;
    for (final g in groups) {
      final n = counts[g.name] ?? 0;
      if (n > biggest) biggest = n;
    }
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups)
          Semantics(
            container: true,
            label: S.weeklySpoken(S.groupName(g.name), counts[g.name] ?? 0),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(S.groupName(g.name))),
                      Text(S.weeklySets(counts[g.name] ?? 0)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: (counts[g.name] ?? 0) / biggest,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    final all = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [head, rows],
    );
    // The title and the bars both open the weekly screen.
    return InkWell(onTap: onOpen, child: all);
  }
}
