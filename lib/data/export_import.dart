// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show DriftSqlType, GeneratedColumn;

import '../app_info.dart';
import 'database.dart';

/// Thrown by [importArchive] with a plain message that is safe to show.
/// The message never contains any of the user's data.
class ImportException implements Exception {
  ImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _format = 'daybook-export';
const _formatVersion = 1;

const _readme =
    '''This file is an export of your $appName data.

daybook.json holds everything. It is the file $appName reads when you import.
The csv folder has the same data, one file per table, for spreadsheets.
$appName does not read the csv files.

Foods with kind "off" contain data from Open Food Facts (https://openfoodfacts.org),
available under the Open Database License (ODbL) v1.0.
''';

/// Everything the user has, as the bytes of one zip file.
Future<List<int>> exportArchive(
  AppDatabase db, {
  required DateTime now,
  required String appVersion,
}) async {
  final tables = <String, List<Map<String, Object?>>>{};
  final columns = <String, List<String>>{};
  // One transaction, so all tables come from the same moment.
  await db.transaction(() async {
    for (final t in db.allTables) {
      final name = t.actualTableName;
      columns[name] = [for (final c in t.$columns) c.name];
      final rows = await db
          .customSelect('SELECT * FROM "$name" ORDER BY rowid')
          .get();
      tables[name] = [
        for (final r in rows)
          {
            for (final e in r.data.entries)
              // JSON cannot hold infinity or NaN, and one bad value must not
              // block a backup. Writes should never store them.
              e.key: e.value is double && !(e.value as double).isFinite
                  ? null
                  : e.value,
          },
      ];
    }
  });

  final json = {
    'format': _format,
    'formatVersion': _formatVersion,
    'schemaVersion': db.schemaVersion,
    'exportedAt': now.toUtc().toIso8601String(),
    'app': '$appName $appVersion',
    'tables': tables,
  };

  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  final archive = Archive();
  void add(String name, String text) {
    archive.add(
      ArchiveFile.bytes(name, utf8.encode(text))..lastModTime = seconds,
    );
  }

  add('daybook.json', jsonEncode(json));
  for (final name in tables.keys) {
    add('csv/$name.csv', toCsv(columns[name]!, tables[name]!));
  }
  add('README.txt', _readme);
  return ZipEncoder().encode(archive);
}

/// RFC 4180 CSV: CRLF line endings, a header row, null as an empty field.
String toCsv(List<String> columns, List<Map<String, Object?>> rows) {
  final out = StringBuffer();
  out.write('${columns.map(_csvField).join(',')}\r\n');
  for (final row in rows) {
    out.write('${columns.map((c) => _csvField(row[c])).join(',')}\r\n');
  }
  return out.toString();
}

String _csvField(Object? value) {
  final s = value?.toString() ?? '';
  if (!s.contains(RegExp('[",\r\n]'))) return s;
  return '"${s.replaceAll('"', '""')}"';
}

/// Replaces all user data with the contents of an export file. The file is
/// fully checked first, and the write is one transaction, so on any failure
/// the database is left exactly as it was.
Future<void> importArchive(AppDatabase db, List<int> bytes) async {
  final tables = _validate(db, bytes);

  try {
    await db.transaction(() async {
      await db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final name in tables.keys) {
        await db.customStatement('DELETE FROM "$name"');
      }
      for (final entry in tables.entries) {
        for (final row in entry.value) {
          await _insert(db, entry.key, row);
        }
      }
      final broken = await db.customSelect('PRAGMA foreign_key_check').get();
      if (broken.isNotEmpty) {
        throw ImportException(
          'The file has records that point to missing records.',
        );
      }
    });
    // The writes above bypass drift's own tracking, so tell open streams.
    db.markTablesUpdated(db.allTables);
  } on ImportException {
    rethrow;
  } catch (_) {
    // Constraint errors can quote values, so the cause is not passed on.
    throw ImportException(
      'The file could not be imported. Your data was not changed.',
    );
  }
}

Future<void> _insert(AppDatabase db, String table, Map<String, Object?> row) {
  if (row.isEmpty) {
    return db.customStatement('INSERT INTO "$table" DEFAULT VALUES');
  }
  final names = row.keys.map((k) => '"$k"').join(',');
  final marks = List.filled(row.length, '?').join(',');
  return db.customStatement(
    'INSERT INTO "$table" ($names) VALUES ($marks)',
    row.values.toList(),
  );
}

/// Returns the rows to import for every table in the database (empty if the
/// file has none). Table and column names are checked against the schema, so
/// they are safe to quote into SQL.
Map<String, List<Map<String, Object?>>> _validate(
  AppDatabase db,
  List<int> bytes,
) {
  Never bad(String why) => throw ImportException(why);

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    bad('This is not a $appName export file.');
  }
  final file = archive.findFile('daybook.json');
  if (file == null) bad('This is not a $appName export file.');

  final Object? doc;
  try {
    doc = jsonDecode(utf8.decode(file.content));
  } catch (_) {
    bad('The export file is damaged.');
  }
  if (doc is! Map || doc['format'] != _format) {
    bad('This is not a $appName export file.');
  }
  if (doc['formatVersion'] != _formatVersion) {
    bad('This export file has a format this version of $appName cannot read.');
  }
  final schema = doc['schemaVersion'];
  if (schema is! int || schema < 1) bad('The export file is damaged.');
  // When the schema goes to v2, older files must be migrated (import into a
  // database at the file's version, then upgrade it), not inserted as they are.
  if (schema > db.schemaVersion) {
    bad(
      'This file was made by a newer version of $appName. Update the app and try again.',
    );
  }
  final given = doc['tables'];
  if (given is! Map) bad('The export file is damaged.');

  final known = {
    for (final t in db.allTables)
      t.actualTableName: {for (final c in t.$columns) c.name: c},
  };
  final result = {
    for (final name in known.keys) name: <Map<String, Object?>>[],
  };
  if (known.keys.any((name) => !given.containsKey(name))) {
    bad('The export file is incomplete.');
  }
  for (final entry in given.entries) {
    final columns = known[entry.key];
    if (columns == null) {
      bad('The export file has data $appName does not know.');
    }
    final rows = entry.value;
    if (rows is! List) bad('The export file is damaged.');
    for (final row in rows) {
      if (row is! Map) bad('The export file is damaged.');
      for (final cell in row.entries) {
        final column = columns[cell.key];
        if (column == null) {
          bad('The export file has data $appName does not know.');
        }
        if (!_fits(column, cell.value)) bad('The export file is damaged.');
      }
      result[entry.key]!.add(Map<String, Object?>.from(row));
    }
  }
  return result;
}

/// Whether [v] is a legal value for [column]. SQLite would accept anything,
/// but typed reads later would crash or truncate.
bool _fits(GeneratedColumn column, Object? v) {
  if (v == null) return column.$nullable;
  switch (column.type) {
    case DriftSqlType.int:
    case DriftSqlType.bool:
      return v is int;
    case DriftSqlType.double:
      return v is num;
    case DriftSqlType.string:
      return v is String;
    default:
      return false;
  }
}
