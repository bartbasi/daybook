// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import '../util/dates.dart';
import '../util/units.dart';

// Resistance training maths. Pure functions: no database, no Flutter. Every
// number keeps full precision. Only a number meant to be shown goes through
// [roundOneRepMaxForDisplay] (and, for calories, roundForDisplay in
// calorie_budget.dart), so a rounded number can never leak into a later step.

/// The one place an estimated one-rep max is rounded for showing: a whole
/// number in pounds ("228 lb"), one decimal in kilograms. The value is first
/// rounded to 8 decimals so float noise (228.00000000000003) cannot matter.
double roundOneRepMaxForDisplay(double value, UnitSystem units) {
  final v = (value * 1e8).roundToDouble() / 1e8;
  return units == UnitSystem.imperial ? v.roundToDouble() : roundToTenth(v);
}

/// The reps that count toward an estimated one-rep max, inclusive.
const oneRepMaxMinReps = 1;
const oneRepMaxMaxReps = 12;

/// The Epley estimated one-rep max: weight x (1 + reps / 30).
///
/// Only sets of 1 to 12 reps are estimated; any other rep count, and a weight
/// that is not above zero (a body weight set), has no estimate and returns
/// null. The result is in the same unit as [weight], so 180 lb for 8 reps
/// gives 228 lb. At 1 rep the formula gives 1.033 x the weight, as written.
double? estimatedOneRepMax(double weight, int reps) {
  if (reps < oneRepMaxMinReps || reps > oneRepMaxMaxReps) return null;
  if (!weight.isFinite || weight <= 0) return null;
  return weight * (1 + reps / 30);
}

/// [estimatedOneRepMax] for a stored weight in kilograms, answered in the
/// user's unit with one conversion at the end (the formula is linear, so
/// converting the answer equals converting the weight first).
double? estimatedOneRepMaxIn(double weightKg, int reps, UnitSystem units) {
  final kg = estimatedOneRepMax(weightKg, reps);
  if (kg == null) return null;
  return units == UnitSystem.imperial ? kgToLb(kg) : kg;
}

/// One completed set, for records. [atMs] is when it was completed and [id]
/// breaks a tie between sets completed in the same millisecond.
class DoneSet {
  const DoneSet({
    required this.weightKg,
    required this.reps,
    required this.atMs,
    this.id = 0,
  });

  /// Null for a body weight set.
  final double? weightKg;
  final int? reps;
  final int atMs;
  final int id;

  /// This set came before [other].
  bool isBefore(DoneSet other) =>
      atMs != other.atMs ? atMs < other.atMs : id < other.id;

  /// A weight above zero and at least one rep: a set that can be a record.
  bool get hasWeightAndReps =>
      (weightKg ?? 0) > 0 && (reps ?? 0) >= 1 && weightKg!.isFinite;

  /// The Epley estimate for this set in kilograms, or null.
  double? get estimateKg {
    final w = weightKg, r = reps;
    if (w == null || r == null) return null;
    return estimatedOneRepMax(w, r);
  }
}

/// An estimate is only better when it beats the best by more than float noise.
const _estimateTolerance = 1e-9;

/// The records of one exercise: the heaviest weight and the best estimated
/// one-rep max, each with the set it came from. When sets tie, the one done
/// first holds the record.
class Records {
  const Records({this.heaviest, this.bestEstimate});

  final DoneSet? heaviest;
  final DoneSet? bestEstimate;

  /// The best estimate in kilograms, or null.
  double? get bestEstimateKg => bestEstimate?.estimateKg;
}

/// The records over [sets]. Sets with no weight (body weight) or no reps are
/// ignored. A set only counts toward the estimate with 1 to 12 reps.
Records recordsOf(Iterable<DoneSet> sets) {
  DoneSet? heaviest;
  DoneSet? best;
  for (final s in sets) {
    if (!s.hasWeightAndReps) continue;
    final h = heaviest;
    if (h == null ||
        s.weightKg! > h.weightKg! ||
        (s.weightKg! == h.weightKg! && s.isBefore(h))) {
      heaviest = s;
    }
    final e = s.estimateKg;
    if (e == null) continue;
    final b = best;
    if (b == null) {
      best = s;
      continue;
    }
    final be = b.estimateKg!;
    final clearlyBetter = e > be + _estimateTolerance * be;
    final tied = (e - be).abs() <= _estimateTolerance * be;
    if (clearlyBetter || (tied && s.isBefore(b))) best = s;
  }
  return Records(heaviest: heaviest, bestEstimate: best);
}

/// Whether a just-logged set beat the exercise's records.
class RecordCheck {
  const RecordCheck({this.heaviest = false, this.estimate = false});

  static const none = RecordCheck();

  /// Heavier than every set before it.
  final bool heaviest;

  /// A better estimated one-rep max than every set before it.
  final bool estimate;

  bool get any => heaviest || estimate;
}

/// Whether [set] is a new record given the sets done [before] it. A tie is not
/// a record. With nothing before it to beat (the first set ever, or only body
/// weight sets before), it is not a record either: "beats the best" needs a
/// best.
RecordCheck checkRecord(Iterable<DoneSet> before, DoneSet set) {
  if (!set.hasWeightAndReps) return RecordCheck.none;
  final r = recordsOf(before);
  final h = r.heaviest;
  final e = r.bestEstimateKg;
  final mine = set.estimateKg;
  return RecordCheck(
    heaviest: h != null && set.weightKg! > h.weightKg!,
    estimate: e != null && mine != null && mine > e + _estimateTolerance * e,
  );
}

/// [checkRecord] against every set in [all] that was done before [set]. [all]
/// may include [set] itself and sets done after it.
RecordCheck recordFor(DoneSet set, Iterable<DoneSet> all) =>
    checkRecord(all.where((s) => s.isBefore(set)), set);

/// Weight x reps added up, in kilograms. Sets with no weight or no reps add
/// nothing.
double totalVolumeKg(Iterable<DoneSet> sets) {
  var total = 0.0;
  for (final s in sets) {
    if (s.hasWeightAndReps) total += s.weightKg! * s.reps!;
  }
  return total;
}

/// A completed set for weekly volume: the day of its workout and the primary
/// muscles of its exercise (the caller looks them up; this file never does).
typedef VolumeSet = ({String localDate, Iterable<String> muscles});

/// Completed sets per primary muscle in the week (Monday to Sunday) that
/// contains [dayInWeek]. A set counts once for each primary muscle of its
/// exercise. The week is found with the date helpers, which work on calendar
/// dates, so a daylight saving change cannot move a set to another week.
/// Muscles with no sets are not in the result.
Map<String, int> setsPerMuscle(Iterable<VolumeSet> sets, String dayInWeek) {
  final monday = mondayOf(dayInWeek);
  final sunday = addDays(monday, 6);
  final out = <String, int>{};
  for (final s in sets) {
    // 'YYYY-MM-DD' strings sort the same as the dates.
    if (s.localDate.compareTo(monday) < 0 ||
        s.localDate.compareTo(sunday) > 0) {
      continue;
    }
    for (final m in s.muscles.toSet()) {
      out[m] = (out[m] ?? 0) + 1;
    }
  }
  return out;
}

/// The MET value for resistance training decided in Phase 3 (Compendium of
/// Physical Activities, 2024, code 02054).
const resistanceMet = 3.5;

/// Calories of a workout: MET x body weight in kilograms x hours, with hours
/// being the finish time minus the start time (workout.html, frame 6:
/// 3.5 x 181.8 lb x 52 min is about 250 kcal). Full precision; round with
/// roundForDisplay to show. A duration of zero or less gives 0.
double workoutKcal({required double bodyWeightKg, required int durationMs}) {
  if (durationMs <= 0) return 0;
  return resistanceMet * bodyWeightKg * (durationMs / 3600000);
}
