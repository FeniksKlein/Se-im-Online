// Yayınevi sayfası arayüz testi (sahte RPC; 390 ve 320 px) — 27.11.2026
// Kitaplar › Yayınevleri: yayınevi kartları, yayınevi sayfası (sahip/ortaklar, sayılar, kitaplar, yazarlar), oyuncu kartı, geri, kitap detayından geçiş, eski sunucu, taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/yayinevi_sayfa_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
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
    await page.waitForFunction(() => typeof window.soKitapVitriniAc === 'function' && typeof window.soYayineviAc === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.YENI = true; window.kartlar = [];
      window.oyuncuKart = k => kartlar.push(k);
      const kit = (i, y, yad, yazar, sat) => ({ id: i, baslik: 'Kitap ' + i + (i === 3 ? ' — Çok Uzun Başlıklı Bir Siyaset Tarihi İncelemesi' : ''), tur: 'Roman', ozet: 'Özet', icerik: null, yazar, yazar_benim: false, yayinevi: y, yayinevi_ad: yad, durum: 'yayinda', fiyat: 250, stok: 40, satilan: sat, telif: 15, aldim: false, eser: i });
      const yv = (o) => YENI ? o : { id: o.id, ad: o.ad, sahip: o.sahip, bekleyen: o.bekleyen, yayinlanan: o.yayinlanan };
      API = { rpc: async (ad) => {
        if (ad === 'uc_kitap_panel') return { inceleme_saat: 72, benim_yayinevleri: [], yayinevleri: [
          yv({ id: 1, ad: 'Babıali Yayınları ve Kültür Sanat Organizasyon', sahip: 'EnverTalat', yonetici: 'EnverTalat', il: 'Elazığ', kurulus: '2026-11-26T11:37:04Z', bekleyen: 2, yayinlanan: 3, ortak_sayisi: 3, ortaklar: [{ kad: 'EnverTalat', pay: 52 }, { kad: 'CanUzunKullaniciAdiOlanOrtak', pay: 26.5 }, { kad: 'Asl', pay: 21.5 }] }),
          yv({ id: 2, ad: 'Kurt Medya', sahip: 'kurtx', yonetici: 'kurtx', il: 'Ankara', kurulus: '2026-11-25T05:11:08Z', bekleyen: 0, yayinlanan: 1, ortak_sayisi: 1, ortaklar: [{ kad: 'kurtx', pay: 100 }] }),
          yv({ id: 3, ad: 'Boş Yayınevi', sahip: null, yonetici: 'yeni', il: 'Rize', kurulus: '2026-11-27T05:11:08Z', bekleyen: 0, yayinlanan: 0, ortak_sayisi: 2, ortaklar: [{ kad: 'yeni', pay: 49 }, { kad: 'diger', pay: 49 }] })],
          kitaplar: [kit(1, 1, 'Babıali Yayınları ve Kültür Sanat Organizasyon', 'Asl', 120), kit(2, 1, 'Babıali Yayınları ve Kültür Sanat Organizasyon', 'Asl', 40), kit(3, 1, 'Babıali Yayınları ve Kültür Sanat Organizasyon', 'OsmanliTarihcisiUzunAd', 300), kit(4, 2, 'Kurt Medya', 'kurtx', 9)] };
        if (ad === 'kitap_rekabet') return { hafta: { no: 3, bitis: new Date(Date.now() + 86400e3).toISOString() }, haftalik: [], gecen: [], imza: [], imzali: [], duzenlenebilir: [], yazarlar: [{ kad: 'Asl', kitap: 2, hafta_adet: 10, toplam_adet: 160 }],
          yayinevleri: [{ id: 1, ad: 'Babıali Yayınları ve Kültür Sanat Organizasyon', kitap: 3, hafta_adet: 77, gecen_adet: 0, hafta_ciro: 19250, toplam_adet: 460, imza: 2, benim: false }, { id: 2, ad: 'Kurt Medya', kitap: 1, hafta_adet: 9, gecen_adet: 0, hafta_ciro: 2250, toplam_adet: 9, imza: 0, benim: false }] };
        return {};
      } };
    });
    const tasma = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, gen + ' ' + ad + ' taşma ' + t); if (shot) await page.waitForTimeout(600); if (shot) await page.screenshot({ path: path.join(shot, 'yv_' + gen + '_' + ad + '.png'), fullPage: true }); };
    await page.evaluate(async () => { await soKitapVitriniAc(); soKitapSekme('yayinevi'); });
    let m = await page.evaluate(() => ({ kart: document.querySelectorAll('.kt-yvk').length, yazi: document.getElementById('icerik').innerText }));
    assert.equal(m.kart, 3); assert.match(m.yazi, /3 ortaklı · yöneten EnverTalat/); assert.match(m.yazi, /Sahibi kurtx · Ankara/); assert.match(m.yazi, /3 kitap · 460 satış · 2 dosya bekliyor/);
    await tasma('liste');
    await page.click('.kt-yvk');
    m = await page.evaluate(() => ({ yazi: document.getElementById('icerik').innerText, satir: document.querySelectorAll('.kt-satir').length, kisi: document.querySelectorAll('.kt-kisi').length }));
    assert.match(m.yazi, /Ortakları/); assert.match(m.yazi, /%26,5/); assert.match(m.yazi, /yönetici/); assert.match(m.yazi, /Elazığ · Kuruluş 26 Kasım 2026/);
    assert.match(m.yazi, /Çıkardığı kitaplar/); assert.equal(m.satir, 3); assert.equal(m.kisi, 5); assert.match(m.yazi, /Yazarları/); assert.match(m.yazi, /2 kitap · 160 satış/);
    await tasma('sayfa');
    await page.click('.kt-kisi button');
    assert.deepEqual(await page.evaluate(() => kartlar), ['EnverTalat']);
    await page.click('.kt-yv-geri');
    assert.equal(await page.evaluate(() => document.querySelectorAll('.kt-yvk').length), 3);
    await page.evaluate(() => soYayineviAc(3));
    m = await page.evaluate(() => document.getElementById('icerik').innerText);
    assert.match(m, /henüz kitap yayımlamadı/); assert.match(m, /%49/);
    await tasma('bos');
    // kitap detayından yayınevine geçiş
    await page.evaluate(() => { soKitapSekme('vitrin'); soKitapDetay(4); });
    await page.click('a[onclick*="soYayineviAc(2)"]');
    m = await page.evaluate(() => document.getElementById('icerik').innerText);
    assert.match(m, /Kurt Medya/); assert.match(m, /Sahibi/); assert.match(m, /%100/);
    // eski sunucu (ortaklar/il yok)
    await page.evaluate(async () => { window.YENI = false; soKitapSekme('vitrin'); await soKitapVitriniAc(); soYayineviAc(1); });
    m = await page.evaluate(() => document.getElementById('icerik').innerText);
    assert.match(m, /Sahibi/); assert.match(m, /EnverTalat/); assert.match(m, /Çıkardığı kitaplar/);
    await page.close();
  }
  assert.deepEqual(hatalar, []);
  console.log('Yayınevi sayfası arayüz testi: TAMAM (390 ve 320 px)');
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
