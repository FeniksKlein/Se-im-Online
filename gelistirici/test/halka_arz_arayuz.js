// Halka arz arayüzü (SPK başvurusu, talep toplama, eşit dağıtım bilgisi). Ağ yok; sahte RPC.
// Yayındaki docs/index.html + docs/*.js birlikte yüklenir.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/halka_arz_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const kok = path.join(__dirname, '../..');
let html = fs.readFileSync(path.join(kok, 'docs/index.html'), 'utf8');
html = html.replace(/<script src="https:[^"]+"><\/script>/g, '');
html = html.replace(/<script src="([^":]+?)(\?[^"]*)?"><\/script>/g, (m, dosya) => {
  const p = path.join(kok, 'docs', dosya);
  return fs.existsSync(p) ? '<script>' + fs.readFileSync(p, 'utf8') + '</script>' : '';
});
const shot = process.argv[2];
const simdi = Date.now(), saat = h => new Date(simdi + h * 3600e3).toISOString();
const kural = { spk_saat: 3, kilit_gun: 7, soguma_tamam_gun: 3, soguma_iptal_saat: 24, min_faaliyet_gun: 3, ilk_arz_min_pay: 10, en_cok_pay: 49,
  en_az_talep: 1000, en_az_buyukluk: 10000, spk_ucret: 0.2, borsa_ucret: 0.1, araci_komisyon: 1.5, masraf_toplam: 1.8 };
const arzTalep = { id: 70, sirket_id: 17, sirket: 'Onur Marketleri', sektor: 'market', baslatan: 'onur', ben_baslattim: false, durum: 'acik', asama: 'talep',
  deger: 3825406, hedef: 300000, asgari: 75000, toplanan: 420000, yatirimci: 3, bas: saat(-5), bit: saat(20), spk_bit: saat(-2), talep_bas: saat(-2),
  ortak_satis: 100000, yeni_pay_tutari: 200000, fon_kullanim: 'İzmir ve Manisa\'da yeni mağazalar', satilan_pay_hedef: 7.47, arz_fiyati: 40254.06, pay_fiyati_1: 41254.06,
  talep_toplam: 420000, katilim_kat: 1.4, ort_net_simdi: 41000, ort_net_hedef: 45000, talebim: 50000, tahmini_tahsisim: 50000,
  ortaklar: [{ kad: 'onur', pay: 83.26 }, { kad: 'yatirimci1', pay: 16.74 }] };
const arzSpk = { ...arzTalep, id: 71, sirket_id: 10, sirket: 'İstanbul Enerji Santrali', asama: 'spk', toplanan: 0, yatirimci: 0, talebim: 0, tahmini_tahsisim: 0, spk_bit: saat(2.5), bit: saat(26.5) };
const durum = { id: 10, ad: 'İstanbul Enerji Santrali', sektor: 'enerji', sermaye: 500000, kasa: 185951, halka_acik: false, tur_hukuki: 'as', as_mi: true,
  kurulus: saat(-260), payim: 100, kar_kasada: false, asgari_ucret: 30000, ort_net: 69725, deger_en_az: 500000, deger_en_cok: 3625752, deger_onerilen: 1812876,
  en_fazla_tutar: 3483565, ilk_arz: true, min_pay: 10, kural, soguma_bit: null, soguma_neden: null, kilit_bit: null, acik: null,
  gecmis: [{ id: 3, durum: 'iptal', bas: saat(-80), sonuc_zaman: saat(-79), toplanan: 0, aciklama: 'Şirket tarafından iptal edildi' }] };

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    for (const w of [320, 390, 768]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: w < 700, locale: 'tr-TR' });
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      page.on('dialog', d => d.accept());
      await page.route('**/*', r => r.abort());
      await page.setContent(html, { waitUntil: 'domcontentloaded' });
      await page.evaluate(({ durum, arzTalep, arzSpk, kural }) => {
        window.calls = []; window.FX = { durum, arzTalep, arzSpk, kural };
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'halka_arz_durum') return FX.durumOverride || FX.durum;
          if (ad === 'halka_arz_liste') return { acik: [FX.arzTalep, FX.arzSpk], son: [{ ...FX.arzTalep, id: 60, durum: 'tamam', sonuc_zaman: new Date().toISOString(), satilan: 86500, aciklama: '3 yatırımcı, 86.500 ₺ talep (0,36 kat), 86.500 ₺ satış; satılan pay %1,87' }],
            katildiklarim: [{ ...FX.arzTalep, id: 61, durum: 'tamam', sonuc_zaman: new Date().toISOString(), talebim: 300000, tahsisim: 120000, iadem: 180000, arz_payim: 2.95 }], kural: FX.kural, cuzdan: 1234681 };
          if (ad === 'halka_arz_hesapla') return { ort_net_simdi: 69725, ort_net_sonra: 82000 };
          if (ad === 'halka_arz_basvur') return { ...FX.arzSpk };
          if (ad === 'halka_arz_talep') return { ...FX.arzTalep, talebim: FX.arzTalep.talebim + args.p_tutar };
          return {};
        } };
        D.durum = { simdi: new Date().toISOString(), profil: { il_id: 34, kad: 'ArvenTora', parti: null, makamlar: [], cuzdan: { para: 1250000 } } };
      }, { durum, arzTalep, arzSpk, kural });
      const sec = (s) => page.locator(s);
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`), fullPage: true }); };
      const son = async (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);

      // 1) Halka arzlar listesi (menüden açılan ekran)
      await page.evaluate(() => ekranAc(halkaArzPazarEkrani));
      await page.waitForSelector('#icerik .kart');
      let t = await sec('#icerik').textContent();
      assert.match(t, /Talep toplayanlar/); assert.match(t, /SPK incelemesindekiler/); assert.match(t, /eşit dağıtım yapılacak/);
      assert.match(t, /Katıldığım halka arzlar/); assert.match(t, /120\.000 ₺ tahsis/); assert.match(t, /Fon kullanım yeri/);
      assert.equal(await sec('#ha_talep_70').count(), 1, 'talep kutusu');
      assert.equal(await sec('#ha_talep_71').count(), 0, 'SPK aşamasında talep kutusu olmamalı');
      await tasmaYok('liste'); await foto('ha_liste');

      // Talep artırma: en fazla büyüklük - mevcut talep
      assert.equal(await sec('#ha_talep_70').getAttribute('max'), '250000');
      await sec('#ha_talep_70').fill('20000');
      await sec('#ha_talep_70').dispatchEvent('input');
      assert.match(await sec('#ha_talep_ozet_70').textContent(), /eşit dağıtım/);
      await sec('#ha_talep_btn_70').click();
      await page.waitForFunction(() => calls.some(c => c.ad === 'halka_arz_talep'));
      assert.deepEqual((await son('halka_arz_talep')).args, { p_arz: 70, p_tutar: 20000 });

      // 2) Şirket sahibi: SPK başvuru formu
      await page.evaluate(() => halkaArzEkrani(10));
      await page.waitForSelector('#ha_deger');
      t = await sec('#icerik').textContent();
      assert.match(t, /Halka arz süreci/); assert.match(t, /SPK incelemesi/); assert.match(t, /İzahname ve SPK başvurusu/);
      await page.waitForFunction(() => /Haftalık net kâr tahmini/.test((document.getElementById('ha_kar') || {}).textContent || ''));
      assert.equal(await sec('#ha_baslat').isDisabled(), false, 'varsayılan değerlerle başvuru açık olmalı');
      // %10 altı satış: buton kapanır
      await sec('#ha_tutar').fill('20000'); await sec('#ha_tutar').dispatchEvent('input');
      assert.match(await sec('#ha_sonuc').textContent(), /asgari halka açıklık %10/);
      assert.equal(await sec('#ha_baslat').isDisabled(), true);
      // Sermaye artırımı + ortak satışı
      await sec('#ha_tutar').fill('400000'); await sec('#ha_tutar').dispatchEvent('input');
      await sec('#ha_ortak').fill('100000'); await sec('#ha_ortak').dispatchEvent('input');
      await sec('#ha_fon').fill('Yeni güneş santrali');
      t = await sec('#ha_sonuc').textContent();
      assert.match(t, /500\.000 ₺/); assert.match(t, /Cüzdanına net giriş/); assert.match(t, /Şirkete net giriş/);
      await tasmaYok('basvuru'); await foto('ha_basvuru');
      await sec('#ha_baslat').click();
      await page.waitForFunction(() => calls.some(c => c.ad === 'halka_arz_basvur'));
      const b = (await son('halka_arz_basvur')).args;
      assert.equal(b.p_sirket, 10); assert.equal(b.p_hedef, 500000); assert.equal(b.p_ortak_satis, 100000);
      assert.equal(b.p_deger, 1812876); assert.equal(b.p_asgari, 250000); assert.equal(b.p_saat, 72); assert.equal(b.p_fon_kullanim, 'Yeni güneş santrali');

      // 3) SPK incelemesindeki kendi arzı
      await page.evaluate(() => { FX.durumOverride = { ...FX.durum, acik: { ...FX.arzSpk, ben_baslattim: true } }; halkaArzEkrani(10); });
      await page.waitForSelector('#icerik .kart');
      t = await sec('#icerik').textContent();
      assert.match(t, /SPK incelemesinde/); assert.match(t, /Halka arzı iptal et/);
      assert.equal(await sec('#ha_deger').count(), 0, 'süren arz varken yeni başvuru formu olmamalı');
      await tasmaYok('spk'); await foto('ha_spk');

      // 4) Ltd. şirket: önce A.Ş. yönlendirmesi; bekleme süresi
      await page.evaluate(() => { FX.durumOverride = { ...FX.durum, as_mi: false, tur_hukuki: 'ltd' }; halkaArzEkrani(10); });
      await page.waitForSelector('#icerik .kart');
      assert.match(await sec('#icerik').textContent(), /Önce anonim şirket ol/);
      await page.evaluate(() => { FX.durumOverride = { ...FX.durum, soguma_bit: new Date(Date.now() + 5 * 3600e3).toISOString(), soguma_neden: 'İptal edilen ya da gerçekleşmeyen başvurudan sonra yeni başvuru için 24 saat beklenir.' }; halkaArzEkrani(10); });
      await page.waitForSelector('#icerik .kart');
      assert.match(await sec('#icerik').textContent(), /24 saat beklenir/);

      assert.deepEqual(errors, [], 'sayfa hatası: ' + errors.join(' | '));
      await page.close();
      console.log(`ok ${w}px`);
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
