// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/screens/my_foods/food_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_foods_harness.dart';

// The custom food editor (task 2.12, food-editor frame 1), opened from More,
// My foods and recipes, over the real food data.

void main() {
  final h = MyFoodsHarness()..register();

  Future<List<Food>> foodRows(WidgetTester t) =>
      h.real(t, () => h.db.select(h.db.foods).get());

  Future<Map<int, double>> nutrientsOf(WidgetTester t, int id) async {
    final rows = await h.real(
      t,
      () => (h.db.select(
        h.db.foodNutrients,
      )..where((n) => n.foodId.equals(id))).get(),
    );
    return {for (final r in rows) r.nutrientId: r.amount};
  }

  Future<List<FoodPortion>> portionsOf(WidgetTester t, int id) => h.real(
    t,
    () => (h.db.select(
      h.db.foodPortions,
    )..where((p) => p.foodId.equals(id))).get(),
  );

  Future<void> newFood(WidgetTester t) async {
    await h.goToList(t);
    await h.tap(t, find.text('+ New'));
    await h.tap(t, find.text('New food').last);
    expect(find.byType(FoodEditor), findsOneWidget);
  }

  Future<void> pickUnit(WidgetTester t, String word) async {
    await h.tap(t, find.byWidgetPredicate((w) => w is DropdownButtonFormField));
    await h.tap(t, find.text(word).last);
  }

  Future<void> fill(
    WidgetTester t, {
    String name = 'Zorbo',
    String calories = '120',
  }) async {
    await h.enter(t, 'Name', name);
    await h.enter(t, 'Calories', calories);
  }

  String textOf(WidgetTester t, String label) =>
      t.widget<TextField>(h.field(label)).controller!.text;

  /// How many "not listed" hints can be seen (a field with a value keeps its
  /// hint in the tree, at no opacity).
  int notListed() => find.text('not listed').evaluate().where((e) {
    final o = e.findAncestorWidgetOfExactType<AnimatedOpacity>();
    return o == null || o.opacity == 1;
  }).length;

  const weightLabel = 'One serving weighs (optional)';
  const barcodeLabel = 'Barcode (optional)';

  group('required fields', () {
    h.appTest('name, amount and calories are each refused when empty, and '
        'nothing is written', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await h.tap(tester, h.saveButton());
      expect(find.byType(FoodEditor), findsOneWidget);
      expect(find.text('Give it a name.'), findsOneWidget);
      expect(find.text('Enter the calories.'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);

      await fill(tester, name: '', calories: '120');
      await h.tap(tester, h.saveButton());
      expect(find.text('Give it a name.'), findsOneWidget);
      expect(find.text('Enter the calories.'), findsNothing);
      expect(await foodRows(tester), isEmpty);

      await fill(tester, name: 'Zorbo', calories: '');
      await h.tap(tester, h.saveButton());
      expect(find.text('Give it a name.'), findsNothing);
      expect(find.text('Enter the calories.'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);

      await fill(tester);
      await h.enter(tester, 'Amount', '');
      await h.tap(tester, h.saveButton());
      expect(find.text('Enter an amount above 0.'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
      await h.enter(tester, 'Amount', '0');
      await h.tap(tester, h.saveButton());
      expect(find.text('Enter an amount above 0.'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
    });

    h.appTest('a name of only spaces counts as empty', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester, name: '   ');
      await h.tap(tester, h.saveButton());
      expect(find.text('Give it a name.'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
    });

    h.appTest('a value that is not a number is refused beside its field and '
        'nothing is written', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      await h.enter(tester, 'Protein', 'lots');
      await h.tap(tester, h.saveButton());
      expect(find.text('Enter a number, or leave it empty.'), findsOneWidget);
      await h.enter(tester, 'Protein', '-3');
      await h.tap(tester, h.saveButton());
      expect(find.text('Enter a number, or leave it empty.'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
    });

    h.appTest('a bad value under More nutrients opens that part and says so', (
      tester,
    ) async {
      await h.openApp(tester);
      await newFood(tester);
      await h.tap(tester, find.text('More nutrients'));
      await h.enter(tester, 'Fiber', 'x');
      await h.tap(tester, find.text('More nutrients'));
      expect(h.field('Fiber'), findsNothing);
      await fill(tester);
      await h.tap(tester, h.saveButton());
      expect(h.field('Fiber'), findsOneWidget);
      expect(find.text('Enter a number, or leave it empty.'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
    });
  });

  group('not listed and zero', () {
    h.appTest('an empty nutrient is stored as absent and shown not listed; a '
        'typed 0 is stored and shown as 0', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      expect(notListed(), 3);
      await fill(tester);
      await h.enter(tester, 'Protein', '0');
      await h.enter(tester, 'Fat', '4.5');
      await h.tap(tester, h.saveButton());
      expect(find.byType(FoodEditor), findsNothing);
      final food = (await foodRows(tester)).single;
      expect(await nutrientsOf(tester, food.id), {
        Nutrients.energy: 120,
        Nutrients.protein: 0,
        Nutrients.fat: 4.5,
      });

      await h.tap(tester, find.text('Zorbo'));
      expect(textOf(tester, 'Protein'), '0');
      expect(textOf(tester, 'Carbs'), '');
      expect(notListed(), 1);
      await h.tap(tester, find.text('More nutrients'));
      expect(notListed(), 21);
      expect(textOf(tester, 'Fiber'), '');
    });

    h.appTest('a nutrient under More nutrients is stored, and the row says '
        'how many there are', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      expect(
        find.text('Fiber, sugar, sodium and 17 more. Optional.'),
        findsOneWidget,
      );
      await h.tap(tester, find.text('More nutrients'));
      await h.enter(tester, 'Sodium', '350');
      await fill(tester);
      await h.tap(tester, h.saveButton());
      final food = (await foodRows(tester)).single;
      expect((await nutrientsOf(tester, food.id))[Nutrients.sodium], 350);
    });
  });

  group('the amount', () {
    h.appTest('per serving, no weight: base 1 serving, values as typed', (
      tester,
    ) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester, calories: '150');
      await h.enter(tester, 'Protein', '5');
      await h.tap(tester, h.saveButton());
      final f = (await foodRows(tester)).single;
      expect((f.baseAmount, f.baseUnit), (1.0, 'serving'));
      expect(await nutrientsOf(tester, f.id), {
        Nutrients.energy: 150,
        Nutrients.protein: 5,
      });
      expect(await portionsOf(tester, f.id), isEmpty);
    });

    h.appTest('per serving with a weight: grams, with a 1 serving portion', (
      tester,
    ) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester, calories: '150');
      await h.enter(tester, weightLabel, '30');
      await h.tap(tester, h.saveButton());
      final f = (await foodRows(tester)).single;
      expect((f.baseAmount, f.baseUnit), (30.0, 'g'));
      expect(await nutrientsOf(tester, f.id), {Nutrients.energy: 150});
      final p = (await portionsOf(tester, f.id)).single;
      expect((p.label, p.baseQuantity), ('1 serving', 30.0));
    });

    h.appTest('per 100 g: base 100 g, values as typed', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await pickUnit(tester, 'grams');
      expect(textOf(tester, 'Amount'), '100');
      await fill(tester, calories: '250');
      await h.enter(tester, 'Carbs', '40');
      await h.tap(tester, h.saveButton());
      final f = (await foodRows(tester)).single;
      expect((f.baseAmount, f.baseUnit), (100.0, 'g'));
      expect(await nutrientsOf(tester, f.id), {
        Nutrients.energy: 250,
        Nutrients.carbs: 40,
      });
    });

    h.appTest('per 100 ml: base 100 ml, values as typed', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await pickUnit(tester, 'milliliters');
      await fill(tester, calories: '42');
      await h.tap(tester, h.saveButton());
      final f = (await foodRows(tester)).single;
      expect((f.baseAmount, f.baseUnit), (100.0, 'ml'));
      expect(await nutrientsOf(tester, f.id), {Nutrients.energy: 42});
    });

    h.appTest('values for another amount are worked out per 100 g', (
      tester,
    ) async {
      await h.openApp(tester);
      await newFood(tester);
      await pickUnit(tester, 'grams');
      await h.enter(tester, 'Amount', '50');
      await fill(tester, calories: '90');
      await h.tap(tester, h.saveButton());
      final f = (await foodRows(tester)).single;
      expect((f.baseAmount, f.baseUnit), (100.0, 'g'));
      expect((await nutrientsOf(tester, f.id))[Nutrients.energy], 180);
    });

    h.appTest('a decimal comma is read as a point', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester, calories: '12,5');
      await h.enter(tester, 'Protein', '1,25');
      await h.tap(tester, h.saveButton());
      final f = (await foodRows(tester)).single;
      expect(await nutrientsOf(tester, f.id), {
        Nutrients.energy: 12.5,
        Nutrients.protein: 1.25,
      });
    });

    h.appTest('a portion is stored with its weight', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await pickUnit(tester, 'grams');
      await fill(tester);
      expect(find.text('None yet.'), findsOneWidget);
      await h.tap(tester, find.text('+ Add'));
      await h.enter(tester, 'Portion name', 'cookie');
      await h.enter(tester, 'Weight', '15');
      await h.tap(tester, h.saveButton());
      final f = (await foodRows(tester)).single;
      final p = (await portionsOf(tester, f.id)).single;
      expect((p.label, p.baseQuantity), ('1 cookie', 15.0));
    });

    h.appTest('a portion with no weight is refused and nothing is written; '
        'with no serving weight portions are not offered', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      expect(find.text('+ Add'), findsNothing);
      expect(
        find.text('Give the weight of one serving above to use portions.'),
        findsOneWidget,
      );
      await h.enter(tester, weightLabel, '20');
      await h.tap(tester, find.text('+ Add'));
      await h.enter(tester, 'Portion name', 'cookie');
      await h.tap(tester, h.saveButton());
      expect(
        find.text('Give each portion a name and a weight above 0.'),
        findsOneWidget,
      );
      expect(await foodRows(tester), isEmpty);
    });
  });

  group('the barcode', () {
    h.appTest('is stored in its one form, a 12 digit code with a leading 0', (
      tester,
    ) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      await h.enter(tester, barcodeLabel, '036000291452');
      await h.tap(tester, h.saveButton());
      expect((await foodRows(tester)).single.barcode, '0036000291452');
    });

    h.appTest('a code whose check digit is wrong is refused in plain words', (
      tester,
    ) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      await h.enter(tester, barcodeLabel, '036000291453');
      await h.tap(tester, h.saveButton());
      expect(
        find.text(
          'That barcode does not look right. Check the digits under the '
          'barcode.',
        ),
        findsOneWidget,
      );
      await h.enter(tester, barcodeLabel, '12ab');
      await h.tap(tester, h.saveButton());
      expect(find.textContaining('does not look right'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
    });

    h.appTest('a barcode another food has is refused; an empty one is fine, '
        'twice', (tester) async {
      await h.real(
        tester,
        () => h.db.createCustomFood(
          const CustomFoodInput(
            name: 'Other',
            basis: FoodBasis.per100g,
            nutrients: {Nutrients.energy: 1},
            barcode: '0036000291452',
          ),
          nowFixed,
        ),
      );
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      await h.enter(tester, barcodeLabel, '036000291452');
      await h.tap(tester, h.saveButton());
      expect(
        find.text('Another food already has this barcode.'),
        findsOneWidget,
      );
      expect(await foodRows(tester), hasLength(1));
      await h.enter(tester, barcodeLabel, '');
      await h.tap(tester, h.saveButton());
      expect(await foodRows(tester), hasLength(2));
      await h.tap(tester, find.text('+ New'));
      await h.tap(tester, find.text('New food').last);
      await fill(tester, name: 'Third');
      await h.tap(tester, h.saveButton());
      expect(await foodRows(tester), hasLength(3));
    });

    h.appTest('editing a food that has a barcode keeps it', (tester) async {
      final a = await h.real(
        tester,
        () => h.db.createCustomFood(
          const CustomFoodInput(
            name: 'Alpha',
            basis: FoodBasis.per100g,
            nutrients: {Nutrients.energy: 1},
            barcode: '0036000291452',
          ),
          nowFixed,
        ),
      );
      await h.openApp(tester);
      await h.goToList(tester);
      await h.tap(tester, find.text('Alpha'));
      expect(textOf(tester, barcodeLabel), '0036000291452');
      await h.enter(tester, 'Calories', '7');
      await h.tap(tester, h.saveButton());
      expect(find.byType(FoodEditor), findsNothing);
      final d = await h.real(tester, () => h.db.loadFood(a.food.id));
      expect(d!.food.barcode, '0036000291452');
      expect(d.nutrients[Nutrients.energy], 7);
    });
  });

  group('editing and leaving', () {
    h.appTest('a saved food opens with its values; a change is written and '
        'read back, with the list saying so', (tester) async {
      final a = await h.real(
        tester,
        () => h.db.createCustomFood(
          const CustomFoodInput(
            name: 'Granola',
            brand: 'Mill',
            basis: FoodBasis.per100g,
            nutrients: {Nutrients.energy: 450, Nutrients.protein: 10},
            servingSize: 40,
          ),
          nowFixed,
        ),
      );
      await h.openApp(tester);
      await h.goToList(tester);
      await h.tap(tester, find.text('Granola'));
      expect(textOf(tester, 'Name'), 'Granola');
      expect(textOf(tester, 'Brand (optional)'), 'Mill');
      expect(textOf(tester, 'Amount'), '100');
      expect(textOf(tester, 'Calories'), '450');
      expect(textOf(tester, weightLabel), '40');
      await h.enter(tester, 'Name', '  Granola mix ');
      await h.tap(tester, h.saveButton());
      expect(find.byType(FoodEditor), findsNothing);
      expect(find.text('"Granola mix" saved.'), findsOneWidget);
      final d = await h.real(tester, () => h.db.loadFood(a.food.id));
      expect(d!.food.name, 'Granola mix');
      expect(d.food.brand, 'Mill');
      expect(d.servingSize, 40);
      expect(d.nutrients, {Nutrients.energy: 450, Nutrients.protein: 10});
    });

    h.appTest('Back without saving writes nothing', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      await tester.pageBack();
      await settle(tester);
      expect(find.byType(FoodEditor), findsNothing);
      expect(await foodRows(tester), isEmpty);
    });

    h.appTest('a second tap on Save while it writes writes once, and a route '
        'that took the top is not what closes', (tester) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      h.gate.hold = Completer<void>();
      await tester.tap(h.saveButton());
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(h.saveButton()).onPressed, isNull);
      await tester.tap(h.saveButton(), warnIfMissed: false);
      Navigator.of(tester.element(find.byType(FoodEditor))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('on top')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      h.gate.hold!.complete();
      h.gate.hold = null;
      await settle(tester);
      expect(find.byType(FoodEditor), findsNothing);
      expect(find.text('on top'), findsOneWidget);
      expect(await foodRows(tester), hasLength(1));
    });

    h.appTest('a failing write keeps the editor and the typing, and says so', (
      tester,
    ) async {
      await h.openApp(tester);
      await newFood(tester);
      await fill(tester);
      h.gate.failInsert = true;
      await h.tap(tester, h.saveButton());
      expect(find.byType(FoodEditor), findsOneWidget);
      expect(
        find.text('Could not save. Nothing was changed. Try again.'),
        findsOneWidget,
      );
      expect(textOf(tester, 'Name'), 'Zorbo');
      h.gate.failInsert = false;
      await h.tap(tester, h.saveButton());
      expect(find.byType(FoodEditor), findsNothing);
      expect(await foodRows(tester), hasLength(1));
    });
  });

  group('layout', () {
    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      h.appTest('at ${width.toInt()} dp and text scale $scale with the '
          'keyboard up: no overflow, 48 dp targets, Save in view', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await h.openApp(tester, size: Size(width, 800));
        await newFood(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await fill(tester, name: 'A very long food name to see how it wraps');
        await h.enter(tester, 'Protein', 'lots and lots of words here');
        await h.tap(tester, h.saveButton());
        expect(tester.takeException(), isNull);
        final save = tester.getRect(h.saveButton());
        expect(save.bottom, lessThanOrEqualTo(500.5));
        expect(save.height, greaterThanOrEqualTo(48));
        expect(find.text('Enter a number, or leave it empty.'), findsOneWidget);
        await h.tap(tester, find.text('More nutrients'));
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -3000),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final b in find.byType(ListTile).evaluate()) {
          expect(
            tester.getSize(find.byWidget(b.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
      });
    }
  });

  test('parseFoodNumber reads a point or a comma and nothing else', () {
    expect(parseFoodNumber('12'), 12);
    expect(parseFoodNumber(' 1,5 '), 1.5);
    expect(parseFoodNumber('.5'), 0.5);
    expect(parseFoodNumber(''), isNull);
    expect(parseFoodNumber('-1'), isNull);
    expect(parseFoodNumber('1e3'), isNull);
    expect(parseFoodNumber('1.2.3'), isNull);
    expect(parseFoodNumber('999999999'), isNull);
  });
}
