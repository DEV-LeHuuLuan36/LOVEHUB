package com.example.lovehub

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class LoveWidgetProvider : es.antonborri.home_widget.HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val days = widgetData.getString("days", null) ?: "—"
            val names = widgetData.getString("names", null) ?: ""

            val views = RemoteViews(context.packageName, R.layout.love_widget).apply {
                setTextViewText(R.id.widget_days, days)
                setTextViewText(R.id.widget_label, "days together 💕")
                setTextViewText(R.id.widget_names, names)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
