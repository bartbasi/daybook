// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Helpers on local dates written 'YYYY-MM-DD'. Date maths runs on UTC
// DateTimes built from the wall-clock fields, so daylight saving time can
// never shift a day.

/// The calendar day as a UTC midnight DateTime.
DateTime parseDate(String localDate) {
  final p = localDate.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String addDays(String localDate, int days) =>
    formatDate(parseDate(localDate).add(Duration(days: days)));

/// The Monday on or before the date (weeks start on Monday).
String mondayOf(String localDate) =>
    addDays(localDate, 1 - parseDate(localDate).weekday);

/// The wall clock at an instant in a given local offset.
DateTime _wallClock(int utcMs, int offsetMinutes) =>
    DateTime.fromMillisecondsSinceEpoch(
      utcMs + offsetMinutes * 60000,
      isUtc: true,
    );

/// The local date of an instant, in the given offset.
String localDateOf(int utcMs, int offsetMinutes) =>
    formatDate(_wallClock(utcMs, offsetMinutes));

/// Minutes since local midnight (0 to 1439) of an instant, in the given offset.
int minuteOfDayOf(int utcMs, int offsetMinutes) {
  final t = _wallClock(utcMs, offsetMinutes);
  return t.hour * 60 + t.minute;
}
