// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:convert';
import 'dart:io';

import 'package:daybook/data/database.dart';
import 'package:daybook/data/exercise_library.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseLibrary lib;
  late int readmeCount;
  late String rawAsset;

  setUpAll(() async {
    lib = await ExerciseLibrary.load();
    rawAsset = File('assets/exercises/wger_exercises.json').readAsStringSync();
    final readme = File('assets/exercises/README.txt').readAsStringSync();
    readmeCount = int.parse(
      RegExp(r'(\d+) exercises\s+with English text').firstMatch(readme)![1]!,
    );
  });

  group('the bundled asset', () {
    test('loads every entry and the count matches the README', () {
      expect(lib.all.length, readmeCount);
      expect((jsonDecode(rawAsset) as List).length, readmeCount);
    });

    test('every entry has a name, a license and a credit', () {
      for (final e in lib.all) {
        expect(e.name.trim(), isNotEmpty, reason: e.ref);
        expect(e.license, isNotEmpty, reason: e.ref);
        expect(e.licenseUrl, startsWith('http'), reason: e.ref);
        expect(e.credit, isNotNull, reason: e.ref);
        expect(e.credit, isNotEmpty, reason: e.ref);
        expect(e.url, startsWith('https://wger.de/'), reason: e.ref);
      }
    });

    test('no email address and no HTML tag anywhere in the file', () {
      expect(RegExp(r'[^\s@"]+@[^\s@"]+').hasMatch(rawAsset), isFalse);
      expect(rawAsset.contains('@'), isFalse);
      expect(RegExp(r'</?[A-Za-z!][^<>]*>').hasMatch(rawAsset), isFalse);
    });

    test('the file is valid, sorted by id, one entry per line', () {
      final data = (jsonDecode(rawAsset) as List).cast<Map<String, dynamic>>();
      final ids = [for (final e in data) e['id'] as int];
      expect(ids, [...ids]..sort());
      expect(ids.toSet().length, ids.length);
      expect(rawAsset.contains('\r'), isFalse);
      expect(rawAsset.split('\n').length, data.length + 3);
    });

    test('loading twice gives the same order', () async {
      final again = await ExerciseLibrary.load();
      expect(
        [for (final e in again.all) e.ref],
        [for (final e in lib.all) e.ref],
      );
    });

    test('the list is sorted by name, accents and case ignored', () {
      final names = [for (final e in lib.all) e.name.toLowerCase()];
      for (var i = 1; i < names.length; i++) {
        // Compare only the first letters; the full key also drops accents.
        expect(
          names[i - 1].codeUnitAt(0) <= names[i].codeUnitAt(0) ||
              names[i].codeUnitAt(0) > 0x7f ||
              names[i - 1].codeUnitAt(0) > 0x7f,
          isTrue,
          reason: '${names[i - 1]} before ${names[i]}',
        );
      }
    });

    test('shows no email as an author and keeps the contributor wording', () {
      expect(
        lib.all.any((e) => e.authors.contains('wger.de contributor')),
        isTrue,
      );
    });
  });

  group('search', () {
    test('by name', () {
      final r = lib.search('bench press');
      expect(r, isNotEmpty);
      expect(r.every((e) => e.name.toLowerCase().contains('bench')), isTrue);
    });

    test('by alias', () {
      final r = lib.search('Schwarzenegger Press');
      expect(r, isNotEmpty);
      expect(r.first.aliases, contains('Schwarzenegger Press'));
      expect(r.first.name.toLowerCase().contains('schwarzenegger'), isFalse);
    });

    test('case and accents are forgiven', () {
      expect(
        [for (final e in lib.search('BENCH PRESS')) e.ref],
        [for (final e in lib.search('bench press')) e.ref],
      );
      final custom = lib.withUser([
        LibraryExercise(ref: 'local:1', name: 'Südländer Curl'),
      ]);
      expect(custom.search('sudlander').map((e) => e.ref), ['local:1']);
      expect(custom.search('SÜDLÄNDER').map((e) => e.ref), ['local:1']);
    });

    test('every word must match, in any order', () {
      final r = lib.search('press bench');
      expect(r, isNotEmpty);
      expect(lib.search('bench zzzqqq'), isEmpty);
    });

    test('an empty query lists everything', () {
      expect(lib.search('  ').length, lib.all.length);
    });

    test('one muscle filter at a time', () {
      final chest = lib.search('', group: 'Chest');
      expect(chest, isNotEmpty);
      expect(chest.length, lessThan(lib.all.length));
      expect(
        chest.every(
          (e) => e.primaryMuscles.contains('Chest') || e.category == 'Chest',
        ),
        isTrue,
      );
      final both = lib.search('press', group: 'chest');
      expect(both, isNotEmpty);
      expect(both.every(chest.contains), isTrue);
      expect(
        lib
            .search('', group: 'Triceps')
            .every(
              (e) =>
                  e.primaryMuscles.contains('Triceps') ||
                  e.category == 'Triceps',
            ),
        isTrue,
      );
    });
  });

  group('refs', () {
    test('wger:<id> resolves with its credit and license', () {
      final first = lib.all.first;
      final r = lib.lookup(first.ref);
      expect(r.found, isTrue);
      expect(r.exercise!.name, first.name);
      expect(r.exercise!.license, isNotEmpty);
      expect(lib.lookup('wger:9').exercise!.name, '2 Handed Kettlebell Swing');
    });

    test('an unknown ref gives a clear result', () {
      final r = lib.lookup('wger:99999999');
      expect(r.found, isFalse);
      expect(r.exercise, isNull);
      expect(r.ref, 'wger:99999999');
      expect(lib.lookup('local:42').found, isFalse);
      expect(lib.lookup('nonsense').found, isFalse);
    });
  });

  group('the user\'s own exercises', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test(
      'are merged in, found by search and by ref, in the same shape',
      () async {
        final id = await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                name: 'Zercher Zig Zag',
                category: const Value('Legs'),
                primaryMuscles: const Value('Quads, Glutes'),
                secondaryMuscles: const Value('Abs'),
                equipment: const Value('Barbell'),
              ),
            );
        final merged = lib.withUser(await db.userExercises());
        expect(merged.all.length, lib.all.length + 1);

        final found = merged.search('zig zag');
        expect(found.map((e) => e.ref), ['local:$id']);
        final e = found.single;
        expect(e.isUser, isTrue);
        expect(e.primaryMuscles, ['Quads', 'Glutes']);
        expect(e.secondaryMuscles, ['Abs']);
        expect(e.equipment, ['Barbell']);
        expect(e.license, isNull);
        expect(e.credit, isNull);
        expect(
          merged.search('', group: 'glutes').map((x) => x.ref),
          contains('local:$id'),
        );
        expect(merged.lookup('local:$id').exercise!.name, 'Zercher Zig Zag');
        expect(merged.lookup('wger:9').found, isTrue);
        expect(lib.lookup('local:$id').found, isFalse);
      },
    );

    test(
      'an archived exercise is not listed but its ref still resolves',
      () async {
        final id = await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                name: 'Archived Thing',
                archived: const Value(true),
              ),
            );
        final merged = lib.withUser(await db.userExercises());
        expect(merged.search('archived thing'), isEmpty);
        expect(merged.lookup('local:$id').found, isTrue);
      },
    );

    test('merged order stays sorted by name', () {
      final merged = lib.withUser([
        LibraryExercise(ref: 'local:2', name: 'Aaa first'),
        LibraryExercise(ref: 'local:1', name: 'Aaa first'),
      ]);
      final refs = [for (final e in merged.all) e.ref];
      expect(refs.indexOf('local:1'), refs.indexOf('local:2') - 1);
    });
  });
}
