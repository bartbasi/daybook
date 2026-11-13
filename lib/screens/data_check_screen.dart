// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Temporary Phase 2 screen so Bart can check nutrition numbers on a phone.
// Phase 4 replaces it with the real screens designed in Phase 3.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_info.dart';
import '../data/database.dart';
import '../data/food_reference.dart';
import '../data/nutrients.dart';
import '../data/off_client.dart';
import '../strings.dart';

class DataCheckScreen extends StatefulWidget {
  const DataCheckScreen({super.key, required this.db, required this.foodsPath});

  final AppDatabase db;

  /// Path of the installed USDA database, see installFoodReference.
  final Future<String> foodsPath;

  @override
  State<DataCheckScreen> createState() => _DataCheckScreenState();
}

class _DataCheckScreenState extends State<DataCheckScreen> {
  FoodReference? _foods;
  List<UsdaHit> _hits = const [];
  String _query = '';
  final _barcode = TextEditingController();
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    widget.foodsPath.then((path) {
      if (mounted) setState(() => _foods = FoodReference.open(path));
    });
  }

  @override
  void dispose() {
    _foods?.close();
    _barcode.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() {
      _query = q;
      _hits = q.trim().isEmpty ? const [] : _foods!.search(q);
    });
  }

  Future<void> _lookUp() async {
    final code = _barcode.text.trim();
    if (code.isEmpty) return;
    setState(() => _looking = true);
    final client = http.Client();
    String? error;
    try {
      final product = await OffClient(
        client,
        userAgent: offUserAgent(appVersion),
      ).lookup(code);
      if (product == null) {
        error = S.notFound;
      } else {
        await saveOffProduct(widget.db, product);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NutrientScreen(
              title: [
                product.brand,
                product.name,
              ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
              subtitle: product.barcode,
              baseLabel: product.baseUnit == 'ml' ? S.per100ml : S.per100g,
              per100: product.nutrients,
              portions: [
                if (product.servingQuantity != null)
                  UsdaPortion(
                    product.servingLabel ?? 'serving',
                    product.servingQuantity!,
                  ),
              ],
              credit: S.offCredit,
            ),
          ),
        );
      }
    } on ArgumentError {
      error = S.notFound;
    } catch (_) {
      error = S.lookupFailed;
    } finally {
      client.close();
      if (mounted) setState(() => _looking = false);
    }
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _open(UsdaHit hit) {
    final f = _foods!.food(hit.id)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NutrientScreen(
          title: f.description,
          subtitle: '${S.dataset(f.dataset)}, FDC ${f.id}',
          baseLabel: S.per100g,
          per100: f.nutrients,
          portions: f.portions,
          credit: S.usdaCredit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foods = _foods;
    return Scaffold(
      appBar: AppBar(title: const Text('${S.title}: ${S.dataCheck}')),
      body: foods == null
          ? const Center(child: Text(S.loadingFoods))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcode,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: S.barcodeHint,
                          ),
                          onSubmitted: (_) => _lookUp(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _looking ? null : _lookUp,
                        child: const Text(S.lookUp),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: S.searchHint,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _search,
                  ),
                ),
                Expanded(
                  child: _hits.isEmpty && _query.trim().isNotEmpty
                      ? const Center(child: Text(S.noResults))
                      : ListView.builder(
                          itemCount: _hits.length,
                          itemBuilder: (_, i) => ListTile(
                            title: Text(_hits[i].description),
                            subtitle: Text(S.dataset(_hits[i].dataset)),
                            onTap: () => _open(_hits[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Tracked nutrients for 100 g (or ml) or for one portion.
class NutrientScreen extends StatefulWidget {
  const NutrientScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.baseLabel,
    required this.per100,
    required this.portions,
    required this.credit,
  });

  final String title;
  final String subtitle;
  final String baseLabel;
  final Map<int, double> per100;
  final List<UsdaPortion> portions;
  final String credit;

  @override
  State<NutrientScreen> createState() => _NutrientScreenState();
}

class _NutrientScreenState extends State<NutrientScreen> {
  UsdaPortion? _portion; // null means per 100

  @override
  Widget build(BuildContext context) {
    final factor = (_portion?.grams ?? 100) / 100;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.subtitle),
          const SizedBox(height: 8),
          DropdownButton<UsdaPortion?>(
            value: _portion,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: null, child: Text(widget.baseLabel)),
              for (final p in widget.portions)
                if (p.label != defaultPortionLabel)
                  DropdownMenuItem(
                    value: p,
                    child: Text('${p.label} (${_grams(p.grams)} g)'),
                  ),
            ],
            onChanged: (p) => setState(() => _portion = p),
          ),
          for (final n in Nutrients.tracked)
            ListTile(
              dense: true,
              title: Text(n.name),
              trailing: Text(
                widget.per100[n.id] == null
                    ? S.notListed
                    : '${_fmt(widget.per100[n.id]! * factor)} ${n.unit}',
              ),
            ),
          const SizedBox(height: 16),
          Text(widget.credit, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  static String _grams(double g) =>
      g == g.roundToDouble() ? g.toStringAsFixed(0) : g.toStringAsFixed(1);

  static String _fmt(double v) =>
      v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(v >= 10 ? 1 : 2);
}
