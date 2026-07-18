# Fomo IF - Intermittent Fasting & Body Composition Tracker

## Technical Documentation

### Overview
Fomo IF is an offline-first Flutter application for intermittent fasting tracking and body composition monitoring. Built with Clean Architecture, Riverpod state management, and an event-driven Android native background foreground service.

**Key Principles:**
- **Zero external dependencies** - Works completely offline.
- **Timeline-Based Session Continuity** - Fasting state calculated from chronological `TimelineSession` ranges, ensuring midnight transitions do not reset active fasting.
- **Single timer** - One `Timer.periodic` runs for entire app lifetime.
- **Reactive State Sync** - Immediate updates triggered by Hive database watch streams (no stale caches).
- **Minimalist, M3 Notifications** - Highly optimized native custom notifications with live stopwatch countdowns and quick action deep links.

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
│   ├── providers/          # Core Riverpod providers (with reactive watch streams)
│   ├── router/             # AppRouter (GoRouter)
│   ├── services/           # NotificationService
│   └── theme/              # AppTheme (Material 3)
├── features/
│   ├── fasting/
│   │   ├── domain/
│   │   │   └── entities/   # FastingState, FastingStatus, FastingPhase, FastingRecord, FastingSchedule
│   │   ├── data/
│   │   │   └── services/   # FastingEngine (singleton), TimelineGenerator, SessionResolver, HistoryGenerator
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
│   ├── home/                # HomeScreen with fasting status card (Active Plan focused)
│   ├── food_scanner/        # FoodScannerScreen (barcodes, history placeholders)
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
  List<TimelineSession> _cachedTimeline = [];
  
  void initialize() {
    _timer = Timer.periodic(Duration(seconds: 1), _onTimerTick);
    
    // Subscribe to Hive Box Watch streams for reactive synchronization
    HiveService.instance.fastingScheduleBox.watch(key: 'schedule').listen((_) => _invalidateCache());
    HiveService.instance.fastingRecordsBox.watch().listen((_) => _invalidateCache());
    
    _tick();
  }
}
```

### TimelineSession
**File:** `lib/features/fasting/data/services/timeline_generator.dart`
Represents an isolated, scheduled fasting range starting on a specific weekday. Start and end targets are calculated purely from that weekday's schedule, ensuring that modifying subsequent days has no impact on active sessions.

```dart
class TimelineSession {
  final DateTime expectedStart;
  final DateTime expectedEnd;
  final int weekday;
}
```

### SessionResolver
**File:** `lib/features/fasting/data/services/session_resolver.dart`
Resolves active and transition states chronologically using a strict search order:
1. **Previous Session**: If the most recently started fasting session is still active (ends after the current time and has no manual skip/completed override), the engine continues using it.
2. **Current Eating Window**: Evaluates the eating duration leading up to the next scheduled fasting session.
3. **Next Session**: Determines transition states.

---

## Native Notifications

The application uses an Android foreground service (`FastingForegroundService.kt`) with RemoteViews and custom XML layouts.

### Temporary Minimal Test Layout (`notification_expanded.xml`)
For debugging and isolating RemoteViews compatibility issues, the expanded layout is temporarily replaced with a barebones structure containing only:
- **Application Label**: Plain text displaying `"Fomo IF"`.
- **Status Indicator**: Simple text display representing the current fasting phase (e.g. `FASTING`).
- **Timer Display**: Simple TextView showing the remaining duration (`04:20:00`).
- **Progress Indicator**: A standard horizontal `ProgressBar` utilizing the platform-concrete style `@android:style/Widget.ProgressBar.Horizontal`.

All custom background colors, padding overrides, custom fonts, vector drawables, elevation settings, and action button deep links have been temporarily removed to achieve a clean baseline for isolation testing.