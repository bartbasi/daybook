// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/food_data.dart';
import '../../data/nutrients.dart';
import '../../data/settings_data.dart';
import '../../data/weight_data.dart';
import '../../math/weight_trend.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';
import '../food/confirm_bar.dart';
import '../food/food_entry_screen.dart';
import '../weight/weight_sheet.dart';

/// The Today tab: the date, the meals, the weight row and the bottom action
/// bar. The budget card and the exercise rows come in later steps.
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
  Stream<List<MealSlot>>? _slots;
  Stream<DayLog>? _day;
  String? _dayFor;

  // The one message above the action bar, with its Undo. The Undo of a deleted
  // meal holds that meal's rows in memory; they are dropped when the message
  // goes (one Undo, ten seconds, or another message).
  //
  // Task 8.2: Import must discard a pending Undo. It would leave the held rows
  // pointing at a database that Import has replaced. Clear [_notice] (or add a
  // method here that does) before Import writes.
  _Notice? _notice;
  Timer? _bannerTimer;
  var _foodOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.of(context).db;
    if (_weights == null) {
      _weights = db.watchWeights();
      _trend = db.watchTrend();
      _units = db.watchUnits();
      _slots = db.watchMealSlots();
    }
    // The meals follow the day: a new stream when "today" changes.
    if (_dayFor != widget.today) {
      _dayFor = widget.today;
      _day = db.watchDay(widget.today);
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new day (the shell moved past midnight): read that day's meals.
    if (_dayFor != widget.today) {
      _dayFor = widget.today;
      _day = AppScope.of(context).db.watchDay(widget.today);
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _showNotice(_Notice n) {
    _bannerTimer?.cancel();
    _bannerTimer = Timer(_bannerTime, _hideBanner);
    setState(() => _notice = n);
  }

  /// Opens the weight sheet and shows the confirmation bar after a save.
  /// The + Weight button and the widget link both come here.
  Future<void> openWeightSheet() async {
    // A request while a sheet is opening or open does nothing: the sheet
    // functions share one guard.
    final saved = await showWeightSheet(context);
    if (saved == null || !mounted) return;
    _showNotice(
      _Notice(
        () => _weightMessage(saved, AppScope.of(context).clock().localDate),
        undo: () => _undoWeight(saved),
        failed: S.undoFailed,
      ),
    );
  }

  void _hideBanner() {
    if (mounted) setState(() => _notice = null);
  }

  Future<void> _undo() async {
    final notice = _notice;
    if (notice == null || notice.undo == null) return;
    // Single flight: the message is taken and cleared before anything is
    // awaited, so a second tap finds nothing to undo.
    _bannerTimer?.cancel();
    setState(() => _notice = null);
    try {
      await notice.undo!();
    } catch (_) {
      // Includes a missing row. The row stays as it was, and the bar says so.
      if (mounted) _showNotice(_Notice(() => notice.failed));
    }
  }

  /// The day a meal was logged for, or null when it is today.
  String? _dayNamed(String localDate) {
    final today = AppScope.of(context).clock().localDate;
    return localDate == today ? null : S.dayWord(localDate, today);
  }

  Future<void> _undoWeight(SavedWeight saved) {
    final scope = AppScope.of(context);
    return scope.db.deleteWeight(saved.row.id, scope.clock());
  }

  /// Opens the food screen: a new meal (the day shown, the meal from the
  /// clock, or [slotId]), a logged [meal] to edit, or a closed screen
  /// reopened from its [draft]. Then shows what happened.
  Future<void> openFood({
    StoredMeal? meal,
    int? slotId,
    FoodDraft? draft,
  }) async {
    if (_foodOpen) return; // a fast double tap opens one screen
    _foodOpen = true;
    final FoodEntryResult? result;
    try {
      result = await Navigator.of(context, rootNavigator: true)
          .push<FoodEntryResult>(
            MaterialPageRoute(
              builder: (_) => FoodEntryScreen(
                date: widget.today,
                slotId: slotId,
                editing: meal,
                draft: draft,
              ),
            ),
          );
    } finally {
      _foodOpen = false;
    }
    if (!mounted || result == null) return;
    final db = AppScope.of(context).db;
    switch (result) {
      case FoodSaved(:final meal, :final edited):
        // Built from the stored meal that was read back, not from the text.
        // An edit has no Undo: the previous version is not kept.
        _showNotice(
          _Notice(
            () => S.mealSaved(
              meal.slotName,
              meal.totals[Nutrients.energy],
              _dayNamed(meal.meal.localDate),
            ),
            // Undo of a save deletes the meal. The rows it returns for a later
            // Undo are not kept: a save's Undo is offered once.
            undo: edited ? null : () => db.deleteMeal(meal.meal.id),
            failed: S.undoMealFailed,
          ),
        );
      case FoodDeleted(:final deleted):
        final m = deleted.meal;
        _showNotice(
          _Notice(
            () => S.mealDeleted(
              m.slotName,
              m.totals[Nutrients.energy],
              _dayNamed(m.meal.localDate),
            ),
            undo: () => db.undoDeleteMeal(deleted),
            failed: S.undoDeleteMealFailed,
          ),
        );
      case FoodAbandoned(:final draft):
        _showNotice(
          _Notice(
            () => draft.editingMealId != null
                ? S.mealChangesNotSaved(draft.slotName)
                : S.mealNotSaved(draft.slotName),
            undo: () async {
              // Undo opens the screen again with the text and the picks. It
              // does not wait for the screen: that screen's own result shows
              // its own message when it closes.
              unawaited(openFood(draft: draft));
            },
            failed: S.undoMealFailed,
          ),
        );
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
                _Meals(slots: _slots!, day: _day!, onOpen: openFood),
                const SizedBox(height: 12),
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
        if (_notice != null)
          ConfirmBar(
            message: _notice!.message(),
            onUndo: _notice!.undo == null ? null : _undo,
          ),
        Material(
          color: theme.colorScheme.surfaceContainer,
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: openFood,
                      style: _barButton,
                      child: const Text(S.addFood),
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
  /// [today] is read from the clock as the message is built.
  static String _weightMessage(SavedWeight s, String today) {
    final minute = minuteOfDayOf(s.row.measuredAtMs, s.row.tzOffsetMinutes);
    return S.weightSaved(
      formatWeight(s.row.weightKg, s.units),
      S.unitWord(s.units),
      S.whenInSentence(s.row.localDate, minute, today),
    );
  }
}

/// The message above the action bar. [message] is read each time the bar is
/// drawn. A null [undo] means no Undo button. [failed] replaces the message,
/// with no Undo, when the Undo did not work.
class _Notice {
  const _Notice(this.message, {this.undo, this.failed = ''});

  final String Function() message;
  final Future<void> Function()? undo;
  final String failed;
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

typedef _OpenFood = Future<void> Function({
  StoredMeal? meal,
  int? slotId,
  FoodDraft? draft,
});

/// The day's meals, in meal order, each opening Food entry. A meal with
/// nothing logged stays listed, so it is always one tap away (home.html).
class _Meals extends StatelessWidget {
  const _Meals({required this.slots, required this.day, required this.onOpen});

  final Stream<List<MealSlot>> slots;
  final Stream<DayLog> day;
  final _OpenFood onOpen;

  /// The foods in brief: each name up to its first comma.
  static String _foods(StoredMeal m) => S.foodsInBrief([
    for (final e in m.entries) e.entry.foodName.split(',').first.trim(),
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<MealSlot>>(
      stream: slots,
      builder: (context, slotSnap) => StreamBuilder<DayLog>(
        stream: day,
        builder: (context, daySnap) {
          if (!slotSnap.hasData || !daySnap.hasData) {
            return const SizedBox.shrink();
          }
          final meals = daySnap.data!.meals;
          final rows = <Widget>[];
          for (final slot in slotSnap.data!) {
            final here = [
              for (final m in meals)
                if (m.meal.slotId == slot.id) m,
            ];
            if (here.isEmpty) {
              rows.add(
                _MealRow(
                  title: slot.name,
                  detail: S.mealEmpty,
                  onTap: () => onOpen(slotId: slot.id),
                ),
              );
            }
            for (final m in here) {
              rows.add(
                _MealRow(
                  title: slot.name,
                  kcal: S.kcal(m.totals[Nutrients.energy]),
                  detail: _foods(m),
                  onTap: () => onOpen(meal: m),
                ),
              );
            }
          }
          // A meal in a slot that was archived since stays listed.
          final listed = {for (final slot in slotSnap.data!) slot.id};
          for (final m in meals) {
            if (listed.contains(m.meal.slotId)) continue;
            rows.add(
              _MealRow(
                title: m.slotName,
                kcal: S.kcal(m.totals[Nutrients.energy]),
                detail: _foods(m),
                onTap: () => onOpen(meal: m),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(S.homeMeals, style: theme.textTheme.titleMedium),
              ),
              ...rows,
            ],
          );
        },
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.title,
    required this.detail,
    required this.onTap,
    this.kcal,
  });

  final String title;
  final String? kcal;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (kcal != null) Text(kcal!),
                ],
              ),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
