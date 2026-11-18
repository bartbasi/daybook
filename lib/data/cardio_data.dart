// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:drift/drift.dart';

import '../clock.dart';
import '../math/cardio_estimate.dart';
import 'database.dart';
import 'food_data.dart';
import 'goal_data.dart';
import 'met_table.dart';

// Cardio sessions: choose the Compendium entry, estimate the calories, save,
// edit, delete (soft, with Undo) and list. Calories reach the day's budget
// through exerciseKcalForDay in goal_data.dart, which counts each session that
// is not deleted by its local date, with the user's number when there is one,
// else the estimate (see [CardioSessionKcal.effectiveKcal]). No user-facing
// text here: the screen words the group names itself.
//
// Rows may come from elsewhere later (task 7.1 writes another [source]). They
// can have no activityCode and no met. Nothing here assumes 'manual'.
//
// An activity is one of the three groups (Running, Walking, Bicycling), named
// by any code of the group, or an "Other" row of the Compendium, named by its
// own code. A session stores the entry used (activityCode, met), and its name:
// the group's name, or the row's description for Other.

/// Why a cardio save or edit was refused. Carries no user data.
enum CardioProblem {
  /// No activity, or a code (activity or entry) that is not in the table.
  noActivity,

  /// The duration is zero or less.
  badDuration,

  /// A distance that is negative or not a number. (0 or none means no
  /// distance and is fine.)
  badDistance,

  /// An override that is negative or not a number. (0 is allowed.)
  badNumber,
}

class CardioRefused implements Exception {
  const CardioRefused(this.problem);

  final CardioProblem problem;

  @override
  String toString() => 'CardioRefused(${problem.name})';
}

/// What the cardio screen hands to [CardioData.saveCardio] and
/// [CardioData.editCardio].
class CardioInput {
  const CardioInput({
    this.activityCode,
    this.entryCode,
    required this.durationSeconds,
    this.distanceMeters,
    this.avgHeartRate,
    this.kcalOverride,
  });

  /// The activity picked: any code of a group, or an Other row's code. Needed
  /// to save. On an edit, null keeps the stored activity, entry and MET (an
  /// imported session may have none).
  final String? activityCode;

  /// The entry the user chose with Change. It wins over the pace and over last
  /// time.
  final String? entryCode;

  final int durationSeconds;

  /// In meters, whatever unit was typed. Null or 0: no distance.
  final double? distanceMeters;
  final int? avgHeartRate;

  /// The user's own calorie number. Null: use the estimate.
  final double? kcalOverride;
}

/// How the entry was found and what it comes to, for the screen's live
/// estimate and for saving.
class CardioPreview {
  const CardioPreview({
    required this.entry,
    required this.group,
    required this.mph,
    required this.fromPace,
    required this.weightKg,
    required this.kcal,
  });

  /// The Compendium row used.
  final MetActivity entry;

  /// The group the activity is in, or null for an Other row.
  final MetGroup? group;

  /// The pace in mph, or null when there is no distance (or no duration).
  final double? mph;

  /// True when [entry] is the band that holds [mph].
  final bool fromPace;

  /// The weigh-in used, or null when there is none.
  final double? weightKg;

  /// The estimate, unrounded. Null without a duration or without a weigh-in.
  final double? kcal;
}

/// One of the activities the screen offers again.
class RecentActivity {
  const RecentActivity({
    required this.name,
    required this.group,
    required this.entry,
  });

  /// The group's name ('Running') or an Other row's description.
  final String name;

  /// The group, or null for an Other row.
  final MetGroup? group;

  /// The entry used last time. Its code goes in [CardioInput.activityCode].
  final MetActivity entry;
}

extension CardioSessionKcal on CardioSession {
  /// The calories that count: the user's number when there is one, else the
  /// estimate, else null.
  double? get effectiveKcal => kcalOverride ?? kcalEstimated;

  /// True when the user's own number is the one in use.
  bool get usesOverride => kcalOverride != null;
}

extension CardioData on AppDatabase {
  Future<CardioSession?> cardioSession(int id) =>
      (select(cardioSessions)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<CardioSession> _row(int id) =>
      (select(cardioSessions)..where((c) => c.id.equals(id))).getSingle();

  // Choosing the entry and the estimate

  /// The entry and estimate for what is typed so far, without saving. Throws
  /// [CardioRefused] with [CardioProblem.noActivity] for an unknown code.
  ///
  /// The entry, in order: [entryCode] (the user's choice); for a group with a
  /// pace (a duration and a distance above 0), the band that holds the pace
  /// ([pickBand]); for a group with no distance, [currentEntryCode] if it is
  /// in the same group (an edit keeps its entry), else the entry of the last
  /// session of the group (not deleted, not [exceptId], with a code), else the
  /// group's general entry. An Other row is always its own row.
  ///
  /// [localDate] picks the weigh-in: the latest on or before that day.
  Future<CardioPreview> cardioPreview(
    MetTable table, {
    required String activityCode,
    String? entryCode,
    int? durationSeconds,
    double? distanceMeters,
    required String localDate,
    String? currentEntryCode,
    int? exceptId,
  }) async {
    final activity = table.byCode(activityCode);
    if (activity == null) throw const CardioRefused(CardioProblem.noActivity);
    final secs = durationSeconds != null && durationSeconds > 0
        ? durationSeconds
        : null;
    final distance =
        distanceMeters != null && distanceMeters.isFinite && distanceMeters > 0
        ? distanceMeters
        : null;
    final mph = secs == null
        ? null
        : paceMph(distanceMeters: distance, durationSeconds: secs);
    final group = table.groupOf(activityCode);

    MetActivity entry = activity;
    var fromPace = false;
    final chosen = entryCode == null ? null : table.byCode(entryCode);
    if (entryCode != null && chosen == null) {
      throw const CardioRefused(CardioProblem.noActivity);
    }
    if (chosen != null) {
      entry = chosen;
    } else if (group != null) {
      if (mph != null) {
        entry =
            group.bands[pickBand([
              for (final b in group.bands) (min: b.minMph, max: b.maxMph),
            ], mph)];
        fromPace = true;
      } else {
        final current = currentEntryCode == null
            ? null
            : table.byCode(currentEntryCode);
        entry =
            (current != null && group.contains(current.code)
                ? current
                : null) ??
            await _lastEntry(table, group, exceptId) ??
            group.general;
      }
    }

    final weight = await weightOnOrBefore(localDate);
    return CardioPreview(
      entry: entry,
      group: group,
      mph: mph,
      fromPace: fromPace,
      weightKg: weight?.weightKg,
      kcal: secs == null || weight == null
          ? null
          : cardioKcal(
              met: entry.met,
              bodyWeightKg: weight.weightKg,
              durationSeconds: secs,
            ),
    );
  }

  /// The entry of the most recent session of [group] that has a code in the
  /// group. Deleted sessions and sessions with no code are skipped; the source
  /// does not matter.
  Future<MetActivity?> _lastEntry(
    MetTable table,
    MetGroup group,
    int? exceptId,
  ) async {
    final codes = [group.general.code, for (final b in group.bands) b.code];
    final row =
        await (select(cardioSessions)
              ..where(
                (c) =>
                    c.activityCode.isIn(codes) &
                    c.deletedAtMs.isNull() &
                    (exceptId == null
                        ? const Constant(true)
                        : c.id.equals(exceptId).not()),
              )
              ..orderBy([
                (c) => OrderingTerm.desc(c.startedAtMs),
                (c) => OrderingTerm.desc(c.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    final code = row?.activityCode;
    return code == null ? null : table.byCode(code);
  }

  /// The entry used last time for the activity [activityCode] belongs to, or
  /// null (an Other row, an unknown code, or no session yet). The screen shows
  /// it when there is no distance.
  Future<MetActivity?> lastEntryFor(MetTable table, String activityCode) async {
    final group = table.groupOf(activityCode);
    return group == null ? null : _lastEntry(table, group, null);
  }

  // Saving

  void _checkNumbers({
    required int durationSeconds,
    double? distanceMeters,
    double? kcalOverride,
  }) {
    if (durationSeconds <= 0) {
      throw const CardioRefused(CardioProblem.badDuration);
    }
    final d = distanceMeters;
    if (d != null && !(d.isFinite && d >= 0)) {
      throw const CardioRefused(CardioProblem.badDistance);
    }
    final k = kcalOverride;
    if (k != null && !(k.isFinite && k >= 0)) {
      throw const CardioRefused(CardioProblem.badNumber);
    }
  }

  /// Saves a session that started at [at] (its local day and offset are
  /// stored as they were then). Returns the row read back. Throws
  /// [CardioRefused] for no activity or an unknown code, a duration of zero or
  /// less, a negative or non-finite distance or override; nothing is written
  /// then. The estimate is empty (null) when there is no weigh-in on or before
  /// the day; the override and the estimate are both stored.
  Future<CardioSession> saveCardio(
    MetTable table,
    CardioInput input,
    Now at,
  ) async {
    final code = input.activityCode;
    if (code == null) throw const CardioRefused(CardioProblem.noActivity);
    _checkNumbers(
      durationSeconds: input.durationSeconds,
      distanceMeters: input.distanceMeters,
      kcalOverride: input.kcalOverride,
    );
    return transaction(() async {
      final p = await cardioPreview(
        table,
        activityCode: code,
        entryCode: input.entryCode,
        durationSeconds: input.durationSeconds,
        distanceMeters: input.distanceMeters,
        localDate: at.localDate,
      );
      final id = await into(cardioSessions).insert(
        CardioSessionsCompanion.insert(
          localDate: at.localDate,
          startedAtMs: at.utcMs,
          tzOffsetMinutes: at.offsetMinutes,
          activityCode: Value(p.entry.code),
          activityName: _nameOf(p),
          met: Value(p.entry.met),
          durationSeconds: input.durationSeconds,
          distanceMeters: Value(_distanceOf(input)),
          avgHeartRate: Value(input.avgHeartRate),
          kcalEstimated: Value(p.kcal),
          kcalOverride: Value(input.kcalOverride),
        ),
      );
      return _row(id);
    });
  }

  /// Changes a session. [input] is everything the screen shows; [at], when
  /// given, moves the start (otherwise the day and time stay as stored,
  /// whatever the phone's zone is now). The source and source id stay.
  ///
  /// The estimate is worked out again from the new values (entry, duration,
  /// distance, the day's weigh-in) when any of them changed, and when there is
  /// none yet. When only the override, the heart rate or the time of day
  /// changed, the stored estimate stays as it was. With no [CardioInput
  /// .activityCode] the stored activity and MET stay, and without a MET the
  /// stored estimate stays. Throws [StateError] for a missing or deleted
  /// session, and [CardioRefused] as [saveCardio] does.
  Future<CardioSession> editCardio(
    int id,
    MetTable table,
    CardioInput input, {
    Now? at,
  }) async {
    _checkNumbers(
      durationSeconds: input.durationSeconds,
      distanceMeters: input.distanceMeters,
      kcalOverride: input.kcalOverride,
    );
    return transaction(() async {
      final old =
          await (select(cardioSessions)
                ..where((c) => c.id.equals(id) & c.deletedAtMs.isNull()))
              .getSingleOrNull();
      if (old == null) throw StateError('No such cardio session');
      final day = at?.localDate ?? old.localDate;
      final distance = _distanceOf(input);

      String? code = old.activityCode;
      String name = old.activityName;
      double? met = old.met;
      double? estimate = old.kcalEstimated;
      final inputCode = input.activityCode;
      var changed =
          input.durationSeconds != old.durationSeconds ||
          distance != old.distanceMeters ||
          day != old.localDate;
      if (inputCode != null) {
        final p = await cardioPreview(
          table,
          activityCode: inputCode,
          entryCode: input.entryCode,
          durationSeconds: input.durationSeconds,
          distanceMeters: input.distanceMeters,
          localDate: day,
          currentEntryCode: old.activityCode,
          exceptId: id,
        );
        changed = changed || p.entry.code != old.activityCode;
        code = p.entry.code;
        name = _nameOf(p);
        met = p.entry.met;
        if (changed || estimate == null) estimate = p.kcal;
      } else if (met != null && (changed || estimate == null)) {
        final w = await weightOnOrBefore(day);
        estimate = w == null
            ? null
            : cardioKcal(
                met: met,
                bodyWeightKg: w.weightKg,
                durationSeconds: input.durationSeconds,
              );
      }

      await (update(cardioSessions)..where((c) => c.id.equals(id))).write(
        CardioSessionsCompanion(
          localDate: Value(day),
          startedAtMs: at == null ? const Value.absent() : Value(at.utcMs),
          tzOffsetMinutes: at == null
              ? const Value.absent()
              : Value(at.offsetMinutes),
          activityCode: Value(code),
          activityName: Value(name),
          met: Value(met),
          durationSeconds: Value(input.durationSeconds),
          distanceMeters: Value(distance),
          avgHeartRate: Value(input.avgHeartRate),
          kcalEstimated: Value(estimate),
          kcalOverride: Value(input.kcalOverride),
        ),
      );
      return _row(id);
    });
  }

  String _nameOf(CardioPreview p) => p.group?.name ?? p.entry.description;

  double? _distanceOf(CardioInput input) {
    final d = input.distanceMeters;
    return d == null || d == 0 ? null : d;
  }

  // Delete and Undo

  /// Marks the session deleted at [now]. The row stays, so an import cannot
  /// bring it back. Throws [StateError] when there is no such session.
  Future<CardioSession> deleteCardio(int id, Now now) =>
      _setDeleted(id, now.utcMs);

  /// Clears the deleted mark.
  Future<CardioSession> undoDeleteCardio(int id) => _setDeleted(id, null);

  Future<CardioSession> _setDeleted(int id, int? deletedAtMs) async {
    final changed =
        await (update(cardioSessions)..where((c) => c.id.equals(id))).write(
          CardioSessionsCompanion(deletedAtMs: Value(deletedAtMs)),
        );
    if (changed == 0) throw StateError('No such cardio session');
    return _row(id);
  }

  // Reading

  /// The day's sessions that are not deleted, earliest start first.
  Future<List<CardioSession>> cardioForDay(String localDate) =>
      (select(cardioSessions)
            ..where(
              (c) => c.localDate.equals(localDate) & c.deletedAtMs.isNull(),
            )
            ..orderBy([
              (c) => OrderingTerm.asc(c.startedAtMs),
              (c) => OrderingTerm.asc(c.id),
            ]))
          .get();

  /// The day's sessions again after every change to cardio.
  Stream<List<CardioSession>> watchCardioForDay(String localDate) =>
      liveQuery(this, [cardioSessions], () => cardioForDay(localDate));

  /// Up to 3 activities, most recent first, one per activity: Running,
  /// Walking and Bicycling count once each, an Other row by its code. Deleted
  /// sessions, sessions with no code, and sessions whose code is not in the
  /// table are skipped. Each carries the entry used last time.
  Future<List<RecentActivity>> recentActivities(MetTable table) async {
    final rows =
        await (select(cardioSessions)
              ..where(
                (c) => c.deletedAtMs.isNull() & c.activityCode.isNotNull(),
              )
              ..orderBy([
                (c) => OrderingTerm.desc(c.startedAtMs),
                (c) => OrderingTerm.desc(c.id),
              ]))
            .get();
    final out = <RecentActivity>[];
    final seen = <String>{};
    for (final r in rows) {
      final entry = table.byCode(r.activityCode!);
      if (entry == null) continue;
      final group = table.groupOf(entry.code);
      if (!seen.add(group?.name ?? entry.code)) continue;
      out.add(
        RecentActivity(
          name: group?.name ?? entry.description,
          group: group,
          entry: entry,
        ),
      );
      if (out.length == 3) break;
    }
    return out;
  }

  Stream<List<RecentActivity>> watchRecentActivities(MetTable table) =>
      liveQuery(this, [cardioSessions], () => recentActivities(table));
}
