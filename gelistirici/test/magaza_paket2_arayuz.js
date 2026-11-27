// Mağaza Paketi 2 arayüz testi (sahte RPC; 390 ve 320 px) — 27.11.2026
// Mağaza bölümleri ve hak kullanma pencereleri (vitrin, manşet, plaka, hediye/parti kartı), Gündem manşet + destekçi duvarı +
// manşet onayı, Kürsü "Öne çıkan" etiketi, sohbet kart mesajları ve rozetler, kurultay Kongre Paketi, Lansman Sahnesi,
// Genel Merkez (parti sayfası ve ekran), mazbata, zafer sahnesi, taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/magaza_paket2_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
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
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => window.M2 && typeof window.M2_MAGAZA === 'function' && typeof magazaEkrani === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = [];
      const now = Date.now(), iso = (ms) => new Date(now + ms).toISOString();
      const urun = (urun_id, ad, tur, fiyat, aciklama, ek) => Object.assign({ urun_id, ad, tur, fiyat, aciklama, miktar: 0, gun: 0, hak: null, etiket: null, sahip: false, alinabilir: true }, ek || {});
      window.ST = { jeton: { m2_vitrin: 1, m2_manset: 1, m2_hediye_kart: 1, m2_parti_kart: 4, plaka_degis: 1 } };
      const m2 = () => ({ jeton: ST.jeton, plaka: { metin: '35 AY 1923', il: 35, harf: 'AY', rakam: '1923', secildi: true, makam: true }, plaka_hak: true, seckin_hak: false, il: 35,
        vitrin: { yer: 3, saat: 24, dolu: 3, sira: 2, tahmin: iso(20 * 3600e3) }, manset: { yer: 3, saat: 24, oto_saat: 12, dolu: 1, sira: 0, tahmin: iso(0) },
        yayinlarim: [{ id: 5, tur: 'kursu', durum: 'sirada', metin: 'Pazar günü Konya mitingindeyiz', sira: 2, tahmin: iso(20 * 3600e3) }],
        parti: { id: 1, ad: 'Mavi Kalkınma Partisi', kisa: 'MKP', renk: '#2B4FB8', sahne: false, gm_katki: 32, gm_seviye: 2, gm_seviye_ad: 'Gümüş Donanım', gm_sonraki: 50, yonetici: true, parti_adina: true, bagisci_bitis: iso(20 * 86400e3) },
        gm_hesap_tamam: true, gm_hesap_gun: 3, bagis_tutar: 250000, gm_tutar: 100000, parti_kart_adet: 5,
        kongre: { secim_id: 9, slogan: 'Yeniden büyük MKP' }, zaferler: [{ secim_id: 3, gorev: 'İzmir milletvekili', tarih: iso(-86400e3), mazbata: false, kutlama: true }],
        mazbata_sayi: 1, kutlama_bekleyen: null, destek: 3, yillik_bitis: null, duraklat: false });
      const paketler = [
        urun('secimonline.politics_card_30d', 'Siyaset Kartı · 30 gün', 'kart', '₺99,99', 'Kart', { gun: 30, miktar: 30000 }),
        urun('secimonline.politics_card_90d', 'Siyaset Kartı · 90 gün', 'kart', '₺249,99', 'Hemen 90.000 ₺ ve 90 gün boyunca her gün Kart ödülü.', { gun: 90, miktar: 90000, etiket: '3 ay' }),
        urun('secimonline.politics_card_365d', 'Siyaset Kartı · Yıllık', 'kart', '₺799,99', 'Hemen 365.000 ₺; aylığa göre yaklaşık 4 ay bedava. Yıllık Üye rozeti.', { gun: 365, miktar: 365000, etiket: 'Yıllık Üye' }),
        urun('secimonline.cash_1000000', 'Hazine Paketi', 'para', '₺599,99', 'Cüzdanına 1.000.000 ₺.', { miktar: 1000000, etiket: '%100 fazla' }),
        urun('secimonline.vanity_plate', 'Özel Plaka', 'kalici', '₺49,99', 'Kişisel plakan.', { hak: 'plaka', sahip: true, alinabilir: false }),
        urun('secimonline.vanity_plate_elite', 'Özel Plaka · Seçkin', 'kalici', '₺149,99', 'Tek harfli ya da 01–99 numaralı kıt plakalar.', { hak: 'plaka_seckin' }),
        urun('secimonline.plate_change', 'Plaka Değiştirme', 'jeton', '₺29,99', 'Plakanı bir kez değiştirme hakkı.', { hak: 'plaka_degis' }),
        urun('secimonline.kursu_showcase_24h', 'Kürsü Vitrini · 24 saat', 'hizmet', '₺249,99', 'Seçtiğin Kürsü paylaşımın 24 saat akışın en üstünde durur. Aynı anda en çok 3 vitrin olur.'),
        urun('secimonline.headline_24h', 'Gündem Manşeti · 24 saat', 'hizmet', '₺299,99', 'Manşetin moderasyondan sonra 24 saat haber şeridinin başında durur.'),
        urun('secimonline.mandate', 'Mazbata', 'hizmet', '₺49,99', 'Kazandığın seçim için mazbata.'),
        urun('secimonline.victory_night', 'Seçim Gecesi Kutlaması', 'hizmet', '₺49,99', 'Zafer sahnesi, tebrik kartı ve rozet.'),
        urun('secimonline.party_donation', 'Parti Kasasına Bağış', 'hizmet', '₺199,99', 'Partinin kasasına 250.000 ₺.'),
        urun('secimonline.hq_campaign', 'Genel Merkez Kampanyası', 'hizmet', '₺99,99', 'Partinin ortak hedefine katkı.'),
        urun('secimonline.launch_stage', 'Lansman Sahnesi', 'hizmet', '₺199,99', 'Partiye kalıcı ışıklı sahne.'),
        urun('secimonline.congress_pack', 'Kongre Paketi', 'hizmet', '₺99,99', 'Kurultay adaylığında bayrak ve afiş.'),
        urun('secimonline.party_card_pack', 'Parti Kart Paketi', 'hizmet', '₺399,99', '5 üyeye 30 günlük kart.'),
        urun('secimonline.gift_card_30d', 'Hediye Siyaset Kartı', 'hizmet', '₺99,99', 'Seçtiğin oyuncuya 30 günlük kart.'),
        urun('secimonline.supporter_wall_bronze', 'Destekçiler Duvarı · Bronz', 'hizmet', '₺249,99', 'Bronz kademe.'),
        urun('secimonline.supporter_wall_silver', 'Destekçiler Duvarı · Gümüş', 'hizmet', '₺499,99', 'Gümüş kademe.'),
        urun('secimonline.supporter_wall_gold', 'Destekçiler Duvarı · Altın', 'hizmet', '₺999,99', 'Altın kademe.')];
      const durum = () => ({ paketler, kart: { aktif: false, gunluk: 7500 }, haklar: ['plaka'], jetonlar: {}, unvanlar: [], parti_kimlik: {}, reklamsiz: false, satis_acik: true, para: 1500000, m2: m2() });
      const genel = { sahne: [1], gm: [{ p: 1, k: 32, s: 2 }], ay_ad: 'Kasım 2026', duraklat: false, manset_onay: 2, vitrin: [8660],
        duvar: [{ kad: 'celal', ad: 'Celal Kara', kademe: 3 }, { kad: 'mert', ad: 'Mert Demir', kademe: 2 }, { kad: 'ayse', ad: 'Ayşe Çelik Uzunsoyadlıoğlu', kademe: 1 }],
        manset: [{ id: 1, baslik: "MKP'den Konya çıkarması: Pazar günü Mevlana Meydanı'nda büyük miting", parti: { ad: 'Mavi Kalkınma Partisi' }, ad: 'Zeynep Kaya', bit: iso(11 * 3600e3) }] };
      const gonderi = (id, metin, kad) => ({ id, kad: kad || 'zeynep', unvan: null, parti: { id: 1, kisa: 'MKP', renk: '#2B4FB8' }, metin, zaman: iso(-3600e3), begeni: 4, begenmeme: 0, yanit: 1, yp: 0, alinti_sayi: 0, benim: false });
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'magaza_durum') return durum();
        if (ad === 'magaza_rozetler') return { Ben: 'p:35 AY 1923,pm,dw:3,gm:2,bb:1,yu', zeynep: 'p:06 K 07,z:Kasım 2026 zaferi,kg:Yeniden büyük MKP' };
        if (ad === 'm2_genel') return genel;
        if (ad === 'oyuncu_kart') return { kad: a.p_kad, il_ad: 'İzmir', parti: { id: 1, kisa: 'MKP', renk: '#2B4FB8' }, makamlar: [], rozetler: [], gecmis: [], karneler: [], katilim: new Date(now - 30 * 864e5).toISOString(), uyelik: new Date(now - 30 * 864e5).toISOString(), kayit: new Date(now - 30 * 864e5).toISOString() };
        if (ad === 'kursu_profil') return { liste: [{ g: Object.assign(gonderi(901, 'Pazar günü Konya mitingindeyiz, herkesi bekliyoruz!', 'Ben'), { benim: true }) }, { g: Object.assign(gonderi(902, 'Bütçe görüşmeleri için hazırız.', 'Ben'), { benim: true }) }] };
        if (ad === 'kursu_vitrin_baslat') return { id: 9, durum: 'sirada', sira: 3, tahmin: iso(21 * 3600e3) };
        if (ad === 'manset_basvur') return { id: 3, durum: 'onay' };
        if (ad === 'plaka_kaydet') return { plaka: '35 AY 1924', ucretli: true };
        if (ad === 'hediye_kart_ver') return { alan: a.p_kad, kalan: 0 };
        if (ad === 'parti_kart_ver') return { alan: a.p_kad, kalan: 3 };
        if (ad === 'kursu_akis') return { liste: [{ sira: iso(-3600e3), yp: null, vitrin: true, g: gonderi(8660, 'Vitrindeki paylaşım: pazar günü büyük miting!') }, { sira: iso(-60e3), yp: null, g: gonderi(8661, 'Sıradan bir paylaşım') }], imlec: null, vitrin: [8660] };
        if (ad === 'kursu_ben' || ad === 'kursu_gundem') return {};
        if (ad === 'vergi_rehberi') return { tanitim: true };
        if (ad === 'manset_onay_liste') return { oto_saat: 12, onay: [{ id: 3, baslik: 'Kurultayımıza bütün üyeler davetlidir', ad: 'Ali Veli', kad: 'ali', olusturma: iso(-3600e3) }],
          aktif: [{ id: 5, tur: 'kursu', durum: 'yayinda', metin: 'Vitrindeki paylaşım', ad: 'Zeynep Kaya', kad: 'zeynep' }] };
        if (ad === 'manset_karar') return { id: a.p_id, durum: a.p_onay ? 'yayinda' : 'reddedildi' };
        if (ad === 'mazbatalar') return [{ id: 1, secim_id: 3, tur: 'mv', ad: 'Ahmet Yılmaz', gorev: 'İzmir milletvekili', oy_orani: 38.4, tarih: iso(-86400e3), donem: 'Kasım 2026', kad: 'Ben' }];
        // 27.11.2026: Genel Merkez ekranı genel_merkez.js'e devredildi (bina + panel + kampanya)
        if (ad === 'genel_merkez_panel') return { simdi: iso(0), parti: { id: 1, ad: 'Mavi Kalkınma Partisi', kisa: 'MKP', renk: '#2B4FB8', amblem: 'a_basak', kurulus: iso(-5 * 864e5) }, uyeyim: true, rol: 'uye', gm: false, sehir: { id: 6, ad: 'Ankara' },
          fon: { bakiye: 0, toplam: 0, bagisci: 0, benim: 0, liste: [] }, kademe: { no: 2, ad: 'Genel Merkez Binası', avantaj: { gby: 6, il_yk: 7, stant: 1 }, kosul_tamam: false, kasa: null, yukseltebilir: false, olcu: { uye: 97, il: 81, il_baskani: 6 }, sonraki: { no: 3, ad: 'Genel Merkez Yerleşkesi', uye: 150, il: 40, il_baskani: 20 }, liste: [{ no: 1, ad: 'Kuruluş Bürosu', uye: 0, il: 0, il_baskani: 0 }, { no: 2, ad: 'Genel Merkez Binası', uye: 50, il: 15, il_baskani: 5 }, { no: 3, ad: 'Genel Merkez Yerleşkesi', uye: 150, il: 40, il_baskani: 20 }, { no: 4, ad: 'Büyük Genel Merkez', uye: 350, il: 70, il_baskani: 50 }] },
          prestij: { seviye: 2, ad: 'Gümüş Donanım', katki: 32, esik: [10, 25, 50], sonraki: 50, sonraki_ad: 'Altın Donanım', tutar: 100000, hesap_gun: 3, urun_acik: true, katki_verebilir: true, liste: [{ kad: 'ahmet', ad: 'Ahmet Yılmaz', adet: 6 }, { kad: 'zeynep', ad: 'Zeynep Kaya', adet: 4 }] },
          yonetim: { gb: { kad: 'zeynep', ad: 'Zeynep Kaya' }, vekil: null, gby: [], disiplin: 0 }, sayilar: { uye: 97, aktif_14g: 97, aktif_24s: 40, yeni_7g: 9, il: 81, il_baskani: 6, il_baskani_secilmis: 0, mv: 0, belediye: 0 },
          mitingler: [], aciklamalar: [], partiler: [{ id: 2, kisa: 'CYP', ad: 'CYP', renk: '#c62828', kademe: 3, uye: 396, prestij: 3 }, { id: 1, kisa: 'MKP', ad: 'MKP', renk: '#2B4FB8', kademe: 2, uye: 97, prestij: 2 }] };
        if (ad === 'genel_merkez') return { parti: { id: 1, ad: 'Mavi Kalkınma Partisi', kisa: 'MKP', renk: '#2B4FB8' }, katki: 32, seviye: 2, seviye_ad: 'Gümüş Donanım', esik: [10, 25, 50], sonraki: 50, sonraki_ad: 'Altın Donanım', tutar: 100000,
          liste: [{ kad: 'ahmet', ad: 'Ahmet Yılmaz', adet: 6 }, { kad: 'zeynep', ad: 'Zeynep Kaya', adet: 4 }], siralama: [{ id: 2, kisa: 'CYP', renk: '#c62828', katki: 51, seviye: 3 }, { id: 1, kisa: 'MKP', renk: '#2B4FB8', katki: 32, seviye: 2 }, { id: 3, kisa: 'DTP', renk: '#00838f', katki: 3, seviye: 0 }],
          uyesiyim: true, katki_verebilir: true, hesap_gun: 3 };
        if (ad === 'secim_detay') return { id: 9, tur: 'kurultay', asama: 'oy', oy_bas: iso(-3600e3), oy_bit: iso(3600e3), sonuc_at: iso(7200e3), oy_verdim: false,
          secenekler: [{ hedef: 1, kad: 'zeynep', kisa: 'MKP', renk: '#2B4FB8', parti_id: 1, vaat: 'Teşkilatı güçlendireceğim.', vaatler: [] }, { hedef: 2, kad: 'mert', kisa: 'MKP', renk: '#2B4FB8', parti_id: 1, vaatler: [] }] };
        if (ad === 'kongre_paketleri') return [{ kad: 'zeynep', ad: 'Zeynep Kaya', slogan: 'Yeniden büyük MKP', renk: '#2B4FB8' }];
        if (ad === 'aday_lansman_detay') return { id: 7, baslik: 'İstanbul adaylarımızla tanışın', bas: iso(-600e3), bit: iso(3000e3), durum: 'planli', canli: true, bitti: false, il: 'İstanbul', parti: { id: 1, kisa: 'MKP', renk: '#2B4FB8', amblem: 'a_basak' },
          aday_sayisi: 1, katilim: 4, hatirlat: 3, metin: 'Sunuş', duzenleyen: { ad: 'GB' }, adaylar: [{ aday_id: 241, kad: 'aday1', ad: 'Ataman Fotoğlu', il: 'İstanbul', sira: 1, alkis: 2, alkisladim: false }], mesajlar: [] };
        if (ad === 'aday_lansman_alkis') return { alkis: 3 };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: iso(0), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 35, kad: 'Ben', parti: { id: 1, kisa: 'MKP', renk: '#2B4FB8' }, makamlar: [], cuzdan: { para: 1500000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: iso(0), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      M2.kur(); M2.yok = false; M2.genelT = 0;
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const tikla = async (sel) => { await page.waitForSelector(sel); await page.$eval(sel, el => el.click()); };
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.waitForTimeout(600); const h = await page.evaluate(() => { const i = document.getElementById('icerik'); return i ? i.scrollHeight : 0; }); await page.setViewportSize({ width: gen, height: Math.min(6000, Math.max(640, h + 160)) }); await page.waitForTimeout(300); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); await page.setViewportSize({ width: gen, height: gen === 320 ? 640 : 844 }); } };
    const tasma = async () => page.evaluate(() => [...document.querySelectorAll('#icerik *, #modal *')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.kaydir,.serit,.kr-serit,.sekmeler'); }).map(el => (el.className && el.className.baseVal !== undefined ? el.tagName : el.className) || el.tagName).slice(0, 5));

    // 1) Mağaza
    await page.evaluate(() => { MGZ.rozetZaman = 0; return MGZ.durumYukle().then(() => magazaEkrani()); });
    await page.waitForSelector('.m2-bolum');
    const mg = await page.textContent('#icerik');
    for (const x of ['Uzun süreli Siyaset Kartı', 'Siyaset Kartı · Yıllık', 'Hazine Paketi', 'Seçim dönemi', 'Kürsü Vitrini · 24 saat', 'Şu an 3/3 dolu, sırada 2 kişi', 'Gündem Manşeti · 24 saat',
      'Parti ve hediye', 'MKP: Gümüş Donanım · 32 katkı · sıradaki seviyeye 18 katkı', 'Görünüş ve tanınma', 'Destekçiler Duvarı · Altın', 'Bu ay bu kademedesin', 'Vitrin ve manşetlerim', '2. sırada'])
      assert.ok(mg.includes(x), et('mağaza: ' + x));
    assert.ok(await page.$('.m2-plaka.mk.buyuk'), et('makam plakası büyük'));
    assert.deepEqual(await tasma(), [], et('mağaza taşma'));
    await cek('magaza');

    // Vitrin penceresi
    await tikla('[data-m2k="vitrin"]');
    await page.waitForSelector('[data-akis="901"]');
    assert.match(await page.textContent('#modal'), /tahmini yayın/, et('vitrin kuyruk yazısı'));
    await tikla('[data-akis="901"]'); await tikla('#m2VitrinBas');
    await page.waitForFunction(() => calls.some(c => c.ad === 'kursu_vitrin_baslat' && c.a.p_akis === 901));
    // Manşet penceresi
    await tikla('[data-m2k="manset"]');
    await page.fill('#m2Manset', 'Pazar günü Konya\'da büyük mitingimize herkesi bekliyoruz');
    assert.ok(await page.$('#m2PartiAdina'), et('parti adına seçeneği'));
    await page.$eval('#m2PartiAdina', el => { el.checked = true; });
    await cek('manset_modal');
    await tikla('#m2MansetGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'manset_basvur' && c.a.p_parti_adina === true));
    // Plaka penceresi
    await tikla('[data-m2k="plaka"]');
    await page.fill('#m2PlR', '1924');
    assert.match(await page.textContent('#m2PlOn'), /35 AY 1924/, et('plaka önizleme'));
    assert.deepEqual(await tasma(), [], et('plaka modal taşma'));
    await cek('plaka_modal');
    await tikla('#m2PlKaydet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'plaka_kaydet' && c.a.p_rakam === '1924' && c.a.p_il === 35));
    // Hediye ve parti kartı
    await tikla('[data-m2k="hediye"]'); await page.fill('#m2Kad', 'mert'); await page.fill('#m2Not', 'Hayırlı olsun'); await tikla('#m2KartVer');
    await page.waitForFunction(() => calls.some(c => c.ad === 'hediye_kart_ver' && c.a.p_kad === 'mert'));
    await tikla('[data-m2k="partiKart"]'); await page.fill('#m2Kad', 'ayse'); await tikla('#m2KartVer');
    await page.waitForFunction(() => calls.some(c => c.ad === 'parti_kart_ver' && c.a.p_kad === 'ayse'));

    // 2) Gündem: manşet, duvar, manşet onayı
    await page.evaluate(() => { D.sekme = 'gundem'; D.yigin = []; iskelet('Gündem', '<div class="serit"><span class="etiket">Gündem</span><div class="kaydir"><span>x</span></div></div><div class="kart">Gündem içeriği</div>'); });
    await page.waitForSelector('#m2Gundem .m2-manset');
    const gd = await page.textContent('#m2Gundem');
    assert.match(gd, /Manşet · Sponsorlu/, et('manşet etiketi')); assert.match(gd, /Kasım 2026 destekçileri/, et('duvar')); assert.match(gd, /Manşet onayı · 2 bekliyor/, et('mod kartı'));
    assert.deepEqual(await tasma(), [], et('gündem taşma'));
    await cek('gundem');
    await tikla('[data-m2="mansetOnay"]');
    await page.waitForSelector('[data-onay="3"]');
    await tikla('[data-onay="3"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'manset_karar' && c.a.p_id === 3 && c.a.p_onay === true));

    // 3) Kürsü vitrin etiketi
    await page.evaluate(() => kursuEkrani('ana'));
    await page.waitForSelector('.kr-g.m2-vitrin');
    assert.match(await page.textContent('.kr-g.m2-vitrin'), /Öne çıkan · Kürsü Vitrini/, et('vitrin etiketi'));
    assert.equal(await page.$$eval('.kr-g.m2-vitrin', x => x.length), 1, et('yalnız vitrindeki etiketli'));
    await cek('kursu');

    // 4) Sohbet kart mesajı ve rozetler (yeni sohbet tasarımı)
    await page.evaluate(() => { MGZ.rozet = { Ben: 'p:35 AY 1923,pm,dw:3,gm:2,bb:1,yu', zeynep: 'p:06 K 07,z:Kasım 2026 zaferi,kg:Yeniden büyük MKP' }; document.getElementById('icerik').insertAdjacentHTML('beforeend',
      '<div id="shTest"><div class="shm ilk son" data-id="1" data-kad="zeynep"><span class="shm-av"></span><div class="shm-b"><div class="shm-kim"><b>zeynep</b></div><span class="shm-tx">[Büyük Bağış] Zeynep Kaya parti kasamıza 250.000 ₺ bağışladı. Kasa: 2.090.000 ₺</span></div></div>' +
      '<div class="shm ilk son" data-id="2" data-kad="Ben"><span class="shm-av"></span><div class="shm-b"><div class="shm-kim"><b>Ben</b></div><span class="shm-tx">Merhaba</span></div></div></div>'); });
    await page.waitForSelector('#shTest .m2-kartmsj');
    const sh = await page.textContent('#shTest');
    assert.match(sh, /Büyük Bağış/, et('kart başlığı')); assert.ok(!/\[Büyük Bağış\]/.test(sh), et('köşeli önek gizlendi'));
    assert.match(sh, /06 K 07/, et('plaka rozeti')); assert.match(sh, /Kasım 2026 zaferi/, et('zafer rozeti')); assert.match(sh, /Büyük Bağışçı/, et('bağışçı rozeti (aynı parti)')); assert.match(sh, /Yıllık Üye/, et('yıllık üye'));

    // 5) Kongre Paketi: oy pusulasında ayrıcalık YOK; sohbette çip, oyuncu kartında afiş
    assert.match(sh, /Yeniden büyük MKP/, et('sohbette kongre çipi'));
    await page.evaluate(() => secimEkrani(9));
    await page.waitForSelector('.pusula-secenek');
    await page.waitForTimeout(400);
    assert.equal(await page.$$eval('#icerik .m2-kongre, #icerik .m2-plaka, #icerik .m2-cip', x => x.length), 0, et('oy pusulasında süsleme yok'));
    await cek('kongre_pusula_sade');
    await page.evaluate(() => oyuncuKart('zeynep'));
    await page.waitForSelector('#modal [data-m2kongre]');
    assert.match(await page.textContent('#modal [data-m2kongre]'), /YENİDEN BÜYÜK MKP/, et('oyuncu kartında kongre afişi'));
    if (shot) { await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_kongre_kart_' + gen + '.png') }); }
    await page.evaluate(() => modalKapat());

    // 6) Lansman Sahnesi
    await page.evaluate(() => adayLansmanAc(7));
    await page.waitForSelector('#avLansman.m2-sahne-on');
    assert.ok(await page.$('.m2-isiklar'), et('sahne ışıkları')); assert.ok(await page.$('.m2-poster'), et('parti posteri'));
    assert.deepEqual(await tasma(), [], et('sahne taşma'));
    await cek('lansman_sahne');
    await tikla('[data-alkis="241"]');
    await page.waitForSelector('.m2-konfeti');

    // 7) Genel Merkez
    await page.evaluate(() => genelMerkezEkrani(1));
    await page.waitForFunction(() => /İmtiyazlı görünüm/.test((document.getElementById('icerik') || {}).textContent || ''));
    const gmm = await page.textContent('#icerik');
    assert.match(gmm, /MKP Genel Merkezi/, et('genel merkez paneli')); assert.match(gmm, /★ Gümüş Donanım/, et('donanım')); assert.match(gmm, /Altın Donanım için32 \/ 50 katkı/, et('sonraki donanım')); assert.match(gmm, /Ahmet Yılmaz/, et('katkı listesi')); assert.ok(await page.$('#gmzMagaza'), et('mağaza düğmesi'));
    assert.deepEqual(await tasma(), [], et('genel merkez taşma'));
    await cek('genel_merkez');

    // 8) Mazbata ve zafer sahnesi
    await page.evaluate(() => { const m = document.getElementById('modal'); if (m) m.remove(); });
    await page.evaluate(() => { MGZ.durum.m2.kutlama_bekleyen = { id: 4, gorev: 'İzmir milletvekili', rozet: 'Kasım 2026 zaferi', oy_orani: 38.4 }; M2.kutlamaKontrol(); });
    await page.waitForSelector('.m2-zafer');
    assert.match(await page.textContent('.m2-zafer'), /Tebrikler, kazandın/, et('zafer sahnesi'));
    if (shot) { await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_zafer_' + gen + '.png') }); }
    await tikla('#m2ZaferTamam');
    await page.waitForFunction(() => calls.some(c => c.ad === 'kutlama_goruldu' && c.a.p_id === 4));
    await page.evaluate(() => { ST.jeton.m2_mazbata = 1; return MGZ.durumYukle().then(() => magazaEkrani()); });
    await page.waitForSelector('[data-m2k="mazbata"]');
    await page.evaluate(() => { document.querySelector('[data-m2k="mazbata"]').click(); });
    await page.waitForSelector('#modal [data-secim="3"]');
    await page.evaluate(() => { const m = document.getElementById('modal'); if (m) m.remove(); });
    await page.evaluate(() => { ST.jeton.m2_mazbata = 0; return MGZ.durumYukle().then(() => magazaEkrani()); });
    await tikla('[data-m2k="mazbatalarim"]');
    await page.waitForSelector('#modal .m2-mazbata');
    assert.match(await page.textContent('#modal'), /İzmir milletvekili seçilmiştir/, et('mazbata metni'));
    assert.match(await page.textContent('#modal'), /%38,4/, et('oy oranı'));
    assert.deepEqual(await tasma(), [], et('mazbata taşma'));
    if (shot) { await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_mazbata_' + gen + '.png') }); }
    await page.evaluate(() => { const m = document.getElementById('modal'); if (m) m.remove(); });
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('magaza_paket2_arayuz: TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
