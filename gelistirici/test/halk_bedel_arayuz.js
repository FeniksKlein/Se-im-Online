// Halk Hareketleri 5.0 · Sokağın Faturası arayüz testi (sahte RPC, 390 ve 320 px)
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/halk_bedel_arayuz.js
const fs = require('fs'), path = require('path'), assert = require('node:assert/strict');
const { chromium } = require('playwright');
const kok = path.join(__dirname, '../..');
const src = fs.readFileSync(path.join(kok, 'docs/halk-org-davet.js'), 'utf8');
assert.equal(src, fs.readFileSync(path.join(kok, 'www/halk-org-davet.js'), 'utf8'), 'docs ve www kopyası aynı olmalı');
for (const s of ['sokak_bedel_panel', 'sokak_bedel_ozet', 'sokak_bedel_islem', "['bedel','💸 Fatura']", 'data-hh5-bedel', 'data-hh5-ozet', 'window.__hh5.ciz'])
  assert.ok(src.includes(s), 'kaynakta yok: ' + s);
const sql = fs.readFileSync(path.join(kok, 'supabase/migrations/20261113040000_halk_ekonomi_bedeli.sql'), 'utf8');
for (const s of ['create or replace function oyun.sokak_bedel_tick()', 'public.sokak_bedel_islem', 'toplumsal_olay', "cron.schedule('halk-bedel'", 'grev_erteleme', 'kepenk', 'sokak_sure_carpani'])
  assert.ok(sql.includes(s), 'migration içinde yok: ' + s);
for (const yasak of [/\bdelete\s+from\b/i, /\bdrop\s+(table|column|function)\b/i, /\btruncate\b/i])
  assert.ok(!yasak.test(sql), 'migration yıkıcı ifade içeriyor: ' + yasak);

const simdi = new Date().toISOString();
const bicimler = (secili, org) => [
  ['tencere', 'Tencere-tava eylemi', '🍳', 0, 2, 0, 0, 0.004], ['miting', 'Meydan mitingi', '📣', 1, 1, 0, 0, 0.03],
  ['yuruyus', 'Yürüyüş ve kortej', '🚶', 2, 3, 25000, 3, 0.05], ['cadir', 'Çadır kenti / direniş nöbeti', '⛺', 2, 3, 40000, 2, 0.025],
  ['kepenk', 'Kepenk kapatma (esnaf eylemi)', '🏪', 3, 4, 60000, 4, 0.10], ['konvoy', 'Traktör ve TIR konvoyu', '🚜', 3, 5, 80000, 5, 0.09],
  ['genel_grev', 'Genel grev ve iş bırakma', '🛠️', 4, 8, 120000, 8, 0.16]
].map(([kod, ad, ikon, basamak, min, bedel, guc, k]) => ({
  kod, ad, ikon, basamak, min_kisi: min, bedel, guc, k_gsyh: k, aciklama: ad + ' açıklaması — uzun Türkçe metin satır kırmalı, ekrandan taşmamalı.',
  gercek: 'Gerçek hayattaki karşılığı.', karsi: 'Karşı önlem.', secili: kod === secili,
  uygun: org && kod !== secili && kod !== 'genel_grev' && kod !== 'konvoy',
  neden: kod === secili ? 'Şu anki biçim' : (!org ? 'Biçimi eylemi başlatan ya da düzenleyen kuruluşun başkanı seçer' : (kod === 'genel_grev' ? 'En az 8 gerçek katılımcı gerekir (şu an 7)' : null)),
  yon: basamak > 3 ? 'tirman' : basamak < 3 ? 'yumusat' : 'yatay'
}));
const araclar = (yetkili) => ['kriz_masasi', 'asgari_hizmet', 'lojistik_koridor', 'esnaf_destek', 'piyasa_istikrar', 'grev_erteleme', 'fatura'].map((kod, i) => ({
  kod, ad: 'Araç ' + kod, ikon: '🧭', kim: 'Vali · İçişleri Bakanı · Cumhurbaşkanı', aciklama: 'Açıklama ' + kod + ' — zarar azalır.',
  bedel: '0,05 milyar ₺ (Hazine)', sinir: '12 saatte bir', yetkili, uygun: yetkili && kod !== 'kriz_masasi',
  neden: yetkili ? (kod === 'kriz_masasi' ? 'Kriz merkezi kuruldu' : null) : 'Yetkin yok: Vali', kullanildi: kod === 'kriz_masasi' ? simdi : null
}));
function panel(rol) {
  const org = rol === 'org', cb = rol === 'cb';
  return {
    veri: true, eylem_id: 24, il: 'İstanbul', il_id: 34, durum: 'aktif', bitis: new Date(Date.now() + 9 * 3600e3).toISOString(), simdi,
    bicim: { kod: 'kepenk', ad: 'Kepenk kapatma (esnaf eylemi)', ikon: '🏪', aciklama: 'Esnaf kapatır.', basamak: 3, karsi: 'Esnafa zarar tazmini paketi.', zaman: simdi },
    bicimler: bicimler('kepenk', org),
    canli: { saatlik_gsyh: 0.101429, saatlik_hazine: 0.030429, saatlik_sirket: 20028.66, saniye_tl: 28174.72, son: simdi, saat: 20, sure_carpani: 1.13,
      sonraki: { saat: 4, carpan: 1.21 }, tepki_carpani: 0.7, ilk_tepki: simdi, ilk_tepki_dk: 0, katilimci: 7, kepenk: 1, il_pay: 0.2907, katsayi: 0.1,
      kirmizi: true, yogunluk: 0.513, onlem_carpani: 0.8, sirket_carpani: 0.85, lojistik_carpani: 1 },
    toplam: { gsyh: 0.267752, hazine: 0.080327, sirket: 25309.92, belediye: 817.34, tazmin: 0, artci: 0, gsyh_oran: 0.13 },
    seri: [{ saat: simdi, gsyh: 0.04, sirket: 5000 }, { saat: simdi, gsyh: 0.07, sirket: 9000 }, { saat: simdi, gsyh: 0.1, sirket: 20000 }],
    sirketler: [{ ad: 'UYGAR KAHVECİLİK', kanal: 'ticaret', kayip: 210.94, kepenk: true, sektor: 'ticaret', tazmin: 0 },
      { ad: 'ASLAN HOLDİNG - OTOMOBİL VE ÇOK UZUN ŞİRKET ADI ANONİM ŞİRKETİ', kanal: 'ticaret', kayip: 9765.45, kepenk: false, sektor: 'oto_galeri', tazmin: 0 }],
    etkilenen_sirket: 36,
    benim_sirketlerim: org ? [{ id: 273, ad: 'DS FAST FOOD', sektor: 'ticaret', kanal: 'ticaret', kepenk: false, kayip: 266.23, tazmin: 0 },
      { id: 220, ad: 'UYGAR KAHVECİLİK', sektor: 'ticaret', kanal: 'ticaret', kepenk: true, kayip: 210.94, tazmin: 0 }] : [],
    mudahaleler: [{ kim: 'cb', tur: 'kriz_masasi', aktif: true, bedel: 0.05, bitis: simdi, metin: '🧭 Cumhurbaşkanı Kriz Koordinasyon Merkezi kurdu.', taraf: 'devlet', unvan: 'Cumhurbaşkanı', zaman: simdi },
      { kim: 'org', tur: 'bicim:kepenk', aktif: false, bedel: 60000, bitis: simdi, metin: '🏪 Eylem biçim değiştirdi.', taraf: 'eylem', unvan: 'Düzenleyen', zaman: simdi }],
    araclar: araclar(cb),
    rol: { org, katilimci: org, devlet: cb, unvan: cb ? 'Cumhurbaşkanı' : null },
    eylemci: { fatura_kes: org, fatura_neden: org ? null : 'Eylemi düzenleyenler kullanır' },
    karne_tahmin: { harf: 'B', puan: 80 }, rapor: null, karne: null, puan: null
  };
}
const ozet = {
  simdi, bugun: { gsyh: 0.31, hazine: 0.093, sirket: 34191.42, belediye: 871.03, buyume: 0.0355, enflasyon: 0.0095, memnuniyet: 0.085, issizlik: 0, gsyh_oran: 0.15 },
  saatlik: 0.12, piyasa_riski: 3.54,
  aktif: [{ eylem_id: 24, il: 'İstanbul', bicim: 'kepenk', bicim_ad: 'Kepenk kapatma (esnaf eylemi)', ikon: '🏪', saatlik_gsyh: 0.1, toplam_gsyh: 0.27, toplam_hazine: 0.08, toplam_sirket: 25309, sure_carpani: 1.13, tepki_carpani: 0.7, artci: false },
    { eylem_id: 25, il: 'Ankara', bicim: 'miting', bicim_ad: 'Meydan mitingi', ikon: '📣', saatlik_gsyh: 0.02, toplam_gsyh: 0.03, toplam_hazine: 0.01, toplam_sirket: 3000, sure_carpani: 1.13, tepki_carpani: 0.7, artci: true }],
  raporlar: [{ eylem_id: 23, il: 'Adana', kapandi: simdi, karne: 'C', puan: 62, rapor: { sure_saat: 28.8, gsyh: 0.4, hazine: 0.12, sirket: 12000, tazmin: 3000, gsyh_oran: 0.2, artci_saat: 7.2, ilk_tepki_dk: 95 } }],
  onlemler: [{ tur: 'piyasa_istikrar', unvan: 'Hazine ve Maliye Bakanı', bitis: simdi, metin: 'Paket' }],
  toplam: { gsyh: 0.6, hazine: 0.18, sirket: 40000 }
};

async function senaryo(tarayici, genislik, rol) {
  const sayfa = await tarayici.newPage({ viewport: { width: genislik, height: 820 } });
  const hatalar = [];
  sayfa.on('pageerror', e => hatalar.push(String(e)));
  await sayfa.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;background:#0a1024;color:#fff;font-family:sans-serif}#icerik{padding:8px}</style></head><body><div id="icerik"></div></body></html>');
  await sayfa.evaluate(({ P, O }) => {
    window.__cagri = []; window.__toast = [];
    window.toast = (m, h) => window.__toast.push([m, !!h]);
    window.iskelet = function () {}; window.sokakHareketleriEkrani = async function () {}; // gerçek uygulamada index.html tanımlar
    window.API = { rpc: async (fn, a) => { window.__cagri.push([fn, a]); if (fn === 'sokak_bedel_panel') return P; if (fn === 'sokak_bedel_ozet') return O; if (fn === 'sokak_bedel_islem') return P; return null; } };
  }, { P: panel(rol), O: ozet });
  await sayfa.addScriptTag({ content: src });
  await sayfa.evaluate(() => { window.__tazele = 0; window.sokakHareketleriEkrani = () => { window.__tazele++; }; });
  return { sayfa, hatalar };
}
async function tasma(sayfa, ad) {
  const t = await sayfa.evaluate(() => ({ sw: document.documentElement.scrollWidth, w: window.innerWidth }));
  assert.ok(t.sw <= t.w + 1, ad + ': yatay taşma ' + JSON.stringify(t));
  const kucuk = await sayfa.evaluate(() => [...document.querySelectorAll('#hh4 .hh5-btn, #hh4 .hh5-basamak, #hh4 .hh5-satir')].filter(b => b.offsetParent && b.getBoundingClientRect().height < 44).map(b => b.textContent.trim().slice(0, 40)));
  assert.deepEqual(kucuk, [], ad + ': 44 px altı dokunma alanı');
}

(async () => {
  const tarayici = await chromium.launch();
  for (const w of [390, 320]) {
    // 1) ana ekran kartı
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, 'tarafsiz');
      await sayfa.evaluate(() => {
        document.getElementById('icerik').innerHTML = '<section id="hh4"><div data-hh5-ozet></div><button type="button" class="hh4-mkart" data-hh4-ac="24"><div class="alt"></div></button></section>';
        window.__hh4 = { gorunum: 'ana', sekme: 'akis' };
        window.__hh5.ciz(document.getElementById('hh4'), window.__hh4, null);
      });
      await sayfa.waitForSelector('#hh4 .hh5-kart');
      const metin = await sayfa.textContent('#hh4');
      for (const s of ['Sokağın faturası', 'Hazine', 'Borsa risk primi', 'İstanbul · Kepenk kapatma', 'artçı etki', 'kriz karneleri']) assert.ok(metin.includes(s), w + ' ana: ' + s);
      assert.equal(await sayfa.locator('#hh4 .hh4-mkart [data-hh5-etiket]').count(), 1, 'meydan kartında fatura etiketi');
      const s1 = await sayfa.textContent('#hh4 [data-hh5-sayac]'); await sayfa.waitForTimeout(1300);
      const s2 = await sayfa.textContent('#hh4 [data-hh5-sayac]');
      assert.notEqual(s1, s2, 'canlı sayaç ilerlemeli');
      await sayfa.click('#hh4 .hh5-satir[data-hh4-ac="24"]');
      assert.equal(await sayfa.evaluate(() => window.__hh4.sekme + ':' + window.__hh4.eylem + ':' + window.__tazele), 'bedel:24:1', 'satır eylemin Fatura sekmesini açmalı');
      await tasma(sayfa, w + ' ana');
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
    // 2) Cumhurbaşkanı: hükümet araçları
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, 'cb');
      await sayfa.evaluate(() => {
        document.getElementById('icerik').innerHTML = '<section id="hh4"><div class="hh4-uyarilar"></div><nav class="hh4-sekmeler"><button data-hh4-sekme="bedel">💸 Fatura</button></nav><div data-hh5-bedel="24"></div></section>';
        window.__hh4 = { gorunum: 'eylem', eylem: 24, sekme: 'bedel' };
        window.__hh5.ciz(document.getElementById('hh4'), window.__hh4, { id: 24 });
      });
      await sayfa.waitForSelector('#hh4 .hh5-arac');
      const metin = await sayfa.textContent('#hh4');
      for (const s of ['Fatura nasıl hesaplanıyor', 'Süre çarpanı', 'Hükümet tepkisi', '4 saat içinde söndürülmezse', 'Eylem biçimi', 'Hükümetin ekonomik önlemleri', 'Ekonomik kayıtlar', 'Etkilenen şirketler · 36', 'kriz karnesi']) assert.ok(metin.includes(s), w + ' cb: ' + s);
      assert.equal(await sayfa.locator('#hh4 [data-hh5-serit]').count(), 1, 'başlık şeridi');
      assert.equal(await sayfa.locator('#hh4 .hh5-arac').count(), 7, '7 hükümet aracı');
      assert.equal(await sayfa.locator('#hh4 .hh5-basamak').count(), 7, '7 eylem biçimi');
      assert.equal(await sayfa.locator('#hh4 .hh5-basamak[data-hh5-onayac]').count(), 0, 'CB biçim seçemez');
      // asgari hizmet: onay → RPC
      await sayfa.click('#hh4 [data-hh5-onayac="arac:asgari_hizmet"]');
      await sayfa.click('#hh4 [data-hh5-onaykutu="arac:asgari_hizmet"] [data-hh5-islem]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_bedel_islem'));
      let son = await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').pop());
      assert.deepEqual(son[1], { p_eylem: 24, p_islem: 'asgari_hizmet', p_veri: {} });
      // grev erteleme: gerekçe zorunlu, 16 px
      await sayfa.click('#hh4 [data-hh5-onayac="arac:grev_erteleme"]');
      const fs16 = await sayfa.evaluate(() => parseFloat(getComputedStyle(document.querySelector('#hh5Gerekce')).fontSize));
      assert.ok(fs16 >= 16, 'gerekçe kutusu en az 16 px');
      await sayfa.fill('#hh5Gerekce', 'kısa');
      await sayfa.click('#hh4 [data-hh5-onaykutu="arac:grev_erteleme"] [data-hh5-islem]');
      assert.equal(await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').length), 1, 'kısa gerekçe gönderilmemeli');
      assert.ok(await sayfa.evaluate(() => window.__toast.some(t => t[1] && /20 karakter/.test(t[0]))), 'kısa gerekçe uyarısı');
      await sayfa.fill('#hh5Gerekce', 'Hastanelerde ve enerji tesislerinde hizmet durdu; genel sağlık tehlikede.');
      await sayfa.click('#hh4 [data-hh5-onaykutu="arac:grev_erteleme"] [data-hh5-islem]');
      await sayfa.waitForFunction(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').length === 2);
      son = await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').pop());
      assert.equal(son[1].p_islem, 'grev_erteleme'); assert.ok(son[1].p_veri.gerekce.length >= 20);
      await tasma(sayfa, w + ' cb');
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
    // 3) düzenleyen: biçim merdiveni, kepenk, faturayı kes
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, 'org');
      await sayfa.evaluate(() => {
        document.getElementById('icerik').innerHTML = '<section id="hh4"><div class="hh4-uyarilar"></div><nav class="hh4-sekmeler"><button data-hh4-sekme="bedel">💸 Fatura</button></nav><div data-hh5-bedel="24"></div></section>';
        window.__hh4 = { gorunum: 'eylem', eylem: 24, sekme: 'bedel' };
        window.__hh5.ciz(document.getElementById('hh4'), window.__hh4, { id: 24 });
      });
      await sayfa.waitForSelector('#hh4 .hh5-basamak');
      const metin = await sayfa.textContent('#hh4');
      for (const s of ['Şirketlerin ve bu eylem', 'DS FAST FOOD', 'Kepenk indir', 'Kepengi aç', 'Faturayı hükümete kes', 'En az 8 gerçek katılımcı']) assert.ok(metin.includes(s), w + ' org: ' + s);
      assert.equal(await sayfa.locator('#hh4 .hh5-arac .hh5-btn').count(), 0, 'yetkisiz kişide hükümet aracı düğmesi yok');
      await sayfa.click('#hh4 [data-hh5-onayac="bicim:tencere"]');
      await sayfa.click('#hh4 [data-hh5-onaykutu="bicim:tencere"] [data-hh5-islem]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_bedel_islem'));
      let son = await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').pop());
      assert.deepEqual(son[1], { p_eylem: 24, p_islem: 'bicim', p_veri: { kod: 'tencere' } });
      await sayfa.click('#hh4 [data-hh5-onayac="kepenk:273"]');
      await sayfa.click('#hh4 [data-hh5-onaykutu="kepenk:273"] [data-hh5-islem]');
      await sayfa.waitForFunction(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').length === 2);
      son = await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').pop());
      assert.deepEqual(son[1], { p_eylem: 24, p_islem: 'kepenk', p_veri: { sirket: 273 } });
      await sayfa.click('#hh4 [data-hh5-islem="kepenk_ac"]');
      await sayfa.waitForFunction(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').length === 3);
      son = await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').pop());
      assert.deepEqual(son[1], { p_eylem: 24, p_islem: 'kepenk_ac', p_veri: { sirket: 220 } });
      await sayfa.click('#hh4 [data-hh5-onayac="fatura_kes"]');
      await sayfa.click('#hh4 [data-hh5-onaykutu="fatura_kes"] [data-hh5-islem]');
      await sayfa.waitForFunction(() => window.__cagri.filter(c => c[0] === 'sokak_bedel_islem').length === 4);
      await tasma(sayfa, w + ' org');
      if (w === 390) await sayfa.screenshot({ path: '/tmp/hh5_org_390.png', fullPage: true });
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
  }
  {
    const { sayfa } = await senaryo(tarayici, 390, 'cb');
    await sayfa.evaluate(() => {
      document.getElementById('icerik').innerHTML = '<section id="hh4"><div class="hh4-uyarilar"></div><nav class="hh4-sekmeler"><button data-hh4-sekme="bedel">💸 Fatura</button></nav><div data-hh5-bedel="24"></div></section>';
      window.__hh5.ciz(document.getElementById('hh4'), { sekme: 'bedel' }, { id: 24 });
    });
    await sayfa.waitForSelector('#hh4 .hh5-arac');
    await sayfa.screenshot({ path: '/tmp/hh5_cb_390.png', fullPage: true });
    await sayfa.close();
  }
  await tarayici.close();
  console.log('TAMAM: Sokağın Faturası arayüzü (ana kart, CB araçları, düzenleyen biçim/kepenk/fatura; 390 ve 320 px)');
})().catch(e => { console.error(e); process.exit(1); });
