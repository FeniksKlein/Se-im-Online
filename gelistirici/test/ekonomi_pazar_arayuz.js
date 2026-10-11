// Rekabetçi şirketler + kamu ihaleleri ekranları. Ağ yok; yerel veritabanından alınmış gerçek RPC çıktıları (test/veri/ekonomi_pazar_ornek.json).
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/ekonomi_pazar_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
for (const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
const FX = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/ekonomi_pazar_ornek.json'), 'utf8'));
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    for (const w of [320, 390, 768]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: w < 700, locale: 'tr-TR' });
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      await page.route('**/*', r => r.abort());
      await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
      await page.evaluate((FX) => {
        window.calls = []; window.FX = FX; window.ihaleKim = 'ihale_a';
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'pazar_katalog') return FX.katalog;
          if (ad === 'pazar_harita') return FX.harita;
          if (ad === 'pazar_detay') return args.p_sirket === FX.enerji.id ? FX.enerji : FX.detay;
          if (ad === 'pazar_ayarla' || ad === 'pazar_tasi') return FX.detay.tahmin;
          if (ad === 'pazar_sirket_kur') return { id: FX.detay.id, tahmin: FX.detay.tahmin };
          if (ad === 'ihale_ekrani') return FX[window.ihaleKim];
          if (['ihale_ac', 'ihale_teklif', 'ihale_teklif_geri', 'ihale_iptal', 'ihale_yontem', 'sektor_politika_ayarla', 'il_ruhsat_ayarla'].includes(ad)) return { tamam: true };
          if (ad === 'sirket_vitrini') return { sirketler: [] };
          throw new Error('Beklenmeyen RPC: ' + ad);
        } };
        D.durum = { profil: { il_id: 35, kad: 'Ayse', parti: null, makamlar: [], cuzdan: { para: 4600000 } } };
      }, FX);
      const sec = (s) => page.locator(s);
      const tik = async (s) => { await sec(s).first().click(); await page.waitForTimeout(80); };
      const onay = async () => { await page.waitForSelector('#evet'); await page.click('#evet'); await page.waitForTimeout(80); };
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };

      // merkez
      await page.evaluate(() => ekranAc(pazarMerkezEkrani)); await page.waitForSelector('.pz-satir');
      let t = await sec('#icerik').textContent();
      assert.match(t, /Ayse Market/); assert.match(t, /Özel Hastane/); assert.match(t, /Enerji Santrali/); assert.match(t, /kurumlar vergisi/);
      await tasmaYok('merkez'); if (shot) await page.screenshot({ path: path.join(shot, `pazar_merkez_${w}.png`), fullPage: true });

      // harita + kuruluş
      await page.evaluate(() => ekranAc(() => pazarHaritaEkrani('market'))); await page.waitForSelector('#pzIlListe .pz-satir');
      assert.equal(await sec('#pzIlListe .pz-satir').count(), 81);
      await page.fill('#pzIlAra', 'izm'); await page.waitForTimeout(50);
      assert.equal(await page.locator('#pzIlListe .pz-satir:visible').count(), 1);
      await tasmaYok('harita'); if (shot) await page.screenshot({ path: path.join(shot, `pazar_harita_${w}.png`) });
      await tik('#pzIlListe .pz-satir:visible');
      await page.fill('#pzAd', 'Ege Market'); await tik('#pzKurBtn'); await page.waitForTimeout(200);
      let c = await page.evaluate(() => calls.find(x => x.ad === 'pazar_sirket_kur'));
      assert.equal(c.args.p_il, 35); assert.equal(c.args.p_sektor, 'market'); assert.equal(c.args.p_kaynak, null);

      // detay + karar önizleme
      await page.evaluate(() => ekranAc(() => pazarDetayEkrani(FX.detay.id))); await page.waitForSelector('#pzKaydet');
      t = await sec('#icerik').textContent();
      assert.match(t, /Bu haftanın tahmini/); assert.match(t, /Pazardaki payın/); assert.match(t, /Haftalık raporlar/);
      assert.ok(await sec('#pzKaydet').isDisabled(), 'değişiklik yokken buton kapalı');
      await tik('#pzFiyat button[data-v="1"]');
      assert.ok(!(await sec('#pzKaydet').isDisabled()));
      const beklenen = FX.detay.senaryo.find(x => x.fiyat === 1 && x.kalite === FX.detay.kalite).net;
      assert.match(await sec('#pzOnizNet').textContent(), new RegExp(String(Math.abs(beklenen)).replace(/\B(?=(\d{3})+(?!\d))/g, '.')));
      await tasmaYok('detay'); if (shot) await page.screenshot({ path: path.join(shot, `pazar_detay_${w}.png`), fullPage: true });
      await tik('#pzKaydet'); await page.waitForTimeout(150);
      c = await page.evaluate(() => calls.find(x => x.ad === 'pazar_ayarla')); assert.equal(c.args.p_fiyat, 1);

      // enerji kaynak seçimi
      await page.evaluate(() => ekranAc(() => pazarDetayEkrani(FX.enerji.id))); await page.waitForSelector('#pzKaynak');
      assert.match(await sec('#pzKaynak').textContent(), /Kömür/);
      await tik('#pzKaynak button[data-v="yenilenebilir"]'); await tik('#pzKaydet'); await page.waitForTimeout(150);
      c = await page.evaluate(() => calls.filter(x => x.ad === 'pazar_ayarla').pop()); assert.equal(c.args.p_kaynak, 'yenilenebilir');

      // ihaleler: şirket sahibi gözüyle
      await page.evaluate(() => { PZ.ihaleSekme = 'acik'; ekranAc(ihaleEkrani); }); await page.waitForSelector('.segment');
      t = await sec('#icerik').textContent(); assert.match(t, /Park ve yeşil alan/); assert.doesNotMatch(t, /Makam masası/);
      await tasmaYok('ihale'); if (shot) await page.screenshot({ path: path.join(shot, `ihale_acik_${w}.png`), fullPage: true });
      const acik = FX.ihale_a.acik[0];
      if (!acik.acan_benim && FX.ihale_a.insaat_sirketlerim.length) {
        await page.fill(`#ihT${acik.id}`, String(Math.round(acik.tavan * 0.9)));
        await tik(`button[onclick="ihaleTeklifVer(${acik.id})"]`); await page.waitForTimeout(150);
        c = await page.evaluate(() => calls.find(x => x.ad === 'ihale_teklif')); assert.equal(c.args.p_ihale, acik.id);
      }
      await page.evaluate(() => { PZ.ihaleSekme = 'yapim'; ihaleEkrani(); }); await page.waitForSelector('.pz-secim');
      if (shot) await page.screenshot({ path: path.join(shot, `ihale_yapim_${w}.png`), fullPage: true });
      await tik('.pz-secim button:nth-child(3)'); await onay(); await page.waitForTimeout(150);
      c = await page.evaluate(() => calls.find(x => x.ad === 'ihale_yontem')); assert.equal(c.args.p_yontem, 'tasarruflu');
      await page.evaluate(() => { PZ.ihaleSekme = 'biten'; ihaleEkrani(); }); await page.waitForTimeout(150);
      assert.match(await sec('#icerik').textContent(), /Denetime takıldı|Teslim edildi/);

      // belediye başkanı masası
      await page.evaluate(() => { window.ihaleKim = 'ihale_bas'; PZ.ihaleSekme = 'masa'; ihaleEkrani(); }); await page.waitForSelector('#ihBelProje');
      t = await sec('#icerik').textContent(); assert.match(t, /İzmir Belediyesi/); assert.match(t, /ruhsat harcı/i);
      await tasmaYok('masa'); if (shot) await page.screenshot({ path: path.join(shot, `ihale_masa_bel_${w}.png`), fullPage: true });
      await page.selectOption('#ihBelProje', 'yol'); await tik('button[onclick="ihaleAc(\'bel\')"]'); await onay();
      c = await page.evaluate(() => calls.find(x => x.ad === 'ihale_ac')); assert.equal(c.args.p_proje, 'yol'); assert.equal(c.args.p_il, 35);
      await page.evaluate(() => { PZ.ihaleSekme = 'masa'; ihaleEkrani(); }); await page.waitForSelector('#ihRuhsat');
      await page.fill('#ihRuhsat', '3.5'); await tik('button[onclick="ihaleRuhsat()"]');
      c = await page.evaluate(() => calls.find(x => x.ad === 'il_ruhsat_ayarla')); assert.equal(c.args.p_oran, 3.5);

      // bakan masası: ihale + sektör politikası
      await page.evaluate(() => { window.ihaleKim = 'ihale_bakan'; PZ.ihaleSekme = 'masa'; ihaleEkrani(); }); await page.waitForSelector('#ihBak_saglik');
      t = await sec('#icerik').textContent(); assert.match(t, /Sağlık Bakanlığı/); assert.match(t, /Sektör politikası/); assert.match(t, /Özel Hastane/);
      if (shot) await page.screenshot({ path: path.join(shot, `ihale_masa_bakan_${w}.png`), fullPage: true });
      await page.selectOption('#ihBakIl_saglik', '6'); await tik('button[onclick="ihaleAc(\'saglik\')"]'); await onay();
      c = await page.evaluate(() => calls.filter(x => x.ad === 'ihale_ac').pop()); assert.equal(c.args.p_proje, 'hastane'); assert.equal(c.args.p_il, 6);
      await page.evaluate(() => { PZ.ihaleSekme = 'masa'; ihaleEkrani(); }); await page.waitForSelector('#ihBak_saglik');
      const pol = FX.ihale_bakan.yetki.sektorler[0];
      const hedef = pol.durum === 'denetim' ? 'normal' : 'denetim';
      await tik(`button[onclick="ihalePolitika('${pol.sektor}','${hedef}')"]`); await onay();
      c = await page.evaluate(() => calls.find(x => x.ad === 'sektor_politika_ayarla')); assert.equal(c.args.p_durum, hedef);

      // giriş noktaları
      await page.evaluate(() => iskelet('Hayat', '<div class="vit-ana-izgara"></div>', {}));
      assert.equal(await sec('.vit-ana-izgara .pz-ek').count(), 2);
      await page.evaluate(() => iskelet('Şirketler', '<div class="vit-dugme"></div>', {}));
      assert.equal(await sec('.vit-dugme .pz-ek').count(), 2);
      assert.equal(await page.evaluate(() => vitSektor.ozel_okul), 'Özel Okul');

      assert.deepEqual(errors, [], `${w}px sayfa hataları`);
      await page.close();
      console.log(`  ✓ ${w}px: merkez, harita (81 il, arama), kuruluş, karar önizlemesi, enerji kaynağı, teklif, yöntem, belediye ve bakan masası, giriş noktaları`);
    }
    console.log('ekonomi_pazar_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
