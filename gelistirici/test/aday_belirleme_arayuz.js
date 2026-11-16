// Aday belirleme (ön seçim / Genel Başkan ataması) arayüz testi. Ağ yok; sahte RPC; dist/index.html.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/aday_belirleme_arayuz.js [ekran-goruntusu-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = path.join(__dirname, '../dist');
const shot = process.argv[2];
const T = new Date(Date.now() + 3600e3).toISOString(), G = new Date(Date.now() - 3600e3).toISOString();

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  for (const genislik of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: genislik, height: 800 }, isMobile: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(genislik + ': ' + e.message));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, u.pathname === '/' ? '/index.html' : decodeURIComponent(u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'text/javascript' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => typeof window.adayBelirlemeEkrani === 'function' && typeof iskelet === 'function');
    await page.evaluate(({ T, G }) => {
      window.calls = [];
      const panel = { parti: { id: 1, ad: 'Halk Partisi', kisa: 'HP', renk: '#c00' }, gb_mi: true, belirlendi: false, mv: 'onsecim', bel: 'onsecim',
        kilit_mv: null, kilit_bel: null, secim_mv: { id: 9, basvuru_bas: G, basvuru_bit: G, oy_bas: G, oy_bit: T, acik: true }, secim_bel: null,
        iller: [{ il_id: 7, ad: 'Antalya', mv: 16, uye: 3, mv_basvuru: 1, mv_atanan: 0, bel_atanan: null }], kural: 'Kural metni.' };
      const il = { il_id: 7, il_ad: 'Antalya', kontenjan: 16, tur: 'mv', yontem: 'atama', secim: { id: 9, oy_bit: T },
        uyeler: [{ kad: 'Doğukan', gb: true, basvurdu: false, atama_sira: null }, { kad: 'yavuz<b>02', gb: false, basvurdu: true, atama_sira: null }, { kad: 'Kuzey', gb: false, basvurdu: false, atama_sira: null }] };
      API = { rpc: async (ad, args) => { calls.push({ ad, args });
        if (ad === 'parti_aday_panel') return panel;
        if (ad === 'parti_aday_yontem_ayarla') { panel.mv = args.p_mv; panel.bel = args.p_bel; panel.belirlendi = true; return panel; }
        if (ad === 'parti_aday_il') return il;
        if (ad === 'parti_aday_ata') return il;
        return {}; } };
      D.durum = { profil: { il_id: 7, kad: 'Doğukan', parti: { id: 1, renk: '#c00' }, makamlar: [], cuzdan: { para: 1000 } } };
      D.sekme = 'parti'; D.yigin = [];
    }, { T, G });
    await page.evaluate(() => iskelet('Partiler', '<div class="kart">Parti listesi</div>'));
    await page.waitForSelector('#abPartiKart .ab-kart');
    let t = await page.locator('#abPartiKart').textContent();
    assert.match(t, /Aday belirleme · HP/); assert.match(t, /henüz seçmedin/); assert.match(t, /Yöntemi seç/);
    if (shot) await page.screenshot({ path: path.join(shot, genislik + '_1_partiler.png') });
    await page.getByRole('button', { name: 'Yöntemi seç' }).click();
    await page.waitForSelector('#abMv');
    await page.selectOption('#abMv', 'atama');
    await page.click('#abKaydet');
    await page.waitForSelector('.ab-il');
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'parti_aday_yontem_ayarla').args), { p_mv: 'atama', p_bel: 'onsecim' });
    if (shot) await page.screenshot({ path: path.join(shot, genislik + '_2_ekran.png'), fullPage: true });
    await page.click('.ab-il');
    await page.waitForSelector('#abListe');
    // Önce başvuran, sonra GB eklenir; GB yukarı taşınır
    await page.locator('#abUyeler button[data-e="yavuz<b>02"]').click();
    await page.locator('#abUyeler button[data-e="Doğukan"]').click();
    await page.locator('#abListe button[data-y="1"]').click();
    assert.equal(await page.locator('#abListe b >> text=02').count(), 0, 'HTML kaçışı');
    if (shot) await page.screenshot({ path: path.join(shot, genislik + '_3_liste.png') });
    await page.click('#abLKaydet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'parti_aday_ata'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'parti_aday_ata').args), { p_tur: 'mv', p_il: 7, p_kadlar: ['Doğukan', 'yavuz<b>02'] });
    // Taşma kontrolü
    const tasma = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    assert.ok(tasma <= 1, 'yatay taşma: ' + tasma);
    // Üye görünümü
    await page.evaluate(() => { window.__p = null; });
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, []);
  console.log('aday_belirleme_arayuz TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
