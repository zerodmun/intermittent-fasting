# Fomo IF - Intermittent Fasting & Body Composition Tracker

## Technical Documentation

### Overview
Fomo IF is an offline-first Flutter application for intermittent fasting tracking and body composition monitoring. Built with Clean Architecture, Riverpod state management, and daily scheduled local notifications.

**Key Principles:**
- **Zero external dependencies** - Works completely offline.
- **Timeline-Based Session Continuity** - Fasting state calculated from chronological `TimelineSession` ranges, ensuring midnight transitions do not reset active fasting.
- **Single timer** - One `Timer.periodic` runs for the entire app lifetime.
- **Reactive State Sync** - Immediate updates triggered by Hive database watch streams (no stale caches).
- **Timezone-Safe Transition Reminders** - Highly optimized notification system with exact daily alarms for eating and fasting windows.

---

## Architecture

### Folder Structure
```
lib/
├── core/
│   ├── constants/          # AppColors, AppSpacing, AppTypography
│   ├── extensions/         # Context, DateTime, Duration extensions
│   ├── helpers/            # StreakCalculator
│   ├── providers/          # Core Riverpod providers (with reactive watch streams)
│   ├── router/             # AppRouter (GoRouter)
│   ├── services/           # HiveService, NotificationService, FoodApiService, WidgetSyncService
│   └── theme/              # AppTheme (Material 3)
├── features/
│   ├── fasting/
│   │   ├── domain/
│   │   │   └── entities/   # FastingState, FastingStatus, FastingPhase, FastingRecord, FastingSchedule
│   │   ├── data/
│   │   │   └── services/   # FastingEngine (singleton), TimelineGenerator, SessionResolver, HistoryGenerator
│   │   └── presentation/
│   │       ├── providers/  # FastingEngineProvider, FastingStateNotifier
│   │       └── screens/    # FastingScreen
│   ├── body_composition/
│   │   ├── domain/entities/ # BodyCompResult, BodyFatCategory
│   │   ├── data/services/   # BodyCompCalculator (US Navy formula)
│   │   └── presentation/providers/
│   ├── onboarding/
│   │   ├── domain/entities/ # UserProfile, DailySchedule
│   │   └── presentation/    # OnboardingScreen, OnboardingProvider
│   ├── home/                # HomeScreen, Home widgets
│   │   └── presentation/
│   │       ├── screens/    # HomeScreen (dashboard layout)
│   │       └── widgets/    # HomeHeader, FastingProgressCard, NextAlarmCard, CaloriesCard, CompletedCard
│   ├── food/                # Replaces legacy food_scanner feature
│   │   ├── data/
│   │   │   └── models/     # FoodProduct, FoodLogEntry
│   │   └── presentation/
│   │       ├── providers/  # FoodLogsNotifier, foodLogsProvider
│   │       └── screens/    # FoodScannerScreen, BarcodeScannerScreen, ProductResultScreen
│   ├── statistics/          # StatisticsScreen (charts), nutrition details, food intake summaries
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
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
    
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

## Daily Transition Notifications

The application schedules local daily notifications exactly matching fasting and eating window start times:
1. **Fasting Started Notification**:
   - Title: `Time to Start Fasting`
   - Body: `Your fasting window has started. Stay hydrated and good luck!`
2. **Eating Window Started Notification**:
   - Title: `Time to Eat`
   - Body: `Your eating window has started. Enjoy your meal!`

These notifications are fully rescheduled dynamically whenever the user updates settings or fasting hours, and they utilize exact alarms (`SCHEDULE_EXACT_ALARM` permissions on Android) with timezone-safe scheduling.

---

## Food Feature & API Integration

The food module provides manual search, barcode scanning, and local persistence of nutrition logs.

### Layered Architecture
*   **Domain Models**: Stored in `lib/features/food/data/models/`:
    - `food_product.dart`: Open Food Facts mapped structure (`FoodProduct` and `OfflineException`).
    - `food_log_entry.dart`: Saved meal logs (`FoodLogEntry`).
*   **State Providers**: Stored in `lib/features/food/presentation/providers/`:
    - `food_logs_provider.dart`: `FoodLogsNotifier` StateNotifier handling add/update/delete.
*   **Views**: Stored in `lib/features/food/presentation/screens/`:
    - `food_scanner_screen.dart`: List of logs and search action page.
    - `barcode_scanner_screen.dart`: Controller-disposed scanner camera view.
    - `product_result_screen.dart`: Scanner details and saving prompt.

### Indonesian-English Translation Support
*   **Translation Mapping**: User searches in Indonesian (e.g. `nasi`) are programmatically translated to English counterpart keys (e.g. `Rice`) and prioritized.
*   **Dual-Query API Fallback**: Queries initially target Open Food Facts CGI V1 endpoints; if they fail or timeout, the service automatically falls back to search-v2 API endpoints.
*   **Relevance Scoring**: Search results are filtered to remove non-food products (e.g., shampoo) and sorted using a descending relevance score prioritizing exact matches, brand-free titles, and complete nutritional facts.

---

## UI Components & Dashboard Widgets

### StatCard Widget
*   **StatCard Widget**: One reusable widget enforcing a strictly left-aligned structure:
    - **Header**: Fixed `40dp` height row with a left-aligned icon and an optional right-aligned info button (does not collapse or reposition when empty).
    - **Main Value**: Displayed below the header using a `FittedBox` for responsive scaling without clipping/wrapping.
    - **Title**: Single line (no subtitle, `maxLines: 1`, `softWrap: false`, and `overflow: TextOverflow.ellipsis`).
    - **Spacing**: 16dp outer padding, 20dp header $\rightarrow$ value spacing, and 8dp value $\rightarrow$ title spacing.
*   **Dynamic Height Alignment**: Uses `IntrinsicHeight` rows to dynamically match height configurations across same-row cards, ensuring consistent horizontal and vertical balance across differing device aspect ratios (phones, foldables, tablets).

### Decomposed Home Widgets
To keep the main screen clean, the dashboard components are modularized under `lib/features/home/presentation/widgets/`:
- `home_header.dart`: Profile greeting and avatar badge.
- `fasting_progress_card.dart`: The gradient-colored fasting / eating window countdown ring.
- `next_alarm_card.dart`: Plan timetable strip.
- `calories_card.dart`: Burned Calories stat card with estimated calories dialog calculations.
- `completed_card.dart`: Total completed sessions stat card.