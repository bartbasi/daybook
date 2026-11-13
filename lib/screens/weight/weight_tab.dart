// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/settings_data.dart';
import '../../data/weight_data.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';
import 'weight_chart.dart';
import 'weight_sheet.dart';

/// The chart ranges. A null day count means every weigh-in.
enum WeightRange {
  month(30, S.range1Month),
  threeMonths(90, S.range3Months),
  year(365, S.range1Year),
  all(null, S.rangeAll);

  const WeightRange(this.days, this.label);

  final int? days;
  final String label;
}

/// The Weight tab: the trend number, the chart, range chips, and every
/// weigh-in newest first. Tap a row to edit it; delete is in the edit sheet.
class WeightTab extends StatefulWidget {
  const WeightTab({super.key, this.offsetAt = systemOffsetAt});

  /// Passed to the sheets, so tests can pick any time zone.
  final OffsetAt offsetAt;

  @override
  State<WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends State<WeightTab> {
  static const _snackTime = Duration(seconds: 10);

  Stream<List<WeightEntry>>? _weights;
  Stream<UnitSystem>? _units;
  WeightRange _range = WeightRange.month;
  bool _sheetOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weights == null) {
      final db = AppScope.of(context).db;
      _weights = db.watchWeights();
      _units = db.watchUnits();
    }
  }

  void _say(String text, {String? action, VoidCallback? onAction}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: _snackTime,
        action: action == null
            ? null
            : SnackBarAction(label: action, onPressed: onAction!),
      ),
    );
  }

  String _savedMessage(WeightEntry row, UnitSystem units, String today) {
    final minute = minuteOfDayOf(row.measuredAtMs, row.tzOffsetMinutes);
    return S.weightSaved(
      formatWeight(row.weightKg, units),
      S.unitWord(units),
      S.whenInSentence(row.localDate, minute, today),
    );
  }

  Future<void> _log() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    SavedWeight? saved;
    try {
      saved = await showWeightSheet(context, offsetAt: widget.offsetAt);
    } finally {
      _sheetOpen = false;
    }
    if (saved == null || !mounted) return;
    final scope = AppScope.of(context);
    final row = saved.row;
    // Built from the stored row, with Undo as on Home.
    _say(
      _savedMessage(row, saved.units, scope.clock().localDate),
      action: S.undo,
      onAction: () async {
        try {
          await scope.db.deleteWeight(row.id, scope.clock());
        } catch (_) {
          // Includes StateError for a row that is gone.
          if (mounted) _say(S.undoFailed);
        }
      },
    );
  }

  Future<void> _edit(WeightEntry row, UnitSystem units) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    EditedWeight? result;
    try {
      result = await showEditWeightSheet(
        context,
        row,
        units,
        offsetAt: widget.offsetAt,
      );
    } finally {
      _sheetOpen = false;
    }
    if (result == null || !mounted) return;
    final scope = AppScope.of(context);
    final stored = result.row;
    if (!result.deleted) {
      _say(_savedMessage(stored, result.units, scope.clock().localDate));
      return;
    }
    _say(
      S.weightDeleted(
        formatWeight(stored.weightKg, result.units),
        S.unitWord(result.units),
        S.dayShort(stored.localDate, scope.clock().localDate),
      ),
      action: S.undo,
      onAction: () async {
        try {
          await scope.db.undoDeleteWeight(stored.id, scope.clock());
        } catch (_) {
          if (mounted) _say(S.undoDeleteFailed);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = AppScope.of(context).clock().localDate;
    return ContentWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      S.tabWeight,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _log,
                  child: const Text(S.logWeight),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<UnitSystem>(
              stream: _units,
              builder: (context, unitsSnap) {
                // Draw nothing until the units are known, so a metric user
                // never sees pounds for a frame.
                if (!unitsSnap.hasData) return const SizedBox.shrink();
                final units = unitsSnap.data!;
                return StreamBuilder<List<WeightEntry>>(
                  stream: _weights,
                  builder: (context, weightsSnap) {
                    if (!weightsSnap.hasData) return const SizedBox.shrink();
                    return _body(context, weightsSnap.data!, units, today);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<WeightEntry> rows,
    UnitSystem units,
    String today,
  ) {
    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [Text(S.noWeighIns)],
      );
    }
    final theme = Theme.of(context);
    final unit = S.unitWord(units);
    final data = buildChartData(
      rows: rows,
      today: today,
      rangeDays: _range.days,
      units: units,
    )!;
    final trendNow = data.trend.last.value;
    final days = data.trend.length;
    String? change;
    if (days >= 2) {
      final diff = roundToTenth(trendNow - data.trend.first.value);
      change = diff == 0
          ? S.trendSame(days)
          : S.trendChange(
              diff < 0 ? S.trendDown : S.trendUp,
              diff.abs().toStringAsFixed(1),
              unit,
              days,
            );
    }

    final head = <Widget>[
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 8,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trendNow.toStringAsFixed(1)} $unit',
                  style: theme.textTheme.headlineMedium,
                ),
                const Text(S.trendToday),
              ],
            ),
          ),
          if (change != null) Text(change, textAlign: TextAlign.end),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final r in WeightRange.values)
            ChoiceChip(
              label: Text(r.label),
              selected: r == _range,
              showCheckmark: true,
              onSelected: (_) => setState(() => _range = r),
            ),
        ],
      ),
      const SizedBox(height: 8),
      WeightChart(data: data, today: today),
      Text(S.chartKey, style: theme.textTheme.bodySmall),
      const SizedBox(height: 16),
      Semantics(
        header: true,
        child: Text(S.weighIns, style: theme.textTheme.titleMedium),
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: head.length + rows.length,
      itemBuilder: (context, i) {
        if (i < head.length) return head[i];
        final row = rows[i - head.length];
        return _WeighInTile(
          row: row,
          units: units,
          today: today,
          onTap: () => _edit(row, units),
        );
      },
    );
  }
}

class _WeighInTile extends StatelessWidget {
  const _WeighInTile({
    required this.row,
    required this.units,
    required this.today,
    required this.onTap,
  });

  final WeightEntry row;
  final UnitSystem units;
  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = switch (row.source) {
      'health_connect' => S.fromHealthConnect,
      'apple_health' => S.fromAppleHealth,
      _ => null,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      onTap: onTap,
      title: Text(
        '${formatWeight(row.weightKg, units)} ${S.unitWord(units)}',
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.weighInWhen(
              row.localDate,
              minuteOfDayOf(row.measuredAtMs, row.tzOffsetMinutes),
              today,
            ),
          ),
          if (source != null) Text(source),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
