// Kesintisiz ekran testi (31.10.2026): otomatik tazeleme yazılanı silmez, sayfayı en üste atmaz. Ağ yok.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/kesintisiz_ekran_arayuz.js
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
  const hatalar = []; page.on('pageerror', e => hatalar.push(e.message));
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (u.hostname !== 'oyun.test') return r.abort();
    const ad = decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname);
    let f = path.join(KOK, ad); if (!fs.existsSync(f)) f = path.join(YEDEK, ad);
    if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
    r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : 'text/html' });
  });
  await page.goto('http://oyun.test/index.html');
  await page.waitForFunction(() => window.SO_KESINTISIZ_V1 && typeof iskelet === 'function' && iskelet._ks);
  await page.waitForTimeout(800);
  const govde = (isaret) => '<div class="kart" id="isaret">' + isaret + '</div><div class="kart akis-kart"><textarea id="gAkisMetin"></textarea></div>' + '<div class="kart" style="height:900px">uzun</div>'.repeat(4);
  const ciz = (isaret) => page.evaluate((h) => { yukleniyor('Gündem'); iskelet('Gündem', h); }, govde(isaret));
  const otoYap = () => page.evaluate(() => { SO_KESINTISIZ.eylem = 0; SO_KESINTISIZ.dokunus = 0; SO_KESINTISIZ.oto = Date.now(); });
  const isaret = () => page.evaluate(() => (document.getElementById('isaret') || {}).textContent || '');

  await page.evaluate(() => { D.sekme = 'gundem'; D.yigin = []; D._ekranNo = 1; });
  await page.evaluate((h) => { iskelet('Gündem', h); }, govde('ilk'));

  // 1) Kürsü kutusuna yazı yazılırken otomatik tazeleme: yazı ve ekran yerinde kalır
  await page.evaluate(() => { const t = document.getElementById('gAkisMetin'); t.focus(); t.value = 'Yarım kalmış gönderi'; });
  await otoYap(); await ciz('ikinci');
  assert.equal(await isaret(), 'ilk', 'yazarken ekran yeniden çizilmemeli');
  assert.equal(await page.evaluate(() => document.getElementById('gAkisMetin').value), 'Yarım kalmış gönderi');

  // 2) Odak dışında ama gönderilmemiş taslak varken de çizilmez
  await page.evaluate(() => document.getElementById('gAkisMetin').blur());
  await otoYap(); await ciz('ucuncu');
  assert.equal(await isaret(), 'ilk', 'taslak varken ekran yeniden çizilmemeli');

  // 3) Taslak yokken otomatik tazeleme: içerik yenilenir, kaydırma korunur, "Yükleniyor" görünmez
  await page.evaluate(() => { document.getElementById('gAkisMetin').value = ''; document.getElementById('icerik').scrollTop = 1500; });
  await page.waitForTimeout(200); await otoYap();
  await page.evaluate(() => yukleniyor('Gündem'));
  assert.equal(await page.evaluate(() => !!document.querySelector('#icerik .yukleniyor')), false, 'otomatik tazelemede sayfa "Yükleniyor" ile silinmemeli');
  await page.evaluate((h) => iskelet('Gündem', h), govde('dorduncu'));
  assert.equal(await isaret(), 'dorduncu');
  const k = await page.evaluate(() => document.getElementById('icerik').scrollTop);
  assert.ok(k > 1000, 'kaydırma korunmalı, şu an: ' + k);

  // 4) Kaydırırken (son 4 sn) otomatik tazeleme yapılmaz
  await otoYap(); await page.evaluate(() => { SO_KESINTISIZ.dokunus = Date.now(); });
  await ciz('besinci');
  assert.equal(await isaret(), 'dorduncu', 'kaydırma sırasında çizilmemeli');

  // 5) Pencere (Kürsü yazma penceresi) açıkken sunucu sinyaliyle yeniden çizim yapılmaz
  await otoYap();
  await page.evaluate(() => { const w = document.createElement('div'); w.id = 'krYaz'; w.className = 'kr-yaz-arka'; document.body.appendChild(w); });
  await page.evaluate(() => { window._cizildi = 0; const e = EKRAN.gundem; EKRAN.gundem = () => { window._cizildi++; }; yenidenCiz(); EKRAN.gundem = e; });
  assert.equal(await page.evaluate(() => window._cizildi), 0, 'Kürsü penceresi açıkken yenidenCiz atlanmalı');
  await page.evaluate(() => document.getElementById('krYaz').remove());

  // 6) Oyuncunun kendi dokunuşuyla başlayan çizim her zaman yapılır (Yükleniyor dahil)
  await page.evaluate(() => { SO_KESINTISIZ.eylem = Date.now(); SO_KESINTISIZ.dokunus = 0; document.getElementById('gAkisMetin').value = 'taslak'; });
  await page.evaluate(() => yukleniyor('Gündem'));
  assert.equal(await page.evaluate(() => !!document.querySelector('#icerik .yukleniyor')), true, 'kullanıcı eyleminde yükleniyor gösterilir');
  await page.evaluate((h) => iskelet('Gündem', h), govde('altinci'));
  assert.equal(await isaret(), 'altinci');

  // 7) Uygulamaya dönüş otomatik sayılır
  await page.evaluate(() => { SO_KESINTISIZ.eylem = Date.now() - 50; document.dispatchEvent(new Event('visibilitychange')); });
  assert.equal(await page.evaluate(() => SO_KESINTISIZ.oto >= SO_KESINTISIZ.eylem && SO_OTOMATIK()), true, 'uygulamaya dönüş otomatik tetik sayılmalı');

  await browser.close();
  const ilgili = hatalar.filter(h => /kesintisiz|iskelet|SO_/i.test(h));
  assert.equal(ilgili.length, 0, 'Sayfa hataları: ' + ilgili.join(' | '));
  console.log('TAMAM (kesintisiz ekran: yazarken/taslakta/kaydırırken/pencere açıkken tazeleme yok; kaydırma korunuyor; kullanıcı eylemi her zaman çiziliyor)');
})().catch(e => { console.error(e); process.exit(1); });
