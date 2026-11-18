// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/workout_data.dart';
import '../../math/training.dart';
import '../../strings.dart';
import '../../util/units.dart';

// Small pieces the workout screens share. Only showing numbers here: every
// training number is worked out by the data layer or lib/math/training.dart.

/// A stored weight in the user's unit as typed on a set: '175', '175.5'. No
/// unit word.
String setWeightText(double kg, UnitSystem units) {
  final t = formatWeight(kg, units);
  return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
}

/// A volume or any weight total, whole in the user's unit: '10,540'.
String volumeText(double kg, UnitSystem units) =>
    S.count(kgToWeight(kg, units).round());

/// An estimated one-rep max as shown: whole pounds, or kilograms to a tenth.
String oneRepMaxText(double kgOrLb, UnitSystem units) {
  final v = roundOneRepMaxForDisplay(kgOrLb, units);
  return units == UnitSystem.imperial
      ? S.count(v.round())
      : v.toStringAsFixed(1);
}

/// Whole minutes in a length, rounded to the nearest minute.
int minutesIn(int ms) => (ms / 60000).round();

/// '175 x 8' or 'body weight x 8', for last time and for "Changed, from".
String setValuesText(SetValues v, UnitSystem units) {
  final w = v.weightKg;
  final weight = w == null ? S.bodyWeightLower : setWeightText(w, units);
  return '$weight x ${v.reps ?? 0}';
}

/// A refused change in plain words.
String workoutProblemText(WorkoutProblem p) => switch (p) {
  WorkoutProblem.anotherIsRunning => S.problemAnotherRunning,
  WorkoutProblem.notRunning => S.problemNotRunning,
  WorkoutProblem.needsReps => S.problemNeedsReps,
  WorkoutProblem.badNumber => S.problemBadNumber,
  WorkoutProblem.blankName => S.routineBlankName,
  WorkoutProblem.duplicateExercise => S.problemDuplicate,
  WorkoutProblem.loggedSetsInExercise => S.problemLoggedSets,
};

/// Rebuilds [builder] every 20 seconds, so "23 min" on a running workout moves
/// on while the screen stays open.
class MinuteTick extends StatefulWidget {
  const MinuteTick({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<MinuteTick> createState() => _MinuteTickState();
}

class _MinuteTickState extends State<MinuteTick> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The top of a workout screen: back, a title and one line under it, and
/// something at the end. It grows with the text size.
class WorkoutHeader extends StatelessWidget {
  const WorkoutHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // At large text the action drops under the title, so the title keeps the
    // width it needs instead of breaking inside words.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final titles = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall),
          if (stacked && trailing != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: trailing),
        ],
      ),
    );
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showBack) const BackButton() else const SizedBox(width: 16),
            Expanded(child: titles),
            if (!stacked && trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: trailing,
              ),
            if (stacked) const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// A short label in an outline: a word and a shape, never color alone.
class WorkoutBadge extends StatelessWidget {
  const WorkoutBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.onSurface, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
