import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ---------------------------------------------------------
// HELPER: Live Google News RSS Search (Unblockable)
// ---------------------------------------------------------
async function searchGoogleNews(query: string): Promise<string> {
  try {
    const response = await fetch(`https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=en-US&gl=US&ceid=US:en`);
    const xml = await response.text();
    const items: string[] = [];
    const itemBlocks = xml.split('<item>');
    
    for (let i = 1; i < itemBlocks.length && items.length < 5; i++) {
      const titleMatch = itemBlocks[i].match(/<title>(.*?)<\/title>/);
      if (titleMatch && titleMatch[1]) {
        const title = titleMatch[1].replace(/<[^>]+>/g, '').replace(/&quot;/g, '"').replace(/&#39;/g, "'").trim();
        items.push(`- ${title}`);
      }
    }
    return items.join('\n');
  } catch (e) {
    console.error("News search error:", e);
    return "";
  }
}

// ---------------------------------------------------------
// HELPER: Ask Groq (With Automatic Model Fallback)
// ---------------------------------------------------------
async function callGroq(apiKey: string, messages: any[], max_tokens: number = 300, availableModels: string[] = []) {
  // Priority list of models to try
  const modelPriority = [
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "qwen/qwen3.8-27b",
    "allam-2-7b"
  ];

  // Find the best available model
  let modelToUse = modelPriority.find(m => availableModels.includes(m));

  if (!modelToUse) {
    // If none of the prioritized models exist, just grab any text model
    modelToUse = availableModels.find(m => 
      !m.includes('whisper') && !m.includes('guard') && !m.includes('vision') && !m.includes('orpheus')
    );
  }

  if (!modelToUse) throw new Error("No usable AI models available on this account.");

  console.log(`Calling model: ${modelToUse}`);
  
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: modelToUse,
      messages: messages,
      temperature: 0.4,
      max_tokens: max_tokens,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Groq Error: ${err}`);
  }

  return await res.json();
}

// ---------------------------------------------------------
// MAIN SERVER
// ---------------------------------------------------------
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { userMessage, imageBase64 } = await req.json()
    const groqApiKey = Deno.env.get('GROQ_API_KEY')
    if (!groqApiKey) throw new Error("Missing GROQ_API_KEY")

    // 1. Fetch available models from the user's Groq account
    const modelsRes = await fetch('https://api.groq.com/openai/v1/models', {
      headers: { 'Authorization': `Bearer ${groqApiKey}` }
    });
    const modelsData = await modelsRes.json();
    const availableModels: string[] = modelsData.data?.map((m: any) => m.id) || [];

    // -----------------------------------------------------
    // PATH A: VISION (User sent an image)
    // -----------------------------------------------------
    if (imageBase64) {
      const visionModel = "llama-3.2-11b-vision-preview";
      if (!availableModels.includes(visionModel)) {
        return new Response(JSON.stringify({ reply: "Vision is not available on your account yet." }), { headers: corsHeaders });
      }

      const visionRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${groqApiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: visionModel,
          messages: [
            {
              role: "user",
              content: [
                { type: "text", text: userMessage || "Describe this image in detail." },
                { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }
              ]
            }
          ],
          max_tokens: 400,
        }),
      });

      const visionData = await visionRes.json();
      if (visionData.choices && visionData.choices.length > 0) {
        return new Response(JSON.stringify({ reply: visionData.choices[0].message.content.trim() }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      throw new Error("Vision analysis failed.");
    }

    // -----------------------------------------------------
    // PATH B: TEXT + LIVE WEB SEARCH (No image)
    // -----------------------------------------------------
    
    // 1. Try to get live news context based on the user's message
    console.log(`Searching Google News for: ${userMessage}`);
    const webContext = await searchGoogleNews(userMessage);

    // 2. Build the prompt. We explicitly tell the AI it HAS web access.
    let finalPrompt = "";
    if (webContext) {
      finalPrompt = `You are Dinor AI. I just performed a live web search for the user's question and found these recent news headlines:\n\n${webContext}\n\nUser Question: ${userMessage}\n\nUsing the headlines above, answer the user's question directly. Be confident. Do not say "I don't have real-time info." Plain text only.`;
    } else {
      finalPrompt = `User Question: ${userMessage}\n\nAnswer confidently using your general knowledge. Plain text only.`;
    }

    // 3. Ask the AI
    const finalRes = await callGroq(
      groqApiKey,
      [
        { role: "system", content: "You are Dinor AI, a helpful, highly intelligent assistant with live internet access. Answer naturally and do not mention your training cutoff." },
        { role: "user", content: finalPrompt }
      ],
      400,
      availableModels
    );

    const reply = finalRes.choices[0].message.content.trim().replace(/\*\*/g, ''); // Strip markdown

    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ reply: `System Error: ${error.message}` }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
