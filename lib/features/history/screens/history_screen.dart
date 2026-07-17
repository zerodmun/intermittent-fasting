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
import '../providers/history_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/widgets/shimmer_loading.dart';

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
}