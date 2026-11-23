// 23.11.2026 · Kullanıcı Sözleşmesi: kayıttan önce tam metin + iki zorunlu kutu, sunucuya onay kaydı (sahte API, 390 ve 320 px).
// Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/kullanici_sozlesmesi_arayuz.js [ekran-klasörü]
const fs = require('fs'), path = require('path'); const { chromium } = require('playwright');
const klasor = process.argv[2] || '/tmp/sozlesme_ekran'; fs.mkdirSync(klasor, { recursive: true });
const html0 = fs.readFileSync(path.join(__dirname, '../dist/index.html'), 'utf8');
const R = (kabul) => ({ sozlesme_durumum: { surum: '1.0', kabul, zorunlu: false }, sozlesme_onayla: { surum: '1.0', kabul: true }, harita: [], surum: { min_uygulama: '0' } });
const sayfa = (r, oturum) => html0.replace(/<script src="https:[^"]+"><\/script>/g, '').replace('<body>', '<body>' + `<script>window.__R=${JSON.stringify(r)};window.__OT=${JSON.stringify(oturum)};window.API_TEST={async rpc(fn,a){(window.__son=window.__son||[]).push([fn,a]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return window.__OT},async kayit(em,sf,meta){window.__kayit=[em,sf,meta];return {onayGerekli:true}},async giris(){},async cikis(){},async kodTekrar(){}};</script>`).replace('API = window.API_TEST || gercekApi();', 'API = window.API_TEST;');
const tasma = () => { const g = document.documentElement.clientWidth; return [...document.querySelectorAll('#app *')].filter(x => { const r = x.getBoundingClientRect(); return r.width > 0 && r.right > g + 1; }).map(x => x.tagName + '.' + x.className).slice(0, 5); };
// localStorage'ın çalışması için sayfa sahte bir https kökeninden açılır; diğer bütün istekler kesilir.
const ac = async (p, html) => { await p.route('**/*', r => r.request().url() === 'https://oyun.test/' ? r.fulfill({ status: 200, contentType: 'text/html; charset=utf-8', body: html }) : r.abort()); await p.goto('https://oyun.test/', { waitUntil: 'load' }); };
let hataVar = false; const dogrula = (k, m) => { if (!k) { hataVar = true; console.log('  ✗', m); } else console.log('  ✓', m); };
(async () => {
  for (const isaret of ['window.sozlesmeKapisi', 'sozlesme_onayla', 'Madde 18', "kayitEkrani(sozlesmeOnayli)"]) if (!html0.includes(isaret)) throw new Error('Derlemede yok: ' + isaret);
  if (/Gülveren/.test(html0)) throw new Error('Derlemede hâlâ "Gülveren" geçiyor');
  const b = await chromium.launch(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {});
  for (const w of [390, 320]) {
    console.log('— genişlik', w);
    // 1) Hesap oluştur → sözleşme → form → kayıt (meta ile)
    let p = await b.newPage({ viewport: { width: w, height: 844 }, deviceScaleFactor: 2 });
    const hatalar = []; p.on('pageerror', e => hatalar.push(e.message));
    await ac(p, sayfa(R(false), null)); await p.waitForTimeout(500);
    await p.evaluate(() => { API = window.API_TEST; try { localStorage.clear(); } catch (_) {} karsilama(); });
    await p.waitForTimeout(200);
    dogrula(await p.evaluate(() => /Kullanıcı Sözleşmesi/.test(document.querySelector('.karsila').textContent)), 'karşılamada "Kullanıcı Sözleşmesi" bağlantısı');
    await p.evaluate(() => kayitEkrani()); await p.waitForTimeout(300);
    let s = await p.evaluate(() => ({ baslik: document.querySelector('.karsila h1').textContent, kutu: !!document.querySelector('#sozKutu'), madde18: /Madde 18/.test(document.querySelector('#sozKutu').textContent), form: !!document.querySelector('#eposta'), kapali: document.querySelector('#sozKabul').disabled, yas: /18 yaşından büyüğüm/.test(document.body.textContent), guncel: /Gülveren/.test(document.body.textContent) }));
    dogrula(s.baslik === 'Kullanıcı Sözleşmesi' && s.kutu && s.madde18 && !s.form, 'Hesap oluştur önce tam sözleşme metnini açar, form açılmaz');
    dogrula(s.kapali, 'kutular işaretlenmeden "Kabul ediyorum" kapalı');
    dogrula(s.yas && !s.guncel, '18 yaş kutusu var, eski unvan yok');
    dogrula((await p.evaluate(tasma)).length === 0, 'sözleşme ekranında taşma yok ' + JSON.stringify(await p.evaluate(tasma)));
    await p.screenshot({ path: `${klasor}/${w}_1_sozlesme.png` });
    await p.click('#sozK1');
    dogrula(await p.evaluate(() => document.querySelector('#sozKabul').disabled), 'tek kutu yetmez');
    await p.click('#sozK2');
    dogrula(await p.evaluate(() => !document.querySelector('#sozKabul').disabled), 'iki kutu işaretlenince açılır');
    await p.evaluate(() => { document.querySelector('#sozKutu').scrollTop = 1e6; document.querySelector('.karsila').scrollTop = 1e6; }); await p.waitForTimeout(150);
    dogrula(await p.evaluate(() => { const [a, b] = [...document.querySelectorAll('.soz-onay')].map(x => x.getBoundingClientRect()); return a.bottom <= b.top + 1; }), 'onay kutuları üst üste binmiyor');
    await p.screenshot({ path: `${klasor}/${w}_2_isaretli.png` });
    await p.click('#sozKabul'); await p.waitForTimeout(200);
    s = await p.evaluate(() => ({ form: !!document.querySelector('#eposta'), not: !!document.querySelector('.soz-kabul-not'), eskiKutu: !!document.querySelector('#kvkk') }));
    dogrula(s.form && s.not && !s.eskiKutu, 'kabulden sonra kayıt formu, "kabul ettin" notu; eski tek kutu yok');
    dogrula((await p.evaluate(tasma)).length === 0, 'kayıt formunda taşma yok');
    await p.screenshot({ path: `${klasor}/${w}_3_form.png` });
    await p.fill('#eposta', 'Yeni@Ornek.com'); await p.fill('#sifre', 'gizli12345'); await p.fill('#sifre2', 'gizli12345');
    await p.click('#kaydol'); await p.waitForTimeout(300);
    s = await p.evaluate(() => ({ k: window.__kayit, yerel: JSON.parse(localStorage.getItem('so_sozlesme_onay') || 'null') }));
    dogrula(s.k && s.k[2] && s.k[2].sozlesme_surum === '1.0' && !!s.k[2].sozlesme_onay_at, 'signUp hesap bilgisine sözleşme sürümü ve anı yazılır');
    dogrula(s.yerel && s.yerel.email === 'yeni@ornek.com', 'cihazdaki kabul bu e-postaya bağlanır');
    // Kabul etmiyorum → karşılama
    await p.evaluate(() => kayitEkrani()); await p.waitForTimeout(150);
    await p.click('#sozRet'); await p.waitForTimeout(200);
    dogrula(await p.evaluate(() => !document.querySelector('#sozKutu') && !document.querySelector('#eposta') && /Hesap oluştur/.test(document.body.textContent)), '"Kabul etmiyorum" karşılamaya döner, form açılmaz');
    dogrula(hatalar.length === 0, 'sayfa hatası yok ' + JSON.stringify(hatalar));
    await p.close();

    // 2) Doğrulamadan sonra: aynı cihazdaki kabul sunucuya "kayit" olarak yazılır, sözleşme ikinci kez sorulmaz
    p = await b.newPage({ viewport: { width: w, height: 844 } }); await ac(p, sayfa(R(false), { email: 'yeni@ornek.com', meta: {} })); await p.waitForTimeout(400);
    await p.evaluate(() => { API = window.API_TEST; localStorage.setItem('so_sozlesme_onay', JSON.stringify({ surum: '1.0', at: new Date().toISOString(), email: 'yeni@ornek.com' })); D.durum = { kayit_durumu: true }; });
    await p.evaluate(() => profilOlusturEkrani()); await p.waitForTimeout(400);
    s = await p.evaluate(() => ({ cagri: (window.__son || []).filter(x => x[0] === 'sozlesme_onayla'), profil: !!document.querySelector('#kad'), soz: !!document.querySelector('#sozKutu') }));
    dogrula(s.cagri.length === 1 && s.cagri[0][1].p_kaynak === 'kayit' && s.cagri[0][1].p_surum === '1.0' && s.profil && !s.soz, 'cihazdaki kabul sunucuya yazılır, profil ekranı açılır');
    await p.close();

    // 3) Başka cihazda doğrulama: hesap bilgisindeki kabul yeterli
    p = await b.newPage({ viewport: { width: w, height: 844 } }); await ac(p, sayfa(R(false), { email: 'x@y.com', meta: { sozlesme_surum: '1.0', sozlesme_onay_at: new Date().toISOString() } })); await p.waitForTimeout(400);
    await p.evaluate(() => { API = window.API_TEST; localStorage.clear(); D.durum = { kayit_durumu: true }; });
    await p.evaluate(() => profilOlusturEkrani()); await p.waitForTimeout(400);
    s = await p.evaluate(() => ({ cagri: (window.__son || []).filter(x => x[0] === 'sozlesme_onayla').length, profil: !!document.querySelector('#kad') }));
    dogrula(s.cagri === 1 && s.profil, 'hesap bilgisindeki kabul sunucuya yazılır');
    await p.close();

    // 4) Eski yoldan kayıt olmuş, kabul kaydı yok: oyuna başlamadan önce sözleşme açılır; başka hesabın cihaz kaydı sayılmaz
    p = await b.newPage({ viewport: { width: w, height: 844 } }); await ac(p, sayfa(R(false), { email: 'eski@ornek.com', meta: {} })); await p.waitForTimeout(400);
    await p.evaluate(() => { API = window.API_TEST; localStorage.setItem('so_sozlesme_onay', JSON.stringify({ surum: '1.0', at: new Date().toISOString(), email: 'baska@ornek.com' })); D.durum = { kayit_durumu: true }; });
    await p.evaluate(() => profilOlusturEkrani()); await p.waitForTimeout(400);
    s = await p.evaluate(() => ({ soz: !!document.querySelector('#sozKutu'), profil: !!document.querySelector('#kad'), cagri: (window.__son || []).filter(x => x[0] === 'sozlesme_onayla').length }));
    dogrula(s.soz && !s.profil && s.cagri === 0, 'kabul kaydı olmayan hesapta profil ekranı yerine sözleşme açılır');
    await p.screenshot({ path: `${klasor}/${w}_4_giris.png` });
    await p.evaluate(() => { window.basla = async () => { window.__basla = true; }; });
    await p.click('#sozK1'); await p.click('#sozK2'); await p.click('#sozKabul'); await p.waitForTimeout(300);
    s = await p.evaluate(() => ({ c: (window.__son || []).filter(x => x[0] === 'sozlesme_onayla').map(x => x[1].p_kaynak), b: !!window.__basla }));
    dogrula(s.c.length === 1 && s.c[0] === 'giris' && s.b, 'onaylayınca sunucuya "giris" kaydı yazılır ve oyun devam eder');
    await p.evaluate(() => sozlesmeEkrani('giris')); await p.click('#sozRet'); await p.waitForTimeout(150);
    dogrula(await p.evaluate(() => /Sözleşme kabul edilmedi/.test(document.body.textContent) && /Çıkış yap/.test(document.body.textContent)), '"Kabul etmiyorum" oyuna sokmaz, çıkış sunar');
    await p.close();

    // 5) Kabul kaydı olan hesap: sözleşme tekrar sorulmaz
    p = await b.newPage({ viewport: { width: w, height: 844 } }); await ac(p, sayfa(R(true), { email: 'a@b.com', meta: {} })); await p.waitForTimeout(400);
    await p.evaluate(() => { API = window.API_TEST; D.durum = { kayit_durumu: true }; });
    await p.evaluate(() => profilOlusturEkrani()); await p.waitForTimeout(400);
    dogrula(await p.evaluate(() => !!document.querySelector('#kad') && !document.querySelector('#sozKutu')), 'kabul eden hesaba sözleşme yeniden sorulmaz');
    // Ben › Kullanıcı Sözleşmesi penceresi
    await p.evaluate(() => metinGoster('sozlesme')); await p.waitForTimeout(200);
    dogrula(await p.evaluate(() => /Madde 18/.test(document.querySelector('.modal').textContent)), 'Kullanıcı Sözleşmesi penceresi açılır');
    await p.evaluate(() => { modalKapat(); metinGoster('gizlilik'); }); await p.waitForTimeout(200);
    dogrula(await p.evaluate(() => { const t = document.querySelector('.modal').textContent; return /Veri sorumlusu: FeniksKlein\./.test(t) && /görüntülenebilir/.test(t) && /Frankfurt/.test(t); }), 'Gizlilik metni güncel (veri sorumlusu, denetim, sunucu yeri)');
    await p.close();
  }
  await b.close();
  if (hataVar) { console.log('BAŞARISIZ'); process.exit(1); }
  console.log('Hepsi geçti. Ekranlar:', klasor);
})().catch(e => { console.error(e); process.exit(1); });
