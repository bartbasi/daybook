// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/food_reference.dart';
import 'error_log.dart';
import 'screens/data_check_screen.dart';
import 'strings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  runApp(DaybookApp(db: AppDatabase.open(), foodsPath: installFoodReference()));
}

class DaybookApp extends StatelessWidget {
  const DaybookApp({super.key, required this.db, required this.foodsPath});

  final AppDatabase db;
  final Future<String> foodsPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.title,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: DataCheckScreen(db: db, foodsPath: foodsPath),
    );
  }
}
