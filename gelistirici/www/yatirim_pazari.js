/* Seçim Online - yatırım amaçlı gayrimenkul pazarı (2026-10-22).
 * Belediyeden arsa/daire/dükkan + oyuncular arası tapu devri;
 * müteahhitten alınmış kişisel daire/dükkan tapuları da yeniden satılabilir.
 */
(function () {
  "use strict";
  var veri = null, secIl = null, secTip = "hepsi";
  var adlar = { arsa: "Arsa", daire: "Daire / Ev", dukkan: "Dükkân" };
  var ikonlar = { arsa: "🌱", daire: "🏠", dukkan: "🏪" };
  var kac = function (v) { return Number(v || 0); };
  var tl = function (v) { return typeof tlYaz === "function" ? tlYaz(kac(v)) : kac(v).toLocaleString("tr-TR") + " ₺"; };
  var esc = function (v) { return String(v == null ? "" : v).replace(/[&<>"']/g, function (c) { return { "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]; }); };
  var msg = function (s, bad) { if (typeof toast === "function") toast(s, !!bad); };
  var errtext = function (er) { return typeof hataCevir === "function" ? hataCevir(er.message || String(er)) : (er.message || String(er)); };
  function kutu(title, body) { return '<div class="kart"><h2>' + title + '</h2>' + body + '</div>'; }
  function satir(label, val) { return '<div class="kv"><span>' + label + '</span><b>' + val + '</b></div>'; }
  function buton(text, command, style) { return '<button class="btn ' + (style || 'ikinci') + '" onclick="' + command + '">' + text + '</button>'; }
  function kiraci(t) { return kac(t) > 0 ? tl(t) + ' / hafta' : 'Kira yok (arsa)'; }
  function goster(d) {
    veri = d;
    if (secIl == null) secIl = kac(d.il);
    var iller = d.iller || [], belediye = d.belediye || [], ilanlar = d.ilanlar || [];
    var h = kutu('🏘️ Yatırımlık Gayrimenkul', '<p class="alt">81 ilde belediyeden arsa, ev veya dükkân alabilir; tapulu taşınmazlarını başka oyunculara satabilirsin. İnşaat projelerinden aldığın daire ve dükkânlar da satışa çıkarılabilir.</p>' +
      satir('Cüzdan bakiyen', tl(d.cuzdan)) + '<p class="kucuk">Belediyeden alışta %2 tapu harcı; oyuncular arası satışta alıcı ve satıcıdan ayrı ayrı %2 tapu harcı alınır. Arsanın kira geliri yoktur.</p>');
    h += kutu('📍 İl ve mülk türü', '<div class="alan"><label>İl</label><select id="ypIl" onchange="ypIlDegis(this.value)">' +
      iller.map(function (i) { return '<option value="' + kac(i.id) + '"' + (kac(i.id) === kac(secIl) ? ' selected' : '') + '>' + esc(i.ad) + '</option>'; }).join('') +
      '</select></div><div class="alan"><label>Tür</label><select onchange="ypTurDegis(this.value)">' +
      [['hepsi','Tümü'],['arsa','Arsa'],['daire','Ev / Daire'],['dukkan','Dükkân']].map(function (x) {
        return '<option value="' + x[0] + '"' + (secTip === x[0] ? ' selected' : '') + '>' + x[1] + '</option>';
      }).join('') + '</select></div>');
    h += '<div id="ypDinamik">' + dinamik(d) + '</div>';
    h += kutu('📋 Tapularım / Portföyüm', portfoy(d));
    var gecmis = (d.gecmis || []).slice(0,12);
    h += kutu('🧾 Son Tapu İşlemlerim', gecmis.length ? gecmis.map(function (x) {
      return '<div class="liste-satir"><span class="orta"><b>' + (x.rol === 'alici' ? 'Alış' : 'Satış') +
        ' · ' + esc(adlar[x.tip] || x.tip) + '</b><span class="kucuk">' + esc(x.il) +
        ' · ' + esc(new Date(x.tarih).toLocaleDateString('tr-TR')) + '</span></span><b>' + tl(x.bedel) + '</b></div>';
    }).join('') : '<p class="alt">Henüz bu pazarda işlem yapmadın.</p>');
    iskelet('Gayrimenkul Yatırım Pazarı', h, { geri: true });
  }
  function dinamik(d) {
    var belediye = (d.belediye || []).filter(function (x) { return secTip === 'hepsi' || x.tip === secTip; });
    var ilanlar = (d.ilanlar || []).filter(function (x) { return secTip === 'hepsi' || x.tip === secTip; });
    var h = kutu('🏛️ Belediyeden Satılık', belediye.map(function (x) {
      var fiyat = kac(x.fiyat), kalan = kac(x.kalan), tip = x.tip;
      return '<div class="liste-satir" style="align-items:flex-start"><span class="orta"><b>' + (ikonlar[tip] || '🏡') +
         ' ' + esc(adlar[tip] || tip) + ' · ' + kac(x.m2) + ' m²</b>' +
        '<span class="kucuk">' + kiraci(x.haftalik_kira) + ' · Stok ' + kalan + ' / ' + kac(x.kota) + '</span>' +
        '<span class="kucuk">Alıcı harcı dahil ' + tl(fiyat * 1.02) + '</span></span>' +
        '<span style="text-align:right"><b>' + tl(fiyat) + '</b><div style="margin-top:7px">' +
        (kalan ? buton('Satın al', "ypAlimOnay('belediye_al'," + "{il:" + kac(secIl) + ",tip:'" + tip + "'}" + "," + fiyat + ")", 'altin') : '<span class="rozet">Tükendi</span>') +
        '</div></span></div>';
    }).join('') || '<p class="alt">Bu il ve türde belediye satış stoğu bulunmuyor.</p>');
    h += kutu('🤝 Oyunculardan Satılık', ilanlar.length ? ilanlar.map(function (x) {
      var tip = x.tip, komut = x.benim ? "ypIslem('ilan_iptal',{ilan:" + kac(x.id) + "})" :
        "ypAlimOnay('ilan_al',{ilan:" + kac(x.id) + "}," + kac(x.fiyat) + ")";
      return '<div class="liste-satir" style="align-items:flex-start"><span class="orta"><b>' +
        (ikonlar[tip] || '🏡') + ' ' + esc(adlar[tip] || tip) + ' #' + kac(x.ref_id) +
        '</b><span class="kucuk">' + kac(x.m2) + ' m² · Satıcı: ' + esc(x.satici) + '</span>' +
        '<span class="kucuk">' + esc(x.aciklama || '') + '</span></span>' +
        '<span style="text-align:right"><b>' + tl(x.fiyat) + '</b><div style="margin-top:7px">' +
        buton(x.benim ? 'İlanımı kaldır' : 'Satın al', komut, x.benim ? 'ikinci' : 'altin') +
        '</div></span></div>';
    }).join('') : '<p class="alt">Bu il ve türde oyuncu ilanı yok.</p>');
    return h;
  }
  function portfoy(d) {
    var sahiplik = (d.benim || []).concat(d.benim_projeler || []);
    if (!sahiplik.length) return '<p class="alt">Henüz yatırımın yok. Belediyeden satın alarak başlayabilirsin.</p>';
    var toplam = sahiplik.reduce(function (a, x) { return a + kac(x.deger); }, 0);
    var kira = sahiplik.reduce(function (a, x) { return a + kac(x.kira); }, 0);
    return satir('Görünen toplam değer', tl(toplam)) + satir('Haftalık kira potansiyeli', tl(kira)) +
      '<p class="kucuk">İnşaat projesinden aldığın dükkân aktif bir şube tarafından kiralanmışsa tapu satışı kiracı sözleşmesi bitene kadar kapalıdır.</p>' +
      sahiplik.map(function (x) {
        var tip = x.tip, rayic = kac(x.deger), ilani = x.ilan_id;
        var engel = x.kirada;
        return '<div class="liste-satir" style="align-items:flex-start"><span class="orta"><b>' +
          (ikonlar[tip] || '🏡') + ' ' + esc(adlar[tip] || tip) + ' #' + kac(x.ref_id) + '</b>' +
          '<span class="kucuk">' + esc(x.il) + ' · ' + kac(x.m2) + ' m² · ' + esc(x.aciklama || '') + '</span>' +
          '<span class="kucuk">Alış: ' + tl(x.alis) + ' · Tahmini rayiç: ' + tl(rayic) +
          ' · Haftalık kira: ' + tl(x.kira) + '</span></span><span>' +
          (ilani ? buton('İlanı kaldır', "ypIslem('ilan_iptal',{ilan:" + kac(ilani) + "})") :
           engel ? '<span class="rozet">Kiracı var</span>' :
           buton('Satış ilanı ver', "ypIlanAc('" + x.kaynak + "'," + kac(x.ref_id) + "," + rayic + ")", 'altin')) +
          '</span></div>';
      }).join('');
  }
  window.ypIlDegis = function (id) {
    secIl = Number(id);
    window.yatirimPazarEkrani();
  };
  window.ypTurDegis = function (tip) {
    secTip = tip;
    var alan = document.getElementById('ypDinamik');
    if (alan && veri) alan.innerHTML = dinamik(veri);
  };
  window.yatirimPazarEkrani = async function () {
    if (typeof yukleniyor === 'function') yukleniyor('Yatırım pazarı');
    try { goster(await API.rpc('yatirim_pazar_panel', {p_il:secIl})); }
    catch (er) { iskelet('Yatırım pazarı',kutu('İşlem yapılamadı','<p>' + esc(errtext(er)) + '</p>'),{geri:true}); }
  };
  window.ypIslem = async function (eylem, veri) {
    try {
      await API.rpc('yatirim_pazar_islem', {p_eylem:eylem,p_veri:veri});
      if (typeof modalKapat === 'function') modalKapat();
      msg(eylem === 'ilan_iptal' ? 'Satılık ilanı kaldırıldı.' : 'Tapu işlemi tamamlandı.');
      await window.yatirimPazarEkrani();
    } catch (er) { msg(errtext(er), true); }
  };
  window.ypAlimOnay = function (eylem, veri, fiyat) {
    var tutar = kac(fiyat);
    var m = modal('<h3>Tapu alımını onayla</h3>' +
      satir('Satış bedeli',tl(tutar)) + satir('Alıcı tapu harcı (%2)',tl(tutar*.02)) +
      satir('Ödenecek toplam',tl(tutar*1.02)) +
      '<p class="kucuk">Ödeme yapılırsa tapu otomatik olarak hesabına geçer. Satışı geri alma işlemi yoktur.</p>' +
      '<button class="btn altin" id="ypOnayBtn">Satın al ve tapuyu devret</button>');
    m.querySelector('#ypOnayBtn').onclick = async function () {
      this.disabled = true;
      try {
        await API.rpc('yatirim_pazar_islem',{p_eylem:eylem,p_veri:veri});
        modalKapat(); msg('Satın alma başarılı. Tapun oluşturuldu.');
        window.yatirimPazarEkrani();
      } catch (er) { this.disabled = false; msg(errtext(er),true); }
    };
  };
  window.ypIlanAc = function (kaynak, id, rayic) {
    var varsayilan = Math.max(10000,Math.round(rayic));
    var m = modal('<h3>Taşınmazı satışa çıkar</h3><p class="alt">Tapu #' + kac(id) +
      ' · Rayiç yaklaşık ' + tl(rayic) + '</p><div class="alan"><label>Satış fiyatı (₺)</label>' +
      '<input type="number" id="ypFiyat" min="10000" max="1000000000" step="1000" value="' + varsayilan +
      '"></div><p class="kucuk">Fiyat il rayicinin %40–%400 aralığında olmalıdır. Satılınca %2 satıcı harcı kesilir.</p>' +
      '<button class="btn altin" id="ypIlanBtn">İlanı yayımla</button>');
    m.querySelector('#ypIlanBtn').onclick = async function () {
      var fiyat = Number(m.querySelector('#ypFiyat').value);
      if (!Number.isSafeInteger(fiyat) || fiyat<10000 || fiyat>1000000000) { msg('Geçerli bir fiyat gir.',true); return; }
      this.disabled = true;
      try {
        await API.rpc('yatirim_pazar_islem',{p_eylem:'ilan_ac',p_veri:{kaynak:kaynak,ref_id:id,fiyat:fiyat}});
        modalKapat(); msg('Satılık ilanı yayımlandı.'); window.yatirimPazarEkrani();
      } catch (er) { this.disabled = false; msg(errtext(er),true); }
    };
  };
  function girisEkle() {
    var root = document.getElementById('icerik');
    if (!root || root.querySelector('.yp-giris') || root.querySelector('#ypDinamik')) return;
    var baslik = root.querySelector('h2');
    if (!baslik || !/(gayrimenkul|emlak pazarı|oyuncudan emlak)/i.test(baslik.textContent)) return;
    var card = baslik.closest('.kart');
    if (!card) return;
    var btn = document.createElement('button');
    btn.className = 'btn altin yp-giris';
    btn.textContent = '🏘️ Belediyeden ve Oyunculardan Yatırımlık Arsa / Ev / Dükkân';
    btn.onclick = function () { ekranAc(window.yatirimPazarEkrani); };
    card.appendChild(btn);
  }
  function baslat() {
    var app = document.getElementById('app');
    if (!app) return;
    var scheduled = false;
    var observer = new MutationObserver(function () {
      if (scheduled) return;
      scheduled = true;
      requestAnimationFrame(function () { scheduled=false; observer.disconnect(); girisEkle(); observer.observe(app,{subtree:true,childList:true}); });
    });
    observer.observe(app,{subtree:true,childList:true});
    girisEkle();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded',baslat,{once:true});
  else baslat();
})();
