package com.fastflow.fast_flow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar

class FastingWidgetProviderSmall : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("FastingWidgetPrefs", Context.MODE_PRIVATE)
        val status = prefs.getString("status", "COMPLETED") ?: "COMPLETED"
        val startTimeMs = prefs.getLong("start_time_ms", 0L)
        val endTimeMs = prefs.getLong("end_time_ms", 0L)
        
        val widgetEnabled = prefs.getBoolean("pref_widget_enabled", true)
        val countdownEnabled = prefs.getBoolean("pref_countdown_enabled", true)
        val ringEnabled = prefs.getBoolean("pref_ring_enabled", true)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.fasting_widget_small)

            if (!widgetEnabled) {
                // Clear views or show disabled state
                views.setTextViewText(R.id.widget_status_text, "DISABLED")
                views.setTextViewText(R.id.widget_countdown_text, "--:--:--")
                views.setTextViewText(R.id.widget_percent_text, "")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                continue
            }

            // Status label and color
            val label = WidgetHelper.getStatusLabel(status)
            val color = WidgetHelper.getStatusColor(context, status)
            views.setTextViewText(R.id.widget_status_text, label)
            views.setTextColor(R.id.widget_status_text, color)

            // Dynamic timer calculations
            val now = System.currentTimeMillis()
            val totalSec = (endTimeMs - startTimeMs) / 1000
            val elapsedSec = (now - startTimeMs) / 1000
            val remainingSec = (endTimeMs - now) / 1000

            // Progress percentage
            val progress = if (totalSec > 0) {
                val p = elapsedSec.toFloat() / totalSec.toFloat()
                p.coerceIn(0f, 1f)
            } else 0f

            val percentText = "${(progress * 100).toInt()}%"
            views.setTextViewText(R.id.widget_percent_text, if (ringEnabled) percentText else "")

            // Countdown
            val countdownStr = if (countdownEnabled) {
                if (remainingSec > 0) {
                    WidgetHelper.formatCountdown(remainingSec)
                } else {
                    "00:00:00"
                }
            } else {
                "--:--:--"
            }
            views.setTextViewText(R.id.widget_countdown_text, countdownStr)

            // Render progress ring
            if (ringEnabled) {
                val ringBitmap = WidgetHelper.drawProgressRing(context, progress, color)
                views.setImageViewBitmap(R.id.widget_progress_ring, ringBitmap)
            } else {
                // Draw zero progress ring
                val ringBitmap = WidgetHelper.drawProgressRing(context, 0f, color)
                views.setImageViewBitmap(R.id.widget_progress_ring, ringBitmap)
            }

            // Launch App intent
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.fastflow.action.NAVIGATE"
                putExtra("route", "/")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                101,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_progress_ring, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
