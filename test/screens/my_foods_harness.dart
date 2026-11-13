// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/app.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/parser/parse_worker.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'food_entry_screen_test.dart' show FakeLink, Gate, nowFixed, settle;

export 'food_entry_screen_test.dart' show FakeLink, Gate, nowFixed, settle;

// What the My foods and recipes tests share (task 2.12): the real USDA food
// data behind an inline parser worker, an in memory database with a Gate, and
// the app opened at a size. Call [register] once in main.

class MyFoodsHarness {
  late Directory tmp;
  late sqlite.Database usda;
  late SqliteUsdaFoods loader;
  late Parser parser;
  late AppDatabase db;
  late Gate gate;
  late List<FakeLink> links;
  var useLink = false;

  void register() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    setUpAll(() {
      tmp = Directory.systemTemp.createTempSync('daybook_my_foods');
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
    setUp(() {
      gate = Gate();
      db = AppDatabase(NativeDatabase.memory().interceptWith(gate));
      links = [];
      useLink = false;
    });
  }

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

  Future<T> real<T>(WidgetTester tester, Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> goToList(WidgetTester tester) async {
    await tap(tester, find.widgetWithText(NavigationDestination, 'More'));
    await tap(tester, find.text('My foods and recipes'));
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );

  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), text);
    await tester.pump();
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
}
