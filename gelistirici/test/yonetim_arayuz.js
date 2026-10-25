// Yönetim alt menüsü (Bakanlığım/Belediyem yerine) ve CİMER "Makamıma gelen" sekmesi. Ağ yok; sahte RPC.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules HTML_PATH=../docs/index.html node test/yonetim_arayuz.js [ekran_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
const html = fs.readFileSync(htmlYol, 'utf8').replace(/<script src="([\w.-]+\.js)(?:\?[^"]*)?"><\/script>/g, (t, ad) => {
  const f = path.join(path.dirname(htmlYol), ad); return fs.existsSync(f) ? '<script>' + fs.readFileSync(f, 'utf8') + '</script>' : t; });
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('**/*', r => r.abort());
    await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
    await page.evaluate(() => {
      window.calls = [];
      window.PROFIL = { il_id: 35, kad: 'Ada', parti: { id: 3, ad: 'Örnek Parti', renk: '#123456' }, gb: false, gby: true, cuzdan: { para: 1 },
        makamlar: [{ tur: 'mv', il_id: 35, il_ad: 'İzmir' }, { tur: 'bel', il_id: 35, il_ad: 'İzmir' }] };
      window.CIMER_GELEN = [];
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args });
        if (ad === 'durum') return { simdi: new Date().toISOString(), profil: PROFIL };
        if (ad === 'cimer') return { basvurularim: [], gelen: CIMER_GELEN, kurumlar: { bakanliklar: [], il_id: 35 }, bugun_kalan: 3 };
        if (ad === 'belediye_sehir_paneli') return { il_ad: 'İzmir', kasa: 1.234, memnuniyet: 55, gelisim: 61 };
        if (ad === 'bakanlik_panellerim') return [{ kod: 'saglik', ad: 'Sağlık Bakanlığı', kasa: 2, pay: 5, gunluk: 0.1, politikalar: [], icraatlar: [] }];
        return null;
      } };
      D.durum = { profil: PROFIL };
    });
    // Alt menü: Yönetim artık Devlet › Makamım; Devlet Gündem'in hemen yanında (2026-10-13)
    await page.evaluate(() => sekmeAc('yonetim'));
    await page.waitForSelector('.ynt-bolum');
    const menu = await page.locator('nav.sekmeler button .pa-nl').allTextContents(); // 5'li alt menü (premium arayüz)
    assert.equal(menu[0], 'Gündem'); assert.equal(menu[1], 'Devlet');
    assert.ok(!menu.includes('Yönetim') && !menu.includes('Belediyem') && !menu.includes('Bakanlığım'), menu.join(','));
    assert.equal(await page.locator('#icerik .segment button.aktif').textContent(), 'Makamım');
    // Belediye bölümü en üstte (ilk makam bölümü), Meclis ve parti bölümleri altta
    const bas = await page.locator('.ynt-bolum h2').allTextContents();
    assert.match(bas[0], /İzmir Belediyesi/); assert.equal(bas[1], 'TBMM'); assert.match(bas[2], /Örnek Parti/);
    const t = await page.locator('#icerik').textContent();
    assert.match(t, /Makamına gelen başvurular/); assert.match(t, /Şehir yönetimi/); assert.match(t, /Genel Başkan Yardımcısı/);
    if (shot) await page.screenshot({ path: path.join(shot, 'yonetim.png'), fullPage: true });
    // Eski bağlantılar Yönetim'e döner
    await page.evaluate(() => sekmeAc('belediye')); await page.waitForSelector('.ynt-bolum');
    assert.equal(await page.evaluate(() => D.sekme), 'devlet');
    // CİMER: belediye başkanına başvuru hiç gelmemişken bile "Makamıma gelen" sekmesi görünür
    await page.click('.ynt-cimer'); await page.waitForSelector('[data-cs="gelen"]');
    assert.match(await page.locator('#icerik').textContent(), /Bekleyen başvuru yok/);
    // Başvuru gelince Yönetim'de sayı görünür
    await page.evaluate(() => { CIMER_GELEN.push({ id: 7, konu: 'Kaldırım bozuk', kurum: 'İzmir Belediyesi', kategori: 'sikayet', metin: 'x', gonderen: 'Can', durum: 'bekliyor', yanitlayabilirim: true, zaman: new Date().toISOString() }); return sekmeAc('yonetim'); });
    await page.waitForSelector('.ynt-cimer .rozet');
    assert.match(await page.locator('.ynt-cimer').textContent(), /Makamına 1 başvuru geldi[\s\S]*Kaldırım bozuk/);
    // Bakan: paneller Yönetim'in içinde; sekme yok
    await page.evaluate(() => { PROFIL.makamlar = [{ tur: 'bakan', bakanlik: 'saglik', bakanlik_ad: 'Sağlık Bakanlığı' }]; PROFIL.gby = false; return sekmeAc('yonetim'); });
    await page.waitForSelector('.ynt-bolum');
    assert.match(await page.locator('#icerik').textContent(), /Sağlık Bakanlığı/);
    // Makamsız oyuncuya sekme gösterilmez
    await page.evaluate(() => { PROFIL.makamlar = []; D.durum = { profil: PROFIL }; iskelet('Deneme', ''); });
    await page.waitForTimeout(300);
    assert.ok(!(await page.locator('nav.sekmeler button .pa-nl').allTextContents()).includes('Yönetim'));
    const ilgili = errors.filter(m => /yonetim|cimer|ynt/i.test(m));
    assert.deepEqual(ilgili, []);
    console.log('yonetim_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
