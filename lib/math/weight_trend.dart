// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

/// One weigh-in: the local date it counts for and the weight in kilograms.
typedef DayWeight = ({String localDate, double kg});

class TrendPoint {
  const TrendPoint(this.localDate, this.averageKg, this.trendKg);

  final String localDate;

  /// The average of that day's weigh-ins.
  final double averageKg;

  /// The trend after that day.
  final double trendKg;
}

const _step = 0.1;

/// The trend, one point per day that has a weigh-in, oldest first.
///
/// Each day's weigh-ins are averaged. The first day's trend is its average;
/// after that the trend moves 10% of the way toward each day's average. Days
/// with no weigh-in have no point and change nothing, so the trend on any day
/// is the trend of the latest point on or before it.
List<TrendPoint> weightTrend(Iterable<DayWeight> weighIns) {
  final sums = <String, double>{};
  final counts = <String, int>{};
  for (final w in weighIns) {
    sums[w.localDate] = (sums[w.localDate] ?? 0) + w.kg;
    counts[w.localDate] = (counts[w.localDate] ?? 0) + 1;
  }
  final days = sums.keys.toList()..sort();
  final points = <TrendPoint>[];
  double? trend;
  for (final d in days) {
    final avg = sums[d]! / counts[d]!;
    trend = trend == null ? avg : trend + _step * (avg - trend);
    points.add(TrendPoint(d, avg, trend));
  }
  return points;
}
