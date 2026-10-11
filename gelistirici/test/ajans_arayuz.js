// Reklam ve anket ajansı ekranları + Gündem sponsorlu kart/anket. Ağ yok; yerel veritabanından alınmış gerçek RPC çıktıları.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/ajans_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
for (const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
const FX = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/ajans_ornek.json'), 'utf8'));
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
        window.calls = []; window.FX = FX; window.kim = 'liste_gb';
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'ajans_liste') return FX[window.kim];
          if (ad === 'ajans_yonetim' || ad === 'ajans_ayarla') return FX.yonetim;
          if (ad === 'ajans_gundem') return FX.gundem;
          if (ad === 'ajans_anket_cevap') return { tamam: true, odul: 800 };
          if (['ajans_siparis', 'ajans_anket_yayimla', 'ajans_puanla'].includes(ad)) return { tamam: true };
          if (ad === 'ajans_kur') return { id: FX.yonetim.id };
          throw new Error('Beklenmeyen RPC: ' + ad);
        } };
        D.durum = { profil: { il_id: 35, kad: 'GenelBaskan', parti: null, makamlar: [], cuzdan: { para: 1000000 } } };
      }, FX);
      const sec = (s) => page.locator(s);
      const tik = async (s) => { await sec(s).first().click(); await page.waitForTimeout(80); };
      const onay = async () => { await page.waitForSelector('#evet'); await page.click('#evet'); await page.waitForTimeout(120); };
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`) }); };

      // ajans listesi ve sipariş (genel başkan)
      await page.evaluate(() => ekranAc(ajansMerkezEkrani)); await page.waitForSelector('.pz-grid');
      let t = await sec('#icerik').textContent();
      assert.match(t, /Kampanyanı gerçek oyunculara ulaştır/); assert.match(t, /Siparişlerim/); assert.match(t, /Ege Medya Ajans/);
      await tasmaYok('ajans'); await foto('ajans_merkez');
      await tik('button[onclick^="ajansSiparisModal"][onclick$="\'reklam\')"]');
      assert.match(await sec('#ajKaynak').textContent(), /parti kasası/);
      await page.fill('#ajMetin', 'Pazar günü Gündoğdu mitingimize bekliyoruz!'); await page.dispatchEvent('#ajMetin', 'input');
      assert.match(await sec('#ajOnizle').textContent(), /Gündoğdu/);
      await foto('ajans_reklam_modal');
      await tik('#ajSiparisBtn'); await page.waitForTimeout(150);
      let c = await page.evaluate(() => calls.find(x => x.ad === 'ajans_siparis'));
      assert.equal(c.args.p_tur, 'reklam'); assert.equal(c.args.p_kaynak, 'parti'); assert.equal(c.args.p_il, 35);
      await page.waitForSelector('.pz-grid');
      await tik('button[onclick^="ajansSiparisModal"][onclick$="\'anket\')"]'); await page.selectOption('#ajKaynak', 'kisi'); await tik('#ajSiparisBtn'); await page.waitForTimeout(150);
      c = await page.evaluate(() => calls.filter(x => x.ad === 'ajans_siparis').pop()); assert.equal(c.args.p_tur, 'anket'); assert.equal(c.args.p_kaynak, 'kisi'); assert.equal(c.args.p_metin, null);
      // sonuç, yayımla, puanla
      await page.waitForSelector('.pz-grid');
      if (await sec('.aj-cubuk').count()) {
        assert.match(await sec('#icerik').textContent(), /hata payı/);
        if (await sec('button[onclick^="ajansYayimla"]').count()) { await tik('button[onclick^="ajansYayimla"]'); await onay(); }
      }
      if (await sec('.aj-yildiz button').count()) { await tik('.aj-yildiz button:nth-child(4)'); c = await page.evaluate(() => calls.find(x => x.ad === 'ajans_puanla')); assert.equal(c.args.p_puan, 4); }
      // il değiştir
      await page.waitForSelector('.alan select');
      await page.selectOption('.alan select', ''); await page.waitForTimeout(150);
      c = await page.evaluate(() => calls.filter(x => x.ad === 'ajans_liste').pop()); assert.equal(c.args.p_il, null);

      // ajans sahibi: yönetim
      await page.evaluate(() => { window.kim = 'liste_sahip'; ekranAc(() => ajansYonetimEkrani(FX.yonetim.id)); }); await page.waitForSelector('#ajKaydet');
      t = await sec('#icerik').textContent(); assert.match(t, /Bu hafta/); assert.match(t, /Fiyat listen/); assert.match(t, /Gelen işler/);
      assert.ok(await sec('#ajKaydet').isDisabled());
      await tik('#ajF button[data-v="3"]'); assert.ok(!(await sec('#ajKaydet').isDisabled()));
      await tasmaYok('yonetim'); await foto('ajans_yonetim');
      await tik('#ajKaydet'); c = await page.evaluate(() => calls.find(x => x.ad === 'ajans_ayarla')); assert.equal(c.args.p_fiyat, 3);

      // Gündem kartları (doğrudan HTML üreticisi)
      await page.evaluate(() => iskelet('Gündem', '<div id="g"></div>', {}));
      await page.evaluate(() => { D.sekme = 'gundem'; $('#icerik').insertAdjacentHTML('afterbegin', ajansGundemHtml(FX.gundem)); });
      t = await sec('#icerik').textContent(); assert.match(t, /Sponsorlu/); assert.match(t, /Bugün seçim olsa/); assert.match(t, /Kararsızım/);
      await tasmaYok('gundem'); await foto('ajans_gundem');
      await tik('#ajAnket .secenek button'); await page.waitForTimeout(120);
      assert.equal(await sec('#ajAnket').count(), 0);
      assert.match(await sec('.toast').textContent(), /800/);
      // XSS: reklam metni düz yazı
      const kotu = await page.evaluate(() => ajansGundemHtml({ reklam: { metin: '<img src=x onerror=window.xss=1>', kim: '<b>x</b>', ajans: 'A' } }));
      assert.ok(!kotu.includes('<img') && !kotu.includes('<b>x'));

      // giriş noktaları
      await page.evaluate(() => iskelet('Hayat', '<div class="vit-ana-izgara"></div>', {}));
      assert.equal(await sec('.vit-ana-izgara .aj-ek2').count(), 1);
      await page.evaluate(() => iskelet('Ekonomi merkezi', '<div class="br-git"></div>', {}));
      assert.equal(await sec('.br-git .aj-git').count(), 1);
      assert.equal(await page.evaluate(() => vitSektor.ajans), 'Reklam ve Anket Ajansı');

      assert.deepEqual(errors, [], `${w}px sayfa hataları`);
      await page.close();
      console.log(`  ✓ ${w}px: ajans listesi, reklam/anket siparişi, sonuç-yayımla-puanla, il seçimi, ajans yönetimi, Gündem sponsorlu kart ve anket, XSS, giriş noktaları`);
    }
    console.log('ajans_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
