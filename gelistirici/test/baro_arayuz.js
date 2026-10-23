// Avukatlık kontenjanı + Türkiye Barosu arayüz testi. Ağ yok; sahte RPC. docs/ klasörünü (canlı web) sunar.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/baro_arayuz.js [ekran-goruntusu-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const T = new Date(Date.now() + 3600e3).toISOString(), G = new Date(Date.now() - 86400e3).toISOString();

const AVUKAT = (uye, baskan) => ({
  hesap_uygun: true, yonetici: false, harc: 100000, kontenjan: 4, aktif_avukat: 3, bekleyen: 2,
  kontenjan_bilgi: { aktif_oyuncu: 36, oran: 10, min: 2, elle: null, pasif_gun: 14 },
  bekleme_listesi: [{ sira: 1, kad: 'Ayşe', basvuru: G, benim: false }, { sira: 2, kad: 'Mehmet', basvuru: G, benim: false }],
  akademi: { baslangic: G, egitim_bitti: G, sinav_gecildi: G, son_puan: 18, pratik1: G, pratik2: G },
  ruhsat: { durum: 'aktif', sira: null, ruhsat_at: G, gerekce: null, harc_odendi: true },
  calisabilir: uye, engel: uye ? null : 'Mesleği icra etmek için Türkiye Barosu levhasına kayıtlı olmalısın.',
  baro: { uyeyim: uye, sicil: uye ? 1001 : null, durum: uye ? 'aktif' : null },
  sinav_sorular: [], uygulamalar: [],
  avukatlar: [{ id: 'a', kad: 'Celal', sicil: 1001, calisabilir: true, tamamlanan: 3, kazanilan: 2, oran: 66.7, ruhsat_at: G, disiplin: { uyari: 0, kinama: 0, yasak: 0 } },
              { id: 'b', kad: "Uygar'zk", sicil: null, calisabilir: false, tamamlanan: 0, kazanilan: 0, oran: null, ruhsat_at: G, disiplin: { uyari: 1, kinama: 0, yasak: 1 } }],
  burolar: [], benim_burom: null,
  gecmis: [{ olay: 'baro_kayit', aciklama: 'Türkiye Barosu levhasına 1001 sicil numarasıyla kaydoldu', zaman: G }, { olay: 'aktif', aciklama: 'Kontenjana yerleşti, ruhsat verildi', zaman: G }]
});
const BEKLEYEN_AKADEMI = { hesap_uygun: true, yonetici: true, harc: 100000, kontenjan: 4, aktif_avukat: 4, bekleyen: 3,
  kontenjan_bilgi: { aktif_oyuncu: 36, oran: 10, min: 2, elle: null, pasif_gun: 14 },
  bekleme_listesi: [{ sira: 1, kad: 'Ayşe', basvuru: G }, { sira: 2, kad: 'Ben', basvuru: G, benim: true }],
  akademi: { baslangic: G, egitim_bitti: G, sinav_gecildi: G, son_puan: 17, pratik1: G, pratik2: G },
  ruhsat: { durum: 'bekliyor', sira: 2, harc_odendi: false }, calisabilir: false, engel: null, baro: { uyeyim: false },
  sinav_sorular: [], uygulamalar: [], avukatlar: [], burolar: [], benim_burom: null, gecmis: [] };
const BARO_IC = {
  ad: 'Türkiye Barosu', kurulus: G, uye_sayi: 2, baskan: 'Celal', baskan_id: 'a', gecici: true, giris_ucret: 10000, aidat: 5000,
  uyeyim: true, benim_durum: 'aktif', ruhsatliyim: true, kayit_olabilir: false, icerde: true, gozlemci: false, baskanim: true, sonraki_secim: T,
  kasa: 70000, adli_yardim_ucret: 20000, adli_yardim_sinir: 50000,
  ben: { sicil: 1001, kayit: G, ilk_kayit: G, aidat_bitis: T, gonullu: false, calisabilir: true, engel: null },
  duyurular: [{ id: 1, yazar: 'Celal', metin: 'Baro toplantısı cuma günü <b>20:00</b>.', zaman: G, silebilirim: true }],
  mesajlar: [{ id: 2, yazar: 'Uygarzk', benim: false, metin: 'Merhaba meslektaşlar', zaman: G, silebilirim: true }],
  levha: [{ id: 'a', kad: 'Celal', sicil: 1001, kayit: G, gonullu: false, baskan: true, burosu: null, il: 'İstanbul', aktif_dosya: 1, yasak_bitis: null, disiplin: { uyari: 0, kinama: 0, yasak: 0 } },
          { id: 'b', kad: "Uygar'zk", sicil: 1002, kayit: G, gonullu: true, baskan: false, burosu: 'Adalet Hukuk', il: 'İzmir', aktif_dosya: 0, yasak_bitis: T, disiplin: { uyari: 0, kinama: 0, yasak: 1 } }],
  bekleyen_davalar: [{ id: 25, tur: 'hakaret', davaci: 'Eyetkin', davali: 'Sadık', davaci_bos: true, davali_bos: true, teklif: 1, adli_yardim: true, taraf_miyim: false, savunma_son: T, acilis: G }],
  adli_yardim: [{ id: 1, dava: 25, taraf: 'davali', talep_eden: 'Sadık', gerekce: 'Param yetmiyor.', durum: 'bekliyor', avukat: null, ucret: 0, zaman: G }],
  gonulluler: [{ id: 'a', kad: 'Celal', baskan: true }, { id: 'b', kad: "Uygar'zk", baskan: false }],
  disiplin: [{ id: 1, avukat: "Uygar'zk", avukat_id: 'b', durum: 'bekliyor', ceza: null, zaman: G, dava: 25, metin: 'Duruşmada karşı tarafa hakaret etti ve dosyayı geciktirdi.', sikayetci: 'Eyetkin', karar_verebilirim: true }],
  secim: { id: 1, donem: '2026-11', durum: 'oy', aday_bas: G, oy_bas: G, oy_son: T, kazanan: null, katilim: 0, sonuc: [],
    adaylar: [{ id: 'a', kad: 'Celal', vaat: 'Adli yardımı büyüteceğim.', benim: true }, { id: 'b', kad: "Uygar'zk", vaat: 'Aidatı düşüreceğim.', benim: false }], oyum: null, oy_hakkim: true, adayim: true },
  kasa_hareket: [{ tutar: 25000, tur: 'ruhsat_payi', aciklama: 'Ruhsat harcından baro payı · Celal', zaman: G }, { tutar: -20000, tur: 'adli_yardim', aciklama: 'Dava #25 adli yardım ücreti', zaman: G }]
};
const BARO_DIS = { ad: 'Türkiye Barosu', uye_sayi: 2, baskan: 'Celal', gecici: true, giris_ucret: 10000, aidat: 5000, uyeyim: false, ruhsatliyim: false, kayit_olabilir: false, icerde: false, gozlemci: false, baskanim: false, sonraki_secim: T };

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  async function sayfa(senaryo) {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(senaryo + ': ' + e.message));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => typeof adliyeHtml === 'function' && window.BARO_YUKLENDI);
    return page;
  }
  async function kur(page, s) {
    await page.evaluate(({ s, T, G }) => {
      window.calls = [];
      const DAVA = { id: 25, davaci: 'Eyetkin', davali: 'Ben', tur: 'hakaret', iddia: 'Test iddiası yeterince uzun yazıldı.', delil: '', acilis: G, savunma_son: T, savunma_geldi: false, durum: 'acik', karar: null, davalimiyim: true, davacimiyim: false };
      API = { rpc: async (ad, args) => { calls.push({ ad, args });
        const sabit = { adliye_durum: { ben: 'Ben', parti_id: null, cb_miyim: false, hakim: 'Yargıç', hakim_miyim: false, partiler: [], davalar: [DAVA], aflar: [], atamalar: [] },
          adliye_siyasi_bilgi: { oneri_donemi: 1, oneriler: [], secimler: [], itirazlar: [] }, avukat_primlerim: [], avukat_durum: s.avukat, baro_durum: s.baro,
          adliye_detay: { beyanlar: [], yorumlar: [], ilgililer: [] }, avukat_dava_durum: { teklifler: [{ id: 3, avukat: 'Celal', taraf: 'davali', tutar: 15000, prim: 20, aciklama: 'Davanızı alırım', durum: 'bekliyor', cevaplayabilirim: true }], vekaletler: [{ id: 9, avukat: "Uygar'zk", taraf: 'davaci', muvekkil: 'Eyetkin', ucret: 0, aktif: false, benim: false }] },
          avukat_pazarlik_liste: [], baro_dava_bilgi: { benim_taraf: 'davali', vekilim_var: false, dava_acik: true, sinir: 50000, cuzdan: 30000, baro_uye_sayi: 2, talepler: [], sikayet_edilebilir: [{ id: 'b', kad: "Uygar'zk" }] },
          baro_kaydol: { tamam: true, sicil: 1003 }, baro_mesaj_gonder: { id: 5 }, baro_oy_ver: { tamam: true }, baro_adli_yardim_karar: { durum: 'atandi', ucret: 20000 }, baro_sikayet_karar: { tamam: true } };
        if (ad in sabit) return sabit[ad];
        throw new Error('sahte: ' + ad); } };
      D.durum = { profil: { il_id: 34, kad: 'Ben', parti: null, makamlar: [], cuzdan: { para: 30000 } } }; D.sekme = 'adliye'; D.yigin = [];
    }, { s, T, G });
  }
  const yaz = async (page, ad) => { if (shot) await page.screenshot({ path: path.join(shot, ad + '.png'), fullPage: false }); };

  // 1) Baroya kayıtlı başkan avukat
  let page = await sayfa('uye');
  await kur(page, { avukat: AVUKAT(true, true), baro: BARO_IC });
  await page.evaluate(() => adliyeEkrani());
  await page.waitForSelector('text=Levhaya kayıtlı avukat');
  let t = await page.locator('#icerik').textContent();
  assert.match(t, /Türkiye Barosu/); assert.match(t, /Celal \(geçici/); assert.match(t, /Baro binasına gir/);
  assert.match(t, /Kontenjan \(dolu \/ toplam\)3 \/ 4 · 1 boş/); assert.match(t, /Her 10 aktif oyuncuya 1 ruhsat/); assert.match(t, /Baro sicil 1001/);
  assert.match(t, /Baro kaydı yok/); assert.match(t, /Disiplin: 1 uyarı, 1 işten yasaklama/);
  await yaz(page, '1_adliye');
  await page.getByRole('button', { name: /Baro binasına gir/ }).first().click();
  await page.waitForSelector('text=Meslektaşlar panosu');
  t = await page.locator('#icerik').textContent();
  assert.match(t, /Baro kasası70\.000 ₺/); assert.match(t, /Baro başkanısın \(geçici\)/);
  assert.equal(await page.locator('#icerik b >> text=20:00').count(), 0, 'HTML kaçışı');
  await yaz(page, '2_pano');
  await page.fill('#baroMesajMetin', 'Herkese merhaba');
  await page.getByRole('button', { name: 'Gönder', exact: true }).click();
  await page.waitForFunction(() => calls.some(c => c.ad === 'baro_mesaj_gonder'));
  assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'baro_mesaj_gonder').args), { p_metin: 'Herkese merhaba', p_duyuru: false });
  for (const [sek, beklenen, ad] of [['Davalar', /Avukat bekleyen davalar \(1\)/, '3_davalar'], ['Levha', /Sicil 1002/, '4_levha'], ['Seçim', /Oylama sürüyor/, '5_secim'], ['Disiplin', /Disiplin kurulu/, '6_disiplin'], ['Hesabım', /Sicil numarası1001/, '7_hesap']]) {
    await page.locator('.segment button', { hasText: sek }).click();
    await page.waitForFunction(b => document.querySelector('#icerik').textContent.match(new RegExp(b)), beklenen.source);
    await yaz(page, ad);
  }
  // Seçimde oy (adı tırnak içeren aday)
  await page.locator('.segment button', { hasText: 'Seçim' }).click();
  await page.waitForSelector('text=Oylama sürüyor');
  await page.locator('button', { hasText: 'Oy ver' }).nth(1).click();
  await page.locator('#evet').click();
  await page.waitForFunction(() => calls.some(c => c.ad === 'baro_oy_ver'));
  assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'baro_oy_ver').args), { p_aday: 'b' });
  // Adli yardım görevlendirme
  await page.locator('.segment button', { hasText: 'Davalar' }).click();
  await page.getByRole('button', { name: 'Karar ver' }).click();
  await page.selectOption('#baroAdliAvukat', 'b');
  await page.getByRole('button', { name: 'Görevlendir' }).click();
  await page.waitForFunction(() => calls.some(c => c.ad === 'baro_adli_yardim_karar'));
  assert.equal(await page.evaluate(() => calls.find(c => c.ad === 'baro_adli_yardim_karar').args.p_avukat), 'b');
  // Dava dosyası: avukat paneli + baro kartı
  await page.evaluate(() => ekranAc(() => adliyeDosya(25)));
  await page.waitForSelector('#baroDavaKart');
  t = await page.locator('#icerik').textContent();
  assert.match(t, /Adli yardım iste \(ücretsiz avukat\)/); assert.match(t, /Ücretsiz \/ adli yardım/); assert.match(t, /başarı primi en fazla %25/);
  const sira = await page.evaluate(() => { const a = document.querySelector('#avukatHukukPanel'), b = document.querySelector('#baroDavaKart'); return !!(a && b && (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING)); });
  assert.ok(sira, 'Baro kartı avukat panelinin ardından gelmeli');
  await page.locator('#baroDavaKart summary').click();
  await yaz(page, '8_dosya');
  await page.close();

  // 2) Ruhsatlı ama baroya kayıtsız
  page = await sayfa('kayitsiz');
  await kur(page, { avukat: AVUKAT(false), baro: { ...BARO_DIS, ruhsatliyim: true, kayit_olabilir: true } });
  await page.evaluate(() => adliyeEkrani());
  await page.waitForSelector('text=Levhaya kaydol');
  t = await page.locator('#icerik').textContent();
  assert.match(t, /Mesleği icra etmek için Türkiye Barosu levhasına kaydolmalısın/);
  await page.getByRole('button', { name: 'Levhaya kaydol' }).first().click();
  await page.locator('#evet').click();
  await page.waitForFunction(() => calls.some(c => c.ad === 'baro_kaydol'));
  await page.close();

  // 3) Avukat olmayan / bekleme listesindeki oyuncu: kapı kapalı; yönetici ayarı görünür
  page = await sayfa('disari');
  await kur(page, { avukat: BEKLEYEN_AKADEMI, baro: BARO_DIS });
  await page.evaluate(() => adliyeEkrani());
  await page.waitForSelector('text=Bekleme listesinde');
  t = await page.locator('#icerik').textContent();
  assert.match(t, /🔒 Baro binasına yalnız ruhsatlı/); assert.doesNotMatch(t, /Baro binasına gir/);
  assert.match(t, /Bekleme listesinde 2\. sıradasın/); assert.match(t, /Cüzdanında 30\.000 ₺ var/); assert.match(t, /Kontenjan ayarı \(yönetici\)/);
  await yaz(page, '9_disari');
  await page.evaluate(() => ekranAc(baroEkrani));
  await page.waitForSelector('text=Kapı kapalı');
  await page.close();

  await browser.close();
  if (hatalar.length) { console.error(hatalar.join('\n')); process.exit(1); }
  console.log('baro_arayuz: tamam');
})().catch(e => { console.error(e); process.exit(1); });
