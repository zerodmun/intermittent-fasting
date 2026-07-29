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
│   ├── statistics/          # StatisticsScreen, AverageFastDetailScreen, ExerciseScreen (placeholder), WeeklyDetailScreen, MonthlyCalendarScreen, NutritionDetailsScreen
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

## Daily Transition & Scheduled Reminder Notifications

The application manages two categories of local notifications using exact alarms (`SCHEDULE_EXACT_ALARM` on Android) and timezone-safe scheduling (`tz.TZDateTime`):

### 1. Transition Notifications (IDs 1000+)
*   **Fasting Started**: `Time to Fast` - "Your fasting window starts now."
*   **Eating Window Started**: `Time to Eat` - "Congratulations! Your fasting session is complete."

### 2. Scheduled Reminder Notifications (IDs 2000–2003)
*   **10 Minutes Before Fasting Start** (ID 2000): `Fasting Starts Soon` - "Your fasting will begin in 10 minutes."
*   **At Fasting Start** (ID 2001): `Fasting Started` - "Your fasting has officially begun."
*   **10 Minutes Before Iftar** (ID 2002): `Iftar is Almost Here` - "Only 10 minutes remaining until it's time to break your fast."
*   **At Iftar Time** (ID 2003): `It's Time to Break Your Fast` - "May your fasting be accepted. Enjoy your meal."

### Offline-First, Reliable, Self-Healing Notification Scheduler Architecture
The local notification engine ([`NotificationService`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/core/services/notification_service.dart)) follows an **offline-first, battery-efficient, deterministic, self-healing architecture**:

1. **Write-Only AlarmManager Execution Target**: `AlarmManager` is an execution target, not a queryable state provider. State validation and integrity checking rely strictly on Database (Primary Source of Truth) $\rightarrow$ Expected Reminder Schedule $\rightarrow$ Optimization Cache (`_currentlyScheduledReminders`).
2. **Zero Battery Overhead**: No `Timer.periodic()`, polling loops, infinite loops, or background clock monitoring. CPU returns to idle immediately after native alarm registration (`AndroidScheduleMode.exactAllowWhileIdle`).
3. **10-Step Deterministic Lifecycle**:
   * Schedule Validation (`fastStart < fastEnd`)
   * Midnight Rollover Reset (`_resetDeliveredIfNewDay()`)
   * Target Reminder Generation (IDs `2000`–`2003`)
   * Integrity Check & Idempotency Evaluation
   * Differential Rescheduling (cancelling ONLY obsolete alarms)
   * Independent Execution (isolated `try-catch` per reminder)
   * Immediate Cache Synchronization
   * Structured Diagnostic Summary Logging
4. **Dedicated Sound Channels**: Channel ID sound preference mapping (`fasting_reminders`, `fasting_reminders_app`, `fasting_reminders_silent`).
5. **Boot & Package Recovery**: Declared `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` in `AndroidManifest.xml` for `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED` intents.
6. **Modular On-Demand Diagnostics**: Exposes `NotificationService.instance.getDiagnostics()` snapshot inspector executing strictly on-demand.

### Notification & Widget Settings Architecture
All notification configuration options and widget sync preferences are modularized into dedicated top-level sections on [`SettingsScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/settings/presentation/screens/settings_screen.dart):
1. **Notification Section**: Section header `Notification` with single card `Notification Settings` leading to [`NotificationSettingsScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/settings/presentation/screens/notification_settings_screen.dart) (`/settings/notifications`). Manages master switch (`notifications_enabled`), system permission status checker, fasting reminders, sound picker sheet, vibration, and window transition alerts.
2. **Widgets & Persistent Notification Section**: Section header `Widgets & Persistent Notification` with single card `Widgets & Persistent Notification` leading to [`WidgetsNotificationSettingsScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/settings/presentation/screens/widgets_notification_settings_screen.dart) (`/settings/widgets-notification`). Manages home screen widgets (`widgetEnabled`, `progressRingEnabled`, `bodyFatEnabled`, `weightEnabled`) and persistent drawer notifications (`notificationEnabled`, `liveCountdownEnabled`).

### Standalone Exercises Module (Workout Journal)
The **Exercises Module** ([`ExerciseScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/statistics/presentation/screens/exercise_screen.dart)) operates as a completely decoupled, standalone workout journal. It does **not** modify or integrate with fasting timers, fasting streaks, TDEE, consumed calories, weight goals, or notification scheduling.

* **Domain Entities**:
  * `WorkoutLog` ([`workout_log.dart`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/statistics/domain/entities/workout_log.dart)): Encapsulates workout ID, title, date, duration, exercise list (`ExerciseItem`), and notes.
  * `ExerciseItem`: Exercise name, sets, reps, weight ($\text{kg}$), and notes.
* **Calorie Calculation Methodology**:
  * ACSM / Compendium MET formula: $\text{Calories} = \text{MET} \times \text{BodyWeight (kg)} \times \text{Duration (hours)}$.
  * Refined MET estimation based on resistance volume ($\text{totalVolumeKg}$) and sets density per minute.
  * Explicitly displays an **Estimated Calculation Accuracy** badge ($\approx 70\%$) and explanatory notes without claiming scientific precision.
* **Workout Statistics Header & Card Sync**: Cumulative stats for Total Workouts, Total Exercises, Total Sets, Total Volume ($\text{kg}$), Total Duration ($\text{min}$), and Total Estimated Calories Burned ($\text{kcal}$). Stored workout duration stays 100% synchronized across the Exercises header and main Statistics dashboard cards.
* **Unified UI Action Pattern**: Replaced duplicate Floating Action Buttons across data-entry screens ([`ExerciseScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/statistics/presentation/screens/exercise_screen.dart), [`FoodIntakeSummaryScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/statistics/presentation/screens/food_intake_summary_screen.dart), and [`BodyCompScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/body_composition/presentation/screens/body_comp_screen.dart)) with clean, top-right AppBar action text buttons with icons (`+ Workout`, `+ Food`, `+ Record`).

---

## Food Feature & API Integration

The food module provides manual search, barcode scanning, local persistence of nutrition logs, and an intelligent **Scan Real Food (AI)** vision scanner.

### Layered Architecture
*   **Domain & Data Models**: Stored in `lib/features/food/data/models/`:
    - `food_product.dart`: Open Food Facts mapped structure (`FoodProduct` and `OfflineException`).
    - `food_log_entry.dart`: Saved meal logs (`FoodLogEntry`).
    - `food_recognition_model.dart`: Structured nutritional result returned from the Gemini AI endpoint (`name`, `estimatedWeightG`, `calories`, `protein`, `fat`, `carbs`, `confidence`).
*   **State Providers**: Stored in `lib/features/food/presentation/providers/`:
    - `food_logs_provider.dart`: `FoodLogsNotifier` StateNotifier handling add/update/delete.
    - `food_recognition_provider.dart`: `FoodRecognitionNotifier` handling loading, result, and error states of Gemini recognition.
*   **Views**: Stored in `lib/features/food/presentation/screens/`:
    - `food_scanner_screen.dart`: List of logs, search action page, and launch camera controls.
    - `barcode_scanner_screen.dart`: Controller-disposed scanner camera view.
    - `product_result_screen.dart`: Scanner details and saving prompt.
    - `ai_camera_preview_screen.dart`: Preview Screen displaying captured food, managing retake cameras, presenting validation alerts, and displaying loading and detailed error dialogs.
    - `ai_food_result_screen.dart`: AI scanner details, macronutrient progress indicators, and "Add to Diary" + "Analyze Another Photo" controls.

### Gemini AI API & Resilient Scanner Strategy
*   **Gemini Model**: Integrates the latest vision-capable `gemini-3.5-flash` model.
*   **Centralized AI Exception System**: Defines `AIException` with mapped categories: `quotaExceeded` (429), `networkError` (SocketExceptions), `timeout` (408/TimeoutExceptions), `invalidApiKey` (401/403), `imageTooLarge` (>10 MB), `invalidResponse`, `serverError` (500/503), and `unknown`.
*   **Automatic Retry strategy**: If a transient network error, timeout, or server error (500/503/408) is encountered, the service automatically retries the operation once after a 1-second delay. Non-transient errors (400, 401, 403, 404, 429) skip retries.
*   **Connection Timeout Guard**: Imposes a 30-second execution limit on network requests to prevent infinite loading freezes.
*   **Pre-Flight Image Validation**: UI validates file existence, checks readability, and restricts file sizes to under 10 MB before hitting the API.
*   **Client-Side In-Memory Cache**: Centralized cache map inside `GeminiService` prevents redundant API calls if the same image path is submitted for analysis multiple times.
*   **Safe Route Transitions**: Camera picker callbacks defer GoRouter page transitions until the next Flutter layout frame via `WidgetsBinding.instance.addPostFrameCallback`, eliminating race crashes.

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