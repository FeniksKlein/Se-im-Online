// Cihaz yasağı arayüz testi (sahte RPC; 390 ve 320 px). Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/cihaz_yasak_arayuz.js [ekran-klasörü]
// Denetlenenler: Kayıt masasında cihaz uyarıları, güçlü uyarıda "görerek onay" (mod_kayit_karar) ve "reddet" yolları,
// uyarısız başvuruda eski yol (admin_kayit_karar2), Yasaklı cihazlar ekranı (liste, gerekçeli kaldırma / yeniden açma),
// cihaz yasağında açılış ekranı başlığı, taşma olmaması.
const fs = require('fs'), path = require('path'); const { chromium } = require('playwright');
const klasor = process.argv[2] || '/tmp/cy_ekran'; fs.mkdirSync(klasor, { recursive: true });
const html0 = fs.readFileSync(path.join(__dirname, '../dist/index.html'), 'utf8');
const simdi = new Date().toISOString(), dk = (n) => new Date(Date.now() - n * 60000).toISOString();
const YASAK_MESAJ = 'Bu cihazın oyuna erişimi, kural ihlali nedeniyle oyun yönetimi tarafından kapatılmıştır. Bu cihazdan giriş yapılamaz ve yeni hesap açılamaz. Bir yanlışlık olduğunu düşünüyorsan yaz: feniksklein@gmail.com';
const liste = (kaldirabilir) => ({
  kaldirabilir,
  aktif: [
    { id: 1, kaynak: 'Süleymanbskr', neden: 'Ağır hakaret ve tehdit; engellendikten sonra yeni adla yeniden kayıt', zaman: dk(90), ekleyen: 'FeniksKlein',
      hesaplar: [{ kad: 'Süleyman', yasakli: true, muaf: false }, { kad: 'Süleymanbskr', yasakli: true, muaf: false }, { kad: 'UzunKullaniciAdi_1234', yasakli: false, muaf: false }, { kad: 'kardesi', yasakli: false, muaf: true }],
      deneme: { hesap: 2, toplam: 5, son: dk(4) } },
    { id: 2, kaynak: 'gürültücü', neden: null, zaman: dk(3000), ekleyen: null, hesaplar: [], deneme: { hesap: 0, toplam: 0, son: null } }
  ],
  kaldirilan: [{ id: 3, kaynak: 'yanlisEngel', neden: 'spam', zaman: dk(9000), kaldiran: 'mehmetemincelik', kaldirma_zaman: dk(700), kaldirma_not: 'Aynı evdeki kardeşinin telefonu; ayrı kişi olduğu doğrulandı.' }],
  denemeler: [
    { kad: null, hesap_var: false, basvuru: 'beklemede', ilk: dk(30), son: dk(4), sayi: 3, kaynak: 'Süleymanbskr' },
    { kad: 'SuleymanGeriDondu', hesap_var: false, basvuru: 'beklemede', ilk: dk(60), son: dk(50), sayi: 2, kaynak: 'Süleymanbskr' },
    { kad: 'eskiYanHesap', hesap_var: true, basvuru: 'onaylandi', ilk: dk(80), son: dk(70), sayi: 1, kaynak: 'Süleymanbskr' }
  ]
});
const R = {
  durum: { simdi, profil: { kad: 'ArvenTora', yonetici: true, il_id: 34, yetkiler: { yonetici: true, moderator: false, liste: [] }, cuzdan: { para: 1e8 } }, okunmamis: { bildirim: 0, ozel: 0 } },
  mod_merkez: { zaman: simdi, ben: { kad: 'ArvenTora', yonetici: true, yetkiler: ['kayit', 'sikayet', 'sustur', 'hesap_kapat', 'oyuncu_ara', 'coklu_hesap'], rutbe: 'moderator' }, birimler: [],
    kuyruk: { kayit: { sayi: 4, en_eski: dk(45) }, coklu: { sayi: 1 } }, istatistik: { bugun: 4, hafta: 32, sira: 1, ekip: 13, cevrimici: 2 }, son_islemlerim: [{ islem: 'cihaz_yasak_kaldir', hedef: 'yanlisEngel', zaman: dk(5) }] },
  admin_kayit_basvurulari: [
    { user_id: 'u1', kad: 'yeni_ad_55', ad_soyad: 'Süleyman Başkır', il: 'İstanbul', olusturma: dk(30), basvuru_at: dk(25), durum: 'beklemede', red_sayisi: 0, uyari: null, onceki_red: null,
      cihaz_uyari: { guclu: true, ozet: 'engelli «Süleymanbskr» ile aynı bağlantı ve aynı cihaz modeli', satirlar: [
        { seviye: 'guclu', metin: 'Aynı bağlantı ve aynı cihaz modeli: engellenmiş «Süleymanbskr» ile aynı internet bağlantısından, aynı model ve ayardaki bir cihazdan geliyor. Büyük olasılıkla aynı kişi.' },
        { seviye: 'zayif', metin: 'Aynı internet bağlantısı: engellenmiş «Süleyman» ile aynı bağlantıdan giriş yapılmış. Zayıf işaret; aile, okul ya da mobil operatör paylaşımı olabilir.' }] } },
    { user_id: 'u2', kad: 'ahmet_y', ad_soyad: 'Ahmet Yılmaz', il: 'Ankara', olusturma: dk(20), basvuru_at: dk(15), durum: 'beklemede', red_sayisi: 0, uyari: null, onceki_red: null,
      cihaz_uyari: { guclu: false, ozet: null, satirlar: [] } },
    { user_id: 'u3', kad: 'ikinci_hesap', ad_soyad: 'Ayşe Demir', il: 'İzmir', olusturma: dk(12), basvuru_at: dk(10), durum: 'beklemede', red_sayisi: 0, uyari: null, onceki_red: null,
      cihaz_uyari: { guclu: false, ozet: null, satirlar: [{ seviye: 'zayif', metin: 'Bu cihazda başka hesap var: aysedemir35. Aynı kişinin ikinci hesabı olabilir.' }] } },
    { user_id: 'u4', kad: 'eski_surum', ad_soyad: 'Mehmet Kaya', il: 'Bursa', olusturma: dk(8), basvuru_at: dk(5), durum: 'beklemede', red_sayisi: 0, uyari: null, onceki_red: null }
  ],
  mod_ustlenmeler: {}, mod_ustlen: { tamam: true },
  admin_kayit_karar2: { durum: 'onaylandi' }, mod_kayit_karar: { durum: 'onaylandi' },
  mod_cihaz_yasaklari: liste(true), mod_cihaz_yasak_ayarla: liste(true),
  admin_supheler: { cihaz: [], ip: [] }, yk_oyuncular: { toplam: 0, liste: [] }
};
const KOPRU = `<script>window.__R=${JSON.stringify(R)};window.__son=[];window.API_TEST={async rpc(fn,a){window.__son.push([fn,a]);if(window.__HATA&&window.__HATA[fn])throw new Error(window.__HATA[fn]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return window.__OTURUM||null},async kayit(){},async giris(){},async cikis(){}};</script>`;
const html = html0.replace(/<script src="https:[^"]+"><\/script>/g, '').replace('<body>', '<body>' + KOPRU).replace('API = window.API_TEST || gercekApi();', 'API = window.API_TEST;');
let basarisiz = 0;
const kontrol = (ad, kosul, ek) => { if (kosul) console.log('  ✓', ad); else { basarisiz++; console.log('  ✗', ad, ek === undefined ? '' : JSON.stringify(ek)); } };
(async () => {
  const b = await chromium.launch();
  for (const gen of [390, 320]) {
    console.log(`— ${gen} px —`);
    const p = await b.newPage({ viewport: { width: gen, height: 844 }, deviceScaleFactor: 2 });
    const hatalar = []; p.on('pageerror', e => hatalar.push(e.message)); p.on('console', m => { if (m.type() === 'error') hatalar.push('console:' + m.text()); });
    await p.setContent(html, { waitUntil: 'load' }); await p.waitForTimeout(800);
    await p.evaluate(() => { API = window.API_TEST; D.durum = __R.durum; });
    const tasma = () => p.evaluate(() => { const w = document.documentElement.clientWidth; return [...document.querySelectorAll('#icerik *,.modal *,#modal *')].filter(x => x.getBoundingClientRect().right > w + 1).slice(0, 3).map(x => x.className + '|' + x.tagName); });
    const ekran = async (ad, fn) => {
      await p.evaluate(() => { if (window.SO_KESINTISIZ) { SO_KESINTISIZ.eylem = Date.now(); SO_KESINTISIZ.dokunus = 0; } });
      await p.evaluate(fn); await p.waitForTimeout(700);
      const t = await tasma(); kontrol(`${ad}: taşma yok`, t.length === 0, t);
      await p.screenshot({ path: `${klasor}/${gen}_${ad}.png`, fullPage: false });
    };
    const son = (fn) => p.evaluate((f) => window.__son.filter(x => x[0] === f).map(x => x[1]), fn);
    const sifirla = () => p.evaluate(() => { window.__son = []; });

    // Pano: araç düğmesi ve işlem adı
    await ekran('1_pano', () => yoneticiEkrani());
    kontrol('panoda "Yasaklı cihazlar" aracı', await p.evaluate(() => !!document.querySelector('[data-ac="cihaz"]')));
    kontrol('işlem adı Türkçe', await p.evaluate(() => document.getElementById('icerik').textContent.includes('cihaz yasağını kaldırdı')));

    // Kayıt masası 1. başvuru: güçlü + zayıf uyarı kutuları
    await ekran('2_kayit_guclu', () => ekranAc(mmKayit));
    kontrol('güçlü uyarı kutusu görünür', await p.evaluate(() => document.getElementById('icerik').textContent.includes('Mükerrer hesap uyarısı.') && document.getElementById('icerik').textContent.includes('Büyük olasılıkla aynı kişi')));
    kontrol('zayıf uyarı sarı kutuda', await p.evaluate(() => [...document.querySelectorAll('.mm-uyari.sari')].some(x => x.textContent.includes('Zayıf işaret'))));
    // Kabul et → uyarı penceresi; sunucuya henüz karar gitmedi
    await sifirla();
    await ekran('2b_uyari_penceresi', () => document.getElementById('mmKabul').click());
    kontrol('kabulde uyarı penceresi açılır', await p.evaluate(() => !!document.getElementById('mmCuOnay') && !!document.getElementById('mmCuRed')));
    kontrol('pencere açılınca karar gönderilmedi', (await son('admin_kayit_karar2')).length === 0 && (await son('mod_kayit_karar')).length === 0);
    // "Uyarıyı gördüm, yine de kabul et" → mod_kayit_karar(p_uyari_goruldu: true)
    await p.evaluate(() => document.getElementById('mmCuOnay').click()); await p.waitForTimeout(500);
    let c = await son('mod_kayit_karar');
    kontrol('görerek onay yeni RPC ile gider', c.length === 1 && c[0].p_user === 'u1' && c[0].p_onay === true && c[0].p_uyari_goruldu === true, c);
    kontrol('eski RPC çağrılmadı', (await son('admin_kayit_karar2')).length === 0);

    // 2. başvuru (uyarısız): doğrudan eski yol
    await sifirla();
    kontrol('uyarısız başvuruda cihaz kutusu yok', await p.evaluate(() => !document.getElementById('icerik').textContent.includes('Mükerrer hesap uyarısı.') && document.getElementById('icerik').textContent.includes('Ahmet Yılmaz')));
    await p.evaluate(() => document.getElementById('mmKabul').click()); await p.waitForTimeout(500);
    c = await son('admin_kayit_karar2');
    kontrol('uyarısız onay eski RPC ile gider', c.length === 1 && c[0].p_user === 'u2' && c[0].p_onay === true && (await son('mod_kayit_karar')).length === 0, c);

    // 3. başvuru (yalnız zayıf uyarı): kutu var, onay doğrudan
    await ekran('3_kayit_zayif', () => {});
    kontrol('zayıf uyarılı başvuruda kutu var', await p.evaluate(() => document.getElementById('icerik').textContent.includes('Bu cihazda başka hesap var: aysedemir35')));
    await sifirla();
    await p.evaluate(() => document.getElementById('mmKabul').click()); await p.waitForTimeout(500);
    kontrol('zayıf uyarıda pencere açılmaz, eski RPC', (await son('admin_kayit_karar2')).length === 1 && await p.evaluate(() => !document.getElementById('mmCuOnay')));

    // 4. başvuru (eski sunucu yanıtı: cihaz_uyari alanı yok) → hata yok
    kontrol('cihaz_uyari alanı olmayan başvuru çizilir', await p.evaluate(() => document.getElementById('icerik').textContent.includes('Mehmet Kaya')));

    // Güçlü uyarıda "Reddet (önerilen)" → mükerrer hesap gerekçesi
    await p.evaluate(() => ekranAc(mmKayit)); await p.waitForTimeout(700);
    await sifirla();
    await p.evaluate(() => document.getElementById('mmKabul').click()); await p.waitForTimeout(300);
    await p.evaluate(() => document.getElementById('mmCuRed').click()); await p.waitForTimeout(500);
    c = await son('admin_kayit_karar2');
    kontrol('önerilen ret mükerrer hesap gerekçesiyle gider', c.length === 1 && c[0].p_onay === false && /Mükerrer hesap/.test(c[0].p_neden || ''), c);
    // Liste görünümü etiketleri
    await p.evaluate(() => ekranAc(mmKayit)); await p.waitForTimeout(600);
    await ekran('4_kayit_liste', () => document.querySelector('[data-g="liste"]').click());
    kontrol('listede "mükerrer?" ve "cihaz" etiketleri', await p.evaluate(() => { const t = [...document.querySelectorAll('.mm-etiket')].map(x => x.textContent); return t.includes('mükerrer?') && t.includes('cihaz'); }));
    // Ret penceresinde gerekçe ön yazısı
    await p.evaluate(() => { document.querySelector('[data-g="kart"]').click(); }); await p.waitForTimeout(500);
    await ekran('4b_ret', () => document.getElementById('mmRed').click());
    kontrol('ret penceresinde mükerrer hesap seçeneği ve ön yazı', await p.evaluate(() => document.getElementById('mmRetMetin').value.startsWith('Mükerrer hesap') && document.querySelectorAll('#mmRetSec button').length === 6));
    await p.evaluate(() => modalKapat());

    // Yasaklı cihazlar ekranı
    await ekran('5_cihazlar', () => ekranAc(mmCihaz));
    kontrol('yasaklı cihaz, hesaplar ve denemeler görünür', await p.evaluate(() => { const t = document.getElementById('icerik').textContent; return t.includes('Yasaklı cihazlar (2)') && t.includes('Süleymanbskr') && t.includes('bu cihazdan giremez') && t.includes('muaf') && t.includes('2 ayrı hesap') && t.includes('Yeni hesap (başvurusu yok)'); }));
    await p.evaluate(() => document.getElementById('icerik').scrollTo(0, 700)); await p.waitForTimeout(200); await p.screenshot({ path: `${klasor}/${gen}_5b_cihazlar_alt.png` });
    await p.evaluate(() => document.getElementById('icerik').scrollTo(0, 0));
    await sifirla();
    await ekran('6_kaldir', () => document.querySelector('[data-cyk="1"]').click());
    await p.evaluate(() => { document.getElementById('mmCyNot').value = 'kısa'; document.getElementById('mmCyOk').click(); }); await p.waitForTimeout(300);
    kontrol('kısa gerekçeyle kaldırma gönderilmez', (await son('mod_cihaz_yasak_ayarla')).length === 0);
    await p.evaluate(() => { document.getElementById('mmCyNot').value = 'Kardeşinin telefonu, ayrı kişi olduğu doğrulandı.'; document.getElementById('mmCyOk').click(); }); await p.waitForTimeout(500);
    c = await son('mod_cihaz_yasak_ayarla');
    kontrol('kaldırma gerekçeyle gider', c.length === 1 && c[0].p_id === 1 && c[0].p_aktif === false && c[0].p_not.length >= 10, c);
    await sifirla();
    await p.evaluate(() => { document.querySelector('details.mm-kart').open = true; document.querySelector('[data-cya="3"]').click(); }); await p.waitForTimeout(300);
    await p.evaluate(() => { document.getElementById('mmCyNot').value = 'Yeniden ihlal: aynı cihazdan tehdit sürdü.'; document.getElementById('mmCyOk').click(); }); await p.waitForTimeout(500);
    c = await son('mod_cihaz_yasak_ayarla');
    kontrol('yeniden yasaklama gider', c.length === 1 && c[0].p_id === 3 && c[0].p_aktif === true, c);
    // Kaldırma yetkisi olmayan moderatör: düğme yok, açıklama var
    await p.evaluate((l) => { __R.mod_cihaz_yasaklari = l; }, liste(false));
    await ekran('7_cihazlar_yetkisiz', () => ekranAc(mmCihaz));
    kontrol('yetkisiz moderatörde kaldırma düğmesi yok', await p.evaluate(() => !document.querySelector('[data-cyk]') && document.getElementById('icerik').textContent.includes('kurucu ve Oyuncu Masası')));
    await p.evaluate((l) => { __R.mod_cihaz_yasaklari = l; }, liste(true));
    // Çoklu hesap ekranından geçiş
    await ekran('8_coklu', () => ekranAc(mmCoklu));
    kontrol('Çoklu hesap ekranında "Yasaklı cihazlar" düğmesi', await p.evaluate(() => !!document.getElementById('mmCyGit')));

    // Açılış: cihaz yasağı mesajında başlık "Erişim kapalı"; gerçek bağlantı hatasında "Bağlantı sorunu"
    await p.evaluate((m) => { window.__OTURUM = { user: { id: 'x', email: 'a@b.c' } }; window.__HATA = { durum: m }; }, YASAK_MESAJ);
    await p.evaluate(() => basla()); await p.waitForTimeout(900);
    kontrol('cihaz yasağında başlık "Erişim kapalı"', await p.evaluate(() => (document.querySelector('.karsila h1') || {}).textContent === 'Erişim kapalı' && document.querySelector('.karsila .giris').textContent.includes('Bu cihazın oyuna erişimi')));
    const t2 = await p.evaluate(() => { const w = document.documentElement.clientWidth; return [...document.querySelectorAll('#app *')].filter(x => x.getBoundingClientRect().right > w + 1).length; });
    kontrol('erişim kapalı ekranı taşmıyor', t2 === 0, t2);
    await p.screenshot({ path: `${klasor}/${gen}_9_erisim_kapali.png` });
    await p.evaluate(() => { window.__HATA = { durum: 'Failed to fetch' }; }); await p.evaluate(() => basla()); await p.waitForTimeout(900);
    kontrol('bağlantı hatasında başlık değişmedi', await p.evaluate(() => (document.querySelector('.karsila h1') || {}).textContent === 'Bağlantı sorunu'));
    kontrol('sayfa hatası yok', hatalar.length === 0, hatalar.slice(0, 4));
    await p.close();
  }
  await b.close();
  console.log(basarisiz ? `BAŞARISIZ: ${basarisiz}` : 'Cihaz yasağı arayüz testi OK');
  process.exit(basarisiz ? 1 : 0);
})();
