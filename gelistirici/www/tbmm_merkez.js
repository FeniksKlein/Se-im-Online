/* =====================================================================
   TBMM ÇALIŞMALARI MERKEZİ (27.11.2026 · sql/zz_20261127_tbmm_denetim_vekil.sql)
   Meclis sekmesinin başında canlı Genel Kurul kartı ve "Çalışmalar" bölümü:
   • 19 ihtisas komisyonu: üyelik, başkan seçimi, komisyon gündemi ve oyu, rapor, canlı komisyon salonu.
   • Denetim yolları (Anayasa m.98): yazılı soru önergesi (15 gün), genel görüşme, Meclis araştırması;
     gensoru yalnız parlamenter sistemde (2017'de kaldırıldı).
   • Dilekçe (Anayasa m.74): vatandaş TBMM'ye yazar, Dilekçe Komisyonu cevaplar ya da bakanlığa gönderir.
   • Halk buluşması: milletvekili seçim bölgesinde canlı buluşma düzenler, vatandaş soru sorar,
     vekil yanıtlar ya da soruyu yazılı soru önergesine çevirir; katılanlar puan verir.
   • Vekil karnesi ve Meclis sıralaması.
   Bütün kurallar sunucuda. Ortak stil ve form yardımcıları tbmm_salon.js'den (SO_GK).
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_TBMM_MERKEZ) return;
  window.SO_TBMM_MERKEZ = true;

  var $1 = function (s, k) { return (k || document).querySelector(s); };
  var $$ = function (s, k) { return Array.prototype.slice.call((k || document).querySelectorAll(s)); };
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var rpc = function (ad, a) { return API.rpc(ad, a || {}); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var bildir = function (m, kotu) { try { toast(m, kotu); } catch (_) {} };
  var kelime = function (m) { m = String(m || '').trim(); return m ? m.split(/\s+/).length : 0; };
  var TZ = { timeZone: 'Europe/Istanbul' };
  var saat = function (t) { try { return new Date(t).toLocaleTimeString('tr-TR', Object.assign({ hour: '2-digit', minute: '2-digit' }, TZ)).replace(':', '.'); } catch (_) { return ''; } };
  var gun = function (t) { try { return new Date(t).toLocaleDateString('tr-TR', Object.assign({ day: 'numeric', month: 'long' }, TZ)); } catch (_) { return ''; } };
  var gunSaat = function (t) { return t ? gun(t) + ' ' + saat(t) : ''; };
  var GK = function () { return window.SO_GK || {}; };
  var portreH = function (kad, renk, boy) { return typeof portre === 'function' ? portre(kad, renk, boy || 36) : ''; };
  var ozetC = { t: 0, v: null };

  function css() {
    if (GK().css) GK().css();
    if ($1('#tmCss')) return;
    var s = document.createElement('style'); s.id = 'tmCss';
    s.textContent = [
      '.tm{color-scheme:dark}.tm-bant{border-radius:16px;padding:14px;margin-bottom:12px;background:radial-gradient(130% 120% at 100% 0,#3a2a12 0,#1b2346 55%,#141b38 100%);border:1px solid rgba(217,178,91,.45)}',
      '.tm-bant .tm-ust{display:flex;align-items:center;gap:8px;flex-wrap:wrap;background:none;padding:0;border:0;box-shadow:none}.tm-bant b.bas{font-family:var(--disp);font-size:17px;color:#f4e6c0;letter-spacing:.02em}.tm-bant p{font-size:14px;color:var(--txt2);line-height:1.45;margin-top:6px}',
      '.tm-bant .egemen{display:block;font-family:var(--disp);font-size:11px;letter-spacing:.16em;color:#d9b25b;margin-top:8px;text-align:center;opacity:.9}',
      '.tm-izgara{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:12px}.tm-kut{position:relative;display:flex;flex-direction:column;gap:4px;text-align:left;padding:12px;border-radius:14px;background:var(--panel);border:1px solid var(--line);min-height:96px;color:var(--txt)}',
      '.tm-kut svg{width:24px;height:24px;color:#d9b25b}.tm-kut b{font-size:15px;line-height:1.25}.tm-kut span{font-size:12.5px;color:var(--mut);line-height:1.35}.tm-kut i.rz{position:absolute;top:10px;right:10px;font-style:normal;min-width:22px;height:22px;padding:0 6px;border-radius:99px;background:#e5484d;color:#fff;font-size:12px;font-weight:800;display:flex;align-items:center;justify-content:center}',
      '.tm-kut.genis{grid-column:1/-1;min-height:0;flex-direction:row;align-items:center;gap:12px}.tm-kut.genis .o{flex:1;min-width:0}.tm-kut .o b,.tm-kut .o span{display:block}.tm-kut .o span{margin-top:3px}',
      '.tm-seg{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin-bottom:10px}.tm-seg::-webkit-scrollbar{display:none}.tm-seg button{flex:0 0 auto;min-height:38px;padding:7px 13px;border-radius:999px;background:var(--panel2);color:var(--txt);font-size:13.5px;font-weight:700;white-space:nowrap}.tm-seg button.aktif{background:#d9b25b;color:#1a1405}',
      '.tm-oge{background:var(--panel);border-radius:14px;padding:12px 13px;margin-bottom:9px;border:1px solid var(--line)}.tm-oge .bs{display:flex;align-items:flex-start;gap:8px}.tm-oge .bs .o{flex:1;min-width:0}',
      '.tm-oge b.t{display:block;font-size:15px;line-height:1.3;overflow-wrap:anywhere}.tm-oge small{display:block;font-size:12.5px;color:var(--mut);margin-top:3px;line-height:1.35}.tm-oge p{font-size:14.5px;line-height:1.5;color:var(--txt2);margin-top:8px;white-space:pre-wrap;overflow-wrap:anywhere}',
      '.tm-rz{display:inline-flex;align-items:center;padding:3px 8px;border-radius:99px;font-size:11.5px;font-weight:800;letter-spacing:.03em;background:#283563;color:#fff;white-space:nowrap}.tm-rz.iyi{background:#1f6f47}.tm-rz.kotu{background:#8a1f1a}.tm-rz.sari{background:#7a5a10}.tm-rz.altin{background:#d9b25b;color:#1a1405}',
      '.tm-cevap{margin-top:9px;padding:10px 12px;border-radius:12px;background:#17203f;border-left:3px solid #2fbf71}.tm-cevap b{font-size:13px;color:#9be7bf}.tm-cevap p{margin-top:4px}',
      '.tm-uye{display:flex;align-items:center;gap:9px;padding:8px 0;border-top:1px solid var(--line)}.tm-uye:first-child{border-top:0}.tm-uye .pp{flex:0 0 36px;width:36px;height:36px;border-radius:50%;overflow:hidden}.tm-uye .o{flex:1;min-width:0}',
      '.tm-uye .o b{display:block;font-size:14.5px;overflow-wrap:anywhere}.tm-uye .o small{display:block;font-size:12.5px;color:var(--mut)}',
      '.tm-tablo{width:100%;border-collapse:collapse;font-size:13.5px}.tm-tablo th,.tm-tablo td{padding:7px 4px;border-top:1px solid var(--line);text-align:left}.tm-tablo th{font-size:12px;color:var(--mut);font-weight:700}.tm-tablo td.s{text-align:right;font-variant-numeric:tabular-nums}',
      '.tm-yildiz{display:flex;gap:6px;margin-top:8px}.tm-yildiz button{flex:1;min-height:46px;border-radius:12px;background:#232b4a;color:#f2b33d;font-size:22px}.tm-yildiz button.secili{background:#f2b33d;color:#1a1405}',
      '.tm-karne{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:10px}.tm-karne div{background:#1a2140;border-radius:10px;padding:8px 4px;text-align:center}.tm-karne b{display:block;font-size:18px}.tm-karne span{font-size:11.5px;color:var(--mut)}',
      '.tm-puan{display:flex;align-items:center;gap:12px}.tm-puan .halka{flex:0 0 auto;width:74px;height:74px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:24px;font-weight:900;background:conic-gradient(#d9b25b var(--y),#262f52 0)}',
      '.tm-puan .halka span{width:60px;height:60px;border-radius:50%;background:var(--panel);display:flex;align-items:center;justify-content:center}',
      '.tm-kom-akis{background:#f7f3e8;color:#1d1a14;border-radius:14px;padding:12px;max-height:46vh;min-height:140px;overflow:auto;font-family:Georgia,"Times New Roman",serif;font-size:15px;line-height:1.55;color-scheme:light}',
      '.tm-kom-akis .gk-t{margin-bottom:8px}','.tm-kom-akis p,.tm-kom-akis .gk-t{color:#1d1a14}.tm-kom-akis .gk-t.sis{color:#5c5546}','.tm-tablo th.s{text-align:right}'
    ].join('');
    document.head.appendChild(s);
  }
  var IK = {
    kom: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7" r="3"/><circle cx="17" cy="8" r="2.5"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M15 14.5c2.8 0 5 2.2 5 5"/></svg>',
    soru: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6M9.5 13a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .8-1 1.4M12 19.5h.01"/></svg>',
    gg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/><path d="M8 9h8M8 13h5"/></svg>',
    ar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4M8 11h6M11 8v6"/></svg>',
    dil: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16v12H5.2L4 17.2z"/><path d="M8 8h8M8 12h5"/></svg>',
    hb: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11v2a1 1 0 0 0 1 1h2l5 4V6L6 10H4a1 1 0 0 0-1 1zM15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/></svg>',
    karne: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/></svg>',
    arsiv: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 8v13H3V8M1 3h22v5H1zM10 12h4"/></svg>',
    salon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18M5 21V11M19 21V11M9.5 21V11M14.5 21V11M2 11l10-7 10 7z"/></svg>',
    gen: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/></svg>'
  };
  var DURUM = { imza: ['İmzaya açık', 'sari'], bekliyor: ['Gündemde bekliyor', 'sari'], acildi: ['Genel görüşme açıldı', 'iyi'], ret: ['Reddedildi', 'kotu'], reddedildi: ['Reddedildi', 'kotu'], dustu: ['Düştü', 'kotu'], geri: ['Geri çekildi', ''],
    tamamlandi: ['Tamamlandı', 'iyi'], oylamada: ['Öngörüşme oylamasında', 'sari'], kurulus: ['Komisyon kuruluyor', 'sari'], calisma: ['Komisyon çalışıyor', 'altin'], rapor_oylama: ['Rapor oylamasında', 'sari'],
    komisyonda: ['Dilekçe Komisyonunda', 'sari'], bakanlikta: ['Bakanlıkta', 'sari'], cevaplandi: ['Cevaplandı', 'iyi'], cevapsiz: ['Süresinde cevaplanmadı', 'kotu'] };
  function rozet(d) { var x = DURUM[d] || [d, '']; return '<span class="tm-rz ' + x[1] + '">' + esc(x[0]) + '</span>'; }
  function form(baslik, aciklama, govde, onay, fn) { return GK().form ? GK().form(baslik, aciklama, govde, onay, fn) : null; }
  async function cagir(ad, arg, basari) { try { var r = await rpc(ad, arg); if (basari) bildir(basari); return r; } catch (err) { bildir(hata(err), true); err._gosterildi = true; throw err; } }
  function geriSayac() {
    if (window._tmTik) return;
    window._tmTik = setInterval(function () {
      var els = $$('#icerik .tm [data-geri]'); if (!$1('#icerik .tm')) { clearInterval(window._tmTik); window._tmTik = null; return; }
      els.forEach(function (el) { var k = Math.max(0, (+el.getAttribute('data-geri') - Date.now()) / 1000); el.textContent = GK().mmss ? GK().mmss(k) : Math.round(k) + ' sn'; });
    }, 1000);
  }
  function sayfa(baslik, html, opt) { css(); iskelet(baslik, '<div class="tm">' + html + '</div>', Object.assign({ geri: true }, opt || {})); geriSayac(); var ic = $1('#icerik'); if (ic && typeof portreleriTazele === 'function') { try { portreleriTazele(ic); } catch (_) {} } }
  function yuk(baslik) { css(); iskelet(baslik, '<div class="yukleniyor">Yükleniyor…</div>', { geri: true }); }
  function bos(m) { return '<div class="bos">' + m + '</div>'; }
  function tikla(sec, fn) { $$(sec).forEach(function (el) { el.onclick = function (ev) { ev.preventDefault(); fn(el, ev); }; }); }

  /* ---------------------------------------------------------- özet + canlı kart */
  async function ozetAl(zorla) {
    if (!zorla && ozetC.v && Date.now() - ozetC.t < 20e3) return ozetC.v;
    ozetC.v = await rpc('tbmm_ozet'); ozetC.t = Date.now(); return ozetC.v;
  }
  function canliKartHtml(o) {
    var b = o.birlesim, cip, bas, alt;
    var sira = GK().sira || function (n) { return n; };
    if (b && b.durum !== 'kapandi') {
      cip = b.durum === 'arada' ? '<span class="gk-cip ara">ARA</span>' : '<span class="gk-cip canli"><i></i>' + (b.durum === 'yoklama' ? 'YOKLAMA' : 'CANLI') + '</span>';
      bas = 'Genel Kurul toplantıda · ' + (b.tur === 'olaganustu' ? 'Olağanüstü ' : '') + sira(b.no) + ' Birleşim';
      alt = (b.kursu ? 'Kürsüde: <b>' + esc(b.kursu) + '</b> · ' : '') + (b.salonda || 0) + ' vekil salonda · ' + (b.izleyici || 0) + ' izleyici';
    } else if (o.sonraki) {
      cip = '<span class="gk-cip yok">GENEL KURUL</span>'; bas = (o.sonraki.tur === 'olaganustu' ? 'Olağanüstü toplantı: ' : 'Sonraki birleşim: ') + gunSaat(o.sonraki.bas);
      alt = 'Birleşim açılınca salona gir; yoklamada "Buradayım" de, söz iste, oyunu kullan.';
    } else {
      cip = '<span class="gk-cip yok">GENEL KURUL</span>'; bas = o.dolu ? 'Genel Kurul bugün toplanmıyor' : 'Meclis henüz toplanmadı';
      alt = o.dolu ? 'Olağan birleşimler her akşam 21.00\'de.' : 'Seçilen milletvekilleri göreve başlayınca Genel Kurul her akşam 21.00\'de toplanır.';
    }
    return '<div class="tm-bant"><div class="tm-ust">' + cip + '<b class="bas">' + esc(bas) + '</b></div><p>' + alt + '</p>' +
      '<button type="button" class="gk-d altin" onclick="tbmmSalonAc()">' + IK.salon + (b && b.durum !== 'kapandi' ? 'Genel Kurul salonuna gir' : 'Genel Kurul salonu') + '</button>' +
      '<span class="egemen">EGEMENLİK KAYITSIZ ŞARTSIZ MİLLETİNDİR</span></div>';
  }
  function izgaraHtml(o) {
    var s = (o && o.sayilar) || {}, v = o && o.vekil;
    var rz = function (n) { return n ? '<i class="rz">' + n + '</i>' : ''; };
    var kut = function (ad, ik, bas, alt, n) { return '<button type="button" class="tm-kut" data-git="' + ad + '">' + rz(n) + ik + '<b>' + bas + '</b><span>' + alt + '</span></button>'; };
    return '<div class="tm-izgara">' +
      kut('kom', IK.kom, 'Komisyonlar', v ? (s.komisyonlarim ? s.komisyonlarim + ' komisyonda üyesin' : '19 ihtisas komisyonu · üye ol') : '19 ihtisas komisyonu', s.komisyon_gundem) +
      kut('soru', IK.soru, 'Soru önergeleri', 'Yazılı soru · 15 günde cevap', s.soru_bana) +
      kut('gg', IK.gg, 'Genel görüşme', s.gg_imza ? s.gg_imza + ' önerge imzada' : 'Önerge ver, imzala', 0) +
      kut('ar', IK.ar, 'Meclis araştırması', s.arastirma ? s.arastirma + ' araştırma sürüyor' : 'Araştırma komisyonları', 0) +
      kut('dil', IK.dil, 'Dilekçe', 'Vatandaş TBMM\'ye yazar', (s.dilekce_kom || 0) + (s.dilekce_bakanlik || 0)) +
      kut('hb', IK.hb, 'Halk buluşmaları', s.hb_canli ? s.hb_canli + ' buluşma şu an canlı' : s.hb_ilimde ? 'İlinde ' + s.hb_ilimde + ' buluşma' : 'Vekiller halkla buluşuyor', s.hb_canli) +
      kut('karne', IK.karne, 'Vekil karnesi', 'Meclis sıralaması', 0) +
      kut('arsiv', IK.arsiv, 'Tutanak arşivi', 'Geçmiş birleşimler', 0) +
      (o && o.gensoru_acik ? kut('gensoru', IK.gen, 'Gensoru', 'Hükümete güvensizlik', 0) : '<button type="button" class="tm-kut genis" data-git="gensoru">' + IK.gen + '<span class="o"><b>Gensoru</b><span>2017 Anayasa değişikliğiyle kaldırıldı; parlamenter sisteme geçilirse açılır.</span></span></button>') +
      '</div>';
  }
  function izgaraBagla(kok) {
    $$('[data-git]', kok).forEach(function (b) { b.onclick = function () { git(b.getAttribute('data-git')); }; });
  }
  function git(ad) {
    var E = { kom: komisyonlarEkrani, soru: sorularEkrani, gg: ggEkrani, ar: arastirmaEkrani, dil: dilekceEkrani, hb: hbEkrani, karne: karneEkrani };
    if (ad === 'arsiv') { if (window.tbmmTutanakArsiviAc) window.tbmmTutanakArsiviAc(); return; }
    if (ad === 'gensoru') {
      if (ozetC.v && ozetC.v.gensoru_acik) { try { if (D) D.devletSekme = 'hukumet'; } catch (_) {} sekmeAc('devlet'); return; }
      return form('Gensoru', '', '<p>Gensoru, 2017 Anayasa değişikliğiyle Cumhurbaşkanlığı Hükümet Sisteminde kaldırıldı. Bugün Meclis\'in denetim yolları: yazılı soru önergesi, genel görüşme, Meclis araştırması ve Meclis soruşturmasıdır (Anayasa m.98, 106).</p><p>Oyunda Türkiye parlamenter sisteme geçerse gensoru Devlet › Hükümet ekranında açılır.</p>', 'Anladım', function () { return Promise.resolve(); });
    }
    if (E[ad]) ekranAc(E[ad]);
  }
  async function merkezEkrani() {
    yuk('Meclis Çalışmaları');
    try { var o = await ozetAl(true); sayfa('Meclis Çalışmaları', canliKartHtml(o) + izgaraHtml(o)); izgaraBagla($1('#icerik')); }
    catch (err) { sayfa('Meclis Çalışmaları', bos(esc(hata(err)))); }
  }

  /* ---------------------------------------------------------- komisyonlar */
  async function komisyonlarEkrani() {
    yuk('Komisyonlar');
    try {
      var r = await rpc('komisyonlar'), L = r.komisyonlar || [];
      var kon = (r.kontenjan || []).map(function (k) { return '<tr><td><i style="display:inline-block;width:9px;height:9px;border-radius:50%;background:' + esc(k.renk || '#8E97B5') + ';margin-right:5px"></i>' + esc(k.parti) + '</td><td class="s">' + k.mv + '</td><td class="s">' + k.kontenjan + '</td></tr>'; }).join('');
      var h = '<div class="gk-kart altin"><h3>İhtisas komisyonları</h3><p>Kanun teklifleri konusuna göre esas komisyona havale edilir; komisyon görüşür, oylar ve rapor yazar. Her komisyon ' + r.boyut + ' üyelidir; sandalyeler parti gruplarına Meclis\'teki güçleri oranında dağıtılır. ' +
        (r.vekilim ? 'Sen en çok ' + r.azami_uyelik + ' komisyonda görev alabilirsin (' + (r.uyeliklerim || 0) + ' üyeliğin var).' : 'Komisyonlara milletvekilleri üye olur; toplantılarını herkes izleyebilir.') + '</p>' +
        (kon ? '<table class="tm-tablo" style="margin-top:8px"><tr><th>Parti</th><th class="s">Vekil</th><th class="s">Komisyon kontenjanı</th></tr>' + kon + '</table>' : '') + '</div>' +
        L.map(function (k) {
          var gecerli = (k.uyeler || []).filter(function (u) { return u.gecerli; }).length;
          return '<button type="button" class="tm-oge" style="display:block;width:100%;text-align:left;color:var(--txt)" data-kom="' + esc(k.kod) + '"><div class="bs"><div class="o"><b class="t">' + esc(k.ad) + '</b><small>' + esc(k.aciklama || '') + '</small>' +
            '<small>' + gecerli + '/' + r.boyut + ' üye · Başkan: ' + esc(k.baskan || 'seçilmedi') + ((k.gundem || []).length ? ' · gündemde ' + k.gundem.length + ' teklif' : '') + '</small></div>' +
            (k.gecerli_uyeyim ? '<span class="tm-rz altin">Üyesin</span>' : k.uyeyim ? '<span class="tm-rz sari">Yedek</span>' : '') + '</div></button>';
        }).join('');
      sayfa('Komisyonlar', h);
      tikla('[data-kom]', function (el) { var kod = el.getAttribute('data-kom'); ekranAc(function () { return komisyonEkrani(kod); }); });
    } catch (err) { sayfa('Komisyonlar', bos(esc(hata(err)))); }
  }
  function komTutanak(L) {
    return (L || []).map(function (x) {
      var ad = x.tur === 'baskan' ? 'KOMİSYON BAŞKANI ' + esc((x.ad || '').toLocaleUpperCase('tr')) : esc(((x.rol ? x.rol + ' ' : '') + (x.ad || '')).toLocaleUpperCase('tr')) + (x.il ? ' (' + esc(x.il) + ')' : '');
      return '<p class="gk-t" data-kid="' + x.id + '"><span class="ad">' + (x.renk ? '<i style="background:' + esc(x.renk) + '"></i>' : '') + ad + ' –</span> ' + esc(x.m) + '</p>';
    }).join('');
  }
  async function komisyonEkrani(kod) {
    yuk('Komisyon');
    var son = 0, r;
    var ciz = function () {
      var u = (r.uyeler || []);
      var h = '<div class="gk-kart altin"><h3>' + esc(r.ad) + '</h3><p>' + esc(r.aciklama || '') + '</p><p class="gk-not">Başkan: <b>' + esc(r.baskan || 'henüz seçilmedi') + '</b> · ' + u.filter(function (x) { return x.gecerli; }).length + '/' + r.boyut + ' asıl üye</p>' +
        (r.vekilim ? (r.uyeyim ? '<button type="button" class="gk-d cizgi" data-k="ayril">Komisyondan ayrıl</button>' : '<button type="button" class="gk-d altin" data-k="katil">Komisyona üye ol</button>') : '') + '</div>';
      h += '<div class="gk-kart"><h3>Komisyon salonu</h3><p class="gk-not" style="margin:0 0 8px">Asıl üyeler, Hükümet üyeleri ve görüşülen teklifin sahibi konuşur (150 kelime). Toplantıyı herkes izler.</p><div class="tm-kom-akis" id="tmKomAkis">' +
        (komTutanak(r.tutanak) || '<p class="gk-t sis">Komisyonda henüz konuşma yok.</p>') + '</div>' +
        (r.yazabilirim ? '<textarea id="tmKomMetin" maxlength="1200" placeholder="Sayın Başkan, değerli komisyon üyeleri…" style="display:block;width:100%;box-sizing:border-box;margin-top:8px;padding:11px 12px;border-radius:12px;border:1px solid rgba(255,255,255,.2);background:#1b2140;color:#f2f5ff;font:inherit;font-size:16px;min-height:84px"></textarea>' +
          '<div class="gk-iki" style="align-items:center"><span class="gk-say" id="tmKomSay">0 / 150 kelime</span><button type="button" class="gk-d altin" data-k="konus">Söz al</button></div>' : '') + '</div>';
      if ((r.gundem || []).length) h += '<div class="gk-kart"><h3>Komisyon gündemi</h3>' + r.gundem.map(function (g) {
        return '<div class="gk-satir"><div class="orta"><b>' + esc(g.baslik) + '</b><small>Kabul ' + g.kabul + ' · Ret ' + g.ret + (g.oyum ? ' · Oyun: ' + esc({ kabul: 'Kabul', ret: 'Ret', cekimser: 'Çekimser' }[g.oyum]) : '') + ' · Genel Kurul oylaması ' + gunSaat(g.oy_bas) + '</small></div><button type="button" class="gk-mini altin" data-kanun="' + g.id + '">Aç</button></div>';
      }).join('') + '</div>';
      h += '<div class="gk-kart"><h3>Üyeler</h3>' + (u.length ? u.map(function (x) {
        return '<div class="tm-uye"><div class="pp">' + portreH(x.kad, x.renk, 36) + '</div><div class="o"><b>' + esc(x.kad) + (x.baskan ? ' · <span style="color:#d9b25b">Başkan</span>' : '') + '</b><small>' + esc(x.parti || 'Bağımsız') + (x.gecerli ? '' : ' · kontenjan dışı (yedek)') + (x.oy ? ' · başkanlık için ' + x.oy + ' oy' : '') + '</small></div>' +
          (r.gecerli_uyeyim && x.gecerli ? '<button type="button" class="gk-mini ' + (r.baskan_oyum === x.kad ? 'altin' : 'cizgi') + '" data-baskan="' + esc(x.kad) + '">' + (r.baskan_oyum === x.kad ? 'Oyun' : 'Başkan oyu') + '</button>' : '') +
          (x.cikarabilirim ? '<button type="button" class="gk-mini cizgi" data-cikar="' + esc(x.kad) + '">Çek</button>' : '') + '</div>';
      }).join('') : '<p class="gk-not">Henüz üye yok.</p>') + '</div>';
      if ((r.kontenjan || []).length) h += '<div class="gk-kart"><h3>Kontenjan</h3><table class="tm-tablo"><tr><th>Parti</th><th class="s">Dolu</th><th class="s">Kontenjan</th></tr>' + r.kontenjan.map(function (k) { return '<tr><td>' + esc(k.parti) + '</td><td class="s">' + k.dolu + '</td><td class="s">' + k.kontenjan + '</td></tr>'; }).join('') + '</table></div>';
      if ((r.son_kararlar || []).length) h += '<div class="gk-kart"><h3>Son kararlar</h3>' + r.son_kararlar.map(function (k) { return '<div class="gk-satir"><div class="orta"><b>' + esc(k.baslik) + '</b><small>' + (k.karar === 'kabul' ? 'Kabul edildi' : k.karar === 'ret' ? 'Reddedildi' : esc(k.karar)) + ' · ' + (k.kabul || 0) + '–' + (k.ret || 0) + ' · ' + gun(k.at) + '</small></div></div>'; }).join('') + '</div>';
      if (kod === 'dilekce') h += '<button type="button" class="gk-d" data-k="dilekce">Dilekçeleri incele' + (r.dilekce_bekleyen ? ' (' + r.dilekce_bekleyen + ' bekliyor)' : '') + '</button>';
      sayfa(r.kisa || 'Komisyon', h);
      var ak = $1('#tmKomAkis'); if (ak) ak.scrollTop = ak.scrollHeight;
      var ta = $1('#tmKomMetin'); if (ta) ta.oninput = function () { var n = kelime(ta.value), s = $1('#tmKomSay'); s.textContent = n + ' / 150 kelime'; s.classList.toggle('asti', n > 150); };
      tikla('[data-k="katil"]', function () { cagir('komisyon_katil', { p_kom: kod }, 'Komisyona katıldın.').then(yukle); });
      tikla('[data-k="ayril"]', function () { cagir('komisyon_ayril', { p_kom: kod }, 'Komisyondan ayrıldın.').then(yukle); });
      tikla('[data-k="dilekce"]', function () { ekranAc(dilekceEkrani); });
      tikla('[data-k="konus"]', function (b) { var m = ($1('#tmKomMetin') || {}).value || ''; if (!m.trim()) return; b.disabled = true; cagir('kom_konus', { p_kom: kod, p_metin: m }).then(function () { $1('#tmKomMetin').value = ''; tazele(); }).catch(function () {}).then(function () { b.disabled = false; }); });
      tikla('[data-baskan]', function (b) { cagir('komisyon_baskan_oy', { p_kom: kod, p_kad: b.getAttribute('data-baskan') }, 'Başkanlık oyun kaydedildi.').then(yukle); });
      tikla('[data-cikar]', function (b) { cagir('komisyon_uye_cikar', { p_kom: kod, p_kad: b.getAttribute('data-cikar') }, 'Üye komisyondan çekildi.').then(yukle); });
      tikla('[data-kanun]', function (b) { var id = +b.getAttribute('data-kanun'); ekranAc(function () { return komKanunEkrani(id); }); });
    };
    var yukle = async function () { try { r = await rpc('kom_salon', { p_kom: kod, p_son: 0 }); son = (r.tutanak || []).reduce(function (a, x) { return Math.max(a, x.id); }, 0); ciz(); izle(); } catch (err) { sayfa('Komisyon', bos(esc(hata(err)))); } };
    var tazele = async function () {
      var ak = $1('#tmKomAkis'); if (!ak) return;
      try { var y = await rpc('kom_salon', { p_kom: kod, p_son: son }); var L = (y.tutanak || []).filter(function (x) { return x.id > son && !$1('[data-kid="' + x.id + '"]'); });
        if (L.length) { var sis = $1('.gk-t.sis', ak); if (sis) sis.remove(); ak.insertAdjacentHTML('beforeend', komTutanak(L)); son = Math.max.apply(null, [son].concat(L.map(function (x) { return x.id; }))); ak.scrollTop = ak.scrollHeight; } } catch (_) {}
    };
    var izle = function () { if (window.CANLI && CANLI.izle) CANLI.izle({ anahtarlar: ['miting:kom.' + kod], tazele: tazele, hizliMs: 12000, yedekMs: 60000, yayilim: 3000, pencereMs: 2500 }); };
    await yukle();
  }
  async function komKanunEkrani(id) {
    yuk('Komisyon oylaması');
    var r;
    var ciz = function () {
      var oylar = r.oylar || [], say = { kabul: 0, ret: 0, cekimser: 0 }; oylar.forEach(function (o) { say[o.oy] = (say[o.oy] || 0) + 1; });
      var h = '<div class="gk-kart altin"><h3>' + esc(r.kom_ad) + '</h3><p>' + (r.acik ? 'Komisyon görüşmesi Genel Kurul oylamasına kadar sürer · <b data-geri="' + new Date(r.bitis).getTime() + '"></b>' : 'Komisyon kararı: <b>' + esc(r.karar === 'kabul' ? 'Kabul' : r.karar === 'ret' ? 'Ret' : (r.karar || 'karar verilmedi')) + '</b>') + '</p>' +
        '<p class="gk-not">' + r.uye_sayisi + ' asıl üye · karar için en az ' + r.esik + ' oy · Komisyon başkanı: ' + esc(r.baskan || '—') + ' · Havale: ' + esc(r.havale_eden || 'Başkanlık') + ', ' + gunSaat(r.havale_at) + '</p>' +
        '<div class="gk-say3" style="margin-top:8px"><div><b style="color:#6ee7a6">' + say.kabul + '</b><span>Kabul</span></div><div><b style="color:#ff8a80">' + say.ret + '</b><span>Ret</span></div><div><b style="color:#ffd27a">' + say.cekimser + '</b><span>Çekimser</span></div></div>';
      if (r.oy_verebilirim) h += '<div class="gk-not">Oyun: <b>' + esc({ kabul: 'Kabul', ret: 'Ret', cekimser: 'Çekimser' }[r.oyum] || 'henüz kullanmadın') + '</b></div>' +
        '<input id="tmKG" maxlength="400" placeholder="Gerekçe ya da muhalefet şerhi (isteğe bağlı)" style="display:block;width:100%;box-sizing:border-box;margin-top:8px;padding:11px 12px;border-radius:12px;border:1px solid rgba(255,255,255,.2);background:#1b2140;color:#f2f5ff;font:inherit;font-size:16px">' +
        '<div class="gk-uc">' + [['kabul', 'KABUL', 'evet'], ['ret', 'RET', 'hayir'], ['cekimser', 'ÇEKİMSER', 'cek']].map(function (x) { return '<button type="button" class="gk-d ' + x[2] + (r.oyum === x[0] ? ' secili' : '') + '" data-oy="' + x[0] + '">' + x[1] + '</button>'; }).join('') + '</div>';
      h += '</div>';
      h += '<div class="gk-kart"><h3>Komisyon raporu</h3>' + (r.rapor ? '<p style="white-space:pre-wrap">' + esc(r.rapor) + '</p><p class="gk-not">' + esc(r.rapor_yazan || '') + ' · ' + gunSaat(r.rapor_at) + '</p>' : '<p class="gk-not">Rapor henüz yazılmadı. Raporu komisyon başkanı yazar.</p>') +
        (r.rapor_yazabilirim ? '<textarea id="tmRap" maxlength="8000" style="display:block;width:100%;box-sizing:border-box;margin-top:8px;padding:11px 12px;border-radius:12px;border:1px solid rgba(255,255,255,.2);background:#1b2140;color:#f2f5ff;font:inherit;font-size:16px;min-height:120px" placeholder="Komisyonumuz teklifi görüşmüş…">' + esc(r.rapor || '') + '</textarea><button type="button" class="gk-d altin" data-k="rapor">Raporu kaydet</button>' : '') + '</div>';
      if (oylar.length) h += '<div class="gk-kart"><h3>Oylar</h3>' + oylar.map(function (o) { return '<div class="gk-satir"><div class="orta"><b>' + esc(o.kad) + ' · ' + esc(o.parti || 'Bağımsız') + '</b><small>' + esc({ kabul: 'Kabul', ret: 'Ret', cekimser: 'Çekimser' }[o.oy]) + (o.gerekce ? ' · ' + esc(o.gerekce) : '') + '</small></div></div>'; }).join('') + '</div>';
      if (r.havale_edebilirim) h += '<div class="gk-kart"><h3>Havaleyi değiştir</h3><p class="gk-not">Meclis Başkanı, teklif verildikten sonraki 6 saat içinde ve komisyonda oy kullanılmadan esas komisyonu değiştirebilir.</p><select id="tmHav" style="display:block;width:100%;margin-top:8px;padding:11px;border-radius:12px;background:#1b2140;color:#fff;font-size:16px">' +
        (r.komisyonlar || []).map(function (k) { return '<option value="' + esc(k.kod) + '"' + (k.kod === r.kom_kod ? ' selected' : '') + '>' + esc(k.ad) + '</option>'; }).join('') + '</select><button type="button" class="gk-d" data-k="havale">Havale et</button></div>';
      h += '<button type="button" class="gk-d cizgi" data-k="metin">Teklifin metni ve gerekçesi</button>';
      sayfa('Komisyon oylaması', h);
      tikla('[data-oy]', function (b) { cagir('komisyon_oy', { p_kanun: id, p_oy: b.getAttribute('data-oy'), p_gerekce: ($1('#tmKG') || {}).value || null }, 'Komisyon oyun kaydedildi.').then(function (x) { r = x; ciz(); }); });
      tikla('[data-k="rapor"]', function () { cagir('komisyon_rapor', { p_kanun: id, p_metin: $1('#tmRap').value }, 'Rapor kaydedildi.').then(function (x) { r = x; ciz(); }); });
      tikla('[data-k="havale"]', function () { cagir('komisyon_havale', { p_kanun: id, p_kom: $1('#tmHav').value }, 'Teklif yeniden havale edildi.').then(function (x) { r = x; ciz(); }); });
      tikla('[data-k="metin"]', function () { if (typeof kanunEkrani === 'function') ekranAc(function () { return kanunEkrani(id); }); });
    };
    try { r = await rpc('komisyon_kanun', { p_kanun: id }); if (!r) { sayfa('Komisyon oylaması', bos('Bu teklif komisyonda değil.')); return; } ciz(); }
    catch (err) { sayfa('Komisyon oylaması', bos(esc(hata(err)))); }
  }

  /* ---------------------------------------------------------- yazılı soru önergeleri */
  var soruF = 'hepsi';
  async function sorularEkrani() {
    yuk('Soru Önergeleri');
    try {
      var r = await rpc('tbmm_sorular', { p_filtre: soruF, p_bakanlik: null });
      var seg = [['hepsi', 'Tümü'], ['bekleyen', 'Cevap bekleyen'], ['cevaplanan', 'Cevaplanan'], r.vekilim ? ['benim', 'Benim'] : null, (r.muhataplarim || []).length ? ['bana', 'Bana gelen'] : null].filter(Boolean);
      var h = '<div class="gk-kart altin"><h3>Yazılı soru önergesi</h3><p>Anayasa m.98: Milletvekili Cumhurbaşkanı Yardımcısına ve bakanlara yazılı soru sorar; en geç 15 gün içinde cevaplanır. Cevapsız kalan sorular Başkanlık sunuşlarında Genel Kurula duyurulur.</p>' +
        (r.vekilim ? '<button type="button" class="gk-d altin" data-k="ver">Soru önergesi ver</button><p class="gk-not">Bugün ' + (r.bugun || 0) + '/3 önerge verdin.</p>' : '') + '</div>' +
        '<div class="tm-seg">' + seg.map(function (x) { return '<button type="button" class="' + (soruF === x[0] ? 'aktif' : '') + '" data-f="' + x[0] + '">' + x[1] + '</button>'; }).join('') + '</div>' +
        ((r.liste || []).map(soruHtml).join('') || bos('Bu listede soru önergesi yok.'));
      if ((r.karne || []).length) h += '<div class="gk-kart"><h3>Hükümetin cevap karnesi (60 gün)</h3><table class="tm-tablo"><tr><th>Muhatap</th><th class="s">Soru</th><th class="s">Cevap</th><th class="s">Geciken</th></tr>' +
        r.karne.map(function (k) { return '<tr><td>' + esc(k.ad) + (k.muhatap ? '<br><small style="color:var(--mut)">' + esc(k.muhatap) + '</small>' : '') + '</td><td class="s">' + k.soru + '</td><td class="s">%' + (k.oran == null ? '—' : k.oran) + '</td><td class="s" style="color:' + (k.gecikmis ? '#ff8a80' : 'inherit') + '">' + k.gecikmis + '</td></tr>'; }).join('') + '</table></div>';
      sayfa('Soru Önergeleri', h);
      tikla('[data-f]', function (b) { soruF = b.getAttribute('data-f'); sorularEkrani(); });
      tikla('[data-k="ver"]', function () { soruVerForm(r.hedefler || [], null, ''); });
      tikla('[data-cevapla]', function (b) {
        var sid = +b.getAttribute('data-cevapla');
        form('Soru önergesini cevapla', 'Cevabın milletvekiline ve (varsa) soruyu soran vatandaşa iletilir, herkese açık yayımlanır.', '<label for="tmSC">Cevap</label><textarea id="tmSC" maxlength="8000" style="min-height:150px"></textarea>', 'Cevabı gönder',
          function (md) { return cagir('tbmm_soru_cevapla', { p_id: sid, p_metin: $1('#tmSC', md).value }, 'Soru önergesi cevaplandı.').then(sorularEkrani); });
      });
    } catch (err) { sayfa('Soru Önergeleri', bos(esc(hata(err)))); }
  }
  function soruHtml(s) {
    var k = s.soran || {};
    return '<div class="tm-oge"><div class="bs"><div class="o"><b class="t">' + s.no + ' · ' + esc(s.konu) + '</b><small>' + esc(k.ad || '') + (k.il ? ' (' + esc(k.il) + ')' : '') + (k.kisa ? ' · ' + esc(k.kisa) : '') + ' → ' + esc(s.hedef) + ' · ' + gun(s.zaman) + '</small>' +
      (s.vatandas ? '<small>Halk buluşmasında ' + esc(s.vatandas) + ' sordu</small>' : '') + '</div>' +
      (s.yanit ? '<span class="tm-rz iyi">Cevaplandı</span>' : s.gecikti ? '<span class="tm-rz kotu">Süre geçti</span>' : '<span class="tm-rz sari">' + Math.max(0, Math.ceil((new Date(s.son).getTime() - Date.now()) / 864e5)) + ' gün</span>') + '</div>' +
      '<p>' + esc(s.soru) + '</p>' + (s.yanit ? '<div class="tm-cevap"><b>' + esc((s.yanitlayan && (s.yanitlayan.rol ? s.yanitlayan.rol + ' ' : '') + s.yanitlayan.ad) || s.hedef) + ' · ' + gun(s.yanit_at) + '</b><p>' + esc(s.yanit) + '</p></div>' : '') +
      (s.cevaplayabilirim ? '<button type="button" class="gk-d altin" data-cevapla="' + s.id + '">Cevapla</button>' : '') + '</div>';
  }
  function soruVerForm(hedefler, hbSoru, metin) {
    var h = (hedefler || []).map(function (x) { return '<option value="' + esc(x.kod) + '">' + esc(x.ad) + '</option>'; }).join('');
    var yap = function (L) {
      form(hbSoru ? 'Vatandaşın sorusunu önergeye çevir' : 'Yazılı soru önergesi', 'Türkiye Büyük Millet Meclisi Başkanlığına: Aşağıdaki sorularımın … tarafından yazılı olarak cevaplandırılmasını arz ederim. (24 saatte en çok 3 önerge.)',
        '<label for="tmSH">Muhatap</label><select id="tmSH">' + L + '</select><label for="tmSK">Konu</label><input id="tmSK" maxlength="100" placeholder="Örn. Ege\'de kuraklık"><label for="tmSS">Sorular</label><textarea id="tmSS" maxlength="5000" style="min-height:140px" placeholder="1- …\n2- …">' + esc(metin || '') + '</textarea>', 'Önergeyi ver',
        function (md) { return cagir('tbmm_soru_ver', { p_bakanlik: $1('#tmSH', md).value, p_konu: $1('#tmSK', md).value, p_soru: $1('#tmSS', md).value, p_hb_soru: hbSoru }, 'Soru önergen Başkanlığa sunuldu.'); });
    };
    if (h) yap(h); else rpc('tbmm_sorular', { p_filtre: 'benim', p_bakanlik: null }).then(function (r) { yap((r.hedefler || []).map(function (x) { return '<option value="' + esc(x.kod) + '">' + esc(x.ad) + '</option>'; }).join('')); }).catch(function (err) { bildir(hata(err), true); });
  }

  /* ---------------------------------------------------------- genel görüşme */
  async function ggEkrani() {
    yuk('Genel Görüşme');
    try {
      var r = await rpc('gk_gg_liste');
      var h = '<div class="gk-kart altin"><h3>Genel görüşme önergesi</h3><p>Toplumu ve Devlet faaliyetlerini ilgilendiren bir konunun Genel Kurulda görüşülmesidir (Anayasa m.98). Önerge grup adına ya da ' + r.yeter + ' milletvekilinin imzasıyla verilir; ön görüşmede Genel Kurul açılıp açılmamasını oylar. İmza süresi 48 saat; 7 gün içinde görüşülmeyen önerge düşer.</p>' +
        (r.vekilim ? '<button type="button" class="gk-d altin" data-k="ver">Önerge ver</button>' : '') + '</div>' +
        ((r.liste || []).map(function (g) {
          var v = g.veren || {};
          return '<div class="tm-oge"><div class="bs"><div class="o"><b class="t">' + g.no + ' · ' + esc(g.konu) + '</b><small>' + esc(v.ad || '') + (v.kisa ? ' · ' + esc(v.kisa) : '') + (g.grup_adina ? ' · grup adına' : '') + ' · ' + gun(g.olusturma) + '</small>' +
            (g.durum === 'imza' ? '<small>İmza ' + g.imza + '/' + r.yeter + ' · <b data-geri="' + new Date(g.imza_bit).getTime() + '"></b></small>' : '') + (g.sonuc ? '<small>' + esc(g.sonuc) + '</small>' : '') + '</div>' + rozet(g.durum) + '</div>' +
            '<p>' + esc(g.gerekce) + '</p>' + ((g.imzacilar || []).length > 1 ? '<p class="gk-not">İmzalayanlar: ' + g.imzacilar.map(esc).join(', ') + '</p>' : '') +
            (g.durum === 'imza' && r.vekilim && !g.benim ? '<button type="button" class="gk-d ' + (g.imzaladim ? 'cizgi' : 'altin') + '" data-imza="' + g.id + '" data-v="' + (!g.imzaladim) + '">' + (g.imzaladim ? 'İmzamı geri çek' : 'Önergeyi imzala') + '</button>' : '') +
            (g.benim && (g.durum === 'imza' || g.durum === 'bekliyor') ? '<button type="button" class="gk-d cizgi" data-geri-cek="' + g.id + '">Önergeyi geri çek</button>' : '') + '</div>';
        }).join('') || bos('Henüz genel görüşme önergesi yok.'));
      sayfa('Genel Görüşme', h);
      tikla('[data-k="ver"]', function () {
        form('Genel görüşme önergesi', 'Konu ve gerekçe Genel Kurulda okunur.', '<label for="tmGK">Konu</label><input id="tmGK" maxlength="150"><label for="tmGG">Gerekçe</label><textarea id="tmGG" maxlength="6000" style="min-height:150px"></textarea>' +
          (r.grup ? '<label style="display:flex;gap:8px;align-items:center"><input type="checkbox" id="tmGA" style="width:22px;height:22px;margin:0"> Grup adına ver (imza gerekmez)</label>' : ''), 'Önergeyi ver',
          function (md) { return cagir('gk_gg_ver', { p_konu: $1('#tmGK', md).value, p_gerekce: $1('#tmGG', md).value, p_grup_adina: !!($1('#tmGA', md) || {}).checked }, 'Önergen Başkanlığa sunuldu.').then(ggEkrani); });
      });
      tikla('[data-imza]', function (b) { cagir('gk_gg_imza', { p_id: +b.getAttribute('data-imza'), p_imza: b.getAttribute('data-v') === 'true' }, 'İmzan kaydedildi.').then(ggEkrani); });
      tikla('[data-geri-cek]', function (b) { cagir('gk_gg_geri', { p_id: +b.getAttribute('data-geri-cek') }, 'Önerge geri çekildi.').then(ggEkrani); });
    } catch (err) { sayfa('Genel Görüşme', bos(esc(hata(err)))); }
  }

  /* ---------------------------------------------------------- Meclis araştırması */
  async function arastirmaEkrani() {
    yuk('Meclis Araştırması');
    try {
      var r = await rpc('meclis_arastirmalar', { p_limit: 20 });
      var oz = function (a) {
        return '<button type="button" class="tm-oge" style="display:block;width:100%;text-align:left;color:var(--txt)" data-ar="' + a.id + '"><div class="bs"><div class="o"><b class="t">' + a.no + ' · ' + esc(a.konu) + '</b><small>' + esc(a.teklif_eden || '') + (a.parti ? ' · ' + esc(a.parti.kisa || '') : '') + ' · ' + gun(a.olusturma) + '</small>' +
          (a.son ? '<small>Bu aşamanın bitişi: ' + gunSaat(a.son) + '</small>' : '') + (a.durum === 'imza' ? '<small>İmza ' + a.imza + '/' + r.imza_yeter + '</small>' : '') + (a.uye ? '<small>Komisyon ' + a.uye + '/' + a.uye_sayisi + ' üye' + (a.baskan ? ' · Başkan ' + esc(a.baskan) : '') + '</small>' : '') + '</div>' +
          rozet(a.durum) + '</div>' + (a.bekleyen_oy ? '<small style="color:#ffd27a">Oyunu bekliyor</small>' : '') + '</button>';
      };
      var h = '<div class="gk-kart altin"><h3>Meclis araştırması</h3><p>Bir konuda bilgi edinmek için Meclis\'in kurduğu araştırma komisyonu (Anayasa m.98). Önerge ' + r.imza_yeter + ' imzayla öngörüşmeye gelir; Genel Kurul kabul ederse ' + r.uye_sayisi + ' üyeli komisyon kurulur, bakanları ve yetkilileri dinler, rapor yazar, rapor Genel Kurulda oylanır.</p>' +
        (r.vekilim ? '<button type="button" class="gk-d altin" data-k="ver">Araştırma önergesi ver</button>' : '') + '</div>' +
        ((r.davetlerim || []).length ? '<div class="gk-kart"><h3>Komisyondan sana sorular</h3>' + r.davetlerim.map(function (d) { return '<div class="gk-satir"><div class="orta"><b>' + esc(d.konu) + '</b><small>' + esc(d.soran) + ': ' + esc(d.soru) + ' · son ' + gunSaat(d.son) + '</small></div><button type="button" class="gk-mini altin" data-ar="' + d.arastirma_id + '">Cevapla</button></div>'; }).join('') + '</div>' : '') +
        '<h3 style="font-size:15px;margin:6px 2px 8px;color:var(--mut)">SÜREN ARAŞTIRMALAR</h3>' + ((r.aktif || []).map(oz).join('') || bos('Şu an süren araştırma yok.')) +
        ((r.biten || []).length ? '<h3 style="font-size:15px;margin:12px 2px 8px;color:var(--mut)">SONUÇLANANLAR</h3>' + r.biten.map(oz).join('') : '');
      sayfa('Meclis Araştırması', h);
      tikla('[data-ar]', function (b) { var id = +b.getAttribute('data-ar'); ekranAc(function () { return arastirmaDetay(id); }); });
      tikla('[data-k="ver"]', function () {
        form('Meclis araştırması önergesi', 'Önergen ' + r.imza_yeter + ' milletvekili imzalayınca öngörüşmesi yapılır.', '<label for="tmAK">Konu</label><input id="tmAK" maxlength="150"><label for="tmAG">Gerekçe</label><textarea id="tmAG" maxlength="6000" style="min-height:150px"></textarea>', 'Önergeyi ver',
          function (md) { return cagir('meclis_arastirma_ver', { p_konu: $1('#tmAK', md).value, p_gerekce: $1('#tmAG', md).value }, 'Araştırma önergen imzaya açıldı.').then(arastirmaEkrani); });
      });
    } catch (err) { sayfa('Meclis Araştırması', bos(esc(hata(err)))); }
  }
  function sayimHtml(o) { if (!o) return ''; var k = o.kabul || 0, r = o.ret || 0, c = o.cekimser || 0; return '<div class="gk-say3" style="margin-top:8px"><div><b style="color:#6ee7a6">' + k + '</b><span>Kabul</span></div><div><b style="color:#ff8a80">' + r + '</b><span>Ret</span></div><div><b style="color:#ffd27a">' + c + '</b><span>Çekimser</span></div></div>'; }
  async function arastirmaDetay(id) {
    yuk('Araştırma');
    try {
      var a = await rpc('meclis_arastirma_detay', { p_id: id }), ben = a.ben || {};
      var oyDug = function (asama, oyum) { return '<div class="gk-not">Oyun: <b>' + esc({ kabul: 'Kabul', ret: 'Ret', cekimser: 'Çekimser' }[oyum] || 'henüz kullanmadın') + '</b></div><div class="gk-uc">' + [['kabul', 'KABUL', 'evet'], ['ret', 'RET', 'hayir'], ['cekimser', 'ÇEKİMSER', 'cek']].map(function (x) { return '<button type="button" class="gk-d ' + x[2] + (oyum === x[0] ? ' secili' : '') + '" data-oy="' + x[0] + '">' + x[1] + '</button>'; }).join('') + '</div>'; };
      var h = '<div class="gk-kart altin"><h3>' + a.no + ' · ' + esc(a.konu) + '</h3><p>' + rozet(a.durum) + (a.son ? ' · bitiş <b data-geri="' + new Date(a.son).getTime() + '"></b>' : '') + '</p><p>' + esc(a.gerekce) + '</p><p class="gk-not">Önerge sahibi: ' + esc(a.teklif_eden || '') + (a.sonuc_metin ? '<br>' + esc(a.sonuc_metin) : '') + '</p>';
      if (a.durum === 'imza') h += '<p class="gk-not">İmza ' + a.imza + '/' + a.imza_yeter + (a.imzalar && a.imzalar.length ? ': ' + a.imzalar.map(esc).join(', ') : '') + '</p>' +
        (ben.vekil && !ben.teklif_eden ? '<button type="button" class="gk-d ' + (ben.imzaladim ? 'cizgi' : 'altin') + '" data-k="imza">' + (ben.imzaladim ? 'İmzamı geri çek' : 'Önergeyi imzala') + '</button>' : '') +
        (ben.teklif_eden ? '<button type="button" class="gk-d cizgi" data-k="gericek">Önergeyi geri çek</button>' : '');
      if (a.durum === 'oylamada') h += '<p class="gk-not">Öngörüşme oylaması: Genel Kurul komisyon kurulup kurulmamasını oyluyor. Toplantı yeter sayısı ' + a.toplanti_yeter + ', karar yeter sayısı ' + a.karar_yeter + '.</p>' + sayimHtml(a.ongorusme) + (ben.vekil ? oyDug('ongorusme', ben.ongorusme_oyum) : '');
      if (a.durum === 'rapor_oylama' || a.durum === 'tamamlandi') h += a.rapor_oy ? '<p class="gk-not">Rapor oylaması</p>' + sayimHtml(a.rapor_oy) : '';
      if (a.durum === 'rapor_oylama' && ben.uye) h += oyDug('rapor', ben.rapor_oyum);
      h += '</div>';
      if (['kurulus', 'calisma', 'rapor_oylama', 'tamamlandi'].indexOf(a.durum) >= 0) {
        h += '<div class="gk-kart"><h3>Araştırma komisyonu</h3>' + ((a.kontenjan || []).length ? '<table class="tm-tablo"><tr><th>Parti</th><th class="s">Dolu</th><th class="s">Koltuk</th></tr>' + a.kontenjan.map(function (k) { return '<tr><td>' + esc((k.parti && k.parti.kisa) || 'Bağımsız') + '</td><td class="s">' + k.dolu + '</td><td class="s">' + k.koltuk + '</td></tr>'; }).join('') + '</table>' : '') +
          (a.uyeler || []).map(function (u) { return '<div class="tm-uye"><div class="pp">' + portreH(u.kad, u.parti && u.parti.renk, 36) + '</div><div class="o"><b>' + esc(u.kad) + (u.baskan ? ' · <span style="color:#d9b25b">Başkan</span>' : '') + '</b><small>' + esc((u.parti && u.parti.kisa) || 'Bağımsız') + (u.oy_aldi ? ' · ' + u.oy_aldi + ' başkanlık oyu' : '') + '</small></div>' +
            (ben.uye && a.durum !== 'tamamlandi' ? '<button type="button" class="gk-mini ' + (ben.baskan_oyum === u.kad ? 'altin' : 'cizgi') + '" data-baskan="' + esc(u.kad) + '">' + (ben.baskan_oyum === u.kad ? 'Oyun' : 'Başkan oyu') + '</button>' : '') + '</div>'; }).join('') +
          (a.durum === 'kurulus' && ben.vekil ? '<button type="button" class="gk-d ' + (ben.uye ? 'cizgi' : 'altin') + '" data-k="uye" data-v="' + (!ben.uye) + '">' + (ben.uye ? 'Komisyondan ayrıl' : 'Komisyona üye ol') + '</button>' + (a.serbest_an ? '<p class="gk-not">' + gunSaat(a.serbest_an) + '\'den sonra boş koltuklara her partiden vekil girebilir.</p>' : '') : '') + '</div>';
      }
      if ((a.dinlemeler || []).length || (a.durum === 'calisma' && ben.uye)) {
        h += '<div class="gk-kart"><h3>Dinlemeler</h3>' + (a.dinlemeler || []).map(function (d) {
          return '<div class="tm-oge" style="background:#17203f"><b class="t">' + esc(d.davetli) + (d.davetli_unvan ? ' · ' + esc(d.davetli_unvan) : '') + '</b><small>Soran: ' + esc(d.soran) + ' · ' + gun(d.zaman) + (d.durum === 'bekliyor' ? ' · cevap süresi ' + gunSaat(d.son) : '') + '</small><p>' + esc(d.soru) + '</p>' +
            (d.cevap ? '<div class="tm-cevap"><b>Cevap · ' + gun(d.cevap_at) + '</b><p>' + esc(d.cevap) + '</p></div>' : d.bana && d.durum === 'bekliyor' ? '<button type="button" class="gk-d altin" data-dinle="' + d.id + '">Komisyona cevap ver</button>' : '') + '</div>';
        }).join('') + (a.durum === 'calisma' && ben.uye ? '<button type="button" class="gk-d" data-k="davet">Bir yetkiliyi komisyona davet et</button>' : '') + '</div>';
      }
      if (a.rapor || (a.durum === 'calisma' && ben.baskan)) h += '<div class="gk-kart"><h3>Komisyon raporu</h3>' + (a.rapor ? '<p style="white-space:pre-wrap">' + esc(a.rapor) + '</p>' + (a.oneriler ? '<p class="gk-not"><b>Öneriler:</b> ' + esc(a.oneriler) + '</p>' : '') : '') +
        (a.durum === 'calisma' && ben.baskan ? '<button type="button" class="gk-d altin" data-k="rapor">' + (a.rapor ? 'Raporu güncelle' : 'Raporu yaz') + '</button>' : '') + '</div>';
      if ((a.serhler || []).length || (ben.uye && ['calisma', 'rapor_oylama'].indexOf(a.durum) >= 0 && !ben.serh_yazdim && a.rapor)) h += '<div class="gk-kart"><h3>Muhalefet şerhleri</h3>' + (a.serhler || []).map(function (s) { return '<div class="tm-oge" style="background:#17203f"><b class="t">' + esc(s.kad) + '</b><p>' + esc(s.metin) + '</p></div>'; }).join('') +
        (ben.uye && !ben.serh_yazdim && a.rapor && ['calisma', 'rapor_oylama'].indexOf(a.durum) >= 0 ? '<button type="button" class="gk-d cizgi" data-k="serh">Şerh yaz</button>' : '') + '</div>';
      sayfa('Araştırma', h);
      var yen = function () { return arastirmaDetay(id); };
      tikla('[data-k="imza"]', function () { cagir('meclis_arastirma_imza', { p_id: id, p_imza: !ben.imzaladim }, ben.imzaladim ? 'İmzan geri çekildi.' : 'Önergeyi imzaladın.').then(yen); });
      tikla('[data-k="gericek"]', function () { cagir('meclis_arastirma_geri_cek', { p_id: id }, 'Önerge geri çekildi.').then(yen); });
      tikla('[data-oy]', function (b) { cagir('meclis_arastirma_oy', { p_id: id, p_oy: b.getAttribute('data-oy') }, 'Oyun kaydedildi.').then(yen); });
      tikla('[data-k="uye"]', function (b) { cagir('meclis_arastirma_uye_ol', { p_id: id, p_katil: b.getAttribute('data-v') === 'true' }, 'Kaydedildi.').then(yen); });
      tikla('[data-baskan]', function (b) { cagir('meclis_arastirma_baskan_oy', { p_id: id, p_aday: b.getAttribute('data-baskan') }, 'Başkanlık oyun kaydedildi.').then(yen); });
      tikla('[data-dinle]', function (b) { var did = +b.getAttribute('data-dinle'); form('Komisyona cevap', 'Cevabın komisyon tutanağına ve rapora geçer.', '<textarea id="tmDC" maxlength="5000" style="min-height:150px"></textarea>', 'Cevabı gönder', function (md) { return cagir('meclis_arastirma_cevap', { p_dinleme: did, p_cevap: $1('#tmDC', md).value }, 'Cevabın komisyona iletildi.').then(yen); }); });
      tikla('[data-k="davet"]', function () { form('Komisyona davet', 'Bakan, Cumhurbaşkanı Yardımcısı, belediye başkanı ya da başka bir yetkiliyi soruyla davet edersin; cevap vermek zorundadır.', '<label for="tmDK">Kullanıcı adı</label><input id="tmDK" maxlength="40" autocapitalize="off"><label for="tmDS">Soru</label><textarea id="tmDS" maxlength="2000" style="min-height:120px"></textarea>', 'Davet et', function (md) { return cagir('meclis_arastirma_davet', { p_id: id, p_kad: $1('#tmDK', md).value.trim(), p_soru: $1('#tmDS', md).value }, 'Davet gönderildi.').then(yen); }); });
      tikla('[data-k="rapor"]', function () { form('Araştırma komisyonu raporu', 'Rapor Genel Kurulda oylanır.', '<label for="tmRR">Rapor</label><textarea id="tmRR" maxlength="12000" style="min-height:180px">' + esc(a.rapor || '') + '</textarea><label for="tmRO">Öneriler</label><textarea id="tmRO" maxlength="4000">' + esc(a.oneriler || '') + '</textarea>', 'Raporu kaydet', function (md) { return cagir('meclis_arastirma_rapor', { p_id: id, p_rapor: $1('#tmRR', md).value, p_oneriler: $1('#tmRO', md).value || null }, 'Rapor kaydedildi.').then(yen); }); });
      tikla('[data-k="serh"]', function () { form('Muhalefet şerhi', 'Şerhin rapora eklenir.', '<textarea id="tmSR" maxlength="4000" style="min-height:150px"></textarea>', 'Şerhi ekle', function (md) { return cagir('meclis_arastirma_serh', { p_id: id, p_metin: $1('#tmSR', md).value }, 'Şerhin eklendi.').then(yen); }); });
    } catch (err) { sayfa('Araştırma', bos(esc(hata(err)))); }
  }

  /* ---------------------------------------------------------- dilekçe */
  var dilF = 'benim';
  async function dilekceEkrani() {
    yuk('TBMM Dilekçe');
    try {
      var r = await rpc('tbmm_dilekceler', { p_kapsam: 'benim' });
      var seg = [['benim', 'Dilekçelerim'], r.komisyon ? ['komisyon', 'Komisyon (' + r.komisyon.length + ')'] : null, r.bakanlik ? ['bakanlik', 'Bakanlığıma (' + r.bakanlik.length + ')'] : null, ['cevap', 'Son cevaplar']].filter(Boolean);
      if (!seg.some(function (x) { return x[0] === dilF; })) dilF = 'benim';
      var bek = r.son_verdigim && Date.now() - new Date(r.son_verdigim).getTime() < 48 * 3600e3;
      var dk = function (d, kip) {
        var k = d.kisi || {};
        return '<div class="tm-oge"><div class="bs"><div class="o"><b class="t">' + d.no + ' · ' + esc(d.konu) + '</b><small>' + (kip !== 'benim' && k.ad ? esc(k.ad) + ' · ' : '') + gun(d.zaman) + (d.bakanlik_ad ? ' · ' + esc(d.bakanlik_ad) : '') + (d.son && (d.durum === 'komisyonda' || d.durum === 'bakanlikta') ? ' · süre ' + gunSaat(d.son) : '') + '</small></div>' + rozet(d.durum) + '</div>' +
          '<p>' + esc(d.metin) + '</p>' + (d.cevap && d.durum !== 'bakanlikta' ? '<div class="tm-cevap"' + (d.durum === 'reddedildi' ? ' style="border-left-color:#e5484d"' : '') + '><b>' + (d.cevap_tur === 'bakanlik' ? esc(d.bakanlik_ad || 'Bakanlık') : 'Dilekçe Komisyonu') + (d.cevaplayan ? ' · ' + esc(d.cevaplayan.ad) : '') + ' · ' + gun(d.cevap_at) + '</b><p>' + esc(d.cevap) + '</p></div>' : '') +
          (kip === 'komisyon' ? '<div class="gk-grup"><button type="button" class="gk-mini altin" data-dk="cevapla" data-id="' + d.id + '">Cevapla</button><button type="button" class="gk-mini" data-dk="bakanliga" data-id="' + d.id + '">Bakanlığa gönder</button><button type="button" class="gk-mini cizgi" data-dk="reddet" data-id="' + d.id + '">İşleme koyma</button></div>' : '') +
          (kip === 'bakanlik' ? '<button type="button" class="gk-d altin" data-bc="' + d.id + '">Bakanlık adına cevapla</button>' : '') + '</div>';
      };
      var L = dilF === 'komisyon' ? r.komisyon : dilF === 'bakanlik' ? r.bakanlik : dilF === 'cevap' ? r.son_cevaplar : r.benim;
      var h = '<div class="gk-kart altin"><h3>Türkiye Büyük Millet Meclisine dilekçe</h3><p>Anayasa m.74: Herkes kendisiyle ya da kamuyla ilgili dilek ve şikâyetlerini TBMM\'ye yazabilir. Dilekçe Komisyonu 72 saat içinde cevaplar ya da ilgili bakanlığa gönderir; bakanlık 15 gün içinde cevap verir.</p>' +
        '<button type="button" class="gk-d altin" data-k="ver"' + (bek || (r.hesap_gun != null && r.hesap_gun < 3) ? ' disabled' : '') + '>Dilekçe yaz</button>' +
        (bek ? '<p class="gk-not">48 saatte bir dilekçe verebilirsin.</p>' : r.hesap_gun != null && r.hesap_gun < 3 ? '<p class="gk-not">Dilekçe vermek için hesabının en az 3 günlük olması gerekir.</p>' : '') + '</div>' +
        '<div class="tm-seg">' + seg.map(function (x) { return '<button type="button" class="' + (dilF === x[0] ? 'aktif' : '') + '" data-f="' + x[0] + '">' + x[1] + '</button>'; }).join('') + '</div>' +
        ((L || []).map(function (d) { return dk(d, dilF); }).join('') || bos(dilF === 'benim' ? 'Henüz dilekçe vermedin.' : 'Burada dilekçe yok.'));
      sayfa('TBMM Dilekçe', h);
      tikla('[data-f]', function (b) { dilF = b.getAttribute('data-f'); dilekceEkrani(); });
      var bks = (r.bakanliklar || []).map(function (b) { return '<option value="' + esc(b.kod) + '">' + esc(b.ad) + '</option>'; }).join('');
      tikla('[data-k="ver"]', function () {
        form('Dilekçe', 'Türkiye Büyük Millet Meclisi Başkanlığına. Dilekçen Dilekçe Komisyonunun gündemine girer.', '<label for="tmDK2">Konu</label><input id="tmDK2" maxlength="120"><label for="tmDM">Dilekçe metni</label><textarea id="tmDM" maxlength="2500" style="min-height:150px" placeholder="Gereğinin yapılmasını saygılarımla arz ederim."></textarea>' +
          '<label for="tmDB">İlgili bakanlık (isteğe bağlı)</label><select id="tmDB"><option value="">Bilmiyorum</option>' + bks + '</select>', 'Gönder',
          function (md) { return cagir('tbmm_dilekce_ver', { p_konu: $1('#tmDK2', md).value, p_metin: $1('#tmDM', md).value, p_bakanlik: $1('#tmDB', md).value || null }, 'Dilekçen TBMM\'ye ulaştı.').then(function (x) { dilF = 'benim'; dilekceEkrani(); return x; }); });
      });
      tikla('[data-dk]', function (b) {
        var did = +b.getAttribute('data-id'), k = b.getAttribute('data-dk');
        var govde = k === 'bakanliga' ? '<label for="tmDKB">Bakanlık</label><select id="tmDKB">' + bks + '</select><label for="tmDKM">Not (isteğe bağlı)</label><textarea id="tmDKM" maxlength="1000"></textarea>' : '<label for="tmDKM">' + (k === 'reddet' ? 'Gerekçe' : 'Cevap') + '</label><textarea id="tmDKM" maxlength="3000" style="min-height:130px"></textarea>';
        form(k === 'cevapla' ? 'Dilekçeyi cevapla' : k === 'bakanliga' ? 'Bakanlığa gönder' : 'İşleme koyma', 'Karar dilekçe sahibine bildirilir.', govde, 'Kaydet',
          function (md) { return cagir('tbmm_dilekce_karar', { p_id: did, p_karar: k, p_metin: ($1('#tmDKM', md) || {}).value || null, p_bakanlik: ($1('#tmDKB', md) || {}).value || null }, 'Karar kaydedildi.').then(dilekceEkrani); });
      });
      tikla('[data-bc]', function (b) { var did = +b.getAttribute('data-bc'); form('Bakanlık cevabı', 'Cevabın dilekçe sahibine iletilir ve yayımlanır.', '<textarea id="tmBC" maxlength="3000" style="min-height:140px"></textarea>', 'Cevapla', function (md) { return cagir('tbmm_dilekce_bakan_cevap', { p_id: did, p_metin: $1('#tmBC', md).value }, 'Dilekçe cevaplandı.').then(dilekceEkrani); }); });
    } catch (err) { sayfa('TBMM Dilekçe', bos(esc(hata(err)))); }
  }

  /* ---------------------------------------------------------- halk buluşmaları */
  var hbIl = null;
  function hbKart(b) {
    var v = b.vekil || {};
    return '<button type="button" class="tm-oge" style="display:block;width:100%;text-align:left;color:var(--txt)" data-hb="' + b.id + '"><div class="bs"><div class="tm-uye" style="padding:0;border:0;flex:1"><div class="pp">' + portreH(v.kad, v.renk, 36) + '</div><div class="o"><b>' + esc(b.baslik) + '</b>' +
      '<small>' + esc(b.il || '') + ' Milletvekili ' + esc(v.ad || '') + (v.kisa ? ' · ' + esc(v.kisa) : '') + '</small><small>' + (b.canli ? 'Şu an canlı · ' + b.katilim + ' katılımcı · ' + b.soru + ' soru' : b.bitti ? gun(b.bas) + ' · ' + b.katilim + ' katılımcı' + (b.puan ? ' · ' + String(b.puan).replace('.', ',') + '/5' : '') : gunSaat(b.bas) + ' · ' + (b.hatirlat || 0) + ' kişi hatırlatma istedi') + '</small></div></div>' +
      (b.canli ? '<span class="gk-cip canli"><i></i>CANLI</span>' : b.durum === 'iptal' ? '<span class="tm-rz kotu">İptal</span>' : b.hatirlatiyorum ? '<span class="tm-rz altin">Hatırlatılacak</span>' : '') + '</div></button>';
  }
  async function hbEkrani() {
    yuk('Halk Buluşmaları');
    try {
      var r = await rpc('hb_liste', { p_il: hbIl });
      var iller = (window.VERI && VERI.iller) || [];
      var h = '<div class="gk-kart altin"><h3>Halk buluşmaları</h3><p>Milletvekilleri seçim bölgelerinde vatandaşla buluşur: 45 dakikalık canlı buluşmada sorular sorulur, vekil yanıtlar ya da soruyu Meclis\'e yazılı soru önergesi olarak taşır. Buluşma bitince katılanlar vekili puanlar.</p>' +
        (r.vekilim ? '<button type="button" class="gk-d altin" data-k="planla">Halk buluşması düzenle</button><p class="gk-not">Yalnız kendi seçim ilinde; günde 1, haftada 3 buluşma. Genel Kurul saatinde (20.00–23.00) buluşma yapılmaz.</p>' : '') +
        (iller.length ? '<label for="tmHI" style="display:block;font-size:14px;font-weight:700;margin-top:10px">İl</label><select id="tmHI" style="display:block;width:100%;margin-top:6px;padding:11px;border-radius:12px;background:#1b2140;color:#fff;font-size:16px">' + iller.map(function (i) { return '<option value="' + i.id + '"' + (i.id === r.il_id ? ' selected' : '') + '>' + esc(i.ad) + '</option>'; }).join('') + '</select>' : '') + '</div>';
      if ((r.canli || []).length) h += '<h3 style="font-size:15px;margin:6px 2px 8px;color:#ff8a80">ŞU AN CANLI · TÜRKİYE</h3>' + r.canli.map(hbKart).join('');
      h += '<h3 style="font-size:15px;margin:10px 2px 8px;color:var(--mut)">' + esc((r.il || 'İLİNDE').toLocaleUpperCase('tr')) + ' · YAKLAŞAN</h3>' + ((r.ilimde || []).filter(function (b) { return !b.canli; }).map(hbKart).join('') || bos('Bu ilde planlanmış buluşma yok.'));
      if ((r.benim || []).length) h += '<h3 style="font-size:15px;margin:10px 2px 8px;color:var(--mut)">BULUŞMALARIM</h3>' + r.benim.map(hbKart).join('');
      if ((r.gecmis || []).length) h += '<h3 style="font-size:15px;margin:10px 2px 8px;color:var(--mut)">GEÇMİŞ</h3>' + r.gecmis.map(hbKart).join('');
      sayfa('Halk Buluşmaları', h);
      var sel = $1('#tmHI'); if (sel) sel.onchange = function () { hbIl = +sel.value; hbEkrani(); };
      tikla('[data-hb]', function (b) { var id = +b.getAttribute('data-hb'); ekranAc(function () { return hbDetay(id); }); });
      tikla('[data-k="planla"]', function () {
        var v = new Date(Date.now() + 3600e3); v.setMinutes(0, 0, 0); if (v.getHours() >= 20 && v.getHours() < 23) v.setHours(23);
        var yerel = new Date(v.getTime() - v.getTimezoneOffset() * 60e3).toISOString().slice(0, 16);
        form('Halk buluşması', 'İlindeki oyunculara buluşma başlarken bildirim gider. Buluşma 45 dakika sürer.', '<label for="tmHZ">Başlangıç</label><input id="tmHZ" type="datetime-local" value="' + yerel + '"><label for="tmHB">Başlık</label><input id="tmHB" maxlength="100" placeholder="Örn. Esnafla buluşma: kira ve vergi sorunları">' +
          '<label for="tmHM">Açıklama (isteğe bağlı)</label><textarea id="tmHM" maxlength="1200"></textarea>', 'Planla',
          function (md) { var z = $1('#tmHZ', md).value; if (!z) throw new Error('Başlangıç zamanını seç.'); return cagir('hb_planla', { p_bas: new Date(z).toISOString(), p_baslik: $1('#tmHB', md).value, p_metin: $1('#tmHM', md).value || null }, 'Halk buluşman planlandı.').then(hbEkrani); });
      });
    } catch (err) { sayfa('Halk Buluşmaları', bos(esc(hata(err)))); }
  }
  async function hbDetay(id) {
    yuk('Halk Buluşması');
    var r;
    var ciz = function () {
      var v = r.vekil || {}, benim = r.benim;
      var h = '<div class="gk-kart altin"><div class="tm-uye" style="border:0;padding:0"><div class="pp" style="flex-basis:54px;width:54px;height:54px">' + portreH(v.kad, v.renk, 54) + '</div><div class="o"><b style="font-size:16px">' + esc(r.baslik) + '</b><small>' + esc(r.il) + ' Milletvekili ' + esc(v.ad) + (v.kisa ? ' · ' + esc(v.kisa) : '') + '</small></div>' +
        (r.canli ? '<span class="gk-cip canli"><i></i>CANLI</span>' : '') + '</div>' + (r.metin ? '<p>' + esc(r.metin) + '</p>' : '') +
        '<p class="gk-not">' + (r.canli ? 'Bitişe <b data-geri="' + new Date(r.bit).getTime() + '"></b> · ' : r.bitti ? 'Buluşma bitti · ' : 'Başlangıç ' + gunSaat(r.bas) + ' · <b data-geri="' + new Date(r.bas).getTime() + '"></b> · ') + r.katilim + ' katılımcı · ' + r.soru + ' soru · ' + r.yanit + ' yanıt' + (r.puan ? ' · memnuniyet ' + String(r.puan).replace('.', ',') + '/5 (' + r.puan_sayi + ')' : '') + '</p>';
      if (!r.canli && !r.bitti && r.durum === 'planli' && !benim) h += '<button type="button" class="gk-d ' + (r.hatirlatiyorum ? 'cizgi' : 'altin') + '" data-k="katil">' + (r.hatirlatiyorum ? 'Hatırlatmayı kapat' : 'Başlayınca hatırlat') + '</button>';
      if (r.canli && !benim && !r.katildim) h += '<button type="button" class="gk-d altin" data-k="katil">Buluşmaya katıl</button>';
      if (benim && !r.canli && !r.bitti && r.durum === 'planli') h += '<button type="button" class="gk-d cizgi" data-k="iptal">Buluşmayı iptal et</button>';
      if (r.mod) h += '<button type="button" class="gk-d cizgi" data-k="kaldir">Buluşmayı kaldır (İçerik Masası)</button>';
      h += '</div>';
      if (r.canli && !benim) h += '<div class="gk-kart"><h3>Soru sor</h3><textarea id="tmHS" maxlength="280" placeholder="Sayın Vekilim, …" style="display:block;width:100%;box-sizing:border-box;padding:11px 12px;border-radius:12px;border:1px solid rgba(255,255,255,.2);background:#1b2140;color:#f2f5ff;font:inherit;font-size:16px;min-height:80px"></textarea>' +
        '<div class="gk-iki" style="align-items:center"><span class="gk-say">' + (3 - (r.sorularim || 0)) + ' soru hakkın kaldı</span><button type="button" class="gk-d altin" data-k="sor"' + ((r.sorularim || 0) >= 3 ? ' disabled' : '') + '>Sor</button></div></div>';
      if (r.puanlayabilirim) h += '<div class="gk-kart"><h3>Buluşmayı puanla</h3><p class="gk-not">Vekilinin karnesine işlenir.</p><div class="tm-yildiz">' + [1, 2, 3, 4, 5].map(function (n) { return '<button type="button" data-puan="' + n + '" aria-label="' + n + ' puan">★</button>'; }).join('') + '</div></div>';
      else if (r.puanim) h += '<div class="gk-kart"><p>Puanın: <b>' + '★'.repeat(r.puanim) + '</b></p></div>';
      h += '<div class="gk-kart"><h3>Sorular</h3>' + ((r.sorular || []).map(function (q) {
        var k = q.kisi || {};
        return '<div class="tm-oge" style="background:#17203f"><div class="bs"><div class="o"><b class="t">' + esc(k.ad || '') + '</b><small>' + saat(q.zaman) + (q.onerge ? ' · Meclis\'e soru önergesi olarak taşındı' : '') + '</small></div>' +
          (!benim && r.canli ? '<button type="button" class="gk-mini ' + (q.begendim ? 'altin' : 'cizgi') + '" data-begen="' + q.id + '">▲ ' + q.begeni + '</button>' : '<span class="tm-rz">▲ ' + q.begeni + '</span>') + '</div><p>' + esc(q.metin) + '</p>' +
          (q.yanit ? '<div class="tm-cevap"><b>' + esc(v.ad) + ' · ' + saat(q.yanit_at) + '</b><p>' + esc(q.yanit) + '</p></div>' : '') +
          (benim && (r.canli || r.bitti) ? '<div class="gk-grup"><button type="button" class="gk-mini altin" data-yanit="' + q.id + '">' + (q.yanit ? 'Yanıtı düzenle' : 'Yanıtla') + '</button>' + (q.onerge ? '' : '<button type="button" class="gk-mini" data-onerge="' + q.id + '">Soru önergesine çevir</button>') + '<button type="button" class="gk-mini cizgi" data-sk="' + q.id + '">Kaldır</button></div>' : r.mod ? '<button type="button" class="gk-mini cizgi" data-sk="' + q.id + '">Kaldır</button>' : '') + '</div>';
      }).join('') || '<p class="gk-not">' + (r.canli ? 'İlk soruyu sen sor.' : 'Henüz soru yok.') + '</p>') + '</div>';
      if ((r.katilanlar || []).length) h += '<div class="gk-kart"><h3>Katılanlar (' + r.katilim + ')</h3><p class="gk-not">' + r.katilanlar.map(esc).join(', ') + '</p></div>';
      sayfa('Halk Buluşması', h);
      tikla('[data-k="katil"]', function () { cagir('hb_katil', { p_id: id }).then(function (x) { if (x && x.kidem) bildir('Buluşmaya katıldın · +' + String(x.kidem).replace('.', ',') + ' kıdem'); yukle(); }); });
      tikla('[data-k="iptal"]', function () { cagir('hb_iptal', { p_id: id }, 'Buluşma iptal edildi.').then(yukle); });
      tikla('[data-k="kaldir"]', function () { form('Buluşmayı kaldır', 'Kural dışı içerik nedeniyle buluşma herkes için kaldırılır.', '<label for="tmHG">Gerekçe</label><input id="tmHG" maxlength="200">', 'Kaldır', function (md) { return cagir('hb_kaldir', { p_id: id, p_gerekce: $1('#tmHG', md).value || null }, 'Buluşma kaldırıldı.').then(function () { geriGit(); }); }); });
      tikla('[data-k="sor"]', function (b) { var m = $1('#tmHS').value; if (!m.trim()) return; b.disabled = true; cagir('hb_soru_sor', { p_id: id, p_metin: m }, 'Sorun vekile iletildi.').then(yukle).catch(function () { b.disabled = false; }); });
      tikla('[data-begen]', function (b) { cagir('hb_soru_begen', { p_soru: +b.getAttribute('data-begen') }).then(yukle); });
      tikla('[data-puan]', function (b) { cagir('hb_puanla', { p_id: id, p_puan: +b.getAttribute('data-puan') }, 'Puanın kaydedildi.').then(yukle); });
      tikla('[data-sk]', function (b) { cagir('hb_soru_kaldir', { p_soru: +b.getAttribute('data-sk') }, 'Soru kaldırıldı.').then(yukle); });
      tikla('[data-yanit]', function (b) { var q = (r.sorular || []).find(function (x) { return x.id === +b.getAttribute('data-yanit'); }) || {}; form('Soruyu yanıtla', esc(q.metin), '<textarea id="tmHY" maxlength="600" style="min-height:110px">' + esc(q.yanit || '') + '</textarea>', 'Yanıtla', function (md) { return cagir('hb_yanitla', { p_soru: q.id, p_metin: $1('#tmHY', md).value }, 'Yanıtın yayımlandı.').then(yukle); }); });
      tikla('[data-onerge]', function (b) { var q = (r.sorular || []).find(function (x) { return x.id === +b.getAttribute('data-onerge'); }) || {}; soruVerForm(null, q.id, 'Halk buluşmasında vatandaşımızın sorusu: ' + (q.metin || '')); });
    };
    var yukle = async function () { try { r = await rpc('hb_detay', { p_id: id }); ciz(); izle(); } catch (err) { sayfa('Halk Buluşması', bos(esc(hata(err)))); } };
    var izle = function () { if (window.CANLI && CANLI.izle && r && r.canli) CANLI.izle({ anahtarlar: ['miting:hb.' + id], tazele: function () { if ($1('#icerik .tm') && !$1('#modal')) return yukle(); }, hizliMs: 10000, yedekMs: 45000, yayilim: 3000, pencereMs: 3000 }); };
    await yukle();
  }

  /* ---------------------------------------------------------- vekil karnesi */
  async function karneEkrani(kad) {
    yuk('Vekil Karnesi');
    var ben = null, sira = [];
    try { sira = await rpc('tbmm_meclis_siralama', { p_limit: 30 }); } catch (_) {}
    try { ben = await rpc('tbmm_vekil_karne', { p_kad: kad || null }); } catch (err) { if (kad) { sayfa('Vekil Karnesi', bos(esc(hata(err)))); return; } }
    var h = '';
    if (ben) {
      var k = ben.kisi || {}, y = Math.max(0, Math.min(100, Number(ben.puan) || 0));
      h += '<div class="gk-kart altin"><div class="tm-puan"><div class="halka" style="--y:' + y + '%"><span>' + (ben.puan == null ? '—' : ben.puan) + '</span></div><div style="flex:1;min-width:0"><b style="display:block;font-size:17px;overflow-wrap:anywhere">' + esc(k.ad) + '</b><small style="display:block;color:var(--mut);font-size:13px">' + esc(k.il || '') + ' Milletvekili' + (k.kisa ? ' · ' + esc(k.kisa) : '') + '</small>' +
        '<small style="display:block;color:var(--txt2);font-size:13.5px;margin-top:4px">Meclis sıralaması: <b>' + (ben.sira || '—') + '</b> / ' + (ben.toplam || 0) + '</small></div></div>' +
        '<div class="tm-karne"><div><b>' + ben.yoklama + '/' + ben.birlesim + '</b><span>yoklama</span></div><div><b>' + ben.konusma + '</b><span>kürsü konuşması</span></div><div><b>' + ben.alkis + '</b><span>alkış aldı</span></div>' +
        '<div><b>' + ben.oy_kullandi + '/' + ben.oylama + '</b><span>kanun oylaması</span></div><div><b>' + ben.kanun_teklif + '</b><span>kanun teklifi</span></div><div><b>' + ben.kanunlasan + '</b><span>yasalaştı</span></div>' +
        '<div><b>' + ben.soru + '</b><span>soru önergesi</span></div><div><b>' + ben.hb + '</b><span>halk buluşması</span></div><div><b>' + (ben.hb_puan == null ? '—' : String(ben.hb_puan).replace('.', ',')) + '</b><span>halk puanı</span></div></div>' +
        ((ben.komisyonlar || []).length ? '<p class="gk-not">Komisyonlar: ' + ben.komisyonlar.map(function (c) { return esc(c.ad) + (c.baskan ? ' (Başkan)' : ''); }).join(', ') + '</p>' : '') +
        ((ben.disiplin || []).length ? '<p class="gk-not" style="color:#ff8a80">Disiplin: ' + ben.disiplin.map(function (d) { return esc({ uyarma: 'uyarma', kinama: 'kınama', cikarma: 'geçici çıkarma' }[d.tur] || d.tur) + ' (' + gun(d.zaman) + ')'; }).join(', ') + '</p>' : '') +
        ((ben.son_konusmalar || []).length ? '<h3 style="font-size:14px;margin:12px 0 4px;color:var(--mut)">SON KONUŞMALAR</h3>' + ben.son_konusmalar.map(function (s) { return '<div class="gk-alinti" style="margin-top:6px">“' + esc(s.m) + '”<br><small style="font-style:normal;color:var(--mut)">' + gunSaat(s.z) + '</small></div>'; }).join('') : '') + '</div>';
    }
    h += '<div class="gk-kart"><h3>Meclis sıralaması</h3><p class="gk-not" style="margin:0 0 6px">Yoklama, kürsü, oylamalara katılım, kanun teklifi, soru önergesi ve halk buluşmalarından hesaplanır; 10 dakikada bir güncellenir.</p>' +
      ((sira || []).map(function (x) { return '<div class="tm-uye" data-kad="' + esc(x.kad) + '" style="cursor:pointer"><b style="flex:0 0 28px;font-size:15px;color:#d9b25b">' + x.sira + '</b><div class="pp">' + portreH(x.kad, x.renk, 36) + '</div><div class="o"><b>' + esc(x.ad) + '</b><small>' + esc(x.il || '') + (x.kisa ? ' · ' + esc(x.kisa) : '') + '</small></div><b style="font-size:17px">' + x.puan + '</b></div>'; }).join('') || '<p class="gk-not">Meclis\'te henüz görevde milletvekili yok.</p>') + '</div>';
    sayfa(kad ? 'Vekil Karnesi' : 'Vekil Karnesi', h);
    tikla('[data-kad]', function (el) { var kd = el.getAttribute('data-kad'); ekranAc(function () { return karneEkrani(kd); }); });
  }

  window.tbmmMerkezAc = function () { ekranAc(merkezEkrani); };
  window.tbmmGenelGorusmeAc = function () { ekranAc(ggEkrani); };
  window.tbmmHalkBulusmalariAc = function () { ekranAc(hbEkrani); };
  window.tbmmVekilKarnesiAc = function (kad) { ekranAc(function () { return karneEkrani(kad); }); };
  window.tbmmMerkez = { git: git, ozet: ozetAl };

  /* ---------------------------------------------------------- Meclis sekmesine bağla */
  function bagla() {
    if (typeof meclisHtml !== 'function' || meclisHtml._tm) return false;
    try { if (typeof MECLIS_SEKME !== 'undefined' && !MECLIS_SEKME.some(function (x) { return x[0] === 'calisma'; })) MECLIS_SEKME.splice(1, 0, ['calisma', 'Çalışmalar']); } catch (_) {}
    var eski = meclisHtml;
    var yeni = async function () {
      css();
      var o = null; try { o = await ozetAl(); } catch (_) {}
      var bant = o ? canliKartHtml(o) : '';
      if (typeof D !== 'undefined' && D && D.meclisSekme === 'calisma') {
        var L = (typeof MECLIS_SEKME !== 'undefined' ? MECLIS_SEKME : [['calisma', 'Çalışmalar']]);
        var alt = '<div class="segment mc-seg">' + L.map(function (x) { return '<button class="' + (x[0] === 'calisma' ? 'aktif' : '') + '" onclick="meclisSekmeAc(\'' + x[0] + '\')">' + x[1] + '</button>'; }).join('') + '</div>';
        setTimeout(function () { var ic = $1('#icerik'); if (ic) izgaraBagla(ic); }, 0);
        return '<div class="tm">' + bant + '</div>' + alt + '<div class="tm">' + izgaraHtml(o) + '</div>';
      }
      var h = await eski.apply(this, arguments);
      return '<div class="tm">' + bant + '</div>' + h;
    };
    yeni._tm = true;
    try { meclisHtml = yeni; } catch (_) {}
    window.meclisHtml = yeni;
    return true;
  }
  if (!bagla()) setTimeout(bagla, 1200);
  function aramaEkle() {
    var ind = window.SO_MENU_ARAMA_INDEKSI; if (!ind) return false;
    var hedef = ind.siyaset || ind.meclis || ind.gundem; if (!hedef) return false;
    if (!hedef.some(function (x) { return x[1] === 'Genel Kurul Salonu'; })) {
      hedef.unshift(['🏛️', 'Genel Kurul Salonu', 'Canlı TBMM Genel Kurulu: söz iste, oy ver, tutanağı izle', 'tbmmSalonAc()', 'genel kurul meclis tbmm birleşim kürsü söz oylama yoklama tutanak canlı']);
      hedef.unshift(['📜', 'Meclis Çalışmaları', 'Komisyonlar, soru önergesi, genel görüşme, Meclis araştırması, dilekçe, halk buluşması, vekil karnesi', 'tbmmMerkezAc()', 'komisyon soru önergesi genel görüşme meclis araştırması gensoru dilekçe halk buluşması vekil karnesi']);
    }
    return true;
  }
  if (!aramaEkle()) setTimeout(aramaEkle, 1600);
})();
