// Alıntılı yanıt arayüz testi (sahte RPC; 390 ve 320 px): kanal sohbeti, grup, Genel Kurul (resmî kayıt) ve özel mesaj.
// Yanıtla (dokunma + sağa kaydırma), yanıt çubuğu, vazgeç, sohbet_yanitla / ozel_yanitla argümanları, alıntıya gitme,
// kaldırılmış mesaj bildirimi, eski mesajı yükleyip gitme, taşma.
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/mesaj_alinti_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
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
    await page.waitForFunction(() => window.sohbetTasarim && typeof sohbetTasarim.kanal === 'function' && typeof iskelet === 'function');
    await page.evaluate(() => {
      window.calls = [];
      const z = (dk) => new Date(Date.now() - dk * 60000).toISOString();
      const P = { ayse: { kisa: 'HP', ad: 'Halk Partisi', renk: '#d8425e' }, mert: { kisa: 'MKP', ad: 'Millî Kalkınma Partisi', renk: '#2e86de' } };
      // 60 eski mesaj (1..60) + son 6 mesaj; ilk okuma son 40'ı verir, yukarı kaydırınca öncekiler gelir
      window.K = [];
      for (let i = 1; i <= 60; i++) K.push({ id: i, kad: i % 2 ? 'Ayşe Yılmaz' : 'Mert Demir', metin: i === 7 ? 'Bütçe görüşmeleri pazartesi başlıyor, hazırlıklı gelin.' : 'Eski mesaj ' + i, zaman: z(600 - i), parti: i % 2 ? P.ayse : P.mert, unvan: 'İstanbul Milletvekili', benim: false, gorevli: false, yanit: null });
      K.push({ id: 101, kad: 'Ayşe Yılmaz', metin: 'Asgari ücret teklifini bu hafta Genel Kurul\'a getiriyoruz; desteğinizi bekliyorum.', zaman: z(30), parti: P.ayse, unvan: 'İstanbul Milletvekili', benim: false, gorevli: false, yanit: null });
      K.push({ id: 102, kad: 'Mert Demir', metin: 'Kaynağı ne olacak?', zaman: z(28), parti: P.mert, unvan: 'Ankara Milletvekili', benim: false, gorevli: false, yanit: { id: 101, kad: 'Ayşe Yılmaz', metin: 'Asgari ücret teklifini bu hafta Genel Kurul\'a getiriyoruz; desteğinizi bekliyorum.' } });
      K.push({ id: 103, kad: 'Deniz', metin: 'Ben de aynı soruyu soracaktım.', zaman: z(26), parti: null, unvan: null, benim: true, gorevli: false, yanit: { id: 102, kad: 'Mert Demir', metin: 'Kaynağı ne olacak?' } });
      K.push({ id: 104, kad: 'Ayşe Yılmaz', metin: 'Buna katılmıyorum.', zaman: z(20), parti: P.ayse, unvan: 'İstanbul Milletvekili', benim: false, gorevli: false, yanit: { id: 90, kad: '', metin: 'Bu mesaj kaldırıldı.' } });
      K.push({ id: 105, kad: 'Mert Demir', metin: 'Pazartesi için hazırız.', zaman: z(10), parti: P.mert, unvan: 'Ankara Milletvekili', benim: false, gorevli: false, yanit: { id: 7, kad: 'Ayşe Yılmaz', metin: 'Bütçe görüşmeleri pazartesi başlıyor, hazırlıklı gelin.' } });
      K.push({ id: 106, kad: 'Ayşe Yılmaz', metin: '👍', zaman: z(5), parti: P.ayse, unvan: 'İstanbul Milletvekili', benim: false, gorevli: false, yanit: null });
      window.OZ = [{ id: 501, metin: 'Yarınki grup toplantısına katılacak mısın?', zaman: z(40), benim: false, yanit: null },
        { id: 502, metin: 'Evet, 21.00\'de oradayım.', zaman: z(38), benim: true, yanit: { id: 501, kad: 'Ayşe Yılmaz', metin: 'Yarınki grup toplantısına katılacak mısın?' } }];
      window.no = 200;
      API = { rpc: async (ad, a) => {
        calls.push({ ad, a });
        if (ad === 'sohbet_oku') {
          let l = K.slice();
          if (a.p_sonra != null) l = l.filter(m => m.id > a.p_sonra).slice(0, 100);
          else if (a.p_once != null) l = l.filter(m => m.id < a.p_once).slice(-40);
          else l = l.slice(-40);
          return { kanal: a.p_kanal, baslik: a.p_kanal === 'meclis' ? 'Genel Kurul' : a.p_kanal === 'og:5' ? 'Dostlar Meclisi' : 'Genel Sohbet', mesajlar: l, yazabilir: !window.SALT_OKU, sinyal: 'sohbet:' + a.p_kanal, gorevli_yazabilir: false, resmi_yazabilir: false, kanal_kod: a.p_kanal };
        }
        if (ad === 'sohbet_yaz' || ad === 'sohbet_yanitla') {
          if (ad === 'sohbet_yanitla' && !K.some(m => m.id === a.p_yanit)) throw new Error('Alıntılamak istediğin mesaj bu sohbette bulunamadı (kaldırılmış olabilir).');
          const y = ad === 'sohbet_yanitla' ? K.find(m => m.id === a.p_yanit) : null;
          K.push({ id: ++no, kad: 'Deniz', metin: a.p_metin, zaman: new Date().toISOString(), parti: null, unvan: null, benim: true, gorevli: false, yanit: y ? { id: y.id, kad: y.benim ? 'Sen' : y.kad, metin: y.metin.slice(0, 160) } : null });
          return { tamam: true };
        }
        if (ad === 'ozel_oku') return { kad: a.p_kad, parti: null, unvan: 'İstanbul Milletvekili', mesajlar: a.p_sonra != null ? OZ.filter(m => m.id > a.p_sonra) : OZ.slice(), engelledim: false, aktif: 'cevrimici', okundu_son: 502 };
        if (ad === 'ozel_yaz' || ad === 'ozel_yanitla') { const y = ad === 'ozel_yanitla' ? OZ.find(m => m.id === a.p_yanit) : null;
          OZ.push({ id: ++no + 400, metin: a.p_metin, zaman: new Date().toISOString(), benim: true, yanit: y ? { id: y.id, kad: y.benim ? 'Sen' : 'Ayşe Yılmaz', metin: y.metin } : null }); return { tamam: true }; }
        if (ad === 'meclis_soz_durum') return { zaman: new Date().toISOString(), yazabilir: true, serbest: true, baskanlik: false, baskanlik_cevrimici: false, turler: [], soz: null, bekleyen: null, sira: null, sira_sayi: 0 };
        if (ad === 'vergi_rehberi') return { tanitim: true };
        if (ad === 'durum') return { profil: D.durum.profil, takvim: [], simdi: new Date().toISOString(), ulke: {}, okunmamis: { bildirim: 0, ozel: 0 } };
        if (/tepki/.test(ad)) return {};
        if (/liste|lar$|ler$|listesi|durumlari/.test(ad)) return [];
        return {};
      } };
      D.durum = { profil: { id: 'x', il_id: 34, kad: 'Deniz', parti: null, makamlar: [], cuzdan: { para: 1000, dolu: false }, yetkiler: { liste: [] } }, takvim: [], simdi: new Date().toISOString(), okunmamis: { bildirim: 0, ozel: 0 } };
      D.yigin = [];
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    });
    const et = (m) => gen + 'px · ' + m;
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + gen + '.png') }); } };
    const tasma = () => page.evaluate(() => ({ sayfa: document.documentElement.scrollWidth, ekran: window.innerWidth,
      tasan: [...document.querySelectorAll('#akis .shm *, #shYanitBar, #shYanitBar *, #modal *')].filter(x => { const r = x.getBoundingClientRect(); return r.width > 0 && (r.right > window.innerWidth + 1 || r.left < -1) && !x.closest('.sh-tp-sec'); }).length }));
    const son = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).pop(), ad);
    const say = (ad) => page.evaluate((ad) => calls.filter(c => c.ad === ad).length, ad);

    // ---- 1) Kanal: alıntılar görünür (ad + önizleme), kaldırılmış mesaj bildirimi
    await page.evaluate(() => ekranAc(() => sohbetTasarim.kanal('genel'))); await page.waitForTimeout(900);
    let a1 = await page.evaluate(() => ({ alinti: [...document.querySelectorAll('#akis .shm-yn')].map(x => ({ id: x.dataset.yanit, ad: (x.querySelector('b') || {}).textContent || '', metin: x.querySelector('span').textContent, yok: x.classList.contains('yok'), yuk: Math.round(x.getBoundingClientRect().height) })),
      mesaj: document.querySelectorAll('#akis .shm').length }));
    assert.equal(a1.mesaj, 40, et('ilk okuma 40 mesaj')); assert.equal(a1.alinti.length, 4, et('dört alıntılı mesaj'));
    assert.deepEqual(a1.alinti.map(x => x.id), ['101', '102', '90', '7']);
    assert.equal(a1.alinti[0].ad, 'Ayşe Yılmaz'); assert.ok(a1.alinti[0].metin.startsWith('Asgari ücret teklifini'), et('alıntı önizlemesi'));
    assert.ok(a1.alinti[2].yok && a1.alinti[2].ad === '' && a1.alinti[2].metin === 'Bu mesaj kaldırıldı.', et('kaldırılmış mesaj bildirimi'));
    assert.ok(a1.alinti.every(x => x.yuk >= 40), et('alıntı dokunma alanı en az 40 px: ' + a1.alinti.map(x => x.yuk)));
    let t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('kanal taşıyor: ' + JSON.stringify(t)));
    await cek('kanal');

    // ---- 2) Alıntıya dokun → asıl mesaja git ve vurgula
    await page.click('#akis .shm[data-id="102"] .shm-yn'); await page.waitForTimeout(700);
    let g1 = await page.evaluate(() => { const el = document.querySelector('#akis .shm[data-id="101"]'), r = el.getBoundingClientRect(), ak = document.getElementById('akis').getBoundingClientRect(); return { vurgu: el.classList.contains('shm-vurgu'), gorunur: r.top >= ak.top - 2 && r.bottom <= ak.bottom + 2, modal: !!document.querySelector('#modal') }; });
    assert.ok(g1.vurgu && g1.gorunur, et('asıl mesaja gidilip vurgulanmalı: ' + JSON.stringify(g1))); assert.equal(g1.modal, false, et('alıntıya dokunmak eylem sayfasını açmamalı'));
    // kaldırılmış mesajın alıntısı: bilgi verir, bir yere gitmez
    await page.click('#akis .shm[data-id="104"] .shm-yn'); await page.waitForTimeout(250);
    assert.ok(/artık görüntülenemiyor/.test(await page.evaluate(() => [...document.querySelectorAll('.toast')].map(x => x.textContent).join('|'))), et('kaldırılmış alıntı bildirimi'));
    // ekranda olmayan eski mesaj: önceki sayfa yüklenir, sonra gidilir
    const okuOnce = await say('sohbet_oku');
    await page.click('#akis .shm[data-id="105"] .shm-yn'); await page.waitForTimeout(1300);
    let g2 = await page.evaluate(() => { const el = document.querySelector('#akis .shm[data-id="7"]'); return { var: !!el, vurgu: !!el && el.classList.contains('shm-vurgu'), mesaj: document.querySelectorAll('#akis .shm').length }; });
    assert.ok(g2.var && g2.vurgu, et('eski mesaj yüklenip gidilmeli: ' + JSON.stringify(g2)));
    assert.ok(await say('sohbet_oku') > okuOnce, et('eski mesajlar sunucudan istenmeli'));

    // ---- 3) Dokun → eylem sayfasında Yanıtla → yanıt çubuğu → vazgeç
    await page.evaluate(() => { const ak = document.getElementById('akis'); ak.scrollTop = ak.scrollHeight; }); await page.waitForTimeout(250);
    await page.click('#akis .shm[data-id="101"] .shm-tx'); await page.waitForTimeout(300);
    let s1 = await page.evaluate(() => ({ ilk: (document.querySelector('#modal .sh-es') || {}).textContent, yuk: Math.round((document.querySelector('#modal [data-es="yanit"]') || document.body).getBoundingClientRect().height) }));
    assert.equal(s1.ilk, 'Yanıtla', et('eylem sayfasında ilk seçenek Yanıtla')); assert.ok(s1.yuk >= 44, et('Yanıtla dokunma alanı ' + s1.yuk));
    t = await tasma(); assert.ok(t.tasan === 0, et('eylem sayfası taşıyor'));
    await cek('eylem');
    await page.click('#modal [data-es="yanit"]'); await page.waitForTimeout(250);
    let b1 = await page.evaluate(() => { const b = document.getElementById('shYanitBar'); return b ? { metin: b.innerText.replace(/\s+/g, ' '), vaz: Math.round(document.getElementById('shYanitVaz').getBoundingClientRect().width), yazbarUstunde: b.getBoundingClientRect().bottom <= document.getElementById('yazbar').getBoundingClientRect().top + 1 } : null; });
    assert.ok(b1 && /Ayşe Yılmaz · yanıtlanıyor/.test(b1.metin) && /Asgari ücret teklifini/.test(b1.metin), et('yanıt çubuğu: ' + JSON.stringify(b1)));
    assert.ok(b1.vaz >= 44 && b1.yazbarUstunde, et('vazgeç düğmesi 44 px ve çubuk yazı alanının üstünde'));
    // yukarı kaydırılmışken çıkan "en yeni mesajlara in" düğmesi vazgeç düğmesini örtmemeli
    const ortu = await page.evaluate(() => { const ak = document.getElementById('akis'); ak.scrollTop = Math.max(0, ak.scrollHeight - ak.clientHeight - 600); ak.dispatchEvent(new Event('scroll'));
      return new Promise(r => setTimeout(() => { const a = document.getElementById('shkAsagi'), v = document.getElementById('shYanitVaz').getBoundingClientRect(); if (!a || a.hidden) return r('gizli'); const k = a.getBoundingClientRect();
        r(!(k.right < v.left || k.left > v.right || k.bottom < v.top || k.top > v.bottom) ? 'ortuyor' : 'acik'); }, 350)); });
    assert.notEqual(ortu, 'ortuyor', et('aşağı in düğmesi vazgeç düğmesini örtüyor'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('yanıt çubuğu taşıyor: ' + JSON.stringify(t)));
    await cek('yanit_cubugu');
    await page.evaluate(() => document.querySelectorAll('.toast').forEach(x => x.remove()));     // önceki adımların bildirimleri düğmeyi örtmesin
    await page.click('#shYanitVaz'); await page.waitForTimeout(150);
    assert.equal(await page.evaluate(() => !!document.getElementById('shYanitBar')), false, et('vazgeçince çubuk kalkar'));
    await page.fill('#yaz', 'Alıntısız mesaj'); await page.click('#gonder'); await page.waitForTimeout(500);
    assert.equal(await say('sohbet_yanitla'), 0, et('vazgeçilen yanıt alıntısız gider')); assert.deepEqual((await son('sohbet_yaz')).a, { p_kanal: 'genel', p_metin: 'Alıntısız mesaj' });

    // ---- 4) Sağa kaydırarak yanıtla → gönder → sohbet_yanitla; yeni mesajda alıntı görünür
    const kaydir = async (id, dx, dy) => {
      await page.evaluate((id) => document.querySelector('#akis .shm[data-id="' + id + '"]').scrollIntoView({ block: 'center' }), id); await page.waitForTimeout(150);
      const kutu = await page.evaluate((id) => { const r = document.querySelector('#akis .shm[data-id="' + id + '"] .shm-b, #akis .shm[data-id="' + id + '"] .shr-metin').getBoundingClientRect(); return { x: r.left + 20, y: r.top + r.height / 2 }; }, id);
      const c = await page.context().newCDPSession(page);
      const nokta = (x, y) => [{ x: Math.round(x), y: Math.round(y), id: 1 }];
      await c.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: nokta(kutu.x, kutu.y) });
      for (let i = 1; i <= 6; i++) await c.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: nokta(kutu.x + dx * i / 6, kutu.y + dy * i / 6) });
      await c.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await c.detach(); await page.waitForTimeout(300);
    };
    await kaydir(102, 20, 0);                       // kısa kaydırma: yanıt başlamaz
    assert.equal(await page.evaluate(() => !!document.getElementById('shYanitBar')), false, et('kısa kaydırma yanıt başlatmaz'));
    await kaydir(102, 6, 120);                      // dikey kaydırma: yanıt başlamaz
    assert.equal(await page.evaluate(() => !!document.getElementById('shYanitBar')), false, et('dikey kaydırma yanıt başlatmaz'));
    await page.evaluate(() => { const ak = document.getElementById('akis'); ak.scrollTop = ak.scrollHeight; }); await page.waitForTimeout(200);
    await kaydir(102, 90, 4);
    let b2 = await page.evaluate(() => ({ cubuk: (document.getElementById('shYanitBar') || {}).innerText || '', modal: !!document.querySelector('#modal'), kaymis: document.querySelector('#akis .shm[data-id="102"]').style.transform }));
    assert.ok(/Mert Demir · yanıtlanıyor/.test(b2.cubuk) && /Kaynağı ne olacak/.test(b2.cubuk), et('kaydırınca yanıt çubuğu: ' + b2.cubuk));
    assert.equal(b2.modal, false, et('kaydırma eylem sayfası açmamalı')); assert.equal(b2.kaymis, '', et('balon yerine döner'));
    await page.fill('#yaz', 'Kaynak bütçe fazlası olacak.'); await page.click('#gonder'); await page.waitForTimeout(600);
    assert.deepEqual((await son('sohbet_yanitla')).a, { p_kanal: 'genel', p_metin: 'Kaynak bütçe fazlası olacak.', p_yanit: 102 });
    let y1 = await page.evaluate(() => { const l = [...document.querySelectorAll('#akis .shm')].pop(); const q = l.querySelector('.shm-yn'); return { metin: l.querySelector('.shm-tx').textContent, alinti: q ? q.innerText.replace(/\s+/g, ' ') : null, cubuk: !!document.getElementById('shYanitBar'), benim: l.classList.contains('benim') }; });
    assert.ok(y1.benim && y1.metin === 'Kaynak bütçe fazlası olacak.' && /Mert Demir/.test(y1.alinti) && /Kaynağı ne olacak/.test(y1.alinti), et('gönderilen yanıtta alıntı: ' + JSON.stringify(y1)));
    assert.equal(y1.cubuk, false, et('gönderince çubuk kalkar'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('yanıt sonrası taşma: ' + JSON.stringify(t)));
    await cek('yanit_gonderildi');
    // kendi mesajına yanıt
    await page.click('#akis .shm[data-id="103"] .shm-tx'); await page.waitForTimeout(250); await page.click('#modal [data-es="yanit"]'); await page.waitForTimeout(200);
    assert.ok(/Kendi mesajına yanıt/.test(await page.evaluate(() => document.getElementById('shYanitBar').innerText)), et('kendi mesajına yanıt başlığı'));
    await page.evaluate(() => document.querySelectorAll('.toast').forEach(x => x.remove()));
    await page.click('#shYanitVaz');
    // sunucu reddi (mesaj bu arada kaldırılmış): hata gösterilir, mesaj "gönderilemedi" olarak kalır
    await page.click('#akis .shm[data-id="101"] .shm-tx'); await page.waitForTimeout(250); await page.click('#modal [data-es="yanit"]'); await page.waitForTimeout(200);
    await page.evaluate(() => { window.K = K.filter(m => m.id !== 101); });
    await page.fill('#yaz', 'Geç kalan yanıt'); await page.click('#gonder'); await page.waitForTimeout(500);
    assert.ok(/bu sohbette bulunamadı/.test(await page.evaluate(() => [...document.querySelectorAll('.toast')].map(x => x.textContent).join('|'))), et('sunucu reddi gösterilir'));
    assert.equal(await page.evaluate(() => [...document.querySelectorAll('#akis .shm')].pop().classList.contains('hata')), true, et('gönderilemeyen mesaj işaretlenir'));

    // ---- 5) Yalnız izleyebildiği kanal: Yanıtla yok, kaydırma çubuk açmaz; alıntılar yine okunur
    await page.evaluate(() => { window.SALT_OKU = true; D.yigin = []; return ekranAc(() => sohbetTasarim.kanal('genel')); }); await page.waitForTimeout(900);
    await page.click('#akis .shm[data-id="102"] .shm-tx'); await page.waitForTimeout(300);
    assert.equal(await page.evaluate(() => !!document.querySelector('#modal [data-es="yanit"]')), false, et('yazamadığı kanalda Yanıtla olmaz'));
    await page.evaluate(() => modalKapat()); await kaydir(102, 90, 0);
    assert.equal(await page.evaluate(() => !!document.getElementById('shYanitBar')), false, et('yazamadığı kanalda kaydırma yanıt açmaz'));
    assert.ok(await page.evaluate(() => document.querySelectorAll('#akis .shm-yn').length) >= 3, et('izleyici alıntıları okuyabilir'));
    await page.evaluate(() => { window.SALT_OKU = false; });

    // ---- 6) Genel Kurul (resmî kayıt görünümü) ve özel grup
    await page.evaluate(() => { D.yigin = []; return ekranAc(() => sohbetTasarim.kanal('meclis')); }); await page.waitForTimeout(1100);
    let m1 = await page.evaluate(() => ({ resmi: document.querySelectorAll('#akis .shm.shr').length, alinti: document.querySelectorAll('#akis .shm.shr .shm-yn').length }));
    assert.ok(m1.resmi > 10 && m1.alinti >= 3, et('Genel Kurul kaydında alıntılar: ' + JSON.stringify(m1)));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('Genel Kurul taşıyor: ' + JSON.stringify(t)));
    await cek('genel_kurul');
    await page.click('#akis .shm[data-id="102"] .shm-tx'); await page.waitForTimeout(300);
    if (await page.evaluate(() => !!document.querySelector('#modal [data-es="yanit"]'))) {
      await page.click('#modal [data-es="yanit"]'); await page.waitForTimeout(200);
      assert.ok(/Mert Demir/.test(await page.evaluate(() => (document.getElementById('shYanitBar') || {}).innerText || '')), et('Genel Kurul yanıt çubuğu'));
    } else await page.evaluate(() => modalKapat());
    await page.evaluate(() => { D.yigin = []; return ekranAc(() => sohbetTasarim.kanal('og:5')); }); await page.waitForTimeout(900);
    await kaydir(102, 90, 0);
    await page.fill('#yaz', 'Grupta yanıt'); await page.click('#gonder'); await page.waitForTimeout(500);
    assert.deepEqual((await son('sohbet_yanitla')).a, { p_kanal: 'og:5', p_metin: 'Grupta yanıt', p_yanit: 102 }, et('özel grupta yanıt'));

    // ---- 7) Özel mesaj
    await page.evaluate(() => { D.yigin = []; return ekranAc(() => sohbetTasarim.ozel('Ayşe Yılmaz')); }); await page.waitForTimeout(900);
    let o1 = await page.evaluate(() => [...document.querySelectorAll('#akis .shm-yn')].map(x => x.innerText.replace(/\s+/g, ' ')));
    assert.equal(o1.length, 1); assert.ok(/Ayşe Yılmaz/.test(o1[0]) && /grup toplantısına/.test(o1[0]), et('özel mesajda alıntı: ' + o1[0]));
    await kaydir(501, 90, 0);
    assert.ok(/yanıtlanıyor/.test(await page.evaluate(() => (document.getElementById('shYanitBar') || {}).innerText || '')), et('özel mesajda kaydırarak yanıt'));
    await cek('ozel');
    await page.fill('#yaz', 'Gündemi de konuşalım.'); await page.click('#gonder'); await page.waitForTimeout(600);
    assert.deepEqual((await son('ozel_yanitla')).a, { p_kad: 'Ayşe Yılmaz', p_metin: 'Gündemi de konuşalım.', p_yanit: 501 });
    await page.fill('#yaz', 'Düz mesaj'); await page.click('#gonder'); await page.waitForTimeout(500);
    assert.deepEqual((await son('ozel_yaz')).a, { p_kad: 'Ayşe Yılmaz', p_metin: 'Düz mesaj' }, et('alıntısız özel mesaj eski yoldan gider'));
    t = await tasma(); assert.ok(t.sayfa <= t.ekran + 1 && t.tasan === 0, et('özel mesaj taşıyor: ' + JSON.stringify(t)));
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('Alıntılı yanıt arayüz testleri başarılı (390 ve 320 px).');
})().catch(e => { console.error(e); process.exit(1); });
