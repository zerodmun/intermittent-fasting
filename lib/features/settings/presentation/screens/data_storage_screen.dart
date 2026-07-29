import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_dialog.dart';
import 'package:fast_flow/shared/widgets/section_header.dart';

/// Dedicated screen for managing Data & Storage (Export, Restore, Reset).
class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data & Storage'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        children: [
          const SectionHeader(title: 'Backup & Restore'),
          AppCard.elevated(
            child: Column(
              children: [
                // 1. Export Backup
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
                    final confirm = await AppDialog.showConfirm(
                      context: context,
                      title: 'Export Backup Data',
                      content: 'Are you sure you want to export your profile, fasting records, and weight data to a JSON backup file?',
                      confirmLabel: 'Export',
                      cancelLabel: 'Cancel',
                    );
                    if (confirm == true) {
                      final path = await HiveService.instance.exportData();
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AppDialog(
                            title: 'Data Exported',
                            content: 'Backup file exported successfully to:\n\n$path',
                            confirmLabel: 'OK',
                            onConfirm: () => Navigator.pop(context),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                // 2. Restore Backup
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_backup_restore_rounded, color: colorScheme.primary),
                  title: Text(
                    'Restore Backup',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Restore profile, fasting logs, and weight data from JSON.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  onTap: () async {
                    final confirm = await AppDialog.showConfirm(
                      context: context,
                      title: 'Restore Backup Data',
                      content: 'Are you sure you want to restore your data from backup? This will overwrite your current profile, fasting records, and weight data.',
                      confirmLabel: 'Restore',
                      cancelLabel: 'Cancel',
                    );
                    if (confirm == true) {
                      final dir = await getApplicationDocumentsDirectory();
                      final file = File('${dir.path}/fastflow_export.json');
                      if (await file.exists()) {
                        final jsonString = await file.readAsString();
                        await HiveService.instance.importData(jsonString);
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AppDialog(
                              title: 'Data Restored',
                              content: 'Your backup data has been restored successfully.',
                              confirmLabel: 'OK',
                              onConfirm: () => Navigator.pop(context),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AppDialog(
                              title: 'No Backup File Found',
                              content: 'No backup file found at:\n\n${dir.path}/fastflow_export.json\n\nPlease export a backup file first.',
                              confirmLabel: 'OK',
                              onConfirm: () => Navigator.pop(context),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const SectionHeader(title: 'Danger Zone'),
          AppCard.elevated(
            child: ListTile(
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
                  content: 'Warning: This action cannot be undone. All your profile settings, fasting records, workout logs, and weight data will be permanently deleted.',
                  confirmLabel: 'Reset Everything',
                  cancelLabel: 'Cancel',
                  isDestructive: true,
                );
                if (confirm == true) {
                  await HiveService.instance.resetAll();
                  if (context.mounted) {
                    context.go('/onboarding');
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
