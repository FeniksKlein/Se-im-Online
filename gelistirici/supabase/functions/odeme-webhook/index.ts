// Supabase Edge Function: odeme-webhook
// RevenueCat → Project Settings → Integrations → Webhooks:
//   URL: https://<proje>.supabase.co/functions/v1/odeme-webhook
//   Authorization header value: Bearer <ODEME_GIZLI ile aynı rastgele metin>
// Gerekli gizli değer (Supabase → Edge Functions → Secrets): ODEME_GIZLI
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik verilir.
// Bu fonksiyon "Verify JWT" KAPALI olarak yayımlanmalı (RevenueCat Supabase oturumu taşımaz).
import { isle } from "./cekirdek.mjs";

Deno.serve(async (req) => {
  try {
    const s = await isle({ yontem: req.method, yetki: req.headers.get("authorization"), govde: await req.text() }, {
      supabaseUrl: Deno.env.get("SUPABASE_URL"),
      servisAnahtari: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      gizli: Deno.env.get("ODEME_GIZLI"),
      fetch
    });
    return new Response(JSON.stringify(s.govde), { status: s.durum, headers: { "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ hata: String(err && err.message || err) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
