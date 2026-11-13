// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart';

import '../clock.dart';
import '../math/calorie_budget.dart';
import 'database.dart';
import 'food_data.dart';
import 'nutrients.dart';

// Goals and the day's calorie budget. Goals are saved by the day they start
// ("effective from"). A day uses the row with the latest start on or before
// it, so changing goals never changes a past day. No user-facing text here.
//
// What the goals row holds:
// - calories: the calorie goal in use, a whole number, in both modes. In
//   'calculated' mode it is the number worked out when Goals was saved (or
//   Recalculate was tapped), so effectiveFrom is also the day it was worked
//   out. In 'fixed' mode it is the number the user typed.
// - activityFactor and targetKgPerWeek: the inputs, kept in both modes, so
//   turning "my own number" off brings the calculation back.
// - macroMode 'grams': proteinTarget, carbsTarget, fatTarget are grams.
//   'percent': they are whole percents of calories. All three are set or all
//   three are null (no macro goals).
// The person (sex, birth date, height) is the one profile row, not part of a
// goal. Weight is never stored in a goal: it is read from the weigh-ins.

/// Why a goals save was refused. Carries no user data.
enum GoalProblem {
  /// A calculated goal needs a weigh-in on or before the day.
  needsWeight,

  /// A calculated goal needs sex, birth date and height.
  needsProfile,

  /// The user's own calorie number is zero or less.
  ownNumberNotPositive,

  /// Some but not all of the three macro targets were given, or one is
  /// negative.
  macrosIncomplete,

  /// The exercise add-back is not 0, 50 or 100.
  badAddBack,

  /// The rate is not one of the ten offered rates.
  badRate,

  /// Recalculate was asked for before any goals were saved.
  noGoals,
}

class GoalRefused implements Exception {
  const GoalRefused(this.problem);

  final GoalProblem problem;

  @override
  String toString() => 'GoalRefused(${problem.name})';
}

enum MacroMode { grams, percent }

/// What the Goals screen hands to [GoalData.saveGoals].
class GoalInput {
  const GoalInput({
    this.sex,
    this.birthDate,
    this.heightCm,
    required this.activity,
    required this.rate,
    this.ownCalories,
    this.addBackPercent = 100,
    this.macroMode = MacroMode.grams,
    this.protein,
    this.carbs,
    this.fat,
    this.nutrientOverrides,
  });

  /// The person, saved to the profile row. Null leaves what is stored as it is.
  /// Sex, birth date ('YYYY-MM-DD') and height in cm are all needed for a
  /// calculated goal.
  final Sex? sex;
  final String? birthDate;
  final double? heightCm;

  final ActivityLevel activity;
  final WeeklyRate rate;

  /// The user's own calorie goal. Null means use the calculation. The
  /// activity and rate are kept either way.
  final int? ownCalories;

  /// 0, 50 or 100.
  final int addBackPercent;

  /// [protein], [carbs] and [fat] are grams or whole percents by [macroMode].
  /// All three or none.
  final MacroMode macroMode;
  final double? protein;
  final double? carbs;
  final double? fat;

  /// Goals the user changed from the Daily Value, by nutrient id. Null keeps
  /// what applied before (nothing, for the first save). An empty map clears
  /// them.
  final Map<int, double>? nutrientOverrides;
}

/// Default goals for the "Other nutrients" list: the Daily Value of every
/// tracked nutrient that has one, except calories, protein, carbs and fat,
/// whose goals are in the goals row.
Map<int, double> defaultNutrientGoals() => {
  for (final e in Nutrients.dailyValues.entries)
    if (!_inGoalsRow.contains(e.key)) e.key: e.value,
};

const _inGoalsRow = {
  Nutrients.energy,
  Nutrients.protein,
  Nutrients.carbs,
  Nutrients.fat,
};

/// The goals that apply to one day, read back from the database.
class GoalsForDay {
  const GoalsForDay(this.row, this.nutrientOverrides);

  final Goal row;

  /// Nutrient goals the user changed, by nutrient id.
  final Map<int, double> nutrientOverrides;

  /// The day these goals start. For a calculated goal, also the day it was
  /// worked out ("Calculated Nov 8").
  String get effectiveFrom => row.effectiveFrom;

  /// True when the calorie goal is the user's own number.
  bool get isOwnNumber => row.calorieMode == 'fixed';

  /// The calorie goal in use, in both modes.
  int? get calories => row.calories;

  ActivityLevel? get activity => ActivityLevel.fromFactor(row.activityFactor);
  WeeklyRate? get rate => WeeklyRate.fromKgPerWeek(row.targetKgPerWeek);
  int get addBackPercent => row.exerciseAddBackPercent;
  MacroMode get macroMode =>
      row.macroMode == 'percent' ? MacroMode.percent : MacroMode.grams;

  /// The macro goals in grams, with kcal and the difference from [calories],
  /// or null when no macro goals are set. In percent mode the grams follow
  /// the calorie goal.
  MacroBreakdown? get macros {
    final p = row.proteinTarget, c = row.carbsTarget, f = row.fatTarget;
    if (p == null || c == null || f == null) return null;
    if (macroMode == MacroMode.grams) {
      return MacroBreakdown(proteinG: p, carbsG: c, fatG: f);
    }
    final kcal = calories;
    if (kcal == null) return null;
    try {
      return macrosFromPercent(
        calories: kcal.toDouble(),
        proteinPercent: p.round(),
        carbsPercent: c.round(),
        fatPercent: f.round(),
      );
    } on PercentsDontAddUp {
      return null;
    }
  }

  /// Goals for the "Other nutrients" list: Daily Values, with the user's
  /// changes on top.
  Map<int, double> get nutrientGoals => {
    ...defaultNutrientGoals(),
    ...nutrientOverrides,
  };
}

extension GoalData on AppDatabase {
  // Profile

  Future<ProfileData?> getProfile() =>
      (select(profile)..where((p) => p.id.equals(1))).getSingleOrNull();

  // Reading goals

  /// The goals that apply to [localDate] ('YYYY-MM-DD'): the row with the
  /// latest start on or before it. Null before any goals exist (no budget,
  /// not a zero one).
  Future<GoalsForDay?> goalsForDay(String localDate) async {
    final row =
        await (select(goals)
              ..where((g) => g.effectiveFrom.isSmallerOrEqualValue(localDate))
              ..orderBy([(g) => OrderingTerm.desc(g.effectiveFrom)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    final overrides = await (select(
      goalNutrients,
    )..where((n) => n.goalId.equals(row.id))).get();
    return GoalsForDay(row, {
      for (final n in overrides) n.nutrientId: n.targetAmount,
    });
  }

  /// The goals for the day, again after every change to them.
  Stream<GoalsForDay?> watchGoalsForDay(String localDate) =>
      liveQuery(this, [goals, goalNutrients], () => goalsForDay(localDate));

  /// The latest weigh-in on or before [localDate] that is not deleted, or
  /// null. This is the weight a goal is calculated from.
  Future<WeightEntry?> weightOnOrBefore(String localDate) =>
      (select(weightEntries)
            ..where(
              (w) =>
                  w.localDate.isSmallerOrEqualValue(localDate) &
                  w.deletedAtMs.isNull(),
            )
            ..orderBy([
              (w) => OrderingTerm.desc(w.localDate),
              (w) => OrderingTerm.desc(w.measuredAtMs),
              (w) => OrderingTerm.desc(w.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  // Saving goals

  /// Saves goals from today ([now]'s local date). Saving again on the same day
  /// updates that day's row. Past days keep their goals.
  ///
  /// A calculated goal is worked out now from the latest weigh-in on or
  /// before today and stored (rounded to a whole number). With
  /// [GoalInput.ownCalories] the number typed is stored instead and the
  /// inputs are kept. Returns the goals read back. Throws [GoalRefused] or
  /// [PercentsDontAddUp]; nothing is written then.
  Future<GoalsForDay> saveGoals(GoalInput input, Now now) {
    final day = now.localDate;
    return transaction(() async {
      final own = input.ownCalories;
      if (own != null && own <= 0) {
        throw const GoalRefused(GoalProblem.ownNumberNotPositive);
      }
      if (!addBackChoices.contains(input.addBackPercent)) {
        throw const GoalRefused(GoalProblem.badAddBack);
      }
      if (WeeklyRate.fromKgPerWeek(input.rate.kgPerWeek) == null) {
        throw const GoalRefused(GoalProblem.badRate);
      }
      final macros = [input.protein, input.carbs, input.fat];
      final given = macros.where((m) => m != null).length;
      if (given != 0 && given != 3 || macros.any((m) => m != null && m < 0)) {
        throw const GoalRefused(GoalProblem.macrosIncomplete);
      }
      if (given == 3 && input.macroMode == MacroMode.percent) {
        final p = macros.map((m) => m!).toList();
        if (p.any((v) => v != v.roundToDouble())) {
          throw const PercentsDontAddUp();
        }
        if (percentLeft(p[0].round(), p[1].round(), p[2].round()) != 0) {
          throw const PercentsDontAddUp();
        }
      }

      final stored = await getProfile();
      final sex = input.sex ?? _sexOf(stored?.sex);
      final birthDate = input.birthDate ?? stored?.birthDate;
      final heightCm = input.heightCm ?? stored?.heightCm;

      final int calories;
      if (own != null) {
        calories = own;
      } else {
        if (sex == null || birthDate == null || heightCm == null) {
          throw const GoalRefused(GoalProblem.needsProfile);
        }
        final weight = await weightOnOrBefore(day);
        if (weight == null) throw const GoalRefused(GoalProblem.needsWeight);
        calories = roundForDisplay(
          calorieWorking(
            sex: sex,
            birthDate: birthDate,
            day: day,
            weightKg: weight.weightKg,
            heightCm: heightCm,
            activity: input.activity,
            rate: input.rate,
          ).goal,
        );
      }

      await into(profile).insertOnConflictUpdate(
        ProfileCompanion(
          id: const Value(1),
          sex: Value(sex?.name),
          birthDate: Value(birthDate),
          heightCm: Value(heightCm),
        ),
      );

      final previous = await goalsForDay(day);
      final values = GoalsCompanion(
        effectiveFrom: Value(day),
        calorieMode: Value(own != null ? 'fixed' : 'calculated'),
        calories: Value(calories),
        activityFactor: Value(input.activity.factor),
        targetKgPerWeek: Value(input.rate.kgPerWeek),
        exerciseAddBackPercent: Value(input.addBackPercent),
        macroMode: Value(input.macroMode.name),
        proteinTarget: Value(input.protein),
        carbsTarget: Value(input.carbs),
        fatTarget: Value(input.fat),
      );
      final int id;
      if (previous != null && previous.effectiveFrom == day) {
        id = previous.row.id;
        await (update(goals)..where((g) => g.id.equals(id))).write(values);
      } else {
        id = await into(goals).insert(values);
      }

      final overrides = input.nutrientOverrides ?? previous?.nutrientOverrides;
      if (overrides != null) {
        await (delete(goalNutrients)..where((n) => n.goalId.equals(id))).go();
        for (final e in overrides.entries) {
          await into(goalNutrients).insert(
            GoalNutrientsCompanion.insert(
              goalId: id,
              nutrientId: e.key,
              targetAmount: e.value,
            ),
          );
        }
      }
      return (await goalsForDay(day))!;
    });
  }

  /// Recalculate: works the calorie goal out again from the latest weigh-in
  /// on or before today, with the goals now in effect, and saves it from
  /// today. Everything else is kept. Past days keep theirs. If the goal in
  /// effect is the user's own number there is nothing to recalculate and it is
  /// returned unchanged. Throws [GoalRefused] with [GoalProblem.noGoals]
  /// before any goals exist.
  Future<GoalsForDay> recalculateGoals(Now now) => transaction(() async {
    final current = await goalsForDay(now.localDate);
    if (current == null) throw const GoalRefused(GoalProblem.noGoals);
    if (current.isOwnNumber) return current;
    final r = current.row;
    return saveGoals(
      GoalInput(
        activity: current.activity ?? ActivityLevel.sedentary,
        rate: current.rate ?? WeeklyRate.stay,
        addBackPercent: current.addBackPercent,
        macroMode: current.macroMode,
        protein: r.proteinTarget,
        carbs: r.carbsTarget,
        fat: r.fatTarget,
      ),
      now,
    );
  });

  // The day's budget

  /// The day's exercise in kcal: for each cardio session and each workout on
  /// the day, the user's number if there is one, else the estimate, else 0.
  /// Deleted cardio is left out.
  Future<double> exerciseKcalForDay(String localDate) async {
    final cardio =
        await (select(cardioSessions)..where(
              (c) => c.localDate.equals(localDate) & c.deletedAtMs.isNull(),
            ))
            .get();
    final lifting = await (select(
      workouts,
    )..where((w) => w.localDate.equals(localDate))).get();
    var total = 0.0;
    for (final c in cardio) {
      total += c.kcalOverride ?? c.kcalEstimated ?? 0;
    }
    for (final w in lifting) {
      total += w.kcalOverride ?? w.kcalEstimated ?? 0;
    }
    return total;
  }

  /// The day's budget: the goal for that day, plus the add-back share of the
  /// day's exercise, minus the day's food. Null before any goals exist.
  Future<DayBudget?> budgetForDay(String localDate) => transaction(() async {
    final g = await goalsForDay(localDate);
    final goal = g?.calories;
    if (g == null || goal == null) return null;
    final food = (await loadDay(localDate)).totals[Nutrients.energy] ?? 0;
    return DayBudget(
      goal: goal.toDouble(),
      exerciseKcal: await exerciseKcalForDay(localDate),
      addBackPercent: g.addBackPercent,
      foodKcal: food,
    );
  });

  /// The day's budget, again after any change to goals, food or exercise.
  Stream<DayBudget?> watchBudgetForDay(String localDate) => liveQuery(this, [
    goals,
    cardioSessions,
    workouts,
    meals,
    mealEntries,
    mealEntryNutrients,
    mealSlots,
  ], () => budgetForDay(localDate));

  Sex? _sexOf(String? name) => switch (name) {
    'male' => Sex.male,
    'female' => Sex.female,
    _ => null,
  };
}
