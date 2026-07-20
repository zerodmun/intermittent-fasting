import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Root scaffold with bottom navigation bar using StatefulShellRoute and modern PopScope behavior.
class AppScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final GlobalKey<NavigatorState> homeKey;
  final GlobalKey<NavigatorState> foodScannerKey;
  final GlobalKey<NavigatorState> statisticsKey;
  final GlobalKey<NavigatorState> settingsKey;

  const AppScaffold({
    required this.navigationShell,
    required this.homeKey,
    required this.foodScannerKey,
    required this.statisticsKey,
    required this.settingsKey,
    super.key,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  DateTime? _lastBackTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. Check if the root navigator can pop (dialogs, modal sheets)
        final rootNavigator = Navigator.of(context);
        if (rootNavigator.canPop()) {
          rootNavigator.pop();
          return;
        }

        // 2. Check if the active branch nested navigator can pop
        final GlobalKey<NavigatorState> activeKey;
        switch (widget.navigationShell.currentIndex) {
          case 0:
            activeKey = widget.homeKey;
            break;
          case 1:
            activeKey = widget.foodScannerKey;
            break;
          case 2:
            activeKey = widget.statisticsKey;
            break;
          case 3:
            activeKey = widget.settingsKey;
            break;
          default:
            activeKey = widget.homeKey;
        }

        final activeNavigator = activeKey.currentState;
        if (activeNavigator != null && activeNavigator.canPop()) {
          activeNavigator.pop();
          return;
        }

        // 3. Otherwise, we are at the root of a bottom navigation tab.
        // If we are not on the Home tab (index 0), go back to Home.
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        // 4. Double click/swipe on Home tab inside 2 seconds - close application safely
        final now = DateTime.now();
        if (_lastBackTime == null || now.difference(_lastBackTime!) > const Duration(seconds: 2)) {
          _lastBackTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Double click/swipe inside 2 seconds - close application safely
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) => widget.navigationShell.goBranch(index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Food Scanner',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}