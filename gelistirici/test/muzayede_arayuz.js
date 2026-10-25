// Müzayede Evi arayüz testi (salon, lot, pey, koleksiyon, piyasa, sıralama). Ağ yok; sahte RPC; kurgusal veri.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/muzayede_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
const html = fs.readFileSync(htmlYol, 'utf8').replace(/<script src="https:[^"]+"><\/script>/g, '');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();
const eser = (id, ad, motif, nad, renk, deger, ek) => Object.assign({ id, ad, kod: 'k' + id, motif, renk, nadirlik: nad, nadirlik_ad: nad, kategori: 'tablo', kategori_ad: 'Tablolar',
  seri: 'Deneme Serisi', no: 1, adet: 3, donem: '1900\'ler', aciklama: 'Kurgusal deneme eseri.', kondisyon: 1.1, deger, durum: 'artirmada', sahip: null, benim: false, set_tam: false }, ek || {});
const LOT1 = { id: 11, eser: eser(1, 'Deneme Manzarası', 'tablo_deniz', 'nadir', '#4f8a8b', 22000), baslangic: 13200, bitis: S(5), durum: 'acik', en_yuksek: 14000, pey_sayisi: 2,
  lider: 'Rakip', lider_benim: false, satici: 'Müzayede Evi', satici_benim: false, min_pey: 14700, peyim: 13200, uzadi: false };
const LOT2 = { id: 12, eser: eser(2, 'Deneme Saati', 'saat', 'efsanevi', '#d4af37', 300000), baslangic: 180000, bitis: S(30), durum: 'acik', en_yuksek: null, pey_sayisi: 0,
  lider: null, lider_benim: false, satici: 'Müzayede Evi', satici_benim: false, min_pey: 180000, peyim: null, uzadi: false };
const KAT = ['Tablolar', 'Siyasi tarih', 'Sikkeler'].map((ad, i) => ({ kod: 'k' + i, ad, endeks: 1 + i * 0.02, degisim7: i - 1, seri: [1, 1.01, 0.99, 1 + i * 0.02] }));
const SALON = { simdi: S(0), acik: true, lotlar: [LOT1, LOT2], kategoriler: KAT,
  son_satislar: [{ eser: 'Eski Satış', nadirlik: 'siradan', motif: 'sikke', renk: '#b0bec5', fiyat: 4200, alici: 'Rakip', zaman: S(-2), oran: 0.8 }],
  benim: { eser: 1, deger: 6000, lider: 0, bloke: 0, cuzdan: 250000 }, kurallar: { komisyon: 0.07, eve_satis_oran: 0.5, sergi_tavan: 2000, baslangic_oran: 0.6 } };
const LOT_DETAY = Object.assign({}, LOT1, { simdi: S(0), peyler: [{ kim: 'Rakip', benim: false, tutar: 14000, zaman: S(-1), durum: 'lider' }, { kim: 'Deniz', benim: true, tutar: 13200, zaman: S(-2), durum: 'gecildi' }],
  gecmis: [], endeks: [1, 1.02, 1.01, 1.04], seri_eserler: [{ ad: 'Deneme Manzarası', nadirlik: 'nadir', motif: 'tablo_deniz', renk: '#4f8a8b', bende: false }, { ad: 'İkinci Eser', nadirlik: 'siradan', motif: 'tablo_portre', renk: '#c9733f', bende: true }] });
const KOL = { simdi: S(0), eserler: [Object.assign(eser(3, 'Kendi Pulum', 'pul', 'siradan', '#1565c0', 6000, { durum: 'kasa', benim: true, sahip: 'Deniz', alis_bedeli: 4500, alis_zaman: S(-100) }),
  { lot: null, sergi_gunluk: null, sergi_bas: null, eve_satis: 3000, eve_satis_acilis: S(-28), bagis_kidem: 0 })],
  seriler: [{ seri: 'Deneme Serisi', toplam: 3, bende: 1, tam: false }], peylerim: [LOT1], satistakiler: [], sergi_bugun: null, sergi_tavan: 2000, komisyon: 0.07,
  bagis_kidem: 0, bagis_kidem_tavan: 20, toplam_deger: 6000, toplam_maliyet: 4500 };
const SIRA = { koleksiyoncular: [{ kad: 'Deniz', benim: true, parti: null, eser: 1, deger: 6000, efsanevi: 0, tam_set: 0 }], muze: [], rekorlar: [] };

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  const hatalar = [];
  try {
    for (const w of [390, 320]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: true, locale: 'tr-TR' });
      page.on('pageerror', e => hatalar.push(w + ': ' + e.message + ' @' + String(e.stack || '').split('\n')[1]));
      await page.route('**/*', r => r.abort());
      await page.setContent(html);
      await page.waitForFunction(() => typeof muzayedeEkrani === 'function' && typeof sekmeAc === 'function');
      await page.evaluate((F) => {
        window.calls = [];
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'muzayede_salon') return JSON.parse(JSON.stringify(F.SALON));
          if (ad === 'muzayede_lot') return JSON.parse(JSON.stringify(F.LOT_DETAY));
          if (ad === 'muzayede_pey') { const l = JSON.parse(JSON.stringify(F.LOT_DETAY)); l.en_yuksek = args.p_tutar; l.lider_benim = true; l.lider = 'Deniz'; l.pey_sayisi = 3; return l; }
          if (ad === 'muzayede_koleksiyonum') return JSON.parse(JSON.stringify(F.KOL));
          if (ad === 'muzayede_siralama') return JSON.parse(JSON.stringify(F.SIRA));
          if (ad === 'muzayede_sergi') return { durum: 'sergide' };
          if (ad === 'durum') return { simdi: new Date().toISOString(), profil: D.durum.profil };
          return null;
        } };
        D.durum = { profil: { kad: 'Deniz', il_id: 34, il_ad: 'İstanbul', makamlar: [], cuzdan: { para: 250000 } } };
      }, { SALON, LOT_DETAY, KOL, SIRA });
      const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
      const tasma = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`) }); } };

      await page.evaluate(() => { D.sekme = 'ekonomi'; D.yigin = []; ekranAc(muzayedeEkrani); }); await page.waitForSelector('.mz-izgara');
      let t = await metin();
      assert.match(t, /2 lot açık artırmada/); assert.match(t, /Deneme Manzarası/); assert.match(t, /Günün vitrini/); assert.doesNotMatch(t, /undefined|NaN/);
      assert.equal(await page.locator('.mz-lot').count(), 2);
      await foto('salon'); await tasma('Salon');

      await page.locator('.mz-lot').first().click(); await page.waitForSelector('#mzPeyGirdi');
      t = await metin(); assert.match(t, /Pey geçmişi/); assert.match(t, /Peyin geçildi/); assert.doesNotMatch(t, /undefined|NaN/);
      assert.equal(await page.inputValue('#mzPeyGirdi'), '14.700');
      await page.evaluate(() => mzPeyHizli(0.25)); assert.equal(await page.inputValue('#mzPeyGirdi'), '17.500');
      await foto('lot'); await tasma('Lot');
      await page.click('#mzPeyVer'); await page.click('#evet'); await page.waitForTimeout(300);
      const pey = await page.evaluate(() => calls.filter(c => c.ad === 'muzayede_pey').pop());
      assert.equal(pey.args.p_lot, 11); assert.equal(pey.args.p_tutar, 17500);
      assert.match(await metin(), /Şu an lider sensin/);

      await page.evaluate(() => { geriGit(); }); await page.waitForTimeout(300);
      await page.evaluate(() => mzSekme('kol')); await page.waitForSelector('.mz-eser');
      t = await metin(); assert.match(t, /Koleksiyonum/); assert.match(t, /Kendi Pulum/); assert.match(t, /Peylerim/);
      await page.locator('.mz-eser').first().click(); await page.waitForSelector('#modal .mz-islem');
      assert.match(await page.locator('#modal').innerText(), /Özel müzede sergile/);
      await foto('eser'); await page.evaluate(() => mzSergi(3, true)); await page.waitForTimeout(300);
      assert.ok(await page.evaluate(() => calls.some(c => c.ad === 'muzayede_sergi' && c.args.p_eser === 3 && c.args.p_ac === true)));
      await tasma('Koleksiyon');

      await page.evaluate(() => mzSekme('piyasa')); await page.waitForTimeout(300);
      assert.match(await metin(), /Değer endeksleri/); assert.equal(await page.locator('.mz-kat > div').count(), 3); await tasma('Piyasa');
      await page.evaluate(() => mzSekme('sira')); await page.waitForTimeout(300);
      assert.match(await metin(), /Ülkenin koleksiyoncuları/); assert.match(await metin(), /Devlet Müzesi/); await tasma('Sıralama');
      await foto('sira');
      await page.close();
    }
    const ilgili = hatalar.filter(m => !/ResizeObserver/.test(m));
    console.log('sayfa hataları (toplam):', ilgili.length, ilgili.join(' | '));
    assert.deepEqual(ilgili, []);
    console.log('muzayede_arayuz: TAMAM');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
