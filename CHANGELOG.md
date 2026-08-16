# Changelog

All notable changes to the **Fomo IF** project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-08-16
### Added
- **Multi-Account Authentication & Data Partitioning**: Implemented secure Firebase Authentication supporting multiple user accounts on a single physical device with strict data isolation (`profile_$uid`, `schedule_$uid`).
- **Safe Anonymous-to-Cloud Data Claiming Flow**: Introduced `UserDataMigrationService` to automatically preserve and claim existing legacy/offline Hive data upon registration or login without data loss or duplicate account creation.
- **Production-Ready Forgot Password & Password Reset Flow**: Created dedicated `/forgot-password` and `/reset-password` screens with real-time email regex validation, disabled submit states, Firebase OOB verification code processing, and password policy enforcement.
- **Canonical Multi-Format Notification Event Resolution**: Engineered a multi-tier canonical event resolution engine (`HiveService.generateAllEventAliases`, `tryClaimNotificationDelivery`) that maps divergent event ID schemas between local alarms and Cloudflare Worker cron jobs, guaranteeing exactly ONE notification and ONE sound across Screen ON, Screen OFF, and LOCKED device states.
- **Durable Notification Delivery State Machine**: Persisted delivery records across app restarts, device reboots, and background isolate lifecycles (`SCHEDULED_LOCAL`, `DELIVERED_LOCAL`, `FCM_SKIPPED_LOCAL_PRIMARY`, `DELIVERED_FCM`, `COMPLETED`).
- **Comprehensive 121-Test Automated Suite**: Added complete automated unit/integration suites covering account switching, anonymous claiming, Hive key safety, forgot password flows, and 15 notification delivery race-condition scenarios.

### Changed
- **Account Screen UI**: Enforced controlled, fixed-height dimensions for "Switch Account" and "Log Out" buttons to prevent vertical expansion on large-display devices while preserving standard typography, icons, and padding.
- **Settings Screen UI**: Removed redundant "Account & Security" section header while preserving the direct account tile presentation and navigation.
- **Statistics Screen Monthly Trend**: Formatted x-axis labels to clean, prominent `W1`, `W2`, `W3`, `W4` week markers with proper `reservedSize: 28`, eliminating text clipping and chart overlaps.

---

## [0.9.0] — 2026-08-14
### Added
- **Startup Performance Optimization (>8.6x Speedup)**: Refactored startup flow into lightweight `initLocal()` + async `initBackgroundServices()`. Accelerated First Flutter Frame rendering from **7.37s** to **<0.85s** by deferring FCM token fetch, Firestore schedule version sync, and AlarmManager notification scheduling to post-frame asynchronous execution.
- **Diagnostic Timing & Lock-Screen Audio Tracing System**: Integrated `[STARTUP-DIAG]`, `[SOUND-VERIFY]`, `[SOUND-TIMING]`, and `[SOUND-LOCK-DIAG]` diagnostic logging to measure initialization phases, notification channel creation, and lock-screen notification lifecycles.
- **Device ID Resolution & Firestore Deduplication Pipeline**: Implemented a stable device ID resolution chain (`fcm_device_id` $\rightarrow$ legacy `device_id` $\rightarrow$ generate new ID) and added FCM token deduplication preventing duplicate Firestore device document creation.

### Changed
- **Notification Channel Sound Selection**: Explicitly mapped `FASTING_START` to `fasting_reminders_fast_v2` (`fast.mp3`, `AudioAttributesUsage.notification`) and `FASTING_END` to `fasting_reminders_eat_v2` (`eat.mp3`, `AudioAttributesUsage.notification`). Retained `fasting_reminders` for 10-minute reminders (system default sound) and `fasting_reminders_silent` for silent preference.
- **Audio Waveform Leading Silence Verification**: Conducted PCM sample analysis confirming `fast.mp3` has **59.5ms** of leading silence and `eat.mp3` has **13.1ms** of leading silence (0% silent audio padding).

### Removed
- **Unused Home Screen Widgets & Foreground Service**: Completely purged 16 legacy files related to Android/iOS home screen widgets, widget providers, layout XMLs, and persistent countdown background service (`FastingForegroundService`, `WidgetSyncService`, `WidgetsNotificationSettingsScreen`).

---

## [0.8.0] — 2026-07-29
### Added
- **Offline-First, Reliable, Self-Healing Notification Scheduler Architecture**: Completed complete architectural audit and redesign of `NotificationService`. Operates 100% offline via native `AndroidScheduleMode.exactAllowWhileIdle` alarms. Treats `AlarmManager` strictly as a write-only execution target with Database (Today's Fasting Schedule) as the primary Source of Truth.
- **Settings Menu Layout UI Refactoring**: Reorganized main `SettingsScreen` layout by displaying `Notification` as a dedicated top-level section.
- **Standalone Exercises & Workout Journal Module**: Expanded `ExerciseScreen` into a dedicated standalone workout log feature.

---

## [0.7.0] — 2026-07-23
### Added
- **Scan Real Food (AI) Feature**: Added an intelligent food recognition system powered by Google Gemini API (`gemini-3.5-flash`).
- **Adaptive Elevation & Premium Shadows**: Built a global premium shadow system via a centralized `AppCardStyle` helper.
- **Centralized Logger Service**: Added `LoggerService` wrapping the `logger` package.
