// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'util/dates.dart';

/// An instant and the local time zone offset at that instant. Matches the
/// stored columns: *_at_ms, tz_offset_minutes and local_date.
class Now {
  const Now({required this.utcMs, required this.offsetMinutes});

  /// A wall-clock time on a local date, e.g. from the date and time pickers.
  factory Now.fromLocal(String localDate, int minuteOfDay, int offsetMinutes) =>
      Now(
        utcMs:
            parseDate(localDate).millisecondsSinceEpoch +
            (minuteOfDay - offsetMinutes) * 60000,
        offsetMinutes: offsetMinutes,
      );

  final int utcMs;
  final int offsetMinutes;

  /// 'YYYY-MM-DD' in the local offset.
  String get localDate => localDateOf(utcMs, offsetMinutes);

  /// 0 to 1439 in the local offset.
  int get minuteOfDay => minuteOfDayOf(utcMs, offsetMinutes);
}

/// The only source of "now". Tests pass any function that returns a [Now].
typedef Clock = Now Function();

Now systemNow() {
  final t = DateTime.now();
  return Now(
    utcMs: t.millisecondsSinceEpoch,
    offsetMinutes: t.timeZoneOffset.inMinutes,
  );
}
