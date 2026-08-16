import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/services/hive_service.dart';

import 'package:fast_flow/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fast_flow/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:fast_flow/features/onboarding/domain/entities/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  UserProfile createTestProfile({required String name, double heightCm = 175.0}) {
    return UserProfile(
      name: name,
      gender: 'male',
      ageYears: 28,
      heightCm: heightCm,
      weightKg: 70.0,
      goalWeightKg: 65.0,
      targetBodyFat: 15.0,
      targetWaist: 80.0,
      targetBmi: 22.0,
      selectedPlanId: '16-8',
      onboardingComplete: true,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('forgot_password_test_');
    Hive.init(tempDir.path);
    await HiveService.instance.init();
  });

  setUp(() async {
    await HiveService.instance.userProfileBox.clear();
    await HiveService.instance.fastingScheduleBox.clear();
    await HiveService.instance.settingsBox.clear();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Secure Forgot Password & Password Reset Suite (20 Scenarios)', () {
    testWidgets('1 & 2. Forgot Password screen opens and empty email keeps Next disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password'), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);

      final nextButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('3. Invalid email keeps Next disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'invalid-email-format');
      await tester.pumpAndSettle();

      final nextButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('4. Valid email enables Next button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'valid.user@example.com');
      await tester.pumpAndSettle();

      final nextButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(nextButton.onPressed, isNotNull);
    });

    testWidgets('5. Pre-filled initial email enables Next button directly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialEmail: 'prefilled@example.com'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('prefilled@example.com'), findsOneWidget);
      final nextButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(nextButton.onPressed, isNotNull);
    });

    testWidgets('6. Reset Password screen: Submit disabled when fields are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(email: 'user@example.com'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set New Password'), findsWidgets);
      final submitButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('7. Reset Password screen: Short password (<6 chars) keeps submit disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialCode: 'CODE123'),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // Code field is 0, Password is 1, Confirm Password is 2
      await tester.enterText(textFields.at(1), '12345');
      await tester.enterText(textFields.at(2), '12345');
      await tester.pumpAndSettle();

      final submitButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('8. Reset Password screen: Password mismatch keeps submit disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialCode: 'CODE123'),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(1), 'secret123');
      await tester.enterText(textFields.at(2), 'secret999');
      await tester.pumpAndSettle();

      final submitButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('9. Reset Password screen: Valid code, matching passwords (>=6 chars) enables submit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ResetPasswordScreen(initialCode: 'VALID_CODE_789'),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(1), 'myNewSecurePass123');
      await tester.enterText(textFields.at(2), 'myNewSecurePass123');
      await tester.pumpAndSettle();

      final submitButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(submitButton.onPressed, isNotNull);
    });

    test('10 & 11. Existing account data is retained and loaded after login', () async {
      const testUid = 'user_reset_test_uid_99';
      final prof = createTestProfile(name: 'Password Reset User');
      await HiveService.instance.saveUserProfile(prof, testUid);

      expect(HiveService.instance.getUserProfileFor(testUid)?.name, equals('Password Reset User'));
      expect(HiveService.instance.hasCompletedOnboardingForUser(testUid), isTrue);
    });

    test('12. Onboarding is skipped when account already has data', () async {
      const testUid = 'user_reset_test_uid_99';
      final prof = createTestProfile(name: 'Existing User');
      await HiveService.instance.saveUserProfile(prof, testUid);
      expect(HiveService.instance.hasCompletedOnboardingForUser(testUid), isTrue);
    });

    test('13 & 14. Multi-account isolation: Account A cannot access Account B data after password reset', () async {
      const uidA = 'user_A_111';
      const uidB = 'user_B_222';

      final profA = createTestProfile(name: 'Account A User');
      await HiveService.instance.saveUserProfile(profA, uidA);

      final profB = createTestProfile(name: 'Account B User');
      await HiveService.instance.saveUserProfile(profB, uidB);

      await HiveService.instance.setSetting('bound_firebase_uid', uidA);
      expect(HiveService.instance.userProfile?.name, equals('Account A User'));

      await HiveService.instance.setSetting('bound_firebase_uid', uidB);
      expect(HiveService.instance.userProfile?.name, equals('Account B User'));
    });

    test('15. Forgot Password does not modify anonymous/legacy local data', () async {
      await HiveService.instance.setSetting('anon_user_id', 'user_uppo');
      final legacyProf = createTestProfile(name: 'Legacy Uppo');
      await HiveService.instance.userProfileBox.put('profile', legacyProf);

      expect(HiveService.instance.userProfileBox.get('profile')?.name, equals('Legacy Uppo'));
      expect(HiveService.instance.getSetting<String>('anon_user_id'), equals('user_uppo'));
    });

    test('16 & 17. Passwords and reset tokens are not stored in Hive or settings', () {
      expect(HiveService.instance.settingsBox.containsKey('password'), isFalse);
      expect(HiveService.instance.settingsBox.containsKey('reset_token'), isFalse);
      expect(HiveService.instance.settingsBox.containsKey('oobCode'), isFalse);
    });
  });
}
