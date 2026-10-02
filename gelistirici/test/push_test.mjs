// Push gönderici testi: sahte Google OAuth + sahte Firebase + gerçek veritabanı (service_role).
// Çalıştır (asama3.py'den sonra): node test/push_test.mjs
import { calistir, erisimAnahtari } from "../supabase/functions/push-gonder/cekirdek.mjs";
import { generateKeyPairSync, createVerify } from "node:crypto";
import { execFileSync } from "node:child_process";
import assert from "node:assert";

const psql = (sql) => execFileSync("psql", ["-h", "/tmp", "-U", "postgres", "-d", "oyun_test", "-At", "-q", "-v", "ON_ERROR_STOP=1", "-c", sql], { encoding: "utf8" }).trim();
const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const hesap = {
  project_id: "secim-online-test", client_email: "push@secim-online-test.iam.gserviceaccount.com",
  private_key: privateKey.export({ type: "pkcs8", format: "pem" }), token_uri: "https://oauth2.googleapis.com/token"
};

// Kuyruğa sınama kayıtları
const u = psql(`select id from oyun.profiller where kad='Vatandas'`);
psql(`delete from oyun.push_kuyruk; delete from oyun.cihazlar where user_id='${u}';
      insert into oyun.cihazlar(token,user_id,platform) values ('${"iyi_token_" + "a".repeat(30)}','${u}','ios'),('${"bozuk_token_" + "b".repeat(30)}','${u}','android');
      insert into oyun.push_kuyruk(user_id,baslik,govde,veri) values ('${u}','Kişisel','Atandın','{"ekran":"bildirim"}');
      insert into oyun.push_kuyruk(konu,baslik,govde,veri) values ('s_tum','Bugün seçim var!','Sandıklar açık','{"ekran":"secim","id":7}');
      insert into oyun.push_kuyruk(kosul,baslik,govde) values ('''p_il_35'' in topics && ''p_parti_1'' in topics','Aday','Bana oy verin');
      insert into oyun.push_kuyruk(konu,baslik,govde) values ('hata_konusu','Hata','Firebase reddedecek');`);

const gonderilen = [];
let oauthCagri = 0;
async function sahteFetch(url, ist) {
  if (url === "https://oauth2.googleapis.com/token") {
    oauthCagri++;
    const jwt = new URLSearchParams(ist.body).get("assertion");
    const [b, i, imza] = jwt.split(".");
    const dogru = createVerify("RSA-SHA256").update(b + "." + i).verify(publicKey, Buffer.from(imza, "base64url"));
    assert.ok(dogru, "JWT imzası doğrulanamadı");
    const iddia = JSON.parse(Buffer.from(i, "base64url").toString());
    assert.equal(iddia.iss, hesap.client_email);
    assert.equal(iddia.scope, "https://www.googleapis.com/auth/firebase.messaging");
    return new Response(JSON.stringify({ access_token: "erisim123", expires_in: 3600 }), { status: 200 });
  }
  if (url.startsWith("https://fcm.googleapis.com/v1/projects/secim-online-test/messages:send")) {
    assert.equal(ist.headers.Authorization, "Bearer erisim123");
    const m = JSON.parse(ist.body).message;
    gonderilen.push(m);
    if (m.token && m.token.startsWith("bozuk")) return new Response(JSON.stringify({ error: { status: "NOT_FOUND", details: [{ errorCode: "UNREGISTERED" }] } }), { status: 404 });
    if (m.topic === "hata_konusu") return new Response("sunucu hatası", { status: 500 });
    return new Response(JSON.stringify({ name: "projects/x/messages/1" }), { status: 200 });
  }
  if (url.startsWith("http://yerel/rest/v1/rpc/")) {
    assert.equal(ist.headers.apikey, "servis-anahtari");
    const fn = url.split("/").pop(), govde = JSON.parse(ist.body);
    const arg = fn === "push_al" ? String(govde.p_limit) : `'${JSON.stringify(govde.p_sonuc).replace(/'/g, "''")}'::jsonb`;
    const out = psql(`set role service_role; select public.${fn}(${arg});`);
    return new Response(out.split("\n").pop(), { status: 200 });
  }
  throw new Error("beklenmeyen istek: " + url);
}

const sonuc = await calistir({ supabaseUrl: "http://yerel", servisAnahtari: "servis-anahtari", hesap, fetch: sahteFetch });
console.log("   Sonuç:", sonuc);
assert.equal(oauthCagri, 1);
assert.equal(sonuc.alinan, 4);
assert.equal(gonderilen.length, 5);                        // 2 cihaz + konu + koşul + hatalı konu
const kisisel = gonderilen.filter((m) => m.token);
assert.equal(kisisel[0].notification.title, "Kişisel");
assert.equal(kisisel[0].data.ekran, "bildirim");
const konu = gonderilen.find((m) => m.topic === "s_tum");
assert.equal(konu.data.id, "7");                           // veri alanları metne çevrildi
assert.ok(gonderilen.find((m) => m.condition === "'p_il_35' in topics && 'p_parti_1' in topics"));
assert.equal(psql(`select count(*) from oyun.cihazlar where token like 'bozuk_token_%'`), "0");   // geçersiz cihaz silindi
assert.equal(psql(`select count(*) from oyun.cihazlar where token like 'iyi_token_%'`), "1");
assert.equal(psql(`select count(*) from oyun.push_kuyruk where gonderildi is not null`), "3");
assert.match(psql(`select hata from oyun.push_kuyruk where konu='hata_konusu'`), /^500/);
// hatalı kayıt 2 dk sonra tekrar denenir, 3. denemeden sonra kapanır
psql(`update oyun.push_kuyruk set alindi = now() - interval '3 minutes', deneme = 2 where konu='hata_konusu'`);
await calistir({ supabaseUrl: "http://yerel", servisAnahtari: "servis-anahtari", hesap, fetch: sahteFetch });
assert.notEqual(psql(`select gonderildi from oyun.push_kuyruk where konu='hata_konusu'`), "");
// boş kuyrukta Google'a hiç gidilmez
const once = oauthCagri;
const bos = await calistir({ supabaseUrl: "http://yerel", servisAnahtari: "servis-anahtari", hesap, fetch: sahteFetch });
assert.deepEqual(bos, { alinan: 0, gonderilen: 0 }); assert.equal(oauthCagri, once);
console.log("  ✓ Push gönderici: Google OAuth JWT (RS256) imzası doğru, kişisel/konu/koşul mesajları Firebase biçiminde, geçersiz cihaz silindi, hatalı kayıt yeniden denendi ve 3 denemede kapandı, boş kuyrukta istek yok");
console.log("\nPUSH TESTİ GEÇTİ");
