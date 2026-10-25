// İlan Meydanı arayüz testi. Ağ yok; sahte RPC; derlenmiş gelistirici/dist/index.html sunulur.
// Önce: node gelistirici/build/derle.js
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/ilan_meydani_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = path.join(__dirname, '../dist');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const TARIFE = [
  { kod: 'ilan_emlak', ad: 'Emlak ilanı', tutar: 750, gun: 30, aciklama: 'Konut, işyeri ve arsa ilanı 30 gün yayında kalır.' },
  { kod: 'ilan_hisse', ad: 'Şirket hissesi ilanı', tutar: 1000, gun: 30, aciklama: 'Şirket hissesi ilanı 30 gün yayında kalır.' },
  { kod: 'ilan_sirket', ad: 'Satılık şirket ilanı', tutar: 2000, gun: 30, aciklama: 'Şirketin tamamı için ilan 30 gün yayında kalır.' },
  { kod: 'vitrin', ad: 'Vitrin', tutar: 3000, gun: 3, aciklama: 'İlan Meydanı açılışındaki vitrinde fotoğraflı kart olarak görünür.' },
  { kod: 'ust_sira', ad: 'Üst sıra', tutar: 1500, gun: 3, aciklama: 'Kategori ve arama sonuçlarında ilanların en üstünde durur.' },
  { kod: 'acil', ad: 'Acil satılık', tutar: 750, gun: 7, aciklama: 'Kırmızı "Acil" etiketi alır, Acil ilanlar listesinde görünür.' },
  { kod: 'renkli', ad: 'Renkli çerçeve', tutar: 500, gun: 7, aciklama: 'Listede renkli çerçeve ve kalın başlıkla dikkat çeker.' },
  { kod: 'yukari', ad: 'Yukarı taşı', tutar: 300, gun: 0, aciklama: 'İlan yeni verilmiş gibi listenin başına taşınır (tek sefer).' }];
const oz = (o) => Object.assign({ dustu: false, benim: false, acil: false, vitrin: false, ust: false, renkli: false, pazarlik: true, durum: 'yayinda', goruntulenme: 4, kaynak: 'oyuncu', satis_bedeli: null, sektor: null, pay: null, tarih: S(-5), siralama: S(-5), bitis: S(600) }, o);
const L = [
  oz({ id: 3, no: 1000003, kategori: 'konut', varlik: 'tapu', baslik: 'Kadıköy merkezde 3+1 daire, kiracılı', fiyat: 850000, il: 'İstanbul', il_id: 34, satici: 'Ayşe', gorsel: 'daire', ozellik: '110 m² · haftalık kira 10.200 ₺', vitrin: true, acil: true }),
  oz({ id: 4, no: 1000004, kategori: 'isyeri', varlik: 'bolum', baslik: 'Çarşı içinde köşe dükkân', fiyat: 1240000, il: 'İzmir', il_id: 35, satici: 'Mert', gorsel: 'dukkan', ozellik: '80 m² · Yeşil Vadi Konutları', renkli: true, dustu: true }),
  oz({ id: 5, no: 1000005, kategori: 'sirket', varlik: 'sirket', baslik: 'Deniz Lojistik — devren satılık', fiyat: 420000, il: 'Ankara', il_id: 6, satici: 'Deniz', gorsel: 'sirket', sektor: 'lojistik', ozellik: 'Lojistik · şirketin tamamı', benim: true, pay: 100 }),
  oz({ id: 6, no: 1000006, kategori: 'hisse', varlik: 'hisse', baslik: 'Anadolu Teknoloji %20 hisse', fiyat: 96000, il: 'Bursa', il_id: 16, satici: 'Selin', gorsel: 'hisse', sektor: 'teknoloji', pay: 20, ozellik: 'Teknoloji · %20 hisse' }),
  oz({ id: 7, no: 1000007, kategori: 'arsa', varlik: 'tapu', baslik: 'Göl manzaralı imarlı arsa', fiyat: 310000, il: 'Sakarya', il_id: 54, satici: 'Kerem', gorsel: 'arsa', ozellik: '500 m²' })];
const MEYDAN = {
  liste: L, toplam: 5, sayfa: 1, boy: 20, vitrin: [L[0], L[3]],
  kategoriler: { konut: 1, isyeri: 1, arsa: 1, sirket: 1, hisse: 1, acil: 1, toplam: 5, muteahhit: 4 },
  muteahhit: [{ bolum: 41, yapi: 9, proje: 'Yeşil Vadi Konutları', tur: 'daire', kategori: 'konut', il: 'İzmir', il_id: 35, fiyat: 640000, adet: 3, alan_m2: 110, firma: 'Ege Yapı', harc: 12800 },
    { bolum: 44, yapi: 9, proje: 'Yeşil Vadi Konutları', tur: 'dukkan', kategori: 'isyeri', il: 'İzmir', il_id: 35, fiyat: 980000, adet: 1, alan_m2: 80, firma: 'Ege Yapı', harc: 19600 }],
  sektorler: [{ kod: 'lojistik', ad: 'Lojistik' }, { kod: 'teknoloji', ad: 'Teknoloji' }],
  benim: { aktif_ilan: 1, gelen: 1, giden: 2, karsi: 1, favori: [3], cuzdan: 184250 }, tarife: TARIFE };
const BILGI = [['Emlak tipi', 'Daire'], ['İl', 'İstanbul'], ['Alan', '110 m²'], ['Haftalık kira geliri', '10.200 ₺'], ['Tapu durumu', 'Tapulu, belediyeden alınmış'], ['İl rayici', '820.000 ₺'], ['İlan no', '1000003'], ['İlan tarihi', '20.10.2026'], ['Pazarlık', 'Teklif kabul ediliyor']];
const SATICI = { kad: 'Ayşe', uye: '07.10.2026', il: 'İstanbul', son_gorulme: S(-1), satis: 2, aktif: 2 };
const DETAY = {
  3: Object.assign({}, L[0], { aciklama: 'Metroya 5 dakika. Kiracı düzenli ödüyor.\nTapu temiz.', bilgi: BILGI, mali: null, mali_goster: false, satici_bilgi: SATICI, ilk_fiyat: 900000, onceki_fiyat: 900000, favori: true, favori_sayisi: 3,
    teklifler: null, teklifim: { id: 21, tutar: 760000, karsi: 820000, durum: 'karsi', bitis: S(30), emanet: 775200, not: 'Hemen devralabilirim' }, benzer: [L[1]], alici_harc: 17000, satici_harc_oran: 2, bant: null, paketler: null, cuzdan: 184250, yonetici: false, goruntulenme: 12 }),
  4: Object.assign({}, L[1], { aciklama: null, bilgi: BILGI.slice(0, 4), mali: null, mali_goster: false, satici_bilgi: Object.assign({}, SATICI, { kad: 'Mert', aktif: 1 }), ilk_fiyat: 1300000, onceki_fiyat: 1300000, favori: false, favori_sayisi: 0,
    teklifler: null, teklifim: null, benzer: [], alici_harc: 24800, satici_harc_oran: 2, bant: null, paketler: null, cuzdan: 1500000, yonetici: false }),
  5: Object.assign({}, L[2], { aciklama: 'Üç şubeli, düzenli sözleşmeli lojistik firması.', bilgi: [['Şirket', 'Deniz Lojistik'], ['Sektör', 'Lojistik'], ['Satılan', 'Şirketin tamamı (%100)']], mali: { kasa: 182000, sermaye: 150000, defter: 240000, acik: false }, mali_goster: false,
    satici_bilgi: Object.assign({}, SATICI, { kad: 'Deniz' }), ilk_fiyat: 420000, onceki_fiyat: null, favori: false, favori_sayisi: 1,
    teklifler: [{ id: 31, alici: 'Burak', tutar: 360000, karsi: null, durum: 'bekliyor', bitis: S(40), not: 'Kasa bilgisini paylaşır mısın?', zaman: S(-2) },
      { id: 32, alici: 'Ece', tutar: 300000, karsi: 390000, durum: 'karsi', bitis: S(20), not: null, zaman: S(-20) }],
    teklifim: null, benzer: [], alici_harc: 0, satici_harc_oran: 1, bant: { alt: 91000, ust: 546000, rayic: null }, paketler: { vitrin: S(40), ust_sira: null, acil: null, renkli: null }, cuzdan: 184250, yonetici: false })
};
const VARLIK = {
  tapular: [{ varlik: 'tapu', id: 13, tip: 'daire', kategori: 'konut', il: 'Batman', il_id: 72, alan_m2: 110, kira: 1980, alis: 165000, rayic: 165000, alt: 66000, ust: 660000, ilanda: false, baska_pazar: false }],
  bolumler: [{ varlik: 'bolum', id: 44, tip: 'dukkan', kategori: 'isyeri', il: 'İzmir', il_id: 35, alan_m2: 80, kira: 6000, proje: 'Yeşil Vadi Konutları', sira: 4, rayic: 980000, alt: 392000, ust: 3920000, kirada: true, ilanda: false, baska_pazar: false }],
  sirketler: [{ id: 77, ad: 'Deniz Lojistik', sektor: 'lojistik', sektor_ad: 'Lojistik', pay: 100, tam: true, banka: false, il: 'Ankara', kullanilabilir: 100, sirket_alt: 91000, sirket_ust: 546000, bant_acik: true, birim_alt: 910, birim_ust: 5460, ilanda_sirket: false, ilanda_hisse: false },
    { id: 203, ad: 'Örnek Bank', sektor: 'banka', sektor_ad: 'Banka', pay: 100, tam: true, banka: true, il: 'İstanbul', kullanilabilir: 100, sirket_alt: 1000, sirket_ust: 1e9, bant_acik: true, birim_alt: 10, birim_ust: 100, ilanda_sirket: false, ilanda_hisse: false }],
  aktif: 1, limit: 10, cuzdan: 184250, sirket_pazari: true, tarife: TARIFE };
const HESAP = {
  ilanlar: [Object.assign({}, L[2], { teklif: 2, en_yuksek: 360000, favori_sayisi: 1, kapanis: null, paketler: {} }),
    Object.assign({}, L[4], { id: 9, durum: 'satildi', satis_bedeli: 300000, teklif: 0, favori_sayisi: 0, kapanis: S(-30), paketler: {} })],
  gelen: [{ id: 31, ilan: 5, no: 1000005, baslik: 'Deniz Lojistik — devren satılık', fiyat: 420000, gorsel: 'sirket', kategori: 'sirket', kisi: 'Burak', tutar: 360000, karsi: null, durum: 'bekliyor', bitis: S(40), not: 'Kasa bilgisini paylaşır mısın?', zaman: S(-2) }],
  giden: [{ id: 21, ilan: 3, no: 1000003, baslik: 'Kadıköy merkezde 3+1 daire, kiracılı', fiyat: 850000, gorsel: 'tapu', kategori: 'konut', kisi: 'Ayşe', tutar: 760000, karsi: 820000, durum: 'karsi', emanet: 775200, bitis: S(30), not: null, zaman: S(-3), ilan_durum: 'yayinda', harc: 16400 },
    { id: 22, ilan: 6, no: 1000006, baslik: 'Anadolu Teknoloji %20 hisse', fiyat: 96000, gorsel: 'hisse', kategori: 'hisse', kisi: 'Selin', tutar: 80000, karsi: null, durum: 'bekliyor', emanet: 80000, bitis: S(44), not: null, zaman: S(-1), ilan_durum: 'yayinda', harc: 0 }],
  favoriler: [L[0]], cuzdan: 184250, tarife: TARIFE };

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
  page.on('pageerror', e => hatalar.push(e.message));
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (u.hostname !== 'oyun.test') return r.abort();
    const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
    if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
    r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
  });
  await page.goto('http://oyun.test/index.html');
  await page.waitForFunction(() => window.ILAN_MEYDANI && typeof iskelet === 'function' && typeof ilanMeydaniEkrani === 'function');
  await page.evaluate(({ MEYDAN, DETAY, VARLIK, HESAP }) => {
    window.calls = [];
    window.onayla = async () => true;
    API = { rpc: async (ad, args) => {
      calls.push({ ad, args: JSON.parse(JSON.stringify(args || {})) });
      const kopya = (x) => JSON.parse(JSON.stringify(x));
      if (ad === 'ilan_meydani') return kopya(MEYDAN);
      if (ad === 'ilan_detay') { if (!DETAY[args.p_ilan]) throw new Error('İlan bulunamadı.'); return kopya(DETAY[args.p_ilan]); }
      if (ad === 'ilan_varliklarim') return kopya(VARLIK);
      if (ad === 'ilan_hesabim') return kopya(HESAP);
      if (ad === 'ilan_ver') return { tamam: true, id: 4, no: 1000004, ucret: 3750 };
      if (ad === 'ilan_teklif_ver') return { tamam: true, teklif: 30, emanet: args.p_tutar * 1.02 };
      if (['ilan_hemen_al', 'ilan_teklif_yanit', 'ilan_karsi_yanit', 'ilan_teklif_geri_cek', 'ilan_favori', 'ilan_one_cikar', 'ilan_kaldir', 'ilan_duzenle', 'eko_emlak_islem'].indexOf(ad) >= 0) return { tamam: true };
      if (ad === 'durum' || ad === 'durum_ozet') return {};
      throw new Error('sahte: ' + ad);
    } };
    window.durumYenile = async () => {};
    D.durum = { profil: { il_id: 34, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 184250 } } }; D.sekme = 'ekonomi'; D.yigin = [];
  }, { MEYDAN, DETAY, VARLIK, HESAP });
  const yaz = async (ad) => {
    if (!shot) return;
    fs.mkdirSync(shot, { recursive: true });
    await page.evaluate(() => { const a = document.querySelector('#app'); a.dataset.eski = a.style.cssText; a.style.position = 'static'; a.style.height = 'auto';
      document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = 'visible'; }); document.body.style.overflow = 'visible'; document.documentElement.style.height = 'auto'; document.body.style.height = 'auto'; });
    await page.screenshot({ path: path.join(shot, ad + '.png'), fullPage: true });
    await page.evaluate(() => { const a = document.querySelector('#app'); a.style.cssText = a.dataset.eski || ''; document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = ''; }); document.body.style.overflow = ''; document.documentElement.style.height = ''; document.body.style.height = ''; });
  };
  const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
  const modalMetin = () => page.evaluate(() => (document.querySelector('#modal') || {}).innerText || '');
  const bekle = (ms) => page.waitForTimeout(ms || 250);
  const sonCagri = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);
  const tasmaYok = async (ne) => assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1), false, ne + ': yatay taşma');
  let t;

  // 1) Ana sayfa
  await page.evaluate(() => ekranAc(ilanMeydaniEkrani)); await bekle(400);
  t = await metin();
  for (const k of [/Kategoriler/, /Vitrin/, /Müteahhitten sıfır/, /Son ilanlar/, /İlan ver/, /Kadıköy merkezde/, /850\.000 ₺/, /Acil satılıklar/]) assert.match(t, k);
  assert.doesNotMatch(t, /undefined|NaN|null/);
  await tasmaYok('ana sayfa'); await yaz('01_ana');

  // 2) Kategori listesi ve filtre
  await page.evaluate(() => imKategori('konut')); await bekle(400);
  t = await metin(); assert.match(t, /5 ilan/); assert.match(t, /Filtrele/); assert.match(t, /En ucuz/);
  await yaz('02_liste');
  await page.evaluate(() => imFiltreAc()); await bekle();
  t = await modalMetin(); assert.match(t, /Filtrele/); assert.match(t, /Tüm Türkiye/);
  await page.selectOption('#imfIl', '34'); await page.fill('#imfMin', '500.000'); await yaz('03_filtre');
  await page.evaluate(() => imFiltreUygula()); await bekle(400);
  let c = await sonCagri('ilan_meydani');
  assert.equal(c.args.p_filtre.il, '34'); assert.equal(c.args.p_filtre.min, 500000); assert.equal(c.args.p_filtre.kategori, 'konut');
  await page.evaluate(() => imSirala('ucuz')); await bekle(300);
  c = await sonCagri('ilan_meydani'); assert.equal(c.args.p_filtre.sirala, 'ucuz');

  // 3) Alıcı: karşı teklif bekleyen ilan
  await page.evaluate(() => imAc(3)); await bekle(400);
  t = await metin();
  assert.match(t, /Satıcı karşı teklif verdi: 820\.000 ₺/); assert.match(t, /İlan bilgileri/); assert.match(t, /Güvenli Ödeme/); assert.match(t, /Metroya 5 dakika/);
  assert.doesNotMatch(t, /undefined|NaN/);
  await tasmaYok('ilan detayı'); await yaz('04_detay_karsi');
  await page.evaluate(() => imKarsiYanit(21, true, null)); await bekle(300);
  c = await sonCagri('ilan_karsi_yanit'); assert.equal(c.args.p_teklif, 21); assert.equal(c.args.p_kabul, true);

  // 4) Alıcı: teklif ver
  await page.evaluate(() => imAc(4)); await bekle(400);
  t = await metin(); assert.match(t, /Teklif ver/); assert.match(t, /Hemen al/); assert.match(t, /↓ Fiyatı düştü/);
  await page.evaluate(() => imTeklifModal(4)); await bekle();
  await page.fill('#imTk', '1.100.000'); await page.evaluate(() => imTeklifOzet());
  t = await modalMetin(); assert.match(t, /Bloke edilecek/); assert.match(t, /1\.122\.000 ₺/);
  await yaz('05_teklif');
  await page.fill('#imTk', '1.300.000'); await page.evaluate(() => imTeklifOzet());
  assert.equal(await page.$eval('#imTkBtn', b => b.disabled), true, 'ilan fiyatından yüksek teklif engellenmeli');
  await page.fill('#imTk', '1.100.000'); await page.evaluate(() => imTeklifOzet());
  await page.evaluate(() => document.getElementById('imTkBtn').click()); await bekle(300);
  c = await sonCagri('ilan_teklif_ver'); assert.equal(c.args.p_ilan, 4); assert.equal(c.args.p_tutar, 1100000);
  await page.evaluate(() => imHemenAl(4)); await bekle(300);
  c = await sonCagri('ilan_hemen_al'); assert.equal(c.args.p_fiyat, 1240000);

  // 5) Satıcı: kendi ilanı, gelen teklifler, öne çıkar
  await page.evaluate(() => imAc(5)); await bekle(400);
  t = await metin();
  assert.match(t, /Bu senin ilanın/); assert.match(t, /360\.000 ₺/); assert.match(t, /Kasa bilgisini paylaşır mısın/); assert.match(t, /yalnız sen görüyorsun/); assert.match(t, /Öne çıkarma: Vitrin/);
  await yaz('06_satici');
  await page.evaluate(() => imOneCikarModal(5)); await bekle();
  t = await modalMetin(); assert.match(t, /Yukarı taşı/); assert.match(t, /3\.000 ₺/);
  await yaz('07_one_cikar');
  await page.evaluate(() => document.querySelectorAll('#modal .im-paket')[0].click()); await bekle(300);
  c = await sonCagri('ilan_one_cikar'); assert.equal(c.args.p_paket, 'vitrin');
  await page.evaluate(() => imKarsiModal(31, 360000, 420000)); await bekle();
  assert.equal(await page.inputValue('#imKt'), '390.000');
  await page.evaluate(() => imKarsiGonder(31, null)); await bekle(300);
  c = await sonCagri('ilan_teklif_yanit'); assert.equal(c.args.p_karar, 'karsi'); assert.equal(c.args.p_karsi, 390000);

  // 6) İlan ver: varlık seç, form, paket, yayınla
  await page.evaluate(() => ilanVerEkrani()); await bekle(400);
  t = await metin();
  assert.match(t, /Batman/); assert.match(t, /Kiracısı var/); assert.match(t, /Bankalar İlan Meydanı’nda satılamaz/); assert.match(t, /Tamamını sat/); assert.match(t, /Hisse sat/);
  await tasmaYok('ilan ver'); await yaz('08_ilan_ver_sec');
  await page.evaluate(() => imVarlikSec('tapu', 13)); await bekle(400);
  t = await metin(); assert.match(t, /İl rayici 165\.000 ₺/); assert.match(t, /Öde ve yayınla/); assert.match(t, /Ödenecek/);
  await page.evaluate(() => { const c = document.querySelector('.im-paket input'); c.checked = true; c.dispatchEvent(new Event('change')); }); await bekle();
  t = await metin(); assert.match(t, /3\.750 ₺/);
  await yaz('09_ilan_formu');
  await page.fill('#ivFiyat', '10.000'); await page.evaluate(() => imIvAlan('fiyat', document.getElementById('ivFiyat').value));
  assert.equal(await page.$eval('#ivBtn', b => b.disabled), true, 'bant altı fiyat engellenmeli');
  await page.fill('#ivFiyat', '170.000'); await page.evaluate(() => imIvAlan('fiyat', document.getElementById('ivFiyat').value));
  assert.equal(await page.$eval('#ivBtn', b => b.disabled), false);
  await page.evaluate(() => document.getElementById('ivBtn').click()); await bekle(500);
  c = await sonCagri('ilan_ver');
  assert.equal(c.args.p_veri.varlik, 'tapu'); assert.equal(c.args.p_veri.fiyat, 170000); assert.deepEqual(c.args.p_veri.paketler, ['vitrin']);
  t = await metin(); assert.match(t, /Çarşı içinde köşe dükkân/, 'yayınlanınca ilan sayfası açılmalı');
  // hisse formu: pay değişince bant güncellenir
  await page.evaluate(() => ilanVerEkrani()); await bekle(300);
  await page.evaluate(() => imVarlikSec('hisse', 77)); await bekle(300);
  await page.fill('#ivPay', '10'); await page.evaluate(() => imIvPay('10'));
  t = await metin(); assert.match(t, /9\.100 ₺ ile 54\.600 ₺/); assert.equal(await page.inputValue('#ivBaslik'), 'Deniz Lojistik — %10 hisse');

  // 7) Hesabım
  await page.evaluate(() => ilanHesabimEkrani('gelen')); await bekle(400);
  t = await metin(); assert.match(t, /İlanlarına gelen teklifler/); assert.match(t, /Burak/); assert.match(t, /Kabul et/);
  await yaz('10_gelen');
  await page.evaluate(() => imHsSekme('giden')); await bekle();
  t = await metin(); assert.match(t, /Satıcının karşı teklifi/); assert.match(t, /Teklifi geri çek/);
  await yaz('11_giden');
  await page.evaluate(() => imHsSekme('ilanlar')); await bekle();
  t = await metin(); assert.match(t, /Satıldı · 300\.000 ₺/);

  // 8) Ekonomi › Emlak sekmesi ve bildirim yönlendirmesi
  await page.evaluate(() => { D.sekme = 'ekonomi'; D.yigin = []; soMenuSec('ekonomi', 'emlak'); }); await bekle(700);
  t = await metin(); assert.match(t, /İlan Meydanı/); assert.match(t, /Müteahhitten sıfır/);
  await yaz('12_ekonomi_emlak');
  if (await page.evaluate(() => typeof bmKategori === 'function')) {
    const k = await page.evaluate(() => [bmKategori('“Kadıköy daire” ilanına 760.000 ₺ teklif geldi (Burak). 48 saat içinde İlan Meydanı’ndan yanıtla.'),
      bmKategori('Satış tamamlandı: “Deniz Lojistik” 420.000 ₺ bedelle Burak adlı oyuncuya geçti.'), bmKategori('İhale ilanı yayımlandı.')]);
    assert.equal(k[0].rota, 'ilan'); assert.equal(k[0].kat, 'acil'); assert.equal(k[1].rota, 'ilan'); assert.equal(k[1].kat, 'ozel'); assert.notEqual(k[2].rota, 'ilan');
  }
  // eski "Emlak pazarı" ekranı İlan Meydanı'na açılır
  await page.evaluate(() => ekranAc(emlakYeniEkrani)); await bekle(400);
  t = await metin(); assert.match(t, /Emlak ilanları/);

  // 9) 320 px
  await page.setViewportSize({ width: 320, height: 700 });
  await page.evaluate(() => { D.yigin = []; ekranAc(ilanMeydaniEkrani); }); await bekle(400); await tasmaYok('320 ana'); await yaz('13_ana_320');
  await page.evaluate(() => imAc(3)); await bekle(400); await tasmaYok('320 detay'); await yaz('14_detay_320');

  const ilgili = hatalar.filter(h => /\bim[A-Z]|ilan|ILAN/.test(h));
  console.log('sayfa hataları (toplam):', hatalar.length, ilgili.length ? ilgili : '');
  assert.equal(ilgili.length, 0);
  await browser.close();
  console.log('ilan_meydani_arayuz: TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
