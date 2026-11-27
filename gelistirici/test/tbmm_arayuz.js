// TBMM Genel Kurul salonu + Meclis çalışmaları arayüz testi (sahte RPC; 390 ve 320 px) — 27.11.2026
// Salon (600 sandalye, tutanak, kürsü, işaret oylaması, kanun EVET/HAYIR, Başkanlık paneli, söz iste, konuşma, yoklama, izleyici),
// Meclis sekmesi canlı kartı + Çalışmalar, komisyon, soru önergesi, genel görüşme, Meclis araştırması, dilekçe, halk buluşması, karne, tutanak arşivi.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/tbmm_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
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
    await page.waitForFunction(() => typeof window.tbmmSalonAc === 'function' && typeof window.tbmmMerkezAc === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = [];
      const now = Date.now(), iso = (ms) => new Date(now + ms).toISOString();
      const P = [{ id: 1, kisa: 'CYP', ad: 'Cumhuriyet Yolu Partisi', renk: '#c62828', n: 248 }, { id: 2, kisa: 'MBP', ad: 'Milliyetçi Birlik Partisi', renk: '#ef8f00', n: 141 },
                 { id: 3, kisa: 'YDP', ad: 'Yeni Demokrasi Partisi', renk: '#1565c0', n: 92 }, { id: null, kisa: 'Bağımsız', ad: 'Bağımsız milletvekilleri', renk: '#8E97B5', n: 7 }];
      const V = []; let m = 1000; P.forEach(p => { for (let i = 0; i < p.n; i++) V.push({ m: m++, k: 'v' + m, a: 'Vekil ' + m, p: p.id, i: 'İzmir' }); });
      const H = { zaman: iso(0), toplam: 600, partiler: P, vekiller: V, baskan: null };
      const kimlik = (kad, ad, il, kisa, renk, mk) => ({ ad, kad, il, kisa, renk, mk, parti_id: 1, rol: null });
      window.ST = { rol: 'baskan', soz: false, yoklama: false, bitti: false, surum: 10, oy: null };
      const tut = [
        { id: 1, z: iso(-30 * 60e3), tur: 'baskan', m: 'Türkiye Büyük Millet Meclisinin 3\'üncü Birleşimini açıyorum.' },
        { id: 2, z: iso(-29 * 60e3), tur: 'yoklama', m: 'Yoklama sonucu: 312 milletvekili hazır. Toplantı yeter sayısı 163.' },
        { id: 3, z: iso(-28 * 60e3), tur: 'gundem', m: 'Gündem dışı konuşmalar' },
        { id: 4, z: iso(-9 * 60e3), tur: 'konusma', ad: 'Ayşe Karadenizlioğlu Uzunsoyadlı', kad: 'ayse', il: 'Trabzon', kisa: 'CYP', renk: '#c62828', soz: 9, st: 'gundem_disi', v: { ilk: true, konu: 'Fındık fiyatları ve üreticinin borç yükü' }, m: 'Sayın Başkan, değerli milletvekilleri; fındık üreticisi bu yıl maliyetin altında satış yapmak zorunda kaldı. Taban fiyat açıklanmalı.' },
        { id: 5, z: iso(-8 * 60e3), tur: 'laf', ad: 'Mehmet Yerinden', kad: 'mehmet', il: 'Konya', kisa: 'MBP', renk: '#ef8f00', m: 'Siz iktidardayken ne yaptınız?' },
        { id: 6, z: iso(-8 * 60e3), tur: 'tepki', m: '(CYP sıralarından alkışlar)' },
        { id: 7, z: iso(-2 * 60e3), tur: 'sistem', m: 'Kanun Teklifi teklifinin oylaması başladı; elektronik oylama 21.40\'e kadar açıktır.' }
      ];
      const genel = () => ({ simdi: iso(0), esik: { taban: 488, toplanti: 163, karar: 123, dolu: 488 }, sonraki: null, son: null,
        b: { id: 3, no: 3, tur: 'olagan', durum: ST.yoklama ? 'yoklama' : 'acik', gun: '2026-12-03', plan_bas: iso(-31 * 60e3), bitis: iso(29 * 60e3), acilis: iso(-30 * 60e3), ara_bit: null, ara_neden: null, uzatma: 0, uzatma_azami: 2,
             yeter: 163, kapali: false, aktif: 21, gerekce: null, yoneten: kimlik('ben', 'Meclis Başkanı Ben', 'Ankara', 'CYP', '#c62828', 1001), baskan: kimlik('ben', 'Meclis Başkanı Ben'), gecici: null },
        gundem: [{ id: 20, sira: 1, tur: 'sunus', baslik: 'Başkanlığın Genel Kurula sunuşları', durum: 'bitti' }, { id: 21, sira: 2, tur: 'grup_onerisi', ref: 5, baslik: 'CYP Grubu önerisi: Fındık üreticisine destek bildirisi', durum: 'gorusuluyor' },
                 { id: 22, sira: 3, tur: 'kanun_oylama', ref: 77, baslik: 'Esnaf Kira Desteği Kanun Teklifi — elektronik oylama', durum: 'bekliyor' }, { id: 23, sira: 4, tur: 'serbest', baslik: 'Diğer işler ve serbest görüşmeler', durum: 'bekliyor' }],
        kursu: ST.bitti ? null : { id: 9, tur: 'grup', tur_ad: 'Grup adına', kelime: 280, kullanilan: 120, ek: false, verildi: iso(-100e3), bas: iso(-90e3), bit: iso(270e3), konu: null, kisi: kimlik('ayse', 'Ayşe Karadenizlioğlu Uzunsoyadlı', 'Trabzon', 'CYP', '#c62828', 1003) },
        sira: [{ id: 31, tur: 'kisisel', tur_ad: 'Şahsı adına', konu: null, istek: iso(-60e3), kisi: kimlik('m1', 'Zeynep Çokuzunsoyadlıoğlu Karamanoğulları', 'İstanbul', 'MBP', '#ef8f00') },
               { id: 32, tur: 'yerinden', tur_ad: 'Yerinden kısa açıklama', konu: null, istek: iso(-30e3), kisi: kimlik('m2', 'Ali Veli', 'Ankara', 'YDP', '#1565c0') }],
        sira_sayi: 2,
        yoklama: ST.yoklama ? { id: 4, bas: iso(-60e3), bit: iso(240e3), neden: 'istem', sonuc: 'acik', sayi: 120, yeter: 163 } : null,
        oylama: { id: 41, konu: 'grup_onerisi', baslik: 'CYP Grubunun önerisini', bas: iso(-60e3), bit: iso(120e3), durum: 'acik', yeter_istendi: false, karar_yeter: 123, kabul: 140, ret: 98, cekimser: 4,
                  partiler: [{ kisa: 'CYP', renk: '#c62828', k: 140, r: 0, c: 2 }, { kisa: 'MBP', renk: '#ef8f00', k: 0, r: 98, c: 2 }], oy: Object.fromEntries(V.slice(0, 242).map((v, i) => [v.m, i < 140 ? 'k' : i < 238 ? 'r' : 'c'])) },
        kanunlar: [{ id: 77, no: 12, baslik: 'Esnaf Kira Desteği Kanun Teklifi', tur: 'serbest', durum: 'oylamada', bit: iso(40 * 60e3), kabul: 210, ret: 150, cekimser: 3,
                     partiler: [{ kisa: 'CYP', renk: '#c62828', k: 200, r: 10, c: 1 }], oy: Object.fromEntries(V.slice(0, 363).map((v, i) => [v.m, i < 210 ? 'k' : i < 360 ? 'r' : 'c'])) }],
        tepki: { 4: [12, 3, 5] }, gizlenen: [], sal: V.slice(0, 300).map(v => v.m), yemin: null,
        gundem_disi: [{ id: 51, konu: 'Kuraklık', durum: 'bekliyor', kisi: kimlik('k1', 'Kemal Kurak') }], oneriler: [] });
      const ben = () => ({ vekil: ST.rol !== 'izleyici', hukumet: false, yonetebilir: ST.rol === 'baskan', baskan: false, yonetici: false, mod: ST.rol === 'baskan', grup_parti: ST.rol === 'baskan' ? 1 : null, grup_kisa: 'CYP', cb: false, mk: 1001,
        cikarildi: false, ihtar_bit: null, turler: [{ kod: 'kisisel', ad: 'Şahsı adına', kelime: 150, sure: 240 }, { kod: 'grup', ad: 'Grup adına', kelime: 280, sure: 360 }, { kod: 'yerinden', ad: 'Yerinden kısa açıklama', kelime: 45, sure: 60 }, { kod: 'satasma', ad: 'Sataşma', kelime: 70, sure: 120 }],
        soz: ST.soz ? { id: 99, tur: 'kisisel', ad: 'Şahsı adına', kelime: 150, kullanilan: 0, bas: null, bit: iso(90e3), sure: 240 } : null, bekleyen: null, bekleme_bitis: null, laf_bitis: null, laf_kalan: 3,
        yoklamada: false, oyum: ST.oy, kanun_oylarim: {}, tepkilerim: {}, gundem_disi: null, oneri_verdim: false, yemin: true });
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'gk_durum') return { surum: ST.surum, ayni: false, simdi: iso(0), genel: genel(), ben: ben(), yeni: a && a.p_son ? [] : tut, bid: 3, salon: { vekil: 312, izleyici: 1840 } };
        if (ad === 'gk_salon_harita') return H;
        if (ad === 'gk_oy') { ST.oy = a.p_oy; ST.surum++; return { tamam: true }; }
        if (ad === 'gk_birlesimler') return [{ id: 2, no: 2, tur: 'olagan', durum: 'kapandi', gun: '2026-12-02', acilis: iso(-86400e3), kapanis: iso(-82800e3), ozet: { konusma: 14, oylamalar: [{}], sure_dk: 62 } }];
        if (ad === 'gk_tutanak_oku') return { birlesim: { id: 2, no: 2, tur: 'olagan', durum: 'kapandi', acilis: iso(-86400e3), kapanis: iso(-82800e3) }, satirlar: tut };
        if (ad === 'gk_gg_liste') return { yeter: 20, vekilim: true, grup: true, liste: [{ id: 1, no: 1, konu: 'Gençlerin işsizliği ve beyin göçü', gerekce: 'Gençlerimizin işsizlik oranı yükseliyor.', durum: 'imza', grup_adina: false, olusturma: iso(-3600e3), imza_bit: iso(40 * 3600e3), veren: kimlik('x', 'Önerge Sahibi Uzunadlı'), imza: 7, imzaladim: false, imzacilar: ['A', 'B'], benim: false }] };
        if (ad === 'tbmm_ozet') return { simdi: iso(0), vekil: true, yonetebilir: true, hukumet: false, birlesim: { id: 3, no: 3, durum: 'acik', tur: 'olagan', bitis: iso(29 * 60e3), kursu: 'Ayşe Karadenizlioğlu', salonda: 312, izleyici: 1840 }, sonraki: null, dolu: 488, gensoru_acik: false,
          sayilar: { komisyonlarim: 2, komisyon_gundem: 1, soru_bana: 0, soru_benim: 3, gg_imza: 1, arastirma: 1, dilekce_kom: 4, dilekce_bakanlik: null, hb_ilimde: 2, hb_canli: 1 } };
        if (ad === 'komisyonlar') return { boyut: 26, dolu: 488, vekilim: true, tbmm_baskani: false, uyeliklerim: 1, azami_uyelik: 2, kontenjan: [{ parti: 'CYP', renk: '#c62828', mv: 248, kontenjan: 13 }],
          komisyonlar: [{ kod: 'tarim', ad: 'Tarım, Orman ve Köyişleri Komisyonu', kisa: 'Tarım ve Orman', aciklama: 'Tarım, hayvancılık, ormancılık.', baskan: 'ayse', uyeler: [{ kad: 'ayse', parti: 'CYP', renk: '#c62828', gecerli: true, baskan: true, oy: 9 }], uyeyim: true, gecerli_uyeyim: true, gundem: [{ id: 77, baslik: 'Esnaf', oy_bas: iso(3600e3), kabul: 3, ret: 1, oyum: null }], son_kararlar: [] },
                        { kod: 'dilekce', ad: 'Dilekçe Komisyonu', kisa: 'Dilekçe', aciklama: 'Vatandaş dilekçeleri.', baskan: null, uyeler: [], uyeyim: false, gecerli_uyeyim: false, gundem: [], son_kararlar: [] }] };
        if (ad === 'kom_salon') return { kod: 'tarim', ad: 'Tarım, Orman ve Köyişleri Komisyonu', kisa: 'Tarım ve Orman', aciklama: 'Tarım, hayvancılık.', baskan: 'ayse', uyeler: [{ kad: 'ayse', parti: 'CYP', renk: '#c62828', gecerli: true, baskan: true, oy: 9, cikarabilirim: false }], uyeyim: true, gecerli_uyeyim: true, baskan_oyum: 'ayse',
          gundem: [{ id: 77, baslik: 'Esnaf Kira Desteği', oy_bas: iso(3600e3), kabul: 3, ret: 1, oyum: 'kabul' }], son_kararlar: [{ id: 70, baslik: 'Gübre desteği', karar: 'kabul', kabul: 9, ret: 4, at: iso(-86400e3) }], boyut: 26, yazabilirim: true, vekilim: true, uyeliklerim: 1, grup_yetkili: false,
          kontenjan: [{ parti: 'CYP', renk: '#c62828', mv: 248, kontenjan: 13, dolu: 1 }], dilekce_bekleyen: null, tutanak: [{ id: 1, z: iso(-60e3), tur: 'konusma', ad: 'Ayşe K', kad: 'ayse', il: 'Trabzon', renk: '#c62828', m: 'Komisyonumuz teklifi görüşüyor.' }] };
        if (ad === 'komisyon_kanun') return { kom_kod: 'tarim', kom_ad: 'Tarım Komisyonu', havale_at: iso(-3600e3), havale_eden: 'baskan', karar: null, acik: true, bitis: iso(3600e3), baskan: 'ayse', rapor: null, oylar: [{ kad: 'ayse', parti: 'CYP', oy: 'kabul', gerekce: null }], uye_sayisi: 26, esik: 9, oy_verebilirim: true, oyum: null, rapor_yazabilirim: true, havale_edebilirim: false, komisyonlar: [] };
        if (ad === 'tbmm_sorular') return { vekilim: true, muhataplarim: [], hedefler: [{ kod: 'tarim', ad: 'Tarım ve Orman Bakanlığı' }, { kod: 'cby', ad: 'Cumhurbaşkanı Yardımcılığı' }], bugun: 1,
          liste: [{ id: 1, no: 1, bakanlik: 'tarim', hedef: 'Tarım ve Orman Bakanlığı', konu: 'Ege kuraklığı', soru: 'Bakanlık, Ege\'deki kuraklık için çiftçiye ne tür destek vermeyi planlıyor?', zaman: iso(-86400e3), son: iso(14 * 86400e3), yanit: 'Destek paketi hazırlandı.', yanit_at: iso(-3600e3), yanitlayan: { ad: 'Bakan', rol: 'Tarım ve Orman Bakanı' }, soran: { ad: 'Ayşe', il: 'İzmir', kisa: 'CYP' }, vatandas: 'Vatandaş 1', gecikti: false, benim: true, cevaplayabilirim: false }],
          karne: [{ kod: 'tarim', ad: 'Tarım ve Orman Bakanlığı', soru: 4, cevap: 3, gecikmis: 1, ort_saat: 30, oran: 75, muhatap: 'Bakan Bey' }] };
        if (ad === 'meclis_arastirmalar') return { vekilim: true, tbmm_baskani: false, imza_yeter: 20, uye_sayisi: 12, dolu: 488, aktif: [{ id: 1, no: 1, konu: 'Maden kazaları', durum: 'kurulus', teklif_eden: 'x', parti: { kisa: 'MBP' }, olusturma: iso(-86400e3), son: iso(86400e3), imza: 20, uye: 5, uye_sayisi: 12, baskan: null, uyesiyim: false, bekleyen_oy: false }], biten: [], davetlerim: [] };
        if (ad === 'meclis_arastirma_detay') return { id: 1, no: 1, konu: 'Maden kazaları', durum: 'kurulus', teklif_eden: 'x', son: iso(86400e3), gerekce: 'Maden kazalarının nedenleri araştırılmalı.', imza_yeter: 20, imza: 20, dolu: 488, toplanti_yeter: 163, karar_yeter: 123, imzalar: ['a'],
          uyeler: [{ kad: 'u1', parti: { kisa: 'CYP', renk: '#c62828' }, baskan: false, oy_aldi: 2 }], kontenjan: [{ parti: { kisa: 'CYP' }, koltuk: 6, dolu: 1 }], serbest_an: iso(43200e3), dinlemeler: [], serhler: [], ben: { vekil: true, uye: false, baskan: false, teklif_eden: false, imzaladim: true } };
        if (ad === 'tbmm_dilekceler') return { uye: true, bakanliklarim: [], bakanliklar: [{ kod: 'tarim', ad: 'Tarım ve Orman Bakanlığı' }], son_verdigim: null, hesap_gun: 20,
          benim: [{ id: 1, no: 1, konu: 'Köy yolu bozuk', metin: 'Köyümüzün yolu iki yıldır yapılmıyor.', durum: 'cevaplandi', zaman: iso(-86400e3), bakanlik_ad: 'Ulaştırma', cevap: 'Yol programa alındı.', cevap_tur: 'bakanlik', cevap_at: iso(-3600e3), cevaplayan: { ad: 'Bakan' } }],
          komisyon: [{ id: 2, no: 2, konu: 'Okul servisi', metin: 'Servis yok.', durum: 'komisyonda', zaman: iso(-3600e3), son: iso(70 * 3600e3), kisi: { ad: 'Vatandaş' } }], bakanlik: null, son_cevaplar: [] };
        if (ad === 'hb_liste') return { il_id: 35, il: 'İzmir', vekilim: true, secim_ilim: 35, canli: [{ id: 5, baslik: 'Esnafla buluşma: kira ve vergi', bas: iso(-600e3), bit: iso(2100e3), durum: 'planli', canli: true, bitti: false, il: 'İzmir', vekil: kimlik('v', 'Ataman Fotoğlu'), katilim: 34, soru: 12, yanit: 4, hatirlat: 50 }],
          ilimde: [{ id: 6, baslik: 'Gençlerle buluşma', bas: iso(86400e3), bit: iso(88000e3), durum: 'planli', canli: false, bitti: false, il: 'İzmir', vekil: kimlik('v2', 'Zeynep Kaya'), katilim: 0, soru: 0, hatirlat: 8, hatirlatiyorum: true }], benim: [], gecmis: [] };
        if (ad === 'hb_detay') return { id: 5, baslik: 'Esnafla buluşma: kira ve vergi', metin: 'Kira ve vergi sorunlarını konuşalım.', bas: iso(-600e3), bit: iso(2100e3), durum: 'planli', canli: true, bitti: false, il: 'İzmir', vekil: kimlik('v', 'Ataman Fotoğlu', null, 'CYP', '#c62828'), katilim: 34, soru: 2, yanit: 1, puan: null, puan_sayi: 0, benim: false, simdi: iso(0),
          katildim: true, hatirlatiyorum: false, puanim: null, puanlayabilirim: false, sorularim: 1, mod: false, sorular: [{ id: 1, metin: 'Kira artışına sınır gelecek mi?', zaman: iso(-300e3), yanit: 'Evet, teklif vereceğim.', yanit_at: iso(-200e3), begeni: 7, onerge: true, kisi: { ad: 'Vatandaş Bir' }, benim: false, begendim: true }], katilanlar: ['A', 'B'] };
        if (ad === 'tbmm_meclis_siralama') return [{ kad: 'ayse', ad: 'Ayşe Karadenizlioğlu', il: 'Trabzon', kisa: 'CYP', renk: '#c62828', puan: 64, sira: 1 }];
        if (ad === 'tbmm_vekil_karne') return { kisi: { ad: 'Ben Vekil', il: 'Ankara', kisa: 'CYP' }, bas: iso(-86400e3), puan: 42, sira: 12, toplam: 488, birlesim: 3, yoklama: 3, konusma: 4, kelime: 400, alkis: 20, laf: 2, kanun_teklif: 1, kanunlasan: 0, oylama: 2, oy_kullandi: 2, soru: 3, soru_cevap: 1, gg: 0, hb: 1, hb_katilim: 30, hb_puan: 4.5, komisyonlar: [{ kod: 'tarim', ad: 'Tarım', baskan: false }], disiplin: [], ihtar: 0, son_konusmalar: [{ z: iso(-3600e3), m: 'Sayın Başkan…', st: 'kisisel' }] };
        if (ad === 'meclis_rehber') return { partiler: [], bagimsiz: 0, toplam: 600, dolu: 488, cogunluk: 245, grup_esigi: 20, baskan: null, gecici: null, iller: [], sozluk: {} };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: iso(0), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return { tamam: true };
      } };
      D.durum = { profil: { id: 'x', il_id: 35, kad: 'ben', parti: { id: 1, kisa: 'CYP', renk: '#c62828' }, makamlar: [{ tur: 'mv' }], cuzdan: { para: 1000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: iso(0), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const temizle = () => page.evaluate(() => { const m = document.getElementById('modal'); if (m) modalKapat(); });
    const tikla = async (sel) => { await page.waitForSelector(sel); await page.$eval(sel, el => el.click()); };
    const cek = async (ad) => { if (!shot) return; fs.mkdirSync(shot, { recursive: true }); await page.waitForTimeout(600); const h = await page.evaluate(() => { const i = document.getElementById('icerik'); return i ? i.scrollHeight : 0; }); await page.setViewportSize({ width: gen, height: Math.min(5200, Math.max(640, h + 120)) }); await page.waitForTimeout(250); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); await page.setViewportSize({ width: gen, height: gen === 320 ? 640 : 844 }); };
    const tasma = async () => page.evaluate(() => [...document.querySelectorAll('#icerik *, #modal *')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.segment,.tm-seg,.gk-akis'); }).map(el => (el.className && el.className.baseVal != null ? el.className.baseVal : el.className) || el.tagName).slice(0, 6));
    const son = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).slice(-1)[0] || null, ad);

    // 1) Genel Kurul sohbeti salona çıkar
    await page.evaluate(() => { ekranAc(() => sohbetEkrani('meclis')); });
    await page.waitForSelector('#gkSalon .gk-svg circle.k');
    await page.waitForFunction(() => document.querySelectorAll('#gkAkis .gk-t').length >= 7);
    assert.equal(await page.$$eval('.gk-svg circle.k', l => l.length), 600, et('600 sandalye'));
    const metin = await page.textContent('#gkSalon');
    assert.match(metin, /CANLI/, et('canlı rozet'));
    assert.match(metin, /3'üncü Birleşim/, et('Türkçe sıra eki'));
    assert.match(metin, /BAŞKAN –/, et('tutanak başkan satırı'));
    assert.match(metin, /\(CYP sıralarından alkışlar\)/, et('tepki satırı'));
    assert.match(metin, /AYŞE KARADENİZLİOĞLU UZUNSOYADLI \(Trabzon\) –/, et('TBMM tutanak düzeni'));
    assert.match(metin, /EGEMENLİK KAYITSIZ ŞARTSIZ MİLLETİNDİR/, et('egemenlik yazısı'));
    assert.match(metin, /1\.840 izleyici/, et('izleyici sayısı'));
    assert.match(metin, /KABUL[\s\S]*RET[\s\S]*ÇEKİMSER/, et('işaret oylaması düğmeleri'));
    assert.match(metin, /EVET[\s\S]*HAYIR/, et('kanun oylaması düğmeleri'));
    assert.match(metin, /Başkanlık kürsüsü/, et('Başkanlık paneli'));
    assert.match(metin, /Zeynep Çokuzunsoyadlıoğlu/, et('söz sırası'));
    // oylama görünümü: sandalyeler oy rengini alır
    const yesil = await page.$$eval('.gk-svg circle.k', l => l.filter(c => c.getAttribute('fill') === '#2fbf71').length);
    assert.equal(yesil, 140, et('oylama görünümünde kabul sandalyeleri'));
    assert.deepEqual(await tasma(), [], et('salon taşma'));
    await cek('salon');
    // KABUL
    await tikla('[data-eylem="oy"][data-oy="kabul"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_oy'));
    assert.deepEqual((await son('gk_oy')).a, { p_oylama: 41, p_oy: 'kabul' }, et('işaret oyu'));
    // kanun EVET
    await tikla('[data-eylem="kanunoy"][data-oy="kabul"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'kanun_oy'));
    assert.deepEqual((await son('kanun_oy')).a, { p_id: 77, p_oy: 'kabul' }, et('kanun oyu'));
    // Başkan söz verir (kürsü doluyken düğme kapalı) → kürsüyü boşalt
    assert.equal(await page.$eval('[data-eylem="ver"]', b => b.disabled), true, et('kürsü doluyken söz ver kapalı'));
    await page.evaluate(() => { ST.bitti = true; ST.surum++; SO_GK._S.imza = {}; });
    await page.evaluate(() => window.CANLI && CANLI._ekran && CANLI._ekran().dinle && CANLI._ekran().dinle.calistir());
    await page.evaluate(async () => { await API.rpc('gk_durum', { p_surum: 0, p_son: 0 }); });
    await page.evaluate(() => tbmmSalonEkrani());
    await page.waitForFunction(() => { const b = document.querySelector('[data-eylem="ver"]'); return b && !b.disabled; });
    await tikla('[data-eylem="ver"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_soz_ver'));
    assert.deepEqual((await son('gk_soz_ver')).a, { p_soz: 31 }, et('söz ver'));
    // sırayı düzenle
    await tikla('[data-eylem="sira"][data-yon="1"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_soz_sira'));
    // Disiplin formu
    await tikla('[data-eylem="disiplin"]');
    await page.waitForSelector('#gkDK');
    await page.fill('#gkDK', 'mehmet'); await page.selectOption('#gkDT', 'kinama'); await page.fill('#gkDG', 'Genel Kurulda ağır hakaret');
    assert.deepEqual(await tasma(), [], et('disiplin formu taşma'));
    await tikla('#gkFOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_disiplin'));
    assert.deepEqual((await son('gk_disiplin')).a, { p_kad: 'mehmet', p_tur: 'kinama', p_gerekce: 'Genel Kurulda ağır hakaret', p_birlesim: 1 }, et('disiplin'));
    // Söz iste menüsü
    await temizle();
    await page.evaluate(() => { ST.oy = 'kabul'; });
    await page.evaluate(() => { const o = API.rpc; API.rpc = async (ad, a) => { const r = await o(ad, a); if (ad === 'gk_durum') { r.genel.oylama.durum = 'kabul'; } return r; }; });
    await page.evaluate(() => tbmmSalonEkrani());
    await page.waitForSelector('[data-eylem="soziste"]');
    await tikla('[data-eylem="soziste"]');
    await page.waitForSelector('.gk-sec[data-tur="kisisel"]');
    assert.equal(await page.$$eval('.gk-sec[data-tur]', l => l.length), 3, et('sataşma listede yok'));
    await cek('soz_iste');
    await tikla('.gk-sec[data-tur="kisisel"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_soz_iste'));
    assert.deepEqual((await son('gk_soz_iste')).a, { p_tur: 'kisisel', p_hedef: null }, et('söz iste'));
    // Söz bende: kelime sayacı + konuş
    await temizle();
    await page.evaluate(() => { ST.soz = true; ST.surum++; });
    await page.evaluate(() => tbmmSalonEkrani());
    await page.waitForSelector('#gkMetin');
    await page.fill('#gkMetin', 'Sayın Başkan değerli milletvekilleri fındık üreticisi zor durumda');
    await page.dispatchEvent('#gkMetin', 'input');
    assert.match(await page.textContent('#gkSay'), /8 \/ 150 kelime/, et('kelime sayacı'));
    await cek('konusma');
    await tikla('[data-eylem="konus"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_konus'));
    assert.equal((await son('gk_konus')).a.p_metin, 'Sayın Başkan değerli milletvekilleri fındık üreticisi zor durumda', et('konuş'));
    // Sataşma düğmesi
    await page.evaluate(() => { ST.soz = false; ST.surum++; });
    await page.evaluate(() => tbmmSalonEkrani());
    await page.waitForSelector('[data-eylem="satasma"]');
    await tikla('[data-eylem="satasma"]'); await page.waitForSelector('#gkFOk'); await tikla('#gkFOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_soz_iste' && c.a.p_tur === 'satasma'));
    // Yoklama: BURADAYIM
    await temizle();
    await page.evaluate(() => { ST.yoklama = true; ST.surum++; });
    await page.evaluate(() => tbmmSalonEkrani());
    await page.waitForSelector('[data-eylem="buradayim"]');
    assert.match(await page.textContent('#gkPano'), /120 milletvekili hazır/, et('yoklama panosu'));
    await cek('yoklama');
    await tikla('[data-eylem="buradayim"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_buradayim'));
    // İzleyici (halk galerisi): oy/söz düğmesi yok, alkış var
    await page.evaluate(() => { ST.yoklama = false; ST.rol = 'izleyici'; ST.surum++; });
    await page.evaluate(() => tbmmSalonEkrani());
    await page.waitForFunction(() => /Halk galerisindesin/.test(document.getElementById('gkDock').textContent));
    assert.equal(await page.$('[data-eylem="soziste"]'), null, et('izleyici söz isteyemez'));
    assert.equal(await page.$('#gkBaskan details'), null, et('izleyicide Başkanlık paneli yok'));
    await tikla('[data-eylem="tepki"][data-tur="alkis"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'gk_tepki'));
    assert.deepEqual(await tasma(), [], et('izleyici taşma'));
    await cek('izleyici');
    // Tutanak arşivi
    await page.evaluate(() => tbmmTutanakArsiviAc());
    await page.waitForSelector('.gk-sec[data-id="2"]');
    await tikla('.gk-sec[data-id="2"]');
    await page.waitForSelector('#gkArsiv .gk-t');
    assert.match(await page.textContent('#gkArsiv'), /GENEL KURUL TUTANAĞI/, et('arşiv tutanağı'));
    await cek('tutanak');

    // 2) Meclis sekmesi: canlı kart + Çalışmalar
    await page.evaluate(() => { meclisSekmeAc('calisma'); });
    await page.waitForSelector('.tm-izgara .tm-kut');
    const mk = await page.textContent('#icerik');
    assert.match(mk, /Genel Kurul toplantıda · 3'üncü Birleşim/, et('canlı Genel Kurul kartı'));
    assert.match(mk, /Çalışmalar/, et('Çalışmalar sekmesi'));
    assert.match(mk, /2017 Anayasa değişikliğiyle kaldırıldı/, et('gensoru bilgisi'));
    assert.deepEqual(await tasma(), [], et('Meclis Çalışmalar taşma'));
    await cek('meclis_calismalar');
    const ekranlar = [['kom', '.tm-oge[data-kom]'], ['soru', '.tm-oge'], ['gg', '.tm-oge'], ['ar', '.tm-oge[data-ar]'], ['dil', '.tm-oge'], ['hb', '.tm-oge[data-hb]'], ['karne', '.tm-puan']];
    for (const [ad, sec] of ekranlar) {
      await page.evaluate((ad) => { D.yigin = []; tbmmMerkez.git(ad); }, ad);
      await page.waitForSelector(sec);
      assert.deepEqual(await tasma(), [], et(ad + ' taşma'));
      await cek('merkez_' + ad);
    }
    // komisyon salonu + konuşma
    await page.evaluate(() => { D.yigin = []; tbmmMerkez.git('kom'); });
    await tikla('.tm-oge[data-kom="tarim"]');
    await page.waitForSelector('#tmKomMetin');
    await page.fill('#tmKomMetin', 'Teklifi destekliyoruz.');
    await tikla('[data-k="konus"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'kom_konus'));
    assert.deepEqual((await son('kom_konus')).a, { p_kom: 'tarim', p_metin: 'Teklifi destekliyoruz.' }, et('komisyonda konuşma'));
    assert.deepEqual(await tasma(), [], et('komisyon taşma'));
    await cek('komisyon');
    await tikla('[data-kanun="77"]');
    await page.waitForSelector('[data-oy="ret"]');
    await tikla('[data-oy="ret"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'komisyon_oy'));
    assert.equal((await son('komisyon_oy')).a.p_oy, 'ret', et('komisyon oyu'));
    // soru önergesi ver
    await page.evaluate(() => { D.yigin = []; tbmmMerkez.git('soru'); });
    await tikla('[data-k="ver"]');
    await page.waitForSelector('#tmSH');
    await page.selectOption('#tmSH', 'cby'); await page.fill('#tmSK', 'Asgari ücret'); await page.fill('#tmSS', '1- Asgari ücrete ara zam yapılacak mı?');
    await tikla('#gkFOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'tbmm_soru_ver'));
    assert.deepEqual((await son('tbmm_soru_ver')).a, { p_bakanlik: 'cby', p_konu: 'Asgari ücret', p_soru: '1- Asgari ücrete ara zam yapılacak mı?', p_hb_soru: null }, et('soru önergesi'));
    // halk buluşması detay + soru
    await temizle();
    await page.evaluate(() => { D.yigin = []; tbmmMerkez.git('hb'); });
    await tikla('.tm-oge[data-hb="5"]');
    await page.waitForSelector('#tmHS');
    await page.fill('#tmHS', 'Esnafa vergi affı gelecek mi?');
    await tikla('[data-k="sor"]');
    await page.waitForFunction(() => calls.some(c => c.ad === 'hb_soru_sor'));
    assert.deepEqual(await tasma(), [], et('halk buluşması taşma'));
    await cek('halk_bulusmasi');
    // dilekçe komisyon kararı
    await page.evaluate(() => { D.yigin = []; tbmmMerkez.git('dil'); });
    await tikla('.tm-seg [data-f="komisyon"]');
    await page.waitForSelector('[data-dk="bakanliga"]');
    await tikla('[data-dk="bakanliga"]'); await page.waitForSelector('#tmDKB'); await tikla('#gkFOk');
    await page.waitForFunction(() => calls.some(c => c.ad === 'tbmm_dilekce_karar'));
    assert.deepEqual((await son('tbmm_dilekce_karar')).a, { p_id: 2, p_karar: 'bakanliga', p_metin: null, p_bakanlik: 'tarim' }, et('dilekçe kararı'));
    await temizle();
    await page.close();
  }
  await browser.close();
  if (hatalar.length) { console.error('SAYFA HATALARI:\n' + hatalar.join('\n')); process.exit(1); }
  console.log('TBMM arayüz testi: TAMAM (390 ve 320 px)');
})().catch(e => { console.error(e); process.exit(1); });
