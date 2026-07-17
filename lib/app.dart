import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/router/app_router.dart';
import 'package:fast_flow/core/theme/app_theme.dart';
import 'package:fast_flow/features/settings/providers/settings_provider.dart';

/// Root widget providing theme, routing, and Riverpod scope.
class FastFlowApp extends ConsumerWidget {
  final SharedPreferences prefs;

  const FastFlowApp({required this.prefs, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = AppRouter(prefs: prefs).router;

    return MaterialApp.router(
      title: 'FastFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
