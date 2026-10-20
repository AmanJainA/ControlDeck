# ControlDeck

ControlDeck is a cross-platform Flutter workspace that gives LifeHub, Notes, Railways, Interview, and Portfolio dedicated connection cards. It starts as a UI/UX hub: no project repository URLs or deployment destinations are prefilled. Add the actual app or admin destination yourself when you are ready.

## What it includes

- Responsive desktop, tablet, and mobile dashboard
- Dark/light themes with an olive accent
- Search, category filters, favourites, and app shortcut management
- Dedicated, initially unconnected cards for LifeHub, Notes, Railways, Interview, and Portfolio
- Visible Connected / Not connected states and a Connect action on each card
- Separate Portfolio admin destination field; the admin destination can be configured independently
- No GitHub repository URLs or guessed deployment URLs are prefilled
- Supabase email/password authentication and per-user cloud-synced shortcuts
- Row Level Security so signed-in users can only access their own ControlDeck shortcuts
- Local-only mode when Supabase is not configured

## Supabase setup

ControlDeck uses its own table named `public.controldeck_apps`. This table stores shortcut metadata and URLs; it does **not** import or grant access to the private data in your other apps.

1. Select a dedicated Supabase project for ControlDeck.
2. Open that project's **SQL Editor**.
3. Run the complete script in [`supabase/controldeck_schema.sql`](supabase/controldeck_schema.sql).
4. In Supabase Authentication, enable Email authentication. Configure email confirmation according to your preference.
5. Copy the project's **Project URL** and **publishable key** (or legacy anon key). Never use a service-role or secret key in the Flutter app.
6. From the repository root, run the app with the values supplied at build/run time:

```bash
flutter pub get
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

For Chrome, replace `-d macos` with `-d chrome`. For another device, use its Flutter device ID. The URL and publishable/anon key are client configuration; access is restricted by Supabase Auth and RLS. Do not put a service-role key in the app or commit secrets to GitHub.

When the app is launched without both compile-time values, it runs in local mode and stores shortcuts on that device only. With Supabase configured, sign in or create an account and shortcuts sync to the account. On first launch, all five project cards are intentionally marked **Not connected** until you add your own destinations.

## Configure the Portfolio admin shortcut

Open ControlDeck, choose the Portfolio card menu, select **Edit shortcut**, and enter the actual **Admin URL** for your Portfolio admin login/dashboard. You can leave **App URL** blank if you only want to configure the admin destination. Save, then use the admin icon on the Portfolio card. No destination is guessed or prefilled. ControlDeck stores the destination only; it does not grant admin rights.

## Run locally

```bash
flutter pub get
flutter run
```

To run in Chrome:

```bash
flutter run -d chrome
```

## Security and integration boundary

- ControlDeck's RLS policy scopes shortcut rows to the authenticated user.
- Each linked website retains its own login, roles, and access controls.
- Connecting a shortcut does not automatically connect that app's database. If you want data from an individual app inside ControlDeck, integrate that app through a documented API or a separately secured backend endpoint; never place a database service-role key in the Flutter client.
- The SQL script is intended for a dedicated ControlDeck Supabase project. Do not run it in another project's database unless you explicitly want the ControlDeck table hosted there.

## Repository structure

- `lib/main.dart` — dashboard, sign-in, and shortcut management
- `pubspec.yaml` — Flutter dependencies
- `supabase/controldeck_schema.sql` — table and RLS setup
- `analysis_options.yaml` — Dart lint configuration


## Native project workspaces

ControlDeck opens project screens inside Flutter; it does not navigate to GitHub Pages.

- **LifeHub**: uses the LifeHub custom-auth function and displays the signed-in user's task list with quick task creation.
- **Portfolio**: reads the live public portfolio profile, skills, projects, experience, education, and social-link records from the `portfolio` schema.
- **Notes**: browses the database-driven languages, topics, and JSON lesson content from the `notes` schema.
- **Interview**: uses the `interview.login_user` RPC for sign-in and displays the assessment question catalogue.
- **Railways**: opens a native workspace surface for Railway workflows.

### Notes and Interview database configuration

Those two React projects intentionally keep their Supabase URL and public anon key in local environment variables rather than committing them. Supply the same project values when running ControlDeck:

```bash
flutter run -d macos \
  --dart-define=NOTES_SUPABASE_URL=https://YOUR-NOTES-PROJECT.supabase.co \
  --dart-define=NOTES_SUPABASE_ANON_KEY=YOUR_NOTES_ANON_KEY \
  --dart-define=INTERVIEW_SUPABASE_URL=https://YOUR-INTERVIEW-PROJECT.supabase.co \
  --dart-define=INTERVIEW_SUPABASE_ANON_KEY=YOUR_INTERVIEW_ANON_KEY
```

For Android/iOS builds, pass the same `--dart-define` values to the relevant `flutter build` command. Use the public anon/publishable keys only; never put a service-role key in a client app.

The Flutter interfaces are a native implementation based on each repository's current `main` branch, not a WebView of the deployed React pages. Some advanced React workflows (including the full timed assessment and admin CRUD flows) still need to be ported into native Flutter screens.
