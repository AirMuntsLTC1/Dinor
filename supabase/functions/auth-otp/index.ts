
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function getAccessToken(supabase) {
  const { data } = await supabase.from('google_tokens').select('refresh_token').eq('id', 1).single()
  if (!data) throw new Error("No Google Refresh Token found in DB. Please authorize Gmail first.")

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
      client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
      refresh_token: data.refresh_token,
      grant_type: 'refresh_token',
    }),
  })
  const tokenData = await res.json()
  return tokenData.access_token
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { email, action, code } = await req.json()
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    if (action === 'send') {
      const otp = Math.floor(100000 + Math.random() * 900000).toString()
      await supabaseAdmin.from('otp_codes').upsert({ email, code: otp })

      const accessToken = await getAccessToken(supabaseAdmin)

      const emailContent = [
        `To: ${email}`,
        `Subject: Your Dinor Login Code`,
        `MIME-Version: 1.0`,
        `Content-Type: text/html; charset="UTF-8"`,
        ``,
        `<h2>Welcome to Dinor!</h2><p>Your login code is: <strong>${otp}</strong></p>`,
      ].join('\r\n')

      const encodedEmail = btoa(emailContent).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')

      const gmailRes = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ raw: encodedEmail }),
      })

      if (!gmailRes.ok) {
        const err = await gmailRes.text()
        throw new Error("Gmail API Error: " + err)
      }

      return new Response(JSON.stringify({ success: true, message: 'OTP sent' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (action === 'verify') {
      const { data: otpData } = await supabaseAdmin.from('otp_codes').select('code').eq('email', email).single()
      
      if (otpData && otpData.code === code) {
        // Code is correct! Create a real Supabase session.
        const { data: linkData, error } = await supabaseAdmin.auth.admin.generateLink({
          type: 'magiclink',
          email: email,
        })
        
        if (error) throw error
        
        await supabaseAdmin.from('otp_codes').delete().eq('email', email)

        return new Response(JSON.stringify({ success: true, session: linkData.properties }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      } else {
        return new Response(JSON.stringify({ success: false, error: 'Invalid or expired code' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    }

    return new Response(JSON.stringify({ error: 'Invalid action' }), { status: 400, headers: corsHeaders })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
