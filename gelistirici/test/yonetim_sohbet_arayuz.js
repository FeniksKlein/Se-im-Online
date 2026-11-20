// 20.11.2026 · Sohbete yönetim adına yazma arayüz testi (sahte RPC, 390 px ve 320 px).
// Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/yonetim_sohbet_arayuz.js [ekran-klasörü]
const fs = require('fs'), path = require('path'); const { chromium } = require('playwright');
const klasor = process.argv[2] || '/tmp/yonetim_sohbet_ekran'; fs.mkdirSync(klasor, { recursive: true });
const html0 = fs.readFileSync(path.join(__dirname, '../dist/index.html'), 'utf8');
const simdi = new Date().toISOString(), dk = (n) => new Date(Date.now() - n * 60000).toISOString();
const genel = () => ({ kanal: 'genel', baslik: 'Türkiye Meydanı', yazabilir: true, sinyal: 'sohbet:genel', gorevli_yazabilir: false, resmi_yazabilir: true, kanal_kod: 'genel', mesajlar: [
  { id: 1, kad: 'sertOyuncu', metin: 'Bu partinin hepsi işe yaramaz, hepiniz aynısınız!', zaman: dk(9), parti: { kisa: 'HP', renk: '#e5574f' }, unvan: 'Vatandaş', benim: false, gorevli: false },
  { id: 2, kad: 'Oyun Yöneticisi G-07', metin: 'Lütfen üslubunuza dikkat edin. Hakaret ve küfür yasaktır; devamında susturma uygulanır.', zaman: dk(6), parti: null, unvan: 'Oyun Yönetimi', benim: false, gorevli: true },
  { id: 3, kad: 'sakinOyuncu', metin: 'Haklısınız, konuya dönelim.', zaman: dk(5), parti: null, unvan: 'Saygın Vatandaş', benim: false, gorevli: false }] });
const meclis = () => ({ kanal: 'meclis', baslik: 'TBMM Genel Kurulu', yazabilir: false, sinyal: 'sohbet:meclis', gorevli_yazabilir: false, resmi_yazabilir: true, kanal_kod: 'meclis', mesajlar: [
  { id: 11, kad: 'vekilA', metin: 'Sayın Başkan, değerli milletvekilleri; bütçe üzerine söz almış bulunuyorum.', zaman: dk(8), parti: { kisa: 'CYP', renk: '#3b82f6' }, unvan: 'Milletvekili', benim: false, gorevli: false },
  { id: 12, kad: 'Oyun Yöneticisi G-07', metin: 'Genel Kurul\'da kişisel hakaret içeren mesajlar kaldırılmıştır.', zaman: dk(4), parti: null, unvan: 'Oyun Yönetimi', benim: false, gorevli: true }] });
const R = {
  durum: { simdi, profil: { id: 'u-1', kad: 'Eyetkin', yonetici: false, il_id: 34, il_ad: 'İstanbul', parti: null, makamlar: [], yetkiler: { yonetici: false, moderator: true, liste: ['kayit', 'sikayet', 'sustur', 'hesap_kapat', 'oyuncu_ara', 'sohbet_tum', 'sohbet_resmi'] }, cuzdan: { para: 1e6 } }, okunmamis: { bildirim: 0, ozel: 0 } },
  ozel_liste: [], sohbet_grup_kesfet: null, rozetler: {}, mesaj_tepkileri: {},
  sohbet_ozet: { cevrimici: 12, toplam_okunmamis: 1, grup_sinir: { kurucu_aktif: 3, uye: 50 },
    kanallar: ['genel', 'il', 'belediye', 'parti', 'meclis'].map(k => ({ kanal: k, baslik: { genel: 'Türkiye Meydanı', il: 'İstanbul Kahvesi', belediye: 'İstanbul Belediye Meclisi', parti: 'Parti sohbeti', meclis: 'TBMM Genel Kurulu' }[k], kilit: k === 'parti' ? 'Bir partiye katılınca açılır.' : null, yazabilir: k === 'genel' || k === 'il', okunmamis: k === 'genel' ? 1 : 0,
      son: k === 'genel' || k === 'il' ? { kad: 'Oyun Yöneticisi G-07', metin: 'Lütfen üslubunuza dikkat edin.', zaman: dk(6), gorevli: true } : null, cevrimici: k === 'genel' ? 12 : null, sinyal: 'sohbet:' + k })),
    yardim: { kanal: 'yardim', baslik: 'Yardım Masası', kilit: null, yazabilir: true, okunmamis: 0, sinyal: 'sohbet:yardim', gorevli: true, bekleyen: 0, son: null } },
  sohbet_oku: genel(),
  sohbet_yaz: { tamam: true }, yardim_yanitla: { tamam: true }, mod_sohbet_yaz: { tamam: true, kanal: 'il:34', kanal_ad: 'İstanbul sohbeti', imza: 'Oyun Yöneticisi G-07' },
  mod_merkez: { zaman: simdi, ben: { kad: 'Eyetkin', yonetici: false, yetkiler: ['kayit', 'sikayet', 'sustur', 'hesap_kapat', 'oyuncu_ara', 'sohbet_tum', 'sohbet_resmi'], rutbe: 'moderator', kod: 'G-07', birim: 'icerik', birim_ad: 'İçerik Masası', sozlesme_at: simdi }, birimler: [], kuyruk: {}, istatistik: { bugun: 1, hafta: 5, ekip: 13, cevrimici: 3 }, son_islemlerim: [{ islem: 'sohbet_resmi', hedef: 'genel', zaman: dk(6) }] },
  mod_sohbet_nobeti: { zaman: simdi, tum_yetki: true, resmi_yetki: true,
    kanallar: [{ kanal: 'genel', ad: 'Genel', sayi: 40, grup: false }, { kanal: 'il:34', ad: 'İstanbul sohbeti', sayi: 22, grup: false }, { kanal: 'parti:1', ad: 'CYP parti sohbeti', sayi: 9, grup: true }, { kanal: 'og:15', ad: 'Grup: Ege Gençlik Meclisi ve Dayanışma Platformu', sayi: 4, grup: true }],
    mesajlar: [
      { id: 31, kanal: 'il:34', kanal_ad: 'İstanbul sohbeti', kad: 'sertOyuncu', gorevli: false, metin: 'Hepiniz satılmışsınız!!!', zaman: dk(3), gizli: false, isaret: ['sert'], grup: false, susturulmus: false, moderator: false, sikayet: 1 },
      { id: 30, kanal: 'genel', kanal_ad: 'Genel', kad: 'Oyun Yöneticisi G-07', gorevli: true, metin: 'Lütfen üslubunuza dikkat edin.', zaman: dk(6), gizli: false, isaret: [], grup: false, susturulmus: null, moderator: true, sikayet: 0 }] },
  yayin_haklari: [], bakan_tekliflerim: [], cb_yardimcisi_tekliflerim: [], resmi_kabul_davetlerim: { gelen: [], giden: [] }, bildirim_hedefleri: {}
};
const KOPRU = `<script>window.__R=${JSON.stringify(R)};window.API_TEST={async rpc(fn,a){window.__son=(window.__son||[]);window.__son.push([fn,a]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return null},async kayit(){},async giris(){},async cikis(){}};</script>`;
const html = html0.replace(/<script src="https:[^"]+"><\/script>/g, '').replace('<body>', '<body>' + KOPRU).replace('API = window.API_TEST || gercekApi();', 'API = window.API_TEST;');

(async () => {
  for (const isaret of ["API.rpc('mod_sohbet_yaz'", 'API.rpc("mod_sohbet_yaz"', 'Yönetim adına sohbete yaz', 'sohbete yönetim adına yazdı', 'function resmiYazKur'])
    if (!html0.includes(isaret)) throw new Error('Derlemede yok: ' + isaret);
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

    // 1) Kanal listesi: son mesaj yönetimdense görev unvanı ve kalkan (gerçek ad yok), ikon taşmıyor
    await p.evaluate(() => ekranAc(sohbetListe)); await p.waitForTimeout(700);
    await p.evaluate(() => document.querySelector('[data-sh="seg"][data-v="kanal"]').click());
    await cek('1_kanallar');
    const s1 = await p.evaluate(() => { const g = document.querySelector('[data-sh="kanal"][data-kanal="genel"]'), r = document.querySelector('[data-sh="kanal"][data-kanal="il"]'); const sv = r && r.querySelector('.shy-son svg'); return r && g ? { genel: g.textContent, metin: r.textContent, kalkan: sv ? sv.getBoundingClientRect().width : -1 } : null; });
    if (!s1 || !/Oyun Yöneticisi G-07/.test(s1.genel) || !/Oyun Yöneticisi G-07/.test(s1.metin) || /Eyetkin/.test(s1.genel + s1.metin) || s1.kalkan < 8 || s1.kalkan > 20) throw new Error('kanal listesi: ' + JSON.stringify(s1));

    // 2) Genel sohbet: yönetim mesajı kalkanlı; anahtar KAPALI gelir
    await p.evaluate(() => document.querySelector('[data-sh="kanal"][data-kanal="genel"]').click());
    await cek('2_genel_kapali');
    const s2 = await p.evaluate(() => ({ yon: document.querySelectorAll('.shm.shy').length, ad: (document.querySelector('.shm.shy .shy-kim b') || {}).textContent, alt: (document.querySelector('.shm.shy .shy-kim small') || {}).textContent,
      kadBos: [...document.querySelectorAll('.shm.shy')].every(x => x.getAttribute('data-kad') === ''), anahtar: !!document.querySelector('#shyResmi'), acik: (document.querySelector('#shyResmi') || {}).checked,
      baslik: (document.querySelector('#shyResmiB') || {}).textContent, yer: document.querySelector('#yaz').placeholder, cerceve: document.querySelector('#yazbar').classList.contains('shy-acik'), yazi: getComputedStyle(document.querySelector('#yaz')).fontSize }));
    console.log(w, 'genel', JSON.stringify(s2));
    if (s2.yon !== 1 || s2.ad !== 'Oyun Yöneticisi G-07' || !/resmî mesaj/.test(s2.alt) || !s2.kadBos || !s2.anahtar || s2.acik || s2.baslik !== 'Kendi adınla yazıyorsun' || s2.cerceve || parseFloat(s2.yazi) < 16) throw new Error('genel sohbet ekranı');
    const yer0 = s2.yer;
    // kapalıyken: sıradan mesaj
    await p.evaluate(() => { const t = document.querySelector('#yaz'); t.value = 'Selam millet.'; t.dispatchEvent(new Event('input')); document.querySelector('#gonder').click(); }); await p.waitForTimeout(600);
    const a2 = await son('sohbet_yaz');
    if (await say('mod_sohbet_yaz') !== 0 || !a2 || a2.p_kanal !== 'genel') throw new Error('kendi adına gönderim');
    // anahtarı aç: yönetim adına
    await p.evaluate(() => document.querySelector('#shyResmi').click()); await p.waitForTimeout(200);
    const s3 = await p.evaluate(() => ({ baslik: document.querySelector('#shyResmiB').textContent, yer: document.querySelector('#yaz').placeholder, cerceve: document.querySelector('#yazbar').classList.contains('shy-acik') }));
    if (s3.baslik !== 'Yönetim adına yazıyorsun' || s3.yer !== 'Yönetim adına yaz' || !s3.cerceve) throw new Error('anahtar açık durumu: ' + JSON.stringify(s3));
    await cek('3_genel_acik');
    await p.evaluate(() => { const t = document.querySelector('#yaz'); t.value = 'Tartışma burada kapanmıştır.'; t.dispatchEvent(new Event('input')); document.querySelector('#gonder').click(); }); await p.waitForTimeout(600);
    const a3 = await son('mod_sohbet_yaz');
    if (await say('mod_sohbet_yaz') !== 1 || await say('sohbet_yaz') !== 1 || await say('yardim_yanitla') !== 0 || !a3 || a3.p_kanal !== 'genel' || a3.p_metin !== 'Tartışma burada kapanmıştır.') throw new Error('yönetim adına gönderim: ' + JSON.stringify(a3));
    // kapatınca eski yer tutucu geri gelir
    await p.evaluate(() => document.querySelector('#shyResmi').click()); await p.waitForTimeout(200);
    if (await p.evaluate(() => document.querySelector('#yaz').placeholder) !== yer0) throw new Error('yer tutucu geri gelmedi');
    // yönetim mesajına dokun: oyuncu kartı, özel mesaj ve şikâyet yok
    await p.evaluate(() => document.querySelector('.shm.shy:not(.benim) .shm-b').click()); await p.waitForTimeout(400);
    const s4 = await p.evaluate(() => [...document.querySelectorAll('#modal [data-es]')].map(x => x.getAttribute('data-es')));
    if (s4.includes('sikayet') || s4.includes('kart') || s4.includes('dm') || !s4.includes('kopya')) throw new Error('yönetim mesajı eylem sayfası: ' + s4.join(','));
    await p.evaluate(() => modalKapat());

    // 3) Yetkisiz oyuncu: anahtar yok, yönetim mesajı yine kalkanlı
    await p.evaluate(() => { __R.sohbet_oku.resmi_yazabilir = false; geriGit(); }); await p.waitForTimeout(500);
    await p.evaluate(() => document.querySelector('[data-sh="kanal"][data-kanal="genel"]').click()); await p.waitForTimeout(800);
    const s5 = await p.evaluate(() => ({ anahtar: !!document.querySelector('#shyResmi'), yon: document.querySelectorAll('.shm.shy').length }));
    if (s5.anahtar || s5.yon !== 1) throw new Error('oyuncu görünümü: ' + JSON.stringify(s5));
    await cek('4_oyuncu');

    // 4) Resmî kanal (Meclis): yönetim mesajı tutanak satırı değil kalkanlı balon; söz hakkı yoksa anahtar yok
    await p.evaluate((m) => { __R.sohbet_oku = m; geriGit(); }, meclis()); await p.waitForTimeout(500);
    await p.evaluate(() => document.querySelector('[data-sh="kanal"][data-kanal="meclis"]').click()); await p.waitForTimeout(800);
    const s6 = await p.evaluate(() => ({ yon: document.querySelectorAll('.shm.shy').length, tutanak: document.querySelectorAll('.shm.shr').length, anahtar: !!document.querySelector('#shyResmi') }));
    if (s6.yon !== 1 || s6.tutanak !== 1 || s6.anahtar) throw new Error('Meclis görünümü: ' + JSON.stringify(s6));
    await cek('5_meclis');

    // 5) Sohbet nöbeti: "Yönetim adına sohbete yaz" penceresi
    await p.evaluate(() => ekranAc(mmNobet)); await p.waitForTimeout(900);
    await cek('6_nobet');
    const n1 = await p.evaluate(() => ({ dugme: !!document.querySelector('#mmNbR'), etiket: [...document.querySelectorAll('.mm-etiket')].some(x => x.textContent === 'yönetim adına') }));
    if (!n1.dugme || !n1.etiket) throw new Error('nöbet ekranı: ' + JSON.stringify(n1));
    // mesaja dokun → bu kanala yaz
    await p.evaluate(() => document.querySelector('.mm-mesaj[data-i="0"]').click()); await p.waitForTimeout(400);
    await cek('7_mesaj_islem');
    await p.evaluate(() => document.querySelector('#mmMsgR').click()); await p.waitForTimeout(500);
    const n2 = await p.evaluate(() => { const s = document.querySelector('#mmRK'), t = document.querySelector('#mmRM'); return { kanal: s.value, secenek: [...s.options].map(o => o.value), yazi: getComputedStyle(t).fontSize, secYazi: getComputedStyle(s).fontSize, uz: t.maxLength, imza: document.querySelector('#modal .mm-uyari').textContent, sablon: document.querySelectorAll('#mmRH button').length, dugmeY: document.querySelector('#mmROk').getBoundingClientRect().height }; });
    console.log(w, 'pencere', JSON.stringify(n2));
    if (n2.kanal !== 'il:34' || !n2.secenek.includes('genel') || !n2.secenek.includes('parti:1') || !n2.secenek.includes('og:15') || parseFloat(n2.yazi) < 16 || parseFloat(n2.secYazi) < 16 || n2.uz !== 1000 || !/Oyun Yöneticisi G-07/.test(n2.imza) || n2.sablon !== 5 || n2.dugmeY < 44) throw new Error('yazma penceresi');
    await cek('8_pencere');
    // boş gönderim engellenir
    await p.evaluate(() => document.querySelector('#mmROk').click()); await p.waitForTimeout(300);
    if (await say('mod_sohbet_yaz') !== 1) throw new Error('boş mesaj gönderildi');
    // hazır uyarı → gönder
    await p.evaluate(() => document.querySelector('#mmRH button').click()); await p.waitForTimeout(200);
    const n3 = await p.evaluate(() => ({ metin: document.querySelector('#mmRM').value, sayac: document.querySelector('#mmRS').textContent }));
    if (!/üslubunuza dikkat/.test(n3.metin) || n3.sayac !== n3.metin.length + ' / 1000') throw new Error('hazır uyarı: ' + JSON.stringify(n3));
    await cek('9_pencere_dolu');
    await p.evaluate(() => document.querySelector('#mmROk').click()); await p.waitForTimeout(600);
    const a9 = await son('mod_sohbet_yaz');
    if (await say('mod_sohbet_yaz') !== 2 || !a9 || a9.p_kanal !== 'il:34' || a9.p_metin !== n3.metin || await p.evaluate(() => !!document.querySelector('#mmRM'))) throw new Error('nöbetten gönderim: ' + JSON.stringify(a9));
    // üstteki düğme: seçili kanal yoksa Genel
    await p.evaluate(() => document.querySelector('#mmNbR').click()); await p.waitForTimeout(400);
    if (await p.evaluate(() => document.querySelector('#mmRK').value) !== 'genel') throw new Error('varsayılan kanal');
    await p.evaluate(() => modalKapat());
    // yetkisiz moderatör (Oyuncu Masası): düğmeler yok
    await p.evaluate(() => { __R.mod_sohbet_nobeti.resmi_yetki = false; __R.mod_sohbet_nobeti.tum_yetki = false; return mmNobet(); }); await p.waitForTimeout(700);
    await p.evaluate(() => document.querySelector('.mm-mesaj[data-i="0"]').click()); await p.waitForTimeout(400);
    const n4 = await p.evaluate(() => ({ ust: !!document.querySelector('#mmNbR'), msg: !!document.querySelector('#mmMsgR') }));
    if (n4.ust || n4.msg) throw new Error('yetkisiz moderatörde düğme göründü');
    await p.evaluate(() => modalKapat());
    // Moderasyon Merkezi: işlem adı
    await p.evaluate(() => ekranAc(modMerkezi)); await p.waitForTimeout(800);
    if (!/sohbete yönetim adına yazdı/.test(await p.evaluate(() => document.getElementById('icerik').textContent))) throw new Error('işlem adı');
    if (hatalar.length) throw new Error('Sayfa hataları: ' + JSON.stringify(hatalar));
    await p.close();
  }
  await b.close();
  console.log('TAMAM');
})().catch(e => { console.error('BAŞARISIZ:', e.message); process.exit(1); });
