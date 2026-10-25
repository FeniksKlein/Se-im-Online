/*
 * SEÇİM SİMÜLASYONU ONLINE — MÜZAYEDE EVİ (25.10.2026)
 * Koleksiyon eserleri için açık artırma: pey ver, kazan, sergile, yeniden sat,
 * Devlet Müzesi'ne bağışla. Bütün para ve değer hesabı sunucuda
 * (public.muzayede_* RPC'leri); bu dosya yalnız arayüzdür.
 */
(function () {
  'use strict';
  if (window.MUZAYEDE) return;
  window.MUZAYEDE = true;

  var M = { sekme: 'salon', salon: null, kol: null, sira: null, lot: null, lotId: null, zamanlayici: null, tazele: null, filtre: 'hepsi' };

  /* ---------- yardımcılar ---------- */
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function sayi(v) { var n = Number(v); return isFinite(n) ? n : 0; }
  function tl(n) { return sayi(n).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' ₺'; }
  function kisa(n) { n = sayi(n); var a = Math.abs(n); if (a >= 1e6) return (n / 1e6).toLocaleString('tr-TR', { maximumFractionDigits: 2 }) + ' Mn ₺'; if (a >= 1e5) return (n / 1e3).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' B ₺'; return tl(n); }
  function suan() { try { return typeof simdi === 'function' ? simdi() : Date.now(); } catch (e) { return Date.now(); } }
  function geri(ms) {
    if (ms <= 0) return 'Bitti';
    var s = Math.floor(ms / 1000), g = Math.floor(s / 86400), sa = Math.floor(s % 86400 / 3600), dk = Math.floor(s % 3600 / 60), sn = s % 60;
    var iki = function (n) { return String(n).padStart(2, '0'); };
    if (g > 0) return g + 'g ' + iki(sa) + ':' + iki(dk);
    return iki(sa) + ':' + iki(dk) + ':' + iki(sn);
  }
  function tarih(s) { try { return new Date(s).toLocaleString('tr-TR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }); } catch (e) { return ''; } }
  function hata(err) { var m = err && err.message || String(err || ''); toast(typeof hataCevir === 'function' ? hataCevir(m) : m, true); }
  function rpc(ad, args) { return API.rpc(ad, args || {}); }
  function aktifMi() { return !!document.querySelector('#icerik .mz'); }
  var NAD = { siradan: 'Sıradan', nadir: 'Nadir', cok_nadir: 'Çok nadir', efsanevi: 'Efsanevi' };
  var NAD_RENK = { siradan: '#8fa0c3', nadir: '#4aa3ff', cok_nadir: '#b06cff', efsanevi: '#f2c14e' };

  /* ---------- eser çizimleri (kurgusal, her motif için SVG) ---------- */
  function ac(h, t) { // rengi aç/koyulaştır
    h = String(h || '#c9a227').replace('#', ''); if (h.length !== 6) h = 'c9a227';
    var n = parseInt(h, 16), r = n >> 16 & 255, g = n >> 8 & 255, b = n & 255, k = t < 0 ? 0 : 255, o = Math.abs(t);
    return '#' + [r, g, b].map(function (x) { return Math.round(x + (k - x) * o).toString(16).padStart(2, '0'); }).join('');
  }
  var svgSay = 0;
  function eserSvg(e, cls) {
    var r = e && e.renk || '#c9a227', m = e && e.motif || 'tablo_deniz', id = 'mzg' + (++svgSay), A = ac(r, 0.35), K = ac(r, -0.45), K2 = ac(r, -0.7);
    var cer = '<rect x="6" y="6" width="108" height="108" rx="4" fill="url(#' + id + 'c)"/><rect x="13" y="13" width="94" height="94" fill="' + K2 + '"/>';
    var tanim = '<defs><linearGradient id="' + id + 'c" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f6dc8c"/><stop offset=".5" stop-color="#b8862b"/><stop offset="1" stop-color="#f1d27a"/></linearGradient>' +
      '<linearGradient id="' + id + 'g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + A + '"/><stop offset="1" stop-color="' + r + '"/></linearGradient>' +
      '<radialGradient id="' + id + 'm" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#fff" stop-opacity=".9"/><stop offset=".25" stop-color="' + A + '"/><stop offset="1" stop-color="' + K + '"/></radialGradient></defs>';
    var ic = '';
    switch (m) {
      case 'tablo_deniz':
        ic = cer + '<rect x="13" y="13" width="94" height="56" fill="url(#' + id + 'g)"/><circle cx="78" cy="40" r="10" fill="#fff3c4" opacity=".9"/>' +
          '<path d="M13 69h94v38H13z" fill="' + K + '"/><path d="M13 72c12-4 22 4 34 0s22 4 34 0 18 2 26 0" stroke="' + A + '" stroke-width="2" fill="none" opacity=".7"/>' +
          '<path d="M13 84c14-3 24 3 36 0s22 3 34 0 16 2 24 0" stroke="' + A + '" stroke-width="1.5" fill="none" opacity=".45"/>' +
          '<path d="M30 66l14-22v22z" fill="#f5f0e6"/><path d="M26 66h24l-4 6H30z" fill="#3b2a1c"/><path d="M84 58h10v11H84zM86 50h6v8h-6z" fill="' + K2 + '" opacity=".85"/>';
        break;
      case 'tablo_portre':
        ic = cer + '<rect x="13" y="13" width="94" height="94" fill="url(#' + id + 'g)"/><circle cx="60" cy="50" r="15" fill="' + K + '"/>' +
          '<path d="M30 107c2-22 14-34 30-34s28 12 30 34z" fill="' + K + '"/><path d="M45 47c2-10 8-14 15-14s13 4 15 14c-6-5-24-5-30 0z" fill="' + K2 + '"/>';
        break;
      case 'afis':
        ic = '<rect x="20" y="8" width="80" height="104" rx="3" fill="#efe4c8"/><rect x="20" y="8" width="80" height="30" fill="' + r + '"/>' +
          '<g fill="#fff3c4"><path d="M60 15l3 7 7 .6-5.4 4.6 1.7 7L60 30.4 53.7 34.2l1.7-7L50 22.6l7-.6z"/></g>' +
          '<rect x="30" y="46" width="60" height="7" rx="2" fill="' + K + '"/><rect x="34" y="58" width="52" height="4" rx="2" fill="' + K + '" opacity=".55"/>' +
          '<rect x="34" y="66" width="44" height="4" rx="2" fill="' + K + '" opacity=".55"/><circle cx="60" cy="90" r="12" fill="none" stroke="' + r + '" stroke-width="3"/><path d="M55 90l4 4 7-8" stroke="' + r + '" stroke-width="3" fill="none"/>';
        break;
      case 'pusula':
        ic = '<rect x="16" y="10" width="88" height="100" rx="3" fill="#f3ecdc"/><rect x="16" y="10" width="88" height="14" fill="' + r + '"/>';
        for (var i = 0; i < 4; i++) ic += '<rect x="24" y="' + (32 + i * 19) + '" width="72" height="14" rx="2" fill="none" stroke="' + K + '" stroke-width="1.4" opacity=".7"/><circle cx="34" cy="' + (39 + i * 19) + '" r="4" fill="none" stroke="' + K + '" stroke-width="1.4"/><rect x="44" y="' + (37 + i * 19) + '" width="40" height="3" rx="1.5" fill="' + K + '" opacity=".5"/>';
        break;
      case 'sandik':
        ic = '<path d="M20 44h80v56a4 4 0 0 1-4 4H24a4 4 0 0 1-4-4z" fill="' + r + '"/><path d="M14 36h92v12H14z" fill="' + K + '"/><rect x="44" y="40" width="32" height="4" rx="2" fill="#1a120c"/>' +
          '<path d="M20 60h80M20 80h80" stroke="' + K + '" stroke-width="2" opacity=".5"/><rect x="54" y="66" width="12" height="14" rx="2" fill="#f1d27a"/><circle cx="60" cy="72" r="2" fill="#5a3d0d"/>';
        break;
      case 'davetiye':
        ic = '<rect x="14" y="20" width="92" height="80" rx="4" fill="#fbf6ea"/><rect x="19" y="25" width="82" height="70" rx="2" fill="none" stroke="#c9a227" stroke-width="2"/>' +
          '<rect x="34" y="40" width="52" height="5" rx="2" fill="' + K + '"/><rect x="40" y="52" width="40" height="3" rx="1.5" fill="' + K + '" opacity=".5"/><rect x="40" y="60" width="40" height="3" rx="1.5" fill="' + K + '" opacity=".5"/>' +
          '<circle cx="60" cy="80" r="9" fill="#b71c1c"/><circle cx="60" cy="80" r="5" fill="none" stroke="#ffcdd2" stroke-width="1.5"/>';
        break;
      case 'mazbata':
        ic = '<path d="M24 16h72v84H24z" fill="#efe2c2"/><path d="M18 14h84a6 6 0 0 1 0 12H18a6 6 0 0 1 0-12zM18 94h84a6 6 0 0 1 0 12H18a6 6 0 0 1 0-12z" fill="#d9c79c"/>' +
          '<rect x="34" y="38" width="52" height="4" rx="2" fill="' + K + '"/><rect x="34" y="48" width="46" height="3" rx="1.5" fill="' + K + '" opacity=".5"/><rect x="34" y="56" width="50" height="3" rx="1.5" fill="' + K + '" opacity=".5"/>' +
          '<circle cx="74" cy="78" r="11" fill="' + r + '"/><path d="M70 88l-3 10 7-4 7 4-3-10" fill="' + r + '"/><circle cx="74" cy="78" r="6" fill="none" stroke="#ffd7d7" stroke-width="1.4"/>';
        break;
      case 'defter':
        ic = '<rect x="22" y="12" width="76" height="96" rx="5" fill="' + r + '"/><rect x="22" y="12" width="12" height="96" rx="4" fill="' + K + '"/><rect x="40" y="22" width="50" height="76" rx="3" fill="none" stroke="#f1d27a" stroke-width="2"/>' +
          '<path d="M65 44l4 9 10 1-7 6 2 10-9-5-9 5 2-10-7-6 10-1z" fill="#f1d27a"/><rect x="92" y="52" width="10" height="16" rx="2" fill="#f1d27a"/>';
        break;
      case 'sikke':
        ic = '<circle cx="60" cy="60" r="46" fill="url(#' + id + 'm)"/><circle cx="60" cy="60" r="46" fill="none" stroke="' + K + '" stroke-width="3"/>' +
          '<circle cx="60" cy="60" r="38" fill="none" stroke="' + K + '" stroke-width="1.5" stroke-dasharray="2 3" opacity=".7"/>' +
          '<path d="M46 72c0-12 6-22 16-24 8-2 14 4 13 11-1 6-7 8-11 6 5 6 2 12-4 13-6 1-14-1-14-6z" fill="' + K + '" opacity=".75"/><circle cx="66" cy="54" r="2" fill="' + A + '"/>';
        break;
      case 'pul':
        ic = '<rect x="18" y="14" width="84" height="92" fill="#fbf7ee"/>';
        for (var p = 0; p < 9; p++) { ic += '<circle cx="' + (18 + p * 10.5) + '" cy="14" r="3" fill="#0e1530"/><circle cx="' + (18 + p * 10.5) + '" cy="106" r="3" fill="#0e1530"/>'; }
        for (var q = 0; q < 10; q++) { ic += '<circle cx="18" cy="' + (14 + q * 10.2) + '" r="3" fill="#0e1530"/><circle cx="102" cy="' + (14 + q * 10.2) + '" r="3" fill="#0e1530"/>'; }
        ic += '<rect x="26" y="22" width="68" height="62" fill="' + r + '"/><path d="M34 66l26-26 26 26z" fill="' + A + '" opacity=".8"/><circle cx="76" cy="36" r="7" fill="#fff3c4"/>' +
          '<rect x="30" y="90" width="40" height="5" rx="2" fill="' + K + '"/><text x="90" y="96" font-size="9" font-weight="700" fill="' + K + '" text-anchor="end" font-family="sans-serif">25</text>';
        break;
      case 'ibrik':
        ic = '<path d="M48 26h24l-3 10c12 6 18 18 16 34-2 18-12 30-25 30S37 88 35 70c-2-16 4-28 16-34z" fill="url(#' + id + 'm)"/>' +
          '<path d="M84 50c10 0 14 8 10 16l-10 12" stroke="' + K + '" stroke-width="4" fill="none"/><path d="M36 54L20 40l2-4 18 12" fill="' + K + '"/><rect x="50" y="18" width="20" height="8" rx="3" fill="' + K + '"/>' +
          '<path d="M44 66c6 6 26 6 32 0" stroke="' + A + '" stroke-width="2" fill="none" opacity=".7"/>';
        break;
      case 'tabak':
        ic = '<circle cx="60" cy="60" r="48" fill="#f7f4ee"/><circle cx="60" cy="60" r="48" fill="none" stroke="' + r + '" stroke-width="5"/><circle cx="60" cy="60" r="30" fill="none" stroke="' + r + '" stroke-width="2"/>' +
          '<path d="M60 40c6 6 6 14 0 20-6-6-6-14 0-20zM60 60c8-2 14 2 16 8-8 2-14-2-16-8zM60 60c-8-2-14 2-16 8 8 2 14-2 16-8z" fill="#c62828"/><path d="M60 60v18" stroke="#2e7d32" stroke-width="2.5"/>';
        break;
      case 'vazo':
        ic = '<path d="M46 14h28v8c-2 4-4 6-4 10 14 8 22 22 20 40-2 20-14 34-30 34S32 92 30 72c-2-18 6-32 20-40 0-4-2-6-4-10z" fill="url(#' + id + 'm)"/>' +
          '<path d="M36 64c10 8 38 8 48 0" stroke="#f1d27a" stroke-width="2.5" fill="none"/><path d="M38 78c10 6 34 6 44 0" stroke="#f1d27a" stroke-width="1.5" fill="none" opacity=".7"/>';
        break;
      case 'zarf':
        ic = '<path d="M36 30h48l-6 50a8 8 0 0 1-8 7H50a8 8 0 0 1-8-7z" fill="url(#' + id + 'm)"/><path d="M42 94h36l6 10H36z" fill="' + K + '"/><rect x="56" y="86" width="8" height="9" fill="' + K + '"/>' +
          '<circle cx="60" cy="52" r="5" fill="#c62828"/><circle cx="48" cy="62" r="4" fill="#2e7d32"/><circle cx="72" cy="62" r="4" fill="#2e7d32"/><path d="M38 40h44" stroke="#fff3c4" stroke-width="2" opacity=".7"/>';
        break;
      case 'saat':
        ic = '<path d="M60 8a6 6 0 0 1 6 6v6h-12v-6a6 6 0 0 1 6-6z" fill="' + K + '"/><circle cx="60" cy="66" r="44" fill="url(#' + id + 'm)"/><circle cx="60" cy="66" r="35" fill="#fbf7ee"/>';
        for (var s = 0; s < 12; s++) { var aa = s * Math.PI / 6; ic += '<line x1="' + (60 + Math.sin(aa) * 29).toFixed(1) + '" y1="' + (66 - Math.cos(aa) * 29).toFixed(1) + '" x2="' + (60 + Math.sin(aa) * 33).toFixed(1) + '" y2="' + (66 - Math.cos(aa) * 33).toFixed(1) + '" stroke="#1b2140" stroke-width="' + (s % 3 ? 1.4 : 2.6) + '"/>'; }
        ic += '<path d="M60 66V44M60 66l14 8" stroke="#1b2140" stroke-width="3" stroke-linecap="round"/><circle cx="60" cy="66" r="3" fill="' + r + '"/>';
        break;
      case 'araba':
        ic = '<path d="M10 76c0-8 4-12 12-14l14-14c4-4 8-6 14-6h22c8 0 12 2 16 8l8 12c8 0 14 4 14 14v6H10z" fill="' + r + '"/>' +
          '<path d="M40 50h14v14H30zM60 50h12c4 0 6 2 8 4l6 10H60z" fill="#cfe6ff" opacity=".85"/><rect x="10" y="78" width="100" height="6" rx="3" fill="' + K + '"/>' +
          '<circle cx="34" cy="84" r="12" fill="#1a1a1a"/><circle cx="34" cy="84" r="5" fill="#c0c7d6"/><circle cx="88" cy="84" r="12" fill="#1a1a1a"/><circle cx="88" cy="84" r="5" fill="#c0c7d6"/>' +
          '<rect x="100" y="68" width="8" height="5" rx="2" fill="#fff3c4"/><path d="M14 70h10" stroke="#fff3c4" stroke-width="3"/>';
        break;
      case 'mucevher':
        ic = '<circle cx="60" cy="60" r="40" fill="none" stroke="#f1d27a" stroke-width="5"/>';
        for (var j = 0; j < 12; j++) { var b = j * Math.PI / 6; ic += '<circle cx="' + (60 + Math.cos(b) * 40).toFixed(1) + '" cy="' + (60 + Math.sin(b) * 40).toFixed(1) + '" r="4" fill="#fffbe9"/>'; }
        ic += '<path d="M60 30l22 18-22 44-22-44z" fill="url(#' + id + 'm)"/><path d="M38 48h44M60 30l-8 18 8 44 8-44z" stroke="' + A + '" stroke-width="1.4" fill="none" opacity=".8"/>';
        break;
      case 'hali':
        ic = '<rect x="18" y="14" width="84" height="92" fill="' + r + '"/><rect x="24" y="20" width="72" height="80" fill="none" stroke="#f1d27a" stroke-width="3"/>' +
          '<rect x="30" y="26" width="60" height="68" fill="none" stroke="' + A + '" stroke-width="1.5" stroke-dasharray="4 3"/><path d="M60 38l18 22-18 22-18-22z" fill="' + K + '"/><path d="M60 48l9 12-9 12-9-12z" fill="#f1d27a"/>';
        for (var f = 0; f < 11; f++) ic += '<path d="M' + (21 + f * 8) + ' 106v8M' + (21 + f * 8) + ' 6v8" stroke="#efe4c8" stroke-width="2"/>';
        break;
      default:
        ic = cer + '<rect x="13" y="13" width="94" height="94" fill="url(#' + id + 'g)"/>';
    }
    return '<svg class="' + (cls || 'mz-svg') + '" viewBox="0 0 120 120" role="img" aria-label="' + esc(e && e.ad || 'Eser') + '">' + tanim + ic + '</svg>';
  }
  window.mzEserSvg = eserSvg;

  /* ---------- stiller ---------- */
  function stil() {
    if (document.getElementById('mz-stil')) return;
    var s = document.createElement('style'); s.id = 'mz-stil';
    s.textContent = [
      '.mz{--mz-altin:#f2c14e;--mz-bordo:#5a1a2e;--mz-kart:linear-gradient(170deg,#1d2650,#151c3b)}',
      '.mz-hero{position:relative;overflow:hidden;isolation:isolate;border-radius:24px;padding:18px;margin:0 0 12px;color:#fff;background:linear-gradient(135deg,#7a2440 0%,#3a1430 55%,#1c1433 100%);box-shadow:0 22px 40px -26px #c2456c,inset 0 1px 0 rgba(255,255,255,.18),inset 0 0 0 1px rgba(242,193,78,.22)}',
      '.mz-hero::before{content:"";position:absolute;inset:0;z-index:-1;background:var(--pa-gilos) right -50px top -30px/430px auto no-repeat;opacity:.2}',
      '.mz-hero small{display:block;font-size:12.5px;font-weight:650;color:rgba(255,255,255,.78)}',
      '.mz-hero h2{margin:3px 0 0;padding-right:72px;font:700 28px/1.05 var(--disp);letter-spacing:-.4px;color:#fff}',
      '.mz-hero p{margin:6px 0 0;padding-right:64px;font-size:13px;color:rgba(255,255,255,.82)}',
      '.mz-hero .mz-tokmak{position:absolute;top:14px;right:14px;width:66px;height:66px;border-radius:50%;display:grid;place-items:center;background:radial-gradient(circle at 35% 30%,rgba(255,255,255,.3),rgba(255,255,255,.06) 62%);box-shadow:inset 0 0 0 1.5px rgba(242,193,78,.55),0 0 0 5px rgba(255,255,255,.06)}',
      '.mz-hero .mz-tokmak svg{width:34px;height:34px;color:#f6dc8c}',
      '.mz-veri{display:grid;grid-template-columns:repeat(auto-fit,minmax(86px,1fr));gap:7px;margin-top:14px}',
      '.mz-veri>div{min-width:0;padding:8px 10px;border-radius:13px;background:rgba(5,8,25,.25);box-shadow:inset 0 0 0 1px rgba(255,255,255,.09)}',
      '.mz-veri small{font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
      '.mz-veri b{display:block;margin-top:2px;font:700 18px/1.1 var(--disp);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
      '.mz-sekme{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 0 14px}',
      '.mz-sekme::-webkit-scrollbar{display:none}',
      '.mz-sekme button{flex:0 0 auto;padding:9px 15px;border-radius:999px;background:rgba(29,40,80,.72);box-shadow:inset 0 0 0 1px rgba(164,184,255,.12);color:#c9d1e6;font-weight:650;font-size:14px;min-height:38px}',
      '.mz-sekme button.aktif{background:#f4f6fb;color:#121a3a}',
      '.mz-bas{display:flex;align-items:baseline;justify-content:space-between;gap:8px;margin:18px 2px 9px}',
      '.mz-bas h3{margin:0;font:700 19px/1.2 var(--disp);color:#f2f5ff}',
      '.mz-bas small{color:#8f9bc0;font-size:12.5px}',
      /* çerçeveler */
      '.mz-cerceve{position:relative;display:grid;place-items:center;border-radius:16px;background:radial-gradient(circle at 50% 35%,#2a335c,#121834 75%);box-shadow:inset 0 0 0 1.5px var(--nr,#8fa0c3),0 10px 24px -16px var(--nr,#8fa0c3);overflow:hidden}',
      '.mz-cerceve svg{width:78%;height:78%;filter:drop-shadow(0 8px 10px rgba(0,0,0,.45))}',
      '.mz-cerceve.efsanevi::after{content:"";position:absolute;inset:0;background:linear-gradient(115deg,transparent 35%,rgba(255,236,170,.35) 50%,transparent 65%);transform:translateX(-120%);animation:mzParilti 3.6s ease-in-out infinite}',
      '@keyframes mzParilti{60%,100%{transform:translateX(120%)}}',
      '.mz-nad{display:inline-flex;align-items:center;gap:5px;padding:3px 9px;border-radius:999px;font-size:11.5px;font-weight:750;color:var(--nr);background:color-mix(in srgb,var(--nr) 16%,transparent);box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--nr) 40%,transparent)}',
      '.mz-nad::before{content:"";width:6px;height:6px;border-radius:50%;background:var(--nr)}',
      /* vitrin */
      '.mz-vitrin{all:unset;box-sizing:border-box;cursor:pointer;display:grid;grid-template-columns:132px 1fr;gap:14px;width:100%;padding:12px;border-radius:22px;background:linear-gradient(150deg,#2a1d3f,#161a3a);box-shadow:inset 0 0 0 1px rgba(242,193,78,.28),0 18px 34px -26px #f2c14e;margin-bottom:12px}',
      '.mz-vitrin .mz-cerceve{width:132px;height:150px}',
      '.mz-vitrin .mz-vb small{color:#d9c58a;font-weight:700;font-size:12px}',
      '.mz-vitrin .mz-vb b.ad{display:block;margin:5px 0 4px;font:700 21px/1.1 var(--disp);color:#fff}',
      '.mz-vitrin .mz-vb .alt{font-size:12px;color:#aab4d4}',
      '.mz-fiyat{margin-top:10px}',
      '.mz-fiyat small{display:block;font-size:11.5px;color:#8f9bc0}',
      '.mz-fiyat b{font:700 22px/1.1 var(--disp);color:#fff;font-variant-numeric:tabular-nums}',
      '.mz-sayac{display:inline-flex;align-items:center;gap:5px;margin-top:8px;padding:5px 10px;border-radius:999px;background:rgba(255,255,255,.07);font:700 13px/1 ui-monospace,Menlo,Consolas,monospace;color:#e8ecf8;font-variant-numeric:tabular-nums}',
      '.mz-sayac.acil{background:rgba(240,69,75,.2);color:#ff9a9e;animation:mzNabiz 1.2s ease-in-out infinite}',
      '@keyframes mzNabiz{50%{opacity:.6}}',
      '.mz-lider{display:inline-block;margin-left:6px;padding:3px 8px;border-radius:999px;background:rgba(52,201,138,.18);color:#62e3a9;font-size:11.5px;font-weight:750}',
      '.mz-gecildi{display:inline-block;margin-left:6px;padding:3px 8px;border-radius:999px;background:rgba(240,69,75,.18);color:#ff8a8f;font-size:11.5px;font-weight:750}',
      /* lot ızgarası */
      '.mz-izgara{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}',
      '.mz-lot{all:unset;box-sizing:border-box;cursor:pointer;display:flex;flex-direction:column;gap:8px;padding:10px;border-radius:18px;background:var(--mz-kart);box-shadow:inset 0 0 0 1px rgba(164,184,255,.10);transition:transform .14s}',
      '.mz-lot:active{transform:scale(.97)}',
      '.mz-lot:focus-visible,.mz-vitrin:focus-visible{outline:2px solid #a895ff;outline-offset:2px}',
      '.mz-lot .mz-cerceve{width:100%;aspect-ratio:1}',
      '.mz-lot b.ad{font-size:14px;font-weight:700;color:#f2f5ff;line-height:1.25;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;min-height:35px}',
      '.mz-lot .mz-fiyat{margin-top:0}',
      '.mz-lot .mz-fiyat b{font-size:18px}',
      '.mz-lot .mz-alt{display:flex;align-items:center;justify-content:space-between;gap:6px;font-size:11.5px;color:#8f9bc0}',
      '.mz-lot .mz-sayac{margin-top:0;padding:4px 8px;font-size:12px}',
      /* son satışlar şeridi */
      '.mz-serit{display:flex;gap:9px;overflow-x:auto;scrollbar-width:none;padding-bottom:4px}',
      '.mz-serit::-webkit-scrollbar{display:none}',
      '.mz-serit>div{flex:0 0 150px;padding:10px;border-radius:16px;background:var(--mz-kart);box-shadow:inset 0 0 0 1px rgba(164,184,255,.09)}',
      '.mz-serit .mz-cerceve{width:44px;height:44px;border-radius:12px;float:left;margin-right:8px}',
      '.mz-serit b{display:block;font-size:12.5px;color:#f2f5ff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
      '.mz-serit small{display:block;font-size:11px;color:#8f9bc0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
      '.mz-serit em{display:block;clear:both;padding-top:6px;font:700 15px/1 var(--disp);font-style:normal;color:#f2c14e}',
      /* lot detayı */
      '.mz-sahne{position:relative;border-radius:24px;padding:16px;margin-bottom:12px;background:radial-gradient(120% 80% at 50% 0%,#3a2c55,#141a38 70%);box-shadow:inset 0 0 0 1px rgba(242,193,78,.22)}',
      '.mz-sahne .mz-cerceve{width:min(240px,70vw);height:min(240px,70vw);margin:4px auto 12px;border-radius:22px}',
      '.mz-sahne h2{margin:0;text-align:center;font:700 26px/1.1 var(--disp);color:#fff}',
      '.mz-sahne .mz-ust{display:flex;justify-content:center;flex-wrap:wrap;gap:6px;margin-top:8px}',
      '.mz-sahne .mz-ust span.cip{padding:3px 9px;border-radius:999px;background:rgba(255,255,255,.07);font-size:11.5px;color:#c9d1e6}',
      '.mz-sahne p{margin:10px 0 0;text-align:center;font-size:13.5px;line-height:1.45;color:#c3cbe2}',
      '.mz-pey{border-radius:22px;padding:16px;margin-bottom:12px;background:linear-gradient(150deg,#22204a,#161c3c);box-shadow:inset 0 0 0 1px rgba(168,149,255,.22)}',
      '.mz-pey .mz-satir{display:flex;justify-content:space-between;align-items:flex-end;gap:10px}',
      '.mz-pey .mz-buyuk{font:700 34px/1 var(--disp);color:#fff;letter-spacing:-.5px;font-variant-numeric:tabular-nums}',
      '.mz-pey .mz-girdi{display:flex;align-items:center;gap:8px;margin-top:14px;padding:0 14px;height:56px;border-radius:16px;background:rgba(6,10,28,.55);box-shadow:inset 0 0 0 1px rgba(164,184,255,.18)}',
      '.mz-pey .mz-girdi:focus-within{box-shadow:inset 0 0 0 1.5px #a895ff,0 0 0 4px rgba(123,97,255,.18)}',
      '.mz-pey .mz-girdi input{all:unset;flex:1;min-width:0;font:700 24px/1 var(--disp);color:#fff}',
      '.mz-pey .mz-girdi span{font:700 22px/1 var(--disp);color:#8f9bc0}',
      '.mz-hizli{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-top:9px}',
      '.mz-hizli button{padding:9px 4px;border-radius:12px;background:rgba(255,255,255,.06);box-shadow:inset 0 0 0 1px rgba(255,255,255,.08);color:#dfe5f5;font-weight:700;font-size:13px}',
      '.mz-pey .mz-ver{width:100%;margin-top:12px;min-height:54px;border-radius:16px;font-size:17px;font-weight:800;background:linear-gradient(180deg,#f6d77a,#d9a83a);color:#3a2604;box-shadow:0 12px 24px -14px #f2c14e}',
      '.mz-pey .mz-ver:disabled{opacity:.45;box-shadow:none}',
      '.mz-pey .mz-not{margin-top:9px;font-size:12px;line-height:1.45;color:#8f9bc0}',
      '.mz-kart{border-radius:20px;padding:14px 16px;margin-bottom:12px;background:var(--mz-kart);box-shadow:inset 0 0 0 1px rgba(164,184,255,.10)}',
      '.mz-kart h4{margin:0 0 8px;font-size:13px;font-weight:700;color:#8f9bc0}',
      '.mz-kv{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid rgba(164,184,255,.08);font-size:14px;color:#c9d1e6}',
      '.mz-kv:last-child{border-bottom:0}',
      '.mz-kv b{color:#fff;font-variant-numeric:tabular-nums;text-align:right}',
      '.mz-kond{height:7px;border-radius:7px;background:rgba(255,255,255,.1);overflow:hidden;margin-top:6px}',
      '.mz-kond i{display:block;height:100%;border-radius:7px;background:linear-gradient(90deg,#f2c14e,#62e3a9)}',
      '.mz-seri{display:flex;gap:8px;overflow-x:auto;scrollbar-width:none}',
      '.mz-seri>div{flex:0 0 64px;text-align:center}',
      '.mz-seri .mz-cerceve{width:64px;height:64px;border-radius:14px}',
      '.mz-seri .mz-cerceve.yok{opacity:.35;filter:grayscale(.8)}',
      '.mz-seri small{display:block;margin-top:4px;font-size:10.5px;color:#aab4d4;line-height:1.2;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}',
      '.mz-peyler .mz-kv span{display:flex;align-items:center;gap:6px}',
      '.mz-peyler .mz-kv.ben b,.mz-peyler .mz-kv.ben span{color:#62e3a9}',
      '.mz-spark{width:100%;height:46px;display:block}',
      /* koleksiyon */
      '.mz-eser{all:unset;box-sizing:border-box;cursor:pointer;display:flex;gap:12px;align-items:center;width:100%;padding:10px;border-radius:18px;background:var(--mz-kart);box-shadow:inset 0 0 0 1px rgba(164,184,255,.10);margin-bottom:8px}',
      '.mz-eser .mz-cerceve{width:64px;height:64px;flex:none;border-radius:14px}',
      '.mz-eser .orta{flex:1;min-width:0}',
      '.mz-eser .orta b{display:block;font-size:15px;color:#f2f5ff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
      '.mz-eser .orta small{display:block;margin-top:3px;font-size:12px;color:#8f9bc0}',
      '.mz-eser .sag{text-align:right;flex:none}',
      '.mz-eser .sag b{display:block;font:700 17px/1.1 var(--disp);color:#fff}',
      '.mz-eser .sag small{font-size:11.5px;font-weight:700}',
      '.mz-art{color:#62e3a9}.mz-eks{color:#ff8a8f}',
      '.mz-durum{display:inline-block;margin-top:4px;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:700;background:rgba(255,255,255,.07);color:#c9d1e6}',
      '.mz-durum.sergide{background:rgba(242,193,78,.16);color:#f2c14e}.mz-durum.artirmada{background:rgba(123,97,255,.2);color:#c9bdff}',
      '.mz-ilerle{display:flex;align-items:center;gap:10px;padding:9px 0;border-bottom:1px solid rgba(164,184,255,.08)}',
      '.mz-ilerle:last-child{border-bottom:0}',
      '.mz-ilerle .ad{flex:1;min-width:0;font-size:14px;color:#e8ecf8}',
      '.mz-ilerle .cubuk{flex:0 0 90px;height:7px;border-radius:7px;background:rgba(255,255,255,.1);overflow:hidden}',
      '.mz-ilerle .cubuk i{display:block;height:100%;background:linear-gradient(90deg,#a895ff,#f2c14e)}',
      '.mz-ilerle small{flex:none;font-size:12px;color:#aab4d4;width:34px;text-align:right}',
      '.mz-islem{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:12px}',
      '.mz-islem button{min-height:48px;border-radius:14px;font-weight:700;font-size:14px;background:rgba(255,255,255,.06);box-shadow:inset 0 0 0 1px rgba(255,255,255,.10);color:#eef1f8}',
      '.mz-islem button.ana{background:linear-gradient(180deg,#8a73ff,#6a52e8);box-shadow:0 10px 20px -12px #7b61ff}',
      '.mz-islem button.altin{background:linear-gradient(180deg,#f6d77a,#d9a83a);color:#3a2604}',
      '.mz-islem button:disabled{opacity:.42}',
      '.mz-sira{display:flex;align-items:center;gap:12px;padding:11px 0;border-bottom:1px solid rgba(164,184,255,.08)}',
      '.mz-sira:last-child{border-bottom:0}',
      '.mz-sira .no{flex:none;width:30px;height:30px;border-radius:10px;display:grid;place-items:center;font:700 15px/1 var(--disp);background:rgba(255,255,255,.07);color:#c9d1e6}',
      '.mz-sira .no.n1{background:linear-gradient(145deg,#f6d77a,#b8862b);color:#3a2604}.mz-sira .no.n2{background:linear-gradient(145deg,#e3e8f2,#8d97ad);color:#1b2140}.mz-sira .no.n3{background:linear-gradient(145deg,#e7a873,#9a5b2f);color:#2a1406}',
      '.mz-sira .orta{flex:1;min-width:0}.mz-sira .orta b{display:block;color:#f2f5ff;font-size:15px}.mz-sira .orta small{color:#8f9bc0;font-size:12px}',
      '.mz-sira.ben .orta b{color:#62e3a9}',
      '.mz-sira .sag{font:700 16px/1 var(--disp);color:#f2c14e}',
      '.mz-kat{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}',
      '.mz-kat>div{padding:12px;border-radius:18px;background:var(--mz-kart);box-shadow:inset 0 0 0 1px rgba(164,184,255,.10)}',
      '.mz-kat b{display:block;font-size:13.5px;color:#e8ecf8}',
      '.mz-kat .e{font:700 22px/1.1 var(--disp);color:#fff;margin-top:4px}',
      '.mz-bos{padding:22px 16px;border-radius:20px;text-align:center;color:#aab4d4;font-size:14px;line-height:1.5;background:rgba(255,255,255,.03);box-shadow:inset 0 0 0 1px rgba(164,184,255,.08)}',
      '.mz-bos .btn{margin-top:12px}',
      '@media (max-width:360px){.mz-vitrin{grid-template-columns:104px 1fr}.mz-vitrin .mz-cerceve{width:104px;height:124px}.mz-izgara{gap:8px}.mz-pey .mz-buyuk{font-size:28px}}',
      '@media (prefers-reduced-motion:reduce){.mz-cerceve.efsanevi::after,.mz-sayac.acil{animation:none}}'
    ].join('\n');
    document.head.appendChild(s);
  }

  /* ---------- parçalar ---------- */
  var TOKMAK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="10.2" y="2.6" width="6" height="10" rx="1.6" transform="rotate(45 13.2 7.6)"/><path d="M8.4 9.6l3.9 3.9M11.6 11.4L4 19"/><path d="M13 21.2h8M14.5 18.4h5"/></svg>';
  function cerceve(e, ek) { var n = e && e.nadirlik || 'siradan'; return '<div class="mz-cerceve ' + n + (ek ? ' ' + ek : '') + '" style="--nr:' + (NAD_RENK[n] || '#8fa0c3') + '">' + eserSvg(e) + '</div>'; }
  function nadir(e) { var n = e && e.nadirlik || 'siradan'; return '<span class="mz-nad" style="--nr:' + (NAD_RENK[n] || '#8fa0c3') + '">' + esc(NAD[n] || n) + '</span>'; }
  function sayac(bitis) { var ms = new Date(bitis).getTime() - suan(); return '<span class="mz-sayac' + (ms < 600000 ? ' acil' : '') + '" data-mz-bitis="' + esc(bitis) + '">' + geri(ms) + '</span>'; }
  function spark(ls, renk) {
    ls = (ls || []).map(Number).filter(isFinite); if (ls.length < 2) ls = [1, 1];
    var mn = Math.min.apply(null, ls), mx = Math.max.apply(null, ls), w = 200, h = 46, d = '';
    if (mx - mn < 0.0001) { mx += 0.01; mn -= 0.01; }
    ls.forEach(function (v, i) { d += (i ? 'L' : 'M') + (i * w / (ls.length - 1)).toFixed(1) + ' ' + (h - 4 - (v - mn) / (mx - mn) * (h - 8)).toFixed(1); });
    return '<svg class="mz-spark" viewBox="0 0 200 46" preserveAspectRatio="none"><path d="' + d + 'L200 46L0 46Z" fill="' + renk + '" opacity=".14"/><path d="' + d + '" fill="none" stroke="' + renk + '" stroke-width="2.2" vector-effect="non-scaling-stroke"/></svg>';
  }
  function sekmeler() {
    return '<div class="mz-sekme" role="tablist">' + [['salon', 'Salon'], ['kol', 'Koleksiyonum'], ['piyasa', 'Piyasa'], ['sira', 'Sıralama']].map(function (x) {
      return '<button type="button" role="tab" aria-selected="' + (M.sekme === x[0]) + '" class="' + (M.sekme === x[0] ? 'aktif' : '') + '" onclick="mzSekme(\'' + x[0] + '\')">' + x[1] + '</button>';
    }).join('') + '</div>';
  }
  function cizSayfa(govde) {
    iskelet('Müzayede', '<div class="mz">' + govde + '</div>', { geri: D.yigin.length > 0 });
    M.ekran = 'salon'; zamanlayiciKur();
  }

  /* ---------- salon ---------- */
  function lotKarti(l) {
    var e = l.eser || {}, pey = l.pey_sayisi > 0;
    return '<button type="button" class="mz-lot" onclick="mzLotAc(' + Number(l.id) + ')">' + cerceve(e) +
      '<div>' + nadir(e) + (l.lider_benim ? '<span class="mz-lider">Lider</span>' : (l.peyim ? '<span class="mz-gecildi">Geçildi</span>' : '')) + '</div>' +
      '<b class="ad">' + esc(e.ad) + '</b>' +
      '<div class="mz-fiyat"><small>' + (pey ? 'En yüksek pey' : 'Açılış') + '</small><b>' + esc(kisa(pey ? l.en_yuksek : l.baslangic)) + '</b></div>' +
      '<div class="mz-alt">' + sayac(l.bitis) + '<span>' + (pey ? l.pey_sayisi + ' pey' : 'Pey yok') + '</span></div></button>';
  }
  function salonHtml(s) {
    var lotlar = s.lotlar || [], b = s.benim || {};
    var enYakin = lotlar.length ? lotlar[0].bitis : null;
    var vitrin = lotlar.slice().sort(function (a, c) { var r = { efsanevi: 4, cok_nadir: 3, nadir: 2, siradan: 1 }; return (r[c.eser.nadirlik] || 0) - (r[a.eser.nadirlik] || 0) || sayi(c.eser.deger) - sayi(a.eser.deger); })[0];
    var h = '<section class="mz-hero"><div class="mz-tokmak">' + TOKMAK + '</div><small>Müzayede Evi</small><h2>' + lotlar.length + ' lot açık artırmada</h2>' +
      '<p>' + (enYakin ? 'Sıradaki tokmak ' + '<span data-mz-bitis="' + esc(enYakin) + '">' + geri(new Date(enYakin).getTime() - suan()) + '</span> sonra' : 'Yeni lotlar birazdan salona gelir') + '</p>' +
      '<div class="mz-veri"><div><small>Koleksiyonun</small><b>' + esc(kisa(b.deger)) + '</b></div><div><small>Lider olduğun</small><b>' + sayi(b.lider) + ' lot</b></div><div><small>Bloke pey</small><b>' + esc(kisa(b.bloke)) + '</b></div></div></section>';
    h += sekmeler();
    if (s.acik === false) h += '<div class="mz-bos">Müzayede evi şu an bakımda. Peylerin ve eserlerin güvende; birazdan yeniden açılacak.</div>';
    if (vitrin) {
      var e = vitrin.eser, pey = vitrin.pey_sayisi > 0;
      h += '<button type="button" class="mz-vitrin" onclick="mzLotAc(' + Number(vitrin.id) + ')">' + cerceve(e) +
        '<div class="mz-vb"><small>Günün vitrini · ' + esc(e.kategori_ad) + '</small><b class="ad">' + esc(e.ad) + '</b>' + nadir(e) +
        '<div class="alt" style="margin-top:6px">' + esc(e.seri) + ' · ' + esc(e.no) + '/' + esc(e.adet) + '. baskı</div>' +
        '<div class="mz-fiyat"><small>' + (pey ? 'En yüksek pey' : 'Açılış fiyatı') + ' · tahmini ' + esc(kisa(e.deger)) + '</small><b>' + esc(tl(pey ? vitrin.en_yuksek : vitrin.baslangic)) + '</b></div>' + sayac(vitrin.bitis) + '</div></button>';
    }
    var filtreler = [['hepsi', 'Hepsi'], ['benim', 'Peylerim'], ['efsanevi', 'Efsanevi'], ['cok_nadir', 'Çok nadir'], ['nadir', 'Nadir'], ['siradan', 'Sıradan']];
    var gor = lotlar.filter(function (l) { return M.filtre === 'hepsi' || (M.filtre === 'benim' ? !!l.peyim || l.satici_benim : l.eser.nadirlik === M.filtre); });
    h += '<div class="mz-bas"><h3>Salondaki lotlar</h3><small>' + gor.length + ' lot</small></div>';
    h += '<div class="mz-sekme" style="margin-bottom:10px">' + filtreler.map(function (f) { return '<button type="button" class="' + (M.filtre === f[0] ? 'aktif' : '') + '" onclick="mzFiltre(\'' + f[0] + '\')">' + f[1] + '</button>'; }).join('') + '</div>';
    h += gor.length ? '<div class="mz-izgara">' + gor.map(lotKarti).join('') + '</div>' : '<div class="mz-bos">Bu filtrede açık lot yok.</div>';
    if ((s.son_satislar || []).length) {
      h += '<div class="mz-bas"><h3>Son tokmaklar</h3><small>Gerçek satışlar</small></div><div class="mz-serit">' + s.son_satislar.map(function (x) {
        return '<div>' + cerceve({ motif: x.motif, renk: x.renk, nadirlik: x.nadirlik, ad: x.eser }) + '<b>' + esc(x.eser) + '</b><small>' + esc(x.alici || '') + '</small><small>' + esc(tarih(x.zaman)) + '</small><em>' + esc(kisa(x.fiyat)) + '</em></div>';
      }).join('') + '</div>';
    }
    h += '<div class="mz-kart" style="margin-top:14px"><h4>Nasıl işler?</h4><div style="font-size:13px;line-height:1.55;color:#c3cbe2">Pey verdiğinde tutar cüzdanından bloke edilir; biri seni geçerse paran anında iade edilir. Son 5 dakikada gelen pey süreyi 5 dakika uzatır. Kazandığın eser koleksiyonuna girer: değeri, o türdeki gerçek satışlara göre her gün artar ya da azalır. Sergileyip günlük gelir alabilir, yeniden açık artırmaya çıkarabilir ya da Devlet Müzesi\'ne bağışlayıp kıdem puanı kazanabilirsin.</div></div>';
    return h;
  }

  /* ---------- lot detayı ---------- */
  function lotHtml(l) {
    var e = l.eser || {}, acik = l.durum === 'acik' && new Date(l.bitis).getTime() > suan(), pey = l.pey_sayisi > 0;
    var cz = D.durum && D.durum.profil && D.durum.profil.cuzdan ? sayi(D.durum.profil.cuzdan.para) : null;
    var h = '<div class="mz"><section class="mz-sahne">' + cerceve(e, e.nadirlik) + '<h2>' + esc(e.ad) + '</h2>' +
      '<div class="mz-ust">' + nadir(e) + '<span class="cip">' + esc(e.kategori_ad) + '</span><span class="cip">' + esc(e.no) + '/' + esc(e.adet) + '. baskı</span>' + (e.donem ? '<span class="cip">' + esc(e.donem) + '</span>' : '') + '</div>' +
      '<p>' + esc(e.aciklama) + '</p></section>';
    // pey kutusu
    h += '<section class="mz-pey"><div class="mz-satir"><div><small style="color:#8f9bc0;font-size:12px">' + (pey ? 'En yüksek pey · ' + esc(l.lider || '') : 'Açılış fiyatı') + '</small><div class="mz-buyuk">' + esc(tl(pey ? l.en_yuksek : l.baslangic)) + '</div></div>' +
      '<div style="text-align:right">' + (acik ? sayac(l.bitis) : '<span class="mz-sayac">' + (l.durum === 'satildi' ? 'Satıldı' : 'Kapandı') + '</span>') + '</div></div>';
    if (l.lider_benim && acik) h += '<div style="margin-top:10px"><span class="mz-lider" style="margin:0">Şu an lider sensin</span></div>';
    else if (l.peyim && acik) h += '<div style="margin-top:10px"><span class="mz-gecildi" style="margin:0">Peyin geçildi, paran iade edildi</span></div>';
    if (acik && !l.satici_benim) {
      h += '<div class="mz-girdi"><input id="mzPeyGirdi" inputmode="numeric" autocomplete="off" aria-label="Pey tutarı" value="' + esc(sayi(l.min_pey).toLocaleString('tr-TR')) + '" oninput="mzPeyBicim(this)"><span>₺</span></div>' +
        '<div class="mz-hizli"><button type="button" onclick="mzPeyHizli(0)">En az</button><button type="button" onclick="mzPeyHizli(0.1)">+%10</button><button type="button" onclick="mzPeyHizli(0.25)">+%25</button></div>' +
        '<button type="button" class="mz-ver" id="mzPeyVer" onclick="mzPeyVer()">' + (l.lider_benim ? 'Peyimi yükselt' : 'Pey ver') + '</button>' +
        '<div class="mz-not">En az ' + esc(tl(l.min_pey)) + '. Pey tutarı cüzdanından bloke edilir' + (cz != null ? ' (cüzdanında ' + esc(tl(cz)) + ' var)' : '') + '; geçilirsen anında iade edilir. Son 5 dakikadaki pey süreyi uzatır.</div>';
    } else if (acik && l.satici_benim) {
      h += '<div class="mz-not" style="margin-top:12px">Bu senin lotun. ' + (pey ? 'Satış kapanınca bedelden %7 komisyon düşülüp cüzdanına geçer.' : 'Henüz pey gelmedi; istersen geri çekebilirsin.') + '</div>' +
        (!pey ? '<div class="mz-islem"><button type="button" onclick="mzLotIptal(' + Number(l.id) + ')">Lotu geri çek</button></div>' : '');
    }
    h += '</section>';
    // değer
    var ilk = (l.endeks || [])[0], son = (l.endeks || [])[(l.endeks || []).length - 1];
    var deg = ilk && son ? ((son / ilk) - 1) * 100 : 0;
    h += '<section class="mz-kart"><h4>Değer</h4>' +
      '<div class="mz-kv"><span>Tahmini değer</span><b>' + esc(tl(e.deger)) + '</b></div>' +
      '<div class="mz-kv"><span>Açılış fiyatı</span><b>' + esc(tl(l.baslangic)) + '</b></div>' +
      (e.son_fiyat ? '<div class="mz-kv"><span>Son satış</span><b>' + esc(tl(e.son_fiyat)) + '</b></div>' : '') +
      '<div class="mz-kv" style="display:block"><div style="display:flex;justify-content:space-between"><span>Kondisyon</span><b>' + Math.round(sayi(e.kondisyon) * 100) + ' / 125</b></div><div class="mz-kond"><i style="width:' + Math.min(100, Math.round(sayi(e.kondisyon) / 1.25 * 100)) + '%"></i></div></div>' +
      '<div style="margin-top:10px;font-size:12px;color:#8f9bc0">' + esc(e.kategori_ad) + ' piyasası, son 30 gün ' + (deg >= 0 ? '<span class="mz-art">▲ %' + deg.toFixed(1) + '</span>' : '<span class="mz-eks">▼ %' + Math.abs(deg).toFixed(1) + '</span>') + '</div>' +
      spark(l.endeks, deg >= 0 ? '#62e3a9' : '#ff8a8f') + '</section>';
    // seri
    if ((l.seri_eserler || []).length) {
      var bende = l.seri_eserler.filter(function (x) { return x.bende; }).length;
      h += '<section class="mz-kart"><h4>' + esc(e.seri) + ' serisi · ' + bende + '/' + l.seri_eserler.length + ' sende</h4><div class="mz-seri">' +
        l.seri_eserler.map(function (x) { return '<div>' + cerceve(x, x.bende ? '' : 'yok') + '<small>' + esc(x.ad) + '</small></div>'; }).join('') +
        '</div><div style="margin-top:8px;font-size:12px;color:#8f9bc0">Serinin tamamını toplayan oyuncunun bu serideki bütün eserleri %25 daha değerli sayılır.</div></section>';
    }
    // peyler
    h += '<section class="mz-kart mz-peyler"><h4>Pey geçmişi · ' + sayi(l.pey_sayisi) + '</h4>' + ((l.peyler || []).length ? l.peyler.map(function (p) {
      return '<div class="mz-kv' + (p.benim ? ' ben' : '') + '"><span>' + esc(p.kim) + (p.durum === 'lider' || p.durum === 'kazandi' ? ' <span class="mz-lider" style="margin:0">' + (p.durum === 'kazandi' ? 'Kazandı' : 'Lider') + '</span>' : '') + '</span><b>' + esc(tl(p.tutar)) + '<small style="display:block;font-weight:500;color:#8f9bc0;font-size:11px">' + esc(tarih(p.zaman)) + '</small></b></div>';
    }).join('') : '<div style="font-size:13.5px;color:#aab4d4">Henüz pey yok. İlk peyi sen ver!</div>') + '</section>';
    if ((l.gecmis || []).length) h += '<section class="mz-kart"><h4>Bu eserin önceki satışları</h4>' + l.gecmis.map(function (g) { return '<div class="mz-kv"><span>' + esc(tarih(g.zaman)) + ' · ' + esc(g.alici || '') + '</span><b>' + esc(tl(g.fiyat)) + '</b></div>'; }).join('') + '</section>';
    h += '<div class="mz-kart"><div class="mz-kv"><span>Satıcı</span><b>' + esc(l.satici) + '</b></div><div class="mz-kv"><span>Lot no</span><b>#' + esc(l.id) + '</b></div></div></div>';
    return h;
  }

  /* ---------- koleksiyon ---------- */
  function eserSatiri(e) {
    var kz = e.alis_bedeli ? (sayi(e.deger) / sayi(e.alis_bedeli) - 1) * 100 : null;
    var dur = e.durum === 'sergide' ? 'Sergide · günde ' + tl(e.sergi_gunluk) : e.durum === 'artirmada' ? 'Açık artırmada' : 'Kasada';
    return '<button type="button" class="mz-eser" onclick="mzEserAc(' + Number(e.id) + ')">' + cerceve(e) +
      '<div class="orta"><b>' + esc(e.ad) + '</b><small>' + esc(NAD[e.nadirlik] || '') + ' · ' + esc(e.seri) + '</small><span class="mz-durum ' + esc(e.durum) + '">' + esc(dur) + '</span></div>' +
      '<div class="sag"><b>' + esc(kisa(e.deger)) + '</b>' + (kz != null ? '<small class="' + (kz >= 0 ? 'mz-art' : 'mz-eks') + '">' + (kz >= 0 ? '▲ %' : '▼ %') + Math.abs(kz).toFixed(1) + '</small>' : '') + '</div></button>';
  }
  function kolHtml(k) {
    var es = k.eserler || [], kar = sayi(k.toplam_deger) - sayi(k.toplam_maliyet), tamSet = (k.seriler || []).filter(function (s) { return s.tam; }).length;
    var sergiG = es.reduce(function (t, e) { return t + (e.durum === 'sergide' ? sayi(e.sergi_gunluk) : 0); }, 0);
    var h = '<section class="mz-hero"><div class="mz-tokmak">' + TOKMAK + '</div><small>Koleksiyonum</small><h2>' + esc(tl(k.toplam_deger)) + '</h2>' +
      '<p>' + es.length + ' eser · ' + (k.toplam_maliyet ? 'alış maliyetine göre ' + (kar >= 0 ? '+' : '−') + esc(tl(Math.abs(kar))) : 'henüz eserin yok') + '</p>' +
      '<div class="mz-veri"><div><small>Tam seri</small><b>' + tamSet + '</b></div><div><small>Sergi geliri</small><b>' + esc(tl(Math.min(sergiG, sayi(k.sergi_tavan)))) + '/gün</b></div><div><small>Bağış kıdemi</small><b>' + sayi(k.bagis_kidem) + '/' + sayi(k.bagis_kidem_tavan) + '</b></div></div></section>';
    h += sekmeler();
    if ((k.peylerim || []).length) h += '<div class="mz-bas"><h3>Peylerim</h3><small>Açık artırmalar</small></div><div class="mz-izgara">' + k.peylerim.map(lotKarti).join('') + '</div>';
    if ((k.satistakiler || []).length) h += '<div class="mz-bas"><h3>Satıştaki eserlerim</h3></div><div class="mz-izgara">' + k.satistakiler.map(lotKarti).join('') + '</div>';
    h += '<div class="mz-bas"><h3>Eserlerim</h3><small>Dokun: sergile, sat, bağışla</small></div>';
    h += es.length ? es.map(eserSatiri).join('') : '<div class="mz-bos">Koleksiyonun henüz boş. Salondaki lotlara pey vererek ilk eserini kazan.<br><button class="btn" onclick="mzSekme(\'salon\')">Salona git</button></div>';
    if ((k.seriler || []).length) h += '<div class="mz-bas"><h3>Seriler</h3><small>Tamamlayınca %25 değer</small></div><div class="mz-kart">' + k.seriler.map(function (s) {
      return '<div class="mz-ilerle"><span class="ad">' + esc(s.seri) + (s.tam ? ' <span class="mz-lider">Tamam</span>' : '') + '</span><span class="cubuk"><i style="width:' + Math.round(s.bende / s.toplam * 100) + '%"></i></span><small>' + s.bende + '/' + s.toplam + '</small></div>';
    }).join('') + '</div>';
    h += '<div class="mz-kart"><h4>Özel müze</h4><div style="font-size:13px;line-height:1.55;color:#c3cbe2">Sergilediğin her eser, değerine ve nadirliğine göre her gün gelir getirir (günde en fazla ' + esc(tl(k.sergi_tavan)) + '). Sergiye koyduğun eserin geliri ertesi gün başlar.' + (k.sergi_bugun ? ' Bugün ' + esc(tl(k.sergi_bugun)) + ' sergi geliri aldın.' : '') + '</div></div>';
    return h;
  }
  function eserModal(e) {
    var acilis = e.eve_satis_acilis ? new Date(e.eve_satis_acilis).getTime() : 0, eveHazir = !acilis || acilis <= suan();
    var h = '<div class="mz" style="text-align:center">' + cerceve(e, e.nadirlik).replace('class="mz-cerceve', 'style="width:150px;height:150px;margin:0 auto 10px" class="mz-cerceve') +
      '<h3 style="font:700 22px/1.15 var(--disp);color:#fff">' + esc(e.ad) + '</h3><div style="margin-top:6px">' + nadir(e) + '</div>' +
      '<div class="mz-kart" style="text-align:left;margin-top:12px">' +
      '<div class="mz-kv"><span>Tahmini değer</span><b>' + esc(tl(e.deger)) + '</b></div>' +
      (e.alis_bedeli ? '<div class="mz-kv"><span>Alış bedelin</span><b>' + esc(tl(e.alis_bedeli)) + '</b></div>' : '') +
      '<div class="mz-kv"><span>Kondisyon</span><b>' + Math.round(sayi(e.kondisyon) * 100) + ' / 125</b></div>' +
      '<div class="mz-kv"><span>Seri</span><b>' + esc(e.seri) + (e.set_tam ? ' · tamam (+%25)' : '') + '</b></div>' +
      (e.durum === 'sergide' ? '<div class="mz-kv"><span>Sergi geliri</span><b>günde ' + esc(tl(e.sergi_gunluk)) + '</b></div>' : '') + '</div>';
    if (e.durum === 'artirmada') {
      h += '<div class="mz-islem" style="grid-template-columns:1fr"><button type="button" class="ana" onclick="modalKapat();mzLotAc(' + Number(e.lot) + ')">Açık artırmayı izle</button></div>';
    } else {
      h += '<div class="mz-islem">' +
        '<button type="button" class="ana" onclick="mzSatisaCikar(' + Number(e.id) + ')">Açık artırmaya çıkar</button>' +
        (e.durum === 'sergide' ? '<button type="button" onclick="mzSergi(' + Number(e.id) + ',false)">Sergiden kaldır</button>' : '<button type="button" class="altin" onclick="mzSergi(' + Number(e.id) + ',true)">Özel müzede sergile</button>') +
        '<button type="button" onclick="mzEveSat(' + Number(e.id) + ')"' + (eveHazir ? '' : ' disabled') + '>Müzayede evine sat<small style="display:block;font-weight:500;font-size:11.5px;color:#aab4d4">' + (eveHazir ? esc(tl(e.eve_satis)) : esc(tarih(e.eve_satis_acilis)) + ' sonra') + '</small></button>' +
        '<button type="button" onclick="mzBagis(' + Number(e.id) + ')">Devlet Müzesi\'ne bağışla<small style="display:block;font-weight:500;font-size:11.5px;color:#aab4d4">' + (sayi(e.bagis_kidem) > 0 ? '+' + sayi(e.bagis_kidem) + ' kıdem puanı' : 'Adın müzede yazılır') + '</small></button></div>';
    }
    h += '<button class="btn ikinci" style="margin-top:10px" onclick="modalKapat()">Kapat</button></div>';
    modal(h);
  }

  /* ---------- piyasa ve sıralama ---------- */
  function piyasaHtml(s) {
    var h = '<section class="mz-hero"><div class="mz-tokmak">' + TOKMAK + '</div><small>Koleksiyon piyasası</small><h2>Değer endeksleri</h2><p>Her gün gerçek satışlara göre güncellenir: rekabetli açık artırmalar endeksi yükseltir, pey gelmeyen lotlar düşürür.</p></section>' + sekmeler();
    h += '<div class="mz-kat">' + (s.kategoriler || []).map(function (c) {
      var d = c.degisim7 == null ? null : Number(c.degisim7), renk = d == null || d >= 0 ? '#62e3a9' : '#ff8a8f';
      return '<div><b>' + esc(c.ad) + '</b><div class="e">' + (sayi(c.endeks) * 100).toFixed(1) + '</div><small style="color:' + renk + ';font-weight:700;font-size:12px">' + (d == null ? 'Yeni piyasa' : (d >= 0 ? '▲ %' : '▼ %') + Math.abs(d).toFixed(1) + ' · 7 gün') + '</small>' + spark(c.seri, renk) + '</div>';
    }).join('') + '</div>';
    h += '<div class="mz-kart" style="margin-top:12px"><h4>Değer nasıl hesaplanır?</h4><div style="font-size:13px;line-height:1.55;color:#c3cbe2">Tahmini değer = eserin taban değeri × kategori endeksi × kondisyonu × son satış primi. Bir eser tahmini değerinin üstünde satılırsa primi yükselir, prim zamanla normale döner. Bir serinin bütün eserlerini toplarsan o serideki eserlerin %25 daha değerli sayılır. Endeks 100 ile başladı.</div></div>';
    return h;
  }
  function siraHtml(r) {
    var h = '<section class="mz-hero"><div class="mz-tokmak">' + TOKMAK + '</div><small>Sıralama</small><h2>Ülkenin koleksiyoncuları</h2><p>En değerli koleksiyonlar, rekor satışlar ve Devlet Müzesi bağışçıları.</p></section>' + sekmeler();
    h += '<div class="mz-bas"><h3>Koleksiyoncular</h3><small>Toplam değere göre</small></div><div class="mz-kart">' + ((r.koleksiyoncular || []).length ? r.koleksiyoncular.map(function (k, i) {
      return '<div class="mz-sira' + (k.benim ? ' ben' : '') + '"><span class="no' + (i < 3 ? ' n' + (i + 1) : '') + '">' + (i + 1) + '</span><span class="orta"><b>' + esc(k.kad) + (k.parti ? ' <small style="color:' + esc(k.parti.renk) + '">' + esc(k.parti.kisa) + '</small>' : '') + '</b><small>' + sayi(k.eser) + ' eser' + (k.efsanevi ? ' · ' + k.efsanevi + ' efsanevi' : '') + (k.tam_set ? ' · ' + k.tam_set + ' tam seri' : '') + '</small></span><span class="sag">' + esc(kisa(k.deger)) + '</span></div>';
    }).join('') : '<div style="font-size:13.5px;color:#aab4d4">Henüz koleksiyoncu yok. İlk olmak için salona git!</div>') + '</div>';
    if ((r.rekorlar || []).length) h += '<div class="mz-bas"><h3>Rekor satışlar</h3></div><div class="mz-serit">' + r.rekorlar.map(function (x) {
      return '<div>' + cerceve({ motif: x.motif, renk: x.renk, nadirlik: x.nadirlik, ad: x.eser }) + '<b>' + esc(x.eser) + '</b><small>' + esc(x.alici || '') + '</small><small>' + esc(tarih(x.zaman)) + '</small><em>' + esc(kisa(x.fiyat)) + '</em></div>';
    }).join('') + '</div>';
    h += '<div class="mz-bas"><h3>Devlet Müzesi</h3><small>' + (r.muze || []).length + ' bağış</small></div>';
    h += (r.muze || []).length ? (r.muze || []).map(function (e) {
      return '<div class="mz-eser" style="cursor:default">' + cerceve(e) + '<div class="orta"><b>' + esc(e.ad) + '</b><small>Bağışlayan: ' + esc(e.bagisci || '—') + ' · ' + esc(tarih(e.bagis_zaman)) + '</small></div></div>';
    }).join('') : '<div class="mz-bos">Müze henüz boş. Koleksiyonundan bir eseri bağışlayan ilk oyuncunun adı burada yazacak.</div>';
    return h;
  }

  /* ---------- ekranlar ---------- */
  async function salonCiz(sessiz) {
    if (!sessiz) yukleniyor('Müzayede');
    try {
      if (M.sekme === 'kol') { M.kol = await rpc('muzayede_koleksiyonum'); cizSayfa(kolHtml(M.kol)); }
      else if (M.sekme === 'sira') { M.sira = await rpc('muzayede_siralama'); cizSayfa(siraHtml(M.sira)); }
      else { M.salon = await rpc('muzayede_salon'); cizSayfa(M.sekme === 'piyasa' ? piyasaHtml(M.salon) : salonHtml(M.salon)); }
    } catch (err) {
      if (sessiz) return;
      iskelet('Müzayede', '<div class="mz"><div class="mz-bos">Müzayede evi şu an açılamadı.<br>' + esc(typeof hataCevir === 'function' ? hataCevir(err.message) : err.message) + '<br><button class="btn" onclick="muzayedeEkrani()">Yeniden dene</button></div></div>', { geri: D.yigin.length > 0 });
    }
  }
  window.muzayedeEkrani = function (sekme) { stil(); if (typeof sekme === 'string') M.sekme = sekme; M.lotId = null; return salonCiz(false); };
  window.mzSekme = function (s) { M.sekme = s; salonCiz(true).then(function () { var ic = document.getElementById('icerik'); if (ic) ic.scrollTop = 0; }); };
  window.mzFiltre = function (f) { M.filtre = f; if (M.salon) cizSayfa(salonHtml(M.salon)); };
  async function lotCiz(sessiz) {
    if (!sessiz) yukleniyor('Açık artırma');
    try {
      var l = await rpc('muzayede_lot', { p_lot: M.lotId }); M.lot = l;
      var girdi = document.getElementById('mzPeyGirdi'), yaziyor = sessiz && girdi && document.activeElement === girdi, deger = girdi && girdi.value;
      if (yaziyor) { guncelleCanli(l); return; }
      iskelet('Açık artırma', lotHtml(l), { geri: true }); M.ekran = 'lot';
      if (sessiz && deger && girdi) { var g2 = document.getElementById('mzPeyGirdi'); if (g2 && sayi(deger.replace(/\D/g, '')) >= sayi(l.min_pey)) g2.value = deger; }
      zamanlayiciKur();
    } catch (err) { if (!sessiz) hata(err); }
  }
  function guncelleCanli(l) { // kullanıcı tutar yazarken ekranı baştan çizme; yalnız fiyatı ve süreyi tazele
    var b = document.querySelector('.mz-pey .mz-buyuk'); if (b) b.textContent = tl(l.pey_sayisi > 0 ? l.en_yuksek : l.baslangic);
    var s = document.querySelector('.mz-pey [data-mz-bitis]'); if (s) s.setAttribute('data-mz-bitis', l.bitis);
  }
  window.mzLotAc = function (id) { stil(); M.lotId = Number(id); ekranAc(function () { M.lotId = Number(id); return lotCiz(false); }); };
  window.mzPeyBicim = function (el) { var n = el.value.replace(/\D/g, ''); el.value = n ? Number(n).toLocaleString('tr-TR') : ''; };
  window.mzPeyHizli = function (oran) {
    var l = M.lot; if (!l) return; var g = document.getElementById('mzPeyGirdi'); if (!g) return;
    var taban = sayi(l.pey_sayisi > 0 ? l.en_yuksek : l.baslangic), v = oran ? Math.max(sayi(l.min_pey), Math.ceil(taban * (1 + oran) / 100) * 100) : sayi(l.min_pey);
    g.value = v.toLocaleString('tr-TR');
  };
  window.mzPeyVer = async function () {
    var l = M.lot, g = document.getElementById('mzPeyGirdi'); if (!l || !g) return;
    var t = sayi(g.value.replace(/\D/g, ''));
    if (t < sayi(l.min_pey)) { toast('Pey en az ' + tl(l.min_pey) + ' olmalı.', true); return; }
    var ek = l.lider_benim ? ' Şu an lider sensin; yalnız aradaki ' + tl(t - sayi(l.en_yuksek)) + ' bloke edilir.' : '';
    if (!(await onayla('Pey ver: ' + esc(tl(t)), '“' + esc(l.eser.ad) + '” için ' + esc(tl(t)) + ' pey veriyorsun. Bu tutar cüzdanından bloke edilir; biri seni geçerse anında iade edilir.' + esc(ek), 'Pey ver'))) return;
    var btn = document.getElementById('mzPeyVer'); if (btn) btn.disabled = true;
    try {
      var r = await rpc('muzayede_pey', { p_lot: l.id, p_tutar: t }); M.lot = r;
      toast('Peyin alındı. Şu an lider sensin!');
      if (typeof durumYenile === 'function') durumYenile().catch(function () {});
      iskelet('Açık artırma', lotHtml(r), { geri: true }); M.ekran = 'lot'; zamanlayiciKur();
    } catch (err) { hata(err); if (btn) btn.disabled = false; lotCiz(true); }
  };
  window.mzLotIptal = async function (id) {
    if (!(await onayla('Lotu geri çek', 'Eser koleksiyonuna geri döner. Lot açma ücreti iade edilmez.', 'Geri çek'))) return;
    try { await rpc('muzayede_lot_iptal', { p_lot: id }); toast('Lot geri çekildi.'); geriGit(); } catch (err) { hata(err); }
  };
  window.mzEserAc = function (id) {
    var e = M.kol && (M.kol.eserler || []).filter(function (x) { return Number(x.id) === Number(id); })[0];
    if (e) eserModal(e);
  };
  async function kolYenile() { M.sekme = 'kol'; await salonCiz(true); }
  window.mzSergi = async function (id, ac) {
    try { await rpc('muzayede_sergi', { p_eser: id, p_ac: !!ac }); modalKapat(); toast(ac ? 'Eser özel müzende sergileniyor. Sergi geliri yarın başlar.' : 'Eser sergiden kaldırıldı.'); kolYenile(); } catch (err) { hata(err); }
  };
  window.mzEveSat = async function (id) {
    var e = M.kol && (M.kol.eserler || []).filter(function (x) { return Number(x.id) === Number(id); })[0]; if (!e) return;
    if (!(await onayla('Müzayede evine sat', '“' + esc(e.ad) + '” eserini müzayede evine ' + esc(tl(e.eve_satis)) + ' karşılığında satıyorsun (tahmini değerin yarısı). Açık artırmada daha yüksek fiyat alabilirsin.', 'Sat', true))) return;
    try { var r = await rpc('muzayede_eve_sat', { p_eser: id }); modalKapat(); toast('Satıldı: +' + tl(r.bedel)); if (typeof durumYenile === 'function') durumYenile().catch(function () {}); kolYenile(); } catch (err) { hata(err); }
  };
  window.mzBagis = async function (id) {
    var e = M.kol && (M.kol.eserler || []).filter(function (x) { return Number(x.id) === Number(id); })[0]; if (!e) return;
    if (!(await onayla('Devlet Müzesi\'ne bağışla', '“' + esc(e.ad) + '” kalıcı olarak Devlet Müzesi\'ne geçer ve adın bağışçı olarak yazılır.' + (sayi(e.bagis_kidem) > 0 ? ' Karşılığında +' + sayi(e.bagis_kidem) + ' kıdem puanı kazanırsın (bağışlardan toplam en fazla 20).' : '') + ' Bu işlem geri alınamaz.', 'Bağışla', true))) return;
    try { var r = await rpc('muzayede_bagis', { p_eser: id }); modalKapat(); toast('Eser müzeye bağışlandı' + (r.kidem ? ': +' + r.kidem + ' kıdem puanı' : '.')); kolYenile(); } catch (err) { hata(err); }
  };
  window.mzSatisaCikar = function (id) {
    var e = M.kol && (M.kol.eserler || []).filter(function (x) { return Number(x.id) === Number(id); })[0]; if (!e) return;
    var oneri = Math.max(500, Math.round(sayi(e.deger) * 0.7 / 100) * 100);
    modal('<div class="mz"><h3 style="font:700 21px/1.2 var(--disp);color:#fff">Açık artırmaya çıkar</h3><p class="alt" style="margin-top:6px">“' + esc(e.ad) + '” · tahmini değer ' + esc(tl(e.deger)) + '</p>' +
      '<div class="alan"><label>Açılış fiyatı (₺)</label><input id="mzSatBas" inputmode="numeric" value="' + oneri.toLocaleString('tr-TR') + '" oninput="mzPeyBicim(this);mzSatUcret()"></div>' +
      '<div class="alan"><label>Süre</label><select id="mzSatSaat"><option value="6">6 saat</option><option value="12">12 saat</option><option value="24" selected>24 saat</option><option value="48">48 saat</option></select></div>' +
      '<p class="kucuk" id="mzSatNot" style="margin:6px 0 4px"></p>' +
      '<button class="btn" id="mzSatGit" onclick="mzSatGonder(' + Number(e.id) + ')">Lotu aç</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button></div>');
    window.mzSatUcret();
  };
  window.mzSatUcret = function () {
    var g = document.getElementById('mzSatBas'), n = document.getElementById('mzSatNot'); if (!g || !n) return;
    var b = sayi(g.value.replace(/\D/g, '')), u = Math.max(250, Math.min(5000, Math.round(b * 0.01)));
    n.textContent = 'Lot açma ücreti ' + tl(u) + '. Satılırsa bedelden %7 komisyon düşülür; pey gelmezse eser koleksiyonuna döner. Aynı anda en fazla 3 lot açabilirsin.';
  };
  window.mzSatGonder = async function (id) {
    var b = sayi((document.getElementById('mzSatBas') || {}).value.replace(/\D/g, '')), s = Number((document.getElementById('mzSatSaat') || {}).value || 24);
    var btn = document.getElementById('mzSatGit'); if (btn) btn.disabled = true;
    try { var r = await rpc('muzayede_lot_ac', { p_eser: id, p_baslangic: b, p_saat: s }); modalKapat(); toast('Eserin salonda! Açık artırma başladı.'); M.lotId = r.id; ekranAc(function () { M.lotId = Number(r.id); return lotCiz(false); }); }
    catch (err) { hata(err); if (btn) btn.disabled = false; }
  };

  /* ---------- canlı sayaç ve tazeleme ---------- */
  function zamanlayiciKur() {
    if (M.zamanlayici) return;
    M.zamanlayici = setInterval(function () {
      if (!aktifMi()) { clearInterval(M.zamanlayici); M.zamanlayici = null; clearInterval(M.tazele); M.tazele = null; return; }
      var n = suan();
      document.querySelectorAll('#icerik [data-mz-bitis]').forEach(function (el) {
        var ms = new Date(el.getAttribute('data-mz-bitis')).getTime() - n; el.textContent = geri(ms);
        if (el.classList.contains('mz-sayac')) el.classList.toggle('acil', ms > 0 && ms < 600000);
      });
    }, 1000);
    clearInterval(M.tazele);
    M.tazele = setInterval(function () {
      if (!aktifMi() || document.hidden || (window.YUK && typeof YUK.otomatik === 'function' && !YUK.otomatik())) return;
      if (document.getElementById('modal')) return;
      if (M.ekran === 'lot' && M.lotId && document.querySelector('#icerik .mz-pey')) lotCiz(true);
      else if (M.ekran === 'salon' && M.sekme === 'salon' && document.querySelector('#icerik .mz-izgara,#icerik .mz-bos')) salonCiz(true);
    }, 8000 + Math.floor(Math.random() * 2000));
  }
})();
