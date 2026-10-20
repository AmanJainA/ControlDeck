# ControlDeck

ControlDeck is a cross-platform Flutter workspace for opening native Flutter versions of your LifeHub, Portfolio, Notes, Interview, and Railways projects. It does not route project cards to GitHub Pages.

## Design concept

The editable iOS/Android screen concept is in [Figma](https://www.figma.com/design/hl5NbR4aBUGDaeafAJMl73). The reviewed product direction, per-project workflows, security constraints and migration plan are documented in [docs/APP_DESIGN_CONCEPT.md](docs/APP_DESIGN_CONCEPT.md). For first-time platform setup and run commands, see [docs/MOBILE_BUILD_SETUP.md](docs/MOBILE_BUILD_SETUP.md).

## Current native implementation

- **Responsive dashboard:** mobile/tablet/desktop layouts, dark/light themes, favourites, categories, editable shortcuts, local storage and optional Supabase sync.
- **Animated search:** the search control expands smoothly from the app bar and filters the workspace list as you type. The toolbar adapts to narrow screens.
- **LifeHub:** native dashboard, Tasks, Notes, Goals, Reminders, Ideas, Finance transactions/budgets/reports, Splitwise groups/member balances/settlements, Profile, and permission-gated finance-category admin. It uses a server-verified SSO exchange and keeps the LifeHub session separate from the central ControlDeck session.
- **Portfolio:** native public portfolio view for profile, skills, projects, work experience, education, languages, and social links.
- **Portfolio Admin:** native admin sign-in and CRUD screens for languages, skills, projects, education, work experience, and social links, using the existing admin_login, admin_get_all, admin_upsert, admin_delete, and admin_logout database RPCs. The admin session token is stored in platform secure storage and revalidated by the backend on restore.
- **Notes:** native curriculum dashboard and search; language/topic browsing; JSON lesson rendering for heading, subheading, paragraph, code, lists, images, notes, tables and dividers; per-user lesson completion; profile/progress view; contact messages; signup/sign-in/password-reset request/change-password flows; and admin language/topic/lesson-content management. When the Notes schema is hosted in the ControlDeck Supabase project, it reuses the existing ControlDeck Auth session. A separate Notes project uses its existing `custom-auth` Edge Function and its own session.
- **Interview:** native sign-in and question catalogue backed by the Interview schema.
- **Railways:** native module map for My Data, Nangia, NR Dashboard, File Viewer, Approvals, Work Tracker, Administration, and Activity/History; secure data loading and role-aware workflows remain to be ported.

## Shared sign-in and security

The requested single sign-in is the intended product experience, but **full cross-project SSO is not complete yet**. A server-verified `controldeck-sso` Edge Function is deployed for LifeHub, and Notes can reuse the same Auth session when configured to the same Supabase project. Notes and other modules still enforce their own access flags. Interview, Portfolio, and Railways need their own trusted backend bridge before their separate login prompts can be removed. Current status and blockers are in [docs/SSO_IMPLEMENTATION_STATUS.md](docs/SSO_IMPLEMENTATION_STATUS.md). Do not hardcode passwords or commit service-role credentials.

## Important feature-parity status

This is a native Flutter migration in progress, not a claim that every React workflow has already been reproduced. LifeHub's core data workflows have now been ported to a native workspace; the original web chart/export presentation and email verification/reset screens are not pixel-for-pixel ports, and the native workflow still needs build and device testing. See [docs/LIFEHUB_NATIVE_INTEGRATION.md](docs/LIFEHUB_NATIVE_INTEGRATION.md). Notes has a native curriculum/auth/progress/contact/admin implementation, but its full admin activity-monitoring dashboard and native Excel/PDF export parity still need completion. Admin writes also require the server-enforced policies in `docs/NOTES_ADMIN_POLICIES.sql` to be applied in the Notes Supabase project. Build and device testing remains pending. Interview still needs registration, instructions, timed assessment, autosaved answers, submission/results, and admin reporting. The public Portfolio screen is read-only; its separate admin screen supports content management. Railways now has a native module map, but its source authentication and access model needs a server-side security migration before protected records can be exposed. These remaining workflows should be ported into Flutter screens and continue using each project's existing backend and access controls.

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

The native LifeHub workspace uses the LifeHub project's public publishable key and exchanges the verified ControlDeck session through `controldeck-sso`. Data requests carry the server-issued opaque LifeHub session as `x-lifehub-session`; the app never embeds the service-role key or a password. The original web app's custom-auth flow remains in its own repository.

### Notes and Interview

Notes defaults to the central ControlDeck Supabase project and reuses its authenticated client when both point to the same URL. Override the Notes URL/key only when its database is genuinely hosted in another project; a different Supabase project needs its own trusted SSO bridge and cannot accept the central JWT automatically.

Interview currently retains its own backend configuration and login RPC. Until an Interview-side SSO bridge is implemented and tested, do not assume that setting the same email alone creates a shared session.

When you need to configure a separate Notes or Interview backend, provide its public URL and publishable/anon key at run time rather than committing credentials:

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
