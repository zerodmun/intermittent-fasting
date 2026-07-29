import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/services/hive_service.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final themeStr = HiveService.instance.getSetting<String>('theme_mode');
    if (themeStr != null) {
      return ThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemeMode.system,
      );
    }
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await HiveService.instance.setSetting('theme_mode', mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return HiveService.instance.getSetting<bool>('notifications_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('notifications_enabled', enabled);
  }
}

final notificationsEnabledProvider = NotifierProvider<NotificationsEnabledNotifier, bool>(
  NotificationsEnabledNotifier.new,
);

class DefaultPlanIdNotifier extends Notifier<String> {
  @override
  String build() {
    return HiveService.instance.getSetting<String>('default_plan_id') ?? '16:8';
  }

  Future<void> setPlanId(String planId) async {
    state = planId;
    await HiveService.instance.setSetting('default_plan_id', planId);
  }
}

final defaultPlanIdProvider = NotifierProvider<DefaultPlanIdNotifier, String>(
  DefaultPlanIdNotifier.new,
);

class EatingNotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return HiveService.instance.getSetting<bool>('eating_notification_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('eating_notification_enabled', enabled);
  }
}

final eatingNotificationsEnabledProvider = NotifierProvider<EatingNotificationsEnabledNotifier, bool>(
  EatingNotificationsEnabledNotifier.new,
);

class FastingNotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return HiveService.instance.getSetting<bool>('fasting_notification_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('fasting_notification_enabled', enabled);
  }
}

final fastingNotificationsEnabledProvider = NotifierProvider<FastingNotificationsEnabledNotifier, bool>(
  FastingNotificationsEnabledNotifier.new,
);

// ── Fasting Reminder Providers ──

class ReminderFastingEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return HiveService.instance.getSetting<bool>('reminder_fasting_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('reminder_fasting_enabled', enabled);
  }
}

final reminderFastingEnabledProvider = NotifierProvider<ReminderFastingEnabledNotifier, bool>(
  ReminderFastingEnabledNotifier.new,
);

class ReminderIftarEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return HiveService.instance.getSetting<bool>('reminder_iftar_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('reminder_iftar_enabled', enabled);
  }
}

final reminderIftarEnabledProvider = NotifierProvider<ReminderIftarEnabledNotifier, bool>(
  ReminderIftarEnabledNotifier.new,
);

class ReminderSoundNotifier extends Notifier<String> {
  @override
  String build() {
    return HiveService.instance.getSetting<String>('reminder_sound') ?? 'default';
  }

  Future<void> setSound(String sound) async {
    state = sound;
    await HiveService.instance.setSetting('reminder_sound', sound);
  }
}

final reminderSoundProvider = NotifierProvider<ReminderSoundNotifier, String>(
  ReminderSoundNotifier.new,
);

class ReminderVibrationNotifier extends Notifier<bool> {
  @override
  bool build() {
    return HiveService.instance.getSetting<bool>('reminder_vibration') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await HiveService.instance.setSetting('reminder_vibration', enabled);
  }
}

final reminderVibrationProvider = NotifierProvider<ReminderVibrationNotifier, bool>(
  ReminderVibrationNotifier.new,
);