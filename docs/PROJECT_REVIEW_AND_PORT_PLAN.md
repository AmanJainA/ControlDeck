# ControlDeck — source review and native migration plan

Reviewed on 20 October 2026 against the `main` branches of Notes, Railways, LifeHub, Interview, Portfolio and ControlDeck.

## Product contract

- One Flutter application for iOS and Android; no project card should launch a GitHub Pages website or wrap the React app in a WebView.
- Keep one consistent app shell, search, theme, adaptive navigation, error/loading/empty states and accessibility.
- Preserve each source project's domain rules and backend data. A screen is not considered ported just because its title or a module card exists.
- The requested email can be prefilled in the sign-in UI. The password must be entered at sign-in and must not be hardcoded in Dart, SQL, a workflow, or a repository secret-free config.

## Source review

| Project | Source-backed areas | Current native status | Remaining parity work |
|---|---|---|---|
| LifeHub | Dashboard; Life (tasks, notes, goals, reminders, ideas); Finance (expenses, budgets, reports); Splitwise groups/settlements; profile; admin; custom-auth Edge Function/session header | Custom-auth sign-in and task list/add; task completion and delete controls now added | Secure session persistence/refresh/logout; full CRUD for each Life tab; finance charts/reports; Splitwise; profile/admin; exports and search |
| Notes | Language catalogue; topics; JSON lesson blocks; progress; signup/login; email verification; password recovery; page tracking; admin dashboard | Native language/topic/lesson browser and renderer for code, lists, images, notes, tables and dividers | Port the Notes custom-auth/session protocol, registration/recovery, progress writes, page tracking, protected/admin routes and export features |
| Interview | Custom `interview.login_user` RPC; registration; company information/instructions; question catalogue; timed attempts; answer autosave; submission/thank-you; admin results/users/content/tracking | Native login and question catalogue | Registration; instructions; attempt creation/resume; durable timer; answer upsert/autosave; safe server-side scoring/submission; results; admin workflows |
| Portfolio | Profile, languages, skills, projects, education, experience, social links; rich text; separate admin | Native public content view and separate admin RPC screens | Validate all table/field mappings and rich text, protected admin session lifecycle, full CRUD form validation, image handling and accessibility |
| Railways | Username/password table flow; role-specific headings/menus; My Data; Nangia; NR dashboard; dynamic display; viewer; uploads/approvals; folder/menu administration; user profiles; page/login history; tracking; work tracker | Native module map only | Secure authentication/authorization redesign first; then assigned data, menus, document viewing/download/export, approvals, work tracker and admin modules |

## Authentication and security blockers

The five projects do not share a single identity provider today:

- ControlDeck uses Supabase Auth.
- LifeHub uses a custom-auth Edge Function and a session header.
- Notes has its own custom-auth/session flow and protected learning/admin pages.
- Interview uses custom RPCs against its own `interview.users` table.
- Railways has a separate users table and stores role/session flags client-side.
- Portfolio admin uses dedicated admin RPCs.

Therefore, the same email/password entered once in ControlDeck does not automatically create valid sessions in those four other backends. A proper single sign-on requires a server-side token exchange or migration to a common identity provider, plus backend-enforced authorization in every project. Do not fake SSO by treating a local Boolean/profile as proof of access, and do not ship service-role keys in a mobile app.

Before releasing Railways or Interview admin/user workflows, review and harden the source database policies and server-side authorization. A publishable/anon key is not an authorization boundary.

## Release gates

1. Flutter analyze and widget tests pass.
2. Android debug APK builds.
3. iOS simulator build succeeds.
4. Each configured backend is tested with real permitted and denied accounts.
5. Session expiry, logout, offline/error states, duplicate submissions, and app restart are tested.
6. Feature parity is documented honestly until each workflow is ported and verified.
