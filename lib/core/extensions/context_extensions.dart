import 'package:flutter/material.dart';
import '../theme/app_theme_extensions.dart';
import '../theme/color_schemes.dart';

extension ContextExtensions on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  ThemeData get theme => Theme.of(this);
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  NavigatorState get navigator => Navigator.of(this);
  ScaffoldMessengerState get scaffoldMessenger => ScaffoldMessenger.of(this);
  FocusScopeNode get focusScope => FocusScope.of(this);

  double get screenWidth => mediaQuery.size.width;
  double get screenHeight => mediaQuery.size.height;
  double get statusBarHeight => mediaQuery.padding.top;
  double get bottomPadding => mediaQuery.padding.bottom;
  double get viewInsetsBottom => mediaQuery.viewInsets.bottom;
  bool get isKeyboardOpen => viewInsetsBottom > 0;

  bool get isDarkMode => theme.brightness == Brightness.dark;
  bool get isLightMode => theme.brightness == Brightness.light;

  /// Helper to access custom semantic colors.
  AppColorsExtension get colors {
    return theme.extension<AppColorsExtension>() ?? (isDarkMode ? darkColorsExtension : lightColorsExtension);
  }

  /// Show standard design system Snackbars.
  void showSnack(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    scaffoldMessenger.clearSnackBars();

    final Color bgColor;
    final Color textColor;
    final IconData icon;

    if (isError) {
      bgColor = colorScheme.errorContainer;
      textColor = colorScheme.onErrorContainer;
      icon = Icons.error_outline_rounded;
    } else if (isSuccess) {
      bgColor = colors.successContainer;
      textColor = colors.onSuccessContainer;
      icon = Icons.check_circle_outline_rounded;
    } else {
      bgColor = colorScheme.primaryContainer;
      textColor = colorScheme.onPrimaryContainer;
      icon = Icons.info_outline_rounded;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: duration,
        elevation: 4,
      ),
    );
  }

  void hideKeyboard() {
    focusScope.unfocus();
  }
}