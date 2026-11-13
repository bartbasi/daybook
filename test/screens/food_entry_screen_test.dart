// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';
import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/screens/food/food_entry_screen.dart';
import 'package:daybook/screens/food/food_line_tile.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Food entry (task 2.8) over the real bundled food data, with the parser
// worker running inline so every result arrives before the call that asked
// for it returns.

const brief =
    '2 eggs, 2 slices sourdough toast, 1 tbsp butter, '
    'coffee with 2 tbsp half and half';

Now at(String date, int h, int m) => Now.fromLocal(date, h * 60 + m, -360);

/// Thursday, Nov 12, 2026, 7:02 am at UTC minus 6.
final nowFixed = at('2026-11-12', 7, 2);

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // A screen that was popped is removed one frame after its exit animation.
  await tester.pump(const Duration(milliseconds: 400));
}

/// Lets a test hold or fail a database write.
class Gate extends QueryInterceptor {
  Completer<void>? hold;
  var failInsert = false;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    await hold?.future;
    if (failInsert) throw StateError('disk full');
    return super.runInsert(executor, statement, args);
  }
}

/// A worker link that answers like the inline worker, and can fail a text
/// request or stop the worker on command.
class FakeLink implements WorkerLink {
  FakeLink(this.parser);

  final Parser parser;
  late final WorkerCore core = WorkerCore(parser);
  void Function(WorkerReply)? reply;
  var failTexts = false;
  var crashOnStart = false;
  var closed = false;

  /// While true, the answers to text requests are kept, not given.
  var hold = false;
  final held = <WorkerReply>[];
  var lastSession = 0;

  void release() {
    hold = false;
    final now = [...held];
    held.clear();
    for (final r in now) {
      reply!(r);
    }
  }

  @override
  void start(void Function(WorkerReply reply) onReply) {
    reply = onReply;
    if (crashOnStart) {
      onReply(const WorkerFailure(0, FailureKind.startup, 'StateError'));
      return;
    }
    onReply(const ReadyReply());
  }

  @override
  void send(WorkerRequest request) {
    if (request is TextRequest) lastSession = request.session;
    if (failTexts && request is TextRequest) {
      reply!(
        WorkerFailure(
          request.id,
          FailureKind.request,
          'StateError',
          session: request.session,
        ),
      );
      return;
    }
    final r = core.handle(request);
    if (r == null) return;
    if (hold && request is TextRequest) {
      held.add(r);
    } else {
      reply!(r);
    }
  }

  void failRequest() => reply!(
    WorkerFailure(0, FailureKind.request, 'StateError', session: lastSession),
  );

  void crash() => reply!(const WorkerFailure(0, FailureKind.crashed, 'exited'));

  @override
  Future<void> close() async => closed = true;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late sqlite.Database usda;
  late SqliteUsdaFoods loader;
  late Parser parser;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('daybook_food_screen');
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
  late Gate gate;
  late Now clockNow;
  var workersMade = 0;
  late List<FakeLink> links;
  FakeLink Function(Parser)? linkMaker;

  setUp(() {
    gate = Gate();
    clockNow = nowFixed;
    db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
    workersMade = 0;
    links = [];
    linkMaker = null;
    FoodEntryScreenState.lineTapObserver = null;
  });

  tearDown(() => FoodEntryScreenState.lineTapObserver = null);

  /// Unmounts the app first, so drift's stream clean-up timer runs, then
  /// closes the database.
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
        clock: () => clockNow,
        foodsPath: Future.value('unused'),
        workerFactory: (_) {
          workersMade++;
          final make = linkMaker;
          if (make == null) return ParseWorker.inlineWith(parser);
          final link = make(parser);
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

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<FilledButton>(button).onPressed != null;

  String boxText(WidgetTester tester) =>
      tester.widget<TextField>(box()).controller!.text;

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<List<Meal>> mealRows(WidgetTester tester) =>
      real(tester, () => db.select(db.meals).get());

  Future<StoredMeal> theMeal(WidgetTester tester) async {
    final rows = await mealRows(tester);
    expect(rows, hasLength(1));
    final StoredMeal? m = await real(tester, () => db.loadMeal(rows.single.id));
    return m!;
  }

  double kcalOf(StoredMeal m) => m.totals[Nutrients.energy]!;

  /// Types the brief's meal, saves it, and returns the stored meal.
  Future<StoredMeal> logBrief(WidgetTester tester) async {
    await openApp(tester);
    await openFood(tester);
    await type(tester, brief);
    await tester.tap(saveButton());
    await settle(tester);
    return theMeal(tester);
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

  group('opening', () {
    appTest('one tap on + Food opens it with the cursor in the box, the '
        'keyboard up, today and the meal from the clock', (tester) async {
      await openApp(tester);
      await tester.tap(plusFood());
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Today, Nov 12'), findsOneWidget);
      for (final slot in ['Breakfast', 'Lunch', 'Dinner', 'Snack']) {
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, slot))
              .selected,
          slot == 'Breakfast',
          reason: slot,
        );
      }
      // Nothing to save yet.
      expect(enabled(tester, saveButton()), isFalse);
    });

    for (final (h, m, slot) in [
      (7, 2, 'Breakfast'),
      (10, 29, 'Breakfast'),
      (10, 30, 'Lunch'),
      (14, 30, 'Snack'),
      (17, 0, 'Dinner'),
      (21, 0, 'Snack'),
      (23, 59, 'Snack'),
    ]) {
      appTest('the meal comes from the clock at $h:$m', (tester) async {
        clockNow = at('2026-11-12', h, m);
        await openApp(tester);
        await openFood(tester);
        for (final s in ['Breakfast', 'Lunch', 'Dinner', 'Snack']) {
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, s))
                .selected,
            s == slot,
            reason: '$h:$m $s',
          );
        }
      });
    }

    appTest('the date moves a day with one tap each way and stops at '
        'today', (tester) async {
      await openApp(tester);
      await openFood(tester);
      IconButton button(String tip) => tester.widget<IconButton>(
        find.widgetWithIcon(
          IconButton,
          tip == 'next' ? Icons.chevron_right : Icons.chevron_left,
        ),
      );
      expect(button('next').onPressed, isNull);

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      expect(find.text('Yesterday, Nov 11'), findsOneWidget);
      expect(button('next').onPressed, isNotNull);
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      expect(find.text('Tue, Nov 10'), findsOneWidget);

      await tester.tap(find.byTooltip('Next day'));
      await tester.tap(find.byTooltip('Next day'));
      await tester.pump();
      expect(find.text('Today, Nov 12'), findsOneWidget);
      expect(button('next').onPressed, isNull);
    });

    appTest('the meal and the date picked are the ones saved', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dinner'));
      await tester.tap(find.byTooltip('Previous day'));
      await type(tester, '1 apple');
      await tester.tap(saveButton());
      await settle(tester);
      final m = (await theMeal(tester)).meal;
      expect(m.localDate, '2026-11-11');
      expect((await real(tester, () => db.loadMeal(m.id)))!.slotName, 'Dinner');
    });
  });

  group('lines and totals', () {
    appTest('the brief meal shows five lines and 490 kcal, and Save stores '
        'five entries totalling 490 kcal', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, brief);
      expect(tiles(), findsNWidgets(5));
      expect(
        find.textContaining('490 kcal', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(saveButton());
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      final meal = await theMeal(tester);
      expect(meal.entries, hasLength(5));
      expect(kcalOf(meal).round(), 490);
      expect(meal.meal.sourceText, brief);
      expect(meal.slotName, 'Breakfast');
      expect(meal.meal.localDate, '2026-11-12');
      expect(find.text('Breakfast saved, 490 kcal'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    appTest('lines update on every change with no delay', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      expect(tiles(), findsNWidgets(1));
      await type(tester, '2 eggs, 1 banana');
      expect(tiles(), findsNWidgets(2));
      await type(tester, '2 eggs');
      expect(tiles(), findsNWidgets(1));
      await type(tester, '');
      expect(tiles(), findsNothing);
      expect(enabled(tester, saveButton()), isFalse);
      await type(tester, '2 eggs, 1 banana, 1 apple');
      expect(tiles(), findsNWidgets(3));
      expect(enabled(tester, saveButton()), isTrue);
    });

    appTest('a line shows the food, the amount, kcal, protein, carbs and '
        'fat', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      expect(find.textContaining('Egg'), findsWidgets);
      expect(find.text('176 kcal'), findsOneWidget);
      expect(find.text('2, 100 g'), findsOneWidget);
      expect(find.text('P 12  C 1  F 14'), findsOneWidget);
    });

    appTest('the half typed item is plain, has no marker and is not '
        'counted', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 zorbo');
      expect(tiles(), findsNWidgets(2));
      // Drawn as plain typing: the typed words, no marker, no "not counted".
      expect(find.text('1 zorbo'), findsOneWidget);
      expect(find.text('Not found'), findsNothing);
      expect(find.text('not counted'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
      expect(find.textContaining('Fix'), findsNothing);
      expect(find.textContaining('item not counted'), findsNothing);
      // Only the eggs are in the total.
      expect(find.textContaining('176 kcal', findRichText: true), findsWidgets);
    });

    appTest('Save with the item still being typed marks it not found and '
        'asks for a pick, and nothing is saved', (tester) async {
      await openApp(tester);
      await openFood(tester);
      final taps = <LineTap>[];
      FoodEntryScreenState.lineTapObserver = taps.add;
      await type(tester, '2 eggs, 1 zorbo');
      await tester.tap(saveButton());
      await settle(tester);
      expect(taps, hasLength(1));
      expect(taps.single.line.state, LineState.notFound);
      expect(taps.single.text, '2 eggs, 1 zorbo');
      expect(await mealRows(tester), isEmpty);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(find.text('Not found'), findsOneWidget);
      expect(find.text('Fix 1 item'), findsOneWidget);
    });

    appTest('a not found item that the cursor has left is counted: "Fix 1 '
        'item" opens that line and saves nothing', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 zorbo, 1 apple');
      expect(find.text('Fix 1 item'), findsOneWidget);
      expect(find.text('1 item not counted'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Not found'), findsOneWidget);
      expect(find.text('Tap to pick a food'), findsOneWidget);
      expect(find.text('"1 zorbo"'), findsOneWidget);
      expect(find.text('not counted'), findsOneWidget);
      expect(
        find.text('Egg, whole, cooked, NS as to cooking method'),
        findsOneWidget,
      );

      final taps = <LineTap>[];
      FoodEntryScreenState.lineTapObserver = taps.add;
      await tester.tap(find.text('Fix 1 item'));
      await settle(tester);
      expect(taps, hasLength(1));
      expect(taps.single.line.state, LineState.notFound);
      expect(taps.single.line.span, isNotNull);
      expect(await mealRows(tester), isEmpty);

      // Tapping a line calls the same hook.
      await tester.tap(tiles().first);
      expect(taps, hasLength(2));
      expect(taps.last.line.state, LineState.matched);
    });

    appTest('two not found items read "Fix 2 items"', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '1 zorbo, 1 blorp, 1 apple');
      expect(find.text('Fix 2 items'), findsOneWidget);
      expect(find.text('2 items not counted'), findsOneWidget);
    });

    appTest('Save is disabled with no lines, and a filler only text gives '
        'no line', (tester) async {
      await openApp(tester);
      await openFood(tester);
      expect(enabled(tester, saveButton()), isFalse);
      await type(tester, 'I had');
      expect(tiles(), findsNothing);
      expect(enabled(tester, saveButton()), isFalse);
    });

    appTest('a saved meal typed by name shows a header with its item lines, '
        'and Save stores the items', (tester) async {
      final created = (await real(
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
      )).saved!;
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'usual breakfast');
      // One header and two items; the header adds nothing of its own.
      expect(tiles(), findsNWidgets(3));
      expect(find.text('Usual breakfast'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(find.textContaining('260 kcal', findRichText: true), findsWidgets);
      final bar = find.textContaining('260 kcal', findRichText: true);
      expect(bar, findsWidgets);
      // The header shows its subtotal once, in its own tile.
      expect(find.text('260 kcal'), findsOneWidget);
      // Items are indented under the header.
      double left(int i) => tester
          .getTopLeft(
            find.descendant(of: tiles().at(i), matching: find.byType(InkWell)),
          )
          .dx;
      expect(left(1), greaterThan(left(0)));

      await tester.tap(saveButton());
      await settle(tester);
      final meal = await theMeal(tester);
      expect(meal.entries, hasLength(2));
      expect(kcalOf(meal), 260);
      expect(meal.meal.savedMealId, created.meal.id);
    });
  });

  group('saving', () {
    appTest('a failing write keeps everything on the screen with the '
        'message', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, brief);
      gate.failInsert = true;
      await tester.tap(saveButton());
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(
        find.text('Could not save. Your meal is still here. Try again.'),
        findsOneWidget,
      );
      expect(boxText(tester), brief);
      expect(tiles(), findsNWidgets(5));
      expect(await mealRows(tester), isEmpty);
      expect(enabled(tester, saveButton()), isTrue);

      gate.failInsert = false;
      await tester.tap(saveButton());
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect((await theMeal(tester)).entries, hasLength(5));
    });

    appTest('the screen closes only after the write returns, and Save '
        'tapped twice writes one meal', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, brief);
      gate.hold = Completer<void>();
      await tester.tap(saveButton());
      await tester.pump();
      await tester.tap(saveButton(), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      // Closing is also refused while the write is in flight.
      await tester.tap(find.byTooltip('Close'), warnIfMissed: false);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);

      gate.hold!.complete();
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect((await theMeal(tester)).entries, hasLength(5));
      expect(find.text('Breakfast saved, 490 kcal'), findsOneWidget);
    });

    appTest('Undo after a save removes exactly that meal', (tester) async {
      await logBrief(tester);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await mealRows(tester), isEmpty);
      expect(
        await real(tester, () => db.select(db.mealEntries).get()),
        isEmpty,
      );
      expect(find.text('Undo'), findsNothing);
      expect(find.textContaining('saved,'), findsNothing);
    });

    appTest('what was learned from a pick is saved with the meal', (
      tester,
    ) async {
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
      final other = alts.others.first.ref;
      expect(
        await real(tester, () => s.debugHandle!.pick(text, span, other)),
        isTrue,
      );
      await tester.pump();
      expect(find.text('Your pick'), findsOneWidget);
      await tester.tap(saveButton());
      await settle(tester);
      final learned = await real(
        tester,
        () => db.select(db.learnedMatches).get(),
      );
      expect(learned.single.foodRef, other);
      expect((await theMeal(tester)).entries.single.entry.foodRef, other);
    });
  });

  group('closing', () {
    appTest('closing with text closes at once and Home offers Undo, which '
        'reopens the screen with the text and the picks', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 slices toast, 1 apple');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines.first.span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      final other = alts.others.first;
      await real(tester, () => s.debugHandle!.pick(text, span, other.ref));
      await tester.pump();
      expect(find.text('Your pick'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      // No popup. Home shows the message at once.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(find.text('Breakfast not saved'), findsOneWidget);
      expect(await mealRows(tester), isEmpty);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(boxText(tester), '2 slices toast, 1 apple');
      expect(tiles(), findsNWidgets(2));
      expect(find.text('Your pick'), findsOneWidget);
      expect(find.text(other.name), findsOneWidget);
      expect(find.text('Breakfast not saved'), findsNothing);
      // Saving it now keeps the pick and learns it.
      await tester.tap(saveButton());
      await settle(tester);
      final meal = await theMeal(tester);
      expect(meal.entries.first.entry.foodRef, other.ref);
      expect(meal.meal.sourceText, '2 slices toast, 1 apple');
    });

    appTest('the system back button closes with text the same way', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(find.text('Breakfast not saved'), findsOneWidget);
    });

    appTest('closing with an empty box closes with no message', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(find.textContaining('not saved'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    });
  });

  group('editing a logged meal', () {
    Future<void> openLogged(WidgetTester tester) async {
      await tester.tap(find.text('Breakfast').last);
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
    }

    appTest('tapping the meal opens it with its entries as added lines and '
        'an empty box', (tester) async {
      await logBrief(tester);
      await openLogged(tester);
      expect(find.text('Editing Breakfast'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      expect(tiles(), findsNWidgets(5));
      expect(boxText(tester), '');
      // The keyboard stays down so the lines can be read.
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        find.textContaining('490 kcal', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Tap to type more'), findsOneWidget);
      // Nothing was parsed or priced again: the stored values are shown.
      expect(
        find.text('Egg, whole, cooked, NS as to cooking method'),
        findsOneWidget,
      );
    });

    appTest('saving with no change leaves every stored value identical', (
      tester,
    ) async {
      final before = await logBrief(tester);
      // Even if time passes: the logged time stays.
      clockNow = at('2026-11-12', 15, 15);
      await openLogged(tester);
      await tester.tap(saveButton());
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      final after = await theMeal(tester);
      expect(after.meal, before.meal);
      expect(after.entries.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(after.entries[i].entry, before.entries[i].entry);
        expect(after.entries[i].nutrients, before.entries[i].nutrients);
      }
      expect(find.text('Breakfast saved, 490 kcal'), findsOneWidget);
      // An edit has no Undo: the earlier version is not kept.
      expect(find.text('Undo'), findsNothing);
    });

    appTest('removing one added line and typing one adds a new line, keeps '
        'the others and appends the text', (tester) async {
      final before = await logBrief(tester);
      await openLogged(tester);
      final remove = find.byWidgetPredicate(
        (w) => w is IconButton && (w.tooltip ?? '').startsWith('Remove Butter'),
      );
      await tester.tap(remove);
      await tester.pump();
      expect(tiles(), findsNWidgets(4));
      await type(tester, '1 banana');
      expect(find.text('From your text'), findsOneWidget);
      expect(tiles(), findsNWidgets(5));
      await tester.tap(saveButton());
      await settle(tester);

      final after = await theMeal(tester);
      expect(after.entries, hasLength(5));
      final butter = before.entries.firstWhere(
        (e) => e.entry.foodName.startsWith('Butter'),
      );
      expect(after.entries.any((e) => e.entry.id == butter.entry.id), isFalse);
      final kept = before.entries.where((e) => e != butter);
      for (final k in kept) {
        final now = after.entries.firstWhere((e) => e.entry.id == k.entry.id);
        expect(now.nutrients, k.nutrients);
        expect(now.entry.foodRef, k.entry.foodRef);
        expect(now.entry.quantity, k.entry.quantity);
      }
      expect(after.entries.last.entry.foodName, contains('Banana'));
      expect(after.meal.sourceText, '$brief\n1 banana');
    });

    appTest('Delete meal removes it at once and Home offers Undo, which '
        'puts back the same rows, once', (tester) async {
      final before = await logBrief(tester);
      await openLogged(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete meal'));
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(await mealRows(tester), isEmpty);
      expect(find.text('Breakfast deleted, 490 kcal'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      final after = await theMeal(tester);
      expect(after.meal, before.meal);
      expect(
        [for (final e in after.entries) e.entry],
        [for (final e in before.entries) e.entry],
      );
      // One Undo: the held rows are dropped with the message.
      expect(find.text('Undo'), findsNothing);
      expect(find.textContaining('deleted'), findsNothing);
    });

    appTest('an Undo that is not used leaves the meal deleted after ten '
        'seconds', (tester) async {
      await logBrief(tester);
      await tester.pump(const Duration(seconds: 11));
      await openLogged(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete meal'));
      await settle(tester);
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Undo'), findsNothing);
      expect(await mealRows(tester), isEmpty);
    });

    appTest('a new meal has no Delete meal in its menu', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Delete meal'), findsNothing);
      expect(find.text('Save as a saved meal'), findsOneWidget);
    });

    Finder dialogSave() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    Finder dialogField() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    appTest('Save as a saved meal asks for a name, refuses an empty or a '
        'taken one, and makes the saved meal', (tester) async {
      await logBrief(tester);
      await openLogged(tester);
      Future<void> openDialog() async {
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save as a saved meal'));
        await tester.pumpAndSettle();
      }

      await openDialog();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(dialogSave());
      await settle(tester);
      expect(find.text('Give it a name.'), findsOneWidget);

      await tester.enterText(dialogField(), 'Usual breakfast');
      await tester.tap(dialogSave());
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Saved meal "Usual breakfast" created.'),
        findsOneWidget,
      );
      final saved = await real(tester, () => db.savedMealsList());
      expect(saved, hasLength(1));
      expect(saved.single.items, hasLength(5));
      expect(saved.single.aliases, isEmpty); // its own name expands it
      expect(saved.single.meal.name, 'Usual breakfast');

      // Two saved meals may share a name: the newest wins when it is typed.
      await openDialog();
      await tester.enterText(dialogField(), 'Usual breakfast');
      await tester.tap(dialogSave());
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await real(tester, () => db.savedMealsList()), hasLength(2));
    });

    appTest('Save as a saved meal does not make one from some of the lines', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 zorbo');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as a saved meal'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(
          'An item was not found, so the saved meal was not made. Fix it first.',
        ),
        findsOneWidget,
      );
      expect(await real(tester, () => db.savedMealsList()), isEmpty);
    });

    appTest('a failing delete keeps the screen and says so', (tester) async {
      await logBrief(tester);
      await openLogged(tester);
      // The meal is gone from under the screen, so the delete finds nothing.
      await real(tester, () => db.delete(db.meals).go());
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete meal'));
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(
        find.text('Could not delete. The meal is still logged.'),
        findsOneWidget,
      );
    });
  });

  group('the weight widget', () {
    Future<void> sendLink(WidgetTester tester) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'home_widget/updates',
        const StandardMethodCodec().encodeSuccessEnvelope('daybook://weight'),
        (_) {},
      );
      await settle(tester);
    }

    appTest('a widget tap over the food screen opens the weight sheet over '
        'it, keeps the text, and shows the confirmation there without '
        'covering the totals or Save', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 banana');
      await sendLink(tester);
      expect(find.byType(WeightSheet), findsOneWidget);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(boxText(tester), '2 eggs, 1 banana');

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
      expect(boxText(tester), '2 eggs, 1 banana');
      expect(tiles(), findsNWidgets(2));
      expect(await mealRows(tester), isEmpty);

      final message = find.descendant(
        of: find.byType(FoodEntryScreen),
        matching: find.text('Weight saved: 181.8 lb, today 7:02 am'),
      );
      expect(message, findsOneWidget);
      // The bar is under the chips, clear of the totals bar and of Save.
      final msgRect = tester.getRect(message);
      final saveRect = tester.getRect(saveButton());
      final totals = tester.getRect(
        find.textContaining('kcal', findRichText: true).last,
      );
      expect(msgRect.bottom, lessThan(saveRect.top));
      expect(msgRect.bottom, lessThan(totals.top));
      expect(tester.getRect(find.text('Undo')).bottom, lessThan(saveRect.top));
      expect(enabled(tester, saveButton()), isTrue);

      // Undo marks the weigh-in deleted, and the text is still there.
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(message, findsNothing);
      final w = await real(tester, () => db.select(db.weightEntries).get());
      expect(w.single.deletedAtMs, isNotNull);
      expect(boxText(tester), '2 eggs, 1 banana');
    });
  });

  group('the parser worker', () {
    appTest('a failed request keeps Save off until a good result', (
      tester,
    ) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      expect(enabled(tester, saveButton()), isTrue);

      links.single.failTexts = true;
      await type(tester, '2 eggs, 1 apple');
      expect(enabled(tester, saveButton()), isFalse);
      expect(
        find.text(
          'Could not read that just now. Keep typing and it will catch up.',
        ),
        findsOneWidget,
      );
      // Still not enabled while the lines are for older text.
      await tester.pump();
      expect(enabled(tester, saveButton()), isFalse);

      links.single.failTexts = false;
      await type(tester, '2 eggs, 1 apple ');
      expect(enabled(tester, saveButton()), isTrue);
      expect(find.textContaining('Could not read'), findsNothing);
    });

    appTest('a dead worker keeps the text, hides the lines, disables Save '
        'and says so once; opening the screen again uses a new worker', (
      tester,
    ) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 apple');
      expect(tiles(), findsNWidgets(2));
      expect(workersMade, 1);

      links.single.crash();
      await tester.pump();
      expect(boxText(tester), '2 eggs, 1 apple');
      expect(tiles(), findsNothing);
      expect(enabled(tester, saveButton()), isFalse);
      expect(
        find.text('The food list stopped working. Your text is kept.'),
        findsOneWidget,
      );
      expect(find.textContaining('Close this screen'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      await openFood(tester);
      expect(workersMade, 2);
      await type(tester, '2 eggs');
      expect(tiles(), findsNWidgets(1));
      expect(enabled(tester, saveButton()), isTrue);
    });
  });

  group('the food data', () {
    appTest(
      'while the food data is being installed the screen opens and says so, then reads the text typed so far',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final path = Completer<String>();
        await tester.pumpWidget(
          DaybookApp(
            db: db,
            clock: () => clockNow,
            foodsPath: path.future,
            workerFactory: (_) => ParseWorker.inlineWith(parser),
          ),
        );
        await settle(tester);
        await openFood(tester);
        expect(find.text('Getting the food list ready...'), findsOneWidget);
        await type(tester, '2 eggs');
        expect(boxText(tester), '2 eggs');
        expect(enabled(tester, saveButton()), isFalse);

        // The data arrives: the text typed so far is read.
        path.complete('unused');
        await settle(tester);
        expect(find.text('Getting the food list ready...'), findsNothing);
        expect(tiles(), findsNWidgets(1));
        expect(enabled(tester, saveButton()), isTrue);
      },
    );

    appTest('food data that cannot be installed keeps the text and says the '
        'list stopped', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final path = Completer<String>();
      await tester.pumpWidget(
        DaybookApp(
          db: db,
          clock: () => clockNow,
          foodsPath: path.future,
          workerFactory: (_) => ParseWorker.inlineWith(parser),
        ),
      );
      await settle(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      path.completeError(StateError('no disk'));
      await settle(tester);
      expect(boxText(tester), '2 eggs');
      expect(find.textContaining('stopped working'), findsOneWidget);
      expect(enabled(tester, saveButton()), isFalse);
    });
  });

  group('markers', () {
    appTest('each marker has its word and its spoken label', (tester) async {
      final semantics = tester.ensureSemantics();
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'coffee with 2 tbsp half and half, 1 zorbo, 1 apple');
      expect(find.text('Guess'), findsOneWidget);
      expect(find.text('Assumed'), findsOneWidget);
      expect(find.text('Not found'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Assumed\. Coffee.*calories\. Double tap to change\.$'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Guess\. Cream, half and half\. 2 tablespoons, 30 grams\. 39 calories\. Double tap to change\.$',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Not found. 1 zorbo. Not counted. Double tap to pick a food.',
        ),
        findsOneWidget,
      );

      // Your pick, on a typed line.
      await type(tester, '2 slices toast');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines.single.span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      await real(
        tester,
        () => s.debugHandle!.pick(text, span, alts.others.first.ref),
      );
      await tester.pump();
      expect(find.text('Your pick'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Your pick\. .*Double tap to change\.$'),
        ),
        findsOneWidget,
      );

      // Scanned, on an added line, with the Open Food Facts credit.
      s.addLines([
        const AddedLine(
          Line(
            state: LineState.matched,
            foodRef: 'local:1',
            foodName: 'Skyr',
            quantity: 1,
            unitLabel: 'container',
            baseQuantity: 150,
            baseUnit: 'g',
            nutrients: {Nutrients.energy: 90, Nutrients.protein: 15},
            markers: {Marker.scanned},
          ),
        ),
      ]);
      await tester.pump();
      expect(find.text('Scanned'), findsOneWidget);
      expect(find.text('Data from Open Food Facts (ODbL)'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Scanned. Skyr. 1 container, 150 grams. 90 calories. Double tap to change.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    appTest('a saved meal header is read as a saved meal and has no marker '
        'word', (tester) async {
      final semantics = tester.ensureSemantics();
      await real(
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
      );
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'usual breakfast');
      expect(
        find.bySemanticsLabel(
          'Saved meal. Usual breakfast. 2 items. 260 calories. Double tap to change.',
        ),
        findsOneWidget,
      );
      for (final w in [
        'Guess',
        'Assumed',
        'Not found',
        'Your pick',
        'Scanned',
      ]) {
        expect(find.text(w), findsNothing);
      }
      semantics.dispose();
    });
  });

  group('the review of task 2.8', () {
    Future<void> sendLink(WidgetTester tester) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'home_widget/updates',
        const StandardMethodCodec().encodeSuccessEnvelope('daybook://weight'),
        (_) {},
      );
      await settle(tester);
    }

    Future<List<LearnedMatche>> learned(WidgetTester tester) =>
        real(tester, () => db.select(db.learnedMatches).get());

    /// Picks the first other food for the only typed line, as the correction
    /// sheet will.
    Future<String> pickOther(
      WidgetTester tester, {
      Marker marker = Marker.yourPick,
    }) async {
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines.single.span!;
      final alts = await real(
        tester,
        () => s.debugHandle!.alternatives(text, span),
      );
      final ref = alts.others.first.ref;
      await real(
        tester,
        () => s.debugHandle!.pick(text, span, ref, marker: marker),
      );
      await tester.pump();
      return ref;
    }

    Future<void> saveAndSettle(WidgetTester tester) async {
      await tester.tap(saveButton());
      await settle(tester);
    }

    // M1

    appTest('Try again after the worker died keeps the text and brings the '
        'lines back, and Save works', (tester) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 apple');
      links.single.crash();
      await tester.pump();
      expect(tiles(), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Try again')).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(workersMade, 2);
      expect(boxText(tester), '2 eggs, 1 apple');
      expect(tiles(), findsNWidgets(2));
      expect(find.text('Try again'), findsNothing);
      expect(enabled(tester, saveButton()), isTrue);
      await saveAndSettle(tester);
      final meal = await theMeal(tester);
      expect(meal.entries, hasLength(2));
      expect(meal.meal.sourceText, '2 eggs, 1 apple');
    });

    appTest('when Try again fails too, the message and the button stay', (
      tester,
    ) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      links.single.crash();
      await tester.pump();
      linkMaker = (p) => FakeLink(p)..crashOnStart = true;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('stopped working'), findsOneWidget);
      expect(boxText(tester), '2 eggs');
      expect(enabled(tester, saveButton()), isFalse);
    });

    appTest('Try again sends the picks again only for text the result '
        'matches', (tester) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 slices toast');
      await pickOther(tester);
      expect(find.text('Your pick'), findsOneWidget);
      links.single.crash();
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Your pick'), findsOneWidget);

      links.last.crash();
      await tester.pump();
      await type(tester, '2 slices toast ');
      await tester.tap(find.text('Try again'));
      await settle(tester);
      // The text moved on while the worker was dead: no stale pick.
      expect(find.text('Your pick'), findsNothing);
    });

    // M2

    appTest('a double tap on Undo after a delete restores the meal and '
        'shows no false failure', (tester) async {
      final before = await logBrief(tester);
      await tester.tap(find.text('Breakfast').last);
      await settle(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete meal'));
      await settle(tester);
      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await settle(tester);
      expect(find.textContaining('Could not undo'), findsNothing);
      expect((await theMeal(tester)).meal, before.meal);
    });

    appTest('a double tap on Undo after a save deletes the meal and shows '
        'no false failure', (tester) async {
      await logBrief(tester);
      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await settle(tester);
      expect(find.textContaining('Could not undo'), findsNothing);
      expect(await mealRows(tester), isEmpty);
    });

    // S1

    appTest('closing while Save waits for the parser returns the draft, and '
        'the late result saves nothing', (tester) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      links.single.hold = true;
      await tester.tap(saveButton());
      await tester.pump();
      // The box stays editable: nothing toggles read-only.
      expect(tester.widget<TextField>(box()).readOnly, isFalse);
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(find.text('Breakfast not saved'), findsOneWidget);
      links.single.release();
      await settle(tester);
      expect(await mealRows(tester), isEmpty);
    });

    appTest('the system back button also closes while Save waits', (
      tester,
    ) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      links.single.hold = true;
      await tester.tap(saveButton());
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
    });

    // S2

    appTest('a pick from older text is not in the draft', (tester) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 slices toast');
      await pickOther(tester);
      links.single.failTexts = true;
      await type(tester, '2 slices bagel');
      expect(enabled(tester, saveButton()), isFalse);
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      links.single.failTexts = false;
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(boxText(tester), '2 slices bagel');
      expect(find.text('Your pick'), findsNothing);
      await saveAndSettle(tester);
      expect(await learned(tester), isEmpty);
    });

    // S3

    appTest('tapping the date opens a calendar that ends today', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await tester.tap(find.text('Today, Nov 12'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('10'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Tue, Nov 10'), findsOneWidget);

      await tester.tap(find.text('Tue, Nov 10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('13')); // after today: cannot be picked
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Tue, Nov 10'), findsOneWidget);
      // The arrows still work.
      await tester.tap(find.byTooltip('Next day'));
      await tester.pump();
      expect(find.text('Yesterday, Nov 11'), findsOneWidget);
    });

    // S4

    appTest('the line for the item under the cursor is in view above the '
        'totals bar at 344 dp with the keyboard up, and has the ring', (
      tester,
    ) async {
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await type(tester, brief);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tiles(), findsNWidgets(5));
      final last = tester.getRect(tiles().last);
      expect(last.bottom, lessThanOrEqualTo(tester.getRect(saveButton()).top));
      expect(last.top, greaterThanOrEqualTo(0));
      expect(tester.widget<FoodLineTile>(tiles().last).current, isTrue);
      expect(tester.widget<FoodLineTile>(tiles().first).current, isFalse);
    });

    // S5

    appTest('with no counted line the totals are zeros, read as zeros', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openApp(tester);
      await openFood(tester);
      expect(
        find.textContaining('0 kcal  P 0  C 0  F 0', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Meal total: 0 calories, protein 0 grams, carbs 0 grams, fat 0 grams.',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    // S7

    appTest('closing an edit with typed text says the changes were not '
        'saved, and Undo reopens the edit', (tester) async {
      await logBrief(tester);
      await tester.tap(find.text('Breakfast').last);
      await settle(tester);
      await type(tester, '1 banana');
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.text('Changes to Breakfast not saved'), findsOneWidget);
      expect(find.text('Breakfast not saved'), findsNothing);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Editing Breakfast'), findsOneWidget);
      expect(tiles(), findsNWidgets(6));
      expect(boxText(tester), '1 banana');
    });

    // S8

    appTest('the spoken totals include the count of items not counted', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 zorbo, 1 apple');
      expect(
        find.bySemanticsLabel(RegExp(r'^Meal total: .* 1 item not counted\.$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    // S9

    appTest('a widget tap while Save is running opens no sheet', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      gate.hold = Completer<void>();
      await tester.tap(saveButton());
      await tester.pump();
      await sendLink(tester);
      expect(find.byType(WeightSheet), findsNothing);
      gate.hold!.complete();
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect(find.text('Breakfast saved, 176 kcal'), findsOneWidget);
    });

    appTest('a meal saved for another day names the day on Home', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await tester.tap(find.byTooltip('Previous day'));
      await type(tester, '2 eggs');
      await saveAndSettle(tester);
      expect(
        find.text('Breakfast saved for yesterday, 176 kcal'),
        findsOneWidget,
      );
    });

    // S10

    appTest('rule 4: with a late result Save stays off, then turns on', (
      tester,
    ) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      expect(enabled(tester, saveButton()), isTrue);
      links.single.hold = true;
      await type(tester, '2 eggs, 1 apple');
      expect(enabled(tester, saveButton()), isFalse);
      expect(tiles(), findsNWidgets(1)); // the lines are for older text
      links.single.release();
      await tester.pump();
      expect(enabled(tester, saveButton()), isTrue);
      expect(tiles(), findsNWidgets(2));
    });

    appTest('rule 5: nothing is written while the result for the text with '
        'no cursor is pending, then the meal is saved from it', (tester) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs, 1 apple');
      links.single.hold = true;
      await tester.tap(saveButton());
      await settle(tester);
      expect(await mealRows(tester), isEmpty);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      links.single.release();
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      expect((await theMeal(tester)).entries, hasLength(2));
    });

    appTest('a failure during the wait saves nothing and leaves the screen '
        'usable with the text kept', (tester) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      links.single.hold = true;
      await tester.tap(saveButton());
      await tester.pump();
      links.single.failRequest();
      await tester.pump();
      links.single.hold = false;
      links.single.held.clear();
      expect(await mealRows(tester), isEmpty);
      expect(boxText(tester), '2 eggs');
      expect(enabled(tester, saveButton()), isFalse);
      // Typing again gives a good result and Save works.
      await type(tester, '2 eggs, 1 apple');
      expect(enabled(tester, saveButton()), isTrue);
      await saveAndSettle(tester);
      expect((await theMeal(tester)).entries, hasLength(2));
    });

    appTest('a crash during the wait saves nothing and keeps the text', (
      tester,
    ) async {
      linkMaker = FakeLink.new;
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 eggs');
      links.single.hold = true;
      await tester.tap(saveButton());
      await tester.pump();
      links.single.crash();
      await tester.pump();
      expect(await mealRows(tester), isEmpty);
      expect(boxText(tester), '2 eggs');
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    // The learning flags (grammar 7.2, rule 12).

    appTest('a line from a learned match saved unchanged counts up', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 slices toast');
      final ref = await pickOther(tester);
      await saveAndSettle(tester);
      expect((await learned(tester)).single.timesUsed, 1);

      await tester.tap(find.text('Undo').first, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 11));
      await tester.tap(plusFood());
      await settle(tester);
      await type(tester, 'toast');
      expect(find.text('Your pick'), findsNothing);
      await saveAndSettle(tester);
      final rows = await learned(tester);
      expect(rows.single.foodRef, ref);
      expect(rows.single.timesUsed, 2);
    });

    appTest('a typed line marked Scanned is learned', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 slices toast');
      final ref = await pickOther(tester, marker: Marker.scanned);
      expect(find.text('Scanned'), findsOneWidget);
      await saveAndSettle(tester);
      expect((await learned(tester)).single.foodRef, ref);
    });

    appTest('an added line that carries a pick marker is never learned', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      screen(tester).addLines([
        const AddedLine(
          Line(
            state: LineState.matched,
            foodRef: 'usda:2707153',
            foodName: 'Egg',
            quantity: 1,
            unitLabel: '',
            baseQuantity: 50,
            baseUnit: 'g',
            nutrients: {Nutrients.energy: 72},
            markers: {Marker.yourPick},
            learnedKey: 'egg',
          ),
        ),
      ]);
      await tester.pump();
      await saveAndSettle(tester);
      expect((await theMeal(tester)).entries, hasLength(1));
      expect(await learned(tester), isEmpty);
    });

    appTest('an amount set in the sheet on an assumed amount is stored', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await type(tester, 'coffee');
      final s = screen(tester);
      final text = boxText(tester);
      final span = s.debugResult!.lines.single.span!;
      final out = await real(
        tester,
        () => s.debugHandle!.rewriteAmount(
          text,
          text.length,
          span,
          quantity: 2,
          unit: 'cup',
        ),
      );
      expect(out, isNotNull);
      await tester.enterText(box(), out!.text);
      await tester.pump();
      await saveAndSettle(tester);
      final row = (await learned(tester)).single;
      expect(row.quantity, 2);
      expect(row.unitLabel, 'cup');
    });

    appTest('a saved meal typed with a multiplier stores scaled values', (
      tester,
    ) async {
      await real(
        tester,
        () => db.createSavedMeal(
          name: 'Usual breakfast',
          now: nowFixed,
          items: [item('usda:2707153', 'Egg', 2, 'egg', 100, 176)],
        ),
      );
      await openApp(tester);
      await openFood(tester);
      await type(tester, '2 usual breakfast');
      expect(find.text('Usual breakfast  × 2'), findsOneWidget);
      await saveAndSettle(tester);
      final e = (await theMeal(tester)).entries.single;
      expect(e.entry.quantity, 4);
      expect(e.entry.baseQuantity, 200);
      expect(e.nutrients[Nutrients.energy], 352);
      expect(await learned(tester), isEmpty);
    });
  });

  group('layout', () {
    for (final width in [344.0, 673.0]) {
      appTest('no overflow at ${width.toInt()} dp with the keyboard up, and '
          'Save stays reachable above it', (tester) async {
        await openApp(tester, size: Size(width, 800));
        await openFood(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await type(tester, brief);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.testTextInput.isVisible, isTrue);

        final save = tester.getRect(saveButton());
        expect(save.bottom, lessThanOrEqualTo(800 - 300));
        expect(save.left, greaterThanOrEqualTo(0));
        expect(save.right, lessThanOrEqualTo(width));
        final content = tester.getRect(box());
        expect(content.width, lessThanOrEqualTo(600));

        // Tap targets are at least 48 dp.
        for (final f in [
          saveButton(),
          find.widgetWithIcon(IconButton, Icons.close),
          find.widgetWithIcon(IconButton, Icons.chevron_left),
          find.widgetWithIcon(IconButton, Icons.chevron_right),
          find.byType(PopupMenuButton<String>),
          find.widgetWithText(ChoiceChip, 'Lunch'),
          tiles().first,
        ]) {
          final s = tester.getSize(f);
          expect(s.height, greaterThanOrEqualTo(48), reason: '$f');
          expect(s.width, greaterThanOrEqualTo(48), reason: '$f');
        }

        // Save works with the keyboard still up.
        await tester.tap(saveButton());
        await settle(tester);
        expect(find.byType(FoodEntryScreen), findsNothing);
        expect((await theMeal(tester)).entries, hasLength(5));
      });
    }

    appTest('2x text at 344 dp with the keyboard up has no overflow and '
        'Save is above the keyboard', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await type(tester, '$brief, 1 zorbo, 1 apple');
      await tester.pump();
      expect(tester.takeException(), isNull);
      final save = tester.getRect(
        find.widgetWithText(FilledButton, 'Fix 1 item'),
      );
      expect(save.bottom, lessThanOrEqualTo(500));
      expect(save.top, greaterThanOrEqualTo(0));
      await tester.tap(find.widgetWithText(FilledButton, 'Fix 1 item'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
    });

    appTest('editing a meal at 344 dp and 2x text has no overflow', (
      tester,
    ) async {
      await logBrief(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(344, 800);
      await tester.pump();
      await tester.tap(find.text('Breakfast').last);
      await settle(tester);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      final remove = tester.getSize(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Remove Butter, NFS',
        ),
      );
      expect(remove.height, greaterThanOrEqualTo(48));
      expect(remove.width, greaterThanOrEqualTo(48));
    });

    Finder linesArea() => find.byKey(FoodEntryScreenState.linesKey);
    double linesOffset(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(of: linesArea(), matching: find.byType(Scrollable))
              .first,
        )
        .position
        .pixels;

    /// The box is wholly above the keyboard and on screen, the caret is
    /// inside the box, the lines area sits between the box and the totals
    /// bar, and the current line is wholly in view whenever it can fit.
    void expectBoxAndCaretVisible(WidgetTester tester, String at) {
      final boxRect = tester.getRect(box());
      expect(boxRect.top, greaterThanOrEqualTo(0), reason: at);
      expect(boxRect.bottom, lessThanOrEqualTo(500), reason: at);
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final caret = editable.getLocalRectForCaret(
        TextPosition(offset: boxText(tester).length),
      );
      final caretGlobal = MatrixUtils.transformRect(
        editable.getTransformTo(null),
        caret,
      );
      expect(
        boxRect.inflate(0.5).contains(caretGlobal.center),
        isTrue,
        reason: '$at caret $caretGlobal box $boxRect',
      );
      final area = tester.getRect(linesArea());
      expect(area.top, greaterThanOrEqualTo(boxRect.bottom - 0.5), reason: at);
      final bar = tester.getRect(find.byType(FilledButton)).top;
      expect(area.bottom, lessThanOrEqualTo(bar + 0.5), reason: at);
      final current = find.byWidgetPredicate(
        (w) => w is FoodLineTile && w.current,
      );
      if (current.evaluate().length == 1) {
        final r = tester.getRect(current);
        if (r.height <= area.height) {
          expect(r.top, greaterThanOrEqualTo(area.top - 0.5), reason: at);
          expect(r.bottom, lessThanOrEqualTo(area.bottom + 0.5), reason: at);
        }
      }
    }

    // Types the text one character at a time and checks after every key.
    Future<void> typeSlowly(WidgetTester tester, String text) async {
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(box(), text.substring(0, i));
        await settle(tester);
        final at = 'after "${text.substring(0, i)}"';
        expectBoxAndCaretVisible(tester, at);
        final offset = linesOffset(tester);
        for (var f = 0; f < 4; f++) {
          await tester.pump(const Duration(milliseconds: 50));
          expect(linesOffset(tester), offset, reason: '$at frame $f');
          expectBoxAndCaretVisible(tester, at);
        }
        expect(tester.takeException(), isNull, reason: at);
      }
    }

    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      appTest('typing the meal one key at a time at ${width.toInt()} dp and '
          'text scale $scale keeps the box and caret in view and the lines '
          'still', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openApp(tester, size: Size(width, 800));
        await openFood(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await typeSlowly(tester, '$brief, 1 apple');
        expect(find.byType(FilledButton), findsOneWidget);
      });
    }

    appTest('a scroll of the lines by hand is left alone until the next '
        'text change', (tester) async {
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await type(tester, '$brief, 1 apple, 1 banana, 1 orange, 1 pear');
      await settle(tester);
      final area = linesArea();
      expect(
        tester
            .state<ScrollableState>(
              find
                  .descendant(of: area, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .maxScrollExtent,
        greaterThan(0),
      );
      await tester.drag(area, const Offset(0, 1000));
      await settle(tester);
      expect(linesOffset(tester), 0);
      for (var f = 0; f < 5; f++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(linesOffset(tester), 0);
      expect(tester.getRect(box()).top, greaterThanOrEqualTo(0));

      // The next change brings the current line back.
      await type(tester, '$brief, 1 apple, 1 banana, 1 orange, 1 pea');
      await settle(tester);
      expect(linesOffset(tester), greaterThan(0));
      expectBoxAndCaretVisible(tester, 'after the next change');
    });

    for (final (name, text, fix) in [
      ('Save', brief, false),
      ('Fix', '$brief, 1 zorbo, 1 apple', true),
    ]) {
      appTest('at 2x text on 344 dp with the keyboard up, the $name state '
          'keeps the top row, the box and a compact bar in view', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openApp(tester, size: const Size(344, 800));
        await openFood(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await type(tester, text);
        await settle(tester);
        expect(tester.takeException(), isNull);

        final button = find.byType(FilledButton);
        expect(
          find.descendant(
            of: button,
            matching: find.text(fix ? 'Fix 1 item' : 'Save'),
          ),
          findsOneWidget,
        );
        final boxRect = tester.getRect(box());
        final close = tester.getRect(find.byTooltip('Close'));
        expect(close.top, greaterThanOrEqualTo(0));
        expect(close.bottom, lessThanOrEqualTo(boxRect.top));
        expect(boxRect.bottom, lessThanOrEqualTo(500));
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(500));
        final area = tester.getRect(linesArea());
        expect(500 - area.bottom, lessThanOrEqualTo(500 / 3 + 1));
        expect(area.top, greaterThanOrEqualTo(boxRect.bottom - 0.5));
        final seen = [
          for (final t in tiles().evaluate())
            tester.getRect(find.byWidget(t.widget)).overlaps(area),
        ];
        expect(seen, contains(true));
        expectBoxAndCaretVisible(tester, 'at 2x');

        await tester.tap(find.byTooltip('Previous day'));
        await tester.pump();
        expect(find.text('Yesterday, Nov 11'), findsOneWidget);
        await tester.tap(find.byTooltip('Next day'));
        await tester.pump();
        expect(find.text('Today, Nov 12'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await settle(tester);
        expect(find.byType(FoodEntryScreen), findsNothing);
      });
    }

    appTest('folding keeps the typed text', (tester) async {
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      await type(tester, '2 eggs, 1 banana');
      tester.view.physicalSize = const Size(673, 800);
      await tester.pump();
      expect(boxText(tester), '2 eggs, 1 banana');
      expect(tiles(), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });
}
