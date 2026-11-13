// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:daybook/app_scope.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A wall-clock time on a local date at a local offset in minutes.
Now at(String date, int h, int m, int offsetMinutes) =>
    Now.fromLocal(date, h * 60 + m, offsetMinutes);

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = at('2026-11-12', 7, 2, -360);

/// Lets a test hold a database write, or make it fail.
class Gate extends QueryInterceptor {
  Completer<void>? hold;
  bool fail = false;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (fail) throw Exception('disk full');
    await hold?.future;
    return super.runInsert(executor, statement, args);
  }
}

/// Real async work, since drift does not run in the widget test's fake time.
Future<T> real<T>(WidgetTester tester, Future<T> Function() f) =>
    tester.runAsync(f).then((v) => v as T);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late Gate gate;
  late AppDatabase db;
  SavedWeight? result;
  var closedWithoutSave = false;

  setUp(() {
    gate = Gate();
    db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    result = null;
    closedWithoutSave = false;
  });
  tearDown(() => db.close());

  Future<void> openSheet(
    WidgetTester tester, {
    OffsetAt offsetAt = _noOffset,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        db: db,
        clock: () => nowFixed,
        foodsPath: Future.value(''),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showWeightSheet(context, offsetAt: offsetAt);
                    closedWithoutSave = result == null;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  bool saveEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(saveButton()).onPressed != null;
  Finder field() => find.byType(TextField);
  String typed(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller!.text;

  Future<void> seed(
    WidgetTester tester,
    double value,
    UnitSystem units,
    Now when,
  ) => real(tester, () => db.saveWeight(value, units, when));

  Future<List<WeightEntry>> rows(WidgetTester tester) =>
      real(tester, () => db.select(db.weightEntries).get());

  testWidgets('opens with the last weight selected and the number pad up', (
    tester,
  ) async {
    await seed(
      tester,
      182.4,
      UnitSystem.imperial,
      at('2026-11-11', 6, 55, -360),
    );
    await openSheet(tester);

    final tf = tester.widget<TextField>(field());
    expect(tf.controller!.text, '182.4');
    expect(
      tf.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    expect(tf.autofocus, isTrue);
    expect(
      tf.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(tf.textInputAction, TextInputAction.done);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('Last: 182.4 lb, yesterday 6:55 am'), findsOneWidget);
    expect(find.text('Today, 7:02 am'), findsOneWidget);
    expect(saveEnabled(tester), isTrue);

    // Typing replaces the selected number.
    await tester.enterText(field(), '181.8');
    await tester.pump();
    expect(typed(tester), '181.8');
  });

  testWidgets('with no earlier weight the box is empty and Save is off', (
    tester,
  ) async {
    await openSheet(tester);
    expect(typed(tester), '');
    expect(saveEnabled(tester), isFalse);
    expect(find.text('Enter your weight.'), findsOneWidget);
    expect(find.textContaining('Last:'), findsNothing);
  });

  testWidgets('Save is off outside the range, with the reason in words', (
    tester,
  ) async {
    await openSheet(tester);
    const range = 'Enter a weight from 50 to 1,000 lb.';

    for (final text in ['49.9', '1000.1', '0', '1824', '9' * 40, '1' * 400]) {
      await tester.enterText(field(), text);
      await tester.pump();
      expect(saveEnabled(tester), isFalse, reason: text);
      expect(find.text(range), findsOneWidget, reason: text);
      expect(find.text('Enter a number, like 181.8.'), findsNothing);
    }

    await tester.enterText(field(), '1.2.3');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    expect(find.text('Enter a number, like 181.8.'), findsOneWidget);

    for (final text in ['50', '50.0', '1000', '181,8']) {
      await tester.enterText(field(), text);
      await tester.pump();
      expect(saveEnabled(tester), isTrue, reason: text);
      expect(find.text(range), findsNothing);
    }
  });

  testWidgets('the sheet closes only after the write returns, and hands back '
      'the stored row', (tester) async {
    await openSheet(tester);
    gate.hold = Completer<void>();
    await tester.enterText(field(), '181.84');
    await tester.pump();
    await tester.tap(saveButton());
    await settle(tester);

    // The write has not returned: still open, Save off.
    expect(field(), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    expect(result, isNull);

    gate.hold!.complete();
    await settle(tester);
    expect(field(), findsNothing);

    final stored = (await rows(tester)).single;
    expect(result!.row, stored);
    expect(result!.units, UnitSystem.imperial);
    // The stored value is 181.8, not what was typed.
    expect(formatWeight(result!.row.weightKg, UnitSystem.imperial), '181.8');
    expect(stored.localDate, '2026-11-12');
    expect(stored.tzOffsetMinutes, -360);
    expect(stored.measuredAtMs, nowFixed.utcMs);
  });

  testWidgets('a failing write keeps the sheet open with the number', (
    tester,
  ) async {
    await openSheet(tester);
    gate.fail = true;
    await tester.enterText(field(), '181.8');
    await tester.pump();
    await tester.tap(saveButton());
    await settle(tester);

    expect(field(), findsOneWidget);
    expect(typed(tester), '181.8');
    expect(
      find.text(
        'Could not save. Your 181.8 lb is still here. Tap Save to try again.',
      ),
      findsOneWidget,
    );
    expect(saveEnabled(tester), isTrue);
    expect(result, isNull);
    expect(closedWithoutSave, isFalse);
    expect(await rows(tester), isEmpty);

    // Trying again works once the database does.
    gate.fail = false;
    await tester.tap(saveButton());
    await settle(tester);
    expect(field(), findsNothing);
    expect((await rows(tester)).length, 1);
  });

  testWidgets('metric shows kg and stores kilograms', (tester) async {
    await real(tester, () => db.setUnits(UnitSystem.metric));
    await seed(tester, 82.5, UnitSystem.metric, at('2026-11-11', 6, 55, -360));
    await openSheet(tester);

    expect(typed(tester), '82.5');
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('lb'), findsNothing);
    expect(find.text('Last: 82.5 kg, yesterday 6:55 am'), findsOneWidget);

    await tester.enterText(field(), '22.6');
    await tester.pump();
    expect(saveEnabled(tester), isFalse);
    expect(find.text('Enter a weight from 22.7 to 453.6 kg.'), findsOneWidget);

    await tester.enterText(field(), '81.9');
    await tester.pump();
    await tester.tap(saveButton());
    await settle(tester);
    final all = await rows(tester);
    expect(all.map((r) => r.weightKg), contains(81.9));
    expect(result!.units, UnitSystem.metric);
  });

  testWidgets('Change sets the date and time, with the offset of that day', (
    tester,
  ) async {
    // The offset for a picked time is looked up, not taken from today.
    int offsetAt(DateTime local) =>
        local.month == 11 && local.day == 5 ? -300 : -360;
    await openSheet(tester, offsetAt: offsetAt);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Time picker: switch to typing and enter 9:30 (am stays selected).
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

    await tester.enterText(field(), '180.2');
    await tester.pump();
    await tester.tap(saveButton());
    await settle(tester);

    final stored = (await rows(tester)).single;
    final expected = at('2026-11-05', 9, 30, -300);
    expect(stored.localDate, '2026-11-05');
    expect(stored.tzOffsetMinutes, -300);
    expect(stored.measuredAtMs, expected.utcMs);
    // It was made now, though it counts for Nov 5.
    expect(stored.createdAtMs, nowFixed.utcMs);
  });

  testWidgets('cancelling the pickers leaves the time as now', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Today, 7:02 am'), findsOneWidget);
  });

  testWidgets('the keyboard done action saves', (tester) async {
    await openSheet(tester);
    await tester.enterText(field(), '181.8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(field(), findsNothing);
    expect((await rows(tester)).length, 1);
  });

  testWidgets('done does nothing when the number is out of range', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(field(), '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(field(), findsOneWidget);
    expect(await rows(tester), isEmpty);
  });

  testWidgets('Save tapped twice quickly writes one row', (tester) async {
    await openSheet(tester);
    await tester.enterText(field(), '181.8');
    await tester.pump();
    // Both taps land before the screen redraws.
    await tester.tap(saveButton());
    await tester.tap(saveButton(), warnIfMissed: false);
    await settle(tester);
    expect((await rows(tester)).length, 1);
  });

  testWidgets('Save and done while a write is held still write one row', (
    tester,
  ) async {
    await openSheet(tester);
    gate.hold = Completer<void>();
    await tester.enterText(field(), '181.8');
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pump();
    await tester.tap(saveButton(), warnIfMissed: false);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    gate.hold!.complete();
    await settle(tester);
    expect((await rows(tester)).length, 1);
  });

  for (final width in [344.0, 673.0]) {
    testWidgets('layout has no overflow at ${width.toInt()} dp, targets are '
        'at least 48 dp', (tester) async {
      await seed(
        tester,
        182.4,
        UnitSystem.imperial,
        at('2026-11-11', 6, 55, -360),
      );
      await openSheet(tester, size: Size(width, 800));
      gate.fail = true;
      await tester.tap(saveButton());
      await settle(tester);
      expect(find.textContaining('Could not save.'), findsOneWidget);

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(WeightSheet)).width,
        lessThanOrEqualTo(600),
      );
      for (final f in [
        saveButton(),
        find.widgetWithText(TextButton, 'Change'),
        field(),
      ]) {
        final s = tester.getSize(f);
        expect(s.height, greaterThanOrEqualTo(48));
        expect(s.width, greaterThanOrEqualTo(48));
      }
    });
  }

  testWidgets('large text does not overflow at 344 dp', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openSheet(tester, size: const Size(344, 800));
    await tester.enterText(field(), '5');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

int _noOffset(DateTime local) => -360;
