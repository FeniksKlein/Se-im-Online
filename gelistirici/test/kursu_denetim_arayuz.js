// Kürsü denetimi arayüz testi (sahte RPC; 390 ve 320 px):
//  1) oyun yöneticisi (sikayet yetkisi) Kürsü'de başkasının paylaşımında "Paylaşımı kaldır" görür; gerekçeyle kaldırır; oyuncu görmez
//  2) Moderasyon Merkezi › Kürsü şikâyetleri: şikâyet listesi, kaldırılanlar ve geri yükleme
//  3) 5 dakikalık paylaşım aralığı reddi oyuncuya gösterilir, yazma penceresi açık kalır
// NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/kursu_denetim_arayuz.js [ekran-klasoru]   (önce node build/derle.js)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const htmlYol = process.env.HTML_PATH || path.join(__dirname, '../dist/index.html');
const html = fs.readFileSync(htmlYol, 'utf8').replace(/<script src="https:[^"]+"><\/script>/g, '');
const shot = process.argv[2];
const S = (dk) => new Date(Date.now() + dk * 60e3).toISOString();
const P1 = { id: 1, ad: 'Deneme Partisi', kisa: 'DP', renk: '#3f7be0' };
const g = (id, kad, metin, ek) => Object.assign({ id, kad, metin, zaman: S(-id % 50), unvan: null, parti: P1, il: 'Ankara', yanit_id: null, begeni: 3, begenmeme: 1, yanit: 0,
  begendim: false, begenmedim: false, benim: kad === 'Deniz', yp: 0, ypledim: false, alinti_sayi: 0, alinti: null, yanit_kad: null, takip_ediyorum: false }, ek || {});
const AKIS = { liste: [{ sira: S(-1), yp: null, g: g(901, 'Ekin', 'Kurallara aykırı kurgusal bir paylaşım; yönetim kaldıracak.') }, { sira: S(-2), yp: null, g: g(902, 'Mert', 'Bugün meydandaydık. #miting') }, { sira: S(-3), yp: null, g: g(904, 'Deniz', 'Benim gönderim.') }], imlec: null };

(async () => {
  const browser = await chromium.launch({ headless: true });
  const hatalar = []; let no = 0;
  for (const w of [390, 320]) {
    const page = await browser.newPage({ viewport: { width: w, height: w === 320 ? 640 : 844 }, isMobile: true, hasTouch: true, locale: 'tr-TR' });
    page.on('pageerror', e => hatalar.push(w + ': ' + e.message.slice(0, 300)));
    await page.setContent(html, { waitUntil: 'load' });
    await page.waitForFunction(() => typeof window.kursuEkrani === 'function' && typeof window.mmKursu === 'function' && typeof iskelet === 'function');
    await page.evaluate((F) => {
      window.calls = []; window.HIZ = false;
      window.SK = [{ id: 901, kad: 'Ekin', metin: 'Kurallara aykırı kurgusal bir paylaşım; yönetim kaldıracak.', gizli: false, sayi: 3, nedenler: ['hakaret'], ilk: new Date(Date.now() - 36e5).toISOString(), kilit: false, devir: false }];
      window.KL = [{ id: 880, kad: 'Selin', metin: 'Daha önce kaldırılmış kurgusal paylaşım.', zaman: new Date(Date.now() - 72e5).toISOString(), sikayet: 2 }];
      const k = (v) => JSON.parse(JSON.stringify(v));
      API = { rpc: async (ad, args) => {
        calls.push({ ad, args });
        if (ad === 'kursu_akis') return k(F.AKIS);
        if (ad === 'kursu_ben') return { kad: 'Deniz', takip: 2, takipci: 1, yeni: 0, benim: true };
        if (ad === 'kursu_gundem') return { saat: 48, etiketler: [], kisiler: [], partiler: [], dernekler: [], oneriler: [] };
        if (ad === 'akis_yaz') { if (window.HIZ) throw new Error("Kürsü'de 5 dakikada bir paylaşım yapabilirsin. 3 dk 12 sn sonra yeniden dene (yanıt yazmak serbest)."); return { tamam: true, id: 999 }; }
        if (ad === 'mod_kursu_kaldir') { if (String(args.p_gerekce || '').trim().length < 5) throw new Error('Kaldırma gerekçesini yaz (5-300 karakter; paylaşımın sahibi görür).'); SK = SK.filter(x => x.id !== args.p_id); KL.unshift({ id: args.p_id, kad: 'Ekin', metin: 'Kurallara aykırı kurgusal bir paylaşım; yönetim kaldıracak.', zaman: new Date().toISOString(), sikayet: 3 }); return { tamam: true, id: args.p_id }; }
        if (ad === 'admin_akis_sikayetleri') return k(SK);
        if (ad === 'mod_kursu_kaldirilanlar') return k(KL);
        if (ad === 'admin_akis_karar') { if (args.p_islem === 'yok_say') KL = KL.filter(x => x.id !== args.p_id); SK = SK.filter(x => x.id !== args.p_id); return k(SK); }
        if (ad === 'vergi_rehberi') return { tanitim: true };
        if (ad === 'kimlikler') return {};
        if (ad === 'durum') return { simdi: new Date().toISOString(), profil: D.durum.profil };
        return null;
      } };
      D.durum = { profil: { kad: 'Deniz', il_id: 34, il_ad: 'İstanbul', parti: { id: 1, ad: 'Deneme Partisi', kisa: 'DP', renk: '#3f7be0' }, makamlar: [], cuzdan: { para: 250000 }, yetkiler: { yonetici: false, moderator: false, liste: [] } } };
      setInterval(() => { if (window.SO_KESINTISIZ) SO_KESINTISIZ.eylem = Date.now(); }, 50);
    }, { AKIS });
    const et = (m) => w + 'px · ' + m;
    const son = (ad) => page.evaluate((a) => calls.filter(c => c.ad === a).pop(), ad);
    const say = (ad) => page.evaluate((a) => calls.filter(c => c.ad === a).length, ad);
    const cek = async (ad) => { if (shot) { fs.mkdirSync(shot, { recursive: true }); await page.screenshot({ path: path.join(shot, String(++no).padStart(2, '0') + '_' + ad + '_' + w + '.png') }); } };
    const tasma = () => page.evaluate(() => ({ sayfa: document.documentElement.scrollWidth - window.innerWidth,
      tasan: [...document.querySelectorAll('#modal *, #icerik .mm-kart *')].filter(x => { const r = x.getBoundingClientRect(); return r.width > 0 && r.right > window.innerWidth + 1; }).length }));
    const toastlar = () => page.evaluate(() => [...document.querySelectorAll('.toast')].map(x => x.textContent).join(' | '));
    const menuAc = async (id) => { await page.evaluate(() => { try { modalKapat(); } catch (_) {} document.querySelectorAll('.toast').forEach(x => x.remove()); });
      await page.click('.kr-g[data-id="' + id + '"] [data-kr="menu"], .kr-g[data-id="' + id + '"] [data-menu]'); await page.waitForTimeout(250); };

    // ---- 1a) Sıradan oyuncu: "Paylaşımı kaldır" yok
    await page.evaluate(() => { D.sekme = 'gundem'; D.yigin = []; ekranAc(() => kursuEkrani('ana')); });
    await page.waitForSelector('.kr-g[data-id="901"]');
    await menuAc(901);
    assert.equal(await page.evaluate(() => !!document.querySelector('#modal [data-sf="modkaldir"]')), false, et('oyuncuda yönetim düğmesi olmamalı'));
    assert.equal(await page.evaluate(() => !!document.querySelector('#modal [data-sf="sikayet"]')), true, et('oyuncu şikâyet edebilmeli'));

    // ---- 3) Paylaşım aralığı reddi: bildirim görünür, yazı kaybolmaz
    await page.evaluate(() => { modalKapat(); window.HIZ = true; kursuYaz('Beş dakika dolmadan ikinci paylaşım'); }); await page.waitForTimeout(300);
    await page.click('#krYaz .kr-yaz-gonder, #krYazGonder'); await page.waitForTimeout(400);
    assert.match(await toastlar(), /5 dakikada bir paylaşım yapabilirsin/, et('aralık reddi bildirilmeli'));
    const yz = await page.evaluate(() => { const y = document.getElementById('krYaz'); const t = y && y.querySelector('textarea'); return { acik: !!y, metin: t ? t.value : null }; });
    assert.ok(yz.acik && yz.metin === 'Beş dakika dolmadan ikinci paylaşım', et('ret sonrası yazı korunmalı: ' + JSON.stringify(yz)));
    await cek('aralik');
    await page.evaluate(() => { window.HIZ = false; const y = document.getElementById('krYaz'); if (y) y.remove(); document.querySelectorAll('.toast').forEach(x => x.remove()); });

    // ---- 1b) Oyun yöneticisi (sikayet yetkisi): kaldırma akışı
    await page.evaluate(() => { D.durum.profil.yetkiler = { yonetici: false, moderator: true, liste: ['sikayet', 'sustur'] }; });
    await menuAc(904);
    assert.equal(await page.evaluate(() => !!document.querySelector('#modal [data-sf="modkaldir"]')), false, et('kendi gönderisinde yönetim düğmesi yok (normal sil var)'));
    await menuAc(901);
    const md = await page.evaluate(() => { const b = document.querySelector('#modal [data-sf="modkaldir"]'); return b ? { metin: b.innerText.replace(/\s+/g, ' '), yuk: Math.round(b.getBoundingClientRect().height) } : null; });
    assert.ok(md && /Paylaşımı kaldır/.test(md.metin) && md.yuk >= 44, et('yönetim düğmesi: ' + JSON.stringify(md)));
    await cek('menu');
    await page.click('#modal [data-sf="modkaldir"]'); await page.waitForTimeout(300);
    const fm = await page.evaluate(() => { const t = document.getElementById('krMkGer'); return t ? { yazi: parseFloat(getComputedStyle(t).fontSize), gen: Math.round(t.getBoundingClientRect().width), cip: document.querySelectorAll('#modal [data-mk-hazir]').length,
      cipYuk: Math.min(...[...document.querySelectorAll('#modal [data-mk-hazir]')].map(b => b.getBoundingClientRect().height)), metin: document.querySelector('#modal').innerText } : null; });
    assert.ok(fm && fm.yazi >= 16 && fm.cip === 5 && fm.cipYuk >= 40 && fm.gen > w * 0.7, et('gerekçe penceresi: ' + JSON.stringify(fm)));
    assert.match(fm.metin, /Ekin: Kurallara aykırı/, et('kaldırılacak paylaşım özeti'));
    let t = await tasma(); assert.ok(t.sayfa <= 1 && t.tasan === 0, et('gerekçe penceresi taşıyor: ' + JSON.stringify(t)));
    await cek('gerekce');
    await page.click('#modal [data-sf="kaldir"]'); await page.waitForTimeout(250);
    assert.equal(await say('mod_kursu_kaldir'), 0, et('gerekçesiz kaldırma sunucuya gitmemeli'));
    assert.match(await toastlar(), /Gerekçe yaz/, et('gerekçe uyarısı'));
    await page.evaluate(() => document.querySelectorAll('.toast').forEach(x => x.remove()));
    await page.click('#modal [data-mk-hazir]:nth-of-type(1)'); await page.waitForTimeout(100);
    assert.equal(await page.evaluate(() => document.getElementById('krMkGer').value), 'Hakaret ya da küfür içerdiği için kaldırıldı.', et('hazır gerekçe'));
    await page.click('#modal [data-sf="kaldir"]'); await page.waitForTimeout(450);
    assert.deepEqual((await son('mod_kursu_kaldir')).args, { p_id: 901, p_gerekce: 'Hakaret ya da küfür içerdiği için kaldırıldı.' });
    assert.equal(await page.locator('.kr-g[data-id="901"]').count(), 0, et('kaldırılan paylaşım akıştan çıkar'));
    assert.equal(await page.locator('.kr-g[data-id="902"]').count(), 1, et('diğer paylaşımlar durur'));
    assert.match(await toastlar(), /Paylaşım kaldırıldı/, et('kaldırıldı bildirimi'));

    // ---- 2) Moderasyon Merkezi › Kürsü şikâyetleri
    await page.evaluate(() => { document.querySelectorAll('.toast').forEach(x => x.remove()); window.SK = [{ id: 902, kad: 'Mert', metin: 'Bugün meydandaydık. #miting', gizli: false, sayi: 1, nedenler: ['spam'], ilk: new Date(Date.now() - 6e5).toISOString(), kilit: false, devir: false }]; D.yigin = []; return ekranAc(mmKursu); });
    await page.waitForTimeout(600);
    const mm = await page.evaluate(() => ({ metin: document.getElementById('icerik').innerText, sikayet: document.querySelectorAll('.mm-kart[data-i]').length, kaldirilan: document.querySelectorAll('.mm-kart[data-kl]').length,
      dugme: Math.min(...[...document.querySelectorAll('.mm-aksiyon button')].map(b => b.getBoundingClientRect().height)) }));
    assert.equal(mm.sikayet, 1, et('açık şikâyet kartı')); assert.equal(mm.kaldirilan, 2, et('kaldırılanlar (az önce kaldırılan + eski)'));
    for (const b of ['1 şikâyet', 'Sorun yok', 'Gizle', 'Kaldırılan paylaşımlar', 'Geri yükle', 'Paylaşımı kaldır']) assert.ok(mm.metin.includes(b), et('ekranda "' + b + '" yok'));
    assert.ok(!/yetkin yok/i.test(mm.metin), et('yetki hatası görünmemeli'));
    t = await tasma(); assert.ok(t.sayfa <= 1 && t.tasan === 0, et('şikâyet ekranı taşıyor: ' + JSON.stringify(t)));
    await cek('sikayetler');
    await page.click('.mm-kart[data-kl] [data-geri="901"]'); await page.waitForTimeout(500);
    assert.deepEqual((await son('admin_akis_karar')).args, { p_id: 901, p_islem: 'yok_say' }, et('geri yükleme'));
    assert.equal(await page.locator('.mm-kart[data-kl]').count(), 1, et('geri yüklenen listeden çıkar'));
    await page.click('.mm-kart[data-i] [data-k="gizle"]'); await page.waitForTimeout(500);
    assert.deepEqual((await son('admin_akis_karar')).args, { p_id: 902, p_islem: 'gizle' }, et('şikâyetten gizleme'));
    await page.close();
  }
  await browser.close();
  assert.deepEqual(hatalar, [], 'sayfa hataları: ' + hatalar.join(' | '));
  console.log('Kürsü denetimi arayüz testleri başarılı (390 ve 320 px).');
})().catch(e => { console.error(e); process.exit(1); });
