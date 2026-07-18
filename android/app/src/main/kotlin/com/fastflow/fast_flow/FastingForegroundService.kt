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

    private var lastTimerStr = ""
    private var lastStatus = ""
    private var lastProgressInt = -1
    private var lastWeight = 0f
    private var lastBodyFat = 0f
    private var lastStreak = -1

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

        val timerStr = if (remainingSec > 0) {
            WidgetHelper.formatCountdownMinutes(remainingSec)
        } else {
            "00:00"
        }
        val timerStrSeconds = if (remainingSec > 0) {
            WidgetHelper.formatCountdown(remainingSec)
        } else {
            "00:00:00"
        }

        val progressInt = (progress * 100).toInt()

        // Check if any visible value changed. If not, bypass rebuilding & notify() to optimize resource usage.
        if (timerStrSeconds == lastTimerStr &&
            status == lastStatus &&
            progressInt == lastProgressInt &&
            weight == lastWeight &&
            bodyFat == lastBodyFat &&
            streak == lastStreak
        ) {
            // No visible change. Re-trigger widget update just in case, then return early.
            WidgetHelper.triggerWidgetUpdate(this)
            return
        }

        // Cache the new values
        lastTimerStr = timerStrSeconds
        lastStatus = status
        lastProgressInt = progressInt
        lastWeight = weight
        lastBodyFat = bodyFat
        lastStreak = streak

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
        collapsedViews.setTextViewText(R.id.notification_large_timer, timerStr)

        // Collapsed progress
        collapsedViews.setProgressBar(R.id.notification_progress_bar, 100, progressInt, false)

        // Emoji status label for expanded layout
        val emojiLabel = when (status) {
            "FASTING" -> "🌙 FASTING"
            "EATINGWINDOW", "EATING_WINDOW" -> "🍽 EATING WINDOW"
            "PREPARING" -> "🍽 PREPARING"
            "COMPLETED" -> "✓ COMPLETED"
            "SKIPPED" -> "✕ SKIPPED"
            "CANCELLED" -> "✕ CANCELLED"
            else -> "🍽 EATING WINDOW"
        }

        // Expanded texts
        expandedViews.setTextViewText(R.id.notification_expanded_status, emojiLabel)
        expandedViews.setTextColor(R.id.notification_expanded_status, color)
        expandedViews.setTextViewText(R.id.notification_expanded_timer, timerStrSeconds)

        // Expanded progress
        expandedViews.setProgressBar(R.id.notification_expanded_progress, 100, progressInt, false)

        // Format dates for top section
        val dayFormat = SimpleDateFormat("E, HH:mm", Locale.getDefault())
        val startFormatted = if (startTimeMs > 0) dayFormat.format(Date(startTimeMs)) else "--, --:--"
        val endFormatted = if (endTimeMs > 0) dayFormat.format(Date(endTimeMs)) else "--, --:--"
        expandedViews.setTextViewText(R.id.notification_start_time_text, startFormatted)
        expandedViews.setTextViewText(R.id.notification_end_time_text, endFormatted)

        // Secondary Info line (Elapsed + Goal or Next Transition)
        val secondaryInfoStr = if (status == "FASTING") {
            val goalHours = (endTimeMs - startTimeMs) / 3600000
            val goalStr = if ((endTimeMs - startTimeMs) % 3600000 == 0L) "${goalHours}h" else String.format(Locale.US, "%.1fh", (endTimeMs - startTimeMs).toFloat() / 3600000f)
            "Elapsed $elapsedStr • Goal $goalStr"
        } else {
            val dfTime = SimpleDateFormat("HH:mm", Locale.getDefault())
            val endFormattedTime = if (endTimeMs > 0) dfTime.format(Date(endTimeMs)) else "--:--"
            val nextLabel = if (status == "FASTING") "Eating" else "Fasting"
            "Next: $nextLabel at $endFormattedTime"
        }
        expandedViews.setTextViewText(R.id.notification_secondary_info_text, secondaryInfoStr)

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

        // Setup action listeners on RemoteViews buttons
        expandedViews.setOnClickPendingIntent(R.id.notification_action_complete, editIntent)
        expandedViews.setOnClickPendingIntent(R.id.notification_action_skip, editIntent)
        expandedViews.setOnClickPendingIntent(R.id.notification_action_open, openIntent)

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
