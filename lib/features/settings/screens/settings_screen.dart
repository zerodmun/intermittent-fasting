import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/core/services/notification_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fast_flow/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/illustrations/settings_illustration.svg',
              height: 120,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(context, 'Appearance'),
          Card(
            child: ListTile(
              title: const Text('Theme Mode'),
              subtitle: Text(themeMode.name.toUpperCase()),
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.dark, label: Icon(Icons.dark_mode)),
                  ButtonSegment(value: ThemeMode.system, label: Icon(Icons.settings)),
                ],
                selected: {themeMode},
                onSelectionChanged: (set) => themeNotifier.setThemeMode(set.first),
              ),
            ),
          ),
          _buildSectionHeader(context, 'Fasting Preferences'),
          Card(
            child: ListTile(
              title: const Text('Daily Fasting Schedule'),
              subtitle: const Text('Configure custom fasting and eating hours for each day.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.go('/home/fasting'),
            ),
          ),
          _buildSectionHeader(context, 'Notifications'),
          Card(
            child: SwitchListTile(
              title: const Text('Enable Reminders'),
              subtitle: const Text('Notify when fasting/eating window starts or finishes.'),
              value: notificationsEnabled,
              onChanged: (val) async {
                ref.read(notificationsEnabledProvider.notifier).setEnabled(val);
                if (val) {
                  await NotificationService.instance.requestPermissions();
                } else {
                  await NotificationService.instance.cancelAll();
                }
              },
            ),
          ),
          _buildSectionHeader(context, 'Data Management'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Export Backup'),
                  subtitle: const Text('Export all profile, weight, and history data to JSON.'),
                  onTap: () async {
                    final path = await HiveService.instance.exportData();
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Data Exported'),
                          content: Text('Backup file exported to:\n\n$path'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Backup'),
                  subtitle: const Text('Import previously exported JSON backup.'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Import Backup'),
                        content: const Text(
                          'To import a JSON backup file, place your fastflow_export.json inside your app documents folder or contact support.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Reset All Data', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Wipe all local user profiles, logs, and settings.'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Reset'),
                        content: const Text(
                          'Are you sure you want to delete all user profiles, fasting histories, weight tracking logs, and app settings? This action is irreversible.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await HiveService.instance.resetAll();
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.clear();
                              if (context.mounted) {
                                context.go('/onboarding');
                              }
                            },
                            child: const Text('Reset Everything', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildSectionHeader(context, 'About'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('App Name'),
                  trailing: Text('FastFlow'),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text('Version'),
                  trailing: Text('1.0.0 (Production)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.sm),
      child: Text(
        title,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
