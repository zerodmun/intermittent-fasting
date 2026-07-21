import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fast_flow/core/services/hive_service.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeStr = HiveService.instance.getSetting<String>('theme_mode');
    if (themeStr != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await HiveService.instance.setSetting('theme_mode', mode.name);
  }
}

final notificationsEnabledProvider = StateNotifierProvider<NotificationsEnabledNotifier, bool>((ref) {
  return NotificationsEnabledNotifier(ref);
});

class NotificationsEnabledNotifier extends StateNotifier<bool> {
  final Ref _ref;
  NotificationsEnabledNotifier(this._ref) : super(true) {
    _load();
  }

  Future<void> _load() async {
    final enabled = HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('notifications_enabled', enabled);
  }
}

final defaultPlanIdProvider = StateNotifierProvider<DefaultPlanIdNotifier, String>((ref) {
  return DefaultPlanIdNotifier(ref);
});

class DefaultPlanIdNotifier extends StateNotifier<String> {
  final Ref _ref;
  DefaultPlanIdNotifier(this._ref) : super('16:8') {
    _load();
  }

  Future<void> _load() async {
    final planId = HiveService.instance.getSetting<String>('default_plan_id') ?? '16:8';
    state = planId;
  }

  Future<void> setPlanId(String planId) async {
    state = planId;
    await HiveService.instance.setSetting('default_plan_id', planId);
  }
}

final eatingNotificationsEnabledProvider = StateNotifierProvider<EatingNotificationsEnabledNotifier, bool>((ref) {
  return EatingNotificationsEnabledNotifier();
});

class EatingNotificationsEnabledNotifier extends StateNotifier<bool> {
  EatingNotificationsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final enabled = HiveService.instance.getSetting<bool>('eating_notification_enabled') ?? true;
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('eating_notification_enabled', enabled);
  }
}

final fastingNotificationsEnabledProvider = StateNotifierProvider<FastingNotificationsEnabledNotifier, bool>((ref) {
  return FastingNotificationsEnabledNotifier();
});

class FastingNotificationsEnabledNotifier extends StateNotifier<bool> {
  FastingNotificationsEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final enabled = HiveService.instance.getSetting<bool>('fasting_notification_enabled') ?? true;
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('fasting_notification_enabled', enabled);
  }
}