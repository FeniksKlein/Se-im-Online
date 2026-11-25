/* 26.11.2026 · YENİ OYUNCU REHBERİ (onboarding) — sürüm 2026.11.26-3
   Oyuncu önerisi (Yönetime Yaz): "İlk giren oyuncu için oyun aşırı karışık. Her şeyi görüyor ama hiçbir şey bilmiyor."
   Bu modül hiçbir özelliği gizlemez ya da kilitlemez; yalnız anlatır:
     1) Karşılama: 4 kartlık kısa tanıtım (atlanabilir). Metinler sunucudan gelir (Süper Yönetici Portalı'ndan değişir),
        gelmezse aşağıdaki varsayılanlar kullanılır. Yalnız rehber açıldıktan SONRA kayıt olan hesaplarda kendiliğinden açılır.
     2) İlk Adımlar 2.0: Gündem'deki kart (ilkAdimlarHtml'in yerine geçer) — her adımın nedeni, "Git" düğmesi,
        ilerleme çubuğu ve çekirdek adımlar bitince tek seferlik başlangıç ödülü (rehber_odul_al).
     3) Ekran ipuçları: her ana sekmede başlığın yanında "?" düğmesi; yeni hesaplarda sekmeye ilk girişte bir kez kendiliğinden açılır.
        Kapatılan ipuçları hesapta tutulur (rehber_isaretle) — telefon değişse de tekrar çıkmaz.
     4) "Yeni" rozeti: sohbet_tasarim.js (sohbet_oku.yeni) ve oyuncu kartı (index.html, katılım tarihi) içinde.
   Yük: yeni RPC okuması yok. Durum Gündem'in zaten çağırdığı ilk_adimlar'dan (60 sn önbellek) alınır; oturum başında bir kez okunur.
   Yazma yalnız oyuncu bir şeyi kapattığında / ödülü aldığında olur. */
(function () {
  "use strict";
  if (window.REHBER) return;
  var esc = function (x) { return typeof e === "function" ? e(String(x == null ? "" : x)) : String(x == null ? "" : x).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); };
  var hc = function (m) { return typeof hataCevir === "function" ? hataCevir(m) : m; };
  var tl = function (n) { try { return Math.round(+n || 0).toLocaleString("tr-TR") + " ₺"; } catch (_) { return (+n || 0) + " ₺"; } };
  var Dx = function () { return typeof D !== "undefined" ? D : null; };
  var fn = function (ad) { var f = window[ad]; return typeof f === "function" ? f : null; };

  var R = { ia: null, iaZaman: 0, okunuyor: null, gosterilen: {}, karsilamaAcik: false, yerel: {} };
  try { R.yerel = JSON.parse(localStorage.getItem("rhYerel") || "{}") || {}; } catch (_) { R.yerel = {}; }
  function yerelYaz() { try { localStorage.setItem("rhYerel", JSON.stringify(R.yerel)); } catch (_) {} }

  /* ------------------------------------------------------------------ Metinler */
  var KARSILAMA = [
    ["Türkiye'yi oyuncular yönetiyor", "Burada bot yok. Cumhurbaşkanından belediye başkanına, vekilden bakana kadar her makamda gerçek bir oyuncu oturuyor. Sen de o koltuklardan birine aday olabilirsin."],
    ["Para ve kıdem nasıl kazanılır?", "Her gün maaşını topla (+1 kıdem), günde 5 ek iş yap, mitinglere katıl, oyunu kullan. Kıdem arttıkça maaşın yükselir; parti ve şirket kurma, adaylık hakları açılır."],
    ["Her ay seçim var", "Belediye seçimi, kurultay ve genel seçim her ay döner. Önce adaylık başvurusu, sonra ön seçim, sonra sandık. Takvimi Gündem'in en üstünde görürsün."],
    ["İlk hedefin", "Gündem'deki \"İlk adımların\" listesini bitir: maaşını topla, kendini tanıt, bir partiye katıl. Hepsini bitirince başlangıç ödülün cüzdanına yatar. Takıldığın her ekranda başlığın yanındaki ? düğmesine bas."]
  ];
  var KART_IKON = [
    '<path d="M4 11h16v9H4zM8 11V4h8v7M10 7h4"/>',
    '<rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10.5h18M16.5 15h1.5M7 6V5a2 2 0 0 1 2-2h8"/>',
    '<rect x="3" y="4" width="18" height="17" rx="3"/><path d="M8 2v4M16 2v4M3 10h18M8 14h3M8 17h6"/>',
    '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'
  ];
  var IPUCU = {
    gundem: ["Gündem — oyunun ana sayfası", "En üstte bu ayın seçim takvimi ve sıradaki aşamanın geri sayımı var. \"Bugün\" bölümü yapman gereken işleri sıralar: maaş, başvurular, oylamalar. Haberler, mitingler ve İlk adımların kartı da burada."],
    devlet: ["Devlet", "Cumhurbaşkanı, kabine, bakanlıklar, kanunlar ve kararnameler burada. Bir makamın varsa (bakan, belediye başkanı, vali…) işlemlerini buradaki Yönetim bölümünden yaparsın."],
    yonetim: ["Yönetim", "Sahip olduğun makamın (belediye, bakanlık, Cumhurbaşkanlığı…) bütün işlemleri burada toplanır. Makamın yoksa burası boş görünür; seçim kazanınca ya da atanınca dolar."],
    adliye: ["Adliye", "Davalar, mahkemeler, istinaf, baro ve avukatlar. Hakkının yendiğini düşünüyorsan dava açabilirsin; dava açmak ve savunma yapmak için avukat tutman gerekir. Gözaltı ve ifade çağrıları da buradan izlenir."],
    hayat: ["Hayat — cüzdanın ve günlük işlerin", "Maaşını buradan toplarsın; her gün topladığında +1 kıdem kazanırsın. Ek işler, mülklerin, banka hesapların ve harcamaların burada. Kıdem arttıkça maaşın ve hakların artar."],
    ekonomi: ["Ekonomi", "Şirket kur, dükkân aç, hisse ve döviz al, ilanlara ve müzayedeye katıl. Şirket kurmak için yeterli kıdem ve sermaye gerekir; önce ek işlerle ve maaşla para biriktir."],
    sohbet: ["Sohbet", "İl kahvesi ilindeki oyuncularla, meydan bütün Türkiye ile konuşma yeri. Partinin kanalı, özel mesajların ve kurduğun gruplar da burada. Bir sorun ya da sorun varsa Yardım Masası'na yaz."],
    meclis: ["Meclis", "TBMM'nin sandalye dağılımı, Meclis Başkanı ve il il milletvekilleri. Vekilsen kanun teklifi verir, Genel Kurul'da oy kullanırsın; vekil değilsen oturumları canlı izleyebilirsin."],
    harita: ["Harita", "81 ilin belediye başkanları, oy dağılımı ve oyuncu sayıları. Bir ile dokunarak ayrıntısını gör. İlini değiştirmeyi düşünüyorsan rekabetin az olduğu illere bak."],
    parti: ["Partiler", "Partileri, ideolojilerini ve üye sayılarını incele, sana yakın olana katıl. Üyeler kurultayda genel başkanı seçer, ön seçimde aday sıralamasını belirler. Partini sonradan değiştirebilirsin."],
    dernek: ["Dernekler", "Bir derneğe üye ol ya da kendi derneğini kur. Dernekler basın açıklaması yapar, protesto düzenler, bağış toplar, il il şube açar ve aday ya da partilere destek verir."],
    ben: ["Profilin", "Portren, biyografin, kıdemin, rozetlerin ve ayarların. Diğer oyuncular seni bu bilgilerle tanır; portre ve biyografi ilk oy hakkın için de gerekir."]
  };
  var GIT = {
    maas: function () { sekme("hayat"); },
    kimlik: function () { var f = fn("portreModal"); if (f) f(); else sekme("ben"); },
    sohbet: function () {
      var st = window.sohbetTasarim, k = st && typeof st.kanal === "function" ? st.kanal : fn("kanalEkrani"), ac = fn("ekranAc");
      if (k && ac) { sekme("sohbet"); ac(function () { return k("il"); }); } else sekme("sohbet");
    },
    parti: function () { sekme("parti"); },
    ek_is: function () { var f = fn("ekIsAc"); if (f) f(); else sekme("hayat"); },
    anket: function () { var a = fn("anketEkrani"), ac = fn("ekranAc"); if (a && ac) ac(a); },
    oy: function () { sekme("gundem"); setTimeout(function () { var el = document.querySelector(".olay.oy, .olay.basvuru, .sahne"); if (el) el.scrollIntoView({ behavior: "smooth", block: "center" }); }, 700); }
  };
  function sekme(k) { var f = fn("sekmeAc"); if (f) f(k); }

  /* ------------------------------------------------------------------ Durum */
  function rehber() { return (R.ia && R.ia.rehber) || {}; }
  function ipucuGoruldu(k) {
    var r = rehber();
    return (Array.isArray(r.ipucu) && r.ipucu.indexOf(k) >= 0) || !!(R.yerel.ipucu && R.yerel.ipucu[k]);
  }
  function karsilamaGoruldu() { return !!rehber().karsilama || !!R.yerel.karsilama; }
  function iaAl(zorla) {
    if (!zorla && R.ia && Date.now() - R.iaZaman < 60000) return Promise.resolve(R.ia);
    if (R.okunuyor) return R.okunuyor;
    if (typeof API === "undefined" || !API.rpc) return Promise.resolve(null);
    R.okunuyor = API.rpc("ilk_adimlar").then(function (v) { iaGuncelle(v); return v; }).catch(function () { return null; }).then(function (v) { R.okunuyor = null; return v; });
    return R.okunuyor;
  }
  function iaGuncelle(v) { if (v && typeof v === "object") { R.ia = v; R.iaZaman = Date.now(); } }
  function isaretle(anahtar) {
    if (anahtar === "karsilama") R.yerel.karsilama = 1;
    else if (anahtar.indexOf("ipucu:") === 0) { R.yerel.ipucu = R.yerel.ipucu || {}; R.yerel.ipucu[anahtar.slice(6)] = 1; }
    else if (anahtar === "ipucu_sifirla") R.yerel = {};
    yerelYaz();
    if (typeof API === "undefined" || !API.rpc) return Promise.resolve(null);
    return API.rpc("rehber_isaretle", { p_anahtar: anahtar }).then(function (r) { if (R.ia && r) R.ia.rehber = r; return r; }).catch(function () { return null; });
  }

  /* ------------------------------------------------------------------ Stil */
  function css() {
    if (document.getElementById("rhCss")) return;
    var s = document.createElement("style"); s.id = "rhCss";
    s.textContent = [
      ".rh-katman{position:fixed;inset:0;z-index:9000;background:rgba(5,9,24,.72);display:flex;align-items:flex-end;justify-content:center;animation:rhSol .18s ease-out}",
      ".rh-katman.orta{align-items:center}",
      "@keyframes rhSol{from{opacity:0}to{opacity:1}}",
      "@keyframes rhYukari{from{transform:translateY(24px);opacity:.4}to{transform:none;opacity:1}}",
      ".rh-pano{width:100%;max-width:520px;box-sizing:border-box;background:var(--panel,#141c3a);color:var(--txt,#EEF1F8);border:1px solid var(--line2,rgba(164,184,255,.19));border-radius:22px 22px 0 0;padding:20px 18px calc(18px + var(--safeB,0px));animation:rhYukari .22s ease-out;max-height:88vh;overflow:auto}",
      ".rh-katman.orta .rh-pano{border-radius:22px;margin:16px;width:calc(100% - 32px)}",
      ".rh-pano h3{font-family:var(--disp,inherit);font-size:24px;font-weight:700;line-height:1.15;margin:0 0 8px;color:var(--txt,#EEF1F8)}",
      ".rh-pano p{font-size:16px;line-height:1.5;margin:0 0 14px;color:var(--txt2,#C9D1E6)}",
      ".rh-pano .btn{min-height:48px;white-space:normal}",
      ".rh-ust{display:flex;align-items:center;gap:10px;margin-bottom:10px}",
      ".rh-ust .rh-etiket{font-size:13px;font-weight:800;letter-spacing:.6px;text-transform:uppercase;color:var(--mut,#98A4C4)}",
      ".rh-atla{margin-left:auto;background:none;border:0;color:var(--ink2,#A895FF);font-size:15px;font-weight:700;min-height:44px;padding:0 6px}",
      ".rh-kart-ikon{width:64px;height:64px;border-radius:18px;display:grid;place-items:center;margin:6px 0 14px;background:linear-gradient(135deg,#d8425e,#5d47d6);color:#fff}",
      ".rh-kart-ikon svg{width:34px;height:34px}",
      ".rh-noktalar{display:flex;gap:6px;justify-content:center;margin:4px 0 14px}",
      ".rh-noktalar i{width:8px;height:8px;border-radius:99px;background:var(--panel3,rgba(255,255,255,.2));transition:width .2s}",
      ".rh-noktalar i.on{width:22px;background:var(--ink2,#A895FF)}",
      ".rh-iki{display:flex;gap:10px}.rh-iki .btn{flex:1;margin-top:0}",
      ".rh-soru{flex:none;width:30px;height:30px;border-radius:99px;border:1.5px solid var(--line,rgba(255,255,255,.25));background:transparent;color:inherit;font-weight:800;font-size:16px;line-height:1;display:inline-grid;place-items:center;padding:0;margin:0 2px 0 -2px;opacity:.85}",
      ".rh-soru.yeni{border-color:var(--ink2,#A895FF);color:var(--ink2,#A895FF);box-shadow:0 0 0 0 rgba(123,97,255,.6);animation:rhNabiz 1.8s ease-out 3}",
      "@keyframes rhNabiz{0%{box-shadow:0 0 0 0 rgba(123,97,255,.55)}100%{box-shadow:0 0 0 10px rgba(123,97,255,0)}}",
      ".rh-baglanti{display:flex;flex-direction:column;gap:2px;margin-top:6px}",
      ".rh-baglanti button{display:flex;align-items:center;gap:10px;width:100%;min-height:48px;background:none;border:0;border-top:1px solid var(--line2,rgba(164,184,255,.19));color:var(--txt,#EEF1F8);font-size:15.5px;text-align:left;padding:8px 2px}",
      ".rh-baglanti button span{flex:1}.rh-baglanti button b{opacity:.5}",
      /* İlk adımlar kartı */
      ".rh-ilk{border:1px solid rgba(123,97,255,.45)}",
      ".rh-ilk .rh-bas{display:flex;align-items:flex-start;gap:10px}",
      ".rh-ilk .rh-bas h2{margin:0;flex:1}",
      ".rh-ilk .rh-odul-cip{flex:none;font-size:13.5px;font-weight:800;padding:5px 10px;border-radius:99px;background:var(--inkbg,rgba(123,97,255,.16));color:var(--ink2,#A895FF)}",
      ".rh-cubuk{height:8px;border-radius:99px;background:var(--panel3,rgba(255,255,255,.12));overflow:hidden;margin:10px 0 4px}",
      ".rh-cubuk i{display:block;height:100%;border-radius:99px;background:linear-gradient(90deg,#34c98a,#9be3b8);transition:width .4s}",
      ".rh-adim{display:flex;gap:10px;align-items:flex-start;padding:11px 0;border-top:1px solid var(--line,rgba(255,255,255,.08))}",
      ".rh-adim:first-of-type{border-top:0}",
      ".rh-adim .kutu{width:24px;height:24px;border-radius:7px;border:2px solid var(--panel3,rgba(255,255,255,.3));flex:none;display:grid;place-items:center;margin-top:1px}",
      ".rh-adim.tamam .kutu{background:var(--good,#34c98a);border-color:var(--good,#34c98a)}",
      ".rh-adim.tamam .kutu::after{content:'';width:10px;height:5px;border:2.5px solid #0E1530;border-top:0;border-right:0;transform:rotate(-45deg) translate(1px,-1px)}",
      ".rh-adim .orta{flex:1;min-width:0}",
      ".rh-adim .orta b{display:block;font-size:15.5px;line-height:1.3}",
      ".rh-adim.tamam .orta b{opacity:.55;text-decoration:line-through}",
      ".rh-adim .orta small{display:block;font-size:14px;line-height:1.4;opacity:.78;margin-top:3px}",
      ".rh-adim .orta small.engel{color:#f0b35a;opacity:1}",
      ".rh-adim.sira{background:linear-gradient(90deg,rgba(123,97,255,.12),transparent);margin:0 -10px;padding-left:10px;padding-right:10px;border-radius:10px}",
      ".rh-adim .rh-git{flex:none;min-height:40px;min-width:64px;padding:0 14px;border-radius:12px;border:1px solid var(--ink2,#A895FF);background:transparent;color:var(--ink2,#A895FF);font-weight:800;font-size:14.5px}",
      ".rh-adim.sira .rh-git{background:var(--ink,#7B61FF);border-color:var(--ink,#7B61FF);color:#fff}",
      ".rh-alt-satir{display:flex;flex-wrap:wrap;gap:6px 16px;margin-top:10px}",
      ".rh-alt-satir button{background:none;border:0;color:inherit;opacity:.75;font-size:14.5px;font-weight:700;min-height:40px;padding:0;text-decoration:underline;text-underline-offset:3px}",
      ".rh-gizli-not{font-size:14px;opacity:.75}",
      ".rh-yeni-rozet{display:inline-block;margin-left:6px;padding:1px 7px;border-radius:99px;font-size:11.5px;font-weight:800;letter-spacing:.3px;line-height:1.5;vertical-align:1px;background:rgba(52,201,138,.16);color:#7ff0bd;border:1px solid rgba(52,201,138,.4)}",
      "@media (prefers-reduced-motion:reduce){.rh-katman,.rh-pano,.rh-soru.yeni{animation:none}}"
    ].join("\n");
    document.head.appendChild(s);
  }

  /* ------------------------------------------------------------------ Katman (alt pano / orta kart) */
  function katmanKapat() { var k = document.getElementById("rhKatman"); if (k) k.remove(); }
  function katman(html, orta, kapaninca) {
    css(); katmanKapat();
    var a = document.createElement("div"); a.id = "rhKatman"; a.className = "rh-katman" + (orta ? " orta" : "");
    a.setAttribute("role", "dialog"); a.setAttribute("aria-modal", "true");
    a.innerHTML = '<div class="rh-pano">' + html + "</div>";
    a.addEventListener("click", function (ev) { if (ev.target === a) { katmanKapat(); if (kapaninca) kapaninca(); } });
    document.body.appendChild(a);
    return a;
  }

  /* ------------------------------------------------------------------ 1) Karşılama */
  function karsilamaMetinleri() {
    var m = R.ia && Array.isArray(R.ia.metinler) ? R.ia.metinler : [];
    var kartlar = m.map(function (x) {
      var s = String(x || ""), i = s.indexOf("|");
      return i > 0 ? [s.slice(0, i).trim(), s.slice(i + 1).trim()] : null;
    }).filter(function (x) { return x && x[0] && x[1]; });
    return kartlar.length ? kartlar : KARSILAMA;
  }
  function karsilamaAc(elle) {
    var kartlar = karsilamaMetinleri(), i = 0;
    R.karsilamaAcik = true;
    var bitir = function (gitIlk) {
      R.karsilamaAcik = false; katmanKapat();
      if (!karsilamaGoruldu()) isaretle("karsilama");
      if (gitIlk) ilkAdimlaraGit();
    };
    var ciz = function () {
      var k = kartlar[i], son = i === kartlar.length - 1;
      var a = katman(
        '<div class="rh-ust"><span class="rh-etiket">Hoş geldin · ' + (i + 1) + " / " + kartlar.length + '</span><button class="rh-atla" data-rh="atla">' + (son ? "Kapat" : "Atla") + "</button></div>" +
        '<div class="rh-kart-ikon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + KART_IKON[i % KART_IKON.length] + "</svg></div>" +
        "<h3>" + esc(k[0]) + "</h3><p>" + esc(k[1]) + "</p>" +
        '<div class="rh-noktalar">' + kartlar.map(function (_, j) { return '<i class="' + (j === i ? "on" : "") + '"></i>'; }).join("") + "</div>" +
        '<div class="rh-iki">' + (i > 0 ? '<button class="btn ikinci" data-rh="geri">Geri</button>' : "") +
        '<button class="btn" data-rh="ileri">' + (son ? (R.ia && R.ia.yeni && !R.ia.bitti ? "İlk adımlarıma git" : "Başla") : "İleri") + "</button></div>",
        true, function () { bitir(false); });
      a.querySelector('[data-rh="atla"]').onclick = function () { bitir(false); };
      var g = a.querySelector('[data-rh="geri"]'); if (g) g.onclick = function () { i--; ciz(); };
      a.querySelector('[data-rh="ileri"]').onclick = function () { if (son) bitir(!!(R.ia && R.ia.yeni)); else { i++; ciz(); } };
      // Parmakla kaydırma
      var x0 = null, pano = a.querySelector(".rh-pano");
      pano.addEventListener("touchstart", function (ev) { x0 = ev.touches[0].clientX; }, { passive: true });
      pano.addEventListener("touchend", function (ev) {
        if (x0 == null) return; var dx = ev.changedTouches[0].clientX - x0; x0 = null;
        if (dx < -50 && !son) { i++; ciz(); } else if (dx > 50 && i > 0) { i--; ciz(); }
      }, { passive: true });
    };
    ciz();
    if (elle) R.gosterilen.karsilama = 1;
  }
  function ilkAdimlaraGit() {
    var dx = Dx();
    var kaydir = function () { var el = document.getElementById("rhIlk"); if (el) el.scrollIntoView({ behavior: "smooth", block: "start" }); };
    if (dx && dx.sekme === "gundem" && !(dx.yigin && dx.yigin.length)) kaydir();
    else { sekme("gundem"); setTimeout(kaydir, 900); }
  }

  /* ------------------------------------------------------------------ 2) İlk Adımlar kartı */
  function ilkAdimlarHtml(ia) {
    iaGuncelle(ia);
    css();
    if (!ia || !ia.yeni || !Array.isArray(ia.adimlar) || !ia.adimlar.length) return "";
    var r = ia.rehber || {};
    if (ia.bitti && !ia.odul_hazir) return "";
    if (r.kart_gizle && !ia.odul_hazir) {
      return '<div class="kart rh-gizli-not" id="rhIlk">İlk adımlar kartını gizledin. <button class="bag" style="background:none;border:0;color:inherit;text-decoration:underline;font-weight:700;min-height:40px" onclick="REHBER.kartGoster()">Yeniden göster</button></div>';
    }
    var adimlar = ia.adimlar, n = adimlar.filter(function (a) { return a.tamam; }).length;
    var siradaki = -1;
    adimlar.forEach(function (a, i) { if (siradaki < 0 && !a.tamam && (a.cekirdek !== false)) siradaki = i; });
    if (siradaki < 0) adimlar.forEach(function (a, i) { if (siradaki < 0 && !a.tamam) siradaki = i; });
    var odul = +ia.odul || 0;
    var kalanGun = ia.bitis ? Math.max(0, Math.ceil((new Date(ia.bitis).getTime() - Date.now()) / 864e5)) : null;
    var h = '<div class="kart rh-ilk" id="rhIlk"><div class="rh-bas"><h2>İlk adımların</h2>' +
      (odul > 0 && !ia.odul_alindi ? '<span class="rh-odul-cip">Ödül ' + esc(tl(odul)) + "</span>" : ia.odul_alindi ? '<span class="rh-odul-cip">Ödül alındı ✓</span>' : "") + "</div>" +
      '<div class="alt">' + n + " / " + adimlar.length + " tamam" + (kalanGun != null && odul > 0 && !ia.odul_alindi ? " · ödül için " + kalanGun + " gün kaldı" : "") + ". Sırayla git; her adım oyunun bir köşesini tanıtır.</div>" +
      '<div class="rh-cubuk"><i style="width:' + Math.round(n * 100 / adimlar.length) + '%"></i></div>';
    if (ia.odul_hazir) {
      h += '<button class="btn" onclick="REHBER.odulAl(this)">Başlangıç ödülünü al · ' + esc(tl(odul)) + "</button>";
    }
    adimlar.forEach(function (a, i) {
      var engel = a.kod === "oy" && !a.tamam && a.not;
      h += '<div class="rh-adim' + (a.tamam ? " tamam" : "") + (i === siradaki ? " sira" : "") + '"><span class="kutu"></span><div class="orta"><b>' + esc(a.ad) +
        (a.cekirdek === false && !a.tamam ? ' <span class="kucuk" style="opacity:.7;font-weight:600">(isteğe bağlı)</span>' : "") + "</b>" +
        (!a.tamam && a.neden ? "<small>" + esc(a.neden) + "</small>" : "") +
        (engel ? '<small class="engel">' + esc(a.not) + "</small>" : "") + "</div>" +
        (!a.tamam && GIT[a.kod] ? '<button class="rh-git" onclick="REHBER.git(\'' + esc(a.kod) + '\')">Git</button>' : "") + "</div>";
    });
    h += '<div class="rh-alt-satir">' +
      '<button onclick="REHBER.karsilama()">Tanıtımı yeniden izle</button>' +
      (fn("smMentorEkrani") ? '<button onclick="REHBER.mentor()">Yol arkadaşı bul</button>' : "") +
      (!ia.odul_hazir ? '<button onclick="REHBER.kartGizle()">Kartı gizle</button>' : "") + "</div></div>";
    return h;
  }

  async function odulAl(btn) {
    if (btn) btn.disabled = true;
    try {
      var r = await API.rpc("rehber_odul_al");
      if (typeof toast === "function") toast("Başlangıç ödülün cüzdanına yattı: " + tl(r && r.odul));
      if (R.ia) { R.ia.odul_hazir = false; R.ia.odul_alindi = true; R.ia.rehber = Object.assign({}, R.ia.rehber || {}, { odul: new Date().toISOString() }); }
      try { if (typeof durumYenile === "function") await durumYenile(); } catch (_) {}
      var y = fn("yenidenCiz"); if (y) y();
    } catch (err) {
      if (typeof toast === "function") toast(hc((err && err.message) || String(err)), true);
      if (btn) btn.disabled = false;
    }
  }
  function kartGizle() {
    if (R.ia) R.ia.rehber = Object.assign({}, R.ia.rehber || {}, { kart_gizle: new Date().toISOString() });
    isaretle("kart_gizle").then(function () { var y = fn("yenidenCiz"); if (y) y(); });
    var el = document.getElementById("rhIlk"); if (el) el.outerHTML = ilkAdimlarHtml(R.ia);
    if (typeof toast === "function") toast("Kart gizlendi. ? düğmesinden yeniden açabilirsin.");
  }
  function kartGoster() {
    if (R.ia && R.ia.rehber) delete R.ia.rehber.kart_gizle;
    isaretle("kart_goster");
    var el = document.getElementById("rhIlk"); if (el) el.outerHTML = ilkAdimlarHtml(R.ia);
  }

  /* ------------------------------------------------------------------ 3) Ekran ipuçları ve ? düğmesi */
  function anaEkranAnahtari() {
    var dx = Dx(); if (!dx || !dx.durum || !dx.durum.profil) return null;
    if (dx.yigin && dx.yigin.length) return null;
    return IPUCU[dx.sekme] ? dx.sekme : null;
  }
  function ipucuAc(k, otomatik) {
    var t = IPUCU[k]; if (!t) return;
    R.gosterilen[k] = 1;
    var ia = R.ia || {}, yeni = !!ia.yeni;
    var kapat = function () { katmanKapat(); if (!ipucuGoruldu(k)) isaretle("ipucu:" + k); soruGuncelle(); };
    var bag = [];
    if (yeni && ia.adimlar && ia.adimlar.length && !(ia.bitti && !ia.odul_hazir)) bag.push(["ilk", "İlk adımlarım" + (ia.odul_hazir ? " · ödülün hazır" : "")]);
    bag.push(["karsilama", "Oyun tanıtımını yeniden izle"]);
    if (fn("metinGoster")) bag.push(["kurallar", "Oyun nasıl oynanır? (kurallar)"]);
    if (fn("yardimMasasiAc")) bag.push(["yardim", "Yardım Masası'na soru sor"]);
    if (fn("smMentorEkrani") && yeni) bag.push(["mentor", "Deneyimli bir yol arkadaşı bul"]);
    if (fn("yonetimeYazEkrani")) bag.push(["yonetim", "Yönetime yaz (sorun, öneri, şikâyet)"]);
    var a = katman(
      '<div class="rh-ust"><span class="rh-etiket">' + (otomatik ? "Bu ekran ne işe yarar?" : "Rehber") + '</span><button class="rh-atla" data-rh="kapat">Kapat</button></div>' +
      "<h3>" + esc(t[0]) + "</h3><p>" + esc(t[1]) + "</p>" +
      '<button class="btn" data-rh="tamam">Anladım</button>' +
      '<div class="rh-baglanti">' + bag.map(function (b) { return '<button data-rh-bag="' + b[0] + '"><span>' + esc(b[1]) + "</span><b>›</b></button>"; }).join("") + "</div>",
      false, kapat);
    a.querySelector('[data-rh="kapat"]').onclick = kapat;
    a.querySelector('[data-rh="tamam"]').onclick = kapat;
    a.querySelectorAll("[data-rh-bag]").forEach(function (b) {
      b.onclick = function () {
        var ne = b.getAttribute("data-rh-bag"); kapat();
        if (ne === "ilk") ilkAdimlaraGit();
        else if (ne === "karsilama") karsilamaAc(true);
        else if (ne === "kurallar") fn("metinGoster")("kurallar");
        else if (ne === "yardim") fn("yardimMasasiAc")();
        else if (ne === "mentor") mentor();
        else if (ne === "yonetim") { var ac = fn("ekranAc"), y = fn("yonetimeYazEkrani"); if (ac && y) ac(function () { return y({ konu: "oneri" }); }); }
      };
    });
  }
  function mentor() { var ac = fn("ekranAc"), m = fn("smMentorEkrani"); if (ac && m) ac(m); }
  function soruGuncelle() {
    var b = document.querySelector("#app > header.ust .rh-soru"); if (!b) return;
    var k = anaEkranAnahtari();
    b.classList.toggle("yeni", !!(k && R.ia && R.ia.yeni && !ipucuGoruldu(k)));
  }
  function soruEkle() {
    var hd = document.querySelector("#app > header.ust"); if (!hd) return;
    var k = anaEkranAnahtari();
    var var_ = hd.querySelector(".rh-soru");
    if (!k) { if (var_) var_.remove(); return; }
    if (var_ && var_.getAttribute("data-k") === k) return;
    if (var_) var_.remove();
    var h1 = hd.querySelector("h1"); if (!h1) return;
    css();
    var b = document.createElement("button");
    b.type = "button"; b.className = "rh-soru"; b.setAttribute("data-k", k);
    b.setAttribute("aria-label", "Bu ekran ne işe yarar? Rehberi aç"); b.title = "Rehber";
    b.textContent = "?";
    b.onclick = function (ev) { ev.stopPropagation(); ipucuAc(k, false); };
    h1.insertAdjacentElement("afterend", b);
    soruGuncelle();
  }

  /* Gündem'de kartı görünür yere (takvimin hemen altına) taşı */
  function kartiYerlestir() {
    var dx = Dx(); if (!dx || dx.sekme !== "gundem" || (dx.yigin && dx.yigin.length)) return;
    var kart = document.getElementById("rhIlk"); if (!kart || kart.classList.contains("rh-gizli-not") || kart._rhYer) return;
    var ic = document.getElementById("icerik"); if (!ic) return;
    var sahne = ic.querySelector(":scope > .sahne");
    if (sahne && sahne.nextElementSibling !== kart) sahne.insertAdjacentElement("afterend", kart);
    kart._rhYer = 1;
  }

  /* Kendiliğinden açılma: yalnız rehber açıldıktan sonra kayıt olan hesap (ia.otomatik), oturumda bir kez */
  var otoZaman = null;
  function otomatikKontrol() {
    if (otoZaman) return;
    otoZaman = setTimeout(function () {
      otoZaman = null;
      var ia = R.ia;
      if (!ia || !ia.yeni || !ia.otomatik) return;
      if (document.getElementById("rhKatman") || document.getElementById("modal") || R.karsilamaAcik) return;
      var dx = Dx(); if (!dx || !dx.durum || !dx.durum.profil) return;
      if (!karsilamaGoruldu()) { if (!R.gosterilen.karsilama) { R.gosterilen.karsilama = 1; karsilamaAc(false); } return; }
      // Gündem'i karşılama zaten anlatıyor; orada ipucu kendiliğinden açılmaz (? düğmesi yine çalışır)
      var k = anaEkranAnahtari();
      if (k && k !== "gundem" && !ipucuGoruldu(k) && !R.gosterilen[k]) ipucuAc(k, true);
    }, 900);
  }

  /* ------------------------------------------------------------------ Kurulum */
  function cizimSonrasi() {
    try { soruEkle(); kartiYerlestir(); } catch (_) {}
    var dx = Dx(); if (!dx || !dx.durum || !dx.durum.profil) return;
    if (!R.ia && !R.okunuyor) iaAl().then(function () { soruGuncelle(); otomatikKontrol(); });
    else otomatikKontrol();
  }
  function kur() {
    css();
    // Gündem'deki eski kartın yerine geç (index.html gundemEkrani bu adı çağırır)
    window.ilkAdimlarHtml = ilkAdimlarHtml;
    var app = document.getElementById("app"); if (!app) return;
    var z = 0;
    new MutationObserver(function () { if (z) return; z = requestAnimationFrame(function () { z = 0; cizimSonrasi(); }); }).observe(app, { childList: true });
    cizimSonrasi();
  }

  window.REHBER = {
    git: function (kod) { var f = GIT[kod]; if (f) f(); },
    odulAl: odulAl, kartGizle: kartGizle, kartGoster: kartGoster, mentor: mentor,
    karsilama: function () { karsilamaAc(true); },
    ipucu: function (k) { ipucuAc(k || anaEkranAnahtari() || "gundem", false); },
    sifirla: function () { R.gosterilen = {}; return isaretle("ipucu_sifirla"); },
    durum: function () { return R.ia; }
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", kur); else kur();
})();
