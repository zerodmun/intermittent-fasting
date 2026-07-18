import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/color_schemes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_animations.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/duration_extensions.dart';
import '../../../core/data/services/hive_service.dart';
import '../domain/entities/fasting_record.dart';
import '../domain/entities/fasting_schedule.dart';
import '../domain/entities/fasting_state.dart';
import '../presentation/providers/fasting_providers.dart';
import '../../../shared/widgets/animated_progress_ring.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/section_header.dart';

class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  int _activeSegment = 0;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fastingStateNotifierProvider);
    final notifier = ref.read(fastingStateNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasting Plan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  _buildTabOption(0, 'Timer'),
                  _buildTabOption(1, 'Schedule'),
                  _buildTabOption(2, 'Timeline'),
                  _buildTabOption(3, 'Calendar'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppAnimations.medium,
              child: _buildSegmentContent(state, notifier),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOption(int index, String label) {
    final isSelected = _activeSegment == index;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSegment = index),
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            boxShadow: isSelected
                ? AppSpacing.shadowSm(
                    theme.brightness == Brightness.dark ? Colors.black : theme.colorScheme.outlineVariant,
                  )
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentContent(FastingState? state, FastingStateNotifier notifier) {
    switch (_activeSegment) {
      case 1:
        return _buildScheduleSegment(state, notifier);
      case 2:
        return _buildTimelineSegment(state);
      case 3:
        return _buildCalendarSegment(state, notifier);
      case 0:
      default:
        return _buildTimerSegment(state, notifier);
    }
  }

  // ── TIMER SEGMENT ──
  Widget _buildTimerSegment(FastingState? state, FastingStateNotifier notifier) {
    if (state == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color ringColor;
    IconData centerIcon;

    switch (state.status) {
      case FastingStatus.preparing:
        ringColor = context.colors.preparingActive;
        centerIcon = Icons.hourglass_top_rounded;
        break;
      case FastingStatus.fasting:
        ringColor = context.colors.fastingActive;
        centerIcon = Icons.nights_stay_outlined;
        break;
      case FastingStatus.eatingWindow:
        ringColor = context.colors.eatingActive;
        centerIcon = Icons.restaurant_rounded;
        break;
      case FastingStatus.completed:
        ringColor = context.colors.completedActive;
        centerIcon = Icons.check_circle_outline_rounded;
        break;
      case FastingStatus.skipped:
        ringColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
        centerIcon = Icons.block;
        break;
      default:
        ringColor = colorScheme.primary;
        centerIcon = Icons.timer_outlined;
    }

    final activeWeekday = state.activeWindowStart.weekday;
    final activeSched = state.schedule.getScheduleFor(activeWeekday);

    return SingleChildScrollView(
      key: const ValueKey('timer_segment'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        children: [
          Center(
            child: AnimatedProgressRing(
              progress: state.progress,
              size: 250,
              strokeWidth: 12,
              color: ringColor,
              backgroundColor: ringColor.withValues(alpha: 0.15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(centerIcon, size: 40, color: ringColor),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.status.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ringColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.remaining.toHHMMSS,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Elapsed: ${state.elapsed.toReadable}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          AppCard.elevated(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Active Plan",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTimeColumn(context, 'Fasting Starts', _formatTime(activeSched.fastHour, activeSched.fastMin)),
                    _buildTimeColumn(context, 'Eating Starts', _formatTime(activeSched.eatHour, activeSched.eatMin)),
                    _buildTimeColumn(
                      context,
                      'Fasting Target',
                      '${(24.0 - _getEatingMinutes(activeWeekday, state.schedule) / 60.0).toStringAsFixed(1).replaceAll('.0', '')}h',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Complete Fast',
                  variant: AppButtonVariant.primary,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    notifier.logManualAction('completed');
                    context.showSnack('Logged completed fast', isSuccess: true);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Skip Window',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.block_rounded,
                  onPressed: () {
                    notifier.logManualAction('skipped');
                    context.showSnack('Logged skipped window');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ── WEEKLY SCHEDULE SEGMENT ──
  Widget _buildScheduleSegment(FastingState? state, FastingStateNotifier notifier) {
    if (state == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final schedule = state.schedule;
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return SingleChildScrollView(
      key: const ValueKey('schedule_segment'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Routine',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppButton.text(
                label: 'Copy Monday to All',
                size: AppButtonSize.sm,
                onPressed: () {
                  final monday = schedule.getScheduleFor(1);
                  final updatedMap = Map<int, DailySchedule>.from(schedule.dailySchedules);
                  for (int i = 2; i <= 7; i++) {
                    updatedMap[i] = DailySchedule(
                      fastHour: monday.fastHour,
                      fastMin: monday.fastMin,
                      eatHour: monday.eatHour,
                      eatMin: monday.eatMin,
                    );
                  }
                  HiveService.instance.saveFastingSchedule(schedule.copyWith(dailySchedules: updatedMap));
                  notifier.onScheduleChanged();
                  context.showSnack('Routine updated: Monday copied to all days', isSuccess: true);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, idx) {
              final weekdayNum = idx + 1;
              final daySched = schedule.getScheduleFor(weekdayNum);
              final isToday = DateTime.now().weekday == weekdayNum;

              return AppCard.elevated(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                weekdays[idx],
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (isToday) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'TODAY',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(Icons.nights_stay_outlined, size: 14, color: context.colors.fastingActive),
                              const SizedBox(width: 4),
                              Text(
                                'Fast: ${_formatTime(daySched.fastHour, daySched.fastMin)}',
                                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Icon(Icons.restaurant_rounded, size: 14, color: context.colors.eatingActive),
                              const SizedBox(width: 4),
                              Text(
                                'Eat: ${_formatTime(daySched.eatHour, daySched.eatMin)}',
                                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editDaySchedule(context, weekdayNum, daySched, notifier),
                      icon: const Icon(Icons.edit_calendar_rounded),
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── TIMELINE SEGMENT ──
  Widget _buildTimelineSegment(FastingState? state) {
    if (state == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final days = ['Yesterday', 'Today', 'Tomorrow'];

    return SingleChildScrollView(
      key: const ValueKey('timeline_segment'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(3, (idx) {
          final date = DateTime.now().add(Duration(days: idx - 1));
          final sched = state.schedule.getScheduleFor(date.weekday);
          final record = _getRecordForDay(date);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard.elevated(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        days[idx],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (record != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: record.status == 'completed'
                                ? context.colors.successContainer
                                : theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            record.status.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: record.status == 'completed'
                                  ? context.colors.onSuccessContainer
                                  : theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildTimelineRow('Scheduled Fast', '${_formatTime(sched.fastHour, sched.fastMin)} - ${_formatTime(sched.eatHour, sched.eatMin)}'),
                  if (record != null) ...[
                    _buildTimelineRow('Actual Fast', '${DateFormat('HH:mm').format(record.startTime)} - ${record.endTime != null ? DateFormat('HH:mm').format(record.endTime!) : "Active"}'),
                    _buildTimelineRow('Logged Duration', record.actualDuration.toReadable),
                    if (record.note != null && record.note!.isNotEmpty)
                      _buildTimelineRow('Note', record.note!),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimelineRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── CALENDAR SEGMENT ──
  Widget _buildCalendarSegment(FastingState? state, FastingStateNotifier notifier) {
    if (state == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final selectedRecord = _getRecordForDay(_selectedDay);

    return SingleChildScrollView(
      key: const ValueKey('calendar_segment'),
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard.elevated(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 365)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: context.colors.success,
                  shape: BoxShape.circle,
                ),
              ),
              eventLoader: (day) {
                final r = _getRecordForDay(day);
                return r != null ? [r] : [];
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionHeader(title: 'Details for ${DateFormat('MMMM dd').format(_selectedDay)}'),
          if (selectedRecord != null) ...[
            AppCard.elevated(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedRecord.planName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => _editManualLogSheet(context, selectedRecord, notifier),
                        icon: const Icon(Icons.edit_calendar_rounded),
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTimelineRow('Fasted Time', selectedRecord.actualDuration.toReadable),
                  _buildTimelineRow('Status', selectedRecord.status.toUpperCase()),
                  if (selectedRecord.note != null && selectedRecord.note!.isNotEmpty)
                    _buildTimelineRow('Notes', selectedRecord.note!),
                ],
              ),
            ),
          ] else ...[
            AppCard.outlined(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Text(
                      'No fasting log found for this day.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.outlined(
                      label: 'Log Manually',
                      onPressed: () => _createManualLogSheet(context, _selectedDay, state.schedule, notifier),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── LOG MUTATIONS ──
  void _editDaySchedule(BuildContext context, int weekdayNum, DailySchedule current, FastingStateNotifier notifier) async {
    final theme = Theme.of(context);
    final fastTime = TimeOfDay(hour: current.fastHour, minute: current.fastMin);
    final eatTime = TimeOfDay(hour: current.eatHour, minute: current.eatMin);

    final selectedFast = await showTimePicker(
      context: context,
      initialTime: fastTime,
      helpText: 'Fasting Starts',
    );

    if (selectedFast == null) return;

    if (context.mounted) {
      final selectedEat = await showTimePicker(
        context: context,
        initialTime: eatTime,
        helpText: 'Eating Starts',
      );

      if (selectedEat == null) return;

      final updatedSched = notifier.state?.schedule.copyWith() ?? FastingSchedule.defaultSchedule();
      updatedSched.dailySchedules[weekdayNum] = DailySchedule(
        fastHour: selectedFast.hour,
        fastMin: selectedFast.minute,
        eatHour: selectedEat.hour,
        eatMin: selectedEat.minute,
      );

      await HiveService.instance.saveFastingSchedule(updatedSched);
      notifier.onScheduleChanged();
      context.showSnack('Plan updated successfully', isSuccess: true);
    }
  }

  void _createManualLogSheet(BuildContext context, DateTime day, FastingSchedule schedule, FastingStateNotifier notifier) {
    final noteController = TextEditingController();
    final daySched = schedule.getScheduleFor(day.weekday);
    final formKey = GlobalKey<FormState>();

    AppBottomSheet.show(
      context: context,
      title: 'Manual Day Entry',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Input records for ${DateFormat('MMMM dd, yyyy').format(day)}.'),
            const SizedBox(height: AppSpacing.md),
            AppInput(
              label: 'Note / Reason',
              controller: noteController,
              hint: 'e.g. Completed scheduled fast successfully.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: 'Log as Completed',
              onPressed: () {
                final record = FastingRecord(
                  id: const Uuid().v4(),
                  planName: '16:8 Fast',
                  fastingMinutes: 16 * 60,
                  eatingMinutes: 8 * 60,
                  startTime: DateTime(day.year, day.month, day.day, daySched.fastHour, daySched.fastMin),
                  endTime: DateTime(day.year, day.month, day.day, daySched.eatHour, daySched.eatMin),
                  status: 'completed',
                  note: noteController.text,
                );

                HiveService.instance.saveFastingRecord(record);
                notifier.refresh();
                Navigator.of(context).pop();
                context.showSnack('Day logged as Completed', isSuccess: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editManualLogSheet(BuildContext context, FastingRecord existing, FastingStateNotifier notifier) {
    final noteController = TextEditingController(text: existing.note ?? '');

    AppBottomSheet.show(
      context: context,
      title: 'Edit Day Log',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInput(
            label: 'Note',
            controller: noteController,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Save Changes',
            onPressed: () {
              existing.note = noteController.text;
              HiveService.instance.saveFastingRecord(existing);
              notifier.refresh();
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
                await HiveService.instance.deleteFastingRecord(existing.id);
                notifier.refresh();
                Navigator.of(context).pop();
                context.showSnack('Fasting record deleted');
              }
            },
          ),
        ],
      ),
    );
  }

  // ── UTILS ──
  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _getEatingMinutes(int weekday, FastingSchedule schedule) {
    final daySched = schedule.getScheduleFor(weekday);
    final start = daySched.eatHour * 60 + daySched.eatMin;
    var end = daySched.fastHour * 60 + daySched.fastMin;
    if (end < start) end += 24 * 60;
    return end - start;
  }

  FastingRecord? _getRecordForDay(DateTime date) {
    final records = HiveService.instance.allFastingRecords;
    for (final r in records) {
      if (r.startTime.year == date.year &&
          r.startTime.month == date.month &&
          r.startTime.day == date.day) {
        return r;
      }
    }
    return null;
  }
}