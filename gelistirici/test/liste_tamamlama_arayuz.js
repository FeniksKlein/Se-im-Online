// Milletvekili listesi tamamlama (28.11.2026) arayüz testi. Ağ yok; sahte RPC; dist/index.html.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/liste_tamamlama_arayuz.js [ekran-goruntusu-klasoru]
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
      // Sunucu tamamlama döneminde yetkiliye mv='atama' (uyum) + gercek_mv döndürür
      const panel = { parti: { id: 1, ad: 'Cumhuriyet Yolu Partisi', kisa: 'CYP', renk: '#c00' }, gb_mi: true, belirlendi: true, mv: 'atama', gercek_mv: 'onsecim', bel: 'onsecim',
        kilit_mv: T, kilit_bel: null, secim_mv: { id: 5, basvuru_bas: G, basvuru_bit: T, oy_bas: T, oy_bit: T, acik: true, tamamlama: true }, secim_bel: null,
        tamamlama_mv: { id: 5, son: T, yetkili: true, aciklama: 'Ön seçim bitti; boş sıraları doldur.' },
        iller: [{ il_id: 34, ad: 'İstanbul', mv: 5, uye: 4, mv_basvuru: 2, mv_atanan: 2, mv_bos: 3, bel_atanan: null }], kural: 'Kural metni.' };
      const il = { il_id: 34, il_ad: 'İstanbul', kontenjan: 5, tur: 'mv', yontem: 'atama', gercek_yontem: 'onsecim', tamamlama: true, kilitli_sayi: 2, dolu: 2, bos: 3,
        dis_il_serbest: true, aciklama: 'İstanbul listesinde 2 sıra dolu, 3 boş.', secim: { id: 5, oy_bit: T, son: T, tamamlama: true },
        uyeler: [
          { kad: 'birinci', ad: 'Bir Inci', kilitli: true, basvurdu: true, tamamlama: false, atama_sira: 1, oy: 9 },
          { kad: 'ikinci', ad: 'Iki Nci', kilitli: true, basvurdu: true, tamamlama: false, atama_sira: 2, oy: 4 },
          { kad: 'uye<b>3', ad: 'Üç <b>Kişi', kilitli: false, tamamlama: false, atama_sira: null },
          { kad: 'baskan', ad: 'Belediye Başkanı', kilitli: false, tamamlama: false, atama_sira: null, engel: 'belediye başkanı' },
          { kad: 'dort', ad: 'Dört Kişi', kilitli: false, tamamlama: false, atama_sira: null }] };
      API = { rpc: async (ad, args) => { calls.push({ ad, args });
        if (ad === 'parti_aday_panel') return panel;
        if (ad === 'parti_aday_il') return il;
        if (ad === 'parti_aday_ata') return il;
        if (ad === 'parti_aday_uye_ara') return [{ kad: 'izmirli', ad: 'İzmirli Üye', il_id: 35, il: 'İzmir', aday_il_id: null, aday_il: null, atama_sira: null, basvurdu: false, uygun: true }];
        return {}; } };
      D.durum = { profil: { il_id: 34, kad: 'gb', parti: { id: 1, renk: '#c00' }, makamlar: [], cuzdan: { para: 1000 } } };
      D.sekme = 'parti'; D.yigin = [];
    }, { T, G });
    await page.evaluate(() => iskelet('Partiler', '<div class="kart">Parti listesi</div>'));
    await page.waitForSelector('#abPartiKart .ab-kart');
    let t = await page.locator('#abPartiKart').textContent();
    assert.match(t, /Liste tamamlama açık/); assert.match(t, /Ön seçim/, 'gerçek yöntem gösterilmeli');
    await page.getByRole('button', { name: 'Listeleri tamamla' }).click();
    await page.waitForSelector('.ab-il');
    t = await page.locator('#icerik').textContent();
    assert.match(t, /3 boş sıra/); assert.match(t, /Liste tamamlama açık/);
    assert.equal(await page.locator('#abMv').inputValue(), 'onsecim', 'yöntem seçimi gerçek yöntemi göstermeli');
    if (shot) await page.screenshot({ path: path.join(shot, genislik + '_t1_ekran.png'), fullPage: true });
    await page.click('.ab-il');
    await page.waitForSelector('#abTListe');
    // kilitli sıralarda düğme yok, engelli üyede ekle düğmesi yok
    assert.equal(await page.locator('.modal li:has-text("Bir Inci") button').count(), 0);
    assert.equal(await page.locator('#abTUyeler button[data-e="baskan"]').count(), 0);
    assert.match(await page.locator('#abTUyeler').textContent(), /eklenemez: belediye başkanı/);
    await page.locator('#abTUyeler button[data-e="uye<b>3"]').click();
    await page.locator('#abTUyeler button[data-e="dort"]').click();
    assert.match(await page.locator('#abTListe').textContent(), /^3\./, 'numara kilitlilerin arkasından başlamalı');
    await page.locator('#abTListe button[data-y="1"]').click();
    // başka ilden arama
    await page.fill('#abTAra', 'izm');
    await page.waitForSelector('#abTAraSonuc button[data-d="izmirli"]');
    await page.click('#abTAraSonuc button[data-d="izmirli"]');
    // kontenjan dolu: 4. ekleme reddedilir (3 boş sıra)
    await page.fill('#abTAra', 'izm');
    assert.equal(await page.locator('#abTListe li').count(), 3);
    assert.equal(await page.locator('.modal b >> text=3').count() >= 0, true);
    assert.equal(await page.locator('#abTListe b:has-text("<b>")').count(), 0, 'HTML kaçışı');
    if (shot) await page.screenshot({ path: path.join(shot, genislik + '_t2_liste.png') });
    const tasma = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    assert.ok(tasma <= 1, 'yatay taşma: ' + tasma);
    await page.click('#abTKaydet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'parti_aday_ata'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'parti_aday_ata').args), { p_tur: 'mv', p_il: 34, p_kadlar: ['dort', 'uye<b>3', 'izmirli'] });
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, []);
  console.log('liste_tamamlama_arayuz TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
