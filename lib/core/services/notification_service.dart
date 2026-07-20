import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _configureLocalTimeZone();

      // Attempt initialization with primary launcher_icon resource
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      try {
        await _notifications.initialize(initSettings);
      } catch (iconError) {
        assert(() {
          print('NotificationService: Failed initializing with primary icon: $iconError');
          return true;
        }());
        const fallbackAndroidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const fallbackInitSettings = InitializationSettings(
          android: fallbackAndroidInit,
          iOS: iosInit,
        );
        await _notifications.initialize(fallbackInitSettings);
      }

      // Automatically reschedule on schedule changes
      HiveService.instance.fastingScheduleBox.watch(key: 'schedule').listen((_) {
        scheduleFastingNotifications();
      });

      // Automatically reschedule on settings changes
      HiveService.instance.settingsBox.watch().listen((event) {
        if (event.key == 'notifications_enabled' ||
            event.key == 'eating_notification_enabled' ||
            event.key == 'fasting_notification_enabled') {
          scheduleFastingNotifications();
        }
      });

      _initialized = true;

      // Schedule initially on startup
      await scheduleFastingNotifications();
    } catch (e, stackTrace) {
      assert(() {
        print('NotificationService: Critical initialization failure: $e\n$stackTrace');
        return true;
      }());
    }
  }

  void _configureLocalTimeZone() {
    try {
      tz.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours;
      final sign = hours >= 0 ? '-' : '+';
      final absHours = hours.abs();
      final gmtName = 'Etc/GMT$sign$absHours';
      try {
        final loc = tz.getLocation(gmtName);
        tz.setLocalLocation(loc);
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      assert(() {
        print('NotificationService: Failed to configure local timezone: $e');
        return true;
      }());
    }
  }

  Future<bool?> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidNotifications = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidNotifications?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final iosNotifications = _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await iosNotifications?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      return false;
    } catch (e) {
      assert(() {
        print('NotificationService: Failed requesting permissions: $e');
        return true;
      }());
      return false;
    }
  }

  Future<void> scheduleFastingNotifications() async {
    try {
      await _notifications.cancelAll();

      final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
      if (!enabled) {
        return;
      }

      final schedule = HiveService.instance.fastingScheduleBox.get('schedule');
      if (schedule == null) {
        return;
      }

      final eatingEnabled = HiveService.instance.getSetting<bool>('eating_notification_enabled') ?? true;
      final fastingEnabled = HiveService.instance.getSetting<bool>('fasting_notification_enabled') ?? true;

      for (int day = 1; day <= 7; day++) {
        final daySched = schedule.getScheduleFor(day);

        // Fasting start notification (odd IDs)
        if (fastingEnabled) {
          await _scheduleDailyNotification(
            id: day * 2 - 1,
            title: '🌙 Fasting Started',
            body: 'Your fasting timer has started.\nStay hydrated and keep going!',
            hour: daySched.fastHour,
            minute: daySched.fastMin,
            weekday: day,
          );
        }

        // Eating window start notification (even IDs)
        if (eatingEnabled) {
          await _scheduleDailyNotification(
            id: day * 2,
            title: '🍽 Eating Window Started',
            body: 'Your eating window is now open.\nRemember to eat balanced meals and stay hydrated.',
            hour: daySched.eatHour,
            minute: daySched.eatMin,
            weekday: day,
          );
        }
      }
    } catch (e) {
      assert(() {
        print('NotificationService: Failed scheduling notifications: $e');
        return true;
      }());
    }
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
  }) async {
    try {
      final scheduledDate = _nextInstanceOfWeekday(weekday, hour, minute);
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fasting_schedule',
            'Fasting Schedule',
            channelDescription: 'Notifications for fasting and eating windows',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      assert(() {
        print('NotificationService: Failed scheduling daily notification ID $id: $e');
        return true;
      }());
    }
  }

  @visibleForTesting
  tz.TZDateTime nextInstanceOfWeekday(int weekday, int hour, int minute) {
    return _nextInstanceOfWeekday(weekday, hour, minute);
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Adjust to target weekday (1=Monday...7=Sunday)
    int daysAhead = weekday - now.weekday;
    if (daysAhead < 0) {
      daysAhead += 7;
    } else if (daysAhead == 0 && scheduledDate.isBefore(now)) {
      daysAhead += 7;
    }

    scheduledDate = scheduledDate.add(Duration(days: daysAhead));
    return scheduledDate;
  }

  Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      assert(() {
        print('NotificationService: Failed to cancel all notifications: $e');
        return true;
      }());
    }
  }
}