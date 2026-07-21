import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fast_flow/core/services/hive_service.dart';
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
        await _notifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (response) {
            if (kDebugMode) {
              debugPrint('[NotificationService] Notification fired: ID ${response.id}');
            }
          },
        );
      } catch (iconError) {
        assert(() {
          debugPrint('NotificationService: Failed initializing with primary icon: $iconError');
          return true;
        }());
        const fallbackAndroidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const fallbackInitSettings = InitializationSettings(
          android: fallbackAndroidInit,
          iOS: iosInit,
        );
        await _notifications.initialize(
          fallbackInitSettings,
          onDidReceiveNotificationResponse: (response) {
            if (kDebugMode) {
              debugPrint('[NotificationService] Notification fired: ID ${response.id}');
            }
          },
        );
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

      // Verify/Request notification permission status and log
      final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
      if (enabled) {
        await requestPermissions();
      } else {
        if (kDebugMode) {
          debugPrint('[NotificationService] Permission status: disabled in settings');
        }
      }

      if (kDebugMode) {
        debugPrint('[NotificationService] Notification service initialized');
      }

      // Schedule initially on startup
      await scheduleFastingNotifications();
    } catch (e, stackTrace) {
      assert(() {
        debugPrint('NotificationService: Critical initialization failure: $e\n$stackTrace');
        return true;
      }());
    }
  }

  void _configureLocalTimeZone() {
    try {
      tz.initializeTimeZones();
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      
      String? matchedLocation;
      for (final entry in tz.timeZoneDatabase.locations.entries) {
        final loc = entry.value;
        if (loc.timeZone(nowMs).offset == offsetMs) {
          matchedLocation = entry.key;
          break;
        }
      }
      
      if (matchedLocation != null) {
        tz.setLocalLocation(tz.getLocation(matchedLocation));
      } else {
        tz.setLocalLocation(tz.UTC);
      }
      if (kDebugMode) {
        debugPrint('[NotificationService] Timezone configured: ${tz.local.name}');
      }
    } catch (e) {
      assert(() {
        debugPrint('NotificationService: Failed to configure local timezone: $e');
        return true;
      }());
    }
  }

  Future<bool?> requestPermissions() async {
    try {
      bool? status;
      if (Platform.isAndroid) {
        final androidNotifications = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        status = await androidNotifications?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final iosNotifications = _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        status = await iosNotifications?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (kDebugMode) {
        debugPrint('[NotificationService] Permission status: $status');
      }
      return status ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed requesting permissions: $e');
      }
      return false;
    }
  }

  Future<void> scheduleFastingNotifications() async {
    try {
      await _notifications.cancelAll();
      if (kDebugMode) {
        debugPrint('[NotificationService] Notification cancelled');
      }

      final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
      if (!enabled) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Reschedule completed: notifications disabled');
        }
        return;
      }

      final FastingSchedule? schedule = HiveService.instance.fastingScheduleBox.get('schedule');
      if (schedule == null) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Reschedule completed: no schedule found');
        }
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
            title: '🌙 Time to Fast',
            body: 'Your fasting session has started.\nStay hydrated and keep going.',
            hour: daySched.fastHour,
            minute: daySched.fastMin,
            weekday: day,
          );
        }

        // Eating window start notification (even IDs)
        if (eatingEnabled) {
          await _scheduleDailyNotification(
            id: day * 2,
            title: '🍽 Time to Eat',
            body: 'Your eating window has started.\nEnjoy your meal and stay within your calorie goal.',
            hour: daySched.eatHour,
            minute: daySched.eatMin,
            weekday: day,
          );
        }
      }
      if (kDebugMode) {
        debugPrint('[NotificationService] Reschedule completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed scheduling notifications: $e');
      }
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
            playSound: true,
            enableVibration: true,
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
      if (kDebugMode) {
        debugPrint('[NotificationService] Notification scheduled: ID $id at $scheduledDate');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed scheduling daily notification ID $id: $e');
      }
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
      if (kDebugMode) {
        debugPrint('[NotificationService] Notification cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed to cancel all notifications: $e');
      }
    }
  }
}