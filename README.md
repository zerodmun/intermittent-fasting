# Fomo IF - Intermittent Fasting & Body Composition Tracker

A modern, offline-first Flutter application for intermittent fasting tracking and body composition monitoring. Built with Clean Architecture, Riverpod, and Material 3.

## Features

### Fasting Tracker
- **Schedule-driven engine** - No start/stop buttons needed. The app automatically determines your fasting state from the current time and your daily schedule.
- **Real-time countdown** - Live timer updating every second with circular progress ring
- **Multiple fasting windows** - Different fasting/eating times for each day of the week
- **Timeline view** - Yesterday, Today, Tomorrow with scheduled vs actual times
- **Calendar view** - Monthly overview with completion markers
- **Manual overrides** - Mark sessions as completed, skipped, or cancelled with custom times
- **Copy Monday to All** - Quick setup for consistent weekly schedules

### Body Composition
- **US Navy Body Fat Formula** - Accurate body fat % from waist, neck, hip measurements
- **Automatic calculations** - BMI, BMR, TDEE, Lean Mass, Fat Mass
- **Health categories** - Essential Fat, Athlete, Fitness, Average, Obese (gender-specific)
- **Progress photos** - Front, side, back views with timeline
- **Measurement history** - Weight, waist, neck, hip, chest, arms, thighs, calves
- **Charts** - Weight, body fat %, lean mass, fat mass, BMI, waist, chest, arms, thighs, calves (weekly/monthly/yearly/all time)

### Smart Features
- **Streak tracking** - Current and longest fasting streaks
- **Auto history generation** - Automatically creates completed records for past days
- **Offline notifications** - Fasting start, eating window start, preparing alerts (2 hours before fast)
- **Data export/import** - Full JSON backup/restore
- **Dark/Light theme** - System-aware with manual override

### Onboarding
1. **Welcome** - Feature overview
2. **Profile** - Name, age, gender, height, current weight
3. **Goals** - Target weight, body fat %, waist, BMI
4. **Schedule** - Per-day fasting/eating times with "Copy Monday" shortcut

---

## Screenshots

*(Add screenshots here)*

---

## Architecture

**Clean Architecture** with **Riverpod** state management:

```
lib/
├── core/                    # Shared infrastructure
│   ├── data/services/       # HiveService (database)
│   ├── providers/           # Core Riverpod providers
│   ├── router/              # AppRouter (GoRouter)
│   ├── services/            # NotificationService
│   ├── theme/               # AppTheme (Material 3)
│   └── extensions/          # Context, DateTime, Duration
├── features/
│   ├── fasting/             # Fasting engine, timer, schedule
│   ├── body_composition/    # Measurements, calculations, charts
│   ├── onboarding/          # 4-step setup flow
│   ├── home/                # Dashboard
│   ├── history/             # Past sessions
│   ├── statistics/          # Charts & trends
│   ├── weight/              # Body measurements
│   └── settings/            # App preferences
└── shared/widgets/          # Reusable UI components
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Singleton FastingEngine** | One `Timer.periodic` for entire app lifetime |
| **Schedule = Source of Truth** | State = `DateTime.now()` + `Schedule` (no manual start/stop) |
| **Riverpod StateNotifier** | Reactive UI updates from engine changes |
| **Hive CE** | Fast, offline-first local storage |
| **Auto-history** | Seamless past-day record generation |

---

## Getting Started

### Prerequisites
- Flutter SDK 3.19+
- Dart 3.3+
- Android Studio / Xcode for device deployment

### Installation

```bash
# Clone repository
git clone <repository-url>
cd fastflow

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### Build Commands

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# iOS
flutter build ios --release
```

---

## Permissions

| Platform | Permissions |
|----------|-------------|
| Android 13+ | `POST_NOTIFICATIONS` |
| Android 12+ | `SCHEDULE_EXACT_ALARM` |
| iOS | Notification permission prompt |

**No internet permission required** - fully offline.

---

## Data Export/Import

### Export (JSON)
```json
{
  "version": 1,
  "exportDate": "2026-07-17T10:30:00Z",
  "userProfile": { "name": "John", "ageYears": 30, ... },
  "fastingSchedule": { "dailySchedules": { "1": {...}, ... } },
  "fastingRecords": [ { "id": "uuid", "planName": "Daily Schedule", ... } ],
  "weightEntries": [ { "id": "uuid", "weightKg": 75.5, ... } ]
}
```

### Import
File → Settings → Import Data → Select JSON file

---

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.19+ |
| State | Riverpod 3.3+ (NotifierProvider) |
| Navigation | GoRouter 17+ |
| Database | Hive CE 2.19+ |
| Notifications | flutter_local_notifications 18+ |
| Charts | fl_chart 1.2+ |
| Typography | Google Fonts (Inter) |
| Date/Time | intl 0.20+ |
| Calendar | table_calendar 3.2+ |

---

## Development

```bash
# Static analysis
flutter analyze

# Format code
dart format .

# Run tests
flutter test

# Check dependencies
flutter pub outdated
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

For issues and feature requests, please use the GitHub issue tracker.

---

*FastFlow - Fast smarter, track better, achieve your goals.*