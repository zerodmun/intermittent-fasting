# Fomo IF Fasting Engine Documentation

## Overview

The Fomo IF fasting engine is a **singleton service** that calculates fasting state in real-time from:
- **Current DateTime** (system clock)
- **User Daily Schedule** (single source of truth)

No manual start/stop buttons required. The engine runs continuously and automatically determines the current fasting state.

---

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    FastingEngine (Singleton)                │
├─────────────────────────────────────────────────────────────┤
│  • ONE Timer.periodic (1 second)                            │
│  • Reads current DateTime + Schedule on every tick          │
│  • Computes FastingState                                    │
│  • Notifies listeners (Riverpod)                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Riverpod Providers                       │
├─────────────────────────────────────────────────────────────┤
│  • fastingEngineProvider    → Singleton instance            │
│  • fastingStateProvider2    → NotifierProvider<FastingState?>│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
├─────────────────────────────────────────────────────────────┤
│  • HomeScreen           → Status card, progress ring        │
│  • FastingScreen        → Timer, Schedule, Timeline, Calendar│
│  • HistoryScreen        → Past records                      │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Timer Tick (1s)
     │
     ▼
DateTime.now() + Schedule.getScheduleFor(weekday)
     │
     ▼
Compute Active Window (checks yesterday/today/tomorrow)
     │
     ▼
Check Manual Override (FastingRecord for cycle date)
     │
     ▼
Calculate: Status, Elapsed, Remaining, Progress, Next Transition
     │
     ▼
Update FastingState → Notify Riverpod → UI Rebuilds
```

---

## FastingEngine API

### Initialization

```dart
final engine = FastingEngine();
engine.initialize();  // Starts timer, auto-generates history
```

Called automatically via `fastingEngineProvider` in `main.dart`.

### State Access

```dart
// Current computed state (nullable until first tick)
FastingState? state = engine.currentState;

// Reactive updates via listener
engine.addListener(() {
  final state = engine.currentState;
  // Update UI
});
```

### Schedule Changes

```dart
// Call after saving new schedule to Hive
engine.onScheduleChanged();
// Or via notifier:
ref.read(fastingStateProvider2.notifier).onScheduleChanged();
```

### Record Changes

```dart
// Call after adding/editing/deleting FastingRecord
engine.onRecordChanged();
// Or via notifier:
ref.read(fastingStateProvider2.notifier).refresh();
```

---

## FastingState

```dart
class FastingState {
  final FastingStatus status;           // Current status enum
  final Duration elapsed;               // Time elapsed in current window
  final Duration remaining;             // Time remaining in current window
  final double progress;                // 0.0 - 1.0 progress
  final FastingSchedule schedule;       // Current schedule
  final DateTime activeWindowStart;     // Window start time
  final DateTime activeWindowEnd;       // Window end time
  final FastingPhase currentPhase;      // fasting | eating
  final DateTime nextTransition;        // Next phase change time
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

### FastingPhase Enum

| Value | Description |
|-------|-------------|
| `fasting` | Fasting phase |
| `eating` | Eating phase |

---

## Riverpod Usage

### Watching State

```dart
// In a ConsumerWidget
final state = ref.watch(fastingStateProvider2);

// Or using the stream provider (alternative)
final state = ref.watch(fastingStateProvider);
```

### Manual Actions

```dart
final notifier = ref.read(fastingStateProvider2.notifier);

// Mark completed/skipped/cancelled
notifier.logManualAction('completed');
notifier.logManualAction('skipped');
notifier.logManualAction('cancelled');

// Edit existing record
notifier.editFastingRecord(
  id: record.id,
  startTime: newStart,
  endTime: newEnd,
  status: 'completed',
  note: 'Felt great!',
  reason: 'Early dinner',
);

// Save schedule changes (called from Schedule screen)
notifier.saveSchedule(newSchedule);
```

---

## Schedule Model

### FastingSchedule

```dart
class FastingSchedule {
  // Key: 1=Monday ... 7=Sunday
  // Value: {fastHour, fastMin, eatHour, eatMin}
  Map<int, Map<String, int>> dailySchedules;
  
  Map<String, int> getScheduleFor(int weekday);
  
  FastingSchedule copyWith({Map<int, Map<String, int>>? dailySchedules});
  
  static FastingSchedule defaultSchedule(); // 17:00 - 09:00 daily
}
```

### Example: 16:8 Schedule

```dart
final schedule = FastingSchedule(dailySchedules: {
  1: {'fastHour': 20, 'fastMin': 0, 'eatHour': 12, 'eatMin': 0},  // Mon
  2: {'fastHour': 20, 'fastMin': 0, 'eatHour': 12, 'eatMin': 0},  // Tue
  // ... etc
});
```

### Copy Monday to All

```dart
final monday = schedule.getScheduleFor(1);
final updatedMap = Map<int, Map<String, int>>.from(schedule.dailySchedules);
for (int i = 2; i <= 7; i++) {
  updatedMap[i] = Map<String, int>.from(monday);
}
final updatedSchedule = schedule.copyWith(dailySchedules: updatedMap);
```

---

## Active Window Calculation

The engine checks **3 days** (yesterday, today, tomorrow) to find the active window:

```
For each candidate day:
  1. Get schedule for weekday
  2. Create eatingTime and fastingTime DateTimes
  3. If eating < fasting (overnight fast):
       Eating window: eatingTime → fastingTime
       Fasting window: fastingTime → eatingTime + 1 day
     Else (same-day fast):
       Fasting window: fastingTime → eatingTime
       Eating window: eatingTime → fastingTime + 1 day
  4. Check if now is within either window
```

### Cycle Start Date

Each fasting cycle has a `cycleStartDate` (date-only) used for:
- Finding manual overrides (`FastingRecord` for that date)
- Calculating next transition
- History grouping

---

## Manual Overrides

### FastingRecord

```dart
class FastingRecord {
  String id;
  String planName;
  int fastingMinutes;
  int eatingMinutes;
  DateTime startTime;
  DateTime? endTime;
  String status;  // 'active', 'completed', 'cancelled', 'skipped'
  String? note;
  String? reason;
}
```

### Override Logic

When a record exists for the cycle date:
- **Actual start/end** = record's startTime/endTime (not schedule)
- **Phase** = determined by current time vs actual times
- **Status** = record's status (completed/skipped/cancelled)

---

## History Generation

Auto-generates completed records for past days (up to yesterday):

```dart
// Runs once on first launch, then daily
while (loopDate < today) {
  if (no record exists for loopDate) {
    create record with:
      - startTime = schedule fasting time
      - endTime = startTime + fasting minutes
      - status = 'completed'
  }
  loopDate += 1 day;
}
```

Triggered via `last_history_gen_date` setting.

---

## UI Integration Examples

### Home Screen Status Card

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(fastingStateProvider2);
  
  if (state == null) return CircularProgressIndicator();
  
  final isFasting = state.currentPhase == FastingPhase.fasting;
  final gradient = isFasting ? AppColors.fastingGradient : AppColors.eatingGradient;
  
  String title = 'Fasting Active';
  if (state.status == FastingStatus.eatingWindow) title = 'Eating Window';
  if (state.status == FastingStatus.preparing) title = 'Preparing to Fast';
  if (state.status == FastingStatus.completed) title = 'Fasting Completed';
  
  return GradientCard(
    gradient: gradient,
    child: Row(
      children: [
        Expanded(child: Column(...)),
        AnimatedProgressRing(
          progress: state.progress,
          child: Text(state.remaining.toHHMM), // Uses duration extension
        ),
      ],
    ),
  );
}
```

### Timer Screen

```dart
final state = ref.watch(fastingStateProvider2);
final notifier = ref.read(fastingStateProvider2.notifier);

@override
Widget build(BuildContext context) {
  final state = ref.watch(fastingStateProvider2);
  
  if (state == null) return Center(child: CircularProgressIndicator());
  
  Color ringColor;
  switch (state.status) {
    case FastingStatus.fasting: ringColor = AppColors.fastingActive; break;
    case FastingStatus.eatingWindow: ringColor = AppColors.eatingActive; break;
    case FastingStatus.preparing: ringColor = AppColors.amber400; break;
    case FastingStatus.completed: ringColor = AppColors.success; break;
    case FastingStatus.skipped: ringColor = Colors.grey; break;
    default: ringColor = Theme.of(context).colorScheme.primary;
  }
  
  return AnimatedProgressRing(
    progress: state.progress,
    size: 260,
    color: ringColor,
    child: Text(state.remaining.toHHMMSS),
  );
}
```

### Schedule Editing

```dart
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
```

---

## Key Behaviors

| Scenario | Behavior |
|----------|----------|
| App launch | Timer starts, computes initial state |
| Hot reload | Timer persists (singleton), state preserved |
| Navigate away/back | Timer continues running |
| Edit today's schedule | `onScheduleChanged()` → immediate recalc |
| Manual override | `logManualAction()` → state updates next tick |
| Past date edit | Only affects history, not current state |
| Midnight crossover | Handles overnight windows correctly |
| Timezone change | Uses `DateTime.now()` (system time) |

---

## Testing

```dart
// Mock engine for widget tests
final mockEngine = MockFastingEngine();
when(mockEngine.currentState).thenReturn(testState);

await tester.pumpWidget(
  ProviderScope(
    overrides: [
      fastingEngineProvider.overrideWithValue(mockEngine),
    ],
    child: MyApp(),
  ),
);
```

---

## Migration Notes

### Removed
- `FastingTimerProvider` (old NotifierProvider)
- `FastingTimerState` class
- `FastingTimerNotifier` class
- `formattedShort`, `formattedTime`, `formattedDateTime` extensions

### Added
- `FastingEngine` singleton service
- `FastingState`, `FastingStatus`, `FastingPhase` enums
- `fastingStateProvider2` (NotifierProvider)
- All DateTime formatting uses `intl.DateFormat` directly

---

## File Structure

```
lib/features/fasting/
├── models/
│   ├── fasting_schedule.dart
│   ├── fasting_record.dart
│   └── fasting_state.dart (removed - types in engine)
├── providers/
│   └── fasting_provider.dart
├── screens/
│   └── fasting_screen.dart
└── services/
    └── fasting_engine.dart  ← NEW: Core engine
```

---

## Performance

- **Single timer** for entire app lifetime
- **Minimal allocations** per tick (reuses objects where possible)
- **Distinct check** in stream provider prevents unnecessary rebuilds
- **Lazy initialization** - timer starts only when provider first read
- **Proper disposal** - timer cancelled when provider disposed