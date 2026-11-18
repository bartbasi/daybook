// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import 'exercise_detail.dart';
import 'exercise_picker.dart';
import 'routine_editor.dart';
import 'seams.dart';
import 'weekly_volume_screen.dart';

/// Fills the five seams the Workouts tab and the active workout use, so the
/// controls that were hidden appear. main() calls it once before the app runs;
/// a test that wants the real screens calls it too, and clears the seams in
/// tearDown.
void installWorkoutSeams() {
  WorkoutSeams.exercisePicker = openExercisePicker;
  WorkoutSeams.exerciseDetail = (context, ref) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exerciseRef: ref)),
    );
  };
  WorkoutSeams.routineEditor = openRoutineEditor;
  WorkoutSeams.exercises = openExerciseList;
  WorkoutSeams.weeklyVolume = (context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const WeeklyVolumeScreen()));
  };
}

/// Clears the seams again (for tests).
void clearWorkoutSeams() {
  WorkoutSeams.exercisePicker = null;
  WorkoutSeams.exerciseDetail = null;
  WorkoutSeams.routineEditor = null;
  WorkoutSeams.exercises = null;
  WorkoutSeams.weeklyVolume = null;
}
