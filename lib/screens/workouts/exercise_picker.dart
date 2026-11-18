// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/exercise_library.dart';
import '../../data/workout_data.dart';
import '../../strings.dart';
import '../food/confirm_bar.dart';
import '../my_foods/food_editor.dart' show popRouteOf;
import 'create_exercise_screen.dart';
import 'exercise_detail.dart';

/// What the picker calls for each exercise the user adds or picks. It returns
/// null when it worked, or a plain sentence to show when it did not.
typedef PickExercise = Future<String?> Function(String ref, String name);

/// The exercise library with the user's own exercises merged in. The bundled
/// list is read once and shared; this only adds the user's rows.
Future<ExerciseLibrary> loadExerciseLibrary(AppDatabase db) async =>
    ExerciseLibrary.load(userExercises: await db.userExercises());

/// Opens the picker over a workout or a routine (routine-editor.html frame 2).
/// It stays open after each Add, and closes with Back, or after one pick with
/// [single]. Completes when it closes.
Future<void> openExercisePicker(
  BuildContext context, {
  required PickExercise onPick,
  required Set<String> alreadyIn,
  bool single = false,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => ExercisePickerScreen(
      onPick: onPick,
      alreadyIn: alreadyIn,
      single: single,
    ),
  ),
);

/// The exercise list: the picker in browse mode, where a tap opens the detail.
Future<void> openExerciseList(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const ExercisePickerScreen()));

enum _Kind { heading, exercise, note, create }

class _Item {
  const _Item.heading(this.text)
    : kind = _Kind.heading,
      ref = '',
      sub = '',
      recent = false;
  const _Item.note(this.text)
    : kind = _Kind.note,
      ref = '',
      sub = '',
      recent = false;
  const _Item.create(this.text)
    : kind = _Kind.create,
      ref = '',
      sub = '',
      recent = false;
  const _Item.exercise(this.ref, this.text, this.sub, {this.recent = false})
    : kind = _Kind.exercise;

  final _Kind kind;
  final String ref;
  final String text;
  final String sub;
  final bool recent;
}

/// With [onPick] each row has an Add button; without it (browse mode) a row
/// only opens the exercise's detail.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({
    super.key,
    this.onPick,
    this.alreadyIn = const {},
    this.single = false,
  });

  final PickExercise? onPick;
  final Set<String> alreadyIn;
  final bool single;

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  late AppDatabase _db;
  var _started = false;

  ExerciseLibrary? _library;
  var _failed = false;
  List<({String exerciseRef, String exerciseName})> _recents = const [];

  final _query = TextEditingController();
  String? _group;
  final _added = <String>{};
  String? _message;
  var _picking = false;
  var _opening = false;

  bool get _picks => widget.onPick != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _db = AppScope.of(context).db;
    // The screen is shown at once with the recent exercises; the list fills in
    // when it is read.
    _db.recentExercises().then((r) {
      if (mounted) setState(() => _recents = r);
    }, onError: (Object _) {});
    _load();
  }

  Future<void> _load() async {
    try {
      final lib = await loadExerciseLibrary(_db);
      if (mounted) setState(() => _library = lib);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _add(String ref, String name) async {
    final onPick = widget.onPick;
    if (onPick == null || _picking) return;
    _picking = true;
    setState(() => _message = null);
    try {
      final said = await onPick(ref, name);
      if (!mounted) return;
      if (said != null) {
        setState(() => _message = said);
        return;
      }
      setState(() => _added.add(ref));
      if (widget.single) popRouteOf<void>(context, null);
    } finally {
      _picking = false;
    }
  }

  Future<void> _openDetail(String ref, String name) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ExerciseDetailScreen(exerciseRef: ref, name: name),
        ),
      );
    } finally {
      _opening = false;
    }
  }

  Future<void> _create() async {
    final lib = _library;
    if (lib == null || _opening) return;
    _opening = true;
    final LibraryExercise? made;
    try {
      made = await Navigator.of(context).push<LibraryExercise>(
        MaterialPageRoute(
          builder: (_) =>
              CreateExerciseScreen(library: lib, initialName: _query.text),
        ),
      );
    } finally {
      _opening = false;
    }
    if (made == null || !mounted) return;
    // The new exercise is the one result, ready to Add.
    final ExerciseLibrary fresh;
    try {
      fresh = lib.withUser(await _db.userExercises());
    } catch (_) {
      if (mounted) setState(() => _message = S.pickerLoadFailed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _library = fresh;
      _group = null;
      _query.text = made!.name;
    });
  }

  String _subOf(String ref) {
    final e = _library?.lookup(ref).exercise;
    return e == null
        ? ''
        : S.exerciseSub(e.primaryMuscles, e.secondaryMuscles, e.equipment);
  }

  List<_Item> _items() {
    final lib = _library;
    final typed = _query.text.trim();
    final filtered = typed.isNotEmpty || _group != null;
    _Item of(LibraryExercise e) => _Item.exercise(
      e.ref,
      e.name,
      S.exerciseSub(e.primaryMuscles, e.secondaryMuscles, e.equipment),
    );
    final out = <_Item>[];
    if (filtered) {
      out.add(const _Item.heading(S.pickerResults));
      if (lib == null) {
        out.add(_Item.note(_failed ? S.pickerLoadFailed : S.pickerLoading));
      } else {
        final found = lib.search(_query.text, group: _group);
        if (found.isEmpty) out.add(const _Item.note(S.pickerNone));
        out.addAll(found.map(of));
      }
      if (typed.isNotEmpty && lib != null) {
        out.add(_Item.create(S.pickerCreate(typed)));
      }
      return out;
    }
    if (_recents.isNotEmpty) {
      out.add(const _Item.heading(S.pickerRecent));
      for (final r in _recents) {
        out.add(
          _Item.exercise(
            r.exerciseRef,
            r.exerciseName,
            _subOf(r.exerciseRef),
            recent: true,
          ),
        );
      }
    }
    out.add(const _Item.heading(S.pickerAll));
    if (lib == null) {
      out.add(_Item.note(_failed ? S.pickerLoadFailed : S.pickerLoading));
    } else {
      out.addAll(lib.all.map(of));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return Scaffold(
      appBar: AppBar(title: Text(_picks ? S.pickerTitle : S.exerciseListTitle)),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              // Outside the scrolling list, so the box stays in view with the
              // keyboard up.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _query,
                  autofocus: _picks,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() => _message = null),
                  decoration: const InputDecoration(
                    labelText: S.pickerSearch,
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final c in S.pickerChips)
                        FilterChip(
                          label: Text(c),
                          selected: _group == c,
                          onSelected: (on) =>
                              setState(() => _group = on ? c : null),
                        ),
                    ],
                  ),
                ),
              ),
              if (_message != null) ConfirmBar(message: _message!),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _row(context, items[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _Item item) {
    final theme = Theme.of(context);
    switch (item.kind) {
      case _Kind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Semantics(
            header: true,
            child: Text(item.text, style: theme.textTheme.titleMedium),
          ),
        );
      case _Kind.note:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(item.text),
        );
      case _Kind.create:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _create,
            child: Text(item.text, textAlign: TextAlign.center),
          ),
        );
      case _Kind.exercise:
        final inWorkout =
            widget.alreadyIn.contains(item.ref) || _added.contains(item.ref);
        return Row(
          key: ValueKey('${item.recent ? 'recent' : 'row'}-${item.ref}'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                label: S.pickerOpenSpoken(item.text, item.sub),
                excludeSemantics: true,
                onTap: () => _openDetail(item.ref, item.text),
                child: InkWell(
                  onTap: () => _openDetail(item.ref, item.text),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.text,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (item.sub.isNotEmpty)
                            Text(
                              item.sub,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_picks) ...[
              const SizedBox(width: 8),
              if (inWorkout)
                Semantics(
                  container: true,
                  label: S.pickerAddedSpoken(item.text),
                  excludeSemantics: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 72,
                      minHeight: 48,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: 18),
                        SizedBox(width: 4),
                        Text(S.pickerAdded),
                      ],
                    ),
                  ),
                )
              else
                Semantics(
                  container: true,
                  button: true,
                  label: S.pickerAddSpoken(item.text),
                  excludeSemantics: true,
                  onTap: () => _add(item.ref, item.text),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(72, 48),
                    ),
                    onPressed: () => _add(item.ref, item.text),
                    child: const Text(S.pickerAdd),
                  ),
                ),
            ],
          ],
        );
    }
  }
}
