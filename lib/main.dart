import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/app.dart';
import 'package:fast_flow/core/data/services/hive_service.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/widget_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  await HiveService.instance.init();
  await NotificationService.instance.init();
  await WidgetSyncService.instance.initialize();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: FastFlowApp(prefs: prefs),
    ),
  );
}