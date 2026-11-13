// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'database.dart';
import 'nutrients.dart';

// Open Food Facts barcode lookup. Data is ODbL: show "Data from Open Food
// Facts (ODbL)" next to scanned products. Never log barcodes or responses.

/// A barcode's one stored form, used for the request, the cache and the
/// search for a stored food: a UPC-E code (8 digits, only when the scanner
/// says it read UPC-E) is expanded to UPC-A, and a 12 digit UPC-A is padded to
/// 13 digits with a leading 0. Any other code, such as an EAN-8 or an EAN-13,
/// is returned as it is.
String barcodeForm(String code, {bool upcE = false}) {
  var c = code;
  if (upcE && c.length == 8) c = _upcEToUpcA(c);
  if (c.length == 12) c = '0$c';
  if (c.length == 14 && c.startsWith('0')) c = c.substring(1);
  return c;
}

/// True when [code] is an 8 digit number to be read as a UPC-E: it starts with
/// 0 or 1 and its UPC-A expansion has a good check digit. A code starting with
/// 0 is a UPC-E whether or not it also passes the EAN-8 check (more than half
/// of them do), so it is an EAN-8 only when the expansion fails. A code
/// starting with 1 is an EAN-8 first, and a UPC-E only when it is not a valid
/// EAN-8. Any other 8 digit code is an EAN-8. Submit a UPC-E with `upcE: true`.
bool isUpcE(String code) {
  if (!RegExp(r'^[01]\d{7}$').hasMatch(code)) return false;
  if (code.startsWith('1') && barcodeCheckOk(code)) return false;
  return barcodeCheckOk(barcodeForm(code, upcE: true).substring(1));
}

// The zero suppression rules of UPC-E: the last of the six digits says where
// the zeros go. The number system digit and the check digit are kept.
String _upcEToUpcA(String e) {
  final ns = e[0], d = e.substring(1, 7), check = e[7], last = d[5];
  final body = switch (last) {
    '0' || '1' || '2' => '${d.substring(0, 2)}${last}0000${d.substring(2, 5)}',
    '3' => '${d.substring(0, 3)}00000${d.substring(3, 5)}',
    '4' => '${d.substring(0, 4)}00000${d[4]}',
    _ => '${d.substring(0, 5)}0000$last',
  };
  return '$ns$body$check';
}

/// True when [code] has 8, 12, 13 or 14 digits and its last digit is the
/// standard mod 10 check digit of the others.
bool barcodeCheckOk(String code) {
  if (!RegExp(r'^\d+$').hasMatch(code) ||
      !const [8, 12, 13, 14].contains(code.length)) {
    return false;
  }
  var sum = 0, weight = 3;
  for (var i = code.length - 2; i >= 0; i--) {
    sum += int.parse(code[i]) * weight;
    weight = weight == 3 ? 1 : 3;
  }
  return (10 - sum % 10) % 10 == int.parse(code[code.length - 1]);
}

class OffException implements Exception {
  OffException(this.message);
  final String message;
  @override
  String toString() => 'OffException: $message';
}

class OffProduct {
  const OffProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.baseUnit,
    required this.nutrients,
    required this.servingQuantity,
    required this.servingLabel,
    required this.rawNutrimentsJson,
  });

  final String barcode;
  final String name;
  final String? brand;

  /// 'g' or 'ml'. Nutrients are per 100 of this unit.
  final String baseUnit;

  /// Per 100 g or ml, keyed by USDA nutrient id, in the units of
  /// [Nutrients.tracked] (kcal, g, mg, µg).
  final Map<int, double> nutrients;

  /// One serving in [baseUnit], if the product gives it.
  final double? servingQuantity;
  final String? servingLabel;

  /// The full nutriments map as JSON, kept so more can be shown later.
  final String rawNutrimentsJson;
}

class OffClient {
  OffClient(this._client, {required this.userAgent, Uri? baseUri})
    : _base = baseUri ?? Uri.parse('https://world.openfoodfacts.org');

  /// The client the app uses, over the phone's network. Made here so that
  /// this file stays the only one that imports package:http.
  factory OffClient.network({required String userAgent}) =>
      OffClient(http.Client(), userAgent: userAgent);

  final http.Client _client;
  final String userAgent;
  final Uri _base;

  static const _timeout = Duration(seconds: 10);

  /// Returns null when Open Food Facts does not know the barcode.
  Future<OffProduct?> lookup(String barcode) async {
    if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
      throw ArgumentError('A barcode is 8 to 14 digits');
    }
    final uri = _base.replace(
      path: '/api/v2/product/$barcode.json',
      queryParameters: {
        'fields':
            'code,product_name,brands,nutriments,serving_quantity,'
            'serving_size,serving_quantity_unit,product_quantity_unit',
      },
    );
    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(_timeout);
    } on TimeoutException {
      throw OffException('Open Food Facts did not answer in time');
    } on http.ClientException {
      throw OffException('Could not reach Open Food Facts');
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw OffException('Open Food Facts returned HTTP ${res.statusCode}');
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw OffException('Open Food Facts sent an unreadable answer');
    }
    final product = body['product'];
    if (body['status'] == 0 || product is! Map<String, dynamic>) return null;
    return _parse(barcode, product);
  }

  OffProduct _parse(String barcode, Map<String, dynamic> p) {
    final raw = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? {};
    final nutrients = <int, double>{};
    // A value that is not a number, is negative, or is more than 100 (grams in
    // 100 g, checked before any conversion; 900 kcal for energy) is wrong
    // data: it is left out, as if absent.
    for (final n in Nutrients.tracked) {
      final v = _num(raw['${n.offKey}_100g']);
      if (v == null) continue;
      if (n.id == Nutrients.energy) {
        if (v > _maxKcal) continue;
      } else if (v > 100) {
        continue;
      }
      nutrients[n.id] = v * _scale(n.unit);
    }
    // OFF stores every nutrient except energy in grams per 100 g.
    if (!nutrients.containsKey(Nutrients.energy)) {
      final kj = _num(raw['energy_100g']);
      if (kj != null && kj / 4.184 <= _maxKcal) {
        nutrients[Nutrients.energy] = kj / 4.184;
      }
    }
    final baseUnit = p['product_quantity_unit'] == 'ml' ? 'ml' : 'g';
    // A serving in another unit than the base unit cannot be used. A missing
    // serving unit is taken to be the base unit.
    final servingUnit = p['serving_quantity_unit'];
    final servingFits = servingUnit == null || servingUnit == baseUnit;
    final serving = servingFits ? _num(p['serving_quantity']) : null;
    final sizeText = (p['serving_size'] as String?)?.trim();
    final brand = (p['brands'] as String?)?.trim();
    final name = (p['product_name'] as String?)?.trim();
    return OffProduct(
      barcode: barcode,
      name: (name == null || name.isEmpty) ? barcode : name,
      brand: (brand == null || brand.isEmpty) ? null : brand,
      baseUnit: baseUnit,
      nutrients: nutrients,
      servingQuantity: (serving != null && serving > 0) ? serving : null,
      servingLabel: (sizeText == null || sizeText.isEmpty)
          ? '1 serving'
          : sizeText,
      rawNutrimentsJson: jsonEncode(raw),
    );
  }

  static const _maxKcal = 900;

  /// A number that is finite and at least 0, else null.
  static double? _num(Object? v) {
    final x = v is num
        ? v.toDouble()
        : (v is String ? double.tryParse(v) : null);
    return x != null && x.isFinite && x >= 0 ? x : null;
  }

  static double _scale(String unit) => switch (unit) {
    'mg' => 1000,
    'µg' => 1e6,
    _ => 1,
  };
}

/// The food stored with [barcode] (in its [barcodeForm]) that is not archived:
/// the user's own food or a cached product. [serving] is false only for a
/// cached product that has no serving size. Null when there is none.
Future<({int id, bool serving})?> findFoodByBarcode(
  AppDatabase db,
  String barcode,
) async {
  final f =
      await (db.select(
            db.foods,
          )..where((f) => f.barcode.equals(barcode) & f.archived.equals(false)))
          .getSingleOrNull();
  if (f == null) return null;
  if (f.kind != 'off') return (id: f.id, serving: true);
  final portion =
      await (db.select(db.foodPortions)
            ..where((p) => p.foodId.equals(f.id))
            ..limit(1))
          .getSingleOrNull();
  return (id: f.id, serving: portion != null);
}

/// Inserts or updates the cached product (matched by barcode). Returns the
/// food id. A food of another kind with the same barcode (the user's own) is
/// left untouched and its id returned.
Future<int> saveOffProduct(AppDatabase db, OffProduct p) {
  return db.transaction(() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (db.select(
      db.foods,
    )..where((f) => f.barcode.equals(p.barcode))).getSingleOrNull();
    final int id;
    if (existing == null) {
      id = await db
          .into(db.foods)
          .insert(
            FoodsCompanion.insert(
              kind: 'off',
              name: p.name,
              brand: Value(p.brand),
              barcode: Value(p.barcode),
              baseAmount: 100,
              baseUnit: p.baseUnit,
              sourceJson: Value(p.rawNutrimentsJson),
              createdAtMs: now,
              updatedAtMs: now,
            ),
          );
    } else if (existing.kind != 'off') {
      return existing.id;
    } else {
      id = existing.id;
      await (db.update(db.foods)..where((f) => f.id.equals(id))).write(
        FoodsCompanion(
          kind: const Value('off'),
          archived: const Value(false),
          baseAmount: const Value(100),
          name: Value(p.name),
          brand: Value(p.brand),
          baseUnit: Value(p.baseUnit),
          sourceJson: Value(p.rawNutrimentsJson),
          updatedAtMs: Value(now),
        ),
      );
      await (db.delete(
        db.foodNutrients,
      )..where((n) => n.foodId.equals(id))).go();
      await (db.delete(
        db.foodPortions,
      )..where((q) => q.foodId.equals(id))).go();
    }
    for (final e in p.nutrients.entries) {
      await db
          .into(db.foodNutrients)
          .insert(
            FoodNutrientsCompanion.insert(
              foodId: id,
              nutrientId: e.key,
              amount: e.value,
            ),
          );
    }
    if (p.servingQuantity != null) {
      await db
          .into(db.foodPortions)
          .insert(
            FoodPortionsCompanion.insert(
              foodId: id,
              label: p.servingLabel ?? '1 serving',
              baseQuantity: p.servingQuantity!,
            ),
          );
    }
    return id;
  });
}
