import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/fasting/data/services/timeline_generator.dart';

class ScheduledNotification {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledDate;

  ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
  });
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Reminder Notification Constants ──
  static const int _reminderFastingSoonId = 2000;
  static const int _reminderFastingStartId = 2001;
  static const int _reminderIftarSoonId = 2002;
  static const int _reminderIftarTimeId = 2003;
  static const List<int> _reminderIds = [
    _reminderFastingSoonId,
    _reminderFastingStartId,
    _reminderIftarSoonId,
    _reminderIftarTimeId,
  ];

  // Tracks which reminder IDs have already been delivered today to prevent duplicates
  final Set<int> _deliveredToday = {};
  DateTime _lastDeliveryResetDate = DateTime(0);

  Future<void> init() async {
    if (_initialized) return;
    try {
      _configureLocalTimeZone();

      // Ensure FastingEngine is initialized to handle state queries correctly
      FastingEngine().initialize();

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
            _onNotificationResponse(response);
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
            _onNotificationResponse(response);
          },
        );
      }

      // Automatically reschedule on schedule changes
      HiveService.instance.fastingScheduleBox.watch(key: 'schedule').listen((_) {
        scheduleFastingNotifications();
        scheduleReminderNotifications();
      });

      // Automatically reschedule on settings changes
      HiveService.instance.settingsBox.watch().listen((event) {
        if (event.key == 'notifications_enabled' ||
            event.key == 'eating_notification_enabled' ||
            event.key == 'fasting_notification_enabled') {
          scheduleFastingNotifications();
        }
        // Reschedule reminders on reminder-related settings changes
        if (event.key == 'notifications_enabled' ||
            event.key == 'reminder_fasting_enabled' ||
            event.key == 'reminder_iftar_enabled' ||
            event.key == 'reminder_sound' ||
            event.key == 'reminder_vibration') {
          scheduleReminderNotifications();
        }
      });

      // Automatically reschedule on fasting record changes (e.g. start, edit, complete, delete, resume)
      HiveService.instance.fastingRecordsBox.watch().listen((_) {
        scheduleFastingNotifications();
        scheduleReminderNotifications();
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
      await scheduleReminderNotifications();
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

  /// Recalculates and returns the exact list of notifications to schedule based on active/upcoming fasting state.
  List<ScheduledNotification> calculateNotificationsToSchedule({
    required FastingSchedule schedule,
    required DateTime now,
    required FastingRecord? Function(DateTime expectedStart) getRecordForSession,
    bool eatingEnabled = true,
    bool fastingEnabled = true,
  }) {
    if (!eatingEnabled && !fastingEnabled) return [];

    final List<ScheduledNotification> result = [];
    final sessions = TimelineGenerator.generateTimeline(
      schedule: schedule,
      centerDate: now,
      daysBefore: 2,
      daysAfter: 7,
    );

    int notificationIdCounter = 1000;

    for (final session in sessions) {
      final expectedStart = session.expectedStart;
      final expectedEnd = session.expectedEnd;

      final override = getRecordForSession(expectedStart);
      final actualStart = override?.startTime ?? expectedStart;
      final actualEnd = (override != null && override.status == 'active')
          ? expectedEnd
          : (override?.endTime ?? expectedEnd);

      // Check if fasting session is currently active
      final isFastingActive = (override != null && override.status == 'active') ||
          (override == null && now.isBefore(actualEnd) && (now.isAfter(actualStart) || now.isAtSameMomentAs(actualStart)));

      if (isFastingActive) {
        // Current active session:
        // Schedule only the Eating notification (if eating is enabled and actualEnd is in the future)
        if (eatingEnabled && actualEnd.isAfter(now)) {
          result.add(ScheduledNotification(
            id: notificationIdCounter++,
            title: 'Time to Eat',
            body: 'Congratulations! Your fasting session is complete.',
            scheduledDate: actualEnd,
          ));
        }
      } else if (override == null) {
        // Future scheduled session (starts in the future):
        if (actualStart.isAfter(now)) {
          // Schedule Start Fasting notification
          if (fastingEnabled) {
            result.add(ScheduledNotification(
              id: notificationIdCounter++,
              title: 'Time to Fast',
              body: 'Your fasting window starts now.',
              scheduledDate: actualStart,
            ));
          }

          // Schedule Eating Time notification
          if (eatingEnabled && actualEnd.isAfter(now)) {
            result.add(ScheduledNotification(
              id: notificationIdCounter++,
              title: 'Time to Eat',
              body: 'Congratulations! Your fasting session is complete.',
              scheduledDate: actualEnd,
            ));
          }
        }
      }
    }

    return result;
  }

  Future<void> scheduleFastingNotifications() async {
    try {
      await cancelAll();

      final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
      if (!enabled) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Reschedule completed: notifications disabled');
        }
        return;
      }

      final eatingEnabled = HiveService.instance.getSetting<bool>('eating_notification_enabled') ?? true;
      final fastingEnabled = HiveService.instance.getSetting<bool>('fasting_notification_enabled') ?? true;

      final schedule = HiveService.instance.fastingSchedule;
      final now = DateTime.now();

      final list = calculateNotificationsToSchedule(
        schedule: schedule,
        now: now,
        getRecordForSession: FastingEngine().getRecordForSession,
        eatingEnabled: eatingEnabled,
        fastingEnabled: fastingEnabled,
      );

      for (final n in list) {
        await _scheduleOneShotNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          scheduledDate: n.scheduledDate,
        );
      }

      if (kDebugMode) {
        debugPrint('[NotificationService] Rescheduled ${list.length} notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed scheduling notifications: $e');
      }
    }
  }

  Future<void> _scheduleOneShotNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
        return; // Don't schedule in the past
      }

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
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
      );
      if (kDebugMode) {
        debugPrint('[NotificationService] Notification scheduled: ID $id at $tzDate');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed scheduling notification ID $id: $e');
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

  // ── Reminder Notification System ──

  /// Handles notification response for both existing and reminder notifications
  void _onNotificationResponse(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('[NotificationService] Notification fired: ID ${response.id}');
    }
    // Track delivery for reminder notifications to prevent duplicates on reschedule
    final id = response.id;
    if (id != null && _reminderIds.contains(id)) {
      _deliveredToday.add(id);
      if (kDebugMode) {
        debugPrint('[NotificationService] Reminder ID $id marked as delivered today');
      }
    }
  }

  /// Resets the delivered tracking set at the start of each new calendar day
  void _resetDeliveredIfNewDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastDeliveryResetDate != today) {
      _deliveredToday.clear();
      _lastDeliveryResetDate = today;
    }
  }

  /// Cancels only the four reminder notification IDs without touching existing notifications
  Future<void> cancelReminderNotifications() async {
    for (final id in _reminderIds) {
      await _notifications.cancel(id);
    }
    if (kDebugMode) {
      debugPrint('[NotificationService] Reminder notifications cancelled (IDs 2000-2003)');
    }
  }

  /// Schedules the four fasting reminder notifications based on today's schedule.
  /// Respects delivered-today tracking, enabled settings, and selected sound.
  Future<void> scheduleReminderNotifications() async {
    try {
      // Cancel only reminder IDs, not existing notifications
      await cancelReminderNotifications();
      _resetDeliveredIfNewDay();

      // Check master notification toggle
      final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
      if (!enabled) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Reminders skipped: master notifications disabled');
        }
        return;
      }

      final fastingReminderEnabled = HiveService.instance.getSetting<bool>('reminder_fasting_enabled') ?? true;
      final iftarReminderEnabled = HiveService.instance.getSetting<bool>('reminder_iftar_enabled') ?? true;

      if (!fastingReminderEnabled && !iftarReminderEnabled) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Reminders skipped: both reminder types disabled');
        }
        return;
      }

      // Read sound and vibration preferences
      final soundPref = HiveService.instance.getSetting<String>('reminder_sound') ?? 'default';
      final vibrationEnabled = HiveService.instance.getSetting<bool>('reminder_vibration') ?? true;

      final schedule = HiveService.instance.fastingSchedule;
      final now = DateTime.now();

      // Generate timeline to find the nearest upcoming/active session for today
      final sessions = TimelineGenerator.generateTimeline(
        schedule: schedule,
        centerDate: now,
        daysBefore: 1,
        daysAfter: 1,
      );

      // Find the best session: the first session whose expectedEnd is still in the future
      TimelineSession? targetSession;
      for (final session in sessions) {
        if (session.expectedEnd.isAfter(now)) {
          targetSession = session;
          break;
        }
      }

      if (targetSession == null) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Reminders skipped: no upcoming session found');
        }
        return;
      }

      final fastStart = targetSession.expectedStart;
      final fastEnd = targetSession.expectedEnd;

      // Build the list of reminders to schedule
      final List<ScheduledNotification> reminders = [];

      if (fastingReminderEnabled) {
        reminders.add(ScheduledNotification(
          id: _reminderFastingSoonId,
          title: 'Fasting Starts Soon',
          body: 'Your fasting will begin in 10 minutes.',
          scheduledDate: fastStart.subtract(const Duration(minutes: 10)),
        ));
        reminders.add(ScheduledNotification(
          id: _reminderFastingStartId,
          title: 'Fasting Started',
          body: 'Your fasting has officially begun.',
          scheduledDate: fastStart,
        ));
      }

      if (iftarReminderEnabled) {
        reminders.add(ScheduledNotification(
          id: _reminderIftarSoonId,
          title: 'Iftar is Almost Here',
          body: 'Only 10 minutes remaining until it\'s time to break your fast.',
          scheduledDate: fastEnd.subtract(const Duration(minutes: 10)),
        ));
        reminders.add(ScheduledNotification(
          id: _reminderIftarTimeId,
          title: 'It\'s Time to Break Your Fast',
          body: 'May your fasting be accepted. Enjoy your meal.',
          scheduledDate: fastEnd,
        ));
      }

      int scheduledCount = 0;
      for (final reminder in reminders) {
        // Skip if already delivered today
        if (_deliveredToday.contains(reminder.id)) {
          if (kDebugMode) {
            debugPrint('[NotificationService] Reminder ID ${reminder.id} already delivered today, skipping');
          }
          continue;
        }

        // Skip if scheduled time is in the past
        if (reminder.scheduledDate.isBefore(now) || reminder.scheduledDate.isAtSameMomentAs(now)) {
          if (kDebugMode) {
            debugPrint('[NotificationService] Reminder ID ${reminder.id} time has passed (${reminder.scheduledDate}), skipping');
          }
          continue;
        }

        await _scheduleReminderNotification(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: reminder.scheduledDate,
          soundPref: soundPref,
          vibrationEnabled: vibrationEnabled,
        );
        scheduledCount++;
      }

      if (kDebugMode) {
        debugPrint('[NotificationService] Scheduled $scheduledCount reminder notification(s)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed scheduling reminder notifications: $e');
      }
    }
  }

  /// Schedules a single reminder notification with the configured sound and vibration.
  Future<void> _scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String soundPref,
    required bool vibrationEnabled,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    AndroidNotificationDetails defaultDetails() => AndroidNotificationDetails(
      'fasting_reminders',
      'Fasting Reminders',
      channelDescription: 'Fasting reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: vibrationEnabled,
    );

    AndroidNotificationDetails androidDetails;
    bool usesCustomSound = false;

    switch (soundPref) {
      case 'app_notification':
      case 'bell':
      case 'adhan':
        androidDetails = AndroidNotificationDetails(
          'fasting_reminders_app',
          'Fasting Reminders (App Notification)',
          channelDescription: 'Fasting reminder notifications with app sound',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('bell'),
          enableVibration: vibrationEnabled,
        );
        usesCustomSound = true;
        break;
      case 'silent':
        androidDetails = AndroidNotificationDetails(
          'fasting_reminders_silent',
          'Fasting Reminders (Silent)',
          channelDescription: 'Fasting reminder notifications without sound',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: vibrationEnabled,
        );
        break;
      default:
        androidDetails = defaultDetails();
    }

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundPref != 'silent',
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      if (kDebugMode) {
        debugPrint('[NotificationService] Reminder scheduled: ID $id "$title" at $tzDate (sound: $soundPref)');
      }
    } catch (e) {
      if (usesCustomSound) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Custom sound "$soundPref" failed, falling back to default: $e');
        }
        try {
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            tzDate,
            NotificationDetails(android: defaultDetails(), iOS: iosDetails),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          if (kDebugMode) {
            debugPrint('[NotificationService] Reminder scheduled with default sound fallback: ID $id "$title" at $tzDate');
          }
        } catch (fallbackError) {
          if (kDebugMode) {
            debugPrint('[NotificationService] Failed scheduling reminder ID $id even with default fallback: $fallbackError');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('[NotificationService] Failed scheduling reminder ID $id: $e');
        }
      }
    }
  }
}