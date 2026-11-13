// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The home-screen widget on a real build (Android emulator in CI).
//
// What this proves: the widget provider class is in the app (the real plugin
// resolves it by name), the widget data goes through the real plugin into
// the phone's storage, and the running app, with its real database, opens the
// weight sheet over Today when the plugin reports the widget link.
//
// What it cannot prove: an integration test cannot place a widget or tap one,
// and it cannot send the system intent that the tap sends. The widget's
// message to Dart is sent by hand here, in the same form the plugin uses. The
// receiver entry in the manifest, the look of the widget and a real tap are
// for the phone.

import 'package:daybook/main.dart' as app;
import 'package:daybook/platform/weight_widget.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the widget provider is in the app and its data is stored', (
    tester,
  ) async {
    // The plugin looks the class up by name and fails if it is missing.
    final asked = await HomeWidget.updateWidget(
      qualifiedAndroidName: androidWidgetProvider,
    );
    expect(asked, isTrue);

    await writeWeightWidget(const [], UnitSystem.imperial, '2026-11-12');
    expect(
      await HomeWidget.getWidgetData<String>(widgetKeyWeight),
      'No weight yet',
    );
    expect(await HomeWidget.getWidgetData<String>(widgetKeyTap), 'Tap to log');
  });

  testWidgets('the widget link opens the weight sheet and a save updates the '
      'widget data', (tester) async {
    app.main();
    var waited = 0;
    while (find.byType(NavigationBar).evaluate().isEmpty && waited < 300) {
      await tester.pump(const Duration(milliseconds: 200));
      waited++;
    }
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(WeightSheet), findsNothing);

    // The same message the plugin sends when the widget is tapped while the
    // app is running.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'home_widget/updates',
      const StandardMethodCodec().encodeSuccessEnvelope(weightLaunchLink),
      (_) {},
    );
    waited = 0;
    while (find.byType(WeightSheet).evaluate().isEmpty && waited < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      waited++;
    }
    expect(find.byType(WeightSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField), '181.8');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    waited = 0;
    while (find.byType(WeightSheet).evaluate().isNotEmpty && waited < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      waited++;
    }
    expect(find.textContaining('Weight saved: 181.8 lb'), findsOneWidget);

    // The widget data now holds the saved weight, in the phone's storage.
    String? stored;
    waited = 0;
    while (stored != '181.8 lb' && waited < 50) {
      await tester.pump(const Duration(milliseconds: 100));
      stored = await HomeWidget.getWidgetData<String>(widgetKeyWeight);
      waited++;
    }
    expect(stored, '181.8 lb');
  });
}
