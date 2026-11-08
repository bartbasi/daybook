// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'app_info.dart';

/// All user-facing text, in one place.
class S {
  static const title = appName;

  // Phase 2 data check screen. Temporary: replaced by the real screens in Phase 4.
  static const dataCheck = 'Data check';
  static const loadingFoods = 'Getting the food database ready...';
  static const searchHint = 'Search USDA foods, e.g. egg raw';
  static const barcodeHint = 'Barcode';
  static const lookUp = 'Look up';
  static const noResults = 'No foods found.';
  static const notFound = 'No product with that barcode in Open Food Facts.';
  static const lookupFailed =
      'Lookup failed. Check the connection and try again.';
  static const per100g = 'Per 100 g';
  static const per100ml = 'Per 100 ml';
  static const notListed = 'not listed';

  static const usdaCredit =
      'Food data from USDA FoodData Central. Public domain (CC0 1.0).';
  static const offCredit = 'Data from Open Food Facts (ODbL)';

  static String dataset(String d) => switch (d) {
    'foundation' => 'USDA Foundation Foods',
    'sr_legacy' => 'USDA SR Legacy',
    'fndds' => 'USDA FNDDS',
    _ => d,
  };
}
