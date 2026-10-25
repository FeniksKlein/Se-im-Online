/*
 * SEÇİM SİMÜLASYONU ONLINE — PREMIUM ARAYÜZ KATMANI (25.10.2026)
 * Mobil Şube'nin tasarım dilini bütün oyuna taşır. Yalnız arayüz:
 * hiçbir RPC çağırmaz, oyun verisini değiştirmez, kural koymaz.
 *  · 10 sekmeli kayan alt menü → 5 düğmeli sade menü + "Menü" çekmecesi
 *  · Her ana bölüme kendi renginde, gravürlü (guilloché) "kurum kartı"
 *  · Bölüm başındaki tek tek düğmeler kartın altındaki hızlı işlem şeridine toplanır
 *  · Profil: oyuncu kimlik kartı · Hayat: maaş kumbarası halkası
 *  · Ortak bileşenler (kart, hap sekme, düğme, satır) tek sistemde
 * derle.js ile en son gömülür; mevcut fonksiyonların hepsi aynen çalışır.
 */
(function () {
  'use strict';
  if (window.SO_PREMIUM_ARAYUZ_V1) return;
  window.SO_PREMIUM_ARAYUZ_V1 = true;

  /* ---------- küçük yardımcılar ---------- */
  var SON = {};                        // ekranların zaten çektiği RPC sonuçları (ek istek yok)
  window.SO_PA_SON = SON;
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function sayi(v) { var n = Number(v); return isFinite(n) ? n : 0; }
  function tr(n, k) { return sayi(n).toLocaleString('tr-TR', { maximumFractionDigits: k == null ? 0 : k }); }
  function tl(n) { return tr(n) + ' ₺'; }
  function kisaTl(n) {
    n = sayi(n); var a = Math.abs(n), s = n < 0 ? '−' : '';
    if (a >= 1e9) return s + tr(a / 1e9, 2) + ' Mr ₺';
    if (a >= 1e6) return s + tr(a / 1e6, 2) + ' Mn ₺';
    if (a >= 1e5) return s + tr(a / 1e3, 0) + ' B ₺';
    return s + tr(a) + ' ₺';
  }
  function g(name) { try { if (typeof window[name] === 'function') return window[name]; if (name === 'makamYaz' && typeof makamYaz === 'function') return makamYaz; } catch (e) {} return null; }
  function Dx() { try { return typeof D !== 'undefined' ? D : null; } catch (e) { return null; } }
  function profil() { var d = Dx(); return d && d.durum && d.durum.profil || null; }
  function azHareket() { try { return window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches; } catch (e) { return false; } }
  function hex2rgb(h) { h = String(h || '').replace('#', ''); if (h.length === 3) h = h.replace(/./g, '$&$&'); var n = parseInt(h, 16); if (!isFinite(n) || h.length !== 6) return [123, 97, 255]; return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
  function karis(h, k, t) { var a = hex2rgb(h), b = hex2rgb(k); return '#' + a.map(function (x, i) { return Math.round(x + (b[i] - x) * t).toString(16).padStart(2, '0'); }).join(''); }
  function rgba(h, a) { var c = hex2rgb(h); return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; }
  function tarihKisa(s) { try { return new Date(s).toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric' }); } catch (e) { return ''; } }
  function gunFark(s) { var t = new Date(s).getTime(); return isFinite(t) ? Math.floor((Date.now() - t) / 864e5) : null; }
  function selam() { var h = new Date().getHours(); return h < 5 ? 'İyi geceler' : h < 11 ? 'Günaydın' : h < 17 ? 'İyi günler' : h < 22 ? 'İyi akşamlar' : 'İyi geceler'; }

  /* ---------- ikonlar ---------- */
  function sv(p) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>'; }
  var IK = {
    menu: sv('<rect x="3.5" y="3.5" width="7" height="7" rx="2"/><rect x="13.5" y="3.5" width="7" height="7" rx="2"/><rect x="3.5" y="13.5" width="7" height="7" rx="2"/><rect x="13.5" y="13.5" width="7" height="7" rx="3.5"/>'),
    banka: sv('<path d="M3 10h18M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 21h18M12 3l9 5H3z"/>'),
    ilan: sv('<path d="M4 10l8-6 8 6v10a1 1 0 0 1-1 1h-5v-6h-4v6H5a1 1 0 0 1-1-1z"/>'),
    magaza: sv('<path d="M5 8h14l-1.2 11.2a2 2 0 0 1-2 1.8H8.2a2 2 0 0 1-2-1.8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>'),
    zil: sv('<path d="M6 8a6 6 0 1 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0"/>'),
    kalkan: sv('<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>'),
    ara: sv('<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>'),
    kalem: sv('<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>'),
    megafon: sv('<path d="M3 11v2a1 1 0 0 0 1 1h3l6 4V6L7 10H4a1 1 0 0 0-1 1z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>'),
    kriz: sv('<path d="M12 4l9.5 16h-19z"/><path d="M12 10v4M12 17.5v.01"/>'),
    gazete: sv('<path d="M4 5h13v14a2 2 0 0 0 2 2H6a2 2 0 0 1-2-2z"/><path d="M17 9h3v10a2 2 0 0 1-2 2M8 9h5M8 13h5M8 17h3"/>'),
    gorev: sv('<path d="M9 6h11M9 12h11M9 18h11"/><path d="M3.5 6l1.2 1.2L7 5M3.5 12l1.2 1.2L7 11M3.5 18l1.2 1.2L7 17"/>'),
    oynat: sv('<circle cx="12" cy="12" r="9"/><path d="M10 8.5v7l6-3.5z"/>'),
    para: sv('<circle cx="12" cy="12" r="9"/><path d="M10 7v10M10 12h3.5a2.5 2.5 0 0 0 0-5H10M14.5 17L10 12"/>'),
    kumbara: sv('<path d="M5 11a7 6 0 0 1 12.5-2.5L20 8v4l-1.6.8A7 7 0 0 1 15 17v3h-3v-2H9v2H6v-3.4A6 6 0 0 1 5 11z"/><circle cx="15.5" cy="10.5" r=".6" fill="currentColor"/>'),
    kanun: sv('<path d="M7 3h7l5 5v12a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z"/><path d="M14 3v5h5M9 13h7M9 17h5"/>'),
    kisi: sv('<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7"/>'),
    kisiler: sv('<circle cx="9" cy="8" r="3.3"/><circle cx="17" cy="9" r="2.6"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M15.5 14.4c3 0 5.5 2 5.5 5.6"/>'),
    yeniMesaj: sv('<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20.5l1.4-4.6A8 8 0 1 1 21 12z"/><path d="M12 8.5v7M8.5 12h7"/>'),
    konum: sv('<path d="M12 21s-7-6.2-7-12a7 7 0 0 1 14 0c0 5.8-7 12-7 12z"/><circle cx="12" cy="9" r="2.6"/>'),
    el: sv('<path d="M7 11V6a1.5 1.5 0 0 1 3 0v4.5M10 10V4.5a1.5 1.5 0 0 1 3 0V10M13 10V5.5a1.5 1.5 0 0 1 3 0V12M16 9a1.5 1.5 0 0 1 3 0v5a7 7 0 0 1-7 7h-1a6 6 0 0 1-5.4-3.4L4 14.4a1.6 1.6 0 0 1 2.7-1.7L8 14"/>'),
    kalp: sv('<path d="M12 20s-8-4.7-8-10.6A4.4 4.4 0 0 1 12 7a4.4 4.4 0 0 1 8 2.4C20 15.3 12 20 12 20z"/>'),
    dernekKur: sv('<path d="M4 21V9l8-5 8 5v12M9 21v-6h6v6"/><path d="M12 8v4M10 10h4"/>'),
    kimlik: sv('<rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="9" cy="11" r="2.3"/><path d="M5.8 16c.6-1.6 1.8-2.4 3.2-2.4s2.6.8 3.2 2.4M14.5 10h4M14.5 13.5h3"/>'),
    ayar: sv('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>'),
    kapat: sv('<path d="M6 6l12 12M18 6L6 18"/>'),
    ok: sv('<path d="M9 6l6 6-6 6"/>'),
    ekonomi: sv('<path d="M3 20h18"/><path d="M5 16l4.5-5 3.5 3 6-7"/><path d="M15 7h4v4"/>'),
    sandik: sv('<path d="M4 11h16v9H4zM8 11l3-6h6l-3 6M9 15h6"/>'),
    arti: sv('<path d="M12 5v14M5 12h14"/>'),
    grafik: sv('<path d="M4 20h16"/><rect x="5.5" y="11" width="3" height="6" rx="1"/><rect x="10.5" y="6" width="3" height="11" rx="1"/><rect x="15.5" y="9" width="3" height="8" rx="1"/>'),
    canta: sv('<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7M3 13h18"/>'),
    bina: sv('<path d="M4 21V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v16M15 9h4a1 1 0 0 1 1 1v11M3 21h18"/><path d="M8 8h3M8 12h3M8 16h3"/>'),
    fis: sv('<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6M9 16h3"/>'),
    tabela: sv('<path d="M12 3v3M5 6h14l2 4-2 4H5z"/><path d="M12 14v7"/>'),
    dukkan: sv('<path d="M4 9l1.5-5h13L20 9M4 9v11h16V9M4 9h16"/><path d="M4 9a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0 2.7 2.7 0 0 0 5.3 0M10 20v-5h4v5"/>'),
    liste: sv('<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M9 10h6M9 14h6M9 18h3"/>'),
    klasor: sv('<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'),
    belge: sv('<path d="M7 3h7l5 5v12a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z"/><path d="M14 3v5h5M9 13h7M9 17h5"/>'),
    terazi: sv('<path d="M12 3v18M7 21h10M5 7h14M5 7l-3 6a3 3 0 0 0 6 0zM19 7l-3 6a3 3 0 0 0 6 0z"/>'),
    insaat: sv('<path d="M3 21h18M6 21V10l6-4 6 4v11"/><path d="M4 6l8-3 8 3M10 21v-5h4v5"/>'),
    trend: sv('<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>'),
    dusus: sv('<path d="M3 7l6 6 4-4 8 8"/><path d="M15 17h6v-6"/>'),
    roket: sv('<path d="M12 15l-3-3a13 13 0 0 1 9-8.5c.4 4-1.3 7-6 11.5z"/><path d="M9 12H5l2-4h4M12 15v4l4-2v-4M6 18c-1 1-1.5 2.5-1.5 2.5S6 20 7 19"/>'),
    ev: sv('<path d="M4 11l8-7 8 7v9a1 1 0 0 1-1 1h-5v-6h-4v6H5a1 1 0 0 1-1-1z"/>'),
    kitap: sv('<path d="M4 5a2 2 0 0 1 2-2h12v15H6a2 2 0 0 0-2 2z"/><path d="M4 20a2 2 0 0 0 2 1h12v-3M9 7h5"/>'),
    hilal: sv('<path d="M14.5 4.5A8 8 0 1 0 14.5 19.5 6.5 6.5 0 1 1 14.5 4.5z"/><path d="M17 9.5l.9 1.9 2 .3-1.5 1.4.4 2-1.8-1-1.8 1 .4-2-1.5-1.4 2-.3z"/>'),
    cekic: sv('<rect x="10.2" y="2.6" width="6" height="10" rx="1.6" transform="rotate(45 13.2 7.6)"/><path d="M8.4 9.6l3.9 3.9M11.6 11.4L4 19"/><path d="M13 21.2h8M14.5 18.4h5"/>'),
    kart: sv('<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M3 10h18M7 15h4"/>'),
    etiket: sv('<path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9z"/><circle cx="7.5" cy="7.5" r="1.3"/>'),
    fabrika: sv('<path d="M3 21V10l5 3V10l5 3V10l5 3V4h3v17z"/><path d="M7 17h2M12 17h2M17 17h1"/>'),
    kutu: sv('<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M4 7.5L12 12l8-4.5M12 12v9"/>'),
    doviz: sv('<path d="M4 8h13l-3-3M20 16H7l3 3"/>'),
    anahtar: sv('<circle cx="8" cy="15" r="4"/><path d="M11 12l8-8M16 7l2 2M14 9l2 2"/>'),
    basak: sv('<path d="M12 21V9"/><path d="M12 9c-2-1-3-3-3-5 2 1 3 3 3 5zM12 9c2-1 3-3 3-5-2 1-3 3-3 5zM12 14c-2-1-4-2.5-4.5-5 2.5.5 4 2.5 4.5 5zM12 14c2-1 4-2.5 4.5-5-2.5.5-4 2.5-4.5 5z"/>'),
    tv: sv('<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M8 21h8M9 2l3 4 3-4"/>'),
    bilet: sv('<path d="M3 8a2 2 0 0 0 2-2h14a2 2 0 0 0 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 0-2 2H5a2 2 0 0 0-2-2v-2a2 2 0 0 0 0-4z"/><path d="M14 6v12" stroke-dasharray="2 2"/>'),
    sehir: sv('<path d="M3 21h18M5 21V10h5v11M10 21V4h6v17M16 21v-8h3v8"/><path d="M13 8h.01M13 12h.01M13 16h.01"/>'),
    madalya: sv('<circle cx="12" cy="15" r="5"/><path d="M8.5 11.5L6 3h4l2 5 2-5h4l-2.5 8.5"/><path d="M12 13v4"/>'),
    sepet: sv('<path d="M3 4h2l2.4 11.2a1 1 0 0 0 1 .8h9.2a1 1 0 0 0 1-.8L20 8H6.2"/><circle cx="9" cy="20" r="1.3"/><circle cx="17" cy="20" r="1.3"/>'),
    ozet: sv('<path d="M12 3l9 9-9 9-9-9z"/><path d="M12 8l4 4-4 4-4-4z"/>'),
    diger: sv('<circle cx="5.5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18.5" cy="12" r="1.6"/>'),
    bayrak: sv('<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>')
  };
  function ikon(k) {
    if (IK[k]) return IK[k];
    try { if (typeof IKON === 'object' && IKON && IKON[k]) return IKON[k]; } catch (e) {}
    return IK.menu;
  }

  /* ---------- bölüm kimlikleri (her bölümün banka kartı gibi kendi rengi) ---------- */
  var B = {
    gundem:  { ad: 'Gündem',   a1: '#d8425e', a2: '#3c1638', ik: 'gundem' },
    devlet:  { ad: 'Devlet',   a1: '#4469dc', a2: '#131c47', ik: 'devlet' },
    ekonomi: { ad: 'Ekonomi',  a1: '#1f9e86', a2: '#11363d', ik: 'ekonomi' },
    sohbet:  { ad: 'Sohbet',   a1: '#2e86de', a2: '#13284f', ik: 'sohbet' },
    hayat:   { ad: 'Hayat',    a1: '#8a68f2', a2: '#291f5c', ik: 'hayat' },
    meclis:  { ad: 'Meclis',   a1: '#16a0a6', a2: '#0f3442', ik: 'meclis' },
    adliye:  { ad: 'Adliye',   a1: '#c18a3e', a2: '#3f2c22', ik: 'adliye' },
    harita:  { ad: 'Türkiye',  a1: '#3a9fd6', a2: '#122c4a', ik: 'harita' },
    parti:   { ad: 'Partiler', a1: '#c03a6b', a2: '#36173a', ik: 'parti' },
    dernek:  { ad: 'Dernekler',a1: '#df7f45', a2: '#43241f', ik: 'dernek' },
    ben:     { ad: 'Profilim', a1: '#6e7fb8', a2: '#20284a', ik: 'ben' },
    belediye:{ ad: 'Belediye', a1: '#2f9e64', a2: '#123a2c', ik: 'devlet' },
    yonetim: { ad: 'Devlet',   a1: '#4469dc', a2: '#131c47', ik: 'devlet' }
  };
  var ANA = ['gundem', 'devlet', 'MENU', 'ekonomi', 'sohbet'];
  function aktifSekme() { var d = Dx(); var k = d && d.sekme || 'gundem'; return k === 'yonetim' || k === 'belediye' || k === 'bakanlik' ? 'devlet' : k; }
  function bolum(k) {
    var b = B[k] || B.gundem;
    if (k === 'parti' || k === 'ben') {
      var p = profil(), r = p && p.parti && p.parti.renk;
      if (r && /^#[0-9a-f]{6}$/i.test(r)) return { ad: b.ad, ik: b.ik, a1: karis(r, '#ffffff', .08), a2: karis(r, '#0c1230', .78) };
    }
    return b;
  }

  /* ---------- gravür (guilloché) deseni: banknot / kimlik kartı dokusu ---------- */
  function gilosSvg(renk, kalin) {
    var p = [], cx = 330, cy = 70, i, j, t, r, x, y, d;
    for (j = 0; j < 9; j++) {                       // rozet halkaları
      d = '';
      for (i = 0; i <= 240; i++) {
        t = i / 240 * Math.PI * 2;
        r = 46 + j * 3.1 + 9 * Math.sin(12 * t + j * .42) + 3 * Math.cos(5 * t - j * .3);
        x = cx + r * Math.cos(t); y = cy + r * Math.sin(t);
        d += (i ? 'L' : 'M') + x.toFixed(1) + ' ' + y.toFixed(1);
      }
      p.push('<path d="' + d + 'Z"/>');
    }
    for (j = 0; j < 14; j++) {                      // banknot dalgaları
      d = ''; var y0 = 120 + j * 7.5;
      for (i = 0; i <= 80; i++) { x = i * 5.2; y = y0 + 4.5 * Math.sin(x / 21 + j * .55) + 2 * Math.sin(x / 7.5 - j); d += (i ? 'L' : 'M') + x.toFixed(1) + ' ' + y.toFixed(1); }
      p.push('<path d="' + d + '"/>');
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 420 230" fill="none" stroke="' + renk + '" stroke-width="' + (kalin || .7) + '">' + p.join('') + '</svg>';
  }
  function svgUrl(s) { return 'url("data:image/svg+xml;charset=utf-8,' + encodeURIComponent(s) + '")'; }

  /* ---------- stiller ---------- */
  var CSS = [
    '@property --pa-glow{syntax:"<color>";inherits:true;initial-value:rgba(123,97,255,.18)}',
    ':root{--pa-a1:#7b61ff;--pa-a2:#1d2850;--pa-glow:rgba(123,97,255,.18);transition:--pa-glow .6s ease}',
    /* ortam ışığı: bölüm değişince renk yavaşça döner */
    '#app::before{content:"";position:absolute;inset:0;z-index:-1;pointer-events:none;background:radial-gradient(110% 48% at 50% -10%,var(--pa-glow),transparent 72%)}',
    '.ust{background:rgba(12,18,42,.62)!important}',
    '@media (min-width:361px){.ust h1{font-size:28px!important;letter-spacing:-.3px!important}}',

    /* ===== 5'li alt menü ===== */
    'nav.sekmeler.pa-nav{display:grid!important;grid-template-columns:repeat(5,1fr);overflow:visible!important;padding:7px 6px var(--safeB)!important;gap:0;background:rgba(9,14,34,.86)!important;-webkit-backdrop-filter:saturate(170%) blur(20px);backdrop-filter:saturate(170%) blur(20px);border-top:1px solid rgba(164,184,255,.10)!important;box-shadow:0 -12px 30px -18px rgba(0,0,0,.8)}',
    'nav.sekmeler.pa-nav>button{all:unset;box-sizing:border-box;position:relative;display:flex!important;flex-direction:column;align-items:center;justify-content:flex-start;gap:4px;min-width:0!important;padding:3px 0 2px!important;cursor:pointer;color:#7f8aae;font:600 11px/1.15 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;letter-spacing:0;-webkit-tap-highlight-color:transparent}',
    'nav.sekmeler.pa-nav>button::before{display:none!important}',
    'nav.sekmeler.pa-nav .pa-ni{position:relative;display:grid;place-items:center;width:46px;height:30px;border-radius:999px;transition:background .22s,color .22s,transform .22s}',
    'nav.sekmeler.pa-nav .pa-ni svg{width:22px!important;height:22px!important;padding:0!important;background:none!important;box-shadow:none!important}',
    'nav.sekmeler.pa-nav .pa-nl{max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    'nav.sekmeler.pa-nav>button.aktif{color:#fff}',
    'nav.sekmeler.pa-nav>button.aktif .pa-ni{background:linear-gradient(180deg,' + 'rgba(255,255,255,.16),rgba(255,255,255,.07));box-shadow:inset 0 0 0 1px rgba(255,255,255,.14);color:#fff}',
    'nav.sekmeler.pa-nav>button:active .pa-ni{transform:scale(.92)}',
    'nav.sekmeler.pa-nav>button:focus-visible .pa-ni{outline:2px solid #a895ff;outline-offset:2px}',
    'nav.sekmeler.pa-nav>button.mesaj-var{color:#ff8a8f}',
    'nav.sekmeler.pa-nav .sayi{position:absolute!important;top:-5px!important;right:-2px!important;left:auto!important;min-width:19px;height:19px;font-size:11px;border:2px solid #0b1026!important}',
    'nav.sekmeler.pa-nav .pa-nokta{position:absolute;top:0;right:4px;width:9px;height:9px;border-radius:50%;background:#34c98a;border:2px solid #0b1026;box-shadow:0 0 0 3px rgba(52,201,138,.25)}',
    /* orta "Menü" mücevheri */
    'nav.sekmeler.pa-nav>button.pa-orta .pa-ni{width:54px;height:54px;margin-top:-23px;border-radius:19px;color:#fff;background:linear-gradient(145deg,var(--pa-o1,#8b73ff),var(--pa-o2,#4b37c9));box-shadow:0 10px 22px -8px var(--pa-o1,#7b61ff),inset 0 1px 0 rgba(255,255,255,.35),inset 0 0 0 1px rgba(255,255,255,.14),0 0 0 5px rgba(9,14,34,.92)}',
    'nav.sekmeler.pa-nav>button.pa-orta .pa-ni svg{width:24px!important;height:24px!important}',
    'nav.sekmeler.pa-nav>button.pa-orta.aktif .pa-ni{background:linear-gradient(145deg,var(--pa-o1),var(--pa-o2))}',
    'nav.sekmeler.pa-nav>button.pa-orta .pa-nl{margin-top:1px}',
    'nav.sekmeler.pa-nav>button.pa-orta.aktif .pa-nl{color:#fff}',

    /* ===== Menü çekmecesi ===== */
    '#paMenu{position:fixed;inset:0;z-index:80;display:flex;flex-direction:column;justify-content:flex-end}',
    '#paMenu[hidden]{display:none}',
    '#paMenu .pa-perde{position:absolute;inset:0;background:rgba(4,7,20,.58);-webkit-backdrop-filter:blur(5px);backdrop-filter:blur(5px);animation:paSoluk .25s ease both}',
    '#paMenu .pa-cekmece{position:relative;max-height:88vh;min-height:min(80vh,660px);overflow-y:auto;-webkit-overflow-scrolling:touch;padding:10px 16px calc(var(--safeB,14px) + 14px);border-radius:28px 28px 0 0;background:linear-gradient(180deg,#19224a,#0f1636 46%);box-shadow:0 -24px 60px -20px rgba(0,0,0,.85),inset 0 1px 0 rgba(255,255,255,.10);animation:paYuksel .34s cubic-bezier(.2,.85,.25,1) both}',
    '#paMenu.kapaniyor .pa-cekmece{animation:paIn .22s ease-in both}#paMenu.kapaniyor .pa-perde{animation:paSoluk .22s ease reverse both}',
    '#paMenu .pa-tutamac{width:42px;height:5px;border-radius:5px;background:rgba(255,255,255,.22);margin:2px auto 12px}',
    '#paMenu .pa-cb{display:flex;align-items:center;gap:10px;margin-bottom:14px}',
    '#paMenu .pa-cb h2{flex:1;font:700 25px/1.1 var(--disp);letter-spacing:-.3px;color:#fff;margin:0}',
    '#paMenu .pa-kapat{all:unset;cursor:pointer;display:grid;place-items:center;width:38px;height:38px;border-radius:13px;background:rgba(255,255,255,.07);color:#c9d1e6;box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)}',
    '#paMenu .pa-kapat svg{width:19px;height:19px}',
    '#paMenu .pa-kim{all:unset;box-sizing:border-box;cursor:pointer;display:flex;align-items:center;gap:12px;width:100%;padding:12px;border-radius:20px;background:linear-gradient(135deg,var(--k1),var(--k2));position:relative;overflow:hidden;box-shadow:inset 0 0 0 1px rgba(255,255,255,.10),0 14px 28px -18px var(--k1)}',
    '#paMenu .pa-kim::before{content:"";position:absolute;inset:0;background:var(--pa-gilos) right -120px top -40px/420px auto no-repeat;opacity:.2}',
    '#paMenu .pa-kim .pa-pp{position:relative;width:52px;height:52px;border-radius:16px;overflow:hidden;flex:none;box-shadow:0 0 0 2px rgba(255,255,255,.35)}',
    '#paMenu .pa-kim .pa-pp svg,#paMenu .pa-kim .pa-pp .portre{width:100%!important;height:100%!important;display:block}',
    '#paMenu .pa-kim .pa-km{position:relative;flex:1;min-width:0;color:#fff}',
    '#paMenu .pa-kim b{display:block;font:700 20px/1.1 var(--disp);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '#paMenu .pa-kim small{display:block;margin-top:3px;font-size:12.5px;opacity:.82;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '#paMenu .pa-kim .pa-cz{position:relative;padding:7px 10px;border-radius:12px;background:rgba(0,0,0,.22);color:#fff;font:700 14px/1 var(--disp);white-space:nowrap}',
    '#paMenu .pa-ara{display:flex;align-items:center;gap:10px;margin-top:14px;padding:0 14px;height:50px;border-radius:16px;background:rgba(6,10,28,.55);box-shadow:inset 0 0 0 1px rgba(164,184,255,.16);cursor:text}',
    '#paMenu .pa-ara:focus-within{box-shadow:inset 0 0 0 1.5px #a895ff,0 0 0 4px rgba(123,97,255,.18)}',
    '#paMenu .pa-ara-simge{display:grid;place-items:center;color:#8f9bc0;flex:none}',
    '#paMenu .pa-ara-simge svg{width:20px;height:20px}',
    '#paMenu .pa-ara input{all:unset;flex:1;min-width:0;height:100%;font-size:16px;color:#f2f5ff}',
    '#paMenu .pa-ara input::placeholder{color:#7f8aae}',
    '#paMenu .pa-ara input::-webkit-search-cancel-button{-webkit-appearance:none}',
    '#paMenu .pa-ara-sonuc{margin-top:12px;display:flex;flex-direction:column;gap:7px}',
    '#paMenu .pa-ara-sonuc[hidden],#paMenu #paGruplar[hidden]{display:none}',
    '#paMenu .pa-ara-bas{margin:2px 2px 2px;font-size:12.5px;font-weight:650;color:#8f9bc0}',
    '#paMenu .pa-ara-satir{all:unset;box-sizing:border-box;cursor:pointer;display:flex;align-items:center;gap:12px;width:100%;padding:10px 12px;border-radius:16px;background:linear-gradient(170deg,#1f2950,#161e3e);box-shadow:inset 0 0 0 1px rgba(164,184,255,.09)}',
    '#paMenu .pa-ara-satir:active{transform:scale(.985)}',
    '#paMenu .pa-ara-satir:focus-visible{box-shadow:inset 0 0 0 2px #a895ff}',
    '#paMenu .pa-ara-satir.oyuncu{margin-top:4px;background:rgba(46,134,222,.10);box-shadow:inset 0 0 0 1px rgba(46,134,222,.30)}',
    '#paMenu .pa-ara-ik{flex:none;display:grid;place-items:center;width:40px;height:40px;border-radius:13px;color:#fff;background:linear-gradient(145deg,var(--k1),var(--k2));box-shadow:inset 0 1px 0 rgba(255,255,255,.26)}',
    '#paMenu .pa-ara-ik svg{width:20px;height:20px}',
    '#paMenu .pa-ara-orta{flex:1;min-width:0}',
    '#paMenu .pa-ara-orta b{display:block;font-size:15px;font-weight:700;color:#f2f5ff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '#paMenu .pa-ara-orta small{display:block;margin-top:2px;font-size:12px;color:#8f9bc0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '#paMenu .pa-ara-grp{flex:none;padding:3px 8px;border-radius:999px;background:rgba(255,255,255,.06);font-size:11px;font-weight:650;color:#aab4d4}',
    '#paMenu .pa-ara-bos{margin:4px 2px;font-size:13.5px;line-height:1.45;color:#aab4d4}',
    '#paMenu .pa-grup{margin-top:18px}',
    '#paMenu .pa-grup>h3{margin:0 2px 9px;font-size:13px;font-weight:650;color:#8f9bc0;letter-spacing:.1px}',
    '#paMenu .pa-izgara{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:9px}',
    '#paMenu .pa-karo{all:unset;box-sizing:border-box;cursor:pointer;position:relative;display:flex;flex-direction:column;gap:9px;min-height:104px;padding:12px 11px 11px;border-radius:18px;background:linear-gradient(160deg,#1f2950,#161e3e);box-shadow:inset 0 0 0 1px rgba(164,184,255,.09);transition:transform .15s,box-shadow .15s;overflow:hidden}',
    '#paMenu .pa-karo::after{content:"";position:absolute;right:-26px;bottom:-26px;width:74px;height:74px;border-radius:50%;background:radial-gradient(circle,var(--k1),transparent 70%);opacity:.22}',
    '#paMenu .pa-karo:active{transform:scale(.96)}',
    '#paMenu .pa-karo:focus-visible{box-shadow:inset 0 0 0 2px #a895ff}',
    '#paMenu .pa-karo.aktif{box-shadow:inset 0 0 0 1.5px var(--k1),0 10px 22px -16px var(--k1)}',
    '#paMenu .pa-karo .pa-ki{display:grid;place-items:center;width:38px;height:38px;border-radius:13px;color:#fff;background:linear-gradient(145deg,var(--k1),var(--k2));box-shadow:inset 0 1px 0 rgba(255,255,255,.28),0 8px 16px -10px var(--k1)}',
    '#paMenu .pa-karo .pa-ki svg{width:20px;height:20px}',
    '#paMenu .pa-karo b{font-size:14px;font-weight:700;color:#f2f5ff;line-height:1.2}',
    '#paMenu .pa-karo small{display:block;margin-top:2px;font-size:11.5px;color:#8f9bc0;line-height:1.3}',
    '#paMenu .pa-karo .sayi,#paMenu .pa-karo .pa-rz{position:absolute;top:9px;right:9px;min-width:20px;height:20px;padding:0 6px;border-radius:10px;background:#f0454b;color:#fff;font-size:11.5px;font-weight:800;display:grid;place-items:center}',
    '#paMenu .pa-karo .pa-rz.yesil{background:#21a874}',
    '#paMenu .pa-alt{margin-top:18px;text-align:center;font-size:12px;color:#6e7a9c}',
    '@keyframes paYuksel{from{transform:translateY(100%)}to{transform:none}}',
    '@keyframes paIn{to{transform:translateY(100%)}}',
    '@keyframes paSoluk{from{opacity:0}to{opacity:1}}',

    /* ===== Kurum kartı (bölüm başlığı) ===== */
    '.pa-hero{position:relative;overflow:hidden;isolation:isolate;border-radius:24px;padding:17px 18px 16px;margin:0 0 12px;color:#fff;background:linear-gradient(135deg,var(--a1) 0%,' + 'var(--a2) 82%);box-shadow:0 20px 36px -24px var(--a1),inset 0 1px 0 rgba(255,255,255,.20),inset 0 0 0 1px rgba(255,255,255,.08)}',
    '.pa-hero::before{content:"";position:absolute;inset:0;z-index:-1;background:var(--pa-gilos) right -46px top -26px/430px auto no-repeat;opacity:.24;pointer-events:none}',
    '.pa-hero::after{content:"";position:absolute;inset:0;z-index:-1;background:radial-gradient(70% 90% at 0% 0%,rgba(255,255,255,.14),transparent 60%);pointer-events:none}',
    '.pa-hero.pa-giris .pa-isilti{position:absolute;inset:0;pointer-events:none;background:linear-gradient(105deg,transparent 30%,rgba(255,255,255,.26) 48%,transparent 66%);transform:translateX(-130%);animation:paIsilti 1.15s .2s cubic-bezier(.3,.7,.2,1) both}',
    '.pa-hero.pa-giris{animation:paKalk .55s cubic-bezier(.2,.8,.2,1) both}',
    '@keyframes paIsilti{to{transform:translateX(130%)}}',
    '@keyframes paKalk{from{opacity:0;transform:translateY(10px) scale(.985)}to{opacity:1;transform:none}}',
    '.pa-hero .pa-ust{position:relative;padding-right:84px;min-height:58px}',
    '.pa-hero.genis .pa-ust{padding-right:0}',
    '.pa-hero .pa-ust small{display:block;font-size:12.5px;font-weight:600;color:rgba(255,255,255,.80);letter-spacing:.1px}',
    '.pa-hero .pa-ust b{display:block;margin-top:3px;font:700 27px/1.05 var(--disp);letter-spacing:-.4px;overflow-wrap:anywhere}',
    '.pa-hero .pa-ust b.buyuk{font-size:40px;letter-spacing:-.8px;margin-top:4px}',
    '.pa-hero .pa-ust p{margin:6px 0 0;font-size:13px;line-height:1.4;color:rgba(255,255,255,.84)}',
    '.pa-hero .pa-cipler{display:flex;flex-wrap:wrap;gap:6px;margin-top:9px}',
    '.pa-hero .pa-cip{display:inline-flex;align-items:center;gap:5px;padding:4px 9px;border-radius:999px;background:rgba(0,0,0,.20);box-shadow:inset 0 0 0 1px rgba(255,255,255,.14);font-size:12px;font-weight:650;color:#fff;white-space:nowrap}',
    '.pa-hero .pa-cip i{width:7px;height:7px;border-radius:50%;background:#7dffbf;box-shadow:0 0 0 3px rgba(125,255,191,.2)}',
    '.pa-hero .pa-cip.canli i{background:#ff6b70;box-shadow:0 0 0 3px rgba(255,107,112,.25);animation:paNabiz 1.6s infinite}',
    '@keyframes paNabiz{50%{box-shadow:0 0 0 7px rgba(255,107,112,0)}}',
    '.pa-hero .pa-veri{display:grid;grid-template-columns:repeat(auto-fit,minmax(78px,1fr));gap:7px;margin-top:14px}',
    '.pa-hero .pa-veri>div{min-width:0;padding:8px 10px 9px;border-radius:13px;background:rgba(5,8,25,.22);box-shadow:inset 0 0 0 1px rgba(255,255,255,.09)}',
    '.pa-hero .pa-veri small{display:block;font-size:11.5px;color:rgba(255,255,255,.74);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.pa-hero .pa-veri b{display:block;margin-top:3px;font:700 18px/1.1 var(--disp);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-variant-numeric:tabular-nums}',
    '.pa-hero .pa-sag{position:absolute;top:15px;right:15px;width:74px;height:74px;display:grid;place-items:center}',
    '.pa-hero .pa-muhur{width:66px;height:66px;border-radius:50%;display:grid;place-items:center;background:radial-gradient(circle at 35% 30%,rgba(255,255,255,.28),rgba(255,255,255,.06) 60%);box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.38),0 0 0 5px rgba(255,255,255,.07)}',
    '.pa-hero .pa-muhur svg{width:34px;height:34px;color:#fff}',
    '.pa-hero .pa-muhur span{font:700 21px/1 var(--disp);letter-spacing:-.3px}',
    '.pa-hero .pa-halka{position:relative;width:74px;height:74px}',
    '.pa-hero .pa-halka svg{width:74px;height:74px;transform:rotate(-90deg)}',
    '.pa-hero .pa-halka .iz{stroke:rgba(255,255,255,.16)}',
    '.pa-hero .pa-halka .dolu{stroke:#fff;transition:stroke-dashoffset 1s cubic-bezier(.2,.8,.2,1)}',
    '.pa-hero .pa-halka div{position:absolute;inset:0;display:grid;place-content:center;text-align:center}',
    '.pa-hero .pa-halka div b{font:700 18px/1 var(--disp)}',
    '.pa-hero .pa-halka div small{font-size:10px;opacity:.8;margin-top:2px}',
        /* hızlı işlem şeridi (Mobil Şube'deki 4'lü düğmeler) */
    '.pa-hizli{display:grid;grid-template-columns:repeat(var(--n,4),minmax(0,1fr));gap:8px;margin:0 0 16px}',
    '.pa-hizli>button{all:unset;box-sizing:border-box;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:7px;padding:12px 4px 10px;border-radius:17px;text-align:center;background:linear-gradient(170deg,#1d2650,#151c3b);box-shadow:inset 0 0 0 1px rgba(164,184,255,.09),0 8px 18px -14px rgba(0,0,0,.9);transition:transform .14s,background .14s}',
    '.pa-hizli>button:active{transform:scale(.95)}',
    '.pa-hizli>button:focus-visible{box-shadow:inset 0 0 0 2px #a895ff}',
    '.pa-hizli .pa-hi{display:grid;place-items:center;width:36px;height:36px;border-radius:12px;color:var(--hc,#c9bdff);background:var(--hb,rgba(123,97,255,.20));box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)}',
    '.pa-hizli .pa-hi svg{width:19px;height:19px}',
    '.pa-hizli b{font-size:12px;font-weight:650;line-height:1.2;color:#e8ecf8;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}',
    '.pa-hizli small{display:block;font-size:10.5px;color:#8f9bc0;margin-top:-4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}',
    '.pa-hizli>button.ana .pa-hi{color:#fff;background:linear-gradient(145deg,var(--a1),var(--a2));box-shadow:0 8px 16px -10px var(--a1),inset 0 1px 0 rgba(255,255,255,.3)}',
    '.pa-hizli>button:disabled{opacity:.45;cursor:default}',
    '.pa-gizli{display:none!important}',

    /* ===== Kimlik kartı (Profilim) ===== */
    '.pa-kimlik{position:relative;overflow:hidden;isolation:isolate;border-radius:20px;margin:0 0 12px;padding:14px 16px 12px;color:#1b2140;min-height:214px;background:linear-gradient(125deg,#f6f3ee 0%,#eaf0fa 48%,' + '#f3e9ef 100%);box-shadow:0 22px 40px -26px var(--a1),0 0 0 1px rgba(255,255,255,.6) inset}',
    '.pa-kimlik::before{content:"";position:absolute;inset:0;z-index:-1;background:var(--pa-gilos-koyu) right -60px top -30px/460px auto no-repeat;opacity:.55}',
    '.pa-kimlik::after{content:"";position:absolute;left:0;right:0;top:0;height:6px;background:linear-gradient(90deg,var(--a1),var(--a2))}',
    '.pa-kimlik.pa-giris{animation:paKart .7s cubic-bezier(.2,.8,.2,1) both}',
    '@keyframes paKart{from{opacity:0;transform:perspective(900px) rotateX(14deg) translateY(12px)}to{opacity:1;transform:none}}',
    '.pa-kimlik .pa-kb{display:flex;justify-content:space-between;align-items:flex-start;gap:8px}',
    '.pa-kimlik .pa-kb small{display:block;font-size:9.5px;font-weight:800;letter-spacing:.9px;color:#56608a}',
    '.pa-kimlik .pa-kb b{display:block;font:700 15px/1.1 var(--disp);color:#1b2140;letter-spacing:.2px}',
    '.pa-kimlik .pa-kb .pa-cipi{width:38px;height:29px;border-radius:7px;background:linear-gradient(135deg,#e9cf8c,#b8913f 55%,#e7c978);box-shadow:inset 0 0 0 1px rgba(90,60,10,.35);position:relative}',
    '.pa-kimlik .pa-kb .pa-cipi::before{content:"";position:absolute;inset:6px 10px;border:1px solid rgba(90,60,10,.4);border-radius:3px}',
    '.pa-kimlik .pa-kg{display:flex;gap:13px;margin-top:10px}',
    '.pa-kimlik .pa-kf{width:76px;height:94px;border-radius:12px;overflow:hidden;flex:none;background:#dfe5f2;box-shadow:0 0 0 1px rgba(27,33,64,.15),0 6px 14px -8px rgba(27,33,64,.5)}',
    '.pa-kimlik .pa-kf svg,.pa-kimlik .pa-kf .portre{width:100%!important;height:100%!important;display:block;border-radius:0!important}',
    '.pa-kimlik .pa-kalan{flex:1;min-width:0;display:grid;grid-template-columns:1fr 1fr;gap:6px 10px;align-content:start}',
    '.pa-kimlik .pa-kalan>div{min-width:0}',
    '.pa-kimlik .pa-kalan .tam{grid-column:1/-1}',
    '.pa-kimlik .pa-kalan small{display:block;font-size:9px;font-weight:700;letter-spacing:.5px;color:#6a7398}',
    '.pa-kimlik .pa-kalan b{display:block;font-size:13.5px;font-weight:750;color:#151a36;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.pa-kimlik .pa-kalan b.ad{font:700 19px/1.1 var(--disp);letter-spacing:-.2px}',
    '.pa-kimlik .pa-mrz{margin-top:9px;font:600 10.5px/1.35 ui-monospace,"SFMono-Regular",Menlo,Consolas,monospace;letter-spacing:1.3px;color:#3a4266;white-space:nowrap;overflow:hidden;opacity:.85}',

    /* ===== Ortak bileşenler: Mobil Şube dili ===== */
    '.kart{border-radius:20px}',
    '.btn{border-radius:14px}',
    /* hap sekmeler */
    '#icerik .segment{display:flex!important;gap:6px;padding:0!important;background:none!important;box-shadow:none!important;overflow-x:auto;scrollbar-width:none;flex-wrap:nowrap}',
    '#icerik .segment::-webkit-scrollbar{display:none}',
    '#icerik .segment>button{flex:0 0 auto!important;padding:9px 15px!important;border-radius:999px!important;background:rgba(29,40,80,.72)!important;box-shadow:inset 0 0 0 1px rgba(164,184,255,.12)!important;color:#c9d1e6!important;font-weight:650;font-size:14px;white-space:nowrap;min-height:38px}',
    '#icerik .segment>button.aktif{background:#f4f6fb!important;color:#121a3a!important;box-shadow:0 6px 16px -10px rgba(255,255,255,.6)!important}',
    '#icerik>.so-tabs,#icerik :not(.so-ekonomi)>.so-tabs{gap:6px!important;padding:0!important;background:none!important;border:0!important;box-shadow:none!important;margin-bottom:12px!important}',
    '#icerik>.so-tabs>button,#icerik :not(.so-ekonomi)>.so-tabs>button{border-radius:999px!important;padding:9px 15px!important;min-height:38px!important;background:rgba(29,40,80,.72)!important;box-shadow:inset 0 0 0 1px rgba(164,184,255,.12)!important;color:#c9d1e6!important}',
    '#icerik>.so-tabs>button[aria-selected="true"],#icerik :not(.so-ekonomi)>.so-tabs>button[aria-selected="true"]{background:#f4f6fb!important;color:#121a3a!important}',
    '#icerik .sekme-cip>button{border-radius:999px}',
    '#icerik .sekme-cip>button.aktif{background:#f4f6fb;color:#121a3a}',
    /* menü merkezlerinin başlık kartı da kurum kartı olur */
    '#icerik .so-menu-hero{position:relative;overflow:hidden;isolation:isolate;border-radius:22px!important;border:0!important;background:linear-gradient(135deg,var(--pa-a1),var(--pa-a2) 85%)!important;box-shadow:0 18px 32px -24px var(--pa-a1),inset 0 1px 0 rgba(255,255,255,.18)!important;color:#fff}',
    '#icerik .so-menu-hero::before{content:"";position:absolute;inset:0;z-index:-1;background:var(--pa-gilos) right -60px top -40px/430px auto no-repeat;opacity:.22}',
    '#icerik .so-menu-hero h2{font-family:var(--disp);font-size:26px!important;letter-spacing:-.3px;color:#fff!important}',
    '#icerik .so-menu-hero p{color:rgba(255,255,255,.82)!important}',
    '#icerik .so-stats .so-stat{border-radius:16px!important;background:linear-gradient(170deg,#1d2650,#151c3b)!important;box-shadow:inset 0 0 0 1px rgba(164,184,255,.09)!important;border:0!important}',
    '#icerik .so-stats .so-stat b{font-family:var(--disp);font-size:24px}',
    /* tek düğmelik kartlar: sade bağlantı satırı */
    '#icerik>.kart:has(>.btn.altin:only-child),#icerik>.kart:has(>.btn.ikinci:only-child){padding:0;background:none!important;box-shadow:none!important;border:0}',
    '#icerik>.kart>.btn.altin:only-child,#icerik>.kart>.btn.ikinci:only-child{display:flex;align-items:center;justify-content:space-between;text-align:left;padding:15px 16px;border-radius:18px;background:linear-gradient(170deg,#1d2650,#151c3b)!important;box-shadow:inset 0 0 0 1px rgba(164,184,255,.10)!important;color:#eef1f8!important;font-weight:650}',
    '#icerik>.kart>.btn.altin:only-child::after,#icerik>.kart>.btn.ikinci:only-child::after{content:"›";font-size:22px;line-height:1;color:#8f9bc0;margin-left:10px}',
    /* Gündem'in basın kısayolları: daha derli toplu */
    '#icerik .so-gundem-kisa .so-kisa-kart{min-height:0!important;padding:12px!important;border-radius:17px!important;background:linear-gradient(170deg,#1d2650,#151c3b)!important;box-shadow:inset 0 0 0 1px rgba(164,184,255,.09)!important;border:0!important}',
    '#icerik .so-gundem-kisa .so-kisa-metin b{display:-webkit-box!important;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;line-height:1.2}',
    '#icerik .so-gundem-kisa .so-kisa-metin small{display:block!important;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    /* Makamım bölümlerindeki düğme yığınları: Mobil Şube satırları gibi */
    '#icerik .ynt-bolum>.btn{display:flex;align-items:center;justify-content:space-between;text-align:left;min-height:50px;padding:13px 16px;margin-top:8px;border-radius:15px;background:rgba(255,255,255,.045)!important;box-shadow:inset 0 0 0 1px rgba(164,184,255,.11)!important;color:#eef1f8!important;font-weight:650;font-size:15px}',
    '#icerik .ynt-bolum>.btn::after{content:"›";font-size:22px;line-height:1;color:#8f9bc0;margin-left:10px}',
    '#icerik .ynt-bolum>.btn.altin:first-of-type{background:linear-gradient(135deg,rgba(123,97,255,.30),rgba(123,97,255,.12))!important;box-shadow:inset 0 0 0 1px rgba(168,149,255,.32)!important}',
    '#icerik .so-gundem-kisa .so-kisa-metin{min-width:0}',
    '#icerik .so-gundem-kisa>.pa-hizli{margin-bottom:18px}',
    /* maaş kumbarası şeridi (Gündem) */
    '.pa-kumbara{position:relative;display:flex;align-items:center;gap:12px;margin:0 0 12px;padding:13px 14px;border-radius:20px;background:linear-gradient(135deg,#2a2160,#1a1d45 70%);box-shadow:inset 0 0 0 1px rgba(168,149,255,.22),0 14px 28px -20px #7b61ff;overflow:hidden}',
    '.pa-kumbara::before{content:"";position:absolute;inset:0;background:var(--pa-gilos) right -150px top -60px/420px auto no-repeat;opacity:.12;pointer-events:none}',
    '.pa-kumbara.dolu{background:linear-gradient(135deg,#136b55,#14324a 75%);box-shadow:inset 0 0 0 1px rgba(125,255,191,.35),0 16px 30px -18px #21c08b;animation:paKumbaraNabiz 2.4s ease-in-out infinite}',
    '@keyframes paKumbaraNabiz{50%{box-shadow:inset 0 0 0 1px rgba(125,255,191,.55),0 16px 34px -14px #2fe0a2}}',
    '.pa-kumbara .pa-kk{position:relative;flex:none;display:grid;place-items:center;width:48px;height:48px;border-radius:16px;color:#fff;background:linear-gradient(145deg,#9b7dff,#5a3fd6);box-shadow:inset 0 1px 0 rgba(255,255,255,.3),0 8px 18px -10px #7b61ff}',
    '.pa-kumbara.dolu .pa-kk{background:linear-gradient(145deg,#3fe0a6,#12936d);box-shadow:inset 0 1px 0 rgba(255,255,255,.35),0 8px 18px -8px #21c08b}',
    '.pa-kumbara .pa-kk svg{width:26px;height:26px}',
    '.pa-kumbara .pa-km{position:relative;flex:1;min-width:0}',
    '.pa-kumbara .pa-km small{display:block;font-size:12px;font-weight:650;color:rgba(255,255,255,.75)}',
    '.pa-kumbara .pa-km b{display:block;margin-top:1px;font:700 24px/1.1 var(--disp);color:#fff;letter-spacing:-.3px;font-variant-numeric:tabular-nums}',
    '.pa-kumbara .pa-kbar{height:6px;margin-top:6px;border-radius:6px;background:rgba(255,255,255,.14);overflow:hidden}',
    '.pa-kumbara .pa-kbar i{display:block;height:100%;border-radius:6px;background:linear-gradient(90deg,#a895ff,#ffffff)}',
    '.pa-kumbara.dolu .pa-kbar i{background:linear-gradient(90deg,#3fe0a6,#c8ffe9)}',
    '.pa-kumbara .pa-kalt{display:block;margin-top:5px;font-size:11.5px;color:rgba(255,255,255,.72);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.pa-kumbara .pa-topla{all:unset;box-sizing:border-box;position:relative;flex:none;cursor:pointer;padding:12px 18px;border-radius:14px;background:#fff;color:#2a1f6b;font-weight:800;font-size:15px;box-shadow:0 8px 18px -10px rgba(255,255,255,.7)}',
    '.pa-kumbara.dolu .pa-topla{background:linear-gradient(180deg,#5cf0bb,#22c48f);color:#06301f}',
    '.pa-kumbara .pa-topla:active{transform:scale(.95)}',
    '.pa-kumbara .pa-topla:disabled{opacity:.45;cursor:default;box-shadow:none}',
    '.pa-kumbara .pa-topla:focus-visible{outline:2px solid #fff;outline-offset:2px}',
    /* Hayat: asıl kumbara kartı kurum kartının hemen altında, büyük */
    '#icerik .olay.pa-kumbara-buyuk{margin:0 0 12px!important;padding:16px!important;border:0!important;border-radius:22px!important;background:linear-gradient(135deg,#2a2160,#181c44 75%)!important;box-shadow:inset 0 0 0 1px rgba(168,149,255,.22),0 16px 30px -22px #7b61ff!important}',
    '#icerik .olay.oy.pa-kumbara-buyuk{background:linear-gradient(135deg,#136b55,#14324a 75%)!important;box-shadow:inset 0 0 0 1px rgba(125,255,191,.35),0 16px 30px -18px #21c08b!important}',
    '#icerik .olay.pa-kumbara-buyuk .baslik b{font:700 19px/1.2 var(--disp)}',
    '#icerik .olay.pa-kumbara-buyuk .sayac{font:700 38px/1.1 var(--disp)!important;letter-spacing:-.6px;color:#fff}',
    '#icerik .olay.pa-kumbara-buyuk .bar{height:9px;border-radius:9px;background:rgba(255,255,255,.14)}',
    '#icerik .olay.pa-kumbara-buyuk .bar i{border-radius:9px;background:linear-gradient(90deg,#a895ff,#fff)!important}',
    '#icerik .olay.oy.pa-kumbara-buyuk .bar i{background:linear-gradient(90deg,#3fe0a6,#c8ffe9)!important}',
    '#icerik .olay.pa-kumbara-buyuk #hTopla{margin-top:12px;min-height:52px;font-size:17px;font-weight:800;border-radius:15px;background:#fff!important;color:#2a1f6b!important;box-shadow:0 10px 22px -12px rgba(255,255,255,.7)!important}',
    '#icerik .olay.oy.pa-kumbara-buyuk #hTopla{background:linear-gradient(180deg,#5cf0bb,#22c48f)!important;color:#06301f!important}',
    '#icerik .olay.pa-kumbara-buyuk #hTopla:disabled{opacity:.45}',
    /* cüzdan çipi: kumbara dolunca yeşil nokta */
    '.ust .para-cip.pa-kumbara-dolu{position:relative}',
    '.ust .para-cip.pa-kumbara-dolu::after{content:"";position:absolute;top:-3px;right:-3px;width:11px;height:11px;border-radius:50%;background:#34c98a;border:2px solid #0b1026;box-shadow:0 0 0 3px rgba(52,201,138,.28)}',
    /* simge kareleri */
    '#icerik .pa-ik{display:grid!important;place-items:center;flex:none;color:#fff!important;font-size:0!important;line-height:0;border-radius:14px!important;background:linear-gradient(145deg,var(--ik),var(--ik2))!important;box-shadow:inset 0 1px 0 rgba(255,255,255,.26),0 8px 16px -10px var(--ik)!important;border:0!important}',
    '#icerik .pa-ik svg{width:21px!important;height:21px!important;display:block;max-width:none!important;flex:none}',
    '#icerik .so-ms-front-icon.pa-ik svg{width:28px!important;height:28px!important}',
    '#icerik .so-link-ikon.pa-ik{width:44px!important;height:44px!important;min-width:44px}',
    '#icerik .so-econ-tile-icon.pa-ik{width:40px!important;height:40px!important}',
    '#icerik .so-makam-emoji.pa-ik{width:44px!important;height:44px!important}',
    '#icerik .so-kisa-simge.pa-ik{width:40px!important;height:40px!important;border-radius:13px!important}',
    '#icerik .so-ms-front-icon.pa-ik{width:58px!important;height:58px!important;border-radius:18px!important}',
    '#icerik .giris-satir>.yik.pa-ik{width:40px!important;height:40px!important}',
    /* satır kartları: Mobil Şube listeleri gibi */
    '#icerik .so-link,#icerik .so-makam-btn{border-radius:18px!important;background:linear-gradient(170deg,#1d2650,#151c3b)!important;border:0!important;box-shadow:inset 0 0 0 1px rgba(164,184,255,.10),0 8px 18px -16px rgba(0,0,0,.9)!important;transition:transform .14s}',
    '#icerik .so-link:active,#icerik .so-makam-btn:active{transform:scale(.985)}',
    '#icerik .so-link b,#icerik .so-makam-btn b{color:#f2f5ff}',
    /* Ekonomi üst sekmeleri: simgeli karo şerit, yapışkan ve tam genişlik */
    '#icerik .so-ekonomi>.so-tabs{position:sticky!important;top:0!important;z-index:9!important;display:flex!important;gap:4px!important;overflow-x:auto!important;scrollbar-width:none;margin:14px -16px 12px!important;padding:8px 12px 9px!important;border-radius:0!important;border:0!important;border-bottom:1px solid rgba(164,184,255,.10)!important;background:rgba(11,16,38,.94)!important;-webkit-backdrop-filter:saturate(160%) blur(16px);backdrop-filter:saturate(160%) blur(16px);box-shadow:0 -14px 0 0 #0d1431,0 12px 20px -18px rgba(0,0,0,.9)!important}',
    '#icerik .so-ekonomi>.so-tabs::-webkit-scrollbar{display:none}',
    '#icerik .so-ekonomi>.so-tabs>button{flex:0 0 auto!important;display:flex!important;flex-direction:column!important;align-items:center!important;gap:6px!important;min-width:72px!important;min-height:0!important;padding:6px 6px 7px!important;border-radius:16px!important;background:transparent!important;border:0!important;box-shadow:none!important;color:#9aa6c8!important;font-size:12px!important;font-weight:650!important;transform:none!important}',
    '#icerik .so-ekonomi>.so-tabs>button[aria-selected="true"]{background:rgba(255,255,255,.06)!important;color:#fff!important;box-shadow:inset 0 0 0 1px rgba(255,255,255,.10)!important}',
    '#icerik .so-ekonomi>.so-tabs .so-econ-tab-icon.pa-ik{width:40px!important;height:40px!important;margin:0!important;background:var(--ikt)!important;color:var(--ikc)!important;box-shadow:inset 0 0 0 1px rgba(255,255,255,.07)!important;transition:background .2s,box-shadow .2s}',
    '#icerik .so-ekonomi>.so-tabs>button[aria-selected="true"] .so-econ-tab-icon.pa-ik{background:linear-gradient(145deg,var(--ik),var(--ik2))!important;color:#fff!important;box-shadow:inset 0 1px 0 rgba(255,255,255,.3),0 8px 18px -8px var(--ik)!important}',
    '#icerik .so-ekonomi>.so-tabs>button:active .so-econ-tab-icon{transform:scale(.92)}',
    '@media (prefers-reduced-motion:reduce){.pa-kumbara.dolu,.pa-hero.pa-giris,.pa-kimlik.pa-giris,.pa-hero .pa-isilti,#paMenu .pa-cekmece,#paMenu .pa-perde{animation:none!important}}',
    '@media (max-width:360px){.ust h1{font-size:22px!important}.pa-hero{padding:15px 14px 14px}.pa-hero .pa-veri>div{padding:7px 8px 8px}.pa-hero .pa-veri b{font-size:16px}.pa-hero .pa-ust b{font-size:24px}.pa-hero .pa-ust b.buyuk{font-size:34px}.pa-hizli{gap:6px}.pa-hizli b{font-size:11px}.pa-kimlik .pa-kf{width:64px;height:80px}.pa-kimlik .pa-kalan b{font-size:12.5px}.pa-kimlik .pa-kalan b.ad{font-size:17px}#paMenu .pa-izgara{gap:7px}#paMenu .pa-karo{padding:10px 9px;min-height:96px}}'
  ].join('\n');

  function stilKur() {
    if (document.getElementById('so-premium-arayuz-css')) return;
    var st = document.createElement('style'); st.id = 'so-premium-arayuz-css'; st.textContent = CSS;
    (document.head || document.documentElement).appendChild(st);
    var r = document.documentElement.style;
    r.setProperty('--pa-gilos', svgUrl(gilosSvg('#ffffff', .7)));
    r.setProperty('--pa-gilos-koyu', svgUrl(gilosSvg('#7d88b8', .55)));
  }

  /* ---------- RPC sonuçlarını pasifçe hatırla (yeni çağrı yapmaz) ---------- */
  function apiSar() {
    try {
      if (typeof API === 'undefined' || !API || typeof API.rpc !== 'function' || API.rpc.__pa) return;
      var asil = API.rpc;
      var sar = function (fn) {
        var p = asil.apply(this, arguments);
        if (p && typeof p.then === 'function') p.then(function (r) { if (r && typeof r === 'object') SON[fn] = r; }, function () {});
        return p;
      };
      sar.__pa = true; API.rpc = sar;
    } catch (e) {}
  }

  /* ---------- eylemler (onclick'ler buradan geçer) ---------- */
  function ac(fn) { var e = g('ekranAc'); if (e) e(fn); else fn(); }
  function git(k) { var s = g('sekmeAc'); if (s) s(k); }
  function hata() { var t = g('toast'); if (t) t('Bu bölüm şu an açılamadı. Sayfayı yenileyip yeniden dene.', true); }
  var EYLEM = {
    sekme: function (k) { git(k); },
    mobilSube: function () { var f = g('mobilSubeEkrani'); f ? ac(function () { return f(); }) : hata(); },
    ilan: function () { var f = g('ilanMeydaniEkrani'); f ? ac(f) : hata(); },
    magaza: function () { var f = g('magazaEkrani'); f ? ac(f) : hata(); },
    muzayede: function () { var f = g('muzayedeEkrani'); f ? ac(f) : hata(); },
    bildirim: function () { var f = g('bildirimEkrani'); f ? ac(f) : hata(); },
    yonetici: function () { var f = g('yoneticiEkrani'); f ? ac(f) : hata(); },
    ara: function () { var f = g('oyuncuAramaAc'); f ? f() : hata(); },
    seslenis: function () { var f = g('cbUlusaSeslenislerEkrani'); f ? ac(f) : hata(); },
    kriz: function () { var f = g('krizMerkeziEkrani'); f ? ac(f) : hata(); },
    gazete: function () { var d = Dx(), f = g('devletEkrani'); if (d) d.devletSekme = 'gazete'; f ? f() : git('devlet'); },
    kanun: function () { var f = g('kanunTeklifEkrani'); f ? ac(function () { return f(); }) : hata(); },
    meclisSekme: function (s) { var d = Dx(); if (d && d.sekme !== 'meclis') git('meclis'); var f = g('meclisSekmeAc'); if (f) f(s); },
    sohbet: function (k) { var f = g('sohbetEkrani'); f ? ac(function () { return f(k); }) : hata(); },
    yeniMesaj: function () { var f = g('yeniOzelModal'); f ? f() : hata(); },
    cevrimici: function () { var f = g('cevrimiciListeAc'); f ? f() : hata(); },
    partim: function (id) { var f = g('partiDetay'); f ? ac(function () { return f(id); }) : hata(); },
    koalisyon: function () { var f = g('koalisyonPazarlikEkrani'); f ? ac(f) : hata(); },
    kurucu: function () { var f = g('kurucuDavetModal'); f ? f() : hata(); },
    ilim: function (id) { var f = g('ilDetay'); f ? f(id) : hata(); },
    sosyal: function () { var f = g('stkSosyalVitrin'); f ? ac(f) : hata(); },
    dernekKur: function () { var f = g('stkKurModal'); f ? f() : hata(); },
    portre: function () { var f = g('portreModal'); f ? f() : hata(); },
    secmen: function () { var f = g('vatandaslikModal'); f ? f() : hata(); },
    gorev: function () { var f = g('gorevEkrani'); f ? ac(f) : hata(); },
    tikla: function (id) { var el = document.getElementById(id); if (el && !el.disabled) el.click(); else if (el) { var t = g('toast'); if (t) t('Şu an kullanılamıyor.'); } },
    kaydir: function (sec) { var el = document.querySelector(sec); if (el) el.scrollIntoView({ behavior: azHareket() ? 'auto' : 'smooth', block: 'start' }); },
    topla: function () { toplaEylem(); },
    akis: function () { var f = g('akisEkrani'); f ? ac(function () { return f(); }) : hata(); }
  };
  window.soPa = function (ad) { var a = [].slice.call(arguments, 1); try { menuKapat(true); if (EYLEM[ad]) EYLEM[ad].apply(null, a); } catch (e) { if (window.console) console.warn('Premium arayüz:', e); hata(); } };
  function on(ad) { var a = [].slice.call(arguments, 1).map(function (x) { return JSON.stringify(x).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;'); }); return 'soPa(&quot;' + ad + '&quot;' + (a.length ? ',' + a.join(',') : '') + ')'; }

  /* ---------- emoji simgeler → çizgi simge + renkli kare (Mobil Şube / Menü dili) ---------- */
  var R = { para: '#1f9e86', is: '#d9932b', mulk: '#df7f45', devlet: '#4469dc', kisi: '#8a68f2', medya: '#d8425e', mavi: '#2e86de', pembe: '#c03a6b', gri: '#7b8bb8', yesil: '#2f9e64', bordo: '#b33a5c' };
  var EMO = {
    '➕': ['arti', R.kisi], '🤝': ['el', R.kisi], '📊': ['grafik', R.mavi], '💼': ['canta', R.para], '🏢': ['bina', R.is], '🏬': ['bina', R.is],
    '🏦': ['banka', R.bordo], '🏛': ['devlet', R.devlet], '🧾': ['fis', R.para], '📄': ['belge', R.devlet], '📒': ['kitap', R.para], '🪧': ['tabela', R.mulk],
    '🏪': ['dukkan', R.is], '🛍': ['magaza', R.is], '📋': ['liste', R.devlet], '📝': ['kalem', R.devlet], '💸': ['para', R.para], '📂': ['klasor', R.devlet],
    '📁': ['klasor', R.devlet], '📥': ['klasor', R.mavi], '📜': ['belge', R.devlet], '⚖': ['terazi', '#c18a3e'], '👩‍⚖': ['terazi', '#c18a3e'], '🧑‍⚖': ['terazi', '#c18a3e'],
    '🏗': ['insaat', R.mulk], '📈': ['trend', R.yesil], '📉': ['dusus', R.bordo], '🚀': ['roket', R.pembe], '🏡': ['ev', R.mulk], '🏠': ['ev', R.mulk],
    '🛡': ['kalkan', R.devlet], '⚙': ['ayar', R.gri], '📢': ['megafon', R.medya], '📣': ['megafon', R.medya], '📚': ['kitap', R.medya], '🇹🇷': ['hilal', '#d8425e'],
    '🗳': ['sandik', '#16a0a6'], '🔨': ['cekic', R.is], '💳': ['kart', R.bordo], '💰': ['para', R.para], '💵': ['para', R.para], '🪙': ['para', '#c9a227'],
    '🏷': ['etiket', R.is], '🏭': ['fabrika', R.is], '📦': ['kutu', R.is], '💱': ['doviz', R.para], '🔑': ['anahtar', R.mulk], '🌾': ['basak', R.yesil],
    '📺': ['tv', R.medya], '🎟': ['bilet', R.pembe], '🏙': ['sehir', '#2f9e64'], '🏅': ['madalya', '#c9a227'], '📰': ['gazete', R.medya], '🏳': ['bayrak', null],
    '🛒': ['sepet', R.is], '◈': ['ozet', R.kisi], '✦': ['diger', R.gri], '🔍': ['ara', R.mavi], '🔎': ['ara', R.mavi], '🔔': ['zil', R.medya], '⚠': ['kriz', '#e0565b'],
    '🚨': ['kriz', '#e0565b'], '👥': ['kisiler', R.kisi], '👤': ['kisi', R.kisi], '🗺': ['harita', '#3a9fd6'], '💬': ['sohbet', R.mavi], '❤': ['kalp', R.pembe]
  };
  var TAB_RENK = { 'Özet': R.kisi, 'Şirketlerim': '#1f9e86', 'Ticaret': R.is, 'Bankalar': R.bordo, 'Yatırım': R.yesil, 'Emlak': R.mulk, 'Diğer': R.gri };
  var IK_SEC = '.so-econ-tab-icon,.so-econ-tile-icon,.so-link-ikon,.so-makam-emoji,.so-kisa-simge,.so-ms-front-icon,.giris-satir>.yik';
  function ikonlastir(kok) {
    if (!kok) return;
    var p = profil(), partiRenk = p && p.parti && /^#[0-9a-f]{6}$/i.test(p.parti.renk || '') ? p.parti.renk : '#8a68f2';
    kok.querySelectorAll(IK_SEC).forEach(function (el) {
      if (el.getAttribute('data-pa-ik')) return;
      if (el.querySelector('svg,img')) { el.setAttribute('data-pa-ik', 'svg'); return; }
      var t = (el.textContent || '').replace(/[\uFE0F\u200D\s]/g, function (c) { return c === '\u200D' ? '\u200D' : ''; }).trim();
      var e = EMO[t] || EMO[t.replace(/\u200D/g, '')] || EMO[Array.from(t)[0]];
      if (!e) return;
      var renk = e[1] || partiRenk;
      if (el.classList.contains('so-econ-tab-icon')) { var lb = el.parentElement && el.parentElement.getAttribute('aria-label'); if (lb && TAB_RENK[lb]) renk = TAB_RENK[lb]; }
      el.innerHTML = ikon(e[0]); el.setAttribute('data-pa-ik', e[0]); el.classList.add('pa-ik');
      el.style.setProperty('--ik', renk); el.style.setProperty('--ik2', karis(renk, '#0b1130', .55)); el.style.setProperty('--ikt', rgba(renk, .17)); el.style.setProperty('--ikc', karis(renk, '#ffffff', .5));
    });
  }

  /* ---------- kurum kartı parçaları ---------- */
  function veri(ls) { ls = ls.filter(function (x) { return x && x[1] != null && x[1] !== ''; }); return ls.length ? '<div class="pa-veri">' + ls.map(function (x) { return '<div><small>' + esc(x[0]) + '</small><b' + (x[2] != null ? ' data-pa-say="' + x[2] + '"' + (x[3] ? ' data-pa-tur="' + x[3] + '"' : '') : '') + '>' + esc(x[1]) + '</b></div>'; }).join('') + '</div>' : ''; }
  function cipler(ls) { ls = ls.filter(Boolean); return ls.length ? '<div class="pa-cipler">' + ls.join('') + '</div>' : ''; }
  function cip(t, tur) { return '<span class="pa-cip' + (tur ? ' ' + tur : '') + '">' + (tur ? '<i></i>' : '') + esc(t) + '</span>'; }
  function muhur(ic) { return '<div class="pa-sag"><div class="pa-muhur">' + ic + '</div></div>'; }
  function halka(oran, ust, alt) {
    oran = Math.max(0, Math.min(1, sayi(oran))); var c = 2 * Math.PI * 31;
    return '<div class="pa-sag"><div class="pa-halka"><svg viewBox="0 0 74 74"><circle class="iz" cx="37" cy="37" r="31" fill="none" stroke-width="6.5"/><circle class="dolu" cx="37" cy="37" r="31" fill="none" stroke-width="6.5" stroke-linecap="round" stroke-dasharray="' + c.toFixed(1) + '" stroke-dashoffset="' + (c * (1 - oran)).toFixed(1) + '" data-pa-halka="' + (c * (1 - oran)).toFixed(1) + '"/></svg><div><b>' + esc(ust) + '</b><small>' + esc(alt) + '</small></div></div></div>';
  }
  function hero(k, o) {
    var b = bolum(k);
    return '<section class="pa-hero' + (o.sag ? '' : ' genis') + '" data-pa-hero="' + k + '" style="--a1:' + b.a1 + ';--a2:' + b.a2 + '"><span class="pa-isilti" aria-hidden="true"></span>' +
      (o.sag || '') + '<div class="pa-ust"><small>' + esc(o.ust) + '</small><b' + (o.buyuk ? ' class="buyuk"' : '') + (o.sayac != null ? ' data-pa-say="' + o.sayac + '" data-pa-tur="tl"' : '') + '>' + esc(o.baslik) + '</b>' + (o.alt ? '<p>' + esc(o.alt) + '</p>' : '') + (o.cip || '') + '</div>' + (o.veri || '') + '</section>';
  }
  function hizli(k, ls) {
    ls = ls.filter(Boolean); if (!ls.length) return '';
    var b = bolum(k);
    return '<div class="pa-hizli" data-pa-hizli="' + k + '" style="--n:' + ls.length + ';--a1:' + b.a1 + ';--a2:' + b.a2 + ';--hb:' + rgba(b.a1, .2) + ';--hc:' + karis(b.a1, '#ffffff', .45) + '">' +
      ls.map(function (x, i) { return '<button type="button" class="' + (i === 0 ? 'ana' : '') + '" onclick="' + x[2] + '"' + (x[4] ? ' disabled' : '') + '><span class="pa-hi">' + ikon(x[0]) + '</span><b>' + esc(x[1]) + '</b>' + (x[3] ? '<small>' + esc(x[3]) + '</small>' : '') + '</button>'; }).join('') + '</div>';
  }
  function rolYaz(p) {
    var m = (p.makamlar || [])[0], my = g('makamYaz');
    if (m && my) { try { return my(m); } catch (e) {} }
    if (p.gb) return 'Genel Başkan';
    if (p.gby) return 'Genel Başkan Yardımcısı';
    return 'Vatandaş';
  }
  function siradakiSecim(d) {
    var tk = (d && d.durum && d.durum.takvim) || [], simdi = Date.now(), TUR_AD = { mv: 'Genel seçim', mv_on: 'Vekil ön seçimi', cb: 'Cumhurbaşkanlığı', cb_on: 'CB ön seçimi', cb2: 'CB 2. tur', bel: 'Belediye seçimi', bel_on: 'Belediye ön seçimi', kurultay: 'Kurultay' };
    var acik = null, sonraki = null;
    tk.forEach(function (x) {
      var a = new Date(x.oy_bas).getTime(), b = new Date(x.oy_bit).getTime();
      if (a <= simdi && simdi <= b) acik = x;
      else if (a > simdi && (!sonraki || a < new Date(sonraki.oy_bas).getTime())) sonraki = x;
    });
    if (acik) return cip('Sandık açık · ' + (TUR_AD[acik.tur] || 'Seçim'), 'canli');
    if (sonraki) { var gun = Math.ceil((new Date(sonraki.oy_bas).getTime() - simdi) / 864e5); return cip((TUR_AD[sonraki.tur] || 'Seçim') + ' · ' + (gun <= 1 ? 'yarın' : gun + ' gün sonra'), 'yesil'); }
    return '';
  }

  /* ---------- maaş kumbarası (her zaman göz önünde) ---------- */
  function kumbaraBilgi(p) {
    var h = SON.hayat, kb = h && h.kumbara, cz = (p && p.cuzdan) || {};
    var bir = kb && kb.birikmis != null ? sayi(kb.birikmis) : sayi(cz.birikmis);
    var kap = kb ? sayi(kb.kapasite) || 24 : 0, saat = kb ? sayi(kb.saat) : 0;
    var dolu = !!cz.dolu || (kap > 0 && saat >= kap);
    var toplanabilir = bir >= 1 || !!cz.gunun_ilki || (h && h.bugun_toplandi === false);
    return { bir: bir, kap: kap, saat: saat, dolu: dolu, toplanabilir: toplanabilir, oran: kap ? Math.min(1, saat / kap) : (dolu ? 1 : null) };
  }
  function kumbaraSerit(p) {
    var k = kumbaraBilgi(p);
    var alt = k.dolu ? 'Kumbara doldu, birikme durdu. Hemen topla!' : (k.kap ? tr(k.saat, 1) + ' / ' + k.kap + ' saat doldu' : 'Maaşın saat saat birikiyor');
    return '<section class="pa-kumbara' + (k.dolu ? ' dolu' : '') + '" data-pa-kumbara aria-label="Maaş kumbarası">' +
      '<span class="pa-kk">' + IK.kumbara + '</span>' +
      '<div class="pa-km"><small>Maaş kumbarası</small><b>' + esc(tl(k.bir)) + '</b>' +
      (k.oran != null ? '<div class="pa-kbar"><i style="width:' + Math.round(k.oran * 100) + '%"></i></div>' : '') +
      '<span class="pa-kalt">' + esc(alt) + '</span></div>' +
      '<button type="button" class="pa-topla" onclick="soPa(&quot;topla&quot;)"' + (k.toplanabilir ? '' : ' disabled') + '>Topla</button></section>';
  }
  var toplaniyor = false;
  function toplaEylem() {
    var b = document.getElementById('hTopla');
    if (b) { if (!b.disabled) b.click(); return; }
    if (toplaniyor || typeof API === 'undefined' || !API) return; toplaniyor = true;
    document.querySelectorAll('.pa-topla').forEach(function (x) { x.disabled = true; x.textContent = 'Toplanıyor…'; });
    API.rpc('topla').then(function (r) {
      var s2 = (r && r.sonuc) || {}, t = g('toast'), tly = function (n) { return tl(n); };
      if (t) t('+' + tly(s2.maas || 0) + ' maaş' + (s2.destek ? ' + ' + tly(s2.destek) + ' destek' : '') + (s2.ilk && s2.seri > 1 ? ' · ' + s2.seri + '. gün' : '') + (s2.statu_atladi ? ' · Statün yükseldi!' : ''));
      if (r && typeof r === 'object') SON.hayat = r;
      var dy = g('durumYenile');
      return (dy ? dy() : Promise.resolve()).then(function () { var y = g('yenidenCiz'); if (y) y(); var rg = g('rozetGuncelle'); if (rg) try { rg(); } catch (e) {} });
    }).catch(function (err) {
      var t = g('toast'), hc = g('hataCevir'); if (t) t(hc ? hc(err && err.message) : 'Toplanamadı.', true);
      document.querySelectorAll('.pa-topla').forEach(function (x) { x.disabled = false; x.textContent = 'Topla'; });
    }).then(function () { toplaniyor = false; });
  }
  function ekleriSirala(ic, k, var_) {               // kartın hemen altına: kumbara, sonra hızlı işlemler
    var son = var_, tasindi = false;
    var kum = k === 'hayat' ? (function () { var b = ic.querySelector('#hTopla'); var o = b && b.closest('.olay'); if (o) o.classList.add('pa-kumbara-buyuk'); return o; })() : (var_.parentElement || ic).querySelector('[data-pa-kumbara]');
    var hz = (var_.parentElement || ic).querySelector('[data-pa-hizli]') || ic.querySelector('[data-pa-hizli]');
    [kum, hz].forEach(function (el) { if (!el) return; if (son.nextElementSibling !== el) { son.after(el); tasindi = true; } son = el; });
    return tasindi;
  }

  /* ---------- bölüm başına kurum kartı + sadeleştirme ---------- */
  function gizle(ic, sec) { try { ic.querySelectorAll(sec).forEach(function (x) { x.classList.add('pa-gizli'); }); } catch (e) {} }
  function kartIle(ic, sec) { try { ic.querySelectorAll(':scope>.kart').forEach(function (k) { if (k.querySelector(sec)) k.classList.add('pa-gizli'); }); } catch (e) {} }

  var HERO = {
    gundem: function (ic, d, p) {
      gizle(ic, ':scope>.mg-serit');
      var cz = p.cuzdan || {}, ok = (d.durum && d.durum.okunmamis) || d.okunmamis || {};
      var parti = p.parti ? p.parti.ad : 'Bağımsız';
      var tarih = new Date().toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', weekday: 'long' });
      return hero('gundem', {
        ust: tarih, baslik: selam() + ', ' + p.kad, alt: rolYaz(p) + ' · ' + parti,
        cip: cipler([siradakiSecim(d)]),
        veri: veri([['Cüzdan', kisaTl(cz.para), cz.para, 'kisa'], ['Okunmamış', tr(sayi(ok.sohbet) + sayi(ok.ozel)), sayi(ok.sohbet) + sayi(ok.ozel)]])
      }) + kumbaraSerit(p) + hizli('gundem', [
        ['hayat', 'Hayat', on('sekme', 'hayat')],
        ['meclis', 'Meclis', on('sekme', 'meclis')],
        ['banka', 'Mobil Şube', on('mobilSube')],
        ['magaza', 'Mağaza', on('magaza')]
      ]);
    },
    devlet: function (ic, d, p) {
      kartIle(ic, 'button[onclick*="cbUlusaSeslenislerEkrani"]');
      var cb = d.durum && d.durum.cb, gun = cb && gunFark(cb.bas);
      return hero('devlet', {
        ust: 'Türkiye Cumhuriyeti', baslik: cb ? 'Cumhurbaşkanı ' + cb.kad : 'Cumhurbaşkanlığı boş',
        alt: cb && cb.parti ? cb.parti.ad : (cb ? 'Bağımsız' : 'Seçim sonucu bekleniyor'),
        sag: muhur(ikon('devlet')),
        veri: veri([['Görev süresi', cb && gun != null ? (gun < 1 ? 'Bugün' : gun + ' gün') : null], ['Senin makamın', (p.makamlar || []).length ? rolYaz(p) : 'Yok']])
      }) + hizli('devlet', [
        ['meclis', 'Meclis', on('sekme', 'meclis')],
        ['megafon', 'Ulusa sesleniş', on('seslenis')],
        g('krizMerkeziEkrani') ? ['kriz', 'Kriz merkezi', on('kriz')] : null,
        ['gazete', 'Resmî Gazete', on('gazete')]
      ]);
    },
    hayat: function (ic, d, p) {
      var h = SON.hayat || {}, cz = p.cuzdan || {}, kb = h.kumbara || {}, st = h.statu || {};
      gizle(ic, ':scope>.sahne:first-child'); kartIle(ic, 'button[onclick*="gorevEkrani"]'); gizle(ic, ':scope>#mgHayat');
      var rk = document.getElementById('hReklam'), rkAlt = rk ? (rk.querySelector('.kucuk') || {}).textContent : '';
      if (rk && rk.parentElement && rk.parentElement.parentElement === ic) rk.parentElement.classList.add('pa-gizli');
      var kap = sayi(kb.kapasite) || 24, saat = sayi(kb.saat);
      return hero('hayat', {
        ust: 'Cüzdanın', baslik: tl(h.para != null ? h.para : cz.para), sayac: h.para != null ? h.para : cz.para, buyuk: true,
        sag: kb.kapasite ? halka(saat / kap, tr(saat, 1), '/ ' + kap + ' saat') : '',
        cip: cipler([st.ad ? cip(st.ad) : '', kb.seri ? cip(kb.seri + ' günlük seri') : '']),
        veri: veri([['Saatlik net', kb.saatlik ? tl(kb.saatlik.net) : null], ['Günlük net', kb.gunluk_net ? tl(kb.gunluk_net) : null]])
      }) + hizli('hayat', [
        ['gorev', 'Görevler', on('gorev')],
        rk ? ['oynat', 'Reklam izle', on('tikla', 'hReklam'), (rkAlt || '').trim()] : null,
        ['banka', 'Mobil Şube', on('mobilSube')],
        ['magaza', 'Mağaza', on('magaza')]
      ]);
    },
    sohbet: function (ic, d, p) {
      kartIle(ic, '.co-sayi');
      var s = SON.sohbet_ozet || {}, ok = (d.durum && d.durum.okunmamis) || d.okunmamis || {};
      var acik = (s.kanallar || []).filter(function (k) { return !k.kilit; }).length;
      var oku = s.toplam_okunmamis != null ? s.toplam_okunmamis : sayi(ok.sohbet) + sayi(ok.ozel);
      return hero('sohbet', {
        ust: 'Sohbet ve mesajlar', baslik: s.cevrimici != null ? s.cevrimici + ' oyuncu çevrimiçi' : 'Sohbet',
        alt: oku ? oku + ' okunmamış mesajın var' : 'Hepsini okudun',
        sag: muhur(ikon('sohbet')),
        veri: veri([['Okunmamış', tr(oku)], ['Açık kanal', acik ? tr(acik) : null]])
      }) + hizli('sohbet', [
        ['yeniMesaj', 'Yeni mesaj', on('yeniMesaj')],
        ['kisiler', 'Çevrimiçi', on('cevrimici')],
        ['ara', 'Oyuncu ara', on('ara')],
        ['megafon', 'Meydan', on('sohbet', 'genel')]
      ]);
    },
    meclis: function (ic, d, p) {
      var m = SON.meclis_rehber || SON.meclis || {}, dolu = sayi(m.dolu), top = sayi(m.toplam) || 600;
      var bs = (SON.meclis_baskanlik && SON.meclis_baskanlik.baskan) || (SON.meclis_rehber && SON.meclis_rehber.baskan);
      return hero('meclis', {
        ust: 'Türkiye Büyük Millet Meclisi', baslik: m.dolu != null ? dolu + ' / ' + top + ' sandalye' : 'Genel Kurul',
        alt: bs && bs.kad ? 'TBMM Başkanı ' + bs.kad : 'Kanunlar burada yapılır',
        sag: muhur(ikon('meclis')),
        veri: veri([['Parti', m.partiler ? tr(m.partiler.length) : null], ['Bağımsız', m.bagimsiz != null ? tr(m.bagimsiz) : null], ['Kabul için', m.dolu != null ? tr(Math.floor(dolu / 2) + 1) + ' evet' : null]])
      }) + hizli('meclis', [
        ['kanun', 'Kanun teklifi', on('kanun')],
        ['sandik', 'Yasama', on('meclisSekme', 'yasama')],
        ['kisiler', 'Vekiller', on('meclisSekme', 'vekiller')],
        ['sohbet', 'Genel Kurul', on('sohbet', 'meclis')]
      ]);
    },
    harita: function (ic, d, p) {
      kartIle(ic, 'button[onclick*="oyuncuAramaAc"]');
      var h = Array.isArray(SON.harita) ? SON.harita : [], oy = 0, bel = 0, mv = 0;
      h.forEach(function (x) { oy += sayi(x.oyuncu); if (x.bel) bel++; (x.vekil || []).forEach(function (v) { mv += sayi(v.n); }); });
      return hero('harita', {
        ust: 'Türkiye haritası', baslik: '81 il' + (oy ? ' · ' + tr(oy) + ' oyuncu' : ''), alt: 'Senin ilin: ' + (p.il_ad || '—'),
        sag: muhur(ikon('harita')),
        veri: veri([['Belediye başkanı', h.length ? tr(bel) + ' il' : null], ['Milletvekili', h.length ? tr(mv) : null]])
      }) + hizli('harita', [
        ['ara', 'Oyuncu ara', on('ara')],
        p.il_id ? ['konum', p.il_ad || 'İlim', on('ilim', p.il_id)] : null,
        ['meclis', 'Meclis', on('sekme', 'meclis')]
      ]);
    },
    parti: function (ic, d, p) {
      kartIle(ic, 'button[onclick*="koalisyonPazarlikEkrani"]'); kartIle(ic, 'button[onclick*="oyuncuAramaAc"]');
      gizle(ic, ':scope>button[onclick*="kurucuDavetModal"]');
      var pr = p.parti;
      if (pr) gizle(ic, ':scope>.kart.cizgili');
      var bilgi = pr && (SON.partiler || []).filter(function (x) { return x.id === pr.id; })[0];
      return hero('parti', {
        ust: pr ? 'Partin' : 'Siyasi partiler', baslik: pr ? pr.ad : 'Bağımsızsın',
        alt: bilgi && bilgi.gb ? 'Genel Başkan ' + bilgi.gb : (pr ? (p.gb ? 'Genel Başkansın' : '') : 'Bir partiye katıl ya da yenisini kur'),
        sag: muhur('<span>' + esc(pr ? pr.kisa : (SON.partiler ? SON.partiler.length : '')) + '</span>'),
        veri: veri(bilgi ? [['Üye', tr(bilgi.uye)], ['Vekil', tr(bilgi.vekil)], ['Belediye', tr(bilgi.belediye)]] : [['Parti sayısı', SON.partiler ? tr(SON.partiler.length) : null]])
      }) + hizli('parti', [
        pr ? ['parti', 'Partim', on('partim', pr.id)] : null,
        ['el', 'Pazarlıklar', on('koalisyon')],
        ['ara', 'Üye ara', on('ara')],
        ['kisiler', 'Kurucular', on('kurucu')]
      ]);
    },
    dernek: function (ic, d, p) {
      kartIle(ic, 'button[onclick*="stkSosyalVitrin"]');
      var ilkP = ic.querySelector(':scope>p.alt'); if (ilkP) ilkP.classList.add('pa-gizli');
      var dl = Array.isArray(SON.dernekler) ? SON.dernekler : null;
      var uye = dl ? dl.filter(function (x) { return x.uyesiyim; }).length : null, bas = dl ? dl.filter(function (x) { return x.baskan === p.kad; }).length : null;
      return hero('dernek', {
        ust: 'Sivil toplum', baslik: dl ? dl.length + ' dernek ve vakıf' : 'Dernekler',
        alt: 'Protesto, basın açıklaması, bildiri ve destek', sag: muhur(ikon('dernek')),
        veri: veri([['Üyeliğin', uye != null ? tr(uye) : null], ['Başkanlığın', bas ? tr(bas) : null]])
      }) + hizli('dernek', [
        ['kalp', 'Sosyal etki', on('sosyal')],
        g('stkKurModal') ? ['dernekKur', 'Dernek kur', on('dernekKur')] : null,
        ['megafon', 'Protestolar', on('kaydir', '#icerik .bolum-bas:nth-of-type(2)')]
      ]);
    },
    ben: function (ic, d, p) {
      gizle(ic, ':scope>.giris-satir[onclick*="magazaEkrani"]');
      var pb = ic.querySelector('button[onclick="portreModal()"]');
      if (pb) {
        pb.classList.add('pa-gizli'); var ust = pb.previousElementSibling; if (ust && ust.querySelector('h3')) ust.classList.add('pa-gizli');
        var pk = pb.parentElement;                // kimlik kartında yazanlar (il, parti, görev, katılım) tekrar edilmez
        if (pk && pk !== ic) pk.querySelectorAll(':scope>.kv').forEach(function (x) { var t = (x.querySelector('.k') || x.firstElementChild || {}).textContent || ''; if (/^(İl|Parti|Görev|Katılım)$/.test(t.trim())) x.classList.add('pa-gizli'); });
      }
      var yb = ic.querySelector(':scope>button[onclick*="yoneticiEkrani"]'); if (yb) yb.classList.add('pa-gizli');
      var b = bolum('ben'), st = (SON.hayat && SON.hayat.statu) || {};
      var pf = g('portre'), foto = '';
      try { foto = pf ? pf(p.kad, p.parti && p.parti.renk) : ''; } catch (e) {}
      var asc = function (s) { return String(s || '').toLocaleUpperCase('tr-TR').replace(/[ÇĞİÖŞÜ]/g, function (c) { return { 'Ç': 'C', 'Ğ': 'G', 'İ': 'I', 'Ö': 'O', 'Ş': 'S', 'Ü': 'U' }[c]; }).replace(/[^A-Z0-9]/g, '<'); };
      var no = String(p.id || '').replace(/-/g, '').slice(0, 8).toUpperCase();
      var mrz1 = ('SO<TUR' + asc(p.kad) + '<<' + asc(p.il_ad) + '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<').slice(0, 36);
      var mrz2 = (no + '<' + asc(p.parti ? p.parti.kisa : 'BAGIMSIZ') + '<<' + (p.olusturma ? String(p.olusturma).slice(0, 10).replace(/-/g, '') : '') + '<<<<<<<<<<<<<<<<<<<<<<<<<<<<').slice(0, 36);
      return '<section class="pa-kimlik" data-pa-hero="ben" style="--a1:' + b.a1 + ';--a2:' + b.a2 + '" aria-label="Oyuncu kimlik kartı">' +
        '<div class="pa-kb"><div><small>SEÇİM SİMÜLASYONU · TÜRKİYE</small><b>Vatandaş Kimlik Kartı</b></div><span class="pa-cipi" aria-hidden="true"></span></div>' +
        '<div class="pa-kg"><div class="pa-kf">' + foto + '</div><div class="pa-kalan">' +
        '<div class="tam"><small>KULLANICI ADI</small><b class="ad">' + esc(p.kad) + '</b></div>' +
        '<div><small>İL</small><b>' + esc(p.il_ad || '—') + '</b></div>' +
        '<div><small>PARTİ</small><b>' + esc(p.parti ? p.parti.kisa : 'Bağımsız') + '</b></div>' +
        '<div class="tam"><small>GÖREV</small><b>' + esc(rolYaz(p)) + '</b></div>' +
        (st.ad ? '<div><small>STATÜ</small><b>' + esc(st.ad) + '</b></div>' : '') +
        '<div' + (st.ad ? '' : ' class="tam"') + '><small>KAYIT</small><b>' + esc(p.olusturma ? tarihKisa(p.olusturma) : '—') + '</b></div>' +
        '</div></div><div class="pa-mrz" aria-hidden="true">' + esc(mrz1) + '<br>' + esc(mrz2) + '</div></section>' +
        hizli('ben', [
          ['kalem', 'Portre ve biyografi', on('portre')],
          ['kimlik', 'Seçmen kartım', on('secmen')],
          ['magaza', 'Mağaza', on('magaza')],
          p.yonetici ? ['ayar', 'Yönetici paneli', on('yonetici')] : ['zil', 'Bildirimler', on('bildirim')]
        ]);
    }
  };
  var BASLIK = { gundem: 'Gündem', devlet: 'Devlet', hayat: 'Hayat', sohbet: 'Sohbet', meclis: 'Meclis', harita: 'Türkiye', parti: 'Partiler', dernek: 'Dernekler', ben: 'Profilim' };

  var sonGiris = '', tasimaAnahtar = '', tasimaSay = 0;
  function heroKur(ic) {
    var d = Dx(), p = profil(); if (!d || !p || !p.kad) return;
    var k = d.sekme; if (!HERO[k] || (d.yigin && d.yigin.length)) return;
    var h1 = document.querySelector('#app header.ust h1'); if (!h1 || h1.textContent.trim() !== BASLIK[k]) return;
    var var_ = ic.querySelector('[data-pa-hero]');
    if (var_) {                                   // sonradan eklenen bölümler kartın üstüne çıkmasın; gizlemeleri tazele
      try { HERO[k](ic, d, p); } catch (e) {}
      if (k === 'gundem') {                       // Gündem'in sıralamasını kendi modülü yönetir: kart, basın kısayollarının başında durur
        var kisa = ic.querySelector(':scope>.so-gundem-kisa'), kum0 = ic.querySelector('[data-pa-kumbara]'), hz0 = ic.querySelector('[data-pa-hizli]');
        if (kisa && var_.parentElement !== kisa) { kisa.insertBefore(var_, kisa.firstChild); if (kum0) var_.after(kum0); if (hz0) (kum0 || var_).after(hz0); }
        return;
      }
      if (var_.parentElement !== ic) return;
      var anah = k + '|' + (d._ekranNo || 0);
      if (tasimaAnahtar !== anah) { tasimaAnahtar = anah; tasimaSay = 0; }
      if (tasimaSay > 4) return;                  // başka bir modülle sıralama yarışına girme
      var once = var_.previousElementSibling, tasindi = false;
      while (once && once.classList.contains('pa-gizli')) once = once.previousElementSibling;
      if (once) { ic.insertBefore(var_, ic.firstChild); tasindi = true; }
      if (ekleriSirala(ic, k, var_)) tasindi = true;
      if (tasindi) tasimaSay++;
      return;
    }
    if (ic.querySelector(':scope>.yukleniyor') && k !== 'gundem' && k !== 'ben') return;
    var html = '';
    try { html = HERO[k](ic, d, p); } catch (e) { if (window.console) console.warn('Premium arayüz kartı:', e); return; }
    if (!html) return;
    var yer = k === 'gundem' ? ic.querySelector(':scope>.so-gundem-kisa') : null;
    if (yer) yer.insertAdjacentHTML('afterbegin', html);
    else if (k === 'gundem') { var sonu = null; ic.querySelectorAll(':scope>.mg-serit,:scope>.aj-sponsor,:scope>.aj-ek,:scope>.serit,:scope>.secim-ust,:scope>.so-canli-oylama,:scope>.so-canli-akis,:scope>.sm-gundem').forEach(function (x) { sonu = x; }); if (sonu) sonu.insertAdjacentHTML('afterend', html); else ic.insertAdjacentHTML('afterbegin', html); }
    else ic.insertAdjacentHTML('afterbegin', html);
    var anahtar = k + '|' + (d._ekranNo || 0);
    var kart = ic.querySelector('[data-pa-hero]');
    if (kart && k !== 'gundem') ekleriSirala(ic, k, kart);
    if (kart && anahtar !== sonGiris && !azHareket()) { sonGiris = anahtar; kart.classList.add('pa-giris'); sayacOynat(kart); }
    else sonGiris = anahtar;
  }
  function sayacOynat(kok) {
    kok.querySelectorAll('[data-pa-say]').forEach(function (el) {
      var hedef = sayi(el.getAttribute('data-pa-say')), tur = el.getAttribute('data-pa-tur') || '', t0 = 0, dur = 750;
      if (!hedef) return;
      var yaz = function (v) { el.textContent = tur === 'tl' ? tl(v) : tur === 'kisa' ? kisaTl(v) : tr(v); };
      var adim = function (ts) { if (!t0) t0 = ts; var x = Math.min(1, (ts - t0) / dur), e = 1 - Math.pow(1 - x, 3); yaz(Math.round(hedef * e)); if (x < 1) requestAnimationFrame(adim); else yaz(hedef); };
      yaz(0); requestAnimationFrame(adim);
    });
    var hl = kok.querySelector('[data-pa-halka]');
    if (hl) { var son = hl.getAttribute('data-pa-halka'); hl.style.strokeDashoffset = String(2 * Math.PI * 31); requestAnimationFrame(function () { requestAnimationFrame(function () { hl.style.strokeDashoffset = son; }); }); }
  }

  /* ---------- alt menü ---------- */
  function okunmamis() { var d = Dx(); return d && d.okunmamis || {}; }
  function sohbetSayi() { var f = g('sohbetOkunmamisSayi'); try { return f ? f(okunmamis()) : 0; } catch (e) { return 0; } }
  function rozet(n) { var f = g('sayiRozet'); return f ? f(n) : (n > 0 ? '<span class="sayi">' + (n > 99 ? '99+' : n) + '</span>' : ''); }
  function navKur(nav) {
    var ak = aktifSekme(), p = profil(), cz = p && p.cuzdan, ikincil = ANA.indexOf(ak) < 0;
    var ob = ikincil ? bolum(ak) : null, dm = sohbetSayi();
    var html = ANA.map(function (k) {
      if (k === 'MENU') {
        var nokta = cz && (cz.dolu || cz.gunun_ilki) ? '<span class="pa-nokta" title="Maaşın hazır"></span>' : '';
        return '<button type="button" class="pa-orta' + (ikincil ? ' aktif' : '') + '" aria-label="Tüm bölümler' + (ikincil ? ', şu an ' + esc(ob.ad) : '') + '" aria-haspopup="dialog" onclick="soPaMenu()"' +
          (ob ? ' style="--pa-o1:' + ob.a1 + ';--pa-o2:' + karis(ob.a2, ob.a1, .25) + '"' : '') + '><span class="pa-ni">' + (ikincil ? ikon(ob.ik) : IK.menu) + nokta + '</span><span class="pa-nl">' + (ikincil ? esc(ob.ad) : 'Menü') + '</span></button>';
      }
      var b = B[k], ac = ak === k;
      if (k === 'sohbet') return '<button type="button" id="sohbetSekme" class="' + (ac ? 'aktif' : '') + (dm > 0 ? ' mesaj-var' : '') + '" aria-label="Sohbet, ' + dm + ' okunmamış mesaj" onclick="sekmeAc(\'sohbet\')"><span class="pa-ni">' + ikon('sohbet') + '<span id="dmSayi">' + rozet(dm) + '</span></span><span class="pa-nl">Sohbet</span></button>';
      return '<button type="button" class="' + (ac ? 'aktif' : '') + '"' + (ac ? ' aria-current="page"' : '') + ' onclick="sekmeAc(\'' + k + '\')"><span class="pa-ni">' + ikon(b.ik) + '</span><span class="pa-nl">' + b.ad + '</span></button>';
    }).join('');
    nav.innerHTML = html; nav.classList.add('pa-nav'); nav.setAttribute('aria-label', 'Ana menü');
  }

  /* ---------- Menü çekmecesi ---------- */
  function karo(k, ad, alt, eylem, rz) {
    var b = bolum(k === '@banka' ? 'hayat' : k), ak = aktifSekme() === k;
    var renk = { '@banka': ['#b33a5c', '#3b1832'], '@ilan': ['#d99a2b', '#45301a'], '@muzayede': ['#c99a3a', '#4a1a2e'], '@magaza': ['#7a5af0', '#2a1f5e'], '@bildirim': ['#e0565b', '#45182a'], '@yonetici': ['#7b8bb8', '#232b4c'] }[k];
    var a1 = renk ? renk[0] : b.a1, a2 = renk ? renk[1] : b.a2;
    var ik = { '@banka': 'banka', '@ilan': 'ilan', '@muzayede': 'cekic', '@magaza': 'magaza', '@bildirim': 'zil', '@yonetici': 'ayar' }[k] || (B[k] && B[k].ik) || k;
    return '<button type="button" class="pa-karo' + (ak ? ' aktif' : '') + '" style="--k1:' + a1 + ';--k2:' + a2 + '" onclick="' + eylem + '"><span class="pa-ki">' + ikon(ik) + '</span><span><b>' + esc(ad) + '</b><small>' + esc(alt) + '</small></span>' + (rz || '') + '</button>';
  }
  function menuHtml() {
    var p = profil() || {}, cz = p.cuzdan || {}, ok = okunmamis(), d = Dx();
    var yon = false; try { var yv = g('yonetimVarMi'); yon = !!(yv && yv()); } catch (e) {}
    var bel = (p.makamlar || []).some(function (m) { return m.tur === 'bel'; });
    var m = SON.meclis_rehber || SON.meclis, pf = g('portre'), foto = '';
    try { foto = pf && p.kad ? pf(p.kad, p.parti && p.parti.renk) : ''; } catch (e) {}
    var kb = bolum('ben');
    var gruplar = [
      ['Siyaset', [
        karo('meclis', 'Meclis', m && m.dolu != null ? m.dolu + '/' + (m.toplam || 600) + ' sandalye' : 'Kanun ve oylama', on('sekme', 'meclis')),
        karo('parti', 'Partiler', p.parti ? p.parti.kisa + ' ve ittifaklar' : 'Katıl ya da kur', on('sekme', 'parti')),
        karo('adliye', 'Adliye', 'Dava ve avukat', on('sekme', 'adliye')),
        karo('harita', 'Türkiye', '81 il haritası', on('sekme', 'harita')),
        karo('dernek', 'Dernekler', 'Sivil toplum', on('sekme', 'dernek')),
        karo('devlet', bel ? 'Belediyem' : 'Devlet', bel ? 'Makamım' : 'Hükümet', on('sekme', 'devlet'))
      ]],
      ['Hayat ve para', [
        karo('hayat', 'Hayat', 'Maaş, görev, statü', on('sekme', 'hayat'), cz.dolu ? '<span class="pa-rz yesil">Topla</span>' : ''),
        karo('@banka', 'Mobil Şube', 'Hesap, kart, kredi', on('mobilSube')),
        karo('@ilan', 'İlan Meydanı', 'Ev, dükkân, hisse', on('ilan')),
        karo('@muzayede', 'Müzayede', 'Pey ver, koleksiyon yap', on('muzayede')),
        karo('ekonomi', 'Ekonomi', 'Şirket ve piyasa', on('sekme', 'ekonomi')),
        karo('@magaza', 'Mağaza', 'Kart ve paketler', on('magaza'))
      ]],
      ['Hesabım', [
        karo('ben', 'Profilim', 'Kimlik ve ayarlar', on('sekme', 'ben')),
        karo('@bildirim', 'Bildirimler', 'Son gelişmeler', on('bildirim'), rozet(sayi(ok.bildirim))),
        p.yonetici ? karo('@yonetici', 'Yönetici', 'Oyun paneli', on('yonetici')) : (yon ? karo('devlet', 'Makamım', 'Yönetim', on('sekme', 'devlet')) : '')
      ]]
    ];
    return '<div class="pa-perde" onclick="soPaMenuKapat()"></div><div class="pa-cekmece" role="dialog" aria-modal="true" aria-label="Tüm bölümler"><div class="pa-tutamac"></div>' +
      '<div class="pa-cb"><h2>Tüm bölümler</h2><button type="button" class="pa-kapat" aria-label="Kapat" onclick="soPaMenuKapat()">' + IK.kapat + '</button></div>' +
      (p.kad ? '<button type="button" class="pa-kim" style="--k1:' + kb.a1 + ';--k2:' + kb.a2 + '" onclick="' + on('sekme', 'ben') + '"><span class="pa-pp">' + foto + '</span><span class="pa-km"><b>' + esc(p.kad) + '</b><small>' + esc(rolYaz(p)) + (p.parti ? ' · ' + esc(p.parti.kisa) : '') + '</small></span><span class="pa-cz">' + esc(kisaTl(cz.para)) + '</span></button>' : '') +
      '<label class="pa-ara" for="paAraKutu"><span class="pa-ara-simge">' + IK.ara + '</span><input id="paAraKutu" type="search" enterkeyhint="search" autocomplete="off" autocorrect="off" spellcheck="false" placeholder="Menülerde ara: kredi, dava, şirket kur…" aria-label="Menülerde ara" oninput="soPaAra(this.value)" onkeydown="if(event.key===\'Enter\'){event.preventDefault();soPaAraAc(0)}"></label>' +
      '<div id="paAramaSonuc" class="pa-ara-sonuc" hidden aria-live="polite"></div>' +
      '<div id="paGruplar">' + gruplar.map(function (gr) { var ic = gr[1].filter(Boolean).join(''); return ic ? '<section class="pa-grup"><h3>' + gr[0] + '</h3><div class="pa-izgara">' + ic + '</div></section>' : ''; }).join('') +
      '<div class="pa-alt">Gündem, Devlet, Ekonomi ve Sohbet her zaman alt menüde.</div></div></div>';
  }
  /* ---------- Menü çekmecesi: genel arama ---------- */
  function normal(x) { return String(x || '').toLocaleLowerCase('tr-TR').replace(/[ıİ]/g, 'i').replace(/ğ/g, 'g').replace(/ü/g, 'u').replace(/ş/g, 's').replace(/ö/g, 'o').replace(/ç/g, 'c').replace(/â/g, 'a').replace(/î/g, 'i').replace(/û/g, 'u'); }
  // [ikon, renk, başlık, açıklama, eylem (soPa eylem adı + argümanlar ya da kod), anahtar kelimeler, bölüm]
  function aramaDizini() {
    var p = profil() || {}, ls = [];
    var e = function (ik, renk, ad, alt, ey, kel, grp) { ls.push({ ik: ik, renk: renk, ad: ad, alt: alt, ey: ey, kel: kel || '', grp: grp }); };
    e('gundem', B.gundem.a1, 'Gündem', 'Akış, haberler, seçim takvimi', ['sekme', 'gundem'], 'ana sayfa haber akış paylaşım', 'Bölüm');
    e('devlet', B.devlet.a1, 'Devlet', 'Makamım, hükümet, mevzuat, gazete, tarih', ['sekme', 'devlet'], 'hükümet kabine bakanlık makam yönetim belediye cumhurbaşkanı', 'Bölüm');
    e('meclis', B.meclis.a1, 'Meclis', 'Sandalyeler, kanunlar, oylamalar', ['sekme', 'meclis'], 'tbmm milletvekili kanun yasa oylama grup başkanlık', 'Bölüm');
    e('parti', B.parti.a1, 'Partiler', 'Partin, ittifaklar, ideolojiler', ['sekme', 'parti'], 'parti ittifak kurultay genel başkan üye katıl kur', 'Bölüm');
    e('adliye', B.adliye.a1, 'Adliye', 'Mahkeme, davalar, avukatlar, baro', ['sekme', 'adliye'], 'mahkeme dava avukat hukuk baro icra', 'Bölüm');
    e('harita', B.harita.a1, 'Türkiye haritası', '81 il, belediyeler, vekiller', ['sekme', 'harita'], 'harita il şehir belediye gelişmişlik', 'Bölüm');
    e('dernek', B.dernek.a1, 'Dernekler', 'Sivil toplum, protesto, bildiri', ['sekme', 'dernek'], 'dernek vakıf stk protesto basın açıklaması bildiri', 'Bölüm');
    e('hayat', B.hayat.a1, 'Hayat', 'Cüzdan, maaş kumbarası, görevler, statü', ['sekme', 'hayat'], 'cüzdan para maaş kumbara statü kıdem bağış vergi', 'Bölüm');
    e('ekonomi', B.ekonomi.a1, 'Ekonomi', 'Şirketler, ticaret, bankalar, yatırım', ['sekme', 'ekonomi'], 'ekonomi şirket ticaret piyasa borsa', 'Bölüm');
    e('sohbet', B.sohbet.a1, 'Sohbet', 'Kanallar ve özel mesajlar', ['sekme', 'sohbet'], 'mesaj sohbet kanal meydan kahve dm', 'Bölüm');
    e('ben', B.ben.a1, 'Profilim', 'Kimlik kartı, ayarlar, geçmiş seçimler', ['sekme', 'ben'], 'profil hesap ayar biyografi portre taşın istifa çıkış', 'Bölüm');
    e('kumbara', '#21a874', 'Maaşı topla', 'Maaş kumbarasındaki parayı cüzdanına al', ['topla'], 'maaş kumbara topla para kazan günlük', 'İşlem');
    e('banka', '#b33a5c', 'Mobil Şube', 'Hesap, kredi kartı, kredi, birikim, FAST', ['mobilSube'], 'banka hesap kredi kart mevduat faiz fast eft havale iban', 'Para');
    e('para', '#1f9e86', 'Para gönder', 'Başka bir oyuncuya para gönder', ['kod', 'paraGonderModal()'], 'para gönder transfer havale fast', 'Para');
    e('ilan', '#d99a2b', 'İlan Meydanı', 'Satılık ev, dükkân, arsa, şirket, hisse', ['ilan'], 'ilan satılık ev daire dükkan arsa emlak tapu şirket hisse sahibinden', 'Para');
    if (g('muzayedeEkrani')) e('cekic', '#c99a3a', 'Müzayede Evi', 'Koleksiyon eserlerine pey ver, sergile, sat', ['muzayede'], 'müzayede açık artırma pey koleksiyon eser tablo sikke pul antika saat mücevher halı otomobil sergi müze', 'Para');
    e('magaza', '#7a5af0', 'Mağaza', 'Siyaset Kartı ve ₺ paketleri', ['magaza'], 'mağaza satın al paket siyaset kartı rozet', 'Para');
    e('gorev', '#8a68f2', 'Görevler', 'Günlük, haftalık ve kalıcı görevler', ['gorev'], 'görev ödül', 'Hayat');
    e('kanun', B.meclis.a1, 'Kanun teklifi ver', 'Meclis\'e yeni kanun teklifi sun', ['kanun'], 'kanun teklif yasa önerge', 'Meclis');
    e('sandik', B.meclis.a1, 'Yasama ve oylamalar', 'Oylamadaki kanunlar', ['meclisSekme', 'yasama'], 'oylama oy ver yasama kanun', 'Meclis');
    e('kisiler', B.meclis.a1, 'İl il milletvekilleri', 'Vekil listesi', ['meclisSekme', 'vekiller'], 'vekil milletvekili liste', 'Meclis');
    e('megafon', B.devlet.a1, 'Ulusa sesleniş', 'Cumhurbaşkanlarının konuşmaları', ['seslenis'], 'sesleniş konuşma cumhurbaşkanı', 'Devlet');
    if (g('krizMerkeziEkrani')) e('kriz', '#e0565b', 'Kriz merkezi', 'Ülke krizleri ve kararlar', ['kriz'], 'kriz afet olay karar', 'Devlet');
    e('gazete', B.devlet.a1, 'Resmî Gazete', 'Kanunlar ve kararnameler', ['gazete'], 'resmi gazete kararname', 'Devlet');
    e('el', '#c03a6b', 'Koalisyon pazarlıkları', 'Gizli siyasi pazarlıklar ve protokoller', ['koalisyon'], 'koalisyon pazarlık protokol ittifak gizli', 'Siyaset');
    e('kisiler', '#c03a6b', 'Kurucular kurulu', 'Parti kurma davetleri', ['kurucu'], 'parti kur kurucu davet', 'Siyaset');
    e('ara', '#2e86de', 'Oyuncu ara', 'Kullanıcı adı, il ve partiye göre bul', ['ara'], 'oyuncu ara bul kişi profil', 'Kişiler');
    e('yeniMesaj', '#2e86de', 'Yeni özel mesaj', 'Bir oyuncuya yaz', ['yeniMesaj'], 'mesaj yaz dm özel', 'Kişiler');
    e('kisiler', '#2e86de', 'Çevrimiçi oyuncular', 'Şu an oyunda olanlar', ['cevrimici'], 'çevrimiçi online', 'Kişiler');
    if (g('soYayinGit')) { e('gazete', '#d8425e', 'Gazeteler', 'Oyuncu gazeteleri ve köşe yazıları', ['kod', 'soYayinGit("basin")'], 'gazete köşe yazısı basın yayın', 'Basın'); e('kitap', '#d8425e', 'Kitaplar ve yayınevleri', 'Kitap oku, satın al, yayımla', ['kod', 'soYayinGit("kitap")'], 'kitap yayınevi yazar', 'Basın'); }
    if (g('soGundemTakvimAc')) e('sandik', '#16a0a6', 'Seçim takvimi', 'Yaklaşan seçimler ve eski sonuçlar', ['kod', 'soGundemTakvimAc()'], 'seçim takvim aday başvuru sandık sonuç', 'Siyaset');
    e('kalp', B.dernek.a1, 'Sosyal etki merkezi', 'Bağış kampanyaları, gönüllü etkinlikler', ['sosyal'], 'bağış kampanya gönüllü yardım', 'Dernekler');
    if (g('stkKurModal')) e('dernekKur', B.dernek.a1, 'Dernek kur', 'Yeni dernek ya da vakıf kur', ['dernekKur'], 'dernek vakıf kur', 'Dernekler');
    e('kalem', B.ben.a1, 'Portre ve biyografi', 'Profil resmini ve yazını düzenle', ['portre'], 'portre avatar resim biyografi', 'Profil');
    e('kimlik', B.ben.a1, 'Seçmen kartım', 'Oy, adaylık ve parti kurma şartları', ['secmen'], 'seçmen kartı şart aday', 'Profil');
    e('zil', '#e0565b', 'Bildirimler', 'Son gelişmeler', ['bildirim'], 'bildirim haber uyarı', 'Profil');
    if (p.il_id) e('konum', B.harita.a1, (p.il_ad || 'İlim') + ' il sayfası', 'İlinin belediyesi, vekilleri ve oyuncuları', ['ilim', p.il_id], 'il şehrim belediye', 'Türkiye');
    if (p.yonetici) e('ayar', '#7b8bb8', 'Yönetici paneli', 'Oyun yönetimi', ['yonetici'], 'yönetici admin panel', 'Profil');
    var ind = window.SO_MENU_ARAMA_INDEKSI || {};
    [['ekonomi', 'Ekonomi'], ['adliye', 'Adliye']].forEach(function (gr) {
      (ind[gr[0]] || []).forEach(function (x) {
        var t = String(x[0] || '').replace(/[\uFE0F\s]/g, ''), em = EMO[t] || EMO[Array.from(t)[0]] || [B[gr[0]].ik, B[gr[0]].a1];
        ls.push({ ik: em[0], renk: em[1] || B[gr[0]].a1, ad: x[1], alt: x[2], ey: ['menu', gr[0], x[3]], kel: x[4] || '', grp: gr[1] });
      });
    });
    var gor = {};                                   // aynı adlı satırları bir kez göster
    return ls.filter(function (x) { var k = normal(x.ad); if (gor[k]) return false; gor[k] = 1; return true; });
  }
  var ARA = { liste: [], son: [] };
  function aramaYap(q) {
    var kutu = document.getElementById('paAramaSonuc'), gruplar = document.getElementById('paGruplar');
    if (!kutu || !gruplar) return;
    var n = normal(q).trim();
    if (!n) { kutu.hidden = true; kutu.innerHTML = ''; gruplar.hidden = false; return; }
    if (!ARA.liste.length) ARA.liste = aramaDizini();
    var kelimeler = n.split(/\s+/).filter(Boolean);
    var puanli = ARA.liste.map(function (x) {
      var ad = normal(x.ad), hep = ad + ' ' + normal(x.alt) + ' ' + normal(x.kel) + ' ' + normal(x.grp);
      if (!kelimeler.every(function (k) { return hep.indexOf(k) >= 0; })) return null;
      var puan = (ad.indexOf(n) === 0 ? 0 : ad.indexOf(n) > 0 ? 1 : kelimeler.every(function (k) { return ad.indexOf(k) >= 0; }) ? 2 : 3) * 100 + (x.grp === 'Bölüm' ? 0 : 10);
      return { x: x, p: puan };
    }).filter(Boolean).sort(function (a, b) { return a.p - b.p; }).slice(0, 14).map(function (o) { return o.x; });
    ARA.son = puanli;
    gruplar.hidden = true; kutu.hidden = false;
    kutu.innerHTML = '<div class="pa-ara-bas">' + (puanli.length ? puanli.length + ' sonuç' : 'Sonuç yok') + '</div>' +
      (puanli.length ? puanli.map(function (x, i) {
        return '<button type="button" class="pa-ara-satir" onclick="soPaAraAc(' + i + ')"><span class="pa-ara-ik" style="--k1:' + x.renk + ';--k2:' + karis(x.renk, '#0b1130', .55) + '">' + ikon(x.ik) + '</span>' +
          '<span class="pa-ara-orta"><b>' + esc(x.ad) + '</b><small>' + esc(x.alt) + '</small></span><span class="pa-ara-grp">' + esc(x.grp) + '</span></button>';
      }).join('') : '<p class="pa-ara-bos">“' + esc(q) + '” ile eşleşen bir menü bulamadım. Başka bir kelime dene; bir oyuncuyu arıyorsan aşağıdan bulabilirsin.</p>') +
      '<button type="button" class="pa-ara-satir oyuncu" onclick="soPa(&quot;ara&quot;)"><span class="pa-ara-ik" style="--k1:#2e86de;--k2:#173a66">' + IK.ara + '</span><span class="pa-ara-orta"><b>Oyuncu ara</b><small>Bu isimde bir oyuncu mu arıyorsun?</small></span></button>';
  }
  window.soPaAra = function (q) { try { aramaYap(q); } catch (e) { if (window.console) console.warn('Menü arama:', e); } };
  window.soPaAraAc = function (i) {
    var x = ARA.son[i]; if (!x) return;
    var ey = x.ey;
    if (ey[0] === 'menu') {                         // Ekonomi / Adliye menü merkezinin bir işlemi
      menuKapat(true);
      var grp = ey[1], kod = ey[2], d = Dx();
      try {
        if (/^soMenuSec\(/.test(kod) && (!d || d.sekme !== grp || (d.yigin && d.yigin.length))) git(grp);
        (new Function(kod))();
      } catch (e) { hata(); }
      return;
    }
    if (ey[0] === 'kod') { menuKapat(true); try { (new Function(ey[1]))(); } catch (e) { hata(); } return; }
    window.soPa.apply(null, ey);
  };

  var menuOdak = null;
  window.soPaMenu = function () {
    var el = document.getElementById('paMenu');
    if (!el) { el = document.createElement('div'); el.id = 'paMenu'; document.body.appendChild(el); }
    menuOdak = document.activeElement; ARA.liste = []; ARA.son = [];
    el.className = ''; el.innerHTML = menuHtml(); el.hidden = false;
    var ilk = el.querySelector('.pa-kapat'); if (ilk) try { ilk.focus({ preventScroll: true }); } catch (e) {}
  };
  function menuKapat(hemen) {
    var el = document.getElementById('paMenu'); if (!el || el.hidden) return;
    if (hemen || azHareket()) { el.hidden = true; el.innerHTML = ''; return; }
    el.classList.add('kapaniyor');
    setTimeout(function () { el.hidden = true; el.innerHTML = ''; el.classList.remove('kapaniyor'); }, 210);
    if (menuOdak && menuOdak.focus) try { menuOdak.focus({ preventScroll: true }); } catch (e) {}
  }
  window.soPaMenuKapat = function () { menuKapat(false); };
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    var k = document.getElementById('paAraKutu');
    if (k && k.value && document.activeElement === k) { k.value = ''; aramaYap(''); return; }
    menuKapat(false);
  });

  /* ---------- ortam rengi ---------- */
  var sonRenk = '';
  function ortam() {
    var b = bolum(aktifSekme()); if (b.a1 === sonRenk) return; sonRenk = b.a1;
    var r = document.documentElement.style;
    r.setProperty('--pa-a1', b.a1); r.setProperty('--pa-a2', b.a2); r.setProperty('--pa-glow', rgba(b.a1, .24));
  }

  /* ---------- her çizimde uygula ---------- */
  var calisiyor = false;
  function isle() {
    if (calisiyor) return; calisiyor = true;
    try {
      apiSar(); ortam();
      var app = document.getElementById('app'); if (!app) return;
      var nav = app.querySelector(':scope>nav.sekmeler:not(.pa-nav)'); if (nav) navKur(nav);
      var cip0 = app.querySelector('.ust .para-cip'), pp = profil();
      if (cip0) cip0.classList.toggle('pa-kumbara-dolu', !!(pp && pp.cuzdan && (pp.cuzdan.dolu || pp.cuzdan.gunun_ilki)));
      var ic = app.querySelector('#icerik');
      if (ic) { heroKur(ic); ikonlastir(ic); icIzle(ic); }
    } finally { calisiyor = false; }
  }
  var icGozcu = null, izlenen = null;
  function icIzle(ic) {
    if (izlenen === ic) return; izlenen = ic;
    if (icGozcu) icGozcu.disconnect();
    var bekliyor = false;
    icGozcu = new MutationObserver(function (ms) {
      if (calisiyor) return;
      var dogrudan = ms.some(function (m) { return m.target === ic; });
      if (dogrudan) { isle(); return; }
      if (bekliyor) return; bekliyor = true;      // iç güncellemelerde yalnız simgeleri yenile (kare başına bir kez)
      requestAnimationFrame(function () { bekliyor = false; try { ikonlastir(ic); } catch (e) {} });
    });
    icGozcu.observe(ic, { childList: true, subtree: true });
  }
  function basla() {
    stilKur();
    var app = document.getElementById('app'); if (!app) return setTimeout(basla, 50);
    new MutationObserver(isle).observe(app, { childList: true });
    isle();
    setInterval(apiSar, 1500);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', basla); else basla();
})();
