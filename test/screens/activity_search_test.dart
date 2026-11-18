// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/data/met_table.dart';
import 'package:daybook/screens/cardio/activity_search.dart';
import 'package:daybook/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The "Other..." search of the cardio screen (task 5.3, cardio.html frame 4),
// opened as the sheet it is: the box stays in view with the keyboard up, the
// results are capped with a line saying so, and each row reads exactly as the
// Compendium words it.

void main() {
  late MetTable table;
  MetActivity? picked;
  var closed = false;

  Finder box() => find.widgetWithText(TextField, S.cardioSearchHint);

  // The results list, found through the ListView so the text field's own
  // scrollable is not in the way.
  Finder results() => find.descendant(
    of: find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListView),
    ),
    matching: find.byType(Scrollable),
  );

  Future<void> open(WidgetTester tester) async {
    table = (await tester.runAsync(MetTable.load))!;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    picked = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  picked = await showActivitySearch(context, table);
                  closed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(box(), text);
    await tester.pumpAndSettle();
  }

  testWidgets('it opens with a prompt and the box at the top', (tester) async {
    await open(tester);
    expect(find.text(S.cardioSearchTitle), findsOneWidget);
    expect(find.text(S.cardioSearchPrompt), findsOneWidget);
    expect(box(), findsOneWidget);
  });

  testWidgets('with the keyboard up the box stays in view, with and without '
      'results', (tester) async {
    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 500);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(box()).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(box()).bottom, lessThanOrEqualTo(800 - 500));

    await search(tester, 'walking');
    expect(tester.getRect(box()).bottom, lessThanOrEqualTo(800 - 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a keyboard height reported below zero does not break the '
      'sheet', (tester) async {
    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: -20);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(box(), findsOneWidget);
    await search(tester, 'rowing');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long result list stops at 50 rows and says so', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'walking');
    final found = table.search('walking');
    expect(found.length, greaterThan(50));

    await tester.scrollUntilVisible(
      find.text(S.cardioSearchMore(50)),
      500,
      scrollable: results(),
    );
    expect(find.text(S.cardioSearchMore(50)), findsOneWidget);
    // The 50th result is the last row, and the 51st is not listed.
    expect(find.byKey(ValueKey('activity-${found[49].code}')), findsOneWidget);
    expect(find.byKey(ValueKey('activity-${found[50].code}')), findsNothing);
  });

  testWidgets('a short result list has no "Showing the first" line', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'rowing');
    expect(table.search('rowing').length, lessThan(50));
    expect(find.textContaining('Showing the first'), findsNothing);
    expect(
      find.byKey(ValueKey('activity-${table.search('rowing').first.code}')),
      findsOneWidget,
    );
  });

  testWidgets('Cancel closes the search and picks nothing', (tester) async {
    await open(tester);
    await search(tester, 'rowing');
    await tester.tap(find.widgetWithText(TextButton, S.cancel));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(picked, isNull);
    expect(find.text(S.cardioSearchTitle), findsNothing);
  });

  testWidgets('no match says so in a plain sentence', (tester) async {
    await open(tester);
    await search(tester, 'zzzzqx');
    expect(find.text(S.cardioSearchNone), findsOneWidget);
    expect(find.text(S.cardioSearchPrompt), findsNothing);
  });

  testWidgets('a row is worded exactly as the Compendium words it, and '
      'picking it hands it back', (tester) async {
    await open(tester);
    await search(tester, 'running 6-6.3');
    final row = table.byCode('12050')!;
    expect(row.description, 'Running, 6-6.3 mph (10 min/mile)');
    final key = find.byKey(const ValueKey('activity-12050'));
    await tester.scrollUntilVisible(key, 200, scrollable: results());
    expect(find.text('Running, 6-6.3 mph (10 min/mile)'), findsOneWidget);
    await tester.tap(key);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(picked?.code, '12050');
  });
}
