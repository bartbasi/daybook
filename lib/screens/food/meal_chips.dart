// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/food_data.dart';
import '../../data/food_library_data.dart';
import '../../data/nutrients.dart';
import '../../strings.dart';

/// The chips under the food screen's text box (food-entry frame 1): "Same as
/// yesterday" and the saved meals, which are whole meals, then recent and
/// frequent foods. Each group is one row that scrolls sideways, under its own
/// label. The row follows [date] and [slotId]: when either changes, the data
/// behind it is read again.
///
/// The widget only shows and reports taps. What a tap does (log at once, or
/// add lines) is the screen's decision: [logsNow] says which one, so the label
/// and the spoken words say the same thing as the tap will do.
class MealChips extends StatefulWidget {
  const MealChips({
    super.key,
    required this.db,
    required this.date,
    required this.slotId,
    required this.today,
    required this.logsNow,
    required this.enabled,
    required this.onYesterday,
    required this.onSavedMeal,
    required this.onFood,
  });

  final AppDatabase db;

  /// The day being logged. "Yesterday" is the day before it.
  final String date;
  final int slotId;

  /// Today's date, the end of the window for recent foods.
  final String today;

  /// True while the box is empty and there are no lines: a whole-meal chip
  /// logs at once. False: it adds its items.
  final bool logsNow;

  /// False while a save is running: no chip takes a tap.
  final bool enabled;

  final void Function(StoredMeal meal) onYesterday;
  final void Function(SavedMealDetail meal) onSavedMeal;
  final void Function(RecentFood food) onFood;

  @override
  State<MealChips> createState() => _MealChipsState();
}

class _MealChipsState extends State<MealChips> {
  StoredMeal? _yesterday;
  var _saved = const <SavedMealDetail>[];
  var _foods = const <RecentFood>[];
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(MealChips old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date ||
        old.slotId != widget.slotId ||
        old.today != widget.today ||
        old.db != widget.db) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  /// Chips of another day or meal are never shown for this one: the old values
  /// go at once, and the new ones arrive from the database.
  void _subscribe() {
    _cancel();
    _yesterday = null;
    _saved = const [];
    _foods = const [];
    final db = widget.db;
    _subs.addAll([
      db
          .watchSameAsYesterday(forDate: widget.date, slotId: widget.slotId)
          .listen((m) => _set(() => _yesterday = m), onError: (Object _) {}),
      db
          .watchSavedMeals(slotId: widget.slotId)
          .listen(
            (m) => _set(
              () => _saved = [
                for (final s in m)
                  if (s.items.isNotEmpty) s,
              ],
            ),
            onError: (Object _) {},
          ),
      db
          .watchRecentFoods(slotId: widget.slotId, today: widget.today)
          .listen((f) => _set(() => _foods = f), onError: (Object _) {}),
    ]);
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  @override
  Widget build(BuildContext context) {
    final y = _yesterday;
    final onTap = widget.enabled;
    final whole = <Widget>[
      if (y != null)
        _Chip(
          name: S.chipSameAsYesterday,
          sub: S.chipYesterdaySub(y.slotName, y.totals[Nutrients.energy]),
          spoken: S.spokenYesterdayChip(
            y.slotName,
            y.entries.length,
            y.totals[Nutrients.energy],
            widget.logsNow,
          ),
          onTap: onTap ? () => widget.onYesterday(y) : null,
        ),
      for (final s in _saved)
        _Chip(
          name: s.meal.name,
          sub: S.chipSavedSub(s.items.length, s.totals[Nutrients.energy]),
          spoken: S.spokenWholeChip(
            s.meal.name,
            s.items.length,
            s.totals[Nutrients.energy],
            widget.logsNow,
          ),
          onTap: onTap ? () => widget.onSavedMeal(s) : null,
        ),
    ];
    final foods = <Widget>[
      for (final f in _foods)
        _Chip(
          name: f.foodName,
          sub: S.sheetAmountShort(f.quantity, f.unitLabel),
          spoken: S.spokenFoodChip(
            f.foodName,
            S.sheetAmountShort(f.quantity, f.unitLabel),
            f.nutrients[Nutrients.energy],
          ),
          onTap: onTap ? () => widget.onFood(f) : null,
        ),
    ];
    if (whole.isEmpty && foods.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: S.chipsRowLabel,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (whole.isNotEmpty)
            _Group(
              label: widget.logsNow ? S.chipsWholeLabel : S.chipsWholeLabelAdds,
              chips: whole,
            ),
          if (foods.isNotEmpty) _Group(label: S.chipsFoodLabel, chips: foods),
        ],
      ),
    );
  }
}

/// A label over one row of chips that scrolls sideways.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.chips});

  final String label;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in chips)
                Padding(padding: const EdgeInsets.only(right: 8), child: c),
            ],
          ),
        ),
      ],
    );
  }
}

/// One chip: a name, and a smaller line under it. At least 48 dp tall; the
/// text wraps at a wide chip and nothing is shrunk.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.name,
    required this.sub,
    required this.spoken,
    required this.onTap,
  });

  final String name;
  final String sub;
  final String spoken;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: spoken,
      excludeSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 48,
          minWidth: 48,
          maxWidth: 240,
        ),
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Center(
                widthFactor: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (sub.isNotEmpty)
                      Text(sub, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
