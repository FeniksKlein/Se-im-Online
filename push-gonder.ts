// TEK DOSYA SÜRÜMÜ — Supabase → Edge Functions → push-gonder → index.ts içine olduğu gibi yapıştır
// Push gönderici çekirdeği — Supabase Edge Function (Deno) içinde ve testte Node'da çalışır.
// Kuyruktaki bildirimleri veritabanından alır, Firebase Cloud Messaging (HTTP v1) ile gönderir,
// sonucu veritabanına yazar. Dış bağımlılığı yoktur (yalnızca fetch ve Web Crypto).

const b64url = (buf) => {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = ""; for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};
const b64urlMetin = (m) => b64url(new TextEncoder().encode(m));

function pemToDer(pem) {
  const govde = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const ikili = atob(govde);
  const out = new Uint8Array(ikili.length);
  for (let i = 0; i < ikili.length; i++) out[i] = ikili.charCodeAt(i);
  return out.buffer;
}

// Google servis hesabıyla OAuth erişim anahtarı al
async function erisimAnahtari(hesap, fetchFn, simdi = Math.floor(Date.now() / 1000)) {
  const baslik = { alg: "RS256", typ: "JWT" };
  const iddia = {
    iss: hesap.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: hesap.token_uri || "https://oauth2.googleapis.com/token",
    iat: simdi, exp: simdi + 3600
  };
  const imzalanacak = b64urlMetin(JSON.stringify(baslik)) + "." + b64urlMetin(JSON.stringify(iddia));
  const anahtar = await crypto.subtle.importKey("pkcs8", pemToDer(hesap.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const imza = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", anahtar, new TextEncoder().encode(imzalanacak));
  const jwt = imzalanacak + "." + b64url(imza);
  const r = await fetchFn(iddia.aud, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=" + encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer") + "&assertion=" + jwt
  });
  if (!r.ok) throw new Error("Google erişim anahtarı alınamadı: " + r.status + " " + (await r.text()));
  return (await r.json()).access_token;
}

async function rpc(ayar, fn, govde) {
  const r = await ayar.fetch(`${ayar.supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ayar.servisAnahtari, Authorization: `Bearer ${ayar.servisAnahtari}` },
    body: JSON.stringify(govde)
  });
  if (!r.ok) throw new Error(`${fn} başarısız: ${r.status} ${await r.text()}`);
  return r.json();
}

function mesajKur(kayit, hedef) {
  const veri = {};
  for (const [k, v] of Object.entries(kayit.veri || {})) veri[k] = String(v);
  return {
    message: {
      ...hedef,
      notification: { title: kayit.baslik, body: kayit.govde },
      data: veri,
      android: { priority: "high", notification: { sound: "default" } },
      apns: { payload: { aps: { sound: "default" } } }
    }
  };
}

// Sınırlı eşzamanlılıkla iş çalıştır
async function sirayla(isler, esz = 10) {
  const sonuc = new Array(isler.length); let i = 0;
  await Promise.all(Array.from({ length: Math.min(esz, isler.length) }, async () => {
    while (i < isler.length) { const n = i++; sonuc[n] = await isler[n](); }
  }));
  return sonuc;
}

// ayar: { supabaseUrl, servisAnahtari, hesap (servis hesabı JSON), fetch }
async function calistir(ayar) {
  const kuyruk = await rpc(ayar, "push_al", { p_limit: 500 });
  if (!kuyruk.length) return { alinan: 0, gonderilen: 0 };
  const token = await erisimAnahtari(ayar.hesap, ayar.fetch);
  const url = `https://fcm.googleapis.com/v1/projects/${ayar.hesap.project_id}/messages:send`;
  const basarili = [], hatalar = {}, gecersiz = [];
  let gonderilen = 0;

  const gonder = async (govde) => {
    const r = await ayar.fetch(url, { method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` }, body: JSON.stringify(govde) });
    if (r.ok) { gonderilen++; return { ok: true }; }
    const metin = await r.text();
    return { ok: false, durum: r.status, metin, gecersiz: r.status === 404 || /UNREGISTERED|registration-token-not-registered|INVALID_ARGUMENT/.test(metin) };
  };

  await sirayla(kuyruk.map((k) => async () => {
    if (k.tokenlar) {
      if (!k.tokenlar.length) { basarili.push(k.id); return; }      // cihazı kalmamış: kapat
      const sonuclar = await Promise.all(k.tokenlar.map((t) => gonder(mesajKur(k, { token: t }))));
      sonuclar.forEach((s, i) => { if (!s.ok && s.gecersiz && s.durum !== 400) gecersiz.push(k.tokenlar[i]); });
      if (sonuclar.some((s) => s.ok) || sonuclar.every((s) => s.gecersiz)) basarili.push(k.id);
      else hatalar[k.id] = sonuclar.map((s) => s.durum).join(",");
    } else {
      const s = await gonder(mesajKur(k, k.kosul ? { condition: k.kosul } : { topic: k.konu }));
      if (s.ok) basarili.push(k.id); else hatalar[k.id] = `${s.durum} ${String(s.metin).slice(0, 200)}`;
    }
  }));

  await rpc(ayar, "push_bitti", { p_sonuc: { basarili, hatalar, gecersiz } });
  return { alinan: kuyruk.length, gonderilen, basarili: basarili.length, hatali: Object.keys(hatalar).length, gecersiz: gecersiz.length };
}

// Supabase Edge Function: push-gonder
// Veritabanı her dakika (kuyrukta bildirim varsa) bu fonksiyonu çağırır.
// Gerekli gizli değerler (Supabase → Edge Functions → Secrets):
//   PUSH_GIZLI           : oyun.ayarlar.push_gizli ile aynı rastgele metin
//   FCM_SERVICE_ACCOUNT  : Firebase servis hesabı JSON dosyasının tamamı
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından otomatik verilir.

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
