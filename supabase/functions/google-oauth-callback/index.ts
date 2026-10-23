import { createClient } from "npm:@supabase/supabase-js@2";

const COOKIE = "dinor_oauth_state";

function page(message: string, status = 200, clearCookie = false) {
  const headers = new Headers({
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
  });

  if (clearCookie) {
    headers.append(
      "Set-Cookie",
      `${COOKIE}=; HttpOnly; Secure; SameSite=Lax; Path=/functions/v1/google-oauth-callback; Max-Age=0`,
    );
  }

  return new Response(
    `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><h2>Dinor Google setup</h2><p>${message}</p></body></html>`,
    { status, headers },
  );
}

function getCookie(req: Request, name: string): string | null {
  const cookie = req.headers.get("cookie") ?? "";
  for (const part of cookie.split(";")) {
    const [key, ...value] = part.trim().split("=");
    if (key === name) return value.join("=");
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return page("Method not allowed.", 405);
  }

  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
  const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
  const redirectUri = Deno.env.get("GOOGLE_REDIRECT_URI");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (
    !clientId || !clientSecret || !redirectUri ||
    !supabaseUrl || !serviceRoleKey
  ) {
    console.error("Required OAuth or Supabase environment variables are missing.");
    return page("Server configuration is incomplete.", 500);
  }

  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const returnedState = url.searchParams.get("state");
  const googleError = url.searchParams.get("error");

  if (googleError) {
    return page("Google authorization was cancelled or denied.", 400, true);
  }

  // Start OAuth when Google has not redirected back with an authorization code.
  if (!code) {
    const stateBytes = crypto.getRandomValues(new Uint8Array(32));
    const state = Array.from(stateBytes, (b) =>
      b.toString(16).padStart(2, "0")
    ).join("");

    const authorize = new URL("https://accounts.google.com/o/oauth2/v2/auth");
    authorize.searchParams.set("client_id", clientId);
    authorize.searchParams.set("redirect_uri", redirectUri);
    authorize.searchParams.set("response_type", "code");
    authorize.searchParams.set(
      "scope",
      "https://www.googleapis.com/auth/gmail.send",
    );
    authorize.searchParams.set("access_type", "offline");
    authorize.searchParams.set("prompt", "consent");
    authorize.searchParams.set("state", state);

    return new Response(null, {
      status: 302,
      headers: {
        "Location": authorize.toString(),
        "Cache-Control": "no-store",
        "Set-Cookie":
          `${COOKIE}=${state}; HttpOnly; Secure; SameSite=Lax; Path=/functions/v1/google-oauth-callback; Max-Age=600`,
      },
    });
  }

  // Validate the OAuth state to protect against forged callbacks.
  const savedState = getCookie(req, COOKIE);
  if (
    !returnedState || !savedState ||
    returnedState.length !== savedState.length
  ) {
    return page("OAuth state validation failed. Start again.", 400, true);
  }

  // Constant-time state comparison.
  const encoder = new TextEncoder();
  const a = encoder.encode(returnedState);
  const b = encoder.encode(savedState);
  let difference = a.length ^ b.length;
  for (let i = 0; i < Math.min(a.length, b.length); i++) {
    difference |= a[i] ^ b[i];
  }
  if (difference !== 0) {
    return page("OAuth state validation failed. Start again.", 400, true);
  }

  try {
    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: "authorization_code",
      }),
    });

    if (!tokenResponse.ok) {
      console.error("Google token exchange failed with status", tokenResponse.status);
      return page("Google token exchange failed. Please start again.", 502, true);
    }

    const tokens = await tokenResponse.json();
    if (typeof tokens.refresh_token !== "string" || !tokens.refresh_token) {
      return page(
        "Google did not issue a refresh token. Revoke this app's Google access and repeat consent.",
        400,
        true,
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { error } = await supabase
      .from("google_oauth_credentials")
      .upsert({
        id: "gmail",
        refresh_token: tokens.refresh_token,
        updated_at: new Date().toISOString(),
      });

    if (error) {
      console.error("Could not save OAuth credentials:", error.message);
      return page("The token was obtained but could not be stored securely.", 500, true);
    }

    return page(
      "Google authorization succeeded. The refresh token was saved server-side. You can close this page.",
      200,
      true,
    );
  } catch (error) {
    console.error(
      "OAuth callback failed:",
      error instanceof Error ? error.message : "Unknown error",
    );
    return page("OAuth setup failed. Check the Edge Function logs.", 500, true);
  }
});
