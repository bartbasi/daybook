// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// An independent pass over weight reliability (BRIEF.md: "Reliability is the
// requirement"). Written by someone who did not write the weight code, to
// break it. The points the task row names come first, then everything else
// that could lose or corrupt a weigh-in. Each test says in its name what the
// app promises. The data level uses real files in a temp folder where closing
// and reopening matters; the screens run the whole app.

import 'dart:async';
import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/math/weight_trend.dart';
import 'package:daybook/screens/home/home_screen.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/screens/weight/weight_tab.dart';
import 'package:daybook/util/dates.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Now at(String date, int h, int m, int offsetMinutes, [int seconds = 0]) {
  final n = Now.fromLocal(date, h * 60 + m, offsetMinutes);
  return Now(utcMs: n.utcMs + seconds * 1000, offsetMinutes: offsetMinutes);
}

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = at('2026-11-12', 7, 2, -360);

/// Lets a test hold a database write.
class Gate extends QueryInterceptor {
  Completer<void>? hold;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await hold?.future;
    return super.runInsert(executor, statement, args);
  }
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  const imp = UnitSystem.imperial;
  const met = UnitSystem.metric;

  //
  // The data layer, on real files.
  //
  group('on a real database file', () {
    late Directory dir;
    late File file;
    final open = <AppDatabase>[];

    AppDatabase openDb() {
      final db = AppDatabase(NativeDatabase(file));
      open.add(db);
      return db;
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('daybook_weight_');
      file = File('${dir.path}${Platform.pathSeparator}daybook.sqlite');
    });

    // Close every connection first: Windows cannot delete an open file.
    tearDown(() async {
      for (final db in open) {
        await db.close();
      }
      open.clear();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      dir.deleteSync(recursive: true);
    });

    Future<List<WeightEntry>> everyRow(AppDatabase db) => (db.select(
      db.weightEntries,
    )..orderBy([(w) => OrderingTerm.asc(w.id)])).get();

    test('closing and reopening the database keeps every saved row', () async {
      final first = openDb();
      await first.setUnits(met);
      final clock = at('2026-11-12', 7, 2, -360);
      // A mix of everything a user does: saves in both units, a date change,
      // an edit, a delete, a delete that is undone.
      final saved = <WeightEntry>[];
      for (var i = 0; i < 30; i++) {
        saved.add(
          await first.saveWeight(
            i.isEven ? 180 + i / 10 : 82 + i / 10,
            i.isEven ? imp : met,
            clock,
            at: at('2026-10-${10 + i % 20}', 6, i, -360),
          ),
        );
      }
      await first.editWeight(
        saved[3].id,
        190.4,
        imp,
        clock,
        at: at('2026-09-01', 8, 15, -360),
      );
      await first.deleteWeight(saved[5].id, clock);
      await first.deleteWeight(saved[6].id, clock);
      await first.undoDeleteWeight(saved[6].id, clock);

      final rowsBefore = await everyRow(first);
      final listBefore = await first.watchWeights().first;
      List<(String, double, double)> trendOf(List<TrendPoint> points) => [
        for (final p in points) (p.localDate, p.averageKg, p.trendKg),
      ];
      final trendBefore = trendOf(await first.watchTrend().first);
      final latestBefore = await first.latestWeight();
      expect(rowsBefore, hasLength(30));
      await first.close();

      final second = openDb();
      expect(await everyRow(second), rowsBefore, reason: 'every column');
      expect(await second.watchWeights().first, listBefore);
      expect(trendOf(await second.watchTrend().first), trendBefore);
      expect(await second.latestWeight(), latestBefore);
      expect(await second.getUnits(), met, reason: 'the units setting too');

      // The reopened database still takes writes.
      final more = await second.saveWeight(181.8, imp, clock);
      expect(more.id, greaterThan(rowsBefore.last.id));
      expect(await everyRow(second), hasLength(31));
    });

    test('a saved row is on disk at once, without the database being closed '
        '(the app can be killed at any time)', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final writer = openDb();
      final row = await writer.saveWeight(181.8, imp, nowFixed);
      // Nothing is closed or flushed. Another connection, as a restarted app
      // would be, must see the row.
      final reader = openDb();
      expect(await everyRow(reader), [row]);

      await writer.deleteWeight(row.id, nowFixed);
      expect((await everyRow(reader)).single.deletedAtMs, nowFixed.utcMs);
    });

    test('a hundred weigh-ins saved at once all land, each with its own '
        'value', () async {
      final db = openDb();
      final saves = [
        for (var i = 0; i < 100; i++)
          db.saveWeight(
            150 + i / 10,
            imp,
            at('2026-11-12', 7, 2, -360, i),
            at: at('2026-08-${1 + i % 28}', 7, i % 60, -360),
          ),
      ];
      final results = await Future.wait(saves);
      expect({for (final r in results) r.id}, hasLength(100));
      final stored = await everyRow(db);
      expect(stored, hasLength(100));
      final shown = {for (final r in stored) formatWeight(r.weightKg, imp)};
      expect(shown, {
        for (var i = 0; i < 100; i++) (150 + i / 10).toStringAsFixed(1),
      });
      expect(await db.watchWeights().first, hasLength(100));
    });

    test('many saves at the very same instant all stay', () async {
      final db = openDb();
      await Future.wait([
        for (var i = 0; i < 30; i++) db.saveWeight(181.8, imp, nowFixed),
      ]);
      expect(await everyRow(db), hasLength(30));
      final ids = [for (final r in await db.watchWeights().first) r.id];
      expect(
        ids,
        orderedEquals([...ids]..sort((a, b) => b - a)),
        reason: 'the same instant is listed newest id first, every time',
      );
    });

    test('an edit and a delete of the same row at the same time never leave '
        'a live row or a second row', () async {
      for (final editFirst in [true, false]) {
        final db = openDb();
        final row = await db.saveWeight(181.8, imp, nowFixed);
        final outcomes = <String>[];
        Future<void> edit() => db
            .editWeight(row.id, 190.0, imp, nowFixed)
            .then((_) => outcomes.add('edited'))
            .catchError((Object e) => outcomes.add('edit ${e.runtimeType}'));
        Future<void> delete() => db
            .deleteWeight(row.id, nowFixed)
            .then((_) => outcomes.add('deleted'))
            .catchError((Object e) => outcomes.add('delete ${e.runtimeType}'));
        await Future.wait(editFirst ? [edit(), delete()] : [delete(), edit()]);

        final stored = (await everyRow(db)).single;
        expect(stored.deletedAtMs, isNotNull, reason: '$outcomes');
        expect(outcomes, contains('deleted'), reason: 'the delete never fails');
        expect(
          outcomes.where((o) => o != 'deleted' && o != 'edited'),
          everyElement('edit StateError'),
          reason: 'the only allowed failure is "the row is gone"',
        );
        // If the edit won, its number is kept. If it lost, the old one is.
        expect(
          formatWeight(stored.weightKg, imp),
          outcomes.contains('edited') ? '190.0' : '181.8',
        );
        expect(await db.watchWeights().first, isEmpty);
        await db.close();
        open.remove(db);
        file.deleteSync();
      }
    });

    test('two edits of the same row at the same time leave one of the two '
        'numbers, in one row', () async {
      final db = openDb();
      final row = await db.saveWeight(181.8, imp, nowFixed);
      await Future.wait([
        db.editWeight(row.id, 183.0, imp, nowFixed),
        db.editWeight(row.id, 184.0, imp, nowFixed),
      ]);
      final stored = (await everyRow(db)).single;
      expect(['183.0', '184.0'], contains(formatWeight(stored.weightKg, imp)));
      expect(stored.deletedAtMs, isNull);
    });

    test(
      'unusual but valid typed text is read as the number it looks like',
      () {
        const lb181_8 = 181.8;
        for (final text in [
          '181.8',
          '0181.8',
          '00181.8',
          '181,8',
          ' 181.8 ',
          '\t181.8\n',
          '181.80',
          '181.8000000000000001',
          '181.84',
        ]) {
          expect(parseWeight(text), lb181_8, reason: '"$text"');
        }
        expect(parseWeight('181.'), 181.0);
        expect(parseWeight('181,'), 181.0);
        expect(parseWeight('.5'), 0.5);
        for (final text in [
          '',
          ' ',
          '.',
          ',',
          '..',
          '1.2.3',
          '1,2,3',
          '1,000.5',
          '-181.8',
          '+181.8',
          '181.8 lb',
          '1e3',
          '0x10',
          '181 .8',
          'NaN',
          'Infinity',
        ]) {
          expect(parseWeight(text), isNull, reason: '"$text"');
        }
      },
    );
  });

  //
  // The whole app.
  //
  group('in the whole app', () {
    late AppDatabase db;
    late Gate gate;
    late Now clockNow;
    final widgetData = <String, String?>{};

    setUp(() {
      gate = Gate();
      clockNow = nowFixed;
      db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
      widgetData.clear();
    });

    /// Unmounts the app first, so drift's stream clean-up timer runs, then
    /// closes the database.
    void appTest(String name, Future<void> Function(WidgetTester) body) {
      testWidgets(name, (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), (
          call,
        ) async {
          if (call.method == 'saveWidgetData') {
            final args = call.arguments as Map<Object?, Object?>;
            widgetData['${args['id']}'] = args['data'] as String?;
          }
          return null;
        });
        messenger.setMockMethodCallHandler(
          const MethodChannel('home_widget/updates'),
          (call) async => null,
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            const MethodChannel('home_widget'),
            null,
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel('home_widget/updates'),
            null,
          );
        });
        try {
          await body(tester);
        } finally {
          // Also after a failure, so one failing test cannot hurt the next.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(db.close);
        }
      });
    }

    Future<void> openApp(
      WidgetTester tester, {
      Size size = const Size(400, 800),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        DaybookApp(db: db, clock: () => clockNow, foodsPath: Future.value('')),
      );
      await settle(tester);
    }

    Future<void> seed(
      WidgetTester tester,
      double value,
      UnitSystem units,
      Now when,
    ) async {
      await tester.runAsync(() => db.saveWeight(value, units, when));
    }

    Finder barButton(String label) => find.widgetWithText(FilledButton, label);
    Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
    Finder field() => find.byType(TextField);
    String typed(WidgetTester tester) =>
        tester.widget<TextField>(field()).controller!.text;
    bool saveEnabled(WidgetTester tester) =>
        tester.widget<FilledButton>(saveButton()).onPressed != null;
    Future<List<WeightEntry>> rows(WidgetTester tester) async =>
        (await tester.runAsync(() => db.select(db.weightEntries).get()))!;

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(barButton('Weight'));
      await settle(tester);
      expect(find.byType(WeightSheet), findsOneWidget);
    }

    Future<void> goToTab(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await settle(tester);
    }

    /// Tells the app, as the phone does, that it went to the background and
    /// came back.
    void pauseAndResume(WidgetTester tester) {
      final b = tester.binding;
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    //
    // The three points the task row names.
    //
    appTest('Save tapped twice fast writes one row', (tester) async {
      await openApp(tester);
      await openSheet(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      // Both taps land before the screen redraws.
      await tester.tap(saveButton());
      await tester.tap(saveButton(), warnIfMissed: false);
      await settle(tester);
      expect(await rows(tester), hasLength(1));
      expect(find.byType(WeightSheet), findsNothing);
      expect(
        find.text('Weight saved: 181.8 lb, today 7:02 am'),
        findsOneWidget,
      );
    });

    appTest('Save tapped twice while the write is slow still writes one '
        'row, and the second tap does not reach Home', (tester) async {
      await openApp(tester);
      await openSheet(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      gate.hold = Completer<void>();
      await tester.tap(saveButton());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(saveButton(), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(saveButton(), warnIfMissed: false);
      gate.hold!.complete();
      await settle(tester);
      expect(await rows(tester), hasLength(1));
      expect(find.byType(WeightSheet), findsNothing);
      // A late third tap on the spot where Save was must not start anything.
      await settle(tester);
      expect(await rows(tester), hasLength(1));
    });

    appTest('folding: a width change from 344 dp to 673 dp with the sheet '
        'open keeps the typed number', (tester) async {
      await openApp(tester, size: const Size(344, 800));
      await openSheet(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      EditableText editable() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable().focusNode.hasFocus, isTrue);

      tester.view.physicalSize = const Size(673, 800);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(WeightSheet), findsOneWidget);
      expect(typed(tester), '181.8');
      expect(saveEnabled(tester), isTrue);
      expect(editable().focusNode.hasFocus, isTrue, reason: 'keyboard stays');

      // Folded again, and unfolded once more, with more typing in between.
      tester.view.physicalSize = const Size(344, 800);
      await settle(tester);
      expect(typed(tester), '181.8');
      await tester.enterText(field(), '181.9');
      tester.view.physicalSize = const Size(673, 800);
      await settle(tester);
      expect(typed(tester), '181.9');
      expect(tester.takeException(), isNull);

      await tester.tap(saveButton());
      await settle(tester);
      final stored = (await rows(tester)).single;
      expect(stored.weightKg, lbToKg(181.9));
    });

    appTest('folding keeps a changed date and time on the sheet', (
      tester,
    ) async {
      await openApp(tester, size: const Size(344, 800));
      await openSheet(tester);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final boxes = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(boxes.at(0), '9');
      await tester.enterText(boxes.at(1), '30');
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Thu, Nov 5, 9:30 am'), findsOneWidget);
      await tester.enterText(field(), '181.8');
      await tester.pump();

      tester.view.physicalSize = const Size(673, 800);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Thu, Nov 5, 9:30 am'), findsOneWidget);
      expect(typed(tester), '181.8');

      await tester.tap(saveButton());
      await settle(tester);
      final stored = (await rows(tester)).single;
      expect(stored.localDate, '2026-11-05');
      expect(stored.weightKg, lbToKg(181.8));
    });

    //
    // More ways a weight tracker can break.
    //
    appTest('a save updates Home and the Weight tab, which both listen, even '
        'while one of them is hidden', (tester) async {
      await seed(tester, 182.4, imp, at('2026-11-11', 6, 55, -360));
      await openApp(tester);

      // Saved from Home. The Weight tab is hidden and must already have it.
      await openSheet(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      final tabText = find.descendant(
        of: find.byType(WeightTab, skipOffstage: false),
        matching: find.text('181.8 lb', skipOffstage: false),
      );
      expect(tabText, findsWidgets, reason: 'in the hidden tab list');
      await goToTab(tester, 'Weight');
      expect(find.text('Today, Nov 12, 7:02 am'), findsOneWidget);
      expect(find.text('Wed, Nov 11, 6:55 am'), findsOneWidget);

      // Saved from the Weight tab. Home is hidden and must already have it.
      await tester.tap(find.widgetWithText(FilledButton, '+ Log'));
      await settle(tester);
      await tester.enterText(field(), '181.0');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      expect(find.textContaining('Weight saved: 181.0 lb'), findsOneWidget);
      final homeText = find.descendant(
        of: find.byType(HomeScreen, skipOffstage: false),
        matching: find.text('181.0 lb', skipOffstage: false),
      );
      expect(homeText, findsOneWidget, reason: 'on the hidden Home row');
      expect(widgetData['weight_value'], '181.0 lb');
      expect(await rows(tester), hasLength(3));

      await goToTab(tester, 'Today');
      expect(find.text('181.0 lb'), findsOneWidget);
      expect(find.textContaining('Trend'), findsOneWidget);
    });

    appTest('Undo still works after the app is paused and resumed', (
      tester,
    ) async {
      await openApp(tester);
      await openSheet(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);

      pauseAndResume(tester);
      await settle(tester);
      expect(
        find.text('Weight saved: 181.8 lb, today 7:02 am'),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect((await rows(tester)).single.deletedAtMs, isNotNull);
      expect(find.text('No weight yet.'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    appTest('Undo after the app resumes on the next day still removes that '
        'weigh-in, and the message names the right day', (tester) async {
      clockNow = at('2026-11-12', 23, 59, -360);
      await openApp(tester);
      await openSheet(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      expect(
        find.text('Weight saved: 181.8 lb, today 11:59 pm'),
        findsOneWidget,
      );

      clockNow = at('2026-11-13', 0, 5, -360);
      pauseAndResume(tester);
      await settle(tester);
      expect(
        find.text('Weight saved: 181.8 lb, yesterday 11:59 pm'),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await settle(tester);
      final stored = (await rows(tester)).single;
      expect(stored.deletedAtMs, isNotNull);
      expect(stored.localDate, '2026-11-12');
    });

    appTest('Undo tapped twice fast removes the weigh-in once and shows no '
        'error', (tester) async {
      await openApp(tester);
      await openSheet(tester);
      await tester.enterText(field(), '181.8');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await settle(tester);
      final stored = (await rows(tester)).single;
      expect(stored.deletedAtMs, isNotNull);
      expect(find.textContaining('Could not undo'), findsNothing);
      expect(find.text('No weight yet.'), findsOneWidget);
    });

    appTest('saves at 23:59 and 00:00 land on different days, and Home, the '
        'Weight tab and the message all name them right', (tester) async {
      clockNow = at('2026-11-12', 23, 59, -360, 30);
      await openApp(tester);
      await openSheet(tester);
      await tester.enterText(field(), '182.0');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      expect(
        find.text('Weight saved: 182.0 lb, today 11:59 pm'),
        findsOneWidget,
      );

      // The phone goes to sleep and wakes after midnight.
      clockNow = at('2026-11-13', 0, 0, -360);
      pauseAndResume(tester);
      await settle(tester);
      expect(find.text('Friday, Nov 13'), findsOneWidget);
      await openSheet(tester);
      expect(find.text('Today, 12:00 am'), findsWidgets);
      await tester.enterText(field(), '181.6');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      expect(
        find.text('Weight saved: 181.6 lb, today 12:00 am'),
        findsOneWidget,
      );

      final stored = await rows(tester);
      expect(
        [for (final r in stored) r.localDate],
        ['2026-11-12', '2026-11-13'],
      );
      await goToTab(tester, 'Weight');
      expect(find.text('Today, Nov 13, 12:00 am'), findsOneWidget);
      expect(find.text('Thu, Nov 12, 11:59 pm'), findsOneWidget);
    });

    appTest('a save after midnight, in an app that was never put in the '
        'background, says today', (tester) async {
      // A phone left on a stand with the app open: no pause, no resume.
      clockNow = at('2026-11-12', 23, 59, -360);
      await openApp(tester);
      clockNow = at('2026-11-13', 0, 0, -360, 30);
      await openSheet(tester);
      await tester.enterText(field(), '181.6');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      final stored = (await rows(tester)).single;
      expect(stored.localDate, '2026-11-13');
      expect(
        find.text('Weight saved: 181.6 lb, today 12:00 am'),
        findsOneWidget,
        reason: 'the stored day is today, so the message must say today',
      );
    });

    appTest('a sheet opened at 23:59 and saved after midnight keeps the day '
        'the sheet showed', (tester) async {
      clockNow = at('2026-11-12', 23, 59, -360, 30);
      await openApp(tester);
      await openSheet(tester);
      expect(find.text('Today, 11:59 pm'), findsOneWidget);
      await tester.enterText(field(), '181.6');
      await tester.pump();
      // The user takes their time. Midnight passes while the sheet is open.
      clockNow = at('2026-11-13', 0, 1, -360);
      await tester.tap(saveButton());
      await settle(tester);
      final stored = (await rows(tester)).single;
      expect(
        stored.localDate,
        '2026-11-12',
        reason: 'the sheet said Today, 11:59 pm when the number was typed',
      );
    });

    appTest('a weigh-in list of 600 rows opens, scrolls to the oldest row, '
        'and that row can be edited', (tester) async {
      final first = parseDate('2025-03-01');
      await tester.runAsync(() async {
        await db.batch((b) {
          b.insertAll(db.weightEntries, [
            for (var i = 0; i < 600; i++)
              () {
                final date = formatDate(first.add(Duration(days: i)));
                final when = Now.fromLocal(date, 7 * 60, -360);
                return WeightEntriesCompanion.insert(
                  localDate: date,
                  measuredAtMs: when.utcMs,
                  tzOffsetMinutes: -360,
                  // The oldest is 199.9 and no other row has that number.
                  weightKg: lbToKg(i == 0 ? 199.9 : 170 + (i % 100) / 10),
                  createdAtMs: when.utcMs,
                  updatedAtMs: when.utcMs,
                );
              }(),
          ]);
        });
      });
      await openApp(tester);
      await goToTab(tester, 'Weight');
      expect(tester.takeException(), isNull);
      expect(find.text('Weigh-ins'), findsOneWidget);

      // The whole history on the chart.
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      final list = find.descendant(
        of: find.byType(WeightTab),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('199.9 lb'),
        1500,
        scrollable: list,
        maxScrolls: 400,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('199.9 lb'));
      await settle(tester);
      expect(find.text('Edit weigh-in'), findsOneWidget);
      expect(typed(tester), '199.9');
    });

    appTest('typed text that looks odd but is valid is stored as the number '
        'it means', (tester) async {
      await openApp(tester);
      // Each pair: what is typed, and what the box then holds.
      const valid = {
        '0181.8': '0181.8',
        '181.': '181.',
        '181,8': '181,8',
        ' 181.8 ': '181.8', // spaces cannot be typed
        '181.8 lb': '181.8', // letters cannot be typed
        '-181.8': '181.8', // a minus cannot be typed
        '181.84': '181.84',
        '00181.8': '00181.8',
      };
      var count = 0;
      for (final e in valid.entries) {
        await openSheet(tester);
        await tester.enterText(field(), e.key);
        await tester.pump();
        expect(typed(tester), e.value, reason: '"${e.key}"');
        expect(saveEnabled(tester), isTrue, reason: '"${e.key}"');
        await tester.tap(saveButton());
        await settle(tester);
        final stored = await rows(tester);
        expect(stored, hasLength(++count), reason: '"${e.key}"');
        final want = e.value == '181.' ? 181.0 : 181.8;
        expect(stored.last.weightKg, lbToKg(want), reason: '"${e.key}"');
        expect(
          find.text(
            'Weight saved: ${want.toStringAsFixed(1)} lb, today 7:02 am',
          ),
          findsOneWidget,
          reason: '"${e.key}"',
        );
      }
    });

    appTest('typed text that is not a weight leaves Save off and writes '
        'nothing', (tester) async {
      await openApp(tester);
      await openSheet(tester);
      for (final text in [
        '.',
        ',',
        '..',
        '1.2.3',
        '1,2,3',
        '1,000.5',
        '181..8',
        '.5',
        '0',
        '0.0',
        '00',
        '49.9',
        '1000.1',
        '',
        '   ',
      ]) {
        await tester.enterText(field(), text);
        await tester.pump();
        expect(saveEnabled(tester), isFalse, reason: '"$text"');
        // The done key must not save it either.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle(tester);
        expect(find.byType(WeightSheet), findsOneWidget, reason: '"$text"');
      }
      expect(await rows(tester), isEmpty);
    });

    appTest('a weight that rounds into the range at either end is stored as '
        'the rounded number', (tester) async {
      await openApp(tester);
      var count = 0;
      for (final e in {'49.96': 50.0, '1000.04': 1000.0}.entries) {
        await openSheet(tester);
        await tester.enterText(field(), e.key);
        await tester.pump();
        expect(saveEnabled(tester), isTrue, reason: e.key);
        await tester.tap(saveButton());
        await settle(tester);
        final stored = await rows(tester);
        expect(stored, hasLength(++count), reason: e.key);
        expect(
          formatWeight(stored.last.weightKg, imp),
          e.value.toStringAsFixed(1),
        );
      }
    });
  });
}
