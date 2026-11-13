// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../clock.dart';
import '../../data/database.dart';
import '../../data/settings_data.dart';
import '../../data/weight_data.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';

/// What the sheet hands back when it closes after a save: the stored row,
/// read back from the database, and the units it was typed in.
typedef SavedWeight = ({WeightEntry row, UnitSystem units});

/// What the edit sheet hands back after a write: the stored row read back, the
/// units shown, and whether the write was a delete.
typedef EditedWeight = ({WeightEntry row, UnitSystem units, bool deleted});

/// The UTC offset in minutes that applies at a picked local date and time.
typedef OffsetAt = int Function(DateTime local);

int systemOffsetAt(DateTime local) => local.timeZoneOffset.inMinutes;

/// Opens the weight sheet over the current screen. Completes with the saved
/// weight, or null if the sheet was closed without saving. [offsetAt] is
/// replaceable so tests can pick any time zone.
Future<SavedWeight?> showWeightSheet(
  BuildContext context, {
  OffsetAt offsetAt = systemOffsetAt,
}) async {
  if (weightSheetOpen) return null;
  final token = _openToken = Object();
  try {
    final scope = AppScope.of(context);
    var units = UnitSystem.imperial;
    WeightEntry? last;
    try {
      units = await scope.db.getUnits();
      last = await scope.db.latestWeight();
    } catch (_) {
      // The sheet still opens. Saving will say if the database is not working.
    }
    if (!context.mounted) return null;
    return await _present<SavedWeight>(
      context,
      WeightSheet(
        db: scope.db,
        clock: scope.clock,
        units: units,
        last: last,
        offsetAt: offsetAt,
        token: token,
      ),
    );
  } finally {
    _release(token);
  }
}

/// Set from the request until the sheet closes, so only one weight sheet is
/// ever open, whichever screen or widget link asked for it. Each request owns
/// its own token, and only the owner clears it: a sheet that finishes closing
/// late cannot clear the flag of the sheet that replaced it. The sheet also
/// releases it when it is removed from the tree.
Object? _openToken;

/// True while a weight sheet is being opened or is open.
bool get weightSheetOpen => _openToken != null;

void _release(Object? token) {
  if (token != null && identical(_openToken, token)) _openToken = null;
}

/// Opens the sheet on an existing weigh-in. Completes with the stored row after
/// a save or a delete, or null if the sheet was closed without either.
Future<EditedWeight?> showEditWeightSheet(
  BuildContext context,
  WeightEntry row,
  UnitSystem units, {
  OffsetAt offsetAt = systemOffsetAt,
}) async {
  if (weightSheetOpen) return null;
  final token = _openToken = Object();
  try {
    final scope = AppScope.of(context);
    return await _present<EditedWeight>(
      context,
      WeightSheet(
        db: scope.db,
        clock: scope.clock,
        units: units,
        editing: row,
        offsetAt: offsetAt,
        token: token,
      ),
    );
  } finally {
    _release(token);
  }
}

Future<T?> _present<T>(BuildContext context, WeightSheet sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // A drag calls Navigator.pop directly, so it would close the sheet while
    // a save is in flight. PopScope in the sheet covers back and the scrim.
    enableDrag: false,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => sheet,
  );
}

enum _Check { ok, missing, notNumber, outOfRange }

final _digits = RegExp(r'^(\d+[.,]?\d*|[.,]\d+)$');

class WeightSheet extends StatefulWidget {
  const WeightSheet({
    super.key,
    required this.db,
    required this.clock,
    required this.units,
    this.last,
    this.editing,
    this.offsetAt = systemOffsetAt,
    this.token,
  });

  /// The request that opened this sheet, released when the sheet is disposed.
  final Object? token;

  final AppDatabase db;
  final Clock clock;
  final UnitSystem units;

  /// The newest weigh-in, or null if there is none. Used when adding.
  final WeightEntry? last;

  /// The weigh-in being edited, or null when adding a new one.
  final WeightEntry? editing;
  final OffsetAt offsetAt;

  @override
  State<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<WeightSheet> with WidgetsBindingObserver {
  late final TextEditingController _text;

  /// When the sheet was opened, or when the app last came back with nothing
  /// picked. Its label shows this time and Save stores it.
  late Now _opened;

  /// The date and time picked, or null for "now" (adding) or "as stored"
  /// (editing).
  Now? _at;
  bool _saving = false;
  bool _failed = false;
  bool _deleteFailed = false;
  bool _gone = false;
  bool _futureTime = false;

  WeightEntry? get _row => widget.editing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _opened = widget.clock();
    final row = _row;
    final source = row ?? widget.last;
    final start = source == null
        ? ''
        : formatWeight(source.weightKg, widget.units);
    _text = TextEditingController(text: start)
      ..selection = TextSelection(baseOffset: 0, extentOffset: start.length);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release(widget.token);
    _text.dispose();
    super.dispose();
  }

  /// A sheet left open while the phone was away would keep the old time.
  /// Move "now" to the present unless a time was picked or a save is running.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_row != null || _at != null || _saving) return;
    setState(() => _opened = widget.clock());
  }

  /// The date and time the sheet shows right now.
  Now get _current {
    final picked = _at;
    if (picked != null) return picked;
    final row = _row;
    if (row == null) return _opened;
    return Now.fromLocal(
      row.localDate,
      minuteOfDayOf(row.measuredAtMs, row.tzOffsetMinutes),
      row.tzOffsetMinutes,
    );
  }

  _Check get _check {
    final t = _text.text.trim();
    if (t.isEmpty) return _Check.missing;
    if (!_digits.hasMatch(t)) return _Check.notNumber;
    // parseWeight is null for a huge number too, which is out of range.
    final v = parseWeight(t);
    if (v == null || !weightInRange(v, widget.units)) {
      return _Check.outOfRange;
    }
    return _Check.ok;
  }

  Future<void> _save() async {
    if (_saving || _gone || _check != _Check.ok) return;
    final value = parseWeight(_text.text)!;
    setState(() {
      _saving = true;
      _failed = false;
      _deleteFailed = false;
    });
    try {
      final row = _row;
      if (row == null) {
        final saved = await widget.db.saveWeight(
          value,
          widget.units,
          widget.clock(),
          // The time the sheet showed is the time saved.
          at: _at ?? _opened,
        );
        if (!mounted) return;
        Navigator.of(context)
            .pop<SavedWeight>((row: saved, units: widget.units));
      } else {
        final saved = await widget.db.editWeight(
          row.id,
          value,
          widget.units,
          widget.clock(),
          at: _at,
        );
        if (!mounted) return;
        Navigator.of(
          context,
        ).pop<EditedWeight>((row: saved, units: widget.units, deleted: false));
      }
    } on StateError {
      // The row was deleted or removed while the sheet was open.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _gone = true;
      });
    } catch (_) {
      // Any other failure (a full disk, a closed database): stay open, keep
      // the number, say so.
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
      final deleted = await widget.db.deleteWeight(row.id, widget.clock());
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop<EditedWeight>((row: deleted, units: widget.units, deleted: true));
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

  DateTime get _firstDate => DateTime(2000);

  Future<DateTime?> _askDate(Now cur) {
    final day = parseDate(cur.localDate);
    final today = parseDate(_opened.localDate);
    var initial = DateTime(day.year, day.month, day.day);
    final last = DateTime(today.year, today.month, today.day);
    if (initial.isBefore(_firstDate)) initial = _firstDate;
    // A row can be dated after today (after travelling west).
    if (initial.isAfter(last)) initial = last;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _firstDate,
      lastDate: last,
    );
  }

  Future<TimeOfDay?> _askTime(Now cur) => showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: cur.minuteOfDay ~/ 60,
      minute: cur.minuteOfDay % 60,
    ),
  );

  /// Takes a picked day and time of day. A time that has not happened yet is
  /// refused: the earlier value stays and the sheet says so.
  void _apply(DateTime date, int minuteOfDay) {
    final local = DateTime(
      date.year,
      date.month,
      date.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    final picked = Now.fromLocal(
      formatDate(DateTime.utc(date.year, date.month, date.day)),
      minuteOfDay,
      widget.offsetAt(local),
    );
    setState(() {
      if (picked.utcMs > widget.clock().utcMs) {
        _futureTime = true;
      } else {
        _at = picked;
      }
    });
  }

  /// Adding: the date, then the time.
  Future<void> _change() async {
    setState(() => _futureTime = false);
    final cur = _current;
    final date = await _askDate(cur);
    if (date == null || !mounted) return;
    final time = await _askTime(cur);
    if (time == null || !mounted) return;
    _apply(date, time.hour * 60 + time.minute);
  }

  /// Editing: the date alone.
  Future<void> _changeDate() async {
    setState(() => _futureTime = false);
    final cur = _current;
    final date = await _askDate(cur);
    if (date == null || !mounted) return;
    _apply(date, cur.minuteOfDay);
  }

  /// Editing: the time alone.
  Future<void> _changeTime() async {
    setState(() => _futureTime = false);
    final cur = _current;
    final time = await _askTime(cur);
    if (time == null || !mounted) return;
    final day = parseDate(cur.localDate);
    _apply(day, time.hour * 60 + time.minute);
  }

  String _when(String date, int minute) =>
      S.whenInSentence(date, minute, _opened.localDate);

  Widget _pickerField(String label, String value, VoidCallback? onTap) {
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            child: Text(value),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = S.unitWord(widget.units);
    final check = _check;
    final at = _current;
    final last = widget.last;
    final row = _row;
    final editing = row != null;
    final reason = switch (check) {
      _Check.ok => null,
      _Check.missing => S.weightMissing,
      _Check.notNumber => S.weightNotNumber(widget.units),
      _Check.outOfRange => S.weightOutOfRange(widget.units),
    };
    final canSave = check == _Check.ok && !_saving && !_gone;

    final field = Semantics(
      label: S.weightField,
      child: TextField(
        controller: _text,
        autofocus: !editing,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        style: theme.textTheme.headlineSmall,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onChanged: (_) => setState(() {
          _failed = false;
          _deleteFailed = false;
        }),
        onSubmitted: (_) => _save(),
      ),
    );
    final unitText = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(unit, style: theme.textTheme.titleMedium),
    );

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (editing)
                Semantics(
                  header: true,
                  child: Text(
                    S.editWeightTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              S.weightTitle,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            S.whenAsLabel(
                              at.localDate,
                              at.minuteOfDay,
                              _opened.localDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _saving ? null : _change,
                      child: const Text(S.change),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (editing) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: field),
                    unitText,
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _pickerField(
                        S.dateField,
                        S.dayShort(at.localDate, _opened.localDate),
                        _saving ? null : _changeDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerField(
                        S.timeField,
                        S.timeOfDay(at.minuteOfDay),
                        _saving ? null : _changeTime,
                      ),
                    ),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: field),
                    unitText,
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 56),
                      ),
                      onPressed: canSave ? _save : null,
                      child: const Text(S.save),
                    ),
                  ],
                ),
              if (_futureTime)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: const Text(S.timeInFuture),
                  ),
                ),
              if (reason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(liveRegion: true, child: Text(reason)),
                ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      S.saveFailed(_text.text.trim(), unit),
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (_deleteFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      S.deleteFailed,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (_gone)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      S.weighInGone,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (editing) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    S.enteredNote(
                      row.source,
                      '${S.monthDay(localDateOf(row.createdAtMs, row.tzOffsetMinutes), _opened.localDate)}, '
                      '${S.timeOfDay(minuteOfDayOf(row.createdAtMs, row.tzOffsetMinutes))}',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 56),
                      ),
                      onPressed: (_saving || _gone) ? null : _delete,
                      child: const Text(S.delete),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 56),
                      ),
                      onPressed: canSave ? _save : null,
                      child: const Text(S.save),
                    ),
                  ],
                ),
              ] else if (last != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    S.lastWeight(
                      formatWeight(last.weightKg, widget.units),
                      unit,
                      _when(
                        last.localDate,
                        minuteOfDayOf(last.measuredAtMs, last.tzOffsetMinutes),
                      ),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
