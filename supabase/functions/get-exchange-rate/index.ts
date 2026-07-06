import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// Caché en memoria: { "USD_ARS": { rate: 1050.5, cachedAt: Date } }
const cache: Record<string, { rate: number; cachedAt: number }> = {};
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hora

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const from = (url.searchParams.get("from") ?? "USD").toUpperCase();
    const to = (url.searchParams.get("to") ?? "ARS").toUpperCase();

    if (from === to) {
      return new Response(
        JSON.stringify({ from, to, rate: 1, cached: false }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const cacheKey = `${from}_${to}`;
    const now = Date.now();
    const cached = cache[cacheKey];

    if (cached && now - cached.cachedAt < CACHE_TTL_MS) {
      return new Response(
        JSON.stringify({
          from,
          to,
          rate: cached.rate,
          cached: true,
          cachedAt: new Date(cached.cachedAt).toISOString(),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Llamar a la API de tasas de cambio (Open Exchange Rates formato compatible)
    // Usamos exchangerate-api.com formato Open (gratuito sin key para pares básicos)
    // Alternativa: open.er-api.com/v6/latest/{from}
    const apiUrl = `https://open.er-api.com/v6/latest/${from}`;
    const apiRes = await fetch(apiUrl);

    if (!apiRes.ok) {
      throw new Error(`API de tasa de cambio devolvió ${apiRes.status}`);
    }

    const data = await apiRes.json();
    const rate = data?.rates?.[to];

    if (typeof rate !== "number") {
      throw new Error(`Moneda '${to}' no encontrada en la respuesta`);
    }

    // Guardar en caché
    cache[cacheKey] = { rate, cachedAt: now };

    return new Response(
      JSON.stringify({
        from,
        to,
        rate,
        cached: false,
        fetchedAt: new Date(now).toISOString(),
        note: "Tasa sugerida. Puede ajustarse antes de confirmar.",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
