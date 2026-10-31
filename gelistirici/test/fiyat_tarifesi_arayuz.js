// Fiyat Tarifesi ve ekip partisi (kurucular kurulu, kuruluş fonu) arayüz testi (31.10.2026). Ağ yok; sahte RPC.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/fiyat_tarifesi_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const TARIFE = {
  endeks: 1.02, asgari: 30000, baslangic: 150000, reklam_odul: 334,
  ben: { kidem: 12, statu: 1, statu_ad: 'Vatandaş', sonraki_ad: 'Saygın Vatandaş', sonraki_esik: 30, gunluk_net: 5002, para: 208977,
    sirket: { statu: 1, hak: 1, kullanilan: 0, sonraki_ad: 'Saygın Vatandaş', sonraki_hak: 2, sonraki_esik: 30 } },
  statuler: [
    { basamak: 0, ad: 'Yeni Gelen', esik: 0, maas_carpan: 1, sirket_hakki: 0, acilan: [] },
    { basamak: 1, ad: 'Vatandaş', esik: 10, maas_carpan: 1.2, sirket_hakki: 1, acilan: ['Şirket ve dükkân kurmak', 'Gazete kurmak', 'Dernek kurmak', 'Parti kurucu üyesi olmak'] },
    { basamak: 2, ad: 'Saygın Vatandaş', esik: 30, maas_carpan: 1.4, sirket_hakki: 2, acilan: ['Reklam ajansı kurmak', 'Parti kurma başvurusu'] },
    { basamak: 3, ad: 'Kanaat Önderi', esik: 75, maas_carpan: 1.6, sirket_hakki: 3, acilan: ['Banka kurmak'] },
    { basamak: 4, ad: 'Duayen', esik: 150, maas_carpan: 1.8, sirket_hakki: 5, acilan: [] },
    { basamak: 5, ad: 'Yaşayan Efsane', esik: 300, maas_carpan: 2, sirket_hakki: 8, acilan: [] }],
  sektorler: [
    { kod: 'ticaret', ad: 'Toptan ve Perakende Ticaret', min: 200000 }, { kod: 'teknoloji', ad: 'Bilişim ve Yazılım', min: 200000 },
    { kod: 'market', ad: 'Market Zinciri', min: 500000 }, { kod: 'turizm', ad: 'Turizm ve Otelcilik', min: 500000 },
    { kod: 'ozel_hastane', ad: 'Özel Hastane', min: 1000000 }, { kod: 'akaryakit', ad: 'Akaryakıt İstasyonu', min: 1000000 },
    { kod: 'enerji', ad: 'Enerji Santrali', min: 1500000 }, { kod: 'oto_galeri', ad: 'Otomobil Galerisi', min: 2500000 }],
  kurumlar: [
    { ad: 'Banka', tutar: 15000000, statu: 'Kanaat Önderi', not: 'Kuruluş sermayesi; ortaklı kurulabilir' },
    { ad: 'Reklam ve anket ajansı', tutar: 400000, statu: 'Saygın Vatandaş', not: 'Kuruluş sermayesi' },
    { ad: 'Gazete', tutar: 152965, statu: 'Vatandaş', not: 'Kuruluş bedeli' },
    { ad: 'Dernek', tutar: 51000, statu: 'Vatandaş', not: 'Kuruluş harcı' },
    { ad: 'Dernek şubesi', tutar: 5100, en_cok: 15300, statu: null, not: 'İl büyüklüğüne göre' }],
  parti: { kurucu_kurulu: 7, harc: 509882, fon: 1019800, kurucu_statu: 'Saygın Vatandaş', ortak_statu: 'Vatandaş', kurucu_hesap_gun: 14, ortak_hesap_gun: 7,
    bekleme_gun: 90, basvuru_gun: 10, oran: 2, en_cok: 30, teskilat: 10198, teskilat_en_cok: 30593 },
  siyaset: [
    { ad: 'Milletvekili aday adaylığı', tutar: 15296, not: 'Partinin kasasına girer' },
    { ad: 'Belediye başkanı aday adaylığı', tutar: 10198, en_cok: 30593, not: 'İl büyüklüğüne göre' },
    { ad: 'Cumhurbaşkanı aday adaylığı', tutar: 152965, not: 'Parti içi ön seçim' },
    { ad: 'Taşınma', tutar: 2040, not: 'Devlet desteği %80 düşülmüş' }],
  getiri: [
    { ad: 'Konut ve dükkân kirası', oran: 2, birim: 'hafta', not: 'Önceden alınan mülkler eski kirasıyla devam eder' },
    { ad: 'İkinci ve sonraki makam maaşı', oran: 25, birim: 'tam maaşın', not: 'En yüksek makam maaşı tam ödenir' }]
};
const DAVET = {
  kurallar: { kurucu_kurulu: 7, harc: 509882, fon: 1019800, katki_min: 10000, kurucu_statu: 'Saygın Vatandaş', ortak_statu: 'Vatandaş', kurucu_hesap_gun: 14, ortak_hesap_gun: 7, basvuru_gun: 10, engel: null },
  basvurum: { id: 24, ad: 'Kuzey Yıldızı Topluluğu', kisa: 'KZT', bit: S(200), ideolojiler: ['merkez_sag'], onay: 4, gerekli: 6, kurucu_kurulu: 7, harc: 509882, fon: 1019800,
    kurucu_katki: 400000, toplanan: 700000, davetler: [
      { kad: 'TuranRiver', durum: 'evet', katki: 0, engel: null }, { kad: 'Abdullah', durum: 'evet', katki: 300000, engel: null },
      { kad: 'Kuzey', durum: 'evet', katki: 0, engel: null }, { kad: 'Hakim', durum: 'evet', katki: 0, engel: 'Yüksek Mahkeme üyeleri parti kurucusu olamaz.' },
      { kad: 'Mehmet', durum: 'bekliyor', katki: 0, engel: null }, { kad: 'Ece', durum: 'hayir', katki: 0, engel: null }] },
  gelen: [{ id: 30, ad: 'Güney Rüzgârı Topluluğu', kisa: 'GRT', kurucu: 'Selin', ideolojiler: ['liberal'], bit: S(100), durum: 'bekliyor', gerekli: 6, onay: 2,
    engel: 'Son 30 gün içinde başka bir partinin kurucusu oldun; bu sürede yeniden kurucu üye olunamaz.' }],
  onayladiklarim: [{ id: 31, ad: 'Ege Işığı Topluluğu', kisa: 'EIT', kurucu: 'Arda', bit: S(150), katki: 50000, fon: 1019800, gerekli: 6, onay: 5, toplanan: 350000 }]
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
    await page.waitForFunction(() => window.SO_FIYAT_TARIFESI_V1 && typeof iskelet === 'function' && typeof kurucuDavetModal === 'function');
    await page.waitForTimeout(600);
    await page.evaluate(({ TARIFE, DAVET }) => {
      window.calls = [];
      const sahte = (ad) => {
        switch (ad) {
          case 'fiyat_tarifesi': return TARIFE;
          case 'kurucu_davetlerim': return DAVET;
          case 'vatandaslik': return { uygun: true, sartlar: [], parti_kurma: { kurucu: 7, harc: 509882, fon: 1019800, ucret: 1529682, para: 208977, statu: 'Saygın Vatandaş', ortak_statu: 'Vatandaş', ortak_hesap_gun: 7,
            engel: 'Parti kurma başvurusu için en az "Saygın Vatandaş" statüsü (30 kıdem) gerekiyor; kıdemin 12.' } };
          case 'kurucu_katki': return { katki: 100000, toplanan: 800000, fon: 1019800, kalan: 219800 };
          case 'kurucu_davet_yanit': return { kabul: false, onay: 3, gerekli: 6 };
          default: return {};
        }
      };
      API = { rpc: async (ad, args) => { calls.push({ ad, args }); return JSON.parse(JSON.stringify(sahte(ad, args || {}))); } };
      if (window.YUK) try { YUK.temizle && YUK.temizle(); } catch (_) {}
      D.durum = D.durum || {}; D.durum.profil = Object.assign({ id: 'u1', il_id: 6, kad: 'Deniz', parti: null, makamlar: [] }, D.durum.profil || {}, { kad: 'Deniz' });
      window.onayla = async () => true;
    }, { TARIFE, DAVET });
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

    // 1) Fiyat Tarifesi
    await page.evaluate(() => ekranAc(fiyatTarifesiEkrani)); await bekle(500);
    let t = await metin();
    assert.match(t, /Fiyat Tarifesi/); assert.match(t, /Statü merdiveni/); assert.match(t, /Yaşayan Efsane/);
    assert.match(t, /Banka/); assert.match(t, /15 mn ₺/); assert.match(t, /Kurucular kurulu/); assert.match(t, /en az 7 kişi/);
    assert.match(t, /Küçük işletme/); assert.match(t, /200 bin ₺/); assert.match(t, /Saygın Vatandaş/);
    assert.ok(!await tasma(), genislik + ' px: yatay taşma olmamalı (tarife)');
    await yaz('01_fiyat_tarifesi');

    // 2) Parti kur ekranı: dinamik kurucu sayısı ve engel
    await page.evaluate(() => ekranAc(partiKurEkrani)); await bekle(500);
    t = await metin();
    assert.match(t, /en az 6/); assert.match(t, /509\.882 ₺ harç/); assert.match(t, /Saygın Vatandaş/);
    assert.ok(await page.evaluate(() => document.getElementById('kur').disabled), 'engel varken kur düğmesi kapalı olmalı');
    await yaz('02_parti_kur');

    // 3) Kurucular kurulu penceresi
    await page.evaluate(() => kurucuDavetModal()); await bekle(500);
    t = await modalMetin();
    assert.match(t, /Kurucu onayı: 4\/6/); assert.match(t, /700\.000 ₺ \/ 1\.019\.800 ₺/); assert.match(t, /Sayılmaz: Yüksek Mahkeme/);
    assert.match(t, /2 onay daha gerekli/); assert.match(t, /Onayımı geri çek/); assert.match(t, /Şu an kurucu üye olamazsın/);
    assert.ok(await page.evaluate(() => document.querySelector('#kurucularTamamla').disabled), 'onay eksikken kurma düğmesi kapalı');
    assert.ok(await page.evaluate(() => document.querySelector('button[data-davet="30"][data-yanit="evet"]').disabled), 'engelli davette Kabul kapalı');
    await yaz('03_kurucu_modal');
    await page.fill('#kurucuKatkiBen', '100000');
    await page.click('button[data-katki="kurucuKatkiBen"]'); await bekle(400);
    let c = await page.evaluate(() => calls.filter(x => x.ad === 'kurucu_katki').pop());
    assert.deepEqual(c.args, { p_basvuru: 24, p_tutar: 100000 });
    await page.evaluate(() => kurucuDavetModal()); await bekle(400);
    await page.click('button[data-davet="31"][data-geri="1"]'); await bekle(400);
    c = await page.evaluate(() => calls.filter(x => x.ad === 'kurucu_davet_yanit').pop());
    assert.deepEqual(c.args, { p_basvuru: 31, p_kabul: false });
    await page.evaluate(() => { try { modalKapat(); } catch (_) {} });
    await page.close();
  }
  await browser.close();
  const ilgili = hatalar.filter(h => /fiyat|kurucu|tarife/i.test(h));
  assert.equal(ilgili.length, 0, 'Sayfa hataları: ' + ilgili.join(' | '));
  console.log('TAMAM (fiyat tarifesi, parti kur, kurucular kurulu; 390 ve 320 px)' + (hatalar.length ? ' · ilgisiz sayfa hatası: ' + hatalar.length : ''));
})().catch(e => { console.error(e); process.exit(1); });
