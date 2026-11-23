// Ek İşler 2.0 arayüz testi: oyuncu ekranı (hak, sıralama, başlat/ücret al, sayaç), ana ekran şeridi, yönetici sekmesi.
// Gerçek ekranlar derlenmiş dist/index.html üzerinde sahte RPC ile çizilir; 390 ve 320 px'de taşma denetlenir.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/ek_isler_v2_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const shot = process.argv[2];
const ISLER = [['garson','Garsonluk','🍽️',55,750,'hizmet','Hizmet'],['kurye','Paket Kuryeliği','🚲',70,1000,'ulasim','Ulaşım'],['taksi','Taksi Şoförlüğü','🚕',90,1250,'ulasim','Ulaşım'],
  ['market','Market Çalışanı','🛒',60,850,'hizmet','Hizmet'],['guvenlik','Özel Güvenlik','🛡️',80,1100,'hizmet','Hizmet'],['insaat','İnşaat İşçiliği','🏗️',100,1400,'zanaat','Zanaat ve teknik'],
  ['oto_tamir','Oto Tamirciliği','🔧',125,1750,'zanaat','Zanaat ve teknik'],['elektrik','Elektrikçilik','💡',130,1800,'zanaat','Zanaat ve teknik'],['tesisat','Tesisatçılık','🚿',120,1650,'zanaat','Zanaat ve teknik'],
  ['fotograf','Fotoğrafçılık','📷',105,1500,'medya','Medya ve tasarım'],['ozel_ders','Özel Ders Öğretmenliği','📚',125,1750,'egitim_ofis','Eğitim ve ofis'],['muhasebe','Muhasebe Destek İşleri','🧾',145,2000,'egitim_ofis','Eğitim ve ofis'],
  ['yazilim','Yazılım Geliştirme','💻',180,2500,'teknoloji','Teknoloji'],['tasarim','Grafik Tasarım','🎨',120,1650,'medya','Medya ve tasarım'],['sosyal_medya','Sosyal Medya Yöneticiliği','📱',105,1500,'medya','Medya ve tasarım'],
  ['gazetecilik','Gazetecilik','📰',100,1400,'medya','Medya ve tasarım'],['organizasyon','Organizasyon Görevlisi','🎪',85,1200,'hizmet','Hizmet'],['tarim','Tarım İşçiliği','🌾',65,950,'tarim','Tarım'],
  ['asci','Aşçılık','🍳',95,1300,'hizmet','Hizmet'],['bilgisayar_servis','Bilgisayar Teknik Servisi','🖥️',135,1900,'teknoloji','Teknoloji']]
  .map(([kod, ad, simge, sure_dakika, u, kategori, kategori_ad], i) => ({ kod, ad, simge, aciklama: ad + ' işini tamamla ve ücretini al.', sure_dakika, asgari_ucret: u, azami_ucret: u, kategori, kategori_ad, min_kidem: 0, uygun: true, sira: i + 1, aktif: true, silindi: false, adet_7g: 3 * i, odenen_7g: 3 * i * u, gecmis_var: i % 2 === 0 }));
ISLER.push({ kod: 'tamirat', ad: 'Ev ve Cihaz Tamiri', simge: '🛠️', aciklama: 'Küçük bakım ve onarım işini bitir.', sure_dakika: 90, asgari_ucret: 950, azami_ucret: 1450, kategori: 'zanaat', kategori_ad: 'Zanaat ve teknik', min_kidem: 0, uygun: true, sira: 21, aktif: true, silindi: false, adet_7g: 30, odenen_7g: 36000, gecmis_var: true });

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const gen of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: gen, height: gen === 320 ? 640 : 844 }, isMobile: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(gen + ': ' + e.message.slice(0, 300)));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const f = path.join(KOK, decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname));
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => typeof window.ekIslerEkrani === 'function' && typeof window.ekIsSeridi === 'function' && window.SO_PREMIUM_ARAYUZ_V1 && typeof iskelet === 'function');
    await page.evaluate((ISLER) => {
      window.calls = [];
      const gece = () => { const t = Date.now() + 3 * 3600e3; return new Date((Math.floor(t / 86400e3) + 1) * 86400e3 - 3 * 3600e3).toISOString(); };
      window.S = { limit: 5, yapilan: 2, kazanilan: 1750, aktif: null, no: 10, isler: ISLER, yonetici: false,
        gecmis: [{ id: 2, ad: 'Paket Kuryeliği', simge: '🚲', ucret: 1000, odendi_at: new Date(Date.now() - 36e5).toISOString() }, { id: 1, ad: 'Garsonluk', simge: '🍽️', ucret: 750, odendi_at: new Date(Date.now() - 72e5).toISOString() }] };
      const panel = () => ({ gunluk_limit: S.limit, bugun_yapilan: S.yapilan, kalan: Math.max(0, S.limit - S.yapilan), bugun_kazanilan: S.kazanilan, simdi: new Date().toISOString(), sifirlanma: gece(), kidem: null,
        isler: S.isler.filter(x => x.aktif && !x.silindi), aktif: S.aktif ? Object.assign({}, S.aktif, { hazir: Date.now() >= new Date(S.aktif.bitis).getTime() }) : null, gecmis: S.gecmis });
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args });
        if (ad === 'vergi_rehberi') return { tanitim: true };          // ekonomi tanıtım penceresi testi bölmesin
        if (ad === 'ek_is_paneli') return panel();
        if (ad === 'ek_is_ozet') { const p = panel(); return { gunluk_limit: p.gunluk_limit, bugun_yapilan: p.bugun_yapilan, kalan: p.kalan, simdi: p.simdi, sifirlanma: p.sifirlanma, aktif: p.aktif }; }
        if (ad === 'ek_is_baslat') {
          const is = S.isler.find(x => x.kod === args.p_tur); let onceki = null;
          if (S.aktif && Date.now() < new Date(S.aktif.bitis).getTime()) throw new Error('Önce devam eden ek işinin süresinin dolmasını bekleyip ücretini al.');
          if (S.yapilan >= S.limit) throw new Error('Bugünkü ' + S.limit + ' ek iş hakkını doldurdun. Haklar Türkiye saatiyle 00.00\'da yenilenir.');
          if (S.aktif) { onceki = { id: S.aktif.id, ucret: S.aktif.ucret }; S.kazanilan += S.aktif.ucret; S.gecmis.unshift({ id: S.aktif.id, ad: S.aktif.ad, simge: S.aktif.simge, ucret: S.aktif.ucret, odendi_at: new Date().toISOString() }); }
          S.yapilan++; S.aktif = { id: ++S.no, tur: is.kod, ad: is.ad, simge: is.simge, baslama: new Date().toISOString(), bitis: new Date(Date.now() + is.sure_dakika * 60000).toISOString(), ucret: is.asgari_ucret };
          return { id: S.aktif.id, tur: is.kod, ad: is.ad, bitis: S.aktif.bitis, ucret: S.aktif.ucret, kalan: S.limit - S.yapilan, onceki_odeme: onceki };
        }
        if (ad === 'ek_is_ucret_al') { const a = S.aktif; if (!a || a.id !== args.p_id) throw new Error('Ek iş kaydı bulunamadı.'); S.aktif = null; S.kazanilan += a.ucret; S.gecmis.unshift({ id: a.id, ad: a.ad, simge: a.simge, ucret: a.ucret, odendi_at: new Date().toISOString() }); return { id: a.id, ucret: a.ucret }; }
        if (ad === 'yk_ek_is_liste') return { gunluk_limit: S.limit, bugun: { baslatilan: 368, oyuncu: 179, odenen: 334251 }, isler: S.isler,
          kategoriler: [['hizmet','Hizmet'],['ulasim','Ulaşım'],['zanaat','Zanaat ve teknik'],['egitim_ofis','Eğitim ve ofis'],['teknoloji','Teknoloji'],['medya','Medya ve tasarım'],['tarim','Tarım'],['diger','Diğer']].map(([kod, ad]) => ({ kod, ad })) };
        if (ad === 'yk_ek_is_ayar') { S.limit = args.p_gunluk_limit; return { tamam: true, gunluk_limit: S.limit }; }
        if (ad === 'yk_ek_is_kaydet') { let is = S.isler.find(x => x.kod === args.p_kod); if (!is) { is = { kod: 'yeni_is', kategori_ad: 'Hizmet', adet_7g: 0, odenen_7g: 0, gecmis_var: false, silindi: false, sira: 99 }; S.isler.push(is); }
          Object.assign(is, args.p_veri, { sure_dakika: Number(args.p_veri.sure_dakika), asgari_ucret: Number(args.p_veri.asgari_ucret), azami_ucret: Number(args.p_veri.azami_ucret) }); return { tamam: true, yeni: !args.p_kod, is }; }
        if (ad === 'yk_ek_is_sil') { const is = S.isler.find(x => x.kod === args.p_kod); if (is.gecmis_var) { is.silindi = true; is.aktif = false; return { tamam: true, kalici: false }; } S.isler = S.isler.filter(x => x !== is); return { tamam: true, kalici: true }; }
        if (ad === 'durum') return { profil: { id: 'x', il_id: 6, il: 'Ankara', kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 20921, dolu: false, birikim: 0 }, statu: { ad: 'Vatandaş' }, yetkiler: { liste: [], yonetici: S.yonetici } }, takvim: [], simdi: new Date().toISOString(), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/liste|lar$|ler$|listesi|durumlari|haklarim|firsatlari|^akis_gundem$|^kursu_akis$|^cimer$/.test(ad)) return [];
        if (/ilk_adimlar|meclis$|dernek_akis|secim_gecesi_aktif|gun_ozeti/.test(ad)) return null;
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 6, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 20921, dolu: false }, yetkiler: { liste: [], yonetici: false } }, takvim: [], simdi: new Date().toISOString() };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    }, ISLER);
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png'), fullPage: false }); } };
    const tasma = () => page.evaluate(() => ({ sayfa: document.documentElement.scrollWidth, ekran: window.innerWidth,
      tasan: [...document.querySelectorAll('#icerik *, #modal *')].filter(x => { const r = x.getBoundingClientRect(); return r.width > 0 && r.right > window.innerWidth + 1 && !x.closest('.ei-sirala') && !x.closest('.segment'); }).length }));
    const et = (m) => gen + 'px · ' + m;

    // ---- 1) Ana ekran: Ek İşler şeridi ilk ekranda, kalan hak görünür, dokununca Ek İşler açılır
    try { await page.evaluate(() => { D.sekme = 'gundem'; D.yigin = []; return EKRAN.gundem(); }); } catch (_) { /* sahte veriyle bazı alt bölümler çizilemeyebilir */ }
    await page.waitForTimeout(1300);
    await page.evaluate(() => { try { if (document.querySelector('#modal')) modalKapat(); } catch (_) {} });
    const serit = await page.evaluate(() => { const el = document.querySelector('[data-ek-is-serit]'); if (!el) return null; const r = el.getBoundingClientRect(); const ic = document.getElementById('icerik');
      return { ust: Math.round(r.top + (ic ? ic.scrollTop : 0)), gen: Math.round(r.width), yuk: Math.round(r.height), metin: el.innerText.replace(/\s+/g, ' '), sayi: document.querySelectorAll('[data-ek-is-serit]').length,
        hizli: document.querySelectorAll('[data-pa-hizli="gundem"] button').length }; });
    assert.ok(serit, et('ana ekranda Ek İşler şeridi yok'));
    assert.equal(serit.sayi, 1, et('ana ekranda tek şerit olmalı'));
    assert.equal(serit.hizli, 4, et('mevcut dört kısayol aynen durmalı'));
    assert.ok(serit.ust < 620, et('şerit ilk ekranda olmalı (üst ' + serit.ust + ')'));
    assert.ok(serit.yuk >= 56 && serit.gen >= gen - 40, et('şerit dokunma alanı ' + serit.gen + 'x' + serit.yuk));
    assert.ok(/Ek İşler/.test(serit.metin) && /3\/5/.test(serit.metin) && /3 iş hakkın var/.test(serit.metin), et('şerit metni: ' + serit.metin));
    let t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1, et('ana ekran yatay taşıyor'));
    await cek('ana_ekran');
    await page.click('[data-ek-is-serit]'); await page.waitForTimeout(500);

    // ---- 2) Ek İşler ekranı
    let e1 = await page.evaluate(() => ({ baslik: document.querySelector('.ust h1, #baslik') ? (document.querySelector('.ust h1') || document.querySelector('#baslik')).innerText : '', metin: document.getElementById('icerik').innerText,
      is: document.querySelectorAll('.ei-is').length, acik: document.querySelectorAll('.ei-basla:not([disabled])').length, hak: (document.querySelector('.ei-hakbas b') || {}).textContent,
      dolu: document.querySelectorAll('.ei-hak i:not(.ei-bos)').length, bos: document.querySelectorAll('.ei-hak i.ei-bos').length, ilk: document.querySelector('.ei-is .ei-m b').textContent,
      dugme: Math.min(...[...document.querySelectorAll('.ei-basla')].map(b => b.getBoundingClientRect().height)), cip: Math.min(...[...document.querySelectorAll('.ei-sirala button')].map(b => b.getBoundingClientRect().height)) }));
    assert.equal(e1.is, 21, et('21 iş listelenmeli')); assert.equal(e1.acik, 21, et('hak varken bütün işler başlatılabilir'));
    assert.equal(e1.hak, '3/5', et('Günlük Ek İş Hakkı 3/5')); assert.equal(e1.dolu, 3); assert.equal(e1.bos, 2);
    assert.equal(e1.ilk, 'Garsonluk', et('önerilen sırada ilk iş'));
    for (const b of ['Günlük Ek İş Hakkı', 'Bugün kazanılan', '1.750', 'Hakların yenilenmesine', '00.00', 'Tamamlanan işlerim', 'Paket Kuryeliği', '2.500', '3 sa', 'Teknoloji'])
      assert.ok(e1.metin.includes(b), et('ekranda "' + b + '" yok'));
    assert.ok(e1.dugme >= 44 && e1.cip >= 44, et('dokunma alanı en az 44 px (' + e1.dugme + ', ' + e1.cip + ')'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('Ek İşler ekranı taşıyor: ' + JSON.stringify(t)));
    await cek('ek_isler');

    // sıralama: sunucuya yeni istek gitmeden yeniden çizilir
    const once = await page.evaluate(() => calls.filter(c => c.ad === 'ek_is_paneli').length);
    await page.click('.ei-sirala button:nth-child(2)'); await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => document.querySelector('.ei-is .ei-m b').textContent), 'Yazılım Geliştirme', et('en çok kazanç'));
    await page.click('.ei-sirala button:nth-child(3)'); await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => document.querySelector('.ei-is .ei-m b').textContent), 'Garsonluk', et('en kısa süre'));
    await page.click('.ei-sirala button:nth-child(4)'); await page.waitForTimeout(150);
    const tur = await page.evaluate(() => [...document.querySelectorAll('.ei-grup')].map(x => x.textContent));
    assert.deepEqual(tur, ['Eğitim ve ofis', 'Hizmet', 'Medya ve tasarım', 'Tarım', 'Teknoloji', 'Ulaşım', 'Zanaat ve teknik'], et('meslek türüne göre gruplar'));
    await cek('ek_isler_tur');
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'ek_is_paneli').length), once, et('sıralama sunucuya istek atmamalı'));
    await page.click('.ei-sirala button:nth-child(1)'); await page.waitForTimeout(150);

    // ---- 3) İşe başla: onay penceresi → vazgeç (istek yok) → başla
    await page.click('.ei-is:nth-child(1) .ei-basla'); await page.waitForTimeout(250);
    const onay = await page.evaluate(() => document.querySelector('#modal') ? document.querySelector('#modal').innerText : '');
    assert.ok(/Garsonluk/.test(onay) && /55 dk/.test(onay) && /750/.test(onay) && /iptal edilmez/.test(onay), et('onay penceresi: ' + onay));
    t = await tasma(); assert.ok(t.tasan === 0, et('onay penceresi taşıyor'));
    await cek('onay');
    await page.click('#modal #hayir'); await page.waitForTimeout(200);
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'ek_is_baslat').length), 0, et('vazgeçince istek gitmemeli'));
    await page.click('.ei-is:nth-child(1) .ei-basla'); await page.waitForTimeout(200);
    await page.click('#modal #evet'); await page.waitForTimeout(500);
    const bas = await page.evaluate(() => calls.filter(c => c.ad === 'ek_is_baslat'));
    assert.equal(bas.length, 1); assert.deepEqual(bas[0].args, { p_tur: 'garson' });
    let e2 = await page.evaluate(() => ({ metin: document.getElementById('icerik').innerText, acik: document.querySelectorAll('.ei-basla:not([disabled])').length, hak: document.querySelector('.ei-hakbas b').textContent,
      sayac: (document.getElementById('eiSayac') || {}).textContent, etiket: document.querySelector('.ei-basla').textContent }));
    assert.equal(e2.hak, '2/5', et('iş başlayınca hak düşer')); assert.equal(e2.acik, 0, et('iş sürerken yeni iş başlatılamaz')); assert.equal(e2.etiket, 'Sürüyor');
    assert.ok(/Devam eden iş: Garsonluk/.test(e2.metin) && /5\d dk/.test(e2.sayac), et('devam eden iş ve geri sayım: ' + e2.sayac));
    const s1 = e2.sayac; await page.waitForTimeout(2200);
    assert.notEqual(await page.evaluate(() => document.getElementById('eiSayac').textContent), s1 + 'x', et('sayaç var'));
    await cek('suruyor');

    // ---- 4) İş bitti: ücret al (tek istek) ya da doğrudan yeni işe başla (önceki ücret yatar)
    await page.evaluate(() => { S.aktif.bitis = new Date(Date.now() - 1000).toISOString(); return ekIslerEkrani(true); }); await page.waitForTimeout(300);
    let e3 = await page.evaluate(() => ({ metin: document.getElementById('icerik').innerText, acik: document.querySelectorAll('.ei-basla:not([disabled])').length }));
    assert.ok(/İş bitti: Garsonluk/.test(e3.metin) && /Ücretimi al/.test(e3.metin), et('iş bitince ücret düğmesi'));
    assert.equal(e3.acik, 21, et('iş bitince yeni iş başlatılabilir'));
    await cek('bitti');
    await page.evaluate(() => { const id = S.aktif.id; ekIsUcretAl(id); ekIsUcretAl(id); }); await page.waitForTimeout(500);       // çift dokunma
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'ek_is_ucret_al').length), 1, et('çift dokunmada tek ödeme isteği'));
    assert.ok((await page.evaluate(() => document.getElementById('icerik').innerText)).includes('2.500'), et('bugün kazanılan 1.750 + 750 = 2.500'));
    // biten işi almadan yeni işe başla
    await page.evaluate(async () => { const o = window.onayla; window.onayla = async () => true; try { onayla = window.onayla; } catch (_) {} await ekIsBaslat('kurye'); S.aktif.bitis = new Date(Date.now() - 1000).toISOString(); await ekIsBaslat('taksi'); window.onayla = o; try { onayla = o; } catch (_) {} });
    await page.waitForTimeout(300);
    assert.equal(await page.evaluate(() => S.kazanilan), 3500, et('yeni iş başlarken önceki ücret yattı'));

    // ---- 5) Hak doldu: bütün düğmeler kapalı, sunucu reddi oyuncuya gösterilir
    await page.evaluate(() => { S.yapilan = 5; S.aktif = null; return ekIslerEkrani(true); }); await page.waitForTimeout(300);
    let e4 = await page.evaluate(() => ({ acik: document.querySelectorAll('.ei-basla:not([disabled])').length, hak: document.querySelector('.ei-hakbas b').textContent, etiket: document.querySelector('.ei-basla').textContent, metin: document.getElementById('icerik').innerText }));
    assert.equal(e4.hak, '0/5'); assert.equal(e4.acik, 0, et('hak dolunca hiçbir iş başlatılamaz')); assert.equal(e4.etiket, 'Hak doldu');
    assert.ok(/Bugünkü hakların doldu/.test(e4.metin), et('hak doldu açıklaması'));
    await cek('hak_doldu');
    await page.evaluate(async () => { const o = window.onayla; window.onayla = async () => true; try { onayla = window.onayla; } catch (_) {} await ekIsBaslat('garson'); window.onayla = o; try { onayla = o; } catch (_) {} });   // arayüz atlatılsa bile
    await page.waitForTimeout(250);
    assert.ok(/hakkını doldurdun/.test(await page.evaluate(() => [...document.querySelectorAll('.toast')].map(x => x.textContent).join(' | '))), et('sunucu reddi bildirilir'));

    // ---- 6) Yönetici sekmesi (yalnız oyunun sahibi)
    if (gen === 390) {
      const yok = await page.evaluate(async () => { kontrolMerkezi('ekis'); await new Promise(r => setTimeout(r, 400)); return document.querySelector('[data-km-sekme="ekis"]') ? 'var' : 'yok'; });
      assert.equal(yok, 'yok', 'oyuncuda Ek işler yönetim sekmesi görünmemeli');
    }
    await page.evaluate(() => { S.yonetici = true; S.yapilan = 2; D.durum.profil.yetkiler = { liste: [], yonetici: true }; D.yigin = []; });
    const sahip = await page.evaluate(() => { try { return !!yetkim().y.yonetici; } catch (e) { return 'hata: ' + e.message; } });
    assert.equal(sahip, true, 'test kurulumu: yönetici yetkisi okunamadı (' + sahip + ')');
    await page.evaluate(() => kontrolMerkezi('ekis')); await page.waitForTimeout(600);
    let y1 = await page.evaluate(() => ({ metin: document.getElementById('icerik').innerText, kart: document.querySelectorAll('[data-ekis]').length, limit: (document.getElementById('kmEkLimit') || {}).value,
      yazi: [...document.querySelectorAll('#kmIc input')].map(i => parseFloat(getComputedStyle(i).fontSize)) }));
    assert.equal(y1.kart, 21, et('yönetimde 21 meslek')); assert.equal(y1.limit, '5');
    for (const b of ['Günlük ek iş hakkı', 'Yeni meslek ekle', '368', '334.251', '12.500', 'Yazılım Geliştirme', 'Son 7 gün']) assert.ok(y1.metin.includes(b), et('yönetimde "' + b + '" yok'));
    assert.ok(y1.yazi.every(x => x >= 16), et('giriş alanları en az 16 px olmalı'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('yönetim sekmesi taşıyor: ' + JSON.stringify(t)));
    await cek('yonetim');
    await page.fill('#kmEkLimit', '6'); await page.click('#kmEkLimitK'); await page.waitForTimeout(400);
    assert.deepEqual(await page.evaluate(() => calls.filter(c => c.ad === 'yk_ek_is_ayar').pop().args), { p_gunluk_limit: 6 });
    await page.fill('#kmEkLimit', '40'); await page.click('#kmEkLimitK'); await page.waitForTimeout(200);
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'yk_ek_is_ayar').length), 1, et('geçersiz hak sunucuya gönderilmez'));
    // ücret/süre düzenle
    await page.click('[data-ekis="yazilim"]'); await page.waitForTimeout(250);
    const m1 = await page.evaluate(() => ({ ad: document.getElementById('kmEkAd').value, u: document.getElementById('kmEkAsgari').value, yazi: [...document.querySelectorAll('#modal input, #modal select, #modal textarea')].map(i => parseFloat(getComputedStyle(i).fontSize)),
      yuk: [...document.querySelectorAll('#modal .btn')].map(b => b.getBoundingClientRect().height) }));
    assert.equal(m1.ad, 'Yazılım Geliştirme'); assert.equal(m1.u, '2500');
    assert.ok(m1.yazi.every(x => x >= 16) && m1.yuk.every(x => x >= 44), et('düzenleme penceresi okunurluk: ' + JSON.stringify(m1)));
    t = await tasma(); assert.ok(t.tasan === 0, et('düzenleme penceresi taşıyor'));
    await cek('yonetim_duzenle');
    await page.fill('#kmEkAsgari', '3000'); await page.fill('#kmEkAzami', '3000'); await page.fill('#kmEkSure', '200'); await page.click('#kmEkK'); await page.waitForTimeout(400);
    const k1 = await page.evaluate(() => calls.filter(c => c.ad === 'yk_ek_is_kaydet').pop().args);
    assert.equal(k1.p_kod, 'yazilim'); assert.equal(k1.p_veri.asgari_ucret, '3000'); assert.equal(k1.p_veri.azami_ucret, '3000'); assert.equal(k1.p_veri.sure_dakika, '200'); assert.equal(k1.p_veri.aktif, true);
    assert.ok((await page.evaluate(() => document.getElementById('icerik').innerText)).includes('3.000 ₺ · 200 dk'), et('liste yeni ücreti göstermeli'));
    // yeni meslek
    await page.click('#kmEkYeni'); await page.waitForTimeout(250);
    await page.fill('#kmEkAd', 'Çiçekçilik'); await page.fill('#kmEkAcik', 'Buket hazırla ve teslim et.'); await page.fill('#kmEkSure', '40'); await page.fill('#kmEkAsgari', '600'); await page.fill('#kmEkAzami', '');
    await page.click('#kmEkK'); await page.waitForTimeout(400);
    const k2 = await page.evaluate(() => calls.filter(c => c.ad === 'yk_ek_is_kaydet').pop().args);
    assert.equal(k2.p_kod, null); assert.equal(k2.p_veri.ad, 'Çiçekçilik'); assert.equal(k2.p_veri.azami_ucret, '600', et('boş en yüksek ücret = en düşük ücret')); assert.ok(!('sira' in k2.p_veri));
    // pasifleştir + sil/arşiv
    await page.click('[data-ekis="kurye"]'); await page.waitForTimeout(250); await page.selectOption('#kmEkAktif', 'false'); await page.click('#kmEkK'); await page.waitForTimeout(400);
    assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'yk_ek_is_kaydet').pop().args.p_veri.aktif), false);
    await page.click('[data-ekis="garson"]'); await page.waitForTimeout(250); await page.click('#kmEkSil'); await page.waitForTimeout(250);
    assert.ok(/Arşive alınsın mı/.test(await page.evaluate(() => document.querySelector('#modal').innerText)), et('geçmişi olan meslek arşive alınır'));
    await page.click('#modal #evet'); await page.waitForTimeout(400);
    assert.deepEqual(await page.evaluate(() => calls.filter(c => c.ad === 'yk_ek_is_sil').pop().args), { p_kod: 'garson' });
    assert.ok((await page.evaluate(() => document.getElementById('icerik').innerText)).includes('Arşiv'), et('arşiv bölümü görünmeli'));
    await cek('yonetim_son');
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('Ek İşler 2.0 arayüz testleri başarılı (390 ve 320 px).');
})().catch(e => { console.error(e); process.exit(1); });
