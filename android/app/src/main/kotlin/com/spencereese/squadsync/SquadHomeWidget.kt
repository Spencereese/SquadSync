package com.spencereese.squadsync

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/// Home screen widget. Reads the same keys the Dart side saves.
/// The OS refreshes it on its schedule. It is not a live background feed.
class SquadHomeWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val who = prefs.getString("who_summary", null) ?: "Open SquadSync"
        val names = prefs.getString("who_names", null).orEmpty()
        val spot = prefs.getString("spot_line", null) ?: "No spot called."
        val honesty = prefs.getString("honesty", null)
            ?: "Updates while SquadSync is open. It does not stay live in the background until push exists."
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.squad_home_widget)
            views.setTextViewText(R.id.squad_widget_who, who)
            views.setTextViewText(R.id.squad_widget_names, names)
            views.setTextViewText(R.id.squad_widget_spot, spot)
            views.setTextViewText(R.id.squad_widget_honesty, honesty)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
