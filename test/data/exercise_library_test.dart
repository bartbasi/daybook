// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:convert';
import 'dart:io';

import 'package:daybook/data/database.dart';
import 'package:daybook/data/exercise_library.dart';
import 'package:daybook/parser/normalize.dart' show foldText;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bundle that holds one asset as text, or none when [text] is null.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.text);
  String? text;
  final cacheArgs = <bool>[];

  @override
  Future<ByteData> load(String key) async => throw StateError('use loadString');

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    cacheArgs.add(cache);
    final t = text;
    if (t == null) throw StateError('Unable to load asset');
    return t;
  }
}

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

    test('the list is sorted by the full folded name, then the ref', () {
      final all = lib.all;
      for (var i = 1; i < all.length; i++) {
        final x = all[i - 1];
        final y = all[i];
        final c = foldText(x.name).compareTo(foldText(y.name));
        expect(
          c < 0 || (c == 0 && x.ref.compareTo(y.ref) < 0),
          isTrue,
          reason: '${x.ref} ${x.name} before ${y.ref} ${y.name}',
        );
      }
    });

    test('credits are pinned', () {
      // No author at either level in wger, and an email author: both read
      // as the contributor wording.
      expect(lib.lookup('wger:549').exercise!.authors, ['wger.de contributor']);
      // A named author on the text.
      expect(lib.lookup('wger:9').exercise!.authors, ['deusinvictus']);
      expect(lib.lookup('wger:9').exercise!.credit, 'deusinvictus');
      // Authors that wger gives only on the exercise itself are kept.
      expect(lib.lookup('wger:1084').exercise!.authors, ['admin']);
      expect(lib.lookup('wger:2692').exercise!.authors, [
        'Original exercise instructions prepared for nalhilal',
      ]);
      // Two authors.
      final two = lib.lookup('wger:12').exercise!;
      expect(two.authors, ['Araaosf', 'flori']);
      expect(two.credit, 'Araaosf and flori');
    });

    test('a CC0 entry has its label and an https license URL', () {
      final e = lib.lookup('wger:152').exercise!;
      expect(e.license, 'CC0');
      expect(e.licenseLabel, 'CC0 1.0');
      expect(
        e.licenseUrl,
        'https://creativecommons.org/publicdomain/zero/1.0/',
      );
      expect(
        lib.all.where((x) => x.licenseUrl!.startsWith('http://')),
        isEmpty,
      );
    });

    test('left out entries and descriptions stay out', () {
      for (final id in [2699, 2760, 2645, 1949, 2452, 1702]) {
        expect(lib.lookup('wger:$id').found, isFalse, reason: '$id');
      }
      expect(lib.all.any((e) => e.name.endsWith('(Custom)')), isFalse);
      expect(lib.lookup('wger:1925').exercise!.description, '');
      expect(lib.lookup('wger:205').exercise!.description, '');
    });

    test('no orphan list marker and no zero width character', () {
      expect(RegExp('[​-‍﻿]').hasMatch(rawAsset), isFalse);
      for (final e in lib.all) {
        for (final line in e.description.split('\n')) {
          expect(RegExp(r'^(\d+\.|-)$').hasMatch(line), isFalse, reason: e.ref);
        }
      }
    });

    test('shows no email as an author and keeps the contributor wording', () {
      expect(
        lib.all.any((e) => e.authors.contains('wger.de contributor')),
        isTrue,
      );
    });
  });

  group('names for people', () {
    LibraryExercise withAuthors(List<String> a, [String? license]) =>
        LibraryExercise(ref: 'wger:1', name: 'X', authors: a, license: license);

    test('credit joins authors with and', () {
      expect(withAuthors([]).credit, isNull);
      expect(withAuthors(['A']).credit, 'A');
      expect(withAuthors(['A', 'B']).credit, 'A and B');
      expect(withAuthors(['A', 'B', 'C']).credit, 'A, B, and C');
    });

    test('license label', () {
      expect(withAuthors([], 'CC-BY-SA 4').licenseLabel, 'CC BY-SA 4.0');
      expect(withAuthors([], 'CC-BY-SA 3').licenseLabel, 'CC BY-SA 3.0');
      expect(withAuthors([], 'CC0').licenseLabel, 'CC0 1.0');
      expect(withAuthors([], 'ODbL').licenseLabel, 'ODbL');
      expect(withAuthors([]).licenseLabel, isNull);
      expect(withAuthors([], 'CC-BY-SA 4').license, 'CC-BY-SA 4');
    });
  });

  group('the loader', () {
    final good = jsonEncode([
      {
        'id': 1,
        'name': 'Test',
        'aliases': <String>[],
        'category': '',
        'primary_muscles': <String>[],
        'secondary_muscles': <String>[],
        'equipment': <String>[],
        'description': '',
        'license': 'CC0',
        'license_full': 'x',
        'license_url': 'https://creativecommons.org/publicdomain/zero/1.0/',
        'authors': ['a'],
        'url': 'https://wger.de/en/exercise/1/view/',
      },
    ]);

    test(
      'a missing asset is a FormatException naming the asset only',
      () async {
        final bundle = _FakeBundle(null);
        await expectLater(
          ExerciseLibrary.load(bundle: bundle),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'assets/exercises/wger_exercises.json could not be loaded',
            ),
          ),
        );
      },
    );

    test('bad JSON does not leak its content', () async {
      final bundle = _FakeBundle('{"secret": oops');
      await expectLater(
        ExerciseLibrary.load(bundle: bundle),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('not valid JSON'))
              .having((e) => e.message, 'message', isNot(contains('secret'))),
        ),
      );
    });

    test('a wrong shape names the entry', () async {
      await expectLater(
        ExerciseLibrary.load(bundle: _FakeBundle('{"a": 1}')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not a list'),
          ),
        ),
      );
      final broken = jsonEncode([
        ...jsonDecode(good) as List,
        {'id': 2, 'name': 'No other fields'},
      ]);
      await expectLater(
        ExerciseLibrary.load(bundle: _FakeBundle(broken)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Entry 1'), isNot(contains('No other fields'))),
          ),
        ),
      );
    });

    test('a failure is not remembered and a later good load works', () async {
      final bundle = _FakeBundle('nope');
      await expectLater(
        ExerciseLibrary.load(bundle: bundle),
        throwsA(isA<FormatException>()),
      );
      bundle.text = good;
      final loaded = await ExerciseLibrary.load(bundle: bundle);
      expect(loaded.all.single.name, 'Test');
      // A second load shares the first and does not read the asset again.
      bundle.text = 'changed but not read again';
      expect((await ExerciseLibrary.load(bundle: bundle)).all.length, 1);
    });

    test('the asset text is not cached by the bundle', () async {
      final bundle = _FakeBundle(good);
      await ExerciseLibrary.load(bundle: bundle);
      expect(bundle.cacheArgs, [false]);
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
