// Kademeli Getiri + İstihdam arayüz testi (sahte RPC; 390 ve 320 px) — 26.11.2026
// Şirket › Özet'te Kademeli Getiri kartı + Personel düğmesi + Hızlı Açılış; Şirket › Personel (ilan, başvuru kabul,
// çalışan maaş/bitir); Ek İşler'in üstünde İş Hayatı kartı ve Mesaiye git; İş Hayatı ekranı (ilan başvurusu);
// Mağaza'da "Bu parayı şirketine koyarsan" kartı; eski sunucuda (RPC yok) hiçbir şey eklenmez; taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/kademe_istihdam_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
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
    await page.waitForFunction(() => typeof window.personelEkrani === 'function' && typeof window.istihdamEkrani === 'function' && typeof iskelet === 'function' && typeof window.ekIslerEkrani === 'function');
    await page.evaluate(() => {
      window.calls = []; window.ESKI = false;
      const g = new Date().toISOString().slice(0, 10);
      window.ST = { is: null, bas: [{ id: 5, user_id: 'u5', ad: 'Ayşe Yılmaz', kidem: 3.5, mesaj: 'Düzenli çalışırım, her gün mesaideyim.', zaman: new Date().toISOString() }],
        cal: [{ id: 9, ad: 'Mehmet Uzunisimlioğlu Kaya', maas: 2500, baslama: new Date().toISOString(), son_mesai: g, bugun: true, mesai_sayi: 4, toplam_maas: 10000, toplam_katma: 13500 }] };
      const ozet = { aktif: true, verim: 2.3, sermaye: 445000, gunluk_hedef: 11125, oran: 2.5, ilk_dilim_kalan: 55000, hizli_jeton: 1, hizli_gun: 9,
        dilimler: [{ alt: 0, ust: 500000, oran: 2.5 }, { alt: 500000, ust: 2000000, oran: 1.2 }, { alt: 2000000, ust: 5000000, oran: 0.6 }, { alt: 5000000, ust: null, oran: 0.3 }],
        patron: { aktif: false, bitis: null, ek: 250000 }, sirketler: [{ id: 168, ad: 'BALKES A.Ş', sermaye: 445000, pay: 100, olgunluk: 72 }] };
      const sirket = () => ({ sirket_id: 168, ad: 'BALKES A.Ş', kasa: 105000, sermaye: 445000, kontenjan: 3, kontenjan_birim: 200000, kontenjan_max: 10,
        piyasa_ucret: 2500, katma_kat: 1.35, maas_taban: 1500, maas_tavan: 20000,
        ilan: { id: 2, sirket_id: 168, sirket: 'BALKES A.Ş', sektor: 'Sanayi Üretimi', il: 'Balıkesir', maas: 2500, kontenjan: 2, dolu: 1, aciklama: 'Fabrikamıza işçi aranıyor', acik: true, odeme_guvenli: true },
        basvurular: ST.bas, calisanlar: ST.cal, son7: { mesai: 4, maas: 10000, katma: 13500, vergi: 875 } });
      const panel = () => ({ acik: true, piyasa_ucret: 2500, maas_taban: 1500, maas_tavan: 20000, katma_kat: 1.35, pasif_gun: 7, min_hesap_gun: 3, ek_is_kalan: 4,
        is: ST.is, basvurularim: ST.is ? [] : [{ id: 3, ilan_id: 7, sirket: 'Uzun Adlı Lojistik ve Taşımacılık Anonim Şirketi', durum: 'bekliyor', zaman: new Date().toISOString() }],
        ilanlar: [{ id: 7, sirket_id: 244, sirket: 'Uzun Adlı Lojistik ve Taşımacılık Anonim Şirketi', sektor: 'Kargo ve Lojistik', il: 'Kahramanmaraş', maas: 3200, kontenjan: 4, dolu: 1, aciklama: 'Gece vardiyası yok, düzenli ödeme.', acik: true, odeme_guvenli: true },
                  { id: 8, sirket_id: 141, sirket: 'Gaziantep Sanayi', sektor: 'Sanayi Üretimi', il: 'Gaziantep', maas: 1500, kontenjan: 1, dolu: 0, aciklama: '', acik: true, odeme_guvenli: false }],
        sirketlerim: [{ id: 168, ad: 'BALKES A.Ş', calisan: 1, kontenjan: 3, bekleyen: 1, ilan_acik: true }] });
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        const yok = () => { throw new Error('function public.' + ad + ' does not exist'); };
        if (ESKI && /^(kademe_|istihdam_|hizli_)/.test(ad)) yok();
        if (ad === 'kademe_ozet') return ozet;
        if (ad === 'istihdam_sirket' || ad === 'istihdam_ilan_ver' || ad === 'istihdam_ilan_kapat' || ad === 'istihdam_maas' || ad === 'istihdam_cikar') return sirket();
        if (ad === 'istihdam_basvuru_karar') { ST.bas = []; ST.cal = ST.cal.concat([{ id: 10, ad: 'Ayşe Yılmaz', maas: 2500, baslama: new Date().toISOString(), son_mesai: null, bugun: false, mesai_sayi: 0, toplam_maas: 0, toplam_katma: 0 }]); return sirket(); }
        if (ad === 'istihdam_panel' || ad === 'istihdam_basvuru_geri' || ad === 'istihdam_ayril') return panel();
        if (ad === 'istihdam_basvur') return panel();
        if (ad === 'istihdam_mesai') { ST.is = Object.assign({}, ST.is, { bugun_yapildi: true, mesai_sayi: ST.is.mesai_sayi + 1 }); return Object.assign(panel(), { odenen: ST.is.maas }); }
        if (ad === 'hizli_acilis_kullan') return { once: 72, sonra: 100, kalan: 0 };
        if (ad === 'ortak_sirket_panel') return { sirketler: [{ id: 168, ad: 'BALKES A.Ş', sektor: 'sanayi', benim_pay: 100, sermaye: 445000, kasa: 105000, ortaklar: [] }] };
        if (ad === 'sirket_kasa_bilgi') return { bakiye: 50000 };
        if (ad === 'sirket_yerleri') return { yonetici: true, merkez: { il: 'Balıkesir' }, subeler: [] };
        if (ad === 'ek_is_paneli') return { simdi: new Date().toISOString(), sifirlanma: new Date(Date.now() + 5 * 3600e3).toISOString(), gunluk_limit: 5, bugun_yapilan: 1, kalan: 4, bugun_kazanilan: 2500, aktif: null, isler: [{ kod: 'yazilim', ad: 'Yazılım', simge: '💻', aciklama: 'Kod yaz', sure_dakika: 60, asgari_ucret: 2500, azami_ucret: 2500, kategori_ad: 'Teknoloji' }], gecmis: [] };
        if (ad === 'magaza_durum') return { satis_acik: true, para: 20000, kart: { aktif: false, gunluk: 7500 }, haklar: [], jetonlar: {}, unvanlar: [],
          paketler: [{ urun_id: 'secimonline.cash_25000', ad: 'Cep Harçlığı', miktar: 25000, tur: 'para', fiyat: '₺29,99', alinabilir: true },
                     { urun_id: 'secimonline.cash_400000', ad: 'Büyük Servet', miktar: 400000, tur: 'para', fiyat: '₺299,99', etiket: '%60 fazla', alinabilir: true }],
          getiri: ESKI ? undefined : { 'secimonline.cash_25000': 600, 'secimonline.cash_400000': 5000 },
          kademe: { aktif: true, sermaye: 445000, gunluk_hedef: 11125, ilk_dilim: 500000, ilk_oran: 2.5 }, patron: { aktif: false } };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: new Date().toISOString(), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 34, kad: 'Patron', makamlar: [], cuzdan: { para: 1000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: new Date().toISOString(), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    // Oyunun kendi bir kerelik tanıtım pencereleri (ör. ekonomi tanıtımı) testteki tıklamaları örtmesin
    const temizle = () => page.evaluate(() => { const m = document.getElementById('modal'); if (m && !m.querySelector('#kiNot,#kiYeniMaas')) modalKapat(); });
    const tikla = async (sel) => { await temizle(); await page.click(sel); };
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.waitForTimeout(1200); await temizle(); const h = await page.evaluate(() => { const i = document.getElementById('icerik'); return i ? i.scrollHeight : 0; }); await page.setViewportSize({ width: gen, height: Math.min(4000, Math.max(640, h + 160)) }); await page.waitForTimeout(300); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); await page.setViewportSize({ width: gen, height: gen === 320 ? 640 : 844 }); } };
    const tasma = async () => page.evaluate(() => [...document.querySelectorAll('#icerik *, #modal *')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.sm-tabs,.ei-sirala,.segment'); }).map(el => el.className || el.tagName).slice(0, 5));

    // 1) Şirket › Özet: Kademeli Getiri kartı
    await page.evaluate(() => sirketTekSirketEkrani(168, 'genel'));
    await page.waitForSelector('#kiKademe');
    const k = await page.textContent('#kiKademe');
    assert.match(k, /Kademeli Getiri/, et('kart başlığı'));
    assert.match(k, /İlk 500\.000/, et('ilk dilim'));
    assert.match(k, /← sen/, et('oyuncunun dilimi işaretli'));
    assert.match(k, /11\.125/, et('günlük hedef'));
    assert.match(k, /%72/, et('kuruluş verimi'));
    assert.ok(await page.$('#kiHizli'), et('hızlı açılış düğmesi'));
    assert.ok(await page.$('#kiPersonelBtn'), et('personel düğmesi'));
    assert.deepEqual(await tasma(), [], et('özet taşma'));
    await cek('sirket_ozet');
    page.once('dialog', d => d.accept());
    await page.evaluate(() => { window.onayla = async () => true; });
    await tikla('#kiHizli');
    await page.waitForFunction(() => calls.some(c => c.ad === 'hizli_acilis_kullan' && c.a.p_sirket === 168));

    // 2) Personel ekranı
    await page.evaluate(() => personelEkrani(168));
    await page.waitForSelector('#kiIlanVer');
    const p = await page.textContent('#icerik');
    assert.match(p, /Ayşe Yılmaz/, et('başvuru'));
    assert.match(p, /Mehmet Uzunisimlioğlu Kaya/, et('çalışan'));
    assert.match(p, /Bugün mesaide/, et('mesai etiketi'));
    assert.match(p, /3\.375/, et('katma değer örneği'));
    assert.deepEqual(await tasma(), [], et('personel taşma'));
    await cek('personel');
    await page.fill('#kiMaas', '3000'); await page.fill('#kiKont', '3');
    await tikla('#kiIlanVer');
    await page.waitForFunction(() => calls.some(c => c.ad === 'istihdam_ilan_ver'));
    const iv = await page.evaluate(() => calls.filter(c => c.ad === 'istihdam_ilan_ver').pop().a);
    assert.equal(iv.p_maas, 3000, et('ilan maaşı')); assert.equal(iv.p_kontenjan, 3, et('ilan kontenjanı')); assert.equal(iv.p_sirket, 168, et('ilan şirketi'));
    await page.waitForSelector('[data-kabul="5"]');
    await tikla('[data-kabul="5"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'istihdam_basvuru_karar' && c.a.p_kabul === true && c.a.p_basvuru === 5));
    await page.waitForFunction(() => document.querySelectorAll('[data-cikar]').length === 2);
    await tikla('[data-maas="9"]');
    await page.waitForSelector('#kiYeniMaas');
    assert.deepEqual(await tasma(), [], et('maaş penceresi taşma'));
    await page.fill('#kiYeniMaas', '2800'); await tikla('#kiMaasOnay');
    await page.waitForFunction(() => calls.some(c => c.ad === 'istihdam_maas' && c.a.p_maas === 2800 && c.a.p_istihdam === 9));

    // 3) İş Hayatı: işi yok → ilanlar, başvuru
    await page.evaluate(() => { ST.is = null; istihdamEkrani(); });
    await page.waitForSelector('[data-basvur="7"]');
    const ih = await page.textContent('#icerik');
    assert.match(ih, /Uzun Adlı Lojistik/, et('ilan'));
    assert.match(ih, /Ödeme güvenli/, et('ödeme güvenli etiketi'));
    assert.match(ih, /Şirketlerimin personeli/, et('şirketlerim'));
    assert.match(ih, /1 başvuru bekliyor/, et('bekleyen sayısı'));
    assert.deepEqual(await tasma(), [], et('iş hayatı taşma'));
    await cek('is_hayati');
    await tikla('[data-basvur="7"]');
    await page.waitForSelector('#kiNot');
    await page.fill('#kiNot', 'Merhaba'); await tikla('#kiBasvurOnay');
    await page.waitForFunction(() => calls.some(c => c.ad === 'istihdam_basvur' && c.a.p_ilan === 7 && c.a.p_mesaj === 'Merhaba'));

    // 4) Ek İşler: işi var → İş Hayatı kartı + Mesaiye git
    await page.evaluate(() => { ST.is = { id: 2, sirket_id: 168, sirket: 'BALKES A.Ş', maas: 2500, mesai_sayi: 3, toplam_maas: 7500, bugun_yapildi: false, kasa_yeter: true }; ekIslerEkrani(); });
    await page.waitForSelector('#kiIsKart #kiMesai');
    assert.match(await page.textContent('#kiMesai'), /Mesaiye git/, et('mesai düğmesi'));
    assert.deepEqual(await tasma(), [], et('ek işler taşma'));
    await cek('ek_isler');
    await temizle(); await page.evaluate(() => document.querySelector('#kiMesai').click());
    await page.waitForFunction(() => calls.some(c => c.ad === 'istihdam_mesai'));
    await page.waitForFunction(() => { const b = document.querySelector('#kiMesai'); return b && b.disabled && /tamam/.test(b.textContent); });

    // 5) Mağaza: tahmini getiri kartı
    await page.evaluate(() => magazaEkrani());
    await page.waitForSelector('#kiMagaza');
    const mg = await page.textContent('#kiMagaza');
    assert.match(mg, /400\.000/, et('paket miktarı')); assert.match(mg, /5\.000/, et('paket getirisi'));
    assert.deepEqual(await tasma(), [], et('mağaza taşma'));
    await cek('magaza');

    // 6) Eski sunucu: hiçbir şey eklenmez, hata yok
    await page.evaluate(() => { ESKI = true; sirketTekSirketEkrani(168, 'genel'); });
    await page.waitForSelector('.sm-tabs');
    await page.waitForTimeout(400);
    assert.equal(await page.$('#kiKademe'), null, et('eski sunucuda kart yok'));
    await page.evaluate(() => ekIslerEkrani());
    await page.waitForSelector('.ei-ust'); await page.waitForTimeout(400);
    assert.equal(await page.$('#kiIsKart'), null, et('eski sunucuda iş kartı yok'));
    await page.evaluate(() => magazaEkrani());
    await page.waitForSelector('#mgEkran', { state: 'attached' }); await page.waitForTimeout(400);
    assert.equal(await page.$('#kiMagaza'), null, et('eski sunucuda mağaza kartı yok'));
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'sayfa hatası yok');
  console.log('kademe_istihdam_arayuz: tamam');
})().catch(e => { console.error(e); process.exit(1); });
