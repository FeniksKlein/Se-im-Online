// Sohbette sabit mesaj arayüz testi (sahte RPC; 390 ve 320 px): parti sohbeti sabit çubuğu, eylem sayfasında
// Sabitle / Sabitlemeyi kaldır, sabit listesi (Mesaja git, kaldır), yetkisiz üye, sabitsiz kanal, taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/sohbet_sabit_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const gen of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: gen, height: gen === 320 ? 640 : 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(gen + ': ' + e.message.slice(0, 300)));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => window.sohbetTasarim && typeof sohbetTasarim.kanal === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = []; window.YETKI = true;
      const z = (dk) => new Date(Date.now() - dk * 60000).toISOString();
      const P = { kisa: 'YDP', ad: 'Yeni Demokrasi Partisi', renk: '#1565c0', amblem: 'a_terazi' };
      window.K = [];
      for (let i = 1; i <= 60; i++) K.push({ id: i, kad: i % 2 ? 'Ayşe Yılmaz' : 'Mert Demir', metin: i === 5 ? 'Kurultay takvimi: aday başvuruları cuma 20.00\'ye kadar, oylama cumartesi. Herkes oyunu kullansın!' : 'Mesaj ' + i, zaman: z(600 - i), parti: P, unvan: i % 2 ? 'YDP Genel Başkan Yardımcısı' : 'YDP Parti Sözcüsü', benim: false, gorevli: false, yanit: null });
      window.SB = [5];
      const liste = () => SB.map(id => { const m = K.find(x => x.id === id); return { id, kad: m.kad, metin: m.metin, zaman: m.zaman, gorevli: false, sabitleyen: 'Orhan', sabit_zaman: z(1) }; });
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'sohbet_oku') {
          let l = K.slice();
          if (a.p_sonra != null) l = l.filter(m => m.id > a.p_sonra).slice(0, 100);
          else if (a.p_once != null) l = l.filter(m => m.id < a.p_once).slice(-40);
          else l = l.slice(-40);
          const sabitli = a.p_kanal === 'parti' && a.p_once == null;
          return { kanal: a.p_kanal, baslik: a.p_kanal === 'parti' ? 'Yeni Demokrasi Partisi' : 'İl Kahvesi', mesajlar: l, yazabilir: true, sinyal: 'sohbet:' + a.p_kanal, gorevli_yazabilir: false, resmi_yazabilir: false, kanal_kod: a.p_kanal,
            sabitler: sabitli ? liste() : null, sabitleyebilir: sabitli && YETKI };
        }
        if (ad === 'sohbet_sabitle') {
          let dusen = null;
          SB = SB.filter(x => x !== a.p_mesaj);
          if (a.p_sabitle) { SB.unshift(a.p_mesaj); if (SB.length > 3) dusen = SB.pop(); }
          return { sabitler: liste(), dusen };
        }
        if (ad === 'vergi_rehberi') return { tanitim: true };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: new Date().toISOString(), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/tepki/.test(ad)) return {};
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 34, kad: 'Deniz', parti: P, makamlar: [], cuzdan: { para: 1000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: new Date().toISOString(), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); } };
    const tasma = () => page.evaluate(() => ({ sayfa: document.documentElement.scrollWidth, ekran: window.innerWidth,
      tasan: [...document.querySelectorAll('#shSabit, #shSabit *, #modal *')].filter(x => { const r = x.getBoundingClientRect(); return r.width > 0 && (r.right > window.innerWidth + 1 || r.left < -1) && !x.closest('.sh-tp-sec'); }).length }));
    // bildirim balonları alttaki mesajların üstüne düşebilir; dokunmadan önce temizle
    const dokun = async (sel) => { await page.evaluate(() => document.querySelectorAll('.toast').forEach(x => x.remove())); await page.click(sel); };
    const son = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);
    const cubuk = () => page.evaluate(() => { const b = document.getElementById('shSabit'); if (!b) return null; const r = b.getBoundingClientRect(), a = document.getElementById('akis').getBoundingClientRect();
      return { metin: b.innerText.replace(/\s+/g, ' '), yuk: Math.round(r.height), akisUstu: r.bottom <= a.top + 1, adet: document.querySelectorAll('#shSabit').length }; });

    // 1) Parti sohbeti: sabit çubuğu görünür
    await page.evaluate(() => ekranAc(() => sohbetTasarim.kanal('parti'))); await page.waitForTimeout(900);
    let c = await cubuk();
    assert.ok(c && c.adet === 1, et('sabit çubuğu bir kez görünmeli'));
    assert.ok(/Sabitlenmiş mesaj/.test(c.metin) && /Ayşe Yılmaz: Kurultay takvimi/.test(c.metin), et('çubuk metni: ' + c.metin));
    assert.ok(c.yuk >= 44 && c.akisUstu, et('çubuk 44 px ve mesajların üstünde: ' + JSON.stringify(c)));
    let t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('taşma: ' + JSON.stringify(t)));
    await cek('cubuk');

    // 2) Eylem sayfası: Sabitle
    await dokun('#akis .shm[data-id="58"] .shm-tx'); await page.waitForTimeout(300);
    let e1 = await page.evaluate(() => ({ var: !!document.querySelector('#modal [data-es="sabit"]'), yuk: Math.round((document.querySelector('#modal [data-es="sabit"]') || document.body).getBoundingClientRect().height) }));
    assert.ok(e1.var && e1.yuk >= 44, et('Sabitle seçeneği: ' + JSON.stringify(e1)));
    await cek('eylem');
    await page.click('#modal [data-es="sabit"]'); await page.waitForTimeout(400);
    assert.deepEqual((await son('sohbet_sabitle')).a, { p_kanal: 'parti', p_mesaj: 58, p_sabitle: true });
    c = await cubuk(); assert.ok(/2 sabitlenmiş mesaj/.test(c.metin) && /Mert Demir: Mesaj 58/.test(c.metin), et('yeni sabit en üstte: ' + c.metin));
    // sabitli mesajda menü "Sabitlemeyi kaldır" der
    await dokun('#akis .shm[data-id="58"] .shm-tx'); await page.waitForTimeout(300);
    assert.ok(await page.$('#modal [data-es="sabitsil"]'), et('sabitli mesajda kaldır seçeneği'));
    await page.click('#modal [data-es="vaz"]'); await page.waitForTimeout(150);
    // 4. sabit: en eskisi düşer
    for (const id of [59, 60]) { await dokun('#akis .shm[data-id="' + id + '"] .shm-tx'); await page.waitForTimeout(250); await page.click('#modal [data-es="sabit"]'); await page.waitForTimeout(350); }
    c = await cubuk(); assert.ok(/3 sabitlenmiş mesaj/.test(c.metin), et('en çok 3: ' + c.metin));
    assert.ok(/En eski sabit mesaj kaldırıldı/.test(await page.evaluate(() => [...document.querySelectorAll('.toast')].map(x => x.textContent).join('|'))), et('düşen bildirimi'));

    // 3) Liste: Mesaja git (ekranda olmayan eski mesaj yüklenir) ve kaldır
    await page.evaluate(() => window.SB = [60, 59, 5]);
    await page.evaluate(() => ekranAc(() => sohbetTasarim.kanal('parti'))); await page.waitForTimeout(800);
    await page.click('#shSabit'); await page.waitForTimeout(300);
    let l1 = await page.evaluate(() => ({ kart: document.querySelectorAll('#modal .sh-sbk').length, kaldir: document.querySelectorAll('#modal [data-sb="kaldir"]').length, metin: document.querySelector('#modal').innerText,
      alcak: [...document.querySelectorAll('#modal .sh-sbk-dug button')].filter(b => b.getBoundingClientRect().height < 44).length }));
    assert.equal(l1.kart, 3); assert.equal(l1.kaldir, 3); assert.equal(l1.alcak, 0, et('44 px altı düğme'));
    assert.ok(/Orhan sabitledi/.test(l1.metin) && /Herkes oyunu kullansın!/.test(l1.metin), et('tam metin ve sabitleyen'));
    t = await tasma(); assert.ok(t.tasan === 0, et('liste taşıyor'));
    await cek('liste');
    await page.click('#modal [data-sb="git"][data-id="5"]'); await page.waitForTimeout(1500);
    let g = await page.evaluate(() => { const el = document.querySelector('#akis .shm[data-id="5"]'); return { var: !!el, vurgu: !!el && el.classList.contains('shm-vurgu'), modal: !!document.getElementById('modal') }; });
    assert.ok(g.var && g.vurgu && !g.modal, et('eski sabit mesaja gidilmeli: ' + JSON.stringify(g)));
    await page.click('#shSabit'); await page.waitForTimeout(300);
    await page.click('#modal [data-sb="kaldir"][data-id="59"]'); await page.waitForTimeout(400);
    assert.deepEqual((await son('sohbet_sabitle')).a, { p_kanal: 'parti', p_mesaj: 59, p_sabitle: false });
    c = await cubuk(); assert.ok(/2 sabitlenmiş mesaj/.test(c.metin), et('kaldırınca 2: ' + c.metin));
    // hepsi kalkınca çubuk kaybolur
    await page.evaluate(() => window.SB = [60]);
    await page.click('#shSabit'); await page.waitForTimeout(250);
    await page.evaluate(() => window.SB = [60]);
    await page.click('#modal [data-sb="kaldir"]'); await page.waitForTimeout(400);
    assert.equal(await cubuk(), null, et('sabit kalmayınca çubuk kalkmalı'));

    // 4) Yetkisiz üye: çubuk ve liste var, sabitleme/kaldırma yok
    await page.evaluate(() => { window.YETKI = false; window.SB = [5]; });
    await page.evaluate(() => ekranAc(() => sohbetTasarim.kanal('parti'))); await page.waitForTimeout(800);
    assert.ok(await cubuk(), et('üye de sabit mesajı görür'));
    await dokun('#akis .shm[data-id="58"] .shm-tx'); await page.waitForTimeout(250);
    assert.equal(await page.$('#modal [data-es="sabit"]'), null, et('yetkisiz üyede Sabitle yok'));
    await page.click('#modal [data-es="vaz"]'); await page.waitForTimeout(150);
    await page.click('#shSabit'); await page.waitForTimeout(250);
    assert.equal(await page.$('#modal [data-sb="kaldir"]'), null, et('yetkisiz üyede kaldır yok'));
    await cek('uye_liste');
    await page.click('#modal [data-sb="vaz"]'); await page.waitForTimeout(150);

    // 5) Sabitleme olmayan kanal: çubuk yok, menüde Sabitle yok
    await page.evaluate(() => { window.YETKI = true; });
    await page.evaluate(() => ekranAc(() => sohbetTasarim.kanal('il'))); await page.waitForTimeout(800);
    assert.equal(await cubuk(), null, et('il kahvesinde çubuk olmamalı'));
    await dokun('#akis .shm[data-id="58"] .shm-tx'); await page.waitForTimeout(250);
    assert.equal(await page.$('#modal [data-es="sabit"]'), null, et('il kahvesinde Sabitle yok'));
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('sohbet_sabit_arayuz: tamam');
})().catch(e => { console.error(e); process.exit(1); });
