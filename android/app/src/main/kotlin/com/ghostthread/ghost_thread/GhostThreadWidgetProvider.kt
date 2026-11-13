package com.ghostthread.ghost_thread

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Shows the most recently surfaced unfinished thought and opens it on tap.
 * Data is written by the Flutter side through home_widget.
 */
class GhostThreadWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.ghost_thread_widget)
            val data = HomeWidgetPlugin.getData(context)

            val snippet = data
                .getString("ghost_thread_snippet", null)
                ?.takeIf { it.isNotBlank() }
                ?: "No unfinished thoughts"
            val threadId = data.getString("ghost_thread_id", null)

            views.setTextViewText(R.id.ghost_thread_widget_text, snippet)

            val uri = if (!threadId.isNullOrBlank()) {
                Uri.parse("ghostthread://thread/$threadId")
            } else {
                null
            }
            views.setOnClickPendingIntent(
                R.id.ghost_thread_widget_container,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    uri,
                ),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
