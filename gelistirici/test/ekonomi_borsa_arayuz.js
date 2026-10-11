// Ekonomi merkezi, borsa, Rekabet Kurumu, siyasi bağışlar, danışman/otopilot ekranları. Ağ yok; yerel veritabanından alınmış gerçek RPC çıktıları.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/ekonomi_borsa_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
for (const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
const FX = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/ekonomi_borsa_ornek.json'), 'utf8'));
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
        window.DN = Object.assign({}, FX.danisman, { oneri: Object.assign({}, FX.danisman.oneri, { fiyat: 2, kalite: 1, net: 9999 }), oneri_farkli: true });
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          const t = { piyasa_raporu: FX.rapor, borsa_liste: FX.borsa, borsa_sirket: FX.bsirket, rekabet_ekrani: FX.rekabet, siyasi_bagislar: FX.bagis,
            pazar_detay: FX.detay, pazar_danisman: window.DN, pazar_katalog: FX.katalog, pazar_otopilot: Object.assign({}, window.DN, { otopilot: true }) }[ad];
          if (t) return t;
          if (['borsa_al', 'borsa_sat', 'borsa_iptal', 'rekabet_ac', 'sirket_parti_bagis'].includes(ad)) return { tamam: true };
          if (ad === 'pazar_ayarla') return FX.detay.tahmin;
          throw new Error('Beklenmeyen RPC: ' + ad);
        } };
        D.durum = { profil: { il_id: 1, kad: 'Burak', parti: null, makamlar: [], cuzdan: { para: 5000000 } } };
      }, FX);
      const sec = (s) => page.locator(s);
      const tik = async (s) => { await sec(s).first().click(); await page.waitForTimeout(80); };
      const onay = async () => { await page.waitForSelector('#evet'); await page.click('#evet'); await page.waitForTimeout(100); };
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`) }); };

      // ekonomi merkezi
      await page.evaluate(() => ekranAc(ekonomiMerkeziEkrani)); await page.waitForSelector('.br-izgara');
      let t = await sec('#icerik').textContent();
      assert.match(t, /Piyasa fiyat endeksi/); assert.match(t, /Sektör liderleri/); assert.match(t, /Market Zinciri/); assert.match(t, /Siyasi bağışlar/);
      assert.equal(await sec('.br-git button').count(), 6);
      await tasmaYok('merkez'); await foto('ekonomi_merkezi');

      // borsa listesi ve şirket
      await page.evaluate(() => ekranAc(borsaEkrani)); await page.waitForSelector('.vit-banka');
      assert.match(await sec('#icerik').textContent(), /Ayse Market/);
      await tasmaYok('borsa'); await foto('borsa');
      await page.evaluate(() => ekranAc(() => borsaSirketEkrani(FX.bsirket.id))); await page.waitForSelector('.pz-net');
      t = await sec('#icerik').textContent(); assert.match(t, /Satış emirleri/); assert.match(t, /Fiyat \/ kazanç/);
      assert.equal(await sec('.br-spark').count(), FX.bsirket.gunluk.length > 1 ? 1 : 0);
      await tasmaYok('borsa_sirket'); await foto('borsa_sirket');
      const al = FX.bsirket.emirler.find(x => !x.benim);
      if (al) {
        await tik(`button[onclick="borsaAlModal(${al.id})"]`);
        await page.fill('#brAlPay', '0.5'); await page.dispatchEvent('#brAlPay', 'input');
        assert.match(await sec('#brAlOzet').textContent(), /komisyon/);
        await tik('#brAlBtn'); await page.waitForTimeout(120);
        const c = await page.evaluate(() => calls.find(x => x.ad === 'borsa_al')); assert.equal(c.args.p_emir, al.id); assert.equal(c.args.p_pay, 0.5);
      }
      if (await sec('#brSatPay').count()) {
        await page.fill('#brSatPay', '1'); await page.fill('#brSatFiyat', '5000'); await tik('button[onclick="borsaSat()"]');
        const c = await page.evaluate(() => calls.find(x => x.ad === 'borsa_sat')); assert.equal(c.args.p_birim, 5000);
      }

      // rekabet kurumu
      await page.evaluate(() => ekranAc(rekabetEkrani)); await page.waitForSelector('#rkIl');
      t = await sec('#icerik').textContent(); assert.match(t, /Kartel/); assert.match(t, /Soruşturmalar/); assert.match(t, /İhlal|Temiz/);
      await tasmaYok('rekabet'); await foto('rekabet');
      await page.selectOption('#rkIl', '6'); await tik('button[onclick="rekabetAc()"]'); await onay();
      let c = await page.evaluate(() => calls.find(x => x.ad === 'rekabet_ac')); assert.equal(c.args.p_il, 6);

      // siyasi bağışlar
      await page.evaluate(() => ekranAc(siyasiBagisEkrani)); await page.waitForSelector('.pz-logo');
      t = await sec('#icerik').textContent(); assert.match(t, /Son 30 gün/); assert.match(t, /Tüm bağışlar/);
      await tasmaYok('bagis'); await foto('siyasi_bagis');
      if (await sec('#sbTutar').count()) {
        await page.fill('#sbTutar', '20000'); await tik('button[onclick="siyasiBagisYap()"]'); await onay();
        c = await page.evaluate(() => calls.find(x => x.ad === 'sirket_parti_bagis')); assert.equal(c.args.p_tutar, 20000);
      }

      // şirket yönetimi: danışman ve otopilot
      await page.evaluate(() => ekranAc(() => pazarDetayEkrani(FX.detay.id))); await page.waitForSelector('#pzKaydet');
      t = await sec('#icerik').textContent(); assert.match(t, /Yönetim/); assert.match(t, /Danışman önerisi/); assert.match(t, /Otopilot/);
      await tasmaYok('detay'); await foto('sirket_yonetim');
      await tik('button[onclick="pazarOneriUygula()"]'); await page.waitForTimeout(150);
      c = await page.evaluate(() => calls.find(x => x.ad === 'pazar_ayarla')); assert.equal(c.args.p_fiyat, 2); assert.equal(c.args.p_kalite, 1);
      await tik('button[onclick="pazarOtopilot(true)"]'); await page.waitForTimeout(150);
      c = await page.evaluate(() => calls.find(x => x.ad === 'pazar_otopilot')); assert.equal(c.args.p_acik, true);

      // giriş noktaları
      await page.evaluate(() => iskelet('Hayat', '<div class="vit-ana-izgara"></div>', {}));
      assert.equal(await sec('.vit-ana-izgara .br-ek').count(), 1);
      await page.evaluate(() => iskelet('Şirketler', '<div class="vit-dugme"></div>', {}));
      assert.equal(await sec('.vit-dugme .br-ek').count(), 1);
      await page.evaluate(() => ekranAc(pazarMerkezEkrani)); await page.waitForTimeout(150);
      assert.match(await sec('#icerik').textContent(), /Üç adımda şirket/);

      assert.deepEqual(errors, [], `${w}px sayfa hataları`);
      await page.close();
      console.log(`  ✓ ${w}px: ekonomi merkezi, borsa listesi/şirket/alım/satış, Rekabet Kurumu, siyasi bağış, danışman ve otopilot, giriş noktaları`);
    }
    console.log('ekonomi_borsa_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
