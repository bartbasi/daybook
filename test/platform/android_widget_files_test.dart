// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the Android files straight from disk, so a careless edit to the
/// widget size or to the manifest protections fails a plain test.
void main() {
  const root = 'android/app/src/main';

  String attr(String xml, String name) {
    final m = RegExp('android:$name="([^"]*)"').firstMatch(xml);
    expect(m, isNotNull, reason: 'weight_widget_info.xml has no android:$name');
    return m!.group(1)!;
  }

  int dp(String value, String name) {
    final m = RegExp(r'^(\d+)dp$').firstMatch(value);
    expect(m, isNotNull, reason: '$name is "$value", expected a dp value');
    return int.parse(m!.group(1)!);
  }

  test('the widget can be resized down to 2 by 1 cells and never polls', () {
    final info = File('$root/res/xml/weight_widget_info.xml')
        .readAsStringSync();

    final modes = attr(info, 'resizeMode').split('|');
    expect(
      modes,
      contains('horizontal'),
      reason: 'resizeMode lacks horizontal',
    );
    expect(modes, contains('vertical'), reason: 'resizeMode lacks vertical');
    expect(
      dp(attr(info, 'minResizeWidth'), 'minResizeWidth'),
      lessThanOrEqualTo(110),
      reason: 'minResizeWidth is above 110dp',
    );
    expect(
      dp(attr(info, 'minResizeHeight'), 'minResizeHeight'),
      lessThanOrEqualTo(40),
      reason: 'minResizeHeight is above 40dp',
    );
    expect(
      attr(info, 'updatePeriodMillis'),
      '0',
      reason: 'updatePeriodMillis is not 0',
    );
  });

  test(
    'the manifest keeps the receiver private and the permissions removed',
    () {
      final manifest = File('$root/AndroidManifest.xml').readAsStringSync();

      final receiver = RegExp(r'<receiver\b[^>]*WeightWidgetProvider[^>]*>')
          .firstMatch(manifest);
      expect(receiver, isNotNull, reason: 'no WeightWidgetProvider receiver');
      expect(
        receiver!.group(0),
        contains('android:exported="false"'),
        reason: 'WeightWidgetProvider is not android:exported="false"',
      );

      for (final p in [
        'WAKE_LOCK',
        'ACCESS_NETWORK_STATE',
        'RECEIVE_BOOT_COMPLETED',
        'FOREGROUND_SERVICE',
      ]) {
        final entry = RegExp(
          '<uses-permission\\b[^>]*android\\.permission\\.$p"[^>]*>',
        ).firstMatch(manifest);
        expect(entry, isNotNull, reason: 'no uses-permission entry for $p');
        expect(
          entry!.group(0),
          contains('tools:node="remove"'),
          reason: '$p is not marked tools:node="remove"',
        );
      }
    },
  );
}
