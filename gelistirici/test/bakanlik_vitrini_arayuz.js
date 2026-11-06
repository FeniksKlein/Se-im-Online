// Bakanlık masası 2.0 görünüm testi (06.11.2026). Sahte RPC, ağ yok.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/bakanlik_vitrini_arayuz.js [ekran_klasörü]
// Denetlenenler: tek künye (makam_kurumsal ikinci künye eklemez), birimli göstergeler, sekmelerin sığması,
// Masa (işlem ızgarası, görevler, sorumluluklar, karne dökümü), İcraat (gruplar, politikalar), Etkinlik (canlı kart, çarpan),
// Bütçe (tablo, talepler, akış, defter kısaltma), İletişim; vekâlet ve ziyaretçi görünümleri; 390/320 px taşma; sayfa hatası.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2] || null;
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const ICRAATLAR = [
  { kod: 'egt_burs', ad: 'Ücretsiz öğle yemeği', etki: { memnuniyet: 0.6, issizlik: -0.1 }, hazir: null, oyuncu: [], maliyet: 4, aciklama: 'Bütün devlet okullarında öğrencilere ücretsiz öğle yemeği verilir.', sure_gun: 7, aktif_bit: null, il_gerekli: false, bekleme_saat: 168 },
  { kod: 'egt_okul', ad: 'Yeni okul binası', etki: { gelisim: 0.4 }, hazir: null, oyuncu: [], maliyet: 6, aciklama: 'Seçilen ile 24 derslikli modern okul binası yapılır.', sure_gun: null, aktif_bit: null, il_gerekli: true, bekleme_saat: 72 },
  { kod: 'egt_dijital', ad: 'Dijital eğitim seferberliği', etki: { buyume: 0.2, enflasyon: 0.05 }, hazir: null, oyuncu: [], maliyet: 30, aciklama: 'Her öğrenciye tablet, her sınıfa akıllı tahta.', sure_gun: 14, aktif_bit: null, il_gerekli: false, bekleme_saat: 336 },
  { kod: 'egt_kitap', ad: 'Ücretsiz ders kitabı', etki: { memnuniyet: 0.3 }, hazir: S(30), oyuncu: [], maliyet: 2, aciklama: 'Ders kitapları ücretsiz dağıtılır.', sure_gun: 5, aktif_bit: S(70), il_gerekli: false, bekleme_saat: 120 },
  { kod: 'egt_ogretmen', ad: 'Öğretmen ataması', etki: { issizlik: -0.2 }, hazir: S(20), oyuncu: [], maliyet: 5, aciklama: '20 bin öğretmen ataması.', sure_gun: null, aktif_bit: null, il_gerekli: false, bekleme_saat: 96 }];
const MASA = {
  kod: 'egitim', ad: 'Millî Eğitim Bakanlığı', yetki: 'bakan', simdi: S(0), bakan: { kad: 'ArvenTora', parti: { kisa: 'DHP', renk: '#2e86de' }, bas: S(-300) },
  yurutme: 'Ercan', sistem: 'baskanlik', kasa: 24.2, pay: 14, gunluk: 1.43, tavan: 100, ozet7: { gelir: 10.01, gider: 8.5 },
  dagilim30: [{ tur: 'gunluk', giris: 41.2, cikis: 0 }, { tur: 'icraat', giris: 0, cikis: 26 }, { tur: 'etkinlik', giris: 0, cikis: 3 }, { tur: 'odenek', giris: 10, cikis: 0 }, { tur: 'ziyaret', giris: 0, cikis: 1 }],
  hareketler: Array.from({ length: 12 }, (_, i) => i % 3 === 0
    ? { zaman: S(-1 - i * 9), tutar: 1.43, bakiye: 24.2 - i, tur: 'gunluk', aciklama: 'Günlük bütçe ödeneği (bütçe kanunu payı)', kim: null }
    : { zaman: S(-3 - i * 9), tutar: -(i % 2 ? 4 : 0.5), bakiye: 22 - i, tur: i % 2 ? 'icraat' : 'ziyaret', aciklama: i % 2 ? 'İcraat: Ücretsiz öğle yemeği' : 'Saha ziyareti: İzmir', kim: 'ArvenTora' }),
  icraatlar: ICRAATLAR, politikalar: [],
  gorevler: { hafta: S(-50), bitis: S(80), odul: 1, bonus: 2, liste: [
    { kod: 'icraat2', ad: 'İki icraat başlat', aciklama: 'Bu hafta bakanlığından en az iki icraat başlat.', hedef: 2, ilerleme: 2, tamam: true, alindi: false },
    { kod: 'katilim5', ad: 'Halkla buluş', aciklama: 'Bu hafta düzenlediğin etkinliklere toplam beş katılım topla.', hedef: 5, ilerleme: 2, tamam: false, alindi: false },
    { kod: 'aciklama1', ad: 'Kamuoyunu bilgilendir', aciklama: 'Bu hafta bir bakanlık açıklaması yayımla.', hedef: 1, ilerleme: 1, tamam: true, alindi: true }] },
  etkinlik_turleri: [
    { kod: 'bke_egitim_1', ad: 'Bilim Şenliği', aciklama: 'Okullar bilim projelerini halka sergiler.', maliyet: 3, sure_saat: 24, il_gerekli: true, etki: { il_memnuniyet: 1, memnuniyet: 0.2 }, kidem: 0.5, bekleme_saat: 72, hazir: null },
    { kod: 'bke_egitim_2', ad: 'Öğretmenler Haftası', aciklama: 'Ülke çapında öğretmenlere teşekkür etkinlikleri.', maliyet: 4, sure_saat: 48, il_gerekli: false, etki: { memnuniyet: 0.4 }, kidem: 0.5, bekleme_saat: 96, hazir: S(10) }],
  etkinlikler: [
    { id: 11, tur: 'bke_egitim_1', ad: 'Bilim Şenliği', il: 'Ankara', bas: S(-5), bit: S(19), durum: 'aktif', katilimci: 7, yerel: 5, sonuc: null, not: 'Bütün öğrencilerimizi ve velilerimizi bekliyoruz', aktif: true },
    { id: 9, tur: 'bke_egitim_2', ad: 'Öğretmenler Haftası', il: null, bas: S(-120), bit: S(-72), durum: 'bitti', katilimci: 12, yerel: 0, sonuc: { carpan: 2 }, not: null, aktif: false }],
  ziyaret: { maliyet: 0.5, bekleme_saat: 12, hazir: null, son: [{ il: 'İzmir', zaman: S(-30), not: 'Yeni okul inşaatını denetledik', kad: 'ArvenTora' }, { il: 'Van', zaman: S(-80), not: null, kad: 'ArvenTora' }] },
  aciklama: { bekleme_dk: 360, hazir: S(2), son: [
    { baslik: 'Okullarda ücretsiz öğle yemeği başlıyor', metin: 'Pazartesiden itibaren bütün devlet okullarında öğrencilerimize sıcak öğle yemeği verilecek. Uygulama ilk hafta 81 ilde başlayacak; veliler herhangi bir ücret ödemeyecek. Beslenme uzmanlarımızın hazırladığı menüler okul müdürlüklerine gönderildi. Bütçesi bakanlığımızın kasasından karşılanacak ve hesap defterinde herkese açık olarak izlenebilecek.', zaman: S(-4), kad: 'ArvenTora' },
    { baslik: 'Karne günü mesajı', metin: 'Bütün öğrencilerimizi kutluyorum.', zaman: S(-50), kad: 'ArvenTora' }] },
  talepler: [{ id: 4, tutar: 10, gerekce: 'Deprem bölgesindeki okulların yeniden inşası', durum: 'bekliyor', zaman: S(-3), bitis: S(69), karar_zaman: null, karar_not: null },
    { id: 2, tutar: 5, gerekce: 'Okul bakımı', durum: 'red', zaman: S(-100), bitis: S(-28), karar_zaman: S(-90), karar_not: 'Hazine sıkışık' }],
  talep_ayar: { ust: 25, sure_saat: 72, hazir: null },
  sorumluluk: { cimer_bekleyen: 2, soru_bekleyen: 1 },
  karne: { puan: 48, gorev: 0, icraat: 13, etkinlik: 1, katilim: 11, ziyaret: 1, cimer: 2, cimer_yanit: 2, soru: 0, soru_yanit: 0, harcama: 8.5, odenek: 15.5, gun: 28 }
};
const POLITIKA = [
  { kod: 'asgari', ad: 'Asgari ücret', birim: 'tl_ay', bakanlik: 'calisma', aciklama: 'Herkesin maaşının tabanı.', deger: 22104, alt: 22104, ust: 28735, bekleme_gun: 7, hazir: null },
  { kod: 'kidem_primi', ad: 'Kıdem primi', birim: 'yuzde', bakanlik: 'calisma', aciklama: 'Her statü basamağının maaşa eklediği prim.', deger: 5, alt: 0, ust: 20, bekleme_gun: 7, hazir: S(40) },
  { kod: 'destek', ad: 'Sosyal destek', birim: 'tl_gun', bakanlik: 'calisma', aciklama: 'Yeni gelenlere günlük destek.', deger: 250, alt: 0, ust: 1000, bekleme_gun: 3, hazir: null }];
const VARYANT = {
  bakan: MASA,
  vekalet: Object.assign({}, MASA, { yetki: 'vekalet', bakan: null, gorevler: null }),
  ziyaretci: Object.assign({}, MASA, { yetki: null, gorevler: null, icraatlar: ICRAATLAR, talepler: [] }),
  calisma: Object.assign({}, MASA, { kod: 'calisma', ad: 'Çalışma ve Sosyal Güvenlik Bakanlığı', politikalar: POLITIKA, kasa: 3.2, bakan: { kad: 'Selin', parti: { kisa: 'ÖP', renk: '#3E7BFA' } } })
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const sonuc = [];
  for (const W of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: W, height: 844 }, isMobile: true, deviceScaleFactor: 2, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
    const hatalar = []; page.on('pageerror', e => hatalar.push(e.message));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const ad = decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname);
      let f = path.join(KOK, ad); if (!fs.existsSync(f)) f = path.join(YEDEK, ad);
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => window.SO_BAKANLIK_MASASI_V1 && window.SO_MAKAM_KURUMSAL_V1 && typeof iskelet === 'function');
    await page.waitForTimeout(500);
    await page.evaluate((VARYANT) => {
      window.calls = []; window.VAR = 'bakan';
      const sahte = (ad, a) => {
        if (ad === 'bakanlik_masasi') return VARYANT[window.VAR];
        if (ad === 'resmi_program_panel') return { makamlar: [{ makam: 'bakan', unvan: 'Millî Eğitim Bakanı', kasa: 24.2 }], acik: [], nisanlarim: [], programlar: [] };
        if (ad === 'politika_onizle') return { gunluk: 0.4, enflasyon: 0.2 };
        if (ad === 'bakanlik_gorev_odul_al') return Object.assign({}, VARYANT.bakan, { kazanilan: 1 });
        return null;
      };
      API = { rpc: async (ad, args) => { calls.push({ ad, args }); return JSON.parse(JSON.stringify(sahte(ad, args || {}))); } };
      D.durum = { profil: { id: 'u1', il_id: 35, kad: 'ArvenTora', parti: { kisa: 'DHP', renk: '#2e86de' }, makamlar: [{ tur: 'bakan', bakanlik: 'egitim' }], cuzdan: { para: 184250 } }, okunmamis: {} };
      D.sekme = 'devlet'; D.yigin = [];
    }, VARYANT);

    const durum = () => page.evaluate(() => ({
      metin: document.getElementById('icerik')?.innerText || '',
      yatay: document.documentElement.scrollWidth > window.innerWidth + 1 || [...document.querySelectorAll('#bmMasa *')].some(el => { const r = el.getBoundingClientRect(); return r.width && r.right > window.innerWidth + 1 && !el.closest('.bmv-sekme, .bmv-filigran') && getComputedStyle(el).position !== 'fixed'; }),
      sekmeTasma: (() => { const s = document.querySelector('#bmMasa .bmv-sekme'); return s ? s.scrollWidth > s.clientWidth + 1 : false; })()
    }));
    const tamFoto = async (ad) => {
      if (!shot) return;
      fs.mkdirSync(shot, { recursive: true });
      const h = await page.evaluate(() => { const ic = document.getElementById('icerik'); return ic ? ic.scrollHeight + 160 : 844; });
      await page.setViewportSize({ width: W, height: Math.min(7000, Math.max(844, h)) }); await page.waitForTimeout(150);
      await page.screenshot({ path: path.join(shot, `${ad}_${W}.png`) });
      await page.setViewportSize({ width: W, height: 844 }); await page.waitForTimeout(80);
    };
    const ac = async (varyant, sekme) => {
      await page.evaluate(({ varyant, sekme }) => { window.VAR = varyant; D.yigin = []; return ekranAc(() => bakanlikMasasiEkrani(varyant === 'calisma' ? 'calisma' : 'egitim', sekme)); }, { varyant, sekme });
      await page.waitForTimeout(450);
    };
    const temiz = (t, yer) => assert.doesNotMatch(t, /undefined|NaN|\[object Object\]|null/, yer);

    // 1) Bakan — Masa
    await ac('bakan', 'ozet');
    let s = await durum();
    const kunye = await page.evaluate(() => ({ n: document.querySelectorAll('#bmMasa [data-dk="kunye"]').length, eski: document.querySelectorAll('#bmMasa .dk-resmi, #bmMasa .bkm-kimlik').length,
      ajanda: !!document.querySelector('#bmMasa .bmv-ajanda[data-dk-ajanda]'), sekmeler: [...document.querySelectorAll('#bmMasa .bmv-sekme button')].map(b => b.dataset.s) }));
    await page.waitForTimeout(400);
    assert.equal(await page.evaluate(() => document.querySelectorAll('#bmMasa [data-dk="kunye"]').length), 1, 'makam_kurumsal ikinci künye eklememeli');
    assert.equal(kunye.eski, 0, 'Eski künye/kimlik kartı olmamalı'); assert.ok(kunye.ajanda, 'Makam ajandası düğmesi');
    assert.deepEqual(kunye.sekmeler, ['ozet', 'icraat', 'etkinlik', 'butce', 'iletisim']);
    assert.ok(!s.sekmeTasma, 'Sekmeler sığmalı (' + W + ')'); assert.ok(!s.yatay, 'Yatay taşma (masa)');
    for (const k of ['Bakanlık kasası', '24,2', 'Tavan 100 milyar ₺', 'milyar ₺ / gün', '%14,0', '48', 'Şimdi yapabileceklerin', 'Bu haftanın görevleri', 'Sorumlulukların', 'CİMER başvuruları', 'Bakan karnesi', 'Hizmet harcaması', 'Bakanlıktan istifa et', 'Bilim Şenliği'])
      assert.ok(s.metin.includes(k), 'Masa: ' + k);
    temiz(s.metin, 'masa');
    const izgara = await page.evaluate(() => [...document.querySelectorAll('#bmMasa .bmv-eylem')].map(b => b.className.replace('bmv-eylem', '').trim() + ':' + b.innerText.replace(/\s+/g, ' ')));
    assert.equal(izgara.length, 6); assert.match(izgara[0], /^hazir:İcraat başlat 3 hazır/); assert.match(izgara[3], /^bekle:Açıklama yap/); assert.match(izgara[4], /^uyari:Ek ödenek iste Karar bekliyor/);
    await page.click('#bmMasa .bmv-eylem.bekle'); await page.waitForTimeout(150);
    assert.match(await page.evaluate(() => document.querySelector('.toast')?.textContent || document.body.innerText), /açıklaması .* yapılabilir/, 'Bekleyen işleme dokununca bilgi');
    await tamFoto('b01_masa');
    await page.click('#bmMasa .bmv-odul'); await page.waitForTimeout(250);
    assert.equal((await page.evaluate(() => calls.filter(c => c.ad === 'bakanlik_gorev_odul_al').pop())).args.p_gorev, 'icraat2');
    // görev satırına dokununca ilgili sekme
    await page.click('#bmMasa .bmv-gorev[role=button]'); await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => document.querySelector('#bmMasa .bmv-sekme button.aktif')?.dataset.s), 'etkinlik', 'Halkla buluş → Etkinlik');
    sonuc.push('masa: tek künye, 5 sekme sığıyor, ızgara durumları, görev ödülü ve yönlendirme');

    // 2) İcraat
    await page.evaluate(() => bmSekme('icraat')); await page.waitForTimeout(150);
    s = await durum(); temiz(s.metin, 'icraat'); assert.ok(!s.yatay, 'Yatay taşma (icraat)');
    const icr = await page.evaluate(() => ({ kart: document.querySelectorAll('#bmMasa .bmv-icr').length, uygula: [...document.querySelectorAll('#bmMasa .bmv-icr .bmv-btn')].map(b => b.textContent),
      bas: [...document.querySelectorAll('#bmGovde .bmv-bas h3')].map(h => h.textContent) }));
    assert.equal(icr.kart, 3); assert.deepEqual(icr.bas, ['Uygulanabilir', 'Yürürlükte', 'Bekleme süresinde']);
    assert.ok(icr.uygula.includes('Uygula · 4 milyar ₺')); assert.ok(icr.uygula.some(x => /Kasa yetmiyor/.test(x)), 'Kasa yetmeyen icraat ek ödeneğe yönlendirir');
    assert.match(s.metin, /işsizlik −0,1/); assert.match(s.metin, /7 günde bir|3 günde bir/);
    await tamFoto('b02_icraat');
    sonuc.push('icraat: uygulanabilir / yürürlükte / bekleme grupları');

    // 3) Etkinlik
    await page.evaluate(() => bmSekme('etkinlik')); await page.waitForTimeout(150);
    s = await durum(); temiz(s.metin, 'etkinlik'); assert.ok(!s.yatay, 'Yatay taşma (etkinlik)');
    assert.match(s.metin, /Sürüyor[\s\S]*Bilim Şenliği[\s\S]*×1,55[\s\S]*3 katılım daha/); assert.match(s.metin, /Geçmiş etkinlikler[\s\S]*Öğretmenler Haftası/);
    await tamFoto('b03_etkinlik');
    // 4) Bütçe
    await page.evaluate(() => bmSekme('butce')); await page.waitForTimeout(150);
    s = await durum(); temiz(s.metin, 'bütçe'); assert.ok(!s.yatay, 'Yatay taşma (bütçe)');
    const def = await page.evaluate(() => ({ gorunen: [...document.querySelectorAll('#bmMasa .bmv-defter')].filter(x => x.offsetParent).length, dugme: !!document.querySelector('#bmMasa .bmv-defter-daha') }));
    assert.equal(def.gorunen, 8); assert.ok(def.dugme);
    await tamFoto('b04_butce');
    await page.click('#bmMasa .bmv-defter-daha'); await page.waitForTimeout(100);
    assert.equal(await page.evaluate(() => [...document.querySelectorAll('#bmMasa .bmv-defter')].filter(x => x.offsetParent).length), 12);
    // 5) İletişim
    await page.evaluate(() => bmSekme('iletisim')); await page.waitForTimeout(150);
    s = await durum(); temiz(s.metin, 'iletişim'); assert.ok(!s.yatay, 'Yatay taşma (iletişim)');
    assert.match(s.metin, /Vatandaş ve Meclis[\s\S]*Bakanlık açıklamaları[\s\S]*Saha ziyaretleri[\s\S]*Van/);
    await tamFoto('b05_iletisim');
    sonuc.push('etkinlik / bütçe / iletişim sekmeleri');

    // 6) Vekâlet
    await ac('vekalet', 'ozet');
    s = await durum(); temiz(s.metin, 'vekâlet'); assert.match(s.metin, /Bakan atanmadı[\s\S]*Ercan vekâleten yönetiyor[\s\S]*Vekâleten/);
    assert.equal(await page.evaluate(() => !!document.querySelector('#bmMasa .bmv-ajanda')), false, 'Vekâlette makam ajandası yok');
    assert.equal(await page.evaluate(() => !!document.querySelector('#bmMasa .bmv-istifa')), false, 'Vekâlette istifa yok');
    assert.match(await page.evaluate(() => [...document.querySelectorAll('#bmMasa .bmv-eylem')][4].className), /kapali/);
    await tamFoto('b06_vekalet');
    // 7) Ziyaretçi
    await ac('ziyaretci', 'ozet');
    s = await durum(); temiz(s.metin, 'ziyaretçi'); assert.ok(!s.yatay, 'Yatay taşma (ziyaretçi)');
    assert.deepEqual(await page.evaluate(() => [...document.querySelectorAll('#bmMasa .bmv-sekme button')].map(b => b.dataset.s)), ['ozet', 'etkinlik', 'butce', 'iletisim']);
    assert.match(s.metin, /Kamuya açık[\s\S]*Bakan karnesi[\s\S]*Yürürlükteki icraatlar[\s\S]*Ücretsiz ders kitabı[\s\S]*Son açıklamalar[\s\S]*Bakanlığa başvur/);
    assert.doesNotMatch(s.metin, /Şimdi yapabileceklerin|Bakanlıktan istifa/);
    await tamFoto('b07_ziyaretci');
    await page.evaluate(() => bmSekme('etkinlik')); await page.waitForTimeout(150);
    assert.match((await durum()).metin, /Etkinliğe katıl, kıdem kazan/);
    sonuc.push('vekâlet ve ziyaretçi görünümleri');

    // 8) Politikalı bakanlık (Çalışma)
    await ac('calisma', 'ozet');
    s = await durum(); temiz(s.metin, 'çalışma');
    assert.match(s.metin, /Politikaların[\s\S]*22\.104 ₺\/ay[\s\S]*%5,0[\s\S]*250 ₺\/gün/);
    assert.ok(!(await durum()).sekmeTasma, 'Uzun adlı bakanlıkta sekmeler sığmalı');
    await tamFoto('b08_calisma');
    await page.click('#bmMasa .bmv-pol-ozet'); await page.waitForTimeout(250);
    const pol = await page.evaluate(() => ({ s: document.querySelector('#bmMasa .bmv-sekme button.aktif')?.dataset.s, n: document.querySelectorAll('#bmMasa [data-pol]').length }));
    assert.equal(pol.s, 'icraat'); assert.equal(pol.n, 3);
    await page.fill('#bmMasa [data-pol="asgari"] input', '24000'); await page.waitForTimeout(500);
    assert.match(await page.evaluate(() => document.querySelector('#bmMasa [data-pol="asgari"] .pol-etki').textContent), /Bütçeye etkisi/);
    s = await durum(); assert.ok(!s.yatay, 'Yatay taşma (politika)');
    await tamFoto('b09_politika');
    sonuc.push('politikalar: masa özeti ve İcraat sekmesinde düzenleme');

    assert.deepEqual(hatalar, [], 'Sayfa hatası: ' + hatalar.join(' | '));
    await page.close();
  }
  await browser.close();
  console.log('TAMAM\n- ' + sonuc.join('\n- '));
})().catch(e => { console.error('HATA:', e.message); process.exit(1); });
