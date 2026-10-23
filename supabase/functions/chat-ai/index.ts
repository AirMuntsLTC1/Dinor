import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { userMessage, context } = await req.json()
    
    const groqApiKey = Deno.env.get('GROQ_API_KEY')
    if (!groqApiKey) throw new Error("GROQ_API_KEY is not set in Supabase Secrets")

    // Ensure the prompt is a clean string without weird formatting
    let prompt = "";
    if (context && context.trim().length > 0) {
      prompt = `Context from web: ${context}\n\nUser Question: ${userMessage}\n\nProvide a clear, concise answer based on the context.`;
    } else {
      prompt = `User Question: ${userMessage}\n\nProvide a clear, concise answer.`;
    }

    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${groqApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        messages: [
          { 
            role: "system", 
            content: "You are Dinor AI, a helpful and friendly assistant. Answer in plain text." 
          },
          { 
            role: "user", 
            content: prompt 
          }
        ],
        temperature: 0.5,
        max_tokens: 300,
      }),
    })

    // Catch the actual error from Groq instead of failing silently
    if (!res.ok) {
      const errorData = await res.json();
      throw new Error(JSON.stringify(errorData));
    }

    const data = await res.json()

    if (data.choices && data.choices.length > 0) {
      return new Response(JSON.stringify({ reply: data.choices[0].message.content.trim() }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    } else {
      throw new Error("No choices returned from Groq")
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
