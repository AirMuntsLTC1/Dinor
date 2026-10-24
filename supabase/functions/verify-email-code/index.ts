import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "POST required" });

  // The Flutter client supplies its public Supabase key in the apikey header.
  const apiKey = req.headers.get("apikey");
  if (!apiKey) return reply(401, { error: "Missing API key" });

  try {
    const body = await req.json();
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const code = typeof body.code === "string" ? body.code.trim() : "";

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
        !/^\d{8}$/.test(code)) {
      return reply(400, { error: "Enter a valid email and six-digit code." });
    }

    const url = Deno.env.get("SUPABASE_URL");
    if (!url) return reply(500, { error: "Authentication is not configured." });

    // Let Supabase Auth validate its own OTP and issue the real session.
    const response = await fetch(`${url}/auth/v1/verify`, {
      method: "POST",
      headers: {
        apikey: apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email,
        token: code,
        type: "magiclink",
      }),
    });

    const result = await response.json();

    if (!response.ok || !result.access_token || !result.refresh_token) {
      return reply(401, { error: "The code is invalid or expired. Request a new code." });
    }

    // These are session credentials intended for the authenticated client.
    return reply(200, {
      access_token: result.access_token,
      refresh_token: result.refresh_token,
      token_type: result.token_type,
      expires_in: result.expires_in,
      user: result.user,
    });
  } catch (error) {
    console.error("verify-email-code failed:", error);
    return reply(500, { error: "Could not verify the code." });
  }
});


============================================================
