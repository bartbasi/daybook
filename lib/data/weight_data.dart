// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart';

import '../clock.dart';
import '../math/weight_trend.dart';
import '../util/units.dart';
import 'database.dart';

/// A weight outside 50 to 1,000 lb (23 to 450 kg), refused before any write.
class WeightOutOfRange implements Exception {
  const WeightOutOfRange(this.value, this.units);

  final double value;
  final UnitSystem units;

  @override
  String toString() => 'WeightOutOfRange';
}

/// Weights are typed in the display unit and stored in kilograms. Every write
/// returns the row read back from the database.
///
/// [now] is the instant of the write (created and updated times). [at] is the
/// instant and offset the weigh-in counts for; it defaults to [now].
extension WeightData on AppDatabase {
  /// The value rounded to one decimal, or throws [WeightOutOfRange].
  double _checked(double value, UnitSystem units) {
    if (!value.isFinite) throw WeightOutOfRange(value, units);
    final v = roundToTenth(value);
    if (!weightInRange(v, units)) throw WeightOutOfRange(value, units);
    return v;
  }

  Future<WeightEntry> _read(int id) =>
      (select(weightEntries)..where((w) => w.id.equals(id))).getSingle();

  Future<WeightEntry> saveWeight(
    double value,
    UnitSystem units,
    Now now, {
    Now? at,
  }) async {
    final kg = weightToKg(_checked(value, units), units);
    final when = at ?? now;
    final id = await into(weightEntries).insert(
      WeightEntriesCompanion.insert(
        localDate: when.localDate,
        measuredAtMs: when.utcMs,
        tzOffsetMinutes: when.offsetMinutes,
        weightKg: kg,
        createdAtMs: now.utcMs,
        updatedAtMs: now.utcMs,
      ),
    );
    return _read(id);
  }

  /// Changes the weight and, when [at] is given, the date and time. Without
  /// [at] the day stays as it was, whatever the phone's time zone is now.
  Future<WeightEntry> editWeight(
    int id,
    double value,
    UnitSystem units,
    Now now, {
    Now? at,
  }) async {
    final kg = weightToKg(_checked(value, units), units);
    final changed =
        await (update(
          weightEntries,
        )..where((w) => w.id.equals(id) & w.deletedAtMs.isNull())).write(
          WeightEntriesCompanion(
            weightKg: Value(kg),
            updatedAtMs: Value(now.utcMs),
            localDate: at == null ? const Value.absent() : Value(at.localDate),
            measuredAtMs: at == null ? const Value.absent() : Value(at.utcMs),
            tzOffsetMinutes: at == null
                ? const Value.absent()
                : Value(at.offsetMinutes),
          ),
        );
    if (changed == 0) throw StateError('No such weigh-in');
    return _read(id);
  }

  /// Marks the row deleted. The row stays so a health sync cannot bring it back.
  Future<WeightEntry> deleteWeight(int id, Now now) =>
      _setDeleted(id, now.utcMs, now);

  /// Clears the deleted mark.
  Future<WeightEntry> undoDeleteWeight(int id, Now now) =>
      _setDeleted(id, null, now);

  Future<WeightEntry> _setDeleted(int id, int? deletedAtMs, Now now) async {
    final changed =
        await (update(weightEntries)..where((w) => w.id.equals(id))).write(
          WeightEntriesCompanion(
            deletedAtMs: Value(deletedAtMs),
            updatedAtMs: Value(now.utcMs),
          ),
        );
    if (changed == 0) throw StateError('No such weigh-in');
    return _read(id);
  }

  SimpleSelectStatement<$WeightEntriesTable, WeightEntry>
  get _liveNewestFirst =>
      select(weightEntries)
        ..where((w) => w.deletedAtMs.isNull())
        ..orderBy([
          (w) => OrderingTerm.desc(w.measuredAtMs),
          (w) => OrderingTerm.desc(w.id),
        ]);

  /// The newest weigh-in that is not deleted, or null.
  Future<WeightEntry?> latestWeight() =>
      (_liveNewestFirst..limit(1)).getSingleOrNull();

  /// Weigh-ins that are not deleted, newest first, updated after every write.
  Stream<List<WeightEntry>> watchWeights() => _liveNewestFirst.watch();

  /// The trend over all weigh-ins that are not deleted, oldest day first.
  Stream<List<TrendPoint>> watchTrend() => watchWeights().map(
    (rows) =>
        weightTrend(rows.map((r) => (localDate: r.localDate, kg: r.weightKg))),
  );
}
