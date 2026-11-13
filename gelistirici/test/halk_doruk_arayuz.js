// Halk Hareketleri 5.2 · Doruk Anı ve Bireysel Yaptırımlar arayüz testi (sahte RPC, 390 ve 320 px)
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/halk_doruk_arayuz.js
const fs = require('fs'), path = require('path'), assert = require('node:assert/strict');
const { chromium } = require('playwright');
const kok = path.join(__dirname, '../..');
const src = fs.readFileSync(path.join(kok, 'docs/halk-org-davet.js'), 'utf8');
assert.equal(src, fs.readFileSync(path.join(kok, 'www/halk-org-davet.js'), 'utf8'), 'docs ve www kopyası aynı olmalı');
for (const s of ['window.__hh7.ciz(kok,S,E)', 'window.__hh7.tazele(id)', 'sokak_doruk_panel', 'sokak_doruk_ozet', 'sokak_bireysel_ihtar', 'sokak_doruk_karar'])
  assert.ok(src.includes(s), 'kaynakta yok: ' + s);
const sql = fs.readFileSync(path.join(kok, 'supabase/migrations/20261113160000_halk_doruk_bireysel.sql'), 'utf8');
for (const yasak of [/\bdelete\s+from\b/i, /\bdrop\s+(table|column|function)\b/i, /\btruncate\b/i])
  assert.ok(!yasak.test(sql), 'migration yıkıcı ifade içeriyor: ' + yasak);
const y159 = fs.readFileSync(path.join(kok, 'gelistirici/sql/159_rpc_yuzey.sql'), 'utf8');
for (const f of ['sokak_doruk_panel', 'sokak_doruk_ozet', 'sokak_doruk_karar', 'sokak_bireysel_ihtar', 'sokak_bireysel_geri']) assert.ok(y159.includes("'" + f + "'"), '159 yüzeyinde yok: ' + f);

const ileri = s => new Date(Date.now() + s * 1000).toISOString();
const simdi = new Date().toISOString();
const KAT = [
  { tur: 'idari_ceza', ad: 'İdari Para Cezası', ikon: '🧾', kat: 1, saat: 0, aciklama: '2911 sayılı Kanun… %3 kesilir ve Hazine\'ye gelir yazılır.', bedel: 50000, engel: null },
  { tur: 'seyahat', ad: 'İl Dışına Çıkış Yasağı', ikon: '🛂', kat: 1, saat: 48, aciklama: '48 saat il değiştiremez.', bedel: 50000, engel: 'Aynı yaptırım bu meydanda 12 saatte bir uygulanabilir.' },
  { tur: 'teminat', ad: 'Mal Varlığına İhtiyati Tedbir', ikon: '🏦', kat: 2, saat: 72, aciklama: 'Cüzdanın %15\'i 72 saat bloke.', bedel: 100000, engel: null },
  { tur: 'erisim', ad: 'Erişim Engeli', ikon: '📵', kat: 1.5, saat: 12, aciklama: '12 saat Kürsü kapalı.', bedel: 75000, engel: null },
  { tur: 'disiplin', ad: 'Disiplin Soruşturması', ikon: '📁', kat: 1, saat: 0, aciklama: 'Kamu görevlilerine −5 kıdem.', bedel: 50000, engel: null }];
function panel(rol) {
  const yet = rol === 'cb' || rol === 'vali';
  return { eylem_id: 25, simdi, aktif: true, seviye: 99.4, kirmizi: true, il: 'Ankara', kosul: { doruk: 95, zafer: 85, ultimatom_saat: 6, ihtar_dk: 30 },
    doruk: { durum: 'ultimatom', baslangic: simdi, ultimatom: ileri(5 * 3600 + 120), tepe: 99.4, sonuc: {} },
    rol: { yetkili: yet, cb: rol === 'cb', katilimci: rol === 'kat' }, icisleri_dolu: true, mesruiyet_bitis: null,
    katalog: KAT.map(k => ({ ...k, engel: yet ? k.engel : 'yetki' })),
    yaptirimlar: [{ id: 7, tur: 'seyahat', ad: 'İl Dışına Çıkış Yasağı', yapan: 'Ankara Valiliği', gerekce: 'Uyarılara rağmen dağılmayan kalabalık kamu düzenini bozdu ve yolları kapattı.', durum: 'ihtar', zaman: simdi, uygulama: ileri(1500), bitis: ileri(1500 + 48 * 3600), etkilenen: 0, toplam: 0, geri_cekebilir: yet }],
    ihtar: { id: 7, tur: 'seyahat', ad: 'İl Dışına Çıkış Yasağı', uygulama: ileri(1500), gerekce: 'Uyarılara rağmen dağılmayan kalabalık kamu düzenini bozdu ve yolları kapattı.' },
    benim: rol === 'kat' ? [{ tur: 'idari_ceza', ad: 'İdari Para Cezası', tutar: 12500, bitis: null }, { tur: 'teminat', ad: 'Mal Varlığına İhtiyati Tedbir', tutar: 62500, iade_zaman: ileri(70 * 3600), iade_durum: 'bekliyor' }] : [] };
}
const ozet = cb => ({ simdi, cb, icisleri_dolu: true, benim: [], doruklar: [
  { eylem_id: 26, il: 'İzmir', durum: 'ultimatom', ultimatom: ileri(3600), seviye: 96 },
  { eylem_id: 25, il: 'Ankara', durum: 'zafer', sonuc_zaman: simdi, cb_karar: null, cb_karar_son: ileri(20 * 3600), mesruiyet_bitis: ileri(40 * 3600), sonuc: { odullu: 9, iade: 0 } }] });

async function senaryo(tarayici, genislik, P, O) {
  const sayfa = await tarayici.newPage({ viewport: { width: genislik, height: 820 } });
  const hatalar = [];
  sayfa.on('pageerror', e => hatalar.push(String(e)));
  sayfa.on('dialog', d => d.accept());
  await sayfa.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;background:#0a1024;color:#fff;font-family:sans-serif}#icerik{padding:8px}</style></head><body><div id="icerik"></div></body></html>');
  await sayfa.evaluate(([P, O]) => {
    window.__cagri = []; window.__toast = [];
    window.toast = (m, h) => window.__toast.push([m, !!h]);
    window.iskelet = function () {}; window.sokakHareketleriEkrani = async function () {};
    window.API = { rpc: async (fn, a) => { window.__cagri.push([fn, a]); if (fn === 'sokak_doruk_panel') return P; if (fn === 'sokak_doruk_ozet') return O; if (fn === 'sokak_doruk_karar' || fn === 'sokak_bireysel_ihtar' || fn === 'sokak_bireysel_geri') return P; return null; } };
  }, [P, O]);
  await sayfa.addScriptTag({ content: src });
  return { sayfa, hatalar };
}
const eylemIskelet = `<section id="hh4"><div class="hh4-uyarilar"><div class="hh4-uyari kirmizi"><i>🔴</i><div>Kırmızı</div></div></div>
 <nav class="hh4-sekmeler"><button data-hh4-sekme="akis">📡 Akış</button><button data-hh4-sekme="devlet">🏛️ Devlet</button></nav>
 <div data-hh4-sekme-ic="devlet"><p class="m">Hükümetin attığı adımlar.</p><div data-hh4-yuva="em-devlet"></div><div data-hh4-yuva="devlet"></div></div></section>`;
async function tasma(sayfa, ad) {
  const t = await sayfa.evaluate(() => ({ sw: document.documentElement.scrollWidth, w: window.innerWidth }));
  assert.ok(t.sw <= t.w + 1, ad + ': yatay taşma ' + JSON.stringify(t));
  const kucuk = await sayfa.evaluate(() => [...document.querySelectorAll('#hh4 .hh6-btn')].filter(b => b.offsetParent && b.getBoundingClientRect().height < 44).map(b => b.textContent.trim().slice(0, 40)));
  assert.deepEqual(kucuk, [], ad + ': 44 px altı dokunma alanı');
  const fs16 = await sayfa.evaluate(() => [...document.querySelectorAll('#hh4 textarea')].filter(t => parseFloat(getComputedStyle(t).fontSize) < 16).length);
  assert.equal(fs16, 0, ad + ': 16 px altı giriş');
}
const bekle = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  const tarayici = await chromium.launch();
  for (const w of [390, 320]) {
    // 1) Vali: doruk şeridi + Devlet sekmesinde yaptırım masası, ihtar ver
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, panel('vali'), ozet(false));
      await sayfa.evaluate(h => { document.getElementById('icerik').innerHTML = h; window.__hh4 = { gorunum: 'eylem', eylem: 25, sekme: 'devlet' }; window.__hh7.ciz(document.getElementById('hh4'), window.__hh4, { id: 25 }); }, eylemIskelet);
      await bekle(150);
      const durum = await sayfa.evaluate(() => ({
        doruk: !!document.querySelector('#hh4 .hh4-uyarilar > [data-hh7-doruk]:first-child'),
        ihtar: !!document.querySelector('#hh4 [data-hh7-ihtar]'),
        masa: document.querySelectorAll('#hh4 [data-hh7-devlet] .hh7-kalem').length,
        kilitli: document.querySelectorAll('#hh4 [data-hh7-ac][disabled]').length,
        geri: !!document.querySelector('#hh4 [data-hh7-geri-cek="7"]') }));
      assert.deepEqual(durum, { doruk: true, ihtar: true, masa: 5, kilitli: 1, geri: true }, 'vali görünümü ' + w);
      await sayfa.click('#hh4 [data-hh7-ac="teminat"]');
      await sayfa.fill('#hh4 [data-hh7-gerekce]', 'kısa');
      await sayfa.click('#hh4 [data-hh7-gonder="teminat"]');
      let t = await sayfa.evaluate(() => window.__toast.slice(-1)[0]);
      assert.deepEqual(t, ['Gerekçe en az 20 karakter olmalı.', true]);
      await tasma(sayfa, 'vali form ' + w);
      await sayfa.fill('#hh4 [data-hh7-gerekce]', 'Uyarılara rağmen dağılmayan kalabalık kamu düzenini ağır biçimde bozdu.');
      await sayfa.click('#hh4 [data-hh7-gonder="teminat"]');
      await bekle(100);
      const c = await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_bireysel_ihtar'));
      assert.deepEqual(c, [['sokak_bireysel_ihtar', { p_eylem: 25, p_tur: 'teminat', p_gerekce: 'Uyarılara rağmen dağılmayan kalabalık kamu düzenini ağır biçimde bozdu.' }]]);
      await sayfa.click('#hh4 [data-hh7-geri-cek="7"]');
      await bekle(100);
      assert.ok(await sayfa.evaluate(() => window.__cagri.some(c => c[0] === 'sokak_bireysel_geri' && c[1].p_id === 7)), 'geri çek');
      await tasma(sayfa, 'vali ' + w);
      assert.deepEqual(hatalar, []);
      await sayfa.close();
    }
    // 2) Katılımcı: ihtar uyarısı "sen meydandasın" + yaptırımlarım; masa yok
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, panel('kat'), ozet(false));
      await sayfa.evaluate(h => { document.getElementById('icerik').innerHTML = h; window.__hh4 = { gorunum: 'eylem', eylem: 25, sekme: 'akis' }; window.__hh7.ciz(document.getElementById('hh4'), window.__hh4, { id: 25 }); }, eylemIskelet);
      await bekle(150);
      const d = await sayfa.evaluate(() => ({ ihtar: (document.querySelector('#hh4 [data-hh7-ihtar]') || {}).textContent || '', benim: (document.querySelector('#hh4 [data-hh7-benim]') || {}).textContent || '', masa: document.querySelectorAll('#hh4 .hh7-kalem').length, kayit: document.querySelectorAll('#hh4 [data-hh7-devlet] .hh6-panel').length, geri: document.querySelectorAll('#hh4 [data-hh7-geri-cek]').length }));
      assert.ok(d.ihtar.includes('Sen meydandasın'), 'katılımcı uyarısı');
      assert.ok(d.benim.includes('12.500') && d.benim.includes('bloke'), 'yaptırımlarım: ' + d.benim);
      assert.equal(d.masa, 0); assert.equal(d.kayit, 1); assert.equal(d.geri, 0);
      await tasma(sayfa, 'katılımcı ' + w);
      assert.deepEqual(hatalar, []);
      await sayfa.close();
    }
    // 3) Ana ekran, CB: süren doruk + zafer kararı
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, panel('cb'), ozet(true));
      await sayfa.evaluate(() => { document.getElementById('icerik').innerHTML = '<section id="hh4"><div class="hh4-mkart" data-hh4-ac="26"><div class="alt"></div></div></section>'; window.__hh4 = { gorunum: 'ana' };
        document.querySelector('.hh4-mkart').addEventListener('click', () => { window.__git = 26; });
        window.__hh7.ciz(document.getElementById('hh4'), window.__hh4, null); });
      await bekle(150);
      const n = await sayfa.evaluate(() => ({ kart: document.querySelectorAll('#hh4 [data-hh7-ana] .hh7-doruk').length, karar: document.querySelectorAll('#hh4 [data-hh7-karar]').length }));
      assert.deepEqual(n, { kart: 2, karar: 3 });
      await sayfa.click('#hh4 [data-hh7-git="26"]');
      assert.equal(await sayfa.evaluate(() => window.__git), 26);
      await tasma(sayfa, 'cb ana ' + w);
      await sayfa.fill('#hh4 [data-hh7-karar-metin="25"]', 'Milletimizin sesini duyduk.');
      await sayfa.click('#hh4 [data-hh7-karar="talep"]');
      await bekle(100);
      const c = await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_doruk_karar'));
      assert.deepEqual(c, [['sokak_doruk_karar', { p_eylem: 25, p_karar: 'talep', p_gerekce: 'Milletimizin sesini duyduk.' }]]);
      assert.deepEqual(hatalar, []);
      await sayfa.close();
    }
  }
  await tarayici.close();
  console.log('halk_doruk_arayuz: TAMAM');
})().catch(e => { console.error(e); process.exit(1); });
