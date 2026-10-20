# ControlDeck

ControlDeck is a cross-platform Flutter workspace for opening native Flutter versions of your LifeHub, Portfolio, Notes, Interview, and Railways projects. It does not route project cards to GitHub Pages.

## Design concept

The editable iOS/Android screen concept is in [Figma](https://www.figma.com/design/hl5NbR4aBUGDaeafAJMl73). The reviewed product direction, per-project workflows, security constraints and migration plan are documented in [docs/APP_DESIGN_CONCEPT.md](docs/APP_DESIGN_CONCEPT.md).

## Current native implementation

- **Responsive dashboard:** mobile/tablet/desktop layouts, dark/light themes, favourites, categories, editable shortcuts, local storage and optional Supabase sync.
- **Animated search:** the search control expands smoothly from the app bar and filters the workspace list as you type. The toolbar adapts to narrow screens.
- **LifeHub:** native sign-in, session-aware Supabase connection, and task list/add flow.
- **Portfolio:** native public portfolio view for profile, skills, projects, work experience, education, languages, and social links.
- **Portfolio Admin:** native admin sign-in and CRUD screens for languages, skills, projects, education, work experience, and social links, using the existing admin_login, admin_get_all, admin_upsert, admin_delete, and admin_logout database RPCs.
- **Notes:** native language/topic/lesson browser backed by the Notes schema.
- **Interview:** native sign-in and question catalogue backed by the Interview schema.
- **Railways:** native placeholder workspace; the full Railway portal workflows still need to be ported.

## Shared sign-in and security

The requested single sign-in is the intended product experience, but the source projects currently use different authentication systems: ControlDeck/Portfolio Supabase Auth or admin RPCs, LifeHub custom-auth Edge Functions, Notes custom-auth/session handling, Interview custom login RPCs, and Railways table-based username/password checks. A single screen does not create secure SSO by itself. A central identity/session bridge must be deployed and tested for each backend before the app can promise one login across all workspaces. Do not hardcode the supplied password or commit service-role credentials.

## Important feature-parity status

This is a native Flutter migration in progress, not a claim that every React workflow has already been reproduced. LifeHub currently covers sign-in and basic tasks rather than its complete Life, Finance, Splitwise, dashboard, and profile areas. Notes still needs its full custom-auth, progress tracking, and admin workflows. Interview still needs registration, instructions, timed assessment, autosaved answers, submission/results, and admin reporting. The public Portfolio screen is read-only; its separate admin screen supports content management. These remaining workflows should be ported into Flutter screens and continue using each project's existing backend and access controls.

## Configuration

ControlDeck's own optional cloud sync uses public.controldeck_apps. To enable it, run supabase/controldeck_schema.sql in a dedicated Supabase project and launch with:

~~~bash
flutter pub get
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://YOUR_CONTROLDECK_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_CONTROLDECK_PUBLISHABLE_OR_ANON_KEY
~~~

The project-specific data connections are separate from ControlDeck's own shortcut sync.

### LifeHub

The LifeHub URL and publishable key use the public configuration already present in LifeHub's main-branch client. LifeHub login uses its custom-auth Edge Function and the returned session header for data requests.

### Notes and Interview

Their source repositories keep database settings in local environment variables. Provide the values at run time rather than committing credentials:

~~~bash
flutter run -d macos \
  --dart-define=NOTES_SUPABASE_URL=https://YOUR_NOTES_PROJECT.supabase.co \
  --dart-define=NOTES_SUPABASE_ANON_KEY=YOUR_NOTES_PUBLISHABLE_OR_ANON_KEY \
  --dart-define=INTERVIEW_SUPABASE_URL=https://YOUR_INTERVIEW_PROJECT.supabase.co \
  --dart-define=INTERVIEW_SUPABASE_ANON_KEY=YOUR_INTERVIEW_PUBLISHABLE_OR_ANON_KEY
~~~

Never put service-role keys or database passwords in the Flutter app. The Notes and Interview keys must be the same publishable/anon values used by their respective React apps.

## Run and verify

~~~bash
flutter pub get
flutter analyze
flutter run -d macos
~~~

The GitHub changes have been committed, but a Flutter build/analyze run still needs to be performed in a local environment with the Flutter SDK installed.
