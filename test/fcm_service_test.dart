import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';

void main() {
  group('FcmService Registration & Persistence Tests', () {
    test('buildDeviceDocument creates standardized device payload with required fields', () {
      final doc = FcmService.instance.buildDeviceDocument(
        deviceId: 'device_test_123',
        fcmToken: 'token_sample_abc',
      );

      expect(doc['deviceId'], equals('device_test_123'));
      expect(doc['fcmToken'], equals('token_sample_abc'));
      expect(doc['platform'], isNotNull);
      expect(doc['appVersion'], isNotNull);
      expect(doc['updatedAt'], isNotNull);
      expect(doc['enabled'], isTrue);
    });

    test('getOrCreateDeviceId returns a persistent non-empty ID', () {
      final id1 = FcmService.instance.getOrCreateDeviceId();
      final id2 = FcmService.instance.getOrCreateDeviceId();

      expect(id1, isNotEmpty);
      expect(id2, equals(id1));
    });

    test('Device document Firestore path matches users/{userId}/devices/{deviceId}', () {
      final userId = NotificationSyncService.instance.userId;
      final deviceId = FcmService.instance.getOrCreateDeviceId();
      final path = 'users/$userId/devices/$deviceId';

      expect(path, matches(RegExp(r'^users/[^/]+/devices/[^/]+$')));
    });

    test('Token refresh update retains exact same deviceId while updating fcmToken', () {
      final deviceIdInitial = FcmService.instance.getOrCreateDeviceId();

      final payload1 = FcmService.instance.buildDeviceDocument(
        deviceId: deviceIdInitial,
        fcmToken: 'initial_token_123',
      );

      final payload2 = FcmService.instance.buildDeviceDocument(
        deviceId: deviceIdInitial,
        fcmToken: 'refreshed_token_456',
      );

      expect(payload1['deviceId'], equals(deviceIdInitial));
      expect(payload2['deviceId'], equals(deviceIdInitial));
      expect(payload1['fcmToken'], equals('initial_token_123'));
      expect(payload2['fcmToken'], equals('refreshed_token_456'));
    });

    test('FCM payload missing required fields returns safely without error', () async {
      final invalidData = <String, String>{
        'type': 'fasting_start_reminder',
      };
      expect(
        () async => await FcmService.instance.handleRemoteMessage(
          RemoteMessage(data: invalidData),
        ),
        returnsNormally,
      );
    });
  });
}
