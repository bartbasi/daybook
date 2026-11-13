// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../clock.dart';
import '../../data/database.dart';
import '../../data/food_library_data.dart';
import '../../data/nutrients.dart';
import '../../strings.dart';
import '../food/confirm_bar.dart';
import 'food_editor.dart';
import 'recipe_editor.dart';

/// The foods and recipes the user made, and the products scanned from Open
/// Food Facts, under More. One row for each, by name, with its calories. A tap
/// opens the right editor; "+ New" asks for a food or a recipe. A scanned
/// product is read only: it says it is scanned, carries the Open Food Facts
/// credit, and has a Delete (the next scan of its barcode fetches it again).
/// A delete comes back here with Undo for 10 seconds.
class MyFoodsScreen extends StatefulWidget {
  const MyFoodsScreen({super.key});

  @override
  State<MyFoodsScreen> createState() => _MyFoodsScreenState();
}

class _Notice {
  const _Notice(this.text, [this.undo]);
  final String text;
  final Future<void> Function()? undo;
}

class _MyFoodsScreenState extends State<MyFoodsScreen> {
  static const _noticeTime = Duration(seconds: 10);

  late AppDatabase _db;
  late Clock _clock;
  Stream<List<FoodDetail>>? _foods;
  _Notice? _notice;
  Timer? _timer;
  var _opening = false;
  var _deleting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_foods != null) return;
    final scope = AppScope.of(context);
    _db = scope.db;
    _clock = scope.clock;
    _foods = _db.watchMyFoods();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// One message at a time, gone after ten seconds, after one Undo, or when
  /// another message replaces it.
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
      if (mounted) _show(const _Notice(S.myFoodUndoFailed));
    }
  }

  Future<void> _open({FoodDetail? food, bool recipe = false}) async {
    if (_opening) return; // a fast double tap opens one editor
    _opening = true;
    final MyFoodResult? result;
    try {
      final isRecipe = food?.food.kind == 'recipe' || (food == null && recipe);
      result = await Navigator.of(context).push<MyFoodResult>(
        MaterialPageRoute(
          builder: (_) =>
              isRecipe ? RecipeEditor(recipe: food) : FoodEditor(food: food),
        ),
      );
    } finally {
      _opening = false;
    }
    if (!mounted || result == null) return;
    switch (result) {
      case MyFoodSaved(:final food):
        // From the row read back, not from what was typed.
        _show(_Notice(S.myFoodSaved(food.food.name)));
      case MyFoodRemoved(:final food, :final barcode):
        _showRemoved(food, barcode);
    }
  }

  /// The message after a delete, with Undo: it brings the food back and puts
  /// its [barcode] back unless another food has it now.
  void _showRemoved(FoodDetail food, String? barcode) {
    _show(
      _Notice(S.myFoodDeleted(food.food.name), () async {
        final back = await _db.archiveFood(
          food.food.id,
          _clock(),
          archived: false,
          restoreBarcode: barcode,
        );
        if (mounted && barcode != null && back.food.barcode != barcode) {
          _show(_Notice(S.myFoodBarcodeTaken(back.food.name)));
        }
      }),
    );
  }

  /// Delete on a scanned product. One at a time. The barcode is freed, so the
  /// next scan of it fetches the product again.
  Future<void> _deleteScanned(FoodDetail f) async {
    if (_deleting) return;
    _deleting = true;
    try {
      final gone = await _db.archiveFood(f.food.id, _clock());
      if (mounted) _showRemoved(gone, f.food.barcode);
    } catch (_) {
      if (mounted) _show(const _Notice(S.myFoodDeleteFailed));
    } finally {
      _deleting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.myFoodsTitle),
        actions: [
          PopupMenuButton<bool>(
            tooltip: S.myFoodsNewLabel,
            onSelected: (recipe) => _open(recipe: recipe),
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text(S.myFoodsNewFood)),
              PopupMenuItem(value: true, child: Text(S.myFoodsNewRecipe)),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(S.myFoodsNew),
                ),
              ),
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
                child: StreamBuilder<List<FoodDetail>>(
                  stream: _foods,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text(S.myFoodsLoadFailed));
                    }
                    final foods = snap.data;
                    if (foods == null) return const SizedBox.shrink();
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final f in foods) _row(context, f),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            foods.isEmpty ? S.myFoodsEmpty : S.myFoodsHelp,
                            style: Theme.of(context).textTheme.bodyMedium,
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

  static String _sub(FoodDetail f) {
    final kcal = f.nutrients[Nutrients.energy];
    if (f.food.kind == 'recipe') {
      final servings = f.food.baseAmount;
      return S.recipeRowSub(
        servings,
        kcal == null || servings <= 0 ? null : kcal / servings,
      );
    }
    final basis = switch (f.basis) {
      FoodBasis.perServing => S.basisServing,
      FoodBasis.per100g => S.basisPer100g,
      FoodBasis.per100ml => S.basisPer100ml,
    };
    if (f.food.kind == 'off') return S.scannedRowSub(f.food.brand, kcal, basis);
    return S.foodRowSub(f.food.brand, kcal, basis);
  }

  /// A scanned product: words and a Delete, nothing to open.
  Widget _scannedRow(BuildContext context, FoodDetail f) {
    final sub = _sub(f);
    final small = Theme.of(context).textTheme.bodyMedium;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: S.scannedRowLabel(f.food.name, sub),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.food.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(sub, style: small),
                    Text(S.offCredit, style: small),
                  ],
                ),
              ),
            ),
          ),
          // The button keeps its own tap action; only its words are replaced
          // by the longer label that names the product.
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _deleteScanned(f),
            child: Semantics(
              label: S.scannedDeleteLabel(f.food.name),
              excludeSemantics: true,
              child: const Text(S.scannedDelete),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, FoodDetail f) {
    if (f.food.kind == 'off') return _scannedRow(context, f);
    final sub = _sub(f);
    return Semantics(
      container: true,
      button: true,
      label: S.myFoodRowLabel(f.food.name, sub),
      excludeSemantics: true,
      onTap: () => _open(food: f),
      child: InkWell(
        onTap: () => _open(food: f),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.food.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(sub, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
