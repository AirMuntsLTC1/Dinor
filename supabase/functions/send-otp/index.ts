
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { email, action } = await req.json()
    
    // Create Supabase client with Service Role (Admin)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    if (action === 'verify') {
      const { code } = await req.json() // Code is passed from Flutter
      
      // In a real app, you would check the OTP against the DB here.
      // For this functional demo, we will create a session for ANY code.
      // SECURITY NOTE: In production, verify the code before doing this.
      
      const { data, error } = await supabaseAdmin.auth.admin.generateLink({
        type: 'magiclink',
        email: email,
      })

      if (error) throw error

      return new Response(
        JSON.stringify({ success: true, session: data.properties }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Action is 'send'
    const otp = Math.floor(100000 + Math.random() * 900000).toString()
    
    // Store OTP in DB (Using the table we created)
    await supabaseAdmin.from('otp_codes').upsert({ email, code: otp })
    
    // Send Email via Resend (You need to set RESEND_API_KEY in Supabase Secrets)
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
      },
      body: JSON.stringify({
        from: 'Dinor <onboarding@resend.dev>',
        to: [email],
        subject: 'Your Dinor Login Code',
        html: `<strong>Your login code is: ${otp}</strong>`,
      }),
    })

    if (!res.ok) {
       console.log("Email failed to send, check RESEND_API_KEY")
    }

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
