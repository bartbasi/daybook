// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The user's data as the parser needs it, in plain Dart: no drift, no Flutter,
// only strings, numbers, lists and maps, so a value can be sent to the parser's
// isolate. lib/data/food_data.dart fills it from the database
// (loadUserSnapshot). Task 2.5's lib/parser/user_snapshot.dart reads it.

/// A household portion of a local food. [baseQuantity] is an amount in the
/// food's base unit, for example 20 for "1 cookie" of a food counted in g.
class PortionData {
  const PortionData(this.label, this.baseQuantity);

  final String label;
  final double baseQuantity;
}

/// One of the user's own foods: a custom food, a recipe or a cached Open Food
/// Facts product. Archived foods are not in the snapshot.
class UserFoodData {
  const UserFoodData({
    required this.ref,
    required this.name,
    required this.kind,
    required this.baseUnit,
    required this.baseAmount,
    this.portions = const [],
    this.nutrients = const {},
  });

  /// `local:<id>`.
  final String ref;
  final String name;

  /// 'custom', 'recipe' or 'off'.
  final String kind;

  /// 'g', 'ml' or 'serving'. [nutrients] are per [baseAmount] of it.
  final String baseUnit;
  final double baseAmount;
  final List<PortionData> portions;

  /// Nutrient id to amount per [baseAmount]. A nutrient the food does not list
  /// is not in the map.
  final Map<int, double> nutrients;
}

/// A row of `learned_matches` (grammar 7).
class LearnedMatchData {
  const LearnedMatchData({
    required this.key,
    required this.foodRef,
    required this.foodName,
    this.unitLabel,
    this.quantity,
    this.timesUsed = 1,
  });

  /// The learned key (7.1).
  final String key;
  final String foodRef;
  final String foodName;

  /// With [quantity]: the amount learned. Both null when none was learned.
  final String? unitLabel;
  final double? quantity;
  final int timesUsed;
}

/// One stored item of a saved meal, with its nutrient copy for that amount.
class SavedMealItemData {
  const SavedMealItemData({
    required this.foodRef,
    required this.foodName,
    required this.quantity,
    required this.unitLabel,
    required this.baseQuantity,
    required this.baseUnit,
    this.nutrients = const {},
  });

  final String foodRef;
  final String foodName;
  final double quantity;
  final String unitLabel;
  final double baseQuantity;
  final String baseUnit;
  final Map<int, double> nutrients;
}

class SavedMealData {
  const SavedMealData({
    required this.id,
    required this.name,
    this.items = const [],
  });

  final int id;
  final String name;

  /// In the order stored.
  final List<SavedMealItemData> items;
}

/// An alias phrase, already normalized, and the saved meal it expands to.
class AliasData {
  const AliasData(this.phrase, this.savedMealId);

  final String phrase;
  final int savedMealId;
}

/// Everything the parser needs from the user's database, at one moment.
class UserSnapshotData {
  const UserSnapshotData({
    this.version = 0,
    this.foods = const [],
    this.learned = const [],
    this.aliases = const [],
    this.savedMeals = const [],
    this.historyCounts = const {},
  });

  /// Counts up each time the data is loaded again, so the parser can tell
  /// which snapshot its cached results came from.
  final int version;
  final List<UserFoodData> foods;
  final List<LearnedMatchData> learned;
  final List<AliasData> aliases;
  final List<SavedMealData> savedMeals;

  /// Food ref to the number of logged lines that used it.
  final Map<String, int> historyCounts;
}
