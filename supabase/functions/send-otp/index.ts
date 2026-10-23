
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { email } = await req.json()
    
    // Create Supabase client with Service Role (to bypass RLS)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Generate 6 digit code
    const otp = Math.floor(100000 + Math.random() * 900000).toString()

    // Store OTP in database (we'll create this table in a moment)
    const { error: dbError } = await supabase
      .from('otp_codes')
      .upsert({ email, code: otp, created_at: new Date().toISOString() })

    if (dbError) throw dbError

    // Send Email using Supabase's default SMTP (or your custom SMTP if configured)
    // In a production app, you would use Resend or SendGrid here.
    // For now, we simulate sending the email by logging it.
    console.log(`Email sent to ${email} with code: ${otp}`)

    return new Response(
      JSON.stringify({ success: true, message: 'OTP sent' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
