// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The home-screen widget on a real build (Android emulator and iOS simulator
// in CI).
//
// What this proves: the widget is in the app (on Android the real plugin
// resolves the provider class by name; on iOS WeightWidget.appex is inside
// Runner.app/PlugIns), the widget data goes through the real plugin into the
// phone's storage (on iOS the App Group's UserDefaults, written and read back
// by the app), and the running app, with its real database, opens the weight
// sheet over Today when the plugin reports the widget link.
//
// What it cannot prove: an integration test cannot place a widget or tap one,
// and it cannot send the system intent or URL that the tap sends. The
// widget's message to Dart is sent by hand here, in the same form the plugin
// uses. On iOS it also cannot prove that the widget, a separate process, can
// read the App Group: that needs a signed build with the App Group in its
// provisioning profile. The receiver entry in the manifest, the look of the
// widget and a real tap are for the phones.

import 'dart:io';

import 'package:daybook/main.dart' as app;
import 'package:daybook/platform/weight_widget.dart';
import 'package:daybook/screens/weight/weight_sheet.dart';
import 'package:daybook/util/units.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final android = defaultTargetPlatform == TargetPlatform.android;

  testWidgets('the widget is in the app and its data is stored', (
    tester,
  ) async {
    if (android) {
      // The plugin looks the class up by name and fails if it is missing.
      final asked = await HomeWidget.updateWidget(
        qualifiedAndroidName: androidWidgetProvider,
      );
      expect(asked, isTrue);
    } else {
      // The app's executable sits directly in Runner.app.
      final bundle = File(Platform.resolvedExecutable).parent.path;
      expect(
        File('$bundle/PlugIns/WeightWidget.appex/Info.plist').existsSync(),
        isTrue,
        reason: 'WeightWidget.appex in $bundle/PlugIns',
      );
    }

    // On iOS this also sets the App Group, which the reads below need.
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
    // app is running. The iOS widget's link has the plugin's query item.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'home_widget/updates',
      const StandardMethodCodec().encodeSuccessEnvelope(
        android ? weightLaunchLink : '$weightLaunchLink?homeWidget',
      ),
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
    // The message follows the sheet by a frame or more on a slow simulator,
    // so wait for it instead of looking once.
    final saved = find.textContaining('Weight saved: 181.8 lb');
    waited = 0;
    while (saved.evaluate().isEmpty && waited < 100) {
      await tester.pump(const Duration(milliseconds: 100));
      waited++;
    }
    expect(find.byType(WeightSheet), findsNothing);
    expect(saved, findsOneWidget);

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
