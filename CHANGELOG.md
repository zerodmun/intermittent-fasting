# Changelog

All notable changes to the **Fomo IF** project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
