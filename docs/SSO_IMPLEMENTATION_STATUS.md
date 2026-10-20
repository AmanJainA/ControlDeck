# Single sign-on implementation status

Updated: 20 October 2026.

## Goal

Sign in once in ControlDeck, keep the session securely across app restarts, and let each module access only the data and actions its own backend authorizes. Keep existing project databases and records separate.

## Changes committed in this phase

- Added `flutter_secure_storage` for device-side storage of session tokens.
- LifeHub now saves the custom-auth session ID and the minimal profile data needed to restore its screen. It restores the session on reopening and continues to send the session ID in the `x-lifehub-session` header. The LifeHub backend remains responsible for validating the session.
- Portfolio Admin now saves its existing admin token in secure storage and attempts to restore it through the existing `admin_get_all` RPC. If the backend rejects the token, the app clears the saved token.
- Explicit sign-out removes the saved LifeHub or Portfolio Admin session token.

These changes prevent those two module sessions from being kept only in widget memory. They do **not** yet constitute single sign-on across every project.

## What is still required for true one-login SSO

| Module | Current authentication | Work required |
|---|---|---|
| ControlDeck | Supabase Auth; its session persistence is managed by `supabase_flutter` | Establish the canonical identity and account mapping for all module backends. |
| LifeHub | `custom-auth` Edge Function and server-issued session ID | Add a backend-verified session exchange from the canonical identity; do not trust a local profile alone. |
| Notes | Custom-auth/profile system in the `notes` schema | Add the same trusted identity/session validation and preserve Notes-specific permissions. |
| Interview | `interview.login_user` RPC | Replace profile-only client state with a backend-issued session or verified canonical identity. |
| Portfolio Admin | Separate `admin_login`/admin token RPCs | Add an explicit, server-validated SSO exchange while retaining admin-role checks. |
| Railways | Legacy user table and role-based workflows | Redesign the backend authorization first; do not bypass the existing role and record-level access rules. |

## Why the remaining bridge is not deployed in this commit

The connected Supabase account currently exposes the `p&l` project (`wrssvnvagpnvlwhnqqta`) and the separate `Railways` project (`drcxxbymdonyfjtkiouf`). The Portfolio client code also references a different Supabase project (`ixjdjvkktlzgiyojnsto`), which is not among the connected projects. Notes and Interview URLs are runtime configuration values. A secure SSO bridge cannot be completed safely until the correct backend project access, canonical account mapping, and per-project authorization entry points are confirmed.

No production table, user, password hash, or existing record was migrated or deleted as part of this phase.

## Security rules for the remaining work

1. Never store the user's password in local storage or use it as a reusable cross-project credential.
2. Never put a service-role key in Flutter or GitHub.
3. Treat local secure storage as token storage only; every protected operation must still be validated by the backend.
4. Preserve per-module authorization and database boundaries. A Notes operation must not mutate LifeHub, Interview, Portfolio, or Railways data.
5. Use explicit sign-out/revocation and server-side expiry. Do not treat a locally cached profile as proof of authentication.
6. Test session expiry, revoked sessions, unauthorized roles, and cross-module data isolation before declaring SSO complete.
