/*
 * SEÇİM SİMÜLASYONU ONLINE — KÜRSÜ (26.10.2026)
 * Akış'ın sosyal ağ hâli: hesaplar, biyografi ve kapak, takip/takipçi,
 * yeniden paylaşım ve alıntı, beğeni/beğenmeme, yanıt dizileri,
 * Türkiye gündemi (etiketler, kişiler, partiler, dernekler) ve Kürsü bildirimleri.
 * Gönderiler yine oyun.akis tablosunda durur; Akış'ın kuralları (280 karakter,
 * küfür/bağlantı yasağı, hız sınırları, şikâyet ve engelleme) aynen geçerlidir.
 * Sunucu: public.kursu_* RPC'leri (sql/141_kursu.sql) + akis_yaz/akis_yanit_yaz/akis_tepki/akis_sil.
 */
(function () {
  'use strict';
  if (window.KURSU) return;
  window.KURSU = true;

  var KR = {
    g: {},                       // gönderi önbelleği: id -> gönderi
    akis: {},                    // ana sayfa sekmeleri: sekme -> { liste, imlec, t, kaydir }
    sekme: 'sana',
    ben: null, benT: 0,
    gundem: null, gundemT: 0,
    enSon: 0,                    // görülen en yeni gönderi no'su (yeni gönderi balonu için)
    gozcu: null, ekran: null, kesfetSuzgec: 'hepsi', araZaman: null
  };
  window.KURSU_DURUM = KR;

  /* ---------- yardımcılar ---------- */
  function esc(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function n(v) { var x = Number(v); return isFinite(x) ? x : 0; }
  function say(v) {
    v = n(v); if (v < 10000) return v.toLocaleString('tr-TR');
    if (v < 1e6) return (Math.round(v / 100) / 10).toLocaleString('tr-TR') + ' B';
    return (Math.round(v / 1e5) / 10).toLocaleString('tr-TR') + ' Mn';
  }
  function sayBos(v) { return n(v) > 0 ? say(v) : ''; }
  function rpc(ad, args) { return API.rpc(ad, args || {}); }
  function hataMetni(err) { var m = (err && err.message) || String(err || ''); return typeof hataCevir === 'function' ? hataCevir(m) : m; }
  function hata(err) { toast(hataMetni(err), true); }
  function ne(ts) { try { return typeof gecenZaman === 'function' ? gecenZaman(ts) : new Date(ts).toLocaleDateString('tr-TR'); } catch (e) { return ''; } }
  function tamTarih(ts) {
    try { var d = new Date(ts); return d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Istanbul' }) + ' · ' + d.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Europe/Istanbul' }); } catch (e) { return ''; }
  }
  function ayYil(ts) { try { return new Date(ts).toLocaleDateString('tr-TR', { month: 'long', year: 'numeric', timeZone: 'Europe/Istanbul' }); } catch (e) { return ''; } }
  function profil() { return (typeof D !== 'undefined' && D.durum && D.durum.profil) || null; }
  function benKad() { var p = profil(); return p ? p.kad : ''; }
  function av(kad, renk, boy) { try { return portre(kad, renk, boy); } catch (e) { return '<span class="kr-av-bos" style="width:' + boy + 'px;height:' + boy + 'px"></span>'; } }
  function avTazele(kok) { try { if (typeof portreleriTazele === 'function') portreleriTazele(kok); } catch (e) {} }
  function kok() { return document.getElementById('icerik'); }
  function aktif(ad) { var k = kok(); return !!(k && k.querySelector('.kr[data-kr-ekran="' + ad + '"]')); }
  function hafif() { try { HAPTIK.hafif(); } catch (e) {} }
  function partiRenk(p) { return (p && p.renk) || '#5b6894'; }
  function titrek(el) { if (!el) return; el.classList.remove('kr-pat'); void el.offsetWidth; el.classList.add('kr-pat'); }

  /* ---------- ikonlar ---------- */
  function sv(p, ek) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"' + (ek || '') + '>' + p + '</svg>'; }
  var I = {
    yanit: sv('<path d="M20.5 11.6a8.1 8.1 0 0 1-11.8 7.2L3.5 20l1.4-4.5a8.1 8.1 0 1 1 15.6-3.9z"/>'),
    yp: sv('<path d="M17 2.8l3.2 3.2L17 9.2"/><path d="M4 11.4V9.6A3.6 3.6 0 0 1 7.6 6h12.6"/><path d="M7 21.2L3.8 18 7 14.8"/><path d="M20 12.6v1.8a3.6 3.6 0 0 1-3.6 3.6H3.8"/>'),
    kalp: sv('<path d="M12 20.3s-7.8-4.6-9.2-9.6C1.9 7.4 4 4.2 7.4 4.2c2 0 3.5 1.1 4.6 2.7 1.1-1.6 2.6-2.7 4.6-2.7 3.4 0 5.5 3.2 4.6 6.5-1.4 5-9.2 9.6-9.2 9.6z"/>'),
    kalpDolu: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 20.3s-7.8-4.6-9.2-9.6C1.9 7.4 4 4.2 7.4 4.2c2 0 3.5 1.1 4.6 2.7 1.1-1.6 2.6-2.7 4.6-2.7 3.4 0 5.5 3.2 4.6 6.5-1.4 5-9.2 9.6-9.2 9.6z"/></svg>',
    kirik: sv('<path d="M12 20.3s-7.8-4.6-9.2-9.6C1.9 7.4 4 4.2 7.4 4.2c2 0 3.5 1.1 4.6 2.7"/><path d="M12 6.9c1.1-1.6 2.6-2.7 4.6-2.7 3.4 0 5.5 3.2 4.6 6.5-1.4 5-9.2 9.6-9.2 9.6"/><path d="M12 6.9l-1.6 4 3 1.8-1.7 4.2"/>'),
    kirikDolu: '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M11.2 6.1C10.1 5 8.9 4.2 7.4 4.2 4 4.2 1.9 7.4 2.8 10.7c1.2 4.4 7.3 8.4 8.8 9.4l1.1-3.1-2.8-1.8 1.9-4.7-1.4-1.1zM13 5.6l-1.1 3.2 2.9 2-2.1 5.6-.8 3.6c1.7-1 7.7-5 8.9-9.3.9-3.3-1.2-6.5-4.6-6.5-1.3 0-2.3.5-3.2 1.4z"/></svg>',
    paylas: sv('<path d="M12 3.5v11.3"/><path d="M7.6 7.8L12 3.4l4.4 4.4"/><path d="M5 12.5v6.3a1.7 1.7 0 0 0 1.7 1.7h10.6a1.7 1.7 0 0 0 1.7-1.7v-6.3"/>'),
    menu: '<svg viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><circle cx="5" cy="12" r="1.7"/><circle cx="12" cy="12" r="1.7"/><circle cx="19" cy="12" r="1.7"/></svg>',
    ara: sv('<circle cx="10.8" cy="10.8" r="6.6"/><path d="M20.3 20.3l-4.8-4.8"/>'),
    zil: sv('<path d="M6 8.6a6 6 0 1 1 12 0c0 6.6 2.8 8.4 2.8 8.4H3.2S6 15.2 6 8.6"/><path d="M10.2 20.6a2 2 0 0 0 3.6 0"/>'),
    ev: sv('<path d="M3.5 10.6L12 3.8l8.5 6.8V19a1.6 1.6 0 0 1-1.6 1.6h-4.2v-5.8H9.3v5.8H5.1A1.6 1.6 0 0 1 3.5 19z"/>'),
    kalem: sv('<path d="M4 20l1.1-4.3L15.8 5a2.2 2.2 0 0 1 3.1 3.1L8.3 18.9z"/><path d="M13.8 7l3.2 3.2"/><path d="M13 20h7"/>'),
    arti: sv('<path d="M12 5v14M5 12h14"/>', ' stroke-width="2.4"'),
    raptiye: sv('<path d="M9 3.5h6l-1 5.2 3.5 3.3v1.5h-11V12L10 8.7z"/><path d="M12 13.5v7"/>'),
    alinti: sv('<path d="M4 20l1.1-4.3L15.8 5a2.2 2.2 0 0 1 3.1 3.1L8.3 18.9z"/><path d="M13.8 7l3.2 3.2"/>'),
    kisi: sv('<circle cx="12" cy="8" r="4"/><path d="M4.5 20.5c1.4-3.8 4.2-5.7 7.5-5.7s6.1 1.9 7.5 5.7"/>'),
    kisiArti: sv('<circle cx="10" cy="8" r="4"/><path d="M3 20.5c1.3-3.8 3.9-5.7 7-5.7 1.6 0 3 .5 4.2 1.4"/><path d="M18.5 13.5v6M15.5 16.5h6"/>'),
    konum: sv('<path d="M12 21s-6.8-6.1-6.8-11.2a6.8 6.8 0 1 1 13.6 0C18.8 14.9 12 21 12 21z"/><circle cx="12" cy="9.8" r="2.4"/>'),
    takvim: sv('<rect x="3.5" y="5" width="17" height="15.5" rx="2.6"/><path d="M8 3v4M16 3v4M3.5 10h17"/>'),
    bayrak: sv('<path d="M5 21V4M5 4h11.5l-2.2 4.2 2.2 4.3H5"/>'),
    mesaj: sv('<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3.8 7l8.2 6 8.2-6"/>'),
    kart: sv('<rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="9" cy="11" r="2.3"/><path d="M5.8 16.4c.7-1.6 1.8-2.4 3.2-2.4s2.5.8 3.2 2.4M14.5 10h4M14.5 13.5h3"/>'),
    sil: sv('<path d="M4 7h16M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>'),
    kalkan: sv('<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>'),
    atesli: sv('<path d="M12 21.5c-4.1 0-7-2.8-7-6.6 0-3.3 2.2-5.4 3.6-7.4.3 2 1.3 3.2 2.5 3.6-.4-3.4 1.2-6.3 4-8.6-.1 3.2 1.1 5.1 2.6 6.9 1.2 1.4 2.3 3 2.3 5.5 0 3.8-3.4 6.6-8 6.6z"/>'),
    dernek: sv('<path d="M4 21V9l8-5 8 5v12"/><path d="M9 21v-6h6v6"/>'),
    kitap: sv('<path d="M4 19.5V5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5 2.5 2.5 0 0 0 6.5 23H20"/>'),
    ok: sv('<path d="M5 12h14M13 6l6 6-6 6"/>'),
    yukari: sv('<path d="M12 19V5M6 11l6-6 6 6"/>', ' stroke-width="2.4"'),
    kapat: sv('<path d="M6 6l12 12M18 6L6 18"/>', ' stroke-width="2.2"')
  };
  var logoSay = 0;
  function logo(boy) {
    var id = 'krLg' + (++logoSay);
    return '<svg class="kr-logo" viewBox="0 0 32 32" width="' + (boy || 26) + '" height="' + (boy || 26) + '" aria-hidden="true"><defs><linearGradient id="' + id + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8b6cff"/><stop offset="1" stop-color="#ff4f8b"/></linearGradient></defs>' +
      '<rect width="32" height="32" rx="9.5" fill="url(#' + id + ')"/>' +
      '<path d="M10.6 26.4h10.8l-1.4-8.1h-8z" fill="#fff"/><rect x="8.6" y="16.1" width="14.8" height="2.6" rx="1.3" fill="#fff"/>' +
      '<path d="M16 16v-3.2" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/><circle cx="16" cy="10.4" r="2.7" fill="#fff"/>' +
      '<path d="M10.4 7.3a7.4 7.4 0 0 0 0 6.4M21.6 7.3a7.4 7.4 0 0 1 0 6.4" stroke="#fff" stroke-width="1.8" fill="none" stroke-linecap="round" opacity=".8"/></svg>';
  }
  // Makam sahiplerine "makam nişanı"; Cumhurbaşkanına altın nişan
  function nisan(unvan) {
    if (!unvan) return '';
    var u = String(unvan);
    var renk = /Cumhurbaşkanı Yardımcısı/.test(u) ? '#f59e0b' : /Cumhurbaşkanı/.test(u) ? '#d4a62c' : /Başbakan/.test(u) ? '#e85568' : /Bakanı|Bakan(?:$|\s|\()/.test(u) ? '#a78bfa' : /Milletvekili/.test(u) ? '#419dff' : /Belediye Başkanı/.test(u) ? '#20bd83' : /TBMM Başkanı|Meclis Başkanı/.test(u) ? '#fb7185' : /Yargıç|Hakim|Hâkim/.test(u) ? '#22d3ee' : /Genel Başkan/.test(u) ? '#e879bb' : '#94a3b8';
    return '<span class="kr-nisan" style="color:' + renk + '" role="img" aria-label="' + esc(unvan) + '" title="' + esc(unvan) + '"><svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 1.8l2.4 1.9 3-.4 1.1 2.8 2.8 1.1-.4 3 1.9 2.4-1.9 2.4.4 3-2.8 1.1-1.1 2.8-3-.4L12 22.2l-2.4-1.9-3 .4-1.1-2.8-2.8-1.1.4-3L1.2 12l1.9-2.4-.4-3 2.8-1.1 1.1-2.8 3 .4z"/><path d="M8 12.3l2.7 2.7 5.4-5.6" stroke="#fff" stroke-width="2.3" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg></span>';
  }

  /* ---------- metin: #etiket ve @kişi bağlantıları ---------- */
  function metinHtml(m, uyum) {
    var s = String(m == null ? '' : m), html = '', son = 0, re = /([#@])([\p{L}\p{N}_.]{2,30})/gu, x;
    while ((x = re.exec(s))) {
      var ad = x[2].replace(/\.+$/, ''), bas = x.index;
      if (ad.length < 2) continue;
      if (bas > 0 && /[\p{L}\p{N}_]/u.test(s.charAt(bas - 1))) continue;      // e-posta vb.
      if (x[1] === '#' && /\./.test(ad)) ad = ad.split('.')[0];
      if (ad.length < 2) continue;
      html += esc(s.slice(son, bas));
      if (x[1] === '#') {
        var k = ad.toLocaleLowerCase('tr-TR');
        html += uyum ? '<span class="etk kr-et" data-etk="' + esc(k) + '">#' + esc(ad) + '</span>' : '<span class="kr-et" data-kr="etiket" data-et="' + esc(k) + '">#' + esc(ad) + '</span>';
      } else {
        html += '<span class="kr-an" data-kr="profil" data-kad="' + esc(ad) + '">@' + esc(ad) + '</span>';
      }
      son = bas + 1 + ad.length;
      re.lastIndex = son;
    }
    return html + esc(s.slice(son));
  }

  /* ---------- gönderi kartı ---------- */
  function kaydet(g) {
    if (!g || g.id == null) return g;
    var eski = KR.g[g.id];
    if (eski) {
      // Akış listelerinden gelen kayıtlarda Kürsü alanları olmayabilir: eldekini koru
      ['yp', 'ypledim', 'alinti_sayi', 'alinti', 'yanit_kad', 'takip_ediyorum'].forEach(function (k) { if (g[k] === undefined && eski[k] !== undefined) g[k] = eski[k]; });
    }
    KR.g[g.id] = g;
    if (n(g.id) > KR.enSon) KR.enSon = n(g.id);
    return g;
  }
  function eylemIc(k, g) {
    if (k === 'yanit') return '<span class="kr-ei">' + I.yanit + '</span><span class="kr-es">' + sayBos(g.yanit) + '</span>';
    if (k === 'yp') return '<span class="kr-ei">' + I.yp + '</span><span class="kr-es">' + sayBos(g.yp) + '</span>';
    if (k === 'begen') return '<span class="kr-ei">' + (g.begendim ? I.kalpDolu : I.kalp) + '</span><span class="kr-es">' + sayBos(g.begeni) + '</span>';
    if (k === 'begenme') return '<span class="kr-ei">' + (g.begenmedim ? I.kirikDolu : I.kirik) + '</span><span class="kr-es">' + sayBos(g.begenmeme) + '</span>';
    return '<span class="kr-ei">' + I.paylas + '</span>';
  }
  function eylemSinif(k, g) {
    var on = (k === 'yp' && g.ypledim) || (k === 'begen' && g.begendim) || (k === 'begenme' && g.begenmedim);
    return 'kr-e kr-e-' + k + (on ? ' on' : '');
  }
  var EYLEM_AD = { yanit: 'Yanıtla', yp: 'Yeniden paylaş', begen: 'Beğen', begenme: 'Beğenme', paylas: 'Paylaş' };
  function eylemHtml(g, uyum) {
    return '<div class="kr-eylem">' + ['yanit', 'yp', 'begen', 'begenme', 'paylas'].map(function (k) {
      var at;
      if (uyum && k === 'yanit') at = 'data-yanitla="' + g.id + '"';
      else if (uyum && (k === 'begen' || k === 'begenme')) at = 'data-tepki="' + k + '" data-id="' + g.id + '"';
      else at = 'data-kr="' + k + '" data-id="' + g.id + '"';
      return '<button type="button" class="' + eylemSinif(k, g) + '" data-k="' + k + '" ' + at + ' aria-label="' + EYLEM_AD[k] + '">' + eylemIc(k, g) + '</button>';
    }).join('') + '</div>';
  }
  function alintiHtml(q) {
    if (!q) return '';
    return '<div class="kr-alinti" data-kr="ac" data-id="' + q.id + '"><div class="kr-al-bas">' + av(q.kad, partiRenk(q.parti), 20) +
      '<b>' + esc(q.kad) + '</b>' + nisan(q.unvan) + '<span class="kr-sure">' + esc(ne(q.zaman)) + '</span></div>' +
      '<div class="kr-al-metin">' + metinHtml(q.metin) + '</div></div>';
  }
  function altSatir(g) {
    var p = [];
    if (g.unvan) p.push(esc(g.unvan));
    if (g.parti) p.push('<span class="kr-pnok" style="background:' + esc(partiRenk(g.parti)) + '"></span>' + esc(g.parti.kisa || g.parti.ad));
    else if (!g.unvan && g.il) p.push(esc(g.il));
    return p.length ? '<div class="kr-unvan">' + p.join('<i></i>') + '</div>' : '';
  }
  // opt: { yp: 'kad', sabit: true, odak: true, uyum: true (Gündem önizlemesi: eski bağlayıcılarla çalışır), cizgi: true }
  function gonderiHtml(g, opt) {
    opt = opt || {};
    kaydet(g);
    var uyum = !!opt.uyum, odak = !!opt.odak;
    var ust = '';
    if (opt.sabit) ust = '<div class="kr-ustnot">' + I.raptiye + '<span>Sabitlenmiş gönderi</span></div>';
    else if (opt.yp) ust = '<div class="kr-ustnot">' + I.yp + '<span><b data-kr="profil" data-kad="' + esc(opt.yp) + '">' + (opt.yp === benKad() ? 'Sen' : esc(opt.yp)) + '</b> yeniden paylaştı</span></div>';
    var adAt = 'data-kr="profil" data-kad="' + esc(g.kad) + '"';
    var bas = '<div class="kr-bas"><b class="kr-ad" ' + adAt + '>' + esc(g.kad) + '</b>' + nisan(g.unvan) +
      (odak ? '' : '<span class="kr-sure">' + esc(ne(g.zaman)) + '</span>') +
      '<button type="button" class="kr-dm" ' + (uyum ? 'data-menu="' + g.id + '"' : 'data-kr="menu" data-id="' + g.id + '"') + ' aria-label="Seçenekler">' + I.menu + '</button></div>';
    var yanitNot = g.yanit_kad ? '<div class="kr-yanitnot"><span data-kr="profil" data-kad="' + esc(g.yanit_kad) + '">@' + esc(g.yanit_kad) + '</span> kişisine yanıt</div>' : '';
    var metin = '<div class="kr-metin metin"' + (uyum ? ' data-konu="' + g.id + '"' : '') + '>' + metinHtml(g.metin, uyum) + '</div>';
    var istat = '';
    if (odak) {
      var ps = [];
      if (n(g.yp)) ps.push('<span><b>' + say(g.yp) + '</b> Yeniden paylaşım</span>');
      if (n(g.alinti_sayi)) ps.push('<span><b>' + say(g.alinti_sayi) + '</b> Alıntı</span>');
      if (n(g.begeni)) ps.push('<span><b>' + say(g.begeni) + '</b> Beğeni</span>');
      if (n(g.begenmeme)) ps.push('<span><b>' + say(g.begenmeme) + '</b> Beğenmeme</span>');
      istat = '<div class="kr-zaman-tam">' + esc(tamTarih(g.zaman)) + (g.il ? ' · ' + esc(g.il) : '') + '</div>' + (ps.length ? '<div class="kr-istat">' + ps.join('') + '</div>' : '');
    }
    var cls = 'akis-satir kr-g' + (odak ? ' kr-odak konu-ana' : '') + (opt.cizgi ? ' kr-zincir' : '') + (uyum ? ' kr-uyum' : '');
    var kokAt = (odak || uyum) ? '' : ' data-kr="ac"';
    if (odak) {
      return '<article class="' + cls + '" data-id="' + g.id + '">' + ust +
        '<div class="kr-odak-ust"><span class="kr-av" ' + adAt + '>' + av(g.kad, partiRenk(g.parti), 48) + '</span><div class="kr-odak-kim">' + bas + altSatir(g) + '</div></div>' +
        yanitNot + metin + alintiHtml(g.alinti) + istat + eylemHtml(g, false) + '</article>';
    }
    return '<article class="' + cls + '" data-id="' + g.id + '"' + kokAt + '>' + ust +
      '<div class="kr-g-ic"><span class="kr-av" ' + adAt + '>' + av(g.kad, partiRenk(g.parti), 44) + '</span>' +
      '<div class="kr-g-g">' + bas + altSatir(g) + yanitNot + metin + alintiHtml(g.alinti) + eylemHtml(g, uyum) + '</div></div></article>';
  }
  // Ekrandaki aynı gönderinin bütün kopyalarındaki sayaçları yerinde güncelle (bağlayıcılar korunur)
  function sayacGuncelle(id, pat) {
    var g = KR.g[id]; if (!g) return;
    document.querySelectorAll('.kr-g[data-id="' + id + '"] .kr-eylem [data-k]').forEach(function (b) {
      var k = b.dataset.k; if (k === 'paylas') return;
      b.className = eylemSinif(k, g); b.innerHTML = eylemIc(k, g);
      if (pat && pat === k) titrek(b);
    });
  }

  /* ---------- liste parçaları ---------- */
  function listeHtml(liste) {
    var gor = {};
    return (liste || []).map(function (x) {
      var g = x && x.g ? x.g : x; if (!g || gor[g.id]) return ''; gor[g.id] = 1;
      return gonderiHtml(g, { yp: x && x.yp });
    }).join('');
  }
  function bosHtml(baslik, metin, dugme) {
    return '<div class="kr-bos"><div class="kr-bos-ik">' + logo(54) + '</div><b>' + baslik + '</b><p>' + metin + '</p>' + (dugme || '') + '</div>';
  }
  function yukleHtml() { return '<div class="kr-yuk" aria-label="Yükleniyor"><span></span><span></span><span></span></div>'; }
  function iskeletGonderi(k) { var h = ''; for (var i = 0; i < (k || 4); i++) h += '<div class="kr-hayal"><span class="a"></span><div><span class="b"></span><span class="c"></span><span class="d"></span></div></div>'; return h; }
  function takipBtn(k, kucuk) {
    if (!k || k.benim) return '';
    var on = !!k.takip_ediyorum;
    return '<button type="button" class="kr-takip' + (on ? ' on' : '') + (kucuk ? ' kucuk' : '') + '" data-kr="takip" data-kad="' + esc(k.kad || k.ad) + '" data-on="' + (on ? 1 : 0) + '">' +
      (on ? '<span class="kr-t1">Takip ediliyor</span><span class="kr-t2">Bırak</span>' : (k.beni_takip_ediyor ? 'Sen de takip et' : 'Takip et')) + '</button>';
  }
  function kisiSatir(k) {
    return '<div class="kr-kisi" data-kr="profil" data-kad="' + esc(k.kad) + '"><span class="kr-av">' + av(k.kad, partiRenk(k.parti), 44) + '</span>' +
      '<div class="kr-kisi-g"><div class="kr-kisi-ad"><b>' + esc(k.kad) + '</b>' + nisan(k.unvan) + '</div>' +
      '<div class="kr-kisi-alt">' + (k.unvan ? esc(k.unvan) : (k.parti ? esc(k.parti.ad) : 'Vatandaş')) + (k.beni_takip_ediyor ? '<span class="kr-seni">Seni takip ediyor</span>' : '') + '</div>' +
      (k.bio ? '<div class="kr-kisi-bio">' + metinHtml(k.bio) + '</div>' : '') + '</div>' + takipBtn(k, true) + '</div>';
  }

  /* ---------- üst çubuk ---------- */
  function baslik(alt) {
    if (alt) return '<span class="kr-baslik kr-baslik-alt">' + alt + '</span>';
    return '<span class="kr-baslik" data-kr="ev">' + logo(28) + '<span>Kürsü</span></span>';
  }
  function sagIkonlar(secili) {
    var p = profil(), yeni = KR.ben ? n(KR.ben.yeni) : 0;
    return '<div class="kr-sag">' +
      '<button type="button" class="kr-ust-b" onclick="sekmeAc(\'sohbet\')" aria-label="Özel mesajlar">' + I.mesaj + '</button>' +
      '<button type="button" class="kr-ust-b' + (secili === 'kesfet' ? ' on' : '') + '" data-kr="git" data-alt="kesfet" aria-label="Keşfet ve gündem">' + I.ara + '</button>' +
      '<button type="button" class="kr-ust-b' + (secili === 'bildirim' ? ' on' : '') + '" data-kr="git" data-alt="bildirim" aria-label="Kürsü bildirimleri' + (yeni ? ', ' + yeni + ' yeni' : '') + '">' + I.zil + '<span class="kr-rozet" id="krRozet"' + (yeni && secili !== 'bildirim' ? '' : ' hidden') + '>' + (yeni > 99 ? '99+' : yeni) + '</span></button>' +
      (p ? '<button type="button" class="kr-ust-b kr-ust-av' + (secili === 'profil' ? ' on' : '') + '" data-kr="profil" data-kad="' + esc(p.kad) + '" aria-label="Kürsü profilim">' + av(p.kad, p.parti && p.parti.renk, 30) + '</button>' : '') +
      '</div>';
  }
  function ciz(ad, ust, govde, opt) {
    opt = opt || {};
    iskelet(ust, '<div class="kr" data-kr-ekran="' + ad + '">' + govde + '</div>', { geri: D.yigin.length > 0, sag: opt.sag });
    KR.ekran = ad;
    var k = kok(); if (k) { avTazele(k); }
    if (opt.fab) fabKur(opt.fab);
  }
  function fabKur(fn) {
    var app = document.getElementById('app'); if (!app) return;
    var b = document.createElement('button'); b.type = 'button'; b.className = 'kr-fab'; b.setAttribute('aria-label', 'Gönderi yaz');
    b.innerHTML = I.kalem; b.onclick = function () { hafif(); fn(); };
    app.appendChild(b);
  }
  async function benYukle(zorla) {
    if (!zorla && KR.ben && Date.now() - KR.benT < 60000) return KR.ben;
    try { KR.ben = await rpc('kursu_ben'); KR.benT = Date.now(); } catch (e) {}
    return KR.ben;
  }
  function rozetYaz() {
    var r = document.getElementById('krRozet'); if (!r) return;
    var y = KR.ben ? n(KR.ben.yeni) : 0;
    r.hidden = !y || KR.ekran === 'bildirim'; r.textContent = y > 99 ? '99+' : y;
  }
  async function gundemYukle(zorla) {
    if (!zorla && KR.gundem && Date.now() - KR.gundemT < 120000) return KR.gundem;
    try { KR.gundem = await rpc('kursu_gundem'); KR.gundemT = Date.now(); } catch (e) { if (!KR.gundem) KR.gundem = null; }
    return KR.gundem;
  }

  /* =====================================================================
     ANA SAYFA
     ===================================================================== */
  var SEKMELER = [['sana', 'Sana özel'], ['takip', 'Takip ettiklerin'], ['il', 'İlin'], ['parti', 'Partin']];
  function sekmeler() {
    var p = profil() || {};
    return '<div class="kr-sekmeler" role="tablist">' + SEKMELER.filter(function (s) { return s[0] !== 'parti' || p.parti; }).map(function (s) {
      var ad = s[0] === 'il' && p.il_ad ? p.il_ad : (s[0] === 'parti' && p.parti ? (p.parti.kisa || 'Partin') : s[1]);
      return '<button type="button" role="tab" aria-selected="' + (KR.sekme === s[0]) + '" class="' + (KR.sekme === s[0] ? 'on' : '') + '" data-kr="sekme" data-sekme="' + s[0] + '"><span>' + esc(ad) + '</span></button>';
    }).join('') + '</div>';
  }
  function sorHtml() {
    var p = profil(); if (!p) return '';
    return '<button type="button" class="kr-sor" data-kr="yaz"><span class="kr-av">' + av(p.kad, p.parti && p.parti.renk, 40) + '</span><span class="kr-sor-m">Neler oluyor, ' + esc(p.kad) + '?</span><span class="kr-sor-b">Paylaş</span></button>';
  }
  function gundemSeridi() {
    var gd = KR.gundem, et = gd && gd.etiketler || [];
    if (!et.length) return '<div class="kr-serit" id="krSerit" hidden></div>';
    return '<div class="kr-serit" id="krSerit"><span class="kr-serit-b">' + I.atesli + 'Gündemde</span>' + et.slice(0, 8).map(function (x) {
      return '<button type="button" data-kr="etiket" data-et="' + esc(x.anahtar) + '">' + esc(x.ad) + '<small>' + say(x.sayi) + '</small></button>';
    }).join('') + '</div>';
  }
  function akisDurum(s) { return KR.akis[s] || (KR.akis[s] = { liste: [], imlec: null, t: 0, kaydir: 0, bitti: false }); }

  window.kursuEkrani = async function (alt) {
    if (alt === 'kesfet') return kesfetEkrani();
    if (alt === 'bildirim') return bildirimEkrani();
    if (alt === 'profil') return window.kursuProfilEkrani(benKad());
    var s = KR.sekme, A = akisDurum(s), taze = A.t && Date.now() - A.t < 90000 && A.liste.length;
    var ust = baslik(), sag = sagIkonlar('ana');
    ciz('ana', ust, sekmeler() + '<div class="kr-yeni" id="krYeni" hidden></div>' + sorHtml() + gundemSeridi() +
      '<div id="krListe">' + (taze ? listeHtml(A.liste) : iskeletGonderi(5)) + '</div><div id="krSon"></div>', { sag: sag, fab: function () { yazAc({ tur: 'yeni' }); } });
    if (taze) { sonDurum(A); var k = kok(); if (k && A.kaydir) k.scrollTop = A.kaydir; }
    kaydirmaIzle(s);
    benYukle().then(rozetYaz);
    gundemYukle().then(function () { var e = document.getElementById('krSerit'); if (e && aktif('ana') && KR.gundem) { var t = document.createElement('div'); t.innerHTML = gundemSeridi(); e.replaceWith(t.firstElementChild); } });
    { // Ekrana her dönüşte sunucuyla eşitle; önbellek yalnızca ilk çizim içindir.
      try {
        var r = await rpc('kursu_akis', { p_sekme: s === 'sana' ? 'herkes' : s, p_imlec: null, p_limit: 20 });
        if (!aktif('ana') || KR.sekme !== s) return;
        A.liste = (r && r.liste) || []; A.imlec = r && r.imlec; A.bitti = !A.imlec; A.t = Date.now(); A.kaydir = 0;
        var l = document.getElementById('krListe');
        l.innerHTML = A.liste.length ? listeHtml(A.liste) : anaBos(s);
        avTazele(l); sonDurum(A);
      } catch (err) {
        var l2 = document.getElementById('krListe');
        if (l2) l2.innerHTML = bosHtml('Kürsü şu an yüklenemedi', esc(hataMetni(err)), '<button type="button" class="kr-btn" data-kr="tazele">Yeniden dene</button>');
        return;
      }
    }
    yeniGozcu(s);
  };
  function anaBos(s) {
    if (s === 'takip') {
      var on = (KR.gundem && KR.gundem.oneriler) || [];
      return bosHtml('Akışın seni bekliyor', 'Takip ettiğin oyuncuların gönderileri ve yeniden paylaştıkları burada görünür. Birkaç kişiyle başla.',
        on.length ? '<div class="kr-oneri-liste">' + on.slice(0, 5).map(kisiSatir).join('') + '</div>' : '<button type="button" class="kr-btn" data-kr="git" data-alt="kesfet">Kimi takip edeceğini keşfet</button>');
    }
    return bosHtml('Burada henüz söz alan yok', 'Kürsüye ilk çıkan sen ol: bir görüş yaz, bir etiket başlat.', '<button type="button" class="kr-btn" data-kr="yaz">İlk gönderiyi yaz</button>');
  }
  function sonDurum(A) {
    var s = document.getElementById('krSon'); if (!s) return;
    if (A.bitti || !A.imlec) { s.innerHTML = A.liste.length > 4 ? '<div class="kr-dip">' + logo(22) + '<span>Hepsini gördün. Sıra sende.</span></div>' : ''; return; }
    s.innerHTML = '<button type="button" class="kr-daha" data-kr="daha">Daha fazla göster</button>';
    sonsuzKur(function () { return daha(); });
  }
  function sonsuzKur(fn) {
    try { if (KR.gozcu) KR.gozcu.disconnect(); } catch (e) {}
    var s = document.getElementById('krSon'), k = kok(); if (!s || !k || !('IntersectionObserver' in window)) return;
    KR.gozcu = new IntersectionObserver(function (ls) { if (ls.some(function (x) { return x.isIntersecting; })) fn(); }, { root: k, rootMargin: '700px 0px' });
    KR.gozcu.observe(s);
  }
  var dahaYuk = false;
  async function daha() {
    if (dahaYuk) return; var s = KR.sekme, A = akisDurum(s); if (!A.imlec || !aktif('ana')) return;
    dahaYuk = true; var son = document.getElementById('krSon'); if (son) son.innerHTML = yukleHtml();
    try {
      var r = await rpc('kursu_akis', { p_sekme: s === 'sana' ? 'herkes' : s, p_imlec: A.imlec, p_limit: 20 });
      if (!aktif('ana') || KR.sekme !== s) return;
      var var0 = {}; A.liste.forEach(function (x) { var0[x.g.id] = 1; });
      var yeni = ((r && r.liste) || []).filter(function (x) { return x && x.g && !var0[x.g.id]; });
      A.liste = A.liste.concat(yeni); A.imlec = r && r.imlec; A.bitti = !A.imlec || !yeni.length;
      var l = document.getElementById('krListe'), t = document.createElement('div'); t.innerHTML = listeHtml(yeni);
      while (t.firstChild) l.appendChild(t.firstChild);
      avTazele(l);
    } catch (err) { hata(err); }
    finally { dahaYuk = false; sonDurum(A); }
  }
  function kaydirmaIzle(s) {
    var k = kok(); if (!k) return; var z = 0;
    k.addEventListener('scroll', function () { if (z) return; z = setTimeout(function () { z = 0; if (aktif('ana') && KR.sekme === s) akisDurum(s).kaydir = k.scrollTop; }, 120); }, { passive: true });
  }
  // 30 sn'de bir yeni gönderi var mı bak; varsa üstte "Yeni gönderiler" balonu
  function yeniGozcu(s) {
    try { canliDurdur(); } catch (e) {}
    var tur = 0;
    D.canli = setInterval(async function () {
      if (document.hidden || !aktif('ana') || KR.sekme !== s) return;
      try { if (typeof YUK !== 'undefined' && !YUK.otomatik()) return; } catch (e) {}
      tur++;
      try {
        var r = await rpc('kursu_akis', { p_sekme: s === 'sana' ? 'herkes' : s, p_imlec: null, p_limit: 6 });
        var A = akisDurum(s), gor = {}; A.liste.forEach(function (x) { gor[x.g.id] = 1; });
        var enBuyuk = A.liste.reduce(function (m, x) { return Math.max(m, n(x.g.id)); }, 0);
        var yeni = ((r && r.liste) || []).filter(function (x) { return x.g && !gor[x.g.id] && n(x.g.id) > enBuyuk && !x.g.benim; });
        var b = document.getElementById('krYeni');
        if (b && yeni.length) {
          var kadlar = []; yeni.forEach(function (x) { if (kadlar.indexOf(x.g.kad) < 0) kadlar.push(x.g.kad); });
          b.innerHTML = '<button type="button" data-kr="yenile">' + I.yukari + '<span class="kr-yeni-av">' + kadlar.slice(0, 3).map(function (k) { return av(k, null, 22); }).join('') + '</span><span>Yeni gönderiler</span></button>';
          b.hidden = false; avTazele(b);
        }
      } catch (e) {}
      if (tur % 2 === 0) { await benYukle(true); rozetYaz(); }
    }, 30000 + Math.floor(Math.random() * 4000));
  }
  async function anaYenile() {
    var A = akisDurum(KR.sekme); A.t = 0; A.kaydir = 0;
    var k = kok(); if (k) k.scrollTop = 0;
    await window.kursuEkrani('ana');
  }

  /* =====================================================================
     GÖNDERİ (konuşma)
     ===================================================================== */
  window.kursuGonderiEkrani = async function (id, yaz) {
    // "Yanıtla" ile açıldıysa yenilemelerde yazma penceresi yeniden açılmasın
    if (yaz && D.yigin.length) D.yigin[D.yigin.length - 1] = function () { return window.kursuGonderiEkrani(id); };
    ciz('gonderi', baslik('Gönderi'), iskeletGonderi(2));
    var r;
    try { r = await rpc('kursu_gonderi', { p_id: id }); }
    catch (err) { if (!aktif('gonderi')) return; ciz('gonderi', baslik('Gönderi'), bosHtml('Bu gönderi açılamadı', esc(hataMetni(err)))); return; }
    if (!aktif('gonderi')) return;
    var ana = r.ana, yan = r.yanitlar || [], al = r.alintilar || [];
    var h = gonderiHtml(ana, { odak: true }) +
      '<button type="button" class="kr-yanit-cubuk" data-kr="yanit" data-id="' + ana.id + '"><span class="kr-av">' + av(benKad(), (profil() && profil().parti || {}).renk, 32) + '</span><span>Yanıtını yaz</span><span class="kr-yanit-b">Yanıtla</span></button>' +
      (yan.length ? '<div class="kr-bolum"><h3>Yanıtlar</h3><span>' + say(yan.length) + '</span></div>' + yan.map(function (y) { return gonderiHtml(y); }).join('') :
        '<div class="kr-bos kucuk"><b>İlk yanıtı sen yaz</b><p>Fikrini söyle; konuşma burada başlar.</p></div>') +
      (al.length ? '<div class="kr-bolum"><h3>Alıntılar</h3><span>' + say(ana.alinti_sayi || al.length) + '</span></div>' + al.map(function (y) { return gonderiHtml(y); }).join('') : '');
    ciz('gonderi', baslik('Gönderi'), h);
    if (r.odak && r.odak !== ana.id) {
      var o = document.querySelector('#icerik .kr-g[data-id="' + r.odak + '"]');
      if (o) { o.classList.add('kr-vurgu'); setTimeout(function () { o.scrollIntoView({ block: 'center' }); }, 30); }
    }
    if (yaz) setTimeout(function () { yazAc({ tur: 'yanit', g: ana }); }, 60);
  };

  /* =====================================================================
     PROFİL
     ===================================================================== */
  var KAPAK = {
    mor: ['#6d4dff', '#ff4f8b', 'Kürsü'], gece: ['#0f1b4d', '#46308f', 'Gece'], gun: ['#ff8a3d', '#ffd166', 'Gün doğumu'], deniz: ['#0077b6', '#2ee6d6', 'Deniz'],
    orman: ['#16553a', '#7bd389', 'Orman'], gul: ['#e8487f', '#ffc2d6', 'Gül'], altin: ['#7d5d17', '#f2c14e', 'Altın'], kizil: ['#7d1428', '#ff5a5f', 'Kızıl'],
    meclis: ['#0f3442', '#16a0a6', 'Meclis'], yildiz: ['#140f3a', '#6a4cff', 'Yıldızlı']
  };
  function kapakSvg(ad) {
    var c = KAPAK[ad] || KAPAK.mor, h = '';
    for (var i = 0; i < 16; i++) h += '<ellipse cx="300" cy="95" rx="' + (70 + i * 13) + '" ry="' + (28 + i * 6) + '" transform="rotate(' + (i * 11.25) + ' 300 95)"/>';
    var yildiz = '';
    if (ad === 'yildiz') for (var j = 0; j < 26; j++) yildiz += '<circle cx="' + ((j * 73) % 400) + '" cy="' + ((j * 41) % 150) + '" r="' + (j % 3 ? 0.9 : 1.6) + '" fill="#fff" opacity="' + (j % 4 ? 0.5 : 0.9) + '"/>';
    return '<svg viewBox="0 0 400 150" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><defs><linearGradient id="krKp' + ad + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="' + c[0] + '"/><stop offset="1" stop-color="' + c[1] + '"/></linearGradient></defs>' +
      '<rect width="400" height="150" fill="url(#krKp' + ad + ')"/><g fill="none" stroke="#fff" stroke-opacity=".13" stroke-width=".8">' + h + '</g>' + yildiz + '</svg>';
  }
  var PROF = { kad: null, sekme: 'gonderi', veri: null, imlec: null };
  window.kursuProfilEkrani = async function (kad, sekme) {
    kad = String(kad || benKad());
    if (PROF.kad !== kad) { PROF.sekme = 'gonderi'; }
    if (sekme) PROF.sekme = sekme;
    PROF.kad = kad;
    var benimMi = kad.toLocaleLowerCase('tr-TR') === benKad().toLocaleLowerCase('tr-TR');
    ciz('profil', baslik(esc(kad)), '<div class="kr-kapak">' + kapakSvg('mor') + '</div>' + iskeletGonderi(3), { sag: benimMi ? sagIkonlar('profil') : '' });
    var r;
    try { r = await rpc('kursu_profil', { p_kad: kad, p_sekme: PROF.sekme, p_imlec: null }); }
    catch (err) { if (!aktif('profil')) return; ciz('profil', baslik(esc(kad)), bosHtml('Bu hesap bulunamadı', esc(hataMetni(err)))); return; }
    if (!aktif('profil') || PROF.kad !== kad) return;
    PROF.veri = r; PROF.imlec = r.imlec;
    ciz('profil', baslik(esc(r.kisi.kad)), profilHtml(r), { sag: r.kisi.benim ? sagIkonlar('profil') : '', fab: r.kisi.benim ? function () { yazAc({ tur: 'yeni' }); } : null });
    if (PROF.imlec) { profilSonDurum(); }
  };
  function profilHtml(r) {
    var k = r.kisi, liste = r.liste || [];
    var butonlar = k.benim ?
      '<button type="button" class="kr-btn ikinci" data-kr="duzenle">Profili düzenle</button>' :
      '<button type="button" class="kr-yuv" data-kr="dm" data-kad="' + esc(k.kad) + '" aria-label="Özel mesaj">' + I.mesaj + '</button>' +
      '<button type="button" class="kr-yuv" data-kr="kart" data-kad="' + esc(k.kad) + '" aria-label="Oyuncu kartı">' + I.kart + '</button>' + (k.engelli ? '' : takipBtn(k));
    var meta = [];
    if (k.parti) meta.push('<span class="kr-meta-parti" data-kr="parti" data-id="' + esc(k.parti.id) + '"><span class="kr-pnok" style="background:' + esc(partiRenk(k.parti)) + '"></span>' + esc(k.parti.ad) + '</span>');
    if (k.il) meta.push('<span>' + I.konum + esc(k.il) + '</span>');
    if (k.katilim) meta.push('<span>' + I.takvim + esc(ayYil(k.katilim)) + ' tarihinde katıldı</span>');
    var bio = k.bio ? '<p class="kr-p-bio">' + metinHtml(k.bio) + '</p>' : (k.benim ? '<p class="kr-p-bio bos" data-kr="duzenle">Kendini bir cümleyle anlat: biyografi ekle.</p>' : '');
    var sekmeler = [['gonderi', 'Gönderiler'], ['yanit', 'Yanıtlar'], ['one_cikan', 'Öne çıkanlar']].map(function (s) {
      return '<button type="button" class="' + (PROF.sekme === s[0] ? 'on' : '') + '" data-kr="psekme" data-sekme="' + s[0] + '"><span>' + s[1] + '</span></button>';
    }).join('');
    var govde;
    if (k.engelli) govde = bosHtml('Bu hesabın gönderilerini göremezsin', 'Aranızda engelleme var. Engeli Profilim > Engellediklerim bölümünden kaldırabilirsin.');
    else if (!liste.length && !r.sabit) govde = PROF.sekme === 'yanit' ? bosHtml('Henüz yanıt yok', k.benim ? 'Bir konuşmaya katıl; yanıtların burada toplanır.' : esc(k.kad) + ' henüz kimseye yanıt yazmadı.') :
      bosHtml(k.benim ? 'Kürsün boş duruyor' : 'Henüz gönderi yok', k.benim ? 'İlk gönderini yaz; takipçilerin akışında görünsün.' : esc(k.kad) + ' henüz kürsüye çıkmadı.', k.benim ? '<button type="button" class="kr-btn" data-kr="yaz">Gönderi yaz</button>' : '');
    else govde = (r.sabit ? gonderiHtml(r.sabit, { sabit: true }) : '') + listeHtml(liste.filter(function (x) { return !r.sabit || x.g.id !== r.sabit.id || x.yp; }));
    return '<div class="kr-kapak">' + kapakSvg(k.kapak) + '</div>' +
      '<div class="kr-p-ust"><span class="kr-p-av">' + av(k.kad, partiRenk(k.parti), 86) + '</span><div class="kr-p-btn">' + butonlar + '</div></div>' +
      '<div class="kr-p-kim"><h2>' + esc(k.kad) + nisan(k.unvan) + '</h2>' +
      '<div class="kr-p-unvan">' + esc(k.unvan || (k.parti ? k.parti.ad + ' üyesi' : 'Vatandaş')) + (k.beni_takip_ediyor && !k.benim ? '<span class="kr-seni">Seni takip ediyor</span>' : '') + '</div>' +
      bio + (meta.length ? '<div class="kr-p-meta">' + meta.join('') + '</div>' : '') +
      '<div class="kr-p-say"><button type="button" data-kr="liste" data-kad="' + esc(k.kad) + '" data-tur="takip"><b>' + say(k.takip) + '</b> Takip</button>' +
      '<button type="button" data-kr="liste" data-kad="' + esc(k.kad) + '" data-tur="takipci"><b>' + say(k.takipci) + '</b> Takipçi</button>' +
      '<span><b>' + say(k.begeni_alinan) + '</b> Beğeni</span></div>' +
      (!k.benim && n(k.ortak) ? '<div class="kr-ortak">' + I.kisi + 'Takip ettiğin ' + say(k.ortak) + ' kişiyi o da takip ediyor</div>' : '') + '</div>' +
      '<div class="kr-sekmeler kr-p-sekme">' + sekmeler + '</div>' +
      '<div id="krListe">' + govde + '</div><div id="krSon"></div>';
  }
  function profilSonDurum() {
    var s = document.getElementById('krSon'); if (!s) return;
    if (!PROF.imlec) { s.innerHTML = ''; return; }
    s.innerHTML = '<button type="button" class="kr-daha" data-kr="pdaha">Daha fazla göster</button>';
    sonsuzKur(profilDaha);
  }
  var pYuk = false;
  async function profilDaha() {
    if (pYuk || !PROF.imlec || !aktif('profil')) return; pYuk = true;
    var s = document.getElementById('krSon'); if (s) s.innerHTML = yukleHtml();
    try {
      var r = await rpc('kursu_profil', { p_kad: PROF.kad, p_sekme: PROF.sekme, p_imlec: PROF.imlec });
      if (!aktif('profil')) return;
      PROF.imlec = r.imlec;
      var l = document.getElementById('krListe'), t = document.createElement('div'); t.innerHTML = listeHtml(r.liste);
      while (t.firstChild) l.appendChild(t.firstChild); avTazele(l);
    } catch (err) { hata(err); PROF.imlec = null; }
    finally { pYuk = false; profilSonDurum(); }
  }
  async function profilSekme(s) {
    PROF.sekme = s;
    document.querySelectorAll('#icerik .kr-p-sekme button').forEach(function (b) { b.classList.toggle('on', b.dataset.sekme === s); });
    var l = document.getElementById('krListe'); if (l) l.innerHTML = iskeletGonderi(3);
    var sn = document.getElementById('krSon'); if (sn) sn.innerHTML = '';
    try {
      var r = await rpc('kursu_profil', { p_kad: PROF.kad, p_sekme: s, p_imlec: null });
      if (!aktif('profil') || PROF.sekme !== s) return;
      PROF.veri = r; PROF.imlec = r.imlec;
      var t = document.createElement('div'); t.innerHTML = profilHtml(r);
      var yeniL = t.querySelector('#krListe'); l = document.getElementById('krListe');
      if (l && yeniL) { l.innerHTML = yeniL.innerHTML; avTazele(l); }
      profilSonDurum();
    } catch (err) { hata(err); }
  }
  function profilDuzenle() {
    var r = PROF.veri; if (!r || !r.kisi.benim) return;
    var k = r.kisi, secili = k.kapak || 'mor';
    var m = modal('<div class="kr-duz"><h3>Kürsü profilin</h3>' +
      '<div class="kr-duz-kapak" id="krDuzKapak">' + kapakSvg(secili) + '<span class="kr-duz-av">' + av(k.kad, partiRenk(k.parti), 64) + '</span></div>' +
      '<label class="kr-duz-et">Kapak</label><div class="kr-renkler">' + Object.keys(KAPAK).map(function (a) {
        return '<button type="button" class="' + (a === secili ? 'on' : '') + '" data-kapak="' + a + '" aria-label="' + KAPAK[a][2] + '" style="background:linear-gradient(135deg,' + KAPAK[a][0] + ',' + KAPAK[a][1] + ')"></button>';
      }).join('') + '</div>' +
      '<label class="kr-duz-et" for="krBio">Biyografi</label><div class="kr-bio-kap"><textarea id="krBio" maxlength="160" rows="3" placeholder="Örnek: Ankara. Gençlik kollarından meclise. #eğitim">' + esc(k.bio_kendi || k.bio || '') + '</textarea><span id="krBioSay"></span></div>' +
      '<p class="kr-duz-not">En fazla 160 karakter. Küfür ve bağlantı kullanılamaz. #etiket ve @kişi yazabilirsin.</p>' +
      '<button type="button" class="kr-btn ikinci" id="krPortre">Portremi değiştir</button>' +
      '<button type="button" class="kr-btn" id="krKaydet">Kaydet</button></div>');
    m.querySelector('.modal').classList.add('kr-modal');
    var bio = m.querySelector('#krBio'), sayac = m.querySelector('#krBioSay');
    var yaz = function () { var l = bio.value.length; sayac.textContent = (160 - l); sayac.className = l > 140 ? 'az' : ''; };
    bio.oninput = yaz; yaz();
    m.querySelectorAll('[data-kapak]').forEach(function (b) {
      b.onclick = function () { secili = b.dataset.kapak; m.querySelectorAll('[data-kapak]').forEach(function (x) { x.classList.toggle('on', x === b); }); var kp = m.querySelector('#krDuzKapak svg'); var t = document.createElement('div'); t.innerHTML = kapakSvg(secili); kp.replaceWith(t.firstElementChild); };
    });
    m.querySelector('#krPortre').onclick = function () { modalKapat(); try { portreModal(); } catch (e) {} };
    var kb = m.querySelector('#krKaydet');
    kb.onclick = async function () {
      kb.disabled = true;
      try {
        await rpc('kursu_profil_guncelle', { p_bio: bio.value, p_kapak: secili, p_sabit: r.sabit ? r.sabit.id : null });
        modalKapat(); toast('Profilin güncellendi.'); hafif(); KR.benT = 0;
        window.kursuProfilEkrani(k.kad);
      } catch (err) { hata(err); kb.disabled = false; }
    };
  }
  window.kursuTakipListesi = async function (kad, tur) {
    var bas = function () { return '<div class="kr-sekmeler">' + [['takipci', 'Takipçiler'], ['takip', 'Takip edilenler']].map(function (s) { return '<button type="button" class="' + (tur === s[0] ? 'on' : '') + '" data-kr="tliste" data-kad="' + esc(kad) + '" data-tur="' + s[0] + '"><span>' + s[1] + '</span></button>'; }).join('') + '</div>'; };
    ciz('liste', baslik(esc(kad)), bas() + yukleHtml());
    try {
      var l = await rpc('kursu_takip_listesi', { p_kad: kad, p_tur: tur });
      if (!aktif('liste')) return;
      ciz('liste', baslik(esc(kad)), bas() + (l.length ? l.map(kisiSatir).join('') : bosHtml(tur === 'takipci' ? 'Henüz takipçi yok' : 'Henüz kimseyi takip etmiyor', tur === 'takipci' ? 'Takip edenler burada listelenir.' : 'Takip edilen hesaplar burada listelenir.')));
    } catch (err) { hata(err); }
  };

  /* =====================================================================
     KEŞFET: Türkiye gündemi ve arama
     ===================================================================== */
  var TUR_AD = { etiket: 'Etiket', kisi: 'Kişi', parti: 'Parti', dernek: 'Dernek' };
  function gundemBirlesik(gd) {
    var hepsi = [].concat(gd.etiketler || [], (gd.kisiler || []).filter(function (x) { return n(x.sayi) > 0; }), gd.partiler || [], gd.dernekler || []);
    hepsi.sort(function (a, b) { return n(b.sayi) - n(a.sayi) || (a.tur === 'etiket' ? -1 : 1); });
    return hepsi;
  }
  function gundemAt(x) {
    if (x.tur === 'etiket') return 'data-kr="etiket" data-et="' + esc(x.anahtar) + '"';
    if (x.tur === 'kisi') return 'data-kr="profil" data-kad="' + esc(x.anahtar) + '"';
    if (x.tur === 'parti') return 'data-kr="parti" data-id="' + esc(x.anahtar) + '"';
    return 'data-kr="dernek" data-id="' + esc(x.anahtar) + '"';
  }
  function gundemAlt(x) {
    if (x.tur === 'etiket') return say(x.sayi) + ' gönderi' + (n(x.kisi) > 1 ? ', ' + say(x.kisi) + ' kişi konuşuyor' : '');
    if (x.tur === 'kisi') return say(x.sayi) + ' kez konuşuldu' + (x.unvan ? ', ' + esc(x.unvan) : '');
    return say(x.sayi) + ' gönderide geçiyor';
  }
  function gundemAdHtml(x) {
    if (x.tur === 'kisi') return '<span class="kr-tr-kisi">' + av(x.ad, partiRenk(x.parti), 22) + esc(x.ad) + nisan(x.unvan) + '</span>';
    if (x.tur === 'parti') return '<span class="kr-tr-kisi"><span class="kr-pnok buyuk" style="background:' + esc(partiRenk(x.parti)) + '"></span>' + esc(x.ad) + '</span>';
    if (x.tur === 'dernek') return '<span class="kr-tr-kisi"><span class="kr-tr-ik">' + I.dernek + '</span>' + esc(x.ad) + '</span>';
    return esc(x.ad);
  }
  function kesfetGovde(gd) {
    if (!gd) return bosHtml('Gündem yüklenemedi', 'Biraz sonra yeniden dene.', '<button type="button" class="kr-btn" data-kr="kyenile">Yeniden dene</button>');
    var hepsi = gundemBirlesik(gd), f = KR.kesfetSuzgec;
    var sec = f === 'hepsi' ? hepsi : hepsi.filter(function (x) { return x.tur === f; });
    if (f === 'kisi') sec = (gd.kisiler || []).slice();
    var enCok = sec.reduce(function (m, x) { return Math.max(m, n(x.sayi)); }, 1);
    var sure = n(gd.saat) > 48 ? 'son 7 gün' : 'son 48 saat';
    var suz = [['hepsi', 'Tümü'], ['etiket', 'Etiketler'], ['kisi', 'Kişiler'], ['parti', 'Partiler'], ['dernek', 'Dernekler']].map(function (s) {
      var adet = s[0] === 'hepsi' ? hepsi.length : s[0] === 'kisi' ? (gd.kisiler || []).length : hepsi.filter(function (x) { return x.tur === s[0]; }).length;
      return '<button type="button" class="' + (f === s[0] ? 'on' : '') + '" data-kr="suz" data-f="' + s[0] + '">' + s[1] + (adet ? '<small>' + adet + '</small>' : '') + '</button>';
    }).join('');
    var zirve = '', liste = sec;
    if (sec.length) {
      var z = sec[0]; liste = sec.slice(1);
      zirve = '<button type="button" class="kr-zirve" ' + gundemAt(z) + '><span class="kr-zirve-ust">' + I.atesli + 'Türkiye’de 1 numara · ' + TUR_AD[z.tur] + '</span>' +
        '<b>' + gundemAdHtml(z) + '</b><span class="kr-zirve-alt">' + gundemAlt(z) + '</span><span class="kr-zirve-dalga" aria-hidden="true"></span></button>';
    }
    var satirlar = liste.map(function (x, i) {
      return '<div class="kr-trend" role="button" tabindex="0" ' + gundemAt(x) + '><span class="kr-tr-sira">' + (i + 2) + '</span><span class="kr-tr-g">' +
        '<small>' + TUR_AD[x.tur] + ' · Gündemde</small><b>' + gundemAdHtml(x) + '</b><small>' + gundemAlt(x) + '</small>' +
        '<span class="kr-tr-bar"><i style="width:' + Math.max(4, Math.round(n(x.sayi) / enCok * 100)) + '%"></i></span></span>' +
        (x.tur === 'kisi' && x.anahtar !== benKad() ? takipBtn({ kad: x.anahtar, takip_ediyorum: x.takip_ediyorum }, true) : '<span class="kr-tr-ok">' + I.ok + '</span>') + '</div>';
    }).join('');
    var oneri = (gd.oneriler || []).length ? '<div class="kr-bolum"><h3>Kimi takip etmeli</h3></div><div class="kr-oneri-kayan">' + gd.oneriler.map(function (k) {
      return '<div class="kr-okart" data-kr="profil" data-kad="' + esc(k.kad) + '"><span class="kr-av">' + av(k.kad, partiRenk(k.parti), 56) + '</span><b>' + esc(k.kad) + nisan(k.unvan) + '</b><small>' + esc(k.unvan || (k.parti ? k.parti.ad : 'Vatandaş')) + '</small>' +
        '<span class="kr-okart-say">' + say(k.takipci) + ' takipçi</span>' + takipBtn(k, true) + '</div>';
    }).join('') + '</div>' : '';
    return '<div class="kr-bolum kr-bolum-ilk"><h3>Türkiye gündemi</h3><span>' + sure + '</span></div>' +
      '<div class="kr-suzgec">' + suz + '</div>' +
      (sec.length ? zirve + satirlar : bosHtml('Gündem sessiz', 'Bu bölümde henüz konuşulan bir şey yok. #etiket kullanarak gündemi sen başlat.', '<button type="button" class="kr-btn" data-kr="yaz">Gönderi yaz</button>')) + oneri;
  }
  async function kesfetEkrani() {
    var ara = '<label class="kr-ara">' + I.ara + '<input id="krAra" type="search" enterkeyhint="search" autocomplete="off" placeholder="Kürsü’de ara: kişi, #etiket, söz"></label>';
    ciz('kesfet', baslik(), ara + '<div id="krAraSonuc" hidden></div><div id="krKesfet">' + (KR.gundem ? kesfetGovde(KR.gundem) : yukleHtml()) + '</div>', { sag: sagIkonlar('kesfet'), fab: function () { yazAc({ tur: 'yeni' }); } });
    aramaBagla();
    var gd = await gundemYukle(!KR.gundem || Date.now() - KR.gundemT > 45000);
    if (!aktif('kesfet')) return;
    var k = document.getElementById('krKesfet'); if (k) { k.innerHTML = kesfetGovde(gd); avTazele(k); }
    benYukle().then(rozetYaz);
  }
  function aramaBagla() {
    var g = document.getElementById('krAra'); if (!g) return;
    g.oninput = function () {
      clearTimeout(KR.araZaman);
      var q = g.value.trim(), s = document.getElementById('krAraSonuc'), k = document.getElementById('krKesfet');
      if (q.length < 2) { s.hidden = true; s.innerHTML = ''; k.hidden = false; return; }
      KR.araZaman = setTimeout(async function () {
        s.hidden = false; k.hidden = true; s.innerHTML = yukleHtml();
        try {
          var r = await rpc('kursu_ara', { p_q: q });
          if (g.value.trim() !== q) return;
          var h = '';
          if ((r.kisiler || []).length) h += '<div class="kr-bolum"><h3>Kişiler</h3></div>' + r.kisiler.map(kisiSatir).join('');
          if ((r.etiketler || []).length) h += '<div class="kr-bolum"><h3>Etiketler</h3></div>' + r.etiketler.map(function (x) { return '<div class="kr-trend" role="button" tabindex="0" data-kr="etiket" data-et="' + esc(x.anahtar) + '"><span class="kr-tr-sira kr-tr-diyez">#</span><span class="kr-tr-g"><b>' + esc(x.ad) + '</b><small>' + say(x.sayi) + ' gönderi</small></span><span class="kr-tr-ok">' + I.ok + '</span></div>'; }).join('');
          if ((r.gonderiler || []).length) h += '<div class="kr-bolum"><h3>Gönderiler</h3></div>' + r.gonderiler.map(function (x) { return gonderiHtml(x); }).join('');
          s.innerHTML = h || bosHtml('Sonuç yok', '“' + esc(q) + '” için bir şey bulunamadı. Başka bir kelime dene.');
          avTazele(s);
        } catch (err) { s.innerHTML = bosHtml('Arama yapılamadı', esc(hataMetni(err))); }
      }, 320);
    };
  }

  /* =====================================================================
     ETİKET
     ===================================================================== */
  var ET = { ad: null, imlec: null };
  window.kursuEtiketEkrani = async function (et) {
    et = String(et || '').replace(/^#/, '').toLocaleLowerCase('tr-TR');
    ET.ad = et; ET.imlec = null;
    var bas = '<div class="kr-et-bas"><span class="kr-et-diyez">#</span><div><h2>#' + esc(et) + '</h2><span id="krEtSay">Gönderiler yükleniyor</span></div>' +
      '<button type="button" class="kr-btn kucuk" data-kr="etyaz" data-et="' + esc(et) + '">Bu etiketle yaz</button></div>';
    ciz('etiket', baslik('#' + esc(et)), bas + '<div id="krListe">' + iskeletGonderi(4) + '</div><div id="krSon"></div>', { fab: function () { yazAc({ tur: 'yeni', metin: '#' + et + ' ' }); } });
    try {
      var r = await rpc('kursu_etiket', { p_etiket: et, p_imlec: null });
      if (!aktif('etiket') || ET.ad !== et) return;
      ET.imlec = r.imlec;
      var s = document.getElementById('krEtSay'); if (s) s.textContent = say(r.sayi) + ' gönderi';
      var l = document.getElementById('krListe');
      l.innerHTML = (r.liste || []).length ? listeHtml(r.liste) : bosHtml('Bu etikette henüz gönderi yok', 'İlk sözü sen söyle; etiketi gündeme sen taşı.', '<button type="button" class="kr-btn" data-kr="etyaz" data-et="' + esc(et) + '">#' + esc(et) + ' ile yaz</button>');
      avTazele(l); etiketSon();
    } catch (err) { var l2 = document.getElementById('krListe'); if (l2) l2.innerHTML = bosHtml('Yüklenemedi', esc(hataMetni(err))); }
  };
  function etiketSon() {
    var s = document.getElementById('krSon'); if (!s) return;
    if (!ET.imlec) { s.innerHTML = ''; return; }
    s.innerHTML = '<button type="button" class="kr-daha" data-kr="etdaha">Daha fazla göster</button>';
    sonsuzKur(etiketDaha);
  }
  var eYuk = false;
  async function etiketDaha() {
    if (eYuk || !ET.imlec || !aktif('etiket')) return; eYuk = true;
    try {
      var r = await rpc('kursu_etiket', { p_etiket: ET.ad, p_imlec: ET.imlec });
      if (!aktif('etiket')) return; ET.imlec = r.imlec;
      var l = document.getElementById('krListe'), t = document.createElement('div'); t.innerHTML = listeHtml(r.liste);
      while (t.firstChild) l.appendChild(t.firstChild); avTazele(l);
    } catch (err) { hata(err); ET.imlec = null; }
    finally { eYuk = false; etiketSon(); }
  }

  /* =====================================================================
     BİLDİRİMLER
     ===================================================================== */
  var BIL = {
    takip: [I.kisiArti, 'mor', function (x) { return '<b>' + esc(x.kad) + '</b> seni takip etmeye başladı'; }],
    yp: [I.yp, 'yesil', function (x) { return '<b>' + esc(x.kad) + '</b> gönderini yeniden paylaştı'; }],
    yanit: [I.yanit, 'mavi', function (x) { return '<b>' + esc(x.kad) + '</b> gönderine yanıt verdi'; }],
    alinti: [I.alinti, 'mavi', function (x) { return '<b>' + esc(x.kad) + '</b> gönderini alıntıladı'; }],
    anma: [I.kalem, 'turuncu', function (x) { return '<b>' + esc(x.kad) + '</b> senden bahsetti'; }],
    begeni: [I.kalpDolu, 'pembe', function (x) { return 'Gönderin <b>' + say(x.sayi) + ' beğeni</b> aldı'; }]
  };
  async function bildirimEkrani() {
    ciz('bildirim', baslik(), '<div class="kr-bolum kr-bolum-ilk"><h3>Bildirimler</h3><span>son 7 gün</span></div>' + yukleHtml(), { sag: sagIkonlar('bildirim') });
    var r;
    try { r = await rpc('kursu_bildirimler', { p_okundu: true }); }
    catch (err) { if (aktif('bildirim')) document.querySelector('#icerik .kr').insertAdjacentHTML('beforeend', bosHtml('Bildirimler yüklenemedi', esc(hataMetni(err)))); return; }
    if (!aktif('bildirim')) return;
    if (KR.ben) KR.ben.yeni = 0;
    var okundu = r.okundu ? new Date(r.okundu).getTime() : 0, liste = r.liste || [];
    var h = liste.map(function (x) {
      var b = BIL[x.tur]; if (!b) return '';
      var yeni = new Date(x.zaman).getTime() > okundu;
      var g = x.g, hedef = x.tur === 'takip' ? 'data-kr="profil" data-kad="' + esc(x.kad) + '"' : (g ? 'data-kr="ac" data-id="' + g.id + '"' : '');
      var ozet = '';
      if (g && (x.tur === 'yanit' || x.tur === 'alinti' || x.tur === 'anma')) { kaydet(g); ozet = '<div class="kr-bil-metin">' + metinHtml(g.metin) + '</div>' + eylemHtml(g, false); }
      else if (g) ozet = '<div class="kr-bil-ozet">' + esc(g.metin) + '</div>';
      var avl = x.kad ? '<span class="kr-av" data-kr="profil" data-kad="' + esc(x.kad) + '">' + av(x.kad, x.kisi && partiRenk(x.kisi.parti), 32) + '</span>' : '';
      return '<div class="kr-bil' + (yeni ? ' yeni' : '') + (ozet && x.tur !== 'begeni' && x.tur !== 'yp' ? ' kr-g' : '') + '" ' + hedef + (g ? ' data-id="' + g.id + '"' : '') + '>' +
        '<span class="kr-bil-ik ' + b[1] + '">' + b[0] + '</span><div class="kr-bil-g"><div class="kr-bil-ust">' + avl + '<span class="kr-sure">' + esc(ne(x.zaman)) + '</span></div>' +
        '<p>' + b[2](x) + '</p>' + ozet + (x.tur === 'takip' && x.kisi && !x.kisi.takip_ediyorum ? takipBtn(x.kisi, true) : '') + '</div></div>';
    }).join('');
    var k = document.querySelector('#icerik .kr'); if (!k) return;
    var y = k.querySelector('.kr-yuk'); if (y) y.remove();
    k.insertAdjacentHTML('beforeend', h || bosHtml('Henüz bildirim yok', 'Biri seni takip ettiğinde, gönderine yanıt verdiğinde ya da senden bahsettiğinde burada görürsün.', '<button type="button" class="kr-btn" data-kr="yaz">Bir şey paylaş</button>'));
    avTazele(k); rozetYaz();
  }

  /* =====================================================================
     YAZMA PENCERESİ (yeni gönderi, yanıt, alıntı)
     ===================================================================== */
  function yazAc(opt) {
    opt = opt || {};
    var p = profil(); if (!p) return;
    yazKapat();
    var tur = opt.tur || 'yeni', g = opt.g;
    var yer = tur === 'yanit' ? 'Yanıtını yaz' : tur === 'alinti' ? 'Bir yorum ekle' : 'Neler oluyor?';
    var baglam = '';
    if (tur === 'yanit' && g) baglam = '<div class="kr-yaz-baglam"><span class="kr-av">' + av(g.kad, partiRenk(g.parti), 40) + '</span><div><div class="kr-bas"><b class="kr-ad">' + esc(g.kad) + '</b>' + nisan(g.unvan) + '<span class="kr-sure">' + esc(ne(g.zaman)) + '</span></div><div class="kr-metin">' + metinHtml(g.metin) + '</div><div class="kr-yanitnot"><span>@' + esc(g.kad) + '</span> kişisine yanıt veriyorsun</div></div></div>';
    var et = (KR.gundem && KR.gundem.etiketler || []).slice(0, 6);
    var w = document.createElement('div'); w.className = 'kr-yaz-arka'; w.id = 'krYaz';
    w.innerHTML = '<div class="kr-yaz" role="dialog" aria-modal="true" aria-label="' + (tur === 'yanit' ? 'Yanıt yaz' : 'Gönderi yaz') + '">' +
      '<div class="kr-yaz-ust"><button type="button" class="kr-yaz-iptal" id="krYazIptal">Vazgeç</button><span class="kr-yaz-tur">' + (tur === 'yanit' ? 'Yanıt' : tur === 'alinti' ? 'Alıntı' : 'Yeni gönderi') + '</span><button type="button" class="kr-yaz-gonder" id="krYazGonder" disabled>' + (tur === 'yanit' ? 'Yanıtla' : 'Paylaş') + '</button></div>' +
      '<div class="kr-yaz-govde">' + baglam + '<div class="kr-yaz-satir"><span class="kr-av">' + av(p.kad, p.parti && p.parti.renk, 40) + '</span><textarea id="krYazMetin" maxlength="280" rows="3" placeholder="' + yer + '"></textarea></div>' +
      (tur === 'alinti' && g ? '<div class="kr-yaz-alinti">' + alintiHtml(g) + '</div>' : '') + '</div>' +
      '<div class="kr-yaz-alt">' + (et.length ? '<div class="kr-yaz-et">' + et.map(function (x) { return '<button type="button" data-ekle="' + esc(x.ad) + '">' + esc(x.ad) + '</button>'; }).join('') + '</div>' : '<div class="kr-yaz-ipucu">#etiket ile gündeme gir, @isim ile birini an.</div>') +
      '<span class="kr-halka" id="krHalka"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9.5" class="z"/><circle cx="12" cy="12" r="9.5" class="d" id="krHalkaD"/></svg><b id="krKalan"></b></span></div></div>';
    document.body.appendChild(w);
    avTazele(w);
    var t = w.querySelector('#krYazMetin'), gb = w.querySelector('#krYazGonder');
    if (opt.metin) t.value = opt.metin;
    var cevre = 2 * Math.PI * 9.5;
    var guncelle = function () {
      t.style.height = 'auto'; t.style.height = Math.min(t.scrollHeight, 280) + 'px';
      var l = t.value.length, kalan = 280 - l, d = w.querySelector('#krHalkaD'), kb = w.querySelector('#krKalan'), h = w.querySelector('#krHalka');
      d.setAttribute('stroke-dasharray', cevre); d.setAttribute('stroke-dashoffset', cevre * (1 - Math.min(1, l / 280)));
      h.className = 'kr-halka' + (kalan <= 20 ? ' az' : '') + (l === 0 ? ' bos' : '');
      kb.textContent = kalan <= 20 ? kalan : '';
      gb.disabled = !t.value.trim();
    };
    t.oninput = guncelle; guncelle();
    w.querySelectorAll('[data-ekle]').forEach(function (b) {
      b.onclick = function () { var v = t.value, ek = b.dataset.ekle; if (v.indexOf(ek) < 0) { t.value = (v && !/\s$/.test(v) ? v + ' ' : v) + ek + ' '; guncelle(); } t.focus(); };
    });
    w.querySelector('#krYazIptal').onclick = yazKapat;
    w.addEventListener('click', function (ev) { if (ev.target === w) yazKapat(); });
    gb.onclick = async function () {
      var m = t.value.trim(); if (!m) return;
      gb.disabled = true; gb.textContent = 'Gönderiliyor';
      try {
        var r;
        if (tur === 'yanit') r = await rpc('akis_yanit_yaz', { p_id: g.id, p_metin: m });
        else if (tur === 'alinti') r = await rpc('kursu_alinti', { p_id: g.id, p_metin: m });
        else r = await rpc('akis_yaz', { p_metin: m });
        hafif(); yazKapat();
        toast(tur === 'yanit' ? 'Yanıtın gönderildi.' : tur === 'alinti' ? 'Alıntın yayında.' : 'Gönderin yayında.');
        if (tur === 'yanit' && g && KR.g[g.id]) { KR.g[g.id].yanit = n(KR.g[g.id].yanit) + 1; sayacGuncelle(g.id); }
        if (tur === 'alinti' && g && KR.g[g.id]) KR.g[g.id].alinti_sayi = n(KR.g[g.id].alinti_sayi) + 1;
        KR.gundemT = 0; KR.benT = 0;
        Object.keys(KR.akis).forEach(function (s) { KR.akis[s].t = 0; });
        if (opt.sonra) opt.sonra(r);
        else if (aktif('gonderi') && tur === 'yanit') yenidenCiz();
        else if (aktif('ana')) anaYenile();
        else if (aktif('profil') && PROF.kad === benKad()) window.kursuProfilEkrani(PROF.kad);
        else if (aktif('etiket')) window.kursuEtiketEkrani(ET.ad);
      } catch (err) { hata(err); gb.disabled = false; gb.textContent = tur === 'yanit' ? 'Yanıtla' : 'Paylaş'; }
    };
    setTimeout(function () { try { t.focus(); var L = t.value.length; t.setSelectionRange(L, L); } catch (e) {} }, 60);
  }
  function yazKapat() { var w = document.getElementById('krYaz'); if (w) w.remove(); }
  window.kursuYaz = function (metin) { yazAc({ tur: 'yeni', metin: metin || '' }); };

  /* =====================================================================
     ETKİLEŞİMLER
     ===================================================================== */
  async function tepki(id, tur, btn) {
    var g = KR.g[id]; if (!g) return;
    var once = { begeni: g.begeni, begenmeme: g.begenmeme, begendim: g.begendim, begenmedim: g.begenmedim };
    // iyimser güncelleme: aynı tepkiye basmak kaldırır, diğerini açmak öbürünü kapatır
    if (tur === 'begen') { if (g.begendim) { g.begendim = false; g.begeni = n(g.begeni) - 1; } else { g.begendim = true; g.begeni = n(g.begeni) + 1; if (g.begenmedim) { g.begenmedim = false; g.begenmeme = n(g.begenmeme) - 1; } } }
    else { if (g.begenmedim) { g.begenmedim = false; g.begenmeme = n(g.begenmeme) - 1; } else { g.begenmedim = true; g.begenmeme = n(g.begenmeme) + 1; if (g.begendim) { g.begendim = false; g.begeni = n(g.begeni) - 1; } } }
    var acildi = tur === 'begen' ? g.begendim : g.begenmedim;
    sayacGuncelle(id, acildi ? tur : null); hafif();
    try { var r = await rpc('akis_tepki', { p_id: id, p_tepki: tur }); Object.assign(g, r); sayacGuncelle(id); }
    catch (err) { Object.assign(g, once); sayacGuncelle(id); hata(err); }
  }
  async function ypYap(id, ac) {
    var g = KR.g[id]; if (!g) return;
    var once = { yp: g.yp, ypledim: g.ypledim };
    g.ypledim = ac; g.yp = Math.max(0, n(g.yp) + (ac ? 1 : -1)); sayacGuncelle(id, ac ? 'yp' : null); hafif();
    try { var r = await rpc('kursu_yp', { p_id: id, p_ac: ac }); Object.assign(g, r); sayacGuncelle(id); toast(ac ? 'Yeniden paylaştın.' : 'Yeniden paylaşımı geri aldın.'); Object.keys(KR.akis).forEach(function (s) { if (s === 'takip') KR.akis[s].t = 0; }); }
    catch (err) { Object.assign(g, once); sayacGuncelle(id); hata(err); }
  }
  function sayfa(html) {
    var m = modal('<div class="kr-sayfa">' + html + '</div>'); m.querySelector('.modal').classList.add('kr-modal'); return m;
  }
  function ypMenu(id) {
    var g = KR.g[id]; if (!g) return;
    var m = sayfa('<button type="button" class="kr-sf" data-sf="yp">' + I.yp + '<span>' + (g.ypledim ? 'Yeniden paylaşımı geri al' : 'Yeniden paylaş') + '<small>' + (g.ypledim ? 'Takipçilerinin akışından kalkar' : 'Takipçilerinin akışında görünür') + '</small></span></button>' +
      '<button type="button" class="kr-sf" data-sf="alinti">' + I.alinti + '<span>Alıntıla<small>Kendi yorumunla paylaş</small></span></button>' +
      '<button type="button" class="kr-sf iptal" data-sf="iptal">Vazgeç</button>');
    m.querySelector('[data-sf="yp"]').onclick = function () { modalKapat(); ypYap(id, !g.ypledim); };
    m.querySelector('[data-sf="alinti"]').onclick = function () { modalKapat(); yazAc({ tur: 'alinti', g: g }); };
    m.querySelector('[data-sf="iptal"]').onclick = modalKapat;
  }
  function gonderiMenu(id) {
    var g = KR.g[id]; if (!g) return;
    var yenile = function () { Object.keys(KR.akis).forEach(function (s) { KR.akis[s].t = 0; }); if (aktif('gonderi') && D.yigin.length) geriGit(); else yenidenCiz(); };
    if (g.benim) {
      var sabitMi = PROF.veri && PROF.veri.sabit && PROF.veri.sabit.id === g.id;
      var m = sayfa((g.yanit_id ? '' : '<button type="button" class="kr-sf" data-sf="sabit">' + I.raptiye + '<span>' + (sabitMi ? 'Profilinden kaldır' : 'Profiline sabitle') + '<small>' + (sabitMi ? 'Sabitlenmiş gönderi kalkar' : 'Profilinin en üstünde durur') + '</small></span></button>') +
        '<button type="button" class="kr-sf tehlike" data-sf="sil">' + I.sil + '<span>Gönderiyi sil<small>Geri alınamaz</small></span></button>' +
        '<button type="button" class="kr-sf iptal" data-sf="iptal">Vazgeç</button>');
      var sb = m.querySelector('[data-sf="sabit"]');
      if (sb) sb.onclick = async function () { modalKapat(); try { await rpc('kursu_sabitle', { p_id: sabitMi ? null : g.id }); toast(sabitMi ? 'Sabitleme kaldırıldı.' : 'Profiline sabitlendi.'); if (aktif('profil')) window.kursuProfilEkrani(PROF.kad); } catch (err) { hata(err); } };
      m.querySelector('[data-sf="sil"]').onclick = async function () {
        modalKapat();
        if (!(await onayla('Gönderi silinsin mi?', 'Gönderin, yanıt sayıları ve beğenileriyle birlikte kaldırılır.', 'Sil', true))) return;
        try { await rpc('akis_sil', { p_id: g.id }); toast('Gönderi silindi.'); document.querySelectorAll('.kr-g[data-id="' + g.id + '"]').forEach(function (x) { x.remove(); }); delete KR.g[g.id]; Object.keys(KR.akis).forEach(function (s) { KR.akis[s].liste = KR.akis[s].liste.filter(function (x) { return x.g.id !== g.id; }); }); if (aktif('gonderi')) geriGit(); }
        catch (err) { hata(err); }
      };
      m.querySelector('[data-sf="iptal"]').onclick = modalKapat;
      return;
    }
    var takipte = !!g.takip_ediyorum;
    var m2 = sayfa('<button type="button" class="kr-sf" data-sf="takip">' + I.kisiArti + '<span>' + (takipte ? esc(g.kad) + ' takibini bırak' : esc(g.kad) + ' takip et') + '</span></button>' +
      '<button type="button" class="kr-sf" data-sf="profil">' + I.kisi + '<span>Profili gör</span></button>' +
      '<button type="button" class="kr-sf tehlike" data-sf="sikayet">' + I.kalkan + '<span>Şikâyet et veya engelle</span></button>' +
      '<button type="button" class="kr-sf iptal" data-sf="iptal">Vazgeç</button>');
    m2.querySelector('[data-sf="takip"]').onclick = function () { modalKapat(); takip(g.kad, !takipte); };
    m2.querySelector('[data-sf="profil"]').onclick = function () { modalKapat(); ekranAc(function () { return window.kursuProfilEkrani(g.kad); }); };
    m2.querySelector('[data-sf="sikayet"]').onclick = function () { modalKapat(); try { akisMenu({ id: g.id, kad: g.kad, benim: false }, yenile); } catch (e) {} };
    m2.querySelector('[data-sf="iptal"]').onclick = modalKapat;
  }
  async function takip(kad, ac, btn) {
    var dugmeler = document.querySelectorAll('.kr-takip[data-kad="' + (window.CSS && CSS.escape ? CSS.escape(kad) : kad) + '"]');
    if (!ac && btn && !(await onayla(esc(kad) + ' takibi bırakılsın mı?', 'Gönderileri artık Takip ettiklerin akışında görünmez.', 'Takibi bırak', true))) return;
    dugmeler.forEach(function (b) { b.disabled = true; });
    try {
      var k = await rpc('kursu_takip_et', { p_kad: kad, p_takip: ac });
      hafif();
      document.querySelectorAll('.kr-takip[data-kad="' + (window.CSS && CSS.escape ? CSS.escape(kad) : kad) + '"]').forEach(function (b) {
        var t = document.createElement('div'); t.innerHTML = takipBtn(k, b.classList.contains('kucuk')); if (t.firstElementChild) b.replaceWith(t.firstElementChild);
      });
      Object.keys(KR.g).forEach(function (id) { if (KR.g[id].kad === kad) KR.g[id].takip_ediyorum = !!k.takip_ediyorum; });
      if (KR.akis.takip) KR.akis.takip.t = 0;
      KR.benT = 0;
      if (aktif('profil') && PROF.veri && PROF.veri.kisi.kad === kad) {
        PROF.veri.kisi.takip_ediyorum = k.takip_ediyorum; PROF.veri.kisi.takipci = k.takipci;
        var tb = document.querySelector('#icerik .kr-p-say [data-tur="takipci"] b'); if (tb) tb.textContent = say(k.takipci);
      }
      toast(ac ? kad + ' takip ediliyor.' : kad + ' takibi bırakıldı.');
    } catch (err) { hata(err); dugmeler.forEach(function (b) { b.disabled = false; }); }
  }
  async function paylasDis(id) {
    var g = KR.g[id]; if (!g) return;
    var metin = g.kad + ' Kürsü’de: “' + g.metin + '” — Seçim Simülasyonu Online';
    try { if (navigator.share) { await navigator.share({ text: metin }); return; } } catch (e) { if (e && e.name === 'AbortError') return; }
    try { await navigator.clipboard.writeText(metin); toast('Gönderi metni kopyalandı.'); } catch (e) { toast('Paylaşılamadı.', true); }
  }
  function git(fn) { ekranAc(fn); }
  function altGit(alt) {
    // Kürsü bölümleri arasında geçiş: yığının en üstündeki Kürsü ekranının yerine geç
    var f = function () { return window.kursuEkrani(alt); };
    if (D.yigin.length && KR.ekran && aktif(KR.ekran) && ['ana', 'kesfet', 'bildirim'].indexOf(KR.ekran) >= 0) { D.yigin[D.yigin.length - 1] = f; D._ekranNo = (D._ekranNo || 0) + 1; f(); }
    else ekranAc(f);
  }

  // Tek tıklama dinleyicisi (yakalama evresi): Kürsü ögeleri her yerde (Gündem önizlemesi dahil) çalışır
  document.addEventListener('click', function (ev) {
    var el = ev.target && ev.target.closest ? ev.target.closest('[data-kr]') : null;
    if (!el) return;
    if (!el.closest('#app,#modal,#krYaz')) return;
    var k = el.dataset.kr, id = n(el.dataset.id);
    // Gönderinin içindeki seçili metni kopyalamaya çalışan oyuncuyu rahatsız etme
    if (k === 'ac') { try { var sel = window.getSelection && String(window.getSelection()); if (sel && sel.length > 1) return; } catch (e) {} }
    ev.preventDefault(); ev.stopPropagation();
    switch (k) {
      case 'ac': if (id) git(function () { return window.kursuGonderiEkrani(id); }); break;
      case 'profil': if (el.dataset.kad) { var kad = el.dataset.kad; if (aktif('profil') && PROF.kad && PROF.kad.toLocaleLowerCase('tr-TR') === kad.toLocaleLowerCase('tr-TR')) { var kk = kok(); if (kk) kk.scrollTo({ top: 0, behavior: 'smooth' }); break; } modalKapat(); git(function () { return window.kursuProfilEkrani(kad); }); } break;
      case 'etiket': if (el.dataset.et) { var et = el.dataset.et; git(function () { return window.kursuEtiketEkrani(et); }); } break;
      case 'yanit': if (KR.g[id]) yazAc({ tur: 'yanit', g: KR.g[id] }); break;
      case 'yp': if (KR.g[id]) ypMenu(id); else ekranAc(function () { return window.kursuGonderiEkrani(id); }); break;
      case 'begen': case 'begenme': tepki(id, k, el); break;
      case 'paylas': paylasDis(id); break;
      case 'menu': gonderiMenu(id); break;
      case 'takip': takip(el.dataset.kad, el.dataset.on !== '1', el); break;
      case 'yaz': yazAc({ tur: 'yeni' }); break;
      case 'etyaz': yazAc({ tur: 'yeni', metin: '#' + el.dataset.et + ' ' }); break;
      case 'sekme': if (el.dataset.sekme !== KR.sekme) { KR.sekme = el.dataset.sekme; window.kursuEkrani('ana'); } else { var kp = kok(); if (kp && kp.scrollTop > 0) kp.scrollTo({ top: 0, behavior: 'smooth' }); else anaYenile(); } break;
      case 'yenile': anaYenile(); break;
      case 'tazele': anaYenile(); break;
      case 'daha': daha(); break;
      case 'pdaha': profilDaha(); break;
      case 'etdaha': etiketDaha(); break;
      case 'psekme': if (el.dataset.sekme !== PROF.sekme) profilSekme(el.dataset.sekme); break;
      case 'duzenle': profilDuzenle(); break;
      case 'liste': var lk = el.dataset.kad, lt = el.dataset.tur; git(function () { return window.kursuTakipListesi(lk, lt); }); break;
      case 'tliste': var tk = el.dataset.kad, tt = el.dataset.tur; D.yigin[D.yigin.length - 1] = function () { return window.kursuTakipListesi(tk, tt); }; window.kursuTakipListesi(tk, tt); break;
      case 'git': altGit(el.dataset.alt); break;
      case 'ev': if (KR.ekran === 'ana' && aktif('ana')) { var ke = kok(); if (ke) ke.scrollTo({ top: 0, behavior: 'smooth' }); } else altGit('ana'); break;
      case 'suz': KR.kesfetSuzgec = el.dataset.f; var kf = document.getElementById('krKesfet'); if (kf) { kf.innerHTML = kesfetGovde(KR.gundem); avTazele(kf); } break;
      case 'kyenile': kesfetEkrani(); break;
      case 'dm': try { var dk = el.dataset.kad; ekranAc(function () { return ozelEkrani(dk); }); } catch (e) {} break;
      case 'kart': try { oyuncuKart(el.dataset.kad); } catch (e) {} break;
      case 'parti': if (id && typeof partiDetay === 'function') ekranAc(function () { return partiDetay(id); }); break;
      case 'dernek': if (id && typeof stkDetay === 'function') ekranAc(function () { return stkDetay(id); }); break;
    }
  }, true);
  document.addEventListener('keydown', function (ev) {
    if (ev.key === 'Escape' && document.getElementById('krYaz')) yazKapat();
    if (ev.key === 'Enter' && (ev.metaKey || ev.ctrlKey)) { var b = document.getElementById('krYazGonder'); if (b && !b.disabled) b.click(); }
  });

  /* =====================================================================
     AKIŞ İLE BÜTÜNLEŞME
     ===================================================================== */
  // Eski Akış ekranları artık Kürsü'yü açar
  window.akisEkrani = function (etiket) { return etiket ? window.kursuEtiketEkrani(etiket) : window.kursuEkrani('ana'); };
  window.akisKonuEkrani = function (id, yaz) { return window.kursuGonderiEkrani(id, yaz); };
  // Gündem'deki Akış önizlemesi Kürsü görünümünde çizilir; eski bağlayıcılar (akisBagla) aynen çalışır
  window.akisSatirHtml = function (a, opt) {
    if (!a) return '';
    var ana = opt && typeof opt === 'object' && opt.ana;
    var g = KR.g[a.id];
    if (g) ['yp', 'ypledim', 'alinti_sayi', 'alinti', 'yanit_kad'].forEach(function (k) { if (a[k] === undefined && g[k] !== undefined) a[k] = g[k]; });
    return gonderiHtml(a, { uyum: !ana, odak: !!ana });
  };
  // Gündem'deki "Akış" başlığını Kürsü yap
  function gundemBasligi() {
    var b = document.querySelector('#icerik .so-canli-akis > .bolum-bas');
    if (!b || b.dataset.kr) return;
    var h = b.querySelector('h2'); if (!h || !/Akış/.test(h.textContent)) return;
    b.dataset.kr = '1';
    h.innerHTML = '<span class="kr-gb">' + logo(24) + 'Kürsü<span class="kr-gb-c">canlı</span></span>';
    var btn = b.querySelector('button'); if (btn) { btn.textContent = 'Kürsü’ye git'; btn.removeAttribute('onclick'); btn.setAttribute('data-kr', 'git'); btn.setAttribute('data-alt', 'ana'); btn.classList.add('kr-gb-git'); }
    var kart = b.parentNode.querySelector('.akis-kart');
    if (kart && !kart.querySelector('.kr-gb-yaz')) {
      var p = profil(), t = kart.querySelector('#gAkisMetin');
      if (t) t.setAttribute('placeholder', 'Neler oluyor' + (p ? ', ' + p.kad : '') + '? #etiket ve @isim yazabilirsin');
    }
  }
  try {
    new MutationObserver(function () { if (document.querySelector('#icerik .so-canli-akis')) gundemBasligi(); })
      .observe(document.getElementById('app') || document.body, { childList: true, subtree: true });
  } catch (e) {}

  /* =====================================================================
     STİL
     ===================================================================== */
  var st = document.createElement('style'); st.id = 'kursuStil';
  st.textContent = [
    ':root{--kr-mor:#8b6cff;--kr-pembe:#ff4f8b;--kr-yesil:#22d39a;--kr-mavi:#4cc3ff;--kr-turuncu:#ffa24c;--kr-cizgi:rgba(164,184,255,.11);--kr-soluk:#8f9bbd;--kr-yuzey:#141c3a;--kr-grad:linear-gradient(135deg,#8b6cff,#ff4f8b)}',
    '.kr{margin:-14px -16px 0;min-height:60vh;font-size:15px;color:var(--txt)}',
    '.kr button{font:inherit;color:inherit;-webkit-tap-highlight-color:transparent}',
    '.kr-baslik{display:inline-flex;align-items:center;gap:9px;cursor:pointer;font-family:var(--disp);font-weight:800;letter-spacing:.2px}',
    '.kr-baslik .kr-logo{flex:none}',
    '.kr-baslik-alt{cursor:default;overflow:hidden;text-overflow:ellipsis}',
    '.kr-sag{display:flex;gap:4px;align-items:center;flex:none}',
    '.kr-ust-b{position:relative;width:38px;height:38px;border-radius:50%;display:grid;place-items:center;color:var(--txt2);background:none;border:0;cursor:pointer}',
    '.kr-ust-b svg{width:22px;height:22px}.kr-ust-b.on{color:#fff;background:rgba(139,108,255,.18)}.kr-ust-b:active{transform:scale(.92)}',
    '.kr-ust-av .portre,.kr-ust-av svg.portre{width:30px!important;height:30px!important;border-radius:50%;box-shadow:0 0 0 2px var(--bg)}.kr-ust-av.on .portre{box-shadow:0 0 0 2px var(--kr-mor)}',
    '.kr-rozet{position:absolute;top:2px;right:0;min-width:17px;height:17px;padding:0 4px;border-radius:9px;background:var(--kr-pembe);color:#fff;font:700 10.5px/17px system-ui;text-align:center;box-shadow:0 0 0 2px var(--bg)}',
    /* sekmeler */
    '.kr-sekmeler{position:sticky;top:-14px;z-index:8;display:flex;background:rgba(14,21,48,.86);-webkit-backdrop-filter:saturate(170%) blur(18px);backdrop-filter:saturate(170%) blur(18px);border-bottom:1px solid var(--kr-cizgi);overflow-x:auto;scrollbar-width:none}',
    '.kr-sekmeler::-webkit-scrollbar{display:none}',
    '.kr-sekmeler>button{flex:1 0 auto;min-width:0;padding:0 14px;height:48px;background:none;border:0;color:var(--kr-soluk);font-weight:600!important;font-size:14.5px!important;cursor:pointer;display:flex;justify-content:center;white-space:nowrap}',
    '.kr-sekmeler>button>span{position:relative;display:flex;align-items:center;height:100%}',
    '.kr-sekmeler>button.on{color:#fff;font-weight:800!important}',
    '.kr-sekmeler>button.on>span::after{content:"";position:absolute;left:-4px;right:-4px;bottom:0;height:4px;border-radius:4px 4px 0 0;background:var(--kr-grad)}',
    /* yaz kutusu */
    '.kr-sor{display:flex;align-items:center;gap:12px;width:100%;padding:12px 16px;background:none;border:0;border-bottom:1px solid var(--kr-cizgi);cursor:text;text-align:left}',
    '.kr-sor-m{flex:1;color:var(--kr-soluk);font-size:16.5px;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.kr-sor-b{flex:none;padding:7px 16px;border-radius:999px;background:var(--kr-grad);color:#fff;font-weight:800;font-size:14px;box-shadow:0 6px 18px -6px rgba(255,79,139,.6)}',
    '.kr-av{flex:none;display:block;line-height:0;cursor:pointer}.kr-av .portre,.kr-av svg{border-radius:50%;display:block}',
    /* gündem şeridi */
    '.kr-serit{display:flex;gap:8px;overflow-x:auto;padding:10px 16px;border-bottom:1px solid var(--kr-cizgi);scrollbar-width:none;align-items:center}',
    '.kr-serit::-webkit-scrollbar{display:none}',
    '.kr-serit-b{flex:none;display:inline-flex;align-items:center;gap:5px;font-size:13px;font-weight:800;color:var(--kr-turuncu)}.kr-serit-b svg{width:16px;height:16px}',
    '.kr-serit>button{flex:none;display:inline-flex;align-items:center;gap:6px;padding:6px 12px;border-radius:999px;background:rgba(139,108,255,.12);border:1px solid rgba(139,108,255,.28);color:#d9d0ff;font-weight:700;font-size:13.5px;cursor:pointer}',
    '.kr-serit>button small{color:var(--kr-soluk);font-weight:600;font-size:11.5px}',
    /* gönderi */
    '.kr-g{display:block;position:relative;padding:12px 16px 4px;border-bottom:1px solid var(--kr-cizgi);cursor:pointer;transition:background .15s}',
    '.kr-g:active{background:rgba(255,255,255,.025)}',
    '.kr-g-ic{display:flex;gap:11px}.kr-g-g{flex:1;min-width:0}',
    '.kr-ustnot{display:flex;align-items:center;gap:7px;margin:0 0 4px 30px;color:var(--kr-soluk);font-size:13px;font-weight:600}.kr-ustnot svg{width:15px;height:15px;flex:none}.kr-ustnot b{cursor:pointer;color:var(--txt2)}',
    '.kr-bas{display:flex;align-items:center;gap:5px;min-width:0;line-height:1.25}',
    '.kr-ad{font-weight:800;font-size:15.5px;color:#fff;cursor:pointer;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.kr-sure{color:var(--kr-soluk);font-size:14px;white-space:nowrap;flex:none}.kr-sure::before{content:"·";margin:0 4px 0 1px}',
    '.kr-dm{margin-left:auto;flex:none;width:30px;height:26px;margin-right:-6px;border-radius:999px;display:grid;place-items:center;color:var(--kr-soluk);background:none;border:0;cursor:pointer}.kr-dm svg{width:18px;height:18px}',
    '.kr-nisan{flex:none;display:inline-grid;width:17px;height:17px;color:var(--kr-mor)}.kr-nisan svg{width:17px;height:17px}.kr-nisan.altin{color:#f2c14e}',
    '.kr-unvan{display:flex;align-items:center;flex-wrap:wrap;gap:0;color:var(--kr-soluk);font-size:12.8px;margin-top:1px;line-height:1.35}',
    '.kr-unvan i{width:3px;height:3px;border-radius:50%;background:currentColor;opacity:.6;margin:0 7px}',
    '.kr-pnok{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:5px;flex:none}.kr-pnok.buyuk{width:14px;height:14px;margin-right:8px}',
    '.kr-yanitnot{color:var(--kr-soluk);font-size:14px;margin-top:3px}.kr-yanitnot span{color:var(--kr-mavi);cursor:pointer}',
    '.kr-metin{margin-top:4px;font-size:15.5px;line-height:1.45;white-space:pre-wrap;word-wrap:break-word;overflow-wrap:anywhere;color:var(--txt)}',
    '.kr-et,.kr-an{color:#b9a8ff;cursor:pointer;font-weight:600}.kr-an{color:var(--kr-mavi)}',
    '.kr-alinti{margin-top:10px;border:1px solid var(--kr-cizgi);border-radius:16px;padding:10px 12px;cursor:pointer;background:rgba(255,255,255,.015)}',
    '.kr-al-bas{display:flex;align-items:center;gap:6px;font-size:14px}.kr-al-bas .portre{border-radius:50%}.kr-al-bas b{color:#fff}.kr-al-bas .kr-nisan,.kr-al-bas .kr-nisan svg{width:15px;height:15px}',
    '.kr-al-metin{margin-top:4px;font-size:14.5px;line-height:1.4;display:-webkit-box;-webkit-line-clamp:5;-webkit-box-orient:vertical;overflow:hidden;white-space:pre-wrap;overflow-wrap:anywhere}',
    /* eylemler */
    '.kr-eylem{display:flex;justify-content:space-between;max-width:440px;margin:6px 0 0 -8px}',
    '.kr-e{display:inline-flex;align-items:center;gap:2px;min-width:0;height:38px;padding:0 6px 0 0;background:none;border:0;color:var(--kr-soluk);font-size:13px!important;font-weight:600!important;cursor:pointer;font-variant-numeric:tabular-nums}',
    '.kr-ei{position:relative;width:34px;height:34px;display:grid;place-items:center;border-radius:50%;transition:background .15s,color .15s}',
    '.kr-ei svg{width:19px;height:19px}',
    '.kr-es{min-width:12px;transition:color .15s}',
    '.kr-e-yanit:active .kr-ei{background:rgba(76,195,255,.14);color:var(--kr-mavi)}',
    '.kr-e-yp.on,.kr-e-yp:active .kr-ei{color:var(--kr-yesil)}.kr-e-yp:active .kr-ei{background:rgba(34,211,154,.14)}',
    '.kr-e-begen.on{color:var(--kr-pembe)}.kr-e-begen:active .kr-ei{background:rgba(255,79,139,.14);color:var(--kr-pembe)}',
    '.kr-e-begenme.on{color:var(--kr-turuncu)}.kr-e-begenme:active .kr-ei{background:rgba(255,162,76,.14);color:var(--kr-turuncu)}',
    '.kr-e-paylas:active .kr-ei{background:rgba(139,108,255,.14);color:var(--kr-mor)}',
    '@media (hover:hover){.kr-g:hover{background:rgba(255,255,255,.018)}.kr-e-yanit:hover{color:var(--kr-mavi)}.kr-e-yanit:hover .kr-ei{background:rgba(76,195,255,.12)}.kr-e-yp:hover{color:var(--kr-yesil)}.kr-e-yp:hover .kr-ei{background:rgba(34,211,154,.12)}.kr-e-begen:hover{color:var(--kr-pembe)}.kr-e-begen:hover .kr-ei{background:rgba(255,79,139,.12)}.kr-e-begenme:hover{color:var(--kr-turuncu)}.kr-e-begenme:hover .kr-ei{background:rgba(255,162,76,.12)}.kr-e-paylas:hover .kr-ei{background:rgba(139,108,255,.12);color:var(--kr-mor)}}',
    '.kr-pat .kr-ei svg{animation:krPat .5s cubic-bezier(.2,1.7,.4,1)}',
    '.kr-e-begen.kr-pat .kr-ei::after,.kr-e-yp.kr-pat .kr-ei::after{content:"";position:absolute;left:50%;top:50%;width:5px;height:5px;margin:-2.5px;border-radius:50%;pointer-events:none;animation:krKivilcim .6s ease-out forwards;box-shadow:0 -17px 0 #ff4f8b,15px -9px 0 #ffb347,15px 9px 0 #8b6cff,0 17px 0 #ff4f8b,-15px 9px 0 #22d39a,-15px -9px 0 #4cc3ff}',
    '.kr-e-yp.kr-pat .kr-ei::after{box-shadow:0 -17px 0 #22d39a,15px -9px 0 #4cc3ff,15px 9px 0 #22d39a,0 17px 0 #8b6cff,-15px 9px 0 #22d39a,-15px -9px 0 #4cc3ff}',
    '.kr-e-begen.kr-pat .kr-ei{animation:krHalo .55s ease-out}',
    '@keyframes krPat{0%{transform:scale(.35)}55%{transform:scale(1.32)}100%{transform:scale(1)}}',
    '@keyframes krKivilcim{0%{transform:scale(.25);opacity:1}70%{opacity:1}100%{transform:scale(1.45);opacity:0}}',
    '@keyframes krHalo{0%{box-shadow:0 0 0 0 rgba(255,79,139,.55)}100%{box-shadow:0 0 0 14px rgba(255,79,139,0)}}',
    '@media (prefers-reduced-motion:reduce){.kr-pat .kr-ei svg,.kr-pat .kr-ei::after,.kr-pat .kr-ei{animation:none!important}}',
    /* odak (konuşmanın ana gönderisi) */
    '.kr-odak{cursor:default;padding:14px 16px 2px}.kr-odak:active{background:none}',
    '.kr-odak-ust{display:flex;gap:11px;align-items:center}.kr-odak-kim{flex:1;min-width:0}',
    '.kr-odak .kr-metin{font-size:18.5px;line-height:1.42;margin-top:12px}',
    '.kr-zaman-tam{color:var(--kr-soluk);font-size:14.5px;padding:14px 0 12px;border-bottom:1px solid var(--kr-cizgi)}',
    '.kr-istat{display:flex;flex-wrap:wrap;gap:4px 16px;padding:12px 0;border-bottom:1px solid var(--kr-cizgi);color:var(--kr-soluk);font-size:14.5px}.kr-istat b{color:#fff;margin-right:4px;font-weight:800}',
    '.kr-odak .kr-eylem{max-width:none;margin:2px -8px 0;padding:2px 0}.kr-odak .kr-ei svg{width:22px;height:22px}.kr-odak .kr-es{display:none}',
    '.kr-vurgu{background:linear-gradient(90deg,rgba(139,108,255,.13),transparent 70%)}',
    '.kr-yanit-cubuk{display:flex;align-items:center;gap:11px;width:100%;padding:10px 16px;border:0;border-bottom:1px solid var(--kr-cizgi);background:none;cursor:text;color:var(--kr-soluk);text-align:left;font-size:15.5px}',
    '.kr-yanit-cubuk>span:nth-child(2){flex:1}.kr-yanit-b{padding:6px 14px;border-radius:999px;background:rgba(139,108,255,.2);color:#d9d0ff;font-weight:800;font-size:13.5px}',
    /* bölüm başlıkları */
    '.kr-bolum{display:flex;align-items:baseline;justify-content:space-between;padding:18px 16px 8px}.kr-bolum h3{font-family:var(--disp);font-size:21px;font-weight:800;margin:0;color:#fff}.kr-bolum span{color:var(--kr-soluk);font-size:13px}',
    '.kr-bolum-ilk{padding-top:14px}',
    /* boş ve yükleniyor */
    '.kr-bos{padding:44px 28px 36px;text-align:center}.kr-bos b{display:block;font-family:var(--disp);font-size:24px;font-weight:800;color:#fff;line-height:1.15}.kr-bos p{color:var(--kr-soluk);margin:8px auto 18px;max-width:320px;line-height:1.45}',
    '.kr-bos.kucuk{padding:26px 24px}.kr-bos.kucuk b{font-size:19px}.kr-bos.kucuk p{margin-bottom:4px}',
    '.kr-bos-ik{display:flex;justify-content:center;margin-bottom:14px}.kr-bos-ik svg{filter:drop-shadow(0 10px 26px rgba(139,108,255,.45))}',
    '.kr-oneri-liste{text-align:left;margin:0 -28px;border-top:1px solid var(--kr-cizgi)}',
    '.kr-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;min-height:44px;padding:0 22px;border-radius:999px;border:0;background:var(--kr-grad);color:#fff!important;font-weight:800!important;font-size:15px!important;cursor:pointer;box-shadow:0 10px 26px -10px rgba(255,79,139,.6)}',
    '.kr-btn.ikinci{background:none;border:1px solid rgba(164,184,255,.32);box-shadow:none;color:#fff}.kr-btn.kucuk{min-height:34px;padding:0 14px;font-size:13.5px!important}',
    '.kr-btn:disabled{opacity:.55}',
    '.kr-yuk{display:flex;justify-content:center;gap:6px;padding:26px}.kr-yuk span{width:8px;height:8px;border-radius:50%;background:var(--kr-mor);animation:krNokta 1s infinite ease-in-out}.kr-yuk span:nth-child(2){animation-delay:.15s;background:#c45ec6}.kr-yuk span:nth-child(3){animation-delay:.3s;background:var(--kr-pembe)}',
    '@keyframes krNokta{0%,80%,100%{transform:scale(.5);opacity:.4}40%{transform:scale(1);opacity:1}}',
    '.kr-hayal{display:flex;gap:11px;padding:14px 16px;border-bottom:1px solid var(--kr-cizgi)}.kr-hayal>div{flex:1}.kr-hayal span{display:block;border-radius:8px;background:linear-gradient(90deg,rgba(164,184,255,.07),rgba(164,184,255,.14),rgba(164,184,255,.07));background-size:200% 100%;animation:krParilti 1.3s linear infinite}',
    '.kr-hayal .a{width:44px;height:44px;border-radius:50%;flex:none}.kr-hayal .b{width:42%;height:12px}.kr-hayal .c{width:92%;height:11px;margin-top:10px}.kr-hayal .d{width:64%;height:11px;margin-top:7px}',
    '@keyframes krParilti{0%{background-position:200% 0}100%{background-position:-200% 0}}',
    '.kr-daha{display:block;width:100%;padding:16px;background:none;border:0;color:#b9a8ff;font-weight:700;cursor:pointer}',
    '.kr-dip{display:flex;align-items:center;justify-content:center;gap:8px;padding:26px 16px;color:var(--kr-soluk);font-size:13.5px}',
    /* yeni gönderi balonu */
    '.kr-yeni{position:sticky;top:42px;z-index:7;height:0;display:flex;justify-content:center}',
    '.kr-yeni>button{display:inline-flex;align-items:center;gap:8px;height:38px;padding:0 16px 0 12px;border-radius:999px;border:0;background:var(--kr-grad);color:#fff;font-weight:800;font-size:14px;cursor:pointer;box-shadow:0 10px 26px -6px rgba(0,0,0,.6);animation:krBalon .4s cubic-bezier(.2,1.5,.4,1)}',
    '.kr-yeni>button>svg{width:16px;height:16px}.kr-yeni-av{display:flex}.kr-yeni-av .portre{width:22px!important;height:22px!important;border-radius:50%;box-shadow:0 0 0 2px #b45bd6;margin-left:-6px}.kr-yeni-av .portre:first-child{margin-left:0}',
    '@keyframes krBalon{from{transform:translateY(-14px) scale(.8);opacity:0}}',
    /* yazma düğmesi */
    '.kr-fab{position:absolute;right:16px;bottom:calc(var(--safeB) + 84px);z-index:20;width:58px;height:58px;border-radius:50%;border:0;background:var(--kr-grad);color:#fff;display:grid;place-items:center;cursor:pointer;box-shadow:0 14px 30px -8px rgba(255,79,139,.65),0 0 0 1px rgba(255,255,255,.12) inset}',
    '.kr-fab svg{width:25px;height:25px}.kr-fab:active{transform:scale(.93)}',
    /* profil */
    '.kr-kapak{height:132px;overflow:hidden;line-height:0;background:var(--kr-yuzey)}.kr-kapak svg{width:100%;height:100%}',
    '.kr-p-ust{display:flex;align-items:flex-end;justify-content:space-between;padding:0 16px;margin-top:-44px;gap:10px}',
    '.kr-p-av{line-height:0;flex:none}.kr-p-av .portre{width:86px!important;height:86px!important;border-radius:50%;box-shadow:0 0 0 4px var(--bg),0 10px 24px -8px rgba(0,0,0,.6)}',
    '.kr-p-btn{display:flex;gap:8px;align-items:center;padding-bottom:4px}',
    '.kr-yuv{width:40px;height:40px;border-radius:50%;display:grid;place-items:center;background:none;border:1px solid rgba(164,184,255,.32);cursor:pointer;color:#fff}.kr-yuv svg{width:19px;height:19px}',
    '.kr-p-kim{padding:10px 16px 6px;text-align:left}.kr-p-kim h2{display:flex;align-items:center;gap:6px;font-family:var(--disp);font-size:25px;font-weight:800;margin:0;color:#fff;line-height:1.15;word-break:break-word}.kr-p-kim h2 .kr-nisan,.kr-p-kim h2 .kr-nisan svg{width:21px;height:21px}',
    '.kr-p-unvan{color:var(--kr-soluk);font-size:14.5px;margin-top:2px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}',
    '.kr-seni{display:inline-block;padding:2px 7px;border-radius:5px;background:rgba(164,184,255,.13);color:var(--txt2);font-size:11.5px;font-weight:700;margin-left:6px}',
    '.kr-p-unvan .kr-seni{margin-left:0}',
    '.kr-p-bio{margin:10px 0 0;font-size:15.5px;line-height:1.45;white-space:pre-wrap;overflow-wrap:anywhere}.kr-p-bio.bos{color:#b9a8ff;cursor:pointer}',
    '.kr-p-meta{display:flex;flex-wrap:wrap;gap:6px 14px;margin-top:10px;color:var(--kr-soluk);font-size:14px}.kr-p-meta>span{display:inline-flex;align-items:center;gap:5px}.kr-p-meta svg{width:16px;height:16px}',
    '.kr-meta-parti{cursor:pointer;color:var(--txt2)}',
    '.kr-p-say{display:flex;flex-wrap:wrap;gap:4px 18px;margin-top:10px;font-size:14.5px;color:var(--kr-soluk)}.kr-p-say>*{background:none;border:0;padding:0;cursor:pointer;color:var(--kr-soluk)}.kr-p-say>span{cursor:default}.kr-p-say b{color:#fff;font-weight:800;margin-right:3px}',
    '.kr-ortak{display:flex;align-items:center;gap:6px;margin-top:10px;font-size:13px;color:var(--kr-soluk)}.kr-ortak svg{width:15px;height:15px}',
    '.kr-p-sekme{margin-top:8px}',
    /* takip düğmesi */
    '.kr-takip{flex:none;min-height:36px;padding:0 18px;border-radius:999px;border:0;background:#fff;color:#0e1530!important;font-weight:800!important;font-size:14px!important;cursor:pointer;white-space:nowrap}',
    '.kr-takip.kucuk{min-height:32px;padding:0 14px;font-size:13.5px!important}',
    '.kr-takip.on{background:none;border:1px solid rgba(164,184,255,.35);color:#fff!important}.kr-takip .kr-t2{display:none}',
    '@media (hover:hover){.kr-takip.on:hover{border-color:rgba(255,90,95,.6);color:#ff7a7f!important;background:rgba(255,90,95,.08)}.kr-takip.on:hover .kr-t1{display:none}.kr-takip.on:hover .kr-t2{display:inline}}',
    '.kr-takip:disabled{opacity:.6}',
    /* kişi satırı */
    '.kr-kisi{display:flex;gap:11px;align-items:flex-start;padding:12px 16px;border-bottom:1px solid var(--kr-cizgi);cursor:pointer}',
    '.kr-kisi-g{flex:1;min-width:0}.kr-kisi-ad{display:flex;align-items:center;gap:5px}.kr-kisi-ad b{color:#fff;font-weight:800;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.kr-kisi-alt{color:var(--kr-soluk);font-size:13.5px}.kr-kisi-bio{margin-top:4px;font-size:14.5px;line-height:1.4;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}',
    /* keşfet */
    '.kr-ara{display:flex;align-items:center;gap:10px;margin:10px 16px 2px;padding:0 16px;height:44px;border-radius:999px;background:var(--kr-yuzey);border:1px solid var(--kr-cizgi);color:var(--kr-soluk)}',
    '.kr-ara:focus-within{border-color:var(--kr-mor);box-shadow:0 0 0 3px rgba(139,108,255,.2)}.kr-ara svg{width:19px;height:19px;flex:none}',
    '.kr-ara input{flex:1;min-width:0;background:none;border:0;outline:0;color:var(--txt);font-size:16px;padding:0}',
    '.kr-suzgec{display:flex;gap:8px;overflow-x:auto;padding:2px 16px 12px;scrollbar-width:none}.kr-suzgec::-webkit-scrollbar{display:none}',
    '.kr-suzgec button{flex:none;display:inline-flex;gap:6px;align-items:center;height:34px;padding:0 14px;border-radius:999px;border:1px solid rgba(164,184,255,.22);background:none;color:var(--txt2);font-weight:700;font-size:13.5px;cursor:pointer}',
    '.kr-suzgec button small{font-size:11.5px;color:var(--kr-soluk)}.kr-suzgec button.on{background:#fff;color:#0e1530;border-color:#fff}.kr-suzgec button.on small{color:#4a5274}',
    '.kr-zirve{position:relative;overflow:hidden;display:block;width:calc(100% - 32px);margin:0 16px 6px;padding:18px 18px 20px;border-radius:22px;border:0;text-align:left;cursor:pointer;color:#fff;background:radial-gradient(120% 140% at 100% 0%,#ff4f8b 0%,rgba(255,79,139,0) 55%),linear-gradient(135deg,#3d2a9c,#6d4dff 55%,#9a4fd8);box-shadow:0 20px 40px -18px rgba(139,108,255,.7)}',
    '.kr-zirve-ust{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:800;padding:5px 10px;border-radius:999px;background:rgba(0,0,0,.22)}.kr-zirve-ust svg{width:15px;height:15px;color:#ffd166}',
    '.kr-zirve b{display:block;margin-top:12px;font-family:var(--disp);font-size:31px;font-weight:800;line-height:1.08;word-break:break-word;position:relative}',
    '.kr-zirve-alt{display:block;margin-top:6px;font-size:14px;color:rgba(255,255,255,.85);position:relative}',
    '.kr-zirve-dalga{position:absolute;right:-40px;bottom:-60px;width:200px;height:200px;border-radius:50%;border:1px solid rgba(255,255,255,.18);box-shadow:0 0 0 22px rgba(255,255,255,.05),0 0 0 46px rgba(255,255,255,.035),0 0 0 72px rgba(255,255,255,.02);pointer-events:none}',
    '.kr-zirve .kr-tr-kisi .portre{width:30px!important;height:30px!important}',
    '.kr-trend{display:flex;align-items:center;gap:12px;width:100%;padding:12px 16px;background:none;border:0;border-bottom:1px solid var(--kr-cizgi);text-align:left;cursor:pointer}',
    '.kr-tr-sira{flex:none;width:26px;text-align:center;font-family:var(--disp);font-size:20px;font-weight:800;color:rgba(185,168,255,.75);font-variant-numeric:tabular-nums}.kr-tr-diyez{color:#b9a8ff}',
    '.kr-tr-g{flex:1;min-width:0;display:flex;flex-direction:column;gap:1px}.kr-tr-g small{color:var(--kr-soluk);font-size:12.5px}.kr-tr-g b{color:#fff;font-size:16px;font-weight:800;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.kr-tr-kisi{display:inline-flex;align-items:center;gap:7px;min-width:0;max-width:100%}.kr-tr-kisi .portre{width:22px!important;height:22px!important;border-radius:50%;flex:none}',
    '.kr-tr-ik{display:inline-grid;place-items:center;width:22px;height:22px;border-radius:7px;background:rgba(34,211,154,.16);color:var(--kr-yesil);flex:none}.kr-tr-ik svg{width:14px;height:14px}',
    '.kr-tr-bar{display:block;height:3px;border-radius:3px;background:rgba(164,184,255,.09);margin-top:6px;overflow:hidden}.kr-tr-bar i{display:block;height:100%;border-radius:3px;background:var(--kr-grad)}',
    '.kr-tr-ok{flex:none;color:var(--kr-soluk);opacity:.6}.kr-tr-ok svg{width:16px;height:16px}',
    '.kr-oneri-kayan{display:flex;gap:10px;overflow-x:auto;padding:4px 16px 18px;scrollbar-width:none;scroll-snap-type:x mandatory}.kr-oneri-kayan::-webkit-scrollbar{display:none}',
    '.kr-okart{flex:none;width:150px;scroll-snap-align:start;display:flex;flex-direction:column;align-items:center;text-align:center;gap:3px;padding:16px 10px 12px;border-radius:18px;background:var(--kr-yuzey);border:1px solid var(--kr-cizgi);cursor:pointer}',
    '.kr-okart .kr-av{margin-bottom:6px}.kr-okart b{display:flex;align-items:center;gap:4px;max-width:100%;color:#fff;font-size:14.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.kr-okart small{color:var(--kr-soluk);font-size:12px;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.kr-okart-say{font-size:12px;color:var(--txt2);margin:2px 0 8px}',
    /* etiket */
    '.kr-et-bas{display:flex;align-items:center;gap:12px;padding:16px;border-bottom:1px solid var(--kr-cizgi);background:linear-gradient(180deg,rgba(139,108,255,.14),transparent)}',
    '.kr-et-diyez{flex:none;width:50px;height:50px;border-radius:16px;display:grid;place-items:center;background:var(--kr-grad);font:800 28px/1 var(--disp);color:#fff;box-shadow:0 10px 24px -10px rgba(255,79,139,.6)}',
    '.kr-et-bas>div{flex:1;min-width:0}.kr-et-bas h2{margin:0;font-family:var(--disp);font-size:23px;font-weight:800;color:#fff;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.kr-et-bas span{color:var(--kr-soluk);font-size:13.5px}',
    /* bildirimler */
    '.kr-bil{display:flex;gap:12px;padding:12px 16px 10px;border-bottom:1px solid var(--kr-cizgi);cursor:pointer}',
    '.kr-bil.yeni{background:linear-gradient(90deg,rgba(139,108,255,.1),transparent 80%)}',
    '.kr-bil-ik{flex:none;width:32px;display:flex;justify-content:flex-end;padding-top:2px}.kr-bil-ik svg{width:24px;height:24px}',
    '.kr-bil-ik.mor{color:var(--kr-mor)}.kr-bil-ik.yesil{color:var(--kr-yesil)}.kr-bil-ik.mavi{color:var(--kr-mavi)}.kr-bil-ik.turuncu{color:var(--kr-turuncu)}.kr-bil-ik.pembe{color:var(--kr-pembe)}',
    '.kr-bil-g{flex:1;min-width:0}.kr-bil-ust{display:flex;align-items:center;gap:6px}.kr-bil-ust .kr-sure::before{content:none}.kr-bil-ust .kr-sure{margin-left:auto;font-size:13px}',
    '.kr-bil-g p{margin:6px 0 0;font-size:15px;line-height:1.4}.kr-bil-g p b{color:#fff}',
    '.kr-bil-ozet{margin-top:4px;color:var(--kr-soluk);font-size:14.5px;line-height:1.4;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}',
    '.kr-bil-metin{margin-top:6px;font-size:15px;line-height:1.42;white-space:pre-wrap;overflow-wrap:anywhere}',
    '.kr-bil .kr-takip{margin-top:10px}',
    '.kr-bil.kr-g{padding:12px 16px 2px}',
    /* sayfa (alt menü) */
    '.modal.kr-modal{padding-bottom:calc(var(--safeB) + 10px)}',
    '.kr-sayfa{display:flex;flex-direction:column;gap:2px;margin-top:4px}',
    '.kr-sf{display:flex;align-items:center;gap:14px;width:100%;padding:13px 6px;border:0;background:none;color:#fff;text-align:left;font-size:16px!important;font-weight:700!important;cursor:pointer;border-radius:12px}',
    '.kr-sf:active{background:rgba(255,255,255,.05)}.kr-sf svg{width:22px;height:22px;flex:none;color:var(--txt2)}.kr-sf small{display:block;color:var(--kr-soluk);font-size:13px;font-weight:500;margin-top:1px}',
    '.kr-sf.tehlike,.kr-sf.tehlike svg{color:#ff7a7f}.kr-sf.iptal{justify-content:center;margin-top:8px;border:1px solid rgba(164,184,255,.25);border-radius:999px}',
    /* profil düzenle */
    '.kr-duz h3{font-family:var(--disp);font-size:22px;font-weight:800;margin:0 0 12px}',
    '.kr-duz-kapak{position:relative;height:110px;border-radius:16px;overflow:visible;margin-bottom:34px;line-height:0}.kr-duz-kapak>svg{width:100%;height:100%;border-radius:16px}',
    '.kr-duz-av{position:absolute;left:14px;bottom:-28px;line-height:0}.kr-duz-av .portre{width:64px!important;height:64px!important;border-radius:50%;box-shadow:0 0 0 3px var(--panel)}',
    '.kr-duz-et{display:block;font-size:13px;font-weight:700;color:var(--txt2);margin:12px 0 8px}',
    '.kr-renkler{display:flex;flex-wrap:wrap;gap:9px}.kr-renkler button{width:36px;height:36px;border-radius:50%;border:0;cursor:pointer;box-shadow:inset 0 0 0 1px rgba(255,255,255,.15)}.kr-renkler button.on{box-shadow:0 0 0 2px var(--panel),0 0 0 4px #fff}',
    '.kr-bio-kap{position:relative}.kr-bio-kap textarea{width:100%;box-sizing:border-box;min-height:84px;padding:12px 12px 22px;border-radius:14px;background:var(--bg);border:1px solid var(--kr-cizgi);color:var(--txt);font:inherit;font-size:15.5px;resize:none}',
    '.kr-bio-kap span{position:absolute;right:12px;bottom:8px;font-size:12px;color:var(--kr-soluk)}.kr-bio-kap span.az{color:var(--kr-turuncu)}',
    '.kr-duz-not{font-size:12.5px;color:var(--kr-soluk);margin:6px 0 14px}.kr-duz .kr-btn{width:100%;margin-top:8px}',
    /* yazma penceresi */
    '.kr-yaz-arka{position:fixed;inset:0;z-index:80;background:rgba(5,8,22,.6);display:flex;align-items:flex-end;justify-content:center;animation:krSol .2s ease-out}',
    '.kr-yaz{width:100%;max-width:620px;height:100%;max-height:100%;display:flex;flex-direction:column;background:var(--bg);animation:krYukari .28s cubic-bezier(.2,.9,.3,1)}',
    '@media (min-width:700px){.kr-yaz-arka{align-items:flex-start;padding-top:6vh}.kr-yaz{height:auto;max-height:80vh;border-radius:22px;border:1px solid var(--kr-cizgi)}}',
    '@keyframes krSol{from{opacity:0}}@keyframes krYukari{from{transform:translateY(40px);opacity:0}}',
    '.kr-yaz-ust{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:calc(var(--safeT) + 10px) 14px 10px}',
    '.kr-yaz-iptal{background:none;border:0;color:var(--txt);font-size:16px;cursor:pointer;padding:8px 4px}',
    '.kr-yaz-tur{font-weight:800;color:var(--kr-soluk);font-size:14px}',
    '.kr-yaz-gonder{min-height:38px;padding:0 20px;border-radius:999px;border:0;background:var(--kr-grad);color:#fff;font-weight:800;font-size:15px;cursor:pointer;box-shadow:0 8px 20px -8px rgba(255,79,139,.7)}',
    '.kr-yaz-gonder:disabled{opacity:.45;box-shadow:none}',
    '.kr-yaz-govde{flex:1;overflow-y:auto;padding:4px 16px 12px}',
    '.kr-yaz-baglam{display:flex;gap:11px;position:relative;padding-bottom:14px}',
    '.kr-yaz-baglam::before{content:"";position:absolute;left:19px;top:46px;bottom:2px;width:2px;background:rgba(164,184,255,.2);border-radius:2px}',
    '.kr-yaz-baglam>div{flex:1;min-width:0}.kr-yaz-baglam .kr-metin{font-size:15px;color:var(--txt2);display:-webkit-box;-webkit-line-clamp:4;-webkit-box-orient:vertical;overflow:hidden}',
    '.kr-yaz-satir{display:flex;gap:11px}',
    '.kr-yaz-satir textarea{flex:1;min-width:0;min-height:120px;background:none;border:0;outline:0;resize:none;color:var(--txt);font:inherit;font-size:19px;line-height:1.4;padding:8px 0}',
    '.kr-yaz-satir textarea::placeholder{color:#6f7ba0}',
    '.kr-yaz-satir textarea,.kr-yaz-satir textarea:focus{border:0!important;box-shadow:none!important;outline:0!important;background:none!important;border-radius:0!important}',
    '.kr-istat>span{white-space:nowrap}',
    '.kr-yaz-alinti{margin-left:51px}',
    '.kr-yaz-alt{display:flex;align-items:center;gap:10px;padding:10px 16px calc(var(--safeB) + 6px);border-top:1px solid var(--kr-cizgi)}',
    '.kr-yaz-et{flex:1;min-width:0;display:flex;gap:6px;overflow-x:auto;scrollbar-width:none}.kr-yaz-et::-webkit-scrollbar{display:none}',
    '.kr-yaz-et button{flex:none;height:32px;padding:0 12px;border-radius:999px;border:1px solid rgba(139,108,255,.35);background:rgba(139,108,255,.1);color:#d9d0ff;font-weight:700;font-size:13px;cursor:pointer}',
    '.kr-yaz-ipucu{flex:1;color:var(--kr-soluk);font-size:13px}',
    '.kr-halka{position:relative;flex:none;width:30px;height:30px;display:grid;place-items:center}.kr-halka svg{position:absolute;inset:0;width:30px;height:30px;transform:rotate(-90deg)}',
    '.kr-halka .z{fill:none;stroke:rgba(164,184,255,.18);stroke-width:2.4}.kr-halka .d{fill:none;stroke:var(--kr-mor);stroke-width:2.4;stroke-linecap:round;transition:stroke-dashoffset .15s}',
    '.kr-halka.az .d{stroke:var(--kr-turuncu)}.kr-halka.bos .d{stroke:transparent}.kr-halka b{position:relative;font-size:11px;font-weight:800;color:var(--kr-turuncu)}',
    /* Gündem önizlemesi */
    '.so-canli-akis .kr-gb{display:inline-flex;align-items:center;gap:9px}.so-canli-akis .kr-gb .kr-logo{filter:drop-shadow(0 4px 10px rgba(139,108,255,.4))}',
    '.kr-gb-c{display:inline-flex;align-items:center;gap:5px;font:800 10.5px/1 system-ui;color:#ff6f9f;padding:4px 7px;border-radius:999px;background:rgba(255,79,139,.13);letter-spacing:.2px}.kr-gb-c::before{content:"";width:6px;height:6px;border-radius:50%;background:#ff4f8b;animation:krNabiz 1.6s infinite}',
    '@keyframes krNabiz{0%{box-shadow:0 0 0 0 rgba(255,79,139,.6)}70%{box-shadow:0 0 0 7px rgba(255,79,139,0)}100%{box-shadow:0 0 0 0 rgba(255,79,139,0)}}',
    '.kr-gb-git{color:#b9a8ff!important;font-weight:800!important}',
    '.akis-kart .kr-g,.kart .kr-g.kr-uyum{padding:12px 0 2px;cursor:default;background:none}.akis-kart .kr-g:last-child{border-bottom:0}',
    '.kr-uyum .kr-metin{cursor:pointer}',
    '.kr-av-bos{display:block;border-radius:50%;background:var(--panel2)}',
    '@media (max-width:350px){.kr-sekmeler>button{padding:0 10px;font-size:13.5px!important}.kr-e{padding-right:2px}.kr-ei{width:30px}.kr-p-btn{gap:6px}.kr-takip{padding:0 14px}.kr-zirve b{font-size:26px}.kr-okart{width:136px}.kr-p-av .portre{width:72px!important;height:72px!important}.kr-p-ust{margin-top:-38px;gap:8px}.kr-yuv{width:36px;height:36px}.kr-p-btn .kr-takip{padding:0 13px;font-size:13.5px!important}}'
  ].join('\n');
  document.head.appendChild(st);
})();
