// Mesajlar (Sohbet yeniden tasarımı) arayüz testi: gelen kutusu, kanallar, özel konuşma, kanal, yeni mesaj, üst kısayol.
// Ağ yok; sahte RPC; kurgusal veri.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/sohbet_tasarim_arayuz.js [ekran-klasoru]
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
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR' });
      page.on('pageerror', e => hatalar.push(w + ': ' + e.message + ' @' + String(e.stack || '').split('\n')[1]));
      await page.route('**/*', r => r.abort());
      await page.setContent(html);
      await page.waitForFunction(() => typeof sekmeAc === 'function' && window.SOHBET_TASARIM_V1);
      await page.evaluate(() => {
        const S = (dk) => new Date(Date.now() + dk * 60e3).toISOString();
        const P1 = { id: 1, ad: 'Deneme Partisi', kisa: 'DP', renk: '#3f7be0', amblem: 'yildiz' }, P2 = { id: 2, ad: 'Örnek Hareket', kisa: 'ÖH', renk: '#e0563f' };
        window.calls = []; window.DM_MESAJ = [
          { id: 11, metin: 'Selam, ittifak teklifini konuşalım mı?', zaman: S(-60 * 26), benim: false },
          { id: 12, metin: 'Olur, akşam uygun.', zaman: S(-60 * 25), benim: true },
          { id: 13, metin: 'Meclis grubunda da destek var.', zaman: S(-9), benim: false },
          { id: 14, metin: 'Harika, listeyi hazırlıyorum. #ittifak', zaman: S(-8), benim: true },
          { id: 15, metin: 'Tamam 👍', zaman: S(-7), benim: true },
          { id: 16, metin: '🇹🇷', zaman: S(-3), benim: false }];
        window.OKUNDU_SON = 14;
        window.KANAL_MESAJ = [
          { id: 101, kad: 'Ekin', metin: 'Genel Kurul\'da bugün bütçe var.', zaman: S(-20), parti: P1, unvan: 'Milletvekili (Ankara)', benim: false },
          { id: 102, kad: 'Ekin', metin: 'Herkes katılsın.', zaman: S(-19), parti: P1, unvan: 'Milletvekili (Ankara)', benim: false },
          { id: 103, kad: 'Mert', metin: 'Katılıyorum!', zaman: S(-10), parti: P2, unvan: null, benim: false },
          { id: 104, kad: 'Deniz', metin: 'Ben de geliyorum.', zaman: S(-5), parti: P1, unvan: null, benim: true }];
        const kanallar = ['genel', 'il', 'belediye', 'parti', 'yonetim', 'ittifak', 'meclis', 'grup', 'divan', 'kabine'].map((k, i) => ({
          kanal: k, baslik: { genel: 'Türkiye Meydanı', il: 'İzmir Kahvesi', belediye: 'İzmir Belediye Meclisi', parti: 'Deneme Partisi', meclis: 'TBMM Genel Kurulu' }[k] || k,
          kilit: ['yonetim', 'ittifak', 'grup', 'divan', 'kabine'].includes(k) ? 'Görev gelince açılır.' : null,
          yazabilir: k !== 'meclis' && k !== 'belediye', okunmamis: k === 'genel' ? 3 : k === 'parti' ? 1 : 0,
          son: ['genel', 'il', 'parti'].includes(k) ? { kad: 'Ekin', metin: 'Merhaba arkadaşlar', zaman: S(-5) } : null,
          cevrimici: ['genel', 'il', 'belediye', 'parti'].includes(k) ? 12 : null }));
        API = { rpc: async (ad, a) => {
          calls.push({ ad, args: a });
          const k = (v) => JSON.parse(JSON.stringify(v));
          if (ad === 'ozel_liste') return [
            { kad: 'mustafaozdemir', parti: P1, unvan: 'Milletvekili (İzmir)', son: '🇹🇷', zaman: S(-3), benden: false, okunmamis: 2, okundu: false, aktif: 'cevrimici' },
            { kad: 'Selin', parti: null, unvan: null, son: 'Sağolun şimdi bakıyorum, birazdan dönerim çok uzun bir mesaj bu', zaman: S(-60 * 30), benden: true, okunmamis: 0, okundu: true, aktif: 'bugun' },
            { kad: 'Baran', parti: P2, unvan: 'Belediye Başkanı (İzmir)', son: 'Görüşürüz', zaman: S(-60 * 24 * 9), benden: true, okunmamis: 0, okundu: false, aktif: 'uzun' }];
          if (ad === 'sohbet_ozet') return { cevrimici: 42, toplam_okunmamis: 4, kanallar: k(kanallar) };
          if (ad === 'ozel_oku') {
            const L = DM_MESAJ.filter(m => a.p_sonra == null || m.id > a.p_sonra);
            return { kad: a.p_kad, parti: P1, unvan: 'Milletvekili (İzmir)', mesajlar: k(L), engelledim: false, aktif: 'cevrimici', okundu_son: OKUNDU_SON };
          }
          if (ad === 'ozel_yaz') { DM_MESAJ.push({ id: 17 + DM_MESAJ.length, metin: a.p_metin, zaman: new Date().toISOString(), benim: true }); return { tamam: true }; }
          if (ad === 'sohbet_oku') {
            const L = KANAL_MESAJ.filter(m => (a.p_sonra == null || m.id > a.p_sonra) && (a.p_once == null || m.id < a.p_once));
            return { baslik: { genel: 'Türkiye Meydanı', meclis: 'TBMM Genel Kurulu' }[a.p_kanal] || 'Kanal', mesajlar: k(L), yazabilir: a.p_kanal !== 'meclis' };
          }
          if (ad === 'sohbet_yaz') { KANAL_MESAJ.push({ id: 200 + KANAL_MESAJ.length, kad: 'Deniz', metin: a.p_metin, zaman: new Date().toISOString(), parti: P1, benim: true }); return { tamam: true }; }
          if (ad === 'oyuncu_arama') return { toplam: 1, oyuncular: [{ kad: 'Ekin', il_ad: 'Ankara', parti: P1, unvan: 'Milletvekili (Ankara)' }] };
          if (ad === 'oyuncu_kart') return { kad: a.p_kad };
          if (ad === 'rozetler') return { bildirim: 1, sohbet: 6, ozel: 2 };
          if (ad === 'durum') return { simdi: new Date().toISOString(), profil: D.durum.profil, okunmamis: { bildirim: 1, sohbet: 6 } };
          if (ad === 'kimlikler') return {};
          return null;
        } };
        D.durum = { simdi: new Date().toISOString(), profil: { kad: 'Deniz', il_id: 35, il_ad: 'İzmir', parti: P1, makamlar: [], cuzdan: { para: 250000 } } };
        D.okunmamis = { bildirim: 1, sohbet: 6 };
      });
      const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
      const tasma = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`) }); } };
      const son = (ad) => page.evaluate((a) => calls.filter(c => c.ad === a).pop(), ad);

      // 1) Üst çubukta mesaj kısayolu (Gündem dışı bir ekranda da çalışır)
      await page.evaluate(() => { D.sekme = 'harita'; D.yigin = []; iskelet('Türkiye', '<div class="kart">x</div>'); });
      await page.waitForSelector('header.ust .sh-ust-dm');
      assert.equal(await page.locator('header.ust .sh-ust-dm-say').innerText(), '6');

      // 2) Gelen kutusu (Özel)
      await page.evaluate(() => { try { sessionStorage.removeItem('shSeg'); } catch (e) {} SOHBET_DURUM.seg = 'ozel'; });
      await page.click('header.ust .sh-ust-dm');
      await page.waitForSelector('.sh-k[data-kad="mustafaozdemir"]');
      let t = await metin();
      assert.match(t, /Mesajlar/); assert.match(t, /Sohbetler/); assert.match(t, /Okunmamış/); assert.doesNotMatch(t, /undefined|NaN|null/);
      assert.equal(await page.locator('.sh-liste .sh-k').count(), 3);
      assert.equal(await page.locator('.sh-k.yeni').count(), 1);
      assert.equal(await page.locator('.sh-k[data-kad="Selin"] .sh-tik.on').count(), 1, 'okundu çift tik');
      assert.equal(await page.locator('.sh-hikaye .sh-h.cev').count(), 1);
      assert.equal(await page.locator('[data-pa-hero]').count(), 0, 'eski premium kartı çıkmamalı');
      assert.equal(await page.locator('#app .sh-fab').count(), 1);
      const avBoy = await page.locator('.sh-k[data-kad="mustafaozdemir"] .sh-k-av').boundingBox();
      assert.ok(avBoy.width <= 56 && avBoy.height <= 56, 'portre sabit boyutta');
      const satirBoy = await page.locator('.sh-k[data-kad="mustafaozdemir"]').boundingBox();
      assert.ok(satirBoy.height < 110, 'satır yüksekliği makul: ' + satirBoy.height);
      await foto('1_gelen_kutusu'); await tasma('Gelen kutusu');

      // 3) Arama ve süzgeç
      await page.fill('#shAra', 'sel');
      await page.waitForTimeout(80);
      assert.equal(await page.locator('.sh-liste .sh-k').count(), 1);
      await page.click('[data-sh="araSil"]');
      await page.click('[data-sh="suz"][data-v="1"]');
      assert.equal(await page.locator('.sh-liste .sh-k').count(), 1);
      await page.click('[data-sh="suz"][data-v="0"]');

      // 4) Kanallar
      await page.click('[data-sh="seg"][data-v="kanal"]');
      await page.waitForSelector('.sh-meydan');
      t = await metin();
      assert.match(t, /Türkiye Meydanı/); assert.match(t, /Herkese açık/); assert.match(t, /Siyasi örgüt/); assert.match(t, /Devlet/);
      assert.equal(await page.locator('.sh-c.kilit').count(), 5);
      await foto('2_kanallar'); await tasma('Kanallar');
      await page.click('[data-sh="seg"][data-v="ozel"]');

      // 5) Özel konuşma
      await page.click('.sh-k[data-kad="mustafaozdemir"]');
      await page.waitForSelector('.shk-dm .shm[data-id="16"]');
      t = await metin();
      assert.match(t, /mustafaozdemir/); assert.match(t, /Çevrimiçi/); assert.match(t, /Bugün/); assert.match(t, /Dün|Çarşamba|Perşembe|Cuma|Cumartesi|Pazar|Pazartesi|Salı/);
      assert.equal(await page.locator('.shm[data-id="16"].emoji').count(), 1, 'bayrak tek emoji olarak');
      const em = await page.locator('.shm[data-id="16"] .shm-tx').boundingBox();
      assert.ok(em.height < 80 && em.width < 90, 'emoji büyük ama sınırlı: ' + JSON.stringify(em));
      assert.equal(await page.locator('.shm[data-id="14"] .shm-tik.on').count(), 1, '14 okundu');
      assert.equal(await page.locator('.shm[data-id="15"] .shm-tik.on').count(), 0, '15 henüz okunmadı');
      assert.equal(await page.locator('.shm-gun').count(), 2);
      assert.equal(await page.locator('.shm-et').count(), 1);
      await foto('3_ozel_konusma'); await tasma('Özel');
      assert.equal(await page.locator('#gonder').isDisabled(), true);
      await page.fill('#yaz', 'Yarın Meclis\'te görüşürüz');
      assert.equal(await page.locator('#gonder.hazir').count(), 1);
      await foto('4_yaziyor');
      await page.click('#gonder');
      await page.waitForFunction(() => [...document.querySelectorAll('.shm.benim .shm-tx')].some(x => /Yarın Meclis/.test(x.textContent)) && !document.querySelector('.shm.bekle'));
      assert.equal((await son('ozel_yaz')).args.p_metin, "Yarın Meclis'te görüşürüz");
      assert.equal(await page.inputValue('#yaz'), '');
      // okundu güncellenince tikler maviye döner
      await page.evaluate(() => { OKUNDU_SON = 999; return SOHBET_DURUM; });
      await page.evaluate(() => sohbetTasarim && 1);
      await page.waitForTimeout(50);
      // eylem sayfası
      await page.click('.shm[data-id="13"] .shm-b');
      await page.waitForSelector('#modal .sh-es[data-es="sikayet"]');
      assert.match(await page.locator('#modal').innerText(), /Metni kopyala/);
      await foto('5_eylem');
      await page.click('#modal [data-es="vaz"]');
      await page.click('#dmMenu'); await page.waitForSelector('#modal [data-es="engel"]');
      await page.click('#modal [data-es="vaz"]');

      // 6) Kanal ekranı (izleyici)
      await page.evaluate(() => { D.sekme = 'sohbet'; D.yigin = []; ekranAc(() => sohbetEkrani('meclis')); });
      await page.waitForSelector('.shk-kanal .shm[data-id="101"]');
      assert.equal(await page.locator('.shk-not').count(), 1);
      assert.match(await page.locator('.shk-not').innerText(), /Genel Kurul/);
      assert.equal(await page.locator('.shm[data-id="101"] .shm-kim').count(), 1);
      assert.equal(await page.locator('.shm[data-id="102"] .shm-kim').count(), 0, 'gruplanmış ikinci mesajda ad tekrarlanmaz');
      await foto('6_kanal_izleyici'); await tasma('Kanal');

      // 7) Kanal ekranı (yazabilir) + gönderim
      await page.evaluate(() => { D.yigin = []; ekranAc(() => sohbetEkrani('genel')); });
      await page.waitForSelector('.shk-kanal .shm[data-id="104"]');
      await page.fill('#yaz', 'Meydanda herkese selam');
      await page.click('#gonder');
      await page.waitForFunction(() => [...document.querySelectorAll('.shm.benim .shm-tx')].some(x => /herkese selam/.test(x.textContent)) && !document.querySelector('.shm.bekle'));
      assert.equal((await son('sohbet_yaz')).args.p_kanal, 'genel');
      await foto('7_kanal');

      // 8) Yeni mesaj penceresi
      await page.evaluate(() => { D.yigin = []; sekmeAc('sohbet'); });
      await page.waitForSelector('.sh-fab');
      await page.click('.sh-fab'); await page.waitForSelector('#shKime');
      assert.match(await page.locator('#modal').innerText(), /KONUŞTUKLARIN|Son konuştukların/);
      await page.fill('#shKime', 'Ek'); await page.waitForSelector('#modal .sh-ys[data-kad="Ekin"]');
      await foto('8_yeni_mesaj');
      await page.click('#modal .sh-ys[data-kad="Ekin"]');
      await page.waitForSelector('.shk-dm');
      assert.equal((await son('ozel_oku')).args.p_kad, 'Ekin');

      // 9) Boş gelen kutusu
      await page.evaluate(() => { const eski = API.rpc; API.rpc = async (ad, a) => ad === 'ozel_liste' ? [] : eski(ad, a); D.yigin = []; SOHBET_DURUM.dm = null; sekmeAc('sohbet'); });
      await page.waitForSelector('.sh-bos-res');
      assert.match(await metin(), /Henüz özel mesajın yok/);
      await foto('9_bos'); await tasma('Boş');
      await page.close();
    }
  } finally { await browser.close(); }
  if (hatalar.length) { console.error(hatalar.join('\n')); process.exit(1); }
  console.log('sohbet_tasarim_arayuz: TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
