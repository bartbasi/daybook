// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/food_library_data.dart';
import '../../strings.dart';
import '../data_check_screen.dart';
import '../saved_meals/saved_meals_screen.dart';

/// Things set up once and changed rarely: the saved meals, and for now the
/// Data check screen.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Stream<List<SavedMealDetail>>? _saved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _saved ??= AppScope.of(context).db.watchSavedMeals();
  }

  /// "Usual breakfast and 1 more" (settings frame 1).
  static String _summary(List<SavedMealDetail> meals) => meals.isEmpty
      ? S.moreSavedMealsNone
      : S.moreSavedMealsSummary(meals.first.meal.name, meals.length - 1);

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              header: true,
              child: Text(
                S.moreTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          StreamBuilder<List<SavedMealDetail>>(
            stream: _saved,
            builder: (context, snap) => ListTile(
              minTileHeight: 56,
              title: const Text(S.moreSavedMeals),
              subtitle: snap.hasData ? Text(_summary(snap.data!)) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedMealsScreen(),
                ),
              ),
            ),
          ),
          ListTile(
            minTileHeight: 56,
            title: const Text(S.dataCheck),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final scope = AppScope.of(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DataCheckScreen(db: scope.db, foodsPath: scope.foodsPath),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
