// Merkez Bankası, belediye tahvilleri, SPK, konkordato ekranları. Ağ yok; sahte RPC.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/ekonomi_kurumlar_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
for (const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
const shot = process.argv[2];
const simdi = Date.now(), saat = (h) => new Date(simdi + h * 3600e3).toISOString();
const FX = {
  mb: { baskan: { id: 'b1', kad: 'Ekonomist', atama: saat(-30) }, politika_faiz: 45.5, tcmb_karari: true, enflasyon: 33.79, buyume: 5.1, reel_faiz: 11.71,
    oranlar: { politika: 45.5, vadeli30: 3.74, kredi: 6.07 }, sonraki_karar: saat(100), ben_baskan: true, ben_atayabilir: true, yurutme_unvan: 'Cumhurbaşkanı',
    bekleyen_teklifim: { id: 7, teklif_eden: 'Reis', zaman: saat(-1) },
    kararlar: [{ zaman: saat(-60), baskan: 'Ekonomist', onceki: 45.8, yeni: 45.5, enflasyon: 33.8, gerekce: 'Enflasyon beklentileri <b>iyileşiyor</b>' }],
    kural: 'PPK haftada bir toplanır.' },
  tahvil: { politika_faiz: 45.5, kural: 'Satış 48 saat sürer.',
    belediyem: { il_id: 35, il: 'İzmir', tavan: 178008, acik_stok: 50000, max_yillik_faiz: 70.5 },
    tahviller: [
      { id: 1, il_id: 35, il: 'İzmir', ihrac_eden: 'Baskan', hedef: 150000, toplanan: 90000, faiz: 3, yillik: 36.5, vade_gun: 30, satis_bit: saat(20), vade: null, durum: 'satista', odenen: null, payim: null },
      { id: 2, il_id: 6, il: 'Ankara', ihrac_eden: 'Mansur', hedef: 100000, toplanan: 100000, faiz: 2, yillik: 24.3, vade_gun: 30, satis_bit: saat(-30), vade: saat(400), durum: 'tutuluyor', odenen: null, payim: 20000 },
      { id: 3, il_id: 34, il: 'İstanbul', ihrac_eden: 'Ekrem', hedef: 120000, toplanan: 120000, faiz: 4, yillik: 48.7, vade_gun: 30, satis_bit: saat(-800), vade: saat(-2), durum: 'temerrut', odenen: 62400, payim: null }] },
  spk: { yetkili: true, yasagim: saat(48), kural: 'Bağlantılı hesaplar incelenir.', sirketler: [{ id: 3, ad: 'Patron Holding' }],
    incelemeler: [
      { id: 1, sirket: 'Patron Holding', sirket_id: 3, taraf1: 'Ali', taraf2: 'Veli', tur: 'bagli_hesap', tur_ad: 'Bağlantılı hesaplar arası işlem', tutar: '20000', iddia: null, acan: 'Otomatik gözetim', taraf_benim: false, bas: saat(-3), bit: saat(69), durum: 'acik', ceza: null, karar_not: null },
      { id: 2, sirket: 'Patron Holding', sirket_id: 3, taraf1: 'Can', taraf2: null, tur: 'manipulasyon', tur_ad: 'Manipülasyon iddiası', tutar: '90000', iddia: 'Kapanışa doğru fiyat şişirildi', acan: 'Maliyeci', taraf_benim: false, bas: saat(-100), bit: saat(-28), durum: 'ceza', ceza: 18000, karar_not: 'Ceza' }] },
  konk: { kural: '14 gün içinde kurtulmazsa iflas.',
    riskli: [{ id: 9, ad: 'Batık Ticaret', kasa: -50000, sermaye: 200000, surecte: false, otomatik_esik: -100000 }],
    surecler: [{ id: 1, sirket_id: 8, sirket: 'Iflas AŞ', bas: saat(-100), bit: saat(236), durum: 'surec', kasa: -150000, baslangic_kasa: -150000, sonuc_zaman: null },
               { id: 2, sirket_id: 7, sirket: 'Eski Ticaret', bas: saat(-500), bit: saat(-164), durum: 'iflas', kasa: -90000, baslangic_kasa: -90000, sonuc_zaman: saat(-164) }] },
  rapor: { endeks: 1, enflasyon: 33.8, buyume: 5.1, benim_gecim: null, benim_il_ad: 'İzmir', kurumlar_7g: 0, ruhsat_7g: 0, borsa: { sirket: 1, deger: 1 }, ihale: { acik: 0, yapim: 0 }, sektorler: [], eski_sayi: 0 }
};
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    for (const w of [320, 390, 768]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: w < 700, locale: 'tr-TR' });
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      await page.route('**/*', r => r.abort());
      await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
      await page.evaluate((FX) => {
        window.calls = [];
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          const t = { merkez_bankasi: FX.mb, belediye_tahviller: FX.tahvil, belediye_tahvilleri: FX.tahvil, spk_ekrani: FX.spk, konkordato_ekrani: FX.konk, piyasa_raporu: FX.rapor }[ad];
          if (t) return t;
          if (['ppk_faiz_karari', 'tcmb_baskan_ata', 'tcmb_teklif_yanit', 'tcmb_baskan_gorevden_al'].includes(ad)) return FX.mb;
          if (['belediye_tahvil_ihrac', 'belediye_tahvil_al'].includes(ad)) return FX.tahvil;
          if (['spk_inceleme_ac', 'spk_karar'].includes(ad)) return FX.spk;
          if (ad === 'sirket_konkordato_ilan') return [];
          throw new Error('Beklenmeyen RPC: ' + ad);
        } };
        D.durum = { profil: { il_id: 35, kad: 'Burak', parti: null, makamlar: [], cuzdan: { para: 5000000 } } };
      }, FX);
      const sec = (s) => page.locator(s);
      const onay = async () => { await page.waitForSelector('#evet'); await page.click('#evet'); await page.waitForTimeout(100); };
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`), fullPage: true }); };
      const son = async (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);

      // Ekonomi merkezinde dört yeni giriş
      await page.evaluate(() => ekranAc(ekonomiMerkeziEkrani)); await page.waitForSelector('.ek-ek');
      assert.equal(await sec('.br-git .ek-ek').count(), 4);
      await tasmaYok('merkez');

      // Merkez Bankası
      await sec('.br-git .ek-ek').first().click(); await page.waitForSelector('.ek-faiz');
      let t = await sec('#icerik').textContent();
      assert.match(t, /Sana görev teklifi var/); assert.match(t, /Para Politikası Kurulu kararı/); assert.match(t, /Başkan ata/); assert.match(t, /Geçmiş kararlar/);
      assert.equal(await sec('#icerik b:has-text("iyileşiyor")').count(), 0, 'gerekçe kaçışlanmalı');
      await tasmaYok('tcmb'); await foto('tcmb');
      await sec('#ekFaiz').fill('47.25'); await sec('#ekGerekce').fill('Kur baskısı'); await page.click('button:has-text("Kararı açıkla")'); await onay();
      assert.deepEqual((await son('ppk_faiz_karari')).args, { p_faiz: 47.25, p_gerekce: 'Kur baskısı' });
      await page.click('button:has-text("Görevi kabul et")'); await onay();
      assert.deepEqual((await son('tcmb_teklif_yanit')).args, { p_teklif: 7, p_kabul: true });
      await sec('#ekTcmbAday').fill('Yeni Aday'); await page.click('button:has-text("Teklif gönder")'); await page.waitForTimeout(100);
      assert.deepEqual((await son('tcmb_baskan_ata')).args, { p_kad: 'Yeni Aday' });

      // Belediye tahvilleri
      await page.evaluate(() => ekranAc(belediyeTahvilEkrani)); await page.waitForSelector('#ekThHedef');
      t = await sec('#icerik').textContent();
      assert.match(t, /İzmir Belediyesi adına tahvil çıkar/); assert.match(t, /Tahvillerim/); assert.match(t, /Temerrüt/); assert.match(t, /Satıştaki tahviller/);
      await page.click('#ekThVade button[data-g="60"]');
      await sec('#ekThHedef').fill('150000'); await sec('#ekThFaiz').fill('6.5');
      assert.match(await sec('#ekThOzet').textContent(), /159\.750/);
      await tasmaYok('tahvil'); await foto('tahvil');
      await page.click('button:has-text("Tahvili ihraç et")'); await onay();
      assert.deepEqual((await son('belediye_tahvil_ihrac')).args, { p_hedef: 150000, p_faiz: 6.5, p_vade_gun: 60 });
      await page.waitForSelector('button:has-text("Tahvil al")');
      await page.click('button:has-text("Tahvil al")'); await page.waitForSelector('#ekTaTutar');
      await sec('#ekTaTutar').fill('25000'); await page.click('#ekTaBtn'); await page.waitForTimeout(150);
      assert.deepEqual((await son('belediye_tahvil_al')).args, { p_tahvil: 1, p_tutar: 25000 });

      // SPK
      await page.evaluate(() => ekranAc(spkEkrani)); await page.waitForSelector('#ekSpkKad');
      t = await sec('#icerik').textContent();
      assert.match(t, /Borsa işlem yasağın/); assert.match(t, /Bağlantılı hesaplar arası işlem/); assert.match(t, /Ali ↔ Veli/);
      await tasmaYok('spk'); await foto('spk');
      await sec('#ekSpkKad').fill('Can'); await sec('#ekSpkIddia').fill('Fiyat şişirme'); await page.click('button:has-text("İncelemeyi başlat")'); await onay();
      assert.deepEqual((await son('spk_inceleme_ac')).args, { p_sirket: 3, p_kad: 'Can', p_aciklama: 'Fiyat şişirme' });
      await page.click('button:has-text("Ceza ver")'); await onay();
      assert.deepEqual((await son('spk_karar')).args, { p_id: 1, p_ceza: true, p_not: null });

      // Konkordato
      await page.evaluate(() => ekranAc(konkordatoEkrani)); await page.waitForSelector('text=Zor durumdaki şirketlerim');
      t = await sec('#icerik').textContent();
      assert.match(t, /Batık Ticaret/); assert.match(t, /Iflas AŞ/); assert.match(t, /İflas/);
      await tasmaYok('konkordato'); await foto('konkordato');
      await page.click('button:has-text("Konkordato ilan et")'); await onay();
      assert.deepEqual((await son('sirket_konkordato_ilan')).args, { p_sirket: 9 });

      assert.deepEqual(errors, [], `${w}px sayfa hataları: ${errors.join(' | ')}`);
      await page.close();
      console.log(`  ✓ ${w}px: dört ekran, girişler ve tüm işlemler`);
    }
    console.log('TAMAM: ekonomi kurumları arayüzü');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
