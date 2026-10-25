// Bankacılık 2.0 arayüz testi (Mobil Şube, Genel Müdürlük, kasa gizliliği). Ağ yok; sahte RPC; docs/ sunulur.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/bankacilik_arayuz.js [ekran-klasoru]
// Derlenmiş paketi denemek için: KOK_DIZIN=gelistirici/dist (önce node gelistirici/build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../../docs');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const SUBE = {
  kad: 'Deniz', cuzdan: 184250, simdi: S(0), kredi_notu: 1640, not_ad: 'İyi', kara_liste: null,
  toplam: { varlik: 812430.5, banka: 628180.5, borc: 96420 },
  devlet: { iban: 'TR90 0000 1723 0759 17', vadesiz: 42180.5,
    oranlar: { politika: 44.2, vadeli1s: 0.005, vadeli3s: 0.015, vadeli6s: 0.03, vadeli12s: 0.061, vadeli24s: 0.121, vadeli7: 0.848, vadeli30: 3.633 },
    vadeliler: [{ id: 3, anapara: 100000, oran: 0.121, gun: 1, vade_saat: 24, oran_tur: 'vade', acilis: S(-5), vade: S(19), biriken: 25.2 }], kredi: null },
  hesaplar: [
    { banka_id: 12, ad: 'Anadolu Katılım', renk: 'zumrut', slogan: 'Bereketli birikim', iban: 'TR63 0012 0926 5304 83', acilis: S(-200), vadesiz: 86000, vadeli: 400000, kredi: 58420, kart: 0 },
    { banka_id: 203, ad: 'Feniks Bank', renk: 'bordo', slogan: null, iban: 'TR45 0203 0825 6968 24', acilis: S(-40), vadesiz: 0, vadeli: 0, kredi: 0, kart: 38000 }],
  kartlar: [{ id: 7, banka_id: 203, banka: 'Feniks Bank', renk: 'bordo', limit: 120000, borc: 38000, kullanilabilir: 82000, durum: 'aktif', son_dort: '0007', kesim_at: S(60), gecikmis_asgari: 0, nakit_avans: 0,
      ekstre: { id: 4, kesim: S(-100), son_odeme: S(68), toplam: 38000, asgari: 7600, odenen: 0 },
      hareketler: [{ tur: 'harcama', tutar: 12500, aciklama: 'Kuzey Market · POS', zaman: S(-30) }, { tur: 'odeme', tutar: 20000, aciklama: 'Kart borç ödemesi', zaman: S(-90) }] },
    { id: 2, banka_id: null, banka: 'Devlet Bankası', renk: 'devlet', limit: 50000, borc: 0, kullanilabilir: 50000, durum: 'donduruldu', son_dort: '0002', kesim_at: S(80), gecikmis_asgari: 0, nakit_avans: 0, ekstre: null, hareketler: [] }],
  kart_basvurulari: [{ id: 21, banka_id: 12, banka: 'Anadolu Katılım', istek: 150000, istenen: ['kredi_notu', 'maas', 'nakit'], izin: [], teklif_limit: null, basvuru: S(-3) }],
  krediler: [{ id: 27, banka_id: 12, banka: 'Anadolu Katılım', renk: 'zumrut', anapara: 50000, toplam: 54000, kalan: 58420 - 4420, oran: 8, durum: 'aktif', vade_gun: 20, acilis: S(-120), vade: S(360), basvuru: S(-121), taksit_sayisi: 20,
    odenen_taksit: 5, siradaki: { sira: 6, vade: S(4), kalan: 2700 }, geciken: 0, erken_kapama: 41200, icra: null }],
  mevduatlar: [{ id: 4, banka_id: 12, banka: 'Anadolu Katılım', renk: 'zumrut', anapara: 400000, oran: 1.5, getiri: 6000, saat: 168, acilis: S(-50), vade: S(118), vadesi_doldu: false }],
  bekleyen: { teklifler: [{ id: 5, banka: 'Feniks Bank', banka_id: 203, tutar: 75000, vade_gun: 10, taksit_sayisi: 10, faiz: 6.5, mesaj: 'Sadık müşterimize özel', son: S(30),
      plan: { toplam: 79875, taksitler: [{ sira: 1, vade: S(24), tutar: 7987 }, { sira: 2, vade: S(48), tutar: 7987 }] } }],
    bilgi: [], kredi_bilgi: [], pos: [{ id: 91, sirket: 'Kuzey Market', tutar: 2400, aciklama: 'Haftalık alışveriş', olusturma: S(-1) }] },
  hareketler: [
    { kaynak: 'Anadolu Katılım', renk: 'zumrut', tutar: 25000, aciklama: 'FAST gelen: Ayşe · Devlet Bankası: kira', zaman: S(-2) },
    { kaynak: 'Devlet Bankası', renk: 'devlet', tutar: -12000, aciklama: 'FAST giden: Mert · Feniks Bank', zaman: S(-6) },
    { kaynak: 'Kart •••• 0007', renk: 'kart', tutar: -12500, aciklama: 'Kuzey Market · POS', zaman: S(-30) },
    { kaynak: 'Devlet Bankası', renk: 'devlet', tutar: 48000, aciklama: 'Maaş yatırıldı', zaman: S(-40) }],
  bankalar: [
    { id: 12, ad: 'Anadolu Katılım', kurulus: S(-500), renk: 'zumrut', slogan: 'Bereketli birikim', not: 'AAA', durum: 'saglam', mevduat7: 1.5, kredi24: 0.59,
      vadeler: { 1: 0.01, 6: 0.05, 24: 0.22, 168: 1.5 }, paket_sayisi: 6, en_dusuk_kredi: 6, musteri: 14, hesabim: true, bankam: false, kart_otomatik: false, kredi_otomatik: true },
    { id: 203, ad: 'Feniks Bank', kurulus: S(-60), renk: 'bordo', slogan: null, not: 'A', durum: 'saglam', mevduat7: 1.8, kredi24: 0.6,
      vadeler: { 1: 0.02, 6: 0.1, 24: 0.23, 168: 1.8 }, paket_sayisi: 0, en_dusuk_kredi: null, musteri: 9, hesabim: true, bankam: false, kart_otomatik: true, kredi_otomatik: true },
    { id: 301, ad: 'Ege Yatırım Bankası', kurulus: S(-10), renk: 'turkuaz', slogan: 'Denizden güçlü', not: 'BBB', durum: 'dikkat', mevduat7: 1.7, kredi24: 0.8,
      vadeler: { 1: 0.02, 6: 0.08, 24: 0.2, 168: 1.7 }, paket_sayisi: 2, en_dusuk_kredi: 9, musteri: 3, hesabim: false, bankam: false, kart_otomatik: false, kredi_otomatik: false }]
};
const YON = [{ id: 203, ad: 'Feniks Bank', aktif: true, renk: 'bordo', yonetebilir: true, not: 'A', bekleyen: 3 }];
const GM = {
  simdi: S(0), politika_faizi: 44.2,
  banka: { id: 203, ad: 'Feniks Bank', kurulus: S(-60), sermaye: 2000000, kasa: 1279000, yonetici: null, yonetebilir: true, renk: 'bordo', slogan: 'Küllerinden doğan güven',
    emniyet_payi: 100000, risk_profili: 'dengeli', gizlilik: 'gizli', ortaklar: [{ kad: 'Deniz', pay: 100, ben: true, kar_kasada: false }] },
  bilanco: { not: 'A', borc: 55000, dibs: 200000, puan: 84, durum: 'saglam', nakit: 1279000, rezerv: 216500, tampon: 200000, varlik: 2270520, sermaye: 2000000, vadesiz: 55000,
    krediler: 0, likidite: 23.25, ozkaynak: 2215520, kart_alacak: 791520, birikmis_kar: 215520, emniyet_payi: 100000, kart_geciken: 41200, kredi_mevduat: 1439.1, riskli_varlik: 812120,
    takipteki_oran: 5.2, vadeli_anapara: 0, yaklasan_odeme: 0, dibs_alinabilir: 1062500, geciken_mevduat: 0, krediler_geciken: 0, dagitilabilir_kar: 215520, kredi_verilebilir: 962500,
    vadeli_yukumluluk: 0, sermaye_yeterlilik: 272.8, sermaye_azaltilabilir: 1000000 },
  gelir7: { gun: 7, net: 48230, dibs: 1695, faaliyet: 30120, dagitilan: 0, kart_faiz: 12840, kredi_faiz: 0, mevduat_faiz: 0, pos_komisyon: 3575 },
  gelir30: { gun: 30, net: 103764, dibs: 1695, faaliyet: 60240, dagitilan: 50000, kart_faiz: 31840, kredi_faiz: 0, mevduat_faiz: 46, pos_komisyon: 10035 },
  urunler: { mevduat7: 1.8, kredi24: 0.6, vadeler: { 1: 0.02, 3: 0.05, 6: 0.1, 12: 0.15, 24: 0.23 }, pos_komisyon: 2,
    paketler: [{ id: 9, ad: 'Hızlı Nakit', vade_gun: 7, taksit_sayisi: 7, faiz: 7, min_tutar: 5000, max_tutar: 100000, otomatik: true, min_not: 1100, aktif: true, kullanan: 2 }],
    otomatik: { pos: true, kart: true, kredi: true }, asgari_not: 1100, kart_max: 300000, kredi_max: 300000 },
  bekleyen: {
    krediler: [{ id: 31, kad: 'Ayşe', anapara: 100000, vade_gun: 28, taksit_sayisi: 4, oran: 11.02, toplam: 111020, basvuru: S(-1), not: 1490, hesap: true,
      risk: { uygun: true, neden: 'Gelir ve kredi notu uygun', azami_kredi: 102000, haftalik_gelir: 146199 } }],
    kartlar: [{ id: 21, kad: 'Mert', istek: 150000, istenen: ['kredi_notu', 'maas', 'nakit'], izin: ['kredi_notu', 'maas', 'nakit'], basvuru: S(-3), hesap: true, teklif_limit: null,
      bilgi: { kredi_notu: 1840, haftalik_gelir: 131957, nakit: 602 }, kapasite: { uygun: true, neden: 'Uygun', ek_limit: 120000 } },
      { id: 22, kad: 'Selin', istek: 40000, istenen: ['kredi_notu'], izin: [], basvuru: S(-2), hesap: true, teklif_limit: null, bilgi: {}, kapasite: { uygun: false, neden: 'Kredi notu düşük', ek_limit: 0 } }],
    poslar: [{ id: 40, sirket: 'Kuzey Market', sektor: 'market', kad: 'Kerem', basvuru: S(-5), hesap: true }] },
  musteriler: [{ kad: 'Mert', acilis: S(-30), not: 1840, not_ad: 'Çok iyi', vadesiz: 50000, vadeli: 0, kredi: 0, kart: 38000, teklif: null, bilgi: null },
    { kad: 'Ayşe', acilis: S(-20), not: 1490, not_ad: 'Az riskli', vadesiz: 5000, vadeli: 0, kredi: 0, kart: 0, teklif: { id: 5, tutar: 75000, son: S(30) }, bilgi: 'izin' }],
  krediler: [{ id: 12, kad: 'Burak', anapara: 40000, toplam: 44000, kalan: 22000, oran: 10, vade_gun: 10, durum: 'aktif', acilis: S(-200), vade: S(40), geciken: 4400, dava_acilabilir: true, icra: null }],
  kartlar: [{ id: 7, kad: 'Mert', limit: 120000, borc: 38000, durum: 'aktif', gecikmis_asgari: 0, son_dort: '0007' }, { id: 8, kad: 'Burak', limit: 60000, borc: 41200, durum: 'aktif', gecikmis_asgari: 8240, son_dort: '0008' }],
  dibs: [{ id: 1, tutar: 200000, gun: 7, oran: 0.8477, acilis: S(-24), vade: S(144), durum: 'acik', odenen: null, getiri: 1695.4 }],
  dibs_oran: { 1: 0.109, 7: 0.8477, 30: 3.8135 },
  temettuler: [{ tur: 'temettu', brut: 50000, stopaj: 7500, net: 42500, yapan: 'Deniz', zaman: S(-200) }],
  hareketler: [{ zaman: S(-1), tutar: -200000, aciklama: 'DİBS alımı #1: 7 gün vadeli devlet tahvili, %0.8477 getiri (Deniz)', tur: 'banka' },
    { zaman: S(-2), tutar: 5000, aciklama: 'Mert · FAST gelen: Ayşe · Devlet Bankası', tur: 'musteri' },
    { zaman: S(-8), tutar: 1000000, aciklama: 'Ortak Deniz şirket kasasına kendi parasından 1000000 TL yatırdı; paylar değişmedi.', tur: 'banka' }]
};
const GIZ = { sirketler: [{ id: 203, ad: 'Feniks Bank', sektor: 'banka', kasa: 1279000, gorunurluk: 'gizli', ayarlayabilir: true },
  { id: 206, ad: 'Anadolu Danışmanlık', sektor: 'danismanlik', kasa: 106000, gorunurluk: 'herkes', ayarlayabilir: true }],
  dernekler: [{ id: 4, ad: 'Cumhuriyetçi Gençlik', kasa: 138131, gorunurluk: 'uyeler', ayarlayabilir: true }], gazeteler: [] };

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
  await page.waitForFunction(() => window.BANKACILIK_V2 && typeof iskelet === 'function' && typeof mobilSubeEkrani === 'function');
  await page.evaluate(({ SUBE, YON, GM, GIZ }) => {
    window.calls = [];
    API = { rpc: async (ad, args) => {
      calls.push({ ad, args });
      const sabit = { banka_sube: SUBE, banka_yonettiklerim: YON, banka_yonetilen_liste: [{ id: 203, ad: 'Feniks Bank', kasa: 1279000 }], banka_genel_mudurluk: GM, kasa_gizlilik_listem: GIZ,
        banka_alici: { kad: 'Ayşe', yasakli: false, hesaplar: [{ hedef: 'devlet', ad: 'Devlet Bankası', renk: 'devlet' }, { hedef: 'b:12', ad: 'Anadolu Katılım', renk: 'zumrut' }] },
        banka_fast: { tamam: true, yol: 'fast', tutar: 2500, alici: 'Ayşe' }, banka_kar_dagit: { tamam: true, brut: 100000, stopaj: 15000, net: 85000 },
        banka_dibs_al: { tamam: true, getiri: 847.7 }, kasa_gizlilik_ayarla: { tamam: true }, oyb_kredi_karar: { id: 31 } };
      if (ad in sabit) return JSON.parse(JSON.stringify(sabit[ad]));
      throw new Error('sahte: ' + ad);
    } };
    D.durum = { profil: { il_id: 34, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 184250 } } }; D.sekme = 'hayat'; D.yigin = [];
  }, { SUBE, YON, GM, GIZ });
  const yaz = async (ad) => {
    if (!shot) return;
    fs.mkdirSync(shot, { recursive: true });
    await page.evaluate(() => { const a = document.querySelector('#app'); a.dataset.eski = a.style.cssText; a.style.position = 'static'; a.style.height = 'auto';
      document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = 'visible'; }); document.body.style.overflow = 'visible'; document.documentElement.style.height = 'auto'; document.body.style.height = 'auto'; });
    await page.screenshot({ path: path.join(shot, ad + '.png'), fullPage: true });
    await page.evaluate(() => { const a = document.querySelector('#app'); a.style.cssText = a.dataset.eski || ''; document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = ''; }); document.body.style.overflow = ''; document.documentElement.style.height = ''; document.body.style.height = ''; });
  };
  const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
  const bekle = (ms) => page.waitForTimeout(ms || 250);

  // Mobil Şube
  await page.evaluate(() => ekranAc(mobilSubeEkrani)); await bekle(400);
  let t = await metin();
  assert.match(t, /Toplam varlığın/); assert.match(t, /812\.43\d/); assert.match(t, /Genel Müdürlü/); assert.match(t, /kredi teklif etti/);
  assert.match(t, /TR90 0000 1723 0759 17/); assert.doesNotMatch(t, /undefined|NaN/);
  await yaz('01_sube_ozet');
  for (const [s, ad, kalip] of [['kartlar', '02_sube_kartlar', /Dönem borcu/], ['krediler', '03_sube_krediler', /Sıradaki taksit/], ['birikim', '04_sube_birikim', /Faiz karşılaştırması/], ['bankalar', '05_sube_bankalar', /Ege Yatırım Bankası/]]) {
    await page.evaluate((s) => msSekme(s), s); await bekle();
    t = await metin(); assert.match(t, kalip); assert.doesNotMatch(t, /undefined|NaN/); await yaz(ad);
  }
  // FAST
  await page.evaluate(() => msSekme('ozet')); await page.evaluate(() => msFastAc()); await bekle();
  await page.fill('#fsAlici', 'Ayşe'); await page.click('text=Bul'); await bekle();
  await page.click('#fsHedefler button[data-h="b:12"]'); await page.fill('#fsTutar', '2.500'); await page.evaluate(() => msFastOzet()); await bekle();
  t = await page.evaluate(() => document.querySelector('#modal').innerText); assert.match(t, /FAST|EFT/); await yaz('06_fast');
  await page.click('#fsGonder'); await bekle(400);
  const fast = await page.evaluate(() => calls.find(c => c.ad === 'banka_fast'));
  assert.equal(fast.args.p_alici, 'Ayşe'); assert.equal(fast.args.p_hedef, 'b:12'); assert.equal(fast.args.p_tutar, 2500); assert.equal(fast.args.p_kaynak, 'devlet');
  // paraGonderModal(kad) eski çağrı → FAST, alıcı dolu
  await page.evaluate(() => paraGonderModal('Ayşe')); await bekle(400);
  assert.equal(await page.inputValue('#fsAlici'), 'Ayşe'); await page.evaluate(() => modalKapat());

  // Genel Müdürlük
  await page.evaluate(() => bankaGenelMudurlukEkrani(203)); await bekle(400);
  t = await metin(); assert.match(t, /Feniks Bank/); assert.match(t, /Bankacılık oranları/); assert.match(t, /Gelir tablosu/); assert.doesNotMatch(t, /undefined|NaN/);
  await yaz('07_gm_ozet');
  for (const [s, ad, kalip] of [['basvuru', '08_gm_basvuru', /Kredi kartı başvuruları/], ['kasa', '09_gm_kasa', /DİBS/], ['urun', '10_gm_urun', /Risk profili/], ['musteri', '11_gm_musteri', /Geciken krediler/], ['ayar', '12_gm_ayar', /Kasa görünürlüğü/]]) {
    await page.evaluate((s) => gmSekme(s), s); await bekle();
    t = await metin(); assert.match(t, kalip); assert.doesNotMatch(t, /undefined|NaN/); await yaz(ad);
  }
  await page.evaluate(() => gmSekme('kasa')); await page.evaluate(() => gmKarDagit()); await page.fill('#gmKD', '100000'); await page.evaluate(() => gmKarOnizle()); await bekle();
  t = await page.evaluate(() => document.querySelector('#modal').innerText); assert.match(t, /85\.000/); await yaz('13_kar_dagit');
  await page.evaluate(() => modalKapat());
  // Kasa gizliliği
  await page.evaluate(() => ekranAc(kasaGizlilikEkrani)); await bekle(400);
  t = await metin(); assert.match(t, /Üyelere açık/); await yaz('14_kasa_gizlilik');
  // Eski "Bankamı yönet" kısayolları yeni Genel Müdürlüğe açılır (ayar → Ürünler sekmesi)
  await page.evaluate(() => ekranAc(mobilSubeEkrani)); await bekle(300);
  await page.evaluate(() => soBankaYonetimGit('ayar')); await bekle(400);
  t = await metin(); assert.match(t, /Risk profili/);
  await page.evaluate(() => ekranAc(function () { return bankaYonetimEkrani(203, 'basvuru'); })); await bekle(400);
  t = await metin(); assert.match(t, /Kredi kartı başvuruları/);
  // Ekonomi › Bankalar sekmesi (menu_merkezleri): Genel Müdürlük ve Mobil Şube kutuları
  const ekoVar = await page.evaluate(() => typeof soMenuSec === 'function' && typeof ekonomiSekmeEkrani === 'function');
  if (ekoVar) {
    await page.evaluate(() => { D.sekme = 'ekonomi'; D.yigin = []; soMenuSec('ekonomi', 'bankalar'); }); await bekle(800);
    t = await metin(); assert.match(t, /Benim bankalarım/); assert.match(t, /Mobil Şube/); assert.doesNotMatch(t, /undefined|NaN/);
    await yaz('16_eko_bankalar');
  }
  // gizliTL
  const g = await page.evaluate(() => [gizliTL(null), gizliTL(1500)]);
  assert.match(g[0], /Gizli/); assert.match(g[1], /1\.500/);
  // 320 px
  await page.setViewportSize({ width: 320, height: 700 });
  await page.evaluate(() => ekranAc(mobilSubeEkrani)); await bekle(400);
  const tasma = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
  assert.equal(tasma, false, '320 px yatay taşma');
  await yaz('15_sube_320');

  const ilgili = hatalar.filter(h => /bankacilik|msSekme|gm[A-Z]|mobilSube|kasaGizlilik/.test(h));
  console.log('sayfa hataları (toplam):', hatalar.length, ilgili.length ? ilgili : '');
  assert.equal(ilgili.length, 0);
  await browser.close();
  console.log('bankacilik_arayuz: TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
