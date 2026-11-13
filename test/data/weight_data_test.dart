// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/settings_data.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const imp = UnitSystem.imperial;
const met = UnitSystem.metric;

/// A wall-clock time on a local date at a local offset in hours.
Now at(String date, int h, int m, double offsetHours, [int s = 0]) {
  final n = Now.fromLocal(date, h * 60 + m, (offsetHours * 60).round());
  return Now(utcMs: n.utcMs + s * 1000, offsetMinutes: n.offsetMinutes);
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('entry', () {
    test('a save returns the row read back, with date and offset from the clock',
        () async {
      final now = at('2026-11-12', 7, 2, -6);
      final row = await db.saveWeight(181.8, imp, now);
      expect(row.id, greaterThan(0));
      expect(row.localDate, '2026-11-12');
      expect(row.tzOffsetMinutes, -360);
      expect(row.measuredAtMs, now.utcMs);
      expect(row.createdAtMs, now.utcMs);
      expect(row.updatedAtMs, now.utcMs);
      expect(row.weightKg, closeTo(181.8 * 0.45359237, 1e-12));
      expect(row.source, 'manual');
      expect(row.sourceId, isNull);
      expect(row.deletedAtMs, isNull);
      final stored = await db.select(db.weightEntries).get();
      expect(stored.single, row);
    });

    test('metric values are stored as typed', () async {
      final row = await db.saveWeight(82.5, met, at('2026-11-12', 7, 0, 0));
      expect(row.weightKg, 82.5);
    });

    test('a weight typed with extra decimals is stored to one decimal', () async {
      final row = await db.saveWeight(181.84, imp, at('2026-11-12', 7, 0, 0));
      expect(formatWeight(row.weightKg, imp), '181.8');
      expect(row.weightKg, weightToKg(181.8, imp));
    });

    test('a weigh-in for another day keeps created time at now', () async {
      final now = at('2026-11-12', 7, 2, -6);
      final then = at('2026-11-10', 6, 55, -6);
      final row = await db.saveWeight(182.4, imp, now, at: then);
      expect(row.localDate, '2026-11-10');
      expect(row.measuredAtMs, then.utcMs);
      expect(row.createdAtMs, now.utcMs);
    });

    test('latestWeight is null with no rows', () async {
      expect(await db.latestWeight(), isNull);
    });

    test('latestWeight is the newest by time, not by insert order', () async {
      final now = at('2026-11-12', 7, 0, 0);
      await db.saveWeight(180, imp, now);
      await db.saveWeight(
        190,
        imp,
        now,
        at: at('2026-11-01', 7, 0, 0),
      );
      expect(formatWeight((await db.latestWeight())!.weightKg, imp), '180.0');
    });
  });

  group('edit', () {
    test('weight, date and time change; updated moves, created does not',
        () async {
      final first = at('2026-11-11', 6, 55, -6);
      final row = await db.saveWeight(182.4, imp, first);
      final later = at('2026-11-12', 9, 0, -6);
      final newTime = at('2026-11-10', 8, 15, -6);
      final edited = await db.editWeight(row.id, 181.2, imp, later, at: newTime);
      expect(edited.id, row.id);
      expect(formatWeight(edited.weightKg, imp), '181.2');
      expect(edited.localDate, '2026-11-10');
      expect(edited.measuredAtMs, newTime.utcMs);
      expect(edited.tzOffsetMinutes, -360);
      expect(edited.updatedAtMs, later.utcMs);
      expect(edited.createdAtMs, first.utcMs);
      expect(await db.select(db.weightEntries).get(), hasLength(1));
    });

    test('editing only the weight keeps the day, even in a new time zone',
        () async {
      final row = await db.saveWeight(182.4, imp, at('2026-11-12', 7, 0, 9));
      final edited = await db.editWeight(
        row.id,
        181.0,
        imp,
        at('2026-11-12', 12, 0, -6),
      );
      expect(edited.localDate, '2026-11-12');
      expect(edited.tzOffsetMinutes, 540);
      expect(edited.measuredAtMs, row.measuredAtMs);
    });

    test('an edit can be entered in the other unit', () async {
      final row = await db.saveWeight(182.4, imp, at('2026-11-12', 7, 0, 0));
      final edited = await db.editWeight(
        row.id,
        80.0,
        met,
        at('2026-11-12', 8, 0, 0),
      );
      expect(edited.weightKg, 80.0);
    });

    test('an out of range edit is refused and changes nothing', () async {
      final row = await db.saveWeight(182.4, imp, at('2026-11-12', 7, 0, 0));
      await expectLater(
        db.editWeight(row.id, 20, imp, at('2026-11-12', 8, 0, 0)),
        throwsA(isA<WeightOutOfRange>()),
      );
      expect((await db.latestWeight())!, row);
    });

    test('editing a deleted or missing row fails', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final row = await db.saveWeight(182.4, imp, now);
      await db.deleteWeight(row.id, now);
      await expectLater(db.editWeight(row.id, 180, imp, now), throwsStateError);
      await expectLater(db.editWeight(999, 180, imp, now), throwsStateError);
    });
  });

  group('delete and undo', () {
    test('delete sets deleted_at_ms and keeps the row', () async {
      final saved = at('2026-11-12', 7, 0, 0);
      final row = await db.saveWeight(182.4, imp, saved);
      final when = at('2026-11-12', 7, 5, 0);
      final gone = await db.deleteWeight(row.id, when);
      expect(gone.deletedAtMs, when.utcMs);
      expect(gone.updatedAtMs, when.utcMs);
      expect(await db.select(db.weightEntries).get(), hasLength(1));
    });

    test('list, latest and trend skip deleted rows', () async {
      final now = at('2026-11-12', 7, 0, 0);
      await db.saveWeight(180, imp, now, at: at('2026-11-10', 7, 0, 0));
      final mid = await db.saveWeight(
        190,
        imp,
        now,
        at: at('2026-11-11', 7, 0, 0),
      );
      await db.saveWeight(182, imp, now);
      await db.deleteWeight(mid.id, now);

      final list = await db.watchWeights().first;
      expect(list.map((r) => formatWeight(r.weightKg, imp)), ['182.0', '180.0']);
      expect(formatWeight((await db.latestWeight())!.weightKg, imp), '182.0');
      final trend = await db.watchTrend().first;
      expect(trend.map((p) => p.localDate), ['2026-11-10', '2026-11-12']);
      expect(
        trend.last.trendKg,
        closeTo(weightToKg(180, imp) + 0.1 * (weightToKg(182, imp) - weightToKg(180, imp)), 1e-9),
      );

      await db.deleteWeight((await db.latestWeight())!.id, now);
      expect(formatWeight((await db.latestWeight())!.weightKg, imp), '180.0');
    });

    test('deleting everything leaves no latest weight and no trend', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final row = await db.saveWeight(182, imp, now);
      await db.deleteWeight(row.id, now);
      expect(await db.latestWeight(), isNull);
      expect(await db.watchWeights().first, isEmpty);
      expect(await db.watchTrend().first, isEmpty);
    });

    test('undo clears the mark and the row is back everywhere', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final row = await db.saveWeight(182.4, imp, now);
      await db.deleteWeight(row.id, now);
      final back = await db.undoDeleteWeight(row.id, at('2026-11-12', 7, 1, 0));
      expect(back.deletedAtMs, isNull);
      expect(back.weightKg, row.weightKg);
      expect(back.createdAtMs, row.createdAtMs);
      expect((await db.latestWeight())!.id, row.id);
      expect(await db.watchWeights().first, hasLength(1));
      expect(await db.watchTrend().first, hasLength(1));
    });

    test('deleting a missing row fails', () async {
      await expectLater(
        db.deleteWeight(999, at('2026-11-12', 7, 0, 0)),
        throwsStateError,
      );
    });

  });

  group('lists', () {
    test('watchWeights is newest first and updates after each write', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final seen = <List<int>>[];
      final sub = db.watchWeights().listen(
        (rows) => seen.add([for (final r in rows) r.id]),
      );
      await pumpEventQueue();
      final a = await db.saveWeight(181, imp, now, at: at('2026-11-10', 7, 0, 0));
      await pumpEventQueue();
      final b = await db.saveWeight(182, imp, now, at: at('2026-11-11', 7, 0, 0));
      await pumpEventQueue();
      await db.deleteWeight(b.id, now);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [
        <int>[],
        [a.id],
        [b.id, a.id],
        [a.id],
      ]);
    });

    test('after travel the latest is the newest day, not the newest instant',
        () async {
      final now = at('2026-11-12', 7, 0, 9);
      final tokyo = await db.saveWeight(181, imp, now); // Nov 12 07:00 +9
      final chicago = await db.saveWeight(
        182,
        imp,
        now,
        at: at('2026-11-11', 20, 0, -6), // a later instant, an earlier day
      );
      expect(chicago.measuredAtMs, greaterThan(tokyo.measuredAtMs));
      expect((await db.latestWeight())!.id, tokyo.id);
      expect((await db.watchWeights().first).map((r) => r.id), [
        tokyo.id,
        chicago.id,
      ]);
      expect((await db.watchTrend().first).last.localDate, '2026-11-12');
    });

    test('two weigh-ins at the same instant keep a stable order', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final a = await db.saveWeight(181, imp, now);
      final b = await db.saveWeight(182, imp, now);
      expect((await db.watchWeights().first).map((r) => r.id), [b.id, a.id]);
    });
  });

  group('units', () {
    test('every 0.1 lb from 50.0 to 1,000.0 survives store and display',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      for (var i = 500; i <= 10000; i++) {
        final typed = (i / 10).toStringAsFixed(1);
        final row = await db.saveWeight(parseWeight(typed)!, imp, now);
        expect(formatWeight(row.weightKg, imp), typed);
      }
    });

    test('every 0.1 kg from 22.7 to 453.6 survives store and display',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      for (var i = 227; i <= 4536; i++) {
        final typed = (i / 10).toStringAsFixed(1);
        final row = await db.saveWeight(parseWeight(typed)!, met, now);
        expect(formatWeight(row.weightKg, met), typed);
      }
    });

    test('switching the setting changes display only, never stored values',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      await db.saveWeight(181.8, imp, now);
      final before = await db.select(db.weightEntries).get();
      await db.setUnits(met);
      expect(await db.getUnits(), met);
      await db.setUnits(imp);
      expect(await db.getUnits(), imp);
      expect(await db.select(db.weightEntries).get(), before);
      expect(formatWeight(before.single.weightKg, imp), '181.8');
    });

    test('a time-only edit made after a unit switch keeps the stored value',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      final other = at('2026-11-12', 8, 0, 0);
      final row = await db.saveWeight(180.4, imp, now);
      await db.setUnits(met);
      final shown = parseWeight(formatWeight(row.weightKg, met))!; // 81.8
      final edited = await db.editWeight(row.id, shown, met, now, at: other);
      expect(edited.weightKg, row.weightKg);
      expect(edited.measuredAtMs, other.utcMs);
      expect(formatWeight(edited.weightKg, imp), '180.4');
    });

    test('a time-only edit keeps an imported value with more precision',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      final id = await db.into(db.weightEntries).insert(
        WeightEntriesCompanion.insert(
          localDate: '2026-11-12',
          measuredAtMs: now.utcMs,
          tzOffsetMinutes: 0,
          weightKg: 81.83,
          source: const Value('health_connect'),
          sourceId: const Value('abc'),
          createdAtMs: now.utcMs,
          updatedAtMs: now.utcMs,
        ),
      );
      final edited = await db.editWeight(
        id,
        81.8,
        met,
        now,
        at: at('2026-11-12', 9, 0, 0),
      );
      expect(edited.weightKg, 81.83);
    });

    test('50.6 lb survives a time-only edit made in kg', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final row = await db.saveWeight(50.6, imp, now);
      expect(formatWeight(row.weightKg, met), '23.0');
      final edited = await db.editWeight(
        row.id,
        23.0,
        met,
        now,
        at: at('2026-11-12', 8, 0, 0),
      );
      expect(edited.weightKg, row.weightKg);
      expect(formatWeight(edited.weightKg, imp), '50.6');
    });

    test('a changed number in the other unit does change the stored value',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      final row = await db.saveWeight(180.4, imp, now);
      final edited = await db.editWeight(row.id, 82.0, met, now);
      expect(edited.weightKg, 82.0);
    });

    test('every lb value survives a time-only edit made in kg', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final later = at('2026-11-12', 8, 0, 0);
      for (var i = 500; i <= 10000; i += 13) {
        final row = await db.saveWeight(i / 10, imp, now);
        final shown = parseWeight(formatWeight(row.weightKg, met))!;
        final edited = await db.editWeight(row.id, shown, met, now, at: later);
        expect(edited.weightKg, row.weightKg, reason: '${i / 10} lb');
      }
    });
  });

  group('range', () {
    test('below 50 or above 1,000 lb is refused, the limits are accepted',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      for (final bad in [49.9, 0.0, -5.0, 1000.1, 5000.0]) {
        await expectLater(
          db.saveWeight(bad, imp, now),
          throwsA(isA<WeightOutOfRange>()),
          reason: '$bad lb',
        );
      }
      expect(await db.select(db.weightEntries).get(), isEmpty);
      await db.saveWeight(50.0, imp, now);
      await db.saveWeight(1000.0, imp, now);
      expect(await db.select(db.weightEntries).get(), hasLength(2));
    });

    test('below 22.7 or above 453.6 kg is refused, the limits are accepted',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      for (final bad in [22.6, 0.0, 453.7, 1000.0]) {
        await expectLater(
          db.saveWeight(bad, met, now),
          throwsA(isA<WeightOutOfRange>()),
          reason: '$bad kg',
        );
      }
      expect(await db.select(db.weightEntries).get(), isEmpty);
      await db.saveWeight(22.7, met, now);
      await db.saveWeight(453.6, met, now);
      expect(await db.select(db.weightEntries).get(), hasLength(2));
    });

    test('the range is judged in the unit typed', () async {
      final now = at('2026-11-12', 7, 0, 0);
      // 24 is out of range in lb but fine in kg.
      await expectLater(
        db.saveWeight(24, imp, now),
        throwsA(isA<WeightOutOfRange>()),
      );
      expect(await db.select(db.weightEntries).get(), isEmpty);
      await db.saveWeight(24, met, now);
      expect(await db.select(db.weightEntries).get(), hasLength(1));
    });

    test('huge numbers are refused with WeightOutOfRange', () async {
      final now = at('2026-11-12', 7, 0, 0);
      for (final big in [1e6, 1e300, 1e308, double.maxFinite]) {
        await expectLater(
          db.saveWeight(big, imp, now),
          throwsA(isA<WeightOutOfRange>()),
        );
      }
      expect(await db.select(db.weightEntries).get(), isEmpty);
    });

    test('NaN and infinity are refused', () async {
      final now = at('2026-11-12', 7, 0, 0);
      await expectLater(
        db.saveWeight(double.nan, imp, now),
        throwsA(isA<WeightOutOfRange>()),
      );
      await expectLater(
        db.saveWeight(double.infinity, met, now),
        throwsA(isA<WeightOutOfRange>()),
      );
      expect(await db.select(db.weightEntries).get(), isEmpty);
    });
  });

  group('time zones', () {
    test('a 7:00 weigh-in in Tokyo keeps its day when the clock moves to -6',
        () async {
      final tokyo = at('2026-11-12', 7, 0, 9);
      final row = await db.saveWeight(181.8, imp, tokyo);
      expect(row.localDate, '2026-11-12');
      expect(row.tzOffsetMinutes, 540);
      expect(tokyo.localDate, '2026-11-12');

      // The phone lands in Chicago. The same instant is still the day before there.
      final chicago = Now(utcMs: tokyo.utcMs, offsetMinutes: -360);
      expect(chicago.localDate, '2026-11-11');
      final stored = (await db.latestWeight())!;
      expect(stored.localDate, '2026-11-12');
      expect(stored.tzOffsetMinutes, 540);
      // The trend sees it on the day it was made.
      expect((await db.watchTrend().first).single.localDate, '2026-11-12');
    });

    test('today follows the current offset', () {
      final utc = DateTime.utc(2026, 11, 12, 3, 0).millisecondsSinceEpoch;
      Now clock(int off) => Now(utcMs: utc, offsetMinutes: off);
      expect(clock(0).localDate, '2026-11-12');
      expect(clock(-6 * 60).localDate, '2026-11-11');
      expect(clock(9 * 60).localDate, '2026-11-12');
      expect(clock(-12 * 60).localDate, '2026-11-11');
      expect(clock(14 * 60).localDate, '2026-11-12');
    });

    test('a weigh-in made at the extreme offsets lands on the local day',
        () async {
      for (final off in [-12.0, 14.0]) {
        final row = await db.saveWeight(
          181.8,
          imp,
          at('2026-11-12', 0, 30, off),
        );
        expect(row.localDate, '2026-11-12', reason: 'offset $off');
        expect(row.tzOffsetMinutes, (off * 60).round());
        final late = await db.saveWeight(
          181.8,
          imp,
          at('2026-11-12', 23, 30, off),
        );
        expect(late.localDate, '2026-11-12', reason: 'offset $off');
      }
    });

    test('the same instant is two different days at -12 and +14', () async {
      final utc = DateTime.utc(2026, 11, 12, 12, 0).millisecondsSinceEpoch;
      final west = await db.saveWeight(
        181,
        imp,
        Now(utcMs: utc, offsetMinutes: -12 * 60),
      );
      final east = await db.saveWeight(
        181,
        imp,
        Now(utcMs: utc, offsetMinutes: 14 * 60),
      );
      expect(west.localDate, '2026-11-12'); // 00:00
      expect(east.localDate, '2026-11-13'); // 02:00 the next day
    });
  });

  group('date boundaries', () {
    test('23:59:59 and 00:00:00 land on different days', () async {
      final late = await db.saveWeight(
        181,
        imp,
        at('2026-11-12', 23, 59, -6, 59),
      );
      final early = await db.saveWeight(
        181,
        imp,
        at('2026-11-13', 0, 0, -6),
      );
      expect(late.localDate, '2026-11-12');
      expect(early.localDate, '2026-11-13');
      expect(early.measuredAtMs - late.measuredAtMs, 1000);
    });

    test('New Year', () async {
      final eve = await db.saveWeight(
        181,
        imp,
        at('2026-12-31', 23, 59, 0, 59),
      );
      final day = await db.saveWeight(181, imp, at('2027-01-01', 0, 0, 0));
      expect(eve.localDate, '2026-12-31');
      expect(day.localDate, '2027-01-01');
      expect(
        (await db.watchTrend().first).map((p) => p.localDate),
        ['2026-12-31', '2027-01-01'],
      );
    });

    test('a daylight saving change day stays one day', () async {
      // New York, 2026-03-08: the clock jumps from 02:00 (-5) to 03:00 (-4).
      final before = await db.saveWeight(181, imp, at('2026-03-08', 1, 30, -5));
      final after = await db.saveWeight(182, imp, at('2026-03-08', 3, 30, -4));
      final night = await db.saveWeight(183, imp, at('2026-03-08', 23, 59, -4, 59));
      final next = await db.saveWeight(184, imp, at('2026-03-09', 0, 0, -4));
      expect(before.localDate, '2026-03-08');
      expect(after.localDate, '2026-03-08');
      expect(night.localDate, '2026-03-08');
      expect(next.localDate, '2026-03-09');
      final trend = await db.watchTrend().first;
      expect(trend.map((p) => p.localDate), ['2026-03-08', '2026-03-09']);
      expect(trend.first.averageKg, closeTo(weightToKg(182, imp), 1e-9));

      // The autumn change day has 25 hours; both 01:30 weigh-ins are that day.
      final a = await db.saveWeight(181, imp, at('2026-11-01', 1, 30, -4));
      final b = await db.saveWeight(181, imp, at('2026-11-01', 1, 30, -5));
      expect(a.localDate, '2026-11-01');
      expect(b.localDate, '2026-11-01');
      expect(b.measuredAtMs - a.measuredAtMs, 3600 * 1000);
    });

    test('two weigh-ins in one day both stay and the trend uses their average',
        () async {
      final now = at('2026-11-12', 7, 0, 0);
      await db.saveWeight(180, imp, at('2026-11-12', 7, 0, 0));
      await db.saveWeight(182, imp, at('2026-11-12', 21, 0, 0));
      expect(await db.watchWeights().first, hasLength(2));
      final trend = await db.watchTrend().first;
      expect(trend, hasLength(1));
      expect(trend.single.averageKg, closeTo(weightToKg(181, imp), 1e-9));
      expect(formatWeight((await db.latestWeight())!.weightKg, imp), '182.0');
      expect(now.localDate, '2026-11-12');
    });

    test('moving a weigh-in to another day moves its trend day', () async {
      final now = at('2026-11-12', 7, 0, 0);
      final row = await db.saveWeight(181, imp, now);
      await db.editWeight(row.id, 181, imp, now, at: at('2026-11-11', 23, 59, 0));
      expect((await db.watchTrend().first).single.localDate, '2026-11-11');
    });
  });

  group('trend', () {
    test('the trend follows saves, edits and deletes', () async {
      final now = at('2026-11-12', 7, 0, 0);
      await db.saveWeight(180, imp, now, at: at('2026-11-10', 7, 0, 0));
      final b = await db.saveWeight(190, imp, now, at: at('2026-11-11', 7, 0, 0));
      var trend = await db.watchTrend().first;
      final k180 = weightToKg(180, imp);
      final k190 = weightToKg(190, imp);
      expect(trend.last.trendKg, closeTo(k180 + 0.1 * (k190 - k180), 1e-9));

      await db.editWeight(b.id, 200, imp, now);
      trend = await db.watchTrend().first;
      expect(
        trend.last.trendKg,
        closeTo(k180 + 0.1 * (weightToKg(200, imp) - k180), 1e-9),
      );

      await db.deleteWeight(b.id, now);
      trend = await db.watchTrend().first;
      expect(trend.single.trendKg, closeTo(k180, 1e-9));
    });
  });
}
