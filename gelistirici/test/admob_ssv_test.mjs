// AdMob SSV: imza doğrulama (ağ yok) ve, yerel oyun_test varsa, ödül RPC'si.
// Çalıştır: node gelistirici/test/admob_ssv_test.mjs
// SQL bölümü için önce: bash gelistirici/kur_yerel.sh
import assert from "node:assert";
import { createSign, generateKeyPairSync } from "node:crypto";
import { execFileSync } from "node:child_process";
import {
  isle, sorguCoz, imzaGecerli, zamanDamgasi, anahtarlariYukle, onbellekSifirla, ANAHTAR_URL
} from "../../supabase/functions/admob-ssv/cekirdek.mjs";

const { publicKey, privateKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const pem = publicKey.export({ type: "spki", format: "pem" });
const imzala = (icerik) => createSign("SHA256").update(icerik).sign(privateKey).toString("base64url");
const simdi = Date.now();
const icerik = (tid, ozel = {}) => {
  const p = new URLSearchParams({
    ad_network: "5450213213286189855",
    ad_unit: "2747237135",
    custom_data: "aabbccddeeff00112233445566778899",
    reward_amount: "1",
    reward_item: "odul",
    timestamp: String(simdi),
    transaction_id: tid,
    user_id: "11111111-1111-1111-1111-111111111111",
    ...ozel
  });
  return p.toString();
};
const sorguYap = (govde, keyId = "42") => `${govde}&signature=${imzala(govde)}&key_id=${keyId}`;

const cozum = sorguCoz(sorguYap(icerik("t1")));
assert.equal(cozum.keyId, "42");
assert.equal(cozum.params.get("transaction_id"), "t1");
assert.equal(cozum.params.get("custom_data"), "aabbccddeeff00112233445566778899");
assert.ok(imzaGecerli(cozum.icerik, cozum.imza, pem));
assert.equal(imzaGecerli(cozum.icerik + "x", cozum.imza, pem), false);
assert.equal(sorguCoz("signature=abc&key_id=1"), null);
assert.equal(zamanDamgasi(String(simdi), simdi), true);
assert.equal(zamanDamgasi(String(Math.floor(simdi / 1000)), simdi), true);
assert.equal(zamanDamgasi(String(simdi * 1000), simdi), true);
assert.equal(zamanDamgasi("1000000000000", simdi), false);
assert.equal(zamanDamgasi(String(simdi + 60 * 60 * 1000), simdi), false);

onbellekSifirla();
let indirme = 0;
const sahteAnahtar = async (url) => {
  assert.equal(url, ANAHTAR_URL);
  indirme++;
  return new Response(JSON.stringify({ keys: [{ keyId: 42, pem }] }), { status: 200 });
};
await anahtarlariYukle(sahteAnahtar, simdi);
await anahtarlariYukle(sahteAnahtar, simdi + 1000);
assert.equal(indirme, 1);

const cagrilar = [];
const ayar = (fazla = {}) => ({
  supabaseUrl: "http://yerel",
  servisAnahtari: "servis",
  gizli: "test-admob-ssv-gizli-degeri",
  simdiMs: simdi,
  anahtarlar: new Map([["42", pem]]),
  fetch: async (url, ist) => {
    cagrilar.push({ url, ist });
    return new Response(JSON.stringify({ durum: "verildi", odul: 10 }), { status: 200 });
  },
  ...fazla
});
const gonder = (sorgu, a = ayar()) => isle({ yontem: "GET", sorgu }, a);

assert.equal((await isle({ yontem: "PUT", sorgu: "" }, ayar())).durum, 405);
assert.equal((await gonder("ad_unit=1")).durum, 400);
const bozuk = sorguYap(icerik("t1"), "99");
assert.equal((await gonder(bozuk)).durum, 400);
const sahte = sorguYap(icerik("t1")).replace("transaction_id=t1", "transaction_id=t2");
assert.equal((await gonder(sahte)).durum, 403);
assert.equal(cagrilar.length, 0);
const eski = sorguYap(icerik("eski", { timestamp: "1000000000000" }));
assert.equal((await gonder(eski)).govde.durum, "suresi_doldu");
assert.equal(cagrilar.length, 0);
assert.equal((await gonder(sorguYap(icerik("t1")), ayar({ gizli: "" }))).durum, 500);

const tamam = await gonder(sorguYap(icerik("t-ok")));
assert.equal(tamam.durum, 200);
assert.equal(tamam.govde.durum, "verildi");
assert.ok(cagrilar[0].url.endsWith("/rest/v1/rpc/reklam_ssv_isle"));
assert.equal(cagrilar[0].ist.headers.apikey, "servis");
const govde = JSON.parse(cagrilar[0].ist.body);
assert.equal(govde.p_olay.transaction_id, "t-ok");
assert.equal(govde.p_olay.gizli, "test-admob-ssv-gizli-degeri");
assert.equal(govde.p_olay.custom_data, "aabbccddeeff00112233445566778899");

const dbHata = await gonder(sorguYap(icerik("t-hata")), ayar({
  fetch: async () => new Response("bozuk", { status: 503 })
}));
assert.equal(dbHata.durum, 500);
console.log("  ✓ AdMob SSV imza: geçerli istek RPC'ye gider, bozuk imza ve eski zaman damgası gitmez");

function psqlVar() {
  try { execFileSync("psql", ["--version"], { stdio: "ignore" }); return true; } catch { return false; }
}
if (!psqlVar()) {
  console.log("  · SQL atlandı (psql yok).");
  console.log("\nADMOB SSV TESTİ GEÇTİ");
  process.exit(0);
}
const kok = new URL(".", import.meta.url).pathname;
const psqlDosya = (db, dosya) => execFileSync("psql", ["-h", "/tmp", "-U", "postgres", "-d", db, "-v", "ON_ERROR_STOP=1", "-q", "-f", dosya], { encoding: "utf8" });
const psql = (sql) => execFileSync("psql", ["-h", "/tmp", "-U", "postgres", "-d", "admob_ssv_test", "-At", "-q", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
execFileSync("psql", ["-h", "/tmp", "-U", "postgres", "-d", "postgres", "-q", "-c", "drop database if exists admob_ssv_test"], { encoding: "utf8" });
execFileSync("psql", ["-h", "/tmp", "-U", "postgres", "-d", "postgres", "-q", "-c", "create database admob_ssv_test"], { encoding: "utf8" });
psqlDosya("admob_ssv_test", kok + "../sql/00_supabase_taklit.sql");
psqlDosya("admob_ssv_test", kok + "admob_ssv_kur.sql");
psqlDosya("admob_ssv_test", kok + "../sql/159_admob_ssv.sql");
psqlDosya("admob_ssv_test", kok + "../sql/160_fk_indeksleri.sql");
let silmeKapali = false;
try { psqlDosya("admob_ssv_test", kok + "../ops/yedek_semalari_sil.sql"); }
catch (err) { silmeKapali = /Silme kapalı/.test(String(err.stderr || err.message)); }
assert.ok(silmeKapali, "onaysız yedek silme betiği hata vermeli");
const GIZLI = "test-admob-ssv-gizli-degeri";
psql(`insert into oyun.uygulama_ayar(anahtar, deger, aciklama, herkese_acik)
      values ('admob_ssv_gizli', to_jsonb('${GIZLI}'::text), 'test', false)
      on conflict (anahtar) do update set deger = excluded.deger, herkese_acik = false`);
assert.equal(psql(`select count(*) from oyun.uygulama_ayar where anahtar='admob_ssv_gizli' and herkese_acik`), "0");
let izinReddi = false;
try { psql(`set role authenticated; select public.reklam_ssv_isle('{}'::jsonb);`); }
catch (err) { izinReddi = /permission denied|izin/i.test(String(err.stderr || err.message)); }
assert.ok(izinReddi, "authenticated reklam_ssv_isle çağıramamalı");
const u = psql(`insert into oyun.profiller(id) values (gen_random_uuid()) returning id`);
const hazirla = () => JSON.parse(psql(`select set_config('request.jwt.claim.sub','${u}', false); select public.reklam_hazirla();`).split("\n").pop());
const sqlIsle = (olay) => JSON.parse(psql(`set role service_role; select public.reklam_ssv_isle('${JSON.stringify(olay).replace(/'/g, "''")}'::jsonb);`));
let reddedildi = false;
try { psql(`select set_config('request.jwt.claim.sub','${u}', false); select public.reklam_odul();`); }
catch (err) { reddedildi = /doğrulanmış/.test(String(err.stderr || err.message)); }
assert.ok(reddedildi, "reklamsız olmayan reklam_odul ödememeli");
const haz = hazirla();
assert.equal(haz.yol, "ssv");
assert.equal(haz.user_id, u);
const olay = { transaction_id: "node-1", user_id: u, custom_data: haz.token, gizli: GIZLI };
const yanit = sqlIsle(olay);
assert.equal(yanit.durum, "verildi");
assert.equal(Number(yanit.odul), 250);
assert.equal(sqlIsle(olay).durum, "zaten_islendi");
assert.equal(psql(`select para::int from oyun.cuzdan where user_id='${u}'`), "250");
const ham = psql(`select coalesce(ham::text,'') from oyun.reklam_ssv_islem where transaction_id='node-1'`);
assert.ok(!ham.includes(GIZLI));
assert.equal(sqlIsle({ transaction_id: "node-yanlis", gizli: "yanlis-ama-yeterince-uzun-metin" }).durum, "yetkisiz");
let bekledi = false;
try { hazirla(); } catch (err) { bekledi = /biraz bekle/.test(String(err.stderr || err.message)); }
assert.ok(bekledi);
for (let i = 2; i <= 5; i++) {
  psql(`update oyun.ayarlar set test_simdi = now() + interval '${i} minutes'`);
  const h = hazirla();
  assert.equal(sqlIsle({ transaction_id: "node-" + i, user_id: u, custom_data: h.token, gizli: GIZLI }).durum, "verildi");
}
let yarin = false;
try { hazirla(); } catch (err) { yarin = /Yarın/.test(String(err.stderr || err.message)); }
assert.ok(yarin, "günlük 5 sınır");
assert.equal(psql(`select para::int from oyun.cuzdan where user_id='${u}'`), "1250");
psql(`create or replace function oyun.reklamsiz(u uuid, t timestamptz default null) returns boolean language sql stable as $$ select true $$`);
psql(`update oyun.ayarlar set test_simdi = now() + interval '1 day'`);
const reklamsiz = JSON.parse(psql(`select set_config('request.jwt.claim.sub','${u}', false); select public.reklam_odul();`).split("\n").pop());
assert.equal(Number(reklamsiz.sonuc.odul), 250);
assert.equal(psql(`select para::int from oyun.cuzdan where user_id='${u}'`), "1500");
console.log("  ✓ SQL: yetki, tekillik, günlük sınır, reklamsız hak, onaysız yedek silme");
console.log("\nADMOB SSV TESTİ GEÇTİ");
