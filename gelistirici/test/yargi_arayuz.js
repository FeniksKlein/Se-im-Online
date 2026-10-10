// Adliye: Yüksek Mahkeme, istinaf, AYM ekranları. Ağ yok; sahte RPC.
// NODE_PATH=/opt/npm-tools/node_modules node test/yargi_arayuz.js [klasör]   (HTML_PATH ile başka derleme)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('**/*', r => r.abort());
    await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
    await page.evaluate(() => {
      window.calls = [];
      const simdiIso = new Date(Date.now() + 3600e3).toISOString();
      window.DURUM = { ben: 'Vekil1', parti_id: 1, cb_miyim: false, hakim: 'YargicA', hakim_miyim: false,
        partiler: [{ id: 1, ad: 'Alfa Partisi', kisa: 'AAA', gb: 'Vekil1', sozcu: null, gb_miyim: true, sozcu_muyum: false }, { id: 2, ad: 'Beta Partisi', kisa: 'BBB', gb: 'Diger', sozcu: null, gb_miyim: false, sozcu_muyum: false }],
        davalar: [{ id: 7, davaci: 'Vekil1', davali: 'Davali', tur: 'hakaret', iddia: 'İddia metni burada yeterince uzun yazıldı.', delil: '', acilis: simdiIso, savunma_son: simdiIso, savunma_geldi: true, durum: 'karar', karar: 'para_10b', gerekce: 'Gerekçe', hakim: 'YargicA', karar_at: simdiIso, davalimiyim: false, davacimiyim: true }],
        aflar: [], atamalar: [] };
      window.MAHKEME = { ayar: { gorev_gun: 30, karar_saat: 72, istinaf_saat: 24, juri_saat: 48, harc: 5000, aym_gun: 10 }, salt_cogunluk: 5, azil_gerekli: 5,
        vekil_miyim: true, uye_miyim: false, cb_miyim: false, yargic_olabilir: false,
        uyeler: [{ sira: 1, kaynak: 'cb', kad: 'YargicA', gorev_bit: simdiIso, benim: false, azil: { id: 3, teklif_eden: 'Vekil2', gerekce: 'Taraflı davranıyor <b>x</b>', bit: simdiIso, kabul: 2, ret: 1, oyum: null } },
                 { sira: 2, kaynak: 'meclis', kad: 'YargicB', gorev_bit: simdiIso, benim: false, azil: null },
                 { sira: 3, kaynak: 'meclis', kad: null, adaylar: [{ kad: 'YargicC', oy: 3 }], oyum: null }],
        juri_gorevlerim: [{ dava_id: 7, bit: simdiIso, oyum: null }],
        aym: [{ id: 1, kanun_id: 9, kanun: 'Baraj Kanunu', kanun_no: 12, parti: 'AAA', basvuran: 'Vekil1', gerekce: 'Temsilde adalete aykırı', gorus: null, bas: simdiIso, karar_son: simdiIso, durum: 'acik', oy_sayi: 1, oyum: null, gorus_verebilirim: false }],
        aym_kanunlar: [{ id: 10, no: 13, baslik: 'Vergi Kanunu', tur: 'butce', sonuc_at: simdiIso }] };
      window.EK = { kesin: false, karar_son: null, istinaf_son: simdiIso, harc: 5000, harc_durum: 'yatirildi', ilk_karar: 'para_10b', heyet_sayi: 3, gerekli: 2, oy_sayi: 3, oyum: null, oy_verebilirim: false,
        oylar: [{ uye: 'YargicA', karar: 'para_10b', gerekce: 'Hakaret sabit' }, { uye: 'YargicB', karar: 'beraat', gerekce: 'Eleştiri' }, { uye: 'YargicC', karar: 'para_10b', gerekce: 'Ağır ifade' }],
        istinaf: { basvuran: 'Davali', gerekce: 'Eleştiri cezalandırılamaz', bas: simdiIso, bit: simdiIso, durum: 'acik', onay: 0, boz: 1, juri_sayi: 3, juri: null, juri_miyim: true, juri_oyum: null }, istinaf_hakkim: false };
      API = { rpc: async (ad, args) => { calls.push({ ad, args });
        if (ad === 'adliye_durum') return DURUM; if (ad === 'adliye_siyasi_bilgi') return { oneri_donemi: 1, oneriler: [], secimler: [], itirazlar: [] };
        if (ad === 'adliye_mahkeme') return MAHKEME; if (ad === 'adliye_dava_ek') return EK; if (ad === 'adliye_detay') return { beyanlar: [], yorumlar: [] };
        if (['mahkeme_meclis_oy'].includes(ad)) return { tamam: true, oy: 4, gerekli: 5, secildi: false };
        if (['mahkeme_azil_oy','adliye_juri_oy','aym_basvur','aym_oy_ver','mahkeme_azil_teklif','adliye_istinaf'].includes(ad)) return { tamam: true };
        if (ad === 'partiler') return [];
        throw new Error('Beklenmeyen RPC: ' + ad); } };
      D.durum = { profil: { il_id: 34, kad: 'Vekil1', parti: { id: 1 }, makamlar: [], cuzdan: { para: 1 } } }; D.sekme = 'adliye';
    });
    await page.evaluate(() => adliyeEkrani());
    await page.waitForSelector('text=Yüksek Mahkeme');
    const t = await page.locator('#icerik').textContent();
    assert.match(t, /3 üye · oy çokluğuyla karar/); assert.match(t, /Boş koltuk/); assert.match(t, /YargicC — 3 oy/); assert.match(t, /İstinaf jürisi görevin var/);
    assert.match(t, /Dava aç · harç 5\.000/); assert.match(t, /Anayasa Mahkemesi/); assert.match(t, /12 sayılı Baraj Kanunu/);
    assert.equal(await page.locator('#icerik b >> text=<b>x</b>').count(), 0);
    if (shot) await page.screenshot({ path: path.join(shot, 'mahkeme.png'), fullPage: false });
    await page.getByRole('button', { name: 'Görevden alınsın' }).click(); await page.waitForFunction(() => calls.some(c => c.ad === 'mahkeme_azil_oy'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'mahkeme_azil_oy').args), { p_id: 3, p_oy: 'kabul' });
    await page.waitForSelector('text=Aday için oy ver'); await page.getByRole('button', { name: 'Aday için oy ver' }).click();
    await page.fill('#adlMecAday', 'YargicC'); await page.click('#adlMecGonder'); await page.waitForFunction(() => calls.some(c => c.ad === 'mahkeme_meclis_oy'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'mahkeme_meclis_oy').args), { p_sira: 3, p_kad: 'YargicC' });
    await page.waitForSelector('text=Kanun için iptal başvurusu yap'); await page.getByRole('button', { name: 'Kanun için iptal başvurusu yap' }).click();
    await page.fill('#aymGerekce', 'Vergi kanunu mülkiyet hakkını ölçüsüz sınırlıyor.'); await page.click('#aymGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'aym_basvur'));
    assert.equal(await page.evaluate(() => calls.find(c => c.ad === 'aym_basvur').args.p_kanun), 10);
    // dava dosyası: heyet oyları, karşı oy, istinaf jürisi
    await page.evaluate(() => adliyeDosya(7)); await page.waitForSelector('text=Heyet oyları');
    const dt = await page.locator('#icerik').textContent();
    assert.match(dt, /İstinafta/); assert.match(dt, /Karşı oy/); assert.match(dt, /Harç: 5\.000/); assert.match(dt, /1 boz/);
    if (shot) await page.screenshot({ path: path.join(shot, 'dava.png') });
    await page.getByRole('button', { name: 'Kararı boz' }).click(); await page.waitForFunction(() => calls.some(c => c.ad === 'adliye_juri_oy'));
    assert.equal(await page.evaluate(() => calls.find(c => c.ad === 'adliye_juri_oy').args.p_oy), 'boz');
    // yargıç: parti davasında yalnız parti cezaları
    await page.evaluate(() => { DURUM.davalar.push({ id: 8, davaci: 'X', davali: null, davali_parti: 'Beta Partisi', tur: 'yolsuzluk', iddia: 'Parti hakkında iddia burada.', delil: '', acilis: '', savunma_son: '', durum: 'acik' }); ADL = DURUM; adlKararModal(8); });
    const sec = await page.locator('#adlCeza option').allTextContents();
    assert.deepEqual(sec, ['Beraat', 'Uyarı', 'Partiye 25.000 ₺ hazine yardımı kesintisi']);
    assert.deepEqual(errors, []);
    console.log('yargi_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
