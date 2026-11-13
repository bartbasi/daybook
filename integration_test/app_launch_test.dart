// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Starts the real app on a device or simulator: the real database, the real
// bundled food data, the real plugins. CI runs it on an Android emulator and
// an iOS simulator.

import 'package:daybook/main.dart' as app;
import 'package:daybook/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the app starts and shows its first screen', (tester) async {
    app.main();

    // The first run unpacks the food data, so give it time. Not pumpAndSettle:
    // a progress animation would keep it from settling.
    var waited = 0;
    while (find.byType(Scaffold).evaluate().isEmpty && waited < 150) {
      await tester.pump(const Duration(milliseconds: 200));
      waited++;
    }
    expect(find.byType(Scaffold), findsOneWidget);

    // The food data has been installed once the loading message is gone.
    waited = 0;
    while (find.text(S.loadingFoods).evaluate().isNotEmpty && waited < 300) {
      await tester.pump(const Duration(milliseconds: 200));
      waited++;
    }
    expect(find.text(S.loadingFoods), findsNothing);
  });
}
