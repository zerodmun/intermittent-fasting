import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/features/settings/presentation/providers/settings_providers.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
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



          const SectionHeader(title: 'Notification'),
          AppCard.elevated(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_active_rounded, color: colorScheme.primary),
                  title: Text(
                    'Notification Settings',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Reminders, sound, vibration & status options.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
                  onTap: () => context.go('/settings/notifications'),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.widgets_rounded, color: colorScheme.primary),
                  title: Text(
                    'Widgets & Persistent Notification',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Home screen widgets, persistent status & timer options.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
                  onTap: () => context.go('/settings/widgets-notification'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(title: 'Data Management'),
          AppCard.elevated(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.storage_rounded, color: colorScheme.primary),
              title: Text(
                'Data & Storage',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Backup, restore & database management.',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
              onTap: () => context.go('/settings/data-storage'),
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
