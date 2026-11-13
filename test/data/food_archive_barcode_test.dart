// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// An archived food gives up its barcode, so a later scan finds nothing stale
// and a new food can use the number (task 2.12, item 6).

void main() {
  late AppDatabase db;
  final now = Now.fromLocal('2026-11-12', 7 * 60, 0);
  const code = '0123456789012';

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<FoodDetail> make(String name, {String? barcode}) =>
      db.createCustomFood(
        CustomFoodInput(
          name: name,
          basis: FoodBasis.per100g,
          nutrients: const {Nutrients.energy: 100},
          barcode: barcode,
        ),
        now,
      );

  test('archiving frees the barcode, and a new food can take it', () async {
    final a = await make('Zorbo', barcode: code);
    final archived = await db.archiveFood(a.food.id, now);
    expect(archived.food.archived, isTrue);
    expect(archived.food.barcode, isNull);
    final b = await make('Zorbo again', barcode: code);
    expect(b.food.barcode, code);
  });

  test('bringing it back with its barcode puts the barcode back', () async {
    final a = await make('Zorbo', barcode: code);
    await db.archiveFood(a.food.id, now);
    final back = await db.archiveFood(
      a.food.id,
      now,
      archived: false,
      restoreBarcode: code,
    );
    expect(back.food.archived, isFalse);
    expect(back.food.barcode, code);
  });

  test('the barcode stays off when another food took it meanwhile', () async {
    final a = await make('Zorbo', barcode: code);
    await db.archiveFood(a.food.id, now);
    final b = await make('Other', barcode: code);
    final back = await db.archiveFood(
      a.food.id,
      now,
      archived: false,
      restoreBarcode: code,
    );
    expect(back.food.archived, isFalse);
    expect(back.food.barcode, isNull);
    expect((await db.loadFood(b.food.id))!.food.barcode, code);
  });

  test('bringing it back with no barcode asked for leaves it off', () async {
    final a = await make('Zorbo', barcode: code);
    await db.archiveFood(a.food.id, now);
    final back = await db.archiveFood(a.food.id, now, archived: false);
    expect(back.food.barcode, isNull);
  });
}
