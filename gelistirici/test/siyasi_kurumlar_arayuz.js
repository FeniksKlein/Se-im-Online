// Modül 97 arayüzü: davet, ulusal kriz masası, komisyonlar, kapatma davaları, kollar. Ağ yok; veriler gerçek RPC çıktısından (test/veri/siyasi_kurumlar_ornek.json).
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules HTML_PATH=docs/index.html node gelistirici/test/siyasi_kurumlar_arayuz.js [ekran_klasoru]
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
const html = fs.readFileSync(htmlYol, 'utf8')
  .replace(/<script src="https:[^"]+"><\/script>/g, '')
  .replace(/<script src="([\w.-]+\.js)(?:\?[^"]*)?"><\/script>/g, (t, ad) => {
    const f = path.join(path.dirname(htmlYol), ad);
    return fs.existsSync(f) ? '<script>' + fs.readFileSync(f, 'utf8') + '</script>' : t;
  });
const VERI = JSON.parse(fs.readFileSync(path.join(__dirname, 'veri/siyasi_kurumlar_ornek.json'), 'utf8'));
const shot = process.argv[2];

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {}) });
  try {
    for (const w of [320, 390]) {
      const page = await browser.newPage({ viewport: { width: w, height: 844 }, isMobile: true, locale: 'tr-TR' });
      const errors = []; page.on('pageerror', e => errors.push(e.message));
      await page.route('**/*', r => r.request().url() === 'http://oyun.test/' ? r.fulfill({ body: html, contentType: 'text/html; charset=utf-8' }) : r.abort());
      await page.goto('http://oyun.test/');
      await page.evaluate((V) => {
        window.calls = []; window.ROL = 'cb';
        window.PROFIL = { il_id: 31, kad: 'Reis', parti: { id: V.parti_id, ad: 'A Partisi', renk: '#335599' }, gb: true, cuzdan: { para: 25079 }, makamlar: [{ tur: 'cb' }] };
        API = { rpc: async (ad, args) => {
          calls.push({ ad, args });
          if (ad === 'durum') return { simdi: new Date().toISOString(), profil: PROFIL, takvim: [] };
          if (ad === 'ulusal_kriz') return ROL === 'cb' ? V.kriz_cb : ROL === 'yon' ? V.kriz_yon : V.kriz_vatandas;
          if (ad === 'komisyonlar') return V.komisyonlar;
          if (ad === 'komisyon_kanun') return V.komisyon_kanun;
          if (ad === 'kanun_detay') return V.kanun_detay;
          if (ad === 'parti_kapatma_davalari') return ROL === 'cb' ? V.davalar_hakim : V.davalar_gb;
          if (ad === 'parti_kollari') return V.kollar;
          if (ad === 'davet_bilgim') return V.davet;
          if (ad === 'harita') return [];
          if (ad === 'davet_kodu_gir') return { tamam: true, durum: 'bekliyor', davet_eden: 'Ahmet' };
          return null;
        } };
        D.durum = { profil: PROFIL, takvim: [] };
      }, VERI);
      const tasmaYok = async (ad) => { const t = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); assert.ok(t <= 1, `${ad} ${w}px yatay taşma ${t}px`); };
      const foto = async (ad) => { if (shot) await page.screenshot({ path: path.join(shot, `${ad}_${w}.png`), fullPage: true }); };
      const metin = () => page.locator('#icerik').textContent();

      // Ulusal kriz: CB karar verebilir
      await page.evaluate(() => ekranAc(ulusalKrizEkrani)); await page.waitForSelector('#icerik .sk-serit');
      let m = await metin();
      assert.match(m, /Büyük deprem/); assert.match(m, /İlk müdahale/); assert.match(m, /Bu kararı uygula/);
      assert.ok(!/"puan"/.test(m));
      await foto('kriz_cb'); await tasmaYok('kriz cb');
      // Vatandaş: puanlar, karar düğmesi görmez
      await page.evaluate(() => { ROL = 'vat'; ekranAc(ulusalKrizEkrani); }); await page.waitForSelector('#skPuanH');
      m = await metin(); assert.ok(!/Bu kararı uygula/.test(m)); assert.match(m, /Belediyesi nasıl yönetiyor/);
      await page.click('#skPuanH button:nth-child(4)'); await page.click('#skPuanB button:nth-child(2)');
      await page.evaluate(() => { calls = []; }); await page.click('text=Puanımı ver');
      await page.waitForTimeout(100);
      const pc = await page.evaluate(() => calls.find(c => c.ad === 'ulusal_kriz_puanla'));
      assert.ok(pc && pc.args.p_hukumet === 4 && pc.args.p_belediye === 2, 'puan çağrısı: ' + JSON.stringify(pc));
      await foto('kriz_vatandas'); await tasmaYok('kriz vatandaş');
      // Yönetici paneli
      await page.evaluate(() => { ROL = 'yon'; ekranAc(ulusalKrizEkrani); }); await page.waitForSelector('#skKrizTur');
      await foto('kriz_yonetici');

      // Gündem kartı
      await page.evaluate(() => { ROL = 'cb'; ekranAc(ulusalKrizEkrani); }); await page.waitForSelector('text=Bu kararı uygula');
      await page.evaluate(() => iskelet('Gündem', '<div class="kart">Gündem içerik</div>'));
      await page.waitForSelector('.sk-gundem-kriz'); assert.match(await metin(), /Karar ver/);

      // Meclis / Adliye / Devlet / Profil giriş noktaları
      await page.evaluate(() => iskelet('Meclis', '<div class="segment mc-seg"><button>Genel</button></div><div class="kart">x</div>'));
      assert.equal(await page.locator('#icerik > .segment + .sk-meclis').count(), 1, 'Meclis kartı segmentin altında olmalı');
      await page.evaluate(() => iskelet('Adliye', '<div class="kart">x</div>')); assert.equal(await page.locator('.sk-adliye').count(), 1);
      await page.evaluate(() => iskelet('Devlet', '<div class="kart">x</div>')); assert.equal(await page.locator('.sk-devlet').count(), 1);
      await page.evaluate(() => iskelet('Profilim', '<div class="kart">x</div>')); assert.equal(await page.locator('.sk-profil').count(), 1);

      // Komisyonlar
      await page.evaluate(() => ekranAc(komisyonlarEkrani)); await page.waitForSelector('text=İhtisas komisyonları');
      m = await metin(); assert.match(m, /Plan ve Bütçe Komisyonu/); assert.match(m, /Sağlık, Aile, Çalışma/);
      await foto('komisyonlar'); await tasmaYok('komisyonlar');
      // Kanun detayına komisyon kartı eklenir
      await page.evaluate((id) => ekranAc(() => kanunEkrani(id)), VERI.kanun_id); await page.waitForSelector('.sk-kom-kanun');
      m = await metin(); assert.match(m, /1 kabul · 1 ret/);
      await foto('kanun_komisyon'); await tasmaYok('kanun komisyon');

      // Kapatma davaları
      await page.evaluate(() => ekranAc(() => kapatmaDavalariEkrani(null))); await page.waitForSelector('text=Parti kapatma davaları');
      m = await metin(); assert.match(m, /İmza toplanıyor/); assert.match(m, /Parti kapatıldı/); assert.match(m, /Hazine yardımından yoksun/);
      await foto('kapatma'); await tasmaYok('kapatma');
      if (await page.locator('button.tehlike', { hasText: 'Kapatma davası' }).count()) {
        await page.locator('button.tehlike', { hasText: 'Kapatma davası' }).first().click();
        await page.waitForSelector('#skPkdIddia'); await page.evaluate(() => modalKapat());
      }
      if (await page.locator('text=Mahkeme oyumu ver').count()) { await page.click('text=Mahkeme oyumu ver'); await page.waitForSelector('#skPkdKarar'); await page.evaluate(() => modalKapat()); }

      // Kollar
      await page.evaluate((pid) => ekranAc(() => partiKollariEkrani(pid)), VERI.parti_id); await page.waitForSelector('text=Gençlik Kolları');
      m = await metin(); assert.match(m, /Kadın Kolları/); assert.match(m, /Kol başkanı/);
      await foto('kollar'); await tasmaYok('kollar');

      // Davet
      await page.evaluate(() => ekranAc(davetEkrani)); await page.waitForSelector('.sk-kod');
      assert.equal((await page.locator('.sk-kod').textContent()).trim(), VERI.davet.kod);
      await foto('davet'); await tasmaYok('davet');

      // Kayıt ekranında davet kodu alanı + bağlantıdan gelen kod
      await page.evaluate(() => { localStorage.setItem('skDavet', 'ABC234'); profilOlusturEkrani(); });
      await page.waitForSelector('#skKayitDavet');
      assert.equal(await page.inputValue('#skKayitDavet'), 'ABC234');
      await foto('kayit_davet');
      // Profil varken bekleyen kod bir kez uygulanır
      await page.evaluate(() => { calls = []; iskelet('Hayat', '<div class="kart">x</div>'); });
      await page.waitForTimeout(100);
      assert.equal(await page.evaluate(() => calls.filter(c => c.ad === 'davet_kodu_gir').length), 1);
      assert.equal(await page.evaluate(() => localStorage.getItem('skDavet')), null);

      assert.deepEqual(errors, [], 'sayfa hataları: ' + errors.join(' | '));
      await page.close();
      console.log(`  ✓ ${w}px: kriz (CB/vatandaş/yönetici), gündem kartı, giriş noktaları, komisyonlar, kanun komisyon kartı, kapatma davaları, kollar, davet, kayıt alanı`);
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
