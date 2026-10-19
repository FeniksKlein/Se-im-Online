// Canlı sayım paneli, fırsatlar, akış, rapor/başarım ekranları. Ağ yok; sahte RPC.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node test/canli_ek_arayuz.js [ekran_goruntusu_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
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
      window.AKIS_VERI = [{ id: 9, kad: 'Ada', unvan: 'ABC Genel Başkanı', parti: { id: 1, ad: 'A', kisa: 'ABC', renk: '#123456', amblem: 'a_yildiz' }, il: 'İzmir', metin: '<img src=x onerror="window.xss=1"> Bugün #SeçimGecesi çok heyecanlı', zaman: new Date().toISOString(), begeni: 2, begenmeme: 0, yanit: 1, begendim: false, begenmedim: false, benim: false },
        { id: 8, kad: 'Deniz', unvan: null, parti: null, il: 'Ankara', metin: "Benim paylaşımım: Türkiye'nin gündemi & <b>haber</b>", zaman: new Date().toISOString(), begeni: 0, begenmeme: 0, yanit: 0, begendim: false, begenmedim: false, benim: true }];
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args });
        if (ad === 'secim_detay') return detay();
        if (ad === 'akis_liste') return AKIS_VERI;
        if (ad === 'akis_gundem') return [{ etiket: 'seçimgecesi', kisi: 4, paylasim: 5 }];
        if (ad === 'akis_yaz') return { tamam: true, id: 10 };
        if (ad === 'akis_begen') return { begeni: 3, begendim: true };
        if (ad === 'akis_tepki') return args.p_tepki === 'begenme' ? { begeni: 2, begenmeme: 1, begendim: false, begenmedim: true } : { begeni: 3, begenmeme: 0, begendim: true, begenmedim: false };
        if (ad === 'akis_konu') return { ana: AKIS_VERI[0], yanitlar: [Object.assign({}, AKIS_VERI[1], { id: 11, yanit_id: 9, metin: 'Katılmıyorum' })] };
        if (ad === 'akis_yanit_yaz') return { tamam: true, id: 12 };
        if (ad === 'cimer') return window.CIMER_VERI;
        if (ad === 'cimer_karne') return [{ kurum: 'Sağlık Bakanlığı', hedef: 'bakanlik', basvuru: 3, yanit: 2, geciken: 1, ort_saat: 5.5, memnuniyet: 50 }];
        if (ad === 'cimer_basvur') return { tamam: true, id: 1, muhatap_var: true };
        if (ad === 'cimer_yanitla' || ad === 'cimer_degerlendir') return { tamam: true };
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
    const gh = await page.evaluate(() => gundemEkUst({ canli: [{ secim_id: 5, tur: 'mv', yuzde: 40 }], firsat: [], etiket: [], ozet: null }) + gundemEkAlt({ canli: [], firsat: [{ tur: 'belediye', anahtar: 'bel:34', metin: 'İstanbul belediye başkanlığı boş.', ekran: 'gundem' }], etiket: [{ etiket: 'gündem', kisi: 3, paylasim: 4 }], ozet: { gelismeler: [{ tur: 'secim', metin: '<b>Seçim</b> sonuçlandı', zaman: '' }] }, akis: [], cimer: null }));
    assert.match(gh, /sayımı sürüyor/); assert.match(gh, /İstanbul belediye başkanlığı boş/); assert.match(gh, /#gündem/); assert.doesNotMatch(gh, /<b>Seçim<\/b>/);

    // --- akış
    await page.evaluate(() => akisEkrani());
    await page.waitForSelector('.akis-satir');
    assert.equal(await page.locator('.akis-satir').count(), 2);
    assert.equal(await page.locator('#icerik img, #icerik script').count(), 0);
    assert.equal(await page.evaluate(() => window.xss), undefined);
    assert.equal(await page.locator('.akis-satir .etk').count(), 1);
    assert.equal(await page.locator('.akis-satir[data-id="8"] .metin').textContent(), "Benim paylaşımım: Türkiye'nin gündemi & <b>haber</b>");
    assert.equal(await page.locator('.akis-satir[data-id="8"] .etk').count(), 0, 'HTML karakter kodundaki #39 etiket olamaz');
    const etiketDeneme = await page.evaluate(() => {
      const el = document.createElement('div');
      el.innerHTML = akisMetinHtml("Türkiye'nin #Seçim gündemi & <olay>");
      return { metin: el.textContent, etiket: el.querySelector('.etk')?.dataset.etk, adet: el.querySelectorAll('.etk').length };
    });
    assert.deepEqual(etiketDeneme, { metin: "Türkiye'nin #Seçim gündemi & <olay>", etiket: 'seçim', adet: 1 });
    await page.fill('#akisMetin', 'Merhaba #deneme'); await page.click('#akisGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'akis_yaz'));
    assert.equal(await page.evaluate(() => calls.find(c => c.ad === 'akis_yaz').args.p_metin), 'Merhaba #deneme');
    await page.click('.akis-satir[data-id="9"] [data-tepki="begenme"]'); await page.waitForFunction(() => calls.some(c => c.ad === 'akis_tepki'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'akis_tepki').args), { p_id: 9, p_tepki: 'begenme' });
    await page.waitForSelector('.akis-satir[data-id="9"] .acik-begenme');
    assert.match(await page.locator('.akis-satir[data-id="9"] [data-tepki="begenme"]').textContent(), /1/);
    await page.click('.akis-satir[data-id="9"] [data-menu="9"]'); await page.selectOption('#skNeden', 'spam'); await page.click('#skGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'akis_sikayet_et'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'akis_sikayet_et').args), { p_id: 9, p_neden: 'spam' });
    await page.click('.akis-satir .etk'); await page.waitForFunction(() => calls.filter(c => c.ad === 'akis_liste').some(c => c.args.p_etiket === 'seçimgecesi'));
    await page.waitForSelector('.akis-satir[data-id="8"] [data-menu="8"]');
    if (shot) await page.screenshot({ path: path.join(shot, 'akis.png') });
    // konu (yanıtlar) ekranı
    await page.click('.akis-satir[data-id="9"] [data-yanitla="9"]'); await page.waitForSelector('#konuKap .konu-ana');
    assert.equal(await page.locator('#konuKap .akis-satir').count(), 2);
    await page.fill('#yanitMetin', 'Ben de katılıyorum'); await page.click('#yanitGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'akis_yanit_yaz'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'akis_yanit_yaz').args), { p_id: 9, p_metin: 'Ben de katılıyorum' });
    if (shot) await page.screenshot({ path: path.join(shot, 'konu.png') });
    // CİMER
    await page.evaluate(() => { window.CIMER_VERI = { bugun_kalan: 2, kurumlar: { cb: 'Reis', il_id: 34, belediye_baskani: null, bakanliklar: [{ kod: 'saglik', ad: 'Sağlık Bakanlığı', bakan: 'Doktor' }, { kod: 'egitim', ad: 'Millî Eğitim Bakanlığı', bakan: null }] },
      basvurularim: [{ id: 1, kurum: 'Sağlık Bakanlığı', kategori: 'sikayet', konu: 'Randevu <b>yok</b>', metin: 'Metin', zaman: new Date().toISOString(), durum: 'sonuclandi', sonuc: 'olumlu', cevap: 'Hekim atandı', cevaplayan: 'Doktor', cevaplayan_unvan: 'Sağlık Bakanı', memnun: null, benim: true }],
      gelen: [{ id: 2, kurum: 'Sağlık Bakanlığı', kategori: 'talep', konu: 'Ambulans', metin: 'Köyümüze ambulans', zaman: new Date().toISOString(), durum: 'bekliyor', gonderen: 'Ali', gonderen_il: 'Bursa', yanitlayabilirim: true, suresi_gecti: true }] }; CIMER.sekme = 'yeni'; return cimerEkrani(); });
    await page.waitForSelector('#cmHedef');
    assert.match(await page.locator('#cmBak').textContent(), /bakan yok, Cumhurbaşkanı bakar/);
    await page.selectOption('#cmHedef', 'belediye'); assert.equal(await page.locator('#cmIlKut').isHidden(), false);
    assert.match(await page.locator('#cmIlNot').textContent(), /başkanı yok/);
    if (shot) await page.screenshot({ path: path.join(shot, 'cimer.png') });
    await page.selectOption('#cmHedef', 'bakanlik'); await page.selectOption('#cmBak', 'egitim');
    await page.click('#cmKat [data-kat="oneri"]'); await page.fill('#cmKonu', 'Okul'); await page.fill('#cmMetin', 'Okul bahçesi düzenlensin lütfen.');
    await page.click('#cmGonder'); await page.waitForFunction(() => calls.some(c => c.ad === 'cimer_basvur'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'cimer_basvur').args), { p_hedef: 'bakanlik', p_bakanlik: 'egitim', p_il: null, p_kategori: 'oneri', p_konu: 'Okul', p_metin: 'Okul bahçesi düzenlensin lütfen.' });
    await page.waitForSelector('.cimer-satir');
    assert.equal(await page.locator('.cimer-satir b >> text=Randevu <b>yok</b>').count(), 1);
    await page.getByRole('button', { name: 'Memnun kaldım' }).click(); await page.waitForFunction(() => calls.some(c => c.ad === 'cimer_degerlendir'));
    await page.click('[data-cs="gelen"]'); await page.waitForSelector('text=Süresi geçti');
    await page.getByRole('button', { name: 'Resmî yanıt ver' }).click(); await page.fill('#cmCevap', 'Ambulans görevlendirildi.'); await page.click('#cmYanitGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'cimer_yanitla'));
    assert.deepEqual(await page.evaluate(() => calls.find(c => c.ad === 'cimer_yanitla').args), { p_id: 2, p_durum: 'sonuclandi', p_sonuc: 'olumlu', p_cevap: 'Ambulans görevlendirildi.' });
    await page.click('[data-cs="karne"]'); await page.waitForSelector('.cimer-karne'); assert.match(await page.locator('.cimer-karne').textContent(), /5,5 sa/);
    const cg = await page.evaluate(() => cimerGundemHtml(CIMER_VERI)); assert.match(cg, /1 CİMER başvurusu geldi/);
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
