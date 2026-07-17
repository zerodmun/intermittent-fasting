import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(initSettings);

    // Request permissions
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleScheduleNotifications(FastingSchedule schedule) async {
    await _notifications.cancelAll();

    for (int day = 1; day <= 7; day++) {
      final daySched = schedule.getScheduleFor(day);

      // Fasting start notification
      await _scheduleDailyNotification(
        id: day * 2 - 1,
        title: 'Fasting Started',
        body: 'Your fasting period has begun. Stay strong!',
        hour: daySched.fastHour,
        minute: daySched.fastMin,
        weekday: day,
      );

      // Eating window start notification
      await _scheduleDailyNotification(
        id: day * 2,
        title: 'Eating Window Opened',
        body: 'Your eating window has started. Enjoy your meals!',
        hour: daySched.eatHour,
        minute: daySched.eatMin,
        weekday: day,
      );
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
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekday(weekday, hour, minute),
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
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Adjust to target weekday (1=Monday...7=Sunday)
    int daysAhead = weekday - scheduledDate.weekday;
    if (daysAhead <= 0) daysAhead += 7;

    scheduledDate = scheduledDate.add(Duration(days: daysAhead));

    // If it's today but time has passed, schedule for next week
    if (daysAhead == 0 && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}