// Öne çıkan giriş kartları: Gündem (TV Kanalları), Ekonomi (Ticaret Odası), Devlet › Hükümet (Valilik).
// Gerçek sekme ekranları sahte RPC ile çizilir; kartın yeri, duruma göre metni ve götürdüğü ekran doğrulanır.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/one_cikan_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const DURUMLAR = [
  { ad: 'canli_adaylik_vatandas',
    tv: { canli: 2, yakinda: 3, kanal: 4, ilk: { id: 31, baslik: 'Ekonomi düellosu: asgari ücret ne olmalı?', kanal: 'Başkent TV', tur_ad: 'Siyasi düello', sunucu: 'Selin', izleyici: 37 }, siradaki: null, davet: 0, teklif: 0 },
    oda: { il: 6, ad: 'Ankara Ticaret Odası', uye: 14, baskan: null, baskanim: false, sirketim: 3, oy_hakki: 3, oy_bekleyen: 0, aidat_borc: 0, aidat: 3000, secim: { durum: 'aday', oy_bas: S(40), oy_son: S(64), aday: 2, adayim: false }, birlik: null, birlik_baskan: null },
    vali: { durum: 'yok', il: null, cb: false, vali: 3, havuz: 5, bekleyen: 4 },
    bekle: { tv: ['Başkent TV', 'Ekonomi düellosu', '37 kişi izliyor', 'İzle', 'Canlı'], oda: ['Ankara Ticaret Odası', 'adaylık açık', 'Aday ol'], vali: ['Valilik', 'Sınavı geç, vali ol', '3 / 81', 'Başvur'] },
    tik: { tv: ['tv_detay', { p_program: 31 }], oda: ['oda_panel', { p_il: 6 }], vali: ['vali_durum', undefined] } },
  { ad: 'akis_oylama_cb',
    tv: { canli: 0, yakinda: 2, kanal: 4, ilk: null, siradaki: { id: 40, baslik: 'Cuma Akşamı Düellosu', kanal: 'Ege Haber', tur_ad: 'Siyasi düello', bas: S(30) }, davet: 0, teklif: 0 },
    oda: { il: 35, ad: 'İzmir Ticaret Odası', uye: 9, baskan: 'Ayşe', baskanim: false, sirketim: 2, oy_hakki: 2, oy_bekleyen: 2, aidat_borc: 0, aidat: 3000, secim: { durum: 'oy', oy_bas: S(-3), oy_son: S(21), aday: 3, adayim: false }, birlik: null, birlik_baskan: null },
    vali: { durum: 'yok', il: null, cb: true, vali: 3, havuz: 5, bekleyen: 4 },
    bekle: { tv: ['yayın akışı', 'Cuma Akşamı Düellosu', 'Ege Haber', 'Akış'], oda: ['İzmir Ticaret Odası', '2 oyun bekliyor', 'Oy ver'], vali: ['Cumhurbaşkanlığı', '4 aday atama bekliyor', 'Ata'] },
    tik: { tv: ['tv_liste', undefined], oda: ['oda_panel', { p_il: 35 }], vali: ['vali_durum', undefined] } },
  { ad: 'davet_borc_vali',
    tv: { canli: 0, yakinda: 0, kanal: 2, ilk: null, siradaki: null, davet: 1, teklif: 0 },
    oda: { il: 6, ad: 'Ankara Ticaret Odası', uye: 14, baskan: 'Mert', baskanim: false, sirketim: 1, oy_hakki: 0, oy_bekleyen: 0, aidat_borc: 6000, aidat: 3000, secim: null, birlik: null, birlik_baskan: null },
    vali: { durum: 'vali', il: 'Ankara', cb: false, vali: 4, havuz: 6, bekleyen: 2 },
    bekle: { tv: ['1 program davetin var', 'Yanıtla'], oda: ['Aidat borcun var', '6.000', 'Öde'], vali: ['Ankara Valisisin', 'Makamım'] },
    tik: { tv: ['tv_liste', undefined], oda: ['oda_panel', { p_il: 6 }], vali: ['vali_durum', undefined] } },
  { ad: 'bos_durum',
    tv: { canli: 0, yakinda: 0, kanal: 0, ilk: null, siradaki: null, davet: 0, teklif: 0 },
    oda: { il: 6, ad: 'Ankara Ticaret Odası', uye: 0, baskan: null, baskanim: false, sirketim: 0, oy_hakki: 0, oy_bekleyen: 0, aidat_borc: 0, aidat: 3000, secim: null, birlik: null, birlik_baskan: null },
    vali: { durum: 'sinav', il: null, cb: false, vali: 0, havuz: 0, bekleyen: 0 },
    bekle: { tv: ['TV Kanalları', 'İlk TV kanalını sen kur'], oda: ['Başkan henüz seçilmedi', 'şirket kurunca otomatik üye olursun'], vali: ['Valilik sınavın açık', 'Sınava gir'] },
    tik: { tv: ['tv_liste', undefined], oda: ['oda_panel', { p_il: 6 }], vali: ['vali_durum', undefined] } },
];
const SEKME = {
  tv: { id: 'tvGundemKart', ac: () => { D.sekme = 'gundem'; D.yigin = []; return EKRAN.gundem(); } },
  oda: { id: 'toEkonomiKart', ac: () => { D.sekme = 'ekonomi'; D.yigin = []; return window.ekonomiSekmeEkrani(); } },
  vali: { id: 'vlDevletKart', ac: () => { D.sekme = 'devlet'; D.devletSekme = 'hukumet'; D.yigin = []; return devletEkrani(); } },
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const d of DURUMLAR) {
    for (const gen of (d.ad === 'canli_adaylik_vatandas' ? [390, 320] : [390])) {
      const page = await browser.newPage({ viewport: { width: gen, height: gen === 320 ? 640 : 844 }, isMobile: true, locale: 'tr-TR' });
      page.on('pageerror', e => hatalar.push(d.ad + ': ' + e.message.slice(0, 200)));
      await page.route('**/*', r => {
        const u = new URL(r.request().url());
        if (u.hostname !== 'oyun.test') return r.abort();
        const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
        if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
        r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
      });
      await page.goto('http://oyun.test/index.html');
      await page.waitForFunction(() => window.SO_TV_KANALLARI_V1 && window.SO_VALILIK_V1 && window.SO_TICARET_ODASI_V1 && window.SO_ONE_CIKAN && typeof iskelet === 'function');
      await page.evaluate((v) => {
        window.calls = []; window.OZ = v;
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'tv_canli_ozet') return OZ.tv; if (ad === 'oda_ozet') return OZ.oda; if (ad === 'vali_ozet') return OZ.vali;
          // kartın götürdüğü ekranlar için en küçük geçerli yanıtlar
          if (ad === 'oda_panel') return { il: (args && args.p_il) || 6, ad: 'Ticaret Odası', ulusal: false, simdi: new Date().toISOString(), oda: { kasa: 0, aidat: 3000, baskan: null, uye: 0, borclu: 0, toplam_aidat: 0, toplam_harcama: 0 },
            benim: { baskan: false, temsilci: false, sirketler: [] }, secim: null, son_secim: null, icraatlar: [], bildiriler: [], imza: { sayi: 0, gereken: 1 }, uyeler: [], iller: [], sendikalar: [] };
          if (ad === 'vali_durum') return { simdi: new Date().toISOString(), harc: 25000, hesap_uygun: true, cb: false, siyasi_engel: null, gunluk_maas: 10000, akademi: null, sorular: [], havuz: null, gorevim: null, adaylar: [], valiler: [], iller: [], gecmis: [] };
          if (ad === 'tv_liste') return { simdi: new Date().toISOString(), kur_ucret: 250000, kanalim: null, sunuculuk: [], sunucu_teklif: [], davetlerim: [], canli: [], yakinda: [], biten: [], kanallar: [] };
          if (ad === 'tv_detay') return { id: args.p_program, kanal_id: 2, kanal: 'Başkent TV', tur: 'duello', tur_ad: 'Siyasi düello', baslik: 'Ekonomi düellosu', bas: new Date(Date.now() - 6e5).toISOString(), bit: new Date(Date.now() + 9e5).toISOString(),
            acik_uclu: false, durum: 'canli', sunucu: 'Selin', konuklar: [], izleyici: 37, reklam: 0, rolum: 'izleyici', kanal_sahibi: false, sunucu_kisi: { kad: 'Selin' }, izleyici_ucret: 500, konuk_liste: [], mesajlar: [],
            izleyiciler: { anlik: 37, toplam: 40, liste: [] }, alkis: 0, yuh: 0, tepkim: null, oyum: null, oy_acik: true, reklamlar: [], reklamlarim: [] };
          if (ad === 'durum') return { profil: { id: 'x', il_id: 6, il: 'Ankara', kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 840000, dolu: false, birikim: 0 }, statu: { ad: 'Vatandaş' } }, takvim: [], simdi: new Date().toISOString(), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
          if (/liste|lar$|ler$|listesi|durumlari|haklarim|firsatlari|^akis_gundem$|^kursu_akis$|^cimer$/.test(ad)) return [];
          if (/ilk_adimlar|meclis$|dernek_akis|secim_gecesi_aktif|gun_ozeti/.test(ad)) return null;
          return {};
        } };
        D.durum = { profil: { id: 'x', il_id: 6, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 840000, dolu: false } }, simdi: new Date().toISOString() };
        D.yigin = [];
        // test işlevleri doğrudan çağırır; gerçek kullanımda sekmeye dokunmak kullanıcı eylemidir
        setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
      }, { tv: d.tv, oda: d.oda, vali: d.vali });
      for (const k of ['tv', 'oda', 'vali']) {
        const s = SEKME[k];
        try { await page.evaluate(s.ac); } catch (_) { /* sahte veriyle sekmenin bazı alt bölümleri çizilemeyebilir; kart yine de yerleşmelidir */ }
        await page.waitForTimeout(1150);
        await page.evaluate(() => { try { if (document.querySelector('#modal') && typeof modalKapat === 'function') modalKapat(); } catch (_) {} });
        const kart = await page.evaluate((id) => {
          const el = document.getElementById(id); if (!el) return null; const r = el.getBoundingClientRect(), ic = document.getElementById('icerik');
          return { ust: Math.round(r.top + (ic ? ic.scrollTop : 0)), gen: Math.round(r.width), yuk: Math.round(r.height), metin: el.innerText.replace(/\s+/g, ' '), sayi: document.querySelectorAll('.oc-giris').length,
            canli: el.classList.contains('canli'), sayfa: document.documentElement.scrollWidth, ekran: window.innerWidth };
        }, s.id);
        const et = d.ad + ' / ' + k + ' / ' + gen + 'px';
        assert.ok(kart, et + ': kart yok');
        assert.equal(kart.sayi, 1, et + ': ekranda tek öne çıkan kart olmalı');
        assert.ok(kart.ust < 700, et + ': kart ilk ekranda olmalı (üst ' + kart.ust + ')');
        assert.ok(kart.gen >= gen - 40 && kart.sayfa <= kart.ekran + 1, et + ': genişlik/taşma ' + kart.gen + ' / ' + kart.sayfa);
        assert.ok(kart.yuk >= 72, et + ': kart en az 72 px yüksek olmalı (' + kart.yuk + ')');
        for (const b of d.bekle[k]) assert.ok(kart.metin.toLocaleLowerCase('tr-TR').includes(b.toLocaleLowerCase('tr-TR')), et + ': "' + b + '" yok → ' + kart.metin);
        if (k === 'tv') assert.equal(kart.canli, !!d.tv.ilk, et + ': canlı vurgusu');
        if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + d.ad + '_' + k + '_' + gen + '.png') }); }
        if (gen === 390) {
          const once = await page.evaluate(() => calls.length);
          await page.click('#' + s.id); await page.waitForTimeout(350);
          const [rpcAd, rpcArg] = d.tik[k];
          const c = await page.evaluate(({ once, rpcAd }) => calls.slice(once).filter(x => x.ad === rpcAd).pop(), { once, rpcAd });
          assert.ok(c, et + ': dokununca ' + rpcAd + ' çağrılmalı');
          if (rpcArg) assert.deepEqual(c.args, rpcArg, et + ': ' + rpcAd + ' argümanı');
        }
      }
      // Kart yalnız kendi sekmesinin ana ekranında: iç ekranlarda ve başka sekmelerde görünmez
      await page.evaluate(() => { D.sekme = 'ekonomi'; D.yigin = []; iskelet('Şirketlerim', '<div class="kart">iç ekran</div>', { geri: true }); });
      await page.waitForTimeout(700);
      assert.equal(await page.locator('.oc-giris').count(), 0, d.ad + ': iç ekranda kart olmamalı');
      await page.close();
    }
  }
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('Öne çıkan giriş kartları arayüz testi geçti (' + DURUMLAR.length + ' durum × 3 sekme, 390 ve 320 px)');
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
