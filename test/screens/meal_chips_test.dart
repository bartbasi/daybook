// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';
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
import 'package:daybook/screens/food/correction_sheet.dart';
import 'package:daybook/screens/food/food_entry_screen.dart';
import 'package:daybook/screens/food/food_line_tile.dart';
import 'package:daybook/screens/food/meal_chips.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'food_entry_screen_test.dart' show Gate, nowFixed, settle;

// The chips row of the food screen (task 2.10), over the real food data with
// the parser worker running inline.

const egg = 'usda:2707153';
const coffee = 'usda:2710373';
const halfAndHalf = 'usda:2705594';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late sqlite.Database usda;
  late SqliteUsdaFoods loader;
  late Parser parser;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('daybook_chips');
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
  late Gate gate;

  setUp(() {
    gate = Gate();
    db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
  });

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

  Future<void> openApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => nowFixed,
        foodsPath: Future.value('unused'),
        workerFactory: (_) => ParseWorker.inlineWith(parser),
      ),
    );
    await settle(tester);
  }

  Finder plusFood() => find.widgetWithText(FilledButton, '+ Food');
  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  Finder box() => find.descendant(
    of: find.byType(FoodEntryScreen),
    matching: find.byType(TextField),
  );
  Finder tiles() => find.byType(FoodLineTile);
  Finder chipsRow() => find.byType(MealChips);
  Finder chip(String name) =>
      find.descendant(of: chipsRow(), matching: find.text(name));
  Finder chipBox(String name) =>
      find.ancestor(of: chip(name), matching: find.byType(InkWell)).first;
  Finder sheet() => find.byType(CorrectionSheet);
  Finder inSheet(Finder f) => find.descendant(of: sheet(), matching: f);

  var taps = 0;
  Future<void> tap(WidgetTester tester, Finder f) async {
    taps++;
    await tester.tap(f);
    await settle(tester);
  }

  /// A chip that is out of view is swiped into view first (that is a drag,
  /// not a tap), then tapped.
  Future<void> tapChip(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tap(tester, f);
  }

  Future<void> openFood(WidgetTester tester) async {
    await tap(tester, plusFood());
    expect(find.byType(FoodEntryScreen), findsOneWidget);
    // The chips arrive from the database after the first frame.
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(box(), text);
    await tester.pump();
  }

  String boxText(WidgetTester tester) =>
      tester.widget<TextField>(box()).controller!.text;

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<List<Meal>> mealRows(WidgetTester tester) =>
      real(tester, () => db.select(db.meals).get());

  Future<StoredMeal> mealOf(WidgetTester tester, int id) async {
    final StoredMeal? m = await real(tester, () => db.loadMeal(id));
    return m!;
  }

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
    double kcal,
  ) => MealLineInput(
    foodRef: ref,
    foodName: name,
    quantity: q,
    unitLabel: unit,
    baseQuantity: grams,
    baseUnit: 'g',
    nutrients: {Nutrients.energy: kcal, Nutrients.protein: 10},
  );

  Future<StoredMeal> logMeal(
    WidgetTester tester,
    String date,
    String slot,
    List<MealLineInput> lines, {
    int? savedMealId,
    int hour = 8,
  }) async {
    final id = await slotId(tester, slot);
    return real(
      tester,
      () => db.saveMeal(
        now: Now.fromLocal(date, hour * 60, -360),
        localDate: date,
        slotId: id,
        lines: lines,
        savedMealId: savedMealId,
      ),
    );
  }

  MealLineInput eggs2() => item(egg, 'Egg', 2, '', 100, 176);
  MealLineInput coffee1() =>
      item(coffee, 'Coffee, NS as to type', 1, 'small', 360, 4);
  MealLineInput cream2() =>
      item(halfAndHalf, 'Cream, half and half', 2, 'tbsp', 30, 39);

  Future<SavedMeal> makeSaved(
    WidgetTester tester,
    String name,
    List<MealLineInput> items, {
    List<String> aliases = const [],
  }) async => (await real(
    tester,
    () => db.createSavedMeal(
      name: name,
      items: items,
      now: nowFixed,
      aliases: aliases,
    ),
  )).saved!.meal;

  /// Yesterday's breakfast (219 kcal), and two saved meals, "My oatmeal" the
  /// one used more in Breakfast.
  Future<({SavedMeal usual, SavedMeal oats})> seed(WidgetTester tester) async {
    final usual = await makeSaved(
      tester,
      'Usual breakfast',
      [eggs2(), coffee1()],
      aliases: const ['usual breakfast'],
    );
    final oats = await makeSaved(tester, 'My oatmeal', [
      cream2(),
      item(egg, 'Egg', 1, '', 50, 88),
    ]);
    await logMeal(tester, '2026-11-11', 'Breakfast', [
      eggs2(),
      coffee1(),
      cream2(),
    ]);
    await logMeal(tester, '2026-11-09', 'Breakfast', [
      eggs2(),
    ], savedMealId: usual.id);
    await logMeal(tester, '2026-11-08', 'Breakfast', [
      cream2(),
    ], savedMealId: oats.id);
    await logMeal(tester, '2026-11-07', 'Breakfast', [
      cream2(),
    ], savedMealId: oats.id);
    return (usual: usual, oats: oats);
  }

  group('the row', () {
    appTest('has Same as yesterday first, then saved meals by use in this '
        'meal, then recent foods, under their labels', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      expect(find.text('Log a whole meal. Tap logs it now.'), findsOneWidget);
      expect(
        find.text('Recent and frequent. Tap adds a line.'),
        findsOneWidget,
      );
      final y = tester.getTopLeft(chip('Same as yesterday')).dx;
      final oats = tester.getTopLeft(chip('My oatmeal')).dx;
      final usual = tester.getTopLeft(chip('Usual breakfast')).dx;
      expect(y, lessThan(oats));
      expect(oats, lessThan(usual));
      // The foods are a row of their own, under the whole meals.
      expect(
        tester.getTopLeft(chip('Egg')).dy,
        greaterThan(tester.getTopLeft(chip('My oatmeal')).dy),
      );
      // Name, item count and kcal on each whole-meal chip.
      expect(find.text('Breakfast, 3 items, 219 kcal'), findsOneWidget);
      expect(find.text('2 items, 180 kcal'), findsOneWidget);
      expect(find.text('2 items, 127 kcal'), findsOneWidget);
      // It is under the box and above the lines.
      expect(
        tester.getTopLeft(chipsRow()).dy,
        greaterThan(tester.getBottomLeft(box()).dy),
      );
    });

    appTest('each chip is at least 48 dp tall and says what a tap will do', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      for (final n in [
        'Same as yesterday',
        'Usual breakfast',
        'My oatmeal',
        'Egg',
      ]) {
        expect(
          tester.getSize(chipBox(n)).height,
          greaterThanOrEqualTo(48),
          reason: n,
        );
      }
      final labels = [
        for (final n in ['Same as yesterday', 'Usual breakfast', 'Egg'])
          tester.getSemantics(chipBox(n)).label,
      ];
      expect(
        labels[0],
        'Same as yesterday, Breakfast. 3 items, 219 calories. '
        'Double tap to log it now.',
      );
      expect(
        labels[1],
        'Usual breakfast. 2 items, 180 calories. Double tap to log it now.',
      );
      expect(labels[2], 'Egg, 2. 176 calories. Double tap to add a line.');
      // With text the spoken words change with the label.
      await type(tester, '1 apple');
      await tester.pump();
      expect(
        tester.getSemantics(chipBox('Usual breakfast')).label,
        'Usual breakfast. 2 items, 180 calories. Double tap to add its items.',
      );
      semantics.dispose();
    });

    appTest('has no Same as yesterday when yesterday has no meal in this '
        'slot', (tester) async {
      await seed(tester);
      await logMeal(tester, '2026-11-11', 'Lunch', [coffee1()]);
      await openApp(tester);
      await openFood(tester);
      expect(chip('Same as yesterday'), findsOneWidget);
      await tap(tester, find.widgetWithText(ChoiceChip, 'Dinner'));
      expect(chip('Same as yesterday'), findsNothing);
      await tap(tester, find.widgetWithText(ChoiceChip, 'Lunch'));
      expect(chip('Same as yesterday'), findsOneWidget);
      expect(find.text('Lunch, 1 item, 4 kcal'), findsOneWidget);
    });

    appTest('follows the meal: saved meals are ordered by use in that slot', (
      tester,
    ) async {
      final s = await seed(tester);
      await logMeal(tester, '2026-11-09', 'Lunch', [
        eggs2(),
      ], savedMealId: s.usual.id);
      await openApp(tester);
      await openFood(tester);
      expect(
        tester.getTopLeft(chip('My oatmeal')).dx,
        lessThan(tester.getTopLeft(chip('Usual breakfast')).dx),
      );
      await tap(tester, find.widgetWithText(ChoiceChip, 'Lunch'));
      expect(
        tester.getTopLeft(chip('Usual breakfast')).dx,
        lessThan(tester.getTopLeft(chip('My oatmeal')).dx),
      );
      // Recent foods are the lunch ones now: no coffee, no half and half.
      expect(chip('Coffee, NS as to type'), findsNothing);
      expect(chip('Egg'), findsOneWidget);
    });

    appTest('follows the date: yesterday is the day before the date shown', (
      tester,
    ) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      expect(find.text('Breakfast, 3 items, 219 kcal'), findsOneWidget);
      await tap(tester, find.byTooltip('Previous day'));
      // The day before Nov 11 is Nov 10: nothing there.
      expect(chip('Same as yesterday'), findsNothing);
      await tap(tester, find.byTooltip('Previous day'));
      // The day before Nov 10 is Nov 9: one egg line (the 2 eggs, 176 kcal).
      expect(find.text('Breakfast, 1 item, 176 kcal'), findsOneWidget);
    });

    appTest('is not shown while editing a logged meal', (tester) async {
      await seed(tester);
      await openApp(tester);
      await logMeal(tester, '2026-11-12', 'Breakfast', [coffee1()]);
      await tester.pump();
      await settle(tester);
      await tap(tester, find.text('Breakfast').last);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      await settle(tester);
      expect(chipsRow(), findsNothing);
      expect(find.text('Log a whole meal. Tap logs it now.'), findsNothing);
    });

    appTest('a row with nothing to show takes no room', (tester) async {
      await openApp(tester);
      await openFood(tester);
      expect(find.text('Log a whole meal. Tap logs it now.'), findsNothing);
      expect(find.text('Recent and frequent. Tap adds a line.'), findsNothing);
    });
  });

  group('a whole-meal chip with an empty screen', () {
    appTest('a saved meal logs in 2 taps: + Food and the chip; Home says so '
        'and Undo removes exactly that meal', (tester) async {
      final s = await seed(tester);
      // The test font is wider than a real one, so this is the narrowest
      // width where the second chip is in view with no swipe.
      await openApp(tester, size: const Size(673, 800));
      taps = 0;
      await openFood(tester);
      // The most used saved meal is in view with no swipe, so the target is
      // 2 taps.
      expect(tester.getRect(chip('My oatmeal')).right, lessThan(673));
      await tap(tester, chip('My oatmeal'));
      expect(taps, 2, reason: '+ Food, then the chip');
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(
        find.text('Breakfast logged: My oatmeal, 127 kcal'),
        findsOneWidget,
      );

      final rows = await mealRows(tester);
      expect(rows, hasLength(5));
      final logged = rows.firstWhere((m) => m.localDate == '2026-11-12');
      final m = await mealOf(tester, logged.id);
      expect(m.slotName, 'Breakfast');
      expect(m.meal.savedMealId, s.oats.id);
      expect(m.meal.sourceText, isNull);
      expect([for (final e in m.entries) e.entry.foodRef], [halfAndHalf, egg]);
      expect(m.entries.first.entry.quantity, 2);
      expect(m.totals[Nutrients.energy], 127);
      // Nothing is learned from a chip.
      expect(
        await real(tester, () => db.select(db.learnedMatches).get()),
        isEmpty,
      );

      // Undo, twice fast: one Undo, and it removes exactly that meal.
      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await settle(tester);
      final left = await mealRows(tester);
      expect(left, hasLength(4));
      expect(left.any((x) => x.id == logged.id), isFalse);
      expect(find.text('Undo'), findsNothing);
    });

    appTest('the message and its Undo stay for 10 seconds, then the meal is '
        'an ordinary meal on Home', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await tapChip(tester, chip('Same as yesterday'));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Undo'), findsNothing);
      expect(
        find.text('Breakfast logged: same as yesterday, 219 kcal'),
        findsNothing,
      );
      // The meal is still there, and Home shows it.
      expect(
        (await mealRows(tester)).where((m) => m.localDate == '2026-11-12'),
        hasLength(1),
      );
      expect(find.text('219 kcal'), findsWidgets);
    });

    appTest('Same as yesterday logs a copy of yesterday in 2 taps; the '
        'copy is a new meal with no saved meal, and Undo removes it', (
      tester,
    ) async {
      await seed(tester);
      await openApp(tester);
      taps = 0;
      await openFood(tester);
      // First in the row, so always in view.
      expect(tester.getRect(chip('Same as yesterday')).left, lessThan(100));
      await tap(tester, chip('Same as yesterday'));
      expect(taps, 2);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(
        find.text('Breakfast logged: same as yesterday, 219 kcal'),
        findsOneWidget,
      );
      final rows = await mealRows(tester);
      final yesterday = rows.firstWhere((m) => m.localDate == '2026-11-11');
      final copy = rows.firstWhere((m) => m.localDate == '2026-11-12');
      expect(copy.id, isNot(yesterday.id));
      final a = await mealOf(tester, yesterday.id);
      final b = await mealOf(tester, copy.id);
      expect(b.meal.savedMealId, isNull);
      expect(b.meal.sourceText, isNull);
      expect(b.entries, hasLength(3));
      for (var i = 0; i < 3; i++) {
        final x = a.entries[i], y = b.entries[i];
        expect(y.entry.id, isNot(x.entry.id));
        expect(y.entry.foodRef, x.entry.foodRef);
        expect(y.entry.foodName, x.entry.foodName);
        expect(y.entry.quantity, x.entry.quantity);
        expect(y.entry.unitLabel, x.entry.unitLabel);
        expect(y.entry.baseQuantity, x.entry.baseQuantity);
        expect(y.nutrients, x.nutrients);
      }
      // Yesterday's own meal is as it was.
      expect((await mealOf(tester, yesterday.id)).entries, hasLength(3));
      expect(
        await real(tester, () => db.select(db.learnedMatches).get()),
        isEmpty,
      );

      await tester.tap(find.text('Undo'));
      await settle(tester);
      final left = await mealRows(tester);
      expect(left.any((m) => m.id == copy.id), isFalse);
      expect(left.any((m) => m.id == yesterday.id), isTrue);
    });

    appTest('logs into the date and meal shown on the screen', (tester) async {
      await seed(tester);
      await logMeal(tester, '2026-11-10', 'Lunch', [coffee1()]);
      await openApp(tester);
      await openFood(tester);
      await tap(tester, find.byTooltip('Previous day'));
      await tap(tester, find.widgetWithText(ChoiceChip, 'Lunch'));
      // Yesterday for Nov 11 Lunch is Nov 10 Lunch.
      await tapChip(tester, chip('Same as yesterday'));
      final rows = await mealRows(tester);
      final logged = rows.where((m) => m.localDate == '2026-11-11').toList();
      final lunch = await slotId(tester, 'Lunch');
      expect(logged.where((m) => m.slotId == lunch), hasLength(1));
      expect(
        find.text('Lunch logged for yesterday: same as yesterday, 4 kcal'),
        findsOneWidget,
      );
    });

    appTest('a chip tapped twice fast logs one meal', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      final target = chip('Usual breakfast');
      await tester.ensureVisible(target);
      await tester.pump();
      await tester.tap(target);
      await tester.tap(target, warnIfMissed: false);
      await settle(tester);
      final rows = await mealRows(tester);
      expect(rows.where((m) => m.localDate == '2026-11-12'), hasLength(1));
    });

    appTest('Same as yesterday tapped twice fast logs one meal', (
      tester,
    ) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      final target = chip('Same as yesterday');
      await tester.tap(target);
      await tester.tap(target, warnIfMissed: false);
      await settle(tester);
      final rows = await mealRows(tester);
      expect(rows.where((m) => m.localDate == '2026-11-12'), hasLength(1));
    });

    appTest('another chip tapped while the first is being written does '
        'nothing', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      gate.hold = Completer<void>();
      await tester.ensureVisible(chip('Usual breakfast'));
      await tester.pump();
      await tester.tap(chip('Usual breakfast'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      await tester.tap(chip('My oatmeal'), warnIfMissed: false);
      await tester.tap(chip('Same as yesterday'), warnIfMissed: false);
      await tester.pump();
      gate.hold!.complete();
      gate.hold = null;
      await settle(tester);
      final rows = await mealRows(tester);
      final logged = rows.where((m) => m.localDate == '2026-11-12').toList();
      expect(logged, hasLength(1));
      expect(
        (await mealOf(tester, logged.single.id)).totals[Nutrients.energy],
        180,
      );
      expect(find.byType(FoodEntryScreen), findsNothing);
    });

    appTest('a chip tapped while Save is running does nothing', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      gate.hold = Completer<void>();
      await tester.tap(saveButton());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      await tester.tap(chip('Usual breakfast'), warnIfMissed: false);
      await tester.tap(chip('Egg'), warnIfMissed: false);
      await tester.pump();
      gate.hold!.complete();
      gate.hold = null;
      await settle(tester);
      final rows = await mealRows(tester);
      final saved = rows.where((m) => m.localDate == '2026-11-12').toList();
      expect(saved, hasLength(1));
      final m = await mealOf(tester, saved.single.id);
      expect(m.entries, hasLength(1));
      expect(m.entries.single.entry.foodName, startsWith('Apple'));
      expect(m.meal.savedMealId, isNull);
    });

    appTest('a failed write keeps the screen open and says so; the chip can '
        'be tapped again', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      gate.failInsert = true;
      await tapChip(tester, chip('Usual breakfast'));
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(
        find.text('Could not save. Your meal is still here. Try again.'),
        findsOneWidget,
      );
      gate.failInsert = false;
      await tapChip(tester, chip('Usual breakfast'));
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(
        (await mealRows(tester)).where((m) => m.localDate == '2026-11-12'),
        hasLength(1),
      );
    });

    appTest('a saved meal deleted while the screen is open loses its chip', (
      tester,
    ) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await real(tester, () => db.deleteSavedMeal(s.usual.id));
      await settle(tester);
      expect(chip('Usual breakfast'), findsNothing);
    });
  });

  group('a whole-meal chip when there is text or a line', () {
    appTest('the label reads Tap adds its items and a saved meal chip adds '
        'its header and items; nothing is logged', (tester) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      expect(find.text('Tap adds its items'), findsOneWidget);
      expect(find.text('Log a whole meal. Tap logs it now.'), findsNothing);
      await tapChip(tester, chip('Usual breakfast'));
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(boxText(tester), '1 apple');
      expect(find.text('Added'), findsOneWidget);
      // The header and its two items, and the typed apple.
      expect(tiles(), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(FoodLineTile),
          matching: find.text('Usual breakfast'),
        ),
        findsOneWidget,
      );
      expect(await mealRows(tester), hasLength(4)); // the seeded ones only
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.meal.savedMealId, s.usual.id);
      // Added lines first, then the typed line.
      expect(m.entries.map((e) => e.entry.foodRef).take(2), [egg, coffee]);
      expect(m.entries, hasLength(3));
      expect(find.textContaining('Breakfast saved'), findsOneWidget);
    });

    appTest('the label and the tap also switch once a line is added', (
      tester,
    ) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      expect(find.text('Log a whole meal. Tap logs it now.'), findsOneWidget);
      await tapChip(tester, chip('Egg'));
      expect(tiles(), findsNWidgets(1));
      expect(find.text('Tap adds its items'), findsOneWidget);
      await tapChip(tester, chip('Same as yesterday'));
      // Not logged: its three entries are added lines.
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(tiles(), findsNWidgets(4));
      expect(await mealRows(tester), hasLength(4));
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.entries, hasLength(4));
      expect(m.meal.savedMealId, isNull);
    });

    appTest('Same as yesterday with text adds its entries as added lines', (
      tester,
    ) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('Same as yesterday'));
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      expect(tiles(), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(FoodLineTile),
          matching: find.text('Coffee, NS as to type'),
        ),
        findsOneWidget,
      );
      expect(boxText(tester), '1 apple');
    });
  });

  group('a food chip', () {
    appTest('adds one line at the amount last logged, never logs, and the '
        'screen stays open', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await tapChip(tester, chip('Egg'));
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(tiles(), findsNWidgets(1));
      expect(find.text('2, 100 g'), findsOneWidget);
      expect(await mealRows(tester), hasLength(4));
      expect(boxText(tester), '');
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.entries, hasLength(1));
      expect(m.entries.single.entry.quantity, 2);
      expect(m.entries.single.entry.baseQuantity, 100);
      expect(m.meal.savedMealId, isNull);
      expect(
        await real(tester, () => db.select(db.learnedMatches).get()),
        isEmpty,
      );
    });

    appTest('adds a line with text in the box too', (tester) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('Coffee, NS as to type'));
      expect(find.text('Added'), findsOneWidget);
      expect(tiles(), findsNWidgets(2));
      expect(boxText(tester), '1 apple');
    });

    appTest('an amount in a unit the food cannot take falls back to the '
        'same weight', (tester) async {
      await logMeal(tester, '2026-11-11', 'Breakfast', [
        item(egg, 'Egg', 3, 'wobble', 150, 264),
      ]);
      await openApp(tester);
      await openFood(tester);
      await tapChip(tester, chip('Egg'));
      expect(find.text('150 g'), findsOneWidget);
      // Nothing was reset, so no note.
      expect(
        find.text(
          'That food could not keep the amount, so it is set to its usual '
          'amount.',
        ),
        findsNothing,
      );
    });

    appTest('an amount nothing can keep falls back to the usual amount and '
        'says so', (tester) async {
      final breakfast = await slotId(tester, 'Breakfast');
      await real(
        tester,
        () => db.saveMeal(
          now: nowFixed,
          localDate: '2026-11-11',
          slotId: breakfast,
          lines: [
            MealLineInput(
              foodRef: egg,
              foodName: 'Egg',
              quantity: 3,
              unitLabel: 'wobble',
              baseQuantity: 3,
              baseUnit: 'ml',
              nutrients: const {Nutrients.energy: 10},
            ),
          ],
        ),
      );
      await openApp(tester);
      await openFood(tester);
      await tapChip(tester, chip('Egg'));
      expect(tiles(), findsNWidgets(1));
      expect(
        find.text(
          'That food could not keep the amount, so it is set to its usual '
          'amount.',
        ),
        findsOneWidget,
      );
    });

    appTest('a food that cannot be priced adds nothing and says so', (
      tester,
    ) async {
      await logMeal(tester, '2026-11-11', 'Breakfast', [
        item('usda:1', 'Ghost food', 1, '', 10, 10),
      ]);
      await openApp(tester);
      await openFood(tester);
      await tapChip(tester, chip('Ghost food'));
      expect(tiles(), findsNothing);
      expect(
        find.text('That food could not be used here, so nothing was changed.'),
        findsOneWidget,
      );
    });
  });

  group('saved_meal_id', () {
    appTest('a typed saved meal turned into its items, then a chip: the '
        'converted meal stays first', (tester) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'usual breakfast');
      // Change an item: the typed saved meal becomes its items.
      await tap(
        tester,
        find.widgetWithText(FoodLineTile, 'Coffee, NS as to type'),
      );
      await tester.enterText(
        inSheet(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Amount',
          ),
        ),
        '2',
      );
      await tap(tester, inSheet(find.text('Done')));
      expect(boxText(tester), '');
      await tapChip(tester, chip('My oatmeal'));
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.meal.savedMealId, s.usual.id);
      expect(m.entries.map((e) => e.entry.foodRef), [
        egg,
        coffee,
        halfAndHalf,
        egg,
      ]);
    });

    appTest('a chip, then a typed saved meal: the chip is first', (
      tester,
    ) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'usual breakfast');
      await tapChip(tester, chip('My oatmeal'));
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.meal.savedMealId, s.oats.id);
      expect(m.entries, hasLength(4));
    });

    appTest('a chip, then a typed saved meal changed into its items: the '
        'chip stays first, and a changed item keeps the id', (tester) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('My oatmeal'));
      // Change an item of the added header: its items become added lines
      // that still come from "My oatmeal".
      await tap(
        tester,
        find.widgetWithText(FoodLineTile, 'Cream, half and half'),
      );
      await tester.enterText(
        inSheet(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Amount',
          ),
        ),
        '4',
      );
      await tap(tester, inSheet(find.text('Done')));
      // Removing the whole saved meal's items would drop the id; one is left.
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.meal.savedMealId, s.oats.id);
      expect(m.entries.first.entry.quantity, 4);
    });

    appTest('closed with a chip header and opened again with Undo, the saved '
        'meal is still the one stored', (tester) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('My oatmeal'));
      await tap(tester, find.byTooltip('Close'));
      expect(find.byType(FoodEntryScreen), findsNothing);
      await tap(tester, find.text('Undo'));
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(tiles(), findsNWidgets(4));
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.meal.savedMealId, s.oats.id);
    });

    appTest('two chips: the first tapped is the one stored', (tester) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('Usual breakfast'));
      await tapChip(tester, chip('My oatmeal'));
      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.meal.savedMealId, s.usual.id);
    });
  });

  group('the multiplier of an added saved meal', () {
    Finder multiplier() => inSheet(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Multiplier',
      ),
    );

    appTest('scales its item lines, keeps its saved meal, and is stored '
        'times the multiplier', (tester) async {
      final s = await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('Usual breakfast'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(FoodLineTile),
          matching: find.text('Usual breakfast'),
        ),
      );
      expect(multiplier(), findsOneWidget);
      expect(inSheet(find.text('Use a food instead')), findsOneWidget);
      expect(inSheet(find.text('Done')), findsOneWidget);
      await tester.enterText(multiplier(), '2');
      await tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsNothing);
      expect(find.text('Usual breakfast  × 2'), findsOneWidget);
      expect(find.text('4, 200 g'), findsOneWidget);
      expect(find.text('360 kcal'), findsWidgets);
      // Not typed: the box is untouched.
      expect(boxText(tester), '1 apple');
      // And again, to a half: from the header as it is now.
      await tap(
        tester,
        find.descendant(
          of: find.byType(FoodLineTile),
          matching: find.text('Usual breakfast  × 2'),
        ),
      );
      await tester.enterText(multiplier(), '0.5');
      await tap(tester, inSheet(find.text('Done')));
      expect(find.text('Usual breakfast  × ½'), findsOneWidget);
      expect(find.text('1, 50 g'), findsOneWidget);

      await tester.tap(saveButton());
      await settle(tester);
      final rows = await mealRows(tester);
      final m = await mealOf(
        tester,
        rows.firstWhere((x) => x.localDate == '2026-11-12').id,
      );
      expect(m.meal.savedMealId, s.usual.id);
      expect(m.entries.first.entry.quantity, 1);
      expect(m.entries.first.entry.baseQuantity, 50);
      expect(m.entries.first.nutrients[Nutrients.energy], 88);
      expect(m.entries[1].entry.baseQuantity, 180);
    });

    appTest('a number that is not above 0 is refused and the sheet stays', (
      tester,
    ) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('Usual breakfast'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(FoodLineTile),
          matching: find.text('Usual breakfast'),
        ),
      );
      await tester.enterText(multiplier(), '0');
      await tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsOneWidget);
      expect(find.text('Enter a number above 0.'), findsOneWidget);
    });

    appTest('Done with the multiplier left alone changes nothing', (
      tester,
    ) async {
      await seed(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 apple');
      await tapChip(tester, chip('Usual breakfast'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(FoodLineTile),
          matching: find.text('Usual breakfast'),
        ),
      );
      await tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FoodLineTile),
          matching: find.text('Usual breakfast'),
        ),
        findsOneWidget,
      );
      expect(find.text('2, 100 g'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      appTest('at ${width.toInt()} dp and text scale $scale: no overflow, '
          '48 dp targets, and the row scrolls sideways when it must', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await seed(tester);
        await openApp(tester, size: Size(width, 800));
        await openFood(tester);
        expect(tester.takeException(), isNull);
        for (final n in [
          'Same as yesterday',
          'Usual breakfast',
          'My oatmeal',
          'Egg',
        ]) {
          final h = tester.getSize(chipBox(n)).height;
          expect(h, greaterThanOrEqualTo(48), reason: n);
        }
        // The first row of chips is a horizontal scroller: at 344 dp it has
        // somewhere to go, and a long drag brings the last chip into view.
        await tester.ensureVisible(chipBox('Same as yesterday'));
        await tester.pump();
        final scrollers = find.descendant(
          of: chipsRow(),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.horizontal,
          ),
        );
        expect(scrollers, findsNWidgets(2));
        final wholeRow = tester.state<ScrollableState>(scrollers.first);
        final viewWidth = tester.view.physicalSize.width;
        // Three whole-meal chips are wider than the column at every width.
        expect(wholeRow.position.maxScrollExtent, greaterThan(0));
        final before = tester.getTopLeft(chip('My oatmeal')).dx;
        await tester.drag(scrollers.first, const Offset(-2000, 0));
        await tester.pump();
        expect(tester.getTopLeft(chip('My oatmeal')).dx, lessThan(before));
        final right = tester.getTopRight(chipBox('Usual breakfast')).dx;
        expect(right, lessThanOrEqualTo(viewWidth + 0.5));
        await tester.drag(scrollers.first, const Offset(2000, 0));
        await tester.pump();
        expect(tester.takeException(), isNull);
        // A chip is still reachable and logs.
        await tapChip(tester, chip('Same as yesterday'));
        expect(find.byType(FoodEntryScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
