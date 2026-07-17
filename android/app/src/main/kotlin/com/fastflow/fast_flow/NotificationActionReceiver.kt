package com.fastflow.fast_flow

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "ACTION_DISMISS") {
            // Disable persistent notification setting
            val prefs = context.getSharedPreferences("FastingWidgetPrefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("pref_notification_enabled", false).apply()

            // Stop the ongoing timer service
            val serviceIntent = Intent(context, FastingForegroundService::class.java)
            context.stopService(serviceIntent)

            // Cancel notification view
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(9001)

            // Update app widgets to reflect notification removal
            WidgetHelper.triggerWidgetUpdate(context)
        }
    }
}
