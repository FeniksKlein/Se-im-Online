// Kürsü (sosyal ağ) arayüz testi: ana akış, gönderi, beğeni/yeniden paylaşım, yazma, profil, keşfet/gündem, bildirimler, etiket.
// Ağ yok; sahte RPC; kurgusal veri.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/kursu_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
const html = fs.readFileSync(htmlYol, 'utf8').replace(/<script src="https:[^"]+"><\/script>/g, '');
const shot = process.argv[2];
const S = (dk) => new Date(Date.now() + dk * 60e3).toISOString();
const P1 = { id: 1, ad: 'Deneme Partisi', kisa: 'DP', renk: '#3f7be0' }, P2 = { id: 2, ad: 'Örnek Hareket', kisa: 'ÖH', renk: '#e0563f' };
const g = (id, kad, metin, ek) => Object.assign({ id, kad, metin, zaman: S(-id * 7), unvan: null, parti: P1, il: 'Ankara', yanit_id: null, begeni: 3, begenmeme: 1, yanit: 2,
  begendim: false, begenmedim: false, benim: kad === 'Deniz', yp: 1, ypledim: false, alinti_sayi: 0, alinti: null, yanit_kad: null, takip_ediyorum: false }, ek || {});
const G1 = g(901, 'Ekin', 'Bütçe görüşmelerinde #eğitim payı artmalı. @Mert ne dersin?', { unvan: 'Milletvekili (Ankara)', begeni: 1240, yp: 88 });
const G2 = g(902, 'Mert', 'Bugün meydandaydık, katılan herkese teşekkürler. #miting', { parti: P2, takip_ediyorum: true });
const G3 = g(903, 'Selin', 'Bu söze katılıyorum.', { alinti: { id: 901, kad: 'Ekin', unvan: 'Milletvekili (Ankara)', parti: P1, metin: G1.metin, zaman: G1.zaman } });
const G4 = g(904, 'Deniz', 'İlk gönderim burada.', { begeni: 0, begenmeme: 0, yanit: 0, yp: 0 });
const AKIS = { liste: [{ sira: S(-1), yp: null, g: G1 }, { sira: S(-2), yp: 'Baran', g: G2 }, { sira: S(-3), yp: null, g: G3 }, { sira: S(-4), yp: null, g: G4 }], imlec: null };
const Y1 = g(905, 'Mert', 'Katılıyorum, öğretmen maaşları da konuşulmalı.', { yanit_id: 901, yanit_kad: 'Ekin', parti: P2, yp: 0 });
const GONDERI = { ana: Object.assign({}, G1, { alinti_sayi: 1 }), odak: 901, yanitlar: [Y1], alintilar: [G3] };
const KISI = (kad, ek) => Object.assign({ kad, unvan: null, parti: P1, bio: 'Kurgusal deneme hesabı. #deneme', takipci: 12, takip_ediyorum: false, beni_takip_ediyor: false, benim: kad === 'Deniz' }, ek || {});
const PROFIL = { kisi: Object.assign(KISI('Ekin', { unvan: 'Milletvekili (Ankara)', beni_takip_ediyor: true, takipci: 2400 }), { il: 'Ankara', katilim: S(-60 * 24 * 40), kapak: 'deniz', bio_kendi: 'Kurgusal deneme hesabı.', takip: 140, gonderi: 51, begeni_alinan: 9800, engelli: false, ortak: 3 }),
  sabit: Object.assign({}, G1, { id: 899, metin: 'Sabitlenmiş kurgusal gönderi.' }), liste: [{ sira: S(-1), yp: null, g: G1 }], imlec: null };
const BENPROFIL = { kisi: Object.assign(KISI('Deniz', { benim: true, bio: null }), { il: 'İstanbul', katilim: S(-60 * 24 * 3), kapak: 'mor', bio_kendi: null, takip: 2, gonderi: 1, begeni_alinan: 0, engelli: false, ortak: 0 }), sabit: null, liste: [], imlec: null };
const GUNDEM = { saat: 48,
  etiketler: [{ tur: 'etiket', ad: '#eğitim', anahtar: 'eğitim', sayi: 42, kisi: 17 }, { tur: 'etiket', ad: '#miting', anahtar: 'miting', sayi: 12, kisi: 6 }],
  kisiler: [{ tur: 'kisi', ad: 'Ekin', anahtar: 'Ekin', unvan: 'Milletvekili (Ankara)', parti: P1, sayi: 30, anma: 20, puan: 90, takip_ediyorum: false }],
  partiler: [{ tur: 'parti', ad: P2.ad, anahtar: 2, parti: P2, sayi: 18 }], dernekler: [{ tur: 'dernek', ad: 'Deneme Derneği', anahtar: 5, sayi: 4 }],
  oneriler: [KISI('Selin'), KISI('Baran', { unvan: 'Belediye Başkanı (İzmir)', parti: P2 })] };
const BILDIRIM = { okundu: S(-30), yeni: 2, liste: [
  { tur: 'takip', kad: 'Selin', zaman: S(-5), kisi: KISI('Selin', { beni_takip_ediyor: true }) },
  { tur: 'yanit', kad: 'Mert', zaman: S(-10), g: Y1 },
  { tur: 'begeni', sayi: 5, zaman: S(-40), g: { id: 904, kad: 'Deniz', metin: 'İlk gönderim burada.', zaman: S(-50) } }] };

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  const hatalar = [];
  try {
    for (const w of [390, 320]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: true, locale: 'tr-TR' });
      page.on('pageerror', e => hatalar.push(w + ': ' + e.message + ' @' + String(e.stack || '').split('\n')[1]));
      await page.route('**/*', r => r.abort());
      await page.setContent(html);
      await page.waitForFunction(() => typeof kursuEkrani === 'function' && typeof sekmeAc === 'function');
      await page.evaluate((F) => {
        window.calls = [];
        const k = (v) => JSON.parse(JSON.stringify(v));
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'kursu_akis') return k(F.AKIS);
          if (ad === 'kursu_ben') return { kad: 'Deniz', takip: 2, takipci: 1, yeni: 2, benim: true };
          if (ad === 'kursu_gundem') return k(F.GUNDEM);
          if (ad === 'kursu_gonderi') return k(F.GONDERI);
          if (ad === 'kursu_profil') return k(args.p_kad === 'Deniz' ? F.BENPROFIL : F.PROFIL);
          if (ad === 'kursu_bildirimler') return k(F.BILDIRIM);
          if (ad === 'kursu_etiket') return { etiket: args.p_etiket, liste: k(F.AKIS.liste.slice(0, 2)), sayi: 42, imlec: null };
          if (ad === 'kursu_ara') return { kisiler: [k(F.GUNDEM.oneriler[0])], etiketler: [{ ad: '#eğitim', anahtar: 'eğitim', sayi: 42 }], gonderiler: [k(F.AKIS.liste[0].g)] };
          if (ad === 'kursu_takip_et') return { kad: args.p_kad, takip_ediyorum: args.p_takip, takipci: 13, benim: false };
          if (ad === 'kursu_yp') return { yp: args.p_ac ? 89 : 88, ypledim: args.p_ac };
          if (ad === 'akis_tepki') return { begeni: 1241, begenmeme: 1, begendim: true, begenmedim: false };
          if (ad === 'akis_yaz') return { tamam: true, id: 999 };
          if (ad === 'akis_yanit_yaz') return { tamam: true, id: 998 };
          if (ad === 'kursu_takip_listesi') return [k(F.GUNDEM.oneriler[0])];
          if (ad === 'kimlikler') return {};
          if (ad === 'durum') return { simdi: new Date().toISOString(), profil: D.durum.profil };
          return null;
        } };
        D.durum = { profil: { kad: 'Deniz', il_id: 34, il_ad: 'İstanbul', parti: { id: 1, ad: 'Deneme Partisi', kisa: 'DP', renk: '#3f7be0' }, makamlar: [], cuzdan: { para: 250000 } } };
      }, { AKIS, GONDERI, PROFIL, BENPROFIL, GUNDEM, BILDIRIM });
      const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
      const tasma = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`) }); } };
      const son = (ad) => page.evaluate((a) => calls.filter(c => c.ad === a).pop(), ad);

      // 1) Ana akış
      await page.evaluate(() => { D.sekme = 'gundem'; D.yigin = []; ekranAc(() => kursuEkrani('ana')); });
      await page.waitForSelector('.kr-g[data-id="901"]');
      let t = await metin();
      assert.match(t, /Kürsü/); assert.match(t, /Sana özel/); assert.match(t, /Takip ettiklerin/); assert.match(t, /Baran yeniden paylaştı/);
      assert.match(t, /Neler oluyor, Deniz\?/); assert.match(t, /1\.240/); assert.doesNotMatch(t, /undefined|NaN|null/);
      assert.equal(await page.locator('#krListe .kr-g').count(), 4);
      assert.equal(await page.locator('.kr-g[data-id="903"] .kr-alinti').count(), 1);
      await page.waitForSelector('#krSerit button'); assert.match(await page.locator('#krSerit').innerText(), /#eğitim/);
      assert.equal(await page.locator('#app .kr-fab').count(), 1);
      await foto('ana'); await tasma('Ana');

      // 2) Beğeni (iyimser + sunucu) ve yeniden paylaşım
      await page.click('.kr-g[data-id="901"] [data-k="begen"]');
      await page.waitForTimeout(150);
      assert.ok(await page.locator('.kr-g[data-id="901"] [data-k="begen"].on').count());
      assert.deepEqual((await son('akis_tepki')).args, { p_id: 901, p_tepki: 'begen' });
      assert.match(await page.locator('.kr-g[data-id="901"] [data-k="begen"]').innerText(), /1\.241/);
      await page.click('.kr-g[data-id="901"] [data-k="yp"]'); await page.waitForSelector('#modal .kr-sf');
      assert.match(await page.locator('#modal').innerText(), /Yeniden paylaş/); assert.match(await page.locator('#modal').innerText(), /Alıntıla/);
      await page.click('#modal [data-sf="yp"]'); await page.waitForTimeout(150);
      assert.deepEqual((await son('kursu_yp')).args, { p_id: 901, p_ac: true });
      assert.ok(await page.locator('.kr-g[data-id="901"] [data-k="yp"].on').count());

      // 3) Yazma penceresi
      await page.click('.kr-sor'); await page.waitForSelector('#krYazMetin');
      assert.equal(await page.locator('#krYazGonder').isDisabled(), true);
      await page.fill('#krYazMetin', 'Kurgusal deneme gönderisi '); await page.click('#krYaz [data-ekle="#eğitim"]');
      assert.equal(await page.inputValue('#krYazMetin'), 'Kurgusal deneme gönderisi #eğitim ');
      await foto('yaz'); await tasma('Yaz');
      await page.click('#krYazGonder'); await page.waitForTimeout(250);
      assert.equal((await son('akis_yaz')).args.p_metin, 'Kurgusal deneme gönderisi #eğitim');
      assert.equal(await page.locator('#krYaz').count(), 0);

      // 4) Sekme değişimi
      await page.click('.kr-sekmeler [data-sekme="takip"]'); await page.waitForTimeout(250);
      assert.equal((await son('kursu_akis')).args.p_sekme, 'takip');

      // 5) Gönderi (konuşma)
      await page.click('.kr-g[data-id="901"] .kr-metin'); await page.waitForSelector('.kr-odak');
      t = await metin();
      assert.match(t, /Yanıtlar/); assert.match(t, /Alıntılar/); assert.match(t, /Ekin kişisine yanıt/); assert.match(t, /Beğeni/); assert.doesNotMatch(t, /undefined|NaN/);
      await foto('gonderi'); await tasma('Gönderi');
      await page.click('.kr-yanit-cubuk'); await page.waitForSelector('#krYaz .kr-yaz-baglam');
      assert.match(await page.locator('#krYaz').innerText(), /Ekin kişisine yanıt veriyorsun/);
      await page.fill('#krYazMetin', 'Kurgusal yanıt'); await page.click('#krYazGonder'); await page.waitForTimeout(250);
      assert.deepEqual((await son('akis_yanit_yaz')).args, { p_id: 901, p_metin: 'Kurgusal yanıt' });

      // 6) Profil (başkası) ve takip
      await page.click('.kr-odak .kr-ad'); await page.waitForSelector('.kr-p-kim');
      t = await metin();
      assert.match(t, /Seni takip ediyor/); assert.match(t, /Sabitlenmiş gönderi/); assert.match(t, /2\.400/); assert.match(t, /Takipçi/); assert.match(t, /Öne çıkanlar/);
      assert.doesNotMatch(t, /undefined|NaN/);
      await foto('profil'); await tasma('Profil');
      await page.click('.kr-p-btn .kr-takip'); await page.waitForTimeout(150);
      assert.deepEqual((await son('kursu_takip_et')).args, { p_kad: 'Ekin', p_takip: true });
      assert.equal(await page.locator('.kr-p-btn .kr-takip.on').count(), 1);
      await page.click('.kr-p-sekme [data-sekme="yanit"]'); await page.waitForTimeout(150);
      assert.equal((await son('kursu_profil')).args.p_sekme, 'yanit');

      // 7) Keşfet: gündem en çoktan aza
      await page.evaluate(() => { D.yigin = []; ekranAc(() => kursuEkrani('kesfet')); }); await page.waitForSelector('.kr-zirve');
      t = await metin();
      assert.match(t, /Türkiye gündemi/); assert.match(t, /1 numara/); assert.match(t, /Kimi takip etmeli/);
      const sira = await page.evaluate(() => [...document.querySelectorAll('#krKesfet .kr-tr-g b')].map(b => b.innerText.split('\n').pop().trim()));
      assert.deepEqual(sira, ['Ekin', 'Örnek Hareket', '#miting', 'Deneme Derneği']);   // 42 > 30 > 18 > 12 > 4
      assert.match(await page.locator('.kr-zirve').innerText(), /#eğitim/);
      await foto('kesfet'); await tasma('Keşfet');
      await page.click('[data-kr="suz"][data-f="parti"]'); assert.match(await page.locator('.kr-zirve').innerText(), /Örnek Hareket/);
      await page.fill('#krAra', 'sel'); await page.waitForSelector('#krAraSonuc .kr-kisi');
      assert.match(await page.locator('#krAraSonuc').innerText(), /Kişiler/);

      // 8) Bildirimler
      await page.evaluate(() => { D.yigin = []; ekranAc(() => kursuEkrani('bildirim')); }); await page.waitForSelector('.kr-bil');
      t = await metin();
      assert.match(t, /Selin seni takip etmeye başladı/); assert.match(t, /Mert gönderine yanıt verdi/); assert.match(t, /Gönderin 5 beğeni aldı/);
      assert.equal((await son('kursu_bildirimler')).args.p_okundu, true);
      await foto('bildirim'); await tasma('Bildirim');

      // 9) Etiket ve kendi profilim (boş hâl)
      await page.evaluate(() => { D.yigin = []; ekranAc(() => akisEkrani('eğitim')); }); await page.waitForSelector('.kr-et-bas');
      assert.match(await metin(), /#eğitim/); assert.match(await metin(), /42 gönderi/); await tasma('Etiket');
      await page.evaluate(() => { D.yigin = []; ekranAc(() => kursuProfilEkrani('Deniz')); }); await page.waitForSelector('.kr-p-kim');
      t = await metin(); assert.match(t, /Profili düzenle/); assert.match(t, /Kürsün boş duruyor/);
      await page.click('[data-kr="duzenle"]'); await page.waitForSelector('#krBio');
      await foto('duzenle');
      await page.click('[data-kapak="altin"]'); await page.fill('#krBio', 'Kurgusal biyografi'); await page.click('#krKaydet'); await page.waitForTimeout(200);
      assert.deepEqual((await son('kursu_profil_guncelle')).args, { p_bio: 'Kurgusal biyografi', p_kapak: 'altin', p_sabit: null });

      // 10) Eski Akış girişleri Kürsü'ye yönlenir; Gündem önizlemesi Kürsü kartıyla çizilir
      assert.equal(await page.evaluate(() => { const h = akisSatirHtml({ id: 77, kad: 'Ekin', metin: 'Önizleme #deneme', zaman: new Date().toISOString(), begeni: 0, begenmeme: 0, yanit: 0, parti: null }, 0); return /kr-g/.test(h) && /data-tepki="begen"/.test(h) && /data-yanitla="77"/.test(h) && /data-etk="deneme"/.test(h); }), true);
      await page.close();
    }
    const ilgili = hatalar.filter(m => !/ResizeObserver/.test(m));
    console.log('sayfa hataları (toplam):', ilgili.length, ilgili.join(' | '));
    assert.deepEqual(ilgili, []);
    console.log('kursu_arayuz: TAMAM');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
