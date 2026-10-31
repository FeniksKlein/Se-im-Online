// Siyaset Arenası arayüz testi (31.10.2026). Ağ yok; sahte RPC.
// node gelistirici/build/derle.js && NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/siyaset_arenasi_arayuz.js [ekran-klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const KOK = process.env.KOK_DIZIN || path.join(__dirname, '../dist');
const YEDEK = path.join(__dirname, '../../docs');
const shot = process.argv[2];
const S = (h) => new Date(Date.now() + h * 3600e3).toISOString();

const OTURUM = { acik: true, bas: S(-0.3), bit: S(0.7), gun: '2026-10-31', vekil: true, yoklamada: false, vekil_sayisi: 35,
  katilan: [{ kad: 'halilmutlu', parti: 'HP', renk: '#c62828' }, { kad: 'Kuzey', parti: 'İP', renk: '#ad1457' }],
  katilmayan: ['TuranRiver', 'Ulaskonu16', 'CELAL'],
  oylamalar: [{ id: 49, baslik: 'Vatandaşlık Görevini Yerine Getirmeyen Vatandaşların Cezalandırılması Hakkında Kanun Teklifi', bit: S(2), kabul: 4, ret: 1, cekimser: 2, oyum: null }] };
const ISLER = [
  { tur: 'golge', oncelik: 3, baslik: 'Gölge kabineni tamamla', alt: '0/12 bakanlığa gölge bakan atandı', git: 'golge' },
  { tur: 'oylama', oncelik: 1, baslik: 'Kanun oylaması: Vatandaşlık Görevi', alt: 'Oyunu henüz kullanmadın', bit: S(2), id: 49, git: 'meclis' },
  { tur: 'kurucu', oncelik: 2, baslik: 'Kurucu daveti: Kuzey Yıldızı Topluluğu', alt: 'Kurucular kuruluna çağrıldın', bit: S(90), id: 24, git: 'kurucu' }];
const HEDEF = { parti: { id: 1, ad: 'Halk Partisi', kisa: 'HP', renk: '#c62828' }, hafta: '2026-10-26', bitis: S(30),
  hedefler: [{ kod: 'kursu', ad: "Kürsü'de partiyi duyurun (gönderi)", hedef: 40, odul: 25500, tamam: false, ilerleme: 23 },
    { kod: 'miting', ad: 'Hafta içinde miting düzenleyin', hedef: 4, odul: 25500, tamam: true, ilerleme: 5 }],
  ayin_uyeleri: [{ kad: 'TuranRiver', puan: 16 }, { kad: 'uygarzk', puan: 14 }] };
const SIRA = { donem: '2026-10', bas: S(-700), bit: S(8), canli: true,
  siyasetci: [{ kad: 'AbdullahGencer', parti: 'İTF', renk: '#c62828', deger: 22 }, { kad: 'ArvenTora', parti: 'DHP', renk: '#2e7d32', deger: 18 }],
  vekil: [{ kad: 'Sadıközerçağlar77', parti: 'İTF', deger: 35 }], is_insani: [{ kad: 'uygarzk', parti: 'HP', deger: 19981779 }],
  kalem: [{ kad: 'Sadıközerçağlar77', parti: 'İTF', deger: 193 }], haftanin_kalemi: [{ kad: 'mehmetemincelik', donem: '2026-H43' }], odullu: null };
const GOLGE = { parti: { id: 1, ad: 'Halk Partisi', kisa: 'HP', renk: '#c62828' }, gb_benim: true, uye: true,
  bakanliklar: [{ kod: 'adalet', ad: 'Adalet Bakanı', bakan: 'Ece', golge: null, golge_benim: false }, { kod: 'icisleri', ad: 'İçişleri Bakanı', bakan: null, golge: 'Kuzey', golge_benim: false }],
  raporlar: [{ id: 1, bakanlik: 'adalet', bakanlik_ad: 'Adalet Bakanı', yazar: 'Kuzey', parti: 'HP', baslik: 'Bütçe denetimi', metin: 'Bakanlığın bu haftaki harcamaları şeffaf değil.', zaman: S(-1) }] };

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = [];
  for (const genislik of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: genislik, height: 844 }, isMobile: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(e.message));
    await page.route('**/*', r => {
      const u = new URL(r.request().url());
      if (u.hostname !== 'oyun.test') return r.abort();
      const ad = decodeURIComponent(u.pathname === '/' ? '/index.html' : u.pathname);
      let f = path.join(KOK, ad); if (!fs.existsSync(f)) f = path.join(YEDEK, ad);
      if (!fs.existsSync(f)) return r.fulfill({ status: 404, body: '' });
      r.fulfill({ status: 200, body: fs.readFileSync(f), contentType: f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
    });
    await page.goto('http://oyun.test/index.html');
    await page.waitForFunction(() => window.SO_SIYASET_ARENASI_V1 && typeof iskelet === 'function' && typeof window.siyasetArenasiEkrani === 'function');
    await page.waitForTimeout(600);
    await page.evaluate((V) => {
      window.calls = [];
      const sahte = (ad) => ({ meclis_oturum: V.OTURUM, bekleyen_islerim: V.ISLER, parti_hedefleri: V.HEDEF, siralamalar: V.SIRA, golge_kabine: V.GOLGE,
        meclis_yoklama: { tamam: true, kidem: 1 }, kanun_oy: {}, golge_ata: { tamam: true }, golge_rapor_yaz: { id: 2, kidem: 1 } })[ad] || {};
      API = { rpc: async (ad, args) => { calls.push({ ad, args }); return JSON.parse(JSON.stringify(sahte(ad))); } };
      if (window.YUK) try { YUK.temizle && YUK.temizle(); } catch (_) {}
      D.durum = D.durum || {}; D.durum.profil = Object.assign({ id: 'u1', il_id: 6, kad: 'Deniz', parti: null, makamlar: [] }, D.durum.profil || {}, { kad: 'Deniz' });
    }, { OTURUM, ISLER, HEDEF, SIRA, GOLGE });
    const bekle = (ms = 350) => page.waitForTimeout(ms);
    const yaz = async (ad) => {
      if (!shot) return; fs.mkdirSync(shot, { recursive: true });
      await page.evaluate(() => { try { if (!document.querySelector('#saKad,#saRB')) modalKapat(); } catch (_) {} }); await page.waitForTimeout(250);
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) { a.dataset.eski = a.style.cssText; a.style.position = 'static'; a.style.height = 'auto'; } document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = 'visible'; }); });
      await page.screenshot({ path: path.join(shot, genislik + '_' + ad + '.png'), fullPage: true });
      await page.evaluate(() => { const a = document.querySelector('#app'); if (a) a.style.cssText = a.dataset.eski || ''; document.querySelectorAll('.icerik').forEach(x => { x.style.overflow = ''; }); });
    };
    const metin = () => page.evaluate(() => document.querySelector('#app').innerText);
    const tasma = () => page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
    const son = (ad) => page.evaluate((a) => calls.filter(x => x.ad === a).pop(), ad);

    // Bugün
    await page.evaluate(() => ekranAc(siyasetArenasiEkrani)); await bekle(600);
    let t = await metin();
    assert.match(t, /Siyaset Arenası/); assert.match(t, /CANLI/); assert.match(t, /Yoklamaya katıl/); assert.match(t, /Katılmayan vekiller/); assert.match(t, /halilmutlu/);
    assert.ok(!await tasma(), genislik + ' px: taşma (bugün)'); await yaz('01_bugun');
    await page.click('text=Yoklamaya katıl'); await bekle();
    assert.ok(await son('meclis_yoklama'), 'yoklama çağrılmalı');
    await page.click('.sa-oy.kabul'); await bekle();
    assert.deepEqual((await son('kanun_oy')).args, { p_id: 49, p_oy: 'kabul' });

    // Bekleyen işler: öncelik sırası
    await page.evaluate(() => saSekme('isler')); await bekle(500);
    t = await metin();
    assert.ok(t.indexOf('Kanun oylaması') < t.indexOf('Kurucu daveti') && t.indexOf('Kurucu daveti') < t.indexOf('Gölge kabineni'), 'öncelik sırası');
    assert.ok(!await tasma(), genislik + ' px: taşma (işler)'); await yaz('02_isler');

    // Parti hedefi
    await page.evaluate(() => saSekme('hedef')); await bekle(500);
    t = await metin(); assert.match(t, /23 \/ 40/); assert.match(t, /Tamamlandı/); assert.match(t, /Ayın en aktif üyesi/);
    assert.ok(!await tasma(), genislik + ' px: taşma (hedef)'); await yaz('03_hedef');

    // Sıralamalar
    await page.evaluate(() => saSekme('sira')); await bekle(500);
    t = await metin(); assert.match(t, /AbdullahGencer/); assert.match(t, /Haftanın Kalemi/); assert.match(t, /mehmetemincelik/);
    await page.evaluate(() => saSiraTur('is_insani')); await bekle(200);
    t = await metin(); assert.match(t, /uygarzk/); assert.match(t, /20 mn ₺/);
    assert.ok(!await tasma(), genislik + ' px: taşma (sıra)'); await yaz('04_sira');

    // Gölge kabine
    await page.evaluate(() => saSekme('golge')); await bekle(500);
    t = await metin(); assert.match(t, /Gölge Kabine/); assert.match(t, /Bütçe denetimi/); assert.match(t, /Gölge: Kuzey/);
    assert.ok(!await tasma(), genislik + ' px: taşma (gölge)'); await yaz('05_golge');
    await page.evaluate(() => saGolgeAta('adalet')); await bekle(300);
    await page.fill('#saKad', 'Kuzey'); await page.click('#saAtaOk'); await bekle();
    assert.deepEqual((await son('golge_ata')).args, { p_bakanlik: 'adalet', p_kad: 'Kuzey' });
    await bekle(800);

    // Gündem kartı ve kendiliğinden yoklama
    const gk = await page.evaluate(async () => { calls.length = 0; iskelet('Gündem', '<div class="kart">Gündem</div>'); await saGundemEkle(); const k = document.querySelector('#icerik .sa-gk'); return k ? k.innerText : ''; }); await bekle(300);
    assert.equal(await page.evaluate(() => typeof gundemEkrani === 'function' && /gundemEkle/.test(String(gundemEkrani))), true, 'Gündem sarılmalı');
    assert.match(gk, /SİYASET ARENASI|Siyaset Arenası/); assert.match(gk, /iş seni bekliyor/);
    assert.ok(await son('meclis_yoklama'), 'oturum açıkken vekilin yoklaması kendiliğinden alınmalı');
    await yaz('06_gundem');
    await page.close();
  }
  await browser.close();
  const ilgili = hatalar.filter(h => /arena|sa[A-Z]|siyaset/i.test(h));
  assert.equal(ilgili.length, 0, 'Sayfa hataları: ' + ilgili.join(' | '));
  console.log('TAMAM (siyaset arenası: bugün, bekleyen, hedef, sıralama, gölge kabine, gündem kartı; 390 ve 320 px)' + (hatalar.length ? ' · ilgisiz sayfa hatası: ' + hatalar.length : ''));
})().catch(e => { console.error(e); process.exit(1); });
