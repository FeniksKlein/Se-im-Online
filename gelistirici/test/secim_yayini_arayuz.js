// Seçim gecesi canlı yayını görünüm testi (06.11.2026). Sahte sunucu, ağ yok.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/secim_yayini_arayuz.js [ekran_klasörü]
// Denetlenenler: Gündem kartı ve üst bant, sayım öncesi stüdyo, sayım (halka, liste, ÖNDE, harita, il paneli, son sandıklar,
// stüdyo yorumu, son dakika bandı), sıralama değişimi, tamamı açıldı, resmî sonuç (kazanan, ikinci tur, Meclis), sekme geçişi,
// yeniden izleme, ayrıntılı sonuçlara geçiş ve "yeniden izle" kartı, eski sunucuda eski ekran; 390/320 px taşma; sayfa hatası.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2] || null;

// Bu geceki gerçek seçime benzeyen dağılım: CB 23 oy / 17 il, MV 15 oy / 9 il
const CB_IL = { 1: 1, 2: 1, 6: 1, 7: 1, 14: 1, 21: 1, 23: 1, 27: 1, 28: 1, 35: 1, 42: 1, 43: 1, 44: 1, 62: 1, 77: 1, 16: 2, 34: 6 };
const MV_IL = { 2: 1, 7: 1, 14: 1, 21: 1, 27: 1, 28: 1, 44: 1, 16: 2, 34: 6 };
const IL_AD = { 1: 'Adana', 2: 'Adıyaman', 6: 'Ankara', 7: 'Antalya', 14: 'Bolu', 16: 'Bursa', 21: 'Diyarbakır', 23: 'Elazığ', 27: 'Gaziantep', 28: 'Giresun', 34: 'İstanbul', 35: 'İzmir', 42: 'Konya', 43: 'Kütahya', 44: 'Malatya', 62: 'Tunceli', 77: 'Yalova' };

(async () => {
  const browser = await chromium.launch({ headless: true });
  const sonuc = [];
  for (const W of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: W, height: 844 }, isMobile: true, deviceScaleFactor: 2, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
    const hatalar = []; page.on('pageerror', e => hatalar.push(e.message));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const ad = decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname);
      let f = path.join(KOK, ad); if (!fs.existsSync(f)) f = path.join(YEDEK, ad);
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => window.SO_SECIM_YAYINI_V1 && typeof iskelet === 'function' && window.SO_YAYIN);
    await page.waitForTimeout(400);

    await page.evaluate(({ CB_IL, MV_IL, IL_AD }) => {
      // ---- sahte sunucu: sandıklar, saat ve resmî sonuç test tarafından yönetilir
      const T = window.T = { gecen: -40, sure: 1620, kesin: false, eskiSunucu: false, calls: [], cbKazanan: true };
      const CB = 378269, MV = 378267;
      const adaylar = [
        { k: 'a1', kad: 'Ercan', parti_id: 1, kisa: 'CYP', ad: 'Cumhuriyetçi Yol Partisi', renk: '#c62828', amblem: 2 },
        { k: 'a2', kad: 'ArvenTora', parti_id: 2, kisa: 'ABP', ad: 'Anadolu Birlik Partisi', renk: '#c62828', amblem: 3 },   // canlıdaki gibi iki kırmızı parti
        { k: 'a3', kad: 'Selin_Demir', parti_id: 3, kisa: 'YDP', ad: 'Yeni Demokrasi Partisi', renk: '#1565c0', amblem: 4 }];
      const partiler = [
        { k: 'p1', parti_id: 1, kisa: 'CYP', ad: 'Cumhuriyetçi Yol Partisi', renk: '#c62828', amblem: 2 },
        { k: 'p2', parti_id: 2, kisa: 'ABP', ad: 'Anadolu Birlik Partisi', renk: '#ef8f00', amblem: 3 },
        { k: 'p3', parti_id: 3, kisa: 'YDP', ad: 'Yeni Demokrasi Partisi', renk: '#1565c0', amblem: 4 },
        { k: 'p4', parti_id: 4, kisa: 'MKP', ad: 'Millî Kalkınma Partisi', renk: '#2e7d32', amblem: 5 }];
      // İstanbul'da önce A2, sonra A1 güçlenir → sıralama değişir
      const cbOy = (il, j) => il == 34 ? ['a2', 'a2', 'a1', 'a1', 'a1', 'a3'][j] : il == 16 ? ['a1', 'a2'][j] : ['a1', 'a2', 'a3', 'a1', 'a2'][il % 5];
      const mvOy = (il, j) => il == 34 ? ['p2', 'p1', 'p1', 'p3', 'p1', 'p2'][j] : il == 16 ? ['p1', 'bag'][j] : ['p1', 'p2', 'p4', 'p1', 'p3'][il % 5];
      const kur = (ILS, oy, sure) => {
        const iller = Object.keys(ILS).map(Number), sd = []; let kum = 0; const top = iller.reduce((t, i) => t + ILS[i], 0);
        iller.sort((a, b) => ILS[a] - ILS[b] || a - b).forEach((il) => {
          kum += ILS[il]; const c = Math.max(20, Math.ceil(sure * kum / top));
          for (let j = 0; j < ILS[il]; j++) {
            const s = j === ILS[il] - 1 ? c : Math.round(c * 0.15 + c * 0.85 * (j + 1) / ILS[il] - 7);
            let k = oy(il, j); if (k === 'bag') k = 'a9';
            sd.push({ il_id: il, no: 1001 + j, sn: s, oy: 1, dagilim: { [k]: 1 } });
          }
        });
        return sd.sort((a, b) => a.sn - b.sn);
      };
      T.sd = { [CB]: kur(CB_IL, cbOy, T.sure), [MV]: kur(MV_IL, mvOy, T.sure) };
      const secmen = (il) => 6 + (il % 5) * 3;
      const yaris = (sid) => {
        const cb = sid === CB, sd = T.sd[sid], bas = Date.now() - T.gecen * 1000;
        const acik = T.kesin ? sd : sd.filter((s) => s.sn <= T.gecen), dag = {};
        acik.forEach((s) => Object.entries(s.dagilim).forEach(([k, n]) => { dag[k] = (dag[k] || 0) + n; }));
        const iller = Object.keys(cb ? CB_IL : MV_IL).map(Number).map((il) => {
          const hep = sd.filter((s) => s.il_id === il), ac = acik.filter((s) => s.il_id === il), d = {};
          ac.forEach((s) => Object.entries(s.dagilim).forEach(([k, n]) => { d[k] = (d[k] || 0) + n; }));
          return { il_id: il, ad: IL_AD[il], mv: il === 34 ? 98 : 6, sandik: hep.length, acilan: ac.length, oy: hep.length, sayilan: ac.length, secmen: secmen(il), dagilim: d,
            musahit: il === 34 ? [{ kisa: 'CYP', renk: '#c62828' }, { kisa: 'ABP', renk: '#ef8f00' }] : [] };
        }).sort((a, b) => a.ad.localeCompare(b.ad, 'tr'));
        const durum = T.kesin ? 'kesin' : T.gecen < 0 ? 'once' : T.gecen < T.sure ? 'sayim' : 'tamam';
        const r = {
          secim_id: sid, tur: cb ? 'cb' : 'mv', ara: true, donem: 'erken', durum, mod: 'canli',
          oy_bas: new Date(bas - 14 * 3600e3 - 120e3).toISOString(), oy_bit: new Date(bas - 120e3).toISOString(),
          sonuc_at: new Date(bas + (T.sure + 60) * 1000).toISOString(), goreve_bas: new Date(bas + 2 * 3600e3).toISOString(),
          baslangic: new Date(bas).toISOString(), bitis: new Date(bas + T.sure * 1000).toISOString(), sure_sn: T.sure, gecen_sn: T.gecen,
          toplam_sandik: sd.length, acilan_sandik: acik.length, toplam_oy: sd.length, sayilan_oy: acik.length,
          secmen: iller.reduce((t, i) => t + i.secmen, 0), dagilim: dag,
          secenekler: (cb ? adaylar : partiler).map((x) => ({ ...x, oy: dag[x.k] || 0 })),
          bagimsizlar: cb ? [] : [{ k: 'a9', kad: 'Bağımsız_Kemal', il_id: 16, oy: dag.a9 || 0 }],
          ittifaklar: cb ? [] : [{ ad: 'Millet ve Kalkınma İttifakı', partiler: ['CYP', 'MKP'], oy: (dag.p1 || 0) + (dag.p4 || 0) }],
          iller, son: acik.slice(-15).reverse().map((s) => ({ ...s, il: IL_AD[s.il_id], an: new Date(bas + s.sn * 1000).toISOString() })),
          baraj: cb ? null : 7, sandalye_toplam: cb ? null : 600
        };
        if (T.kesin) r.kesin_sonuc = cb
          ? (T.cbKazanan ? { kazanan: { k: 'a1', kad: 'Ercan', kisa: 'CYP', renk: '#c62828', parti_id: 1 }, ikinci_tur: false, toplam: 23 } : { kazanan: null, ikinci_tur: true, ikinci_tur_id: 999, toplam: 23 })
          : { ulusal: [{ parti_id: 1, kisa: 'CYP', ad: 'Cumhuriyetçi Yol Partisi', renk: '#c62828', oy: 7, yuzde: 46.67, gecti: true, sandalye: 12 },
                       { parti_id: 2, kisa: 'ABP', ad: 'Anadolu Birlik Partisi', renk: '#ef8f00', oy: 4, yuzde: 26.67, gecti: true, sandalye: 6 },
                       { parti_id: 3, kisa: 'YDP', ad: 'Yeni Demokrasi Partisi', renk: '#1565c0', oy: 2, yuzde: 13.33, gecti: true, sandalye: 2 }], dolu: 21, bos: 579, sandalye_toplam: 600, bagimsiz_sandalye: 1 };
        return r;
      };
      const sahte = (ad, a) => {
        if (ad === 'secim_yayini') {
          if (T.eskiSunucu) throw new Error('Could not find the function public.secim_yayini');
          const ys = [yaris(CB), yaris(MV)];
          let sonraki = null; ys.forEach((y) => { const x = T.sd[y.secim_id].find((s) => s.sn > T.gecen); if (x) sonraki = Math.min(sonraki == null ? 1e9 : sonraki, x.sn - T.gecen); });
          return { simdi: new Date().toISOString(), secim_id: a.p_secim, yarislar: ys, sonraki_sn: sonraki == null ? 15 : Math.max(1, Math.ceil(sonraki)) };
        }
        if (ad === 'secim_yayini_tekrar') {
          const k = T.kesin, g = T.gecen; T.kesin = true;
          const ys = [CB, MV].map((sid) => { const y = yaris(sid); const t = { ...y, sandiklar: T.sd[sid], iller_bilgi: y.iller.map((i) => ({ il_id: i.il_id, ad: i.ad, mv: i.mv, secmen: i.secmen, musahit: i.musahit })) };
            t.secenekler = t.secenekler.map((x) => ({ ...x, oy: 0 })); t.bagimsizlar = t.bagimsizlar.map((x) => ({ ...x, oy: 0 })); t.ittifaklar = t.ittifaklar.map((x) => ({ ...x, oy: 0 }));
            t.acilan_sandik = 0; t.sayilan_oy = 0; t.dagilim = {}; t.son = []; t.baslangic = new Date(Date.now() - 3 * 3600e3).toISOString(); return t; });
          T.kesin = k; T.gecen = g;
          return { simdi: new Date().toISOString(), secim_id: a.p_secim, yarislar: ys };
        }
        if (ad === 'secim_detay') return { id: a.p_secim, tur: 'cb', asama: 'bitti', oy_bas: new Date(Date.now() - 20 * 3600e3).toISOString(), oy_bit: new Date(Date.now() - 6 * 3600e3).toISOString(),
          sonuc_at: new Date(Date.now() - 5 * 3600e3).toISOString(), goreve_bas: null, katilim: 23, secenekler: [],
          sonuc: { toplam: 23, ikinci_tur: false, kazanan: { kad: 'Ercan' }, adaylar: adaylar.map((x, i) => ({ kad: x.kad, kisa: x.kisa, renk: x.renk, oy: [14, 6, 3][i] })) } };
        if (ad === 'secim_ayrintili_sonuclar') return { hazir: false };
        if (ad === 'portreler' || ad === 'kimlikler') return [];
        return null;
      };
      API = { rpc: async (ad, args) => { T.calls.push({ ad, args }); const v = sahte(ad, args || {}); return v == null ? v : JSON.parse(JSON.stringify(v)); } };
      const simdiIso = new Date().toISOString();
      D.durum = { simdi: simdiIso, profil: { id: 'u1', il_id: 34, kad: 'ArvenTora', parti: { id: 2, kisa: 'ABP', renk: '#ef8f00' }, makamlar: [], cuzdan: { para: 1000 } }, okunmamis: {},
        takvim: [{ id: CB, tur: 'cb', asama: 'sayim', ara: true, oy_bit: new Date(Date.now() - 600e3).toISOString(), sonuc_at: new Date(Date.now() + 1200e3).toISOString(), katilim: 23 },
                 { id: MV, tur: 'mv', asama: 'sayim', ara: true, oy_bit: new Date(Date.now() - 600e3).toISOString(), sonuc_at: new Date(Date.now() + 1200e3).toISOString(), katilim: 15 }] };
      D.sekme = 'gundem'; D.yigin = [];
      window.CB = CB; window.MV = MV;
    }, { CB_IL, MV_IL, IL_AD });

    const durum = () => page.evaluate(() => ({
      metin: document.getElementById('icerik')?.innerText || '',
      yatay: document.documentElement.scrollWidth > window.innerWidth + 1 || [...document.querySelectorAll('#yayinKok *')].some(el => {
        const r = el.getBoundingClientRect(); return r.width && r.right > window.innerWidth + 1 && !el.closest('.yy-kayan-ic, .yy-konfeti') && getComputedStyle(el).position !== 'fixed'; })
    }));
    const tamFoto = async (ad) => {
      if (!shot) return;
      fs.mkdirSync(shot, { recursive: true });
      const h = await page.evaluate(() => { const ic = document.getElementById('icerik'); return ic ? ic.scrollHeight + 160 : 844; });
      await page.setViewportSize({ width: W, height: Math.min(7000, Math.max(844, h)) }); await page.waitForTimeout(250);
      await page.screenshot({ path: path.join(shot, `${ad}_${W}.png`) });
      await page.setViewportSize({ width: W, height: 844 }); await page.waitForTimeout(80);
    };
    const ekranFoto = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, `${ad}_${W}_ekran.png`) }); } };
    const temiz = (t, yer) => assert.doesNotMatch(t, /undefined|NaN|\[object Object\]|null|Infinity/, yer);
    const yenile = async (gecen, ek) => { await page.evaluate(({ gecen, ek }) => { T.gecen = gecen; Object.assign(T, ek || {}); return SO_YAYIN.yenile(); }, { gecen, ek }); await page.waitForTimeout(1300); };

    // 0) Gündem kartı ve üst bant (wrapper'lar)
    const g = await page.evaluate(() => {
      SO_YAYIN.aktif = [{ secim_id: CB, tur: 'cb', yuzde: 34.8, onde: 'Ercan %50,0', acilan_sandik: 8, toplam_sandik: 23 }];
      const kart = olayKarti(D.durum.takvim[0]);
      const ust = gundemEkUst({ canli: [{ secim_id: CB, tur: 'cb', yuzde: 34.8, onde: 'Ercan %50,0' }, { secim_id: MV, tur: 'mv', yuzde: 20, onde: 'başa baş' }] });
      const bos = gundemEkUst({ canli: [] });
      return { kart, ust, bos };
    });
    assert.match(g.kart, /Canlı sayım/); assert.match(g.kart, /%34,8/); assert.match(g.kart, /8\/23/); assert.match(g.kart, /Önde: Ercan %50,0/); assert.match(g.kart, /Canlı yayını izle/);
    assert.match(g.ust, /Seçim gecesi/); assert.match(g.ust, /Milletvekili/); assert.match(g.ust, /başa baş/); assert.equal(g.bos, '');
    sonuc.push('gündem: canlı sayım kartı ve üst bant');

    // 1) Sayım öncesi: stüdyo
    await page.evaluate(() => ekranAc(() => secimEkrani(CB)));
    await page.waitForTimeout(900);
    let s = await durum();
    for (const k of ['CANLI', 'SEÇİM 2026', 'SON DAKİKA', 'Sandıklar kapandı, oylar sayılıyor', 'Sandık kurulları oyları sayıyor', 'Sayımın başlamasına kalan', 'Bu gece 23 seçmen sandığa gitti', 'Cumhurbaşkanlığı', 'Milletvekili', 'Ercan', 'ArvenTora', 'Türkiye haritası', 'İlk sandıkların açılması bekleniyor'])
      assert.ok(s.metin.includes(k), 'Öncesi: ' + k);
    temiz(s.metin, 'once'); assert.ok(!s.yatay, 'Yatay taşma (once)');
    assert.equal(await page.evaluate(() => document.querySelectorAll('#yyListe .yy-satir').length), 3);
    await tamFoto('y01_once');
    sonuc.push('sayım öncesi stüdyo');

    // 2) Sayım: ilk sandıklar
    await yenile(400);
    s = await durum(); temiz(s.metin, 'sayim1'); assert.ok(!s.yatay, 'Yatay taşma (sayım)');
    const ilk = await page.evaluate(() => ({
      halka: document.getElementById('yyHalkaY').textContent, satir: [...document.querySelectorAll('#yyListe .yy-satir')].map(x => x.innerText.replace(/\s+/g, ' ')),
      onde: document.querySelectorAll('#yyListe .yy-cip.onde').length, renkli: [...document.querySelectorAll('#yyHarita path')].filter(p => !['#1A2347', '#34416F'].includes(p.getAttribute('fill'))).length,
      akis: document.querySelectorAll('#yyAkis li').length, yorum: document.querySelectorAll('#yyYorum .yy-yorum-satir').length,
      kayan: document.getElementById('yyKayan').textContent, sekme: [...document.querySelectorAll('#yySekmeler button')].map(b => b.innerText.replace(/\s+/g, ' ')),
      il: document.getElementById('yyIl').innerText
    }));
    assert.match(ilk.halka, /^%\d+,\d$/); assert.ok(ilk.renkli >= 3, 'Haritada açılan iller renkli'); assert.ok(ilk.akis >= 3); assert.ok(ilk.yorum >= 1, 'Stüdyo yorumu');
    assert.match(ilk.kayan, /CUMHURBAŞKANLIĞI: açılan sandık %/); assert.equal(ilk.sekme.length, 2);
    const cubuk = await page.evaluate(() => [...document.querySelectorAll('#yyListe .yy-cubuk i')].map(i => i.style.background));
    assert.equal(new Set(cubuk).size, cubuk.length, 'Aynı renkli partiler ayrı renkte çizilmeli: ' + cubuk.join(','));
    assert.match(ilk.il, /İstanbul/); assert.match(ilk.il, /SENİN İLİN/); assert.match(ilk.il, /müşahitler/);
    await tamFoto('y02_sayim');
    await ekranFoto('y02_sayim');
    sonuc.push('sayım: halka, liste, harita, il paneli, akış, yorum, bant');

    // 3) Sıralama değişimi ve FLIP
    await yenile(900); await yenile(1250); await yenile(1500);
    const orta = await page.evaluate(() => ({ yorum: [...document.querySelectorAll('#yyYorum p')].map(p => p.textContent), lider: document.querySelector('#yyListe .yy-satir.lider .ad')?.textContent,
      fark: document.getElementById('yyFark').innerText }));
    assert.ok(orta.yorum.length >= 2);
    assert.ok(orta.lider || /eşit/.test(orta.fark), 'Önde olan işaretli ya da eşitlik yazıyor'); assert.match(orta.fark, /Fark|eşit/);
    s = await durum(); temiz(s.metin, 'sayim-orta');
    sonuc.push('sıralama ve fark: ' + orta.lider + ' · ' + orta.yorum[0]);

    // 4) Harita dokunuşu → il paneli
    await page.evaluate(() => yayinIlSec(16, false)); await page.waitForTimeout(200);
    assert.match(await page.evaluate(() => document.getElementById('yyIl').innerText), /Bursa/);
    assert.equal(await page.evaluate(() => document.querySelector('#yyHarita path.secili')?.dataset.il), '16');
    sonuc.push('harita dokunuşu → il paneli');

    // 5) Tamamı açıldı
    await yenile(1625);
    s = await durum(); temiz(s.metin, 'tamam');
    for (const k of ['Sandıkların tamamı açıldı', 'Yüksek Seçim Kurulu resmî sonucu', 'YSK bekleniyor']) assert.ok(s.metin.includes(k), 'Tamam: ' + k);
    assert.equal(await page.evaluate(() => document.getElementById('yyHalkaY').textContent), '%100,0');
    await tamFoto('y03_tamam');
    sonuc.push('tamamı açıldı + resmî sonuç geri sayımı');

    // 6) Resmî sonuç: kazanan
    await yenile(1700, { kesin: true });
    s = await durum(); temiz(s.metin, 'kesin');
    for (const k of ['TÜRKİYE CUMHURİYETİ CUMHURBAŞKANI', 'Ercan', 'ilk turda seçildi', 'KAZANDI', 'Seçim gecesini baştan izle', 'Ayrıntılı resmî sonuçlar', 'SONUÇ', 'Resmî sonuç açıklandı'])
      assert.ok(s.metin.includes(k), 'Kesin: ' + k);
    assert.ok(await page.evaluate(() => document.querySelectorAll('.yy-konfeti i').length > 10), 'Konfeti');
    assert.ok(!s.yatay, 'Yatay taşma (kesin)');
    await tamFoto('y04_kazanan');
    // MV sekmesi: Meclis aritmetiği
    await page.evaluate(() => document.querySelector(`#yySekmeler button[data-sid="${MV}"]`).click()); await page.waitForTimeout(500);
    s = await durum(); temiz(s.metin, 'mv-kesin');
    for (const k of ["TBMM'nin yeni aritmetiği", 'Cumhuriyetçi Yol Partisi', '12 sandalye', 'tek başına çoğunluk', 'İttifaklar', 'Bağımsızlar', 'Partiler'])
      assert.ok(s.metin.includes(k), 'MV kesin: ' + k);
    assert.ok(await page.evaluate(() => document.querySelectorAll('#yyMeclis circle').length >= 300));
    await tamFoto('y05_meclis');
    sonuc.push('resmî sonuç: kazanan, konfeti, MV Meclis aritmetiği');

    // 7) İkinci tur görünümü
    await page.evaluate(() => { T.cbKazanan = false; SO_YAYIN.kesinGoruldu = {}; document.querySelector(`#yySekmeler button[data-sid="${CB}"]`).click(); });
    await yenile(1700, { kesin: true });
    s = await durum();
    assert.ok(s.metin.includes('Seçim ikinci tura kaldı') && s.metin.includes('2. TUR') && s.metin.includes('İkinci tur sandığı'), 'İkinci tur');
    temiz(s.metin, 'ikinci-tur');
    await tamFoto('y06_ikinci_tur');
    sonuc.push('ikinci tur kartı');

    // 8) Yeniden izleme
    await page.evaluate(() => yayinTekrarAc(CB)); await page.waitForTimeout(600);
    let t1 = await page.evaluate(() => ({ et: document.getElementById('yyCanli').textContent, s: SO_YAYIN.tekrar && SO_YAYIN.tekrar.gecen }));
    assert.equal(t1.et, 'TEKRAR');
    await page.waitForTimeout(3500);
    const t2 = await page.evaluate(() => ({ ac: (SO_YAYIN.veri.yarislar[0] || {}).acilan_sandik, metin: document.getElementById('icerik').innerText }));
    assert.ok(t2.ac > 0, 'Tekrar ilerliyor'); assert.match(t2.metin, /Seçim gecesi yeniden/);
    temiz(t2.metin, 'tekrar');
    await tamFoto('y07_tekrar');
    await page.evaluate(() => yayinTekrarKontrol('son')); await page.waitForTimeout(500);
    s = await durum(); assert.ok(s.metin.includes('Seçim ikinci tura kaldı'), 'Tekrar sonu: resmî sonuç'); temiz(s.metin, 'tekrar-son');
    await page.evaluate(() => yayinTekrarKontrol('cik')); await page.waitForTimeout(700);
    assert.equal(await page.evaluate(() => document.getElementById('yyCanli').textContent), 'SONUÇ');
    sonuc.push('yeniden izleme: ilerliyor, sona geç, kapat');

    // 9) Ayrıntılı sonuçlar → eski ekran + yeniden izle kartı
    await page.evaluate(() => yayinAyrinti(CB)); await page.waitForTimeout(700);
    s = await durum();
    assert.ok(s.metin.includes('Seçim gecesini baştan izle') && !(await page.evaluate(() => !!document.getElementById('yayinKok'))), 'Ayrıntı ekranı + tekrar kartı');
    sonuc.push('ayrıntılı resmî sonuçlar ve yeniden izle kartı');

    // 10) Eski sunucu: eski ekran açılır
    await page.evaluate(() => { T.eskiSunucu = true; T.kesin = false; D.yigin = []; return ekranAc(() => secimEkrani(CB)); }); await page.waitForTimeout(700);
    assert.equal(await page.evaluate(() => !!document.getElementById('yayinKok')), false, 'Eski sunucuda yayın açılmaz');
    sonuc.push('eski sunucuda eski seçim ekranı');

    assert.deepEqual(hatalar, [], 'Sayfa hatası: ' + hatalar.join(' | '));
    console.log(`  ✓ ${W}px: ${sonuc.splice(0).join(' · ')}`);
    await page.close();
  }
  await browser.close();
  console.log('TAMAM');
})().catch((e) => { console.error(e); process.exit(1); });
