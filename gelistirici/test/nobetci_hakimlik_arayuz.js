// Nöbetçi hâkimlik: Gözaltı ve Avukat ekranına eklenen sevk / savunma / karar bölümleri ve hâkim şeridi.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/nobetci_hakimlik_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();
const ORTAK = { simdi: S(0), nobetci_hakim: 'Hâkim Ayşe', suc_turleri: ['hakaret', 'iftira', 'rusvet', 'yolsuzluk', 'usulsuzluk', 'dolandiricilik', 'diger'], kararlar: ['serbest', 'adli_kontrol', 'tutuklama'],
  sureler: { sorgu_saat: 3, tutukluluk_saat: 6, oncelik_dk: 60 }, dosyam: null, muvekkil_dosyalari: [], hakim_dosyalari: [], sevk_edilebilir: [], son_kararlar: [] };
const UZUN = 'Şüpheli 20 Kasım günü Kürsü’de Cumhurbaşkanlığı makamına yönelik hakaret içeren, çokuzunbirkelimeiletaşmayıdeneyenbirpaylaşımyapmıştır.';
const PANEL = {
  supheli: Object.assign({}, ORTAK, { hakim_mi: false, sevk_yetkisi: false,
    dosyam: { id: 4, durum: 'bekliyor', suc_tur: 'hakaret', iddia: UZUN, delil: 'Ekran görüntüsü', sevk_eden: 'Başkan', makam: 'cumhurbaskani', zaman: S(-0.5), son: S(2.5), nobetci: 'Hâkim Ayşe', savunma: null } }),
  hakim: Object.assign({}, ORTAK, { hakim_mi: true, sevk_yetkisi: false,
    hakim_dosyalari: [{ id: 4, hedef: 'Deniz', sevk_eden: 'Başkan', makam: 'cumhurbaskani', suc_tur: 'hakaret', iddia: UZUN, delil: '', gozalti_gerekce: 'Kamu düzeni', zaman: S(-0.5), son: S(2.5), nobetci: 'Hâkim Ayşe', nobetci_benim: true, savunma: 'Paylaşım eleştiri sınırları içindedir.', savunma_yazan: 'CELAL', bakabilir: true }],
    son_kararlar: [{ id: 3, hedef: 'Mehmet', makam: 'icisleri_bakani', suc_tur: 'iftira', durum: 'adli_kontrol', gerekce: 'x', karar_at: S(-5), dava_id: 12 }] }),
  yetkili: Object.assign({}, ORTAK, { hakim_mi: false, sevk_yetkisi: true,
    sevk_edilebilir: [{ kaynak: 'yonetim', id: 9, hedef: 'Zeynep', gerekce: 'Deneme gerekçesi', bitis: S(2), sevk: null }, { kaynak: 'yonetim', id: 10, hedef: 'Ali', gerekce: 'Deneme', bitis: S(1), sevk: { id: 5, durum: 'bekliyor', son: S(1) } }] }),
  tutuklu: Object.assign({}, ORTAK, { hakim_mi: false, sevk_yetkisi: false,
    dosyam: { id: 4, durum: 'tutuklama', suc_tur: 'hakaret', iddia: UZUN, delil: '', sevk_eden: 'Başkan', makam: 'cumhurbaskani', zaman: S(-2), son: S(1), nobetci: 'Hâkim Ayşe', hakim: 'Hâkim Ayşe', gerekce: 'Kuvvetli suç şüphesi.', karar_at: S(-1), tutukluluk_bitis: S(5), dava_id: 14 } }),
};
(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const [ad, veri] of Object.entries(PANEL)) {
    for (const gen of [390, 320]) {
      const page = await browser.newPage({ viewport: { width: gen, height: gen === 320 ? 640 : 844 }, isMobile: true, locale: 'tr-TR' });
      page.on('pageerror', e => hatalar.push(ad + ': ' + e.message.slice(0, 200)));
      page.on('dialog', d => d.accept());
      await page.route('**/*', r => {
        const u = new URL(r.request().url());
        if (u.hostname !== 'oyun.test') return r.abort();
        const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
        if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
        r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
      });
      await page.goto('http://oyun.test/index.html');
      await page.waitForFunction(() => window.SO_NOBETCI_V1 && window.SO_GOZALTI_V1 && typeof iskelet === 'function' && typeof gozaltiMerkeziEkrani === 'function');
      await page.evaluate((v) => {
        window.calls = []; window.V = v;
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'nobetci_panel') return V;
          if (ad === 'gozalti_durumum') return { simdi: new Date().toISOString(), gozalti: null, muvekkiller: [], avukat_mi: false, baro_baskani: false, tahliye_yetkisi: !!V.sevk_yetkisi };
          if (ad === 'ifade_cagrilari') return { benim: [], yetkili: false, dosyalar: [], ayar: {} };
          if (ad === 'gozalti_yetkili_liste') return { yetkili: !!V.sevk_yetkisi, kota: { kota: 3, kullanilan: 1, sure_saat: 3, ara_saat: 48 }, gozaltilar: [] };
          if (ad === 'yonetim_gozalti_kota') return { yetkili: !!V.sevk_yetkisi, kota: 3, kullanilan: 1, sure_saat: 3, ara_saat: 48 };
          if (/liste|lar$|ler$/.test(ad)) return [];
          return { tamam: true };
        } };
        D.durum = { profil: { id: 'x', il_id: 6, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 1000, dolu: false } }, simdi: new Date().toISOString() };
        D.yigin = [];
        setInterval(() => { const m = document.getElementById('modal'); if (m) m.remove(); }, 80);
      }, veri);
      await page.evaluate(() => ekranAc(gozaltiMerkeziEkrani));
      await page.waitForSelector('#nhBolum');
      await page.evaluate(() => document.querySelectorAll('#nhBolum details').forEach(d => d.open = true));
      const olc = await page.evaluate(() => ({ metin: document.getElementById('nhBolum').innerText.replace(/\s+/g, ' '), sayfa: document.documentElement.scrollWidth, ekran: window.innerWidth,
        adet: document.querySelectorAll('#nhBolum').length,
        kucuk: [...document.querySelectorAll('#nhBolum input,#nhBolum textarea,#nhBolum select')].filter(x => parseFloat(getComputedStyle(x).fontSize) < 16).length,
        alcak: [...document.querySelectorAll('#nhBolum .btn')].filter(b => b.offsetParent && b.getBoundingClientRect().height < 44).length }));
      const et = ad + ' / ' + gen + 'px';
      assert.equal(olc.adet, 1, et + ': bölüm bir kez eklenir');
      assert.ok(olc.sayfa <= olc.ekran + 1, et + ': yatay taşma ' + olc.sayfa);
      assert.equal(olc.kucuk, 0, et + ': 16px altı giriş alanı');
      assert.equal(olc.alcak, 0, et + ': 44px altı düğme');
      if (ad === 'supheli') {
        for (const b of ['Nöbetçi hâkimliğe sevk edildiniz', 'Hâkim Ayşe', 'Suçlama (Hakaret)', 'serbest bırakma', 'adli kontrol', 'tutuklama', 'Ceza ya da beraat bu aşamada verilmez', 'Savunmayı sun']) assert.ok(olc.metin.includes(b), et + ': ' + b);
        if (gen === 390) {
          await page.fill('form[data-nh-savunma] textarea', 'Paylaşım eleştiri sınırları içindedir, hakaret değildir.');
          await page.click('form[data-nh-savunma] button[type=submit]'); await page.waitForTimeout(300);
          const c = await page.evaluate(() => calls.filter(x => x.ad === 'nobetci_savunma').pop());
          assert.deepEqual(c.args, { p_sevk: 4, p_metin: 'Paylaşım eleştiri sınırları içindedir, hakaret değildir.' });
        }
      }
      if (ad === 'hakim') {
        for (const b of ['Nöbetçi hâkimlik (1)', 'Nöbetçi sizsiniz', 'Savunma (CELAL)', 'Kararı ver', 'Son nöbetçi hâkimlik kararları', 'Dava #12']) assert.ok(olc.metin.includes(b), et + ': ' + b);
        if (gen === 390) {
          await page.selectOption('form[data-nh-karar] select', 'adli_kontrol');
          await page.fill('form[data-nh-karar] textarea', 'Tutuklama ölçüsüz olacağından adli kontrol yeterlidir.');
          await page.click('form[data-nh-karar] button[type=submit]'); await page.waitForTimeout(300);
          const c = await page.evaluate(() => calls.filter(x => x.ad === 'nobetci_karar').pop());
          assert.deepEqual(c.args, { p_sevk: 4, p_karar: 'adli_kontrol', p_gerekce: 'Tutuklama ölçüsüz olacağından adli kontrol yeterlidir.' });
          // Başka ekranda hâkim şeridi; sabit kalır ve "Aç" merkezi açar
          await page.evaluate(() => { D.yigin = []; iskelet('Gündem', '<div class="kart">akış</div>'); });
          await page.waitForSelector('#nhSerit');
          const degisim = await page.evaluate(() => new Promise(r => { let n = 0; const o = new MutationObserver(m => m.forEach(x => { if ([...x.addedNodes].some(e => e.id === 'nhSerit')) n++; })); o.observe(document.getElementById('app'), { childList: true, subtree: true }); setTimeout(() => { o.disconnect(); r(n); }, 1000); }));
          assert.ok(degisim <= 1, et + ': şerit sürekli yeniden kuruluyor (' + degisim + '/sn)');
          assert.ok((await page.innerText('#nhSerit')).includes('1 dosya karar bekliyor'), et + ': şerit metni');
          await page.click('#nhSerit button', { timeout: 5000 }); await page.waitForSelector('#gzEkran', { timeout: 5000 });
        }
      }
      if (ad === 'yetkili') {
        for (const b of ['Nöbetçi hâkimliğe sevk', 'Zeynep', 'Suçlama türü', 'Karar bekleniyor', 'Sevk #5']) assert.ok(olc.metin.includes(b), et + ': ' + b);
        assert.equal(await page.locator('form[data-nh-sevk]').count(), 1, et + ': sevk edilmiş gözaltıda form yok');
        if (gen === 390) {
          await page.selectOption('form[data-nh-sevk] select', 'iftira');
          await page.fill('form[data-nh-sevk] textarea[name=iddia]', 'Şüpheli asılsız yolsuzluk iddiası yaymıştır.');
          await page.click('form[data-nh-sevk] button[type=submit]'); await page.waitForTimeout(300);
          const c = await page.evaluate(() => calls.filter(x => x.ad === 'nobetci_sevk_et').pop());
          assert.deepEqual(c.args, { p_kaynak: 'yonetim', p_id: 9, p_tur: 'iftira', p_iddia: 'Şüpheli asılsız yolsuzluk iddiası yaymıştır.', p_delil: '' });
        }
      }
      if (ad === 'tutuklu') for (const b of ['Tutuklama', 'Tutukluluğunuz', 'Karar gerekçesi', 'dava #14']) assert.ok(olc.metin.includes(b), et + ': ' + b);
      if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png'), fullPage: true }); }
      await page.close();
    }
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'Sayfa hataları: ' + hatalar.join(' | '));
  console.log('Nöbetçi hâkimlik arayüzü OK (4 durum × 2 genişlik)');
})().catch(e => { console.error(e); process.exit(1); });
