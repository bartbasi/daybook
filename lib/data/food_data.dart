// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:drift/drift.dart';

import '../clock.dart';
import '../parser/line.dart';
import '../parser/user_snapshot_data.dart';
import '../util/dates.dart';
import 'database.dart';

// Logging food: save, edit and delete a meal, what Home and Food entry read
// back, learned matches and the snapshot the parser needs. Saved meals, custom
// foods and recipes are in food_library_data.dart. No user-facing text here.

/// A stream that loads once on listen and again after every write to one of
/// [tables]. The loads run one after another. Shared with
/// food_library_data.dart.
Stream<T> liveQuery<T>(
  AppDatabase db,
  Iterable<ResultSetImplementation> tables,
  Future<T> Function() load,
) {
  final ticks = StreamController<void>();
  StreamSubscription<void>? sub;
  ticks.onListen = () {
    // Subscribe before the first load, so a write during it is not missed.
    sub = db
        .tableUpdates(TableUpdateQuery.onAllTables(tables))
        .listen((_) => ticks.add(null));
    ticks.add(null);
  };
  ticks.onCancel = () => sub?.cancel();
  return ticks.stream.asyncMap((_) => load());
}

/// Adds up nutrient maps. A nutrient is in the result only if some part has it.
Map<int, double> sumNutrients(Iterable<Map<int, double>> parts) {
  final out = <int, double>{};
  for (final p in parts) {
    for (final e in p.entries) {
      out[e.key] = (out[e.key] ?? 0) + e.value;
    }
  }
  return out;
}

bool sameNutrients(Map<int, double> a, Map<int, double> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// One line of a meal as it is written: what [FoodData.saveMeal] and
/// [FoodData.editMeal] take, and what a saved meal or recipe item is made from.
///
/// The four learning flags say what happened to the line on screen, so the
/// data layer can apply grammar 7.2 when the meal is saved:
/// - [pickedFood]: the user picked a food in the correction sheet (picking the
///   guess itself counts);
/// - [setAmount]: the user set an amount in the sheet on a line whose amount
///   was assumed (or together with a pick). Never set it for a typed amount;
/// - [fromLearned]: the line came from a learned match and was saved unchanged.
/// If more than one is set, [pickedFood] wins, then [setAmount].
/// Nothing is learned for a line with no [learnedKey] (an added line), or for
/// a line with [inSavedMeal] (an item of an expanded saved meal).
class MealLineInput {
  const MealLineInput({
    required this.foodRef,
    required this.foodName,
    required this.quantity,
    required this.unitLabel,
    required this.baseQuantity,
    required this.baseUnit,
    this.nutrients = const {},
    this.existingId,
    this.learnedKey,
    this.pickedFood = false,
    this.setAmount = false,
    this.fromLearned = false,
    this.inSavedMeal = false,
  });

  /// A line the parser made. It must have a food (not a not found line).
  factory MealLineInput.fromLine(
    Line line, {
    int? existingId,
    bool pickedFood = false,
    bool setAmount = false,
    bool fromLearned = false,
    bool inSavedMeal = false,
  }) => MealLineInput(
    foodRef: line.foodRef!,
    foodName: line.foodName!,
    quantity: line.quantity!,
    unitLabel: line.unitLabel ?? '',
    baseQuantity: line.baseQuantity!,
    baseUnit: line.baseUnit!,
    nutrients: line.nutrients,
    existingId: existingId,
    learnedKey: line.learnedKey,
    pickedFood: pickedFood,
    setAmount: setAmount,
    fromLearned: fromLearned,
    inSavedMeal: inSavedMeal,
  );

  final String foodRef;
  final String foodName;
  final double quantity;
  final String unitLabel;
  final double baseQuantity;
  final String baseUnit;

  /// Only the nutrients the food has. Absent stays absent, never zero.
  final Map<int, double> nutrients;

  /// The id of the stored entry this line came from, when editing a meal.
  final int? existingId;

  /// The key of grammar 7.1, for a line made from typed text.
  final String? learnedKey;
  final bool pickedFood;
  final bool setAmount;
  final bool fromLearned;
  final bool inSavedMeal;

  /// The same amount times [m], nutrients too. Used for saved meal items.
  MealLineInput scaled(double m, {bool inSavedMeal = false}) => MealLineInput(
    foodRef: foodRef,
    foodName: foodName,
    quantity: quantity * m,
    unitLabel: unitLabel,
    baseQuantity: baseQuantity * m,
    baseUnit: baseUnit,
    nutrients: {for (final e in nutrients.entries) e.key: e.value * m},
    inSavedMeal: inSavedMeal,
  );
}

/// A stored meal entry with its nutrient copy.
class StoredEntry {
  const StoredEntry(this.entry, this.nutrients);

  final MealEntry entry;
  final Map<int, double> nutrients;

  /// The entry as a line. With [keepId] it carries the entry's id, so
  /// [FoodData.editMeal] knows it is the same line.
  MealLineInput asInput({bool keepId = false}) => MealLineInput(
    foodRef: entry.foodRef,
    foodName: entry.foodName,
    quantity: entry.quantity,
    unitLabel: entry.unitLabel,
    baseQuantity: entry.baseQuantity,
    baseUnit: entry.baseUnit,
    nutrients: nutrients,
    existingId: keepId ? entry.id : null,
  );
}

/// A meal row with its entries in screen order. [totals] are unrounded.
class StoredMeal {
  const StoredMeal(this.meal, this.slotName, this.entries);

  final Meal meal;
  final String slotName;
  final List<StoredEntry> entries;

  Map<int, double> get totals => sumNutrients(entries.map((e) => e.nutrients));
}

/// The meals of one day, by meal slot order, and the day's totals (unrounded).
class DayLog {
  const DayLog(this.localDate, this.meals);

  final String localDate;
  final List<StoredMeal> meals;

  Map<int, double> get totals => sumNutrients(meals.map((m) => m.totals));
}

/// A meal removed by [FoodData.deleteMeal], kept so Undo can put back exactly
/// the same rows. It lives in memory only (see deleteMeal).
class DeletedMeal {
  const DeletedMeal(this.meal);

  final StoredMeal meal;
}

/// A food logged in a slot lately, with the amount last logged.
class RecentFood {
  const RecentFood({
    required this.foodRef,
    required this.foodName,
    required this.quantity,
    required this.unitLabel,
    required this.baseQuantity,
    required this.baseUnit,
    required this.nutrients,
    required this.timesLogged,
    required this.lastLoggedAtMs,
  });

  final String foodRef;
  final String foodName;
  final double quantity;
  final String unitLabel;
  final double baseQuantity;
  final String baseUnit;

  /// The nutrient copy of the last entry, for the last amount.
  final Map<int, double> nutrients;

  /// In how many meals of the slot it was logged in the window.
  final int timesLogged;
  final int lastLoggedAtMs;

  /// The added line a chip makes (grammar 9.3).
  MealLineInput asInput() => MealLineInput(
    foodRef: foodRef,
    foodName: foodName,
    quantity: quantity,
    unitLabel: unitLabel,
    baseQuantity: baseQuantity,
    baseUnit: baseUnit,
    nutrients: nutrients,
  );
}

extension FoodData on AppDatabase {
  // Save, edit, delete a meal

  /// Saves a meal, its entries and what is learned from it (grammar 7.2), all
  /// in one transaction. Either everything is written or nothing. [lines] are
  /// in screen order (added lines first, then typed lines). [localDate] is the
  /// day the user picked; the logged time and offset come from [now].
  /// [savedMealId] is the first saved meal expanded in this meal, if any.
  /// Returns the stored meal read back.
  Future<StoredMeal> saveMeal({
    required Now now,
    required String localDate,
    required int slotId,
    required List<MealLineInput> lines,
    String? sourceText,
    int? savedMealId,
  }) async {
    if (lines.isEmpty) throw ArgumentError('A meal needs at least one line');
    return transaction(() async {
      final id = await into(meals).insert(
        MealsCompanion.insert(
          localDate: localDate,
          slotId: slotId,
          loggedAtMs: now.utcMs,
          tzOffsetMinutes: now.offsetMinutes,
          sourceText: Value(_textOrNull(sourceText)),
          savedMealId: Value(savedMealId),
        ),
      );
      for (var i = 0; i < lines.length; i++) {
        await _insertEntry(id, i, lines[i]);
      }
      await _learn(lines, now.utcMs);
      return (await loadMeal(id))!;
    });
  }

  /// Edits a logged meal. [lines] is the whole meal in screen order. A line
  /// with an [MealLineInput.existingId] whose values equal the stored entry is
  /// not written at all (same row, same name, same nutrients, even if the
  /// reference data has changed since). A changed line is updated in place,
  /// stored entries missing from [lines] are deleted, and lines with no id are
  /// inserted. Text typed during the edit is added to the end of the stored
  /// source text on a new line. [localDate], [slotId] and [savedMealId] change
  /// only when given ([savedMealId] only if the meal has none). The logged
  /// time stays. Learning follows saveMeal. Returns the meal read back.
  Future<StoredMeal> editMeal(
    int mealId, {
    required Now now,
    required List<MealLineInput> lines,
    String? typedText,
    String? localDate,
    int? slotId,
    int? savedMealId,
  }) async {
    if (lines.isEmpty) throw ArgumentError('A meal needs at least one line');
    return transaction(() async {
      final old = await loadMeal(mealId);
      if (old == null) throw StateError('No such meal');
      final stored = {for (final e in old.entries) e.entry.id: e};
      final keep = <int>{};
      for (final l in lines) {
        final id = l.existingId;
        if (id == null) continue;
        if (!stored.containsKey(id)) throw StateError('Not an entry of meal');
        if (!keep.add(id)) throw StateError('Entry used twice');
      }
      for (final id in stored.keys) {
        if (!keep.contains(id)) {
          await (delete(mealEntries)..where((e) => e.id.equals(id))).go();
        }
      }
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        final was = l.existingId == null ? null : stored[l.existingId];
        if (was == null) {
          await _insertEntry(mealId, i, l);
          continue;
        }
        final e = was.entry;
        final same =
            e.foodRef == l.foodRef &&
            e.foodName == l.foodName &&
            e.quantity == l.quantity &&
            e.unitLabel == l.unitLabel &&
            e.baseQuantity == l.baseQuantity &&
            e.baseUnit == l.baseUnit;
        if (same &&
            e.position == i &&
            sameNutrients(was.nutrients, l.nutrients)) {
          continue;
        }
        await (update(mealEntries)..where((x) => x.id.equals(e.id))).write(
          MealEntriesCompanion(
            position: Value(i),
            foodRef: Value(l.foodRef),
            foodName: Value(l.foodName),
            quantity: Value(l.quantity),
            unitLabel: Value(l.unitLabel),
            baseQuantity: Value(l.baseQuantity),
            baseUnit: Value(l.baseUnit),
          ),
        );
        if (!sameNutrients(was.nutrients, l.nutrients)) {
          await (delete(
            mealEntryNutrients,
          )..where((n) => n.entryId.equals(e.id))).go();
          await _insertNutrients(e.id, l.nutrients);
        }
      }
      final typed = _textOrNull(typedText);
      final before = old.meal.sourceText;
      await (update(meals)..where((m) => m.id.equals(mealId))).write(
        MealsCompanion(
          sourceText: typed == null
              ? const Value.absent()
              : Value(
                  before == null || before.isEmpty ? typed : '$before\n$typed',
                ),
          localDate: localDate == null
              ? const Value.absent()
              : Value(localDate),
          slotId: slotId == null ? const Value.absent() : Value(slotId),
          savedMealId: old.meal.savedMealId == null && savedMealId != null
              ? Value(savedMealId)
              : const Value.absent(),
        ),
      );
      await _learn(lines, now.utcMs);
      return (await loadMeal(mealId))!;
    });
  }

  /// Deletes a meal and returns what Undo needs.
  ///
  /// The schema has no `deleted_at` on meals and may not change, so the rows
  /// are really deleted and held in the returned [DeletedMeal] (in memory) for
  /// [undoDeleteMeal]. Ids are never reused (AUTOINCREMENT), so Undo puts
  /// back the same ids. If the app is closed before Undo, the meal is gone.
  Future<DeletedMeal> deleteMeal(int mealId) => transaction(() async {
    final m = await loadMeal(mealId);
    if (m == null) throw StateError('No such meal');
    await (delete(meals)..where((x) => x.id.equals(mealId))).go();
    return DeletedMeal(m);
  });

  /// Puts back a deleted meal with the same ids and values. If its saved meal
  /// has been deleted since, the link is dropped.
  Future<StoredMeal> undoDeleteMeal(DeletedMeal deleted) =>
      transaction(() async {
        final m = deleted.meal;
        final sm = m.meal.savedMealId;
        final linked =
            sm != null &&
            await (select(
                  savedMeals,
                )..where((s) => s.id.equals(sm))).getSingleOrNull() !=
                null;
        await into(meals).insert(
          (linked ? m.meal : m.meal.copyWith(savedMealId: const Value(null)))
              .toCompanion(false),
        );
        for (final e in m.entries) {
          await into(mealEntries).insert(e.entry.toCompanion(false));
          await _insertNutrients(e.entry.id, e.nutrients);
        }
        return (await loadMeal(m.meal.id))!;
      });

  Future<int> _insertEntry(int mealId, int position, MealLineInput l) async {
    final id = await into(mealEntries).insert(
      MealEntriesCompanion.insert(
        mealId: mealId,
        position: position,
        foodRef: l.foodRef,
        foodName: l.foodName,
        quantity: l.quantity,
        unitLabel: l.unitLabel,
        baseQuantity: l.baseQuantity,
        baseUnit: l.baseUnit,
      ),
    );
    await _insertNutrients(id, l.nutrients);
    return id;
  }

  Future<void> _insertNutrients(int entryId, Map<int, double> nutrients) =>
      batch(
        (b) => b.insertAll(mealEntryNutrients, [
          for (final e in nutrients.entries)
            MealEntryNutrientsCompanion.insert(
              entryId: entryId,
              nutrientId: e.key,
              amount: e.value,
            ),
        ]),
      );

  String? _textOrNull(String? t) => (t == null || t.trim().isEmpty) ? null : t;

  // Learning (grammar 7.2)

  Future<void> _learn(List<MealLineInput> lines, int nowMs) async {
    for (final l in lines) {
      final key = l.learnedKey;
      if (key == null || key.isEmpty || l.inSavedMeal) continue;
      if (!l.pickedFood && !l.setAmount && !l.fromLearned) continue;
      final row = await (select(
        learnedMatches,
      )..where((m) => m.phrase.equals(key))).getSingleOrNull();
      if (l.pickedFood) {
        final same = row != null && row.foodRef == l.foodRef;
        await into(learnedMatches).insertOnConflictUpdate(
          LearnedMatchesCompanion(
            phrase: Value(key),
            foodRef: Value(l.foodRef),
            foodName: Value(l.foodName),
            // Same food: keep the learned amount. Another food: clear it,
            // unless an amount was set in this correction too.
            unitLabel: Value(
              l.setAmount ? l.unitLabel : (same ? row.unitLabel : null),
            ),
            quantity: Value(
              l.setAmount ? l.quantity : (same ? row.quantity : null),
            ),
            timesUsed: Value(same ? row.timesUsed + 1 : 1),
            updatedAtMs: Value(nowMs),
          ),
        );
      } else if (l.setAmount) {
        if (row == null) {
          await into(learnedMatches).insert(
            LearnedMatchesCompanion.insert(
              phrase: key,
              foodRef: l.foodRef,
              foodName: l.foodName,
              unitLabel: Value(l.unitLabel),
              quantity: Value(l.quantity),
              updatedAtMs: nowMs,
            ),
          );
        } else {
          await (update(
            learnedMatches,
          )..where((m) => m.phrase.equals(key))).write(
            LearnedMatchesCompanion(
              unitLabel: Value(l.unitLabel),
              quantity: Value(l.quantity),
              updatedAtMs: Value(nowMs),
            ),
          );
        }
      } else if (row != null) {
        await (update(
          learnedMatches,
        )..where((m) => m.phrase.equals(key))).write(
          LearnedMatchesCompanion(
            timesUsed: Value(row.timesUsed + 1),
            updatedAtMs: Value(nowMs),
          ),
        );
      }
    }
  }

  /// "Forget this match" (grammar 7.4): deletes the learned row for [key] at
  /// once. Returns whether there was one.
  Future<bool> forgetLearnedMatch(String key) async =>
      await (delete(learnedMatches)..where((m) => m.phrase.equals(key))).go() >
      0;

  // Reads

  /// A meal with its entries, or null.
  Future<StoredMeal?> loadMeal(int id) async {
    final rows = await (select(meals)..where((m) => m.id.equals(id))).get();
    return (await _storedMeals(rows)).firstOrNull;
  }

  Future<List<StoredMeal>> _storedMeals(List<Meal> rows) async {
    if (rows.isEmpty) return [];
    final slots = {for (final s in await select(mealSlots).get()) s.id: s.name};
    final entries =
        await (select(mealEntries)
              ..where((e) => e.mealId.isIn([for (final m in rows) m.id]))
              ..orderBy([
                (e) => OrderingTerm.asc(e.position),
                (e) => OrderingTerm.asc(e.id),
              ]))
            .get();
    final nutrients = <int, Map<int, double>>{};
    if (entries.isNotEmpty) {
      final ns = await (select(
        mealEntryNutrients,
      )..where((n) => n.entryId.isIn([for (final e in entries) e.id]))).get();
      for (final n in ns) {
        (nutrients[n.entryId] ??= {})[n.nutrientId] = n.amount;
      }
    }
    final byMeal = <int, List<StoredEntry>>{};
    for (final e in entries) {
      (byMeal[e.mealId] ??= []).add(StoredEntry(e, nutrients[e.id] ?? {}));
    }
    return [
      for (final m in rows)
        StoredMeal(m, slots[m.slotId] ?? '', byMeal[m.id] ?? []),
    ];
  }

  /// The meals of a day with entries, in meal slot order, then by logged time.
  Future<DayLog> loadDay(String localDate) =>
      transaction(() => _loadDay(localDate));

  Future<DayLog> _loadDay(String localDate) async {
    final rows = await (select(
      meals,
    )..where((m) => m.localDate.equals(localDate))).get();
    final pos = {
      for (final s in await select(mealSlots).get()) s.id: s.position,
    };
    rows.sort((a, b) {
      final c = (pos[a.slotId] ?? 0).compareTo(pos[b.slotId] ?? 0);
      if (c != 0) return c;
      final t = a.loggedAtMs.compareTo(b.loggedAtMs);
      return t != 0 ? t : a.id.compareTo(b.id);
    });
    return DayLog(localDate, await _storedMeals(rows));
  }

  /// The day, updated after every write to meals, entries or slots.
  Stream<DayLog> watchDay(String localDate) => liveQuery(this, [
    meals,
    mealEntries,
    mealEntryNutrients,
    mealSlots,
  ], () => loadDay(localDate));

  /// Yesterday's meal in the same slot, or null when there is none. Yesterday
  /// is the day before [forDate], the day being logged. If the slot was
  /// logged more than once yesterday, the last one logged is used.
  Future<StoredMeal?> sameAsYesterday({
    required String forDate,
    required int slotId,
  }) async {
    final rows =
        await (select(meals)
              ..where(
                (m) =>
                    m.localDate.equals(addDays(forDate, -1)) &
                    m.slotId.equals(slotId),
              )
              ..orderBy([
                (m) => OrderingTerm.desc(m.loggedAtMs),
                (m) => OrderingTerm.desc(m.id),
              ])
              ..limit(1))
            .get();
    return (await _storedMeals(rows)).firstOrNull;
  }

  Stream<StoredMeal?> watchSameAsYesterday({
    required String forDate,
    required int slotId,
  }) => liveQuery(this, [
    meals,
    mealEntries,
    mealEntryNutrients,
  ], () => sameAsYesterday(forDate: forDate, slotId: slotId));

  /// Foods logged in [slotId] in the last 30 days: [today] and the 29 days
  /// before it (a meal dated 30 days before [today] does not count). Most
  /// logged first (meals it was in), then most recent, then by ref so the
  /// order never changes between reads. Each has the amount last logged. At
  /// most [limit] (8).
  Future<List<RecentFood>> recentFoods({
    required int slotId,
    required String today,
    int limit = 8,
  }) async {
    final q =
        select(mealEntries)
            .join([innerJoin(meals, meals.id.equalsExp(mealEntries.mealId))])
          ..where(
            meals.slotId.equals(slotId) &
                meals.localDate.isBiggerOrEqualValue(addDays(today, -29)) &
                meals.localDate.isSmallerOrEqualValue(today),
          )
          ..orderBy([
            OrderingTerm.asc(meals.loggedAtMs),
            OrderingTerm.asc(meals.id),
            OrderingTerm.asc(mealEntries.position),
          ]);
    final inMeals = <String, Set<int>>{};
    final last = <String, (MealEntry, int)>{};
    for (final r in await q.get()) {
      final e = r.readTable(mealEntries);
      final m = r.readTable(meals);
      (inMeals[e.foodRef] ??= {}).add(m.id);
      last[e.foodRef] = (e, m.loggedAtMs);
    }
    final refs = last.keys.toList()
      ..sort((a, b) {
        final c = inMeals[b]!.length.compareTo(inMeals[a]!.length);
        if (c != 0) return c;
        final t = last[b]!.$2.compareTo(last[a]!.$2);
        return t != 0 ? t : a.compareTo(b);
      });
    final top = refs.take(limit).toList();
    final nutrients = <int, Map<int, double>>{};
    if (top.isNotEmpty) {
      final ns =
          await (select(mealEntryNutrients)..where(
                (n) => n.entryId.isIn([for (final r in top) last[r]!.$1.id]),
              ))
              .get();
      for (final n in ns) {
        (nutrients[n.entryId] ??= {})[n.nutrientId] = n.amount;
      }
    }
    return [
      for (final r in top)
        RecentFood(
          foodRef: r,
          foodName: last[r]!.$1.foodName,
          quantity: last[r]!.$1.quantity,
          unitLabel: last[r]!.$1.unitLabel,
          baseQuantity: last[r]!.$1.baseQuantity,
          baseUnit: last[r]!.$1.baseUnit,
          nutrients: nutrients[last[r]!.$1.id] ?? {},
          timesLogged: inMeals[r]!.length,
          lastLoggedAtMs: last[r]!.$2,
        ),
    ];
  }

  Stream<List<RecentFood>> watchRecentFoods({
    required int slotId,
    required String today,
    int limit = 8,
  }) => liveQuery(this, [
    meals,
    mealEntries,
    mealEntryNutrients,
  ], () => recentFoods(slotId: slotId, today: today, limit: limit));

  /// The default meal slot at a time of day (0 to 1439): the rule with the
  /// latest start at or before it, so a boundary belongs to the later slot.
  /// Rules whose slot is archived are skipped. If no rule starts at or before
  /// the time, the last rule of the day carries past midnight. With no usable
  /// rule at all, the first slot that is not archived.
  Future<MealSlot> defaultMealSlot(int minuteOfDay) async {
    final rows =
        await (select(mealSlotRules).join([
                innerJoin(
                  mealSlots,
                  mealSlots.id.equalsExp(mealSlotRules.slotId),
                ),
              ])
              ..where(mealSlots.archived.equals(false))
              ..orderBy([OrderingTerm.asc(mealSlotRules.startMinute)]))
            .get();
    MealSlot? pick;
    for (final r in rows) {
      if (r.read(mealSlotRules.startMinute)! > minuteOfDay) break;
      pick = r.readTable(mealSlots);
    }
    if (pick == null && rows.isNotEmpty) pick = rows.last.readTable(mealSlots);
    if (pick != null) return pick;
    // No usable rule: the first slot that is not archived.
    return (select(mealSlots)
          ..where((s) => s.archived.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.position)])
          ..limit(1))
        .getSingle();
  }

  // For the parser

  /// Food ref to the number of logged lines that used it.
  Future<Map<String, int>> historyCounts() async {
    final n = mealEntries.id.count();
    final q = selectOnly(mealEntries)
      ..addColumns([mealEntries.foodRef, n])
      ..groupBy([mealEntries.foodRef]);
    return {
      for (final r in await q.get()) r.read(mealEntries.foodRef)!: r.read(n)!,
    };
  }

  /// Everything the parser needs from the user's data, in plain types. Foods
  /// that are archived are left out; learned matches are all there (the
  /// parser ignores one whose food is gone, grammar 7.3).
  Future<UserSnapshotData> loadUserSnapshot({int version = 0}) =>
      transaction(() => _loadUserSnapshot(version));

  Future<UserSnapshotData> _loadUserSnapshot(int version) async {
    final foodRows = await (select(
      foods,
    )..where((f) => f.archived.equals(false))).get();
    final fn = <int, Map<int, double>>{};
    for (final n in await select(foodNutrients).get()) {
      (fn[n.foodId] ??= {})[n.nutrientId] = n.amount;
    }
    final fp = <int, List<PortionData>>{};
    final portionRows = await (select(
      foodPortions,
    )..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
    for (final p in portionRows) {
      (fp[p.foodId] ??= []).add(PortionData(p.label, p.baseQuantity));
    }
    final sn = <int, Map<int, double>>{};
    for (final n in await select(savedMealItemNutrients).get()) {
      (sn[n.itemId] ??= {})[n.nutrientId] = n.amount;
    }
    final items =
        await (select(savedMealItems)..orderBy([
              (i) => OrderingTerm.asc(i.position),
              (i) => OrderingTerm.asc(i.id),
            ]))
            .get();
    final byMeal = <int, List<SavedMealItemData>>{};
    for (final i in items) {
      (byMeal[i.savedMealId] ??= []).add(
        SavedMealItemData(
          foodRef: i.foodRef,
          foodName: i.foodName,
          quantity: i.quantity,
          unitLabel: i.unitLabel,
          baseQuantity: i.baseQuantity,
          baseUnit: i.baseUnit,
          nutrients: sn[i.id] ?? {},
        ),
      );
    }
    return UserSnapshotData(
      version: version,
      foods: [
        for (final f in foodRows)
          UserFoodData(
            ref: 'local:${f.id}',
            name: f.name,
            kind: f.kind,
            baseUnit: f.baseUnit,
            baseAmount: f.baseAmount,
            portions: fp[f.id] ?? [],
            nutrients: fn[f.id] ?? {},
          ),
      ],
      learned: [
        for (final m in await select(learnedMatches).get())
          LearnedMatchData(
            key: m.phrase,
            foodRef: m.foodRef,
            foodName: m.foodName,
            unitLabel: m.unitLabel,
            quantity: m.quantity,
            timesUsed: m.timesUsed,
          ),
      ],
      aliases: [
        for (final a in await select(aliases).get())
          AliasData(a.phrase, a.savedMealId),
      ],
      savedMeals: [
        for (final s in await select(savedMeals).get())
          SavedMealData(id: s.id, name: s.name, items: byMeal[s.id] ?? []),
      ],
      historyCounts: await historyCounts(),
    );
  }

  /// The snapshot, loaded on listen and again after every write to the tables
  /// it reads. [UserSnapshotData.version] is 1 for the first, then counts up.
  Stream<UserSnapshotData> watchUserSnapshot() {
    var version = 0;
    return liveQuery(this, [
      foods,
      foodNutrients,
      foodPortions,
      learnedMatches,
      aliases,
      savedMeals,
      savedMealItems,
      savedMealItemNutrients,
      mealEntries,
    ], () => loadUserSnapshot(version: ++version));
  }
}
