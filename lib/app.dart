import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/core/router/app_router.dart';
import 'package:fast_flow/core/theme/app_theme.dart';
import 'package:fast_flow/features/settings/presentation/providers/settings_providers.dart';

/// Root widget providing theme, routing, and Riverpod scope.
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:fast_flow/core/services/logger_service.dart';

class FastFlowApp extends ConsumerStatefulWidget {
  final SharedPreferences prefs;

  const FastFlowApp({required this.prefs, super.key});

  @override
  ConsumerState<FastFlowApp> createState() => _FastFlowAppState();
}

class _FastFlowAppState extends ConsumerState<FastFlowApp> {
  static const _channel = MethodChannel('com.fastflow.app/widget_sync');
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter(prefs: widget.prefs).router;
    _setupDeepLinking();
  }

  void _setupDeepLinking() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'navigate') {
        final route = call.arguments as String?;
        if (route != null) {
          _handleNavigation(route);
        }
      }
    });

    Future.microtask(() async {
      try {
        final route = await _channel.invokeMethod<String>('getInitialRoute');
        if (route != null) {
          _handleNavigation(route);
        }
      } catch (_) {}
    });
  }

  void _handleNavigation(String route) {
    LoggerService.d('[AppDeepLink] Received route: "$route"');
    if (route == '/' || route.isEmpty) {
      LoggerService.d('[AppDeepLink] Ignoring default root route to preserve current/restored route state');
      return;
    }
    String target = route;
    if (route == '/body_composition') target = '/home/body-composition';
    LoggerService.d('[AppDeepLink] Redirecting GoRouter to: $target');
    _router.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Fomo IF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}