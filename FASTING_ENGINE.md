# Fomo IF Fasting Engine Documentation

## Overview

The Fomo IF fasting engine is a **timeline-based, session-centric service** that calculates the active fasting or eating state in real-time. Unlike calendar-based systems, it is **session-based rather than day-based**, ensuring that fasting sessions crossing midnight (e.g. overnight fasts) are handled seamlessly without resets or schedule leakage.

No manual start/stop buttons are required. The engine runs continuously, resolving current states automatically and updating native widgets and notifications dynamically.

---

## Architecture

The fasting engine has been completely refactored to a **Timeline-Based** architecture. Daily schedules are generated as isolated, self-contained `TimelineSession` ranges, which are then evaluated sequentially by the resolver.

```
┌─────────────────────────────────────────────────────────────┐
│                    Weekly Fasting Schedule                  │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│             TimelineGenerator (Rolling 21-day Window)       │
├─────────────────────────────────────────────────────────────┤
│  • Maps daily weekday schedules to absolute DateTime ranges │
│  • Generates chronological list of isolated TimelineSessions │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│             SessionResolver (Sequential Engine)            │
├─────────────────────────────────────────────────────────────┤
│  • Resolves current state by evaluating sessions list       │
│  • Search Order: 1. Prev Session, 2. Current Window, 3. Next │
│  • Computes: elapsed, remaining, progress, next transition  │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              FastingEngine (1Hz Timer Singleton)            │
├─────────────────────────────────────────────────────────────┤
│  • Caches rolling timeline, ticking once per second         │
│  • Subscribes to Hive watch streams for reactive updates    │
│  • Publishes FastingState & syncs to native widget systems  │
└─────────────────────────────────────────────────────────────┘
```

### Core Services

1. **Timeline Generator** (`timeline_generator.dart`)
   - Generates a chronologically sorted list of `TimelineSession` ranges.
   - **Schedule Isolation**: A session's start and end times are determined solely by the day the fast starts. Changing Saturday's schedule will never affect an active Friday session.

2. **Session Resolver** (`session_resolver.dart`)
   - Sequentially analyzes the `TimelineSession` list relative to `DateTime.now()` and any manual Hive log overrides.
   - **Chronological Search Order**:
     1. **Previous Session**: If the most recent session is active (started before now, and ends after now, with no manual completed/skipped/cancelled override), it continues using that session. Changing calendar days never interrupts active fasts.
     2. **Eating Window**: If the previous session is ended, it resolves to the eating window leading to the start of the next session.
     3. **Next Session**: Determines transition states.

3. **History Generator** (`history_generator.dart`)
   - Scans the timeline of the past 7 days and automatically generates completed historical records for finished fasting sessions that do not already have manual override records in Hive.

---

## FastingEngine API

### Initialization

```dart
final engine = FastingEngine();
engine.initialize();  // Subscribes to Hive watch streams, starts 1Hz timer, auto-generates history
```

Called automatically via `fastingEngineProvider` in `main.dart`.

### Reactive State Updates

State updates are fully reactive and happen instantly. There is no caching of stale schedules or records:

- **Schedule Watcher**: The engine subscribes to `fastingScheduleBox.watch(key: 'schedule')`. Any schedule edit immediately invalidates cached timelines, recalculates the active session, and refreshes the home screen, notification, and widgets.
- **Records Watcher**: The engine subscribes to `fastingRecordsBox.watch()`. Manual logs (adds, edits, skips, deletes) trigger instant updates.

---

## TimelineSession Model

```dart
class TimelineSession {
  final DateTime expectedStart; // Scheduled start datetime
  final DateTime expectedEnd;   // Scheduled end datetime (offset by 1 day if crossing midnight)
  final int weekday;            // Weekday index (1-7) of the starting day
}
```

## FastingState Model

```dart
class FastingState {
  final FastingStatus status;           // Current status enum (fasting, eatingWindow, preparing, etc.)
  final Duration elapsed;               // Time elapsed in current window
  final Duration remaining;             // Time remaining in current window (directly targeted from endDateTime)
  final double progress;                // 0.0 - 1.0 progress fraction
  final FastingSchedule schedule;       // Current schedule
  final DateTime activeWindowStart;     // Window start time
  final DateTime activeWindowEnd;       // Window end time (Countdown target)
  final FastingPhase currentPhase;      // fasting | eating
  final DateTime nextTransition;        // Next transition time
  final FastingPhase nextPhase;         // Next phase
}
```

### FastingStatus Enum

| Value | Description |
|-------|-------------|
| `fasting` | Currently in fasting window |
| `eatingWindow` | Currently in eating window |
| `preparing` | Fasting starts within 2 hours |
| `completed` | Manual override: completed |
| `skipped` | Manual override: skipped |
| `cancelled` | Manual override: cancelled |

---

## UI Integration

### Visual Separation & Decoupling
To enforce that the weekly schedule is never used as the direct source of truth for UI, all active schedule displays must read properties from `activeWindowStart.weekday` instead of `DateTime.now().weekday`.

```dart
// Display targets for the active plan card
final activeWeekday = state.activeWindowStart.weekday;
final activePlan = state.schedule.getScheduleFor(activeWeekday);

print('Active plan starts at: ${activePlan.fastTimeFormatted}');
print('Active plan ends at: ${activePlan.eatTimeFormatted}');
```