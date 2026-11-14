// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/math/training.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter_test/flutter_test.dart';

DoneSet lbSet(double lb, int reps, int at, [int id = 0]) =>
    DoneSet(weightKg: lbToKg(lb), reps: reps, atMs: at, id: id);

void main() {
  group('estimated one-rep max (Epley)', () {
    test('180 lb for 8 reps is 228 lb', () {
      expect(estimatedOneRepMax(180, 8), closeTo(228, 1e-9));
      expect(
        estimatedOneRepMaxIn(lbToKg(180), 8, UnitSystem.imperial),
        closeTo(228, 1e-9),
      );
    });

    test('in kilograms the answer stays in kilograms', () {
      expect(
        estimatedOneRepMaxIn(80, 8, UnitSystem.metric),
        closeTo(101.3333333, 1e-6),
      );
    });

    test('1 rep and 12 reps are estimated', () {
      expect(estimatedOneRepMax(100, 1), closeTo(100 * (1 + 1 / 30), 1e-9));
      expect(estimatedOneRepMax(100, 12), closeTo(140, 1e-9));
    });

    test('13 reps, 0 reps and negative reps have no estimate', () {
      expect(estimatedOneRepMax(100, 13), isNull);
      expect(estimatedOneRepMax(100, 0), isNull);
      expect(estimatedOneRepMax(100, -3), isNull);
      expect(estimatedOneRepMaxIn(45, 13, UnitSystem.imperial), isNull);
      expect(estimatedOneRepMaxIn(45, 0, UnitSystem.metric), isNull);
    });

    test('no weight above zero means no estimate', () {
      expect(estimatedOneRepMax(0, 8), isNull);
      expect(estimatedOneRepMax(-5, 8), isNull);
      expect(estimatedOneRepMax(double.nan, 8), isNull);
    });

    test('display rounding is one named place: whole lb, one decimal kg', () {
      expect(
        roundOneRepMaxForDisplay(228.00000000000003, UnitSystem.imperial),
        228,
      );
      expect(roundOneRepMaxForDisplay(221.6666, UnitSystem.imperial), 222);
      expect(roundOneRepMaxForDisplay(101.3333, UnitSystem.metric), 101.3);
    });
  });

  group('records', () {
    test('heaviest weight and best estimate, each with its set', () {
      final r = recordsOf([
        lbSet(175, 8, 1),
        lbSet(175, 8, 2),
        lbSet(180, 8, 3),
        lbSet(170, 8, 0),
      ]);
      expect(r.heaviest!.weightKg, lbToKg(180));
      expect(r.heaviest!.reps, 8);
      expect(r.bestEstimate!.atMs, 3);
      expect(kgToLb(r.bestEstimateKg!), closeTo(228, 1e-9));
    });

    test('a tie is held by the set done first, for both records', () {
      final r = recordsOf([lbSet(175, 8, 20, 2), lbSet(175, 8, 10, 1)]);
      expect(r.heaviest!.atMs, 10);
      expect(r.bestEstimate!.atMs, 10);
    });

    test('a lighter set of more reps can hold the estimate record only', () {
      // 150 x 12 = 210 estimate; 200 x 1 = 206.7 estimate and is heaviest.
      final r = recordsOf([lbSet(200, 1, 1), lbSet(150, 12, 2)]);
      expect(r.heaviest!.weightKg, lbToKg(200));
      expect(r.bestEstimate!.weightKg, lbToKg(150));
    });

    test('sets of 13 or more reps can be heaviest but never the estimate', () {
      final r = recordsOf([lbSet(100, 20, 1)]);
      expect(r.heaviest, isNotNull);
      expect(r.bestEstimate, isNull);
    });

    test('body weight sets and sets with no reps are ignored', () {
      final r = recordsOf([
        const DoneSet(weightKg: null, reps: 15, atMs: 1),
        const DoneSet(weightKg: 50, reps: null, atMs: 2),
      ]);
      expect(r.heaviest, isNull);
      expect(r.bestEstimate, isNull);
    });

    test('a heavier set is a new heaviest record and a new estimate', () {
      final before = [lbSet(175, 8, 1), lbSet(175, 7, 2)];
      final c = checkRecord(before, lbSet(180, 8, 3));
      expect(c.heaviest, isTrue);
      expect(c.estimate, isTrue);
      expect(c.any, isTrue);
    });

    test('a tie is not a record', () {
      final before = [lbSet(175, 8, 1)];
      final c = checkRecord(before, lbSet(175, 8, 2));
      expect(c.any, isFalse);
    });

    test('a lighter set of more reps with a higher estimate is an estimate record only', () {
      final before = [lbSet(200, 1, 1)]; // estimate 206.7
      final c = checkRecord(before, lbSet(150, 12, 2)); // estimate 210
      expect(c.heaviest, isFalse);
      expect(c.estimate, isTrue);
    });

    test('a heavier set of many reps is a heaviest record but no estimate', () {
      final before = [lbSet(150, 12, 1)];
      final c = checkRecord(before, lbSet(160, 14, 2));
      expect(c.heaviest, isTrue);
      expect(c.estimate, isFalse);
    });

    test('the first set ever has nothing to beat, so it is not a record', () {
      final c = checkRecord(const [], lbSet(100, 8, 1));
      expect(c.any, isFalse);
    });

    test('recordFor only looks at sets done before it', () {
      final all = [
        lbSet(175, 8, 1, 1),
        lbSet(180, 8, 2, 2),
        lbSet(185, 8, 3, 3),
      ];
      expect(recordFor(all[1], all).heaviest, isTrue);
      expect(recordFor(all[0], all).any, isFalse);
      // The same weight at the same millisecond: the later id is not a record.
      final a = lbSet(180, 8, 5, 10), b = lbSet(180, 8, 5, 11);
      expect(recordFor(b, [a, b]).any, isFalse);
    });

    test('a set with no weight is never a record', () {
      final c = checkRecord([
        lbSet(100, 8, 1),
      ], const DoneSet(weightKg: null, reps: 30, atMs: 2));
      expect(c.any, isFalse);
    });
  });

  group('volume of a workout', () {
    test('weight x reps added up (the sample in workout.html)', () {
      final sets = [
        for (final s in [(175, 8), (175, 8), (180, 8)])
          lbSet(s.$1.toDouble(), s.$2, 1),
      ];
      expect(kgToLb(totalVolumeKg(sets)), closeTo(4240, 1e-6));
    });

    test('body weight sets add nothing', () {
      expect(
        totalVolumeKg(const [DoneSet(weightKg: null, reps: 10, atMs: 1)]),
        0,
      );
    });
  });

  group('weekly volume', () {
    VolumeSet s(String day, List<String> muscles) =>
        (localDate: day, muscles: muscles);

    test('counts sets per primary muscle, Monday to Sunday', () {
      // Mon Nov 9 to Sun Nov 15, 2026.
      final out = setsPerMuscle([
        s('2026-11-09', ['back']),
        s('2026-11-09', ['back']),
        s('2026-11-12', ['chest', 'triceps']),
        s('2026-11-15', ['back']),
      ], '2026-11-12');
      expect(out, {'back': 3, 'chest': 1, 'triceps': 1});
    });

    test('Sunday night and Monday morning are different weeks', () {
      final sets = [
        s('2026-11-08', ['quads']),
        s('2026-11-09', ['quads']),
      ];
      expect(setsPerMuscle(sets, '2026-11-08'), {'quads': 1});
      expect(setsPerMuscle(sets, '2026-11-09'), {'quads': 1});
      expect(setsPerMuscle(sets, '2026-11-14'), {'quads': 1});
    });

    test('a daylight saving change inside the week moves nothing', () {
      // US clocks went back on Sun Nov 1, 2026 and forward on Sun Mar 8.
      final nov = [
        s('2026-10-26', ['a']),
        s('2026-11-01', ['a']),
        s('2026-11-02', ['a']),
      ];
      expect(setsPerMuscle(nov, '2026-10-30'), {'a': 2});
      expect(setsPerMuscle(nov, '2026-11-02'), {'a': 1});
      final mar = [
        s('2026-03-02', ['a']),
        s('2026-03-08', ['a']),
        s('2026-03-09', ['a']),
      ];
      expect(setsPerMuscle(mar, '2026-03-08'), {'a': 2});
    });

    test('a muscle listed twice for one exercise counts the set once; no muscles counts nowhere', () {
      expect(
        setsPerMuscle([
          s('2026-11-09', ['a', 'a']),
          s('2026-11-09', []),
        ], '2026-11-09'),
        {'a': 1},
      );
    });
  });

  group('workout calories', () {
    test('3.5 MET x kg x hours: the sample in workout.html', () {
      final kg = lbToKg(181.8);
      final kcal = workoutKcal(bodyWeightKg: kg, durationMs: 52 * 60000);
      // 3.5 x 82.4639 x (52 / 60) = 250.14
      expect(kcal, closeTo(3.5 * kg * 52 / 60, 1e-9));
      expect(kcal.round(), 250);
    });

    test('an hour at 80 kg is 280 kcal, with full precision', () {
      expect(workoutKcal(bodyWeightKg: 80, durationMs: 3600000), 280);
    });

    test('no time gives zero', () {
      expect(workoutKcal(bodyWeightKg: 80, durationMs: 0), 0);
      expect(workoutKcal(bodyWeightKg: 80, durationMs: -5), 0);
    });
  });
}
