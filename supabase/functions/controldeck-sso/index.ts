import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = req.headers.get("Authorization") || "";
  if (!authorization.startsWith("Bearer ")) return json({ error: "Sign in to ControlDeck first." }, 401);

  let body: { app?: unknown; page?: unknown; action?: unknown; sessionId?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  const action = String(body.action || "exchange").toLowerCase();
  const app = String(body.app || "").toLowerCase();
  if (app !== "lifehub" && app !== "notes") {
    return json({ error: "This module is not configured for shared sign-in yet." }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authResult, error: authError } = await admin.auth.getUser(authorization.slice(7));
  const user = authResult.user;
  const email = user?.email?.trim().toLowerCase();

  if (authError || !user || !email || !user.email_confirmed_at) {
    return json({ error: "Your ControlDeck session is invalid or your email is not verified. Sign in again." }, 401);
  }

  const profileQuery = app === "lifehub"
    ? admin.schema("public").from("profiles")
        .select("id, full_name, email, email_verified, is_active, account_status")
    : admin.schema("notes").from("profiles")
        .select("id, full_name, email, email_verified, account_status, notes_enabled");
  const { data: profile, error: profileError } = await profileQuery
    .ilike("email", email)
    .maybeSingle();

  if (profileError) {
    console.error("[controldeck-sso] profile lookup failed", { app, code: profileError.code });
    return json({ error: "Could not verify your access to this module." }, 500);
  }
  if (!profile || profile.email_verified !== true ||
      profile.is_active === false || profile.account_status === "blocked" ||
      (app === "notes" && profile.notes_enabled !== true)) {
    return json({ error: "This email does not have an active, verified, enabled profile for this module. Existing module permissions were not changed." }, 403);
  }

  if (action === "logout") {
    if (app === "lifehub") {
      const sessionId = String(body.sessionId || "");
      if (sessionId) {
        const { error: revokeError } = await admin.from("app_sessions")
          .update({ revoked_at: new Date().toISOString() })
          .eq("id", sessionId)
          .eq("app", "lifehub")
          .eq("user_id", profile.id);
        if (revokeError) return json({ error: "Could not revoke the LifeHub session." }, 500);
      }
    }
    return json({ ok: true, action: "logout" });
  }
  if (action !== "exchange") return json({ error: "Unknown action." }, 400);

  if (app === "notes") {
    if (profile.id !== user.id) {
      return json({
        error: "The Notes profile exists but is not linked to the shared ControlDeck identity. No data was changed.",
        needsAccountLink: true,
      }, 409);
    }
    return json({
      ok: true,
      app,
      profile: { id: profile.id, full_name: profile.full_name, email: profile.email },
      authUserId: user.id,
    });
  }

  const { data: existingSession, error: existingSessionError } = await admin
    .from("app_sessions")
    .select("id, activity_session_id, expires_at")
    .eq("app", "lifehub")
    .eq("user_id", profile.id)
    .is("revoked_at", null)
    .gt("expires_at", new Date().toISOString())
    .order("expires_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existingSessionError) {
    console.error("[controldeck-sso] session lookup failed", { code: existingSessionError.code });
    return json({ error: "Could not check your existing LifeHub session." }, 500);
  }

  if (existingSession) {
    return json({
      ok: true,
      app,
      sessionId: existingSession.id,
      activitySessionId: existingSession.activity_session_id,
      expiresAt: existingSession.expires_at,
      profile: { id: profile.id, full_name: profile.full_name, email: profile.email },
    });
  }

  const sessionId = crypto.randomUUID();
  const activitySessionId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const { error: sessionError } = await admin.from("app_sessions").insert({
    id: sessionId,
    app: "lifehub",
    user_id: profile.id,
    activity_session_id: activitySessionId,
    expires_at: expiresAt,
  });

  if (sessionError) {
    console.error("[controldeck-sso] session creation failed", { code: sessionError.code });
    return json({ error: "Could not start the LifeHub session. Please try again." }, 500);
  }

  return json({
    ok: true,
    app,
    sessionId,
    activitySessionId,
    expiresAt,
    profile: { id: profile.id, full_name: profile.full_name, email: profile.email },
  });
});
