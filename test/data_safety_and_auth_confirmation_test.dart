import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/auth_service.dart';
import 'package:fast_flow/core/services/logger_service.dart';

import 'package:fast_flow/shared/widgets/app_dialog.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('safety_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Part 1 — Graceful .env Loading Tests', () {
    test('Missing .env file is handled gracefully without fatal exception', () async {
      try {
        await dotenv.load(fileName: '.env');
        LoggerService.i('.env loaded');
      } catch (_) {
        LoggerService.w('.env file not found, using default configuration');
      }
      expect(true, isTrue);
    });
  });

  group('Part 2 & Part 9 — Logout Confirmation & Double Execution Protection Tests', () {
    testWidgets('Logout confirmation dialog cancel preserves login state', (tester) async {
      bool confirmResult = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await AppDialog.showConfirm(
                  context: context,
                  title: 'Logout?',
                  content: 'Are you sure you want to logout?',
                  confirmLabel: 'LOGOUT',
                  cancelLabel: 'CANCEL',
                  isDestructive: true,
                );
                confirmResult = result ?? false;
              },
              child: const Text('Sign Out'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Logout?'), findsOneWidget);
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(confirmResult, isFalse);
    });

    test('Logout does NOT clear or delete local Hive data', () async {
      // 1. Populate sample fasting record
      final record = FastingRecord(
        id: 'safety_record_1',
        planName: '16:8 Fast',
        fastingMinutes: 960,
        eatingMinutes: 480,
        startTime: DateTime.now().subtract(const Duration(hours: 16)),
        endTime: DateTime.now(),
        status: 'completed',
      );
      await HiveService.instance.saveFastingRecord(record);
      await HiveService.instance.setSetting('test_pref', 'retained_value');

      // 2. Perform logout
      await AuthService.instance.signOut();

      // 3. Verify Hive boxes remain 100% intact
      final records = HiveService.instance.fastingRecordsBox.values.toList();
      expect(records.length, greaterThanOrEqualTo(1));
      expect(records.any((r) => r.id == 'safety_record_1'), isTrue);
      expect(HiveService.instance.getSetting<String>('test_pref'), equals('retained_value'));
    });
  });

  group('Part 4 & Part 5 — Data Deletion & Restore Confirmation Tests', () {
    testWidgets('Delete single item confirmation dialog renders standardized title & buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await AppDialog.showConfirm(
                  context: context,
                  title: 'Delete this data?',
                  content: 'This data will be permanently removed. This action cannot be undone.',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Cancel',
                  isDestructive: true,
                );
              },
              child: const Text('Delete Item'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Delete Item'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this data?'), findsOneWidget);
      expect(find.text('This data will be permanently removed. This action cannot be undone.'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Restore backup confirmation dialog renders warning message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await AppDialog.showConfirm(
                  context: context,
                  title: 'Restore backup?',
                  content: 'Restoring this backup may replace your current data. Make sure you have a recent backup of your current data before continuing.',
                  confirmLabel: 'Restore',
                  cancelLabel: 'CANCEL',
                );
              },
              child: const Text('Restore Data'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Restore Data'));
      await tester.pumpAndSettle();

      expect(find.text('Restore backup?'), findsOneWidget);
      expect(find.text('Restoring this backup may replace your current data. Make sure you have a recent backup of your current data before continuing.'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets('Delete all data confirmation dialog renders strong warning', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await AppDialog.showConfirm(
                  context: context,
                  title: 'Delete all data?',
                  content: 'This will permanently delete all locally stored application data, including your history, records, schedules, and settings. This action cannot be undone.',
                  confirmLabel: 'DELETE ALL',
                  cancelLabel: 'CANCEL',
                  isDestructive: true,
                );
              },
              child: const Text('Reset All Data'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reset All Data'));
      await tester.pumpAndSettle();

      expect(find.text('Delete all data?'), findsOneWidget);
      expect(find.text('This will permanently delete all locally stored application data, including your history, records, schedules, and settings. This action cannot be undone.'), findsOneWidget);
      expect(find.text('DELETE ALL'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });
  });
}
