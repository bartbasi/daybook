// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart';

import '../clock.dart';
import '../parser/name_key.dart';
import 'database.dart';
import 'food_data.dart';
import 'nutrients.dart';

// Saved meals and their aliases, the user's own foods and recipes. Split from
// food_data.dart (logging meals) so each file stays readable. No user-facing
// text here.

// Saved meals

/// A stored saved meal item with its nutrient copy.
class StoredSavedItem {
  const StoredSavedItem(this.item, this.nutrients);

  final SavedMealItem item;
  final Map<int, double> nutrients;

  /// The item as a line (an added line in the saved meal editor).
  MealLineInput asInput() => MealLineInput(
    foodRef: item.foodRef,
    foodName: item.foodName,
    quantity: item.quantity,
    unitLabel: item.unitLabel,
    baseQuantity: item.baseQuantity,
    baseUnit: item.baseUnit,
    nutrients: nutrients,
  );
}

/// A saved meal with its other names and items. [totals] are unrounded.
/// [timesUsedInSlot] is how many logged meals used it in the slot asked for
/// (0 when no slot was asked for).
class SavedMealDetail {
  const SavedMealDetail(
    this.meal,
    this.aliases,
    this.items, {
    this.timesUsedInSlot = 0,
  });

  final SavedMeal meal;

  /// The phrases as the user typed them (trimmed), in the order added.
  final List<String> aliases;
  final List<StoredSavedItem> items;
  final int timesUsedInSlot;

  Map<int, double> get totals => sumNutrients(items.map((i) => i.nutrients));
}

enum AliasProblem {
  /// Nothing is left of the phrase once it is keyed with nameKey.
  empty,

  /// Another saved meal already has the phrase.
  taken,
}

/// The result of creating or updating a saved meal. When any alias is refused
/// nothing is written, [saved] is null and [problems] says which phrases
/// (as typed, trimmed; '' for an empty one) and why.
class SavedMealResult {
  const SavedMealResult.saved(SavedMealDetail this.saved) : problems = const {};
  const SavedMealResult.refused(this.problems) : saved = null;

  final SavedMealDetail? saved;
  final Map<String, AliasProblem> problems;

  bool get ok => saved != null;
}

/// A saved meal expanded for logging: [items] have the amounts and nutrients
/// times [multiplier] and are marked as saved meal items, so nothing in them
/// is ever learned. Pass [savedMealId] to saveMeal for the first expansion.
class SavedMealExpansion {
  const SavedMealExpansion(
    this.savedMealId,
    this.name,
    this.multiplier,
    this.items,
  );

  final int savedMealId;
  final String name;
  final double multiplier;
  final List<MealLineInput> items;
}

/// A deleted saved meal, held for Undo (see deleteSavedMeal).
class DeletedSavedMeal {
  const DeletedSavedMeal(this.detail, this.mealIds);

  final SavedMealDetail detail;

  /// Logged meals that pointed at it, whose link was cleared by the delete.
  final List<int> mealIds;
}

// Custom foods and recipes

/// What a custom food's nutrients are for.
enum FoodBasis { perServing, per100g, per100ml }

class PortionInput {
  const PortionInput(this.label, this.baseQuantity);

  /// As the portion readers expect it, for example "1 cookie".
  final String label;

  /// An amount in the food's base unit.
  final double baseQuantity;
}

/// A custom food as the editor holds it (food-editor frame 1).
///
/// [nutrients] are the values as typed, for one serving ([FoodBasis.perServing])
/// or per 100 g or 100 ml. Leave out what was left empty. Energy (1008) is
/// required. [servingSize] is the weight of one serving in grams, or in ml
/// for [FoodBasis.per100ml]; it makes a "1 serving" portion so g and oz work.
class CustomFoodInput {
  const CustomFoodInput({
    required this.name,
    required this.basis,
    required this.nutrients,
    this.brand,
    this.barcode,
    this.servingSize,
    this.portions = const [],
  });

  final String name;
  final String? brand;
  final String? barcode;
  final FoodBasis basis;
  final Map<int, double> nutrients;
  final double? servingSize;

  /// Extra portions the user added.
  final List<PortionInput> portions;
}

/// A recipe as the editor holds it: the ingredients, and how many servings it
/// makes. Ingredient nutrients are summed into the whole recipe's nutrients.
class RecipeInput {
  const RecipeInput({
    required this.name,
    required this.servings,
    required this.ingredients,
  });

  final String name;
  final double servings;
  final List<MealLineInput> ingredients;
}

/// A custom food or recipe with its nutrients (per base amount), portions and
/// ingredients.
class FoodDetail {
  const FoodDetail(this.food, this.nutrients, this.portions, this.ingredients);

  final Food food;
  final Map<int, double> nutrients;
  final List<FoodPortion> portions;
  final List<RecipeIngredient> ingredients;

  String get ref => 'local:${food.id}';

  /// What a custom food's values are for, read back from how it is stored.
  /// A food per 100 g with a serving of exactly 100 g reads as per 100 g.
  FoodBasis get basis => switch (food.baseUnit) {
    'ml' => FoodBasis.per100ml,
    'g' => food.baseAmount == 100 ? FoodBasis.per100g : FoodBasis.perServing,
    _ => FoodBasis.perServing,
  };

  /// The weight (or ml) of one serving, if it has one.
  double? get servingSize {
    if (food.baseUnit == 'serving') return null;
    for (final p in portions) {
      if (p.label == servingLabel) return p.baseQuantity;
    }
    return null;
  }
}

/// The label of the portion that holds a serving's weight.
const servingLabel = '1 serving';

extension FoodLibraryData on AppDatabase {
  // Saved meals

  /// Reads a saved meal, or null.
  Future<SavedMealDetail?> loadSavedMeal(int id) =>
      transaction(() => _loadSavedMeal(id));

  Future<SavedMealDetail?> _loadSavedMeal(int id) async {
    final rows = await (select(
      savedMeals,
    )..where((s) => s.id.equals(id))).get();
    return (await _savedMealDetails(rows)).firstOrNull;
  }

  Future<List<SavedMealDetail>> _savedMealDetails(
    List<SavedMeal> rows, {
    Map<int, int> used = const {},
  }) async {
    if (rows.isEmpty) return [];
    final ids = [for (final s in rows) s.id];
    final items =
        await (select(savedMealItems)
              ..where((i) => i.savedMealId.isIn(ids))
              ..orderBy([
                (i) => OrderingTerm.asc(i.position),
                (i) => OrderingTerm.asc(i.id),
              ]))
            .get();
    final nutrients = <int, Map<int, double>>{};
    if (items.isNotEmpty) {
      final ns = await (select(
        savedMealItemNutrients,
      )..where((n) => n.itemId.isIn([for (final i in items) i.id]))).get();
      for (final n in ns) {
        (nutrients[n.itemId] ??= {})[n.nutrientId] = n.amount;
      }
    }
    final itemsOf = <int, List<StoredSavedItem>>{};
    for (final i in items) {
      (itemsOf[i.savedMealId] ??= []).add(
        StoredSavedItem(i, nutrients[i.id] ?? {}),
      );
    }
    final aliasRows =
        await (select(aliases)
              ..where((a) => a.savedMealId.isIn(ids))
              ..orderBy([(a) => OrderingTerm.asc(a.id)]))
            .get();
    final aliasesOf = <int, List<String>>{};
    for (final a in aliasRows) {
      (aliasesOf[a.savedMealId] ??= []).add(a.phrase);
    }
    return [
      for (final s in rows)
        SavedMealDetail(
          s,
          aliasesOf[s.id] ?? [],
          itemsOf[s.id] ?? [],
          timesUsedInSlot: used[s.id] ?? 0,
        ),
    ];
  }

  /// Every saved meal. With [slotId], ordered by how many logged meals used it
  /// in that slot (through meals.saved_meal_id), then by name; without, by
  /// name. Updated after every change to saved meals, aliases or meals.
  Future<List<SavedMealDetail>> savedMealsList({int? slotId}) =>
      transaction(() => _savedMealsList(slotId));

  Future<List<SavedMealDetail>> _savedMealsList(int? slotId) async {
    final rows = await select(savedMeals).get();
    final used = <int, int>{};
    if (slotId != null) {
      final n = meals.id.count();
      final q = selectOnly(meals)
        ..addColumns([meals.savedMealId, n])
        ..where(meals.slotId.equals(slotId) & meals.savedMealId.isNotNull())
        ..groupBy([meals.savedMealId]);
      for (final r in await q.get()) {
        used[r.read(meals.savedMealId)!] = r.read(n)!;
      }
    }
    final details = await _savedMealDetails(rows, used: used);
    details.sort((a, b) {
      final c = b.timesUsedInSlot.compareTo(a.timesUsedInSlot);
      if (c != 0) return c;
      final n = a.meal.name.toLowerCase().compareTo(b.meal.name.toLowerCase());
      return n != 0 ? n : a.meal.id.compareTo(b.meal.id);
    });
    return details;
  }

  Stream<List<SavedMealDetail>> watchSavedMeals({int? slotId}) => liveQuery(
    this,
    [savedMeals, savedMealItems, savedMealItemNutrients, aliases, meals],
    () => savedMealsList(slotId: slotId),
  );

  /// Creates a saved meal with [items] (each with its nutrient copy) and
  /// [aliases] (other names, stored as typed and compared through nameKey). If
  /// an alias is refused nothing is written (see [SavedMealResult]).
  Future<SavedMealResult> createSavedMeal({
    required String name,
    required List<MealLineInput> items,
    required Now now,
    List<String> aliases = const [],
  }) async {
    _checkName(name);
    return transaction(() async {
      final phrases = <String>[];
      final problems = await _aliasProblems(aliases, null, phrases);
      if (problems.isNotEmpty) return SavedMealResult.refused(problems);
      final id = await into(savedMeals).insert(
        SavedMealsCompanion.insert(name: name.trim(), createdAtMs: now.utcMs),
      );
      await _writeSavedItems(id, items);
      await _writeAliases(id, phrases);
      return SavedMealResult.saved((await loadSavedMeal(id))!);
    });
  }

  /// Renames, replaces the items and replaces the other names, for each one
  /// given. Items are written again with the values given, so pass the stored
  /// ones back for items that were not touched. Never changes logged meals.
  Future<SavedMealResult> updateSavedMeal(
    int id, {
    String? name,
    List<MealLineInput>? items,
    List<String>? aliases,
  }) async {
    if (name != null) _checkName(name);
    return transaction(() async {
      if (await loadSavedMeal(id) == null) {
        throw StateError('No such saved meal');
      }
      final phrases = <String>[];
      if (aliases != null) {
        final problems = await _aliasProblems(aliases, id, phrases);
        if (problems.isNotEmpty) return SavedMealResult.refused(problems);
      }
      if (name != null) {
        await (update(savedMeals)..where((s) => s.id.equals(id))).write(
          SavedMealsCompanion(name: Value(name.trim())),
        );
      }
      if (items != null) {
        await (delete(
          savedMealItems,
        )..where((i) => i.savedMealId.equals(id))).go();
        await _writeSavedItems(id, items);
      }
      if (aliases != null) {
        await (delete(
          this.aliases,
        )..where((a) => a.savedMealId.equals(id))).go();
        await _writeAliases(id, phrases);
      }
      return SavedMealResult.saved((await loadSavedMeal(id))!);
    });
  }

  void _checkName(String name) {
    if (name.trim().isEmpty) throw ArgumentError('A saved meal needs a name');
  }

  /// Puts the trimmed phrases of [wanted] into [out] (one per nameKey, the
  /// first typed wins) and returns the ones that cannot be used. A phrase
  /// clashes when its nameKey equals the nameKey of a phrase stored for
  /// another saved meal. [ownId] is the saved meal being updated, whose own
  /// phrases are fine.
  Future<Map<String, AliasProblem>> _aliasProblems(
    List<String> wanted,
    int? ownId,
    List<String> out,
  ) async {
    final problems = <String, AliasProblem>{};
    final stored = <String, int>{
      for (final a in await select(aliases).get())
        if (a.savedMealId != ownId) nameKey(a.phrase): a.savedMealId,
    };
    final seen = <String>{};
    for (final w in wanted) {
      final p = w.trim();
      final key = nameKey(p);
      if (key.isEmpty) {
        problems[''] = AliasProblem.empty;
        continue;
      }
      if (!seen.add(key)) continue;
      out.add(p);
      if (stored.containsKey(key)) problems[p] = AliasProblem.taken;
    }
    return problems;
  }

  Future<void> _writeAliases(int savedMealId, List<String> phrases) async {
    for (final p in phrases) {
      await into(aliases)
          .insert(AliasesCompanion.insert(phrase: p, savedMealId: savedMealId));
    }
  }

  Future<void> _writeSavedItems(int id, List<MealLineInput> items) async {
    for (var i = 0; i < items.length; i++) {
      final l = items[i];
      final itemId = await into(savedMealItems).insert(
        SavedMealItemsCompanion.insert(
          savedMealId: id,
          position: i,
          foodRef: l.foodRef,
          foodName: l.foodName,
          quantity: l.quantity,
          unitLabel: l.unitLabel,
          baseQuantity: l.baseQuantity,
          baseUnit: l.baseUnit,
        ),
      );
      await _insertSavedNutrients(itemId, l.nutrients);
    }
  }

  Future<void> _insertSavedNutrients(int itemId, Map<int, double> nutrients) =>
      batch(
        (b) => b.insertAll(savedMealItemNutrients, [
          for (final e in nutrients.entries)
            SavedMealItemNutrientsCompanion.insert(
              itemId: itemId,
              nutrientId: e.key,
              amount: e.value,
            ),
        ]),
      );

  /// Deletes a saved meal, its items and its other names. Logged meals keep
  /// their entries; their saved meal link is cleared. Returns what Undo needs.
  Future<DeletedSavedMeal> deleteSavedMeal(int id) => transaction(() async {
    final d = await loadSavedMeal(id);
    if (d == null) throw StateError('No such saved meal');
    final linked = await (select(
      meals,
    )..where((m) => m.savedMealId.equals(id))).get();
    await (delete(savedMeals)..where((s) => s.id.equals(id))).go();
    return DeletedSavedMeal(d, [for (final m in linked) m.id]);
  });

  /// Puts back a deleted saved meal with the same ids, and relinks the logged
  /// meals that still exist. An alias whose nameKey another saved meal has
  /// taken since is not restored.
  Future<SavedMealDetail> undoDeleteSavedMeal(DeletedSavedMeal deleted) =>
      transaction(() async {
        final d = deleted.detail;
        await into(savedMeals).insert(d.meal.toCompanion(false));
        for (final i in d.items) {
          await into(savedMealItems).insert(i.item.toCompanion(false));
          await _insertSavedNutrients(i.item.id, i.nutrients);
        }
        final keys = <String>{
          for (final a in await select(aliases).get()) nameKey(a.phrase),
        };
        for (final p in d.aliases) {
          if (keys.add(nameKey(p))) {
            await into(aliases).insert(
              AliasesCompanion.insert(phrase: p, savedMealId: d.meal.id),
            );
          }
        }
        await (update(meals)..where((m) => m.id.isIn(deleted.mealIds))).write(
          MealsCompanion(savedMealId: Value(d.meal.id)),
        );
        return (await loadSavedMeal(d.meal.id))!;
      });

  /// A saved meal's items for logging, times [multiplier] (grammar 6.2, 6.4),
  /// or null if there is no such saved meal.
  Future<SavedMealExpansion?> expandSavedMeal(
    int id, {
    double multiplier = 1,
  }) async {
    final d = await loadSavedMeal(id);
    if (d == null) return null;
    return SavedMealExpansion(id, d.meal.name, multiplier, [
      for (final i in d.items)
        i.asInput().scaled(multiplier, inSavedMeal: true),
    ]);
  }

  // Custom foods and recipes

  /// Creates a custom food (kind 'custom'). With a serving weight per serving
  /// it is stored as grams (base amount is the serving weight, so the typed
  /// values are kept as typed) plus a "1 serving" portion; with no weight, as
  /// base unit 'serving', amount 1. Per 100 g and per 100 ml are base amount
  /// 100 of 'g' and 'ml'. Empty nutrients are not stored.
  Future<FoodDetail> createCustomFood(CustomFoodInput f, Now now) =>
      transaction(() async {
        final (unit, amount) = _basis(f);
        final id = await into(foods).insert(
          FoodsCompanion.insert(
            kind: 'custom',
            name: f.name.trim(),
            brand: Value(_orNull(f.brand)),
            barcode: Value(_orNull(f.barcode)),
            baseAmount: amount,
            baseUnit: unit,
            createdAtMs: now.utcMs,
            updatedAtMs: now.utcMs,
          ),
        );
        await _writeFoodBody(id, f.nutrients, _portionsOf(f));
        return (await loadFood(id))!;
      });

  /// Replaces a custom food's fields, nutrients and portions. Logged meals
  /// keep their copies.
  Future<FoodDetail> editCustomFood(int id, CustomFoodInput f, Now now) =>
      transaction(() async {
        final old = await loadFood(id);
        if (old == null || old.food.kind != 'custom') {
          throw StateError('No such custom food');
        }
        final (unit, amount) = _basis(f);
        await (update(foods)..where((x) => x.id.equals(id))).write(
          FoodsCompanion(
            name: Value(f.name.trim()),
            brand: Value(_orNull(f.brand)),
            barcode: Value(_orNull(f.barcode)),
            baseAmount: Value(amount),
            baseUnit: Value(unit),
            updatedAtMs: Value(now.utcMs),
          ),
        );
        await _clearFoodBody(id);
        await _writeFoodBody(id, f.nutrients, _portionsOf(f));
        return (await loadFood(id))!;
      });

  (String, double) _basis(CustomFoodInput f) {
    if (f.name.trim().isEmpty) throw ArgumentError('A food needs a name');
    if (!f.nutrients.containsKey(Nutrients.energy)) {
      throw ArgumentError('A food needs calories');
    }
    final s = f.servingSize;
    if (s != null && !(s > 0)) throw ArgumentError('A serving needs a size');
    return switch (f.basis) {
      FoodBasis.perServing => s == null ? ('serving', 1.0) : ('g', s),
      FoodBasis.per100g => ('g', 100.0),
      FoodBasis.per100ml => ('ml', 100.0),
    };
  }

  List<PortionInput> _portionsOf(CustomFoodInput f) => [
    if (f.servingSize != null) PortionInput(servingLabel, f.servingSize!),
    ...f.portions,
  ];

  String? _orNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  Future<void> _clearFoodBody(int id) async {
    await (delete(foodNutrients)..where((n) => n.foodId.equals(id))).go();
    await (delete(foodPortions)..where((p) => p.foodId.equals(id))).go();
    await (delete(
      recipeIngredients,
    )..where((r) => r.recipeFoodId.equals(id))).go();
  }

  Future<void> _writeFoodBody(
    int id,
    Map<int, double> nutrients,
    List<PortionInput> portions,
  ) async {
    await batch((b) {
      b.insertAll(foodNutrients, [
        for (final e in nutrients.entries)
          FoodNutrientsCompanion.insert(
            foodId: id,
            nutrientId: e.key,
            amount: e.value,
          ),
      ]);
      b.insertAll(foodPortions, [
        for (final p in portions)
          FoodPortionsCompanion.insert(
            foodId: id,
            label: p.label,
            baseQuantity: p.baseQuantity,
          ),
      ]);
    });
  }

  /// Creates a recipe (kind 'recipe'). Every ingredient must have its
  /// nutrients (an empty map is refused with [ArgumentError]): stored
  /// ingredients carry none, so when reopening a recipe the caller must
  /// recompute each ingredient's nutrients from the food data before saving
  /// it again. Base amount is [RecipeInput.servings]
  /// of base unit 'serving', and the nutrients are the whole recipe's, the sum
  /// of its ingredient lines. The ingredients are stored in order.
  Future<FoodDetail> createRecipe(RecipeInput r, Now now) =>
      transaction(() async {
        _checkRecipe(r);
        final id = await into(foods).insert(
          FoodsCompanion.insert(
            kind: 'recipe',
            name: r.name.trim(),
            baseAmount: r.servings,
            baseUnit: 'serving',
            createdAtMs: now.utcMs,
            updatedAtMs: now.utcMs,
          ),
        );
        await _writeRecipeBody(id, r);
        return (await loadFood(id))!;
      });

  Future<FoodDetail> editRecipe(int id, RecipeInput r, Now now) =>
      transaction(() async {
        _checkRecipe(r);
        final old = await loadFood(id);
        if (old == null || old.food.kind != 'recipe') {
          throw StateError('No such recipe');
        }
        await (update(foods)..where((x) => x.id.equals(id))).write(
          FoodsCompanion(
            name: Value(r.name.trim()),
            baseAmount: Value(r.servings),
            updatedAtMs: Value(now.utcMs),
          ),
        );
        await _clearFoodBody(id);
        await _writeRecipeBody(id, r);
        return (await loadFood(id))!;
      });

  void _checkRecipe(RecipeInput r) {
    if (r.ingredients.any((i) => i.nutrients.isEmpty)) {
      throw ArgumentError('Every ingredient needs its nutrients');
    }
    if (r.name.trim().isEmpty) throw ArgumentError('A recipe needs a name');
    if (!(r.servings > 0)) throw ArgumentError('A recipe makes some servings');
  }

  Future<void> _writeRecipeBody(int id, RecipeInput r) async {
    await _writeFoodBody(
      id,
      sumNutrients(r.ingredients.map((i) => i.nutrients)),
      const [],
    );
    await batch(
      (b) => b.insertAll(recipeIngredients, [
        for (var i = 0; i < r.ingredients.length; i++)
          RecipeIngredientsCompanion.insert(
            recipeFoodId: id,
            position: i,
            foodRef: r.ingredients[i].foodRef,
            foodName: r.ingredients[i].foodName,
            quantity: r.ingredients[i].quantity,
            unitLabel: r.ingredients[i].unitLabel,
            baseQuantity: r.ingredients[i].baseQuantity,
            baseUnit: r.ingredients[i].baseUnit,
          ),
      ]),
    );
  }

  /// Archives a food (or brings it back with [archived] false). Foods are
  /// never deleted, because logged meals and saved meals point to them.
  ///
  /// Archiving frees the food's barcode (the column is unique, and a scan
  /// must not find a food that cannot be used). Bringing a food back with
  /// [restoreBarcode] puts that barcode back unless another food has it now;
  /// check the returned food's barcode to see which happened.
  Future<FoodDetail> archiveFood(
    int id,
    Now now, {
    bool archived = true,
    String? restoreBarcode,
  }) => transaction(() async {
    Value<String?> barcode = const Value.absent();
    if (archived) {
      barcode = const Value(null);
    } else if (restoreBarcode != null) {
      final taken = await (select(
        foods,
      )..where((f) => f.barcode.equals(restoreBarcode))).getSingleOrNull();
      if (taken == null || taken.id == id) barcode = Value(restoreBarcode);
    }
    final changed = await (update(foods)..where((f) => f.id.equals(id))).write(
      FoodsCompanion(
        archived: Value(archived),
        barcode: barcode,
        updatedAtMs: Value(now.utcMs),
      ),
    );
    if (changed == 0) throw StateError('No such food');
    return (await loadFood(id))!;
  });

  Future<FoodDetail?> loadFood(int id) async {
    final rows = await (select(foods)..where((f) => f.id.equals(id))).get();
    return (await _foodDetails(rows)).firstOrNull;
  }

  Future<List<FoodDetail>> _foodDetails(List<Food> rows) async {
    if (rows.isEmpty) return [];
    final ids = [for (final f in rows) f.id];
    final nutrients = <int, Map<int, double>>{};
    for (final n in await (select(
      foodNutrients,
    )..where((x) => x.foodId.isIn(ids))).get()) {
      (nutrients[n.foodId] ??= {})[n.nutrientId] = n.amount;
    }
    final portions = <int, List<FoodPortion>>{};
    for (final p
        in await (select(foodPortions)
              ..where((x) => x.foodId.isIn(ids))
              ..orderBy([(x) => OrderingTerm.asc(x.id)]))
            .get()) {
      (portions[p.foodId] ??= []).add(p);
    }
    final ingredients = <int, List<RecipeIngredient>>{};
    for (final i
        in await (select(recipeIngredients)
              ..where((x) => x.recipeFoodId.isIn(ids))
              ..orderBy([(x) => OrderingTerm.asc(x.position)]))
            .get()) {
      (ingredients[i.recipeFoodId] ??= []).add(i);
    }
    return [
      for (final f in rows)
        FoodDetail(
          f,
          nutrients[f.id] ?? {},
          portions[f.id] ?? [],
          ingredients[f.id] ?? [],
        ),
    ];
  }

  /// The user's custom foods and recipes by name, for the "My foods and
  /// recipes" screen. Cached Open Food Facts products are not listed.
  /// Archived ones only with [includeArchived].
  Future<List<FoodDetail>> myFoods({bool includeArchived = false}) async {
    final rows =
        await (select(foods)..where(
              (f) =>
                  f.kind.isIn(const ['custom', 'recipe']) &
                  (includeArchived
                      ? const Constant(true)
                      : f.archived.equals(false)),
            ))
            .get();
    rows.sort((a, b) {
      final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return n != 0 ? n : a.id.compareTo(b.id);
    });
    return _foodDetails(rows);
  }

  Stream<List<FoodDetail>> watchMyFoods({bool includeArchived = false}) =>
      liveQuery(this, [
        foods,
        foodNutrients,
        foodPortions,
        recipeIngredients,
      ], () => myFoods(includeArchived: includeArchived));
}
