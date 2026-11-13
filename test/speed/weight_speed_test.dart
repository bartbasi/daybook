// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Speed target 3 (docs/design/speed-targets.md, section 3): log body weight
// from Home, or from the widget, in as few taps as the design promises. The
// whole app runs here, with an in-memory database and a fixed clock. The same
// flow runs on a real build in integration_test/flows_test.dart.

import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/flows/weight_flow.dart';
import 'tap_counter.dart';

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = Now.fromLocal('2026-11-12', 7 * 60 + 2, -360);

void main() {
  late AppDatabase db;

  // What the home_widget plugin says the app was started with.
  String? launchLink;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    launchLink = null;
  });

  /// Unmounts the app first, so drift's stream clean-up timer runs, then
  /// closes the database.
  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (call) async => call.method == 'initiallyLaunchedFromHomeWidget'
            ? launchLink
            : null,
      );
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
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(db.close);
    });
  }

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      DaybookApp(db: db, clock: () => nowFixed, foodsPath: Future.value('')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A weigh-in from yesterday, so the sheet opens with its number.
  Future<WeightEntry> seedYesterday(
    WidgetTester tester,
    double value,
    UnitSystem units,
  ) async {
    final when = Now.fromLocal('2026-11-11', 6 * 60 + 55, -360);
    return (await tester.runAsync(() => db.saveWeight(value, units, when)))!;
  }

  test('no flow under integration_test/flows drives the screen without the '
      'tap counter', () async {
    await db.close(); // setUp opened one this test does not use
    final flows = Directory('integration_test/flows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(flows, isNotEmpty);
    final direct = RegExp(
      r'tester\s*\.\s*(tap\w*|longPress\w*|drag\w*|fling\w*|timedDrag\w*|'
      r'scrollUntilVisible|startGesture|createGesture|press|sendKey\w*|'
      r'showKeyboard|enterText)|testTextInput',
    );
    for (final file in flows) {
      // The whole file, comments removed and whitespace collapsed, so a call
      // split across lines is still found.
      final code = file
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ')
          .replaceAll(RegExp(r'(^|\s)//[^\n]*'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      final hit = direct.firstMatch(code);
      expect(
        hit,
        isNull,
        reason: '${file.path} drives the screen directly: ${hit?.group(0)}',
      );
    }
  });

  testWidgets('the tap counter counts taps and keyboard actions, not typing', (
    tester,
  ) async {
    final changes = <String>[];
    final controller = TextEditingController();
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(
                autofocus: true,
                controller: controller,
                onChanged: changes.add,
                textInputAction: TextInputAction.done,
              ),
              TextButton(
                onPressed: () => pressed++,
                child: const Text('press'),
              ),
            ],
          ),
        ),
      ),
    );
    final taps = TapCounter(tester);
    taps.expectCount(0);
    await taps.type(find.byType(TextField), '181.8');
    expect(controller.text, '181.8');
    taps.expectCount(0);
    await taps.tap(find.text('press'));
    expect(pressed, 1);
    taps.expectCount(1);
    await taps.keyboardAction();
    taps.expectCount(2);
    expect(
      () => taps.expectCount(3),
      throwsA(isA<TestFailure>()),
      reason: 'a wrong count is reported',
    );
    await tester.runAsync(db.close); // setUp opened one this test does not use
  });

  testWidgets('typing into a field that is not focused fails, because that '
      'field needs a counted tap first', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField())),
    );
    final taps = TapCounter(tester);
    expect(
      () => taps.type(find.byType(TextField), '181.8'),
      throwsA(isA<TestFailure>()),
    );
    // After a counted tap the field has focus and typing works.
    await taps.tap(find.byType(TextField));
    await tester.pump();
    await taps.type(find.byType(TextField), '181.8');
    taps.expectCount(1);
    await tester.runAsync(db.close);
  });

  appTest('the device flow runs here as it runs on a device, under the '
      'fixed clock and an in-memory database', (tester) async {
    await openApp(tester);
    await runWeightFlow(tester);
  });

  group('from Home', () {
    appTest('2 counted taps and typing 181.8 store one row of 181.8 lb', (
      tester,
    ) async {
      await openApp(tester);
      final taps = TapCounter(tester);
      final row = await logWeightFromHome(tester, taps, type: '181.8');
      taps.expectCount(2, flow: 'Weight, Save');

      final all = await storedWeights(tester);
      expect(all, [row]);
      expect(row.weightKg, lbToKg(181.8));
      expect(formatWeight(row.weightKg, UnitSystem.imperial), '181.8');
      expect(row.localDate, '2026-11-12');
      expect(row.measuredAtMs, nowFixed.utcMs);
      expect(row.tzOffsetMinutes, -360);

      // Home confirms from the stored row, and its weight row shows it too.
      expect(
        find.text('Weight saved: 181.8 lb, today 7:02 am'),
        findsOneWidget,
      );
      expect(find.text('181.8 lb'), findsOneWidget);
    });

    appTest('the weight the same as last time takes 2 counted taps and no '
        'typing', (tester) async {
      final last = await seedYesterday(tester, 182.4, UnitSystem.imperial);
      await openApp(tester);
      final taps = TapCounter(tester);
      final row = await logWeightFromHome(tester, taps);
      taps.expectCount(2, flow: 'Weight, Save');

      expect(await storedWeights(tester), hasLength(2));
      expect(row.id, isNot(last.id));
      expect(row.weightKg, last.weightKg);
      expect(row.localDate, '2026-11-12');
      expect(
        find.text('Weight saved: 182.4 lb, today 7:02 am'),
        findsOneWidget,
      );
    });

    appTest('the keyboard done key can replace the Save tap and still counts '
        'as one', (tester) async {
      await openApp(tester);
      final taps = TapCounter(tester);
      final row = await logWeightFromHome(
        tester,
        taps,
        type: '181.8',
        doneKey: true,
      );
      taps.expectCount(2, flow: 'Weight, done key');
      expect(row.weightKg, lbToKg(181.8));
      expect(await storedWeights(tester), hasLength(1));
    });

    appTest('in metric, 2 counted taps and typing 82.5 store one row of 82.5 '
        'kg', (tester) async {
      await tester.runAsync(() => db.setUnits(UnitSystem.metric));
      await openApp(tester);
      final taps = TapCounter(tester);
      final row = await logWeightFromHome(tester, taps, type: '82.5');
      taps.expectCount(2, flow: 'Weight, Save');

      expect(await storedWeights(tester), [row]);
      expect(row.weightKg, 82.5);
      expect(find.text('Weight saved: 82.5 kg, today 7:02 am'), findsOneWidget);
      expect(find.text('82.5 kg'), findsOneWidget);
    });

    appTest('in metric, the weight the same as last time takes 2 counted '
        'taps and no typing', (tester) async {
      await tester.runAsync(() => db.setUnits(UnitSystem.metric));
      final last = await seedYesterday(tester, 82.5, UnitSystem.metric);
      await openApp(tester);
      final taps = TapCounter(tester);
      final row = await logWeightFromHome(tester, taps);
      taps.expectCount(2, flow: 'Weight, Save');
      expect(row.weightKg, last.weightKg);
      expect(await storedWeights(tester), hasLength(2));
    });
  });

  group('from the widget link', () {
    appTest('after the launch, 1 counted tap and typing 181.8 store one row', (
      tester,
    ) async {
      launchLink = 'daybook://weight';
      await openApp(tester);
      await waitForWeightSheet(tester);
      final taps = TapCounter(tester);
      taps.expectCount(0); // the launch itself is not a tap

      final row = await saveOpenWeightSheet(tester, taps, type: '181.8');
      taps.expectCount(1, flow: 'the widget link, then Save');
      expect(await storedWeights(tester), [row]);
      expect(row.weightKg, lbToKg(181.8));
      expect(
        find.text('Weight saved: 181.8 lb, today 7:02 am'),
        findsOneWidget,
      );
    });

    appTest('with the weight the same as last time, 1 counted tap and no '
        'typing', (tester) async {
      final last = await seedYesterday(tester, 182.4, UnitSystem.imperial);
      launchLink = 'daybook://weight';
      await openApp(tester);
      await waitForWeightSheet(tester);
      final taps = TapCounter(tester);
      final row = await saveOpenWeightSheet(tester, taps);
      taps.expectCount(1, flow: 'the widget link, then Save');
      expect(row.weightKg, last.weightKg);
      expect(await storedWeights(tester), hasLength(2));
    });

    appTest('in metric, 1 counted tap and typing 82.5 store one row of 82.5 '
        'kg', (tester) async {
      await tester.runAsync(() => db.setUnits(UnitSystem.metric));
      launchLink = 'daybook://weight';
      await openApp(tester);
      await waitForWeightSheet(tester);
      final taps = TapCounter(tester);
      final row = await saveOpenWeightSheet(tester, taps, type: '82.5');
      taps.expectCount(1, flow: 'the widget link, then Save');
      expect(await storedWeights(tester), [row]);
      expect(row.weightKg, 82.5);
      expect(find.text('Weight saved: 82.5 kg, today 7:02 am'), findsOneWidget);
    });

    appTest('a tap on the widget while the app runs also takes 1 counted '
        'tap', (tester) async {
      await openApp(tester);
      await deliverWidgetLink(tester);
      final taps = TapCounter(tester);
      final row = await saveOpenWeightSheet(tester, taps, type: '181.8');
      taps.expectCount(1, flow: 'the widget link, then Save');
      expect(await storedWeights(tester), [row]);
    });
  });
}
