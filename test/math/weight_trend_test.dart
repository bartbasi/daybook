// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/math/weight_trend.dart';
import 'package:flutter_test/flutter_test.dart';

DayWeight w(String date, double kg) => (localDate: date, kg: kg);

void main() {
  test('no weigh-ins give no trend', () {
    expect(weightTrend([]), isEmpty);
  });

  test("the first day's trend is that day's average", () {
    final t = weightTrend([w('2026-11-01', 80)]);
    expect(t, hasLength(1));
    expect(t.single.trendKg, 80);
    expect(t.single.averageKg, 80);
  });

  test('the trend moves 10 percent toward each new day', () {
    final t = weightTrend([
      w('2026-11-01', 80),
      w('2026-11-02', 82),
      w('2026-11-03', 78),
    ]);
    expect(t[1].trendKg, closeTo(80.2, 1e-9));
    expect(t[2].trendKg, closeTo(80.2 + 0.1 * (78 - 80.2), 1e-9));
  });

  test('several weigh-ins in a day are averaged first', () {
    final t = weightTrend([
      w('2026-11-01', 80),
      w('2026-11-02', 81),
      w('2026-11-02', 83),
      w('2026-11-02', 82),
    ]);
    expect(t[1].averageKg, closeTo(82, 1e-9));
    expect(t[1].trendKg, closeTo(80.2, 1e-9));
  });

  test('days with no weigh-in change nothing', () {
    final gap = weightTrend([w('2026-11-01', 80), w('2026-11-20', 82)]);
    final next = weightTrend([w('2026-11-01', 80), w('2026-11-02', 82)]);
    expect(gap, hasLength(2));
    expect(gap[1].trendKg, next[1].trendKg);
  });

  test('input order does not matter', () {
    final a = weightTrend([w('2026-11-03', 78), w('2026-11-01', 80)]);
    final b = weightTrend([w('2026-11-01', 80), w('2026-11-03', 78)]);
    expect([for (final p in a) p.trendKg], [for (final p in b) p.trendKg]);
    expect(a.first.localDate, '2026-11-01');
  });

  test('a steady weight keeps the trend at that weight', () {
    final t = weightTrend([for (var d = 1; d <= 9; d++) w('2026-11-0$d', 75)]);
    expect(t.last.trendKg, closeTo(75, 1e-9));
  });
}
