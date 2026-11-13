// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Starts the real app on a device or simulator: the real database, the real
// bundled food data, the real plugins. CI runs it on an Android emulator and
// an iOS simulator.

import 'dart:io';

import 'package:daybook/data/food_reference.dart';
import 'package:daybook/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app starts and installs the food data', (tester) async {
    app.main();

    // Not pumpAndSettle: it could wait forever on an animation.
    var waited = 0;
    while (find.byType(Scaffold).evaluate().isEmpty && waited < 300) {
      await tester.pump(const Duration(milliseconds: 200));
      waited++;
    }
    expect(find.byType(Scaffold), findsWidgets);

    // The first run unpacks the food data; its version file is written last.
    final dir = await getApplicationSupportDirectory();
    final version = File(p.join(dir.path, 'usda_version.txt'));
    waited = 0;
    while (!version.existsSync() && waited < 300) {
      await tester.pump(const Duration(milliseconds: 200));
      waited++;
    }
    expect(version.existsSync(), isTrue);

    final path = await installFoodReference();
    final foods = FoodReference.open(path);
    final egg = foods.food(2707153);
    foods.close();
    expect(egg, isNotNull);
  });
}
