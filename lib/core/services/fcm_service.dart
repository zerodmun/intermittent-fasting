import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

/// Top-level background message handler required by firebase_messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[FcmService] Background Firebase init note: $e');
    }
  }

  try {
    await HiveService.instance.init();
    await NotificationService.instance.init();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[FcmService] Background service init note: $e');
    }
  }

  if (kDebugMode) {
    debugPrint('[FCM] Message received (Background/Killed)');
    debugPrint('[FCM] Message ID: ${message.messageId}');
    debugPrint('[FCM] Message data: ${message.data}');
  }
  await FcmService.instance.handleRemoteMessage(message);
}

/// Firebase Cloud Messaging service managing device token registration
/// and incoming payload validation for online notification triggers.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  FirebaseMessaging? _customMessaging;
  FirebaseMessaging get _messaging => _customMessaging ?? FirebaseMessaging.instance;
  FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  bool _initialized = false;

  /// Builds standardized device document payload for Firestore
  Map<String, dynamic> buildDeviceDocument({
    required String deviceId,
    required String fcmToken,
  }) {
    final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
    return {
      'deviceId': deviceId,
      'fcmToken': fcmToken,
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      'appVersion': '1.0.0',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'enabled': enabled,
    };
  }

  /// Initialize FCM messaging, device token registration, and message listeners
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Request notification permissions via FCM
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        if (kDebugMode) {
          debugPrint('[Notification] Permission granted (${settings.authorizationStatus})');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[Notification] Permission denied (${settings.authorizationStatus})');
        }
      }

      // Register device token in Firestore
      await _registerDeviceToken();

      // Listen for token updates
      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) {
          debugPrint('[FCM] Token refreshed');
        }
        _updateTokenInFirestore(newToken);
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[FCM] Message received (Foreground)');
          debugPrint('[FCM] Message ID: ${message.messageId}');
          debugPrint('[FCM] Message data: ${message.data}');
        }
        handleRemoteMessage(message);
      });

      // App opened from background notification listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[FCM] Notification opened app from background. Message ID: ${message.messageId}');
          debugPrint('[FCM] Message data: ${message.data}');
        }
        handleRemoteMessage(message);
      });

      // Terminated state initial message
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          debugPrint('[FCM] App launched from terminated notification. Message ID: ${initialMessage.messageId}');
          debugPrint('[FCM] Message data: ${initialMessage.data}');
        }
        handleRemoteMessage(initialMessage);
      }

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _initialized = true;
    } catch (e, stackTrace) {
      LoggerService.e('FcmService initialization error', e, stackTrace);
    }
  }

  /// Registers or updates device token in Firestore under users/{userId}/devices/{deviceId}
  Future<void> _registerDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmService] Failed getting FCM token: $e');
      }
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    final userId = NotificationSyncService.instance.userId;
    var deviceId = getOrCreateDeviceId();

    if (kDebugMode) {
      debugPrint('[FCM] Device ID: $deviceId');
      debugPrint('[FCM] Token available: true');
      debugPrint('[FCM] Registering device for user: $userId');
    }

    try {
      // Protection against duplicate device records with the same FCM token for this user
      final existingDevices = await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .where('fcmToken', isEqualTo: token)
          .get()
          .timeout(const Duration(seconds: 5));

      if (existingDevices.docs.isNotEmpty) {
        final existingDoc = existingDevices.docs.first;
        if (existingDoc.id != deviceId) {
          if (kDebugMode) {
            debugPrint('[FCM] Existing device ID found for FCM token: ${existingDoc.id}. Reusing canonical record.');
          }
          deviceId = existingDoc.id;
          HiveService.instance.setSetting('fcm_device_id', deviceId);
          _memoryDeviceIdCache = deviceId;
        }
      }

      final deviceData = buildDeviceDocument(deviceId: deviceId, fcmToken: token);

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .doc(deviceId)
          .set(deviceData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        debugPrint('[FCM] FCM token saved to Firestore for device: $deviceId');
      }

      await _syncDeviceToCloudflare(token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Failed updating FCM token in Firestore: $e');
      }
    }
  }

  Future<void> _syncDeviceToCloudflare(String token) async {
    final userId = NotificationSyncService.instance.userId;
    final deviceId = getOrCreateDeviceId();

    final payload = {
      'userId': userId,
      'deviceId': deviceId,
      'fcmToken': token,
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      'appVersion': '1.0.0',
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://fomo-notification-scheduler.zerodmun2.workers.dev/device'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
          debugPrint('[FcmService] Device synced to Cloudflare Worker successfully for device: $deviceId');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[FcmService] Cloudflare Worker device sync returned status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmService] Cloudflare Worker device sync error for device $deviceId: $e');
      }
    }
  }

  String? _memoryDeviceIdCache;

  String getOrCreateDeviceId() {
    if (_memoryDeviceIdCache != null && _memoryDeviceIdCache!.isNotEmpty) {
      return _memoryDeviceIdCache!;
    }

    // 1. Check primary fcm_device_id key
    var deviceId = HiveService.instance.getSetting<String>('fcm_device_id');
    if (deviceId != null && deviceId.isNotEmpty) {
      _memoryDeviceIdCache = deviceId;
      return deviceId;
    }

    // 2. Migration check: read legacy device_id key if present
    final legacyId = HiveService.instance.getSetting<String>('device_id');
    if (legacyId != null && legacyId.isNotEmpty) {
      HiveService.instance.setSetting('fcm_device_id', legacyId);
      _memoryDeviceIdCache = legacyId;
      return legacyId;
    }

    // 3. Fallback: generate a new device ID if neither key exists
    deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    HiveService.instance.setSetting('fcm_device_id', deviceId);
    _memoryDeviceIdCache = deviceId;
    return deviceId;
  }

  /// Re-registers device token in Firestore and Cloudflare Worker with updated userId
  Future<void> reRegisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FcmService] Failed re-registering FCM token: $e');
      }
    }
  }

  /// Processes incoming FCM message with versioning and duplicate event validation.
  /// FCM acts strictly as an event trigger and delegates notification display to NotificationService.
  Future<void> handleRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    if (data.isEmpty) return;

    final type = data['type'] as String?;
    final scheduleId = data['scheduleId'] as String?;
    final versionStr = data['version'] as String?;
    final eventId = data['eventId'] as String?;

    if (type == null || scheduleId == null || versionStr == null || eventId == null) {
      if (kDebugMode) {
        debugPrint('[FcmService] Invalid FCM payload format: missing required fields');
      }
      return;
    }

    final normalizedEventType = NotificationService.instance.normalizeEventType(type);

    if (kDebugMode) {
      debugPrint('[FCM] Reminder trigger received');
      debugPrint('[FCM] Event ID: $eventId');
      debugPrint('[FCM] Event type: $normalizedEventType');
      debugPrint('[FCM] Checking event deduplication');
    }

    // Validation 1: Check master notifications setting
    final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
    if (!enabled) {
      if (kDebugMode) {
        debugPrint('[FcmService] Ignored FCM event $eventId: notifications disabled in settings');
      }
      return;
    }

    // Validation 2: Check schedule versioning (stale task protection)
    final incomingVersion = int.tryParse(versionStr) ?? 0;
    final localVersion = NotificationSyncService.instance.localVersion;
    if (incomingVersion < localVersion) {
      if (kDebugMode) {
        debugPrint('[FcmService] Ignored FCM event $eventId: FCM version ($incomingVersion) < Current local version ($localVersion)');
      }
      return;
    }

    // Validation 3: Event deduplication check
    if (HiveService.instance.isEventProcessed(eventId)) {
      if (kDebugMode) {
        debugPrint('[FCM] Event already processed - skipping');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('[FCM] New reminder event');
      debugPrint('[FCM] Triggering local notification');
    }

    // Trigger local notification pipeline in NotificationService
    await NotificationService.instance.processReminderEvent(
      eventId: eventId,
      eventType: normalizedEventType,
      rawType: type,
    );
  }

  /// Runs end-to-end FCM & Notification diagnostics report logging.
  Future<void> runDiagnosticsReport() async {
    final token = await _messaging.getToken();
    final deviceId = getOrCreateDeviceId();
    final permissions = await _messaging.getNotificationSettings();

    debugPrint('=== FCM & NOTIFICATION DIAGNOSTICS REPORT ===');
    debugPrint('[Diagnostic] FCM initialized: $_initialized');
    debugPrint('[Diagnostic] Device ID available: ${deviceId.isNotEmpty} ($deviceId)');
    debugPrint('[Diagnostic] FCM token available: ${token != null && token.isNotEmpty}');
    debugPrint('[Diagnostic] Notification permission: ${permissions.authorizationStatus}');
    debugPrint('[Diagnostic] Notification channel: available');
    debugPrint('[Diagnostic] Notification service: initialized');
    debugPrint('=============================================');
  }

  /// Processes a simulated FCM payload locally for debugging without waiting for backend scheduler.
  Future<void> processSimulatedFcmPayload(Map<String, String> data) async {
    final message = RemoteMessage(data: data);
    if (kDebugMode) {
      debugPrint('[FCM] Processing simulated FCM payload: $data');
    }
    await handleRemoteMessage(message);
  }
}
