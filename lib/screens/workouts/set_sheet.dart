// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/workout_data.dart';
import '../../strings.dart';
import '../../util/insets.dart';
import '../../util/units.dart';
import '../my_foods/food_editor.dart'
    show foodNumberProblem, parseFoodNumber, popRouteOf;
import 'workout_widgets.dart';

/// Which number the sheet puts the cursor in.
enum SetField { weight, reps }

/// Opens the adjust sheet for one set of a running workout (workout.html frame
/// 4): -5 and +5 lb (-2.5 and +2.5 kg), -1 and +1 reps, either number typed,
/// Remove set and Done. The sheet writes through the data layer itself, so a
/// closed sheet has already saved; the workout screen sees the change in its
/// own stream. Returns the set it removed, if Remove set was used, so the
/// workout screen can offer Undo. [notice] is a plain sentence shown at the top (the check was
/// tapped on a set with no reps).
Future<RemovedSets?> showSetSheet(
  BuildContext context, {
  required SetView set,
  required String exerciseName,
  required int number,
  required UnitSystem units,
  SetField focus = SetField.weight,
  String? notice,
}) async {
  if (_sheetOpen) return null;
  _sheetOpen = true;
  try {
    return await showModalBottomSheet<RemovedSets>(
      context: context,
      isScrollControlled: true,
      // A drag would close the sheet while a write is in flight; PopScope in
      // the sheet covers back and the scrim.
      enableDrag: false,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => _SetSheet(
        set: set,
        exerciseName: exerciseName,
        number: number,
        units: units,
        focus: focus,
        notice: notice,
      ),
    );
  } finally {
    _sheetOpen = false;
  }
}

/// True from the request until the sheet is gone, so a fast double tap opens
/// one sheet. The sheet also clears it when it leaves the tree.
bool _sheetOpen = false;

class _SetSheet extends StatefulWidget {
  const _SetSheet({
    required this.set,
    required this.exerciseName,
    required this.number,
    required this.units,
    required this.focus,
    required this.notice,
  });

  final SetView set;
  final String exerciseName;
  final int number;
  final UnitSystem units;
  final SetField focus;
  final String? notice;

  @override
  State<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends State<_SetSheet> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  late final String _startWeightText;
  late final FocusNode _weightFocus = FocusNode();
  late final FocusNode _repsFocus = FocusNode();

  String? _weightError;
  String? _repsError;
  String? _failure;
  late String? _notice = widget.notice;
  var _saving = false;

  WorkoutSet get _row => widget.set.row;
  double get _step => widget.units == UnitSystem.imperial ? 5 : 2.5;

  @override
  void initState() {
    super.initState();
    final w = _row.weightKg;
    _startWeightText = w == null ? '' : setWeightText(w, widget.units);
    _weight = TextEditingController(text: _startWeightText);
    _reps = TextEditingController(
      text: _row.reps == null ? '' : '${_row.reps}',
    );
    final first = widget.focus == SetField.reps ? _repsFocus : _weightFocus;
    final text = widget.focus == SetField.reps ? _reps : _weight;
    text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) first.requestFocus();
    });
  }

  @override
  void dispose() {
    _sheetOpen = false;
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  void _typed() => setState(() {
    _weightError = null;
    _repsError = null;
    _failure = null;
    _notice = null;
  });

  String _trim(double v) {
    final t = v.toStringAsFixed(1);
    return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
  }

  void _stepWeight(int direction) {
    final text = _weight.text.trim();
    final current = text.isEmpty ? 0.0 : parseFoodNumber(text);
    if (current == null) {
      setState(() => _weightError = foodNumberProblem(text, S.setWeightBad));
      return;
    }
    final next = roundToTenth(current + direction * _step);
    setState(() {
      _weight.text = _trim(next < 0 ? 0 : next);
      _weightError = null;
      _failure = null;
      _notice = null;
    });
  }

  void _stepReps(int direction) {
    final text = _reps.text.trim();
    final current = text.isEmpty ? 0 : int.tryParse(text);
    if (current == null) {
      setState(() => _repsError = S.setRepsBad);
      return;
    }
    final next = current + direction;
    setState(() {
      _reps.text = '${next < 1 ? 1 : next}';
      _repsError = null;
      _failure = null;
      _notice = null;
    });
  }

  Future<void> _done() async {
    if (_saving) return;
    // The weight is only converted when it was changed, so a weight that was
    // stored as 79.4 kg stays 79.4 kg when only the reps change.
    final weightText = _weight.text.trim();
    double? weightKg = _row.weightKg;
    String? weightError;
    if (weightText != _startWeightText) {
      if (weightText.isEmpty) {
        weightKg = null;
      } else {
        final v = parseFoodNumber(weightText);
        if (v == null) {
          weightError = foodNumberProblem(weightText, S.setWeightBad);
        } else {
          weightKg = weightToKg(roundToTenth(v), widget.units);
        }
      }
    }
    final repsText = _reps.text.trim();
    int? reps;
    String? repsError;
    if (repsText.isNotEmpty) {
      reps = int.tryParse(repsText);
      if (reps == null) repsError = S.setRepsBad;
    }
    if (weightError != null || repsError != null) {
      setState(() {
        _weightError = weightError;
        _repsError = repsError;
        _notice = null;
      });
      return;
    }
    final scope = AppScope.of(context);
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await scope.db.adjustSet(_row.id, weightKg: weightKg, reps: reps);
      if (!mounted) return;
      popRouteOf<void>(context, null);
    } on WorkoutRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.problem == WorkoutProblem.needsReps) {
          _repsError = S.loggedSetNeedsReps;
        } else {
          _failure = workoutProblemText(e.problem);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = S.workoutSaveFailed;
      });
    }
  }

  Future<void> _remove() async {
    if (_saving) return;
    final scope = AppScope.of(context);
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final removed = await scope.db.removeSet(_row.id);
      if (!mounted) return;
      popRouteOf<RemovedSets?>(context, removed);
    } on WorkoutRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = workoutProblemText(e.problem);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = S.workoutSaveFailed;
      });
    }
  }

  Widget _stepper(String label, String spoken, VoidCallback onTap) {
    return Semantics(
      container: true,
      button: true,
      label: spoken,
      excludeSemantics: true,
      onTap: _saving ? null : onTap,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(56, 56)),
        onPressed: _saving ? null : onTap,
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = widget.units;
    final unit = S.unitWord(units);
    final prev = widget.set.previous;
    final stepText = _trim(_step);
    final error = TextStyle(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.bold,
    );
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset(context)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  S.setSheetTitle(widget.exerciseName, widget.number),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (prev != null)
                Text(
                  S.setSheetLast(
                    setWeightText(prev.weightKg ?? 0, units),
                    unit,
                    prev.weightKg == null,
                    prev.reps ?? 0,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_notice!, style: error),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepper(
                    '-$stepText',
                    S.setTakeOffWeight(stepText, unit),
                    () => _stepWeight(-1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _weight,
                      focusNode: _weightFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                      decoration: InputDecoration(
                        labelText: S.setWeightLabel,
                        hintText: S.bodyWeight,
                        suffixText: unit,
                        errorText: _weightError,
                        errorMaxLines: 4,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => _typed(),
                      onSubmitted: (_) => _repsFocus.requestFocus(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _stepper(
                    '+$stepText',
                    S.setAddWeight(stepText, unit),
                    () => _stepWeight(1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepper('-1', S.setTakeOffRep, () => _stepReps(-1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _reps,
                      focusNode: _repsFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                      decoration: InputDecoration(
                        labelText: S.setRepsLabel,
                        errorText: _repsError,
                        errorMaxLines: 4,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => _typed(),
                      onSubmitted: (_) => _done(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _stepper('+1', S.setAddRep, () => _stepReps(1)),
                ],
              ),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_failure!, style: error),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 56),
                    ),
                    onPressed: _saving ? null : _remove,
                    child: const Text(S.setRemove),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 56),
                    ),
                    onPressed: _saving ? null : _done,
                    child: const Text(S.setSheetDone),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
