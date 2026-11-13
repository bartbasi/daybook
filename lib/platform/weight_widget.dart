// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:home_widget/home_widget.dart';

import '../data/database.dart';
import '../math/weight_trend.dart';
import '../strings.dart';
import '../util/dates.dart';
import '../util/units.dart';

/// The link a tap on the widget opens the app with.
const weightLaunchLink = 'daybook://weight';

/// The Android widget provider class, with its package.
const androidWidgetProvider = 'io.github.bartbasi.daybook.WeightWidgetProvider';

/// The data keys the native widget reads. Every value is a ready-made text;
/// an empty text means "show nothing here".
const widgetKeyTitle = 'weight_title';
const widgetKeyWeight = 'weight_value';
const widgetKeyWhen = 'weight_when';
const widgetKeyTrend = 'weight_trend';
const widgetKeyTap = 'weight_tap';

/// Writes what the widget shows and asks it to redraw. [rows] are the
/// weigh-ins that are not deleted, newest first. This only reads them: the
/// widget never writes to the database.
///
/// A phone with no widget placed, or no plugin (tests, other platforms),
/// must never get in the way of a save, so every error is swallowed. Nothing
/// is logged, because the text holds the user's weight.
Future<void> writeWeightWidget(
  List<WeightEntry> rows,
  UnitSystem units,
  String today,
) async {
  try {
    final latest = rows.isEmpty ? null : rows.first;
    final texts = <String, String>{
      widgetKeyTitle: S.widgetTitle,
      widgetKeyWeight: latest == null
          ? S.widgetNoWeight
          : '${formatWeight(latest.weightKg, units)} ${S.unitWord(units)}',
      widgetKeyWhen: latest == null
          ? ''
          // An absolute day, never "Today": the widget is not redrawn
          // overnight, so relative wording would go stale.
          : '${S.dayShort(latest.localDate, today)}, '
                '${S.timeOfDay(minuteOfDayOf(latest.measuredAtMs, latest.tzOffsetMinutes))}',
      widgetKeyTrend: latest == null
          ? ''
          : S.homeTrend(formatWeight(_trendKg(rows), units), S.unitWord(units)),
      widgetKeyTap: S.widgetTapToLog,
    };
    for (final e in texts.entries) {
      await HomeWidget.saveWidgetData<String>(e.key, e.value);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: androidWidgetProvider);
  } catch (_) {
    // See above.
  }
}

double _trendKg(List<WeightEntry> rows) =>
    weightTrend(rows.map((r) => (localDate: r.localDate, kg: r.weightKg)))
        .last
        .trendKg;

/// The link the app was started with from the widget, or null.
Future<Uri?> readWidgetLaunchLink() async {
  try {
    return await HomeWidget.initiallyLaunchedFromHomeWidget();
  } catch (_) {
    return null;
  }
}

/// Links from widget taps that arrive while the app is running.
Stream<Uri?> widgetLinks() =>
    HomeWidget.widgetClicked.handleError((Object _) {});

bool isWeightLink(Uri? link) =>
    link != null && link.scheme == 'daybook' && link.host == 'weight';
