// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/food_library_data.dart';
import '../../data/nutrients.dart';
import '../../strings.dart';
import '../food/confirm_bar.dart';
import 'saved_meal_editor.dart';

/// The saved meals under More (saved-meals.html frame 1): one row for each,
/// with its name, its other names, its items in brief and its kcal. A tap
/// opens the editor; "+ New" opens it empty. A delete from the editor comes
/// back here with Undo for 10 seconds.
class SavedMealsScreen extends StatefulWidget {
  const SavedMealsScreen({super.key});

  @override
  State<SavedMealsScreen> createState() => _SavedMealsScreenState();
}

class _Notice {
  const _Notice(this.text, [this.undo]);
  final String text;
  final Future<void> Function()? undo;
}

class _SavedMealsScreenState extends State<SavedMealsScreen> {
  static const _noticeTime = Duration(seconds: 10);

  late AppDatabase _db;
  Stream<List<SavedMealDetail>>? _meals;
  _Notice? _notice;
  Timer? _timer;
  var _opening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_meals != null) return;
    _db = AppScope.of(context).db;
    _meals = _db.watchSavedMeals();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// One message at a time. The held rows of a deleted saved meal live in the
  /// notice's Undo, so they are dropped with it: after one Undo, after ten
  /// seconds, or when another message replaces it.
  void _show(_Notice n) {
    _timer?.cancel();
    _timer = Timer(_noticeTime, () {
      if (mounted) setState(() => _notice = null);
    });
    setState(() => _notice = n);
  }

  /// Single flight: the message is taken and cleared before anything is
  /// awaited, so a second tap finds nothing to undo.
  Future<void> _undo() async {
    final undo = _notice?.undo;
    if (undo == null) return;
    _timer?.cancel();
    setState(() => _notice = null);
    try {
      await undo();
    } catch (_) {
      if (mounted) _show(const _Notice(S.undoDeleteSavedMealFailed));
    }
  }

  Future<void> _open([SavedMealDetail? saved]) async {
    if (_opening) return; // a fast double tap opens one editor
    _opening = true;
    final SavedMealEditorResult? result;
    try {
      result = await Navigator.of(context).push<SavedMealEditorResult>(
        MaterialPageRoute(builder: (_) => SavedMealEditor(saved: saved)),
      );
    } finally {
      _opening = false;
    }
    if (!mounted || result == null) return;
    switch (result) {
      case SavedMealSaved(:final saved):
        // From the row read back, not from what was typed.
        _show(_Notice(S.savedMealSavedMsg(saved.meal.name)));
      case SavedMealRemoved(:final deleted):
        _show(
          _Notice(S.savedMealDeletedMsg(deleted.detail.meal.name), () async {
            await _db.undoDeleteSavedMeal(deleted);
          }),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.savedMealsTitle),
        actions: [
          Semantics(
            label: S.savedMealsNewLabel,
            button: true,
            excludeSemantics: true,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _open,
              child: const Text(S.savedMealsNew),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            children: [
              if (_notice != null)
                ConfirmBar(
                  message: _notice!.text,
                  onUndo: _notice!.undo == null ? null : _undo,
                ),
              Expanded(
                child: StreamBuilder<List<SavedMealDetail>>(
                  stream: _meals,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text(S.savedMealsLoadFailed));
                    }
                    final meals = snap.data;
                    if (meals == null) return const SizedBox.shrink();
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final m in meals) _row(context, m),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.savedMealsHelpType,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                S.savedMealsHelpMake,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, SavedMealDetail m) {
    final theme = Theme.of(context);
    final sub = S.savedMealRowSub(
      m.items.length,
      m.totals[Nutrients.energy],
      m.aliases,
    );
    return Semantics(
      container: true,
      button: true,
      label: S.savedMealRowLabel(m.meal.name, sub),
      excludeSemantics: true,
      onTap: () => _open(m),
      child: InkWell(
        onTap: () => _open(m),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.meal.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(sub, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
