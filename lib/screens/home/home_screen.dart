// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/settings_data.dart';
import '../../data/weight_data.dart';
import '../../math/weight_trend.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';
import '../weight/weight_sheet.dart';

/// The Today tab. This step has the date, the weight row and the bottom
/// action bar. The budget card and meals come in later steps.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.today,
    required this.onOpenWeightTab,
  });

  /// Today's date from the clock. The shell computes it on every redraw.
  final String today;

  /// Tapping the weight row opens the Weight tab.
  final VoidCallback onOpenWeightTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  static const _bannerTime = Duration(seconds: 10);

  Stream<List<WeightEntry>>? _weights;
  Stream<List<TrendPoint>>? _trend;
  Stream<UnitSystem>? _units;

  SavedWeight? _saved;
  bool _undoFailed = false;
  Timer? _bannerTimer;
  bool _sheetOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weights == null) {
      final db = AppScope.of(context).db;
      _weights = db.watchWeights();
      _trend = db.watchTrend();
      _units = db.watchUnits();
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  /// Opens the weight sheet and shows the confirmation bar after a save.
  /// The + Weight button and the widget link both come here.
  Future<void> openWeightSheet() async {
    // A second tap while the sheet is opening or open does nothing.
    if (_sheetOpen) return;
    _sheetOpen = true;
    SavedWeight? saved;
    try {
      saved = await showWeightSheet(context);
    } finally {
      _sheetOpen = false;
    }
    if (saved == null || !mounted) return;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(_bannerTime, _hideBanner);
    setState(() {
      _saved = saved;
      _undoFailed = false;
    });
  }

  void _hideBanner() {
    if (mounted) setState(() => _saved = null);
  }

  Future<void> _undo() async {
    final saved = _saved;
    if (saved == null) return;
    final scope = AppScope.of(context);
    try {
      await scope.db.deleteWeight(saved.row.id, scope.clock());
      if (!mounted) return;
      _bannerTimer?.cancel();
      setState(() => _saved = null);
    } catch (_) {
      // Includes a missing row. The weight stays saved, and the banner says so.
      if (!mounted) return;
      setState(() => _undoFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.today;
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(
                    header: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.homeToday, style: theme.textTheme.headlineSmall),
                        Text(S.dateLong(today)),
                      ],
                    ),
                  ),
                ),
                _WeightRow(
                  weights: _weights!,
                  trend: _trend!,
                  units: _units!,
                  today: today,
                  onTap: widget.onOpenWeightTab,
                ),
              ],
            ),
          ),
        ),
        if (_saved != null)
          Material(
            color: theme.colorScheme.secondaryContainer,
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _undoFailed ? S.undoFailed : _savedMessage(today),
                          ),
                        ),
                      ),
                    ),
                    if (!_undoFailed)
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _undo,
                        child: const Text(S.undo),
                      ),
                  ],
                ),
              ),
            ),
          ),
        Material(
          color: theme.colorScheme.surfaceContainer,
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: null,
                      style: _barButton,
                      child: Text(S.addFood),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      style: _barButton,
                      onPressed: openWeightSheet,
                      child: const Text(S.addWeight),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: FilledButton.tonal(
                      onPressed: null,
                      style: _barButton,
                      child: Text(S.addCardio),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Built from the stored row that saveWeight returned, not from the text.
  String _savedMessage(String today) {
    final s = _saved!;
    final minute = minuteOfDayOf(s.row.measuredAtMs, s.row.tzOffsetMinutes);
    return S.weightSaved(
      formatWeight(s.row.weightKg, s.units),
      S.unitWord(s.units),
      S.whenInSentence(s.row.localDate, minute, today),
    );
  }
}

const _barButton = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(48, 56)),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
);

class _WeightRow extends StatelessWidget {
  const _WeightRow({
    required this.weights,
    required this.trend,
    required this.units,
    required this.today,
    required this.onTap,
  });

  final Stream<List<WeightEntry>> weights;
  final Stream<List<TrendPoint>> trend;
  final Stream<UnitSystem> units;
  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<UnitSystem>(
      stream: units,
      builder: (context, unitsSnap) {
        // Draw nothing until the units are known, so a metric user never
        // sees pounds for a frame.
        if (!unitsSnap.hasData) return const SizedBox.shrink();
        final u = unitsSnap.data!;
        return StreamBuilder<List<WeightEntry>>(
          stream: weights,
          builder: (context, weightsSnap) {
            if (!weightsSnap.hasData) return const SizedBox.shrink();
            final rows = weightsSnap.data!;
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.homeWeightLabel,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (rows.isEmpty)
                          const Text(S.homeNoWeight)
                        else ...[
                          Text(
                            '${formatWeight(rows.first.weightKg, u)} '
                            '${S.unitWord(u)}',
                            style: theme.textTheme.headlineSmall,
                          ),
                          StreamBuilder<List<TrendPoint>>(
                            stream: trend,
                            builder: (context, trendSnap) {
                              final points = trendSnap.data;
                              if (points == null || points.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                S.homeTrend(
                                  formatWeight(points.last.trendKg, u),
                                  S.unitWord(u),
                                ),
                              );
                            },
                          ),
                          Text(
                            S.whenAsLabel(
                              rows.first.localDate,
                              minuteOfDayOf(
                                rows.first.measuredAtMs,
                                rows.first.tzOffsetMinutes,
                              ),
                              today,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
