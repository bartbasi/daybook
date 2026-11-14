// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';
import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/screens/food/correction_sheet.dart';
import 'package:daybook/screens/food/food_line_tile.dart';
import 'package:daybook/screens/more/more_screen.dart';
import 'package:daybook/screens/saved_meals/saved_meal_editor.dart';
import 'package:daybook/screens/saved_meals/saved_meals_screen.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'food_entry_screen_test.dart' show FakeLink, Gate, nowFixed, settle;

// The saved meals list and editor under More (task 2.10), over the real food
// data with the parser worker running inline.

const egg = 'usda:2707153';
const coffee = 'usda:2710373';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late sqlite.Database usda;
  late SqliteUsdaFoods loader;
  late Parser parser;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('daybook_saved_meals');
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
  late List<FakeLink> links;
  var useLink = false;

  setUp(() {
    gate = Gate();
    db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    links = [];
    useLink = false;
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
        workerFactory: (_) {
          if (!useLink) return ParseWorker.inlineWith(parser);
          final link = FakeLink(parser);
          links.add(link);
          return ParseWorker.linked(link);
        },
      ),
    );
    await settle(tester);
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> goToList(WidgetTester tester) async {
    await tap(tester, find.widgetWithText(NavigationDestination, 'More'));
    // The Goals row is first now, so at large text this one may be below the fold.
    await tester.scrollUntilVisible(find.text('Saved meals and aliases'), 100);
    await tester.ensureVisible(find.text('Saved meals and aliases'));
    await tester.pump();
    await tap(tester, find.text('Saved meals and aliases'));
    expect(find.byType(SavedMealsScreen), findsOneWidget);
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

  Future<SavedMeal> usualBreakfast(WidgetTester tester) => makeSaved(
    tester,
    'Usual breakfast',
    [
      item(egg, 'Egg, whole, cooked', 2, '', 100, 176),
      item(coffee, 'Coffee, NS as to type', 1, 'small', 360, 4),
    ],
    aliases: const ['usual breakfast', 'ub'],
  );

  Future<SavedMeal> myOatmeal(WidgetTester tester) => makeSaved(
    tester,
    'My oatmeal',
    [item(egg, 'Egg, whole, cooked', 1, '', 50, 88)],
    aliases: const ['my oats'],
  );

  Future<SavedMealDetail> detail(WidgetTester tester, int id) async {
    final SavedMealDetail? d = await real(tester, () => db.loadSavedMeal(id));
    return d!;
  }

  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;
  Finder nameField() => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == 'Name',
  );
  Finder newNameField() => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == 'New name',
  );
  Finder boxField() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.hintText ==
            'Type to add items, the same way as Food entry',
  );
  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  Finder sheet() => find.byType(CorrectionSheet);
  Finder inSheet(Finder f) => find.descendant(of: sheet(), matching: f);
  Finder tiles() => find.byType(FoodLineTile);
  Finder amountField() => inSheet(
    find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Amount',
    ),
  );

  Future<void> openEditor(WidgetTester tester, String name) async {
    await tap(tester, row(name));
    expect(find.byType(SavedMealEditor), findsOneWidget);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(boxField(), text);
    await tester.pump();
  }

  group('More and the list', () {
    appTest('More has the row, with what is in it; a tap opens the list', (
      tester,
    ) async {
      await openApp(tester);
      await tap(tester, find.widgetWithText(NavigationDestination, 'More'));
      expect(find.byType(MoreScreen), findsOneWidget);
      expect(find.text('Saved meals and aliases'), findsOneWidget);
      expect(find.text('None yet'), findsOneWidget);
      await usualBreakfast(tester);
      await myOatmeal(tester);
      await settle(tester);
      expect(find.text('My oatmeal and 1 more'), findsOneWidget);
      expect(
        tester
            .getSize(find.widgetWithText(ListTile, 'Saved meals and aliases'))
            .height,
        greaterThanOrEqualTo(48),
      );
      await tap(tester, find.text('Saved meals and aliases'));
      expect(find.byType(SavedMealsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    appTest('each row has the name, items and kcal, the other names and the '
        'items in brief, under the help words', (tester) async {
      await usualBreakfast(tester);
      await myOatmeal(tester);
      await openApp(tester);
      await goToList(tester);
      expect(find.text('Saved meals'), findsOneWidget);
      expect(find.text('+ New'), findsOneWidget);
      expect(find.text('Usual breakfast'), findsOneWidget);
      expect(
        find.text('2 items, 180 kcal. Also typed as: usual breakfast, ub'),
        findsOneWidget,
      );
      expect(find.text('Egg, Coffee'), findsNothing);
      expect(find.text('My oatmeal'), findsOneWidget);
      expect(
        find.text('1 item, 88 kcal. Also typed as: my oats'),
        findsOneWidget,
      );
      expect(find.textContaining("Type a saved meal's name"), findsOneWidget);
      expect(find.textContaining('Save as a saved meal'), findsOneWidget);
      expect(
        tester.getSize(row('Usual breakfast')).height,
        greaterThanOrEqualTo(48),
      );
    });

    appTest('a saved meal with no other names has no "Also typed as" line', (
      tester,
    ) async {
      await makeSaved(tester, 'Plain', [item(egg, 'Egg', 1, '', 50, 88)]);
      await openApp(tester);
      await goToList(tester);
      expect(find.text('Plain'), findsOneWidget);
      expect(find.textContaining('Also typed as'), findsNothing);
    });
  });

  group('the editor', () {
    appTest('shows the name, the other names and the items as added lines '
        'with an empty box to type into', (tester) async {
      await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      expect(
        tester.widget<TextField>(nameField()).controller!.text,
        'Usual breakfast',
      );
      expect(find.text('Other names you can type'), findsOneWidget);
      expect(find.text('usual breakfast'), findsOneWidget);
      expect(find.text('ub'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      expect(tiles(), findsNWidgets(2));
      expect(tester.widget<TextField>(boxField()).controller!.text, '');
      expect(find.textContaining('180 kcal', findRichText: true), findsWidgets);
    });

    appTest('rename: saved, read back, and the list says so', (tester) async {
      final m = await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tester.enterText(nameField(), '  Big breakfast ');
      await tester.pump();
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsNothing);
      expect(find.text('Big breakfast'), findsOneWidget);
      expect(find.text('Saved meal "Big breakfast" saved.'), findsOneWidget);
      final d = await detail(tester, m.id);
      expect(d.meal.name, 'Big breakfast');
      expect(d.aliases, ['usual breakfast', 'ub']);
      expect(d.items, hasLength(2));
    });

    appTest('an empty name is refused in plain words and nothing is written', (
      tester,
    ) async {
      final m = await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tester.enterText(nameField(), '   ');
      await tester.pump();
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsOneWidget);
      expect(find.text('Give it a name.'), findsOneWidget);
      expect((await detail(tester, m.id)).meal.name, 'Usual breakfast');
    });

    appTest('names may repeat: a rename to another saved meal\'s name is '
        'saved', (tester) async {
      final m = await usualBreakfast(tester);
      await myOatmeal(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tester.enterText(nameField(), 'My oatmeal');
      await tester.pump();
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsNothing);
      expect((await detail(tester, m.id)).meal.name, 'My oatmeal');
      expect(
        await real(tester, () => db.select(db.savedMeals).get()),
        hasLength(2),
      );
    });

    appTest('add an other name and remove one', (tester) async {
      final m = await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tester.enterText(newNameField(), 'my breakfast');
      await tap(tester, find.text('+ Add'));
      expect(find.text('my breakfast'), findsOneWidget);
      expect(tester.widget<TextField>(newNameField()).controller!.text, '');
      await tap(tester, find.byTooltip('Remove the name ub'));
      expect(find.text('ub'), findsNothing);
      // Targets are 48 dp.
      expect(
        tester.getSize(find.byTooltip('Remove the name my breakfast')).height,
        greaterThanOrEqualTo(48),
      );
      await tap(tester, saveButton());
      expect((await detail(tester, m.id)).aliases, [
        'usual breakfast',
        'my breakfast',
      ]);
    });

    appTest('a name empty or twice in the list is refused when added', (
      tester,
    ) async {
      await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tap(tester, find.text('+ Add'));
      expect(find.text('Type a name to add.'), findsOneWidget);
      await tester.enterText(newNameField(), 'UB');
      await tap(tester, find.text('+ Add'));
      expect(find.text('"UB" is already in this list.'), findsOneWidget);
    });

    appTest('a name another saved meal already uses is refused in plain '
        'words and nothing is written', (tester) async {
      final m = await usualBreakfast(tester);
      await myOatmeal(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tester.enterText(newNameField(), 'My  Oats');
      await tap(tester, find.text('+ Add'));
      await tester.enterText(nameField(), 'Renamed');
      await tester.pump();
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsOneWidget);
      expect(
        find.text(
          '"My  Oats" is already used by another saved meal. Pick a '
          'different name.',
        ),
        findsOneWidget,
      );
      final d = await detail(tester, m.id);
      expect(d.meal.name, 'Usual breakfast');
      expect(d.aliases, ['usual breakfast', 'ub']);
    });

    appTest('add an item by typing: it joins the items when saved, and the '
        'untouched items are as they were', (tester) async {
      final m = await usualBreakfast(tester);
      final before = await detail(tester, m.id);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await type(tester, '1 apple');
      // A typed line shows under the items; the box is outside the scroll.
      expect(tiles(), findsNWidgets(3));
      expect(
        tester.getTopLeft(boxField()).dy,
        greaterThan(tester.getBottomLeft(tiles().last).dy),
      );
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsNothing);
      final d = await detail(tester, m.id);
      expect(d.items, hasLength(3));
      expect(d.items.last.item.foodName, startsWith('Apple'));
      for (var i = 0; i < 2; i++) {
        final a = before.items[i], b = d.items[i];
        expect(b.item.foodRef, a.item.foodRef);
        expect(b.item.quantity, a.item.quantity);
        expect(b.item.baseQuantity, a.item.baseQuantity);
        expect(b.nutrients, a.nutrients);
      }
      expect(d.aliases, ['usual breakfast', 'ub']);
    });

    appTest('the box has its own worker session, a new one each time the '
        'editor opens', (tester) async {
      useLink = true;
      await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await type(tester, '1 apple');
      final first = links.single.lastSession;
      expect(first, greaterThan(0));
      expect(tiles(), findsNWidgets(3));
      await tester.pageBack();
      await settle(tester);
      await openEditor(tester, 'Usual breakfast');
      await type(tester, '1 apple');
      expect(links.single.lastSession, isNot(first));
      expect(tiles(), findsNWidgets(3));
    });

    appTest('a typed saved meal name expands into its items', (tester) async {
      final m = await myOatmeal(tester);
      await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'My oatmeal');
      await type(tester, 'usual breakfast');
      await tap(tester, saveButton());
      expect((await detail(tester, m.id)).items, hasLength(3));
    });

    appTest('a typed item that is not found makes Save read Fix 1 item and '
        'writes nothing', (tester) async {
      final m = await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await type(tester, '1 zorbo, 1 apple');
      expect(find.widgetWithText(FilledButton, 'Fix 1 item'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Fix 1 item'));
      expect(sheet(), findsOneWidget);
      expect((await detail(tester, m.id)).items, hasLength(2));
    });

    appTest('the sheet of a not found item has no Scan and no Create a food: '
        "those are Food entry's", (tester) async {
      await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await type(tester, '1 zorbo, 1 apple');
      await tap(tester, find.widgetWithText(FilledButton, 'Fix 1 item'));
      expect(sheet(), findsOneWidget);
      expect(
        inSheet(find.textContaining('Nothing in the food list')),
        findsOneWidget,
      );
      expect(inSheet(find.text('Scan its barcode')), findsNothing);
      expect(inSheet(find.textContaining('Create a food')), findsNothing);
      expect(
        inSheet(find.textContaining('make it your own food')),
        findsNothing,
      );
    });

    appTest('change an item through the sheet and save: only that item '
        'changes', (tester) async {
      final m = await usualBreakfast(tester);
      final before = await detail(tester, m.id);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tap(
        tester,
        find.widgetWithText(FoodLineTile, 'Egg, whole, cooked'),
      );
      expect(sheet(), findsOneWidget);
      await tester.enterText(amountField(), '3');
      await tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsNothing);
      await tap(tester, saveButton());
      final d = await detail(tester, m.id);
      expect(d.items, hasLength(2));
      expect(d.items.first.item.quantity, 3);
      expect(d.items.first.item.baseQuantity, 150);
      expect(d.items.last.item.quantity, before.items.last.item.quantity);
      expect(d.items.last.nutrients, before.items.last.nutrients);
    });

    appTest('remove an item through the sheet and save', (tester) async {
      final m = await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tap(
        tester,
        find.widgetWithText(FoodLineTile, 'Egg, whole, cooked'),
      );
      await tap(tester, inSheet(find.text('Remove from meal')));
      expect(tiles(), findsNWidgets(1));
      await tap(tester, saveButton());
      final d = await detail(tester, m.id);
      expect(d.items, hasLength(1));
      expect(d.items.single.item.foodRef, coffee);
    });

    appTest('a saved meal with no items is refused', (tester) async {
      final m = await myOatmeal(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'My oatmeal');
      await tap(
        tester,
        find.widgetWithText(FoodLineTile, 'Egg, whole, cooked'),
      );
      await tap(tester, inSheet(find.text('Remove from meal')));
      await tap(tester, saveButton());
      expect(find.text('Add at least one item.'), findsOneWidget);
      expect(find.byType(SavedMealEditor), findsOneWidget);
      expect((await detail(tester, m.id)).items, hasLength(1));
    });

    appTest('+ New makes a saved meal from typed items', (tester) async {
      await openApp(tester);
      await goToList(tester);
      await tap(tester, find.text('+ New'));
      expect(find.text('New saved meal'), findsWidgets);
      await tester.enterText(nameField(), 'Snack mix');
      await type(tester, '2 eggs');
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsNothing);
      expect(find.text('Snack mix'), findsOneWidget);
      expect(find.text('Saved meal "Snack mix" saved.'), findsOneWidget);
      final rows = await real(tester, () => db.savedMealsList());
      expect(rows.single.meal.name, 'Snack mix');
      expect(rows.single.aliases, isEmpty);
      expect(rows.single.items.single.item.quantity, 2);
    });
  });

  group('review fixes', () {
    appTest('a grown box and a message in the bar at 2x text with the '
        'keyboard up have no overflow at 344x800 and 344x700', (tester) async {
      for (final h in [800.0, 700.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await usualBreakfast(tester);
        await openApp(tester, size: Size(344, h));
        await goToList(tester);
        await openEditor(tester, 'Usual breakfast');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await tester.enterText(nameField(), '');
        await type(tester, '1 apple\n1 egg\n1 pear\n1 plum');
        await tester.tap(saveButton());
        await settle(tester);
        expect(find.text('Give it a name.'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'height $h');
        expect(tester.getRect(boxField()).top, greaterThanOrEqualTo(0));
        expect(
          tester.getRect(saveButton()).bottom,
          lessThanOrEqualTo(h - 300 + 0.5),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
        await real(tester, () => db.delete(db.savedMeals).go());
      }
    });

    appTest('a route that took the top during the write is not what closes: '
        'the editor leaves, and Save cannot run twice', (tester) async {
      await openApp(tester);
      await goToList(tester);
      await tap(tester, find.text('+ New'));
      await tester.enterText(nameField(), 'Snack mix');
      await type(tester, '2 eggs');
      gate.hold = Completer<void>();
      await tester.tap(saveButton());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
      await tester.tap(saveButton(), warnIfMissed: false);
      Navigator.of(tester.element(find.byType(SavedMealEditor))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('on top')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      gate.hold!.complete();
      gate.hold = null;
      await settle(tester);
      expect(find.byType(SavedMealEditor), findsNothing);
      expect(find.text('on top'), findsOneWidget);
      expect(
        await real(tester, () => db.select(db.savedMeals).get()),
        hasLength(1),
      );
    });

    appTest('Back while a delete runs waits for it: the editor leaves with '
        'the Undo on the list', (tester) async {
      await myOatmeal(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'My oatmeal');
      gate.holdDelete = Completer<void>();
      await tap(tester, find.byTooltip('More options'));
      await tester.tap(find.text('Delete saved meal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SavedMealEditor), findsOneWidget);
      gate.holdDelete!.complete();
      gate.holdDelete = null;
      await settle(tester);
      expect(find.byType(SavedMealEditor), findsNothing);
      expect(find.text('Saved meal "My oatmeal" deleted.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    appTest('a name typed in the New name field is added by Save', (
      tester,
    ) async {
      final m = await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tester.enterText(newNameField(), 'my usual');
      await tester.pump();
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsNothing);
      expect((await detail(tester, m.id)).aliases, [
        'usual breakfast',
        'ub',
        'my usual',
      ]);
    });

    appTest('a name left in the New name field that is refused stops the '
        'save, with the same words as + Add', (tester) async {
      final m = await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tester.enterText(nameField(), 'Renamed');
      await tester.enterText(newNameField(), 'UB');
      await tester.pump();
      await tap(tester, saveButton());
      expect(find.byType(SavedMealEditor), findsOneWidget);
      expect(find.text('"UB" is already in this list.'), findsOneWidget);
      expect((await detail(tester, m.id)).meal.name, 'Usual breakfast');
    });

    appTest('Try again after the worker died sends the picks again', (
      tester,
    ) async {
      useLink = true;
      await usualBreakfast(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await type(tester, '2 slices toast');
      final s = tester.state<SavedMealEditorState>(
        find.byType(SavedMealEditor),
      );
      const text = '2 slices toast';
      final span = s.debugResult!.lines.single.span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      await real(
        tester,
        () => s.debugHandle!.pick(
          text,
          span,
          alts.others.first.ref,
          marker: Marker.yourPick,
        ),
      );
      await tester.pump();
      expect(find.text('Your pick'), findsOneWidget);
      links.single.crash();
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Your pick'), findsOneWidget);
    });
  });

  group('delete', () {
    appTest('removes the saved meal at once; Undo brings it back with its '
        'names and items, once', (tester) async {
      final m = await usualBreakfast(tester);
      await myOatmeal(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tap(tester, find.byTooltip('More options'));
      await tap(tester, find.text('Delete saved meal'));
      expect(find.byType(SavedMealEditor), findsNothing);
      expect(
        find.text('Saved meal "Usual breakfast" deleted.'),
        findsOneWidget,
      );
      expect(find.text('Usual breakfast'), findsNothing);
      expect(await real(tester, () => db.loadSavedMeal(m.id)), isNull);

      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await settle(tester);
      final d = await detail(tester, m.id);
      expect(d.meal.name, 'Usual breakfast');
      expect(d.aliases, ['usual breakfast', 'ub']);
      expect(d.items, hasLength(2));
      expect(find.text('Usual breakfast'), findsOneWidget);
      // One Undo: the message and the held rows are gone.
      expect(find.text('Undo'), findsNothing);
    });

    appTest('the message and its Undo go after ten seconds', (tester) async {
      final m = await myOatmeal(tester);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'My oatmeal');
      await tap(tester, find.byTooltip('More options'));
      await tap(tester, find.text('Delete saved meal'));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Undo'), findsNothing);
      expect(await real(tester, () => db.loadSavedMeal(m.id)), isNull);
    });
  });

  group('logged meals', () {
    Future<StoredMeal> logFrom(WidgetTester tester, SavedMeal m) =>
        real(tester, () async {
          final x = (await db.expandSavedMeal(m.id))!;
          final slot = (await db.select(db.mealSlots).get()).first.id;
          return db.saveMeal(
            now: nowFixed,
            localDate: '2026-11-12',
            slotId: slot,
            lines: x.items,
            savedMealId: m.id,
          );
        });

    appTest('a logged meal made from the saved meal is unchanged after the '
        'saved meal is edited, and after it is deleted', (tester) async {
      final m = await usualBreakfast(tester);
      final logged = await logFrom(tester, m);
      await openApp(tester);
      await goToList(tester);
      await openEditor(tester, 'Usual breakfast');
      await tap(
        tester,
        find.widgetWithText(FoodLineTile, 'Egg, whole, cooked'),
      );
      await tester.enterText(amountField(), '5');
      await tap(tester, inSheet(find.text('Done')));
      await tester.enterText(nameField(), 'Changed');
      await tester.pump();
      await tap(tester, saveButton());

      Future<StoredMeal> reread() async {
        final StoredMeal? r = await real(
          tester,
          () => db.loadMeal(logged.meal.id),
        );
        return r!;
      }

      var now = await reread();
      expect(now.entries, hasLength(2));
      expect(now.entries.first.entry.quantity, 2);
      expect(now.entries.first.entry.baseQuantity, 100);
      expect(now.totals, logged.totals);
      expect(now.meal.savedMealId, m.id);

      await openEditor(tester, 'Changed');
      await tap(tester, find.byTooltip('More options'));
      await tap(tester, find.text('Delete saved meal'));
      now = await reread();
      expect(now.entries, hasLength(2));
      expect(now.entries.first.entry.quantity, 2);
      expect(now.totals, logged.totals);
    });
  });

  group('layout', () {
    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      appTest('at ${width.toInt()} dp and text scale $scale: no overflow, '
          '48 dp targets, the box and Save stay in view', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await usualBreakfast(tester);
        await myOatmeal(tester);
        await openApp(tester, size: Size(width, 800));
        await goToList(tester);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(row('Usual breakfast')).height,
          greaterThanOrEqualTo(48),
        );
        final plus = find.widgetWithText(TextButton, '+ New');
        expect(tester.getSize(plus).height, greaterThanOrEqualTo(48));
        await openEditor(tester, 'Usual breakfast');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await type(tester, '1 apple');
        expect(tester.takeException(), isNull);
        final box = tester.getRect(boxField());
        final save = tester.getRect(saveButton());
        expect(box.top, greaterThanOrEqualTo(0));
        expect(save.bottom, lessThanOrEqualTo(500));
        expect(save.height, greaterThanOrEqualTo(48));
        expect(box.bottom, lessThanOrEqualTo(save.top + 0.5));
        for (final b in find.byType(IconButton).evaluate()) {
          final size = tester.getSize(find.byWidget(b.widget));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      });
    }
  });
}
