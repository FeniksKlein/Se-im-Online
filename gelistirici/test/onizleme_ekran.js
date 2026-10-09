// Önizleme sunucusundaki uygulamanın ekran görüntülerini alır (390×844, iPhone boyutu).
// Kullanım: node test/onizleme_ekran.js <çıktı-klasörü> <kad> <ekran1,ekran2,...>
// Ekran adları aşağıdaki ADIM tablosundadır.
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path'), fs = require('fs');
const [cikti, kad, liste] = process.argv.slice(2);
const ADIM = {
  karsilama: async p => { await p.goto('http://127.0.0.1:8788/'); await p.waitForTimeout(600); },
  gundem: async p => { await ac(p); },
  gundem_alt: async p => { await ac(p); await p.evaluate(() => { const m = document.querySelector('#icerik'); m.scrollTop = m.scrollHeight * 0.45; }); await p.waitForTimeout(300); },
  hayat: async p => { await ac(p); await p.evaluate(() => sekmeAc('hayat')); await p.waitForTimeout(900); },
  partiler: async p => { await ac(p); await p.evaluate(() => sekmeAc('parti')); await p.waitForTimeout(900); },
  devlet: async p => { await ac(p); await p.evaluate(() => sekmeAc('devlet')); await p.waitForTimeout(900); },
  harita: async p => { await ac(p); await p.evaluate(() => sekmeAc('harita')); await p.waitForTimeout(900); },
  sohbet: async p => { await ac(p); await p.evaluate(() => sekmeAc('sohbet')); await p.waitForTimeout(900); },
  ben: async p => { await ac(p); await p.evaluate(() => sekmeAc('ben')); await p.waitForTimeout(900); },
  sandik: async p => { await ac(p); await p.evaluate(async () => { const s = (D.durum.takvim || []).find(x => x.tur === 'mv' && x.asama === 'oy'); if (s) ekranAc(() => secimEkrani(s.id)); }); await p.waitForTimeout(1200); },
  sandik_secili: async p => { await ADIM.sandik(p); await p.locator('.pusula-secenek, .oy-satir').nth(1).click(); await p.waitForTimeout(500); },
  sonuc: async p => { await ac(p); await p.evaluate(async () => { const s = (D.durum.takvim || []).find(x => x.tur === 'mv' && x.asama === 'bitti'); if (s) ekranAc(() => secimEkrani(s.id)); }); await p.waitForTimeout(2600); },
  oyuncu: async p => { await ac(p); await p.evaluate(() => oyuncuKart('Ercan_Ege')); await p.waitForTimeout(900); },
  tarih: async p => { await ac(p); await p.evaluate(() => { D.devletSekme = 'tarih'; sekmeAc('devlet'); }); await p.waitForTimeout(1200); },
  meclis: async p => { await ac(p); await p.evaluate(() => { D.devletSekme = 'meclis'; sekmeAc('devlet'); }); await p.waitForTimeout(1200); },
  gazete: async p => { await ac(p); await p.evaluate(() => otomatikGazeteEkrani()); await p.waitForTimeout(1200); },
  basin: async p => { await ac(p); await p.evaluate(() => ekranAc(basinEkrani)); await p.waitForTimeout(1000); },
  banka: async p => { await ac(p); await p.evaluate(() => ekranAc(bankaEkrani)); await p.waitForTimeout(1000); },
  bildirim: async p => { await ac(p); await p.evaluate(() => ekranAc(bildirimEkrani)); await p.waitForTimeout(1000); },
  parti_detay: async p => { await ac(p); await p.evaluate(() => ekranAc(() => partiDetay(1))); await p.waitForTimeout(1400); },
  il: async p => { await ac(p); await p.evaluate(() => { sekmeAc('harita'); setTimeout(() => ilDetay(35), 600); }); await p.waitForTimeout(1800); },
  vatandaslik: async p => { await ac(p); await p.evaluate(() => vatandaslikModal()); await p.waitForTimeout(900); },
  hayat_alt: async p => { await ADIM.hayat(p); await p.evaluate(() => { const m = document.querySelector('#icerik'); m.scrollTop = m.scrollHeight; }); await p.waitForTimeout(300); },
  sirket: async p => { await ac(p); await p.evaluate(() => sirketEkrani()); await p.waitForTimeout(1200); },
  piyasa: async p => { await ac(p); await p.evaluate(() => ekranAc(piyasaEkrani)); await p.waitForTimeout(1200); },
  pusula_parti: async p => { await ac(p); await p.evaluate(() => typeof partiTestiModal === 'function' && partiTestiModal()); await p.waitForTimeout(700); },
  mulk: async p => { await ac(p); await p.evaluate(() => ekranAc(mulkEkrani)); await p.waitForTimeout(1500); },
  mulk_alt: async p => { await ADIM.mulk(p); await p.evaluate(() => { const m = document.querySelector('#icerik'); m.scrollTop = 520; }); await p.waitForTimeout(300); },
  mulk_il: async p => { await ADIM.mulk(p); await p.evaluate(() => { mulkSecIl = 69; $('#mulkStokAlan').innerHTML = mulkStokHtml(); const m = document.querySelector('#icerik'); m.scrollTop = 520; }); await p.waitForTimeout(300); },
  meydan: async p => { await ac(p); await p.evaluate(() => mitingAc(1)); await p.waitForTimeout(1800); },
  meydan_alt: async p => { await ADIM.meydan(p); await p.evaluate(() => { const m = document.querySelector('#icerik'); m.scrollTop = 560; }); await p.waitForTimeout(300); },
  meydan_son: async p => { await ADIM.meydan(p); await p.evaluate(() => { const m = document.querySelector('#icerik'); m.scrollTop = m.scrollHeight; }); await p.waitForTimeout(300); },
  parti_miting: async p => { await ADIM.parti_detay(p); await p.evaluate(() => { const k = document.querySelector('#partiMitingKart'); if (k) k.scrollIntoView(); }); await p.waitForTimeout(500); },
  parti_miting_modal: async p => { await ADIM.parti_detay(p); await p.evaluate(() => partiMitingModal(1)); await p.waitForTimeout(600); },
  portre: async p => { await ac(p); await p.evaluate(() => typeof portreModal === 'function' && portreModal()); await p.waitForTimeout(700); },
};
async function ac(p) { await p.goto('http://127.0.0.1:8788/?kad=' + encodeURIComponent(kad)); await p.waitForSelector('.sekmeler', { timeout: 15000 }); await p.waitForTimeout(1400); }
(async () => {
  fs.mkdirSync(cikti, { recursive: true });
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
  const hatalar = [];
  for (const ad of liste.split(',')) {
    const p = await ctx.newPage();
    p.on('pageerror', e => hatalar.push(ad + ': ' + e.message));
    p.on('console', m => { if (m.type() === 'error') hatalar.push(ad + ' konsol: ' + m.text()); });
    try { await ADIM[ad](p); await p.screenshot({ path: path.join(cikti, ad + '.png') }); console.log('✓', ad); }
    catch (err) { console.log('✗', ad, err.message.split('\n')[0]); }
    await p.close();
  }
  await b.close();
  if (hatalar.length) console.log('SAYFA HATALARI:\n' + [...new Set(hatalar)].join('\n'));
})();
