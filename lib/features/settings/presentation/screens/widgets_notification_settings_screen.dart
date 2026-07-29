import 'package:flutter/material.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/services/widget_sync_service.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';

/// Dedicated screen for managing all Widget synchronization preferences
/// and Persistent / Ongoing Foreground Notification settings.
class WidgetsNotificationSettingsScreen extends StatefulWidget {
  const WidgetsNotificationSettingsScreen({super.key});

  @override
  State<WidgetsNotificationSettingsScreen> createState() => _WidgetsNotificationSettingsScreenState();
}

class _WidgetsNotificationSettingsScreenState extends State<WidgetsNotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final widgetSettings = WidgetSyncService.instance.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widgets & Persistent Notification'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        children: [
          // ── Home Screen Widget Section ──
          const SectionHeader(title: 'Home Screen Widgets'),
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
                  value: widgetSettings.widgetEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      widgetSettings.copyWith(widgetEnabled: val),
                    );
                    setState(() {});
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
                  value: widgetSettings.progressRingEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      widgetSettings.copyWith(progressRingEnabled: val),
                    );
                    setState(() {});
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
                  value: widgetSettings.bodyFatEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      widgetSettings.copyWith(bodyFatEnabled: val),
                    );
                    setState(() {});
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
                  value: widgetSettings.weightEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      widgetSettings.copyWith(weightEnabled: val),
                    );
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Persistent Notification Section ──
          const SectionHeader(title: 'Persistent Countdown Notification'),
          AppCard.elevated(
            child: Column(
              children: [
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
                  value: widgetSettings.notificationEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      widgetSettings.copyWith(notificationEnabled: val),
                    );
                    setState(() {});
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
                  value: widgetSettings.liveCountdownEnabled,
                  onChanged: (val) {
                    WidgetSyncService.instance.updateSettings(
                      widgetSettings.copyWith(liveCountdownEnabled: val),
                    );
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
