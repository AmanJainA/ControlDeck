# ControlDeck — native app design concept

Figma concept: https://www.figma.com/design/hl5NbR4aBUGDaeafAJMl73

## Product direction

ControlDeck is one native Flutter app for iOS and Android. It is not a collection of WebViews and it must not send users to the projects' GitHub Pages sites. Shared app chrome, navigation, search, accessibility, loading states and design tokens belong to ControlDeck; each workspace keeps its domain-specific workflows and data service.

## Visual system

- Dark-first, with a deliberate light theme; deep navy/charcoal surfaces, soft borders, generous spacing, restrained lime accent, and a distinct but coordinated accent for each workspace.
- Inter as the Figma concept typeface. In Flutter, prefer a bundled font only if the repository adds the font asset and licence; otherwise use platform-safe theme typography.
- Rounded cards, 48px+ touch targets, clear hierarchy, accessible contrast, and minimal decorative effects.
- Bottom navigation on phones; adaptive rail/sidebar and multi-column layouts on larger tablets and desktop.
- Search expands smoothly from the top app bar and filters the app catalogue as the user types.
- All screen content is editable Figma text and vector shapes, not a flattened screenshot.

## Screens included in the concept

1. **Sign in** — shared entry point, email/password, secure-session explanation.
2. **Workspace home** — animated search, five workspaces, favourites and navigation.
3. **LifeHub** — daily summary, tasks and quick access to life-management areas.
4. **Notes** — curriculum search, language catalogue and lesson progression.
5. **Interview** — assessment overview, question progress, answer options and continuation action.
6. **Railways** — role-aware modules for data, documents, approvals and work tracking.
7. **Portfolio** — profile, expertise and selected projects.

## Source review and workspace mapping

### LifeHub

The React app has a dashboard, Life, Finance, Splitwise, Profile and Admin areas. Life contains Tasks, Notes, Goals, Reminders and Ideas. Finance includes expenses, budgets, categories and reports. Splitwise includes groups, members and expense sharing. Authentication is implemented through a custom-auth Edge Function and session headers; a Flutter migration must preserve that protocol rather than assume normal Supabase Auth.

### Notes

The React app is a database-driven curriculum: languages, topics and JSON lesson content. It includes login, signup, email verification, password recovery/reset, protected routes, lesson layouts, page tracking and an admin dashboard. The custom-schema client targets `notes`; the Flutter app must preserve its actual auth implementation, RLS expectations and lesson block types.

### Interview

The React app uses the `interview` schema and custom RPC authentication. User workflows include registration, a home/dashboard, assessment instructions, timed attempts, saved answers, submission and a thank-you/results flow. Admin workflows include dashboard, results, activity tracking, users, questions, content, instructions and settings. The current Flutter question catalogue is not feature parity.

### Railways

The React app is a role-aware portal using public Supabase configuration and tables for users, folders, headings, menus, uploads and data collection. Main areas include dashboard, My Data, Nangia, NR data dashboards, dynamic menu displays, file viewing, upload management, approvals, folder/menu administration, user profiles, page activity, login history, tracking and work tracking. Its login currently queries a `users` table using username/password and stores role/session values client-side. A secure Flutter migration must not reproduce plaintext-password checks or treat client-side role values as trusted authorization; use backend-enforced access policies and preserve the existing role/heading/menu access rules.

### Portfolio

The React app renders profile, skills, languages, projects, education, experience and social links from the `portfolio` schema, with animated presentation and rich-text handling. The repo also includes a separate admin interface. Flutter should use native scrolling, cards and safe rich-text rendering, and keep admin RPCs protected.

## Shared sign-in: important backend dependency

The desired experience is one ControlDeck sign-in. The existing apps do not share one identity provider: LifeHub, Notes, Interview and Railways have different authentication/session designs, and Portfolio has its own admin token RPC. A single login screen alone cannot safely create SSO. A production implementation needs a central identity provider plus a server-side token exchange/authorization design for each project, or an explicitly provisioned common identity and supported session bridge. Never hardcode the supplied password in source code, and never put Supabase service-role keys in the mobile app. The ControlDeck Supabase Auth sign-in is the intended front door, but it must not imply that the other project backends are authenticated until the bridge is implemented.

## Migration phases

1. **Foundation:** design system, secure sign-in/session, adaptive navigation, route guards, loading/error/empty states, connection configuration, tests.
2. **Portfolio and Notes:** read-only public content first; then full Notes auth, curriculum, progress, recovery and admin workflows.
3. **LifeHub:** port custom-auth correctly, then tasks/notes/goals/reminders/ideas, Finance/reports, Splitwise, profile and admin.
4. **Interview:** login/register, instructions, durable timed attempts, answer autosave, submission/results and admin operations.
5. **Railways:** role-aware menus and assigned data, secure document viewing, downloads/exports, approvals, tracking and administration. Validate every database operation and permission before claiming parity.
6. **Verification:** run `flutter analyze`, widget/unit tests, iOS simulator and Android emulator builds, and test real backend access on both platforms.

## Current implementation status

The existing ControlDeck main branch already has a responsive dashboard, animated search, native Portfolio/Portfolio Admin screens, a basic Notes browser, basic Interview sign-in/question catalogue, and a basic LifeHub task flow. Railways is currently a placeholder. These are useful foundations, not complete ports of the five React applications. A Flutter SDK build/analyze run has not yet been confirmed in this environment.
