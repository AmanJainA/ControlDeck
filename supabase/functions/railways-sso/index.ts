import { createClient } from "npm:@supabase/supabase-js@2";

// This function is deployed to the Railways Supabase project. Its service-role
// key is supplied by Supabase at runtime and is never exposed to the client.
const RAILWAYS_URL = Deno.env.get("SUPABASE_URL")!;
const RAILWAYS_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Public publishable key: used only to validate the ControlDeck bearer token
// against ControlDeck Auth. It is not a service-role credential.
const CONTROLDECK_URL = "https://wrssvnvagpnvlwhnqqta.supabase.co";
const CONTROLDECK_PUBLISHABLE_KEY = "sb_publishable_AEu-JBRYrCLYrVq3VjAtyA_ya5ApyuM";

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
  if (!authorization.startsWith("Bearer ")) {
    return json({ error: "Sign in to ControlDeck first." }, 401);
  }

  let body: { app?: unknown; action?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body." }, 400);
  }

  if (String(body.app || "").toLowerCase() !== "railways") {
    return json({ error: "This function is only for the Railways module." }, 400);
  }
  const action = String(body.action || "exchange").toLowerCase();
  if (action !== "exchange" && action !== "logout") {
    return json({ error: "Unknown action." }, 400);
  }

  const controlDeck = createClient(CONTROLDECK_URL, CONTROLDECK_PUBLISHABLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authResult, error: authError } = await controlDeck.auth.getUser(authorization.slice(7));
  const controlDeckUser = authResult.user;
  const email = controlDeckUser?.email?.trim().toLowerCase();

  if (authError || !controlDeckUser || !email || !controlDeckUser.email_confirmed_at) {
    return json({ error: "Your ControlDeck session is invalid or your email is not verified. Sign in again." }, 401);
  }

  // Explicit account link; do not create a duplicate Railway account.
  const railwayEmailByControlDeckEmail: Record<string, string> = {
    "amanjain033@gmail.com": "aman.jain@nangia.co.in",
  };
  const railwayEmail = railwayEmailByControlDeckEmail[email];
  if (!railwayEmail) {
    return json({ error: "This ControlDeck account is not linked to an existing Railways account." }, 403);
  }
  if (action === "logout") return json({ ok: true, action: "logout" });

  const railwayAdmin = createClient(RAILWAYS_URL, RAILWAYS_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: railwayUser, error: railwayLookupError } = await railwayAdmin
    .from("users")
    .select("id,username,email,role,dept,project")
    .ilike("email", railwayEmail)
    .maybeSingle();

  if (railwayLookupError) {
    console.error("[railways-sso] account lookup failed", { code: railwayLookupError.code });
    return json({ error: "Could not verify the existing Railways account." }, 500);
  }
  if (!railwayUser) {
    return json({ error: "The mapped Railways account was not found. No Railway data or permissions were changed." }, 403);
  }

  return json({
    ok: true,
    app: "railways",
    user: {
      id: railwayUser.id,
      username: railwayUser.username,
      email: railwayUser.email,
      role: railwayUser.role,
      dept: railwayUser.dept,
      project: railwayUser.project,
    },
    controlDeckUserId: controlDeckUser.id,
  });
});
