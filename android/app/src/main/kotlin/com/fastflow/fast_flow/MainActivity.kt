package com.fastflow.fast_flow

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fastflow.app/widget_sync"
    private var initialRoute: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        if (route != null) {
            initialRoute = route
            methodChannel?.invokeMethod("navigate", route)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> {
                    val route = initialRoute
                    initialRoute = null // clear so we only consume it once
                    result.success(route)
                }
                "syncState" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args != null) {
                        saveToSharedPrefs(args)
                        toggleForegroundService(args)
                        WidgetHelper.triggerWidgetUpdate(this)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Arguments map is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveToSharedPrefs(data: Map<String, Any>) {
        val prefs = getSharedPreferences("FastingWidgetPrefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()

        editor.putString("status", data["status"] as? String ?: "COMPLETED")
        editor.putString("phase", data["phase"] as? String ?: "eating")
        editor.putLong("start_time_ms", (data["start_time_ms"] as? Number)?.toLong() ?: 0L)
        editor.putLong("end_time_ms", (data["end_time_ms"] as? Number)?.toLong() ?: 0L)
        editor.putLong("next_transition_ms", (data["next_transition_ms"] as? Number)?.toLong() ?: 0L)
        editor.putInt("current_streak", (data["current_streak"] as? Number)?.toInt() ?: 0)

        editor.putFloat("latest_weight", (data["latest_weight"] as? Number)?.toFloat() ?: 0f)
        editor.putFloat("latest_body_fat", (data["latest_body_fat"] as? Number)?.toFloat() ?: 0f)

        editor.putBoolean("pref_widget_enabled", data["pref_widget_enabled"] as? Boolean ?: true)
        editor.putBoolean("pref_notification_enabled", data["pref_notification_enabled"] as? Boolean ?: true)
        editor.putBoolean("pref_countdown_enabled", data["pref_countdown_enabled"] as? Boolean ?: true)
        editor.putBoolean("pref_ring_enabled", data["pref_ring_enabled"] as? Boolean ?: true)
        editor.putBoolean("pref_body_fat_enabled", data["pref_body_fat_enabled"] as? Boolean ?: true)
        editor.putBoolean("pref_weight_enabled", data["pref_weight_enabled"] as? Boolean ?: true)

        editor.apply()
    }

    private fun toggleForegroundService(data: Map<String, Any>) {
        val notificationEnabled = data["pref_notification_enabled"] as? Boolean ?: true
        val serviceIntent = Intent(this, FastingForegroundService::class.java)

        if (notificationEnabled) {
            ContextCompat.startForegroundService(this, serviceIntent)
        } else {
            stopService(serviceIntent)
        }
    }
}
