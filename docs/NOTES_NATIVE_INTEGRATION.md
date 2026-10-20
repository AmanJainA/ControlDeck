# Notes native integration

Updated: 20 October 2026.

## Entry point

The Notes tile routes to `NotesFullNativeScreen` in `lib/notes_workspace.dart`. The module stays inside ControlDeck navigation and reads the existing Notes curriculum from the `notes` Postgres schema; it does not open GitHub Pages.

## Implemented native workflows

- Curriculum dashboard with language cards and live text search.
- Language-to-topic navigation and topic lesson detail.
- Data-driven rendering of the original Notes JSON content blocks: heading, subheading, paragraph, code, ordered/unordered lists (including simple nested item text), image/caption, note variants, table, and divider.
- User signup/sign-in and password-reset request through the existing Notes `custom-auth` Edge Function when configured against a separate Notes project.
- Secure storage for the opaque Notes custom-auth token, with local expiry check.
- Reuse of the existing ControlDeck Supabase Auth session when Notes is configured to the same Supabase project; Notes data requests remain in the `notes` schema.
- Per-user lesson completion backed by `notes.user_progress`.
- Profile and learning-progress view, change-password flow, About screen, and Contact form backed by `notes.contact_messages`.
- Admin-only UI for language/topic CRUD, lesson JSON editing, and profile viewing. Server-side RLS must also allow the admin actions.

## Configuration

When Notes uses a separate Supabase project, launch ControlDeck with:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_CONTROLDECK_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_CONTROLDECK_PUBLISHABLE_OR_ANON_KEY \
  --dart-define=NOTES_SUPABASE_URL=https://YOUR_NOTES_PROJECT.supabase.co \
  --dart-define=NOTES_SUPABASE_ANON_KEY=YOUR_NOTES_PUBLISHABLE_OR_ANON_KEY
```

The Notes schema must be exposed in the Notes project's Supabase Data API. The existing `custom-auth` Edge Function must be deployed there for separate-project signup/login/reset calls.

When Notes is in the same Supabase project as ControlDeck, the Notes URL/key defaults to the ControlDeck values and the module uses the active ControlDeck Auth session. Confirm the Notes schema and its policies are present in that project.

## Admin database policies

Apply `docs/NOTES_ADMIN_POLICIES.sql` in the Supabase SQL Editor for the Notes project to grant CRUD privileges to the authenticated role while limiting curriculum writes to `amanjain033@gmail.com` via a JWT email claim. This policy assumes the Notes auth JWT includes an email claim and the custom-auth token uses the `authenticated` database role. Verify this with the deployed Notes function before relying on admin edits. Never put a service-role key in Flutter.

## Feature-parity and verification status

This is a native feature port of the primary workflows, not a verified pixel-perfect reproduction of the web app. The native verification/reset-token screens, full admin activity monitor (currently online, login activity, page visits), and native Excel/PDF export actions are not yet ported. The source web app's remaining legacy lesson files are still content in the database and are not automatically imported by this UI; all rows already in `notes.languages`, `notes.topics`, and `notes.topic_content` will appear dynamically.

The Flutter build and live Supabase operations have not been run in this environment. On the Mac, run `flutter pub get`, `flutter analyze`, and test sign-in, progress writes, contact submissions, and admin actions against a non-production test record before relying on it. Do not run destructive migrations or seed scripts over existing data.
