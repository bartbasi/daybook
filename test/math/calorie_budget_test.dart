// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter_test/flutter_test.dart';

// The sample person from goals.html: male, born May 14, 1982, 5 ft 11 in,
// 181.8 lb, lightly active, losing 0.5 lb a week, on Nov 12, 2026 (age 44).
final sampleKg = lbToKg(181.8);
final sampleCm = inToCm(71);
const lose05 = WeeklyRate(Target.lose, 0.5, UnitSystem.imperial);

CalorieWorking sample({
  Sex sex = Sex.male,
  String birthDate = '1982-05-14',
  String day = '2026-11-12',
  double? weightKg,
  double? heightCm,
  ActivityLevel activity = ActivityLevel.lightlyActive,
  WeeklyRate rate = lose05,
}) => calorieWorking(
  sex: sex,
  birthDate: birthDate,
  day: day,
  weightKg: weightKg ?? sampleKg,
  heightCm: heightCm ?? sampleCm,
  activity: activity,
  rate: rate,
);

void main() {
  group('resting energy', () {
    test('the sample man is 1,736.8 kcal', () {
      final r = restingEnergy(
        sex: Sex.male,
        weightKg: sampleKg,
        heightCm: sampleCm,
        ageYears: 44,
      );
      expect(r, closeTo(10 * sampleKg + 6.25 * 180.34 - 220 + 5, 1e-9));
      expect(roundToTenth(r), 1736.8);
      expect(roundForDisplay(r), 1737);
    });

    test('a woman gets minus 161 where a man gets plus 5', () {
      double rest(Sex s) =>
          restingEnergy(sex: s, weightKg: 70, heightCm: 170, ageYears: 30);
      expect(rest(Sex.male), 10 * 70 + 6.25 * 170 - 150 + 5);
      expect(rest(Sex.female), 10 * 70 + 6.25 * 170 - 150 - 161);
      expect(rest(Sex.male) - rest(Sex.female), 166);
    });

    test('works at the edges of age, height and weight', () {
      expect(
        restingEnergy(
          sex: Sex.female,
          weightKg: 22.7,
          heightCm: 100,
          ageYears: 18,
        ),
        closeTo(10 * 22.7 + 625 - 90 - 161, 1e-9),
      );
      expect(
        restingEnergy(
          sex: Sex.male,
          weightKg: 453.6,
          heightCm: 250,
          ageYears: 100,
        ),
        closeTo(4536 + 1562.5 - 500 + 5, 1e-9),
      );
    });
  });

  group('age', () {
    test('turns a year older on the birthday, not before', () {
      expect(ageOn('1982-05-14', '2026-05-13'), 43);
      expect(ageOn('1982-05-14', '2026-05-14'), 44);
      expect(ageOn('1982-05-14', '2026-05-15'), 44);
    });

    test('a birthday on Feb 29 is passed on Mar 1 in a common year', () {
      expect(ageOn('2000-02-29', '2025-02-28'), 24);
      expect(ageOn('2000-02-29', '2025-03-01'), 25);
      expect(ageOn('2000-02-29', '2028-02-29'), 28);
    });

    test('the new year does not change the age', () {
      expect(ageOn('1982-12-31', '2026-01-01'), 43);
      expect(ageOn('1982-12-31', '2026-12-31'), 44);
    });
  });

  group('activity factors', () {
    test('the five factors', () {
      expect(ActivityLevel.values.map((a) => a.factor), [
        1.2,
        1.375,
        1.55,
        1.725,
        1.9,
      ]);
    });

    test('each factor multiplies the resting energy', () {
      final rest = sample().resting;
      for (final a in ActivityLevel.values) {
        final w = sample(activity: a, rate: WeeklyRate.stay);
        expect(w.maintenance, rest * a.factor, reason: a.name);
        expect(w.goal, rest * a.factor, reason: a.name);
        expect(w.activity, a);
      }
    });

    test('a stored factor finds its level, and anything else finds none', () {
      for (final a in ActivityLevel.values) {
        expect(ActivityLevel.fromFactor(a.factor), a);
      }
      expect(ActivityLevel.fromFactor(1.3), isNull);
    });
  });

  group('rates', () {
    test('imperial rates at 3,500 kcal per lb', () {
      final kcal = {0.25: 125, 0.5: 250, 1.0: 500, 1.5: 750, 2.0: 1000};
      expect(WeeklyRate.amounts(UnitSystem.imperial), kcal.keys.toList());
      for (final e in kcal.entries) {
        final lose = WeeklyRate(Target.lose, e.key, UnitSystem.imperial);
        final gain = WeeklyRate(Target.gain, e.key, UnitSystem.imperial);
        expect(lose.kcalPerDay, closeTo(-e.value, 1e-9), reason: '${e.key} lb');
        expect(gain.kcalPerDay, closeTo(e.value, 1e-9));
        expect(lose.kgPerWeek, closeTo(-lbToKg(e.key), 1e-12));
        expect(gain.kgPerWeek, closeTo(lbToKg(e.key), 1e-12));
      }
    });

    test('metric rates at 7,700 kcal per kg', () {
      final kcal = {0.1: 110, 0.25: 275, 0.5: 550, 0.75: 825, 1.0: 1100};
      expect(WeeklyRate.amounts(UnitSystem.metric), kcal.keys.toList());
      for (final e in kcal.entries) {
        final lose = WeeklyRate(Target.lose, e.key, UnitSystem.metric);
        final gain = WeeklyRate(Target.gain, e.key, UnitSystem.metric);
        expect(lose.kcalPerDay, closeTo(-e.value, 1e-9), reason: '${e.key} kg');
        expect(gain.kcalPerDay, closeTo(e.value, 1e-9));
        expect(lose.kgPerWeek, -e.key);
        expect(gain.kgPerWeek, e.key);
      }
    });

    test('staying the same changes nothing', () {
      expect(WeeklyRate.stay.kcalPerDay, 0);
      expect(WeeklyRate.stay.kgPerWeek, 0);
    });

    test('every offered rate is read back from its stored kg', () {
      for (final units in UnitSystem.values) {
        for (final t in [Target.lose, Target.gain]) {
          for (final a in WeeklyRate.amounts(units)) {
            final r = WeeklyRate(t, a, units);
            final back = WeeklyRate.fromKgPerWeek(r.kgPerWeek)!;
            expect(back.target, t);
            expect(back.amount, a);
            expect(back.units, units);
            expect(back.kcalPerDay, r.kcalPerDay);
          }
        }
      }
      expect(WeeklyRate.fromKgPerWeek(0)!.target, Target.stay);
      expect(WeeklyRate.fromKgPerWeek(-0.3), isNull);
    });

    test('the rate changes the goal by its daily amount', () {
      final base = sample(rate: WeeklyRate.stay).goal;
      expect(
        sample(rate: const WeeklyRate(Target.lose, 2, UnitSystem.imperial))
            .goal,
        closeTo(base - 1000, 1e-9),
      );
      expect(
        sample(rate: const WeeklyRate(Target.gain, 1, UnitSystem.metric)).goal,
        closeTo(base + 1100, 1e-9),
      );
    });
  });

  group('the sample person', () {
    test('1,736.8 resting, 2,388 to stay the same, 2,138 to lose 0.5 lb', () {
      final w = sample();
      expect(roundToTenth(w.resting), 1736.8);
      expect(roundForDisplay(w.resting), 1737);
      expect(roundForDisplay(w.maintenance), 2388);
      expect(roundForDisplay(w.adjustment), -250);
      expect(roundForDisplay(w.goal), 2138);
    });

    test('nothing is rounded inside', () {
      final w = sample();
      // Had the 1,737 shown been used, 1,737 x 1.375 would be 2,388.375.
      expect(w.maintenance, isNot(1737 * 1.375));
      expect(w.maintenance, w.resting * 1.375);
      // Had 2,388 been used, the goal would be exactly 2,138.
      expect(w.goal, isNot(2138));
      expect(w.goal, w.resting * 1.375 - 250);
      expect(w.goal, closeTo(2138.0, 0.5));
    });

    test('the same person a woman', () {
      final w = sample(sex: Sex.female);
      expect(w.resting, closeTo(sample().resting - 166, 1e-9));
    });

    test('the age is taken on the day asked for', () {
      final before = sample(day: '2026-05-13').resting;
      final after = sample(day: '2026-05-14').resting;
      expect(before - after, 5);
    });
  });

  group('low intake', () {
    test('men: under 1,500, not at 1,500', () {
      expect(isLowIntake(1499, Sex.male), isTrue);
      expect(isLowIntake(1500, Sex.male), isFalse);
      expect(isLowIntake(1499.9, Sex.male), isTrue);
      expect(isLowIntake(1501, Sex.male), isFalse);
    });

    test('women: under 1,200, not at 1,200', () {
      expect(isLowIntake(1199, Sex.female), isTrue);
      expect(isLowIntake(1200, Sex.female), isFalse);
      expect(isLowIntake(1201, Sex.female), isFalse);
    });

    test('the two lines differ by sex', () {
      expect(isLowIntake(1300, Sex.male), isTrue);
      expect(isLowIntake(1300, Sex.female), isFalse);
    });

    test('with no sex known there is nothing to warn about', () {
      expect(isLowIntake(500, null), isFalse);
    });

    test('the sample at 2 lb a week is 1,388, which is low for a man', () {
      final g = sample(
        rate: const WeeklyRate(Target.lose, 2, UnitSystem.imperial),
      ).goal;
      expect(roundForDisplay(g), 1388);
      expect(isLowIntake(roundForDisplay(g), Sex.male), isTrue);
    });
  });

  group('macros', () {
    test('percent mode on 2,138: 160 g, 214 g, 71 g', () {
      final m = macrosFromPercent(
        calories: 2138,
        proteinPercent: 30,
        carbsPercent: 40,
        fatPercent: 30,
      );
      expect(m.proteinG, closeTo(2138 * 0.3 / 4, 1e-9));
      expect(m.carbsG, closeTo(2138 * 0.4 / 4, 1e-9));
      expect(m.fatG, closeTo(2138 * 0.3 / 9, 1e-9));
      expect(roundForDisplay(m.proteinG), 160);
      expect(roundForDisplay(m.carbsG), 214);
      expect(roundForDisplay(m.fatG), 71);
      expect(roundForDisplay(m.proteinKcal), 641);
      expect(roundForDisplay(m.carbsKcal), 855);
      expect(m.totalKcal, closeTo(2138, 1e-9));
    });

    test('percents that do not add to 100 are refused', () {
      for (final p in [
        [30, 40, 25],
        [30, 40, 35],
        [0, 0, 0],
        [100, 100, -100],
        [110, 0, -10],
      ]) {
        expect(
          () => macrosFromPercent(
            calories: 2000,
            proteinPercent: p[0],
            carbsPercent: p[1],
            fatPercent: p[2],
          ),
          throwsA(isA<PercentsDontAddUp>()),
          reason: '$p',
        );
      }
    });

    test('percents of 100 and 0 are fine', () {
      final m = macrosFromPercent(
        calories: 1800,
        proteinPercent: 100,
        carbsPercent: 0,
        fatPercent: 0,
      );
      expect(m.proteinG, 450);
      expect(m.fatG, 0);
    });

    test('how many percent are left', () {
      expect(percentLeft(30, 40, 25), 5);
      expect(percentLeft(30, 40, 30), 0);
      expect(percentLeft(40, 40, 30), -10);
    });

    test('grams mode: 600, 908 and 630 kcal, 2,138 in all, no difference', () {
      const m = MacroBreakdown(proteinG: 150, carbsG: 227, fatG: 70);
      expect(m.proteinKcal, 600);
      expect(m.carbsKcal, 908);
      expect(m.fatKcal, 630);
      expect(m.totalKcal, 2138);
      expect(m.differenceFrom(2138), 0);
    });

    test('grams mode says how far off the goal is, over or under', () {
      const m = MacroBreakdown(proteinG: 150, carbsG: 227, fatG: 70);
      expect(m.differenceFrom(2038), 100);
      expect(m.differenceFrom(2238), -100);
    });
  });

  group('exercise add-back', () {
    test('0, 50 and 100 percent of a 383 kcal run', () {
      expect(addBackKcal(383, 0), 0);
      expect(addBackKcal(383, 50), 191.5);
      expect(addBackKcal(383, 100), 383);
    });

    test('nothing else is allowed', () {
      for (final p in [-50, 25, 75, 150]) {
        expect(() => addBackKcal(383, p), throwsArgumentError);
      }
    });
  });

  group('the day budget', () {
    DayBudget day(int percent, {double exercise = 383}) => DayBudget(
      goal: 2138,
      exerciseKcal: exercise,
      addBackPercent: percent,
      foodKcal: 1266,
    );

    test('2,138 + 383 - 1,266 = 1,255', () {
      final b = day(100);
      expect(b.addBack, 383);
      expect(b.left, 1255);
    });

    test('at 50 percent the run adds 191.5', () {
      expect(day(50).left, 2138 + 191.5 - 1266);
    });

    test('at 0 percent exercise adds nothing', () {
      expect(day(0).left, 2138 - 1266);
      expect(day(0).addBack, 0);
    });

    test('no exercise and no food leaves the whole goal', () {
      final b = DayBudget(
        goal: 2138,
        exerciseKcal: 0,
        addBackPercent: 100,
        foodKcal: 0,
      );
      expect(b.left, 2138);
    });

    test('over the goal is negative, with nothing rounded', () {
      final b = DayBudget(
        goal: 2000,
        exerciseKcal: 0,
        addBackPercent: 100,
        foodKcal: 2100.4,
      );
      expect(b.left, closeTo(-100.4, 1e-9));
    });

    test('a bad add-back percent is refused', () {
      expect(
        () => DayBudget(
          goal: 2000,
          exerciseKcal: 100,
          addBackPercent: 60,
          foodKcal: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('rounding for display', () {
    test('half rounds away from zero', () {
      expect(roundForDisplay(0.5), 1);
      expect(roundForDisplay(2137.5), 2138);
      expect(roundForDisplay(-250.5), -251);
      expect(roundForDisplay(2137.49), 2137);
    });
  });
}
