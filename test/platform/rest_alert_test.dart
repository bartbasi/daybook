// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/platform/rest_alert.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

// The wrapper around the notification plugin (task 4.5): nothing is called
// until it is used, the plugin is set up without asking for anything, one
// notification with a fixed id says "Rest done" at the right UTC time, and
// the Android files ask for no exact alarm.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  Object? permissionAnswer;

  setUp(() {
    calls.clear();
    permissionAnswer = true;
    // In a test the plugin has not registered itself.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'requestNotificationsPermission') {
            return permissionAnswer;
          }
          if (call.method == 'initialize') return true;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<String> names() => [for (final c in calls) c.method];

  test('making the wrapper calls nothing', () {
    const LocalRestAlert();
    expect(calls, isEmpty);
  });

  test('asking for permission sets the plugin up and asks once, and says '
      'what the user answered', () async {
    expect(await const LocalRestAlert().requestPermission(), isTrue);
    // The plugin is set up once per run, so only the first test sees it.
    expect(names().last, 'requestNotificationsPermission');
    expect(names().where((n) => n == 'requestNotificationsPermission'), hasLength(1));
    expect(
      names().where((n) => n != 'initialize' && !n.startsWith('request')),
      isEmpty,
    );

    permissionAnswer = false;
    expect(await const LocalRestAlert().requestPermission(), isFalse);
    permissionAnswer = null;
    expect(await const LocalRestAlert().requestPermission(), isFalse);
  });

  test('schedule makes one notification, "Rest done", with nothing else in '
      'it, at that instant in UTC, with no exact alarm', () async {
    final end = DateTime.now().toUtc().add(const Duration(seconds: 90));
    await const LocalRestAlert().schedule(end.millisecondsSinceEpoch);

    final call = calls.singleWhere((c) => c.method == 'zonedSchedule');
    final a = call.arguments as Map;
    expect(a['id'], restAlertId);
    expect(a['title'], 'Rest done');
    expect(a['body'], isNull);
    expect(a['payload'], '');
    expect(a['timeZoneName'], 'Etc/UTC', reason: 'the UTC of the timezone package');
    expect(
      DateTime.parse(a['scheduledDateTimeISO8601'] as String)
          .millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
    final s = a['platformSpecifics'] as Map;
    expect(s['scheduleMode'], 'inexactAllowWhileIdle');
    expect(s['channelId'], restAlertChannelId);
    expect(s['channelName'], 'Rest timer');
    expect(a.containsKey('matchDateTimeComponents'), isFalse);
  });

  test('every schedule uses the same id, so there is never more than one', () {
    final later = DateTime.now().add(const Duration(minutes: 3));
    final ids = <Object?>{};
    return () async {
      await const LocalRestAlert().schedule(later.millisecondsSinceEpoch);
      await const LocalRestAlert().schedule(
        later.add(const Duration(seconds: 15)).millisecondsSinceEpoch,
      );
      for (final c in calls.where((c) => c.method == 'zonedSchedule')) {
        ids.add((c.arguments as Map)['id']);
      }
      expect(ids, {restAlertId});
    }();
  });

  test('a time that has passed schedules nothing, and cancel names the same '
      'id', () async {
    await const LocalRestAlert().schedule(
      DateTime.now().subtract(const Duration(seconds: 5)).millisecondsSinceEpoch,
    );
    expect(names().where((n) => n == 'zonedSchedule'), isEmpty);

    calls.clear();
    await const LocalRestAlert().cancel();
    final c = calls.singleWhere((c) => c.method == 'cancel');
    expect((c.arguments as Map)['id'], restAlertId);
  });

  test('a plugin that fails never throws out of the wrapper', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'x', message: 'user 175'),
        );
    final end = DateTime.now().add(const Duration(minutes: 2));
    await const LocalRestAlert().schedule(end.millisecondsSinceEpoch);
    await const LocalRestAlert().cancel();
    expect(await const LocalRestAlert().requestPermission(), isFalse);
  });

  group('the Android files', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    test('no exact alarm permission, no boot receiver and no vibrate '
        'permission is declared', () {
      for (final name in [
        'SCHEDULE_EXACT_ALARM',
        'USE_EXACT_ALARM',
        'USE_FULL_SCREEN_INTENT',
      ]) {
        expect(manifest, isNot(contains(name)), reason: name);
      }
      // The plugin's own VIBRATE and the boot receiver's permission are
      // removed, not added.
      for (final name in ['VIBRATE', 'RECEIVE_BOOT_COMPLETED']) {
        expect(
          manifest,
          contains('android.permission.$name" tools:node="remove"'),
          reason: name,
        );
      }
      expect(manifest, isNot(contains('ScheduledNotificationBootReceiver')));
    });

    test('the receiver that shows the scheduled notification is declared, '
        'and POST_NOTIFICATIONS is the one permission added', () {
      expect(
        manifest,
        contains('com.dexterous.flutterlocalnotifications.'
            'ScheduledNotificationReceiver'),
      );
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });

    test('the build turns on core library desugaring, which the plugin needs',
        () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(gradle, contains('coreLibraryDesugaring('));
    });
  });
}
