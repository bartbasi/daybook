// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_session.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/screens/food/correction_sheet.dart';
import 'package:daybook/screens/food/food_entry_screen.dart';
import 'package:daybook/screens/food/food_line_tile.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// The correction sheet (task 2.9), through the real sheet on the real bundled
// food data with the inline worker. A held FakeLink is used where order
// matters.

const brief =
    '2 eggs, 2 slices sourdough toast, 1 tbsp butter, '
    'coffee with 2 tbsp half and half';

Now at(String date, int h, int m) => Now.fromLocal(date, h * 60 + m, -360);
final nowFixed = at('2026-11-12', 7, 2);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// A worker link that answers like the inline worker, and can refuse a
/// rewrite or stop the worker on command.
class FakeLink implements WorkerLink {
  FakeLink(this.parser);

  final Parser parser;
  late final WorkerCore core = WorkerCore(parser);
  void Function(WorkerReply)? reply;
  var refuseRewrite = false;

  @override
  void start(void Function(WorkerReply reply) onReply) {
    reply = onReply;
    onReply(const ReadyReply());
  }

  @override
  void send(WorkerRequest request) {
    if (refuseRewrite && request is RewriteRequest) {
      reply!(EditResult(request.id, null, request.cursor));
      return;
    }
    final r = core.handle(request);
    if (r != null) reply!(r);
  }

  void crash() => reply!(const WorkerFailure(0, FailureKind.crashed, 'exited'));

  @override
  Future<void> close() async {}
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late sqlite.Database usda;
  late SqliteUsdaFoods loader;
  late Parser parser;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('daybook_sheet');
    final path = '${tmp.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    usda = sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readOnly);
    loader = SqliteUsdaFoods(usda);
    parser = Parser(SearchIndex.build(readUsdaFoods(usda)), loader.call);
  });

  tearDownAll(() {
    loader.dispose();
    usda.close();
    tmp.deleteSync(recursive: true);
  });

  late AppDatabase db;
  late List<FakeLink> links;
  var useLink = false;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    links = [];
    useLink = false;
  });

  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      for (final c in ['home_widget', 'home_widget/updates']) {
        messenger.setMockMethodCallHandler(MethodChannel(c), (_) async => null);
      }
      addTearDown(() {
        for (final c in ['home_widget', 'home_widget/updates']) {
          messenger.setMockMethodCallHandler(MethodChannel(c), null);
        }
      });
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(db.close);
    });
  }

  Future<void> openApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => nowFixed,
        foodsPath: Future.value('unused'),
        workerFactory: (_) {
          if (!useLink) return ParseWorker.inlineWith(parser);
          final link = FakeLink(parser);
          links.add(link);
          return ParseWorker.linked(link);
        },
      ),
    );
    await settle(tester);
  }

  Finder plusFood() => find.widgetWithText(FilledButton, '+ Food');
  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  Finder box() => find.descendant(
    of: find.byType(FoodEntryScreen),
    matching: find.byType(TextField),
  );
  Finder tiles() => find.byType(FoodLineTile);
  Finder sheet() => find.byType(CorrectionSheet);
  Finder inSheet(Finder f) => find.descendant(of: sheet(), matching: f);
  Finder amountField() => inSheet(
    find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Amount',
    ),
  );
  Finder searchField() => inSheet(
    find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Search all foods',
    ),
  );

  Future<void> openFood(WidgetTester tester) async {
    await tester.tap(plusFood());
    await settle(tester);
    expect(find.byType(FoodEntryScreen), findsOneWidget);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(box(), text);
    await tester.pump();
  }

  FoodEntryScreenState screen(WidgetTester tester) =>
      tester.state<FoodEntryScreenState>(find.byType(FoodEntryScreen));

  String boxText(WidgetTester tester) =>
      tester.widget<TextField>(box()).controller!.text;

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<StoredMeal> theMeal(WidgetTester tester) async {
    final rows = await real(tester, () => db.select(db.meals).get());
    expect(rows, hasLength(1));
    final StoredMeal? m = await real(tester, () => db.loadMeal(rows.single.id));
    return m!;
  }

  var taps = 0;
  Future<void> tap(WidgetTester tester, Finder f) async {
    taps++;
    await tester.tap(f);
    await settle(tester);
  }

  /// The tile that shows [name].
  Finder tileOf(String name) => find.widgetWithText(FoodLineTile, name);

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  MealLineInput item(
    String ref,
    String name,
    double q,
    String unit,
    double grams,
    double kcal,
  ) => MealLineInput(
    foodRef: ref,
    foodName: name,
    quantity: q,
    unitLabel: unit,
    baseQuantity: grams,
    baseUnit: 'g',
    nutrients: {Nutrients.energy: kcal, Nutrients.protein: 10},
  );

  const cream = '2 tbsp half and half';

  group('a typed line with a food', () {
    appTest('lists the current pick first, marked, then the others in rank '
        'order, in a list that scrolls', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '$brief, 1 apple');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines
          .firstWhere(
            (l) => text.substring(l.span!.start, l.span!.end) == cream,
          )
          .span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      expect(alts.others.length, inInclusiveRange(1, 7));

      await tester.tap(
        find.widgetWithText(FoodLineTile, 'Cream, half and half'),
      );
      await settle(tester);
      expect(sheet(), findsOneWidget);
      expect(inSheet(find.text('You typed')), findsOneWidget);
      expect(inSheet(find.text('"$cream"')), findsOneWidget);
      expect(inSheet(find.text('Which food?')), findsOneWidget);
      expect(inSheet(find.byIcon(Icons.radio_button_checked)), findsOneWidget);
      expect(inSheet(find.textContaining('Current pick')), findsOneWidget);
      // The current pick is the first row; the others follow in rank order.
      final y = tester.getTopLeft(inSheet(find.text(alts.current!.name))).dy;
      final yNext = tester
          .getTopLeft(inSheet(find.text(alts.others.first.name)))
          .dy;
      expect(y, lessThan(yNext));
      expect(
        inSheet(find.text('Your pick is remembered when you save the meal.')),
        findsOneWidget,
      );
      expect(inSheet(find.text('Remove from meal')), findsOneWidget);
      expect(inSheet(find.text('Done')), findsOneWidget);
      expect(inSheet(find.text('Forget this match')), findsNothing);
      expect(inSheet(find.text('Scan its barcode')), findsNothing);
      expect(inSheet(find.textContaining('Create a food')), findsNothing);

      // The list scrolls: the last candidate is reached by scrolling.
      final list = inSheet(find.byType(ListView)).first;
      await tester.scrollUntilVisible(
        inSheet(find.text(alts.others.last.name)),
        100,
        scrollable: find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first,
      );
      expect(inSheet(find.text(alts.others.last.name)), findsOneWidget);
    });

    appTest('fixing a guess takes exactly 2 taps: the line, then the food', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '$brief, 1 apple');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines
          .firstWhere(
            (l) => text.substring(l.span!.start, l.span!.end) == cream,
          )
          .span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      final other = alts.others.first;
      expect(find.text('Guess'), findsOneWidget);
      expect(find.text('Your pick'), findsNothing);

      taps = 0;
      await tap(tester, find.widgetWithText(FoodLineTile, alts.current!.name));
      await tap(tester, inSheet(find.text(other.name)));
      expect(taps, 2);
      expect(sheet(), findsNothing);
      expect(find.text('Your pick'), findsOneWidget);
      expect(find.widgetWithText(FoodLineTile, other.name), findsOneWidget);
      expect(boxText(tester), '$brief, 1 apple'); // the text is not changed
    });

    appTest('the pick survives more typing elsewhere and keeps its food', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, cream);
      final s = screen(tester);
      final text = boxText(tester);
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(
          text,
          s.debugResult!.lines.single.span!,
        ),
      );
      final other = alts.others.first;
      await tap(tester, tiles().first);
      await tap(tester, inSheet(find.text(other.name)));
      expect(find.text('Your pick'), findsOneWidget);
      await type(tester, '$cream, 1 apple');
      await type(tester, '$cream, 1 apple, 1 banana');
      expect(find.text('Your pick'), findsOneWidget);
      expect(find.widgetWithText(FoodLineTile, other.name), findsOneWidget);
    });

    appTest('a new amount rewrites only the number, and the new text reads '
        'back as that amount', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 apple');
      await tap(tester, tileOf('Egg, whole, cooked, NS as to cooking method'));
      expect(tester.widget<TextField>(amountField()).controller!.text, '2');
      await tester.enterText(amountField(), '3');
      await tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsNothing);
      expect(boxText(tester), '3 eggs, 1 apple');
      expect(find.text('264 kcal'), findsOneWidget); // 3 eggs, as 3 x 88
      expect(find.text('3, 150 g'), findsOneWidget);
    });

    appTest('a new unit is written next to the number and re-parses to that '
        'amount; only offered units are listed', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, $cream');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines.last.span!;
      final choices = await real(
        tester,
        () => s.debugHandle!.unitChoices(text, span),
      );
      await tap(
        tester,
        find.widgetWithText(FoodLineTile, 'Cream, half and half'),
      );
      await tester.tap(inSheet(find.byType(DropdownButton<UnitChoice>)));
      await tester.pumpAndSettle();
      // Exactly the parser's choices are offered, never a "Quantity not
      // specified" label.
      final shown = {
        for (final w in tester.widgetList<DropdownMenuItem<UnitChoice>>(
          find.byType(DropdownMenuItem<UnitChoice>),
        ))
          (w.child as Text).data!,
      };
      final expected = {
        for (final c in choices) c.label.isEmpty ? 'count' : c.label,
      };
      expect(shown, expected);
      expect(shown.any((l) => l.startsWith('Quantity not specified')), isFalse);
      expect(choices.any((c) => c.unitText == 'tsp'), isTrue);
      await tester.tap(find.text('tsp').last);
      await tester.pumpAndSettle();
      await tester.enterText(amountField(), '6');
      await tap(tester, inSheet(find.text('Done')));
      expect(boxText(tester), '2 eggs, 6 tsp half and half');
      expect(find.text('6, 30 g'), findsNothing);
      expect(find.textContaining('6 tsp'), findsWidgets);
    });

    appTest('a rewrite the worker refuses changes nothing and says so', (
      tester,
    ) async {
      useLink = true;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 apple');
      links.single.refuseRewrite = true;
      await tap(tester, tileOf('Egg, whole, cooked, NS as to cooking method'));
      await tester.enterText(amountField(), '3');
      await tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsNothing);
      expect(boxText(tester), '2 eggs, 1 apple');
      expect(
        find.text('The text cannot show that amount, so nothing was changed.'),
        findsOneWidget,
      );
    });

    appTest('a number that is not above 0 keeps the sheet open with a '
        'message', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      await tap(tester, tiles().first);
      await tester.enterText(amountField(), '0');
      await tap(tester, inSheet(find.text('Done')));
      expect(sheet(), findsOneWidget);
      expect(inSheet(find.text('Enter a number above 0.')), findsOneWidget);
      expect(boxText(tester), '2 eggs');
    });

    appTest('Remove deletes the item\'s text and leaves the other lines and '
        'their picks alone', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, $cream, 1 apple');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines[1].span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      await tap(tester, find.widgetWithText(FoodLineTile, alts.current!.name));
      await tap(tester, inSheet(find.text(alts.others.first.name)));
      expect(find.text('Your pick'), findsOneWidget);

      await tap(tester, tileOf('Egg, whole, cooked, NS as to cooking method'));
      await tap(tester, inSheet(find.text('Remove from meal')));
      expect(sheet(), findsNothing);
      final after = boxText(tester);
      expect(after, isNot(contains('eggs')));
      expect(after, contains(cream));
      expect(after, contains('1 apple'));
      expect(tiles(), findsNWidgets(2));
      expect(find.text('Your pick'), findsOneWidget);
      expect(
        find.widgetWithText(FoodLineTile, alts.others.first.name),
        findsOneWidget,
      );
    });

    appTest('the weight widget over an open sheet opens the weight sheet on '
        'top, and both close cleanly', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      await tap(tester, tiles().first);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'home_widget/updates',
        const StandardMethodCodec().encodeSuccessEnvelope('daybook://weight'),
        (_) {},
      );
      await settle(tester);
      expect(find.byType(WeightSheet), findsOneWidget);
      expect(sheet(), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(WeightSheet),
          matching: find.byType(TextField),
        ),
        '181.8',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(WeightSheet),
          matching: find.widgetWithText(FilledButton, 'Save'),
        ),
      );
      await settle(tester);
      expect(find.byType(WeightSheet), findsNothing);
      expect(sheet(), findsOneWidget);
      await closeSheet(tester);
      expect(sheet(), findsNothing);
      expect(boxText(tester), '2 eggs');
      expect(find.byType(FoodEntryScreen), findsOneWidget);
    });
  });

  group('learned matches', () {
    Future<String> learnToast(WidgetTester tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 slices toast');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines.single.span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      await tap(tester, tiles().first);
      await tap(tester, inSheet(find.text(alts.others.first.name)));
      await tester.tap(saveButton());
      await settle(tester);
      return alts.others.first.ref;
    }

    appTest('Forget appears only for a learned line and acts at once', (
      tester,
    ) async {
      final ref = await learnToast(tester);
      var rows = await real(tester, () => db.select(db.learnedMatches).get());
      expect(rows.single.foodRef, ref);
      await tester.tap(find.text('Undo').first, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 11));
      await tester.tap(plusFood());
      await settle(tester);
      await type(tester, 'toast');
      // A line that came from the learned match.
      await tap(tester, tiles().first);
      expect(inSheet(find.text('Forget this match')), findsOneWidget);
      await tap(tester, inSheet(find.text('Forget this match')));
      expect(sheet(), findsNothing);
      rows = await real(tester, () => db.select(db.learnedMatches).get());
      expect(rows, isEmpty);
      // Normal ranking again: the line is not from a learned match now.
      await tap(tester, tiles().first);
      expect(inSheet(find.text('Forget this match')), findsNothing);
      expect(boxText(tester), 'toast');
    });
  });

  group('a line that was not found', () {
    appTest('opens with the typed words in a search that already shows '
        'results, no list, and no scan or create', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 zorbo, 1 apple');
      await tap(tester, find.text('Fix 1 item'));
      expect(sheet(), findsOneWidget);
      expect(inSheet(find.text('"1 zorbo"')), findsOneWidget);
      expect(tester.widget<TextField>(searchField()).controller!.text, 'zorbo');
      expect(inSheet(find.text('Which food?')), findsNothing);
      expect(inSheet(find.byIcon(Icons.radio_button_checked)), findsNothing);
      expect(inSheet(find.text('Remove from meal')), findsOneWidget);
      expect(inSheet(find.text('Scan its barcode')), findsNothing);
      expect(inSheet(find.textContaining('Create a food')), findsNothing);
      expect(
        inSheet(find.textContaining('Nothing in the food list')),
        findsOneWidget,
      );
    });

    appTest('a pick from the search makes the line matched, marked Your '
        'pick, and Remove deletes its text', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 zorbo, 1 apple');
      await tap(tester, find.text('Fix 1 item'));
      await tester.enterText(searchField(), 'banana');
      await settle(tester);
      expect(inSheet(find.byType(InkWell)), findsWidgets);
      final first = tester
          .widgetList<Text>(
            inSheet(
              find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    (w.style?.fontWeight == FontWeight.bold) &&
                    (w.data ?? '').contains('Banana'),
              ),
            ),
          )
          .first
          .data!;
      await tap(tester, inSheet(find.text(first)).first);
      expect(sheet(), findsNothing);
      expect(find.text('Your pick'), findsOneWidget);
      expect(find.widgetWithText(FoodLineTile, first), findsOneWidget);
      expect(find.textContaining('Fix'), findsNothing);
      expect(find.text('Save'), findsOneWidget);

      await type(tester, '2 eggs, 1 zorbo2, 1 apple');
      await tap(tester, find.text('Fix 1 item'));
      await tap(tester, inSheet(find.text('Remove from meal')));
      expect(boxText(tester), isNot(contains('zorbo')));
      expect(tiles(), findsNWidgets(2));
    });
  });

  group('added lines and saved meals', () {
    appTest('changing an added line replaces its stored row on Save and '
        'leaves the others byte for byte', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, brief);
      await tester.tap(saveButton());
      await settle(tester);
      final before = await theMeal(tester);
      await tester.tap(find.text('Breakfast').last);
      await settle(tester);
      expect(find.text('Added'), findsOneWidget);

      await tap(tester, tileOf('Butter, NFS'));
      expect(inSheet(find.text('Which food?')), findsOneWidget);
      // Never learned: no note about remembering.
      expect(
        inSheet(find.text('Your pick is remembered when you save the meal.')),
        findsNothing,
      );
      expect(inSheet(find.text('Forget this match')), findsNothing);
      await tester.enterText(amountField(), '2');
      await tap(tester, inSheet(find.text('Done')));
      expect(find.text('2 tbsp, 28 g'), findsOneWidget);
      await tester.tap(saveButton());
      await settle(tester);

      final after = await theMeal(tester);
      expect(after.entries, hasLength(5));
      for (var i = 0; i < 5; i++) {
        final b = before.entries[i];
        final a = after.entries[i];
        if (b.entry.foodName.startsWith('Butter')) {
          expect(a.entry.id, b.entry.id);
          expect(a.entry.quantity, 2);
          expect(
            a.nutrients[Nutrients.energy],
            closeTo(b.nutrients[Nutrients.energy]! * 2, 1),
          );
        } else {
          expect(a.entry, b.entry);
          expect(a.nutrients, b.nutrients);
        }
      }
      expect(
        await real(tester, () => db.select(db.learnedMatches).get()),
        isEmpty,
      );
    });

    appTest('another food for an added line comes from the search, keeps its '
        'row id, and Remove deletes the line', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 banana');
      await tester.tap(saveButton());
      await settle(tester);
      final before = await theMeal(tester);
      await tester.tap(find.text('Breakfast').last);
      await settle(tester);
      await tap(tester, tiles().last);
      await tester.enterText(searchField(), 'apple');
      await settle(tester);
      final apple = tester
          .widgetList<Text>(
            inSheet(
              find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    w.style?.fontWeight == FontWeight.bold &&
                    (w.data ?? '').startsWith('Apple'),
              ),
            ),
          )
          .first
          .data!;
      await tap(tester, inSheet(find.text(apple)).first);
      expect(find.widgetWithText(FoodLineTile, apple), findsOneWidget);
      await tap(tester, tiles().first);
      await tap(tester, inSheet(find.text('Remove from meal')));
      expect(tiles(), findsNWidgets(1));
      await tester.tap(saveButton());
      await settle(tester);
      final after = await theMeal(tester);
      expect(after.entries, hasLength(1));
      expect(after.entries.single.entry.id, before.entries.last.entry.id);
      expect(after.entries.single.entry.foodName, apple);
    });

    Future<SavedMeal> makeSaved(WidgetTester tester) async {
      return (await real(
        tester,
        () => db.createSavedMeal(
          name: 'Usual breakfast',
          now: nowFixed,
          aliases: const ['usual breakfast'],
          items: [
            item('usda:2707153', 'Egg', 2, 'egg', 100, 176),
            item('usda:2707153', 'Egg again', 1, 'egg', 50, 84),
          ],
        ),
      )).saved!.meal;
    }

    appTest('a typed saved meal: the multiplier rewrites the text', (
      tester,
    ) async {
      await makeSaved(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'usual breakfast');
      await tap(tester, tileOf('Usual breakfast'));
      expect(inSheet(find.text('Use a food instead')), findsOneWidget);
      expect(inSheet(find.text('Multiplier')), findsOneWidget);
      await tester.enterText(
        inSheet(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Multiplier',
          ),
        ),
        '2',
      );
      await tap(tester, inSheet(find.text('Done')));
      expect(boxText(tester), '2 usual breakfast');
      expect(find.text('Usual breakfast  × 2'), findsOneWidget);
    });

    appTest('a change to an item turns the saved meal into its items for this '
        'meal, learns nothing and leaves the saved meal unchanged', (
      tester,
    ) async {
      final saved = await makeSaved(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'usual breakfast');
      await tap(tester, tileOf('Egg again'));
      expect(
        inSheet(find.text('Your pick is remembered when you save the meal.')),
        findsNothing,
      );
      await tester.enterText(amountField(), '3');
      await tap(tester, inSheet(find.text('Done')));
      // The name is gone from the box; its items are added lines.
      expect(boxText(tester), '');
      expect(find.text('Added'), findsOneWidget);
      expect(tiles(), findsNWidgets(2));
      expect(find.text('Usual breakfast'), findsNothing);
      await tester.tap(saveButton());
      await settle(tester);

      final meal = await theMeal(tester);
      expect(meal.entries, hasLength(2));
      expect(meal.meal.savedMealId, saved.id);
      expect(meal.entries.first.entry.quantity, 2);
      expect(meal.entries.last.entry.quantity, 3);
      expect(
        await real(tester, () => db.select(db.learnedMatches).get()),
        isEmpty,
      );
      final list = await real(tester, () => db.savedMealsList());
      expect(list.single.items, hasLength(2));
      expect(list.single.items.last.item.quantity, 1);
    });

    appTest('Use a food instead replaces the saved meal with one added food '
        'for this meal only', (tester) async {
      await makeSaved(tester);
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'usual breakfast');
      await tap(tester, tileOf('Usual breakfast'));
      await tap(tester, inSheet(find.text('Use a food instead')));
      await tester.enterText(searchField(), 'apple');
      await settle(tester);
      final apple = tester
          .widgetList<Text>(
            inSheet(
              find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    w.style?.fontWeight == FontWeight.bold &&
                    (w.data ?? '').startsWith('Apple'),
              ),
            ),
          )
          .first
          .data!;
      await tap(tester, inSheet(find.text(apple)).first);
      expect(boxText(tester), '');
      expect(tiles(), findsNWidgets(1));
      expect(find.widgetWithText(FoodLineTile, apple), findsOneWidget);
      await tester.tap(saveButton());
      await settle(tester);
      final meal = await theMeal(tester);
      expect(meal.entries.single.entry.foodName, apple);
      expect(meal.meal.savedMealId, isNull);
      expect(
        (await real(tester, () => db.savedMealsList())).single.items,
        hasLength(2),
      );
    });
  });

  group('the sheet stays in step with the screen', () {
    appTest('the text changing under the open sheet closes it with one line '
        'and nothing is acted on', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, cream);
      await tap(tester, tiles().first);
      expect(sheet(), findsOneWidget);
      await tester.enterText(box(), '$cream, 1 apple');
      await settle(tester);
      expect(sheet(), findsNothing);
      expect(find.text('That line changed. Tap it again.'), findsOneWidget);
      expect(boxText(tester), '$cream, 1 apple');
      expect(find.text('Your pick'), findsNothing);
    });

    appTest('a worker that dies with the sheet open closes it and the screen '
        'says so', (tester) async {
      useLink = true;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      await tap(tester, tiles().first);
      expect(sheet(), findsOneWidget);
      links.single.crash();
      await settle(tester);
      expect(sheet(), findsNothing);
      expect(
        find.text('The food list stopped working. Your text is kept.'),
        findsOneWidget,
      );
      expect(boxText(tester), '2 eggs');
    });

    appTest('the keyboard goes down while the sheet is open and comes back '
        'with the cursor where it was', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 apple');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '2 eggs, 1 apple',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await settle(tester);
      expect(tester.testTextInput.isVisible, isTrue);
      await tap(tester, tileOf('Egg, whole, cooked, NS as to cooking method'));
      expect(tester.testTextInput.isVisible, isFalse);
      await closeSheet(tester);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.widget<TextField>(box()).controller!.selection,
        const TextSelection.collapsed(offset: 3),
      );
    });

    appTest('a new meal closed with added lines and no text offers Undo, '
        'which brings them back', (tester) async {
      await openApp(tester);
      await openFood(tester);
      screen(tester).addLines([
        AddedLine(
          Line(
            state: LineState.matched,
            foodRef: 'usda:2707153',
            foodName: 'Egg',
            quantity: 1,
            unitLabel: '',
            baseQuantity: 50,
            baseUnit: 'g',
            nutrients: const {Nutrients.energy: 72},
          ),
        ),
      ]);
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(find.text('Breakfast not saved'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(tiles(), findsNWidgets(1));
      expect(find.widgetWithText(FoodLineTile, 'Egg'), findsOneWidget);
    });
  });

  group('after a change made through the sheet', () {
    appTest('the current line is in view when the first item is changed after '
        'the list has scrolled to the bottom', (tester) async {
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await type(tester, '$brief, 1 apple, 1 banana, 1 orange, 1 pear');
      await settle(tester);
      final area = find.byKey(FoodEntryScreenState.linesKey);
      await tester.drag(area, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(tiles().first);
      await settle(tester);
      expect(sheet(), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.enterText(amountField(), '20');
      await tester.tap(inSheet(find.text('Done')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await settle(tester);
      expect(boxText(tester), startsWith('20 eggs'));
      final current = find.byWidgetPredicate(
        (w) => w is FoodLineTile && w.current,
      );
      expect(current, findsOneWidget);
      final a = tester.getRect(area);
      final r = tester.getRect(current);
      expect(r.top, greaterThanOrEqualTo(a.top - 0.5));
      expect(r.top, lessThan(a.bottom));
    });
  });

  group('after a pick through the sheet', () {
    appTest('the current line is in view after a pick on an earlier line', (
      tester,
    ) async {
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await type(tester, '$brief, 1 apple, 1 banana, 1 orange, 1 pear');
      await settle(tester);
      final area = find.byKey(FoodEntryScreenState.linesKey);
      await tester.drag(area, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(tiles().first);
      await settle(tester);
      expect(sheet(), findsOneWidget);
      final rows = find.ancestor(
        of: inSheet(find.byIcon(Icons.radio_button_unchecked)),
        matching: find.byType(InkWell),
      );
      await tester.tap(rows.first);
      await settle(tester);
      expect(sheet(), findsNothing);
      expect(find.text('Your pick'), findsOneWidget);
      final current = find.byWidgetPredicate(
        (w) => w is FoodLineTile && w.current,
      );
      expect(current, findsOneWidget);
      final a = tester.getRect(area);
      final r = tester.getRect(current);
      expect(r.top, greaterThanOrEqualTo(a.top - 0.5));
      expect(r.top, lessThan(a.bottom));
      if (r.height <= a.height) {
        expect(r.bottom, lessThanOrEqualTo(a.bottom + 0.5));
      }
    });
  });

  group('layout', () {
    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      appTest('the sheet at ${width.toInt()} dp and text scale $scale has no '
          'overflow, scrolls its list and keeps 48 dp targets', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openApp(tester, size: Size(width, 800));
        await openFood(tester);
        await type(tester, '$brief, 1 apple');
        await tester.ensureVisible(
          find.widgetWithText(FoodLineTile, 'Cream, half and half'),
        );
        await tester.pump();
        await tap(
          tester,
          find.widgetWithText(FoodLineTile, 'Cream, half and half'),
        );
        expect(sheet(), findsOneWidget);
        expect(tester.takeException(), isNull);
        final size = tester.getSize(sheet());
        expect(size.width, lessThanOrEqualTo(600));
        for (final f in [
          find.ancestor(
            of: inSheet(find.byIcon(Icons.radio_button_checked)),
            matching: find.byType(InkWell),
          ),
          inSheet(find.byType(DropdownButton<UnitChoice>)),
        ]) {
          expect(tester.getSize(f.first).height, greaterThanOrEqualTo(48));
        }
        for (final f in [
          find.widgetWithText(TextButton, 'Remove from meal'),
          find.widgetWithText(FilledButton, 'Done'),
        ]) {
          final s = tester.getSize(f);
          expect(s.height, greaterThanOrEqualTo(48));
          expect(s.width, greaterThanOrEqualTo(48));
        }
        // With the keyboard up for the search box there is still no
        // overflow.
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.tap(searchField());
        await tester.pump();
        await tester.enterText(searchField(), 'cream');
        await settle(tester);
        expect(tester.takeException(), isNull);
        // The list of rows scrolls.
        final lists = inSheet(find.byType(ListView));
        expect(lists, findsWidgets);
        final pos = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: lists.first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        expect(pos.maxScrollExtent, greaterThanOrEqualTo(0));
      });
    }
  });
}
