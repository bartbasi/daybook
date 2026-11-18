// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/exercise_library.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/workout_data.dart';
import 'package:daybook/screens/workouts/install_seams.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workouts_harness.dart';

// Exercise detail (task 4.4, exercise-detail.html frame 1): muscles and
// equipment, records, estimated 1-rep max by session, history, and the wger
// text with its author and license.

void main() {
  final h = WorkoutHarness()..register();

  setUp(installWorkoutSeams);
  tearDown(clearWorkoutSeams);

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
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search exercises'),
      search,
    );
    await settle(tester);
    await tester.tap(find.text(name).first);
    await settle(tester);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
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
    await settle(tester);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.widgetWithText(AppBar, 'Bench Press'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
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
