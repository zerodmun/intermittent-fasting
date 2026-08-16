import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/user_data_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('migration_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UserDataMigrationService Unit & Integrity Tests', () {
    test('Default migration status is legacy_local_user', () {
      expect(UserDataMigrationService.instance.migrationStatus, equals('legacy_local_user'));
      expect(UserDataMigrationService.instance.boundFirebaseUid, isNull);
    });

    test('localUserId returns a valid persistent anonymous user identity', () {
      final localId = UserDataMigrationService.instance.localUserId;
      expect(localId, isNotEmpty);
      expect(localId, startsWith('user_'));
    });

    test('Account switch on same device binds new active UID seamlessly and preserves state', () async {
      await HiveService.instance.setSetting('bound_firebase_uid', 'user_A_123');

      await UserDataMigrationService.instance.processPostLoginMigration(
        uid: 'user_B_456',
        email: 'userB@example.com',
      );

      expect(UserDataMigrationService.instance.migrationStatus, equals('completed'));
      expect(UserDataMigrationService.instance.boundFirebaseUid, equals('user_B_456'));
    });


  });
}
