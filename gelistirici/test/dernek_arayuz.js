// Dernekler arayüz testi (sahte RPC, ağ yok, canlıya bağlanmaz).
// Çalıştır: HTML_PATH=gelistirici/dist/index.html NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/dernek_arayuz.js [ekran_klasörü]
// Denetlenenler: ana sayfa (künye, sekmeler, Derneklerim / Keşfet / Sokak / Yardım), arama ve alan süzgeci,
// tekrar eden liste olmaması, dernek sayfası (künye, yönetim masası, sekmeler, diğer bölümler),
// eski enjekte kartların görünmemesi, 320/390 px yatay taşma, sayfa hatası.
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
const ESKI = process.env.ESKI === '1'; // değişiklik öncesi derlemenin ekran görüntüsü için (denetimler atlanır)
const veri = require('./veri/gorunum_ornek.js');

const saat = 36e5, gun = 864e5, simdi = Date.now();
const iso = (ms) => new Date(simdi + ms).toISOString();
const D_LISTE = [
  [1, 'Atatürkçü Düşünme Ve İlerici Hareket Derneği', 'genel', 'Genel', 'İstanbul', 'TuranRiver', 8, 81, true],
  [2, 'Cumhuriyetçi Halk Hareketi', 'genel', 'Genel', 'Giresun', 'mustafaozdm', 8, 6, true],
  [3, 'Türk Gençlik Teşkilatı', 'genclik', 'Gençlik', 'Ankara', 'Sadıközerçağlar77', 7, 81, true],
  [4, 'Sosyal Demokrasi Vakfı', 'genel', 'Genel', 'İstanbul', 'ArvenTora', 5, 8, true],
  [5, 'Ege Doğa Derneği', 'cevre', 'Çevre', 'İzmir', 'Ada', 4, 3, true],
  [6, 'Önce Hürriyet Derneği', 'hak', 'İnsan Hakları', 'Tunceli', 'halilmutlu', 3, 2, false],
  [7, 'Anadolu Esnaf Birliği', 'esnaf', 'Esnaf ve Meslek', 'Konya', 'Kerem', 3, 4, false],
  [8, 'Kadın Emeği Platformu', 'kadin', 'Kadın', 'İzmir', 'Selin', 3, 2, false],
  [9, 'Patili Dostlar', 'hayvan', 'Hayvan Hakları', 'Eskişehir', 'mert_a', 2, 1, false],
  [10, 'Emek ve Adalet Sendikası', 'emek', 'Emek ve Sendika', 'Kocaeli', 'Barış', 2, 3, false],
  [11, 'Kent Hakkı Derneği', 'yerel', 'Kent ve Yerel', 'Bursa', 'Deniz', 2, 1, false],
  [12, 'Bilim ve Eğitim Vakfı', 'egitim', 'Eğitim', 'Ankara', 'Ece', 2, 2, false],
  [13, 'Kültür Sanat Atölyesi', 'kultur', 'Kültür ve Sanat', 'Antalya', 'Zeynep', 1, 1, false],
  [14, 'Özgür Düşünceler', 'genel', 'Genel', 'Adana', 'ak1n', 1, 1, false],
  [15, 'Karadeniz Çevre Gönüllüleri', 'cevre', 'Çevre', 'Trabzon', 'Oğuz', 1, 1, false],
  [16, 'Genç Girişimciler', 'genclik', 'Gençlik', 'İstanbul', 'Can', 1, 1, false]
].map(([id, ad, alan, alan_ad, merkez, baskan, uye, sube, uyesiyim]) => ({ id, ad, alan, alan_ad, merkez, baskan, uye, sube, uyesiyim }));
const dj = (id) => { const d = D_LISTE.find(x => x.id === id); return { id: d.id, ad: d.ad }; };
const eylem = (o) => Object.assign({ hedef_tur: 'genel', hedef_id: null, hedef_ad: null, il: null, il_id: null, bas: null, bit: null, yazan: 'Ada',
  canli: false, bitti: false, katilim: null, katildim: false, benim_ilim: false }, o);
const AKIS = {
  protestolar: [
    eylem({ id: 41, dernek: dj(3), tur: 'protesto', baslik: 'Gençlere barınma hakkı', metin: 'Yurt fiyatları el yakıyor. Kızılay meydanında buluşuyoruz.', il: 'İzmir', il_id: 35, bas: iso(-20 * 60e3), bit: iso(40 * 60e3), canli: true, katilim: 23, benim_ilim: true }),
    eylem({ id: 42, dernek: dj(5), tur: 'protesto', baslik: 'Kordon\'a beton dökülmesin', metin: 'Kıyı imarına karşı Gündoğdu\'dayız.', il: 'İzmir', il_id: 35, bas: iso(5 * saat), bit: iso(6 * saat), katilim: 0, benim_ilim: true }),
    eylem({ id: 43, dernek: dj(10), tur: 'protesto', baslik: 'Asgari ücret insanca yaşamaya yetsin', metin: 'Fabrika önünde basın açıklaması ve yürüyüş.', il: 'Kocaeli', il_id: 41, bas: iso(26 * saat), bit: iso(27 * saat), katilim: 0 })
  ],
  aciklamalar: [
    eylem({ id: 31, dernek: dj(14), tur: 'bildiri', baslik: 'Özgür Düşünce Derneği', metin: 'Türkiye\'de, özgür düşünceyi yaymak ve bu uğurda çalışmalar yapacağımızı haykırmaya başlıyoruz. Her vatandaşın "Bugün tutuklanır mıyım?, şunu desem birşey olur mu?" gibi kaygılardan arındığı bir Türkiye\'de yaşamak için var gücümüzle gerek sahada gerek sosyal medyada gücümüzü kullanacağız.', zaman: iso(-2 * saat) }),
    eylem({ id: 32, dernek: dj(4), tur: 'destek', baslik: 'Adayımız belli: Ece', metin: 'Vakfımız İzmir milletvekili adayı Ece\'yi destekliyor.', hedef_tur: 'oyuncu', hedef_ad: 'Ece', zaman: iso(-5 * saat) }),
    eylem({ id: 33, dernek: dj(1), tur: 'basin', baslik: 'Cumhuriyetin 103. yılında', metin: 'Cumhuriyetimizin kuruluş yıl dönümünü kutluyor, bütün yurttaşlarımızı törenlere davet ediyoruz.', zaman: iso(-26 * saat) }),
    eylem({ id: 34, dernek: dj(10), tur: 'basin', baslik: 'Vergi paketine itiraz', metin: 'Yeni vergi düzenlemesi emekçinin sırtına yük bindiriyor. Meclis\'i paketi geri çekmeye çağırıyoruz.', hedef_tur: 'kanun', hedef_id: '12', hedef_ad: 'Vergi Usul Kanunu', zaman: iso(-50 * saat) })
  ]
};
const detay = (id, rol) => {
  const d = D_LISTE.find(x => x.id === id);
  const uyeler = [{ kad: d.baskan, il: d.merkez, rol: 'baskan' }, { kad: 'Selin', il: 'İzmir', rol: 'yonetim' }, { kad: 'Mert', il: 'Bursa', rol: 'uye' }, { kad: 'Deniz', il: 'Ankara', rol: 'uye' }].slice(0, Math.max(1, d.uye));
  if (rol && !uyeler.some(u => u.kad === 'Ada')) uyeler.push({ kad: 'Ada', il: 'İzmir', rol });
  const iller = ['İzmir', 'Manisa', 'Aydın', 'Muğla', 'Denizli', 'İstanbul', 'Ankara', 'Bursa'];
  return {
    id: d.id, ad: d.ad, alan: d.alan, alan_ad: d.alan_ad, amac: id === 14 ? 'Özgür düşüncenin Türkiye\'de bağımsız bir şekilde ifade edilebilmesini savunan oluşum.' : 'Kıyılarımızı, ormanlarımızı ve zeytinliklerimizi korumak; kent ve doğa arasında yaşanabilir bir denge kurmak için çalışırız. Fidan dikimi, kıyı temizliği ve bilgilendirme toplantıları düzenleriz.',
    kapali: false, kurulus: '2026-10-11T09:00:00Z', kurucu: d.baskan, baskan: d.baskan, merkez: d.merkez, merkez_il: 35,
    kasa: rol ? 184250 : null, rolum: rol || null, yetkili: rol === 'baskan' || rol === 'yonetim', harc: 25000,
    uyeler, subeler: Array.from({ length: Math.min(d.sube, iller.length) }, (_, i) => ({ il_id: 35 + i, il: i === 0 ? d.merkez : iller[i], merkez: i === 0 })),
    sube_ucretleri: { 1: 1000, 2: 2000, 3: 3000 },
    hareketler: rol === 'baskan' ? [{ zaman: iso(-3 * saat), tutar: 5000, aciklama: 'Selin bağış yaptı' }, { zaman: iso(-28 * saat), tutar: -2000, aciklama: 'Manisa şubesi açıldı' }, { zaman: iso(-50 * saat), tutar: 25000, aciklama: 'Kuruluş bağışı' }] : null,
    eylemler: id === 14 ? [AKIS.aciklamalar[0]] : [AKIS.protestolar[1], eylem({ id: 51, dernek: dj(id), tur: 'basin', baslik: 'Zeytinliklere maden ruhsatı verilmesin', metin: 'Zeytinlik alanlarda madencilik faaliyetine izin veren düzenleme geri çekilmelidir. Yasal süreci sonuna kadar takip edeceğiz.', zaman: iso(-30 * saat) }),
      eylem({ id: 52, dernek: dj(id), tur: 'protesto', baslik: 'Körfez temizlensin', metin: 'Körfezdeki kirliliğe dikkat çekmek için buluştuk.', il: 'İzmir', il_id: 35, bas: iso(-4 * gun), bit: iso(-4 * gun + saat), bitti: true, katilim: 17 })]
  };
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const sonuc = [];
  for (const W of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: W, height: 844 }, isMobile: true, deviceScaleFactor: 2, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
    const hatalar = []; page.on('pageerror', e => { hatalar.push(e.message); if (process.env.YIGIN) console.log(e.stack); });
    await page.route('**/*', r => r.request().url() === 'http://oyun.test/' ? r.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: html }) : r.abort());
    await page.goto('http://oyun.test/');
    await page.waitForTimeout(300);
    await page.evaluate(({ v, liste, akis, detaylar }) => {
      window.PROFIL = v.profil; window.__cagri = [];
      API = { rpc: async (ad, arg) => {
        window.__cagri.push([ad, arg]);
        if (ad === 'durum') return { simdi: new Date().toISOString(), profil: PROFIL, okunmamis: { bildirim: 0, ozel: 0, sohbet: 0 } };
        if (ad === 'dernekler') return JSON.parse(JSON.stringify(liste));
        if (ad === 'dernek_akis') return JSON.parse(JSON.stringify(akis));
        if (ad === 'dernek_detay') return JSON.parse(JSON.stringify(detaylar[arg.p_dernek] || detaylar[14]));
        if (ad === 'dernek_kampanya_vitrin') return [
          { id: 7, dernek: 'Ege Doğa Derneği', dernek_id: 5, tur: 'agac', baslik: 'Muğla Hatıra Ormanı', hedef: 50000, toplanan: 31500, bitis: new Date(Date.now() + 3 * 864e5).toISOString() },
          { id: 8, dernek: 'Patili Dostlar', dernek_id: 9, tur: 'hayvan', baslik: 'Kışa hazırlık: barınak ve mama', hedef: 20000, toplanan: 4200, bitis: new Date(Date.now() + 20 * 36e5).toISOString() }];
        if (ad === 'dernek_ziyaret_taleplerim') return [{ id: 3, dernek: 'Kadın Emeği Platformu', dernek_id: 8, parti: 'Örnek Parti', parti_id: 3, konu: 'Kreş ve eşit ücret taleplerimizi görüşmek istiyoruz.', tarih: new Date(Date.now() + 2 * 864e5).toISOString(), durum: 'bekliyor' }];
        if (ad === 'dernek_eylem_oku') return JSON.parse(JSON.stringify(akis.aciklamalar.find(x => x.id === arg.p_eylem) || null));
        if (ad === 'dernek_kampanya_bagis') { window.__bagis = arg; return { tamam: true }; }
        if (ad === 'kimlikler') return {};
        if (ad === 'rozetler') return { bildirim: 0, ozel: 0, sohbet: 0 };
        return v.rpc[ad] ?? null;
      } };
      D.durum = { profil: PROFIL, okunmamis: { bildirim: 0, ozel: 0, sohbet: 0 } };
      try { sessionStorage.clear(); localStorage.clear(); } catch (_) {}
    }, { v: veri, liste: D_LISTE, akis: AKIS, detaylar: { 5: detay(5, 'baskan'), 14: detay(14, null), 3: detay(3, 'uye') } });

    const durum = () => page.evaluate(() => ({
      baslik: document.querySelector('.ust h1')?.textContent,
      yatay: document.documentElement.scrollWidth > window.innerWidth + 1 || [...document.querySelectorAll('#icerik *')].some(el => { const r = el.getBoundingClientRect(); return r.width && r.right > window.innerWidth + 1 && getComputedStyle(el).position !== 'fixed' && !el.closest('.dv-yatay'); }),
      metin: document.getElementById('icerik')?.innerText || ''
    }));
    const foto = async (ad, tam) => { if (klasor) await page.screenshot({ path: path.join(klasor, `${ESKI ? 'eski_' : ''}${ad}_${W}.png`), fullPage: !!tam }); };
    const tamFoto = async (ad) => {
      if (!klasor) return;
      const h = await page.evaluate(() => { const ic = document.getElementById('icerik'); return ic ? ic.scrollHeight + 200 : 844; });
      await page.setViewportSize({ width: W, height: Math.min(6000, Math.max(844, h)) });
      await page.waitForTimeout(150);
      await page.screenshot({ path: path.join(klasor, `${ESKI ? 'eski_' : ''}${ad}_${W}_tam.png`) });
      await page.setViewportSize({ width: W, height: 844 });
      await page.waitForTimeout(100);
    };

    // 1) Ana sayfa
    await page.evaluate(() => sekmeAc('dernek'));
    await page.waitForTimeout(700);
    await foto('dernek_ana'); await tamFoto('dernek_ana');
    if (ESKI) {
      await page.evaluate(() => ekranAc(() => stkDetay(14))); await page.waitForTimeout(500); await tamFoto('dernek_detay14');
      await page.evaluate(() => ekranAc(() => stkDetay(5))); await page.waitForTimeout(500); await tamFoto('dernek_detay5');
      await page.close(); continue;
    }
    let s = await durum();
    assert.strictEqual(s.baslik, 'Dernekler');
    const ana = await page.evaluate(() => ({
      hero: document.querySelectorAll('#icerik [data-pa-hero]').length,
      sekmeler: [...document.querySelectorAll('#icerik .dv-sekme button')].map(b => b.textContent.replace(/\s+/g, ' ').trim()),
      aktif: document.querySelector('#icerik .dv-sekme button.aktif')?.dataset.s,
      satir: document.querySelectorAll('#icerik [data-dv-dernek]').length,
      eskiKart: [...document.querySelectorAll('#icerik > .kart:not(.pa-gizli)')].map(x => x.textContent.slice(0, 40)),
      gorunenEski: [...document.querySelectorAll('#icerik .kart')].filter(x => x.offsetParent && /Sosyal etki ve yardım merkezi/.test(x.textContent)).length
    }));
    assert.strictEqual(ana.hero, 1, 'Tek künye kartı olmalı');
    assert.deepStrictEqual(ana.sekmeler.map(x => x.replace(/\s*\d+$/, '')), ['Derneklerim', 'Keşfet', 'Sokak', 'Yardım'], ana.sekmeler.join('|'));
    assert.strictEqual(ana.aktif, 'benim', 'Üyeliği olan oyuncu Derneklerim ile başlar');
    assert.strictEqual(ana.satir, 5, 'Derneklerim: 5 dernek');
    assert.strictEqual(ana.gorunenEski, 0, 'Eski "Sosyal etki" kartı görünmemeli');
    assert.ok(!s.yatay, 'Yatay taşma (ana)');
    sonuc.push('ana sayfa: künye + 4 sekme, Derneklerim 5');

    // 2) Keşfet: 16 dernek, tekrar yok, arama ve alan süzgeci
    await page.click('#icerik .dv-sekme button[data-s="kesfet"]');
    await page.waitForTimeout(200);
    await foto('dernek_kesfet'); await tamFoto('dernek_kesfet');
    let k = await page.evaluate(() => ({ n: document.querySelectorAll('#icerik [data-dv-dernek]').length, adlar: [...document.querySelectorAll('#icerik [data-dv-dernek] .dv-ad')].map(x => x.textContent) }));
    assert.strictEqual(k.n, 16); assert.strictEqual(new Set(k.adlar).size, 16, 'Keşfet listesinde tekrar olmamalı');
    await page.fill('#dvAra', 'çevre');
    await page.waitForTimeout(100);
    k = await page.evaluate(() => [...document.querySelectorAll('#icerik [data-dv-dernek]')].filter(x => !x.hidden).length);
    assert.strictEqual(k, 2, 'Arama "çevre": 2 dernek (alan adı da aranır)');
    await page.fill('#dvAra', '');
    await page.click('#icerik .dv-alanlar button[data-alan="genclik"]');
    await page.waitForTimeout(100);
    k = await page.evaluate(() => [...document.querySelectorAll('#icerik [data-dv-dernek]')].filter(x => !x.hidden).length);
    assert.strictEqual(k, 2, 'Gençlik süzgeci: 2 dernek');
    await foto('dernek_kesfet_genclik');
    s = await durum(); assert.ok(!s.yatay, 'Yatay taşma (keşfet)');
    sonuc.push('keşfet: 16 dernek, arama ve alan süzgeci');

    // Kaydırınca sekme çubuğu üstte yapışık kalır; sekme değişince yeni içerik çubuğun altından başlar
    await page.click('#icerik .dv-alanlar button[data-alan="tumu"]');
    await page.evaluate(() => { document.getElementById('icerik').scrollTop = 1400; });
    await page.waitForTimeout(100);
    const yap = await page.evaluate(() => { const ic = document.getElementById('icerik').getBoundingClientRect().top, sk = document.querySelector('#icerik .dv-sekme').getBoundingClientRect().top; return Math.abs(sk - ic); });
    assert.ok(yap < 2, 'Sekme çubuğu yapışık olmalı: ' + yap);
    // 3) Sokak
    await page.click('#icerik .dv-sekme button[data-s="sokak"]');
    await page.waitForTimeout(100);
    const ust = await page.evaluate(() => { const ic = document.getElementById('icerik'), g = document.getElementById('dvGovde').getBoundingClientRect().top - ic.getBoundingClientRect().top; return g; });
    assert.ok(ust > 0 && ust < 120, 'Sekme değişince içerik başı görünür olmalı: ' + ust);
    await page.waitForTimeout(200);
    await foto('dernek_sokak'); await tamFoto('dernek_sokak');
    const sok = await page.evaluate(() => ({ canli: document.querySelectorAll('#icerik .dv-eylem.canli').length, katil: !!document.querySelector('#icerik .dv-eylem.canli button[onclick*="stkProtestoKatil"]'), aciklama: document.querySelectorAll('#icerik .dv-akis [data-dv-eylem]').length }));
    assert.strictEqual(sok.canli, 1); assert.ok(sok.katil, 'Canlı protestoya katıl düğmesi'); assert.ok(sok.aciklama >= 4, 'Son açıklamalar listesi');
    s = await durum(); assert.ok(!s.yatay, 'Yatay taşma (sokak)');
    sonuc.push('sokak: canlı protesto + açıklamalar');

    // 4) Yardım (ziyaret talebi + kampanyalar, istekle yüklenir)
    await page.click('#icerik .dv-sekme button[data-s="yardim"]');
    await page.waitForTimeout(400);
    await foto('dernek_yardim'); await tamFoto('dernek_yardim');
    const yar = await page.evaluate(() => ({ kamp: document.querySelectorAll('#icerik .dv-kampanya').length, ziyaret: document.querySelectorAll('#icerik .dv-ziyaret').length }));
    assert.strictEqual(yar.kamp, 2); assert.strictEqual(yar.ziyaret, 1);
    s = await durum(); assert.ok(!s.yatay, 'Yatay taşma (yardım)');
    sonuc.push('yardım: 2 kampanya, 1 ziyaret talebi');

    // 5) Dernek sayfası (üye değil)
    await page.evaluate(() => ekranAc(() => stkDetay(14)));
    await page.waitForTimeout(600);
    await foto('dernek_detay14'); await tamFoto('dernek_detay14');
    let dt = await page.evaluate(() => ({
      baslik: document.querySelector('.ust h1')?.textContent,
      uyeOl: !!document.querySelector('#icerik button[onclick^="stkKatil("]'),
      bagis: !!document.querySelector('#icerik button[onclick^="stkBagisModal("]'),
      masa: !!document.querySelector('#icerik .dv-masa'),
      eskiFaaliyet: [...document.querySelectorAll('#icerik .kart')].filter(x => x.offsetParent && /Dernek faaliyetleri ve üyelik destekleri/.test(x.textContent)).length,
      eskiGenel: [...document.querySelectorAll('#icerik .sos-menu-karti')].filter(x => x.offsetParent).length,
      kasa: document.querySelector('#icerik .dv-istat')?.textContent || ''
    }));
    assert.ok(dt.uyeOl && dt.bagis, 'Üye ol + Bağış yap'); assert.ok(!dt.masa, 'Üye olmayana yönetim masası yok');
    assert.strictEqual(dt.eskiFaaliyet, 0, 'Eski faaliyet kartı tekrarlanmamalı'); assert.strictEqual(dt.eskiGenel, 0, 'Eski genel kurul kartı tekrarlanmamalı');
    assert.ok(/Gizli/.test(dt.kasa), 'Gizli kasa "Gizli" yazar: ' + dt.kasa);
    s = await durum(); assert.ok(!s.yatay, 'Yatay taşma (detay 14)');
    sonuc.push('dernek sayfası (ziyaretçi)');

    // 6) Başkanın dernek sayfası: yönetim masası + sekmeler
    await page.evaluate(() => ekranAc(() => stkDetay(5)));
    await page.waitForTimeout(600);
    await foto('dernek_detay5'); await tamFoto('dernek_detay5');
    dt = await page.evaluate(() => ({
      masa: [...document.querySelectorAll('#icerik .dv-masa button')].map(b => b.textContent.trim()),
      sekmeler: [...document.querySelectorAll('#icerik .dv-dsekme button')].map(b => b.dataset.s),
      baglar: [...document.querySelectorAll('#icerik .dv-bag')].map(b => b.querySelector('b')?.textContent)
    }));
    assert.ok(dt.masa.length >= 4, 'Yönetim masası: ' + dt.masa.join('|'));
    assert.deepStrictEqual(dt.sekmeler, ['akis', 'uyeler', 'subeler', 'kasa']);
    assert.ok(dt.baglar.includes('Sosyal faaliyetler') && dt.baglar.includes('Genel kurul ve seçimler'), dt.baglar.join('|'));
    for (const t of ['uyeler', 'subeler', 'kasa']) {
      await page.click(`#icerik .dv-dsekme button[data-s="${t}"]`);
      await page.waitForTimeout(150);
      await foto('dernek_detay5_' + t); await tamFoto('dernek_detay5_' + t);
      s = await durum(); assert.ok(!s.yatay, 'Yatay taşma (detay 5 ' + t + ')');
    }
    await page.click('#icerik .dv-dsekme button[data-s="akis"]');
    sonuc.push('dernek sayfası (başkan): yönetim masası, 4 sekme');

    // 7) Bildirimden açılan tek yayın sayfası
    await page.evaluate(() => ekranAc(() => stkYayinGoster(31)));
    await page.waitForTimeout(400);
    await foto('dernek_yayin');
    const yy = await page.evaluate(() => ({ b: document.querySelector('#icerik .dv-makale h2')?.textContent, kim: !!document.querySelector('#icerik .dv-makale-kim') }));
    assert.strictEqual(yy.b, 'Özgür Düşünce Derneği'); assert.ok(yy.kim, 'Yayın sayfasında dernek bağlantısı');
    s = await durum(); assert.ok(!s.yatay, 'Yatay taşma (yayın)');
    // 8) Menüden açılan Yardım kampanyaları ekranı + bağış penceresi
    await page.evaluate(() => ekranAc(stkSosyalVitrin));
    await page.waitForTimeout(400);
    await foto('dernek_sosyal');
    assert.strictEqual(await page.evaluate(() => document.querySelectorAll('#icerik #dvYardimTek .dv-kampanya').length), 2);
    await page.click('#icerik .dv-kampanya button.birincil');
    await page.waitForTimeout(150);
    await foto('dernek_bagis_modal');
    await page.click('#modal [data-v="5000"]');
    await page.click('#dvBagisTamam');
    await page.waitForTimeout(300);
    assert.deepStrictEqual(await page.evaluate(() => window.__bagis), { p_kampanya: 7, p_tutar: 5000 });
    sonuc.push('tek yayın + yardım ekranı + kampanya bağışı');
    // 9) Hiçbir derneğe üye olmayan oyuncu Keşfet ile başlar
    await page.evaluate(() => { window.__eskiRpc = API.rpc; const asil = API.rpc; API.rpc = async (ad, arg) => { const r = await asil(ad, arg); if (ad === 'dernekler') r.forEach(x => { x.uyesiyim = false; x.baskan = x.baskan === 'Ada' ? 'Ece' : x.baskan; }); return r; }; try { sessionStorage.clear(); } catch (_) {} });
    await page.evaluate(() => sekmeAc('dernek'));
    await page.waitForTimeout(500);
    await page.click('#icerik .dv-sekme button[data-s="benim"]');
    await page.waitForTimeout(150);
    await foto('dernek_bos_benim');
    assert.ok(await page.evaluate(() => !!document.querySelector('#icerik .dv-cagri[onclick="stkKurModal()"]')), 'Üye olmayana "Dernek kur" çağrısı');
    await page.evaluate(() => { API.rpc = window.__eskiRpc; });
    sonuc.push('üyeliği olmayan oyuncu: boş durum + dernek kur');

    assert.deepStrictEqual(hatalar, [], 'Sayfa hatası: ' + hatalar.join(' | '));
    await page.close();
  }
  await browser.close();
  console.log(ESKI ? 'Eski ekranlar kaydedildi.' : 'TAMAM\n- ' + sonuc.join('\n- '));
})().catch(err => { console.error('HATA:', err.message); process.exit(1); });
