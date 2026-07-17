import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = HiveService.instance.getSetting<String>('theme_mode');
    if (stored == 'light') {
      return ThemeMode.light;
    } else if (stored == 'dark') {
      return ThemeMode.dark;
    } else {
      return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    HiveService.instance.setSetting('theme_mode', mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
  }

  void setEnabled(bool enabled) {
    state = enabled;
    HiveService.instance.setSetting('notifications_enabled', enabled);
  }
}

final notificationsEnabledProvider = NotifierProvider<NotificationsEnabledNotifier, bool>(NotificationsEnabledNotifier.new);

class DefaultPlanIdNotifier extends Notifier<String> {
  @override
  String build() {
    return HiveService.instance.getSetting<String>('default_plan') ?? '16_8';
  }

  void setPlanId(String planId) {
    state = planId;
    HiveService.instance.setSetting('default_plan', planId);
  }
}

final defaultPlanIdProvider = NotifierProvider<DefaultPlanIdNotifier, String>(DefaultPlanIdNotifier.new);
