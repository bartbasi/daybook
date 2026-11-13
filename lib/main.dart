// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import 'app.dart';
import 'clock.dart';
import 'data/database.dart';
import 'data/food_reference.dart';
import 'error_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  runApp(
    DaybookApp(
      db: AppDatabase.open(),
      clock: systemNow,
      foodsPath: installFoodReference(),
    ),
  );
}
