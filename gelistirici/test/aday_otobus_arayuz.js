// Aday mitingine otobüs penceresi arayüz testi (sahte RPC; 390 px) — 27.11.2026
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/aday_otobus_arayuz.js   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
  const hatalar = []; page.on('pageerror', e => hatalar.push(e.message));
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (u.hostname !== 'oyun.test') return r.abort();
    const f = path.join(KOK, u.pathname === '/' ? '/index.html' : decodeURIComponent(u.pathname));
    if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
    r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
  });
  await page.goto('http://oyun.test/index.html');
  await page.waitForFunction(() => typeof window.mitingOtobusAc === 'function' && typeof window.mtSahneHtml === 'function');
  const sonuc = await page.evaluate(async () => {
    const now = Date.now(), iso = ms => new Date(now + ms).toISOString();
    window.calls = [];
    const bilgi = odeme => ({ id: 5, tur: 'aday', parti_mitingi: true, yetkili: true, odeme, il: 'Mersin', il_id: 33, benim_ilim: 33,
      bas: iso(2 * 3600e3), bit: iso(3 * 3600e3), simdi: iso(0), kasa: 1500, otobusler: [{ kaynak: 'Adana', kaynak_il: 1, adet: 2, dolu: 3, koltuk: 80 }],
      iller: [{ id: 1, ad: 'Adana', ucret: 800 }, { id: 6, ad: 'Ankara', ucret: 2400 }] });
    let od = 'aday';
    API = { rpc: async (ad, a) => { calls.push(ad); if (ad === "miting_otobus_bilgi") return bilgi(od); return {}; } };
    const r = {};
    await mitingOtobusAc(5);
    const m = () => document.querySelector('.modal, #modal, [class*=modal]');
    const metin = () => document.body.innerText;
    r.adayBaslik = metin().includes('Kendi cüzdanından otobüs kaldır');
    r.adayDugme = document.querySelector('#moKaldir').textContent;
    r.cuzdan = metin().includes('Cüzdanın');
    document.querySelector('#moAdet').value = '2'; document.querySelector('#moAdet').dispatchEvent(new Event('change'));
    r.yetersiz = document.querySelector('#moFiyat').textContent.includes('Cüzdanında yeterli para yok') && document.querySelector('#moKaldir').disabled;
    if (typeof modalKapat === 'function') modalKapat();
    od = 'parti'; await mitingOtobusAc(5);
    r.partiDugme = document.querySelector('#moKaldir').textContent;
    if (typeof modalKapat === 'function') modalKapat();
    r.sahne = (mtSahneHtml({ id: 5, tur: 'aday', baslik: 'X', il: 'Mersin', kad: 'aday', unvan: 'CB adayı', parti: null, canli: true, bitti: false, cosku: 10, cosku_ad: 'Isınıyor', katilim: 3, katilabilir: false, katildim: false, son_katilanlar: [], konusmalar: [], tepkiler: [], sloganlar: [], bas: iso(-60e3), bit: iso(3600e3) }) || '').includes('mitingOtobusAc(5)');
    return r;
  });
  console.log(sonuc);
  assert.equal(sonuc.adayBaslik, true); assert.equal(sonuc.cuzdan, true); assert.equal(sonuc.yetersiz, true);
  assert.match(sonuc.adayDugme, /Cüzdanımdan öde/); assert.match(sonuc.partiDugme, /Parti kasasından öde/);
  assert.equal(sonuc.sahne, true);
  assert.deepEqual(hatalar, []);
  console.log('Aday otobüs arayüz testi: TAMAM');
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
