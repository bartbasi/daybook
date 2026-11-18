// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:daybook/app_scope.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/cardio_data.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/met_table.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/data/workout_data.dart';
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

/// A database that can hold or refuse the insert of a session, and refuse an
/// update of one (a delete, an Undo, an edit).
class _Gate extends QueryInterceptor {
  Completer<void>? hold;
  var failInserts = false;
  var failUpdates = false;

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (failUpdates && statement.contains('cardio_sessions')) {
      throw Exception('disk full');
    }
    return super.runUpdate(executor, statement, args);
  }

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

/// Holds reads of the weigh-ins, so a test can look at the screen while a
/// preview is on its way. Each read takes the next gate in [queue], if there
/// is one, and waits for it; with none queued a read goes straight through.
class _HoldWeights extends QueryInterceptor {
  final queue = <Completer<void>>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('weight_entries') && queue.isNotEmpty) {
      await queue.removeAt(0).future;
    }
    return super.runSelect(executor, statement, args);
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

  /// Types into a field, scrolling to it first when it is not in view, as a
  /// person would (the list builds only the rows in view).
  Future<void> type(WidgetTester tester, String label, String text) async {
    final f = field(label);
    if (f.hitTestable().evaluate().isEmpty) {
      if (f.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).first,
        );
      } else {
        await tester.ensureVisible(f);
      }
      await tester.pump();
    }
    await tester.enterText(f, text);
    await settle(tester);
  }

  // The two Change buttons: the day and time, then (when there is a matched
  // line) the entry.
  Finder changeTime() => find.widgetWithText(TextButton, 'Change').first;
  Finder changeEntry() => find.widgetWithText(TextButton, 'Change').last;
  Finder logCardio() => find.widgetWithText(OutlinedButton, S.logCardio);

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

    await tester.tap(changeEntry());
    await settle(tester);
    final group = table.groups.first;
    expect(find.text('Other entries for Running'), findsOneWidget);
    // The list builds only the rows in view: scroll to each one, top to
    // bottom, as a person would.
    final scroll = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    Finder entry(String code) => find.byKey(ValueKey('entry-$code'));
    // The entry the pace chose is marked, once, and it is near the top.
    expect(
      find.descendant(of: entry('12050'), matching: find.text('In use')),
      findsOneWidget,
    );
    expect(find.text('In use'), findsOneWidget);
    for (final e in [group.general, ...group.bands]) {
      await tester.scrollUntilVisible(entry(e.code), 200, scrollable: scroll);
      expect(entry(e.code), findsOneWidget, reason: e.code);
      expect(
        find.descendant(of: entry(e.code), matching: find.text('MET ${e.metText}')),
        findsOneWidget,
        reason: e.code,
      );
    }
    // Back to the top, where 12060 (MET 10.5) is in view.
    await tester.drag(scroll, const Offset(0, 5000));
    await settle(tester);

    await tester.tap(entry('12060'));
    await settle(tester);
    expect(find.textContaining('code 12060'), findsOneWidget);
    expect(find.textContaining('You chose this entry.'), findsOneWidget);
    expect(find.text('383 kcal estimate'), findsNothing);
    // MET 10.5 x 82.46309 kg x 0.5 h = 432.9
    expect(find.text('433 kcal estimate'), findsOneWidget);
    await save(tester);
    final row = (await sessions(tester)).last;
    expect(row.activityCode, '12060');
    expect(row.met, 10.5);
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
    // A new session is never "gone", and Save stays usable for another try.
    expect(find.text(S.cardioGone), findsNothing);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
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
    // It closes with an X, not a back arrow.
    await tester.tap(find.byType(CloseButton));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
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

    await tester.tap(changeTime());
    await settle(tester);
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await settle(tester);
    // The clock reads 5:29 pm, so the picker opens on PM: choose AM. (The
    // weight sheet's test needs no tap, its clock reads 7:02 am.)
    await tester.tap(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text('AM'),
      ),
    );
    await tester.pump();
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

  // Review fixes for task 5.3. Each test names the fix it covers.

  // A1: the "a screen is open" flag is cleared when the screen leaves the
  // tree. This test ends with the screen open and the tree unmounted, as
  // every harness does, and the next one must still be able to open it.
  h.appTest('a test can end with the cardio screen open (first of two)', (
    tester,
  ) async {
    await weigh(tester);
    await openApp(tester);
    await openCardio(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
  });

  h.appTest('the screen still opens in the next test (second of two)', (
    tester,
  ) async {
    await weigh(tester);
    await openApp(tester);
    await openCardio(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Other...'), findsOneWidget);
  });

  // A2
  h.appTest('Change for Walking lists each entry once, though the general '
      'entry is also one of its bands', (tester) async {
    await weigh(tester);
    await seed(tester, input(code: walking, miles: null));
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    await tester.tap(changeEntry());
    await settle(tester);

    final group = table.groups[1];
    expect(group.name, 'Walking');
    final listed = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('entry-'),
    );
    expect(listed, findsNWidgets(group.bands.length));
    expect(find.byKey(const ValueKey('entry-17190')), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // A3
  h.appTest('a screen reader can pick a chip, open Other... and Change: each '
      'has a tap action', (tester) async {
    await weigh(tester);
    await seed(tester, input(code: walking, miles: null), at('2026-11-11', 8, 0));
    await seed(tester, input());
    await openApp(tester);
    final handle = tester.ensureSemantics();
    await openCardio(tester);
    await type(tester, 'Duration', '30');

    for (final label in [
      'Walking',
      S.cardioOtherSpoken,
      S.cardioChangeEntrySpoken,
      S.cardioChangeTimeSpoken,
    ]) {
      final node = find.semantics.byLabel(label);
      expect(node, findsOneWidget, reason: label);
      expect(
        node.evaluate().single.getSemanticsData().hasAction(
          SemanticsAction.tap,
        ),
        isTrue,
        reason: label,
      );
    }
    // Performing the action picks the activity.
    tester.semantics.tap(find.semantics.byLabel('Walking'));
    await settle(tester);
    expect(find.semantics.byLabel('Walking, picked'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Walking'))
          .selected,
      isTrue,
    );
    // And Other... opens its search.
    tester.semantics.tap(find.semantics.byLabel(S.cardioOtherSpoken));
    await settle(tester);
    expect(find.text(S.cardioSearchTitle), findsOneWidget);
    handle.dispose();
  });

  // A5: a Running, Walking or Cycling row found with Other... is the entry
  // in use, as if chosen with Change.
  h.appTest('Other... with Running already picked: a Running row found there '
      'is the entry used, and is saved', (tester) async {
    await weigh(tester);
    await seed(tester, input()); // Running, last entry 12050
    await openApp(tester);
    await openCardio(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Other...'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, S.cardioSearchHint),
      'running 7 mph 8.5',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('activity-12070')));
    await settle(tester);

    expect(find.textContaining('code 12070'), findsOneWidget);
    expect(find.textContaining('You chose this entry.'), findsOneWidget);
    await type(tester, 'Duration', '30');
    await save(tester);
    final row = (await sessions(tester)).last;
    expect(row.activityCode, '12070');
    expect(row.activityName, 'Running');
    expect(row.met, 11);
  });

  h.appTest('Other... with another activity picked: a Running row found '
      'there picks Running and is the entry used', (tester) async {
    await weigh(tester);
    await seed(tester, input(code: walking, miles: null));
    await openApp(tester);
    await openCardio(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Other...'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, S.cardioSearchHint),
      'running 7 mph 8.5',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('activity-12070')));
    await settle(tester);

    expect(find.textContaining('code 12070'), findsOneWidget);
    expect(find.textContaining('You chose this entry.'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Running'))
          .selected,
      isTrue,
    );
    await type(tester, 'Duration', '30');
    await save(tester);
    final row = (await sessions(tester)).last;
    expect(row.activityCode, '12070');
    expect(row.activityName, 'Running');
  });

  // A6
  h.appTest('with a weigh-in on record the bar never says one is needed while '
      'a preview is on its way', (tester) async {
    final hold = _HoldWeights();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(hold));
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    final c = Completer<void>();
    hold.queue.add(c);
    await type(tester, 'Duration', '3');
    expect(find.text(S.cardioNeedsWeighIn), findsNothing);
    c.complete();
    await settle(tester);
    expect(find.text(S.cardioNeedsWeighIn), findsNothing);
    // 9.3 MET x 82.46309 kg x 3 min = 38.3
    expect(find.text('38 kcal estimate'), findsOneWidget);
  });

  h.appTest('picking another activity clears the matched line, the Change '
      'button and the number until its preview arrives', (tester) async {
    final hold = _HoldWeights();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(hold));
    await weigh(tester);
    await seed(tester, input(code: walking, miles: null), at('2026-11-11', 8, 0));
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    expect(find.text('383 kcal estimate'), findsOneWidget);

    final c = Completer<void>();
    hold.queue.add(c);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Walking'));
    await settle(tester);
    expect(find.textContaining('Matched'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Change'), findsOneWidget); // time
    expect(find.text('383 kcal estimate'), findsNothing);
    expect(find.text(S.cardioNeedsWeighIn), findsNothing);

    c.complete();
    await settle(tester);
    expect(find.textContaining('code 17190'), findsOneWidget);
    // 3.8 MET x 82.46309 kg x 0.5 h = 156.7
    expect(find.text('157 kcal estimate'), findsOneWidget);
  });

  // The preview of an older change must not overwrite a newer one.
  h.appTest('an older preview that arrives late does not overwrite a newer '
      'one', (tester) async {
    final hold = _HoldWeights();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(hold));
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);

    final first = Completer<void>();
    hold.queue.add(first); // the read for 30 minutes waits
    await type(tester, 'Duration', '30');
    await type(tester, 'Duration', '60'); // this read goes straight through
    // 9.3 MET x 82.46309 kg x 1 h = 766.9
    expect(find.text('767 kcal estimate'), findsOneWidget);
    first.complete();
    await settle(tester);
    expect(find.text('767 kcal estimate'), findsOneWidget);
    expect(find.text('383 kcal estimate'), findsNothing);
  });

  // A7
  h.appTest('at a large text size the Change button is under the matched '
      'line, not beside it', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester, size: const Size(344, 800), scale: 2);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    final line = tester.getRect(find.textContaining('Matched Running'));
    final change = tester.getRect(changeEntry());
    expect(change.top, greaterThanOrEqualTo(line.bottom - 0.5));
    expect(tester.takeException(), isNull);
  });

  // A8
  h.appTest('on an edit, picking Walking and then Running again keeps the '
      'entry that was chosen', (tester) async {
    await weigh(tester);
    await seed(tester, input(code: walking, miles: null), at('2026-11-11', 8, 0));
    final s = await seed(tester, input(entry: '12060')); // 3.1 mi, chose 10.5
    expect(s.activityCode, '12060');
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);
    expect(find.textContaining('code 12060'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Walking'));
    await settle(tester);
    expect(find.textContaining('Matched Walking'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Running'));
    await settle(tester);
    // Not the entry the pace would pick (12050): the stored choice is back.
    expect(find.textContaining('code 12060'), findsOneWidget);
    await save(tester);
    final row = (await sessions(tester)).firstWhere((r) => r.id == s.id);
    expect(row.activityCode, '12060');
    expect(row.met, 10.5);
  });

  // A9
  h.appTest('a row under Exercise is one spoken line with a tap action', (
    tester,
  ) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    final handle = tester.ensureSemantics();
    final node = find.semantics.byLabel(
      'Running, 383 kcal, 30 min, 3.1 mi, 12:00 pm',
    );
    expect(node, findsOneWidget);
    expect(
      node.evaluate().single.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    // Its pieces are not read one by one.
    expect(find.semantics.byLabel('383 kcal'), findsNothing);
    handle.dispose();
  });

  // A10
  h.appTest('the units show beside the fields before anything is typed', (
    tester,
  ) async {
    await weigh(tester);
    await openApp(tester);
    await openCardio(tester);
    for (final (label, unit) in [
      ('Duration', 'min'),
      ('Distance (optional)', 'mi'),
      ('Avg heart rate (optional)', 'bpm'),
      ('Calories (own number)', 'kcal'),
    ]) {
      expect(find.text(unit), findsOneWidget, reason: unit);
      expect(
        tester.getRect(find.text(unit)).left,
        greaterThanOrEqualTo(tester.getRect(field(label)).right - 0.5),
        reason: '$unit is beside $label',
      );
    }
  });

  // A11
  h.appTest('the screen closes with an X', (tester) async {
    await weigh(tester);
    await openApp(tester);
    await openCardio(tester);
    expect(find.byType(CloseButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CardioScreen), findsNothing);
  });

  // A12
  h.appTest('a session of under half a minute shows a short duration, not '
      '0, and can still be saved', (tester) async {
    await weigh(tester);
    final s = await seed(
      tester,
      const CardioInput(activityCode: running, durationSeconds: 25),
    );
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);
    expect(tester.widget<TextField>(field('Duration')).controller!.text, '0.4');
    expect(find.text(S.cardioDurationBad), findsNothing);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
    await type(tester, 'Avg heart rate (optional)', '120');
    await save(tester);
    final row = (await sessions(tester)).single;
    expect(row.durationSeconds, 25); // the stored seconds, not "0.4" read back
    expect(row.avgHeartRate, 120);
  });

  // A13
  h.appTest('Change on a session dated before the earliest day opens the '
      'date picker on that day', (tester) async {
    await weigh(tester);
    final id = await h.real(
      tester,
      () => h.db
          .into(h.db.cardioSessions)
          .insert(
            CardioSessionsCompanion.insert(
              localDate: '1999-12-31',
              startedAtMs: at('1999-12-31', 8, 0).utcMs,
              tzOffsetMinutes: -360,
              activityName: 'Imported run',
              durationSeconds: 1800,
              source: const Value('health_connect'),
              sourceId: const Value('hc-old'),
            ),
          ),
    );
    final row = (await h.real(tester, () => h.db.cardioSession(id)))!;
    await openApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(openCardioScreen(context, editing: row));
    await settle(tester);
    await tester.tap(changeTime());
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  // The words and the layout.
  h.appTest('with no distance the general entry says how to match a pace, '
      'and a distance replaces that line', (tester) async {
    await weigh(tester);
    await seed(tester, input(code: running, miles: null)); // the general entry
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    expect(
      find.textContaining(
        'Matched Running, self-selected pace, code 12145, MET 10.5. '
        'General entry. Add a distance to match your pace.',
      ),
      findsOneWidget,
    );
    await type(tester, 'Distance (optional)', '3.1');
    expect(find.textContaining('General entry.'), findsNothing);
    expect(find.textContaining('is in this band.'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    h.appTest('at 344 dp and text scale $scale every chip is fully in view, '
        'with no swipe', (tester) async {
      await weigh(tester);
      table = (await tester.runAsync(MetTable.load))!;
      final longest = table.all.reduce(
        (a, b) => a.description.length >= b.description.length ? a : b,
      );
      await seed(
        tester,
        input(code: longest.code, miles: null),
        at('2026-11-10', 8, 0),
      );
      await seed(tester, input(), at('2026-11-12', 12, 0));
      await seed(
        tester,
        input(code: walking, miles: null),
        at('2026-11-11', 8, 0),
      );
      await openApp(tester, size: const Size(344, 800), scale: scale);
      await openCardio(tester);
      for (final f in [find.byType(ChoiceChip), find.byType(ActionChip)]) {
        expect(f, findsWidgets);
        for (var i = 0; i < f.evaluate().length; i++) {
          final r = tester.getRect(f.at(i));
          expect(r.left, greaterThanOrEqualTo(0), reason: '$f $i');
          expect(r.right, lessThanOrEqualTo(344), reason: '$f $i');
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  // Edit: Use estimate on a session that had its own number.
  h.appTest('Use estimate on an edit clears the stored own number and keeps '
      'the stored estimate', (tester) async {
    await weigh(tester);
    final s = await seed(tester, input(override: 360));
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);
    expect(find.text('360 kcal your number'), findsOneWidget);
    expect(find.text('Estimate was 383.'), findsOneWidget);
    await tester.tap(find.text('Use estimate'));
    await settle(tester);
    expect(find.text('383 kcal estimate'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('Calories (own number)')).controller!.text,
      isEmpty,
    );
    await save(tester);
    expect(find.text('Running changed, 383 kcal'), findsOneWidget);
    final row = (await sessions(tester)).single;
    expect(row.kcalOverride, isNull);
    expect(row.kcalEstimated, s.kcalEstimated);
  });

  // Delete and Undo that fail.
  h.appTest('a delete that fails keeps the screen and says so; trying again '
      'works', (tester) async {
    final gate = _Gate();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    await weigh(tester);
    final s = await seed(tester, input());
    await openApp(tester);
    await tester.tap(find.byKey(ValueKey('cardio-${s.id}')));
    await settle(tester);

    gate.failUpdates = true;
    await tester.tap(find.byTooltip(S.cardioMenu));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
    expect(find.text(S.cardioDeleteFailed), findsOneWidget);
    expect(find.text(S.cardioGone), findsNothing);
    expect((await sessions(tester)).single.deletedAtMs, isNull);

    gate.failUpdates = false;
    await tester.tap(find.byTooltip(S.cardioMenu));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CardioScreen), findsNothing);
    expect(find.text('Running deleted, 383 kcal'), findsOneWidget);
  });

  h.appTest('an Undo of a save that fails says the session is still saved', (
    tester,
  ) async {
    final gate = _Gate();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    await save(tester);
    expect(find.text('Running saved, 383 kcal'), findsOneWidget);

    gate.failUpdates = true;
    await tester.tap(undo());
    await settle(tester);
    expect(find.text(S.cardioUndoFailed), findsOneWidget);
    expect(find.text('Running saved, 383 kcal'), findsNothing);
    final rows = await sessions(tester);
    expect(rows, hasLength(2));
    expect(rows.last.deletedAtMs, isNull);
  });

  h.appTest('an Undo of a delete that fails says the session is still '
      'deleted', (tester) async {
    final gate = _Gate();
    h.db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
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
    expect(find.text('Running deleted, 383 kcal'), findsOneWidget);

    gate.failUpdates = true;
    await tester.tap(undo());
    await settle(tester);
    expect(find.text(S.cardioUndoDeleteFailed), findsOneWidget);
    expect((await sessions(tester)).single.deletedAtMs, isNotNull);
  });

  // Home: a session saved for another day, and the day Home shows.
  h.appTest('Home says the day when a session is saved for another day, and '
      'does not list it under today', (tester) async {
    await h.real(
      tester,
      () => h.db.saveWeight(150, imp, at('2026-11-03', 7, 0)).then((_) {}),
    );
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await openCardio(tester);
    await type(tester, 'Duration', '30');
    await tester.tap(changeTime());
    await settle(tester);
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.text('AM'),
      ),
    );
    await tester.pump();
    final boxes = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(boxes.at(0), '9');
    await tester.enterText(boxes.at(1), '30');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await settle(tester);
    await save(tester);

    // 150 lb, the weigh-in on or before Nov 5: 9.3 x 68.04 kg x 0.5 h = 316.
    expect(find.text('Running saved for Thu, Nov 5, 316 kcal'), findsOneWidget);
    final row = (await sessions(tester)).last;
    expect(row.localDate, '2026-11-05');
    expect(find.byKey(ValueKey('cardio-${row.id}')), findsNothing);
  });

  h.appTest('Home lists the sessions of the day it shows, and follows the day '
      'when it changes', (tester) async {
    await weigh(tester);
    await seed(tester, input(), at('2026-11-12', 12, 0));
    await seed(tester, input(minutes: 20, miles: null), at('2026-11-13', 9, 0));
    await openApp(tester);
    expect(find.text('30 min, 3.1 mi, 12:00 pm'), findsOneWidget);
    expect(find.text('20 min, 9:00 am'), findsNothing);

    h.now = at('2026-11-13', 0, 1);
    await tester.pump(const Duration(hours: 7));
    await settle(tester);
    expect(find.text('20 min, 9:00 am'), findsOneWidget);
    expect(find.text('30 min, 3.1 mi, 12:00 pm'), findsNothing);
  });

  // The Workouts tab: Log cardio (task 5.3).

  h.appTest('Log cardio on the Workouts tab opens the screen', (tester) async {
    await weigh(tester);
    await openApp(tester);
    await h.openWorkoutsTab(tester);
    await tester.tap(logCardio());
    await settle(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
  });

  h.appTest('after Save the Workouts tab says so, and Undo deletes the '
      'session', (tester) async {
    await weigh(tester);
    await seed(tester, input());
    await openApp(tester);
    await h.openWorkoutsTab(tester);
    await tester.tap(logCardio());
    await settle(tester);
    await type(tester, 'Duration', '30');
    await save(tester);

    expect(find.byType(CardioScreen), findsNothing);
    expect(find.text('Running saved, 383 kcal'), findsOneWidget);
    expect(await sessions(tester), hasLength(2));

    await tester.tap(undo());
    await tester.tap(undo(), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Running saved, 383 kcal'), findsNothing);
    expect(await h.real(tester, () => h.db.cardioForDay('2026-11-12')), hasLength(1));
  });

  h.appTest('Log cardio is there while a workout runs', (tester) async {
    await weigh(tester);
    await h.real(
      tester,
      () => h.db.startEmptyWorkout(at('2026-11-12', 17, 0)).then((_) {}),
    );
    await openApp(tester);
    await h.openWorkoutsTab(tester);
    // Only "Return to workout" starts anything now, and Log cardio stays.
    expect(find.widgetWithText(OutlinedButton, 'Empty workout'), findsNothing);
    expect(logCardio(), findsOneWidget);
    await tester.tap(logCardio());
    await settle(tester);
    expect(find.byType(CardioScreen), findsOneWidget);
  });

  h.appTest('Log cardio does not push the Start again rows out of view at '
      '320 x 568 (speed target 4)', (tester) async {
    await h.seedSample(tester);
    await h.openApp(tester, size: const Size(320, 568));
    await h.openWorkoutsTab(tester);
    expect(find.text('Start again'), findsOneWidget);
    final box = tester.getRect(
      find.widgetWithText(FilledButton, 'Start').first,
    );
    expect(box.top >= 0 && box.bottom <= 568, isTrue, reason: '$box');
    // The button is on the tab, below the routines.
    expect(logCardio(), findsOneWidget);
    expect(tester.getRect(logCardio()).top, greaterThan(box.bottom));
  });

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
