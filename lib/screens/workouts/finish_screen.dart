// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/goal_data.dart';
import '../../data/settings_data.dart';
import '../../data/workout_data.dart';
import '../../math/calorie_budget.dart';
import '../../math/training.dart';
import '../../strings.dart';
import '../../util/units.dart';
import '../my_foods/food_editor.dart'
    show foodNumberProblem, parseFoodNumber, popRouteOf;
import 'workout_widgets.dart';

/// What the finish screen hands back when it closes.
enum FinishOutcome { done, resumed }

class _Read {
  const _Read({
    required this.result,
    required this.title,
    required this.units,
    required this.weight,
    required this.addBackPercent,
    required this.today,
  });

  final WorkoutResult result;
  final String title;
  final UnitSystem units;

  /// The weigh-in the estimate was worked out from, or null.
  final WeightEntry? weight;

  /// The add-back of the workout's day, or null before any goals exist.
  final int? addBackPercent;
  final String today;
}

/// The summary right after Finish (workout.html frame 6). Finish has already
/// ended the workout, with no "are you sure". Resume reopens it. Everything
/// shown is read from the database: the numbers are the data layer's.
class FinishScreen extends StatefulWidget {
  const FinishScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  _Read? _read;
  var _failed = false;
  var _loadedOnce = false;
  var _busy = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedOnce) return;
    _loadedOnce = true;
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final db = scope.db;
    try {
      final result = await db.workoutResult(widget.workoutId);
      final view = await db.loadWorkout(widget.workoutId);
      final units = await db.getUnits();
      final day = result.workout.localDate;
      final weight = await db.weightOnOrBefore(day);
      final goals = await db.goalsForDay(day);
      final name = view?.routineName;
      final names = [
        for (final e in view?.exercises ?? const <ExerciseBlock>[])
          e.exerciseName,
      ];
      final title =
          name ??
          (names.isEmpty ? S.workoutDefaultName : S.exercisesInBrief(names, 2));
      if (!mounted) return;
      setState(() {
        _failed = false;
        _read = _Read(
          result: result,
          title: title,
          units: units,
          weight: weight,
          addBackPercent: goals?.addBackPercent,
          today: scope.clock().localDate,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _resume() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r = await AppScope.of(context).db.resumeWorkout(widget.workoutId);
      if (!mounted) return;
      if (r.started) {
        popRouteOf<FinishOutcome>(context, FinishOutcome.resumed);
      } else {
        setState(() {
          _busy = false;
          _message = S.resumeRefused;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = S.workoutSaveFailed;
        });
      }
    }
  }

  void _done() {
    if (_busy) return;
    setState(() => _busy = true);
    popRouteOf<FinishOutcome>(context, FinishOutcome.done);
  }

  Future<void> _change(_Read read) async {
    final w = read.result.workout;
    final shown = w.kcalOverride ?? w.kcalEstimated;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => _KcalSheet(
        workoutId: widget.workoutId,
        start: shown == null ? '' : '${roundForDisplay(shown)}',
        hasOwn: w.kcalOverride != null,
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final read = _read;
    return Scaffold(
      body: Column(
        children: [
          WorkoutHeader(
            showBack: false,
            title: S.finishTitle,
            subtitle: read == null
                ? null
                : S.finishSub(
                    read.title,
                    S.dayShort(read.result.workout.localDate, read.today),
                  ),
          ),
          Expanded(
            child: read == null
                ? Center(
                    child: _failed
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(S.finishLoadFailed),
                          )
                        : const CircularProgressIndicator(),
                  )
                : _Body(read: read, onChange: () => _change(read)),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: read == null || _busy ? null : _resume,
                      child: const Text(S.resume),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 56),
                      ),
                      onPressed: _busy ? null : _done,
                      child: const Text(S.finishDone),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.read, required this.onChange});

  final _Read read;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = read.result;
    final units = read.units;
    final unit = S.unitWord(units);
    final w = r.workout;
    final own = w.kcalOverride;
    final estimate = w.kcalEstimated;
    final shown = own ?? estimate;
    final minutes = r.durationMs == null ? 0 : minutesIn(r.durationMs!);
    final weight = read.weight;

    Widget stat(String label, String value, {String? small}) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Semantics(
          container: true,
          label: '$label, $value${small == null ? '' : ' $small'}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Text(value, style: theme.textTheme.headlineSmall),
              if (small != null) Text(small, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    String? basis;
    if (estimate != null && weight != null) {
      basis = S.finishBasis(
        '$resistanceMet',
        formatWeight(weight.weightKg, units),
        unit,
        weight.localDate == w.localDate
            ? null
            : S.monthDay(weight.localDate, read.today),
        minutes,
      );
    }

    return ContentWidth(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (r.removedPlannedSets > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const WorkoutBadge(S.plannedBadge),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(S.plannedNotLogged(r.removedPlannedSets)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                stat(S.finishTime, S.minutesShort(minutes)),
                stat(S.finishSets, '${r.setCount}'),
                stat(
                  S.finishVolume,
                  volumeText(r.volumeKg, units),
                  small: unit,
                ),
              ],
            ),
            if (r.newRecords.isNotEmpty) ...[
              heading(S.finishRecords),
              for (final b in r.newRecords)
                _RecordCard(record: b, units: units),
            ],
            heading(S.finishCalories),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: shown == null
                      ? const Text(S.finishNoEstimate)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: S.kcal(
                                      roundForDisplay(shown).toDouble(),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' ${own == null ? S.finishEstimateWord : S.finishOwnWord}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (own != null && estimate != null)
                              Text(
                                S.finishEstimateWas(
                                  S.kcal(roundForDisplay(estimate).toDouble()),
                                ),
                                style: theme.textTheme.bodySmall,
                              )
                            else if (basis != null)
                              Text(basis, style: theme.textTheme.bodySmall),
                          ],
                        ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onChange,
                  child: const Text(S.change),
                ),
              ],
            ),
            if (shown == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(S.finishNoEstimateWhy),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  read.addBackPercent == null
                      ? S.finishNoGoals
                      : S.finishAdded(
                          S.dayWord(w.localDate, read.today),
                          read.addBackPercent!,
                        ),
                ),
              ),
            if (r.removedPlannedSets == 0) ...[
              heading(S.plannedTitle),
              const Text(S.plannedNone),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.units});

  final RecordBreak record;
  final UnitSystem units;

  double _in(double kg) => units == UnitSystem.imperial ? kgToLb(kg) : kg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = S.unitWord(units);
    final heaviest = record.heaviest;
    final estimate = record.estimate;
    final top = heaviest ?? estimate!;
    final topWeight = top.weightKg ?? 0;
    final estimateNow = estimate == null
        ? null
        : estimatedOneRepMaxIn(estimate.weightKg!, estimate.reps!, units);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.onSurface, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.recordTitle(
                record.exerciseName,
                setWeightText(topWeight, units),
                unit,
                top.reps ?? 0,
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (heaviest != null)
              Text(
                S.recordHeaviest(
                  setWeightText(heaviest.weightKg ?? 0, units),
                  unit,
                  record.heaviestWasKg == null
                      ? null
                      : setWeightText(record.heaviestWasKg!, units),
                ),
              ),
            if (estimateNow != null)
              Text(
                S.recordEstimate(
                  oneRepMaxText(estimateNow, units),
                  unit,
                  record.estimateWasKg == null
                      ? null
                      : oneRepMaxText(_in(record.estimateWasKg!), units),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The number box behind "Change": the user's own calories for this workout.
class _KcalSheet extends StatefulWidget {
  const _KcalSheet({
    required this.workoutId,
    required this.start,
    required this.hasOwn,
  });

  final int workoutId;
  final String start;
  final bool hasOwn;

  @override
  State<_KcalSheet> createState() => _KcalSheetState();
}

class _KcalSheetState extends State<_KcalSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.start)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.start.length,
        );
  String? _error;
  String? _failure;
  var _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _write(double? value) async {
    final db = AppScope.of(context).db;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await db.setWorkoutKcal(widget.workoutId, value);
      if (!mounted) return;
      popRouteOf<bool>(context, true);
    } on WorkoutRefused {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = S.kcalNegative;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = S.workoutSaveFailed;
      });
    }
  }

  void _save() {
    if (_saving) return;
    final t = _text.text.trim();
    if (!widget.hasOwn && t == widget.start) {
      // The estimate, untouched: it is not the user's own number, so nothing
      // is written (a written number would stop the estimate following a
      // Resume).
      popRouteOf<bool>(context, false);
      return;
    }
    if (t.startsWith('-')) {
      setState(() => _error = S.kcalNegative);
      return;
    }
    final v = parseFoodNumber(t);
    if (t.isEmpty || v == null) {
      setState(() => _error = foodNumberProblem(t, S.kcalBad));
      return;
    }
    _write(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(S.kcalTitle, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                ],
                decoration: InputDecoration(
                  labelText: S.kcalField,
                  suffixText: S.kcalUnit,
                  errorText: _error,
                  errorMaxLines: 4,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {
                  _error = null;
                  _failure = null;
                }),
                onSubmitted: (_) => _save(),
              ),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _failure!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  if (widget.hasOwn)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: _saving ? null : () => _write(null),
                      child: const Text(S.kcalUseEstimate),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 56),
                    ),
                    onPressed: _saving ? null : _save,
                    child: const Text(S.save),
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
