import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fast_flow/core/constants/app_colors.dart';
import 'package:fast_flow/core/constants/app_spacing.dart';
import 'package:fast_flow/core/extensions/context_extensions.dart';
import 'package:fast_flow/core/extensions/duration_extensions.dart';
import 'package:fast_flow/core/services/hive_service.dart';
import 'package:fast_flow/features/fasting/models/fasting_record.dart';
import 'package:fast_flow/features/fasting/models/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/providers/fasting_provider.dart';
import 'package:fast_flow/shared/widgets/animated_progress_ring.dart';
import 'package:uuid/uuid.dart';

class FastingScreen extends ConsumerStatefulWidget {
  const FastingScreen({super.key});

  @override
  ConsumerState<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends ConsumerState<FastingScreen> {
  int _activeSegment = 0; // 0 = Timer, 1 = Schedule, 2 = Timeline, 3 = Calendar
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fastingStateProvider2);
    final notifier = ref.read(fastingStateProvider2.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fasting Schedule'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Timer')),
                ButtonSegment(value: 1, label: Text('Schedule')),
                ButtonSegment(value: 2, label: Text('Timeline')),
                ButtonSegment(value: 3, label: Text('Calendar')),
              ],
              selected: {_activeSegment},
              onSelectionChanged: (val) {
                setState(() {
                  _activeSegment = val.first;
                });
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildSegmentContent(state, notifier),
            ),
          ),
        ],
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
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    Color ringColor;
    IconData centerIcon;

    switch (state.status) {
      case FastingStatus.preparing:
        ringColor = AppColors.amber400;
        centerIcon = Icons.hourglass_top_rounded;
        break;
      case FastingStatus.fasting:
        ringColor = AppColors.fastingActive;
        centerIcon = Icons.nights_stay_outlined;
        break;
      case FastingStatus.eatingWindow:
        ringColor = AppColors.eatingActive;
        centerIcon = Icons.restaurant_rounded;
        break;
      case FastingStatus.completed:
        ringColor = AppColors.success;
        centerIcon = Icons.check_circle_outline;
        break;
      case FastingStatus.skipped:
        ringColor = Colors.grey;
        centerIcon = Icons.block;
        break;
      default:
        ringColor = context.colorScheme.primary;
        centerIcon = Icons.timer_outlined;
    }

    final todaySched = state.schedule.getScheduleFor(DateTime.now().weekday);

    return SingleChildScrollView(
      key: const ValueKey('timer_segment'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          // Circular Progress Ring
          Center(
            child: AnimatedProgressRing(
              progress: state.progress,
              size: 260,
              strokeWidth: 12,
              color: ringColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(centerIcon, size: 36, color: ringColor),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    state.status.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ringColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.remaining.toHHMMSS,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Elapsed: ${state.elapsed.toReadable}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Today's Schedule Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    'Today\'s Schedule',
                    style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTimeColumn('Fasting Starts', _formatTime(todaySched['fastHour']!, todaySched['fastMin']!)),
                      _buildTimeColumn('Eating Starts', _formatTime(todaySched['eatHour']!, todaySched['eatMin']!)),
                      _buildTimeColumn(
                        'Fasting Hours',
                        '${(24.0 - _getEatingMinutes(DateTime.now().weekday, state.schedule) / 60.0).toStringAsFixed(1).replaceAll('.0', '')}h',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Manual action overrides
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Mark Completed'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () {
                  notifier.logManualAction('completed');
                  context.showSnack('Marked current window as Completed.');
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.block),
                label: const Text('Skip Fast'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  notifier.logManualAction('skipped');
                  context.showSnack('Marked current window as Skipped.');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── WEEKLY SCHEDULE SEGMENT ──
  Widget _buildScheduleSegment(FastingState? state, FastingStateNotifier notifier) {
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final schedule = state.schedule;
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return SingleChildScrollView(
      key: const ValueKey('schedule_segment'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Schedule Configuration',
                style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Copy Monday to All'),
                onPressed: () {
                  final monday = schedule.getScheduleFor(1);
                  final updatedMap = Map<int, Map<String, int>>.from(schedule.dailySchedules);
                  for (int i = 2; i <= 7; i++) {
                    updatedMap[i] = Map<String, int>.from(monday);
                  }
                  final updatedSchedule = schedule.copyWith(dailySchedules: updatedMap);
                  notifier.saveSchedule(updatedSchedule);
                  context.showSnack('Copied Monday schedule to all days.');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(7, (index) {
            final weekdayNum = index + 1;
            final dayName = weekdays[index];
            final daySched = schedule.getScheduleFor(weekdayNum);

            final fastHour = daySched['fastHour']!;
            final fastMin = daySched['fastMin']!;
            final eatHour = daySched['eatHour']!;
            final eatMin = daySched['eatMin']!;

            // Calculate fasting duration
            final startMin = fastHour * 60 + fastMin;
            final endMin = (eatHour * 60 + eatMin < startMin)
                ? (eatHour * 60 + eatMin) + 24 * 60
                : eatHour * 60 + eatMin;
            final fastingHoursCount = (endMin - startMin) / 60;
            final eatingHoursCount = 24.0 - fastingHoursCount;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: fastHour, minute: fastMin),
                              );
                              if (selected != null) {
                                final updatedMap = Map<int, Map<String, int>>.from(schedule.dailySchedules);
                                updatedMap[weekdayNum] = {
                                  'fastHour': selected.hour,
                                  'fastMin': selected.minute,
                                  'eatHour': eatHour,
                                  'eatMin': eatMin,
                                };
                                notifier.saveSchedule(schedule.copyWith(dailySchedules: updatedMap));
                              }
                            },
                            child: Column(
                              children: [
                                const Text('Start Fasting', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(_formatTime(fastHour, fastMin), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: eatHour, minute: eatMin),
                              );
                              if (selected != null) {
                                final updatedMap = Map<int, Map<String, int>>.from(schedule.dailySchedules);
                                updatedMap[weekdayNum] = {
                                  'fastHour': fastHour,
                                  'fastMin': fastMin,
                                  'eatHour': selected.hour,
                                  'eatMin': selected.minute,
                                };
                                notifier.saveSchedule(schedule.copyWith(dailySchedules: updatedMap));
                              }
                            },
                            child: Column(
                              children: [
                                const Text('Eating Starts', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(_formatTime(eatHour, eatMin), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${fastingHoursCount.toStringAsFixed(1).replaceAll('.0', '')}h Fasting • ${eatingHoursCount.toStringAsFixed(1).replaceAll('.0', '')}h Eating Window',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── TIMELINE SEGMENT ──
  Widget _buildTimelineSegment(FastingState? state) {
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    return ListView(
      key: const ValueKey('timeline_segment'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildTimelineDayCard('Yesterday', yesterday, state.schedule),
        const SizedBox(height: AppSpacing.md),
        _buildTimelineDayCard('Today', now, state.schedule, state.status.name),
        const SizedBox(height: AppSpacing.md),
        _buildTimelineDayCard('Tomorrow', tomorrow, state.schedule),
      ],
    );
  }

  Widget _buildTimelineDayCard(String label, DateTime date, FastingSchedule schedule, [String? currentStatus]) {
    final record = _getRecordForDay(date);
    final daySched = schedule.getScheduleFor(date.weekday);

    String statusStr = 'Fasting Scheduled';
    Color statusColor = context.colorScheme.primary;

    if (record != null) {
      if (record.status == 'completed') {
        statusStr = 'Completed';
        statusColor = AppColors.success;
      } else if (record.status == 'skipped') {
        statusStr = 'Skipped';
        statusColor = Colors.grey;
      } else if (record.status == 'cancelled') {
        statusStr = 'Cancelled';
        statusColor = Colors.red;
      }
    } else if (currentStatus != null) {
      statusStr = currentStatus;
      if (currentStatus == FastingStatus.fasting.name) statusColor = AppColors.fastingActive;
      if (currentStatus == FastingStatus.eatingWindow.name) statusColor = AppColors.eatingActive;
      if (currentStatus == FastingStatus.preparing.name) statusColor = AppColors.amber400;
    }

    final fastingStart = DateTime(date.year, date.month, date.day, daySched['fastHour']!, daySched['fastMin']!);
    final durationMin = _getFastingMinutes(date.weekday, schedule);
    final fastingEnd = fastingStart.add(Duration(minutes: durationMin));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$label (${DateFormat('MMM d').format(date)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusStr,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _buildTimelineRow('Scheduled', '${DateFormat('h:mm a').format(fastingStart)} → ${DateFormat('h:mm a').format(fastingEnd)}'),
            _buildTimelineRow('Actual Start', record != null ? DateFormat('h:mm a').format(record.startTime) : '--'),
            _buildTimelineRow('Actual End', record != null && record.endTime != null ? DateFormat('h:mm a').format(record.endTime!) : '--'),
            _buildTimelineRow(
              'Duration',
              record != null
                  ? '${(record.endTime?.difference(record.startTime).inMinutes ?? 0)} min'
                  : '$durationMin min',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── CALENDAR SEGMENT ──
  Widget _buildCalendarSegment(FastingState? state, FastingStateNotifier notifier) {
    return Column(
      key: const ValueKey('calendar_segment'),
      children: [
        TableCalendar(
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
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              final record = _getRecordForDay(date);
              if (record == null) return null;

              Color dotColor = Colors.grey;
              if (record.status == 'completed') dotColor = AppColors.success;
              if (record.status == 'skipped') dotColor = Colors.grey;
              if (record.status == 'cancelled') dotColor = Colors.red;

              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _buildSelectedDayDetails(_selectedDay, state!.schedule, notifier),
        ),
      ],
    );
  }

  Widget _buildSelectedDayDetails(DateTime date, FastingSchedule schedule, FastingStateNotifier notifier) {
    final record = _getRecordForDay(date);
    final daySched = schedule.getScheduleFor(date.weekday);

    if (record == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No record stored for this day yet.\n(Scheduled: ${_formatTime(daySched['fastHour']!, daySched['fastMin']!)} → ${_formatTime(daySched['eatHour']!, daySched['eatMin']!)})',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => _showManualLogSheet(context, date, schedule, notifier),
              child: const Text('Add Manual Override'),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fasting Record: ${DateFormat('MMM d').format(date)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showManualLogSheet(context, date, schedule, notifier, record),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _buildTimelineRow('Start Time', DateFormat('MMM d, h:mm a').format(record.startTime)),
            _buildTimelineRow('End Time', record.endTime != null ? DateFormat('MMM d, h:mm a').format(record.endTime!) : '--'),
            _buildTimelineRow('Fasting Status', record.status.toUpperCase()),
            _buildTimelineRow('Fasting Duration', '${record.fastingMinutes} minutes'),
            if (record.note != null) _buildTimelineRow('Note', record.note!),
            if (record.reason != null) _buildTimelineRow('Reason', record.reason!),
          ],
        ),
      ),
    );
  }

  void _showManualLogSheet(
    BuildContext context,
    DateTime date,
    FastingSchedule schedule,
    FastingStateNotifier notifier, [
    FastingRecord? existing,
  ]) {
    final noteController = TextEditingController(text: existing?.note ?? '');
    final reasonController = TextEditingController(text: existing?.reason ?? '');
    var status = existing?.status ?? 'completed';

    final daySched = schedule.getScheduleFor(date.weekday);

    var startHour = existing?.startTime.hour ?? daySched['fastHour']!;
    var startMin = existing?.startTime.minute ?? daySched['fastMin']!;

    var endHour = existing?.endTime?.hour ?? daySched['eatHour']!;
    var endMin = existing?.endTime?.minute ?? daySched['eatMin']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing != null ? 'Edit Override Record' : 'Add Override Record',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Status Selection
                      DropdownButton<String>(
                        value: status,
                        isExpanded: true,
                        onChanged: (val) {
                          if (val != null) setModalState(() => status = val);
                        },
                        items: const [
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'skipped', child: Text('Skipped')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Start picker
                      ListTile(
                        leading: const Icon(Icons.play_arrow_outlined),
                        title: const Text('Actual Fasting Start'),
                        trailing: Text(_formatTime(startHour, startMin)),
                        onTap: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: startHour, minute: startMin),
                          );
                          if (selected != null) {
                            setModalState(() {
                              startHour = selected.hour;
                              startMin = selected.minute;
                            });
                          }
                        },
                      ),

                      // End picker
                      ListTile(
                        leading: const Icon(Icons.stop_outlined),
                        title: const Text('Actual Eating Start'),
                        trailing: Text(_formatTime(endHour, endMin)),
                        onTap: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: endHour, minute: endMin),
                          );
                          if (selected != null) {
                            setModalState(() {
                              endHour = selected.hour;
                              endMin = selected.minute;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Note field
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Reason field
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      ElevatedButton(
                        onPressed: () {
                          final startDt = DateTime(date.year, date.month, date.day, startHour, startMin);
                          var endDt = DateTime(date.year, date.month, date.day, endHour, endMin);
                          if (endDt.isBefore(startDt)) {
                            // Overnight adjust
                            endDt = endDt.add(const Duration(days: 1));
                          }

                          if (existing != null) {
                            notifier.editFastingRecord(
                              id: existing.id,
                              startTime: startDt,
                              endTime: endDt,
                              status: status,
                              note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                              reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                            );
                          } else {
                            final record = FastingRecord(
                              id: const Uuid().v4(),
                              planName: 'Manual Override',
                              fastingMinutes: endDt.difference(startDt).inMinutes,
                              eatingMinutes: _getEatingMinutes(date.weekday, schedule),
                              startTime: startDt,
                              endTime: endDt,
                              status: status,
                              note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                              reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                            );
                            HiveService.instance.saveFastingRecord(record);
                          }
                          Navigator.pop(context);
                          context.showSnack('Fasting record override saved.');
                          setState(() {});
                        },
                        child: const Text('Save Record Override'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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

  int _getFastingMinutes(int weekday, FastingSchedule schedule) {
    final daySched = schedule.getScheduleFor(weekday);
    final start = daySched['fastHour']! * 60 + daySched['fastMin']!;
    var end = daySched['eatHour']! * 60 + daySched['eatMin']!;
    if (end < start) end += 24 * 60;
    return end - start;
  }

  int _getEatingMinutes(int weekday, FastingSchedule schedule) {
    final daySched = schedule.getScheduleFor(weekday);
    final start = daySched['eatHour']! * 60 + daySched['eatMin']!;
    var end = daySched['fastHour']! * 60 + daySched['fastMin']!;
    if (end < start) end += 24 * 60;
    return end - start;
  }
}
