// Mahkemede avukat zorunluluğu + Parti sözcüsü açıklamaları arayüz testi. Ağ yok; sahte RPC; docs/ sunulur.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/avukat_zorunlu_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const T = new Date(Date.now() + 86400e3).toISOString(), G = new Date(Date.now() - 3600e3).toISOString();
const ISLER = {
  avukat_miyim: false,
  benim: [{ id: 7, tur: 'dava', muvekkil: 'Ben', parti: null, hedef_tur: 'oyuncu', hedef_ad: 'Adem', dava_tur: 'hakaret', tazminat: null, metin: 'Genel sohbette hakaret etti.', delil: '', durum: 'avukat_bekliyor', avukat: null, ucret: 0, prim: 0, emanet: 0, olusturma: G,
    muvekkilim: true, teklifler: [{ id: 31, avukat: 'Celal', tutar: 20000, prim: 0, aciklama: 'Bugün sunarım', durum: 'bekliyor', benim: false }], teklif_sayi: 1 }],
  ustlendigim: [], acik: []
};
(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
  page.on('pageerror', e => hatalar.push(e.message));
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (u.hostname !== 'oyun.test') return r.abort();
    const f = path.join(KOK, decodeURIComponent(u.pathname));
    if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
    r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : 'text/html' });
  });
  await page.goto('http://oyun.test/index.html');
  await page.waitForFunction(() => window.AVUKAT_ZORUNLU_YUKLENDI && window.BARO_YUKLENDI);
  await page.evaluate(({ T, G, ISLER }) => {
    window.calls = [];
    const DAVA = { id: 26, davaci: 'Sadık', davali: 'Ben', tur: 'hakaret', iddia: 'Test iddiası yeterince uzun yazıldı.', delil: '', acilis: G, savunma_son: T, savunma_geldi: false, durum: 'acik', karar: null, davalimiyim: true, davacimiyim: false, temsil_iznim: false };
    const sabit = {
      adliye_durum: { ben: 'Ben', parti_id: 15, cb_miyim: false, hakim: 'Yargıç', hakim_miyim: false, partiler: [{ id: 15, ad: 'Milli Demokrasi Partisi', kisa: 'MDP', gb: 'Ben', sozcu: 'Sözcü1', gb_miyim: true, sozcu_muyum: false }, { id: 16, ad: 'Beta', kisa: 'BTA', gb: 'X', sozcu: null, gb_miyim: false, sozcu_muyum: false }], davalar: [DAVA], aflar: [], atamalar: [] },
      adliye_siyasi_bilgi: { oneri_donemi: 1, oneriler: [], secimler: [{ id: 3, tur: 'mv', donem: 'Ekim', itiraz_son: T }], itirazlar: [] },
      avukat_primlerim: [], avukat_durum: { hesap_uygun: true, harc: 100000, kontenjan: 4, aktif_avukat: 2, bekleyen: 0, kontenjan_bilgi: { oran: 10, min: 2, aktif_oyuncu: 36 }, bekleme_listesi: [], akademi: null, ruhsat: null, calisabilir: false, baro: { uyeyim: false }, avukatlar: [], burolar: [], gecmis: [] },
      baro_durum: { ad: 'Türkiye Barosu', uye_sayi: 2, baskan: 'Celal', gecici: true, giris_ucret: 10000, aidat: 5000, uyeyim: false, kayit_olabilir: false, icerde: false, sonraki_secim: T },
      hukuk_islerim: ISLER, adliye_kurum_listesi: [{ tur: 'dernek', id: '4', ad: 'Ege Derneği' }],
      adliye_detay: { beyanlar: [], yorumlar: [], ilgililer: [] }, adliye_dava_ek: null,
      avukat_dava_durum: { teklifler: [{ id: 3, avukat: 'Celal', taraf: 'davali', tutar: 15000, prim: 0, aciklama: '', durum: 'bekliyor', cevaplayabilirim: true }], vekaletler: [{ id: 9, avukat: 'Uygar', taraf: 'davaci', muvekkil: 'Sadık', ucret: 20000, aktif: true, benim: false }] },
      avukat_pazarlik_liste: [],
      baro_dava_bilgi: { benim_taraf: 'davali', vekilim_var: false, dava_acik: true, zorunlu: true, ilgili_miyim: false, muvekkil_taraf: 'davali', istinaf_vekili: false, istinaf_acik: false, sinir: 50000, cuzdan: 30000, baro_uye_sayi: 2, talepler: [], sikayet_edilebilir: [] },
      hukuk_is_olustur: { tamam: true, id: 8 }, hukuk_is_teklif_karar: { durum: 'kabul' },
      durum: { simdi: new Date().toISOString(), profil: { il_id: 34, kad: 'Ben', parti: { id: 15 }, makamlar: [], cuzdan: { para: 30000 }, gb: true, gby: false }, takvim: [], okunmamis: { bildirim: 0, ozel: 0 } },
      parti_detay: { id: 15, kisa: 'MDP', ad: 'Milli Demokrasi Partisi', renk: '#c0392b', amblem: 'x', sistem: false, kurulus: G, kurucu: 'Ben', uye: 5, vekil: 2, belediye: 1, kurulus_bit: null, uyesiyim: true, gb: 'Ben', gby: [], uyeler: [], gb_vekaleten: null },
      parti_sozcu_bilgi: { sozcu: 'Sözcü1', gb_miyim: true, genel_baskan: 'Ben' },
      parti_aciklamalari: { sozcu: 'Sözcü1', gb_miyim: true, yazabilirim: true, aciklamalar: [{ id: 1, yazar: 'Sözcü1', rol: 'sozcu', baslik: 'Ekonomi politikamız', metin: 'Asgari ücret önerimiz hazır <b>x</b>.', zaman: G, silebilirim: true }] },
      parti_aciklama_yap: { tamam: true, id: 2 }
    };
    API = { rpc: async (ad, args) => { calls.push({ ad, args }); if (ad in sabit) return JSON.parse(JSON.stringify(sabit[ad])); throw new Error('sahte: ' + ad); } };
    D.durum = sabit.durum; D.sekme = 'adliye'; D.yigin = [];
  }, { T, G, ISLER });
  const yaz = async ad => { if (shot) await page.screenshot({ path: path.join(shot, ad + '.png') }); };

  // Adliye ana sayfa
  await page.evaluate(() => adliyeEkrani());
  await page.waitForSelector('#hukukIslerimKart');
  let t = await page.locator('#icerik').textContent();
  assert.doesNotMatch(t, /Parti Sözcüleri \(/, 'sözcü listesi Adliye’den kalkmalı');
  assert.doesNotMatch(t, /parti sözcüsü yalnız yetkisi varsa temsil/);
  assert.match(t, /Davayı yalnız avukat açar/); assert.match(t, /Savunmayı ve beyanları yalnız tarafların avukatları sunar/);
  assert.match(t, /Kaybeden tarafın avukatı 24 saat/); assert.match(t, /genel başkanı avukat tutarak başvurabilir/);
  assert.match(t, /Avukatla dava aç/); assert.match(t, /Hukuki işlerim/); assert.match(t, /Av\. Celal · 20\.000 ₺/);
  const sira = await page.evaluate(() => { const x = document.querySelector('#icerik').textContent; return [x.indexOf('Yüksek Yargı'), x.indexOf('Levhaya kayıtlı avukat'), x.indexOf('Hukuki işlerim')]; });
  assert.ok(sira[0] < sira[1] && sira[1] < sira[2], 'sıra: mahkeme → baro → hukuki işlerim ' + sira);
  await page.evaluate(() => document.querySelector('#hukukIslerimKart').scrollIntoView());
  await yaz('z1_adliye_islerim');
  // Teklif kabul
  await page.locator('#hukukIslerimKart button', { hasText: 'Kabul et' }).click();
  await page.locator('#evet').click();
  await page.waitForFunction(() => calls.some(c => c.ad === 'hukuk_is_teklif_karar'));
  assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'hukuk_is_teklif_karar').args), { p_teklif: 31, p_kabul: true });
  // Dava talebi
  await page.evaluate(() => adliyeEkrani()); await page.waitForSelector('#hukukIslerimKart');
  await page.locator('button', { hasText: 'Avukatla dava aç' }).first().click();
  await page.waitForSelector('#hiGonder');
  await page.fill('#hiHedef', 'Adem'); await page.selectOption('#hiTur', 'tazminat'); await page.fill('#hiTaz', '25000');
  await page.fill('#hiIddia', 'Davalı ortak şirkette payımı devretmedi, zararım oluştu.');
  await yaz('z2_dava_talebi');
  await page.click('#hiGonder');
  await page.waitForFunction(() => calls.some(c => c.ad === 'hukuk_is_olustur'));
  const a = await page.evaluate(() => calls.find(c => c.ad === 'hukuk_is_olustur').args);
  assert.equal(a.p_tur, 'dava'); assert.equal(a.p_hedef_tur, 'oyuncu'); assert.equal(a.p_hedef, 'Adem'); assert.equal(a.p_dava_tur, 'tazminat'); assert.equal(a.p_tazminat, 25000); assert.equal(a.p_parti, null);
  assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'adliye_dava_ac' || c.ad === 'adliye_kurum_dava_ac').length), 0);
  // Seçim itirazı talebi
  await page.evaluate(() => adlSecimItirazModal(3));
  await page.fill('#hsGerekce', 'Sandık sonuçlarında bir ilde oy sayısı seçmen sayısını aşıyor.');
  await page.click('#hsGonder');
  await page.waitForFunction(() => calls.filter(c => c.ad === 'hukuk_is_olustur').length === 2);
  const s = await page.evaluate(() => calls.filter(c => c.ad === 'hukuk_is_olustur')[1].args);
  assert.equal(s.p_tur, 'secim_itiraz'); assert.equal(s.p_parti, 15); assert.equal(s.p_secim, 3);
  // Dava dosyası: taraf beyan düğmesi yok, uyarı var
  await page.evaluate(() => ekranAc(() => adliyeDosya(26)));
  await page.waitForSelector('#avukatHukukPanel');
  await page.waitForFunction(() => document.querySelector('#avukatHukukPanel').textContent.includes('avukatı yok'));
  t = await page.locator('#icerik').textContent();
  assert.doesNotMatch(t, /Savunma \/ beyan ver|Olay beyanı ver/); assert.doesNotMatch(t, /Parti sözcün/);
  assert.match(t, /davalı tarafın avukatı yok/);
  await yaz('z3_dosya');
  // Parti sayfası
  await page.evaluate(() => ekranAc(() => partiDetay(15)));
  await page.waitForSelector('#partiAciklamaKart');
  t = await page.locator('#icerik').textContent();
  assert.match(t, /Partinin resmî sesidir/); assert.doesNotMatch(t, /davalarda iddia ve savunma sunar/);
  assert.match(t, /Ekonomi politikamız/); assert.equal(await page.locator('#partiAciklamaKart b >> text=x').count(), 0, 'HTML kaçışı');
  await page.evaluate(() => document.querySelector('#partiAciklamaKart').scrollIntoView());
  await yaz('z4_parti');
  await page.fill('#paBaslik', 'Yeni açıklama'); await page.fill('#paMetin', 'Partimiz bu hafta Ege turuna çıkıyor.');
  await page.locator('#partiAciklamaKart button', { hasText: 'Parti adına açıkla' }).click();
  await page.waitForFunction(() => calls.some(c => c.ad === 'parti_aciklama_yap'));
  assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'parti_aciklama_yap').args), { p_parti: 15, p_baslik: 'Yeni açıklama', p_metin: 'Partimiz bu hafta Ege turuna çıkıyor.' });

  await browser.close();
  const gercek = hatalar.filter(m => !/sahte:/.test(m));
  if (gercek.length) { console.error(gercek.join('\n')); process.exit(1); }
  console.log('avukat_zorunlu_arayuz: tamam');
})().catch(e => { console.error(e); process.exit(1); });
