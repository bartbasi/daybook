// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/app_info.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_data.dart';
import 'package:daybook/data/food_library_data.dart';
import 'package:daybook/data/nutrients.dart';
import 'package:daybook/data/off_client.dart';
import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/platform/barcode.dart';
import 'package:daybook/screens/food/barcode_scan_screen.dart';
import 'package:daybook/screens/food/correction_sheet.dart';
import 'package:daybook/screens/food/food_entry_screen.dart';
import 'package:daybook/screens/food/food_line_tile.dart';
import 'package:daybook/screens/my_foods/food_editor.dart';
import 'package:daybook/strings.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'food_entry_screen_test.dart' show nowFixed, settle;

// Barcode scanning (task 2.11) through the real food entry screen, the real
// correction sheet and the real data, with a fake camera and a mock HTTP
// client. No camera is opened and nothing leaves the test.

const yogurtCode = '5000000000012';
// Words no USDA food has, so typing them can only mean this product.
const yogurtName = 'Zorblat Yogurt';

/// A product as Open Food Facts answers: 60 kcal per 100 g, one serving of
/// 150 g, so 90 kcal a serving (food-entry frame 10).
String yogurt({
  String? name = yogurtName,
  bool energy = true,
  bool serving = true,
  String code = yogurtCode,
}) => jsonEncode({
  'status': 1,
  'code': code,
  'product': {
    'code': code,
    'product_name': ?name,
    'brands': 'Test Dairy',
    if (serving) 'serving_quantity': 150,
    if (serving) 'serving_size': '1 container',
    'nutriments': {
      if (energy) 'energy-kcal_100g': 60,
      'proteins_100g': 10,
      'carbohydrates_100g': 4,
      'fat_100g': 0,
    },
  },
});

/// Stands in for the camera. A test says what the camera sees with [emit] or
/// what went wrong with [fail].
class FakeCamera extends BarcodeCamera {
  void Function(String, bool)? onCode;
  void Function(CameraProblem)? onProblem;
  var views = 0;
  CameraProblem? failWith;

  @override
  Widget view({
    required void Function(String code, bool upcE) onCode,
    required void Function(CameraProblem problem) onProblem,
  }) {
    views++;
    this.onCode = onCode;
    this.onProblem = onProblem;
    final problem = failWith;
    if (problem != null) scheduleMicrotask(() => onProblem(problem));
    return const SizedBox.expand(key: ValueKey('fake-camera'));
  }

  void emit(String code, {bool upcE = false}) => onCode!(code, upcE);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late sqlite.Database usda;
  late SqliteUsdaFoods loader;
  late Parser parser;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('daybook_barcode');
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
  late FakeCamera camera;
  late List<http.Request> requests;

  /// What the mock answers. A test replaces it.
  late Future<http.Response> Function(http.Request) answer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    camera = FakeCamera();
    requests = [];
    answer = (_) async => http.Response(yogurt(), 200);
  });

  void appTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const channels = ['home_widget', 'home_widget/updates'];
      for (final c in channels) {
        messenger.setMockMethodCallHandler(MethodChannel(c), (_) async => null);
      }
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(db.close);
        for (final c in channels) {
          messenger.setMockMethodCallHandler(MethodChannel(c), null);
        }
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
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      DaybookApp(
        db: db,
        clock: () => nowFixed,
        foodsPath: Future.value('unused'),
        workerFactory: (_) => ParseWorker.inlineWith(parser),
        camera: camera,
        offClient: OffClient(
          MockClient((r) {
            requests.add(r);
            return answer(r);
          }),
          userAgent: offUserAgent(appVersion),
        ),
      ),
    );
    await settle(tester);
  }

  Finder plusFood() => find.widgetWithText(FilledButton, '+ Food');
  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  Finder scanButton() => find.widgetWithText(OutlinedButton, 'Scan');
  Finder scanScreen() => find.byType(BarcodeScanScreen);
  Finder box() => find.descendant(
    of: find.byType(FoodEntryScreen),
    matching: find.byType(TextField),
  );
  Finder tiles() => find.byType(FoodLineTile);
  Finder sheet() => find.byType(CorrectionSheet);
  Finder inSheet(Finder f) => find.descendant(of: sheet(), matching: f);

  Future<void> openFood(WidgetTester tester) async {
    await tester.tap(plusFood());
    await settle(tester);
    expect(find.byType(FoodEntryScreen), findsOneWidget);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(box(), text);
    await tester.pump();
  }

  /// Time for the lookup, the save and the parser to finish.
  Future<void> settleMore(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
  }

  /// Taps Scan and lets the scan screen open.
  Future<void> openScan(WidgetTester tester, {Finder? button}) async {
    await tester.tap(button ?? scanButton());
    await settle(tester);
    expect(scanScreen(), findsOneWidget);
  }

  /// Opens the scan screen and sees [code].
  Future<void> scan(
    WidgetTester tester,
    String code, {
    Finder? button,
    bool upcE = false,
  }) async {
    await openScan(tester, button: button);
    camera.emit(code, upcE: upcE);
    await settleMore(tester);
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<List<Food>> foodRows(WidgetTester tester) =>
      real(tester, () => db.select(db.foods).get());

  Future<StoredMeal> theMeal(WidgetTester tester) async {
    final rows = await real(tester, () => db.select(db.meals).get());
    expect(rows, hasLength(1));
    final StoredMeal? m = await real(tester, () => db.loadMeal(rows.single.id));
    return m!;
  }

  Line lineOf(WidgetTester tester, int i) =>
      tester.widget<FoodLineTile>(tiles().at(i)).line;

  group('a found product', () {
    appTest('adds one added line at 1 serving, marked Scanned, with the '
        'credit, and Save stores it and learns nothing', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);

      // The scan screen closed; one line, listed under "Added".
      expect(scanScreen(), findsNothing);
      expect(find.text('Added'), findsOneWidget);
      expect(tiles(), findsOneWidget);
      final line = lineOf(tester, 0);
      expect(line.foodName, contains(yogurtName));
      expect(line.markers, contains(Marker.scanned));
      expect(line.markers, isNot(contains(Marker.assumed)));
      expect(line.state, LineState.matched);
      expect(find.text('Assumed'), findsNothing);
      expect(line.quantity, 1);
      expect(line.baseQuantity, 150);
      expect(line.nutrients[Nutrients.energy], closeTo(90, 1e-6));
      expect(find.text('Scanned'), findsOneWidget);
      expect(find.text('Data from Open Food Facts (ODbL)'), findsOneWidget);
      expect(find.textContaining('90 kcal'), findsWidgets);
      // Nothing was written into the text box.
      expect(tester.widget<TextField>(box()).controller!.text, '');

      await tester.tap(saveButton());
      await settleMore(tester);
      expect(find.byType(FoodEntryScreen), findsNothing);
      final meal = await theMeal(tester);
      expect(meal.entries, hasLength(1));
      final e = meal.entries.single.entry;
      final foods = await foodRows(tester);
      expect(foods, hasLength(1));
      expect(foods.single.kind, 'off');
      expect(foods.single.barcode, yogurtCode);
      expect(e.foodRef, 'local:${foods.single.id}');
      expect(e.quantity, 1);
      expect(e.baseQuantity, 150);
      expect(e.baseUnit, 'g');
      expect(
        meal.entries.single.nutrients[Nutrients.energy],
        closeTo(90, 1e-6),
      );
      expect(
        await real(tester, () => db.select(db.learnedMatches).get()),
        isEmpty,
      );
    });

    appTest('is cached and then found by typing its name, with its own '
        'dataset in the sheet', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      await type(tester, 'zorblat yogurt');
      expect(tiles(), findsNWidgets(2));
      final typed = lineOf(tester, 1);
      expect(typed.state, isNot(LineState.notFound));
      expect(typed.foodName, contains(yogurtName));
      expect(typed.foodRef, lineOf(tester, 0).foodRef);

      // The sheet names the dataset: not "My food".
      await tester.tap(tiles().at(1));
      await settle(tester);
      expect(sheet(), findsOneWidget);
      expect(
        inSheet(find.textContaining('Open Food Facts (ODbL)')),
        findsWidgets,
      );
      expect(inSheet(find.textContaining('My food')), findsNothing);
    });

    appTest('a second scan of the same barcode reuses the cached row and '
        'sends no request', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      await scan(tester, yogurtCode);
      expect(tiles(), findsNWidgets(2));
      expect(requests, hasLength(1));
      final foods = await foodRows(tester);
      expect(foods, hasLength(1));
      expect(lineOf(tester, 0).foodRef, lineOf(tester, 1).foodRef);
      expect(lineOf(tester, 1).markers, contains(Marker.scanned));
    });

    appTest("a barcode that is the user's own food uses that food", (
      tester,
    ) async {
      final now = nowFixed;
      final own = await real(
        tester,
        () => db.createCustomFood(
          const CustomFoodInput(
            name: 'My own yogurt',
            basis: FoodBasis.perServing,
            nutrients: {Nutrients.energy: 123},
            barcode: yogurtCode,
          ),
          now,
        ),
      );
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(tiles(), findsOneWidget);
      final line = lineOf(tester, 0);
      expect(line.foodRef, own.ref);
      expect(line.foodName, 'My own yogurt');
      expect(line.markers, contains(Marker.scanned));
      expect(line.nutrients[Nutrients.energy], closeTo(123, 1e-6));
      // Still one food row, and it is still the user's own, unchanged.
      final foods = await foodRows(tester);
      expect(foods, hasLength(1));
      expect(foods.single.kind, 'custom');
      expect(foods.single.name, 'My own yogurt');
    });
  });

  group('nothing found', () {
    appTest('not found adds nothing and says so', (tester) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      await openApp(tester);
      await openFood(tester);
      await scan(tester, '0123456789012');
      expect(scanScreen(), findsNothing);
      expect(tiles(), findsNothing);
      expect(find.text('No product found for 0123456789012.'), findsOneWidget);
      expect(find.text('Add it as your own food'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
      expect(requests, hasLength(1));
    });

    appTest('a product with no energy value or no name is treated as not '
        'found and saves nothing', (tester) async {
      for (final body in [yogurt(energy: false), yogurt(name: null)]) {
        answer = (_) async => http.Response(body, 200);
        await openApp(tester);
        await openFood(tester);
        await scan(tester, yogurtCode);
        expect(tiles(), findsNothing);
        expect(find.text('No product found for $yogurtCode.'), findsOneWidget);
        expect(await foodRows(tester), isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
      }
    });

    appTest('no connection adds nothing, says so, and a second try '
        'works', (tester) async {
      answer = (_) async => throw http.ClientException('offline');
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(scanScreen(), findsNothing);
      expect(tiles(), findsNothing);
      expect(
        find.text(
          'Could not reach Open Food Facts. Check the connection and try '
          'again.',
        ),
        findsOneWidget,
      );
      expect(await foodRows(tester), isEmpty);

      answer = (_) async => http.Response(yogurt(), 200);
      await scan(tester, yogurtCode);
      expect(tiles(), findsOneWidget);
      expect(lineOf(tester, 0).foodName, contains(yogurtName));
      expect(requests, hasLength(2));
    });

    appTest('a server error counts as no connection', (tester) async {
      answer = (_) async => http.Response('oops', 503);
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(tiles(), findsNothing);
      expect(
        find.textContaining('Could not reach Open Food Facts'),
        findsOneWidget,
      );
    });

    appTest('a product that cannot be saved adds nothing and says so', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await tester.runAsync(
        () => db.customStatement('DROP TABLE food_nutrients'),
      );
      await scan(tester, yogurtCode);
      expect(tiles(), findsNothing);
      expect(
        find.text('Could not save that product. Nothing was added. Try again.'),
        findsOneWidget,
      );
    });

    appTest('cancelling adds nothing and sends nothing', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await openScan(tester);
      await tester.tap(find.byTooltip('Close').last);
      await settle(tester);
      expect(scanScreen(), findsNothing);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(tiles(), findsNothing);
      expect(requests, isEmpty);
      expect(await foodRows(tester), isEmpty);
      // The back button cancels too.
      await openScan(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(scanScreen(), findsNothing);
      expect(requests, isEmpty);
    });
  });

  group('the one request', () {
    appTest('exactly one request per scan, to the Open Food Facts product '
        'address, with the agreed User-Agent and no image request', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(requests, hasLength(1));
      final r = requests.single;
      expect(r.method, 'GET');
      expect(r.url.scheme, 'https');
      expect(r.url.host, 'world.openfoodfacts.org');
      expect(r.url.path, '/api/v2/product/$yogurtCode.json');
      expect(r.headers['User-Agent'], 'Daybook/1.0.0 (bartbasi@gmail.com)');
      expect(r.headers['User-Agent'], offUserAgent(appVersion));
      expect(r.url.queryParameters['fields'], isNot(contains('image')));
      await scan(tester, '4006381333931');
      expect(requests, hasLength(2));
      expect(requests.last.url.path, '/api/v2/product/4006381333931.json');
      for (final q in requests) {
        expect(q.url.host, 'world.openfoodfacts.org');
        expect(q.url.path, isNot(contains('image')));
        expect(q.url.path, isNot(matches(RegExp(r'\.(jpe?g|png|webp)$'))));
      }
    });

    appTest('a scan while a lookup is running does nothing', (tester) async {
      final hold = Completer<http.Response>();
      answer = (_) => hold.future;
      await openApp(tester);
      await openFood(tester);
      await openScan(tester);
      camera.emit(yogurtCode);
      await tester.pump();
      // The same barcode again and another one, while the first is running.
      camera.emit(yogurtCode);
      camera.emit('4006381333931');
      await tester.pump();
      expect(find.text('Looking it up on Open Food Facts...'), findsOneWidget);
      // Nothing can be closed or typed meanwhile.
      final close = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.close).last,
      );
      expect(close.onPressed, isNull);
      expect(requests, hasLength(1));
      hold.complete(http.Response(yogurt(), 200));
      await settleMore(tester);
      expect(requests, hasLength(1));
      expect(tiles(), findsOneWidget);
      expect(await foodRows(tester), hasLength(1));
    });

    appTest('the number can be typed instead, and a bad one is refused '
        'before anything is sent', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await openScan(tester);
      await tester.tap(find.text('Type the number instead'));
      await settle(tester);
      expect(find.byKey(const ValueKey('fake-camera')), findsNothing);
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Barcode number',
      );
      await tester.enterText(field, '12ab');
      await tester.tap(find.text('Look up'));
      await tester.pump();
      expect(
        find.text(
          'Enter the 8, 12, 13 or 14 digits printed under the barcode.',
        ),
        findsOneWidget,
      );
      expect(requests, isEmpty);
      await tester.enterText(field, yogurtCode);
      await tester.tap(find.text('Look up'));
      await settleMore(tester);
      expect(requests, hasLength(1));
      expect(tiles(), findsOneWidget);
    });
  });

  group('the camera', () {
    appTest('permission is asked only when the scan screen opens', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      expect(camera.views, 0);
      await openScan(tester);
      expect(camera.views, greaterThan(0));
    });

    appTest('a refused permission says so in plain words, and the way '
        'back works', (tester) async {
      camera.failWith = CameraProblem.noPermission;
      await openApp(tester);
      await openFood(tester);
      await openScan(tester);
      await settle(tester);
      expect(find.textContaining('Camera access is off'), findsOneWidget);
      expect(find.textContaining('settings'), findsOneWidget);
      expect(find.byKey(const ValueKey('fake-camera')), findsNothing);
      // Typing the number is still there, and so is the way back.
      expect(find.text('Type the number instead'), findsOneWidget);
      await tester.tap(find.byTooltip('Close').last);
      await settle(tester);
      expect(scanScreen(), findsNothing);
      expect(tiles(), findsNothing);
      expect(requests, isEmpty);
    });

    appTest('a camera that will not start says so', (tester) async {
      camera.failWith = CameraProblem.unavailable;
      await openApp(tester);
      await openFood(tester);
      await openScan(tester);
      await settle(tester);
      expect(find.textContaining('The camera could not start'), findsOneWidget);
    });
  });

  group('"Scan its barcode" in the not found sheet', () {
    Future<void> openNotFoundSheet(WidgetTester tester) async {
      await type(tester, '2 eggs, 1 zorbo, 1 apple');
      await tester.tap(find.text('Fix 1 item'));
      await settle(tester);
      expect(sheet(), findsOneWidget);
    }

    appTest('the scanned product becomes that item\'s food, marked '
        'Scanned', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await openNotFoundSheet(tester);
      expect(
        inSheet(
          find.textContaining('scan the package, or make it your own food'),
        ),
        findsOneWidget,
      );
      await scan(
        tester,
        yogurtCode,
        button: inSheet(
          find.widgetWithText(OutlinedButton, 'Scan its barcode'),
        ),
      );
      expect(sheet(), findsNothing);
      expect(scanScreen(), findsNothing);
      // Three typed lines, no "Fix", and the middle one matches the product.
      expect(find.textContaining('Fix'), findsNothing);
      expect(tiles(), findsNWidgets(3));
      final line = lineOf(tester, 1);
      expect(line.state, LineState.matched);
      expect(line.foodName, contains(yogurtName));
      expect(line.markers, contains(Marker.scanned));
      expect(find.text('Scanned'), findsOneWidget);
      expect(find.text('Data from Open Food Facts (ODbL)'), findsOneWidget);
      expect(find.text('Not found'), findsNothing);
      // The text is unchanged and the pick is kept while typing elsewhere.
      expect(
        tester.widget<TextField>(box()).controller!.text,
        '2 eggs, 1 zorbo, 1 apple',
      );
      await type(tester, '2 eggs, 1 zorbo, 1 apple, 1 banana');
      expect(lineOf(tester, 1).markers, contains(Marker.scanned));

      await tester.tap(saveButton());
      await settleMore(tester);
      final meal = await theMeal(tester);
      final foods = await foodRows(tester);
      expect(foods, hasLength(1));
      expect(
        meal.entries.map((e) => e.entry.foodRef),
        contains('local:${foods.single.id}'),
      );
      // A pick made in the sheet is sticky and learned: the typed words now
      // point at the scanned product.
      final learned = await real(
        tester,
        () => db.select(db.learnedMatches).get(),
      );
      expect(learned, hasLength(1));
      expect(learned.single.foodRef, 'local:${foods.single.id}');
      expect(learned.single.foodName, contains(yogurtName));
    });

    appTest('a barcode with no product shows the message in the sheet and '
        'keeps the sheet open', (tester) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      await openApp(tester);
      await openFood(tester);
      await openNotFoundSheet(tester);
      await scan(
        tester,
        '0123456789012',
        button: inSheet(
          find.widgetWithText(OutlinedButton, 'Scan its barcode'),
        ),
      );
      expect(sheet(), findsOneWidget);
      expect(
        inSheet(find.text('No product found for 0123456789012.')),
        findsOneWidget,
      );
      expect(find.text('Not found'), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
    });

    appTest('cancelling leaves the sheet as it was', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await openNotFoundSheet(tester);
      await openScan(
        tester,
        button: inSheet(
          find.widgetWithText(OutlinedButton, 'Scan its barcode'),
        ),
      );
      await tester.tap(find.byTooltip('Close').last);
      await settle(tester);
      expect(sheet(), findsOneWidget);
      expect(requests, isEmpty);
      expect(find.text('Not found'), findsOneWidget);
    });
  });

  group('add it as your own food', () {
    const code = '0123456789012';
    Finder editor() => find.byType(FoodEditor);
    Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    Finder addOwn() =>
        find.widgetWithText(TextButton, 'Add it as your own food');

    Future<void> notFound(WidgetTester tester) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      await openApp(tester);
      await openFood(tester);
      await scan(tester, code);
      expect(find.text('No product found for $code.'), findsOneWidget);
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.tap(f);
      await settle(tester);
    }

    Future<void> openNotFoundSheet(WidgetTester tester) async {
      await type(tester, '2 eggs, 1 zorbo, 1 apple');
      await tap(tester, find.text('Fix 1 item'));
      expect(sheet(), findsOneWidget);
    }

    Future<void> makeFood(WidgetTester tester) async {
      await tester.enterText(field('Name'), 'Zorbo bar');
      await tester.enterText(field('Calories'), '210');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settleMore(tester);
    }

    appTest('the message has the button, 48 dp, and it opens the editor with '
        'the barcode in its stored form', (tester) async {
      await notFound(tester);
      expect(addOwn(), findsOneWidget);
      expect(tester.getSize(addOwn()).height, greaterThanOrEqualTo(48));
      await tap(tester, addOwn());
      expect(editor(), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Barcode (optional)')).controller!.text,
        code,
      );
      expect(tester.widget<TextField>(field('Name')).controller!.text, '');
    });

    appTest('the message with the button stays until the button is tapped; '
        'tapping it clears the message, so a return from the editor does not '
        'offer the same barcode again', (tester) async {
      await notFound(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(addOwn(), findsOneWidget);
      expect(find.text('No product found for $code.'), findsOneWidget);
      await tap(tester, addOwn());
      expect(editor(), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      expect(editor(), findsNothing);
      expect(addOwn(), findsNothing);
      expect(find.text('No product found for $code.'), findsNothing);
    });

    appTest('a message with no button still goes after ten seconds', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      answer = (_) async => http.Response('', 500);
      await scan(tester, code);
      expect(find.text(S.scanNoConnection), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
      expect(find.text(S.scanNoConnection), findsNothing);
    });

    appTest('a 12 digit scan is filled in as its 13 digit form', (
      tester,
    ) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      await openApp(tester);
      await openFood(tester);
      await scan(tester, '036000291452');
      await tap(tester, addOwn());
      expect(
        tester.widget<TextField>(field('Barcode (optional)')).controller!.text,
        '0036000291452',
      );
    });

    appTest('saving adds the food as an added line at 1 serving, not marked '
        'Scanned, with no Open Food Facts credit; the next scan finds it with '
        'no request', (tester) async {
      await notFound(tester);
      await tap(tester, addOwn());
      await makeFood(tester);
      expect(editor(), findsNothing);
      expect(find.byType(FoodEntryScreen), findsOneWidget);
      expect(tiles(), findsOneWidget);
      final line = lineOf(tester, 0);
      expect(line.foodName, 'Zorbo bar');
      expect(line.quantity, 1);
      expect(line.markers, isNot(contains(Marker.scanned)));
      expect(line.markers, isNot(contains(Marker.assumed)));
      expect(find.text('Scanned'), findsNothing);
      expect(find.text('Data from Open Food Facts (ODbL)'), findsNothing);
      expect(find.text('Added'), findsOneWidget);
      expect(line.nutrients[Nutrients.energy], 210);
      expect(requests, hasLength(1));

      await scan(tester, code);
      expect(requests, hasLength(1));
      expect(tiles(), findsNWidgets(2));
      expect(lineOf(tester, 1).foodRef, line.foodRef);
      expect(lineOf(tester, 1).markers, contains(Marker.scanned));

      await tester.tap(saveButton());
      await settleMore(tester);
      final meal = await theMeal(tester);
      final foods = await foodRows(tester);
      expect(foods.single.kind, 'custom');
      expect(foods.single.barcode, code);
      expect(meal.entries, hasLength(2));
      expect(meal.entries.first.entry.foodRef, 'local:${foods.single.id}');
      expect(
        await real(tester, () => db.select(db.learnedMatches).get()),
        isEmpty,
      );
    });

    appTest('cancelling the editor adds nothing and creates nothing', (
      tester,
    ) async {
      await notFound(tester);
      await tap(tester, addOwn());
      await tester.pageBack();
      await settleMore(tester);
      expect(editor(), findsNothing);
      expect(tiles(), findsNothing);
      expect(await foodRows(tester), isEmpty);
    });

    appTest("from the sheet the new food becomes that line's food, marked "
        'Your pick and not Scanned', (tester) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      await openApp(tester);
      await openFood(tester);
      await openNotFoundSheet(tester);
      await scan(
        tester,
        code,
        button: inSheet(
          find.widgetWithText(OutlinedButton, 'Scan its barcode'),
        ),
      );
      expect(sheet(), findsOneWidget);
      final button = inSheet(
        find.widgetWithText(OutlinedButton, 'Add it as your own food'),
      );
      expect(button, findsOneWidget);
      await tap(tester, button);
      expect(editor(), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Barcode (optional)')).controller!.text,
        code,
      );
      await makeFood(tester);
      expect(editor(), findsNothing);
      expect(sheet(), findsNothing);
      expect(find.textContaining('Fix'), findsNothing);
      expect(find.text('Your pick'), findsOneWidget);
      expect(find.text('Scanned'), findsNothing);
      expect(find.text('Data from Open Food Facts (ODbL)'), findsNothing);
      final foods = await foodRows(tester);
      expect(foods.single.barcode, code);
      expect(
        tester.widget<TextField>(box()).controller!.text,
        '2 eggs, 1 zorbo, 1 apple',
      );
    });

    appTest('cancelling the editor from the sheet leaves the sheet and its '
        'message as they were', (tester) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      await openApp(tester);
      await openFood(tester);
      await openNotFoundSheet(tester);
      await scan(
        tester,
        code,
        button: inSheet(
          find.widgetWithText(OutlinedButton, 'Scan its barcode'),
        ),
      );
      await tap(
        tester,
        inSheet(find.widgetWithText(OutlinedButton, 'Add it as your own food')),
      );
      await tester.pageBack();
      await settleMore(tester);
      expect(sheet(), findsOneWidget);
      expect(inSheet(find.text('No product found for $code.')), findsOneWidget);
      expect(await foodRows(tester), isEmpty);
    });
  });

  group('serving, credit and dataset', () {
    appTest('a product with a serving is Scanned and not Assumed, on screen '
        'and spoken, and reads as one serving of 150 g', (tester) async {
      final semantics = tester.ensureSemantics();
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(find.text('Scanned'), findsOneWidget);
      expect(find.text('Assumed'), findsNothing);
      expect(find.textContaining('150 g'), findsWidgets);
      expect(
        find.bySemanticsLabel(RegExp(r'^Scanned\. .*Double tap to change\.$')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Assumed')), findsNothing);
      semantics.dispose();
    });

    appTest('a product with no serving is 100 g, Scanned and Assumed', (
      tester,
    ) async {
      answer = (_) async => http.Response(yogurt(serving: false), 200);
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      final line = lineOf(tester, 0);
      expect(line.baseQuantity, 100);
      expect(line.markers, containsAll([Marker.scanned, Marker.assumed]));
      expect(find.text('Assumed'), findsOneWidget);
      expect(find.text('Scanned'), findsOneWidget);
      // A second scan of the cached product still knows it has no serving.
      await scan(tester, yogurtCode);
      expect(requests, hasLength(1));
      expect(lineOf(tester, 1).markers, contains(Marker.assumed));
    });

    appTest('the sheet of a scanned product says Open Food Facts, not My '
        'food', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(find.text('Data from Open Food Facts (ODbL)'), findsOneWidget);
      await tester.tap(tiles().first);
      await settle(tester);
      expect(sheet(), findsOneWidget);
      expect(
        inSheet(find.textContaining('Open Food Facts (ODbL)')),
        findsWidgets,
      );
      expect(inSheet(find.textContaining('My food')), findsNothing);
    });

    appTest('a scan of the own food of the user has no Open Food Facts '
        'credit, and its sheet says My food', (tester) async {
      await real(
        tester,
        () => db.createCustomFood(
          const CustomFoodInput(
            name: 'My own yogurt',
            basis: FoodBasis.perServing,
            nutrients: {Nutrients.energy: 123},
            barcode: yogurtCode,
          ),
          nowFixed,
        ),
      );
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(tiles(), findsOneWidget);
      expect(find.text('Scanned'), findsOneWidget);
      expect(find.text('Data from Open Food Facts (ODbL)'), findsNothing);
      await tester.tap(tiles().first);
      await settle(tester);
      expect(inSheet(find.textContaining('My food')), findsWidgets);
    });

    appTest('a typed line matched to a cached product shows the credit', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      await type(tester, 'zorblat yogurt');
      expect(tiles(), findsNWidgets(2));
      expect(find.text('Data from Open Food Facts (ODbL)'), findsNWidgets(2));
    });
  });

  group('looking in the stored foods first', () {
    appTest('a cached product is used with no request, also with no '
        'connection', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(requests, hasLength(1));
      answer = (_) async => throw http.ClientException('offline');
      await scan(tester, yogurtCode);
      expect(requests, hasLength(1));
      expect(tiles(), findsNWidgets(2));
      expect(lineOf(tester, 1).foodName, contains(yogurtName));
      expect(lineOf(tester, 1).markers, contains(Marker.scanned));
      expect(
        find.textContaining('Could not reach Open Food Facts'),
        findsNothing,
      );
    });

    appTest('the own food of the user is used with no request, also when '
        'Open Food Facts would say 404', (tester) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      final own = await real(
        tester,
        () => db.createCustomFood(
          const CustomFoodInput(
            name: 'My own yogurt',
            basis: FoodBasis.perServing,
            nutrients: {Nutrients.energy: 123},
            barcode: yogurtCode,
          ),
          nowFixed,
        ),
      );
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(requests, isEmpty);
      expect(lineOf(tester, 0).foodRef, own.ref);
      expect(find.textContaining('No product found'), findsNothing);
    });

    appTest('an archived food with that barcode is ignored and one request '
        'goes out', (tester) async {
      final id = await real(
        tester,
        () => db
            .into(db.foods)
            .insert(
              FoodsCompanion.insert(
                kind: 'off',
                name: 'Old yogurt',
                barcode: const Value(yogurtCode),
                baseAmount: 100,
                baseUnit: 'g',
                archived: const Value(true),
                createdAtMs: 1,
                updatedAtMs: 1,
              ),
            ),
      );
      await openApp(tester);
      await openFood(tester);
      await scan(tester, yogurtCode);
      expect(requests, hasLength(1));
      expect(tiles(), findsOneWidget);
      expect(lineOf(tester, 0).foodRef, 'local:$id');
      expect(lineOf(tester, 0).foodName, contains(yogurtName));
    });
  });

  group('the form of a barcode', () {
    Finder numberField() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Barcode number',
    );

    appTest('a scanned UPC-A and the same number typed as 13 digits are one '
        'product and one row', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, '049000028911');
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v2/product/0049000028911.json');
      await openScan(tester);
      await tester.tap(find.text('Type the number instead'));
      await settle(tester);
      await tester.enterText(numberField(), '0049000028911');
      await tester.tap(find.text('Look up'));
      await settleMore(tester);
      expect(requests, hasLength(1));
      expect(tiles(), findsNWidgets(2));
      final foods = await foodRows(tester);
      expect(foods, hasLength(1));
      expect(foods.single.barcode, '0049000028911');
    });

    appTest('a UPC-E code is looked up as its UPC-A, an EAN-8 as it is', (
      tester,
    ) async {
      await openApp(tester);
      await openFood(tester);
      await scan(tester, '04252614', upcE: true);
      expect(requests.single.url.path, '/api/v2/product/0042100005264.json');
      await scan(tester, '96385074');
      expect(requests.last.url.path, '/api/v2/product/96385074.json');
      expect((await foodRows(tester)).map((f) => f.barcode).toSet(), {
        '0042100005264',
        '96385074',
      });
    });

    appTest('a typed number with a wrong last digit is refused in plain '
        'words and nothing is sent', (tester) async {
      await openApp(tester);
      await openFood(tester);
      await openScan(tester);
      await tester.tap(find.text('Type the number instead'));
      await settle(tester);
      for (final bad in ['4006381333932', '96385075', '049000028910']) {
        await tester.enterText(numberField(), bad);
        await tester.tap(find.text('Look up'));
        await tester.pump();
        expect(
          find.text(
            'That number does not look right. Check the digits under the '
            'barcode and try again.',
          ),
          findsOneWidget,
          reason: bad,
        );
      }
      expect(requests, isEmpty);
      await tester.enterText(numberField(), '4006381333931');
      await tester.tap(find.text('Look up'));
      await settleMore(tester);
      expect(requests, hasLength(1));
    });
  });

  group('typed numbers of 8 and 14 digits', () {
    Finder numberField() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Barcode number',
    );

    Future<void> lookUpTyped(WidgetTester tester, String code) async {
      await tester.enterText(numberField(), code);
      await tester.tap(find.text('Look up'));
      await tester.pump();
    }

    Future<void> openTyping(WidgetTester tester) async {
      await openApp(tester);
      await openFood(tester);
      await openScan(tester);
      await tester.tap(find.text('Type the number instead'));
      await settle(tester);
    }

    appTest('a UPC-E number typed by hand is sent once, as its 13 digit '
        'form', (tester) async {
      await openTyping(tester);
      await lookUpTyped(tester, '04252614');
      await settleMore(tester);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v2/product/0042100005264.json');
      expect(find.text(S.scanNumberCheck), findsNothing);
    });

    appTest('a valid EAN-8 typed is sent unchanged', (tester) async {
      await openTyping(tester);
      await lookUpTyped(tester, '96385074');
      await settleMore(tester);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v2/product/96385074.json');
    });

    appTest('a typed UPC-E that also passes the EAN-8 check is looked up as '
        'its UPC-A form', (tester) async {
      await openTyping(tester);
      await lookUpTyped(tester, '00010054');
      await settleMore(tester);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v2/product/0000100000054.json');
    });

    appTest('a food saved in the editor with such a barcode is found by a '
        'camera scan of the same UPC-E, with no request', (tester) async {
      answer = (_) async => http.Response('{"status":0}', 404);
      await openTyping(tester);
      await lookUpTyped(tester, '00010054');
      await settleMore(tester);
      expect(requests, hasLength(1));
      await tester.tap(
        find.widgetWithText(TextButton, 'Add it as your own food'),
      );
      await settle(tester);
      final barcode = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Barcode (optional)',
      );
      expect(
        tester.widget<TextField>(barcode).controller!.text,
        '0000100000054',
      );
      // The same number typed in the editor by hand is kept as its 13 digit
      // form too.
      await tester.enterText(barcode, '00010054');
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Name',
        ),
        'Zorbo bar',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Calories',
        ),
        '210',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settleMore(tester);
      final rows = await foodRows(tester);
      expect(rows.single.barcode, '0000100000054');
      expect(tiles(), findsOneWidget);
      await scan(tester, '00010054', upcE: true);
      expect(requests, hasLength(1));
      expect(tiles(), findsNWidgets(2));
      expect(lineOf(tester, 1).foodName, 'Zorbo bar');
    });

    appTest('an 8 digit number that is neither EAN-8 nor UPC-E is refused '
        'and nothing is sent', (tester) async {
      await openTyping(tester);
      // Starts with 0 but its UPC-A form fails too; and one starting with 5.
      for (final bad in ['04252615', '55555556']) {
        await lookUpTyped(tester, bad);
        expect(find.text(S.scanNumberCheck), findsOneWidget, reason: bad);
      }
      expect(requests, isEmpty);
    });

    appTest('a 14 digit number typed with a leading 0 and the same UPC-A '
        'scanned are one product and one row', (tester) async {
      await openTyping(tester);
      await lookUpTyped(tester, '00049000028911');
      await settleMore(tester);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/v2/product/0049000028911.json');
      await scan(tester, '049000028911');
      expect(requests, hasLength(1));
      expect(tiles(), findsNWidgets(2));
      final foods = await foodRows(tester);
      expect(foods, hasLength(1));
      expect(foods.single.barcode, '0049000028911');
    });
  });

  group('layout', () {
    for (final (width, scale) in [(344.0, 1.0), (673.0, 1.0), (344.0, 2.0)]) {
      appTest('the scan button and the scan screen at ${width.toInt()} dp '
          'and text scale $scale have no overflow, 48 dp targets and '
          'spoken labels', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        await openApp(tester, size: Size(width, 800));
        await openFood(tester);
        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Scan a barcode'), findsOneWidget);
        for (final f in [
          scanButton(),
          find.widgetWithIcon(IconButton, Icons.close),
          find.widgetWithIcon(IconButton, Icons.chevron_left),
          find.widgetWithIcon(IconButton, Icons.chevron_right),
          find.byType(PopupMenuButton<String>),
        ]) {
          final s = tester.getSize(f);
          expect(s.height, greaterThanOrEqualTo(48), reason: '$f');
          expect(s.width, greaterThanOrEqualTo(48), reason: '$f');
        }
        final bar = tester.getRect(scanButton());
        expect(bar.left, greaterThanOrEqualTo(0));
        expect(bar.right, lessThanOrEqualTo(width));

        await openScan(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Scan a barcode'), findsOneWidget);
        expect(find.text('Point the camera at the barcode.'), findsOneWidget);
        expect(
          find.text(
            'The number is looked up on Open Food Facts. Nothing else is '
            'sent.',
          ),
          findsOneWidget,
        );
        final typeButton = find.widgetWithText(
          OutlinedButton,
          'Type the number instead',
        );
        final s = tester.getSize(typeButton);
        expect(s.height, greaterThanOrEqualTo(48));
        expect(
          tester
              .getSize(find.widgetWithIcon(IconButton, Icons.close).last)
              .width,
          greaterThanOrEqualTo(48),
        );
        // Words and the close button are spoken.
        expect(find.byTooltip('Close'), findsWidgets);
        expect(
          find.bySemanticsLabel('Point the camera at the barcode.'),
          findsWidgets,
        );

        // The typing view, with the keyboard up, and the refused-permission
        // view, fit too.
        await tester.ensureVisible(typeButton);
        await tester.pump();
        await tester.tap(typeButton);
        await settle(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.text('Look up')).height, greaterThan(0));
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Look up')).height,
          greaterThanOrEqualTo(48),
        );
        tester.view.resetViewInsets();
        await tester.pump();
        semantics.dispose();
      });
    }

    appTest('the refused-permission words fit at 344 dp and text scale 2', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      camera.failWith = CameraProblem.noPermission;
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      await openScan(tester);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Camera access is off'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.widgetWithText(OutlinedButton, 'Type the number instead'),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
    });

    // The test font's letters are as wide as they are tall, wider than any
    // phone font, so a message that fits here fits on a phone.
    appTest('both number errors are shown in full at 344 dp and text scale 2 '
        'with the keyboard up', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openApp(tester, size: const Size(344, 800));
      await openFood(tester);
      await openScan(tester);
      final typeButton = find.text('Type the number instead');
      await tester.ensureVisible(typeButton);
      await tester.pump();
      await tester.tap(typeButton);
      await settle(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Barcode number',
      );
      for (final (typed, message) in [
        ('12ab', S.scanNumberBad),
        ('96385075', S.scanNumberCheck),
      ]) {
        await tester.enterText(field, typed);
        await tester.tap(find.text('Look up'));
        await tester.pump();
        expect(find.text(message), findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(message),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: message);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetViewInsets();
      await tester.pump();
    });
  });
}
