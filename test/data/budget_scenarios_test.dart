// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Task 3.3: the day's budget across days and goal changes. Every row is put
// in directly, so these tests do not depend on how the screens save things.
// Each expected number is from home.html or worked out by hand in a comment.
//
// What goal_data_test.dart already proves, and is not repeated here: the
// goal calculation and its refusals, one saved row per day, own number on and
// off, macros and Daily Values, the three add-back percents on one run, an
// override of zero, estimate and override on one cardio row, one workout row,
// deleted cardio left out, a stored add-back of 75, a first look at
// exceptMealId, and a first stream test for goals, workouts and food.

// Central time in 2026: UTC-5 in daylight time, UTC-6 in standard time.
const cdt = -300;
const cst = -360;

/// A wall-clock time on a local date (used on ordinary days).
Now localAt(String date, int h, int m, [int offset = cst]) =>
    Now.fromLocal(date, h * 60 + m, offset);

/// A real UTC instant with the local offset that applied at it.
Now utcAt(int y, int mo, int d, int h, int mi, int offset) => Now(
  utcMs: DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch,
  offsetMinutes: offset,
);

/// The sample person from goals.html: a man born 1982-05-14, 71 in tall,
/// lightly active, losing 0.5 lb a week.
GoalInput sample({
  int addBack = 100,
  int? own,
  WeeklyRate rate = const WeeklyRate(Target.lose, 0.5, UnitSystem.imperial),
}) => GoalInput(
  sex: Sex.male,
  birthDate: '1982-05-14',
  heightCm: inToCm(71),
  activity: ActivityLevel.lightlyActive,
  rate: rate,
  ownCalories: own,
  addBackPercent: addBack,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> weigh(double lb, String date) => db
      .into(db.weightEntries)
      .insert(
        WeightEntriesCompanion.insert(
          localDate: date,
          measuredAtMs: 0,
          tzOffsetMinutes: cst,
          weightKg: lbToKg(lb),
          createdAtMs: 0,
          updatedAtMs: 0,
        ),
      )
      .then((_) {});

  /// A goals row put in directly: a fixed calorie number from [from].
  Future<int> goalRow(String from, int kcal, {int addBack = 100}) => db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          effectiveFrom: from,
          calorieMode: 'fixed',
          calories: Value(kcal),
          activityFactor: 1.375,
          targetKgPerWeek: 0,
          macroMode: 'grams',
          exerciseAddBackPercent: Value(addBack),
        ),
      );

  Future<int> slotId(String name) async => (await (db.select(
    db.mealSlots,
  )..where((s) => s.name.equals(name))).getSingle()).id;

  /// A meal at [at], one entry per map in [entries] (nutrient id to amount).
  Future<int> addMeal(
    Now at,
    List<Map<int, double>> entries, {
    String slot = 'Breakfast',
  }) async {
    final meal = await db
        .into(db.meals)
        .insert(
          MealsCompanion.insert(
            localDate: at.localDate,
            slotId: await slotId(slot),
            loggedAtMs: at.utcMs,
            tzOffsetMinutes: at.offsetMinutes,
          ),
        );
    for (var i = 0; i < entries.length; i++) {
      final entry = await db
          .into(db.mealEntries)
          .insert(
            MealEntriesCompanion.insert(
              mealId: meal,
              position: i,
              foodRef: 'local:1',
              foodName: 'Food',
              quantity: 1,
              unitLabel: 'serving',
              baseQuantity: 1,
              baseUnit: 'serving',
            ),
          );
      for (final n in entries[i].entries) {
        await db
            .into(db.mealEntryNutrients)
            .insert(
              MealEntryNutrientsCompanion.insert(
                entryId: entry,
                nutrientId: n.key,
                amount: n.value,
              ),
            );
      }
    }
    return meal;
  }

  /// A meal with one entry worth [kcal].
  Future<int> eat(Now at, double kcal, {String slot = 'Breakfast'}) =>
      addMeal(at, [
        {Nutrients.energy: kcal},
      ], slot: slot);

  /// Changes the calories of a one-entry meal (an edit).
  Future<void> setMealKcal(int mealId, double kcal) async {
    final entry = await (db.select(
      db.mealEntries,
    )..where((e) => e.mealId.equals(mealId))).getSingle();
    await (db.update(db.mealEntryNutrients)..where(
          (n) =>
              n.entryId.equals(entry.id) &
              n.nutrientId.equals(Nutrients.energy),
        ))
        .write(MealEntryNutrientsCompanion(amount: Value(kcal)));
  }

  Future<int> cardio(Now at, {double? override, double? estimate}) => db
      .into(db.cardioSessions)
      .insert(
        CardioSessionsCompanion.insert(
          localDate: at.localDate,
          startedAtMs: at.utcMs,
          tzOffsetMinutes: at.offsetMinutes,
          activityName: 'Running',
          durationSeconds: 1800,
          kcalOverride: Value(override),
          kcalEstimated: Value(estimate),
        ),
      );

  Future<int> lift(Now at, {double? override, double? estimate}) => db
      .into(db.workouts)
      .insert(
        WorkoutsCompanion.insert(
          localDate: at.localDate,
          startedAtMs: at.utcMs,
          tzOffsetMinutes: at.offsetMinutes,
          kcalOverride: Value(override),
          kcalEstimated: Value(estimate),
        ),
      );

  /// Soft delete and put back, the way the data layer marks deleted cardio.
  Future<void> markDeleted(int id, bool deleted) =>
      (db.update(db.cardioSessions)..where((c) => c.id.equals(id))).write(
        CardioSessionsCompanion(deletedAtMs: Value(deleted ? 1 : null)),
      );

  Future<DayBudget> budget(String day, {int? except}) async =>
      (await db.budgetForDay(day, exceptMealId: except))!;

  void expectShown(
    DayBudget b, {
    required int goal,
    required int addBack,
    required int food,
    required int left,
  }) {
    expect(
      [b.shownGoal, b.shownAddBack, b.shownFood, b.shownLeft],
      [goal, addBack, food, left],
    );
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  group('1. the sample day of home.html frame 2', () {
    // Thursday, Nov 12, 2026. Breakfast 490 (egg, toast, butter, coffee, half
    // and half), lunch 776 (chicken, rice, milk, apple), a 30 minute run of
    // 383 kcal. Food 490 + 776 = 1,266.
    Future<void> sampleDay() async {
      final nov12 = localAt('2026-11-12', 12, 0);
      await goalRow('2026-11-08', 2138);
      // Entries add up to the meal: 78 + 180 + 102 + 5 + 125 = 490 and
      // 330 + 205 + 122 + 119 = 776. The first entry of each meal carries
      // the macros of the whole meal: protein 20 and 66, carbs 34 and 86,
      // fat 30.2 and 18.3 (so the meals alone show 30 and 18, as the note says).
      await addMeal(localAt('2026-11-12', 8, 0), [
        {
          Nutrients.energy: 78,
          Nutrients.protein: 20,
          Nutrients.carbs: 34,
          Nutrients.fat: 30.2,
        },
        {Nutrients.energy: 180},
        {Nutrients.energy: 102},
        {Nutrients.energy: 5},
        {Nutrients.energy: 125},
      ]);
      await addMeal(localAt('2026-11-12', 12, 30), [
        {
          Nutrients.energy: 330,
          Nutrients.protein: 66,
          Nutrients.carbs: 86,
          Nutrients.fat: 18.3,
        },
        {Nutrients.energy: 205},
        {Nutrients.energy: 122},
        {Nutrients.energy: 119},
      ], slot: 'Lunch');
      await cardio(nov12, estimate: 383);
    }

    test('2,138 + 383 - 1,266 = 1,255, and every shown number', () async {
      await sampleDay();
      final b = await budget('2026-11-12');
      expect(b.foodKcal, 1266);
      expectShown(b, goal: 2138, addBack: 383, food: 1266, left: 1255);
      // 2,138 + 383 - 1,266 = 1,255 (2,138 + 383 = 2,521; 2,521 - 1,266).
      expect(b.left, 1255);
    });

    test('the meals and macros of the frame', () async {
      await sampleDay();
      final log = await db.loadDay('2026-11-12');
      expect([for (final m in log.meals) m.meal.id], hasLength(2));
      expect(
        [
          for (final m in log.meals)
            roundForDisplay(m.totals[Nutrients.energy]!),
        ],
        [490, 776],
      );
      // Protein 20 + 66 = 86, carbs 34 + 86 = 120, fat 30.2 + 18.3 = 48.5.
      expect(log.totals[Nutrients.protein], 86);
      expect(log.totals[Nutrients.carbs], 120);
      expect(log.totals[Nutrients.fat], closeTo(48.5, 1e-9));
      // The frame shows fat as 49, though the meals alone round to 30 and 18.
      expect(roundForDisplay(log.totals[Nutrients.fat]!), 49);
      expect(
        [for (final m in log.meals) roundForDisplay(m.totals[Nutrients.fat]!)],
        [30, 18],
      );
    });

    test('the same day at 50 percent add-back', () async {
      await sampleDay();
      await (db.update(db.goals))
          .write(const GoalsCompanion(exerciseAddBackPercent: Value(50)));
      final b = await budget('2026-11-12');
      // 383 x 50% = 191.5, shown 192. 2,138 + 192 - 1,266 = 1,064.
      expect(b.addBack, 191.5);
      expectShown(b, goal: 2138, addBack: 192, food: 1266, left: 1064);
    });

    test('the same day at 0 percent add-back', () async {
      await sampleDay();
      await (db.update(db.goals))
          .write(const GoalsCompanion(exerciseAddBackPercent: Value(0)));
      final b = await budget('2026-11-12');
      // 2,138 + 0 - 1,266 = 872.
      expectShown(b, goal: 2138, addBack: 0, food: 1266, left: 872);
    });

    test('with the goal worked out and saved, not put in', () async {
      // Weigh-in 181.8 lb = 82.4631 kg. 10 x 82.4631 = 824.631, plus
      // 6.25 x 180.34 = 1,127.125, minus 5 x 44 = 220, plus 5: 1,736.756.
      // x 1.375 = 2,388.04. Minus 250 (0.5 lb a week) = 2,138.04, stored 2,138.
      await weigh(181.8, '2026-11-08');
      await db.saveGoals(sample(), localAt('2026-11-08', 8, 0));
      await addMeal(localAt('2026-11-12', 8, 0), [
        {Nutrients.energy: 490},
      ]);
      await eat(localAt('2026-11-12', 12, 30), 776, slot: 'Lunch');
      await cardio(localAt('2026-11-12', 12, 0), estimate: 383);
      final b = await budget('2026-11-12');
      expectShown(b, goal: 2138, addBack: 383, food: 1266, left: 1255);
    });
  });

  group('2. a week with the goals changed in the middle', () {
    // Monday Nov 9 to Sunday Nov 15, 2026. The weigh-in is 181.8 lb.
    //   Sun Nov 8: no goals yet. Food and a run are logged.
    //   Mon Nov 9: goals saved, calculated 2,138, add-back 100%.
    //   Thu Nov 12: own number 1,800, add-back 50%.
    //   Sat Nov 14: back to calculated, staying the same, add-back 100%.
    // Calculated, staying the same: 2,388.04, stored 2,388.
    test('earlier days keep their goal, later days use the new one', () async {
      await weigh(181.8, '2026-11-05');
      // Before any goals: no budget, even with food and a run on the day.
      await eat(localAt('2026-11-08', 9, 0), 300);
      await cardio(localAt('2026-11-08', 10, 0), estimate: 200);

      await db.saveGoals(sample(), localAt('2026-11-09', 7, 30));
      await eat(localAt('2026-11-09', 8, 0), 500);
      await cardio(localAt('2026-11-09', 12, 0), estimate: 200);
      await eat(localAt('2026-11-10', 8, 0), 1000);
      // Nothing logged on Wednesday.

      Future<List<String>> week() async => [
        for (var d = 8; d <= 15; d++)
          switch (await db.budgetForDay(
            '2026-11-${d.toString().padLeft(2, '0')}',
          )) {
            null => 'none',
            final b =>
              '${b.shownGoal}/${b.shownAddBack}/${b.shownFood}/${b.shownLeft}',
          },
      ];
      final beforeChange = await week();
      // Sun none. Mon 2,138 + 200 - 500 = 1,838. Tue 2,138 + 0 - 1,000 = 1,138.
      // Wed 2,138. Thu to Sun: the same goal, nothing logged yet.
      expect(beforeChange, [
        'none',
        '2138/200/500/1838',
        '2138/0/1000/1138',
        '2138/0/0/2138',
        '2138/0/0/2138',
        '2138/0/0/2138',
        '2138/0/0/2138',
        '2138/0/0/2138',
      ]);

      // Thursday: own number 1,800, add-back 50%.
      await db.saveGoals(
        sample(own: 1800, addBack: 50),
        localAt('2026-11-12', 7, 30),
      );
      await cardio(localAt('2026-11-12', 12, 0), estimate: 383);
      await eat(localAt('2026-11-12', 8, 0), 490);
      await eat(localAt('2026-11-12', 12, 30), 776, slot: 'Lunch');

      final afterChange = await week();
      // Mon, Tue and Wed are exactly as they were.
      expect(afterChange.sublist(0, 4), beforeChange.sublist(0, 4));
      // Thu: 383 x 50% = 191.5, shown 192. 1,800 + 192 - 1,266 = 726.
      expect(afterChange[4], '1800/192/1266/726');
      // Fri to Sun: 1,800 and nothing logged.
      expect(afterChange.sublist(5), List.filled(3, '1800/0/0/1800'));

      // Saturday: calculated again, staying the same, add-back back to 100%.
      await db.saveGoals(
        sample(rate: WeeklyRate.stay),
        localAt('2026-11-14', 7, 30),
      );
      await eat(localAt('2026-11-14', 18, 0), 100, slot: 'Dinner');
      await lift(localAt('2026-11-14', 9, 0), override: 300);
      final end = await week();
      expect(end.sublist(0, 5), afterChange.sublist(0, 5));
      expect(end[5], '1800/0/0/1800'); // Friday is still the own number
      // Sat: 2,388 + 300 - 100 = 2,588. Sun: 2,388.
      expect(end[6], '2388/300/100/2588');
      expect(end[7], '2388/0/0/2388');
    });

    test('a day before any goals is null, not zero', () async {
      await goalRow('2026-11-09', 2138);
      await eat(localAt('2026-11-08', 9, 0), 300);
      expect(await db.budgetForDay('2026-11-08'), isNull);
      expect(await db.budgetForDay('2026-11-09'), isNotNull);
      expect(await db.goalsForDay('2026-11-08'), isNull);
    });
  });

  group('3. cardio deleted after the fact', () {
    test('the add-back goes and comes back', () async {
      await goalRow('2026-11-08', 2138);
      await eat(localAt('2026-11-12', 8, 0), 1266);
      final run = await cardio(localAt('2026-11-12', 12, 0), estimate: 383);

      expect(
        (await budget('2026-11-12')).shownLeft,
        1255,
      ); // 2,138 + 383 - 1,266
      await markDeleted(run, true);
      final gone = await budget('2026-11-12');
      expect(gone.exerciseKcal, 0);
      expect(gone.shownLeft, 872); // 2,138 + 0 - 1,266
      // Put back (Undo). The cardio data layer does not exist yet (task 5.2),
      // so this clears the deleted mark by hand. When 5.2 adds delete and
      // Undo, this should call them.
      await markDeleted(run, false);
      expect((await budget('2026-11-12')).shownLeft, 1255);
    });

    test('at 50 percent, and only the deleted session goes', () async {
      await goalRow('2026-11-08', 2138, addBack: 50);
      await eat(localAt('2026-11-12', 8, 0), 1266);
      final a = await cardio(localAt('2026-11-12', 7, 0), estimate: 383);
      await cardio(localAt('2026-11-12', 18, 0), override: 100);
      // Exercise 483, half is 241.5 shown 242: 2,138 + 242 - 1,266 = 1,114.
      var b = await budget('2026-11-12');
      expectShown(b, goal: 2138, addBack: 242, food: 1266, left: 1114);
      await markDeleted(a, true);
      // Exercise 100, half is 50: 2,138 + 50 - 1,266 = 922.
      b = await budget('2026-11-12');
      expectShown(b, goal: 2138, addBack: 50, food: 1266, left: 922);
    });

    test('deleting a row for good gives the same budget', () async {
      await goalRow('2026-11-08', 2138);
      final run = await cardio(localAt('2026-11-12', 12, 0), estimate: 383);
      expect((await budget('2026-11-12')).shownLeft, 2521);
      await (db.delete(db.cardioSessions)..where((c) => c.id.equals(run))).go();
      expect((await budget('2026-11-12')).shownLeft, 2138);
    });
  });

  group('4. cardio and resistance on one day', () {
    setUp(() => goalRow('2026-11-08', 2000));

    test('both are counted, each with its own number first', () async {
      // Run: typed 400, estimate 383, so 400. Workout: typed 250, estimate
      // 200, so 250. Exercise 650, all added back at 100%: 2,000 + 650.
      await cardio(localAt('2026-11-12', 12, 0), override: 400, estimate: 383);
      await lift(localAt('2026-11-12', 17, 0), override: 250, estimate: 200);
      final b = await budget('2026-11-12');
      expect(b.exerciseKcal, 650);
      expectShown(b, goal: 2000, addBack: 650, food: 0, left: 2650);
    });

    test('a typed number wins even when it is lower', () async {
      // Typed 60 against estimates of 999 and 888: 60 + 70 = 130.
      await cardio(localAt('2026-11-12', 12, 0), override: 60, estimate: 999);
      await lift(localAt('2026-11-12', 17, 0), override: 70, estimate: 888);
      expect((await budget('2026-11-12')).exerciseKcal, 130);
    });

    test('estimates alone are added', () async {
      // 383 + 150 = 533.
      await cardio(localAt('2026-11-12', 12, 0), estimate: 383);
      await lift(localAt('2026-11-12', 17, 0), estimate: 150);
      expect((await budget('2026-11-12')).exerciseKcal, 533);
    });

    test('a session with neither number counts zero', () async {
      await cardio(localAt('2026-11-12', 12, 0));
      await lift(localAt('2026-11-12', 17, 0));
      final b = await budget('2026-11-12');
      expect(b.exerciseKcal, 0);
      expectShown(b, goal: 2000, addBack: 0, food: 0, left: 2000);
    });

    test('a session with neither does not hide the other one', () async {
      await cardio(localAt('2026-11-12', 12, 0));
      await lift(localAt('2026-11-12', 17, 0), estimate: 200);
      expect((await budget('2026-11-12')).exerciseKcal, 200);
    });

    test('at 50 percent the sum is halved once', () async {
      await db
          .update(db.goals)
          .write(const GoalsCompanion(exerciseAddBackPercent: Value(50)));
      // (400 + 251) / 2 = 325.5, shown 326.
      await cardio(localAt('2026-11-12', 12, 0), override: 400);
      await lift(localAt('2026-11-12', 17, 0), estimate: 251);
      final b = await budget('2026-11-12');
      expect(b.addBack, 325.5);
      expect(b.shownAddBack, 326);
    });
  });

  group('5. days are separate', () {
    test(
      'food, exercise and goals of the next and last day stay out',
      () async {
        // Goals start on Nov 11 (2,000), Nov 12 (2,138) and Nov 13 (1,800).
        await goalRow('2026-11-11', 2000);
        await goalRow('2026-11-12', 2138);
        await goalRow('2026-11-13', 1800);

        // Nov 11: a meal at 23:59 local (UTC Nov 12 05:59, so UTC has already
        // turned over, local has not), a run 500 and a workout 150.
        await eat(utcAt(2026, 11, 12, 5, 59, cst), 700);
        await cardio(localAt('2026-11-11', 9, 0), estimate: 500);
        await lift(localAt('2026-11-11', 18, 0), estimate: 150);
        // Nov 12: meals at 00:00 sharp (100) and 20:00 (200; UTC Nov 13 02:00),
        // a run of 300 and a workout of 50 at 23:59.
        await eat(localAt('2026-11-12', 0, 0), 100);
        await eat(utcAt(2026, 11, 13, 2, 0, cst), 200, slot: 'Dinner');
        await cardio(localAt('2026-11-12', 12, 0), estimate: 300);
        await lift(localAt('2026-11-12', 23, 59), override: 50);
        // Nov 13: meals at 00:00 sharp (800), a run 600 and a workout 250.
        await eat(localAt('2026-11-13', 0, 0), 800);
        await cardio(localAt('2026-11-13', 7, 0), estimate: 600);
        await lift(localAt('2026-11-13', 19, 0), estimate: 250);

        // Nov 12: food 100 + 200 = 300, exercise 300 + 50 = 350.
        // 2,138 + 350 - 300 = 2,188.
        expectShown(
          await budget('2026-11-12'),
          goal: 2138,
          addBack: 350,
          food: 300,
          left: 2188,
        );
        // Nov 11: exercise 500 + 150 = 650. 2,000 + 650 - 700 = 1,950.
        expectShown(
          await budget('2026-11-11'),
          goal: 2000,
          addBack: 650,
          food: 700,
          left: 1950,
        );
        // Nov 13: exercise 600 + 250 = 850. 1,800 + 850 - 800 = 1,850.
        expectShown(
          await budget('2026-11-13'),
          goal: 1800,
          addBack: 850,
          food: 800,
          left: 1850,
        );
      },
    );

    test(
      'the day the clocks go back (Nov 1, 2026) is one 25 hour day',
      () async {
        // In Chicago the clocks go from 02:00 CDT back to 01:00 CST on Nov 1.
        // Each instant is checked against the local date written by hand.
        final instants = <(Now, String, double)>[
          // Oct 31 23:59 CDT is UTC Nov 1 04:59: the UTC date is Nov 1.
          (utcAt(2026, 11, 1, 4, 59, cdt), '2026-10-31', 111),
          // Nov 1 00:00 CDT is UTC 05:00, the first minute of the day.
          (utcAt(2026, 11, 1, 5, 0, cdt), '2026-11-01', 200),
          // 01:30 CDT, then one hour later 01:30 CST: same wall clock twice.
          (utcAt(2026, 11, 1, 6, 30, cdt), '2026-11-01', 300),
          (utcAt(2026, 11, 1, 7, 30, cst), '2026-11-01', 400),
          // Nov 1 23:59 CST is UTC Nov 2 05:59.
          (utcAt(2026, 11, 2, 5, 59, cst), '2026-11-01', 500),
          // Nov 2 00:01 CST is UTC 06:01.
          (utcAt(2026, 11, 2, 6, 1, cst), '2026-11-02', 700),
        ];
        for (final (now, day, kcal) in instants) {
          expect(now.localDate, day, reason: '$kcal kcal');
        }
        await goalRow('2026-10-30', 2000);
        for (final (now, _, kcal) in instants) {
          await eat(now, kcal);
          await cardio(now, estimate: kcal / 10);
        }
        // Oct 31: food 111, run 11.1. 2,000 + 11.1 - 111 = 1,900.1.
        var b = await budget('2026-10-31');
        expectShown(b, goal: 2000, addBack: 11, food: 111, left: 1900);
        // Nov 1: food 200 + 300 + 400 + 500 = 1,400, runs 20 + 30 + 40 + 50 = 140.
        // 2,000 + 140 - 1,400 = 740.
        b = await budget('2026-11-01');
        expectShown(b, goal: 2000, addBack: 140, food: 1400, left: 740);
        // Nov 2: food 700, run 70. 2,000 + 70 - 700 = 1,370.
        b = await budget('2026-11-02');
        expectShown(b, goal: 2000, addBack: 70, food: 700, left: 1370);
      },
    );

    test(
      'the day the clocks go forward (Mar 8, 2026) is one 23 hour day',
      () async {
        // 02:00 CST becomes 03:00 CDT on Mar 8.
        final instants = <(Now, String, double)>[
          // Mar 7 23:59 CST is UTC Mar 8 05:59.
          (utcAt(2026, 3, 8, 5, 59, cst), '2026-03-07', 100),
          // Mar 8 00:00 CST is UTC 06:00, and 01:59 CST is UTC 07:59.
          (utcAt(2026, 3, 8, 6, 0, cst), '2026-03-08', 200),
          (utcAt(2026, 3, 8, 7, 59, cst), '2026-03-08', 300),
          // 03:00 CDT is UTC 08:00, the very next minute.
          (utcAt(2026, 3, 8, 8, 0, cdt), '2026-03-08', 400),
          // Mar 8 23:59 CDT is UTC Mar 9 04:59.
          (utcAt(2026, 3, 9, 4, 59, cdt), '2026-03-08', 500),
          // Mar 9 00:00 CDT is UTC 05:00.
          (utcAt(2026, 3, 9, 5, 0, cdt), '2026-03-09', 600),
        ];
        for (final (now, day, kcal) in instants) {
          expect(now.localDate, day, reason: '$kcal kcal');
        }
        await goalRow('2026-03-01', 2000);
        for (final (now, _, kcal) in instants) {
          await eat(now, kcal);
          await lift(now, override: kcal / 10);
        }
        // Mar 7: food 100, workout 10: 2,000 + 10 - 100 = 1,910.
        expectShown(
          await budget('2026-03-07'),
          goal: 2000,
          addBack: 10,
          food: 100,
          left: 1910,
        );
        // Mar 8: food 200 + 300 + 400 + 500 = 1,400, workouts 140.
        // 2,000 + 140 - 1,400 = 740.
        expectShown(
          await budget('2026-03-08'),
          goal: 2000,
          addBack: 140,
          food: 1400,
          left: 740,
        );
        // Mar 9: food 600, workout 60: 2,000 + 60 - 600 = 1,460.
        expectShown(
          await budget('2026-03-09'),
          goal: 2000,
          addBack: 60,
          food: 600,
          left: 1460,
        );
      },
    );

    test('a goals save near midnight starts on the local day', () async {
      // Oct 31 23:59 CDT is already Nov 1 in UTC. The goal starts Oct 31.
      await db.saveGoals(sample(own: 2000), utcAt(2026, 11, 1, 4, 59, cdt));
      // Nov 1 01:30 CST (the second 01:30) saves a new number from Nov 1.
      await db.saveGoals(sample(own: 1900), utcAt(2026, 11, 1, 7, 30, cst));
      expect((await db.goalsForDay('2026-10-31'))!.calories, 2000);
      expect((await db.goalsForDay('2026-10-31'))!.effectiveFrom, '2026-10-31');
      expect((await db.goalsForDay('2026-11-01'))!.calories, 1900);
      expect(await db.goalsForDay('2026-10-30'), isNull);
    });
  });

  group('6. the budget stream', () {
    test('emits again after every kind of change', () async {
      final seen = <double?>[];
      final sub = db
          .watchBudgetForDay('2026-11-12')
          .listen((b) => seen.add(b?.left));
      await settle();
      // No goals yet. The first open of a new database fills the meal slots,
      // which can repeat the first answer a few times, so only check it is
      // always null.
      expect(seen, isNotEmpty);
      expect(seen.every((v) => v == null), isTrue);

      Future<void> step(
        String what,
        Future<void> Function() change,
        double? left,
      ) async {
        final before = seen.length;
        await change();
        await settle();
        expect(seen.length, greaterThan(before), reason: what);
        expect(seen.last, left, reason: what);
      }

      await step('goals saved', () async {
        await db.saveGoals(sample(own: 2138), localAt('2026-11-12', 7, 0));
      }, 2138);
      late int a, run, workout;
      await step('meal added', () async {
        a = await eat(localAt('2026-11-12', 8, 0), 490);
      }, 1648); // 2,138 - 490
      await step('meal edited', () => setMealKcal(a, 600), 1538); // 2,138 - 600
      await step('second meal added', () async {
        await eat(localAt('2026-11-12', 12, 30), 776, slot: 'Lunch');
      }, 762); // 2,138 - 600 - 776
      await step('meal deleted', () async {
        await db.deleteMeal(a);
      }, 1362); // 2,138 - 776
      await step('cardio added', () async {
        run = await cardio(localAt('2026-11-12', 12, 0), estimate: 383);
      }, 1745); // 1,362 + 383
      await step('workout added', () async {
        workout = await lift(localAt('2026-11-12', 17, 0), override: 100);
      }, 1845); // 1,745 + 100
      await step('cardio deleted', () => markDeleted(run, true), 1462); // - 383
      await step('cardio put back', () => markDeleted(run, false), 1845);
      await step('workout deleted', () async {
        await (db.delete(db.workouts)..where((w) => w.id.equals(workout))).go();
      }, 1745); // 1,845 - 100
      await step('cardio removed', () async {
        await (db.delete(
          db.cardioSessions,
        )..where((c) => c.id.equals(run))).go();
      }, 1362); // 1,745 - 383
      await step('goals saved again', () async {
        await db.saveGoals(sample(own: 1800), localAt('2026-11-12', 21, 0));
      }, 1024); // 1,800 - 776
      await sub.cancel();
    });

    test('with exceptMealId that meal is out and the rest stays', () async {
      await goalRow('2026-11-08', 2138);
      final a = await eat(localAt('2026-11-12', 8, 0), 490);
      final b = await eat(localAt('2026-11-12', 12, 30), 776, slot: 'Lunch');
      await eat(localAt('2026-11-12', 15, 0), 130, slot: 'Snack');
      await cardio(localAt('2026-11-12', 12, 0), estimate: 383);

      final seen = <DayBudget?>[];
      final sub = db
          .watchBudgetForDay('2026-11-12', exceptMealId: b)
          .listen(seen.add);
      await settle();
      // Food without the lunch: 490 + 130 = 620. Goal and run stay.
      expect(seen.last!.foodKcal, 620);
      expect(seen.last!.goal, 2138);
      expect(seen.last!.exerciseKcal, 383);
      expect(seen.last!.shownLeft, 1901); // 2,138 + 383 - 620

      await eat(localAt('2026-11-12', 19, 0), 100, slot: 'Dinner');
      await settle();
      expect(seen.last!.foodKcal, 720); // 620 + 100
      expect(seen.last!.shownLeft, 1801);

      await setMealKcal(b, 900); // editing the excepted meal changes nothing
      await settle();
      expect(seen.last!.foodKcal, 720);

      await setMealKcal(a, 300); // editing another meal does: 300 + 130 + 100
      await settle();
      expect(seen.last!.foodKcal, 530);

      await db.deleteMeal(a); // 130 + 100
      await settle();
      expect(seen.last!.foodKcal, 230);
      expect(seen.last!.shownLeft, 2291); // 2,138 + 383 - 230
      await sub.cancel();
    });
  });

  group('7. Recalculate after a new weigh-in', () {
    test('changes the goal from that day on, not before', () async {
      await weigh(181.8, '2026-11-08');
      await db.saveGoals(sample(), localAt('2026-11-08', 8, 0)); // 2,138
      await eat(localAt('2026-11-10', 8, 0), 1500);
      await cardio(localAt('2026-11-11', 12, 0), estimate: 383);
      await eat(localAt('2026-11-11', 8, 0), 1266);
      await eat(localAt('2026-11-12', 8, 0), 490);

      Future<List<String>> days() async => [
        for (final d in [
          '2026-11-08',
          '2026-11-10',
          '2026-11-11',
          '2026-11-12',
        ])
          switch (await db.budgetForDay(d)) {
            null => 'none',
            final b =>
              '${b.shownGoal}/${b.shownAddBack}/${b.shownFood}/${b.shownLeft}',
          },
      ];
      expect(await days(), [
        '2138/0/0/2138',
        '2138/0/1500/638',
        '2138/383/1266/1255',
        '2138/0/490/1648',
      ]);

      // A new weigh-in: 160 lb = 72.5748 kg. 725.748 + 1,127.125 - 220 + 5
      // = 1,637.873; x 1.375 = 2,252.075; minus 250 = 2,002.075, stored 2,002.
      await weigh(160, '2026-11-12');
      final again = await db.recalculateGoals(localAt('2026-11-12', 9, 0));
      expect(again.calories, 2002);
      expect(again.effectiveFrom, '2026-11-12');

      expect(await days(), [
        '2138/0/0/2138',
        '2138/0/1500/638',
        '2138/383/1266/1255',
        // Nov 12 is the only day that moved: 2,002 + 0 - 490 = 1,512.
        '2002/0/490/1512',
      ]);
      // A day after still uses the new number.
      expect((await budget('2026-11-14')).shownGoal, 2002);
    });
  });

  group('8. rounding', () {
    // Meals of 270.7, 34.84 and 85.96 kcal add up to exactly 391.5. In some
    // orders the computer's sum is 391.49999999999994, in others 391.5.
    // Food shows 392 (half goes up) whatever the order they were logged.
    const parts = [270.7, 34.84, 85.96];
    const orders = [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [1, 2, 0],
      [2, 0, 1],
      [2, 1, 0],
    ];

    Future<void> freshDb() async {
      await db.close();
      db = AppDatabase(NativeDatabase.memory());
    }

    Future<DayBudget> logInOrder(List<int> order) async {
      await freshDb();
      await goalRow('2026-11-08', 2000);
      for (var i = 0; i < order.length; i++) {
        // Same slot, logged a minute apart, so the day's sum adds them in
        // exactly this order.
        await eat(localAt('2026-11-12', 8, i), parts[order[i]]);
      }
      return budget('2026-11-12');
    }

    test('the same numbers shown in every order', () async {
      final raw = <double>{};
      for (final order in orders) {
        final b = await logInOrder(order);
        raw.add(b.foodKcal);
        // 270.7 + 34.84 + 85.96 = 391.50. Shown 392. 2,000 - 392 = 1,608.
        expectShown(b, goal: 2000, addBack: 0, food: 392, left: 1608);
      }
      // The test would prove nothing if every order added up the same, so
      // check the sums really do differ in the last digits.
      expect(raw.length, greaterThan(1), reason: 'orders should differ');
    });

    test('the same numbers shown when the meals are in other slots', () async {
      const slots = ['Breakfast', 'Lunch', 'Dinner'];
      for (final order in orders) {
        await freshDb();
        await goalRow('2026-11-08', 2000);
        for (var i = 0; i < 3; i++) {
          // The slot decides the order the day adds them: slot order wins.
          await eat(
            localAt('2026-11-12', 8, 0),
            parts[i],
            slot: slots[order[i]],
          );
        }
        final b = await budget('2026-11-12');
        expectShown(b, goal: 2000, addBack: 0, food: 392, left: 1608);
      }
    });

    test('a number really under a half still rounds down', () async {
      await goalRow('2026-11-08', 2000);
      await eat(localAt('2026-11-12', 8, 0), 391.49);
      // 391.49 shown 391. 2,000 - 391 = 1,609.
      expectShown(
        await budget('2026-11-12'),
        goal: 2000,
        addBack: 0,
        food: 391,
        left: 1609,
      );
    });

    // goal, exercise, add-back percent, food, then the four shown numbers.
    // Half rounds up (away from zero). Left is always goal + add-back - food
    // of the shown numbers. Each row is worked out by hand.
    final cases = <(double, double, int, double, int, int, int, int)>[
      // The sample day: 2,138 + 383 - 1,266.
      (2138, 383, 100, 1266, 2138, 383, 1266, 1255),
      // 383 x 50% = 191.5 shown 192: 2,138 + 192 - 1,266.
      (2138, 383, 50, 1266, 2138, 192, 1266, 1064),
      // 0%: 2,138 - 1,266.
      (2138, 383, 0, 1266, 2138, 0, 1266, 872),
      // Nothing eaten, nothing done.
      (2000, 0, 100, 0, 2000, 0, 0, 2000),
      // Over budget: 1,800 - 2,100.4 (shown 2,100) = -300.
      (1800, 0, 100, 2100.4, 1800, 0, 2100, -300),
      // Over with an add-back: 250.5 x 50% = 125.25 shown 125; food 2,300.5
      // shown 2,301: 1,800 + 125 - 2,301 = -376.
      (1800, 250.5, 50, 2300.5, 1800, 125, 2301, -376),
      // Food on exactly a half goes up: 391.5 shown 392.
      (2000, 0, 100, 391.5, 2000, 0, 392, 1608),
      // 1 x 50% = 0.5 shown 1: 1,500 + 1 - 0.
      (1500, 1, 50, 0, 1500, 1, 0, 1501),
      // Just under a half stays down: food 100.49999999 shown 100.
      (1500, 0, 100, 100.49999999, 1500, 0, 100, 1400),
      // Both halves: 333 x 50% = 166.5 shown 167; food 1,000.5 shown
      // 1,001: 1,200 + 167 - 1,001 = 366.
      (1200, 333, 50, 1000.5, 1200, 167, 1001, 366),
      // Exactly on budget: 2,500 + 1,000 - 3,500.
      (2500, 1000, 100, 3500, 2500, 1000, 3500, 0),
      // 99.5 shown 100 and 1,899.5 shown 1,900: 1,800 + 100 - 1,900 = 0.
      (1800, 99.5, 100, 1899.5, 1800, 100, 1900, 0),
      // A small run rounds to nothing: 0.4 shown 0.
      (1500, 0.4, 100, 0.4, 1500, 0, 0, 1500),
      // 383.5 x 50% = 191.75 shown 192; food 1,266.4 shown 1,266.
      (2138, 383.5, 50, 1266.4, 2138, 192, 1266, 1064),
      // Far over with no add-back: 1,200 - 5,000.
      (1200, 800, 0, 5000, 1200, 0, 5000, -3800),
      // Over where the unrounded left would show 1 less than the parts:
      // goal 1,000, add-back 0.5 shown 1, food 1,000.5 shown 1,001:
      // shown 1,000 + 1 - 1,001 = 0 (the true left is 0).
      (1000, 1, 50, 1000.5, 1000, 1, 1001, 0),
    ];

    test('the line adds up in sixteen hand-picked cases', () {
      for (final c in cases) {
        final b = DayBudget(
          goal: c.$1,
          exerciseKcal: c.$2,
          addBackPercent: c.$3,
          foodKcal: c.$4,
        );
        final why = 'goal ${c.$1}, exercise ${c.$2}, ${c.$3}%, food ${c.$4}';
        expectShown(b, goal: c.$5, addBack: c.$6, food: c.$7, left: c.$8);
        expect(
          b.shownGoal + b.shownAddBack - b.shownFood,
          b.shownLeft,
          reason: why,
        );
      }
      expect(cases.length, greaterThanOrEqualTo(12));
    });
  });
}
