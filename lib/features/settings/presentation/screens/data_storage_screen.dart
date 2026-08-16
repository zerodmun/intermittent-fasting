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
                // 1. Export Backup (Normal export does not require warning dialog)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.upload_file_rounded, color: colorScheme.primary),
                  title: Text(
                    'Export Backup',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Export profile, fasting records, and weight data to JSON.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  onTap: () async {
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
                  },
                ),
                const Divider(),
                // 2. Restore Backup (Requires warning confirmation dialog)
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
                      title: 'Restore backup?',
                      content: 'Restoring this backup may replace your current data. Make sure you have a recent backup of your current data before continuing.',
                      confirmLabel: 'Restore',
                      cancelLabel: 'CANCEL',
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
                  title: 'Delete all data?',
                  content: 'This will permanently delete all locally stored application data, including your history, records, schedules, and settings. This action cannot be undone.',
                  confirmLabel: 'DELETE ALL',
                  cancelLabel: 'CANCEL',
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
