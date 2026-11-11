/* =====================================================================
   TASARIM v5 — "Devlet Salonu" (2026-11-11) — yalnız görünüm.
   Tasarım v4'ün ÜSTÜNE, en son yüklenir. v4 kabuğu (üst çubuk, alt menü,
   kurum kartları) sadeleştirmişti; v5 geri kalan dağınıklığı toplar:
     1) Emoji yerine tek tip çizgi ikon (başlık, düğme, karo, menü). Emoji
        Android ve iPhone'da farklı göründüğü için arayüz telefondan telefona
        değişiyordu. Sohbet, Kürsü, gazete gibi oyuncu yazılarına dokunulmaz.
     2) Bütün giriş alanları (sınıfsız select/input/textarea dahil) tek dilde;
        beyaz kalan açılır listeler koyu temaya alınır.
     3) Modüllerin kendi düğme/karo/rozet aileleri ortak ölçüye bağlanır.
     4) Bölüm başlıkları, anahtar-değer satırları, listeler, boş durumlar için
        tek ritim; rakamlar eş genişlikte.
     5) Ekran geçişi, pencere, düğme ve ilerleme çubuğu hareketleri. Otomatik
        tazelemede hareket OYNATILMAZ (yalnız oyuncu ekran değiştirince).
   Hiçbir RPC çağırmaz; oyun verisine, kurala, akışa, olay dinleyicisine
   dokunmaz. Geri almak için derle.js'teki tasarim_v5 satırlarını silmek yeter.
   Kapatma anahtarı: adres çubuğuna ?v5=kapali yazılırsa bu katman yüklenmez.
   ===================================================================== */
(function () {
  if (window.SO_TASARIM_V5) return; window.SO_TASARIM_V5 = true;
  try { if (/[?&]v5=kapali/.test(location.search)) return; } catch (e) {}

  var CSS = `
/* ---------- 0. Zemin: sistem denetimleri koyu, rakamlar hizalı ---------- */
html:root{color-scheme:dark;
  --v5-yuzey:linear-gradient(180deg,rgba(255,255,255,.028),rgba(255,255,255,0) 64px),var(--panel);
  --v5-altin:#D9B45B; --v5-altin2:#F1D48A; --v5-altinbg:rgba(217,180,91,.13);
  --v5-ease:cubic-bezier(.2,.8,.2,1)}
html body{-webkit-font-smoothing:antialiased;text-rendering:optimizeLegibility;-webkit-tap-highlight-color:transparent}
html body #app{background:
  radial-gradient(120% 220px at 50% -40px,rgba(110,86,248,.10),transparent 70%),
  linear-gradient(180deg,#0E1220 0,var(--bg) 260px)!important}
html body .kv .v,html body .sayac,html body .tablo td,html body .pa-veri b,html body .gosterge b,html body .para-cip{font-variant-numeric:tabular-nums}

/* ---------- 1. İkon (emoji yerine) ---------- */
.v5i{display:inline-grid;place-items:center;width:1.2em;height:1.2em;margin-right:.42em;vertical-align:-.22em;flex:none;color:inherit}
.v5i svg{width:100%;height:100%;display:block;fill:none;stroke:currentColor;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}
.v5i.tek{margin-right:0}
html body .kart h2>.v5i:first-child,html body .kart h3>.v5i:first-child,html body .bolum-bas h2>.v5i:first-child,html body .modal h3>.v5i:first-child,html body .so-kisa-bas b>.v5i:first-child{color:var(--ink2)}
html body .btn>.v5i:first-child{width:1.15em;height:1.15em;opacity:.95}
/* yalnız ikon taşıyan kutular (eski emoji yuvaları) */
html body .so-kisa-simge>.v5i.tek,html body .mg-ikon>.v5i.tek{width:22px;height:22px}

/* ---------- 2. Kartlar ---------- */
html body .kart,html body .olay,html body .yayin,html body .sonuc-sahne{background:var(--v5-yuzey)}
html body .kart .kart{background:var(--panel2)}
html body .kart.duz{background:none!important}
html body .kart h2,html body .kart h3{text-wrap:balance}
html body .kart>p.alt,html body .kart>.alt{text-wrap:pretty}
html body .alt{color:#9AA3BB}
html body .kucuk{color:#7C849D}

/* Bölüm başlığı: küçük, harf aralıklı etiket + altın çentik (her ekranda aynı ritim) */
html body .bolum-bas{margin:24px 2px 9px}
html body #icerik>.bolum-bas:first-child{margin-top:6px}
html body .bolum-bas h2{font-size:12.5px;font-weight:750;letter-spacing:.09em;text-transform:uppercase;color:var(--txt2);display:flex;align-items:center}
html body .bolum-bas h2::before{content:"";display:block!important;flex:none;width:3px;height:13px;margin-right:9px;border-radius:2px;background:var(--v5-altin)}
html body .bolum-bas h2 .v5i{display:none}
html body .bolum-bas .kucuk,html body .bolum-bas>span{font-size:12.5px;color:var(--faint)}

/* Anahtar-değer ve liste satırları */
html body .kv{gap:14px;align-items:baseline;border-color:var(--line)}
html body .kv .k{font-size:13.5px}
html body .kv .v{font-weight:650;color:var(--txt);text-align:right}
html body .liste-satir{border-color:var(--line)}
html body .kart>.liste-satir:first-child,html body .kart>.kv:first-of-type{padding-top:2px}
html body .kart>.liste-satir:last-child,html body .kart>.kv:last-child{padding-bottom:2px;border-bottom:0}

/* Boş durum: sakin, ortalı kutu */
html body .bos{font-size:14px;line-height:1.5;border-radius:14px}
html body .kart>.bos:only-child{padding:22px 12px}

/* ---------- 3. Düğmeler ---------- */
html body .btn{min-height:48px;font-weight:650;border:0;
  background:linear-gradient(180deg,#7A63FA,#6149F0);box-shadow:inset 0 1px 0 rgba(255,255,255,.18),0 6px 16px -10px rgba(97,73,240,.9)}
html body .btn.ikinci{background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line)}
html body .kart .btn.ikinci,html body .modal .btn.ikinci{background:var(--panel3);box-shadow:inset 0 1px 0 rgba(255,255,255,.05)}
html body .btn.altin{background:rgba(110,86,248,.07);box-shadow:inset 0 0 0 1.5px rgba(169,155,255,.30)}
html body .btn.tehlike{background:rgba(239,67,73,.06);box-shadow:inset 0 0 0 1.5px rgba(239,67,73,.36)}
html body .btn.canli{background:linear-gradient(180deg,#F4575C,#E23A40);box-shadow:inset 0 1px 0 rgba(255,255,255,.2)}
html body .btn.kucuk,html body .btn.ufak{min-height:38px;padding:8px 14px;font-size:14px;border-radius:12px}
html body .btn:disabled{background:var(--panel2);color:var(--faint);opacity:.75;box-shadow:inset 0 0 0 1px var(--line)}
html body .btn:focus-visible,html body button:focus-visible,html body a:focus-visible{outline:2px solid var(--ink2);outline-offset:2px}
/* modüllerin kendi düğmeleri: aynı köşe, aynı ağırlık */
html body .bmv-btn,html body .kr-btn,html body .cbtor-btn,html body .cbm-btn,html body .vit-dugme,html body .dv-dugme,html body .km-kucukbtn{border-radius:12px;font-weight:650;letter-spacing:-.05px}

/* ---------- 4. Giriş alanları: sınıfsız olanlar dahil ---------- */
:where(#app,.modal-arka,.modal,#paMenu) :where(select,textarea,input:not([type=checkbox]):not([type=radio]):not([type=range]):not([type=file]):not([type=color]):not([type=button]):not([type=submit])){
  background-color:rgba(255,255,255,.035);color:var(--txt);border:1px solid var(--line2);border-radius:13px;
  min-height:48px;padding:12px 14px;font:inherit;font-size:16px;max-width:100%;box-sizing:border-box}
:where(#app,.modal-arka,.modal,#paMenu) :where(select){-webkit-appearance:none;appearance:none;padding-right:38px;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23A9B1C8' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
  background-repeat:no-repeat;background-position:right 12px center;background-size:18px}
html body select{-webkit-appearance:none;appearance:none;color:var(--txt);
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23A9B1C8' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E")!important;
  background-repeat:no-repeat!important;background-position:right 12px center!important;background-size:18px!important;padding-right:38px}
html body select option,html body select optgroup{background:#161C2E;color:#F4F6FB}
html body input[type=checkbox],html body input[type=radio]{accent-color:var(--ink)}
html body input[type=range]{accent-color:var(--ink)}
html body ::placeholder{color:var(--faint);opacity:1}
html body .alan{margin-bottom:12px}
html body .alan label{font-size:13px;color:var(--txt2)}

/* ---------- 5. Rozet, hap sekme ---------- */
html body .rozet{border-radius:999px}
html body #icerik .segment>button{border-radius:999px}

/* ---------- 6. Kabuk: üst çubuk çizgisi, alt menü göstergesi ---------- */
html body .ust{position:relative}
html body .ust h1{min-width:0;flex:1 1 auto;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
html body .ust::after{content:"";position:absolute;left:0;right:0;bottom:-1px;height:1px;pointer-events:none;
  background:linear-gradient(90deg,transparent,rgba(217,180,91,.42) 18%,rgba(169,155,255,.34) 60%,transparent)}
html body nav.sekmeler.pa-nav>button{position:relative;transition:color .18s}
html body nav.sekmeler.pa-nav>button:not(.pa-orta)::before{content:"";position:absolute;top:0;left:50%;width:22px;height:3px;margin-left:-11px;border-radius:0 0 3px 3px;background:var(--ink2);transform:scaleX(0);transition:transform .22s var(--v5-ease)}
html body nav.sekmeler.pa-nav>button.aktif:not(.pa-orta)::before{transform:scaleX(1)}
html body nav.sekmeler.pa-nav>button .pa-ni{transition:transform .2s var(--v5-ease),background .2s}
html body nav.sekmeler.pa-nav>button:active .pa-ni{transform:scale(.9)}

/* ---------- 7. Kurum kartı ve hızlı işlemler ---------- */
html body .pa-hero{box-shadow:inset 0 1px 0 rgba(255,255,255,.14),inset 0 0 0 1px rgba(255,255,255,.08),0 18px 30px -26px var(--a1)!important}
html body .pa-hero .pa-ust b{text-wrap:balance}
html body .pa-hizli>button{min-height:78px;transition:transform .12s,background .15s}
html body .pa-hizli>button:active{transform:scale(.97)}
html body .pa-hizli b{font-size:12.5px;line-height:1.2}
/* dolu kumbara: yeşil parlama yerine sakin vurgu */
html body .pa-kumbara{box-shadow:inset 0 0 0 1px rgba(168,149,255,.20)!important;animation:none!important}
html body .pa-kumbara.dolu{box-shadow:inset 0 0 0 1px rgba(125,255,191,.30)!important}

/* Gündem kısa yol karoları: alt yazı kesilmez (iki satır) */
html body .so-kisa-kart{background:var(--v5-yuzey)!important;box-shadow:inset 0 0 0 1px var(--line)!important}
html body .so-kisa-metin small{white-space:normal!important;display:-webkit-box!important;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;text-overflow:clip!important;line-height:1.3}
html body .so-kisa-ok{font-size:0!important;align-self:center;width:7px;height:7px;border-right:2px solid var(--faint);border-top:2px solid var(--faint);transform:rotate(45deg);flex:none;margin-right:3px}
html body .so-kisa-bas b{font-size:12.5px;font-weight:750;letter-spacing:.09em;text-transform:uppercase;color:var(--txt2)}

/* Parti / kurum sayfası başlığı: amblem + ad + üç sayı tek kimlik kartı */
html body #icerik>.kart:has(>.amb+h3){text-align:center;padding-top:22px;
  background:radial-gradient(120% 90px at 50% 0,rgba(255,255,255,.07),transparent 70%),var(--panel)}
html body #icerik>.kart:has(>.amb+h3)>.amb{margin-left:auto;margin-right:auto;box-shadow:0 0 0 1px var(--line2),0 14px 26px -16px rgba(0,0,0,.9)}
html body #icerik>.kart:has(>.amb+h3)>h3{font-size:21px;margin-top:12px}
html body #icerik>.kart:has(>.amb+h3)>div:last-child:not(.alt){background:var(--panel2);border-radius:14px;padding:12px 6px;margin-top:14px}
html body #icerik>.kart:has(>.amb+h3)>div:last-child:not(.alt)>div+div{box-shadow:-1px 0 0 var(--line2)}
/* kart içinde etiketsiz açılır liste tam genişlik */
html body .kart>select{width:100%;margin:2px 0 10px}
/* Satır biçimli gezinme düğmeleri: sağ ok aynı */
html body .giris-satir{border-color:var(--line)}

/* ---------- 8. Pencere ---------- */
html body .modal{background:linear-gradient(180deg,#171D30,#121727 120px)}
html body .modal .tutamak{margin-bottom:14px}

/* ---------- 9. Hareket (yalnız oyuncu ekran değiştirince) ---------- */
@keyframes v5Gir{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
@keyframes v5Bar{from{transform:scaleX(0)}to{transform:scaleX(1)}}
@keyframes v5Isik{from{transform:translateX(-120%)}to{transform:translateX(220%)}}
html body #icerik.v5-gir>*{animation:v5Gir .34s var(--v5-ease) both}
html body #icerik.v5-gir>*:nth-child(2){animation-delay:.035s}
html body #icerik.v5-gir>*:nth-child(3){animation-delay:.07s}
html body #icerik.v5-gir>*:nth-child(4){animation-delay:.105s}
html body #icerik.v5-gir>*:nth-child(5){animation-delay:.14s}
html body #icerik.v5-gir>*:nth-child(6){animation-delay:.175s}
html body #icerik.v5-gir>*:nth-child(n+7){animation-delay:.21s}
html body #icerik.v5-gir .bar>i,html body #icerik.v5-gir .pa-kbar>i,html body #icerik.v5-gir .sonuc-satir .cubuk>i{transform-origin:left center;animation:v5Bar .7s .12s var(--v5-ease) both}
html body .kart,html body .so-kisa-kart,html body .giris-satir{transition:background .15s}
html body button.kart:active,html body .kart[onclick]:active,html body .liste-satir[onclick]:active,html body button.giris-satir:active{background:var(--panel2)}
@media (prefers-reduced-motion:reduce){
  html body #icerik.v5-gir>*,html body #icerik.v5-gir .bar>i,html body #icerik.v5-gir .pa-kbar>i{animation:none!important}
  html body *{scroll-behavior:auto!important}
}

/* ---------- 10. Dar ekran (320–360 px) ---------- */
@media (max-width:400px){
  html body .ust{gap:2px;padding-left:14px;padding-right:9px}
  html body .ust .ikon:not(.para-cip){width:31px}
  html body .ust .ikon svg{width:20px;height:20px}
  html body .ust .para-cip{font-size:13.5px;margin-right:0}
}
@media (max-width:360px){
  html body .kart{padding:14px 13px 13px}
  html body .pa-hizli b{font-size:11.5px}
}
`;

  function stilEkle() {
    var eski = document.getElementById('soTasarimV5'); if (eski) eski.remove();
    var st = document.createElement('style'); st.id = 'soTasarimV5'; st.textContent = CSS;
    /* v4 kendini <head>'in sonunda tutar; v5 çakışmamak için <body>'nin sonunda durur (belge sırasında daha sonra). */
    (document.body || document.documentElement).appendChild(st);
  }

  /* ---------- İkon geçişi ---------- */
  var IK = window.SO_V5_IKON || {};
  var anahtarlar = Object.keys(IK).sort(function (a, b) { return b.length - a.length; });
  var RE = anahtarlar.length ? new RegExp('^(\\s*)(' + anahtarlar.map(function (k) { return k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }).join('|') + ')\\uFE0F?[\\u00A0 ]*') : null;
  /* Oyuncunun yazdığı metinler ve kendi çizimini yapan sahneler: dokunma */
  var ATLA_SINIF = /(^|[\s_-])(mesaj|msg|balon|yorum|gonderi|post|slogan|pankart|afis|biyo|sohbet|kursu|kr|sh|krs|yy|rp-onizleme|rp-afis|gazete|makale|haber-metin|metin-govde|kullanici-metin|hh-sohbet|chat)([\s_-]|$)/i;
  var ETIKET = { BUTTON: 1, H1: 1, H2: 1, H3: 1, H4: 1, B: 1, STRONG: 1, SUMMARY: 1, A: 1, LABEL: 1, SPAN: 1, DIV: 1, SMALL: 1, EM: 1, I: 1, TH: 1, TD: 1, LI: 1, P: 1, LEGEND: 1, DT: 1, OPTION: 0 };

  function atlanir(el) {
    for (var e = el, n = 0; e && e !== document.body && n < 12; e = e.parentElement, n++) {
      var t = e.tagName;
      if (t === 'SCRIPT' || t === 'STYLE' || t === 'TEXTAREA' || t === 'INPUT' || t === 'SELECT' || t === 'OPTION' || t === 'svg' || t === 'SVG' || t === 'CANVAS' || t === 'PRE' || t === 'CODE') return true;
      if (e.isContentEditable) return true;
      if (e.hasAttribute && e.hasAttribute('data-v5-yok')) return true;
      var c = e.className; if (typeof c === 'string' && c && (c.indexOf('v5i') >= 0 || ATLA_SINIF.test(c))) return true;
      var id = e.id; if (id && ATLA_SINIF.test(id)) return true;
    }
    return false;
  }
  function metinIsle(tn) {
    var v = tn.nodeValue; if (!v || v.length < 1 || v.length > 400) return;
    var m = RE.exec(v); if (!m) return;
    var p = tn.parentNode; if (!p || p.nodeType !== 1 || !ETIKET[p.tagName]) return;
    var kalan = v.slice(m[0].length);
    /* Uzun paragrafın başındaki emoji anlatının parçasıdır; yalnız kısa etiketlerde ikonlaştır */
    if ((p.tagName === 'P' || p.tagName === 'DIV' || p.tagName === 'LI' || p.tagName === 'TD') && kalan.length > 90) return;
    if (atlanir(p)) return;
    var svg = IK[m[2]]; if (!svg) return;
    var s = document.createElement('span'); s.className = 'v5i' + (kalan.trim() || p.childNodes.length > 1 ? '' : ' tek'); s.setAttribute('aria-hidden', 'true');
    s.innerHTML = '<svg viewBox="0 0 24 24">' + svg + '</svg>';
    p.insertBefore(s, tn); tn.nodeValue = (m[1] || '') + kalan;
  }
  function agacIsle(kok) {
    if (!RE || !kok) return;
    if (kok.nodeType === 3) { metinIsle(kok); return; }
    if (kok.nodeType !== 1) return;
    var w = document.createTreeWalker(kok, NodeFilter.SHOW_TEXT, null), dugumler = [], n;
    while ((n = w.nextNode())) { if (n.nodeValue && n.nodeValue.length < 400 && RE.test(n.nodeValue)) dugumler.push(n); }
    for (var i = 0; i < dugumler.length; i++) { try { metinIsle(dugumler[i]); } catch (e) {} }
  }

  /* ---------- Ekran girişi hareketi ---------- */
  var sonAnahtar = null, girZaman = null;
  function ekranAnahtari() {
    var h = document.querySelector('#app>.ust h1, #app>header h1');
    var d = (typeof D === 'object' && D) ? (D.sekme + '|' + (D._ekranNo || 0) + '|' + ((D.yigin && D.yigin.length) || 0)) : '';
    return d + '|' + (h ? h.textContent : '');
  }
  function girisKontrol() {
    var ic = document.getElementById('icerik'); if (!ic) return;
    var a = ekranAnahtari();
    if (a === sonAnahtar) return;
    var ilk = sonAnahtar === null; sonAnahtar = a;
    if (ic.querySelector(':scope>.yukleniyor')) { sonAnahtar = a + '|yuk'; return; }   // veri gelince bir kez oynat
    try { if (!ilk && typeof window.SO_OTOMATIK === 'function' && window.SO_OTOMATIK()) return; } catch (e) {}
    ic.classList.add('v5-gir'); clearTimeout(girZaman);
    girZaman = setTimeout(function () { var x = document.getElementById('icerik'); if (x) x.classList.remove('v5-gir'); }, 700);
  }

  /* Ekran adı üst çubuğa sığmıyorsa kesmek yerine yazıyı kademeli küçült (en az 16 px) */
  function baslikSigdir() {
    var h = document.querySelector('#app>.ust h1, #app>header h1'); if (!h || h._v5m === h.textContent + '|' + h.clientWidth) return;
    h.style.fontSize = '';
    var px = parseFloat(getComputedStyle(h).fontSize) || 23, n = 0;
    while (h.scrollWidth > h.clientWidth + 1 && px > 16 && n < 10) { px -= 1; h.style.setProperty('font-size', px + 'px', 'important'); n++; }
    h._v5m = h.textContent + '|' + h.clientWidth;
  }

  /* ---------- Gözlemci: yeni çizilen her şeyi bir kare içinde işle ---------- */
  var kuyruk = [], planli = false;
  function bosalt() {
    planli = false; var l = kuyruk; kuyruk = [];
    for (var i = 0; i < l.length; i++) { var n = l[i]; if (n && n.isConnected) agacIsle(n); }
    try { girisKontrol(); } catch (e) {}
    try { baslikSigdir(); clearTimeout(bosalt._t); bosalt._t = setTimeout(function () { try { baslikSigdir(); } catch (e) {} }, 500); } catch (e) {}
    try { var st = document.getElementById('soTasarimV5'); if (st && st.nextElementSibling && document.body.querySelector('#soTasarimV5~style')) document.body.appendChild(st); } catch (e) {}
  }
  function basla() {
    stilEkle();
    try { agacIsle(document.body); girisKontrol(); baslikSigdir(); } catch (e) {}
    window.addEventListener('resize', function () { try { baslikSigdir(); } catch (e) {} });
    try {
      new MutationObserver(function (kayitlar) {
        for (var i = 0; i < kayitlar.length; i++) {
          var k = kayitlar[i];
          if (k.type === 'characterData') { if (k.target.parentNode && !(k.target.parentNode.className && String(k.target.parentNode.className).indexOf('v5i') >= 0)) kuyruk.push(k.target); continue; }
          for (var j = 0; j < k.addedNodes.length; j++) {
            var n = k.addedNodes[j];
            if (n.nodeType === 1) { if (n.id === 'soTasarimV5' || (n.className && typeof n.className === 'string' && n.className.indexOf('v5i') >= 0)) continue; kuyruk.push(n); }
            else if (n.nodeType === 3) kuyruk.push(n);
          }
        }
        if (kuyruk.length > 400) kuyruk = [document.body];
        if (kuyruk.length && !planli) { planli = true; (window.requestAnimationFrame || setTimeout)(bosalt); }
      }).observe(document.body, { childList: true, subtree: true, characterData: true });
    } catch (e) {}
  }
  if (document.body) basla(); else document.addEventListener('DOMContentLoaded', basla);
  window.SO_V5 = { ikonla: agacIsle, surum: '2026.11.11' };
})();
