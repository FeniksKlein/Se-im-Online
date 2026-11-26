// Aday Vitrini + Aday Lansmanı arayüz testi (sahte RPC; 390 ve 320 px) — 27.11.2026
// Vitrin (harita, parti süzgeci, arama), il listeleri (kesin sıra + aday adayı), canlı lansman salonu (alkış, mesaj),
// lansman düzenleme (aday seçimi sırası, not, bedel, gönderim), girişler (Partiler kartı, Türkiye, Gündem), taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/aday_vitrini_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
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
    await page.waitForFunction(() => typeof window.adayVitriniAc === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = [];
      const now = Date.now(), iso = (ms) => new Date(now + ms).toISOString();
      const P = [{ id: 1, kisa: 'CYP', ad: 'Cumhuriyet Yolu Partisi', renk: '#c62828', amblem: 'a_basak', yontem: 'onsecim', aday: 41, il: 29 },
                 { id: 2, kisa: 'MBP', ad: 'Milliyetçi Birlik Partisi', renk: '#ef8f00', amblem: 'a_hilal', yontem: 'atama', aday: 24, il: 18 },
                 { id: 25, kisa: 'DETP', ad: 'Demokratik Türkiye Partisi', renk: '#00838f', amblem: 'a_gunes', yontem: 'atama', aday: 0, il: 0 }];
      const iller = VERI.iller.map(i => ({ id: i.id, ad: i.ad, k: i.id === 34 ? 84 : i.id === 6 ? 36 : 4, n: i.id === 34 ? 7 : i.id % 5 === 0 ? 2 : 0, p: i.id === 34 ? { 1: 4, 2: 3 } : i.id % 5 === 0 ? { 1: 1, 2: 1 } : {}, b: i.id === 34 ? 1 : 0, l: i.id === 34 ? 1 : 0 }));
      const L = (id, canli) => ({ id, baslik: id === 7 ? 'İstanbul adaylarımızla tanışın: yeni kadro sahnede' : 'Türkiye\'nin yeni kadrosu', bas: iso(canli ? -10 * 60e3 : 2 * 3600e3), bit: iso(canli ? 50 * 60e3 : 3 * 3600e3), durum: 'planli',
        canli, bitti: false, il_id: id === 7 ? 34 : null, il: id === 7 ? 'İstanbul' : 'Türkiye geneli', parti: P[0], aday_sayisi: 3, katilim: canli ? 12 : 0, hatirlat: 30 });
      window.ST = { alkis: {}, mesajlar: [{ id: 1, kad: 'ali', ad: 'Ali Uzunadlıoğlu Karabekiroğulları', parti: { kisa: 'CYP', renk: '#c62828' }, metin: 'Başarılar! Sonuna kadar arkanızdayız, İstanbul sizinle.', zaman: iso(-60e3) }] };
      const detay = (id) => Object.assign(L(id, id === 7), { metin: 'İstanbul milletvekili adaylarımızı sizlerle tanıştırıyoruz.\nGençlik, emek ve adalet için sahnedeyiz.', simdi: iso(0),
        duzenleyen: { kad: 'gb', ad: 'Genel Başkan' }, katildim: false, hatirlatiyor: false, yetkili: true, mod: true,
        adaylar: [1, 2, 3].map(i => ({ aday_id: 240 + i, kad: 'aday' + i, ad: ['Ataman Fotoğlu', 'Zeynep Çok Uzun Soyadlıoğlu', 'Mert Kaya'][i - 1], il: 'İstanbul', sira: i, not: i === 1 ? 'Gençlerin sesi' : null, alkis: (ST.alkis[240 + i] || 0) + i, alkisladim: !!ST.alkis[240 + i] })),
        mesajlar: ST.mesajlar });
      const vitrin = { donem: 'lansman-20261122', asama: 'kesin', asama_yazi: 'Aday listeleri kesinleşti — sandık yaklaşıyor', kesin: true, simdi: iso(0),
        takvim: { basvuru_bas: iso(-86400e3), basvuru_bit: iso(-40000e3), onsecim_bas: iso(-30000e3), onsecim_bit: iso(-3600e3), secim_bas: iso(86400e3), secim_bit: iso(100000e3) },
        toplam_kontenjan: 600, partiler: P, iller, lansmanlar: [L(7, true), L(8, false)], ben: { parti_id: 1, il_id: 34, lansman_yetkili: true, mod: false } };
      const ilv = { donem: 'x', asama: 'kesin', asama_yazi: 'Aday listeleri kesinleşti', kesin: true, il: { id: 34, ad: 'İstanbul', kontenjan: 84 }, benim_ilim: true,
        listeler: [{ parti: P[0], yontem: 'onsecim', adaylar: [1, 2, 3, 4].map(i => ({ aday_id: 240 + i, kad: 'aday' + i, ad: i === 2 ? 'Zeynep Çok Uzun Soyadlıoğlu Karamanoğulları' : 'Aday ' + i, sira: i, oy: 10 - i, vaat: i === 1 ? 'İstanbul için ulaşımda ücretsiz öğrenci kartı, her ilçeye kreş ve gençlik merkezi; şeffaf belediyecilik ve açık ihale sözü veriyorum.' : null, gb: i === 3, lansman: 1, alkis: 5 })) },
                   { parti: P[1], yontem: 'atama', adaylar: [{ aday_id: 301, kad: 'm1', ad: 'Mehmet Bey', sira: 1, oy: null, vaat: null, gb: false, lansman: 0, alkis: 0 }] }],
        bagimsizlar: [{ aday_id: 400, kad: 'bag', ad: 'Bağımsız Aday', vaat: 'Partisiz, halktan biri.' }], bos_listeli_partiler: [{ kisa: 'DETP', renk: '#00838f', yontem: 'atama' }], lansmanlar: [L(7, true)] };
      const haz = { acik: true, donem: 'x', kesin: true, yontem: 'onsecim', aday_hazir: true, kural_yazi: 'Listeler kesinleşti: listedeki adaylarınla lansman yapabilirsin.',
        en_erken: iso(15 * 60e3), en_gec: iso(2 * 86400e3), sure_dk: 60, parti: Object.assign({ kasa: 3118590 }, P[0]), bedel: { il_taban: 10000, il_sandalye: 1000, ulke: 150000, secili: 150000 },
        gunluk_sinir: 4, son24: 1, il: null,
        adaylar: [{ aday_id: 241, kad: 'aday1', ad: 'Ataman Fotoğlu', il_id: 34, il: 'İstanbul', sira: 1 }, { aday_id: 242, kad: 'aday2', ad: 'Zeynep Çok Uzun Soyadlıoğlu', il_id: 34, il: 'İstanbul', sira: 2 },
                  { aday_id: 243, kad: 'aday3', ad: 'Mert Kaya', il_id: 34, il: 'İstanbul', sira: 3 }, { aday_id: 250, kad: 'ank', ad: 'Ankara Adayı', il_id: 6, il: 'Ankara', sira: 1 }],
        lansmanlarim: [Object.assign(L(7, true), { bedel: 94000 })] };
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'aday_vitrini') return vitrin;
        if (ad === 'aday_vitrini_il') return ilv;
        if (ad === 'aday_vitrini_ara') return [{ aday_id: 241, kad: 'aday1', ad: 'Ataman Fotoğlu', il_id: 34, il: 'İstanbul', sira: 1, parti: { id: 1, kisa: 'CYP', renk: '#c62828' } }];
        if (ad === 'aday_lansman_detay') return detay(a.p_id);
        if (ad === 'aday_lansman_alkis') { ST.alkis[a.p_aday] = 1; return { tamam: true, alkis: 9 }; }
        if (ad === 'aday_lansman_katil') return { tamam: true, katildi: true };
        if (ad === 'aday_lansman_mesaj_yaz') { ST.mesajlar = ST.mesajlar.concat([{ id: 2, kad: 'ben', ad: 'Ben', parti: null, metin: a.p_metin, zaman: iso(0), benim: true }]); return { tamam: true, id: 2 }; }
        if (ad === 'aday_lansman_hazirlik') return haz;
        if (ad === 'aday_lansman_duzenle') return { tamam: true, id: 7, bedel: 94000 };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: iso(0), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 34, kad: 'Ben', parti: { id: 1, kisa: 'CYP', renk: '#c62828' }, makamlar: [], cuzdan: { para: 1000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: iso(0), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const temizle = () => page.evaluate(() => { const m = document.getElementById('modal'); if (m && !m.querySelector('#avKGer,#avOnay')) modalKapat(); });
    const tikla = async (sel) => { await temizle(); await page.waitForSelector(sel); await page.$eval(sel, el => el.click()); };
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.waitForTimeout(800); await temizle(); const h = await page.evaluate(() => { const i = document.getElementById('icerik'); return i ? i.scrollHeight : 0; }); await page.setViewportSize({ width: gen, height: Math.min(5000, Math.max(640, h + 160)) }); await page.waitForTimeout(300); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); await page.setViewportSize({ width: gen, height: gen === 320 ? 640 : 844 }); } };
    const tasma = async () => page.evaluate(() => [...document.querySelectorAll('#icerik *, #modal *')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.av-seg,.av-l-serit,.segment'); }).map(el => el.className || el.tagName).slice(0, 5));

    // 1) Vitrin
    await page.evaluate(() => adayVitriniAc());
    await page.waitForSelector('.av-harita svg path');
    const v = await page.textContent('#icerik');
    assert.match(v, /parti adayı · 600 sandalye/, et('üst özet'));
    assert.match(v, /Listeler kesin/, et('kesin rozeti'));
    assert.match(v, /Aday lansmanı düzenle/, et('yetkiliye düzenle girişi'));
    assert.match(v, /İstanbul adaylarımızla/, et('lansman şeridi'));
    assert.equal(await page.$$eval('.av-harita path', x => x.length), 81, et('81 il yolu'));
    assert.ok(await page.$('.av-harita circle'), et('lansman noktası'));
    assert.deepEqual(await tasma(), [], et('vitrin taşma'));
    await cek('vitrin');
    await tikla('.av-seg button[data-p="1"]');
    await page.waitForSelector('.av-seg button[data-p="1"].aktif');
    const fill = await page.evaluate(() => [...document.querySelectorAll('.av-harita path')].filter(p => p.getAttribute('fill') === '#c62828').length);
    assert.ok(fill >= 2, et('parti süzgeci haritayı boyadı'));
    await page.fill('#avAra', 'Ata');
    await page.waitForFunction(() => /Ataman Fotoğlu/.test((document.getElementById('avAraSonuc') || {}).textContent || ''));
    assert.match(await page.textContent('#avAraSonuc'), /1\. sıra/, et('arama sonucu sıra'));

    // 2) İl
    await page.evaluate(() => adayVitriniIl(34));
    await page.waitForSelector('.av-liste-kart');
    const il = await page.textContent('#icerik');
    assert.match(il, /84 milletvekili/, et('kontenjan'));
    assert.match(il, /Senin ilin/, et('benim ilim'));
    assert.match(il, /4 \/ 84 sıralı aday/, et('liste sayısı'));
    assert.match(il, /Genel Başkan/, et('GB etiketi'));
    assert.match(il, /ön seçim oyu/, et('ön seçim oyu'));
    assert.match(il, /Bağımsız adaylar/, et('bağımsızlar'));
    assert.match(il, /DETP/, et('boş partiler'));
    assert.equal(await page.$$eval('.av-sira.ilk', x => x.length), 2, et('1. sıralar vurgulu'));
    assert.deepEqual(await tasma(), [], et('il taşma'));
    await cek('il');

    // 3) Canlı lansman salonu
    await page.evaluate(() => adayLansmanAc(7));
    await page.waitForSelector('#avLansman');
    const ls = await page.textContent('#icerik');
    assert.match(ls, /CANLI/, et('canlı rozet'));
    assert.match(ls, /Bitişe/, et('sayaç'));
    assert.match(ls, /Gençlerin sesi/, et('aday notu'));
    assert.match(ls, /Salona gir/, et('salona gir'));
    assert.deepEqual(await tasma(), [], et('salon taşma'));
    await cek('lansman_canli');
    await tikla('[data-alkis="241"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'aday_lansman_alkis' && c.a.p_aday === 241 && c.a.p_id === 7));
    await page.waitForFunction(() => /Alkışladın/.test(document.querySelector('[data-alkis="241"]').textContent));
    await page.fill('#avMsj', 'Hepinize başarılar!');
    await tikla('#avMsjGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'aday_lansman_mesaj_yaz' && c.a.p_metin === 'Hepinize başarılar!'));
    await page.waitForFunction(() => /Hepinize başarılar!/.test(document.getElementById('avMesajlar').textContent));
    await tikla('#avKatil');
    await page.waitForFunction(() => calls.some(c => c.ad === 'aday_lansman_katil' && c.a.p_id === 7));

    // 4) Yaklaşan lansman: hatırlat + iptal düğmesi
    await page.evaluate(() => adayLansmanAc(8));
    await page.waitForSelector('#avLansman[data-id="8"]');
    const yl = await page.textContent('#icerik');
    assert.match(yl, /Başlayınca hatırlat/, et('hatırlat düğmesi'));
    assert.match(yl, /Başlamasına/, et('başlamaya kalan'));
    assert.ok(await page.$('#avIptal'), et('yetkiliye iptal'));
    assert.ok(!(await page.$('#avMsj')), et('başlamadan mesaj kutusu yok'));

    // 5) Düzenle
    await page.evaluate(() => adayLansmanDuzenleAc());
    await page.waitForSelector('#avKapsam');
    const dz = await page.textContent('#icerik');
    assert.match(dz, /Parti kasası: 3\.118\.590 ₺/, et('kasa'));
    assert.match(dz, /Lansmanlarım/, et('lansmanlarım'));
    const opts = await page.$$eval('#avKapsam option', o => o.map(x => x.value));
    assert.deepEqual(opts, ['ulke', '34', '6'], et('kapsam seçenekleri (çok adaylı il önce)'));
    assert.equal(await page.inputValue('#avKapsam'), '34', et('varsayılan il'));
    assert.match(await page.textContent('#avBedel'), /94\.000/, et('İstanbul bedeli 10.000 + 84×1.000'));
    assert.deepEqual(await tasma(), [], et('düzenle taşma'));
    await cek('duzenle');
    await tikla('#avAdaySec [data-a="243"]');
    await tikla('#avAdaySec [data-a="241"]');
    await page.fill('#avAdaySec [data-n="243"]', 'Emekçinin sesi');
    assert.match(await page.textContent('#avSecSay'), /2 \/ 12/, et('seçim sayacı'));
    await page.fill('#avBaslik', 'İstanbul adaylarımız sahnede');
    await page.fill('#avSunus', 'İstanbul milletvekili adaylarımızı sizlerle tanıştırıyoruz, hepinizi bekliyoruz.');
    await tikla('.av-hizli [data-z="180"]');
    await tikla('#avKaydet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'aday_lansman_duzenle'));
    const g = await page.evaluate(() => calls.filter(c => c.ad === 'aday_lansman_duzenle').pop().a);
    assert.equal(g.p_il, 34, et('il'));
    assert.deepEqual(g.p_adaylar, [243, 241], et('dokunma sırası'));
    assert.deepEqual(g.p_notlar, ['Emekçinin sesi', ''], et('notlar'));
    const fark = (new Date(g.p_bas).getTime() - Date.now()) / 60000;
    assert.ok(fark > 170 && fark < 182, et('3 saat sonra hızlı düğmesi ' + fark));
    await page.waitForSelector('#avLansman[data-id="7"]');
    await page.evaluate(() => { document.getElementById('avKapsam') || null; });
    // Türkiye geneli seçilince bedel ve arama kutusu
    await page.evaluate(() => adayLansmanDuzenleAc());
    await page.waitForSelector('#avKapsam');
    await page.selectOption('#avKapsam', 'ulke');
    await page.waitForSelector('#avAdayAra');
    assert.match(await page.textContent('#avBedel'), /150\.000/, et('ülke bedeli'));
    assert.equal(await page.$$eval('#avAdaySec [data-a]', x => x.length), 4, et('ülke geneli bütün adaylar'));

    // 6) Girişler
    await page.evaluate(() => iskelet('Partiler', '<div class="kart">x</div>'));
    await page.waitForSelector('#avParti .av-giris');
    await page.waitForSelector('#avPartiLansman button');
    await page.evaluate(() => iskelet('Türkiye', '<div class="kart">x</div>'));
    assert.ok(await page.$('#avHarita .av-giris'), et('Türkiye girişi'));
    await page.evaluate(() => iskelet('Gündem', '<section class="sahne"><div class="olay-adi">Genel Seçim</div></section><div class="kart">y</div>'));
    assert.ok(await page.$('#avGundem .av-giris'), et('Gündem girişi'));
    assert.match(await page.textContent('#avGundem'), /canlı/, et('canlı lansman sayısı'));
    await page.close();
  }
  await browser.close();
  if (hatalar.length) { console.error('Sayfa hataları:\n' + hatalar.join('\n')); process.exit(1); }
  console.log('aday_vitrini_arayuz: TAMAM (390 ve 320 px)');
})().catch(e => { console.error(e); process.exit(1); });
