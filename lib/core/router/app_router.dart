import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_flow/features/fasting/screens/fasting_screen.dart';
import 'package:fast_flow/features/history/screens/history_screen.dart';
import 'package:fast_flow/features/home/screens/home_screen.dart';
import 'package:fast_flow/features/onboarding/screens/onboarding_screen.dart';
import 'package:fast_flow/features/settings/screens/settings_screen.dart';
import 'package:fast_flow/features/statistics/screens/statistics_screen.dart';
import 'package:fast_flow/features/weight/screens/weight_screen.dart';
import 'package:fast_flow/features/body_composition/presentation/screens/body_comp_screen.dart';
import 'package:fast_flow/features/body_composition/presentation/screens/progress_photos_screen.dart';
import 'package:fast_flow/features/food_scanner/presentation/pages/food_scanner_screen.dart';
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

  late final GoRouter router = GoRouter(
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
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
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
            routes: [
              GoRoute(
                path: foodScanner,
                builder: (context, state) => const FoodScannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: statistics,
                builder: (context, state) => const StatisticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
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