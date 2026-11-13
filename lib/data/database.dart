// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// The user database: everything the user creates. Reference data (USDA foods)
// lives in a separate read-only file, see food_reference.dart.
//
// Conventions (see docs/data-model.md):
// - Days are TEXT 'YYYY-MM-DD' in the user's local time when the record was
//   made. They are stored, never recomputed, so a time zone change does not
//   move a record to another day.
// - Instants are INTEGER milliseconds since the epoch, UTC, with the local
//   offset in minutes stored next to them.
// - Weights are kilograms, distances meters, food amounts grams or ml.
// - A food is referenced by a text ref: 'usda:<fdc id>' or 'local:<foods.id>'.
//   Logged items also keep a copy of the food's name and nutrients, so history
//   never changes when a food is edited or the USDA data is updated.

// Foods the user creates, recipes, and cached Open Food Facts products.
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()(); // 'custom', 'recipe' or 'off'
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get barcode => text().nullable().unique()();
  // Nutrients are given per baseAmount of baseUnit, e.g. per 100 g.
  RealColumn get baseAmount => real()();
  TextColumn get baseUnit => text()(); // 'g', 'ml' or 'serving'
  // Raw data from the source that the app does not use yet (OFF nutriments).
  TextColumn get sourceJson => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();
}

class FoodNutrients extends Table {
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  IntColumn get nutrientId => integer()();
  RealColumn get amount => real()(); // per baseAmount

  @override
  Set<Column> get primaryKey => {foodId, nutrientId};
}

// Household portions, e.g. 'slice' = 30 g.
class FoodPortions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get foodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  RealColumn get baseQuantity => real()(); // in the food's baseUnit
}

class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeFoodId =>
      integer().references(Foods, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get foodRef => text()();
  TextColumn get foodName => text()();
  RealColumn get quantity => real()();
  TextColumn get unitLabel => text()();
  RealColumn get baseQuantity => real()();
  TextColumn get baseUnit => text()();
}

class MealSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

// Which slot is the default at a time of day. A rule applies from its start
// minute until the next rule's start minute.
class MealSlotRules extends Table {
  IntColumn get startMinute => integer()(); // 0 to 1439
  IntColumn get slotId => integer().references(MealSlots, #id)();

  @override
  Set<Column> get primaryKey => {startMinute};
}

// One save from the food entry screen.
class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localDate => text()();
  IntColumn get slotId => integer().references(MealSlots, #id)();
  IntColumn get loggedAtMs => integer()();
  IntColumn get tzOffsetMinutes => integer()();
  TextColumn get sourceText => text().nullable()();
  // The first saved meal expanded in this meal, so chips can be ordered by use.
  IntColumn get savedMealId => integer().nullable().references(
    SavedMeals,
    #id,
    onDelete: KeyAction.setNull,
  )();
}

class MealEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealId =>
      integer().references(Meals, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get foodRef => text()();
  TextColumn get foodName => text()();
  RealColumn get quantity => real()(); // as entered, e.g. 2
  TextColumn get unitLabel => text()(); // as entered, e.g. 'slice'
  RealColumn get baseQuantity => real()(); // e.g. 60
  TextColumn get baseUnit => text()(); // e.g. 'g'
}

// Nutrients for the amount eaten (not per 100 g).
class MealEntryNutrients extends Table {
  IntColumn get entryId =>
      integer().references(MealEntries, #id, onDelete: KeyAction.cascade)();
  IntColumn get nutrientId => integer()();
  RealColumn get amount => real()();

  @override
  Set<Column> get primaryKey => {entryId, nutrientId};
}

class SavedMeals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get createdAtMs => integer()();
}

class SavedMealItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get savedMealId =>
      integer().references(SavedMeals, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get foodRef => text()();
  TextColumn get foodName => text()();
  RealColumn get quantity => real()();
  TextColumn get unitLabel => text()();
  RealColumn get baseQuantity => real()();
  TextColumn get baseUnit => text()();
}

class SavedMealItemNutrients extends Table {
  IntColumn get itemId =>
      integer().references(SavedMealItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get nutrientId => integer()();
  RealColumn get amount => real()();

  @override
  Set<Column> get primaryKey => {itemId, nutrientId};
}

// 'usual breakfast' expands to a saved meal.
@DataClassName('Alias')
class Aliases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get phrase => text().unique()(); // normalized: lower case, trimmed
  IntColumn get savedMealId =>
      integer().references(SavedMeals, #id, onDelete: KeyAction.cascade)();
}

// Corrections the parser learns: 'toast' means this bread.
class LearnedMatches extends Table {
  TextColumn get phrase => text()(); // normalized
  TextColumn get foodRef => text()();
  TextColumn get foodName => text()();
  TextColumn get unitLabel => text().nullable()();
  RealColumn get quantity => real().nullable()();
  IntColumn get timesUsed => integer().withDefault(const Constant(1))();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column> get primaryKey => {phrase};
}

class WeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localDate => text()();
  IntColumn get measuredAtMs => integer()();
  IntColumn get tzOffsetMinutes => integer()();
  RealColumn get weightKg => real()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  // Id in Health Connect or Apple Health, so a sync never imports twice.
  TextColumn get sourceId => text().nullable()();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();
  // Set instead of deleting the row, so a health sync cannot bring a deleted
  // weigh-in back. Screens and totals skip rows where this is set.
  IntColumn get deletedAtMs => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {source, sourceId},
  ];
}

// Exercises the user creates. Library exercises ship as reference data and
// are referenced as 'wger:<id>'; these are 'local:<id>'.
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get primaryMuscles => text().withDefault(const Constant(''))();
  TextColumn get secondaryMuscles => text().withDefault(const Constant(''))();
  TextColumn get equipment => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get position => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtMs => integer()();
}

class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get exerciseRef => text()();
  TextColumn get exerciseName => text()();
  IntColumn get targetSets => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
}

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localDate => text()();
  IntColumn get startedAtMs => integer()();
  IntColumn get endedAtMs => integer().nullable()();
  IntColumn get tzOffsetMinutes => integer()();
  IntColumn get routineId => integer().nullable().references(
    Routines,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get kcalEstimated => real().nullable()();
  RealColumn get kcalOverride => real().nullable()();
  TextColumn get note => text().nullable()();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get exerciseRef => text()();
  TextColumn get exerciseName => text()();
  RealColumn get weightKg => real().nullable()(); // null for body weight
  IntColumn get reps => integer().nullable()();
  IntColumn get completedAtMs => integer().nullable()(); // null until done
}

class CardioSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localDate => text()();
  IntColumn get startedAtMs => integer()();
  IntColumn get tzOffsetMinutes => integer()();
  TextColumn get activityCode => text().nullable()(); // Compendium code
  TextColumn get activityName => text()();
  RealColumn get met => real().nullable()();
  IntColumn get durationSeconds => integer()();
  RealColumn get distanceMeters => real().nullable()();
  IntColumn get avgHeartRate => integer().nullable()();
  RealColumn get kcalEstimated => real().nullable()();
  RealColumn get kcalOverride => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceId => text().nullable()();
  // Same as WeightEntries.deletedAtMs.
  IntColumn get deletedAtMs => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {source, sourceId},
  ];
}

// One row (id 1). Inputs for Mifflin-St Jeor.
class Profile extends Table {
  IntColumn get id => integer()();
  TextColumn get sex => text().nullable()(); // 'male' or 'female'
  TextColumn get birthDate => text().nullable()();
  RealColumn get heightCm => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Goals apply from effectiveFrom until the next row's effectiveFrom, so past
// days are shown against the goals that applied then.
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get effectiveFrom => text().unique()();
  TextColumn get calorieMode => text()(); // 'calculated' or 'fixed'
  // The calorie goal in both modes: the calculated number stored when Goals
  // is saved, or the number the user typed.
  IntColumn get calories => integer().nullable()();
  RealColumn get activityFactor => real()();
  RealColumn get targetKgPerWeek => real()(); // negative to lose
  IntColumn get exerciseAddBackPercent =>
      integer().withDefault(const Constant(100))(); // 0, 50 or 100
  TextColumn get macroMode => text()(); // 'grams' or 'percent'
  RealColumn get proteinTarget => real().nullable()();
  RealColumn get carbsTarget => real().nullable()();
  RealColumn get fatTarget => real().nullable()();
}

class GoalNutrients extends Table {
  IntColumn get goalId =>
      integer().references(Goals, #id, onDelete: KeyAction.cascade)();
  IntColumn get nutrientId => integer()();
  RealColumn get targetAmount => real()();

  @override
  Set<Column> get primaryKey => {goalId, nutrientId};
}

// Small settings, e.g. 'units' = 'imperial'.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Foods,
    FoodNutrients,
    FoodPortions,
    RecipeIngredients,
    MealSlots,
    MealSlotRules,
    Meals,
    MealEntries,
    MealEntryNutrients,
    SavedMeals,
    SavedMealItems,
    SavedMealItemNutrients,
    Aliases,
    LearnedMatches,
    WeightEntries,
    Exercises,
    Routines,
    RoutineExercises,
    Workouts,
    WorkoutSets,
    CardioSessions,
    Profile,
    Goals,
    GoalNutrients,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The database file on the device.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'daybook'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await insertDefaults();
    },
    // Each new schema version adds a step here, generated with
    // `dart run drift_dev make-migrations` (see docs/data-model.md).
    onUpgrade: (m, from, to) async {},
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Default meal slots and the default meal by time of day from BRIEF.md.
  Future<void> insertDefaults() async {
    const slots = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    final ids = <String, int>{};
    for (var i = 0; i < slots.length; i++) {
      ids[slots[i]] = await into(mealSlots)
          .insert(MealSlotsCompanion.insert(name: slots[i], position: i));
    }
    const rules = {
      0: 'Breakfast', // until 10:30
      10 * 60 + 30: 'Lunch', // 10:30 to 2:30
      14 * 60 + 30: 'Snack', // 2:30 to 5:00
      17 * 60: 'Dinner', // 5:00 to 9:00
      21 * 60: 'Snack', // after 9:00
    };
    for (final r in rules.entries) {
      await into(mealSlotRules).insert(
        MealSlotRulesCompanion.insert(
          startMinute: Value(r.key),
          slotId: ids[r.value]!,
        ),
      );
    }
    await into(settings)
        .insert(SettingsCompanion.insert(key: 'units', value: 'imperial'));
  }
}
