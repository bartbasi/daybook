// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/data/database.dart';
import 'package:daybook/data/food_reference.dart';
import 'package:daybook/screens/data_check_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'installs the bundled USDA data, finds an egg, shows its numbers',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('daybook_test');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        dir.deleteSync(recursive: true);
      });

      final path = await tester.runAsync(() => installFoodReference(dir: dir));
      await tester.pumpWidget(
        MaterialApp(
          home: DataCheckScreen(db: db, foodsPath: Future.value(path!)),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextField).last,
        'egg whole raw fresh',
      );
      await tester.pump();
      await tester.tap(find.text('Egg, whole, raw, fresh'));
      await tester.pumpAndSettle();

      // SR Legacy 171287, per 100 g.
      expect(find.text('143 kcal'), findsOneWidget);
      expect(find.text('12.6 g'), findsOneWidget); // 12.56, shown to 1 decimal

      // Per large egg (50 g).
      await tester.tap(find.byType(DropdownButton<UsdaPortion?>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('large (50 g)').last);
      await tester.pumpAndSettle();
      expect(find.text('71.5 kcal'), findsOneWidget);
      expect(find.text('6.28 g'), findsOneWidget);

      // Unmount so the screen closes the database before the temp dir goes.
      await tester.pumpWidget(const SizedBox());
    },
  );
}
