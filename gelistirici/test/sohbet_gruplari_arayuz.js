// Oyuncu sohbet grupları arayüz testi: Gruplarım bölümü, yeni grup, grup sohbeti, grup bilgisi (ad, ekle, çıkar, kapat, ayrıl).
// Ağ yok; sahte RPC; kurgusal veri.
// NODE_PATH=/opt/npm-tools/node_modules CHROME_PATH=/usr/bin/google-chrome node gelistirici/test/sohbet_gruplari_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
const html = fs.readFileSync(htmlYol, 'utf8').replace(/<script src="https:[^"]+"><\/script>/g, '');
const shot = process.argv[2];

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  const hatalar = [];
  try {
    for (const w of [390, 320]) {
      for (const rol of ['kurucu', 'uye']) {
        const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR' });
        page.on('pageerror', e => hatalar.push(w + '/' + rol + ': ' + e.message + ' @' + String(e.stack || '').split('\n')[1]));
        await page.route('**/*', r => r.abort());
        await page.setContent(html);
        await page.waitForFunction(() => typeof sekmeAc === 'function' && window.SOHBET_TASARIM_V1);
        await page.evaluate((rol) => {
          const S = (dk) => new Date(Date.now() + dk * 60e3).toISOString();
          const P1 = { id: 1, ad: 'Deneme Partisi', kisa: 'DP', renk: '#3f7be0' };
          window.calls = []; window.GRUPLAR = rol === 'uye' ? [{ id: 7, ad: 'Ege Gönüllüleri', kurucu: false, uye: ['Baran', 'Deniz', 'Ekin'] }] : [];
          window.GMESAJ = [{ id: 501, kad: 'Baran', metin: 'Gruba hoş geldiniz.', zaman: S(-4), parti: P1, unvan: null, benim: false }];
          const temel = ['genel', 'il', 'belediye', 'parti', 'yonetim', 'ittifak', 'meclis', 'grup', 'divan', 'kabine'].map(k => ({ kanal: k, baslik: k, kilit: ['yonetim', 'ittifak', 'grup', 'divan', 'kabine'].includes(k) ? 'Kilitli' : null, yazabilir: true, okunmamis: 0, son: null, cevrimici: 5 }));
          const k = v => JSON.parse(JSON.stringify(v));
          API = { rpc: async (ad, a) => {
            calls.push({ ad, args: a });
            if (ad === 'ozel_liste') return [{ kad: 'Selin', parti: null, unvan: null, son: 'Selam', zaman: S(-30), benden: false, okunmamis: 0, okundu: true, aktif: 'cevrimici' }];
            if (ad === 'sohbet_ozet') return { cevrimici: 9, toplam_okunmamis: 1, kanallar: k(temel.concat(GRUPLAR.map(g => ({ kanal: 'og:' + g.id, baslik: g.ad, kilit: null, yazabilir: true, okunmamis: 1, son: GMESAJ.length ? { kad: 'Baran', metin: GMESAJ[GMESAJ.length - 1].metin, zaman: S(-4) } : null, cevrimici: 2, sinyal: 'sohbet:og:' + g.id, ozgrup: true, grup_id: g.id, kurucu: g.kurucu, uye_sayisi: g.uye.length, olusturma: S(-100) })))) };
            if (ad === 'sohbet_grup_kur') { GRUPLAR.push({ id: 9, ad: a.p_ad, kurucu: true, uye: ['Deniz'].concat(a.p_uyeler) }); return { tamam: true, id: 9, kanal: 'og:9', ad: a.p_ad, eklenen: a.p_uyeler.length, atlanan: [] }; }
            if (ad === 'sohbet_oku') {
              const g = GRUPLAR.find(x => 'og:' + x.id === a.p_kanal);
              if (/^og:/.test(a.p_kanal) && !g) throw new Error('Bu sohbet grubunun üyesi değilsin ya da grup kapatıldı.');
              return { baslik: g ? g.ad : 'Kanal', mesajlar: k(GMESAJ.filter(m => a.p_sonra == null || m.id > a.p_sonra)), yazabilir: true, sinyal: 'sohbet:' + a.p_kanal };
            }
            if (ad === 'sohbet_yaz') { GMESAJ.push({ id: 600 + GMESAJ.length, kad: 'Deniz', metin: a.p_metin, zaman: new Date().toISOString(), parti: P1, benim: true }); return { tamam: true }; }
            if (ad === 'sohbet_grup_detay') {
              const g = GRUPLAR.find(x => x.id === a.p_grup);
              return { id: g.id, ad: g.ad, kurucu: g.kurucu ? 'Deniz' : 'Baran', benim_kurucu: g.kurucu, uye_sayisi: g.uye.length, uye_sinir: 100,
                uyeler: g.uye.map(u => ({ kad: u, unvan: null, parti: P1, kurucu: g.kurucu ? u === 'Deniz' : u === 'Baran', ben: u === 'Deniz', cevrimici: u !== 'Ekin' })) };
            }
            if (ad === 'sohbet_grup_ad') { const g = GRUPLAR.find(x => x.id === a.p_grup); g.ad = a.p_ad; return { tamam: true, ad: a.p_ad }; }
            if (ad === 'sohbet_grup_uye_ekle') { GRUPLAR.find(x => x.id === a.p_grup).uye.push(a.p_kad); return { tamam: true, kad: a.p_kad }; }
            if (ad === 'sohbet_grup_uye_cikar') { const g = GRUPLAR.find(x => x.id === a.p_grup); g.uye = g.uye.filter(u => u !== a.p_kad); return { tamam: true }; }
            if (ad === 'sohbet_grup_kapat' || ad === 'sohbet_grup_ayril') { GRUPLAR = GRUPLAR.filter(x => x.id !== a.p_grup); return { tamam: true }; }
            if (ad === 'oyuncu_arama') return { toplam: 2, oyuncular: [{ kad: 'Ekin', il_ad: 'Ankara', parti: P1, unvan: null }, { kad: 'Mert', il_ad: 'İzmir', parti: null, unvan: null }] };
            if (ad === 'rozetler') return { bildirim: 0, sohbet: 1, ozel: 0 };
            if (ad === 'durum') return { simdi: new Date().toISOString(), profil: D.durum.profil, okunmamis: { bildirim: 0, sohbet: 1 } };
            if (ad === 'mesaj_tepkileri') return {};
            if (ad === 'kimlikler') return {};
            return null;
          } };
          D.durum = { simdi: new Date().toISOString(), profil: { id: 'u1', kad: 'Deniz', il_id: 35, il_ad: 'İzmir', parti: P1, makamlar: [], cuzdan: { para: 1 } } };
          D.okunmamis = { bildirim: 0, sohbet: 1 };
          window.SOHBET_DURUM.seg = 'kanal';
        }, rol);
        const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
        const mtext = () => page.evaluate(() => (document.querySelector('#modal') || {}).innerText || '');
        const tasma = async (ad) => {
          const t = await page.evaluate(() => {
            const d = document.documentElement.scrollWidth - window.innerWidth;
            const m = document.querySelector('#modal .modal'); const mt = m ? m.scrollWidth - m.clientWidth : 0;
            return Math.max(d, mt);
          });
          assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`);
        };
        const olcu = async (ad) => {
          const r = await page.evaluate(() => {
            const kotu = [];
            document.querySelectorAll('#modal input, #modal textarea').forEach(i => { const f = parseFloat(getComputedStyle(i).fontSize); if (f < 16) kotu.push('giris ' + i.id + ' ' + f); });
            document.querySelectorAll('#modal button:not(.sh-gy-cip), .sh-gr-yeni, .sh-gr-bos').forEach(b => { const h = b.getBoundingClientRect().height; if (h && h < 44) kotu.push('dugme ' + (b.className || b.id) + ' ' + h); });
            return kotu;
          });
          assert.deepEqual(r, [], ad + ' ölçü: ' + r.join(', '));
        };
        const foto = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, `${ad}_${rol}_${w}.png`) }); } };
        const son = (ad) => page.evaluate((a) => calls.filter(c => c.ad === a).pop(), ad);
        const bekleCagri = (ad) => page.waitForFunction((a) => calls.some(c => c.ad === a), ad);

        await page.evaluate(() => sekmeAc('sohbet'));
        await page.waitForSelector('#shGovde .sh-bas h3');
        await page.waitForFunction(() => /Gruplarım/.test(document.querySelector('#shGovde').innerText));

        if (rol === 'kurucu') {
          // Boş durum + Yeni grup
          assert.match(await metin(), /Kendi sohbet grubunu kur/);
          await olcu('liste'); await tasma('liste'); await foto('1_liste_bos');
          await page.click('.sh-gr-yeni');
          await page.waitForSelector('#shGAd');
          await page.fill('#shGAd', 'Ege Gönüllüleri');
          await page.fill('#shGAra', 'Ek');
          await page.waitForSelector('.sh-gy-sec[data-kad="Ekin"]');
          await page.click('.sh-gy-sec[data-kad="Ekin"]');
          await page.click('.sh-gy-sec[data-kad="Mert"]');
          assert.equal(await page.locator('.sh-gy-cip').count(), 2);
          await page.click('.sh-gy-cip[data-kad="Mert"]');
          assert.equal(await page.locator('.sh-gy-cip').count(), 1);
          assert.match(await mtext(), /1 kişi seçildi/);
          await olcu('yeni grup'); await tasma('yeni grup'); await foto('2_yeni_grup');
          await page.click('#shGKur');
          await page.waitForSelector('.shk-kanal');
          const kur = await son('sohbet_grup_kur');
          assert.deepEqual(kur.args, { p_ad: 'Ege Gönüllüleri', p_uyeler: ['Ekin'] });
          await page.waitForFunction(() => document.getElementById('sbBaslik').textContent === 'Ege Gönüllüleri');
          assert.equal((await son('sohbet_oku')).args.p_kanal, 'og:9');
          assert.match(await page.locator('.sht-serit').innerText(), /Yalnızca üyeler/i);
          // Gruba yaz
          await page.fill('#yaz', 'Toplantı yarın 20.00');
          await page.click('#gonder');
          await bekleCagri('sohbet_yaz');
          assert.deepEqual((await son('sohbet_yaz')).args, { p_kanal: 'og:9', p_metin: 'Toplantı yarın 20.00' });
          await tasma('grup sohbet'); await foto('3_grup_sohbet');
          // Grup bilgisi
          await page.click('#shkCev');
          await page.waitForSelector('#shGbAdInp');
          assert.match(await mtext(), /ÜYELER \(2\)/i);
          await olcu('grup bilgisi'); await tasma('grup bilgisi'); await foto('4_grup_bilgi');
          // Ad değiştir
          await page.fill('#shGbAdInp', 'Ege Ekibi');
          await page.click('[data-gb="ad"]');
          await page.waitForFunction(() => document.getElementById('sbBaslik').textContent === 'Ege Ekibi');
          assert.deepEqual((await son('sohbet_grup_ad')).args, { p_grup: 9, p_ad: 'Ege Ekibi' });
          // Üye ekle
          await page.fill('#shGbAra', 'Me');
          await page.waitForSelector('[data-gb="ekle"][data-kad="Mert"]');
          assert.equal(await page.locator('#shGbSonuc .sh-gb-sen').count(), 1); // Ekin zaten üye
          await page.click('[data-gb="ekle"][data-kad="Mert"]');
          await page.waitForFunction(() => /ÜYELER \(3\)/i.test(document.querySelector('#modal').innerText));
          assert.deepEqual((await son('sohbet_grup_uye_ekle')).args, { p_grup: 9, p_kad: 'Mert' });
          // Üye çıkar (onaylı)
          await page.click('[data-gb="cikar"][data-kad="Ekin"]');
          await page.waitForSelector('#evet'); await page.click('#evet');
          await page.waitForFunction(() => /ÜYELER \(2\)/i.test((document.querySelector('#modal') || {}).innerText || ''));
          assert.deepEqual((await son('sohbet_grup_uye_cikar')).args, { p_grup: 9, p_kad: 'Ekin' });
          assert.equal(await page.locator('[data-gb="cikar"][data-kad="Deniz"]').count(), 0); // kurucu kendini çıkaramaz
          // Grubu kapat
          await page.click('[data-gb="kapat"]');
          await page.waitForSelector('#evet'); await page.click('#evet');
          await bekleCagri('sohbet_grup_kapat');
          await page.waitForSelector('#shGovde');
          await page.waitForFunction(() => /Kendi sohbet grubunu kur/.test(document.querySelector('#shGovde').innerText));
        } else {
          // Üye: grup listede, yönetim düğmeleri yok, ayrılabilir
          await page.waitForSelector('.sh-c[data-kanal="og:7"]');
          assert.match(await page.locator('.sh-c[data-kanal="og:7"]').innerText(), /Ege Gönüllüleri/);
          assert.match(await page.locator('.sh-c[data-kanal="og:7"]').innerText(), /Baran:\s*Gruba hoş geldiniz/);
          await tasma('liste uye'); await foto('1_liste');
          await page.click('.sh-c[data-kanal="og:7"]');
          await page.waitForSelector('.shk-kanal');
          await page.waitForFunction(() => document.getElementById('sbBaslik').textContent === 'Ege Gönüllüleri');
          await page.click('#shkKim');
          await page.waitForSelector('.sh-gb-uyeler');
          assert.equal(await page.locator('#shGbAdInp').count(), 0);
          assert.equal(await page.locator('[data-gb="cikar"]').count(), 0);
          assert.match(await mtext(), /yetkisi grubu kuran Baran/);
          await olcu('grup bilgisi uye'); await tasma('grup bilgisi uye'); await foto('2_bilgi_uye');
          await page.click('[data-gb="ayril"]');
          await page.waitForSelector('#evet'); await page.click('#evet');
          await bekleCagri('sohbet_grup_ayril');
          assert.deepEqual((await son('sohbet_grup_ayril')).args, { p_grup: 7 });
          await page.waitForSelector('#shGovde');
          await page.waitForFunction(() => !document.querySelector('.sh-c[data-kanal="og:7"]'));
        }
        await page.close();
      }
    }
    assert.deepEqual(hatalar, [], 'Sayfa hataları:\n' + hatalar.join('\n'));
    console.log('sohbet_gruplari_arayuz: TAMAM');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
