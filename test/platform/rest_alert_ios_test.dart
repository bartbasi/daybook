// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/platform/rest_alert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

// The iOS side of the wrapper (task 4.5). Its own file, because the wrapper
// keeps its set-up in a static and the Android tests set it up first.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  Object? checkAnswer;

  setUp(() {
    calls.clear();
    checkAnswer = {'isEnabled': true};
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'checkPermissions') return checkAnswer;
          if (call.method == 'initialize') return false;
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('on iOS, setting the plugin up asks for no permission', () async {
    await const LocalRestAlert().cancel();
    final init = calls.firstWhere((c) => c.method == 'initialize');
    final a = init.arguments as Map;
    for (final k in [
      'requestAlertPermission',
      'requestSoundPermission',
      'requestBadgePermission',
      'requestProvisionalPermission',
      'requestCriticalPermission',
      'requestProvidesAppNotificationSettings',
    ]) {
      expect(a[k], isFalse, reason: k);
    }
    expect(calls.where((c) => c.method == 'requestPermissions'), isEmpty);
  });

  test('on iOS, the quiet check sends only checkPermissions, never a request, '
      'and no answer or an error is "not allowed"', () async {
    expect(await const LocalRestAlert().isAllowed(), isTrue);
    expect(calls.where((c) => c.method != 'initialize').map((c) => c.method), [
      'checkPermissions',
    ]);
    checkAnswer = {'isEnabled': false};
    expect(await const LocalRestAlert().isAllowed(), isFalse);
    checkAnswer = null;
    expect(await const LocalRestAlert().isAllowed(), isFalse);
    expect(calls.where((c) => c.method == 'requestPermissions'), isEmpty);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'x'),
        );
    expect(await const LocalRestAlert().isAllowed(), isFalse);
  });

  test('on iOS, "Rest done" is not shown while Daybook is in front', () async {
    final end = DateTime.now().add(const Duration(minutes: 2));
    await const LocalRestAlert().schedule(end.millisecondsSinceEpoch);
    final call = calls.singleWhere((c) => c.method == 'zonedSchedule');
    final s = (call.arguments as Map)['platformSpecifics'] as Map;
    for (final k in [
      'presentAlert',
      'presentBanner',
      'presentList',
      'presentSound',
    ]) {
      expect(s[k], isFalse, reason: k);
    }
  });
}
