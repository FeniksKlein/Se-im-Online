// AdMob ödüllü reklam SSV çekirdeği. Edge Function (Deno) ve Node testi aynı dosyayı kullanır.
// Google, ödül verildiğinde yapılandırılan adrese GET atar. Sorgu dizisinin imzası
// (signature parametresinden önceki baytlar) ECDSA P-256 / SHA-256 ve DER kodludur.
// Açık anahtarlar: https://www.gstatic.com/admob/reward/verifier-keys.json
// Anahtarlar 24 saatten uzun önbellekte tutulmaz. İmza doğrulanmadan RPC çağrılmaz.
//
// AdMob konsolu:
//   1. Uygulama → Reklam birimleri → ödüllü birim → Gelişmiş ayarlar → Sunucu tarafı doğrulama.
//   2. Geri çağrı URL'si: https://<proje>.supabase.co/functions/v1/admob-ssv
//      (Verify JWT kapalı; supabase/config.toml bunu yazar. Dağıtımda --no-verify-jwt de geçer.)
//   3. "Geri çağırmayı doğrula" ile konsolun örnek isteğini gönderin. 200 ve durum alanı beklenir.
//   4. Ödül tutarı oyun maaşından hesaplanır; AdMob reward_amount oyun parasına çevrilmez.
//   5. Google'ın örnek reklam birimleri (ca-app-pub-3940256099942544/...) sizin URL'nize
//      geri çağrı göndermez. Gerçek birimde test cihazı kullanın ya da konsoldaki doğrulama aracını.

import { createVerify, createPublicKey } from "node:crypto";

export const ANAHTAR_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const ONBELLEK_MS = 12 * 60 * 60 * 1000;
let onbellek = { zaman: 0, harita: null };

export function onbellekSifirla() { onbellek = { zaman: 0, harita: null }; }

// Google'ın doğrulayıcısı: içerik, "signature=" ifadesinden hemen önceki '&'e kadardır.
// signature ve key_id her zaman sondadır; sıra ve kodlama değiştirilmez.
export function sorguCoz(sorgu) {
  const ham = String(sorgu || "");
  if (ham.length > 8192) return null;
  const i = ham.indexOf("signature=");
  if (i < 1 || ham[i - 1] !== "&") return null;
  const icerik = ham.slice(0, i - 1);
  const kalan = ham.slice(i);
  const k = kalan.indexOf("&key_id=");
  if (k < "signature=".length) return null;
  const imza = kalan.slice("signature=".length, k);
  const keyId = decodeURIComponent(kalan.slice(k + "&key_id=".length).split("&")[0] || "").trim();
  if (!imza || !keyId || !icerik) return null;
  return { icerik, imza, keyId, params: new URLSearchParams(icerik) };
}

export function imzaGecerli(icerik, imza, pem) {
  let key;
  try { key = createPublicKey(pem); } catch { return false; }
  const dene = (kodlama, imzaMetni) => {
    const v = createVerify("SHA256");
    v.update(icerik, "utf8");
    return v.verify({ key, dsaEncoding: "der" }, imzaMetni, kodlama);
  };
  try { if (dene("base64url", imza)) return true; } catch { /* sıradaki kodlama */ }
  try { if (dene("base64", imza)) return true; } catch { /* geçersiz imza */ }
  return false;
}

// 10 hane saniye, 13 hane milisaniye, 16 hane mikrosaniye. 15 dk gelecek / 24 saat geçmiş reddedilir.
// transaction_id tekilliği asıl yinelemedir; zaman penceresi gecikmiş imzalı URL'yi keser.
export function zamanDamgasi(deger, simdiMs) {
  const n = Number(deger);
  if (!Number.isFinite(n) || n <= 0) return false;
  let ms = n;
  if (n < 1e11) ms = n * 1000;
  else if (n >= 1e14) ms = Math.floor(n / 1000);
  const fark = ms - simdiMs;
  if (fark > 15 * 60 * 1000) return false;
  if (fark < -24 * 60 * 60 * 1000) return false;
  return true;
}

export async function anahtarlariYukle(fetchFn, simdi = Date.now()) {
  if (onbellek.harita && simdi - onbellek.zaman < ONBELLEK_MS) return onbellek.harita;
  const yanit = await fetchFn(ANAHTAR_URL);
  if (!yanit.ok) throw new Error("AdMob anahtarları indirilemedi");
  const json = await yanit.json();
  const harita = new Map();
  for (const k of json.keys || []) {
    if (k && k.keyId != null && k.pem) harita.set(String(k.keyId), k.pem);
  }
  if (!harita.size) throw new Error("AdMob açık anahtarı yok");
  onbellek = { zaman: simdi, harita };
  return harita;
}

// istek: { yontem, sorgu }
// ayar : { supabaseUrl, servisAnahtari, gizli, fetch, simdiMs?, anahtarlar? }
export async function isle(istek, ayar) {
  if (istek.yontem !== "GET" && istek.yontem !== "POST") return { durum: 405, govde: { hata: "yalnız GET" } };
  const cozum = sorguCoz(istek.sorgu);
  if (!cozum) return { durum: 400, govde: { hata: "imza yok" } };
  let harita;
  try {
    harita = ayar.anahtarlar || await anahtarlariYukle(ayar.fetch, ayar.simdiMs ?? Date.now());
  } catch (err) {
    return { durum: 500, govde: { hata: String(err && err.message || err) } };
  }
  const pem = harita.get(String(cozum.keyId));
  if (!pem) return { durum: 400, govde: { hata: "anahtar yok" } };
  if (!imzaGecerli(cozum.icerik, cozum.imza, pem)) return { durum: 403, govde: { hata: "imza geçersiz" } };
  const simdi = ayar.simdiMs ?? Date.now();
  if (!zamanDamgasi(cozum.params.get("timestamp"), simdi)) return { durum: 200, govde: { durum: "suresi_doldu" } };
  if (!ayar.gizli) return { durum: 500, govde: { hata: "ADMOB_SSV_GIZLI yok" } };
  const olay = {
    transaction_id: cozum.params.get("transaction_id"),
    user_id: cozum.params.get("user_id"),
    custom_data: cozum.params.get("custom_data"),
    timestamp: cozum.params.get("timestamp"),
    reward_amount: cozum.params.get("reward_amount"),
    reward_item: cozum.params.get("reward_item"),
    ad_network: cozum.params.get("ad_network"),
    ad_unit: cozum.params.get("ad_unit"),
    gizli: ayar.gizli
  };
  const yanit = await ayar.fetch(`${ayar.supabaseUrl}/rest/v1/rpc/reklam_ssv_isle`, {
    method: "POST",
    headers: {
      apikey: ayar.servisAnahtari,
      Authorization: `Bearer ${ayar.servisAnahtari}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ p_olay: olay })
  });
  if (!yanit.ok) {
    return { durum: 500, govde: { hata: "veritabanı: " + yanit.status + " " + (await yanit.text()).slice(0, 200) } };
  }
  return { durum: 200, govde: await yanit.json() };
}
