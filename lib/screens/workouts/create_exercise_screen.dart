// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/exercise_library.dart';
import '../../strings.dart';
import '../food/confirm_bar.dart';
import '../my_foods/food_editor.dart' show popRouteOf;

/// The short form behind "Create ... as your own exercise" (routine-editor.html
/// frame 2 note): name, primary and secondary muscles, equipment. Closes with
/// the exercise as it was read back, or with nothing.
class CreateExerciseScreen extends StatefulWidget {
  const CreateExerciseScreen({
    super.key,
    required this.library,
    this.initialName = '',
  });

  final ExerciseLibrary library;
  final String initialName;

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  late final _name = TextEditingController(text: widget.initialName.trim());
  final _equipment = TextEditingController();
  final _primary = <String>{};
  final _secondary = <String>{};
  String? _nameError;
  String? _failure;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _equipment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _nameError = null;
      _failure = null;
    });
    final scope = AppScope.of(context);
    final names = exerciseMuscleNames;
    try {
      final made = await scope.db.createExercise(
        widget.library,
        _name.text,
        // In the library's own order.
        primary: [
          for (final m in names)
            if (_primary.contains(m)) m,
        ],
        secondary: [
          for (final m in names)
            if (_secondary.contains(m)) m,
        ],
        equipment: _equipment.text,
      );
      if (!mounted) return;
      popRouteOf<LibraryExercise>(context, made);
    } on ExerciseRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _nameError = e.problem == ExerciseProblem.blankName
            ? S.problemExerciseBlank
            : S.problemExerciseSame;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = S.createExerciseFailed;
        });
      }
    }
  }

  /// A muscle is primary or secondary, never both: choosing it here clears it
  /// from [other].
  Widget _muscles(String title, Set<String> chosen, Set<String> other) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final m in exerciseMuscleNames)
              FilterChip(
                // Wraps rather than fades, for a long name on a narrow screen.
                label: Text(m, softWrap: true, maxLines: 3),
                selected: chosen.contains(m),
                onSelected: (on) => setState(() {
                  if (on) {
                    chosen.add(m);
                    other.remove(m);
                  } else {
                    chosen.remove(m);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.createExerciseTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: S.createExerciseName,
                        errorText: _nameError,
                        errorMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    _muscles(S.createExercisePrimary, _primary, _secondary),
                    _muscles(S.createExerciseSecondary, _secondary, _primary),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _equipment,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: S.createExerciseEquipment,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_failure != null) ConfirmBar(message: _failure!),
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
                      onPressed: _busy ? null : _save,
                      child: const Text(S.createExerciseSave),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
