// Ekonomi 3.0 arayüzü: piyasa panosu, şirket karnesi, kararlar, genel kurul. Ağ yok; sahte RPC.
// Yayındaki docs/index.html + docs/*.js + gelistirici/www/ekonomi3.js birlikte yüklenir.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/ekonomi3_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const kok = path.join(__dirname, '../..');
let html = fs.readFileSync(path.join(kok, 'docs/index.html'), 'utf8');
html = html.replace(/<script src="https:[^"]+"><\/script>/g, '');
html = html.replace(/<script src="([^":]+?)(\?[^"]*)?"><\/script>/g, (m, dosya) => {
  const p = path.join(kok, 'docs', dosya);
  return fs.existsSync(p) ? '<script>' + fs.readFileSync(p, 'utf8') + '</script>' : '';
});
html = html.replace('</body>', () => '<script>' + fs.readFileSync(path.join(__dirname, '../www/ekonomi3.js'), 'utf8') + '</script></body>');
const shot = process.argv[2];

const FX = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/ekonomi3_ornek.json'), 'utf8'));

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    for (const w of [320, 390, 768]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: w < 700, locale: 'tr-TR' });
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      await page.route('**/*', r => r.abort());
      await page.setContent(html, { waitUntil: 'domcontentloaded' });
      await page.evaluate((FX) => {
        window.calls = [];
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'piyasa_panosu') return FX.pano;
          if (ad === 'sirket_karnesi') return FX.karne;
          if (ad === 'pazar_ayarla' || ad === 'sirket_reklam_ayarla') return FX.karne.tahmin;
          if (ad === 'genel_kurul_ac') return { id: 5, durum: 'acik' };
          if (ad === 'genel_kurul_oy') return { durum: 'acik' };
          if (ad === 'sirket_as_donustur') return { tamam: true, harc: 2500 };
          if (ad === 'sirket_liste') return { sirketler: [{ id: 10, ad: 'İstanbul Enerji Santrali', sektor: 'enerji', kasa: 504821, sermaye: 500000, pay: 100, sonraki_kazanc: new Date().toISOString(), dagitilabilir_kar: 0 }], pazar: [], teklifler: [], asgari: 30000 };
          return {};
        } };
        D.durum = { simdi: new Date().toISOString(), profil: { il_id: 34, kad: 'ArvenTora', parti: null, makamlar: [], cuzdan: { para: 1250000 } } };
      }, FX);
      const sec = (s) => page.locator(s);
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`), fullPage: true }); };
      const son = async (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);

      // Ekonomi sekmesi: üstte piyasa kartı
      await page.evaluate(() => sekmeAc('ekonomi'));
      await page.waitForSelector('.e3-giris');
      await page.waitForFunction(() => (document.querySelector('#e3GirisDeger') || {}).textContent !== '…');
      assert.match(await sec('.e3-giris').textContent(), /Şirketler Endeksi/);
      await tasmaYok('ekonomi'); await foto('e3_ekonomi');

      // Piyasa panosu
      await sec('.e3-giris').click();
      await page.waitForSelector('.e3-buyuk');
      let t = await sec('#icerik').textContent();
      assert.match(t, /Türkiye'nin en değerli şirketleri/); assert.match(t, /Bölgesel teşvik/); assert.match(t, /Şirketler arası ticaret/);
      assert.match(t, /Bankacılık/, 'banka sektör adı');
      assert.ok(await sec('.e3-sira').count() >= 10);
      await tasmaYok('pano'); await foto('e3_pano');

      // Şirket karnesi
      await page.evaluate(() => sirketKarnesiAc(10));
      await page.waitForSelector('.e3-sec');
      t = await sec('#icerik').textContent();
      assert.match(t, /Bu haftanın tahmini/); assert.match(t, /Kararların/); assert.match(t, /Genel kurul/); assert.match(t, /Hukuki yapı/);
      assert.match(t, /UYGAR HOLDING/, 'müşteri listesi');
      await tasmaYok('karne'); await foto('e3_karne');

      // Fiyat ve reklam kararı
      await page.click('.e3-sec.uc button:has-text("Normal")');
      await page.waitForTimeout(150);
      assert.deepEqual((await son('pazar_ayarla')).args, { p_sirket: 10, p_fiyat: 2, p_kalite: 1, p_kaynak: null });
      await page.click('.e3-sec button:has-text("Orta")');
      await page.waitForTimeout(150);
      assert.deepEqual((await son('sirket_reklam_ayarla')).args, { p_sirket: 10, p_seviye: 2 });

      // Genel kurul oyu ve önerge
      await page.click('.e3-kurul button:has-text("Hayır")');
      await page.waitForTimeout(150);
      assert.deepEqual((await son('genel_kurul_oy')).args, { p_kurul: 3, p_oy: false });
      await page.click('button:has-text("Önerge ver")');
      await page.waitForSelector('#e3Tur');
      await sec('#e3Deger').fill('25000');
      await foto('e3_onerge');
      await page.click('#e3Gonder'); await page.waitForTimeout(150);
      assert.deepEqual((await son('genel_kurul_ac')).args, { p_sirket: 10, p_tur: 'temettu', p_veri: { tutar: 25000 } });

      // A.Ş. dönüşümü
      await page.click('button:has-text("Anonim şirkete dönüştür")');
      await page.waitForSelector('#evet'); await page.click('#evet'); await page.waitForTimeout(150);
      assert.deepEqual((await son('sirket_as_donustur')).args, { p_sirket: 10 });

      // Şirketlerim ekranında karne girişi
      await page.evaluate(() => ekranAc(sirketYonetimEkrani));
      await page.waitForSelector('.so-firma .e3-karne-btn');
      await foto('e3_portfoy');
      await page.click('.so-firma .e3-karne-btn');
      await page.waitForSelector('.e3-sec');
      // Eski Şirketlerim ekranı da karne girişi ve günlük ifade alır
      await page.evaluate(() => ekranAc(sirketEskiYonetimEkrani));
      await page.waitForSelector('button[onclick^="aliciBagisModal"]');
      await page.waitForSelector('.e3-karne-btn');
      assert.match(await sec('#icerik').textContent(), /Sonraki günlük hesap/);

      assert.deepEqual(errors, [], 'sayfa hatası: ' + errors.join(' | '));
      await page.close();
      console.log(`ekonomi3 arayüz ${w}px tamam`);
    }
  } finally { await browser.close(); }
})().catch(err => { console.error(err); process.exit(1); });
