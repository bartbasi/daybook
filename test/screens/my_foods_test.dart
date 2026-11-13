// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/data/off_client.dart';
import 'package:daybook/screens/my_foods/food_editor.dart';
import 'package:daybook/screens/my_foods/my_foods_screen.dart';
import 'package:daybook/screens/my_foods/recipe_editor.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_foods_harness.dart';

// My foods and recipes under More (task 2.12): the list, the way into each
// editor, delete with Undo, the barcode of a deleted food, and logged meals
// that never change.

const code = '0036000291452';

void main() {
  final h = MyFoodsHarness()..register();

  Future<FoodDetail> makeFood(
    WidgetTester t,
    String name, {
    String? brand,
    String? barcode,
    double kcal = 100,
    FoodBasis basis = FoodBasis.per100g,
  }) => h.real(
    t,
    () => h.db.createCustomFood(
      CustomFoodInput(
        name: name,
        brand: brand,
        barcode: barcode,
        basis: basis,
        nutrients: {Nutrients.energy: kcal},
      ),
      nowFixed,
    ),
  );

  Future<FoodDetail> makeRecipe(WidgetTester t, String name) => h.real(
    t,
    () => h.db.createRecipe(
      RecipeInput(
        name: name,
        servings: 4,
        ingredients: const [
          MealLineInput(
            foodRef: 'usda:2707153',
            foodName: 'Egg',
            quantity: 2,
            unitLabel: '',
            baseQuantity: 100,
            baseUnit: 'g',
            nutrients: {Nutrients.energy: 1236},
          ),
        ],
      ),
      nowFixed,
    ),
  );

  Future<FoodDetail> reload(WidgetTester t, int id) async {
    final FoodDetail? d = await h.real(t, () => h.db.loadFood(id));
    return d!;
  }

  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

  Future<void> deleteOpen(WidgetTester t) async {
    await h.tap(t, find.byTooltip('More options'));
    await h.tap(t, find.textContaining('Delete '));
  }

  group('the list', () {
    h.appTest('shows foods and recipes by name, each with what it is and its '
        'calories; cached products and archived foods are not listed', (
      tester,
    ) async {
      await makeFood(tester, 'Zorbo bar', brand: 'Mill', kcal: 450);
      await makeFood(
        tester,
        'Apple pie slice',
        kcal: 300,
        basis: FoodBasis.perServing,
      );
      await makeFood(tester, 'Oat drink', kcal: 45, basis: FoodBasis.per100ml);
      await makeRecipe(tester, 'Turkey chili');
      final gone = await makeFood(tester, 'Old thing');
      await h.real(tester, () => h.db.archiveFood(gone.food.id, nowFixed));
      await h.real(
        tester,
        () => h.db
            .into(h.db.foods)
            .insert(
              FoodsCompanion.insert(
                kind: 'off',
                name: 'Scanned yogurt',
                barcode: const Value('5000000000012'),
                baseAmount: 100,
                baseUnit: 'g',
                createdAtMs: 1,
                updatedAtMs: 1,
              ),
            ),
      );
      await h.openApp(tester);
      await h.goToList(tester);
      expect(find.text('My foods and recipes'), findsWidgets);
      expect(find.text('+ New'), findsOneWidget);
      expect(find.text('Apple pie slice'), findsOneWidget);
      expect(find.text('300 kcal per serving'), findsOneWidget);
      expect(find.text('Mill, 450 kcal per 100 g'), findsOneWidget);
      expect(find.text('45 kcal per 100 ml'), findsOneWidget);
      expect(
        find.text('Recipe, 4 servings, 309 kcal a serving'),
        findsOneWidget,
      );
      expect(find.text('Old thing'), findsNothing);
      expect(find.text('Scanned yogurt'), findsNothing);
      // By name.
      final ys = [
        for (final n in [
          'Apple pie slice',
          'Oat drink',
          'Turkey chili',
          'Zorbo bar',
        ])
          tester.getTopLeft(find.text(n)).dy,
      ];
      expect([...ys]..sort(), ys);
      expect(
        find.text(
          'A food or recipe you make here can be typed in Food entry like any other food.',
        ),
        findsOneWidget,
      );
      expect(tester.getSize(row('Zorbo bar')).height, greaterThanOrEqualTo(48));
    });

    h.appTest('+ New asks for a food or a recipe and opens that editor', (
      tester,
    ) async {
      await h.openApp(tester);
      await h.goToList(tester);
      final plus = find.ancestor(
        of: find.text('+ New'),
        matching: find.byType(PopupMenuButton<bool>),
      );
      expect(tester.getSize(plus).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('New food or recipe'), findsOneWidget);
      await h.tap(tester, find.text('+ New'));
      await h.tap(tester, find.text('New recipe').last);
      expect(find.byType(RecipeEditor), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      await h.tap(tester, find.text('+ New'));
      await h.tap(tester, find.text('New food').last);
      expect(find.byType(FoodEditor), findsOneWidget);
    });

    h.appTest('a tap opens the right editor for the kind, and a fast double '
        'tap opens one', (tester) async {
      await makeFood(tester, 'Zorbo bar');
      await makeRecipe(tester, 'Turkey chili');
      await h.openApp(tester);
      await h.goToList(tester);
      await tester.tap(row('Zorbo bar'));
      await tester.tap(row('Zorbo bar'), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(FoodEditor), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      await h.tap(tester, row('Turkey chili'));
      expect(find.byType(RecipeEditor), findsOneWidget);
    });
  });

  group('delete and Undo', () {
    h.appTest('Delete takes the food off the list at once with Undo for ten '
        'seconds; Undo puts it back with its barcode, once', (tester) async {
      final f = await makeFood(tester, 'Zorbo bar', barcode: code);
      await h.openApp(tester);
      await h.goToList(tester);
      await h.tap(tester, find.text('Zorbo bar'));
      await deleteOpen(tester);
      expect(find.byType(FoodEditor), findsNothing);
      expect(find.text('"Zorbo bar" deleted.'), findsOneWidget);
      expect(find.text('Zorbo bar'), findsNothing);
      var d = await reload(tester, f.food.id);
      expect(d.food.archived, isTrue);
      // The barcode is free, so a scan no longer finds a food it cannot use.
      expect(d.food.barcode, isNull);
      expect(await h.real(tester, () => findFoodByBarcode(h.db, code)), isNull);

      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await settle(tester);
      d = await reload(tester, f.food.id);
      expect(d.food.archived, isFalse);
      expect(d.food.barcode, code);
      expect(find.text('Zorbo bar'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(
        (await h.real(tester, () => findFoodByBarcode(h.db, code)))!.id,
        f.food.id,
      );
    });

    h.appTest('Undo when another food took the barcode meanwhile brings the '
        'food back without it, and says so', (tester) async {
      final f = await makeFood(tester, 'Zorbo bar', barcode: code);
      await h.openApp(tester);
      await h.goToList(tester);
      await h.tap(tester, find.text('Zorbo bar'));
      await deleteOpen(tester);
      final other = await makeFood(tester, 'Newer bar', barcode: code);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      final d = await reload(tester, f.food.id);
      expect(d.food.archived, isFalse);
      expect(d.food.barcode, isNull);
      expect((await reload(tester, other.food.id)).food.barcode, code);
      expect(
        find.text(
          '"Zorbo bar" is back. Its barcode now belongs to another food, so '
          'it was left off.',
        ),
        findsOneWidget,
      );
    });

    h.appTest('a deleted food gives its barcode up: a new food can use it', (
      tester,
    ) async {
      await makeFood(tester, 'Zorbo bar', barcode: code);
      await h.openApp(tester);
      await h.goToList(tester);
      await h.tap(tester, find.text('Zorbo bar'));
      await deleteOpen(tester);
      await h.tap(tester, find.text('+ New'));
      await h.tap(tester, find.text('New food').last);
      await h.enter(tester, 'Name', 'Second bar');
      await h.enter(tester, 'Calories', '80');
      await h.enter(tester, 'Barcode (optional)', code);
      await h.tap(tester, h.saveButton());
      expect(find.byType(FoodEditor), findsNothing);
      final found = await h.real(tester, () => findFoodByBarcode(h.db, code));
      expect((await reload(tester, found!.id)).food.name, 'Second bar');
    });

    h.appTest('the message and its Undo go after ten seconds', (tester) async {
      final f = await makeFood(tester, 'Zorbo bar');
      await h.openApp(tester);
      await h.goToList(tester);
      await h.tap(tester, find.text('Zorbo bar'));
      await deleteOpen(tester);
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Undo'), findsNothing);
      expect((await reload(tester, f.food.id)).food.archived, isTrue);
    });
  });

  group('logged meals', () {
    h.appTest('a logged meal is unchanged after its food is edited, and '
        'after it is deleted', (tester) async {
      final f = await makeFood(tester, 'Zorbo bar', barcode: code, kcal: 210);
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
              foodRef: 'local:${f.food.id}',
              foodName: 'Zorbo bar',
              quantity: 2,
              unitLabel: '',
              baseQuantity: 200,
              baseUnit: 'g',
              nutrients: const {Nutrients.energy: 420, Nutrients.protein: 8},
            ),
          ],
        ),
      );
      Future<StoredMeal> reread() async {
        final StoredMeal? m = await h.real(
          tester,
          () => h.db.loadMeal(logged.meal.id),
        );
        return m!;
      }

      await h.openApp(tester);
      await h.goToList(tester);
      await h.tap(tester, find.text('Zorbo bar'));
      await h.enter(tester, 'Name', 'Changed bar');
      await h.enter(tester, 'Calories', '999');
      await h.tap(tester, h.saveButton());
      var now = await reread();
      expect(now.entries.single.entry.foodName, 'Zorbo bar');
      expect(now.entries.single.entry.baseQuantity, 200);
      expect(now.totals, logged.totals);
      expect(now.totals[Nutrients.energy], 420);

      await h.tap(tester, find.text('Changed bar'));
      await deleteOpen(tester);
      now = await reread();
      expect(now.entries.single.entry.foodName, 'Zorbo bar');
      expect(now.entries.single.nutrients, logged.entries.single.nutrients);
      expect(now.totals, logged.totals);
    });
  });

  group('layout', () {
    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      h.appTest('the list at ${width.toInt()} dp and text scale $scale: no '
          'overflow, 48 dp rows and targets, a notice with Undo fits', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await makeFood(
          tester,
          'A food with a very long name that has to wrap onto lines',
          brand: 'A brand with a long name too',
        );
        await makeRecipe(tester, 'Turkey chili');
        await h.openApp(tester, size: Size(width, 800));
        await h.goToList(tester);
        expect(tester.takeException(), isNull);
        final rows = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(InkWell),
        );
        expect(rows, findsNWidgets(2));
        for (final r in rows.evaluate()) {
          expect(
            tester.getSize(find.byWidget(r.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        await h.tap(tester, find.text('Turkey chili'));
        await deleteOpen(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Undo'), findsOneWidget);
        expect(
          tester.getSize(find.text('Undo')).height,
          greaterThanOrEqualTo(0),
        );
        final undo = find.widgetWithText(TextButton, 'Undo');
        expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(undo).width, greaterThanOrEqualTo(48));
      });
    }
  });

  test('the screens exist', () {
    expect(const MyFoodsScreen(), isA<Widget>());
  });
}
