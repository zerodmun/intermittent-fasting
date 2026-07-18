import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_animations.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../../fasting/domain/entities/fasting_record.dart';
import '../../fasting/presentation/providers/fasting_providers.dart';
import '../providers/history_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_input.dart';

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
    final recordsAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return recordsAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: 5,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerLoading(width: double.infinity, height: 75),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (records) {
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
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, FastingRecord record) {
    final theme = Theme.of(context);
    final isCompleted = record.status == 'completed';

    return AppCard.elevated(
      padding: EdgeInsets.zero,
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
          record.planName,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${DateFormat('MMM dd, yyyy').format(record.startTime)} • ${record.actualDuration.toReadable}',
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
    );
  }

  Widget _buildCalendarView(BuildContext context, WidgetRef ref, DateTime selectedDay) {
    final theme = Theme.of(context);
    final selectedRecord = _getRecordForDay(ref, selectedDay);

    return SingleChildScrollView(
      key: const ValueKey('calendar_view'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard.elevated(
            padding: const EdgeInsets.all(AppSpacing.sm),
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
                ref.read(selectedDayProvider.notifier).state = selected;
              },
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
      title: 'Delete Fast Log',
      content: 'Are you sure you want to permanently delete this fasting record?',
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
    final records = ref.read(historyProvider).maybeWhen(
          data: (data) => data,
          orElse: () => <FastingRecord>[],
        );
    return records.where((r) => r.startTime.isSameDay(day)).toList();
  }

  FastingRecord? _getRecordForDay(WidgetRef ref, DateTime day) {
    final events = _getEventsForDay(ref, day);
    return events.isNotEmpty ? events.first : null;
  }

  void _editManualLogSheet(BuildContext context, FastingRecord existing, WidgetRef ref) {
    final noteController = TextEditingController(text: existing.note ?? '');
    DateTime startTime = existing.startTime;
    DateTime endTime = existing.endTime ?? existing.startTime.add(Duration(minutes: existing.fastingMinutes));
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
      title: 'Edit Day Log',
      child: StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final duration = endTime.difference(startTime);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Start Date Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Start Time:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () async {
                      final dt = await selectDateTime(context, startTime);
                      if (dt != null) {
                        setState(() {
                          startTime = dt;
                          if (endTime.isBefore(startTime)) {
                            endTime = startTime.add(const Duration(hours: 16));
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(DateFormat('MMM dd, HH:mm').format(startTime)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // End Date Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('End Time:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () async {
                      final dt = await selectDateTime(context, endTime);
                      if (dt != null) {
                        setState(() {
                          endTime = dt;
                          if (endTime.isBefore(startTime)) {
                            startTime = endTime.subtract(const Duration(hours: 16));
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(DateFormat('MMM dd, HH:mm').format(endTime)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Calculated Duration info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Calculated Fast:', style: theme.textTheme.bodySmall),
                    Text(
                      duration.inMinutes % 60 == 0
                          ? '${duration.inHours}h'
                          : '${duration.inHours}h ${duration.inMinutes % 60}m',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Status Dropdown
              DropdownButtonFormField<String>(
                value: status,
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
                onPressed: () {
                  ref.read(fastingStateNotifierProvider.notifier).editFastingRecord(
                    id: existing.id,
                    startTime: startTime,
                    endTime: endTime,
                    status: status,
                    note: noteController.text,
                    reason: existing.reason,
                  );
                  ref.read(historyProviderNotifier.notifier).refresh();
                  Navigator.of(context).pop();
                  context.showSnack('Log updated successfully', isSuccess: true);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.outlined(
                label: 'Delete Log',
                onPressed: () async {
                  final confirm = await AppDialog.showConfirm(
                    context: context,
                    title: 'Delete Log',
                    content: 'Are you sure you want to delete this fasting record?',
                    isDestructive: true,
                  );
                  if (confirm == true && context.mounted) {
                    await ref.read(historyProviderNotifier.notifier).deleteRecord(existing.id);
                    Navigator.of(context).pop();
                    context.showSnack('Fasting record deleted');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}