# Fomo IF - Intermittent Fasting & Body Composition Tracker

A modern, offline-first Flutter application for intermittent fasting tracking and body composition monitoring. Built with Clean Architecture, Riverpod, and Material 3.

## Features

### Authentication, Account Switching & Legacy Data Safety
- **Multi-Account Support & Complete Data Isolation** - One physical device can securely host multiple Firebase accounts. Switching accounts immediately swaps local Hive namespaces (`profile_$uid`, `schedule_$uid`) without cross-account data leakage.
- **Safe Anonymous-to-Cloud Data Migration** - Users who used the app offline for weeks or months without logging in do not lose historical data. When registering or claiming an account, local data is safely bound to the authenticated Firebase UID.
- **Production-Ready Forgot Password & Reset Password Flow** - Dedicated secure screens (`/forgot-password`, `/reset-password`) using Firebase Authentication OOB email verification. Features live validation, visibility toggles, and zero local password/token storage.
- **Device Binding Transfer & Restriction Protection** - Firestore device mapping enforces single-device ownership while allowing seamless local multi-account switching.

### Fasting Tracker & Notifications
- **Schedule-Driven Engine** - No start/stop buttons needed. The app automatically determines your fasting state from the current time and your daily schedule.
- **Real-Time Countdown** - Live timer updating every second with circular progress ring.
- **Primary vs Fallback Notification Delivery** - Local OS AlarmManager (`zonedSchedule`) acts as the Primary delivery mechanism (0ms latency, exact OS alarm) while FCM acts strictly as Fallback.
- **Zero Duplicate Sound Guarantee** - Multi-format canonical event resolution prevents duplicate notifications and sounds across Screen ON, Screen OFF, and LOCKED device states.
- **Custom Sound Channels** - `FASTING_START` plays `fast.mp3` (`fasting_reminders_fast_v2`), `EAT_TIME` / `FASTING_END` plays `eat.mp3` (`fasting_reminders_eat_v2`), with system default for 10-minute alerts.
- **Timezone-Safe Alarm Scheduling** - Exact alarms via `AndroidScheduleMode.exactAllowWhileIdle` and timezone-safe `tz.TZDateTime`.
- **Multiple Fasting Windows** - Different fasting/eating times for each day of the week.
- **Timeline & Calendar Views** - Yesterday, Today, Tomorrow with scheduled vs actual times, and monthly overview with completion markers.
- **Manual Overrides** - Mark sessions as completed, skipped, or cancelled with custom times.

### High-Performance Startup & Cloud Sync
- **Non-Blocking Fast Startup (<0.85s)** - Main screen UI renders in under 850ms by deferring heavy network and background initializations to post-frame execution.
- **Firebase & Cloudflare Scheduler Integration** - Automatic schedule and device token synchronization with Cloudflare Workers.
- **Device ID Resolution & Deduplication** - Canonical device document mapping with automatic token deduplication.

### Nutrition & Calorie Tracker (Redesigned Statistics)
- **Daily Calorie Requirement** - Mifflin-St Jeor calorie needs calculation using user profiles with custom activity multipliers and weight goals.
- **Scan Real Food (AI)** - Powered by Google Gemini (`gemini-3.5-flash`) for meal photo nutritional analysis.
- **Nutrition Details Page** - Targets for calories, protein, fat, carbohydrates, fiber, and water intake.
- **Total Calories Consumed** - Real-time summation of calories from all food logs.
- **Average Fast Details** - Comprehensive fast metrics incorporating shortest, longest, and average fasting durations.
- **Standalone Exercises Journal** - Log workouts, sets, reps, weights, and ACSM MET estimated calories burned.
- **Clean Responsive Monthly Trend** - Formatted `W1`, `W2`, `W3`, `W4` charts without text clipping or layout overflow.

### Body Composition & History
- **US Navy Body Fat Formula** - Accurate body fat % from waist, neck, hip measurements.
- **Automatic Calculations** - BMI, BMR, TDEE, Lean Mass, Fat Mass.
- **Health Categories** - Essential Fat, Athlete, Fitness, Average, Obese (gender-specific).
- **Progress Photos** - Front, side, back views with timeline.
- **Measurement History** - Weight, waist, neck, hip, chest, arms, thighs, calves.
- **Charts** - Weight, body fat %, lean mass, fat mass, BMI (weekly/monthly/yearly/all time).

### Smart Robustness Features
- **100% Offline Core Logic** - Bundled local Google Fonts (Inter) assets and disabled runtime network fetching.
- **Fail-Safe Hive Storage** - Box openings run with 4-level automatic recovery/deletion and temp path fallbacks.
- **Data Export/Import** - Full JSON backup/restore.
- **Dark/Light Theme** - System-aware with manual override.
- **Onboarding** - 4-step setup flow (Welcome, Profile, Goals, Schedule).

---

## Screenshots

<p align="center">
  <img src="screenshots/beranda.png" width="170"/>
  <img src="screenshots/bodyfat.png" width="170"/>
  <img src="screenshots/soon.png" width="170"/>
  <img src="screenshots/stats.png" width="170"/>
</p>
