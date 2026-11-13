// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const kcal = Nutrients.energy;
const protein = Nutrients.protein;
const fat = Nutrients.fat;

/// A wall-clock time on a local date at a local offset in hours.
Now at(String date, int h, int m, [double offsetHours = 0]) =>
    Now.fromLocal(date, h * 60 + m, (offsetHours * 60).round());

/// A meal line. Nutrients default to kcal only.
MealLineInput ml(
  String ref, {
  String? name,
  double q = 1,
  String unit = '',
  double base = 100,
  String baseUnit = 'g',
  Map<int, double>? n,
  String? key,
  bool picked = false,
  bool setAmount = false,
  bool fromLearned = false,
  bool inSavedMeal = false,
  int? existingId,
}) => MealLineInput(
  foodRef: ref,
  foodName: name ?? 'Food $ref',
  quantity: q,
  unitLabel: unit,
  baseQuantity: base,
  baseUnit: baseUnit,
  nutrients: n ?? {kcal: 100},
  learnedKey: key,
  pickedFood: picked,
  setAmount: setAmount,
  fromLearned: fromLearned,
  inSavedMeal: inSavedMeal,
  existingId: existingId,
);

void main() {
  late AppDatabase db;
  late int breakfast;
  late int lunch;
  late int dinner;
  final today = at('2026-11-12', 7, 40);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    Future<int> slot(String name) async => (await (db.select(
      db.mealSlots,
    )..where((s) => s.name.equals(name))).getSingle()).id;
    breakfast = await slot('Breakfast');
    lunch = await slot('Lunch');
    dinner = await slot('Dinner');
  });
  tearDown(() => db.close());

  Future<StoredMeal> save(
    List<MealLineInput> lines, {
    String date = '2026-11-12',
    int? slot,
    Now? now,
    String? text,
    int? savedMealId,
  }) => db.saveMeal(
    now: now ?? today,
    localDate: date,
    slotId: slot ?? breakfast,
    lines: lines,
    sourceText: text,
    savedMealId: savedMealId,
  );

  Future<LearnedMatche?> learned(String key) => (db.select(
    db.learnedMatches,
  )..where((m) => m.phrase.equals(key))).getSingleOrNull();

  Future<List<MealEntryNutrient>> nutRows() async =>
      (await db.select(db.mealEntryNutrients).get())..sort(
        (a, b) => a.entryId != b.entryId
            ? a.entryId.compareTo(b.entryId)
            : a.nutrientId.compareTo(b.nutrientId),
      );

  Future<List<SavedMealItemNutrient>> savedNutRows() async =>
      (await db.select(db.savedMealItemNutrients).get())..sort(
        (a, b) => a.itemId != b.itemId
            ? a.itemId.compareTo(b.itemId)
            : a.nutrientId.compareTo(b.nutrientId),
      );

  Future<List<int>> counts() async => [
    (await db.select(db.meals).get()).length,
    (await db.select(db.mealEntries).get()).length,
    (await db.select(db.mealEntryNutrients).get()).length,
    (await db.select(db.learnedMatches).get()).length,
  ];

  group('save a meal', () {
    test('writes the meal, entries in order and nutrient copies', () async {
      final now = at('2026-11-12', 7, 40, -6);
      final m = await db.saveMeal(
        now: now,
        localDate: '2026-11-12',
        slotId: breakfast,
        sourceText: '2 eggs, toast',
        lines: [
          ml(
            'usda:1',
            name: 'Egg',
            q: 2,
            base: 100,
            n: {kcal: 176, protein: 12},
          ),
          ml(
            'usda:2',
            name: 'Toast',
            q: 1,
            unit: 'slice',
            base: 28,
            n: {kcal: 84},
          ),
        ],
      );
      expect(m.meal.localDate, '2026-11-12');
      expect(m.meal.slotId, breakfast);
      expect(m.slotName, 'Breakfast');
      expect(m.meal.loggedAtMs, now.utcMs);
      expect(m.meal.tzOffsetMinutes, -360);
      expect(m.meal.sourceText, '2 eggs, toast');
      expect(m.meal.savedMealId, isNull);
      expect(m.entries.map((e) => e.entry.position), [0, 1]);
      expect(m.entries.map((e) => e.entry.foodName), ['Egg', 'Toast']);
      expect(m.entries[0].entry.quantity, 2);
      expect(m.entries[1].entry.unitLabel, 'slice');
      expect(m.entries[1].entry.baseQuantity, 28);
      expect(m.entries[0].nutrients, {kcal: 176, protein: 12});
      expect(m.totals, {kcal: 260, protein: 12});
      final stored = await db.loadMeal(m.meal.id);
      expect(stored!.meal, m.meal);
      expect((await db.select(db.mealEntries).get()).length, 2);
    });

    test(
      'a nutrient the line does not have is not stored, never zero',
      () async {
        final m = await save([
          ml('usda:1', n: {kcal: 50}),
        ]);
        final rows = await db.select(db.mealEntryNutrients).get();
        expect(rows.map((r) => r.nutrientId), [kcal]);
        expect(m.entries.single.nutrients.containsKey(protein), isFalse);
        expect(m.totals.containsKey(protein), isFalse);
      },
    );

    test('no text, or only spaces, is stored as null', () async {
      expect((await save([ml('usda:1')])).meal.sourceText, isNull);
      expect((await save([ml('usda:1')], text: '  ')).meal.sourceText, isNull);
    });

    test('the saved meal id is stored', () async {
      final sm = (await db.createSavedMeal(
        name: 'Usual',
        items: [ml('usda:1')],
        now: today,
      )).saved!;
      final m = await save([ml('usda:1')], savedMealId: sm.meal.id);
      expect(m.meal.savedMealId, sm.meal.id);
    });

    test('a meal with no lines is refused', () {
      expect(save([]), throwsArgumentError);
    });

    test('a failure in the middle leaves no rows at all', () async {
      await db.customStatement(
        "CREATE TRIGGER boom BEFORE INSERT ON learned_matches "
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        save([
          ml('usda:1', n: {kcal: 1, protein: 2}),
          ml('usda:2', key: 'toast', picked: true),
        ]),
        throwsA(anything),
      );
      expect(await counts(), [0, 0, 0, 0]);
    });
  });

  group('learning on save, grammar 7.2', () {
    test('a picked food creates the row with times used 1', () async {
      await save([ml('usda:5', name: 'Bread', key: 'toast', picked: true)]);
      final r = (await learned('toast'))!;
      expect(r.foodRef, 'usda:5');
      expect(r.foodName, 'Bread');
      expect(r.timesUsed, 1);
      expect(r.quantity, isNull);
      expect(r.unitLabel, isNull);
      expect(r.updatedAtMs, today.utcMs);
    });

    test(
      'picking the same food again counts up and keeps its amount',
      () async {
        await save([
          ml(
            'usda:5',
            key: 'toast',
            picked: true,
            setAmount: true,
            q: 2,
            unit: 'slice',
          ),
        ]);
        final later = at('2026-11-13', 8, 0);
        await save([ml('usda:5', key: 'toast', picked: true)], now: later);
        final r = (await learned('toast'))!;
        expect(r.timesUsed, 2);
        expect(r.quantity, 2);
        expect(r.unitLabel, 'slice');
        expect(r.updatedAtMs, later.utcMs);
      },
    );

    test('picking another food replaces it and clears the amount', () async {
      await save([
        ml(
          'usda:5',
          key: 'toast',
          picked: true,
          setAmount: true,
          q: 2,
          unit: 'slice',
        ),
      ]);
      await save([ml('usda:6', name: 'Rye', key: 'toast', picked: true)]);
      final r = (await learned('toast'))!;
      expect(r.foodRef, 'usda:6');
      expect(r.foodName, 'Rye');
      expect(r.timesUsed, 1);
      expect(r.quantity, isNull);
      expect(r.unitLabel, isNull);
    });

    test('picking another food with an amount set in the same correction keeps the amount', () async {
      await save([ml('usda:5', key: 'toast', picked: true)]);
      await save([
        ml(
          'usda:6',
          key: 'toast',
          picked: true,
          setAmount: true,
          q: 3,
          unit: '',
        ),
      ]);
      final r = (await learned('toast'))!;
      expect(r.foodRef, 'usda:6');
      expect(r.timesUsed, 1);
      expect(r.quantity, 3);
      expect(r.unitLabel, '');
    });

    test(
      'an amount set on an assumed line creates the row with the current food',
      () async {
        await save([
          ml('usda:7', key: 'coffee', setAmount: true, q: 1, unit: 'cup'),
        ]);
        final r = (await learned('coffee'))!;
        expect(r.foodRef, 'usda:7');
        expect(r.quantity, 1);
        expect(r.unitLabel, 'cup');
        expect(r.timesUsed, 1);
      },
    );

    test('an amount set on an assumed line updates an existing row', () async {
      await save([ml('usda:7', key: 'coffee', picked: true)]);
      await save([
        ml('usda:7', key: 'coffee', setAmount: true, q: 2, unit: 'cup'),
      ]);
      final r = (await learned('coffee'))!;
      expect(r.foodRef, 'usda:7');
      expect(r.quantity, 2);
      expect(r.unitLabel, 'cup');
      expect(r.timesUsed, 1);
    });

    test('a typed amount teaches nothing', () async {
      // The screen sets no flag for a typed amount, even if it was changed.
      await save([ml('usda:7', key: 'coffee', q: 3, unit: 'cup')]);
      expect(await learned('coffee'), isNull);
      await save([ml('usda:7', key: 'coffee', picked: true)]);
      await save([ml('usda:7', key: 'coffee', q: 3, unit: 'cup')]);
      final r = (await learned('coffee'))!;
      expect(r.quantity, isNull);
      expect(r.timesUsed, 1);
    });

    test(
      'saving a learned line unchanged counts up and moves the time',
      () async {
        await save([ml('usda:7', key: 'coffee', picked: true)]);
        final later = at('2026-11-14', 9, 0);
        await save([
          ml('usda:7', key: 'coffee', fromLearned: true),
        ], now: later);
        final r = (await learned('coffee'))!;
        expect(r.timesUsed, 2);
        expect(r.updatedAtMs, later.utcMs);
      },
    );

    test('nothing is learned when the meal is not saved', () async {
      // The only way to write a learned match is a save. A failed save
      // writes nothing, and building lines or expanding a saved meal does not
      // touch the table.
      await db.customStatement(
        "CREATE TRIGGER boom BEFORE INSERT ON meal_entries "
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      await expectLater(
        save([ml('usda:5', key: 'toast', picked: true)]),
        throwsA(anything),
      );
      expect(await learned('toast'), isNull);
      expect(await db.select(db.learnedMatches).get(), isEmpty);
    });

    test(
      'corrections inside an expanded saved meal are never learned',
      () async {
        await save([
          ml('usda:5', key: 'toast', picked: true, inSavedMeal: true),
          ml('usda:6', key: 'egg', setAmount: true, inSavedMeal: true),
          ml('usda:7', key: 'jam', fromLearned: true, inSavedMeal: true),
        ]);
        expect(await db.select(db.learnedMatches).get(), isEmpty);
      },
    );

    test('picks on added lines (no key) are never learned', () async {
      await save([
        ml('usda:5', picked: true),
        ml('usda:6', setAmount: true),
        ml('usda:7', key: '', picked: true),
      ]);
      expect(await db.select(db.learnedMatches).get(), isEmpty);
    });

    test(
      'a typed line is learned and an added line next to it is not',
      () async {
        await save([
          ml('usda:5', picked: true),
          ml('usda:6', key: 'toast', picked: true),
        ]);
        final rows = await db.select(db.learnedMatches).get();
        expect(rows.map((r) => r.phrase), ['toast']);
      },
    );
  });

  group('edit a logged meal', () {
    test('touches only the changed lines, by id and stored value', () async {
      final m = await save([
        ml('usda:1', name: 'A', q: 1, n: {kcal: 10, protein: 1}),
        ml('usda:2', name: 'B', q: 2, n: {kcal: 20}),
        ml('usda:3', name: 'C', q: 3, n: {kcal: 30}),
      ], text: 'a, b, c');
      final a = m.entries[0], b = m.entries[1], c = m.entries[2];
      final rowsBefore = await db.select(db.mealEntries).get();
      final nutBefore = await db.select(db.mealEntryNutrients).get();

      final edited = await db.editMeal(
        m.meal.id,
        now: at('2026-11-12', 15, 15),
        lines: [
          a.asInput(keepId: true),
          ml('usda:9', name: 'D', n: {kcal: 5}),
          ml(
            'usda:2',
            name: 'B',
            q: 4,
            n: {kcal: 40, fat: 2},
            existingId: b.entry.id,
          ),
        ],
        typedText: 'and d',
      );

      expect(edited.entries.map((e) => e.entry.foodName), ['A', 'D', 'B']);
      expect(edited.entries.map((e) => e.entry.position), [0, 1, 2]);
      // Untouched: the same row, byte for byte.
      expect(edited.entries[0].entry, a.entry);
      expect(edited.entries[0].nutrients, a.nutrients);
      expect(rowsBefore.firstWhere((e) => e.id == a.entry.id), a.entry);
      // Changed: same id, new values, nutrients replaced.
      expect(edited.entries[2].entry.id, b.entry.id);
      expect(edited.entries[2].entry.quantity, 4);
      expect(edited.entries[2].nutrients, {kcal: 40, fat: 2});
      // New: a new id.
      expect([
        a.entry.id,
        b.entry.id,
        c.entry.id,
      ], isNot(contains(edited.entries[1].entry.id)));
      // Removed: its row and its nutrients are gone.
      final left = await db.select(db.mealEntries).get();
      expect(left.any((e) => e.id == c.entry.id), isFalse);
      final nutLeft = await db.select(db.mealEntryNutrients).get();
      expect(nutLeft.any((n) => n.entryId == c.entry.id), isFalse);
      expect(
        nutBefore.where((n) => n.entryId == a.entry.id).toList(),
        nutLeft.where((n) => n.entryId == a.entry.id).toList(),
      );
      expect(edited.meal.sourceText, 'a, b, c\nand d');
      expect(edited.meal.loggedAtMs, m.meal.loggedAtMs);
    });

    test(
      'an edit with nothing changed leaves every stored value identical',
      () async {
        final m = await save([
          ml('usda:1', n: {kcal: 1, protein: 2}),
          ml('usda:2'),
        ]);
        final e1 = await db.select(db.mealEntries).get();
        final n1 = await db.select(db.mealEntryNutrients).get();
        final out = await db.editMeal(
          m.meal.id,
          now: at('2026-11-13', 1, 0),
          lines: [for (final e in m.entries) e.asInput(keepId: true)],
        );
        expect(out.meal, m.meal);
        expect(await db.select(db.mealEntries).get(), e1);
        expect(await db.select(db.mealEntryNutrients).get(), n1);
      },
    );

    test('typed text is added on a new line, or becomes the text when there was none', () async {
      final m = await save([ml('usda:1')]);
      var out = await db.editMeal(
        m.meal.id,
        now: today,
        lines: [m.entries[0].asInput(keepId: true)],
        typedText: 'first',
      );
      expect(out.meal.sourceText, 'first');
      out = await db.editMeal(
        m.meal.id,
        now: today,
        lines: [m.entries[0].asInput(keepId: true)],
        typedText: 'second',
      );
      expect(out.meal.sourceText, 'first\nsecond');
      out = await db.editMeal(
        m.meal.id,
        now: today,
        lines: [m.entries[0].asInput(keepId: true)],
        typedText: '   ',
      );
      expect(out.meal.sourceText, 'first\nsecond');
    });

    test('date, slot and saved meal link change only when given', () async {
      final sm = (await db.createSavedMeal(
        name: 'Usual',
        items: [ml('usda:1')],
        now: today,
      )).saved!;
      final m = await save([ml('usda:1')]);
      var out = await db.editMeal(
        m.meal.id,
        now: today,
        lines: [m.entries[0].asInput(keepId: true)],
      );
      expect(out.meal.localDate, '2026-11-12');
      expect(out.meal.slotId, breakfast);
      expect(out.meal.savedMealId, isNull);
      out = await db.editMeal(
        m.meal.id,
        now: today,
        lines: [m.entries[0].asInput(keepId: true)],
        localDate: '2026-11-11',
        slotId: dinner,
        savedMealId: sm.meal.id,
      );
      expect(out.meal.localDate, '2026-11-11');
      expect(out.meal.slotId, dinner);
      expect(out.meal.savedMealId, sm.meal.id);
    });

    test('learning on an edit follows the same table', () async {
      final m = await save([ml('usda:1')]);
      await db.editMeal(
        m.meal.id,
        now: today,
        lines: [
          m.entries[0].asInput(keepId: true),
          ml('usda:5', key: 'toast', picked: true),
        ],
      );
      expect((await learned('toast'))!.foodRef, 'usda:5');
    });

    test(
      'the same existing id twice is refused and nothing is written',
      () async {
        final m = await save([ml('usda:1'), ml('usda:2')]);
        final id = m.entries[0].entry.id;
        final rows = await db.select(db.mealEntries).get();
        await expectLater(
          db.editMeal(
            m.meal.id,
            now: today,
            lines: [
              ml('usda:1', existingId: id),
              ml('usda:9', existingId: id),
            ],
          ),
          throwsStateError,
        );
        expect(await db.select(db.mealEntries).get(), rows);
      },
    );

    test(
      'a line that is not an entry of the meal, or no lines, is refused',
      () async {
        final m = await save([ml('usda:1')]);
        final other = await save([ml('usda:2')]);
        expect(
          db.editMeal(
            m.meal.id,
            now: today,
            lines: [other.entries[0].asInput(keepId: true)],
          ),
          throwsStateError,
        );
        expect(
          db.editMeal(m.meal.id, now: today, lines: []),
          throwsArgumentError,
        );
        expect(
          db.editMeal(999, now: today, lines: [ml('usda:1')]),
          throwsStateError,
        );
      },
    );
  });

  group('delete a meal with Undo', () {
    test('Undo restores exactly the same rows', () async {
      final sm = (await db.createSavedMeal(
        name: 'Usual',
        items: [ml('usda:1')],
        now: today,
      )).saved!;
      final m = await save(
        [
          ml('usda:1', n: {kcal: 1, protein: 2}),
          ml('usda:2', n: {kcal: 3}),
        ],
        text: 'typed',
        savedMealId: sm.meal.id,
      );
      await save([ml('usda:9')]); // another meal, left alone
      final meals1 = await db.select(db.meals).get();
      final entries1 = await db.select(db.mealEntries).get();
      final nuts1 = await nutRows();

      final held = await db.deleteMeal(m.meal.id);
      expect(await db.loadMeal(m.meal.id), isNull);
      expect((await db.select(db.meals).get()).length, 1);
      expect((await db.select(db.mealEntries).get()).length, 1);
      expect((await db.select(db.mealEntryNutrients).get()).length, 1);

      final back = await db.undoDeleteMeal(held);
      expect(back.meal, m.meal);
      expect(await db.select(db.meals).get(), meals1);
      expect(await db.select(db.mealEntries).get(), entries1);
      expect(await nutRows(), nuts1);
    });

    test('Undo after the saved meal was deleted drops the link', () async {
      final sm = (await db.createSavedMeal(
        name: 'Usual',
        items: [ml('usda:1')],
        now: today,
      )).saved!;
      final m = await save([ml('usda:1')], savedMealId: sm.meal.id);
      final held = await db.deleteMeal(m.meal.id);
      await db.deleteSavedMeal(sm.meal.id);
      final back = await db.undoDeleteMeal(held);
      expect(back.meal.savedMealId, isNull);
      expect(back.entries.length, 1);
    });

    test(
      'a second Undo of the same deleted meal is refused and leaves one copy',
      () async {
        final m = await save([
          ml('usda:1', n: {kcal: 1}),
        ]);
        final held = await db.deleteMeal(m.meal.id);
        await db.undoDeleteMeal(held);
        await expectLater(db.undoDeleteMeal(held), throwsA(anything));
        expect(await counts(), [1, 1, 1, 0]);
      },
    );

    test('two saves started at the same moment both land', () async {
      final both = await Future.wait([
        save([ml('usda:1')]),
        save([ml('usda:2')]),
      ]);
      expect(both[0].meal.id, isNot(both[1].meal.id));
      expect(await counts(), [2, 2, 2, 0]);
    });

    test('deleting a meal that is not there is refused', () {
      expect(db.deleteMeal(5), throwsStateError);
    });
  });

  group('the day', () {
    test(
      'meals in slot order with per meal and per day totals, unrounded',
      () async {
        await save([
          ml('a', n: {kcal: 100.25, protein: 1.5}),
        ], slot: lunch);
        await save([
          ml('b', n: {kcal: 200.5}),
          ml('c', n: {kcal: 50, fat: 3.25}),
        ], slot: breakfast);
        await save([ml('d')], date: '2026-11-11', slot: breakfast);
        final day = await db.loadDay('2026-11-12');
        expect(day.meals.map((m) => m.slotName), ['Breakfast', 'Lunch']);
        expect(day.meals[0].totals, {kcal: 250.5, fat: 3.25});
        expect(day.meals[1].totals, {kcal: 100.25, protein: 1.5});
        expect(day.totals, {kcal: 350.75, fat: 3.25, protein: 1.5});
        expect((await db.loadDay('2026-11-10')).meals, isEmpty);
      },
    );

    test('the watched day updates on save, edit and delete', () async {
      final seen = <double>[];
      final sub = db
          .watchDay('2026-11-12')
          .listen((d) => seen.add(d.totals[kcal] ?? 0));
      await pumpEventQueue();
      expect(seen, [0]);
      final m = await save([
        ml('a', n: {kcal: 100}),
      ]);
      await pumpEventQueue();
      expect(seen.last, 100);
      await db.editMeal(
        m.meal.id,
        now: today,
        lines: [
          ml('a', n: {kcal: 150}, existingId: m.entries[0].entry.id),
        ],
      );
      await pumpEventQueue();
      expect(seen.last, 150);
      await db.deleteMeal(m.meal.id);
      await pumpEventQueue();
      expect(seen.last, 0);
      await sub.cancel();
    });
  });

  group('same as yesterday', () {
    test('is yesterday in the same slot', () async {
      await save([ml('a')], date: '2026-11-11', slot: breakfast);
      await save([ml('b')], date: '2026-11-11', slot: lunch);
      await save([ml('c')], date: '2026-11-10', slot: breakfast);
      await save([ml('d')], date: '2026-11-12', slot: breakfast);
      final m = await db.sameAsYesterday(
        forDate: '2026-11-12',
        slotId: breakfast,
      );
      expect(m!.entries.map((e) => e.entry.foodRef), ['a']);
      final l = await db.sameAsYesterday(forDate: '2026-11-12', slotId: lunch);
      expect(l!.entries.single.entry.foodRef, 'b');
    });

    test('is absent when yesterday has nothing in that slot', () async {
      await save([ml('b')], date: '2026-11-11', slot: lunch);
      expect(
        await db.sameAsYesterday(forDate: '2026-11-12', slotId: breakfast),
        isNull,
      );
      expect(
        await db.sameAsYesterday(forDate: '2026-11-12', slotId: dinner),
        isNull,
      );
    });

    test('works across a daylight saving change day', () async {
      await save([ml('a')], date: '2026-03-08');
      await save([ml('b')], date: '2026-11-01');
      final spring = await db.sameAsYesterday(
        forDate: '2026-03-09',
        slotId: breakfast,
      );
      expect(spring!.entries.single.entry.foodRef, 'a');
      final fall = await db.sameAsYesterday(
        forDate: '2026-11-02',
        slotId: breakfast,
      );
      expect(fall!.entries.single.entry.foodRef, 'b');
    });

    test(
      'works across a month and year boundary, and takes the last logged',
      () async {
        await save([ml('a')], date: '2025-12-31', now: at('2025-12-31', 7, 0));
        await save([ml('b')], date: '2025-12-31', now: at('2025-12-31', 9, 0));
        final m = await db.sameAsYesterday(
          forDate: '2026-01-01',
          slotId: breakfast,
        );
        expect(m!.entries.single.entry.foodRef, 'b');
      },
    );

    test('its entries make a new meal that is stored by itself', () async {
      final y = await save(
        [
          ml('a', n: {kcal: 5, protein: 1}),
        ],
        date: '2026-11-11',
        text: 'old text',
      );
      final copy = (await db.sameAsYesterday(
        forDate: '2026-11-12',
        slotId: breakfast,
      ))!;
      final m = await save([for (final e in copy.entries) e.asInput()]);
      expect(m.meal.id, isNot(y.meal.id));
      expect(m.meal.sourceText, isNull);
      expect(m.entries.single.nutrients, {kcal: 5, protein: 1});
      expect(m.entries.single.entry.id, isNot(y.entries.single.entry.id));
    });
  });

  group('recent and frequent foods', () {
    test('most logged first, then most recent, then ref', () async {
      await save(
        [ml('egg', q: 2)],
        date: '2026-11-08',
        now: at('2026-11-08', 7, 0),
      );
      await save(
        [ml('egg', q: 3), ml('coffee')],
        date: '2026-11-10',
        now: at('2026-11-10', 7, 0),
      );
      await save(
        [ml('banana')],
        date: '2026-11-11',
        now: at('2026-11-11', 7, 0),
      );
      await save(
        [ml('zebra'), ml('apple')],
        date: '2026-11-09',
        now: at('2026-11-09', 7, 0),
      );
      final r = await db.recentFoods(slotId: breakfast, today: '2026-11-12');
      // egg 2 meals; then banana (11th), coffee (10th); then zebra and apple
      // tie on count and time, so by ref.
      expect(r.map((f) => f.foodRef), [
        'egg',
        'banana',
        'coffee',
        'apple',
        'zebra',
      ]);
      expect(r.first.timesLogged, 2);
    });

    test('each has the amount and nutrients last logged', () async {
      await save(
        [
          ml('egg', q: 2, unit: '', base: 100, n: {kcal: 176}),
        ],
        date: '2026-11-08',
        now: at('2026-11-08', 7, 0),
      );
      await save(
        [
          ml(
            'egg',
            q: 3,
            unit: 'large',
            base: 150,
            n: {kcal: 264, protein: 18},
          ),
        ],
        date: '2026-11-10',
        now: at('2026-11-10', 7, 0),
      );
      final egg = (await db.recentFoods(
        slotId: breakfast,
        today: '2026-11-12',
      )).single;
      expect(egg.quantity, 3);
      expect(egg.unitLabel, 'large');
      expect(egg.baseQuantity, 150);
      expect(egg.baseUnit, 'g');
      expect(egg.nutrients, {kcal: 264, protein: 18});
      expect(egg.lastLoggedAtMs, at('2026-11-10', 7, 0).utcMs);
      expect(egg.asInput().quantity, 3);
    });

    test('only this slot, and only the last 30 days up to today', () async {
      await save(
        [ml('thirty')],
        date: '2026-10-14',
        now: at('2026-10-14', 7, 0),
      );
      await save(
        [ml('thirtyone')],
        date: '2026-10-13',
        now: at('2026-10-13', 7, 0),
      );
      await save([ml('lunchy')], date: '2026-11-10', slot: lunch);
      await save([ml('future')], date: '2026-11-13');
      await save([ml('now')], date: '2026-11-12');
      final r = await db.recentFoods(slotId: breakfast, today: '2026-11-12');
      expect(r.map((f) => f.foodRef).toSet(), {'thirty', 'now'});
    });

    test(
      'at most 8, and the same food twice in one meal counts once',
      () async {
        for (var i = 0; i < 10; i++) {
          await save(
            [ml('f$i')],
            date: '2026-11-10',
            now: at('2026-11-10', 7, i),
          );
        }
        await save(
          [ml('twice'), ml('twice')],
          date: '2026-11-01',
          now: at('2026-11-01', 7, 0),
        );
        final r = await db.recentFoods(slotId: breakfast, today: '2026-11-12');
        expect(r.length, 8);
        expect(r.first.foodRef, 'f9');
        expect(r.map((f) => f.foodRef), isNot(contains('twice')));
        final all = await db.recentFoods(
          slotId: breakfast,
          today: '2026-11-12',
          limit: 20,
        );
        expect(all.firstWhere((f) => f.foodRef == 'twice').timesLogged, 1);
      },
    );

    test('the watched list updates after a save', () async {
      final seen = <int>[];
      final sub = db
          .watchRecentFoods(slotId: breakfast, today: '2026-11-12')
          .listen((l) => seen.add(l.length));
      await pumpEventQueue();
      await save([ml('a')]);
      await pumpEventQueue();
      expect(seen, [0, 1]);
      await sub.cancel();
    });
  });

  group('default meal by time of day', () {
    test(
      'follows the rules, and a boundary belongs to the later slot',
      () async {
        Future<String> at_(int h, int m) async =>
            (await db.defaultMealSlot(h * 60 + m)).name;
        expect(await at_(0, 0), 'Breakfast');
        expect(await at_(7, 40), 'Breakfast');
        expect(await at_(10, 29), 'Breakfast');
        expect(await at_(10, 30), 'Lunch');
        expect(await at_(14, 29), 'Lunch');
        expect(await at_(14, 30), 'Snack');
        expect(await at_(16, 59), 'Snack');
        expect(await at_(17, 0), 'Dinner');
        expect(await at_(20, 59), 'Dinner');
        expect(await at_(21, 0), 'Snack');
        expect(await at_(23, 59), 'Snack');
      },
    );

    test('works from the clock', () async {
      expect(
        (await db.defaultMealSlot(at('2026-11-12', 10, 30, -6).minuteOfDay)).id,
        lunch,
      );
    });

    test('skips a rule whose slot is archived', () async {
      await (db.update(db.mealSlots)..where((s) => s.id.equals(breakfast)))
          .write(const MealSlotsCompanion(archived: Value(true)));
      // Breakfast's rule is skipped and nothing earlier is left, so the last
      // rule of the day (Snack after 21:00) carries past midnight.
      expect((await db.defaultMealSlot(480)).name, 'Snack');
      expect((await db.defaultMealSlot(11 * 60)).name, 'Lunch');
    });

    test(
      'the last rule of the day carries past midnight when none starts at 0:00',
      () async {
        await (db.delete(
          db.mealSlotRules,
        )..where((r) => r.startMinute.equals(0))).go();
        expect((await db.defaultMealSlot(0)).name, 'Snack');
        expect((await db.defaultMealSlot(10 * 60 + 29)).name, 'Snack');
        expect((await db.defaultMealSlot(10 * 60 + 30)).name, 'Lunch');
      },
    );

    test('falls back to the first slot when no rule applies', () async {
      await db.delete(db.mealSlotRules).go();
      expect((await db.defaultMealSlot(600)).id, breakfast);
      await (db.update(db.mealSlots)..where((s) => s.id.equals(breakfast)))
          .write(const MealSlotsCompanion(archived: Value(true)));
      expect((await db.defaultMealSlot(600)).id, lunch);
    });
  });

  group('saved meals and aliases', () {
    Future<SavedMealDetail> create(
      String name, {
      List<String> aliases = const [],
      List<MealLineInput>? items,
    }) async => (await db.createSavedMeal(
      name: name,
      items:
          items ??
          [
            ml('usda:1', n: {kcal: 176, protein: 12}),
          ],
      now: today,
      aliases: aliases,
    )).saved!;

    test(
      'create from lines keeps order, amounts and nutrient copies',
      () async {
        final d = await create(
          'Usual breakfast',
          aliases: ['Usual Breakfast', 'ub'],
          items: [
            ml(
              'usda:1',
              name: 'Egg',
              q: 2,
              base: 100,
              n: {kcal: 176, protein: 12},
            ),
            ml(
              'usda:2',
              name: 'Toast',
              q: 1,
              unit: 'slice',
              base: 28,
              n: {kcal: 84},
            ),
          ],
        );
        expect(d.meal.name, 'Usual breakfast');
        expect(d.meal.createdAtMs, today.utcMs);
        expect(d.aliases, ['Usual Breakfast', 'ub']);
        expect(d.items.map((i) => i.item.foodName), ['Egg', 'Toast']);
        expect(d.items.map((i) => i.item.position), [0, 1]);
        expect(d.items[0].nutrients, {kcal: 176, protein: 12});
        expect(d.items[1].nutrients.containsKey(protein), isFalse);
        expect(d.totals, {kcal: 260, protein: 12});
      },
    );

    test('alias phrases are stored as typed, trimmed', () async {
      final d = await create('X', aliases: ["  Mom's  CAFÉ!! "]);
      expect(d.aliases, ["Mom's  CAFÉ!!"]);
      expect(
        (await db.select(db.aliases).get()).single.phrase,
        "Mom's  CAFÉ!!",
      );
    });

    test(
      'a phrase used by another saved meal is refused and nothing is written',
      () async {
        await create('Usual breakfast', aliases: ['usual breakfast', 'ub']);
        final r = await db.createSavedMeal(
          name: 'Other',
          items: [ml('usda:9')],
          now: today,
          aliases: ['fresh', 'UB.', 'Usual  Breakfast'],
        );
        expect(r.ok, isFalse);
        expect(r.saved, isNull);
        expect(r.problems, {
          'UB.': AliasProblem.taken,
          'Usual  Breakfast': AliasProblem.taken,
        });
        expect((await db.select(db.savedMeals).get()).length, 1);
        expect((await db.select(db.savedMealItems).get()).length, 1);
        expect((await db.select(db.aliases).get()).length, 2);
      },
    );

    test('PB&J is stored and read back as typed, and spellings that parse the same are taken', () async {
      final a = await create('A', aliases: ['PB&J', 'coffee w/ milk']);
      expect(a.aliases, ['PB&J', 'coffee w/ milk']);
      expect((await db.loadSavedMeal(a.meal.id))!.aliases, [
        'PB&J',
        'coffee w/ milk',
      ]);
      for (final same in [
        'pb and j',
        'pb & j',
        'coffee with milk',
        'Coffee W/ Milk',
      ]) {
        final r = await db.createSavedMeal(
          name: 'B',
          items: [ml('usda:9')],
          now: today,
          aliases: [same],
        );
        expect(r.problems, {same: AliasProblem.taken}, reason: same);
      }
      expect((await db.select(db.savedMeals).get()).length, 1);
      expect((await db.select(db.aliases).get()).length, 2);
    });

    test('the same alias can be saved again on the same saved meal', () async {
      final a = await create('A', aliases: ['PB&J']);
      final again = await db.updateSavedMeal(a.meal.id, aliases: ['PB&J']);
      expect(again.saved!.aliases, ['PB&J']);
      final respelled = await db.updateSavedMeal(
        a.meal.id,
        aliases: ['pb and j'],
      );
      expect(respelled.saved!.aliases, ['pb and j']);
    });

    test('aliases that differ only in case or accents clash', () async {
      await create('A', aliases: ['Café au lait']);
      for (final same in [
        'CAFÉ AU LAIT',
        'cafe au lait',
        'Cafe\u0301 au lait',
      ]) {
        final r = await db.createSavedMeal(
          name: 'B',
          items: [ml('usda:9')],
          now: today,
          aliases: [same],
        );
        expect(r.problems, {same: AliasProblem.taken}, reason: same);
      }
    });

    test('two spellings of one alias in one save are stored once', () async {
      final a = await create('A', aliases: ['PB&J', 'pb and j']);
      expect(a.aliases, ['PB&J']);
    });

    test('the snapshot gets the phrase as typed', () async {
      final a = await create('A', aliases: ['PB&J']);
      final s = await db.loadUserSnapshot();
      expect(s.aliases.single.phrase, 'PB&J');
      expect(s.aliases.single.savedMealId, a.meal.id);
    });

    test('an empty phrase is refused', () async {
      final r = await db.createSavedMeal(
        name: 'X',
        items: [ml('usda:9')],
        now: today,
        aliases: ['  !! '],
      );
      expect(r.problems, {'': AliasProblem.empty});
      expect(await db.select(db.savedMeals).get(), isEmpty);
    });

    test('a saved meal keeps its own phrases on update, and cannot take another one', () async {
      final a = await create('A', aliases: ['alpha']);
      final b = await create('B', aliases: ['beta']);
      final ok = await db.updateSavedMeal(
        a.meal.id,
        aliases: ['alpha', 'also'],
      );
      expect(ok.saved!.aliases, ['alpha', 'also']);
      final bad = await db.updateSavedMeal(
        b.meal.id,
        name: 'B2',
        aliases: ['Alpha'],
      );
      expect(bad.problems, {'Alpha': AliasProblem.taken});
      final still = (await db.loadSavedMeal(b.meal.id))!;
      expect(still.meal.name, 'B');
      expect(still.aliases, ['beta']);
    });

    test('rename and replace items', () async {
      final a = await create('A', aliases: ['alpha']);
      final r = await db.updateSavedMeal(
        a.meal.id,
        name: ' Renamed ',
        items: [
          ml('usda:5', name: 'New', q: 3, n: {kcal: 9}),
        ],
      );
      final d = r.saved!;
      expect(d.meal.name, 'Renamed');
      expect(d.aliases, ['alpha']);
      expect(d.items.single.item.foodName, 'New');
      expect(d.items.single.nutrients, {kcal: 9});
      expect((await db.select(db.savedMealItems).get()).length, 1);
      expect((await db.select(db.savedMealItemNutrients).get()).length, 1);
    });

    test('saving a saved meal never changes meals already logged', () async {
      final a = await create('A');
      final m = await save([
        ml('usda:1', n: {kcal: 176}),
      ], savedMealId: a.meal.id);
      await db.updateSavedMeal(
        a.meal.id,
        items: [
          ml('usda:1', n: {kcal: 1}),
        ],
      );
      final back = (await db.loadMeal(m.meal.id))!;
      expect(back.entries.single.nutrients, {kcal: 176});
      expect(back.meal.savedMealId, a.meal.id);
    });

    test('delete removes items and aliases and clears the link; Undo puts them back', () async {
      final a = await create(
        'A',
        aliases: ['alpha'],
        items: [
          ml('usda:1', n: {kcal: 1, protein: 2}),
          ml('usda:2'),
        ],
      );
      final m = await save([ml('usda:1')], savedMealId: a.meal.id);
      final items1 = await db.select(db.savedMealItems).get();
      final nuts1 = await savedNutRows();

      final held = await db.deleteSavedMeal(a.meal.id);
      expect(await db.select(db.savedMeals).get(), isEmpty);
      expect(await db.select(db.savedMealItems).get(), isEmpty);
      expect(await db.select(db.savedMealItemNutrients).get(), isEmpty);
      expect(await db.select(db.aliases).get(), isEmpty);
      expect((await db.loadMeal(m.meal.id))!.meal.savedMealId, isNull);
      // The phrase is free again.
      final other = await create('B', aliases: ['alpha']);
      await db.deleteSavedMeal(other.meal.id);

      final back = await db.undoDeleteSavedMeal(held);
      expect(back.meal, a.meal);
      expect(back.aliases, ['alpha']);
      expect(await db.select(db.savedMealItems).get(), items1);
      expect(await savedNutRows(), nuts1);
      expect((await db.loadMeal(m.meal.id))!.meal.savedMealId, a.meal.id);
    });

    test(
      'Undo skips a restored alias whose key a newer saved meal has',
      () async {
        final a = await create('A', aliases: ['PB & J', 'keep me']);
        final held = await db.deleteSavedMeal(a.meal.id);
        final e = await create('E', aliases: ['pb and j']);

        final back = await db.undoDeleteSavedMeal(held);
        expect(back.aliases, ['keep me']);
        final stored = await db.select(db.aliases).get();
        expect(
          {for (final s in stored) s.phrase: s.savedMealId},
          {'pb and j': e.meal.id, 'keep me': a.meal.id},
        );
      },
    );

    test('Undo with no clash restores every alias as typed', () async {
      final a = await create('A', aliases: ['PB & J', 'Usual  Café', 'ub']);
      final held = await db.deleteSavedMeal(a.meal.id);
      await create('B', aliases: ['other']);

      final back = await db.undoDeleteSavedMeal(held);
      expect(back.aliases, unorderedEquals(['PB & J', 'Usual  Café', 'ub']));
    });

    test(
      'expanding multiplies amounts and nutrients, and marks the items',
      () async {
        final a = await create(
          'A',
          items: [
            ml(
              'usda:1',
              q: 2,
              unit: '',
              base: 100,
              n: {kcal: 176, protein: 12},
            ),
            ml('usda:2', q: 1, unit: 'slice', base: 28, n: {kcal: 84}),
          ],
        );
        final x = (await db.expandSavedMeal(a.meal.id, multiplier: 0.5))!;
        expect(x.savedMealId, a.meal.id);
        expect(x.name, 'A');
        expect(x.multiplier, 0.5);
        expect(x.items.map((i) => i.quantity), [1, 0.5]);
        expect(x.items.map((i) => i.baseQuantity), [50, 14]);
        expect(x.items[0].nutrients, {kcal: 88, protein: 6});
        expect(x.items[1].nutrients, {kcal: 42});
        expect(x.items.every((i) => i.inSavedMeal), isTrue);
        expect(x.items[1].unitLabel, 'slice');
        final one = (await db.expandSavedMeal(a.meal.id))!;
        expect(one.items[0].nutrients, {kcal: 176, protein: 12});
        expect(await db.expandSavedMeal(999), isNull);
        // Stored lines are the multiplied ones.
        final m = await save(x.items, savedMealId: x.savedMealId);
        expect(m.entries[0].entry.quantity, 1);
        expect(m.totals, {kcal: 130, protein: 6});
      },
    );

    test('ordered by use in this slot, then by name', () async {
      final a = await create('Alpha');
      final b = await create('beta');
      final c = await create('Charlie');
      final d = await create('Delta');
      for (var i = 0; i < 2; i++) {
        await save([ml('x')], savedMealId: b.meal.id);
      }
      await save([ml('x')], savedMealId: a.meal.id);
      for (var i = 0; i < 5; i++) {
        await save([ml('x')], slot: lunch, savedMealId: c.meal.id);
      }
      List<String> names(List<SavedMealDetail> l) => [
        for (final s in l) s.meal.name,
      ];
      final inBreakfast = await db.savedMealsList(slotId: breakfast);
      expect(names(inBreakfast), ['beta', 'Alpha', 'Charlie', 'Delta']);
      expect(inBreakfast.map((s) => s.timesUsedInSlot), [2, 1, 0, 0]);
      expect(names(await db.savedMealsList(slotId: lunch)), [
        'Charlie',
        'Alpha',
        'beta',
        'Delta',
      ]);
      expect(names(await db.savedMealsList(slotId: dinner)), [
        'Alpha',
        'beta',
        'Charlie',
        'Delta',
      ]);
      expect(names(await db.savedMealsList()), [
        'Alpha',
        'beta',
        'Charlie',
        'Delta',
      ]);
      expect(d.meal.id, isNonZero);
    });

    test('the watched list updates when a saved meal is used', () async {
      final a = await create('Alpha');
      await create('Beta');
      final seen = <String>[];
      final sub = db
          .watchSavedMeals(slotId: breakfast)
          .listen((l) => seen.add(l.first.meal.name));
      await pumpEventQueue();
      expect(seen, ['Alpha']);
      await save([ml('x')], savedMealId: a.meal.id);
      await pumpEventQueue();
      expect(seen.last, 'Alpha');
      final b = (await db.savedMealsList()).last;
      await save([ml('x')], savedMealId: b.meal.id);
      await save([ml('x')], savedMealId: b.meal.id);
      await pumpEventQueue();
      expect(seen.last, 'Beta');
      await sub.cancel();
    });

    test('a name is required', () {
      expect(
        db.createSavedMeal(name: ' ', items: [ml('a')], now: today),
        throwsArgumentError,
      );
    });
  });

  group('custom foods', () {
    test(
      'per serving with a serving weight: grams, and a 1 serving portion',
      () async {
        final f = await db.createCustomFood(
          const CustomFoodInput(
            name: ' Zorbo ',
            brand: 'Acme',
            barcode: '0123456789012',
            basis: FoodBasis.perServing,
            servingSize: 30,
            nutrients: {kcal: 90, protein: 4},
          ),
          today,
        );
        expect(f.food.kind, 'custom');
        expect(f.food.name, 'Zorbo');
        expect(f.food.brand, 'Acme');
        expect(f.food.barcode, '0123456789012');
        expect(f.food.baseUnit, 'g');
        expect(f.food.baseAmount, 30);
        expect(f.food.createdAtMs, today.utcMs);
        expect(f.nutrients, {kcal: 90, protein: 4});
        expect(f.portions.map((p) => (p.label, p.baseQuantity)), [
          ('1 serving', 30.0),
        ]);
        expect(f.ref, 'local:${f.food.id}');
        expect(f.basis, FoodBasis.perServing);
        expect(f.servingSize, 30);
      },
    );

    test(
      'per serving without a weight: base unit serving, no portion',
      () async {
        final f = await db.createCustomFood(
          const CustomFoodInput(
            name: 'Zorbo',
            basis: FoodBasis.perServing,
            nutrients: {kcal: 90},
          ),
          today,
        );
        expect(f.food.baseUnit, 'serving');
        expect(f.food.baseAmount, 1);
        expect(f.portions, isEmpty);
        expect(f.food.brand, isNull);
        expect(f.food.barcode, isNull);
        expect(f.basis, FoodBasis.perServing);
        expect(f.servingSize, isNull);
      },
    );

    test(
      'per 100 g and per 100 ml, with a serving and extra portions',
      () async {
        final g = await db.createCustomFood(
          const CustomFoodInput(
            name: 'Cookie',
            basis: FoodBasis.per100g,
            servingSize: 20,
            portions: [PortionInput('1 big cookie', 40)],
            nutrients: {kcal: 480},
          ),
          today,
        );
        expect(g.food.baseUnit, 'g');
        expect(g.food.baseAmount, 100);
        expect(g.portions.map((p) => (p.label, p.baseQuantity)), [
          ('1 serving', 20.0),
          ('1 big cookie', 40.0),
        ]);
        expect(g.basis, FoodBasis.per100g);
        expect(g.servingSize, 20);
        final ml100 = await db.createCustomFood(
          const CustomFoodInput(
            name: 'Juice',
            basis: FoodBasis.per100ml,
            nutrients: {kcal: 45},
          ),
          today,
        );
        expect(ml100.food.baseUnit, 'ml');
        expect(ml100.food.baseAmount, 100);
        expect(ml100.basis, FoodBasis.per100ml);
      },
    );

    test('nutrients left empty are not stored', () async {
      final f = await db.createCustomFood(
        const CustomFoodInput(
          name: 'Zorbo',
          basis: FoodBasis.per100g,
          nutrients: {kcal: 90},
        ),
        today,
      );
      final rows = await db.select(db.foodNutrients).get();
      expect(rows.map((r) => (r.foodId, r.nutrientId, r.amount)), [
        (f.food.id, kcal, 90.0),
      ]);
    });

    test('a name and calories are required, and a serving needs a size', () {
      expect(
        db.createCustomFood(
          const CustomFoodInput(
            name: ' ',
            basis: FoodBasis.per100g,
            nutrients: {kcal: 1},
          ),
          today,
        ),
        throwsArgumentError,
      );
      expect(
        db.createCustomFood(
          const CustomFoodInput(
            name: 'x',
            basis: FoodBasis.per100g,
            nutrients: {protein: 1},
          ),
          today,
        ),
        throwsArgumentError,
      );
      expect(
        db.createCustomFood(
          const CustomFoodInput(
            name: 'x',
            basis: FoodBasis.perServing,
            servingSize: 0,
            nutrients: {kcal: 1},
          ),
          today,
        ),
        throwsArgumentError,
      );
    });

    test('edit replaces fields, nutrients and portions', () async {
      final f = await db.createCustomFood(
        const CustomFoodInput(
          name: 'Zorbo',
          basis: FoodBasis.perServing,
          servingSize: 30,
          nutrients: {kcal: 90, protein: 4},
        ),
        today,
      );
      final later = at('2026-11-13', 8, 0);
      final e = await db.editCustomFood(
        f.food.id,
        const CustomFoodInput(
          name: 'Zorbo 2',
          basis: FoodBasis.per100g,
          nutrients: {kcal: 300},
        ),
        later,
      );
      expect(e.food.id, f.food.id);
      expect(e.food.name, 'Zorbo 2');
      expect(e.food.baseAmount, 100);
      expect(e.nutrients, {kcal: 300});
      expect(e.portions, isEmpty);
      expect(e.food.createdAtMs, today.utcMs);
      expect(e.food.updatedAtMs, later.utcMs);
      expect(
        db.editCustomFood(
          999,
          const CustomFoodInput(
            name: 'x',
            basis: FoodBasis.per100g,
            nutrients: {kcal: 1},
          ),
          later,
        ),
        throwsStateError,
      );
    });

    test('archive instead of delete, and back', () async {
      final f = await db.createCustomFood(
        const CustomFoodInput(
          name: 'Zorbo',
          basis: FoodBasis.per100g,
          nutrients: {kcal: 1},
        ),
        today,
      );
      final later = at('2026-11-13', 8, 0);
      final a = await db.archiveFood(f.food.id, later);
      expect(a.food.archived, isTrue);
      expect(a.food.updatedAtMs, later.utcMs);
      expect(await db.myFoods(), isEmpty);
      expect((await db.myFoods(includeArchived: true)).length, 1);
      expect(
        (await db.archiveFood(f.food.id, later, archived: false)).food.archived,
        isFalse,
      );
      expect((await db.myFoods()).length, 1);
    });

    test('the My foods list has custom foods and recipes by name, not cached products', () async {
      Future<void> custom(String name) => db.createCustomFood(
        CustomFoodInput(
          name: name,
          basis: FoodBasis.per100g,
          nutrients: {kcal: 1},
        ),
        today,
      );
      await custom('banana bread');
      await custom('Apple pie');
      await db.createRecipe(
        RecipeInput(name: 'Chili', servings: 4, ingredients: [ml('usda:1')]),
        today,
      );
      await db
          .into(db.foods)
          .insert(
            FoodsCompanion.insert(
              kind: 'off',
              name: 'Scanned',
              baseAmount: 100,
              baseUnit: 'g',
              createdAtMs: 0,
              updatedAtMs: 0,
            ),
          );
      final seen = <List<String>>[];
      final sub = db.watchMyFoods().listen(
        (l) => seen.add([for (final f in l) f.food.name]),
      );
      await pumpEventQueue();
      expect(seen.last, ['Apple pie', 'banana bread', 'Chili']);
      await custom('Cherry');
      await pumpEventQueue();
      expect(seen.last, ['Apple pie', 'banana bread', 'Cherry', 'Chili']);
      await sub.cancel();
    });
  });

  group('recipes', () {
    final ingredients = [
      ml(
        'usda:1',
        name: 'Turkey',
        q: 1,
        unit: 'lb',
        base: 453,
        n: {kcal: 680, protein: 100},
      ),
      ml(
        'usda:2',
        name: 'Beans',
        q: 1,
        unit: 'can',
        base: 436,
        n: {kcal: 353, protein: 10},
      ),
      ml(
        'usda:3',
        name: 'Tomatoes',
        q: 1,
        unit: 'cup',
        base: 240,
        n: {kcal: 103},
      ),
      ml(
        'usda:4',
        name: 'Onions',
        q: 1,
        unit: 'whole',
        base: 148,
        n: {kcal: 56},
      ),
      ml(
        'usda:5',
        name: 'Chili powder',
        q: 2,
        unit: 'tbsp',
        base: 16,
        n: {kcal: 45, protein: 3},
      ),
    ];

    test('makes 4: base amount 4 servings, the whole pot nutrients, ingredients in order', () async {
      final r = await db.createRecipe(
        RecipeInput(
          name: 'Turkey chili',
          servings: 4,
          ingredients: ingredients,
        ),
        today,
      );
      expect(r.food.kind, 'recipe');
      expect(r.food.baseUnit, 'serving');
      expect(r.food.baseAmount, 4);
      expect(r.nutrients, {kcal: 1237, protein: 113});
      expect(r.ingredients.map((i) => i.foodName), [
        'Turkey',
        'Beans',
        'Tomatoes',
        'Onions',
        'Chili powder',
      ]);
      expect(r.ingredients.map((i) => i.position), [0, 1, 2, 3, 4]);
      expect(r.ingredients[0].baseQuantity, 453);
      expect(r.ingredients[4].unitLabel, 'tbsp');
      expect(r.ingredients[0].recipeFoodId, r.food.id);
      expect(r.portions, isEmpty);
    });

    test('a nutrient no ingredient has is not stored', () async {
      final r = await db.createRecipe(
        RecipeInput(
          name: 'R',
          servings: 2,
          ingredients: [
            ml('usda:1', n: {kcal: 5}),
          ],
        ),
        today,
      );
      expect(r.nutrients, {kcal: 5});
    });

    test('edit replaces ingredients, servings and nutrients', () async {
      final r = await db.createRecipe(
        RecipeInput(name: 'Chili', servings: 4, ingredients: ingredients),
        today,
      );
      final e = await db.editRecipe(
        r.food.id,
        RecipeInput(
          name: 'Chili 2',
          servings: 2,
          ingredients: [
            ml('usda:1', name: 'Turkey', n: {kcal: 100}),
          ],
        ),
        at('2026-11-13', 8, 0),
      );
      expect(e.food.name, 'Chili 2');
      expect(e.food.baseAmount, 2);
      expect(e.nutrients, {kcal: 100});
      expect(e.ingredients.length, 1);
      expect((await db.select(db.recipeIngredients).get()).length, 1);
      expect((await db.select(db.foodNutrients).get()).length, 1);
    });

    test('an ingredient with no nutrients is refused, so a rename cannot wipe them', () async {
      final bare = ml('usda:1', n: {});
      expect(
        db.createRecipe(
          RecipeInput(name: 'R', servings: 1, ingredients: [bare]),
          today,
        ),
        throwsArgumentError,
      );
      final r = await db.createRecipe(
        RecipeInput(
          name: 'R',
          servings: 1,
          ingredients: [
            ml('usda:1', n: {kcal: 400}),
          ],
        ),
        today,
      );
      await expectLater(
        db.editRecipe(
          r.food.id,
          RecipeInput(name: 'R2', servings: 1, ingredients: [bare]),
          today,
        ),
        throwsArgumentError,
      );
      final back = (await db.loadFood(r.food.id))!;
      expect(back.food.name, 'R');
      expect(back.nutrients, {kcal: 400});
    });

    test('servings must be more than zero, a recipe needs a name', () {
      expect(
        db.createRecipe(
          RecipeInput(name: 'R', servings: 0, ingredients: ingredients),
          today,
        ),
        throwsArgumentError,
      );
      expect(
        db.createRecipe(
          RecipeInput(name: '', servings: 1, ingredients: ingredients),
          today,
        ),
        throwsArgumentError,
      );
    });
  });

  group('for the parser', () {
    test('history counts are logged lines per food', () async {
      expect(await db.historyCounts(), isEmpty);
      await save([ml('usda:1'), ml('usda:2')]);
      await save([ml('usda:1')], date: '2026-11-10');
      expect(await db.historyCounts(), {'usda:1': 2, 'usda:2': 1});
    });

    test('forgetting a learned match deletes it at once', () async {
      await save([ml('usda:5', key: 'toast', picked: true)]);
      expect(await db.forgetLearnedMatch('toast'), isTrue);
      expect(await learned('toast'), isNull);
      expect(await db.forgetLearnedMatch('toast'), isFalse);
    });

    test('the snapshot holds what was stored', () async {
      final f = await db.createCustomFood(
        const CustomFoodInput(
          name: 'Cookie',
          basis: FoodBasis.per100g,
          servingSize: 20,
          portions: [PortionInput('1 cookie', 20)],
          nutrients: {kcal: 480, protein: 6},
        ),
        today,
      );
      final r = await db.createRecipe(
        RecipeInput(
          name: 'Chili',
          servings: 4,
          ingredients: [
            ml('usda:1', n: {kcal: 8}),
          ],
        ),
        today,
      );
      final gone = await db.createCustomFood(
        const CustomFoodInput(
          name: 'Old',
          basis: FoodBasis.per100g,
          nutrients: {kcal: 1},
        ),
        today,
      );
      await db.archiveFood(gone.food.id, today);
      final sm = (await db.createSavedMeal(
        name: 'Usual breakfast',
        items: [
          ml('usda:1', name: 'Egg', q: 2, n: {kcal: 176}),
          ml('usda:2', n: {kcal: 84, fat: 1}),
        ],
        now: today,
        aliases: ['ub'],
      )).saved!;
      await save([
        ml(
          'usda:5',
          name: 'Bread',
          key: 'toast',
          picked: true,
          setAmount: true,
          q: 2,
          unit: 'slice',
        ),
        ml('usda:1'),
      ]);
      await save([ml('usda:1')]);

      final s = await db.loadUserSnapshot(version: 7);
      expect(s.version, 7);
      expect(s.foods.map((x) => x.ref), [f.ref, r.ref]);
      final cookie = s.foods.first;
      expect(cookie.name, 'Cookie');
      expect(cookie.kind, 'custom');
      expect(cookie.baseUnit, 'g');
      expect(cookie.baseAmount, 100);
      expect(cookie.nutrients, {kcal: 480, protein: 6});
      expect(cookie.portions.map((p) => (p.label, p.baseQuantity)), [
        ('1 serving', 20.0),
        ('1 cookie', 20.0),
      ]);
      final chili = s.foods.last;
      expect(
        (chili.kind, chili.baseUnit, chili.baseAmount),
        ('recipe', 'serving', 4.0),
      );
      expect(chili.nutrients, {kcal: 8});
      expect(s.learned.single.key, 'toast');
      expect(s.learned.single.foodRef, 'usda:5');
      expect(s.learned.single.foodName, 'Bread');
      expect(s.learned.single.quantity, 2);
      expect(s.learned.single.unitLabel, 'slice');
      expect(s.learned.single.timesUsed, 1);
      expect(s.aliases.single.phrase, 'ub');
      expect(s.aliases.single.savedMealId, sm.meal.id);
      final meal = s.savedMeals.single;
      expect(meal.name, 'Usual breakfast');
      expect(meal.items.map((i) => i.foodName), ['Egg', 'Food usda:2']);
      expect(meal.items[0].quantity, 2);
      expect(meal.items[0].nutrients, {kcal: 176});
      expect(meal.items[1].nutrients, {kcal: 84, fat: 1});
      expect(s.historyCounts, {'usda:5': 1, 'usda:1': 2});
    });

    test('the snapshot stream ticks on each relevant change, with a rising version', () async {
      final versions = <int>[];
      final sub = db.watchUserSnapshot().listen((s) => versions.add(s.version));
      await pumpEventQueue();
      expect(versions, [1]);

      Future<void> expectTick(
        String what,
        Future<void> Function() change,
      ) async {
        final before = versions.length;
        await change();
        await pumpEventQueue();
        expect(versions.length, greaterThan(before), reason: what);
      }

      late FoodDetail food;
      await expectTick('custom food', () async {
        food = await db.createCustomFood(
          const CustomFoodInput(
            name: 'Z',
            basis: FoodBasis.per100g,
            nutrients: {kcal: 1},
          ),
          today,
        );
      });
      await expectTick('archive', () async {
        await db.archiveFood(food.food.id, today);
      });
      late SavedMealDetail sm;
      await expectTick('saved meal', () async {
        sm = (await db.createSavedMeal(
          name: 'S',
          items: [ml('usda:1')],
          now: today,
          aliases: ['s'],
        )).saved!;
      });
      await expectTick('alias', () async {
        await db.updateSavedMeal(sm.meal.id, aliases: ['t']);
      });
      await expectTick('learned match and history', () async {
        await save([ml('usda:5', key: 'toast', picked: true)]);
      });
      await expectTick('forget', () async {
        await db.forgetLearnedMatch('toast');
      });
      await expectTick('delete saved meal', () async {
        await db.deleteSavedMeal(sm.meal.id);
      });

      final before = versions.length;
      await db.saveWeight(180, UnitSystem.imperial, today);
      await pumpEventQueue();
      expect(versions.length, before, reason: 'a weigh-in is not parser data');

      for (var i = 1; i < versions.length; i++) {
        expect(versions[i], greaterThan(versions[i - 1]));
      }
      await sub.cancel();
    });
  });

  test('two saves of the same text make two meals', () async {
    final a = await save([ml('usda:1')], text: 'egg');
    final b = await save([ml('usda:1')], text: 'egg');
    expect(a.meal.id, isNot(b.meal.id));
    expect(await counts(), [2, 2, 2, 0]);
  });
}
