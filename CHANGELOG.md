# Changelog

All notable changes to the **Fomo IF** project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.6.0] — 2026-07-20
### Added
- **Decomposed Home Screen Widgets**: Extracted legacy helper methods in `home_screen.dart` into modular reusable widgets under `lib/features/home/presentation/widgets/` (`HomeHeader`, `FastingProgressCard`, `NextAlarmCard`, `CaloriesCard`, `CompletedCard`).

### Changed
- **Standardized Clean Architecture Directory Structure**: Reorganized files to strictly follow feature-first structure (grouping views under `presentation/screens/` and providers under `presentation/providers/`).
- **Refactored Food Scanner to Food Feature**: Replaced legacy `food_scanner` feature folder with a scalable layered `food` feature, splitting models, notifier providers, and screens.
- **Centralized Global Services**: Consolidated and moved core services (such as `HiveService` and `FoodApiService`) under `lib/core/services/`.

### Fixed
- **Stability and Compile Correction**: Fixed capitalization on boolean constants (e.g. `False` -> `false`) and imported foundation and duration extensions correctly, restoring the application to a 100% stable compiling state.

---

## [0.5.0] — 2026-07-19
### Added
- **Food Module MVP**: Integrated Manual Food Search, Barcode Scanner, and Nutrition Saving.
- **Persistent Local Storage**: Built offline-first local persistence utilizing Hive boxes.
- **Statistics Integration**: Introduced "Total Calories Consumed" tracking syncing directly from Hive logs.
- **Bilingual & Fallback Search**: Programmed a hybrid query system translating Indonesian food searches (e.g. `nasi` to `Rice`) with automated fallbacks to OpenFoodFacts V2 API endpoints.
- **Relevance Scoring Engine**: Added title keyword scoring, noise filters, and completeness weighting to search results.
- **Calorie Burn Estimator**: Implemented Mifflin-St Jeor real-time calorie burn estimator updating continuously during fasting windows.

### Fixed
- **Camera Navigation Intercept**: Added back-swipe and hardware back key intercepts on the scanner camera via `PopScope` to prevent unexpected application exit.
- **Card Spacing & Layout Consistency**: Realigned statistic cards on Home and Statistics dashboards to left-aligned structures (Icon -> Value -> Title -> Subtitle) and ensured row layouts adapt heights naturally using `IntrinsicHeight` constraints.

---

## [0.4.0] — 2026-07-17
### Added
- **Global Rebranding**: Renamed application to **Fomo IF** across Dart, Kotlin, XML, and Info.plist layers.
- **Modern Vector Logo Pack**: Added SVG master versions (`logo.svg`, `logo_light.svg`, `logo_dark.svg`, `icon_foreground.svg`, `icon_background.svg`, `monochrome_icon.svg`, `notification_icon.svg`, and `splash_logo.svg`) inside `assets/branding/`.
- **Adaptive Launcher Icons**: Configured Android adaptive and monochrome icons utilizing a clean clock/moon/leaf PNG foreground with 25% safe zone padding to look great on circle/squircle systems.
- **Native Splash Screen**: Implemented native Android 12+ splash screens centering the clean logo on light (white) and dark (`#121212`) background themes.
- **Notification Icon**: Designed a transparent, high-contrast monochrome notification stencil (`ic_notification.xml`) for Android's status bar drawer.

### Fixed
- **RemoteViews Inflation Crash**: Resolved `BadForegroundServiceNotificationException` by replacing raw `<View>` tags with RemoteViews-supported `<FrameLayout>` elements for dividers.

---

## [0.3.0] — 2026-06-15
### Added
- **Native Ongoing Notification**: Programmed a persistent Android Foreground Service timer that syncs local fasting state countdown values in real-time.
- **Custom Notification Layout**: Added collapsed (`notification_collapsed.xml`) and expanded (`notification_expanded.xml`) views featuring custom Material Symbols and Canvas-drawn progress bars.
- **Home Screen Widgets**: Created Small (2x2), Medium (4x2), and Large (4x4) interactive Android Home Screen Widgets.
- **Real-time Sync Channel**: Added `com.fastflow.app/widget_sync` MethodChannel to push active states into native `SharedPreferences` on state ticks.
- **Quick Actions Deep Linking**: Hooked up PendingIntents and MainActivity intent listeners to navigate straight to sections like `/home/body-composition` on notification buttons.

---

## [0.2.0] — 2026-05-10
### Added
- **Body Composition Module**: Added body fat estimation utilizing the official U.S. Navy Circumference formula.
- **Advanced Tape Measurements**: Added fields for Neck, Waist, Hip, Chest, Arms, Thighs, and Calves with unit conversions (kg/lbs, cm/inches).
- **Physical Boundary Validations**: Implemented strict validation checks (e.g. Waist > Neck) to ensure biological accuracy.
- **Physiological Metrics Calculations**: Added calculations for BMI, Lean/Fat Mass, Mifflin-St Jeor BMR, TDEE, WHtR, and Ideal Weight.
- **Dynamic Charting Dashboard**: Enabled 10 health metric charts plotted over Weekly, Monthly, Yearly, and All-Time intervals.

---

## [0.1.0] — 2026-04-01
### Added
- **Core Fasting Engine**: Automated fasting detection from weekly schedules, removing the need for manual start/stop toggling.
- **Weekly Schedule Strips**: Created interactive schedule builders with Copy Monday to All capabilities.
- **Timeline Screen**: Visualized Yesterday, Today, and Tomorrow fasting and eating window bands.
- **Local SQLite/Hive Database**: Implemented offline storage boxes for weight logs, fasting records, and profiles.
- **Light & Dark Theme**: Configured Material 3 ThemeData with system theme awareness.
