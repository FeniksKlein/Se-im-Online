// 21.11.2026 · Sohbet bölümünde "Mod" sekmesi (sahte RPC, 390 px ve 320 px).
// Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/mod_sohbet_sekme_arayuz.js [ekran-klasörü]
const fs = require('fs'), path = require('path'); const { chromium } = require('playwright');
const klasor = process.argv[2] || '/tmp/mod_sekme_ekran'; fs.mkdirSync(klasor, { recursive: true });
const html0 = fs.readFileSync(path.join(__dirname, '../dist/index.html'), 'utf8');
const simdi = new Date().toISOString(), dk = (n) => new Date(Date.now() - n * 60000).toISOString();
const R = (gorevli, nobet) => ({
  durum: { simdi, profil: { id: 'u-1', kad: 'Eyetkin', yonetici: false, il_id: 34, il_ad: 'İstanbul', parti: null, makamlar: [], yetkiler: { yonetici: false, moderator: gorevli, liste: [] }, cuzdan: { para: 1e6 } }, okunmamis: { bildirim: 0, ozel: 0 } },
  ozel_liste: [], sohbet_grup_kesfet: null, rozetler: {}, mesaj_tepkileri: {},
  sohbet_ozet: { cevrimici: 12, toplam_okunmamis: 0, grup_sinir: { kurucu_aktif: 3, uye: 50 },
    kanallar: [{ kanal: 'genel', baslik: 'Türkiye Meydanı', kilit: null, yazabilir: true, okunmamis: 0, son: null, cevrimici: 12, sinyal: 'sohbet:genel' }],
    yardim: { kanal: 'yardim', baslik: 'Yardım Masası', kilit: null, yazabilir: true, okunmamis: 0, sinyal: 'sohbet:yardim', gorevli, bekleyen: 0, son: null } },
  mod_sohbet_sekme: { nobet, tum: nobet },
  mod_merkez: { zaman: simdi, ben: { kad: 'Eyetkin', yonetici: false, yetkiler: ['sikayet', 'sohbet_tum'], rutbe: 'moderator', kod: 'G-07', birim: 'icerik', birim_ad: 'İçerik Masası', sozlesme_at: simdi }, birimler: [], kuyruk: {}, istatistik: {} },
  mod_sohbet_nobeti: { zaman: simdi, tum_yetki: true, resmi_yetki: false,
    kanallar: [{ kanal: 'genel', ad: 'Genel', sayi: 40, grup: false }, { kanal: 'parti:1', ad: 'CYP parti sohbeti', sayi: 9, grup: true }],
    mesajlar: [{ id: 31, kanal: 'parti:1', kanal_ad: 'CYP parti sohbeti', kad: 'sertOyuncu', gorevli: false, metin: 'Deneme mesajı', zaman: dk(3), gizli: false, isaret: [], grup: true, susturulmus: false, moderator: false, sikayet: 0 }] },
  yayin_haklari: [], bakan_tekliflerim: [], cb_yardimcisi_tekliflerim: [], resmi_kabul_davetlerim: { gelen: [], giden: [] }, bildirim_hedefleri: {}
});
const sayfa = (r) => html0.replace(/<script src="https:[^"]+"><\/script>/g, '').replace('<body>', '<body>' + `<script>window.__R=${JSON.stringify(r)};window.API_TEST={async rpc(fn,a){window.__son=(window.__son||[]);window.__son.push([fn,a]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return null},async kayit(){},async giris(){},async cikis(){}};</script>`).replace('API = window.API_TEST || gercekApi();', 'API = window.API_TEST;');
(async () => {
  for (const isaret of ["API.rpc('mod_sohbet_sekme'", 'data-sh="modNobet"', '.sh-seg.uc']) if (!html0.includes(isaret)) throw new Error('Derlemede yok: ' + isaret);
  const b = await chromium.launch(process.env.CHROME_PATH ? { executablePath: process.env.CHROME_PATH } : {});
  const DURUM = { nobetci_mod: [true, true], nobetsiz_mod: [true, false], oyuncu: [false, false] };
  for (const [ad, [gorevli, nobet]] of Object.entries(DURUM)) for (const w of [390, 320]) {
    const p = await b.newPage({ viewport: { width: w, height: 844 }, deviceScaleFactor: 2 });
    const hatalar = []; p.on('pageerror', e => hatalar.push(e.message));
    await p.route('**/*', r => r.abort());
    await p.setContent(sayfa(R(gorevli, nobet)), { waitUntil: 'load' }); await p.waitForTimeout(800);
    await p.evaluate(() => { API = window.API_TEST; D.durum = __R.durum; });
    await p.evaluate(() => ekranAc(sohbetListe)); await p.waitForTimeout(900);
    const s = await p.evaluate(() => { const seg = document.querySelector('.sh-seg'), g = document.documentElement.clientWidth; return {
      dugme: seg.querySelectorAll('button').length, mod: !!seg.querySelector('[data-sh="modNobet"]'), uc: seg.classList.contains('uc'),
      cagri: (window.__son || []).filter(x => x[0] === 'mod_sohbet_sekme').length,
      tasma: [...seg.querySelectorAll('*')].filter(x => x.getBoundingClientRect().right > g + 1).length,
      alcak: [...seg.querySelectorAll('button')].filter(x => x.getBoundingClientRect().height < 36).length,
      kay: seg.querySelector('.sh-seg-kay').getBoundingClientRect().width, ilk: seg.querySelector('button').getBoundingClientRect().width }; });
    await p.screenshot({ path: `${klasor}/${w}_${ad}.png` });
    console.log(w, ad, JSON.stringify(s), hatalar.length ? 'HATA ' + JSON.stringify(hatalar) : '');
    if (hatalar.length || s.tasma || s.alcak) throw new Error(ad + ': sayfa hatası / taşma');
    if (nobet) {
      if (!s.mod || !s.uc || s.dugme !== 3 || s.cagri !== 1 || Math.abs(s.kay - s.ilk) > 2) throw new Error(ad + ': Mod sekmesi bekleniyordu');
      await p.evaluate(() => document.querySelector('[data-sh="seg"][data-v="kanal"]').click()); await p.waitForTimeout(400);
      if (!(await p.evaluate(() => !!document.querySelector('.sh-seg [data-sh="modNobet"]')))) throw new Error(ad + ': sekme değişince Mod kayboldu');
      await p.evaluate(() => document.querySelector('[data-sh="modNobet"]').click()); await p.waitForTimeout(900);
      const n = await p.evaluate(() => ({ cagri: (window.__son || []).filter(x => x[0] === 'mod_sohbet_nobeti').length, metin: document.getElementById('app').innerText }));
      await p.screenshot({ path: `${klasor}/${w}_${ad}_nobet.png` });
      if (!n.cagri || !/Sohbet nöbeti/.test(n.metin) || !/Deneme mesajı/.test(n.metin)) throw new Error(ad + ': nöbet ekranı açılmadı');
    } else {
      if (s.mod || s.uc || s.dugme !== 2) throw new Error(ad + ': Mod sekmesi görünmemeliydi');
      if (!gorevli && s.cagri !== 0) throw new Error(ad + ': sıradan oyuncu yetki sorgusu yapmamalı');
    }
    await p.close();
  }
  await b.close(); console.log('Mod sekmesi arayüzü OK');
})().catch(e => { console.error(e); process.exit(1); });
