// Şeffaflık (parti kasa defteri, yönetim hediyeleri) ve MASAK paneli. Ağ yok; yerel veritabanından alınmış gerçek RPC çıktıları.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/guvenlik_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
for (const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
const FX = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/guvenlik_ornek.json'), 'utf8'));
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    for (const w of [320, 390, 768]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: w < 700, locale: 'tr-TR' });
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      await page.route('**/*', r => r.abort());
      await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
      await page.evaluate((FX) => {
        window.calls = []; window.FX = FX;
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'parti_kasa_defteri') return FX.defter;
          if (ad === 'partiler') return FX.partiler;
          if (ad === 'yonetim_hediyeleri') return FX.hediye;
          if (ad === 'admin_masak') return args.p_durum === 'el_koyuldu' ? FX.masak_el : FX.masak;
          if (ad === 'admin_masak_karar') return FX.masak;
          throw new Error('Beklenmeyen RPC: ' + ad);
        } };
        D.durum = { profil: { il_id: 35, kad: 'Diger', parti: null, makamlar: [], cuzdan: { para: 1 } } };
      }, FX);
      const sec = (s) => page.locator(s);
      const tik = async (s) => { await sec(s).first().click(); await page.waitForTimeout(100); };
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`) }); };

      await page.evaluate(() => { GV.sekme = 'parti'; GV.parti = null; ekranAc(seffaflikEkrani); }); await page.waitForSelector('.pz-grid');
      let t = await sec('#icerik').textContent(); assert.match(t, /Kasa defteri/); assert.match(t, /30 günde çıkan/);
      await tasmaYok('defter'); await foto('seffaflik_defter');
      await tik('.segment button:nth-child(2)'); await page.waitForTimeout(150);
      t = await sec('#icerik').textContent(); assert.match(t, /Yönetimin dağıttığı para/); assert.match(t, /el koyma/i);
      await foto('seffaflik_hediye');

      await page.evaluate(() => { GV.masakDurum = 'yeni'; ekranAc(masakEkrani); }); await page.waitForSelector('.segment');
      t = await sec('#icerik').textContent(); assert.match(t, /Şüpheli işlem incelemesi/);
      await tasmaYok('masak'); await foto('masak');
      if (await sec('button[onclick^="masakKarar"][onclick*="ihtar"]').count()) {
        await tik('button[onclick^="masakKarar"][onclick*="ihtar"]'); await page.fill('#gvNot', 'kısa'); await tik('#gvOnay');
        assert.match(await sec('.toast').textContent(), /10 karakter/);
        await page.fill('#gvNot', 'Karşılıklı al-sat yapmayın, uyarı.'); await tik('#gvOnay'); await page.waitForTimeout(150);
        const c = await page.evaluate(() => calls.find(x => x.ad === 'admin_masak_karar')); assert.equal(c.args.p_karar, 'ihtar');
      }
      await page.evaluate(() => { GV.masakDurum = 'el_koyuldu'; masakEkrani(); }); await page.waitForTimeout(150);
      assert.match(await sec('#icerik').textContent(), /El konuldu/);

      await page.evaluate(() => iskelet('Ekonomi merkezi', '<div class="br-git"></div>', {}));
      assert.equal(await sec('.br-git .gv-git').count(), 1);
      await page.evaluate(() => iskelet('Yönetici paneli', '<div></div>', {}));
      assert.equal(await sec('.gv-ek').count(), 1);
      assert.deepEqual(errors, [], `${w}px sayfa hataları`);
      await page.close();
      console.log(`  ✓ ${w}px: parti kasa defteri, yönetim hediyeleri, MASAK listesi ve karar, giriş noktaları`);
    }
    console.log('guvenlik_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
