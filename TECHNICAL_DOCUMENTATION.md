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

---

## Food Module MVP

The food module provides manual search, barcode scanning, and local persistence of nutrition logs.

### Offline-First Architecture
*   **Hive Persistence**: Food log entries are stored in a dedicated Hive box (`food_logs`) containing dates, times, barcodes, food names, calorie values, macronutrient values, and serving details.
*   **Reactive State Streams**: The UI reactive elements (like total daily calories consumed) subscribe directly to watches on the Hive boxes to update instantly when items are added or removed.

### Robust Search & Translation Logic
*   **Indonesian-English Support**: User searches in Indonesian (e.g. `nasi`) are programmatically translated to English counterpart keys (e.g. `Rice`) and prioritized.
*   **Dual-Query API Fallback**: Queries initially target Open Food Facts CGI V1 endpoints; if they fail or timeout, the service automatically falls back to search-v2 API endpoints.
*   **Relevance Scoring**: Search results are filtered to remove non-food products (e.g., shampoo) and sorted using a descending relevance score prioritizing exact matches, brand-free titles, and complete nutritional facts.

### Real-time Calorie Burn Estimator
*   Uses the Mifflin-St Jeor equation to compute BMR based on user profiles (Age, Weight, Height, Gender).
*   Estimates continuous calorie burn rate: `BMR / 1440` kcal/minute.
*   Ticks every second while fasting and resets to 0 when the fasting window ends.

### Spacing & Layout System
*   **StatCard Widget**: One reusable widget enforcing a strictly left-aligned structure:
    *   **Header**: Fixed `40dp` height row with a left-aligned icon and an optional right-aligned info button (does not collapse or reposition when empty).
    *   **Main Value**: Displayed below the header using a `FittedBox` for responsive scaling without clipping/wrapping.
    *   **Title**: Single line (no subtitle, `maxLines: 1`, `softWrap: false`, and `overflow: TextOverflow.ellipsis`).
    *   **Spacing**: 16dp outer padding, 20dp header $\rightarrow$ value spacing, and 8dp value $\rightarrow$ title spacing.
*   **Dynamic Height Alignment**: Uses `IntrinsicHeight` rows to dynamically match height configurations across same-row cards, ensuring consistent horizontal and vertical balance across differing device aspect ratios (phones, foldables, tablets).

### Barcode Scanning Flow & Navigation
*   **Nested Route Stack**: Barcode scanner camera screen (`BarcodeScannerPage` at `/food-scanner/camera`) and product details screen (`ProductResultScreen` at `/food-scanner/result`) are pushed onto the nested navigation stack under the `/food-scanner` parent route.
*   **Lifecycle Management**: The camera stream and controller are initialized in `initState`, stopped (`_controller.stop()`) immediately upon barcode detection to prevent double scan triggers/API requests, and properly disposed in `dispose`.
*   **Inline Loading & State Widgets**: To prevent a black screen preview after a barcode is successfully detected, the scanner screen dynamically renders loading, "Product Not Found", and offline error views inline, replacing the camera preview.
*   **Safe Tab Navigation**: If a user presses back at the root of a tab other than Home, the app redirects to the Home tab (index 0). Exiting the app via a double back press (within 2 seconds) is only allowed on the Home tab. Added a custom SnackBar toast `"Press back again to exit"`.