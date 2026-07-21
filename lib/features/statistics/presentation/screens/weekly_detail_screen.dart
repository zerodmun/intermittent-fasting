import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/providers/app_providers.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/shared/widgets/app_card.dart';

class WeeklyDetailScreen extends ConsumerWidget {
  const WeeklyDetailScreen({super.key});

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(fastingRecordsProvider);
    final scheduleAsync = ref.watch(fastingScheduleProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly History Details'),
        centerTitle: true,
      ),
      body: recordsAsync.when(
        data: (records) {
          return scheduleAsync.when(
            data: (schedule) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final monday = today.subtract(Duration(days: today.weekday - 1));

              // Generate Monday to Sunday list
              final List<Map<String, dynamic>> days = [];
              int completedCount = 0;

              for (int i = 0; i < 7; i++) {
                final dayDate = monday.add(Duration(days: i));
                final weekdayName = _getWeekdayName(dayDate.weekday);

                // Find completed record for this day
                FastingRecord? record;
                for (final r in records) {
                  if (r.status == 'completed' &&
                      r.startTime.year == dayDate.year &&
                      r.startTime.month == dayDate.month &&
                      r.startTime.day == dayDate.day) {
                    record = r;
                    break;
                  }
                }

                String statusText = '';
                Color statusColor = Colors.grey;
                String trailingText = '';

                if (record != null) {
                  statusText = 'Completed';
                  statusColor = Colors.green;
                  completedCount++;
                  final duration = record.actualDuration;
                  if (duration.inMinutes % 60 == 0) {
                    trailingText = '${duration.inHours}h';
                  } else {
                    trailingText = '${duration.inHours}h ${duration.inMinutes % 60}m';
                  }
                } else {
                  if (dayDate.isBefore(today)) {
                    statusText = 'Missed';
                    statusColor = Colors.red;
                  } else if (dayDate.isAfter(today)) {
                    statusText = 'Upcoming';
                    statusColor = Colors.grey;
                  } else {
                    // Today
                    final daySched = schedule.getScheduleFor(dayDate.weekday);
                    final fastStart = DateTime(dayDate.year, dayDate.month, dayDate.day, daySched.fastHour, daySched.fastMin);
                    DateTime fastEnd = DateTime(dayDate.year, dayDate.month, dayDate.day, daySched.eatHour, daySched.eatMin);
                    if (fastEnd.isBefore(fastStart) || fastEnd.isAtSameMomentAs(fastStart)) {
                      fastEnd = fastEnd.add(const Duration(days: 1));
                    }

                    if (now.isBefore(fastStart)) {
                      statusText = 'Upcoming';
                      statusColor = Colors.grey;
                    } else if (now.isAfter(fastEnd)) {
                      statusText = 'Missed';
                      statusColor = Colors.red;
                    } else {
                      statusText = 'In Progress';
                      statusColor = Colors.orange;
                    }
                  }
                }

                days.add({
                  'name': weekdayName,
                  'dateText': '${dayDate.day}/${dayDate.month}',
                  'status': statusText,
                  'color': statusColor,
                  'trailing': trailingText,
                });
              }

              final completionPercent = ((completedCount / 7) * 100).round();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard.elevated(
                      child: Column(
                        children: [
                          Text(
                            'This Week\'s Progress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '$completedCount / 7 Completed',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completionPercent% Completion Rate',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard.elevated(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day['name'] as String,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      day['dateText'] as String,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (day['color'] as Color).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                      ),
                                      child: Text(
                                        day['status'] as String,
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: day['color'] as Color,
                                        ),
                                      ),
                                    ),
                                    if ((day['trailing'] as String).isNotEmpty) ...[
                                      const SizedBox(width: AppSpacing.md),
                                      Text(
                                        day['trailing'] as String,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading schedule: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading history: $err')),
      ),
    );
  }
}
