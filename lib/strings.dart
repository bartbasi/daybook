// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'app_info.dart';
import 'util/dates.dart';
import 'util/units.dart';

/// All user-facing text, in one place.
class S {
  static const title = appName;

  // Bottom bar.
  static const tabToday = 'Today';
  static const tabSummary = 'Summary';
  static const tabWorkouts = 'Workouts';
  static const tabWeight = 'Weight';
  static const tabMore = 'More';

  // Home.
  static const homeToday = 'Today';
  static const homeWeightLabel = 'Weight';
  static const homeNoWeight = 'No weight yet. Tap to add.';
  static String homeTrend(String weight, String unit) => 'Trend $weight $unit';
  static const addFood = '+ Food';
  static const addWeight = 'Weight';
  static const addCardio = 'Cardio';
  static const undo = 'Undo';
  static const undoFailed = 'Could not undo. The weight is still saved.';
  static String weightSaved(String weight, String unit, String when) =>
      'Weight saved: $weight $unit, $when';

  // Weight sheet.
  static const weightTitle = 'Weight';
  static const weightField = 'Weight';
  static const change = 'Change';
  static const save = 'Save';
  static String lastWeight(String weight, String unit, String when) =>
      'Last: $weight $unit, $when';
  static const weightMissing = 'Enter your weight.';
  static const weightNotNumber = 'Enter a number, like 181.8.';
  static String weightOutOfRange(UnitSystem units) =>
      units == UnitSystem.imperial
      ? 'Enter a weight from 50 to 1,000 lb.'
      : 'Enter a weight from 22.7 to 453.6 kg.';
  static String saveFailed(String typed, String unit) =>
      'Could not save. Your $typed $unit is still here. '
      'Tap Save to try again.';

  // More.
  static const moreTitle = 'More';

  // Dates and times (used by Home and the weight sheet).
  static String unitWord(UnitSystem units) =>
      units == UnitSystem.imperial ? 'lb' : 'kg';

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdaysLong = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// 'Thursday, Nov 12'.
  static String dateLong(String localDate) {
    final d = parseDate(localDate);
    return '${_weekdaysLong[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
  }

  /// '7:02 am' from minutes since local midnight.
  static String timeOfDay(int minuteOfDay) {
    final h = minuteOfDay ~/ 60;
    final m = minuteOfDay % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'am' : 'pm'}';
  }

  /// 'today', 'yesterday', or 'Wed, Nov 11' (with the year for another year).
  static String dayWord(String localDate, String today) {
    if (localDate == today) return 'today';
    if (localDate == addDays(today, -1)) return 'yesterday';
    final d = parseDate(localDate);
    final year = d.year == parseDate(today).year ? '' : ', ${d.year}';
    return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}$year';
  }

  /// For a sentence: 'today 7:02 am'.
  static String whenInSentence(String localDate, int minute, String today) =>
      '${dayWord(localDate, today)} ${timeOfDay(minute)}';

  /// For a label: 'Today, 7:02 am'.
  static String whenAsLabel(String localDate, int minute, String today) {
    final w = dayWord(localDate, today);
    return '${w[0].toUpperCase()}${w.substring(1)}, ${timeOfDay(minute)}';
  }

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
