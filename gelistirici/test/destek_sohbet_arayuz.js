// Yardım ve destek sohbeti arayüz testi (sahte RPC; 390 ve 320 px) — 26.11.2026
// Yönetime Yaz: talep listesi (görevli adı / "Görevli atanıyor"), talep sohbeti (balonlar, görevli kutusu, gönder),
// eski sunucu (gorevli_ad yok) geri dönüşü; Sohbet listesinde Yardım Masası kapalıyken "Yardım ve destek" satırı ve
// Mod sekmesinin üst düzey 'gorevli' ile açılması; yardimMasasiAc yönlendirmesi; Talep kutusu: Sana atandı, Üstlen, Yanıtsız kapat.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/destek_sohbet_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
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
    await page.waitForFunction(() => typeof window.yonetimeYazEkrani === 'function' && window.sohbetTasarim && typeof window.mmKutu === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = []; window.ESKI = false;
      const z = (dk) => new Date(Date.now() - dk * 60000).toISOString();
      const uzun = 'Bankadan para çekemiyorum, işlem sürekli beklemede kalıyor ve ekranda hiçbir hata yazmıyor; dün akşamdan beri böyle. ';
      window.T = [
        { id: 41, konu: 'hata', konu_ad: 'Hata bildirimi', durum: 'yanitlandi', okundu: false, zaman: z(90), son_hareket: z(10), hedef: null, metin: uzun, gorevli_ad: 'Oyun Yöneticisi G-07',
          mesajlar: [{ id: 1, gorevli: false, yazan: 'oyuncu', metin: uzun, zaman: z(90) }, { id: 2, gorevli: true, yazan: 'Oyun Yöneticisi G-07', metin: 'Merhaba, hesabına bakıyorum. Hangi bankada oluyor?', zaman: z(10) }] },
        { id: 42, konu: 'sikayet', konu_ad: 'Oyuncu şikâyeti', durum: 'yeni', okundu: true, zaman: z(3), son_hareket: z(3), hedef: 'gürültücü', metin: 'Genel sohbette bana sürekli hakaret ediyor.', gorevli_ad: null,
          mesajlar: [{ id: 3, gorevli: false, yazan: 'oyuncu', metin: 'Genel sohbette bana sürekli hakaret ediyor.', zaman: z(3) }] },
        { id: 30, konu: 'oneri', konu_ad: 'Öneri', durum: 'kapali', okundu: true, zaman: z(3000), son_hareket: z(2000), hedef: null, metin: 'Eski öneri', gorevli_ad: 'Oyun Yöneticisi G-02',
          mesajlar: [{ id: 4, gorevli: false, yazan: 'oyuncu', metin: 'Eski öneri', zaman: z(3000) }, { id: 5, gorevli: true, yazan: 'Oyun Yöneticisi G-02', metin: 'Teşekkürler, ekibe ilettik.', zaman: z(2000) }] }];
      const bilgi = () => ({ konular: [{ kod: 'hata', ad: 'Hata bildirimi', aciklama: 'Oyunda bir şey çalışmıyor.' }, { kod: 'sikayet', ad: 'Oyuncu şikâyeti', aciklama: 'Küfür, hakaret.' }], acik: 2, okunmamis: 1,
        talepler: JSON.parse(JSON.stringify(T)).map(t => { if (ESKI) delete t.gorevli_ad; return t; }) });
      window.KUTU = () => ({ yonetici: false, bana_atanan: 1, masalar: [{ kod: 'oyuncu', ad: 'Oyuncu Masası' }, { kod: 'icerik', ad: 'İçerik Masası' }], talepler: [
        { id: 42, kad: 'yeniOyuncu', konu: 'sikayet', konu_ad: 'Oyuncu şikâyeti', masa: 'oyuncu', masa_ad: 'Oyuncu Masası', durum: 'yeni', zaman: z(3), son_hareket: z(3), hedef: 'gürültücü', onceki: 0, atanan_kod: 'G-07', bana_atandi: true,
          mesajlar: [{ gorevli: false, yazan: 'oyuncu', metin: 'Genel sohbette bana sürekli hakaret ediyor.', zaman: z(3) }] },
        { id: 43, kad: 'baskaOyuncu', konu: 'hata', konu_ad: 'Hata bildirimi', masa: 'oyuncu', masa_ad: 'Oyuncu Masası', durum: 'yeni', zaman: z(40), son_hareket: z(40), onceki: 2, atanan_kod: 'G-03', bana_atandi: false,
          mesajlar: [{ gorevli: false, yazan: 'oyuncu', metin: 'Seçim ekranı açılmıyor.', zaman: z(40) }] },
        { id: 44, kad: 'ucuncu', konu: 'hata', konu_ad: 'Hata bildirimi', masa: 'oyuncu', masa_ad: 'Oyuncu Masası', durum: 'yeni', zaman: z(5), son_hareket: z(5), onceki: 0, atanan_kod: null, bana_atandi: false,
          mesajlar: [{ gorevli: false, yazan: 'oyuncu', metin: 'Para gitti.', zaman: z(5) }] }] });
      window.OZ = { gorevli: true, yardim: null, cevrimici: 72, kanallar: [{ kanal: 'genel', baslik: 'Türkiye Meydanı', yazabilir: true, okunmamis: 0, son: null, cevrimici: 72 }, { kanal: 'il', baslik: 'Muğla Kahvesi', yazabilir: true, okunmamis: 0, son: null }], toplam_okunmamis: 0, grup_sinir: {} };
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'yonetime_yaz_bilgi') return bilgi();
        if (ad === 'yonetime_yaz_yanit') { const t = T.find(x => x.id === a.p_id); t.mesajlar.push({ id: 99, gorevli: false, yazan: 'oyuncu', metin: a.p_metin, zaman: new Date().toISOString() }); t.durum = 'yeni'; return bilgi(); }
        if (ad === 'yonetime_yaz_okundu') return { tamam: true };
        if (ad === 'sohbet_ozet') return OZ;
        if (ad === 'ozel_liste') return [];
        if (ad === 'mod_sohbet_sekme') return { nobet: true, tum: false };
        if (ad === 'mod_kutu' || ad === 'mod_kutu_ustlen' || ad === 'mod_kutu_yanitla') return KUTU();
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: new Date().toISOString(), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return null;
      } };
      D.durum = { profil: { id: 'x', il_id: 48, kad: 'Deniz', makamlar: [], cuzdan: { para: 1000, dolu: false }, yetkiler: { liste: [], moderator: true } }, takvim: [], simdi: new Date().toISOString(), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); } };
    const tasma = () => page.evaluate(() => { const w = document.documentElement.clientWidth;
      return { sayfa: document.documentElement.scrollWidth, ekran: w, tasan: [...document.querySelectorAll('#icerik *')].filter(x => { const r = x.getBoundingClientRect(); return r.width > 0 && r.right > w + 1; }).slice(0, 3).map(x => x.className || x.tagName) }; });
    const son = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);
    const metin = (sel) => page.evaluate((s) => { const el = document.querySelector(s); return el ? el.textContent.replace(/\s+/g, ' ') : null; }, sel);

    // 1) Talep listesi
    await page.evaluate(() => ekranAc(yonetimeYazEkrani)); await page.waitForTimeout(700);
    const satirlar = await page.evaluate(() => [...document.querySelectorAll('.yy-satir')].map(b => ({ m: b.innerText.replace(/\s+/g, ' '), h: Math.round(b.getBoundingClientRect().height) })));
    assert.equal(satirlar.length, 3, et('3 talep satırı'));
    assert.ok(/Görevli: Oyun Yöneticisi G-07/.test(satirlar[0].m), et('görevli adı: ' + satirlar[0].m));
    assert.ok(/Görevli atanıyor/.test(satirlar[1].m), et('atanıyor: ' + satirlar[1].m));
    assert.ok(!/Görevli:/.test(satirlar[2].m.replace(/Görevli: Teşekkürler.*/, '')), et('kapalı talepte görevli satırı yok'));
    assert.ok(satirlar.every(s => s.h >= 48), et('dokunma alanı'));
    assert.ok(await page.$('#yyYeni'), et('yeni talep düğmesi'));
    let t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan.length === 0, et('liste taşma: ' + JSON.stringify(t)));
    await cek('liste');

    // 2) Yeni talep formu açılır / kapanır
    await page.click('#yyYeni'); await page.waitForTimeout(250);
    assert.ok(await page.$('#yyMetin') && await page.$('#yyGonder'), et('form açıldı'));
    const fs16 = await page.evaluate(() => parseFloat(getComputedStyle(document.getElementById('yyMetin')).fontSize));
    assert.ok(fs16 >= 16, et('girdi yazısı 16 px'));
    await cek('form');
    await page.click('#yyVazgec'); await page.waitForTimeout(250);
    assert.ok(!(await page.$('#yyMetin')), et('form kapandı'));

    // 3) Talep sohbeti
    await page.click('.yy-satir[data-ac="41"]'); await page.waitForTimeout(600);
    assert.ok(await page.$('#yySohbet[data-id="41"]'), et('sohbet ekranı'));
    const gk = await metin('#yyGorevli'); assert.ok(/Oyun Yöneticisi G-07/.test(gk), et('görevli kutusu: ' + gk));
    const bal = await page.evaluate(() => ({ ben: document.querySelectorAll('.yy-balon.ben').length, g: document.querySelectorAll('.yy-balon.g').length,
      benSag: (() => { const b = document.querySelector('.yy-balon.ben').getBoundingClientRect(); return b.right > window.innerWidth / 2; })() }));
    assert.deepEqual([bal.ben, bal.g], [1, 1], et('balonlar'));
    assert.ok(bal.benSag, et('oyuncu balonu sağda'));
    assert.ok((await son('yonetime_yaz_okundu')), et('okundu işaretlendi'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan.length === 0, et('sohbet taşma: ' + JSON.stringify(t)));
    await cek('sohbet');
    await page.fill('#yyY', 'Ziraat Bankası’nda oluyor, ekran görüntüsü de var.');
    await page.click('#yyYGonder'); await page.waitForTimeout(400);
    assert.deepEqual((await son('yonetime_yaz_yanit')).a, { p_id: 41, p_metin: 'Ziraat Bankası’nda oluyor, ekran görüntüsü de var.' });
    assert.equal(await page.evaluate(() => document.querySelectorAll('.yy-balon.ben').length), 2, et('yeni balon eklendi'));
    assert.equal(await page.evaluate(() => document.getElementById('yyY').value), '', et('kutu temizlendi'));
    assert.ok(/Yanıt bekliyor/.test(await metin('#yyDurum')), et('durum güncellendi'));
    await cek('gonderildi');

    // 4) Görevlisi atanmamış talep ve kapalı talep
    await page.evaluate(() => yonetimeYazTalep(42)); await page.waitForTimeout(500);
    assert.ok(/Görevli atanıyor/.test(await metin('#yyGorevli')), et('atanıyor kutusu'));
    await page.evaluate(() => yonetimeYazTalep(30)); await page.waitForTimeout(500);
    assert.ok(/kapatıldı/.test(await metin('#yyGorevli')) && !(await page.$('#yyY')), et('kapalı talepte yazma alanı yok'));

    // 5) Eski sunucu (gorevli_ad alanı yok)
    await page.evaluate(() => { ESKI = true; ekranAc(yonetimeYazEkrani); }); await page.waitForTimeout(600);
    const eski = await page.evaluate(() => [...document.querySelectorAll('.yy-satir')].map(b => b.innerText));
    assert.ok(eski.length === 3 && eski.every(m => !/atanıyor/.test(m)), et('eski sunucuda görevli satırı yok'));
    await page.evaluate(() => { ESKI = false; });

    // 6) Sohbet listesi: Yardım Masası kapalı → "Yardım ve destek" satırı + Mod sekmesi
    await page.evaluate(() => ekranAc(sohbetTasarim.ana)); await page.waitForTimeout(400);
    await page.evaluate(() => { const b = document.querySelector('[data-sh="seg"][data-v="kanal"]'); if (b) b.click(); }); await page.waitForTimeout(700);
    assert.ok(await page.$('[data-sh="destek"]'), et('Yardım ve destek satırı'));
    assert.ok(await page.$('[data-sh="modNobet"]'), et('Mod sekmesi (üst düzey gorevli)'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1, et('sohbet listesi taşma'));
    await cek('sohbet_listesi');
    await page.click('[data-sh="destek"]'); await page.waitForTimeout(600);
    assert.ok(await page.$('.yy-satir'), et('satır Yönetime Yaz açar'));
    // yardimMasasiAc kısayolu da Yönetime Yaz'a gider
    await page.evaluate(() => { ekranAc(() => iskelet('Boş', '<div></div>')); }); await page.waitForTimeout(200);
    await page.evaluate(() => yardimMasasiAc()); await page.waitForTimeout(600);
    assert.ok(await page.$('.yy-satir'), et('yardimMasasiAc → Yönetime Yaz'));

    // 7) Talep kutusu (moderatör)
    await page.evaluate(() => ekranAc(mmKutu)); await page.waitForTimeout(700);
    const kt = await page.evaluate(() => [...document.querySelectorAll('.mm-kart[data-i]')].map(k => ({ m: k.innerText.replace(/\s+/g, ' '), ustlen: !!k.querySelector('[data-ustlen]'), kapat: !!k.querySelector('[data-kapat]') })));
    assert.ok(/Sana atandı/.test(kt[0].m) && !kt[0].ustlen && kt[0].kapat, et('bana atanan: ' + JSON.stringify(kt[0])));
    assert.ok(/Görevli: G-03/.test(kt[1].m) && kt[1].ustlen, et('başkasının talebi: ' + kt[1].m));
    assert.ok(/Henüz görevli atanmadı/.test(kt[2].m) && kt[2].ustlen, et('atanmamış: ' + kt[2].m));
    assert.ok(/1 talep yanıt bekliyor/.test(await metin('#icerik')), et('bana atanan sayısı'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan.length === 0, et('kutu taşma: ' + JSON.stringify(t)));
    await cek('kutu');
    await page.click('.mm-kart[data-i="1"] [data-ustlen]'); await page.waitForTimeout(500);
    assert.deepEqual((await son('mod_kutu_ustlen')).a, { p_id: 43 });
    await page.click('.mm-kart[data-i="0"] [data-kapat]'); await page.waitForTimeout(500);
    assert.deepEqual((await son('mod_kutu_yanitla')).a, { p_id: 42, p_metin: null, p_kapat: true });
    await page.close();
  }
  await browser.close();
  if (hatalar.length) { console.error('Sayfa hataları:\n' + hatalar.join('\n')); process.exit(1); }
  console.log('destek_sohbet_arayuz: tamam (390 ve 320 px)');
})().catch(e => { console.error(e); process.exit(1); });
