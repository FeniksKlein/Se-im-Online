// Kitap dosyası takibi arayüz testi (sahte RPC; 390 ve 320 px) — 26.11.2026
// Kitaplar › Vitrin'de "Dosyalarım" afişi, Dosyalarım sekmesi (aşamalar, ret gerekçesi, geri sayım, metni oku,
// başka yayınevine de gönder, geri çek), yayınevine gelen dosyalar; İş Dünyası › Kitap ve yayınevi ekranında aşama satırı,
// geri çek / başka yayınevine gönder düğmeleri ve gerekçeli ret; eski sunucu (inceleme_saat yok) geri dönüşü; taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/kitap_dosya_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
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
    await page.waitForFunction(() => typeof window.soKitapVitriniAc === 'function' && typeof window.ucEkonomiEkrani === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = []; window.YENI = true;
      const s = (sa) => new Date(Date.now() - sa * 3600e3).toISOString();
      const metin = 'Birinci bölüm. '.repeat(40);
      const kit = (o) => Object.assign({ tur: 'Roman', ozet: 'Bir kasabanın siyasi hikâyesi.', icerik: metin, yazar: 'Soydan Kaya', fiyat: 300, stok: 0, satilan: 0, telif: 15, aldim: false, degisim_saat: 24, yayin: null, karar: null, incelendi: null, ret_kod: null, ret_gerekce: null, son_karar: null, yayinevi_sahip: 'Uygar Zeki' }, o);
      window.PANEL = () => {
        const p = { benim_yayinevleri: [181], yayinevleri: [
          { id: 167, ad: 'Kurt Medya Grubu', kasa: 96155, sahip: 'Kurt', bekleyen: 4, yayinlanan: 6 },
          { id: 169, ad: 'MEÇ Organizasyon', kasa: 1549861, sahip: 'Meç', bekleyen: 1, yayinlanan: 3 },
          { id: 181, ad: 'UYGAR MEDYA', kasa: 651416, sahip: 'Uygar Zeki', bekleyen: 8, yayinlanan: 2 },
          { id: 189, ad: 'YAVUZ MEDYA', kasa: 10000, sahip: 'Yavuz', bekleyen: 1, yayinlanan: 0 }],
          kitaplar: [
          kit({ id: 90, eser: 83, baslik: 'Ortak Masa: Ayrışmadan Konuşabilme Sanatı ve Uzun Bir Alt Başlık', yazar_benim: true, yayinevi: 169, yayinevi_ad: 'MEÇ Organizasyon', durum: 'teklif', gonderim: s(5), incelendi: s(2), son_karar: new Date(Date.now() + 67 * 3600e3).toISOString(), kopya_bekleyen: 2, eser_yayinda: false }),
          kit({ id: 83, eser: 83, baslik: 'Ortak Masa: Ayrışmadan Konuşabilme Sanatı ve Uzun Bir Alt Başlık', yazar_benim: true, yayinevi: 167, yayinevi_ad: 'Kurt Medya Grubu', durum: 'teklif', gonderim: s(30), son_karar: new Date(Date.now() + 42 * 3600e3).toISOString(), kopya_bekleyen: 2, eser_yayinda: false }),
          kit({ id: 70, eser: 70, baslik: 'Sessizliğin Bedeli', yazar_benim: true, yayinevi: 181, yayinevi_ad: 'UYGAR MEDYA', durum: 'reddedildi', gonderim: s(50), incelendi: s(40), karar: s(39), ret_kod: 'ret', ret_gerekce: 'Metin kısa, biraz daha geliştir.', kopya_bekleyen: 0, eser_yayinda: false }),
          kit({ id: 47, eser: 47, baslik: 'Köklerin Sesi', yazar_benim: true, yayinevi: 167, yayinevi_ad: 'Kurt Medya Grubu', durum: 'yayinda', gonderim: s(60), yayin: s(55), karar: s(55), stok: 12, satilan: 30, kopya_bekleyen: 0, eser_yayinda: true }),
          kit({ id: 88, eser: 88, baslik: 'Gelen Dosya Örneği', yazar: 'Ali Veli', yazar_benim: false, yayinevi: 181, yayinevi_ad: 'UYGAR MEDYA', durum: 'teklif', gonderim: s(20), son_karar: new Date(Date.now() + 52 * 3600e3).toISOString() }),
          kit({ id: 12, eser: 12, baslik: 'Başkasının Yayındaki Kitabı', yazar: 'Ayşe', yazar_benim: false, yayinevi: 169, yayinevi_ad: 'MEÇ Organizasyon', durum: 'yayinda', icerik: null, stok: 5, satilan: 9, yayin: s(80) })] };
        if (YENI) p.inceleme_saat = 72;
        else p.kitaplar.forEach(k => { delete k.incelendi; delete k.son_karar; delete k.kopya_bekleyen; delete k.ret_kod; });
        return p;
      };
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'uc_kitap_panel') return PANEL();
        if (ad === 'kitap_rekabet') return { hafta: { no: 48, bit: new Date(Date.now() + 86400e3).toISOString() }, haftalik: [], gecen: [], yayinevleri: [], yazarlar: [], imza: [], duzenlenebilir: [], imzali: [], kurallar: {} };
        if (ad === 'uc_kitap_islem') return { durum: 'teklif' };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: new Date().toISOString(), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 34, kad: 'Soydan Kaya', makamlar: [], cuzdan: { para: 1000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: new Date().toISOString(), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      try { sessionStorage.removeItem('kt_sekme'); } catch (_) {}
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png'), fullPage: false }); } };
    const tasma = async () => page.evaluate(() => [...document.querySelectorAll('#icerik *, #modal *')].filter(el => { const r = el.getBoundingClientRect(); return r.width > 0 && r.right > innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.kt-segment,.kt-raf,.segment'); }).map(el => el.className || el.tagName).slice(0, 5));

    // 1) Vitrin: Dosyalarım afişi
    await page.evaluate(() => soKitapVitriniAc());
    await page.waitForSelector('.kt-dosya-afis');
    const afis = await page.textContent('.kt-dosya-afis');
    assert.match(afis, /1 kitabın incelemede/, et('afiş bekleyen'));
    assert.match(afis, /1 kitabın yeniden gönderilmeyi bekliyor/, et('afiş iade'));
    assert.match(afis, /yayınevine gelen 1 dosya/, et('afiş gelen'));
    await cek('vitrin_afis');

    // 2) Dosyalarım sekmesi
    await page.click('.kt-dosya-afis');
    await page.waitForSelector('.kt-dosya');
    const dosyaSay = await page.$$eval('.kt-dosya', l => l.length);
    assert.equal(dosyaSay, 3, et('3 eser kartı (kopyalar tek kartta)'));
    const ilk = await page.$eval('.kt-dosya', el => el.textContent);
    assert.match(ilk, /2 yayınevinde inceleniyor/, et('ilk kart özet'));
    assert.match(ilk, /Yayınevi dosyanı gördü/, et('görüldü aşaması'));
    assert.match(ilk, /Yayınevinin dosyayı açması bekleniyor/, et('görülmedi aşaması'));
    assert.match(ilk, /Karar bekleniyor/, et('karar aşaması'));
    assert.match(ilk, /En geç/, et('son tarih'));
    assert.match(ilk, /Başka yayınevine de gönder/, et('kopya düğmesi'));
    assert.equal((ilk.match(/Bu yayınevinden geri çek/g) || []).length, 2, et('her bekleyen dosyada geri çek'));
    const tum = await page.textContent('#ktGovde');
    assert.match(tum, /Gerekçe: Metin kısa/, et('ret gerekçesi'));
    assert.match(tum, /Şu an hiçbir yayınevinde değil/, et('reddedilen kitap özeti'));
    assert.match(tum, /Bir yayınevine gönder/, et('reddedilende gönder düğmesi'));
    assert.match(tum, /Vitrinde gör/, et('yayındaki kitap'));
    assert.match(tum, /Yayınevine gelen dosyalar/, et('gelen dosyalar bölümü'));
    assert.match(tum, /Gelen Dosya Örneği/, et('gelen dosya adı'));
    assert.doesNotMatch(tum, /Başkasının Yayındaki Kitabı/, et('başkasının kitabı Dosyalarım\'da yok'));
    assert.deepEqual(await tasma(), [], et('Dosyalarım taşma'));
    await cek('dosyalarim');

    // 3) Kitabımı oku
    await page.click('.kt-dosya .kt-dugmeler button:has-text("Kitabımı oku")');
    await page.waitForSelector('#modal .kt-oku');
    assert.match(await page.textContent('#modal .kt-oku'), /Birinci bölüm/, et('metin okunuyor'));
    await cek('oku');
    await page.evaluate(() => modalKapat());

    // 4) Başka yayınevine de gönder → zaten bekleyen yayınevleri listede yok
    await page.click('.kt-dosya button:has-text("Başka yayınevine de gönder")');
    await page.waitForSelector('#ktDosyaYv');
    const sec = await page.$$eval('#ktDosyaYv option', l => l.map(o => Number(o.value)));
    assert.deepEqual(sec.sort(), [181, 189], et('167 ve 169 listede yok'));
    assert.deepEqual(await tasma(), [], et('gönder penceresi taşma'));
    await cek('kopya_gonder');
    await page.selectOption('#ktDosyaYv', '189');
    await page.click('#ktDosyaGonder');
    await page.waitForFunction(() => calls.some(c => c.ad === 'uc_kitap_islem' && c.a.p_islem === 'kopya_gonder'));
    const kc = await page.evaluate(() => calls.filter(c => c.ad === 'uc_kitap_islem').pop().a);
    assert.equal(kc.p_id, 90, et('kopya en yeni dosyadan')); assert.equal(kc.p_veri.yayinevi, 189, et('kopya hedef'));
    await page.waitForSelector('.kt-dosya');
    assert.equal(await page.$eval('.kt-segment button.aktif', b => b.textContent), 'Dosyalarım', et('işlemden sonra Dosyalarım\'da kalır'));

    // 5) Geri çek
    await page.click('.kt-dosya button:has-text("Bu yayınevinden geri çek")');
    await page.waitForSelector('#modal #evet');
    await page.click('#modal #evet');
    await page.waitForFunction(() => calls.some(c => c.ad === 'uc_kitap_islem' && c.a.p_islem === 'geri_cek'));

    // 6) İş Dünyası › Kitap ve yayınevi
    await page.evaluate(() => ucEkonomiEkrani('kitap'));
    await page.waitForFunction(() => /Kitap yaz, yayımla/.test(document.querySelector('#icerik')?.textContent || ''));
    const ue = await page.textContent('#icerik');
    assert.match(ue, /Yayınevi gördü/, et('İD: aşama'));
    assert.match(ue, /Karar en geç/, et('İD: son tarih'));
    assert.match(ue, /Kitabımı oku/, et('İD: yazar okur'));
    assert.match(ue, /Geri çek/, et('İD: geri çek'));
    assert.match(ue, /Başka yayınevine de gönder/, et('İD: kopya'));
    assert.match(ue, /Yayınevinin gerekçesi: Metin kısa/, et('İD: gerekçe'));
    assert.match(ue, /Karar için son/, et('İD: yayınevine süre'));
    assert.doesNotMatch(ue, /Yayınevini değiştir/, et('İD: eski taşıma düğmesi yeni sunucuda yok'));
    assert.deepEqual(await tasma(), [], et('İD taşma'));
    await cek('is_dunyasi');
    // gerekçeli ret
    await page.click('button:has-text("Reddet")');
    await page.waitForSelector('#ucRejectWhy');
    await page.fill('#ucRejectWhy', 'Kurgu zayıf.');
    await page.click('#ucSubmit');
    await page.waitForFunction(() => calls.some(c => c.ad === 'uc_kitap_islem' && c.a.p_islem === 'reddet'));
    const rc = await page.evaluate(() => calls.filter(c => c.a && c.a.p_islem === 'reddet').pop().a);
    assert.equal(rc.p_id, 88, et('ret doğru dosya')); assert.equal(rc.p_veri.gerekce, 'Kurgu zayıf.', et('ret gerekçe gönderildi'));

    // 7) Eski sunucu: yeni düğmeler gizli, eski taşıma yolu durur
    await page.evaluate(() => { YENI = false; });
    await page.evaluate(() => ucEkonomiEkrani('kitap'));
    await page.waitForFunction(() => /Kitap yaz, yayımla/.test(document.querySelector('#icerik')?.textContent || ''));
    const eski = await page.textContent('#icerik');
    assert.doesNotMatch(eski, /Başka yayınevine de gönder/, et('eski sunucu: kopya yok'));
    assert.match(eski, /Yayınevini değiştir/, et('eski sunucu: değiştir var'));
    await page.evaluate(() => { try { sessionStorage.setItem('kt_sekme', 'dosya'); } catch (_) {} return soKitapVitriniAc(); });
    await page.waitForSelector('.kt-dosya');
    const eskiD = await page.textContent('#ktGovde');
    assert.doesNotMatch(eskiD, /geri çek/i, et('eski sunucu: geri çek yok'));
    assert.match(eskiD, /Kitabımı oku/, et('eski sunucu: okuma var'));
    await cek('eski_sunucu');
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('kitap_dosya_arayuz: tamam');
})().catch(e => { console.error(e); process.exit(1); });
