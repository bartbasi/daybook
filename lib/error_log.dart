// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/foundation.dart';

/// Keeps user data out of logs. Error messages can contain user data (drift
/// puts bound values such as a weight in its exception text), so release
/// builds log only the error's type. Debug builds keep Flutter's full output.
void installErrorHandlers({
  bool debug = kDebugMode,
  void Function(String)? log,
}) {
  if (debug) return;
  final out = log ?? (String s) => debugPrint(s);
  FlutterError.onError = (details) =>
      out('Unhandled error: ${details.exception.runtimeType}');
  PlatformDispatcher.instance.onError = (error, stack) {
    out('Unhandled error: ${error.runtimeType}');
    return true;
  };
}
