# Code Style Guide

This document describes coding standards, styling tokens, naming rules, and architectural guidelines for maintaining the **Fomo IF** codebase.

---

## 1. Directory Structure Conventions

Always adhere to the feature-first Clean Architecture folder layout:
```
lib/
├── core/                  # Shared system infrastructure
│   ├── constants/         # Central design tokens (spacing, typography)
│   ├── theme/             # Material 3 Theme configurations
│   ├── services/          # Low-level core integrations (database, notifications)
│   └── extensions/        # Helper context/datetime extensions
├── features/              # Feature-scoped logic
│   └── [feature_name]/    # e.g., fasting, body_composition, weight
│       ├── domain/        # Entities & boundary contracts
│       ├── data/          # Services, APIs, and models
│       └── presentation/  # Notifiers, controllers, and screens
└── shared/                # Global cross-cutting widgets
```

---

## 2. Naming Conventions

- **File and Folder Names**: Use `snake_case` only. Examples: `body_comp_service.dart`, `settings_screen.dart`.
- **Class and Extension Names**: Use `PascalCase`. Examples: `BodyCompResult`, `ContextExtensions`.
- **Variable and Method Names**: Use `camelCase`. Examples: `elapsedSeconds`, `updateProfile()`.
- **Providers**: Append `Provider` to all Riverpod providers. Examples: `userProfileProvider`, `streakProvider`.

---

## 3. Design System Tokens (No Hardcoding)

Do **not** hardcode values like color codes, padding, margins, or fonts directly in layout widgets. Always reference design tokens from `core/constants/` or the local `ThemeData` context.

### Spacing (AppSpacing)
Reference standard padding intervals:
- Small padding: `AppSpacing.xs` (4.0) or `AppSpacing.sm` (8.0)
- Grid gaps: `AppSpacing.md` (12.0) or `AppSpacing.lg` (16.0)
- Screen margins: `AppSpacing.screenPadding` (16.0)
- Vertical blocks: `AppSpacing.xl` (24.0) or `AppSpacing.xxl` (32.0)

### Colors (ThemeData ColorScheme)
Always read semantic color tokens from the inherited theme context:
```dart
final colorScheme = Theme.of(context).colorScheme;
final primaryColor = colorScheme.primary;          // Never Colors.green
final cardColor = colorScheme.surfaceContainer;    // Never Colors.white/grey
```

### Typography (AppTypography)
Use Material 3 typography definitions:
- Hero titles: `Theme.of(context).textTheme.headlineLarge`
- Card headers: `Theme.of(context).textTheme.titleMedium`
- Value labels: `Theme.of(context).textTheme.bodyMedium`

---

## 4. Riverpod & State Management Rules

- **Watch vs. Read**:
  - Use `ref.watch(provider)` inside `build()` methods to rebuild widgets on state changes.
  - Use `ref.read(provider)` inside button callback event handlers or action triggers.
- **Provider Scoping**:
  - Prefer `AutoDisposeNotifierProvider` to release RAM allocations when screens disappear.
  - Keep states small, atomic, and focused (e.g. separate `weightEntriesProvider` from `userProfileProvider`).
