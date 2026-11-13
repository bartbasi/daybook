// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/screens/food/correction_sheet.dart';
import 'package:daybook/screens/food/food_entry_screen.dart';
import 'package:daybook/screens/food/food_line_tile.dart';
import 'package:daybook/screens/my_foods/recipe_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_foods_harness.dart';

// The recipe editor (task 2.12, food-editor frame 2): ingredients as added
// lines, a typed box that adds more, servings, and totals worked out from the
// ingredients each time.

const egg = 'usda:2707153';
const coffee = 'usda:2710373';

void main() {
  final h = MyFoodsHarness()..register();

  /// What the food data says one amount of a food is.
  Future<Line> priced(
    WidgetTester t,
    String ref,
    double q, [
    String unit = '',
  ]) => h.real(t, () async {
    final w = ParseWorker.inlineWith(h.parser);
    await w.start();
    final l = await w.foodLine(ref, quantity: q, unit: unit);
    await w.dispose();
    return l!;
  });

  double kcalOf(Line l) => l.nutrients[Nutrients.energy]!;

  /// Ingredients as an older editor left them: stored with numbers that are
  /// not the food data's, so a number shown or stored later is proven to have
  /// been worked out again.
  MealLineInput stale(
    String ref,
    String name,
    double q,
    String unit,
    double base,
  ) => MealLineInput(
    foodRef: ref,
    foodName: name,
    quantity: q,
    unitLabel: unit,
    baseQuantity: base,
    baseUnit: 'g',
    nutrients: const {Nutrients.energy: 999, Nutrients.protein: 99},
  );

  Future<FoodDetail> makeRecipe(
    WidgetTester t, {
    String name = 'Turkey chili',
    double servings = 4,
    List<MealLineInput>? ingredients,
  }) => h.real(
    t,
    () => h.db.createRecipe(
      RecipeInput(
        name: name,
        servings: servings,
        ingredients:
            ingredients ??
            [
              stale(egg, 'Egg, whole, cooked', 2, '', 100),
              stale(coffee, 'Coffee, NS as to type', 1, 'small', 360),
            ],
      ),
      nowFixed,
    ),
  );

  Future<FoodDetail> reload(WidgetTester t, int id) async {
    final FoodDetail? d = await h.real(t, () => h.db.loadFood(id));
    return d!;
  }

  Finder boxField() => find.byWidgetPredicate(
    (w) =>
        w is TextField && w.decoration?.hintText == 'Type to add ingredients',
  );
  Finder tiles() => find.byType(FoodLineTile);

  /// The tile of the ingredient whose food name starts with [prefix].
  Finder tileNamed(String prefix) => find.byWidgetPredicate(
    (w) => w is FoodLineTile && (w.line.foodName ?? '').startsWith(prefix),
  );
  Finder sheet() => find.byType(CorrectionSheet);
  Finder inSheet(Finder f) => find.descendant(of: sheet(), matching: f);

  Future<void> type(WidgetTester t, String text) async {
    await t.enterText(boxField(), text);
    await t.pump();
  }

  Future<void> newRecipe(WidgetTester t) async {
    await h.goToList(t);
    await h.tap(t, find.text('+ New'));
    await h.tap(t, find.text('New recipe').last);
    expect(find.byType(RecipeEditor), findsOneWidget);
  }

  Future<void> openRecipe(WidgetTester t, String name) async {
    await h.goToList(t);
    await h.tap(t, find.text(name));
    expect(find.byType(RecipeEditor), findsOneWidget);
    // Opening works out each ingredient again before Save can be used.
    await settle(t);
  }

  /// The text in the totals bar, spoken form (the bar excludes its words from
  /// the tree and gives one label).
  String barLabel(WidgetTester t) {
    final f = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label ?? '').startsWith('Each serving'),
    );
    return t.widget<Semantics>(f.first).properties.label!;
  }

  group('a new recipe', () {
    h.appTest('ingredients typed in the box, servings, and the totals worked '
        'out and stored', (tester) async {
      final e2 = await priced(tester, egg, 2);
      final c1 = await priced(tester, coffee, 1, 'small');
      await h.openApp(tester);
      await newRecipe(tester);
      await h.enter(tester, 'Name', '  Breakfast pot ');
      await type(tester, '2 eggs, 1 small coffee');
      expect(tiles(), findsNWidgets(2));
      await h.enter(tester, 'Makes', '2');
      final whole = kcalOf(e2) + kcalOf(c1);
      expect(
        find.textContaining('Whole: ${_n(whole)} kcal', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '${_n(whole / 2)} kcal a serving',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await h.tap(tester, h.saveButton());
      expect(find.byType(RecipeEditor), findsNothing);
      final f = (await h.real(tester, () => h.db.myFoods())).single;
      expect(f.food.kind, 'recipe');
      expect(f.food.name, 'Breakfast pot');
      expect((f.food.baseAmount, f.food.baseUnit), (2.0, 'serving'));
      expect(f.nutrients[Nutrients.energy], closeTo(whole, 1e-6));
      expect(f.ingredients.map((i) => i.foodRef), [egg, coffee]);
      expect(f.ingredients.first.quantity, 2);
      expect(find.text('"Breakfast pot" saved.'), findsOneWidget);
      expect(
        find.text('Recipe, 2 servings, ${_n(whole / 2)} kcal a serving'),
        findsOneWidget,
      );
    });

    h.appTest('a name, servings above 0 and an ingredient are each needed, '
        'and nothing is written until they are there', (tester) async {
      await h.openApp(tester);
      await newRecipe(tester);
      await type(tester, '2 eggs');
      await h.tap(tester, h.saveButton());
      expect(find.text('Give it a name.'), findsOneWidget);
      expect(await h.real(tester, () => h.db.myFoods()), isEmpty);

      await h.enter(tester, 'Name', 'Eggs');
      await h.enter(tester, 'Makes', '');
      await h.tap(tester, h.saveButton());
      expect(
        find.text('Enter how many servings it makes, a number above 0.'),
        findsOneWidget,
      );
      await h.enter(tester, 'Makes', '0');
      await h.tap(tester, h.saveButton());
      expect(
        find.text('Enter how many servings it makes, a number above 0.'),
        findsOneWidget,
      );
      expect(await h.real(tester, () => h.db.myFoods()), isEmpty);

      await h.enter(tester, 'Makes', '1');
      await type(tester, '');
      await h.tap(tester, h.saveButton());
      expect(find.text('Add at least one ingredient.'), findsOneWidget);
      expect(await h.real(tester, () => h.db.myFoods()), isEmpty);
      expect(find.byType(RecipeEditor), findsOneWidget);
    });

    h.appTest('servings take a decimal comma', (tester) async {
      await h.openApp(tester);
      await newRecipe(tester);
      await h.enter(tester, 'Name', 'Eggs');
      await type(tester, '2 eggs');
      await h.enter(tester, 'Makes', '2,5');
      await h.tap(tester, h.saveButton());
      final f = (await h.real(tester, () => h.db.myFoods())).single;
      expect(f.food.baseAmount, 2.5);
    });

    h.appTest('a typed ingredient that is not found makes Save read Fix 1 '
        'item and writes nothing', (tester) async {
      await h.openApp(tester);
      await newRecipe(tester);
      await h.enter(tester, 'Name', 'Mystery');
      await type(tester, '1 zorbo, 1 apple');
      await tester.pump();
      expect(find.widgetWithText(FilledButton, 'Fix 1 item'), findsOneWidget);
      await h.tap(tester, find.widgetWithText(FilledButton, 'Fix 1 item'));
      expect(sheet(), findsOneWidget);
      // The sheet here has no Scan and no Create: those are Food entry's.
      expect(inSheet(find.text('Scan its barcode')), findsNothing);
      expect(inSheet(find.textContaining('Create a food')), findsNothing);
      expect(await h.real(tester, () => h.db.myFoods()), isEmpty);
    });
  });

  group('a saved recipe opened again', () {
    h.appTest('shows its ingredients as added lines with numbers worked out '
        'again, not the stored ones', (tester) async {
      final e2 = await priced(tester, egg, 2);
      final c1 = await priced(tester, coffee, 1, 'small');
      await makeRecipe(tester);
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      expect(
        tester.widget<TextField>(h.field('Name')).controller!.text,
        'Turkey chili',
      );
      expect(tester.widget<TextField>(h.field('Makes')).controller!.text, '4');
      expect(tiles(), findsNWidgets(2));
      expect(tester.widget<TextField>(boxField()).controller!.text, '');
      final whole = kcalOf(e2) + kcalOf(c1);
      expect(
        find.textContaining('Whole: ${_n(whole)} kcal', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('999'), findsNothing);
    });

    h.appTest('saving with no change stores the totals from the food data', (
      tester,
    ) async {
      final e2 = await priced(tester, egg, 2);
      final c1 = await priced(tester, coffee, 1, 'small');
      final r = await makeRecipe(tester);
      expect(r.nutrients[Nutrients.energy], 1998);
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      await h.tap(tester, h.saveButton());
      expect(find.byType(RecipeEditor), findsNothing);
      final d = await reload(tester, r.food.id);
      expect(
        d.nutrients[Nutrients.energy],
        closeTo(kcalOf(e2) + kcalOf(c1), 1e-6),
      );
      expect(d.nutrients[Nutrients.protein], isNot(198));
      expect(d.ingredients, hasLength(2));
    });

    h.appTest('an ingredient changed through the sheet: the totals shown and '
        'stored follow the current ingredients', (tester) async {
      final e3 = await priced(tester, egg, 3);
      final c1 = await priced(tester, coffee, 1, 'small');
      final r = await makeRecipe(tester);
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      await h.tap(tester, tileNamed('Egg'));
      expect(sheet(), findsOneWidget);
      await tester.enterText(
        inSheet(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Amount',
          ),
        ),
        '3',
      );
      await h.tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsNothing);
      final whole = kcalOf(e3) + kcalOf(c1);
      expect(
        find.textContaining('Whole: ${_n(whole)} kcal', findRichText: true),
        findsOneWidget,
      );
      await h.tap(tester, h.saveButton());
      final d = await reload(tester, r.food.id);
      expect(d.nutrients[Nutrients.energy], closeTo(whole, 1e-6));
      expect(d.ingredients.first.quantity, 3);
    });

    h.appTest('an ingredient added by typing, then one removed through the '
        'sheet: the totals follow each step', (tester) async {
      final e2 = await priced(tester, egg, 2);
      final c1 = await priced(tester, coffee, 1, 'small');
      final r = await makeRecipe(tester);
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      await type(tester, '2 eggs');
      expect(tiles(), findsNWidgets(3));
      final up = kcalOf(e2) * 2 + kcalOf(c1);
      expect(
        find.textContaining('Whole: ${_n(up)} kcal', findRichText: true),
        findsOneWidget,
      );
      // Remove the coffee.
      await h.tap(tester, tileNamed('Coffee'));
      await h.tap(tester, inSheet(find.text('Remove from meal')));
      expect(tiles(), findsNWidgets(2));
      final down = kcalOf(e2) * 2;
      expect(
        find.textContaining('Whole: ${_n(down)} kcal', findRichText: true),
        findsOneWidget,
      );
      await h.tap(tester, h.saveButton());
      final d = await reload(tester, r.food.id);
      expect(d.nutrients[Nutrients.energy], closeTo(down, 1e-6));
      expect(d.ingredients, hasLength(2));
      expect(d.ingredients.every((i) => i.foodRef == egg), isTrue);
    });

    h.appTest('servings changed: the per serving number follows, the whole '
        'stays', (tester) async {
      final e2 = await priced(tester, egg, 2);
      final c1 = await priced(tester, coffee, 1, 'small');
      final r = await makeRecipe(tester);
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      final whole = kcalOf(e2) + kcalOf(c1);
      await h.enter(tester, 'Makes', '8');
      expect(
        find.textContaining(
          '${_n(whole / 8)} kcal a serving',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Whole: ${_n(whole)} kcal', findRichText: true),
        findsOneWidget,
      );
      await h.tap(tester, h.saveButton());
      final d = await reload(tester, r.food.id);
      expect(d.food.baseAmount, 8);
      expect(d.nutrients[Nutrients.energy], closeTo(whole, 1e-6));
    });

    h.appTest('an ingredient that cannot be worked out any more stops Save '
        'with a plain message, until it is removed', (tester) async {
      await makeRecipe(
        tester,
        ingredients: [
          stale(egg, 'Egg, whole, cooked', 2, '', 100),
          stale('usda:999999999', 'Gone food', 1, '', 100),
        ],
      );
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      await h.tap(tester, h.saveButton());
      expect(
        find.text(
          'An ingredient could not be worked out. Tap it to remove it or '
          'pick another food.',
        ),
        findsOneWidget,
      );
      expect(find.byType(RecipeEditor), findsOneWidget);
      await h.tap(tester, find.widgetWithText(FoodLineTile, 'Gone food'));
      await h.tap(tester, inSheet(find.text('Remove from meal')));
      await h.tap(tester, h.saveButton());
      expect(find.byType(RecipeEditor), findsNothing);
    });
  });

  group('logged meals and Food entry', () {
    h.appTest('"2 servings chili" in Food entry matches the recipe with the '
        'right numbers (worked example 74)', (tester) async {
      final e2 = await priced(tester, egg, 2);
      final c1 = await priced(tester, coffee, 1, 'small');
      final r = await makeRecipe(tester);
      // Store it the way the editor would, with the right totals.
      await h.real(
        tester,
        () => h.db.editRecipe(
          r.food.id,
          RecipeInput(
            name: 'Turkey chili',
            servings: 4,
            ingredients: [
              MealLineInput.fromLine(e2),
              MealLineInput.fromLine(c1),
            ],
          ),
          nowFixed,
        ),
      );
      await h.openApp(tester);
      await tester.tap(find.widgetWithText(FilledButton, '+ Food'));
      await settle(tester);
      final box = find.descendant(
        of: find.byType(FoodEntryScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(box, '2 servings chili');
      await tester.pump();
      await settle(tester);
      expect(tiles(), findsOneWidget);
      expect(find.text('Turkey chili'), findsOneWidget);
      final two = (kcalOf(e2) + kcalOf(c1)) / 4 * 2;
      expect(
        find.textContaining('${_n(two)} kcal', findRichText: true),
        findsWidgets,
      );
      expect(find.text('Chili, NFS'), findsNothing);
    });

    h.appTest('a logged meal is unchanged after its recipe is edited, and '
        'after it is deleted', (tester) async {
      final e2 = await priced(tester, egg, 2);
      final r = await makeRecipe(
        tester,
        ingredients: [MealLineInput.fromLine(e2)],
      );
      final slot = (await h.real(
        tester,
        () => h.db.select(h.db.mealSlots).get(),
      )).first.id;
      final logged = await h.real(
        tester,
        () => h.db.saveMeal(
          now: nowFixed,
          localDate: '2026-11-12',
          slotId: slot,
          lines: [
            MealLineInput(
              foodRef: 'local:${r.food.id}',
              foodName: 'Turkey chili',
              quantity: 2,
              unitLabel: 'serving',
              baseQuantity: 2,
              baseUnit: 'serving',
              nutrients: {Nutrients.energy: kcalOf(e2) / 2},
            ),
          ],
        ),
      );
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      await h.enter(tester, 'Name', 'Changed chili');
      await type(tester, '2 eggs');
      await h.tap(tester, h.saveButton());

      Future<StoredMeal> reread() async {
        final StoredMeal? m = await h.real(
          tester,
          () => h.db.loadMeal(logged.meal.id),
        );
        return m!;
      }

      var now = await reread();
      expect(now.entries.single.entry.foodName, 'Turkey chili');
      expect(now.entries.single.entry.quantity, 2);
      expect(now.totals, logged.totals);

      await h.tap(tester, find.text('Changed chili'));
      await h.tap(tester, find.byTooltip('More options'));
      await h.tap(tester, find.text('Delete recipe'));
      expect(find.byType(RecipeEditor), findsNothing);
      now = await reread();
      expect(now.entries.single.entry.foodName, 'Turkey chili');
      expect(now.totals, logged.totals);
    });
  });

  group('delete and leaving', () {
    h.appTest('Delete archives the recipe at once with Undo on the list, '
        'once', (tester) async {
      final r = await makeRecipe(tester);
      await h.openApp(tester);
      await openRecipe(tester, 'Turkey chili');
      await h.tap(tester, find.byTooltip('More options'));
      await h.tap(tester, find.text('Delete recipe'));
      expect(find.byType(RecipeEditor), findsNothing);
      expect(find.text('"Turkey chili" deleted.'), findsOneWidget);
      expect(await h.real(tester, () => h.db.myFoods()), isEmpty);
      expect((await reload(tester, r.food.id)).food.archived, isTrue);
      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await settle(tester);
      final d = await reload(tester, r.food.id);
      expect(d.food.archived, isFalse);
      expect(d.ingredients, hasLength(2));
      expect(find.text('Turkey chili'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    h.appTest('Back without saving writes nothing', (tester) async {
      await h.openApp(tester);
      await newRecipe(tester);
      await h.enter(tester, 'Name', 'Eggs');
      await type(tester, '2 eggs');
      await tester.pageBack();
      await settle(tester);
      expect(find.byType(RecipeEditor), findsNothing);
      expect(await h.real(tester, () => h.db.myFoods()), isEmpty);
    });

    h.appTest('a second tap on Save while it writes writes once, and a route '
        'that took the top is not what closes', (tester) async {
      await h.openApp(tester);
      await newRecipe(tester);
      await h.enter(tester, 'Name', 'Eggs');
      await type(tester, '2 eggs');
      h.gate.hold = Completer<void>();
      await tester.tap(h.saveButton());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(h.saveButton()).onPressed, isNull);
      await tester.tap(h.saveButton(), warnIfMissed: false);
      Navigator.of(tester.element(find.byType(RecipeEditor))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('on top')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      h.gate.hold!.complete();
      h.gate.hold = null;
      await settle(tester);
      expect(find.byType(RecipeEditor), findsNothing);
      expect(find.text('on top'), findsOneWidget);
      expect(await h.real(tester, () => h.db.myFoods()), hasLength(1));
    });

    h.appTest('a failing write keeps the editor and says so', (tester) async {
      await h.openApp(tester);
      await newRecipe(tester);
      await h.enter(tester, 'Name', 'Eggs');
      await type(tester, '2 eggs');
      h.gate.failInsert = true;
      await h.tap(tester, h.saveButton());
      expect(find.byType(RecipeEditor), findsOneWidget);
      expect(
        find.text('Could not save the recipe. Try again.'),
        findsOneWidget,
      );
      h.gate.failInsert = false;
      await h.tap(tester, h.saveButton());
      expect(find.byType(RecipeEditor), findsNothing);
    });
  });

  group('layout', () {
    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      h.appTest('at ${width.toInt()} dp and text scale $scale with the '
          'keyboard up: no overflow, 48 dp targets, the box and Save stay in '
          'view', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await makeRecipe(tester);
        await h.openApp(tester, size: Size(width, 800));
        await openRecipe(tester, 'Turkey chili');
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await h.enter(tester, 'Name', '');
        await type(tester, '1 egg\n1 pear\n1 plum');
        await tester.tap(h.saveButton());
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Give it a name.'), findsOneWidget);
        final box = tester.getRect(boxField());
        final save = tester.getRect(h.saveButton());
        expect(box.top, greaterThanOrEqualTo(0));
        expect(save.bottom, lessThanOrEqualTo(500.5));
        expect(save.height, greaterThanOrEqualTo(48));
        expect(box.bottom, lessThanOrEqualTo(save.top + 0.5));
        for (final b in find.byType(IconButton).evaluate()) {
          final size = tester.getSize(find.byWidget(b.widget));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        // The spoken totals are one label for the bar.
        expect(barLabel(tester), startsWith('Each serving'));
      });
    }
  });
}

/// A kcal number as the app shows it: rounded, with thousands commas.
String _n(double v) {
  final s = v.round().abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
