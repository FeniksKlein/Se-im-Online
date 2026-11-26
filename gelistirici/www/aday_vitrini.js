/* =====================================================================
   ADAY VİTRİNİ + ADAY TANITIM LANSMANI (27.11.2026)
   İstek (Ercan): "Partilerin milletvekili adaylarını lanse edebilecekleri bir ekran/menü/harita: hangi ilde kim aday,
   kaçıncı sıradan. Bir de partiler aday tanıtım lansmanı yapabilsin."
   Sunucu: sql/zz_20261127_aday_vitrini_lansman.sql
     aday_vitrini, aday_vitrini_il, aday_vitrini_ara,
     aday_lansman_hazirlik, aday_lansman_duzenle, aday_lansman_iptal,
     aday_lansmanlari, aday_lansman_detay, aday_lansman_katil, aday_lansman_alkis, aday_lansman_mesaj_yaz,
     aday_lansman_kaldir, aday_lansman_mesaj_sil (İçerik Masası)
   Ekranlar: adayVitriniAc() (harita + partiler + lansmanlar + arama), adayVitriniIl(id) (il il listeler),
             adayLansmanAc(id) (canlı salon: alkış + destek mesajı), adayLansmanDuzenleAc() (GB / yetkili GBY).
   Girişler: Partiler ekranı kartı, Türkiye haritası, Gündem › Sıradaki seçim panosu altı, Menü (Siyaset) ve menü araması,
             bildirimlerden "Aday Vitrini'ne git". Eski sunucuda RPC yoksa kartlar eklenmez, ekran hata metni gösterir.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_ADAY_VITRINI_V1) return;
  window.SO_ADAY_VITRINI_V1 = true;

  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var simdiMs = function () { try { return typeof simdi === 'function' ? simdi() : Date.now(); } catch (_) { return Date.now(); } };
  var zaman = function (t) { try { return typeof tarihSaat === 'function' ? tarihSaat(t) : new Date(t).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }); } catch (_) { return ''; } };
  var saat = function (t) { try { return typeof saatYaz === 'function' ? saatYaz(t) : new Date(t).toLocaleTimeString('tr-TR', { timeZone: 'Europe/Istanbul', hour: '2-digit', minute: '2-digit' }); } catch (_) { return ''; } };
  var sure = function (ms) {
    if (ms <= 0) return 'şimdi';
    var dk = Math.round(ms / 60000), g = Math.floor(dk / 1440), s = Math.floor((dk % 1440) / 60), d = dk % 60;
    return g > 0 ? g + ' gün ' + s + ' sa' : s > 0 ? s + ' sa ' + d + ' dk' : d + ' dk';
  };
  var tl = function (n) { return Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' ₺'; };
  var rpc = function (ad, a) { return API.rpc(ad, a || {}); };
  var ac = function (fn) { if (typeof ekranAc === 'function') ekranAc(fn); else fn(); };
  var bildir = function (m, h) { try { toast(m, h); } catch (_) {} };
  var ic = function () { return document.getElementById('icerik'); };
  var amb = function (p, boy) {
    try { if (typeof amblemKutu === 'function' && p) return amblemKutu(p, boy || 34); } catch (_) {}
    return '<span class="av-nok" style="background:' + esc((p && p.renk) || '#666') + '"></span>';
  };
  var por = function (kad, renk) { try { return typeof portre === 'function' ? portre(kad, renk) : ''; } catch (_) { return ''; } };
  var kartAc = function (kad) { try { if (kad && typeof oyuncuKart === 'function') oyuncuKart(kad); } catch (_) {} };
  var YON = { onsecim: 'Ön seçim', atama: 'Genel Başkan ataması' };

  var C = { v: null, at: 0, mod: 'yogunluk', parti: null, canliTimer: null, sonLansman: null };

  function css() {
    if (document.getElementById('av-css')) return;
    var s = document.createElement('style'); s.id = 'av-css';
    s.textContent = [
      '.av-ust{position:relative;overflow:hidden;border-radius:18px;padding:16px;background:linear-gradient(135deg,#1d2754 0%,#2a1f4d 55%,#3a1c38 100%);border:1px solid rgba(164,184,255,.18)}',
      '.av-ust h2{font-size:20px;font-weight:900;margin:0 0 4px;line-height:1.25}',
      '.av-ust p{font-size:14px;line-height:1.5;margin:4px 0;opacity:.92}',
      '.av-cip{display:inline-flex;align-items:center;gap:6px;padding:4px 10px;border-radius:999px;font-size:13px;font-weight:800;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.16);white-space:nowrap}',
      '.av-cip.canli{background:#d93a3a;border-color:#ff7a7a;color:#fff}.av-cip.canli:before{content:"";width:8px;height:8px;border-radius:50%;background:#fff;animation:avNabiz 1.2s infinite}',
      '.av-cip.altin{color:#f2c46d;border-color:#7a5d22}.av-cip.yesil{color:#7fe0a6;border-color:#2c6e4a}.av-cip.gri{opacity:.75}',
      '@keyframes avNabiz{0%,100%{opacity:1}50%{opacity:.25}}',
      '.av-adim{display:grid;grid-template-columns:repeat(4,1fr);gap:4px;margin-top:12px}',
      '.av-adim div{font-size:12px;line-height:1.3;padding:7px 6px;border-radius:10px;background:rgba(255,255,255,.06);text-align:center;min-width:0;overflow-wrap:anywhere}',
      '.av-adim div.tamam{background:rgba(127,224,166,.14);color:#a9f0c6}.av-adim div.su{background:#f2c46d;color:#2a1d05;font-weight:800}',
      '.av-adim b{display:block;font-size:12.5px}',
      '.av-seg{display:flex;gap:6px;overflow-x:auto;padding:2px 0 6px;-webkit-overflow-scrolling:touch;scrollbar-width:none}.av-seg::-webkit-scrollbar{display:none}',
      '.av-seg button{flex:none;min-height:40px;padding:6px 12px;border-radius:999px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;font-size:14px;font-weight:700;display:inline-flex;align-items:center;gap:6px}',
      '.av-seg button.aktif{background:#f2c46d;color:#2a1d05;border-color:#f2c46d}',
      '.av-nok{display:inline-block;width:11px;height:11px;border-radius:50%;flex:none}',
      '.av-harita{position:relative;margin-top:6px}.av-harita svg{width:100%;height:auto;display:block}',
      '.av-harita path{cursor:pointer;transition:fill-opacity .2s}.av-harita path:active{fill-opacity:1!important}',
      '.av-lejant{display:flex;flex-wrap:wrap;gap:6px 12px;font-size:13px;margin-top:6px;opacity:.9}',
      '.av-lejant span{display:inline-flex;align-items:center;gap:5px}',
      '.av-ara{width:100%;min-width:0;box-sizing:border-box;font-size:16px;min-height:48px;padding:10px 14px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;color-scheme:dark}',
      '.av-satir{display:flex;align-items:center;gap:10px;width:100%;text-align:left;padding:10px 4px;border:0;border-bottom:1px solid var(--line2,#2a3045);background:none;color:inherit;font:inherit;min-height:52px}',
      '.av-satir:last-child{border-bottom:0}.av-satir .orta{flex:1;min-width:0}.av-satir b{font-size:15px;overflow-wrap:anywhere}.av-satir small{display:block;font-size:13px;opacity:.78;margin-top:2px;line-height:1.4}',
      '.av-bar{display:flex;height:7px;border-radius:5px;overflow:hidden;background:rgba(255,255,255,.07);margin-top:5px}.av-bar i{display:block;height:100%}',
      '.av-l-serit{display:flex;gap:10px;overflow-x:auto;padding:2px 0 8px;scroll-snap-type:x mandatory;-webkit-overflow-scrolling:touch}',
      '.av-lk{flex:none;width:250px;max-width:82vw;scroll-snap-align:start;text-align:left;border-radius:16px;padding:12px;border:1px solid rgba(255,255,255,.12);color:#fff;font:inherit;background:var(--lk,#333);position:relative;overflow:hidden;min-height:132px}',
      '.av-lk:after{content:"";position:absolute;inset:0;background:linear-gradient(160deg,rgba(0,0,0,.05),rgba(0,0,0,.55));pointer-events:none}',
      '.av-lk>*{position:relative;z-index:1}.av-lk b{display:block;font-size:16px;line-height:1.3;margin:8px 0 4px;overflow-wrap:anywhere}.av-lk small{display:block;font-size:13px;opacity:.92;line-height:1.4}',
      '.av-liste-kart{border-left:4px solid var(--pr,#888)}',
      '.av-liste-bas{display:flex;align-items:center;gap:10px;margin-bottom:6px}.av-liste-bas .orta{flex:1;min-width:0}.av-liste-bas h3{font-size:17px;font-weight:800;margin:0;overflow-wrap:anywhere}',
      '.av-sira{flex:none;width:36px;height:36px;border-radius:10px;display:grid;place-items:center;font-weight:900;font-size:15px;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.14)}',
      '.av-sira.ilk{background:#f2c46d;color:#2a1d05;border-color:#f2c46d}.av-sira.aa{font-size:11px;font-weight:800}',
      '.av-por{flex:none;width:40px;height:40px;border-radius:50%;overflow:hidden;display:grid;place-items:center}.av-por svg{width:40px;height:40px}',
      '.av-vaat{font-size:13.5px;line-height:1.45;opacity:.85;margin-top:3px;overflow-wrap:anywhere;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}',
      '.av-sahne{border-radius:20px;padding:18px 16px;color:#fff;background:var(--lk,#333);position:relative;overflow:hidden}',
      '.av-sahne:after{content:"";position:absolute;inset:0;background:radial-gradient(120% 80% at 50% 0%,rgba(255,255,255,.18),transparent 60%),linear-gradient(180deg,rgba(0,0,0,.1),rgba(0,0,0,.6));pointer-events:none}',
      '.av-sahne>*{position:relative;z-index:1}.av-sahne h2{font-size:22px;font-weight:900;line-height:1.25;margin:10px 0 6px;overflow-wrap:anywhere}',
      '.av-sayac{font-size:28px;font-weight:900;letter-spacing:.5px;margin-top:8px}',
      '.av-istat{display:flex;gap:8px;margin-top:12px;flex-wrap:wrap}.av-istat div{flex:1;min-width:84px;background:rgba(0,0,0,.25);border-radius:12px;padding:8px;text-align:center}.av-istat b{display:block;font-size:19px}.av-istat small{font-size:12px;opacity:.85}',
      '.av-aday-izgara{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:10px}',
      '.av-aday{border-radius:14px;padding:12px 10px;background:var(--bg,#151a28);border:1px solid var(--line2,#2a3045);text-align:center;display:flex;flex-direction:column;align-items:center;gap:4px;min-width:0}',
      '.av-aday .av-por{width:56px;height:56px}.av-aday .av-por svg{width:56px;height:56px}',
      '.av-aday b{font-size:15px;line-height:1.3;overflow-wrap:anywhere}.av-aday small{font-size:12.5px;opacity:.8;line-height:1.35;overflow-wrap:anywhere}',
      '.av-alkis{width:100%;min-height:44px;margin-top:6px;border-radius:12px;border:1px solid #7a5d22;background:rgba(242,196,109,.12);color:#f2c46d;font:inherit;font-weight:800;font-size:14px}',
      '.av-alkis.oldu{background:#f2c46d;color:#2a1d05}.av-alkis:disabled{opacity:.6}',
      '.av-mesajlar{max-height:360px;overflow-y:auto;display:flex;flex-direction:column;gap:8px;padding:2px}',
      '.av-msj{background:var(--bg,#151a28);border:1px solid var(--line2,#2a3045);border-radius:12px;padding:8px 10px;font-size:14.5px;line-height:1.45;overflow-wrap:anywhere}',
      '.av-msj .kim{display:flex;align-items:center;gap:6px;font-size:13px;font-weight:800;margin-bottom:2px}.av-msj .kim button{background:none;border:0;color:inherit;font:inherit;padding:0;text-align:left;white-space:nowrap}',
      '.av-msj .kim button[data-kad]{flex:1;min-width:0;white-space:normal;overflow-wrap:anywhere}.av-msj .kim .kucuk{white-space:nowrap;flex:none}',
      '.av-amb-beyaz{display:inline-grid;place-items:center;width:38px;height:38px;border-radius:50%;background:rgba(255,255,255,.92);flex:none}.av-amb-beyaz .amb{background:transparent!important;width:30px!important;height:30px!important}',
      '.av-form label{display:block;font-size:15px;font-weight:700;margin:12px 0 6px}',
      '.av-form input,.av-form select,.av-form textarea{display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;min-height:48px;padding:10px 12px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;color-scheme:dark;font-family:inherit}',
      '.av-form textarea{min-height:120px;line-height:1.5;resize:vertical}.av-form option{background:#151a28;color:#eef1f8}',
      '.av-form .sayac{font-size:13px;opacity:.75;text-align:right;margin-top:3px}',
      '.av-hizli{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}.av-hizli button{min-height:40px;padding:6px 12px;border-radius:999px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;font-size:14px}',
      '.av-sec{display:flex;align-items:center;gap:10px;width:100%;min-height:52px;padding:8px 10px;margin:6px 0;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;text-align:left}',
      '.av-sec.secili{border-color:#f2c46d;background:rgba(242,196,109,.1)}.av-sec .orta{flex:1;min-width:0}.av-sec b{font-size:15px;overflow-wrap:anywhere}.av-sec small{display:block;font-size:13px;opacity:.78}',
      '.av-sec .no{flex:none;width:30px;height:30px;border-radius:50%;display:grid;place-items:center;font-weight:900;border:2px solid var(--line2,#2a3045)}.av-sec.secili .no{background:#f2c46d;color:#2a1d05;border-color:#f2c46d}',
      '.av-not{margin:-2px 0 8px 40px;width:calc(100% - 40px)!important}',
      '.av-uyari{padding:10px 12px;border-radius:12px;background:rgba(242,196,109,.12);border:1px solid #7a5d22;font-size:14px;line-height:1.5;margin:8px 0}',
      '.av-ozet{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid var(--line2,#2a3045);font-size:15px;flex-wrap:wrap}.av-ozet:last-child{border-bottom:0}',
      '.av-giris{display:flex;align-items:center;gap:12px;width:100%;text-align:left;min-height:60px;padding:12px 14px;border-radius:16px;border:1px solid rgba(242,196,109,.35);background:linear-gradient(135deg,rgba(242,196,109,.14),rgba(93,71,214,.16));color:inherit;font:inherit;margin:10px 0}',
      '.av-giris .orta{flex:1;min-width:0}.av-giris b{font-size:16px;display:block}.av-giris small{display:block;font-size:13px;opacity:.85;line-height:1.4;margin-top:2px}.av-giris .ok{font-size:22px;opacity:.7}',
      '.av-ik{flex:none;width:42px;height:42px;border-radius:12px;display:grid;place-items:center;background:#f2c46d;color:#2a1d05}.av-ik svg{width:24px;height:24px}',
      '@media (prefers-reduced-motion:reduce){.av-cip.canli:before{animation:none}}'
    ].join('');
    document.head.appendChild(s);
  }

  var IKON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 10h16v10H4z"/><path d="M9 10V6a3 3 0 0 1 6 0v4"/><path d="M12 14v2"/></svg>';
  var IKON_SAHNE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 20h18"/><path d="M5 20v-6h14v6"/><path d="M12 4v6"/><path d="M8 7l4-3 4 3"/></svg>';

  function vitrinGetir(zorla) {
    if (!zorla && C.v && Date.now() - C.at < 45000) return Promise.resolve(C.v);
    return API.rpc('aday_vitrini', {}).then(function (v) { C.v = v; C.at = Date.now(); return v; });
  }

  /* ------------------------------------------------ yardımcı görünümler */
  function durumCip(l) {
    if (l.canli) return '<span class="av-cip canli">CANLI</span>';
    if (l.bitti) return '<span class="av-cip gri">Tamamlandı</span>';
    return '<span class="av-cip altin">' + esc(sure(new Date(l.bas).getTime() - simdiMs())) + ' sonra</span>';
  }
  function lansmanKart(l) {
    var p = l.parti || {};
    return '<button type="button" class="av-lk" style="--lk:' + esc(p.renk || '#444') + '" onclick="adayLansmanAc(' + (+l.id) + ')">' +
      '<div style="display:flex;justify-content:space-between;gap:6px;align-items:center"><span class="av-cip">' + esc(p.kisa || '') + ' · ' + esc(l.il || '') + '</span>' + durumCip(l) + '</div>' +
      '<b>' + esc(l.baslik) + '</b>' +
      '<small>' + esc(zaman(l.bas)) + '–' + esc(saat(l.bit)) + ' · ' + (+l.aday_sayisi || 0) + ' aday</small>' +
      '<small>' + (l.canli || l.bitti ? (+l.katilim || 0) + ' katılımcı' : (+l.hatirlat || 0) + ' kişi bekliyor') + '</small></button>';
  }
  function asamaAdimlari(v) {
    var a = v.asama, sira = ['basvuru', 'onsecim', 'kesin', 'sandik'], ad = { basvuru: 'Aday adaylığı', onsecim: 'Ön seçim', kesin: 'Kesin liste', sandik: 'Sandık' };
    var idx = a === 'hazirlik' ? -1 : a === 'sayim' ? 1.5 : a === 'sonuc' ? 4 : sira.indexOf(a);
    var tk = v.takvim || {}, z = { basvuru: tk.basvuru_bas, onsecim: tk.onsecim_bas, kesin: tk.onsecim_bit, sandik: tk.secim_bas };
    return '<div class="av-adim">' + sira.map(function (k, i) {
      var cls = i < idx ? 'tamam' : (i === idx ? 'su' : '');
      return '<div class="' + cls + '"><b>' + ad[k] + '</b>' + (z[k] ? esc(zaman(z[k])) : '') + '</div>';
    }).join('') + '</div>';
  }

  /* ------------------------------------------------ VİTRİN (harita) */
  function ekran() {
    css(); durdur();
    if (typeof iskelet === 'function') iskelet('Aday Vitrini', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    vitrinGetir(true).then(ciz).catch(function (err) { var x = ic(); if (x) x.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>'; });
  }

  function haritaSvg(v) {
    var H = (window.VERI || (typeof VERI !== 'undefined' ? VERI : {})).harita;
    if (!H || !H.il) return '';
    var il = {}; (v.iller || []).forEach(function (x) { il[x.id] = x; });
    var pr = {}; (v.partiler || []).forEach(function (p) { pr[p.id] = p; });
    var renk = function (id) {
      var x = il[id]; if (!x) return { f: '#2a2f45', o: 1 };
      if (C.parti) {
        var c = (x.p || {})[C.parti] || 0, p = pr[C.parti] || {};
        return c ? { f: p.renk || '#888', o: .35 + .65 * Math.min(1, c / Math.max(1, Math.min(x.k, 12))) } : { f: '#2a2f45', o: 1 };
      }
      if (C.mod === 'lider') {
        var en = null, n = 0; Object.keys(x.p || {}).forEach(function (k) { if (x.p[k] > n) { n = x.p[k]; en = k; } });
        return en ? { f: (pr[en] || {}).renk || '#888', o: .9 } : { f: '#2a2f45', o: 1 };
      }
      if (!x.n) return { f: '#2a2f45', o: 1 };
      return { f: '#f2c46d', o: .18 + .82 * Math.min(1, x.n / Math.max(1, x.k)) };
    };
    var noktalar = (v.iller || []).filter(function (x) { return x.l > 0 && H.il[x.id] && H.il[x.id].x != null; }).map(function (x) {
      var p = H.il[x.id]; return '<circle cx="' + p.x + '" cy="' + p.y + '" r="11" fill="#ff5a5a" stroke="#fff" stroke-width="3" pointer-events="none"><title>' + esc(x.ad) + ' · lansman</title></circle>';
    }).join('');
    return '<svg viewBox="0 0 ' + H.w + ' ' + H.h + '" role="img" aria-label="Milletvekili adayları haritası"><g stroke="#0b0f1f" stroke-width="1.3">' +
      Object.keys(H.il).map(function (id) {
        var r = renk(+id), x = il[+id] || {};
        return '<path d="' + H.il[id].d + '" fill="' + esc(r.f) + '" fill-opacity="' + r.o.toFixed(2) + '" onclick="adayVitriniIl(' + (+id) + ')"><title>' + esc(x.ad || '') + ' · ' + (x.n || 0) + ' aday / ' + (x.k || 0) + ' sandalye</title></path>';
      }).join('') + '</g>' + noktalar + '</svg>';
  }

  function ciz(v) {
    var x = ic(); if (!x) return;
    var pr = {}; (v.partiler || []).forEach(function (p) { pr[p.id] = p; });
    var toplam = (v.iller || []).reduce(function (t, i) { return t + (i.n || 0); }, 0);
    var canli = (v.lansmanlar || []).filter(function (l) { return l.canli; }).length;
    var seg = '<div class="av-seg" role="tablist">' +
      '<button type="button" class="' + (!C.parti && C.mod === 'yogunluk' ? 'aktif' : '') + '" data-m="yogunluk">Aday yoğunluğu</button>' +
      '<button type="button" class="' + (!C.parti && C.mod === 'lider' ? 'aktif' : '') + '" data-m="lider">En çok aday</button>' +
      (v.partiler || []).filter(function (p) { return p.aday > 0; }).map(function (p) {
        return '<button type="button" class="' + (C.parti === String(p.id) ? 'aktif' : '') + '" data-p="' + p.id + '"><span class="av-nok" style="background:' + esc(p.renk) + '"></span>' + esc(p.kisa) + '</button>';
      }).join('') + '</div>';
    var lejant = C.parti ? '<span><span class="av-nok" style="background:' + esc((pr[C.parti] || {}).renk) + '"></span>' + esc((pr[C.parti] || {}).kisa) + ' adayı olan iller (koyu = liste dolu)</span>'
      : C.mod === 'lider' ? (v.partiler || []).filter(function (p) { return p.aday > 0; }).map(function (p) { return '<span><span class="av-nok" style="background:' + esc(p.renk) + '"></span>' + esc(p.kisa) + '</span>'; }).join('')
      : '<span><span class="av-nok" style="background:#f2c46d"></span>Koyu = sandalye başına çok aday</span>';
    lejant += '<span><span class="av-nok" style="background:#ff5a5a"></span>Lansman var</span>';
    var iller = (v.iller || []).slice().sort(function (a, b) { return (b.n || 0) - (a.n || 0) || b.k - a.k; });
    var ilSatir = function (i) {
      var parcalar = Object.keys(i.p || {}).map(function (k) { return '<i style="width:' + (100 * i.p[k] / Math.max(1, i.n)).toFixed(1) + '%;background:' + esc((pr[k] || {}).renk || '#888') + '"></i>'; }).join('');
      return '<button type="button" class="av-satir" onclick="adayVitriniIl(' + i.id + ')"><div class="orta"><b>' + esc(i.ad) + '</b>' +
        '<small>' + i.k + ' sandalye · ' + (i.n || 0) + ' parti adayı' + (i.b ? ' · ' + i.b + ' bağımsız' : '') + (i.l ? ' · ' + i.l + ' lansman' : '') + '</small>' +
        (i.n ? '<div class="av-bar">' + parcalar + '</div>' : '') + '</div><span aria-hidden="true">›</span></button>';
    };
    var lansmanlar = v.lansmanlar || [];
    x.innerHTML =
      '<div class="av-ust"><div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center"><span class="av-cip altin">Genel Seçim' + (v.takvim && v.takvim.secim_bas ? ' · ' + esc(zaman(v.takvim.secim_bas)) : '') + '</span>' +
      (v.kesin ? '<span class="av-cip yesil">Listeler kesin</span>' : '<span class="av-cip">Listeler kesinleşmedi</span>') + (canli ? '<span class="av-cip canli">' + canli + ' lansman</span>' : '') + '</div>' +
      '<h2>' + esc(toplam) + ' parti adayı · ' + esc(v.toplam_kontenjan || 600) + ' sandalye</h2><p>' + esc(v.asama_yazi || '') + '</p>' + asamaAdimlari(v) + '</div>' +
      ((v.ben && v.ben.lansman_yetkili) ? '<button type="button" class="av-giris" onclick="adayLansmanDuzenleAc()"><span class="av-ik">' + IKON_SAHNE + '</span><span class="orta"><b>Aday lansmanı düzenle</b><small>Adaylarını sahneye çıkar: il ya da Türkiye geneli, canlı salon, alkış ve haber.</small></span><span class="ok">›</span></button>' : '') +
      (lansmanlar.length ? '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 8px">Aday lansmanları</h2><div class="av-l-serit">' + lansmanlar.slice(0, 12).map(lansmanKart).join('') + '</div></div>' : '') +
      '<div class="kart"><label for="avAra" class="kucuk" style="display:block;margin-bottom:6px;font-size:15px;font-weight:700">Aday ara</label><input id="avAra" class="av-ara" type="search" enterkeyhint="search" autocomplete="off" placeholder="Ad soyad ya da kullanıcı adı"><div id="avAraSonuc"></div></div>' +
      '<div class="kart" style="padding:12px">' + seg + '<div class="av-harita">' + haritaSvg(v) + '</div><div class="av-lejant">' + lejant + '</div><p class="kucuk" style="margin-top:6px">Bir ile dokun: o ildeki bütün partilerin listeleri, sıraları ve lansmanları.</p></div>' +
      '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 6px">Partiler</h2>' + (v.partiler || []).map(function (p) {
        return '<button type="button" class="av-satir" data-p="' + p.id + '">' + amb(p, 36) + '<div class="orta"><b>' + esc(p.ad) + '</b><small>' + (p.aday || 0) + ' aday · ' + (p.il || 0) + ' il · ' + esc(YON[p.yontem] || '') + '</small></div><span aria-hidden="true">›</span></button>';
      }).join('') + '</div>' +
      '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 6px">81 il</h2>' + iller.map(ilSatir).join('') + '</div>';
    x.querySelectorAll('.av-seg button').forEach(function (b) { b.onclick = function () {
      if (b.dataset.p) { C.parti = C.parti === b.dataset.p ? null : b.dataset.p; } else { C.parti = null; C.mod = b.dataset.m; }
      ciz(C.v || v);
    }; });
    x.querySelectorAll('.av-satir[data-p]').forEach(function (b) { b.onclick = function () { C.parti = b.dataset.p; ciz(C.v || v); var h = x.querySelector('.av-harita'); if (h && h.scrollIntoView) h.scrollIntoView({ block: 'center' }); }; });
    var ara = document.getElementById('avAra'), zm = null;
    if (ara) ara.oninput = function () {
      clearTimeout(zm); var q = ara.value.trim(), out = document.getElementById('avAraSonuc');
      if (q.length < 2) { out.innerHTML = ''; return; }
      zm = setTimeout(function () {
        API.rpc('aday_vitrini_ara', { p_ara: q }).then(function (r) {
          if (ara.value.trim() !== q) return;
          out.innerHTML = (r || []).length ? r.map(function (a) {
            return '<button type="button" class="av-satir" onclick="adayVitriniIl(' + (+a.il_id) + ')"><span class="av-nok" style="background:' + esc((a.parti || {}).renk || '#777') + '"></span><div class="orta"><b>' + esc(a.ad) + '</b><small>' +
              esc(a.il) + ' · ' + esc(a.parti ? a.parti.kisa : 'Bağımsız') + (a.sira ? ' · ' + a.sira + '. sıra' : (a.parti ? ' · aday adayı' : '')) + '</small></div><span aria-hidden="true">›</span></button>';
          }).join('') : '<div class="kucuk" style="padding:8px 0">Bu isimde aday bulunamadı.</div>';
        }).catch(function (err) { out.innerHTML = '<div class="kucuk">' + esc(hata(err)) + '</div>'; });
      }, 350);
    };
  }

  /* ------------------------------------------------ İL */
  function ilEkrani(id) {
    css(); durdur();
    var ad = ''; try { var b = (window.VERI || VERI).iller.find(function (x) { return x.id === id; }); ad = b ? b.ad : ''; } catch (_) {}
    if (typeof iskelet === 'function') iskelet(ad ? ad + ' adayları' : 'İl adayları', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    API.rpc('aday_vitrini_il', { p_il: id }).then(ilCiz).catch(function (err) { var x = ic(); if (x) x.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>'; });
  }

  function adaySatir(a, p, kesin, i) {
    var siraHtml = kesin && a.sira ? '<span class="av-sira' + (a.sira === 1 ? ' ilk' : '') + '">' + a.sira + '</span>' : '<span class="av-sira aa" title="Aday adayı">AA</span>';
    var ek = [];
    if (a.gb) ek.push('Genel Başkan');
    if (a.oy != null) ek.push(a.oy + ' ön seçim oyu');
    if (a.lansman) ek.push('lansmanda tanıtıldı' + (a.alkis ? ' · ' + a.alkis + ' alkış' : ''));
    return '<button type="button" class="av-satir" data-kad="' + esc(a.kad) + '">' + siraHtml +
      '<span class="av-por">' + por(a.kad, p.renk) + '</span><div class="orta"><b>' + esc(a.ad) + '</b>' +
      (ek.length ? '<small>' + esc(ek.join(' · ')) + '</small>' : '') + (a.vaat ? '<div class="av-vaat">“' + esc(a.vaat) + '”</div>' : '') + '</div></button>';
  }

  function ilCiz(d) {
    var x = ic(); if (!x) return;
    var il = d.il || {}, kesin = !!d.kesin;
    var listeler = (d.listeler || []).map(function (L) {
      var p = L.parti || {}, n = (L.adaylar || []).length;
      return '<div class="kart av-liste-kart" style="--pr:' + esc(p.renk) + '"><div class="av-liste-bas">' + amb(p, 40) + '<div class="orta"><h3>' + esc(p.ad) + '</h3>' +
        '<div class="kucuk">' + (kesin ? n + ' / ' + il.kontenjan + ' sıralı aday' : n + ' aday adayı') + ' · ' + esc(YON[L.yontem] || '') + '</div></div></div>' +
        (!kesin && L.yontem === 'atama' ? '<p class="kucuk" style="margin:0 0 4px">Bu partide sırayı Genel Başkan belirler; liste ön seçim süresi bitince kesinleşir.</p>' : '') +
        (L.adaylar || []).map(function (a, i) { return adaySatir(a, p, kesin, i); }).join('') + '</div>';
    }).join('');
    var bag = (d.bagimsizlar || []).length ? '<div class="kart av-liste-kart" style="--pr:#8a93ad"><div class="av-liste-bas"><div class="orta"><h3>Bağımsız adaylar</h3><div class="kucuk">' + d.bagimsizlar.length + ' aday</div></div></div>' +
      d.bagimsizlar.map(function (a) { return '<button type="button" class="av-satir" data-kad="' + esc(a.kad) + '"><span class="av-sira aa">B</span><span class="av-por">' + por(a.kad, '#8a93ad') + '</span><div class="orta"><b>' + esc(a.ad) + '</b>' + (a.vaat ? '<div class="av-vaat">“' + esc(a.vaat) + '”</div>' : '') + '</div></button>'; }).join('') + '</div>' : '';
    var bos = (d.bos_listeli_partiler || []).length ? '<p class="kucuk">Bu ilde henüz ' + (kesin ? 'listesi olmayan' : 'aday adayı olmayan') + ' partiler: ' + d.bos_listeli_partiler.map(function (p) { return esc(p.kisa); }).join(', ') + '.</p>' : '';
    var lns = (d.lansmanlar || []).length ? '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 8px">Bu ildeki lansmanlar</h2><div class="av-l-serit">' + d.lansmanlar.map(lansmanKart).join('') + '</div></div>' : '';
    x.innerHTML =
      '<div class="av-ust"><div style="display:flex;gap:6px;flex-wrap:wrap"><span class="av-cip altin">' + esc(il.kontenjan) + ' milletvekili</span>' + (d.benim_ilim ? '<span class="av-cip yesil">Senin ilin</span>' : '') +
      (kesin ? '<span class="av-cip yesil">Listeler kesin</span>' : '<span class="av-cip">Aday adayları</span>') + '</div><h2>' + esc(il.ad) + '</h2><p>' + esc(d.asama_yazi || '') + '</p>' +
      '<p class="kucuk" style="opacity:.85">' + (kesin ? 'Sandalyeler seçimde D\'Hondt usulüyle bu sıralara göre dağıtılır; 1. sıradaki aday listenin başıdır.' : 'Ön seçim sonuçlanınca listeler sıra numarasıyla görünür. Şimdilik başvuranları görüyorsun (AA = aday adayı).') + '</p></div>' +
      lns + (listeler || '<div class="kart"><div class="bos">Bu ilde henüz parti adayı yok.</div></div>') + bag + bos;
    x.querySelectorAll('[data-kad]').forEach(function (b) { b.onclick = function () { kartAc(b.dataset.kad); }; });
  }

  /* ------------------------------------------------ LANSMAN SALONU */
  function durdur() { if (C.canliTimer) { clearInterval(C.canliTimer); C.canliTimer = null; } }

  function lansmanEkrani(id) {
    css(); durdur();
    if (typeof iskelet === 'function') iskelet('Aday lansmanı', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    API.rpc('aday_lansman_detay', { p_id: id }).then(function (l) { lansmanCiz(l); canliBaslat(l); })
      .catch(function (err) { var x = ic(); if (x) x.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>'; });
  }

  function adaylarHtml(l) {
    var p = l.parti || {};
    return (l.adaylar || []).map(function (a) {
      var dugme = l.canli ? '<button type="button" class="av-alkis' + (a.alkisladim ? ' oldu' : '') + '" data-alkis="' + a.aday_id + '"' + (a.alkisladim ? ' disabled' : '') + '>' + (a.alkisladim ? 'Alkışladın' : 'Alkışla') + ' · ' + (+a.alkis || 0) + '</button>'
        : '<small>' + (+a.alkis || 0) + ' alkış</small>';
      return '<div class="av-aday"><span class="av-por">' + por(a.kad, p.renk) + '</span><b><button type="button" data-kad="' + esc(a.kad) + '" style="background:none;border:0;color:inherit;font:inherit;font-weight:800;padding:0">' + esc(a.ad) + '</button></b>' +
        '<small>' + esc(a.il) + (a.sira ? ' · ' + a.sira + '. sıra' : '') + '</small>' + (a.not ? '<small style="opacity:.95">“' + esc(a.not) + '”</small>' : '') + dugme + '</div>';
    }).join('');
  }
  function mesajlarHtml(l) {
    var ms = l.mesajlar || [];
    if (!ms.length) return '<div class="kucuk" style="padding:6px 0">' + (l.canli ? 'İlk destek mesajını sen yaz.' : 'Mesaj yok.') + '</div>';
    return ms.map(function (m) {
      return '<div class="av-msj"><div class="kim"><span class="av-nok" style="background:' + esc((m.parti || {}).renk || '#777') + '"></span><button type="button" data-kad="' + esc(m.kad) + '">' + esc(m.ad) + '</button>' +
        (m.parti ? '<span class="kucuk" style="font-weight:600;opacity:.7">' + esc(m.parti.kisa) + '</span>' : '') + '<span class="kucuk" style="margin-left:auto;font-weight:500;opacity:.6">' + esc(saat(m.zaman)) + '</span>' +
        (l.mod ? '<button type="button" data-sil="' + m.id + '" style="color:#ff8a8a;margin-left:6px">Sil</button>' : '') + '</div>' + esc(m.metin) + '</div>';
    }).join('');
  }
  function sayacMetni(l) {
    var t = simdiMs();
    if (l.durum === 'iptal') return 'İptal edildi';
    if (l.durum === 'kaldirildi') return 'Yönetim kaldırdı';
    if (l.bitti || t >= new Date(l.bit).getTime()) return 'Lansman tamamlandı';
    if (l.canli || t >= new Date(l.bas).getTime()) return 'Bitişe ' + sure(new Date(l.bit).getTime() - t);
    return 'Başlamasına ' + sure(new Date(l.bas).getTime() - t);
  }

  function lansmanCiz(l) {
    var x = ic(); if (!x) return;
    C.sonLansman = l;
    var p = l.parti || {};
    var eylem = '';
    if (l.durum === 'planli' && !l.bitti) {
      eylem = l.canli
        ? (l.katildim ? '<div class="av-cip yesil" style="margin-top:12px">Salondasın</div>' : '<button type="button" class="btn altin" id="avKatil" style="margin-top:12px">Salona gir</button>')
        : '<button type="button" class="btn ' + (l.hatirlatiyor ? 'ikinci' : 'altin') + '" id="avKatil" style="margin-top:12px">' + (l.hatirlatiyor ? 'Hatırlatmayı kapat' : 'Başlayınca hatırlat') + '</button>';
    }
    x.innerHTML =
      '<div class="av-sahne" id="avLansman" data-id="' + (+l.id) + '" style="--lk:' + esc(p.renk || '#444') + '">' +
      '<div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center"><span class="av-amb-beyaz">' + amb(p, 30) + '</span><span class="av-cip">' + esc(p.kisa) + ' · ' + esc(l.il) + '</span>' + durumCip(l) + '</div>' +
      '<h2>' + esc(l.baslik) + '</h2><div class="kucuk" style="opacity:.92">' + esc(zaman(l.bas)) + '–' + esc(saat(l.bit)) + ' · Düzenleyen: ' + esc((l.duzenleyen || {}).ad || '') + '</div>' +
      '<div class="av-sayac" id="avSayac">' + esc(sayacMetni(l)) + '</div>' +
      '<div class="av-istat"><div><b id="avKatilim">' + (+l.katilim || 0) + '</b><small>katılımcı</small></div><div><b>' + (+l.aday_sayisi || 0) + '</b><small>aday</small></div><div><b id="avHatirlat">' + (+l.hatirlat || 0) + '</b><small>hatırlat</small></div></div>' +
      eylem + '</div>' +
      (l.durum === 'kaldirildi' ? '<div class="av-uyari">Bu lansman Oyun Yönetimi tarafından kaldırıldı' + (l.kaldir_gerekce ? ': ' + esc(l.kaldir_gerekce) : '') + '</div>' : '') +
      '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 6px">Sunuş</h2><p style="font-size:15px;line-height:1.6;white-space:pre-wrap;overflow-wrap:anywhere;margin:0">' + esc(l.metin) + '</p></div>' +
      '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 8px">Sahnedeki adaylar</h2>' + (l.canli ? '<p class="kucuk" style="margin:0 0 8px">Her adayı bir kez alkışlayabilirsin.</p>' : '') + '<div class="av-aday-izgara" id="avAdaylar">' + adaylarHtml(l) + '</div></div>' +
      '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 8px">Destek mesajları</h2><div class="av-mesajlar" id="avMesajlar">' + mesajlarHtml(l) + '</div>' +
      (l.canli ? '<div class="av-form"><label for="avMsj">Mesajın</label><textarea id="avMsj" maxlength="200" rows="2" placeholder="Adaylara destek mesajı (en çok 200 karakter)" style="min-height:72px"></textarea><div class="sayac" id="avMsjSay">0 / 200</div><div class="hata-metin" id="avMsjHata"></div><button type="button" class="btn altin" id="avMsjGonder">Gönder</button></div>' : '') + '</div>' +
      ((l.yetkili && l.durum === 'planli' && simdiMs() < new Date(l.bas).getTime()) ? '<div class="kart"><button type="button" class="btn ikinci" id="avIptal">Lansmanı iptal et (bedel kasaya iade edilir)</button></div>' : '') +
      ((l.mod && l.durum !== 'kaldirildi') ? '<div class="kart"><button type="button" class="btn ikinci" id="avKaldir" style="color:#ff8a8a">Yönetim: lansmanı kaldır</button></div>' : '');
    baglaLansman(l);
  }

  function baglaLansman(l) {
    var x = ic(); if (!x) return;
    x.querySelectorAll('[data-kad]').forEach(function (b) { b.onclick = function () { kartAc(b.dataset.kad); }; });
    x.querySelectorAll('[data-alkis]').forEach(function (b) { b.onclick = function () {
      b.disabled = true;
      API.rpc('aday_lansman_alkis', { p_id: l.id, p_aday: +b.dataset.alkis }).then(function (r) { b.classList.add('oldu'); b.textContent = 'Alkışladın · ' + (r.alkis || 0); })
        .catch(function (err) { b.disabled = false; bildir(hata(err), true); });
    }; });
    x.querySelectorAll('[data-sil]').forEach(function (b) { b.onclick = function () {
      b.disabled = true; API.rpc('aday_lansman_mesaj_sil', { p_mesaj: +b.dataset.sil }).then(function () { bildir('Mesaj silindi.'); tazele(true); }).catch(function (err) { b.disabled = false; bildir(hata(err), true); });
    }; });
    var k = document.getElementById('avKatil');
    if (k) k.onclick = function () { k.disabled = true; API.rpc('aday_lansman_katil', { p_id: l.id }).then(function (r) {
      bildir(r.katildi ? 'Salona girdin.' : r.hatirlat ? 'Lansman başlayınca bildirim alacaksın.' : 'Hatırlatma kapatıldı.'); tazele(true, true);
    }).catch(function (err) { k.disabled = false; bildir(hata(err), true); }); };
    var t = document.getElementById('avMsj'), say = document.getElementById('avMsjSay'), g = document.getElementById('avMsjGonder');
    if (t && say) t.oninput = function () { say.textContent = t.value.length + ' / 200'; };
    if (g) g.onclick = function () {
      var m = (t.value || '').trim(), he = document.getElementById('avMsjHata'); he.textContent = '';
      if (!m) { he.textContent = 'Mesaj boş olamaz.'; return; }
      g.disabled = true;
      API.rpc('aday_lansman_mesaj_yaz', { p_id: l.id, p_metin: m }).then(function () { t.value = ''; say.textContent = '0 / 200'; g.disabled = false; tazele(true); })
        .catch(function (err) { he.textContent = hata(err); g.disabled = false; });
    };
    var ip = document.getElementById('avIptal');
    if (ip) ip.onclick = function () {
      if (!confirmModal('Lansman iptal edilsin mi?', 'Bedel (' + tl((C.sonLansman || {}).bedel) + ') parti kasasına iade edilir; hatırlatma isteyenlere bildirim gider.', 'İptal et', function () {
        API.rpc('aday_lansman_iptal', { p_id: l.id }).then(function (r) { bildir('Lansman iptal edildi. ' + tl(r.iade) + ' kasaya döndü.'); C.at = 0; if (typeof geriGit === 'function') geriGit(); }).catch(function (err) { bildir(hata(err), true); });
      })) return;
    };
    var kl = document.getElementById('avKaldir');
    if (kl) kl.onclick = function () {
      var m = modal('<h3 style="font-size:19px;font-weight:800">Lansmanı kaldır</h3><p class="kucuk">Lansman vitrinden kalkar, düzenleyene ve Genel Başkana gerekçeyle bildirim gider. Bedel iade edilmez.</p>' +
        '<div class="av-form"><label for="avKGer">Gerekçe</label><textarea id="avKGer" maxlength="500" placeholder="Örn. başlıkta yasaklı ifade"></textarea><div class="hata-metin" id="avKHata"></div>' +
        '<button type="button" class="btn altin" id="avKOnay">Kaldır</button><button type="button" class="btn ikinci" id="avKVaz">Vazgeç</button></div>');
      m.querySelector('#avKVaz').onclick = modalKapat;
      m.querySelector('#avKOnay').onclick = function () {
        var gr = m.querySelector('#avKGer').value.trim(); if (gr.length < 5) { m.querySelector('#avKHata').textContent = 'Gerekçe en az 5 karakter olmalı.'; return; }
        API.rpc('aday_lansman_kaldir', { p_id: l.id, p_gerekce: gr }).then(function () { modalKapat(); bildir('Lansman kaldırıldı.'); C.at = 0; tazele(true, true); })
          .catch(function (err) { m.querySelector('#avKHata').textContent = hata(err); });
      };
    };
  }

  function confirmModal(baslik, metin, dugme, fn) {
    if (typeof modal !== 'function') { if (window.confirm(baslik + '\n' + metin)) fn(); return true; }
    var m = modal('<h3 style="font-size:19px;font-weight:800">' + esc(baslik) + '</h3><p style="font-size:15px;line-height:1.5">' + esc(metin) + '</p>' +
      '<button type="button" class="btn altin" id="avOnay">' + esc(dugme) + '</button><button type="button" class="btn ikinci" id="avVaz">Vazgeç</button>');
    m.querySelector('#avVaz').onclick = modalKapat;
    m.querySelector('#avOnay').onclick = function () { modalKapat(); fn(); };
    return true;
  }

  // Canlı/yaklaşan lansman açıkken: sayaç her saniye, veri 8 sn'de bir (ekran görünür ve bu lansman açıkken).
  function canliBaslat(l) {
    durdur();
    if (l.durum !== 'planli' || l.bitti) return;
    var adim = 0;
    C.canliTimer = setInterval(function () {
      var kok = document.getElementById('avLansman');
      if (!kok || +kok.dataset.id !== +l.id) { durdur(); return; }
      var s = document.getElementById('avSayac'); if (s && C.sonLansman) s.textContent = sayacMetni(C.sonLansman);
      adim++;
      if (document.hidden) return;
      var L = C.sonLansman || l, t = simdiMs(), bas = new Date(L.bas).getTime(), bit = new Date(L.bit).getTime();
      var durumDegisti = (!L.canli && t >= bas && t < bit) || (L.canli && t >= bit);
      if (durumDegisti) { tazele(true, true); return; }
      if (L.canli && adim % 8 === 0) tazele(false);
    }, 1000);
  }

  // tam = true: bütün ekranı yeniden çiz (durum değişti). Aksi halde yalnız sayılar, adaylar ve mesajlar (yazılan mesaj korunur).
  function tazele(zorla, tam) {
    var L = C.sonLansman; if (!L) return;
    API.rpc('aday_lansman_detay', { p_id: L.id }).then(function (l) {
      var kok = document.getElementById('avLansman'); if (!kok || +kok.dataset.id !== +l.id) return;
      if (tam || l.canli !== L.canli || l.bitti !== L.bitti || l.durum !== L.durum) { lansmanCiz(l); canliBaslat(l); return; }
      C.sonLansman = l;
      var k = document.getElementById('avKatilim'); if (k) k.textContent = +l.katilim || 0;
      var h = document.getElementById('avHatirlat'); if (h) h.textContent = +l.hatirlat || 0;
      var a = document.getElementById('avAdaylar'); if (a) a.innerHTML = adaylarHtml(l);
      var m = document.getElementById('avMesajlar');
      if (m) { var altta = m.scrollHeight - m.scrollTop - m.clientHeight < 40; m.innerHTML = mesajlarHtml(l); if (altta || zorla) m.scrollTop = m.scrollHeight; }
      baglaLansman(l);
    }).catch(function () {});
  }

  /* ------------------------------------------------ LANSMAN DÜZENLE */
  var F = { h: null, il: '', secili: [], notlar: {} };

  function duzenleEkrani() {
    css(); durdur();
    if (typeof iskelet === 'function') iskelet('Aday lansmanı düzenle', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    Promise.all([API.rpc('aday_lansman_hazirlik', {}), vitrinGetir(false).catch(function () { return null; })]).then(function (r) {
      F.h = r[0]; F.secili = []; F.notlar = {};
      var iller = ilSecenekleri(F.h);
      F.il = F.il && (F.il === 'ulke' || iller.some(function (i) { return String(i.id) === F.il; })) ? F.il : (iller[0] ? String(iller[0].id) : 'ulke');
      duzenleCiz();
    }).catch(function (err) { var x = ic(); if (x) x.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>'; });
  }

  function ilSecenekleri(h) {
    var m = {}; (h.adaylar || []).forEach(function (a) { if (!m[a.il_id]) m[a.il_id] = { id: a.il_id, ad: a.il, n: 0 }; m[a.il_id].n++; });
    return Object.keys(m).map(function (k) { return m[k]; }).sort(function (a, b) { return b.n - a.n || String(a.ad).localeCompare(String(b.ad), 'tr'); });
  }
  function ilKontenjan(id) { var v = C.v; var i = v && (v.iller || []).find(function (x) { return +x.id === +id; }); return i ? i.k : null; }
  function bedelHesap(h, il) {
    var b = h.bedel || {}; if (il === 'ulke') return +b.ulke || 0;
    var k = ilKontenjan(il); return k == null ? null : (+b.il_taban || 0) + (+b.il_sandalye || 0) * k;
  }
  function ustSinir(il) { if (il === 'ulke') return 12; var k = ilKontenjan(il); return Math.min(12, k == null ? 12 : k); }
  function yerelDeger(d) { var z = new Date(d), p = function (n) { return String(n).padStart(2, '0'); }; return z.getFullYear() + '-' + p(z.getMonth() + 1) + '-' + p(z.getDate()) + 'T' + p(z.getHours()) + ':' + p(z.getMinutes()); }

  function duzenleCiz() {
    var x = ic(); if (!x) return; var h = F.h || {};
    var p = h.parti || {}, iller = ilSecenekleri(h);
    var adaylar = (h.adaylar || []).filter(function (a) { return F.il === 'ulke' || String(a.il_id) === F.il; });
    var ust = ustSinir(F.il), bedel = bedelHesap(h, F.il);
    var lnsm = (h.lansmanlarim || []).map(function (l) {
      return '<button type="button" class="av-satir" onclick="adayLansmanAc(' + (+l.id) + ')"><div class="orta"><b>' + esc(l.baslik) + '</b><small>' + esc(l.il) + ' · ' + esc(zaman(l.bas)) + ' · ' +
        (l.durum === 'iptal' ? 'iptal edildi' : l.durum === 'kaldirildi' ? 'yönetim kaldırdı' : l.canli ? 'CANLI' : l.bitti ? 'tamamlandı' : 'planlandı') + ' · ' + tl(l.bedel) + '</small></div><span aria-hidden="true">›</span></button>';
    }).join('');
    var bilgi = '<div class="kart"><div class="av-liste-bas">' + amb(p, 40) + '<div class="orta"><h3>' + esc(p.ad || '') + '</h3><div class="kucuk">Parti kasası: ' + tl(p.kasa) + ' · son 24 saatte ' + (+h.son24 || 0) + ' / ' + (+h.gunluk_sinir || 0) + ' lansman</div></div></div>' +
      '<div class="av-uyari">' + esc(h.kural_yazi || '') + '</div>' +
      '<div class="av-ozet"><span>İl lansmanı</span><span>' + tl((h.bedel || {}).il_taban) + ' + sandalye başı ' + tl((h.bedel || {}).il_sandalye) + '</span></div>' +
      '<div class="av-ozet"><span>Türkiye geneli lansmanı</span><span>' + tl((h.bedel || {}).ulke) + '</span></div>' +
      '<div class="av-ozet"><span>Kurallar</span><span style="text-align:right;flex:1;min-width:180px">Her ilde ve Türkiye genelinde dönemde 1 kez · ' + (+h.sure_dk || 60) + ' dk canlı · başlamadan iptal edilirse bedel iade</span></div></div>';
    if (!h.acik || !h.aday_hazir || !(h.adaylar || []).length) {
      x.innerHTML = bilgi + '<div class="kart"><div class="bos">' + (!h.acik ? 'Şu anda lansman düzenlenemez: takvimde uygun genel seçim yok ya da lansman süresi doldu.' : !h.aday_hazir ? 'Listeler kesinleşince lansman düzenleyebilirsin.' : 'Lansmanda tanıtılabilecek adayın yok: önce aday listesi oluşmalı.') + '</div></div>' +
        (lnsm ? '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 6px">Lansmanlarım</h2>' + lnsm + '</div>' : '');
      return;
    }
    var enErken = new Date(h.en_erken), enGec = new Date(h.en_gec);
    var onerilen = new Date(Math.max(enErken.getTime() + 15 * 60000, simdiMs() + 60 * 60000)); onerilen.setMinutes(onerilen.getMinutes() < 30 ? 30 : 60, 0, 0);
    if (onerilen > enGec) onerilen = new Date(enErken.getTime() + 5 * 60000);
    x.innerHTML = bilgi +
      '<div class="kart av-form"><h2 style="font-size:17px;font-weight:800;margin:0">Yeni lansman</h2>' +
      '<label for="avKapsam">Nerede?</label><select id="avKapsam"><option value="ulke"' + (F.il === 'ulke' ? ' selected' : '') + '>Türkiye geneli (her ilden en çok 12 aday)</option>' +
      iller.map(function (i) { return '<option value="' + i.id + '"' + (String(i.id) === F.il ? ' selected' : '') + '>' + esc(i.ad) + ' · ' + i.n + ' aday</option>'; }).join('') + '</select>' +
      '<label for="avBaslik">Başlık</label><input id="avBaslik" maxlength="90" placeholder="Örn. ' + esc(F.il === 'ulke' ? 'Türkiye\'nin yeni kadrosu sahnede' : 'Adaylarımızla tanışın') + '"><div class="sayac" id="avBaslikSay">0 / 90</div>' +
      '<label for="avSunus">Sunuş (salonda ve haberde görünür)</label><textarea id="avSunus" maxlength="1500" placeholder="Adaylarını neden seçtiğini, vaatlerini ve hedefini anlat (en az 30 karakter)."></textarea><div class="sayac" id="avSunusSay">0 / 1500</div>' +
      '<label for="avZaman">Başlangıç (Türkiye saati)</label><input id="avZaman" type="datetime-local" min="' + yerelDeger(enErken) + '" max="' + yerelDeger(enGec) + '" value="' + yerelDeger(onerilen) + '">' +
      '<div class="av-hizli"><button type="button" data-z="60">1 saat sonra</button><button type="button" data-z="180">3 saat sonra</button><button type="button" data-z="aksam">Bu akşam 21:00</button><button type="button" data-z="yarin">Yarın 20:00</button></div>' +
      '<p class="kucuk" style="margin:6px 0 0">En erken ' + esc(zaman(h.en_erken)) + ', en geç ' + esc(zaman(h.en_gec)) + '. Lansman ' + (+h.sure_dk || 60) + ' dakika sürer.</p>' +
      '<label>Sahneye çıkacak adaylar <span class="kucuk" id="avSecSay">(0 / ' + ust + ')</span></label><p class="kucuk" style="margin:0 0 4px">Dokunduğun sırayla sahneye çıkarlar. İstersen her adaya kısa bir tanıtım notu yaz.</p>' +
      (F.il === 'ulke' ? '<input id="avAdayAra" type="search" placeholder="Aday ya da il ara" autocomplete="off" style="margin-bottom:6px">' : '') +
      '<div id="avAdaySec"></div>' +
      '<div class="av-ozet" style="margin-top:10px"><span>Lansman bedeli (parti kasasından)</span><b id="avBedel">' + (bedel == null ? '—' : tl(bedel)) + '</b></div>' +
      '<div class="hata-metin" id="avHata"></div><button type="button" class="btn altin" id="avKaydet">Lansmanı duyur</button></div>' +
      (lnsm ? '<div class="kart"><h2 style="font-size:17px;font-weight:800;margin:0 0 6px">Lansmanlarım</h2>' + lnsm + '</div>' : '');

    var secCiz = function () {
      var q = ((document.getElementById('avAdayAra') || {}).value || '').toLocaleLowerCase('tr-TR').trim();
      var liste = adaylar.filter(function (a) { return !q || F.secili.indexOf(a.aday_id) >= 0 || String(a.ad + ' ' + a.il + ' ' + a.kad).toLocaleLowerCase('tr-TR').indexOf(q) >= 0; });
      liste.sort(function (a, b) { var ia = F.secili.indexOf(a.aday_id), ib = F.secili.indexOf(b.aday_id); if (ia >= 0 || ib >= 0) return (ia < 0 ? 999 : ia) - (ib < 0 ? 999 : ib); return 0; });
      document.getElementById('avAdaySec').innerHTML = liste.slice(0, 120).map(function (a) {
        var i = F.secili.indexOf(a.aday_id);
        return '<button type="button" class="av-sec' + (i >= 0 ? ' secili' : '') + '" data-a="' + a.aday_id + '"><span class="no">' + (i >= 0 ? i + 1 : '') + '</span><span class="orta"><b>' + esc(a.ad) + '</b><small>' + esc(a.il) + (a.sira ? ' · listede ' + a.sira + '. sıra' : '') + '</small></span></button>' +
          (i >= 0 ? '<input class="av-not" data-n="' + a.aday_id + '" maxlength="240" placeholder="Tanıtım notu (isteğe bağlı)" value="' + esc(F.notlar[a.aday_id] || '') + '">' : '');
      }).join('') || '<div class="kucuk">Aday bulunamadı.</div>';
      document.getElementById('avSecSay').textContent = '(' + F.secili.length + ' / ' + ust + ')';
      document.querySelectorAll('#avAdaySec [data-a]').forEach(function (b) { b.onclick = function () {
        var id = +b.dataset.a, i = F.secili.indexOf(id), he = document.getElementById('avHata'); he.textContent = '';
        if (i >= 0) F.secili.splice(i, 1);
        else if (F.secili.length >= ust) { he.textContent = 'Bu lansmanda en çok ' + ust + ' aday tanıtabilirsin.'; return; }
        else F.secili.push(id);
        secCiz();
      }; });
      document.querySelectorAll('#avAdaySec [data-n]').forEach(function (n) { n.oninput = function () { F.notlar[n.dataset.n] = n.value; }; });
    };
    secCiz();
    var ara = document.getElementById('avAdayAra'); if (ara) ara.oninput = secCiz;
    var bagSay = function (id, sid, max) { var el = document.getElementById(id), s = document.getElementById(sid); if (el && s) el.oninput = function () { s.textContent = el.value.length + ' / ' + max; }; };
    bagSay('avBaslik', 'avBaslikSay', 90); bagSay('avSunus', 'avSunusSay', 1500);
    document.getElementById('avKapsam').onchange = function () {
      F.il = this.value; F.secili = []; F.notlar = {};
      var bas = document.getElementById('avBaslik').value, sun = document.getElementById('avSunus').value, z = document.getElementById('avZaman').value;
      duzenleCiz();
      document.getElementById('avBaslik').value = bas; document.getElementById('avSunus').value = sun; document.getElementById('avZaman').value = z;
      document.getElementById('avBaslikSay').textContent = bas.length + ' / 90'; document.getElementById('avSunusSay').textContent = sun.length + ' / 1500';
      if (bedelHesap(h, F.il) == null && F.il !== 'ulke') API.rpc('aday_lansman_hazirlik', { p_il: +F.il }).then(function (r) { var b = document.getElementById('avBedel'); if (b) b.textContent = tl((r.bedel || {}).secili); }).catch(function () {});
    };
    document.querySelectorAll('.av-hizli [data-z]').forEach(function (b) { b.onclick = function () {
      var z = new Date(simdiMs()), k = b.dataset.z;
      if (k === 'aksam') { z.setHours(21, 0, 0, 0); if (z.getTime() < simdiMs() + 16 * 60000) z.setDate(z.getDate() + 1); }
      else if (k === 'yarin') { z.setDate(z.getDate() + 1); z.setHours(20, 0, 0, 0); }
      else { z = new Date(simdiMs() + (+k) * 60000); z.setSeconds(0, 0); }
      document.getElementById('avZaman').value = yerelDeger(z);
    }; });
    var kb = document.getElementById('avKaydet');
    kb.onclick = function () {
      var he = document.getElementById('avHata'); he.textContent = '';
      var bas = document.getElementById('avBaslik').value.trim(), sun = document.getElementById('avSunus').value.trim(), zv = document.getElementById('avZaman').value;
      if (bas.length < 5) { he.textContent = 'Başlık en az 5 karakter olmalı.'; return; }
      if (sun.length < 30) { he.textContent = 'Sunuş en az 30 karakter olmalı.'; return; }
      if (!zv) { he.textContent = 'Başlangıç zamanını seç.'; return; }
      if (!F.secili.length) { he.textContent = 'En az bir aday seç.'; return; }
      var t = new Date(zv); if (isNaN(t.getTime())) { he.textContent = 'Başlangıç zamanı geçersiz.'; return; }
      kb.disabled = true;
      API.rpc('aday_lansman_duzenle', { p_il: F.il === 'ulke' ? null : +F.il, p_bas: t.toISOString(), p_baslik: bas, p_metin: sun,
        p_adaylar: F.secili.slice(), p_notlar: F.secili.map(function (id) { return (F.notlar[id] || '').trim(); }) })
        .then(function (r) { bildir('Lansman duyuruldu. ' + tl(r.bedel) + ' parti kasasından ödendi.'); C.at = 0; F.secili = []; F.notlar = {}; ac(function () { lansmanEkrani(r.id); }); })
        .catch(function (err) { he.textContent = hata(err); kb.disabled = false; });
    };
  }

  /* ------------------------------------------------ girişler */
  function girisHtml(alt) {
    return '<button type="button" class="av-giris" onclick="adayVitriniAc()"><span class="av-ik">' + IKON + '</span><span class="orta"><b>Aday Vitrini</b><small>' + esc(alt) + '</small></span><span class="ok" aria-hidden="true">›</span></button>';
  }
  function ekle(id, html, yer, nerede) {
    if (!yer || document.getElementById(id)) return;
    var d = document.createElement('div'); d.id = id; d.innerHTML = html;
    if (nerede === 'once') yer.parentNode.insertBefore(d, yer); else if (nerede === 'sonra') yer.parentNode.insertBefore(d, yer.nextSibling); else yer.insertBefore(d, yer.firstChild);
  }
  function girisleriEkle(baslik) {
    var x = ic(); if (!x) return;
    if (baslik === 'Partiler') {
      css();
      ekle('avParti', girisHtml('81 ilde hangi parti kimi, kaçıncı sıradan aday gösterdi · aday lansmanları') + '<div id="avPartiLansman"></div>', x);
      var dl = function (v) { var y = document.getElementById('avPartiLansman'); if (y && v && v.ben && v.ben.lansman_yetkili && !y.innerHTML) y.innerHTML = '<button type="button" class="btn ikinci" style="margin:-2px 0 10px" onclick="adayLansmanDuzenleAc()">Aday lansmanı düzenle</button>'; };
      if (C.v) dl(C.v); else vitrinGetir(false).then(dl).catch(function () { var y = document.getElementById('avParti'); if (y) y.remove(); });
    } else if (baslik === 'Türkiye') {
      css(); ekle('avHarita', girisHtml('Milletvekili adayları haritası: il il listeler ve sıralar'), x);
    } else {
      var sahne = x.querySelector('section.sahne');
      if (sahne && /Genel Seçim|Milletvekili/.test(sahne.textContent || '')) {
        css();
        var canli = C.v ? (C.v.lansmanlar || []).filter(function (l) { return l.canli; }).length : 0;
        ekle('avGundem', girisHtml(canli ? canli + ' aday lansmanı şu an canlı · il il adaylar ve sıralar' : 'Hangi ilde kim aday, kaçıncı sırada · aday lansmanları'), sahne, 'sonra');
      }
    }
  }
  if (typeof window.iskelet === 'function') {
    var eski = window.iskelet;
    window.iskelet = iskelet = function (baslik) {
      var sonuc = eski.apply(this, arguments);
      try { if (typeof baslik === 'string' && baslik !== 'Aday lansmanı') durdurDisari(); girisleriEkle(baslik); } catch (_) {}
      return sonuc;
    };
  }
  function durdurDisari() { if (!document.getElementById('avLansman')) durdur(); }

  window.adayVitriniEkrani = ekran;
  window.adayVitriniAc = function () { ac(ekran); };
  window.adayVitriniIl = function (id) { ac(function () { ilEkrani(+id); }); };
  window.adayLansmanAc = function (id) { ac(function () { lansmanEkrani(+id); }); };
  window.adayLansmanDuzenleAc = function () { ac(duzenleEkrani); };
})();
