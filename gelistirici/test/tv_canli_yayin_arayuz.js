// TV 2.0 canlı yayın arayüz testi (sunucu 209). Ağ yok; sahte RPC; dist/ sunulur (önce node build/derle.js).
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/tv_canli_yayin_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();
const SN = (s) => new Date(Date.now() + s * 1000).toISOString();
const K = (kad, unvan) => ({ kad, unvan: unvan || null });

const P = (o) => Object.assign({ id: 70, kanal_id: 2, kanal: 'Başkent TV', tur: 'yarisma', tur_ad: 'Bilgi yarışması', baslik: 'Kim Bilir? Siyaset Bilgi Yarışması', aciklama: 'Her doğru cevap puan, ilk üçe ödül',
  bas: S(-0.2), bit: S(0.5), acik_uclu: false, durum: 'canli', sunucu: 'Selin', konuklar: [], izleyici: 128, reklam: 1, zirve: 140, odul: 50000 }, o || {});
const LISTE = { simdi: S(0), kur_ucret: 250000, kanalim: null, sunuculuk: [], sunucu_teklif: [], davetlerim: [],
  canli: [P()], yakinda: [P({ id: 40, tur: 'acik_oturum', tur_ad: 'Açık oturum · Halk soruyor', durum: 'planli', baslik: 'Halk Soruyor: Bütçe', bas: S(30), bit: S(31), izleyici: 0, reklam: 0, odul: 0 })],
  biten: [], kanallar: [{ id: 2, ad: 'Başkent TV', slogan: 'Gerçeğin ekranı', sahip: 'Cumhur', izleyici_ucret: 500, canli: true, program: 9, toplam_izleyici: 612 },
    { id: 4, ad: 'Ege Haber', slogan: null, sahip: 'Kemal', izleyici_ucret: 250, canli: false, program: 2, toplam_izleyici: 51 }] };
const LISTE_EK = { takip: [2], hatirlat: [40], hatirlat_sayi: { 40: 17 },
  kanallar: { 2: { takipci: 88, seviye: { kademe: 3, ad: 'Ulusal kanal', gunluk: 6, toplam: 612, esik: 500, sonraki_esik: 2000, sonraki_ad: 'Ana akım kanal', sonraki_gunluk: 8 } },
    4: { takipci: 3, seviye: { kademe: 1, ad: 'Yerel kanal', gunluk: 4, toplam: 51, esik: 0, sonraki_esik: 100, sonraki_ad: 'Bölgesel kanal', sonraki_gunluk: 5 } } } };
const REYTING = { simdi: S(0), program_sayi: 14, izlenme: 940, baz: { cevrimici: 212, aktif: 640 }, gecen_hafta: { hafta: '2026-11-09', ozet: { kanallar: [{ ad: 'Başkent TV', izlenme: 410 }], programlar: [{ baslik: 'Seçim özel', izleyici: 96 }] } },
  programlar: [{ id: 22, baslik: 'Seçim özel', kanal: 'Başkent TV', kanal_id: 2, tur_ad: 'Haber programı', sunucu: 'Selin', izleyici: 96, zirve: 81 }, { id: 23, baslik: 'Ekonomi düellosu', kanal: 'Ege Haber', kanal_id: 4, tur_ad: 'Siyasi düello', sunucu: 'Kemal', izleyici: 54, zirve: 40 }],
  kanallar: [{ id: 2, ad: 'Başkent TV', izlenme: 610, program: 9, takipci: 88, seviye: 'Ulusal kanal' }, { id: 4, ad: 'Ege Haber', izlenme: 330, program: 5, takipci: 3, seviye: 'Yerel kanal' }],
  sunucular: [{ kad: 'Selin', izlenme: 500, program: 6 }], duellocular: [{ kad: 'Ayşe', galibiyet: 3, oy: 120 }], yarismacilar: [{ kad: 'Baran', derece: 4, birincilik: 2, odul: 60000 }] };
const MES = (id, rol, kad, metin, dk, unvan) => ({ id, rol, metin, zaman: S(-dk / 60), kisi: rol === 'reklam' ? null : K(kad, unvan), benim: false });
const DETAY = (o) => Object.assign(P(), { simdi: S(0), rolum: 'izleyici', kanal_sahibi: false, sunucu_kisi: K('Selin'), izleyici_ucret: 500, konuk_liste: [],
  mesajlar: [MES(1, 'sunucu', 'Selin', 'İyi akşamlar! Kim Bilir?\'e hoş geldiniz. İlk sorumuz geliyor.', 6), MES(2, 'sistem', 'Selin', 'Soru 1 · TBMM kaç milletvekilinden oluşur? (30 saniye)', 1)],
  izleyiciler: { anlik: 128, toplam: 160, liste: ['Deniz', 'Kemal', 'Baran'] }, alkis: 12, yuh: 1, tepkim: null, oyum: null, oy_acik: false,
  reklamlar: [{ marka: 'Anadolu Kahve', metin: 'Sohbetin tadı' }], reklamlarim: [] }, o || {});
const ANKET = (o) => Object.assign({ id: 9, tur: 'yarisma', soru: 'TBMM kaç milletvekilinden oluşur?', secenekler: ['450', '550', '600', '650'], acilis: SN(-5), kapanis: SN(25), kapandi: false, no: 1, toplam: 41,
  oylar: null, dogru: null, secimim: null, puanim: null }, o || {});
const CANLI = (o) => Object.assign({ id: 70, durum: 'canli', rolum: 'izleyici', simdi: S(0), yonetici: false, kanal_sahibi: false, konuk_imza: '', reklam_n: 1, oy_acik: false,
  izleyici: { anlik: 128, toplam: 160, zirve: 140 }, reyting: 20, pay: 60, cevrimici: 212, alkis: 12, yuh: 1, tepkim: null,
  emoji: { alkis: 40, ates: 12, kalp: 3 }, emoji_son: { ates: 4 }, isi: 30, mesajlar: [],
  yorumlar: [{ id: 1, kad: 'Baran', metin: 'Bu soru kolay!', zaman: S(-0.01), soru: false, ekranda: false, benim: false }, { id: 2, kad: 'Elif', metin: 'Ödül ne zaman dağıtılıyor?', zaman: S(-0.005), soru: true, ekranda: false, benim: false }],
  yorum_sayi: 2, sorular: [{ id: 2, kad: 'Elif', metin: 'Ödül ne zaman dağıtılıyor?', destek: 6, benim: false, destekledim: false }], ekranda: null,
  anket: ANKET(), yarisma: { odul: 50000, soru_sayisi: 1, tablo: [{ kad: 'Baran', puan: 380, ben: false }, { kad: 'Deniz', puan: 200, ben: true }], puanim: 200, kazananlar: [] },
  reklam_arasi: null, reklam_arasi_hazir: true, soz: { istedim: false, sayi: 2, kuyruk: null }, konuk_oy: null, oyum: null, takip: true, takipci: 88, hatirlat: false,
  diger: [{ id: 70, baslik: 'Kim Bilir?', kanal: 'Başkent TV' }, { id: 31, baslik: 'Ekonomi düellosu', kanal: 'Ege Haber' }] }, o || {});
const KANAL = { id: 4, ad: 'Ege Haber', slogan: 'Ege’nin sesi', sahip: K('Kemal'), kurulus: S(-400), izleyici_ucret: 250, reklam_vergisi: 10, benim: false, yayinciyim: false, simdi: S(0), kasa: null,
  sunucular: [], programlar: [], gecmis: [], bekleyen_reklam: [], hareketler: [] };
const KANAL_EK = { takip: false, takipci: 3, seviye: LISTE_EK.kanallar[4].seviye, hafta_izlenme: 51, hafta_sira: 2, rekor: { baslik: 'Ekonomi düellosu', izleyici: 54, zirve: 40 } };

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
  await page.waitForFunction(() => window.SO_TV_KANALLARI_V1 && typeof iskelet === 'function');
  await page.evaluate((v) => {
    window.calls = []; window.SAHTE = v;
    API = { rpc: async (ad, args) => {
      calls.push({ ad, args });
      const s = window.SAHTE, kop = x => JSON.parse(JSON.stringify(x));
      if (ad === 'tv_canli') { const c = kop(s.canli); c.mesajlar = (c.mesajlar || []).filter(m => m.id > (args.p_mesaj || 0)); c.yorumlar = (c.yorumlar || []).filter(y => y.id > (args.p_yorum || 0)); return c; }
      if (ad === 'tv_anket_oyla') { s.canli.anket.secimim = args.p_secim; return { tamam: true, secim: args.p_secim }; }
      if (ad === 'tv_emoji') { s.canli.emoji[args.p_tur] = (s.canli.emoji[args.p_tur] || 0) + 1; return { tamam: true }; }
      if (ad === 'tv_yorum_yaz') { s.canli.yorumlar.push({ id: 6, kad: 'Deniz', metin: args.p_metin, zaman: new Date().toISOString(), soru: args.p_soru, ekranda: false, benim: true }); s.canli.yorum_sayi = 3; return { tamam: true, id: 6 }; }
      if (ad === 'tv_soz_iste') { s.canli.soz.istedim = args.p_ac; return { tamam: true, istedim: args.p_ac }; }
      const sabit = { tv_liste: s.liste, tv_liste_ek: s.listeEk, tv_reyting: s.reyting, tv_detay: s.detay, tv_kanal_detay: s.kanal, tv_kanal_ek: s.kanalEk,
        tv_takip: { takip: true, takipci: 4 }, tv_hatirlat: { hatirlat: true, sayi: 18 }, tv_anket_ac: { tamam: true, id: 10 }, tv_yorum_ekrana: { tamam: true }, tv_soz_ver: s.detay,
        tv_reklam_arasi: { tamam: true }, tv_yorum_destek: { tamam: true, destek: 7 }, tv_odul_koy: { tamam: true, odul: 60000 }, tv_canli_ozet: { canli: 1 } };
      if (ad in sabit) return kop(sabit[ad]);
      throw new Error('sahte: ' + ad);
    } };
    window.onayla = async () => true;
    D.durum = { profil: { il_id: 6, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 840000 } } }; D.sekme = 'gundem'; D.yigin = [];
    window.TIK = setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
  }, { liste: LISTE, listeEk: LISTE_EK, reyting: REYTING, detay: DETAY(), canli: CANLI(), kanal: KANAL, kanalEk: KANAL_EK });
  const bekle = (ms) => page.waitForTimeout(ms || 350);
  const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
  const tumMetin = () => page.evaluate(() => document.querySelector('#app').textContent.replace(/\s+/g, ' '));
  const sahte = (k, v) => page.evaluate(({ k, v }) => { window.SAHTE[k] = v; }, { k, v });
  const cagri = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);
  let no = 0;
  const yaz = async (ad) => {
    const tas = await page.evaluate(() => { const ic = document.querySelector('#icerik'); return ic ? ic.scrollWidth - ic.clientWidth : 0; });
    assert.ok(tas <= 1, ad + ': yatay taşma ' + tas + ' px');
    if (!shot) return; fs.mkdirSync(shot, { recursive: true });
    await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '.png'), fullPage: true });
  };
  const parca = async (sel, ad) => { if (!shot) return; const el = page.locator(sel).first(); if (await el.count()) await el.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '.png') }); };
  let t;
  const icerir = (a, b) => a.toLocaleUpperCase('tr-TR').includes(b.toLocaleUpperCase('tr-TR'));

  /* ---- ana ekran: takip şeridi, hatırlatma, seviye, reyting ---- */
  await page.evaluate(() => { D.yigin = []; ekranAc(tvKanallariEkrani); }); await bekle(450);
  t = await tumMetin(); for (const b of ['Takip ettiklerin', 'Hatırlatma kurulu', '17 kişi bekliyor', 'Ödül 50.000 ₺', 'Ulusal kanal', '88 takipçi', 'Takip ediyorsun', 'Reyting']) assert.ok(icerir(t, b), 'ana ekran: ' + b);
  await yaz('tv2_ana');
  await page.click('[data-kx="tv"] button[data-k="reyting"]'); await bekle(400);
  assert.ok(await cagri('tv_reyting'), 'reyting sekmesi tv_reyting çağırmalı');
  t = await metin(); for (const b of ['Haftanın reytingleri', 'Geçen haftanın birincisi: Başkent TV', 'Seçim özel', 'Kanal sıralaması', 'Düello şampiyonları', 'Yarışma şampiyonları']) assert.ok(icerir(t, b), 'reyting: ' + b);
  await yaz('tv2_reyting'); await parca('#tvReytingK', 'tv2_reyting_tablo');

  /* ---- izleyici stüdyosu: TV çerçevesi + yarışma sorusu ---- */
  await page.evaluate(() => { D.yigin = []; tvStudyoAc(70); }); await bekle(500);
  t = await metin();
  for (const b of ['Başkent TV', 'Takipte', 'Rtg %20 · Pay %60', 'Yarışma · Soru 1', 'TBMM kaç milletvekilinden oluşur?', '50.000 ₺', 'Yarışma tablosu', 'Baran', 'Salon ısısı', 'SEYİRCİ']) assert.ok(icerir(t, b), 'stüdyo: ' + b);
  assert.equal(await page.locator('#tvSahne .tvx-opt').count(), 4, 'dört seçenek ekranda');
  assert.equal(await page.locator('#tvEmojiK [data-emo]').count(), 6, 'altı emoji');
  assert.equal(await page.locator('.tvx-kum').count(), 2, 'kumanda: önceki / sonraki canlı yayın');
  assert.match(await page.evaluate(() => document.querySelector('#tvKayanI').innerText), /Baran.*Bu soru kolay/);
  assert.equal(await page.locator('#tvYaz').count(), 0, 'izleyici stüdyoya yazamaz');
  await yaz('tv2_studyo_yarisma');
  await page.click('#tvSahne .tvx-opt:nth-child(3)'); await bekle(400);
  assert.deepEqual((await cagri('tv_anket_oyla')).args, { p_anket: 9, p_secim: 2 });
  assert.match(await page.evaluate(() => document.querySelector('#tvSahne').innerText), /kilitlendi/);
  assert.equal(await page.locator('#tvSahne .tvx-opt:disabled').count(), 4, 'kilitli cevap: seçenekler kapalı');
  await page.click('#tvEmojiK [data-emo="ates"]'); await bekle(250);
  assert.equal((await cagri('tv_emoji')).args.p_tur, 'ates');
  assert.ok(await page.locator('#tvUcan .tvx-u').count() >= 1, 'dokunulan emoji ekranda uçmalı');
  // başkalarının tepkileri ve yeni seyirci yorumu tazelemede gelir; soru kapanır, doğru cevap açıklanır
  await page.evaluate(() => { clearInterval(window.TIK); SO_KESINTISIZ.eylem = 0; SO_KESINTISIZ.dokunus = 0; if (document.activeElement) document.activeElement.blur(); });
  await page.evaluate(() => { const c = window.SAHTE.canli; c.emoji.kalp = 15; c.yorumlar.push({ id: 5, kad: 'Sude', metin: 'Ankara’dan selamlar!', zaman: new Date().toISOString(), soru: false, ekranda: false, benim: false });
    c.anket = Object.assign(c.anket, { kapandi: true, kapanis: new Date().toISOString(), dogru: 2, oylar: [3, 6, 30, 2], puanim: 186 }); return window._tvTaz(); }); await bekle(400);
  assert.ok(await page.locator('#tvUcan .tvx-u').count() >= 3, 'başkalarının kalpleri uçmalı');
  assert.match(await page.evaluate(() => document.querySelector('#tvKayanI').innerText), /Sude.*selamlar/);
  t = await page.evaluate(() => document.querySelector('#tvSahne').innerText); assert.match(t, /Doğru!/); assert.match(t, /186 puan/);
  assert.equal(await page.locator('#tvSahne .tvx-opt.dogru').count(), 1);
  await yaz('tv2_studyo_dogru');
  await page.evaluate(() => { window.TIK = setInterval(() => { SO_KESINTISIZ.eylem = Date.now(); }, 50); });
  // seyirci kürsüsü: yorum / soru / söz iste
  await page.click('[data-kx="tvs70"] button[data-k="seyirci"]'); await bekle(200);
  t = await metin(); for (const b of ['Öne çıkan sorular', 'Ödül ne zaman dağıtılıyor?', 'Ben de soruyorum · 6', 'Söz iste · canlı bağlan', 'Seyirci kürsüsü']) assert.ok(icerir(t, b), 'seyirci: ' + b);
  await page.fill('#tvYorum', 'Sunucuya selamlar, harika yarışma!'); await page.evaluate(() => tvYorumYaz(70)); await bekle(400);
  assert.deepEqual((await cagri('tv_yorum_yaz')).args, { p_program: 70, p_metin: 'Sunucuya selamlar, harika yarışma!', p_soru: false });
  assert.match(await page.evaluate(() => document.querySelector('#tvYorumAkis').innerText), /harika yarışma/);
  await page.evaluate(() => tvSozIste(70, true)); await bekle(400);
  assert.deepEqual((await cagri('tv_soz_iste')).args, { p_program: 70, p_ac: true });
  assert.match(await metin(), /Söz isteğini geri çek/);
  await yaz('tv2_seyirci'); await parca('#tvSeyirciK', 'tv2_seyirci_kursusu');
  await page.evaluate(() => tvZap(31)); await bekle(300);
  assert.equal((await cagri('tv_detay')).args.p_program, 31, 'kumanda başka canlı yayına geçmeli');

  /* ---- reji masası (sunucu): söz kuyruğu, seyirci sorusu, soru bankası ---- */
  await sahte('detay', DETAY({ rolum: 'sunucu', sunucu_kisi: K('Deniz'), sunucu: 'Deniz', konuk_liste: [Object.assign(K('Ayşe', 'İzmir Milletvekili'), { durum: 'kabul', oy: 0 })] }));
  await sahte('canli', CANLI({ rolum: 'sunucu', yonetici: true, konuk_imza: 'Ayşe:kabul', anket: null, soz: { istedim: false, sayi: 1, kuyruk: [Object.assign(K('Baran'), { zaman: S(-0.01) })] } }));
  await page.evaluate(() => { D.yigin = []; tvStudyoAc(70); }); await bekle(500);
  t = await metin(); for (const b of ['Reji masası', 'Yayın yönetimi', 'Stüdyodakiler (1/6)', 'Yayından al', 'Baran', 'Yayına al', 'Ekrana al', 'Reklam arası ver (40 sn)', 'Yarışma sorusu sor', 'Soru bankasından getir', 'Ödül havuzu']) assert.ok(icerir(t, b), 'reji: ' + b);
  assert.equal(await page.locator('#tvEmojiK [data-emo]').count(), 0, 'sunucu emoji vermez ama salon ısısını görür');
  assert.match(await metin(), /Salon ısısı/);
  await page.evaluate(() => tvSoruBankasi()); await bekle(100);
  const banka = await page.evaluate(() => ({ soru: document.getElementById('tvASoru').value, sec: [0, 1, 2, 3].map(j => document.getElementById('tvASec' + j).value), d: Number(document.querySelector('input[name="tvADogru"]:checked').value) }));
  assert.ok(banka.soru.length > 5 && banka.sec.every(x => x), 'soru bankası formu doldurmalı');
  await page.evaluate(() => tvAnketAc(70)); await bekle(400);
  const aa = (await cagri('tv_anket_ac')).args;
  assert.equal(aa.p_secenekler.length, 4); assert.equal(aa.p_secenekler[aa.p_dogru], banka.sec[banka.d], 'işaretli doğru cevap gönderilmeli'); assert.equal(aa.p_saniye, 30);
  await page.evaluate(() => tvSozVer(70, 'Baran')); await bekle(400);
  assert.deepEqual((await cagri('tv_soz_ver')).args, { p_program: 70, p_kad: 'Baran' });
  await page.evaluate(() => tvYorumEkrana(2)); await bekle(300);
  assert.deepEqual((await cagri('tv_yorum_ekrana')).args, { p_yorum: 2 });
  await yaz('tv2_reji'); await parca('#tvReji', 'tv2_reji_masasi');

  /* ---- reklam arası, ekrandaki izleyici sorusu, bitti ---- */
  await sahte('detay', DETAY({ tur: 'acik_oturum', tur_ad: 'Açık oturum · Halk soruyor' }));
  await sahte('canli', CANLI({ anket: null, yarisma: null, reklam_arasi: { bitis: SN(30), reklamlar: [{ marka: 'Anadolu Kahve', metin: 'Sohbetin tadı' }, { marka: 'Ege Lojistik', metin: 'Yükünüz emin ellerde' }] } }));
  await page.evaluate(() => { D.yigin = []; tvStudyoAc(70); }); await bekle(500);
  assert.match(await page.evaluate(() => document.querySelector('#tvSahne').innerText), /REKLAM ARASI/);
  await yaz('tv2_reklam_arasi');
  await sahte('canli', CANLI({ anket: null, yarisma: null, ekranda: { id: 2, kad: 'Elif', metin: 'Ödül ne zaman dağıtılıyor?', soru: true, zaman: new Date().toISOString() } }));
  await page.evaluate(() => window._tvTaz()); await bekle(300);
  assert.ok(icerir(await page.evaluate(() => document.querySelector('#tvSahne').innerText), 'İzleyici sorusu'));
  await yaz('tv2_izleyici_sorusu');
  await sahte('detay', DETAY({ durum: 'bitti', bit: S(-0.1), izleyiciler: { anlik: 0, toplam: 210, liste: [] } }));
  await sahte('canli', CANLI({ durum: 'bitti', anket: null, izleyici: { anlik: 0, toplam: 210, zirve: 162 }, reyting: 25.3, pay: null,
    yarisma: { odul: 50000, soru_sayisi: 12, tablo: [], puanim: 980, kazananlar: [{ kad: 'Baran', sira: 1, puan: 1540, tutar: 25000 }, { kad: 'Deniz', sira: 2, puan: 980, tutar: 15000 }] } }));
  await page.evaluate(() => { D.yigin = []; tvStudyoAc(70); }); await bekle(500);
  t = await metin(); for (const b of ['Yayın sona erdi', 'Yarışmanın birincisi Baran', '210', '162', 'Kazananlar', '25.000 ₺']) assert.ok(icerir(t, b), 'bitti: ' + b);
  await yaz('tv2_bitti');

  /* ---- planlı program: hatırlat; kanal: seviye + takip ---- */
  await sahte('detay', DETAY({ id: 40, durum: 'planli', bas: S(2), bit: S(3), tur: 'acik_oturum', tur_ad: 'Açık oturum · Halk soruyor', baslik: 'Halk Soruyor: Bütçe', mesajlar: [] }));
  await sahte('canli', CANLI({ id: 40, durum: 'planli', anket: null, yarisma: null, hatirlat: false, yorumlar: [], sorular: [] }));
  await page.evaluate(() => { D.yigin = []; tvStudyoAc(40); }); await bekle(500);
  assert.match(await metin(), /Hatırlat · başlayınca haber ver/);
  await page.evaluate(() => tvHatirlat(40, true)); await bekle(300);
  assert.deepEqual((await cagri('tv_hatirlat')).args, { p_program: 40, p_ac: true });
  await yaz('tv2_planli');
  await page.evaluate(() => { D.yigin = []; tvKanalAc(4); }); await bekle(450);
  t = await metin(); for (const b of ['Yerel kanal', '3 takipçi', 'bu hafta 2. sırada', 'Takip et', '51 / 100 izlenme', 'Bölgesel kanal olunca günde 5 program']) assert.ok(icerir(t, b), 'kanal: ' + b);
  await yaz('tv2_kanal');
  await page.evaluate(() => tvTakip(4, true, 'kanal')); await bekle(350);
  assert.deepEqual((await cagri('tv_takip')).args, { p_kanal: 4, p_ac: true });

  /* ---- 320 px ---- */
  await page.setViewportSize({ width: 320, height: 640 });
  await sahte('detay', DETAY()); await sahte('canli', CANLI());
  for (const [ad, fn] of [['tv2_ana_320', 'tvKanallariEkrani()'], ['tv2_studyo_320', 'tvStudyoEkrani(70)']]) {
    await page.evaluate((fn) => { D.yigin = []; ekranAc(() => eval('window.' + fn)); }, fn); await bekle(450);
    const gen = await page.evaluate(() => document.documentElement.scrollWidth);
    assert.ok(gen <= 321, ad + ': sayfa genişliği ' + gen); await yaz(ad);
  }
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('TV 2.0 canlı yayın arayüz testi geçti (' + (await page.evaluate(() => calls.length)) + ' RPC çağrısı)');
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
