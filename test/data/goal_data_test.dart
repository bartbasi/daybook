// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const imp = UnitSystem.imperial;
const lose05 = WeeklyRate(Target.lose, 0.5, imp);

/// A wall-clock time on a local date at a local offset in hours.
Now at(String date, int h, int m, double offsetHours) =>
    Now.fromLocal(date, h * 60 + m, (offsetHours * 60).round());

/// The sample person's goals, with changes where a test needs them.
GoalInput sampleInput({
  WeeklyRate rate = lose05,
  ActivityLevel activity = ActivityLevel.lightlyActive,
  int? ownCalories,
  int addBack = 100,
  MacroMode macroMode = MacroMode.grams,
  double? protein = 150,
  double? carbs = 227,
  double? fat = 70,
  Map<int, double>? overrides,
  Sex? sex = Sex.male,
  String? birthDate = '1982-05-14',
  double? heightCm,
}) => GoalInput(
  sex: sex,
  birthDate: birthDate,
  heightCm: heightCm ?? inToCm(71),
  activity: activity,
  rate: rate,
  ownCalories: ownCalories,
  addBackPercent: addBack,
  macroMode: macroMode,
  protein: protein,
  carbs: carbs,
  fat: fat,
  nutrientOverrides: overrides,
);

void main() {
  late AppDatabase db;
  final nov12 = at('2026-11-12', 8, 15, -6);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> weigh(double lb, String date) =>
      db.saveWeight(lb, imp, at(date, 7, 0, -6)).then((_) {});

  Future<int> goalRows() async => (await db.select(db.goals).get()).length;

  Future<void> run(
    String date, {
    double? override,
    double? estimate,
    DateTime? deleted,
  }) => db
      .into(db.cardioSessions)
      .insert(
        CardioSessionsCompanion.insert(
          localDate: date,
          startedAtMs: 0,
          tzOffsetMinutes: -360,
          activityName: 'Running',
          durationSeconds: 1800,
          kcalOverride: Value(override),
          kcalEstimated: Value(estimate),
          deletedAtMs: Value(deleted?.millisecondsSinceEpoch),
        ),
      )
      .then((_) {});

  /// A meal on [date] with one entry worth [kcal].
  Future<void> eat(String date, double kcal) async {
    final slot = (await db.select(db.mealSlots).get()).first.id;
    final meal = await db
        .into(db.meals)
        .insert(
          MealsCompanion.insert(
            localDate: date,
            slotId: slot,
            loggedAtMs: 0,
            tzOffsetMinutes: -360,
          ),
        );
    final entry = await db
        .into(db.mealEntries)
        .insert(
          MealEntriesCompanion.insert(
            mealId: meal,
            position: 0,
            foodRef: 'local:1',
            foodName: 'Food',
            quantity: 1,
            unitLabel: 'serving',
            baseQuantity: 1,
            baseUnit: 'serving',
          ),
        );
    await db
        .into(db.mealEntryNutrients)
        .insert(
          MealEntryNutrientsCompanion.insert(
            entryId: entry,
            nutrientId: Nutrients.energy,
            amount: kcal,
          ),
        );
  }

  group('saving goals', () {
    test('the sample person: 2,138 stored, with every input', () async {
      await weigh(181.8, '2026-11-12');
      final g = await db.saveGoals(sampleInput(), nov12);
      expect(g.calories, 2138);
      expect(g.row.calorieMode, 'calculated');
      expect(g.isOwnNumber, isFalse);
      expect(g.effectiveFrom, '2026-11-12');
      expect(g.row.activityFactor, 1.375);
      expect(g.row.targetKgPerWeek, closeTo(-lbToKg(0.5), 1e-12));
      expect(g.activity, ActivityLevel.lightlyActive);
      expect(g.rate!.amount, 0.5);
      expect(g.addBackPercent, 100);
      expect(g.macroMode, MacroMode.grams);
      expect(g.row.proteinTarget, 150);
      final p = (await db.getProfile())!;
      expect(p.sex, 'male');
      expect(p.birthDate, '1982-05-14');
      expect(p.heightCm, closeTo(180.34, 1e-9));
    });

    test('the same save read back for the day', () async {
      await weigh(181.8, '2026-11-12');
      final saved = await db.saveGoals(sampleInput(), nov12);
      final read = await db.goalsForDay('2026-11-12');
      expect(read!.row, saved.row);
    });

    test(
      'the weight comes from the latest weigh-in on or before the day',
      () async {
        await weigh(190, '2026-11-10');
        await weigh(181.8, '2026-11-12');
        final g = await db.saveGoals(sampleInput(), nov12);
        expect(g.calories, 2138);
      },
    );

    test('a weigh-in after the save day is ignored', () async {
      await weigh(181.8, '2026-11-12');
      await weigh(250, '2026-11-13');
      final g = await db.saveGoals(sampleInput(), nov12);
      expect(g.calories, 2138);
    });

    test('with only a later weigh-in there is no weight yet', () async {
      await weigh(181.8, '2026-11-13');
      await expectLater(
        db.saveGoals(sampleInput(), nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.needsWeight,
          ),
        ),
      );
      expect(await goalRows(), 0);
      expect(await db.getProfile(), isNull);
    });

    test(
      'with two weigh-ins on one day the later one by time is used',
      () async {
        await db.saveWeight(190, imp, at('2026-11-12', 6, 0, -6));
        await db.saveWeight(181.8, imp, at('2026-11-12', 7, 30, -6));
        await db.saveWeight(170, imp, at('2026-11-12', 6, 30, -6));
        final g = await db.saveGoals(sampleInput(), nov12);
        expect(g.calories, 2138);
      },
    );

    test('a deleted weigh-in is not used', () async {
      await weigh(190, '2026-11-10');
      final w = await db.saveWeight(181.8, imp, at('2026-11-12', 7, 0, -6));
      await db.deleteWeight(w.id, nov12);
      final g = await db.saveGoals(sampleInput(), nov12);
      // By hand, 190 lb = 86.18255 kg: 861.8255 + 1,127.125 - 220 + 5
      // = 1,773.9505; x 1.375 = 2,439.1819; - 250 = 2,189.18, so 2,189.
      expect(g.calories, 2189);
      expect(g.calories, isNot(2138));
    });

    test('a calculated goal needs the person and a weigh-in', () async {
      await expectLater(
        db.saveGoals(sampleInput(sex: null), nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.needsProfile,
          ),
        ),
      );
      await expectLater(
        db.saveGoals(sampleInput(), nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.needsWeight,
          ),
        ),
      );
    });

    test(
      'the profile saved earlier fills in what a later save leaves out',
      () async {
        await weigh(181.8, '2026-11-10');
        await db.saveGoals(sampleInput(), at('2026-11-10', 8, 0, -6));
        final g = await db.saveGoals(
          sampleInput(sex: null, birthDate: null, heightCm: null).let(
            (i) => GoalInput(
              activity: i.activity,
              rate: i.rate,
              protein: i.protein,
              carbs: i.carbs,
              fat: i.fat,
            ),
          ),
          nov12,
        );
        expect(g.calories, 2138);
      },
    );
  });

  group('days and rows', () {
    test('saving twice on one day updates one row', () async {
      await weigh(181.8, '2026-11-12');
      final first = await db.saveGoals(sampleInput(), nov12);
      final second = await db.saveGoals(
        sampleInput(rate: const WeeklyRate(Target.lose, 1, imp), addBack: 50),
        at('2026-11-12', 20, 0, -6),
      );
      expect(await goalRows(), 1);
      expect(second.row.id, first.row.id);
      expect(second.calories, 1888);
      expect(second.addBackPercent, 50);
    });

    test(
      'a day uses the latest row on or before it; past days keep theirs',
      () async {
        await weigh(181.8, '2026-11-01');
        await db.saveGoals(sampleInput(), at('2026-11-09', 8, 0, -6));
        await db.saveGoals(
          sampleInput(rate: const WeeklyRate(Target.lose, 1, imp)),
          at('2026-11-12', 8, 0, -6),
        );
        expect(await goalRows(), 2);
        expect(await db.goalsForDay('2026-11-08'), isNull);
        for (final d in ['2026-11-09', '2026-11-10', '2026-11-11']) {
          expect((await db.goalsForDay(d))!.calories, 2138, reason: d);
        }
        for (final d in ['2026-11-12', '2026-11-13', '2027-01-01']) {
          expect((await db.goalsForDay(d))!.calories, 1888, reason: d);
        }
      },
    );

    test('before any goals exist there is no goal and no budget', () async {
      expect(await db.goalsForDay('2026-11-12'), isNull);
      expect(await db.budgetForDay('2026-11-12'), isNull);
      await run('2026-11-12', estimate: 383);
      await eat('2026-11-12', 100);
      expect(await db.budgetForDay('2026-11-12'), isNull);
    });

    test('the day starts by the clock offset, not by UTC', () async {
      await weigh(181.8, '2026-11-12');
      // 23:30 on Nov 12 at minus 6 is already Nov 13 in UTC.
      final late = at('2026-11-12', 23, 30, -6);
      expect(late.utcMs, greaterThan(at('2026-11-13', 0, 0, 0).utcMs));
      final g = await db.saveGoals(sampleInput(), late);
      expect(g.effectiveFrom, '2026-11-12');
      // 00:10 on Nov 13 at plus 14 is still Nov 12 in UTC.
      final early = at('2026-11-13', 0, 10, 14);
      expect(
        (await db.saveGoals(sampleInput(), early)).effectiveFrom,
        '2026-11-13',
      );
      expect(await goalRows(), 2);
    });

    test('a day just before the start does not use the new row', () async {
      await weigh(181.8, '2026-11-12');
      await db.saveGoals(sampleInput(), nov12);
      expect(await db.goalsForDay('2026-11-11'), isNull);
      expect(await db.goalsForDay('2026-11-12'), isNotNull);
    });
  });

  group('a calculated goal that is not usable', () {
    // A very old woman, 150 cm, 100 lb, losing 2 lb a week: below zero.
    GoalInput extreme() => sampleInput(
      sex: Sex.female,
      birthDate: '1900-01-01',
      heightCm: 150,
      activity: ActivityLevel.sedentary,
      rate: const WeeklyRate(Target.lose, 2, imp),
      protein: null,
      carbs: null,
      fat: null,
    );

    test('is refused and nothing is written', () async {
      await weigh(100, '2026-11-12');
      await expectLater(
        db.saveGoals(extreme(), nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.calculatedNotPositive,
          ),
        ),
      );
      expect(await goalRows(), 0);
    });

    test('an own number still works for the same person', () async {
      await weigh(100, '2026-11-12');
      final g = await db.saveGoals(
        sampleInput(
          sex: Sex.female,
          birthDate: '1900-01-01',
          heightCm: 150,
          ownCalories: 1500,
        ),
        nov12,
      );
      expect(g.calories, 1500);
    });
  });

  group('own number', () {
    test(
      'is stored as typed, bypasses the formula and keeps the inputs',
      () async {
        await weigh(181.8, '2026-11-12');
        final g = await db.saveGoals(sampleInput(ownCalories: 1800), nov12);
        expect(g.calories, 1800);
        expect(g.isOwnNumber, isTrue);
        expect(g.row.calorieMode, 'fixed');
        expect(g.activity, ActivityLevel.lightlyActive);
        expect(g.rate!.amount, 0.5);
      },
    );

    test('needs no weigh-in and no profile', () async {
      final g = await db.saveGoals(
        sampleInput(ownCalories: 1800, sex: null, birthDate: null).let(
          (i) =>
              GoalInput(activity: i.activity, rate: i.rate, ownCalories: 1800),
        ),
        nov12,
      );
      expect(g.calories, 1800);
    });

    test('turning it off brings the calculation back', () async {
      await weigh(181.8, '2026-11-12');
      await db.saveGoals(sampleInput(ownCalories: 1800), nov12);
      final g = await db.saveGoals(sampleInput(), nov12);
      expect(g.calories, 2138);
      expect(g.row.calorieMode, 'calculated');
      expect(await goalRows(), 1);
    });

    test('zero or less is refused', () async {
      for (final n in [0, -100]) {
        await expectLater(
          db.saveGoals(sampleInput(ownCalories: n), nov12),
          throwsA(
            isA<GoalRefused>().having(
              (e) => e.problem,
              'problem',
              GoalProblem.ownNumberNotPositive,
            ),
          ),
        );
      }
      expect(await goalRows(), 0);
    });

    test('Recalculate leaves it alone', () async {
      await weigh(181.8, '2026-11-12');
      final saved = await db.saveGoals(sampleInput(ownCalories: 1800), nov12);
      final again = await db.recalculateGoals(at('2026-11-14', 8, 0, -6));
      expect(again.row, saved.row);
      expect(await goalRows(), 1);
    });
  });

  group('Recalculate with a row it cannot read', () {
    Future<void> badRow({double factor = 1.375, double kg = -0.5}) => db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            effectiveFrom: '2026-11-08',
            calorieMode: 'calculated',
            calories: const Value(2138),
            activityFactor: factor,
            targetKgPerWeek: kg,
            macroMode: 'grams',
          ),
        )
        .then((_) {});

    test('an unreadable rate is refused and nothing is written', () async {
      await weigh(181.8, '2026-11-08');
      await badRow(kg: -0.3);
      await expectLater(
        db.recalculateGoals(nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.badRate,
          ),
        ),
      );
      expect(await goalRows(), 1);
      expect((await db.goalsForDay('2026-11-12'))!.calories, 2138);
    });

    test('an unreadable activity is refused and nothing is written', () async {
      await weigh(181.8, '2026-11-08');
      await badRow(factor: 1.3, kg: -lbToKg(0.5));
      await expectLater(
        db.recalculateGoals(nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.badActivity,
          ),
        ),
      );
      expect(await goalRows(), 1);
    });
  });

  group('Recalculate', () {
    test(
      'uses the latest weigh-in, from today, and past days keep theirs',
      () async {
        await weigh(181.8, '2026-11-08');
        final first = await db.saveGoals(
          sampleInput(addBack: 50, overrides: {Nutrients.sodium: 1500}),
          at('2026-11-08', 8, 0, -6),
        );
        expect(first.calories, 2138);
        await weigh(170, '2026-11-12');
        final again = await db.recalculateGoals(nov12);
        // By hand, 170 lb = 77.11070 kg: 771.1070 + 1,127.125 - 220 + 5
        // = 1,683.2320; x 1.375 = 2,314.4440; - 250 = 2,064.44, so 2,064.
        expect(again.calories, 2064);
        expect(again.calories, lessThan(2138));
        expect(again.effectiveFrom, '2026-11-12');
        // Everything but the number is kept.
        expect(again.addBackPercent, 50);
        expect(again.row.proteinTarget, 150);
        expect(again.activity, ActivityLevel.lightlyActive);
        expect(again.nutrientOverrides, {Nutrients.sodium: 1500});
        // The earlier row is untouched.
        expect(await goalRows(), 2);
        expect((await db.goalsForDay('2026-11-11'))!.row, first.row);
      },
    );

    test('twice on one day leaves one row', () async {
      await weigh(181.8, '2026-11-08');
      await db.saveGoals(sampleInput(), at('2026-11-08', 8, 0, -6));
      await db.recalculateGoals(nov12);
      await db.recalculateGoals(at('2026-11-12', 21, 0, -6));
      expect(await goalRows(), 2);
    });

    test(
      'an edited weigh-in only matters when Recalculate is tapped',
      () async {
        await weigh(181.8, '2026-11-12');
        await db.saveGoals(sampleInput(), nov12);
        await weigh(150, '2026-11-12');
        expect((await db.goalsForDay('2026-11-12'))!.calories, 2138);
      },
    );

    test('before any goals it is refused', () async {
      await expectLater(
        db.recalculateGoals(nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.noGoals,
          ),
        ),
      );
    });
  });

  group('rates and units', () {
    test('every metric rate round-trips through the row', () async {
      await weigh(181.8, '2026-11-12');
      for (final a in WeeklyRate.amounts(UnitSystem.metric)) {
        final g = await db.saveGoals(
          sampleInput(rate: WeeklyRate(Target.gain, a, UnitSystem.metric)),
          nov12,
        );
        expect(g.rate!.units, UnitSystem.metric);
        expect(g.rate!.amount, a);
        expect(g.rate!.target, Target.gain);
      }
    });

    test('metric 0.25 kg a week is 275 kcal a day', () async {
      await weigh(181.8, '2026-11-12');
      final stay = await db.saveGoals(
        sampleInput(rate: WeeklyRate.stay),
        nov12,
      );
      final g = await db.saveGoals(
        sampleInput(
          rate: const WeeklyRate(Target.lose, 0.25, UnitSystem.metric),
        ),
        nov12,
      );
      // 2,388.04 stays at 2,388. Less 275 is 2,113.04, stored as 2,113.
      expect(stay.calories, 2388);
      expect(g.calories, 2113);
      expect(stay.calories! - g.calories!, 275);
    });

    test('a metric amount that is really a pound count is refused', () async {
      await weigh(181.8, '2026-11-12');
      await expectLater(
        db.saveGoals(
          sampleInput(
            rate: const WeeklyRate(Target.lose, 0.45359237, UnitSystem.metric),
          ),
          nov12,
        ),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.badRate,
          ),
        ),
      );
      expect(await goalRows(), 0);
    });

    test('every activity level round-trips', () async {
      await weigh(181.8, '2026-11-12');
      for (final a in ActivityLevel.values) {
        final g = await db.saveGoals(sampleInput(activity: a), nov12);
        expect(g.activity, a);
      }
    });

    test('a rate that is not one of the ten is refused', () async {
      await weigh(181.8, '2026-11-12');
      await expectLater(
        db.saveGoals(
          sampleInput(rate: const WeeklyRate(Target.lose, 0.3, imp)),
          nov12,
        ),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.badRate,
          ),
        ),
      );
    });

    test('a bad add-back is refused', () async {
      await weigh(181.8, '2026-11-12');
      await expectLater(
        db.saveGoals(sampleInput(addBack: 75), nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.badAddBack,
          ),
        ),
      );
    });
  });

  group('macros', () {
    test(
      'grams mode reads back with kcal and the difference from the goal',
      () async {
        await weigh(181.8, '2026-11-12');
        final g = await db.saveGoals(sampleInput(), nov12);
        final m = g.macros!;
        expect([m.proteinKcal, m.carbsKcal, m.fatKcal], [600, 908, 630]);
        expect(m.totalKcal, 2138);
        expect(m.differenceFrom(g.calories!), 0);
      },
    );

    test('percent mode: 160 g, 214 g and 71 g of the stored 2,138', () async {
      await weigh(181.8, '2026-11-12');
      final g = await db.saveGoals(
        sampleInput(
          macroMode: MacroMode.percent,
          protein: 30,
          carbs: 40,
          fat: 30,
        ),
        nov12,
      );
      expect(g.macroMode, MacroMode.percent);
      final m = g.macros!;
      expect(roundForDisplay(m.proteinG), 160);
      expect(roundForDisplay(m.carbsG), 214);
      expect(roundForDisplay(m.fatG), 71);
    });

    test(
      'percents that do not add to 100 are refused and nothing is written',
      () async {
        await weigh(181.8, '2026-11-12');
        for (final p in [
          [30.0, 40.0, 25.0],
          [30.0, 40.0, 35.0],
          [30.5, 39.5, 30.0],
        ]) {
          await expectLater(
            db.saveGoals(
              sampleInput(
                macroMode: MacroMode.percent,
                protein: p[0],
                carbs: p[1],
                fat: p[2],
              ),
              nov12,
            ),
            throwsA(isA<PercentsDontAddUp>()),
            reason: '$p',
          );
        }
        expect(await goalRows(), 0);
        expect(await db.getProfile(), isNull);
      },
    );

    test('some but not all macros is refused; none is fine', () async {
      await weigh(181.8, '2026-11-12');
      await expectLater(
        db.saveGoals(sampleInput(carbs: null), nov12),
        throwsA(
          isA<GoalRefused>().having(
            (e) => e.problem,
            'problem',
            GoalProblem.macrosIncomplete,
          ),
        ),
      );
      final g = await db.saveGoals(
        sampleInput(protein: null, carbs: null, fat: null),
        nov12,
      );
      expect(g.macros, isNull);
    });

    test(
      'changing the mode on a later day leaves the earlier day as it was',
      () async {
        await weigh(181.8, '2026-11-08');
        await db.saveGoals(sampleInput(), at('2026-11-08', 8, 0, -6));
        await db.saveGoals(
          sampleInput(
            macroMode: MacroMode.percent,
            protein: 30,
            carbs: 40,
            fat: 30,
          ),
          nov12,
        );
        expect(
          (await db.goalsForDay('2026-11-10'))!.macroMode,
          MacroMode.grams,
        );
        expect(
          (await db.goalsForDay('2026-11-12'))!.macroMode,
          MacroMode.percent,
        );
      },
    );
  });

  group('nutrient goals', () {
    test('the Daily Values are the defaults', () async {
      final d = defaultNutrientGoals();
      expect(d[Nutrients.fiber], 28);
      expect(d[Nutrients.sodium], 2300);
      expect(d[Nutrients.addedSugar], 50);
      expect(d[Nutrients.vitaminB12], 2.4);
      expect(d.containsKey(Nutrients.sugar), isFalse);
      expect(d.containsKey(Nutrients.transFat), isFalse);
      // Calories and macros are goals in the goals row.
      for (final id in [
        Nutrients.energy,
        Nutrients.protein,
        Nutrients.carbs,
        Nutrients.fat,
      ]) {
        expect(d.containsKey(id), isFalse);
      }
    });

    test(
      'every tracked nutrient has a Daily Value except sugars and trans fat',
      () {
        final without = [
          for (final n in Nutrients.tracked)
            if (Nutrients.dailyValueOf(n.id) == null) n.id,
        ];
        expect(without, [Nutrients.sugar, Nutrients.transFat]);
      },
    );

    test('the Daily Values table', () {
      expect(Nutrients.dailyValues, {
        Nutrients.energy: 2000,
        Nutrients.protein: 50,
        Nutrients.carbs: 275,
        Nutrients.fat: 78,
        Nutrients.fiber: 28,
        Nutrients.addedSugar: 50,
        Nutrients.saturatedFat: 20,
        Nutrients.cholesterol: 300,
        Nutrients.sodium: 2300,
        Nutrients.potassium: 4700,
        Nutrients.calcium: 1300,
        Nutrients.iron: 18,
        Nutrients.magnesium: 420,
        Nutrients.zinc: 11,
        Nutrients.vitaminA: 900,
        Nutrients.vitaminC: 90,
        Nutrients.vitaminD: 20,
        Nutrients.vitaminE: 15,
        Nutrients.vitaminK: 120,
        Nutrients.vitaminB6: 1.7,
        Nutrients.vitaminB12: 2.4,
        Nutrients.folate: 400,
      });
    });

    test('an override sits on top of the default for that goal only', () async {
      await weigh(181.8, '2026-11-12');
      final g = await db.saveGoals(
        sampleInput(overrides: {Nutrients.sodium: 1500}),
        nov12,
      );
      expect(g.nutrientGoals[Nutrients.sodium], 1500);
      expect(g.nutrientGoals[Nutrients.fiber], 28);
      expect(g.nutrientOverrides, {Nutrients.sodium: 1500});
    });

    test('a later save keeps the overrides unless it gives others', () async {
      await weigh(181.8, '2026-11-08');
      await db.saveGoals(
        sampleInput(overrides: {Nutrients.sodium: 1500}),
        at('2026-11-08', 8, 0, -6),
      );
      final kept = await db.saveGoals(sampleInput(), nov12);
      expect(kept.nutrientOverrides, {Nutrients.sodium: 1500});
      final changed = await db.saveGoals(
        sampleInput(overrides: {Nutrients.fiber: 35}),
        nov12,
      );
      expect(changed.nutrientOverrides, {Nutrients.fiber: 35});
      expect((await db.goalsForDay('2026-11-10'))!.nutrientOverrides, {
        Nutrients.sodium: 1500,
      });
      final cleared = await db.saveGoals(sampleInput(overrides: {}), nov12);
      expect(cleared.nutrientOverrides, isEmpty);
      expect(cleared.nutrientGoals[Nutrients.sodium], 2300);
    });
  });

  group('the day budget', () {
    Future<void> sampleGoals() async {
      await weigh(181.8, '2026-11-08');
      await db.saveGoals(sampleInput(), at('2026-11-08', 8, 0, -6));
    }

    test('2,138 + 383 - 1,266 = 1,255', () async {
      await sampleGoals();
      await run('2026-11-12', estimate: 383);
      await eat('2026-11-12', 490);
      await eat('2026-11-12', 776);
      final b = (await db.budgetForDay('2026-11-12'))!;
      expect(b.goal, 2138);
      expect(b.exerciseKcal, 383);
      expect(b.foodKcal, 1266);
      expect(b.left, 1255);
    });

    test('with nothing logged the whole goal is left', () async {
      await sampleGoals();
      expect((await db.budgetForDay('2026-11-12'))!.left, 2138);
    });

    test('the user\'s number comes before the estimate', () async {
      await sampleGoals();
      await run('2026-11-12', override: 400, estimate: 383);
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 400);
    });

    test('an estimate alone counts, and neither counts as zero', () async {
      await sampleGoals();
      await run('2026-11-12', estimate: 383);
      await run('2026-11-12');
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 383);
    });

    test('an override of zero is the user\'s number, not a gap', () async {
      await sampleGoals();
      await run('2026-11-12', override: 0, estimate: 383);
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 0);
    });

    test('deleted cardio is left out', () async {
      await sampleGoals();
      await run('2026-11-12', estimate: 383);
      await run('2026-11-12', override: 500, deleted: DateTime(2026, 11, 12));
      final b = (await db.budgetForDay('2026-11-12'))!;
      expect(b.exerciseKcal, 383);
      expect(b.left, 2138 + 383);
    });

    test('a workout counts the same way', () async {
      await sampleGoals();
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              localDate: '2026-11-12',
              startedAtMs: 0,
              tzOffsetMinutes: -360,
              kcalEstimated: const Value(200),
              kcalOverride: const Value(250),
            ),
          );
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              localDate: '2026-11-12',
              startedAtMs: 0,
              tzOffsetMinutes: -360,
            ),
          );
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 250);
    });

    test('add-back at 0, 50 and 100 percent, with the same run', () async {
      await run('2026-11-12', estimate: 383);
      await eat('2026-11-12', 1266);
      await weigh(181.8, '2026-11-08');
      final expected = {0: 872.0, 50: 872.0 + 191.5, 100: 1255.0};
      for (final e in expected.entries) {
        await db.saveGoals(
          sampleInput(addBack: e.key),
          at('2026-11-08', 8, 0, -6),
        );
        final b = (await db.budgetForDay('2026-11-12'))!;
        expect(b.left, e.value, reason: '${e.key}%');
      }
    });

    test('add-back with an override, with an estimate and with both', () async {
      await weigh(181.8, '2026-11-08');
      await db.saveGoals(sampleInput(addBack: 50), at('2026-11-08', 8, 0, -6));
      await run('2026-11-12', override: 400);
      expect((await db.budgetForDay('2026-11-12'))!.addBack, 200);
      await run('2026-11-12', estimate: 100);
      expect((await db.budgetForDay('2026-11-12'))!.addBack, 250);
      await run('2026-11-12', override: 60, estimate: 999);
      expect((await db.budgetForDay('2026-11-12'))!.addBack, 280);
    });

    test('other days do not leak in, and days are by local date', () async {
      await sampleGoals();
      await run('2026-11-11', estimate: 500);
      await run('2026-11-13', estimate: 600);
      await eat('2026-11-11', 700);
      await eat('2026-11-13', 800);
      final b = (await db.budgetForDay('2026-11-12'))!;
      expect(b.exerciseKcal, 0);
      expect(b.foodKcal, 0);
      expect((await db.budgetForDay('2026-11-13'))!.foodKcal, 800);
    });

    test(
      'exceptMealId leaves that meal out of the food, and only that one',
      () async {
        await sampleGoals();
        await eat('2026-11-12', 490);
        await eat('2026-11-12', 776);
        await eat('2026-11-12', 130);
        final ids = [for (final m in await db.select(db.meals).get()) m.id];
        final b = (await db.budgetForDay('2026-11-12', exceptMealId: ids[1]))!;
        expect(b.foodKcal, 620);
        expect(b.left, 2138 - 620);
        expect((await db.budgetForDay('2026-11-12'))!.foodKcal, 1396);
        final first = await db.budgetForDay('2026-11-12', exceptMealId: ids[0]);
        expect(first!.foodKcal, 906);
      },
    );

    test('exceptMealId for a meal on another day changes nothing', () async {
      await sampleGoals();
      await eat('2026-11-12', 490);
      await eat('2026-11-11', 300);
      final other = (await db.select(db.meals).get())
          .firstWhere((m) => m.localDate == '2026-11-11')
          .id;
      final b = await db.budgetForDay('2026-11-12', exceptMealId: other);
      expect(b!.foodKcal, 490);
      expect(
        (await db.budgetForDay('2026-11-12', exceptMealId: 9999))!.foodKcal,
        490,
      );
    });

    test(
      'watchBudgetForDay with exceptMealId follows the other meals',
      () async {
        await sampleGoals();
        await eat('2026-11-12', 490);
        await eat('2026-11-12', 776);
        final id = (await db.select(db.meals).get()).first.id;
        final seen = <double>[];
        final sub = db
            .watchBudgetForDay('2026-11-12', exceptMealId: id)
            .listen((b) => seen.add(b!.foodKcal));
        await pumpEventQueue();
        await eat('2026-11-12', 100);
        await pumpEventQueue();
        await sub.cancel();
        expect(seen.first, 776);
        expect(seen.last, 876);
      },
    );

    test('a day uses its own goal', () async {
      await sampleGoals();
      await weigh(181.8, '2026-11-12');
      await db.saveGoals(sampleInput(ownCalories: 1800), nov12);
      expect((await db.budgetForDay('2026-11-11'))!.goal, 2138);
      expect((await db.budgetForDay('2026-11-12'))!.goal, 1800);
    });

    test('a food nutrient other than energy is not counted', () async {
      await sampleGoals();
      await eat('2026-11-12', 300);
      final entry = (await db.select(db.mealEntries).get()).single;
      await db
          .into(db.mealEntryNutrients)
          .insert(
            MealEntryNutrientsCompanion.insert(
              entryId: entry.id,
              nutrientId: Nutrients.protein,
              amount: 40,
            ),
          );
      expect((await db.budgetForDay('2026-11-12'))!.foodKcal, 300);
    });

    test(
      'a stored add-back of 75 reads as 100 and the budget still works',
      () async {
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                effectiveFrom: '2026-11-08',
                calorieMode: 'fixed',
                calories: const Value(2138),
                activityFactor: 1.375,
                targetKgPerWeek: 0,
                macroMode: 'grams',
                exerciseAddBackPercent: const Value(75),
              ),
            );
        await run('2026-11-12', estimate: 383);
        final b = (await db.budgetForDay('2026-11-12'))!;
        expect(b.addBackPercent, 100);
        expect(b.left, 2138 + 383);
      },
    );

    test('cardio and a workout on one day are added together', () async {
      await sampleGoals();
      await run('2026-11-12', estimate: 383);
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              localDate: '2026-11-12',
              startedAtMs: 0,
              tzOffsetMinutes: -360,
              kcalEstimated: const Value(150),
            ),
          );
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 533);
    });

    test('the budget stream re-emits when goals or a workout change', () async {
      await sampleGoals();
      final seen = <double?>[];
      final sub = db
          .watchBudgetForDay('2026-11-12')
          .listen((b) => seen.add(b?.left));
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 50));
      await settle();
      await db.saveGoals(sampleInput(ownCalories: 1800), nov12);
      await settle();
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              localDate: '2026-11-12',
              startedAtMs: 0,
              tzOffsetMinutes: -360,
              kcalOverride: const Value(250),
            ),
          );
      await settle();
      await sub.cancel();
      expect(seen.first, 2138);
      expect(seen, contains(1800));
      expect(seen.last, 2050);
    });

    test('the stream follows goals, exercise and food', () async {
      await sampleGoals();
      final seen = <double?>[];
      final sub = db
          .watchBudgetForDay('2026-11-12')
          .listen((b) => seen.add(b?.left));
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 50));
      await settle();
      await run('2026-11-12', estimate: 383);
      await settle();
      await eat('2026-11-12', 1266);
      await settle();
      await sub.cancel();
      expect(seen.first, 2138);
      expect(seen.last, 1255);
    });

    test('the goals stream emits null, then the saved goals', () async {
      await weigh(181.8, '2026-11-12');
      final seen = <int?>[];
      final sub = db
          .watchGoalsForDay('2026-11-12')
          .listen((g) => seen.add(g?.calories));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.saveGoals(sampleInput(), nov12);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(seen.first, isNull);
      expect(seen.last, 2138);
    });
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
