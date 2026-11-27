/* =====================================================================
   TBMM GENEL KURUL SALONU (27.11.2026 · sql/zz_20261127_tbmm_genel_kurul.sql)
   Meclis açıldığında oyuncuların girdiği canlı salon:
   • Yarım daire Genel Kurul: 600 sandalye parti bloklarıyla; salondaki vekiller yanar,
     oylamada her sandalye verdiği oyun rengini alır. Sandalyeye dokununca vekilin kartı açılır.
   • Başkanlık Divanı, hatip kürsüsü ve "Egemenlik Kayıtsız Şartsız Milletindir".
   • Kürsü: konuşan vekil, kalan süre ve kelime hakkı; mikrofon süre bitince kapanır.
   • Tutanak: TBMM tutanak düzeninde canlı akış ("AD SOYAD (İl) –", "(CYP sıralarından alkışlar)").
   • Söz iste / sıradan söz at / alkış-protesto / yoklama "Buradayım" / işaret oylaması /
     kanun elektronik oylaması EVET-HAYIR-ÇEKİMSER / andiçme / gündem dışı / grup önerisi.
   • Başkanlık paneli: söz ver, sırayı düzenle, ek süre, sözü kes, gündemi yürüt, oylamaya sun,
     ara ver, yoklama, oylama zili, disiplin, kapalı oturum.
   Bütün kurallar sunucuda (gk_*). İstemci yalnız gösterir; durum sürümlü önbellekten gelir.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_TBMM_SALON) return;
  window.SO_TBMM_SALON = true;

  var $1 = function (s, k) { return (k || document).querySelector(s); };
  var $$ = function (s, k) { return Array.prototype.slice.call((k || document).querySelectorAll(s)); };
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var rpc = function (ad, a) { return API.rpc(ad, a || {}); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var bildir = function (m, kotu) { try { toast(m, kotu); } catch (_) {} };
  var buyuk = function (s) { return String(s || '').toLocaleUpperCase('tr'); };
  var sayi = function (n) { return Number(n || 0).toLocaleString('tr-TR'); };
  var kelime = function (m) { m = String(m || '').trim(); return m ? m.split(/\s+/).length : 0; };
  var TZ = { timeZone: 'Europe/Istanbul' };
  var saat = function (t) { try { return new Date(t).toLocaleTimeString('tr-TR', Object.assign({ hour: '2-digit', minute: '2-digit' }, TZ)).replace(':', '.'); } catch (_) { return ''; } };
  var tarih = function (t) { try { return new Date(t).toLocaleDateString('tr-TR', Object.assign({ day: 'numeric', month: 'long', weekday: 'long' }, TZ)); } catch (_) { return ''; } };
  var gunAy = function (t) { try { return new Date(t).toLocaleDateString('tr-TR', Object.assign({ day: 'numeric', month: 'long', year: 'numeric' }, TZ)); } catch (_) { return ''; } };
  function sira(n) {
    n = Number(n) || 0; var s;
    if (n % 1000 === 0 && n) s = 'inci'; else if (n % 100 === 0 && n) s = 'üncü';
    else if (n % 10) s = { 1: 'inci', 2: 'nci', 3: 'üncü', 4: 'üncü', 5: 'inci', 6: 'ncı', 7: 'nci', 8: 'inci', 9: 'uncu' }[n % 10];
    else s = { 1: 'uncu', 2: 'nci', 3: 'uncu', 4: 'ıncı', 5: 'nci', 6: 'ıncı', 7: 'inci', 8: 'inci', 9: 'ıncı' }[Math.floor(n / 10) % 10];
    return n + '\'' + s;
  }
  function mmss(sn) { sn = Math.max(0, Math.round(sn)); var s = sn % 60, d = Math.floor(sn / 60) % 60, h = Math.floor(sn / 3600); return (h ? h + '.' + (d < 10 ? '0' : '') + d : d) + ':' + (s < 10 ? '0' : '') + s; }
  function sure(sn) { sn = Number(sn) || 0; return sn >= 60 ? (sn % 60 ? Math.floor(sn / 60) + ' dk ' + (sn % 60) + ' sn' : (sn / 60) + ' dk') : sn + ' sn'; }

  var S = { G: null, B: null, surum: 0, son: 0, bid: null, satir: {}, sira: [], H: null, Ht: 0, ofs: 0, salon: { vekil: 0, izleyici: 0 },
    mesgul: false, tekrar: false, imza: {}, ilk: true, ses: false, ac: null, tik: null, gorunum: 'oto', acikBsk: true, eskiSohbet: null };
  try { S.ses = localStorage.getItem('gkSes') === '1'; S.acikBsk = localStorage.getItem('gkBsk') !== '0'; } catch (_) {}
  var simdiMs = function () { return Date.now() + S.ofs; };
  var benim = function () { var p = typeof D !== 'undefined' && D && D.durum && D.durum.profil; return p ? p.kad : null; };

  /* ---------------------------------------------------------- ikonlar */
  var I = {
    ses: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5 6 9H2v6h4l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/></svg>',
    sessiz: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5 6 9H2v6h4l5 4z"/><path d="m23 9-6 6M17 9l6 6"/></svg>',
    gundem: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01"/></svg>',
    goz: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>',
    mik: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0 0 14 0M12 17v5"/></svg>',
    el: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 11V6a2 2 0 0 0-4 0M14 10V4a2 2 0 0 0-4 0v6M10 10.5V6a2 2 0 0 0-4 0v8a8 8 0 0 0 8 8h1a7 7 0 0 0 7-7v-3a2 2 0 0 0-4 0"/></svg>',
    alkis: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 11.5 12.5 6a1.6 1.6 0 0 1 2.3 2.3L11 12M9 13.5l5.8-5.8a1.6 1.6 0 0 1 2.3 2.3L12 15M12 15l3.6-3.6a1.6 1.6 0 0 1 2.3 2.3l-4.4 4.4A6 6 0 0 1 5 18.5 6 6 0 0 1 4.5 10l2-2a1.6 1.6 0 0 1 2.3 2.3"/><path d="M15 3l.5-1.5M19 5l1.2-1M20.5 8.5H22"/></svg>',
    protesto: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 14V2M9 18.1 10 14H4.2a2 2 0 0 1-1.9-2.6l2.3-7A2 2 0 0 1 6.5 3H17v11l-4 8a3 3 0 0 1-3-3.9z"/></svg>',
    tokmak: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m14 13-7.5 7.5a2.1 2.1 0 0 1-3-3L11 10M16 16l6-6M8 8l6-6M9 7l8 8M21 11l-8-8"/></svg>',
    kilit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
    arsiv: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 8v13H3V8M1 3h22v5H1zM10 12h4"/></svg>'
  };

  /* ---------------------------------------------------------- sesler (varsayılan kapalı) */
  function sesCal(tur) {
    if (!S.ses) return;
    try {
      var AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
      var ac = S.ac || (S.ac = new AC()); if (ac.state === 'suspended') ac.resume();
      var t = ac.currentTime + 0.02;
      var ton = function (f, bas, uzun, guc, tip) {
        var o = ac.createOscillator(), g = ac.createGain(); o.type = tip || 'sine'; o.frequency.setValueAtTime(f, bas);
        if (tip !== 'sine') o.frequency.exponentialRampToValueAtTime(Math.max(40, f * 0.5), bas + uzun);
        g.gain.setValueAtTime(0.0001, bas); g.gain.exponentialRampToValueAtTime(guc, bas + 0.008); g.gain.exponentialRampToValueAtTime(0.0001, bas + uzun);
        o.connect(g); g.connect(ac.destination); o.start(bas); o.stop(bas + uzun + 0.05);
      };
      if (tur === 'tokmak') { ton(150, t, 0.16, 0.5, 'triangle'); ton(150, t + 0.24, 0.16, 0.45, 'triangle'); ton(150, t + 0.48, 0.22, 0.55, 'triangle'); }
      else if (tur === 'zil') { [0, 0.35, 0.7].forEach(function (d) { ton(1046, t + d, 0.9, 0.12); ton(1568, t + d, 0.6, 0.05); }); }
      else if (tur === 'alkis') {
        var uz = 1.2, n = Math.floor(ac.sampleRate * uz), buf = ac.createBuffer(1, n, ac.sampleRate), d = buf.getChannelData(0);
        for (var i = 0; i < n; i++) { var zarf = Math.pow(Math.sin(Math.PI * i / n), 0.6); d[i] = (Math.random() * 2 - 1) * zarf * (Math.random() < 0.18 ? 1 : 0.25); }
        var src = ac.createBufferSource(), f = ac.createBiquadFilter(), g = ac.createGain(); src.buffer = buf; f.type = 'bandpass'; f.frequency.value = 1800; f.Q.value = 0.7; g.gain.value = 0.35;
        src.connect(f); f.connect(g); g.connect(ac.destination); src.start(t);
      }
    } catch (_) {}
  }

  /* ---------------------------------------------------------- salon geometrisi */
  function koltuklar(N) {
    N = Math.max(1, N | 0);
    var satir = N >= 400 ? 12 : N >= 200 ? 9 : N >= 80 ? 7 : 5, r0 = 0.38, r1 = 1, rad = [], top = 0, i;
    for (i = 0; i < satir; i++) { var r = r0 + (r1 - r0) * i / (satir - 1); rad.push(r); top += r; }
    var say = rad.map(function (r) { return Math.floor(N * r / top); }), fark = N - say.reduce(function (a, b) { return a + b; }, 0);
    for (i = satir - 1; fark > 0; i = (i - 1 + satir) % satir) { say[i]++; fark--; }
    var L = [];
    rad.forEach(function (r, s) { var n = say[s]; for (var j = 0; j < n; j++) L.push({ a: Math.PI * (1 - (j + 0.5) / n), r: r }); });
    L.sort(function (x, y) { return (y.a - x.a) || (x.r - y.r); });
    var kucuk = Math.min.apply(null, rad.map(function (r, s) { return Math.PI * r / Math.max(1, say[s]); }));
    var rr = Math.max(1.6, Math.min(188 * (r1 - r0) / Math.max(1, satir - 1) * 0.42, 188 * kucuk * 0.46));
    return { L: L, rr: rr };
  }
  function bayrak(x, y) {
    return '<g transform="translate(' + x + ',' + y + ')"><rect width="27" height="18" rx="1.2" fill="#e30a17"/><circle cx="10" cy="9" r="5.2" fill="#fff"/><circle cx="11.3" cy="9" r="4.2" fill="#e30a17"/>' +
      '<polygon fill="#fff" points="16.6,9 18.9,9.8 18.9,8.2 16.9,9.6 18.3,7.6"/></g>';
  }
  function svgHtml() {
    var H = S.H || { toplam: 600, vekiller: [] }, N = Math.max(H.toplam || 600, (H.vekiller || []).length), K = koltuklar(N), CX = 200, CY = 198, R = 188;
    S.koltuk = K;
    var dairler = K.L.map(function (k, i) {
      var x = (CX + R * k.r * Math.cos(k.a)).toFixed(1), y = (CY - R * k.r * Math.sin(k.a)).toFixed(1);
      return '<circle class="k" data-i="' + i + '" cx="' + x + '" cy="' + y + '" r="' + K.rr.toFixed(2) + '"/>';
    }).join('');
    return '<svg class="gk-svg" viewBox="0 0 400 300" role="img" aria-label="Genel Kurul salonu">' +
      '<defs><radialGradient id="gkZ" cx="50%" cy="100%" r="100%"><stop offset="0" stop-color="#3b2614"/><stop offset=".55" stop-color="#241a1c"/><stop offset="1" stop-color="#151a30"/></radialGradient>' +
      '<linearGradient id="gkD" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7a4d26"/><stop offset="1" stop-color="#4a2c14"/></linearGradient></defs>' +
      '<path d="M8,' + CY + ' A' + (R + 4) + ',' + (R + 4) + ' 0 0 1 392,' + CY + ' Z" fill="url(#gkZ)" opacity=".95"/>' +
      '<path d="M' + (CX - R * 0.3) + ',' + CY + ' A' + (R * 0.3) + ',' + (R * 0.3) + ' 0 0 1 ' + (CX + R * 0.3) + ',' + CY + '" fill="none" stroke="rgba(217,178,91,.25)" stroke-width="1"/>' +
      '<g id="gkKol">' + dairler + '</g>' +
      '<rect x="0" y="' + (CY + 4) + '" width="400" height="' + (300 - CY - 4) + '" fill="#1a1426"/>' +
      '<rect x="0" y="' + (CY + 4) + '" width="400" height="2" fill="rgba(217,178,91,.35)"/>' +
      bayrak(86, CY + 16) + bayrak(287, CY + 16) +
      '<rect x="118" y="' + (CY + 14) + '" width="164" height="24" rx="4" fill="url(#gkD)" stroke="#a6743f" stroke-width="1"/>' +
      '<circle class="gk-dk" cx="160" cy="' + (CY + 11) + '" r="5"/><circle class="gk-dk" id="gkBskKol" cx="200" cy="' + (CY + 9) + '" r="6.5"/><circle class="gk-dk" cx="240" cy="' + (CY + 11) + '" r="5"/>' +
      '<text x="200" y="' + (CY + 30) + '" class="gk-dy">BAŞKANLIK DİVANI</text>' +
      '<path d="M184,' + (CY + 46) + ' h32 l-5,22 h-22 z" fill="url(#gkD)" stroke="#a6743f" stroke-width="1"/>' +
      '<circle id="gkMik" class="gk-mik" cx="200" cy="' + (CY + 43) + '" r="2.6"/>' +
      '<text x="200" y="' + (CY + 60) + '" class="gk-dy" style="font-size:6px">KÜRSÜ</text>' +
      '<text x="200" y="294" class="gk-yazi">EGEMENLİK KAYITSIZ ŞARTSIZ MİLLETİNDİR</text></svg>';
  }
  function koltukGuncelle() {
    var kol = $1('#gkKol'); if (!kol || !S.H) return;
    var G = S.G || {}, B = S.B || {}, H = S.H, V = H.vekiller || [], P = {}, sal = {}, oy = null, renkOy = { k: '#2fbf71', r: '#e5484d', c: '#f2b33d' };
    (H.partiler || []).forEach(function (p) { P[p.id == null ? 0 : p.id] = p.renk || '#8E97B5'; });
    (G.sal || []).forEach(function (m) { sal[m] = 1; });
    var acik = G.b && ['acik', 'yoklama', 'arada'].indexOf(G.b.durum) >= 0;
    var gor = gorunum();
    if (gor === 'oylama' && G.oylama) oy = G.oylama.oy || {};
    else if (gor === 'kanun' && G.kanunlar && G.kanunlar[0]) oy = G.kanunlar[0].oy || {};
    var konusanMk = G.kursu && G.kursu.kisi ? G.kursu.kisi.mk : null;
    var imza = [gor, acik, JSON.stringify(G.sal || []), oy ? JSON.stringify(oy) : '', konusanMk, B.mk, V.length].join('|');
    if (S.imza.kol === imza) return; S.imza.kol = imza;
    var els = kol.children;
    for (var i = 0; i < els.length; i++) {
      var v = V[i], el = els[i], f, sinif = 'k';
      if (!v) { f = '#2b3150'; sinif += ' bos'; }
      else if (oy) { var o = oy[v.m]; f = o ? renkOy[o] : '#3a4366'; if (!o) sinif += ' yok'; }
      else { f = P[v.p == null ? 0 : v.p] || '#8E97B5'; if (acik && !sal[v.m]) sinif += ' yok'; if (!acik) sinif += ' sonuk'; }
      if (v && B.mk && v.m === B.mk) sinif += ' ben';
      if (v && konusanMk && v.m === konusanMk) sinif += ' konusan';
      el.setAttribute('fill', f); el.setAttribute('class', sinif);
    }
    var mik = $1('#gkMik'); if (mik) mik.setAttribute('class', 'gk-mik' + (G.kursu && G.kursu.bas ? ' acik' : ''));
    var bk = $1('#gkBskKol'); if (bk) bk.setAttribute('class', 'gk-dk' + (G.b && G.b.yoneten ? ' dolu' : ''));
  }
  function gorunum() {
    var G = S.G || {};
    var var_ = { oylama: !!(G.oylama && G.oylama.oy), kanun: !!(G.kanunlar && G.kanunlar[0] && G.kanunlar[0].oy) };
    if (S.gorunum !== 'oto' && (S.gorunum === 'salon' || var_[S.gorunum])) return S.gorunum;
    if (G.oylama && G.oylama.durum === 'acik' && var_.oylama) return 'oylama';
    return 'salon';
  }
  function lejantHtml() {
    var H = S.H || {}, G = S.G || {}, gor = gorunum();
    var sec = (G.oylama && G.oylama.oy) || (G.kanunlar && G.kanunlar[0] && G.kanunlar[0].oy) ? '<div class="gk-gor" role="tablist">' +
      [['salon', 'Salon'], G.oylama && G.oylama.oy ? ['oylama', 'İşaret oylaması'] : null, G.kanunlar && G.kanunlar[0] && G.kanunlar[0].oy ? ['kanun', 'Kanun oylaması'] : null].filter(Boolean)
        .map(function (x) { return '<button type="button" role="tab" aria-selected="' + (gor === x[0]) + '" class="' + (gor === x[0] ? 'aktif' : '') + '" data-gor="' + x[0] + '">' + x[1] + '</button>'; }).join('') + '</div>' : '';
    if (gor !== 'salon') return sec + '<div class="gk-lejant"><span><i style="background:#2fbf71"></i>Kabul</span><span><i style="background:#e5484d"></i>Ret</span><span><i style="background:#f2b33d"></i>Çekimser</span><span><i style="background:#3a4366"></i>Oy kullanmadı</span></div>';
    return sec + '<div class="gk-lejant">' + ((H.partiler || []).map(function (p) { return '<span><i style="background:' + esc(p.renk || '#8E97B5') + '"></i>' + esc(p.kisa) + ' <b>' + p.n + '</b></span>'; }).join('') ||
      '<span>Meclis\'te henüz görevde milletvekili yok.</span>') + (H.toplam && (H.vekiller || []).length < H.toplam ? '<span><i style="background:#2b3150"></i>Boş <b>' + (H.toplam - (H.vekiller || []).length) + '</b></span>' : '') + '</div>';
  }

  /* ---------------------------------------------------------- stil */
  function css() {
    if ($1('#gkCss')) return;
    var s = document.createElement('style'); s.id = 'gkCss';
    s.textContent = [
      '.gk{--gold:#d9b25b;--gold2:#f1d48a;--ok:#2fbf71;--no:#e5484d;--ck:#f2b33d;color-scheme:dark;padding-bottom:6px}',
      '.gk-ust{display:flex;align-items:center;gap:8px;flex-wrap:wrap;padding:10px 12px;border-radius:14px;background:linear-gradient(135deg,#1c2548,#121a36);border:1px solid rgba(217,178,91,.35);margin-bottom:10px}',
      '.gk-ust .orta{flex:1 1 150px;min-width:0}.gk-ust b{display:block;font-family:var(--disp);font-size:16px;letter-spacing:.03em;color:#f4e6c0;line-height:1.25}.gk-ust small{display:block;font-size:13px;color:var(--txt2);margin-top:2px;line-height:1.35}',
      '.gk-cip{display:inline-flex;align-items:center;gap:6px;font-weight:800;font-size:12.5px;letter-spacing:.06em;padding:6px 10px;border-radius:999px;background:#2a3358;color:#fff;white-space:nowrap}',
      '.gk-cip.canli{background:#b3261e}.gk-cip.canli i{width:8px;height:8px;border-radius:50%;background:#fff;animation:gkN 1.2s infinite}.gk-cip.ara{background:#8a5a12}.gk-cip.yok{background:#6c4bd6}.gk-cip.kapali{background:#3c1f1f;border:1px solid #e5484d}',
      '@keyframes gkN{0%,100%{opacity:1}50%{opacity:.25}}',
      '.gk-izl{display:flex;gap:10px;font-size:12.5px;color:var(--txt2);width:100%;flex-wrap:wrap}.gk-izl span{display:inline-flex;align-items:center;gap:4px}.gk-izl svg{width:15px;height:15px}',
      '.gk-sahne{position:relative;border-radius:16px;background:#151a30;border:1px solid rgba(217,178,91,.28);overflow:hidden;margin-bottom:10px}',
      '.gk-svg{display:block;width:100%;height:auto;touch-action:manipulation}.gk-svg circle.k{transition:fill .45s,opacity .45s;cursor:pointer}.gk-svg .yok{opacity:.28}.gk-svg .sonuk{opacity:.55}.gk-svg .bos{opacity:.6}',
      '.gk-svg .ben{stroke:#fff;stroke-width:1.5}.gk-svg .konusan{stroke:#f1d48a;stroke-width:2;animation:gkN 1.4s infinite}',
      '.gk-dk{fill:#3d2a1a;stroke:#a6743f;stroke-width:.8}.gk-dk.dolu{fill:#d9b25b}.gk-dy{fill:#e9cf8f;font-size:6.5px;font-weight:700;letter-spacing:1.2px;text-anchor:middle}',
      '.gk-mik{fill:#5b5f6e}.gk-mik.acik{fill:#ff5252;filter:drop-shadow(0 0 3px #ff5252);animation:gkN 1s infinite}',
      '.gk-yazi{fill:#d9b25b;font-size:10.5px;font-weight:800;letter-spacing:1.3px;text-anchor:middle;font-family:var(--disp)}',
      '.gk-gor{display:flex;gap:6px;padding:8px 8px 0;flex-wrap:wrap}.gk-gor button{min-height:36px;padding:6px 12px;border-radius:999px;background:#232b4a;color:var(--txt);font-size:13.5px;font-weight:700}.gk-gor button.aktif{background:var(--gold);color:#1a1405}',
      '.gk-lejant{display:flex;gap:6px 12px;flex-wrap:wrap;padding:8px 12px 12px;font-size:13px;color:var(--txt2)}.gk-lejant span{display:inline-flex;align-items:center;gap:5px}.gk-lejant i{width:10px;height:10px;border-radius:50%;display:inline-block}.gk-lejant b{color:var(--txt)}',
      '.gk-kart{background:var(--panel);border-radius:14px;padding:13px 14px;margin-bottom:10px;border:1px solid var(--line)}.gk-kart h3{font-family:var(--disp);font-size:16.5px;font-weight:700;letter-spacing:.02em;margin:0 0 6px;color:#f4e6c0}',
      '.gk-kart p,.gk-not{font-size:14.5px;line-height:1.45;color:var(--txt2)}.gk-not{margin-top:6px}.gk-kart.altin{border-color:rgba(217,178,91,.5);background:linear-gradient(160deg,#1f2747,#171e3b)}',
      '.gk-kursu{display:flex;gap:12px;align-items:center}.gk-kursu .pp{flex:0 0 auto;width:58px;height:58px;border-radius:50%;overflow:hidden;box-shadow:0 0 0 2px var(--gold)}.gk-kursu .pp>*{width:58px!important;height:58px!important}',
      '.gk-kursu .ad{flex:1;min-width:0}.gk-kursu .ad b{display:block;font-size:16px;font-weight:800;line-height:1.25;overflow-wrap:anywhere}.gk-kursu .ad small{display:block;font-size:13px;color:var(--txt2);margin-top:2px}',
      '.gk-sure{font-variant-numeric:tabular-nums;font-weight:800;font-size:20px;color:#fff;text-align:right;min-width:64px}.gk-sure small{display:block;font-size:11.5px;font-weight:600;color:var(--mut);letter-spacing:.04em}',
      '.gk-bar{height:7px;border-radius:99px;background:#262f52;overflow:hidden;margin-top:9px}.gk-bar i{display:block;height:100%;background:linear-gradient(90deg,var(--gold),#ffcf6e);border-radius:99px;transition:width .6s}',
      '.gk-bar.kirmizi i{background:linear-gradient(90deg,#e5484d,#ff8a80)}.gk-bar-yazi{display:flex;justify-content:space-between;font-size:12.5px;color:var(--mut);margin-top:4px;font-variant-numeric:tabular-nums}',
      '.gk-mikrofon{display:inline-flex;align-items:center;gap:5px;font-size:11.5px;font-weight:800;letter-spacing:.08em;color:#ff8a80;margin-top:4px}.gk-mikrofon svg{width:14px;height:14px}',
      '.gk-oyl{display:flex;height:12px;border-radius:99px;overflow:hidden;background:#262f52;margin:10px 0 6px}.gk-oyl i{display:block;height:100%}',
      '.gk-say3{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;text-align:center}.gk-say3 div{background:#1a2140;border-radius:10px;padding:7px 4px}.gk-say3 b{display:block;font-size:19px;font-variant-numeric:tabular-nums}.gk-say3 span{font-size:12px;color:var(--mut)}',
      '.gk-partiler{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px;font-size:12.5px}.gk-partiler span{background:#1a2140;border-radius:8px;padding:4px 8px;color:var(--txt2)}.gk-partiler i{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:4px}',
      '.gk-d{display:flex;align-items:center;justify-content:center;gap:7px;width:100%;min-height:48px;margin-top:8px;padding:10px 14px;border-radius:12px;background:#283563;color:#fff;font:inherit;font-size:15.5px;font-weight:800;text-align:center;line-height:1.25;white-space:normal}',
      '.gk-d svg{width:19px;height:19px;flex:0 0 auto}.gk-d.altin{background:var(--gold);color:#1a1405}.gk-d.cizgi{background:transparent;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.22);font-weight:700}',
      '.gk-d.evet{background:#1f8a54}.gk-d.hayir{background:#b3261e}.gk-d.cek{background:#8a6510}.gk-d.secili{box-shadow:0 0 0 3px #fff inset}.gk-d:disabled{opacity:.45}',
      '.gk-d.dev{min-height:64px;font-size:20px;letter-spacing:.06em;font-family:var(--disp)}',
      '.gk-iki,.gk-uc{display:flex;gap:8px}.gk-iki>*,.gk-uc>*{flex:1 1 0;min-width:0}.gk-uc .gk-d{padding:10px 6px;font-size:14.5px}',
      '.gk-akis-kutu{position:relative;margin-bottom:10px}.gk-akis{background:#f7f3e8;color:#1d1a14;border-radius:14px;padding:12px 13px 14px;max-height:56vh;min-height:220px;overflow:auto;-webkit-overflow-scrolling:touch;font-family:Georgia,"Times New Roman",serif;font-size:15.5px;line-height:1.55;color-scheme:light}',
      '.gk-akis-bas{text-align:center;border-bottom:1.5px solid #1d1a14;padding-bottom:7px;margin-bottom:9px}.gk-akis-bas b{display:block;font-size:13.5px;letter-spacing:.12em}.gk-akis-bas small{display:block;font-size:12.5px;color:#5c5546;margin-top:2px}',
      '.gk-t{margin:0 0 9px;overflow-wrap:anywhere}.gk-t .ad{font-weight:700}.gk-t .ad i{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:4px;vertical-align:1px}',
      '.gk-t.bsk .ad{letter-spacing:.02em}.gk-t.laf{font-size:14.5px;color:#3e382c;padding-left:10px;border-left:2px solid #cfc6ad}.gk-t.tepki{text-align:center;font-style:italic;color:#5c5546}',
      '.gk-t.sis{text-align:center;font-size:14px;color:#4a4436}.gk-t.gdm{text-align:center;font-weight:700;letter-spacing:.04em;margin:14px 0 9px;font-size:14px}.gk-t.oy{background:#ece4cf;border-radius:10px;padding:8px 10px;font-weight:700;text-align:center}',
      '.gk-t.ym{font-size:14.5px}.gk-t.gz{color:#8b8473;font-style:italic}.gk-t small.tur{display:block;font-family:-apple-system,system-ui,sans-serif;font-size:12px;color:#6a6252;letter-spacing:.03em;margin-top:2px}',
      '.gk-tp{display:flex;gap:6px;flex-wrap:wrap;margin-top:5px;font-family:-apple-system,system-ui,sans-serif}.gk-tp button{display:inline-flex;align-items:center;gap:5px;min-height:34px;padding:4px 10px;border-radius:999px;background:#e9e1cb;color:#2b2619;font-size:13px;font-weight:700}',
      '.gk-tp button svg{width:15px;height:15px}.gk-tp button.secili{background:#1d1a14;color:#f7f3e8}.gk-tp .gal{font-size:12.5px;color:#6a6252;align-self:center}',
      '.gk-yeni{position:absolute;left:50%;bottom:10px;transform:translateX(-50%);background:#1d1a14;color:#fff;border-radius:999px;padding:8px 14px;font-size:13.5px;font-weight:800;box-shadow:0 4px 14px rgba(0,0,0,.35)}',
      '.gk-perde{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;text-align:center;padding:20px;border-radius:14px;background:rgba(20,12,12,.92);color:#ffd7d7;font-family:var(--disp)}',
      '.gk-perde svg{width:34px;height:34px}.gk-perde b{font-size:20px;letter-spacing:.12em}.gk-perde small{font-family:-apple-system,system-ui,sans-serif;font-size:14px;color:#f1c3c3;max-width:300px;line-height:1.4}',
      '.gk-dock{position:sticky;bottom:0;z-index:5;margin:0 -2px;padding:10px 12px calc(10px + var(--safeB,0px));background:linear-gradient(180deg,rgba(14,21,48,.92),#0b1129 30%);border-top:1px solid rgba(217,178,91,.35);border-radius:16px 16px 0 0;box-shadow:0 -6px 20px rgba(0,0,0,.35)}',
      '.gk-dock .bas{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:14px;color:var(--txt2)}.gk-dock .bas b{color:#fff;font-size:15px}',
      '.gk-dock textarea,.gk-dock input,.gk-form textarea,.gk-form input,.gk-form select{display:block;width:100%;min-width:0;box-sizing:border-box;margin-top:8px;padding:11px 12px;border-radius:12px;border:1px solid rgba(255,255,255,.2);background:#1b2140;color:#f2f5ff;font:inherit;font-size:16px;color-scheme:dark}',
      '.gk-dock textarea{min-height:92px;max-height:34vh;resize:vertical;line-height:1.45}.gk-say{font-variant-numeric:tabular-nums;font-size:13px;color:var(--txt2)}.gk-say.asti{color:#ff8a80;font-weight:800}',
      '.gk-satir{display:flex;align-items:center;gap:8px;padding:9px 0;border-top:1px solid var(--line)}.gk-satir:first-child{border-top:0}.gk-satir .orta{flex:1;min-width:0}.gk-satir .orta b{display:block;font-size:14.5px;overflow-wrap:anywhere}.gk-satir .orta small{display:block;font-size:12.5px;color:var(--mut);margin-top:1px}',
      '.gk-mini{display:inline-flex;align-items:center;justify-content:center;min-width:44px;min-height:40px;padding:6px 10px;border-radius:10px;background:#283563;color:#fff;font-size:13.5px;font-weight:800}.gk-mini.altin{background:var(--gold);color:#1a1405}.gk-mini.cizgi{background:transparent;box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.22)}',
      '.gk-mini:disabled{opacity:.4}.gk-grup{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}.gk-grup>*{flex:1 1 auto}',
      '.gk-bsk summary{list-style:none;display:flex;align-items:center;justify-content:space-between;cursor:pointer;font-family:var(--disp);font-size:16.5px;font-weight:700;color:#f4e6c0;min-height:30px}.gk-bsk summary::-webkit-details-marker{display:none}',
      '.gk-bsk summary small{font-family:-apple-system,system-ui,sans-serif;font-size:12.5px;color:var(--mut);font-weight:600}.gk-bsk h4{font-size:13px;letter-spacing:.06em;color:var(--mut);margin:14px 0 4px;text-transform:uppercase}',
      '.gk-gd{padding:8px 0;border-top:1px solid var(--line);font-size:14px;display:flex;gap:8px;align-items:center}.gk-gd:first-child{border-top:0}.gk-gd .n{flex:0 0 22px;height:22px;border-radius:50%;background:#283563;font-size:12px;font-weight:800;display:flex;align-items:center;justify-content:center}',
      '.gk-gd.aktif .n{background:var(--gold);color:#1a1405}.gk-gd.bitti{opacity:.55}.gk-gd .orta{flex:1;min-width:0;overflow-wrap:anywhere}',
      '.gk-sec{display:block;width:100%;text-align:left;margin-top:8px;padding:12px 14px;border-radius:12px;background:#1d2547;color:#fff;border:1px solid rgba(255,255,255,.12)}.gk-sec b{display:block;font-size:15.5px}.gk-sec span{display:block;font-size:13px;color:var(--txt2);margin-top:2px}.gk-sec:disabled{opacity:.45}',
      '.gk-form label{display:block;font-size:14.5px;font-weight:700;margin-top:10px}.gk-form h3{font-size:19px;font-weight:800;margin:0 0 4px}.gk-form p{font-size:14px;color:var(--txt2);line-height:1.45}',
      '.gk-ozet{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:8px}.gk-ozet div{background:#1a2140;border-radius:10px;padding:8px 4px;text-align:center}.gk-ozet b{display:block;font-size:18px}.gk-ozet span{font-size:12px;color:var(--mut)}',
      '.gk-alinti{margin-top:10px;padding:10px 12px;border-left:3px solid var(--gold);background:#1a2140;border-radius:0 10px 10px 0;font-size:14.5px;line-height:1.45;color:var(--txt);font-style:italic}',
      '.gk-hb{display:inline-flex;align-items:center;justify-content:center;width:40px;height:40px;border-radius:12px;background:rgba(255,255,255,.08);color:#fff}.gk-hb svg{width:20px;height:20px}',
      '.gk [hidden],.gk-perde[hidden],.gk-yeni[hidden]{display:none!important}',
      '@media (max-width:340px){.gk-ust b{font-size:15px}.gk-d.dev{font-size:18px}.gk-akis{font-size:15px}.gk-uc .gk-d{font-size:13.5px}}'
    ].join('');
    document.head.appendChild(s);
  }

  /* ---------------------------------------------------------- bölümler */
  function birlesimAdi(b) { return b ? (b.tur === 'olaganustu' ? 'Olağanüstü ' : '') + sira(b.no) + ' Birleşim' : ''; }
  function ustHtml() {
    var G = S.G || {}, b = G.b, cip, bas, alt = '';
    if (b && b.kapali) cip = '<span class="gk-cip kapali">KAPALI OTURUM</span>';
    else if (b && b.durum === 'acik') cip = '<span class="gk-cip canli"><i></i>CANLI</span>';
    else if (b && b.durum === 'yoklama') cip = '<span class="gk-cip canli"><i></i>YOKLAMA</span>';
    else if (b && b.durum === 'arada') cip = '<span class="gk-cip ara">ARA</span>';
    else cip = '<span class="gk-cip yok">TOPLANTI YOK</span>';
    if (b) {
      bas = 'TBMM Genel Kurulu · ' + birlesimAdi(b);
      alt = tarih(b.plan_bas) + ' · ' + (b.durum === 'arada' ? 'Oturum <span data-geri="' + new Date(b.ara_bit).getTime() + '"></span> sonra devam edecek' : 'Bitişe <span data-geri="' + new Date(b.bitis).getTime() + '"></span>') +
        (b.uzatma ? ' · süre ' + b.uzatma + ' kez uzatıldı' : '');
    } else if (G.sonraki) { bas = 'TBMM Genel Kurulu'; alt = (G.sonraki.tur === 'olaganustu' ? 'Olağanüstü toplantı: ' : 'Sonraki birleşim: ') + tarih(G.sonraki.bas) + ' ' + saat(G.sonraki.bas) + ' · <span data-geri="' + new Date(G.sonraki.bas).getTime() + '"></span>'; }
    else { bas = 'TBMM Genel Kurulu'; alt = G.esik && G.esik.dolu ? 'Olağan birleşimler her akşam 21.00–22.00 arasında yapılır.' : 'Meclis\'te henüz görevde milletvekili yok; genel seçim sonuçları kesinleşince Meclis toplanır.'; }
    var yon = b && b.yoneten ? '<span>' + I.tokmak + 'Başkan: ' + esc(b.yoneten.ad) + (b.yoneten.baskan ? '' : ' (Başkanvekili)') + '</span>' : b ? '<span>' + I.tokmak + 'Başkanlık kürsüsü boş · oturum kendiliğinden yürüyor</span>' : '';
    return cip + '<div class="orta"><b>' + esc(bas) + '</b><small>' + alt + '</small></div>' +
      '<div class="gk-izl"><span>' + I.goz + sayi(S.salon.izleyici) + ' izleyici</span><span>' + I.el + sayi(S.salon.vekil) + ' vekil salonda</span>' + yon + '</div>';
  }
  function kursuHtml() {
    var G = S.G || {}, b = G.b, k = G.kursu;
    if (!b) return sonBirlesimHtml();
    if (b.durum === 'arada') return '<div class="gk-kart"><h3>Birleşime ara verildi</h3><p>' + (b.ara_neden === 'yoklama' ? 'Toplantı yeter sayısı bulunamadı. ' : b.ara_neden && b.ara_neden.indexOf('karar:') === 0 ? 'Karar yeter sayısı bulunamadı. ' : '') +
      'Oturum <b data-geri="' + new Date(b.ara_bit).getTime() + '"></b> sonra yeniden açılacak.</p></div>';
    if (!k) {
      var akt = (G.gundem || []).find(function (g) { return g.id === b.aktif; });
      return '<div class="gk-kart"><div class="gk-kursu"><div class="pp" style="display:flex;align-items:center;justify-content:center;background:#232b4a;color:var(--gold)">' + I.mik + '</div><div class="ad"><b>Kürsü boş</b><small>' +
        (akt ? 'Gündemde: ' + esc(akt.baslik) : 'Gündem maddesi bekleniyor') + (G.sira_sayi ? ' · Söz sırasında ' + G.sira_sayi + ' kişi' : '') + '</small></div></div></div>';
    }
    var kisi = k.kisi || {}, basladi = !!k.bas, bit = new Date(k.bit).getTime(), bas = basladi ? new Date(k.bas).getTime() : new Date(k.verildi).getTime();
    var yuzde = Math.min(100, Math.round(100 * (k.kullanilan || 0) / Math.max(1, k.kelime)));
    var pp = typeof portre === 'function' ? portre(kisi.kad, kisi.renk, 58) : '';
    return '<div class="gk-kart altin"><div class="gk-kursu"><div class="pp">' + pp + '</div><div class="ad"><b>' + esc(kisi.rol ? kisi.rol + ' ' : '') + esc(kisi.ad) + (kisi.il ? ' (' + esc(kisi.il) + ')' : '') + '</b><small>' +
      (kisi.kisa ? '<span style="color:' + esc(kisi.renk || '#ccc') + ';font-weight:800">' + esc(kisi.kisa) + '</span> · ' : '') + esc(k.tur_ad) + (k.ek ? ' · ek süre' : '') + '</small>' +
      (basladi ? '<span class="gk-mikrofon">' + I.mik + 'MİKROFON AÇIK</span>' : '<span class="gk-mikrofon" style="color:var(--gold2)">KÜRSÜYE GELİYOR</span>') + '</div>' +
      '<div class="gk-sure"><span data-geri="' + bit + '"></span><small>' + (basladi ? 'KALAN' : 'BEKLENİYOR') + '</small></div></div>' +
      (k.konu ? '<div class="gk-not">Konu: <b>' + esc(k.konu) + '</b></div>' : '') +
      '<div class="gk-bar" data-cubuk="' + bas + ':' + bit + '"><i style="width:0%"></i></div>' +
      '<div class="gk-bar-yazi"><span>Süre</span><span>' + sure(Math.round((bit - bas) / 1000)) + '</span></div>' +
      '<div class="gk-bar' + (yuzde >= 85 ? ' kirmizi' : '') + '"><i style="width:' + yuzde + '%"></i></div>' +
      '<div class="gk-bar-yazi"><span>Kelime hakkı</span><span>' + (k.kullanilan || 0) + ' / ' + k.kelime + '</span></div></div>';
  }
  function sonBirlesimHtml() {
    var G = S.G || {}, s = G.son, h = '';
    if (G.sonraki) h += '<div class="gk-kart altin"><h3>' + (G.sonraki.tur === 'olaganustu' ? 'Olağanüstü toplantı çağrısı' : 'Genel Kurul toplanacak') + '</h3><p>' + esc(tarih(G.sonraki.bas)) + ', saat <b>' + saat(G.sonraki.bas) + '</b> · <b data-geri="' + new Date(G.sonraki.bas).getTime() + '"></b> kaldı.' +
      (G.sonraki.gerekce ? '<br>Gerekçe: ' + esc(G.sonraki.gerekce) : '') + '</p><p class="gk-not">Birleşim açılınca milletvekilleri elektronik yoklamada "Buradayım" der; toplantı yeter sayısı ' + ((G.esik || {}).toplanti || '—') + '.</p></div>';
    else if (!(G.esik && G.esik.dolu)) h += '<div class="gk-kart altin"><h3>Meclis henüz toplanmadı</h3><p>Genel seçimle gelen milletvekilleri görevine başlayınca Genel Kurul her akşam 21.00\'de toplanır. İlk birleşimde milletvekilleri andiçer.</p></div>';
    if (s && s.ozet) {
      var o = s.ozet || {}, ht = o.hatip;
      h += '<div class="gk-kart"><h3>Son birleşim: ' + esc(birlesimAdi(s)) + '</h3><p>' + (s.durum === 'toplanamadi' ? 'Toplantı yeter sayısı bulunamadığı için Genel Kurul toplanamadı.' : esc(gunAy(s.acilis)) + ' · ' + (o.sure_dk || 0) + ' dakika sürdü.') + '</p>' +
        (s.durum !== 'toplanamadi' ? '<div class="gk-ozet"><div><b>' + (o.konusma || 0) + '</b><span>konuşma</span></div><div><b>' + (o.yoklama || 0) + '</b><span>yoklamada</span></div><div><b>' + (o.alkis || 0) + '</b><span>alkış</span></div></div>' : '') +
        (ht ? '<div class="gk-not">Günün hatibi: <b>' + esc(ht.ad) + '</b>' + (ht.kisa ? ' (' + esc(ht.kisa) + ')' : '') + ' · ' + (ht.alkis || 0) + ' alkış</div>' + (ht.alinti ? '<div class="gk-alinti">“' + esc(String(ht.alinti).replace(/[.…\s]+$/, '')) + '…”</div>' : '') : '') +
        ((o.oylamalar || []).length ? '<div class="gk-not">' + o.oylamalar.map(function (x) { return esc(x.baslik) + ': <b>' + (x.durum === 'kabul' ? 'kabul edildi' : 'kabul edilmedi') + '</b> (' + x.kabul + '–' + x.ret + ')'; }).join('<br>') + '</div>' : '') +
        '<button type="button" class="gk-d cizgi" data-eylem="tutanak" data-id="' + s.id + '">' + I.arsiv + 'Tutanağı oku</button></div>';
    }
    return h;
  }
  function oylamaKart(baslik, alt, k, r, c, partiler, bit, gizli) {
    var top = Math.max(1, k + r + c);
    return '<div class="gk-kart altin"><h3>' + baslik + '</h3><p>' + alt + (bit ? ' · <b data-geri="' + new Date(bit).getTime() + '"></b>' : '') + '</p>' +
      '<div class="gk-oyl"><i style="width:' + (100 * k / top) + '%;background:var(--ok)"></i><i style="width:' + (100 * c / top) + '%;background:var(--ck)"></i><i style="width:' + (100 * r / top) + '%;background:var(--no)"></i></div>' +
      '<div class="gk-say3"><div><b style="color:#6ee7a6">' + k + '</b><span>Kabul</span></div><div><b style="color:#ff8a80">' + r + '</b><span>Ret</span></div><div><b style="color:#ffd27a">' + c + '</b><span>Çekimser</span></div></div>' +
      (!gizli && (partiler || []).length ? '<div class="gk-partiler">' + partiler.map(function (p) { return '<span><i style="background:' + esc(p.renk || '#8E97B5') + '"></i>' + esc(p.kisa || 'Bağımsız') + ' ' + p.k + '/' + p.r + '/' + p.c + '</span>'; }).join('') + '</div>' : '') +
      (gizli ? '<div class="gk-not">Anayasa değişikliği gizli oyla oylanır; kimin ne oy verdiği görünmez.</div>' : '');
  }
  function panoHtml() {
    var G = S.G || {}, B = S.B || {}, b = G.b, h = '';
    if (!b) return '';
    if (G.yoklama && G.yoklama.sonuc === 'acik') {
      var y = G.yoklama, yz = Math.min(100, Math.round(100 * (y.sayi || 0) / Math.max(1, y.yeter)));
      h += '<div class="gk-kart altin"><h3>Elektronik yoklama</h3><p>' + (y.neden === 'istem' ? 'Yoklama istendi. ' : '') + 'Milletvekilleri "Buradayım" düğmesine basıyor · <b data-geri="' + new Date(y.bit).getTime() + '"></b></p>' +
        '<div class="gk-bar"><i style="width:' + yz + '%"></i></div><div class="gk-bar-yazi"><span>' + (y.sayi || 0) + ' milletvekili hazır</span><span>Toplantı yeter sayısı ' + y.yeter + '</span></div></div>';
    }
    if (G.yemin != null) h += '<div class="gk-kart altin"><h3>Andiçme töreni</h3><p>Anayasanın 81\'inci maddesi gereği milletvekilleri andiçiyor. Şu ana kadar <b>' + G.yemin + '</b> milletvekili andiçti.</p></div>';
    if (G.oylama) {
      var o = G.oylama, acik = o.durum === 'acik';
      h += oylamaKart(acik ? esc(o.baslik) + ' oylarınıza sunuyorum' : esc(o.baslik) + (o.durum === 'kabul' ? ' — kabul edildi' : o.durum === 'ret' ? ' — kabul edilmedi' : ' — sonuçlandı'),
        acik ? 'Kabul edenler… Kabul etmeyenler…' + (o.yeter_istendi ? ' Karar yeter sayısı aranıyor (' + o.karar_yeter + ').' : '') : 'İşaret oylaması sonucu', o.kabul, o.ret, o.cekimser, o.partiler, acik ? o.bit : null, false) +
        (acik && B.vekil && !B.baskan ? '<div class="gk-not">Oyun: <b>' + ({ kabul: 'Kabul', ret: 'Ret', cekimser: 'Çekimser' }[B.oyum] || 'henüz kullanmadın') + '</b></div>' : '') +
        (acik && B.grup_parti && !o.yeter_istendi ? '<button type="button" class="gk-d cizgi" data-eylem="yeter" data-id="' + o.id + '">Karar yeter sayısı iste</button>' : '') + '</div>';
    }
    (G.kanunlar || []).forEach(function (k) {
      var benimOy = (B.kanun_oylarim || {})[k.id], gizli = k.tur === 'anayasa';
      h += oylamaKart('Elektronik oylama: ' + esc(k.baslik), (k.durum === 'israr' ? 'Israr oylaması' : 'Kanun teklifinin tümü') + (k.no ? ' · ' + k.no + ' sıra sayılı' : ''), k.kabul, k.ret, k.cekimser, k.partiler, k.bit, gizli) +
        (B.vekil && !B.baskan ? '<div class="gk-not">Oyun: <b>' + ({ kabul: 'Kabul', ret: 'Ret', cekimser: 'Çekimser' }[benimOy] || 'henüz kullanmadın') + '</b></div><div class="gk-uc">' +
          [['kabul', 'EVET', 'evet'], ['ret', 'HAYIR', 'hayir'], ['cekimser', 'ÇEKİMSER', 'cek']].map(function (x) {
            return '<button type="button" class="gk-d ' + x[2] + (benimOy === x[0] ? ' secili' : '') + '" data-eylem="kanunoy" data-id="' + k.id + '" data-oy="' + x[0] + '">' + x[1] + '</button>';
          }).join('') + '</div>' : '') +
        '<button type="button" class="gk-d cizgi" data-eylem="kanun" data-id="' + k.id + '">Teklifin metni ve gerekçesi</button></div>';
    });
    return h;
  }

  /* ---------------------------------------------------------- tutanak satırları */
  function adHtml(x) {
    var nokta = x.renk ? '<i style="background:' + esc(x.renk) + '" title="' + esc(x.kisa || '') + '"></i>' : '';
    return '<span class="ad">' + nokta + esc(buyuk((x.rol ? x.rol + ' ' : '') + (x.ad || x.kad || ''))) + (x.il ? ' (' + esc(x.il) + ')' : '') + ' –</span> ';
  }
  function satirHtml(x, canli) {
    var G = S.G || {}, B = S.B || {}, m = esc(x.m).replace(/\n/g, '<br>'), id = ' data-tid="' + x.id + '"';
    if (x.gz) return '<p class="gk-t gz"' + id + '>' + m + '</p>';
    var mod = canli && (B.mod || B.yonetici) && ['konusma', 'laf', 'baskan', 'yemin'].indexOf(x.tur) >= 0 ? ' <button type="button" class="gk-mini cizgi" style="min-height:28px;min-width:0;padding:2px 8px;color:#6a6252;box-shadow:inset 0 0 0 1px #cfc6ad;font-size:12px" data-eylem="kaldir" data-id="' + x.id + '">Tutanaktan çıkar</button>' : '';
    switch (x.tur) {
      case 'baskan': return '<p class="gk-t bsk"' + id + '><span class="ad">BAŞKAN –</span> ' + m + mod + '</p>';
      case 'laf': return '<p class="gk-t laf"' + id + '>' + adHtml(x) + m + (canli ? tepkiDugme(x, true) : '') + mod + '</p>';
      case 'tepki': return '<p class="gk-t tepki"' + id + '>' + m + '</p>';
      case 'gundem': return '<p class="gk-t gdm"' + id + '>' + esc(buyuk(x.m)) + '</p>';
      case 'oylama': return '<p class="gk-t oy"' + id + '>' + m + '</p>';
      case 'yoklama': case 'sistem': return '<p class="gk-t sis"' + id + '>' + m + '</p>';
      case 'yemin': return '<p class="gk-t ym"' + id + '>' + adHtml(x) + (S.yeminGosterildi ? '<i>andiçti.</i>' : (S.yeminGosterildi = true, '“' + m + '”')) + mod + '</p>';
      default:
        var tur = x.v && x.v.ilk ? '<small class="tur">' + esc(turAd(x.st)) + (x.v.konu ? ' · ' + esc(x.v.konu) : '') + '</small>' : '';
        return '<div class="gk-t kon"' + id + '>' + tur + '<p style="margin:0">' + adHtml(x) + m + '</p>' + (canli ? tepkiDugme(x, false) : '') + mod + '</div>';
    }
  }
  function turAd(k) { return { kisisel: 'Şahsı adına', grup: 'Grup adına', hukumet: 'Hükümet adına', yerinden: 'Yerinden', satasma: 'Sataşma nedeniyle', gundem_disi: 'Gündem dışı', usul: 'Usul hakkında' }[k] || 'Konuşma'; }
  function tepkiDugme(x, lafMi) {
    var G = S.G || {}, B = S.B || {}, t = (G.tepki || {})[x.id] || [0, 0, 0], ben = (B.tepkilerim || {})[x.id], benimKonusma = x.kad && x.kad === benim();
    var acik = G.b && ['acik', 'yoklama', 'arada'].indexOf(G.b.durum) >= 0 && G.b.id === S.bid;
    var h = '';
    if (!lafMi && acik && !benimKonusma) {
      h += '<button type="button" class="' + (ben === 'alkis' ? 'secili' : '') + '" data-eylem="tepki" data-id="' + x.id + '" data-tur="alkis" aria-label="Alkışla">' + I.alkis + '<span>' + (t[0] || '') + '</span></button>' +
        '<button type="button" class="' + (ben === 'protesto' ? 'secili' : '') + '" data-eylem="tepki" data-id="' + x.id + '" data-tur="protesto" aria-label="Protesto et">' + I.protesto + '<span>' + (t[1] || '') + '</span></button>';
    } else if (!lafMi && (t[0] || t[1])) h += '<span class="gal">' + (t[0] ? t[0] + ' alkış' : '') + (t[0] && t[1] ? ' · ' : '') + (t[1] ? t[1] + ' protesto' : '') + '</span>';
    if (!lafMi && t[2]) h += '<span class="gal">Halk galerisinden ' + t[2] + ' tepki</span>';
    var dk20 = simdiMs() - new Date(x.z).getTime() < 19 * 60e3;
    if (acik && (B.vekil || B.hukumet) && !benimKonusma && dk20 && G.b.durum === 'acik') h += '<button type="button" data-eylem="satasma" data-id="' + x.id + '">Sataşma</button>';
    return h ? '<div class="gk-tp">' + h + '</div>' : '';
  }
  function akisBasHtml() {
    var G = S.G || {}, b = G.b;
    if (b && b.id === S.bid) return '<div class="gk-akis-bas"><b>TÜRKİYE BÜYÜK MİLLET MECLİSİ</b><b>GENEL KURUL TUTANAĞI</b><small>' + esc(birlesimAdi(b)) + ' · ' + esc(gunAy(b.plan_bas)) + '</small></div>';
    if (G.son && G.son.id === S.bid) return '<div class="gk-akis-bas"><b>GENEL KURUL TUTANAĞI</b><small>' + esc(birlesimAdi(G.son)) + ' · ' + esc(gunAy(G.son.acilis)) + ' · kapandı</small></div>';
    return '<div class="gk-akis-bas"><b>GENEL KURUL TUTANAĞI</b><small>Henüz birleşim yapılmadı.</small></div>';
  }
  function akisEkle(yeni) {
    var ak = $1('#gkAkis'); if (!ak) return;
    var altta = ak.scrollTop + ak.clientHeight >= ak.scrollHeight - 80;
    var bas = $1('.gk-akis-bas', ak), yeniBas = akisBasHtml();
    if (!bas) ak.insertAdjacentHTML('afterbegin', yeniBas); else if (bas.outerHTML !== yeniBas) bas.outerHTML = yeniBas;
    if (yeni.length) {
      ak.insertAdjacentHTML('beforeend', yeni.map(function (x) { return satirHtml(x, true); }).join(''));
      if (typeof portreleriTazele === 'function') { try { portreleriTazele(ak); } catch (_) {} }
      if (altta || S.ilk) ak.scrollTop = ak.scrollHeight;
      else { var y = $1('#gkYeni'); if (y) y.hidden = false; }
    }
  }
  function tepkileriTazele() {
    var ak = $1('#gkAkis'); if (!ak) return;
    var G = S.G || {}, B = S.B || {}, imza = JSON.stringify([G.tepki, B.tepkilerim, G.gizlenen, G.b && G.b.durum]);
    if (S.imza.tepki === imza) return; S.imza.tepki = imza;
    $$('[data-tid]', ak).forEach(function (el) {
      var id = +el.getAttribute('data-tid'), x = S.satir[id]; if (!x) return;
      if ((G.gizlenen || []).indexOf(id) >= 0 && !x.gz) { x.gz = true; x.m = '(Bu bölüm Oyun Yönetimince tutanaktan çıkarıldı.)'; }
      if (x.gz || x.tur === 'konusma' || x.tur === 'laf') { var yeni = satirHtml(x, true); if (el.outerHTML !== yeni) el.outerHTML = yeni; }
    });
  }

  /* ---------------------------------------------------------- Başkanlık paneli */
  function baskanHtml() {
    var G = S.G || {}, B = S.B || {}, b = G.b;
    if (!B.yonetebilir) return '';
    var h = '', acik = b && b.durum === 'acik';
    if (!b) {
      if (G.sonraki && new Date(G.sonraki.bas).getTime() - simdiMs() < 2.5 * 60e3) h += '<button type="button" class="gk-d altin" data-eylem="ac">' + I.tokmak + 'Birleşimi aç</button>';
      else h += '<p class="gk-not">Birleşim saati gelince "Birleşimi aç" düğmesi burada belirir. Açmazsan birleşim 5 dakika içinde kendiliğinden açılır.</p>';
      if (B.baskan || B.cb || B.yonetici) h += '<button type="button" class="gk-d cizgi" data-eylem="olaganustu">Meclisi olağanüstü toplantıya çağır</button>';
      return '<details class="gk-kart gk-bsk"' + (S.acikBsk ? ' open' : '') + '><summary>Başkanlık kürsüsü<small>Meclis Başkanlığı</small></summary>' + h + '</details>';
    }
    var benYonetiyorum = b.yoneten && b.yoneten.kad === benim();
    h += '<p class="gk-not">' + (benYonetiyorum ? 'Oturumu sen yönetiyorsun. Kararların tutanağa "BAŞKAN –" olarak geçer.' : 'Bir işlem yaptığında oturumu yönetmeye başlarsın.') + '</p>';
    if (G.kursu) h += '<h4>Kürsüde</h4><div class="gk-grup"><button type="button" class="gk-mini altin" data-eylem="eksure" data-id="' + G.kursu.id + '"' + (G.kursu.ek ? ' disabled' : '') + '>+1 dk ek süre</button>' +
      '<button type="button" class="gk-mini" style="background:#8a1f1a" data-eylem="kes" data-id="' + G.kursu.id + '">Sözü kes</button></div>';
    var L = G.sira || [];
    h += '<h4>Söz sırası (' + (G.sira_sayi || 0) + ')</h4>' + (L.length ? L.map(function (x, i) {
      var gd = x.tur === 'gundem_disi';
      return '<div class="gk-satir"><div class="orta"><b>' + (i + 1) + '. ' + esc(x.kisi && x.kisi.ad) + (x.kisi && x.kisi.kisa ? ' · ' + esc(x.kisi.kisa) : '') + '</b><small>' + esc(x.tur_ad) + (x.konu ? ' · ' + esc(x.konu) : '') + ' · ' + saat(x.istek) + '</small></div>' +
        '<button type="button" class="gk-mini altin" data-eylem="ver" data-id="' + x.id + '"' + (G.kursu || !acik ? ' disabled' : '') + '>Söz ver</button></div>' +
        (gd ? '' : '<div class="gk-grup" style="margin:-2px 0 6px"><button type="button" class="gk-mini cizgi" data-eylem="sira" data-id="' + x.id + '" data-yon="1" aria-label="Öne al">Öne al</button><button type="button" class="gk-mini cizgi" data-eylem="sira" data-id="' + x.id + '" data-yon="2" aria-label="Yukarı">▲</button>' +
          '<button type="button" class="gk-mini cizgi" data-eylem="sira" data-id="' + x.id + '" data-yon="3" aria-label="Aşağı">▼</button><button type="button" class="gk-mini cizgi" data-eylem="reddet" data-id="' + x.id + '">Reddet</button></div>');
    }).join('') : '<p class="gk-not">Söz isteyen yok. 90 saniye işlem yapmazsan sıradaki konuşmacıya söz kendiliğinden verilir.</p>');
    var G2 = G.gundem || [], akt = G2.find(function (g) { return g.id === b.aktif; });
    h += '<h4>Gündem</h4>' + G2.map(function (g) {
      return '<div class="gk-gd ' + (g.id === b.aktif ? 'aktif' : g.durum !== 'bekliyor' ? 'bitti' : '') + '"><span class="n">' + g.sira + '</span><span class="orta">' + esc(g.baslik) + '</span>' +
        (g.durum === 'bekliyor' && acik ? '<button type="button" class="gk-mini cizgi" data-eylem="madde" data-id="' + g.id + '">Geç</button>' : '') + '</div>';
    }).join('');
    h += '<div class="gk-grup"><button type="button" class="gk-mini" data-eylem="sonraki"' + (acik && !G.kursu ? '' : ' disabled') + '>Sonraki maddeye geç</button>' +
      (akt && (akt.tur === 'grup_onerisi' || akt.tur === 'genel_gorusme_on') ? '<button type="button" class="gk-mini altin" data-eylem="oylamaya"' + (G.kursu || (G.oylama && G.oylama.durum === 'acik') ? ' disabled' : '') + '>Oylamaya sun</button>' : '') + '</div>';
    var bitis = new Date(b.bitis).getTime();
    h += '<h4>Oturum</h4><div class="gk-grup">' + [5, 10, 15].map(function (d) { return '<button type="button" class="gk-mini cizgi" data-eylem="ara" data-dk="' + d + '"' + (acik ? '' : ' disabled') + '>' + d + ' dk ara</button>'; }).join('') + '</div>' +
      '<div class="gk-grup"><button type="button" class="gk-mini" data-eylem="yoklamaiste"' + (acik && !G.kursu ? '' : ' disabled') + '>Yoklama yap</button>' +
      (bitis - simdiMs() < 25 * 60e3 && (b.uzatma || 0) < (b.uzatma_azami || 2) ? '<button type="button" class="gk-mini" data-eylem="uzatma"' + (acik && !G.kursu ? '' : ' disabled') + '>Süre uzatımını oyla</button>' : '') +
      (b.kapali ? '<button type="button" class="gk-mini altin" data-eylem="acikoturum">Açık oturuma geç</button>' : '') + '</div>';
    (G.kanunlar || []).forEach(function (k) { h += '<button type="button" class="gk-d cizgi" data-eylem="zil" data-id="' + k.id + '">Oylama zili çal: ' + esc(k.baslik) + '</button>'; });
    var gd = (G.gundem_disi || []).filter(function (d) { return d.durum === 'bekliyor' || d.durum === 'secildi'; });
    if (gd.length) h += '<h4>Gündem dışı söz istemleri</h4>' + gd.map(function (d) {
      return '<div class="gk-satir"><div class="orta"><b>' + esc(d.kisi && d.kisi.ad) + '</b><small>' + esc(d.konu) + '</small></div><button type="button" class="gk-mini ' + (d.durum === 'secildi' ? 'altin' : 'cizgi') + '" data-eylem="gdsec" data-id="' + d.id + '" data-sec="' + (d.durum !== 'secildi') + '">' + (d.durum === 'secildi' ? 'Seçildi' : 'Seç') + '</button></div>';
    }).join('');
    h += '<h4>Düzen</h4><div class="gk-grup"><button type="button" class="gk-mini cizgi" data-eylem="disiplin">Disiplin cezası</button><button type="button" class="gk-mini cizgi" data-eylem="aciklama">Başkanlık açıklaması</button></div>';
    return '<details class="gk-kart gk-bsk" id="gkBskD"' + (S.acikBsk ? ' open' : '') + '><summary>Başkanlık kürsüsü<small>' + (benYonetiyorum ? 'Yönetiyorsun' : 'Meclis Başkanlığı') + '</small></summary>' + h + '</details>';
  }

  /* ---------------------------------------------------------- alt eylem şeridi */
  function dockHtml() {
    var G = S.G || {}, B = S.B || {}, b = G.b, acik = b && b.durum === 'acik';
    var vekil = !!B.vekil, hk = !!B.hukumet, h = '';
    if (!vekil && !hk) {
      return '<div class="bas"><span><b>Halk galerisindesin</b><br>Konuşmaları alkışlayabilir ya da protesto edebilirsin; kürsüde yalnız milletvekilleri ve Hükümet konuşur.</span></div>' +
        '<button type="button" class="gk-d cizgi" data-eylem="diger">Meclis çalışmaları ve tutanaklar</button>';
    }
    if (B.cikarildi) return '<div class="bas"><span><b>Meclisten geçici çıkarma cezan sürüyor.</b><br>Bu birleşimde salona giremez, söz alamaz ve oy kullanamazsın.</span></div>';
    if (!b) {
      return '<div class="bas"><span><b>Genel Kurul toplantıda değil</b><br>Birleşim açılınca burada söz isteyip konuşabilirsin.</span></div>' +
        '<div class="gk-iki">' + (vekil ? '<button type="button" class="gk-d" data-eylem="gundemdisi">Gündem dışı söz iste</button>' : '') + '<button type="button" class="gk-d cizgi" data-eylem="diger">Diğer işlemler</button></div>' +
        (B.gundem_disi ? '<div class="gk-not">Gündem dışı söz istemin: “' + esc(B.gundem_disi.konu) + '” · ' + ({ bekliyor: 'Başkanlık seçimini bekliyor', secildi: 'seçildin', konustu: 'konuştun', dustu: 'sıra gelmedi' }[B.gundem_disi.durum] || B.gundem_disi.durum) + '</div>' : '');
    }
    if (G.yoklama && G.yoklama.sonuc === 'acik' && vekil) {
      return B.yoklamada ? '<div class="bas"><span><b>Yoklamaya katıldın</b> · Buradasın. Yoklama <b data-geri="' + new Date(G.yoklama.bit).getTime() + '"></b> sonra biter.</span></div>' :
        '<button type="button" class="gk-d altin dev" data-eylem="buradayim">BURADAYIM</button><div class="gk-not" style="text-align:center">Elektronik yoklama · <b data-geri="' + new Date(G.yoklama.bit).getTime() + '"></b></div>';
    }
    if (G.oylama && G.oylama.durum === 'acik' && vekil && !B.baskan) {
      var o = G.oylama;
      return '<div class="bas"><span><b>' + esc(o.baslik) + ' oyluyoruz</b></span><span data-geri="' + new Date(o.bit).getTime() + '"></span></div><div class="gk-uc">' +
        [['kabul', 'KABUL', 'evet'], ['ret', 'RET', 'hayir'], ['cekimser', 'ÇEKİMSER', 'cek']].map(function (x) { return '<button type="button" class="gk-d ' + x[2] + (B.oyum === x[0] ? ' secili' : '') + '" data-eylem="oy" data-id="' + o.id + '" data-oy="' + x[0] + '">' + x[1] + '</button>'; }).join('') + '</div>';
    }
    if (G.yemin != null && vekil && !B.yemin && acik) return '<button type="button" class="gk-d altin dev" data-eylem="andic">ANDİÇİYORUM</button><div class="gk-not" style="text-align:center">Anayasa m.81 · Andın tutanağa geçer.</div>';
    if (B.soz) {
      var kalan = Math.max(0, B.soz.kelime - (B.soz.kullanilan || 0));
      return '<div class="bas"><span><b>Söz sende · ' + esc(B.soz.ad) + '</b></span><span class="gk-say" id="gkSay" data-kalan="' + kalan + '"></span></div>' +
        (B.soz.bas ? '<div class="gk-not">Mikrofon açık · <b data-geri="' + new Date(B.soz.bit).getTime() + '"></b> kaldı. Konuşmanı bölümler hâlinde gönderebilirsin.</div>' :
          '<div class="gk-not">Kürsüye çık: süren (' + sure(B.soz.sure) + ') ilk bölümü gönderdiğinde başlar. <b data-geri="' + new Date(B.soz.bit).getTime() + '"></b> içinde başlamazsan söz düşer.</div>') +
        '<textarea id="gkMetin" maxlength="1500" placeholder="Sayın Başkan, değerli milletvekilleri…" aria-label="Konuşma metni"></textarea>' +
        '<div class="gk-iki"><button type="button" class="gk-d altin" data-eylem="konus">' + I.mik + 'Konuş</button><button type="button" class="gk-d cizgi" data-eylem="bitir">Sözümü bitir</button></div>';
    }
    if (B.bekleyen) {
      return '<div class="bas"><span><b>Söz sırasındasın · ' + B.bekleyen.sira + '. sıra</b><br>' + esc(B.bekleyen.ad) + ' · en çok ' + B.bekleyen.kelime + ' kelime. Konuşmanı şimdiden hazırlayabilirsin.</span></div>' +
        '<textarea id="gkMetin" maxlength="1500" placeholder="Konuşmanı hazırla; söz sana gelince gönder." aria-label="Konuşma taslağı"></textarea>' +
        '<button type="button" class="gk-d cizgi" data-eylem="geri">Söz istemimi geri al</button>';
    }
    var lafVar = acik && G.kursu && G.kursu.kullanilan > 0 && !(G.kursu.kisi && G.kursu.kisi.kad === benim());
    var bekle = B.bekleme_bitis && new Date(B.bekleme_bitis).getTime() > simdiMs();
    h += '<div class="gk-iki"><button type="button" class="gk-d altin" data-eylem="soziste"' + (acik ? '' : ' disabled') + '>' + I.el + 'Söz iste</button><button type="button" class="gk-d cizgi" data-eylem="diger">Diğer</button></div>';
    if (bekle) h += '<div class="gk-not">Az önce konuştun; <b data-geri="' + new Date(B.bekleme_bitis).getTime() + '"></b> sonra yeniden söz isteyebilirsin.</div>';
    if (lafVar) {
      var lafBekle = B.laf_bitis && new Date(B.laf_bitis).getTime() > simdiMs();
      h += '<div style="display:flex;gap:8px;align-items:flex-end"><input id="gkLaf" maxlength="90" placeholder="Sıralardan söz at (en çok 12 kelime)" aria-label="Sıralardan söz at" style="flex:1"' + (B.laf_kalan === 0 ? ' disabled' : '') + '>' +
        '<button type="button" class="gk-mini altin" data-eylem="laf" style="min-height:46px"' + (B.laf_kalan === 0 || lafBekle ? ' disabled' : '') + '>At</button></div>' +
        '<div class="gk-not" style="font-size:12.5px">Bu konuşmaya ' + (B.laf_kalan == null ? 3 : B.laf_kalan) + ' hakkın kaldı' + (lafBekle ? ' · <span data-geri="' + new Date(B.laf_bitis).getTime() + '"></span>' : '') + '. Hakaret ve küfür disiplin cezası getirir.</div>';
    }
    if (!acik && b.durum === 'arada') h = '<div class="bas"><span><b>Birleşime ara verildi</b> · <span data-geri="' + new Date(b.ara_bit).getTime() + '"></span> sonra devam</span></div>' + '<button type="button" class="gk-d cizgi" data-eylem="diger">Diğer işlemler</button>';
    return h;
  }

  /* ---------------------------------------------------------- çizim */
  function yerlestir(id, html, korunur) {
    var el = $1('#' + id); if (!el) return;
    if (S.imza[id] === html) return; S.imza[id] = html;
    var deger = null, odak = false, lafDeger = null;
    if (korunur) { var ta = $1('#gkMetin'); if (ta) { deger = ta.value; odak = document.activeElement === ta; } var lf = $1('#gkLaf'); if (lf) lafDeger = lf.value; }
    el.innerHTML = html;
    if (korunur) {
      var ta2 = $1('#gkMetin');
      if (ta2) { ta2.value = deger != null ? deger : taslakAl(); if (odak) ta2.focus(); ta2.oninput = function () { taslakKaydet(ta2.value); sayac(); }; sayac(); }
      var lf2 = $1('#gkLaf'); if (lf2 && lafDeger) lf2.value = lafDeger;
      if (lf2) lf2.onkeydown = function (ev) { if (ev.key === 'Enter') { ev.preventDefault(); eylem('laf'); } };
    }
    if (typeof portreleriTazele === 'function') { try { portreleriTazele(el); } catch (_) {} }
  }
  function taslakAl() { try { return localStorage.getItem('gkTaslak') || ''; } catch (_) { return ''; } }
  function taslakKaydet(v) { try { localStorage.setItem('gkTaslak', v || ''); } catch (_) {} }
  function sayac() {
    var ta = $1('#gkMetin'), el = $1('#gkSay'); if (!ta || !el) return;
    var kalan = +el.getAttribute('data-kalan') || 0, n = kelime(ta.value);
    el.textContent = n + ' / ' + kalan + ' kelime'; el.classList.toggle('asti', n > kalan);
    var b = $1('[data-eylem="konus"]'); if (b) b.disabled = n === 0 || n > kalan;
  }
  function ciz(yeni) {
    if (!$1('#gkSalon')) return;
    yerlestir('gkUst', ustHtml());
    yerlestir('gkLej', lejantHtml());
    koltukGuncelle();
    yerlestir('gkKursu', kursuHtml());
    yerlestir('gkPano', panoHtml());
    yerlestir('gkBaskan', baskanHtml());
    yerlestir('gkDock', dockHtml(), true);
    akisEkle(yeni || []);
    tepkileriTazele();
    var G = S.G || {}, B = S.B || {}, perde = $1('#gkPerde');
    if (perde) perde.hidden = !(G.b && G.b.kapali && !B.vekil && !B.hukumet && !B.yonetici);
    tik();
  }
  function tik() {
    if (!$1('#gkSalon')) { dur(); return; }
    var now = simdiMs();
    $$('#gkSalon [data-geri]').forEach(function (el) {
      var bit = +el.getAttribute('data-geri'), kalan = Math.max(0, (bit - now) / 1000);
      el.textContent = mmss(kalan);
      if (kalan <= 0 && !el._bitti) { el._bitti = true; setTimeout(function () { yokla(); }, 1500); }
    });
    $$('#gkSalon [data-cubuk]').forEach(function (el) {
      var p = el.getAttribute('data-cubuk').split(':'), a = +p[0], z = +p[1], i = el.firstElementChild;
      if (i) i.style.width = Math.max(0, Math.min(100, 100 * (now - a) / Math.max(1, z - a))) + '%';
      el.classList.toggle('kirmizi', z - now < 30e3);
    });
  }
  function dur() { if (S.tik) { clearInterval(S.tik); S.tik = null; } }

  /* ---------------------------------------------------------- veri */
  async function haritaAl(zorla) {
    if (!zorla && S.H && Date.now() - S.Ht < 120e3) return S.H;
    try { S.H = await rpc('gk_salon_harita'); S.Ht = Date.now(); } catch (_) { S.H = S.H || { toplam: 600, partiler: [], vekiller: [] }; }
    return S.H;
  }
  async function yokla(zorla) {
    if (!$1('#gkSalon')) return;
    if (S.mesgul) { S.tekrar = true; return; }
    S.mesgul = true;
    try { isle(await rpc('gk_durum', { p_surum: zorla ? 0 : S.surum, p_son: S.son })); }
    catch (_) {}
    finally { S.mesgul = false; if (S.tekrar) { S.tekrar = false; setTimeout(function () { yokla(); }, 250); } }
  }
  function isle(r) {
    if (!r) return;
    if (r.simdi) S.ofs = new Date(r.simdi).getTime() - Date.now();
    var eski = S.G;
    if (!r.ayni && r.genel) { S.G = r.genel; S.surum = r.surum; }
    if (r.ben) S.B = r.ben;
    if (r.salon) S.salon = r.salon;
    if (r.bid !== S.bid) { S.bid = r.bid; S.satir = {}; S.son = 0; S.yeminGosterildi = false; var ak = $1('#gkAkis'); if (ak) ak.innerHTML = ''; }
    var yeni = (r.yeni || []).filter(function (x) { return !S.satir[x.id]; });
    yeni.forEach(function (x) { S.satir[x.id] = x; if (x.id > S.son) S.son = x.id; });
    // harita: vekil sayısı değiştiyse yenile
    if (S.G && S.G.esik && S.H && (S.H.vekiller || []).length !== S.G.esik.dolu && Date.now() - S.Ht > 30e3) haritaAl(true).then(function () { var k = $1('#gkSvgK'); if (k) { k.innerHTML = svgHtml(); S.imza.kol = ''; koltukGuncelle(); } });
    ciz(yeni);
    if (!S.ilk) sesler(eski, S.G, yeni);
    S.ilk = false;
    izle();
  }
  function sesler(eski, G, yeni) {
    yeni.forEach(function (x) {
      if (x.tur === 'baskan' && /Birleşimini açıyorum|Birleşimi kapatıyorum|oturumunu açıyorum/.test(x.m)) sesCal('tokmak');
      else if (x.tur === 'oylama') sesCal('tokmak');
      else if (x.tur === 'tepki' && /alkış/.test(x.m)) sesCal('alkis');
      else if (x.tur === 'sistem' && /zili/.test(x.m)) sesCal('zil');
    });
    if (G && G.yoklama && G.yoklama.sonuc === 'acik' && !(eski && eski.yoklama && eski.yoklama.id === G.yoklama.id)) sesCal('zil');
    if (G && G.oylama && G.oylama.durum === 'acik' && !(eski && eski.oylama && eski.oylama.id === G.oylama.id)) sesCal('zil');
  }
  function izle() {
    if (!window.CANLI || !CANLI.izle) { if (!S.yedek) S.yedek = setInterval(function () { if (!$1('#gkSalon')) { clearInterval(S.yedek); S.yedek = null; return; } yokla(); }, 7000); return; }
    var B = S.B || {}, G = S.G || {}, etkin = B.vekil || B.hukumet || B.yonetebilir, canli = G.b && ['acik', 'yoklama', 'arada'].indexOf(G.b.durum) >= 0;
    var imza = [etkin, canli, G.sonraki ? G.sonraki.bas : ''].join('|');
    if (S.izleImza === imza && CANLI._ekran && CANLI._ekran().timer) return;
    S.izleImza = imza;
    var sonra = G.sonraki ? new Date(G.sonraki.bas).getTime() - simdiMs() + 2500 : null;
    CANLI.izle({ anahtarlar: ['sohbet:meclis'], tazele: function () { return yokla(); },
      hizliMs: canli ? (etkin ? 5000 : 9000) : 30000, yedekMs: canli ? (etkin ? 15000 : 25000) : 60000, yayilim: canli ? 2500 : 8000,
      pencereMs: etkin ? 1800 : 3500, sonraMs: sonra && sonra > 0 && sonra < 12 * 3600e3 ? sonra : null });
  }

  /* ---------------------------------------------------------- eylemler */
  async function cagir(ad, arg, basari) {
    try { var r = await rpc(ad, arg); if (basari) bildir(basari); await yokla(true); return r; }
    catch (err) { bildir(hata(err), true); yokla(); if (err && typeof err === 'object') err._gosterildi = true; throw err; }
  }
  function form(baslik, aciklama, govde, onay, fn) {
    if (typeof modal !== 'function') return;
    var md = modal('<div class="gk-form"><h3>' + baslik + '</h3>' + (aciklama ? '<p>' + aciklama + '</p>' : '') + govde +
      '<button type="button" class="gk-d altin" id="gkFOk">' + onay + '</button><button type="button" class="gk-d cizgi" id="gkFVaz">Vazgeç</button></div>');
    css();
    $1('#gkFVaz', md).onclick = function () { modalKapat(); };
    $1('#gkFOk', md).onclick = async function () {
      var b = this; b.disabled = true;
      try { await fn(md); modalKapat(); } catch (err) { b.disabled = false; if (!(err && err._gosterildi)) bildir(hata(err), true); }
    };
    var ilk = $1('input,textarea,select', md); if (ilk) setTimeout(function () { try { ilk.focus(); } catch (_) {} }, 60);
    return md;
  }
  async function sozIsteSec() {
    var B = S.B || {}, G = S.G || {}, bekle = B.bekleme_bitis && new Date(B.bekleme_bitis).getTime() > simdiMs();
    var L = (B.turler || []).filter(function (t) { return t.kod !== 'satasma'; });
    if (typeof modal !== 'function') return;
    var md = modal('<div class="gk-form"><h3>Söz iste</h3><p>Sırada ' + (G.sira_sayi || 0) + ' kişi var. Sözü Meclis Başkanlığı verir; Başkanlık salonda değilse sıran gelince söz kendiliğinden verilir. Her söz türünün kelime ve süre sınırı vardır.</p>' +
      L.map(function (t) { return '<button type="button" class="gk-sec" data-tur="' + esc(t.kod) + '"' + (bekle ? ' disabled' : '') + '><b>' + esc(t.ad) + '</b><span>En çok ' + t.kelime + ' kelime · ' + sure(t.sure) + '</span></button>'; }).join('') +
      '<p class="gk-not">Sataşma nedeniyle cevap hakkı için tutanakta ilgili konuşmanın altındaki “Sataşma” düğmesine dokun.</p><button type="button" class="gk-d cizgi" id="gkFVaz">Vazgeç</button></div>');
    css();
    $1('#gkFVaz', md).onclick = function () { modalKapat(); };
    $$('[data-tur]', md).forEach(function (b) { b.onclick = async function () { b.disabled = true; try { await cagir('gk_soz_iste', { p_tur: b.getAttribute('data-tur'), p_hedef: null }, 'Söz istemin Başkanlığa iletildi.'); modalKapat(); } catch (_) { b.disabled = false; } }; });
  }
  function digerMenu() {
    var B = S.B || {}, G = S.G || {}, b = G.b, L = [];
    if (B.vekil) L.push(['gundemdisi', 'Gündem dışı söz iste', b ? 'Bugünkü gündem dışı bölüm geçtiyse yarınki birleşime yazılır.' : 'Bu akşamki birleşimin başında 5 dakikalık konuşma (Başkanlık 3 kişi seçer).']);
    if (B.grup_parti) L.push(['oneri', 'Grup önerisi ver', B.oneri_verdim ? 'Grubun bugün zaten öneri verdi.' : 'Gündem değişikliği, ortak bildiri, genel görüşme açılması ya da süre uzatımı.']);
    if (B.grup_parti && b && b.durum === 'acik') L.push(['yoklamaiste', 'Yoklama iste', 'Grup adına bir birleşimde bir kez.']);
    if ((B.hukumet || B.grup_parti) && b && b.durum === 'acik' && !b.kapali) L.push(['kapali', 'Kapalı oturum iste', 'Genel Kurul oylar; kabul edilirse tutanak gizlenir.']);
    if (B.vekil) L.push(['gg', 'Genel görüşme önergeleri', 'Önerge ver, imzala; yeterli imzayla Genel Kurulda ön görüşmesi yapılır.']);
    L.push(['arsiv', 'Tutanak arşivi', 'Geçmiş birleşimlerin tam tutanakları.']);
    L.push(['merkez', 'Meclis çalışmaları', 'Komisyonlar, soru önergeleri, Meclis araştırması, dilekçeler, halk buluşmaları, vekil karnesi.']);
    if (S.eskiSohbet) L.push(['eski', 'Eski Genel Kurul sohbet kayıtları', 'Salondan önceki dönemin mesajları (yalnız okuma).']);
    var md = modal('<div class="gk-form"><h3>Genel Kurul işlemleri</h3>' + L.map(function (x) { return '<button type="button" class="gk-sec" data-sec="' + x[0] + '"' + (x[0] === 'oneri' && B.oneri_verdim ? ' disabled' : '') + '><b>' + x[1] + '</b><span>' + x[2] + '</span></button>'; }).join('') +
      '<button type="button" class="gk-d cizgi" id="gkFVaz">Kapat</button></div>');
    css();
    $1('#gkFVaz', md).onclick = function () { modalKapat(); };
    $$('[data-sec]', md).forEach(function (b) { b.onclick = function () { modalKapat(); eylem(b.getAttribute('data-sec')); }; });
  }
  async function grupOneriForm() {
    var G = S.G || {};
    var kanunlar = (G.gundem || []).filter(function (g) { return g.tur === 'kanun' || g.tur === 'kanun_oylama'; });
    var gg = []; try { gg = ((await rpc('gk_gg_liste')).liste || []).filter(function (x) { return x.durum === 'bekliyor' || x.durum === 'imza'; }); } catch (_) {}
    form('Siyasi parti grubu önerisi', 'İçtüzük m.19: grup önerisi gündemin başında okunur, lehte-aleyhte konuşulur ve işaret oyuyla oylanır. Grubun günde bir öneri verebilir.',
      '<label for="gkOT">Öneri türü</label><select id="gkOT"><option value="bildiri">Ortak bildiri (Meclis adına açıklama)</option><option value="gundem"' + (kanunlar.length ? '' : ' disabled') + '>Bir kanun teklifini gündemin başına al</option>' +
        '<option value="genel_gorusme"' + (gg.length ? '' : ' disabled') + '>Genel görüşme açılması</option><option value="uzatma"' + (G.b && G.b.durum === 'acik' ? '' : ' disabled') + '>Çalışma süresinin uzatılması</option></select>' +
      '<div id="gkORef" hidden><label for="gkOR">Konu</label><select id="gkOR"></select></div>' +
      '<label for="gkOB">Başlık</label><input id="gkOB" maxlength="120" placeholder="Örn. Depremzedelerle dayanışma bildirisi">' +
      '<label for="gkOM">Öneri metni</label><textarea id="gkOM" maxlength="2000" style="min-height:120px" placeholder="Genel Kurulun… öneriyoruz."></textarea>', 'Öneriyi ver',
      async function (md) {
        var tur = $1('#gkOT', md).value, ref = $1('#gkOR', md).value;
        await cagir('gk_grup_onerisi_ver', { p_tur: tur, p_baslik: $1('#gkOB', md).value, p_metin: $1('#gkOM', md).value, p_ref: ref ? +ref : null }, 'Grup önerin gündeme alındı.');
      });
    var sel = $1('#gkOT'), refK = $1('#gkORef'), refS = $1('#gkOR');
    if (sel) sel.onchange = function () {
      var t = sel.value, L = t === 'gundem' ? kanunlar.map(function (k) { return [k.ref, k.baslik]; }) : t === 'genel_gorusme' ? gg.map(function (x) { return [x.id, x.no + ' · ' + x.konu]; }) : [];
      refK.hidden = !L.length; refS.innerHTML = L.map(function (x) { return '<option value="' + x[0] + '">' + esc(x[1]) + '</option>'; }).join('');
    };
  }
  async function eylem(ad, el) {
    var G = S.G || {}, B = S.B || {}, id = el ? +el.getAttribute('data-id') : null;
    switch (ad) {
      case 'soziste': return sozIsteSec();
      case 'diger': return digerMenu();
      case 'geri': return cagir('gk_soz_geri', {}, 'Söz istemin geri alındı.');
      case 'buradayim': el && (el.disabled = true); try { var r = await cagir('gk_buradayim', {}, 'Buradasın. Yoklamaya katıldın.'); if (r && r.kidem) bildir('Buradasın · +' + String(r.kidem).replace('.', ',') + ' kıdem'); } catch (_) { if (el) el.disabled = false; } return;
      case 'oy': return cagir('gk_oy', { p_oylama: id, p_oy: el.getAttribute('data-oy') }, 'Oyun kaydedildi.');
      case 'kanunoy': return cagir('kanun_oy', { p_id: id, p_oy: el.getAttribute('data-oy') }, 'Oyun kaydedildi.');
      case 'kanun': if (typeof kanunEkrani === 'function') ekranAc(function () { return kanunEkrani(id); }); return;
      case 'yeter': return cagir('gk_karar_yeter_iste', { p_oylama: id }, 'Karar yeter sayısı istendi.');
      case 'andic':
        form('Andiçme', 'Andın Genel Kurul tutanağına geçer.', '<div class="gk-alinti" style="font-style:normal">Devletin varlığı ve bağımsızlığını, vatanın ve milletin bölünmez bütünlüğünü, milletin kayıtsız şartsız egemenliğini koruyacağıma; hukukun üstünlüğüne, demokratik ve laik Cumhuriyete ve Atatürk ilke ve inkılâplarına bağlı kalacağıma; toplumun huzur ve refahı, millî dayanışma ve adalet anlayışı içinde herkesin insan haklarından ve temel hürriyetlerinden yararlanması ülküsünden ve Anayasaya sadakatten ayrılmayacağıma; büyük Türk Milleti önünde namusum ve şerefim üzerine andiçerim.</div>',
          'Andiçiyorum', function () { return cagir('gk_andic', {}, 'Andını içtin. Hayırlı olsun, Sayın Milletvekili.'); });
        return;
      case 'konus':
        var ta = $1('#gkMetin'); if (!ta) return; var m = ta.value.trim(); if (!m) return;
        el.disabled = true;
        try { var r2 = await rpc('gk_konus', { p_metin: m }); ta.value = ''; taslakKaydet(''); if (r2 && r2.kalan === 0) bildir('Kelime hakkın doldu; konuşman tamamlandı.'); await yokla(true); }
        catch (err) { el.disabled = false; bildir(hata(err), true); yokla(); }
        return;
      case 'bitir': return cagir('gk_konusma_bitir', {}, 'Konuşmanı tamamladın.');
      case 'laf':
        var lf = $1('#gkLaf'); if (!lf || !lf.value.trim()) return;
        if (kelime(lf.value) > 12) { bildir('Sıralardan atılan söz en çok 12 kelime olabilir.', true); return; }
        try { await cagir('gk_laf', { p_metin: lf.value.trim() }); lf.value = ''; } catch (_) {}
        return;
      case 'tepki': try { await rpc('gk_tepki', { p_tutanak: id, p_tur: el.getAttribute('data-tur') }); yokla(true); } catch (err) { bildir(hata(err), true); } return;
      case 'satasma':
        form('Sataşma nedeniyle söz', 'Konuşmada adın ya da partin geçtiyse cevap hakkı istersin. Başkanlık uygun görürse 2 dakika, 70 kelimelik söz verir.', '', 'Cevap hakkı iste', function () { return cagir('gk_soz_iste', { p_tur: 'satasma', p_hedef: id }, 'Sataşma nedeniyle söz istedin.'); });
        return;
      case 'kaldir':
        form('Tutanaktan çıkar', 'İçerik Masası: hakaret, küfür ya da kural dışı ifade tutanaktan çıkarılır; satır herkes için gizlenir.', '<label for="gkKG">Gerekçe (isteğe bağlı)</label><input id="gkKG" maxlength="200">', 'Çıkar',
          function (md) { return cagir('gk_tutanak_kaldir', { p_id: id, p_gerekce: $1('#gkKG', md).value || null }, 'Satır tutanaktan çıkarıldı.'); });
        return;
      case 'gundemdisi':
        form('Gündem dışı söz', 'Birleşimin başında 5 dakika, 120 kelimelik konuşma. Başkanlık her birleşimde en çok 3 milletvekili seçer; seçilmezse istemin düşer.', '<label for="gkGD">Konu</label><input id="gkGD" maxlength="150" placeholder="Örn. Ege\'de kuraklık ve çiftçinin borç yükü">', 'İste',
          async function (md) { var r3 = await cagir('gk_gundem_disi_iste', { p_konu: $1('#gkGD', md).value }); bildir('Gündem dışı söz istemin ' + (r3 && r3.gun ? gunAy(r3.gun + 'T12:00:00+03:00') : '') + ' birleşimine yazıldı.'); });
        return;
      case 'oneri': return grupOneriForm();
      case 'yoklamaiste': return cagir('gk_yoklama_iste', {}, 'Yoklama başladı.');
      case 'kapali':
        form('Kapalı oturum istemi', 'Genel Kurul işaret oyuyla karar verir. Kabul edilirse tutanak gizlenir; salonda yalnız milletvekilleri ve Hükümet kalır.', '<label for="gkKO">Gerekçe</label><textarea id="gkKO" maxlength="300"></textarea>', 'İste',
          function (md) { return cagir('gk_kapali_oturum_iste', { p_gerekce: $1('#gkKO', md).value }, 'Kapalı oturum istemi oylamaya sunuldu.'); });
        return;
      case 'gg': if (typeof window.tbmmGenelGorusmeAc === 'function') return window.tbmmGenelGorusmeAc(); return;
      case 'merkez': if (typeof window.tbmmMerkezAc === 'function') return window.tbmmMerkezAc(); return;
      case 'arsiv': return ekranAc(arsivEkrani);
      case 'tutanak': return ekranAc(function () { return tutanakEkrani(id); });
      case 'eski': if (S.eskiSohbet) ekranAc(function () { return S.eskiSohbet('meclis'); }); return;
      // Başkanlık
      case 'ac': return cagir('gk_birlesim_ac', {}, 'Birleşimi açtın.');
      case 'ver': return cagir('gk_soz_ver', { p_soz: id }, 'Söz verildi.');
      case 'sira': return cagir('gk_soz_sira', { p_soz: id, p_yon: +el.getAttribute('data-yon') });
      case 'reddet':
        form('Söz istemini karşılama', 'Gerekçeyi milletvekili görür.', '<label for="gkRG">Gerekçe</label><input id="gkRG" maxlength="200" placeholder="Örn. Görüşülen konuyla ilgili değil.">', 'Reddet',
          function (md) { return cagir('gk_soz_reddet', { p_soz: id, p_gerekce: $1('#gkRG', md).value }, 'İstem reddedildi.'); });
        return;
      case 'eksure': return cagir('gk_ek_sure', { p_soz: id }, '1 dakika ek süre verildi.');
      case 'kes': return cagir('gk_sozu_kes', { p_soz: id }, 'Konuşmacının mikrofonu kapatıldı.');
      case 'ara': return cagir('gk_ara_ver', { p_dk: +el.getAttribute('data-dk') }, 'Birleşime ara verildi.');
      case 'madde': return cagir('gk_gundem_gec', { p_madde: id });
      case 'sonraki': return cagir('gk_gundem_gec', { p_madde: null });
      case 'oylamaya': return cagir('gk_oylamaya_sun', { p_konu: null }, 'Oylama açıldı.');
      case 'uzatma': return cagir('gk_oylamaya_sun', { p_konu: 'uzatma' }, 'Süre uzatımı oylamaya sunuldu.');
      case 'zil': return cagir('gk_zil', { p_kanun: id }, 'Oylama zili çalındı.');
      case 'acikoturum': return cagir('gk_acik_oturum', {}, 'Açık oturuma geçildi.');
      case 'gdsec': return cagir('gk_gundem_disi_sec', { p_id: id, p_sec: el.getAttribute('data-sec') === 'true' });
      case 'aciklama':
        form('Başkanlık açıklaması', 'En çok 100 kelime. Tutanağa “BAŞKAN –” olarak geçer.', '<textarea id="gkBA" maxlength="900" placeholder="Sayın milletvekilleri…"></textarea>', 'Kürsüden söyle',
          function (md) { return cagir('gk_konus', { p_metin: $1('#gkBA', md).value }); });
        return;
      case 'disiplin':
        form('Disiplin cezası', 'İçtüzük m.160-165: Uyarma Başkanlıkça hemen verilir. Kınama ve Meclisten geçici çıkarma Genel Kurulda görüşmesiz oylanır; kınamada milletvekili ödeneğinin üçte biri, çıkarmada üçte ikisi kesilir.',
          '<label for="gkDK">Milletvekilinin kullanıcı adı</label><input id="gkDK" maxlength="40" autocapitalize="off" autocomplete="off">' +
          '<label for="gkDT">Ceza</label><select id="gkDT"><option value="uyarma">Uyarma</option><option value="kinama">Kınama</option><option value="cikarma">Meclisten geçici çıkarma</option></select>' +
          '<label for="gkDB">Çıkarma süresi</label><select id="gkDB"><option value="1">1 birleşim</option><option value="2">2 birleşim</option><option value="3">3 birleşim</option></select>' +
          '<label for="gkDG">Gerekçe</label><input id="gkDG" maxlength="300" placeholder="Örn. Kürsüdeki hatibe hakaret ettiği için">', 'Uygula',
          function (md) { return cagir('gk_disiplin', { p_kad: $1('#gkDK', md).value.trim(), p_tur: $1('#gkDT', md).value, p_gerekce: $1('#gkDG', md).value, p_birlesim: +$1('#gkDB', md).value }, 'Disiplin işlemi başlatıldı.'); });
        return;
      case 'olaganustu':
        var v = new Date(simdiMs() + 2 * 3600e3); v.setMinutes(0, 0, 0);
        var yerel = new Date(v.getTime() - v.getTimezoneOffset() * 60e3).toISOString().slice(0, 16);
        form('Olağanüstü toplantı', 'Anayasa m.93: Meclis Başkanı ya da Cumhurbaşkanı Meclisi tatilde veya ara vermede olağanüstü toplantıya çağırır. Birleşim 60 dakika sürer.',
          '<label for="gkOZ">Toplantı zamanı</label><input id="gkOZ" type="datetime-local" value="' + yerel + '"><label for="gkOG">Gerekçe</label><textarea id="gkOG" maxlength="300"></textarea>', 'Çağır',
          function (md) { var z = $1('#gkOZ', md).value; if (!z) throw new Error('Zaman seç.'); return cagir('gk_olaganustu_cagir', { p_bas: new Date(z).toISOString(), p_gerekce: $1('#gkOG', md).value }, 'Meclis olağanüstü toplantıya çağrıldı.'); });
        return;
    }
  }
  function bagla(kok) {
    if (kok._gk) return; kok._gk = true;
    kok.addEventListener('click', function (ev) {
      var t = ev.target.closest('[data-eylem]');
      if (t && kok.contains(t)) { ev.preventDefault(); if (t.disabled) return; eylem(t.getAttribute('data-eylem'), t); return; }
      var g = ev.target.closest('[data-gor]');
      if (g) { S.gorunum = g.getAttribute('data-gor'); S.imza.gkLej = ''; S.imza.kol = ''; yerlestir('gkLej', lejantHtml()); koltukGuncelle(); return; }
      var k = ev.target.closest('circle.k');
      if (k && S.H) { var v = (S.H.vekiller || [])[+k.getAttribute('data-i')]; if (v && typeof oyuncuKart === 'function') oyuncuKart(v.k); return; }
      if (ev.target.closest('#gkYeni')) { var ak = $1('#gkAkis'); if (ak) ak.scrollTop = ak.scrollHeight; ev.target.closest('#gkYeni').hidden = true; }
    });
    kok.addEventListener('toggle', function (ev) { if (ev.target && ev.target.id === 'gkBskD') { S.acikBsk = ev.target.open; try { localStorage.setItem('gkBsk', S.acikBsk ? '1' : '0'); } catch (_) {} } }, true);
    var ak = $1('#gkAkis', kok); if (ak) ak.addEventListener('scroll', function () { if (ak.scrollTop + ak.clientHeight >= ak.scrollHeight - 60) { var y = $1('#gkYeni'); if (y) y.hidden = true; } });
  }

  /* ---------------------------------------------------------- ekranlar */
  async function salonEkrani() {
    css();
    var sag = '<button type="button" class="gk-hb" id="gkSesB" aria-label="Salon sesleri">' + (S.ses ? I.ses : I.sessiz) + '</button>';
    iskelet('Genel Kurul', '<div class="gk" id="gkSalon"><div class="gk-ust" id="gkUst"><span class="gk-cip yok">YÜKLENİYOR</span><div class="orta"><b>TBMM Genel Kurulu</b><small>Salon hazırlanıyor…</small></div></div>' +
      '<div class="gk-sahne"><div id="gkSvgK"></div><div id="gkLej"></div></div><div id="gkKursu"></div><div id="gkPano"></div><div id="gkBaskan"></div>' +
      '<div class="gk-akis-kutu"><div class="gk-akis" id="gkAkis" role="log" aria-live="polite" aria-label="Genel Kurul tutanağı"></div><button type="button" class="gk-yeni" id="gkYeni" hidden>Yeni satırlar ↓</button>' +
      '<div class="gk-perde" id="gkPerde" hidden>' + I.kilit + '<b>KAPALI OTURUM</b><small>Genel Kurul kapalı oturumda çalışıyor. Görüşmeler gizlidir; tutanak yalnız milletvekillerine açıktır.</small></div></div>' +
      '<div class="gk-dock" id="gkDock"></div></div>', { geri: (typeof D !== 'undefined' && D && D.yigin && D.yigin.length > 0), sekmesiz: true, sag: sag });
    S.imza = {}; S.ilk = true; S.bid = undefined; S.satir = {}; S.son = 0; S.surum = 0; S.izleImza = '';
    var kok = $1('#gkSalon'); bagla(kok);
    var sb = $1('#gkSesB'); if (sb) sb.onclick = function () { S.ses = !S.ses; try { localStorage.setItem('gkSes', S.ses ? '1' : '0'); } catch (_) {} sb.innerHTML = S.ses ? I.ses : I.sessiz; if (S.ses) sesCal('tokmak'); };
    dur(); S.tik = setInterval(tik, 1000);
    try {
      var sonuc = await Promise.all([rpc('gk_durum', { p_surum: 0, p_son: 0 }), haritaAl()]);
      if (!$1('#gkSalon')) return;
      $1('#gkSvgK').innerHTML = svgHtml();
      isle(sonuc[0]);
    } catch (err) {
      var ust = $1('#gkUst'); if (ust) ust.innerHTML = '<span class="gk-cip yok">BAĞLANTI</span><div class="orta"><b>Salona bağlanılamadı</b><small>' + esc(hata(err)) + '</small></div>';
    }
  }
  async function arsivEkrani() {
    css();
    iskelet('Tutanak Arşivi', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    try {
      var L = await rpc('gk_birlesimler', { p_limit: 40 });
      iskelet('Tutanak Arşivi', '<div class="gk">' + (L.length ? L.map(function (b) {
        var o = b.ozet || {};
        return '<button type="button" class="gk-sec" data-id="' + b.id + '"><b>' + esc(birlesimAdi(b)) + ' · ' + esc(gunAy(b.acilis)) + '</b><span>' +
          (b.durum === 'toplanamadi' ? 'Toplantı yeter sayısı bulunamadı' : (o.konusma || 0) + ' konuşma · ' + ((o.oylamalar || []).length) + ' oylama · ' + (o.sure_dk || 0) + ' dakika') + (b.gerekce ? ' · ' + esc(b.gerekce) : '') + '</span></button>';
      }).join('') : '<div class="bos">Henüz birleşim yapılmadı.</div>') + '</div>', { geri: true });
      $$('.gk-sec[data-id]').forEach(function (b) { b.onclick = function () { var id = +b.getAttribute('data-id'); ekranAc(function () { return tutanakEkrani(id); }); }; });
    } catch (err) { iskelet('Tutanak Arşivi', '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); }
  }
  async function tutanakEkrani(id) {
    css();
    iskelet('Tutanak', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    try {
      var r = await rpc('gk_tutanak_oku', { p_birlesim: id, p_once: null }), b = r.birlesim, L = r.satirlar || [];
      var ilk = L.length ? L[0].id : null;
      S.yeminGosterildi = false;
      var govde = function () {
        return '<div class="gk"><div class="gk-akis" id="gkArsiv" style="max-height:none"><div class="gk-akis-bas"><b>TÜRKİYE BÜYÜK MİLLET MECLİSİ</b><b>GENEL KURUL TUTANAĞI</b><small>' + esc(birlesimAdi(b)) + ' · ' + esc(gunAy(b.acilis)) +
          (b.acilis ? ' · Açılış ' + saat(b.acilis) : '') + (b.kapanis ? ' · Kapanış ' + saat(b.kapanis) : '') + '</small></div>' +
          (L.length >= 150 ? '<button type="button" class="gk-d cizgi" id="gkDaha" style="color:#1d1a14">Daha eski satırlar</button>' : '') +
          L.map(function (x) { return satirHtml(x, false); }).join('') + '</div></div>';
      };
      iskelet(birlesimAdi(b), govde(), { geri: true });
      var daha = function () {
        var d = $1('#gkDaha'); if (!d) return;
        d.onclick = async function () {
          d.disabled = true;
          try { var r2 = await rpc('gk_tutanak_oku', { p_birlesim: id, p_once: ilk }); var y = r2.satirlar || []; if (!y.length) { d.remove(); return; } L = y.concat(L); ilk = y[0].id; S.yeminGosterildi = false; iskelet(birlesimAdi(b), govde(), { geri: true }); if (y.length < 150) { var dd = $1('#gkDaha'); if (dd) dd.remove(); } daha(); }
          catch (err) { d.disabled = false; bildir(hata(err), true); }
        };
      };
      daha();
    } catch (err) { iskelet('Tutanak', '<div class="bos">' + esc(hata(err)) + '</div>', { geri: true }); }
  }

  window.tbmmSalonAc = function () { ekranAc(salonEkrani); };
  window.tbmmSalonEkrani = salonEkrani;
  window.tbmmTutanakArsiviAc = function () { ekranAc(arsivEkrani); };
  window.tbmmTutanakAc = function (id) { ekranAc(function () { return tutanakEkrani(id); }); };
  window.SO_GK = { _S: S, sira: sira, kelime: kelime, css: css, form: form, mmss: mmss, esc: esc, gunAy: gunAy, saat: saat, tarih: tarih, sure: sure, I: I, birlesimAdi: birlesimAdi };

  /* Genel Kurul sohbetine giden bütün yollar salona çıkar (eski kayıtlar "Diğer" menüsünde kalır) */
  function sohbetBagla() {
    if (typeof window.sohbetEkrani !== 'function' || window.sohbetEkrani._gk) return false;
    var eski = window.sohbetEkrani;
    var yeni = function (kanal) { if (kanal === 'meclis') return salonEkrani(); return eski.apply(this, arguments); };
    yeni._gk = true; S.eskiSohbet = eski;
    window.sohbetEkrani = yeni; try { sohbetEkrani = yeni; } catch (_) {}
    return true;
  }
  sohbetBagla();
  [800, 2500, 6000].forEach(function (ms) { setTimeout(sohbetBagla, ms); });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { setTimeout(sohbetBagla, 50); });
})();
