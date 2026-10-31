// Meclis sandalye dağılımı, vekil listesi ve milletvekili öz geçmişi arayüz testi (31.10.2026). Ağ yok; sahte RPC.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/meclis_sandalye_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const P = (id, ad, kisa, renk, amblem) => ({ id, ad, kisa, renk, amblem });
const HP = P(1, 'Halk Partisi', 'HP', '#c62828', 'a_basak'), MDP = P(15, 'Milli Birlik ve Demokrasi Partisi', 'MDP', '#00897b', 'a_mesale'), IP = P(16, 'İstiklal Partisi', 'İP', '#ad1457', 'a_ucok');
const SANDALYE = { donem: 2, guncel: true, toplam: 600, dolu: 35, bos: 565, bagimsiz: 3, guncelleme: new Date().toISOString(),
  donemler: [{ no: 2, bas: '2026-10-23T21:00:00Z', bit: null }, { no: 1, bas: '2026-10-12T21:00:00Z', bit: '2026-10-23T21:00:00Z' }],
  partiler: [Object.assign({ n: 7 }, HP), Object.assign({ n: 5 }, MDP), Object.assign({ n: 5 }, IP)] };
const SANDALYE1 = Object.assign({}, SANDALYE, { donem: 1, guncel: false, bos: null, dolu: 33, partiler: [Object.assign({ n: 9 }, P(4, 'Yeni Parti', 'YENİ', '#2e7d32', 'a_cinar'))] });
const VEKILLER = [
  { kad: 'Dobliy', il: 'Kütahya', parti: HP, aktif: true, gorevler: ['Çalışma ve Sosyal Güvenlik Bakanlığı', 'Genel Başkan Yardımcısı'] },
  { kad: 'halilmutlu', il: 'Tunceli', parti: HP, aktif: true, gorevler: ['Genel Başkan', 'Grup Başkanı', 'Adalet Bakanlığı'] },
  { kad: 'TuranRiver', il: 'Malatya', parti: HP, aktif: true, gorevler: [], secildigi: MDP }];
const TUM = [{ kad: 'AbdullahGencer', il: 'Konya', parti: P(18, 'İttihat ve Terakkî Fırkası', 'İTF', '#c62828', 'a_ayyildiz'), aktif: true, donemler: [0, 1, 2], gorevler: [] },
  { kad: 'Eyetkin', il: 'İzmir', parti: null, aktif: false, donemler: [0, 1, 2], gorevler: [] }];
const OZ = { kad: 'halilmutlu', ben: false, il: 'Tunceli', parti: HP, katilim: '2026-10-10T17:01:44Z', kidem: 50.98, aktif: 'bugun',
  biyografi: 'Sosyal demokrasiye gönül vermiş bir insan hakları savunucusu.',
  mv: { il: 'Tunceli', bas: '2026-10-30T14:16:55Z', donem: 2, nasil: 'Sıradaki aday olarak', secildigi: HP },
  gorevler: ['Genel Başkan', 'Grup Başkanı', 'Adalet Bakanlığı'],
  donemler: [{ no: 2, il: 'Tunceli', parti: HP, bas: '2026-10-30T14:16:55Z', bit: null }, { no: 2, il: 'Tunceli', parti: HP, bas: '2026-10-23T21:00:00Z', bit: '2026-10-30T13:56:17Z' },
    { no: 1, il: 'Tunceli', parti: HP, bas: '2026-10-12T21:00:00Z', bit: '2026-10-23T21:00:00Z' }, { no: 0, il: 'Tunceli', parti: HP, bas: '2026-10-10T17:42:15Z', bit: '2026-10-12T21:00:00Z' }],
  gecmis: [{ makam: 'Adalet Bakanlığı', bas: '2026-10-30T16:23:59Z', bit: null }],
  meclis: { teklif: 1, yasalasan: 0, teklifler: [{ no: null, baslik: 'Af Yetkisinin Tarafsızlığı Hakkında Kanun Teklifi', durum: 'ret' }], oy: 27, oylanabilir: 47, yoklama: 0, soru: 0, gensoru: 0 },
  kursu: { bio: null, takipci: 3, takip: 4, gonderi: 92, son: [{ id: 1, metin: 'Adalet Bakanlığı olarak yarın heyeti ziyarete gideceğiz.', zaman: '2026-10-30T20:40:21Z', begeni: 3, yanit: 1 }] },
  rozetler: [{ ad: 'Bakan', sira: '02', aciklama: 'Kabinede görev aldı' }, { ad: 'Milletvekili', sira: '04', aciklama: "Meclis'e girdi" }] };
const REHBER = { toplam: 600, dolu: 35, bagimsiz: 3, cogunluk: 18, grup_esigi: 4, baskan: null, gecici: null, baskanvekilleri: [],
  partiler: [Object.assign({ n: 7, grup: true, sira: 1 }, HP), Object.assign({ n: 5, grup: true, sira: 2 }, MDP)], sozluk: {}, iller: [] };

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
    await page.waitForFunction(() => window.SO_MECLIS_SANDALYE_V1 && typeof iskelet === 'function' && typeof window.meclisSandalyeEkrani === 'function');
    await page.waitForTimeout(600);
    await page.evaluate((V) => {
      window.calls = [];
      const sahte = (ad, a) => ad === 'meclis_sandalye' ? (a.p_donem === 1 ? V.SANDALYE1 : V.SANDALYE)
        : ad === 'meclis_vekiller' ? (a.p_donem === 0 ? V.TUM : V.VEKILLER) : ad === 'milletvekili_ozgecmis' ? V.OZ : ad === 'kimlikler' ? {} : {};
      API = { rpc: async (ad, args) => { calls.push({ ad, args }); return JSON.parse(JSON.stringify(sahte(ad, args || {}))); } };
      if (window.YUK) try { YUK.temizle && YUK.temizle(); } catch (_) {}
      D.durum = D.durum || {}; D.durum.profil = Object.assign({ id: 'u1', il_id: 6, kad: 'Deniz', parti: null, makamlar: [] }, D.durum.profil || {}, { kad: 'Deniz' });
    }, { SANDALYE, SANDALYE1, VEKILLER, TUM, OZ });
    const bekle = (ms = 400) => page.waitForTimeout(ms);
    const yaz = async (ad) => {
      if (!shot) return; fs.mkdirSync(shot, { recursive: true });
      await page.evaluate(() => { try { modalKapat(); } catch (_) {} }); await page.waitForTimeout(250);
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) { a.dataset.eski = a.style.cssText; a.style.position = 'static'; a.style.height = 'auto'; } document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = 'visible'; }); });
      await page.screenshot({ path: path.join(shot, genislik + '_' + ad + '.png'), fullPage: true });
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) a.style.cssText = a.dataset.eski || ''; document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = ''; }); });
    };
    const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
    const tasma = () => page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
    const son = (ad) => page.evaluate((a) => calls.filter(x => x.ad === a).pop(), ad);

    // 1) Meclis › Sandalyeler sekmesindeki gömülü TBMM tablosu
    await page.evaluate((r) => { iskelet('Meclis', meclisGenelHtml(r)); }, REHBER); await bekle();
    let t = await metin();
    assert.match(t, /SANDALYE DAĞILIMI|sandalye dağılımı/i); assert.match(t, /HALK PARTİSİ/); assert.match(t, /BAĞIMSIZ MİLLETVEKİLİ/); assert.match(t, /BOŞ SANDALYE/); assert.match(t, /Toplam\s*600/);
    assert.ok(!/Partilerin sandalyeleri/.test(t), 'eski parti kartı yerini tabloya bırakmalı');
    assert.ok(!await tasma(), genislik + ' px: taşma (gömülü)'); await yaz('01_meclis_sekme');
    await page.click('.ms-satir >> nth=0'); await bekle(600);
    assert.deepEqual((await son('meclis_vekiller')).args, { p_donem: null, p_parti: 1, p_bagimsiz: false });

    // 2) Parti vekil listesi
    t = await metin();
    assert.match(t, /HALILMUTLU|HALİLMUTLU/); assert.match(t, /TUNCELİ MİLLETVEKİLİ/); assert.match(t, /ÖZ GEÇMİŞ/); assert.match(t, /Genel Başkan/);
    assert.ok(!await tasma(), genislik + ' px: taşma (liste)'); await yaz('02_parti_liste');
    await page.fill('.ms-ara', 'malatya'); await bekle(150);
    assert.equal(await page.evaluate(() => [...document.querySelectorAll('.ms-vekil')].filter(b => b.style.display !== 'none').length), 1);
    await page.fill('.ms-ara', ''); await bekle(100);

    // 3) Öz geçmiş
    await page.evaluate(() => document.querySelectorAll('.ms-vekil')[1].click()); await bekle(600);
    assert.deepEqual((await son('milletvekili_ozgecmis')).args, { p_kad: 'halilmutlu' });
    t = await metin();
    assert.match(t, /TUNCELİ MİLLETVEKİLİ/); assert.match(t, /Öz geçmiş/); assert.match(t, /insan hakları/); assert.match(t, /Yasama dönemleri/);
    assert.match(t, /2\. Dönem/); assert.match(t, /Kuruluş Meclisi/); assert.match(t, /%57 katılım/); assert.match(t, /Kürsü hesabı/); assert.match(t, /92/);
    assert.equal(await page.evaluate(() => document.querySelectorAll('.ms-donem').length), 3, 'aynı dönemdeki tekrar kayıtlar birleşmeli');
    assert.ok(!await tasma(), genislik + ' px: taşma (öz geçmiş)'); await yaz('03_ozgecmis');

    // 4) Sandalye ekranı, dönem seçimi, tüm dönem listesi
    await page.evaluate(() => ekranAc(meclisSandalyeEkrani)); await bekle(500);
    t = await metin(); assert.match(t, /2\. DÖNEM|2\. Dönem/i); assert.match(t, /Canlı/);
    assert.ok(!await tasma(), genislik + ' px: taşma (sandalye)'); await yaz('04_sandalye');
    await page.selectOption('#msDonem', '1'); await bekle(500);
    assert.equal((await son('meclis_sandalye')).args.p_donem, 1);
    t = await metin(); assert.match(t, /YENİ PARTİ/); assert.ok(!/BOŞ SANDALYE/.test(t), 'geçmiş dönemde boş sandalye satırı olmamalı');
    await page.evaluate(() => msListe(0)); await bekle(500);
    t = await metin(); assert.match(t, /Tüm dönem/i); assert.match(t, /eski vekil/); assert.match(t, /Kuruluş Meclisi, 1\. Dönem, 2\. Dönem/);
    await yaz('05_tum_donem');
    await page.close();
  }
  await browser.close();
  const ilgili = hatalar.filter(h => /meclis|sandalye|ozgecmis|ms[A-Z]/i.test(h));
  assert.equal(ilgili.length, 0, 'Sayfa hataları: ' + ilgili.join(' | '));
  console.log('TAMAM (sandalye tablosu, parti listesi, öz geçmiş, dönemler, tüm dönem; 390 ve 320 px)' + (hatalar.length ? ' · ilgisiz sayfa hatası: ' + hatalar.length : ''));
})().catch(e => { console.error(e); process.exit(1); });
