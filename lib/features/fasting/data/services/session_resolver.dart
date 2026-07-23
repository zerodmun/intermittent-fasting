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

    // Find the candidate sessions based on chronological search order:
    // - Previous Session: The latest session scheduled to start before now.
    // - Next Session: The earliest session scheduled to start after now.
    TimelineSession? prevSession;
    TimelineSession? nextSession;

    for (final session in sessions) {
      if (session.expectedStart.isBefore(now) || session.expectedStart.isAtSameMomentAs(now)) {
        if (prevSession == null || session.expectedStart.isAfter(prevSession.expectedStart)) {
          prevSession = session;
        }
      } else {
        if (nextSession == null || session.expectedStart.isBefore(nextSession.expectedStart)) {
          nextSession = session;
        }
      }
    }

    // 1. Search Order check:
    // If the previous session is still active (ends after now and not manually completed/skipped/cancelled),
    // we continue using this session.
    if (prevSession != null) {
      final expectedStart = prevSession.expectedStart;
      final expectedEnd = prevSession.expectedEnd;

      final override = getOverrideRecord(expectedStart);
      final actualStart = override?.startTime ?? expectedStart;
      final actualEnd = (override != null && override.status == 'active')
          ? expectedEnd
          : (override?.endTime ?? expectedEnd);

      final isFastingActive = (override != null && override.status == 'active') ||
          (override == null && now.isBefore(actualEnd));

      if (isFastingActive) {
        Duration elapsed = now.difference(actualStart);
        Duration remaining = actualEnd.difference(now);
        if (elapsed.isNegative) elapsed = Duration.zero;
        if (remaining.isNegative) remaining = Duration.zero;

        final total = actualEnd.difference(actualStart);
        final progress = total.inSeconds > 0
            ? (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0)
            : 0.0;

        return FastingState(
          status: FastingStatus.fasting,
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
      } else if (override != null && override.status != 'active') {
        if (now.isBefore(actualEnd)) {
          FastingStatus status = FastingStatus.completed;
          if (override.status == 'skipped') status = FastingStatus.skipped;
          if (override.status == 'cancelled') status = FastingStatus.cancelled;

          return FastingState(
            status: status,
            elapsed: now.difference(actualStart),
            remaining: Duration.zero,
            progress: 1.0,
            schedule: schedule,
            activeWindowStart: actualStart,
            activeWindowEnd: actualEnd,
            currentPhase: FastingPhase.eating,
            nextTransition: actualEnd,
            nextPhase: FastingPhase.eating,
          );
        }
      }
    }

    // 2. Otherwise, we are in the Eating Window between sessions.
    final DateTime eatStart = prevSession?.expectedEnd ?? now;
    final DateTime eatEnd = nextSession?.expectedStart ?? now.add(const Duration(hours: 8));

    FastingStatus status = FastingStatus.eatingWindow;
    
    // Check for preparing status
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

    return FastingState(
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
  }
}
