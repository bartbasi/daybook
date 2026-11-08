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
}
