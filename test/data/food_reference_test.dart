// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';
import 'dart:typed_data';

import 'package:daybook/data/food_reference.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

Database _tiny() {
  final db = sqlite3.openInMemory();
  db.execute('''
CREATE TABLE food(id INTEGER PRIMARY KEY, dataset TEXT, description TEXT, category TEXT);
CREATE TABLE food_nutrient(food_id INTEGER, nutrient_id INTEGER, amount REAL,
  PRIMARY KEY(food_id, nutrient_id)) WITHOUT ROWID;
CREATE TABLE food_portion(food_id INTEGER, seq INTEGER, label TEXT, gram_weight REAL,
  PRIMARY KEY(food_id, seq)) WITHOUT ROWID;
INSERT INTO food VALUES (1, 'sr_legacy', 'Bread, white, toasted', 'Baked');
INSERT INTO food VALUES (2, 'sr_legacy', 'Toast, plain, with crust removed', 'Baked');
INSERT INTO food VALUES (3, 'fndds', 'Butter, 100% real', 'Dairy');
INSERT INTO food VALUES (4, 'fndds', 'Toasted bread', 'Baked');
INSERT INTO food VALUES (5, 'fndds', 'Snack_bar', 'Snacks');
INSERT INTO food VALUES (6, 'fndds', 'Path\\to', 'Odd');
INSERT INTO food_nutrient VALUES (1, 1008, 313), (1, 1003, 10.7);
INSERT INTO food_portion VALUES (1, 2, '1 cup', 100), (1, 1, '1 slice', 25);
''');
  return db;
}

void main() {
  test('food returns nutrients and portions in order', () {
    final ref = FoodReference(_tiny());
    final f = ref.food(1)!;
    expect(f.description, 'Bread, white, toasted');
    expect(f.dataset, 'sr_legacy');
    expect(f.category, 'Baked');
    expect(f.nutrients, {1008: 313.0, 1003: 10.7});
    expect(f.portions.map((p) => p.label), ['1 slice', '1 cup']);
    expect(f.portions.first.grams, 25);
    expect(ref.food(999), isNull);
    ref.close();
  });

  test('the built USDA database has well-known foods', () {
    final dir = Directory.systemTemp.createTempSync('daybook_usda');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    final ref = FoodReference.open(path);
    addTearDown(ref.close);

    // SR Legacy "Egg, whole, raw, fresh", values from food_nutrient.csv.
    final egg = ref.food(171287)!;
    expect(egg.description, 'Egg, whole, raw, fresh');
    expect(egg.dataset, 'sr_legacy');
    expect(egg.nutrients[1008], 143);
    expect(egg.nutrients[1003], 12.56);
    expect(egg.nutrients[1004], 9.51);
    expect(egg.portions.first.label, '1 large');
    expect(egg.portions.first.grams, 50);
    expect(egg.nutrients[1190], 47);

    // Foundation apple has only Atwater energy (2048 = 55.6, 2047 = 61.8).
    final apple = ref.food(1750339)!;
    expect(apple.dataset, 'foundation');
    expect(apple.nutrients[1008], 55.6);
    expect(apple.nutrients[1003], 0.188);

    // Enriched flour: SR Legacy lists DFE 291. Foundation 789890 lists total
    // folate 160 but no folic acid, so DFE must not be made up from it.
    expect(ref.food(168894)!.nutrients[1190], 291);
    final flour = ref.food(789890)!;
    expect(flour.nutrients[1177], 160);
    expect(flour.nutrients.containsKey(1190), isFalse);
  });

  test('FNDDS foods keep the default amount portion', () {
    final dir = Directory.systemTemp.createTempSync('daybook_usda');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    final ref = FoodReference.open(path);
    addTearDown(ref.close);

    void expectDefault(int id, double grams) {
      final match = ref
          .food(id)!
          .portions
          .where((p) => p.label == defaultPortionLabel);
      expect(match, hasLength(1), reason: 'usda:$id');
      expect(match.single.grams, grams, reason: 'usda:$id');
    }

    expectDefault(2707153, 50); // egg
    expectDefault(2710373, 360); // coffee
    expectDefault(2705594, 20); // half and half

    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(db.close);
    expect(db.select('SELECT COUNT(*) AS n FROM food').first['n'], 13598);
  });

  test('usda_version.txt changes with the asset content', () {
    final version = File('assets/food/usda_version.txt')
        .readAsStringSync()
        .trim();
    expect(version, isNot('2026-10-29-b4d69b0012dd000'));

    final gz = File('assets/food/usda.sqlite.gz').readAsBytesSync();
    // The gzip trailer holds the CRC-32 and the size of the uncompressed data.
    final t = ByteData.sublistView(gz, gz.length - 8);
    final crc = t.getUint32(0, Endian.little).toRadixString(16).padLeft(8, '0');
    final size = t.getUint32(4, Endian.little).toRadixString(16);
    expect(version, matches(RegExp(r'^\d{4}-\d{2}-\d{2}-[0-9a-f]+$')));
    expect(version, endsWith('-$crc$size'));
  });

  test('install decompresses the bundled asset once', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('daybook_install');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bundle = _FileBundle();
    final path = await installFoodReference(dir: dir, bundle: bundle);
    expect(File(path).existsSync(), isTrue);
    expect(File('$path.tmp').existsSync(), isFalse);
    final ref = FoodReference.open(path);
    expect(ref.food(171287), isNotNull);
    ref.close();

    // Same version: the file is left alone.
    final stamp = File(path).lastModifiedSync();
    await installFoodReference(dir: dir, bundle: bundle);
    expect(File(path).lastModifiedSync(), stamp);

    // A damaged file with a matching version is installed again.
    File(path).writeAsBytesSync(const []);
    await installFoodReference(dir: dir, bundle: bundle);
    final repaired = FoodReference.open(path);
    expect(repaired.food(171287), isNotNull);
    repaired.close();

    // A different installed version is replaced.
    File('${dir.path}/usda_version.txt').writeAsStringSync('old');
    File(path).writeAsStringSync('junk');
    await installFoodReference(dir: dir, bundle: bundle);
    final again = FoodReference.open(path);
    expect(again.food(171287), isNotNull);
    again.close();
  });
}

/// Serves the real asset files from disk.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(bytes);
  }
}
