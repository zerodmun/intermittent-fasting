# Fomo IF - Intermittent Fasting & Body Composition Tracker

## Technical Documentation

### Overview
Fomo IF is an offline-first Flutter application for intermittent fasting tracking and body composition monitoring. Built with Clean Architecture, Riverpod state management, and daily scheduled local notifications.

**Key Principles:**
- **Zero external dependencies** - Core fasting & tracking logic works completely offline.
- **Timeline-Based Session Continuity** - Fasting state calculated from chronological `TimelineSession` ranges, ensuring midnight transitions do not reset active fasting.
- **Single timer** - One `Timer.periodic` runs for the entire app lifetime.
- **Reactive State Sync** - Immediate updates triggered by Hive database watch streams (no stale caches).
- **Timezone-Safe Transition Reminders** - Highly optimized notification system with exact daily alarms for eating and fasting windows.
- **Instant High-Performance Startup** - Non-blocking startup architecture rendering the main UI in <0.85s.

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
│   ├── services/           # HiveService, NotificationService, FcmService, NotificationSyncService, StartupDiag, LoggerService
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
│   ├── statistics/          # StatisticsScreen, AverageFastDetailScreen, ExerciseScreen, WeeklyDetailScreen, MonthlyCalendarScreen, NutritionDetailsScreen
│   ├── weight/              # WeightScreen (measurements, charts)
│   └── settings/            # SettingsScreen, NotificationSettingsScreen
└── shared/widgets/          # Reusable UI components
```

---

## Core Components

### Startup Architecture & Non-Blocking Initialization
To maximize application responsiveness, startup is split into two distinct phases:

1. **Synchronous Critical Path (Pre-`runApp()`)**:
   - `WidgetsFlutterBinding.ensureInitialized()`
   - `Firebase.initializeApp()`
   - `dotenv.load()` & `GoogleFonts.config.allowRuntimeFetching = false`
   - `HiveService.instance.init()` (local database)
   - `NotificationService.instance.initLocal()` (plugin & production channel registration)
   - `SharedPreferences.getInstance()`
   - **`runApp()` is called immediately!** (First Flutter Frame renders in **< 850ms**, down from 7.37s).

2. **Asynchronous Background Services (Post-Frame)**:
   Triggered asynchronously via `addPostFrameCallback` after the main screen UI renders:
   - `FastingEngine().initialize()`
   - `FcmService.instance.init()` (FCM token retrieval & device registration)
   - `NotificationSyncService.instance.synchronizeOnStartup()` (Firestore schedule version check)
   - `scheduleReminderNotifications('Application Startup')`

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

## Notification & Device Registration Architecture

### Scheduled Reminder Notifications & Production Channels
The application manages local notifications using exact alarms (`SCHEDULE_EXACT_ALARM` on Android) and timezone-safe scheduling (`tz.TZDateTime`):

*   **10 Minutes Before Fasting Start** (ID 2000): `fasting_reminders` channel (System Default Sound)
*   **At Fasting Start** (ID 2001): `fasting_reminders_fast_v2` channel (`fast.mp3` raw resource, `AudioAttributesUsage.notification`)
*   **10 Minutes Before Iftar** (ID 2002): `fasting_reminders` channel (System Default Sound)
*   **At Iftar Time** (ID 2003): `fasting_reminders_eat_v2` channel (`eat.mp3` raw resource, `AudioAttributesUsage.notification`)
*   **Silent Preferences**: `fasting_reminders_silent` channel (`playSound: false`)

### Device ID Resolution & FCM Deduplication Pipeline
1. **Stable Device ID Resolution Chain**:
   `fcm_device_id` (SharedPreferences) $\rightarrow$ legacy `device_id` (Hive) $\rightarrow$ generate new `device_<timestamp>` only if neither exists.
2. **Firestore & Cloudflare Worker Deduplication**:
   Before creating a new device document in `users/{userId}/devices/{deviceId}`, `FcmService` checks existing Firestore records for matching FCM tokens. If an existing document matches the token, it updates `appVersion`, `platform`, `enabled`, and `updatedAt` on the canonical document rather than creating duplicates.

### Diagnostics & Audio Latency Investigation Findings
- **MP3 Waveform Analysis**: Empirical PCM sample scans confirmed `fast.mp3` has **59.5ms** of leading silence, and `eat.mp3` has **13.1ms** of leading silence (0% silent padding).
- **Alarm Handoff Speed**: `flutter_local_notifications` hands off the alarm to Android's `NotificationManagerService` within **4ms**.
- **Problem A (~40s sound delay when screen ON)**: Android `AudioFlinger` / `SoundPool` audio track buffer allocation latency for non-cached custom raw MP3 resources on background states.
- **Problem B (Silent when screen OFF)**: Android OS `AudioService` Doze/Light-Idle power management suppresses non-system audio stream buffer allocations for raw resource files.
- **Problem C (Disappears on screen ON)**: Android `SystemUI` automatically purges non-public / `autoCancel: true` non-ongoing notifications upon keyguard dismissal / screen wake on OEM ROMs.

---

## Food Feature & API Integration

The food module provides manual search, barcode scanning, local persistence of nutrition logs, and an intelligent **Scan Real Food (AI)** vision scanner.

### Gemini AI API & Resilient Scanner Strategy
*   **Gemini Model**: Integrates the latest vision-capable `gemini-3.5-flash` model.
*   **Centralized AI Exception System**: Defines `AIException` with mapped categories: `quotaExceeded` (429), `networkError` (SocketExceptions), `timeout` (408/TimeoutExceptions), `invalidApiKey` (401/403), `imageTooLarge` (>10 MB), `invalidResponse`, `serverError` (500/503), and `unknown`.
*   **Automatic Retry strategy**: Retries once after 1s for transient network errors.
*   **Connection Timeout Guard**: Imposes a 30-second execution limit on network requests.

---

## Exercises Module (Workout Journal)
The **Exercises Module** ([`ExerciseScreen`](file:///Users/tentendigitalindonesia/Downloads/XxX/Apps/intermittent-fasting/lib/features/statistics/presentation/screens/exercise_screen.dart)) operates as a completely decoupled, standalone workout journal. It does **not** modify or integrate with fasting timers, fasting streaks, TDEE, consumed calories, weight goals, or notification scheduling.