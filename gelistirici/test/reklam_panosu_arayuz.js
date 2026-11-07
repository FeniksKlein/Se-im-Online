// Afiş Stüdyosu ve Reklam Panoları: ekranlar, kiralama akışı, Gündem şeridi. Ağ yok; sahte RPC.
// NODE_PATH=/opt/npm-tools/node_modules node test/reklam_panosu_arayuz.js [ekran-görüntüsü-klasörü]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const html = fs.readFileSync(process.env.HTML_PATH || path.join(__dirname, '../dist/index.html'), 'utf8');
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR' });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('**/*', r => r.abort());
    await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
    await page.evaluate(() => {
      window.calls = [];
      const bit = new Date(Date.now() + 2 * 864e5).toISOString(), bas = new Date(Date.now() - 3600e3).toISOString();
      const t1 = { v: 1, zemin: { tip: 'gunes', r1: '#c62828', r2: '#F7E7C6' }, ogeler: [{ t: 'metin', m: 'YENİ BİR SABAH', x: 500, y: 220, boy: 90, renk: '#1b1b1b', font: 'blok', hiza: 'middle' }, { t: 'amblem', id: 'a_basak', renk: '#fff', arka: '#c62828', x: 500, y: 90, s: 90 }], efekt: { doku: 'kagit' } };
      const t2 = { v: 1, zemin: { tip: 'isinsal', r1: '#FFE14D', r2: '#FFA000' }, ogeler: [{ t: 'sekil', sekil: 'rozet', x: 810, y: 215, w: 300, h: 300, renk: '#E30A17' }, { t: 'metin', m: '%30', x: 810, y: 200, boy: 100, renk: '#fff', font: 'blok' }, { t: 'metin', m: 'Feniks Market', x: 60, y: 160, boy: 64, renk: '#111', font: 'blok', hiza: 'start' }] };
      const ilFiyat = (id, g, slot, dolu) => ({ id, ad: id === 35 ? 'İzmir' : id === 34 ? 'İstanbul' : id === 69 ? 'Bayburt' : 'İl ' + id, fiyat: { gunluk: g, slot, dolu, sezon: true, sezon_carpan: 1.35, belediye_carpan: 1, doluluk_carpan: 0.6 }, bos: { slot: 1, bos: new Date().toISOString() } });
      window.MERKEZ = {
        ayar: { acik: true, en_uzun_gun: 30, secim_gunu_yasak: true, secim_carpan: 1.35, doluluk_carpan: 0.6, sira_gun: 7, il_taban: 6000, ulusal_gunluk: 90000, ulusal_slot: 3 },
        sezon: true, yasak: false, il_id: 35, moderator: true,
        kaynaklar: [{ tur: 'oyuncu', id: null, ad: 'ArvenTora', kasa: 181378, odeme: true, renk: '#ef6c00', amblem: 'a_basak' }, { tur: 'parti', id: 21, ad: 'Milli Çelişki Partisi', kasa: 150000, odeme: true, renk: '#ef6c00', amblem: 'a_basak', kisa: 'MÇP' }, { tur: 'sirket', id: 100, ad: 'Feniks Market', kasa: 192045, odeme: true }],
        belediye: { il_id: 35, il: 'İzmir', carpan: 1, son_degisim: null, gelir_7: 41000, gelir_toplam: 120000 },
        afisler: [{ id: 5, ad: 'Sabah afişi', sahip_tur: 'parti', sahip_id: 21, tasarim: t1, yayinda: true }],
        yayinlarim: [{ id: 9, afis_id: 5, ad: 'Sabah afişi', tasarim: t1, sahip_tur: 'parti', sahip_ad: 'Milli Çelişki Partisi', kapsam: 'il', il: 'İzmir', il_id: 35, bas, bit, gun: 3, durum: 'aktif', gosterim: 18, begeni: 4, tutar: 58900, iade: 0 }],
        iller: Object.keys(VERI.harita.il).map(Number).map(id => ilFiyat(id, id === 34 ? 50750 : id === 35 ? 20450 : 1650, id === 34 ? 6 : id === 35 ? 5 : 2, id === 35 ? 1 : id === 34 ? 6 : 0)),
        ulke: { fiyat: { gunluk: 124600, slot: 3, dolu: 1, sezon: true }, bos: { slot: 2, bos: new Date().toISOString() } },
        sikayetler: [{ yayin: { id: 11, tasarim: t2, sahip_ad: 'Feniks Market', kapsam: 'ulke' }, sayi: 2, nedenler: ['Yanıltıcı indirim iddiası, gerçek değil'] }]
      };
      window.VITRIN = { il_id: 35, il: 'İzmir', acik: true, yasak: false, gizlenen: 0,
        ulke: [{ id: 11, ad: 'Kampanya', tasarim: t2, sahip_tur: 'sirket', sahip_ad: 'Feniks Market', kapsam: 'ulke', slot: 1, bas, bit, gosterim: 31, begeni: 7, begendim: false, durum: 'aktif' }],
        yerel: [{ id: 9, ad: 'Sabah afişi', tasarim: t1, sahip_tur: 'parti', sahip_ad: 'Milli Çelişki Partisi', kapsam: 'il', il: 'İzmir', slot: 1, bas, bit, gosterim: 18, begeni: 4, begendim: true, durum: 'aktif' }],
        fiyat_il: { gunluk: 20450 }, fiyat_ulke: { gunluk: 124600 } };
      API = { rpc: async (ad, args) => { calls.push({ ad, args });
        if (ad === 'pano_merkez') return MERKEZ; if (ad === 'pano_vitrin') return VITRIN;
        if (ad === 'kimlikler') return { ArvenTora: { avatar: '3-4-1-0-2-5-1' } };
        if (ad === 'pano_teklif') return { kapsam: args.p_kapsam, il: 'İzmir', gun: args.p_gun, gunluk: 20450, indirim: args.p_gun >= 7 ? 0.1 : args.p_gun >= 3 ? 0.04 : 0, toplam: Math.round(20450 * args.p_gun * (args.p_gun >= 7 ? 0.9 : args.p_gun >= 3 ? 0.96 : 1)), bas: new Date().toISOString(), bit, hemen: true, sira_dolu: false, slot: 2, gelir_yeri: 'İzmir Belediyesi kasası', yasak_uyari: true, fiyat: { sezon: true, sezon_carpan: 1.35, dolu: 1, slot: 5 } };
        if (ad === 'afis_kaydet') return { id: 6, tamam: true };
        if (ad === 'pano_kirala') return { tamam: true, id: 12, bas: new Date().toISOString(), bit, tutar: 58900, hemen: true, il: 'İzmir', kapsam: 'il' };
        if (ad === 'pano_begen') return { begendim: false, begeni: 3 };
        if (ad === 'durum') return D.durum;
        throw new Error('Beklenmeyen RPC: ' + ad); } };
      D.durum = { simdi: new Date().toISOString(), profil: { il_id: 35, kad: 'ArvenTora', parti: { id: 21, ad: 'Milli Çelişki Partisi', renk: '#ef6c00', amblem: 'a_basak', kisa: 'MÇP' }, makamlar: [], cuzdan: { para: 181378 } } };
      D.sekme = 'gundem';
    });
    // 1) Panolar ekranı
    await page.evaluate(() => ekranAc(reklamPanolariEkrani));
    await page.waitForSelector('text=Ülke geneli dev panolar');
    const t = await page.locator('#icerik').textContent();
    assert.match(t, /Reklam Panoları/); assert.match(t, /İzmir panoları/); assert.match(t, /KİRALIK/); assert.match(t, /Seçim sezonu/);
    assert.match(t, /Belediye reklam tarifesi/); assert.match(t, /Şikâyet edilen reklamlar/); assert.match(t, /Türkiye reklam haritası/);
    assert.equal(await page.locator('.rp-harita path').count(), 81);
    if (shot) { await page.screenshot({ path: path.join(shot, '1_panolar.png') }); await page.screenshot({ path: path.join(shot, '1b_panolar_tam.png'), fullPage: true }); }
    // Harita: il bilgisi
    await page.locator('.rp-harita path[data-id="34"]').dispatchEvent('click');
    await page.waitForSelector('text=Bu ilde kirala');
    assert.match(await page.locator('#rpHaritaBilgi').textContent(), /İstanbul[\s\S]*6 \/ 6 dolu/);
    // 2) Stüdyo
    await page.evaluate(() => ekranAc(function () { return afisStudyosu(null); }));
    await page.waitForSelector('#rpTuval g[data-i]');
    if (shot) await page.screenshot({ path: path.join(shot, '2_studyo.png') });
    const ogeSay = await page.locator('#rpTuval g[data-i]').count();
    assert.ok(ogeSay >= 5, 'şablon öğeleri çizilmeli');
    // Şablon değiştir
    await page.locator('.rp-sablon[data-k="neon"]').click();
    await page.waitForFunction(() => document.querySelectorAll('#rpTuval text').length >= 3);
    if (shot) await page.screenshot({ path: path.join(shot, '3_neon.png') });
    // Yazı seç ve sürükle
    const g0 = page.locator('#rpTuval g[data-i="0"]');
    const bb = await g0.boundingBox();
    await page.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2); await page.mouse.down();
    await page.mouse.move(bb.x + bb.width / 2 + 10, bb.y + bb.height / 2 + 40, { steps: 6 }); await page.mouse.up();
    await page.waitForSelector('#rpMetin');
    const yeniY = await page.evaluate(() => RP_DURUM && window.afisStudyosu && document.querySelector('#rpTuval g[data-i="0"] text tspan').getAttribute('y'));
    assert.ok(Number(yeniY) > 140, 'sürükleme yazıyı aşağı taşımalı: ' + yeniY);
    await page.fill('#rpMetin', 'İZMİR İÇİN\nYENİDEN');
    await page.waitForFunction(() => /İZMİR İÇİN/.test(document.querySelector('#rpTuval').textContent));
    await page.locator('[data-st="anahtar"][data-k="kontur"]').click();
    if (shot) await page.screenshot({ path: path.join(shot, '4_duzenle.png') });
    // Geri al
    await page.locator('[data-st="geri"]').first().click();
    // Slogan ustası
    await page.locator('[data-st="slogan"]').first().click();
    await page.waitForSelector('.rp-slogan');
    await page.waitForTimeout(400); if (shot) await page.screenshot({ path: path.join(shot, '5_slogan.png') });
    await page.locator('.rp-slogan').first().click();
    // Öğe ekle: bayrak, zemin
    await page.locator('[data-st="sekme"][data-k="oge"]').click();
    await page.locator('[data-st="ekle"][data-k="bayrak"]').click();
    await page.locator('[data-st="sekme"][data-k="zemin"]').click();
    await page.locator('[data-st="sihir"]').click();
    if (shot) await page.screenshot({ path: path.join(shot, '6_zemin.png') });
    // Kaydet ve panoya as
    await page.locator('[data-st="as"]').click();
    await page.waitForSelector('#rpAfisAd'); await page.fill('#rpAfisAd', 'İzmir neon'); await page.click('#rpAfisKaydetOnay');
    await page.waitForFunction(() => calls.some(c => c.ad === 'afis_kaydet'));
    const kayit = await page.evaluate(() => calls.find(c => c.ad === 'afis_kaydet').args);
    assert.equal(kayit.p_ad, 'İzmir neon'); assert.equal(kayit.p_sahip_tur, 'oyuncu'); assert.ok(Array.isArray(kayit.p_tasarim.ogeler));
    // Sunucu doğrulamasıyla aynı kurallar: renkler ve seçenekler
    const ihlal = await page.evaluate(() => {
      const t = calls.find(c => c.ad === 'afis_kaydet').args.p_tasarim, bad = [];
      const kontrol = o => Object.entries(o).forEach(([k, v]) => {
        if (!/^[a-z0-9_]{1,16}$/.test(k)) bad.push('anahtar ' + k);
        if (k === 'm') return;
        if (typeof v === 'string') {
          if (['renk', 'arka', 'kenar', 'kontur', 'r1', 'r2', 'r3'].includes(k)) { if (!/^#[0-9A-Fa-f]{6}$/.test(v)) bad.push(k + '=' + v); }
          else if (k === 'kod') { if (!/^[0-9]{1,2}(-[0-9]{1,2}){5,6}$/.test(v)) bad.push('kod'); }
          else if (!/^[a-z0-9_]{1,24}$/.test(v)) bad.push(k + '=' + v);
        } else if (v !== null && typeof v === 'object') bad.push('iç içe ' + k);
      });
      t.ogeler.forEach(kontrol); kontrol(t.zemin || {}); kontrol(t.efekt || {});
      return bad;
    });
    assert.deepEqual(ihlal, []);
    await page.waitForSelector('#rpTeklif .rp-teklif-toplam');
    await page.waitForTimeout(400); if (shot) await page.screenshot({ path: path.join(shot, '7_kirala.png') });
    await page.locator('[data-gun="7"]').click();
    await page.waitForFunction(() => /%10/.test(document.querySelector('#rpTeklif').textContent));
    await page.click('#rpKiraOde');
    await page.waitForSelector('.rp-kutlama');
    const kira = await page.evaluate(() => calls.find(c => c.ad === 'pano_kirala').args);
    assert.equal(kira.p_gun, 7); assert.equal(kira.p_kapsam, 'il'); assert.equal(kira.p_il, 35); assert.equal(kira.p_beklenen, Math.round(20450 * 7 * 0.9));
    await page.waitForTimeout(1500);
    if (shot) await page.screenshot({ path: path.join(shot, '8_kutlama.png') });
    await page.click('#rpKutlamaTamam');
    await page.waitForSelector('text=Ülke geneli dev panolar');
    // 3) Gündem şeridi (Gündem başlığı çizildiğinde)
    await page.evaluate(() => { D.yigin = []; D.sekme = 'gundem'; RP_DURUM.vitrinT = 0; iskelet('Gündem', '<div class="kart">Akış</div>'); });
    await page.waitForSelector('#rpSerit .rp-kare');
    assert.match(await page.locator('#rpSerit').textContent(), /İzmir panosu[\s\S]*2 reklam/);
    if (shot) await page.screenshot({ path: path.join(shot, '9_gundem.png') });
    await page.locator('#rpSerit .rp-kare.aktif').click();
    await page.waitForSelector('text=Ödeyen');
    await page.waitForTimeout(400); if (shot) await page.screenshot({ path: path.join(shot, '10_detay.png') });
    // Menü çekmecesinde bağlantı
    await page.evaluate(() => { modalKapat(); });
    const menu = await page.evaluate(() => typeof soPa === 'function');
    assert.ok(menu);
    assert.deepEqual(errors, []);
    console.log('reklam_panosu_arayuz: tamam');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
