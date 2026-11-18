// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../clock.dart';
import '../../data/cardio_data.dart';
import '../../data/database.dart';
import '../../data/met_table.dart';
import '../../data/settings_data.dart';
import '../../math/calorie_budget.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';
import '../weight/weight_sheet.dart' show OffsetAt, systemOffsetAt;
import 'activity_search.dart';

/// What the screen hands back when it closes after a write: the stored row,
/// read back from the database.
sealed class CardioResult {
  const CardioResult(this.row);

  final CardioSession row;
}

class CardioSaved extends CardioResult {
  const CardioSaved(super.row, {required this.edited});

  /// True for a change to an existing session (no Undo is offered for it).
  final bool edited;
}

class CardioDeleted extends CardioResult {
  const CardioDeleted(super.row);
}

bool _screenOpen = false;

/// Opens the cardio screen over the tab bar: a new session, or [editing] a
/// logged one. Completes when it closes, with what it wrote or null. A second
/// request while one is open does nothing.
Future<CardioResult?> openCardioScreen(
  BuildContext context, {
  CardioSession? editing,
  OffsetAt offsetAt = systemOffsetAt,
}) async {
  if (_screenOpen) return null;
  _screenOpen = true;
  try {
    return await Navigator.of(context, rootNavigator: true).push<CardioResult>(
      MaterialPageRoute(
        builder: (_) => CardioScreen(editing: editing, offsetAt: offsetAt),
      ),
    );
  } finally {
    _screenOpen = false;
  }
}

final _decimal = RegExp(r'^(\d+[.,]?\d*|[.,]\d+)$');

double? _parseDecimal(String text) {
  final t = text.trim();
  if (!_decimal.hasMatch(t)) return null;
  final v = double.tryParse(t.replaceAll(',', '.'));
  return v != null && v.isFinite ? v : null;
}

/// A number as typed back into a field: up to two decimals, no trailing zeros.
String _plain(double v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// What the preview of the entry and the estimate came to, for either a new
/// session or an edit.
class _Shown {
  const _Shown({
    required this.entry,
    required this.group,
    required this.mph,
    required this.fromPace,
    required this.inBand,
    required this.weightKg,
    required this.kcal,
    required this.kept,
  });

  final MetActivity? entry;
  final MetGroup? group;
  final double? mph;
  final bool fromPace;
  final bool inBand;
  final double? weightKg;
  final double? kcal;
  final bool kept;
}

/// The cardio screen (cardio.html frames 1 to 4): one screen to log a session,
/// or to edit one. Nothing is pushed on the way to Save.
class CardioScreen extends StatefulWidget {
  const CardioScreen({super.key, this.editing, this.offsetAt = systemOffsetAt});

  final CardioSession? editing;
  final OffsetAt offsetAt;

  @override
  State<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends State<CardioScreen>
    with WidgetsBindingObserver {
  late AppDatabase _db;
  late Clock _clock;
  var _started = false;

  MetTable? _table;
  var _loadFailed = false;
  var _units = UnitSystem.imperial;
  List<RecentActivity> _recents = const [];

  /// The activity picked: its code goes in [CardioInput.activityCode].
  MetActivity? _activity;

  /// Editing: true once the user picked another activity than the stored one.
  var _activityChanged = false;

  /// The entry the user chose with Change, or null.
  MetActivity? _entryPick;

  final _duration = TextEditingController();
  final _distance = TextEditingController();
  final _heart = TextEditingController();
  final _kcal = TextEditingController();

  // What an edit was opened with. A field left as it was gives the stored
  // value back, never a number read from the rounded text.
  var _initDuration = '';
  var _initDistance = '';
  var _initKcal = '';

  late Now _opened;
  Now? _at;
  var _futureTime = false;

  _Shown? _shown;
  var _seq = 0;

  var _saving = false;
  var _failed = false;
  var _deleteFailed = false;
  var _gone = false;
  String? _problem;
  var _asking = false;

  CardioSession? get _row => widget.editing;
  bool get _editing => _row != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scope = AppScope.of(context);
    _db = scope.db;
    _clock = scope.clock;
    _opened = _clock();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _duration.dispose();
    _distance.dispose();
    _heart.dispose();
    _kcal.dispose();
    super.dispose();
  }

  /// A screen left open while the phone was away would keep the old time.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_editing || _at != null || _saving) return;
    setState(() => _opened = _clock());
    _refresh();
  }

  Future<void> _load() async {
    final MetTable table;
    try {
      table = await MetTable.load();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    var units = UnitSystem.imperial;
    var recents = const <RecentActivity>[];
    try {
      units = await _db.getUnits();
      recents = await _db.recentActivities(table);
    } catch (_) {
      // The screen still opens; saving says if the database is not working.
    }
    if (!mounted) return;
    setState(() {
      _table = table;
      _units = units;
      _recents = recents;
      final row = _row;
      if (row == null) {
        _activity = recents.isEmpty ? null : recents.first.entry;
      } else {
        final code = row.activityCode;
        _activity = code == null ? null : table.byCode(code);
        _initDuration = '${(row.durationSeconds / 60).round()}';
        _duration.text = _initDuration;
        final d = row.distanceMeters;
        if (d != null) {
          _initDistance = S.cardioDistanceField(d, units);
          _distance.text = _initDistance;
        }
        final hr = row.avgHeartRate;
        if (hr != null) _heart.text = '$hr';
        final own = row.kcalOverride;
        if (own != null) {
          _initKcal = _plain(own);
          _kcal.text = _initKcal;
        }
      }
    });
    _refresh();
  }

  // What is typed

  int? get _secondsOrNull {
    final t = _duration.text.trim();
    final row = _row;
    if (row != null && t == _initDuration && t.isNotEmpty) {
      return row.durationSeconds > 0 ? row.durationSeconds : null;
    }
    final m = int.tryParse(t);
    return m == null || m <= 0 ? null : m * 60;
  }

  /// The distance in meters: null when empty or not a number. Left as it was
  /// opened, an edit gives back the stored meters.
  double? get _meters {
    final t = _distance.text.trim();
    final row = _row;
    if (row != null && t == _initDistance) return row.distanceMeters;
    final v = _parseDecimal(t);
    if (v == null) return null;
    return _units == UnitSystem.imperial ? milesToMeters(v) : kmToMeters(v);
  }

  double? get _override {
    final t = _kcal.text.trim();
    final row = _row;
    if (row != null && t == _initKcal && t.isNotEmpty) return row.kcalOverride;
    return _parseDecimal(t);
  }

  int? get _heartRate => int.tryParse(_heart.text.trim());

  String? get _durationProblem {
    final t = _duration.text.trim();
    if (t.isEmpty) return null;
    final m = int.tryParse(t);
    return m == null || m <= 0 ? S.cardioDurationBad : null;
  }

  String? get _distanceProblem {
    final t = _distance.text.trim();
    return t.isEmpty || _parseDecimal(t) != null ? null : S.cardioDistanceBad;
  }

  String? get _heartProblem {
    final t = _heart.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    return v == null || v <= 0 ? S.cardioHeartBad : null;
  }

  String? get _kcalProblem {
    final t = _kcal.text.trim();
    return t.isEmpty || _parseDecimal(t) != null ? null : S.cardioKcalBad;
  }

  bool get _canSave =>
      !_saving &&
      !_gone &&
      _table != null &&
      (_editing || _activity != null) &&
      _secondsOrNull != null &&
      _durationProblem == null &&
      _distanceProblem == null &&
      _heartProblem == null &&
      _kcalProblem == null;

  /// The day the session is on: the picked one, else today (new) or the
  /// stored one (edit).
  String get _day => _at?.localDate ?? _row?.localDate ?? _opened.localDate;

  // The input

  CardioInput _input(int seconds) {
    final row = _row;
    if (row == null) {
      return CardioInput(
        activityCode: _activity?.code,
        entryCode: _entryPick?.code,
        durationSeconds: seconds,
        distanceMeters: _meters,
        avgHeartRate: _heartRate,
        kcalOverride: _override,
      );
    }
    final meters = _meters;
    final code = _activityChanged ? _activity?.code : row.activityCode;
    // Keep the stored entry unless the pace or another activity could change
    // it, or the user picked one.
    final paceChanged =
        seconds != row.durationSeconds ||
        (meters == 0 ? null : meters) != row.distanceMeters;
    final entry =
        _entryPick?.code ??
        (_activityChanged || paceChanged ? null : row.activityCode);
    return CardioInput(
      activityCode: code,
      entryCode: entry,
      durationSeconds: seconds,
      distanceMeters: meters,
      avgHeartRate: _heartRate,
      kcalOverride: _override,
    );
  }

  Future<void> _refresh() async {
    final table = _table;
    if (table == null || _gone) return;
    final row = _row;
    if (row == null && _activity == null) {
      if (_shown != null) setState(() => _shown = null);
      return;
    }
    final seq = ++_seq;
    final seconds = _secondsOrNull;
    _Shown? shown;
    try {
      if (row == null) {
        final p = await _db.cardioPreview(
          table,
          activityCode: _activity!.code,
          entryCode: _entryPick?.code,
          durationSeconds: seconds,
          distanceMeters: _meters,
          localDate: _day,
        );
        shown = _Shown(
          entry: p.entry,
          group: p.group,
          mph: p.mph,
          fromPace: p.fromPace,
          inBand: p.inBand,
          weightKg: p.weightKg,
          kcal: p.kcal,
          kept: false,
        );
      } else {
        final p = await _db.editPreview(
          table,
          row.id,
          _input(seconds ?? 0),
          at: _at,
        );
        shown = _Shown(
          entry: p.entry,
          group: p.group,
          mph: p.mph,
          fromPace: p.fromPace,
          inBand: p.inBand,
          weightKg: p.weightKg,
          kcal: p.kcal,
          kept: p.keptStored,
        );
      }
    } on StateError {
      if (mounted && seq == _seq) setState(() => _gone = true);
      return;
    } catch (_) {
      // No preview: the estimate line says what is missing.
    }
    if (!mounted || seq != _seq) return;
    setState(() => _shown = shown);
  }

  void _changed() {
    setState(() {
      _failed = false;
      _deleteFailed = false;
      _problem = null;
    });
    _refresh();
  }

  // Choosing

  /// Running, Walking and Bicycling are each one activity, whichever of their
  /// entries is in use; an Other row is its own.
  bool _same(MetActivity? a, MetActivity? b) {
    final t = _table;
    if (a == null || b == null || t == null) return false;
    final ka = t.groupOf(a.code)?.name ?? a.code;
    final kb = t.groupOf(b.code)?.name ?? b.code;
    return ka == kb;
  }

  void _pick(MetActivity a) {
    if (_same(_activity, a)) return;
    setState(() {
      _activity = a;
      _activityChanged = true;
      _entryPick = null;
    });
    _changed();
  }

  Future<void> _other() async {
    final table = _table;
    if (table == null || _asking) return;
    _asking = true;
    try {
      final a = await showActivitySearch(context, table);
      if (a != null && mounted) _pick(a);
    } finally {
      _asking = false;
    }
  }

  Future<void> _changeEntry(MetGroup group, MetActivity? inUse) async {
    if (_asking) return;
    _asking = true;
    try {
      final entries = [group.general, ...group.bands];
      final a = await showModalBottomSheet<MetActivity>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 600),
        builder: (_) => _EntryList(
          title: S.cardioEntriesTitle(S.cardioName(group.name)),
          entries: entries,
          inUse: inUse?.code,
        ),
      );
      if (a == null || !mounted) return;
      setState(() => _entryPick = a);
      _changed();
    } finally {
      _asking = false;
    }
  }

  // Date and time

  Now get _current {
    final picked = _at;
    if (picked != null) return picked;
    final row = _row;
    if (row == null) return _opened;
    return Now.fromLocal(
      row.localDate,
      minuteOfDayOf(row.startedAtMs, row.tzOffsetMinutes),
      row.tzOffsetMinutes,
    );
  }

  Future<void> _changeTime() async {
    if (_asking) return;
    _asking = true;
    try {
      setState(() => _futureTime = false);
      final cur = _current;
      final day = parseDate(cur.localDate);
      final today = parseDate(_opened.localDate);
      var initial = DateTime(day.year, day.month, day.day);
      final last = DateTime(today.year, today.month, today.day);
      if (initial.isAfter(last)) initial = last;
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: last,
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: cur.minuteOfDay ~/ 60,
          minute: cur.minuteOfDay % 60,
        ),
      );
      if (time == null || !mounted) return;
      final minute = time.hour * 60 + time.minute;
      final local = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      final picked = Now.fromLocal(
        formatDate(DateTime.utc(date.year, date.month, date.day)),
        minute,
        widget.offsetAt(local),
      );
      if (picked.utcMs > _clock().utcMs) {
        setState(() => _futureTime = true);
        return;
      }
      setState(() => _at = picked);
      _changed();
    } finally {
      _asking = false;
    }
  }

  // Writing

  String _problemText(CardioProblem p) => switch (p) {
    CardioProblem.noActivity => S.cardioNeedActivity,
    CardioProblem.badDuration => S.cardioDurationBad,
    CardioProblem.badDistance => S.cardioDistanceBad,
    CardioProblem.badNumber => S.cardioHeartBad,
  };

  Future<void> _save() async {
    if (!_canSave) return;
    final seconds = _secondsOrNull!;
    final table = _table!;
    setState(() {
      _saving = true;
      _failed = false;
      _deleteFailed = false;
      _problem = null;
    });
    try {
      final row = _row;
      final CardioSession saved;
      if (row == null) {
        saved = await _db.saveCardio(table, _input(seconds), _at ?? _opened);
      } else {
        saved = await _db.editCardio(row.id, table, _input(seconds), at: _at);
      }
      if (!mounted) return;
      Navigator.of(context)
          .pop<CardioResult>(CardioSaved(saved, edited: row != null));
    } on CardioRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _problem = _problemText(e.problem);
      });
    } on StateError {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _gone = true;
      });
    } catch (_) {
      // A full disk, a closed database: stay open, keep what was typed.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  Future<void> _delete() async {
    final row = _row;
    if (row == null || _saving || _gone) return;
    setState(() {
      _saving = true;
      _failed = false;
      _deleteFailed = false;
    });
    try {
      final deleted = await _db.deleteCardio(row.id, _clock());
      if (!mounted) return;
      Navigator.of(context).pop<CardioResult>(CardioDeleted(deleted));
    } on StateError {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _gone = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _deleteFailed = true;
      });
    }
  }

  // Words

  String _kcalText(double v) => S.count(roundForDisplay(v));

  String _activityName() {
    final a = _activity;
    final t = _table;
    if (a == null || t == null) {
      final row = _row;
      return row == null ? '' : S.cardioName(row.activityName);
    }
    return S.cardioName(t.groupOf(a.code)?.name ?? a.description);
  }

  /// The lines under the chips: which Compendium entry is in use and why.
  List<String> _matchedLines() {
    final shown = _shown;
    if (shown == null) return const [];
    final entry = shown.entry;
    if (entry == null) {
      final met = _row?.met;
      return [
        met == null ? S.cardioNoEntry : S.cardioKeptMet(met.toStringAsFixed(1)),
      ];
    }
    final lines = [
      S.cardioMatched(entry.description, entry.code, entry.metText),
    ];
    final group = shown.group;
    if (group == null) return lines;
    final mph = shown.mph;
    if (_entryPick != null) {
      lines.add(S.cardioChosenEntry);
    } else if (shown.fromPace && mph != null) {
      final pace = S.cardioPace(mph, _units);
      lines.add(
        shown.inBand ? S.cardioPaceIn(pace) : S.cardioPaceNearest(pace),
      );
    } else {
      lines.add(
        entry.code == group.general.code
            ? S.cardioGeneralEntry
            : S.cardioUsedLastTime,
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final table = _table;
    final shown = _shown;
    final row = _row;
    final seconds = _secondsOrNull;
    final own = _override;
    final yours = own != null && _kcalProblem == null;
    final estimate = seconds == null ? null : shown?.kcal;
    final matched = _matchedLines();
    final at = _current;
    final source = row == null ? null : S.cardioSourceMark(row.source);

    // The calorie bar: always says which number will be used.
    String headline;
    String? sub;
    if (yours) {
      headline = S.cardioBarYours(_kcalText(own));
      if (estimate != null) sub = S.cardioEstimateWas(_kcalText(estimate));
    } else if (!_editing && _activity == null) {
      headline = S.cardioNeedActivity;
    } else if (seconds == null) {
      headline = S.cardioBarNeedsDuration;
    } else if (estimate != null) {
      headline = S.cardioBarEstimate(_kcalText(estimate));
      final met = shown?.entry?.metText ?? row?.met?.toStringAsFixed(1);
      final w = shown?.weightKg;
      if (!shown!.kept && met != null && w != null) {
        sub = S.cardioEstimateFrom(
          met,
          formatWeight(w, _units),
          S.unitWord(_units),
          (seconds / 60).round(),
        );
      }
    } else if (shown != null && shown.entry == null && row?.met == null) {
      headline = S.cardioNoEstimate;
    } else {
      headline = S.cardioNeedsWeighIn;
    }
    final chips = <Widget>[];
    if (table != null) {
      final listed = [for (final r in _recents) r.entry];
      final picked = _activity;
      if (picked != null && !listed.any((a) => _same(a, picked))) {
        listed.add(picked);
      }
      for (final a in listed) {
        final name = S.cardioName(table.groupOf(a.code)?.name ?? a.description);
        final on = _same(a, _activity);
        chips.add(
          Semantics(
            container: true,
            button: true,
            selected: on,
            label: S.cardioChipSpoken(name, on),
            excludeSemantics: true,
            child: ChoiceChip(
              label: Text(name),
              selected: on,
              onSelected: _saving ? null : (_) => _pick(a),
            ),
          ),
        );
      }
      chips.add(
        Semantics(
          container: true,
          button: true,
          label: S.cardioOtherSpoken,
          excludeSemantics: true,
          child: ActionChip(
            label: const Text(S.cardioOther),
            onPressed: _saving ? null : _other,
          ),
        ),
      );
    }

    final change = table == null || shown?.group == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving
                ? null
                : () => _changeEntry(shown!.group!, shown.entry),
            child: Semantics(
              label: S.cardioChangeEntrySpoken,
              excludeSemantics: true,
              child: const Text(S.change),
            ),
          );

    Widget field(
      TextEditingController c,
      String label,
      String unit, {
      String? error,
      String? hint,
      bool decimal = false,
      int maxLength = 6,
      bool last = false,
      bool focus = false,
    }) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          autofocus: focus,
          enabled: !_saving,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
            LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: InputDecoration(
            labelText: label,
            suffixText: unit,
            hintText: hint,
            errorText: error,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _changed(),
          onSubmitted: last ? (_) => _save() : null,
        ),
      );
    }

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (source != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(source, style: theme.textTheme.bodySmall),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                S.whenAsLabel(at.localDate, at.minuteOfDay, _opened.localDate),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _saving ? null : _changeTime,
              child: Semantics(
                label: S.cardioChangeTimeSpoken,
                excludeSemantics: true,
                child: const Text(S.change),
              ),
            ),
          ],
        ),
        if (_futureTime)
          Semantics(liveRegion: true, child: const Text(S.timeInFuture)),
        if (_loadFailed)
          Semantics(liveRegion: true, child: const Text(S.cardioLoadFailed)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: chips),
        const SizedBox(height: 8),
        if (_activity == null && !_editing && table != null)
          const Text(S.cardioPickPrompt)
        else if (table != null || _editing) ...[
          Text(
            _activityName(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(matched.join(' ')),
                ),
              ),
              ?change,
            ],
          ),
        ],
        field(
          _duration,
          S.cardioDuration,
          S.cardioMinUnit,
          error: _durationProblem,
          maxLength: 5,
          focus: !_editing,
        ),
        field(
          _distance,
          S.cardioDistance,
          S.distanceUnit(_units),
          error: _distanceProblem,
          decimal: true,
        ),
        field(
          _heart,
          S.cardioHeartRate,
          S.cardioBpm,
          error: _heartProblem,
          maxLength: 3,
        ),
        field(
          _kcal,
          S.cardioCalories,
          S.cardioKcalUnit,
          error: _kcalProblem,
          hint: estimate == null ? null : _kcalText(estimate),
          decimal: true,
          last: true,
        ),
        if (_problem != null) _message(_problem!, theme),
        if (_failed) _message(S.cardioFailed, theme),
        if (_deleteFailed) _message(S.cardioDeleteFailed, theme),
        if (_gone) _message(S.cardioGone, theme),
      ],
    );

    final bar = Material(
      color: theme.colorScheme.surfaceContainer,
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      liveRegion: true,
                      label: yours
                          ? S.cardioBarSpoken(_kcalText(own), true)
                          : estimate == null
                          ? headline
                          : S.cardioBarSpoken(_kcalText(estimate), false),
                      excludeSemantics: true,
                      child: Text(
                        headline,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (sub != null) Text(sub),
                    if (yours && estimate != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _saving
                            ? null
                            : () {
                                _kcal.clear();
                                _changed();
                              },
                        child: const Text(S.cardioUseEstimate),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 56)),
                onPressed: _canSave ? _save : null,
                child: const Text(S.save),
              ),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(S.cardioTitle),
          actions: [
            if (_editing)
              PopupMenuButton<void>(
                tooltip: S.cardioMenu,
                enabled: !_saving && !_gone,
                itemBuilder: (_) => [
                  PopupMenuItem<void>(
                    onTap: _delete,
                    child: const Text(S.delete),
                  ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: ContentWidth(child: body)),
            bar,
          ],
        ),
      ),
    );
  }

  Widget _message(String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

/// The group's entries, each with its MET, for Change (cardio.html frame 2).
class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.title,
    required this.entries,
    required this.inUse,
  });

  final String title;
  final List<MetActivity> entries;
  final String? inUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(S.cancel),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final e in entries)
                Semantics(
                  container: true,
                  button: true,
                  label:
                      '${S.cardioEntryRow(e.description, e.metText)}'
                      '${e.code == inUse ? ', ${S.cardioInUse}' : ''}',
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('entry-${e.code}'),
                    onTap: () => Navigator.of(context).pop(e),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.description,
                                style: e.code == inUse
                                    ? const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('MET ${e.metText}'),
                                if (e.code == inUse) const Text(S.cardioInUse),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
