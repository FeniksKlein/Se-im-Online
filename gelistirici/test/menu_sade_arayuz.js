// Menü sadeleştirme: Ekonomi alt menüsü, sade Hayat, Yönetim'in Devlet içine taşınması. Ağ yok; sahte RPC.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules HTML_PATH=docs/index.html node gelistirici/test/menu_sade_arayuz.js [ekran_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
// docs/index.html dış .js dosyalarını yükler; testte aynı klasörden gömülür
const html = fs.readFileSync(htmlYol, 'utf8')
  .replace(/<script src="https:[^"]+"><\/script>/g, '')
  .replace(/<script src="([\w.-]+\.js)(?:\?[^"]*)?"><\/script>/g, (t, ad) => {
    const f = path.join(path.dirname(htmlYol), ad);
    return fs.existsSync(f) ? '<script>' + fs.readFileSync(f, 'utf8') + '</script>' : t;
  });
const shot = process.argv[2];
const HAYAT = {
  para: 25079, bugun_toplandi: true, il_ad: 'İzmir', banka: { vadesiz: 0, vadeli: 0 },
  kumbara: { dolu: false, birikmis: 120, saat: 3, kapasite: 16, dolma_an: new Date(Date.now() + 36e6).toISOString(), seri: 1, seri_bonus: 0, reklam_odul: 500, vekil_kesinti: 0,
    gunluk_destek: { devlet: 0, belediye: 0 }, saatlik: { net: 40, maas: 50, brut: 50, vergi: 5, kent: 2, gecim: 3, makam: 0 },
    asgari: 17002, statu_carpan: 1, il_carpan: 1, ucret_bonus: 0, vergi_oran: 15, kent_oran: 2, gecim_indirim: 0 },
  statu: { ad: 'Vatandaş', puan: 5, bu_esik: 0, sonraki_esik: 50, sonraki_ad: 'Tanınan' },
  reklam: { kalan: 5, hazir: null }, etkiler: [], hareketler: [], mulkler: [],
  ulke: { asgari: 17002, vergi: 15, destek: 0, enflasyon: 30, tasinma_destek: 0 }, fiyat: { endeks: 1, tasinma: 1000 }
};
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    for (const w of [320, 390]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: true, locale: 'tr-TR' });
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      await page.route('**/*', r => r.abort());
      await page.setContent(html);
      await page.evaluate((HAYAT) => {
        window.calls = [];
        window.PROFIL = { il_id: 35, kad: 'Ada', parti: { id: 3, ad: 'Örnek Parti', renk: '#123456' }, gb: false, gby: false, cuzdan: { para: 25079 },
          makamlar: [{ tur: 'bel', il_id: 35, il_ad: 'İzmir' }] };
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'durum') return { simdi: new Date().toISOString(), profil: PROFIL };
          if (ad === 'hayat') return HAYAT;
          if (ad === 'cimer') return { basvurularim: [], gelen: [], kurumlar: { bakanliklar: [], il_id: 35 }, bugun_kalan: 3 };
          if (ad === 'belediye_sehir_paneli') return { il_ad: 'İzmir', kasa: 1.2, memnuniyet: 55, gelisim: 61 };
          return null;
        } };
        D.durum = { profil: PROFIL };
      }, HAYAT);
      const menu = () => page.locator('nav.sekmeler button .pa-nl').allTextContents();
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`), fullPage: true }); };

      // 1) Hayat: Ekonomi sadece alt menüden açılır, içeride tekrar bağlantısı yok.
      await page.evaluate(() => sekmeAc('hayat')); await page.waitForSelector('#icerik .olay');
      assert.equal(await page.locator('#icerik .ms-giris').count(), 0, 'Hayat içinde Ekonomi kısayolu kalmamalı');
      const hayat = await page.locator('#icerik').textContent();
      for (const yok of ['İŞ DÜNYASI', 'Rekabetçi şirketler', 'Oyuncu bankaları', 'Halka arzlar', 'Diğer para işlemleri', 'Ekonomi merkezi'])
        assert.ok(!hayat.includes(yok), `Hayat'ta hâlâ "${yok}" var`);
      assert.match(hayat, /Maaş kumbarası/); assert.match(hayat, /Görevler/);
      await foto('hayat'); await tasmaYok('Hayat');

      // 2) Alt menü: Yönetim yok, Devlet ikinci, Ekonomi Hayat'tan sonra
      const m = await menu();
      // 5'li alt menü: ortadaki düğme açık olan ikincil bölümün adını taşır (Hayat), diğerleri Menü çekmecesinde
      assert.deepEqual(m, ['Gündem', 'Devlet', 'Hayat', 'Ekonomi', 'Sohbet']);

      // 3) Ekonomi sekmesi: hepsi tek ekranda, her giriş tek kez
      await page.locator('nav.sekmeler button').filter({ hasText: /^Ekonomi$/ }).click();
      await page.waitForSelector('.ms-grup');
      assert.equal(await page.locator('.ms-ust').count(), 0, 'Ekonomi üstünde tekrarlanan hızlı bağlantılar kalmamalı');
      assert.equal(await page.evaluate(() => D.sekme), 'ekonomi');
      assert.equal(await page.locator('nav.sekmeler button.aktif .pa-nl').first().textContent(), 'Ekonomi');
      const satirlar = await page.locator('#icerik .giris-satir b').allTextContents();
      for (const var_ of ['İş dünyası', 'Rekabetçi şirketler', 'Piyasa raporu', 'Borsa', 'Halka arzlar', 'Devlet bankası', 'Oyuncu bankaları', 'Satılık mülkler', 'Merkez Bankası', 'Kamu ihaleleri', 'Para gönder'])
        assert.ok(satirlar.includes(var_), `Ekonomi'de "${var_}" yok: ${satirlar.join(', ')}`);
      assert.equal(new Set(satirlar).size, satirlar.length, 'Ekonomi ekranında aynı satır iki kez var');
      await foto('ekonomi'); await tasmaYok('Ekonomi');
      // Alt ekrana gidip geri gelince Ekonomi'ye dönülür
      await page.evaluate(() => { window.borsaEkrani = () => iskelet('Borsa', '<div class="kart">b</div>', { geri: true }); });
      await page.evaluate(() => ekranAc(borsaEkrani)); await page.click('header .geri'); await page.waitForSelector('.ms-grup');

      // 4) Devlet: makam sahibi "Makamım" bölümüyle açılır
      await page.evaluate(() => { D._dvMakamIlk = false; D.devletSekme = null; sekmeAc('devlet'); }); await page.waitForSelector('.ynt-bolum');
      assert.equal(await page.locator('header.ust h1').textContent(), 'Devlet');
      assert.equal(await page.locator('#icerik .segment button.aktif').textContent(), 'Makamım');
      assert.match(await page.locator('#icerik').textContent(), /İzmir Belediyesi/);
      assert.equal(await page.locator('nav.sekmeler button.aktif .pa-nl').first().textContent(), 'Devlet');
      await foto('devlet_makam'); await tasmaYok('Devlet');
      // Eski bağlantılar (Yönetim / Belediyem) Devlet › Makamım'a gelir
      for (const k of ['yonetim', 'belediye', 'bakanlik']) {
        await page.evaluate((k) => { D.devletSekme = 'gazete'; sekmeAc(k); }, k); await page.waitForSelector('.ynt-bolum');
        assert.equal(await page.evaluate(() => D.sekme), 'devlet', k);
        assert.equal(await page.locator('header.ust h1').textContent(), 'Devlet', k);
      }

      // 5) Makamsız oyuncu: "Makamım" görünmez, Hükümet açılır
      await page.evaluate(() => { PROFIL.makamlar = []; D.durum = { profil: PROFIL }; D.devletSekme = 'yonetim'; sekmeAc('devlet'); });
      await page.waitForFunction(() => document.querySelector('header.ust h1') && document.querySelector('header.ust h1').textContent === 'Devlet' && document.querySelector('#icerik .segment'));
      const seg = await page.locator('#icerik .segment button').allTextContents();
      assert.ok(!seg.includes('Makamım'), seg.join(','));
      assert.equal(await page.evaluate(() => D.devletSekme), 'hukumet');

      const ilgili = errors.filter(x => /menu|ms-|ekonomiEkrani|yonetim|devlet/i.test(x));
      assert.deepEqual(ilgili, []);
      await page.close();
    }
    console.log('menu_sade_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
