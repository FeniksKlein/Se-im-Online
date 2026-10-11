// Kredi masası arayüzü. Veriler yerel DB'deki gerçek RPC çıktıları (test/veri/oyb_kredi_masasi_ornek.json).
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules HTML_PATH=../docs/index.html node test/oyb_kredi_masasi_arayuz.js [ekran_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
const veri = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/oyb_kredi_masasi_ornek.json'), 'utf8'));
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('**/*', r => r.abort());
    await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
    await page.evaluate(v => {
      window.V = v; window.calls = []; window.KIM = 'can';
      window.onayla = async () => true;
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args });
        if (ad === 'oyb_kredi_masasi') return V[KIM];
        if (ad === 'oyb_kredi_plan') return V.plan;
        if (['oyb_kredi_cek'].includes(ad)) return { tamam: true, durum: 'aktif', id: 99 };
        return { tamam: true };
      } };
      D.durum = { profil: { il_id: 35, kad: 'Can', parti: null, makamlar: [], cuzdan: { para: 1 } } };
    }, veri);
    // Müşteri: teklif + bilgi talebi + paket, plan görmeden çekme kapalı
    await page.evaluate(b => oybKrediMasasiEkrani(b), veri.banka);
    await page.waitForSelector('.km-paket');
    let t = await page.locator('#icerik').textContent();
    assert.match(t, /sana özel kredi teklifi/); assert.match(t, /mali bilgi istiyor/); assert.match(t, /Kredi paketleri/);
    const pid = veri.paket;
    assert.ok(await page.locator(`#kmCek${pid}`).isDisabled(), 'plan görülmeden çekilemez');
    await page.fill(`#kmTutar${pid}`, '5000'); await page.click(`text=Ödeme planını gör >> nth=0`);
    await page.waitForSelector(`#kmPlan${pid} .km-tablo`);
    assert.match(await page.locator(`#kmPlan${pid}`).textContent(), /Toplam/);
    assert.ok(!(await page.locator(`#kmCek${pid}`).isDisabled()));
    if (shot) await page.screenshot({ path: path.join(shot, 'kredi_musteri.png'), fullPage: true });
    await page.click(`#kmCek${pid}`); await page.waitForFunction(() => calls.some(c => c.ad === 'oyb_kredi_cek'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'oyb_kredi_cek').args), { p_paket: pid, p_tutar: 5000 });
    // Bilgi izni: bir kutuyu kaldırıp izin ver
    await page.waitForSelector('input[name="kmIzin"]');
    await page.locator('input[name="kmIzin"][value="mulk"]').uncheck();
    await page.click('text=Seçtiklerime izin ver'); await page.waitForFunction(() => calls.some(c => c.ad === 'oyb_hesap_bilgi_yanit'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'oyb_hesap_bilgi_yanit').args.p_kapsam), ['maas']);
    // Erken kapama (Veli'nin gecikmiş kredisi var) ve sıradaki taksit
    await page.evaluate(b => { KIM = 'veli'; return oybKrediMasasiEkrani(b); }, veri.banka);
    await page.waitForSelector('text=Erken kapat');
    await page.click('text=Erken kapat'); await page.waitForFunction(() => calls.some(c => c.ad === 'oyb_kredi_erken_kapat'));
    // Yönetim
    await page.evaluate(b => { KIM = 'sahip'; KM.mod = 'yonetim'; return oybKrediMasasiEkrani(b); }, veri.banka);
    await page.waitForSelector('text=Kredi paketlerin');
    t = await page.locator('#icerik').textContent();
    assert.match(t, /Hesap sahipleri/); assert.match(t, /Açık krediler/); assert.match(t, /Kasa ve likidite/);
    assert.ok(await page.locator('text=Adliye\'de dava aç').count() >= 1 || /icra dosyası/.test(t), 'geciken krediye dava');
    if (shot) await page.screenshot({ path: path.join(shot, 'kredi_yonetim.png'), fullPage: true });
    await page.click('text=Yeni kredi paketi');
    await page.fill('#kpAd', 'Esnaf'); await page.fill('#kpVade', '30');
    assert.ok((await page.locator('#kpTaksit option').allTextContents()).some(x => /^10 taksit · 3 günde bir/.test(x)));
    await page.selectOption('#kpTaksit', '10'); await page.click('#kpKaydet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'oyb_paket_kaydet'));
    const pk = await page.evaluate(() => calls.find(c => c.ad === 'oyb_paket_kaydet').args);
    assert.equal(pk.p_vade_gun, 30); assert.equal(pk.p_taksit, 10); assert.equal(pk.p_ad, 'Esnaf');
    await page.waitForSelector('text=Kredi teklif et');
    await page.locator('text=Kredi teklif et').first().click(); await page.waitForSelector('#ktPlan .km-tablo');
    await page.click('#ktGonder'); await page.waitForFunction(() => calls.some(c => c.ad === 'oyb_kredi_teklif_ver'));
    const ilgili = errors.filter(m => !/Beklenmeyen/.test(m));
    assert.deepEqual(ilgili, []);
    console.log('oyb_kredi_masasi_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
