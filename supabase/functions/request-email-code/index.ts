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

function base64Url(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "POST required" });
  if (!req.headers.get("apikey")) return reply(401, { error: "Missing API key" });

  try {
    const body = await req.json();
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";

    if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return reply(400, { error: "Enter a valid email address." });
    }

    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const googleClientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const googleClientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");

    if (!url || !serviceKey || !googleClientId || !googleClientSecret) {
      console.error("Required server secrets are missing.");
      return reply(500, { error: "Email login is not configured." });
    }

    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // Limit each address to one request per minute and five per hour.
    const now = Date.now();
    const { data: limit, error: limitError } = await admin
      .from("email_code_rate_limits")
      .select("last_sent_at, window_started_at, request_count")
      .eq("email", email)
      .maybeSingle();

    if (limitError) throw limitError;

    if (limit) {
      const last = Date.parse(limit.last_sent_at);
      const start = Date.parse(limit.window_started_at);
      if (now - last < 60_000) {
        return reply(429, { error: "Please wait a minute before requesting another code." });
      }
      if (now - start < 3_600_000 && Number(limit.request_count) >= 5) {
        return reply(429, { error: "Too many requests. Try again in an hour." });
      }

      const resetWindow = now - start >= 3_600_000;
      const { error } = await admin.from("email_code_rate_limits").update({
        last_sent_at: new Date(now).toISOString(),
        window_started_at: resetWindow ? new Date(now).toISOString() : limit.window_started_at,
        request_count: resetWindow ? 1 : Number(limit.request_count) + 1,
      }).eq("email", email);
      if (error) throw error;
    } else {
      const { error } = await admin.from("email_code_rate_limits").insert({
        email,
        last_sent_at: new Date(now).toISOString(),
        window_started_at: new Date(now).toISOString(),
        request_count: 1,
      });
      if (error) throw error;
    }

    // Generate a Supabase Auth OTP, not an independent custom password.
    const { data: linkData, error: linkError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
    });

    // Avoid revealing whether an account exists.
    if (linkError || !linkData?.properties?.email_otp) {
      return reply(200, {
        message: "If an eligible account exists, a sign-in code will be sent.",
      });
    }

    const { data: credential, error: credentialError } = await admin
      .from("google_oauth_credentials")
      .select("refresh_token")
      .eq("id", "gmail")
      .single();

    if (credentialError || !credential?.refresh_token) {
      console.error("Gmail refresh token is unavailable.");
      return reply(500, { error: "Email delivery is not configured." });
    }

    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: googleClientId,
        client_secret: googleClientSecret,
        refresh_token: credential.refresh_token,
        grant_type: "refresh_token",
      }),
    });

    const tokenData = await tokenResponse.json();
    if (!tokenResponse.ok || !tokenData.access_token) {
      console.error("Google access-token refresh failed.");
      return reply(502, { error: "Gmail authorization failed. Reconnect Gmail." });
    }

    const mime = [
      `To: ${email}`,
      "Subject: Your Dinor sign-in code",
      "MIME-Version: 1.0",
      "Content-Type: text/plain; charset=UTF-8",
      "",
      `Your Dinor six-digit sign-in code is: ${linkData.properties.email_otp}`,
      "",
      "Enter this code in the Dinor app to sign in.",
      "If you did not request this code, you can ignore this email.",
    ].join("\r\n");

    const gmailResponse = await fetch(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${tokenData.access_token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ raw: base64Url(mime) }),
      },
    );

    if (!gmailResponse.ok) {
      console.error("Gmail API send failed:", gmailResponse.status);
      return reply(502, { error: "Could not send the code. Please try again later." });
    }

    return reply(200, {
      message: "If an eligible account exists, a sign-in code will be sent.",
    });
  } catch (error) {
    console.error("request-email-code failed:", error);
    return reply(500, { error: "Could not request a sign-in code." });
  }
});


============================================================
