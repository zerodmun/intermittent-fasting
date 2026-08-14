# Fomo IF Fasting Engine Documentation

## Overview

The Fomo IF fasting engine is a **timeline-based, session-centric service** that calculates the active fasting or eating state in real-time. Unlike calendar-based systems, it is **session-based rather than day-based**, ensuring that fasting sessions crossing midnight (e.g. overnight fasts) are handled seamlessly without resets or schedule leakage.

No manual start/stop buttons are required. The engine runs continuously, resolving current states automatically and updating scheduled notifications dynamically.

---

## Architecture

The fasting engine is built on a **Timeline-Based** architecture. Daily schedules are generated as isolated, self-contained `TimelineSession` ranges, which are then evaluated sequentially by the resolver.

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
│  • Publishes FastingState & triggers notification updates   │
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

Triggered asynchronously after the first Flutter UI frame renders via `NotificationService.instance.initBackgroundServices()` in `main.dart`.

### Reactive State Updates

State updates are fully reactive and happen instantly. There is no caching of stale schedules or records:

- **Schedule Watcher**: The engine subscribes to `fastingScheduleBox.watch(key: 'schedule')`. Any schedule edit immediately invalidates cached timelines, recalculates the active session, and refreshes the home screen and notifications.