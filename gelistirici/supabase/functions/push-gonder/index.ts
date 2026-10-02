// Supabase Edge Function: push-gonder
// Veritabanı her dakika (kuyrukta bildirim varsa) bu fonksiyonu çağırır.
// Gerekli gizli değerler (Supabase → Edge Functions → Secrets):
//   PUSH_GIZLI           : oyun.ayarlar.push_gizli ile aynı rastgele metin
//   FCM_SERVICE_ACCOUNT  : Firebase servis hesabı JSON dosyasının tamamı
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik verilir.
import { calistir } from "./cekirdek.mjs";

Deno.serve(async (req) => {
  if (req.headers.get("x-gizli") !== Deno.env.get("PUSH_GIZLI")) {
    return new Response("yetkisiz", { status: 401 });
  }
  try {
    const sonuc = await calistir({
      supabaseUrl: Deno.env.get("SUPABASE_URL"),
      servisAnahtari: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      hesap: JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") || "{}"),
      fetch
    });
    return new Response(JSON.stringify(sonuc), { headers: { "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ hata: String(err && err.message || err) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
