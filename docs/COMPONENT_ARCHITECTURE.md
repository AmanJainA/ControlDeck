# ControlDeck component-based MVC architecture

ControlDeck uses shared Flutter UI components and a feature-first MVC structure. The launcher is the first feature migrated end-to-end; the same rules are intended for the domain-specific LifeHub, Notes, Railways, Interview and Portfolio modules.

## Structure

```text
lib/
  main.dart
  features/
    apps/
      models/
        deck_app.dart
      controllers/
        deck_home_controller.dart
      repositories/
        deck_app_repository.dart
      views/widgets/
        deck_app_editor_dialog.dart
  shared/
    theme/
      deck_theme.dart
    widgets/
      deck_components.dart
      deck_app_card.dart
      deck_workspace_hero.dart
      deck_feedback_widgets.dart
      deck_navigation.dart
      deck_layout.dart
  lifehub_workspace.dart
  notes_workspace.dart
  railways_native_screen.dart
  railways_data_manager.dart
  interview_native_screen.dart
```

## MVC responsibilities

- **Model — `features/apps/models/deck_app.dart`:** app entity, JSON conversion and default records. No UI or persistence.
- **View — Flutter screens and shared widgets:** renders state, validates presentation input and sends user intent through callbacks. `DeckAppEditorDialog` returns a model; it does not save it.
- **Controller — `features/apps/controllers/deck_home_controller.dart`:** owns launcher records, loading/error state, search/category/favorite filters and CRUD actions. It rolls state back if persistence fails.
- **Repository — `features/apps/repositories/deck_app_repository.dart`:** handles Supabase and SharedPreferences. It does not build UI or navigate.
- **App shell — `main.dart`:** startup, shared authentication, navigation shell and app theme selection.
- **Domain workspaces:** each workspace should have its own models, controllers and repositories as its data workflows are migrated. Keep role/permission enforcement in the feature/domain layer, not in generic widgets.

## Shared component catalog

- **Surfaces:** `DeckCard`, `DeckInfoCard`, `DeckMetricCard`
- **Headers and status:** `DeckPageHero`, `DeckWorkspaceHero`, `DeckSectionTitle`, `DeckNotice`, `DeckConnectionNotice`
- **States:** `DeckEmptyState`, `DeckLauncherEmptyState`
- **Layout:** `DeckPageContainer`, `DeckResponsiveGrid`, `DeckSpacing`
- **Navigation and feature views:** `DeckSideNavigation`, `DeckAppCard`, `DeckAppEditorDialog`
- **Theme tokens:** `DeckColors`, `DeckTheme`

Prefer these widgets over copying styles into each screen. Keep components configurable through typed properties and callbacks; avoid making them depend directly on Supabase, navigation routes or a specific feature controller.

## Rules

1. Views should not perform Supabase or SharedPreferences operations; call a controller.
2. Controllers manage feature state and actions, not widget trees, dialogs or snackbars.
3. Repositories own data access only.
4. Shared widgets are presentation-only and reusable across features.
5. Keep authentication/session behavior in the app shell and permission checks in the relevant feature.
6. Inject repositories into controllers so tests can use fakes.
7. Keep loading, empty, error, responsive and light/dark states explicit.

## Local verification

After pulling, run:

```bash
dart format lib
flutter pub get
flutter analyze
flutter test
```

The GitHub editing workflow has not run these commands. The app launcher now uses MVC for app loading, filtering and CRUD persistence, plus shared widgets for the app cards, editor, hero, notices, navigation and responsive grid. The other workspaces have some shared presentation patterns, but their data workflows still need separate controller/repository migrations before the entire app can be considered fully MVC.
