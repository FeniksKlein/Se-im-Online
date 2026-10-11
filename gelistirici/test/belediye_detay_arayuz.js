// Belediye şehir yönetimi: karne, kriz masası, İller Bankası sekmeleri. Ağ yok; gerçek RPC çıktılarıyla sahte API.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules HTML_PATH=../docs/index.html node test/belediye_detay_arayuz.js [ekran_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../../docs/index.html'), 'utf8');
const veri = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/belediye_detay_ornek.json'), 'utf8'));
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('**/*', r => r.abort());
    await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
    await page.evaluate((v) => {
      window.calls = []; window.V = v; window.DETAY_YOK = false;
      const PROFIL = { il_id: 6, kad: 'AnkBaskan', makamlar: [{ tur: 'bel', il_id: 6, il_ad: 'Ankara' }], cuzdan: { para: 1 } };
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args });
        if (ad === 'durum') return { simdi: new Date().toISOString(), profil: PROFIL };
        if (ad === 'belediye_sehir_paneli') return V.sehir;
        if (ad === 'belediye_detay_paneli') { if (DETAY_YOK) throw new Error('function public.belediye_detay_paneli() does not exist'); return V.detay; }
        if (ad === 'belediye_karnesi') return V.karnesi;
        if (ad === 'belediye_kriz_karar') return { tamam: true, basarili: true, durum: 'cozuldu' };
        if (ad === 'belediye_kredi_al') return { tamam: true };
        return null;
      } };
      D.durum = { profil: PROFIL };
    }, veri);
    // Para biçimi
    const yaz = await page.evaluate(() => [kasaYaz(1000.1), kasaYaz(0.001), kasaYaz(0.0066), kasaYaz(0)]);
    assert.deepEqual(yaz, ['1.000,10 milyar ₺', '1,0 milyon ₺', '6,6 milyon ₺', '0 ₺']);

    await page.evaluate(() => ekranAc(belediyeSehirYonetimEkrani));
    await page.waitForSelector('.segment button');
    const sek = await page.locator('.segment button').allTextContents();
    assert.deepEqual(sek.map(s => s.replace(/ \(1\)$/, '')), ['Bütçe', 'Karne', 'Kriz', 'Binalar', 'Ekonomi', 'İller Bankası', 'İşlem defteri']);
    let t = await page.locator('#icerik').textContent();
    assert.match(t, /Kriz masası: Yoğun kar yağışı/); assert.match(t, /Hizmet karnesi ortalaması/);
    assert.ok(!/mlr/.test(t), 'eski "mlr" yazısı kalmamalı');
    if (shot) await page.screenshot({ path: path.join(shot, 'bel_butce.png'), fullPage: true });

    await page.evaluate(() => belediyeSehirMod('karne')); await page.waitForTimeout(200);
    t = await page.locator('#icerik').textContent();
    for (const a of ['Temizlik ve atık', 'Su ve altyapı', 'Ulaşım', 'Sağlık ve sosyal', 'Eğitim ve kültür', 'Güvenlik ve afet', 'Yeşil alan ve çevre']) assert.ok(t.includes(a), a);
    assert.match(t, /Su Arıtma Tesisi/);
    if (shot) await page.screenshot({ path: path.join(shot, 'bel_karne.png'), fullPage: true });

    await page.evaluate(() => belediyeSehirMod('kriz')); await page.waitForTimeout(200);
    t = await page.locator('#icerik').textContent();
    assert.match(t, /Açık kriz/); assert.match(t, /Tüm ekipler sahaya/); assert.match(t, /Geçmiş kararlar/);
    if (shot) await page.screenshot({ path: path.join(shot, 'bel_kriz.png'), fullPage: true });
    await page.locator('button:has-text("Bu kararı ver")').first().click();
    await page.locator('.modal button:has-text("Kararı ver")').click();
    await page.waitForFunction(() => calls.some(c => c.ad === 'belediye_kriz_karar'));
    const kc = await page.evaluate(() => [calls.find(c => c.ad === 'belediye_kriz_karar').args, V.detay.kriz.id]);
    assert.deepEqual(kc[0], { p_id: kc[1], p_secim: 'a' });

    await page.evaluate(() => belediyeSehirMod('borc')); await page.waitForTimeout(200);
    t = await page.locator('#icerik').textContent();
    assert.match(t, /İller Bankası/); assert.match(t, /Kullanılabilir limit/);
    if (shot) await page.screenshot({ path: path.join(shot, 'bel_borc.png'), fullPage: true });

    await page.evaluate(() => belediyeKarneModal(6)); await page.waitForSelector('.modal h3');
    t = await page.locator('.modal').textContent();
    assert.match(t, /Ankara belediye karnesi/); assert.match(t, /Son krizlerde başkanın kararları/);
    if (shot) await page.screenshot({ path: path.join(shot, 'bel_karne_halk.png'), fullPage: true });
    await page.evaluate(() => modalKapat());

    // Sunucuda yeni modül yoksa eski ekran bozulmadan çalışır
    await page.evaluate(() => { DETAY_YOK = true; D._belediyeSehirMod = 'kriz'; return belediyeSehirYonetimEkrani(); });
    await page.waitForTimeout(200);
    const sek2 = await page.locator('.segment button').allTextContents();
    assert.deepEqual(sek2, ['Bütçe', 'Binalar', 'Ekonomi', 'İşlem defteri']);
    assert.match(await page.locator('#icerik').textContent(), /Şehrin güncel durumu/);

    const ilgili = errors.filter(m => /belediye|kasaYaz|karne|kriz/i.test(m));
    assert.deepEqual(ilgili, [], ilgili.join('\n'));
    console.log('belediye_detay_arayuz: hepsi geçti');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
