import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/constants/app_animations.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/extensions/date_extensions.dart';
import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/presentation/providers/fasting_providers.dart';
import 'package:fast_flow/features/history/presentation/providers/history_providers.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';
import 'package:fast_flow/shared/widgets/app_button.dart';
import 'package:fast_flow/shared/widgets/app_dialog.dart';
import 'package:fast_flow/shared/widgets/animated_list_item.dart';
import 'package:fast_flow/shared/widgets/app_bottom_sheet.dart';
import 'package:fast_flow/shared/widgets/app_input.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalendar = ref.watch(historyViewModeProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Logs'),
        actions: [
          IconButton(
            icon: Icon(isCalendar ? Icons.list_alt_rounded : Icons.calendar_month_rounded),
            color: theme.colorScheme.primary,
            onPressed: () {
              ref.read(historyViewModeProvider.notifier).toggle();
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppAnimations.medium,
        child: isCalendar
            ? _buildCalendarView(context, ref, selectedDay)
            : _buildListView(context, ref),
      ),
    );
  }

  Widget _buildListView(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyProvider);

    if (records.isEmpty) {
      return const EmptyState(
        key: ValueKey('empty_list'),
        icon: Icons.history_rounded,
        title: 'No fasting history yet',
        subtitle: 'Completed cycles will appear here chronologically.',
      );
    }

    return ListView.builder(
      key: const ValueKey('list_view'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AnimatedListItem(
            index: index,
            child: _buildHistoryCard(context, ref, record),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, FastingRecord record) {
    final theme = Theme.of(context);
    final isCompleted = record.status == 'completed';
    final endDateFormatted = DateFormat('d MMMM yyyy').format(record.fastingEndAt);

    return AppCard.elevated(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => _editManualLogSheet(context, record, ref),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isCompleted
                  ? context.colors.success.withValues(alpha: 0.1)
                  : theme.colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
              color: isCompleted ? context.colors.success : theme.colorScheme.error,
            ),
          ),
          title: Text(
            endDateFormatted,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${record.planName} • ${record.actualDuration.toReadable}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: theme.colorScheme.error,
            onPressed: () => _confirmDelete(context, ref, record.id),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarView(BuildContext context, WidgetRef ref, DateTime selectedDay) {
    final theme = Theme.of(context);
    final selectedRecord = _getRecordForDay(ref, selectedDay);

    return SingleChildScrollView(
      key: const ValueKey('calendar_view'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard.elevated(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Align(
              alignment: Alignment.topCenter,
              child: TableCalendar<FastingRecord>(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 30)),
                focusedDay: selectedDay,
                selectedDayPredicate: (day) => day.isSameDay(selectedDay),
                eventLoader: (day) => _getEventsForDay(ref, day),
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: context.colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                onDaySelected: (selected, focused) {
                  ref.read(selectedDayProvider.notifier).select(selected);
                },
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          if (selectedRecord != null) ...[
            Text(
              'Selected Date Log',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildHistoryCard(context, ref, selectedRecord),
          ] else ...[
            AppCard.outlined(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  'No log recorded for this date.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: 'Delete this data?',
      content: 'This data will be permanently removed. This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirm == true) {
      await ref.read(historyProviderNotifier.notifier).deleteRecord(id);
      if (context.mounted) {
        context.showSnack('Fasting record deleted');
      }
    }
  }

  List<FastingRecord> _getEventsForDay(WidgetRef ref, DateTime day) {
    final records = ref.read(historyProvider);
    return records.where((r) => r.fastingEndAt.isSameDay(day)).toList();
  }

  FastingRecord? _getRecordForDay(WidgetRef ref, DateTime day) {
    final events = _getEventsForDay(ref, day);
    return events.isNotEmpty ? events.first : null;
  }

  void _editManualLogSheet(BuildContext context, FastingRecord existing, WidgetRef ref) {
    final noteController = TextEditingController(text: existing.note ?? '');
    DateTime startTime = existing.startTime;
    DateTime endTime = existing.fastingEndAt;
    String status = existing.status;

    Future<DateTime?> selectDateTime(BuildContext ctx, DateTime initial) async {
      final date = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 30)),
      );
      if (date == null) return null;

      if (ctx.mounted) {
        final time = await showTimePicker(
          context: ctx,
          initialTime: TimeOfDay.fromDateTime(initial),
        );
        if (time == null) return null;
        return DateTime(date.year, date.month, date.day, time.hour, time.minute);
      }
      return null;
    }

    AppBottomSheet.show(
      context: context,
      title: 'Fasting Session Details',
      child: StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final bool isValid = endTime.isAfter(startTime);
          final duration = isValid ? endTime.difference(startTime) : Duration.zero;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fasting Start Details Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fasting Start',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final dt = await selectDateTime(context, startTime);
                              if (dt != null) {
                                setState(() {
                                  startTime = dt;
                                });
                              }
                            },
                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                            label: const Text('Change'),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('d MMMM yyyy').format(startTime),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('HH:mm').format(startTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Fasting End Details Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fasting End',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final dt = await selectDateTime(context, endTime);
                              if (dt != null) {
                                setState(() {
                                  endTime = dt;
                                });
                              }
                            },
                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                            label: const Text('Change'),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('d MMMM yyyy').format(endTime),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('HH:mm').format(endTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Duration Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isValid
                        ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                        : colorScheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Duration',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isValid ? duration.toDetailedSpelledOut : 'Invalid time range',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isValid ? colorScheme.primary : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isValid) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Fasting end time must be after start time.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),

                // Status Dropdown
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Fasting Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'skipped', child: Text('Skipped')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        status = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                AppInput(
                  label: 'Note',
                  controller: noteController,
                ),
                const SizedBox(height: AppSpacing.lg),

                AppButton.primary(
                  label: 'Save Changes',
                  onPressed: isValid
                      ? () {
                          final success = ref.read(fastingStateNotifierProvider.notifier).editFastingRecord(
                            id: existing.id,
                            startTime: startTime,
                            endTime: endTime,
                            status: status,
                            note: noteController.text,
                            reason: existing.reason,
                          );
                          if (success) {
                            ref.read(historyProviderNotifier.notifier).refresh();
                            Navigator.of(context).pop();
                            context.showSnack('Log updated successfully', isSuccess: true);
                          } else {
                            context.showSnack('Invalid time range', isError: true);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton.outlined(
                  label: 'Delete Log',
                  onPressed: () async {
                    final confirm = await AppDialog.showConfirm(
                      context: context,
                      title: 'Delete this data?',
                      content: 'This data will be permanently removed. This action cannot be undone.',
                      confirmLabel: 'Delete',
                      cancelLabel: 'Cancel',
                      isDestructive: true,
                    );

                    if (confirm == true && context.mounted) {
                      await ref.read(historyProviderNotifier.notifier).deleteRecord(existing.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        context.showSnack('Fasting record deleted');
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}