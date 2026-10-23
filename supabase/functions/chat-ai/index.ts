
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { userMessage, context } = await req.json()
    
    // Retrieve the secret key from Supabase Environment Variables
    const groqApiKey = Deno.env.get('GROQ_API_KEY')
    if (!groqApiKey) throw new Error("GROQ_API_KEY is not set in Supabase Secrets")

    const prompt = context 
      ? `Context: ${context}\n\nUser Question: ${userMessage}\n\nAnswer the user's question clearly using the context above.`
      : `User Question: ${userMessage}\n\nAnswer clearly.`

    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: "llama3-8b-8192",
        messages: [
          { role: "system", content: "You are Dinor AI, a helpful, smart, and friendly assistant. Keep answers concise." },
          { role: "user", content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 250,
      }),
    })

    const data = await res.json()

    if (data.choices && data.choices.length > 0) {
      return new Response(JSON.stringify({ reply: data.choices[0].message.content.trim() }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } else {
      throw new Error("Invalid response from Groq")
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
