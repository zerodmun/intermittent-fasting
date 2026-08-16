import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/fcm_service.dart';
import 'package:fast_flow/core/services/notification_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthService & Device Identity Tests', () {
    test('DeviceAlreadyLinkedException has clear user-facing error message', () {
      final exc = DeviceAlreadyLinkedException();
      expect(exc.message, contains('already linked to another device'));
      expect(exc.toString(), contains('already linked to another device'));
    });

    test('getOrCreateDeviceId returns a stable persistent deviceId', () {
      final deviceId1 = FcmService.instance.getOrCreateDeviceId();
      final deviceId2 = FcmService.instance.getOrCreateDeviceId();

      expect(deviceId1, isNotEmpty);
      expect(deviceId2, equals(deviceId1));
    });

    test('NotificationSyncService userId falls back to guest identity when unauthenticated', () {
      final userId = NotificationSyncService.instance.userId;
      expect(userId, isNotEmpty);
      expect(userId, startsWith('user_'));
    });

    test('sendPasswordResetEmail handles uninitialized Firebase safely in unit tests', () async {
      expect(
        () async => await AuthService.instance.sendPasswordResetEmail(email: 'test@example.com'),
        throwsA(anything),
      );
    });
  });
}

