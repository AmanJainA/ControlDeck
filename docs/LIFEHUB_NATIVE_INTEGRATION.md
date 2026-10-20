# LifeHub native integration in ControlDeck

Updated: 20 October 2026.

## Entry point

The LifeHub tile now opens `LifeHubFullNativeScreen` from `lib/lifehub_workspace.dart`. It stays inside ControlDeck navigation and uses the existing LifeHub backend at `wrssvnvagpnvlwhnqqta.supabase.co`. It does not embed the LifeHub website or redirect to GitHub Pages.

## Native module coverage

- **Dashboard:** counts for tasks, goals, ideas, pending reminders, and transactions.
- **Life:** Tasks, Notes, Goals, Reminders, and Ideas with create, edit, delete, search, and supported status actions. Notes can be pinned; tasks and reminders can be completed; idea status can be advanced.
- **Finance:** income and expense entries, monthly budgets, transaction search, edit/delete, net cash flow summary, and spending-by-category report.
- **Splitwise:** groups, adding members by LifeHub email, shared expenses split equally among current group members, member balance calculation, and recording settlements.
- **Profile:** edit LifeHub display name and avatar; sign out revokes the LifeHub session and signs out of ControlDeck.
- **Admin:** finance category management is shown only when the LifeHub profile's existing `is_admin` permission is true.

## Identity and data boundaries

- Reuses the authenticated ControlDeck user to exchange for a server-issued LifeHub session through `controldeck-sso`.
- Stores the opaque LifeHub session in Flutter secure storage and sends it as `x-lifehub-session` to the LifeHub data API.
- Uses the active public/publishable API key for the LifeHub Supabase project. No service-role key or user password is embedded in Flutter.
- Reads and writes existing LifeHub tables. It does not migrate, rename, clear, or delete existing records.
- Existing server-side session checks and table policies remain the authorization boundary.

## Verification still required

The GitHub changes are committed, but the Flutter application has not been built or exercised on Android, iOS, tablet, and web in this session. Run `flutter pub get`, `flutter analyze`, and test each module using the verified ControlDeck account. In particular, confirm that the current Supabase policies allow the SSO session to read the LifeHub profile and that group-member relationship queries work in the target project.

This is a native feature port of the core LifeHub workflows, not a claim that every web-only detail (such as the original charting/export UI and custom-auth email-verification screens) has been reproduced pixel-for-pixel.
