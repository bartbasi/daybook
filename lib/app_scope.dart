// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/widgets.dart';

import 'clock.dart';
import 'data/database.dart';

/// The shared objects, read with AppScope.of(context).
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.db,
    required this.clock,
    required this.foodsPath,
    required super.child,
  });

  final AppDatabase db;
  final Clock clock;

  /// Path of the installed USDA database, see installFoodReference.
  final Future<String> foodsPath;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope old) =>
      db != old.db || clock != old.clock || foodsPath != old.foodsPath;
}
