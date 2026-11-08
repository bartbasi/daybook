// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/error_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // drift's SqliteException text includes bound values, for example a weight.
  final error = StateError('insert failed, parameters: 2026-01-01, 81.8 kg');

  test('release builds log only the error type, never its message', () {
    final lines = <String>[];
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
    });

    installErrorHandlers(debug: false, log: lines.add);
    FlutterError.onError!(FlutterErrorDetails(exception: error));
    final handled = PlatformDispatcher.instance.onError!(
      error,
      StackTrace.empty,
    );

    expect(handled, isTrue);
    expect(lines, hasLength(2));
    for (final line in lines) {
      expect(line, contains('StateError'));
      expect(line, isNot(contains('81.8')));
      expect(line, isNot(contains('2026-01-01')));
    }
  });
}
