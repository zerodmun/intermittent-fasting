# Fomo IF - Intermittent Fasting & Body Composition Tracker

## Technical Documentation

### Overview
Fomo IF is an offline-first Flutter application for intermittent fasting tracking and body composition monitoring. Built with Clean Architecture, Riverpod state management, daily scheduled local notifications, and robust cloud synchronization with multi-account isolation.

**Key Principles:**
- **Zero external dependencies for core operation** - Core fasting & tracking logic works completely offline.
- **Timeline-Based Session Continuity** - Fasting state calculated from chronological `TimelineSession` ranges, ensuring midnight transitions do not reset active fasting.
- **Single timer** - One `Timer.periodic` runs for the entire app lifetime.
- **Multi-Account Partitioning & Data Isolation** - Each Firebase account has completely isolated local Hive namespaces (`profile_$uid`, `schedule_$uid`).
- **Safe Anonymous-to-Cloud Migration** - Unclaimed legacy local data is preserved and claimed safely upon registration without data loss.
- **Primary vs Fallback Notification Architecture** - Local AlarmManager (`zonedSchedule`) is Primary (0ms local execution); FCM push is Fallback only.
- **Canonical Multi-Format Notification Resolution** - Resolves cross-platform event ID discrepancies to guarantee exactly ONE notification and ONE sound across all device states.
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
│   ├── router/             # AppRouter (GoRouter with auth & reset routes)
│   ├── services/           # AuthService, UserDataMigrationService, HiveService, NotificationService, FcmService, NotificationSyncService, StartupDiag, LoggerService
│   └── theme/              # AppTheme (Material 3)
├── features/
│   ├── auth/
│   │   └── presentation/
│   │       └── screens/    # LoginScreen, RegisterScreen, ForgotPasswordScreen, ResetPasswordScreen, AccountScreen
│   ├── fasting/
│   │   ├── domain/entities/ # FastingState, FastingStatus, FastingPhase, FastingRecord, FastingSchedule
│   │   ├── data/services/   # FastingEngine (singleton), TimelineGenerator, SessionResolver, HistoryGenerator
│   │   └── presentation/    # FastingScreen, FastingProgressCard
│   ├── body_composition/
│   │   ├── domain/entities/ # BodyCompResult, BodyFatCategory
│   │   └── data/services/   # BodyCompCalculator (US Navy formula)
│   ├── onboarding/
│   │   ├── domain/entities/ # UserProfile, DailySchedule
│   │   └── presentation/    # OnboardingScreen, OnboardingProvider
│   ├── home/                # HomeScreen, Home widgets
│   ├── food/                # FoodScannerScreen, BarcodeScannerScreen, ProductResultScreen, Gemini AI
│   ├── statistics/          # StatisticsScreen, AverageFastDetailScreen, ExerciseScreen, WeeklyDetailScreen, MonthlyCalendarScreen, NutritionDetailsScreen
│   ├── weight/              # WeightScreen (measurements, charts)
│   └── settings/            # SettingsScreen, NotificationSettingsScreen
└── shared/widgets/          # Reusable UI components
```

---

## Authentication & Account Management Architecture

### Multi-Account Hive Partitioning
The local storage uses account-scoped keys in Hive boxes to guarantee strict data isolation across accounts:
*   `profile_$uid`: Account-specific `UserProfile`
*   `schedule_$uid`: Account-specific `FastingSchedule`
*   `known_accounts`: List of accounts active on the device for fast account switching
*   `bound_firebase_uid`: Currently active session UID

When switching **Account A $\rightarrow$ Account B**:
1. Active UID is updated to `Account B`.
2. Local Hive services immediately resolve `profile_B` and `schedule_B`.
3. Notification reminders are refreshed: `cancelReminderNotifications()` $\rightarrow$ `scheduleReminderNotifications('Account Switch')`.
4. Previous account data is never rendered in Account B.

### Safe Anonymous-to-Cloud Migration (`UserDataMigrationService`)
To protect users who used the app offline before registering:
1. **Unclaimed Data Detection**: `hasUnclaimedLocalUserData()` checks if root `profile` or `schedule` keys exist without a bound UID.
2. **Claiming on Registration**: `claimLocalUserDataFor(uid)` copies legacy keys to `profile_$uid` and `schedule_$uid` before binding.
3. **Reconciliation on Login**:
   - If Cloud Firestore contains user data $\rightarrow$ pulls cloud data into local storage.
   - If Cloud is empty but local has unclaimed data $\rightarrow$ migrates local data to cloud.
   - Preserves offline-first operation.

### Secure Forgot Password & Reset Password Flow
*   **Forgot Password Screen (`/forgot-password`)**: Form with live regex validation. Disables submit button until email format is valid. Initiates Firebase OOB password reset email.
*   **Reset Password Screen (`/reset-password`)**: Dedicated form validating reset code (`oobCode`), new password ($\ge$ 6 characters), and matching password confirmation.
*   **Zero Security Leakage**: Passwords and reset tokens are NEVER stored in Hive, SharedPreferences, Firestore, or logs.

---

## Notification Delivery & Zero-Duplicate Architecture

### Primary vs Fallback Delivery Rule
```text
Event (e.g. FASTING_START at 18:00:00)
                  │
                  ├── Primary Local Alarm (zonedSchedule)
                  │       ↓
                  │   Delivers notification at 18:00:00 (0ms latency, exact OS alarm)
                  │   Plays fast.mp3
                  │   Status: SCHEDULED_LOCAL / DELIVERED_LOCAL
                  │       ↓
                  │   FCM push arrives at ~18:00:20 (Cloudflare Worker cron)
                  │       ↓
                  │   FCM checks canonical delivery state (tryClaimNotificationDelivery == false)
                  │   FCM skips display and logs: FCM_SKIPPED_LOCAL_PRIMARY
                  │   Zero duplicate sound / Zero duplicate notification
                  │
                  └── Fallback Path (if Local Alarm was unavailable / new device)
                          ↓
                      FCM fallback claims event (tryClaimNotificationDelivery == true)
                          ↓
                      FCM delivers notification + sound
                      Status: DELIVERED_FCM → COMPLETED
```

### Canonical Event Resolution (`HiveService`)
To eliminate duplicate notifications caused by syntax differences between backend and local schedulers, `HiveService` maps all event variants to a canonical daily event ID:
*   `canonical_FASTING_START_YYYY-MM-DD`
*   `canonical_FASTING_START_SOON_YYYY-MM-DD`
*   `canonical_FASTING_END_YYYY-MM-DD`
*   `canonical_FASTING_END_SOON_YYYY-MM-DD`

**Supported Alias Schemas:**
*   Cloudflare Worker: `${scheduleId}_v${version}_${eventType}_${date}`
*   Cloud Functions: `${scheduleId}_v${version}_${eventType}`
*   Local ISO: `${scheduleId}_${isoTimestamp}_${eventType}`

### Notification Channels & Sound Resources
*   **`FASTING_START`** (ID 2001): `fasting_reminders_fast_v2` channel $\rightarrow$ `fast.mp3` (`raw/fast.mp3`, `AudioAttributesUsage.notification`)
*   **`EAT_TIME` / `FASTING_END`** (ID 2003): `fasting_reminders_eat_v2` channel $\rightarrow$ `eat.mp3` (`raw/eat.mp3`, `AudioAttributesUsage.notification`)
*   **10-Minute Reminders** (IDs 2000, 2002): `fasting_reminders` channel $\rightarrow$ System Default Sound
*   **Silent Preferences**: `fasting_reminders_silent` channel $\rightarrow$ `playSound: false`

---

## Core Fasting Engine

### FastingEngine (Singleton)
**File:** `lib/features/fasting/data/services/fasting_engine.dart`
Runs a single periodic 1-second timer that recalculates fasting metrics, remaining countdown, and active phases. Reacts automatically to Hive box updates without polling.

### TimelineGenerator & SessionResolver
**Files:** `timeline_generator.dart`, `session_resolver.dart`
Generates chronological `TimelineSession` ranges spanning yesterday, today, and tomorrow. Accurately determines active and transition states across midnight boundaries and multi-day fasting plans.

---

## Food Feature & Gemini AI Integration

*   **Gemini Model**: Integrates vision-capable `gemini-3.5-flash` model.
*   **Nutrition Targets**: Mifflin-St Jeor daily calorie requirement calculation, macro-nutrient targets, and food logging.
*   **Exception System**: Centralized `AIException` with automatic retry on transient network errors.

---

## Exercises Module (Workout Journal)
Decoupled workout logger supporting exercise names, sets, reps, weights, and ACSM MET calorie expenditure estimation.