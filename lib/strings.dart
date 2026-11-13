// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'app_info.dart';
import 'util/dates.dart';
import 'util/units.dart';

// A few strings can only live in native files. If the app is renamed or the
// wording changes, look here too:
//   android/app/src/main/AndroidManifest.xml (app label)
//   android/app/src/main/res/values/widget_strings.xml (widget name and
//     description in the widget picker)
//   ios/Runner/Info.plist (CFBundleDisplayName)

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
  static const homeNoWeight = 'No weight yet.';
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
  static String weightNotNumber(UnitSystem units) =>
      'Enter a number, like ${units == UnitSystem.imperial ? '181.8' : '82.5'}.';
  static const timeInFuture = 'That time has not happened yet.';
  static String weightOutOfRange(UnitSystem units) =>
      units == UnitSystem.imperial
      ? 'Enter a weight from 50 to 1,000 lb.'
      : 'Enter a weight from 22.7 to 453.6 kg.';
  static String saveFailed(String typed, String unit) =>
      'Could not save. Your $typed $unit is still here. '
      'Tap Save to try again.';

  // Weight tab and the edit sheet.
  static const logWeight = '+ Log';
  static const range1Month = '1 month';
  static const range3Months = '3 months';
  static const range1Year = '1 year';
  static const rangeAll = 'All';
  static const trendToday = 'Trend today';
  static const noTrend = 'No trend yet';
  static String trendChange(
    String direction,
    String amount,
    String unit,
    int days,
  ) => '$direction $amount $unit in $days days';
  static const trendDown = 'Down';
  static const trendUp = 'Up';
  static String trendSame(int days) => 'No change in $days days';
  static const weighIns = 'Weigh-ins';
  static const noWeighIns = 'No weigh-ins yet. Tap + Log to add one.';
  static const chartKey =
      "Dots: weigh-ins. Line: trend, labeled with today's value.";
  static String chartLabel(
    String from,
    String to,
    String trendFrom,
    String trendTo,
    String unit,
  ) => 'Weight, $from to $to. Trend from $trendFrom to $trendTo $unit.';
  static String chartLabelOne(
    String from,
    String to,
    String trend,
    String unit,
  ) => 'Weight, $from to $to. Trend $trend $unit.';
  static const fromHealthConnect = 'from Health Connect';
  static const fromAppleHealth = 'from Apple Health';
  static const editWeightTitle = 'Edit weigh-in';
  static const dateField = 'Date';
  static const timeField = 'Time';
  static const delete = 'Delete';
  static String enteredNote(String source, String created) => switch (source) {
    'health_connect' => 'From Health Connect. Created $created.',
    'apple_health' => 'From Apple Health. Created $created.',
    _ => 'Entered by hand. Created $created.',
  };
  static String weightDeleted(String weight, String unit, String day) =>
      'Deleted $weight $unit from $day';
  static const weighInGone = 'That weigh-in is no longer in your list.';
  static const deleteFailed =
      'Could not delete. The weigh-in is still in your list.';
  static const undoDeleteFailed =
      'Could not undo. The weigh-in is still deleted.';

  // Home-screen widget. Dart writes these words into the widget's data.
  static const widgetTitle = '$appName weight';
  static const widgetNoWeight = 'No weight yet';
  static const widgetTapToLog = 'Tap to log';

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

  /// 'Nov 11', with the year ('Nov 11, 2025') for another year.
  static String monthDay(String localDate, String today) {
    final d = parseDate(localDate);
    final year = d.year == parseDate(today).year ? '' : ', ${d.year}';
    return '${_months[d.month - 1]} ${d.day}$year';
  }

  /// 'Wed, Nov 11' (never 'yesterday'), with the year for another year.
  static String dayShort(String localDate, String today) {
    final d = parseDate(localDate);
    return '${_weekdays[d.weekday - 1]}, ${monthDay(localDate, today)}';
  }

  /// For the weigh-in list: 'Today, Nov 12, 7:02 am' or 'Wed, Nov 11, 6:55 am'.
  static String weighInWhen(String localDate, int minute, String today) {
    final day = localDate == today
        ? 'Today, ${monthDay(localDate, today)}'
        : dayShort(localDate, today);
    return '$day, ${timeOfDay(minute)}';
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
