// 20.11.2026 · Yardım Masası + uzun duyuru + İstinaf Dairesi metinleri arayüz testi (sahte RPC, 390 px ve 320 px).
// Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/yardim_duyuru_arayuz.js [ekran-klasörü]
const fs = require('fs'), path = require('path'); const { chromium } = require('playwright');
const klasor = process.argv[2] || '/tmp/yardim_ekran'; fs.mkdirSync(klasor, { recursive: true });
const html0 = fs.readFileSync(path.join(__dirname, '../dist/index.html'), 'utf8');
const simdi = new Date().toISOString(), dk = (n) => new Date(Date.now() - n * 60000).toISOString();
const uzun = 'Hoş geldiniz! Bu siyasi ve ekonomik simülasyon evrenine adım attınız. '.repeat(45);
const R = {
  durum: { simdi, profil: { id: 'u-1', kad: 'mustafaozdm', yonetici: false, il_id: 34, il_ad: 'İstanbul', parti: null, makamlar: [], yetkiler: { yonetici: false, moderator: true, liste: ['kayit', 'duyuru', 'sikayet', 'destek'] }, cuzdan: { para: 1e6 } }, okunmamis: { bildirim: 0, ozel: 0 } },
  ozel_liste: [], sohbet_grup_kesfet: null, rozetler: {}, mesaj_tepkileri: {},
  sohbet_ozet: { cevrimici: 12, toplam_okunmamis: 0, grup_sinir: { kurucu_aktif: 3, uye: 50 },
    kanallar: ['genel', 'il', 'belediye', 'parti', 'meclis'].map(k => ({ kanal: k, baslik: { genel: 'Türkiye Meydanı', il: 'İstanbul Kahvesi', belediye: 'İstanbul Belediye Meclisi', parti: 'Parti sohbeti', meclis: 'TBMM Genel Kurulu' }[k], kilit: k === 'parti' ? 'Bir partiye katılınca açılır.' : null, yazabilir: k === 'genel' || k === 'il', okunmamis: 0, son: null, cevrimici: k === 'genel' ? 12 : null, sinyal: 'sohbet:' + k })),
    yardim: { kanal: 'yardim', baslik: 'Yardım Masası', kilit: null, yazabilir: true, okunmamis: 2, sinyal: 'sohbet:yardim', gorevli: true, bekleyen: 3,
      son: { kad: 'Oyun Yöneticisi G-06', metin: 'Menü › Devlet › Meclis yolunu izleyebilirsin.', zaman: dk(4), gorevli: true } } },
  sohbet_oku: { kanal: 'yardim', baslik: 'Yardım Masası', yazabilir: true, sinyal: 'sohbet:yardim', gorevli_yazabilir: true, mesajlar: [
    { id: 1, kad: 'yeniOyuncu', metin: 'Merhaba, Meclis ekranını nerede bulurum? Bir de şirket nasıl kurulur?', zaman: dk(9), parti: { kisa: 'HP', renk: '#e5574f' }, unvan: 'Vatandaş', benim: false, gorevli: false },
    { id: 2, kad: 'Oyun Yöneticisi G-06', metin: 'Menü › Devlet › Meclis yolunu izleyebilirsin. Şirket için Ekonomi › İş dünyası › Şirket kur.', zaman: dk(6), parti: null, unvan: 'Oyun Yönetimi', benim: false, gorevli: true },
    { id: 3, kad: 'tecrubeli', metin: 'Şirkette ilk hafta gideri düşük tut, sonra büyütürsün.', zaman: dk(5), parti: null, unvan: 'Kıdemli Vatandaş', benim: false, gorevli: false },
    { id: 4, kad: 'Oyun Yöneticisi G-02', metin: 'Takıldığın yerde yine yaz; özel konular için Yönetime Yaz ekranını kullan.', zaman: dk(2), parti: null, unvan: 'Oyun Yönetimi', benim: true, gorevli: true }] },
  sohbet_yaz: { tamam: true }, yardim_yanitla: { tamam: true },
  mod_merkez: { zaman: simdi, ben: { kad: 'mustafaozdm', yonetici: false, yetkiler: ['kayit', 'duyuru', 'sikayet', 'destek'], rutbe: 'moderator', kod: 'G-06', birim: 'oyuncu', birim_ad: 'Oyuncu Masası', sozlesme_at: simdi }, birimler: [], kuyruk: {}, istatistik: { bugun: 1, hafta: 5, ekip: 13, cevrimici: 3 }, son_islemlerim: [{ islem: 'yardim_yanit', hedef: null, zaman: dk(2) }, { islem: 'istinaf_oy', hedef: 'Adliye #12', zaman: dk(50) }] },
  admin_duyuru: { tamam: true, kitle: 24 }, yk_bildirim: { kisi: 3 },
  bildirim_kutusu: [
    { tur: 'yayin', id: 9, kad: 'Oyun Yönetimi', unvan: 'Oyun Yönetimi', yayin_tur: 'sistem', metin: uzun + '\n\n— Oyun Yöneticisi G-06', zaman: dk(30), parti: null, benim: false, yeni: true },
    { tur: 'kisisel', id: 10, metin: 'Oyun Yöneticisi G-06: Kayıt başvurun onaylandı, hoş geldin.', zaman: dk(20), yeni: true },
    { tur: 'kisisel', id: 11, metin: '⚖️ İSTİNAF GÖREVİ: Adliye #12 dosyasında İstinaf Dairesi üyesi olarak görevlendirildin (davacı A, davalı B). 24 saat içinde Adliye › Dosya #12 ekranından kararı onayla ya da boz.', zaman: dk(10), yeni: true }],
  yayin_haklari: [], bakan_tekliflerim: [], cb_yardimcisi_tekliflerim: [], resmi_kabul_davetlerim: { gelen: [], giden: [] }, bildirim_hedefleri: {}
};
const KOPRU = `<script>window.__R=${JSON.stringify(R)};window.API_TEST={async rpc(fn,a){window.__son=(window.__son||[]);window.__son.push([fn,a]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return null},async kayit(){},async giris(){},async cikis(){}};</script>`;
const html = html0.replace(/<script src="https:[^"]+"><\/script>/g, '').replace('<body>', '<body>' + KOPRU).replace('API = window.API_TEST || gercekApi();', 'API = window.API_TEST;');

(async () => {
  // Derlemede yeni metinler ve girişler
  for (const isaret of ['window.yardimMasasiAc', "API.rpc('yardim_yanitla'", '3 üyeli İstinaf Dairesi', 'İstinaf Dairesi görevin var', "yardimMasasiAc==='function'&&yardimMasasiAc()", 'maxlength="5000"'])
    if (!html0.includes(isaret)) throw new Error('Derlemede yok: ' + isaret);
  if (/kurayla seçilen[^<]{0,40}jüri/.test(html0)) throw new Error('Eski jüri metni derlemede duruyor');
  const b = await chromium.launch(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {});
  for (const w of [390, 320]) {
    const p = await b.newPage({ viewport: { width: w, height: 844 }, deviceScaleFactor: 2 });
    const hatalar = []; p.on('pageerror', e => hatalar.push(e.message)); p.on('console', m => { if (m.type() === 'error') hatalar.push('console:' + m.text()); });
    await p.route('**/*', r => r.abort());
    await p.setContent(html, { waitUntil: 'load' }); await p.waitForTimeout(800);
    await p.evaluate(() => { API = window.API_TEST; D.durum = __R.durum; });
    const say = (fn) => p.evaluate((f) => (window.__son || []).filter(x => x[0] === f).length, fn);
    const son = (fn) => p.evaluate((f) => { const l = (window.__son || []).filter(x => x[0] === f); return l.length ? l[l.length - 1][1] : null; }, fn);
    const tasma = () => p.evaluate(() => { const g = document.documentElement.clientWidth; return [...document.querySelectorAll('#app *, #modal *')].filter(x => { const r = x.getBoundingClientRect(); return r.width > 0 && r.right > g + 1 && !x.closest('.sh-hikaye,.mm-filtre,.shr-hitap'); }).slice(0, 4).map(x => x.className + '|' + x.tagName); });
    const cek = async (ad) => { await p.waitForTimeout(700); const t = await tasma(); await p.screenshot({ path: `${klasor}/${w}_${ad}.png` }); console.log(w, ad, 'taşma:', JSON.stringify(t), hatalar.length ? 'HATA ' + JSON.stringify(hatalar.splice(0)) : ''); if (t.length) throw new Error(ad + ': yatay taşma'); };

    // 1) Sohbet › Kanallar: Yardım Masası satırı
    await p.evaluate(() => ekranAc(sohbetListe)); await p.waitForTimeout(700);
    await p.evaluate(() => document.querySelector('[data-sh="seg"][data-v="kanal"]').click());
    await cek('1_kanallar');
    const s1 = await p.evaluate(() => { const r = document.querySelector('[data-sh="kanal"][data-kanal="yardim"]'); return r ? r.textContent : null; });
    if (!s1 || !/Yardım Masası/.test(s1) || !/3 yanıt bekleyen mesaj/.test(s1) || !/Oyun Yöneticisi G-06/.test(s1)) throw new Error('Yardım Masası satırı: ' + s1);

    // 2) Kanal ekranı: yönetim yanıtı balonu, bilgi şeridi, yönetim adına yanıt anahtarı
    await p.evaluate(() => document.querySelector('[data-sh="kanal"][data-kanal="yardim"]').click());
    await cek('2_yardim');
    const s2 = await p.evaluate(() => ({ yon: document.querySelectorAll('.shm.shy').length, benimYon: document.querySelectorAll('.shm.shy.benim').length, bilgi: !!document.querySelector('.shy-bilgi'), anahtar: !!document.querySelector('#shyResmi'),
      acik: (document.querySelector('#shyResmi') || {}).checked, ad: (document.querySelector('.shm.shy .shy-kim b') || {}).textContent, kadBos: [...document.querySelectorAll('.shm.shy')].every(x => x.getAttribute('data-kad') === ''),
      yer: document.querySelector('#yaz').placeholder, uz: document.querySelector('#yaz').maxLength, yazi: getComputedStyle(document.querySelector('#yaz')).fontSize }));
    console.log(w, 'yardim', JSON.stringify(s2));
    if (s2.yon !== 2 || s2.benimYon !== 1 || !s2.bilgi || !s2.anahtar || !s2.acik || s2.ad !== 'Oyun Yöneticisi G-06' || !s2.kadBos || s2.uz !== 1500 || parseFloat(s2.yazi) < 16) throw new Error('Yardım Masası ekranı');
    // yönetim adına gönder
    await p.evaluate(() => { const t = document.querySelector('#yaz'); t.value = 'Yönetim adına deneme yanıtı.'; t.dispatchEvent(new Event('input')); document.querySelector('#gonder').click(); }); await p.waitForTimeout(600);
    if (await say('yardim_yanitla') !== 1 || await say('sohbet_yaz') !== 0) throw new Error('yönetim adına gönderim');
    // kendi adına gönder
    await p.evaluate(() => { document.querySelector('#shyResmi').click(); }); await p.waitForTimeout(200);
    const s3 = await p.evaluate(() => document.querySelector('#shyResmiB').textContent);
    await p.evaluate(() => { const t = document.querySelector('#yaz'); t.value = 'Kendi adıma soru.'; t.dispatchEvent(new Event('input')); document.querySelector('#gonder').click(); }); await p.waitForTimeout(600);
    const a3 = await son('sohbet_yaz');
    if (s3 !== 'Kendi adınla yazıyorsun' || await say('yardim_yanitla') !== 1 || !a3 || a3.p_kanal !== 'yardim') throw new Error('kendi adına gönderim: ' + s3 + JSON.stringify(a3));
    await cek('3_kendi_adina');
    // yönetim yanıtına dokun: oyuncu kartı, özel mesaj ve şikâyet yok
    await p.evaluate(() => document.querySelector('.shm.shy:not(.benim) .shm-b').click()); await p.waitForTimeout(400);
    const s4 = await p.evaluate(() => [...document.querySelectorAll('#modal [data-es]')].map(x => x.getAttribute('data-es')));
    console.log(w, 'eylem', s4.join(','));
    if (s4.includes('sikayet') || s4.includes('kart') || s4.includes('dm') || !s4.includes('kopya') || !s4.includes('yy')) throw new Error('yönetim yanıtı eylem sayfası');
    await cek('4_eylem');
    await p.evaluate(() => modalKapat());
    // oyuncu görünümü: anahtar yok
    await p.evaluate(() => { __R.sohbet_oku.gorevli_yazabilir = false; __R.sohbet_oku.mesajlar[3].benim = false; geriGit(); }); await p.waitForTimeout(400);
    await p.evaluate(() => yardimMasasiAc()); await p.waitForTimeout(800);
    const s5 = await p.evaluate(() => ({ anahtar: !!document.querySelector('#shyResmi'), yon: document.querySelectorAll('.shm.shy').length, yer: document.querySelector('#yaz').placeholder }));
    if (s5.anahtar || s5.yon !== 2 || s5.yer !== 'Sorunu yaz') throw new Error('oyuncu görünümü: ' + JSON.stringify(s5));
    await cek('5_oyuncu');

    // 3) Duyuru: 5000 karakter, sayaç
    await p.evaluate(() => ekranAc(mmDuyuru)); await p.waitForTimeout(600);
    const d1 = await p.evaluate((m) => { const t = document.querySelector('#mmDY'); t.value = m; t.dispatchEvent(new Event('input')); return { uz: t.maxLength, sayac: document.querySelector('#mmDYS').textContent, yer: document.querySelector('#mmDM').placeholder }; }, uzun);
    console.log(w, 'duyuru', JSON.stringify(d1));
    if (d1.uz !== 5000 || d1.sayac !== `${uzun.length} / 5000` || !/Oyun Yöneticisi/.test(d1.yer)) throw new Error('duyuru ekranı');
    await cek('6_duyuru');
    await p.evaluate(() => document.querySelector('#mmDYG').click()); await p.waitForTimeout(400);
    await p.evaluate(() => { const o = [...document.querySelectorAll('#modal button')].find(x => /Yayımla/.test(x.textContent)); o.click(); }); await p.waitForTimeout(500);
    const a6 = await son('admin_duyuru');
    if (!a6 || a6.p_metin.length !== uzun.trim().length) throw new Error('duyuru gönderimi');
    // Moderasyon Merkezi: araçlarda Yardım Masası, işlem adları
    await p.evaluate(() => ekranAc(modMerkezi)); await p.waitForTimeout(800);
    const m1 = await p.evaluate(() => ({ arac: [...document.querySelectorAll('.mm-arac [data-ac]')].map(x => x.dataset.ac), metin: document.getElementById('icerik').textContent }));
    if (!m1.arac.includes('yardim') || !/yönetim adına yanıt verdi/.test(m1.metin) || !/istinaf dosyasında oy kullandı/.test(m1.metin) || !/Oyun Yöneticisi G-06/.test(m1.metin)) throw new Error('Moderasyon Merkezi girişleri');
    await cek('7_merkez');

    // 4) Bildirimler: uzun duyuru kısaltılır, dokununca açılır
    await p.evaluate(() => ekranAc(bildirimEkrani)); await p.waitForTimeout(1200);
    const n1 = await p.evaluate(() => { const d = document.querySelector('.bm-devam'), m = document.querySelector('.bm-r-metin.bm-uzun'); return d && m ? { kisa: m.getBoundingClientRect().height, tam: m.scrollHeight, dugme: d.textContent } : null; });
    console.log(w, 'bildirim', JSON.stringify(n1));
    if (!n1 || n1.kisa >= n1.tam || n1.dugme !== 'Devamını oku') throw new Error('uzun duyuru kısaltması');
    await cek('8_bildirim');
    await p.evaluate(() => document.querySelector('.bm-devam').click()); await p.waitForTimeout(300);
    const n2 = await p.evaluate(() => { const m = document.querySelector('.bm-r-metin.bm-uzun'); return { acik: m.classList.contains('acik'), yuk: m.getBoundingClientRect().height, tam: m.scrollHeight, dugme: document.querySelector('.bm-devam').textContent, modal: !!document.querySelector('#modal .modal, #modal > *') }; });
    if (!n2.acik || n2.yuk < n2.tam - 2 || n2.dugme !== 'Kısalt') throw new Error('uzun duyuru açılması: ' + JSON.stringify(n2));
    const n3 = await p.evaluate(() => document.getElementById('icerik').textContent);
    if (!/Oyun Yöneticisi G-06/.test(n3) || !/İSTİNAF GÖREVİ|İstinaf görevi|İstinaf Görevi/.test(n3)) throw new Error('bildirim metinleri');
    if (hatalar.length) throw new Error('Sayfa hataları: ' + JSON.stringify(hatalar));
    await p.close();
  }
  await b.close();
  console.log('TAMAM');
})().catch(e => { console.error('BAŞARISIZ:', e.message); process.exit(1); });
