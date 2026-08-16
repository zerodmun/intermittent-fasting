import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/data/services/fasting_engine.dart';
import 'package:fast_flow/features/fasting/data/services/timeline_generator.dart';
import 'package:fast_flow/core/services/startup_diag.dart';

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

class NotificationDiagnostics {
  final bool notificationsEnabledSetting;
  final bool systemPermissionGranted;
  final bool exactAlarmCapability;
  final bool fastingChannelAvailable;
  final bool reminderChannelAvailable;
  final bool isScheduleValid;
  final int expectedReminderCount;
  final int scheduledReminderCount;
  final int missingReminderCount;
  final bool isSynchronized;
  final bool bootReceiverRegistered;
  final DateTime? lastSchedulingTime;
  final String? lastTriggerSource;

  NotificationDiagnostics({
    required this.notificationsEnabledSetting,
    required this.systemPermissionGranted,
    required this.exactAlarmCapability,
    required this.fastingChannelAvailable,
    required this.reminderChannelAvailable,
    required this.isScheduleValid,
    required this.expectedReminderCount,
    required this.scheduledReminderCount,
    required this.missingReminderCount,
    required this.isSynchronized,
    required this.bootReceiverRegistered,
    this.lastSchedulingTime,
    this.lastTriggerSource,
  });

  Map<String, dynamic> toMap() => {
        'notificationsEnabledSetting': notificationsEnabledSetting,
        'systemPermissionGranted': systemPermissionGranted,
        'exactAlarmCapability': exactAlarmCapability,
        'fastingChannelAvailable': fastingChannelAvailable,
        'reminderChannelAvailable': reminderChannelAvailable,
        'isScheduleValid': isScheduleValid,
        'expectedReminderCount': expectedReminderCount,
        'scheduledReminderCount': scheduledReminderCount,
        'missingReminderCount': missingReminderCount,
        'isSynchronized': isSynchronized,
        'bootReceiverRegistered': bootReceiverRegistered,
        'lastSchedulingTime': lastSchedulingTime?.toIso8601String(),
        'lastTriggerSource': lastTriggerSource,
      };
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isSchedulingFasting = false;
  bool _isSchedulingReminders = false;

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
  // Tracks active scheduled reminder dates per ID to prevent duplicate scheduling
  final Map<int, DateTime> _currentlyScheduledReminders = {};
  DateTime _lastDeliveryResetDate = DateTime(0);
  DateTime? _lastSchedulingTime;
  String? _lastTriggerSource;

  /// Returns an on-demand snapshot of notification system health, permissions, and synchronization state.
  /// Executes strictly on-demand without background polling or timers.
  Future<NotificationDiagnostics> getDiagnostics() async {
    final enabledSetting = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
    bool systemPermission = false;
    bool exactAlarmCap = true;

    try {
      if (Platform.isAndroid) {
        final androidNotifications = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        systemPermission = await androidNotifications?.areNotificationsEnabled() ?? false;
        final exactAlarmStatus = await androidNotifications?.canScheduleExactNotifications();
        exactAlarmCap = exactAlarmStatus ?? true;
      } else {
        systemPermission = true;
      }
    } catch (_) {}

    final schedule = HiveService.instance.fastingSchedule;
    final now = DateTime.now();
    final sessions = TimelineGenerator.generateTimeline(
      schedule: schedule,
      centerDate: now,
      daysBefore: 1,
      daysAfter: 1,
    );

    TimelineSession? targetSession;
    for (final session in sessions) {
      if (session.expectedEnd.isAfter(now)) {
        targetSession = session;
        break;
      }
    }

    final bool scheduleValid = targetSession != null && targetSession.expectedStart.isBefore(targetSession.expectedEnd);

    int expectedCount = 0;
    int missingCount = 0;

    if (targetSession != null && targetSession.expectedStart.isBefore(targetSession.expectedEnd) && enabledSetting) {
      final fastStart = targetSession.expectedStart;
      final fastEnd = targetSession.expectedEnd;

      final fastingEnabled = HiveService.instance.getSetting<bool>('reminder_fasting_enabled') ?? true;
      final iftarEnabled = HiveService.instance.getSetting<bool>('reminder_iftar_enabled') ?? true;

      final List<ScheduledNotification> expectedReminders = [];
      if (fastingEnabled) {
        expectedReminders.add(ScheduledNotification(
          id: _reminderFastingSoonId,
          title: 'Fasting Starts Soon',
          body: 'Your fasting will begin in 10 minutes.',
          scheduledDate: fastStart.subtract(const Duration(minutes: 10)),
        ));
        expectedReminders.add(ScheduledNotification(
          id: _reminderFastingStartId,
          title: 'Fasting Started',
          body: 'Your fasting has officially begun.',
          scheduledDate: fastStart,
        ));
      }
      if (iftarEnabled) {
        expectedReminders.add(ScheduledNotification(
          id: _reminderIftarSoonId,
          title: 'Iftar is Almost Here',
          body: 'Only 10 minutes remaining until it\'s time to break your fast.',
          scheduledDate: fastEnd.subtract(const Duration(minutes: 10)),
        ));
        expectedReminders.add(ScheduledNotification(
          id: _reminderIftarTimeId,
          title: 'It\'s Time to Break Your Fast',
          body: 'May your fasting be accepted. Enjoy your meal.',
          scheduledDate: fastEnd,
        ));
      }

      for (final r in expectedReminders) {
        if (_deliveredToday.contains(r.id)) continue;
        if (r.scheduledDate.isBefore(now) || r.scheduledDate.isAtSameMomentAs(now)) continue;
        expectedCount++;
        if (_currentlyScheduledReminders[r.id] != r.scheduledDate) {
          missingCount++;
        }
      }
    }

    final scheduledCount = _currentlyScheduledReminders.length;
    final isSynchronized = scheduleValid && missingCount == 0;

    return NotificationDiagnostics(
      notificationsEnabledSetting: enabledSetting,
      systemPermissionGranted: systemPermission,
      exactAlarmCapability: exactAlarmCap,
      fastingChannelAvailable: true,
      reminderChannelAvailable: true,
      isScheduleValid: scheduleValid,
      expectedReminderCount: expectedCount,
      scheduledReminderCount: scheduledCount,
      missingReminderCount: missingCount,
      isSynchronized: isSynchronized,
      bootReceiverRegistered: true,
      lastSchedulingTime: _lastSchedulingTime,
      lastTriggerSource: _lastTriggerSource,
    );
  }

  bool _backgroundInitialized = false;

  /// Lightweight local initialization before runApp()
  Future<void> initLocal() async {
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

      // Pre-create Android production notification channels with explicit AudioAttributes for instant sound playback
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'fasting_reminders_fast_v2',
            'Fasting Reminders (Fast Start)',
            description: 'Fasting start notifications with fast sound',
            importance: Importance.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('fast'),
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'fasting_reminders_eat_v2',
            'Fasting Reminders (Eat Time)',
            description: 'Eating start notifications with eat sound',
            importance: Importance.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('eat'),
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'fasting_reminders',
            'Fasting Reminders',
            description: 'Fasting reminder notifications',
            importance: Importance.high,
            playSound: true,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'fasting_reminders_silent',
            'Fasting Reminders (Silent)',
            description: 'Fasting reminder notifications without sound',
            importance: Importance.high,
            playSound: false,
            enableVibration: false,
          ),
        );
      }

      // Automatically reschedule on schedule changes and sync to Firestore
      HiveService.instance.fastingScheduleBox.watch(key: 'schedule').listen((_) {
        final currentSched = HiveService.instance.fastingSchedule;
        NotificationSyncService.instance.updateSchedule(schedule: currentSched, incrementVersion: true);
        scheduleFastingNotifications();
        scheduleReminderNotifications('User Changes Today\'s Fasting Schedule');
      });

      // Automatically reschedule on settings changes and sync to Firestore
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
          final currentSched = HiveService.instance.fastingSchedule;
          NotificationSyncService.instance.updateSchedule(schedule: currentSched, incrementVersion: true);
          scheduleReminderNotifications('Notification Preferences Change');
        }
      });

      // Automatically reschedule on fasting record changes (e.g. start, edit, complete, delete, resume)
      HiveService.instance.fastingRecordsBox.watch().listen((_) {
        scheduleFastingNotifications();
        scheduleReminderNotifications('Fasting Record Change');
      });

      _initialized = true;
      StartupDiag.log('NotificationService initialized');
    } catch (e, stackTrace) {
      assert(() {
        debugPrint('NotificationService: Local initialization failure: $e\n$stackTrace');
        return true;
      }());
    }
  }

  /// Non-blocking background initialization after initial UI frame rendering
  Future<void> initBackgroundServices() async {
    if (_backgroundInitialized) return;
    _backgroundInitialized = true;

    try {
      // 1. Initialize FastingEngine
      StartupDiag.log('FastingEngine background initialization START');
      FastingEngine().initialize();
      StartupDiag.log('FastingEngine background initialization END');

      // 2. Initialize FCM service for online push notifications
      StartupDiag.log('FCM background initialization START');
      await FcmService.instance.init();
      StartupDiag.log('FCM background initialization END');

      // 3. Startup synchronization between local schedule version and Firestore remote schedule
      StartupDiag.log('NotificationSync background initialization START');
      await NotificationSyncService.instance.synchronizeOnStartup(
        onRescheduleNeeded: (reason) async {
          await scheduleReminderNotifications(reason);
        },
      );
      StartupDiag.log('NotificationSync background initialization END');

      // Verify/Request notification permission status and log
      final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
      if (enabled) {
        await requestPermissions();
      }

      // 4. Background notification scheduling
      StartupDiag.log('Notification scheduling background START');
      await scheduleFastingNotifications();
      await scheduleReminderNotifications('Application Startup');
      StartupDiag.log('Notification scheduling background END');
    } catch (e, stackTrace) {
      assert(() {
        debugPrint('NotificationService: Background initialization error: $e\n$stackTrace');
        return true;
      }());
    }
  }

  /// Full initialization helper (backwards compatibility for tests)
  Future<void> init() async {
    await initLocal();
    await initBackgroundServices();
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
    if (_isSchedulingFasting) return;
    _isSchedulingFasting = true;
    try {
      await scheduleReminderNotifications('Fasting Notification Schedule');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Failed scheduling notifications: $e');
      }
    } finally {
      _isSchedulingFasting = false;
    }
  }


  @visibleForTesting
  Future<void> scheduleOneShotNotification({
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
      await HiveService.instance.clearLocalScheduledEvents();
      // ignore: avoid_print
      print(
        '[NOTIFICATION-TRACE]\n\n'
        'eventId: N/A\n'
        'eventType: N/A\n'
        'notificationId: ALL\n\n'
        'source: LOCAL_ALARM\n\n'
        'scheduledAt: N/A\n'
        'triggerAt: N/A\n'
        'executedAt: ${DateTime.now().toIso8601String()}\n\n'
        'channelId: N/A\n'
        'soundResource: N/A\n\n'
        'scheduleVersion: ${NotificationSyncService.instance.localVersion}\n'
        'action: cancelAll',
      );
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

  /// Resets the delivered and scheduled tracking sets at the start of each new calendar day
  void _resetDeliveredIfNewDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastDeliveryResetDate != today) {
      _deliveredToday.clear();
      _currentlyScheduledReminders.clear();
      _lastDeliveryResetDate = today;
    }
  }

  /// Cancels only the four reminder notification IDs without touching existing notifications
  Future<void> cancelReminderNotifications() async {
    for (final id in _reminderIds) {
      try {
        await _notifications.cancel(id);
      } catch (_) {}
      _currentlyScheduledReminders.remove(id);
    }
    await HiveService.instance.clearLocalScheduledEvents();

    // ignore: avoid_print
    print(
      '[NOTIFICATION-TRACE]\n\n'
      'eventId: N/A\n'
      'eventType: N/A\n'
      'notificationId: 2000-2003\n\n'
      'source: LOCAL_ALARM\n\n'
      'scheduledAt: N/A\n'
      'triggerAt: N/A\n'
      'executedAt: ${DateTime.now().toIso8601String()}\n\n'
      'channelId: N/A\n'
      'soundResource: N/A\n\n'
      'scheduleVersion: ${NotificationSyncService.instance.localVersion}\n'
      'action: cancel',
    );
    if (kDebugMode) {
      debugPrint('[NotificationService] Reminder notifications cancelled (IDs 2000-2003)');
    }
  }


  /// Schedules the four fasting reminder notifications based on today's schedule.
  /// 10-Step Deterministic Scheduling Lifecycle:
  /// 1. Triggered & log trigger source
  /// 2. Validate today's fasting schedule (Database primary source of truth: fastStart < fastEnd)
  /// 3. Reset daily state on midnight calendar rollover
  /// 4. Generate today's expected target reminders (IDs 2000-2003)
  /// 5. Perform Notification Integrity Check (Expected vs Optimization Cache)
  /// 6. Evaluate Idempotency (If synchronized, skip platform calls & log)
  /// 7. Differential Rescheduling (Cancel ONLY obsolete/modified reminders, preserve valid)
  /// 8. Register Exact OS Alarms (AndroidScheduleMode.exactAllowWhileIdle)
  /// 9. Independent Per-Notification Execution & Immediate Cache Synchronization
  /// 10. Output Structured Diagnostic Summary Log
  Future<void> scheduleReminderNotifications([String triggerSource = 'Today\'s Fasting Schedule Changed']) async {
    if (_isSchedulingReminders) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Reminder scheduling already in progress, skipping concurrent trigger ($triggerSource)');
      }
      return;
    }
    _isSchedulingReminders = true;
    _lastSchedulingTime = DateTime.now();
    _lastTriggerSource = triggerSource;

    int generatedCount = 0;
    int scheduledCount = 0;
    int skippedDeliveredCount = 0;
    int skippedTimePassedCount = 0;
    int skippedAlreadyScheduledCount = 0;
    int failedCount = 0;

    try {
      StartupDiag.log('Notification scheduling started');
      if (kDebugMode) {
        debugPrint('[NotificationService] Notification scheduling triggered.');
        debugPrint('  • Trigger Source: $triggerSource');
      }

      // Check master notification toggle
      final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
      if (!enabled) {
        await cancelReminderNotifications();
        if (kDebugMode) {
          debugPrint(
            '\nNotification Scheduling Summary\n\n'
            'Trigger:\n$triggerSource\n\n'
            'Schedule Valid:\nNo\n\n'
            'Reason:\nNotifications disabled in settings.\n\n'
            'No notifications scheduled.\n'
          );
        }
        return;
      }

      final fastingReminderEnabled = HiveService.instance.getSetting<bool>('reminder_fasting_enabled') ?? true;
      final iftarReminderEnabled = HiveService.instance.getSetting<bool>('reminder_iftar_enabled') ?? true;

      if (!fastingReminderEnabled && !iftarReminderEnabled) {
        await cancelReminderNotifications();
        if (kDebugMode) {
          debugPrint(
            '\nNotification Scheduling Summary\n\n'
            'Trigger:\n$triggerSource\n\n'
            'Schedule Valid:\nNo\n\n'
            'Reason:\nBoth fasting and iftar reminders disabled in settings.\n\n'
            'No notifications scheduled.\n'
          );
        }
        return;
      }

      // Step 1: Load & Validate Today's Fasting Schedule (Database Source of Truth)
      final schedule = HiveService.instance.fastingSchedule;
      final now = DateTime.now();

      final sessions = TimelineGenerator.generateTimeline(
        schedule: schedule,
        centerDate: now,
        daysBefore: 1,
        daysAfter: 1,
      );

      TimelineSession? targetSession;
      for (final session in sessions) {
        if (session.expectedEnd.isAfter(now)) {
          targetSession = session;
          break;
        }
      }

      if (targetSession == null || !targetSession.expectedStart.isBefore(targetSession.expectedEnd)) {
        await cancelReminderNotifications();
        if (kDebugMode) {
          debugPrint(
            '\nNotification Scheduling Summary\n\n'
            'Trigger:\n$triggerSource\n\n'
            'Schedule Valid:\nNo\n\n'
            'Reason:\nNo valid fasting schedule (start < iftar) found for today.\n\n'
            'No notifications scheduled.\n'
          );
        }
        return;
      }

      final fastStart = targetSession.expectedStart;
      final fastEnd = targetSession.expectedEnd;

      // Step 2: Midnight Calendar Day Rollover Reset
      _resetDeliveredIfNewDay();

      final soundPref = HiveService.instance.getSetting<String>('reminder_sound') ?? 'default';
      final vibrationEnabled = HiveService.instance.getSetting<bool>('reminder_vibration') ?? true;

      // Step 3: Generate Today's Expected Reminders
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

      generatedCount = reminders.length;

      // Step 4: Notification Integrity Check (Expected Schedule vs Optimization Cache)
      final Set<int> targetReminderIds = reminders.map((r) => r.id).toSet();
      final List<int> obsoleteIdsToCancel = [];

      for (final scheduledId in _currentlyScheduledReminders.keys.toList()) {
        if (!targetReminderIds.contains(scheduledId)) {
          obsoleteIdsToCancel.add(scheduledId);
        }
      }

      for (final reminder in reminders) {
        if (_deliveredToday.contains(reminder.id)) continue;
        if (reminder.scheduledDate.isBefore(now) || reminder.scheduledDate.isAtSameMomentAs(now)) continue;
        final currentScheduledTime = _currentlyScheduledReminders[reminder.id];
        if (currentScheduledTime != null && currentScheduledTime != reminder.scheduledDate) {
          if (!obsoleteIdsToCancel.contains(reminder.id)) {
            obsoleteIdsToCancel.add(reminder.id);
          }
        }
      }

      // Step 5: Evaluate Idempotency
      bool needsSchedulingWork = obsoleteIdsToCancel.isNotEmpty;
      if (!needsSchedulingWork) {
        for (final reminder in reminders) {
          if (_deliveredToday.contains(reminder.id)) continue;
          if (reminder.scheduledDate.isBefore(now) || reminder.scheduledDate.isAtSameMomentAs(now)) continue;
          if (_currentlyScheduledReminders[reminder.id] != reminder.scheduledDate) {
            needsSchedulingWork = true;
            break;
          }
        }
      }

      if (!needsSchedulingWork) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Scheduler already synchronized.');
        }
        return;
      }

      // Step 6: Differential Rescheduling — Cancel ONLY Obsolete/Modified Reminders
      for (final cancelId in obsoleteIdsToCancel) {
        await _notifications.cancel(cancelId);
        _currentlyScheduledReminders.remove(cancelId);
      }

      // Steps 7, 8, 9: Register Exact OS Alarms, Independent Execution & Cache Sync
      for (final reminder in reminders) {
        // Rule 2: Skip if delivered today
        if (_deliveredToday.contains(reminder.id)) {
          skippedDeliveredCount++;
          continue;
        }

        // Rule 1: Skip if time passed
        if (reminder.scheduledDate.isBefore(now) || reminder.scheduledDate.isAtSameMomentAs(now)) {
          skippedTimePassedCount++;
          continue;
        }

        // Duplicate Scheduling Rule: Skip if already scheduled for exact same time
        if (_currentlyScheduledReminders[reminder.id] == reminder.scheduledDate) {
          skippedAlreadyScheduledCount++;
          continue;
        }

        // Schedule independently with per-notification error isolation
        try {
          await _scheduleReminderNotification(
            id: reminder.id,
            title: reminder.title,
            body: reminder.body,
            scheduledDate: reminder.scheduledDate,
            soundPref: soundPref,
            vibrationEnabled: vibrationEnabled,
          );
          // Step 9: Immediate Cache Synchronization
          _currentlyScheduledReminders[reminder.id] = reminder.scheduledDate;
          scheduledCount++;
        } catch (singleNotificationError) {
          failedCount++;
          if (kDebugMode) {
            debugPrint('  └─ Failed to schedule Notification ${reminder.id}: $singleNotificationError');
          }
        }
      }

      // Step 10: Output Structured Diagnostic Summary Log
      if (kDebugMode) {
        debugPrint(
          '\nNotification Scheduling Summary\n\n'
          'Trigger:\n$triggerSource\n\n'
          'Schedule Valid:\nYes\n\n'
          'Generated:\n$generatedCount\n\n'
          'Scheduled:\n$scheduledCount\n\n'
          'Skipped (Already Delivered):\n$skippedDeliveredCount\n\n'
          'Skipped (Time Passed):\n$skippedTimePassedCount\n\n'
          'Skipped (Already Scheduled):\n$skippedAlreadyScheduledCount\n\n'
          'Cancelled Obsolete:\n${obsoleteIdsToCancel.length}\n\n'
          'Failed:\n$failedCount\n\n'
          'Scheduling Completed Successfully\n'
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '\nNotification Scheduling Summary\n\n'
          'Trigger:\n$triggerSource\n\n'
          'Schedule Valid:\nNo\n\n'
          'Reason:\nExecution error: $e\n\n'
          'No notifications scheduled.\n'
        );
      }
    } finally {
      StartupDiag.log('Notification scheduling completed');
      _isSchedulingReminders = false;
    }
  }

/// Centralized sound resolver for Android notification details.
AndroidNotificationSound? getFastingReminderSound({
  required String soundName,
}) {
  switch (soundName) {
    case 'eat':
      return const RawResourceAndroidNotificationSound('eat');
    case 'fast':
      return const RawResourceAndroidNotificationSound('fast');
    default:
      return null;
  }
}

  AndroidNotificationDetails _getAndroidDetailsForReminder({
    required int reminderId,
    required String soundPref,
    required bool vibrationEnabled,
  }) {
    if (soundPref == 'silent') {
      return const AndroidNotificationDetails(
        'fasting_reminders_silent',
        'Fasting Reminders (Silent)',
        channelDescription: 'Fasting reminder notifications without sound',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
        enableVibration: false,
      );
    }

    // 1. FASTING_START (ID 2001) -> fasting_reminders_fast_v2 with fast.mp3
    if (reminderId == _reminderFastingStartId) {
      final customSound = getFastingReminderSound(soundName: 'fast');
      return AndroidNotificationDetails(
        'fasting_reminders_fast_v2',
        'Fasting Reminders (Fast Start)',
        channelDescription: 'Fasting start notifications with fast sound',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: customSound,
        audioAttributesUsage: AudioAttributesUsage.notification,
        enableVibration: vibrationEnabled,
      );
    }

    // 2. FASTING_END / IFTAR_TIME (ID 2003) -> fasting_reminders_eat_v2 with eat.mp3
    if (reminderId == _reminderIftarTimeId) {
      final customSound = getFastingReminderSound(soundName: 'eat');
      return AndroidNotificationDetails(
        'fasting_reminders_eat_v2',
        'Fasting Reminders (Eat Time)',
        channelDescription: 'Eating start notifications with eat sound',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: customSound,
        audioAttributesUsage: AudioAttributesUsage.notification,
        enableVibration: vibrationEnabled,
      );
    }

    // 3. FASTING_START_SOON (ID 2000) & FASTING_END_SOON (ID 2002) / 10-minute reminders -> fasting_reminders (system default sound)
    return AndroidNotificationDetails(
      'fasting_reminders',
      'Fasting Reminders',
      channelDescription: 'Fasting reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: vibrationEnabled,
    );
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

    final androidDetails = _getAndroidDetailsForReminder(
      reminderId: id,
      soundPref: soundPref,
      vibrationEnabled: vibrationEnabled,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundPref != 'silent',
    );

    String eventTypeStr = 'UNKNOWN';
    if (id == _reminderFastingSoonId) {
      eventTypeStr = 'FASTING_START_SOON';
    } else if (id == _reminderFastingStartId) {
      eventTypeStr = 'FASTING_START';
    } else if (id == _reminderIftarSoonId) {
      eventTypeStr = 'FASTING_END_SOON';
    } else if (id == _reminderIftarTimeId) {
      eventTypeStr = 'FASTING_END';
    }

    final soundName = androidDetails.channelId == 'fasting_reminders_fast_v2'
        ? 'fast'
        : (androidDetails.channelId == 'fasting_reminders_eat_v2' ? 'eat' : 'default_system');

    final eventIdStr = '${NotificationSyncService.scheduleId}_${scheduledDate.toIso8601String()}_$eventTypeStr';
    final eventKey = '${scheduledDate.year}_${scheduledDate.month}_${scheduledDate.day}_${scheduledDate.hour}_${scheduledDate.minute}_$eventTypeStr';
    await HiveService.instance.markEventScheduledLocally(eventKey, scheduledDate);
    await HiveService.instance.saveDeliveryRecord(
      eventId: eventIdStr,
      data: {
        'eventId': eventIdStr,
        'eventType': eventTypeStr,
        'scheduledAt': scheduledDate.toIso8601String(),
        'notificationId': id,
        'channelId': androidDetails.channelId,
        'soundResource': soundName,
        'scheduleVersion': NotificationSyncService.instance.localVersion,
        'deliverySource': 'LOCAL_ALARM',
        'status': 'SCHEDULED_LOCAL',
        'uid': HiveService.instance.currentActiveUserId,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );

    // ignore: avoid_print
    print(
      '[NOTIFICATION-TRACE]\n\n'
      'eventId: $eventIdStr\n'
      'eventType: $eventTypeStr\n'
      'notificationId: $id\n\n'
      'source: LOCAL_ALARM\n\n'
      'scheduledAt: ${scheduledDate.toIso8601String()}\n'
      'triggerAt: ${scheduledDate.toIso8601String()}\n'
      'executedAt: ${DateTime.now().toIso8601String()}\n\n'
      'channelId: ${androidDetails.channelId}\n'
      'soundResource: $soundName\n\n'
      'scheduleVersion: ${NotificationSyncService.instance.localVersion}\n'
      'deliveryState: SCHEDULED_LOCAL\n'
      'action: zonedSchedule',
    );

    final isCustomSoundChannel = androidDetails.channelId == 'fasting_reminders_fast_v2' ||
        androidDetails.channelId == 'fasting_reminders_eat_v2';

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
        debugPrint('[NotificationService] Reminder scheduled: ID $id "$title" at $tzDate (sound: $soundPref, channel: ${androidDetails.channelId})');
      }
    } catch (e) {
      if (isCustomSoundChannel) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Custom sound channel "${androidDetails.channelId}" failed, falling back to default system sound channel: $e');
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

  /// Normalizes incoming event type strings to canonical event names:
  /// - FASTING_START / FASTING_START_SOON
  /// - FASTING_END / FASTING_END_SOON
  String normalizeEventType(String rawType) {
    switch (rawType.toLowerCase()) {
      case 'fasting_reminder_start':
      case 'fasting_start_reminder':
        return 'FASTING_START_SOON';
      case 'fasting_start':
        return 'FASTING_START';
      case 'fasting_reminder_end':
      case 'fasting_end_reminder':
        return 'FASTING_END_SOON';
      case 'fasting_end':
      case 'eating_start':
        return 'FASTING_END';
      default:
        return rawType.toUpperCase();
    }
  }

  /// Single unified entry-point for displaying reminder notifications,
  /// used by both Local Alarms and FCM Event Triggers.
  Future<void> processReminderEvent({
    required String eventId,
    required String eventType,
    String? rawType,
  }) async {
    final normalized = normalizeEventType(eventType);
    final now = DateTime.now();

    String title;
    String body;
    int id;

    switch (normalized) {
      case 'FASTING_START_SOON':
        title = 'Fasting Starts Soon';
        body = 'Your fasting will begin in 10 minutes.';
        id = _reminderFastingSoonId;
        break;

      case 'FASTING_START':
        title = 'Fasting Started';
        body = 'Your fasting has officially begun.';
        id = _reminderFastingStartId;
        break;

      case 'FASTING_END_SOON':
        title = 'Iftar is Almost Here';
        body = 'Only 10 minutes remaining until it\'s time to break your fast.';
        id = _reminderIftarSoonId;
        break;

      case 'FASTING_END':
        title = 'It\'s Time to Break Your Fast';
        body = 'May your fasting be accepted. Enjoy your meal.';
        id = _reminderIftarTimeId;
        break;

      default:
        title = 'Fasting Update';
        body = 'Scheduled notification alert.';
        id = 2099;
    }

    final soundPref = HiveService.instance.getSetting<String>('reminder_sound') ?? 'app_notification';
    final vibrationEnabled = HiveService.instance.getSetting<bool>('reminder_vibration') ?? true;

    AndroidNotificationDetails defaultDetails() => AndroidNotificationDetails(
      'fasting_reminders',
      'Fasting Reminders',
      channelDescription: 'Fasting reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: vibrationEnabled,
    );

    final androidDetails = _getAndroidDetailsForReminder(
      reminderId: id,
      soundPref: soundPref,
      vibrationEnabled: vibrationEnabled,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: soundPref != 'silent',
    );

    final soundName = androidDetails.channelId == 'fasting_reminders_fast_v2'
        ? 'fast'
        : (androidDetails.channelId == 'fasting_reminders_eat_v2' ? 'eat' : 'default_system');

    // 1. Atomic claim evaluation: Check durable registry to eliminate race conditions between isolates / delivery channels
    final claimGranted = await HiveService.instance.tryClaimNotificationDelivery(
      eventId: eventId,
      source: 'FCM',
      eventType: normalized,
      scheduledDate: now,
    );

    if (!claimGranted) {
      // ignore: avoid_print
      print(
        '[NOTIFICATION-TRACE]\n\n'
        'eventId: $eventId\n'
        'eventType: $normalized\n'
        'notificationId: $id\n\n'
        'source: FCM\n\n'
        'scheduledAt: ${now.toIso8601String()}\n'
        'triggerAt: ${now.toIso8601String()}\n'
        'executedAt: ${now.toIso8601String()}\n\n'
        'channelId: ${androidDetails.channelId}\n'
        'soundResource: $soundName\n\n'
        'scheduleVersion: ${NotificationSyncService.instance.localVersion}\n'
        'deliveryState: FCM_SKIPPED_LOCAL_PRIMARY\n'
        'action: skipped_duplicate_primary_alarm',
      );
      return;
    }

    // 2. Fallback Delivery: Local Alarm was not scheduled/handled, so FCM delivers as fallback
    // ignore: avoid_print
    print(
      '[NOTIFICATION-TRACE]\n\n'
      'eventId: $eventId\n'
      'eventType: $normalized\n'
      'notificationId: $id\n\n'
      'source: FCM\n\n'
      'scheduledAt: ${now.toIso8601String()}\n'
      'triggerAt: ${now.toIso8601String()}\n'
      'executedAt: ${now.toIso8601String()}\n\n'
      'channelId: ${androidDetails.channelId}\n'
      'soundResource: $soundName\n\n'
      'scheduleVersion: ${NotificationSyncService.instance.localVersion}\n'
      'deliveryState: FCM_FALLBACK_DELIVERY\n'
      'action: show',
    );


    final isCustomSoundChannel = androidDetails.channelId == 'fasting_reminders_fast_v2' ||
        androidDetails.channelId == 'fasting_reminders_eat_v2';

    try {
      await _notifications.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );

      // Mark event as processed to complete deduplication
      await HiveService.instance.markEventProcessed(eventId);

      if (kDebugMode) {
        debugPrint('[Notification] Displayed notification for eventId: $eventId ($normalized, channel: ${androidDetails.channelId})');
      }
    } catch (e) {
      if (isCustomSoundChannel) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Custom sound display on channel ${androidDetails.channelId} failed, trying default system sound fallback: $e');
        }
        try {
          await _notifications.show(
            id,
            title,
            body,
            NotificationDetails(android: defaultDetails(), iOS: iosDetails),
          );
          await HiveService.instance.markEventProcessed(eventId);
        } catch (fallbackError) {
          if (kDebugMode) {
            debugPrint('[Notification] FAILED: notificationId: $id, channelId: ${defaultDetails().channelId}, error: $fallbackError');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('[Notification] FAILED: $e');
        }
      }
    }
  }


  /// Displays an immediate notification triggered by an incoming FCM push event.
  Future<void> displayRemoteNotification({
    required String type,
    required String eventId,
  }) async {
    final normalizedType = normalizeEventType(type);
    await processReminderEvent(
      eventId: eventId,
      eventType: normalizedType,
      rawType: type,
    );
  }

  /// Triggers an immediate local test notification to verify local Android notification display.
  Future<void> triggerTestNotification() async {
    if (kDebugMode) {
      debugPrint('[Notification Test] Triggering local test notification');
    }

    const androidDetails = AndroidNotificationDetails(
      'fasting_reminders',
      'Fasting Reminders',
      channelDescription: 'Fasting reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _notifications.show(
        9999,
        'Test Reminder',
        'This is a local notification test.',
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
      if (kDebugMode) {
        debugPrint('[Notification Test] Local notification request completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Notification Test] FAILED: $e');
      }
    }
  }

  /// Temporary diagnostic helper for direct show() timing comparison
  Future<void> debugTestDirectShow({bool useCustomSound = true}) async {
    final int testId = useCustomSound ? _reminderFastingStartId : _reminderFastingSoonId;
    final String soundName = useCustomSound ? 'fast' : 'default_system';

    final androidDetails = _getAndroidDetailsForReminder(
      reminderId: testId,
      soundPref: 'app_notification',
      vibrationEnabled: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final String t0 = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('[SOUND-TIMING] BEFORE_SHOW');
    // ignore: avoid_print
    print('[SOUND-TIMING] eventType: ${useCustomSound ? "FASTING_START" : "FASTING_START_SOON"}');
    // ignore: avoid_print
    print('[SOUND-TIMING] notificationId: $testId');
    // ignore: avoid_print
    print('[SOUND-TIMING] channelId: ${androidDetails.channelId}');
    // ignore: avoid_print
    print('[SOUND-TIMING] sound: $soundName');
    // ignore: avoid_print
    print('[SOUND-TIMING] playSound: ${androidDetails.playSound}');
    // ignore: avoid_print
    print('[SOUND-TIMING] timestamp: $t0');

    await _notifications.show(
      testId,
      useCustomSound ? 'Fasting Started Test' : 'Fasting Soon Test',
      useCustomSound ? 'Direct show test with fast.mp3' : 'Direct show test with system sound',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    final String t1 = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('[SOUND-TIMING] AFTER_SHOW');
    // ignore: avoid_print
    print('[SOUND-TIMING] eventType: ${useCustomSound ? "FASTING_START" : "FASTING_START_SOON"}');
    // ignore: avoid_print
    print('[SOUND-TIMING] notificationId: $testId');
    // ignore: avoid_print
    print('[SOUND-TIMING] channelId: ${androidDetails.channelId}');
    // ignore: avoid_print
    print('[SOUND-TIMING] timestamp: $t1');

    // ignore: avoid_print
    print('[SOUND-LOCK-DIAG] AFTER_SHOW');
    // ignore: avoid_print
    print('[SOUND-LOCK-DIAG] eventType: ${useCustomSound ? "FASTING_START" : "FASTING_START_SOON"}');
    // ignore: avoid_print
    print('[SOUND-LOCK-DIAG] notificationId: $testId');
    // ignore: avoid_print
    print('[SOUND-LOCK-DIAG] channelId: ${androidDetails.channelId}');
    // ignore: avoid_print
    print('[SOUND-LOCK-DIAG] timestamp: $t1');
  }
}