import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:fast_flow/app.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/startup_diag.dart';
import 'package:fast_flow/core/services/logger_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupDiag.start();

  // Initialize Firebase App safely if configured
  try {
    await Firebase.initializeApp();
    StartupDiag.log('Firebase initialized');
  } catch (e) {
    LoggerService.w('main: Firebase initializeApp skipped or failed: $e');
  }

  // Load environment variables (.env) safely
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    LoggerService.e('main: Failed to load .env file', e);
  }

  // Enforce completely offline typography loading
  GoogleFonts.config.allowRuntimeFetching = false;

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Fast local storage & local notification plugin initialization
  try {
    await HiveService.instance.init();
    StartupDiag.log('Hive initialized');
    await NotificationService.instance.initLocal();
  } catch (e, stackTrace) {
    LoggerService.e('main: Service initialization failed', e, stackTrace);
  }

  // Obtain SharedPreferences with a fail-safe fallback
  late final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    LoggerService.e('main: Failed to initialize SharedPreferences', e);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    StartupDiag.log('First Flutter frame');
    NotificationService.instance.initBackgroundServices();
  });

  StartupDiag.log('runApp START');

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: FastFlowApp(prefs: prefs),
    ),
  );
}