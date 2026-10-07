// Uçtan uca arayüz testi: gerçek Postgres + iPhone ekranında uygulama.
// Çalıştır: node test/arayuz.js
const { chromium, devices } = require('/opt/npm-tools/node_modules/playwright');
const { execFileSync } = require('child_process');
const path = require('path'), fs = require('fs');

const KOK = path.join(__dirname, '..');
const EKRAN = path.join(__dirname, 'ekran');
fs.mkdirSync(EKRAN, { recursive: true });

function psql(sql) {
  try {
    return execFileSync('psql', ['-h', '/tmp', '-U', 'postgres', '-d', 'oyun_test', '-At', '-q', '-v', 'ON_ERROR_STOP=1', '-c', sql], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  } catch (err) {
    const m = String(err.stderr || err.message).split('\n')[0].replace('ERROR:  ', '');
    throw new Error(m);
  }
}
const assert1 = (k, m) => { if (!k) throw new Error('DOĞRULAMA: ' + m); };
const lit = (v) => v === null || v === undefined ? 'null' : typeof v === 'number' ? String(v) : typeof v === 'boolean' ? String(v)
  : Array.isArray(v) && v.every(x => typeof x === 'string') ? `array[${v.map(x => `'${x.replace(/'/g, "''")}'`).join(',')}]::text[]`   // PostgREST: JSON dizisi → text[]
  : typeof v === 'object' ? `'${JSON.stringify(v).replace(/'/g, "''")}'::jsonb` : `'${String(v).replace(/'/g, "''")}'`;
function rpc(uid, fn, args) {
  const a = Object.entries(args || {}).map(([k, v]) => `${k} => ${lit(v)}`).join(', ');
  const out = psql(`select set_config('request.jwt.claim.sub', '${uid}', false); select public.${fn}(${a});`);
  const satir = out.split('\n').slice(1).join('\n');
  return satir ? JSON.parse(satir) : null;
}
function saat(ts) { psql(`update oyun.ayarlar set test_simdi = '${ts}+03'; select oyun.tick();`); }
const secimId = (tur, donem) => +psql(`select id from oyun.secimler where tur='${tur}' and donem='${donem}'`);

// ---- sahte kimlik doğrulama (Supabase Auth yerine)
const hesaplar = {}; let aktif = null;
const AUTH = {
  oturum: () => aktif ? { email: aktif.email } : null,
  kayit: (email, sifre) => {
    if (hesaplar[email]) throw new Error('User already registered');
    const uid = psql(`insert into auth.users(email) values (${lit(email)}) returning id`).split('\n')[0];
    hesaplar[email] = { uid, sifre, email, onayli: false };
    return { onayGerekli: true };
  },
  kodDogrula: (email, kod) => {
    if (kod !== '123456') throw new Error('Token has expired or is invalid');
    hesaplar[email].onayli = true; aktif = hesaplar[email];
  },
  kodTekrar: () => null,
  giris: (email, sifre) => {
    const h = hesaplar[email];
    if (!h || h.sifre !== sifre) throw new Error('Invalid login credentials');
    if (!h.onayli) throw new Error('Email not confirmed');
    aktif = h;
  },
  sifreSifirla: () => null, sifreGuncelle: () => null,
  cikis: () => { aktif = null; },
  odeme: (urun) => psql(`set role service_role; select public.odeme_isle('${JSON.stringify({ event: { type: 'NON_RENEWING_PURCHASE', app_user_id: aktif.uid, product_id: urun, transaction_id: 'TEST-' + Date.now() } })}'::jsonb)`),
  testGiris: (kad) => { const uid = psql(`select id from oyun.profiller where kad='${kad}'`); aktif = { uid, email: kad + '@bot', onayli: true }; }
};

(async () => {
  // Veritabanını sıfırla, botları ekle
  execFileSync(path.join(KOK, 'kur_yerel.sh'));
  psql(fs.readFileSync(path.join(KOK, 'sql/90_test_botlar.sql'), 'utf8'));
  psql(`update oyun.ayarlar set baslangic='2026-10-02 12:00+03'`);
  saat('2026-10-02 12:00');
  psql(`update oyun.ayarlar set baslangic_para=60000`);
  psql(`select oyun.test_bot_olustur(160, '2026-09-20 12:00+03')`);
  execFileSync('node', [path.join(KOK, 'build/derle.js')]);

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ ...devices['iPhone 13'], locale: 'tr-TR', timezoneId: 'Europe/Istanbul' });
  const page = await ctx.newPage();
  const hatalar = [];
  page.on('pageerror', e => hatalar.push('pageerror: ' + e.message + ' @ ' + String(e.stack || '').split('\n').slice(1, 4).join(' | ')));
  page.on('console', m => { if (m.type() === 'error' && !/supabase|ERR_|Failed to load/.test(m.text())) hatalar.push('console: ' + m.text()); });
  await page.route(/cdn\.jsdelivr\.net/, r => r.abort());
  await page.exposeFunction('__api', (yontem, a, b, c) => {
    try {
      if (yontem === 'rpc') { if (!aktif) throw new Error('Giriş yapmalısın.'); return { veri: rpc(aktif.uid, a, b) }; }
      return { veri: AUTH[yontem](a, b, c) ?? null };
    } catch (err) { return { hata: err.message }; }
  });
  await page.addInitScript(() => {
    // Telefon ortamı taklidi: Capacitor + Firebase Messaging eklentisi
    window.__konular = []; window.__dinle = {};
    window.Capacitor = { isNativePlatform: () => true, getPlatform: () => 'ios', Plugins: { FirebaseMessaging: {
      requestPermissions: async () => ({ receive: 'granted' }),
      getToken: async () => ({ token: 'test_cihaz_token_' + 'x'.repeat(40) }),
      subscribeToTopic: async ({ topic }) => { if (!window.__konular.includes(topic)) window.__konular.push(topic); },
      unsubscribeFromTopic: async ({ topic }) => { window.__konular = window.__konular.filter(t => t !== topic); },
      addListener: (ad, fn) => { window.__dinle[ad] = fn; return { remove() {} }; } },
      AdMob: { _d: {}, initialize: async () => {}, addListener: async function (ad, fn) { this._d[ad] = fn; return { remove: () => { delete this._d[ad]; } }; },
        prepareRewardVideoAd: async () => {}, showRewardVideoAd: async function () { const f = this._d.onRewardedVideoAdReward; if (f) f({ type: 'odul', amount: 1 }); return { type: 'odul', amount: 1 }; } },
      Purchases: { configure: async () => {},
        getProducts: async ({ productIdentifiers }) => ({ products: productIdentifiers.map((id, i) => ({ identifier: id, priceString: ['₺29,99', '₺89,99', '₺229,99'][i] || '₺0' })) }),
        purchaseStoreProduct: async ({ product }) => { const r = await window.__api('odeme', product.identifier); if (r.hata) throw new Error(r.hata); return { productIdentifier: product.identifier }; } } } };
    const cagir = (y, ...x) => window.__api(y, ...x).then(r => { if (r.hata) throw new Error(r.hata); return r.veri; });
    window.API_TEST = {
      rpc: (fn, args) => cagir('rpc', fn, args || {}), oturum: () => cagir('oturum'),
      kayit: (e, s) => cagir('kayit', e, s), kodDogrula: (e, k, t) => cagir('kodDogrula', e, k, t), kodTekrar: (e) => cagir('kodTekrar', e),
      giris: (e, s) => cagir('giris', e, s), sifreSifirla: (e) => cagir('sifreSifirla', e), sifreGuncelle: (s) => cagir('sifreGuncelle', s), cikis: () => cagir('cikis')
    };
  });
  const foto = async (ad) => { await page.waitForTimeout(350); await page.screenshot({ path: path.join(EKRAN, ad + '.png') }); console.log('  📸', ad); };
  const tikla = async (metin, opt) => { await page.getByRole('button', { name: metin, exact: !!(opt && opt.tam) }).first().click(); await page.waitForTimeout(250); };
  const yenile = async (sekme) => { await page.evaluate((s) => sekmeAc(s), sekme || 'gundem'); await page.waitForTimeout(400); };
  const ok = (m) => console.log('  ✓', m);
  const bekle = async (metin) => { await page.getByText(metin).first().waitFor({ timeout: 5000 }); };
  const toastBekle = async (metin, sure) => { await page.locator('.toast', { hasText: metin }).first().waitFor({ timeout: sure || 5000 }); };

  await page.goto('file://' + path.join(KOK, 'dist/index.html'));
  await bekle('Hesap oluştur');
  await foto('01-karsilama');

  // ---- KAYIT
  await tikla('Hesap oluştur');
  await page.fill('#eposta', 'ercan@ornek.com'); await page.fill('#sifre', 'gizli1234'); await page.fill('#sifre2', 'gizli1234');
  await tikla('Kayıt ol');
  await bekle('Devam etmek için');
  await page.check('#kvkk');
  await foto('02-kayit');
  await tikla('Kayıt ol');
  await bekle('6 haneli bir kod');
  await page.fill('#kod', '111111'); await tikla('Doğrula'); await bekle('Kod hatalı');
  await page.fill('#kod', '123456'); await foto('03-kod');
  await tikla('Doğrula');
  await bekle('Siyasete ilk adım');
  await page.fill('#kad', 'Ercan'); await page.selectOption('#il', '35');
  await foto('04-profil');
  await tikla('Oyuna başla');
  await bekle('Seçim takvimi');
  await foto('05-gundem-ilk');
  ok('Kayıt → e-posta kodu → profil (İzmir) → gündem');
  await page.waitForTimeout(500);
  assert1(psql(`select count(*) from oyun.cihazlar c join oyun.profiller p on p.id=c.user_id where p.kad='Ercan'`) === '1', 'cihaz kaydı yok');
  let konular = await page.evaluate(() => window.__konular.slice().sort());
  assert1(JSON.stringify(konular) === JSON.stringify(['duyuru', 'p_il_35', 'p_tum', 's_tum']), 'konular: ' + konular);
  ok('Push: telefon izni alındı, cihaz kaydedildi, konulara abone olundu (' + konular.join(', ') + ')');

  // ---- PARTİYE KATIL (3 Ekim)
  saat('2026-10-03 12:00');
  await yenile('parti'); await bekle('Tüm partiler');
  await foto('06-partiler');
  await page.getByText('Cumhuriyet Yolu Partisi').first().click(); await page.waitForTimeout(400);
  await tikla('Partiye katıl'); await tikla('Katıl', { tam: true });
  await bekle('Partiden ayrıl');
  await foto('07-parti-detay');
  await page.waitForTimeout(400);
  konular = await page.evaluate(() => window.__konular.slice().sort());
  assert1(konular.includes('p_parti_1') && konular.includes('s_parti_1'), 'parti konuları yok: ' + konular);
  ok('Partiye katılma');

  // ---- BELEDİYE: 6 Ekim aday ol
  saat('2026-10-06 10:00');
  psql(`select oyun.test_bot_aday('bel_on', 0.12)`);
  await yenile(); await bekle('Belediye başkanı aday adayı ol');
  await foto('08-gundem-basvuru');
  await tikla('Belediye başkanı aday adayı ol'); await bekle('öde ve başvur');
  await foto('08a-aday-ucret'); await page.click('#evet');
  await bekle('Başvurun alındı');
  assert1(+psql(`select count(*) from oyun.hesap_hareket h join oyun.profiller p on p.id=h.user_id where p.kad='Ercan' and h.tur='aday'`) === 1, 'aday ücreti alınmadı');
  ok('Belediye aday adaylığı başvurusu');
  // ölçülebilir vaat
  await tikla('Seçim bildirgeni yaz'); await bekle('ÖLÇÜLEBİLİR VAATLER');
  await page.locator('.secenek', { hasText: 'Kent lokantası açacağım' }).click();
  await page.locator('.secenek', { hasText: 'Toplu ulaşımı ücretsiz' }).click();
  await page.fill('#vmetin', 'İzmir\'de kent lokantası ve ücretsiz toplu ulaşım!');
  await bekle('Toplam'); await page.waitForTimeout(300);
  await foto('08b-vaat');
  await page.click('#vkaydet'); await toastBekle('vaatlerin kaydedildi');
  assert1(psql(`select string_agg(kod, ',' order by v.id) from oyun.vaatler v join oyun.profiller p on p.id=v.user_id where p.kad='Ercan'`) === 'lokanta,ulasim', 'vaatler kaydedilmedi');
  ok('Seçim bildirgesi: 2 ölçülebilir vaat, bütçe hesabıyla (kent lokantası, ücretsiz ulaşım)');

  // 8 Ekim ön seçim
  saat('2026-10-08 12:00');
  psql(`select oyun.test_bot_oy(${secimId('bel_on', '2026-10')})`);
  await yenile(); await bekle('Sandık açık');
  await foto('09-gundem-sandik');
  await tikla('Oy ver');
  await bekle('Oy pusulası');
  await page.locator('.pusula-secenek', { hasText: 'Ercan' }).click();
  await foto('10-pusula');
  await tikla('Mühürle ve sandığa at');
  await page.waitForTimeout(1600);
  await bekle('Oyunu kullandın');
  ok('Ön seçimde oy (mühür animasyonu)');

  saat('2026-10-08 18:01');
  // 10 Ekim belediye seçimi
  saat('2026-10-10 12:00');
  psql(`select oyun.test_bot_oy(${secimId('bel', '2026-10')})`);
  await yenile(); await tikla('Oy ver'); await bekle('Oy pusulası');
  await page.locator('.pusula-secenek').first().click();
  await tikla('Mühürle ve sandığa at'); await page.waitForTimeout(1600);
  saat('2026-10-10 18:01');
  const belKim = psql(`select p.kad from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='bel' and m.il_id=35 and m.bit is null`);
  console.log('   İzmir belediye başkanı:', belKim);
  if (!belKim) psql(`insert into oyun.makamlar(tur, user_id, il_id, parti_id, bas) select 'bel', id, 35, 1, oyun.simdi() from oyun.profiller where kad='Ercan'`);   // rastgele botlar İzmir'de kimseyi seçtirmediyse
  else if (belKim !== 'Ercan') psql(`update oyun.makamlar set user_id=(select id from oyun.profiller where kad='Ercan'), parti_id=1 where tur='bel' and il_id=35 and bit is null`); // ekranları göstermek için
  saat('2026-10-11 00:01');
  await yenile();
  await foto('11-gundem-belediye-sonrasi');
  await page.evaluate(() => sekmeAc('harita')); await bekle('İller (');
  await foto('12-harita-belediye');
  await page.locator('svg path').nth(34).click({ force: true }); await bekle('Belediye başkanı');
  await foto('13-il-detay');
  await page.evaluate(() => modalKapat());
  ok('Belediye seçimi ve harita');
  // ---- BELEDİYEM (3. aşama)
  await yenile(); await bekle('Belediyeme git');
  await tikla('Belediyeme git'); await bekle('Belediye kasası');
  await foto('13b-belediyem');
  await page.locator('.kart', { hasText: 'Kent lokantası' }).getByRole('button', { name: 'Aç', exact: true }).click();
  await page.click('#evet'); await toastBekle('Kent lokantası açıldı');
  await bekle('Vaat karnen'); await page.waitForTimeout(300);
  await foto('13c-belediye-karne');
  ok('Belediye başkanı kent lokantası hizmetini açtı; vaat karnesi 1/2');
  // ---- HAYAT (4. aşama): İzmir'de yaşayan oyuncu olarak lokantadan yararlan
  await yenile('hayat'); await bekle('Maaş kumbarası');
  await bekle('Kent lokantası');
  await foto('14a-hayat-kumbara');
  await page.click('#hTopla'); await toastBekle('maaş');
  await page.click('#hReklam'); await toastBekle('Reklam ödülü');
  await page.click('#hMagaza'); await page.locator('[data-urun="tl_10000"]').waitFor({ timeout: 5000 });
  await foto('14b-magaza');
  const paraOnce = +psql(`select para from oyun.cuzdan c join oyun.profiller p on p.id=c.user_id where p.kad='Ercan'`);
  await page.click('[data-urun="tl_10000"]'); await toastBekle('eklendi', 12000);
  const paraSonra = +psql(`select para from oyun.cuzdan c join oyun.profiller p on p.id=c.user_id where p.kad='Ercan'`);
  assert1(paraSonra - paraOnce === 10000, 'satın alma işlemedi: ' + (paraSonra - paraOnce));
  await page.waitForTimeout(300);
  await foto('14-hayat');
  assert1(psql(`select oyun.bonus(35::smallint,'gecim',oyun.simdi())`) === '15', 'lokanta geçim indirimi işlemedi');
  ok('Hayat: maaş kumbarası toplandı, ödüllü reklam izlendi, mağazadan 10.000 ₺ alındı; kent lokantası geçimi %15 düşürdü');
  // söz karnesi, şehir bağışı ve vergi karnesi
  await bekle('Söz karnen'); await bekle('Şehrine katkı');
  const kidemOnce = +psql(`select kidem from oyun.cuzdan c join oyun.profiller p on p.id=c.user_id where p.kad='Ercan'`);
  await page.click('#hBagis'); await bekle('kalkınma bağışı'); await bekle('HAYIRSEVERLERİ');
  await foto('14c-sehir-bagisi');
  await page.fill('#ibmik', '2000'); await page.click('#ibok'); await toastBekle('teşekkürler');
  assert1(+psql(`select kidem from oyun.cuzdan c join oyun.profiller p on p.id=c.user_id where p.kad='Ercan'`) > kidemOnce, 'bağış kıdem puanı vermedi');
  assert1(+psql(`select sum(tutar) from oyun.il_bagis_kayit`) === 2000, 'bağış kaydı yok');
  await bekle('Söz karnen');
  await page.click('#hVergi'); await bekle('Verginin karşılığı'); await bekle('KARŞILIĞINDA SANA İŞLEYENLER');
  await foto('14d-vergi-karnesi');
  await page.evaluate(() => modalKapat());
  ok('Hayat: söz karnesi kartı, şehir kalkınma bağışı (kıdem puanı verdi) ve vergi karnesi çalışıyor');

  // ---- KURULTAY 15-18
  saat('2026-10-15 10:00');
  psql(`select oyun.test_bot_aday('kurultay', 0.03)`);
  await yenile(); await tikla('Genel başkanlığa aday ol'); await bekle('öde ve başvur'); await page.click('#evet'); await bekle('Başvurun alındı');
  saat('2026-10-18 12:00');
  psql(`select oyun.test_bot_oy(${secimId('kurultay', '2026-10')})`);
  await yenile(); await tikla('Oy ver'); await bekle('Oy pusulası');
  await page.locator('.pusula-secenek', { hasText: 'Ercan' }).click();
  await tikla('Mühürle ve sandığa at'); await page.waitForTimeout(1600);
  saat('2026-10-18 18:01'); saat('2026-10-19 00:01');
  const gbMi = psql(`select (gb = (select id from oyun.profiller where kad='Ercan'))::text from oyun.partiler where id=1`);
  console.log('   Ercan CYP genel başkanı mı:', gbMi);
  if (gbMi !== 'true') psql(`update oyun.partiler set gb=(select id from oyun.profiller where kad='Ercan') where id=1`); // ekranları göstermek için
  saat('2026-10-20 12:00');
  await yenile(); await bekle('Cumhurbaşkanı adayı kararı');
  await foto('14-gundem-cb-karari');
  await tikla('Karar ver'); await tikla('Kendim aday olacağım'); await bekle('Kendin adaysın');
  await page.evaluate(() => { D.sekme = 'parti'; D.yigin = []; }); await page.evaluate(() => ekranAc(() => partiDetay(1)));
  await tikla('Yardımcıları ata'); await page.waitForTimeout(300);
  // genel başkan yardımcısı yalnızca milletvekili olabilir: listeden bir vekil seç
  const vekilUye = psql(`select p.kad from oyun.profiller p join oyun.makamlar m on m.user_id=p.id and m.tur='mv' and m.bit is null where p.parti_id=1 order by p.kad limit 1`);
  const ilkUye = vekilUye || await page.locator('#g1 option').nth(1).textContent();
  await page.selectOption('#g1', { label: ilkUye }); await tikla('Kaydet'); await bekle('GB Yardımcısı');
  await foto('15-parti-gb');
  ok('Kurultay, CB adayı kararı (kendisi), GB yardımcısı atama');
  // GB: parti seçim beyannamesi
  await page.locator('#kasaKart').getByRole('button', { name: 'Beyanname yaz' }).click(); await bekle('ÖLÇÜLEBİLİR VAATLER');
  await page.locator('.secenek', { hasText: 'Asgari ücreti artıracağız' }).click();
  await page.locator('.secenek', { hasText: 'Yeni vatandaşlara günlük sosyal destek' }).click();
  await page.fill('#vmetin', 'Asgari ücrete gerçek zam, yeni vatandaşa günlük destek!');
  await bekle('Toplam'); await page.waitForTimeout(500);
  await foto('19b-beyanname');
  await page.click('#vkaydet'); await toastBekle('Beyanname açıklandı');
  assert1(+psql(`select count(*) from oyun.vaatler where kapsam='beyanname' and parti_id=1`) === 2, 'beyanname vaatleri yok');
  ok('Genel başkan seçim beyannamesini bütçe hesabıyla açıkladı');

  // ---- GENEL SEÇİM
  saat('2026-10-26 10:00');
  psql(`select oyun.test_bot_aday('mv_on', 0.45)`); psql(`select oyun.test_bot_aday('cb_on', 0.02)`);
  // Ercan'ın (İzmir, CYP) oy verebileceği en az bir vekil adayı olsun (botlar rastgele olduğundan garanti edilir)
  if (+psql(`select count(*) from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id where s.tur='mv_on' and s.donem='2026-11' and a.il_id=35 and a.parti_id=1`) === 0) {
    const b = psql(`update oyun.profiller set il_id=35, parti_id=1 where id=(select id from oyun.profiller where kad like 'Bot\\_%' and id not in (select user_id from oyun.adaylar) and id not in (select user_id from oyun.makamlar where bit is null) order by kad limit 1) returning id`).split('\n')[0];
    rpc(b, 'aday_ol', { p_tur: 'mv_on' });
  }
  // tek görev kuralı: genel başkan milletvekili adayı olamaz
  await yenile(); await tikla('Milletvekili aday adayı ol'); await bekle('Seçimi kazanırsan'); await foto('19c-tek-gorev-uyari');
  await page.click('#evet'); await toastBekle('Genel başkan milletvekili');
  ok('Tek görev kuralı: genel başkan milletvekili adayı olamıyor (uyarı + sunucu reddi)');
  saat('2026-10-28 12:00');
  psql(`select oyun.test_bot_oy(${secimId('mv_on', '2026-11')})`); psql(`select oyun.test_bot_oy(${secimId('cb_on', '2026-11')})`);
  await yenile(); await foto('16-gundem-onsecim');
  await page.locator('.olay', { hasText: 'Milletvekili Ön Seçimi' }).getByRole('button', { name: 'Oy ver' }).click();
  await bekle('Oy pusulası'); await page.locator('.pusula-secenek').first().click();
  await foto('16b-pusula-bildirge');
  await tikla('Mühürle ve sandığa at'); await page.waitForTimeout(1600);
  saat('2026-10-28 18:01');
  saat('2026-11-01 12:00');
  psql(`select oyun.test_bot_oy(${secimId('mv', '2026-11')})`); psql(`select oyun.test_bot_oy(${secimId('cb', '2026-11')})`);
  await yenile(); await foto('17-gundem-genel-secim');
  await page.locator('.olay', { hasText: 'Genel Seçim' }).getByRole('button', { name: 'Oy ver' }).click();
  await bekle('Oy pusulası'); await foto('18-pusula-genel');
  await page.locator('.pusula-secenek', { hasText: 'Cumhuriyet Yolu' }).click();
  await tikla('Mühürle ve sandığa at'); await page.waitForTimeout(1600);
  await yenile();
  await page.locator('.olay', { hasText: 'Cumhurbaşkanlığı Seçimi' }).getByRole('button', { name: 'Oy ver' }).click();
  await bekle('Oy pusulası'); await foto('19-pusula-cb');
  await page.locator('.pusula-secenek', { hasText: 'Ercan' }).click();
  await tikla('Mühürle ve sandığa at'); await page.waitForTimeout(1600);
  saat('2026-11-01 18:01');
  await yenile(); await foto('20-gundem-sonuc');
  await page.locator('.olay', { hasText: 'Genel Seçim' }).getByRole('button', { name: 'Sonuçları gör' }).click();
  await bekle('Türkiye geneli'); await foto('21-sonuc-genel');
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.locator('#icerik').evaluate(el => el.scrollTop = 700); await foto('22-sonuc-genel-il');
  ok('Ön seçim, genel seçim ve CB oyu, sonuç ekranı');

  const cb2 = psql(`select count(*) from oyun.secimler where tur='cb2'`);
  if (cb2 === '1') {
    saat('2026-11-02 12:00');
    psql(`select oyun.test_bot_oy(${secimId('cb2', '2026-11')})`);
    await yenile(); await foto('23-gundem-ikinci-tur');
    saat('2026-11-02 18:01');
  }
  saat('2026-11-03 00:01');
  await page.evaluate(() => { D.devletSekme = 'hukumet'; sekmeAc('devlet'); }); await bekle('Ülke karnesi');
  await foto('24-devlet');
  // ---- KABİNE: Ercan cumhurbaşkanıysa bakan ata
  const cbKim = psql(`select p.kad from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='cb' and m.bit is null`);
  console.log('   Cumhurbaşkanı:', cbKim);
  if (cbKim !== 'Ercan') psql(`update oyun.makamlar set bit=now() where tur='cb' and bit is null; insert into oyun.makamlar(tur,user_id,parti_id,bas) select 'cb', id, parti_id, '2026-11-03 00:00+03' from oyun.profiller where kad='Ercan'`);
  await yenile('devlet'); await bekle('Kabine (0/12)');
  const botlar = psql(`select string_agg(kad, ',' order by kad) from (select kad from oyun.profiller where kad like 'Bot\\_%' and id not in (select user_id from oyun.makamlar where bit is null) order by random() limit 4) x`).split(',');
  for (let i = 0; i < 4; i++) {
    await page.locator('.liste-satir', { hasText: ['Adalet Bakanı','Dışişleri Bakanı','İçişleri Bakanı','Hazine ve Maliye Bakanı'][i] }).getByRole('button', { name: 'Ata' }).click();
    await page.fill('#bkad', botlar[i]); await page.click('#ata'); await page.waitForTimeout(500);
  }
  await bekle('Kabine (4/12)');
  await foto('25-kabine');
  ok('Kabine: cumhurbaşkanı arayüzden 4 bakan atadı');

  // ---- BOŞ MAKAMLAR / VEKÂLET
  await bekle('Boş makamlar'); await bekle('Vekâleten yönettiğin bakanlıklar');
  await page.locator('details.vekil-bakanlik').first().locator('summary').click();
  await page.waitForTimeout(300);
  await foto('25b-bos-makamlar');
  ok('Boş makamlar panosu ve cumhurbaşkanının vekâlet bölümü görünüyor');

  // ---- SOHBET
  const uid = (kad) => psql(`select id from oyun.profiller where kad='${kad}'`);
  const botYaz = (kad, kanal, metin) => psql(`select set_config('request.jwt.claim.sub','${uid(kad)}',false); select public.sohbet_yaz('${kanal}', '${metin}')`);
  const izmirBot = psql(`select kad from oyun.profiller where il_id=35 and parti_id=1 and kad like 'Bot%' limit 1`);
  botYaz(botlar[0], 'genel', 'Herkese merhaba, Adalet Bakanı olarak göreve başladım.');
  botYaz(botlar[1], 'genel', 'Yeni kabineye başarılar!');
  try { if (izmirBot) botYaz(izmirBot, 'il', 'İzmirliler, belediye seçiminde birlik olalım.'); } catch (_) {}
  await page.evaluate(() => sekmeAc('sohbet')); await bekle('Türkiye Meydanı');
  await bekle('Belediye Meclisi'); await bekle('Bakanlar Kurulu'); await bekle('Yönetim Kurulu');
  await foto('25-sohbet-kanallar');
  await page.getByText('Türkiye Meydanı').click(); await bekle('Yeni kabineye başarılar!');
  await page.fill('#yaz', 'Teşekkürler arkadaşlar, hep birlikte çalışacağız!'); await page.click('#gonder');
  await bekle('hep birlikte çalışacağız');
  saat('2026-11-03 00:02');
  await page.fill('#yaz', 'Sen bir şerefsizsin'); await page.click('#gonder');
  await bekle('uygunsuz bir ifade');
  await page.fill('#yaz', '');
  botYaz(botlar[2], 'genel', 'Sayın Cumhurbaşkanım, İçişleri için hazırım.');
  await page.waitForTimeout(4600); await bekle('İçişleri için hazırım');
  await foto('26-sohbet-genel');
  await page.locator('.balon', { hasText: 'İçişleri için hazırım' }).click(); await bekle('Mesajı şikâyet et');
  await foto('27-mesaj-menu');
  await tikla('Oyuncu kartı'); await bekle('Siyasi geçmiş');
  await foto('28-oyuncu-karti');
  await page.evaluate(() => modalKapat());
  ok('Sohbet: kanal, mesaj gönderme, küfür filtresi, canlı yeni mesaj, mesaj menüsü, oyuncu kartı');

  // ---- ÖZEL MESAJ
  psql(`select set_config('request.jwt.claim.sub','${uid(botlar[3])}',false); select public.ozel_yaz('Ercan', 'Sayın Cumhurbaşkanım, Maliye için bir dosya hazırladım. Görüşebilir miyiz?')`);
  await page.evaluate(() => rozetGuncelle({ bildirim: 0, ozel: 0 }));
  await page.evaluate(async () => rozetGuncelle(await API.rpc('rozetler')));
  await page.evaluate(() => { D.yigin = []; sekmeAc('sohbet'); }); await bekle('Özel mesajlar');
  await foto('29-sohbet-liste');
  await page.locator('.kanal', { hasText: 'Maliye için bir dosya' }).first().click(); await bekle('Maliye için bir dosya');
  saat('2026-11-03 00:03');
  await page.fill('#yaz', 'Yarın Külliye\'de görüşelim.'); await page.click('#gonder'); await bekle('Külliye');
  await foto('30-ozel-mesaj');
  ok('Özel mesaj: okunmamış rozeti, konuşma listesi, yanıt');

  // ---- PROPAGANDA
  psql(`select set_config('request.jwt.claim.sub','${uid(botlar[0])}',false); select public.yayin_gonder('bakan', 'Adalet Bakanlığı olarak yargı reformu paketimizi yarın Meclise sunuyoruz.', null)`);
  await page.evaluate(() => { D.yigin = []; sekmeAc('gundem'); }); await page.waitForTimeout(500);
  await page.evaluate(() => ekranAc(bildirimEkrani)); await bekle('Propaganda yayınla');
  await tikla('Yeni yayın'); await page.waitForTimeout(300);
  await foto('31-yayin-modal');
  await page.locator('.secenek', { hasText: 'Cumhurbaşkanı' }).click();
  await page.fill('#ymetin', 'Aziz milletim! Yeni dönemde 81 ilimize hizmet için kabinemizi kurduk. Hayırlı olsun.');
  await tikla('Yayınla'); await bekle('kişiye ulaştı');
  await page.waitForTimeout(600);
  await foto('32-bildirimler');
  ok('Propaganda: ulusa sesleniş gönderildi, bakan açıklaması bildirim kutusunda');
  await page.evaluate(() => { D.sekme = 'parti'; D.yigin = []; ekranAc(() => partiDetay(1)); }); await bekle('GB Yardımcısı 6');
  await foto('33-parti-6gby');

  // ================= 2. AŞAMA =================
  const girisYap = async (kad) => { await page.evaluate(async (k) => { await window.__api('testGiris', k); D.durum = null; D.yigin = []; await basla(); }, kad); await page.waitForTimeout(600); };
  const botlarOyla = (kid, oy) => psql(`do $$ declare r record; begin for r in select user_id from oyun.makamlar where tur='mv' and bit is null loop
      perform set_config('request.jwt.claim.sub', r.user_id::text, true); begin perform public.kanun_oy(${kid}, '${oy}'); exception when others then null; end; end loop; end $$;`);
  // CB: hükümet ekranı ve kararname
  await page.evaluate(() => { D.devletSekme = 'hukumet'; sekmeAc('devlet'); }); await bekle('Ülke karnesi');
  await foto('37-hukumet');
  await tikla('Kararname çıkar'); await page.waitForTimeout(300);
  await page.selectOption('#kil', '35'); await page.fill('#kmik', '15'); await page.fill('#kmetin', 'İzmir\'in altyapı yatırımları için kalkınma desteği verilmiştir.');
  await foto('38-kararname');
  await page.click('#kimza'); await bekle('Resmî Gazete\'de yayımlandı');
  ok('2. aşama: CB hükümet ekranı ve kararname (İzmir\'e 15 milyar ₺ destek)');
  await tikla('Kararname çıkar'); await page.waitForTimeout(300);
  await page.selectOption('#ktur', 'ikramiye'); await page.fill('#kikr', '1000'); await page.waitForTimeout(200);
  await foto('38b-ikramiye');
  await page.click('#kimza'); await bekle('Resmî Gazete\'de yayımlandı');
  assert1(+psql(`select count(*) from oyun.hesap_hareket where tur='ikramiye'`) >= 1, 'ikramiye ödenmedi');
  ok('Kararname: bayram ikramiyesi aktif oyunculara ödendi');
  // CB: ekonomi masası (asgari ücret)
  await page.locator('#ekonomiMasasi').scrollIntoViewIfNeeded();
  await page.fill('[data-pol="asgari"] input', '30000'); await bekle('Bütçeye etkisi'); await page.waitForTimeout(200);
  await page.locator('[data-pol="asgari"]').scrollIntoViewIfNeeded();
  await foto('38c-ekonomi-masasi');
  await page.locator('[data-pol="asgari"] button').click(); await toastBekle('Resmî Gazete\'de yayımlandı');
  assert1(+psql(`select asgari from oyun.ulke`) === 30000, 'asgari ücret değişmedi');
  ok('CB ekonomi masası: asgari ücret 30.000 ₺ yapıldı (bütçe ve enflasyon etkisi önizlendi)');
  // Bakan: icraat
  await girisYap(botlar[0]);
  await page.evaluate(() => { D.devletSekme = 'hukumet'; sekmeAc('devlet'); }); await bekle('Bakanlık kasası');
  await page.locator('.olay', { hasText: 'Bakanlık kasası' }).scrollIntoViewIfNeeded();
  await foto('39-bakanlik');
  await page.locator('.kart', { hasText: 'Harç muafiyeti' }).getByRole('button', { name: 'Uygula' }).click();
  await page.click('#evet'); await bekle('başlatıldı');
  await bekle('Yürürlükte');
  ok('Bakan icraatı: Adalet Bakanı harç muafiyetiyle taşınma ücretini yarıya indirdi');
  // Vekil: bütçe kanunu teklifi
  const vekilBot = psql(`select p.kad from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='mv' and m.bit is null and p.kad like 'Bot%' limit 1`);
  await girisYap(vekilBot);
  await page.evaluate(() => { D.devletSekme = 'meclis'; sekmeAc('devlet'); }); await bekle('Gündemdeki teklifler');
  await tikla('+ Kanun teklifi ver'); await page.waitForTimeout(400);
  await page.selectOption('#ktur', 'butce');
  await page.fill('#kbaslik', '2027 Yılı Merkezî Yönetim Bütçe Kanunu');
  await page.fill('#kgerekce', 'Vergi tavanı %30\'a indirilir, belediyelerin payı %12\'ye çıkar; eğitim ve sağlık bütçeleri artırılır.');
  await page.fill('[data-b="vergi_ust"]', '30'); await page.fill('[data-b="belediye_payi"]', '12');
  await page.fill('[data-k="egitim"]', '17'); await page.fill('[data-k="saglik"]', '16'); await page.fill('[data-k="savunma"]', '6');
  await page.waitForTimeout(200);
  await foto('40-kanun-teklif');
  await page.click('#kver'); await bekle('Gerekçe');
  const kid = +psql(`select max(id) from oyun.kanunlar`);
  saat('2026-11-04 00:10');
  await page.evaluate((id) => kanunEkrani(id), kid); await bekle('Oyunu kullan');
  await page.locator('.oybtn button', { hasText: 'Kabul' }).click(); await bekle('Oyun kaydedildi');
  botlarOyla(kid, 'kabul');
  await page.evaluate((id) => kanunEkrani(id), kid); await page.waitForTimeout(500);
  await foto('41-kanun-oylama');
  ok('Vekil bütçe kanunu teklif etti, oylamada kabul oyu verdi');
  saat('2026-11-05 00:11');
  // CB: veto
  await girisYap('Ercan');
 await bekle('Onayını bekleyen');
  await foto('42-gundem-onay');
  await page.locator('.olay', { hasText: 'Onayını bekleyen' }).locator('.liste-satir').first().click(); await bekle('Onayınızı bekliyor');
  await tikla('Veto et'); await page.fill('#vgerekce', 'Vergi indirimi hazineyi açığa düşürür, savunma payı çok düşük.'); await page.click('#vok');
  await bekle('Meclis\'e iade edildi'); await page.waitForTimeout(400);
  await foto('43-veto');
  botlarOyla(kid, 'kabul');
  saat('2026-11-06 00:12');
  const kdurum = psql(`select durum from oyun.kanunlar where id=${kid}`);
  console.log('   Bütçe kanunu son durum:', kdurum);
  await page.evaluate(() => { D.devletSekme = 'gazete'; sekmeAc('devlet'); }); await bekle('Resmî Gazete');
  await foto('44-resmi-gazete');
  ok('CB veto etti, Meclis ısrar oylaması yaptı, Resmî Gazete');
  // İttifak
  const abpGb = psql(`select kad from oyun.profiller where parti_id=2 and kad like 'Bot%' and id not in (select user_id from oyun.makamlar where bit is null and tur='cb') limit 1`);
  psql(`update oyun.partiler set gb=(select id from oyun.profiller where kad='${abpGb}') where id=2`);
  await page.evaluate(() => { D.sekme = 'parti'; D.yigin = []; ekranAc(() => partiDetay(1)); }); await bekle('İttifak kur');
  await tikla('İttifak kur'); await page.fill('#iad', 'Anadolu Cephesi'); await page.click('#ikur'); await bekle('İttifak kuruldu');
  await tikla('Partiyi ittifaka davet et'); await page.selectOption('#ipar', '2'); await page.click('#idav'); await bekle('Davet gönderildi');
  await girisYap(abpGb); await bekle('İttifak daveti');
  await foto('45-ittifak-davet');
  await tikla('Davetleri gör'); await bekle('Kabul et'); await tikla('Kabul et'); await bekle('İttifaka katıldınız');
  await page.waitForTimeout(500);
  await page.locator('#ittifakKart').scrollIntoViewIfNeeded(); await foto('46-ittifak');
  // parti kasası (hazine yardımı + bağış)
  await girisYap('Ercan');
  await page.evaluate(() => { D.sekme = 'parti'; D.yigin = []; ekranAc(() => partiDetay(1)); }); await bekle('Parti kasası');
  await tikla('Partine bağış yap'); await page.fill('#bmik', '150'); await page.click('#bok'); await bekle('teşekkürler');
  await page.waitForTimeout(500);
  await page.locator('#kasaKart').scrollIntoViewIfNeeded(); await foto('46b-parti-kasa');
  assert1(+psql(`select count(*) from oyun.parti_hareket where parti_id=1 and aciklama like 'Hazine%'`) >= 1, 'hazine yardımı yok');
  ok('Parti kasası: genel seçim sonrası hazine yardımı geldi, üye bağışı eklendi');
  ok('İttifak: CYP kurdu, ABP\'yi davet etti, ABP genel başkanı gündemden davete ulaşıp kabul etti');
  await page.evaluate(() => { D.haritaMod = 'gelisim'; sekmeAc('harita'); }); await bekle('Gelişmişlik');
  await foto('47-harita-gelisim');
  await girisYap('Ercan');
  // ---- YÖNETİCİ PANELİ ve bildirim ayarları
  psql(`update oyun.profiller set yonetici=true where kad='Ercan'`);
  saat('2026-11-06 10:00');
  const trol = botlar[1];
  botYaz(trol, 'genel', 'Bu oyunu oynayanlar aptal');
  const tmid = psql(`select max(id) from oyun.mesajlar`);
  for (const b of [botlar[2], botlar[3]]) psql(`select set_config('request.jwt.claim.sub','${uid(b)}',false); select public.sikayet_et('mesaj', ${tmid}, null, 'hakaret')`);
  await page.evaluate(() => sekmeAc('ben')); await bekle('Bildirimler');
  await page.locator('[data-ayar="propaganda"]').scrollIntoViewIfNeeded(); await foto('48-bildirim-ayar');
  await page.locator('[data-ayar="propaganda"]').click(); await bekle('tercihlerin kaydedildi');
  await page.waitForTimeout(400);
  konular = await page.evaluate(() => window.__konular.slice().sort());
  assert1(!konular.some(t => t.startsWith('p_')) && konular.includes('s_tum'), 'propaganda kapatılınca konular: ' + konular);
  ok('Bildirim ayarı: propaganda kapatılınca p_ konularından çıkıldı, seçim hatırlatmaları kaldı');
  await tikla('Yönetici paneli'); await bekle('Açık şikâyetler');
  await foto('49-yonetici');
  await page.locator('[data-k="gizle_sustur1"]').first().click(); await bekle('Karar uygulandı');
  assert1(psql(`select gizli from oyun.mesajlar where id=${tmid}`) === 't', 'mesaj gizlenmedi');
  ok('Yönetici paneli: şikâyet görüldü, mesaj gizlendi ve oyuncu 1 gün susturuldu');
  // push bildirimine dokunma → ilgili ekran
  await page.evaluate(() => window.__dinle.notificationActionPerformed({ notification: { data: { ekran: 'ozel', kad: 'Bot_1' } } }));
  await page.waitForTimeout(800);
  assert1(await page.locator('#yaz').count() === 1, 'özel mesaj ekranı açılmadı');
  ok('Push bildirimine dokununca ilgili ekran (özel mesaj) açıldı');
  await page.evaluate(() => sekmeAc('harita')); await page.getByRole('button', { name: 'Vekil', exact: true }).click(); await page.waitForTimeout(300);
  await foto('34-harita-vekil');
  await page.evaluate(() => sekmeAc('ben')); await bekle('Geçmiş seçimler');
  await foto('35-profil');
  await yenile('hayat'); await bekle('Makam maaşı');
  await foto('50-hayat-cb');
  await page.evaluate(() => oyuncuKart('Ercan')); await bekle('Vaat karnesi');
  await foto('51-vaat-karnesi');
  await page.evaluate(() => modalKapat());
  ok('Cumhurbaşkanının makam maaşı ve oyuncu kartında vaat karnesi');
  await page.evaluate(() => { D.sekme = 'parti'; D.yigin = []; ekranAc(partiKurEkrani); });
  await page.fill('#ad', 'Yarın Partisi'); await page.fill('#kisa', 'YRN');
  await page.locator('.renkler button').nth(5).click(); await page.locator('.amblemler button').nth(8).click();
  await foto('36-parti-kur');
  ok('Vekil haritası, profil, parti kurma ekranı');

  // ---- MEVZUAT · KARARNAMEYLE KURAL · TAHVİL · BAKAN ARAMA · HALK OYLAMASI · BELEDİYE KARARI
  await page.evaluate(() => { D.sekme = 'devlet'; D.devletSekme = 'mevzuat'; D.yigin = []; sekmeAc('devlet'); }); await bekle('Devletin kasası');
  const hibe = page.locator('[data-kural="yeni_hibe"]');
  await hibe.locator('input').fill('5000'); await page.waitForTimeout(600);
  await hibe.locator('[data-kkarar]').click(); await page.click('#evet'); await bekle("Resmî Gazete'de yayımlandı");
  assert1(psql(`select deger from oyun.duzenlemeler where kod='yeni_hibe'`) === '5000', 'hoş geldin hibesi kararnamesi uygulanmadı');
  await bekle('Cumhurbaşkanlığı kararnamesi'); await page.waitForTimeout(300);
  await page.locator('[data-kural="yeni_hibe"]').scrollIntoViewIfNeeded(); await foto('52-mevzuat');
  await page.evaluate(() => kararnameModal('tahvil')); await bekle('Devlet iç borçlanma'); await page.fill('#kmik', '30'); await page.waitForTimeout(200);
  await foto('53-tahvil');
  await page.click('#kimza'); await bekle("Resmî Gazete'de yayımlandı");
  assert1(+psql(`select count(*) from oyun.borclar`) === 1, 'tahvil kaydı yok');
  ok('Mevzuat: cumhurbaşkanı kararnameyle hoş geldin hibesi getirdi ve tahvil ihraç etti');
  await page.evaluate(() => bakanAtaModal('egitim', 'Millî Eğitim Bakanlığı', true)); await bekle('Seç'); await page.waitForTimeout(200);
  await foto('54-bakan-ara'); await page.evaluate(() => modalKapat());
  ok('Bakan atama: oyuncu arama listesi uygun adayları ve engelleri gösteriyor');
  const ak = psql(`insert into oyun.kanunlar(tur,baslik,metin,veri,teklif_eden,teklif_parti,durum,teklif_at,oy_bas,oy_bit)
    select 'anayasa','Sandık Görevi Anayasa Değişikliği','Seçimlere katılım vatandaşlık görevidir; sandığa gitmeyene ceza anayasal güvenceye alınır.',
           '{"madde":"duzenleme","kod":"oy_cezasi","deger":500}', id, parti_id, 'oylamada', '2026-11-03 00:00+03','2026-11-04 00:00+03','2026-11-05 00:00+03'
    from oyun.profiller where kad='${vekilBot}' returning id`).split('\n')[0];
  const rid = psql(`select oyun.referandum_baslat(${ak}, '2026-11-05 00:00+03')`).split('\n')[0];
  saat('2026-11-06 10:01');
  await page.evaluate(() => { D.sekme = 'gundem'; D.yigin = []; sekmeAc('gundem'); }); await bekle('Sandığa git');
  await foto('55-gundem-halkoylamasi');
  await page.locator('.olay', { hasText: 'Halk oylaması' }).first().click(); await bekle('Oy pusulası');
  await foto('56-halkoylamasi-pusula');
  await page.click('.ref-daire.evet'); await page.click('#refmuhur'); await bekle('Oyun sandıkta');
  await foto('57-oy-sandikta');
  const secmenler = psql(`select kad from oyun.profiller where kad like 'Bot%' order by kad limit 40`).split('\n');
  secmenler.forEach((b, i) => psql(`select set_config('request.jwt.claim.sub','${uid(b)}',false); select public.referandum_oy(${rid}, '${i % 3 === 0 ? 'hayir' : 'evet'}')`));
  saat('2026-11-06 20:05');
  await page.evaluate((id) => referandumEkrani(id), +rid); await bekle('Sonuç:'); await page.waitForTimeout(300);
  await foto('58-halkoylamasi-sonuc');
  assert1(psql(`select sonuc from oyun.referandumlar where id=${rid}`) === 'kabul' && psql(`select kaynak from oyun.duzenlemeler where kod='oy_cezasi'`) === 'anayasa', 'halk oylaması sonucu uygulanmadı');
  ok('Halk oylaması: gündemde sandık kartı, Evet/Hayır pusulası, mühür, il il sonuç; kabul edilen kural anayasaya bağlandı');
  const baskanBot = psql(`select p.kad from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='bel' and m.bit is null and p.kad like 'Bot%' limit 1`);
  if (baskanBot) {
    await girisYap(baskanBot);
    await page.evaluate(() => { D.yigin = []; ekranAc(belediyeEkrani); }); await bekle('Belediye meclisi kararları');
    const emlak = page.locator('[data-bkural="emlak"]');
    await emlak.locator('input').fill('50'); await emlak.locator('button').click(); await page.click('#evet'); await bekle('Belediye meclisi kararı yürürlükte');
    await page.locator('[data-bkural="emlak"]').scrollIntoViewIfNeeded(); await page.waitForTimeout(300);
    await foto('59-belediye-kurallari');
    ok('Belediye başkanı emlak vergisini belediye meclisi kararıyla belirledi');
    // arsa ihalesi: başkan ihaleye çıkarır, ilde yaşayan bir oyuncu pey sürer
    await page.evaluate(() => { D.yigin = []; ekranAc(belediyeEkrani); }); await bekle('İhaleye çıkar');
    await page.locator('.kart', { hasText: 'Belediye arsası ihalesi' }).getByRole('button', { name: 'İhaleye çıkar' }).click();
    await page.click('#evet'); await bekle('başladı');
    const ilId = psql(`select il_id from oyun.makamlar where tur='bel' and bit is null and user_id=(select id from oyun.profiller where kad='${baskanBot}')`);
    const sakin = psql(`select kad from oyun.profiller where il_id=${ilId} and kad like 'Bot%' and kad<>'${baskanBot}' limit 1`);
    if (sakin) {
      psql(`select oyun.cuzdanim(id) from oyun.profiller where kad='${sakin}'; update oyun.cuzdan set para=greatest(para, 200000) where user_id=(select id from oyun.profiller where kad='${sakin}')`);   // teminat için yeterli para
      await girisYap(sakin); await bekle('arsa ihalesi');
      await foto('60-gundem-ihale');
      await page.locator('.olay', { hasText: 'arsa ihalesi' }).getByRole('button', { name: /Pey sür/ }).click(); await bekle('Kazanırsan günlük kira');
      await foto('61-ihale-teklif');
      await page.click('#aok'); await bekle('Teklifin alındı');
      assert1(psql(`select count(*) from oyun.arsa_ihale where en_yuksek_user=(select id from oyun.profiller where kad='${sakin}')`) === '1', 'teklif kaydedilmedi');
      ok('Arsa ihalesi: başkan ihaleye çıkardı, ilde yaşayan oyuncu gündemden pey sürdü');
    }
  }
  // ---- TBMM BAŞKANLIK DİVANI
  psql(`select oyun.meclis_donem_baslat(null, oyun.simdi())`);
  const vek = psql(`select p.kad from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='mv' and m.bit is null and p.kad like 'Bot%' order by p.kad limit 1`);
  await girisYap(vek);
  await page.evaluate(() => { D.devletSekme = 'meclis'; D.yigin = []; sekmeAc('devlet'); }); await bekle('TBMM Başkanlık Divanı');
  await page.getByRole('button', { name: 'TBMM Başkanlığına aday ol' }).click(); await bekle('Adaylığın alındı');
  await page.waitForTimeout(900); try { await page.locator('.olay', { hasText: 'TBMM Başkanlığı seçimi' }).first().scrollIntoViewIfNeeded({ timeout: 3000 }); } catch (_) {} await foto('62-tbmm-adaylik');
  const simdiTs = psql(`select to_char((oyun.simdi() + interval '24 hours 2 minutes') at time zone 'Europe/Istanbul', 'YYYY-MM-DD HH24:MI')`);
  saat(simdiTs);
  await page.evaluate(() => { D.devletSekme = 'meclis'; D.yigin = []; sekmeAc('devlet'); }); await bekle('1. tur');
  await page.locator('.olay', { hasText: 'TBMM Başkanlığı seçimi' }).getByRole('button', { name: 'Oy ver' }).first().click(); await page.click('#evet'); await bekle('Oyun sandıkta');
  const msid = psql(`select id from oyun.meclis_secim where tur='baskan' and durum='oylama'`);
  const vekiller = psql(`select p.kad from oyun.makamlar m join oyun.profiller p on p.id=m.user_id where m.tur='mv' and m.bit is null and p.kad<>'${vek}'`).split('\n').filter(Boolean);
  vekiller.forEach(v => { try { psql(`select set_config('request.jwt.claim.sub','${uid(v)}',false); select public.meclis_oy(${msid}, 'baskan', '${vek}')`); } catch (_) {} });
  await page.evaluate(() => { D.devletSekme = 'meclis'; D.yigin = []; sekmeAc('devlet'); }); await bekle('Oyunu kullandın');
  await page.waitForTimeout(900); try { await page.locator('.olay', { hasText: 'TBMM Başkanlığı seçimi' }).first().scrollIntoViewIfNeeded({ timeout: 3000 }); } catch (_) {} await foto('63-tbmm-oylama');
  saat(psql(`select to_char((oyun.simdi() + interval '13 hours') at time zone 'Europe/Istanbul', 'YYYY-MM-DD HH24:MI')`));
  await page.evaluate(() => { D.devletSekme = 'meclis'; D.yigin = []; sekmeAc('devlet'); }); await bekle('TBMM Başkanı');
  assert1(psql(`select count(*) from oyun.makamlar where tur='tbmm' and bit is null`) === '1', 'TBMM Başkanı seçilmedi');
  await page.waitForTimeout(900); try { await page.locator('.kart', { hasText: 'TBMM Başkanlık Divanı' }).first().first().scrollIntoViewIfNeeded({ timeout: 3000 }); } catch (_) {} await foto('64-tbmm-divan');
  ok('TBMM Başkanlığı: vekil aday oldu, gizli oy verdi; ilk turda üçte iki ile Meclis Başkanı seçildi');
  await page.evaluate(() => vatandaslikModal()); await bekle('Seçmen kartın');
  await foto('65-secmen-karti'); await page.evaluate(() => modalKapat());
  ok('Seçmen kartı: oy, adaylık ve parti kurma şartları listeleniyor');
  psql(`update oyun.ayarlar set min_uygulama='2099.01.01-1'`);
  await page.evaluate(() => basla()); await bekle('Güncelleme gerekli');
  await foto('66-guncelleme-gerekli');
  psql(`update oyun.ayarlar set min_uygulama='0'`);
  await page.evaluate(() => basla()); await bekle('Gündem');
  ok('Zorunlu güncelleme: sunucu eski uygulamayı desteklemeyince güncelleme ekranı çıktı; sürüm uyunca oyun kaldığı yerden açıldı');

  // ---- BANKA · PARA GÖNDERME · PARTİ ÜCRETİ VE İL TEŞKİLATI · MODERATÖRLER
  await girisYap('Ercan');
  psql(`update oyun.cuzdan set para=200000 where user_id=(select id from oyun.profiller where kad='Ercan')`);
  await yenile('hayat'); await bekle('Bankaya git');
  await page.locator('.kart', { hasText: 'Bankaya git' }).first().scrollIntoViewIfNeeded(); await foto('70-hayat-banka');
  await tikla('🏦 Bankaya git'); await bekle('Vadesiz hesap');
  await page.click('#bYatir'); await page.fill('#tmik', '50000'); await page.click('#tok'); await toastBekle('faiz işlemeye başladı');
  await page.click('#bVadeli'); await page.fill('#tmik', '20000'); await page.selectOption('#tsec', '30'); await page.waitForTimeout(200);
  await foto('71-vadeli-modal'); await page.click('#tok'); await toastBekle('Vadeli hesabın açıldı');
  await page.click('#kCek'); await page.fill('#tmik', '15000'); await page.selectOption('#tsec', '15'); await page.waitForTimeout(200);
  await foto('72-kredi-modal'); await page.click('#tok'); await toastBekle('Kredin cüzdanına geçti');
  await foto('73-banka');
  assert1(psql(`select vadesiz from oyun.banka_musteri m join oyun.profiller p on p.id=m.user_id where p.kad='Ercan'`) === '50000', 'vadesiz hesaba yatırılmadı');
  assert1(psql(`select count(*) from oyun.krediler k join oyun.profiller p on p.id=k.user_id where p.kad='Ercan' and k.durum='aktif'`) === '1', 'kredi açılmadı');
  ok('Banka: vadesiz hesaba yatırma, 30 gün vadeli hesap ve 15 gün kredi ekrandan yapıldı');
  const alici = botlar[3];
  const once = +psql(`select para from oyun.cuzdan c join oyun.profiller p on p.id=c.user_id where p.kad='${alici}'`);
  await page.evaluate((k) => oyuncuKart(k), alici); await bekle('Özel mesaj gönder');
  await page.click('#kp'); await bekle('Gönderdiğin para'); await page.fill('#pgMik', '2500'); await page.fill('#pgNot', 'Kampanya desteği'); await page.waitForTimeout(300);
  await foto('74-para-gonder'); await page.click('#pgOk'); await toastBekle('gönderildi');
  assert1(+psql(`select para from oyun.cuzdan c join oyun.profiller p on p.id=c.user_id where p.kad='${alici}'`) === once + 2500, 'para alıcıya geçmedi');
  ok('Para gönderme: oyuncu kartından 2.500 ₺ gönderildi, alıcının cüzdanına geçti');

  const kurucu = botlar[0];
  psql(`update oyun.ayarlar set parti_kur_ucret=25000, teskilat_zorunlu=true; update oyun.cuzdan set para=60000 where user_id=(select id from oyun.profiller where kad='${kurucu}')`);
  await girisYap(kurucu);
  await page.evaluate(() => { D.sekme = 'parti'; D.yigin = []; ekranAc(partiKurEkrani); }); await bekle('Kuruluş ücreti');
  await page.fill('#ad', 'Teşkilat Deneme Partisi'); await page.fill('#kisa', 'TDP'); await page.waitForTimeout(200);
  await page.locator('#kurUcret').scrollIntoViewIfNeeded(); await foto('75-parti-kur-ucret');
  await page.click('#kur'); await toastBekle('Partin kuruldu');
  const tdp = psql(`select id from oyun.partiler where kisa='TDP'`);
  const ucret = +psql(`select kurulus_ucret from oyun.partiler where id=${tdp}`);    // 25.000 ₺ × fiyat düzeyi
  assert1(ucret >= 25000 && +psql(`select para from oyun.cuzdan c join oyun.profiller p on p.id=c.user_id where p.kad='${kurucu}'`) === 60000 - ucret, 'kuruluş ücreti alınmadı');
  psql(`update oyun.partiler set kasa=20000 where id=${tdp}`);
  await page.evaluate((id) => ekranAc(() => partiDetay(id)), +tdp); await bekle('İl teşkilatları');
  await page.locator('#teskilatKart').scrollIntoViewIfNeeded(); await foto('76-teskilat');
  await tikla('İl teşkilatı aç'); await page.selectOption('#tkil', '6'); await page.waitForTimeout(200);
  await foto('77-teskilat-ac'); await page.click('#tkok'); await toastBekle('İl teşkilatı açıldı');
  assert1(psql(`select count(*) from oyun.parti_teskilat where parti_id=${tdp}`) === '2', 'teşkilat açılmadı');
  ok('Parti kurarken ücret gösterildi ve alındı; genel başkan Ankara il teşkilatını açtı');

  psql(`select set_config('request.jwt.claim.sub', (select id::text from oyun.profiller where kad='Ercan'), false); select public.admin_moderator_ayarla('${botlar[1]}', array['sikayet','oyuncu_ara','sustur'])`);
  await girisYap(botlar[1]);
  await page.evaluate(() => sekmeAc('ben')); await tikla('Moderatör paneli'); await bekle('Moderatörsün');
  await foto('78-moderator-paneli');
  await girisYap('Ercan');
  await page.evaluate(() => { D.yigin = []; sekmeAc('ben'); }); await tikla('Yönetici paneli'); await bekle('Moderatör ekibi');
  await page.locator('#ymod').scrollIntoViewIfNeeded(); await foto('79-moderator-ekibi');
  await page.locator('[data-mduz]').first().click(); await bekle('E-posta görme'); await foto('80-moderator-yetki');
  await page.locator('[data-myetki="duyuru"]').check(); await page.click('#mkaydet'); await toastBekle('Moderatör kaydedildi');
  assert1(psql(`select 'duyuru' = any(yetkiler) from oyun.moderatorler m join oyun.profiller p on p.id=m.user_id where p.kad='${botlar[1]}'`) === 't', 'yetki eklenmedi');
  await page.locator('#ykayit').scrollIntoViewIfNeeded(); await foto('81-moderasyon-gunlugu');
  ok('Moderatörler: yönetici bir oyuncuya yetki verdi; moderatör kısıtlı paneli gördü; yetki ekranından duyuru yetkisi eklendi');

  // XSS denemesi: kötü niyetli kullanıcı adı veritabanında reddedilmeli, parti adı da
  let xss = 'geçti';
  try { rpc(hesaplar['ercan@ornek.com'].uid, 'parti_kur', { p_ad: '<img src=x onerror=alert(1)>', p_kisa: 'XS', p_renk: '#ffffff', p_amblem: 'a_gul' }); xss = 'KABUL EDİLDİ'; } catch (e) { xss = 'reddedildi'; }
  console.log('   Zararlı parti adı:', xss);

  console.log(hatalar.length ? '\nSAYFA HATALARI:\n' + hatalar.join('\n') : '\nSayfa hatası yok.');
  await browser.close();
  if (hatalar.length || xss !== 'reddedildi') process.exit(1);
})().catch(err => { console.error('TEST HATASI:', err); process.exit(1); });
