import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:fast_flow/features/fasting/models/fasting_schedule.dart';

/// Manages local notifications for fasting reminders.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'fastflow_fasting';
  static const _channelName = 'Fasting Reminders';
  static const _channelDesc = 'Notifications for fasting and eating windows';

  /// Initialize the notification plugin.
  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);
  }

  /// Request notification permissions (especially for Android 13+).
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a notification at a specific time.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

      if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) return;

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  /// Schedule fasting start notification.
  Future<void> scheduleFastingStart(DateTime time) async {
    await scheduleNotification(
      id: 100,
      title: '🍽️ Time to start fasting!',
      body: 'Your eating window has ended. Stay strong!',
      scheduledTime: time,
    );
  }

  /// Schedule eating window notification.
  Future<void> scheduleEatingStart(DateTime time) async {
    await scheduleNotification(
      id: 101,
      title: '🎉 Eating window is open!',
      body: 'Great job completing your fast! Enjoy your meal.',
      scheduledTime: time,
    );
  }

  /// Schedule fasting end notification.
  Future<void> scheduleFastingEnd(DateTime time) async {
    await scheduleNotification(
      id: 102,
      title: '✅ Fasting complete!',
      body: 'You\'ve reached your fasting goal. Well done!',
      scheduledTime: time,
    );
  }

  /// Schedule a daily reminder at the given hour and minute.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      200,
      '⏰ Daily Reminder',
      'Don\'t forget your fasting plan today!',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a specific notification.
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Schedule notifications for the next 14 days of the schedule.
  Future<void> scheduleScheduleNotifications(FastingSchedule schedule) async {
    try {
      await cancelAll();
      final now = DateTime.now();
      // Schedule for the next 14 days
      int idCounter = 1000;
      for (int i = 0; i < 14; i++) {
        final date = now.add(Duration(days: i));
        final dateOnly = DateTime(date.year, date.month, date.day);
        final daySched = schedule.getScheduleFor(dateOnly.weekday);

        final fastingTime = DateTime(
          dateOnly.year,
          dateOnly.month,
          dateOnly.day,
          daySched['fastHour']!,
          daySched['fastMin']!,
        );
        final eatingTime = DateTime(
          dateOnly.year,
          dateOnly.month,
          dateOnly.day,
          daySched['eatHour']!,
          daySched['eatMin']!,
        );

        if (fastingTime.isAfter(now)) {
          await scheduleNotification(
            id: idCounter++,
            title: '🍽️ Fasting period started!',
            body: 'Your fasting period has started. Stay hydrated!',
            scheduledTime: fastingTime,
          );
        }
        if (eatingTime.isAfter(now)) {
          await scheduleNotification(
            id: idCounter++,
            title: '🎉 Eating window begun!',
            body: 'Your eating window has begun. Eat mindfully.',
            scheduledTime: eatingTime,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to schedule fasting schedule notifications: $e');
    }
  }
}
