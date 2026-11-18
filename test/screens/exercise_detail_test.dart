// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:daybook/data/database.dart';

import 'dart:async';

import 'package:daybook/data/exercise_library.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_harness.dart';

// Exercise detail (task 4.4, exercise-detail.html frame 1): muscles and
// equipment, records, estimated 1-rep max by session, history, and the wger
// text with its author and license.

void main() {
  final h = WorkoutHarness()..register();

  const bench = 'wger:73'; // Bench Press, text by sistab2, CC BY-SA 3.0

  Future<void> seedBench(WidgetTester tester) => h.real(tester, () async {
    await h.doWorkout('2026-11-05', [
      (bench, 'Bench Press', [(175, 8), (175, 8), (175, 7)]),
    ]);
    await h.doWorkout('2026-11-12', [
      (bench, 'Bench Press', [(175, 8), (175, 8), (180, 8)]),
    ], hour: 8);
  });

  /// More > Exercises, a search, and a tap on the first result named [name].
  Future<void> openDetail(
    WidgetTester tester,
    String search,
    String name, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    await h.openApp(tester, size: size, textScale: scale);
    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await settle(tester);
    for (var i = 0; i < 20 && find.text('Exercises').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Exercises'));
    await tester.pump();
    await tester.tap(find.text('Exercises'));
    await waitFor(tester, find.text('Search exercises'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search exercises'),
      search,
    );
    await waitFor(tester, find.text(name));
    await tester.tap(find.text(name).first);
    // The records come first; the muscles once the list has been read.
    await waitFor(tester, find.textContaining('(primary)'));
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) =>
      tester.scrollUntilVisible(
        f,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );

  h.appTest('shows muscles and equipment, the two records with their sets, '
      'the estimate by session and the history', (tester) async {
    await seedBench(tester);
    await openDetail(tester, 'bench press', 'Bench Press');
    expect(find.widgetWithText(AppBar, 'Bench Press'), findsOneWidget);
    expect(
      find.text(
        'Chest (primary). Shoulders, triceps (secondary). Barbell, Bench.',
      ),
      findsOneWidget,
    );
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Heaviest'), findsOneWidget);
    expect(find.text('180 lb'), findsOneWidget);
    expect(find.text('x 8, Nov 12'), findsOneWidget);
    expect(find.text('Est. 1-rep max'), findsOneWidget);
    expect(find.text('228 lb'), findsWidgets);
    expect(find.text('from 180 x 8, Nov 12'), findsOneWidget);

    await scrollTo(tester, find.text('Thu, Nov 5').first);
    expect(find.text('Est. 1-rep max by session'), findsOneWidget);
    expect(find.text('222 lb'), findsOneWidget); // 175 x 8 on Nov 5
    expect(find.text('best 175 x 8'), findsOneWidget);
    expect(find.text('best 180 x 8'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('175 x 8, 175 x 8, 180 x 8'), findsOneWidget);
    expect(find.text('175 x 8, 175 x 8, 175 x 7'), findsOneWidget);
  });

  h.appTest('numbers follow the user\'s units', (tester) async {
    await seedBench(tester);
    await h.real(tester, () => h.db.setUnits(UnitSystem.metric));
    await openDetail(tester, 'bench press', 'Bench Press');
    expect(find.text('81.6 kg'), findsOneWidget); // 180 lb
    expect(find.text('from 81.6 x 8, Nov 12'), findsOneWidget);
  });

  h.appTest('the wger credit names the author and the license, and About '
      'shows the description', (tester) async {
    await openDetail(tester, 'bench press', 'Bench Press');
    expect(find.text('About this exercise'), findsOneWidget);
    expect(find.textContaining('Lay down on a bench'), findsOneWidget);
    await scrollTo(tester, find.text('Text by sistab2, CC BY-SA 3.0.'));
    expect(find.text('Text by sistab2, CC BY-SA 3.0.'), findsOneWidget);
    expect(find.text('View on wger.de'), findsNothing);
  });

  h.appTest('an exercise with no description has no About, and two authors '
      'are joined', (tester) async {
    await openDetail(
      tester,
      'abdominal stabilization',
      'Abdominal Stabilization',
    );
    expect(find.text('About this exercise'), findsNothing);
    expect(
      find.text('Text by andikeller and wger.de, CC BY-SA 3.0.'),
      findsOneWidget,
    );
  });

  test('no credit of any library exercise holds an email address', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final lib = await ExerciseLibrary.load();
    for (final e in lib.all) {
      expect(e.credit ?? '', isNot(contains('@')), reason: e.ref);
      expect(e.licenseLabel ?? '', isNot(contains('@')), reason: e.ref);
    }
  });

  h.appTest('a user\'s own exercise shows no credit line, and says nothing is '
      'logged yet', (tester) async {
    await h.real(tester, () async {
      final lib = await ExerciseLibrary.load();
      await h.db.createExercise(
        lib,
        'Zq sled haul',
        primary: ['Quads'],
        equipment: 'Sled',
      );
    });
    await openDetail(tester, 'zq sled', 'Zq sled haul');
    expect(find.text('Quads (primary). Sled.'), findsOneWidget);
    expect(find.textContaining('Text by'), findsNothing);
    expect(find.text('About this exercise'), findsNothing);
    expect(find.text('No records yet.'), findsOneWidget);
    expect(find.text('Nothing logged for this exercise yet.'), findsOneWidget);
  });

  h.appTest('Exercise details in a running workout opens it', (tester) async {
    final id = await h.real(
      tester,
      () async => (await h.db.startEmptyWorkout(h.now)).workout!.id,
    );
    await h.real(tester, () => h.db.addExercise(id, bench, 'Bench Press'));
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await settle(tester);
    await tester.tap(find.byTooltip('Menu for Bench Press'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Exercise details'));
    await waitFor(tester, find.text('Records'));
    expect(find.widgetWithText(AppBar, 'Bench Press'), findsOneWidget);
  });

  /// The credit block of the open detail: the three lines under the text.
  Future<void> expectCredit(
    WidgetTester tester, {
    required String search,
    required String name,
    required String credit,
    required String licenseUrl,
    required String sourceUrl,
  }) async {
    await openDetail(tester, search, name);
    await scrollTo(tester, find.text(credit));
    expect(find.text(credit), findsOneWidget);
    expect(find.text('License: $licenseUrl'), findsOneWidget);
    expect(find.text('Source: $sourceUrl'), findsOneWidget);
  }

  h.appTest('the credit also shows the license URL and the exercise page, '
      'for CC BY-SA 4.0', (tester) async {
    await expectCredit(
      tester,
      search: 'bench press isometric',
      name: 'Bench Press Isometric',
      credit: 'Text by HexoctusEngineering, CC BY-SA 4.0.',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/deed.en',
      sourceUrl: 'https://wger.de/en/exercise/2536/view/',
    );
  });

  h.appTest('the credit also shows the license URL and the exercise page, '
      'for CC BY-SA 3.0', (tester) async {
    await expectCredit(
      tester,
      search: 'bench press',
      name: 'Bench Press',
      credit: 'Text by sistab2, CC BY-SA 3.0.',
      licenseUrl: 'https://creativecommons.org/licenses/by-sa/3.0/deed.en',
      sourceUrl: 'https://wger.de/en/exercise/73/view/',
    );
  });

  h.appTest('the credit also shows the license URL and the exercise page, '
      'for CC0', (tester) async {
    await expectCredit(
      tester,
      search: 'chin up',
      name: 'Chin Up',
      credit: 'Text by BFad07, CC0 1.0.',
      licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      sourceUrl: 'https://wger.de/en/exercise/152/view/',
    );
  });

  h.appTest('the credit URLs wrap at text scale 2 on a narrow screen and '
      'are not cut', (tester) async {
    await openDetail(
      tester,
      'chin up',
      'Chin Up',
      size: const Size(344, 800),
      scale: 2,
    );
    final url = find.text(
      'License: https://creativecommons.org/publicdomain/zero/1.0/',
    );
    await scrollTo(tester, url);
    final edit = tester.state<EditableTextState>(url).renderEditable;
    // More than one line, and inside the 16 dp margins.
    expect(edit.size.height, greaterThan(edit.preferredLineHeight * 1.5));
    expect(edit.size.width, lessThanOrEqualTo(344 - 32));
    final page = tester.getRect(find.byType(ListView).last);
    expect(tester.getRect(url).right, lessThanOrEqualTo(page.right));
  });

  h.appTest('an exercise of the user has no license lines', (tester) async {
    await h.real(tester, () async {
      final lib = await ExerciseLibrary.load();
      await h.db.createExercise(lib, 'Zq sled haul', primary: ['Quads']);
    });
    await openDetail(tester, 'zq sled', 'Zq sled haul');
    expect(find.textContaining('License:'), findsNothing);
    expect(find.textContaining('Source:'), findsNothing);
  });

  h.appTest('a body weight set shows as "body weight x 10" in History, and a '
      'set over 12 reps is the heaviest record with no estimate', (
    tester,
  ) async {
    await h.real(tester, () async {
      final r = await h.db.startEmptyWorkout(at('2026-11-05', 17, 0));
      final id = r.workout!.id;
      await h.db.addExercise(id, bench, 'Bench Press', sets: 2);
      final rows = (await h.db.loadWorkout(id))!.exercises.single.sets
          .map((s) => s.row.id)
          .toList();
      await h.db.adjustSet(rows[0], weightKg: null, reps: 10);
      await h.db.adjustSet(rows[1], weightKg: lbToKg(135), reps: 15);
      final done = at('2026-11-05', 17, 30);
      await h.db.logSet(rows[0], done);
      await h.db.logSet(rows[1], done);
      await h.db.finishWorkout(id, at('2026-11-05', 17, 40));
    });
    await openDetail(tester, 'bench press', 'Bench Press');
    expect(find.text('Heaviest'), findsOneWidget);
    expect(find.text('135 lb'), findsOneWidget);
    expect(find.text('x 15, Nov 5'), findsOneWidget);
    expect(find.text('Est. 1-rep max'), findsNothing);
    expect(find.text('Est. 1-rep max by session'), findsNothing);
    await scrollTo(tester, find.text('History'));
    expect(find.text('body weight x 10, 135 x 15'), findsOneWidget);
  });

  /// A running workout holding [bench] under [stored], its Exercise details
  /// opened, with the exercises table read through [reads].
  Future<void> detailFromWorkout(
    WidgetTester tester,
    ExerciseReads reads, {
    required String stored,
  }) async {
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(reads));
    await h.real(tester, () async {
      final id = (await h.db.startEmptyWorkout(h.now)).workout!.id;
      await h.db.addExercise(id, bench, stored);
    });
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await waitFor(tester, find.byTooltip('Menu for $stored'));
    await tester.tap(find.byTooltip('Menu for $stored'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Exercise details'));
    await settle(tester);
  }

  h.appTest("while the exercise list loads the title is the stored name, and "
      "then the list's own", (tester) async {
    final reads = ExerciseReads()..hold = Completer<void>();
    await detailFromWorkout(tester, reads, stored: 'Old name');
    expect(find.widgetWithText(AppBar, 'Old name'), findsOneWidget);
    expect(find.text('The exercise list could not be read.'), findsNothing);
    expect(find.text('This exercise is no longer in the list.'), findsNothing);
    reads.hold!.complete();
    await waitFor(tester, find.widgetWithText(AppBar, 'Bench Press'));
    expect(find.widgetWithText(AppBar, 'Bench Press'), findsOneWidget);
  });

  h.appTest('an exercise the list no longer has keeps its stored name and '
      'says so', (tester) async {
    await h.real(tester, () async {
      final id = (await h.db.startEmptyWorkout(h.now)).workout!.id;
      await h.db.addExercise(id, 'local:99', 'Gone lift');
    });
    await h.openApp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Return'));
    await waitFor(tester, find.byTooltip('Menu for Gone lift'));
    await tester.tap(find.byTooltip('Menu for Gone lift'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Exercise details'));
    await waitFor(tester, find.text('This exercise is no longer in the list.'));
    expect(find.widgetWithText(AppBar, 'Gone lift'), findsOneWidget);
    expect(
      find.text('This exercise is no longer in the list.'),
      findsOneWidget,
    );
  });

  h.appTest('when the exercise list cannot be read the screen says that, '
      'not that the exercise is gone', (tester) async {
    final reads = ExerciseReads()
      ..hold = Completer<void>()
      ..fail = true;
    await detailFromWorkout(tester, reads, stored: 'Old name');
    reads.hold!.complete();
    await waitFor(tester, find.text('The exercise list could not be read.'));
    expect(find.text('The exercise list could not be read.'), findsOneWidget);
    expect(find.text('This exercise is no longer in the list.'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Old name'), findsOneWidget);
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp, text scale $scale: '
          'nothing overflows, the page scrolls to the end', (tester) async {
        await seedBench(tester);
        await openDetail(
          tester,
          'bench press',
          'Bench Press',
          size: size,
          scale: scale,
        );
        await scrollTo(tester, find.text('Text by sistab2, CC BY-SA 3.0.'));
        expect(find.text('Text by sistab2, CC BY-SA 3.0.'), findsOneWidget);
      });
    }
  }

  h.appTest('spoken labels: the record cards and a session', (tester) async {
    await seedBench(tester);
    await openDetail(tester, 'bench press', 'Bench Press');
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('Heaviest, 180 lb, x 8, Nov 12'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Est. 1-rep max, 228 lb, from 180 x 8, Nov 12'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
