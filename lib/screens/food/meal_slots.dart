// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart' show OrderingTerm;

import '../../data/database.dart';
import '../../data/food_data.dart' show liveQuery;

/// The meal slots in order, archived ones included, updated after every write
/// to them. The data layer has no query for this yet (task 8.1 adds slot
/// editing); until then the food screen and Home read the table here, in one
/// place, so it is easy to swap for the data layer's own stream.
Stream<List<MealSlot>> watchMealSlots(AppDatabase db) => liveQuery(
  db,
  [db.mealSlots],
  () => (db.select(
    db.mealSlots,
  )..orderBy([(s) => OrderingTerm.asc(s.position)])).get(),
);
