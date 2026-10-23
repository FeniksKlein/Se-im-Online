// Bildirim merkezi arayüz testi (sahte RPC, ağ yok, canlıya bağlanmaz).
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/bildirim_merkezi_arayuz.js [ekran_klasörü]
// Denetlenenler: sınıflandırma, Dikkat isteyen kartı, filtre çipleri, gün başlıkları, "Gördüm",
// yayınlara dokunma işleyicisinin korunması, toast yığını, yeni süreli bildirim bandı,
// sunucuda bildirim_yeniler yoksa sessiz düşüş, 320/390 px, sayfa hatası.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../../docs/index.html');
const html = fs.readFileSync(htmlYol, 'utf8')
  .replace(/<script src="https:[^"]+"><\/script>/g, '')
  .replace(/<script src="([\w.-]+\.js)(?:\?[^"]*)?"><\/script>/g, (t, ad) => {
    const f = path.join(path.dirname(htmlYol), ad);
    return fs.existsSync(f) ? '<script>' + fs.readFileSync(f, 'utf8') + '</script>' : t;
  });
const klasor = process.argv[2] || null;
const veri = require('./veri/gorunum_ornek.js');

const SINIF = [
  ['Kriz masası: Çöp toplama krizi. 24 saat içinde karar ver (Yönetim › Belediye).', 'acil', 'yonetim'],
  ['Kriz masası: Çöp toplama krizi için 24 saatte karar vermedin. Belediye bütçesi zarar gördü.', 'ozel', 'yonetim'],
  ['Kura ile Adliye 12 istinaf jürisine seçildin. 6 saat içinde kararı onayla.', 'acil', 'adliye'],
  ['14 numaralı davada hakkınızda iddia var. Adliye\'den 12 saat içinde savunma yapın.', 'acil', 'adliye'],
  ['7 numaralı davada partiniz davalıdır. Savunma Adliye\'de.', 'acil', 'adliye'],
  ['Kredi taksitin ödenemedi: 1.200 ₺ gecikmede (2 gün). Cüzdanına ya da vadesiz hesabına para koy.', 'acil', 'banka'],
  ['Uzun süredir oyuna girmedin. Bir gün içinde girmezsen atandığın görevden alınırsın.', 'acil', null],
  ['Deniz seni Ulusal Parti (ULUSAL) partisinin kurucular kuruluna davet etti.', 'acil', 'parti'],
  ['Yeni yatırım ruhsatı başvurusu 31: kur_fabrika. Ruhsat Merkezi ekranından onayla ya da reddet.', 'acil', 'yonetim'],
  ['Kredini zamanında kapattın. Kredi notun yükseldi.', 'ozel', 'banka'],
  ['Kredin hesabina gecti: 5000 TL. Yarin itibaren her gece 250 TL taksit (20 gun).', 'ozel', 'banka'],
  ['Yeni başarım kazandın: Şehrin Başkanı', 'ozel', null],
  ['Tebrikler! Statün yükseldi: Saygın Vatandaş. Maaşın arttı.', 'ozel', null],
  ['ÖP Genel Başkanı seni genel başkan yardımcısı olarak atadı.', 'ozel', 'parti'],
  ['Partiye katıldığın için bağımsız milletvekili adaylığın düştü. Başvurun iptal edildi.', 'ozel', null],
  ['Adliye 9 kararı kesinleşti: beraat.', 'ozel', 'adliye'],
  ['Örnek Holding genel kuruluna önerge geldi: "5.000 ₺ temettü dağıtılması".', 'ozel', null],
  ['ÖP grup kararı: "Partilere Hazine Yardımı" için KABUL oyu.', 'meclis', 'meclis'],
  ['Yeni kanun teklifi: "Seçim Barajı düşürülmesi" (Ece). Oylama 24 10:00\'da başlıyor.', 'meclis', 'meclis'],
  ['TBMM Başkanlığı 2. tur oylaması 14:00 saatinde açılacak ve 30 dakika açık kalacak.', 'meclis', 'meclis'],
  ['TBMM Baskanligi ve parti grubu baskanvekilleri secimi acildi! Devlet > Meclis', 'meclis', 'meclis'],
  ['Oylama günü: Meclis\'te 3 teklif oyunu bekliyor.', 'meclis', 'meclis'],
  ['Parti tüzük oylaması sonuçlandı: KABUL — 12 Evet, 3 Hayır.', 'meclis', null],
  ['Cumhurbaşkanlığı kararı: Servet vergisi artık ‰5. Cüzdanında muafiyetin 100.000 ₺.', 'duyuru', null],
  ['Haftanın özeti yayımlandı: kanunlar, transferler, mitingler ve anket.', 'duyuru', null],
  ['Sponsorlu · aday01: Güç millette!', 'duyuru', null],
  ['Yüksek Mahkeme: 41 numaralı yeni dava dosyası açıldı.', 'duyuru', 'adliye'],
  ['Gençlik Derneği şu an İstanbul\'da protesto düzenliyor: "Barınma hakkı".', 'duyuru', null],
  // Canlı veride görülen kalıplardan (adlar değiştirildi)
  ['Ece şu an İstanbul meydanında: “Halk Mitingi”. Bir saat içinde Gündem\'den mitinge katılıp konuşmaları dinleyebilir, tepki verebilirsin.', 'duyuru', null],
  ['İstanbul mitingin başladı. Meydan seni bekliyor: Gündem\'den mitingine girip kürsüden konuş.', 'acil', 'gundem'],
  ['Örnek Holding genel kuruluna önerge geldi: "10.000 ₺ temettü dağıtılması" (Ece). 24 saat içinde oy ver.', 'ozel', null],
  ['Cumhurbaşkanı Ece sana Adalet Bakanlığı görevi teklif etti. Bildirimler bölümünden kabul edebilir veya reddedebilirsin.', 'acil', null],
  ['YP, partini Millet İttifakı ittifakına davet etti. Parti sayfasından yanıtlayabilirsin.', 'acil', 'parti'],
  ['Örnek Teknoloji zarar ediyor: kasada 2.200 ₺ kaldı. Fiyat/kaliteyi gözden geçir; yoksa iflas edebilir.', 'acil', null],
  ['CİMER: “Kadıköy” başvurun Cumhurbaşkanlığı tarafından yanıtlandı (olumlu).', 'ozel', null],
  ['Parti sözcülüğü göreviniz sona erdi. Yeni davalarda parti adına temsil yetkiniz bulunmuyor.', 'ozel', 'adliye'],
  ['Cumhurbaşkanı Yardımcısı Ece: NATO Zirvesi Öncesi Kulis (#2). Yanıtını Devlet > Hükümet bölümünden ver.', 'acil', 'devlet'],
  ['İstanbul Belediyesi kur_fabrika ruhsat başvurunu onayladı.', 'ozel', null],
  ['Ece partimizden ayrıldı (İstanbul milletvekilliği).', 'meclis', null],
  ['Sirketiniz İstanbul Belediyesi hizmet ihalesini kazandi. 72 saat icinde teslim etmeniz gerekiyor.', 'acil', null],
  ['Ece basın toplantısı düzenliyor: "Bütçe hakkında". Gazeteci olarak 30 dakika içinde soru sorabilirsin.', 'duyuru', null],
  ['Türk Gelişim Partisi genel başkanı parti ideolojilerini oylamaya sundu. 48 saat içinde oyunu kullan.', 'acil', null],
  ['ÖP kasasından 50.000 ₺ harcandı: Ece üyesine kampanya desteği. Kasa defteri herkese açık.', 'duyuru', null],
  ['Ece paylaşımına yanıt verdi: Tebrikler!', 'ozel', null],
  ['Uzun süredir oyuna girmedin. İki gün içinde girmezsen seçildiğin görevden düşeceksin ve olağanüstü seçim yapılacak.', 'acil', null],
  ['3 gündür oyuna girmediğin için genel başkan yardımcılığın sona erdi.', 'ozel', null],
  ['Cumhurbaşkanı seni Adalet Bakanlığı görevinden aldı.', 'ozel', null]
];

const saat = 36e5, gun = 864e5, simdi = Date.now();
const iso = (ms) => new Date(simdi - ms).toISOString();
const kutu = [
  { tur: 'kisisel', id: 901, zaman: iso(0.2 * saat), metin: SINIF[0][0], yeni: true },
  { tur: 'kisisel', id: 900, zaman: iso(0.5 * saat), metin: SINIF[17][0], yeni: true },
  { tur: 'yayin', id: 77, yayin_tur: 'aday', zaman: iso(0.7 * saat), metin: 'İzmir için çalışmaya devam! Oyunuzu bekliyoruz.', kad: 'Ece', unvan: 'Milletvekili adayı', parti: { id: 4, ad: 'Yeni Parti', kisa: 'YP', renk: '#E0A030' }, benim: false, yeni: true },
  { tur: 'kisisel', id: 899, zaman: iso(1 * saat), metin: SINIF[18][0], yeni: true },
  { tur: 'kisisel', id: 898, zaman: iso(1.5 * saat), metin: SINIF[23][0], yeni: true },
  { tur: 'kisisel', id: 897, zaman: iso(2 * saat), metin: SINIF[2][0], yeni: true },
  { tur: 'kisisel', id: 896, zaman: iso(3 * saat), metin: SINIF[11][0], yeni: false },
  { tur: 'kisisel', id: 895, zaman: iso(1 * gun + 2 * saat), metin: SINIF[5][0], yeni: false },
  { tur: 'kisisel', id: 894, zaman: iso(1 * gun + 3 * saat), metin: SINIF[24][0], yeni: false },
  { tur: 'yayin', id: 76, yayin_tur: 'parti', zaman: iso(1 * gun + 4 * saat), metin: 'Parti genelgesi: hafta sonu il kongreleri.', kad: 'Ada', unvan: 'Genel Başkan', parti: veri.profil.parti, benim: true, yeni: false },
  { tur: 'kisisel', id: 893, zaman: iso(1 * gun + 5 * saat), metin: SINIF[19][0], yeni: false },
  { tur: 'kisisel', id: 892, zaman: iso(4 * gun), metin: SINIF[3][0], yeni: false } // eski: Dikkat kartına girmez
];

(async () => {
  // 1) Sınıflandırma (tarayıcı dışı değil: modülün kendisi sayfada çalışır)
  const browser = await chromium.launch({ headless: true });
  const sonuc = [];
  for (const W of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: W, height: 844 }, isMobile: true, deviceScaleFactor: 2, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
    const hatalar = []; page.on('pageerror', e => hatalar.push(e.message));
    // Gerçek bir köken (localStorage için); başka hiçbir istek dışarı çıkmaz.
    await page.route('**/*', r => r.request().url() === 'http://oyun.test/' ? r.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: html }) : r.abort());
    await page.goto('http://oyun.test/');
    await page.waitForTimeout(300);
    if (W === 390) {
      const sinif = await page.evaluate((S) => S.map(([m]) => window.bmKategori(m)), SINIF);
      SINIF.forEach(([m, kat, rota], i) => {
        assert.strictEqual(sinif[i].kat, kat, `Sınıf yanlış: "${m}" → ${sinif[i].kat}, beklenen ${kat}`);
        assert.strictEqual(sinif[i].rota, rota, `Rota yanlış: "${m}" → ${sinif[i].rota}, beklenen ${rota}`);
      });
      sonuc.push(`sınıflandırma: ${SINIF.length} örnek doğru`);
    }
    await page.evaluate(({ v, kutu, yeniler }) => {
      window.PROFIL = v.profil;
      window.__cagri = [];
      window.__rozet = { bildirim: 0, ozel: 0, sohbet: 0 };
      window.__yeniler = yeniler;
      window.__yenilerYok = false;
      API = { rpc: async (ad, arg) => {
        window.__cagri.push(ad);
        if (ad === 'durum') return { simdi: new Date().toISOString(), profil: PROFIL, okunmamis: window.__rozet, ...v.durum };
        if (ad === 'bildirim_kutusu') return JSON.parse(JSON.stringify(kutu));
        if (ad === 'bildirim_yeniler') { if (window.__yenilerYok) throw new Error('Could not find the function public.bildirim_yeniler(p_limit) in the schema cache'); return window.__yeniler; }
        if (ad === 'rozetler') return window.__rozet;
        if (['yayin_haklari', 'bakan_tekliflerim', 'cb_yardimcisi_tekliflerim'].includes(ad)) return [];
        if (ad === 'bildirim_hedefleri') return {};
        if (ad === 'bildirim_yayin_ozet') return null;
        return v.rpc[ad] ?? null;
      } };
      D.durum = { profil: PROFIL, okunmamis: window.__rozet, ...v.durum };
      try { localStorage.clear(); } catch (_) {}
    }, { v: veri, kutu, yeniler: [
      { id: 1001, zaman: new Date(Date.now() - 6e4).toISOString(), metin: 'Kriz masası: Ana isale hattı patladı. 24 saat içinde karar ver (Yönetim › Belediye).' },
      { id: 1000, zaman: new Date(Date.now() - 12e4).toISOString(), metin: 'İTH grup kararı: "Devlet Tahvili Kanunu" için RET oyu.' },
      { id: 999, zaman: new Date(Date.now() - 18e4).toISOString(), metin: '14 numaralı davada hakkınızda iddia var. Adliye\'den 12 saat içinde savunma yapın.' },
      { id: 998, zaman: new Date(Date.now() - 5 * 864e5).toISOString(), metin: 'Kriz masası: Sağanak ve sel. 24 saat içinde karar ver (Yönetim › Belediye).' }
    ] });

    // 2) Bildirimler ekranı
    await page.evaluate(() => sekmeAc('hayat'));
    await page.waitForTimeout(500);
    await page.evaluate(() => ekranAc(bildirimEkrani));
    await page.waitForTimeout(500);
    const ekran = await page.evaluate(() => ({
      baslik: document.querySelector('.ust h1')?.textContent,
      dikkat: document.querySelectorAll('#bmDikkat .bm-d-oge').length,
      dikkatMetin: [...document.querySelectorAll('#bmDikkat .bm-d-metin')].map(x => x.textContent),
      cipler: [...document.querySelectorAll('.bm-cip')].map(x => x.textContent.replace(/\s+/g, ' ').trim()),
      gunler: [...document.querySelectorAll('.bm-gun')].map(x => x.textContent),
      ogeler: document.querySelectorAll('.bm-liste > .kisisel, .bm-liste > .yayin').length,
      acilListe: document.querySelectorAll('.bm-liste .kisisel.bm-k-acil').length,
      gitDugme: [...document.querySelectorAll('#bmDikkat .bm-dugme:not(.sade)')].map(x => x.textContent.trim()),
      disarida: document.querySelectorAll('#icerik > .kisisel, #icerik > .yayin').length,
      yatay: document.documentElement.scrollWidth > window.innerWidth + 1
    }));
    assert.strictEqual(ekran.baslik, 'Bildirimler');
    assert.strictEqual(ekran.ogeler, kutu.length, 'Tüm öğeler listeye taşınmalı');
    assert.strictEqual(ekran.disarida, 0, 'Liste dışında öğe kalmamalı');
    assert.strictEqual(ekran.dikkat, 3, 'Son 3 günün 3 süreli bildirimi Dikkat kartında olmalı: ' + JSON.stringify(ekran.dikkatMetin));
    assert.ok(!ekran.dikkatMetin.some(m => m.includes('14 numaralı')), '4 günlük bildirim Dikkat kartına girmemeli');
    assert.strictEqual(ekran.acilListe, 4, 'Listede 4 süreli bildirim kırmızı işaretli olmalı');
    assert.ok(ekran.gunler[0] === 'Bugün' && ekran.gunler.includes('Dün'), JSON.stringify(ekran.gunler));
    assert.ok(ekran.cipler[0].startsWith('Tümü'), ekran.cipler.join(' | '));
    assert.ok(ekran.cipler.some(c => c.includes('Yayınlar')) && ekran.cipler.some(c => c.includes('Meclis ve parti')), ekran.cipler.join(' | '));
    assert.ok(ekran.gitDugme.includes('Yönetime git ›') && ekran.gitDugme.includes("Adliye'ye git ›") && ekran.gitDugme.includes('Bankaya git ›'), ekran.gitDugme.join(','));
    assert.ok(!ekran.yatay, 'Yatay kaydırma olmamalı');
    if (klasor) await page.screenshot({ path: path.join(klasor, `bm_kutu_${W}.png`) });

    // 3) Filtre: Meclis ve parti
    await page.click('.bm-cip[data-f="meclis"]');
    const meclis = await page.evaluate(() => ({
      gorunen: [...document.querySelectorAll('.bm-liste > .kisisel, .bm-liste > .yayin')].map(n => n.className),
      kayit: localStorage.getItem('bm_filtre_v1')
    }));
    assert.ok(meclis.gorunen.length === 3 && meclis.gorunen.every(c => c.includes('bm-k-meclis')), JSON.stringify(meclis.gorunen));
    assert.strictEqual(meclis.kayit, '"meclis"');
    if (klasor) await page.screenshot({ path: path.join(klasor, `bm_meclis_${W}.png`) });
    await page.click('.bm-cip[data-f="yayin"]');
    // Yayın öğesinin kendi dokunma işleyicisi taşındıktan sonra da çalışır (mesaj menüsü açılır)
    await page.click('.bm-liste .yayin:not([data-benim="1"])');
    await page.waitForTimeout(200);
    const menu = await page.evaluate(() => !!document.getElementById('modal'));
    assert.ok(menu, 'Yayına dokununca mesaj menüsü açılmalı');
    await page.evaluate(() => modalKapat());
    await page.click('.bm-cip[data-f="tumu"]');

    // 4) Gördüm: karttan kalkar, kayıtlı kalır, ekran yenilenince geri gelmez
    await page.click('#bmDikkat [data-gordum="901"]');
    let kalan = await page.evaluate(() => document.querySelectorAll('#bmDikkat .bm-d-oge').length);
    assert.strictEqual(kalan, 2);
    await page.evaluate(() => bildirimEkrani());
    await page.waitForTimeout(400);
    kalan = await page.evaluate(() => document.querySelectorAll('#bmDikkat .bm-d-oge').length);
    assert.strictEqual(kalan, 2, '"Gördüm" denen bildirim yeniden açılışta kartta olmamalı');
    sonuc.push(`${W}px: Bildirimler ekranı, filtre, yayın menüsü, Gördüm`);

    // 5) Toast yığını: en fazla 3, hata mesajı başarı mesajıyla silinmez
    await page.evaluate(() => sekmeAc('hayat'));
    await page.waitForTimeout(300);
    await page.evaluate(() => { document.querySelectorAll('#bmTostYigin .toast').forEach(t => t.remove()); toast('Miting tamamlandı.'); toast('Bakiye yetersiz.', true); toast('Bağış gönderildi.'); toast('Yayın gönderildi.'); toast('Yayın gönderildi.'); });
    await page.waitForTimeout(250);
    const tost = await page.evaluate(() => [...document.querySelectorAll('#bmTostYigin .toast:not(.bm-cik)')].map(t => (t.classList.contains('hata') ? 'H:' : '') + t.textContent));
    assert.deepStrictEqual(tost, ['H:Bakiye yetersiz.', 'Bağış gönderildi.', 'Yayın gönderildi.'], JSON.stringify(tost));
    if (klasor) await page.screenshot({ path: path.join(klasor, `bm_toast_${W}.png`) });
    await page.waitForTimeout(3000);
    const tost2 = await page.evaluate(() => [...document.querySelectorAll('#bmTostYigin .toast:not(.bm-cik)')].map(t => t.textContent));
    assert.deepStrictEqual(tost2, ['Bakiye yetersiz.'], 'Başarı mesajları 2,6 sn sonra kalkar, hata 5 sn kalır: ' + JSON.stringify(tost2));
    sonuc.push(`${W}px: toast yığını`);

    // 6) Bant: rozet sayısı artınca yalnız yeni ve son 2 günün süreli bildirimleri için çıkar
    await page.evaluate(() => { window.__rozet = { bildirim: 3, ozel: 0, sohbet: 0 }; rozetGuncelle(window.__rozet); });
    await page.waitForTimeout(400);
    const bant = await page.evaluate(() => {
      const b = document.getElementById('bmBant');
      return b && { metin: b.querySelector('p').textContent, alt: b.querySelector('.bm-b-alt .kucuk').textContent, dugmeler: [...b.querySelectorAll('.bm-dugme')].map(x => x.textContent.trim()) };
    });
    assert.ok(bant, 'Bant çıkmalı');
    assert.ok(bant.metin.includes('Ana isale'), bant.metin);
    assert.strictEqual(bant.alt, '+1 süreli bildirim daha');
    assert.deepStrictEqual(bant.dugmeler, ['Yönetime git', 'Bildirimleri aç']);
    if (klasor) await page.screenshot({ path: path.join(klasor, `bm_bant_${W}.png`) });
    // Aynı bildirimler için ikinci kez bant çıkmaz
    await page.click('#bmBant .bm-b-kapat');
    await page.evaluate(() => { window.__rozet = { bildirim: 4, ozel: 0, sohbet: 0 }; rozetGuncelle(window.__rozet); });
    await page.waitForTimeout(300);
    assert.ok(!(await page.$('#bmBant')), 'Aynı bildirim için bant tekrar çıkmamalı');
    // Bildirimleri aç → bant kapanır, ekran açılır
    await page.evaluate(() => { window.__yeniler = [{ id: 1002, zaman: new Date().toISOString(), metin: 'Kredi taksitin ödenemedi: 900 ₺ gecikmede (1 gün).' }]; window.__rozet = { bildirim: 5, ozel: 0, sohbet: 0 }; rozetGuncelle(window.__rozet); });
    await page.waitForTimeout(300);
    await page.click('#bmBant [data-ac]');
    await page.waitForTimeout(400);
    const sonra = await page.evaluate(() => ({ bant: !!document.getElementById('bmBant'), baslik: document.querySelector('.ust h1')?.textContent }));
    assert.deepStrictEqual(sonra, { bant: false, baslik: 'Bildirimler' });
    // Sunucuda fonksiyon yoksa: hata atmadan bant devre dışı kalır
    await page.evaluate(() => { window.__yenilerYok = true; sekmeAc('hayat'); window.__rozet = { bildirim: 0 }; rozetGuncelle(window.__rozet); window.__rozet = { bildirim: 2 }; rozetGuncelle(window.__rozet); });
    await page.waitForTimeout(300);
    assert.ok(!(await page.$('#bmBant')));
    sonuc.push(`${W}px: bant, tekrar etmeme, eski sunucuda sessiz düşüş`);

    const ilgili = hatalar.filter(h => /bm|bildirim|toast|rozet/i.test(h));
    assert.deepStrictEqual(ilgili, [], 'Sayfa hatası: ' + ilgili.join(' | '));
    if (hatalar.length) sonuc.push(`${W}px: modül dışı önceden var olan sayfa uyarıları: ${[...new Set(hatalar)].length}`);
    await page.close();
  }
  await browser.close();
  console.log(sonuc.join('\n') + '\nTAMAM');
})().catch(e => { console.error('HATA:', e.message); process.exit(1); });
