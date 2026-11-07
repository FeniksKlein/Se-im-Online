/* =====================================================================
   SO_REKLAM_PANOSU_V1 (07.11.2026) — Afiş Stüdyosu ve Reklam Panoları
   • Afiş Stüdyosu: şablon, yazı, amblem, portre, şekil, ikon, zemin ve efektlerle
     afiş tasarımı. Tasarım küçük bir JSON tarifidir; her cihazda aynı SVG çizilir.
   • Reklam Panoları: il panoları ve ülke geneli dev panolar, Türkiye reklam haritası,
     kiralama, reklamlarım, belediye reklam tarifesi, şikâyet incelemesi.
   • Gündem'in en üstünde oyuncunun ilindeki panoyu gösteren canlı şerit.
   Sunucu: 175_reklam_panosu.sql (pano_* ve afis_* işlemleri). Yetki her zaman sunucuda denetlenir.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_REKLAM_PANOSU_V1) return;
  window.SO_REKLAM_PANOSU_V1 = true;

  /* ---------------------------------------------------------------
     0) YARDIMCILAR
     --------------------------------------------------------------- */
  var RP = { uid: 0, vitrin: null, vitrinT: 0, vitrinIl: null, merkez: null, seritZaman: null };
  window.RP_DURUM = RP;
  var W = 1000, H = 440;
  var esc = function (s) { return typeof e === 'function' ? e(s) : String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var tl = function (n) { return Math.round(Number(n) || 0).toLocaleString('tr-TR') + ' ₺'; };
  var sayiYaz = function (n) { return Math.round(Number(n) || 0).toLocaleString('tr-TR'); };
  var renkOk = function (v, d) { return /^#[0-9a-f]{6}$/i.test(String(v || '')) ? String(v) : d; };
  var sinir = function (v, a, b, d) { v = Number(v); return isFinite(v) ? Math.min(b, Math.max(a, v)) : d; };
  var kodOk = function (v, d) { return /^[a-z0-9_]{1,24}$/.test(String(v || '')) ? String(v) : d; };
  var simdiMs = function () { try { return typeof simdi === 'function' ? simdi() : Date.now(); } catch (_) { return Date.now(); } };
  var trSaat = function () { return (new Date(simdiMs()).getUTCHours() + 3) % 24; };
  var profil = function () { try { return (D && D.durum && D.durum.profil) || null; } catch (_) { return null; } };
  var hataGoster = function (err) { var m = err && err.message ? err.message : String(err || 'Bilinmeyen hata'); toast(typeof hataCevir === 'function' ? hataCevir(m) : m, true); };
  var ilAdi = function (id) { try { var i = (VERI.iller || []).find(function (x) { return x.id === Number(id); }); return i ? i.ad : ''; } catch (_) { return ''; } };
  var kopya = function (x) { return JSON.parse(JSON.stringify(x)); };
  var tarihKisa = function (ts) {
    if (!ts) return '—';
    var d = new Date(new Date(ts).getTime() + 3 * 3600e3);
    var ay = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'][d.getUTCMonth()];
    return d.getUTCDate() + ' ' + ay + ' ' + String(d.getUTCHours()).padStart(2, '0') + ':' + String(d.getUTCMinutes()).padStart(2, '0');
  };
  var kalanYaz = function (ts) {
    var ms = new Date(ts).getTime() - simdiMs();
    if (ms <= 0) return 'bitti';
    var g = Math.floor(ms / 864e5), s = Math.floor(ms % 864e5 / 36e5), d = Math.floor(ms % 36e5 / 6e4);
    return g > 0 ? g + ' gün ' + s + ' sa' : s > 0 ? s + ' sa ' + d + ' dk' : d + ' dk';
  };

  // Sunucu tarafı henüz açılmadıysa (izin/işlev yok) oyuncuya ham hata yerine sade bir mesaj göster
  var hazirlikMi = function (err) { return /permission denied|does not exist|could not find the function|PGRST202|42883|42501/i.test(String(err && err.message || err || '')); };
  var hazirlikHTML = '<div class="kart"><h3 style="font-size:18px">Reklam panoları açılıyor</h3><p class="alt" style="margin-top:6px">Afiş Stüdyosu ve reklam panoları son hazırlıkları tamamlanınca burada olacak. Biraz sonra tekrar dene.</p></div>';
  /* Renk yardımcıları */
  function hexRgb(h) { h = renkOk(h, '#7B61FF').slice(1); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]; }
  function rgbHex(r) { return '#' + r.map(function (x) { return Math.round(sinir(x, 0, 255, 0)).toString(16).padStart(2, '0'); }).join(''); }
  function karis(a, b, t) { var x = hexRgb(a), y = hexRgb(b); return rgbHex([0, 1, 2].map(function (i) { return x[i] + (y[i] - x[i]) * t; })); }
  function koyu(h, t) { return karis(h, '#000000', t); }
  function acik(h, t) { return karis(h, '#ffffff', t); }
  function parlaklik(h) { var c = hexRgb(h).map(function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; }
  function kontrast(h) { return parlaklik(h) > 0.42 ? '#0B1020' : '#FFFFFF'; }
  function hsl(h) {
    var c = hexRgb(h).map(function (v) { return v / 255; }), mx = Math.max.apply(null, c), mn = Math.min.apply(null, c), l = (mx + mn) / 2, s = 0, hu = 0, d = mx - mn;
    if (d) { s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn); hu = mx === c[0] ? (c[1] - c[2]) / d + (c[1] < c[2] ? 6 : 0) : mx === c[1] ? (c[2] - c[0]) / d + 2 : (c[0] - c[1]) / d + 4; hu *= 60; }
    return [hu, s, l];
  }
  function hslHex(hu, s, l) {
    hu = ((hu % 360) + 360) % 360;
    var k = function (n) { return (n + hu / 30) % 12; }, a = s * Math.min(l, 1 - l);
    var f = function (n) { return l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1))); };
    return rgbHex([f(0) * 255, f(8) * 255, f(4) * 255]);
  }
  function uyumPalet(h) {
    var x = hsl(renkOk(h, '#7B61FF'));
    return [h, hslHex(x[0] + 180, Math.max(x[1], 0.55), 0.55), hslHex(x[0] + 30, Math.max(x[1], 0.5), 0.6), hslHex(x[0] - 30, Math.max(x[1], 0.5), 0.45), koyu(h, 0.55), acik(h, 0.75)];
  }
  var SABIT_RENK = ['#FFFFFF', '#0B1020', '#E30A17', '#F2B33D', '#FFD400', '#1E88E5', '#34C98A', '#7B61FF', '#FF4FD8', '#4FF3FF', '#F4F1E8', '#8B0000', '#2E7D32', '#FF6F00', '#6D4C41', '#9E9E9E'];

  /* ---------------------------------------------------------------
     1) AFİŞ ÇİZİCİ (tasarım JSON → güvenli SVG)
     --------------------------------------------------------------- */
  var FONT = {
    kurul: '"Kurul Display","Arial Narrow","Roboto Condensed",sans-serif',
    blok: 'Impact,"Haettenschweiler","Arial Black","Kurul Display",sans-serif',
    serif: 'Georgia,"Times New Roman",serif',
    yuvarlak: '"Arial Rounded MT Bold","Nunito","Trebuchet MS",sans-serif',
    el: '"Segoe Script","Brush Script MT","Snell Roundhand","Bradley Hand",cursive',
    mono: '"Courier New",ui-monospace,monospace'
  };
  var FONT_AD = { kurul: 'Kurul', blok: 'Blok', serif: 'Klasik', yuvarlak: 'Yuvarlak', el: 'El yazısı', mono: 'Daktilo' };
  var IKON = {
    megafon: 'M3 11v2a1 1 0 0 0 1 1h3l6 5V5L7 10H4a1 1 0 0 0-1 1zM17 8a5 5 0 0 1 0 8M20 5a9 9 0 0 1 0 14',
    kalp: 'M12 20s-7-4.4-9.2-8.6C1.2 8.2 3.2 4.5 6.8 4.5c2 0 3.4 1.1 4.2 2.4.8-1.3 2.2-2.4 4.2-2.4 3.6 0 5.6 3.7 4 6.9C19 15.6 12 20 12 20z',
    yildiz: 'M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.5 2.9 1-6.1L3.2 9.5l6.1-.9z',
    el: 'M3 11l4-4h4l2 2M21 11l-4-4h-3l-5 5a1.5 1.5 0 0 0 2 2l2-1.5 3 3.5M7 13l3 3M9 11l4 4',
    basak: 'M12 21V9M12 9c-2-1-3-3-3-5 2 1 3 3 3 5zM12 9c2-1 3-3 3-5-2 1-3 3-3 5zM12 14c-2-1-4-2.5-4.5-5 2.5.5 4 2.5 4.5 5zM12 14c2-1 4-2.5 4.5-5-2.5.5-4 2.5-4.5 5z',
    fabrika: 'M3 21V10l5 3V10l5 3V10l5 3V4h3v17zM7 17h2M12 17h2M17 17h1',
    kitap: 'M4 5a2 2 0 0 1 2-2h12v15H6a2 2 0 0 0-2 2zM4 20a2 2 0 0 0 2 1h12v-3M9 7h5',
    okul: 'M2 9l10-5 10 5-10 5zM6 11v5c3 2.5 9 2.5 12 0v-5M22 9v6',
    saglik: 'M9 3h6v6h6v6h-6v6H9v-6H3V9h6z',
    ev: 'M4 11l8-7 8 7v9a1 1 0 0 1-1 1h-5v-6h-4v6H5a1 1 0 0 1-1-1z',
    terazi: 'M12 3v18M7 21h10M5 7h14M5 7l-3 6a3 3 0 0 0 6 0zM19 7l-3 6a3 3 0 0 0 6 0z',
    gunes: 'M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10zM12 1v3M12 20v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M1 12h3M20 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1',
    damla: 'M12 3s7 7.5 7 12a7 7 0 0 1-14 0c0-4.5 7-12 7-12z',
    yaprak: 'M5 19C5 9 11 4 20 4c0 9-5 15-15 15zM5 19l8-8',
    ampul: 'M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 3z',
    onay: 'M4 12l5 5L20 6',
    kupa: 'M7 4h10v5a5 5 0 0 1-10 0zM7 6H4a3 3 0 0 0 3 4M17 6h3a3 3 0 0 1-3 4M12 14v4M8 21h8M9 18h6',
    sepet: 'M3 7h18l-2 9H5zM8 7l3-4M16 7l-3-4M9 20.5a1 1 0 1 0 0-.01M17 20.5a1 1 0 1 0 0-.01',
    sandik: 'M4 11h16v9H4zM8 11V4h8v7M10 7h4',
    yuzde: 'M19 5L5 19M7 9a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM17 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4z',
    kalkan: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
    cark: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1',
    mikrofon: 'M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM5 11a7 7 0 0 0 14 0M12 18v3M8 21h8',
    ucak: 'M2 16l20-8-4 10-6-3-3 4-1-5z',
    tel: 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2',
    ok: 'M5 12h14M13 6l6 6-6 6',
    insan: 'M12 4a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM5 21c1-4.5 3.8-7 7-7s6 2.5 7 7',
    kilit: 'M6 11h12v10H6zM8 11V7a4 4 0 0 1 8 0v4'
  };
  var IKON_AD = { megafon: 'Megafon', kalp: 'Kalp', yildiz: 'Yıldız', el: 'Tokalaşma', basak: 'Başak', fabrika: 'Fabrika', kitap: 'Kitap', okul: 'Okul', saglik: 'Sağlık', ev: 'Ev', terazi: 'Adalet', gunes: 'Güneş', damla: 'Su', yaprak: 'Yaprak', ampul: 'Fikir', onay: 'Onay', kupa: 'Kupa', sepet: 'Alışveriş', sandik: 'Sandık', yuzde: 'Yüzde', kalkan: 'Kalkan', cark: 'Sanayi', mikrofon: 'Mikrofon', ucak: 'Uçak', tel: 'Telefon', ok: 'Ok', insan: 'İnsan', kilit: 'Güvenlik' };
  var SEKIL_AD = { kutu: 'Kutu', daire: 'Daire', serit: 'Kurdele', rozet: 'Rozet', yildiz: 'Yıldız', ucgen: 'Üçgen', hilal: 'Hilal', bayrak: 'Türk bayrağı', cizgi: 'Çizgi', ok: 'Ok', dalga: 'Dalga' };
  var ZEMIN_AD = { duz: 'Düz', gradyan: 'Geçişli', isinsal: 'Işıltılı', bolunmus: 'Bölünmüş', gunes: 'Güneş ışını', serit: 'Çizgili' };
  var DESEN_AD = { yok: 'Yok', nokta: 'Nokta', cizgi: 'Çizgi', izgara: 'Izgara', dalga: 'Dalga', yildiz: 'Yıldızlar' };
  var DOKU_AD = { yok: 'Yok', kagit: 'Kâğıt', baski: 'Baskı', parlak: 'Vinil' };

  function yildizNoktalar(cx, cy, dis, ic, n, don) {
    var p = [], i, a;
    for (i = 0; i < n * 2; i++) { a = (don || -90) * Math.PI / 180 + i * Math.PI / n; var r = i % 2 ? ic : dis; p.push((cx + r * Math.cos(a)).toFixed(1) + ',' + (cy + r * Math.sin(a)).toFixed(1)); }
    return p.join(' ');
  }
  function amblemIc(id) {
    try { var a = (VERI.amblem || []).find(function (x) { return x.id === id; }) || VERI.amblem[0]; return a ? a.svg : ''; } catch (_) { return ''; }
  }
  function portreIc(kod, ad, renk) {
    try {
      if (!/^[0-9]{1,2}(-[0-9]{1,2}){5,6}$/.test(String(kod || '')) || typeof portreSvg !== 'function')
        return '<svg viewBox="0 0 64 64"><rect width="64" height="64" fill="' + renkOk(renk, '#3A4675') + '"/><circle cx="32" cy="25" r="11" fill="#E6EAF5"/><path d="M9 64c3-15 12-22 23-22s20 7 23 22z" fill="#E6EAF5"/></svg>';
      return portreSvg(kod, { ad: ad || '?', renk: renk || '#3A4675' }).replace(/\sclass="portre"/, '').replace(/\srole="img"/, '');
    } catch (_) { return ''; }
  }

  // Bir tasarımın SVG iç kısmı (defs + çizim). o: {kunye, ornekKunye, sec}
  function afisIc(t, o) {
    t = t && typeof t === 'object' ? t : {}; o = o || {};
    var u = 'rp' + (++RP.uid), z = t.zemin || {}, ef = t.efekt || {}, d = [], s = [];
    var r1 = renkOk(z.r1, '#1B2A6B'), r2 = renkOk(z.r2, '#7B61FF'), aci = sinir(z.aci, 0, 360, 135) * Math.PI / 180;
    var x1 = (50 - 50 * Math.cos(aci)).toFixed(1), y1 = (50 - 50 * Math.sin(aci)).toFixed(1), x2 = (50 + 50 * Math.cos(aci)).toFixed(1), y2 = (50 + 50 * Math.sin(aci)).toFixed(1);
    d.push('<linearGradient id="' + u + 'g" x1="' + x1 + '%" y1="' + y1 + '%" x2="' + x2 + '%" y2="' + y2 + '%"><stop offset="0" stop-color="' + r1 + '"/><stop offset="1" stop-color="' + r2 + '"/></linearGradient>');
    d.push('<radialGradient id="' + u + 'r" cx="' + sinir(z.cx, 0, W, 500) / 10 + '%" cy="' + sinir(z.cy, 0, H, 200) / 4.4 + '%" r="75%"><stop offset="0" stop-color="' + r1 + '"/><stop offset="1" stop-color="' + r2 + '"/></radialGradient>');
    d.push('<filter id="' + u + 's" x="-20%" y="-30%" width="140%" height="160%"><feGaussianBlur in="SourceAlpha" stdDeviation="5"/><feOffset dx="0" dy="5" result="b"/><feComponentTransfer><feFuncA type="linear" slope=".55"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>');
    d.push('<filter id="' + u + 'n" x="-30%" y="-50%" width="160%" height="200%"><feGaussianBlur stdDeviation="7" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>');
    d.push('<linearGradient id="' + u + 'p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".34"/><stop offset=".45" stop-color="#fff" stop-opacity=".06"/><stop offset=".46" stop-color="#fff" stop-opacity="0"/></linearGradient>');
    d.push('<radialGradient id="' + u + 'v" cx="50%" cy="50%" r="72%"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="1"/></radialGradient>');
    // Zemin
    var tip = kodOk(z.tip, 'gradyan');
    if (tip === 'duz') s.push('<rect width="' + W + '" height="' + H + '" fill="' + r1 + '"/>');
    else if (tip === 'isinsal') s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'r)"/>');
    else if (tip === 'bolunmus') s.push('<rect width="' + W + '" height="' + H + '" fill="' + r1 + '"/><polygon points="640,0 ' + W + ',0 ' + W + ',' + H + ' 520,' + H + '" fill="' + r2 + '"/>');
    else if (tip === 'gunes') {
      var cx = sinir(z.cx, 0, W, 500), cy = sinir(z.cy, 0, H + 200, H + 30), n = 28, R = 1400, k;
      s.push('<rect width="' + W + '" height="' + H + '" fill="' + r2 + '"/>');
      for (k = 0; k < n; k += 2) {
        var a1 = Math.PI + k * Math.PI / n, a2 = Math.PI + (k + 1) * Math.PI / n;
        s.push('<polygon points="' + cx + ',' + cy + ' ' + (cx + R * Math.cos(a1)).toFixed(0) + ',' + (cy + R * Math.sin(a1)).toFixed(0) + ' ' + (cx + R * Math.cos(a2)).toFixed(0) + ',' + (cy + R * Math.sin(a2)).toFixed(0) + '" fill="' + r1 + '"/>');
      }
    } else if (tip === 'serit') {
      d.push('<pattern id="' + u + 'st" width="60" height="60" patternUnits="userSpaceOnUse" patternTransform="rotate(-35)"><rect width="60" height="60" fill="' + r1 + '"/><rect width="28" height="60" fill="' + r2 + '"/></pattern>');
      s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'st)"/>');
    } else s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'g)"/>');
    // Desen
    var desen = kodOk(z.desen, 'yok'), dop = sinir(z.dop, 0, 0.6, 0.12), dr = parlaklik(r1) > 0.5 ? '#000' : '#fff';
    if (desen !== 'yok') {
      var pd = '';
      if (desen === 'nokta') pd = '<pattern id="' + u + 'd" width="18" height="18" patternUnits="userSpaceOnUse"><circle cx="9" cy="9" r="3.2" fill="' + dr + '"/></pattern>';
      else if (desen === 'cizgi') pd = '<pattern id="' + u + 'd" width="16" height="16" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="3" height="16" fill="' + dr + '"/></pattern>';
      else if (desen === 'izgara') pd = '<pattern id="' + u + 'd" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0H0V40" fill="none" stroke="' + dr + '" stroke-width="1.5"/></pattern>';
      else if (desen === 'dalga') pd = '<pattern id="' + u + 'd" width="80" height="26" patternUnits="userSpaceOnUse"><path d="M0 13 Q20 0 40 13 T80 13" fill="none" stroke="' + dr + '" stroke-width="2.5"/></pattern>';
      else if (desen === 'yildiz') {
        var ys = '';
        for (var q = 0; q < 46; q++) { var px = (q * 97 + 31) % W, py = (q * 61 + 17 * (q % 5)) % H, pr = 2 + (q % 4) * 1.6; ys += '<polygon points="' + yildizNoktalar(px, py, pr * 2, pr * 0.8, 5) + '" fill="' + dr + '"/>'; }
        s.push('<g opacity="' + dop + '">' + ys + '</g>');
      }
      if (pd) { d.push(pd); s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'd)" opacity="' + dop + '"/>'); }
    }
    // Öğeler
    (Array.isArray(t.ogeler) ? t.ogeler.slice(0, 32) : []).forEach(function (g, i) { if (g && typeof g === 'object') s.push(ogeSvg(g, i, u, d)); });
    // Efektler (dokunmayı engellemesin)
    s.push('<g pointer-events="none">');
    var doku = kodOk(ef.doku, 'yok');
    if (doku === 'kagit') {
      d.push('<pattern id="' + u + 'k" width="7" height="7" patternUnits="userSpaceOnUse"><rect width="1" height="1" fill="#000" opacity=".22"/><rect x="4" y="3" width="1" height="1" fill="#fff" opacity=".3"/><rect x="2" y="5" width="1" height="1" fill="#000" opacity=".14"/></pattern>');
      s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'k)"/><rect width="' + W + '" height="' + H + '" fill="#F2E6C9" opacity=".10"/>');
    } else if (doku === 'baski') {
      d.push('<pattern id="' + u + 'k" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(20)"><circle cx="3" cy="3" r="1.1" fill="#000" opacity=".2"/></pattern>');
      s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'k)"/>');
    } else if (doku === 'parlak') {
      s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'p)" opacity=".7" transform="skewX(-18)"/>');
    }
    if (ef.parlama) s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'p)"/>');
    var vin = sinir(ef.vinyet, 0, 1, 0);
    if (vin > 0) s.push('<rect width="' + W + '" height="' + H + '" fill="url(#' + u + 'v)" opacity="' + (vin * 0.75).toFixed(2) + '"/>');
    if (ef.kenar) s.push('<rect x="14" y="14" width="' + (W - 28) + '" height="' + (H - 28) + '" fill="none" stroke="' + renkOk(ef.kenar, '#FFFFFF') + '" stroke-width="6" opacity=".9"/>');
    // Künye: siyasi reklam ve ticari ilan şeffaflığı
    var kun = o.kunye || o.ornekKunye;
    if (kun) {
      var kt = 'Ödeyen: ' + String(kun).slice(0, 60), kw = Math.min(W - 20, 26 + kt.length * 10.4);
      s.push('<g class="rp-kunye"><rect x="10" y="' + (H - 42) + '" width="' + kw.toFixed(0) + '" height="32" rx="6" fill="#000" opacity=".58"/><text x="22" y="' + (H - 20) + '" font-family=\'' + FONT.kurul + '\' font-size="19" font-weight="700" fill="#fff" letter-spacing=".3">' + esc(kt) + '</text></g>');
    }
    s.push('</g>');
    return '<defs>' + d.join('') + '</defs>' + s.join('');
  }

  function ogeSvg(g, i, u, d) {
    var x = sinir(g.x, -200, W + 200, W / 2), y = sinir(g.y, -200, H + 200, H / 2), op = sinir(g.op, 0.05, 1, 1), don = sinir(g.don, -180, 180, 0);
    var ac = '<g data-i="' + i + '"' + (op < 1 ? ' opacity="' + op + '"' : '') + (don ? ' transform="rotate(' + don + ' ' + x + ' ' + y + ')"' : '') + '>', ic = '';
    var tur = kodOk(g.t, '');
    if (tur === 'metin') {
      var boy = sinir(g.boy, 10, 220, 48), satir = String(g.m == null ? '' : g.m).split('\n').slice(0, 5);
      if (g.buyuk) satir = satir.map(function (x2) { return x2.toLocaleUpperCase('tr-TR'); });
      var renk = renkOk(g.renk, '#FFFFFF'), fk = kodOk(g.font, 'kurul'), font = FONT[fk] || FONT.kurul, kal = [400, 700, 900].indexOf(Number(g.kal)) >= 0 ? Number(g.kal) : 700;
      var hiza = ['start', 'middle', 'end'].indexOf(g.hiza) >= 0 ? g.hiza : 'middle', harf = sinir(g.harf, -6, 40, 0);
      // "sig": yazı bu genişliğe sığmazsa yazı boyu kendiliğinden küçülür (uzun adlar, sloganlar)
      var sig = sinir(g.sig, 0, 1400, 0);
      if (sig > 0) {
        var uz = Math.max.apply(null, satir.map(function (x2) { return x2.length; }).concat([1]));
        var oran = ({ blok: 0.5, kurul: 0.48, serif: 0.56, yuvarlak: 0.6, el: 0.5, mono: 0.62 }[fk] || 0.52) * (kal === 900 ? 1.06 : 1);
        var buyukMu = satir.join('') === satir.join('').toLocaleUpperCase('tr-TR');
        var tahmin = uz * boy * oran * (buyukMu ? 1.14 : 1) + Math.max(0, harf) * uz;
        if (tahmin > sig) boy = Math.max(10, Math.floor(boy * sig / tahmin));
      }
      var lh = boy * 1.06;
      var y0 = y - (satir.length - 1) * lh / 2 + boy * 0.35;
      if (g.arka) {
        var en = Math.max.apply(null, satir.map(function (x2) { return x2.length; })) * boy * (g.font === 'blok' ? 0.5 : 0.56) + harf * 10 + boy * 0.6, by = satir.length * lh + boy * 0.25;
        var bx = hiza === 'start' ? x - boy * 0.3 : hiza === 'end' ? x - en + boy * 0.3 : x - en / 2;
        ic += '<rect x="' + bx.toFixed(0) + '" y="' + (y - by / 2).toFixed(0) + '" width="' + en.toFixed(0) + '" height="' + by.toFixed(0) + '" rx="' + (boy * 0.18).toFixed(0) + '" fill="' + renkOk(g.arka, '#000000') + '"/>';
      }
      var filtre = g.parla ? ' filter="url(#' + u + 'n)"' : g.golge ? ' filter="url(#' + u + 's)"' : '';
      var kontur = g.kontur ? ' stroke="' + renkOk(g.kontur, '#000000') + '" stroke-width="' + sinir(g.kk, 1, 24, Math.max(2, boy / 12)) + '" stroke-linejoin="round" paint-order="stroke"' : '';
      ic += '<text x="' + x + '" text-anchor="' + hiza + '" font-family=\'' + font + '\' font-size="' + boy + '" font-weight="' + kal + '"' + (g.italik ? ' font-style="italic"' : '') + (harf ? ' letter-spacing="' + harf + '"' : '') + ' fill="' + renk + '"' + kontur + filtre + '>' +
        satir.map(function (x2, k) { return '<tspan x="' + x + '" y="' + (y0 + k * lh).toFixed(1) + '">' + (esc(x2) || ' ') + '</tspan>'; }).join('') + '</text>';
    } else if (tur === 'amblem') {
      var sa = sinir(g.s, 16, 420, 90);
      if (g.arka) ic += '<circle cx="' + x + '" cy="' + y + '" r="' + (sa * 0.64).toFixed(1) + '" fill="' + renkOk(g.arka, '#FFFFFF') + '"/>';
      ic += '<svg x="' + (x - sa / 2) + '" y="' + (y - sa / 2) + '" width="' + sa + '" height="' + sa + '" viewBox="0 0 24 24" fill="' + renkOk(g.renk, '#FFFFFF') + '" overflow="visible">' + amblemIc(kodOk(g.id, 'a_yildiz')) + '</svg>';
    } else if (tur === 'portre') {
      var sp = sinir(g.s, 40, 420, 200), cer = kodOk(g.cerceve, 'daire'), kn = renkOk(g.kenar, '#FFFFFF'), kk = sinir(g.kk, 0, 24, 8), cid = u + 'c' + i;
      var ps = portreIc(String(g.kod || ''), g.ad, g.renk);
      d.push('<clipPath id="' + cid + '">' + (cer === 'daire' ? '<circle cx="' + x + '" cy="' + y + '" r="' + sp / 2 + '"/>' : '<rect x="' + (x - sp / 2) + '" y="' + (y - sp / 2) + '" width="' + sp + '" height="' + sp + '" rx="' + (cer === 'kare' ? sp * 0.08 : 0) + '"/>') + '</clipPath>');
      ic += '<g clip-path="url(#' + cid + ')">' + ps.replace(/^<svg/, '<svg x="' + (x - sp / 2) + '" y="' + (y - sp / 2) + '" width="' + sp + '" height="' + sp + '"') + '</g>';
      if (cer !== 'yok' && kk > 0) ic += cer === 'daire' ? '<circle cx="' + x + '" cy="' + y + '" r="' + (sp / 2) + '" fill="none" stroke="' + kn + '" stroke-width="' + kk + '"/>' : '<rect x="' + (x - sp / 2) + '" y="' + (y - sp / 2) + '" width="' + sp + '" height="' + sp + '" rx="' + (sp * 0.08) + '" fill="none" stroke="' + kn + '" stroke-width="' + kk + '"/>';
    } else if (tur === 'sekil') {
      var w = sinir(g.w, 4, 1400, 200), h = sinir(g.h, 2, 900, 120), rn = renkOk(g.renk, '#FFFFFF'), sk = kodOk(g.sekil, 'kutu'), yu = sinir(g.yuvarlak, 0, 200, 0);
      var st = g.kenar ? ' stroke="' + renkOk(g.kenar, '#000000') + '" stroke-width="' + sinir(g.kk, 1, 30, 4) + '"' : '';
      var x0 = x - w / 2, y0s = y - h / 2;
      if (sk === 'daire') ic += '<ellipse cx="' + x + '" cy="' + y + '" rx="' + w / 2 + '" ry="' + h / 2 + '" fill="' + rn + '"' + st + '/>';
      else if (sk === 'serit') { var nt = h * 0.35; ic += '<polygon points="' + [x0 + ',' + y0s, (x0 + w) + ',' + y0s, (x0 + w - nt) + ',' + y, (x0 + w) + ',' + (y0s + h), x0 + ',' + (y0s + h), (x0 + nt) + ',' + y].join(' ') + '" fill="' + rn + '"' + st + '/>'; }
      else if (sk === 'rozet') ic += '<polygon points="' + yildizNoktalar(x, y, w / 2, w / 2 * 0.84, 18) + '" fill="' + rn + '"' + st + '/>';
      else if (sk === 'yildiz') ic += '<polygon points="' + yildizNoktalar(x, y, w / 2, w / 2 * 0.42, 5) + '" fill="' + rn + '"' + st + '/>';
      else if (sk === 'ucgen') ic += '<polygon points="' + x + ',' + y0s + ' ' + (x0 + w) + ',' + (y0s + h) + ' ' + x0 + ',' + (y0s + h) + '" fill="' + rn + '"' + st + '/>';
      else if (sk === 'hilal') { var mid = u + 'm' + i, R = h / 2; d.push('<mask id="' + mid + '"><rect x="-500" y="-500" width="2000" height="1500" fill="#fff"/><circle cx="' + (x + R * 0.26) + '" cy="' + y + '" r="' + (R * 0.8) + '" fill="#000"/></mask>'); ic += '<circle cx="' + x + '" cy="' + y + '" r="' + R + '" fill="' + rn + '" mask="url(#' + mid + ')"/>'; }
      else if (sk === 'bayrak') {
        var bh = h, bw = Math.max(w, bh * 1.5), bx0 = x - bw / 2, by0 = y - bh / 2, mid2 = u + 'b' + i, G = bh;
        d.push('<mask id="' + mid2 + '"><rect x="-500" y="-500" width="2000" height="1500" fill="#fff"/><circle cx="' + (bx0 + 0.5 * G + 0.0625 * G) + '" cy="' + y + '" r="' + (0.2 * G) + '" fill="#000"/></mask>');
        ic += '<rect x="' + bx0 + '" y="' + by0 + '" width="' + bw + '" height="' + bh + '" fill="#E30A17"/><circle cx="' + (bx0 + 0.5 * G) + '" cy="' + y + '" r="' + (0.25 * G) + '" fill="#fff" mask="url(#' + mid2 + ')"/><polygon points="' + yildizNoktalar(bx0 + 0.5 * G + 0.333 * G, y, 0.125 * G, 0.05 * G, 5, 180) + '" fill="#fff"/>';
      }
      else if (sk === 'cizgi') ic += '<rect x="' + x0 + '" y="' + (y - Math.max(2, h) / 2) + '" width="' + w + '" height="' + Math.max(2, Math.min(h, 40)) + '" rx="' + Math.min(h, 40) / 2 + '" fill="' + rn + '"/>';
      else if (sk === 'ok') ic += '<polygon points="' + [x0 + ',' + (y - h * 0.18), (x0 + w * 0.68) + ',' + (y - h * 0.18), (x0 + w * 0.68) + ',' + y0s, (x0 + w) + ',' + y, (x0 + w * 0.68) + ',' + (y0s + h), (x0 + w * 0.68) + ',' + (y + h * 0.18), x0 + ',' + (y + h * 0.18)].join(' ') + '" fill="' + rn + '"' + st + '/>';
      else if (sk === 'dalga') ic += '<path d="M' + x0 + ' ' + y + ' Q ' + (x0 + w * 0.25) + ' ' + (y - h / 2) + ' ' + (x0 + w * 0.5) + ' ' + y + ' T ' + (x0 + w) + ' ' + y + ' V ' + (y0s + h) + ' H ' + x0 + ' Z" fill="' + rn + '"/>';
      else ic += '<rect x="' + x0 + '" y="' + y0s + '" width="' + w + '" height="' + h + '" rx="' + yu + '" fill="' + rn + '"' + st + '/>';
    } else if (tur === 'ikon') {
      var si = sinir(g.s, 16, 420, 90), pth = IKON[kodOk(g.ad, 'yildiz')] || IKON.yildiz, dolu = !!g.dolu;
      ic += '<svg x="' + (x - si / 2) + '" y="' + (y - si / 2) + '" width="' + si + '" height="' + si + '" viewBox="0 0 24 24" overflow="visible"><path d="' + pth + '" fill="' + (dolu ? renkOk(g.renk, '#FFFFFF') : 'none') + '" stroke="' + renkOk(g.renk, '#FFFFFF') + '" stroke-width="' + sinir(g.kal, 0.8, 4, 1.8) + '" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    }
    return ac + ic + '</g>';
  }

  function afisSvg(t, o) {
    o = o || {};
    return '<svg class="rp-afis' + (o.sinif ? ' ' + o.sinif : '') + '" viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid meet" role="img" aria-label="' + esc(o.etiket || 'Afiş') + '">' + afisIc(t, o) + '</svg>';
  }
  window.rpAfisSvg = afisSvg;

  /* ---------------------------------------------------------------
     2) ŞABLONLAR VE SLOGAN USTASI
     --------------------------------------------------------------- */
  function baglam(kaynak) {
    var p = profil() || {}, k = kaynak || {}, ben = (RP.merkez && (RP.merkez.kaynaklar || [])[0]) || {};
    var renk = renkOk(k.renk || ben.renk || (p.parti && p.parti.renk), '#7B61FF');
    var avatar = '';
    try { var km = typeof kimlik === 'function' ? kimlik(p.kad) : null; avatar = km && km.avatar ? km.avatar : ''; } catch (_) {}
    return {
      tur: k.tur || 'oyuncu', renk: renk, amblem: kodOk(k.amblem || ben.amblem || (p.parti && p.parti.amblem), 'a_yildiz'),
      ad: p.kad || 'Aday', sahip: k.ad || (p.parti && p.parti.ad) || p.kad || 'Hareketimiz', kisa: k.kisa || '',
      avatar: /^[0-9]{1,2}(-[0-9]{1,2}){5,6}$/.test(avatar) ? avatar : '', il: ilAdi(p.il_id) || 'Türkiye'
    };
  }
  function portreOge(c, x, y, s, cer, kenar) {
    var o = { t: 'portre', x: x, y: y, s: s, cerceve: cer || 'daire', kenar: kenar || '#FFFFFF', kk: 8 };
    if (c.avatar) o.kod = c.avatar;
    return o;
  }
  var SABLON = [
    { kod: 'meydan', ad: 'Meydan', icin: ['oyuncu', 'parti'], f: function (c) {
      return { v: 1, zemin: { tip: 'gradyan', r1: c.renk, r2: koyu(c.renk, 0.6), aci: 120, desen: 'cizgi', dop: 0.07 }, ogeler: [
        { t: 'sekil', sekil: 'daire', x: 230, y: 215, w: 340, h: 340, renk: '#FFFFFF', op: 0.12 },
        portreOge(c, 230, 210, 270, 'daire', '#FFFFFF'),
        { t: 'metin', m: c.ad, x: 650, y: 140, boy: 76, sig: 600, renk: '#FFFFFF', font: 'kurul', kal: 900, hiza: 'middle', buyuk: true, golge: true },
        { t: 'metin', m: 'GÜÇLÜ YARINLAR İÇİN', x: 650, sig: 600, y: 225, boy: 40, renk: '#FFE08A', font: 'kurul', kal: 700, hiza: 'middle', harf: 3 },
        { t: 'sekil', sekil: 'serit', x: 650, y: 330, w: 540, h: 76, renk: '#FFFFFF' },
        { t: 'amblem', id: c.amblem, renk: c.renk, x: 430, y: 330, s: 52 },
        { t: 'metin', m: c.sahip, x: 675, y: 332, boy: 30, sig: 430, renk: koyu(c.renk, 0.25), font: 'kurul', kal: 700, hiza: 'middle' }
      ], efekt: { parlama: true, vinyet: 0.35 } };
    } },
    { kod: 'gunes', ad: 'Güneş doğuyor', icin: ['oyuncu', 'parti', 'dernek'], f: function (c) {
      return { v: 1, zemin: { tip: 'gunes', r1: c.renk, r2: '#F7E7C6', cx: 500, cy: 470, desen: 'nokta', dop: 0.08 }, ogeler: [
        { t: 'amblem', id: c.amblem, renk: '#FFFFFF', arka: c.renk, x: 500, y: 92, s: 92 },
        { t: 'metin', m: 'YENİ BİR SABAH', x: 500, y: 225, sig: 900, boy: 92, renk: '#1B1B1B', font: 'blok', kal: 900, hiza: 'middle', kontur: '#F7E7C6', kk: 12, harf: 3 },
        { t: 'metin', m: c.ad, x: 500, y: 318, boy: 46, sig: 860, renk: koyu(c.renk, 0.45), font: 'kurul', kal: 900, hiza: 'middle', kontur: '#F7E7C6', kk: 8 },
        { t: 'metin', m: c.sahip, x: 500, y: 385, boy: 24, sig: 700, renk: '#1B1B1B', font: 'kurul', kal: 700, hiza: 'middle', harf: 6, buyuk: true, arka: '#F7E7C6' }
      ], efekt: { doku: 'kagit', vinyet: 0.25 } };
    } },
    { kod: 'cumhuriyet', ad: 'Ay yıldız', icin: ['oyuncu', 'parti', 'dernek'], f: function (c) {
      return { v: 1, zemin: { tip: 'bolunmus', r1: '#E30A17', r2: '#FFFFFF' }, ogeler: [
        { t: 'metin', m: 'ÖNCE\nTÜRKİYE', x: 60, sig: 560, y: 175, boy: 98, renk: '#FFFFFF', font: 'blok', kal: 900, hiza: 'start', golge: true },
        { t: 'metin', m: c.ad, x: 64, y: 330, boy: 44, sig: 560, renk: '#FFFFFF', font: 'kurul', kal: 700, hiza: 'start' },
        { t: 'sekil', sekil: 'bayrak', x: 800, y: 150, w: 240, h: 160 },
        { t: 'amblem', id: c.amblem, renk: '#E30A17', x: 700, y: 330, s: 56 },
        { t: 'metin', m: c.sahip, x: 950, y: 390, boy: 28, sig: 520, renk: '#B0000F', font: 'kurul', kal: 700, hiza: 'end' }
      ], efekt: { parlama: true } };
    } },
    { kod: 'neon', ad: 'Neon gece', icin: ['oyuncu', 'parti', 'dernek', 'sirket'], f: function (c) {
      return { v: 1, zemin: { tip: 'gradyan', r1: '#0A0820', r2: '#1C0B44', aci: 160, desen: 'izgara', dop: 0.1 }, ogeler: [
        { t: 'metin', m: c.tur === 'sirket' ? c.sahip : c.ad, x: 500, y: 165, sig: 900, boy: 92, renk: '#FF4FD8', font: 'kurul', kal: 900, hiza: 'middle', parla: true, buyuk: true },
        { t: 'metin', m: c.tur === 'sirket' ? 'GECE GÜNDÜZ YANINDA' : 'GELECEK BİZİMLE', sig: 900, x: 500, y: 262, boy: 50, renk: '#4FF3FF', font: 'kurul', kal: 700, hiza: 'middle', parla: true, harf: 6 },
        { t: 'sekil', sekil: 'cizgi', x: 500, y: 322, w: 520, h: 5, renk: '#FF4FD8' },
        { t: 'metin', m: c.sahip, x: 500, y: 372, boy: 28, sig: 860, renk: '#FFFFFF', font: 'kurul', kal: 700, hiza: 'middle', harf: 4 }
      ], efekt: { vinyet: 0.55 } };
    } },
    { kod: 'manset', ad: 'Gazete manşeti', icin: ['oyuncu', 'parti', 'gazete'], f: function (c) {
      return { v: 1, zemin: { tip: 'duz', r1: '#F4F1E8' }, ogeler: [
        { t: 'sekil', sekil: 'kutu', x: 500, y: 46, w: 1000, h: 92, renk: '#111111' },
        { t: 'metin', m: 'SON DAKİKA', x: 40, y: 46, boy: 42, renk: '#FFFFFF', font: 'blok', kal: 900, hiza: 'start', harf: 2 },
        { t: 'sekil', sekil: 'kutu', x: 860, y: 46, w: 220, h: 50, renk: '#E30A17', yuvarlak: 6 },
        { t: 'metin', m: 'ÖZEL HABER', x: 860, y: 47, boy: 22, renk: '#FFFFFF', font: 'kurul', kal: 700, hiza: 'middle', harf: 2 },
        { t: 'metin', m: c.ad + ' konuştu:', x: 40, sig: 740, y: 150, boy: 34, renk: '#111111', font: 'serif', kal: 700, hiza: 'start' },
        { t: 'metin', m: '“Bu şehir değişime\nhazır!”', x: 40, sig: 760, y: 250, boy: 62, renk: '#111111', font: 'serif', kal: 900, hiza: 'start' },
        { t: 'sekil', sekil: 'cizgi', x: 430, y: 352, w: 780, h: 3, renk: '#111111' },
        { t: 'metin', m: c.sahip, x: 40, y: 392, boy: 26, sig: 740, renk: '#444444', font: 'serif', kal: 400, hiza: 'start', italik: true },
        portreOge(c, 880, 270, 170, 'kare', '#111111')
      ], efekt: { doku: 'kagit' } };
    } },
    { kod: 'minimal', ad: 'Sade', icin: ['oyuncu', 'parti', 'dernek', 'sirket', 'gazete'], f: function (c) {
      return { v: 1, zemin: { tip: 'duz', r1: '#FFFFFF' }, ogeler: [
        { t: 'sekil', sekil: 'daire', x: 850, y: 120, w: 170, h: 170, renk: c.renk },
        { t: 'amblem', id: c.amblem, renk: kontrast(c.renk), x: 850, y: 120, s: 90 },
        { t: 'metin', m: 'Sade.\nDürüst.\nSenden.', x: 60, y: 190, boy: 84, renk: '#111111', font: 'kurul', kal: 900, hiza: 'start' },
        { t: 'sekil', sekil: 'cizgi', x: 160, y: 352, w: 200, h: 8, renk: c.renk },
        { t: 'metin', m: c.tur === 'oyuncu' ? c.ad : c.sahip, x: 60, y: 392, sig: 640, boy: 28, renk: koyu(c.renk, 0.2), font: 'kurul', kal: 700, hiza: 'start', harf: 2 }
      ], efekt: {} };
    } },
    { kod: 'indirim', ad: 'Kampanya', icin: ['sirket', 'oyuncu'], f: function (c) {
      return { v: 1, zemin: { tip: 'isinsal', r1: '#FFE14D', r2: '#FFA000', cx: 300, cy: 200, desen: 'nokta', dop: 0.1 }, ogeler: [
        { t: 'sekil', sekil: 'rozet', x: 810, y: 215, w: 320, h: 320, renk: '#E30A17', don: -12 },
        { t: 'metin', m: '%30', x: 810, y: 190, boy: 112, renk: '#FFFFFF', font: 'blok', kal: 900, hiza: 'middle', don: -12 },
        { t: 'metin', m: 'İNDİRİM', x: 810, y: 278, boy: 42, renk: '#FFFFFF', font: 'blok', kal: 900, hiza: 'middle', don: -12, harf: 2 },
        { t: 'metin', m: c.sahip, x: 60, y: 140, boy: 62, sig: 600, renk: '#111111', font: 'blok', kal: 900, hiza: 'start' },
        { t: 'metin', m: 'Bu hafta bütün şubelerde!', x: 60, sig: 620, y: 230, boy: 38, renk: '#111111', font: 'kurul', kal: 700, hiza: 'start' },
        { t: 'sekil', sekil: 'kutu', x: 260, y: 340, w: 400, h: 74, renk: '#111111', yuvarlak: 37 },
        { t: 'metin', m: 'HEMEN UĞRA', x: 260, y: 341, boy: 30, renk: '#FFE14D', font: 'kurul', kal: 900, hiza: 'middle', harf: 4 }
      ], efekt: { parlama: true } };
    } },
    { kod: 'luks', ad: 'Lüks marka', icin: ['sirket', 'gazete', 'dernek'], f: function (c) {
      return { v: 1, zemin: { tip: 'gradyan', r1: '#0B0B0B', r2: '#2B2416', aci: 90 }, ogeler: [
        { t: 'sekil', sekil: 'cizgi', x: 500, y: 95, w: 300, h: 2, renk: '#D4AF37' },
        { t: 'metin', m: c.sahip, x: 500, y: 195, boy: 64, sig: 880, renk: '#D4AF37', font: 'serif', kal: 400, hiza: 'middle', harf: 12, buyuk: true },
        { t: 'metin', m: 'Zamansız bir ayrıcalık', x: 500, y: 275, boy: 32, renk: '#EADBB0', font: 'serif', kal: 400, hiza: 'middle', italik: true },
        { t: 'sekil', sekil: 'cizgi', x: 500, y: 335, w: 300, h: 2, renk: '#D4AF37' },
        { t: 'ikon', ad: 'yildiz', x: 500, y: 376, s: 30, renk: '#D4AF37', dolu: true }
      ], efekt: { vinyet: 0.45, parlama: true } };
    } },
    { kod: 'dernek', ad: 'Birlikte', icin: ['dernek', 'parti', 'oyuncu'], f: function (c) {
      return { v: 1, zemin: { tip: 'gradyan', r1: '#0F7B6C', r2: '#0B3D4F', aci: 135, desen: 'dalga', dop: 0.1 }, ogeler: [
        { t: 'sekil', sekil: 'daire', x: 175, y: 215, w: 280, h: 280, renk: '#FFFFFF', op: 0.1 },
        { t: 'ikon', ad: 'el', x: 175, y: 215, s: 200, renk: '#FFFFFF', kal: 1.6 },
        { t: 'metin', m: 'BİRLİKTE\nDAHA GÜÇLÜYÜZ', x: 345, sig: 620, y: 170, boy: 68, renk: '#FFFFFF', font: 'kurul', kal: 900, hiza: 'start' },
        { t: 'metin', m: c.sahip, x: 348, y: 315, boy: 30, sig: 620, renk: '#9FF5E3', font: 'kurul', kal: 700, hiza: 'start' },
        { t: 'metin', m: 'Gönüllü ol, sesini yükselt', x: 348, y: 370, boy: 26, renk: '#FFFFFF', font: 'kurul', kal: 400, hiza: 'start', op: 0.85 }
      ], efekt: { parlama: true, vinyet: 0.3 } };
    } },
    { kod: 'sandik', ad: 'Sandığa', icin: ['parti', 'oyuncu', 'dernek'], f: function (c) {
      return { v: 1, zemin: { tip: 'gradyan', r1: koyu(c.renk, 0.45), r2: c.renk, aci: 0, desen: 'yildiz', dop: 0.14 }, ogeler: [
        { t: 'ikon', ad: 'sandik', x: 175, y: 215, s: 230, renk: '#FFFFFF', kal: 1.6 },
        { t: 'metin', m: 'OYUNU\nKULLAN!', x: 610, sig: 700, y: 160, boy: 98, renk: '#FFFFFF', font: 'blok', kal: 900, hiza: 'middle', golge: true },
        { t: 'metin', m: 'Sandık başına, geleceğe sahip çık', x: 610, y: 318, boy: 30, renk: '#FFE08A', font: 'kurul', kal: 700, hiza: 'middle' },
        { t: 'metin', m: c.sahip, x: 610, y: 378, boy: 24, sig: 700, renk: '#FFFFFF', font: 'kurul', kal: 700, hiza: 'middle', harf: 4 },
        { t: 'amblem', id: c.amblem, renk: '#FFFFFF', x: 930, y: 66, s: 56 }
      ], efekt: { vinyet: 0.35 } };
    } },
    { kod: 'tasra', ad: 'Sizden biri', icin: ['oyuncu', 'parti'], f: function (c) {
      return { v: 1, zemin: { tip: 'gradyan', r1: '#FF8A3D', r2: '#C2185B', aci: 45 }, ogeler: [
        portreOge(c, 200, 220, 280, 'kare', '#FFF5E8'),
        { t: 'metin', m: 'Sizden biri,\nsizin için.', x: 395, y: 160, boy: 62, renk: '#FFF5E8', font: 'el', kal: 700, hiza: 'start' },
        { t: 'metin', m: c.ad, x: 398, y: 305, boy: 52, sig: 570, renk: '#FFFFFF', font: 'kurul', kal: 900, hiza: 'start', buyuk: true },
        { t: 'metin', m: c.il + ' için çalışıyoruz', x: 400, sig: 570, y: 368, boy: 26, renk: '#FFE0C2', font: 'kurul', kal: 700, hiza: 'start' }
      ], efekt: { parlama: true } };
    } },
    { kod: 'gazete', ad: 'Gazete', icin: ['gazete', 'sirket'], f: function (c) {
      return { v: 1, zemin: { tip: 'duz', r1: '#101418' }, ogeler: [
        { t: 'sekil', sekil: 'kutu', x: 500, y: 220, w: 940, h: 380, renk: '#F4F1E8', yuvarlak: 8 },
        { t: 'metin', m: c.sahip, x: 500, y: 112, boy: 64, sig: 860, renk: '#111111', font: 'serif', kal: 900, hiza: 'middle', harf: 3, buyuk: true },
        { t: 'sekil', sekil: 'cizgi', x: 500, y: 162, w: 840, h: 3, renk: '#111111' },
        { t: 'metin', m: 'Her sabah, gerçeğin peşinde.', x: 500, y: 230, boy: 40, renk: '#222222', font: 'serif', kal: 400, hiza: 'middle', italik: true },
        { t: 'metin', m: 'ABONE OL · YAZARLARIMIZI OKU', x: 500, y: 330, boy: 24, renk: '#E30A17', font: 'kurul', kal: 700, hiza: 'middle', harf: 3 }
      ], efekt: { doku: 'kagit' } };
    } }
  ];

  var SLOGAN = {
    'Ekonomi': { isim: ['bereket', 'refah', 'istikrar', 'güçlü ekonomi', 'ucuz ekmek', 'iş ve aş'], fiil: ['büyütüyoruz', 'kalkındırıyoruz', 'ayağa kaldırıyoruz'] },
    'Adalet': { isim: ['adalet', 'hukuk', 'eşitlik', 'hakkaniyet', 'şeffaflık'], fiil: ['savunuyoruz', 'yeniden kuruyoruz', 'herkese ulaştırıyoruz'] },
    'Eğitim': { isim: ['eğitim', 'okul', 'bilim', 'gençlerin geleceği', 'nitelikli eğitim'], fiil: ['güçlendiriyoruz', 'yeniliyoruz', 'ücretsiz yapıyoruz'] },
    'Gençlik': { isim: ['gençlik', 'umut', 'enerji', 'cesaret', 'fırsat eşitliği'], fiil: ['ayağa kaldırıyoruz', 'yanında duruyoruz', 'yetkilendiriyoruz'] },
    'Tarım': { isim: ['tarım', 'toprak', 'çiftçi', 'bereketli hasat', 'köy'], fiil: ['destekliyoruz', 'kalkındırıyoruz', 'yeniden yeşertiyoruz'] },
    'Şehir': { isim: ['temiz şehir', 'yeşil alan', 'ulaşım', 'altyapı', 'yaşanabilir şehir'], fiil: ['yeniliyoruz', 'güzelleştiriyoruz', 'sizinle yönetiyoruz'] },
    'Birlik': { isim: ['birlik', 'kardeşlik', 'huzur', 'barış', 'ortak gelecek'], fiil: ['büyütüyoruz', 'koruyoruz', 'birlikte kuruyoruz'] },
    'Değişim': { isim: ['değişim', 'yenilik', 'yeni nesil siyaset', 'temiz siyaset', 'yeni bir sayfa'], fiil: ['başlatıyoruz', 'getiriyoruz', 'hep birlikte yazıyoruz'] }
  };
  var TICARI = ['{S}: kalitenin adresi', '{S} ile her gün daha iyi', 'Türkiye’nin sevdiği marka: {S}', 'Bu fırsat kaçmaz!', 'Şimdi {I} şubemizde', 'Güvenin adı {S}', 'Yeni sezon başladı', 'Sınırlı stok, büyük indirim'];
  function buyukIlk(x) { return x.charAt(0).toLocaleUpperCase('tr-TR') + x.slice(1); }
  function sloganUret(tema, c) {
    var sablon = [
      function (t) { return 'Önce ' + t.i + ', sonra her şey'; },
      function (t) { return c.il + ' için ' + t.i + '!'; },
      function (t) { return buyukIlk(t.i) + ' için oyunu ver!'; },
      function (t) { return 'Söz verdik: ' + t.f + '!'; },
      function (t) { return buyukIlk(t.i) + ' bizim işimiz'; },
      function (t) { return c.ad + ' ile ' + t.i; },
      function (t) { return 'Yeniden ' + t.i; },
      function (t) { return buyukIlk(t.i) + ' yolunda durmak yok'; },
      function (t) { return 'Halkın sesi, ' + t.i + 'in gücü'; },
      function (t) { return 'Birlikte ' + t.f; },
      function (t) { return buyukIlk(t.i) + ' bir lüks değil, hak!'; }
    ];
    var out = [], havuz = SLOGAN[tema] || SLOGAN['Değişim'], i;
    if (tema === 'Ticari') {
      return TICARI.map(function (x) { return x.replace('{S}', c.sahip).replace('{I}', c.il); }).sort(function () { return Math.random() - 0.5; }).slice(0, 6);
    }
    for (i = 0; out.length < 6 && i < 40; i++) {
      var t = { i: havuz.isim[Math.floor(Math.random() * havuz.isim.length)], f: havuz.fiil[Math.floor(Math.random() * havuz.fiil.length)] };
      var s = sablon[Math.floor(Math.random() * sablon.length)](t);
      if (s.length <= 60 && out.indexOf(s) < 0) out.push(s);
    }
    return out;
  }

  /* ---------------------------------------------------------------
     3) STİL
     --------------------------------------------------------------- */
  function stilKur() {
    if (document.getElementById('rpStil')) return;
    var st = document.createElement('style'); st.id = 'rpStil';
    st.textContent = [
      '.rp-afis{display:block;width:100%;height:auto;aspect-ratio:1000/440;border-radius:3px;background:#0b1020}',
      /* Pano (billboard) */
      '.rp-pano{position:relative;padding-top:14px}',
      '.rp-pano-cerceve{position:relative;padding:7px;border-radius:7px;background:linear-gradient(180deg,#3b4362,#1b2036 55%,#141829);box-shadow:0 18px 30px -16px rgba(0,0,0,.9),inset 0 1px 0 rgba(255,255,255,.18),inset 0 -2px 0 rgba(0,0,0,.4)}',
      '.rp-pano-yuzey{position:relative;overflow:hidden;border-radius:3px;background:#0b1020;box-shadow:inset 0 0 0 1px rgba(0,0,0,.6)}',
      '.rp-pano-yuzey::after{content:"";position:absolute;inset:-40% -60%;background:linear-gradient(100deg,transparent 42%,rgba(255,255,255,.22) 50%,transparent 58%);transform:translateX(-60%);animation:rpSupur 7s ease-in-out infinite;pointer-events:none}',
      '@keyframes rpSupur{0%,62%{transform:translateX(-60%)}82%,100%{transform:translateX(60%)}}',
      '.rp-pano-lamba{position:absolute;top:0;left:0;right:0;display:flex;justify-content:space-around;padding:0 12%;z-index:2;pointer-events:none}',
      '.rp-pano-lamba i{position:relative;display:block;width:22px;height:9px;border-radius:2px 2px 6px 6px;background:linear-gradient(#59617f,#262c45);box-shadow:0 1px 0 rgba(255,255,255,.2) inset}',
      '.rp-pano-lamba i::before{content:"";position:absolute;left:50%;top:-6px;width:2px;height:7px;background:#4a5272;transform:translateX(-50%)}',
      '.rp-gece .rp-pano-lamba i::after{content:"";position:absolute;left:50%;top:7px;width:150px;height:120px;transform:translateX(-50%);background:radial-gradient(ellipse at 50% 0,rgba(255,236,170,.30),rgba(255,236,170,0) 70%);clip-path:polygon(44% 0,56% 0,100% 100%,0 100%)}',
      '.rp-gece .rp-pano-lamba i{background:linear-gradient(#fff2c4,#e9c56a);box-shadow:0 0 14px 4px rgba(255,220,130,.55)}',
      '.rp-pano-ayak{display:flex;justify-content:space-between;padding:0 22%;height:26px}',
      '.rp-pano-ayak::before,.rp-pano-ayak::after{content:"";width:9px;height:100%;background:linear-gradient(90deg,#20263d,#4a5272,#20263d);border-radius:0 0 2px 2px}',
      '.rp-pano.kucuk .rp-pano-ayak{height:14px}.rp-pano.kucuk{padding-top:10px}.rp-pano.kucuk .rp-pano-cerceve{padding:5px}',
      '.rp-pano-etiket{display:flex;align-items:center;gap:6px;margin-top:8px;font-size:14px;color:var(--txt2);line-height:1.35}',
      '.rp-pano-etiket b{color:var(--txt);font-weight:800}.rp-pano-etiket .rp-bosluk{flex:1}',
      /* Sahne */
      '.rp-sahne{position:relative;margin:-4px -4px 14px;border-radius:20px;overflow:hidden;min-height:330px;background:#0b1026;box-shadow:0 20px 40px -24px rgba(0,0,0,.9)}',
      '.rp-sahne svg.rp-gok{position:absolute;inset:0;width:100%;height:100%}',
      '.rp-sahne-ic{position:relative;z-index:1;padding:18px 16px 16px}',
      '.rp-sahne-ust{display:flex;align-items:flex-start;gap:10px;margin-bottom:14px}',
      '.rp-sahne-ust h2{font-family:var(--disp);font-size:28px;line-height:1.02;letter-spacing:.3px;color:#fff;text-shadow:0 2px 12px rgba(0,0,0,.5)}',
      '.rp-sahne-ust p{font-size:14px;color:rgba(255,255,255,.82);margin-top:5px;line-height:1.4}',
      '.rp-sahne-pano{max-width:560px;margin:0 auto}',
      '.rp-dondur{position:relative}.rp-dondur>.rp-kare{position:absolute;inset:0;opacity:0;transition:opacity .9s ease;pointer-events:none;cursor:pointer}.rp-dondur>.rp-kare.aktif{position:relative;opacity:1;pointer-events:auto;z-index:1}',
      '.rp-nokta-sira{display:flex;justify-content:center;gap:6px;margin-top:8px}.rp-nokta-sira i{width:6px;height:6px;border-radius:3px;background:rgba(255,255,255,.35);transition:width .3s,background .3s}.rp-nokta-sira i.aktif{width:18px;background:#fff}',
      '.rp-cip{display:inline-flex;align-items:center;gap:6px;min-height:34px;padding:6px 12px;border-radius:999px;background:rgba(255,255,255,.12);color:#fff;font-size:14px;font-weight:700;backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px);border:1px solid rgba(255,255,255,.16)}',
      '.rp-cip-sira{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}',
      '.rp-eylem-sira{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:14px}.rp-eylem-sira .btn{margin:0;min-height:48px}',
      '.rp-btn-sicak{background:linear-gradient(135deg,#ff8a3d,#f0454b)!important;color:#fff!important;box-shadow:0 10px 24px -12px rgba(240,69,75,.9)}',
      /* Başlıklar ve kaydırmalı satırlar */
      '.rp-bolum{margin:20px 0 10px;display:flex;align-items:baseline;gap:8px}.rp-bolum h3{font-family:var(--disp);font-size:21px;letter-spacing:.2px}.rp-bolum small{color:var(--mut);font-size:14px}',
      '.rp-yatay{display:flex;gap:12px;overflow-x:auto;scroll-snap-type:x mandatory;padding:2px 2px 10px;margin:0 -2px;-webkit-overflow-scrolling:touch}',
      '.rp-yatay>*{flex:0 0 86%;max-width:420px;scroll-snap-align:start}',
      '.rp-kart{background:var(--panel);border-radius:16px;padding:12px;border:1px solid var(--line)}',
      '.rp-kiralik{position:relative;display:grid;place-items:center;aspect-ratio:1000/440;border-radius:3px;background:repeating-linear-gradient(-45deg,#1a2142 0 18px,#151b36 18px 36px);color:#fff;text-align:center;overflow:hidden}',
      '.rp-kiralik b{display:block;font-family:var(--disp);font-size:26px;letter-spacing:2px}.rp-kiralik span{display:block;font-size:14px;color:#c9d1e6;margin-top:4px}',
      '.rp-kiralik::before{content:"";position:absolute;inset:10px;border:2px dashed rgba(255,255,255,.25);border-radius:3px}',
      /* Afişlerim */
      '.rp-afis-kart{background:var(--panel);border-radius:14px;padding:8px;border:1px solid var(--line);text-align:left;width:100%}',
      '.rp-afis-kart b{display:block;font-size:15px;margin:8px 4px 2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rp-afis-kart small{display:block;margin:0 4px 4px;color:var(--mut);font-size:13px}',
      '.rp-yeni-afis{display:grid;place-items:center;aspect-ratio:1000/440;border-radius:8px;border:2px dashed rgba(168,149,255,.5);color:var(--ink2);font-weight:800;font-size:16px;gap:4px}',
      /* Reklamlarım */
      '.rp-yayin{display:grid;grid-template-columns:120px 1fr;gap:12px;align-items:start}',
      '.rp-yayin .rp-afis{border-radius:6px}.rp-yayin h4{font-size:16px;line-height:1.3}.rp-yayin p{font-size:14px;color:var(--txt2);margin-top:3px;line-height:1.4}',
      '.rp-durum{display:inline-block;padding:3px 9px;border-radius:999px;font-size:12px;font-weight:800;letter-spacing:.3px}',
      '.rp-durum.yayinda{background:rgba(52,201,138,.16);color:#5BE0A7}.rp-durum.sirada{background:rgba(242,179,61,.16);color:#F7C766}.rp-durum.bitti{background:var(--panel2);color:var(--mut)}.rp-durum.kaldirildi{background:var(--albg);color:var(--al2)}',
      '.rp-istat{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:10px}.rp-istat div{background:var(--panel2);border-radius:10px;padding:8px;text-align:center}.rp-istat b{display:block;font-family:var(--disp);font-size:20px}.rp-istat small{font-size:12px;color:var(--mut)}',
      /* Harita */
      '.rp-harita{width:100%;height:auto;display:block}.rp-harita path{stroke:#0E1530;stroke-width:1.2;cursor:pointer;transition:fill .2s}',
      '.rp-harita path.bos{fill:#2a3670}.rp-harita path.kismi{fill:#7B61FF}.rp-harita path.dolu{fill:#F0454B}.rp-harita path.ben{stroke:#FFD54F;stroke-width:3}.rp-harita path.sec{fill:#FFD54F}',
      '.rp-lejant{display:flex;flex-wrap:wrap;gap:12px;font-size:13px;color:var(--txt2);margin-top:8px}.rp-lejant i{display:inline-block;width:12px;height:12px;border-radius:3px;margin-right:5px;vertical-align:-1px}',
      /* Stüdyo */
      '.rp-studyo{padding-bottom:84px}',
      '.rp-tuval-kap{position:sticky;top:-14px;z-index:5;margin:-14px -16px 10px;padding:12px 16px 8px;background:var(--bg);box-shadow:0 12px 18px -14px rgba(0,0,0,.85);border-bottom:1px solid var(--line)}',
      '.rp-tuval{position:relative;border-radius:10px;overflow:hidden;box-shadow:0 14px 30px -18px #000,0 0 0 1px rgba(255,255,255,.08)}',
      '.rp-tuval svg{display:block;width:100%;height:auto;touch-action:none;user-select:none;-webkit-user-select:none}',
      '.rp-tuval svg [data-i]{cursor:grab}.rp-sec-kutu{pointer-events:none}',
      '.rp-ipucu{font-size:13px;color:var(--mut);margin-top:6px;text-align:center}',
      '.rp-arac{display:flex;gap:8px;align-items:center;margin-bottom:10px}.rp-arac .btn{margin:0;width:auto;min-height:44px;padding:10px 14px}.rp-arac .rp-bosluk{flex:1}',
      '.rp-sekmeler{display:flex;gap:6px;overflow-x:auto;margin:6px 0 10px;padding-bottom:2px}',
      '.rp-sekmeler button{flex:0 0 auto;min-height:44px;padding:10px 16px;border-radius:999px;background:var(--panel2);color:var(--txt2);font-weight:800;font-size:15px}',
      '.rp-sekmeler button.aktif{background:#fff;color:#0E1530}',
      '.rp-izgara{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}',
      '.rp-sablon{background:var(--panel2);border-radius:12px;padding:6px;text-align:left;border:2px solid transparent}.rp-sablon b{display:block;font-size:14px;margin:6px 4px 2px}',
      '.rp-sablon:active,.rp-sablon.aktif{border-color:var(--ink2)}',
      '.rp-alan{margin-bottom:14px}.rp-alan>label{display:block;font-size:15px;font-weight:700;color:var(--txt);margin-bottom:6px;line-height:1.35}',
      '.rp-alan textarea,.rp-alan input[type=text],.rp-alan input[type=number],.rp-alan select{display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;line-height:1.4;padding:12px 13px;border-radius:12px;background:var(--panel2);color:var(--txt);border:1px solid var(--line2);color-scheme:dark}',
      '.rp-alan select option{background:#1D2850;color:#EEF1F8}.rp-alan textarea::placeholder,.rp-alan input::placeholder{color:#8f9bbd}',
      '.rp-alan input[type=range]{display:block;width:100%;min-width:0;height:36px;accent-color:#A895FF}',
      '.rp-alan .rp-deger{float:right;color:var(--mut);font-weight:600}',
      '.rp-secenek{display:flex;flex-wrap:wrap;gap:8px}.rp-secenek button{min-height:44px;padding:9px 14px;border-radius:12px;background:var(--panel2);color:var(--txt2);font-weight:700;font-size:15px;border:1px solid var(--line)}',
      '.rp-secenek button.aktif{background:var(--inkbg);color:#fff;border-color:var(--ink2)}',
      '.rp-renkler{display:flex;flex-wrap:wrap;gap:8px;align-items:center}.rp-renkler button{width:38px;height:38px;border-radius:50%;border:2px solid rgba(255,255,255,.18);box-shadow:inset 0 0 0 2px rgba(0,0,0,.25)}',
      '.rp-renkler button.aktif{outline:3px solid #fff;outline-offset:2px}.rp-renkler input[type=color]{width:44px;height:44px;border:0;padding:0;background:none;border-radius:50%}',
      '.rp-ikon-izgara{display:grid;grid-template-columns:repeat(auto-fill,minmax(64px,1fr));gap:8px}.rp-ikon-izgara button{display:grid;place-items:center;gap:4px;min-height:64px;border-radius:12px;background:var(--panel2);color:var(--txt);font-size:12px;padding:6px 4px;border:1px solid var(--line)}',
      '.rp-ikon-izgara button svg{width:28px;height:28px}.rp-ikon-izgara button.aktif{border-color:var(--ink2);background:var(--inkbg)}',
      '.rp-secili{background:linear-gradient(180deg,#1f2a57,#18214a);border:1px solid rgba(168,149,255,.35);border-radius:16px;padding:12px 12px 4px;margin-bottom:12px}',
      '.rp-secili-ust{display:flex;align-items:center;gap:8px;margin-bottom:10px}.rp-secili-ust b{flex:1;font-size:16px}',
      '.rp-mini{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:12px}.rp-mini button{flex:1 1 auto;min-height:44px;padding:9px 12px;border-radius:12px;background:var(--panel2);color:var(--txt);font-weight:700;font-size:14px}',
      '.rp-mini button.tehlike{background:var(--albg);color:var(--al2)}',
      '.rp-alt-bar{position:fixed;left:0;right:0;bottom:0;z-index:15;display:grid;grid-template-columns:1fr 1.4fr;gap:10px;padding:10px 14px calc(var(--safeB,12px) + 6px);background:linear-gradient(180deg,rgba(14,21,48,0),rgba(14,21,48,.96) 26%);}',
      '.rp-alt-bar .btn{margin:0;min-height:50px}',
      '.rp-slogan{display:block;width:100%;text-align:left;min-height:48px;padding:12px 14px;margin-bottom:8px;border-radius:12px;background:var(--panel2);color:var(--txt);font-size:16px;font-weight:700;line-height:1.35}',
      /* Kiralama */
      '.rp-teklif{background:linear-gradient(160deg,#20295a,#141b3d);border-radius:16px;padding:14px;border:1px solid var(--line2);margin:12px 0}',
      '.rp-teklif-satir{display:flex;justify-content:space-between;gap:10px;font-size:15px;padding:5px 0;color:var(--txt2);line-height:1.35}.rp-teklif-satir b{color:var(--txt);text-align:right}',
      '.rp-teklif-toplam{display:flex;justify-content:space-between;align-items:baseline;border-top:1px solid var(--line2);margin-top:8px;padding-top:10px}.rp-teklif-toplam span{font-size:15px;color:var(--txt2)}.rp-teklif-toplam b{font-family:var(--disp);font-size:30px;color:#fff}',
      '.rp-not{font-size:14px;color:var(--txt2);line-height:1.45;margin-top:8px}.rp-not.uyari{color:#F7C766}',
      '.rp-radyo{display:block;width:100%;text-align:left;min-height:52px;padding:12px 14px;border-radius:12px;background:var(--panel2);color:var(--txt);font-size:15px;margin-bottom:8px;border:1px solid var(--line);line-height:1.35}',
      '.rp-radyo.aktif{border-color:var(--ink2);background:var(--inkbg)}.rp-radyo small{display:block;color:var(--mut);font-size:13px;margin-top:2px}',
      /* Kutlama */
      '.rp-kutlama{position:fixed;inset:0;z-index:9999;display:grid;place-items:center;padding:20px;background:radial-gradient(circle at 50% 32%,#2a1f5e,#0a0f26 62%,#05081a);animation:rpBelir .35s ease both}',
      '.rp-kutlama-ic{width:100%;max-width:520px;text-align:center}',
      '.rp-kutlama h2{font-family:var(--disp);font-size:30px;color:#fff;margin-top:22px;line-height:1.1}.rp-kutlama p{font-size:15px;color:#c9d1e6;margin-top:8px;line-height:1.45}',
      '.rp-kutlama .rp-pano-yuzey{animation:rpYukari 1.1s cubic-bezier(.2,.9,.25,1) .25s both}',
      '.rp-kutlama .rp-pano-lamba i{animation:rpYan 1.6s steps(1) .9s both}',
      '@keyframes rpBelir{from{opacity:0}to{opacity:1}}@keyframes rpYukari{from{clip-path:inset(100% 0 0 0);filter:brightness(.3)}to{clip-path:inset(0 0 0 0);filter:brightness(1)}}',
      '@keyframes rpYan{0%{opacity:.3}20%{opacity:1}30%{opacity:.4}45%,100%{opacity:1}}',
      '.rp-isik-par{position:absolute;width:6px;height:6px;border-radius:50%;background:#ffe9a8;box-shadow:0 0 12px 3px rgba(255,220,130,.8);animation:rpPar 2.4s ease-out infinite}',
      '@keyframes rpPar{from{transform:translateY(0) scale(1);opacity:1}to{transform:translateY(-160px) scale(.2);opacity:0}}',
      /* Gündem şeridi */
      '.rp-serit{padding:12px 12px 10px;background:linear-gradient(165deg,#1a2350,#121936);border:1px solid rgba(255,255,255,.07);overflow:hidden}',
      '.rp-serit-ust{display:flex;align-items:center;gap:8px;margin-bottom:2px}.rp-serit-ust b{font-size:15px}.rp-serit-ust small{color:var(--mut);font-size:13px}.rp-serit-ust .rp-bosluk{flex:1}',
      '.rp-serit-ust button{min-height:36px;padding:6px 12px;border-radius:999px;background:rgba(255,255,255,.1);color:#fff;font-weight:700;font-size:13px}',
      '.rp-kunye-satir{font-size:13px;color:var(--mut);margin-top:6px;display:flex;gap:8px;align-items:center}.rp-kunye-satir span{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
      '.rp-isletme-serit{display:flex;flex-wrap:wrap;align-items:center;gap:6px 8px;margin:-2px 0 10px;padding:9px 12px;border-radius:12px;background:linear-gradient(135deg,rgba(255,138,61,.16),rgba(240,69,75,.10));border:1px solid rgba(255,138,61,.35);font-size:14px;line-height:1.35}',
      '.rp-isletme-serit.idare{background:var(--panel);border-color:var(--line)}.rp-isletme-serit span:last-child{color:var(--txt2);flex-basis:100%}',
      '.rp-ih-rozet{display:inline-block;padding:3px 8px;border-radius:6px;background:#ff8a3d;color:#1a0f0a;font-size:11px;font-weight:900;letter-spacing:.6px}',
      '.rp-isletme-serit.idare .rp-ih-rozet{background:#7b8bb8;color:#0E1530}',
      '.rp-ihale{margin-bottom:12px;border-color:rgba(255,138,61,.28);background:linear-gradient(170deg,#1f2347,#151b38)}.rp-ihale.kapali{border-color:var(--line);background:var(--panel)}',
      '.rp-ihale.kapali .rp-ih-rozet{background:#7b8bb8;color:#0E1530}',
      '.rp-ihale-ust{display:flex;align-items:center;gap:8px;margin-bottom:8px}.rp-ihale h4{font-family:var(--disp);font-size:20px;line-height:1.15}',
      '.rp-geri-sayim{font-size:13px;font-weight:800;color:#F7C766}',
      '.rp-ihale-izgara{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:10px 0}.rp-ihale-izgara div{background:rgba(255,255,255,.05);border-radius:10px;padding:8px 10px}',
      '.rp-ihale-izgara small{display:block;font-size:12px;color:var(--mut)}.rp-ihale-izgara b{font-size:16px}',
      '.rp-detay{margin:6px 0 12px}.rp-detay>summary{min-height:44px;display:flex;align-items:center;font-weight:800;color:var(--txt2);cursor:pointer}',
      '.rp-pano-no{display:inline-block;padding:2px 7px;border-radius:6px;background:var(--panel3);font-size:12px;font-weight:800;color:var(--txt)}',
      '.rp-pano-sec{display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:8px}.rp-pano-sec button{display:grid;gap:2px;text-align:left;min-height:64px;padding:9px 10px;border-radius:12px;background:var(--panel2);color:var(--txt);border:1px solid var(--line)}',
      '.rp-pano-sec button.aktif{border-color:var(--ink2);background:var(--inkbg)}.rp-pano-sec b{font-size:14px}.rp-pano-sec span{font-size:14px;font-weight:700;color:#F7C766}.rp-pano-sec small{font-size:12px;color:var(--mut)}',
      '@media (prefers-reduced-motion:reduce){.rp-pano-yuzey::after,.rp-kutlama .rp-pano-yuzey,.rp-isik-par{animation:none!important}.rp-dondur>.rp-kare{transition:none}}'
    ].join('\n');
    document.head.appendChild(st);
  }

  /* ---------------------------------------------------------------
     4) PANO BİLEŞENİ, ŞEHİR SAHNESİ
     --------------------------------------------------------------- */
  function panoHTML(icerik, o) {
    o = o || {};
    return '<div class="rp-pano' + (o.kucuk ? ' kucuk' : '') + '"' + (o.id ? ' id="' + o.id + '"' : '') + '><div class="rp-pano-lamba"><i></i><i></i><i></i></div><div class="rp-pano-cerceve"><div class="rp-pano-yuzey">' + icerik + '</div></div><div class="rp-pano-ayak"></div></div>';
  }
  function zamanDilimi() {
    var h = trSaat();
    return h >= 20 || h < 5 ? 'gece' : h < 7 ? 'safak' : h < 17 ? 'gunduz' : 'aksam';
  }
  function gokSvg(tohum) {
    var dilim = zamanDilimi(), u = 'rpg' + (++RP.uid);
    var g = { gece: ['#060a1f', '#141d48', '#26306a'], safak: ['#1d2259', '#8d4f7d', '#f2a46b'], gunduz: ['#2f6fd6', '#71a9f0', '#cfe6ff'], aksam: ['#20184d', '#7a3b74', '#ff8a5c'] }[dilim];
    var bina = { gece: '#0a0f26', safak: '#1a1638', gunduz: '#3a4a78', aksam: '#1c1433' }[dilim];
    var s = '<svg class="rp-gok" viewBox="0 0 1000 600" preserveAspectRatio="xMidYMax slice" aria-hidden="true"><defs><linearGradient id="' + u + '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + g[0] + '"/><stop offset=".6" stop-color="' + g[1] + '"/><stop offset="1" stop-color="' + g[2] + '"/></linearGradient></defs><rect width="1000" height="600" fill="url(#' + u + ')"/>';
    var r = (tohum || 7) * 9301 + 49297, rnd = function () { r = (r * 9301 + 49297) % 233280; return r / 233280; }, i;
    if (dilim === 'gece') {
      for (i = 0; i < 70; i++) s += '<circle cx="' + (rnd() * 1000).toFixed(0) + '" cy="' + (rnd() * 330).toFixed(0) + '" r="' + (rnd() * 1.6 + 0.3).toFixed(1) + '" fill="#fff" opacity="' + (rnd() * 0.7 + 0.2).toFixed(2) + '"/>';
      s += '<circle cx="840" cy="90" r="34" fill="#fdf3d0"/><circle cx="856" cy="80" r="30" fill="' + g[0] + '" opacity=".92"/>';
    } else if (dilim === 'gunduz') {
      s += '<circle cx="830" cy="100" r="46" fill="#fff6d1" opacity=".9"/><circle cx="830" cy="100" r="90" fill="#fff6d1" opacity=".18"/>';
      for (i = 0; i < 4; i++) { var cx = 120 + i * 230 + rnd() * 60, cy = 80 + rnd() * 90; s += '<g fill="#fff" opacity=".55"><ellipse cx="' + cx + '" cy="' + cy + '" rx="70" ry="20"/><ellipse cx="' + (cx + 30) + '" cy="' + (cy - 14) + '" rx="40" ry="20"/></g>'; }
    } else {
      s += '<circle cx="' + (dilim === 'safak' ? 160 : 820) + '" cy="440" r="70" fill="#ffd28a" opacity=".85"/>';
    }
    // Uzak ve yakın siluet
    var katman = function (taban, yuk, renk, op, pencere) {
      var x = -20, out = '';
      while (x < 1020) {
        var w = 34 + rnd() * 70, h = taban + rnd() * yuk;
        out += '<rect x="' + x.toFixed(0) + '" y="' + (600 - h).toFixed(0) + '" width="' + w.toFixed(0) + '" height="' + h.toFixed(0) + '" fill="' + renk + '" opacity="' + op + '"/>';
        if (rnd() < 0.18) out += '<rect x="' + (x + w / 2 - 2).toFixed(0) + '" y="' + (600 - h - 26).toFixed(0) + '" width="4" height="26" fill="' + renk + '" opacity="' + op + '"/>';
        if (pencere && (dilim === 'gece' || dilim === 'aksam')) {
          for (var py = 600 - h + 12; py < 590; py += 16) for (var px = x + 7; px < x + w - 8; px += 13) if (rnd() < (dilim === 'gece' ? 0.32 : 0.16)) out += '<rect x="' + px.toFixed(0) + '" y="' + py.toFixed(0) + '" width="5" height="7" fill="#ffd77a" opacity="' + (0.5 + rnd() * 0.5).toFixed(2) + '"/>';
        }
        x += w + 2;
      }
      return out;
    };
    s += katman(110, 160, bina, 0.55, false) + katman(60, 120, bina, 1, true);
    s += '<rect y="590" width="1000" height="10" fill="#05081a"/></svg>';
    return { svg: s, dilim: dilim };
  }

  /* ---------------------------------------------------------------
     5) VERİ
     --------------------------------------------------------------- */
  function vitrinYukle(il, zorla) {
    il = il || (profil() && profil().il_id) || null;
    if (!zorla && RP.vitrin && RP.vitrinIl === il && Date.now() - RP.vitrinT < 120000) return Promise.resolve(RP.vitrin);
    return API.rpc('pano_vitrin', { p_il: il }).then(function (d) { RP.vitrin = d; RP.vitrinT = Date.now(); RP.vitrinIl = il; return d; });
  }
  function merkezYukle() { return API.rpc('pano_merkez').then(function (d) { RP.merkez = d; return d; }); }

  function kiralikAfis(il, fiyat) {
    return { v: 1, zemin: { tip: 'serit', r1: '#141a36', r2: '#1b2346' }, ogeler: [
      { t: 'sekil', sekil: 'kutu', x: 500, y: 220, w: 900, h: 340, renk: '#0E1530', yuvarlak: 10, op: 0.85 },
      { t: 'metin', m: 'BU PANO KİRALIK', x: 500, y: 150, boy: 86, renk: '#FFFFFF', font: 'blok', kal: 900, hiza: 'middle', harf: 4 },
      { t: 'metin', m: (il ? il + ' görsün: ' : '') + 'afişini tasarla, yayınla', x: 500, sig: 860, y: 235, boy: 36, renk: '#C9D1E6', font: 'kurul', kal: 700, hiza: 'middle' },
      { t: 'sekil', sekil: 'kutu', x: 500, y: 325, w: 470, h: 70, renk: '#FF8A3D', yuvarlak: 35 },
      { t: 'metin', m: fiyat ? 'Günlük ' + tl(fiyat) + '’den başlayan fiyat' : 'Hemen kirala', x: 500, y: 326, boy: 28, renk: '#FFFFFF', font: 'kurul', kal: 900, hiza: 'middle' }
    ], efekt: { parlama: true, vinyet: 0.3 } };
  }

  /* ---------------------------------------------------------------
     6) GÜNDEM ŞERİDİ
     --------------------------------------------------------------- */
  function seritCiz(deneme) {
    var kok = document.getElementById('icerik');
    if (!kok || document.getElementById('rpSerit')) return;
    // Gündem'in hızlı erişim satırı (premium katman) çizilince hemen altına yerleş
    var hizli = kok.querySelector('.pa-hizli');
    if (!hizli && (deneme || 0) < 6) { setTimeout(function () { seritCiz((deneme || 0) + 1); }, 110); return; }
    if (typeof D !== 'undefined' && D && D.sekme !== 'gundem') return;
    try { if (window.UZAKTAN && typeof UZAKTAN.modulAcik === 'function' && !UZAKTAN.modulAcik('reklam_panosu')) return; } catch (_) {}
    stilKur();
    var kap = document.createElement('div');
    kap.className = 'kart rp-serit'; kap.id = 'rpSerit';
    kap.innerHTML = '<div class="rp-serit-ust"><b>📍 Reklam panosu</b><span class="rp-bosluk"></span><button type="button" data-rp="panolar">Panolar ›</button></div>' + panoHTML('<div class="rp-kiralik"><div><b>…</b></div></div>', { kucuk: true });
    if (hizli && hizli.parentNode) hizli.parentNode.insertBefore(kap, hizli.nextSibling);
    else kok.insertBefore(kap, kok.firstChild);
    kap.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-rp]'); if (!b) return;
      ev.preventDefault();
      if (b.dataset.rp === 'panolar') ekranAc(reklamPanolariEkrani);
      else if (b.dataset.rp === 'yayin') yayinModal(Number(b.dataset.id));
    });
    vitrinYukle(null, false).then(function (v) { if (document.body.contains(kap)) seritDoldur(kap, v); }).catch(function () { kap.remove(); });
  }
  function seritDoldur(kap, v) {
    if (!v || v.acik === false && !(v.ulke || []).length && !(v.yerel || []).length) { kap.remove(); return; }
    var hepsi = (v.ulke || []).concat(v.yerel || []);
    var ust = '<div class="rp-serit-ust"><b>📍 ' + esc(v.il || '') + ' panosu</b><small>' + (hepsi.length ? hepsi.length + ' reklam' : 'boş') + '</small><span class="rp-bosluk"></span><button type="button" data-rp="panolar">Panolar ›</button></div>';
    var kareler = hepsi.length
      ? hepsi.map(function (y, i) { return '<div class="rp-kare' + (i === 0 ? ' aktif' : '') + '" data-rp="yayin" data-id="' + Number(y.id) + '" role="button" tabindex="0">' + afisSvg(y.tasarim, { kunye: y.sahip_ad, etiket: y.ad }) + '</div>'; }).join('')
      : '<div class="rp-kare aktif" data-rp="panolar" role="button" tabindex="0">' + afisSvg(kiralikAfis(v.il, v.fiyat_il && v.fiyat_il.gunluk)) + '</div>';
    var alt = hepsi.length ? '<div class="rp-kunye-satir" id="rpSeritKunye"><span>' + kunyeYaz(hepsi[0]) + '</span></div>' : (v.yasak && v.gizlenen ? '<div class="rp-kunye-satir"><span>Seçim yasağı: ' + v.gizlenen + ' siyasi reklam oy verme bitene kadar gösterilmiyor.</span></div>' : '');
    var dilim = zamanDilimi();
    kap.innerHTML = ust + '<div class="' + (dilim === 'gece' ? 'rp-gece' : '') + '">' + panoHTML('<div class="rp-dondur">' + kareler + '</div>', { kucuk: true }) + '</div>' + alt;
    if (hepsi.length > 1) {
      var idx = 0, zam = setInterval(function () {
        if (!document.body.contains(kap)) { clearInterval(zam); return; }
        if (document.hidden) return;
        var k = kap.querySelectorAll('.rp-dondur>.rp-kare'); if (!k.length) return;
        k[idx].classList.remove('aktif'); idx = (idx + 1) % k.length; k[idx].classList.add('aktif');
        var ky = document.getElementById('rpSeritKunye'); if (ky) ky.innerHTML = '<span>' + kunyeYaz(hepsi[idx]) + '</span>';
      }, 6500);
    }
  }
  function kunyeYaz(y) {
    return esc(y.kapsam === 'ulke' ? 'Ülke geneli' : (y.il || '')) + ' · ' + esc(y.sahip_ad) + ' · ♥ ' + sayiYaz(y.begeni) + ' · ' + sayiYaz(y.gosterim) + ' kişi gördü';
  }

  /* ---------------------------------------------------------------
     7) REKLAM PANOLARI EKRANI
     --------------------------------------------------------------- */
  var EKR = { il: null, haritaSec: null };
  async function reklamPanolariEkrani() {
    stilKur();
    yukleniyor('Reklam Panoları');
    var m, v;
    try {
      var p = profil();
      EKR.il = EKR.il || (p && p.il_id) || null;
      var r = await Promise.all([merkezYukle(), vitrinYukle(EKR.il, true), API.rpc('pano_ihale_merkez').catch(function () { return null; })]);
      m = r[0]; v = r[1]; RP.ihale = r[2];
    } catch (err) {
      iskelet('Reklam Panoları', hazirlikMi(err) ? hazirlikHTML : '<div class="kart">' + esc(typeof hataCevir === 'function' ? hataCevir(err.message) : err.message) + '</div>', { geri: true });
      return;
    }
    var gok = gokSvg(Number(v.il_id) || 7), ul = (v.ulke || []), yer = (v.yerel || []), hepsi = ul.concat(yer);
    var ilBilgi = (m.iller || []).find(function (i) { return Number(i.id) === Number(v.il_id); }) || {};
    var slotIl = (ilBilgi.fiyat && ilBilgi.fiyat.slot) || 2, slotUlke = (m.ulke && m.ulke.fiyat && m.ulke.fiyat.slot) || 3;
    var h = '';
    // Sahne
    var sahneKare = hepsi.length
      ? hepsi.map(function (y, i) { return '<div class="rp-kare' + (i === 0 ? ' aktif' : '') + '" data-rp="yayin" data-id="' + Number(y.id) + '" role="button" tabindex="0">' + afisSvg(y.tasarim, { kunye: y.sahip_ad, etiket: y.ad }) + '</div>'; }).join('')
      : '<div class="rp-kare aktif" data-rp="kirala" role="button" tabindex="0">' + afisSvg(kiralikAfis(v.il, v.fiyat_il && v.fiyat_il.gunluk)) + '</div>';
    h += '<section class="rp-sahne ' + (gok.dilim === 'gece' ? 'rp-gece' : '') + '">' + gok.svg + '<div class="rp-sahne-ic">' +
      '<div class="rp-sahne-ust"><div style="flex:1"><h2>Reklam Panoları</h2><p>Afişini tasarla; ' + esc(v.il || 'ilinde') + ' ya da bütün Türkiye görsün.</p></div></div>' +
      '<div class="rp-sahne-pano">' + panoHTML('<div class="rp-dondur" id="rpSahneDondur">' + sahneKare + '</div>') + (hepsi.length > 1 ? '<div class="rp-nokta-sira">' + hepsi.map(function (_, i) { return '<i class="' + (i === 0 ? 'aktif' : '') + '"></i>'; }).join('') + '</div>' : '') + '</div>' +
      '<div class="rp-cip-sira"><button type="button" class="rp-cip" data-rp="ilsec">📍 ' + esc(v.il || '') + ' · ' + slotIl + ' pano ▾</button><span class="rp-cip">🇹🇷 Ülke geneli · ' + slotUlke + ' dev pano</span>' + (m.sezon ? '<span class="rp-cip" style="background:rgba(242,179,61,.22)">🗳️ Seçim sezonu · fiyatlar ' + String(m.ayar.secim_carpan).replace('.', ',') + ' kat</span>' : '') + '</div>' +
      '<div class="rp-eylem-sira"><button type="button" class="btn rp-btn-sicak" data-rp="studyo">✨ Afiş tasarla</button><button type="button" class="btn ikinci" data-rp="kirala">Panoyu kirala</button></div>' +
      '</div></section>';
    if (!m.ayar.acik) h += '<div class="kart"><b>Reklam panoları şu an yeni kiralamaya kapalı.</b><p class="rp-not">Yayındaki reklamlar süreleri bitene kadar görünür.</p></div>';
    if (v.yasak && v.gizlenen) h += '<div class="kart"><b>🗳️ Seçim yasağı sürüyor</b><p class="rp-not">Oy verme saatlerinde ' + v.gizlenen + ' siyasi reklam gösterilmiyor. Süreleri işlemeye devam ediyor.</p></div>';
    // Ülke geneli
    h += '<div class="rp-bolum"><h3>Ülke geneli dev panolar</h3><small>Bütün oyuncular görür</small></div>' + isletmeSerit(m.ulke && m.ulke.fiyat, 'Ulaştırma ve Altyapı Bakanlığı') + '<div class="rp-yatay">' + slotKartlari(ul, slotUlke, 'ulke', m.ulke && m.ulke.fiyat) + '</div>';
    // İl
    h += '<div class="rp-bolum"><h3>' + esc(v.il || '') + ' panoları</h3><small>' + esc(v.il || 'İl') + 'de oynayanlar görür</small></div>' + isletmeSerit(ilBilgi.fiyat, (v.il || '') + ' Belediyesi') + '<div class="rp-yatay">' + slotKartlari(yer, slotIl, 'il', ilBilgi.fiyat) + '</div>';
    // İhaleler ve işletmeler
    h += ihaleBolum(RP.ihale, v);
    // Afişlerim
    var afisler = m.afisler || [];
    h += '<div class="rp-bolum"><h3>Afişlerim</h3><small>' + afisler.length + ' tasarım</small></div><div class="rp-yatay">' +
      '<button type="button" class="rp-afis-kart" data-rp="studyo"><div class="rp-yeni-afis"><div>＋<br>Yeni afiş</div></div><b>Afiş Stüdyosu</b><small>12 hazır şablonla başla</small></button>' +
      afisler.map(function (f) { return '<button type="button" class="rp-afis-kart" data-rp="afis" data-id="' + Number(f.id) + '">' + afisSvg(f.tasarim) + '<b>' + esc(f.ad) + '</b><small>' + esc(sahipEtiket(f, m)) + (f.yayinda ? ' · <span style="color:#5BE0A7">yayında</span>' : '') + '</small></button>'; }).join('') + '</div>';
    // Reklamlarım
    var yl = m.yayinlarim || [];
    if (yl.length) {
      h += '<div class="rp-bolum"><h3>Reklamlarım</h3><small>' + yl.filter(function (y) { return y.durum === 'aktif'; }).length + ' etkin</small></div>';
      h += yl.slice(0, 20).map(function (y) { return yayinSatir(y, m); }).join('');
    }
    // Harita
    h += '<div class="rp-bolum"><h3>Türkiye reklam haritası</h3><small>Bir ile dokun</small></div><div class="rp-kart">' + haritaSvg(m, v.il_id) +
      '<div class="rp-lejant"><span><i style="background:#2a3670"></i>Boş</span><span><i style="background:#7B61FF"></i>Kısmen dolu</span><span><i style="background:#F0454B"></i>Dolu</span><span><i style="background:none;box-shadow:inset 0 0 0 2px #FFD54F"></i>Senin ilin</span></div><div id="rpHaritaBilgi"></div></div>';
    // Belediye
    if (m.belediye) h += belediyeKart(m.belediye, m);
    // Moderatör
    if (m.moderator && (m.sikayetler || []).length) h += sikayetKart(m.sikayetler);
    // Kurallar
    h += '<details class="kart" style="margin-top:16px"><summary style="font-weight:800;font-size:16px;min-height:44px;display:flex;align-items:center">Fiyatlar ve kurallar</summary><div class="rp-not">' +
      '<p>• İl panosu fiyatı ilin nüfusuna ve kişi başı gelirine göre belirlenir: İstanbul en pahalı, küçük iller en uygun. Belediye başkanı kendi ilinin tarifesini 0,5–2 kat arasında ayarlayabilir.</p>' +
      '<p>• Panolar doldukça fiyat artar (bütün panolar doluyken ' + String(1 + Number(m.ayar.doluluk_carpan)).replace('.', ',') + ' kat). Oy verme başlangıcına 72 saatten az kalınca fiyatlar ' + String(m.ayar.secim_carpan).replace('.', ',') + ' kat olur.</p>' +
      '<p>• 3 gün ve üzeri %4, 7 gün %10, 14 gün %18, 30 gün %25 indirim. En uzun ' + m.ayar.en_uzun_gun + ' gün.</p>' +
      '<p>• Bütün panolar doluysa reklamın sıraya girer ve ilk boşalan panoda en geç ' + m.ayar.sira_gun + ' gün içinde başlar.</p>' +
      '<p>• İl panosu kirası o ilin belediye kasasına, ülke geneli kira Hazine’ye gelir yazılır.</p>' +
      '<p>• Her afişin altında herkesin göreceği bir künye bulunur: "Ödeyen: …".</p>' +
      (m.ayar.secim_gunu_yasak ? '<p>• Seçim yasağı: oy verme saatlerinde parti ve aday reklamları gösterilmez; süre işlemeye devam eder.</p>' : '') +
      '<p>• Panoların işletme hakkı ihaleyle verilir (il panoları: il belediyesi, ülke geneli: Ulaştırma ve Altyapı Bakanlığı). İhaleyi kazanan sözleşme boyunca fiyatları kendisi belirler ve kira gelirini alır; her kiralamadan ilan ve reklam vergisi idareye ödenir. İşletmecisi olmayan panoları idare resmî tarifeyle kiralar.</p>' +
      '<p>• Hakaret, küfür ve yanıltıcı içerik şikâyet üzerine yayından kaldırılır.</p></div></details>';
    iskelet('Reklam Panoları', h, { geri: true });
    var kok = document.getElementById('icerik');
    if (!kok) return;
    kok.onclick = function (ev) { ekranTik(ev, m, v); };
    // Sahnede dönen reklamlar
    if (hepsi.length > 1) {
      var idx = 0, zam = setInterval(function () {
        var dd = document.getElementById('rpSahneDondur'); if (!dd) { clearInterval(zam); return; }
        if (document.hidden) return;
        var k = dd.children, n = document.querySelectorAll('.rp-nokta-sira i');
        k[idx].classList.remove('aktif'); if (n[idx]) n[idx].classList.remove('aktif');
        idx = (idx + 1) % k.length; k[idx].classList.add('aktif'); if (n[idx]) n[idx].classList.add('aktif');
      }, 6000);
    }
    var ts = document.getElementById('rpTarife');
    if (ts) ts.addEventListener('input', function () {
      var c = Number(ts.value), b = m.belediye, il = (m.iller || []).find(function (i) { return Number(i.id) === Number(b.il_id); });
      var eskiG = il ? Number(il.fiyat.gunluk) : 0, yeni = eskiG / Math.max(0.5, Number(b.carpan) || 1) * c;
      document.getElementById('rpTarifeDeger').textContent = String(c.toFixed(2)).replace('.', ',') + ' kat';
      document.getElementById('rpTarifeFiyat').textContent = 'Yeni günlük fiyat yaklaşık ' + tl(Math.round(yeni / 50) * 50);
    });
  }
  function sahipEtiket(f, m) {
    if (f.sahip_tur === 'oyuncu') return 'Kişisel';
    var k = (m.kaynaklar || []).find(function (x) { return x.tur === f.sahip_tur && Number(x.id) === Number(f.sahip_id); });
    return k ? k.ad : ({ parti: 'Parti', dernek: 'Dernek', sirket: 'Şirket', gazete: 'Gazete' }[f.sahip_tur] || '');
  }
  function slotKartlari(liste, slot, kapsam, fiyat) {
    var out = [], kul = {};
    var reklam = function (y) {
      return '<div class="rp-kart">' + panoHTML('<div data-rp="yayin" data-id="' + Number(y.id) + '" role="button" tabindex="0">' + afisSvg(y.tasarim, { kunye: y.sahip_ad, etiket: y.ad }) + '</div>', { kucuk: true }) +
        '<div class="rp-pano-etiket"><span class="rp-pano-no">Pano ' + Number(y.slot || 1) + '</span><b>' + esc(y.sahip_ad) + '</b><span class="rp-bosluk"></span><span>' + kalanYaz(y.bit) + '</span></div>' +
        '<div class="rp-pano-etiket"><button type="button" class="rp-cip" data-rp="begen" data-id="' + Number(y.id) + '" style="background:' + (y.begendim ? 'rgba(240,69,75,.25)' : 'rgba(255,255,255,.08)') + '">' + (y.begendim ? '♥' : '♡') + ' ' + sayiYaz(y.begeni) + '</button><span>👁 ' + sayiYaz(y.gosterim) + ' kişi</span></div></div>';
    };
    for (var s = 1; s <= slot; s++) {
      var y = liste.find(function (x) { return Number(x.slot) === s && !kul[x.id]; });
      if (y) { kul[y.id] = 1; out.push(reklam(y)); continue; }
      var fy = fiyat && fiyat.fiyatlar ? Number(fiyat.fiyatlar[s - 1]) : fiyat ? Number(fiyat.gunluk) : 0;
      out.push('<div class="rp-kart">' + panoHTML('<div class="rp-kiralik" data-rp="kirala" data-kapsam="' + kapsam + '" data-slot="' + s + '" role="button" tabindex="0"><div><b>KİRALIK</b><span>' + (fy ? 'Günlük ' + tl(fy) : 'Hemen kirala') + '</span></div></div>', { kucuk: true }) +
        '<div class="rp-pano-etiket"><span class="rp-pano-no">Pano ' + s + '</span><span>Boş</span><span class="rp-bosluk"></span><button type="button" class="rp-cip" data-rp="kirala" data-kapsam="' + kapsam + '" data-slot="' + s + '">Kirala ›</button></div></div>');
    }
    liste.forEach(function (y) { if (!kul[y.id]) out.push(reklam(y)); });
    if (!out.length) out.push('<div class="rp-kart"><p class="rp-not">Pano bulunamadı.</p></div>');
    return out.join('');
  }
  function isletmeSerit(fiyat, idare) {
    var isl = fiyat && fiyat.isletme;
    if (isl) return '<div class="rp-isletme-serit"><span class="rp-ih-rozet">İŞLETMECİ</span><b>' + esc(isl.ad) + '</b><span>fiyatları işletmeci belirliyor · sözleşme ' + tarihKisa(isl.bit) + '’e kadar</span></div>';
    return '<div class="rp-isletme-serit idare"><span class="rp-ih-rozet">İDARE</span><b>' + esc(idare) + '</b><span>işletmeci yok; resmî tarife' + (fiyat && fiyat.sonraki_isletme ? ' · ' + tarihKisa(fiyat.sonraki_isletme) + '’ten itibaren yeni işletmeci' : '') + '</span></div>';
  }
  function ihaleKonu(i) { return i.kapsam === 'ulke' ? 'Ülke geneli ' + i.slot + ' dev pano' : (i.il || '') + ' il panoları (' + i.slot + ' pano)'; }
  function ihaleKart(i) {
    var acik = i.durum === 'acik', benim = (i.benim || [])[0];
    var h = '<div class="rp-kart rp-ihale' + (acik ? '' : ' kapali') + '"><div class="rp-ihale-ust"><span class="rp-ih-rozet">' + (acik ? 'İHALE · KAPALI TEKLİF' : 'SONUÇ İLANI') + '</span><span class="rp-bosluk"></span>' +
      (acik ? '<span class="rp-geri-sayim">⏳ ' + kalanYaz(i.bit) + '</span>' : '<span class="rp-geri-sayim">' + tarihKisa(i.bit) + '</span>') + '</div>' +
      '<h4>' + esc(ihaleKonu(i)) + ' işletme hakkı</h4><p class="rp-not" style="margin-top:2px">İdare: ' + esc(i.idare) + '</p>';
    if (acik) {
      h += '<div class="rp-ihale-izgara"><div><small>Muhammen bedel</small><b>' + tl(i.muhammen) + '</b></div><div><small>En düşük teklif</small><b>' + tl(i.asgari) + '</b></div>' +
        '<div><small>Geçici teminat</small><b>%' + Math.round(Number(i.teminat_oran) * 100) + '</b></div><div><small>İşletme süresi</small><b>' + i.isletme_gun + ' gün</b></div>' +
        '<div><small>İşletme başlangıcı</small><b>' + tarihKisa(i.isletme_bas) + '</b></div><div><small>Verilen teklif</small><b>' + Number(i.teklif_say || 0) + ' zarf</b></div></div>';
      if (benim) h += '<p class="rp-not" style="color:#5BE0A7">✓ Teklifin: ' + tl(benim.tutar) + ' (' + esc(benim.ad) + ') · ' + tl(benim.teminat) + ' teminat yatırıldı. Zarflar ' + tarihKisa(i.bit) + '’te açılacak.</p>';
      else if (i.yetkili) h += '<p class="rp-not uyari">İhale yetkilisi olduğun için bu ihaleye teklif veremezsin.</p>';
      else h += '<button type="button" class="btn" data-rp="ihale" data-id="' + Number(i.id) + '">Kapalı teklif ver</button>';
    } else if (i.durum === 'sonuclandi' && i.kazanan) {
      h += '<p class="rp-not">🏆 Kazanan: <b>' + esc(i.kazanan.ad) + '</b> · ' + tl(i.kazanan.tutar) + ' · ' + Number(i.teklif_say || 0) + ' teklif · muhammen ' + tl(i.muhammen) + '</p>';
      if (benim) h += '<p class="rp-not">Senin teklifin: ' + tl(benim.tutar) + ' · ' + ({ kazandi: 'kazandı', kaybetti: 'kaybetti, teminat iade edildi', irat: 'bedel ödenemedi, teminat irat kaydedildi' }[benim.durum] || benim.durum) + '</p>';
    } else {
      h += '<p class="rp-not">' + (i.durum === 'teklifsiz' ? 'Teklif çıkmadı; panoları idare işletmeye devam ediyor.' : i.durum === 'bozuldu' ? 'Kazananlar bedeli ödeyemedi; ihale bozuldu.' : 'İhale iptal edildi.') + '</p>';
    }
    return h + '</div>';
  }
  function ihaleBolum(ih, v) {
    if (!ih) return '';
    var benIl = Number(v.il_id), pIl = Number((profil() || {}).il_id);
    var acik = (ih.ihaleler || []).filter(function (i) { return i.durum === 'acik'; }).sort(function (a, b) {
      var oa = a.kapsam === 'ulke' ? 0 : Number(a.il_id) === benIl || Number(a.il_id) === pIl ? 1 : 2, ob = b.kapsam === 'ulke' ? 0 : Number(b.il_id) === benIl || Number(b.il_id) === pIl ? 1 : 2;
      return oa - ob || new Date(a.bit) - new Date(b.bit);
    });
    var kapali = (ih.ihaleler || []).filter(function (i) { return i.durum !== 'acik'; });
    var h = '<div class="rp-bolum"><h3>Pano ihaleleri</h3><small>' + acik.length + ' açık ihale</small></div>' +
      '<p class="rp-not" style="margin:-4px 0 10px">Panoların işletme hakkı ihaleyle kiraya verilir. En yüksek kapalı teklifi veren kazanır; sözleşme boyunca pano fiyatlarını kendisi belirler ve kira gelirini alır.</p>';
    var ilk = acik.slice(0, 3), kalan = acik.slice(3);
    h += ilk.map(ihaleKart).join('');
    if (kalan.length) h += '<details class="rp-detay"><summary>Diğer ' + kalan.length + ' ihale</summary>' + kalan.map(ihaleKart).join('') + '</details>';
    if (!acik.length) h += '<div class="rp-kart"><p class="rp-not">Şu an açık pano ihalesi yok. İşletmecisi olmayan panolar için ilan kendiliğinden yayımlanır.</p></div>';
    var isl = ih.isletmelerim || [];
    if (isl.length) {
      h += '<div class="rp-bolum"><h3>İşletmelerim</h3><small>' + isl.length + ' sözleşme</small></div>' + isl.map(function (z) {
        var fy = (z.fiyatlar || []).map(function (x, k) { return '<span class="rp-cip" style="background:var(--panel2)">Pano ' + (k + 1) + ' · ' + tl(x) + '</span>'; }).join('');
        return '<div class="rp-kart rp-ihale"><div class="rp-ihale-ust"><span class="rp-ih-rozet">' + (new Date(z.bas).getTime() > simdiMs() ? 'BAŞLAYACAK · ' + tarihKisa(z.bas) : 'İŞLETİYORSUN') + '</span><span class="rp-bosluk"></span><span class="rp-geri-sayim">⏳ ' + kalanYaz(z.bit) + '</span></div>' +
          '<h4>' + esc(z.kapsam === 'ulke' ? 'Ülke geneli dev panolar' : (z.il || '') + ' il panoları') + '</h4><p class="rp-not" style="margin-top:2px">İşletmeci: ' + esc(z.isletmeci_ad) + ' · ' + tarihKisa(z.bas) + ' – ' + tarihKisa(z.bit) + '</p>' +
          '<div class="rp-istat"><div><b>' + tl(z.bedel).replace(' ₺', '') + '</b><small>₺ ihale bedeli</small></div><div><b>' + tl(z.gelir).replace(' ₺', '') + '</b><small>₺ net kira</small></div><div><b>' + Number(z.dolu || 0) + '/' + z.slot + '</b><small>şu an dolu</small></div></div>' +
          '<div class="rp-cip-sira">' + fy + '</div><p class="rp-not">Resmî tarife karşılığı: ' + tl(z.devlet_gunluk) + '/gün · ' + Number(z.kiralama || 0) + ' kiralama · ' + tl(z.vergi) + ' vergi ödendi</p>' +
          '<button type="button" class="btn" data-rp="isletme" data-id="' + Number(z.id) + '">Pano fiyatlarını belirle</button></div>';
      }).join('');
    }
    var tum = ih.isletmeler || [];
    if (tum.length || kapali.length) {
      h += '<details class="rp-detay"><summary>Sonuçlanan ihaleler ve işletmeciler</summary>' +
        (tum.length ? '<div class="rp-kart"><b>Şu anki işletmeciler</b>' + tum.map(function (z) { return '<p class="rp-not">' + esc(z.kapsam === 'ulke' ? 'Ülke geneli' : z.il) + ' · <b>' + esc(z.ad) + '</b> · ' + tl(z.bedel) + ' · ' + tarihKisa(z.bit) + '’e kadar</p>'; }).join('') + '</div>' : '') +
        kapali.map(ihaleKart).join('') + '</details>';
    }
    return h;
  }
  function ihaleTeklifModal(id) {
    var ih = RP.ihale, i = ih && (ih.ihaleler || []).find(function (x) { return Number(x.id) === Number(id); }); if (!i) return;
    var kay = ih.kaynaklar || [], S = { k: 0, tutar: Number(i.asgari) };
    var md = modal('<h3 style="font-size:20px;font-weight:800">Kapalı teklif ver</h3><p class="rp-not" style="margin-top:4px">' + esc(ihaleKonu(i)) + ' işletme hakkı · ' + esc(i.idare) + '</p><div id="rpIhIc"></div>');
    function ciz() {
      var tem = Math.max(100, Math.round(S.tutar * Number(i.teminat_oran))), k = kay[S.k] || {};
      document.getElementById('rpIhIc').innerHTML =
        '<div class="rp-teklif"><div class="rp-teklif-satir"><span>Muhammen bedel</span><b>' + tl(i.muhammen) + '</b></div><div class="rp-teklif-satir"><span>En düşük teklif</span><b>' + tl(i.asgari) + '</b></div>' +
        '<div class="rp-teklif-satir"><span>İşletme</span><b>' + i.isletme_gun + ' gün · ' + tarihKisa(i.isletme_bas) + '’ten</b></div><div class="rp-teklif-satir"><span>Zarfların açılışı</span><b>' + tarihKisa(i.bit) + '</b></div></div>' +
        '<div class="rp-alan"><label>Teklifi veren</label>' + kay.map(function (x, n) { return '<button type="button" class="rp-radyo' + (n === S.k ? ' aktif' : '') + '" data-k="' + n + '"><b>' + esc(x.ad) + '</b><small>' + (x.tur === 'sirket' ? 'Şirket kasası' : 'Cüzdan') + ' · bakiye ' + tl(x.kasa) + '</small></button>'; }).join('') + '</div>' +
        '<div class="rp-alan"><label for="rpIhTutar">Teklif tutarı (₺)</label><input type="number" id="rpIhTutar" inputmode="numeric" min="' + Number(i.asgari) + '" step="500" value="' + S.tutar + '"></div>' +
        '<div class="rp-secenek" style="margin:-4px 0 14px"><button type="button" data-hizli="asgari">En düşük</button><button type="button" data-hizli="muhammen">Muhammen</button><button type="button" data-hizli="10">+%10</button></div>' +
        '<div class="rp-teklif"><div class="rp-teklif-satir"><span>Şimdi tahsil edilecek geçici teminat</span><b>' + tl(tem) + '</b></div><div class="rp-teklif-satir"><span>Kazanırsan kapanışta tahsil edilecek kalan</span><b>' + tl(Math.max(0, S.tutar - tem)) + '</b></div>' +
        '<div class="rp-teklif-toplam"><span>Teklif</span><b>' + tl(S.tutar) + '</b></div></div>' +
        '<details class="rp-detay" open><summary>İhale şartları</summary><div class="rp-not">' +
        '<p>• Kapalı teklif usulü: tutarlar zarflar açılana kadar gizlidir. Teklif geri alınamaz ve değiştirilemez.</p>' +
        '<p>• En yüksek teklif kazanır; eşitlikte önce veren öne geçer.</p>' +
        '<p>• Kaybedenlerin teminatı iade edilir. Kazanan kalan bedeli ödeyemezse teminatı idareye gelir kaydedilir ve sıradaki teklife geçilir.</p>' +
        '<p>• İhale yetkilisi (o ilin belediye başkanı; ülke genelinde Cumhurbaşkanı ve Ulaştırma Bakanı) ile yönettiği ya da ortağı olduğu şirketler katılamaz.</p>' +
        '<p>• Aynı anda en fazla ' + Number(ih.ayar && ih.ayar.en_fazla || 3) + ' pano işletmesi tutabilirsin.</p>' +
        '<p>• Sözleşme boyunca her panonun günlük fiyatını sen belirlersin; kira geliri sana gelir, her kiralamadan %' + Math.round(Number(ih.ayar && ih.ayar.vergi || 0.1) * 100) + ' ilan ve reklam vergisi idareye ödenir.</p>' +
        '<p>• Yayındaki eski reklamlar süreleri bitene kadar panoda kalır.</p></div></details>' +
        '<button class="btn rp-btn-sicak" id="rpIhGonder">Teminatı yatır ve teklifi ver</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>';
      if (k) {}
    }
    ciz();
    md.addEventListener('input', function (ev) { if (ev.target.id === 'rpIhTutar') { S.tutar = Math.max(0, Math.round(Number(ev.target.value) || 0)); var pos = ev.target.selectionStart; ciz(); var t = document.getElementById('rpIhTutar'); t.focus(); try { t.setSelectionRange(pos, pos); } catch (_) {} } });
    md.addEventListener('click', async function (ev) {
      var b = ev.target.closest('[data-k],[data-hizli],#rpIhGonder'); if (!b) return;
      if (b.dataset.k != null) { S.k = Number(b.dataset.k); ciz(); return; }
      if (b.dataset.hizli) { S.tutar = b.dataset.hizli === 'asgari' ? Number(i.asgari) : b.dataset.hizli === 'muhammen' ? Number(i.muhammen) : Math.round(S.tutar * 1.1 / 500) * 500; ciz(); return; }
      if (b.id === 'rpIhGonder') {
        if (S.tutar < Number(i.asgari)) { toast('En az ' + tl(i.asgari) + ' teklif vermelisin', true); return; }
        var k = kay[S.k]; b.disabled = true; b.textContent = 'Teklif veriliyor…';
        try {
          var r = await API.rpc('pano_ihale_teklif_ver', { p_ihale: Number(i.id), p_tur: k.tur, p_id: k.tur === 'sirket' ? Number(k.id) : null, p_tutar: S.tutar });
          modalKapat(); toast('Teklifin zarfa kondu · ' + tl(r.teminat) + ' teminat yatırıldı'); reklamPanolariEkrani();
        } catch (err) { hataGoster(err); b.disabled = false; b.textContent = 'Teminatı yatır ve teklifi ver'; }
      }
    });
  }
  function isletmeFiyatModal(id) {
    var z = RP.ihale && (RP.ihale.isletmelerim || []).find(function (x) { return Number(x.id) === Number(id); }); if (!z) return;
    var F = (z.fiyatlar || []).map(Number);
    var md = modal('<h3 style="font-size:20px;font-weight:800">Pano fiyatlarını belirle</h3><p class="rp-not" style="margin-top:4px">' + esc(z.kapsam === 'ulke' ? 'Ülke geneli dev panolar' : (z.il || '') + ' il panoları') + ' · resmî tarife ' + tl(z.devlet_gunluk) + '/gün</p><div id="rpIsIc"></div>');
    function ciz() {
      document.getElementById('rpIsIc').innerHTML = '<div class="rp-secenek" style="margin:12px 0"><button type="button" data-f="devlet">Resmî tarife</button><button type="button" data-f="0.8">Hepsi %20 ucuz</button><button type="button" data-f="1.2">Hepsi %20 pahalı</button></div>' +
        F.map(function (x, k) { return '<div class="rp-alan"><label for="rpIsF' + k + '">Pano ' + (k + 1) + ' · günlük fiyat (₺)</label><input type="number" id="rpIsF' + k + '" data-n="' + k + '" inputmode="numeric" min="100" max="5000000" step="50" value="' + Math.round(x) + '"></div>'; }).join('') +
        '<p class="rp-not">Fiyatlar yeni kiralamalarda geçerli olur. Kira gelirinin %' + Math.round(Number(RP.ihale.ayar && RP.ihale.ayar.vergi || 0.1) * 100) + '’i ilan ve reklam vergisi olarak idareye gider. Uzun süre indirimi ve seçim zammı işletmeci panolarında uygulanmaz.</p>' +
        '<button class="btn rp-btn-sicak" id="rpIsKaydet">Fiyatları kaydet</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>';
    }
    ciz();
    md.addEventListener('input', function (ev) { var n = ev.target.dataset && ev.target.dataset.n; if (n != null) F[Number(n)] = Number(ev.target.value) || 0; });
    md.addEventListener('click', async function (ev) {
      var b = ev.target.closest('[data-f],#rpIsKaydet'); if (!b) return;
      if (b.dataset.f) { F = F.map(function (x) { return b.dataset.f === 'devlet' ? Math.round(Number(z.devlet_gunluk) / 50) * 50 : Math.max(100, Math.round(x * Number(b.dataset.f) / 50) * 50); }); ciz(); return; }
      b.disabled = true;
      try { await API.rpc('pano_isletme_fiyat', { p_isletme: Number(z.id), p_fiyatlar: F.map(function (x) { return Math.round(x); }) }); modalKapat(); toast('Pano fiyatları güncellendi'); RP.vitrinT = 0; reklamPanolariEkrani(); }
      catch (err) { hataGoster(err); b.disabled = false; }
    });
  }
  function durumYaz(y) {
    if (y.durum === 'aktif') return new Date(y.bas).getTime() > simdiMs() ? '<span class="rp-durum sirada">SIRADA · ' + tarihKisa(y.bas) + '</span>' : '<span class="rp-durum yayinda">YAYINDA · ' + kalanYaz(y.bit) + '</span>';
    return y.durum === 'kaldirildi' ? '<span class="rp-durum kaldirildi">KALDIRILDI</span>' : '<span class="rp-durum bitti">BİTTİ</span>';
  }
  function yayinSatir(y, m) {
    var afisVar = (m.afisler || []).some(function (f) { return Number(f.id) === Number(y.afis_id); });
    return '<div class="rp-kart" style="margin-bottom:10px"><div class="rp-yayin"><div data-rp="yayin" data-id="' + Number(y.id) + '" role="button" tabindex="0">' + afisSvg(y.tasarim) + '</div><div>' +
      durumYaz(y) + '<h4 style="margin-top:6px">' + esc(y.ad || 'Afiş') + '</h4><p>' + esc(y.kapsam === 'ulke' ? 'Ülke geneli' : y.il) + ' · ' + y.gun + ' gün · ' + tl(y.tutar) + (Number(y.iade) > 0 ? ' · ' + tl(y.iade) + ' iade' : '') + '</p>' +
      (y.kaldirma_neden && y.durum === 'kaldirildi' ? '<p style="color:var(--al2)">' + esc(y.kaldirma_neden) + '</p>' : '') + '</div></div>' +
      '<div class="rp-istat"><div><b>' + sayiYaz(y.gosterim) + '</b><small>kişi gördü</small></div><div><b>' + sayiYaz(y.begeni) + '</b><small>beğeni</small></div><div><b>' + (y.gosterim ? tl(y.tutar / Math.max(1, y.gosterim)).replace(' ₺', '') : '—') + '</b><small>₺ / kişi</small></div></div>' +
      '<div class="rp-mini" style="margin:10px 0 0">' + (y.durum === 'aktif' ? '<button type="button" class="tehlike" data-rp="kaldir" data-id="' + Number(y.id) + '">Yayından kaldır</button>' : '') +
      (afisVar ? '<button type="button" data-rp="tekrar" data-afis="' + Number(y.afis_id) + '">Yeniden yayınla</button>' : '') + '</div></div>';
  }
  function haritaSvg(m, benIl) {
    var yol = (VERI.harita && VERI.harita.il) || {}, bilgi = {};
    (m.iller || []).forEach(function (i) { bilgi[i.id] = i; });
    var s = '<svg class="rp-harita" viewBox="0 0 ' + (VERI.harita.w || 1000) + ' ' + (VERI.harita.h || 429) + '" role="img" aria-label="Türkiye reklam panosu haritası">';
    Object.keys(yol).forEach(function (id) {
      var b = bilgi[id], f = b && b.fiyat, sinif = !f || !f.dolu ? 'bos' : f.dolu >= f.slot ? 'dolu' : 'kismi';
      if (Number(id) === Number(benIl)) sinif += ' ben';
      s += '<path d="' + yol[id].d + '" class="' + sinif + '" data-rp="il" data-id="' + Number(id) + '"><title>' + esc(b ? b.ad : '') + '</title></path>';
    });
    return s + '</svg>';
  }
  function haritaBilgi(m, id) {
    var b = (m.iller || []).find(function (i) { return Number(i.id) === Number(id); }); if (!b) return;
    var f = b.fiyat || {}, bos = b.bos && b.bos.bos ? new Date(b.bos.bos).getTime() : 0, hemen = bos <= simdiMs() + 60000;
    document.querySelectorAll('.rp-harita path.sec').forEach(function (p) { p.classList.remove('sec'); });
    var p = document.querySelector('.rp-harita path[data-id="' + Number(id) + '"]'); if (p) p.classList.add('sec');
    var el = document.getElementById('rpHaritaBilgi'); if (!el) return;
    el.innerHTML = '<div class="rp-teklif" style="margin-bottom:0"><div class="rp-teklif-satir"><span>İl</span><b>' + esc(b.ad) + '</b></div>' +
      '<div class="rp-teklif-satir"><span>Panolar</span><b>' + (f.dolu || 0) + ' / ' + (f.slot || 0) + ' dolu</b></div>' +
      '<div class="rp-teklif-satir"><span>İşleten</span><b>' + (f.isletme ? esc(f.isletme.ad) + ' (ihaleyle)' : esc(b.ad) + ' Belediyesi') + '</b></div>' +
      '<div class="rp-teklif-satir"><span>Günlük fiyat</span><b>' + (f.isletme ? tl(f.gunluk) + '’den' : tl(f.gunluk)) + (Number(f.belediye_carpan) !== 1 ? ' · belediye tarifesi ' + String(f.belediye_carpan).replace('.', ',') + ' kat' : '') + '</b></div>' +
      '<div class="rp-teklif-satir"><span>Yayın başlangıcı</span><b>' + (hemen ? 'Hemen' : tarihKisa(b.bos.bos)) + '</b></div>' +
      '<div class="rp-eylem-sira"><button type="button" class="btn" data-rp="kirala" data-kapsam="il" data-il="' + Number(id) + '">Bu ilde kirala</button><button type="button" class="btn ikinci" data-rp="ilgor" data-il="' + Number(id) + '">Panolarını gör</button></div></div>';
  }
  function belediyeKart(b, m) {
    var son = b.son_degisim ? new Date(b.son_degisim).getTime() : 0, kilit = son && simdiMs() - son < 12 * 3600e3;
    return '<div class="rp-bolum"><h3>Belediye reklam tarifesi</h3><small>' + esc(b.il) + ' Belediye Başkanı</small></div><div class="rp-kart">' +
      '<div class="rp-istat" style="margin-top:0"><div><b>' + String(Number(b.carpan).toFixed(2)).replace('.', ',') + '</b><small>tarife katı</small></div><div><b>' + tl(b.gelir_7).replace(' ₺', '') + '</b><small>₺ son 7 gün</small></div><div><b>' + tl(b.gelir_toplam).replace(' ₺', '') + '</b><small>₺ toplam</small></div></div>' +
      '<div class="rp-alan" style="margin-top:14px"><label for="rpTarife">Yeni tarife <span class="rp-deger" id="rpTarifeDeger">' + String(Number(b.carpan).toFixed(2)).replace('.', ',') + ' kat</span></label><input type="range" id="rpTarife" min="0.5" max="2" step="0.05" value="' + Number(b.carpan) + '"' + (kilit ? ' disabled' : '') + '></div>' +
      '<p class="rp-not" id="rpTarifeFiyat">Düşük tarife daha çok reklam çeker, yüksek tarife belediye kasasına daha çok gelir getirir.</p>' +
      '<button type="button" class="btn" data-rp="tarife"' + (kilit ? ' disabled' : '') + '>' + (kilit ? 'Tarife 12 saatte bir değişebilir' : 'Tarifeyi kaydet') + '</button></div>';
  }
  function sikayetKart(liste) {
    return '<div class="rp-bolum"><h3>Şikâyet edilen reklamlar</h3><small>Moderatör</small></div>' + liste.map(function (s) {
      var y = s.yayin || {};
      return '<div class="rp-kart" style="margin-bottom:10px">' + afisSvg(y.tasarim, { kunye: y.sahip_ad }) + '<p class="rp-not"><b>' + esc(y.sahip_ad) + '</b> · ' + esc(y.kapsam === 'ulke' ? 'Ülke geneli' : y.il) + ' · ' + s.sayi + ' şikâyet</p>' +
        (s.nedenler || []).slice(0, 4).map(function (n) { return '<p class="rp-not">“' + esc(n) + '”</p>'; }).join('') +
        '<div class="rp-mini" style="margin-top:10px"><button type="button" class="tehlike" data-rp="modkaldir" data-id="' + Number(y.id) + '" data-iade="1">Kaldır, kalan süreyi iade et</button><button type="button" class="tehlike" data-rp="modkaldir" data-id="' + Number(y.id) + '" data-iade="0">Kaldır, iade yok</button><button type="button" data-rp="modret" data-id="' + Number(y.id) + '">Şikâyeti reddet</button></div></div>';
    }).join('');
  }
  async function ekranTik(ev, m, v) {
    var b = ev.target.closest('[data-rp]'); if (!b) return;
    var a = b.dataset.rp, id = Number(b.dataset.id);
    if (a === 'studyo') return ekranAc(function () { return afisStudyosu(null); });
    if (a === 'afis') { var f = (m.afisler || []).find(function (x) { return Number(x.id) === id; }); if (f) return afisMenu(f, m); return; }
    if (a === 'yayin') return yayinModal(id);
    if (a === 'kirala') {
      var kap = b.dataset.kapsam || 'il', il = Number(b.dataset.il) || Number(v.il_id);
      return kiralaModal({ kapsam: kap, il: il, slot: Number(b.dataset.slot) || null });
    }
    if (a === 'ihale') return ihaleTeklifModal(id);
    if (a === 'isletme') return isletmeFiyatModal(id);
    if (a === 'tekrar') { var af = (m.afisler || []).find(function (x) { return Number(x.id) === Number(b.dataset.afis); }); return kiralaModal({ afis: af, kapsam: 'il', il: Number(v.il_id) }); }
    if (a === 'il') return haritaBilgi(m, id);
    if (a === 'ilgor') { EKR.il = Number(b.dataset.il); return reklamPanolariEkrani(); }
    if (a === 'ilsec') return ilSecModal(m, function (il) { EKR.il = il; reklamPanolariEkrani(); });
    if (a === 'begen') {
      b.disabled = true;
      try { var r = await API.rpc('pano_begen', { p_yayin: id }); b.innerHTML = (r.begendim ? '♥' : '♡') + ' ' + sayiYaz(r.begeni); b.style.background = r.begendim ? 'rgba(240,69,75,.25)' : 'rgba(255,255,255,.08)'; RP.vitrinT = 0; } catch (err) { hataGoster(err); }
      b.disabled = false; return;
    }
    if (a === 'kaldir') {
      if (!(await onayla('Reklam yayından kalksın mı?', 'Kalan süre için iade yapılmaz. Bu işlem geri alınamaz.', 'Yayından kaldır', true))) return;
      try { await API.rpc('pano_kaldir', { p_yayin: id, p_neden: '', p_iade: false }); toast('Reklam yayından kaldırıldı'); RP.vitrinT = 0; reklamPanolariEkrani(); } catch (err) { hataGoster(err); }
      return;
    }
    if (a === 'modkaldir') return modKaldirModal(id, b.dataset.iade === '1');
    if (a === 'modret') { try { await API.rpc('pano_sikayet_kapat', { p_yayin: id }); toast('Şikâyet kapatıldı'); reklamPanolariEkrani(); } catch (err) { hataGoster(err); } return; }
    if (a === 'tarife') {
      var t = document.getElementById('rpTarife'); b.disabled = true;
      try { await API.rpc('pano_il_tarife', { p_il: Number(m.belediye.il_id), p_carpan: Number(t.value) }); toast('Reklam tarifesi güncellendi'); reklamPanolariEkrani(); } catch (err) { hataGoster(err); b.disabled = false; }
    }
  }
  function ilSecModal(m, sonra) {
    var liste = (m.iller || []).slice().sort(function (a, b) { return a.ad.localeCompare(b.ad, 'tr'); });
    var md = modal('<h3 style="font-size:19px;font-weight:800">İl seç</h3><div class="rp-alan" style="margin-top:10px"><label for="rpIlAra">Ara</label><input type="text" id="rpIlAra" placeholder="İl adı yaz" autocomplete="off"></div><div id="rpIlListe" style="max-height:52vh;overflow-y:auto"></div>');
    var ciz = function (q) {
      q = String(q || '').toLocaleLowerCase('tr-TR');
      document.getElementById('rpIlListe').innerHTML = liste.filter(function (i) { return !q || i.ad.toLocaleLowerCase('tr-TR').indexOf(q) >= 0; }).map(function (i) {
        return '<button type="button" class="rp-radyo" data-il="' + Number(i.id) + '"><b>' + esc(i.ad) + '</b><small>' + (i.fiyat.dolu || 0) + '/' + i.fiyat.slot + ' pano dolu · günlük ' + tl(i.fiyat.gunluk) + '</small></button>';
      }).join('');
    };
    ciz('');
    document.getElementById('rpIlAra').addEventListener('input', function (ev) { ciz(ev.target.value); });
    md.addEventListener('click', function (ev) { var b = ev.target.closest('[data-il]'); if (b) { modalKapat(); sonra(Number(b.dataset.il)); } });
  }
  function afisMenu(f, m) {
    var md = modal('<h3 style="font-size:19px;font-weight:800">' + esc(f.ad) + '</h3><div style="margin:10px 0">' + panoHTML(afisSvg(f.tasarim), { kucuk: true }) + '</div>' +
      '<button class="btn rp-btn-sicak" id="rpAfisKirala">Panoya as</button><button class="btn ikinci" id="rpAfisDuzenle">Düzenle</button><button class="btn ikinci" id="rpAfisKopya">Kopyasını oluştur</button><button class="btn tehlike" id="rpAfisSil">Sil</button>');
    md.querySelector('#rpAfisKirala').onclick = function () { modalKapat(); kiralaModal({ afis: f, kapsam: 'il', il: EKR.il }); };
    md.querySelector('#rpAfisDuzenle').onclick = function () { modalKapat(); ekranAc(function () { return afisStudyosu(f); }); };
    md.querySelector('#rpAfisKopya').onclick = function () { modalKapat(); ekranAc(function () { return afisStudyosu({ ad: f.ad + ' (kopya)', sahip_tur: f.sahip_tur, sahip_id: f.sahip_id, tasarim: kopya(f.tasarim) }); }); };
    md.querySelector('#rpAfisSil').onclick = async function () {
      modalKapat();
      if (!(await onayla('Afiş silinsin mi?', 'Yayındaki reklamlar süreleri bitene kadar panoda kalır.', 'Sil', true))) return;
      try { await API.rpc('afis_sil', { p_id: Number(f.id) }); toast('Afiş silindi'); reklamPanolariEkrani(); } catch (err) { hataGoster(err); }
    };
  }

  /* Yayın ayrıntısı */
  async function yayinModal(id) {
    stilKur();
    var y = null, kaynak = (RP.vitrin ? (RP.vitrin.ulke || []).concat(RP.vitrin.yerel || []) : []).concat(RP.merkez ? RP.merkez.yayinlarim || [] : []);
    y = kaynak.find(function (x) { return Number(x.id) === Number(id); });
    if (!y) { toast('Reklam bulunamadı', true); return; }
    var p = profil() || {}, mod = !!(RP.merkez && RP.merkez.moderator);
    var benim = RP.merkez && (RP.merkez.yayinlarim || []).some(function (x) { return Number(x.id) === Number(id); });
    var md = modal('<h3 style="font-size:19px;font-weight:800">' + esc(y.ad || 'Reklam') + '</h3>' +
      '<div class="' + (zamanDilimi() === 'gece' ? 'rp-gece' : '') + '" style="margin:12px 0 4px">' + panoHTML(afisSvg(y.tasarim, { kunye: y.sahip_ad, etiket: y.ad })) + '</div>' +
      '<div class="rp-teklif"><div class="rp-teklif-satir"><span>Ödeyen</span><b>' + esc(y.sahip_ad) + '</b></div><div class="rp-teklif-satir"><span>Yer</span><b>' + esc(y.kapsam === 'ulke' ? 'Ülke geneli dev pano' : y.il + ' panosu') + '</b></div>' +
      '<div class="rp-teklif-satir"><span>Kalan süre</span><b>' + kalanYaz(y.bit) + '</b></div><div class="rp-teklif-satir"><span>Erişim</span><b>' + sayiYaz(y.gosterim) + ' kişi</b></div></div>' +
      (y.durum === 'aktif' ? '<button class="btn ' + (y.begendim ? 'ikinci' : '') + '" id="rpBegen">' + (y.begendim ? '♥ Beğendin' : '♡ Beğen') + ' · ' + sayiYaz(y.begeni) + '</button>' : '') +
      (y.durum === 'aktif' && !benim ? '<details style="margin-top:10px"><summary style="min-height:44px;display:flex;align-items:center;font-weight:700;color:var(--mut)">Bu reklamı şikâyet et</summary><div class="rp-alan" style="margin-top:8px"><label for="rpSikNeden">Gerekçe</label><textarea id="rpSikNeden" rows="3" maxlength="300" placeholder="Hakaret, küfür, yanıltıcı içerik…">' + '</textarea></div><button class="btn ikinci" id="rpSikGonder">Şikâyeti gönder</button></details>' : '') +
      (mod && !benim && y.durum === 'aktif' ? '<button class="btn tehlike" id="rpModKaldir">Moderatör: yayından kaldır</button>' : '') +
      '<button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
    var bg = md.querySelector('#rpBegen');
    if (bg) bg.onclick = async function () {
      bg.disabled = true;
      try { var r = await API.rpc('pano_begen', { p_yayin: Number(id) }); y.begendim = r.begendim; y.begeni = r.begeni; bg.textContent = (r.begendim ? '♥ Beğendin' : '♡ Beğen') + ' · ' + sayiYaz(r.begeni); bg.classList.toggle('ikinci', !!r.begendim); RP.vitrinT = 0; } catch (err) { hataGoster(err); }
      bg.disabled = false;
    };
    var sg = md.querySelector('#rpSikGonder');
    if (sg) sg.onclick = async function () {
      var n = md.querySelector('#rpSikNeden').value.trim();
      if (n.length < 10) { toast('Gerekçe en az 10 karakter olmalı', true); return; }
      sg.disabled = true;
      try { await API.rpc('pano_sikayet', { p_yayin: Number(id), p_neden: n }); toast('Şikâyetin moderatörlere iletildi'); modalKapat(); } catch (err) { hataGoster(err); sg.disabled = false; }
    };
    var mk = md.querySelector('#rpModKaldir');
    if (mk) mk.onclick = function () { modalKapat(); modKaldirModal(Number(id), true); };
  }
  function modKaldirModal(id, iade) {
    var md = modal('<h3 style="font-size:19px;font-weight:800">Reklamı yayından kaldır</h3><div class="rp-alan" style="margin-top:10px"><label for="rpModNeden">Gerekçe (reklam sahibine bildirilir)</label><textarea id="rpModNeden" rows="3" maxlength="300" placeholder="Örneğin: hakaret içeriyor"></textarea></div>' +
      '<button type="button" class="rp-radyo' + (iade ? ' aktif' : '') + '" data-iade="1"><b>Kalan süreyi iade et</b><small>Para ödeyen kasaya geri döner</small></button><button type="button" class="rp-radyo' + (iade ? '' : ' aktif') + '" data-iade="0"><b>İade yok</b><small>Ağır kural ihlallerinde</small></button>' +
      '<button class="btn tehlike" id="rpModOnay">Yayından kaldır</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    md.addEventListener('click', function (ev) { var r = ev.target.closest('[data-iade]'); if (!r) return; iade = r.dataset.iade === '1'; md.querySelectorAll('[data-iade]').forEach(function (x) { x.classList.toggle('aktif', x === r); }); });
    md.querySelector('#rpModOnay').onclick = async function () {
      var n = md.querySelector('#rpModNeden').value.trim();
      if (n.length < 10) { toast('Gerekçe en az 10 karakter olmalı', true); return; }
      try { var r = await API.rpc('pano_kaldir', { p_yayin: id, p_neden: n, p_iade: iade }); modalKapat(); toast('Reklam kaldırıldı' + (r.iade > 0 ? ' · ' + tl(r.iade) + ' iade edildi' : '')); RP.vitrinT = 0; reklamPanolariEkrani(); } catch (err) { hataGoster(err); }
    };
  }

  /* ---------------------------------------------------------------
     8) KİRALAMA
     --------------------------------------------------------------- */
  async function kiralaModal(o) {
    stilKur(); o = o || {};
    var m = RP.merkez;
    if (!m) { try { m = await merkezYukle(); } catch (err) { hataGoster(err); return; } }
    var afisler = m.afisler || [];
    if (!afisler.length && !o.afis) {
      if (await onayla('Önce bir afiş tasarla', 'Panoya asmak için hazır bir afişin olmalı. Afiş Stüdyosu’nda 12 hazır şablonla bir dakikada hazırlayabilirsin.', 'Afiş Stüdyosu’nu aç')) ekranAc(function () { return afisStudyosu(null); });
      return;
    }
    var S = { afis: o.afis || afisler[0], kapsam: o.kapsam === 'ulke' ? 'ulke' : 'il', il: Number(o.il) || (profil() && profil().il_id) || 34, gun: 3, odeme: 'kasa', teklif: null, istek: 0, slot: Number(o.slot) || null };
    var md = modal('<h3 style="font-size:20px;font-weight:800">Panoyu kirala</h3><div id="rpKiraIc"></div>');
    var kaynakBul = function () { return (m.kaynaklar || []).find(function (k) { return k.tur === S.afis.sahip_tur && (S.afis.sahip_tur === 'oyuncu' || Number(k.id) === Number(S.afis.sahip_id)); }); };
    var ben = (m.kaynaklar || [])[0] || { kasa: 0 };
    function ciz() {
      var k = kaynakBul(), kasaOk = S.afis.sahip_tur !== 'oyuncu' && k && k.odeme;
      if (!kasaOk) S.odeme = 'oyuncu';
      var gunler = [1, 3, 7, 14, 30].filter(function (g) { return g <= m.ayar.en_uzun_gun; });
      var iller = (m.iller || []).slice().sort(function (a, b) { return a.ad.localeCompare(b.ad, 'tr'); });
      var h = '<div style="margin:10px 0">' + panoHTML(afisSvg(S.afis.tasarim, { kunye: k ? k.ad : '' }), { kucuk: true }) + '</div>' +
        (afisler.length > 1 ? '<div class="rp-alan"><label for="rpKiraAfis">Afiş</label><select id="rpKiraAfis">' + afisler.map(function (f) { return '<option value="' + Number(f.id) + '"' + (Number(f.id) === Number(S.afis.id) ? ' selected' : '') + '>' + esc(f.ad) + '</option>'; }).join('') + '</select></div>' : '') +
        '<div class="rp-alan"><label>Nerede yayınlansın?</label><div class="rp-secenek"><button type="button" data-kap="il" class="' + (S.kapsam === 'il' ? 'aktif' : '') + '">📍 İl panosu</button><button type="button" data-kap="ulke" class="' + (S.kapsam === 'ulke' ? 'aktif' : '') + '">🇹🇷 Ülke geneli</button></div></div>' +
        (S.kapsam === 'il' ? '<div class="rp-alan"><label for="rpKiraIl">İl</label><select id="rpKiraIl">' + iller.map(function (i) { return '<option value="' + Number(i.id) + '"' + (Number(i.id) === Number(S.il) ? ' selected' : '') + '>' + esc(i.ad) + ' · ' + tl(i.fiyat.gunluk) + '/gün · ' + (i.fiyat.slot - (i.fiyat.dolu || 0)) + ' boş</option>'; }).join('') + '</select></div>' : '') +
        '<div id="rpSlotlar"></div>' +
        '<div class="rp-alan"><label>Süre</label><div class="rp-secenek">' + gunler.map(function (g) { return '<button type="button" data-gun="' + g + '" class="' + (S.gun === g ? 'aktif' : '') + '">' + g + ' gün</button>'; }).join('') + '</div></div>' +
        '<div class="rp-alan"><label>Ödeme</label>' +
        (kasaOk ? '<button type="button" class="rp-radyo' + (S.odeme === 'kasa' ? ' aktif' : '') + '" data-ode="kasa"><b>' + esc(k.ad) + ' kasası</b><small>Bakiye ' + tl(k.kasa) + '</small></button>' : '') +
        '<button type="button" class="rp-radyo' + (S.odeme === 'oyuncu' ? ' aktif' : '') + '" data-ode="oyuncu"><b>Kendi cüzdanım</b><small>Bakiye ' + tl(ben.kasa) + '</small></button>' +
        (S.afis.sahip_tur !== 'oyuncu' && k && !k.odeme ? '<p class="rp-not">' + esc(k.ad) + ' kasasından ödemeyi yalnız yetkili (genel başkan, başkan, şirket yöneticisi) yapabilir.</p>' : '') + '</div>' +
        '<div id="rpTeklif" class="rp-teklif"><div class="rp-not">Fiyat hesaplanıyor…</div></div>' +
        '<button class="btn rp-btn-sicak" id="rpKiraOde" disabled>Öde ve yayınla</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>';
      document.getElementById('rpKiraIc').innerHTML = h;
      teklifAl();
    }
    async function teklifAl() {
      var no = ++S.istek, el = document.getElementById('rpTeklif'), btn = document.getElementById('rpKiraOde');
      if (btn) btn.disabled = true;
      try {
        var t = await API.rpc('pano_teklif_v2', { p_kapsam: S.kapsam, p_il: S.kapsam === 'il' ? S.il : null, p_gun: S.gun, p_slot: S.slot });
        if (no !== S.istek || !document.getElementById('rpTeklif')) return;
        S.teklif = t;
        var sl = document.getElementById('rpSlotlar');
        if (sl) sl.innerHTML = (t.slotlar || []).length > 1 ? '<div class="rp-alan"><label>Pano</label><div class="rp-pano-sec">' + t.slotlar.map(function (x) {
          var hemen = new Date(x.bos).getTime() <= simdiMs() + 60000;
          return '<button type="button" data-slot="' + Number(x.slot) + '" class="' + (Number(x.slot) === Number(t.slot) ? 'aktif' : '') + '"><b>Pano ' + Number(x.slot) + '</b><span>' + tl(x.fiyat) + '/gün</span><small>' + (hemen ? 'boş' : tarihKisa(x.bos) + '’te boşalır') + '</small></button>';
        }).join('') + '</div></div>' : '';
        var siyasi = S.afis.sahip_tur === 'parti' || S.afis.sahip_tur === 'oyuncu';
        el.innerHTML = (t.isletme ? '<div class="rp-teklif-satir"><span>İşletmeci</span><b>' + esc(t.isletme.ad) + '</b></div>' : '') +
          '<div class="rp-teklif-satir"><span>Günlük fiyat · Pano ' + Number(t.slot) + '</span><b>' + tl(t.gunluk) + '</b></div>' +
          (t.indirim > 0 ? '<div class="rp-teklif-satir"><span>Uzun süre indirimi</span><b style="color:#5BE0A7">%' + Math.round(t.indirim * 100) + '</b></div>' : '') +
          '<div class="rp-teklif-satir"><span>Başlangıç</span><b>' + (t.hemen ? 'Hemen' : tarihKisa(t.bas) + ' (sırada)') + '</b></div>' +
          '<div class="rp-teklif-satir"><span>Bitiş</span><b>' + tarihKisa(t.bit) + '</b></div>' +
          '<div class="rp-teklif-satir"><span>Gelir</span><b>' + esc(t.gelir_yeri) + '</b></div>' +
          '<div class="rp-teklif-toplam"><span>Toplam</span><b>' + tl(t.toplam) + '</b></div>' +
          (t.fiyat && t.fiyat.sezon ? '<p class="rp-not uyari">🗳️ Seçim sezonu: fiyatlar ' + String(t.fiyat.sezon_carpan).replace('.', ',') + ' kat.</p>' : '') +
          (t.fiyat && t.fiyat.dolu > 0 ? '<p class="rp-not">Panoların ' + t.fiyat.dolu + '/' + t.fiyat.slot + '’i dolu; doluluk fiyatı artırır.</p>' : '') +
          (siyasi && t.yasak_uyari ? '<p class="rp-not">Oy verme saatlerinde siyasi reklamlar gösterilmez, süre işlemeye devam eder.</p>' : '') +
          (t.neden ? '<p class="rp-not uyari">' + esc(t.neden) + '</p>' : '');
        if (btn) { btn.disabled = !!t.sira_dolu; btn.textContent = 'Öde ve yayınla · ' + tl(t.toplam); }
      } catch (err) { if (no === S.istek && el) el.innerHTML = '<p class="rp-not uyari">' + esc(typeof hataCevir === 'function' ? hataCevir(err.message) : err.message) + '</p>'; }
    }
    md.addEventListener('change', function (ev) {
      if (ev.target.id === 'rpKiraIl') { S.il = Number(ev.target.value); S.slot = null; teklifAl(); }
      if (ev.target.id === 'rpKiraAfis') { S.afis = afisler.find(function (f) { return Number(f.id) === Number(ev.target.value); }) || S.afis; ciz(); }
    });
    md.addEventListener('click', async function (ev) {
      var b = ev.target.closest('[data-kap],[data-gun],[data-ode],[data-slot],#rpKiraOde'); if (!b) return;
      if (b.dataset.kap) { S.kapsam = b.dataset.kap; S.slot = null; ciz(); return; }
      if (b.dataset.slot) { S.slot = Number(b.dataset.slot); teklifAl(); return; }
      if (b.dataset.gun) { S.gun = Number(b.dataset.gun); md.querySelectorAll('[data-gun]').forEach(function (x) { x.classList.toggle('aktif', x === b); }); teklifAl(); return; }
      if (b.dataset.ode) { S.odeme = b.dataset.ode; md.querySelectorAll('[data-ode]').forEach(function (x) { x.classList.toggle('aktif', x === b); }); return; }
      if (b.id === 'rpKiraOde') {
        if (!S.teklif) return;
        b.disabled = true; b.textContent = 'Ödeme yapılıyor…';
        try {
          var r = await API.rpc('pano_kirala_v2', { p_afis: Number(S.afis.id), p_kapsam: S.kapsam, p_il: S.kapsam === 'il' ? S.il : null, p_gun: S.gun, p_odeme_tur: S.odeme === 'oyuncu' ? 'oyuncu' : 'kasa', p_beklenen: Number(S.teklif.toplam), p_slot: Number(S.teklif.slot) || null });
          modalKapat(); RP.vitrinT = 0;
          kutlama(S.afis, r, (kaynakBul() || {}).ad);
          try { if (typeof durumYenile === 'function') durumYenile(); } catch (_) {}
        } catch (err) { hataGoster(err); b.disabled = false; b.textContent = 'Öde ve yayınla'; teklifAl(); }
      }
    });
    ciz();
  }
  function kutlama(afis, r, sahip) {
    var dilim = zamanDilimi(), yer = r.kapsam === 'ulke' ? 'bütün Türkiye’de' : (r.il || '') + '’de';
    var el = document.createElement('div'); el.className = 'rp-kutlama rp-gece'; el.setAttribute('role', 'dialog'); el.setAttribute('aria-label', 'Reklam yayında');
    var par = ''; for (var i = 0; i < 14; i++) par += '<i class="rp-isik-par" style="left:' + (8 + i * 6.5) + '%;bottom:' + (20 + (i * 37) % 30) + '%;animation-delay:' + (i * 0.17).toFixed(2) + 's"></i>';
    el.innerHTML = par + '<div class="rp-kutlama-ic">' + panoHTML(afisSvg(afis.tasarim, { kunye: sahip || '' })) +
      '<h2>' + (r.hemen ? 'Afişin ' + esc(yer) + ' yayında!' : 'Afişin sıraya girdi') + '</h2>' +
      '<p>' + (r.hemen ? 'Panonun ışıkları yandı. ' + tarihKisa(r.bit) + '’e kadar herkes görecek.' : tarihKisa(r.bas) + '’te ilk boşalan panoda yayına girecek; sana bildirim gelecek.') + ' Ödenen: ' + tl(r.tutar) + '.</p>' +
      '<button class="btn rp-btn-sicak" id="rpKutlamaTamam" style="margin-top:18px">Harika</button></div>';
    document.body.appendChild(el);
    var kapat = function () { el.remove(); if (D.yigin && D.yigin[D.yigin.length - 1] === reklamPanolariEkrani) reklamPanolariEkrani(); else ekranAc(reklamPanolariEkrani); };
    el.querySelector('#rpKutlamaTamam').onclick = kapat;
    void dilim;
  }

  /* ---------------------------------------------------------------
     9) AFİŞ STÜDYOSU
     --------------------------------------------------------------- */
  var ST = null;
  async function afisStudyosu(f) {
    stilKur();
    if (!RP.merkez) { yukleniyor('Afiş Stüdyosu'); try { await merkezYukle(); } catch (err) { iskelet('Afiş Stüdyosu', hazirlikMi(err) ? hazirlikHTML : '<div class="kart">' + esc(typeof hataCevir === 'function' ? hataCevir(err.message) : err.message) + '</div>', { geri: true }); return; } }
    // Aynı ekran yeniden çizilirse (kiralama penceresinden ya da başka ekrandan geri dönüş) düzenleme korunur;
    // yeni bir "Afiş tasarla" dokunuşu her zaman yeni bir çalışma açar.
    var yiginUst = (typeof D !== 'undefined' && D && D.yigin) ? D.yigin[D.yigin.length - 1] : null;
    if (!(ST && yiginUst && ST.yigin === yiginUst)) {
      var kay = RP.merkez.kaynaklar || [], ilk = kay[0] || { tur: 'oyuncu', id: null };
      var sahip = f && f.sahip_tur ? (kay.find(function (k) { return k.tur === f.sahip_tur && (f.sahip_tur === 'oyuncu' || Number(k.id) === Number(f.sahip_id)); }) || ilk) : ilk;
      try { if (typeof kimlikYukle === 'function' && profil()) await kimlikYukle([profil().kad]); } catch (_) {}
      var c = baglam(sahip);
      ST = { yigin: yiginUst, id: f && f.id ? Number(f.id) : null, ad: f && f.ad ? f.ad : '', sahip: sahip, ctx: c,
        t: f && f.tasarim ? kopya(f.tasarim) : SABLON[0].f(c), sec: -1, geri: [], ileri: [], sekme: f ? 'yazi' : 'sablon', kirli: false };
    }
    var h = '<div class="rp-studyo"><div class="rp-tuval-kap"><div class="rp-tuval"><svg id="rpTuval" viewBox="0 0 ' + W + ' ' + H + '" xmlns="http://www.w3.org/2000/svg"></svg></div><div class="rp-ipucu">Öğeye dokun · sürükleyerek taşı · alttan düzenle</div></div>' +
      '<div class="rp-arac"><button type="button" class="btn ikinci" data-st="geri" aria-label="Geri al">↶</button><button type="button" class="btn ikinci" data-st="ileri" aria-label="Yinele">↷</button><span class="rp-bosluk"></span><button type="button" class="btn ikinci" data-st="sahip" id="rpSahipBtn"></button></div>' +
      '<div id="rpSecili"></div><nav class="rp-sekmeler" id="rpSekmeler"></nav><div id="rpPanel"></div>' +
      '<div class="rp-alt-bar"><button type="button" class="btn ikinci" data-st="kaydet">Kaydet</button><button type="button" class="btn rp-btn-sicak" data-st="as">Kaydet ve panoya as</button></div></div>';
    iskelet('Afiş Stüdyosu', h, { geri: true, sekmesiz: true });
    var kok = document.getElementById('icerik');
    kok.onclick = stTik; kok.oninput = stGirdi; kok.onchange = stDegisim;
    tuvalBagla();
    stHepsi();
  }
  function stHepsi() { stTuval(); stSecili(); stSekmeler(); stPanel(); stAracDurum(); }
  function stAracDurum() {
    var s = document.getElementById('rpSahipBtn');
    if (s) s.textContent = '👤 ' + (ST.sahip.tur === 'oyuncu' ? 'Kişisel' : ST.sahip.ad).slice(0, 22) + ' ▾';
    document.querySelectorAll('[data-st="geri"]').forEach(function (b) { b.disabled = !ST.geri.length; });
    document.querySelectorAll('[data-st="ileri"]').forEach(function (b) { b.disabled = !ST.ileri.length; });
  }
  function kayitAl() { ST.geri.push(JSON.stringify(ST.t)); if (ST.geri.length > 50) ST.geri.shift(); ST.ileri = []; ST.kirli = true; stAracDurum(); }
  var cizimBekliyor = false;
  function stTuvalSonra() { if (cizimBekliyor) return; cizimBekliyor = true; requestAnimationFrame(function () { cizimBekliyor = false; stTuval(); }); }
  function stTuval() {
    var svg = document.getElementById('rpTuval'); if (!svg) return;
    svg.innerHTML = afisIc(ST.t, { ornekKunye: ST.sahip.ad });
    // Dokunma alanları ve seçim çerçevesi
    svg.querySelectorAll('g[data-i]').forEach(function (g) {
      try {
        var b = g.getBBox(); if (!b.width && !b.height) return;
        var r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        r.setAttribute('x', b.x - 8); r.setAttribute('y', b.y - 8); r.setAttribute('width', b.width + 16); r.setAttribute('height', b.height + 16); r.setAttribute('fill', 'transparent');
        g.insertBefore(r, g.firstChild);
        if (Number(g.dataset.i) === ST.sec) {
          var k = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
          k.setAttribute('class', 'rp-sec-kutu'); k.setAttribute('x', b.x - 8); k.setAttribute('y', b.y - 8); k.setAttribute('width', b.width + 16); k.setAttribute('height', b.height + 16);
          k.setAttribute('fill', 'none'); k.setAttribute('stroke', '#FFFFFF'); k.setAttribute('stroke-width', '3'); k.setAttribute('stroke-dasharray', '10 7'); k.setAttribute('rx', '6');
          g.appendChild(k);
          var k2 = k.cloneNode(); k2.setAttribute('stroke', '#7B61FF'); k2.setAttribute('stroke-dashoffset', '10'); g.appendChild(k2);
        }
      } catch (_) {}
    });
    if (ST.kilavuz) {
      var kl = ST.kilavuz;
      if (kl.x) svg.insertAdjacentHTML('beforeend', '<line x1="500" y1="0" x2="500" y2="440" stroke="#FF4FD8" stroke-width="2" stroke-dasharray="6 6" pointer-events="none"/>');
      if (kl.y) svg.insertAdjacentHTML('beforeend', '<line x1="0" y1="220" x2="1000" y2="220" stroke="#FF4FD8" stroke-width="2" stroke-dasharray="6 6" pointer-events="none"/>');
    }
  }
  function tuvalBagla() {
    var svg = document.getElementById('rpTuval'); if (!svg) return;
    var drag = null;
    var nokta = function (ev) { var pt = svg.createSVGPoint(); pt.x = ev.clientX; pt.y = ev.clientY; var m = svg.getScreenCTM(); return m ? pt.matrixTransform(m.inverse()) : { x: 0, y: 0 }; };
    svg.addEventListener('pointerdown', function (ev) {
      var g = ev.target.closest && ev.target.closest('g[data-i]');
      if (!g) { if (ST.sec !== -1) { ST.sec = -1; stTuval(); stSecili(); } return; }
      var i = Number(g.dataset.i), o = ST.t.ogeler[i]; if (!o) return;
      var p = nokta(ev);
      drag = { i: i, dx: p.x - Number(o.x || 0), dy: p.y - Number(o.y || 0), once: JSON.stringify(ST.t), oynadi: false, id: ev.pointerId };
      try { svg.setPointerCapture(ev.pointerId); } catch (_) {}
      if (ST.sec !== i) { ST.sec = i; stSecili(); if (ST.sekme === 'sablon') { ST.sekme = o.t === 'metin' ? 'yazi' : 'oge'; stSekmeler(); stPanel(); } }
      stTuval();
      ev.preventDefault();
    });
    svg.addEventListener('pointermove', function (ev) {
      if (!drag || ev.pointerId !== drag.id) return;
      var p = nokta(ev), o = ST.t.ogeler[drag.i]; if (!o) return;
      var nx = Math.round(p.x - drag.dx), ny = Math.round(p.y - drag.dy);
      ST.kilavuz = { x: Math.abs(nx - 500) < 10 && o.hiza !== 'start' && o.hiza !== 'end', y: Math.abs(ny - 220) < 10 };
      if (ST.kilavuz.x) nx = 500; if (ST.kilavuz.y) ny = 220;
      if (Math.abs(nx - o.x) + Math.abs(ny - o.y) > 0) { o.x = sinir(nx, -150, W + 150, 500); o.y = sinir(ny, -150, H + 150, 220); drag.oynadi = true; stTuvalSonra(); }
    });
    var bitir = function (ev) {
      if (!drag || (ev && ev.pointerId !== drag.id)) return;
      if (drag.oynadi) { ST.geri.push(drag.once); if (ST.geri.length > 50) ST.geri.shift(); ST.ileri = []; ST.kirli = true; stAracDurum(); }
      drag = null; ST.kilavuz = null; stTuval();
    };
    svg.addEventListener('pointerup', bitir); svg.addEventListener('pointercancel', bitir);
  }
  var SEKME = [['sablon', 'Şablon'], ['yazi', 'Yazı'], ['oge', 'Öğe ekle'], ['zemin', 'Zemin'], ['efekt', 'Efekt']];
  function stSekmeler() {
    var n = document.getElementById('rpSekmeler'); if (!n) return;
    n.innerHTML = SEKME.map(function (s) { return '<button type="button" data-st="sekme" data-k="' + s[0] + '" class="' + (ST.sekme === s[0] ? 'aktif' : '') + '">' + s[1] + '</button>'; }).join('');
  }
  function renkSecici(anahtar, deger, palet) {
    deger = renkOk(deger, '#FFFFFF');
    var liste = (palet || []).concat(SABIT_RENK).filter(function (x, i, a) { return a.indexOf(x) === i; }).slice(0, 18);
    return '<div class="rp-renkler">' + liste.map(function (r) { return '<button type="button" aria-label="Renk ' + r + '" data-st="renk" data-k="' + anahtar + '" data-v="' + r + '" style="background:' + r + '" class="' + (r.toLowerCase() === deger.toLowerCase() ? 'aktif' : '') + '"></button>'; }).join('') +
      '<input type="color" aria-label="Özel renk" data-k="' + anahtar + '" data-tip="renk" value="' + deger + '"></div>';
  }
  function aralik(anahtar, etiket, deger, min, max, adim, birim) {
    return '<div class="rp-alan"><label>' + etiket + ' <span class="rp-deger">' + (Math.round(Number(deger) * 100) / 100) + (birim || '') + '</span></label><input type="range" data-k="' + anahtar + '" data-tip="sayi" min="' + min + '" max="' + max + '" step="' + (adim || 1) + '" value="' + deger + '"></div>';
  }
  function secenek(anahtar, liste, deger) {
    return '<div class="rp-secenek">' + liste.map(function (x) { return '<button type="button" data-st="sec" data-k="' + anahtar + '" data-v="' + esc(String(x[0])) + '" class="' + (String(deger) === String(x[0]) ? 'aktif' : '') + '">' + x[1] + '</button>'; }).join('') + '</div>';
  }
  function anahtarli(anahtar, etiket, deger) {
    return '<button type="button" data-st="anahtar" data-k="' + anahtar + '" class="' + (deger ? 'aktif' : '') + '">' + (deger ? '✓ ' : '') + etiket + '</button>';
  }
  function stSecili() {
    var el = document.getElementById('rpSecili'); if (!el) return;
    var o = ST.sec >= 0 ? ST.t.ogeler[ST.sec] : null;
    if (!o) { el.innerHTML = ''; return; }
    var pal = uyumPalet(ST.ctx.renk), h = '<div class="rp-secili"><div class="rp-secili-ust"><b>' + ({ metin: '✏️ Yazı', amblem: '🏳️ Amblem', portre: '🧑 Portre', sekil: '◼ Şekil', ikon: '★ İkon' }[o.t] || 'Öğe') + '</b><button type="button" class="rp-cip" data-st="secbirak">Bitti</button></div>';
    if (o.t === 'metin') {
      h += '<div class="rp-alan"><label for="rpMetin">Metin</label><textarea id="rpMetin" rows="2" maxlength="160" data-k="m" data-tip="metin" placeholder="Yazını gir (Enter ile alt satır)">' + esc(o.m || '') + '</textarea></div>' +
        '<button type="button" class="btn ikinci" data-st="slogan" style="margin:-4px 0 14px">✨ Slogan Ustası</button>' +
        '<div class="rp-alan"><label>Yazı tipi</label>' + secenek('font', Object.keys(FONT_AD).map(function (k) { return [k, '<span style="font-family:' + FONT[k].replace(/"/g, '&quot;') + '">' + FONT_AD[k] + '</span>']; }), o.font || 'kurul') + '</div>' +
        aralik('boy', 'Boyut', o.boy || 48, 12, 200, 1) +
        '<div class="rp-alan"><label>Renk</label>' + renkSecici('renk', o.renk, pal) + '</div>' +
        '<div class="rp-alan"><label>Kalınlık ve hiza</label>' + secenek('kal', [[400, 'İnce'], [700, 'Kalın'], [900, 'Siyah']], o.kal || 700) + '<div style="height:8px"></div>' + secenek('hiza', [['start', '⟸ Sol'], ['middle', 'Orta'], ['end', 'Sağ ⟹']], o.hiza || 'middle') + '</div>' +
        '<div class="rp-alan"><label>Süsleme</label><div class="rp-secenek">' + anahtarli('golge', 'Gölge', o.golge) + anahtarli('parla', 'Neon', o.parla) + anahtarli('kontur', 'Kontur', !!o.kontur) + anahtarli('arka', 'Vurgu kutusu', !!o.arka) + anahtarli('buyuk', 'BÜYÜK HARF', o.buyuk) + anahtarli('italik', 'İtalik', o.italik) + '</div></div>' +
        (o.kontur ? '<div class="rp-alan"><label>Kontur rengi</label>' + renkSecici('kontur', o.kontur, ['#000000', '#FFFFFF', ST.ctx.renk]) + '</div>' + aralik('kk', 'Kontur kalınlığı', o.kk || 6, 1, 20, 1) : '') +
        (o.arka ? '<div class="rp-alan"><label>Vurgu kutusu rengi</label>' + renkSecici('arka', o.arka, pal) + '</div>' : '') +
        aralik('harf', 'Harf aralığı', o.harf || 0, -4, 30, 1);
    } else if (o.t === 'amblem') {
      h += '<div class="rp-alan"><label>Amblem</label><div class="rp-ikon-izgara">' + (VERI.amblem || []).map(function (a) { return '<button type="button" data-st="sec" data-k="id" data-v="' + a.id + '" class="' + (o.id === a.id ? 'aktif' : '') + '"><svg viewBox="0 0 24 24" fill="currentColor">' + a.svg + '</svg>' + esc(a.ad) + '</button>'; }).join('') + '</div></div>' +
        aralik('s', 'Boyut', o.s || 90, 20, 400, 2) + '<div class="rp-alan"><label>Renk</label>' + renkSecici('renk', o.renk, pal) + '</div>' +
        '<div class="rp-alan"><div class="rp-secenek">' + anahtarli('arka', 'Daire zemin', !!o.arka) + '</div></div>' + (o.arka ? '<div class="rp-alan"><label>Daire rengi</label>' + renkSecici('arka', o.arka, pal) + '</div>' : '');
    } else if (o.t === 'portre') {
      h += aralik('s', 'Boyut', o.s || 200, 60, 400, 2) + '<div class="rp-alan"><label>Çerçeve</label>' + secenek('cerceve', [['daire', 'Daire'], ['kare', 'Kare'], ['yok', 'Çerçevesiz']], o.cerceve || 'daire') + '</div>' +
        (o.cerceve !== 'yok' ? '<div class="rp-alan"><label>Çerçeve rengi</label>' + renkSecici('kenar', o.kenar, pal) + '</div>' + aralik('kk', 'Çerçeve kalınlığı', o.kk == null ? 8 : o.kk, 0, 20, 1) : '') +
        (!o.kod ? '<p class="rp-not uyari">Portren henüz yok. Profilim → Portre bölümünden oluşturursan afişte görünür.</p>' : '');
    } else if (o.t === 'sekil') {
      h += '<div class="rp-alan"><label>Şekil</label>' + secenek('sekil', Object.keys(SEKIL_AD).map(function (k) { return [k, SEKIL_AD[k]]; }), o.sekil || 'kutu') + '</div>' +
        aralik('w', 'Genişlik', o.w || 200, 4, 1200, 2) + aralik('h', 'Yükseklik', o.h || 120, 2, 600, 2) +
        (o.sekil !== 'bayrak' ? '<div class="rp-alan"><label>Renk</label>' + renkSecici('renk', o.renk, pal) + '</div>' : '') +
        (o.sekil === 'kutu' || !o.sekil ? aralik('yuvarlak', 'Köşe yuvarlaklığı', o.yuvarlak || 0, 0, 150, 1) : '');
    } else if (o.t === 'ikon') {
      h += '<div class="rp-alan"><label>İkon</label><div class="rp-ikon-izgara">' + Object.keys(IKON).map(function (k) { return '<button type="button" data-st="sec" data-k="ad" data-v="' + k + '" class="' + (o.ad === k ? 'aktif' : '') + '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="' + IKON[k] + '"/></svg>' + esc(IKON_AD[k]) + '</button>'; }).join('') + '</div></div>' +
        aralik('s', 'Boyut', o.s || 90, 20, 400, 2) + '<div class="rp-alan"><label>Renk</label>' + renkSecici('renk', o.renk, pal) + '</div>' +
        '<div class="rp-alan"><div class="rp-secenek">' + anahtarli('dolu', 'İçi dolu', o.dolu) + '</div></div>' + aralik('kal', 'Çizgi kalınlığı', o.kal || 1.8, 0.8, 4, 0.1);
    }
    h += aralik('don', 'Döndür', o.don || 0, -45, 45, 1, '°') + aralik('op', 'Saydamlık', o.op == null ? 1 : o.op, 0.1, 1, 0.05);
    h += '<div class="rp-mini"><button type="button" data-st="one">Öne al</button><button type="button" data-st="arkaya">Arkaya al</button><button type="button" data-st="cogalt">Çoğalt</button><button type="button" class="tehlike" data-st="sil">Sil</button></div></div>';
    el.innerHTML = h;
  }
  function stPanel() {
    var el = document.getElementById('rpPanel'); if (!el) return;
    var c = ST.ctx, h = '';
    if (ST.sekme === 'sablon') {
      var uygun = SABLON.filter(function (s) { return s.icin.indexOf(ST.sahip.tur) >= 0; }).concat(SABLON.filter(function (s) { return s.icin.indexOf(ST.sahip.tur) < 0; }));
      h = '<p class="rp-not" style="margin:0 0 10px">Bir şablona dokun; renkler, amblem, adın ve portren kendiliğinden yerleşir. Sonra dilediğin gibi değiştir.</p><div class="rp-izgara">' +
        uygun.map(function (s) { return '<button type="button" class="rp-sablon" data-st="sablon" data-k="' + s.kod + '">' + afisSvg(s.f(c)) + '<b>' + esc(s.ad) + '</b></button>'; }).join('') + '</div>';
    } else if (ST.sekme === 'yazi') {
      var metinler = ST.t.ogeler.map(function (o, i) { return [o, i]; }).filter(function (x) { return x[0].t === 'metin'; });
      h = '<button type="button" class="btn" data-st="ekle" data-k="baslik" style="margin-top:0">＋ Başlık ekle</button><button type="button" class="btn ikinci" data-st="ekle" data-k="altbaslik">＋ Alt başlık ekle</button><button type="button" class="btn ikinci" data-st="slogan">✨ Slogan Ustası</button>' +
        (metinler.length ? '<div class="rp-bolum" style="margin-top:16px"><h3 style="font-size:17px">Afişteki yazılar</h3></div>' + metinler.map(function (x) { return '<button type="button" class="rp-radyo' + (x[1] === ST.sec ? ' aktif' : '') + '" data-st="secoge" data-k="' + x[1] + '"><b>' + esc(String(x[0].m || '').replace(/\n/g, ' ').slice(0, 40) || '(boş)') + '</b><small>' + (FONT_AD[x[0].font] || 'Kurul') + ' · ' + (x[0].boy || 48) + ' pt</small></button>'; }).join('') : '');
    } else if (ST.sekme === 'oge') {
      h = '<div class="rp-izgara">' +
        '<button type="button" class="rp-sablon" data-st="ekle" data-k="amblem"><div class="rp-kiralik" style="background:var(--panel3)"><svg viewBox="0 0 24 24" fill="' + c.renk + '" width="56" height="56">' + amblemIc(c.amblem) + '</svg></div><b>Amblem</b></button>' +
        '<button type="button" class="rp-sablon" data-st="ekle" data-k="portre"><div class="rp-kiralik" style="background:var(--panel3)"><div style="width:64px;height:64px;border-radius:50%;overflow:hidden">' + (c.avatar ? portreIc(c.avatar, c.ad, c.renk).replace('<svg', '<svg width="64" height="64"') : '<svg viewBox="0 0 24 24" width="56" fill="none" stroke="#fff" stroke-width="1.6"><path d="' + IKON.insan + '"/></svg>') + '</div></div><b>Portrem</b></button>' +
        '<button type="button" class="rp-sablon" data-st="ekle" data-k="sekil"><div class="rp-kiralik" style="background:var(--panel3)"><svg viewBox="0 0 60 30" width="90"><polygon points="0,0 60,0 52,15 60,30 0,30 8,15" fill="#fff"/></svg></div><b>Şekil</b></button>' +
        '<button type="button" class="rp-sablon" data-st="ekle" data-k="ikon"><div class="rp-kiralik" style="background:var(--panel3)"><svg viewBox="0 0 24 24" width="56" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="' + IKON.megafon + '"/></svg></div><b>İkon</b></button>' +
        '<button type="button" class="rp-sablon" data-st="ekle" data-k="bayrak"><div class="rp-kiralik" style="background:var(--panel3)"><svg viewBox="0 0 ' + W + ' ' + H + '" width="100">' + ogeSvg({ t: 'sekil', sekil: 'bayrak', x: 500, y: 220, w: 600, h: 400 }, 0, 'rpx' + (++RP.uid), []) + '</svg></div><b>Türk bayrağı</b></button>' +
        '<button type="button" class="rp-sablon" data-st="ekle" data-k="rozet"><div class="rp-kiralik" style="background:var(--panel3)"><svg viewBox="0 0 100 100" width="60"><polygon points="' + yildizNoktalar(50, 50, 48, 40, 18) + '" fill="#F0454B"/></svg></div><b>İndirim rozeti</b></button>' +
        '</div>';
    } else if (ST.sekme === 'zemin') {
      var z = ST.t.zemin || {}, pal = uyumPalet(c.renk);
      h = '<div class="rp-alan"><label>Zemin türü</label>' + secenek('z.tip', Object.keys(ZEMIN_AD).map(function (k) { return [k, ZEMIN_AD[k]]; }), z.tip || 'gradyan') + '</div>' +
        '<div class="rp-alan"><label>Birinci renk</label>' + renkSecici('z.r1', z.r1, pal) + '</div>' +
        (z.tip !== 'duz' ? '<div class="rp-alan"><label>İkinci renk</label>' + renkSecici('z.r2', z.r2, pal) + '</div>' : '') +
        (z.tip === 'gradyan' || !z.tip ? aralik('z.aci', 'Geçiş açısı', z.aci == null ? 135 : z.aci, 0, 360, 5, '°') : '') +
        '<div class="rp-alan"><label>Desen</label>' + secenek('z.desen', Object.keys(DESEN_AD).map(function (k) { return [k, DESEN_AD[k]]; }), z.desen || 'yok') + '</div>' +
        (z.desen && z.desen !== 'yok' ? aralik('z.dop', 'Desen yoğunluğu', z.dop == null ? 0.12 : z.dop, 0.02, 0.5, 0.01) : '') +
        '<button type="button" class="btn ikinci" data-st="sihir">🎨 Parti renklerimle uyumla</button>';
    } else if (ST.sekme === 'efekt') {
      var ef = ST.t.efekt || {};
      h = '<div class="rp-alan"><label>Yüzey</label>' + secenek('e.doku', Object.keys(DOKU_AD).map(function (k) { return [k, DOKU_AD[k]]; }), ef.doku || 'yok') + '</div>' +
        '<div class="rp-alan"><div class="rp-secenek">' + anahtarli('e.parlama', 'Parlak cila', ef.parlama) + anahtarli('e.kenar', 'İç çerçeve', !!ef.kenar) + '</div></div>' +
        (ef.kenar ? '<div class="rp-alan"><label>Çerçeve rengi</label>' + renkSecici('e.kenar', ef.kenar, uyumPalet(c.renk)) + '</div>' : '') +
        aralik('e.vinyet', 'Kenar karartma', ef.vinyet || 0, 0, 1, 0.05);
    }
    el.innerHTML = h;
  }
  function hedef(k) {
    if (k.indexOf('z.') === 0) { ST.t.zemin = ST.t.zemin || {}; return [ST.t.zemin, k.slice(2)]; }
    if (k.indexOf('e.') === 0) { ST.t.efekt = ST.t.efekt || {}; return [ST.t.efekt, k.slice(2)]; }
    var o = ST.t.ogeler[ST.sec]; return o ? [o, k] : null;
  }
  function yeniOge(tur) {
    var c = ST.ctx;
    if (tur === 'baslik') return { t: 'metin', m: 'BAŞLIĞINI YAZ', x: 500, y: 180, boy: 80, sig: 920, renk: kontrast((ST.t.zemin || {}).r1 || '#000000'), font: 'kurul', kal: 900, hiza: 'middle', golge: true };
    if (tur === 'altbaslik') return { t: 'metin', m: 'Alt başlık', x: 500, y: 280, boy: 38, sig: 920, renk: kontrast((ST.t.zemin || {}).r1 || '#000000'), font: 'kurul', kal: 700, hiza: 'middle' };
    if (tur === 'amblem') return { t: 'amblem', id: c.amblem, renk: c.renk, arka: '#FFFFFF', x: 860, y: 110, s: 100 };
    if (tur === 'portre') return portreOge(c, 200, 220, 240, 'daire', '#FFFFFF');
    if (tur === 'sekil') return { t: 'sekil', sekil: 'serit', x: 500, y: 360, w: 520, h: 70, renk: '#FFFFFF' };
    if (tur === 'ikon') return { t: 'ikon', ad: 'megafon', x: 150, y: 220, s: 140, renk: '#FFFFFF', kal: 1.8 };
    if (tur === 'bayrak') return { t: 'sekil', sekil: 'bayrak', x: 840, y: 120, w: 210, h: 140 };
    if (tur === 'rozet') return { t: 'sekil', sekil: 'rozet', x: 840, y: 200, w: 240, h: 240, renk: '#E30A17', don: -10 };
    return null;
  }
  function stTik(ev) {
    var b = ev.target.closest('[data-st]'); if (!b) return;
    var a = b.dataset.st, k = b.dataset.k, v = b.dataset.v;
    if (a === 'sekme') { ST.sekme = k; stSekmeler(); stPanel(); return; }
    if (a === 'sablon') {
      var s = SABLON.find(function (x) { return x.kod === k; }); if (!s) return;
      kayitAl(); ST.t = s.f(ST.ctx); ST.sec = -1; stHepsi(); toast('Şablon uygulandı: ' + s.ad); return;
    }
    if (a === 'geri') { if (!ST.geri.length) return; ST.ileri.push(JSON.stringify(ST.t)); ST.t = JSON.parse(ST.geri.pop()); ST.sec = Math.min(ST.sec, ST.t.ogeler.length - 1); stHepsi(); return; }
    if (a === 'ileri') { if (!ST.ileri.length) return; ST.geri.push(JSON.stringify(ST.t)); ST.t = JSON.parse(ST.ileri.pop()); stHepsi(); return; }
    if (a === 'secbirak') { ST.sec = -1; stTuval(); stSecili(); return; }
    if (a === 'secoge') { ST.sec = Number(k); stTuval(); stSecili(); stPanel(); window.scrollTo && document.getElementById('rpSecili').scrollIntoView({ block: 'nearest' }); return; }
    if (a === 'ekle') {
      if (ST.t.ogeler.length >= 32) { toast('Bir afişte en fazla 32 öğe olabilir', true); return; }
      var o = yeniOge(k); if (!o) return; kayitAl(); ST.t.ogeler.push(o); ST.sec = ST.t.ogeler.length - 1; stHepsi();
      document.getElementById('rpSecili').scrollIntoView({ block: 'nearest' });
      return;
    }
    if (a === 'renk' || a === 'sec') {
      var hd = hedef(k); if (!hd) return; kayitAl();
      var val = v; if (/^-?\d+(\.\d+)?$/.test(String(v)) && a === 'sec' && (k === 'kal')) val = Number(v);
      hd[0][hd[1]] = val;
      stTuval();
      if (k.indexOf('z.') === 0 || k.indexOf('e.') === 0) stPanel(); else stSecili();
      return;
    }
    if (a === 'anahtar') {
      var hd2 = hedef(k); if (!hd2) return; kayitAl();
      var ob = hd2[0], key = hd2[1];
      if (key === 'kontur') ob.kontur = ob.kontur ? undefined : '#000000';
      else if (key === 'arka') ob.arka = ob.arka ? undefined : (ob.t === 'amblem' ? '#FFFFFF' : koyu(ST.ctx.renk, 0.2));
      else if (key === 'kenar') ob.kenar = ob.kenar ? undefined : '#FFFFFF';
      else ob[key] = !ob[key];
      if (ob[key] === undefined) delete ob[key];
      if (key === 'parla' && ob.parla) delete ob.golge; if (key === 'golge' && ob.golge) delete ob.parla;
      stTuval(); if (k.indexOf('e.') === 0) stPanel(); else stSecili();
      return;
    }
    if (a === 'one' || a === 'arkaya' || a === 'cogalt' || a === 'sil') {
      var i = ST.sec, L = ST.t.ogeler; if (i < 0 || !L[i]) return; kayitAl();
      if (a === 'one' && i < L.length - 1) { L.splice(i + 1, 0, L.splice(i, 1)[0]); ST.sec = i + 1; }
      else if (a === 'arkaya' && i > 0) { L.splice(i - 1, 0, L.splice(i, 1)[0]); ST.sec = i - 1; }
      else if (a === 'cogalt') { if (L.length >= 32) { toast('Bir afişte en fazla 32 öğe olabilir', true); return; } var c2 = kopya(L[i]); c2.x = Number(c2.x || 0) + 30; c2.y = Number(c2.y || 0) + 30; L.push(c2); ST.sec = L.length - 1; }
      else if (a === 'sil') { L.splice(i, 1); ST.sec = -1; }
      stHepsi(); return;
    }
    if (a === 'sihir') {
      kayitAl(); var c = ST.ctx.renk, z = ST.t.zemin = ST.t.zemin || {};
      var secenekler = [[c, koyu(c, 0.6), 'gradyan'], [koyu(c, 0.7), c, 'isinsal'], [c, acik(c, 0.85), 'gunes'], [uyumPalet(c)[1], c, 'gradyan']];
      var sec = secenekler[(Number(ST._sihir) || 0) % secenekler.length]; ST._sihir = (Number(ST._sihir) || 0) + 1;
      z.r1 = sec[0]; z.r2 = sec[1]; z.tip = sec[2];
      stTuval(); stPanel(); return;
    }
    if (a === 'slogan') return sloganModal();
    if (a === 'sahip') return sahipModal();
    if (a === 'kaydet' || a === 'as') return stKaydet(a === 'as');
  }
  function stGirdi(ev) {
    var el = ev.target, k = el.dataset && el.dataset.k, tip = el.dataset && el.dataset.tip; if (!k || !tip) return;
    var hd = hedef(k); if (!hd) return;
    if (!ST._girdi) { kayitAl(); ST._girdi = true; }
    if (tip === 'sayi') { hd[0][hd[1]] = Number(el.value); var lab = el.parentNode.querySelector('.rp-deger'); if (lab) lab.textContent = (Math.round(Number(el.value) * 100) / 100) + (k === 'don' || k === 'z.aci' ? '°' : ''); }
    else if (tip === 'renk') { hd[0][hd[1]] = renkOk(el.value, '#FFFFFF'); }
    else if (tip === 'metin') { hd[0][hd[1]] = String(el.value).slice(0, 160); }
    stTuvalSonra();
  }
  function stDegisim(ev) { ST._girdi = false; if (ev.target && ev.target.dataset && ev.target.dataset.tip === 'renk') { var k = ev.target.dataset.k; if (k.indexOf('z.') === 0 || k.indexOf('e.') === 0) stPanel(); else stSecili(); } if (ev.target && ev.target.dataset && ev.target.dataset.tip === 'metin' && ST.sekme === 'yazi') stPanel(); }
  function sloganModal() {
    var temalar = Object.keys(SLOGAN).concat(ST.sahip.tur === 'sirket' || ST.sahip.tur === 'gazete' ? ['Ticari'] : []);
    var tema = ST.sahip.tur === 'sirket' ? 'Ticari' : ST.sahip.tur === 'dernek' ? 'Birlik' : 'Değişim';
    var md = modal('<h3 style="font-size:19px;font-weight:800">✨ Slogan Ustası</h3><p class="rp-not">Bir tema seç, sana özel sloganlar üreteyim. Beğendiğine dokun.</p><div class="rp-alan" style="margin-top:10px"><div class="rp-secenek" id="rpTemalar"></div></div><div id="rpSloganlar"></div><button class="btn ikinci" id="rpYeniSlogan">🔄 Yenilerini üret</button><button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
    var ciz = function () {
      md.querySelector('#rpTemalar').innerHTML = temalar.map(function (t) { return '<button type="button" data-tema="' + esc(t) + '" class="' + (t === tema ? 'aktif' : '') + '">' + esc(t) + '</button>'; }).join('');
      md.querySelector('#rpSloganlar').innerHTML = sloganUret(tema, ST.ctx).map(function (s) { return '<button type="button" class="rp-slogan" data-slogan="' + esc(s) + '">' + esc(s) + '</button>'; }).join('');
    };
    ciz();
    md.addEventListener('click', function (ev) {
      var t = ev.target.closest('[data-tema]'); if (t) { tema = t.dataset.tema; ciz(); return; }
      if (ev.target.closest('#rpYeniSlogan')) { ciz(); return; }
      var s = ev.target.closest('[data-slogan]'); if (!s) return;
      kayitAl();
      var o = ST.sec >= 0 ? ST.t.ogeler[ST.sec] : null;
      if (o && o.t === 'metin') { o.m = s.dataset.slogan; if (!o.sig) o.sig = o.hiza === 'middle' || !o.hiza ? 920 : Math.max(300, o.hiza === 'start' ? 960 - Number(o.x || 0) : Number(o.x || 0) - 40); }
      else { var y = yeniOge('altbaslik'); y.m = s.dataset.slogan; y.boy = 44; y.kal = 900; ST.t.ogeler.push(y); ST.sec = ST.t.ogeler.length - 1; }
      modalKapat(); stHepsi(); toast('Slogan eklendi');
    });
  }
  function sahipModal() {
    var kay = (RP.merkez && RP.merkez.kaynaklar) || [];
    var md = modal('<h3 style="font-size:19px;font-weight:800">Afiş kimin adına?</h3><p class="rp-not">Künyede “Ödeyen” olarak görünür. Parti, dernek, şirket ya da gazete adına hazırlayabilirsin.</p><div style="margin-top:10px">' +
      kay.map(function (k, i) { return '<button type="button" class="rp-radyo' + (k.tur === ST.sahip.tur && String(k.id) === String(ST.sahip.id) ? ' aktif' : '') + '" data-i="' + i + '"><b>' + esc(k.tur === 'oyuncu' ? 'Kişisel · ' + k.ad : k.ad) + '</b><small>' + ({ oyuncu: 'Kendi adına', parti: 'Parti', dernek: 'Dernek', sirket: 'Şirket', gazete: 'Gazete' }[k.tur] || '') + (k.odeme ? '' : ' · kasadan ödemeyi yetkili yapar') + '</small></button>'; }).join('') + '</div>' +
      (ST.id ? '<p class="rp-not">Kayıtlı bir afişin sahibi değiştirilemez; yeni sahip için “Kopyasını oluştur” kullan.</p>' : ''));
    md.addEventListener('click', function (ev) {
      var b = ev.target.closest('[data-i]'); if (!b) return;
      if (ST.id) { toast('Kayıtlı afişin sahibi değiştirilemez', true); return; }
      ST.sahip = kay[Number(b.dataset.i)]; ST.ctx = baglam(ST.sahip); modalKapat(); stHepsi();
    });
  }
  async function stKaydet(as) {
    var ilkYazi = (ST.t.ogeler.find(function (o) { return o.t === 'metin' && String(o.m || '').trim(); }) || {}).m || 'Afişim';
    var ad = ST.ad || String(ilkYazi).replace(/\n/g, ' ').slice(0, 40);
    if (!ST.id) {
      var md = modal('<h3 style="font-size:19px;font-weight:800">Afişi kaydet</h3><div class="rp-alan" style="margin-top:10px"><label for="rpAfisAd">Afiş adı (yalnız sen görürsün)</label><input type="text" id="rpAfisAd" maxlength="60" value="' + esc(ad) + '"></div><p class="rp-not">Sahibi: ' + esc(ST.sahip.tur === 'oyuncu' ? 'Kişisel' : ST.sahip.ad) + '</p><button class="btn rp-btn-sicak" id="rpAfisKaydetOnay">' + (as ? 'Kaydet ve devam et' : 'Kaydet') + '</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
      md.querySelector('#rpAfisKaydetOnay').onclick = function () { var v = md.querySelector('#rpAfisAd').value.trim(); if (v.length < 2) { toast('Afiş adı en az 2 karakter olmalı', true); return; } modalKapat(); ST.ad = v; gonder(as); };
      return;
    }
    gonder(as);
  }
  async function gonder(as) {
    var btns = document.querySelectorAll('[data-st="kaydet"],[data-st="as"]'); btns.forEach(function (b) { b.disabled = true; });
    try {
      var r = await API.rpc('afis_kaydet', { p_id: ST.id, p_sahip_tur: ST.sahip.tur, p_sahip_id: ST.sahip.tur === 'oyuncu' ? null : Number(ST.sahip.id), p_ad: ST.ad, p_tasarim: ST.t });
      ST.id = Number(r.id); ST.kirli = false;
      var m = await merkezYukle();
      toast('Afiş kaydedildi');
      if (as) { var f = (m.afisler || []).find(function (x) { return Number(x.id) === ST.id; }); kiralaModal({ afis: f || { id: ST.id, ad: ST.ad, sahip_tur: ST.sahip.tur, sahip_id: ST.sahip.id, tasarim: ST.t }, kapsam: 'il', il: EKR.il || (profil() && profil().il_id) }); }
    } catch (err) { hataGoster(err); }
    btns.forEach(function (b) { b.disabled = false; });
  }

  /* ---------------------------------------------------------------
     10) BAĞLANTILAR: genel adlar, Gündem şeridi
     --------------------------------------------------------------- */
  window.reklamPanolariEkrani = reklamPanolariEkrani;
  window.afisStudyosu = afisStudyosu;
  window.rpKiralaModal = kiralaModal;
  window.rpYayinModal = yayinModal;
  try {
    var eskiIskelet = iskelet;
    var yeniIskelet = function (baslik) {
      var r = eskiIskelet.apply(this, arguments);
      if (baslik === 'Gündem') setTimeout(function () { seritCiz(0); }, 40);
      return r;
    };
    iskelet = yeniIskelet;
    window.iskelet = yeniIskelet;
  } catch (_) {}
})();
