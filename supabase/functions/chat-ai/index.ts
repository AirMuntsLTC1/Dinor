import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function searchGoogleNews(query: string): Promise<string> {
  try {
    const response = await fetch(`https://news.google.com/rss/search?q=${encodeURIComponent(query)}&hl=en-US&gl=US&ceid=US:en`);
    const xml = await response.text();
    const items: string[] = [];
    const itemBlocks = xml.split('<item>');
    for (let i = 1; i < itemBlocks.length && items.length < 5; i++) {
      const titleMatch = itemBlocks[i].match(/<title>(.*?)<\/title>/);
      if (titleMatch && titleMatch[1]) {
        items.push(`- ${titleMatch[1].replace(/<[^>]+>/g, '').trim()}`);
      }
    }
    return items.join('\n');
  } catch (e) { return ""; }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json();
    const userMessage = body.userMessage || "Hello";
    const imageBase64 = body.imageBase64;

    const groqApiKey = Deno.env.get('GROQ_API_KEY')
    if (!groqApiKey) throw new Error("Missing GROQ_API_KEY")

    const modelsRes = await fetch('https://api.groq.com/openai/v1/models', {
      headers: { 'Authorization': `Bearer ${groqApiKey}` }
    });
    const modelsData = await modelsRes.json();
    const availableModels: string[] = modelsData.data?.map((m: any) => m.id) || [];

    // -------------------------
    // VISION MODEL
    // -------------------------
    if (imageBase64) {
      const visionModel = "llama-3.2-11b-vision-preview";
      if (!availableModels.includes(visionModel)) {
        return new Response(JSON.stringify({ reply: "Vision model is not available on your Groq account." }), { headers: corsHeaders });
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
                { type: "text", text: userMessage },
                { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageBase64}` } }
              ]
            }
          ],
          max_tokens: 500,
        }),
      });

      const visionData = await visionRes.json();
      if (visionData.choices && visionData.choices.length > 0) {
        return new Response(JSON.stringify({ reply: visionData.choices[0].message.content.trim() }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      throw new Error(`Vision failed: ${JSON.stringify(visionData)}`);
    }

    // -------------------------
    // TEXT MODEL
    // -------------------------
    const modelsToTry = ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3.8-27b", "allam-2-7b"]
      .filter(m => availableModels.includes(m));
    const model = modelsToTry[0];
    if (!model) throw new Error("No text models available.");

    const webContext = await searchGoogleNews(userMessage);
    let finalPrompt = webContext 
      ? `News context:\n${webContext}\n\nUser Question: ${userMessage}\n\nAnswer directly.`
      : `User Question: ${userMessage}\n\nAnswer directly.`;

    const finalRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${groqApiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: model,
        messages: [
          { role: "system", content: "You are Dinor AI. Answer confidently." },
          { role: "user", content: finalPrompt }
        ],
        temperature: 0.3,
        max_tokens: 400,
      }),
    });

    const finalData = await finalRes.json();
    if (finalData.choices && finalData.choices.length > 0) {
      return new Response(JSON.stringify({ reply: finalData.choices[0].message.content.trim() }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    throw new Error(`AI failed: ${JSON.stringify(finalData)}`);

  } catch (error) {
    // Catch ANY error and return it as a clean string reply
    return new Response(JSON.stringify({ reply: `AI Error: ${error.message}` }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})


============================================================
