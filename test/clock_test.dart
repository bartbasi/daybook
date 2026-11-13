// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Now reports the local date and minute for its offset', () {
    final utc = DateTime.utc(2026, 11, 12, 6, 30).millisecondsSinceEpoch;
    final tokyo = Now(utcMs: utc, offsetMinutes: 540);
    expect(tokyo.localDate, '2026-11-12');
    expect(tokyo.minuteOfDay, 15 * 60 + 30);
    final chicago = Now(utcMs: utc, offsetMinutes: -360);
    expect(chicago.localDate, '2026-11-12');
    expect(chicago.minuteOfDay, 0 * 60 + 30);
    final earlier = Now(utcMs: utc - 60 * 60000, offsetMinutes: -360);
    expect(earlier.localDate, '2026-11-11');
    expect(earlier.minuteOfDay, 23 * 60 + 30);
  });

  test('Now.fromLocal builds the instant for a wall-clock time', () {
    final n = Now.fromLocal('2026-11-12', 7 * 60, 540);
    expect(n.utcMs, DateTime.utc(2026, 11, 11, 22, 0).millisecondsSinceEpoch);
    expect(n.localDate, '2026-11-12');
    expect(n.minuteOfDay, 420);
    expect(n.offsetMinutes, 540);
  });

  test('fromLocal and the getters agree at the extreme offsets', () {
    for (final off in [-12 * 60, 14 * 60]) {
      for (final minute in [0, 1, 719, 1439]) {
        final n = Now.fromLocal('2026-12-31', minute, off);
        expect(n.localDate, '2026-12-31');
        expect(n.minuteOfDay, minute);
      }
    }
  });

  test('systemNow matches the device clock', () {
    final before = DateTime.now().millisecondsSinceEpoch;
    final n = systemNow();
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(n.utcMs, inInclusiveRange(before, after));
    expect(n.offsetMinutes, DateTime.now().timeZoneOffset.inMinutes);
  });
}
