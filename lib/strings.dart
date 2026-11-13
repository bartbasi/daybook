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
//   ios/WeightWidget/WeightWidget.swift (widget name and description in the
//     widget gallery)
//   ios/WeightWidget/Info.plist (CFBundleDisplayName of the widget)

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

  // Food entry screen, and the meal rows and messages on Home.
  static const foodBoxHint =
      'Type what you ate, for example: 2 eggs, toast with butter, coffee';
  static const foodBoxHintMore = 'Tap to type more';
  static const foodBoxLabel = 'What you ate';
  static const foodClose = 'Close';
  static const foodPreviousDay = 'Previous day';
  static const foodNextDay = 'Next day';
  static const foodMenu = 'More options';
  static const foodDeleteMeal = 'Delete meal';
  static const foodSaveAsSaved = 'Save as a saved meal';
  static const foodMealPicker = 'Meal';
  static String foodEditing(String slot) => 'Editing $slot';
  static const foodSheetStale = 'That line changed. Tap it again.';
  static const foodSheetRefusedAmount =
      'The text cannot show that amount, so nothing was changed.';
  static const foodSheetRefusedRemove =
      'That item could not be taken out cleanly, so nothing was changed.';
  static const foodSheetRefusedFood =
      'That food could not be used here, so nothing was changed.';
  static const foodSheetAmountReset =
      'That food could not keep the amount, so it is set to its usual amount.';
  static const foodSheetForgetFailed =
      'Could not forget that match. Try again.';
  static const foodGroupAdded = 'Added';
  static const foodGroupTyped = 'From your text';
  static const foodLoading = 'Getting the food list ready...';
  static const foodSaveFailed =
      'Could not save. Your meal is still here. Try again.';
  static const foodDeleteFailed = 'Could not delete. The meal is still logged.';
  static const foodParseFailed =
      'Could not read that just now. Keep typing and it will catch up.';
  static const foodParserStopped =
      'The food list stopped working. Your text is kept.';
  static const tryAgain = 'Try again';
  static const fixOne = 'Fix 1 item';
  static String fixItems(int n) => n == 1 ? fixOne : 'Fix $n items';
  static String itemsNotCounted(int n) =>
      n == 1 ? '1 item not counted' : '$n items not counted';

  // The correction sheet (grammar 8.3, food-entry frames 4, 7 and 8).
  static const sheetYouTyped = 'You typed';
  static const sheetAmount = 'Amount';
  static const sheetUnit = 'Unit';
  static const sheetMultiplier = 'Multiplier';
  static const sheetBareCount = 'count';
  static const sheetWhichFood = 'Which food?';
  static const sheetFoodsLabel = 'Foods to choose from';
  static const sheetCurrentPick = 'Current pick';
  static const sheetRemembered =
      'Your pick is remembered when you save the meal.';
  static const sheetSearchHint = 'Search all foods';
  static const sheetNoResults = 'No foods found.';
  static String sheetNothingMatches(
    String words, {
    bool canScan = false,
    bool canCreate = false,
  }) {
    final ways = [
      if (canScan) 'scan the package',
      if (canCreate) 'make it your own food',
    ];
    final tail = switch (ways.length) {
      0 => '',
      1 => ', or ${ways[0]}',
      _ => ', ${ways[0]}, or ${ways[1]}',
    };
    return 'Nothing in the food list or your own foods matches "$words". '
        'Search with other words$tail.';
  }

  static const sheetScan = 'Scan its barcode';
  static String sheetCreate(String name) => 'Create a food called "$name"';
  static const sheetAddOwn = 'Add it as your own food';
  static const sheetAddOwnShort = 'Add it';

  // Barcode scanning (food-entry frames 9, 10 and 7).
  static const scanButton = 'Scan';
  static const scanButtonLabel = 'Scan a barcode';
  static const scanTitle = 'Scan a barcode';
  static const scanHelp = 'Point the camera at the barcode.';
  static const scanPrivacy =
      'The number is looked up on Open Food Facts. Nothing else is sent.';
  static const scanTypeNumber = 'Type the number instead';
  static const scanUseCamera = 'Use the camera instead';
  static const scanNumberLabel = 'Barcode number';
  static const scanLookUp = 'Look up';
  static const scanNumberBad =
      'Enter the 8, 12, 13 or 14 digits printed under the barcode.';
  static const scanNumberCheck =
      'That number does not look right. Check the digits under the barcode '
      'and try again.';
  static const scanLooking = 'Looking it up on Open Food Facts...';
  static const scanNoPermission =
      'Camera access is off, so $appName cannot scan. To scan a barcode, '
      'allow the camera for $appName in your phone\'s settings. You can also '
      'type the number instead.';
  static const scanCameraFailed =
      'The camera could not start. You can type the number instead.';
  static String scanNotFound(String code) =>
      'No product found for $code. Add it as your own food?';
  static const scanNoConnection =
      'Could not reach Open Food Facts. Check the connection and try again.';
  static const scanSaveFailed =
      'Could not save that product. Nothing was added. Try again.';
  static const sheetRemove = 'Remove from meal';
  static const sheetForget = 'Forget this match';
  static const sheetDone = 'Done';
  static const sheetUseFood = 'Use a food instead';
  static const sheetQuantityBad = 'Enter a number above 0.';
  static const sheetRowHint = 'Double tap to choose this food';

  /// 'tbsp, 30 g': the unit with the weight of the current amount.
  static String sheetUnitWeight(String unit, double grams) =>
      '$unit, ${_gramsText(grams)} g';
  static String sheetRowLabel(String name, String sub) => '$name. $sub';

  /// The dataset of a food, for a row of the sheet. Empty for a food whose
  /// dataset is not known (a stored entry being edited): no label then.
  static String datasetName(String? dataset) => switch (dataset) {
    null => '',
    'fndds' => 'USDA FNDDS',
    'sr_legacy' => 'USDA SR Legacy',
    'foundation' => 'USDA Foundation',
    'local' => 'My food',
    'off' => 'Open Food Facts (ODbL)',
    _ => 'USDA',
  };

  /// '2 tbsp' or '2' for a bare count, as in the sheet's rows.
  static String sheetAmountShort(double? q, String? unit) {
    if (q == null) return '';
    final u = unit ?? '';
    return u.isEmpty ? quantityText(q) : '${quantityText(q)} $u';
  }

  /// 'USDA FNDDS. 2 tbsp, 39 kcal. Current pick' (frame 4). A search result
  /// from the worker has no amount and may have no energy.
  static String sheetRowSub({
    required String dataset,
    String amount = '',
    double? kcalValue,
    bool current = false,
  }) {
    final tail = [
      if (amount.isNotEmpty) amount,
      if (kcalValue != null) kcal(kcalValue),
    ].join(', ');
    return [
      if (dataset.isNotEmpty) dataset,
      if (tail.isNotEmpty) tail,
      if (current) sheetCurrentPick,
    ].join('. ');
  }

  // The markers on a line: each is a word and a shape (grammar 8.2).
  static const markerGuess = 'Guess';
  static const markerAssumed = 'Assumed';
  static const markerNotFound = 'Not found';
  static const markerYourPick = 'Your pick';
  static const markerScanned = 'Scanned';
  static const lineNotCounted = 'not counted';
  static const lineTapToPick = 'Tap to pick a food';
  static String lineItems(int n) => n == 1 ? '1 item' : '$n items';

  /// '1,255' style, for kcal.
  static String count(int n) {
    final s = n.abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}$out';
  }

  /// '167 kcal'. A food with no energy value shows '-'.
  static String kcal(double? v) =>
      v == null ? '- kcal' : '${count(v.round())} kcal';
  static String _gram(double? v) => v == null ? '-' : count(v.round());
  static String macros(double? p, double? c, double? f) =>
      'P ${_gram(p)}  C ${_gram(c)}  F ${_gram(f)}';

  static String _trimmed(double v, int decimals) {
    var s = v.toStringAsFixed(decimals);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  static String quantityText(double q) => _trimmed(q, 2);
  static String _gramsText(double g) =>
      g >= 10 ? g.round().toString() : _trimmed(g, 1);

  /// '2 slice, 56 g', '1, 200 g' for a bare count, '200 g' when the amount is
  /// already in the base unit.
  static String amountText(
    double q,
    String unit,
    double base,
    String baseUnit,
  ) {
    final b = '${_gramsText(base)} $baseUnit';
    if (unit.isEmpty) return '${quantityText(q)}, $b';
    if (unit == baseUnit && (q - base).abs() < 0.05) return b;
    return '${quantityText(q)} $unit, $b';
  }

  /// The multiplier of a saved meal header, shown only when it is not 1.
  static String multiplierText(double m) {
    if (m == 0.5) return '× ½';
    return '× ${_trimmed(m, 2)}';
  }

  static String _spokenUnit(String unit, double q) {
    final one = q == 1;
    return switch (unit) {
      'g' => one ? 'gram' : 'grams',
      'ml' => one ? 'milliliter' : 'milliliters',
      'oz' => one ? 'ounce' : 'ounces',
      'fl oz' => one ? 'fluid ounce' : 'fluid ounces',
      'tbsp' => one ? 'tablespoon' : 'tablespoons',
      'tsp' => one ? 'teaspoon' : 'teaspoons',
      'cup' => one ? 'cup' : 'cups',
      _ => unit,
    };
  }

  static String spokenAmount(
    double q,
    String unit,
    double base,
    String baseUnit,
  ) {
    final b = '${_gramsText(base)} ${_spokenUnit(baseUnit, base)}';
    if (unit.isEmpty) return '${quantityText(q)}, $b';
    if (unit == baseUnit && (q - base).abs() < 0.05) return b;
    return '${quantityText(q)} ${_spokenUnit(unit, q)}, $b';
  }

  /// "Guess. Cream, half and half. 2 tablespoons, 30 grams. 39 calories.
  /// Double tap to change." [markers] are the marker words, in order.
  static String spokenLine(
    List<String> markers,
    String name,
    String amount,
    double? kcal,
  ) =>
      '${[...markers, name, amount, if (kcal != null) '${count(kcal.round())} calories'].join('. ')}. '
      'Double tap to change.';
  static String spokenNotFound(String typed) =>
      '$markerNotFound. $typed. Not counted. Double tap to pick a food.';
  static String spokenHeader(
    String name,
    String? multiplier,
    int items,
    double? kcal,
  ) =>
      '${['Saved meal', name, ?multiplier, lineItems(items), if (kcal != null) '${count(kcal.round())} calories'].join('. ')}. '
      'Double tap to change.';
  static String _spokenGrams(double? v) =>
      v == null ? 'not listed' : '${count(v.round())} grams';
  static String spokenTotals(
    double? kcal,
    double? p,
    double? c,
    double? f,
    int notCounted,
  ) =>
      'Meal total: ${count((kcal ?? 0).round())} calories, '
      'protein ${_spokenGrams(p)}, carbs ${_spokenGrams(c)}, '
      'fat ${_spokenGrams(f)}.${notCounted > 0 ? ' ${itemsNotCounted(notCounted)}.' : ''}';

  /// The macros after the kcal in the totals bar.
  static String totalsMacros(double? p, double? c, double? f) =>
      '  ${macros(p, c, f)}';

  /// The typed words of a line, in quotes.
  static String quoted(String typed) => '"$typed"';

  /// A saved meal header's name, with its multiplier when it is not 1.
  static String headerTitle(String name, double? multiplier) =>
      multiplier == null || multiplier == 1
      ? name
      : '$name  ${multiplierText(multiplier)}';

  /// The foods of a meal in brief, for a Home row.
  static String foodsInBrief(List<String> names) => names.join(', ');

  /// 'Today, Nov 12', 'Yesterday, Nov 11' or 'Wed, Nov 4'.
  static String foodDate(String localDate, String today) {
    if (localDate == today) return 'Today, ${monthDay(localDate, today)}';
    if (localDate == addDays(today, -1)) {
      return 'Yesterday, ${monthDay(localDate, today)}';
    }
    return dayShort(localDate, today);
  }

  // Save as a saved meal.
  static const savedMealTitle = 'Save as a saved meal';
  static const savedMealName = 'Name';
  static const savedMealNameEmpty = 'Give it a name.';
  static const savedMealNeedsFix =
      'An item was not found, so the saved meal was not made. Fix it first.';
  static const savedMealFailed = 'Could not save the saved meal. Try again.';
  static String savedMealCreated(String name) => 'Saved meal "$name" created.';
  static const cancel = 'Cancel';

  // The chips row on the food screen (food-entry frame 1) and the message on
  // Home when a whole-meal chip logs at once (frame 12).
  static const chipsWholeLabel = 'Log a whole meal. Tap logs it now.';
  static const chipsWholeLabelAdds = 'Tap adds its items';
  static const chipsFoodLabel = 'Recent and frequent. Tap adds a line.';
  static const chipSameAsYesterday = 'Same as yesterday';
  static const chipSameAsYesterdayShort = 'same as yesterday';
  static String chipYesterdaySub(String slot, double? kcalValue) =>
      '$slot, ${kcal(kcalValue)}';
  static String spokenYesterdayChip(
    String slot,
    int items,
    double? kcalValue,
    bool logsNow,
  ) =>
      spokenWholeChip('$chipSameAsYesterday, $slot', items, kcalValue, logsNow);
  static String chipSavedSub(int items, double? kcalValue) =>
      '${lineItems(items)}, ${kcal(kcalValue)}';
  static String spokenWholeChip(
    String name,
    int items,
    double? kcalValue,
    bool logsNow,
  ) =>
      '${[name, '${lineItems(items)}${kcalValue == null ? '' : ', ${count(kcalValue.round())} calories'}'].join('. ')}. '
      '${logsNow ? 'Double tap to log it now.' : 'Double tap to add its items.'}';
  static String spokenFoodChip(String name, String amount, double? kcalValue) =>
      '${[amount.isEmpty ? name : '$name, $amount', if (kcalValue != null) '${count(kcalValue.round())} calories'].join('. ')}. '
      'Double tap to add a line.';
  static const chipSavedMealGone = 'That saved meal is no longer there.';
  static const chipsRowLabel = 'Meals and foods to add';
  static String mealLogged(
    String slot,
    String what,
    double? kcalValue, [
    String? day,
  ]) =>
      '$slot logged${day == null ? '' : ' for $day'}: $what, '
      '${kcalValue == null ? '-' : count(kcalValue.round())} kcal';

  // Saved meals under More (saved-meals frames 1 and 2).
  static const moreSavedMeals = 'Saved meals and aliases';
  static const moreSavedMealsNone = 'None yet';
  static String moreSavedMealsSummary(String first, int others) =>
      others <= 0 ? first : '$first and $others more';
  static const savedMealsTitle = 'Saved meals';
  static const savedMealsNew = '+ New';
  static const savedMealsNewLabel = 'New saved meal';
  static const savedMealsHelpType =
      "Type a saved meal's name, or one of its other names, in Food entry "
      'and it expands to its items.';
  static const savedMealsHelpMake =
      'To save a meal you logged: open it from Home, then "Save as a saved '
      'meal" in its menu.';

  /// '2 items, 260 kcal. Also typed as: usual breakfast, ub' (frame 1).
  static String savedMealRowSub(
    int items,
    double? kcalValue,
    List<String> names,
  ) =>
      '${lineItems(items)}, ${kcal(kcalValue)}'
      '${names.isEmpty ? '' : '. Also typed as: ${names.join(', ')}'}';
  static String savedMealRowLabel(String name, String sub) =>
      '$name. $sub. Double tap to edit.';
  static const savedMealEditNew = 'New saved meal';
  static const savedMealOtherNames = 'Other names you can type';
  static const savedMealNewName = 'New name';
  static const savedMealAddName = '+ Add';
  static String savedMealRemoveName(String name) => 'Remove the name $name';
  static const savedMealItemsHeading = 'Items';
  static const savedMealItemsEmpty = 'No items yet.';
  static const savedMealBoxHint =
      'Type to add items, the same way as Food entry';
  static const savedMealBoxLabel = 'Items to add';
  static const savedMealMenu = 'More options';
  static const savedMealDelete = 'Delete saved meal';
  static const savedMealNeedsItems = 'Add at least one item.';
  static const savedMealAliasEmpty = 'Type a name to add.';
  static String savedMealAliasInList(String p) =>
      '"$p" is already in this list.';
  static String savedMealAliasTaken(String p) =>
      '"$p" is already used by another saved meal. Pick a different name.';
  static const savedMealAliasBlank = 'A name was empty, so nothing was saved.';
  static String savedMealSavedMsg(String name) => 'Saved meal "$name" saved.';
  static String savedMealDeletedMsg(String name) =>
      'Saved meal "$name" deleted.';
  static const undoDeleteSavedMealFailed =
      'Could not undo. The saved meal is still deleted.';
  static const savedMealsLoadFailed = 'Could not read the saved meals.';
  static const savedMealDeleteFailed =
      'Could not delete. The saved meal is still there.';

  // My foods and recipes (food-editor frames 1 and 2).
  static const moreMyFoods = 'My foods and recipes';
  static const moreMyFoodsSub = 'Foods you made, recipes, scanned products';
  static const myFoodsTitle = 'My foods and recipes';
  static const myFoodsNew = '+ New';
  static const myFoodsNewLabel = 'New food or recipe';
  static const myFoodsNewFood = 'New food';
  static const myFoodsNewRecipe = 'New recipe';
  static const myFoodsEmpty =
      'Nothing here yet. Tap + New to make a food or a recipe.';
  static const myFoodsHelp =
      'A food or recipe you make here can be typed in Food entry like any '
      'other food.';
  static const myFoodsLoadFailed = 'Could not read your foods.';
  static const myFoodsMenu = 'More options';
  static const foodDelete = 'Delete food';
  static const recipeDelete = 'Delete recipe';
  static String myFoodSaved(String name) => '"$name" saved.';
  static String myFoodDeleted(String name) => '"$name" deleted.';
  static const myFoodUndoFailed = 'Could not undo. It is still deleted.';
  static String myFoodBarcodeTaken(String name) =>
      '"$name" is back. Its barcode now belongs to another food, so it was '
      'left off.';
  static const myFoodDeleteFailed = 'Could not delete. It is still there.';
  static const myFoodWriteFailed =
      'Could not save. Nothing was changed. Try again.';

  /// '120 kcal per serving', with the brand in front when there is one.
  static String foodRowSub(String? brand, double? kcalValue, String basis) =>
      '${brand == null ? '' : '$brand, '}${kcal(kcalValue)} $basis';
  static const basisServing = 'per serving';
  static const basisPer100g = 'per 100 g';
  static const basisPer100ml = 'per 100 ml';

  /// 'Scanned product, Brand, 60 kcal per 100 g'.
  static String scannedRowSub(String? brand, double? kcalValue, String basis) =>
      'Scanned product, ${brand == null ? '' : '$brand, '}${kcal(kcalValue)} '
      '$basis';
  static const scannedDelete = 'Delete';
  static String scannedDeleteLabel(String name) => 'Delete $name';
  static String scannedRowLabel(String name, String sub) =>
      '$name. $sub. $offCredit.';

  /// 'Recipe, 4 servings, 309 kcal a serving'.
  static String recipeRowSub(double servings, double? kcalPerServing) =>
      'Recipe, ${servingsText(servings)}, ${kcal(kcalPerServing)} a serving';
  static String servingsText(double n) =>
      n == 1 ? '1 serving' : '${quantityText(n)} servings';
  static String myFoodRowLabel(String name, String sub) => '$name. $sub.';

  /// A number typed back into a field: up to 4 decimals, no trailing zeros.
  static String numberText(double v) => _trimmed(v, 4);

  // The custom food editor.
  static const foodEditNew = 'New food';
  static const foodEditName = 'Name';
  static const foodEditNameEmpty = 'Give it a name.';
  static const foodEditBrand = 'Brand (optional)';
  static const foodEditBarcode = 'Barcode (optional)';
  static const foodEditBarcodeBad =
      'That barcode does not look right. Check the digits under the barcode.';
  static const foodEditBarcodeTaken = 'Another food already has this barcode.';
  static const foodEditFor = 'Nutrition is for';
  static const foodEditAmount = 'Amount';
  static const foodEditUnit = 'Unit';
  static const foodUnitServing = 'serving';
  static const foodUnitG = 'grams';
  static const foodUnitMl = 'milliliters';
  static const foodEditAmountBad = 'Enter an amount above 0.';
  static const foodEditWeight = 'One serving weighs (optional)';
  static const foodEditWeightBad = 'Enter a weight above 0, or leave it empty.';
  static const foodEditCaloriesEmpty = 'Enter the calories.';
  static const foodEditNumberBad = 'Enter a number, or leave it empty.';
  static const foodEditNumberComma =
      'Type it without the comma, for example 1000. A comma is read as a '
      'decimal point.';
  static String foodEditKcalTooHigh(String unit) =>
      'That works out to more than 900 kcal in 100 $unit, which no food has. '
      'Check the amount and the calories.';
  static String foodEditNutrientTooHigh(String unit) =>
      'That works out to more than 100 g in 100 $unit, which cannot be. '
      'Check the amount and this number.';
  static const foodEditPortionServing =
      'Pick another name. A serving already has its own portion.';
  static const foodEditPortionDigit =
      'Start the name with a letter, for example "slice".';

  // Nutrient names and unit words as the food editor shows them.
  static const unitKcal = 'kcal';
  static const unitG = 'g';
  static const unitMl = 'ml';
  static const unitMg = 'mg';
  static const unitMcg = 'µg';
  static String nutrientUnit(String unit) => switch (unit) {
    'kcal' => unitKcal,
    'g' => unitG,
    'mg' => unitMg,
    'µg' => unitMcg,
    _ => unit,
  };
  static String nutrientName(int id) => switch (id) {
    1008 => 'Calories',
    1003 => 'Protein',
    1005 => 'Carbs',
    1004 => 'Fat',
    1079 => 'Fiber',
    2000 => 'Sugar',
    1235 => 'Added sugar',
    1258 => 'Saturated fat',
    1257 => 'Trans fat',
    1253 => 'Cholesterol',
    1093 => 'Sodium',
    1092 => 'Potassium',
    1087 => 'Calcium',
    1089 => 'Iron',
    1090 => 'Magnesium',
    1095 => 'Zinc',
    1106 => 'Vitamin A',
    1162 => 'Vitamin C',
    1114 => 'Vitamin D',
    1109 => 'Vitamin E',
    1185 => 'Vitamin K',
    1175 => 'Vitamin B6',
    1178 => 'Vitamin B12',
    1190 => 'Folate',
    _ => '',
  };
  static const foodEditFix =
      'Some fields need a look. Each one says what is wrong.';
  static const foodEditMore = 'More nutrients';
  static String foodEditMoreHint(int others) =>
      'Fiber, sugar, sodium and $others more. Optional.';
  static const foodEditPortions = 'Portions';
  static const foodEditPortionsNone = 'None yet.';
  static const foodEditPortionsNeedWeight =
      'Give the weight of one serving above to use portions.';
  static const foodEditPortionAdd = '+ Add';
  static const foodEditPortionName = 'Portion name';
  static const foodEditPortionWeight = 'Weight';
  static const foodEditPortionBad =
      'Give each portion a name and a weight above 0.';
  static String foodEditPortionRemove(int n) => 'Remove portion $n';

  // The recipe editor.
  static const recipeEditNew = 'New recipe';
  static const recipeName = 'Name';
  static const recipeNameEmpty = 'Give it a name.';
  static const recipeIngredients = 'Ingredients';
  static const recipeIngredientsEmpty = 'No ingredients yet.';
  static const recipeBoxHint = 'Type to add ingredients';
  static const recipeBoxLabel = 'Ingredients to add';
  static const recipeMakes = 'Makes';
  static const recipeServingsUnit = 'servings';
  static const recipeServingsBad =
      'Enter how many servings it makes, a number above 0.';
  static const recipeNeedsIngredients = 'Add at least one ingredient.';
  static String recipeIngredientUnpriced(String name) =>
      'Could not work out "$name". Tap it to remove it or pick another food.';
  static String recipeAmountReset(List<String> names) =>
      '${names.length == 1 ? 'The amount of' : 'The amounts of'} '
      '${names.map((n) => '"$n"').join(', ')} could not be kept, because '
      '${names.length == 1 ? 'that food changed' : 'those foods changed'}. '
      'The usual amount is used.';
  static const recipePricing =
      'Working out the amounts again. You can change ingredients when that is '
      'done.';
  static String recipeContainsItself(String name) =>
      'A recipe cannot contain itself. Take "$name" out of the ingredients.';
  static const recipeFailed = 'Could not save the recipe. Try again.';
  static String recipeKcalServing(double kcalValue) =>
      '${count(kcalValue.round())} kcal a serving';
  static String recipeWhole(double kcalValue) =>
      'Whole: ${count(kcalValue.round())} kcal';
  static String recipeSpokenTotals(
    double kcalPerServing,
    double? p,
    double? c,
    double? f,
    double whole,
    int notCounted,
  ) =>
      'Each serving: ${count(kcalPerServing.round())} calories, '
      'protein ${_spokenGrams(p)}, carbs ${_spokenGrams(c)}, '
      'fat ${_spokenGrams(f)}. Whole recipe: ${count(whole.round())} '
      'calories.${notCounted > 0 ? ' ${itemsNotCounted(notCounted)}.' : ''}';

  // Home: the meals.
  static const homeMeals = 'Meals';
  static const mealEmpty = 'Nothing yet. Tap to add.';
  // [day] is set when the meal is for a day other than today.
  static String mealSaved(String slot, double? kcal, [String? day]) =>
      '$slot saved${day == null ? '' : ' for $day'}, '
      '${kcal == null ? '-' : count(kcal.round())} kcal';
  static String mealNotSaved(String slot) =>
      '${slot.isEmpty ? 'Meal' : slot} not saved';
  static String mealChangesNotSaved(String slot) =>
      slot.isEmpty ? 'Changes not saved' : 'Changes to $slot not saved';
  static String mealDeleted(String slot, double? kcal, [String? day]) =>
      '$slot deleted${day == null ? '' : ' for $day'}, '
      '${kcal == null ? '-' : count(kcal.round())} kcal';
  static const undoMealFailed = 'Could not undo. The meal is still saved.';
  static const undoDeleteMealFailed =
      'Could not undo. The meal is still deleted.';

  // Used by the food editor and the barcode lines.
  static const notListed = 'not listed';
  static const offCredit = 'Data from Open Food Facts (ODbL)';
}
