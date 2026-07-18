import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/providers/app_providers.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import '../../../../shared/widgets/app_card.dart';

class MonthlyCalendarScreen extends ConsumerWidget {
  const MonthlyCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(fastingRecordsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Fasting Calendar'),
        centerTitle: true,
      ),
      body: recordsAsync.when(
        data: (records) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final firstDay = DateTime(now.year, now.month, 1);
          final lastDay = DateTime(now.year, now.month + 1, 0);

          final weekdayOffset = firstDay.weekday - 1; // 0 for Monday, 6 for Sunday
          final totalCells = weekdayOffset + lastDay.day;
          final totalRows = (totalCells / 7).ceil();

          int completedCount = 0;
          int missedCount = 0;

          // Process all days of the month to count status
          for (int d = 1; d <= lastDay.day; d++) {
            final dayDate = DateTime(now.year, now.month, d);
            if (dayDate.isAfter(today)) continue;

            bool isCompleted = false;
            for (final FastingRecord r in records) {
              if (r.status == 'completed' &&
                  r.startTime.year == dayDate.year &&
                  r.startTime.month == dayDate.month &&
                  r.startTime.day == dayDate.day) {
                isCompleted = true;
                break;
              }
            }

            if (isCompleted) {
              completedCount++;
            } else {
              missedCount++;
            }
          }

          final totalTrackedDays = completedCount + missedCount;
          final monthlyCompletionPercent = totalTrackedDays > 0
              ? ((completedCount / totalTrackedDays) * 100).round()
              : 0;

          final weekdayHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Month Header
                Text(
                  _getMonthName(now.month) + ' ${now.year}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Calendar Grid Card
                AppCard.elevated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      // Weekday Initials Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: weekdayHeaders.map((header) {
                          return SizedBox(
                            width: 32,
                            child: Text(
                              header,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: AppSpacing.md),

                      // Grid Rows
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalRows,
                        itemBuilder: (context, rowIndex) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(7, (colIndex) {
                              final cellIndex = rowIndex * 7 + colIndex;
                              final dayNum = cellIndex - weekdayOffset + 1;

                              if (cellIndex < weekdayOffset || dayNum > lastDay.day) {
                                return const SizedBox(width: 32, height: 32);
                              }

                              final dayDate = DateTime(now.year, now.month, dayNum);
                              bool isFuture = dayDate.isAfter(today);
                              bool isCompleted = false;

                              for (final FastingRecord r in records) {
                                if (r.status == 'completed' &&
                                    r.startTime.year == dayDate.year &&
                                    r.startTime.month == dayDate.month &&
                                    r.startTime.day == dayDate.day) {
                                  isCompleted = true;
                                  break;
                                }
                              }

                              Color cellBg = Colors.transparent;
                              Color textColor = colorScheme.onSurface;
                              Widget icon = const SizedBox.shrink();

                              if (isFuture) {
                                textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
                              } else {
                                if (isCompleted) {
                                  cellBg = Colors.green.withValues(alpha: 0.15);
                                  textColor = Colors.green;
                                  icon = const Icon(Icons.check, size: 10, color: Colors.green);
                                } else {
                                  cellBg = Colors.red.withValues(alpha: 0.15);
                                  textColor = Colors.red;
                                  icon = const Icon(Icons.close, size: 10, color: Colors.red);
                                }
                              }

                              return Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: cellBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned(
                                      top: 4,
                                      child: Text(
                                        '$dayNum',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (!isFuture)
                                      Positioned(
                                        bottom: 2,
                                        child: icon,
                                      ),
                                  ],
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Current Month Summary
                Text(
                  'Current Month Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                AppCard.elevated(
                  child: Column(
                    children: [
                      _buildSummaryRow(context, 'Total Completed Days', '$completedCount days', Colors.green),
                      const Divider(height: AppSpacing.md),
                      _buildSummaryRow(context, 'Total Missed Days', '$missedCount days', Colors.red),
                      const Divider(height: AppSpacing.md),
                      _buildSummaryRow(
                        context,
                        'Monthly Completion Rate',
                        '$monthlyCompletionPercent%',
                        colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading records: $err')),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
