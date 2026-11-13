// Gözaltı ve Avukat ekranı: gözaltındaki oyuncu, avukat, baro başkanı, CB/İçişleri; her ekranda şerit; sohbet yazma çubuğu kilidi.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/gozalti_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const dosya = (o) => Object.assign({ kaynak: 'yonetim', id: 7, aktif: true, baslangic: S(-1), bitis: S(5), tur_ad: 'Cumhurbaşkanlığı gözaltı kararı', gerekce: 'Kamu düzenini bozan paylaşımlar', baro_talep: false }, o);
const DURUM = {
  gozaltinda_avukatsiz: { simdi: S(0), gozalti: dosya({ avukat_kad: null, avukat_durum: null, yetkili_kad: 'Başkan', yazabilecegi: [], aciklamalar: [] }), muvekkiller: [], avukat_mi: false, baro_baskani: false, tahliye_yetkisi: false },
  gozaltinda_avukatli: { simdi: S(0), gozalti: dosya({ avukat_kad: 'CELAL', avukat_durum: 'kabul', yetkili_kad: 'Başkan', yazabilecegi: ['CELAL'], aciklamalar: [{ metin: 'Müvekkilim suçsuzdur.', zaman: S(-0.2), avukat: 'CELAL' }] }), muvekkiller: [], avukat_mi: false, baro_baskani: false, tahliye_yetkisi: false },
  avukat_baro_yetkili: { simdi: S(0), gozalti: null, avukat_mi: true, baro_baskani: true, tahliye_yetkisi: true,
    muvekkiller: [dosya({ hedef_kad: 'Ayşe', avukat_durum: 'cagrildi', aciklama_sayisi: 0 }), dosya({ id: 8, kaynak: 'sokak', tur_ad: 'Eylem gözaltısı', hedef_kad: 'Mehmet', avukat_durum: 'kabul', aciklama_sayisi: 2, bitis: S(0.5) })] },
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const [ad, veri] of Object.entries(DURUM)) {
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
      await page.waitForFunction(() => window.SO_GOZALTI_V1 && typeof iskelet === 'function' && typeof gozaltiMerkeziEkrani === 'function');
      await page.evaluate((v) => {
        window.calls = []; window.V = v;
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'gozalti_durumum') return V;
          if (ad === 'gozalti_baro_liste2') return { baro_baskani: true, gozaltilar: [{ kaynak: 'yonetim', id: 9, hedef_kad: 'Zeynep', bitis: new Date(Date.now() + 3e6).toISOString(), baro_talep: true, avukat_kad: null, avukat_durum: null }] };
          if (ad === 'gozalti_yetkili_liste') return { yetkili: true, kota: { kota: 3, kullanilan: 1, sure_saat: 6, ara_saat: 24 }, gozaltilar: [{ kaynak: 'yonetim', id: 9, hedef_kad: 'Zeynep', bitis: new Date(Date.now() + 3e6).toISOString(), gerekce: 'Deneme', yetkili_kad: 'Başkan' }] };
          if (ad === 'gozalti_avukat_ara') return [{ kad: 'CELAL', il: 'İstanbul', baro: true }, { kad: 'Eyetkin', il: 'Ankara', baro: true }];
          if (ad === 'yonetim_gozalti_kota') return { yetkili: V.tahliye_yetkisi, kota: 3, kullanilan: 1, sure_saat: 6, ara_saat: 24 };
          if (ad === 'ozel_oku') return { kad: args.p_kad, mesajlar: [], aktif: null };
          if (/liste|lar$|ler$/.test(ad)) return [];
          return { tamam: true };
        } };
        D.durum = { profil: { id: 'x', il_id: 6, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 1000, dolu: false } }, simdi: new Date().toISOString() };
        D.yigin = [];
        setInterval(() => { const m = document.getElementById('modal'); if (m) m.remove(); }, 80);
      }, veri);
      // Ekranı aç
      await page.evaluate(() => ekranAc(gozaltiMerkeziEkrani));
      await page.waitForSelector('#gzEkran');
      const olc = await page.evaluate(() => ({ metin: document.getElementById('gzEkran').innerText.replace(/\s+/g, ' '), sayfa: document.documentElement.scrollWidth, ekran: window.innerWidth,
        kucuk: [...document.querySelectorAll('#gzEkran input,#gzEkran textarea')].filter(x => parseFloat(getComputedStyle(x).fontSize) < 16).length,
        alcak: [...document.querySelectorAll('#gzEkran .btn')].filter(b => b.offsetParent && b.getBoundingClientRect().height < 44).length }));
      const et = ad + ' / ' + gen + 'px';
      assert.ok(olc.sayfa <= olc.ekran + 1, et + ': yatay taşma ' + olc.sayfa);
      assert.equal(olc.kucuk, 0, et + ': 16px altı giriş alanı');
      assert.equal(olc.alcak, 0, et + ': 44px altı düğme');
      if (ad === 'gozaltinda_avukatsiz') {
        for (const b of ['Gözaltındasınız', 'İletişim kısıtı', 'Avukat çağır', 'Barodan müdafi iste', 'Cumhurbaşkanı veya İçişleri Bakanı']) assert.ok(olc.metin.includes(b), et + ': ' + b);
        if (gen === 390) {
          await page.click('[data-gz-avara]'); await page.waitForSelector('[data-gz-cagir]');
          await page.click('[data-gz-cagir]'); await page.waitForTimeout(300);
          const c = await page.evaluate(() => calls.filter(x => x.ad === 'gozalti_avukat_cagir2').pop());
          assert.deepEqual(c.args, { p_kaynak: 'yonetim', p_id: 7, p_avukat_kad: 'CELAL' });
          await page.evaluate(() => ekranAc(gozaltiMerkeziEkrani)); await page.waitForSelector('[data-gz-baroiste]');
          await page.click('[data-gz-baroiste]'); await page.waitForTimeout(300);
          assert.ok(await page.evaluate(() => calls.some(x => x.ad === 'gozalti_baro_iste2' && x.args.p_id === 7)), et + ': baro iste');
        }
      }
      if (ad === 'gozaltinda_avukatli') {
        assert.ok(olc.metin.includes('Yalnız avukatınız CELAL'), et + ': avukat adı');
        assert.ok(olc.metin.includes('Müvekkilim suçsuzdur'), et + ': açıklama');
        assert.ok(!olc.metin.includes('Avukat çağır'), et + ': avukat görevdeyken çağırma yok');
      }
      if (ad === 'avukat_baro_yetkili') {
        for (const b of ['Müvekkillerim (2)', 'Savunmayı üstlen', 'Kürsü açıklaması', 'Baro · gözaltı dosyaları', 'Müdafi istedi', 'Gözaltı kararı', '1 / 3', 'Devam eden gözaltılar (1)', 'Serbest bırak']) assert.ok(olc.metin.includes(b), et + ': ' + b);
        if (gen === 390) {
          await page.click('[data-gz-yanit$=":1"]'); await page.waitForTimeout(250);
          assert.ok(await page.evaluate(() => calls.some(x => x.ad === 'gozalti_avukat_yanit2' && x.args.p_kabul === true && x.args.p_id === 7)), et + ': kabul');
          await page.evaluate(() => ekranAc(gozaltiMerkeziEkrani)); await page.waitForSelector('form[data-gz-aciklama]');
          await page.fill('form[data-gz-aciklama] textarea', 'Müvekkilim haksız yere gözaltında tutuluyor.');
          await page.click('form[data-gz-aciklama] button[type=submit]'); await page.waitForTimeout(250);
          assert.ok(await page.evaluate(() => calls.some(x => x.ad === 'gozalti_avukat_aciklama' && x.args.p_kaynak === 'sokak' && x.args.p_id === 8)), et + ': açıklama');
          await page.evaluate(() => ekranAc(gozaltiMerkeziEkrani)); await page.waitForSelector('form[data-gz-barogonder]');
          await page.fill('form[data-gz-barogonder] input', 'CELAL'); await page.click('form[data-gz-barogonder] button'); await page.waitForTimeout(250);
          assert.ok(await page.evaluate(() => calls.some(x => x.ad === 'gozalti_baro_gonder2' && x.args.p_avukat_kad === 'CELAL' && x.args.p_id === 9)), et + ': baro gönder');
          await page.evaluate(() => ekranAc(gozaltiMerkeziEkrani)); await page.waitForSelector('form[data-gz-karar]');
          await page.fill('#gzHedef', 'Zeynep'); await page.fill('#gzGerekce', 'Somut oyun içi gerekçe metni'); await page.click('form[data-gz-karar] button'); await page.waitForTimeout(250);
          assert.ok(await page.evaluate(() => calls.some(x => x.ad === 'yonetim_tutuklama_yap' && x.args.p_kullanici_adi === 'Zeynep')), et + ': gözaltı kararı');
          await page.evaluate(() => ekranAc(gozaltiMerkeziEkrani)); await page.waitForSelector('form[data-gz-tahliye]');
          await page.fill('form[data-gz-tahliye] textarea', 'Tahliye gerekçesi deneme'); await page.click('form[data-gz-tahliye] button'); await page.waitForTimeout(250);
          assert.ok(await page.evaluate(() => calls.some(x => x.ad === 'gozalti_tahliye' && x.args.p_kaynak === 'yonetim' && x.args.p_id === 9)), et + ': tahliye');
        }
      }
      if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png'), fullPage: false }); }
      // Başka bir ekranda şerit ve sohbet kilidi
      if (veri.gozalti && gen === 390) {
        await page.evaluate(() => { D.yigin = []; iskelet('Gündem', '<div class="kart">akış</div><div id="yazbar"><textarea id="yaz"></textarea></div>'); });
        await page.waitForTimeout(200);
        const s = await page.evaluate(() => ({ serit: (document.getElementById('gzSerit') || {}).innerText || '', yb: document.getElementById('yazbar').innerText }));
        assert.ok(s.serit.includes('Gözaltındasınız'), ad + ': şerit');
        assert.ok(s.yb.includes('buraya yazamazsınız'), ad + ': sohbet çubuğu kilitli');
        // Şerit sabit kalmalı (her karede yeniden kurulursa "Aç" dokunuşu tamamlanmaz) ve "Aç" merkezi açmalı.
        const degisim = await page.evaluate(() => new Promise(r => { let n = 0; const o = new MutationObserver(m => m.forEach(x => { if ([...x.addedNodes].some(e => e.id === 'gzSerit')) n++; })); o.observe(document.getElementById('app'), { childList: true }); setTimeout(() => { o.disconnect(); r(n); }, 1000); }));
        assert.ok(degisim <= 1, ad + ': şerit sürekli yeniden kuruluyor (' + degisim + '/sn)');
        await page.click('#gzSerit button', { timeout: 5000 }); await page.waitForSelector('#gzEkran', { timeout: 5000 });
        if (shot) await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_serit.png') });
      }
      if (!veri.gozalti && gen === 390) {
        await page.evaluate(() => { D.yigin = []; iskelet('Devlet', '<div class="kart">devlet</div>'); });
        await page.waitForTimeout(300);
        assert.ok(await page.evaluate(() => !!document.getElementById('ytDevletKisayol') && !document.getElementById('gzSerit')), ad + ': Devlet kısayolu, şerit yok');
      }
      await page.close();
    }
  }
  await browser.close();
  if (hatalar.length) { console.error('Sayfa hataları:\n' + hatalar.join('\n')); process.exit(1); }
  console.log('gozalti_arayuz TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
