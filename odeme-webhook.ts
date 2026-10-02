// TEK DOSYA SÜRÜMÜ — Supabase → Edge Functions → odeme-webhook → index.ts içine olduğu gibi yapıştır
// Ödeme webhook çekirdeği — Supabase Edge Function (Deno) içinde ve testte Node'da çalışır.
// RevenueCat, bir satın alma olduğunda bu adrese olay gönderir. Olay, kimlik doğrulandıktan sonra
// veritabanındaki odeme_isle fonksiyonuna (yalnız service_role çağırabilir) iletilir.
// Para yalnızca burada, mağazanın doğruladığı satın almadan sonra eklenir; uygulama kendi başına para ekleyemez.

// Zamanlamadan bilgi sızdırmayan karşılaştırma
function esit(a, b) {
  a = String(a || ""); b = String(b || "");
  let fark = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) fark |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return fark === 0 && a.length > 0;
}

// istek: { yontem, yetki (Authorization başlığı), govde (metin) }
// ayar : { supabaseUrl, servisAnahtari, gizli, fetch }
async function isle(istek, ayar) {
  if (istek.yontem !== "POST") return { durum: 405, govde: { hata: "yalnız POST" } };
  const beklenen = ayar.gizli && (ayar.gizli.startsWith("Bearer ") ? ayar.gizli : "Bearer " + ayar.gizli);
  if (!ayar.gizli || !esit(istek.yetki, beklenen)) return { durum: 401, govde: { hata: "yetkisiz" } };
  let olay;
  try { olay = JSON.parse(istek.govde || "{}"); } catch { return { durum: 400, govde: { hata: "geçersiz JSON" } }; }
  const yanit = await ayar.fetch(`${ayar.supabaseUrl}/rest/v1/rpc/odeme_isle`, {
    method: "POST",
    headers: { apikey: ayar.servisAnahtari, Authorization: `Bearer ${ayar.servisAnahtari}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_olay: olay })
  });
  if (!yanit.ok) {
    // 5xx dönersek RevenueCat olayı daha sonra yeniden gönderir; aynı işlem iki kez işlenmez (islem_id tekil)
    return { durum: 500, govde: { hata: "veritabanı: " + yanit.status + " " + (await yanit.text()).slice(0, 200) } };
  }
  return { durum: 200, govde: await yanit.json() };
}

// Supabase Edge Function: odeme-webhook
// RevenueCat → Project Settings → Integrations → Webhooks:
//   URL: https://<proje>.supabase.co/functions/v1/odeme-webhook
//   Authorization header value: Bearer <ODEME_GIZLI ile aynı rastgele metin>
// Gerekli gizli değer (Supabase → Edge Functions → Secrets): ODEME_GIZLI
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik verilir.
// Bu fonksiyon "Verify JWT" KAPALI olarak yayımlanmalı (RevenueCat Supabase oturumu taşımaz).

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
