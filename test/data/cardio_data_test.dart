// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/clock.dart';
import 'package:daybook/data/cardio_data.dart';
import 'package:daybook/data/database.dart';
import 'package:daybook/data/goal_data.dart';
import 'package:daybook/data/met_table.dart';
import 'package:daybook/data/weight_data.dart';
import 'package:daybook/math/calorie_budget.dart';
import 'package:daybook/util/units.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const imp = UnitSystem.imperial;
const cst = -360; // US Central, standard time

Now localAt(String date, int h, int m, [int offset = cst]) =>
    Now.fromLocal(date, h * 60 + m, offset);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MetTable table;
  late AppDatabase db;
  final noon = localAt('2026-11-12', 12, 0);

  setUpAll(() async => table = await MetTable.load());
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> weigh(double lb, String date) =>
      db.saveWeight(lb, imp, localAt(date, 7, 0)).then((_) {});

  const running = '12145'; // any code of a group means the group
  const walking = '17190';
  const cycling = '01014';

  CardioInput run({
    String code = running,
    String? entry,
    int minutes = 30,
    double? miles = 3.1,
    int? hr,
    double? override,
  }) => CardioInput(
    activityCode: code,
    entryCode: entry,
    durationSeconds: minutes * 60,
    distanceMeters: miles == null ? null : milesToMeters(miles),
    avgHeartRate: hr,
    kcalOverride: override,
  );

  Future<CardioSession> save(CardioInput input, [Now? at]) =>
      db.saveCardio(table, input, at ?? noon);

  // A row the way task 7.1's import will write it: another source, and
  // possibly no activity code and no MET.
  Future<int> imported(
    Now at, {
    String? code,
    double? met,
    double? estimate,
    double? override,
    String sourceId = 'hc-1',
    String name = 'Imported run',
  }) => db
      .into(db.cardioSessions)
      .insert(
        CardioSessionsCompanion.insert(
          localDate: at.localDate,
          startedAtMs: at.utcMs,
          tzOffsetMinutes: at.offsetMinutes,
          activityCode: Value(code),
          activityName: name,
          met: Value(met),
          durationSeconds: 1800,
          kcalEstimated: Value(estimate),
          kcalOverride: Value(override),
          source: const Value('health_connect'),
          sourceId: Value(sourceId),
        ),
      );

  group('rule 1 and 2: the sample, the estimate and the band', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test('3.1 mi in 30 min: 6.2 mph, code 12050, MET 9.3, 383 kcal', () async {
      final s = await save(run());
      expect(s.activityCode, '12050');
      expect(s.activityName, 'Running');
      expect(s.met, 9.3);
      expect(s.durationSeconds, 1800);
      expect(s.distanceMeters, closeTo(milesToMeters(3.1), 1e-9));
      expect(roundForDisplay(s.kcalEstimated!), 383);
      // Stored unrounded: 9.3 x 82.46 kg x 0.5 h.
      expect(s.kcalEstimated, closeTo(383.45, 0.01));
      expect(s.kcalEstimated, isNot(s.kcalEstimated!.roundToDouble()));
      expect(s.kcalOverride, isNull);
      expect(s.source, 'manual');
      expect(s.deletedAtMs, isNull);
    });

    Future<String?> entryAt(String code, double mph) async =>
        (await db.cardioPreview(
          table,
          activityCode: code,
          durationSeconds: 3600,
          distanceMeters: milesToMeters(mph),
          localDate: '2026-11-12',
        )).entry.code;

    test('running at 6.2 mph, and a pace under the slowest band', () async {
      expect(await entryAt(running, 6.2), '12050');
      expect(await entryAt(running, 2.0), '12026'); // slowest band, 2.6 to 3.7
      expect(await entryAt(running, 30), '12135'); // fastest band, 14 mph
    });

    test('cycling at 10.0, 19.5, 8 and 25 mph', () async {
      expect(await entryAt(cycling, 10.0), '01020'); // "<10" is not 10
      expect(await entryAt(cycling, 19.5), '01050'); // tie: the slower
      expect(await entryAt(cycling, 8), '01010');
      expect(await entryAt(cycling, 25), '01060');
    });

    test('walking at 2.0, 2.6, 3.0 and 5.0 mph', () async {
      expect(
        await entryAt(walking, 2.0),
        '17152',
      ); // "less than 2.0" is not 2.0
      expect(await entryAt(walking, 2.6), '17170'); // gap, 0.1 from 2.5
      expect(await entryAt(walking, 3.0), '17190');
      expect(await entryAt(walking, 5.0), '17231');
    });

    test('an entry for another group is never used for a pace', () async {
      // Any code of the group means the group, so a walking band code with a
      // running pace still picks within Walking.
      expect(await entryAt('17231', 3.0), '17190');
    });

    test('kilometers: 5 km in 30 min is 6.2 mph, the same 12050', () async {
      final s = await save(
        CardioInput(
          activityCode: running,
          durationSeconds: 1800,
          distanceMeters: kmToMeters(5),
        ),
      );
      expect(s.distanceMeters, 5000);
      expect(s.activityCode, '12050');
    });

    test('the preview shows what the screen needs while typing', () async {
      final p = await db.cardioPreview(
        table,
        activityCode: running,
        durationSeconds: 1800,
        distanceMeters: milesToMeters(3.1),
        localDate: '2026-11-12',
      );
      expect(p.entry.code, '12050');
      expect(p.group?.name, 'Running');
      expect(p.mph, closeTo(6.2, 1e-9));
      expect(p.fromPace, isTrue);
      expect(p.weightKg, closeTo(lbToKg(181.8), 1e-9));
      expect(roundForDisplay(p.kcal!), 383);
    });

    test('the preview has no estimate until there is a duration', () async {
      final p = await db.cardioPreview(
        table,
        activityCode: running,
        localDate: '2026-11-12',
      );
      expect(p.kcal, isNull);
      expect(p.mph, isNull);
      expect(p.entry.code, '12145');
    });

    test('an unknown code is refused', () async {
      await expectLater(
        save(run(code: '99999')),
        throwsA(
          isA<CardioRefused>().having(
            (e) => e.problem,
            'problem',
            CardioProblem.noActivity,
          ),
        ),
      );
      await expectLater(
        save(const CardioInput(durationSeconds: 600)),
        throwsA(isA<CardioRefused>()),
      );
    });
  });

  group('rule 3: with no distance', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test('first time: the group\'s general entry', () async {
      expect((await save(run(miles: null))).activityCode, '12145');
      expect(
        (await save(run(code: walking, miles: null))).activityCode,
        '17190',
      );
      expect(
        (await save(run(code: cycling, miles: null))).activityCode,
        '01014',
      );
    });

    test('with a last time: the entry used then', () async {
      await save(run(miles: 3.4), localAt('2026-11-10', 12, 0)); // 6.8: 12060
      final s = await save(run(miles: null));
      expect(s.activityCode, '12060');
      expect(s.met, 10.5);
    });

    test('last time is the most recent, and per group', () async {
      await save(run(miles: 3.4), localAt('2026-11-10', 12, 0)); // 12060
      await save(run(miles: 3.1), localAt('2026-11-11', 12, 0)); // 12050
      await save(run(code: walking, miles: 3.0), localAt('2026-11-11', 8, 0));
      expect((await save(run(miles: null))).activityCode, '12050');
      // 3 mi in 30 min is 6 mph, past the fastest walking band: 17231.
      expect(
        (await save(run(code: walking, miles: null))).activityCode,
        '17231',
      );
    });

    test('last time skips deleted sessions', () async {
      await save(run(miles: 3.4), localAt('2026-11-10', 12, 0)); // 12060
      final newer = await save(run(miles: 3.1), localAt('2026-11-11', 12, 0));
      await db.deleteCardio(newer.id, noon);
      expect((await save(run(miles: null))).activityCode, '12060');
    });

    test('last time skips a session with no code, and an imported one '
        'with a code counts', () async {
      await save(run(miles: 3.4), localAt('2026-11-10', 12, 0)); // 12060
      await imported(localAt('2026-11-11', 12, 0)); // no code, newer
      expect((await db.lastEntryFor(table, running))!.code, '12060');
      await imported(
        localAt('2026-11-11', 18, 0),
        code: '12070',
        met: 11.0,
        sourceId: 'hc-2',
      );
      expect((await db.lastEntryFor(table, running))!.code, '12070');
    });

    test('Other: its own row always, with or without a distance', () async {
      // 02054 is not in any group.
      final a = await save(run(code: '02054', miles: null));
      expect(a.activityCode, '02054');
      expect(a.activityName, table.byCode('02054')!.description);
      expect(a.met, 3.5);
      final b = await save(run(code: '02054', miles: 3.0));
      expect(b.activityCode, '02054');
    });

    test('last entry for an Other row, or an unknown code, is null', () async {
      await save(run(code: '02054', miles: null));
      expect(await db.lastEntryFor(table, '02054'), isNull);
      expect(await db.lastEntryFor(table, '99999'), isNull);
    });

    test('a chosen entry (Change) wins, with or without a distance', () async {
      expect(
        (await save(run(entry: '12090', miles: null))).activityCode,
        '12090',
      );
      expect((await save(run(entry: '12090'))).activityCode, '12090');
      await expectLater(
        save(run(entry: '99999')),
        throwsA(isA<CardioRefused>()),
      );
    });
  });

  group('rule 4: body weight', () {
    test('the latest weigh-in on or before the session\'s day', () async {
      await weigh(190, '2026-11-01');
      await weigh(181.8, '2026-11-10');
      final s = await save(run());
      expect(s.kcalEstimated, closeTo(9.3 * lbToKg(181.8) * 0.5, 1e-6));
    });

    test('a weigh-in on the same day counts, whatever its time', () async {
      await db.saveWeight(181.8, imp, localAt('2026-11-12', 20, 0));
      final s = await save(run(), localAt('2026-11-12', 6, 0));
      expect(s.kcalEstimated, isNotNull);
    });

    test('a weigh-in after the session\'s day is not used', () async {
      await weigh(181.8, '2026-11-13');
      final s = await save(run());
      expect(s.kcalEstimated, isNull);
      await weigh(200, '2026-11-11');
      final t = await save(run());
      expect(t.kcalEstimated, closeTo(9.3 * lbToKg(200) * 0.5, 1e-6));
    });

    test('a deleted weigh-in is not used', () async {
      final w = await db.saveWeight(181.8, imp, localAt('2026-11-10', 7, 0));
      await db.deleteWeight(w.id, noon);
      expect((await save(run())).kcalEstimated, isNull);
    });

    test(
      'with none, the estimate is empty and the row is still saved',
      () async {
        final s = await save(run());
        expect(s.kcalEstimated, isNull);
        expect(s.met, 9.3);
        expect(s.activityCode, '12050');
        final typed = await save(run(override: 350));
        expect(typed.kcalEstimated, isNull);
        expect(typed.kcalOverride, 350);
      },
    );
  });

  group('rule 5: the estimate and the override', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test('both are stored, and the override is the effective number', () async {
      final s = await save(run(override: 360));
      expect(s.kcalOverride, 360);
      expect(roundForDisplay(s.kcalEstimated!), 383);
      expect(s.effectiveKcal, 360);
      expect(s.usesOverride, isTrue);
      final e = await save(run());
      expect(e.effectiveKcal, e.kcalEstimated);
      expect(e.usesOverride, isFalse);
    });

    test('0 is allowed and counts as 0', () async {
      final s = await save(run(override: 0));
      expect(s.kcalOverride, 0);
      expect(s.effectiveKcal, 0);
      expect(s.usesOverride, isTrue);
    });

    test(
      'a negative or non-finite override is refused, nothing written',
      () async {
        for (final bad in [-1.0, -0.001, double.nan, double.infinity]) {
          await expectLater(
            save(run(override: bad)),
            throwsA(
              isA<CardioRefused>().having(
                (e) => e.problem,
                'problem',
                CardioProblem.badNumber,
              ),
            ),
          );
        }
        expect(await db.select(db.cardioSessions).get(), isEmpty);
        final ok = await save(run());
        await expectLater(
          db.editCardio(ok.id, table, run(override: -5)),
          throwsA(isA<CardioRefused>()),
        );
        expect((await db.cardioSession(ok.id))!.kcalOverride, isNull);
      },
    );

    test('an effective number with neither is null', () async {
      await db.delete(db.weightEntries).go();
      final s = await save(run());
      expect(s.effectiveKcal, isNull);
    });
  });

  group('rule 6: units and what is refused', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test('a distance of 0 or empty means no distance', () async {
      final z = await save(
        const CardioInput(
          activityCode: running,
          durationSeconds: 1800,
          distanceMeters: 0,
        ),
      );
      expect(z.distanceMeters, isNull);
      expect(z.activityCode, '12145');
      final n = await save(run(miles: null));
      expect(n.distanceMeters, isNull);
    });

    test(
      'a duration of 0 or less, or a negative distance, is refused',
      () async {
        for (final secs in [0, -60]) {
          await expectLater(
            db.saveCardio(
              table,
              CardioInput(activityCode: running, durationSeconds: secs),
              noon,
            ),
            throwsA(
              isA<CardioRefused>().having(
                (e) => e.problem,
                'problem',
                CardioProblem.badDuration,
              ),
            ),
          );
        }
        for (final d in [-1.0, double.nan, double.infinity]) {
          await expectLater(
            db.saveCardio(
              table,
              CardioInput(
                activityCode: running,
                durationSeconds: 600,
                distanceMeters: d,
              ),
              noon,
            ),
            throwsA(
              isA<CardioRefused>().having(
                (e) => e.problem,
                'problem',
                CardioProblem.badDistance,
              ),
            ),
          );
        }
        expect(await db.select(db.cardioSessions).get(), isEmpty);
      },
    );

    test('heart rate is stored and does not change the estimate', () async {
      final a = await save(run(hr: 150));
      final b = await save(run());
      expect(a.avgHeartRate, 150);
      expect(b.avgHeartRate, isNull);
      expect(a.kcalEstimated, b.kcalEstimated);
    });
  });

  group('rule 7: save returns the row, edit, delete and Undo', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test(
      'save returns the row read back, with the start time and offset',
      () async {
        final at = localAt('2026-11-12', 12, 0, -300);
        final s = await save(run(), at);
        expect(await db.cardioSession(s.id), s);
        expect(s.localDate, '2026-11-12');
        expect(s.startedAtMs, at.utcMs);
        expect(s.tzOffsetMinutes, -300);
      },
    );

    test('edit recomputes the estimate from the stored values', () async {
      final s = await save(run());
      final e = await db.editCardio(s.id, table, run(minutes: 60, miles: 6.2));
      expect(e.id, s.id);
      expect(e.durationSeconds, 3600);
      expect(e.activityCode, '12050'); // still 6.2 mph
      expect(e.kcalEstimated, closeTo(s.kcalEstimated! * 2, 1e-9));
      // Faster: another band, another MET.
      final f = await db.editCardio(s.id, table, run(minutes: 30, miles: 3.5));
      expect(f.activityCode, '12070'); // 7 mph
      expect(f.met, 11.0);
      expect(f.kcalEstimated, closeTo(11.0 * lbToKg(181.8) * 0.5, 1e-6));
      // The distance removed: the entry stays what it was (same activity).
      final g = await db.editCardio(s.id, table, run(miles: null));
      expect(g.distanceMeters, isNull);
      expect(g.activityCode, '12070');
      // Another activity.
      final h = await db.editCardio(s.id, table, run(code: cycling, miles: 7));
      expect(h.activityCode, '01040'); // 7 mi in 30 min is 14 mph
      expect(h.activityName, 'Bicycling');
      expect(h.met, 10.0);
    });

    test('edit with only the override changed keeps the estimate', () async {
      final s = await save(run());
      await weigh(150, '2026-11-11'); // would give another estimate now
      final e = await db.editCardio(s.id, table, run(override: 360, hr: 140));
      expect(e.kcalOverride, 360);
      expect(e.avgHeartRate, 140);
      expect(e.kcalEstimated, s.kcalEstimated);
      // Use estimate: the override cleared, the estimate still there.
      final u = await db.editCardio(s.id, table, run());
      expect(u.kcalOverride, isNull);
      expect(u.kcalEstimated, s.kcalEstimated);
      expect(u.effectiveKcal, s.kcalEstimated);
    });

    test('edit with a changed number takes the day\'s weigh-in now', () async {
      final s = await save(run());
      await weigh(150, '2026-11-11');
      final e = await db.editCardio(s.id, table, run(minutes: 40, miles: 4.1));
      expect(e.kcalEstimated, closeTo(9.3 * lbToKg(150) * (40 / 60), 1e-6));
    });

    test('edit keeps the day and time unless a new start is given', () async {
      final at = localAt('2026-11-12', 23, 50);
      final s = await save(run(), at);
      final e = await db.editCardio(s.id, table, run(minutes: 31, miles: 3.2));
      expect(e.localDate, '2026-11-12');
      expect(e.startedAtMs, at.utcMs);
      expect(e.tzOffsetMinutes, cst);
      final moved = await db.editCardio(
        s.id,
        table,
        run(minutes: 31, miles: 3.2),
        at: localAt('2026-11-13', 0, 10, -300),
      );
      expect(moved.localDate, '2026-11-13');
      expect(moved.tzOffsetMinutes, -300);
    });

    test('edit keeps source and source id', () async {
      final id = await imported(noon, code: '12050', met: 9.3, estimate: 383);
      final e = await db.editCardio(id, table, run(override: 400));
      expect(e.source, 'health_connect');
      expect(e.sourceId, 'hc-1');
    });

    test('edit with the same numbers does not touch the estimate, and a '
        'missing estimate is worked out', () async {
      final s = await save(run());
      final same = await db.editCardio(s.id, table, run());
      expect(same, s);
      await db.delete(db.weightEntries).go();
      final none = await save(run(), localAt('2026-11-12', 13, 0));
      expect(none.kcalEstimated, isNull);
      await weigh(181.8, '2026-11-10');
      final now = await db.editCardio(none.id, table, run(hr: 130));
      expect(now.kcalEstimated, isNotNull);
    });

    test('editing a missing or deleted session is an error', () async {
      await expectLater(db.editCardio(999, table, run()), throwsStateError);
      final s = await save(run());
      await db.deleteCardio(s.id, noon);
      await expectLater(db.editCardio(s.id, table, run()), throwsStateError);
    });

    test('delete is soft, and Undo clears it', () async {
      final s = await save(run());
      final d = await db.deleteCardio(s.id, localAt('2026-11-12', 13, 0));
      expect(d.deletedAtMs, localAt('2026-11-12', 13, 0).utcMs);
      expect(await db.select(db.cardioSessions).get(), hasLength(1));
      expect(await db.cardioForDay('2026-11-12'), isEmpty);
      final back = await db.undoDeleteCardio(s.id);
      expect(back.deletedAtMs, isNull);
      expect(back, s);
      expect(await db.cardioForDay('2026-11-12'), [s]);
      await expectLater(db.deleteCardio(999, noon), throwsStateError);
      await expectLater(db.undoDeleteCardio(999), throwsStateError);
    });

    test('a list of the day: not deleted, oldest first', () async {
      final b = await save(run(), localAt('2026-11-12', 18, 0));
      final a = await save(run(), localAt('2026-11-12', 7, 0));
      await save(run(), localAt('2026-11-13', 7, 0));
      final gone = await save(run(), localAt('2026-11-12', 9, 0));
      await db.deleteCardio(gone.id, noon);
      expect(await db.cardioForDay('2026-11-12'), [a, b]);
      final seen = <List<CardioSession>>[];
      final sub = db.watchCardioForDay('2026-11-12').listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, [a, b]);
      await db.deleteCardio(a.id, noon);
      await pumpEventQueue();
      expect(seen.last, [b]);
      final edited = await db.editCardio(b.id, table, run(override: 77));
      await pumpEventQueue();
      expect(seen.last, [edited]);
      expect(seen.last.single.kcalOverride, 77);
      await sub.cancel();
    });
  });

  group('the entry must belong to the activity', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    Matcher noActivity() => throwsA(
      isA<CardioRefused>().having(
        (e) => e.problem,
        'problem',
        CardioProblem.noActivity,
      ),
    );

    test('a code of another group, or another Other row, is refused', () async {
      await expectLater(save(run(entry: '17190')), noActivity()); // Running
      await expectLater(save(run(code: walking, entry: '12050')), noActivity());
      await expectLater(save(run(code: cycling, entry: '12050')), noActivity());
      await expectLater(save(run(code: '02054', entry: '02050')), noActivity());
      await expectLater(save(run(code: '02054', entry: '12050')), noActivity());
      expect(await db.select(db.cardioSessions).get(), isEmpty);
      // Edit refuses the same, and writes nothing.
      final s = await save(run());
      await expectLater(
        db.editCardio(s.id, table, run(entry: '17190', override: 99)),
        noActivity(),
      );
      expect(await db.cardioSession(s.id), s);
    });

    test(
      'an entry of the same group, or the Other row itself, is fine',
      () async {
        expect((await save(run(entry: '12090'))).activityCode, '12090');
        expect((await save(run(entry: '12145'))).activityCode, '12145');
        expect(
          (await save(run(code: '02054', entry: '02054'))).activityCode,
          '02054',
        );
      },
    );
  });

  group('the preview says how the entry was found', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    Future<CardioPreview> pv({String? entry, double? miles}) =>
        db.cardioPreview(
          table,
          activityCode: running,
          entryCode: entry,
          durationSeconds: 3600,
          distanceMeters: miles == null ? null : milesToMeters(miles),
          localDate: '2026-11-12',
        );

    test('6.2 mph is in its band', () async {
      final p = await pv(miles: 6.2);
      expect(p.entry.code, '12050');
      expect(p.fromPace, isTrue);
      expect(p.inBand, isTrue);
    });

    test('6.5 mph is in a gap: nearest band, not in band', () async {
      final p = await pv(miles: 6.5);
      expect(p.entry.code, '12050');
      expect(p.fromPace, isTrue);
      expect(p.inBand, isFalse);
      expect((await pv(miles: 30)).inBand, isFalse); // beyond the fastest
    });

    test('no distance, or a chosen entry: neither', () async {
      final a = await pv();
      expect([a.fromPace, a.inBand], [false, false]);
      final b = await pv(entry: '12090', miles: 6.2);
      expect([b.fromPace, b.inBand], [false, false]);
    });
  });

  group('heart rate', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test('when given it must be above 0', () async {
      for (final bad in [0, -1, -150]) {
        await expectLater(
          save(run(hr: bad)),
          throwsA(
            isA<CardioRefused>().having(
              (e) => e.problem,
              'problem',
              CardioProblem.badNumber,
            ),
          ),
        );
      }
      expect(await db.select(db.cardioSessions).get(), isEmpty);
      final s = await save(run(hr: 1));
      expect(s.avgHeartRate, 1);
      await expectLater(
        db.editCardio(s.id, table, run(hr: 0)),
        throwsA(isA<CardioRefused>()),
      );
      expect((await db.cardioSession(s.id))!.avgHeartRate, 1);
    });
  });

  group('what an edit stores, and the preview of it', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    Future<void> goals() => db
        .saveGoals(
          const GoalInput(
            activity: ActivityLevel.sedentary,
            rate: WeeklyRate(Target.stay, 0, imp),
            ownCalories: 2138,
          ),
          localAt('2026-11-08', 8, 0),
        )
        .then((_) {});

    test('an edit that changes no estimate input keeps the stored estimate, '
        'and the preview says so', () async {
      final s = await save(run()); // 383 at 181.8 lb
      await weigh(150, '2026-11-12'); // the session's own day, later
      final after = localAt('2026-11-12', 15, 30);
      final edits = <String, (CardioInput, Now?)>{
        'override only': (run(override: 360), null),
        'use estimate': (run(), null),
        'heart rate only': (run(hr: 140), null),
        'time of day only': (run(), after),
      };
      for (final e in edits.entries) {
        final p = await db.editPreview(table, s.id, e.value.$1, at: e.value.$2);
        expect(p.kcal, s.kcalEstimated, reason: e.key);
        expect(p.keptStored, isTrue, reason: e.key);
        final row = await db.editCardio(
          s.id,
          table,
          e.value.$1,
          at: e.value.$2,
        );
        expect(row.kcalEstimated, s.kcalEstimated, reason: e.key);
        expect(roundForDisplay(row.kcalEstimated!), 383, reason: e.key);
      }
      expect((await db.cardioSession(s.id))!.startedAtMs, after.utcMs);
    });

    test('a changed duration, distance or entry works it out again, and the '
        'preview is what is stored', () async {
      final s = await save(run());
      await weigh(150, '2026-11-12');
      final inputs = [
        run(minutes: 40, miles: 4.1),
        run(miles: 3.2), // the distance, same band
        run(entry: '12090'), // the entry
      ];
      for (final input in inputs) {
        final p = await db.editPreview(table, s.id, input);
        expect(p.keptStored, isFalse);
        expect(p.weightKg, closeTo(lbToKg(150), 1e-9));
        final row = await db.editCardio(s.id, table, input);
        expect(row.kcalEstimated, p.kcal);
        expect(row.met, p.entry!.met);
        expect(row.kcalEstimated, isNot(s.kcalEstimated));
      }
      final d = await db.editCardio(s.id, table, run(minutes: 40, miles: 4.1));
      expect(d.kcalEstimated, closeTo(9.3 * lbToKg(150) * (40 / 60), 1e-6));
    });

    test('a move to another day uses that day\'s weigh-in and moves the '
        'calories between budgets', () async {
      await goals();
      final s = await save(run());
      await weigh(150, '2026-11-14');
      final to = localAt('2026-11-14', 12, 0);
      final p = await db.editPreview(table, s.id, run(), at: to);
      expect(p.keptStored, isFalse);
      expect(p.kcal, closeTo(9.3 * lbToKg(150) * 0.5, 1e-6));
      final row = await db.editCardio(s.id, table, run(), at: to);
      expect(row.localDate, '2026-11-14');
      expect(row.kcalEstimated, p.kcal);
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 0);
      expect((await db.budgetForDay('2026-11-14'))!.exerciseKcal, p.kcal);
    });

    test('a missing estimate is filled on any edit once there is a weigh-in, '
        'and the preview says it is new', () async {
      await db.delete(db.weightEntries).go();
      final s = await save(run());
      expect(s.kcalEstimated, isNull);
      final none = await db.editPreview(table, s.id, run(hr: 130));
      expect(none.kcal, isNull);
      expect(none.keptStored, isFalse);
      await weigh(181.8, '2026-11-10');
      final p = await db.editPreview(table, s.id, run(hr: 130));
      expect(p.keptStored, isFalse);
      expect(roundForDisplay(p.kcal!), 383);
      final row = await db.editCardio(s.id, table, run(hr: 130));
      expect(row.kcalEstimated, p.kcal);
    });

    test('the preview of a missing session is an error', () async {
      await expectLater(db.editPreview(table, 999, run()), throwsStateError);
    });
  });

  group('rule 8: the budget', () {
    Future<void> goals() => db
        .saveGoals(
          const GoalInput(
            activity: ActivityLevel.sedentary,
            rate: WeeklyRate(Target.stay, 0, imp),
            ownCalories: 2138,
          ),
          localAt('2026-11-08', 8, 0),
        )
        .then((_) {});

    setUp(() async {
      await weigh(181.8, '2026-11-09');
      await goals();
    });

    Future<DayBudget> budget([String day = '2026-11-12']) async =>
        (await db.budgetForDay(day))!;

    test('a session adds its effective calories, delete takes them off, '
        'Undo puts them back', () async {
      expect((await budget()).exerciseKcal, 0);
      final s = await save(run());
      expect((await budget()).exerciseKcal, s.kcalEstimated);
      expect((await budget()).shownLeft, 2521); // 2,138 + 383
      await db.deleteCardio(s.id, noon);
      expect((await budget()).exerciseKcal, 0);
      await db.undoDeleteCardio(s.id);
      expect((await budget()).shownLeft, 2521);
    });

    test('the override replaces the estimate in the budget', () async {
      final s = await save(run(override: 360));
      expect((await budget()).exerciseKcal, 360);
      await db.editCardio(s.id, table, run()); // Use estimate
      expect((await budget()).shownLeft, 2521);
    });

    test('the day is the session\'s local day', () async {
      await save(run(), localAt('2026-11-11', 23, 50));
      await save(run(minutes: 20, miles: null), localAt('2026-11-12', 0, 10));
      expect((await budget('2026-11-11')).exerciseKcal, greaterThan(0));
      expect(
        (await budget('2026-11-12')).exerciseKcal,
        closeTo(9.3 * lbToKg(181.8) * (20 / 60), 1e-6), // last time: 12050
      );
    });

    test('the budget stream re-emits when cardio changes', () async {
      final seen = <DayBudget?>[];
      final sub = db.watchBudgetForDay('2026-11-12').listen(seen.add);
      await pumpEventQueue();
      expect(seen.last!.exerciseKcal, 0);
      final s = await save(run());
      await pumpEventQueue();
      expect(seen.last!.shownLeft, 2521);
      await db.editCardio(s.id, table, run(override: 100));
      await pumpEventQueue();
      expect(seen.last!.exerciseKcal, 100);
      await db.deleteCardio(s.id, noon);
      await pumpEventQueue();
      expect(seen.last!.exerciseKcal, 0);
      await db.undoDeleteCardio(s.id);
      await pumpEventQueue();
      expect(seen.last!.exerciseKcal, 100);
      await sub.cancel();
    });
  });

  group('rule 9: recent activities', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test('none at first', () async {
      expect(await db.recentActivities(table), isEmpty);
    });

    test('most recent first, one per activity, up to 3', () async {
      await save(run(), localAt('2026-11-05', 12, 0)); // Running, 12050
      await save(run(code: walking, miles: 1.5), localAt('2026-11-06', 12, 0));
      await save(run(code: cycling, miles: 5), localAt('2026-11-07', 12, 0));
      await save(run(code: '02054', miles: null), localAt('2026-11-08', 12, 0));
      await save(
        run(miles: 3.4),
        localAt('2026-11-09', 12, 0),
      ); // Running again
      final r = await db.recentActivities(table);
      expect(r.map((e) => e.name), [
        'Running',
        table.byCode('02054')!.description,
        'Bicycling',
      ]);
      // Each carries the entry used last time, and its group when it has one.
      expect(r[0].entry.code, '12060');
      expect(r[0].group?.name, 'Running');
      expect(r[1].entry.code, '02054');
      expect(r[1].group, isNull);
      expect(r[2].entry.code, '01020'); // 5 mi in 30 min is 10 mph
    });

    test('the three groups count once each, Other rows by code', () async {
      await save(run(), localAt('2026-11-05', 12, 0));
      await save(
        run(entry: '12090', miles: null),
        localAt('2026-11-06', 12, 0),
      );
      await save(run(code: '02054', miles: null), localAt('2026-11-07', 12, 0));
      await save(run(code: '02050', miles: null), localAt('2026-11-08', 12, 0));
      await save(run(code: '02054', miles: null), localAt('2026-11-09', 12, 0));
      final r = await db.recentActivities(table);
      expect(r.map((e) => e.entry.code), ['02054', '02050', '12090']);
    });

    test('deleted sessions, sessions with no code and unknown codes are '
        'skipped', () async {
      final a = await save(run(), localAt('2026-11-05', 12, 0));
      final b = await save(
        run(code: walking, miles: 1.5),
        localAt('2026-11-06', 12, 0),
      );
      await db.deleteCardio(b.id, noon);
      await imported(localAt('2026-11-07', 12, 0)); // no code
      await imported(
        localAt('2026-11-08', 12, 0),
        code: '77777',
        met: 3,
        sourceId: 'hc-2',
      );
      final r = await db.recentActivities(table);
      expect(r.map((e) => e.entry.code), [a.activityCode]);
    });

    test('the stream follows saves and deletes', () async {
      final seen = <List<RecentActivity>>[];
      final sub = db.watchRecentActivities(table).listen(seen.add);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      final s = await save(run());
      await pumpEventQueue();
      expect(seen.last.map((e) => e.name), ['Running']);
      await db.deleteCardio(s.id, noon);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await sub.cancel();
    });
  });

  group('rule 10: imported sessions', () {
    setUp(() => weigh(181.8, '2026-11-09'));

    test('no code and no MET: counted in the budget and listed', () async {
      await db.saveGoals(
        const GoalInput(
          activity: ActivityLevel.sedentary,
          rate: WeeklyRate(Target.stay, 0, imp),
          ownCalories: 2000,
        ),
        localAt('2026-11-08', 8, 0),
      );
      await imported(noon, estimate: 250);
      await imported(noon, override: 100, sourceId: 'hc-2');
      await imported(noon, sourceId: 'hc-3'); // no number at all
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 350);
      final list = await db.cardioForDay('2026-11-12');
      expect(list, hasLength(3));
      expect(list.first.source, 'health_connect');
    });

    test('editing one with no code keeps its activity and its number', () async {
      final id = await imported(noon, estimate: 250);
      final e = await db.editCardio(
        id,
        table,
        const CardioInput(durationSeconds: 1800, kcalOverride: 300),
      );
      expect(e.activityCode, isNull);
      expect(e.activityName, 'Imported run');
      expect(e.met, isNull);
      expect(e.kcalEstimated, 250);
      expect(e.kcalOverride, 300);
      expect(e.source, 'health_connect');
      // A longer session with no MET cannot be recalculated: the number stays.
      final longer = await db.editCardio(
        id,
        table,
        const CardioInput(durationSeconds: 3600),
      );
      expect(longer.kcalEstimated, 250);
      expect(longer.durationSeconds, 3600);
    });

    test('the preview of a row with no code is what the edit stores', () async {
      await weigh(150, '2026-11-12');
      final id = await imported(noon, met: 9.3, estimate: 383);
      const longer = CardioInput(durationSeconds: 3600);
      final p = await db.editPreview(table, id, longer);
      expect(p.entry, isNull);
      expect(p.keptStored, isFalse);
      final row = await db.editCardio(id, table, longer);
      expect(p.kcal, row.kcalEstimated);
      expect(p.kcal, closeTo(9.3 * lbToKg(150), 1e-6));
      expect(row.met, 9.3);
      expect(row.activityName, 'Imported run');
      // Nothing that feeds the estimate changed: the stored number is kept.
      const same = CardioInput(durationSeconds: 1800, kcalOverride: 300);
      final k = await db.editPreview(table, id, same);
      expect(k.keptStored, isFalse); // the duration differs from 3600 now
      final again = await db.editCardio(id, table, longer);
      final kept = await db.editPreview(
        table,
        id,
        const CardioInput(durationSeconds: 3600, kcalOverride: 100),
      );
      expect(kept.keptStored, isTrue);
      expect(kept.kcal, again.kcalEstimated);
    });

    test('a stored code the table does not have can be edited', () async {
      final id = await imported(noon, code: '77777', met: 5, estimate: 200);
      CardioInput input({int secs = 1800, double? own}) => CardioInput(
        activityCode: '77777',
        durationSeconds: secs,
        kcalOverride: own,
      );
      final o = await db.editPreview(table, id, input(own: 150));
      expect(o.entry, isNull);
      expect(o.keptStored, isTrue);
      expect(o.kcal, 200);
      final saved = await db.editCardio(id, table, input(own: 150));
      expect(saved.kcalOverride, 150);
      expect(saved.activityCode, '77777');
      expect(saved.met, 5);
      expect(saved.kcalEstimated, 200);
      await weigh(150, '2026-11-12');
      final p = await db.editPreview(table, id, input(secs: 3600));
      expect(p.keptStored, isFalse);
      final row = await db.editCardio(id, table, input(secs: 3600));
      expect(row.kcalEstimated, p.kcal);
      expect(p.kcal, closeTo(5 * lbToKg(150), 1e-6));
      expect(row.activityCode, '77777');
      expect(row.activityName, 'Imported run');
      expect(row.met, 5);
    });

    test('a row with no MET and no code keeps no estimate and its own '
        'number', () async {
      final id = await imported(noon, override: 120);
      const input = CardioInput(durationSeconds: 3600, kcalOverride: 120);
      final p = await db.editPreview(table, id, input);
      expect(p.entry, isNull);
      expect(p.kcal, isNull);
      expect(p.keptStored, isTrue);
      final row = await db.editCardio(id, table, input);
      expect(row.kcalEstimated, isNull);
      expect(row.kcalOverride, 120);
      expect(row.durationSeconds, 3600);
    });

    test('an imported session can be chosen as an activity by code', () async {
      final id = await imported(noon, code: '12050', met: 9.3, estimate: 383);
      final e = await db.editCardio(id, table, run(miles: 3.5)); // 7 mph
      expect(e.activityCode, '12070');
      expect(e.source, 'health_connect');
    });

    test('delete and Undo work on imported rows, which stay stored', () async {
      final id = await imported(noon, estimate: 250);
      await db.deleteCardio(id, noon);
      expect(await db.cardioForDay('2026-11-12'), isEmpty);
      expect(await db.select(db.cardioSessions).get(), hasLength(1));
      final back = await db.undoDeleteCardio(id);
      expect(back.deletedAtMs, isNull);
      expect((await db.cardioForDay('2026-11-12')).map((e) => e.id), [id]);
      await db.saveGoals(
        const GoalInput(
          activity: ActivityLevel.sedentary,
          rate: WeeklyRate(Target.stay, 0, imp),
          ownCalories: 2000,
        ),
        localAt('2026-11-08', 8, 0),
      );
      expect((await db.budgetForDay('2026-11-12'))!.exerciseKcal, 250);
    });
  });

  group('rule 11: dates and time zones', () {
    setUp(() => weigh(181.8, '2026-03-01'));

    test('a session just before and just after midnight', () async {
      final late = await save(run(), localAt('2026-11-12', 23, 59));
      final early = await save(run(), localAt('2026-11-13', 0, 0));
      expect(late.localDate, '2026-11-12');
      expect(early.localDate, '2026-11-13');
      expect(late.startedAtMs + 60000, early.startedAtMs);
    });

    test(
      'the day uses the offset at the start, even in another zone',
      () async {
        // 23:30 in UTC+9 is still the 12th there, though it is the 12th 14:30
        // UTC; 00:30 in UTC-8 on the 13th is the 13th though it is 08:30 UTC.
        final tokyo = await save(run(), localAt('2026-11-12', 23, 30, 540));
        final la = await save(run(), localAt('2026-11-13', 0, 30, -480));
        expect(tokyo.localDate, '2026-11-12');
        expect(tokyo.tzOffsetMinutes, 540);
        expect(la.localDate, '2026-11-13');
      },
    );

    test('a daylight saving day: two offsets, one day', () async {
      // US Central, 2026-03-08: 02:00 standard jumps to 03:00 daylight.
      final before = await save(run(), localAt('2026-03-08', 1, 30, -360));
      final after = await save(run(), localAt('2026-03-08', 3, 30, -300));
      expect(before.localDate, '2026-03-08');
      expect(after.localDate, '2026-03-08');
      expect(before.tzOffsetMinutes, -360);
      expect(after.tzOffsetMinutes, -300);
      // Two hours of wall clock is one hour on the clock that day.
      expect(after.startedAtMs - before.startedAtMs, 60 * 60000);
      expect(await db.cardioForDay('2026-03-08'), [before, after]);
    });

    test(
      'the weigh-in is the one for the local day, not the UTC day',
      () async {
        await weigh(200, '2026-11-13');
        await weigh(181.8, '2026-11-12');
        // 20:00 local on the 12th is already the 13th in UTC.
        final s = await save(run(), localAt('2026-11-12', 20, 0));
        expect(s.kcalEstimated, closeTo(9.3 * lbToKg(181.8) * 0.5, 1e-6));
      },
    );
  });
}
