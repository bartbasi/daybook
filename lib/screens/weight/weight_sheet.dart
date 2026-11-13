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

/// The UTC offset in minutes that applies at a picked local date and time.
typedef OffsetAt = int Function(DateTime local);

int _systemOffsetAt(DateTime local) => local.timeZoneOffset.inMinutes;

/// Opens the weight sheet over the current screen. Completes with the saved
/// weight, or null if the sheet was closed without saving. [offsetAt] is
/// replaceable so tests can pick any time zone.
Future<SavedWeight?> showWeightSheet(
  BuildContext context, {
  OffsetAt offsetAt = _systemOffsetAt,
}) async {
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
  return showModalBottomSheet<SavedWeight>(
    context: context,
    isScrollControlled: true,
    // A drag calls Navigator.pop directly, so it would close the sheet while
    // a save is in flight. PopScope in the sheet covers back and the scrim.
    enableDrag: false,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (_) => WeightSheet(
      db: scope.db,
      clock: scope.clock,
      units: units,
      last: last,
      offsetAt: offsetAt,
    ),
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
    required this.last,
    this.offsetAt = _systemOffsetAt,
  });

  final AppDatabase db;
  final Clock clock;
  final UnitSystem units;

  /// The newest weigh-in, or null if there is none.
  final WeightEntry? last;
  final OffsetAt offsetAt;

  @override
  State<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<WeightSheet> {
  late final TextEditingController _text;
  late final Now _opened;

  /// The date and time picked with Change, or null for "now".
  Now? _at;
  bool _saving = false;
  bool _failed = false;
  bool _futureTime = false;

  @override
  void initState() {
    super.initState();
    _opened = widget.clock();
    final last = widget.last;
    final start = last == null ? '' : formatWeight(last.weightKg, widget.units);
    _text = TextEditingController(text: start)
      ..selection = TextSelection(baseOffset: 0, extentOffset: start.length);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
    if (_saving || _check != _Check.ok) return;
    final value = parseWeight(_text.text)!;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final row = await widget.db.saveWeight(
        value,
        widget.units,
        widget.clock(),
        at: _at,
      );
      if (!mounted) return;
      Navigator.of(context).pop<SavedWeight>((row: row, units: widget.units));
    } catch (_) {
      // Any failure (a full disk, a closed database, a missing row): stay
      // open, keep the number, say so.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  Future<void> _change() async {
    setState(() => _futureTime = false);
    final cur = _at ?? _opened;
    final day = parseDate(cur.localDate);
    final today = parseDate(_opened.localDate);
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(day.year, day.month, day.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
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
    final local = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final picked = Now.fromLocal(
      formatDate(DateTime.utc(date.year, date.month, date.day)),
      time.hour * 60 + time.minute,
      widget.offsetAt(local),
    );
    setState(() {
      if (picked.utcMs > widget.clock().utcMs) {
        // Keep the earlier value and say so.
        _futureTime = true;
      } else {
        _at = picked;
      }
    });
  }

  String _when(String date, int minute) =>
      S.whenInSentence(date, minute, _opened.localDate);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = S.unitWord(widget.units);
    final check = _check;
    final at = _at ?? _opened;
    final last = widget.last;
    final reason = switch (check) {
      _Check.ok => null,
      _Check.missing => S.weightMissing,
      _Check.notNumber => S.weightNotNumber(widget.units),
      _Check.outOfRange => S.weightOutOfRange(widget.units),
    };

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Semantics(
                      label: S.weightField,
                      child: TextField(
                        controller: _text,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        style: theme.textTheme.headlineSmall,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _failed = false),
                        onSubmitted: (_) => _save(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(unit, style: theme.textTheme.titleMedium),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 56),
                    ),
                    onPressed: (check == _Check.ok && !_saving) ? _save : null,
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
              if (last != null)
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
