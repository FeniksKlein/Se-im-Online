// Oyuncuya özel mesaj / yazılı uyarı penceresi arayüz testi (sahte RPC; 390 ve 320 px). Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/mod_oyuncuya_yaz_arayuz.js [ekran-klasörü]
const fs = require('fs'), path = require('path'); const { chromium } = require('playwright');
const klasor = process.argv[2] || '/tmp/oy_ekran'; fs.mkdirSync(klasor, { recursive: true });
const html0 = fs.readFileSync(path.join(__dirname, '../dist/index.html'), 'utf8');
const simdi = new Date().toISOString();
const R = { durum: { simdi, profil: { kad: 'CELAL', yonetici: false, il_id: 34, yetkiler: { yonetici: false, moderator: true, liste: ['kayit'] }, cuzdan: { para: 1 } }, okunmamis: { bildirim: 0, ozel: 0 } },
  mod_merkez: { zaman: simdi, ben: { kad: 'CELAL', yonetici: false, yetkiler: ['kayit', 'hesap_kapat', 'oyuncu_ara', 'ekonomi'], rutbe: 'moderator', sozlesme_at: simdi, kod: 'G-02' }, birimler: [], kuyruk: {}, istatistik: {}, son_islemlerim: [{ islem: 'mod_yazili_uyari', hedef: 'gürültücü', zaman: simdi }] },
  mod_oyuncuya_yaz: { tamam: true, id: 41, yeni: true } };
const KOPRU = `<script>window.__R=${JSON.stringify(R)};window.__son=[];window.API_TEST={async rpc(fn,a){window.__son.push([fn,a]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return null},async kayit(){},async giris(){},async cikis(){}};</script>`;
const html = html0.replace(/<script src="https:[^"]+"><\/script>/g, '').replace('<body>', '<body>' + KOPRU).replace('API = window.API_TEST || gercekApi();', 'API = window.API_TEST;');
let basarisiz = 0; const kontrol = (ad, k, ek) => { if (k) console.log('  ✓', ad); else { basarisiz++; console.log('  ✗', ad, ek === undefined ? '' : JSON.stringify(ek)); } };
(async () => {
  const b = await chromium.launch();
  for (const gen of [390, 320]) {
    console.log(`— ${gen} px —`);
    const p = await b.newPage({ viewport: { width: gen, height: 844 }, deviceScaleFactor: 2 });
    const hatalar = []; p.on('pageerror', e => hatalar.push(e.message));
    await p.setContent(html, { waitUntil: 'load' }); await p.waitForTimeout(800);
    await p.evaluate(() => { API = window.API_TEST; D.durum = __R.durum; });
    await p.evaluate(() => yoneticiEkrani()); await p.waitForTimeout(700);
    kontrol('işlem adı Türkçe', await p.evaluate(() => document.getElementById('icerik').textContent.includes('oyuncuya yazılı uyarı gönderdi')));
    await p.evaluate(() => mmOyuncuyaYaz('UzunKullaniciAdi_1234')); await p.waitForTimeout(500);
    const tasma = () => p.evaluate(() => { const w = document.documentElement.clientWidth; return [...document.querySelectorAll('#modal *,.modal *')].filter(x => x.getBoundingClientRect().right > w + 1).length; });
    kontrol('pencere taşmıyor', (await tasma()) === 0);
    kontrol('giriş alanı 16 px', await p.evaluate(() => parseFloat(getComputedStyle(document.getElementById('mmOYM')).fontSize) >= 16));
    kontrol('varsayılan tür mesaj', await p.evaluate(() => document.getElementById('mmOYOk').textContent === 'Mesajı gönder'));
    await p.evaluate(() => document.getElementById('mmOYOk').click()); await p.waitForTimeout(200);
    kontrol('boş mesaj gönderilmez', await p.evaluate(() => window.__son.filter(x => x[0] === 'mod_oyuncuya_yaz').length === 0));
    await p.evaluate(() => document.querySelector('#mmOYH [data-v="0"]').click()); await p.waitForTimeout(200);
    kontrol('hazır üslup metni yazılı uyarıya geçirir', await p.evaluate(() => document.getElementById('mmOYM').value.includes('üslubuna') && document.getElementById('mmOYOk').textContent === 'Uyarıyı gönder'));
    await p.screenshot({ path: `${klasor}/${gen}_yaz.png` });
    await p.evaluate(() => document.getElementById('mmOYOk').click()); await p.waitForTimeout(400);
    const c = await p.evaluate(() => window.__son.filter(x => x[0] === 'mod_oyuncuya_yaz').map(x => x[1]));
    kontrol('uyarı sunucuya gider', c.length === 1 && c[0].p_kad === 'UzunKullaniciAdi_1234' && c[0].p_uyari === true && c[0].p_metin.length >= 10, c);
    await p.evaluate(() => { window.__son = []; mmOyuncuyaYaz('ahmet'); }); await p.waitForTimeout(400);
    await p.evaluate(() => { document.getElementById('mmOYM').value = 'Merhaba, hesabınla ilgili kısa bir sorumuz var.'; document.getElementById('mmOYOk').click(); }); await p.waitForTimeout(400);
    const c2 = await p.evaluate(() => window.__son.filter(x => x[0] === 'mod_oyuncuya_yaz').map(x => x[1]));
    kontrol('mesaj sunucuya gider', c2.length === 1 && c2[0].p_uyari === false, c2);
    kontrol('sayfa hatası yok', hatalar.length === 0, hatalar.slice(0, 3));
    await p.close();
  }
  await b.close(); console.log(basarisiz ? `BAŞARISIZ: ${basarisiz}` : 'Oyuncuya yaz arayüz testi OK'); process.exit(basarisiz ? 1 : 0);
})();
