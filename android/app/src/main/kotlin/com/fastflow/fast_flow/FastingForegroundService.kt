package com.fastflow.fast_flow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FastingForegroundService : Service() {

    private val CHANNEL_ID = "fast_flow_ongoing_channel"
    private val NOTIFICATION_ID = 9001

    private val handler = Handler(Looper.getMainLooper())
    private val tickRunnable = object : Runnable {
        override fun run() {
            updateNotificationAndWidgets()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP_SERVICE") {
            stopSelf()
            return START_NOT_STICKY
        }

        // Start foreground immediately with a placeholder to satisfy Android OS timing requirements
        val notification = buildPlaceholderNotification()
        startForeground(NOTIFICATION_ID, notification)

        handler.removeCallbacks(tickRunnable)
        handler.post(tickRunnable)

        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tickRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Fasting Countdown Tracker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live ongoing fasting timer countdown and quick action triggers"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildPlaceholderNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Fomo IF Active")
            .setContentText("Calculating remaining time...")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotificationAndWidgets() {
        val prefs = getSharedPreferences("FastingWidgetPrefs", Context.MODE_PRIVATE)
        val status = prefs.getString("status", "COMPLETED") ?: "COMPLETED"
        val startTimeMs = prefs.getLong("start_time_ms", 0L)
        val endTimeMs = prefs.getLong("end_time_ms", 0L)
        val nextTransitionMs = prefs.getLong("next_transition_ms", 0L)
        val streak = prefs.getInt("current_streak", 0)

        val weight = prefs.getFloat("latest_weight", 0f)
        val bodyFat = prefs.getFloat("latest_body_fat", 0f)

        val notificationEnabled = prefs.getBoolean("pref_notification_enabled", true)
        val countdownEnabled = prefs.getBoolean("pref_countdown_enabled", true)

        if (!notificationEnabled) {
            stopSelf()
            return
        }

        val label = WidgetHelper.getStatusLabel(status)
        val color = WidgetHelper.getStatusColor(this, status)

        val now = System.currentTimeMillis()
        val totalSec = (endTimeMs - startTimeMs) / 1000
        val elapsedSec = (now - startTimeMs) / 1000
        val remainingSec = (endTimeMs - now) / 1000

        val progress = if (totalSec > 0) {
            val p = elapsedSec.toFloat() / totalSec.toFloat()
            p.coerceIn(0f, 1f)
        } else 0f

        val elapsedStr = if (elapsedSec > 0) {
            val hrs = elapsedSec / 3600
            val mins = (elapsedSec % 3600) / 60
            "${hrs}h ${mins}m"
        } else {
            "0h 0m"
        }

        val remainingStr = if (remainingSec > 0) {
            val hrs = remainingSec / 3600
            val mins = (remainingSec % 3600) / 60
            "${hrs}h ${mins}m"
        } else {
            "0h 0m"
        }

        val df = SimpleDateFormat("HH:mm", Locale.getDefault())
        val transitionTimeStr = if (nextTransitionMs > 0) {
            val nextLabel = if (status == "FASTING") "Eating Window" else "Fasting"
            "$nextLabel starts at ${df.format(Date(nextTransitionMs))}"
        } else {
            "No transition scheduled"
        }

        // Setup custom RemoteViews
        val collapsedViews = RemoteViews(packageName, R.layout.notification_collapsed)
        val expandedViews = RemoteViews(packageName, R.layout.notification_expanded)

        // Collapsed status icon
        val iconRes = when (status) {
            "FASTING" -> R.drawable.ic_nightlight
            "EATINGWINDOW", "EATING_WINDOW" -> R.drawable.ic_restaurant
            "PREPARING" -> R.drawable.ic_timer
            "COMPLETED" -> R.drawable.ic_flag
            else -> R.drawable.ic_schedule
        }
        collapsedViews.setImageViewResource(R.id.notification_status_icon, iconRes)
        collapsedViews.setInt(R.id.notification_status_icon, "setColorFilter", color)

        // Collapsed texts
        collapsedViews.setTextViewText(R.id.notification_status_title, label)
        collapsedViews.setTextColor(R.id.notification_status_title, color)
        collapsedViews.setTextViewText(R.id.notification_subtitle, if (countdownEnabled) "$remainingStr remaining" else "Active")

        val timerStr = if (remainingSec > 0) {
            WidgetHelper.formatCountdown(remainingSec)
        } else {
            "00:00:00"
        }
        collapsedViews.setTextViewText(R.id.notification_large_timer, timerStr)

        // Collapsed progress
        val collapsedProgressBitmap = WidgetHelper.drawHorizontalProgressBar(this, progress, color)
        collapsedViews.setImageViewBitmap(R.id.notification_progress_bar, collapsedProgressBitmap)

        // Expanded texts
        expandedViews.setTextViewText(R.id.notification_expanded_status, label)
        expandedViews.setTextColor(R.id.notification_expanded_status, color)
        expandedViews.setTextViewText(R.id.notification_expanded_timer, timerStr)

        // Expanded progress
        val expandedProgressBitmap = WidgetHelper.drawHorizontalProgressBar(this, progress, color)
        expandedViews.setImageViewBitmap(R.id.notification_expanded_progress, expandedProgressBitmap)

        // Grid details
        expandedViews.setTextViewText(R.id.notification_elapsed_text, elapsedStr)
        expandedViews.setTextViewText(R.id.notification_remaining_text, remainingStr)
        expandedViews.setTextViewText(R.id.notification_next_text, transitionTimeStr)

        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        val scheduleRangeStr = if (startTimeMs > 0 && endTimeMs > 0) {
            "${timeFormat.format(Date(startTimeMs))} → ${timeFormat.format(Date(endTimeMs))}"
        } else {
            "--:-- → --:--"
        }
        expandedViews.setTextViewText(R.id.notification_schedule_text, scheduleRangeStr)

        // Body Stats Strip
        val weightStr = if (weight > 0) String.format(Locale.US, "Weight: %.1f kg", weight) else "Weight: --.- kg"
        val bodyFatStr = if (bodyFat > 0) String.format(Locale.US, "Body Fat: %.1f%%", bodyFat) else "Body Fat: --.-%"
        expandedViews.setTextViewText(R.id.notification_weight_text, weightStr)
        expandedViews.setTextViewText(R.id.notification_body_fat_text, bodyFatStr)
        expandedViews.setTextViewText(R.id.notification_streak_text, "Streak: $streak Days")

        // Setup PendingIntents for actions
        val openIntent = PendingIntent.getActivity(
            this, 301,
            Intent(this, MainActivity::class.java).apply {
                action = "com.fastflow.action.NAVIGATE"
                putExtra("route", "/")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val editIntent = PendingIntent.getActivity(
            this, 302,
            Intent(this, MainActivity::class.java).apply {
                action = "com.fastflow.action.NAVIGATE"
                putExtra("route", "/home/fasting")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val logIntent = PendingIntent.getActivity(
            this, 303,
            Intent(this, MainActivity::class.java).apply {
                action = "com.fastflow.action.NAVIGATE"
                putExtra("route", "/body_composition")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Setup action listeners on RemoteViews buttons
        expandedViews.setOnClickPendingIntent(R.id.notification_action_dashboard, openIntent)
        expandedViews.setOnClickPendingIntent(R.id.notification_action_weight, logIntent)
        expandedViews.setOnClickPendingIntent(R.id.notification_action_schedule, editIntent)
        expandedViews.setOnClickPendingIntent(R.id.notification_action_body, logIntent)

        // Build notification
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomContentView(collapsedViews)
            .setCustomBigContentView(expandedViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setColor(color)
            .setContentIntent(openIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, builder.build())

        // Also trigger widget updates
        WidgetHelper.triggerWidgetUpdate(this)
    }
}
