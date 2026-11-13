// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

package io.github.bartbasi.daybook

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen weight widget. It only shows the texts the app wrote (see
 * lib/platform/weight_widget.dart) and never reads or writes the database.
 * The whole widget is one tap target that opens the app on the weight sheet.
 */
class WeightWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val title = widgetData.getString("weight_title", "") ?: ""
        val weight = widgetData.getString("weight_value", "") ?: ""
        val whenText = widgetData.getString("weight_when", "") ?: ""
        val trend = widgetData.getString("weight_trend", "") ?: ""
        val tap = widgetData.getString("weight_tap", "") ?: ""

        val open = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("daybook://weight"),
        )

        for (id in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(id)
            // Below about two cells high there is room for the weight and
            // "Tap to log" only.
            val small = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) < 100
            val views = RemoteViews(
                context.packageName,
                if (small) R.layout.weight_widget_small else R.layout.weight_widget,
            )
            views.setTextViewText(R.id.widget_weight, weight)
            views.setTextViewText(R.id.widget_tap, tap)
            if (!small) {
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_when, whenText)
                views.setTextViewText(R.id.widget_trend, trend)
            }
            // One spoken description for the whole tap target.
            val spoken = listOf(title, weight, whenText, trend, tap)
                .filter { it.isNotEmpty() }
                .joinToString(". ")
            views.setContentDescription(R.id.widget_root, spoken)
            views.setOnClickPendingIntent(R.id.widget_root, open)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    // Resizing can cross the small and normal sizes, so draw again.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            HomeWidgetPlugin.getData(context),
        )
    }
}
