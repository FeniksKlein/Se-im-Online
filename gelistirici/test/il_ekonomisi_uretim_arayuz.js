// İl ekonomisi + üretim paneli + banka güven notu arayüz testi (02.11.2026, sunucu 160-161). Ağ yok; sahte RPC.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/il_ekonomisi_uretim_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const VERI = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/il_ekonomi_ornek.json'), 'utf8'));
const S = (dk) => new Date(Date.now() + dk * 60e3).toISOString();

const URUNLER = [
  { kod: 'ekmek', ad: 'Ekmek', grup: 'gida', kategori: 'market', maliyet: 6, parti: 200, dakika: 30, satis: 12, talep: 20 },
  { kod: 'su', ad: 'Su', grup: 'gida', kategori: 'market', maliyet: 4, parti: 300, dakika: 20, satis: 9, talep: 24 },
  { kod: 'un', ad: 'Un', grup: 'gida', kategori: 'market', maliyet: 85, parti: 60, dakika: 90, satis: 160, talep: 6 }];
const IST = VERI.bilgi['34'];
const PANEL = () => ({
  simdi: new Date().toISOString(),
  urunler: URUNLER,
  sirketler: [
    { id: 222, ad: 'Boğaz Gıda', sektor: 'sanayi', tur: 'fabrika', grup: 'gida', kategori: null, il: 34, il_ad: 'İstanbul', il_endeks: IST,
      kasa: 1831830, sermaye: 2000000, yonetici: true, kapasite: { katsayi: 1.5, tamamlanan_adet: 900, esdeger_parti: 4.5, sonraki_uretim_esdeger: 6, sonraki_sermaye: 3000000 } },
    { id: 300, ad: 'Munzur Market', sektor: 'ticaret', tur: 'magaza', kategori: 'market', il: 62, il_ad: 'Tunceli', il_endeks: VERI.bilgi['62'],
      kasa: 250000, sermaye: 300000, yonetici: true, sonraki_satis: S(40) }],
  stok: [{ sirket: 222, urun: 'ekmek', adet: 120, maliyet: 7.2, fiyat: 10 }],
  tedarikciler: [], oto: [], satislar: [], markalar: [],
  uretim: [
    { id: 3, sirket: 222, urun: 'un', adet: 40, maliyet: 4080, baslangic: S(-36), hazir: S(54), tamam: null, kaynak: null, teslim: S(58) },
    { id: 2, sirket: 222, urun: 'su', adet: 100, maliyet: 480, baslangic: S(-25), hazir: S(-3), tamam: null, kaynak: null, teslim: S(5) },
    { id: 1, sirket: 222, urun: 'ekmek', adet: 120, maliyet: 864, baslangic: S(-120), hazir: S(-90), tamam: S(-88), kaynak: null, teslim: null }]
});
const GM = {
  simdi: S(0), politika_faizi: 44.2,
  banka: { id: 227, ad: 'UYGAR BANKACILIK', kurulus: S(-6000), sermaye: 17711936, kasa: 11447694, yonetici: null, yonetebilir: true, renk: 'lacivert', slogan: 'Her zaman, en çok kazandıran.',
    emniyet_payi: 0, risk_profili: 'dengeli', gizlilik: 'gizli', ortaklar: [{ kad: 'Uygar', pay: 100, ben: true, kar_kasada: false }] },
  bilanco: { not: 'AAA', puan: 99, durum: 'saglam', nakit: 11447694, krediler: 354720, krediler_geciken: 0, krediler_izleme: 68818, geciken_taksit: 7244,
    kart_alacak: 0, kart_geciken: 0, kart_izleme: 0, dibs: 0, varlik: 11802414, vadesiz: 0, vadeli_anapara: 50000, vadeli_yukumluluk: 50750, yaklasan_odeme: 0, geciken_mevduat: 0,
    borc: 50750, ozkaynak: 11751664, sermaye: 17711936, birikmis_kar: -5960272, tampon: 1771193.6, rezerv: 1796193.6, emniyet_payi: 0, riskli_varlik: 354720,
    kredi_verilebilir: 9651500.4, dagitilabilir_kar: 0, sermaye_azaltilabilir: 9651500.4, dibs_alinabilir: 9651500.4,
    likidite: 457.91, sermaye_yeterlilik: 3312.9, takipteki_oran: 0, izleme_oran: 19.4, kredi_mevduat: 709.4, takipteki_ozkaynak: 0, kredi_agirlik: 0.2,
    not_etkenleri: [{ kod: 'izleme', ceza: 1, aciklama: 'Yakın izlemede 68.818 ₺ (taksidi 1-3 gündür gecikmiş). Takibe düşmeden ödenirse not etkilenmez.' }] },
  gelir7: { net: 1000, dibs: 0, faaliyet: 0, kart_faiz: 0, kredi_faiz: 1000, mevduat_faiz: 0, pos_komisyon: 0 },
  gelir30: { net: 1000, dibs: 0, faaliyet: 0, kart_faiz: 0, kredi_faiz: 1000, mevduat_faiz: 0, pos_komisyon: 0 },
  urunler: { mevduat7: 1, kredi24: 0.16, vadeler: {}, pos_komisyon: 2, paketler: [], otomatik: {}, asgari_not: 1100, kart_max: 300000, kredi_max: 300000 },
  bekleyen: { krediler: [], kartlar: [], poslar: [] },
  musteriler: [{ kad: 'Mert', acilis: S(-3000), not: 1500, not_ad: 'İyi', vadesiz: 0, vadeli: 0, kredi: 68818, kart: 0, teklif: null, bilgi: null }],
  krediler: [{ id: 96, kad: 'Mert', anapara: 70000, toplam: 72440, kalan: 68818, oran: 3.5, vade_gun: 20, durum: 'aktif', acilis: S(-3000), vade: S(20000), geciken: 7244,
    dava_acilabilir: true, icra: null, sinif: 2, gecikme_bas: S(-1800) }],
  kartlar: [], dibs: [], dibs_oran: { 1: 0.1, 7: 0.8, 30: 3.8 }, temettuler: [], hareketler: []
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  for (const genislik of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: genislik, height: 844 }, isMobile: true, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
    page.on('pageerror', e => hatalar.push(genislik + ': ' + e.message));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const ad = decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname);
      let f = path.join(KOK, ad); if (!fs.existsSync(f)) f = path.join(YEDEK, ad);
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => window.SO_IL_EKONOMI_V1 && window.BANKACILIK_V2 && typeof iskelet === 'function' && typeof window.ticaretMerkezEkrani === 'function', null, { timeout: 15000 });
    await page.waitForTimeout(600);
    await page.evaluate(({ VERI, GM, PNL }) => {
      const PANEL = () => Object.assign(JSON.parse(JSON.stringify(PNL)), { simdi: new Date().toISOString() });
      window.calls = [];
      const sahte = (ad, a) => {
        switch (ad) {
          case 'eko_ticaret_panel': return PANEL();
          case 'eko_otomasyon_panel': return { uretim: [], kendi: [], satis: [] };
          case 'eko_ticaret_islem': return { emir: 9, maliyet: 1, bitis: new Date(Date.now() + 30 * 60e3).toISOString() };
          case 'il_ekonomi_liste': return VERI.liste;
          case 'il_ekonomi_bilgi': return VERI.bilgi[String(a.p_il)];
          case 'banka_genel_mudurluk': return GM;
          case 'bel_ruhsat_merkezi': return { iller: VERI.liste.iller.map(x => ({ id: x.il_id, ad: x.il })).sort((x, y) => x.ad.localeCompare(y.ad, 'tr')), benim: [], bekleyen: [], tarifeler: [] };
          case 'pazar_katalog': return { benim_il: 34, sektorler: [{ kod: 'akaryakit', ad: 'Akaryakıt İstasyonu', min_sermaye: 1000000 }, { kod: 'oto_galeri', ad: 'Otomobil Galerisi', min_sermaye: 2500000 }] };
          case 'durum': return null;
          case 'vergi_rehberi': return { tanitim: true };
          default: return {};
        }
      };
      API = { rpc: async (ad, args) => { calls.push({ ad, args }); const v = sahte(ad, args || {}); return v == null ? v : JSON.parse(JSON.stringify(v)); } };
      D.durum = D.durum || {}; D.durum.profil = Object.assign({ id: 'u1', il_id: 34, kad: 'Uygar', parti: null, makamlar: [] }, D.durum.profil || {}, { kad: 'Uygar', il_id: 34 });
      D.sekme = 'hayat'; D.yigin = [];
      window.onayla = async () => true;
      window.durumYenile = async () => {};
    }, { VERI, GM, PNL: PANEL() });
    const bekle = (ms = 350) => page.waitForTimeout(ms);
    const yaz = async (ad) => {
      if (!shot) return; fs.mkdirSync(shot, { recursive: true });
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) { a.dataset.eski = a.style.cssText; a.style.position = 'static'; a.style.height = 'auto'; } document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = 'visible'; }); document.body.style.overflow = 'visible'; });
      await page.screenshot({ path: path.join(shot, genislik + '_' + ad + '.png'), fullPage: true });
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) a.style.cssText = a.dataset.eski || ''; document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = ''; }); document.body.style.overflow = ''; });
    };
    const yazGorunum = async (ad, secici) => {
      if (!shot) return; fs.mkdirSync(shot, { recursive: true });
      await page.evaluate((s) => { const el = document.querySelector(s); if (el) el.scrollIntoView({ block: 'center' }); }, secici);
      await page.waitForTimeout(200);
      await page.screenshot({ path: path.join(shot, genislik + '_' + ad + '.png') });
    };
    const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
    const modalMetin = () => page.evaluate(() => (document.querySelector('#modal') || {}).innerText || '');
    const tasmaYok = async (ne) => {
      const w = await page.evaluate(() => Math.max(document.documentElement.scrollWidth, document.body.scrollWidth));
      assert.ok(w <= genislik + 1, ne + ': yatay taşma ' + w + ' > ' + genislik);
    };

    // 1) Banka Genel Müdürlük: güven notu etkenleri, yakın izleme
    await page.evaluate(() => bankaGenelMudurlukEkrani(227)); await bekle(500);
    let t = await metin();
    assert.match(t, /Güven notunu etkileyenler/); assert.match(t, /Yakın izleme/); assert.match(t, /−1 puan/);
    assert.match(t, /yakın izlemede/i); assert.match(t, /Yakın izlemedeki krediler/); assert.match(t, /3 günden uzun/);
    assert.doesNotMatch(t, /undefined|NaN/);
    await tasmaYok('banka özet'); await yaz('01_banka_ozet');
    await page.evaluate(() => gmSekme('musteri')); await bekle();
    t = await metin(); assert.match(t, /yakın izleme/); await yaz('02_banka_musteri');

    // 2) Üretim ve Ticaret: emir kartları, geri sayım, şehir satırı
    await page.evaluate(() => ticaretMerkezEkrani('uretim')); await bekle(600);
    t = await metin();
    assert.match(t, /Üretimde/); assert.match(t, /kaldı/); assert.match(t, /Stoğa geçiyor/); assert.match(t, /Stoğa geçen son 1 üretim/);
    await page.click('.tc-biten summary'); await bekle(150);
    t = await metin(); assert.match(t, /Stoğa geçti: (bugün|dün|\d)/);
    assert.match(t, /İstanbul · üretim maliyeti ×1,2/); assert.match(t, /Bitiş (bugün|yarın)/); assert.match(t, /stoğa en geç/);
    assert.match(t, /Şehir ekonomileri/);
    assert.doesNotMatch(t, /undefined|NaN|Invalid Date/);
    const bar = await page.evaluate(() => { const i = document.querySelector('.tc-emir.uretimde .tc-ilerleme i'); return i ? parseInt(i.style.width) : -1; });
    assert.ok(bar >= 30 && bar <= 50, 'ilerleme çubuğu ~%40 olmalı: ' + bar);
    await tasmaYok('üretim paneli'); await yaz('03_uretim_paneli');

    // 3) Üretim emri penceresi: süre, bitiş, il çarpanlı maliyet, adet düğmeleri
    await page.evaluate(() => tcProduce(222)); await bekle();
    let m = await modalMetin();
    assert.match(m, /Hazır olur/); assert.match(m, /(bugün|yarın) \d\d:\d\d/); assert.match(m, /Toplam maliyet/);
    assert.match(m, /72 ₺/);                      // 10 × 6 ₺ × 1,2
    assert.match(m, /İstanbul üretim çarpanı ×1,2/); assert.match(m, /Parti kapasitesi/); assert.match(m, /300 adet/);
    await page.click('.tc-adet button[data-d="10"]'); await bekle(150);
    m = await modalMetin(); assert.match(m, /144 ₺/);   // 20 adet
    await page.click('.tc-urun[data-kod="un"]'); await bekle(150);
    m = await modalMetin(); assert.match(m, /1 sa 30 dk/); assert.match(m, /90 adet/); assert.match(m, /2\.040 ₺/); // 20 × 85 × 1,2
    await page.click('.tc-adet button[data-d="max"]'); await bekle(150);
    assert.equal(await page.inputValue('#tcQty'), '90');
    await tasmaYok('üretim emri'); await yaz('04_uretim_emri');
    await page.click('#tcOK'); await bekle(500);
    const emir = await page.evaluate(() => calls.filter(c => c.ad === 'eko_ticaret_islem').pop());
    assert.equal(emir.args.p_eylem, 'uret'); assert.equal(emir.args.p_veri.urun, 'un'); assert.equal(emir.args.p_veri.adet, 90);

    // 4) Şehir ekonomileri: sıralama, arama, ayrıntı
    await page.evaluate(() => ekranAc(ilEkonomileriEkrani)); await bekle(500);
    t = await metin();
    assert.match(t, /Şehir ekonomileri/); assert.match(t, /İstanbul/); assert.match(t, /81\.700 ₺/); assert.match(t, /TÜİK/);
    const ilk = await page.evaluate(() => document.querySelector('.ile-satir .ad b').textContent);
    assert.equal(ilk, 'İstanbul');
    await yaz('05_sehir_ekonomileri');
    await page.evaluate(() => ilEkoSira('ucuz')); await bekle();
    const ucuz = await page.evaluate(() => document.querySelector('.ile-satir .ad b').textContent);
    assert.notEqual(ucuz, 'İstanbul');
    await page.fill('#ileAra', 'tun'); await page.evaluate(() => ilEkoAra('tun')); await bekle(150);
    const kalan = await page.evaluate(() => [...document.querySelectorAll('.ile-satir .ad b')].map(x => x.textContent));
    assert.deepEqual(kalan, ['Tunceli']);
    await page.evaluate(() => ilEkoDetay(62)); await bekle(400);
    m = await modalMetin();
    assert.match(m, /Tunceli/); assert.match(m, /30\.300 ₺/); assert.match(m, /Günlük market müşterisi/); assert.match(m, /149/);
    await tasmaYok('il ayrıntı'); await yaz('06_il_ayrinti');
    await page.evaluate(() => modalKapat()); await bekle(150);

    // 5) Şirket kuruluşu: şehre göre kuruluş gideri
    await page.evaluate(() => sirketTumTurKur()); await bekle(600);
    m = await modalMetin();
    assert.match(m, /İstanbul ekonomisi/); assert.match(m, /kuruluş gideri: 81\.700 ₺/);
    await page.selectOption('#stkCity', '62'); await bekle(500);
    m = await modalMetin(); assert.match(m, /Tunceli ekonomisi/); assert.match(m, /30\.300 ₺/);
    await page.selectOption('#stkType', 'pazar:oto_galeri'); await bekle(500);
    m = await modalMetin(); if (!/185\.300 ₺/.test(m)) console.log('MODAL:', m.slice(m.indexOf('ekonomisi') - 30, m.indexOf('ekonomisi') + 600)); assert.match(m, /185\.300 ₺/);
    await tasmaYok('kuruluş'); await yazGorunum('07_kurulus_tunceli', '#stkIlEko');
    await page.evaluate(() => modalKapat()); await bekle(150);
    await page.close();
  }
  await browser.close();
  if (hatalar.length) { console.error('Sayfa hataları:\n' + hatalar.join('\n')); process.exit(1); }
  console.log('il_ekonomisi_uretim_arayuz: TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
