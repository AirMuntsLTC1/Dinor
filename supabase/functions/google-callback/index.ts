
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get('code')

  if (!code) return new Response("No code provided", { status: 400 })

  const clientId = Deno.env.get('GOOGLE_CLIENT_ID')
  const clientSecret = Deno.env.get('GOOGLE_CLIENT_SECRET')
  const redirectUri = Deno.env.get('SUPABASE_URL') + '/functions/v1/google-callback'

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: clientId!,
      client_secret: clientSecret!,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code',
    }),
  })

  const data = await res.json()

  if (data.refresh_token) {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // Save the refresh token to the database
    await supabase.from('google_tokens').upsert({ id: 1, refresh_token: data.refresh_token })
    
    return new Response("<h1>Success! You can close this window and return to the app.</h1>", {
      headers: { "Content-Type": "text/html" },
    })
  }

  return new Response(`<h1>Error</h1><pre>${JSON.stringify(data, null, 2)}</pre>`, {
    headers: { "Content-Type": "text/html" },
  })
})
