# Contributing to Fomo IF

We welcome contributions to Fomo IF! Please read this guide to understand our coding styles, branch structure, and commit requirements.

---

## 1. Branching & PR Workflow

- **Branch Naming**:
  - New features: `feature/short-description`
  - Bug fixes: `bugfix/short-description`
  - Refactoring: `refactor/short-description`
  - Documentation: `docs/short-description`
- **Pull Request Guidelines**:
  - Always run `flutter format .` and `flutter analyze` before pushing.
  - Write descriptive PR descriptions summarizing the changes and verification steps.
  - Include screenshots or screen recordings for UI changes.

---

## 2. Commit Message Conventions

We follow **Conventional Commits** for clean changelog generation:
- `feat`: A new feature (e.g., `feat: add chest tape measurement input`)
- `fix`: A bug fix (e.g., `fix: resolve RemoteViews division overflow crash`)
- `docs`: Documentation changes only (e.g., `docs: update BMR formulas description`)
- `style`: Code style changes (formatting, missing semicolons, no code logic change)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests or correcting existing tests
- `chore`: Build tasks, package managers, dependency configurations, etc.

*Example:*
```bash
git commit -m "feat: integrate Android 13 monochrome adaptive launcher icon"
```

---

## 3. Code Style & Conventions

- **Formatting**: We enforce trailing commas for all multi-parameter lists, list literals, and widget trees. Use `dart format` to automatically format files.
- **Linting**: Ensure there are no warnings or errors reported by `analysis_options.yaml`.
- **Naming Conventions**:
  - Classes and Types: `PascalCase` (e.g., `BodyCompService`)
  - Methods and Variables: `camelCase` (e.g., `calculateBodyFat`)
  - Constants: `camelCase` or `UPPER_SNAKE_CASE` (e.g., `AppSpacing.screenPadding` or `CHANNEL_ID`)
  - Folders and Files: `snake_case` (e.g., `body_comp_service.dart`)

---

## 4. Architectural Rules

- **Clean Architecture Rules**:
  - Domains must be completely independent of UI and third-party databases.
  - Business logic sits inside Domain Entities or Presentation State Notifiers.
  - Data loading goes through Repository implementations mapping DTOs into Domain Entities.
- **Riverpod Rules**:
  - Do not read providers inside widgets globally; use `ConsumerWidget` or `ConsumerStatefulWidget` and read them reactively via `WidgetRef.watch`.
  - Prefer auto-dispose providers unless state needs to persist across screen lifetimes.
