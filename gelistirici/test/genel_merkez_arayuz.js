// Parti Genel Merkezleri arayüz testi (sahte RPC; 390 ve 320 px) — 27.11.2026
// Sahne (bina SVG, kademe + donanım), hedef çubukları, kademe ve donanım önizleme, yönetim katı, sayılar, katlar, pano,
// kampanya (ürün kapalı/açık), bütün genel merkezler şeridi, parti sayfası kartı, menü karosu, bildirim rotası, taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/genel_merkez_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [], digerHata = []; let no = 0;
  for (const gen of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: gen, height: gen === 320 ? 640 : 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
    // Parti sayfasının öteki kartları (ittifak, GBY görev, kasa, teşkilat) bu testin yalın sahte verisiyle hata verir; onlar sayılmaz.
    page.on('pageerror', e => { if (/ittifakKartCiz|gbyGorevCiz|partiKasaCiz|teskilatKartCiz/.test(String(e.stack || ''))) digerHata.push(e.message.slice(0, 120)); else hatalar.push(gen + ': ' + e.message.slice(0, 300) + ' ' + String(e.stack || '').split('\n').slice(1, 3).join(' | ')); });
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => typeof window.genelMerkezAc === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = [];
      const now = Date.now(), iso = (ms) => new Date(now + ms).toISOString();
      const KAD = [{ no: 1, ad: 'Kuruluş Bürosu', uye: 0, il: 0, il_baskani: 0, bedel: 0, gby: 4, il_yk: 5, stant: 1 }, { no: 2, ad: 'Genel Merkez Binası', uye: 50, il: 15, il_baskani: 5, bedel: 3000000, gby: 6, il_yk: 7, stant: 1 }, { no: 3, ad: 'Genel Merkez Yerleşkesi', uye: 150, il: 40, il_baskani: 20, bedel: 12000000, gby: 8, il_yk: 9, stant: 2 }, { no: 4, ad: 'Büyük Genel Merkez', uye: 350, il: 70, il_baskani: 50, bedel: 40000000, gby: 10, il_yk: 11, stant: 3 }];
      window.HAZIR = false; window.INSA = false;
      const PARTILER = [{ id: 1, kisa: 'CYP', ad: 'Cumhuriyet Yolu Partisi', renk: '#c62828', kademe: 3, uye: 396, prestij: 0 }, { id: 5, kisa: 'EÖP', ad: 'Emek ve Özgürlük Partisi', renk: '#f2b233', kademe: 4, uye: 410, prestij: 3 },
        { id: 2, kisa: 'MBP', ad: 'Milli Birlik Partisi', renk: '#2B4FB8', kademe: 1, uye: 154, prestij: 1 }, { id: 25, kisa: 'DETP', ad: 'Demokratik Türkiye Partisi', renk: '#2e9e5b', kademe: 1, uye: 23, prestij: 0 }];
      window.URUN = false;
      window.panel = (pid) => {
        const kendi = pid == null || pid === 1, q = Object.assign({}, PARTILER.find(x => x.id === (kendi ? 1 : pid)) || PARTILER[0]); if (kendi && INSA) q.kademe = 4;
        const ilb = kendi ? (HAZIR ? 52 : 46) : 52, snk = q.kademe < 4 ? KAD[q.kademe] : null, kasa = HAZIR ? 45200000 : 4036540, tamam = !!snk && q.uye >= snk.uye && ilb >= snk.il_baskani, s = q.prestij, esik = [10, 25, 50], katki = [0, 12, 32, 61][s];
        return { simdi: iso(0), parti: { id: q.id, ad: q.ad, kisa: q.kisa, renk: q.renk, amblem: 'a_basak', kurulus: iso(-5 * 864e5) }, uyeyim: kendi, rol: kendi ? 'gb' : null, gm: kendi, sehir: { id: 6, ad: 'Ankara' },
          kademe: { no: q.kademe, ad: KAD[q.kademe - 1].ad, aciklama: '', olcu: { uye: q.uye, il: 81, il_baskani: ilb }, sonraki: snk, liste: KAD, avantaj: { gby: KAD[q.kademe - 1].gby, il_yk: KAD[q.kademe - 1].il_yk, stant: KAD[q.kademe - 1].stant },
            kosul_tamam: tamam, kasa: kendi ? kasa : null, yukseltebilir: kendi && tamam && kasa >= snk.bedel },
          fon: { bakiye: 220000 + (window.BAGIS || 0), toplam: 220000 + (window.BAGIS || 0), bagisci: 2, benim: window.BAGIS || 0, liste: [{ kad: 'caneren', ad: 'Eren Bal', tutar: 200000, magaza: true, magaza_adet: 2 }, { kad: 'gencer', ad: 'Abdullah Gencer', tutar: 20000 + (window.BAGIS || 0), magaza: false, magaza_adet: 0 }] },
          prestij: { seviye: s, ad: ['Standart', 'Bronz Donanım', 'Gümüş Donanım', 'Altın Donanım'][s], katki, esik, sonraki: s < 3 ? esik[s] : null, sonraki_ad: s < 3 ? ['Bronz Donanım', 'Gümüş Donanım', 'Altın Donanım'][s] : null,
            tutar: 100000, hesap_gun: 3, urun_acik: URUN, katki_verebilir: kendi, liste: katki ? [{ kad: 'ahmet', ad: 'Ahmet Yılmaz', adet: 6 }, { kad: 'zeynep', ad: 'Zeynep Kaya', adet: 4 }] : [] },
          yonetim: { gb: { kad: 'gencer', ad: 'Abdullah Gencer Karamanlıoğulları' }, vekil: null, disiplin: 7,
            gby: [{ kad: 'a1', ad: 'Yıldıray Yürekoğlu', gorev: 'Teşkilattan Sorumlu', alanlar: ['teskilat'] }, { kad: 'a2', ad: 'Ataman Fotoğlu', gorev: 'Siyasi ve Hukuki İşlerden Sorumlu', alanlar: ['hukuk', 'miting'] },
              { kad: 'a3', ad: 'Mehmet Mert', gorev: null, alanlar: ['mali'] }, { kad: 'a4', ad: 'Onur Soydan', gorev: null, alanlar: [] }, { kad: 'a5', ad: 'Zeynep Kaya', gorev: 'Tanıtım ve Medyadan Sorumlu', alanlar: ['tanitim'] }] },
          sayilar: { uye: q.uye, aktif_14g: q.uye, aktif_24s: 210, yeni_7g: 41, il: 81, il_baskani: 46, il_baskani_secilmis: 12, mv: 164, belediye: 23 },
          mitingler: [{ id: 5, baslik: 'Ankara Büyük Buluşması', bas: iso(-600e3), bit: iso(3000e3), il: 'Ankara', il_orgut: false, canli: true }, { id: 6, baslik: 'İstanbul Teşkilat Buluşması', bas: iso(26 * 3600e3), bit: iso(27 * 3600e3), il: 'İstanbul', il_orgut: true, canli: false }],
          aciklamalar: [{ id: 7, baslik: 'İstanbul için yeni dönem', il_id: 34, il: 'İstanbul', zaman: iso(-7200e3) }],
          partiler: PARTILER };
      };
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'genel_merkez_panel') return panel(a.p_parti);
        if (ad === 'genel_merkez_bagis') { window.BAGIS = a.p_tutar; return panel(a.p_parti); }
        if (ad === 'genel_merkez_yukselt') { INSA = true; return panel(1); }
        if (ad === 'parti_detay') return { id: a.p_parti, ad: 'Cumhuriyet Yolu Partisi', kisa: 'CYP', renk: '#c62828', amblem: 'a_basak', uye: 396, vekil: 0, belediye: 0, uyesiyim: true, sistem: true, kurulus: iso(-5 * 864e5), kurulus_bit: iso(-4 * 864e5), gb: 'gencer', kurucu: 'gencer', uyeler: [], gby: [], tuzuk: '', iller: [], makamlar: [] };
        if (ad === 'il_masa_benim') return { parti_id: 1, parti: 'CYP', il_id: 6, il: 'Ankara', rol: null, gm: true, gb: true, yontem: 'secim' };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: iso(0), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari|kimlik/.test(ad)) return [];
        window.bos = (window.bos || []).concat(ad);
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 6, kad: 'gencer', gb: true, parti: { id: 1, kisa: 'CYP', renk: '#c62828' }, makamlar: [], cuzdan: { para: 45000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: iso(0), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    // Oyunun kendiliğinden açtığı duyuru pencereleri (ör. vergi bilgilendirmesi) ekran görüntüsünü örtmesin
    const temizle = () => page.evaluate(() => { try { const m = document.getElementById('modal'); if (m && typeof modalKapat === 'function') modalKapat(); } catch (_) {} });
    const tikla = async (sel) => { await page.waitForSelector(sel); await page.$eval(sel, el => el.click()); };
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.waitForTimeout(700); await temizle(); const h = await page.evaluate(() => { const i = document.getElementById('icerik'); return i ? i.scrollHeight : 0; }); await page.setViewportSize({ width: gen, height: Math.min(6000, Math.max(640, h + 160)) }); await page.waitForTimeout(300); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); await page.setViewportSize({ width: gen, height: gen === 320 ? 640 : 844 }); } };
    const tasma = async () => page.evaluate(() => [...document.querySelectorAll('#icerik *')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.gmz-serit') && !el.closest('svg'); }).map(el => (el.className || el.tagName) + ':' + Math.round(el.getBoundingClientRect().right)).slice(0, 5));

    // 1) Kendi partim: kademe 3, donanımsız
    await page.evaluate(() => genelMerkezAc());
    await page.waitForSelector('#gmzSahne .gmz-svg');
    let t = await page.textContent('#icerik');
    assert.match(t, /CYP Genel Merkezi/, et('levha'));
    assert.match(t, /Cumhuriyet Yolu Partisi · Ankara/, et('şehir'));
    assert.match(t, /Genel Başkansın/, et('rol'));
    assert.match(t, /Bina: Genel Merkez Yerleşkesi/, et('kademe adı'));
    assert.match(t, /Sıradaki: Büyük Genel Merkez/, et('sıradaki kademe'));
    assert.match(t, /396 \/ 350 ✓/, et('üye hedefi tamam'));
    assert.match(t, /46 \/ 50/, et('il başkanı hedefi'));
    assert.match(t, /gerçek parayla alınmaz/, et('gerçek parayla alınmaz notu'));
    assert.match(t, /Bu kademenin sağladıkları: 8 genel başkan yardımcısı · il yönetim kurullarında 9 üye · il başına günde 2 seçim standı/, et('kademe avantajı'));
    assert.match(t, /4,3 milyon ₺ \/ 40 milyon ₺/, et('inşaat bedeli: fon + kasa'));
    assert.match(t, /İnşaat fonu 220\.000 ₺ \+ parti kasası 4\.036\.540 ₺/, et('fon ve kasa dökümü'));
    assert.equal(await page.$$eval('#gmzFon .gmz-satir.magaza', x => x.length), 1, et('mağaza destekçisi sarı'));
    assert.match(await page.textContent('#gmzFon .gmz-satir.magaza'), /Eren Bal ★.*2 mağaza katkısı.*200\.000 ₺/, et('destekçi satırı'));
    assert.equal(await page.$eval('#gmzFon .gmz-satir.magaza b', el => getComputedStyle(el).color), 'rgb(242, 196, 109)', et('sarı renk'));
    assert.match(t, /Kazandırır: 10 genel başkan yardımcısı/, et('sıradaki avantaj'));
    assert.ok(await page.$('#gmzYukselt[disabled]'), et('şart eksikken inşa düğmesi kapalı'));
    assert.match(t, /10 GBY · il kurulu 11 · stant 3/, et('avantaj tablosu'));
    assert.match(t, /Abdullah Gencer Karamanlıoğulları/, et('genel başkan'));
    assert.match(t, /Teşkilattan Sorumlu/, et('GBY görevi'));
    assert.match(t, /Mali işler/, et('GBY alanı (görev yoksa)'));
    assert.match(t, /Merkez Yönetim Kurulu: 6 kişi · Disiplin Kurulu: 7 asil üye/, et('kurullar'));
    assert.match(t, /164milletvekili/, et('sayılar'));
    assert.match(t, /CANLI/, et('canlı miting'));
    assert.match(t, /İstanbul İl Başkanlığı/, et('il açıklaması'));
    assert.match(t, /yakında mağazada/, et('ürün kapalı notu'));
    assert.ok(!(await page.$('#gmzMagaza')), et('ürün kapalıyken mağaza düğmesi yok'));
    assert.ok(await page.$('#gmzSahne.p0'), et('donanımsız sahne'));
    assert.equal(await page.$$eval('.gmz-merdiven button', x => x.length), 4, et('4 kademe'));
    assert.equal(await page.$$eval('.gmz-don button', x => x.length), 4, et('4 donanım'));
    assert.equal(await page.$$eval('.gmz-serit button', x => x.length), 4, et('bütün genel merkezler'));
    assert.deepEqual(await tasma(), [], et('panel taşma'));
    await cek('panel');

    // 2) Önizleme: altın donanım + en büyük kademe, geri dönüş
    await tikla('[data-gmzp="3"]');
    await page.waitForSelector('#gmzSahne.p3 .gmz-onizle');
    assert.match(await page.textContent('.gmz-onizle'), /Genel Merkez Yerleşkesi · Altın Donanım/, et('donanım önizleme'));
    assert.match(await page.textContent('#gmzDonNe'), /altın kubbe/, et('donanım açıklaması'));
    await tikla('[data-gmzk="4"]');
    await page.waitForFunction(() => /Büyük Genel Merkez · Altın Donanım/.test((document.querySelector('.gmz-onizle') || {}).textContent || ''));
    assert.deepEqual(await tasma(), [], et('önizleme taşma'));
    await cek('onizleme');
    await tikla('#gmzGercek');
    await page.waitForSelector('#gmzSahne.p0');
    assert.ok(!(await page.$('.gmz-onizle')), et('gerçek görünüme dönüş'));

    // 2a) İnşaat fonuna bağış
    await tikla('[data-gmzb="50000"]');
    await tikla('#gmzBOk');
    await page.waitForSelector('#modal #evet');
    assert.match(await page.textContent('#modal'), /50\.000 ₺ bağışlansın mı/, et('bağış onayı'));
    await tikla('#modal #evet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'genel_merkez_bagis' && c.a.p_tutar === 50000 && c.a.p_parti === 1) && /Senin bağışın: 50\.000 ₺/.test((document.getElementById('gmzFon') || {}).textContent || ''));
    await page.evaluate(() => { window.BAGIS = 0; });

    // 2b) Şartlar ve kasa tamam: inşa et
    await page.evaluate(() => { HAZIR = true; genelMerkezAc(); });
    await page.waitForSelector('#gmzYukselt:not([disabled])');
    assert.match(await page.textContent('#gmzYukselt'), /Büyük Genel Merkez inşa et · 40\.000\.000 ₺/, et('inşa düğmesi'));
    await tikla('#gmzYukselt');
    await page.waitForSelector('#modal #evet');
    assert.match(await page.textContent('#modal'), /geri alınamaz/, et('inşaat onayı'));
    await tikla('#modal #evet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'genel_merkez_yukselt') && /Bina: Büyük Genel Merkez/.test((document.getElementById('icerik') || {}).textContent || ''));
    assert.match(await page.textContent('#gmzBina'), /En büyük kademeye ulaşıldı/, et('inşaat sonrası'));
    assert.ok(!(await page.$('#gmzYukselt')), et('son kademede inşa düğmesi yok'));
    await page.evaluate(() => { HAZIR = false; INSA = false; });

    // 3) Katlar ve pano bağlantıları
    await tikla('[data-gmzil="34"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_masa' && c.a.p_il === 34 && c.a.p_parti === 1));
    await page.evaluate(() => genelMerkezAc());
    await page.waitForSelector('[data-gmzkat="il"]');
    await tikla('[data-gmzkat="il"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'il_masa_genel'));

    // 4) Başka parti: en büyük kademe + altın donanım; ürün açık ama üye değil
    await page.evaluate(() => { URUN = true; genelMerkezAc(5); });
    await page.waitForSelector('#gmzSahne.p3');
    t = await page.textContent('#icerik');
    assert.match(t, /EÖP Genel Merkezi/, et('başka parti'));
    assert.match(t, /★ Altın Donanım/, et('donanım çipi'));
    assert.match(t, /En büyük kademeye ulaşıldı/, et('son kademe'));
    assert.match(t, /En üst donanıma ulaşıldı/, et('son donanım'));
    assert.match(t, /Ahmet Yılmaz/, et('katkı listesi'));
    assert.ok(!(await page.$('#gmzMagaza')), et('üye olmayana mağaza düğmesi yok'));
    assert.ok(!(await page.$('[data-gmzkat="pdk"]')), et('üye olmayana disiplin kurulu yok'));
    assert.deepEqual(await tasma(), [], et('altın panel taşma'));
    await cek('altin');
    await tikla('.gmz-serit [data-gmzparti="2"]');
    await page.waitForFunction(() => /MBP Genel Merkezi/.test((document.getElementById('icerik') || {}).textContent || ''));
    assert.ok(await page.$('#gmzSahne.p1'), et('bronz sahne'));
    assert.match(await page.textContent('#icerik'), /12 \/ 25 katkı/, et('donanım ilerlemesi'));

    // 5) Ürün açık + üye: mağaza düğmesi
    await page.evaluate(() => genelMerkezAc(1));
    await page.waitForSelector('#gmzMagaza');
    assert.match(await page.textContent('#gmzDonanim'), /100\.000 ₺/, et('katkı tutarı'));

    // 6) Parti sayfası kartı, menü, bildirim rotası
    await page.evaluate(() => { calls.length = 0; ekranAc(() => partiDetay(1)); });
    await page.waitForSelector('#gmzParti .gmz-svg');
    assert.match(await page.textContent('#gmzParti'), /CYP Genel Merkezi/, et('parti sayfası kartı'));
    assert.equal(await page.$$eval('.m2-gm', x => x.length), 0, et('eski kampanya kartı çizilmiyor'));
    assert.ok(await page.$eval('#gmzParti', el => el.getBoundingClientRect().right <= innerWidth + 1 && el.scrollWidth <= el.clientWidth + 1), et('parti sayfası kartı taşmıyor'));
    await cek('parti_sayfasi');
    await tikla('#gmzParti');
    await page.waitForSelector('#gmzSahne');
    await page.evaluate(() => soPaMenu());
    await page.waitForFunction(() => /Partinin binası, yönetim katı/.test(document.body.innerText));
    await page.evaluate(() => { try { soPaMenuKapat(); } catch (_) {} });
    const rota = await page.evaluate(() => ['[Genel Merkez] CYP genel merkezi Bronz Donanım kazandı.', 'Partin CYP genel merkezi Altın Donanım kazandı. Rozetin adının yanında.'].map(m => (bmKategori(m) || {}).rota));
    assert.deepEqual(rota, ['gmerkez', 'gmerkez'], et('bildirim rotası ' + rota.join(',')));
    await page.close();
  }
  await browser.close();
  if (hatalar.length) { console.error('Sayfa hataları:\n' + hatalar.join('\n')); process.exit(1); }
  console.log('genel_merkez_arayuz: TAMAM (390 ve 320 px)');
})().catch(e => { console.error(e); process.exit(1); });
