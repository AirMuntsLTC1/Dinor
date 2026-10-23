import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Helper function to scrape DuckDuckGo (which indexes Google)
async function searchWeb(query: string): Promise<string> {
  try {
    const response = await fetch(`https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      }
    });
    
    const html = await response.text();
    
    // Extract snippets using regex (faster than DOM parsing in Deno)
    const snippets: string[] = [];
    const regex = /<a class="result__snippet[^>]*>(.*?)<\/a>/g;
    let match;
    
    while ((match = regex.exec(html)) !== null && snippets.length < 4) {
      // Remove HTML tags from the snippet
      const cleanText = match[1].replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
      if (cleanText.length > 20) {
        snippets.push(cleanText);
      }
    }
    
    return snippets.join('\n\n');
  } catch (e) {
    console.error("Web search failed:", e);
    return "";
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { userMessage } = await req.json()
    
    const groqApiKey = Deno.env.get('GROQ_API_KEY')
    if (!groqApiKey) throw new Error("GROQ_API_KEY is not set in Supabase Secrets")

    // 1. Search the web for context
    console.log(`Searching web for: ${userMessage}`);
    const webContext = await searchWeb(userMessage);

    // 2. Build the prompt
    let prompt = "";
    if (webContext) {
      prompt = `Here are some recent search results from the web:\n\n${webContext}\n\nBased ONLY on the above context, answer the user's question:\n${userMessage}`;
    } else {
      prompt = `Answer this question using your general knowledge:\n${userMessage}`;
    }

    // 3. Ask Groq (Llama 3.1)
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
            content: "You are Dinor AI, a helpful web-searching assistant. Answer clearly and concisely." 
          },
          { 
            role: "user", 
            content: prompt 
          }
        ],
        temperature: 0.3, // Lower temperature means it sticks closer to the facts
        max_tokens: 300,
      }),
    })

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
      throw new Error("No response from AI")
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
