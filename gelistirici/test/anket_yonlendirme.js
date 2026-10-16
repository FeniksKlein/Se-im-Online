// Çalıştır: node gelistirici/test/anket_yonlendirme.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const kok = path.join(__dirname, "..");
const merkez = fs.readFileSync(path.join(kok, "www/siyaset_merkezi.js"), "utf8");
const hayat = fs.readFileSync(path.join(kok, "www/siyasi_hayat.js"), "utf8");
const yayindakiMerkez = fs.readFileSync(path.join(kok, "../docs/siyaset_merkezi.js"), "utf8");
assert.match(merkez, /onclick="window\.smAnketeGit\(\)">Ankette oyunu ver/);
assert.match(yayindakiMerkez, /onclick="window\.smAnketeGit\(\)">Ankette oyunu ver/);

async function yonlendirmeSinav(veri, hata) {
  let acilan = 0;
  const uyari = [];
  const anketEkrani = () => {};
  const ctx = {
    window: {},
    API: { rpc: async ad => {
      assert.equal(ad, "anket_durum");
      if (hata) throw new Error(hata);
      return veri;
    } },
    anketEkrani,
    ekranAc: fn => { assert.equal(fn, anketEkrani); acilan++; },
    toast: (...args) => uyari.push(args),
    hataCevir: mesaj => mesaj
  };
  vm.runInNewContext(merkez, ctx);
  await ctx.window.smAnketeGit();
  return { acilan, uyari };
}

async function ekranSinav(veri) {
  let ekran = "";
  let cizildi = 0;
  const ctx = {
    API: { rpc: async ad => {
      assert.equal(ad, "anket_durum");
      return veri;
    } },
    yukleniyor: () => {},
    iskelet: (_, icerik) => { ekran = icerik; },
    e: x => x,
    hataCevir: x => x
  };
  vm.runInNewContext(hayat, ctx);
  ctx.anketCiz = () => { cizildi++; };
  await vm.runInNewContext("anketEkrani()", ctx);
  return { ekran, cizildi };
}

(async () => {
  const acik = { hafta: "2026-10-12", partiler: [{ id: 1, ad: "Örnek Parti", oy: 0 }] };
  assert.equal((await yonlendirmeSinav(acik)).acilan, 1, "Açık anketin ekranı açılmalı");
  for (const bos of [null, { partiler: [] }, { acik: false, partiler: acik.partiler }]) {
    const sonuc = await yonlendirmeSinav(bos);
    assert.equal(sonuc.acilan, 0, "Açık anket yoksa yönlendirme yapılmamalı");
    assert.match(sonuc.uyari[0][0], /Şu an açık anket yok/);
    const ekran = await ekranSinav(bos);
    assert.equal(ekran.cizildi, 0);
    assert.match(ekran.ekran, /Şu an açık anket yok/);
  }
  assert.equal((await ekranSinav(acik)).cizildi, 1);
  const hata = await yonlendirmeSinav(null, "Bağlantı hatası");
  assert.equal(hata.acilan, 0);
  assert.match(hata.uyari[0][0], /Bağlantı hatası/);
  console.log("Anket yönlendirme testleri başarılı.");
})().catch(err => { console.error(err); process.exitCode = 1; });
