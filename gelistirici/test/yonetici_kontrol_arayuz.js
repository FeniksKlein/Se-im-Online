// Kontrol Merkezi uçtan uca arayüz testi: docs/index.html (canlı web ile aynı dosyalar) yerel Postgres'e bağlanır,
// gerçek tarayıcıda yönetici olarak para yükler, göreve atar, engeller, veri düzenler ve geri alır; engellenen ve
// bakım sırasındaki oyuncunun ekranlarını, duyuru bandını ve Adaylıklarım kartını sınar.
// Ön koşul: yerel oyun_test veritabanı kurulu ve 113_yonetici_kontrol.sql uygulanmış olmalı.
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/yonetici_kontrol_arayuz.js [ekran-klasörü]
const http = require('http'), fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const kok = path.join(__dirname, '../..');
const htmlYol = process.env.HTML_PATH || path.join(kok, 'docs/index.html');
const cikti = process.argv[2] || path.join(__dirname, 'ekran/yonetici');
fs.mkdirSync(cikti, { recursive: true });

const psql = (sql) => execFileSync('psql', ['-h', '/tmp', '-U', 'postgres', '-d', 'oyun_test', '-At', '-q', '-v', 'ON_ERROR_STOP=1', '-c', sql], { encoding: 'utf8', maxBuffer: 64 << 20 }).trim();
const lit = (v) => v === null || v === undefined ? 'null' : typeof v === 'number' ? String(v) : typeof v === 'boolean' ? String(v)
  : Array.isArray(v) ? "'{" + v.map(x => '"' + String(x).replace(/["\\]/g, '\\$&') + '"').join(',') + "}'"
  : typeof v === 'object' ? "'" + JSON.stringify(v).replace(/'/g, "''") + "'::jsonb" : "'" + String(v).replace(/'/g, "''") + "'";
function rpc(uid, fn, args) {
  if (!/^[a-z_0-9]+$/.test(fn)) throw new Error('geçersiz fonksiyon');
  const a = Object.entries(args || {}).map(([k, v]) => `${k} => ${lit(v)}`).join(', ');
  const out = psql(`select set_config('request.jwt.claim.sub', '${uid || ''}', false); select coalesce(to_jsonb(public.${fn}(${a})), 'null'::jsonb);`);
  const s = out.split('\n'); return JSON.parse(s[s.length - 1]);
}
const hataMetni = (err) => String(err.stderr || err.message).split('\n').find(l => /ERROR/.test(l))?.replace(/^.*ERROR:\s+/, '') || err.message;

// ---- Tohum veri
const IL = (ad) => +psql(`select id from oyun.iller where ad='${ad}'`);
function oyuncu(kad, il) {
  const u = psql(`insert into auth.users(email, email_confirmed_at) values ('${kad.toLowerCase()}@t.com', now()) returning id`).split('\n')[0];
  rpc(u, 'profil_olustur', { p_kad: kad, p_il: IL(il) });
  psql(`update oyun.profiller set olusturma = now() - interval '20 days', son_gorulme = now() where id='${u}'`);
  return u;
}
psql("update oyun.ayarlar set test_simdi = null, push_aktif = false");
const [pa] = psql('select id from oyun.partiler where not kapali order by id limit 1').split('\n').map(Number);
const sahip = oyuncu('Sahip', 'Ankara'); psql(`update oyun.profiller set yonetici = true where id='${sahip}'`);
const a = oyuncu('OyuncuA', 'İzmir'), b = oyuncu('OyuncuB', 'İzmir');
psql(`update oyun.profiller set parti_id=${pa} where id in ('${a}','${b}')`);

// ---- Sunucu (docs/index.html + yerel scriptler + yerel veritabanı köprüsü)
const KOPRU = `<script>
window.API_TEST = (function(){
  const kad = new URLSearchParams(location.search).get('kad') || '';
  let uid = null;
  async function post(u, b){ const r = await fetch(u, { method: 'POST', body: JSON.stringify(b) }); const j = await r.json(); if (j.hata) throw new Error(j.hata); return j.veri; }
  return {
    async rpc(fn, args){ if (!uid && kad) uid = await post('/uid', { kad }); return post('/rpc', { uid, fn, args }); },
    async oturum(){ if (!kad) return null; uid = await post('/uid', { kad }); return uid ? { email: kad + '@yerel' } : null; },
    async kayit(){ return { onayGerekli: true }; }, async kodDogrula(){}, async kodTekrar(){}, async giris(){}, async sifreSifirla(){}, async sifreGuncelle(){}, async cikis(){}
  };
})();
</script>`;
const html = fs.readFileSync(htmlYol, 'utf8')
  .replace(/<script src="https:[^"]+"><\/script>/g, '')
  .replace(/<script src="([\w.-]+\.js)(?:\?[^"]*)?"><\/script>/g, (t, ad) => {
    const f = path.join(path.dirname(htmlYol), ad);
    return fs.existsSync(f) ? '<script>' + fs.readFileSync(f, 'utf8') + '</script>' : t;
  })
  .replace('<body>', '<body>' + KOPRU)
  // API_TEST varsa uygulama onu kullanır; gercekApi sarmalayıcısının da çalışması için load'da gercekApi() çağrılsın
  .replace('API = window.API_TEST || gercekApi();', 'API = window.YKM_SAR ? YKM_SAR(window.API_TEST) : window.API_TEST;');
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
    else veri = rpc(x.uid, x.fn, x.args);
    res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ veri }));
  } catch (err) { res.writeHead(200, { 'content-type': 'application/json' }); res.end(JSON.stringify({ hata: hataMetni(err) })); }
}).listen(8791, '127.0.0.1');

const ok = (m) => console.log('  ✓', m);
function esit(a1, b1, m) { if (String(a1) !== String(b1)) throw new Error(`${m}: beklenen ${b1}, gelen ${a1}`); }
(async () => {
  const tarayici = await chromium.launch();
  const ctx = await tarayici.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
  const hatalar = [];
  const sayfa = async (kad) => { const p = await ctx.newPage(); p.on('pageerror', e => hatalar.push(kad + ': ' + e.message)); await p.goto('http://127.0.0.1:8791/?kad=' + encodeURIComponent(kad)); return p; };
  const foto = (p, ad) => p.screenshot({ path: path.join(cikti, ad + '.png') });
  const onayla = async (p) => { await p.waitForSelector('#modal #evet'); await p.click('#modal #evet'); };
  const bekle = (p, ms) => p.waitForTimeout(ms || 700);
  try {
    // 1) Yönetici paneli → Kontrol Merkezi kartı
    const y = await sayfa('Sahip'); await y.waitForSelector('.sekmeler', { timeout: 15000 }); await bekle(y, 1000);
    await y.evaluate(() => ekranAc(yoneticiEkrani)); await y.waitForSelector('.km-giris'); await foto(y, '01_yonetici_paneli'); ok('Yönetici panelinde Kontrol Merkezi kartı');
    await y.click('.km-giris button'); await y.waitForSelector('#kmHedef'); await bekle(y); await foto(y, '02_pano');

    // 2) Herkese para
    const once = +psql('select sum(para) from oyun.cuzdan'); const kisi = +psql('select count(*) from oyun.profiller where not yasakli');
    await y.fill('#kmTutar', '2500'); await y.fill('#kmNeden', 'Açılış ikramiyesi'); await y.click('#kmParaGonder'); await onayla(y); await bekle(y, 1200);
    esit(+psql('select sum(para) from oyun.cuzdan'), once + 2500 * kisi, 'herkese para'); ok('Pano: herkese para yükleme');

    // 3) Oyuncular → OyuncuA → para, görev, engel
    await y.click('[data-km-sekme="oyuncular"]'); await y.waitForSelector('[data-oy="OyuncuA"]'); await foto(y, '03_oyuncular');
    await y.click('[data-oy="OyuncuA"]'); await y.waitForSelector('#kmPara'); await foto(y, '04_oyuncu');
    const pA = +psql(`select para from oyun.cuzdan where user_id='${a}'`);
    await y.click('#kmPara'); await y.click('[data-hizli="10000"]'); await y.fill('#kmTN', 'Ödül'); await y.click('#kmTK'); await bekle(y, 1200);
    esit(+psql(`select para from oyun.cuzdan where user_id='${a}'`), pA + 10000, 'oyuncuya para'); ok('Oyuncu kartından para');
    await y.click('#kmGorev'); await y.waitForSelector('#kmGTur'); await y.selectOption('#kmGTur', 'bakan'); await y.selectOption('#kmGBak', 'maliye'); await foto(y, '05_gorev_modal');
    await y.click('#kmGK'); await bekle(y, 1200);
    esit(psql(`select count(*) from oyun.makamlar where user_id='${a}' and tur='bakan' and bakanlik='maliye' and bit is null`), 1, 'bakan ataması'); ok('Göreve atama (Hazine ve Maliye Bakanı)');
    await y.click('#kmEngel'); await y.waitForSelector('#kmESure'); await y.selectOption('#kmESure', '1'); await y.fill('#kmENeden', 'Test engeli'); await foto(y, '06_engel_modal');
    await y.click('#kmEK'); await bekle(y, 1200);
    esit(psql(`select yasakli from oyun.profiller where id='${a}'`), 't', 'engel'); ok('Süreli engel');
    await foto(y, '07_oyuncu_engelli');

    // 4) Engellenen oyuncunun ekranı
    const pa1 = await sayfa('OyuncuA'); await pa1.waitForSelector('text=Hesabın engellendi', { timeout: 15000 }); await bekle(pa1, 400); await foto(pa1, '08_engelli_oyuncu');
    const t1 = await pa1.textContent('#app'); if (!/Test engeli/.test(t1)) throw new Error('Engel gerekçesi görünmüyor: ' + t1);
    await pa1.close(); ok('Engellenen oyuncu gerekçeli tam ekran görüyor');

    // 5) Görevler sekmesi + görevden al
    await y.evaluate(() => { kontrolMerkezi('gorevler'); }); await y.waitForSelector('#kmYeniGorev'); await bekle(y); await foto(y, '09_gorevler');
    const mid = psql(`select id from oyun.makamlar where user_id='${a}' and tur='bakan' and bit is null`);
    await y.click(`[data-km-al="${mid}"]`); await onayla(y); await bekle(y, 1200);
    esit(psql(`select count(*) from oyun.makamlar where id=${mid} and bit is null`), 0, 'görevden alma'); ok('Görevler listesinden görevden alma');

    // 6) Veri düzenleyici: cuzdan kıdem → kaydet → geçmişten geri al
    await y.click('[data-km-sekme="veri"]'); await y.waitForSelector('[data-sik="oyun.cuzdan"]'); await foto(y, '10_veri_tablolar');
    await y.click('[data-sik="oyun.cuzdan"]'); await y.waitForSelector('#kmVSutun');
    await y.selectOption('#kmVSutun', 'user_id'); await y.fill('#kmVDeger', b); await y.click('#kmVUygula'); await y.waitForSelector('.km-veri-kart'); await foto(y, '11_veri_satirlar');
    await y.click('.km-veri-kart'); await y.waitForSelector('[data-c="kidem"]'); await foto(y, '12_veri_satir_modal');
    const k0 = psql(`select kidem from oyun.cuzdan where user_id='${b}'`);
    await y.fill('[data-c="kidem"]', '321'); await y.click('#kmSKaydet'); await bekle(y, 1200);
    esit(+psql(`select kidem from oyun.cuzdan where user_id='${b}'`), 321, 'veri kaydet');
    await y.click('[data-km-sekme="gecmis"]'); await y.waitForSelector('[data-km-geri]'); await foto(y, '13_gecmis');
    await y.click('[data-km-geri]'); await onayla(y); await bekle(y, 1200);
    esit(+psql(`select kidem from oyun.cuzdan where user_id='${b}'`), +k0, 'geri al'); ok('Veri düzenleyici: satır düzenle ve Geçmiş’ten geri al');

    // 7) Diğer sekmeler açılıyor
    for (const s of ['ekonomi', 'secimler', 'ayarlar']) { await y.click(`[data-km-sekme="${s}"]`); await bekle(y, 1300); await foto(y, '14_' + s); if (await y.$('#kmIc .bos')) { const tx = await y.textContent('#kmIc .bos'); if (/hata|bulunamadı|does not/i.test(tx)) throw new Error(s + ': ' + tx); } }
    ok('Ekonomi, Seçimler, Ayarlar sekmeleri');

    // 8) Bakım modu + duyuru bandı (Pano › Hızlı ayarlar)
    await y.click('[data-km-sekme="pano"]'); await y.waitForSelector('#kmBakim');
    await y.check('#kmBakim'); await y.fill('#kmBand', 'Bu akşam büyük miting!'); await y.click('#kmHizliKaydet'); await onayla(y); await bekle(y, 1500);
    esit(psql("select deger::text from oyun.uygulama_ayar where anahtar='bakim'"), 'true', 'bakım açık');
    const pb1 = await sayfa('OyuncuB'); await pb1.waitForSelector('text=Bakım çalışması', { timeout: 15000 }); await bekle(pb1, 300); await foto(pb1, '15_bakim_oyuncu'); await pb1.close();
    const anon = await sayfa(''); await anon.waitForSelector('text=Bakım çalışması', { timeout: 15000 }); await bekle(anon, 300); await foto(anon, '16_bakim_girissiz'); await anon.close();
    await y.evaluate(() => sekmeAc('gundem')); await y.waitForSelector('.km-bakim-ust'); await foto(y, '17_yonetici_bakimda');
    rpc(sahip, 'yk_uygulama_ayar_kaydet', { p: { bakim: false } });
    const pb2 = await sayfa('OyuncuB'); await pb2.waitForSelector('.km-band', { timeout: 15000 }); await bekle(pb2, 500); await foto(pb2, '18_duyuru_bandi');
    ok('Bakım modunda oyuncu ve giriş yapmamış kişi bakım ekranı, yönetici uyarı bandı; duyuru bandı herkese');

    // 9) Adaylıklarım kartı (yaklaşan bir seçime aday kaydı)
    const sid = psql("select id from oyun.secimler where durum='bekliyor' and oy_bas > oyun.simdi() and tur in ('mv_on','bel_on','kurultay','cb_on') order by oy_bas limit 1");
    if (sid && psql("select to_regprocedure('public.adayliklarim()') is not null") === 't') {
      const tur = psql(`select tur from oyun.secimler where id=${sid}`);
      try { psql(`insert into oyun.adaylar(secim_id, user_id, il_id, parti_id) values (${sid}, '${b}', ${IL('İzmir')}, ${pa})`); } catch (_) {}
      if (psql(`select count(*) from oyun.adaylar where secim_id=${sid} and user_id='${b}'`) === '1') {
        await pb2.evaluate(() => sekmeAc('gundem')); await pb2.waitForSelector('[data-km-cekil]', { timeout: 10000 });
        await pb2.evaluate(() => document.querySelector('#kmAdayliklarim').scrollIntoView()); await foto(pb2, '19_adayliklarim');
        await pb2.click('[data-km-cekil]'); await onayla(pb2); await bekle(pb2, 1500);
        esit(psql(`select count(*) from oyun.adaylar where secim_id=${sid} and user_id='${b}'`), 0, 'adaylıktan çekilme (' + tur + ')');
        ok('Adaylıklarım: adaylıktan çekilme (' + tur + ')');
      }
    }
    else console.log('  · Adaylıklarım: yerel veritabanında adayliklarim() yok (canlıda var), atlandı');
    await pb2.close();
    if (hatalar.length) { console.log('Sayfa hataları:\n' + [...new Set(hatalar)].join('\n')); process.exitCode = 1; }
    else console.log('yonetici_kontrol_arayuz: hepsi geçti (ekranlar: ' + cikti + ')');
  } catch (err) {
    console.error('HATA:', err.message);
    try { for (const p of ctx.pages()) { console.error('--- ekran:', (await p.textContent('#app')).replace(/\s+/g, ' ').slice(0, 600)); await p.screenshot({ path: path.join(cikti, 'hata_' + Date.now() + '.png') }); } } catch (_) {} if (hatalar.length) console.log('Sayfa hataları:\n' + [...new Set(hatalar)].join('\n')); process.exitCode = 1;
  } finally { await tarayici.close(); sunucu.close(); }
})();
