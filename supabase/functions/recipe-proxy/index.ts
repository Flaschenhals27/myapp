import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const groqKey = Deno.env.get("GROQ_API_KEY");
  if (!groqKey) {
    return new Response(
      JSON.stringify({ error: "GROQ_API_KEY not configured on server" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const { ingredients } = await req.json();

  const groqResponse = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${groqKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      max_tokens: 2048,
      messages: [
        {
          role: "system",
          content:
            "Du bist ein Kochassistent. Antworte ausschließlich mit gültigem JSON, ohne zusätzlichen Text.",
        },
        {
          role: "user",
          content: `Schlage 3 einfache Rezepte vor, die folgende Lebensmittel verwenden, die bald ablaufen: ${ingredients}.

Antworte NUR mit einem gültigen JSON-Array:
[
  {
    "name": "Rezeptname",
    "description": "Kurze appetitliche Beschreibung (1-2 Sätze)",
    "ingredients": ["Zutat 1 mit Menge", "Zutat 2 mit Menge"],
    "steps": ["Schritt 1", "Schritt 2", "Schritt 3"],
    "durationMinutes": 30
  }
]`,
        },
      ],
    }),
  });

  const data = await groqResponse.json();

  return new Response(JSON.stringify(data), {
    status: groqResponse.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
