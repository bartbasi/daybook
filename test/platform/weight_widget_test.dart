// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/platform/weight_widget.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Now at(String date, int h, int m) => Now.fromLocal(date, h * 60 + m, -360);

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = at('2026-11-12', 7, 2);

/// Counts every write that reaches the database.
class WriteCounter extends QueryInterceptor {
  int writes = 0;

  @override
  Future<int> runInsert(QueryExecutor e, String s, List<Object?> a) {
    writes++;
    return super.runInsert(e, s, a);
  }

  @override
  Future<int> runUpdate(QueryExecutor e, String s, List<Object?> a) {
    writes++;
    return super.runUpdate(e, s, a);
  }

  @override
  Future<int> runDelete(QueryExecutor e, String s, List<Object?> a) {
    writes++;
    return super.runDelete(e, s, a);
  }
}

void main() {
  const channel = MethodChannel('home_widget');
  const events = MethodChannel('home_widget/updates');

  late AppDatabase db;
  late WriteCounter counter;
  late Map<String, Object?> saved;
  late List<MethodCall> calls;
  late bool pluginFails;
  late Now clockNow;

  setUp(() {
    clockNow = nowFixed;
    counter = WriteCounter();
    db = AppDatabase(NativeDatabase.memory().interceptWith(counter));
    saved = {};
    calls = [];
    pluginFails = false;
  });

  // Widget tests close it themselves, which makes this a no-op for them.
  tearDown(() => db.close());

  void mockPlugin(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (pluginFails) throw PlatformException(code: 'no_widget');
      final args = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'saveWidgetData':
          saved[args!['id']! as String] = args['data'];
          return true;
        case 'updateWidget':
          return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(events, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(events, null);
    });
  }

  int updates() => calls.where((c) => c.method == 'updateWidget').length;

  void widgetTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      mockPlugin(tester);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        DaybookApp(db: db, clock: () => clockNow, foodsPath: Future.value('')),
      );
      await settle(tester);
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(db.close);
    });
  }

  Future<T> run<T>(WidgetTester tester, Future<T> Function() f) async {
    // Started here, in the test's own zone, and pumped like the app does it.
    // (A delete inside runAsync waits for the widgets' live queries, which
    // only move when the test pumps.)
    var done = false;
    late T value;
    Object? error;
    f()
        .then((v) {
          value = v;
        })
        .catchError((Object e) {
          error = e;
        })
        .whenComplete(() => done = true);
    for (var i = 0; i < 200 && !done; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    if (error != null) throw error!;
    expect(done, isTrue);
    await settle(tester);
    return value;
  }

  void expectWidget(Map<String, String> expected, {String reason = ''}) {
    expect(saved, expected, reason: reason);
  }

  Map<String, String> texts({
    required String weight,
    String when = '',
    String trend = '',
  }) => {
    'weight_title': 'Daybook weight',
    'weight_value': weight,
    'weight_when': when,
    'weight_trend': trend,
    'weight_tap': 'Tap to log',
  };

  widgetTest('at start with no weigh-in the widget gets the empty state', (
    tester,
  ) async {
    expectWidget(texts(weight: 'No weight yet'));
    expect(updates(), greaterThanOrEqualTo(1));
    final update = calls.firstWhere((c) => c.method == 'updateWidget');
    expect(
      (update.arguments as Map)['qualifiedAndroidName'],
      'io.github.bartbasi.daybook.WeightWidgetProvider',
    );
  });

  widgetTest('a save through the sheet writes the weight, its day, the '
      'trend and Tap to log, then asks for an update', (tester) async {
    await run(
      tester,
      () => db.saveWeight(
        182.4,
        UnitSystem.imperial,
        nowFixed,
        at: at('2026-11-11', 6, 55),
      ),
    );
    final before = updates();

    await tester.tap(find.widgetWithText(FilledButton, 'Weight'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expectWidget(
      texts(
        weight: '181.8 lb',
        when: 'Thu, Nov 12, 7:02 am',
        // 182.4 moves a tenth of the way to 181.8: 182.34.
        trend: 'Trend 182.3 lb',
      ),
    );
    expect(updates(), greaterThan(before));
  });

  widgetTest('edit, delete, Undo and a units switch each rewrite the widget '
      'and ask for an update', (tester) async {
    await run(
      tester,
      () => db.saveWeight(
        182.4,
        UnitSystem.imperial,
        nowFixed,
        at: at('2026-11-11', 6, 55),
      ),
    );
    final today = (await run(
      tester,
      () => db.saveWeight(181.8, UnitSystem.imperial, nowFixed),
    ));
    var count = updates();
    final yesterdayOnly = texts(
      weight: '182.4 lb',
      when: 'Wed, Nov 11, 6:55 am',
      trend: 'Trend 182.4 lb',
    );

    // Edit.
    await run(
      tester,
      () => db.editWeight(today.id, 181.2, UnitSystem.imperial, nowFixed),
    );
    expectWidget(
      texts(
        weight: '181.2 lb',
        when: 'Thu, Nov 12, 7:02 am',
        // 182.4 moves a tenth of the way to 181.2: 182.28.
        trend: 'Trend 182.3 lb',
      ),
      reason: 'edit',
    );
    expect(updates(), greaterThan(count));
    count = updates();

    // Delete.
    await run(tester, () => db.deleteWeight(today.id, nowFixed));
    expectWidget(yesterdayOnly, reason: 'delete');
    expect(updates(), greaterThan(count));
    count = updates();

    // Undo.
    await run(tester, () => db.undoDeleteWeight(today.id, nowFixed));
    expect(saved['weight_value'], '181.2 lb', reason: 'undo');
    expect(updates(), greaterThan(count));
    count = updates();

    // Units: 181.2 lb is 82.2 kg, and the trend 182.28 lb is 82.7 kg.
    await run(tester, () => db.setUnits(UnitSystem.metric));
    expectWidget(
      texts(
        weight: '82.2 kg',
        when: 'Thu, Nov 12, 7:02 am',
        trend: 'Trend 82.7 kg',
      ),
      reason: 'units',
    );
    expect(updates(), greaterThan(count));
  });

  widgetTest('resuming the app rewrites the widget data', (tester) async {
    await run(
      tester,
      () => db.saveWeight(
        181.8,
        UnitSystem.imperial,
        nowFixed,
        at: at('2026-11-11', 6, 55),
      ),
    );
    expect(saved['weight_when'], 'Wed, Nov 11, 6:55 am');
    calls.clear();
    saved.clear();

    clockNow = at('2026-11-13', 7, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(
      calls.where((c) => c.method == 'saveWidgetData'),
      isNotEmpty,
      reason: 'texts written again',
    );
    expectWidget(
      texts(
        weight: '181.8 lb',
        when: 'Wed, Nov 11, 6:55 am',
        trend: 'Trend 181.8 lb',
      ),
    );
    expect(updates(), greaterThanOrEqualTo(1), reason: 'update requested');
  });

  widgetTest('deleting the only weigh-in goes back to the empty state', (
    tester,
  ) async {
    final row = await run(
      tester,
      () => db.saveWeight(181.8, UnitSystem.imperial, nowFixed),
    );
    expect(saved['weight_value'], '181.8 lb');
    await run(tester, () => db.deleteWeight(row.id, nowFixed));
    expectWidget(texts(weight: 'No weight yet'));
  });

  widgetTest('a plugin error does not break a save', (tester) async {
    pluginFails = true;
    final row = await run(
      tester,
      () => db.saveWeight(181.8, UnitSystem.imperial, nowFixed),
    );
    expect(row.weightKg, closeTo(82.46, 0.01));
    expect(tester.takeException(), isNull);
    final stored = await tester.runAsync(() => db.latestWeight());
    expect(stored?.id, row.id);

    // The same through the sheet.
    await tester.tap(find.widgetWithText(FilledButton, 'Weight'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '181.0');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Weight saved: 181.0 lb, today 7:02 am'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('with no plugin at all, writing the widget just returns', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // No mock handler: the channel throws MissingPluginException.
    await writeWeightWidget(const [], UnitSystem.imperial, '2026-11-12');
    expect(await readWidgetLaunchLink(), isNull);
  });

  widgetTest('the widget code never writes to the database', (tester) async {
    expect(counter.writes, 0, reason: 'start');
    await run(
      tester,
      () => db.saveWeight(181.8, UnitSystem.imperial, nowFixed),
    );
    // Exactly the one write the save itself made, although the widget data
    // was rewritten after it.
    expect(counter.writes, 1);
    expect(saved['weight_value'], '181.8 lb');
    await run(tester, () => db.setUnits(UnitSystem.metric));
    expect(counter.writes, 2); // the units setting, nothing from the widget

    // And the file has no way to: it takes the rows it is given.
    final source = File('lib/platform/weight_widget.dart').readAsStringSync();
    expect(source, isNot(contains('AppDatabase')));
    expect(source, isNot(contains('weight_data.dart')));
    expect(source, isNot(contains('.insert(')));
    expect(source, isNot(contains('.update(')));
  });

  test('only the weight link is a weight link', () {
    expect(isWeightLink(Uri.parse('daybook://weight')), isTrue);
    expect(isWeightLink(Uri.parse('daybook://food')), isFalse);
    expect(isWeightLink(Uri.parse('https://weight')), isFalse);
    expect(isWeightLink(Uri()), isFalse);
    expect(isWeightLink(null), isFalse);
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
