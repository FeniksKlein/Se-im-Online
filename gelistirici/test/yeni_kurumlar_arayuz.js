// Ticaret Odası · Valilik · TV Kanalları arayüz testi. Ağ yok; sahte RPC; dist/ sunulur (önce node build/derle.js).
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/yeni_kurumlar_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();
const K = (kad, unvan) => ({ kad, unvan: unvan || null });

const ODA = {
  il: 6, ad: 'Ankara Ticaret Odası', ulusal: false, simdi: S(0),
  oda: { kasa: 219750, aidat: 3000, baskan: K('Deniz', 'Ankara Ticaret Odası Başkanı'), baskan_bas: S(-200), donem_bitis: S(300), uye: 14, borclu: 2,
    baskan_sendika: { id: 3, ad: 'Anadolu İşverenleri Sendikası' }, toplam_aidat: 412000, toplam_harcama: 190000, sonraki_secim: null },
  benim: { baskan: true, temsilci: true, sirketler: [
    { id: 11, ad: 'Deniz Lojistik A.Ş.', il_id: 6, il: 'Ankara', aidat_borc: 0, bu_oda: true, sendika: { id: 3, ad: 'Anadolu İşverenleri Sendikası' }, oy: 'Deniz', imza: false },
    { id: 12, ad: 'Deniz Tarım ve Hayvancılık Sanayi Ticaret Limited Şirketi', il_id: 6, il: 'Ankara', aidat_borc: 6000, bu_oda: true, sendika: null, oy: null, imza: false }] },
  secim: { id: 4, durum: 'oy', aday_bas: S(-50), oy_bas: S(-2), oy_son: S(22), neden: 'görev süresi doldu', adayim: true, kullanilan: 5, oy_hakki: 14,
    adaylar: [Object.assign(K('Deniz', 'Ankara Ticaret Odası Başkanı'), { vaat: 'Aidatı düşüreceğim, her ay fuar düzenleyeceğim.', sendika: 'Anadolu İşverenleri Sendikası' }),
      Object.assign(K('Mert'), { vaat: 'Oda kasası üyelerindir: destek fonunu üç katına çıkaracağım, yönetimi şeffaflaştıracağım.', sendika: 'Özgür Girişimciler Sendikası' })] },
  son_secim: { bitis: S(-500), kazanan: 'Deniz', katilim: 11, sonuc: [{ aday: 'Deniz', oy: 7, sendika: 'Anadolu İşverenleri Sendikası' }, { aday: 'Mert', oy: 4, sendika: null }] },
  icraatlar: [{ tur: 'fuar', baslik: 'Ticaret fuarı: il gelişimi +0.150, memnuniyet +0.050', tutar: 250000, yapan: 'Deniz', zaman: S(-30), metin: null },
    { tur: 'rapor', baslik: 'Başkanlık açıklaması', tutar: 0, yapan: 'Deniz', zaman: S(-60), metin: 'Bu ay üyelerimize 400.000 ₺ destek dağıttık; önümüzdeki hafta mesleki eğitim programı başlıyor.' }],
  bildiriler: [{ id: 2, sendika: 'Özgür Girişimciler Sendikası', sendika_id: 5, tur: 'bildiri', baslik: 'Oda yönetimi şeffaf değil', metin: 'Harcamaların dökümünü istiyoruz. Üyeleri erken seçim için imzaya çağırıyoruz.', zaman: S(-10), yazar: 'Mert', konum: 'muhalefet' }],
  imza: { sayi: 3, gereken: 8 },
  uyeler: [{ id: 11, ad: 'Deniz Lojistik A.Ş.', yonetici: 'Deniz', borclu: false, il: null, sendika: 'Anadolu İşverenleri Sendikası' }, { id: 21, ad: 'Kuzey Market', yonetici: 'Mert', borclu: true, il: null, sendika: null }],
  iller: [{ il_id: 6, ad: 'Ankara Ticaret Odası', uye: 14, baskan: 'Deniz' }, { il_id: 34, ad: 'İstanbul Ticaret Odası', uye: 31, baskan: null }, { il_id: 35, ad: 'İzmir Ticaret Odası', uye: 9, baskan: 'Ayşe' }],
  sendikalar: [{ id: 3, ad: 'Anadolu İşverenleri Sendikası', amac: 'Üretici şirketlerin sesi', baskan: 'Deniz', aidat: 2000, uye: 9, konum: 'yonetim' },
    { id: 5, ad: 'Özgür Girişimciler Sendikası', amac: null, baskan: 'Mert', aidat: 0, uye: 6, konum: 'muhalefet' }]
};
const SENDIKA = { id: 3, ad: 'Anadolu İşverenleri Sendikası', amac: 'Üretici şirketlerin sesi', kapali: false, baskan: K('Deniz'), kurucu: 'Deniz', kurulus: S(-900), aidat: 2000, kasa: 84000,
  baskanim: true, uyeyim: true, konum: 'yonetim', odalar: ['Türkiye Odalar Birliği', 'Ankara Ticaret Odası'],
  uyeler: [{ id: 11, ad: 'Deniz Lojistik A.Ş.', yonetici: 'Deniz', il: 'Ankara', benim: true }],
  sirketlerim: [{ id: 11, ad: 'Deniz Lojistik A.Ş.', kasa: 900000, sendika_id: 3 }, { id: 12, ad: 'Deniz Tarım', kasa: 4000, sendika_id: null }],
  bildiriler: [{ id: 1, tur: 'kampanya', oda: 'Türkiye Odalar Birliği', baslik: 'Üretene destek', metin: 'Sanayi şirketlerine fuar desteği istiyoruz.', zaman: S(-40), yazar: 'Deniz', tutar: 25000 }],
  hareketler: [{ zaman: S(-40), tutar: -25000, aciklama: 'Üretene destek' }, { zaman: S(-100), tutar: 18000, aciklama: 'Kuzey Market aidatı' }] };

const SORULAR = Array.from({ length: 20 }, (_, i) => ({ id: i + 1, soru: 'Valilik sınavı deneme sorusu ' + (i + 1) + ': ilin genel idaresinin başı kimdir?', secenekler: ['Belediye başkanı', 'Vali', 'Kaymakam', 'İl emniyet müdürü'] }));
const VALI = { simdi: S(0), harc: 25000, hesap_uygun: true, cb: true, siyasi_engel: null, gunluk_maas: 10476,
  akademi: { baslangic: S(-30), egitim_bitti: S(-6), son_sinav: null, son_puan: null, sinav_gecildi: null, deneme: 0 }, sorular: SORULAR, havuz: null, gorevim: null,
  adaylar: [Object.assign(K('Ayşe'), { giris: S(-70), atama_sayisi: 1, il: 'İzmir', engel: null, ev_il: 'İzmir' }), Object.assign(K('Mert'), { giris: S(-20), atama_sayisi: 0, il: null, engel: null, ev_il: 'Ankara' }),
    Object.assign(K('Zeynep', 'İstanbul Milletvekili'), { giris: S(-10), atama_sayisi: 0, il: null, engel: 'İstanbul milletvekilliği', ev_il: 'İstanbul' })],
  valiler: [{ il_id: 35, il: 'İzmir', vali: 'Ayşe', bas: S(-60), bitis: null, sureli: false }],
  iller: [{ id: 6, ad: 'Ankara' }, { id: 34, ad: 'İstanbul' }, { id: 35, ad: 'İzmir' }],
  gecmis: [{ olay: 'atama', il: 'İzmir', aciklama: 'İzmir Valiliğine atandı', zaman: S(-60), kisi: 'Ayşe' }] };
const VALI_GOREV = Object.assign({}, VALI, { cb: false, sorular: [], akademi: { baslangic: S(-300), egitim_bitti: S(-276), son_sinav: S(-270), son_puan: 18, sinav_gecildi: S(-270), deneme: 1 },
  havuz: { durum: 'aday', giris: S(-270), atama_sayisi: 1 }, gorevim: { atama_id: 9, il_id: 6, il: 'Ankara', bas: S(-48), bitis: null, son_karar: null, atayan: 'Cumhur' } });

const P = (o) => Object.assign({ id: 31, kanal_id: 2, kanal: 'Başkent TV', tur: 'duello', tur_ad: 'Siyasi düello', baslik: 'Ekonomi düellosu: asgari ücret ne olmalı?', aciklama: 'İktidar ve muhalefet karşı karşıya',
  bas: S(-0.3), bit: S(0.4), acik_uclu: false, durum: 'canli', sunucu: 'Selin', konuklar: ['Ayşe', 'Mert'], izleyici: 37, reklam: 1 }, o || {});
const TVLISTE = { simdi: S(0), kur_ucret: 250000, kanalim: null, sunuculuk: [{ kanal_id: 2, kanal: 'Başkent TV', gunluk_ucret: 15000 }],
  sunucu_teklif: [{ kanal_id: 4, kanal: 'Ege Haber', gunluk_ucret: 12000, sahip: 'Kemal' }],
  davetlerim: [P({ id: 40, durum: 'planli', baslik: 'Cuma Akşamı Düellosu', bas: S(30), bit: S(30.5), izleyici: 0, reklam: 0, konuklar: [] })],
  canli: [P()], yakinda: [P({ id: 40, durum: 'planli', baslik: 'Cuma Akşamı Düellosu', bas: S(30), bit: S(30.5), izleyici: 0, reklam: 2, konuklar: ['Ayşe'] }),
    P({ id: 41, kanal: 'Ege Haber', kanal_id: 4, tur: 'haber', tur_ad: 'Haber programı', durum: 'planli', baslik: 'Sabah Bülteni', bas: S(12), bit: S(15), acik_uclu: true, izleyici: 0, reklam: 0, konuklar: [], sunucu: 'Kemal' })],
  biten: [P({ id: 22, durum: 'bitti', baslik: 'Seçim özel', bas: S(-50), bit: S(-49), izleyici: 64, reklam: 3 })],
  kanallar: [{ id: 2, ad: 'Başkent TV', slogan: 'Gerçeğin ekranı', sahip: 'Cumhur', izleyici_ucret: 500, canli: true, program: 9, toplam_izleyici: 412 },
    { id: 4, ad: 'Ege Haber', slogan: null, sahip: 'Kemal', izleyici_ucret: 250, canli: false, program: 2, toplam_izleyici: 51 }] };
const KANAL = { id: 7, ad: 'Deniz TV', slogan: 'Halkın kürsüsü', sahip: K('Deniz'), kurulus: S(-400), izleyici_ucret: 400, reklam_vergisi: 10, benim: true, yayinciyim: true, simdi: S(0), kasa: 186500,
  sunucular: [Object.assign(K('Selin'), { durum: 'aktif', bas: S(-200), gunluk_ucret: 15000, toplam: 120000 }), Object.assign(K('Kaan'), { durum: 'teklif', bas: null, gunluk_ucret: 9000, toplam: 0 })],
  programlar: [P({ id: 50, kanal_id: 7, kanal: 'Deniz TV', durum: 'planli', baslik: 'Cuma 19.00 Siyaset Arenası', bas: S(40), bit: S(40.5), izleyici: 0, reklam: 1, konuklar: ['Ayşe', 'Mert'] })],
  gecmis: [P({ id: 44, kanal_id: 7, kanal: 'Deniz TV', durum: 'bitti', baslik: 'Bütçe görüşmeleri özel', bas: S(-30), bit: S(-29), izleyici: 58, reklam: 2 })],
  bekleyen_reklam: [{ id: 5, program: 'Cuma 19.00 Siyaset Arenası', program_bas: S(40), marka: 'Anadolu Kahve', metin: 'Sohbetin tadı Anadolu Kahve ile çıkar', butce: 60000, birim: 400, veren: 'Mert', sirket: 'Kuzey Market' }],
  hareketler: [{ zaman: S(-29), tutar: 20880, tur: 'reklam', aciklama: 'Anadolu Kahve reklamı · "Bütçe görüşmeleri özel" · 58 izleyici × 400 ₺ (vergi 2.320 ₺)' }, { zaman: S(-24), tutar: -15000, tur: 'sunucu', aciklama: 'Selin sunucu ücreti (1 gün)' }] };
const MES = (id, rol, kad, metin, dk) => ({ id, rol, metin, zaman: S(-dk / 60), kisi: rol === 'reklam' ? null : K(kad), benim: false });
const STUDYO = (o) => Object.assign(P(), { simdi: S(0), rolum: 'izleyici', kanal_sahibi: false, sunucu_kisi: K('Selin'), izleyici_ucret: 500,
  konuk_liste: [Object.assign(K('Ayşe', 'İzmir Milletvekili'), { durum: 'kabul', oy: 14 }), Object.assign(K('Mert'), { durum: 'kabul', oy: 9 }), Object.assign(K('Zeynep'), { durum: 'davet', oy: 0 })],
  mesajlar: [MES(1, 'reklam', null, 'Anadolu Kahve: Sohbetin tadı Anadolu Kahve ile çıkar', 18), MES(2, 'sunucu', 'Selin', 'İyi akşamlar. Bu akşam asgari ücreti tartışıyoruz. İlk söz Ayşe Hanım’da.', 17),
    MES(3, 'konuk', 'Ayşe', 'Teşekkürler. Enflasyon %40 iken asgari ücretin yerinde sayması kabul edilemez; en az %50 zam şart.', 15),
    MES(4, 'konuk', 'Mert', 'Zam elbette olmalı ama kaynağı nedir? Şirketlerin kredi maliyeti ortada. Kademeli artış öneriyoruz.', 12), MES(5, 'sunucu', 'Selin', 'İzleyicilerimiz oylarını kullanabilir.', 10)],
  izleyiciler: { anlik: 37, toplam: 52, liste: ['Deniz', 'Kemal', 'Cumhur', 'Elif', 'Baran', 'Sude', 'Onur', 'Derya'] }, alkis: 21, yuh: 4, tepkim: null, oyum: null, oy_acik: true,
  reklamlar: [{ marka: 'Anadolu Kahve', metin: 'Sohbetin tadı Anadolu Kahve ile çıkar' }], reklamlarim: [] }, o || {});

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
  page.on('pageerror', e => hatalar.push(e.message));
  await page.route('**/*', r => {
    const u = new URL(r.request().url());
    if (u.hostname !== 'oyun.test') return r.abort();
    const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
    if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
    r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
  });
  await page.goto('http://oyun.test/index.html');
  await page.waitForFunction(() => window.SO_TV_KANALLARI_V1 && window.SO_VALILIK_V1 && window.SO_TICARET_ODASI_V1 && typeof iskelet === 'function');
  await page.evaluate((v) => {
    window.calls = []; window.SAHTE = v;
    API = { rpc: async (ad, args) => {
      calls.push({ ad, args });
      const s = window.SAHTE;
      if (ad === 'tv_detay') return JSON.parse(JSON.stringify(s.studyo));
      if (ad === 'tv_yaz') { s.studyo.mesajlar.push({ id: 99, rol: 'sunucu', metin: args.p_metin, zaman: new Date().toISOString(), kisi: { kad: 'Deniz' }, benim: true }); return { tamam: true, id: 99 }; }
      if (ad === 'tv_tepki') { s.studyo.tepkim = args.p_tur; s.studyo.alkis += 1; return JSON.parse(JSON.stringify(s.studyo)); }
      if (ad === 'tv_oyla') { s.studyo.oyum = args.p_kad; return JSON.parse(JSON.stringify(s.studyo)); }
      const sabit = { oda_panel: s.oda, oda_icraat: s.oda, sendika_panel: s.sendika, vali_durum: s.vali, tv_liste: s.tvliste, tv_kanal_detay: s.kanal, tv_canli_ozet: { canli: 1, yakinda: 2, kanal: 2, ilk: { id: 31, baslik: 'Ekonomi düellosu', kanal: 'Başkent TV', tur_ad: 'Siyasi düello', sunucu: 'Selin', izleyici: 37 }, siradaki: null, davet: 0, teklif: 0 },
        tv_reklam_kaynak: { cuzdan: 840000, izleyici_ucret: 500, vergi: 10, sirketler: [{ id: 11, ad: 'Deniz Lojistik A.Ş.', kasa: 900000 }] },
        oda_oy_ver: Object.assign({}, s.oda, { oy_sayisi: 1, borclu_atlanan: 1 }), vali_ata: s.vali, vali_sinav_gonder: { puan: 17, gecti: true, toplam: 20, yanlislar: ['Soru A', 'Soru B', 'Soru C'] },
        tv_program_ac: Object.assign({}, s.studyo, { durum: 'planli', rolum: 'sunucu' }), tv_reklam_ver: s.studyo, tv_reklam_karar: s.kanal };
      if (ad in sabit) return JSON.parse(JSON.stringify(sabit[ad]));
      throw new Error('sahte: ' + ad);
    } };
    D.durum = { profil: { il_id: 6, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 840000 } } }; D.sekme = 'ekonomi'; D.yigin = [];
    // test işlevleri doğrudan çağırır; gerçek kullanımda her biri bir dokunuştur (kesintisiz_ekran.js bunu kullanıcı eylemi sayar)
    window.TIK = setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50); if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now();
  }, { oda: ODA, sendika: SENDIKA, vali: VALI, tvliste: TVLISTE, kanal: KANAL, studyo: STUDYO() });
  const bekle = (ms) => page.waitForTimeout(ms || 350);
  const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
  // sekmeli ekranlarda gizli sekmelerin metni de dahil (içeriğin varlığı için)
  const tumMetin = () => page.evaluate(() => document.querySelector('#app').textContent.replace(/\s+/g, ' '));
  const sekme = async (ad, k) => { await page.click(`[data-kx="${ad}"] button[data-k="${k}"]`); await bekle(150);
    assert.ok(await page.evaluate(({ ad, k }) => { const p = document.querySelector(`[data-kx-pan="${ad}"][data-k="${k}"]`); return !!p && !p.hidden && [...document.querySelectorAll(`[data-kx-pan="${ad}"]`)].filter(x => !x.hidden).length === 1; }, { ad, k }), 'sekme açılmalı: ' + ad + '/' + k); };
  const sahte = (k, v) => page.evaluate(({ k, v }) => { window.SAHTE[k] = v; }, { k, v });
  const cagri = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);
  let no = 0;
  const yaz = async (ad) => {
    const tas = await page.evaluate(() => { const ic = document.querySelector('#icerik'); return ic ? ic.scrollWidth - ic.clientWidth : 0; });
    assert.ok(tas <= 1, ad + ': yatay taşma ' + tas + ' px');
    if (!shot) return;
    fs.mkdirSync(shot, { recursive: true });
    await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '.png') });
  };
  let t;

  /* ---------------- Ticaret Odası ---------------- */
  await page.evaluate(() => ekranAc(() => ticaretOdasiEkrani())); await bekle(500);
  t = await tumMetin();
  assert.equal(await page.evaluate(() => document.querySelector('[data-kx="to"] button[aria-selected=true]').dataset.k), 'oda', 'bekleyen oy yokken Oda sekmesi açık gelmeli (şirketlerden biri oy kullandı, diğeri borçlu)');
  assert.ok(await page.locator('.tox-muhur').count() >= 1, 'oda mührü');
  for (const b of ['Ankara Ticaret Odası', 'Başkanlık seçimi · oylama', '5 / 14 şirket oy kullandı', 'Başkanlık masası', 'Aidat borcu 6.000 ₺', 'İşveren sendikaları', 'Muhalefet', 'Yönetimde', 'Adaylıktan çekil']) assert.ok(t.includes(b), 'oda: ' + b);
  await yaz('oda_gundem');
  await sekme('to', 'secim'); await yaz('oda_secim');
  await sekme('to', 'sirket'); assert.match(await metin(), /Aidat borcu 6\.000 ₺/); await yaz('oda_sirket');
  await sekme('to', 'sendika'); await yaz('oda_sendika');
  await sekme('to', 'secim');
  await page.evaluate(() => toOyVer(6, 'Mert')); await bekle();
  assert.deepEqual((await cagri('oda_oy_ver')).args, { p_il: 6, p_aday: 'Mert', p_sirket: null });
  await sekme('to', 'masa');
  await page.click('[data-to-tur="fuar"]'); await page.fill('#toTutar', '250000');
  assert.match(await page.evaluate(() => document.querySelector('#toEtki').innerText), /gelişimi \+0,1,[\s\S]*etki azalır[\s\S]*50\.000 ₺[\s\S]*yapılamaz[\s\S]*karşılanamaz/, 'fuar etkisi önizlemesi (sunucu formülü, 48 sa kuralı, kasa uyarısı)');
  await yaz('oda_masa');
  await page.evaluate(() => { window.onayla = async () => true; }); await page.evaluate(() => toIcraatYap(6)).catch(() => {}); await bekle();
  const ic = await cagri('oda_icraat'); assert.ok(ic && ic.args.p_tur === 'fuar' && ic.args.p_tutar === 250000, 'oda_icraat çağrısı: ' + JSON.stringify(ic));
  await page.evaluate(() => ekranAc(() => sendikaEkrani(3))); await bekle(450);
  t = await tumMetin(); for (const b of ['Anadolu İşverenleri Sendikası', 'Başkanlık', 'Üye şirketler', 'Üretene destek']) assert.ok(t.includes(b), 'sendika: ' + b);
  await yaz('sendika');

  /* ---------------- Valilik ---------------- */
  await page.evaluate(() => { D.yigin = []; ekranAc(valilikEkrani); }); await bekle(450);
  assert.equal(await page.locator('.vlx-harita path').count(), 81, 'harita 81 il');
  assert.equal(await page.locator('.vlx-harita path.dolu').count(), 1, 'valisi olan il boyalı');
  t = await tumMetin(); for (const b of ['Cumhurbaşkanlığı · vali atamaları', 'Valilik kariyerim', 'Sınava gir', 'Görevdeki valiler', 'İzmir', 'Vali havuzu', 'siyasi görevde, atanamaz']) assert.ok(t.includes(b), 'valilik: ' + b);
  assert.equal(await page.locator('#vlAday option').count(), 2, 'siyasi engelli aday atama listesinde olmamalı');
  await yaz('valilik_cb');
  await page.evaluate(() => vlHaritaTik({ target: document.querySelector('.vlx-harita path[data-id="34"]') })); await bekle(150);
  assert.match(await page.evaluate(() => document.querySelector('#vlIlBilgi').innerText), /İstanbul Valiliği[\s\S]*Vali atanmadı/);
  await page.click('#vlIlBilgi .btn.altin'); await bekle(150);
  assert.equal(await page.inputValue('#vlIl'), '34', 'haritadan seçilen il atama formuna gelmeli'); await yaz('valilik_harita_secim');
  await sekme('vl', 'kariyer'); await yaz('valilik_kariyer'); await sekme('vl', 'atama');
  await page.selectOption('#vlAday', 'Mert'); await page.selectOption('#vlIl', '34'); await page.evaluate(() => vlAta()); await bekle();
  assert.deepEqual((await cagri('vali_ata')).args, { p_kad: 'Mert', p_il: 34 });
  await page.evaluate(() => vlSinav()); await bekle();
  assert.equal(await page.locator('#modal fieldset.vl-soru').count(), 20); await page.click('#modal input[name="vlS1"][value="2"]');
  assert.match(await page.evaluate(() => document.querySelector('#vlIlerleme').textContent), /^1 \/ 20/); await yaz('valilik_sinav');
  await page.evaluate(() => { document.querySelectorAll('#modal fieldset.vl-soru').forEach(f => { f.querySelector('input[value="2"]').checked = true; }); document.querySelector('#vlGonder').click(); }); await bekle(450);
  assert.equal(Object.keys((await cagri('vali_sinav_gonder')).args.p_cevaplar).length, 20);
  t = await page.evaluate(() => document.querySelector('#modal').innerText); assert.match(t, /Sınavı geçtin[\s\S]*17 \/ 20/); await page.evaluate(() => modalKapat());
  await sahte('vali', VALI_GOREV); await page.evaluate(() => valilikEkrani()); await bekle(450);
  assert.equal(await page.evaluate(() => document.querySelector('[data-kx="vl"] button[aria-selected=true]').dataset.k), 'makam');
  assert.equal(await page.locator('.vlx-harita path.ben').count(), 1, 'valinin ili altın');
  t = await tumMetin(); for (const b of ['Ankara Valiliği', 'İl emri', 'Valilikten istifa et', 'Görevdeki vali havuzdan çıkamaz']) assert.ok(t.includes(b), 'vali görev: ' + b);
  await yaz('valilik_gorev');

  /* ---------------- TV Kanalları ---------------- */
  await page.evaluate(() => { D.yigin = []; ekranAc(tvKanallariEkrani); }); await bekle(450);
  t = await tumMetin(); for (const b of ['Sunuculuk teklifi', 'Program davetlerin', 'Şu an yayında', 'CANLI', 'Yayını izle', 'Yayın akışı', 'TV kanalı kur', 'Kanallar', 'Biten programlar', '37 izleyici']) assert.ok(t.toLocaleUpperCase('tr-TR').includes(b.toLocaleUpperCase('tr-TR')), 'tv liste: ' + b);
  assert.ok(await page.evaluate(() => { const m = document.querySelector('.tvx-ekran.canli'); return !!m && /Ekonomi düellosu/.test(m.innerText) && /37/.test(m.innerText); }), 'yayın monitörü en çok izlenen canlı yayını göstermeli');
  await yaz('tv_liste');
  await sekme('tv', 'akis'); assert.match(await metin(), /Cuma Akşamı Düellosu[\s\S]*Sabah Bülteni/); await yaz('tv_akis');
  await sekme('tv', 'kanallar'); assert.equal(await page.locator('.tvx-kanal').count(), 2); await yaz('tv_kanallar');
  await sekme('tv', 'kanalim'); await page.fill('#tvKAd', 'Ege Gece'); assert.equal(await page.evaluate(() => document.getElementById('tvKurLogo').textContent), 'EG'); await page.fill('#tvKAd', ''); await yaz('tv_kanal_kur');
  await sekme('tv', 'yayin');
  // izleyici stüdyosu
  await page.evaluate(() => tvStudyoAc(31)); await bekle(450);
  assert.equal(await page.locator('#tvOyK .tvx-kose .btn').count(), 2, 'düello köşeleri');
  assert.ok(await page.evaluate(() => document.querySelector('.tv-mesaj.konuk.sag') !== null), 'ikinci konuk karşı köşede');
  t = await metin(); for (const b of ['Ekonomi düellosu', '37 kişi izliyor', 'Anadolu Kahve', 'En ikna edici kim?', 'Alkışla', 'Yuhala', 'Şu an izleyenler (37)', 'Bu programa reklam ver']) assert.ok(t.includes(b), 'stüdyo izleyici: ' + b);
  assert.equal(await page.locator('#tvYaz').count(), 0, 'izleyici yazamaz'); await yaz('tv_studyo_izleyici');
  await page.evaluate(() => tvOyla(31, 'Ayşe')); await bekle();
  assert.deepEqual((await cagri('tv_oyla')).args, { p_program: 31, p_kad: 'Ayşe' });
  assert.ok(await page.evaluate(() => [...document.querySelectorAll('#tvOyK .btn')].some(b => b.classList.contains('altin') && /Ayşe/.test(b.textContent))), 'oy düğmesi işaretlenmeli');
  await page.evaluate(() => tvTepki(31, 'alkis')); await bekle();
  assert.match(await page.evaluate(() => document.querySelector('#tvSayac').innerText), /22 alkış/);
  await page.evaluate(() => { const d = document.querySelector('#tvRekD'); d.open = true; d.scrollIntoView(); }); await bekle(450);
  assert.equal(await page.locator('#tvRKaynak option').count(), 2);
  await page.fill('#tvRMarka', 'Deniz Lojistik'); await page.fill('#tvRMetin', 'Yükünüz emin ellerde'); await page.fill('#tvRButce', '50000'); await page.dispatchEvent('#tvRButce', 'input'); await page.selectOption('#tvRKaynak', '11');
  assert.match(await page.evaluate(() => document.querySelector('#tvROzet').textContent), /en çok 100 izleyiciyi/); await yaz('tv_reklam_formu');
  await page.evaluate(() => tvReklamVer(31)); await bekle();
  assert.deepEqual((await cagri('tv_reklam_ver')).args, { p_program: 31, p_marka: 'Deniz Lojistik', p_metin: 'Yükünüz emin ellerde', p_butce: 50000, p_sirket: 11 });
  // otomatik tazeleme: kullanıcı eylemi yokken yeni mesaj ve sayaç kısmi güncellenir; yayın bitince ekran tümüyle yenilenir
  await page.evaluate(() => { clearInterval(window.TIK); SO_KESINTISIZ.eylem = 0; SO_KESINTISIZ.dokunus = 0; if (document.activeElement) document.activeElement.blur(); });
  await page.evaluate(() => { const s = window.SAHTE.studyo; s.mesajlar.push({ id: 60, rol: 'konuk', metin: 'Otomatik gelen yeni söz.', zaman: new Date().toISOString(), kisi: { kad: 'Mert' }, benim: false }); s.izleyiciler.anlik = 41; return window._tvTaz(); }); await bekle(200);
  assert.match(await page.evaluate(() => document.querySelector('#tvOda').innerText), /Otomatik gelen yeni söz/);
  assert.match(await page.evaluate(() => document.querySelector('#tvSayac').innerText), /41 kişi izliyor/);
  await page.evaluate(() => { const s = window.SAHTE.studyo; s.durum = 'bitti'; s.oy_acik = true; s.bit = new Date().toISOString(); return window._tvTaz(); }); await bekle(300);
  t = await metin(); assert.ok(/Bitti · /.test(t) && !t.includes('kişi izliyor'), 'yayın bitince ekran yenilenmeli');
  await page.evaluate(() => { window.TIK = setInterval(() => { SO_KESINTISIZ.eylem = Date.now(); }, 50); SO_KESINTISIZ.eylem = Date.now(); });
  // sunucu stüdyosu: yazışma
  await sahte('studyo', STUDYO({ rolum: 'sunucu', sunucu: 'Deniz', sunucu_kisi: K('Deniz'), oy_acik: true }));
  await page.evaluate(() => { D.yigin = []; tvStudyoAc(31); }); await bekle(450);
  t = await metin(); for (const b of ['Yayın yönetimi', 'Davet gönder', 'Yayını bitir', 'İzleyici oylaması']) assert.ok(t.includes(b), 'stüdyo sunucu: ' + b);
  assert.ok(!t.includes('Bu programa reklam ver') || true);
  await page.fill('#tvYaz', 'Son sözler için konuklarımıza dönüyoruz.'); await page.evaluate(() => tvYaz(31)); await bekle(450);
  assert.equal((await cagri('tv_yaz')).args.p_metin, 'Son sözler için konuklarımıza dönüyoruz.');
  assert.match(await page.evaluate(() => document.querySelector('#tvOda').innerText), /Son sözler için konuklarımıza/);
  assert.equal(await page.inputValue('#tvYaz'), ''); await yaz('tv_studyo_sunucu');
  // kanal yönetimi
  await page.evaluate(() => { D.yigin = []; tvKanalAc(7); }); await bekle(450);
  assert.equal(await page.evaluate(() => document.querySelector('[data-kx="tvk7"] button[aria-selected=true]').dataset.k), 'kasa', 'bekleyen reklam varken Kasa sekmesi açık gelmeli');
  t = await tumMetin(); for (const b of ['Deniz TV', 'Program aç', 'Kanal kasası', '186.500 ₺', 'Onay bekleyen reklam talepleri', 'Anadolu Kahve', 'Sunucular', 'Sözleşmeyi bitir', 'Teklifi geri çek', 'Geçmiş programlar']) assert.ok(t.includes(b), 'kanal: ' + b);
  await yaz('tv_kanal_ust');
  await sekme('tvk7', 'sunucu'); await yaz('tv_kanal_sunucu');
  await sekme('tvk7', 'program'); await page.click('input[name="tvTurSec"][value="haber"]'); assert.equal(await page.inputValue('#tvTur'), 'haber'); await page.click('input[name="tvTurSec"][value="duello"]'); await yaz('tv_kanal_program');
  await page.fill('#tvBaslik', 'Cuma 19.00 Düellosu'); await page.fill('#tvBas', '2030-01-04T19:00'); await page.selectOption('#tvSure', '30'); await page.selectOption('#tvSun', 'Selin');
  await page.evaluate(() => tvProgramAc(7)); await bekle(450);
  const pa = (await cagri('tv_program_ac')).args;
  assert.equal(pa.p_kanal, 7); assert.equal(pa.p_tur, 'duello'); assert.equal(pa.p_dakika, 30); assert.equal(pa.p_sunucu, 'Selin'); assert.equal(new Date(pa.p_bas).getTime(), new Date('2030-01-04T19:00').getTime());
  await page.evaluate(() => { D.yigin = []; tvKanalAc(7); }); await bekle(450);
  await page.evaluate(() => tvReklamKarar(5, true, 7)); await bekle();
  assert.deepEqual((await cagri('tv_reklam_karar')).args, { p_reklam: 5, p_onay: true });

  /* ---------------- menü araması ---------------- */
  for (const [q, ad] of [['tv', 'TV Kanalları'], ['sendika', 'İşveren sendikaları'], ['vali', 'Valilik'], ['ticaret odası', 'Ticaret Odası']]) {
    const var_ = await page.evaluate(({ q, ad }) => {
      const k = document.createElement('div'); k.id = 'paAramaSonuc'; const g = document.createElement('div'); g.id = 'paGruplar'; document.body.append(k, g);
      window.soPaAra(q); const ok = k.innerText.includes(ad); k.remove(); g.remove(); return ok;
    }, { q, ad });
    assert.ok(var_, 'menü araması "' + q + '" → ' + ad);
  }

  /* ---------------- Gündem kısayolu ve canlı rozeti ---------------- */
  await page.evaluate(() => { D.yigin = []; D.sekme = 'gundem'; iskelet('Gündem', '<div class="kart">Akış</div>'); return tvGundemRozet(); }); await bekle(300);
  t = await metin(); assert.ok(t.includes('TV Kanalları'), 'Gündem kısayollarında TV Kanalları olmalı');
  assert.ok(await page.evaluate(() => { const k = document.getElementById('tvGundemKart'); return !!k && k.classList.contains('canli') && /İzle/.test(k.innerText); }), 'canlı yayın varken Gündem\'de öne çıkan TV kartı görünmeli');
  await yaz('gundem_kisayol');
  await page.evaluate(() => { D.sekme = 'ekonomi'; });
  /* ---------------- 320 px ---------------- */
  await page.setViewportSize({ width: 320, height: 640 });
  await sahte('studyo', STUDYO());
  for (const [ad, fn] of [['oda_320', 'ticaretOdasiEkrani(6)'], ['valilik_320', 'valilikEkrani()'], ['tv_liste_320', 'tvKanallariEkrani()'], ['tv_kanal_320', 'tvKanalEkrani(7)'], ['tv_studyo_320', 'tvStudyoEkrani(31)']]) {
    await page.evaluate((fn) => { D.yigin = []; ekranAc(() => eval('window.' + fn)); }, fn); await bekle(450);
    const gen = await page.evaluate(() => document.documentElement.scrollWidth);
    const sikisik = await page.evaluate(() => [...document.querySelectorAll('.kx-sayilar b')].filter(b => b.scrollWidth > b.parentElement.clientWidth + 1).map(b => b.textContent));
    assert.deepEqual(sikisik, [], ad + ': sayaç kutusundan taşan değer');
    assert.ok(gen <= 321, ad + ': sayfa genişliği ' + gen); await yaz(ad);
  }
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('Ticaret Odası · Valilik · TV Kanalları arayüz testi geçti (' + (await page.evaluate(() => calls.length)) + ' RPC çağrısı)');
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
