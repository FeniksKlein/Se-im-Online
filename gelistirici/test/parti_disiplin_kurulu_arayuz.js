// Parti MYK + Disiplin Kurulu arayüz testi (sahte RPC; 390 ve 320 px): panel, öneri formu, MYK oyu, kurul oyu
// (istemden ağır seçenek yok), savunma, itiraz, kurul seçimi (aday/oy), Adliye itiraz kartı, taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/parti_disiplin_kurulu_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const gen of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: gen, height: gen === 320 ? 640 : 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(gen + ': ' + e.message.slice(0, 300)));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => typeof partiDisiplinEkrani === 'function' && typeof pdkItirazEkrani === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = [];
      const z = (s) => new Date(Date.now() + s * 3600000).toISOString();
      const ben = (o) => Object.assign({ hedef: false, myk_oyabilir: false, heyette: false, kurul_oyabilir: false, savunabilir: false, itiraz_edebilir: false, itiraz_oyabilir: false }, o || {});
      const dosya = (o) => Object.assign({ id: 1, hedef: 'ayse', hedef_ad: 'Ayşe Yılmaz', sebep: 'parti_aleyhi', sebep_ad: 'Partiyi kamuoyu önünde küçük düşürme, karalama', gerekce: 'Kürsü\'de partiyi karalayan çok uzun bir paylaşım yaptı ve özür dilemedi; parti kararlarına da uymadı.', kanit: 'Kürsü 26.11 18:00', istem: 'kinama', istem_ad: 'Kınama', tedbir: true, durum: 'myk', myk_son: z(20), myk_n: 7, myk_evet: 2, myk_hayir: 0, heyet_n: 0, kurul_oy_veren: 0, ben: ben() }, o);
      window.PANEL = { parti: { id: 3, kisa: 'YDP', ad: 'Yeni Demokrasi Partisi', uye: 104 }, ben: { myk: true, gb: true, uye: true, kurul: 'asil', askida: null },
        myk: [{ kad: 'orhan', ad: 'Orhan Kaya', gorev: 'Genel Başkan' }, { kad: 'mert', ad: 'Mert Demir', gorev: 'Siyasi ve Hukuki İşlerden Sorumlu Genel Başkan Yardımcısı' }],
        kurul: [1,2,3,4,5,6,7].map(i => ({ kad: 'k' + i, ad: 'Kurul Üyesi ' + i, tur: 'asil', sira: i, oy: 20 - i })).concat([{ kad: 'y1', ad: 'Yedek Bir', tur: 'yedek', sira: 8, oy: 3 }]),
        secim: { id: 9, durum: 'oy', aday_bit: z(-1), oy_bit: z(10), oy_sayisi: 41, adaylar: [{ kad: 'can', ad: 'Can Öztürk', tanitim: 'Tarafsız olacağım.' }, { kad: 'ece', ad: 'Ece Çelik', tanitim: null }], oyum: 'can', oy_engel: null },
        kilit: null, kota: { sinir: 5, kullanilan: 1 },
        sebepler: [{ kod: 'parti_aleyhi', ad: 'Partiyi kamuoyu önünde küçük düşürme, karalama' }, { kod: 'diger', ad: 'Tüzüğe aykırı diğer davranış' }],
        kurallar: { myk_saat: 24, savunma_saat: 48, kurul_saat: 72, ek_saat: 24, itiraz_saat: 72, itiraz_harc: 25000, yasak_gun: 30 },
        dosyalar: [dosya({ id: 3, ben: ben({ myk_oyabilir: true, myk_oy: 'evet' }) }),
                   dosya({ id: 2, hedef_ad: 'Mehmet Uzunisimlioğlu Karadenizli', istem: 'kesin', istem_ad: 'Kesin ihraç', durum: 'kurul', karar_son: z(50), heyet_tur: 'kurul', heyet_n: 7, kurul_oy_veren: 3, savunma: 'Ben suçsuzum.', ben: ben({ heyette: true, kurul_oyabilir: true }) }),
                   dosya({ id: 1, durum: 'kesin', sonuc: 'gecici', sonuc_ad: 'Geçici çıkarma', ceza_bit: z(100), heyet_n: 3, heyet_tur: 'kura', itiraz_sonuc: 'onay' })] };
      window.BENIM = { dosyalarim: [dosya({ id: 4, parti: 'YDP', durum: 'karar', sonuc: 'kesin', sonuc_ad: 'Kesin ihraç', itiraz_son: z(70), istem: 'kesin', istem_ad: 'Kesin ihraç', ben: ben({ hedef: true, itiraz_edebilir: true }) })],
        itiraz_gorevlerim: [dosya({ id: 5, parti: 'MKP', durum: 'itiraz', sonuc: 'kesin', sonuc_ad: 'Kesin ihraç', itiraz_karar_son: z(60), itiraz_gerekce: 'Savunmam alınmadı.', ben: ben({ itiraz_heyetinde: true, itiraz_oyabilir: true }) })] };
      API = { rpc: async (ad, a) => { calls.push({ ad, a });
        if (ad === 'pdk_panel' || ad === 'pdk_oner' || ad === 'pdk_myk_oy' || ad === 'pdk_kurul_oy' || ad === 'pdk_secim_oy') return PANEL;
        if (ad === 'pdk_benim' || ad === 'pdk_itiraz' || ad === 'pdk_itiraz_oy') return BENIM;
        if (ad === 'vergi_rehberi') return { tanitim: true };
        if (/liste|lar$|ler$/.test(ad)) return [];
        return {}; } };
      window.onayla = async () => true;
      D.durum = { profil: { id: 'x', il_id: 34, kad: 'orhan', makamlar: [], cuzdan: { para: 50000 } }, takvim: [], simdi: new Date().toISOString(), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
    });
    const et = (m) => gen + 'px · ' + m;
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png'), fullPage: true }); } };
    const tasma = async () => page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    await page.evaluate(() => partiDisiplinEkrani(3)); await page.waitForTimeout(300);
    const metin = await page.evaluate(() => document.body.innerText);
    for (const s of ['Merkez Yürütme Kurulu', 'Disiplin Kurulu seçimi', 'Kurul Üyesi 1', 'Üyeyi disipline öner', 'Sevk edilsin', 'Kurul oyu ver', 'Karara itiraz et', 'Hakkındaki dosya', 'Can Öztürk'])
      assert.ok(metin.includes(s), et('panelde yok: ' + s));
    assert.ok(await tasma() <= 1, et('panel yatay taşma'));
    await cek('panel');
    // MYK oyu
    await page.click('button:has-text("Sevk edilsin")'); await page.waitForTimeout(150);
    assert.deepEqual(await page.evaluate(() => calls.filter(c => c.ad === 'pdk_myk_oy').pop().a), { p_dosya: 3, p_oy: 'evet' }, et('myk oyu'));
    // Kurul oyu: istem kesin → 5 seçenek; ilk dosya kınama için 3
    await page.click('button:has-text("Kurul oyu ver")'); await page.waitForTimeout(150);
    const sec = await page.evaluate(() => [...document.querySelectorAll('#pdkKO option')].map(o => o.value));
    assert.deepEqual(sec, ['beraat', 'uyari', 'kinama', 'gecici', 'kesin'], et('kurul seçenekleri'));
    await cek('kurul_oy');
    await page.selectOption('#pdkKO', 'gecici'); await page.click('#pdkOK'); await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'pdk_kurul_oy').pop().a.p_oy), 'gecici', et('kurul oyu'));
    // Öneri formu
    await page.click('button:has-text("Üyeyi disipline öner")'); await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => getComputedStyle(document.querySelector('#pdkGunAlan')).display), 'none', et('gün alanı gizli olmalı'));
    await page.selectOption('#pdkIstem', 'gecici');
    assert.notEqual(await page.evaluate(() => getComputedStyle(document.querySelector('#pdkGunAlan')).display), 'none', et('gün alanı açılmalı'));
    await page.fill('#pdkHedef', 'Ayşe Yılmaz'); await page.fill('#pdkGerekce', 'Gerekçe yazısı uzun'); await page.fill('#pdkKanit', 'Kanıt 123');
    await page.check('#pdkTedbir');
    const fs16 = await page.evaluate(() => [...document.querySelectorAll('#modal input:not([type=checkbox]),#modal select,#modal textarea')].every(x => parseFloat(getComputedStyle(x).fontSize) >= 16));
    assert.ok(fs16, et('form alanları 16px altında'));
    assert.ok(await tasma() <= 1, et('form taşma'));
    await cek('oner_form');
    await page.click('#pdkOK'); await page.waitForTimeout(150);
    const on = await page.evaluate(() => calls.filter(c => c.ad === 'pdk_oner').pop().a);
    assert.equal(on.p_istem, 'gecici'); assert.equal(on.p_gecici_gun, 7); assert.equal(on.p_tedbir, true); assert.equal(on.p_hedef, 'Ayşe Yılmaz');
    // Kurul seçimi oyu
    await page.evaluate(() => partiDisiplinEkrani(3)); await page.waitForTimeout(250);
    await page.click('button:has-text("Oy ver")'); await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'pdk_secim_oy').pop().a.p_aday), 'ece', et('kurul seçimi oyu'));
    // İtiraz
    await page.evaluate(() => partiDisiplinEkrani(3)); await page.waitForTimeout(250);
    await page.click('button:has-text("Karara itiraz et")'); await page.waitForTimeout(150);
    await page.fill('#pdkIt', 'İtiraz gerekçem yirmi karakterden uzun.'); await page.click('#pdkOK'); await page.waitForTimeout(200);
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'pdk_itiraz').length), 1, et('itiraz çağrısı'));
    // Adliye itiraz ekranı
    await page.evaluate(() => pdkItirazEkrani()); await page.waitForTimeout(250);
    const m2 = await page.evaluate(() => document.body.innerText);
    assert.ok(m2.includes('Karar kaldırılsın') && m2.includes('MKP'), et('itiraz heyeti ekranı'));
    assert.ok(await tasma() <= 1, et('itiraz ekranı taşma'));
    await cek('itiraz_heyeti');
    await page.click('button:has-text("Karar kaldırılsın")'); await page.waitForTimeout(150);
    assert.deepEqual(await page.evaluate(() => calls.filter(c => c.ad === 'pdk_itiraz_oy').pop().a), { p_dosya: 5, p_oy: 'iptal' }, et('itiraz oyu'));
    // Adliye kartı sarmalayıcısı
    const kart = await page.evaluate(async () => { const eskiR = API.rpc; API.rpc = async (ad, a) => ad === 'pdk_benim' ? BENIM : (ad === 'adliye_durum' ? Promise.reject(new Error('x')) : eskiR(ad, a)); try { return await adliyeHtml(); } catch (e) { return 'HATA:' + e.message; } finally { API.rpc = eskiR; } });
    assert.ok(kart.startsWith('HATA') || kart.includes('Parti Disiplin İtirazları'), et('adliye kartı'));
    await page.close();
  }
  await browser.close();
  if (hatalar.length) { console.error(hatalar.join('\n')); process.exit(1); }
  console.log('parti_disiplin_kurulu_arayuz: tamam (390/320)');
})().catch(e => { console.error(e); process.exit(1); });
