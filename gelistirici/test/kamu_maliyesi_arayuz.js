// Kamu Maliyesi 2.0 arayüz testi (31.10.2026): Bütçe ve Ekonomi ekranı, Varlık Fonu aktarımı,
// Devlet bütçesi şeridi + ek ödenek onay penceresi, Devlet › Hükümet kartı, bildirim bağlantısı. Ağ yok; sahte RPC.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/kamu_maliyesi_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();
const RAPOR = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/kamu_maliyesi_ornek.json'), 'utf8'));
const MASA = {
  simdi: S(0), yetkili: true, cb: true, yurutme: 'Ercan', sistem: 'baskanlik', hazine: 1085,
  hesap: { gelir: 14.93, gider: 12.25, denge: 2.68, cari: 10.2 },
  maliye: { hazine: 1085, varlik_fonu: 166904.5, bugun: { gelir: 38.4, harcama: 66.7, denge: -28.3 } },
  son_hazine_hareketleri: [], tavan: 100, aktarim_oran: 25, aktarim_bekleme_saat: 24, talep_ust: 25, son_tahsis: null,
  bakanliklar: [
    { kod: 'egitim', ad: 'Milli Eğitim Bakanlığı', kasa: 9.1, pay: 14, gunluk: 1.43, bakan: 'Ayşe', harcama7: 20, puan: 60, aktif_etkinlik: false },
    { kod: 'maliye', ad: 'Hazine ve Maliye Bakanlığı', kasa: 0.13, pay: 6, gunluk: 0.61, bakan: null, harcama7: 4, puan: 30, aktif_etkinlik: false }],
  talepler: [{ id: 5, kod: 'egitim', ad: 'Milli Eğitim Bakanlığı', kad: 'Ayşe', tutar: 20, gerekce: 'Okul onarımı', durum: 'bekliyor', zaman: S(-2), bitis: S(70) }]
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  for (const genislik of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: genislik, height: 844 }, isMobile: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(e.message));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const ad = decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname);
      let f = path.join(KOK, ad); if (!fs.existsSync(f)) f = path.join(YEDEK, ad);
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => window.SO_KAMU_MALIYESI_V1 && typeof iskelet === 'function' && typeof devletButcesiEkrani === 'function');
    await page.waitForTimeout(600);
    await page.evaluate(({ RAPOR, MASA }) => {
      window.calls = [];
      const sahte = (ad, a) => {
        switch (ad) {
          case 'butce_raporu': return Object.assign({}, RAPOR, { gun: a.p_gun || 7 });
          case 'varlik_fonu_aktar': return Object.assign({}, RAPOR, { varlik_fonu: Object.assign({}, RAPOR.varlik_fonu, { kalan_hak: 50, cekilen: 10, son_islem: new Date().toISOString() }) });
          case 'yurutme_butce_masasi': return MASA;
          default: return {};
        }
      };
      API = { rpc: async (ad, args) => { calls.push({ ad, args }); return JSON.parse(JSON.stringify(sahte(ad, args || {}))); } };
      D.durum = D.durum || {}; D.durum.profil = Object.assign({ id: 'u1', il_id: 6, kad: 'Ercan', parti: null, makamlar: [{ tur: 'cb' }] }, D.durum.profil || {}, { kad: 'Ercan' });
      window.onayla = async () => true;
    }, { RAPOR, MASA });
    const bekle = (ms = 300) => page.waitForTimeout(ms);
    const yaz = async (ad) => {
      if (!shot) return; fs.mkdirSync(shot, { recursive: true });
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) { a.dataset.eski = a.style.cssText; a.style.position = 'static'; a.style.height = 'auto'; } document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = 'visible'; }); });
      await page.screenshot({ path: path.join(shot, genislik + '_' + ad + '.png'), fullPage: true });
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) a.style.cssText = a.dataset.eski || ''; document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = ''; }); });
    };
    const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
    const modalMetin = () => page.evaluate(() => (document.querySelector('#modal') || {}).innerText || '');
    const tasma = () => page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);

    // 1) Bütçe ve Ekonomi ekranı
    await page.evaluate(() => ekranAc(butceEkonomiEkrani)); await bekle(500);
    let t = await metin();
    assert.match(t, /Bütçe ve Ekonomi/); assert.match(t, /Hazine nakdi/); assert.match(t, /1\.085/);
    assert.match(t, /Varlık Fonu/); assert.match(t, /166\.905|166\.904/);
    assert.match(t, /Enflasyonu ne belirliyor\?/); assert.match(t, /Bütçe açığı \/ fazlası/); assert.match(t, /\+3,65/);
    assert.match(t, /fazla harcadı/); assert.match(t, /GSYH'nin %4,1'i/);
    assert.match(t, /Kurumlar vergisi/); assert.match(t, /Bakanlıkların harcamaları/); assert.match(t, /İcraatlar/);
    assert.match(t, /Genel devlet dengesi/); assert.match(t, /Türkiye Varlık Fonu/); assert.match(t, /Fondan Hazine'ye/);
    assert.match(t, /Borç ve faiz/); assert.match(t, /Son Hazine hareketleri/); assert.match(t, /Bakanlığa ek ödenek/);
    assert.ok(await page.evaluate(() => !!document.querySelector('.km-grafik')), 'grafik çizilmeli');
    assert.ok(!await tasma(), genislik + ' px: yatay taşma olmamalı (bütçe)');
    await yaz('01_butce_ekonomi');

    // 2) Dönem seçimi
    await page.evaluate(() => kmDonem(30)); await bekle(400);
    let c = await page.evaluate(() => calls.filter(x => x.ad === 'butce_raporu').pop());
    assert.deepEqual(c.args, { p_gun: 30 });
    assert.match(await metin(), /son 30 gün/);

    // 3) Varlık Fonu aktarımı
    await page.evaluate(() => kmFonModal('cek')); await bekle(300);
    t = await modalMetin();
    assert.match(t, /Varlık Fonu'ndan Hazine'ye aktarım/); assert.match(t, /kalan çekim hakkı/); assert.match(t, /bütçe açığını kapatmaz/);
    await yaz('02_fon_modal');
    await page.fill('#kmFT', '10'); await page.click('#kmFOk'); await bekle(400);
    c = await page.evaluate(() => calls.filter(x => x.ad === 'varlik_fonu_aktar').pop());
    assert.deepEqual(c.args, { p_yon: 'cek', p_tutar: 10, p_gerekce: null });
    assert.match(await metin(), /50,0 \/ 60/);

    // 4) Devlet bütçesi: gerçekleşen bütçe, Varlık Fonu, şerit, ek ödenek onay penceresi
    await page.evaluate(() => ekranAc(devletButcesiEkrani)); await bekle(600);
    await page.evaluate(() => { try { modalKapat(); } catch (_) {} }); await bekle(300);
    t = await metin();
    assert.match(t, /Bugün gerçekleşen/); assert.match(t, /Harcama/); assert.match(t, /Varlık Fonu/);
    assert.match(t, /Gelir-gider kalemleri ve enflasyon/);
    assert.ok(!await tasma(), genislik + ' px: yatay taşma olmamalı (devlet bütçesi)');
    await yaz('03_devlet_butcesi');
    await page.evaluate(() => bmKarar(5, true)); await bekle(300);
    t = await modalMetin();
    assert.match(t, /1\.085,0 milyar ₺/); assert.match(t, /1\.065,0 milyar ₺/); assert.match(t, /enflasyon/);
    await yaz('04_odenek_onay');
    await page.evaluate(() => { try { modalKapat(); } catch (_) {} });

    // 5) Devlet › Hükümet kartı
    await page.evaluate(() => { D.devletSekme = 'hukumet'; iskelet('Devlet', '<div class="segment"><button class="aktif">Hükümet</button><button>Mevzuat</button></div><div class="kart"><p>gösterge</p></div>'); });
    await bekle(500);
    t = await metin();
    assert.match(t, /Bütçe ve ekonomi/); assert.match(t, /Hazine 1\.085,0 milyar ₺/);
    await page.click('#kmHukumetKart'); await bekle(400);
    assert.match(await metin(), /Hazine nakdi/);

    // 6) Bildirim bağlantısı
    await page.evaluate(() => iskelet('Bildirimler', '<div class="kisisel"><div>Hazine: nakit azaldı, kasada 150 milyar ₺ var.</div><div class="bildirim-alt">şimdi</div></div><div class="kisisel"><div>Başka bir bildirim</div></div>'));
    await bekle(300);
    assert.equal(await page.evaluate(() => document.querySelectorAll('.km-bag').length), 1);
    await page.close();
  }
  await browser.close();
  const ilgili = hatalar.filter(h => /butce|bütçe|kamu|maliye|hazine|varlik|km/i.test(h));
  assert.equal(ilgili.length, 0, 'Sayfa hataları: ' + ilgili.join(' | '));
  console.log('TAMAM (bütçe ve ekonomi, Varlık Fonu, devlet bütçesi, hükümet kartı, bildirim; 390 ve 320 px)' + (hatalar.length ? ' · ilgisiz sayfa hatası: ' + hatalar.length : ''));
})().catch(e => { console.error(e); process.exit(1); });
