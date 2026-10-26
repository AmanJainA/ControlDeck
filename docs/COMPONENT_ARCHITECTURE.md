# ControlDeck component-based MVC architecture

ControlDeck combines reusable presentation components with an MVC structure for feature code. The purpose is to keep the View focused on rendering, the Controller responsible for UI state and actions, the Model responsible for app data, and the Repository responsible for persistence.

## Structure

```text
lib/
  main.dart                         # app bootstrap, auth gate and navigation shell
  features/
    apps/
      models/
        deck_app.dart               # DeckApp entity and starter records
      controllers/
        deck_home_controller.dart   # launcher state, filters and actions
      repositories/
        deck_app_repository.dart    # Supabase / local preferences persistence
  shared/
    theme/
      deck_theme.dart
    widgets/
      deck_components.dart
  lifehub_workspace.dart            # feature Views
  notes_workspace.dart
  interview_native_screen.dart
  railways_native_screen.dart
  railways_data_manager.dart
```

## MVC responsibilities

- **Model — `features/apps/models/deck_app.dart`:** the `DeckApp` entity, JSON conversion and default launcher records. It contains no widget or database calls.
- **View — Flutter screens and shared widgets:** renders app data, handles layout and sends user intent through callbacks. Shared widgets stay presentation-only.
- **Controller — `features/apps/controllers/deck_home_controller.dart`:** owns launcher state, search/category/favorite filters and app actions. It notifies listeners when state changes.
- **Repository — `features/apps/repositories/deck_app_repository.dart`:** handles Supabase and SharedPreferences reads/writes. It contains no UI or navigation.
- **App shell — `main.dart`:** startup, shared authentication gate, navigation and app-level theme selection.
- **Feature workspaces:** LifeHub, Notes, Railways and Interview keep their domain-specific workflows separate. Extract their data access into feature-specific repositories/controllers incrementally; do not move permission checks into reusable widgets.

## Shared components

Use `DeckCard`, `DeckPageHero`, `DeckMetricCard`, `DeckInfoCard`, `DeckEmptyState`, `DeckSectionTitle`, `DeckSpacing`, `DeckColors` and `DeckTheme` before creating duplicate presentation patterns.

## Rules

1. Views should not contain direct Supabase or SharedPreferences calls once migrated to a controller/repository.
2. Controllers should not import Flutter Material widgets or build UI.
3. Repositories should not show dialogs, snackbars or navigate.
4. Keep app-wide auth/session behavior in the app shell; keep workspace permissions in the relevant feature.
5. Preserve the existing shared ControlDeck sign-in and direct workspace/dashboard behavior during refactors.
6. Use dependency injection for repositories so controllers can be tested with fakes.
7. Keep loading, empty and error states explicit, and preserve responsive layouts and light/dark theme support.

## Verification

Run locally after pulling the branch:

```bash
dart format lib
flutter pub get
flutter analyze
flutter test
```

These checks have not been run by the GitHub editing workflow. The app launcher View now delegates app loading, filtering and CRUD persistence to `DeckHomeController` and `DeckAppRepository`. Dialog presentation, navigation and transient widget state remain in the View. Apply the same separation incrementally to the LifeHub, Notes, Railways and Interview workspaces.
