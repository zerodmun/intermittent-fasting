package com.fastflow.fast_flow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FastingWidgetProviderMedium : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        try {
            val prefs = context.getSharedPreferences("FastingWidgetPrefs", Context.MODE_PRIVATE)
            val status = prefs.getString("status", "COMPLETED") ?: "COMPLETED"
            val startTimeMs = prefs.getLong("start_time_ms", 0L)
            val endTimeMs = prefs.getLong("end_time_ms", 0L)
            val nextTransitionMs = prefs.getLong("next_transition_ms", 0L)
            val streak = prefs.getInt("current_streak", 0)

            val widgetEnabled = prefs.getBoolean("pref_widget_enabled", true)
            val countdownEnabled = prefs.getBoolean("pref_countdown_enabled", true)
            val ringEnabled = prefs.getBoolean("pref_ring_enabled", true)

            for (appWidgetId in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.fasting_widget_medium)

                if (!widgetEnabled) {
                    views.setTextViewText(R.id.widget_status_text, "DISABLED")
                    views.setTextViewText(R.id.widget_countdown_text, "--:--")
                    views.setTextViewText(R.id.widget_detail_header, "Widget Disabled")
                    views.setTextViewText(R.id.widget_remaining_text, "")
                    views.setTextViewText(R.id.widget_transition_text, "")
                    views.setTextViewText(R.id.widget_streak_text, "")
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                    continue
                }

                val label = WidgetHelper.getStatusLabel(status)
                val color = WidgetHelper.getStatusColor(context, status)

                // Status header & texts
                views.setTextViewText(R.id.widget_status_text, label)
                views.setTextColor(R.id.widget_status_text, color)
                views.setTextViewText(R.id.widget_detail_header, if (status == "FASTING") "FASTING WINDOW" else "EATING WINDOW")

                val now = System.currentTimeMillis()
                val totalSec = (endTimeMs - startTimeMs) / 1000
                val elapsedSec = (now - startTimeMs) / 1000
                val remainingSec = (endTimeMs - now) / 1000

                val progress = if (totalSec > 0) {
                    val p = elapsedSec.toFloat() / totalSec.toFloat()
                    p.coerceIn(0f, 1f)
                } else 0f

                // Countdown timer inside progress
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

                // Remaining text in details
                val remainingStr = if (remainingSec > 0) {
                    val hrs = remainingSec / 3600
                    val mins = (remainingSec % 3600) / 60
                    "${hrs}h ${mins}m remaining"
                } else {
                    "0h 0m remaining"
                }
                views.setTextViewText(R.id.widget_remaining_text, remainingStr)

                // Next Transition time format
                val df = SimpleDateFormat("HH:mm", Locale.getDefault())
                val transitionTimeStr = if (nextTransitionMs > 0) {
                    val nextLabel = if (status == "FASTING") "Eating Window" else "Fasting"
                    "$nextLabel starts at ${df.format(Date(nextTransitionMs))}"
                } else {
                    "No transition set"
                }
                views.setTextViewText(R.id.widget_transition_text, transitionTimeStr)

                // Streak indicator
                views.setTextViewText(R.id.widget_streak_text, "🔥 $streak Days Streak")

                // Render progress ring
                val ringBitmap = WidgetHelper.drawProgressRing(context, if (ringEnabled) progress else 0f, color)
                views.setImageViewBitmap(R.id.widget_progress_ring, ringBitmap)

                // Click Intent
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = "com.fastflow.action.NAVIGATE"
                    putExtra("route", "/")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    102,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_progress_ring, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
