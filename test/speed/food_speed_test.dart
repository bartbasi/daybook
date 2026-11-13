// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Speed targets 1 and 2 (docs/design/speed-targets.md, sections 1 and 2): log
// a typed 4-item meal, and log a saved meal or "same as yesterday". The whole
// app runs here, with an in-memory database, a fixed clock and the real USDA
// food data. The same flows run on a real build in integration_test/food_test.dart.
//
// What counts as a tap, from speed-targets.md: "Every touch on the screen
// counts: buttons, chips, fields, keyboard action keys (Next, Done, Save), and
// anything that opens or closes a keyboard, sheet or message." And: "Typing
// the content itself (letters, digits, commas) is the 'type' part of a target
// and is listed separately as keys." So here a counted tap is any tap and any
// keyboard action made through TapCounter, and typing into the box is free,
// but only because the box already has the cursor when the screen opens. Undo
// is checked with a counter of its own: it is not part of the 2 taps.

import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../integration_test/flows/food_flow.dart';
import '../../integration_test/flows/weight_flow.dart' show waitFor;
import 'tap_counter.dart';

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6: Breakfast.
final nowFixed = Now.fromLocal('2026-11-12', 7 * 60 + 2, -360);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late sqlite.Database usda;
  late SqliteUsdaFoods loader;
  late Parser parser;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('daybook_food_speed');
    final path = '${tmp.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    usda = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    loader = SqliteUsdaFoods(usda);
    parser = Parser(SearchIndex.build(readUsdaFoods(usda)), loader.call);
  });

  tearDownAll(() {
    loader.dispose();
    usda.close();
    tmp.deleteSync(recursive: true);
  });

  late AppDatabase db;
  late Now clockNow;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clockNow = nowFixed;
  });

  /// Unmounts the app first, so drift's stream clean-up timer runs, then
  /// closes the database.
  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const channels = ['home_widget', 'home_widget/updates'];
      for (final c in channels) {
        messenger.setMockMethodCallHandler(MethodChannel(c), (_) async => null);
      }
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(db.close);
        for (final c in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(c), null);
        }
      }
    });
  }

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => clockNow,
        foodsPath: Future.value('unused'),
        workerFactory: (_) => ParseWorker.inlineWith(parser),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<int> slotId(WidgetTester tester, String name) async {
    final rows = await real(tester, () => db.select(db.mealSlots).get());
    return rows.firstWhere((s) => s.name == name).id;
  }

  MealLineInput item(
    String ref,
    String name,
    double q,
    String unit,
    double grams,
    Map<int, double> n,
  ) => MealLineInput(
    foodRef: ref,
    foodName: name,
    quantity: q,
    unitLabel: unit,
    baseQuantity: grams,
    baseUnit: 'g',
    nutrients: n,
  );

  // The foods of the sample meal, from docs/parser-grammar.md section 11,
  // example 1 (kcal, protein, carbs, fat per line, to one decimal).
  MealLineInput eggs() => item(
    'usda:2707153',
    'Egg, whole, cooked, NS as to '
        'cooking method',
    2,
    '',
    100,
    {
      Nutrients.energy: 176,
      Nutrients.protein: 11.8,
      Nutrients.carbs: 0.9,
      Nutrients.fat: 13.9,
    },
  );
  MealLineInput coffeeSmall() => item(
    'usda:2710373',
    'Coffee, NS as to type',
    1,
    'small',
    360,
    {Nutrients.energy: 4, Nutrients.protein: 0.4, Nutrients.fat: 0.1},
  );
  MealLineInput cream() => item(
    'usda:2705594',
    'Cream, half and half',
    2,
    'tbsp',
    30,
    {Nutrients.energy: 39, Nutrients.protein: 0.9, Nutrients.carbs: 1.3},
  );

  Future<StoredMeal> logYesterday(WidgetTester tester) async {
    final id = await slotId(tester, 'Breakfast');
    return real(
      tester,
      () => db.saveMeal(
        now: Now.fromLocal('2026-11-11', 8 * 60, -360),
        localDate: '2026-11-11',
        slotId: id,
        sourceText: '2 eggs, coffee, 2 tbsp half and half',
        lines: [eggs(), coffeeSmall(), cream()],
      ),
    );
  }

  /// Every stored value of an entry, the id left out.
  void expectSameEntry(StoredEntry got, MealLineInput want, int position) {
    expect(got.entry.position, position);
    expect(got.entry.foodRef, want.foodRef);
    expect(got.entry.foodName, want.foodName);
    expect(got.entry.quantity, want.quantity);
    expect(got.entry.unitLabel, want.unitLabel);
    expect(got.entry.baseQuantity, want.baseQuantity);
    expect(got.entry.baseUnit, want.baseUnit);
    expect(got.nutrients.keys.toSet(), want.nutrients.keys.toSet());
    for (final e in want.nutrients.entries) {
      expect(got.nutrients[e.key], closeTo(e.value, 0.051), reason: '${e.key}');
    }
  }

  appTest('target 1: the brief meal takes 2 counted taps, and stores 5 '
      'entries and 490 kcal in today\'s Breakfast', (tester) async {
    await openApp(tester);
    final taps = TapCounter(tester);
    final meal = await logTypedMeal(
      tester,
      taps,
      sampleMeal,
      lines: 5,
      kcal: 490,
    );
    taps.expectCount(2, flow: '+ Food, type the meal, Save');

    // The meal row.
    expect(meal.slotName, 'Breakfast');
    expect(meal.meal.slotId, await slotId(tester, 'Breakfast'));
    expect(meal.meal.localDate, '2026-11-12');
    expect(meal.meal.loggedAtMs, nowFixed.utcMs);
    expect(meal.meal.tzOffsetMinutes, -360);
    expect(meal.meal.sourceText, sampleMeal);
    expect(meal.meal.savedMealId, isNull);
    // Exactly one meal in the database, and it is the one Home shows.
    expect(await storedMeals(tester), hasLength(1));

    // The five entries, in the order typed, with the foods and amounts of
    // parser-grammar.md section 11, example 1.
    expect(meal.entries, hasLength(5));
    final want = <(String, String, double, double, double, double, double)>[
      // ref, unit label, quantity, grams, kcal, protein, carbs / fat below
      ('usda:2707153', '', 2, 100, 176, 11.8, 0.9),
      ('usda:2707647', 'slice', 2, 56, 167, 6.6, 31.9),
      ('usda:2710154', 'tbsp', 1, 14, 104, 0.1, 0.0),
      ('usda:2710373', 'small', 1, 360, 4, 0.4, 0.0),
      ('usda:2705594', 'tbsp', 2, 30, 39, 0.9, 1.3),
    ];
    final fats = [13.9, 1.5, 11.5, 0.1, 3.5];
    final names = [
      'Egg, whole, cooked, NS as to cooking method',
      'Bread, sour dough, toasted',
      'Butter, NFS',
      'Coffee, NS as to type',
      'Cream, half and half',
    ];
    for (var i = 0; i < 5; i++) {
      final e = meal.entries[i];
      final w = want[i];
      expect(e.entry.position, i);
      expect(e.entry.foodRef, w.$1, reason: 'line ${i + 1}');
      expect(e.entry.foodName, names[i]);
      expect(e.entry.unitLabel, w.$2, reason: 'line ${i + 1}');
      expect(e.entry.quantity, w.$3, reason: 'line ${i + 1}');
      expect(e.entry.baseQuantity, closeTo(w.$4, 0.5), reason: 'line ${i + 1}');
      expect(e.entry.baseUnit, 'g');
      expect(e.nutrients[Nutrients.energy], closeTo(w.$5, 0.5));
      expect(e.nutrients[Nutrients.protein], closeTo(w.$6, 0.051));
      expect(e.nutrients[Nutrients.carbs], closeTo(w.$7, 0.051));
      expect(e.nutrients[Nutrients.fat], closeTo(fats[i], 0.051));
    }
    expect(meal.totals[Nutrients.energy]!.round(), 490);
    expect(find.text('Breakfast saved, 490 kcal'), findsOneWidget);
    expect(find.text('490 kcal'), findsWidgets);

    // Undo on Home removes exactly that meal.
    final undo = TapCounter(tester);
    await undoOnHome(tester, undo, meal);
    expect(await storedMeals(tester), isEmpty);
    expect(await real(tester, () => db.select(db.mealEntries).get()), isEmpty);
    expect(
      await real(tester, () => db.select(db.mealEntryNutrients).get()),
      isEmpty,
    );
    expect(find.text('Undo'), findsNothing);
  });

  appTest('target 1: Undo removes the new meal and no other', (tester) async {
    final y = await logYesterday(tester);
    await openApp(tester);
    final before = await foodSnapshot(tester);
    final taps = TapCounter(tester);
    final meal = await logTypedMeal(
      tester,
      taps,
      sampleMeal,
      lines: 5,
      kcal: 490,
    );
    taps.expectCount(2, flow: '+ Food, type the meal, Save');
    await undoOnHome(tester, TapCounter(tester), meal);
    expect(await foodSnapshot(tester), before);
    expect((await storedMeals(tester)).single.meal.id, y.meal.id);
  });

  appTest('target 2: a saved meal chip takes 2 counted taps, stores that '
      'meal, and Undo removes exactly it', (tester) async {
    final saved = (await real(
      tester,
      () => db.createSavedMeal(
        name: 'Usual breakfast',
        items: [eggs(), coffeeSmall()],
        now: nowFixed,
      ),
    )).saved!.meal;
    // Another breakfast, three days ago, for Undo to leave alone. Nothing is
    // logged yesterday, so the saved meal chip is the first one in the row and
    // in full view, which is the condition the target gives.
    final breakfast = await slotId(tester, 'Breakfast');
    final other = await real(
      tester,
      () => db.saveMeal(
        now: Now.fromLocal('2026-11-09', 8 * 60, -360),
        localDate: '2026-11-09',
        slotId: breakfast,
        lines: [eggs()],
      ),
    );
    await openApp(tester);
    final before = await foodSnapshot(tester);

    final taps = TapCounter(tester);
    final meal = await logWithChip(
      tester,
      taps,
      'Usual breakfast',
      what: 'Usual breakfast',
    );
    taps.expectCount(2, flow: '+ Food, the saved meal chip');

    expect(meal.slotName, 'Breakfast');
    expect(meal.meal.localDate, '2026-11-12');
    expect(meal.meal.loggedAtMs, nowFixed.utcMs);
    expect(meal.meal.tzOffsetMinutes, -360);
    expect(meal.meal.savedMealId, saved.id);
    expect(meal.meal.sourceText, isNull);
    expect(meal.entries, hasLength(2));
    expectSameEntry(meal.entries[0], eggs(), 0);
    expectSameEntry(meal.entries[1], coffeeSmall(), 1);
    expect(meal.totals[Nutrients.energy]!.round(), 180);
    expect(
      find.text('Breakfast logged: Usual breakfast, 180 kcal'),
      findsOneWidget,
    );
    expect(await storedMeals(tester), hasLength(2));

    await undoOnHome(tester, TapCounter(tester), meal);
    expect(await foodSnapshot(tester), before);
    final left = await storedMeals(tester);
    expect(left.single.meal.id, other.meal.id);
  });

  appTest('target 2: Same as yesterday takes 2 counted taps, stores a copy '
      'of yesterday, and Undo removes exactly it and leaves yesterday', (
    tester,
  ) async {
    final yesterday = await logYesterday(tester);
    await openApp(tester);
    final before = await foodSnapshot(tester);

    final taps = TapCounter(tester);
    final meal = await logWithChip(
      tester,
      taps,
      'Same as yesterday',
      what: 'same as yesterday',
    );
    taps.expectCount(2, flow: '+ Food, Same as yesterday');

    // A new meal on today's date in the same meal slot, with yesterday's
    // lines and numbers, and nothing carried over that belongs to the
    // yesterday: no source text, no saved meal.
    expect(meal.meal.id, isNot(yesterday.meal.id));
    expect(meal.meal.localDate, '2026-11-12');
    expect(meal.meal.slotId, yesterday.meal.slotId);
    expect(meal.slotName, 'Breakfast');
    expect(meal.meal.loggedAtMs, nowFixed.utcMs);
    expect(meal.meal.sourceText, isNull);
    expect(meal.meal.savedMealId, isNull);
    expect(meal.entries, hasLength(3));
    for (var i = 0; i < 3; i++) {
      final a = yesterday.entries[i], b = meal.entries[i];
      expect(b.entry.id, isNot(a.entry.id));
      expect(b.entry.mealId, meal.meal.id);
      expect(b.entry.position, i);
      expect(b.entry.foodRef, a.entry.foodRef);
      expect(b.entry.foodName, a.entry.foodName);
      expect(b.entry.quantity, a.entry.quantity);
      expect(b.entry.unitLabel, a.entry.unitLabel);
      expect(b.entry.baseQuantity, a.entry.baseQuantity);
      expect(b.entry.baseUnit, a.entry.baseUnit);
      expect(b.nutrients, a.nutrients);
    }
    expect(meal.totals, yesterday.totals);
    expect(
      find.text('Breakfast logged: same as yesterday, 219 kcal'),
      findsOneWidget,
    );
    // Yesterday's own rows are exactly as they were.
    final during = await storedMeals(tester);
    expect(during, hasLength(2));
    final y2 = during.firstWhere((m) => m.meal.id == yesterday.meal.id);
    expect(y2.meal, yesterday.meal);
    expect(
      [for (final e in y2.entries) e.entry],
      [for (final e in yesterday.entries) e.entry],
    );

    await undoOnHome(tester, TapCounter(tester), meal);
    expect(await foodSnapshot(tester), before);
    expect((await storedMeals(tester)).single.meal.id, yesterday.meal.id);
  });

  appTest('editing a logged meal and saving with no change leaves every '
      'stored value identical', (tester) async {
    await openApp(tester);
    final logged = await logTypedMeal(
      tester,
      TapCounter(tester),
      sampleMeal,
      lines: 5,
      kcal: 490,
    );
    final before = await foodSnapshot(tester);
    // The columns the snapshot reads, so a new column cannot slip past it.
    expect(before['meals'], hasLength(1));
    expect(before['entries'], hasLength(5));
    expect(before['nutrients']!.length, greaterThanOrEqualTo(5 * 4));

    // Hours later, so a timestamp that follows the clock would show.
    clockNow = Now.fromLocal('2026-11-12', 15 * 60 + 15, -360);
    await waitFor(
      tester,
      () => find.text('Undo').evaluate().isEmpty,
      'the saved message to go away',
    );
    final taps = TapCounter(tester);
    await openLoggedMeal(tester, taps, logged.slotName);
    expect(find.text('Editing Breakfast'), findsOneWidget);
    await saveAndClose(tester, taps);

    // Every column of every row of the meal, its entries and their nutrients,
    // the learned matches and the saved meals, byte for byte. Nothing in a
    // save with no change is allowed to move, the updated times included: the
    // meal has no updated-at column, and editMeal says "The logged time
    // stays" and writes an entry only when its values differ.
    expect(await foodSnapshot(tester), before);
    final after = (await storedMeals(tester)).single;
    expect(after.meal, logged.meal);
    expect(
      [for (final e in after.entries) e.entry],
      [for (final e in logged.entries) e.entry],
    );
    expect(after.totals, logged.totals);
    expect(find.text('Breakfast saved, 490 kcal'), findsOneWidget);
  });
}
