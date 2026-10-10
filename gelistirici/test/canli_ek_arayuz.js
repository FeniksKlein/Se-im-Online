// Canlı sayım paneli, fırsatlar, akış, rapor/başarım ekranları. Ağ yok; sahte RPC.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/canli_ek_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const html = fs.readFileSync(path.join(__dirname, '../dist/index.html'), 'utf8');
for (const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('**/*', r => r.abort());
    await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
    await page.evaluate(() => {
      window.calls = []; window.zaman = 0;
      const bitis = new Date(Date.now() + 400000).toISOString();
      const detay = () => ({ id: 5, tur: 'mv', asama: 'bitti', oy_bas: bitis, oy_bit: bitis, sonuc_at: bitis, katilim: 130, benim_il: 34,
        gece: { aktif: true, var: true, tur: 'mv', acilan_il: 2 + zaman, toplam_il: 4, yuzde: 23.1 + zaman * 30, onde: 'ABC %41,2', saniye_kaldi: 400, bitis, sure_sn: 720, gecen_sn: 320,
          son_acilan: [{ il_id: 35, ad: 'İzmir', onde: 'ABC' }, { il_id: 16, ad: '<b>Bursa</b>', onde: 'XYZ' }] },
        sonuc: { toplam: 30, dolu: 2, bos: 0, baraj: 7, ulusal: [], iller: zaman ? { 34: { mv: 1, gecerli: 10, partiler: {}, secilen: [], bagimsizlar: [] } } : {}, bagimsiz_sandalye: 0 } });
      window.AKIS_VERI = [{ id: 9, kad: 'Ada', unvan: 'ABC Genel Başkanı', parti: { id: 1, ad: 'A', kisa: 'ABC', renk: '#123456', amblem: 'a_yildiz' }, il: 'İzmir', metin: '<img src=x onerror="window.xss=1"> Bugün #SeçimGecesi çok heyecanlı', zaman: new Date().toISOString(), begeni: 2, begendim: false, benim: false },
        { id: 8, kad: 'Deniz', unvan: null, parti: null, il: 'Ankara', metin: 'Benim paylaşımım', zaman: new Date().toISOString(), begeni: 0, begendim: false, benim: true }];
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args });
        if (ad === 'secim_detay') return detay();
        if (ad === 'akis_liste') return AKIS_VERI;
        if (ad === 'akis_gundem') return [{ etiket: 'seçimgecesi', kisi: 4, paylasim: 5 }];
        if (ad === 'akis_yaz') return { tamam: true, id: 10 };
        if (ad === 'akis_begen') return { begeni: 3, begendim: true };
        if (ad === 'akis_sikayet_et' || ad === 'engelle' || ad === 'akis_sil') return { tamam: true };
        if (ad === 'ay_raporu') return { ay: '2030-02', ay_ad: 'Şubat 2030', kad: 'Deniz<b>', unvan: 'İzmir Milletvekili', il: 'İzmir', parti: { id: 1, ad: 'Örnek Parti' }, parti_vekil: 12, parti_sira: 2, paylasim: 14, begeni: 31, makam_gun: 12.5, yeni_makamlar: [], yeni_basarimlar: [{ kod: 'vekil', ad: 'Meclis Kürsüsü', sinif: 'gumus' }], basarim_toplam: 5, paylasim_metni: 'metin' };
        if (ad === 'basarimlar') return [{ kod: 'ilk_soz', ad: 'İlk Söz', aciklama: 'İlk paylaşım', sinif: 'bronz', kazandi: true, zaman: new Date().toISOString() }, { kod: 'cb', ad: 'Çankaya', aciklama: 'Cumhurbaşkanı', sinif: 'altin', kazandi: false, zaman: null }];
        if (ad === 'partiler') return [];
        throw new Error('Beklenmeyen RPC: ' + ad);
      } };
      D.durum = { profil: { il_id: 34, kad: 'Deniz', parti: { id: 1 }, makamlar: [], cuzdan: { para: 1 } } };
    });
    // --- canlı sayım paneli
    await page.evaluate(() => secimEkrani(5));
    await page.waitForSelector('#geceKart');
    let t = await page.locator('#geceKart').textContent();
    assert.match(t, /Canlı sayım/); assert.match(t, /2\/4 il/); assert.match(t, /%23,1/); assert.match(t, /ABC %41,2/); assert.match(t, /İstanbul henüz açılmadı/);
    assert.equal(await page.locator('#geceKart b >> text=<b>Bursa</b>').count(), 1);   // il adı kaçırıldı (düz yazı)
    assert.equal(await page.locator('#geceKart .gece-il b b').count(), 0);
    if (shot) await page.screenshot({ path: path.join(shot, 'gece.png') });
    // yenileme: yeni il açılınca sessiz yenileme ve kendi ilin açıldı notu
    await page.evaluate(() => { zaman = 1; return secimEkrani(5, true); });
    t = await page.locator('#geceKart').textContent(); assert.match(t, /3\/4 il/); assert.match(t, /İstanbul açıldı/);
    assert.ok(await page.evaluate(() => !!D.canli), 'otomatik yenileme kurulu');
    // sayım bitince panel kalkar
    await page.evaluate(() => { window.__rpc = API.rpc; API.rpc = async (ad) => ({ id: 5, tur: 'mv', asama: 'bitti', oy_bas: new Date().toISOString(), oy_bit: new Date().toISOString(), sonuc_at: new Date().toISOString(), katilim: 1, benim_il: 34, sonuc: { toplam: 0, dolu: 0, bos: 0, ulusal: [], iller: {}, bagimsiz_sandalye: 0 } }); return secimEkrani(5, true); });
    assert.equal(await page.locator('#geceKart').count(), 0);
    assert.ok(await page.evaluate(() => !D.canli), 'bitince yenileme durur');
    assert.match(await page.locator('.toast').textContent(), /Sayım tamamlandı/);

    await page.evaluate(() => { API.rpc = window.__rpc; });
    // --- gündem kartları
    const gh = await page.evaluate(() => gundemEkUst({ canli: [{ secim_id: 5, tur: 'mv', yuzde: 40 }], firsat: [], etiket: [], ozet: null }) + gundemEkAlt({ canli: [], firsat: [{ tur: 'belediye', anahtar: 'bel:34', metin: 'İstanbul belediye başkanlığı boş.', ekran: 'gundem' }], etiket: [{ etiket: 'gündem', kisi: 3, paylasim: 4 }], ozet: { gelismeler: [{ tur: 'secim', metin: '<b>Seçim</b> sonuçlandı', zaman: '' }] } }));
    assert.match(gh, /sayımı sürüyor/); assert.match(gh, /İstanbul belediye başkanlığı boş/); assert.match(gh, /#gündem/); assert.doesNotMatch(gh, /<b>Seçim<\/b>/);

    // --- akış
    await page.evaluate(() => akisEkrani());
    await page.waitForSelector('.akis-satir');
    assert.equal(await page.locator('.akis-satir').count(), 2);
    assert.equal(await page.locator('#icerik img, #icerik script').count(), 0);
    assert.equal(await page.evaluate(() => window.xss), undefined);
    assert.equal(await page.locator('.akis-satir .etk').count(), 1);
    await page.fill('#akisMetin', 'Merhaba #deneme'); await page.click('#akisGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'akis_yaz'));
    assert.equal(await page.evaluate(() => calls.find(c => c.ad === 'akis_yaz').args.p_metin), 'Merhaba #deneme');
    await page.click('[data-begen="9"]'); await page.waitForFunction(() => calls.some(c => c.ad === 'akis_begen'));
    await page.click('[data-sikayet="9"]'); await page.selectOption('#skNeden', 'spam'); await page.click('#skGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'akis_sikayet_et'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'akis_sikayet_et').args), { p_id: 9, p_neden: 'spam' });
    await page.click('.akis-satir .etk'); await page.waitForFunction(() => calls.filter(c => c.ad === 'akis_liste').some(c => c.args.p_etiket === 'seçimgecesi'));
    await page.waitForSelector('.akis-satir[data-id="8"] [data-sil]');
    if (shot) await page.screenshot({ path: path.join(shot, 'akis.png') });

    // --- rapor
    await page.evaluate(() => raporEkrani());
    await page.waitForSelector('#raporKart');
    t = await page.locator('#raporKart').textContent(); assert.match(t, /Şubat 2030 raporu/); assert.match(t, /Deniz<b>/);
    assert.equal(await page.locator('#raporKart b >> text=Deniz').count(), 0);
    assert.equal(await page.locator('.basarim-satir.kilitli').count(), 1);
    assert.equal(await page.locator('#rpSonraki').count(), 0);   // gelecek ay için ileri düğmesi yok
    await page.click('#rpOnceki'); await page.waitForFunction(() => calls.filter(c => c.ad === 'ay_raporu').length >= 2);
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'ay_raporu').at(-1).args.p_ay), '2030-01-15');
    const png = await page.evaluate(async () => { const b = await raporResmi(await API.rpc('ay_raporu')); return b.size; });
    assert.ok(png > 5000, 'rapor kartı resmi üretildi');
    if (shot) await page.screenshot({ path: path.join(shot, 'rapor.png') });
    assert.deepEqual(errors, []);
    console.log('canli_ek_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
