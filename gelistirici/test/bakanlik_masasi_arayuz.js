// Bakanlık masası, devlet bütçesi, bakanlık etkinlikleri, cüzdan hareketleri, şirket inceleme raporu ve
// toptan tedarikte mağaza stoğu arayüz testi (27.10.2026). Ağ yok; sahte RPC.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/bakanlik_masasi_arayuz.js [ekran-klasoru]
// Sayfa gelistirici/dist/index.html'den, dinamik modüller docs/ klasöründen sunulur.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const BAKANLIKLAR = [['adalet', 'Adalet'], ['disisleri', 'Dışişleri'], ['icisleri', 'İçişleri'], ['maliye', 'Hazine ve Maliye'], ['savunma', 'Millî Savunma'], ['egitim', 'Millî Eğitim'],
  ['saglik', 'Sağlık'], ['sanayi', 'Sanayi ve Teknoloji'], ['ticaret', 'Ticaret'], ['tarim', 'Tarım ve Orman'], ['ulastirma', 'Ulaştırma'], ['calisma', 'Çalışma ve Sosyal Güvenlik']];
const ICRAATLAR = [
  { kod: 'adl_harc', ad: 'Harç muafiyeti', etki: { memnuniyet: 0.5 }, ozel: null, hazir: null, oyuncu: [{ tur: 'tasinma', deger: 50 }], maliyet: 3,
    aciklama: 'Tapu, nüfus ve noter harçları kaldırılır: taşınma masrafı 7 gün boyunca yarıya iner.', sure_gun: 7, aktif_bit: null, il_gerekli: false, bekleme_saat: 168 },
  { kod: 'adl_adliye', ad: 'Yeni adliye binası', etki: { gelisim: 0.4 }, ozel: null, hazir: S(20), oyuncu: [], maliyet: 5,
    aciklama: 'Seçilen ile modern adliye binası yapılır.', sure_gun: null, aktif_bit: null, il_gerekli: true, bekleme_saat: 72 }];
const MASA = {
  kod: 'adalet', ad: 'Adalet Bakanlığı', yetki: 'bakan', simdi: S(0), bakan: { kad: 'Deniz', parti: { kisa: 'CTP', renk: '#c22' }, bas: S(-200) },
  yurutme: 'Ercan', sistem: 'baskanlik', kasa: 42.5, pay: 8, gunluk: 0.813, tavan: 100, ozet7: { gelir: 5.69, gider: 3.5 },
  dagilim30: [{ tur: 'gunluk', giris: 12.2, cikis: 0 }, { tur: 'icraat', giris: 0, cikis: 6 }, { tur: 'etkinlik', giris: 0, cikis: 3 }, { tur: 'odenek', giris: 10, cikis: 0 }],
  hareketler: [
    { zaman: S(-1), tutar: 0.813, bakiye: 42.5, tur: 'gunluk', aciklama: 'Günlük bütçe ödeneği (bütçe kanunu payı)', kim: null },
    { zaman: S(-5), tutar: -3, bakiye: 41.69, tur: 'etkinlik', aciklama: 'Etkinlik: Adalet Fuarı (Ankara)', kim: 'Deniz' },
    { zaman: S(-30), tutar: 0, bakiye: 100, tur: 'tavan', aciklama: 'Kasa tavanda (100 milyar ₺): 0,81 milyar ₺ ödenek Hazine\'de kaldı', kim: null }],
  icraatlar: ICRAATLAR, politikalar: [],
  gorevler: { hafta: S(-50), bitis: S(80), odul: 1, bonus: 2, liste: [
    { kod: 'icraat2', ad: 'İki icraat uygula', aciklama: 'Bu hafta bakanlığından iki icraat başlat.', hedef: 2, ilerleme: 2, tamam: true, alindi: false },
    { kod: 'etkinlik1', ad: 'Bir etkinlik düzenle', aciklama: 'Oyunculara açık bir bakanlık etkinliği düzenle.', hedef: 1, ilerleme: 0, tamam: false, alindi: false },
    { kod: 'aciklama1', ad: 'Kamuoyuna açıklama yap', aciklama: 'Bakanlık adına bir açıklama yayımla.', hedef: 1, ilerleme: 1, tamam: true, alindi: true }] },
  etkinlik_turleri: [
    { kod: 'bke_adalet_1', ad: 'Adalet Fuarı', aciklama: 'Adliyeler halka açılır, hukuk danışma masaları kurulur.', maliyet: 3, sure_saat: 24, il_gerekli: true, etki: { il_memnuniyet: 1, memnuniyet: 0.2 }, kidem: 0.5, bekleme_saat: 72, hazir: null },
    { kod: 'bke_adalet_2', ad: 'Hukuk Haftası', aciklama: 'Ülke çapında seminerler.', maliyet: 4, sure_saat: 48, il_gerekli: false, etki: { memnuniyet: 0.4 }, kidem: 0.5, bekleme_saat: 96, hazir: S(10) }],
  etkinlikler: [
    { id: 11, tur: 'bke_adalet_1', ad: 'Adalet Fuarı', il: 'Ankara', bas: S(-5), bit: S(19), durum: 'aktif', katilimci: 7, yerel: 5, sonuc: null, not: 'Hepinizi bekleriz', aktif: true },
    { id: 9, tur: 'bke_adalet_2', ad: 'Hukuk Haftası', il: null, bas: S(-120), bit: S(-72), durum: 'bitti', katilimci: 12, yerel: 0, sonuc: { carpan: 2, etki: { memnuniyet: 0.8 } }, not: null, aktif: false }],
  ziyaret: { maliyet: 0.5, bekleme_saat: 12, hazir: null, son: [{ il: 'İzmir', zaman: S(-30), not: 'Adliye inşaatını denetledik', kad: 'Deniz' }] },
  aciklama: { bekleme_dk: 360, hazir: S(2), son: [{ baslik: 'Harçlar kaldırıldı', metin: 'Bir hafta boyunca tapu ve noter harcı alınmayacak.', zaman: S(-4), kad: 'Deniz' }] },
  talepler: [{ id: 4, tutar: 10, gerekce: 'Deprem bölgesindeki adliyeler', durum: 'bekliyor', zaman: S(-3), bitis: S(69), karar_zaman: null, karar_not: null },
    { id: 2, tutar: 5, gerekce: 'Cezaevi bakımı', durum: 'red', zaman: S(-100), bitis: S(-28), karar_zaman: S(-90), karar_not: 'Hazine sıkışık' }],
  talep_ayar: { ust: 25, sure_saat: 72, hazir: null },
  sorumluluk: { cimer_bekleyen: 2, soru_bekleyen: 0 },
  karne: { puan: 64, gorev: 4, icraat: 5, etkinlik: 2, katilim: 11, ziyaret: 3, cimer: 4, cimer_yanit: 3, soru: 1, soru_yanit: 1, harcama: 22.4, odenek: 10, gun: 28 }
};
const ETK = { simdi: S(0), il_id: 6, bugun_odul: 1, gunluk_odul: 2, liste: [
  { id: 11, tur: 'bke_adalet_1', ad: 'Adalet Fuarı', aciklama: 'Adliyeler halka açılır.', bakanlik: 'adalet', bakanlik_ad: 'Adalet Bakanlığı', il: 'Ankara', il_id: 6, kad: 'Deniz', not: 'Hepinizi bekleriz',
    bas: S(-5), bit: S(19), durum: 'aktif', aktif: true, katilimci: 7, yerel: 5, kidem: 0.5, sonuc: null, benim: null, duzenleyen_benim: false, tepkiler: { katildim: 3, destek: 3, elestiri: 1 } },
  { id: 9, tur: 'bke_saglik_1', ad: 'Sağlık Taraması', aciklama: 'Ücretsiz tarama.', bakanlik: 'saglik', bakanlik_ad: 'Sağlık Bakanlığı', il: null, il_id: null, kad: 'Mert', not: null,
    bas: S(-60), bit: S(-12), durum: 'bitti', aktif: false, katilimci: 12, yerel: 0, kidem: 0.5, sonuc: { carpan: 2, etki: { memnuniyet: 0.8 } }, benim: 'katildim', duzenleyen_benim: false, tepkiler: { katildim: 12, destek: 0, elestiri: 0 } }] };
const BUTCE = { simdi: S(0), yetkili: true, cb: true, yurutme: 'Ercan', sistem: 'baskanlik', hazine: 52.3, hesap: { gelir: 13.98, gider: 12.207, denge: 1.773, cari: 10.164 },
  tavan: 100, aktarim_oran: 25, aktarim_bekleme_saat: 24, talep_ust: 25, son_tahsis: S(-30),
  bakanliklar: BAKANLIKLAR.map(([kod, ad], i) => ({ kod, ad: ad + ' Bakanlığı', kasa: 10 + i * 3.3, pay: 8.33, gunluk: 0.847, bakan: i % 3 ? 'Oyuncu' + i : null, harcama7: i * 0.7, aktarim_hazir: null, aktif_etkinlik: i === 0, puan: 30 + i * 5 })),
  talepler: [{ id: 4, kod: 'adalet', ad: 'Adalet Bakanlığı', kad: 'Deniz', tutar: 10, gerekce: 'Deprem bölgesindeki adliyeler', durum: 'bekliyor', zaman: S(-3), bitis: S(69), karar_zaman: null, karar_not: null },
    { id: 3, kod: 'saglik', ad: 'Sağlık Bakanlığı', kad: 'Mert', tutar: 6, gerekce: 'Aşı kampanyası', durum: 'onay', zaman: S(-50), bitis: S(22), karar_zaman: S(-40), karar_not: 'Uygun' }] };
const CUZDAN = (saat) => ({ saat, bas: S(-saat), simdi: S(0), para: 184250, giris: 52000, cikis: 18000, vergi: 1200, adet: 6,
  gruplar: [{ tur: 'maas', giris: 40000, cikis: 0, adet: 3 }, { tur: 'sirket', giris: 12000, cikis: 15000, adet: 2 }, { tur: 'kazikazan', giris: 0, cikis: 3000, adet: 1 }],
  liste: [{ zaman: S(-1), tutar: 13500, vergi: 400, tur: 'maas', aciklama: 'Maaş (8,0 saat, seri +%10)' }, { zaman: S(-2), tutar: -15000, vergi: 0, tur: 'sirket', aciklama: 'Akaryakıt İstasyonu kuruluş sermayesi' },
    { zaman: S(-3), tutar: 12000, vergi: 0, tur: 'sirket', aciklama: 'Kuzey Market kâr payı' }, { zaman: S(-5), tutar: -3000, vergi: 0, tur: 'kazikazan', aciklama: 'Kazı Kazan bileti' },
    { zaman: S(-9), tutar: 13250, vergi: 400, tur: 'maas', aciklama: 'Maaş (8,0 saat)' }, { zaman: S(-17), tutar: 13250, vergi: 400, tur: 'maas', aciklama: 'Maaş (8,0 saat)' }] });
const RAPOR = { ad: 'GÖKBEY REKLAM AJANSI', id: 184, il: 'Ankara', not: 'Şirketin tamamı satılık: kasa, stok, varlıklar ve yükümlülükler alıcıya geçer; mali tablo alıcılara açıktır.', pay: 100, kasa: 147000,
  son7: { net: 8200, marj: 21.4, gelir: 38300, gider: 30100 }, sube: 1, borsa: false, durum: 'satilik', fiyat: 350000, ortak: false,
  son30: { net: 31000, marj: 19.9, gelir: 155600, gider: 124600 }, hukuki: 'ltd', kurucu: 'Sadık', sektor: 'ajans', toplam: { net: 64000, marj: 18.2, gelir: 351000, dagitilan: 20000 },
  ilan_id: 17, kurulus: S(-120), sermaye: 150000, ortaklar: [{ kad: 'Sadık', pay: 100 }], kasa_gizli: false, stok_degeri: 0, donem_kaynak: 'faaliyet',
  fiyat_defter: 2.38, fiyat_kazanc: 0.9, yillik_net_tahmini: 377167, sermaye_getirisi_30: 20.7 };
const VITRIN = { sirketler: [{ id: 184, ad: 'GÖKBEY REKLAM AJANSI', sektor: 'ajans', il: 'Ankara', sahip: 'Sadık', kurucu: 'Sadık', sermaye: 150000, net_kazanc: 64000, satilik: 350000, aktif: true,
  ortaklar: [{ kad: 'Sadık', pay: 100 }], kasa: 147000, toplam_gelir: 351000, vergi: 5000, kurulus: S(-120) }] };
const TICARET = { sirketler: [{ id: 5, ad: 'AlpEMarket', tur: 'magaza', kategori: 'market', yonetici: true, kasa: 250000, grup: 'market' }],
  urunler: [{ kod: 'ekmek', ad: 'Ekmek', maliyet: 5, satis: 15, parti: 50 }, { kod: 'sut', ad: 'Süt', maliyet: 12, satis: 30, parti: 40 }],
  stok: [{ sirket: 5, urun: 'ekmek', adet: 12, maliyet: 8, fiyat: 15 }, { sirket: 5, urun: 'sut', adet: 4, maliyet: 20, fiyat: 32 }],
  tedarikciler: [{ sirket: 9, ad: 'Anadolu Gıda Fabrikası', urun: 'ekmek', adet: 80, fiyat: 8 }, { sirket: 9, ad: 'Anadolu Gıda Fabrikası', urun: 'sut', adet: 30, fiyat: 21 }],
  uretim: [], satislar: [], zincirler: [], oto: [] };

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
  page.on('pageerror', e => hatalar.push(e.message));
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (u.hostname !== 'oyun.test') return r.abort();
    const ad = decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname);
    let f = path.join(KOK, ad); if (!fs.existsSync(f)) f = path.join(YEDEK, ad);
    if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
    r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
  });
  await page.goto('http://oyun.test/index.html'); console.log('sayfa açıldı');
  await page.waitForFunction(() => window.SO_BAKANLIK_MASASI_V1 && window.SO_CUZDAN_HAREKET_V1 && window.SO_SIRKET_RAPORU_V1 && typeof iskelet === 'function');
  await page.waitForTimeout(800);
  await page.evaluate(({ MASA, ETK, BUTCE, CUZDAN_S, RAPOR, VITRIN, TICARET, ICRAATLAR }) => {
    const CUZDAN = eval(CUZDAN_S);
    window.calls = [];
    const panel = { kod: 'adalet', ad: 'Adalet Bakanlığı', kasa: 42.5, pay: 8, gunluk: 0.813, icraatlar: ICRAATLAR, politikalar: [] };
    const sahte = (ad, a) => {
      switch (ad) {
        case 'bakanlik_masasi': return MASA;
        case 'bakanlik_etkinlikleri': return ETK;
        case 'yurutme_butce_masasi': case 'bakanlik_odenek_karar': case 'bakanlik_odenek_aktar': return BUTCE;
        case 'cuzdan_hareketleri': return CUZDAN(a.p_saat || 24);
        case 'sirket_satis_raporu': case 'ilan_sirket_raporu': return RAPOR;
        case 'sirket_vitrini': return VITRIN;
        case 'sirket_liste': return { sirketler: [] };
        case 'bakanlik_panellerim': return [panel];
        case 'icraat_yap': return { tamam: true };
        case 'bakanlik_gorev_odul_al': return Object.assign({}, MASA, { kazanilan: 1 });
        case 'bakanlik_etkinlik_duzenle': return Object.assign({}, MASA, { yeni_etkinlik: 12, bildirilen: 41 });
        case 'bakanlik_saha_ziyareti': case 'bakanlik_aciklama_yap': case 'bakanlik_odenek_iste': case 'bakanlik_hazineye_iade': return MASA;
        case 'bakanlik_etkinlik_katil': return { odul: 0.5, tepki: a.p_tepki, yerel: true };
        case 'eko_ticaret_panel': return TICARET;
        case 'eko_otomasyon_panel': return { uretim: [], kendi: [], satis: [] };
        case 'magaza_durum': return { satis_acik: true, paketler: [], kart: null };
      }
      throw new Error('sahte: ' + ad);
    };
    API = { rpc: async (ad, args) => { calls.push({ ad, args }); return JSON.parse(JSON.stringify(sahte(ad, args || {}))); } };
    D.durum = { profil: { id: 'u1', il_id: 6, kad: 'Deniz', parti: null, makamlar: [{ tur: 'bakan', bakanlik: 'adalet', bakanlik_ad: 'Adalet Bakanlığı' }], cuzdan: { para: 184250 } } };
    D.sekme = 'devlet'; D.yigin = []; D._bakanPanelleri = [panel];
  }, { MASA, ETK, BUTCE, CUZDAN_S: CUZDAN.toString().replace(/\bS\(/g, '((h)=>new Date(Date.now()+h*3600e3).toISOString())('), RAPOR, VITRIN, TICARET, ICRAATLAR });
  const yaz = async (ad) => {
    if (!shot) return;
    fs.mkdirSync(shot, { recursive: true });
    await page.evaluate(() => { const a = document.querySelector('#app'); a.dataset.eski = a.style.cssText; a.style.position = 'static'; a.style.height = 'auto';
      document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = 'visible'; }); document.body.style.overflow = 'visible'; document.documentElement.style.height = 'auto'; document.body.style.height = 'auto'; });
    await page.screenshot({ path: path.join(shot, ad + '.png'), fullPage: true });
    await page.evaluate(() => { const a = document.querySelector('#app'); a.style.cssText = a.dataset.eski || ''; document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = ''; }); document.body.style.overflow = ''; document.documentElement.style.height = ''; document.body.style.height = ''; });
  };
  const yazModal = async (ad) => { if (!shot) return; fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, ad + '.png') }); };
  const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
  const modalMetin = () => page.evaluate(() => (document.querySelector('#modal') || {}).innerText || '');
  const bekle = (ms) => page.waitForTimeout(ms || 250);
  const son = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);
  const temiz = (t, yer) => { assert.doesNotMatch(t, /undefined|NaN|\[object Object\]/, yer); };

  // 1) Bakanlık masası — Özet
  console.log('adım 1');
  await page.evaluate(() => ekranAc(function () { return bakanlikMasasiEkrani('adalet'); })); await bekle(500);
  let t = await metin();
  assert.match(t, /Bakanlık kasası/); assert.match(t, /42,5/); assert.match(t, /Bu haftanın görevleri/); assert.match(t, /Bakan karnesi/);
  assert.match(t, /CİMER başvuruları/); assert.match(t, /Adalet Fuarı/); assert.match(t, /Bakanlıktan istifa et/); temiz(t, 'özet');
  await yaz('01_masa_ozet');
  // görev ödülü
  await page.evaluate(() => bmGorevOdul('icraat2')); await bekle();
  let c = await son('bakanlik_gorev_odul_al'); assert.equal(c.args.p_kod, 'adalet'); assert.equal(c.args.p_gorev, 'icraat2');
  // sekmeler
  for (const [s, ad, kalip] of [['icraat', '02_masa_icraat', /Harç muafiyeti[\s\S]*Uygula · 3/], ['etkinlik', '03_masa_etkinlik', /Sürüyor[\s\S]*Hukuk Haftası/], ['butce', '04_masa_butce', /Hesap defteri[\s\S]*Günlük bütçe ödeneği/], ['iletisim', '05_masa_iletisim', /Saha ziyaretleri[\s\S]*İzmir/]]) {
    await page.evaluate((s) => bmSekme(s), s); await bekle();
    t = await metin(); assert.match(t, kalip, s); temiz(t, s); await yaz(ad);
  }
  // İcraat: tıklayınca onay penceresi çıkmalı (eskiden sessizce hiçbir şey olmuyordu)
  await page.evaluate(() => bmSekme('icraat')); await bekle();
  await page.click('text=Uygula · 3'); await bekle();
  t = await modalMetin(); assert.match(t, /Harç muafiyeti|3 milyar/); await yazModal('06_icraat_onay');
  await page.click('#evet'); await bekle(500);
  c = await son('icraat_yap'); assert.equal(c.args.p_kod, 'adl_harc');
  assert.ok(await page.evaluate(() => !!document.getElementById('bmMasa')), 'icraat sonrası masa yenilenmeli');
  // Etkinlik düzenle
  await page.evaluate(() => bmEtkinlikModal('bke_adalet_1')); await bekle();
  t = await modalMetin(); assert.match(t, /hangi ilde/); await yazModal('07_etkinlik_modal');
  await page.fill('#bmEtkNot', 'Bekleriz'); await page.click('#bmEtkOk'); await bekle(400);
  c = await son('bakanlik_etkinlik_duzenle'); assert.equal(c.args.p_tur, 'bke_adalet_1'); assert.equal(c.args.p_il, 6); assert.equal(c.args.p_not, 'Bekleriz');
  // Ek ödenek talebi, ziyaret, açıklama, iade
  await page.evaluate(() => bmTalepModal()); await bekle(); await page.fill('#bmTTutar', '12'); await page.fill('#bmTGer', 'Adliyeler için ek kaynak'); await yazModal('08_talep_modal');
  await page.click('#bmTOk'); await bekle(300); c = await son('bakanlik_odenek_iste'); assert.equal(c.args.p_tutar, 12); assert.equal(c.args.p_kod, 'adalet');
  await page.evaluate(() => bmZiyaretModal()); await bekle(); await page.click('#bmZOk'); await bekle(300); c = await son('bakanlik_saha_ziyareti'); assert.equal(c.args.p_il, 6);
  await page.evaluate(() => bmAciklamaModal()); await bekle(); await page.fill('#bmABas', 'Başlık'); await page.fill('#bmAMetin', 'Kamuoyuna duyurulur.'); await page.click('#bmAOk'); await bekle(300);
  c = await son('bakanlik_aciklama_yap'); assert.equal(c.args.p_baslik, 'Başlık');
  await page.evaluate(() => bmIadeModal()); await bekle(); await page.fill('#bmITutar', '2.5'); await page.click('#bmIOk'); await bekle(300);
  c = await son('bakanlik_hazineye_iade'); assert.equal(c.args.p_tutar, 2.5);

  // 2) Yönetim/Devlet içindeki kısa kart ve eski icraatYap yolu (D._bakanPanelleri)
  console.log('adım 2');
  const kart = await page.evaluate(() => bakanPanelHtml(D._bakanPanelleri[0], false));
  assert.match(kart, /Bakanlık masasını aç/); assert.match(kart, /bakanIstifa/);
  await page.evaluate(() => { D._bmPaneller = []; D._panel = null; D._vekil = []; });
  await page.evaluate(() => { icraatYap('adl_harc', false); }); await bekle();
  t = await modalMetin(); assert.match(t, /Harç muafiyeti/); await page.evaluate(() => modalKapat());

  // 3) Devlet bütçesi (yürütme)
  console.log('adım 3');
  await page.evaluate(() => ekranAc(kamuButceEkrani)); await bekle(400);
  t = await metin(); assert.match(t, /Merkezi Yönetim Bütçesi/); assert.match(t, /Karar bekleyen ek ödenek/); assert.match(t, /Çalışma ve Sosyal Güvenlik/); assert.match(t, /Merkezi bütçe tahsisi/); temiz(t, 'bütçe');
  await yaz('09_devlet_butcesi');
  await page.evaluate(() => bmKarar(4, true)); await bekle(); await yazModal('10_karar_modal'); await page.click('#bmKOk'); await bekle(300);
  c = await son('bakanlik_odenek_karar'); assert.equal(c.args.p_id, 4); assert.equal(c.args.p_kabul, true);
  await page.evaluate(() => bmAktarModal()); await bekle(); await page.fill('#bmAT', '1.5'); await page.click('#bmAOk2'); await bekle(300);
  c = await son('bakanlik_odenek_aktar'); assert.equal(c.args.p_tutar, 1.5); assert.notEqual(c.args.p_kaynak, c.args.p_hedef);
  await page.evaluate(() => bmTahsisModal()); await bekle(); t = await modalMetin(); assert.match(t, /Toplam pay/); await page.evaluate(() => modalKapat());

  // 4) Bakanlık etkinlikleri (herkes)
  console.log('adım 4');
  await page.evaluate(() => ekranAc(bakanlikEtkinlikleriEkrani)); await bekle(400);
  t = await metin(); assert.match(t, /bugün 1 ödüllü katılım hakkın/); assert.match(t, /Destekliyorum/); assert.match(t, /Son 48 saatte tamamlananlar/); temiz(t, 'etkinlikler');
  await yaz('11_etkinlikler');
  await page.evaluate(() => bmKatil(11, 'destek')); await bekle(400);
  c = await son('bakanlik_etkinlik_katil'); assert.equal(c.args.p_id, 11); assert.equal(c.args.p_tepki, 'destek');

  // 5) Gündem şeridi ve Devlet › Hükümet kartı
  console.log('adım 5');
  await page.evaluate(() => { D.yigin = []; D.sekme = 'gundem'; iskelet('Gündem', '<div class="kart">akış</div>'); }); await bekle(500);
  assert.ok(await page.evaluate(() => !!document.getElementById('bmGundemSerit')), 'Gündem etkinlik şeridi');
  await page.evaluate(() => { D.sekme = 'devlet'; D.devletSekme = 'hukumet'; iskelet('Devlet', '<div class="segment"><button class="aktif">Hükümet</button><button>Mevzuat</button></div><div class="kart">bağış</div><div class="kart">kabine</div>'); }); await bekle(400);
  t = await metin(); assert.match(t, /Bakanlık masam/); assert.match(t, /Bakanlık etkinlikleri — katıl/);

  // 6) Cüzdan hareketleri
  console.log('adım 6');
  await page.evaluate(() => { D.yigin = []; D.sekme = 'hayat'; iskelet('Hayat', '<section class="kart">Hayat</section>'); }); await bekle(500);
  assert.ok(await page.evaluate(() => !!document.getElementById('czHayatSerit')), 'Hayat cüzdan şeridi');
  const cip = await page.evaluate(() => { const c2 = document.querySelector('.ust .para-cip'); return c2 ? c2.getAttribute('onclick') : null; });
  if (cip) assert.match(cip, /cuzdanEkrani/);
  await page.evaluate(() => ekranAc(cuzdanEkrani)); await bekle(400);
  t = await metin(); assert.match(t, /Para nereden geldi/); assert.match(t, /Maaş/); assert.match(t, /Kazı Kazan/); assert.match(t, /Akaryakıt İstasyonu kuruluş sermayesi/); temiz(t, 'cüzdan');
  await yaz('12_cuzdan');
  await page.evaluate(() => czSaat(168)); await bekle(300); c = await son('cuzdan_hareketleri'); assert.equal(c.args.p_saat, 168);
  await page.evaluate(() => czFiltre('maas')); await bekle(); t = await metin(); assert.doesNotMatch(t, /Kazı Kazan bileti/);

  // 7) Şirket inceleme raporu
  console.log('adım 7');
  await page.evaluate(() => ekranAc(function () { return sirketRaporuEkrani(null, 17); })); await bekle(400);
  t = await metin(); assert.match(t, /Gelir tablosu/); assert.match(t, /Kâr marjı/); assert.match(t, /147\.000/); assert.match(t, /Sermaye getirisi/); temiz(t, 'rapor');
  c = await son('ilan_sirket_raporu'); assert.equal(c.args.p_ilan, 17);
  await yaz('13_sirket_raporu');
  if (await page.evaluate(() => typeof sirketPazarDetay === 'function')) {
    await page.evaluate(() => ekranAc(function () { return sirketPazarDetay(184); })); await bekle(500);
    t = await metin(); assert.match(t, /Kârlılık ve kasa/); assert.match(t, /Satış fiyatı/); temiz(t, 'satılık detay');
    await yaz('14_satilik_detay');
  }

  // 8) Toptan tedarik: mağazanın kendi stoğu görünür
  console.log('adım 8');
  await page.waitForFunction(() => typeof window.tcWholesale === 'function', null, { timeout: 8000 }).catch(() => {});
  if (await page.evaluate(() => typeof ticaretMerkezEkrani === 'function' && typeof tcWholesale === 'function')) {
    await page.evaluate(() => ticaretMerkezEkrani('magaza')); await bekle(500);
    await page.evaluate(() => tcWholesale(5)); await bekle();
    t = await modalMetin(); assert.match(t, /Mağazandaki stok: 16 adet/); assert.match(t, /Ekmek/); assert.match(t, /Mağazanda bu üründen 12 adet/);
    await yazModal('15_toptan_stok'); await page.evaluate(() => modalKapat());
  } else console.log('UYARI: ticaret modülü yüklenmedi, toptan testi atlandı');

  // 9) Bildirim yönlendirmesi
  console.log('adım 9');
  const rota = await page.evaluate(() => [bmKategori('Bakanlık: Ankara ilimizde "Adalet Fuarı" düzenliyor. Katıl, kıdem kazan!').rota,
    bmKategori('Bakanlık: Adalet Bakanı Deniz, 10 milyar ₺ ek ödenek istiyor. Gerekçe: x (Devlet bütçesi ekranından karar ver.)').rota,
    bmKategori('Bakanlık: 10 milyar ₺ ek ödenek talebin onaylandı ve kasaya geçti.').rota]);
  assert.deepEqual(rota, ['bk_etkinlik', 'butce', 'bakanlik']);

  // 10) 320 px taşma
  console.log('adım 10');
  await page.setViewportSize({ width: 320, height: 700 });
  for (const s of ['ozet', 'butce']) {
    await page.evaluate((s) => ekranAc(function () { return bakanlikMasasiEkrani('adalet', s); }), s); await bekle(400);
    const tasma = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
    assert.equal(tasma, false, '320 px yatay taşma: ' + s);
  }
  await yaz('16_masa_320');
  await page.evaluate(() => ekranAc(cuzdanEkrani)); await bekle(400);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1), false, '320 px cüzdan');

  const ilgili = hatalar.filter(h => /bakanlik|bm[A-Z]|cuzdan|cz[A-Z]|sirketRapor|wholesale|tcWholesale|iskelet/.test(h));
  console.log('sayfa hataları (toplam):', hatalar.length, ilgili.length ? ilgili : '');
  assert.equal(ilgili.length, 0);
  await browser.close();
  console.log('bakanlik_masasi_arayuz: TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
