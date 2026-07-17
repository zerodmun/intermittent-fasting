import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fast_flow/core/constants/app_colors.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/features/fasting/models/fasting_record.dart';
import 'package:fast_flow/features/history/providers/history_provider.dart';
import 'package:fast_flow/shared/widgets/empty_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyProvider);
    final isCalendar = ref.watch(historyViewModeProvider);
    final selectedDay = ref.watch(selectedDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: Icon(isCalendar ? Icons.list : Icons.calendar_today),
            onPressed: () {
              ref.read(historyViewModeProvider.notifier).toggle();
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isCalendar
            ? _buildCalendarView(context, ref, records, selectedDay)
            : _buildListView(context, ref, records),
      ),
    );
  }

  Widget _buildListView(BuildContext context, WidgetRef ref, List<FastingRecord> records) {
    if (records.isEmpty) {
      return const EmptyState(
        key: ValueKey('empty_list'),
        icon: Icons.history,
        title: 'No fasting history yet',
        subtitle: 'Once you complete or cancel a fast, it will show up here.',
        illustrationPath: 'assets/illustrations/empty_history.svg',
      );
    }

    return ListView.builder(
      key: const ValueKey('list_view'),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildDismissibleTile(context, ref, record);
      },
    );
  }

  Widget _buildCalendarView(
    BuildContext context,
    WidgetRef ref,
    List<FastingRecord> records,
    DateTime selectedDay,
  ) {
    // Helper to find records for a given day
    List<FastingRecord> getEventsForDay(DateTime day) {
      return records.where((r) => DateUtils.isSameDay(r.startTime, day)).toList();
    }

    final selectedEvents = getEventsForDay(selectedDay);

    return Column(
      key: const ValueKey('calendar_view'),
      children: [
        TableCalendar<FastingRecord>(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 30)),
          focusedDay: selectedDay,
          selectedDayPredicate: (day) => DateUtils.isSameDay(day, selectedDay),
          eventLoader: getEventsForDay,
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: context.colorScheme.primary.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: context.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: AppColors.fastingActive,
              shape: BoxShape.circle,
            ),
          ),
          onDaySelected: (selected, focused) {
            ref.read(selectedDayProvider.notifier).select(selected);
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: selectedEvents.isEmpty
              ? const EmptyState(
                  icon: Icons.event_busy,
                  title: 'No activities on this day',
                  illustrationPath: 'assets/illustrations/empty_history.svg',
                )
              : ListView.builder(
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final record = selectedEvents[index];
                    return _buildDismissibleTile(context, ref, record);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDismissibleTile(BuildContext context, WidgetRef ref, FastingRecord record) {
    final isCompleted = record.status == 'completed';

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xxl),
        color: context.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Record'),
            content: const Text('Are you sure you want to delete this fasting record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete', style: TextStyle(color: context.colorScheme.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(historyProvider.notifier).deleteRecord(record.id);
        context.showSnack('Fasting record deleted.');
      },
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isCompleted
                ? AppColors.success.withValues(alpha: 0.15)
                : context.colorScheme.error.withValues(alpha: 0.15),
            child: Icon(
              isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isCompleted ? AppColors.success : context.colorScheme.error,
            ),
          ),
          title: Text(
            record.planName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${DateFormat('MMM d, h:mm a').format(record.startTime)} → ${record.endTime != null ? DateFormat('h:mm a').format(record.endTime!) : '--:--'}',
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                'Duration: ${record.actualDuration.toReadable}',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success.withValues(alpha: 0.15)
                      : context.colorScheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    color: isCompleted ? AppColors.success : context.colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
