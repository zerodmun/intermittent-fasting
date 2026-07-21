import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/constants/app_animations.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/core/services/widget_sync_service.dart';
import 'package:fast_flow/features/settings/presentation/providers/settings_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/shared/widgets/app_dialog.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final eatingNotificationsEnabled = ref.watch(eatingNotificationsEnabledProvider);
    final fastingNotificationsEnabled = ref.watch(fastingNotificationsEnabledProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        children: [
          const SectionHeader(title: 'Appearance'),
          AppCard.elevated(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Theme Mode',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                themeMode.name.toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_rounded),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (set) => themeNotifier.setThemeMode(set.first),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(title: 'Fasting Preferences'),
          AppCard.elevated(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Daily Fasting Schedule',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Configure custom fasting and eating hours.',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
              onTap: () => context.go('/home/fasting'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(title: 'Notifications'),
          AppCard.elevated(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable Notifications',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Receive scheduled fasting and eating window transitions.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: notificationsEnabled,
                  onChanged: (val) async {
                    await ref.read(notificationsEnabledProvider.notifier).setEnabled(val);
                    if (val) {
                      final hasPerm = await NotificationService.instance.requestPermissions();
                      if (hasPerm == false && context.mounted) {
                        context.showSnack(
                          'Notification permission is denied. You can enable it in system settings.',
                          isError: true,
                        );
                      }
                    } else {
                      await NotificationService.instance.cancelAll();
                    }
                  },
                ),
                if (notificationsEnabled) ...[
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Eating Window Notification',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Notify when eating window starts.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    value: eatingNotificationsEnabled,
                    onChanged: (val) async {
                      await ref.read(eatingNotificationsEnabledProvider.notifier).setEnabled(val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Fasting Started Notification',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Notify when fasting begins.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    value: fastingNotificationsEnabled,
                    onChanged: (val) async {
                      await ref.read(fastingNotificationsEnabledProvider.notifier).setEnabled(val);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(title: 'Widgets & Persistent Notification'),
          AppCard.elevated(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Home Screen Widget',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Enable dynamic update of home widgets.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: WidgetSyncService.instance.settings.widgetEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      WidgetSyncService.instance.settings.copyWith(widgetEnabled: val),
                    );
                    (context as Element).markNeedsBuild();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Persistent Countdown Notification',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Show ongoing status and timer in notification drawer.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: WidgetSyncService.instance.settings.notificationEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      WidgetSyncService.instance.settings.copyWith(notificationEnabled: val),
                    );
                    (context as Element).markNeedsBuild();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Live Countdown Timer',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Display exact remaining hours and minutes.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: WidgetSyncService.instance.settings.liveCountdownEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      WidgetSyncService.instance.settings.copyWith(liveCountdownEnabled: val),
                    );
                    (context as Element).markNeedsBuild();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Fasting Progress Ring',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Show completed percentage gauge.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: WidgetSyncService.instance.settings.progressRingEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      WidgetSyncService.instance.settings.copyWith(progressRingEnabled: val),
                    );
                    (context as Element).markNeedsBuild();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Body Fat Information',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Display latest body fat percentage in widgets.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: WidgetSyncService.instance.settings.bodyFatEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      WidgetSyncService.instance.settings.copyWith(bodyFatEnabled: val),
                    );
                    (context as Element).markNeedsBuild();
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Weight Summary',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Display current weight stats in large widget.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: WidgetSyncService.instance.settings.weightEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      WidgetSyncService.instance.settings.copyWith(weightEnabled: val),
                    );
                    (context as Element).markNeedsBuild();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(title: 'Data Management'),
          AppCard.elevated(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.upload_file_rounded, color: colorScheme.primary),
                  title: Text(
                    'Export Backup',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Export all profile, weight, and logs to JSON.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  onTap: () async {
                    final path = await HiveService.instance.exportData();
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AppDialog(
                          title: 'Data Exported',
                          content: 'Backup file exported to:\n\n$path',
                          confirmLabel: 'OK',
                          onConfirm: () => Navigator.pop(context),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_rounded, color: colorScheme.error),
                  title: Text(
                    'Reset All Data',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                  subtitle: Text(
                    'Permanently wipe database and start onboarding.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  onTap: () async {
                    final confirm = await AppDialog.showConfirm(
                      context: context,
                      title: 'Reset All Data',
                      content: 'Are you sure? This will wipe your profile and logs permanently.',
                      isDestructive: true,
                    );
                    if (confirm == true && context.mounted) {
                      await HiveService.instance.resetAll();
                      context.go('/onboarding');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // About Section
          Center(
            child: Text(
              'Fomo IF v1.0.0',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
