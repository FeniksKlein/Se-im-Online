// Mağaza uçtan uca arayüz testi: docs/index.html + magaza.js yerel Postgres'e bağlanır. Telefon mağazası (RevenueCat)
// taklit edilir: "satın al" düğmesi, mağazanın onayından sonra sunucuya gelen olayı (odeme_isle) yerel veritabanına iletir.
// Sınar: vitrin, ₺ paketi, Başlangıç Paketi + Kart, Kart günlük ödülü (Mağaza ve Hayat), reklamsız ödül (reklam gösterilmez),
// Destekçi rozeti sohbette ve oyuncu kartında, web'de yalnız vitrin.
// Ön koşul: yerel oyun_test veritabanında 113/115 uygulanmış olmalı.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/magaza_arayuz.js [ekran-klasörü]
const http = require('http'), fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const kok = path.join(__dirname, '../..');
const htmlYol = path.join(kok, 'docs/index.html');
const cikti = process.argv[2] || path.join(__dirname, 'ekran/magaza');
fs.mkdirSync(cikti, { recursive: true });
const psql = (sql) => execFileSync('psql', ['-h', '/tmp', '-U', 'postgres', '-d', 'oyun_test', '-At', '-q', '-v', 'ON_ERROR_STOP=1', '-c', sql], { encoding: 'utf8', maxBuffer: 64 << 20 }).trim();
const lit = (v) => v === null || v === undefined ? 'null' : typeof v === 'number' ? String(v) : typeof v === 'boolean' ? String(v)
  : typeof v === 'object' ? "'" + JSON.stringify(v).replace(/'/g, "''") + "'::jsonb" : "'" + String(v).replace(/'/g, "''") + "'";
function rpc(uid, fn, args) {
  if (!/^[a-z_0-9]+$/.test(fn)) throw new Error('geçersiz fonksiyon');
  const a = Object.entries(args || {}).map(([k, v]) => `${k} => ${lit(v)}`).join(', ');
  const out = psql(`select set_config('request.jwt.claim.sub', '${uid || ''}', false); select coalesce(to_jsonb(public.${fn}(${a})), 'null'::jsonb);`);
  const s = out.split('\n'); return JSON.parse(s[s.length - 1]);
}
const hataMetni = (err) => String(err.stderr || err.message).split('\n').find(l => /ERROR/.test(l))?.replace(/^.*ERROR:\s+/, '') || err.message;
const IL = (ad) => +psql(`select id from oyun.iller where ad='${ad}'`);
const ek = Math.random().toString(36).slice(2, 6);
function oyuncu(kad) {
  const u = psql(`insert into auth.users(email, email_confirmed_at) values ('${kad.toLowerCase()}@t.com', now()) returning id`).split('\n')[0];
  rpc(u, 'profil_olustur', { p_kad: kad, p_il: IL('İzmir') });
  psql(`update oyun.profiller set olusturma = now() - interval '20 days', son_gorulme = now() where id='${u}'`);
  return u;
}
psql("update oyun.ayarlar set test_simdi = null, push_aktif = false");
const ALICI = 'Alici' + ek, DIGER = 'Diger' + ek;
const a = oyuncu(ALICI), b = oyuncu(DIGER);
psql(`insert into oyun.mesajlar(kanal, user_id, metin, zaman) values ('genel', '${a}', 'Merhaba meydan', now() - interval '1 minute')`);

const FIYAT = { baslangic_paketi: '₺39,99', siyaset_karti: '₺119,99', para_cep: '₺49,99', para_kampanya: '₺99,99', para_secim: '₺199,99', para_servet: '₺499,99', reklamsiz_odul: '₺149,99', destekci_rozeti: '₺79,99' };
const KOPRU = `<script>
window.API_TEST = (function(){
  const kad = new URLSearchParams(location.search).get('kad') || '';
  let uid = null;
  async function post(u, b){ const r = await fetch(u, { method: 'POST', body: JSON.stringify(b) }); const j = await r.json(); if (j.hata) throw new Error(j.hata); return j.veri; }
  return {
    async rpc(fn, args){ if (!uid && kad) uid = await post('/uid', { kad }); return post('/rpc', { uid, fn, args }); },
    async oturum(){ if (!kad) return null; uid = await post('/uid', { kad }); return uid ? { email: kad + '@yerel' } : null; },
    async kayit(){ return { onayGerekli: true }; }, async kodDogrula(){}, async kodTekrar(){}, async giris(){}, async sifreSifirla(){}, async sifreGuncelle(){}, async cikis(){},
    uid(){ return uid; }, post
  };
})();
window.PUSH_TEST = true;
</script>`;
const html = fs.readFileSync(htmlYol, 'utf8')
  .replace(/<script src="https:[^"]+"><\/script>/g, '')
  .replace(/<script src="([\w.-]+\.js)(?:\?[^"]*)?"><\/script>/g, (t, ad) => {
    const f = path.join(path.dirname(htmlYol), ad);
    return fs.existsSync(f) ? '<script>' + fs.readFileSync(f, 'utf8') + '</script>' : t;
  })
  .replace('<body>', '<body>' + KOPRU)
  .replace('API = window.API_TEST || gercekApi();', 'API = window.YKM_SAR ? YKM_SAR(window.API_TEST) : window.API_TEST;');
let islemNo = 0;
const sunucu = http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET') {
      const ad = decodeURIComponent((req.url || '').split('?')[0]).replace(/^\//, '');
      const js = path.join(path.dirname(htmlYol), ad);
      if (/^[\w.-]+\.js$/.test(ad) && fs.existsSync(js)) { res.writeHead(200, { 'content-type': 'text/javascript; charset=utf-8' }); return res.end(fs.readFileSync(js)); }
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' }); return res.end(html);
    }
    let g = ''; for await (const p of req) g += p; const x = JSON.parse(g || '{}');
    let veri;
    if (req.url === '/uid') veri = psql(`select id from oyun.profiller where lower(kad)=lower(${lit(x.kad)})`) || null;
    else if (req.url === '/magaza_onay') {   // mağaza onayı → RevenueCat → odeme_isle (service_role yolu)
      const olay = { type: 'NON_RENEWING_PURCHASE', app_user_id: x.uid, product_id: x.urun, transaction_id: 'ui_' + ek + '_' + (++islemNo), price_in_purchased_currency: 49.99, currency: 'TRY' };
      veri = JSON.parse(psql(`select public.odeme_isle(${lit({ event: olay })})`));
    } else veri = rpc(x.uid, x.fn, x.args);
    res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ veri }));
  } catch (err) { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ hata: hataMetni(err) })); }
}).listen(8794, '127.0.0.1');

const ok = (m) => console.log('  ✓', m);
function esit(x, y, m) { if (String(x) !== String(y)) throw new Error(`${m}: beklenen ${y}, gelen ${x}`); }
const para = (u) => +psql(`select para from oyun.cuzdan where user_id='${u}'`);
(async () => {
  const tarayici = await chromium.launch();
  const ctx = await tarayici.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
  const hatalar = [];
  const sayfa = async (kad, telefon) => {
    const p = await ctx.newPage(); p.on('pageerror', e => hatalar.push(kad + ': ' + e.message));
    await p.goto('http://127.0.0.1:8794/?kad=' + encodeURIComponent(kad)); await p.waitForSelector('.sekmeler', { timeout: 15000 }); await p.waitForTimeout(800);
    if (telefon) await p.evaluate((F) => {   // telefon mağazası taklidi
      window.__reklam = 0;
      ODEME.eklenti = () => ({ restorePurchases: async () => ({}) }); ODEME.hazirla = async () => true;
      ODEME.urunler = async (ids) => ids.map(id => ({ identifier: id, priceString: F[id] }));
      ODEME.al = async (u) => { await API_TEST.post('/magaza_onay', { uid: API_TEST.uid(), urun: u.identifier }); return {}; };
      window.Capacitor = { isNativePlatform: () => true, getPlatform: () => 'android', Plugins: { AdMob: { initialize: async () => { window.__reklam++; }, addListener: async () => ({ remove(){} }), prepareRewardVideoAd: async () => {}, showRewardVideoAd: async () => ({ amount: 1 }) } } };
    }, FIYAT);
    return p;
  };
  const foto = (p, ad) => p.screenshot({ path: path.join(cikti, ad + '.png') });
  const bekle = (p, ms) => p.waitForTimeout(ms || 700);
  try {
    // 1) Web: yalnız vitrin, fiyatlar bilgi amaçlı ve düğmeler kapalı
    const w = await sayfa(ALICI, false);
    await w.evaluate(() => magazaModal()); await w.waitForSelector('#mgEkran', { state: 'attached' }); await bekle(w, 600); await foto(w, '01_web_vitrin');
    const webDugme = await w.$$eval('.mg-fiyat', l => l.map(x => [x.textContent.trim(), x.disabled]));
    if (!webDugme.length || webDugme.some(([, d]) => !d)) throw new Error('Web vitrininde satın alma düğmesi açık olmamalı');
    if (!(await w.textContent('#app')).includes('Satın alma telefonda')) throw new Error('Web uyarısı yok');
    await w.close(); ok('Web: vitrin ve fiyatlar görünüyor, satın alma telefona yönlendiriliyor');

    // 2) Telefonda ₺ paketi
    const p = await sayfa(ALICI, true);
    await p.evaluate(() => ekranAc(magazaEkrani)); await p.waitForSelector('[data-urun="para_kampanya"]'); await foto(p, '02_magaza');
    const p0 = para(a);
    await p.click('[data-urun="para_kampanya"]'); await p.waitForFunction(() => /eklendi/.test(document.querySelector('.toast')?.textContent || ''), null, { timeout: 15000 });
    esit(para(a), p0 + 125000, '₺ paketi'); ok('₺ paketi: ödeme sonrası cüzdana 125.000 ₺ ekleniyor');

    // 3) Başlangıç Paketi → Kart aktif, paket bir daha alınamıyor, Kart ödülü
    await p.click('[data-urun="baslangic_paketi"]'); await p.waitForSelector('#mgKartAl', { timeout: 15000 }); await bekle(p, 400); await foto(p, '03_kart_aktif');
    if (await p.$('[data-urun="baslangic_paketi"]')) throw new Error('Başlangıç Paketi ikinci kez satılmamalı');
    const p1 = para(a);
    await p.click('#mgKartAl'); await p.waitForFunction(() => /Kartı ödülü/.test(document.querySelector('.toast')?.textContent || ''), null, { timeout: 10000 });
    esit(para(a), p1 + 7500, 'Kart ödülü'); await bekle(p, 500);
    if (!(await p.textContent('#app')).includes('Bugün alındı')) throw new Error('Kart ödülü alındı olarak görünmüyor');
    ok('Başlangıç Paketi: 100.000 ₺ + Kart; paket bir kez; Kart günlük ödülü alınıyor');

    // 4) Reklamsız ödül: Kart varken Hayat'ta "Ödülü al", reklam gösterilmeden ödül
    await p.evaluate(() => sekmeAc('hayat')); await p.waitForSelector('#hReklam'); await bekle(p, 1200); await foto(p, '04_hayat_kart');
    esit((await p.textContent('#hReklam')).trim().startsWith('Ödülü al'), true, 'reklamsız etiket');
    if (!(await p.$('#mgHayat'))) throw new Error('Hayat ekranında Kart kartı yok');
    const p2 = para(a);
    await p.click('#hReklam'); await p.waitForFunction(() => /Reklam ödülü/.test(document.querySelector('.toast')?.textContent || ''), null, { timeout: 10000 });
    esit(await p.evaluate(() => window.__reklam), 0, 'reklam gösterilmemeli');
    if (!(para(a) > p2)) throw new Error('Reklamsız ödül verilmedi');
    ok('Kart sahibine reklam gösterilmeden reklam ödülü veriliyor');

    // 5) Destekçi Rozeti → kalıcı, sohbette ve oyuncu kartında yıldız
    await p.evaluate(() => ekranAc(magazaEkrani)); await p.waitForSelector('[data-urun="destekci_rozeti"]');
    await p.click('[data-urun="destekci_rozeti"]'); await p.waitForFunction(() => /Sende var/.test(document.querySelector('#app')?.textContent || ''), null, { timeout: 15000 });
    await p.evaluate(() => { const m = document.querySelector('#icerik') || document.scrollingElement; m.scrollTop = m.scrollHeight; }); await bekle(p, 300); await foto(p, '05_kalici_sahip');
    esit(psql(`select count(*) from oyun.oyuncu_hak where user_id='${a}' and hak='destekci' and aktif`), 1, 'destekçi hakkı');
    await p.close();
    const d = await sayfa(DIGER, false);
    await d.evaluate(() => ekranAc(() => sohbetEkrani('genel'))); await d.waitForSelector(`.balon[data-kad="${ALICI}"]`); await bekle(d, 600);
    if (!(await d.$(`.balon[data-kad="${ALICI}"] .mg-rz .mg-yildiz`))) throw new Error('Sohbette Destekçi yıldızı yok');
    if (!(await d.$(`.balon[data-kad="${ALICI}"] .mg-rz .mg-kart`))) throw new Error('Sohbette Kart rozeti yok');
    await foto(d, '06_sohbet_rozet');
    await d.evaluate((k) => oyuncuKart(k), ALICI); await d.waitForSelector('#modal .modal h3 .mg-rz', { timeout: 10000 }); await bekle(d, 300); await foto(d, '07_oyuncu_karti_rozet');
    await d.close(); ok('Destekçi yıldızı ve Kart rozeti başka oyuncunun sohbetinde ve oyuncu kartında görünüyor');

    if (hatalar.length) throw new Error('Sayfa hataları:\n' + hatalar.join('\n'));
    console.log('magaza_arayuz: hepsi geçti (ekranlar: ' + cikti + ')');
  } catch (err) {
    console.log('HATA:', err.message);
    process.exitCode = 1;
  } finally { await tarayici.close(); sunucu.close(); }
})();
