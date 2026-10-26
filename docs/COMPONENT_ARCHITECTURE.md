# ControlDeck component-based architecture

ControlDeck uses feature screens with shared presentation components. The goal is to keep visual rules reusable while each workspace retains its own data and workflow.

## Current structure

```text
lib/
  main.dart
  lifehub_workspace.dart
  notes_workspace.dart
  interview_native_screen.dart
  railways_native_screen.dart
  railways_data_manager.dart
  shared/
    theme/
      deck_theme.dart
    widgets/
      deck_components.dart
```

## Responsibilities

- **App shell — `main.dart`:** app startup, shared sign-in gate, navigation, workspace discovery and the dashboard.
- **Feature screens:** each workspace file owns its screen state, navigation and workspace-specific operations. Keep changes local to the relevant feature where possible.
- **Shared theme — `shared/theme/deck_theme.dart`:** brand colors and Material 3 light/dark themes. Avoid repeating global color, card and input styles in individual screens.
- **Shared widgets — `shared/widgets/deck_components.dart`:** reusable cards, page heroes, metric tiles, information cards, empty states and section titles. These widgets accept content and style options rather than owning backend logic.
- **Data and authentication:** keep Supabase calls and permission checks within the relevant feature until that feature's data access can be safely extracted into a dedicated service. Do not move credentials, role checks or access rules into presentation widgets.

## Shared widgets

| Widget | Use |
| --- | --- |
| `DeckCard` | Common surface, padding, margins and optional tap handling |
| `DeckPageHero` | Consistent page introduction with configurable icon and gradient |
| `DeckMetricCard` | Dashboard metric tile |
| `DeckInfoCard` | Titled information or report card |
| `DeckEmptyState` | Empty/search-no-results state |
| `DeckSectionTitle` | Consistent section heading with optional trailing action |
| `DeckSpacing` | Shared spacing scale, including the 5 px card gap |
| `DeckColors` / `DeckTheme` | Brand tokens and light/dark app themes |

## Rules for new UI

1. Prefer an existing shared widget before introducing another slightly different card or hero.
2. Keep widgets focused: presentation widgets render data; feature state and async operations stay in the feature screen or a service.
3. Pass callbacks and data into widgets. Avoid putting Supabase queries inside reusable presentation components.
4. Use `DeckTheme.light` and `DeckTheme.dark` for global themes and `DeckColors.accent` for the primary accent.
5. Preserve responsive constraints and use `LayoutBuilder` where layout depends on available width.
6. Keep empty, loading and error states explicit.
7. When a component is used by multiple workspaces, place it under `lib/shared/widgets/`; keep feature-only widgets near their feature until there is a real reuse case.

## Verification

After pulling changes locally, run:

```bash
dart format lib
flutter analyze
flutter test
```

Run these checks before release; a successful GitHub commit alone does not establish that the app builds on every target platform.
