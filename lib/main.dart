import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:fast_flow/app.dart';
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/widget_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce completely offline typography loading
  GoogleFonts.config.allowRuntimeFetching = false;

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services safely and concurrently with a timeout to ensure Splash Screen never hangs
  try {
    await HiveService.instance.init();
    await Future.wait([
      NotificationService.instance.init(),
      WidgetSyncService.instance.initialize(),
    ]).timeout(const Duration(seconds: 4), onTimeout: () {
      print('main: Service initialization timed out after 4 seconds. Proceeding to startup...');
      return [];
    });
  } catch (e, stackTrace) {
    print('main: Service initialization failed: $e\n$stackTrace');
  }

  // Obtain SharedPreferences with a fail-safe fallback
  late final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    print('main: Failed to initialize SharedPreferences: $e. Falling back to mock implementation...');
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: FastFlowApp(prefs: prefs),
    ),
  );
}