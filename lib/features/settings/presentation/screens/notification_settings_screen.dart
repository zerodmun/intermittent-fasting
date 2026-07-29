import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:fast_flow/features/settings/presentation/providers/settings_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';

/// Dedicated screen for managing all notification settings, permissions,
/// sound & vibration preferences, and notification channels.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool? _permissionStatus;
  bool _checkingPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    setState(() {
      _checkingPermission = true;
    });
    try {
      final status = await NotificationService.instance.requestPermissions();
      if (mounted) {
        setState(() {
          _permissionStatus = status;
          _checkingPermission = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _permissionStatus = false;
          _checkingPermission = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final eatingNotificationsEnabled = ref.watch(eatingNotificationsEnabledProvider);
    final fastingNotificationsEnabled = ref.watch(fastingNotificationsEnabledProvider);
    final reminderFastingEnabled = ref.watch(reminderFastingEnabledProvider);
    final reminderIftarEnabled = ref.watch(reminderIftarEnabledProvider);
    final reminderSound = ref.watch(reminderSoundProvider);
    final reminderVibration = ref.watch(reminderVibrationProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        children: [
          // ── General Notifications Section ──
          const SectionHeader(title: 'General Notifications'),
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
                    'Master switch for all scheduled reminders and transition alerts.',
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
                      await NotificationService.instance.cancelReminderNotifications();
                    }
                    _checkPermissionStatus();
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _permissionStatus == true ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: _permissionStatus == true ? Colors.green : colorScheme.error,
                  ),
                  title: Text(
                    'System Permission Status',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _checkingPermission
                        ? 'Checking permission status...'
                        : (_permissionStatus == true ? 'Permission Granted' : 'Permission Denied / Required'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _permissionStatus == true ? Colors.green : colorScheme.error,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: _checkPermissionStatus,
                    child: const Text('Check / Request'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Fasting Reminders Section ──
          const SectionHeader(title: 'Fasting Reminders'),
          AppCard.elevated(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Fasting Reminder',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Notify 10 min before and at fasting start time.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: reminderFastingEnabled,
                  onChanged: notificationsEnabled
                      ? (val) async {
                          await ref.read(reminderFastingEnabledProvider.notifier).setEnabled(val);
                        }
                      : null,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Iftar Reminder',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Notify 10 min before and at iftar time.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: reminderIftarEnabled,
                  onChanged: notificationsEnabled
                      ? (val) async {
                          await ref.read(reminderIftarEnabledProvider.notifier).setEnabled(val);
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Sound & Vibration Section ──
          const SectionHeader(title: 'Sound & Vibration'),
          AppCard.elevated(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Notification Sound',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _soundDisplayName(reminderSound),
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
                  onTap: notificationsEnabled
                      ? () => _showSoundPicker(context, ref, reminderSound)
                      : null,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Vibration',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Vibrate on reminder notification.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  value: reminderVibration,
                  onChanged: notificationsEnabled
                      ? (val) async {
                          await ref.read(reminderVibrationProvider.notifier).setEnabled(val);
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Window Transition Alerts Section ──
          const SectionHeader(title: 'Fasting Window Transitions'),
          AppCard.elevated(
            child: Column(
              children: [
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
                  onChanged: notificationsEnabled
                      ? (val) async {
                          await ref.read(eatingNotificationsEnabledProvider.notifier).setEnabled(val);
                        }
                      : null,
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
                  onChanged: notificationsEnabled
                      ? (val) async {
                          await ref.read(fastingNotificationsEnabledProvider.notifier).setEnabled(val);
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),



          // ── Advanced Notification Configuration Section ──
          const SectionHeader(title: 'Advanced & System Info'),
          AppCard.elevated(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_rounded, color: colorScheme.primary),
                  title: Text(
                    'Active Notification Channels',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Displays registered Android notification channels.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Notification Channels'),
                        content: const SingleChildScrollView(
                          child: Text(
                            '• fasting_schedule: High Priority (Transitions)\n'
                            '• fasting_reminders: High Priority (System Default Sound)\n'
                            '• fasting_reminders_app: High Priority (App Sound: bell.mp3)\n'
                            '• fasting_reminders_silent: High Priority (Silent)\n'
                            '• fasting_timer: Low Priority (Ongoing Countdown)',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (Platform.isAndroid) ...[
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.battery_saver_rounded, color: colorScheme.primary),
                    title: Text(
                      'Battery Optimization Note',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Ensure battery optimization is disabled for Fast Flow to guarantee exact alarm delivery.',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// Returns human-readable display name for the sound preference key
  String _soundDisplayName(String soundKey) {
    switch (soundKey) {
      case 'app_notification':
      case 'bell':
      case 'adhan':
        return 'App Notification';
      case 'silent':
        return 'Silent';
      default:
        return 'Default';
    }
  }

  /// Shows a modal bottom sheet to pick the reminder notification sound
  void _showSoundPicker(BuildContext context, WidgetRef ref, String currentSound) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const sounds = [
      {'key': 'default', 'label': 'Default', 'icon': Icons.notifications_active_rounded},
      {'key': 'app_notification', 'label': 'App Notification', 'icon': Icons.notifications_rounded},
      {'key': 'silent', 'label': 'Silent', 'icon': Icons.notifications_off_rounded},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm,
                ),
                child: Text(
                  'Notification Sound',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ...sounds.map((sound) {
                final key = sound['key'] as String;
                final label = sound['label'] as String;
                final icon = sound['icon'] as IconData;
                final isSelected = currentSound == key ||
                    (key == 'app_notification' && (currentSound == 'bell' || currentSound == 'adhan'));

                return ListTile(
                  leading: Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                  title: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(reminderSoundProvider.notifier).setSound(key);
                    Navigator.pop(sheetContext);
                  },
                );
              }),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}
