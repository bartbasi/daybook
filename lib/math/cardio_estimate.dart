// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import '../util/units.dart';

// Cardio maths. Pure functions: no database, no Flutter. Every number keeps
// full precision. Calories are shown with roundForDisplay (calorie_budget.dart)
// and stored unrounded, the same way workoutKcal (training.dart) does it.

/// A speed range in mph as the Compendium writes it (see MetActivity.minMph and
/// maxMph in lib/data/met_table.dart). Both numbers: a closed band, ends
/// included. Only [max] ("less than 2.0 mph", "<10 mph"): every pace below
/// [max], not [max] itself. Only [min] (">20 mph"): every pace above [min],
/// not [min] itself. Neither: holds no pace.
typedef MphRange = ({double? min, double? max});

/// Calories of a cardio session: MET x body weight in kilograms x hours (the
/// gross MET, as the brief words it). 9.3 x 82.46 kg x 0.5 h is 383.45, shown
/// as 383. A duration of zero or less gives 0.
double cardioKcal({
  required double met,
  required double bodyWeightKg,
  required int durationSeconds,
}) {
  if (durationSeconds <= 0) return 0;
  return met * bodyWeightKg * (durationSeconds / 3600);
}

/// Average speed in miles per hour, whatever unit the user types in (the
/// distance is in meters: 1 mi is 1609.344 m exactly). Null when there is no
/// distance (null, 0 or less) or no duration. Rounded to 9 decimals so a pace
/// like exactly 10 mph is 10.0, not 9.999999999999998, and sits on a band edge
/// as written.
double? paceMph({
  required double? distanceMeters,
  required int durationSeconds,
}) {
  final d = distanceMeters;
  if (d == null || !(d > 0) || durationSeconds <= 0) return null;
  return _clean(metersToMiles(d) / (durationSeconds / 3600));
}

double _clean(double v) => (v * 1e9).roundToDouble() / 1e9;

/// The index of the band that holds [mph]. [bands] are slowest first and not
/// empty.
///
/// - A band holds the pace as described on [MphRange]. When two bands hold it
///   (they share a closed edge) the slower one, the first in the list, wins.
/// - In a gap between bands, or below the slowest or above the fastest: the
///   band with the nearest edge. On an exact tie the slower one wins. For an
///   open band ("less than 2.0") the edge is its number.
/// - Nothing is interpolated or blended: the answer is one whole band.
int pickBand(List<MphRange> bands, double mph) {
  if (bands.isEmpty) throw ArgumentError('no bands');
  final p = _clean(mph);
  var best = 0;
  var bestGap = double.infinity;
  for (var i = 0; i < bands.length; i++) {
    final b = bands[i];
    if (_holds(b, p)) return i;
    final gap = _gap(b, p);
    if (gap < bestGap) {
      best = i;
      bestGap = gap;
    }
  }
  return best;
}

bool _holds(MphRange b, double p) {
  final lo = b.min, hi = b.max;
  if (lo != null && hi != null) return p >= lo && p <= hi;
  if (hi != null) return p < hi;
  if (lo != null) return p > lo;
  return false;
}

// How far the pace is from the band's nearest edge (0 on the excluded number
// of an open band). Infinite for a band with no numbers.
double _gap(MphRange b, double p) {
  final lo = b.min, hi = b.max;
  if (lo == null && hi == null) return double.infinity;
  if (lo != null && p < lo) return _clean(lo - p);
  if (hi != null && p > hi) return _clean(p - hi);
  return 0;
}
