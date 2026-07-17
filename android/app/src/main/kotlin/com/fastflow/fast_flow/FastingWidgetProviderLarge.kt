package com.fastflow.fast_flow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FastingWidgetProviderLarge : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("FastingWidgetPrefs", Context.MODE_PRIVATE)
        val status = prefs.getString("status", "COMPLETED") ?: "COMPLETED"
        val startTimeMs = prefs.getLong("start_time_ms", 0L)
        val endTimeMs = prefs.getLong("end_time_ms", 0L)
        val nextTransitionMs = prefs.getLong("next_transition_ms", 0L)
        val streak = prefs.getInt("current_streak", 0)
        
        val weight = prefs.getFloat("latest_weight", 0f)
        val bodyFat = prefs.getFloat("latest_body_fat", 0f)

        val widgetEnabled = prefs.getBoolean("pref_widget_enabled", true)
        val countdownEnabled = prefs.getBoolean("pref_countdown_enabled", true)
        val ringEnabled = prefs.getBoolean("pref_ring_enabled", true)
        val bodyFatEnabled = prefs.getBoolean("pref_body_fat_enabled", true)
        val weightEnabled = prefs.getBoolean("pref_weight_enabled", true)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.fasting_widget_large)

            if (!widgetEnabled) {
                views.setTextViewText(R.id.widget_status_text, "DISABLED")
                views.setTextViewText(R.id.widget_countdown_text, "--:--")
                views.setTextViewText(R.id.widget_streak_text, "")
                views.setViewVisibility(R.id.widget_weight_layout, View.GONE)
                views.setViewVisibility(R.id.widget_body_fat_layout, View.GONE)
                views.setTextViewText(R.id.widget_transition_text, "Widget disabled")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                continue
            }

            val label = WidgetHelper.getStatusLabel(status)
            val color = WidgetHelper.getStatusColor(context, status)

            // Header status
            views.setTextViewText(R.id.widget_status_text, label)
            views.setTextColor(R.id.widget_status_text, color)

            val now = System.currentTimeMillis()
            val totalSec = (endTimeMs - startTimeMs) / 1000
            val elapsedSec = (now - startTimeMs) / 1000
            val remainingSec = (endTimeMs - now) / 1000

            val progress = if (totalSec > 0) {
                val p = elapsedSec.toFloat() / totalSec.toFloat()
                p.coerceIn(0f, 1f)
            } else 0f

            // Countdown timer
            val countdownStr = if (countdownEnabled) {
                if (remainingSec > 0) {
                    val hrs = remainingSec / 3600
                    val mins = (remainingSec % 3600) / 60
                    "${hrs}h ${mins}m remaining"
                } else {
                    "Completed!"
                }
            } else {
                "Active"
            }
            views.setTextViewText(R.id.widget_countdown_text, countdownStr)

            // Percent text inside circle
            val percentText = "${(progress * 100).toInt()}%"
            views.setTextViewText(R.id.widget_percent_text, if (ringEnabled) percentText else "")

            // Streak
            views.setTextViewText(R.id.widget_streak_text, "🔥 $streak Days Streak")

            // Render progress ring
            val ringBitmap = WidgetHelper.drawProgressRing(context, if (ringEnabled) progress else 0f, color)
            views.setImageViewBitmap(R.id.widget_progress_ring, ringBitmap)

            // Weight card visibility & text
            if (weightEnabled) {
                views.setViewVisibility(R.id.widget_weight_layout, View.VISIBLE)
                if (weight > 0) {
                    views.setTextViewText(R.id.widget_weight_text, String.format(Locale.US, "%.1f kg", weight))
                } else {
                    views.setTextViewText(R.id.widget_weight_text, "--.- kg")
                }
            } else {
                views.setViewVisibility(R.id.widget_weight_layout, View.GONE)
            }

            // Body fat card visibility & category
            if (bodyFatEnabled) {
                views.setViewVisibility(R.id.widget_body_fat_layout, View.VISIBLE)
                if (bodyFat > 0) {
                    // Quick category estimate matching domain categories
                    val categoryName = when {
                        bodyFat < 6f -> "Essential"
                        bodyFat < 14f -> "Athlete"
                        bodyFat < 18f -> "Fitness"
                        bodyFat < 25f -> "Average"
                        else -> "High"
                    }
                    views.setTextViewText(R.id.widget_body_fat_text, String.format(Locale.US, "%.1f%% (%s)", bodyFat, categoryName))
                } else {
                    views.setTextViewText(R.id.widget_body_fat_text, "--.-%")
                }
            } else {
                views.setViewVisibility(R.id.widget_body_fat_layout, View.GONE)
            }

            // Transition info details
            val df = SimpleDateFormat("HH:mm", Locale.getDefault())
            val transitionTimeStr = if (nextTransitionMs > 0) {
                val nextLabel = if (status == "FASTING") "Eating Window" else "Fasting"
                "Next: $nextLabel starts at ${df.format(Date(nextTransitionMs))}"
            } else {
                "No transition set"
            }
            views.setTextViewText(R.id.widget_transition_text, transitionTimeStr)

            // Setup Quick Action PendingIntents
            // 1. Open App
            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.fastflow.action.NAVIGATE"
                putExtra("route", "/")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPending = PendingIntent.getActivity(
                context, 201, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_open_app, openPending)

            // 2. Edit Schedule
            val editIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.fastflow.action.NAVIGATE"
                putExtra("route", "/home/fasting")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val editPending = PendingIntent.getActivity(
                context, 202, editIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_edit_schedule, editPending)

            // 3. Log Weight
            val logIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.fastflow.action.NAVIGATE"
                putExtra("route", "/body_composition")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val logPending = PendingIntent.getActivity(
                context, 203, logIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_log_weight, logPending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
