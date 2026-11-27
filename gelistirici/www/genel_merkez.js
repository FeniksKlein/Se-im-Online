/* =====================================================================
   PARTİ GENEL MERKEZLERİ — 27.11.2026
   İstek (Ercan): "Satın almaya bağlı olmayan genel merkezler ekle oyuna ama satın alınca daha şık, daha imtiyazlı dursun.
                   Ondan hariç her türlü de şık bir genel merkez paneli görünüşü hazırla."
   Sunucu: sql/zz_20261127_genel_merkez.sql → genel_merkez_panel(p_parti)
   • Bina (kademe 1–4) satın alınmaz: aktif üye + il teşkilatı + il başkanı sayısından hesaplanır.
   • Genel Merkez Kampanyası (mağaza) yalnız görünümü süsler: Bronz / Gümüş / Altın donanım (prestij 1–3).
   Ekran: genelMerkezAc(parti) — sahne (parti renginde bina), bina kademesi ve hedefler, yönetim katı, sayılar, katlar (kısayollar),
          pano (miting, il açıklamaları), imtiyazlı görünüm (önizleme + kampanya), bütün partilerin genel merkezleri.
   Girişler: parti sayfası kartı, Menü › Siyaset karosu, menü araması, bildirim rotası. magaza_paket2.js'ten ÖNCE yüklenir
   (o dosyanın parti sayfası kartı ve Genel Merkez ekranı bu dosya varken buraya devreder).
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_GENEL_MERKEZ_V1) return;
  window.SO_GENEL_MERKEZ_V1 = true;

  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var hata = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var zaman = function (t) { if (!t) return ''; try { return typeof tarihSaat === 'function' ? tarihSaat(t) : new Date(t).toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }); } catch (_) { return ''; } };
  var gun = function (t) { try { return new Date(t).toLocaleDateString('tr-TR', { timeZone: 'Europe/Istanbul', day: 'numeric', month: 'long', year: 'numeric' }); } catch (_) { return ''; } };
  var tl = function (n) { return Number(n || 0).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' ₺'; };
  var n = function (v) { return Number(v) || 0; };
  var rpc = (ad, a) => API.rpc(ad, a || {});
  var ac = function (fn) { if (typeof ekranAc === 'function') ekranAc(fn); else fn(); };
  var bildir = function (m, h) { try { toast(m, h); } catch (_) {} };
  var ic = function () { return document.getElementById('icerik'); };
  var amb = function (p, boy) { try { if (typeof amblemKutu === 'function' && p) return amblemKutu(p, boy || 44); } catch (_) {} return ''; };
  var yuz = function (kad, renk, boy) { try { if (typeof portre === 'function' && kad) return portre(kad, renk, boy); } catch (_) {} return '<span class="gmz-yuz" style="width:' + boy + 'px;height:' + boy + 'px"></span>'; };
  var kartAc = function (kad) { try { if (kad && typeof oyuncuKart === 'function') oyuncuKart(kad); } catch (_) {} };
  var g = function (ad) { return typeof window[ad] === 'function' ? window[ad] : null; };

  var KADEME = ['', 'Kuruluş Bürosu', 'Genel Merkez Binası', 'Genel Merkez Yerleşkesi', 'Büyük Genel Merkez'];
  var PRESTIJ = ['Standart', 'Bronz Donanım', 'Gümüş Donanım', 'Altın Donanım'];
  var PRESTIJ_NE = ['Sade cephe.', 'Tören bayrakları, bronz saçak ve kapı, aydınlık katlar.', 'Bronz donanıma ek: peyzaj, cephe aydınlatması, gümüş saçak.', 'Gümüş donanıma ek: altın kubbe, kırmızı halı, projektörler ve yıldızlı gece.'];
  var TRIM = ['#8e99bd', '#d0915a', '#dfe5f3', '#f2c46d'];
  var ALAN = { hukuk: 'Hukuk', mali: 'Mali işler', miting: 'Miting', secim: 'Seçim işleri', tanitim: 'Tanıtım', teskilat: 'Teşkilat' };
  var ROL = { gb: 'Genel Başkansın', gby: 'Genel Başkan Yardımcısısın', uye: 'Partinin üyesisin' };

  var S = { v: null, onK: null, onP: null };

  /* ------------------------------------------------ renk yardımcıları */
  function hex(r) { r = String(r || '').trim(); if (/^#[0-9a-f]{3}$/i.test(r)) r = '#' + r[1] + r[1] + r[2] + r[2] + r[3] + r[3]; return /^#[0-9a-f]{6}$/i.test(r) ? r : '#5d6ee8'; }
  function karis(a, b, o) {
    a = hex(a); b = hex(b);
    var p = function (h, i) { return parseInt(h.substr(1 + i * 2, 2), 16); }, s = '#';
    for (var i = 0; i < 3; i++) { var v = Math.round(p(a, i) * (1 - o) + p(b, i) * o); s += (v < 16 ? '0' : '') + v.toString(16); }
    return s;
  }
  function parlak(r) { r = hex(r); return (parseInt(r.substr(1, 2), 16) * 299 + parseInt(r.substr(3, 2), 16) * 587 + parseInt(r.substr(5, 2), 16) * 114) / 1000; }

  /* ------------------------------------------------ BİNA (SVG) */
  var SAY = 0;
  function bina(k, p, renk, kisa) {
    k = Math.max(1, Math.min(4, n(k) || 1)); p = Math.max(0, Math.min(3, n(p)));
    renk = hex(renk); if (parlak(renk) < 60) renk = karis(renk, '#ffffff', .25);
    var id = 'gmz' + (++SAY), W = 360, H = 230, Y = 194, cx = 180;
    var trim = TRIM[p], duvar = karis(renk, '#323c66', .86), duvarK = karis(renk, '#232b50', .9), golge = karis(renk, '#161c38', .92);
    var isik = p ? '#ffe3a3' : '#f1c97d', sonuk = '#141a36', yazi = parlak(renk) > 165 ? '#1a1f38' : '#ffffff';
    var yanar = function (i) { return p >= 2 || ((i * 37 + k * 11 + 5) % 100) < (p === 1 ? 80 : 44); };
    var s = '<svg class="gmz-svg" viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="' + esc(KADEME[k]) + (p ? ', ' + esc(PRESTIJ[p]) : '') + '" preserveAspectRatio="xMidYMax slice"><defs>' +
      '<linearGradient id="' + id + 'g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + (p === 3 ? '#0a0e24' : '#0f1531') + '"/><stop offset=".7" stop-color="' + karis(renk, '#232d58', p === 3 ? .8 : .88) + '"/><stop offset="1" stop-color="' + karis(renk, '#3a4680', .78) + '"/></linearGradient>' +
      '<linearGradient id="' + id + 'u" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="' + trim + '" stop-opacity=".42"/><stop offset=".65" stop-color="' + trim + '" stop-opacity="0"/></linearGradient>' +
      '<linearGradient id="' + id + 'a" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff1c2"/><stop offset=".5" stop-color="#f2c46d"/><stop offset="1" stop-color="#b9862f"/></linearGradient>' +
      '<radialGradient id="' + id + 'h" cx=".5" cy=".62" r=".55"><stop offset="0" stop-color="' + trim + '" stop-opacity="' + (p === 3 ? .34 : p === 2 ? .2 : .1) + '"/><stop offset="1" stop-color="' + trim + '" stop-opacity="0"/></radialGradient>' +
      '</defs><rect width="' + W + '" height="' + H + '" fill="url(#' + id + 'g)"/>';
    // gökyüzü: ay, yıldızlar, projektörler
    if (p === 3) {
      [[26, 22], [64, 46], [98, 16], [142, 34], [222, 20], [262, 42], [298, 14], [338, 34], [318, 66], [44, 78]].forEach(function (q, i) { s += '<circle class="gmz-yildiz" style="animation-delay:' + (i * .37).toFixed(2) + 's" cx="' + q[0] + '" cy="' + q[1] + '" r="' + (i % 3 ? 1 : 1.5) + '" fill="#fff6d6"/>'; });
      s += '<polygon points="52,' + Y + ' 64,' + Y + ' 150,0 96,0" fill="#fff" opacity=".06"/><polygon points="308,' + Y + ' 296,' + Y + ' 210,0 264,0" fill="#fff" opacity=".06"/>';
    } else s += '<circle cx="312" cy="34" r="11" fill="#e9ecff" opacity=".2"/><circle cx="316" cy="31" r="10" fill="url(#' + id + 'g)"/>';
    // uzak şehir silüeti
    [[0, 30, 58], [26, 22, 84], [52, 34, 46], [270, 28, 70], [300, 24, 96], [326, 34, 54]].forEach(function (q) { s += '<rect x="' + q[0] + '" y="' + (Y - q[2]) + '" width="' + q[1] + '" height="' + q[2] + '" fill="#141a38" opacity=".7"/>'; });
    s += '<ellipse cx="' + cx + '" cy="' + (Y - 40) + '" rx="170" ry="100" fill="url(#' + id + 'h)"/>';
    // zemin
    s += '<rect x="0" y="' + Y + '" width="' + W + '" height="' + (H - Y) + '" fill="' + (p >= 2 ? '#173a31' : '#161c36') + '"/><rect x="0" y="' + Y + '" width="' + W + '" height="3" fill="' + (p >= 2 ? '#24594a' : '#27305a') + '"/>' +
      '<rect x="0" y="' + (H - 12) + '" width="' + W + '" height="12" fill="#10152b"/>';
    for (var yx = 10; yx < W; yx += 34) s += '<rect x="' + yx + '" y="' + (H - 7) + '" width="16" height="1.6" fill="#3a4476"/>';

    var pi = 0;
    function blok(x, w, kat, fh, o) {
      o = o || {}; var top = Y - kat * fh, h = '';
      h += '<rect x="' + x + '" y="' + top + '" width="' + w + '" height="' + (kat * fh) + '" fill="' + (o.koyu ? duvarK : duvar) + '"/><rect x="' + x + '" y="' + top + '" width="4" height="' + (kat * fh) + '" fill="#fff" opacity=".05"/>' +
        '<rect x="' + (x + w - 5) + '" y="' + top + '" width="5" height="' + (kat * fh) + '" fill="#000" opacity=".14"/>';
      var cols = Math.max(2, Math.floor((w - 8) / 15)), bos = (w - cols * 9) / (cols + 1);
      for (var f = 0; f < kat; f++) for (var c = 0; c < cols; c++) {
        if (o.kapi && f === kat - 1 && Math.abs(x + bos + c * (9 + bos) + 4.5 - (x + w / 2)) < 14) continue;
        var on = yanar(pi++);
        h += '<rect x="' + (x + bos + c * (9 + bos)).toFixed(1) + '" y="' + (top + f * fh + (fh - 10) / 2 + 1).toFixed(1) + '" width="9" height="10" rx="1" fill="' + (on ? isik : sonuk) + '"' + (on ? '' : ' opacity=".9"') + '/>';
      }
      if (p >= 2) h += '<rect x="' + x + '" y="' + top + '" width="' + w + '" height="' + (kat * fh) + '" fill="url(#' + id + 'u)"/>';
      h += '<rect x="' + (x - 3) + '" y="' + (top - 4) + '" width="' + (w + 6) + '" height="5" rx="1" fill="' + trim + '"/>';
      return h;
    }
    function kapi(w, genis) {
      var h = '<rect x="' + (cx - genis / 2) + '" y="' + (Y - 22) + '" width="' + genis + '" height="22" rx="2" fill="#0c1026" stroke="' + trim + '" stroke-width="1.6"/><rect x="' + (cx - .5) + '" y="' + (Y - 21) + '" width="1" height="20" fill="' + trim + '" opacity=".7"/>' +
        '<rect x="' + (cx - genis / 2 - 8) + '" y="' + (Y - 3) + '" width="' + (genis + 16) + '" height="3" fill="' + karis(trim, '#1a2040', .35) + '"/>';
      if (p >= 1) h += '<rect x="' + (cx - genis / 2 - 7) + '" y="' + (Y - 29) + '" width="' + (genis + 14) + '" height="5" rx="1.5" fill="' + (p === 3 ? 'url(#' + id + 'a)' : trim) + '"/>';
      return h;
    }
    function tabela(top, w) {
      var yz = String(kisa || '').slice(0, 6);
      return '<rect x="' + (cx - w / 2) + '" y="' + (top + 4) + '" width="' + w + '" height="13" rx="2" fill="' + renk + '"' + (p ? ' stroke="' + trim + '" stroke-width="1"' : '') + '/>' +
        (yz ? '<text x="' + cx + '" y="' + (top + 14) + '" text-anchor="middle" font-size="9.5" font-weight="900" fill="' + yazi + '" style="letter-spacing:.6px">' + esc(yz) + '</text>' : '');
    }
    function bayrak(x, y, boy, buyuk) {
      var w = buyuk ? 20 : 13, hh = buyuk ? 12 : 8;
      return '<rect x="' + (x - .8) + '" y="' + (y - boy) + '" width="1.6" height="' + boy + '" fill="' + (p ? trim : '#aeb6d6') + '"/><circle cx="' + x + '" cy="' + (y - boy) + '" r="1.8" fill="' + (p ? trim : '#aeb6d6') + '"/>' +
        '<path class="gmz-bayrak" d="M' + (x + 1) + ' ' + (y - boy + 2) + ' q' + (w / 4) + ' -3 ' + (w / 2) + ' 0 t' + (w / 2) + ' 0 v' + hh + ' q-' + (w / 4) + ' 3 -' + (w / 2) + ' 0 t-' + (w / 2) + ' 0 z" fill="' + renk + '" stroke="#fff" stroke-opacity=".25" stroke-width=".6"/>';
    }
    function agac(x, r) { return '<rect x="' + (x - 1.5) + '" y="' + (Y - r) + '" width="3" height="' + r + '" fill="#4a3a2a"/><circle cx="' + x + '" cy="' + (Y - r - r * .6) + '" r="' + r + '" fill="#2c7a58"/><circle cx="' + (x - r * .35) + '" cy="' + (Y - r - r * .9) + '" r="' + (r * .55) + '" fill="#3c9a70" opacity=".8"/>'; }
    function lamba(x) { return '<rect x="' + (x - .7) + '" y="' + (Y - 24) + '" width="1.4" height="24" fill="#8088ad"/><circle cx="' + x + '" cy="' + (Y - 25) + '" r="2.4" fill="#ffe3a3"/><circle cx="' + x + '" cy="' + (Y - 25) + '" r="8" fill="#ffe3a3" opacity=".14"/>'; }

    var ana, top;
    if (k === 1) {
      s += blok(92, 46, 5, 17, { koyu: true }).replace(/fill="#f1c97d"|fill="#ffe3a3"/g, 'fill="#3c4470"') + blok(222, 50, 2, 19, { koyu: true }).replace(/fill="#f1c97d"|fill="#ffe3a3"/g, 'fill="#3c4470"');
      ana = 84; top = Y - 3 * 21;
      s += blok(cx - ana / 2, ana, 3, 21, { kapi: true });
      s += '<rect x="' + (cx - ana / 2 + 6) + '" y="' + (Y - 20) + '" width="22" height="16" rx="1" fill="' + isik + '" opacity=".9"/><rect x="' + (cx + ana / 2 - 28) + '" y="' + (Y - 20) + '" width="22" height="16" rx="1" fill="' + isik + '" opacity=".9"/>' +
        '<path d="M' + (cx - ana / 2 - 4) + ' ' + (Y - 24) + ' h' + (ana + 8) + ' l-5 -8 h-' + (ana - 2) + ' z" fill="' + renk + '"/>' + kapi(ana, 14) +
        tabela(top + 3, 58) + bayrak(cx + ana / 2 - 8, top - 4, 20, false);
    } else if (k === 2) {
      ana = 132; top = Y - 5 * 20;
      s += blok(cx - ana / 2, ana, 5, 20, { kapi: true }) + kapi(ana, 20) + tabela(top + 1, 76) + (p < 3 ? bayrak(cx, top - 4, 24, false) : '');
    } else if (k === 3) {
      ana = 112; top = Y - 6 * 20;
      s += blok(56, 70, 4, 20, { koyu: true }) + blok(234, 70, 4, 20, { koyu: true }) + blok(cx - ana / 2, ana, 6, 20, { kapi: true }) + kapi(ana, 22) + tabela(top + 1, 78) + (p < 3 ? bayrak(cx, top - 4, 26, false) : '');
    } else {
      ana = 98; top = Y - 7 * 19;
      s += blok(28, 50, 3, 20, { koyu: true }) + blok(282, 50, 3, 20, { koyu: true }) + blok(74, 60, 5, 20) + blok(226, 60, 5, 20) +
        blok(cx - ana / 2, ana, 7, 19, { kapi: true }) +
        '<rect x="' + (cx - 30) + '" y="' + (top - 16) + '" width="60" height="12" fill="' + duvar + '"/><rect x="' + (cx - 33) + '" y="' + (top - 19) + '" width="66" height="4" rx="1" fill="' + trim + '"/>' +
        kapi(ana, 24) + tabela(top + 1, 74);
      top -= 15; if (p < 3) s += bayrak(cx, top - 4, 22, false);
    }
    // donanım (prestij)
    var yan = k === 1 ? 54 : k === 2 ? 78 : k === 3 ? 136 : 160;
    var by = k === 1 ? 52 : 40;
    if (p >= 1) s += bayrak(cx - by, Y, k === 1 ? 38 : 44, true) + bayrak(cx + by, Y, k === 1 ? 38 : 44, true) + lamba(cx - yan - 6) + lamba(cx + yan + 6);
    if (p >= 2) s += agac(cx - yan - 22, 11) + agac(cx + yan + 22, 11) + (k <= 2 ? agac(cx - yan - 46, 8) + agac(cx + yan + 46, 8) : '');
    if (p === 2) s += '<ellipse cx="' + cx + '" cy="' + (Y + 12) + '" rx="26" ry="5" fill="#0e2c40"/><ellipse cx="' + cx + '" cy="' + (Y + 11) + '" rx="22" ry="3.6" fill="#3aa3c9" opacity=".75"/><rect x="' + (cx - .8) + '" y="' + (Y + 2) + '" width="1.6" height="9" fill="#bfeaff" opacity=".9"/>';
    if (p === 3) {
      var dy = top - 4, dr = k === 1 ? 16 : k === 4 ? 20 : 22;
      s += '<path d="M' + (cx - dr) + ' ' + dy + ' Q' + (cx - dr) + ' ' + (dy - dr * 1.25) + ' ' + cx + ' ' + (dy - dr * 1.3) + ' Q' + (cx + dr) + ' ' + (dy - dr * 1.25) + ' ' + (cx + dr) + ' ' + dy + ' z" fill="url(#' + id + 'a)"/>' +
        '<rect x="' + (cx - dr - 3) + '" y="' + (dy - 2) + '" width="' + (dr * 2 + 6) + '" height="3" rx="1" fill="#fff1c2"/><rect x="' + (cx - .8) + '" y="' + (dy - dr * 1.3 - 12) + '" width="1.6" height="12" fill="#fff1c2"/><circle cx="' + cx + '" cy="' + (dy - dr * 1.3 - 13) + '" r="2.4" fill="#fff1c2"/>' +
        '<polygon points="' + (cx - 9) + ',' + Y + ' ' + (cx + 9) + ',' + Y + ' ' + (cx + 20) + ',' + (H - 12) + ' ' + (cx - 20) + ',' + (H - 12) + '" fill="#b3232d"/><polygon points="' + (cx - 9) + ',' + Y + ' ' + (cx - 7) + ',' + Y + ' ' + (cx - 16) + ',' + (H - 12) + ' ' + (cx - 20) + ',' + (H - 12) + '" fill="#f2c46d" opacity=".8"/>' +
        '<polygon points="' + (cx + 9) + ',' + Y + ' ' + (cx + 7) + ',' + Y + ' ' + (cx + 16) + ',' + (H - 12) + ' ' + (cx + 20) + ',' + (H - 12) + '" fill="#f2c46d" opacity=".8"/>';
    }
    return s + '</svg>';
  }
  window.genelMerkezBina = bina;

  /* ------------------------------------------------ stil */
  function css() {
    if (document.getElementById('gmz-css')) return;
    var s = document.createElement('style'); s.id = 'gmz-css';
    s.textContent = [
      '.gmz-sahne{position:relative;border-radius:20px;overflow:hidden;border:1px solid rgba(255,255,255,.14);background:#0f1531;margin:0 0 12px}',
      '.gmz-sahne.p1{border-color:#a8703f;box-shadow:0 0 0 1px rgba(208,145,90,.35),0 10px 30px rgba(208,145,90,.12)}',
      '.gmz-sahne.p2{border-color:#c9d1e6;box-shadow:0 0 0 1px rgba(223,229,243,.4),0 10px 34px rgba(223,229,243,.14)}',
      '.gmz-sahne.p3{border-color:#f2c46d;box-shadow:0 0 0 1px rgba(242,196,109,.55),0 12px 40px rgba(242,196,109,.22)}',
      '.gmz-gok{display:block;line-height:0;aspect-ratio:360/230;max-height:300px;width:100%}',
      '.gmz-svg{display:block;width:100%;height:100%}',
      '.gmz-bayrak{transform-box:fill-box;transform-origin:left center;animation:gmzDalga 3.2s ease-in-out infinite}',
      '.gmz-yildiz{animation:gmzYildiz 2.8s ease-in-out infinite}',
      '@keyframes gmzDalga{0%,100%{transform:skewY(0)}50%{transform:skewY(-5deg)}}@keyframes gmzYildiz{0%,100%{opacity:1}50%{opacity:.25}}',
      '@media (prefers-reduced-motion: reduce){.gmz-bayrak,.gmz-yildiz{animation:none}}',
      '.gmz-levha{display:flex;align-items:center;gap:12px;padding:12px 14px 4px;color:#fff}',
      '.gmz-levha .orta{flex:1;min-width:0}.gmz-levha h2{font-size:21px;font-weight:900;line-height:1.2;margin:0;overflow-wrap:anywhere}',
      '.gmz-sahne.p3 .gmz-levha h2{background:linear-gradient(90deg,#fff1c2,#f2c46d 55%,#d9a441);-webkit-background-clip:text;background-clip:text;color:transparent}',
      '.gmz-sahne.p2 .gmz-levha h2{color:#f1f4fc}.gmz-sahne.p1 .gmz-levha h2{color:#f3d3b4}',
      '.gmz-levha small{display:block;font-size:13.5px;opacity:.85;margin-top:3px;line-height:1.4;overflow-wrap:anywhere}',
      '.gmz-cipler{display:flex;flex-wrap:wrap;gap:6px;padding:8px 14px 14px}',
      '.gmz-cip{display:inline-flex;align-items:center;gap:5px;padding:4px 10px;border-radius:999px;font-size:13px;font-weight:800;line-height:1.3;color:#fff;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.2)}',
      '.gmz-cip.d1{background:rgba(208,145,90,.18);border-color:#d0915a;color:#f3d3b4}.gmz-cip.d2{background:rgba(223,229,243,.16);border-color:#dfe5f3;color:#f1f4fc}.gmz-cip.d3{background:#f2c46d;border-color:#f2c46d;color:#2a1d05}',
      '.gmz-cip.rol{background:rgba(127,224,166,.12);border-color:#2c6e4a;color:#a9f0c6}.gmz-cip.canli{background:#d93a3a;border-color:#ff7a7a}',
      '.gmz-onizle{display:flex;align-items:center;gap:8px;padding:8px 12px;background:#f2c46d;color:#2a1d05;font-size:13.5px;font-weight:800;line-height:1.35}',
      '.gmz-onizle span{flex:1;min-width:0}.gmz-onizle button{flex:none;min-height:36px;padding:4px 12px;border-radius:999px;border:0;background:#2a1d05;color:#fff;font:inherit;font-size:13px}',
      '.gmz-bas{font-size:17px;font-weight:800;margin:0 0 4px;display:flex;align-items:center;gap:8px}',
      '.gmz-bas:before{content:"";flex:none;width:4px;height:17px;border-radius:2px;background:var(--gmz-trim,#8e99bd)}',
      '.gmz-hedef{margin-top:10px}.gmz-hedef .ust{display:flex;justify-content:space-between;gap:8px;font-size:14px;line-height:1.4}',
      '.gmz-hedef .ust b{font-weight:800}.gmz-cubuk{height:9px;border-radius:5px;background:rgba(255,255,255,.08);overflow:hidden;margin-top:4px}',
      '.gmz-cubuk i{display:block;height:100%;border-radius:5px;background:var(--gmz-renk,#5d6ee8)}.gmz-cubuk i.tam{background:#52c58a}',
      '.gmz-merdiven{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;margin-top:12px}',
      '.gmz-merdiven button{display:block;min-width:0;padding:0 0 6px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:#0f1531;color:inherit;font:inherit;overflow:hidden;text-align:center}',
      '.gmz-merdiven button.simdi{border-color:#f2c46d;box-shadow:0 0 0 1px #f2c46d}.gmz-merdiven button.yok .gmz-svg{filter:grayscale(.85) brightness(.75)}',
      '.gmz-merdiven .k{display:block;line-height:0;aspect-ratio:360/230}.gmz-merdiven b{display:block;font-size:11.5px;line-height:1.25;padding:5px 3px 0;overflow-wrap:anywhere}',
      '.gmz-merdiven small{display:block;font-size:10.5px;opacity:.7;line-height:1.2}',
      '.gmz-gb{display:flex;align-items:center;gap:12px;width:100%;text-align:left;padding:10px;border-radius:14px;border:1px solid var(--gmz-trim,#2a3045);background:linear-gradient(135deg,rgba(255,255,255,.06),rgba(255,255,255,.01));color:inherit;font:inherit;margin-top:6px;min-height:72px}',
      '.gmz-gb .orta{flex:1;min-width:0}.gmz-gb b{display:block;font-size:17px;line-height:1.25;overflow-wrap:anywhere}.gmz-gb small{display:block;font-size:13px;opacity:.8;margin-top:2px}',
      '.gmz-gby{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px;margin-top:8px}',
      '.gmz-gby button{display:flex;align-items:center;gap:8px;min-width:0;min-height:56px;text-align:left;padding:8px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit}',
      '.gmz-gby .orta{flex:1;min-width:0}.gmz-gby b{display:block;font-size:13.5px;line-height:1.25;overflow-wrap:anywhere}.gmz-gby small{display:block;font-size:11.5px;opacity:.75;line-height:1.3;margin-top:1px;overflow-wrap:anywhere}',
      '.gmz-yuz{display:inline-block;border-radius:50%;background:rgba(255,255,255,.1);flex:none}.gmz-gb .portre,.gmz-gby .portre{flex:none}',
      '.gmz-sayi{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;margin-top:8px}',
      '.gmz-sayi div{background:rgba(255,255,255,.05);border:1px solid var(--line2,#2a3045);border-radius:12px;padding:9px 3px;text-align:center;min-width:0}',
      '.gmz-sayi b{display:block;font-size:19px;line-height:1.15}.gmz-sayi small{display:block;font-size:11.5px;opacity:.8;line-height:1.25;margin-top:3px;overflow-wrap:anywhere}',
      '.gmz-kat{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:8px}',
      '.gmz-kat button{display:flex;flex-direction:column;align-items:flex-start;gap:3px;min-height:76px;min-width:0;padding:11px 12px;border-radius:14px;border:1px solid var(--line2,#2a3045);background:var(--bg,#151a28);color:inherit;font:inherit;text-align:left}',
      '.gmz-kat i{font-style:normal;font-size:11px;font-weight:900;letter-spacing:.6px;opacity:.6}.gmz-kat b{font-size:15px;line-height:1.3;overflow-wrap:anywhere}.gmz-kat small{font-size:12.5px;opacity:.78;line-height:1.35;overflow-wrap:anywhere}',
      '.gmz-satir{display:flex;align-items:flex-start;gap:10px;width:100%;text-align:left;padding:10px 2px;border:0;border-bottom:1px solid var(--line2,#2a3045);background:none;color:inherit;font:inherit;min-height:48px}',
      '.gmz-satir:last-child{border-bottom:0}.gmz-satir .orta{flex:1;min-width:0}.gmz-satir b{font-size:15px;line-height:1.35;overflow-wrap:anywhere}',
      '.gmz-satir small{display:block;font-size:13px;opacity:.8;margin-top:2px;line-height:1.4;overflow-wrap:anywhere}.gmz-satir .sag{flex:none;font-size:13px;font-weight:800;text-align:right}',
      '.gmz-don{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;margin-top:10px}',
      '.gmz-don button{display:block;min-width:0;padding:0 0 7px;border-radius:12px;border:1px solid var(--line2,#2a3045);background:#0f1531;color:inherit;font:inherit;overflow:hidden;text-align:center}',
      '.gmz-don button.simdi{box-shadow:0 0 0 2px #52c58a}.gmz-don button.bak{box-shadow:0 0 0 2px #f2c46d}',
      '.gmz-don .k{display:block;line-height:0;aspect-ratio:360/230}.gmz-don b{display:block;font-size:12px;padding:5px 2px 0;line-height:1.2}.gmz-don small{display:block;font-size:10.5px;opacity:.7;line-height:1.2}',
      '.gmz-not{padding:10px 12px;border-radius:12px;background:rgba(93,140,230,.1);border:1px solid rgba(93,140,230,.35);font-size:14px;line-height:1.5;margin-top:10px}',
      '.gmz-serit{display:flex;gap:8px;overflow-x:auto;padding:4px 0 6px;-webkit-overflow-scrolling:touch;scrollbar-width:none;margin-top:6px}.gmz-serit::-webkit-scrollbar{display:none}',
      '.gmz-serit button{flex:none;width:132px;padding:0 0 8px;border-radius:14px;border:1px solid var(--line2,#2a3045);background:#0f1531;color:inherit;font:inherit;overflow:hidden;text-align:center}',
      '.gmz-serit button.simdi{border-color:#f2c46d}.gmz-serit .k{display:block;line-height:0;aspect-ratio:360/230}.gmz-serit b{display:block;font-size:14px;padding:6px 4px 0}.gmz-serit small{display:block;font-size:11.5px;opacity:.75;line-height:1.3;padding:0 4px}',
      '.gmz-pkart{display:block;width:100%;padding:0;border-radius:18px;overflow:hidden;border:1px solid rgba(255,255,255,.14);background:#0f1531;color:#fff;font:inherit;text-align:left;margin:0 0 12px}',
      '.gmz-pkart.p1{border-color:#d0915a}.gmz-pkart.p2{border-color:#dfe5f3}.gmz-pkart.p3{border-color:#f2c46d;box-shadow:0 0 0 1px rgba(242,196,109,.5)}',
      '.gmz-pkart .k{display:block;line-height:0;aspect-ratio:360/186;overflow:hidden}.gmz-pkart .alt{display:flex;align-items:center;gap:10px;padding:10px 14px 12px}',
      '.gmz-pkart .orta{flex:1;min-width:0}.gmz-pkart b{display:block;font-size:16px;line-height:1.25;overflow-wrap:anywhere}.gmz-pkart small{display:block;font-size:13px;opacity:.82;margin-top:2px;line-height:1.35}.gmz-pkart .ok{font-size:22px;opacity:.7}'
    ].join('');
    document.head.appendChild(s);
  }

  /* ------------------------------------------------ EKRAN */
  function ekran(pid) {
    css(); S.onK = null; S.onP = null;
    if (typeof iskelet === 'function') iskelet('Genel Merkez', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true });
    return rpc('genel_merkez_panel', { p_parti: pid == null ? null : +pid }).then(ciz)
      .catch(function (err) { var x = ic(); if (x) x.innerHTML = '<div class="kart"><div class="bos">' + esc(hata(err)) + '</div></div>'; });
  }

  function sahne(v) {
    var k = S.onK || n(v.kademe.no), p = S.onP == null ? n(v.prestij.seviye) : S.onP, pa = v.parti, on = S.onK != null || S.onP != null;
    return '<section class="gmz-sahne p' + p + '" id="gmzSahne">' +
      (on ? '<div class="gmz-onizle"><span>Önizleme: ' + esc(KADEME[k]) + ' · ' + esc(PRESTIJ[p]) + '</span><button type="button" id="gmzGercek">Gerçek görünüm</button></div>' : '') +
      '<div class="gmz-gok">' + bina(k, p, pa.renk, pa.kisa) + '</div>' +
      '<div class="gmz-levha">' + amb(pa, 48) + '<div class="orta"><h2>' + esc(pa.kisa) + ' Genel Merkezi</h2><small>' + esc(pa.ad) + (v.sehir ? ' · ' + esc(v.sehir.ad) : '') + '</small></div></div>' +
      '<div class="gmz-cipler"><span class="gmz-cip">' + esc(v.kademe.ad) + '</span>' +
      (n(v.prestij.seviye) ? '<span class="gmz-cip d' + n(v.prestij.seviye) + '">★ ' + esc(PRESTIJ[n(v.prestij.seviye)]) + '</span>' : '') +
      (v.rol && ROL[v.rol] ? '<span class="gmz-cip rol">' + esc(ROL[v.rol]) + '</span>' : '') + '</div></section>';
  }

  function hedef(ad, var_, gerek) {
    var o = gerek ? Math.min(100, Math.round(var_ * 100 / gerek)) : 100, tam = var_ >= gerek;
    return '<div class="gmz-hedef"><div class="ust"><span>' + esc(ad) + '</span><b>' + var_ + ' / ' + gerek + (tam ? ' ✓' : '') + '</b></div><div class="gmz-cubuk"><i class="' + (tam ? 'tam' : '') + '" style="width:' + Math.max(3, o) + '%"></i></div></div>';
  }
  function kademeKart(v) {
    var kd = v.kademe, o = kd.olcu || {}, sn = kd.sonraki, pa = v.parti, p = n(v.prestij.seviye);
    var h = '<div class="kart"><h3 class="gmz-bas">Bina: ' + esc(kd.ad) + '</h3>' +
      '<p class="alt" style="margin:0">Genel merkez binası satın alınmaz; partinin örgüt gücüyle büyür. Parti küçülürse bina da küçülür.</p>';
    if (sn) h += '<p style="margin:10px 0 0;font-size:15px"><b>Sıradaki: ' + esc(sn.ad) + '</b></p>' +
      hedef('Aktif üye (son 14 gün)', n(o.uye), n(sn.uye)) + hedef('İl teşkilatı', n(o.il), n(sn.il)) + hedef('Görevdeki il başkanı', n(o.il_baskani), n(sn.il_baskani)) +
      '<p class="kucuk" style="margin:8px 0 0">Üç hedef birlikte tamamlanınca bina kendiliğinden büyür.' + (v.gm && n(o.il_baskani) < n(sn.il_baskani) ? ' İl başkanı eksiğini İl Başkanlıkları ekranından kapatabilirsin.' : '') + '</p>';
    else h += '<p style="margin:10px 0 0;font-size:15px"><b>En büyük kademeye ulaşıldı.</b> ' + n(o.uye) + ' aktif üye, ' + n(o.il) + ' il teşkilatı, ' + n(o.il_baskani) + ' il başkanı.</p>';
    h += '<div class="gmz-merdiven">' + (kd.liste || []).map(function (x) {
      var no = n(x.no);
      return '<button type="button" data-gmzk="' + no + '" class="' + (no === n(kd.no) ? 'simdi' : no > n(kd.no) ? 'yok' : '') + '"><span class="k">' + bina(no, p, pa.renk, '') + '</span><b>' + esc(x.ad) + '</b><small>' + (no === n(kd.no) ? 'şimdi' : no < n(kd.no) ? 'geçildi' : n(x.uye) + ' üye') + '</small></button>';
    }).join('') + '</div><p class="kucuk" style="margin:8px 0 0">Bir kademeye dokun, bina nasıl görünecek gör.</p></div>';
    return h;
  }
  function kisi(x, renk, boy) { return yuz(x.kad, renk, boy); }
  function yonetimKart(v) {
    var y = v.yonetim || {}, pa = v.parti, gby = y.gby || [];
    var h = '<div class="kart"><h3 class="gmz-bas">Yönetim katı</h3>';
    h += y.gb ? '<button type="button" class="gmz-gb" data-kart="' + esc(y.gb.kad) + '">' + kisi(y.gb, pa.renk, 54) + '<span class="orta"><b>' + esc(y.gb.ad) + '</b><small>Genel Başkan' + (y.vekil ? ' · vekili ' + esc(y.vekil.ad) : '') + '</small></span></button>'
      : '<p class="alt" style="margin:4px 0 0">Genel başkanlık makamı boş' + (y.vekil ? '; vekâleten ' + esc(y.vekil.ad) + ' yürütüyor.' : '.') + '</p>';
    if (gby.length) h += '<div class="gmz-gby">' + gby.map(function (x) {
      var alt = x.gorev || (x.alanlar || []).map(function (a) { return ALAN[a] || a; }).join(', ') || 'Genel Başkan Yardımcısı';
      return '<button type="button" data-kart="' + esc(x.kad) + '">' + kisi(x, pa.renk, 36) + '<span class="orta"><b>' + esc(x.ad) + '</b><small>' + esc(alt) + '</small></span></button>';
    }).join('') + '</div>';
    else h += '<p class="alt" style="margin:8px 0 0">Henüz genel başkan yardımcısı atanmadı.</p>';
    h += '<p class="kucuk" style="margin:10px 0 0">Merkez Yönetim Kurulu: ' + ((y.gb ? 1 : 0) + gby.length) + ' kişi' + (n(y.disiplin) ? ' · Disiplin Kurulu: ' + n(y.disiplin) + ' asil üye' : '') + '</p></div>';
    return h;
  }
  function sayiKart(v) {
    var s = v.sayilar || {}, pa = v.parti, kutu = function (d, ad) { return '<div><b>' + d + '</b><small>' + ad + '</small></div>'; };
    return '<div class="kart"><h3 class="gmz-bas">Sayılarla ' + esc(pa.kisa) + '</h3><div class="gmz-sayi">' +
      kutu(n(s.uye), 'üye') + kutu(n(s.aktif_24s), 'son 24 saat aktif') + kutu('+' + n(s.yeni_7g), 'bu hafta katılan') + kutu(n(s.il), 'il teşkilatı') +
      kutu(n(s.il_baskani), 'il başkanı') + kutu(n(s.il_baskani_secilmis), 'kongrede seçilen') + kutu(n(s.mv), 'milletvekili') + kutu(n(s.belediye), 'belediye') +
      '</div>' + (pa.kurulus ? '<p class="kucuk" style="margin:10px 0 0">Kuruluş: ' + esc(gun(pa.kurulus)) + (v.sehir ? ' · Genel merkez ili: ' + esc(v.sehir.ad) : '') + '</p>' : '') + '</div>';
  }
  function katKart(v) {
    var pa = v.parti, ls = [];
    ls.push(['parti', 'ZEMİN KAT', 'Parti sayfası', 'Üyeler, tüzük, bağış, üyelik']);
    if (g('ilBaskanliklariAc') || g('ilMasasiAc')) ls.push(['il', '1. KAT', v.gm ? 'İl Başkanlıkları' : 'İl Başkanlığı', v.gm ? '81 il karnesi, atama, gelen yazılar' : 'İl örgütü masası ve il kongresi']);
    if (g('adayVitriniAc')) ls.push(['aday', '2. KAT', 'Aday Vitrini', 'İl il milletvekili adayları']);
    if (v.uyeyim && g('partiDisiplinEkrani')) ls.push(['pdk', '3. KAT', 'Disiplin Kurulu', 'MYK sevki, savunma, karar']);
    return '<div class="kart"><h3 class="gmz-bas">Genel merkez katları</h3><div class="gmz-kat">' + ls.map(function (x) {
      return '<button type="button" data-gmzkat="' + x[0] + '"><i>' + x[1] + '</i><b>' + esc(x[2]) + '</b><small>' + esc(x[3]) + '</small></button>';
    }).join('') + '</div></div>';
  }
  function panoKart(v) {
    var m = (v.mitingler || []).map(function (x) {
      return '<div class="gmz-satir"><div class="orta"><b>' + esc(x.baslik) + '</b><small>' + esc(x.il || '') + ' · ' + esc(zaman(x.bas)) + ' · ' + (x.il_orgut ? 'il örgütü mitingi' : 'genel merkez mitingi') + '</small></div><div class="sag">' + (x.canli ? '<span class="gmz-cip canli">CANLI</span>' : 'Yakında') + '</div></div>';
    }).join('');
    var a = (v.aciklamalar || []).map(function (x) {
      return '<button type="button" class="gmz-satir" data-gmzil="' + n(x.il_id) + '"><div class="orta"><b>' + esc(x.baslik) + '</b><small>' + esc(x.il) + ' İl Başkanlığı · ' + esc(zaman(x.zaman)) + '</small></div><div class="sag" aria-hidden="true">›</div></button>';
    }).join('');
    if (!m && !a) return '<div class="kart"><h3 class="gmz-bas">Pano</h3><p class="alt" style="margin:0">Yaklaşan parti mitingi ve il başkanlığı açıklaması yok.</p></div>';
    return '<div class="kart"><h3 class="gmz-bas">Pano</h3>' + (m ? '<p class="kucuk" style="margin:4px 0 0">Mitingler</p>' + m : '') + (a ? '<p class="kucuk" style="margin:8px 0 0">İl başkanlıklarından</p>' + a : '') + '</div>';
  }
  function donanimKart(v) {
    var pr = v.prestij || {}, pa = v.parti, s = n(pr.seviye), k = n(v.kademe.no), bak = S.onP;
    var h = '<div class="kart" id="gmzDonanim"><h3 class="gmz-bas">İmtiyazlı görünüm</h3>' +
      '<p class="alt" style="margin:0">Üyelerin Genel Merkez Kampanyası’na katkısı binaya donanım kazandırır. Donanım yalnız görünüştür; binayı büyütmez, oy, makam ya da seçim gücü vermez.</p>' +
      '<div class="gmz-don">' + [0, 1, 2, 3].map(function (i) {
        return '<button type="button" data-gmzp="' + i + '" class="' + (i === s ? 'simdi' : '') + (bak === i && i !== s ? ' bak' : '') + '"><span class="k">' + bina(k, i, pa.renk, '') + '</span><b>' + esc(PRESTIJ[i].replace(' Donanım', '')) + '</b><small>' + (i === s ? 'şimdi' : i === 0 ? 'ücretsiz' : n((pr.esik || [])[i - 1]) + ' katkı') + '</small></button>';
      }).join('') + '</div><p class="kucuk" style="margin:8px 0 0" id="gmzDonNe">' + esc(PRESTIJ_NE[bak == null ? s : bak]) + '</p>';
    if (pr.sonraki) {
      var onceki = s > 0 ? n((pr.esik || [])[s - 1]) : 0, o = Math.max(0, Math.min(100, Math.round((n(pr.katki) - onceki) * 100 / Math.max(1, n(pr.sonraki) - onceki))));
      h += '<div class="gmz-hedef"><div class="ust"><span>' + esc(pr.sonraki_ad) + ' için</span><b>' + n(pr.katki) + ' / ' + n(pr.sonraki) + ' katkı</b></div><div class="gmz-cubuk"><i style="width:' + Math.max(3, o) + '%;background:' + TRIM[Math.min(3, s + 1)] + '"></i></div></div>';
    } else h += '<p style="margin:10px 0 0;font-size:15px"><b>En üst donanıma ulaşıldı</b> · ' + n(pr.katki) + ' katkı</p>';
    if (pr.urun_acik) {
      h += '<p class="kucuk" style="margin:8px 0 0">Her katkı parti kasasına ' + tl(pr.tutar) + ' koyar; donanım kazanıldığında bütün üyelere rozet verilir.</p>';
      if (v.uyeyim && g('magazaEkrani')) h += pr.katki_verebilir ? '<button type="button" class="btn altin" id="gmzMagaza" style="margin-top:10px">Mağazada Genel Merkez Kampanyası</button>'
        : '<div class="gmz-not">Katkı verebilmek için hesabın en az ' + n(pr.hesap_gun) + ' günlük olmalı.</div>';
    } else h += '<div class="gmz-not">Genel Merkez Kampanyası yakında mağazada. O zamana kadar donanımları yukarıdan önizleyebilirsin.</div>';
    if ((pr.liste || []).length) h += '<p class="kucuk" style="margin:12px 0 0">En çok katkı verenler</p>' + pr.liste.map(function (x, i) {
      return '<button type="button" class="gmz-satir" data-kart="' + esc(x.kad) + '"><div class="orta"><b>' + (i + 1) + '. ' + esc(x.ad) + '</b></div><div class="sag">' + n(x.adet) + ' katkı</div></button>';
    }).join('');
    return h + '</div>';
  }
  function partilerKart(v) {
    var ls = v.partiler || []; if (ls.length < 2) return '';
    return '<div class="kart"><h3 class="gmz-bas">Bütün genel merkezler</h3><div class="gmz-serit">' + ls.map(function (x) {
      return '<button type="button" data-gmzparti="' + n(x.id) + '" class="' + (n(x.id) === n(v.parti.id) ? 'simdi' : '') + '"><span class="k">' + bina(x.kademe, x.prestij, x.renk, x.kisa) + '</span><b style="color:' + esc(karis(x.renk, '#ffffff', .35)) + '">' + esc(x.kisa) + '</b><small>' + esc(KADEME[n(x.kademe)] || '') + (n(x.prestij) ? ' · ' + esc(PRESTIJ[n(x.prestij)].replace(' Donanım', '')) : '') + '<br>' + n(x.uye) + ' aktif üye</small></button>';
    }).join('') + '</div></div>';
  }

  function ciz(v) {
    S.v = v; var x = ic(); if (!x) return;
    css();
    var p = n(v.prestij.seviye);
    x.innerHTML = '<div id="gmzKok" style="--gmz-trim:' + TRIM[p] + ';--gmz-renk:' + esc(karis(v.parti.renk, '#ffffff', .15)) + '">' +
      sahne(v) + kademeKart(v) + yonetimKart(v) + sayiKart(v) + katKart(v) + panoKart(v) + donanimKart(v) + partilerKart(v) + '</div>';
    bagla(x, v);
    try { if (typeof portreleriTazele === 'function') portreleriTazele(x); } catch (_) {}
  }
  function sahneYenile(v) {
    var eski = document.getElementById('gmzSahne'); if (!eski) return;
    var d = document.createElement('div'); d.innerHTML = sahne(v); eski.parentNode.replaceChild(d.firstChild, eski);
    var b = document.getElementById('gmzGercek'); if (b) b.onclick = function () { S.onK = null; S.onP = null; sahneYenile(v); donanimIsaret(v); };
    try { document.getElementById('gmzSahne').scrollIntoView({ block: 'start', behavior: 'smooth' }); } catch (_) {}
  }
  function donanimIsaret(v) {
    var s = n(v.prestij.seviye);
    document.querySelectorAll('[data-gmzp]').forEach(function (b) { b.classList.toggle('bak', S.onP != null && +b.dataset.gmzp === S.onP && S.onP !== s); });
    var ne = document.getElementById('gmzDonNe'); if (ne) ne.textContent = PRESTIJ_NE[S.onP == null ? s : S.onP];
  }
  function bagla(x, v) {
    var pid = n(v.parti.id);
    x.querySelectorAll('[data-kart]').forEach(function (b) { b.onclick = function () { kartAc(b.dataset.kart); }; });
    x.querySelectorAll('[data-gmzk]').forEach(function (b) { b.onclick = function () { var k = +b.dataset.gmzk; S.onK = k === n(v.kademe.no) ? null : k; sahneYenile(v); }; });
    x.querySelectorAll('[data-gmzp]').forEach(function (b) { b.onclick = function () { var p = +b.dataset.gmzp; S.onP = p === n(v.prestij.seviye) ? null : p; sahneYenile(v); donanimIsaret(v); }; });
    x.querySelectorAll('[data-gmzparti]').forEach(function (b) { b.onclick = function () { var id = +b.dataset.gmzparti; if (id !== pid) ac(function () { ekran(id); }); }; });
    x.querySelectorAll('[data-gmzil]').forEach(function (b) { b.onclick = function () { var f = g('ilMasasiAc'); if (f) f(pid, +b.dataset.gmzil); }; });
    x.querySelectorAll('[data-gmzkat]').forEach(function (b) { b.onclick = function () {
      var ne = b.dataset.gmzkat, f;
      if (ne === 'parti') { if (typeof partiDetay === 'function') ac(function () { partiDetay(pid); }); }
      else if (ne === 'il') { if (v.gm && (f = g('ilBaskanliklariAc'))) f(); else if (v.uyeyim && (f = g('ilBaskanligiGiris'))) f(); else if ((f = g('ilMasasiAc'))) f(pid, null); }
      else if (ne === 'aday') { if ((f = g('adayVitriniAc'))) f(); }
      else if (ne === 'pdk') { if ((f = g('partiDisiplinEkrani'))) ac(function () { f(pid); }); }
    }; });
    var mg = document.getElementById('gmzMagaza'); if (mg) mg.onclick = function () { ac(window.magazaEkrani); };
  }

  /* ------------------------------------------------ girişler */
  function partiKart(v) {
    var p = n(v.prestij.seviye), pa = v.parti;
    return '<button type="button" class="gmz-pkart p' + p + '" id="gmzParti"><span class="k">' + bina(v.kademe.no, p, pa.renk, pa.kisa) + '</span><span class="alt"><span class="orta"><b>' + esc(pa.kisa) + ' Genel Merkezi</b>' +
      '<small>' + esc(v.kademe.ad) + (p ? ' · ' + esc(PRESTIJ[p]) : '') + (v.sehir ? ' · ' + esc(v.sehir.ad) : '') + '</small></span><span class="ok" aria-hidden="true">›</span></span></button>';
  }
  if (typeof partiDetay === 'function' && !partiDetay._gmz) {
    var eskiParti = partiDetay;
    var yeniParti = async function (id) {
      var r = await eskiParti.apply(this, arguments);
      try {
        var kok = ic(), v = await rpc('genel_merkez_panel', { p_parti: +id });
        if (!kok || ic() !== kok || !v || !v.parti || kok.querySelector('#gmzParti')) return r;
        css();
        var ilk = kok.querySelector('.kart'), kap = document.createElement('div'); kap.innerHTML = partiKart(v);
        var el = kap.firstChild;
        if (ilk && ilk.parentNode) ilk.parentNode.insertBefore(el, ilk.nextSibling); else kok.appendChild(el);
        el.onclick = function () { ac(function () { S.onK = null; S.onP = null; if (typeof iskelet === 'function') iskelet('Genel Merkez', '<div class="yukleniyor">Yükleniyor…</div>', { geri: true }); ciz(v); }); };
      } catch (_) {}
      return r;
    };
    yeniParti._gmz = true;
    if (eskiParti._m2) yeniParti._m2 = true;
    window.partiDetay = partiDetay = yeniParti;
  }

  window.gmzEkrani = ekran;
  window.genelMerkezAc = function (pid) { ac(function () { ekran(pid); }); };
})();
