package com.fastflow.fast_flow

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.*
import android.util.Log

object WidgetHelper {

    fun drawProgressRing(context: Context, progress: Float, strokeColor: Int): Bitmap {
        val size = 200
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val outlineColor = if (isDark) Color.parseColor("#334155") else Color.parseColor("#E2E8F0")

        val bgPaint = Paint().apply {
            color = outlineColor
            style = Paint.Style.STROKE
            strokeWidth = 14f
            isAntiAlias = true
        }

        val activePaint = Paint().apply {
            color = strokeColor
            style = Paint.Style.STROKE
            strokeWidth = 14f
            strokeCap = Paint.Cap.ROUND
            isAntiAlias = true
        }

        val padding = 16f
        val rect = RectF(padding, padding, size - padding, size - padding)

        canvas.drawCircle(size / 2f, size / 2f, (size - padding * 2) / 2f, bgPaint)
        canvas.drawArc(rect, -90f, progress * 360f, false, activePaint)

        return bitmap
    }

    fun drawHorizontalProgressBar(context: Context, progress: Float, strokeColor: Int): Bitmap {
        val width = 600
        val height = 16
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val outlineColor = if (isDark) Color.parseColor("#334155") else Color.parseColor("#E2E8F0")

        val bgPaint = Paint().apply {
            color = outlineColor
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        val activePaint = Paint().apply {
            color = strokeColor
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        val rectBg = RectF(0f, 0f, width.toFloat(), height.toFloat())
        canvas.drawRoundRect(rectBg, height / 2f, height / 2f, bgPaint)

        val activeWidth = width * progress
        if (activeWidth > 0) {
            val rectActive = RectF(0f, 0f, activeWidth, height.toFloat())
            canvas.drawRoundRect(rectActive, height / 2f, height / 2f, activePaint)
        }

        return bitmap
    }

    fun getStatusColor(context: Context, status: String): Int {
        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        return when (status) {
            "PREPARING" -> if (isDark) Color.parseColor("#60A5FA") else Color.parseColor("#3B82F6")
            "FASTING" -> if (isDark) Color.parseColor("#34D399") else Color.parseColor("#10B981")
            "EATINGWINDOW", "EATING_WINDOW" -> if (isDark) Color.parseColor("#FB923C") else Color.parseColor("#F97316")
            "COMPLETED" -> if (isDark) Color.parseColor("#2DD4BF") else Color.parseColor("#14B8A6")
            else -> if (isDark) Color.parseColor("#6B7280") else Color.parseColor("#94A3B8") // SKIPPED, CANCELLED, etc.
        }
    }

    fun getStatusLabel(status: String): String {
        return when (status) {
            "PREPARING" -> "PREPARING"
            "FASTING" -> "FASTING"
            "EATINGWINDOW", "EATING_WINDOW" -> "EATING WINDOW"
            "COMPLETED" -> "COMPLETED"
            else -> "SKIPPED"
        }
    }

    fun formatDuration(seconds: Long): String {
        val hrs = seconds / 3600
        val mins = (seconds % 3600) / 60
        val secs = seconds % 60
        return String.format("%02dh %02dm %02ds", hrs, mins, secs)
    }

    fun formatCountdown(seconds: Long): String {
        val hrs = seconds / 3600
        val mins = (seconds % 3600) / 60
        val secs = seconds % 60
        return String.format("%02d:%02d:%02d", hrs, mins, secs)
    }

    fun triggerWidgetUpdate(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)

            // Small
            val smallComponent = ComponentName(context, FastingWidgetProviderSmall::class.java)
            val smallIds = appWidgetManager.getAppWidgetIds(smallComponent)
            if (smallIds.isNotEmpty()) {
                val intent = Intent(context, FastingWidgetProviderSmall::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, smallIds)
                }
                context.sendBroadcast(intent)
            }

            // Medium
            val mediumComponent = ComponentName(context, FastingWidgetProviderMedium::class.java)
            val mediumIds = appWidgetManager.getAppWidgetIds(mediumComponent)
            if (mediumIds.isNotEmpty()) {
                val intent = Intent(context, FastingWidgetProviderMedium::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, mediumIds)
                }
                context.sendBroadcast(intent)
            }

            // Large
            val largeComponent = ComponentName(context, FastingWidgetProviderLarge::class.java)
            val largeIds = appWidgetManager.getAppWidgetIds(largeComponent)
            if (largeIds.isNotEmpty()) {
                val intent = Intent(context, FastingWidgetProviderLarge::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, largeIds)
                }
                context.sendBroadcast(intent)
            }
        } catch (e: Exception) {
            Log.e("WidgetHelper", "Error forcing widget update broadcast: ${e.message}")
        }
    }
}
