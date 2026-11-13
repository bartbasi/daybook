// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:convert';
import 'dart:io';

import 'package:daybook/data/database.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/data/off_client.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _ua = 'Daybook/1.0.0 (test@example.com)';
const _code = '3017620422003';

OffClient _client(MockClient m) => OffClient(m, userAgent: _ua);

String _fixture() => File('test/fixtures/off_product.json').readAsStringSync();

void main() {
  test('found product maps names and converts units', () async {
    final client = _client(
      MockClient((_) async => http.Response(_fixture(), 200)),
    );
    final p = (await client.lookup(_code))!;
    expect(p.name, 'Nutella');
    expect(p.brand, 'Nutella, Ferrero');
    expect(p.baseUnit, 'g');
    expect(p.nutrients[Nutrients.energy], 539);
    expect(p.nutrients[Nutrients.protein], 6.3);
    expect(p.nutrients[Nutrients.saturatedFat], 10.6);
    // OFF gives 0.0428 g of sodium per 100 g, the app uses mg.
    expect(p.nutrients[Nutrients.sodium], closeTo(42.8, 1e-9));
    expect(p.rawNutrimentsJson, contains('salt_100g'));
  });

  test('micrograms, kJ fallback, ml and serving', () async {
    final body = jsonEncode({
      'status': 1,
      'product': {
        'code': _code,
        'product_name': 'Drink',
        'product_quantity_unit': 'ml',
        'serving_quantity': '250',
        'serving_size': '250 ml',
        'nutriments': {
          'energy_100g': 418.4,
          'vitamin-b12_100g': 0.0000024,
          'vitamin-c_100g': 0.08,
        },
      },
    });
    final p = (await _client(MockClient((_) async => http.Response(body, 200)))
        .lookup(_code))!;
    expect(p.baseUnit, 'ml');
    expect(p.nutrients[Nutrients.energy], closeTo(100, 1e-9));
    expect(p.nutrients[Nutrients.vitaminB12], closeTo(2.4, 1e-9));
    expect(p.nutrients[Nutrients.vitaminC], closeTo(80, 1e-9));
    expect(p.servingQuantity, 250);
    expect(p.servingLabel, '250 ml');
  });

  test('serving in another unit than the base unit is dropped', () async {
    OffClient c(String servingUnit) => _client(MockClient((_) async =>
        http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'product_name': 'Soup',
                'product_quantity_unit': 'g',
                'serving_quantity': 250,
                'serving_quantity_unit': servingUnit,
                'nutriments': {'energy-kcal_100g': 50},
              },
            }),
            200)));
    expect((await c('ml').lookup(_code))!.servingQuantity, isNull);
    expect((await c('g').lookup(_code))!.servingQuantity, 250);
  });

  test('a missing serving unit counts as the base unit', () async {
    final body = jsonEncode({
      'status': 1,
      'product': {
        'product_name': 'Soup',
        'serving_quantity': 30,
        'nutriments': {'energy-kcal_100g': 50},
      },
    });
    final p = await _client(MockClient((_) async => http.Response(body, 200)))
        .lookup(_code);
    expect(p!.servingQuantity, 30);
  });

  test('not found returns null', () async {
    expect(
      await _client(MockClient((_) async => http.Response('{"status":0}', 200)))
          .lookup(_code),
      isNull,
    );
    expect(
      await _client(MockClient((_) async => http.Response('', 404)))
          .lookup(_code),
      isNull,
    );
  });

  test('invalid barcode throws', () async {
    final client = _client(MockClient((_) async => http.Response('', 200)));
    for (final bad in ['123', 'abcdefgh', '123456789012345', '']) {
      expect(() => client.lookup(bad), throwsArgumentError);
    }
  });

  test('sends the User-Agent and requested fields', () async {
    late http.Request seen;
    final client = _client(
      MockClient((r) async {
        seen = r;
        return http.Response(_fixture(), 200);
      }),
    );
    await client.lookup(_code);
    expect(seen.headers['User-Agent'], _ua);
    expect(seen.url.path, '/api/v2/product/$_code.json');
    expect(seen.url.host, 'world.openfoodfacts.org');
    expect(seen.url.queryParameters['fields'], contains('nutriments'));
    expect(seen.url.queryParameters['fields'], contains('serving_quantity_unit'));
  });

  test('server error throws', () async {
    final client = _client(MockClient((_) async => http.Response('', 500)));
    expect(() => client.lookup(_code), throwsA(isA<OffException>()));
  });

  group('saveOffProduct', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    OffProduct product(String name, double kcal, {double? serving}) =>
        OffProduct(
          barcode: _code,
          name: name,
          brand: 'Ferrero',
          baseUnit: 'g',
          nutrients: {Nutrients.energy: kcal, Nutrients.protein: 6},
          servingQuantity: serving,
          servingLabel: '15 g',
          rawNutrimentsJson: '{}',
        );

    test(
      'inserts, then a second save updates instead of duplicating',
      () async {
        final id1 = await saveOffProduct(
          db,
          product('Nutella', 539, serving: 15),
        );
        var foods = await db.select(db.foods).get();
        expect(foods, hasLength(1));
        expect(foods.single.kind, 'off');
        expect(foods.single.baseAmount, 100);
        expect(await db.select(db.foodPortions).get(), hasLength(1));

        final id2 = await saveOffProduct(db, product('Nutella 2', 500));
        expect(id2, id1);
        foods = await db.select(db.foods).get();
        expect(foods, hasLength(1));
        expect(foods.single.name, 'Nutella 2');
        final nutrients = await db.select(db.foodNutrients).get();
        expect(nutrients, hasLength(2));
        expect(
          nutrients.firstWhere((n) => n.nutrientId == Nutrients.energy).amount,
          500,
        );
        expect(await db.select(db.foodPortions).get(), isEmpty);
      },
    );

    test('a custom food with the same barcode is left alone', () async {
      final custom = await db.into(db.foods).insert(FoodsCompanion.insert(
            kind: 'custom',
            name: 'My own',
            barcode: const Value(_code),
            baseAmount: 1,
            baseUnit: 'serving',
            createdAtMs: 1,
            updatedAtMs: 1,
          ));
      final id = await saveOffProduct(db, product('Nutella', 539, serving: 15));
      expect(id, custom);
      final foods = await db.select(db.foods).get();
      expect(foods, hasLength(1));
      expect(foods.single.kind, 'custom');
      expect(foods.single.name, 'My own');
      expect(foods.single.baseUnit, 'serving');
      expect(await db.select(db.foodNutrients).get(), isEmpty);
      expect(await db.select(db.foodPortions).get(), isEmpty);
    });

    test('an update keeps base amount and unit in step with the product',
        () async {
      await saveOffProduct(db, product('Drink', 40));
      final ml = OffProduct(
        barcode: _code,
        name: 'Drink',
        brand: null,
        baseUnit: 'ml',
        nutrients: {Nutrients.energy: 40},
        servingQuantity: null,
        servingLabel: null,
        rawNutrimentsJson: '{}',
      );
      await saveOffProduct(db, ml);
      final f = (await db.select(db.foods).get()).single;
      expect(f.kind, 'off');
      expect(f.baseAmount, 100);
      expect(f.baseUnit, 'ml');
    });
  });

  group('the form of a barcode', () {
    // The check digit of an 11 digit UPC-A body.
    String withCheck(String body) {
      var sum = 0, w = 3;
      for (var i = body.length - 1; i >= 0; i--) {
        sum += int.parse(body[i]) * w;
        w = w == 3 ? 1 : 3;
      }
      return '$body${(10 - sum % 10) % 10}';
    }

    test('a UPC-A is padded to 13 digits, an EAN-8 and an EAN-13 are not '
        'changed', () {
      expect(barcodeForm('049000028911'), '0049000028911');
      expect(barcodeForm('0049000028911'), '0049000028911');
      expect(barcodeForm('96385074'), '96385074');
      expect(barcodeForm('4006381333931'), '4006381333931');
      // A typed 8 digit number is an EAN-8, as typed.
      expect(barcodeForm('04252614'), '04252614');
    });

    test(
      'a 14 digit code that starts with 0 loses that 0, others are kept',
      () {
        expect(barcodeForm('00049000028911'), '0049000028911');
        expect(barcodeForm('10012345678902'), '10012345678902');
      },
    );

    test('a UPC-E code expands to its UPC-A, in all four zero rules', () {
      // The published example: UPC-E 04252614 is UPC-A 042100005264.
      expect(barcodeCheckOk('042100005264'), isTrue);
      expect(barcodeForm('04252614', upcE: true), '0042100005264');
      expect(barcodeForm('01234565', upcE: true), '0012345000065');
      expect(barcodeCheckOk('012345000065'), isTrue);
      // The other three rules: the last of the six digits is 3, 4 and 0.
      for (final (e6, a11) in [
        ('123453', '01230000045'),
        ('123454', '01234000005'),
        ('123450', '01200000345'),
      ]) {
        final upcA = withCheck(a11);
        final e = '0$e6${upcA[11]}';
        expect(barcodeForm(e, upcE: true), '0$upcA', reason: e);
      }
    });

    test('the check digit of typed numbers', () {
      for (final ok in [
        '96385074',
        '049000028911',
        '0049000028911',
        '4006381333931',
        '10012345678902',
      ]) {
        expect(barcodeCheckOk(ok), isTrue, reason: ok);
      }
      for (final bad in [
        '96385075',
        '049000028910',
        '4006381333932',
        '10012345678903',
        '123456789',
        '1234567890',
        '12345678901',
        '12ab5678',
      ]) {
        expect(barcodeCheckOk(bad), isFalse, reason: bad);
      }
    });
  });

  group('odd product data is left out', () {
    Future<OffProduct?> look(Map<String, Object?> nutriments) {
      final body = jsonEncode({
        'status': 1,
        'product': {'product_name': 'Odd', 'nutriments': nutriments},
      });
      return _client(MockClient((_) async => http.Response(body, 200)))
          .lookup(_code);
    }

    test('negative, huge, NaN and too many calories are absent', () async {
      final p = (await look({
        'energy-kcal_100g': -50,
        'proteins_100g': 1e9,
        'fat_100g': 'NaN',
        'carbohydrates_100g': 12,
        'fiber_100g': -1,
        'sodium_100g': 0.5,
      }))!;
      expect(p.nutrients.containsKey(Nutrients.energy), isFalse);
      expect(p.nutrients.containsKey(Nutrients.protein), isFalse);
      expect(p.nutrients.containsKey(Nutrients.fat), isFalse);
      expect(p.nutrients[Nutrients.carbs], 12);
      expect(p.nutrients.containsKey(Nutrients.fiber), isFalse);
      expect(p.nutrients[Nutrients.sodium], closeTo(500, 1e-9));
    });

    test('2500 kcal in 100 g is absent, 900 is kept, and kJ is checked '
        'after conversion', () async {
      expect(
        (await look({'energy-kcal_100g': 2500}))!.nutrients
            .containsKey(Nutrients.energy),
        isFalse,
      );
      expect(
        (await look({'energy-kcal_100g': 900}))!.nutrients[Nutrients.energy],
        900,
      );
      expect(
        (await look({'energy_100g': 4000}))!.nutrients
            .containsKey(Nutrients.energy),
        isFalse,
      );
      expect(
        (await look({'energy_100g': 418.4}))!.nutrients[Nutrients.energy],
        closeTo(100, 1e-9),
      );
    });
  });

  group('the limit of 100 on every nutrient but energy', () {
    Future<OffProduct?> look(Map<String, Object?> nutriments) {
      final body = jsonEncode({
        'status': 1,
        'product': {'product_name': 'Odd', 'nutriments': nutriments},
      });
      return _client(MockClient((_) async => http.Response(body, 200)))
          .lookup(_code);
    }

    test(
      'sodium 400 (milligrams in a grams field) is absent, 0.5 is 500 mg',
      () async {
        final p = (await look({'sodium_100g': 400, 'proteins_100g': 150}))!;
        expect(p.nutrients.containsKey(Nutrients.sodium), isFalse);
        expect(p.nutrients.containsKey(Nutrients.protein), isFalse);
        final ok = (await look({'sodium_100g': 0.5}))!;
        expect(ok.nutrients[Nutrients.sodium], closeTo(500, 1e-9));
      },
    );

    test('energy keeps its own limit', () async {
      expect(
        (await look({'energy-kcal_100g': 884}))!.nutrients[Nutrients.energy],
        884,
      );
      expect(
        (await look({'energy-kcal_100g': 2500}))!.nutrients
            .containsKey(Nutrients.energy),
        isFalse,
      );
    });
  });

  group('the stored food for a barcode', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> insert(String kind, {bool archived = false}) => db
        .into(db.foods)
        .insert(
          FoodsCompanion.insert(
            kind: kind,
            name: 'X',
            barcode: const Value(_code),
            baseAmount: 100,
            baseUnit: 'g',
            archived: Value(archived),
            createdAtMs: 1,
            updatedAtMs: 1,
          ),
        );

    test('nothing, an archived food, the own food and a cached '
        'product with and without a serving', () async {
      expect(await findFoodByBarcode(db, _code), isNull);
      final archived = await insert('custom', archived: true);
      expect(await findFoodByBarcode(db, _code), isNull);
      await (db.delete(db.foods)..where((f) => f.id.equals(archived))).go();

      final own = await insert('custom');
      expect(await findFoodByBarcode(db, _code), (id: own, serving: true));
      await (db.delete(db.foods)..where((f) => f.id.equals(own))).go();

      final off = await insert('off');
      expect(await findFoodByBarcode(db, _code), (id: off, serving: false));
      await db
          .into(db.foodPortions)
          .insert(
            FoodPortionsCompanion.insert(
              foodId: off,
              label: '1 pot',
              baseQuantity: 150,
            ),
          );
      expect(await findFoodByBarcode(db, _code), (id: off, serving: true));
    });

    test('saving a product again brings an archived cached row back', () async {
      final off = await insert('off', archived: true);
      final id = await saveOffProduct(
        db,
        OffProduct(
          barcode: _code,
          name: 'Nutella',
          brand: null,
          baseUnit: 'g',
          nutrients: {Nutrients.energy: 539},
          servingQuantity: null,
          servingLabel: null,
          rawNutrimentsJson: '{}',
        ),
      );
      expect(id, off);
      expect((await db.select(db.foods).get()).single.archived, isFalse);
    });
  });
}
