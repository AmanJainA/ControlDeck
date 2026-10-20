# Single sign-on implementation status

Updated: 20 October 2026.

## Goal

Sign in once in ControlDeck, keep the session securely across app restarts, and let each module access only the data and actions its own backend authorizes. Keep existing project databases and records separate.

## Changes committed in this phase

- Added `flutter_secure_storage` for device-side storage of session tokens.
- Added and deployed the `controldeck-sso` Edge Function to the `p&l` Supabase project. It verifies the ControlDeck Supabase Auth access token server-side and resolves the authenticated email against the target module's existing profile; it does not trust a client-supplied email.
- LifeHub exchanges the existing ControlDeck session for a server-validated LifeHub session. Its existing `x-lifehub-session` validation remains in place. Valid unexpired LifeHub sessions are reused where possible.
- Notes uses the canonical Supabase client when its configured URL is the ControlDeck project and now calls `controldeck-sso` to validate the Notes profile and `notes_enabled` flag before opening the native curriculum. The native module includes lesson progress, contact, account recovery actions, admin curriculum editing, and a basic activity monitor. Separate Notes-project configuration still uses the existing Notes `custom-auth` function; cross-project SSO is not claimed.
- Global ControlDeck sign-out attempts to revoke the current LifeHub session, ends the Portfolio Admin token through its existing logout RPC, clears locally stored module tokens, and signs out of Supabase Auth.
- Portfolio Admin token persistence remains a compatibility measure; it is not yet authenticated by the shared identity.

This is an incremental SSO and native-workspace integration, **not** complete single sign-on across all five projects. No existing profile, permission flag, password hash, or business record was migrated or deleted.

## What is still required for true one-login SSO

| Module | Current authentication | Work required |
|---|---|---|
| ControlDeck | Supabase Auth; its session persistence is managed by `supabase_flutter` | Canonical identity is the ControlDeck Auth user. The account must be email-verified. |
| LifeHub | `custom-auth` Edge Function and server-issued session ID | Shared-session exchange is implemented. The native ControlDeck workspace now includes Life, Finance, Splitwise, Profile, and admin-category screens; see `docs/LIFEHUB_NATIVE_INTEGRATION.md`. Runtime/build verification remains pending. |
| Notes | Shared ControlDeck Auth + `controldeck-sso` when co-located; Notes `custom-auth` when configured separately | The native curriculum, content renderer, progress, contact, account and admin workflows are integrated. A separate Notes project still needs an explicit trusted token bridge for one-login SSO. Existing `notes_enabled` flags are not automatically changed. |
| Interview | `interview.login_user` RPC | Replace profile-only client state with a backend-issued session or verified canonical identity. |
| Portfolio Admin | Separate `admin_login`/admin token RPCs | Add an explicit, server-validated SSO exchange while retaining admin-role checks. |
| Railways | Legacy user table and role-based workflows | Redesign the backend authorization first; do not bypass the existing role and record-level access rules. |

## Why the remaining bridge is not deployed in this commit

The connected Supabase account currently exposes the `p&l` project (`wrssvnvagpnvlwhnqqta`) and the separate `Railways` project (`drcxxbymdonyfjtkiouf`). The Portfolio client code references `ixjdjvkktlzgiyojnsto`, which is not among the connected projects. Interview and Notes URLs are runtime configuration values; Notes can share the canonical session when configured to the `p&l` project. Interview, Portfolio, and Railways still require backend-specific token exchange or secure proxy work before their separate login prompts can be removed. Do not pass the ControlDeck JWT directly to a different Supabase project, because that project cannot automatically validate it.

No production table, user, password hash, or existing record was migrated or deleted as part of this phase.

## Security rules for the remaining work

1. Never store the user's password in local storage or use it as a reusable cross-project credential.
2. Never put a service-role key in Flutter or GitHub.
3. Treat local secure storage as token storage only; every protected operation must still be validated by the backend.
4. Preserve per-module authorization and database boundaries. A Notes operation must not mutate LifeHub, Interview, Portfolio, or Railways data.
5. Use explicit sign-out/revocation and server-side expiry. Do not treat a locally cached profile as proof of authentication.
6. Test session expiry, revoked sessions, unauthorized roles, and cross-module data isolation before declaring SSO complete.
