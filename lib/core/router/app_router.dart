import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_flow/core/services/hive_service.dart';

import 'package:fast_flow/features/fasting/presentation/screens/fasting_screen.dart';

import 'package:fast_flow/features/history/presentation/screens/history_screen.dart';
import 'package:fast_flow/features/home/presentation/screens/home_screen.dart';
import 'package:fast_flow/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:fast_flow/features/settings/presentation/screens/settings_screen.dart';
import 'package:fast_flow/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:fast_flow/features/settings/presentation/screens/data_storage_screen.dart';
import 'package:fast_flow/features/statistics/presentation/screens/statistics_screen.dart';
import 'package:fast_flow/features/weight/presentation/screens/weight_screen.dart';
import 'package:fast_flow/features/body_composition/presentation/screens/body_comp_screen.dart';
import 'package:fast_flow/features/body_composition/presentation/screens/progress_photos_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/food_scanner_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/barcode_scanner_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/product_result_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/ai_camera_preview_screen.dart';
import 'package:fast_flow/features/food/presentation/screens/ai_food_result_screen.dart';
import 'package:fast_flow/features/food/data/models/food_product.dart';
import 'package:fast_flow/features/food/data/models/food_recognition_model.dart';
import 'package:fast_flow/features/auth/presentation/screens/login_screen.dart';
import 'package:fast_flow/features/auth/presentation/screens/register_screen.dart';
import 'package:fast_flow/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:fast_flow/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:fast_flow/shared/widgets/app_scaffold.dart';

import 'package:fast_flow/features/auth/presentation/screens/account_screen.dart';

/// App-wide route configuration using GoRouter with shell routing.
class AppRouter {
  final SharedPreferences prefs;

  AppRouter({required this.prefs});

  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String account = '/account';
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
    redirect: (context, state) {
      if (state.matchedLocation == '/') return home;
      final isOnboarding = state.matchedLocation == onboarding;

      final isLogin = state.matchedLocation == login;
      final isRegister = state.matchedLocation == register;
      final isAccount = state.matchedLocation == account;
      final isForgotPassword = state.matchedLocation == forgotPassword || state.matchedLocation.startsWith(forgotPassword);
      final isResetPassword = state.matchedLocation == resetPassword || state.matchedLocation.startsWith(resetPassword);

      final onboarded = HiveService.instance.hasCompletedOnboardingForUser();

      if (!onboarded && !isOnboarding && !isLogin && !isRegister && !isAccount && !isForgotPassword && !isResetPassword) return onboarding;
      if (onboarded && isOnboarding) return home;
      return null;
    },

    routes: [
      GoRoute(
        path: onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: forgotPassword,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return ForgotPasswordScreen(initialEmail: email);
        },
      ),
      GoRoute(
        path: resetPassword,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          final code = state.uri.queryParameters['code'] ?? state.uri.queryParameters['oobCode'];
          return ResetPasswordScreen(email: email, initialCode: code);
        },
      ),
      GoRoute(
        path: account,
        builder: (context, state) => const AccountScreen(),
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
                  GoRoute(
                    path: 'ai-preview',
                    builder: (context, state) {
                      final imagePath = state.extra as String;
                      return AiCameraPreviewScreen(imagePath: imagePath);
                    },
                  ),
                  GoRoute(
                    path: 'ai-result',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>;
                      final imagePath = extra['imagePath'] as String;
                      final result = extra['result'] as FoodRecognitionModel;
                      return AiFoodResultScreen(
                        imagePath: imagePath,
                        result: result,
                      );
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
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'data-storage',
                    builder: (context, state) => const DataStorageScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}