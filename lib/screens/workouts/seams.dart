// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/widgets.dart';

// The seams between task 4.3 (the Workouts tab and the active workout) and
// task 4.4 (the routine editor, the exercise picker, exercise detail and the
// weekly volume screen). Each one is empty until task 4.4 fills it in. While
// a seam is empty, the control that would use it is not shown at all, so
// there is never a button that does nothing.
//
// Task 4.4 sets these once, before the app runs (or in its own screens' init),
// and deletes this file when it calls its screens directly.

/// What the picker calls for each exercise the user adds or picks. It returns
/// null when it worked, or a plain sentence to show when it did not.
typedef PickExercise = Future<String?> Function(String ref, String name);

/// Opens the exercise picker over the workout. It stays open after each Add and
/// calls [onPick] each time; [alreadyIn] holds the refs already in the workout
/// so the picker can show them as added. With [single] it picks one exercise
/// (Replace exercise) and closes after [onPick] answers null. Completes when
/// the picker closes.
typedef ExercisePicker = Future<void> Function(
  BuildContext context, {
  required PickExercise onPick,
  required Set<String> alreadyIn,
  bool single,
});

abstract final class WorkoutSeams {
  /// "+ Add exercise" in the active workout (and Replace exercise, which picks
  /// one exercise). Null until task 4.4.
  static ExercisePicker? exercisePicker;

  /// "Exercise details" in an exercise's menu, given its ref. Null until task
  /// 4.4.
  static void Function(BuildContext context, String exerciseRef)?
  exerciseDetail;

  /// "+ New routine", and editing a routine when [routineId] is given. Null
  /// until task 4.4.
  static void Function(BuildContext context, {int? routineId})? routineEditor;

  /// The "Exercises" button on the Workouts tab (the exercise list). Null
  /// until task 4.4.
  static void Function(BuildContext context)? exercises;

  /// A tap on "This week, sets by muscle" opens the weekly volume screen. Null
  /// until task 4.4.
  static void Function(BuildContext context)? weeklyVolume;
}
