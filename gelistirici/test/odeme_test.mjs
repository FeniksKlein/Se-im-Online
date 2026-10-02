// Ödeme webhook testi: sahte RevenueCat olayları + gerçek veritabanı (service_role).
// Çalıştır (vatandas.py'den sonra): node test/odeme_test.mjs
import { isle, esit } from "../supabase/functions/odeme-webhook/cekirdek.mjs";
import { execFileSync } from "node:child_process";
import assert from "node:assert";

const psql = (sql) => execFileSync("psql", ["-h", "/tmp", "-U", "postgres", "-d", "oyun_test", "-At", "-q", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
const u = psql(`select id from oyun.profiller where kad='Veli'`);
const para = () => +psql(`select para from oyun.cuzdan where user_id='${u}'`);

async function sahteFetch(url, ist) {
  assert.ok(url.endsWith("/rest/v1/rpc/odeme_isle"));
  assert.equal(ist.headers.apikey, "servis");
  const govde = JSON.parse(ist.body);
  const out = psql(`set role service_role; select public.odeme_isle('${JSON.stringify(govde.p_olay).replace(/'/g, "''")}'::jsonb);`);
  return new Response(out.split("\n").pop(), { status: 200 });
}
const ayar = { supabaseUrl: "http://yerel", servisAnahtari: "servis", gizli: "cok-gizli-anahtar", fetch: sahteFetch };
const gonder = (olay, yetki = "Bearer cok-gizli-anahtar", yontem = "POST") => isle({ yontem, yetki, govde: JSON.stringify(olay) }, ayar);

assert.ok(esit("abc", "abc") && !esit("abc", "abd") && !esit("", ""));
assert.equal((await gonder({ event: { type: "TEST" } }, "Bearer yanlis")).durum, 401);
assert.equal((await gonder({ event: { type: "TEST" } }, null)).durum, 401);
assert.equal((await gonder({}, undefined, "GET")).durum, 405);
assert.equal((await isle({ yontem: "POST", yetki: "Bearer cok-gizli-anahtar", govde: "{bozuk" }, ayar)).durum, 400);
assert.equal((await gonder({ event: { type: "TEST" } })).govde.durum, "test");
const p0 = para();
const olay = { api_version: "1.0", event: { type: "NON_RENEWING_PURCHASE", app_user_id: u, product_id: "tl_100000", transaction_id: "GPA.TEST-1", store: "PLAY_STORE" } };
const r1 = await gonder(olay);
assert.equal(r1.durum, 200); assert.equal(r1.govde.durum, "eklendi");
assert.equal(para(), p0 + 100000);
assert.equal((await gonder(olay)).govde.durum, "zaten_islendi");      // RevenueCat aynı olayı yeniden gönderse de bir kez eklenir
assert.equal(para(), p0 + 100000);
assert.equal((await gonder({ event: { type: "NON_RENEWING_PURCHASE", app_user_id: "yok", product_id: "tl_10000", transaction_id: "X" } })).govde.durum, "kullanici_yok");
// veritabanı hata verirse 500 → RevenueCat yeniden dener
const r5 = await isle({ yontem: "POST", yetki: "Bearer cok-gizli-anahtar", govde: "{}" }, { ...ayar, fetch: async () => new Response("bozuk", { status: 503 }) });
assert.equal(r5.durum, 500);
console.log("  ✓ Ödeme webhook: yanlış/eksik anahtar 401, yalnız POST, bozuk JSON 400, satın alma cüzdana eklendi, tekrar gönderim çift eklemedi, bilinmeyen kullanıcı yok sayıldı, veritabanı hatasında 500");
console.log("\nÖDEME TESTİ GEÇTİ");
