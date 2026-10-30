/* =====================================================================
   MAKAM KİMLİĞİ VE PROTOKOL (30.10.2026)
   • Cumhurbaşkanlığı, Meclis, Bakanlık ve Belediye ekranlarına kurum künyesi
     (mühür, kurum adı, canlı göstergeler) ve resmî görünüm.
   • Makam ajandası: tören, ziyaret, kabul, diplomasi ve nişan/berat programları
     (sunucu: 146_makam_protokol.sql → resmi_program_panel / _yap / _katil).
   • Protokol akışı: herkes açık törenleri görür ve katılır (kıdem kazanır).
   • Oyuncu kartında devlet nişanları ve beratlar.
   Para ve etkiler yalnız sunucuda işlenir; bu dosya arayüzdür.
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_MAKAM_KURUMSAL_V1) return;
  window.SO_MAKAM_KURUMSAL_V1 = true;

  /* ---------------- yardımcılar ---------------- */
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var sayi = function (n, d) { return Number(n || 0).toLocaleString('tr-TR', { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 }); };
  var $q = function (s, k) { return (k || document).querySelector(s); };
  var TZ = 'Europe/Istanbul';
  var TRH = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, day: 'numeric', month: 'long', year: 'numeric' });
  var SAAT = new Intl.DateTimeFormat('tr-TR', { timeZone: TZ, day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  var trh = function (t) { try { return TRH.format(new Date(t)); } catch (_) { return ''; } };
  var saatYaz = function (t) { try { return SAAT.format(new Date(t)); } catch (_) { return ''; } };
  var simdiMs = function () { try { return typeof simdi === 'function' ? simdi() : Date.now(); } catch (_) { return Date.now(); } };
  var kalanYaz = function (t) {
    var ms = new Date(t).getTime() - simdiMs(); if (ms <= 0) return 'şimdi';
    var dk = Math.round(ms / 6e4); if (dk < 60) return dk + ' dk';
    var sa = Math.floor(dk / 60); if (sa < 48) return sa + ' sa ' + (dk % 60 ? (dk % 60) + ' dk' : '');
    return Math.round(sa / 24) + ' gün';
  };
  var hataYaz = function (err) { var m = (err && err.message) || String(err || ''); try { return typeof hataCevir === 'function' ? hataCevir(m) : m; } catch (_) { return m; } };
  var tst = function (m, k) { try { toast(m, k); } catch (_) {} };
  var portreYap = function (kad, renk, boy) { try { return portre(kad, renk, boy); } catch (_) { return '<span class="dk-bas" style="width:' + boy + 'px;height:' + boy + 'px">' + esc(String(kad || '?').slice(0, 2).toLocaleUpperCase('tr-TR')) + '</span>'; } };
  var tazele = function (k) { try { if (typeof portreleriTazele === 'function') portreleriTazele(k); } catch (_) {} };
  var hafif = function () { try { HAPTIK.hafif(); } catch (_) {} };

  /* ---------------- simgeler ---------------- */
  var sv = function (p) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>'; };
  var MUHUR = '<svg viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="22" fill="none" stroke="currentColor" stroke-width="1.3" opacity=".6"/><circle cx="24" cy="24" r="18.6" fill="none" stroke="currentColor" stroke-width=".8" stroke-dasharray="1.1 2.1" opacity=".7"/>' +
    '<path d="M24 11.5l1.4 2.9 3.2.5-2.3 2.2.5 3.2-2.8-1.5-2.8 1.5.5-3.2-2.3-2.2 3.2-.5z" fill="currentColor"/><path d="M14 34.5h20M16 34.5v-9M32 34.5v-9M21.3 34.5v-9M26.7 34.5v-9M13.5 25.5L24 20l10.5 5.5z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/></svg>';
  var KAT_IK = {
    'Tören': sv('<path d="M4 21h16M6 21v-9M18 21v-9M10 21v-9M14 21v-9M3 12l9-6 9 6z"/>'),
    'Ziyaret': sv('<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.4"/>'),
    'Diplomasi': sv('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.6 2.6 3.9 5.6 3.9 9s-1.3 6.4-3.9 9c-2.6-2.6-3.9-5.6-3.9-9S9.4 5.6 12 3z"/>'),
    'Kabul': sv('<path d="M8 12l3 3 5-6"/><path d="M4 7.5V5a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-2.5"/>'),
    'Nişan': sv('<path d="M8.5 2.5l3.5 6 3.5-6M7 2.5h3l2 3.5 2-3.5h3"/><circle cx="12" cy="15" r="6"/><path d="M12 11.6l1 2 2.2.3-1.6 1.5.4 2.2-2-1-2 1 .4-2.2-1.6-1.5 2.2-.3z" fill="currentColor" stroke="none"/>'),
    'Program': sv('<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4M8 14h3M8 17h6"/>'),
    'Hizmet': sv('<path d="M14.5 3.5l6 6-2 2-6-6zM12.5 5.5L4 14l2 2 1-1 1 1 1-1 1 1 1-1 1 1 6.5-6.5"/><path d="M4 20h7"/>')
  };
  var ik = function (kat) { return KAT_IK[kat] || KAT_IK.Program; };
  var MAKAM_AD = { cb: 'Cumhurbaşkanlığı', bakan: 'Bakanlık', tbmm: 'TBMM Başkanlığı', mv: 'Milletvekilliği', bel: 'Belediye Başkanlığı' };
  var ETKI_AD = { buyume: 'Büyüme', enflasyon: 'Enflasyon', issizlik: 'İşsizlik', memnuniyet: 'Ülke memnuniyeti', gelisim: 'İl gelişimi', hazine: 'Hazine' };

  /* ---------------- veri ---------------- */
  var PANEL = { v: null, t: 0 };
  async function panelAl(zorla) {
    if (!zorla && PANEL.v && simdiMs() - PANEL.t < 15e3) return PANEL.v;
    PANEL.v = await API.rpc('resmi_program_panel'); PANEL.t = simdiMs(); return PANEL.v;
  }

  /* ---------------- kurum künyesi ---------------- */
  function kunye(o) {
    var kpi = (o.kpi || []).map(function (k) {
      return '<div class="dk-kpi"><small>' + esc(k[0]) + '</small><b' + (k[2] ? ' class="' + k[2] + '"' : '') + '>' + k[1] + '</b></div>';
    }).join('');
    return '<section class="dk-kunye" data-dk="kunye"><div class="dk-kunye-ust"><span class="dk-muhur">' + MUHUR + '</span><div class="dk-kunye-ad">' +
      '<small>' + esc(o.ust || 'Türkiye Cumhuriyeti') + '</small><b>' + esc(o.ad) + '</b>' + (o.alt ? '<span>' + o.alt + '</span>' : '') + '</div></div>' +
      (kpi ? '<div class="dk-kpiler">' + kpi + '</div>' : '') + (o.eylem || '') + '</section>';
  }
  var yuz = function (x, d) { return '%' + sayi(x, d == null ? 1 : d); };

  /* ---------------- makam ajandası ---------------- */
  function etkiCipler(pr) {
    var c = [];
    Object.keys(pr.etki || {}).forEach(function (k) { var v = Number(pr.etki[k]); c.push('<span class="dk-cip ' + ((k === 'enflasyon' || k === 'issizlik') ? (v < 0 ? 'iyi' : 'kotu') : (v > 0 ? 'iyi' : 'kotu')) + '">' + esc(ETKI_AD[k] || k) + ' ' + (v > 0 ? '+' : '') + sayi(v, 2) + '</span>'); });
    Object.keys(pr.il_etki || {}).forEach(function (k) { var v = Number(pr.il_etki[k]); c.push('<span class="dk-cip iyi">' + (k === 'gelisim' ? 'İl gelişimi' : 'İl memnuniyeti') + ' +' + sayi(v, 1) + '</span>'); });
    if (pr.kidem_hedef > 0) c.push('<span class="dk-cip altin">Alana +' + sayi(pr.kidem_hedef, 1) + ' kıdem</span>');
    if (pr.katilim_saat > 0) c.push('<span class="dk-cip">' + pr.katilim_saat + ' saat katılıma açık' + (pr.kidem_katilim > 0 ? ' · katılana +' + sayi(pr.kidem_katilim, 2) + ' kıdem' : '') + '</span>');
    return c.join('');
  }
  function maliyetYaz(pr) {
    if (!pr.maliyet || pr.kaynak === 'yok') return 'Bütçe gerektirmez';
    var kay = { hazine: 'Hazine', bakanlik: 'bakanlık kasası', belediye: 'belediye kasası' }[pr.kaynak] || '';
    return sayi(pr.maliyet, pr.maliyet < 1 ? 3 : 1) + ' milyar ₺ · ' + kay;
  }
  function programKart(m, pr) {
    var hazir = !pr.hazir || new Date(pr.hazir).getTime() <= simdiMs();
    var para = pr.kaynak === 'yok' || !pr.maliyet || m.kasa == null || Number(m.kasa) >= Number(pr.maliyet);
    return '<button type="button" class="dk-prog' + (hazir ? '' : ' bekle') + '" data-dk-prog="' + esc(pr.kod) + '" data-dk-makam="' + esc(m.makam) + '">' +
      '<span class="dk-prog-ik k-' + esc(pr.kategori) + '">' + ik(pr.kategori) + '</span>' +
      '<span class="dk-prog-g"><small>' + esc(pr.kategori) + '</small><b>' + esc(pr.ad) + '</b><em>' + esc(pr.aciklama) + '</em>' +
      '<span class="dk-prog-alt"><span>' + esc(maliyetYaz(pr)) + '</span>' +
      (hazir ? (para ? '<i class="ok">Düzenlenebilir</i>' : '<i class="kotu">Kasa yetersiz</i>') : '<i>' + esc(kalanYaz(pr.hazir)) + ' sonra</i>') + '</span></span></button>';
  }
  function ajandaHtml(v, makamlar) {
    var ls = (v && v.makamlar || []).filter(function (m) { return !makamlar || makamlar.indexOf(m.makam) >= 0; });
    if (!ls.length) return '';
    return ls.map(function (m) {
      var gruplar = {};
      (m.programlar || []).forEach(function (p) { (gruplar[p.kategori] = gruplar[p.kategori] || []).push(p); });
      return '<section class="dk-ajanda" data-dk="ajanda"><header class="dk-bolum"><span class="dk-muhur kucuk">' + MUHUR + '</span><div><small>' + esc(MAKAM_AD[m.makam] || '') + ' · makam ajandası</small><b>' + esc(m.unvan || '') + '</b></div>' +
        (m.kasa != null ? '<span class="dk-kasa"><small>' + (m.makam === 'cb' ? 'Hazine' : 'Kasa') + '</small>' + sayi(m.kasa, m.makam === 'bel' ? 3 : 1) + ' milyar ₺</span>' : '') + '</header>' +
        '<p class="dk-not">Tören, ziyaret, kabul ve nişan programları kayda geçer; Resmî Gazete ve protokol akışında yayımlanır. Açık törenlere oyuncular katılıp kıdem kazanır.</p>' +
        Object.keys(gruplar).map(function (g) { return '<div class="dk-grup"><h4>' + esc(g) + '</h4><div class="dk-proglar">' + gruplar[g].map(function (p) { return programKart(m, p); }).join('') + '</div></div>'; }).join('') +
        '</section>';
    }).join('');
  }

  /* ---------------- protokol akışı ---------------- */
  function akisSatir(x, ben) {
    var acik = x.acik && !x.benim;
    var yerel = x.il_id == null || (ben && ben.il_id === x.il_id) || (ben && ben.il && ben.il.id === x.il_id);
    return '<div class="dk-akis-s' + (x.acik ? ' canli' : '') + '"><span class="dk-akis-ik k-' + esc(x.kategori) + '">' + ik(x.kategori) + '</span>' +
      '<div class="dk-akis-g"><b>' + esc(x.ad) + (x.il ? ' <span>· ' + esc(x.il) + '</span>' : '') + '</b>' +
      '<small>' + esc(x.unvan || '') + ' ' + '<a class="bag" href="#" onclick="oyuncuKart(\'' + esc(x.kad) + '\');return false">' + esc(x.kad) + '</a>' +
      (x.hedef ? ' → <a class="bag" href="#" onclick="oyuncuKart(\'' + esc(x.hedef) + '\');return false">' + esc(x.hedef) + '</a>' : '') + '</small>' +
      (x.metin ? '<q>' + esc(x.metin) + '</q>' : '') +
      '<span class="dk-akis-alt">' + esc(saatYaz(x.zaman)) + (x.katilimci ? ' · ' + x.katilimci + ' katılımcı' : '') + (x.acik ? ' · <i>katılım ' + esc(kalanYaz(x.katilim_bit)) + ' daha açık</i>' : '') + '</span></div>' +
      (acik ? (x.katildim ? '<span class="dk-katildi">Katıldın</span>' : (yerel ? '<button type="button" class="dk-katil" data-dk-katil="' + Number(x.id) + '">Katıl</button>' : '')) : '') + '</div>';
  }
  function protokolHtml(v, sinir) {
    if (!v) return '';
    var ben = (typeof D !== 'undefined' && D.durum && D.durum.profil) || null;
    var acik = v.acik || [], akis = (v.akis || []).filter(function (x) { return !x.acik; }).slice(0, sinir || 6);
    if (!acik.length && !akis.length) return '<section class="dk-protokol" data-dk="protokol"><header class="dk-bolum"><span class="dk-muhur kucuk">' + MUHUR + '</span><div><small>Devlet protokolü</small><b>Resmî program akışı</b></div></header><p class="dk-not">Henüz resmî program düzenlenmedi. Makam sahipleri tören, ziyaret ve kabul düzenledikçe burada yayımlanır.</p></section>';
    return '<section class="dk-protokol" data-dk="protokol"><header class="dk-bolum"><span class="dk-muhur kucuk">' + MUHUR + '</span><div><small>Devlet protokolü</small><b>Resmî program akışı</b></div>' +
      (acik.length ? '<span class="dk-canli"><i></i>' + acik.length + ' açık tören</span>' : '') + '</header>' +
      (acik.length ? '<div class="dk-akis acik">' + acik.map(function (x) { return akisSatir(x, ben); }).join('') + '</div>' : '') +
      (akis.length ? '<div class="dk-akis">' + akis.map(function (x) { return akisSatir(x, ben); }).join('') + '</div>' : '') +
      '<button type="button" class="dk-tum" data-dk-tum="1">Tüm resmî programlar</button></section>';
  }

  /* ---------------- program formu ---------------- */
  function bulProg(kod, makam) {
    var m = (PANEL.v && PANEL.v.makamlar || []).find(function (x) { return x.makam === makam; });
    return m ? { m: m, p: (m.programlar || []).find(function (x) { return x.kod === kod; }) } : null;
  }
  function beratOnizle(p, m, hedef, gerekce) {
    var ben = (D.durum && D.durum.profil && D.durum.profil.kad) || '';
    return '<div class="dk-berat"><div class="dk-berat-ic"><span class="dk-muhur">' + MUHUR + '</span><small>Türkiye Cumhuriyeti · ' + esc(MAKAM_AD[m.makam] || '') + '</small>' +
      '<h3>' + esc(p.nisan) + '</h3><p class="dk-berat-kime">' + (hedef ? esc(hedef) : '<i>Alıcıyı seçin</i>') + '</p>' +
      '<p class="dk-berat-g">' + (gerekce ? esc(gerekce) : '<i>Gerekçe bu satıra yazılacak</i>') + '</p>' +
      '<div class="dk-berat-alt"><span>' + esc(trh(simdiMs())) + '</span><span class="dk-imza"><b>' + esc(ben) + '</b><small>' + esc(m.unvan || '') + '</small></span></div></div></div>';
  }
  function formAc(kod, makam) {
    var b = bulProg(kod, makam); if (!b || !b.p) return;
    var p = b.p, m = b.m, sec = { hedef: '' };
    var hazir = !p.hazir || new Date(p.hazir).getTime() <= simdiMs();
    var iller = (typeof VERI !== 'undefined' && VERI.iller ? VERI.iller.slice() : []).sort(function (a, c) { return a.ad.localeCompare(c.ad, 'tr'); });
    var h = '<div class="dk-form"><div class="dk-form-bas"><span class="dk-prog-ik k-' + esc(p.kategori) + '">' + ik(p.kategori) + '</span><div><small>' + esc(m.unvan) + ' · ' + esc(p.kategori) + '</small><h3>' + esc(p.ad) + '</h3></div></div>' +
      '<p class="dk-form-acik">' + esc(p.aciklama) + '</p><div class="dk-cipler">' + etkiCipler(p) + '<span class="dk-cip">' + esc(maliyetYaz(p)) + '</span><span class="dk-cip">' + Math.round(p.bekleme_saat) + ' saatte bir</span></div>';
    if (p.il_mod === 'sec') h += '<div class="alan"><label>Program hangi ilde?</label><select id="dkIl">' + iller.map(function (i) { return '<option value="' + i.id + '">' + esc(i.ad) + '</option>'; }).join('') + '</select></div>';
    else if (p.il_mod === 'kendi' && m.il) h += '<p class="dk-yer">' + sv('<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.4"/>') + esc(m.il) + '</p>';
    if (p.hedef) h += '<div class="alan"><label>' + (p.nisan ? 'Kime verilecek?' : 'Kimi kabul edeceksin?') + '</label><input id="dkAra" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="Oyuncu adıyla ara"></div><div id="dkSonuc" class="dk-sonuc"></div>';
    if (p.secenekler) h += '<div class="alan"><label>' + (p.kategori === 'Diplomasi' ? 'Hangi ülke?' : 'Seçim') + '</label><select id="dkSec">' + p.secenekler.map(function (s) { return '<option>' + esc(s) + '</option>'; }).join('') + '</select></div>';
    else h += '<div class="alan"><label>' + esc(p.metin_ipucu || 'Not') + (p.nisan ? '' : ' <span class="kucuk">(isteğe bağlı)</span>') + '</label><textarea id="dkMetin" rows="2" maxlength="280" placeholder="' + esc(p.metin_ipucu || '') + '"></textarea></div>';
    if (p.nisan) h += '<div id="dkBerat">' + beratOnizle(p, m, '', '') + '</div>';
    h += '<button class="btn altin dk-onay" id="dkOnay"' + (hazir ? '' : ' disabled') + '>' + (hazir ? (p.nisan ? 'Beratı imzala ve tevcih et' : 'Programı onayla') : 'Yeniden düzenlenebilir: ' + esc(saatYaz(p.hazir))) + '</button></div>';
    var md = modal(h);
    var ara = $q('#dkAra', md), sonuc = $q('#dkSonuc', md), mt = $q('#dkMetin', md), zz = null;
    var beratYenile = function () { var bb = $q('#dkBerat', md); if (bb) bb.innerHTML = beratOnizle(p, m, sec.hedef, mt ? mt.value.trim() : ''); };
    if (mt) mt.addEventListener('input', beratYenile);
    if (ara) {
      var bul = async function () {
        var q = ara.value.trim(); if (q.length < 2) { sonuc.innerHTML = ''; return; }
        try {
          var r = await API.rpc('oyuncu_arama', { p_aranan: q, p_il: null, p_parti: null, p_limit: 8, p_offset: 0 });
          var l = (r && r.oyuncular) || [];
          sonuc.innerHTML = l.map(function (k) { return '<button type="button" class="dk-aday' + (k.kad === sec.hedef ? ' sec' : '') + '" data-kad="' + esc(k.kad) + '"><span class="dk-aday-p">' + portreYap(k.kad, k.parti && k.parti.renk, 34) + '</span><span><b>' + esc(k.kad) + '</b><small>' + esc([k.il_ad || k.il, k.parti ? k.parti.kisa : 'Bağımsız', k.unvan].filter(Boolean).join(' · ')) + '</small></span></button>'; }).join('') || '<div class="kucuk">Eşleşen oyuncu yok.</div>';
          tazele(sonuc);
        } catch (err) { sonuc.innerHTML = '<div class="kucuk">' + esc(hataYaz(err)) + '</div>'; }
      };
      ara.addEventListener('input', function () { clearTimeout(zz); zz = setTimeout(bul, 250); });
      sonuc.addEventListener('click', function (ev) {
        var s = ev.target.closest('[data-kad]'); if (!s) return; hafif();
        sec.hedef = s.getAttribute('data-kad'); ara.value = sec.hedef;
        sonuc.querySelectorAll('.dk-aday').forEach(function (x) { x.classList.toggle('sec', x === s); });
        beratYenile();
      });
    }
    $q('#dkOnay', md).onclick = async function () {
      var btn = this;
      var arg = { p_kod: p.kod, p_il: null, p_hedef: null, p_metin: null };
      if (p.il_mod === 'sec') arg.p_il = Number($q('#dkIl', md).value);
      if (p.hedef) { arg.p_hedef = sec.hedef || (ara && ara.value.trim()); if (!arg.p_hedef) return tst('Bir oyuncu seç.', true); }
      if (p.secenekler) arg.p_metin = $q('#dkSec', md).value; else if (mt) arg.p_metin = mt.value.trim() || null;
      if (p.nisan && (!arg.p_metin || arg.p_metin.length < 5)) return tst('Gerekçe en az 5 karakter olmalı.', true);
      btn.disabled = true; btn.classList.add('muhurle');
      try {
        PANEL.v = await API.rpc('resmi_program_yap', arg); PANEL.t = simdiMs();
        modalKapat();
        kutla(p.nisan ? p.nisan + ' tevcih edildi' : p.ad, p.nisan ? arg.p_hedef : (arg.p_metin || m.unvan));
        yenile();
      } catch (err) { btn.disabled = false; btn.classList.remove('muhurle'); tst(hataYaz(err), true); }
    };
  }
  function kutla(baslik, alt) {
    try {
      var d = document.createElement('div'); d.className = 'dk-kutla';
      d.innerHTML = '<div class="dk-kutla-ic"><span class="dk-muhur buyuk">' + MUHUR + '</span><b>' + esc(baslik) + '</b>' + (alt ? '<small>' + esc(alt) + '</small>' : '') + '<em>Resmî kayda geçti</em></div>';
      document.body.appendChild(d); hafif();
      setTimeout(function () { d.classList.add('git'); }, 1700); setTimeout(function () { d.remove(); }, 2300);
    } catch (_) { tst(baslik); }
  }
  async function katil(id, btn) {
    try { if (btn) btn.disabled = true; PANEL.v = await API.rpc('resmi_program_katil', { p_id: id }); PANEL.t = simdiMs(); kutla('Törene katıldın', 'Katılımın protokol kaydına işlendi'); yenile(); }
    catch (err) { if (btn) btn.disabled = false; tst(hataYaz(err), true); }
  }
  function yenile() {
    try {
      if (document.querySelector('.dk-tum-ekran')) return protokolEkrani();
      if (document.getElementById('bmMasa')) { var a = document.querySelector('#bmMasa .dk-resmi'); if (a) a.remove(); return bakanlikKunye(true); }
      if (document.querySelector('.dk-yonetim') && typeof yonetimEkrani === 'function') return yonetimEkrani();
      if (typeof D !== 'undefined' && D.sekme === 'meclis' && typeof meclisEkrani === 'function') return meclisEkrani();
      if (document.querySelector('.ust h1') && / Belediyesi$/.test(document.querySelector('.ust h1').textContent.trim()) && typeof belediyeEkrani === 'function') return belediyeEkrani();
      if (typeof devletEkrani === 'function') return devletEkrani();
    } catch (_) {}
  }
  async function protokolEkrani() {
    try { yukleniyor('Devlet protokolü'); } catch (_) {}
    var v = null, l = [];
    try { var r = await Promise.all([panelAl(true), API.rpc('resmi_programlar', { p_limit: 60 })]); v = r[0]; l = r[1] || []; } catch (err) { iskelet('Devlet protokolü', '<div class="bos">' + esc(hataYaz(err)) + '</div>', { geri: true }); return; }
    var ben = D.durum && D.durum.profil;
    iskelet('Devlet protokolü', '<div class="dk-tum-ekran">' + kunye({ ad: 'Devlet Protokolü', alt: 'Resmî törenler, ziyaretler, kabuller ve nişan tevcihleri', kpi: [['Açık tören', String((v.acik || []).length)], ['Kayıtlı program', String(l.length)], ['Nişan ve beratların', String((v.nisanlarim || []).length)]] }) +
      ajandaHtml(v) +
      ((v.acik || []).length ? '<section class="dk-protokol"><header class="dk-bolum"><div><small>Şu an</small><b>Katılıma açık törenler</b></div></header><div class="dk-akis acik">' + v.acik.map(function (x) { return akisSatir(x, ben); }).join('') + '</div></section>' : '') +
      '<section class="dk-protokol"><header class="dk-bolum"><div><small>Arşiv</small><b>Resmî program kayıtları</b></div></header><div class="dk-akis">' + (l.map(function (x) { return akisSatir(x, ben); }).join('') || '<p class="dk-not">Kayıt yok.</p>') + '</div></section>' +
      nisanlarimHtml(v.nisanlarim) + '</div>', { geri: true });
  }
  function nisanlarimHtml(l) {
    if (!l || !l.length) return '';
    return '<section class="dk-protokol"><header class="dk-bolum"><div><small>Onur kaydın</small><b>Nişan ve beratların</b></div></header>' + nisanListe(l) + '</section>';
  }
  function nisanListe(l) {
    return '<div class="dk-nisanlar">' + l.map(function (n) {
      return '<div class="dk-nisan"><span class="dk-madalya">' + MADALYA + '</span><div><b>' + esc(n.ad) + '</b><small>' + esc(n.veren_unvan || '') + ' ' + esc(n.veren || '') + ' · ' + esc(trh(n.zaman)) + '</small>' + (n.gerekce ? '<q>' + esc(n.gerekce) + '</q>' : '') + '</div></div>';
    }).join('') + '</div>';
  }
  var MADALYA = '<svg viewBox="0 0 40 48" aria-hidden="true"><path d="M10 0h8l4 10-6 6zM30 0h-8l-4 10 6 6z" fill="#b3263a"/><path d="M14 0h4l3 8-3 4zM26 0h-4l-3 8 3 4z" fill="#f1f1f1" opacity=".85"/><circle cx="20" cy="31" r="13" fill="url(#dkg)"/><circle cx="20" cy="31" r="9.5" fill="none" stroke="#7a5a17" stroke-width="1.2"/><path d="M20 24.5l1.9 3.9 4.3.6-3.1 3 .7 4.3-3.8-2-3.8 2 .7-4.3-3.1-3 4.3-.6z" fill="#7a5a17"/><defs><radialGradient id="dkg" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#fff2c4"/><stop offset=".55" stop-color="#e3bf62"/><stop offset="1" stop-color="#a77a22"/></radialGradient></defs></svg>';

  /* ---------------- tıklamalar ---------------- */
  document.addEventListener('click', function (ev) {
    var t = ev.target.closest('[data-dk-prog],[data-dk-katil],[data-dk-tum],[data-dk-ajanda]'); if (!t) return;
    ev.preventDefault(); hafif();
    if (t.hasAttribute('data-dk-prog')) return formAc(t.getAttribute('data-dk-prog'), t.getAttribute('data-dk-makam'));
    if (t.hasAttribute('data-dk-katil')) return katil(Number(t.getAttribute('data-dk-katil')), t);
    if (t.hasAttribute('data-dk-tum') || t.hasAttribute('data-dk-ajanda')) return ekranAc(protokolEkrani);
  });
  window.protokolEkrani = protokolEkrani;

  /* ---------------- ekranlara yerleştirme ---------------- */
  function icerikBasina(html) { var ic = document.getElementById('icerik'); if (!ic || !html) return; var d = document.createElement('div'); d.className = 'dk-ek'; d.innerHTML = html; ic.insertBefore(d, ic.firstChild); tazele(d); }

  // Devlet › Hükümet
  if (typeof hukumetHtml === 'function') {
    var asilHukumet = hukumetHtml;
    window.hukumetHtml = hukumetHtml = async function () {
      var govde = await asilHukumet.apply(this, arguments);
      var v = null; try { v = await panelAl(true); } catch (_) {}
      var u = (typeof D !== 'undefined' && D._karne) || null, ust = '';
      try {
        ust = kunye({ ad: 'Cumhurbaşkanlığı ve Hükümet', ust: 'Türkiye Cumhuriyeti · Yürütme', alt: u ? 'Hazine ' + sayi(u.hazine, 0) + ' milyar ₺ · Mali alan ' + sayi(u.mali_alan, 1) + ' milyar ₺/gün' : '',
          kpi: u ? [['Büyüme', yuz(u.buyume), u.buyume >= 3 ? 'iyi' : 'kotu'], ['Enflasyon', yuz(u.enflasyon), u.enflasyon <= 20 ? 'iyi' : 'kotu'], ['İşsizlik', yuz(u.issizlik), u.issizlik <= 9 ? 'iyi' : 'kotu'], ['Memnuniyet', yuz(u.memnuniyet), u.memnuniyet >= 55 ? 'iyi' : 'kotu']] : [],
          eylem: '<button type="button" class="dk-kunye-btn" data-dk-ajanda="1">' + ik('Tören') + 'Devlet protokolü</button>' }) +
          ajandaHtml(v, ['cb', 'bakan']) + protokolHtml(v, 5);
      } catch (_) {}
      return '<div class="dk-resmi">' + ust + '</div>' + govde;
    };
  }

  // Meclis
  if (typeof meclisHtml === 'function') {
    var asilMeclis = meclisHtml;
    window.meclisHtml = meclisHtml = async function () {
      var govde = await asilMeclis.apply(this, arguments), ust = '';
      try {
        var r = typeof meclisRehberAl === 'function' ? await meclisRehberAl() : null;
        var v = null; try { v = await panelAl(); } catch (_) {}
        var bas = r && r.baskan && (r.baskan.kad || (r.baskan.kisi && r.baskan.kisi.kad));
        ust = kunye({ ad: 'Türkiye Büyük Millet Meclisi', ust: 'Egemenlik kayıtsız şartsız milletindir', alt: bas ? 'TBMM Başkanı ' + esc(bas) : 'Yasama · Denetim · Temsil',
          kpi: r ? [['Dolu sandalye', sayi(r.dolu) + ' / ' + sayi(r.toplam)], ['Grup', String((r.partiler || []).length)], ['Bağımsız', String(r.bagimsiz || 0)], ['Karar yeter sayısı', String(r.cogunluk || '—')]] : [] });
        if ((D.meclisSekme || 'genel') === 'genel') ust += ajandaHtml(v, ['tbmm', 'mv']);
      } catch (_) {}
      return '<div class="dk-resmi">' + ust + '</div>' + govde;
    };
  }

  // Belediye
  if (typeof belediyeEkrani === 'function') {
    var asilBelediye = belediyeEkrani;
    window.belediyeEkrani = belediyeEkrani = async function () {
      var r = await asilBelediye.apply(this, arguments);
      try {
        var b = D._belediye; if (!b || !document.getElementById('icerik')) return r;
        var v = null; try { v = await panelAl(true); } catch (_) {}
        icerikBasina('<div class="dk-resmi">' + kunye({ ad: b.il_ad + ' Belediyesi', ust: 'Türkiye Cumhuriyeti · Yerel Yönetim', alt: 'Belediye başkanlığı makamı',
          kpi: [['Kasa', sayi(b.kasa, 2) + ' milyar ₺'], ['Günlük gelir', sayi(b.gelir, 3) + ' milyar'], ['Gelişmişlik', sayi(b.gelisim, 0), b.gelisim >= 50 ? 'iyi' : 'kotu'], ['Memnuniyet', yuz(b.memnuniyet, 0), b.memnuniyet >= 50 ? 'iyi' : 'kotu']] }) +
          ajandaHtml(v, ['bel']) + '</div>');
      } catch (_) {}
      return r;
    };
  }

  // Bakanlık masası: künye ve ajanda kısayolu (masa kendi içinde sık yeniden çizildiği için gözlemciyle)
  async function bakanlikKunye(zorla) {
    var masa = document.getElementById('bmMasa'); if (!masa || (!zorla && masa.querySelector('[data-dk="kunye"]'))) return;
    var v = null; try { v = await panelAl(zorla); } catch (_) {}
    masa = document.getElementById('bmMasa'); if (!masa || masa.querySelector('[data-dk="kunye"]')) return;
    var bm = (v && v.makamlar || []).find(function (m) { return m.makam === 'bakan'; });
    var ad = bm ? bm.unvan.replace(/Bakanı$/, 'Bakanlığı') : 'Bakanlık';
    var d = document.createElement('div'); d.className = 'dk-resmi';
    d.innerHTML = kunye({ ad: ad, ust: 'Türkiye Cumhuriyeti', alt: bm ? 'Bakanlık kasası ' + sayi(bm.kasa, 1) + ' milyar ₺' : '',
      eylem: bm ? '<button type="button" class="dk-kunye-btn" data-dk-ajanda="1">' + ik('Tören') + 'Makam ajandası ve protokol</button>' : '' });
    masa.insertBefore(d, masa.firstChild);
  }
  var gz = 0;
  try { new MutationObserver(function () { if (gz) return; gz = requestAnimationFrame(function () { gz = 0; if (document.getElementById('bmMasa')) bakanlikKunye(false); }); }).observe(document.getElementById('app') || document.body, { childList: true, subtree: true }); } catch (_) {}

  // Yönetim: kişinin bütün makamlarının ajandası tek yerde
  if (typeof window.yonetimEkrani === 'function') {
    var asilYonetim = window.yonetimEkrani;
    window.yonetimEkrani = async function () {
      var r = await asilYonetim.apply(this, arguments);
      try {
        var v = await panelAl(true);
        if (v && (v.makamlar || []).length && document.getElementById('icerik')) {
          icerikBasina('<div class="dk-resmi dk-yonetim">' + kunye({ ad: 'Makam Ajandası', alt: v.makamlar.map(function (m) { return esc(m.unvan); }).join(' · '),
            kpi: [['Makam', String(v.makamlar.length)], ['Açık tören', String((v.acik || []).length)], ['Nişanların', String((v.nisanlarim || []).length)]],
            eylem: '<button type="button" class="dk-kunye-btn" data-dk-tum="1">' + ik('Tören') + 'Devlet protokolü ve arşiv</button>' }) + ajandaHtml(v) + '</div>');
        }
      } catch (_) {}
      return r;
    };
  }

  // Oyuncu kartı: nişan ve beratlar
  if (typeof oyuncuKart === 'function') {
    var asilKart = oyuncuKart;
    window.oyuncuKart = oyuncuKart = async function (kad) {
      var r = await asilKart.apply(this, arguments);
      try {
        var l = await API.rpc('oyuncu_nisanlari', { p_kad: kad });
        if (!l || !l.length) return r;
        var md = document.querySelector('.modal'); if (!md) return r;
        var hedef = Array.prototype.find.call(md.querySelectorAll('.kart h2'), function (h) { return /Siyasi geçmiş/.test(h.textContent); });
        var s = document.createElement('div'); s.className = 'kart dk-kart-nisan';
        s.innerHTML = '<h2>Nişan ve beratlar</h2>' + nisanListe(l);
        if (hedef && hedef.parentNode) hedef.parentNode.parentNode.insertBefore(s, hedef.parentNode); else md.appendChild(s);
      } catch (_) {}
      return r;
    };
  }

  /* ---------------- stil ---------------- */
  var G = '#d9b25b', G2 = '#e8cf8f';
  var css = [
    '.dk-resmi{display:flex;flex-direction:column;gap:12px;margin-bottom:12px}',
    '.dk-kunye,.dk-ajanda,.dk-protokol{position:relative;padding:16px 14px 14px;border-radius:18px;background:linear-gradient(180deg,rgba(217,178,91,.08),rgba(217,178,91,0) 50%),var(--panel,#151E3D);border:1px solid rgba(217,178,91,.26);box-shadow:0 18px 40px -26px rgba(0,0,0,.8),inset 0 1px 0 rgba(255,255,255,.04);overflow:hidden}',
    '.dk-kunye::before,.dk-ajanda::before,.dk-protokol::before{content:"";position:absolute;inset:6px;border:1px solid rgba(217,178,91,.10);border-radius:13px;pointer-events:none}',
    '.dk-kunye{background:radial-gradient(120% 90% at 0% 0%,rgba(217,178,91,.16),transparent 55%),linear-gradient(160deg,#18234a,#0f1633)}',
    '.dk-kunye::after{content:"";position:absolute;right:-30px;top:-30px;width:150px;height:150px;opacity:.06;background:url("data:image/svg+xml;utf8,' + encodeURIComponent(MUHUR.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ').replace(/currentColor/g, G)).replace(/'/g, '%27') + '") center/contain no-repeat;pointer-events:none}',
    '.dk-kunye-ust{display:flex;align-items:center;gap:13px}',
    '.dk-muhur{flex:none;width:52px;height:52px;border-radius:50%;display:grid;place-items:center;color:' + G + ';background:radial-gradient(circle at 50% 30%,rgba(217,178,91,.24),rgba(217,178,91,.04));box-shadow:0 0 0 1px rgba(217,178,91,.42) inset,0 10px 24px -12px rgba(217,178,91,.7)}',
    '.dk-muhur svg{width:46px;height:46px}.dk-muhur.kucuk{width:38px;height:38px}.dk-muhur.kucuk svg{width:33px;height:33px}.dk-muhur.buyuk{width:96px;height:96px}.dk-muhur.buyuk svg{width:86px;height:86px}',
    '.dk-kunye-ad{min-width:0;display:flex;flex-direction:column}.dk-kunye-ad small{font-size:11.5px;letter-spacing:.4px;color:#c9b88f}',
    '.dk-kunye-ad b{font-family:var(--disp);font-size:23px;font-weight:800;line-height:1.1;color:#f5ecd4;letter-spacing:.2px}',
    '.dk-kunye-ad span{margin-top:3px;font-size:12.5px;color:#a9b2cf}',
    '.dk-kpiler{display:grid;grid-template-columns:repeat(auto-fit,minmax(74px,1fr));gap:1px;margin-top:14px;border-radius:12px;overflow:hidden;background:rgba(217,178,91,.18)}',
    '.dk-kpi{padding:9px 8px;background:rgba(10,15,36,.86);text-align:center}.dk-kpi small{display:block;font-size:10.5px;color:#a9b2cf;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.dk-kpi b{display:block;margin-top:2px;font-family:var(--disp);font-size:17px;color:#f5ecd4;font-variant-numeric:tabular-nums}.dk-kpi b.iyi{color:#7fe3bf}.dk-kpi b.kotu{color:#ff9aa2}',
    '.dk-kunye-btn{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;margin-top:12px;min-height:42px;border-radius:12px;border:1px solid rgba(217,178,91,.4);background:rgba(217,178,91,.08);color:' + G2 + ';font:inherit;font-size:14px;font-weight:700;cursor:pointer}.dk-kunye-btn svg{width:18px;height:18px}',
    '.dk-bolum{display:flex;align-items:center;gap:11px;padding-bottom:11px;margin-bottom:10px;border-bottom:1px solid rgba(217,178,91,.2)}',
    '.dk-bolum>div{flex:1;min-width:0}.dk-bolum small{display:block;font-size:11.5px;color:#c9b88f;letter-spacing:.3px}.dk-bolum b{display:block;font-family:var(--disp);font-size:19px;color:#f5ecd4;line-height:1.15;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.dk-kasa{flex:none;text-align:right;font-family:var(--disp);font-size:15px;color:' + G2 + '}.dk-kasa small{display:block;font-family:inherit;font-size:10.5px;color:#a9b2cf}',
    '.dk-not{margin:0 2px 8px;font-size:12.5px;line-height:1.5;color:#a9b2cf}',
    '.dk-grup{margin-top:10px}.dk-grup h4{margin:0 0 7px;font-size:12px;font-weight:700;letter-spacing:.5px;color:#c9b88f}',
    '.dk-proglar{display:flex;flex-direction:column;gap:7px}',
    '.dk-prog{display:flex;gap:11px;width:100%;padding:11px;border-radius:13px;border:1px solid rgba(217,178,91,.18);background:rgba(8,12,30,.45);color:var(--txt);font:inherit;text-align:left;cursor:pointer;-webkit-tap-highlight-color:transparent;transition:border-color .2s,background .2s}',
    '.dk-prog:active{transform:scale(.99);background:rgba(217,178,91,.08)}.dk-prog.bekle{opacity:.62}',
    '.dk-prog-ik{flex:none;width:40px;height:40px;border-radius:12px;display:grid;place-items:center;color:#1b1607;background:linear-gradient(135deg,' + G2 + ',#b8913f);box-shadow:0 6px 14px -8px rgba(217,178,91,.9)}.dk-prog-ik svg{width:21px;height:21px}',
    '.dk-prog-ik.k-Diplomasi,.dk-akis-ik.k-Diplomasi{background:linear-gradient(135deg,#9fd0ff,#4f86d9);color:#0b1a33}',
    '.dk-prog-ik.k-Nişan,.dk-akis-ik.k-Nişan{background:linear-gradient(135deg,#ffd9de,#c43d55);color:#2b0710}',
    '.dk-prog-ik.k-Kabul,.dk-akis-ik.k-Kabul{background:linear-gradient(135deg,#d7ccff,#7d63e8);color:#150b38}',
    '.dk-prog-ik.k-Ziyaret,.dk-akis-ik.k-Ziyaret{background:linear-gradient(135deg,#bff3dc,#2ea978);color:#062418}',
    '.dk-prog-ik.k-Hizmet,.dk-akis-ik.k-Hizmet{background:linear-gradient(135deg,#ffe2b8,#e08a2e);color:#2b1503}',
    '.dk-prog-g{flex:1;min-width:0;display:flex;flex-direction:column}.dk-prog-g small{font-size:10.5px;color:#c9b88f;letter-spacing:.4px}',
    '.dk-prog-g b{font-size:15px;font-weight:700;color:#f3eee0;line-height:1.25}.dk-prog-g em{font-style:normal;margin-top:2px;font-size:12.5px;line-height:1.4;color:#a9b2cf;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}',
    '.dk-prog-alt{display:flex;justify-content:space-between;gap:8px;margin-top:6px;font-size:11.5px;color:#8f9bbd}.dk-prog-alt i{font-style:normal;font-weight:700;color:#c9b88f;white-space:nowrap}.dk-prog-alt i.ok{color:#7fe3bf}.dk-prog-alt i.kotu{color:#ff9aa2}',
    '.dk-canli{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700;color:#ff9aa2}.dk-canli i{width:8px;height:8px;border-radius:50%;background:#ff5a6e;box-shadow:0 0 0 0 rgba(255,90,110,.6);animation:dkNabiz 1.6s infinite}',
    '@keyframes dkNabiz{70%{box-shadow:0 0 0 8px rgba(255,90,110,0)}100%{box-shadow:0 0 0 0 rgba(255,90,110,0)}}',
    '.dk-akis{position:relative;display:flex;flex-direction:column}.dk-akis::before{content:"";position:absolute;left:17px;top:6px;bottom:6px;width:1px;background:linear-gradient(rgba(217,178,91,.4),rgba(217,178,91,.05))}',
    '.dk-akis.acik{margin-bottom:8px;padding:6px;border-radius:12px;background:rgba(255,90,110,.05);border:1px solid rgba(255,90,110,.18)}.dk-akis.acik::before{display:none}',
    '.dk-akis-s{position:relative;display:flex;gap:11px;align-items:flex-start;padding:8px 0}',
    '.dk-akis-ik{position:relative;z-index:1;flex:none;width:34px;height:34px;border-radius:50%;display:grid;place-items:center;color:#1b1607;background:linear-gradient(135deg,' + G2 + ',#b8913f)}.dk-akis-ik svg{width:17px;height:17px}',
    '.dk-akis-g{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}.dk-akis-g>b{font-size:14.5px;color:#f3eee0;line-height:1.3}.dk-akis-g>b span{font-weight:500;color:#c9b88f}',
    '.dk-akis-g small{font-size:12px;color:#a9b2cf}.dk-akis-g q{font-family:Georgia,serif;font-style:italic;font-size:13.5px;color:#d9dcea;quotes:"“" "”"}',
    '.dk-akis-alt{font-size:11.5px;color:#8f9bbd}.dk-akis-alt i{font-style:normal;color:#ff9aa2;font-weight:700}',
    '.dk-katil{flex:none;align-self:center;min-height:34px;padding:0 14px;border-radius:10px;border:0;background:linear-gradient(135deg,' + G2 + ',#b8913f);color:#1b1607;font:inherit;font-size:13.5px;font-weight:800;cursor:pointer;box-shadow:0 8px 16px -10px rgba(217,178,91,.9)}',
    '.dk-katildi{flex:none;align-self:center;font-size:12px;font-weight:700;color:#7fe3bf}',
    '.dk-tum{width:100%;margin-top:8px;min-height:40px;border-radius:11px;border:1px solid rgba(217,178,91,.3);background:none;color:' + G2 + ';font:inherit;font-size:13.5px;font-weight:700;cursor:pointer}',
    '.dk-form-bas{display:flex;gap:12px;align-items:center}.dk-form-bas small{font-size:11.5px;color:#c9b88f}.dk-form-bas h3{margin:2px 0 0;font-family:var(--disp);font-size:21px;line-height:1.15}',
    '.dk-form-acik{margin:10px 0 8px;font-size:14px;line-height:1.5;color:var(--txt2,#C9D1E6)}',
    '.dk-cipler{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px}.dk-cip{font-size:11.5px;font-weight:600;padding:4px 9px;border-radius:999px;background:rgba(255,255,255,.06);color:#c5cdf0}.dk-cip.iyi{background:rgba(52,201,138,.12);color:#7fe3bf}.dk-cip.kotu{background:rgba(240,69,75,.12);color:#ff9aa2}.dk-cip.altin{background:rgba(217,178,91,.14);color:' + G2 + '}',
    '.dk-yer{display:flex;align-items:center;gap:6px;margin:4px 0 10px;font-weight:700;color:' + G2 + '}.dk-yer svg{width:18px;height:18px}',
    '.dk-sonuc{display:flex;flex-direction:column;gap:5px;max-height:30vh;overflow:auto;margin:-4px 0 10px}',
    '.dk-aday{display:flex;align-items:center;gap:10px;padding:7px 9px;border-radius:11px;border:1px solid var(--line,rgba(164,184,255,.1));background:rgba(255,255,255,.03);color:var(--txt);font:inherit;text-align:left;cursor:pointer}',
    '.dk-aday.sec{border-color:' + G + ';background:rgba(217,178,91,.1)}.dk-aday b{display:block;font-size:14.5px}.dk-aday small{display:block;font-size:12px;color:var(--mut,#98A4C4)}',
    '.dk-aday-p .portre,.dk-aday-p svg.portre{width:34px!important;height:34px!important;border-radius:50%;display:block}',
    '.dk-bas{display:grid;place-items:center;border-radius:50%;background:#283563;font-weight:800;font-size:12px}',
    '.dk-form textarea,.dk-form select,.dk-form input{width:100%;box-sizing:border-box;padding:11px 13px;border-radius:12px;border:1px solid rgba(217,178,91,.3);background:rgba(8,12,30,.55);color:var(--txt,#EEF1F8);font:inherit;font-size:15px;outline:none;resize:vertical}',
    '.dk-form textarea:focus,.dk-form select:focus,.dk-form input:focus{border-color:rgba(217,178,91,.75)}',
    '.dk-form .btn.dk-onay{width:100%;min-height:48px;border:0;border-radius:13px;background:linear-gradient(135deg,' + G2 + ',#b8913f)!important;color:#1b1607!important;font-weight:800;box-shadow:0 12px 24px -12px rgba(217,178,91,.9)}',
    '.dk-form .btn.dk-onay:disabled{opacity:.55}',
    '.dk-onay{margin-top:4px}.dk-onay.muhurle{animation:dkMuhur .6s ease}@keyframes dkMuhur{40%{transform:scale(.92) rotate(-2deg)}100%{transform:none}}',
    '.dk-berat{margin:4px 0 12px;padding:6px;border-radius:8px;background:linear-gradient(135deg,#c9a85a,#8a6a24);box-shadow:0 18px 34px -18px rgba(0,0,0,.9)}',
    '.dk-berat-ic{position:relative;display:flex;flex-direction:column;align-items:center;text-align:center;padding:16px 16px 14px;border-radius:5px;background:#f7f2e4;color:#2a241a;font-family:Georgia,"Times New Roman",serif;border:1px solid #c9b07a}',
    '.dk-berat-ic::before{content:"";position:absolute;inset:5px;border:1px solid rgba(160,124,48,.45);border-radius:3px;pointer-events:none}',
    '.dk-berat .dk-muhur{color:#9c7a2c;background:none;box-shadow:0 0 0 1px rgba(156,122,44,.45) inset}',
    '.dk-berat-ic>small{margin-top:6px;font-size:11.5px;letter-spacing:.8px;color:#6b604b}',
    '.dk-berat-ic h3{margin:6px 0 2px;font-size:19px;color:#7a5a17;line-height:1.25}',
    '.dk-berat-kime{margin:8px 0 2px;font-family:"Snell Roundhand","Segoe Script","Brush Script MT",cursive;font-size:26px;color:#1f3a7a}',
    '.dk-berat-g{margin:2px 0 0;font-size:13.5px;line-height:1.5;color:#3d3628}.dk-berat i{color:#9b9079}',
    '.dk-berat-alt{display:flex;justify-content:space-between;align-items:flex-end;width:100%;margin-top:14px;font-size:12px;color:#5f584a}',
    '.dk-imza{display:flex;flex-direction:column;align-items:center}.dk-imza b{font-family:"Snell Roundhand","Segoe Script","Brush Script MT",cursive;font-weight:400;font-size:19px;color:#1f3a7a;transform:rotate(-3deg)}.dk-imza small{margin-top:3px;padding-top:3px;border-top:1px solid #8e8572;font-size:11px}',
    '.dk-kutla{position:fixed;inset:0;z-index:9999;display:grid;place-items:center;background:rgba(5,8,20,.55);-webkit-backdrop-filter:blur(4px);backdrop-filter:blur(4px);animation:dkGir .3s ease;pointer-events:none}',
    '.dk-kutla.git{opacity:0;transition:opacity .5s}',
    '.dk-kutla-ic{display:flex;flex-direction:column;align-items:center;gap:6px;padding:26px 28px;border-radius:20px;background:linear-gradient(160deg,#1b2650,#0f1633);border:1px solid rgba(217,178,91,.45);text-align:center;max-width:300px;box-shadow:0 30px 60px -20px rgba(0,0,0,.8)}',
    '.dk-kutla-ic .dk-muhur{animation:dkDamga .55s cubic-bezier(.2,1.6,.4,1)}',
    '.dk-kutla-ic b{margin-top:6px;font-family:var(--disp);font-size:20px;color:#f5ecd4}.dk-kutla-ic small{font-size:13px;color:#a9b2cf}.dk-kutla-ic em{font-style:normal;margin-top:4px;font-size:11.5px;letter-spacing:.6px;color:' + G + '}',
    '@keyframes dkGir{from{opacity:0}}@keyframes dkDamga{0%{transform:scale(2.2) rotate(-18deg);opacity:0}100%{transform:none;opacity:1}}',
    '.dk-nisanlar{display:flex;flex-direction:column;gap:8px}',
    '.dk-nisan{display:flex;gap:11px;align-items:flex-start;padding:10px;border-radius:12px;background:linear-gradient(90deg,rgba(217,178,91,.10),rgba(217,178,91,.02));border:1px solid rgba(217,178,91,.22)}',
    '.dk-madalya{flex:none;width:30px;height:36px}.dk-madalya svg{width:30px;height:36px;filter:drop-shadow(0 4px 6px rgba(0,0,0,.5))}',
    '.dk-nisan b{display:block;font-size:14.5px;color:#f5ecd4}.dk-nisan small{display:block;font-size:12px;color:#a9b2cf}.dk-nisan q{display:block;margin-top:3px;font-family:Georgia,serif;font-style:italic;font-size:13px;color:#d9dcea}',
    '.dk-kart-nisan{border:1px solid rgba(217,178,91,.3)!important;background:linear-gradient(180deg,rgba(217,178,91,.07),transparent 60%),var(--panel,#151E3D)!important}',
    '@media (prefers-reduced-motion:reduce){.dk-canli i,.dk-kutla,.dk-kutla-ic .dk-muhur,.dk-onay.muhurle{animation:none}}'
  ];
  var st = document.createElement('style'); st.id = 'makamKurumsalStil'; st.textContent = css.join('\n');
  (document.head || document.documentElement).appendChild(st);
})();
