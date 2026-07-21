import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/features/fasting/presentation/screens/fasting_screen.dart';
import 'package:fast_flow/features/history/presentation/screens/history_screen.dart';
import 'package:fast_flow/features/home/presentation/screens/home_screen.dart';
import 'package:fast_flow/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:fast_flow/features/settings/presentation/screens/settings_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/statistics_screen.dart';
import 'package:fast_flow/features/weight/presentation/screens/weight_screen.dart';
import 'package:fast_flow/features/body_composition/presentation/screens/body_comp_screen.dart';
import 'package:fast_flow/features/body_composition/presentation/screens/progress_photos_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/food_scanner_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/barcode_scanner_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/product_result_screen.dart';
import 'package:fast_flow/features/food/data/models/food_product.dart';
import 'package:fast_flow/shared/widgets/app_scaffold.dart';

/// App-wide route configuration using GoRouter with shell routing.
class AppRouter {
  final SharedPreferences prefs;

  AppRouter({required this.prefs});

  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String history = '/home/history';
  static const String foodScanner = '/food-scanner';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
  static const String fasting = '/fasting';
  static const String weight = '/weight';
  static const String bodyComposition = '/home/body-composition';

  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _foodScannerNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _statisticsNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _settingsNavigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: home,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final onboarded = prefs.getBool('onboarding_complete') ?? false;
      final isOnboarding = state.matchedLocation == onboarding;

      if (!onboarded && !isOnboarding) return onboarding;
      if (onboarded && isOnboarding) return home;
      return null;
    },
    routes: [
      GoRoute(
        path: onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(
            navigationShell: navigationShell,
            homeKey: _homeNavigatorKey,
            foodScannerKey: _foodScannerNavigatorKey,
            statisticsKey: _statisticsNavigatorKey,
            settingsKey: _settingsNavigatorKey,
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'fasting',
                    builder: (context, state) => const FastingScreen(),
                  ),
                  GoRoute(
                    path: 'weight',
                    builder: (context, state) => const WeightScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                  ),
                  GoRoute(
                    path: 'body-composition',
                    builder: (context, state) => const BodyCompScreen(),
                    routes: [
                      GoRoute(
                        path: 'photos',
                        builder: (context, state) => const ProgressPhotosScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _foodScannerNavigatorKey,
            routes: [
              GoRoute(
                path: foodScanner,
                builder: (context, state) => const FoodScannerScreen(),
                routes: [
                  GoRoute(
                    path: 'camera',
                    builder: (context, state) => const BarcodeScannerPage(),
                  ),
                  GoRoute(
                    path: 'result',
                    builder: (context, state) {
                      final product = state.extra as FoodProduct;
                      return ProductResultScreen(product: product);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _statisticsNavigatorKey,
            routes: [
              GoRoute(
                path: statistics,
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}