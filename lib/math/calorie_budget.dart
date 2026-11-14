// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import '../util/dates.dart';
import '../util/units.dart';

// The calorie goal and the day's budget. Pure functions: no database, no
// Flutter. Every number keeps full precision. Only a number meant to be shown
// or stored as a whole number goes through [roundForDisplay], so a rounded
// intermediate can never leak into a later step.

/// The one place a number is rounded for showing (and for storing the
/// calculated goal, which is shown). Half rounds away from zero. The value is
/// first rounded to 8 decimal places, so the noise that adding in a different
/// order leaves (391.49999999999994 against 391.5) cannot change the result.
/// A number that is really under a half, like 0.4999999, still rounds down.
int roundForDisplay(double value) =>
    ((value * 1e8).roundToDouble() / 1e8).round();

enum Sex { male, female }

/// How active the user is outside logged workouts, with its multiplier.
enum ActivityLevel {
  sedentary(1.2),
  lightlyActive(1.375),
  moderatelyActive(1.55),
  veryActive(1.725),
  extraActive(1.9);

  const ActivityLevel(this.factor);

  final double factor;

  /// The level with exactly this factor, or null.
  static ActivityLevel? fromFactor(double factor) {
    for (final a in values) {
      if (a.factor == factor) return a;
    }
    return null;
  }
}

enum Target { lose, stay, gain }

/// Energy in a pound of body weight, and in a kilogram when rates are in kg.
const kcalPerLb = 3500.0;
const kcalPerKg = 7700.0;

/// A weekly rate of loss or gain, and what it does to the daily goal.
///
/// Imperial rates (0.25, 0.5, 1, 1.5, 2 lb) use 3,500 kcal per lb. Metric
/// rates (0.1, 0.25, 0.5, 0.75, 1 kg) use 7,700 kcal per kg. Each takes the
/// amount per week times that figure, divided by 7 days. 0.5 lb a week is
/// 250 kcal a day.
class WeeklyRate {
  const WeeklyRate(this.target, this.amount, this.units);

  /// No change in weight.
  static const stay = WeeklyRate(Target.stay, 0, UnitSystem.imperial);

  /// The five amounts offered, in lb or kg a week.
  static List<double> amounts(UnitSystem units) => units == UnitSystem.imperial
      ? const [0.25, 0.5, 1, 1.5, 2]
      : const [0.1, 0.25, 0.5, 0.75, 1];

  /// The rate that was stored as [kgPerWeek] (negative to lose), or null if it
  /// is not one of the offered rates. This is how a goals row is read back.
  static WeeklyRate? fromKgPerWeek(double kgPerWeek) {
    if (kgPerWeek == 0) return stay;
    final target = kgPerWeek < 0 ? Target.lose : Target.gain;
    for (final units in UnitSystem.values) {
      for (final a in amounts(units)) {
        final r = WeeklyRate(target, a, units);
        if ((r.kgPerWeek - kgPerWeek).abs() < 1e-9) return r;
      }
    }
    return null;
  }

  final Target target;

  /// Pounds or kilograms a week (never negative), by [units].
  final double amount;
  final UnitSystem units;

  double get _sign => switch (target) {
    Target.lose => -1,
    Target.stay => 0,
    Target.gain => 1,
  };

  /// Kilograms a week, negative to lose. This is what the goals row stores.
  double get kgPerWeek =>
      _sign * (units == UnitSystem.imperial ? lbToKg(amount) : amount);

  /// Calories a day added to (gain) or taken from (lose, negative) the
  /// calories needed to stay the same.
  double get kcalPerDay =>
      _sign *
      amount *
      (units == UnitSystem.imperial ? kcalPerLb : kcalPerKg) /
      7;
}

/// Whole years old on [day], both 'YYYY-MM-DD'.
int ageOn(String birthDate, String day) {
  final b = parseDate(birthDate);
  final d = parseDate(day);
  var years = d.year - b.year;
  if (d.month < b.month || (d.month == b.month && d.day < b.day)) years--;
  return years;
}

/// Mifflin-St Jeor resting energy in kcal a day:
/// 10 x weight (kg) + 6.25 x height (cm) - 5 x age (years) + 5 for men or
/// - 161 for women. (Mifflin et al., Am J Clin Nutr 1990;51:241-247.)
double restingEnergy({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int ageYears,
}) =>
    10 * weightKg +
    6.25 * heightCm -
    5 * ageYears +
    (sex == Sex.male ? 5 : -161);

/// The steps behind a calculated goal, all unrounded, so a screen can show
/// the working and round each line itself with [roundForDisplay].
class CalorieWorking {
  const CalorieWorking({
    required this.resting,
    required this.activity,
    required this.maintenance,
    required this.adjustment,
  });

  /// Mifflin-St Jeor resting energy.
  final double resting;
  final ActivityLevel activity;

  /// Resting energy times the activity factor: calories to stay the same.
  final double maintenance;

  /// The rate's daily change: negative to lose, 0 to stay, positive to gain.
  final double adjustment;

  /// The calculated calorie goal: [maintenance] plus [adjustment].
  double get goal => maintenance + adjustment;
}

/// The calculated goal for a person on [day] (the age is worked out on that
/// day). [weightKg] is the latest weigh-in on or before it.
CalorieWorking calorieWorking({
  required Sex sex,
  required String birthDate,
  required String day,
  required double weightKg,
  required double heightCm,
  required ActivityLevel activity,
  required WeeklyRate rate,
}) {
  final resting = restingEnergy(
    sex: sex,
    weightKg: weightKg,
    heightCm: heightCm,
    ageYears: ageOn(birthDate, day),
  );
  return CalorieWorking(
    resting: resting,
    activity: activity,
    maintenance: resting * activity.factor,
    adjustment: rate.kcalPerDay,
  );
}

/// True when a calorie goal is under 1,500 kcal for men or 1,200 for women.
/// Exactly at the line is not low. Pass the whole number that is shown or
/// stored (use [roundForDisplay] on a live goal), so the warning never
/// disagrees with the number on screen. With no sex known (an own number and
/// no profile) the lower line, 1,200, is used. This is a condition for the
/// screen to state. It never blocks anything.
bool isLowIntake(int calories, Sex? sex) =>
    calories < (sex == Sex.male ? 1500 : 1200);

/// Percents that do not add to 100 (or one is below 0). Never carries values.
class PercentsDontAddUp implements Exception {
  const PercentsDontAddUp();

  @override
  String toString() => 'PercentsDontAddUp';
}

const kcalPerGramProtein = 4.0;
const kcalPerGramCarbs = 4.0;
const kcalPerGramFat = 9.0;

/// The three macros in grams, with what each is worth in kcal.
class MacroBreakdown {
  const MacroBreakdown({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double proteinG;
  final double carbsG;
  final double fatG;

  double get proteinKcal => proteinG * kcalPerGramProtein;
  double get carbsKcal => carbsG * kcalPerGramCarbs;
  double get fatKcal => fatG * kcalPerGramFat;
  double get totalKcal => proteinKcal + carbsKcal + fatKcal;

  /// How far the macros are from the calorie goal: positive when they add up
  /// to more, negative when to less, 0 when they match. Pass the whole number
  /// that is shown or stored (use [roundForDisplay] on a live goal), so a
  /// goal of 2,138.04 shown as 2,138 gives 0.
  double differenceFrom(int goalKcal) => totalKcal - goalKcal;

  // What the screens show: each part rounded on its own, and the total and
  // the difference built from the rounded parts, so the lines add up on screen.
  int get shownProteinKcal => roundForDisplay(proteinKcal);
  int get shownCarbsKcal => roundForDisplay(carbsKcal);
  int get shownFatKcal => roundForDisplay(fatKcal);
  int get shownTotalKcal => shownProteinKcal + shownCarbsKcal + shownFatKcal;

  /// The shown total minus the whole-number [goalKcal].
  int shownDifferenceFrom(int goalKcal) => shownTotalKcal - goalKcal;
}

/// Percent mode: whole percents of the calorie goal. They must add to 100 or
/// this throws [PercentsDontAddUp]. 30% of 2,138 kcal is 641.4 kcal, which is
/// 160.35 g of protein at 4 kcal a gram.
MacroBreakdown macrosFromPercent({
  required double calories,
  required int proteinPercent,
  required int carbsPercent,
  required int fatPercent,
}) {
  if (proteinPercent < 0 ||
      carbsPercent < 0 ||
      fatPercent < 0 ||
      percentLeft(proteinPercent, carbsPercent, fatPercent) != 0) {
    throw const PercentsDontAddUp();
  }
  return MacroBreakdown(
    proteinG: calories * proteinPercent / 100 / kcalPerGramProtein,
    carbsG: calories * carbsPercent / 100 / kcalPerGramCarbs,
    fatG: calories * fatPercent / 100 / kcalPerGramFat,
  );
}

/// What is left to give out so the percents reach 100 ("Adds to 95%. 5%
/// left."). Negative when they add to more.
int percentLeft(int proteinPercent, int carbsPercent, int fatPercent) =>
    100 - proteinPercent - carbsPercent - fatPercent;

/// The exercise add-back choices: 0, 50 or 100 percent.
const addBackChoices = [0, 50, 100];

/// The part of [exerciseKcal] that counts toward the day, by [percent].
/// Throws [ArgumentError] for anything but 0, 50 or 100.
double addBackKcal(double exerciseKcal, int percent) {
  if (!addBackChoices.contains(percent)) {
    throw ArgumentError.value(percent, 'percent', 'must be 0, 50 or 100');
  }
  return exerciseKcal * percent / 100;
}

/// One day's calorie budget: goal plus the add-back share of exercise, minus
/// food. All values unrounded; [left] is negative when over.
class DayBudget {
  DayBudget({
    required this.goal,
    required this.exerciseKcal,
    required this.addBackPercent,
    required this.foodKcal,
  }) : addBack = addBackKcal(exerciseKcal, addBackPercent);

  final double goal;

  /// All the day's exercise, before the add-back setting.
  final double exerciseKcal;
  final int addBackPercent;

  /// The part of the exercise that is added to the goal.
  final double addBack;
  final double foodKcal;

  /// The goal + add-back - food. Unrounded: use it for logic, never to show.
  double get left => goal + addBack - foodKcal;

  // What the screens show. Each part is rounded on its own and the total is
  // built from the rounded parts, so the line under the big number always
  // adds up: shownGoal + shownAddBack - shownFood == shownLeft. Screens must
  // show only these four, never a rounded [left] next to rounded parts (they
  // can differ by 1).
  int get shownGoal => roundForDisplay(goal);
  int get shownAddBack => roundForDisplay(addBack);
  int get shownFood => roundForDisplay(foodKcal);
  int get shownLeft => shownGoal + shownAddBack - shownFood;

  /// The same day with [kcal] more food (the meal being typed). Nothing else
  /// changes, and the original is untouched.
  DayBudget withFood(double kcal) => DayBudget(
    goal: goal,
    exerciseKcal: exerciseKcal,
    addBackPercent: addBackPercent,
    foodKcal: foodKcal + kcal,
  );
}
