// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/settings_data.dart';
import '../../data/workout_data.dart';
import '../../math/training.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';
import '../food/confirm_bar.dart';
import '../my_foods/food_editor.dart' show popRouteOf;
import 'finish_screen.dart';
import 'rest_timer_bar.dart';
import 'exercise_detail.dart';
import 'exercise_picker.dart';
import 'set_sheet.dart';
import 'workout_widgets.dart';

/// True from a request to open the workout until its screen is gone, so a fast
/// double tap on "Start" or "Return to workout" opens one screen. The screen
/// also clears it when it leaves the tree.
bool _screenOpen = false;

/// Opens the active workout screen over the tab bar.
Future<void> openWorkoutScreen(BuildContext context, int workoutId) async {
  if (_screenOpen) return;
  _screenOpen = true;
  try {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => WorkoutScreen(workoutId: workoutId)),
    );
  } finally {
    _screenOpen = false;
  }
}

/// The active workout (workout.html frames 2 to 5): one card per exercise,
/// each set a row with a check that logs exactly what the row shows.
///
/// The screen keeps nothing the database does not hold. Every tap is written
/// before the screen shows it, so closing the screen or the app loses nothing.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  WorkoutView? _view;
  UnitSystem? _units;
  var _failed = false;
  StreamSubscription<WorkoutView?>? _viewSub;
  StreamSubscription<UnitSystem>? _unitsSub;
  Timer? _minuteTimer;

  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  final _keys = <int, GlobalKey>{};

  // Sets being logged, and sets already logged here. A second tap on a check
  // finds its set in one of them and does nothing, so a double tap logs once
  // and starts one rest.
  final _logging = <int>{};
  final _logged = <int>{};
  int? _scrollAfter;
  var _firstView = true;

  var _busy = false;
  var _picking = false;
  var _finishing = false;
  var _closing = false;
  String? _message;

  // The rows of the last removed set or exercise, for Undo. Dropped after one
  // Undo, on Finish, and with the screen.
  RemovedSets? _removed;
  var _removedWhole = false;
  Timer? _removedTimer;
  static const _removedTime = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    // The minutes in "Started 5:30 pm, 9 min" move on while the screen is open.
    _minuteTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewSub != null) return;
    final db = AppScope.of(context).db;
    _viewSub = db
        .watchWorkout(widget.workoutId)
        .listen(
          _onView,
          onError: (_) {
            if (mounted) setState(() => _failed = true);
          },
        );
    _unitsSub = db.watchUnits().listen((u) {
      if (mounted) setState(() => _units = u);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _screenOpen = false;
    _removedTimer?.cancel();
    _minuteTimer?.cancel();
    _viewSub?.cancel();
    _unitsSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _closeSelf() {
    if (_closing || !mounted) return;
    _closing = true;
    popRouteOf<void>(context, null);
  }

  void _onView(WorkoutView? view) {
    if (!mounted) return;
    if (view == null) {
      // Deleted, or replaced by an import: nothing left to show.
      AppScope.of(context).restTimer?.clearFor(widget.workoutId);
      _closeSelf();
      return;
    }
    if (!view.isRunning && !_finishing) {
      // Finished somewhere else: a finished workout cannot be changed here.
      AppScope.of(context).restTimer?.clearFor(widget.workoutId);
      _closeSelf();
      return;
    }
    setState(() {
      _view = view;
      _failed = false;
      final ids = {
        for (final e in view.exercises)
          for (final s in e.sets) s.row.id,
      };
      _keys.removeWhere((id, _) => !ids.contains(id));
    });
    final target = _scrollAfter;
    final done =
        target != null &&
        view.exercises.any(
          (e) => e.sets.any((s) => s.row.id == target && s.isDone),
        );
    if (_firstView || done) {
      if (done) _scrollAfter = null;
      final jump = _firstView;
      _firstView = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToNext(jump: jump);
      });
    }
  }

  GlobalKey _keyFor(int setId) => _keys.putIfAbsent(setId, GlobalKey.new);

  /// Brings the next set to do into view, when it is not already.
  void _scrollToNext({bool jump = false}) {
    final next = _view?.nextSet;
    if (next == null) return;
    final row = _keys[next.row.id]?.currentContext;
    final list = _listKey.currentContext;
    if (row == null || list == null || !_scroll.hasClients) return;
    final rowBox = row.findRenderObject() as RenderBox?;
    final listBox = list.findRenderObject() as RenderBox?;
    if (rowBox == null || listBox == null) return;
    final rowTop = rowBox.localToGlobal(Offset.zero).dy;
    final listTop = listBox.localToGlobal(Offset.zero).dy;
    final inView =
        rowTop >= listTop &&
        rowTop + rowBox.size.height <= listTop + listBox.size.height;
    if (inView) return;
    Scrollable.ensureVisible(
      row,
      alignment: 0.3,
      duration: jump ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _problem(Object e) =>
      e is WorkoutRefused ? workoutProblemText(e.problem) : S.workoutSaveFailed;

  /// Runs one change to the workout. One at a time; a failure is said in
  /// plain words and changes nothing.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      if (_message != null) setState(() => _message = null);
      await action();
    } catch (e) {
      if (mounted) setState(() => _message = _problem(e));
    } finally {
      _busy = false;
    }
  }

  Future<void> _log(SetView set, ExerciseBlock block, int number) async {
    if (set.isDone || _logged.contains(set.row.id)) return;
    final reps = set.row.reps;
    if (reps == null || reps < 1) {
      // A set with no reps cannot be logged: ask for them.
      await _openSet(set, block, number, notice: S.needsRepsFirst, reps: true);
      return;
    }
    if (!_logging.add(set.row.id)) return;
    final scope = AppScope.of(context);
    try {
      if (_message != null) setState(() => _message = null);
      _scrollAfter = set.row.id;
      await scope.db.logSet(set.row.id, scope.clock());
      _logged.add(set.row.id);
      scope.restTimer?.start(
        widget.workoutId,
        block.restSeconds ?? defaultRestSeconds,
      );
    } catch (e) {
      _scrollAfter = null;
      if (mounted) setState(() => _message = _problem(e));
    } finally {
      _logging.remove(set.row.id);
    }
  }

  Future<void> _openSet(
    SetView set,
    ExerciseBlock block,
    int number, {
    String? notice,
    bool reps = false,
  }) async {
    final units = _units;
    if (units == null) return;
    final removed = await showSetSheet(
      context,
      set: set,
      exerciseName: block.exerciseName,
      number: number,
      units: units,
      notice: notice,
      focus: reps ? SetField.reps : SetField.weight,
    );
    if (removed != null && mounted) _showRemoved(removed, whole: false);
  }

  /// Shows the Undo bar for 10 seconds. A removal clears an old error, so the
  /// Undo is not hidden behind it.
  void _showRemoved(RemovedSets removed, {required bool whole}) {
    _removedTimer?.cancel();
    _removedTimer = Timer(_removedTime, () {
      if (mounted) setState(() => _removed = null);
    });
    setState(() {
      _removed = removed;
      _removedWhole = whole;
      _message = null;
    });
  }

  /// Undo for the last removal. Single flight: the rows are taken before
  /// anything is awaited, so a second tap finds nothing.
  Future<void> _undo() async {
    final removed = _removed;
    if (removed == null || _busy) return;
    _removedTimer?.cancel();
    setState(() => _removed = null);
    await _run(() => AppScope.of(context).db.undoRemove(removed));
  }

  String _removedText(RemovedSets r) => !_removedWhole
      ? S.removedSetMessage(r.exerciseName, r.setNumber)
      : S.removedExerciseMessage(r.exerciseName, r.sets.length);

  Future<void> _finish() async {
    if (_finishing) return;
    _removedTimer?.cancel();
    setState(() {
      _finishing = true;
      _message = null;
      _removed = null;
    });
    final scope = AppScope.of(context);
    try {
      await scope.db.finishWorkout(widget.workoutId, scope.clock());
    } catch (e) {
      if (mounted) {
        setState(() {
          _finishing = false;
          _message = _problem(e);
        });
      }
      return;
    }
    scope.restTimer?.clearFor(widget.workoutId);
    if (!mounted) return;
    final outcome = await Navigator.of(context, rootNavigator: true)
        .push<FinishOutcome>(
          MaterialPageRoute(
            builder: (_) => FinishScreen(workoutId: widget.workoutId),
          ),
        );
    if (!mounted) return;
    if (outcome == FinishOutcome.resumed) {
      setState(() => _finishing = false);
    } else {
      _closeSelf();
    }
  }

  /// Opens the picker over the workout. One at a time: a double tap on
  /// "+ Add exercise" opens one picker.
  Future<void> _pick({
    required Future<void> Function(AppDatabase db, String ref, String name)
    write,
    bool single = false,
  }) async {
    final view = _view;
    if (view == null || _picking) return;
    _picking = true;
    final scope = AppScope.of(context);
    try {
      await openExercisePicker(
        context,
        single: single,
        alreadyIn: {for (final e in view.exercises) e.exerciseRef},
        onPick: (ref, name) async {
          try {
            await write(scope.db, ref, name);
            return null;
          } catch (e) {
            return _problem(e);
          }
        },
      );
    } finally {
      _picking = false;
    }
  }

  Future<void> _addExercise() => _pick(
    write: (db, ref, name) => db.addExercise(widget.workoutId, ref, name),
  );

  Future<void> _replace(ExerciseBlock block) => _pick(
    single: true,
    write: (db, ref, name) =>
        db.replaceExercise(widget.workoutId, block.exerciseRef, ref, name),
  );

  Future<void> _menu(_Menu action, ExerciseBlock block) {
    final db = AppScope.of(context).db;
    switch (action) {
      case _Menu.moveUp:
        return _run(
          () => db.moveExercise(widget.workoutId, block.exerciseRef, -1),
        );
      case _Menu.moveDown:
        return _run(
          () => db.moveExercise(widget.workoutId, block.exerciseRef, 1),
        );
      case _Menu.remove:
        return _run(() async {
          final removed = await db.removeExercise(
            widget.workoutId,
            block.exerciseRef,
          );
          if (mounted && removed.sets.isNotEmpty) {
            _showRemoved(removed, whole: true);
          }
        });
      case _Menu.replace:
        return _replace(block);
      case _Menu.details:
        return Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(
              exerciseRef: block.exerciseRef,
              name: block.exerciseName,
            ),
          ),
        );
    }
  }

  String _title(WorkoutView view) {
    final name = view.routineName;
    if (name != null) return name;
    final names = [for (final e in view.exercises) e.exerciseName];
    return names.isEmpty ? S.workoutDefaultName : S.exercisesInBrief(names, 2);
  }

  String _subtitle(WorkoutView view) {
    final w = view.workout;
    final now = AppScope.of(context).clock();
    final time = S.timeOfDay(minuteOfDayOf(w.startedAtMs, w.tzOffsetMinutes));
    // A workout left running from an earlier day names the day, not a count
    // of minutes in the thousands.
    if (w.localDate != now.localDate) {
      return S.workoutStartedOn(w.localDate, now.localDate, time);
    }
    final ms = now.utcMs - w.startedAtMs;
    return S.workoutStarted(time, ms <= 0 ? 0 : ms ~/ 60000);
  }

  /// 'Up next: set 2, 175 lb x 8' for the first set not logged.
  String? _upNext(WorkoutView view, UnitSystem units) {
    final next = view.nextSet;
    if (next == null) return null;
    for (final e in view.exercises) {
      for (var i = 0; i < e.sets.length; i++) {
        if (!identical(e.sets[i], next)) continue;
        final w = next.row.weightKg;
        return S.upNext(
          i + 1,
          w == null
              ? S.bodyWeightLower
              : '${setWeightText(w, units)} ${S.unitWord(units)}',
          next.row.reps,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final units = _units;
    final scope = AppScope.of(context);
    final timer = scope.restTimer;
    final ready = view != null && units != null;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            WorkoutHeader(
              title: ready ? _title(view) : S.workoutDefaultName,
              subtitle: ready ? _subtitle(view) : null,
              trailing: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
                onPressed: ready && !_finishing ? _finish : null,
                child: const Text(S.finish),
              ),
            ),
            Expanded(
              child: ContentWidth(
                child: !ready
                    ? Center(
                        child: _failed
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(S.workoutLoadFailed),
                              )
                            : const CircularProgressIndicator(),
                      )
                    : _list(view, units),
              ),
            ),
            if (_message != null)
              ConfirmBar(message: _message!)
            else if (_removed != null)
              ConfirmBar(message: _removedText(_removed!), onUndo: _undo),
            if (timer != null && ready)
              ListenableBuilder(
                listenable: timer,
                builder: (context, _) => timer.workoutId == widget.workoutId
                    // Never taller than half the screen: at a very large text
                    // size the bar scrolls inside its space, and the sets keep
                    // theirs.
                    ? ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: RestTimerBar(
                            timer: timer,
                            upNext: _upNext(view, units),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list(WorkoutView view, UnitSystem units) {
    final nextId = view.nextSet?.row.id;
    return SingleChildScrollView(
      key: _listKey,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view.exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(S.noExercises),
            ),
          for (var i = 0; i < view.exercises.length; i++)
            _ExerciseCard(
              block: view.exercises[i],
              units: units,
              today: AppScope.of(context).clock().localDate,
              nextId: nextId,
              isFirst: i == 0,
              isLast: i == view.exercises.length - 1,
              keyFor: _keyFor,
              onLog: (s, n) => _log(s, view.exercises[i], n),
              onOpen: (s, n, {bool reps = false}) =>
                  _openSet(s, view.exercises[i], n, reps: reps),
              onAddSet: () => _run(
                () => AppScope.of(context).db
                    .addSet(widget.workoutId, view.exercises[i].exerciseRef),
              ),
              onMenu: (a) => _menu(a, view.exercises[i]),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _addExercise,
                child: const Text(S.addExercise),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Menu { moveUp, moveDown, replace, remove, details }

typedef _OpenSet = Future<void> Function(SetView, int, {bool reps});

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.block,
    required this.units,
    required this.today,
    required this.nextId,
    required this.isFirst,
    required this.isLast,
    required this.keyFor,
    required this.onLog,
    required this.onOpen,
    required this.onAddSet,
    required this.onMenu,
  });

  final ExerciseBlock block;
  final UnitSystem units;
  final String today;
  final int? nextId;
  final bool isFirst;
  final bool isLast;
  final GlobalKey Function(int setId) keyFor;
  final Future<void> Function(SetView, int) onLog;
  final _OpenSet onOpen;
  final VoidCallback onAddSet;
  final void Function(_Menu) onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anyLogged = block.sets.any((s) => s.isDone);
    final last = block.lastTime;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        block.exerciseName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<_Menu>(
                  tooltip: S.exerciseMenuSpoken(block.exerciseName),
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _Menu.moveUp,
                      enabled: !isFirst,
                      child: const Text(S.moveUp),
                    ),
                    PopupMenuItem(
                      value: _Menu.moveDown,
                      enabled: !isLast,
                      child: const Text(S.moveDown),
                    ),
                    PopupMenuItem(
                      value: _Menu.replace,
                      enabled: !anyLogged,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(S.replaceExercise),
                          if (anyLogged)
                            Text(
                              S.replaceNotAfterLogged,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: _Menu.remove,
                      child: Text(S.removeExercise),
                    ),
                    const PopupMenuItem(
                      value: _Menu.details,
                      child: Text(S.exerciseDetails),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              block.lastTimeDate == null
                  ? S.firstTimeNote
                  : S.lastTime(S.monthDay(block.lastTimeDate!, today), [
                      for (final v in last) setValuesText(v, units),
                    ]),
              style: theme.textTheme.bodySmall,
            ),
            for (var i = 0; i < block.sets.length; i++)
              _SetRow(
                key: keyFor(block.sets[i].row.id),
                set: block.sets[i],
                number: i + 1,
                units: units,
                isNext: block.sets[i].row.id == nextId,
                onLog: () => onLog(block.sets[i], i + 1),
                onOpen: (reps) => onOpen(block.sets[i], i + 1, reps: reps),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onAddSet,
                child: const Text(S.addSet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.units,
    required this.isNext,
    required this.onLog,
    required this.onOpen,
  });

  final SetView set;
  final int number;
  final UnitSystem units;
  final bool isNext;
  final VoidCallback onLog;
  final void Function(bool reps) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = set.row;
    final done = set.isDone;
    final unit = S.unitWord(units);
    final w = row.weightKg;
    final reps = row.reps;
    final weightWords = w != null
        ? '${setWeightText(w, units)} $unit'
        : (reps == null ? S.weightCellEmpty : S.bodyWeight);
    final repsWords = reps == null ? S.repsCellEmpty : S.repsCount(reps);
    final bold = done
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle();
    final spokenWeight = w != null
        ? '${setWeightText(w, units)} $unit'
        : S.bodyWeightLower;
    final record = set.record;
    final est = (done && record.estimate && w != null && reps != null)
        ? estimatedOneRepMaxIn(w, reps, units)
        : null;

    Widget cell(String text, String spoken, bool repsField, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Semantics(
          container: true,
          button: true,
          label: spoken,
          excludeSemantics: true,
          onTap: () => onOpen(repsField),
          child: InkWell(
            onTap: () => onOpen(repsField),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(text, textAlign: TextAlign.center, style: bold),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final check = done
        ? Semantics(
            container: true,
            label: S.setDoneSpoken(number, spokenWeight, reps ?? 0),
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    S.doneWord,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          )
        : Semantics(
            container: true,
            button: true,
            label: reps == null || reps < 1
                ? S.checkNeedsReps(number)
                : S.checkSpoken(number, spokenWeight, reps),
            excludeSemantics: true,
            onTap: onLog,
            child: OutlinedButton(
              key: ValueKey('check-${row.id}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(56, 56),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  width: isNext ? 3 : 1,
                  color: isNext
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline,
                ),
              ),
              onPressed: onLog,
              child: Icon(Icons.check, size: isNext ? 28 : 24),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 24),
                child: Text('$number', style: bold),
              ),
              const SizedBox(width: 8),
              cell(
                weightWords,
                S.setWeightSpoken(number, spokenWeight),
                false,
                flex: 3,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('x', style: bold),
              ),
              cell(
                repsWords,
                S.setRepsSpoken(
                  number,
                  reps == null ? null : S.repsCount(reps),
                ),
                true,
                flex: 2,
              ),
              const SizedBox(width: 8),
              check,
            ],
          ),
        ),
        // Compared as shown, in the user's units: a weight that differs only
        // beyond what the screen shows is not a change.
        if (set.changed &&
            set.previous != null &&
            setValuesText(set.previous!, units) !=
                setValuesText((weightKg: w, reps: reps), units))
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 4),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const WorkoutBadge(S.changedBadge),
                Text(S.changedFrom(setValuesText(set.previous!, units))),
              ],
            ),
          ),
        if (done && record.any)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 4),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const WorkoutBadge(S.newRecord),
                Text(
                  S.newRecordWhat(
                    heaviest: record.heaviest,
                    estimate: est == null ? null : oneRepMaxText(est, units),
                    unit: unit,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
