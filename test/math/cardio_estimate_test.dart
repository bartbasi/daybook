// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/math/cardio_estimate.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter_test/flutter_test.dart';

MphRange r(double? min, double? max) => (min: min, max: max);

// The Compendium's bands as the table holds them, slowest first, with the
// Compendium code of each in the same position (see lib/data/met_table.dart).
final running = [
  r(2.6, 3.7), r(4, 4.2), r(4.3, 4.8), r(5.0, 5.2), r(5.5, 5.8), // 12026..12045
  r(6, 6.3), r(6.7, 6.7), r(7, 7), r(7.5, 7.5), r(8, 8), r(8.6, 8.6), //
  r(9, 9), r(9.3, 9.6), r(10, 10), r(11, 11), r(12, 12), r(13, 13), r(14, 14),
];
const runningCodes = [
  '12026', '12028', '12029', '12030', '12045', '12050', '12060', '12070', //
  '12080', '12090', '12100', '12110', '12115', '12120', '12130', '12132',
  '12134', '12135',
];
final cycling = [
  r(null, 10),
  r(10, 11.9),
  r(12, 13.9),
  r(14, 15.9),
  r(16, 19),
  r(20, null),
];
const cyclingCodes = ['01010', '01020', '01030', '01040', '01050', '01060'];
final walking = [
  r(null, 2.0),
  r(2.0, 2.4),
  r(2.5, 2.5),
  r(2.8, 3.4),
  r(3.5, 3.9),
  r(4.0, 4.4),
  r(4.5, 4.9),
  r(5.0, 5.5),
];
const walkingCodes = [
  '17151', '17152', '17170', '17190', '17200', '17220', '17230', '17231', //
];

void main() {
  String pick(List<MphRange> bands, List<String> codes, double mph) =>
      codes[pickBand(bands, mph)];

  group('the sample', () {
    test('3.1 mi in 30 min is 6.2 mph and picks 12050', () {
      final mph = paceMph(
        distanceMeters: milesToMeters(3.1),
        durationSeconds: 1800,
      )!;
      expect(mph, closeTo(6.2, 1e-9));
      expect(pick(running, runningCodes, mph), '12050');
    });

    test('9.3 x 82.46 kg x 0.5 h is 383 kcal', () {
      final kg = lbToKg(181.8);
      expect(kg, closeTo(82.46, 0.005));
      final kcal = cardioKcal(
        met: 9.3,
        bodyWeightKg: kg,
        durationSeconds: 1800,
      );
      expect(kcal, closeTo(383.45, 0.01));
      expect(roundForDisplay(kcal), 383);
    });

    test('the estimate keeps full precision (rounding is for display)', () {
      final kcal = cardioKcal(
        met: 3.3,
        bodyWeightKg: 70.123,
        durationSeconds: 1234,
      );
      expect(kcal, 3.3 * 70.123 * (1234 / 3600));
    });

    test('no time, no calories', () {
      expect(cardioKcal(met: 9.3, bodyWeightKg: 80, durationSeconds: 0), 0);
      expect(cardioKcal(met: 9.3, bodyWeightKg: 80, durationSeconds: -5), 0);
    });
  });

  group('pace in miles per hour', () {
    test('miles and kilometers give the same pace for the same ground', () {
      // 5 km in 30 min is 10 km/h, 6.2137... mph.
      final km = paceMph(distanceMeters: kmToMeters(5), durationSeconds: 1800);
      final mi = paceMph(
        distanceMeters: milesToMeters(5 / 1.609344),
        durationSeconds: 1800,
      );
      expect(km, closeTo(6.2137119, 1e-6));
      expect(km, closeTo(mi!, 1e-9));
    });

    test('exact speeds come out exact, not a hair under', () {
      // 10 mi in 1 h must be 10.0 so it sits on a band edge as written.
      expect(
        paceMph(distanceMeters: milesToMeters(10), durationSeconds: 3600),
        10.0,
      );
      expect(
        paceMph(distanceMeters: milesToMeters(2), durationSeconds: 3600),
        2.0,
      );
    });

    test('no distance, a distance of 0, or no duration is no pace', () {
      expect(paceMph(distanceMeters: null, durationSeconds: 1800), isNull);
      expect(paceMph(distanceMeters: 0, durationSeconds: 1800), isNull);
      expect(paceMph(distanceMeters: 5000, durationSeconds: 0), isNull);
    });
  });

  group('the band that holds the pace', () {
    test('a pace inside a closed band takes it, ends included', () {
      expect(pick(running, runningCodes, 6.0), '12050');
      expect(pick(running, runningCodes, 6.3), '12050');
      expect(pick(running, runningCodes, 6.1), '12050');
      expect(pick(running, runningCodes, 6.7), '12060'); // a single speed
      expect(pick(running, runningCodes, 5.0), '12030');
      expect(pick(running, runningCodes, 5.2), '12030');
    });

    test('a pace in a gap takes the band with the nearest edge', () {
      expect(pick(running, runningCodes, 6.4), '12050'); // 0.1 from 6.3
      expect(pick(running, runningCodes, 6.6), '12060'); // 0.1 from 6.7
      expect(pick(running, runningCodes, 4.95), '12030'); // 0.05 from 5.0
      expect(pick(running, runningCodes, 4.85), '12029'); // 0.05 from 4.8
      expect(pick(running, runningCodes, 8.4), '12100'); // 0.2 from 8.6
    });

    test('a pace halfway between two bands takes the slower', () {
      expect(pick(running, runningCodes, 6.5), '12050'); // 6.3 | 6.7
      expect(pick(running, runningCodes, 5.35), '12030'); // 5.2 | 5.5
      expect(pick(running, runningCodes, 7.25), '12070'); // 7 | 7.5
      expect(pick(cycling, cyclingCodes, 19.5), '01050'); // 19 | 20
      expect(pick(cycling, cyclingCodes, 11.95), '01020'); // 11.9 | 12
    });

    test('two bands that share a closed edge: the slower one wins', () {
      final bands = [r(4, 6), r(6, 8)];
      expect(pickBand(bands, 6), 0);
      expect(pickBand(bands, 6.01), 1);
      expect(pickBand(bands, 5.99), 0);
    });

    test('"less than" does not hold its own number: 10 mph is 01020', () {
      expect(pick(cycling, cyclingCodes, 10.0), '01020');
      expect(pick(cycling, cyclingCodes, 9.99), '01010');
      expect(pick(cycling, cyclingCodes, 8), '01010');
      expect(pick(cycling, cyclingCodes, 0.5), '01010');
    });

    test('"less than" on walking: 2.0 mph is 17152, 1.9 is 17151', () {
      expect(pick(walking, walkingCodes, 2.0), '17152');
      expect(pick(walking, walkingCodes, 1.9), '17151');
      expect(pick(walking, walkingCodes, 0.4), '17151');
    });

    test('"greater than" does not hold its own number, but is nearest', () {
      // 20.0 is not inside ">20", and not inside 16-19 either: it is in the
      // gap, 0 from the edge of ">20" and 1 from 16-19.
      expect(pick(cycling, cyclingCodes, 20.0), '01060');
      expect(pick(cycling, cyclingCodes, 20.1), '01060');
      expect(pick(cycling, cyclingCodes, 25), '01060');
      expect(pick(cycling, cyclingCodes, 19.4), '01050');
    });

    test('walking paces', () {
      expect(pick(walking, walkingCodes, 2.6), '17170'); // 0.1 from 2.5
      expect(pick(walking, walkingCodes, 3.0), '17190');
      expect(pick(walking, walkingCodes, 5.0), '17231');
      expect(pick(walking, walkingCodes, 2.65), '17170'); // tie, slower
      expect(pick(walking, walkingCodes, 6.0), '17231'); // above the fastest
    });

    test('below the slowest band and above the fastest: the nearest band', () {
      expect(pick(running, runningCodes, 2.0), '12026');
      expect(pick(running, runningCodes, 0.1), '12026');
      expect(pick(running, runningCodes, 3.9), '12028'); // 0.1 from 4
      expect(pick(running, runningCodes, 15), '12135');
      expect(pick(running, runningCodes, 30), '12135');
    });

    test('values are never blended: the answer is always one whole band', () {
      for (var mph = 0.0; mph < 30; mph += 0.05) {
        final i = pickBand(running, mph);
        expect(i, inInclusiveRange(0, running.length - 1));
      }
      // Over the whole sweep the choice only ever steps up with the pace.
      var last = 0;
      for (var mph = 0.0; mph < 30; mph += 0.05) {
        final i = pickBand(running, mph);
        expect(i, greaterThanOrEqualTo(last));
        last = i;
      }
    });

    test('a pace with float noise still lands on the written edge', () {
      expect(pick(cycling, cyclingCodes, 10.0000000001), '01020');
      expect(pick(cycling, cyclingCodes, 9.9999999999), '01020');
      expect(pick(running, runningCodes, 6.5000000001), '12050');
    });

    test('a list with no bands is a mistake', () {
      expect(() => pickBand(const [], 5), throwsArgumentError);
    });
  });
}
