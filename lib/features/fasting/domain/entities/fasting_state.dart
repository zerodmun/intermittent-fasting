import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';

enum FastingPhase {
  fasting,
  eating,
}

enum FastingStatus {
  fasting,
  eatingWindow,
  preparing,
  completed,
  skipped,
  cancelled,
}

class FastingState {
  final FastingStatus status;
  final Duration elapsed;
  final Duration remaining;
  final double progress;
  final FastingSchedule schedule;
  final DateTime activeWindowStart;
  final DateTime activeWindowEnd;
  final FastingPhase currentPhase;
  final DateTime nextTransition;
  final FastingPhase nextPhase;

  FastingState({
    required this.status,
    required this.elapsed,
    required this.remaining,
    required this.progress,
    required this.schedule,
    required this.activeWindowStart,
    required this.activeWindowEnd,
    required this.currentPhase,
    required this.nextTransition,
    required this.nextPhase,
  });

  FastingState copyWith({
    FastingStatus? status,
    Duration? elapsed,
    Duration? remaining,
    double? progress,
    FastingSchedule? schedule,
    DateTime? activeWindowStart,
    DateTime? activeWindowEnd,
    FastingPhase? currentPhase,
    DateTime? nextTransition,
    FastingPhase? nextPhase,
  }) {
    return FastingState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      remaining: remaining ?? this.remaining,
      progress: progress ?? this.progress,
      schedule: schedule ?? this.schedule,
      activeWindowStart: activeWindowStart ?? this.activeWindowStart,
      activeWindowEnd: activeWindowEnd ?? this.activeWindowEnd,
      currentPhase: currentPhase ?? this.currentPhase,
      nextTransition: nextTransition ?? this.nextTransition,
      nextPhase: nextPhase ?? this.nextPhase,
    );
  }
}