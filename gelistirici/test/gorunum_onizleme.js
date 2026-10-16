// Görünüm önizlemesi: ana ekranların ekran görüntüleri (sahte RPC, ağ yok).
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules HTML_PATH=docs/index.html node gelistirici/test/gorunum_onizleme.js <klasör> [genişlik]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
const html = fs.readFileSync(htmlYol, 'utf8')
  .replace(/<script src="https:[^"]+"><\/script>/g, '')
  .replace(/<script src="([\w.-]+\.js)(?:\?[^"]*)?"><\/script>/g, (t, ad) => {
    const f = path.join(path.dirname(htmlYol), ad);
    return fs.existsSync(f) ? '<script>' + fs.readFileSync(f, 'utf8') + '</script>' : t;
  });
const klasor = process.argv[2] || '.'; const W = +(process.argv[3] || 390);
const veri = require('./veri/gorunum_ornek.js');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: W, height: 844 }, isMobile: true, deviceScaleFactor: 2, locale: 'tr-TR' });
  const hatalar = []; page.on('pageerror', e => hatalar.push(e.message));
  await page.route('**/*', r => r.abort());
  await page.setContent(html);
  await page.waitForTimeout(400);
  for (const [ad, fn] of [['karsila', 'karsilama'], ['giris', 'girisEkrani'], ['kayit', 'kayitEkrani']]) {
    await page.evaluate((fn) => { if (typeof window[fn] === 'function') window[fn](); }, fn);
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(klasor, `00_${ad}_${W}.png`) });
  }
  await page.evaluate((v) => {
    window.PROFIL = v.profil;
    API = { rpc: async (ad) => (ad === 'durum' ? { simdi: new Date().toISOString(), profil: PROFIL, ...v.durum } : (v.rpc[ad] ?? null)) };
    D.durum = { profil: PROFIL, ...v.durum };
  }, veri);
  const ekranlar = (process.env.EKRANLAR || 'gundem,devlet,adliye,hayat,ekonomi,sohbet,meclis,harita,partiler,dernekler').split(',');
  let i = 1;
  for (const s of ekranlar) {
    try {
      await page.evaluate((s) => sekmeAc(s), s);
      await page.waitForTimeout(700);
      await page.screenshot({ path: path.join(klasor, `${String(i).padStart(2, '0')}_${s}_${W}.png`), fullPage: !!process.env.TAM });
    } catch (e) { hatalar.push(s + ': ' + e.message); }
    i++;
  }
  console.log(hatalar.length ? 'Sayfa hataları:\n' + [...new Set(hatalar)].join('\n') : 'Sayfa hatası yok');
  await browser.close();
})();
