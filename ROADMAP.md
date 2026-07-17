# Roadmap

This roadmap outlines planned features, platform expansions, and integrations scheduled for future releases of **Fomo IF**.

---

## 🚀 Near-Term Goals (v0.5.0 — v0.6.0)

### Apple iOS Integrations
- **iOS Home Screen Widgets**: Port the current Android widgets to iOS using Swift, SwiftUI, and WidgetKit (supporting Small, Medium, and Large configurations).
- **iOS Live Activities & Dynamic Island**: Implement ongoing Live Activity stencils to display active fasting timers directly on iOS lock screens and the Dynamic Island.

### Local Enhancements
- **Achievements & Badges**: Create an offline achievements engine to award badges for milestone accomplishments (e.g., "10-Day Streak", "Consistent weight logging").
- **Extended Charts Filter**: Add interactive zoom, regression lines, and monthly average aggregations to the statistics charts page.

---

## 🔄 Mid-Term Goals (v0.7.0 — v0.8.0)

### Fitness & Health SDK Syncs
- **Android Health Connect**: Integrate with Google's Health Connect API to sync weight records and daily activities with external fitness logs automatically.
- **Apple HealthKit**: Implement native iOS HealthKit read/write bridges to pull daily weight metrics and push estimated body composition parameters.

### Standalone Smartwatch Apps
- **Wear OS Complications**: Develop a lightweight Wear OS companion application providing status complications and quick weight log dials.
- **Apple Watch companion**: Program a watchOS App using WatchKit to sync active schedules and allow checking fasting phase elapsed counts.

---

## 🌐 Long-Term Goals (v0.9.0 — v1.0.0)

### Cloud Sync & Backup
- **Encrypted Cloud Sync**: Provide an optional, end-to-end encrypted backup system (via private Firebase or Supabase storage) to synchronize profiles across multiple user devices without compromising privacy.
- **CSV/JSON Multi-Format Export**: Support exporting raw tables in CSV, Excel, and JSON formats for external clinician reviews.
