// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../strings.dart';

/// The one notification id. A new alert replaces the old one, so there is
/// never more than one.
const restAlertId = 1;

/// The one Android notification channel.
const restAlertChannelId = 'rest_timer';

/// The "Rest done" notification for the end of a rest (task 4.5). It is the
/// only notification the app makes and it says nothing but "Rest done".
///
/// Nothing here may ask for anything at app start: the plugin is set up only
/// when one of these is first used, and then without any permission request.
/// The permission is asked for only by [requestPermission], from the row the
/// user taps.
abstract class RestAlert {
  const RestAlert();

  /// Asks the phone for permission to show notifications. True if granted.
  Future<bool> requestPermission();

  /// Shows "Rest done" at [endUtcMs] (milliseconds since the epoch, UTC),
  /// replacing the one that is waiting. The phone may be a few seconds late.
  Future<void> schedule(int endUtcMs);

  /// Removes the waiting notification, and one that has already shown.
  Future<void> cancel();
}

/// The real thing, with flutter_local_notifications. A phone or a test with
/// no plugin must never get in the way of logging a set, so every error is
/// swallowed. Nothing is logged.
class LocalRestAlert extends RestAlert {
  const LocalRestAlert();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _ready;

  /// For a test: forget that the plugin was set up.
  @visibleForTesting
  static void resetForTest() => _ready = null;

  /// Sets the plugin up once. On iOS every "request permission" flag is off,
  /// so setting up asks for nothing.
  static Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      )
      .then<void>((_) {})
      .catchError((Object _) {
        // Try again next time.
        _ready = null;
      });

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> schedule(int endUtcMs) async {
    try {
      await _init();
      // Both phones drop the milliseconds, so round up: the alert must never
      // come before the end in the app.
      final end = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC,
        ((endUtcMs + 999) ~/ 1000) * 1000,
      );
      // Nothing to wait for when the time has come.
      if (!end.isAfter(DateTime.now())) {
        await _plugin.cancel(id: restAlertId);
        return;
      }
      await _plugin.zonedSchedule(
        id: restAlertId,
        title: S.restDone,
        scheduledDate: end,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            restAlertChannelId,
            S.restAlertChannel,
          ),
          // Nothing is shown while Daybook is in front: the buzz does that.
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentBanner: false,
            presentList: false,
            presentSound: false,
          ),
        ),
        // Inexact: no exact alarm permission, so it may be a few seconds late.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    try {
      await _init();
      await _plugin.cancel(id: restAlertId);
    } catch (_) {}
  }
}
