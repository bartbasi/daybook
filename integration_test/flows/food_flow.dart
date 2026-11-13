// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The food logging flows of speed targets 1 and 2, written once and used
// twice: by test/speed/food_speed_test.dart (the whole app, an in-memory
// database) and by integration_test/food_test.dart (a real build, the real
// database). Like weight_flow.dart, it finds widgets by type and by their
// words, reads the database through the app's own AppScope, and copes with
// rows that are already there: it only looks at the meals its own save added.
//
// Every tap goes through the TapCounter. Typing is not a tap.

import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/screens/food/food_entry_screen.dart';
import 'package:daybook/screens/food/food_line_tile.dart';
import 'package:daybook/screens/food/meal_chips.dart';
import 'package:daybook/screens/home/home_screen.dart';
import 'package:daybook/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/speed/tap_counter.dart';
import 'weight_flow.dart' show appDatabase, waitFor;

/// The brief's meal, typed exactly as speed-targets.md section 1 gives it. It
/// makes 5 lines and 490 kcal (parser-grammar.md section 11, example 1).
const sampleMeal =
    '2 eggs, 2 slices sourdough toast, 1 tbsp butter, '
    'coffee with 2 tbsp half and half';

/// Every stored meal, with its entries.
Future<List<StoredMeal>> storedMeals(WidgetTester tester) async {
  final db = appDatabase(tester);
  return (await tester.runAsync(() async {
    final rows = await db.select(db.meals).get();
    return [for (final m in rows) (await db.loadMeal(m.id))!];
  }))!;
}

/// The id of every stored meal.
Future<Set<int>> storedMealIds(WidgetTester tester) async => {
  for (final m in await storedMeals(tester)) m.meal.id,
};

Finder _plusFood() => find.widgetWithText(FilledButton, S.addFood);
Finder _save() => find.widgetWithText(FilledButton, S.save);
Finder _box() => find.descendant(
  of: find.byType(FoodEntryScreen),
  matching: find.byType(TextField),
);

/// A chip of the chips row of the food screen, found by its name.
Finder foodChip(String name) =>
    find.descendant(of: find.byType(MealChips), matching: find.text(name));

/// Waits until any earlier "saved" or "logged" message (it stays ten seconds,
/// with its Undo) has gone, so a check for a new one cannot pass on the old.
Future<void> waitForNoUndo(WidgetTester tester) => waitFor(
  tester,
  () => find.text(S.undo).evaluate().isEmpty,
  'the earlier message and its Undo to go away',
  tries: 200,
);

/// From Home, one counted tap on + Food, then waits for the entry screen.
Future<void> openFoodFromHome(WidgetTester tester, TapCounter taps) async {
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(find.byType(FoodEntryScreen), findsNothing);
  await taps.tap(_plusFood());
  await waitFor(
    tester,
    () => find.byType(FoodEntryScreen).evaluate().isNotEmpty,
    'the food screen to open',
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Waits until the food screen has closed and exactly one meal was added
/// since [before], and returns it read back from the database.
Future<StoredMeal> _theNewMeal(WidgetTester tester, Set<int> before) async {
  await waitFor(
    tester,
    () => find.byType(FoodEntryScreen).evaluate().isEmpty,
    'the food screen to close after the save',
  );
  final added = [
    for (final m in await storedMeals(tester))
      if (!before.contains(m.meal.id)) m,
  ];
  expect(added, hasLength(1), reason: 'one save adds exactly one meal');
  return added.single;
}

/// The whole of speed target 1, from Home: tap + Food (1 counted tap), type
/// [text] into the box that already has the cursor, wait until it shows
/// [lines] lines and [kcal] kcal, tap Save (1 counted tap). Returns the meal
/// that was stored, after checking that Home confirms it and lists it.
Future<StoredMeal> logTypedMeal(
  WidgetTester tester,
  TapCounter taps,
  String text, {
  required int lines,
  required int kcal,
}) async {
  await waitForNoUndo(tester);
  final before = await storedMealIds(tester);
  await openFoodFromHome(tester, taps);

  await taps.type(_box(), text);
  await tester.pump();
  await waitFor(
    tester,
    () =>
        find.byType(FoodLineTile).evaluate().length == lines &&
        find
            .textContaining('$kcal kcal', findRichText: true)
            .evaluate()
            .isNotEmpty &&
        tester.widget<FilledButton>(_save()).onPressed != null,
    'the food screen to show $lines lines and $kcal kcal',
  );
  await taps.tap(_save());
  final meal = await _theNewMeal(tester, before);
  await _homeShows(
    tester,
    S.mealSaved(meal.slotName, meal.totals[Nutrients.energy]),
    meal,
  );
  return meal;
}

/// The whole of speed target 2 with a chip: tap + Food (1 counted tap), wait
/// for the chip named [chipName], tap it (1 counted tap). Returns the meal
/// that was stored, after checking that Home says it was logged as [what].
/// The chip must be in view without scrolling.
Future<StoredMeal> logWithChip(
  WidgetTester tester,
  TapCounter taps,
  String chipName, {
  required String what,
}) async {
  await waitForNoUndo(tester);
  final before = await storedMealIds(tester);
  await openFoodFromHome(tester, taps);
  await waitFor(
    tester,
    () => foodChip(chipName).evaluate().isNotEmpty,
    'the chip "$chipName"',
  );
  final box = tester.getRect(foodChip(chipName));
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(
    box.left >= 0 && box.right <= view.width,
    isTrue,
    reason:
        'the chip is in view without a swipe: ${box.left} to ${box.right} of ${view.width}',
  );
  await taps.tap(foodChip(chipName));
  final meal = await _theNewMeal(tester, before);
  await _homeShows(
    tester,
    S.mealLogged(meal.slotName, what, meal.totals[Nutrients.energy]),
    meal,
  );
  return meal;
}

/// Waits for Home to say [message], and checks that its list of meals shows
/// the meal's kcal.
Future<void> _homeShows(
  WidgetTester tester,
  String message,
  StoredMeal meal,
) async {
  await waitFor(
    tester,
    () => find.text(message).evaluate().isNotEmpty,
    'Home to say "$message"',
  );
  expect(find.byType(HomeScreen), findsOneWidget);
  expect(
    find.text(S.kcal(meal.totals[Nutrients.energy])),
    findsWidgets,
    reason: 'Home lists the meal with its kcal',
  );
}

/// Taps Undo on Home (one counted tap) and waits until the meal [logged] is
/// gone from the database.
Future<void> undoOnHome(
  WidgetTester tester,
  TapCounter taps,
  StoredMeal logged,
) async {
  await taps.tap(find.text(S.undo));
  await tester.pump();
  final id = logged.meal.id;
  for (var i = 0; i < 200; i++) {
    if (!(await storedMealIds(tester)).contains(id)) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Undo did not remove the meal');
}

/// Taps the meal on Home that is named [slotName] (one counted tap) and waits
/// for the food screen to open on it.
Future<void> openLoggedMeal(
  WidgetTester tester,
  TapCounter taps,
  String slotName,
) async {
  await taps.tap(find.text(slotName).last);
  await waitFor(
    tester,
    () => find.byType(FoodEntryScreen).evaluate().isNotEmpty,
    'the food screen to open on the meal',
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// On the food screen: taps Save (one counted tap) and waits for the screen to
/// close.
Future<void> saveAndClose(WidgetTester tester, TapCounter taps) async {
  await taps.tap(_save());
  await waitFor(
    tester,
    () => find.byType(FoodEntryScreen).evaluate().isEmpty,
    'the food screen to close after the save',
  );
}

/// The meals table, the entries and their nutrients, and the tables a save
/// could touch by learning (learned matches, saved meals), every column of
/// every row, as text, in id order. Two snapshots are equal only when every
/// stored value is.
Future<Map<String, List<String>>> foodSnapshot(WidgetTester tester) async {
  final db = appDatabase(tester);
  return (await tester.runAsync(() async {
    Future<List<String>> rows<T extends Object>(
      Future<List<T>> read,
      int Function(T a, T b) order,
    ) async => [for (final r in (await read)..sort(order)) r.toString()];
    return {
      'meals': await rows(
        db.select(db.meals).get(),
        (a, b) => a.id.compareTo(b.id),
      ),
      'entries': await rows(
        db.select(db.mealEntries).get(),
        (a, b) => a.id.compareTo(b.id),
      ),
      'nutrients': await rows(
        db.select(db.mealEntryNutrients).get(),
        (a, b) => a.entryId != b.entryId
            ? a.entryId.compareTo(b.entryId)
            : a.nutrientId.compareTo(b.nutrientId),
      ),
      'learned': await rows(
        db.select(db.learnedMatches).get(),
        (a, b) => a.phrase.compareTo(b.phrase),
      ),
      'savedMeals': await rows(
        db.select(db.savedMeals).get(),
        (a, b) => a.id.compareTo(b.id),
      ),
    };
  }))!;
}
