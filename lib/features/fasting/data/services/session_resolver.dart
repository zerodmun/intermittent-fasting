import 'package:fast_flow/core/services/logger_service.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_record.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_schedule.dart';
import 'package:fast_flow/features/fasting/domain/entities/fasting_state.dart';
import 'timeline_generator.dart';

class SessionResolver {
  static FastingState resolveState({
    required DateTime now,
    required List<TimelineSession> sessions,
    required FastingRecord? Function(DateTime expectedStart) getOverrideRecord,
    required FastingSchedule schedule,
  }) {
    if (sessions.isEmpty) {
      final today = DateTime(now.year, now.month, now.day);
      return FastingState(
        status: FastingStatus.eatingWindow,
        elapsed: Duration.zero,
        remaining: Duration.zero,
        progress: 0.0,
        schedule: schedule,
        activeWindowStart: today,
        activeWindowEnd: today.add(const Duration(hours: 8)),
        currentPhase: FastingPhase.eating,
        nextTransition: today.add(const Duration(hours: 8)),
        nextPhase: FastingPhase.fasting,
      );
    }

    // 1. Check if `now` falls inside a scheduled Fasting Session [expectedStart, expectedEnd)
    TimelineSession? activeFastingSession;
    for (final session in sessions) {
      if ((session.expectedStart.isBefore(now) || session.expectedStart.isAtSameMomentAs(now)) &&
          now.isBefore(session.expectedEnd)) {
        activeFastingSession = session;
        break;
      }
    }

    if (activeFastingSession != null) {
      final expectedStart = activeFastingSession.expectedStart;
      final expectedEnd = activeFastingSession.expectedEnd;
      final override = getOverrideRecord(expectedStart);

      final actualStart = override?.startTime ?? expectedStart;
      final actualEnd = expectedEnd; // Target end of fasting window

      Duration elapsed = now.difference(actualStart);
      Duration remaining = actualEnd.difference(now);
      if (elapsed.isNegative) elapsed = Duration.zero;
      if (remaining.isNegative) remaining = Duration.zero;

      final total = actualEnd.difference(actualStart);
      final progress = total.inSeconds > 0
          ? (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0)
          : 0.0;

      FastingStatus status = FastingStatus.fasting;
      if (override != null) {
        if (override.status == 'completed') status = FastingStatus.completed;
        if (override.status == 'skipped') status = FastingStatus.skipped;
        if (override.status == 'cancelled') status = FastingStatus.cancelled;
        if (override.status == 'active') status = FastingStatus.fasting;
      }

      final state = FastingState(
        status: status,
        elapsed: elapsed,
        remaining: remaining,
        progress: progress,
        schedule: schedule,
        activeWindowStart: actualStart,
        activeWindowEnd: actualEnd,
        currentPhase: FastingPhase.fasting,
        nextTransition: actualEnd,
        nextPhase: FastingPhase.eating,
      );

      LoggerService.d(
        '[WINDOW-DIAG]\n'
        'now: $now\n'
        'currentPhase: ${state.currentPhase}\n'
        'status: ${state.status}\n'
        'activeWindowStart: ${state.activeWindowStart}\n'
        'activeWindowEnd: ${state.activeWindowEnd}\n'
        'remaining: ${state.remaining}\n'
        'nextTransition: ${state.nextTransition}\n'
        'nextPhase: ${state.nextPhase}'
      );

      return state;
    }

    // 2. Otherwise, `now` is in the EATING WINDOW between scheduled fasting sessions
    TimelineSession? prevSession;
    TimelineSession? nextSession;

    for (final session in sessions) {
      if (session.expectedEnd.isBefore(now) || session.expectedEnd.isAtSameMomentAs(now)) {
        if (prevSession == null || session.expectedEnd.isAfter(prevSession.expectedEnd)) {
          prevSession = session;
        }
      }
      if (session.expectedStart.isAfter(now)) {
        if (nextSession == null || session.expectedStart.isBefore(nextSession.expectedStart)) {
          nextSession = session;
        }
      }
    }

    final DateTime eatStart = prevSession?.expectedEnd ?? now;
    final DateTime eatEnd = nextSession?.expectedStart ?? now.add(const Duration(hours: 8));

    FastingStatus status = FastingStatus.eatingWindow;

    // Check for preparing status (within 2 hours before fasting starts)
    final diff = eatEnd.difference(now);
    if (diff.inMinutes > 0 && diff.inMinutes <= 120) {
      status = FastingStatus.preparing;
    }

    Duration elapsed = now.difference(eatStart);
    Duration remaining = eatEnd.difference(now);
    if (elapsed.isNegative) elapsed = Duration.zero;
    if (remaining.isNegative) remaining = Duration.zero;

    final total = eatEnd.difference(eatStart);
    final progress = total.inSeconds > 0
        ? (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    final state = FastingState(
      status: status,
      elapsed: elapsed,
      remaining: remaining,
      progress: progress,
      schedule: schedule,
      activeWindowStart: eatStart,
      activeWindowEnd: eatEnd,
      currentPhase: FastingPhase.eating,
      nextTransition: eatEnd,
      nextPhase: FastingPhase.fasting,
    );

    LoggerService.d(
      '[WINDOW-DIAG]\n'
      'now: $now\n'
      'currentPhase: ${state.currentPhase}\n'
      'status: ${state.status}\n'
      'activeWindowStart: ${state.activeWindowStart}\n'
      'activeWindowEnd: ${state.activeWindowEnd}\n'
      'remaining: ${state.remaining}\n'
      'nextTransition: ${state.nextTransition}\n'
      'nextPhase: ${state.nextPhase}'
    );

    return state;
  }
}
