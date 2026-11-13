// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/util/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addDays crosses month, year and leap day boundaries', () {
    expect(addDays('2026-12-31', 1), '2027-01-01');
    expect(addDays('2027-01-01', -1), '2026-12-31');
    expect(addDays('2028-02-28', 1), '2028-02-29');
    expect(addDays('2027-02-28', 1), '2027-03-01');
    expect(addDays('2026-11-12', 0), '2026-11-12');
    expect(addDays('2026-01-31', 30), '2026-03-02');
  });

  test('addDays is not moved by a daylight saving change', () {
    // 2026-03-08 has 23 hours in New York; the date maths must not care.
    expect(addDays('2026-03-07', 1), '2026-03-08');
    expect(addDays('2026-03-08', 1), '2026-03-09');
    expect(addDays('2026-11-01', 1), '2026-11-02');
  });

  test('mondayOf returns the Monday on or before the date', () {
    expect(mondayOf('2026-11-12'), '2026-11-09'); // a Thursday
    expect(mondayOf('2026-11-09'), '2026-11-09'); // a Monday
    expect(mondayOf('2026-11-15'), '2026-11-09'); // a Sunday
    expect(mondayOf('2027-01-01'), '2026-12-28'); // across New Year
  });

  test('parseDate and formatDate round trip', () {
    expect(formatDate(parseDate('2026-01-05')), '2026-01-05');
    expect(formatDate(parseDate('0999-12-31')), '0999-12-31');
  });

  test('localDateOf and minuteOfDayOf follow the offset', () {
    final utc = DateTime.utc(2026, 11, 11, 22, 0).millisecondsSinceEpoch;
    expect(localDateOf(utc, 0), '2026-11-11');
    expect(localDateOf(utc, 9 * 60), '2026-11-12');
    expect(minuteOfDayOf(utc, 9 * 60), 7 * 60);
    expect(localDateOf(utc, -12 * 60), '2026-11-11');
    expect(minuteOfDayOf(utc, -12 * 60), 10 * 60);
    expect(localDateOf(utc, 14 * 60), '2026-11-12');
    expect(minuteOfDayOf(utc, 14 * 60), 12 * 60);
  });

  test('half hour offsets work', () {
    final utc = DateTime.utc(2026, 11, 11, 18, 40).millisecondsSinceEpoch;
    expect(localDateOf(utc, 330), '2026-11-12'); // India, +5:30
    expect(minuteOfDayOf(utc, 330), 0 * 60 + 10);
  });
}
