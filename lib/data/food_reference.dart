// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

// Read-only access to the bundled USDA reference database, built by
// tools/build_food_db.py. The user's own data lives in database.dart.

const _assetDb = 'assets/food/usda.sqlite.gz';
const _assetVersion = 'assets/food/usda_version.txt';

/// The FNDDS portion used as the default amount. It stays in the portion
/// table but is never offered as a choice.
const defaultPortionLabel = 'Quantity not specified';

const _fileName = 'usda.sqlite';
const _versionFileName = 'usda_version.txt';

/// Makes sure the USDA database is installed in [dir] (default: the app
/// support directory) and matches the version bundled in the assets.
/// Returns the path to the database file. The decompression runs off the UI
/// isolate and the file is renamed into place, so a crash never leaves a
/// half-written database.
Future<String> installFoodReference({
  Directory? dir,
  AssetBundle? bundle,
}) async {
  final target = dir ?? await getApplicationSupportDirectory();
  bundle ??= rootBundle;
  final dbPath = p.join(target.path, _fileName);
  final versionPath = p.join(target.path, _versionFileName);
  final bundled = (await bundle.loadString(_assetVersion)).trim();

  final versionFile = File(versionPath);
  if (versionFile.existsSync() &&
      versionFile.readAsStringSync().trim() == bundled &&
      _looksValid(dbPath)) {
    return dbPath;
  }

  await target.create(recursive: true);
  final gz = (await bundle.load(_assetDb)).buffer.asUint8List();
  final tmpPath = '$dbPath.tmp';
  await Isolate.run(
    () => File(tmpPath).writeAsBytesSync(gzip.decode(gz), flush: true),
  );
  File(tmpPath).renameSync(dbPath);
  File('$versionPath.tmp').writeAsStringSync(bundled, flush: true);
  File('$versionPath.tmp').renameSync(versionPath);
  return dbPath;
}

/// A cheap check that the installed file is a USDA database: it opens and
/// has the meta table.
bool _looksValid(String path) {
  if (!File(path).existsSync()) return false;
  try {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      db.select('SELECT 1 FROM meta LIMIT 1');
      return true;
    } finally {
      db.close();
    }
  } on SqliteException {
    return false;
  }
}

class UsdaPortion {
  const UsdaPortion(this.label, this.grams);
  final String label;
  final double grams;
}

class UsdaFood {
  const UsdaFood({
    required this.id,
    required this.description,
    required this.dataset,
    required this.category,
    required this.nutrients,
    required this.portions,
  });
  final int id;
  final String description;
  final String dataset;
  final String category;

  /// Amount per 100 g, keyed by USDA nutrient id.
  final Map<int, double> nutrients;
  final List<UsdaPortion> portions;
}

class FoodReference {
  /// Wraps an already opened database (a test can pass an in-memory one).
  FoodReference(this._db);

  /// Opens the installed file read-only.
  factory FoodReference.open(String path) =>
      FoodReference(sqlite3.open(path, mode: OpenMode.readOnly));

  final Database _db;

  UsdaFood? food(int fdcId) {
    final rows = _db.select(
      'SELECT description, dataset, category FROM food WHERE id = ?',
      [fdcId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final nutrients = <int, double>{
      for (final n in _db.select(
        'SELECT nutrient_id, amount FROM food_nutrient WHERE food_id = ?',
        [fdcId],
      ))
        n['nutrient_id'] as int: (n['amount'] as num).toDouble(),
    };
    final portions = [
      for (final q in _db.select(
        'SELECT label, gram_weight FROM food_portion WHERE food_id = ? ORDER BY seq',
        [fdcId],
      ))
        UsdaPortion(q['label'] as String, (q['gram_weight'] as num).toDouble()),
    ];
    return UsdaFood(
      id: fdcId,
      description: r['description'] as String,
      dataset: r['dataset'] as String,
      category: (r['category'] as String?) ?? '',
      nutrients: nutrients,
      portions: portions,
    );
  }

  void close() => _db.close();
}
