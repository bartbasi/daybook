// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app_scope.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/cardio_data.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/met_table.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/screens/cardio/cardio_screen.dart';
import 'package:daybook/strings.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../speed/tap_counter.dart';
import 'workouts_harness.dart';

// The cardio screen (task 5.3, cardio.html frames 1 to 4), opened from Home,
// and the Exercise rows, edit and delete on Home (frame 5).

const imp = UnitSystem.imperial;
const running = '12145';
const walking = '17190';
const cycling = '01014';

/// A database that can hold or refuse the insert of a session.
class _Gate extends QueryInterceptor {
  Completer<void>? hold;
  var failInserts = false;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await hold?.future;
    if (failInserts && statement.contains('cardio_sessions')) {
      throw StateError('disk full');
    }
    return super.runInsert(executor, statement, args);
  }
}

class _Pushes extends NavigatorObserver {
  var count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}

void main() {
  final h = WorkoutHarness()..register();
  late MetTable table;

  Finder bar(String label) => find.widgetWithText(FilledButton, label);
  Finder field(String label) => find.widgetWithText(TextField, label);
  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  Finder undo() => find.widgetWithText(TextButton, 'Undo');

  Future<void> weigh(WidgetTester tester, [double lb = 181.8]) => h.real(
    tester,
    () => h.db.saveWeight(lb, imp, at('2026-11-09', 7, 0)).then((_) {}),
  );

  CardioInput input({
    String code = running,
    int minutes = 30,
    double? miles = 3.1,
    int? hr,
    double? override,
    String? entry,
  }) => CardioInput(
    activityCode: code,
    entryCode: entry,
    durationSeconds: minutes * 60,
    distanceMeters: miles == null ? null : milesToMeters(miles),
    avgHeartRate: hr,
    kcalOverride: override,
  );

  Future<CardioSession> seed(WidgetTester tester, CardioInput i, [Now? when]) =>
      h.real(
        tester,
        () => h.db.saveCardio(table, i, when ?? at('2026-11-12', 12, 0)),
      );

  Future<List<CardioSession>> sessions(WidgetTester tester) =>
      h.real(tester, () => h.db.select(h.db.cardioSessions).get());

  Future<void> openApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    // Read once, outside the test's fake time.
    table = (await tester.runAsync(MetTable.load))!;
    await h.openApp(tester, size: size, textScale: scale);
  }

  Future<void> openCardio(WidgetTester tester) async {
    await tester.tap(bar('Cardio'));
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(field(label), text);
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(saveButton());
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }

  bool focused(WidgetTester tester, String label) => tester
      .widget<EditableText>(
        find.descendant(of: field(label), matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;

  h.appTest('opens with the last activity picked and Duration focused, the '
      'chips in the order last used, then Other...', (tester) async {
    await weigh(tester);
    await seed(
      tester,
      input(code: cycling, miles: null),
      at('2026-11-10', 8, 0),
    );
    await seed(
      tester,
      input(code: walking, miles: null),
      at('2026-11-11', 8, 0),
    );
    await seed(tester, input());
    await openApp(tester);
    final handle = tester.ensureSemantics();
    await openCardio(tester);

    expect(find.byType(CardioScreen), findsOneWidget);
    expect(focused(tester, 'Duration'), isTrue);
    final names = [
      for (final c in tester.widgetList<Text>(
        find.descendant(of: find.byType(Wrap), matching: find.byType(Text)),
      ))
        c.data,
    ];
    expect(names.take(4), ['Running', 'Walking', 'Cycling', 'Other...']);
    expect(find.bySemanticsLabel('Running, picked'), findsOneWidget);
    expect(find.bySemanticsLabel('Walking'), findsOneWidget);
    expect(find.bySemanticsLabel('Cycling'), findsOneWidget);
    // The picked activity is in bold above the fields.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == 'Running' &&
            w.style?.fontWeight == FontWeight.bold,
      ),
      findsOneWidget,
    );
    // Without a distance the entry of last time is used, and it is said so.
    expect(
      find.textContaining(
        'Matched Running, 6-6.3 mph (10 min/mile), code '
        '12050, MET 9.3.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Used last time.'), findsOneWidget);
    handle.dispose();
  });

  h.appTest('the first time there are no chips but Other..., and nothing is '
      'picked', (tester) async {
    await weigh(tester);
    await openApp(tester);
    await openCardio(tester);

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Other...'), findsOneWidget);
    expect(find.text(S.cardioPickPrompt), findsOneWidget);
    expect(focused(tester, 'Duration'), isTrue);
    await type(tester, 'Duration', '30');
    // No activity: no number and Save stays off.
    expect(find.text(S.cardioNeedActivity), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
  });

  h.appTest('the estimate follows what is typed, and the pace picks the '
      'entry', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);

    expect(find.text('Estimate: needs a duration'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await type(tester, 'Duration', '30');
    expect(find.text('383 kcal estimate'), findsOneWidget);
    expect(find.text('MET 9.3, 181.8 lb, 30 min'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);

    await type(tester, 'Distance (optional)', '3.1');
    expect(
      find.textContaining('Your pace, 6.2 mph, is in this band.'),
      findsOneWidget,
    );
    expect(find.text('383 kcal estimate'), findsOneWidget);

    // A pace in a gap between bands: the nearest band, said so.
    await type(tester, 'Distance (optional)', '3.25');
    expect(
      find.textContaining('Nearest to your pace, 6.5 mph.'),
      findsOneWidget,
    );

    // A slower run uses another entry, so another number.
    await type(tester, 'Distance (optional)', '2.5');
    expect(find.text('383 kcal estimate'), findsNothing);
    expect(find.textContaining('code 12030'), findsOneWidget);
  });

  h.appTest('Save writes the session; Home says so from the row read back, '
      'and Undo deletes it once', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    await type(tester, 'Distance (optional)', '3.1');
    await type(tester, 'Avg heart rate (optional)', '152');
    await save(tester);

    expect(find.byType(CardioScreen), findsNothing);
    expect(find.text('Running saved, 383 kcal'), findsOneWidget);
    final rows = await sessions(tester);
    expect(rows, hasLength(2));
    final row = rows.last;
    expect(row.activityName, 'Running');
    expect(row.activityCode, '12050');
    expect(row.durationSeconds, 1800);
    expect(row.distanceMeters, closeTo(milesToMeters(3.1), 1e-9));
    expect(row.avgHeartRate, 152);
    expect(row.kcalEstimated, closeTo(9.3 * lbToKg(181.8) * 0.5, 1e-9));
    expect(row.kcalOverride, isNull);
    expect(row.localDate, '2026-11-12');
    expect(row.source, 'manual');

    // The run is under Exercise, and Undo takes it back, once.
    expect(find.byKey(ValueKey('cardio-${row.id}')), findsOneWidget);
    await tester.tap(undo());
    await tester.tap(undo(), warnIfMissed: false);
    await settle(tester);
    expect(
      (await h.real(tester, () => h.db.cardioForDay('2026-11-12'))),
      hasLength(1),
    );
    expect(find.byKey(ValueKey('cardio-${row.id}')), findsNothing);
    expect(find.text('Running saved, 383 kcal'), findsNothing);
  });

  h.appTest('a typed number is "your number", both numbers are saved, and '
      'Use estimate gives the estimate back', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    final handle = tester.ensureSemantics();
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    await type(tester, 'Distance (optional)', '3.1');
    expect(find.bySemanticsLabel('383 kilocalories, estimate'), findsOneWidget);

    await type(tester, 'Calories (own number)', '360');
    expect(find.text('360 kcal your number'), findsOneWidget);
    expect(find.text('Estimate was 383.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('360 kilocalories, your number'),
      findsOneWidget,
    );

    await tester.tap(find.text('Use estimate'));
    await settle(tester);
    expect(find.text('383 kcal estimate'), findsOneWidget);
    expect(find.text('Use estimate'), findsNothing);
    expect(
      tester.widget<TextField>(field('Calories (own number)')).controller!.text,
      isEmpty,
    );

    await type(tester, 'Calories (own number)', '360');
    await save(tester);
    expect(find.text('Running saved, 360 kcal'), findsOneWidget);
    final row = (await sessions(tester)).last;
    expect(row.kcalOverride, 360);
    expect(row.kcalEstimated, closeTo(383.45, 0.01));
    handle.dispose();
  });

  h.appTest('Change lists the group\'s entries with their MET, and the pick '
      'is what is saved', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    await type(tester, 'Distance (optional)', '3.1');

    await tester.tap(find.bySemanticsLabel('Change the entry'));
    await settle(tester);
    final group = table.groups.first;
    expect(find.text('Other entries for Running'), findsOneWidget);
    expect(find.text('MET ${group.general.metText}'), findsWidgets);
    for (final e in [group.general, ...group.bands]) {
      expect(
        find.byKey(ValueKey('entry-${e.code}')),
        findsOneWidget,
        reason: e.code,
      );
    }
    expect(find.text('In use'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-12060')));
    await settle(tester);
    expect(find.textContaining('code 12060'), findsOneWidget);
    expect(find.textContaining('You chose this entry.'), findsOneWidget);
    expect(find.text('383 kcal estimate'), findsNothing);
    await save(tester);
    final row = (await sessions(tester)).last;
    expect(row.activityCode, '12060');
    expect(row.met, 9.8);
  });

  h.appTest('Other... searches the Compendium names; the pick shows its '
      'MET, is saved, and is a chip next time', (tester) async {
    await weigh(tester);
    await openApp(tester);
    await openCardio(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Other...'));
    await settle(tester);
    expect(find.text(S.cardioSearchPrompt), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, S.cardioSearchHint),
      'rowing',
    );
    await settle(tester);
    final rows = table
        .search('rowing')
        .where((a) => table.groupOf(a.code) == null);
    final pick = rows.first;
    await tester.tap(find.byKey(ValueKey('activity-${pick.code}')));
    await settle(tester);

    // The search closed, and the pick is in bold with its MET, no second route.
    expect(find.text(S.cardioSearchTitle), findsNothing);
    expect(
      find.textContaining(
        'Matched ${pick.description}, code ${pick.code}, MET ${pick.metText}.',
      ),
      findsOneWidget,
    );
    await type(tester, 'Duration', '20');
    expect(
      find.text(
        S.cardioBarEstimate(S.count((pick.met * lbToKg(181.8) / 3).round())),
      ),
      findsOneWidget,
    );
    await save(tester);
    final row = (await sessions(tester)).single;
    expect(row.activityCode, pick.code);
    expect(row.activityName, pick.description);
    expect(row.met, pick.met);

    await openCardio(tester);
    expect(find.widgetWithText(ChoiceChip, pick.description), findsOneWidget);
  });

  h.appTest('with no weigh-in there is no estimate, and the user\'s own '
      'number can still be saved', (tester) async {
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    expect(find.text(S.cardioNeedsWeighIn), findsOneWidget);
    await type(tester, 'Calories (own number)', '300');
    expect(find.text('300 kcal your number'), findsOneWidget);
    expect(find.text('Use estimate'), findsNothing);
    await save(tester);
    final row = (await sessions(tester)).last;
    expect(row.kcalEstimated, isNull);
    expect(row.kcalOverride, 300);
    expect(find.text('Running saved, 300 kcal'), findsOneWidget);
  });

  h.appTest('a zero duration, a bad number and a bad heart rate each get a '
      'plain sentence beside the field, and Save stays off', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '0');
    expect(find.text(S.cardioDurationBad), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    await type(tester, 'Duration', '30');
    await type(tester, 'Distance (optional)', '1.2.3');
    expect(find.text(S.cardioDistanceBad), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    await type(tester, 'Distance (optional)', '');
    await type(tester, 'Avg heart rate (optional)', '0');
    expect(find.text(S.cardioHeartBad), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    await type(tester, 'Avg heart rate (optional)', '');
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
  });

  h.appTest('a failed write keeps the screen and what was typed; Save again '
      'works', (tester) async {
    final gate = _Gate();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    await weigh(tester);
    await seed(tester, input());
    gate.failInserts = true;
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    await tester.tap(saveButton());
    await settle(tester);

    expect(find.byType(CardioScreen), findsOneWidget);
    expect(find.text(S.cardioFailed), findsOneWidget);
    expect(tester.widget<TextField>(field('Duration')).controller!.text, '30');
    expect(await sessions(tester), hasLength(1));
    gate.failInserts = false;
    await save(tester);
    expect(find.byType(CardioScreen), findsNothing);
    expect(await sessions(tester), hasLength(2));
  });

  h.appTest('two quick taps on Save write one session, and the screen closes '
      'only after the write returns', (tester) async {
    final gate = _Gate();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    gate.hold = Completer<void>();
    await tester.tap(saveButton());
    await tester.pump();
    await tester.tap(saveButton(), warnIfMissed: false);
    await settle(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
    gate.hold!.complete();
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CardioScreen), findsNothing);
    expect(await sessions(tester), hasLength(2));
  });

  h.appTest('a second tap on Cardio while the screen is open opens one '
      'screen', (tester) async {
    await weigh(tester);
    await openApp(tester);
    await tester.tap(bar('Cardio'));
    await tester.pump();
    await tester.tap(bar('Cardio'), warnIfMissed: false);
    await settle(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
    await h.back(tester);
    expect(find.byType(CardioScreen), findsNothing);
  });

  h.appTest('Change sets another day and time; that day\'s weigh-in is used '
      'and a time not yet happened is refused', (tester) async {
    await h.real(
      tester,
      () => h.db.saveWeight(150, imp, at('2026-11-03', 7, 0)).then((_) {}),
    );
    await weigh(tester);
    await seed(tester, input());
    int offsetAt(DateTime local) => -360;
    await openApp(tester);
    // Home opens the screen with the system offset; a test passes its own by
    // pushing the screen itself.
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(openCardioScreen(context, offsetAt: offsetAt));
    await settle(tester);
    await type(tester, 'Duration', '30');
    await type(tester, 'Distance (optional)', '3.1');
    expect(find.text('Today, 5:29 pm'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Change the date and time'));
    await settle(tester);
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await settle(tester);
    final boxes = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(boxes.at(0), '9');
    await tester.enterText(boxes.at(1), '30');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await settle(tester);

    expect(find.text('Thu, Nov 5, 9:30 am'), findsOneWidget);
    // 150 lb, the weigh-in on or before Nov 5.
    expect(find.text('MET 9.3, 150.0 lb, 30 min'), findsOneWidget);
    await save(tester);
    final row = (await sessions(tester)).last;
    expect(row.localDate, '2026-11-05');
    expect(row.kcalEstimated, closeTo(9.3 * lbToKg(150) * 0.5, 1e-9));
    expect(row.tzOffsetMinutes, -360);
  });

  h.appTest('metric: distance in km, the pace in mph and km/h, and meters '
      'stored', (tester) async {
    await h.real(tester, () => h.db.setUnits(UnitSystem.metric));
    await h.real(
      tester,
      () => h.db
          .saveWeight(82.5, UnitSystem.metric, at('2026-11-09', 7, 0))
          .then((_) {}),
    );
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    expect(find.text('km'), findsOneWidget);
    await type(tester, 'Duration', '30');
    await type(tester, 'Distance (optional)', '5');
    expect(
      find.textContaining('Your pace, 6.2 mph (10 km/h), is in this band.'),
      findsOneWidget,
    );
    expect(find.text('MET 9.3, 82.5 kg, 30 min'), findsOneWidget);
    await save(tester);
    expect((await sessions(tester)).last.distanceMeters, 5000);
    expect(find.textContaining(' lb'), findsNothing);
  });

  // Home: the Exercise rows (frame 5)

  h.appTest('Home lists the day\'s sessions and finished workouts, and '
      '"Nothing yet." when there are none', (tester) async {
    await weigh(tester);
    await openApp(tester);
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Nothing yet.'), findsOneWidget);
  });

  h.appTest('the rows say what was done, imported ones say where from, and '
      'a finished workout is listed with them', (tester) async {
    await weigh(tester);
    await seed(tester, input(), at('2026-11-12', 12, 0));
    await h.real(tester, () async {
      await h.db
          .into(h.db.cardioSessions)
          .insert(
            CardioSessionsCompanion.insert(
              localDate: '2026-11-12',
              startedAtMs: at('2026-11-12', 8, 5).utcMs,
              tzOffsetMinutes: -360,
              activityName: 'Hiking',
              durationSeconds: 45 * 60,
              distanceMeters: const Value(5000),
              kcalEstimated: const Value(250),
              source: const Value('health_connect'),
              sourceId: const Value('hc-1'),
            ),
          );
      await h.doWorkout(
        '2026-11-12',
        [
          (squat, 'Squat', [(225, 5), (225, 5)]),
        ],
        hour: 9,
        minutes: 30,
      );
    });
    await openApp(tester);

    expect(find.text('Nothing yet.'), findsNothing);
    expect(find.text('383 kcal'), findsOneWidget);
    expect(find.text('30 min, 3.1 mi, 12:00 pm'), findsOneWidget);
    expect(find.text('Hiking'), findsOneWidget);
    expect(find.text('250 kcal'), findsOneWidget);
    expect(find.text('45 min, 3.11 mi, 8:05 am'), findsOneWidget);
    expect(find.text('From Health Connect'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('1 exercise, 2 sets, 30 min'), findsOneWidget);
    // Earliest first: the imported hike, the workout, then the run.
    final y = [
      for (final t in ['Hiking', 'Squat', '30 min, 3.1 mi, 12:00 pm'])
        tester.getTopLeft(find.text(t)).dy,
    ];
    expect(y[0], lessThan(y[1]));
    expect(y[1], lessThan(y[2]));
  });

  h.appTest('Cycling is the word for the Bicycling group', (tester) async {
    await weigh(tester);
    await seed(tester, input(code: cycling, miles: null));
    await openApp(tester);
    expect(find.text('Cycling'), findsOneWidget);
    expect(find.text('Bicycling'), findsNothing);
  });

  // Edit and delete (frame 5)

  h.appTest('tapping a row reopens the screen with its values; a change is '
      'saved, says so, and keeps the stored estimate and meters', (
    tester,
  ) async {
    await weigh(tester);
    final s = await seed(
      tester,
      CardioInput(
        activityCode: running,
        durationSeconds: 1800,
        distanceMeters: 5000, // 3.11 mi on screen
        avgHeartRate: 140,
      ),
    );
    // A later weigh-in must not change the stored estimate.
    await h.real(
      tester,
      () => h.db.saveWeight(150, imp, at('2026-11-12', 13, 0)).then((_) {}),
    );
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);

    String text(String label) =>
        tester.widget<TextField>(field(label)).controller!.text;
    expect(text('Duration'), '30');
    expect(text('Distance (optional)'), '3.11');
    expect(text('Avg heart rate (optional)'), '140');
    expect(find.widgetWithText(ChoiceChip, 'Running'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Running'))
          .selected,
      isTrue,
    );

    await type(tester, 'Avg heart rate (optional)', '150');
    expect(
      find.text('${S.count(roundForDisplay(s.kcalEstimated!))} kcal estimate'),
      findsOneWidget,
    );
    await save(tester);

    expect(
      find.text(
        'Running changed, ${S.count(roundForDisplay(s.kcalEstimated!))} kcal',
      ),
      findsOneWidget,
    );
    expect(undo(), findsNothing); // the old version is not kept
    final row = (await sessions(tester)).single;
    expect(row.avgHeartRate, 150);
    expect(row.distanceMeters, 5000); // not read back from "3.11"
    expect(row.kcalEstimated, s.kcalEstimated);
    expect(row.activityCode, s.activityCode);
  });

  h.appTest('a changed duration works the estimate out again from the '
      'weigh-in and the pace', (tester) async {
    await weigh(tester);
    final s = await seed(tester, input());
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);
    await type(tester, 'Duration', '60');
    // 3.1 mi in 60 min is 3.1 mph: another entry than the run.
    expect(find.textContaining('code 12050'), findsNothing);
    await save(tester);
    final row = (await sessions(tester)).single;
    expect(row.durationSeconds, 3600);
    expect(row.kcalEstimated, isNot(s.kcalEstimated));
    expect(row.distanceMeters, s.distanceMeters);
  });

  h.appTest('an edit keeps the entry that was chosen before, unless the '
      'duration or distance changes', (tester) async {
    await weigh(tester);
    final s = await seed(tester, input(entry: '12060')); // chose 9.8 MET
    expect(s.activityCode, '12060');
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);
    expect(find.textContaining('code 12060'), findsOneWidget);
    await type(tester, 'Avg heart rate (optional)', '131');
    expect(find.textContaining('code 12060'), findsOneWidget);
    await save(tester);
    expect((await sessions(tester)).single.activityCode, '12060');
  });

  h.appTest('Delete is in the menu; Home says so with Undo, once, and the '
      'row comes back', (tester) async {
    await weigh(tester);
    final s = await seed(tester, input());
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);
    await tester.tap(find.byTooltip(S.cardioMenu));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CardioScreen), findsNothing);
    expect(find.text('Running deleted, 383 kcal'), findsOneWidget);
    expect(find.byKey(ValueKey('cardio-${s.id}')), findsNothing);
    expect((await sessions(tester)).single.deletedAtMs, isNotNull);

    await tester.tap(undo());
    await tester.tap(undo(), warnIfMissed: false);
    await settle(tester);
    expect((await sessions(tester)).single.deletedAtMs, isNull);
    expect(find.byKey(ValueKey('cardio-${s.id}')), findsOneWidget);
    expect(find.text('Running deleted, 383 kcal'), findsNothing);
  });

  h.appTest('the Undo of a save is gone after ten seconds', (tester) async {
    await weigh(tester);
    await openApp(tester);
    await openCardio(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Other...'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, S.cardioSearchHint),
      'yoga',
    );
    await settle(tester);
    await tester.tap(
      find.byKey(ValueKey('activity-${table.search('yoga').first.code}')),
    );
    await settle(tester);
    await type(tester, 'Duration', '20');
    await save(tester);
    expect(undo(), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(undo(), findsNothing);
  });

  h.appTest('a session imported with no code can be opened and edited '
      '(time, duration, calories)', (tester) async {
    await weigh(tester);
    final id = await h.real(
      tester,
      () => h.db
          .into(h.db.cardioSessions)
          .insert(
            CardioSessionsCompanion.insert(
              localDate: '2026-11-12',
              startedAtMs: at('2026-11-12', 8, 0).utcMs,
              tzOffsetMinutes: -360,
              activityName: 'Imported run',
              durationSeconds: 1800,
              kcalEstimated: const Value(250),
              source: const Value('apple_health'),
              sourceId: const Value('ah-1'),
            ),
          ),
    );
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-$id')));
    await settle(tester);
    expect(find.text('From Apple Health'), findsOneWidget);
    expect(find.text('Imported run'), findsWidgets);
    expect(find.text(S.cardioNoEntry), findsOneWidget);
    expect(find.text('250 kcal estimate'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await type(tester, 'Duration', '40');
    await type(tester, 'Calories (own number)', '300');
    expect(find.text('300 kcal your number'), findsOneWidget);
    expect(find.text('Estimate was 250.'), findsOneWidget);
    await save(tester);
    final row = (await sessions(tester)).single;
    expect(row.durationSeconds, 2400);
    expect(row.kcalOverride, 300);
    expect(row.kcalEstimated, 250);
    expect(row.source, 'apple_health');
    expect(row.activityName, 'Imported run');
    expect(row.activityCode, isNull);
  });

  h.appTest('a session with a code the table does not have can be edited', (
    tester,
  ) async {
    await weigh(tester);
    final id = await h.real(
      tester,
      () => h.db
          .into(h.db.cardioSessions)
          .insert(
            CardioSessionsCompanion.insert(
              localDate: '2026-11-12',
              startedAtMs: at('2026-11-12', 8, 0).utcMs,
              tzOffsetMinutes: -360,
              activityCode: const Value('77777'),
              activityName: 'Rowing machine',
              met: const Value(5),
              durationSeconds: 1800,
              kcalEstimated: const Value(200),
              source: const Value('health_connect'),
              sourceId: const Value('hc-9'),
            ),
          ),
    );
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-$id')));
    await settle(tester);
    expect(find.text('MET 5.0, kept as it was saved.'), findsOneWidget);
    await type(tester, 'Duration', '60');
    expect(
      find.text('${S.count(roundForDisplay(5 * lbToKg(181.8)))} kcal estimate'),
      findsOneWidget,
    );
    await save(tester);
    final row = (await sessions(tester)).single;
    expect(row.activityCode, '77777');
    expect(row.met, 5);
    expect(row.kcalEstimated, closeTo(5 * lbToKg(181.8), 1e-9));
  });

  // Layout, keyboard, words

  h.appTest('the keyboard up leaves Save and the fields in view, and what '
      'was typed survives a fold', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester, size: const Size(360, 640));
    await openCardio(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await settle(tester);
    await type(tester, 'Duration', '30');
    expect(tester.getRect(saveButton()).bottom, lessThanOrEqualTo(640 - 300));
    expect(tester.takeException(), isNull);

    // Unfold: the same screen, the same text.
    tester.view.physicalSize = const Size(673, 700);
    await settle(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
    expect(tester.widget<TextField>(field('Duration')).controller!.text, '30');
    expect(find.text('383 kcal estimate'), findsOneWidget);
  });

  for (final size in [const Size(344, 800), const Size(673, 800)]) {
    for (final scale in [1.0, 2.0]) {
      h.appTest('layout at ${size.width.round()} dp and text scale $scale: '
          'nothing overflows and every target is 48 dp', (tester) async {
        await weigh(tester);
        // The longest activity name there is, as a chip.
        table = (await tester.runAsync(MetTable.load))!;
        final longest = table.all.reduce(
          (a, b) => a.description.length >= b.description.length ? a : b,
        );
        await seed(
          tester,
          input(code: longest.code, miles: null),
          at('2026-11-10', 8, 0),
        );
        await seed(tester, input());
        await seed(
          tester,
          input(code: walking, miles: null),
          at('2026-11-11', 8, 0),
        );
        await openApp(tester, size: size, scale: scale);
        await openCardio(tester);
        await type(tester, 'Duration', '30');
        await type(tester, 'Distance (optional)', '3.1');
        await type(tester, 'Calories (own number)', '360');

        final targets = [
          find.byType(ChoiceChip),
          find.byType(ActionChip),
          find.byType(TextField),
          find.widgetWithText(FilledButton, 'Save'),
          find.widgetWithText(TextButton, 'Use estimate'),
          find.widgetWithText(TextButton, 'Change'),
        ];
        for (final f in targets) {
          for (var i = 0; i < f.evaluate().length; i++) {
            final box = tester.getSize(f.at(i));
            expect(box.height, greaterThanOrEqualTo(48), reason: '$f $i');
            expect(box.width, greaterThanOrEqualTo(48), reason: '$f $i');
          }
        }
        // The page scrolls to the end with nothing cut off.
        await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  // The speed target: one screen, three counted taps, no second route.

  testWidgets('speed target 6: open, Next, Save are 3 counted taps, and no '
      'route is pushed after the screen opens', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(db.close);
    });
    table = (await tester.runAsync(MetTable.load))!;
    await tester.runAsync(() async {
      await db.saveWeight(181.8, imp, at('2026-11-09', 7, 0));
      await db.saveCardio(table, input(), at('2026-11-12', 12, 0));
    });
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pushes = _Pushes();
    await tester.pumpWidget(
      AppScope(
        db: db,
        clock: () => at('2026-11-12', 17, 29),
        foodsPath: Future.value(''),
        child: MaterialApp(
          navigatorObservers: [pushes],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => openCardioScreen(context),
                  child: const Text('Cardio'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    final before = pushes.count;
    final taps = TapCounter(tester);

    await taps.tap(find.widgetWithText(FilledButton, 'Cardio')); // tap 1
    await settle(tester);
    expect(pushes.count, before + 1); // the screen itself
    final opened = pushes.count;
    expect(focused(tester, 'Duration'), isTrue);

    await taps.type(field('Duration'), '30');
    await taps.keyboardAction(TextInputAction.next); // tap 2
    await tester.pump();
    expect(focused(tester, 'Distance (optional)'), isTrue);
    await taps.type(field('Distance (optional)'), '3.1');
    await settle(tester);
    await taps.tap(saveButton()); // tap 3
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));

    taps.expectCount(3, flow: 'Log a cardio session');
    expect(pushes.count, opened, reason: 'nothing after the screen opened');
    expect(find.byType(CardioScreen), findsNothing);
    final rows = await tester.runAsync(
      () => db.select(db.cardioSessions).get(),
    );
    expect(rows, hasLength(2));
    expect(rows!.last.kcalEstimated, closeTo(383.45, 0.01));
    expect(rows.last.activityCode, '12050');
  });
}
