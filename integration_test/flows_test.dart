// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The weight flow (speed target 3) and the food flow (speed target 1) on a
// real build: the real app, the real database file on the device, the real
// food data and the real clock. CI runs it on an Android emulator and an iOS
// simulator. Each flow is also a widget test (test/speed/weight_speed_test.dart
// and test/speed/food_speed_test.dart) that runs the same steps.
//
// Both flows run from this one file, with one app.main(). The iOS job retries
// only when the test never connected to the app, so a hang in a later file
// would never be retried, and each extra launch adds exposure and 2 to 4
// minutes. app_launch_test.dart and widget_launch_test.dart stay apart because
// they test the first run and the launch link.
//
// A test that ends clears the widget tree, and a second app.main() would open
// the database a second time. So the flows are two groups of steps in one
// test, each its own function. Each starts from Home, reads only its own
// rows, deletes them at the end, and does not rely on the other, so the order
// does not matter.

import 'package:daybook/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/food_flow.dart';
import 'flows/weight_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the food flow and the weight flow, each from Home, in one run '
      'of the app', (tester) async {
    app.main();
    await waitFor(
      tester,
      () => find.byType(NavigationBar).evaluate().isNotEmpty,
      'the app to start',
      tries: 480, // about 60 seconds, as in app_launch_test.dart
    );

    await runFoodFlow(tester);
    await runWeightFlow(tester);
  });
}
