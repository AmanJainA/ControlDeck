# ControlDeck

ControlDeck is a cross-platform Flutter workspace for opening native Flutter versions of your LifeHub, Portfolio, Notes, Interview, and Railways projects. It does not route project cards to GitHub Pages.

## Design concept

The editable iOS/Android screen concept is in [Figma](https://www.figma.com/design/hl5NbR4aBUGDaeafAJMl73). The reviewed product direction, per-project workflows, security constraints and migration plan are documented in [docs/APP_DESIGN_CONCEPT.md](docs/APP_DESIGN_CONCEPT.md). For first-time platform setup and run commands, see [docs/MOBILE_BUILD_SETUP.md](docs/MOBILE_BUILD_SETUP.md).

## Current native implementation

- **Responsive dashboard:** mobile/tablet/desktop layouts, dark/light themes, favourites, categories, editable shortcuts, local storage and optional Supabase sync.
- **Animated search:** the search control expands smoothly from the app bar and filters the workspace list as you type. The toolbar adapts to narrow screens.
- **LifeHub:** native sign-in, securely persisted custom-auth session, session-aware Supabase connection, and task list/add flow.
- **Portfolio:** native public portfolio view for profile, skills, projects, work experience, education, languages, and social links.
- **Portfolio Admin:** native admin sign-in and CRUD screens for languages, skills, projects, education, work experience, and social links, using the existing admin_login, admin_get_all, admin_upsert, admin_delete, and admin_logout database RPCs. The admin session token is stored in platform secure storage and revalidated by the backend on restore.
- **Notes:** native language/topic/lesson browser backed by the Notes schema, with support for heading, subheading, paragraph, code, ordered/unordered lists, image, note, table, and divider content blocks.
- **Interview:** native sign-in and question catalogue backed by the Interview schema.
- **Railways:** native module map for My Data, Nangia, NR Dashboard, File Viewer, Approvals, Work Tracker, Administration, and Activity/History; secure data loading and role-aware workflows remain to be ported.

## Shared sign-in and security

The requested single sign-in is the intended product experience, but **full cross-project SSO is not complete yet**. This phase adds secure persistence for LifeHub and Portfolio Admin tokens, and their backends still validate those tokens. The projects use different authentication systems: ControlDeck Supabase Auth, LifeHub/Notes custom-auth, Interview custom login RPCs, Portfolio admin RPCs, and Railways legacy role-based authentication. A central identity/session bridge must be deployed and tested for each backend before the app can promise one login across all workspaces. Current status and blockers are in [docs/SSO_IMPLEMENTATION_STATUS.md](docs/SSO_IMPLEMENTATION_STATUS.md). Do not hardcode passwords or commit service-role credentials.

## Important feature-parity status

This is a native Flutter migration in progress, not a claim that every React workflow has already been reproduced. LifeHub currently covers its custom sign-in and basic tasks rather than its complete Life, Finance, Splitwise, dashboard, and profile areas. Notes still needs its full custom-auth, progress tracking, and admin workflows. Interview still needs registration, instructions, timed assessment, autosaved answers, submission/results, and admin reporting. The public Portfolio screen is read-only; its separate admin screen supports content management. Railways now has a native module map, but its source authentication and access model needs a server-side security migration before protected records can be exposed. These remaining workflows should be ported into Flutter screens and continue using each project's existing backend and access controls.

## Configuration

ControlDeck uses its central Supabase Auth project for sign-in and optional cloud sync uses `public.controldeck_apps`. Configure the project first; the app shows a setup screen instead of silently bypassing authentication when these values are absent. To enable cloud sync, run `supabase/controldeck_schema.sql` in a dedicated Supabase project and launch with:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_CONTROLDECK_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_CONTROLDECK_PUBLISHABLE_OR_ANON_KEY
```

The project-specific data connections are separate from ControlDeck's own shortcut sync.

### LifeHub

The LifeHub URL and publishable key use the public configuration already present in LifeHub's main-branch client. LifeHub login uses its custom-auth Edge Function and the returned session header for data requests.

### Notes and Interview

Their source repositories keep database settings in local environment variables. Provide the values at run time rather than committing credentials:

```bash
flutter run \
  --dart-define=NOTES_SUPABASE_URL=https://YOUR_NOTES_PROJECT.supabase.co \
  --dart-define=NOTES_SUPABASE_ANON_KEY=YOUR_NOTES_PUBLISHABLE_OR_ANON_KEY \
  --dart-define=INTERVIEW_SUPABASE_URL=https://YOUR_INTERVIEW_PROJECT.supabase.co \
  --dart-define=INTERVIEW_SUPABASE_ANON_KEY=YOUR_INTERVIEW_PUBLISHABLE_OR_ANON_KEY
```

Never put service-role keys or database passwords in the Flutter app. The Notes and Interview keys must be the same publishable/anon values used by their respective React apps.

## Run and verify

Follow [docs/MOBILE_BUILD_SETUP.md](docs/MOBILE_BUILD_SETUP.md) to generate missing platform runner folders, configure iOS/Android tooling, and run on a device or simulator.

Before a release, run:

```bash
flutter pub get
flutter analyze
flutter test
```

A successful GitHub commit does not by itself mean the iOS/Android builds or every migrated workflow have been tested.
