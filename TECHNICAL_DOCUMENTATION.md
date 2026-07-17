# Fomo IF - Intermittent Fasting & Body Composition Tracker

## Technical Documentation

### Overview
Fomo IF is an offline-first Flutter application for intermittent fasting tracking and body composition monitoring. Built with Clean Architecture and Riverpod state management.

**Key Principles:**
- **Zero external dependencies** - Works completely offline
- **Schedule-driven engine** - Fasting state calculated from current time + user schedule
- **Single timer** - One `Timer.periodic` runs for entire app lifetime
- **Immediate recalculation** - Schedule edits trigger instant UI updates

---

## Architecture

### Folder Structure
```
lib/
├── core/
│   ├── constants/          # AppColors, AppSpacing, AppTypography
│   ├── data/services/      # HiveService (database)
│   ├── extensions/         # Context, DateTime, Duration extensions
│   ├── helpers/            # StreakCalculator
│   ├── providers/          # Core Riverpod providers
│   ├── router/             # AppRouter (GoRouter)
│   ├── services/           # NotificationService
│   └── theme/              # AppTheme (Material 3)
├── features/
│   ├── fasting/
│   │   ├── domain/
│   │   │   └── entities/   # FastingState, FastingStatus, FastingPhase, FastingRecord, FastingSchedule
│   │   ├── data/
│   │   │   └── services/   # FastingEngine (singleton)
│   │   └── presentation/
│   │       ├── providers/  # FastingEngineProvider, FastingStateNotifier
│   │       └── screens/    # FastingScreen (Timer, Schedule, Timeline, Calendar)
│   ├── body_composition/
│   │   ├── domain/entities/ # BodyCompResult, BodyFatCategory
│   │   ├── data/services/   # BodyCompCalculator (US Navy formula)
│   │   └── presentation/providers/
│   ├── onboarding/
│   │   ├── domain/entities/ # UserProfile, DailySchedule
│   │   └── presentation/    # OnboardingScreen (4 steps)
│   ├── home/                # HomeScreen with fasting status card
│   ├── history/             # HistoryScreen (list + calendar)
│   ├── statistics/          # StatisticsScreen (charts)
│   ├── weight/              # WeightScreen (measurements, charts)
│   └── settings/            # SettingsScreen
└── shared/widgets/          # Reusable UI components
```

---

## Core Components

### FastingEngine (Singleton)
**File:** `lib/features/fasting/data/services/fasting_engine.dart`

```dart
class FastingEngine {
  static final FastingEngine _instance = FastingEngine._internal();
  factory FastingEngine() => _instance;
  
  Timer? _timer;
  FastingState? _currentState;
  
  void initialize() {
    _timer = Timer.periodic(Duration(seconds: 1), _onTimerTick);
    _autoGenerateHistory();
    _tick();
  }
  
  void onScheduleChanged() => _tick();
  void onRecordChanged() => _tick();
}
```

**Key Responsibilities:**
- Single `Timer.periodic` running at 1Hz
- Computes `FastingState` from `DateTime.now() + Schedule`
- Handles overnight fasting windows (e.g., 20:00 → 12:00)
- Manages manual overrides (completed/skipped/cancelled)
- Auto-generates historical records for past days

**State Computation:**
```dart
FastingState _computeState(DateTime now, FastingSchedule schedule) {
  // 1. Find active window (checks yesterday, today, tomorrow)
  // 2. Check for manual override record
  // 3. Determine phase: fasting vs eating
  // 4. Apply status overrides: preparing, completed, skipped, cancelled
  // 5. Calculate elapsed, remaining, progress, remaining, progress
  // 6. Determine next transition time
}
```

### FastingState
**File:** `lib/features/fasting/domain/entities/fasting_state.dart`

```dart
class FastingState {
  final FastingStatus status;           // preparing, fasting, eatingWindow, completed, skipped, cancelled
  final Duration elapsed;               // Time elapsed in current window
  final Duration remaining;             // Time remaining in current window
  final double progress;                // 0.0 - 1.0
  final FastingSchedule schedule;       // Current schedule
  final DateTime activeWindowStart;     // Window start time
  final DateTime activeWindowEnd;       // Window end time
  final FastingPhase currentPhase;      // fasting / eating
  final DateTime nextTransition;        // Next phase change time
  final FastingPhase nextPhase;         // Next phase
}
```

### FastingSchedule
**File:** `lib/features/fasting/domain/entities/fasting_schedule.dart`

```dart
class FastingSchedule {
  Map<int, DailySchedule> dailySchedules;  // 1=Mon ... 7=Sun
  
  DailySchedule getScheduleFor(int weekday) { ... }
  FastingSchedule copyWith({Map<int, DailySchedule>? dailySchedules}) { ... }
  
  factory FastingSchedule.defaultSchedule() {
    // 17:00 fasting → 09:00 eating (16:8)
    for (int day = 1; day <= 7; day++) {
      defaults[day] = DailySchedule(fastHour: 17, fastMin: 0, eatHour: 9, eatMin: 0);
    }
  }
}

class DailySchedule {
  int fastHour, fastMin;   // Fasting start (e.g., 20:00)
  int eatHour, eatMin;     // Eating window start (e.g., 12:00)
  
  String get fastTimeFormatted => '${fastHour.toString().padLeft(2, '0')}:${fastMin.toString().padLeft(2, '0')}';
  String get eatTimeFormatted => '${eatHour.toString().padLeft(2, '0')}:${eatMin.toString().padLeft(2, '0')}';
}
```

### Riverpod Providers
**File:** `lib/features/fasting/presentation/providers/fasting_providers.dart`

```dart
// Singleton engine
final fastingEngineProvider = Provider<FastingEngine>((ref) {
  final engine = FastingEngine();
  engine.initialize();
  ref.onDispose(() => engine.dispose());
  return engine;
});

// State notifier bridging engine to UI
final fastingStateNotifierProvider = StateNotifierProvider<FastingStateNotifier, FastingState?>((ref) {
  return FastingStateNotifier(ref);
});

class FastingStateNotifier extends StateNotifier<FastingState?> {
  FastingStateNotifier(Ref ref) : super(null) {
    state = ref.read(fastingEngineProvider).currentState;
  }
  
  void onScheduleChanged() {
    final engine = ref.read(fastingEngineProvider);
    engine.onScheduleChanged();
    state = engine.currentState;
  }
  
  void logManualAction(String status) { /* ... */ }
  void editFastingRecord({...}) { /* ... */ }
}
```

---

## UI Screens

### FastingScreen (`lib/features/fasting/screens/fasting_screen.dart`)
Four segments via `SegmentedButton`:

| Segment | Purpose |
|---------|---------|
| **Timer** | Circular progress ring, countdown, elapsed time, manual actions (Complete/Skip) |
| **Schedule** | Weekly grid with time pickers per day, "Copy Monday to All" |
| **Timeline** | Yesterday/Today/Tomorrow cards with scheduled vs actual times |
| **Calendar** | Monthly view with completion markers, detail view on tap |

**Key Features:**
- Animated progress ring (`AnimatedProgressRing`)
- Real-time countdown updates every second
- Manual override via bottom sheet (`_showManualLogSheet`)
- Copy Monday schedule to all days

### HomeScreen (`lib/features/home/screens/home_screen.dart`)
- Greeting header with user name
- Fasting status card with progress ring and next transition
- Stats grid: Streak, Today's Plan, Completed sessions
- Weight tracker card
- Recent fasts list (last 3)

### OnboardingScreen (`lib/features/onboarding/screens/onboarding_screen.dart`)
4-step flow with `PageView`:

1. **Welcome** - Feature highlights
2. **Profile** - Name, age, gender, height, current weight
3. **Goals** - Target weight, body fat %, waist, BMI
3. **Schedule** - Daily fasting/eating times with "Copy Monday to All"

---

## Body Composition

### BodyCompCalculator (`lib/features/weight/data/services/body_comp_calculator.dart`)

**US Navy Method:**
```dart
// Male: %BF = 495 / (1.0324 - 0.19077*log10(waist-neck) + 0.15456*log10(height)) - 450
// Female: %BF = 495 / (1.29579 - 0.35004*log10(waist+hip-neck) + 0.22100*log10(height)) - 450
```

**Calculations:**
| Metric | Formula |
|--------|---------|
| BMI | weight / (height/100)² |
| Body Fat % | US Navy formula |
| Lean Mass | weight × (1 - BF%) |
| Fat Mass | weight × BF% |
| BMR | Mifflin-St Jeor |
| TDEE | BMR × 1.55 (moderate activity) |

### BodyCompResult
```dart
class BodyCompResult {
  final double bodyFatPercentage;
  final double leanBodyMassKg;
  final double fatMassKg;
  final double bmi;
  final double bmr;
  final double tdee;
  final BodyFatCategory category;  // essentialFat, athlete, fitness, average, obese
  final String bodyFatCategory;
  final double bodyFatRangeMin;
  final double bodyFatRangeMax;
  final bool isInHealthyRange;
}
```

---

## Data Layer (Hive)

### Boxes
| Box | Type | Key |
|-----|------|-----|
| `user_profile` | `UserProfile` | `'profile'` |
| `fasting_schedule` | `FastingSchedule` | `'schedule'` |
| `fasting_records` | `FastingRecord` | record ID |
| `weight_entries` | `WeightEntry` | entry ID |
| `settings` | `Map` | various |
| `active_session` | `Map` | `'session'` |

### Export/Import
```dart
Future<String> exportData() async {
  // JSON with version, date, profile, records, weights
}

Future<void> importData(String jsonString) async { /* ... */ }
```

---

## Notifications

### NotificationService (`lib/core/services/notification_service.dart`)
- **Channels**: Fasting Start, Eating Window, Preparing (2hr before fast)
- **Scheduling**: `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`
- **Auto-reschedule**: Called after schedule changes

---

## Key Workflows

### Schedule Edit → Immediate Update
```dart
// User saves schedule change in UI
notifier.onScheduleChanged();  // Called in UI

// In FastingStateNotifier:
void onScheduleChanged() {
  final engine = ref.read(fastingEngineProvider);
  engine.onScheduleChanged();   // Triggers _tick()
  state = engine.currentState;  // UI rebuilds with new state
}
```

### Manual Override (Complete/Skip)
```dart
// User taps "Mark Completed"
notifier.logManualAction('completed');

// In FastingStateNotifier:
void logManualAction(String status) {
  final engine = ref.read(fastingEngineProvider);
  final active = engine.getActiveWindow(now, schedule);
  
  if (existingRecord) {
    existingRecord.status = status;
    if (status == 'completed') existingRecord.endTime = now;
  } else {
    // Create new record with actual times
  }
  HiveService.instance.saveFastingRecord(record);
  engine.onRecordChanged();  // Triggers UI update
}
```

---

## Build & Run

```bash
# Get dependencies
flutter pub get

# Run analyzer
flutter analyze

# Debug build
flutter run

# Release APK
flutter build apk --release

# Release iOS
flutter build ios --release
```

---

## Dependencies

```yaml
dependencies:
  flutter_riverpod: ^3.3.2      # State management
  go_router: ^17.2.3            # Navigation
  hive_ce: ^2.19.1              # Local database
  hive_ce_flutter: ^2.3.4       # Flutter integration
  flutter_local_notifications: ^18.0.0
  fl_chart: ^1.2.0              # Charts
  shared_preferences: ^2.5.0
  intl: ^0.20.0                 # Date formatting
  uuid: ^4.5.1                  # Unique IDs
  google_fonts: ^6.2.1          # Typography
  table_calendar: ^3.2.0        # Calendar widget
  path_provider: ^2.1.5
  timezone: ^0.10.1             # Notification scheduling
  flutter_svg: ^2.0.10-ap.1     # SVG illustrations
```

---

## Code Quality

```bash
# Static analysis
flutter analyze

# Run tests
flutter test

# Format code
dart format .

# Check for outdated packages
flutter pub outdated
```

---

## Deployment Notes

- **Minimum SDK**: Android 5.0 (API 21), iOS 11.0
- **Target SDK**: Latest stable Flutter
- **Permissions**: 
  - `POST_NOTIFICATIONS` (Android 13+)
  - `SCHEDULE_EXACT_ALARM` (Android 12+)
- **No internet permission required** - fully offline

---

## Version History

| Version | Changes |
|---------|---------|
| 1.0.0 | Initial release with Clean Architecture refactor |

---

*Generated documentation for Fomo IF v1.0.0*