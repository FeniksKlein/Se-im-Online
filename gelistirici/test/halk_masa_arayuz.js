// Halk Hareketleri 5.1 · 🤝 Masa arayüz testi (sahte RPC, 390 ve 320 px)
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/halk_masa_arayuz.js
const fs = require('fs'), path = require('path'), assert = require('node:assert/strict');
const { chromium } = require('playwright');
const kok = path.join(__dirname, '../..');
const src = fs.readFileSync(path.join(kok, 'docs/halk-org-davet.js'), 'utf8');
assert.equal(src, fs.readFileSync(path.join(kok, 'www/halk-org-davet.js'), 'utf8'), 'docs ve www kopyası aynı olmalı');
for (const s of ["['masa','🤝 Masa']", 'data-hh6-masa', 'window.__hh6.ciz', 'sokak_masa_panel', 'data-meydan-islem="kirmizi_yanit"', 'window.__hh6.tazele'])
  assert.ok(src.includes(s), 'kaynakta yok: ' + s);
assert.ok(!src.includes('data-meydan="kirmizi_yanit"'), 'kırmızı hat düğmesi yanlış öznitelikte');
assert.ok(!src.includes('ayrı il sakini'), 'çağrı metni eski kuralı anlatıyor');
const sql = fs.readFileSync(path.join(kok, 'supabase/migrations/20261113090000_halk_masa_cagri_onarim.sql'), 'utf8');
for (const s of ['public.sokak_masa_panel', 'imza_sayisi=3', 'sokak_yama_uygula'])
  assert.ok(sql.includes(s), 'migration içinde yok: ' + s);
for (const yasak of [/\bdelete\s+from\b/i, /\bdrop\s+(table|column|function)\b/i, /\btruncate\b/i])
  assert.ok(!yasak.test(sql), 'migration yıkıcı ifade içeriyor: ' + yasak);
assert.ok(fs.readFileSync(path.join(kok, 'gelistirici/sql/159_rpc_yuzey.sql'), 'utf8').includes("'sokak_masa_panel'"), '159 yüzeyinde sokak_masa_panel yok');

const ileri = s => new Date(Date.now() + s * 1000).toISOString();
const simdi = new Date().toISOString();
const UZUN = 'Hükümet olarak il hizmet memnuniyetini on iki gün içinde beş puan artırma sözü veriyoruz; ayrıntılı takvim kamuoyuyla paylaşılacak ve çok uzun bir cümle taşmamalı.';
function panel(rol) {
  const org = rol === 'org', juri = rol === 'juri';
  return {
    eylem_id: 25, aktif: true, simdi, bekleyen: org ? 4 : juri ? 2 : 0,
    rol: { katilimci: true, organizator: org, hukumet: false, yargi: false },
    talep: 'hizmet', talep_ad: 'İl hizmet memnuniyeti +5 puan',
    soz: { durum: 'oylama', tur: 'hizmet', talep: 'İl hizmet memnuniyeti +5 puan', baslangic: 41, hedef: 46, olcum: 42.5, oy_sonu: ileri(5400), son_tarih: ileri(86400 * 12),
      evet: 3, hayir: 1, secmen: 7, oyum: null, secmenim: true, oy_hakki: org || juri, metin: UZUN, yapan: 'ercan' },
    kararlar: [
      { id: 91, tur: 'masa', ad: 'Uzlaşma masası', durum: 'aktif', gerekce: 'Talepleri dinlemek için Ankara Valiliğinde masa kuruyoruz, temsilcinizi bekliyoruz.', yapan: 'icisleri', unvan: 'İçişleri Bakanı',
        zaman: simdi, bitis: ileri(7200), suresi_doldu: false, cevap: null, hedef: null, soz: false,
        secenekler: org ? [{ k: 'kabul', ad: 'Uzlaşmayı kabul et ve eylemi bitir' }, { k: 'ret', ad: 'Teklifi reddet' }] : [] },
      { id: 90, tur: 'uyari', ad: 'Sert siyasi uyarı', durum: 'aktif', gerekce: 'Kamu düzenini bozan eylemlere göz yumulmayacaktır, dağılın.', yapan: 'vali', unvan: 'Ankara Valisi',
        zaman: simdi, bitis: ileri(-60), suresi_doldu: true, cevap: 'Meydan dağılmayacak, haklarımızı biliyoruz ve barışçılız.', hedef: null, soz: false, secenekler: [] }
    ],
    kirmizi: org ? { durum: 'bekliyor', teklif: 'yatirim', teklif_ad: 'İle yatırım', metin: 'Eylemi bitirirseniz ile 2 fabrika yatırımı açıklanacak.', zaman: simdi, yanit_hakki: true } : null,
    juri: { durum: 'oy', bitis: ileri(3 * 3600), sonuc: null, uye: 7, oy_veren: 2, uyeyim: juri, oyum: null,
      sozler: [{ taraf: 'meydan', metin: 'Hizmet yok, ses vermek hakkımız.', zaman: simdi }, { taraf: 'hukumet', metin: 'Masa kurduk, şiddete izin yok.', zaman: simdi }],
      savunma_taraf: null, kalan_soz: null },
    muzakere: { id: 5, metin: 'Valilik binasını boşaltın, gözaltılar serbest kalsın.', bedel: 40000, durum: 'oy', bitis: ileri(1800), evet: 1, hayir: 2, oyum: null, oy_hakki: org },
    heyet: [{ kim: 'baro_baskani', durum: 'davet', ben: juri, rapor: null, rapor_zaman: null, davet_eden: 'cb', zaman: simdi }],
    hukumet_yaniti: 'Taleplerinizi duyduk; masa kurulmuştur.', yanit_zamani: simdi
  };
}
const bosPanel = { eylem_id: 26, aktif: true, simdi, bekleyen: 0, rol: { katilimci: true, organizator: false, hukumet: false, yargi: false }, talep: null, talep_ad: null,
  soz: null, kararlar: [], kirmizi: null, juri: null, muzakere: null, heyet: [], hukumet_yaniti: null, yanit_zamani: null };

async function senaryo(tarayici, genislik, P) {
  const sayfa = await tarayici.newPage({ viewport: { width: genislik, height: 820 } });
  const hatalar = [];
  sayfa.on('pageerror', e => hatalar.push(String(e)));
  await sayfa.setContent('<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;background:#0a1024;color:#fff;font-family:sans-serif}#icerik{padding:8px}</style></head><body><div id="icerik"></div></body></html>');
  await sayfa.evaluate(P => {
    window.__cagri = []; window.__toast = [];
    window.toast = (m, h) => window.__toast.push([m, !!h]);
    window.iskelet = function () {}; window.sokakHareketleriEkrani = async function () {};
    window.API = { rpc: async (fn, a) => { window.__cagri.push([fn, a]); if (fn === 'sokak_masa_panel') return P; return { tamam: true }; } };
  }, P);
  await sayfa.addScriptTag({ content: src });
  await sayfa.evaluate(() => { window.__tazele = 0; window.sokakHareketleriEkrani = () => { window.__tazele++; }; });
  return { sayfa, hatalar };
}
const iskelet = (id, sekme, tedbir) => `<section id="hh4"><div class="hh4-uyarilar"></div><nav class="hh4-sekmeler"><button data-hh4-sekme="akis">📡 Akış</button><button data-hh4-sekme="masa">🤝 Masa</button></nav>
 <div data-hh4-sekme-ic="masa"><div data-hh6-masa="${id}"></div><div data-hh6-tedbir></div></div>
 <div data-hh4-sekme-ic="devlet"><div data-hh4-yuva="devlet">${tedbir ? '<details class="hh-detail"><summary>🏛️ On iki yeni hükümet aracı</summary><div class="hh-log"><b>Kültür-Festival</b><div class="hh-grid"><button class="hh-action" data-saha-fn="sokak_tedbir_hamle">Sahneyi pankartla işgal et</button></div></div></details>' : ''}</div></div></section>`;
async function tasma(sayfa, ad) {
  const t = await sayfa.evaluate(() => ({ sw: document.documentElement.scrollWidth, w: window.innerWidth }));
  assert.ok(t.sw <= t.w + 1, ad + ': yatay taşma ' + JSON.stringify(t));
  const kucuk = await sayfa.evaluate(() => [...document.querySelectorAll('#hh4 .hh6-btn, #hh4 .hh6-serit')].filter(b => b.offsetParent && b.getBoundingClientRect().height < 44).map(b => b.textContent.trim().slice(0, 40)));
  assert.deepEqual(kucuk, [], ad + ': 44 px altı dokunma alanı');
}
const islemler = sayfa => sayfa.evaluate(() => window.__cagri.filter(c => c[0] !== 'sokak_masa_panel'));

(async () => {
  const tarayici = await chromium.launch();
  for (const w of [390, 320]) {
    // 1) Düzenleyen: akış sekmesinde şerit + rozet, masaya geçip her şeye yanıt verir
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, panel('org'));
      await sayfa.evaluate(h => { document.getElementById('icerik').innerHTML = h; window.__hh4 = { gorunum: 'eylem', eylem: 25, sekme: 'akis' };
        window.__hh6.ciz(document.getElementById('hh4'), window.__hh4, { id: 25 }); }, iskelet(25, 'akis', true));
      await sayfa.waitForSelector('#hh4 [data-hh6-serit]');
      const serit = await sayfa.textContent('#hh4 [data-hh6-serit]');
      for (const s of ['4 yanıt', 'taviz oylaması', 'hükümet kararı', 'kırmızı hat', 'işgal pazarlığı']) assert.ok(serit.includes(s), w + ' şerit: ' + s);
      assert.equal(await sayfa.textContent('#hh4 [data-hh4-sekme="masa"] sup'), '4', 'sekme rozeti');
      // tedbir karşı hamleleri masaya taşınır (eylemci, hükümet formu yok)
      assert.equal(await sayfa.locator('#hh4 [data-hh6-tedbir] [data-saha-fn="sokak_tedbir_hamle"]').count(), 1, 'karşı hamle masaya taşınmalı');
      assert.ok((await sayfa.textContent('#hh4 [data-hh6-tedbir]')).includes('karşı hamlelerin'));
      // masa sekmesine geç
      await sayfa.evaluate(() => { window.__hh4.sekme = 'masa'; window.__hh6.ciz(document.getElementById('hh4'), window.__hh4, { id: 25 }); });
      await sayfa.waitForSelector('#hh4 .hh6-kart');
      assert.equal(await sayfa.locator('#hh4 [data-hh6-serit]').count(), 0, 'masa açıkken şerit kalkar');
      const metin = await sayfa.textContent('#hh4 [data-hh6-masa]');
      for (const s of ['Senden 4 yanıt bekleniyor', 'Hükümetin tavizi', 'Katılımcı oylamasında', 'Kırmızı hat · İle yatırım', 'Halk jürisi', '2 / 7 jüri üyesi', 'Meydanın savunması', 'İşgal pazarlığı', 'Arabulucu heyeti', 'Uzlaşma masası', 'Meydanın yanıtı', 'resmî yanıtı', 'Talep: İl hizmet'])
        assert.ok(metin.includes(s), w + ' org masa: ' + s);
      // taviz oyu
      await sayfa.click('#hh4 [data-hh6-is="soz"][data-v*="true"]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_soz_oyla'));
      assert.deepEqual((await islemler(sayfa)).pop(), ['sokak_soz_oyla', { p_eylem: 25, p_oy: true }]);
      // kırmızı hat ifşa
      await sayfa.click('#hh4 [data-hh6-is="kirmizi"][data-v*="ifsa"]');
      await sayfa.waitForFunction(() => window.__cagri.filter(c => c[0] === 'sokak_meydan_islem').length === 1);
      assert.deepEqual((await islemler(sayfa)).pop(), ['sokak_meydan_islem', { p_eylem: 25, p_islem: 'kirmizi_yanit', p_veri: { yanit: 'ifsa' } }]);
      // işgal pazarlığı
      await sayfa.click('#hh4 [data-hh6-is="muzakere"][data-v*="hayir"]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_eylem_merkezi_islem'));
      assert.deepEqual((await islemler(sayfa)).pop(), ['sokak_eylem_merkezi_islem', { p_eylem: 25, p_islem: 'muzakere_oy', p_veri: { oy: 'hayir' } }]);
      // karar: kısa metin reddedilir, uzun metin gider
      await sayfa.click('#hh4 [data-hh6-ac="karar:91:ret"]');
      const fs16 = await sayfa.evaluate(() => parseFloat(getComputedStyle(document.querySelector('#hh4 [data-hh6-metin]')).fontSize));
      assert.ok(fs16 >= 16, 'metin kutusu en az 16 px');
      await sayfa.fill('#hh4 [data-hh6-metin]', 'kısa');
      await sayfa.click('#hh4 [data-hh6-gonder]');
      assert.ok(await sayfa.evaluate(() => window.__toast.some(t => t[1] && /20 karakter/.test(t[0]))), 'kısa açıklama uyarısı');
      assert.equal(await sayfa.evaluate(() => window.__cagri.filter(c => c[0] === 'sokak_karar_yanit').length), 0);
      await sayfa.fill('#hh4 [data-hh6-metin]', 'Masa göstermelik; yazılı güvence olmadan meydanı terk etmiyoruz.');
      await tasma(sayfa, w + ' org form');
      await sayfa.click('#hh4 [data-hh6-gonder]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_karar_yanit'));
      const k = (await islemler(sayfa)).pop();
      assert.equal(k[0], 'sokak_karar_yanit'); assert.equal(k[1].p_karar, 91); assert.equal(k[1].p_islem, 'ret'); assert.ok(k[1].p_metin.length >= 20);
      await tasma(sayfa, w + ' org');
      if (w === 390) await sayfa.screenshot({ path: '/tmp/hh6_org_390.png', fullPage: true });
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
    // 2) Jüri üyesi katılımcı: jüri oyu ve heyet daveti
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, panel('juri'));
      await sayfa.evaluate(h => { document.getElementById('icerik').innerHTML = h; window.__hh4 = { gorunum: 'eylem', eylem: 25, sekme: 'masa' };
        window.__hh6.ciz(document.getElementById('hh4'), window.__hh4, { id: 25 }); }, iskelet(25, 'masa', false));
      await sayfa.waitForSelector('#hh4 .hh6-kart');
      const metin = await sayfa.textContent('#hh4 [data-hh6-masa]');
      for (const s of ['Jüri üyesisin, oyun bekleniyor', 'Arabulucu olarak davet edildin']) assert.ok(metin.includes(s), w + ' jüri: ' + s);
      assert.equal(await sayfa.locator('#hh4 [data-hh6-is="kirmizi"]').count(), 0, 'kırmızı hat yalnız düzenleyene');
      assert.equal(await sayfa.locator('#hh4 [data-hh6-ac^="karar:"]').count(), 0, 'masa kararına yalnız düzenleyen yanıt verir');
      await sayfa.click('#hh4 [data-hh6-is="juri_oy"][data-v*="meydan"]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_meydan_islem'));
      assert.deepEqual((await islemler(sayfa)).pop(), ['sokak_meydan_islem', { p_eylem: 25, p_islem: 'juri_oy', p_veri: { oy: 'meydan' } }]);
      await sayfa.click('#hh4 [data-hh6-is="heyet"][data-v*="true"]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_heyet_yanit'));
      assert.deepEqual((await islemler(sayfa)).pop(), ['sokak_heyet_yanit', { p_eylem: 25, p_kabul: true }]);
      await tasma(sayfa, w + ' jüri');
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
    // 3) Savunma sırası: düzenleyen jüriye söz yazar
    {
      const P = panel('org'); P.juri = Object.assign(P.juri, { durum: 'savunma', savunma_taraf: 'meydan', kalan_soz: 2, uyeyim: false });
      const { sayfa, hatalar } = await senaryo(tarayici, w, P);
      await sayfa.evaluate(h => { document.getElementById('icerik').innerHTML = h; window.__hh4 = { gorunum: 'eylem', eylem: 25, sekme: 'masa' };
        window.__hh6.ciz(document.getElementById('hh4'), window.__hh4, { id: 25 }); }, iskelet(25, 'masa', false));
      await sayfa.waitForSelector('#hh4 [data-hh6-ac="juri_savun"]');
      await sayfa.click('#hh4 [data-hh6-ac="juri_savun"]');
      await sayfa.fill('#hh4 [data-hh6-metin]', 'Barışçıl meydan, somut talep: hizmet istiyoruz.');
      await sayfa.click('#hh4 [data-hh6-gonder="juri_savun"]');
      await sayfa.waitForFunction(() => window.__cagri.some(c => c[0] === 'sokak_meydan_islem'));
      assert.deepEqual((await islemler(sayfa)).pop(), ['sokak_meydan_islem', { p_eylem: 25, p_islem: 'juri_savun', p_veri: { metin: 'Barışçıl meydan, somut talep: hizmet istiyoruz.' } }]);
      await tasma(sayfa, w + ' savunma');
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
    // 4) Boş masa ve ana ekran kart etiketi
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, bosPanel);
      await sayfa.evaluate(h => { document.getElementById('icerik').innerHTML = h; window.__hh4 = { gorunum: 'eylem', eylem: 26, sekme: 'masa' };
        window.__hh6.ciz(document.getElementById('hh4'), window.__hh4, { id: 26 }); }, iskelet(26, 'masa', false));
      await sayfa.waitForSelector('#hh4 .hh6-kart');
      const metin = await sayfa.textContent('#hh4 [data-hh6-masa]');
      for (const s of ['Hükümet henüz masaya bir şey koymadı', 'Uzlaşma masası', 'Halk jürisi', 'Kırmızı hat']) assert.ok(metin.includes(s), w + ' boş: ' + s);
      assert.equal(await sayfa.locator('#hh4 [data-hh4-sekme="masa"] sup').count(), 0, 'boşta rozet yok');
      await tasma(sayfa, w + ' boş');
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
    {
      const { sayfa, hatalar } = await senaryo(tarayici, w, panel('org'));
      await sayfa.evaluate(() => { document.getElementById('icerik').innerHTML = '<section id="hh4"><button type="button" class="hh4-mkart" data-hh4-ac="25"><div class="alt"></div></button></section>';
        window.__hh4 = { gorunum: 'ana', model: { aktif: [{ id: 25 }] } }; window.__hh6.ciz(document.getElementById('hh4'), window.__hh4, null); });
      await sayfa.waitForSelector('#hh4 [data-hh6-etiket]');
      assert.ok((await sayfa.textContent('#hh4 [data-hh6-etiket]')).includes('4 yanıt bekliyor'));
      assert.deepEqual(hatalar, [], 'sayfa hatası');
      await sayfa.close();
    }
  }
  await tarayici.close();
  console.log('TAMAM: Masa arayüzü (düzenleyen, jüri üyesi, savunma, boş masa, kart etiketi; 390 ve 320 px)');
})().catch(e => { console.error(e); process.exit(1); });
