// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/database.dart';
import 'package:daybook/data/exercise_library.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Create exercise (task 4.4): the user's own exercise, written and read back.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late ExerciseLibrary lib;
  late AppDatabase db;

  setUpAll(() async => lib = await ExerciseLibrary.load());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ExerciseRefused> refused(Future<Object?> f) async {
    try {
      await f;
    } on ExerciseRefused catch (e) {
      return e;
    }
    fail('expected a refusal');
  }

  test(
    'saves the name trimmed, with muscles and equipment, read back',
    () async {
      final made = await db.createExercise(
        lib,
        '  Cable fly  ',
        primary: ['Chest'],
        secondary: ['Shoulders', 'Triceps'],
        equipment: ' Cable machine ',
      );
      expect(made.ref, startsWith('local:'));
      expect(made.name, 'Cable fly');
      expect(made.primaryMuscles, ['Chest']);
      expect(made.secondaryMuscles, ['Shoulders', 'Triceps']);
      expect(made.equipment, ['Cable machine']);
      expect(made.isUser, isTrue);
      final rows = await db.userExercises();
      expect(rows.single.ref, made.ref);
      expect(rows.single.groups, [VolumeGroup.chest]);
      final merged = lib.withUser(rows);
      expect(merged.lookup(made.ref).found, isTrue);
      expect(merged.search('cable fly').map((e) => e.ref), contains(made.ref));
    },
  );

  test('equipment is optional', () async {
    final made = await db.createExercise(lib, 'Zq sled haul');
    expect(made.equipment, isEmpty);
    expect(made.primaryMuscles, isEmpty);
  });

  test('a blank name is refused and nothing is written', () async {
    final e = await refused(db.createExercise(lib, '   '));
    expect(e.problem, ExerciseProblem.blankName);
    expect(await db.userExercises(), isEmpty);
  });

  test('the same name as a library exercise is refused, accents and case '
      'ignored', () async {
    final name = lib.all.first.name;
    final e = await refused(db.createExercise(lib, name.toUpperCase()));
    expect(e.problem, ExerciseProblem.sameName);
    expect(await db.userExercises(), isEmpty);
  });

  test('the same name as another of the user\'s own is refused', () async {
    await db.createExercise(lib, 'Zq sled haul');
    final e = await refused(db.createExercise(lib, ' zq SLED haul '));
    expect(e.problem, ExerciseProblem.sameName);
    expect(await db.userExercises(), hasLength(1));
  });

  test('an accented spelling and extra inner spaces are the same name as a '
      'library exercise', () async {
    expect(lib.lookup('wger:73').exercise!.name, 'Bench Press');
    for (final name in ['Bénch press', 'Bench  press', ' bench \t PRESS ']) {
      final e = await refused(db.createExercise(lib, name));
      expect(e.problem, ExerciseProblem.sameName, reason: name);
    }
    expect(await db.userExercises(), isEmpty);
  });

  test(
    'inner spaces are collapsed in the name that is saved and compared',
    () async {
      final made = await db.createExercise(lib, '  Zq   sled \n haul ');
      expect(made.name, 'Zq sled haul');
      final e = await refused(db.createExercise(lib, 'zq sled  haul'));
      expect(e.problem, ExerciseProblem.sameName);
    },
  );

  test('a muscle that is not in the library is a programming error', () {
    expect(
      () => db.createExercise(lib, 'X', primary: ['Wings']),
      throwsArgumentError,
    );
  });

  test('a muscle in both lists stays primary only', () async {
    final made = await db.createExercise(
      lib,
      'Push up',
      primary: ['Chest'],
      secondary: ['Chest', 'Triceps'],
    );
    expect(made.secondaryMuscles, ['Triceps']);
  });
}
