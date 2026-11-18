// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/workout_data.dart';
import '../../strings.dart';
import '../food/confirm_bar.dart';
import '../my_foods/food_editor.dart' show popRouteOf;
import 'exercise_picker.dart';
import 'rest_timer_bar.dart' show defaultRestSeconds;
import 'seams.dart';
import 'workout_widgets.dart' show workoutProblemText;

/// Opens the routine editor (routine-editor.html frame 1) for a new routine,
/// or for [routineId]. Completes with what changed, or null.
Future<RoutineEdit?> openRoutineEditor(
  BuildContext context, {
  int? routineId,
}) => Navigator.of(context).push<RoutineEdit>(
  MaterialPageRoute(builder: (_) => RoutineEditor(routineId: routineId)),
);

class _Entry {
  _Entry(this.ref, this.name, {this.sets, this.rest});

  final String ref;
  final String name;

  /// Null keeps the data layer's default sets / the rest timer's default.
  int? sets;
  int? rest;
  final key = UniqueKey();

  int get setsShown => sets ?? defaultSetCount;
  int get restShown => rest ?? defaultRestSeconds;
}

enum _Menu { sets, rest, replace, remove, moveUp, moveDown }

/// Name, then the exercises in order. Drag to reorder (or Move up and Move
/// down in the menu, for a screen reader), and in each exercise's menu the
/// number of sets, the rest time, Replace and Remove. Weights and reps are not
/// set here.
class RoutineEditor extends StatefulWidget {
  const RoutineEditor({super.key, this.routineId});

  /// The routine to change, or null for a new one.
  final int? routineId;

  @override
  State<RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<RoutineEditor> {
  final _name = TextEditingController();
  var _entries = <_Entry>[];
  var _loaded = false;
  var _loadFailed = false;
  var _initial = '';
  var _started = false;

  String? _nameError;
  String? _message;
  var _busy = false;
  var _warned = false;

  bool get _isNew => widget.routineId == null;

  String get _snapshot =>
      '${_name.text}|${[for (final e in _entries) '${e.ref},${e.sets},${e.rest}'].join(';')}';

  bool get _dirty => _loaded && _snapshot != _initial;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (mounted) setState(() => _nameError = null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final id = widget.routineId;
    if (id == null) {
      _loaded = true;
      _initial = _snapshot;
      return;
    }
    AppScope.of(context).db
        .getRoutine(id)
        .then(
          (r) {
            if (!mounted) return;
            if (r == null) {
              setState(() => _loadFailed = true);
              return;
            }
            setState(() {
              _name.text = r.routine.name;
              _entries = [
                for (final e in r.exercises)
                  _Entry(
                    e.exerciseRef,
                    e.exerciseName,
                    sets: e.targetSets,
                    rest: e.restSeconds,
                  ),
              ];
              _loaded = true;
              _initial = _snapshot;
            });
          },
          onError: (Object _) {
            if (mounted) setState(() => _loadFailed = true);
          },
        );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  // Changes to the list.

  void _move(int from, int to) {
    setState(() {
      final e = _entries.removeAt(from);
      _entries.insert(to, e);
    });
  }

  Future<void> _addExercises() => openExercisePicker(
    context,
    alreadyIn: {for (final e in _entries) e.ref},
    onPick: (ref, name) async {
      if (_entries.any((e) => e.ref == ref)) return S.problemDuplicateRoutine;
      setState(() => _entries.add(_Entry(ref, name)));
      return null;
    },
  );

  Future<void> _replace(int index) {
    final old = _entries[index];
    return openExercisePicker(
      context,
      single: true,
      alreadyIn: {for (final e in _entries) e.ref},
      onPick: (ref, name) async {
        if (_entries.any((e) => e.ref == ref)) return S.problemDuplicateRoutine;
        final at = _entries.indexOf(old);
        if (at < 0) return S.routineSaveFailed;
        setState(
          () =>
              _entries[at] = _Entry(ref, name, sets: old.sets, rest: old.rest),
        );
        return null;
      },
    );
  }

  Future<void> _step({
    required String title,
    required int value,
    required int step,
    required int min,
    required int max,
    required String Function(int) format,
    required String lessSpoken,
    required String moreSpoken,
    required void Function(int) apply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StepSheet(
        title: title,
        value: value,
        step: step,
        min: min,
        max: max,
        format: format,
        lessSpoken: lessSpoken,
        moreSpoken: moreSpoken,
        apply: (v) => setState(() => apply(v)),
      ),
    );
  }

  Future<void> _menu(_Menu action, int index) async {
    final e = _entries[index];
    switch (action) {
      case _Menu.sets:
        return _step(
          title: S.setsSheetTitle(e.name),
          value: e.setsShown,
          step: 1,
          min: 1,
          max: 30,
          format: (v) => v == 1 ? '1 set' : '$v sets',
          lessSpoken: S.setsFewer,
          moreSpoken: S.setsMore,
          apply: (v) => e.sets = v,
        );
      case _Menu.rest:
        return _step(
          title: S.restSheetTitle(e.name),
          value: e.restShown,
          step: 15,
          min: 0,
          max: 600,
          format: (v) => v == 0 ? S.restNone : S.restClock(v),
          lessSpoken: S.restShorter,
          moreSpoken: S.restLonger,
          apply: (v) => e.rest = v,
        );
      case _Menu.replace:
        return _replace(index);
      case _Menu.remove:
        setState(() => _entries.removeAt(index));
      case _Menu.moveUp:
        if (index > 0) _move(index, index - 1);
      case _Menu.moveDown:
        if (index < _entries.length - 1) _move(index, index + 1);
    }
  }

  // Save and delete.

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = S.routineBlankName);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final scope = AppScope.of(context);
    try {
      final inputs = [
        for (final e in _entries)
          RoutineExerciseInput(
            exerciseRef: e.ref,
            exerciseName: e.name,
            targetSets: e.sets,
            restSeconds: e.rest,
          ),
      ];
      final id = widget.routineId;
      final saved = id == null
          ? await scope.db.createRoutine(_name.text, inputs, scope.clock())
          : await scope.db.updateRoutine(id, _name.text, inputs);
      if (!mounted) return;
      // The name comes from the row read back.
      popRouteOf<RoutineEdit>(context, RoutineSaved(saved.routine.name));
    } on WorkoutRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.problem == WorkoutProblem.blankName) {
          _nameError = S.routineBlankName;
        } else {
          _message = workoutProblemText(e.problem);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = S.routineSaveFailed;
        });
      }
    }
  }

  Future<void> _delete() async {
    final id = widget.routineId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final db = AppScope.of(context).db;
      final now = await db.getRoutine(id);
      await db.deleteRoutine(id);
      if (!mounted) return;
      popRouteOf<RoutineEdit>(
        context,
        RoutineRemoved(id, now?.routine.name ?? _name.text.trim()),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = S.routineSaveFailed;
        });
      }
    }
  }

  // Layout.

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _warned,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dirty) {
          setState(() {
            _warned = true;
            _message = S.routineLeaveWarn;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? S.routineNewTitle : _name.text),
          actions: [
            if (!_isNew)
              PopupMenuButton<String>(
                tooltip: S.routineMenu,
                enabled: !_busy && _loaded,
                onSelected: (_) => _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text(S.routineDelete)),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ContentWidth(
                  child: _loadFailed
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(S.routineLoadFailed),
                        )
                      : !_loaded
                      ? const Center(child: CircularProgressIndicator())
                      : _list(context),
                ),
              ),
              if (_message != null) ConfirmBar(message: _message!),
              Material(
                elevation: 4,
                child: ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(88, 48),
                        ),
                        onPressed: _busy || !_loaded ? null : _save,
                        child: const Text(S.routineSave),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final theme = Theme.of(context);
    return ReorderableListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      buildDefaultDragHandles: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      onReorderItem: _move,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: S.routineNameLabel,
              errorText: _nameError,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Semantics(
              header: true,
              child: Text(
                S.routineExercises,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(S.noExercises),
            ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _addExercises,
              child: const Text(S.addExercise),
            ),
            const SizedBox(height: 12),
            Text(S.routineNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      children: [
        for (var i = 0; i < _entries.length; i++) _row(context, _entries[i], i),
      ],
    );
  }

  Widget _row(BuildContext context, _Entry e, int i) {
    final theme = Theme.of(context);
    return Row(
      key: e.key,
      children: [
        ReorderableDragStartListener(
          index: i,
          child: Semantics(
            label: S.routineDragSpoken(e.name),
            excludeSemantics: true,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.drag_handle),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  S.routineFacts(e.setsShown, S.restClock(e.restShown)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuButton<_Menu>(
          tooltip: S.exerciseMenuSpoken(e.name),
          onSelected: (a) => _menu(a, i),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: _Menu.sets,
              child: Text(S.routineMenuSets),
            ),
            const PopupMenuItem(
              value: _Menu.rest,
              child: Text(S.routineMenuRest),
            ),
            const PopupMenuItem(
              value: _Menu.replace,
              child: Text(S.replaceExercise),
            ),
            const PopupMenuItem(
              value: _Menu.remove,
              child: Text(S.removeExercise),
            ),
            PopupMenuItem(
              value: _Menu.moveUp,
              enabled: i > 0,
              child: const Text(S.moveUp),
            ),
            PopupMenuItem(
              value: _Menu.moveDown,
              enabled: i < _entries.length - 1,
              child: const Text(S.moveDown),
            ),
          ],
        ),
      ],
    );
  }
}

/// A small sheet with a number and two steppers (one fewer, one more). Each
/// step applies at once, so nothing is lost by closing it.
class _StepSheet extends StatefulWidget {
  const _StepSheet({
    required this.title,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.lessSpoken,
    required this.moreSpoken,
    required this.apply,
  });

  final String title;
  final int value;
  final int step;
  final int min;
  final int max;
  final String Function(int) format;
  final String lessSpoken;
  final String moreSpoken;
  final void Function(int) apply;

  @override
  State<_StepSheet> createState() => _StepSheetState();
}

class _StepSheetState extends State<_StepSheet> {
  late var _value = widget.value;

  void _to(int v) {
    final c = v.clamp(widget.min, widget.max);
    if (c == _value) return;
    setState(() => _value = c);
    widget.apply(c);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: widget.lessSpoken,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _value > widget.min
                      ? () => _to(_value - widget.step)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      widget.format(_value),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: widget.moreSpoken,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _value < widget.max
                      ? () => _to(_value + widget.step)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(S.setSheetDone),
            ),
          ],
        ),
      ),
    );
  }
}
