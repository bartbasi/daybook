// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/export_import.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 8, 12, 30, 15);

// One or two rows for every table, with awkward values. Written as SQL so the
// test does not depend on the generated classes.
const _awkward = 'Café 日本 🍙, "quoted"\r\nsecond line\nthird';
final _fixture = <(String, List<Object?>)>[
  (
    'INSERT INTO foods VALUES (?,?,?,?,?,?,?,?,?,?,?)',
    [
      1,
      'custom',
      _awkward,
      null,
      null,
      81.82708,
      'g',
      null,
      0,
      1786000000123,
      1786000000124,
    ],
  ),
  (
    'INSERT INTO foods VALUES (?,?,?,?,?,?,?,?,?,?,?)',
    [
      2,
      'off',
      '',
      'Brand, Inc.',
      '0123456789012',
      0.1,
      'ml',
      '{"a":1,"b":"x,y"}',
      1,
      0,
      4102444800000,
    ],
  ),
  ('INSERT INTO food_nutrients VALUES (?,?,?)', [1, 1008, 81.82708]),
  ('INSERT INTO food_nutrients VALUES (?,?,?)', [2, 1003, 0.1]),
  ('INSERT INTO food_portions VALUES (?,?,?,?)', [1, 1, 'slice, "thin"', 30.5]),
  (
    'INSERT INTO recipe_ingredients VALUES (?,?,?,?,?,?,?,?,?)',
    [1, 1, 0, 'usda:1', 'Egg é', 2.0, 'each', 100.1, 'g'],
  ),
  ('INSERT INTO meal_slots VALUES (?,?,?,?)', [5, 'Late 夜', 4, 1]),
  ('INSERT INTO meal_slot_rules VALUES (?,?)', [300, 5]),
  (
    'INSERT INTO meals VALUES (?,?,?,?,?,?)',
    [1, '2026-11-08', 1, 1786000000123, -360, 'two eggs, "toast"\r\n'],
  ),
  (
    'INSERT INTO meals VALUES (?,?,?,?,?,?)',
    [2, '2026-11-09', 5, 1786000000999, 540, null],
  ),
  (
    'INSERT INTO meal_entries VALUES (?,?,?,?,?,?,?,?,?)',
    [1, 1, 0, 'usda:1', 'Egg', 2, 'each', 100.1, 'g'],
  ),
  ('INSERT INTO meal_entry_nutrients VALUES (?,?,?)', [1, 1008, 0.1]),
  ('INSERT INTO saved_meals VALUES (?,?,?)', [1, 'Usual 🍳', 1786000000000]),
  (
    'INSERT INTO saved_meal_items VALUES (?,?,?,?,?,?,?,?,?)',
    [1, 1, 0, 'local:1', 'Café', 1, 'cup', 240.0, 'ml'],
  ),
  ('INSERT INTO saved_meal_item_nutrients VALUES (?,?,?)', [1, 1008, 2.5]),
  ('INSERT INTO aliases VALUES (?,?,?)', [1, 'usual breakfast', 1]),
  (
    'INSERT INTO learned_matches VALUES (?,?,?,?,?,?,?)',
    ['toast', 'usda:2', 'Bread', null, null, 3, 1786000000000],
  ),
  (
    'INSERT INTO learned_matches VALUES (?,?,?,?,?,?,?)',
    ['pb, "j"', 'local:1', 'Café', 'tbsp', 0.5, 1, 1786000000001],
  ),
  (
    'INSERT INTO weight_entries VALUES (?,?,?,?,?,?,?,?,?,?)',
    [
      1,
      '2026-11-08',
      1786000000123,
      -360,
      81.82708,
      'manual',
      null,
      1,
      2,
      null,
    ],
  ),
  (
    'INSERT INTO weight_entries VALUES (?,?,?,?,?,?,?,?,?,?)',
    [
      2,
      '2026-11-09',
      1786000000456,
      -360,
      0.1,
      'health_connect',
      'abc-123',
      1,
      2,
      1786000009999,
    ],
  ),
  (
    'INSERT INTO exercises VALUES (?,?,?,?,?,?,?)',
    [1, 'Bench 日本', null, 'chest', '', null, 0],
  ),
  ('INSERT INTO routines VALUES (?,?,?,?,?)', [1, 'Push', 0, 0, 1786000000000]),
  (
    'INSERT INTO routine_exercises VALUES (?,?,?,?,?,?,?)',
    [1, 1, 0, 'local:1', 'Bench', 3, null],
  ),
  (
    'INSERT INTO workouts VALUES (?,?,?,?,?,?,?,?,?)',
    [
      1,
      '2026-11-08',
      1786000000000,
      null,
      -360,
      1,
      250.5,
      null,
      'felt "good", strong\n',
    ],
  ),
  (
    'INSERT INTO workout_sets VALUES (?,?,?,?,?,?,?,?)',
    [1, 1, 0, 'local:1', 'Bench', 60.25, 8, 1786000000500],
  ),
  (
    'INSERT INTO workout_sets VALUES (?,?,?,?,?,?,?,?)',
    [2, 1, 1, 'local:1', 'Bench', null, null, null],
  ),
  (
    'INSERT INTO cardio_sessions VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
    [
      1,
      '2026-11-08',
      1786000000000,
      -360,
      '01015',
      'Running',
      9.8,
      1800,
      5000.5,
      150,
      400.0,
      null,
      'manual',
      null,
      1786000009999,
    ],
  ),
  ('INSERT INTO profile VALUES (?,?,?,?)', [1, 'male', '1980-01-31', 180.5]),
  (
    'INSERT INTO goals VALUES (?,?,?,?,?,?,?,?,?,?,?)',
    [
      1,
      '2026-01-01',
      'calculated',
      null,
      1.375,
      -0.5,
      100,
      'grams',
      150.0,
      200.0,
      null,
    ],
  ),
  ('INSERT INTO goal_nutrients VALUES (?,?,?)', [1, 1079, 30.0]),
  ('INSERT INTO settings VALUES (?,?)', ['note', 'a,b "c"\r\nd']),
];

AppDatabase _newDb() => AppDatabase(NativeDatabase.memory());

Future<void> _fill(AppDatabase db) async {
  for (final (sql, args) in _fixture) {
    await db.customStatement(sql, args);
  }
}

/// Every table's rows as stored, as one JSON string so types are compared too.
Future<String> _snapshot(AppDatabase db) async {
  final out = <String, Object?>{};
  for (final t in db.allTables) {
    final name = t.actualTableName;
    final rows = await db
        .customSelect('SELECT * FROM "$name" ORDER BY rowid')
        .get();
    out[name] = [for (final r in rows) r.data];
  }
  return jsonEncode(out);
}

List<int> _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, t) => a.add(ArchiveFile.bytes(n, utf8.encode(t))));
  return ZipEncoder().encode(a);
}

/// Names of every table in the schema, set in setUp.
List<String> _tableNames = [];

/// A valid export document. [tables] overrides the rows of some tables, the
/// rest are present and empty, as in a real export.
Map<String, Object?> _doc({
  Object? format = 'daybook-export',
  Object? formatVersion = 1,
  Object? schemaVersion = 1,
  Object? tables = const <String, Object?>{},
  bool fillMissing = true,
}) => {
  'format': format,
  'formatVersion': formatVersion,
  'schemaVersion': schemaVersion,
  'tables': tables is Map<String, Object?> && fillMissing
      ? {for (final n in _tableNames) n: <Object?>[], ...tables}
      : tables,
};

List<int> _docZip(Map<String, Object?> doc) =>
    _zip({'daybook.json': jsonEncode(doc)});

String _text(Archive a, String name) => utf8.decode(a.findFile(name)!.content);

Map<String, Object?> _food(int id, {String name = 'n', String? barcode}) => {
  'id': id,
  'kind': 'off',
  'name': name,
  'barcode': barcode,
  'base_amount': 100,
  'base_unit': 'g',
  'created_at_ms': 1,
  'updated_at_ms': 1,
};

Map<String, Object?> _weight({
  Object? localDate = '2026-01-01',
  Object? measuredAtMs = 5,
  Object? weightKg = 70.5,
}) => {
  'local_date': localDate,
  'measured_at_ms': measuredAtMs,
  'tz_offset_minutes': 0,
  'weight_kg': weightKg,
  'created_at_ms': 5,
  'updated_at_ms': 5,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = _newDb();
    _tableNames = [for (final t in db.allTables) t.actualTableName];
  });
  tearDown(() => db.close());

  test('the fixture has rows in every table', () async {
    await _fill(db);
    for (final t in db.allTables) {
      final n = await db
          .customSelect('SELECT count(*) AS n FROM "${t.actualTableName}"')
          .getSingle();
      expect(
        n.read<int>('n'),
        greaterThan(0),
        reason: 'add a row for ${t.actualTableName} to the round trip fixture',
      );
    }
  });

  group('round trip', () {
    test('every table comes back identical', () async {
      await _fill(db);
      final before = await _snapshot(db);
      final bytes = await exportArchive(db, now: _now, appVersion: '1.2.3');

      final fresh = _newDb();
      addTearDown(fresh.close);
      await importArchive(fresh, bytes);

      expect(await _snapshot(fresh), before);
      // Spot check the awkward values survived with the right types.
      final food = await fresh
          .customSelect('SELECT * FROM foods WHERE id = 1')
          .getSingle();
      expect(food.data['name'], _awkward);
      expect(food.data['base_amount'], 81.82708);
      expect(food.data['updated_at_ms'], 1786000000124);
      expect(food.data['brand'], isNull);
    });

    test(
      'the imported database still enforces foreign keys and cascades',
      () async {
        await _fill(db);
        final bytes = await exportArchive(db, now: _now, appVersion: '1');
        final fresh = _newDb();
        addTearDown(fresh.close);
        await importArchive(fresh, bytes);
        await fresh.customStatement('DELETE FROM foods WHERE id = 1');
        final left = await fresh
            .customSelect('SELECT count(*) AS n FROM food_nutrients')
            .getSingle();
        expect(left.read<int>('n'), 1);
        // New rows continue after the imported ids.
        await fresh.customStatement(
          "INSERT INTO saved_meals (name, created_at_ms) VALUES ('x', 1)",
        );
        final id = await fresh
            .customSelect('SELECT max(id) AS m FROM saved_meals')
            .getSingle();
        expect(id.read<int>('m'), 2);
      },
    );

    test('a database with only the defaults round trips', () async {
      final before = await _snapshot(db);
      final bytes = await exportArchive(db, now: _now, appVersion: '1');
      final fresh = _newDb();
      addTearDown(fresh.close);
      await importArchive(fresh, bytes);
      expect(await _snapshot(fresh), before);
    });
  });

  test('import replaces existing data, it does not merge', () async {
    await _fill(db);
    final bytes = await exportArchive(db, now: _now, appVersion: '1');

    final other = _newDb();
    addTearDown(other.close);
    await other.customStatement(
      "INSERT INTO foods VALUES (77,'custom','Only here',NULL,NULL,100,'g',NULL,0,1,1)",
    );
    await other.customStatement("INSERT INTO settings VALUES ('extra','yes')");
    await importArchive(other, bytes);

    expect(await _snapshot(other), await _snapshot(db));
    expect(
      await other.customSelect('SELECT * FROM foods WHERE id = 77').get(),
      isEmpty,
    );
  });

  test('columns missing from a row get the column default', () async {
    await _fill(db);
    await importArchive(
      db,
      _docZip(
        _doc(
          tables: {
            'weight_entries': [_weight()],
          },
        ),
      ),
    );
    for (final t in db.allTables) {
      final n = await db
          .customSelect('SELECT count(*) AS n FROM "${t.actualTableName}"')
          .getSingle();
      expect(
        n.read<int>('n'),
        t.actualTableName == 'weight_entries' ? 1 : 0,
        reason: t.actualTableName,
      );
    }
    final w = await db.customSelect('SELECT * FROM weight_entries').getSingle();
    expect(w.data['source'], 'manual');
    expect(w.data['id'], isNotNull);
  });

  test('the v1 golden file still imports and reads back', () async {
    await _fill(db);
    final json = File('test/fixtures/daybook_export_v1.json')
        .readAsStringSync();
    await importArchive(db, _zip({'daybook.json': json}));

    final slots = await db.select(db.mealSlots).get();
    expect(slots.single.name, 'Breakfast');
    final units = await (db.select(
      db.settings,
    )..where((s) => s.key.equals('units'))).getSingle();
    expect(units.value, 'metric');
    final w = await db.select(db.weightEntries).getSingle();
    expect(w.weightKg, 81.5);
    expect(w.localDate, '2026-01-02');
    expect(w.tzOffsetMinutes, -360);
    expect(w.deletedAtMs, isNull);
    final food = await db.select(db.foods).getSingle();
    expect(food.name, 'Oats');
    expect(food.baseAmount, 100.0);
    final n = await db.select(db.foodNutrients).getSingle();
    expect((n.nutrientId, n.amount), (1008, 389.0));
    expect(await db.select(db.meals).get(), isEmpty);
  });

  test('stream queries see the imported data', () async {
    final bytes = await exportArchive(db, now: _now, appVersion: '1');
    final other = _newDb();
    addTearDown(other.close);
    await other.customStatement("UPDATE meal_slots SET name = 'Old'");
    final seen = <List<String>>[];
    final sub = other
        .select(other.mealSlots)
        .watch()
        .listen((rows) => seen.add([for (final r in rows) r.name]));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await importArchive(other, bytes);
    await pumpEventQueue();
    expect(seen.last, ['Breakfast', 'Lunch', 'Dinner', 'Snack']);
  });

  test('non-finite numbers are exported as null, not as a failure', () async {
    await db.customStatement(
      'INSERT INTO profile (id, height_cm) VALUES (1, 1e999)',
    );
    final inf = await db
        .customSelect('SELECT height_cm FROM profile')
        .getSingle();
    expect(inf.data['height_cm'], double.infinity);
    final bytes = await exportArchive(db, now: _now, appVersion: '1');
    final json = jsonDecode(
      _text(ZipDecoder().decodeBytes(bytes), 'daybook.json'),
    ) as Map<String, dynamic>;
    final rows = (json['tables'] as Map)['profile'] as List;
    expect((rows.single as Map)['height_cm'], isNull);
  });

  group('rejects bad files and leaves the data unchanged', () {
    final cases = <String, List<int> Function()>{
      'not a zip': () => utf8.encode('this is just text, not a zip file'),
      'empty bytes': () => <int>[],
      'zip without daybook.json': () => _zip({'other.json': '{}'}),
      'bad JSON': () => _zip({'daybook.json': '{"format": '}),
      'JSON that is not an object': () => _zip({'daybook.json': '[1,2]'}),
      'wrong format string': () => _docZip(_doc(format: 'something-else')),
      'formatVersion 2': () => _docZip(_doc(formatVersion: 2)),
      'newer schemaVersion': () => _docZip(_doc(schemaVersion: 2)),
      'schemaVersion not a number': () => _docZip(_doc(schemaVersion: 'one')),
      'tables is not an object': () => _docZip(_doc(tables: [])),
      'unknown table': () => _docZip(_doc(tables: {'secrets': []})),
      'unknown column': () => _docZip(
        _doc(
          tables: {
            'settings': [
              {'key': 'a', 'value': 'b', 'extra': 1},
            ],
          },
        ),
      ),
      'table is not a list': () => _docZip(_doc(tables: {'settings': {}})),
      'row is not an object': () => _docZip(
        _doc(
          tables: {
            'settings': [5],
          },
        ),
      ),
      'list value': () => _docZip(
        _doc(
          tables: {
            'settings': [
              {
                'key': 'a',
                'value': [1],
              },
            ],
          },
        ),
      ),
      'object value': () => _docZip(
        _doc(
          tables: {
            'settings': [
              {
                'key': 'a',
                'value': {'x': 1},
              },
            ],
          },
        ),
      ),
      'boolean value': () => _docZip(
        _doc(
          tables: {
            'settings': [
              {'key': 'a', 'value': true},
            ],
          },
        ),
      ),
      'missing required column': () => _docZip(
        _doc(
          tables: {
            'settings': [
              {'key': 'a'},
            ],
          },
        ),
      ),
      'foreign key to a missing row': () => _docZip(
        _doc(
          tables: {
            'meal_entries': [
              {
                'meal_id': 999,
                'position': 0,
                'food_ref': 'usda:1',
                'food_name': 'x',
                'quantity': 1,
                'unit_label': 'g',
                'base_quantity': 1,
                'base_unit': 'g',
              },
            ],
          },
        ),
      ),
      'string in a REAL column': () => _docZip(
        _doc(
          tables: {
            'weight_entries': [_weight(weightKg: 'eighty')],
          },
        ),
      ),
      'string in an INTEGER column': () => _docZip(
        _doc(
          tables: {
            'weight_entries': [_weight(measuredAtMs: '5')],
          },
        ),
      ),
      'fraction in an INTEGER column': () => _docZip(
        _doc(
          tables: {
            'weight_entries': [_weight(measuredAtMs: 5.5)],
          },
        ),
      ),
      'fraction in a boolean column': () => _docZip(
        _doc(
          tables: {
            'foods': [_food(1)..['archived'] = 0.5],
          },
        ),
      ),
      'number in a TEXT column': () => _docZip(
        _doc(
          tables: {
            'weight_entries': [_weight(localDate: 20260101)],
          },
        ),
      ),
      'null in a required column': () => _docZip(
        _doc(
          tables: {
            'weight_entries': [_weight(weightKg: null)],
          },
        ),
      ),
      'no tables at all': () => _docZip(_doc(tables: {}, fillMissing: false)),
      'one table missing': () => _docZip(
        _doc(
          tables: {for (final n in _tableNames.skip(1)) n: <Object?>[]},
          fillMissing: false,
        ),
      ),
      'duplicate unique value': () => _docZip(
        _doc(
          tables: {
            'foods': [_food(1, barcode: '123'), _food(2, barcode: '123')],
          },
        ),
      ),
      'duplicate primary key': () => _docZip(
        _doc(
          tables: {
            'settings': [
              {'key': 'a', 'value': '1'},
              {'key': 'a', 'value': '2'},
            ],
          },
        ),
      ),
    };

    for (final c in cases.entries) {
      test(c.key, () async {
        await _fill(db);
        final before = await _snapshot(db);
        await expectLater(
          importArchive(db, c.value()),
          throwsA(isA<ImportException>()),
        );
        expect(await _snapshot(db), before);
      });
    }

    test('error messages do not contain the data', () async {
      await expectLater(
        importArchive(
          db,
          _docZip(
            _doc(
              tables: {
                'foods': [
                  _food(1, name: 'SECRET-NAME', barcode: 'SECRET-CODE'),
                  _food(2, name: 'SECRET-NAME', barcode: 'SECRET-CODE'),
                ],
              },
            ),
          ),
        ),
        throwsA(
          isA<ImportException>().having(
            (e) => e.message,
            'message',
            isNot(contains('SECRET')),
          ),
        ),
      );
    });
  });

  group('export file', () {
    late Archive archive;
    late Map<String, dynamic> json;

    setUp(() async {
      await _fill(db);
      archive = ZipDecoder().decodeBytes(
        await exportArchive(db, now: _now, appVersion: '1.2.3'),
      );
      json = jsonDecode(_text(archive, 'daybook.json')) as Map<String, dynamic>;
    });

    test('daybook.json header', () {
      expect(json['format'], 'daybook-export');
      expect(json['formatVersion'], 1);
      expect(json['schemaVersion'], db.schemaVersion);
      expect(json['exportedAt'], '2026-11-08T12:30:15.000Z');
      expect(json['app'], 'Daybook 1.2.3');
      expect(
        (json['tables'] as Map).keys.toSet(),
        db.allTables.map((t) => t.actualTableName).toSet(),
      );
    });

    test('has one csv per table with a header matching the columns', () {
      for (final t in db.allTables) {
        final name = t.actualTableName;
        expect(archive.findFile('csv/$name.csv'), isNotNull, reason: name);
        final header = _text(archive, 'csv/$name.csv').split('\r\n').first;
        expect(header, t.$columns.map((c) => c.name).join(','));
      }
    });

    test('csv escapes commas, quotes and newlines', () {
      final foods = _text(archive, 'csv/foods.csv');
      expect(foods, contains('"Café 日本 🍙, ""quoted""\r\nsecond line\nthird"'));
      expect(foods, contains('"Brand, Inc."'));
      expect(foods.endsWith('\r\n'), isTrue);
    });

    test('toCsv writes RFC 4180', () {
      expect(
        toCsv(
          ['a', 'b'],
          [
            {'a': 'x,y', 'b': 'say "hi"'},
            {'a': 'one\ntwo', 'b': null},
            {'a': 1.5, 'b': ''},
            {'a': 'cr\rhere', 'b': 'plain'},
          ],
        ),
        'a,b\r\n'
        '"x,y","say ""hi"""\r\n'
        '"one\ntwo",\r\n'
        '1.5,\r\n'
        '"cr\rhere",plain\r\n',
      );
    });

    test('README.txt explains the files and the Open Food Facts license', () {
      final readme = _text(archive, 'README.txt');
      expect(readme, contains('daybook.json'));
      expect(readme, contains('https://openfoodfacts.org'));
      expect(readme, contains('Open Database License (ODbL) v1.0'));
      expect(readme.contains('—'), isFalse);
      expect(readme.contains('-' * 2), isFalse);
    });

    test('is deterministic for the same data and time', () async {
      final a = await exportArchive(db, now: _now, appVersion: '1.2.3');
      final b = await exportArchive(db, now: _now, appVersion: '1.2.3');
      expect(a, b);
    });
  });
}
