// Supabase Edge Function: admob-ssv
// AdMob → Uygulama → Reklam birimleri → ödüllü birim → Sunucu tarafı doğrulama:
//   URL: https://<proje>.supabase.co/functions/v1/admob-ssv
// Verify JWT KAPALI olmalı (Google Supabase oturumu taşımaz). supabase/config.toml bunu yazar.
// Dağıtım: supabase functions deploy admob-ssv --no-verify-jwt
// Gizli (Edge Functions → Secrets): ADMOB_SSV_GIZLI
// Aynı metin veritabanında oyun.uygulama_ayar anahtarı admob_ssv_gizli (herkese_acik false).
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından verilir.
// Bu fonksiyon bu oturumda dağıtılmadı.
import { isle } from "./cekirdek.mjs";

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const sorgu = url.search.startsWith("?") ? url.search.slice(1) : url.search;
    const s = await isle({ yontem: req.method, sorgu }, {
      supabaseUrl: Deno.env.get("SUPABASE_URL"),
      servisAnahtari: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      gizli: Deno.env.get("ADMOB_SSV_GIZLI"),
      fetch
    });
    return new Response(JSON.stringify(s.govde), { status: s.durum, headers: { "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ hata: String(err && err.message || err) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
