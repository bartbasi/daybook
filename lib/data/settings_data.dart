// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart';

import '../util/units.dart';
import 'database.dart';

extension SettingsData on AppDatabase {
  UnitSystem _unitsOf(Setting? row) =>
      row?.value == 'metric' ? UnitSystem.metric : UnitSystem.imperial;

  SimpleSelectStatement<$SettingsTable, Setting> get _unitsRow =>
      select(settings)..where((s) => s.key.equals('units'));

  /// The units setting. Imperial if the row is missing.
  Future<UnitSystem> getUnits() async =>
      _unitsOf(await _unitsRow.getSingleOrNull());

  /// Emits the current units, then again after every change.
  Stream<UnitSystem> watchUnits() =>
      _unitsRow.watchSingleOrNull().map(_unitsOf).distinct();

  Future<void> setUnits(UnitSystem units) =>
      into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(key: 'units', value: units.name),
      );

  /// Whether the user asked to be alerted when a rest ends. Off if the row is
  /// missing.
  Future<bool> getRestAlert() async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals('rest_alert'))).getSingleOrNull();
    return row?.value == 'on';
  }

  Future<void> setRestAlert(bool on) => into(settings).insertOnConflictUpdate(
    SettingsCompanion.insert(key: 'rest_alert', value: on ? 'on' : 'off'),
  );
}
