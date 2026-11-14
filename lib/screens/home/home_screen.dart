// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/food_data.dart';
import '../../data/goal_data.dart';
import '../../data/nutrients.dart';
import '../../data/settings_data.dart';
import '../../data/weight_data.dart';
import '../../math/calorie_budget.dart';
import '../../math/weight_trend.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';
import '../food/confirm_bar.dart';
import '../food/food_entry_screen.dart';
import '../goals/goals_screen.dart';
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
  Stream<DayBudget?>? _budget;
  Stream<GoalsForDay?>? _goals;
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
      _followDay(db);
    }
  }

  void _followDay(AppDatabase db) {
    _day = db.watchDay(widget.today);
    _budget = db.watchBudgetForDay(widget.today);
    _goals = db.watchGoalsForDay(widget.today);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new day (the shell moved past midnight): read that day's meals.
    if (_dayFor != widget.today) {
      _dayFor = widget.today;
      _followDay(AppScope.of(context).db);
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
      case FoodLogged(:final meal, :final what):
        // A whole-meal chip wrote this meal (food-entry frame 12). Undo
        // deletes it, once, like Undo of a save.
        _showNotice(
          _Notice(
            () => S.mealLogged(
              meal.slotName,
              what,
              meal.totals[Nutrients.energy],
              _dayNamed(meal.meal.localDate),
            ),
            undo: () => db.deleteMeal(meal.meal.id),
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

  void _openGoals() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const GoalsScreen()));
  }

  /// Listens to one stream and hands the plain snapshot down. Each stream
  /// has one listener, so each is read by one builder that stays above the
  /// list and is never disposed while Home lives. The cards below get plain
  /// values and never listen.
  Widget _watch<T>(
    Stream<T>? stream,
    Widget Function(AsyncSnapshot<T> snap) build,
  ) => StreamBuilder<T>(stream: stream, builder: (_, snap) => build(snap));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            child: _watch<UnitSystem>(
              _units,
              (units) => _watch<List<WeightEntry>>(
                _weights,
                (weights) => _watch<List<TrendPoint>>(
                  _trend,
                  (trend) => _watch<List<MealSlot>>(
                    _slots,
                    (slots) => _watch<DayLog>(
                      _day,
                      (day) => _watch<DayBudget?>(
                        _budget,
                        (budget) => _watch<GoalsForDay?>(
                          _goals,
                          (goals) => _list(
                            theme,
                            units: units.data,
                            weights: weights.data,
                            trend: trend.data,
                            slots: slots.data,
                            day: day.data,
                            budget: budget,
                            goals: goals.data,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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

  Widget _list(
    ThemeData theme, {
    required UnitSystem? units,
    required List<WeightEntry>? weights,
    required List<TrendPoint>? trend,
    required List<MealSlot>? slots,
    required DayLog? day,
    required AsyncSnapshot<DayBudget?> budget,
    required GoalsForDay? goals,
  }) {
    final today = widget.today;
    return ListView(
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
        _BudgetPart(
          budget: budget.data,
          loading: budget.connectionState == ConnectionState.waiting,
          failed: budget.hasError,
          goals: goals,
          day: day,
          onSetGoals: _openGoals,
        ),
        _Meals(slots: slots, day: day, onOpen: openFood),
        const SizedBox(height: 12),
        _WeightRow(
          units: units,
          rows: weights,
          trend: trend,
          today: today,
          onTap: widget.onOpenWeightTab,
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
    required this.units,
    required this.rows,
    required this.trend,
    required this.today,
    required this.onTap,
  });

  final UnitSystem? units;
  final List<WeightEntry>? rows;
  final List<TrendPoint>? trend;
  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = units;
    final rows = this.rows;
    // Draw nothing until the units are known, so a metric user never sees
    // pounds for a frame.
    if (u == null || rows == null) return const SizedBox.shrink();
    final points = trend;
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
                Text(S.homeWeightLabel, style: theme.textTheme.titleMedium),
                if (rows.isEmpty)
                  const Text(S.homeNoWeight)
                else ...[
                  Text(
                    '${formatWeight(rows.first.weightKg, u)} '
                    '${S.unitWord(u)}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (points != null && points.isNotEmpty)
                    Text(
                      S.homeTrend(
                        formatWeight(points.last.trendKg, u),
                        S.unitWord(u),
                      ),
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
  }
}

/// The budget card and the macro meters, or the "Set your goals" card until
/// goals exist (home.html frames 1 and 2). Every number on the card is one of
/// [DayBudget]'s shown numbers, so the line under the big one always adds up.
/// It gets plain values. [loading] is true before the first read, [failed]
/// when the last read of the budget failed (then a plain line says so, and
/// never "Set your goals", which would be untrue).
class _BudgetPart extends StatelessWidget {
  const _BudgetPart({
    required this.budget,
    required this.loading,
    required this.failed,
    required this.goals,
    required this.day,
    required this.onSetGoals,
  });

  final DayBudget? budget;
  final bool loading;
  final bool failed;
  final GoalsForDay? goals;
  final DayLog? day;
  final VoidCallback onSetGoals;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(S.homeBudgetFailed),
      );
    }
    // A null value is "no goals yet", not "still loading".
    if (loading) return const SizedBox.shrink();
    final b = budget;
    if (b == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSetGoals,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.homeSetGoals,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(S.homeSetGoalsSub),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BudgetCard(budget: b),
          _Meters(macros: goals?.macros, log: day),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});

  final DayBudget budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = budget.shownLeft;
    return Semantics(
      container: true,
      label: S.homeBudgetSpoken(
        left,
        budget.shownGoal,
        budget.shownAddBack,
        budget.shownFood,
      ),
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text(
                    S.count(left.abs()),
                    style: theme.textTheme.displaySmall,
                  ),
                  Text(left < 0 ? S.homeKcalOver : S.homeKcalLeft),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                S.homeBudgetSum(
                  budget.shownGoal,
                  budget.shownAddBack,
                  budget.shownFood,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Protein, carbs and fat eaten so far against the goals, each with its
/// number in words. The bar is only a picture of the same numbers.
class _Meters extends StatelessWidget {
  const _Meters({required this.macros, required this.log});

  final MacroBreakdown? macros;
  final DayLog? log;

  @override
  Widget build(BuildContext context) {
    final macros = this.macros;
    final log = this.log;
    if (macros == null || log == null) return const SizedBox.shrink();
    final totals = log.totals;
    final items = [
      (Nutrients.protein, totals[Nutrients.protein] ?? 0, macros.proteinG),
      (Nutrients.carbs, totals[Nutrients.carbs] ?? 0, macros.carbsG),
      (Nutrients.fat, totals[Nutrients.fat] ?? 0, macros.fatG),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _Meter(
                id: items[i].$1,
                eaten: items[i].$2,
                goal: items[i].$3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.id, required this.eaten, required this.goal});

  final int id;
  final double eaten;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final name = S.nutrientName(id);
    final shownEaten = roundForDisplay(eaten);
    final shownGoal = roundForDisplay(goal);
    final over = shownEaten > shownGoal;
    return Semantics(
      container: true,
      label: S.homeMacroSpoken(name, shownEaten, shownGoal, over),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(S.homeMacroOf(shownEaten, shownGoal, over)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: goal <= 0 ? 0 : (eaten / goal).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
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

  final List<MealSlot>? slots;
  final DayLog? day;
  final _OpenFood onOpen;

  /// The foods in brief: each name up to its first comma.
  static String _foods(StoredMeal m) => S.foodsInBrief([
    for (final e in m.entries) e.entry.foodName.split(',').first.trim(),
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = this.slots;
    final day = this.day;
    if (slots == null || day == null) return const SizedBox.shrink();
    final meals = day.meals;
    final rows = <Widget>[];
    for (final slot in slots) {
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
    final listed = {for (final slot in slots) slot.id};
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
