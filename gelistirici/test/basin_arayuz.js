// Canlı ağ erişimi yok. Gerçek mobil DOM, sahte RPC sözleşmeleri.
// NODE_PATH ile Playwright kurulumu; CHROME_PATH isteğe bağlı.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const kok = path.join(__dirname, '..');
const html = fs.readFileSync(path.join(kok, 'dist/index.html'), 'utf8');
for (const m of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)) new vm.Script(m[1]);
const sql = fs.readFileSync(path.join(kok, 'dist/supabase-kurulum.sql'), 'utf8');
assert(sql.includes('create or replace function public.gazete_kur('));
assert(sql.includes("'gazete_ayar(bigint,text,numeric)'"));
assert.equal((sql.match(/select oyun\.guncelleme_basla\(/g) || []).length, 1);
assert.equal((sql.match(/select oyun\.guncelleme_bitti\(\);/g) || []).length, 1);
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, locale: 'tr-TR' });
    const errors = []; page.on('pageerror', e => errors.push(e.message));
    await page.route('**/*', route => route.abort());
    await page.setContent(html.replace(/<script src="https:[^"]+"><\/script>/g, ''));
    await page.evaluate(() => {
      window.calls = []; window.fail = null;
      window.fixture = { id: 7, ad: '<img src=x onerror="window.xss=1">Günlük', slogan: 'Kentten haberler', sahip: "Ada'\"<b>", sahibim: false, abonelik_ucret: 300, kasa: null, erisim: false, abonelik_bitis: null, abone: 8,
        yazarlar: [], hareketler: [], yayinlar: [{ id: 1, tur: 'propaganda', baslik: '<script>window.xss=1</script>Seçim', metin: 'Yalnızca sunucudan gelen önizleme.', kilitli: true, yazar: '<b>Yazar</b>', zaman: '2026-10-07T12:00:00Z', hedef_parti: { ad: '<img src=x>Parti' } }] };
      window.teskilat = { sayi: 1, iller: [{ il_id: 6, ad: 'Ankara' }], gorevler: [{ il_id: 34, ad: 'İstanbul', kad: "İl'<b>Sorumlusu", teskilat_acik: false }], benim_gorevler: [{ il_id: 34, ad: 'İstanbul', teskilat_acik: false, ucret: 6000 }], yetkili: false, gorev_verebilir: false, zorunlu: true, ucretler: { 1: 2000, 2: 4000, 3: 6000 }, kasa: 50000, cuzdan: 10000 };
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args }); if (fail === ad) throw new Error('Deneme hatası');
        if (ad === 'harita') return VERI.iller.map(i => ({ id: i.id, oyuncu: i.id === 34 ? 0 : i.mv * 5 }));
        if (ad === 'partiler') return [{ id: 2, ad: 'Örnek Parti', kisa: 'ÖP' }];
        if (ad === 'teskilatlar' || ad.startsWith('teskilat_')) return teskilat;
        if (ad === 'basin' || ad === 'gazete_yazar_yanit') return { kurulus_ucreti: 10000, benim: null, gazeteler: [fixture], teklifler: [{ gazete_id: 7, ad: fixture.ad, sahip: 'Ada', ucret: 100 }] };
        if (ad.startsWith('gazete_')) return fixture;
        if (ad === 'bagis_yap') return {};
        throw new Error('Beklenmeyen RPC: ' + ad);
      } };
      D.durum = { profil: { il_id: 34, kad: 'Deniz', cuzdan: { para: 10000 } } }; D.yigin = [basinEkrani];
    });
    const last = ad => page.evaluate(ad => calls.filter(c => c.ad === ad).at(-1), ad);
    const modalClick = name => page.locator('#modal').getByRole('button', { name, exact: true }).click();
    await page.evaluate(() => profilOlusturEkrani());
    assert.match(await page.locator('#il option').nth(1).textContent(), /İstanbul.*Yüksek fırsat/);
    await page.selectOption('#il', '34'); assert.match(await page.locator('#ilbilgi').textContent(), /0 oyuncu/);
    await page.evaluate(() => { fail = 'harita'; return profilOlusturEkrani(); });
    await page.selectOption('#il', '34'); assert.match(await page.locator('#ilbilgi').textContent(), /Veri alınamadı/);
    await page.evaluate(() => { fail = null; return basinEkrani(); });
    assert.equal(await page.locator('.sekmeler button').count(), 6);
    await page.getByRole('button', { name: 'Teklifi kabul et', exact: true }).click();
    assert.equal((await last('gazete_yazar_yanit')).args.p_kabul, true);
    await page.getByRole('button', { name: 'Reddet', exact: true }).click();
    assert.equal((await last('gazete_yazar_yanit')).args.p_kabul, false);
    await page.getByRole('button', { name: 'Gazete kur', exact: true }).click();
    await page.fill('#gazAd', 'Yeni Gazete'); await page.fill('#gazSlogan', '<img>');
    await modalClick('Kuruluş bedelini öde ve kur'); assert.equal((await last('gazete_kur')).args.p_abonelik, 0);
    await page.evaluate(() => gazeteEkrani(7));
    assert.equal(await page.locator('.basin-kilit').count(), 1);
    assert.equal(await page.locator('#icerik img, #icerik script').count(), 0);
    assert.equal(await page.evaluate(() => window.xss), undefined);
    await page.getByRole('button', { name: 'Abone ol ·', exact: false }).click(); await modalClick('Öde ve abone ol');
    assert.deepEqual((await last('gazete_abone_ol')).args, { p_gazete: 7 });
    await page.evaluate(() => { fixture.sahibim = true; fixture.erisim = true; fixture.kasa = 5000; fixture.yayinlar[0].kilitli = false; fixture.yazarlar = [{ kad: "Yazar'\"<b>", ucret: 50 }]; return gazeteEkrani(7); });
    assert.equal(await page.locator('.basin-kilit').count(), 0);
    await page.getByRole('button', { name: 'Kasadan para çek', exact: true }).click(); await page.fill('#gazMiktar', '500');
    await page.evaluate(() => { fail = 'gazete_para_cek'; }); await modalClick('Cüzdanıma aktar');
    assert.equal(await page.locator('#gazMiktar').inputValue(), '500'); assert.equal(await page.locator('#basinForm button').isEnabled(), true);
    await page.evaluate(() => { fail = null; }); await modalClick('Cüzdanıma aktar');
    assert.equal((await last('gazete_para_cek')).args.p_miktar, 500);
    await page.getByRole('button', { name: 'Slogan ve abonelik ayarları' }).click(); await page.fill('#gazAbone', '0'); await modalClick('Kaydet');
    assert.equal((await last('gazete_ayar')).args.p_abonelik, 0);
    await page.getByRole('button', { name: 'Köşe yazarlığı teklif et' }).click(); await page.fill('#gazKad', 'Deniz'); await page.fill('#gazUcret', '100'); await modalClick('Teklif gönder');
    assert.deepEqual((await last('gazete_yazar_teklif')).args, { p_gazete: 7, p_kad: 'Deniz', p_ucret: 100 });
    await page.getByRole('button', { name: 'Yazarlığı sonlandır' }).click(); await modalClick('Sonlandır');
    assert.equal((await last('gazete_yazar_cikar')).args.p_kad, "Yazar'\"<b>");
    for (const tur of ['haber', 'kose', 'propaganda']) {
      await page.getByRole('button', { name: 'Yazı yayımla', exact: true }).click();
      await page.selectOption('#gazTur', tur); await page.fill('#gazBaslik', 'Yeni başlık'); await page.fill('#gazMetin', 'Bu yazı en az yirmi karakter uzunluğunda.');
      if (tur === 'propaganda') { await modalClick('Yayımla'); assert.equal(await page.locator('#modal').count(), 1); await page.selectOption('#gazHedef', '2'); }
      await modalClick('Yayımla'); const c = await last('gazete_yayinla'); assert.equal(c.args.p_tur, tur); assert.equal(c.args.p_hedef_parti, tur === 'propaganda' ? 2 : null);
    }
    await page.evaluate(() => { fixture.sahibim = false; fixture.yazarlar = [{ kad: 'Deniz', benim: true, ucret: 100 }]; return gazeteEkrani(7); });
    assert.equal(await page.getByRole('button', { name: 'Yazı yayımla', exact: true }).count(), 1);
    assert.equal(await page.getByRole('button', { name: 'Kasadan para çek', exact: true }).count(), 0);
    fs.mkdirSync(path.join(__dirname, 'ekran'), { recursive: true });
    for (const width of [320, 390, 768, 1280]) { await page.setViewportSize({ width, height: 844 }); assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'Yatay taşma: ' + width); }
    await page.setViewportSize({ width: 390, height: 844 });
    await page.evaluate(() => { fixture.ad = 'Kent Postası'; fixture.sahip = 'Ada'; fixture.yayinlar[0].baslik = 'İstanbul için yeni bir yol'; fixture.yayinlar[0].yazar = 'Deniz'; fixture.yayinlar[0].hedef_parti.ad = 'Örnek Parti'; document.querySelectorAll('.toast').forEach(x => x.remove()); return gazeteEkrani(7); });
    await page.screenshot({ path: path.join(__dirname, 'ekran/basin.png'), fullPage: true });
    await page.evaluate(() => { iskelet('Parti', '<div id="teskilatKart"></div>'); return teskilatKartCiz(1); });
    await page.getByRole('button', { name: 'İl teşkilatı aç', exact: true }).click();
    assert.equal(await page.locator('#tkil option').count(), 1); assert.equal(await page.locator('#tkkaynak').inputValue(), 'kendi');
    await modalClick('Teşkilatı aç'); assert.deepEqual((await last('teskilat_ac2')).args, { p_il: 34, p_kaynak: 'kendi' });
    await page.evaluate(() => { teskilat.yetkili = true; teskilat.gorev_verebilir = true; return teskilatKartCiz(1); });
    await page.getByRole('button', { name: 'İl teşkilatı aç', exact: true }).click(); await page.selectOption('#tkil', '35'); await modalClick('Teşkilatı aç');
    assert.deepEqual((await last('teskilat_ac2')).args, { p_il: 35, p_kaynak: 'parti' });
    await page.getByRole('button', { name: 'İl teşkilat sorumlusu ata / görevi kaldır' }).click(); await page.selectOption('#gorevIl', '34'); await page.fill('#gorevKad', 'Deniz'); await modalClick('Sorumlu ata');
    assert.deepEqual((await last('teskilat_gorev_ver')).args, { p_il: 34, p_kad: 'Deniz' });
    await page.getByRole('button', { name: 'İl teşkilat sorumlusu ata / görevi kaldır' }).click(); await page.selectOption('#gorevIl', '34'); await modalClick('Seçili ilin sorumluluğunu kaldır');
    assert.equal((await last('teskilat_gorev_al')).args.p_il, 34);
    await page.evaluate(() => bagisModal(1)); await page.fill('#bmik', '1000'); await modalClick('Bağışla'); assert.deepEqual((await last('bagis_yap')).args, { p_miktar: 1000 });
    assert.deepEqual(errors, []);
    console.log('✓ JS/HTML parse, SQL bileşimi; il fırsatı, tüm basın RPC akışları, kilit/XSS, mobil taşma, teşkilat ve bağış.');
  } finally { await browser.close(); }
})().catch(err => { console.error(err); process.exitCode = 1; });
