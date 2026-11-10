/* =====================================================================
   TASARIM v4 — "Gece yayını" (2026-11-10) — yalnız görünüm.
   Önceki katmanların (görünüm cilası, premium arayüz, premium ekonomi,
   sohbet tasarımı) üstüne EN SON yüklenir ve hepsini tek dile bağlar:
   · mor ışıltı / parlama / kenarlık kalabalığı yerine düz, sakin yüzeyler
   · tek vurgu rengi (tercih mührü moru), devlet altını, canlı kırmızısı
   · kart başlıklarında sistem yazı tipi; dar başlık fontu yalnız büyük
     rakamlarda ve ekran adında
   · tek düğme ailesi, tek sekme (hap) dili, tek giriş alanı dili
   Hiçbir RPC çağırmaz, oyun verisine, kurala ya da akışa dokunmaz.
   Geri almak için: derle.js'teki tasarim_v4.js satırını silmek yeterli.
   ===================================================================== */
(function () {
  if (window.SO_TASARIM_V4) return; window.SO_TASARIM_V4 = true;

  var CSS = `
/* ---------- 1. Renk ve ölçü sistemi ---------- */
html:root{
  --bg:#090C16; --bg2:#06080F; --panel:#121726; --panel2:#1A2033; --panel3:#273049;
  --panelUst:#121726;
  --line:rgba(255,255,255,.07); --line2:rgba(255,255,255,.13);
  --kenar:rgba(255,255,255,.07); --kenar2:rgba(255,255,255,.13);
  --txt:#F4F6FB; --txt2:#C6CCDC; --mut:#919AB2; --faint:#6A728B;
  --ink:#6E56F8; --ink2:#A99BFF; --inkbg:rgba(110,86,248,.15);
  --al:#EF4349; --al2:#FF7A7F; --albg:rgba(239,67,73,.14);
  --good:#2FC389; --warn:#EDB548;
  --golge:none;
  --r:18px; --rBtn:14px;
  --pa-glow:transparent;
  --sh-grad:linear-gradient(135deg,#6E56F8,#6E56F8);
  --sh-yuzey:#121726; --sh-cizgi:rgba(255,255,255,.08); --sh-mor:#7C66FA; --sh-pembe:#6E56F8; --sh-soluk:#919AB2;
  --t4-govde:-apple-system,BlinkMacSystemFont,"SF Pro Text","Inter",Roboto,"Segoe UI",system-ui,sans-serif;
}
html,body{background:var(--bg)!important}
body{font-family:var(--t4-govde);letter-spacing:0}
*{scrollbar-width:thin;scrollbar-color:var(--panel3) transparent}
::selection{background:rgba(110,86,248,.45);color:#fff}

/* ---------- 2. Zemin ve kabuk ---------- */
html body #app{background:linear-gradient(180deg,#0E1220 0,var(--bg) 260px)!important}
html body .icerik{padding-left:16px;padding-right:16px}

/* Üst çubuk: tek satır, hayalet ikonlar, ekran adı kesilmez */
html body .ust{background:rgba(9,12,22,.84)!important;-webkit-backdrop-filter:saturate(140%) blur(18px);backdrop-filter:saturate(140%) blur(18px);
  border-bottom:1px solid var(--line)!important;box-shadow:none!important;gap:4px;padding-left:16px;padding-right:12px}
html body .ust h1{font-size:25px!important;letter-spacing:-.2px!important;font-weight:700}
html body .ust .ikon:not(.para-cip),html body .ust .geri{width:36px;height:36px;border-radius:12px;background:transparent!important;box-shadow:none!important;color:var(--txt2);transition:background .15s}
html body .ust .geri{background:var(--panel2)!important;color:var(--txt);margin-right:6px}
html body .ust .ikon:active,html body .ust .geri:active{background:var(--panel3)!important}
html body .ust .ikon svg{width:21px;height:21px}
html body .ust .para-cip{width:auto;height:34px;margin-right:2px;border-radius:999px;background:var(--panel2)!important;box-shadow:inset 0 0 0 1px var(--line2)!important;color:var(--txt)!important;font-size:15.5px;letter-spacing:.1px}
html body .ust .ikon.portre-ikon{margin-left:4px}
html body .ust .sayi{border-color:var(--bg)}
@media (max-width:400px){html body .ust h1{font-size:23px!important}html body .ust .ikon:not(.para-cip){width:33px}html body .ust .para-cip{font-size:14.5px}}

/* Alt menü: düz çubuk, renkli parlama yok */
html body nav.sekmeler.pa-nav,html body .sekmeler{background:rgba(7,9,17,.92)!important;-webkit-backdrop-filter:saturate(140%) blur(20px);backdrop-filter:saturate(140%) blur(20px);
  border-top:1px solid var(--line)!important;box-shadow:none!important}
html body nav.sekmeler.pa-nav>button{color:var(--faint);font-weight:600;font-size:11px;gap:3px}
html body nav.sekmeler.pa-nav>button.aktif{color:var(--txt)}
html body nav.sekmeler.pa-nav>button.aktif .pa-ni{background:var(--inkbg);box-shadow:none;color:var(--ink2)}
html body nav.sekmeler.pa-nav>button.pa-orta .pa-ni{width:52px;height:52px;margin-top:-21px;border-radius:18px;color:#fff;
  background:var(--pa-o1,var(--ink))!important;box-shadow:0 0 0 5px rgba(7,9,17,.96),0 8px 18px -10px rgba(0,0,0,.9)!important}
html body nav.sekmeler.pa-nav>button.pa-orta .pa-nl{color:var(--txt2)}
html body nav.sekmeler.pa-nav .sayi,html body nav.sekmeler.pa-nav .pa-nokta{border-color:#070911!important}
html body .sekmeler button.aktif svg{color:var(--ink2)}

/* ---------- 3. Kartlar ve başlıklar ---------- */
html body .kart,html body .olay,html body .yayin,html body .kisisel,html body .sonuc-sahne{
  background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);border-radius:var(--r)}
html body .kart{padding:16px 16px 15px;margin-bottom:12px}
html body .kart.duz{background:none!important;box-shadow:none!important;padding:4px 0 0}
html body .kart .kart{background:var(--panel2);box-shadow:none}
html body .kart h2{font-family:var(--t4-govde);font-size:17px;font-weight:700;letter-spacing:-.2px;line-height:1.25;margin-bottom:8px}
html body .kart h3{font-family:var(--t4-govde);font-size:18px;font-weight:700;letter-spacing:-.25px;line-height:1.25}
html body .olay{border-left:0;position:relative;overflow:hidden;padding-left:19px}
html body .olay::before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--panel3)}
html body .olay.oy{background:var(--panel)}
html body .olay.oy::before{background:var(--al)}
html body .olay.basvuru::before{background:var(--ink)}
html body .olay .baslik b{font-family:var(--t4-govde);font-size:17px;letter-spacing:-.2px}
html body .kart.cizgili{border-left:0;border-radius:var(--r);box-shadow:inset 4px 0 0 var(--parti,var(--ink)),inset 0 0 0 1px var(--line)}
html body .yayin{border-left:0;box-shadow:inset 3px 0 0 var(--ink),inset 0 0 0 1px var(--line);padding:13px 14px 12px 16px}
html body .yayin.yeni{background:var(--panel2)}
html body .kisisel{padding:13px 14px;border-radius:14px}
html body .alt{color:var(--mut);font-size:13.5px;line-height:1.5}
html body .kucuk{color:var(--faint)}
html body .bolum-bas{margin:26px 2px 10px;align-items:center}
html body .bolum-bas h2{font-family:var(--t4-govde);font-size:18px;font-weight:700;letter-spacing:-.25px;gap:0}
html body .bolum-bas h2::before{display:none}
html body .bolum-bas a,html body .bolum-bas button{color:var(--ink2);font-weight:600}
html body .modal h3{font-family:var(--t4-govde);font-size:20px!important;letter-spacing:-.3px;margin-bottom:4px}
html body .metin h4{font-family:var(--t4-govde);font-size:16px;letter-spacing:-.15px}

/* ---------- 4. Düğme ailesi ---------- */
html body .btn{min-height:50px;padding:13px 18px;border-radius:var(--rBtn);font-weight:650;font-size:15.5px;letter-spacing:-.05px;
  background:var(--ink);color:#fff;box-shadow:none;text-shadow:none;transition:transform .08s,filter .15s,background .15s}
html body .btn:active{transform:scale(.985);filter:brightness(.92)}
html body .btn.ikinci{background:var(--panel2);color:var(--txt);box-shadow:none}
html body .kart .btn.ikinci,html body .modal .btn.ikinci{background:var(--panel3)}
html body .btn.altin{background:transparent;color:var(--ink2);box-shadow:inset 0 0 0 1.5px rgba(169,155,255,.34)}
html body .btn.altin:active{background:var(--inkbg)}
html body .btn.tehlike{background:transparent;color:var(--al2);box-shadow:inset 0 0 0 1.5px rgba(239,67,73,.38)}
html body .btn.tehlike:active{background:var(--albg)}
html body .btn.canli{background:var(--al);box-shadow:none}
html body .btn:disabled{opacity:.4;box-shadow:none}
html body .btn.altin:disabled,html body .btn.tehlike:disabled{box-shadow:inset 0 0 0 1.5px var(--line2)}
/* tek düğmelik kartlar ve yönetim satırları: düz "satır" görünümü */
html body #icerik>.kart>.btn.altin:only-child,html body #icerik>.kart>.btn.ikinci:only-child{
  background:var(--panel)!important;box-shadow:inset 0 0 0 1px var(--line)!important;color:var(--txt);border-radius:16px;font-weight:600}
html body #icerik .ynt-bolum>.btn{background:var(--panel2)!important;box-shadow:none!important;color:var(--txt);font-weight:600}
html body #icerik .ynt-bolum>.btn.altin:first-of-type{background:var(--inkbg)!important;box-shadow:inset 0 0 0 1px rgba(169,155,255,.28)!important;color:#fff}

/* ---------- 5. Giriş alanları ---------- */
html body .alan label{color:var(--mut);font-size:12.5px;font-weight:600;letter-spacing:.1px;margin-bottom:6px}
html body .alan input,html body .alan select,html body textarea,html body textarea.alanmetin,html body .payinput input{
  background:rgba(255,255,255,.035);border:1px solid var(--line2);border-radius:13px;box-shadow:none;transition:border-color .15s,box-shadow .15s,background .15s}
html body .alan input,html body .alan select{min-height:50px;padding:13px 14px}
html body .alan input::placeholder,html body textarea::placeholder{color:var(--faint)}
html body .alan input:focus,html body .alan select:focus,html body textarea:focus{border-color:var(--ink2);background:rgba(110,86,248,.06);box-shadow:0 0 0 4px rgba(110,86,248,.16)}
html body .onay input{width:22px;height:22px;border-radius:6px}

/* ---------- 6. Hap sekmeler, rozetler, satırlar ---------- */
html body #icerik .segment>button{padding:8px 15px!important;background:transparent!important;box-shadow:inset 0 0 0 1px var(--line2)!important;color:var(--txt2)!important;font-weight:600;font-size:13.5px}
html body #icerik .segment>button.aktif{background:var(--txt)!important;color:#0B0E19!important;box-shadow:none!important}
html body .modal .segment{background:var(--bg);box-shadow:none;border-radius:12px;padding:3px}
html body .modal .segment button.aktif{background:var(--panel3);box-shadow:none}
html body .rozet{border-radius:6px;padding:3px 8px;font-weight:650;font-size:11.5px;letter-spacing:.1px;background:var(--panel3);color:var(--txt2)}
html body .rozet.kirmizi{background:var(--albg);color:var(--al2)}
html body .rozet.yesil{background:rgba(47,195,137,.14);color:var(--good)}
html body .rozet.altin{background:var(--inkbg);color:var(--ink2)}
html body .rozet.sari{background:rgba(237,181,72,.14);color:var(--warn)}
html body .durum{border-radius:6px;font-weight:650}
html body .kv{padding:11px 0;font-size:14px}
html body .kv .k{color:var(--mut)}
html body .liste-satir{padding:12px 0}
html body .amb{border-radius:12px}
html body .giris-satir .yik,html body .ms-yik{background:var(--inkbg)!important;box-shadow:none!important}
html body .bar,html body .sonuc-satir .cubuk{border-radius:999px;background:var(--panel3)}
html body .bar i,html body .sonuc-satir .cubuk i{border-radius:999px}
html body .gosterge{background:var(--line);border-radius:14px;box-shadow:inset 0 0 0 1px var(--line)}
html body .gosterge>div{background:var(--panel)}
html body .takvim-satir .gun{background:var(--panel2);border-radius:10px}
html body .secenek{background:var(--panel2);border-radius:13px;border-width:1.5px}
html body .secenek.secili{border-color:var(--ink2);background:var(--inkbg)}
html body .oybtn button{border-radius:13px;background:var(--panel2)}
html body .tablo th{font-size:12px;letter-spacing:.1px}
html body .bos{color:var(--faint);padding:26px 12px}
html body .yukleniyor::before{border-width:2.5px;border-color:var(--panel3);border-top-color:var(--ink2)}

/* ---------- 7. Pencereler ve bildirim ---------- */
html body .modal-arka{background:rgba(3,5,12,.72);-webkit-backdrop-filter:blur(6px);backdrop-filter:blur(6px)}
html body .modal{background:#131828;border-radius:26px 26px 0 0;box-shadow:0 -1px 0 var(--line2),0 -24px 60px -20px rgba(0,0,0,.8);padding:10px 18px calc(var(--safeB) + 18px)}
html body .modal .tutamak{width:38px;height:4px;background:var(--line2);margin:2px auto 16px}
html body .toast{left:14px;right:14px;background:#1E2538;border:0;border-left:0;border-radius:15px;padding:13px 15px 13px 40px;font-weight:600;
  box-shadow:inset 0 0 0 1px var(--line2),0 18px 40px -14px rgba(0,0,0,.85)}
html body .toast::before{content:"";position:absolute;left:15px;top:50%;width:12px;height:12px;margin-top:-6px;border-radius:50%;background:var(--good);box-shadow:0 0 0 4px rgba(47,195,137,.18)}
html body .toast.hata{background:#2A1A22}
html body .toast.hata::before{background:var(--al);box-shadow:0 0 0 4px rgba(239,67,73,.2)}

/* ---------- 8. Bölüm kartı (kurum kartı) ve hızlı işlemler ---------- */
html body .pa-hero{border-radius:22px;padding:18px 18px 17px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.10)!important;
  background:linear-gradient(140deg,color-mix(in srgb,var(--a1) 82%,#090C16) 0%,color-mix(in srgb,var(--a2) 62%,#090C16) 88%)}
html body .pa-hero::after{background:linear-gradient(180deg,rgba(255,255,255,.08),transparent 46%)}
html body .pa-hero::before{opacity:.16}
html body .pa-hero .pa-ust small{font-weight:600;letter-spacing:.2px;color:rgba(255,255,255,.78)}
html body .pa-hero .pa-veri>div{background:rgba(4,6,14,.26);box-shadow:none;border-radius:12px}
html body .pa-hero .pa-cip{background:rgba(4,6,14,.28);box-shadow:none}
html body .pa-hizli{gap:8px;margin-bottom:18px}
html body .pa-hizli>button{background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);border-radius:16px;padding:13px 4px 11px}
html body .pa-hizli>button:active{background:var(--panel2)}
html body .pa-hizli .pa-hi{box-shadow:none;border-radius:12px}
html body .pa-hizli>button.ana .pa-hi{box-shadow:none}
html body .pa-hizli b{font-weight:600;color:var(--txt)}

/* ---------- 9. "Tüm bölümler" çekmecesi ---------- */
html body #paMenu .pa-perde{background:rgba(3,5,12,.72)}
html body #paMenu .pa-cekmece{background:#10141F!important;border-radius:26px 26px 0 0;box-shadow:0 -1px 0 var(--line2)}
html body #paMenu .pa-cb h2{font:700 21px/1.2 var(--t4-govde);letter-spacing:-.35px}
html body #paMenu .pa-kapat{background:var(--panel2);box-shadow:none;border-radius:12px}
html body #paMenu .pa-kim{background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line);border-radius:18px}
html body #paMenu .pa-kim::before{display:none}
html body #paMenu .pa-kim b{font:700 17px/1.2 var(--t4-govde);letter-spacing:-.2px}
html body #paMenu .pa-kim .pa-cz{background:rgba(255,255,255,.07)}
html body #paMenu .pa-ara{background:rgba(255,255,255,.035);box-shadow:inset 0 0 0 1px var(--line2);border-radius:14px}
html body #paMenu .pa-grup>h3{font-size:12px;font-weight:650;letter-spacing:.3px;color:var(--faint)}
html body #paMenu .pa-karo{background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);border-radius:16px}
html body #paMenu .pa-karo::after{display:none}
html body #paMenu .pa-karo:active{background:var(--panel2)}
html body #paMenu .pa-karo.aktif{box-shadow:inset 0 0 0 1.5px var(--k1)}
html body #paMenu .pa-karo .pa-ki{box-shadow:none;border-radius:12px}
html body #paMenu .pa-karo b{font-weight:650;letter-spacing:-.1px}
html body #paMenu .pa-karo small{color:var(--mut)}
html body #paMenu .pa-karo.pa-karo-genis{background:var(--panel2)!important;box-shadow:inset 0 0 0 1px var(--line2)}
html body #paMenu .pa-karo.pa-karo-genis small{color:var(--mut)!important}
html body #paMenu .pa-ara-satir{background:var(--panel);box-shadow:inset 0 0 0 1px var(--line)}
html body #paMenu .pa-ara-ik{box-shadow:none}

/* ---------- 10. Ekonomi ekranları: yeşil/mor karışımı yerine aynı yüzeyler ---------- */
html body .so-ekonomi .so-tabs,html body #icerik .so-ekonomi .so-tabs{background:var(--bg)!important;box-shadow:none!important;border:0!important;border-radius:0!important;padding:8px 0 12px!important}
html body .so-ekonomi .so-tabs button{background:var(--panel)!important;border:0!important;box-shadow:inset 0 0 0 1px var(--line)!important;border-radius:16px!important}
html body .so-ekonomi .so-tabs button[aria-selected="true"],html body .so-ekonomi .so-tabs button[aria-selected=true]{background:var(--panel2)!important;color:#fff!important;box-shadow:inset 0 0 0 1.5px var(--ink2)!important}
html body .so-ekonomi .so-econ-tile,html body .so-ekonomi .so-econ-kpi,html body .so-ekonomi .so-company,html body .so-ekonomi .so-econ-more,
html body .pep-stat,html body #icerik.pep-economy-child .kart{
  background:var(--panel)!important;border:0!important;box-shadow:inset 0 0 0 1px var(--line)!important;border-radius:18px!important}
html body .so-ekonomi .so-econ-tile.featured,html body .so-ekonomi .so-econ-kpi.accent{background:var(--panel2)!important;box-shadow:inset 0 0 0 1px rgba(128,228,200,.32)!important}
html body .so-ekonomi .so-econ-tile b,html body .pep-title h3,html body .so-ekonomi .so-econ-section-head h3,html body #icerik.pep-economy-child .kart h2,html body #icerik.pep-economy-child .kart h3{font-weight:700!important}
html body .so-ekonomi .so-econ-tile .so-econ-tile-icon{background:var(--panel3)!important}
html body .so-ekonomi .so-econ-banner,html body .pep-hero{border-radius:22px!important;box-shadow:inset 0 0 0 1px rgba(255,255,255,.09)!important}
html body .pep-hero h2,html body .so-ekonomi .so-econ-banner h2{font-weight:750!important}
html body .pep-stat strong{font-weight:750}
html body #icerik.pep-economy-child .segment{background:none}

/* ---------- 10b. Sohbet: pembe-mor geçiş ve parlama yok ---------- */
html body .sh-btn.ana,html body .sh-fab,html body .sh-h-yeni .sh-h-ic,html body .sh-logo{box-shadow:none!important}
html body .sh-seg-kay{background:var(--panel3)!important;box-shadow:none!important}
html body .sh-seg button.on .sh-say{color:var(--ink)}
html body .sh-fab{box-shadow:0 10px 24px -12px rgba(0,0,0,.9)!important}
html body .sh-h.halka .sh-h-hal{background:conic-gradient(from 210deg,#6E56F8,#A99BFF,#EDB548,#6E56F8)}

/* ---------- 11. Karşılama ---------- */
html body .karsila{background:none}
html body .karsila h1{letter-spacing:-.6px}
html body .karsila p.giris{color:var(--txt2);line-height:1.55}
html body .logo{border-width:3px}

/* ---------- 12. Geniş ekran (PC): ortalanmış, okunur sütun ---------- */
@media (min-width:900px){
  html body .icerik>*{max-width:760px;margin-left:auto!important;margin-right:auto!important}
  html body .modal-arka{align-items:center;justify-content:center}
  html body .modal{max-width:560px;border-radius:24px;max-height:84vh}
  html body .modal .tutamak{display:none}
  html body .toast{left:50%;right:auto;transform:translateX(-50%);min-width:320px;max-width:520px}
  html body #paMenu .pa-cekmece{max-width:760px;margin:0 auto;width:100%}
}
`;

  function ekle() {
    var eski = document.getElementById('soTasarimV4'); if (eski) eski.remove();
    var st = document.createElement('style'); st.id = 'soTasarimV4'; st.textContent = CSS;
    (document.head || document.documentElement).appendChild(st);
  }
  ekle();
  /* Sonradan <head>'e stil ekleyen modüller olursa bu katman yine en sonda kalsın. */
  try {
    var bekle = null;
    new MutationObserver(function () {
      var st = document.getElementById('soTasarimV4');
      if (!st || document.head.lastElementChild === st) return;
      clearTimeout(bekle); bekle = setTimeout(function () { var s = document.getElementById('soTasarimV4'); if (s && document.head.lastElementChild !== s) document.head.appendChild(s); }, 60);
    }).observe(document.head, { childList: true });
  } catch (e) {}
})();
