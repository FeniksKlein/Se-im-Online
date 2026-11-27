// İl Başkanlığı Masası + İl Başkanlıkları arayüz testi (sahte RPC; 390 ve 320 px) — 27.11.2026
// Masa (üst kart, karne, kongre haftası, sekmeler), etkinlik (miting/stant formu), açıklama, kurul (oy, yetki, üye ekle),
// kasa (bağış), genel merkez yazısı, genel merkez işlemleri; İl Başkanlıkları (yöntem, gelen yazı yanıtı, 81 il), girişler, taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/il_baskanligi_masasi_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const gen of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: gen, height: gen === 320 ? 640 : 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
    page.on('pageerror', e => hatalar.push(gen + ': ' + e.message.slice(0, 300)));
    page.on('dialog', d => d.accept());
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => typeof window.ilMasasiAc === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = [];
      const now = Date.now(), iso = (ms) => new Date(now + ms).toISOString();
      const P = { id: 1, kisa: 'CYP', ad: 'Cumhuriyet Yolu Partisi', renk: '#c62828', amblem: 'a_basak' };
      const hafta = { kurultay_id: 11, kurultay_basvuru: iso(17 * 864e5), kurultay_oy: iso(20 * 864e5), acilis: iso(12 * 864e5), aday_bit: iso(14 * 864e5), oy_bit: iso(14.6 * 864e5), bu_ilde: true };
      window.ROL = 'baskan';
      window.masa = () => ({
        simdi: iso(0), parti: P, il: { id: 34, ad: 'İstanbul', mv: 98 }, rol: ROL, gm: ROL === 'gm', mali: ROL === 'gm', gb: ROL === 'gm', ozel: ROL !== 'uye',
        yetkiler: ROL === 'baskan' ? ['etkinlik', 'aciklama', 'yazisma', 'karar', 'yk'] : [], yontem: 'secim', teskilat: true, yk_azami: 7,
        detay: { il_id: 34, il: 'İstanbul', teskilat: true, yontem: 'secim', kongre_haftasi: hafta,
          baskan: { kad: 'yldry58', ad: 'Yıldıray Yürekoğlu Karamanlıoğulları', statu: 'gecici', bas: iso(-864e5), donem_bit: null },
          yonetim_kurulu: [{ kad: 'Euxionos', ad: 'Ataman Fotoğlu', gorev: 'Seçim İşleri', yetkiler: ['etkinlik', 'aciklama'] }, { kad: 'MeMeKo', ad: 'Mehmet Mert', gorev: 'Tanıtım ve Medya', yetkiler: [] }],
          kongre: { id: 5, tur: 'ilk', durum: 'aday', aday_bit: iso(5 * 3600e3), oy_bit: iso(29 * 3600e3), adaylar: [{ kad: 'yldry58', ad: 'Yıldıray', vaat: 'Her ilçeye teşkilat evi' }], oy_sayisi: 0, kongre_haftasi: false } },
        istatistik: { uye: 106, yeni_7g: 9, aktif_24s: 41, mv: 3, mv_adlar: ['Ali Veli', 'Ayşe Kaya', 'Can Er'], belediye: null },
        karne: { puan: 37, sira: 2, toplam: 81, miting: 1, stant: 2, aciklama: 1, karar: 1, yk: 2, uye: 106 },
        kasa: ROL === 'uye' ? null : { bakiye: 58000, parti_kasa: ROL === 'gm' ? 3933350 : null, hareket: [{ zaman: iso(-3600e3), tutar: 50000, tur: 'odenek', aciklama: 'Genel merkez ödeneği · Abdullah Gencer' }, { zaman: iso(-1800e3), tutar: -2000, tur: 'stant', aciklama: 'İstanbul seçim standı · Ataman Fotoğlu' }] },
        mitingler: [{ id: 91, baslik: 'İstanbul Teşkilat Buluşması', bas: iso(26 * 3600e3), bit: iso(27 * 3600e3), kad: 'yldry58', ad: 'Yıldıray', il_orgut: true, odeyen: 'il', bedel: 12000, canli: false, iptal_edebilir: ROL !== 'uye' }],
        stantlar: [{ id: 3, baslik: 'Kadıköy iskele standı', bas: iso(-3600e3), bit: iso(2 * 3600e3), ad: 'Ataman Fotoğlu', canli: true }],
        aciklamalar: [{ id: 7, baslik: 'İstanbul için yeni dönem', metin: 'İl teşkilatımız olarak İstanbul’un her ilçesinde sahadayız. Kapı kapı dolaşıyoruz.', kamu: true, zaman: iso(-7200e3), kad: 'Euxionos', ad: 'Ataman Fotoğlu', rol: 'yk', silebilir: true },
                      { id: 8, baslik: 'Pazar toplantısı', metin: 'Pazar 14.00 il binasında toplantı.', kamu: false, zaman: iso(-9000e3), kad: 'yldry58', ad: 'Yıldıray', rol: 'baskan', silebilir: true }],
        kararlar: ROL === 'uye' ? null : [{ id: 1, no: '2026/1', tur: 'genel', baslik: 'Kongre hazırlık komisyonu', metin: 'Üç kişilik komisyon kurulmuştur.', durum: 'oylama', kurul: 3, olur: false, acilis: iso(-3600e3), bitis: iso(20 * 3600e3), kabul: 1, ret: 0, cekimser: 0, oneren: 'Yıldıray', oyum: ROL === 'baskan' ? null : null }],
        yazilar: ROL === 'uye' ? null : [{ id: 4, tur: 'talep', baslik: 'Miting ödeneği talebi', metin: 'Kongre haftası öncesi iki miting için ödenek.', tutar: 10000, ilgili: null, zaman: iso(-3600e3), durum: 'kabul', cevap: 'Uygundur, başarılar.', cevaplayan: 'Abdullah Gencer', gonderen: 'Yıldıray' }],
        haklar: { miting_bedel: 12000, stant_bedel: 2000, stant_bugun: false, aciklama_bugun: 1, duyuru_bugun: 0, aciklama_sinir: 6, duyuru_sinir: 3, sonraki_aciklama: null, yazi_24s: 1, yazi_sinir: 3, cuzdan: 45000 },
        uyeler: ROL === 'uye' ? null : [{ kad: 'yldry58', ad: 'Yıldıray', yk: false, baskan: true }, { kad: 'Euxionos', ad: 'Ataman Fotoğlu', yk: true, baskan: false }, { kad: 'soydan', ad: 'Onur Soydan', yk: false, baskan: false }, { kad: 'kerem31', ad: 'Kerem Aras', yk: false, baskan: false }]
      });
      const genel = () => ({ simdi: iso(0), parti: Object.assign({ kasa: 3933350 }, P), gb: true, gm: true, mali: true, yontem: 'secim', yontem_degisim: null, yontem_sonraki: null, kongre_haftasi: Object.assign({ acik_kongre: 0 }, hafta),
        tuzuk: {}, iller: [{ il_id: 34, il: 'İstanbul', mv: 98, teskilat: true, baskan: { kad: 'yldry58', ad: 'Yıldıray', statu: 'gecici' }, yk: 2, uye: 106, puan: 37, kasa: 58000, kongre: null, bekleyen: 1 },
          { il_id: 6, il: 'Ankara', mv: 36, teskilat: true, baskan: null, yk: 0, uye: 22, puan: 6, kasa: 0, kongre: { id: 2, durum: 'oy' }, bekleyen: 0 }, { il_id: 62, il: 'Tunceli', mv: 1, teskilat: false, baskan: null, yk: 0, uye: 0, puan: 0, kasa: 0, kongre: null, bekleyen: 0 }],
        gelen: [{ id: 9, il_id: 34, il: 'İstanbul', tur: 'talep', baslik: 'Stant ödeneği', metin: 'Beş ilçede stant için ödenek talep ediyoruz.', tutar: 20000, ilgili: null, gonderen: 'Yıldıray', zaman: iso(-600e3), durum: 'bekliyor', cevap: null, karar: null },
                { id: 10, il_id: 34, il: 'İstanbul', tur: 'aday', baslik: 'Kadıköy için aday önerisi', metin: 'Onur Soydan’ı milletvekili adayı olarak öneriyoruz.', tutar: null, ilgili: 'Onur Soydan', ilgili_kad: 'soydan', gonderen: 'Yıldıray', zaman: iso(-900e3), durum: 'goruldu', cevap: null, karar: '2026/2' }] });
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'il_masa') return masa();
        if (ad === 'il_masa_genel' || ad === 'il_gm_yazi_cevap') return genel();
        if (ad === 'il_baskan_yontem_ayarla') { const g = genel(); g.yontem = a.p_yontem; return g; }
        if (ad === 'il_masa_benim') return { parti_id: 1, parti: 'CYP', il_id: 34, il: 'İstanbul', rol: ROL === 'gm' ? null : ROL, gm: ROL === 'gm', gb: ROL === 'gm', yontem: 'secim', oy_bekleyen: 1, gelen_bekleyen: 2 };
        if (/^il_(kasa_odenek|kasa_iade|miting_iptal|aciklama_yap|karar_oner|karar_oy|karar_geri_cek|gm_yazi_gonder|yk_yetki|baskan_ata)$/.test(ad)) return masa();
        if (ad === 'il_miting_duzenle') return { id: 92, bedel: 12000, il: 'İstanbul', odeyen: a.p_kaynak === 'il' ? 'il' : 'kisi' };
        if (ad === 'il_stant_ac') return { id: 4 };
        if (ad === 'il_kasa_bagis') return { tamam: true, tutar: a.p_tutar };
        if (ad === 'il_yk_ekle' || ad === 'il_yk_cikar' || ad === 'il_baskan_gorevden_al' || ad === 'il_teskilat_detay') return masa().detay;
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: iso(0), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 34, kad: 'yldry58', parti: { id: 1, kisa: 'CYP', renk: '#c62828' }, makamlar: [], cuzdan: { para: 45000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: iso(0), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      window.confirm = () => true;
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const tikla = async (sel) => { await page.waitForSelector(sel); await page.$eval(sel, el => el.click()); };
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.waitForTimeout(500); const h = await page.evaluate(() => { const m = document.querySelector('#modal .modal'); const i = document.getElementById('icerik'); return m ? m.scrollHeight + 80 : i ? i.scrollHeight : 0; }); await page.setViewportSize({ width: gen, height: Math.min(5000, Math.max(640, h + 160)) }); await page.waitForTimeout(300); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); await page.setViewportSize({ width: gen, height: gen === 320 ? 640 : 844 }); } };
    const tasma = async () => page.evaluate(() => [...document.querySelectorAll('#icerik *, #modal *')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.im-seg'); }).map(el => (el.className || el.tagName) + ':' + Math.round(el.getBoundingClientRect().right)).slice(0, 5));
    const sonCagri = (ad) => page.evaluate((ad) => (calls.filter(c => c.ad === ad).pop() || {}).a, ad);

    // 1) Masa · Özet (il başkanı)
    await page.evaluate(() => ilMasasiAc(1, 34));
    await page.waitForSelector('.im-ust');
    let t = await page.textContent('#icerik');
    assert.match(t, /CYP İstanbul İl Başkanlığı/, et('başlık'));
    assert.match(t, /İl Başkanısın/, et('rol çipi'));
    assert.match(t, /Geçici görevli/, et('statü'));
    assert.match(t, /il kongresi seçer/, et('yöntem çipi'));
    assert.match(t, /İl karnesi: 37\/100/, et('karne'));
    assert.match(t, /81 il örgütü içinde 2\./, et('sıralama'));
    assert.match(t, /Kongre haftası|kongre haftasında/i, et('kongre haftası kartı'));
    assert.match(t, /İstanbul il kongresi yapılacak/, et('bu ilde kongre'));
    assert.match(t, /Masadaki işler/, et('eylem ızgarası'));
    assert.match(t, /Ali Veli, Ayşe Kaya, Can Er/, et('milletvekilleri'));
    assert.equal(await page.$$eval('.im-eylem:not([disabled])', x => x.length), 6, et('6 eylem açık'));
    assert.deepEqual(await tasma(), [], et('özet taşma'));
    await cek('ozet');

    // 2) Miting formu
    await tikla('.im-eylem[data-e="miting"]');
    await page.waitForSelector('#imMBas');
    assert.match(await page.textContent('#modal'), /İl örgütü kasası · 58\.000 ₺/, et('kasa seçeneği'));
    assert.deepEqual(await tasma(), [], et('miting formu taşma'));
    await cek('miting_form');
    await page.fill('#imMBas', 'İstanbul büyük buluşma');
    await tikla('.im-hizli [data-z="60"]');
    await tikla('#imMOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_miting_duzenle'));
    const mt = await sonCagri('il_miting_duzenle');
    assert.equal(mt.p_kaynak, 'il', et('kaynak il'));
    const fark = (new Date(mt.p_bas).getTime() - Date.now()) / 60000;
    assert.ok(fark > 55 && fark < 65, et('1 saat sonra ' + fark));

    // 3) Etkinlik sekmesi + iptal
    await page.waitForSelector('[data-sk="etkinlik"].aktif');
    t = await page.textContent('#icerik');
    assert.match(t, /İl örgütü mitingi/, et('miting satırı'));
    assert.match(t, /AÇIK/, et('açık stant'));
    await tikla('[data-iptal="91"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_miting_iptal' && c.a.p_miting === 91));
    await tikla('#imStant');
    await page.fill('#imSBas', 'Beşiktaş meydan standı');
    await tikla('#imSOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_stant_ac' && c.a.p_baslik === 'Beşiktaş meydan standı'));

    // 4) Açıklama
    await tikla('[data-sk="aciklama"]');
    await page.waitForSelector('#imAc');
    t = await page.textContent('#icerik');
    assert.match(t, /Teşkilat içi duyuru/, et('duyuru etiketi'));
    await tikla('#imAc');
    await page.fill('#imABas', 'Ulaşım zammına tepki');
    await page.fill('#imAMet', 'Ulaşım zammı İstanbullunun belini büküyor; geri alınmalıdır.');
    await cek('aciklama_form');
    await tikla('#imAOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_aciklama_yap' && c.a.p_kamu === true));
    await tikla('[data-sil="7"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_aciklama_sil' && c.a.p_id === 7));

    // 5) Kurul ve kararlar
    await tikla('[data-sk="kurul"]');
    await page.waitForSelector('[data-oy="kabul"]');
    t = await page.textContent('#icerik');
    assert.match(t, /İl yönetim kurulu \(2\/7\)/, et('kurul sayısı'));
    assert.match(t, /2026\/1/, et('karar no'));
    assert.deepEqual(await tasma(), [], et('kurul taşma'));
    await cek('kurul');
    await tikla('[data-oy="kabul"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_karar_oy' && c.a.p_oy === 'kabul' && c.a.p_karar === 1));
    await page.waitForSelector('[data-ytk="MeMeKo"]');
    await tikla('[data-ytk="MeMeKo"]');
    await page.waitForSelector('#imYtOk');
    await page.$eval('#modal input[value="yazisma"]', el => { el.checked = true; });
    await tikla('#imYtOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_yk_yetki' && c.a.p_kad === 'MeMeKo' && c.a.p_yetkiler.includes('yazisma')));
    await page.waitForSelector('#imYkEkle');
    await tikla('#imYkEkle');
    await page.waitForSelector('#imYkKad option', { state: 'attached' });
    assert.deepEqual(await page.$$eval('#imYkKad option', o => o.map(x => x.value)), ['soydan', 'kerem31'], et('kurula eklenebilecekler'));
    await page.fill('#imYkAra', 'kerem');
    assert.deepEqual(await page.$$eval('#imYkKad option', o => o.map(x => x.value)), ['kerem31'], et('üye arama'));
    await tikla('#imYkOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_yk_ekle' && c.a.p_kad === 'kerem31' && c.a.p_gorev === 'İl Başkan Yardımcısı'));
    await tikla('#imKarar');
    await page.waitForSelector('#imKTur');
    await page.selectOption('#imKTur', 'oneri');
    await page.fill('#imKBas', 'Gençlik kolu önerisi');
    await page.fill('#imKMet', 'Genel merkeze İstanbul gençlik kolu kurulması önerilir.');
    await tikla('#imKOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_karar_oner' && c.a.p_tur === 'oneri'));

    // 6) Kasa ve bağış
    await tikla('[data-sk="kasa"]');
    await page.waitForSelector('#imBOk');
    t = await page.textContent('#icerik');
    assert.match(t, /58\.000 ₺/, et('kasa bakiyesi'));
    assert.match(t, /Genel merkez ödeneği/, et('hareket'));
    await page.fill('#imBTut', '5000');
    await tikla('#imBOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_kasa_bagis' && c.a.p_tutar === 5000 && c.a.p_il === 34));

    // 7) Genel merkeze yazı
    await tikla('[data-sk="gm"]');
    await page.waitForSelector('#imYaz');
    assert.match(await page.textContent('#icerik'), /Uygundur, başarılar/, et('gm yanıtı'));
    await tikla('#imYaz');
    await page.selectOption('#imYTur', 'talep');
    await page.waitForSelector('#imYTutarK:not([hidden])');
    await page.fill('#imYTutar', '30000');
    await page.fill('#imYBas', 'Kongre haftası ödeneği');
    await page.fill('#imYMet', 'Kongre haftası için salon ve ulaşım giderleri talep ediyoruz.');
    await cek('yazi_form');
    await tikla('#imYOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_gm_yazi_gonder' && c.a.p_tur === 'talep' && c.a.p_tutar === 30000));

    // 8) Partili üye görünümü
    await page.evaluate(() => { ROL = 'uye'; ilMasasiAc(1, 34); });
    await page.waitForSelector('.im-ust');
    t = await page.textContent('#icerik');
    assert.match(t, /Partili üye/, et('üye rolü'));
    assert.ok(!(await page.$('[data-sk="kurul"]')), et('üyeye kurul sekmesi yok'));
    assert.ok(await page.$('[data-sk="kasa"]'), et('üyeye bağış sekmesi'));
    assert.ok(!(await page.$('.im-eylem')), et('üyeye eylem yok'));

    // 9) Genel merkez: masa altında işlemler + İl Başkanlıkları
    await page.evaluate(() => { ROL = 'gm'; ilMasasiAc(1, 34); });
    await page.waitForSelector('#imGm');
    t = await page.textContent('#imGm');
    assert.match(t, /Geçici il başkanı görevlendir/, et('gm atama'));
    assert.match(t, /olağanüstü kongre açılır/, et('gm görevden alma'));
    assert.match(t, /parti kasası: 3\.933\.350 ₺/, et('gm ödenek'));
    await page.selectOption('#imGmAta', 'soydan');
    await tikla('#imGmAtaOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_baskan_ata' && c.a.p_kad === 'soydan' && c.a.p_il === 34));
    await page.waitForSelector('#imGmOd');
    await page.fill('#imGmOd', '25000');
    await tikla('#imGmOdOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_kasa_odenek' && c.a.p_tutar === 25000));
    await page.waitForSelector('#imGmGer');
    await page.fill('#imGmGer', 'Teşkilat çalışması yetersiz kaldı, yeniden yapılanma');
    await tikla('#imGmAl');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_baskan_gorevden_al'));
    assert.deepEqual(await tasma(), [], et('gm masa taşma'));

    await page.evaluate(() => ilBaskanliklariAc());
    await page.waitForSelector('#imGListe [data-il]');
    t = await page.textContent('#icerik');
    assert.match(t, /CYP İl Başkanlıkları/, et('genel başlık'));
    assert.match(t, /İl kongresi \(seçim\)/, et('yöntem seçenekleri'));
    assert.match(t, /Gelen yazılar \(2 bekliyor\)/, et('bekleyen yazılar'));
    assert.match(t, /Teşkilat yok/, et('teşkilatsız il'));
    assert.deepEqual(await tasma(), [], et('genel taşma'));
    await cek('genel');
    await tikla('[data-cv="kabul"][data-y="9"]');
    await page.waitForSelector('#imCvMet');
    assert.match(await page.textContent('#modal'), /20\.000 ₺ parti kasasından il kasasına aktarılacak/, et('kabul uyarısı'));
    await page.fill('#imCvMet', 'Onaylandı.');
    await tikla('#imCvOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_gm_yazi_cevap' && c.a.p_id === 9 && c.a.p_durum === 'kabul' && c.a.p_cevap === 'Onaylandı.'));
    await page.waitForSelector('[data-yon="atama"]');
    await tikla('[data-yon="atama"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_baskan_yontem_ayarla' && c.a.p_yontem === 'atama'));
    await page.waitForSelector('[data-yon="atama"].secili');
    await page.fill('#imGAra', 'ank');
    assert.equal(await page.$$eval('#imGListe [data-il]', x => x.length), 1, et('il arama'));
    await tikla('#imGListe [data-il="6"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_masa' && c.a.p_il === 6));

    // 10) Girişler
    await page.evaluate(() => { ROL = 'baskan'; iskelet('Partiler', '<div class="kart">x</div>'); });
    await page.waitForSelector('#imParti .im-giris');
    assert.match(await page.textContent('#imParti'), /İl Başkanlığı Masası/, et('Partiler girişi'));
    assert.match(await page.textContent('#imParti'), /1 önerge oyunu bekliyor/, et('bekleyen oy'));
    await page.evaluate(() => ilBaskanligiGiris());
    await page.waitForFunction(() => calls.filter(c => c.ad === 'il_masa_benim').length >= 2);
    const rotalar = await page.evaluate(() => ['İstanbul İl Başkanlığı Masası: yeni karar önergesi oyunu bekliyor', 'CYP İl Yönetim Kurulu’na alındın', 'Kongre haftası başladı: il başkanlığına aday olabilirsin'].map(m => (bmKategori(m) || {}).rota));
    assert.deepEqual(rotalar, ['ilmasa', 'ilmasa', 'ilmasa'], et('bildirim rotası ' + rotalar.join(',')));
    await page.close();
  }
  await browser.close();
  if (hatalar.length) { console.error('Sayfa hataları:\n' + hatalar.join('\n')); process.exit(1); }
  console.log('il_baskanligi_masasi_arayuz: TAMAM (390 ve 320 px)');
})().catch(e => { console.error(e); process.exit(1); });
