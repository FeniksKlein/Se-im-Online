/* Seçim Online — Bankacılık 2.0 (25.10.2026)
   • Mobil Şube: müşterinin bütün hesapları, kartları, kredileri ve birikimleri tek uygulamada.
   • Banka Genel Müdürlüğü: banka sahibinin bilanço, başvuru, ürün, kasa ve müşteri yönetimi.
   • Kasa gizliliği: şirket / banka / dernek / gazete kasaları sahibine görünür; sahibi isterse açar.
   Para hareketleri yalnız sunucu fonksiyonlarıyla yapılır; bu dosya arayüzdür. */
(function () {
  "use strict";
  if (window.BANKACILIK_V2) return;
  window.BANKACILIK_V2 = true;

  /* ---------------- yardımcılar ---------------- */
  var esc = function (x) {
    return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  };
  var sayi = function (n, d) {
    return Number(n || 0).toLocaleString("tr-TR", { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 });
  };
  var tl = function (n, d) { return n == null || isNaN(Number(n)) ? "—" : sayi(n, d) + " ₺"; };
  var tlKisa = function (n) {
    n = Number(n || 0); var a = Math.abs(n);
    if (a >= 1e9) return sayi(n / 1e9, 1) + " Mr ₺";
    if (a >= 1e6) return sayi(n / 1e6, a >= 1e7 ? 1 : 2) + " Mn ₺";
    if (a >= 1e4) return sayi(n / 1e3, 0) + " B ₺";
    return sayi(n) + " ₺";
  };
  var sektorAd = function (k) {
    if (!k) return "";
    try { if (typeof HA_SEKTOR !== "undefined" && HA_SEKTOR[k]) return HA_SEKTOR[k]; } catch (_) {}
    return String(k).replace(/_/g, " ").replace(/^./, function (c) { return c.toLocaleUpperCase("tr-TR"); });
  };
  var yuzde = function (n, d) { return n == null ? "—" : "%" + sayi(n, d == null ? 2 : d); };
  var zaman = function (ts) {
    if (!ts) return "—";
    try { return typeof tarihSaat === "function" ? tarihSaat(ts) : new Date(ts).toLocaleString("tr-TR"); }
    catch (_) { return String(ts); }
  };
  var kalanSure = function (ts) {
    if (!ts) return "";
    var ms = new Date(ts).getTime() - Date.now();
    if (ms <= 0) return "vadesi doldu";
    var dk = Math.round(ms / 60000);
    if (dk < 60) return dk + " dk kaldı";
    var sa = Math.round(dk / 60);
    if (sa < 48) return sa + " saat kaldı";
    return Math.round(sa / 24) + " gün kaldı";
  };
  var parse = function (v) {
    v = String(v == null ? "" : v).trim().replace(/\s/g, "").replace(/₺/g, "");
    if (/^\d{1,3}(\.\d{3})+(,\d+)?$/.test(v)) v = v.replace(/\./g, "").replace(",", ".");
    else v = v.replace(",", ".");
    var n = Number(v);
    return isFinite(n) ? n : NaN;
  };
  var hata = function (err) {
    var m = err && err.message ? err.message : String(err || "Beklenmeyen hata");
    return typeof hataCevir === "function" ? hataCevir(m) : m;
  };
  var bildir = function (m, h) { if (typeof toast === "function") toast(m, h); };
  var $id = function (x) { return document.getElementById(x); };
  var val = function (x) { var el = $id(x); return el ? el.value : ""; };
  var ekran = function (baslik, govde) {
    iskelet(baslik, govde, { geri: typeof D !== "undefined" && !!(D.yigin && D.yigin.length) });
  };
  var sor = function (baslik, metin, buton, tehlike) {
    return typeof onayla === "function" ? onayla(baslik, metin, buton, tehlike) : Promise.resolve(confirm(metin));
  };
  var kapat = function () { if (typeof modalKapat === "function") modalKapat(); };
  // Gizli kasa: sunucu null döndürürse "Gizli" yazar.
  var gizliTL = window.gizliTL = function (v, bicim) {
    if (v === null || v === undefined || v === "") return '<span class="kasa-gizli" title="Kasa bilgisi sahibine özeldir">🔒 Gizli</span>';
    return (bicim || tl)(v);
  };

  // Banka renkleri (banka sahibinin seçtiği kurumsal renk)
  var RENK = {
    lacivert: ["#2747B8", "#101E57", "Lacivert"], bordo: ["#8E1D3B", "#3E0918", "Bordo"],
    zumrut: ["#11806A", "#05372D", "Zümrüt"], turuncu: ["#D0651F", "#6B2A06", "Turuncu"],
    mor: ["#6A4BE0", "#291776", "Mor"], altin: ["#C79A34", "#5A400C", "Altın"],
    turkuaz: ["#16909A", "#063E45", "Turkuaz"], gece: ["#3A4050", "#0C0E14", "Gece"],
    kirmizi: ["#C42B33", "#560B10", "Kırmızı"], gumus: ["#98A2B5", "#3B4252", "Gümüş"],
    devlet: ["#A8162A", "#45060E", "Devlet"], kart: ["#4E5A78", "#1B2135", "Kart"]
  };
  var renk = function (k) { return RENK[k] || RENK.lacivert; };
  var ETIKET = { kredi_notu: "kredi notu", maas: "maaş", nakit: "nakit", mulk: "mülk", sirket: "şirket hisseleri", kira: "kira geliri", gunluk: "günlük gelir" };
  var etiketler = function (l) { return (l || []).map(function (x) { return ETIKET[x] || x; }).join(", "); };
  var NOT_RENK = { AAA: "#34C98A", AA: "#34C98A", A: "#7FD35B", BBB: "#F2B33D", BB: "#F2963D", B: "#F0704B", C: "#F0454B" };

  /* ---------------- stil ---------------- */
  function stilKur() {
    if ($id("bk-stil")) return;
    var css = [
      ".bk{--bkr:16px}",
      ".bk .bk-ust{display:flex;align-items:flex-end;justify-content:space-between;gap:12px;margin:2px 2px 14px}",
      ".bk .bk-ust small{display:block;color:var(--mut);font-size:13px}",
      ".bk .bk-tutar{font-family:var(--disp);font-weight:700;font-size:34px;line-height:1.05;letter-spacing:.2px;font-variant-numeric:tabular-nums}",
      ".bk .bk-ikili{display:flex;gap:18px;margin-top:6px;font-size:13px;color:var(--txt2)}",
      ".bk .bk-ikili b{font-variant-numeric:tabular-nums;color:var(--txt)}",
      ".bk .bk-not{flex:none;width:76px;height:76px;border-radius:50%;display:grid;place-items:center;text-align:center;background:conic-gradient(var(--c) calc(var(--p)*1%),var(--panel2) 0);position:relative}",
      ".bk .bk-not::before{content:'';position:absolute;inset:6px;border-radius:50%;background:var(--bg)}",
      ".bk .bk-not span{position:relative;font-family:var(--disp);font-weight:700;font-size:20px;line-height:1}",
      ".bk .bk-not small{position:relative;display:block;font-size:10px;color:var(--mut);margin-top:2px}",
      /* plastik kart */
      ".bk .bk-kaydir{display:flex;gap:12px;overflow-x:auto;scroll-snap-type:x mandatory;scroll-padding:0 16px;padding:2px 16px 10px;margin:0 -16px 6px;scrollbar-width:none}",
      ".bk .bk-kaydir::-webkit-scrollbar{display:none}",
      ".bk .bk-plastik{flex:0 0 min(78%,300px);aspect-ratio:1.586;border-radius:var(--bkr);padding:16px 18px;position:relative;overflow:hidden;color:#fff;scroll-snap-align:start;text-align:left;display:flex;flex-direction:column;justify-content:space-between;box-shadow:0 10px 24px -14px rgba(0,0,0,.9),inset 0 1px 0 rgba(255,255,255,.18);background:linear-gradient(135deg,var(--a),var(--b))}",
      ".bk .bk-plastik::after{content:'';position:absolute;inset:0;pointer-events:none;background:repeating-radial-gradient(circle at 110% 120%,rgba(255,255,255,.07) 0 1px,transparent 1px 9px),radial-gradient(120% 80% at 0% 0%,rgba(255,255,255,.16),transparent 55%)}",
      ".bk .bk-plastik>*{position:relative;z-index:1}",
      ".bk .bk-plastik .bk-banka{font-family:var(--disp);font-weight:700;font-size:19px;letter-spacing:.3px;line-height:1.05;max-width:78%}",
      ".bk .bk-plastik .bk-tur{position:absolute;top:16px;right:18px;font-size:11px;opacity:.82}",
      ".bk .bk-plastik .bk-cip{width:38px;height:28px;border-radius:6px;background:linear-gradient(135deg,#F6DA8B,#B78A2C);box-shadow:inset 0 0 0 1px rgba(0,0,0,.25);position:relative}",
      ".bk .bk-plastik .bk-cip::before{content:'';position:absolute;inset:6px 0;border-top:1px solid rgba(0,0,0,.3);border-bottom:1px solid rgba(0,0,0,.3)}",
      ".bk .bk-plastik .bk-bakiye{font-family:var(--disp);font-weight:700;font-size:26px;font-variant-numeric:tabular-nums;line-height:1}",
      ".bk .bk-plastik .bk-alt{display:flex;justify-content:space-between;align-items:flex-end;gap:8px;font-size:12px;opacity:.9;font-variant-numeric:tabular-nums;letter-spacing:.6px}",
      ".bk .bk-plastik.bk-yeni{background:transparent;border:1.5px dashed var(--line2);color:var(--txt2);box-shadow:none;align-items:center;justify-content:center;gap:6px;font-weight:700}",
      ".bk .bk-plastik.bk-yeni::after{display:none}",
      ".bk .bk-plastik.bk-buyuk{flex:none;width:100%;max-width:360px;margin:0 auto 12px}",
      ".bk .bk-plastik.dondu{filter:grayscale(.8) brightness(.8)}",
      /* hızlı işlemler */
      ".bk .bk-hizli{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:4px 0 14px}",
      ".bk .bk-hizli button{background:var(--panel);border-radius:14px;padding:12px 4px 10px;display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;font-weight:600;color:var(--txt2);line-height:1.15;text-align:center}",
      ".bk .bk-hizli button span{width:34px;height:34px;border-radius:11px;display:grid;place-items:center;background:var(--inkbg);color:var(--ink2);font-size:17px}",
      /* sekme şeridi */
      ".bk .bk-sekme{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 -16px 12px;padding:0 16px;position:sticky;top:-14px;z-index:3;background:var(--bg);padding-top:6px;padding-bottom:8px}",
      ".bk .bk-sekme::-webkit-scrollbar{display:none}",
      ".bk .bk-sekme button{flex:none;padding:8px 13px;border-radius:999px;background:var(--panel);color:var(--txt2);font-size:13.5px;font-weight:700;white-space:nowrap}",
      ".bk .bk-sekme button.on{background:var(--txt);color:var(--bg)}",
      ".bk .bk-sekme button i{font-style:normal;display:inline-grid;place-items:center;min-width:18px;height:18px;border-radius:9px;background:var(--al);color:#fff;font-size:11px;margin-left:6px;padding:0 5px}",
      /* satırlar */
      ".bk .bk-kutu{background:var(--panel);border-radius:14px;padding:4px 14px;margin-bottom:12px}",
      ".bk .bk-kutu>h3{font-size:13px;color:var(--mut);font-weight:600;padding:12px 0 4px}",
      ".bk .bk-satir{display:flex;align-items:center;gap:12px;padding:12px 0;border-top:1px solid var(--line)}",
      ".bk .bk-kutu>h3+.bk-satir,.bk .bk-kutu>.bk-satir:first-child{border-top:0}",
      ".bk .bk-satir .bk-orta{flex:1;min-width:0}",
      ".bk .bk-satir .bk-orta b{display:block;font-size:14.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}",
      ".bk .bk-satir .bk-orta small{display:block;color:var(--mut);font-size:12.5px;margin-top:1px}",
      ".bk .bk-satir .bk-sag{text-align:right;font-variant-numeric:tabular-nums;font-weight:700;white-space:nowrap}",
      ".bk .bk-satir .bk-sag small{display:block;font-weight:500;color:var(--mut);font-size:12px}",
      ".bk .bk-nokta{flex:none;width:10px;height:10px;border-radius:3px;background:linear-gradient(135deg,var(--a),var(--b))}",
      ".bk .art{color:var(--good)}.bk .eks{color:var(--txt)}",
      ".bk .bk-ipucu{font-size:13px;color:var(--mut);margin:-4px 2px 12px;line-height:1.45}",
      ".bk .bk-dugmeler{display:flex;gap:8px;flex-wrap:wrap;padding:4px 0 12px}",
      ".bk .bk-dugmeler .btn{flex:1 1 120px;margin:0;padding:11px 10px;font-size:14px}",
      ".bk .bk-cubuk{height:6px;border-radius:3px;background:var(--panel2);overflow:hidden;margin:8px 0 2px}",
      ".bk .bk-cubuk i{display:block;height:100%;border-radius:3px;background:var(--c,var(--ink2))}",
      ".bk .bk-uyari{background:var(--albg);color:var(--al2);border-radius:12px;padding:11px 13px;font-size:13.5px;margin-bottom:12px}",
      ".bk .bk-bilgi{background:var(--inkbg);color:var(--txt2);border-radius:12px;padding:11px 13px;font-size:13.5px;margin-bottom:12px}",
      ".bk .bk-bos{text-align:center;color:var(--mut);padding:22px 10px;font-size:14px}",
      ".bk .bk-rozet{display:inline-block;padding:2px 7px;border-radius:6px;font-size:11.5px;font-weight:700;background:var(--panel2);color:var(--txt2);vertical-align:middle}",
      ".bk .bk-rozet.k{background:var(--albg);color:var(--al2)}.bk .bk-rozet.y{background:rgba(52,201,138,.14);color:var(--good)}.bk .bk-rozet.s{background:rgba(242,179,61,.14);color:var(--warn)}",
      ".bk .bk-gn{display:inline-grid;place-items:center;min-width:42px;height:26px;padding:0 7px;border-radius:7px;font-family:var(--disp);font-weight:700;font-size:15px;color:#0E1530;background:var(--c)}",
      /* genel müdürlük */
      ".bk .bk-kimlik{border-radius:18px;padding:18px;color:#fff;position:relative;overflow:hidden;background:linear-gradient(135deg,var(--a),var(--b));margin-bottom:14px}",
      ".bk .bk-kimlik::after{content:'';position:absolute;inset:0;background:repeating-linear-gradient(115deg,rgba(255,255,255,.05) 0 2px,transparent 2px 14px);pointer-events:none}",
      ".bk .bk-kimlik>*{position:relative;z-index:1}",
      ".bk .bk-kimlik h2{font-family:var(--disp);font-size:28px;line-height:1.05}",
      ".bk .bk-kimlik p{opacity:.85;font-size:13.5px;margin-top:4px}",
      ".bk .bk-kimlik .bk-harf{position:absolute;right:16px;top:14px;text-align:center}",
      ".bk .bk-kimlik .bk-harf b{display:block;font-family:var(--disp);font-size:40px;line-height:.9;letter-spacing:1px}",
      ".bk .bk-kimlik .bk-harf small{font-size:11px;opacity:.85}",
      ".bk .bk-kimlik .bk-km{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:16px}",
      ".bk .bk-kimlik .bk-km div{background:rgba(0,0,0,.22);border-radius:11px;padding:8px 10px}",
      ".bk .bk-kimlik .bk-km small{display:block;font-size:11px;opacity:.8}",
      ".bk .bk-kimlik .bk-km b{font-variant-numeric:tabular-nums;font-size:14.5px}",
      ".bk .bk-oran{padding:11px 0;border-top:1px solid var(--line)}",
      ".bk .bk-oran:first-of-type{border-top:0}",
      ".bk .bk-oran .bk-ob{display:flex;justify-content:space-between;font-size:14px}",
      ".bk .bk-oran .bk-ob b{font-variant-numeric:tabular-nums}",
      ".bk .bk-oran small{color:var(--mut);font-size:12px}",
      ".bk .bk-bil{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px}",
      ".bk .bk-bil>div{background:var(--panel);border-radius:14px;padding:12px 13px}",
      ".bk .bk-bil h4{font-size:12.5px;color:var(--mut);font-weight:600;margin-bottom:6px}",
      ".bk .bk-bil .bk-bs{display:flex;justify-content:space-between;font-size:13px;padding:4px 0;gap:6px}",
      ".bk .bk-bil .bk-bs b{font-variant-numeric:tabular-nums}",
      ".bk .bk-bil .bk-top{border-top:1px solid var(--line2);margin-top:6px;padding-top:7px;font-weight:700}",
      ".bk .bk-secim{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:6px 0 12px}",
      ".bk .bk-secim button{background:var(--panel2);border-radius:12px;padding:11px;text-align:left;border:1.5px solid transparent}",
      ".bk .bk-secim button b{display:block;font-size:14px}",
      ".bk .bk-secim button small{color:var(--mut);font-size:12px;line-height:1.35;display:block;margin-top:2px}",
      ".bk .bk-secim button.on{border-color:var(--ink2);background:var(--inkbg)}",
      ".bk .bk-renkler{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin:8px 0}",
      ".bk .bk-renkler button{aspect-ratio:1.586;border-radius:9px;background:linear-gradient(135deg,var(--a),var(--b));border:2px solid transparent}",
      ".bk .bk-renkler button.on{border-color:#fff}",
      ".bk .bk-form .alan{margin-bottom:10px}",
      ".bk .bk-form label{display:block;font-size:12.5px;color:var(--mut);margin-bottom:5px}",
      ".bk .bk-form input,.bk .bk-form select,.bk-modal input,.bk-modal select,.bk-modal textarea{width:100%;background:var(--panel2);border:1px solid var(--line2);border-radius:11px;padding:11px 12px;color:var(--txt);font-size:15px}",
      ".bk-modal .alan{margin-bottom:10px}.bk-modal label{display:block;font-size:12.5px;color:var(--mut);margin-bottom:5px}",
      ".bk-modal .bk-ozet{background:var(--panel2);border-radius:11px;padding:10px 12px;font-size:13.5px;margin:6px 0;line-height:1.5}",
      ".bk-modal .bk-cips{display:flex;gap:6px;flex-wrap:wrap;margin:4px 0 10px}",
      ".bk-modal .bk-cips button{padding:8px 11px;border-radius:999px;background:var(--panel2);font-size:13px;font-weight:700;color:var(--txt2);border:1.5px solid transparent}",
      ".bk-modal .bk-cips button.on{border-color:var(--ink2);color:var(--txt);background:var(--inkbg)}",
      ".kasa-gizli{display:inline-flex;align-items:center;gap:3px;font-weight:600;color:var(--mut);font-size:.92em;white-space:nowrap}",
      "@media (prefers-reduced-motion:no-preference){.bk .bk-plastik{transition:transform .15s}.bk .bk-plastik:active{transform:scale(.985)}}"
    ].join("\n");
    var st = document.createElement("style"); st.id = "bk-stil"; st.textContent = css;
    document.head.appendChild(st);
  }

  /* ---------------- ortak parçalar ---------------- */
  function renkVar(k) { var r = renk(k); return "--a:" + r[0] + ";--b:" + r[1]; }
  function plastik(o) {
    // o: {renk, banka, tur, bakiye, alt1, alt2, onclick, cls}
    return '<button type="button" class="bk-plastik ' + (o.cls || "") + '" style="' + renkVar(o.renk) + '"' +
      (o.onclick ? ' onclick="' + o.onclick + '"' : "") + '>' +
      '<span class="bk-banka">' + esc(o.banka) + '</span><span class="bk-tur">' + esc(o.tur || "") + '</span>' +
      (o.cip ? '<span class="bk-cip" aria-hidden="true"></span>' : '') +
      '<span><span class="bk-bakiye">' + o.bakiye + '</span>' + (o.bakiyeAlt ? '<small style="display:block;font-size:12px;opacity:.85;margin-top:4px">' + o.bakiyeAlt + '</small>' : '') + '</span>' +
      '<span class="bk-alt"><span>' + esc(o.alt1 || "") + '</span><span>' + esc(o.alt2 || "") + '</span></span></button>';
  }
  function satir(o) {
    return '<div class="bk-satir"' + (o.onclick ? ' role="button" tabindex="0" onclick="' + o.onclick + '"' : '') + '>' +
      (o.renk ? '<span class="bk-nokta" style="' + renkVar(o.renk) + '"></span>' : '') +
      '<span class="bk-orta"><b>' + o.bas + '</b>' + (o.alt ? '<small>' + o.alt + '</small>' : '') + '</span>' +
      (o.sag != null ? '<span class="bk-sag">' + o.sag + (o.sagAlt ? '<small>' + o.sagAlt + '</small>' : '') + '</span>' : '') + '</div>';
  }
  function kutu(bas, ic) { return '<section class="bk-kutu">' + (bas ? '<h3>' + bas + '</h3>' : '') + ic + '</section>'; }
  function dugme(yazi, islem, tur) { return '<button type="button" class="btn ' + (tur === "altin" ? "" : (tur || "ikinci")) + '" onclick="' + islem + '">' + esc(yazi) + '</button>'; }
  function sekmeler(liste, aktif, fn) {
    return '<nav class="bk-sekme" role="tablist">' + liste.map(function (s) {
      return '<button type="button" role="tab" class="' + (s[0] === aktif ? "on" : "") + '" aria-selected="' + (s[0] === aktif) + '" onclick="' + fn + "('" + s[0] + "')\">" +
        esc(s[1]) + (s[2] ? '<i>' + s[2] + '</i>' : '') + '</button>';
    }).join("") + '</nav>';
  }
  function bmodal(html) {
    var m = modal('<div class="bk-modal">' + html + '</div>');
    var ilk = m.querySelector("input,select,textarea"); if (ilk) setTimeout(function () { try { ilk.focus(); } catch (_) {} }, 60);
    return m;
  }
  async function calis(btn, fn, basari) {
    var b = btn && btn.tagName ? btn : null;
    if (b) { if (b.disabled) return; b.disabled = true; }
    try { var r = await fn(); if (basari) bildir(typeof basari === "function" ? basari(r) : basari); return r; }
    catch (err) { bildir(hata(err), true); throw err; }
    finally { if (b) b.disabled = false; }
  }
  function notHalka(notu, ad) {
    var p = Math.max(0, Math.min(100, (Number(notu) - 300) / 16));
    var c = notu >= 1700 ? "#34C98A" : notu >= 1500 ? "#7FD35B" : notu >= 1100 ? "#F2B33D" : notu >= 700 ? "#F2963D" : "#F0454B";
    return '<div class="bk-not" style="--p:' + p.toFixed(0) + ';--c:' + c + '" title="Kredi notu"><div><span>' + sayi(notu) + '</span><small>' + esc(ad || "") + '</small></div></div>';
  }
  function gnRozet(harf) { return '<span class="bk-gn" style="--c:' + (NOT_RENK[harf] || "#98A4C4") + '" title="Güven notu">' + esc(harf || "—") + '</span>'; }

  /* =====================================================================
     MOBİL ŞUBE (müşteri)
     ===================================================================== */
  var MS = { sekme: "ozet", veri: null, yon: [], tumHareket: false };

  async function msYukle() {
    var r = await Promise.allSettled([API.rpc("banka_sube"), API.rpc("banka_yonettiklerim")]);
    if (r[0].status !== "fulfilled") throw r[0].reason;
    MS.veri = r[0].value || {};
    MS.yon = r[1].status === "fulfilled" && Array.isArray(r[1].value) ? r[1].value : [];
  }
  async function mobilSube(sekme) {
    stilKur();
    if (sekme) MS.sekme = sekme;
    if (typeof yukleniyor === "function") yukleniyor("Mobil Şube");
    try { await msYukle(); }
    catch (err) {
      return ekran("Mobil Şube", '<div class="bk"><div class="bk-uyari">' + esc(hata(err)) + '</div>' + dugme("Yeniden dene", "mobilSubeEkrani()", "altin") + '</div>');
    }
    msCiz();
  }
  window.mobilSubeEkrani = function (s) { return mobilSube(typeof s === "string" ? s : null); };
  window.msSekme = function (s) { MS.sekme = s; MS.tumHareket = false; msCiz(); };
  window.msYenile = function () { return mobilSube(); };

  function msBekleyenSayi(v) {
    var b = v.bekleyen || {};
    var izinsiz = (v.kart_basvurulari || []).filter(function (x) { return (x.istenen || []).length && !(x.izin || []).length; }).length;
    return (b.teklifler || []).length + (b.bilgi || []).length + (b.kredi_bilgi || []).length + (b.pos || []).length + izinsiz;
  }

  function msCiz() {
    var v = MS.veri || {};
    var gec = (v.kartlar || []).some(function (k) { return Number(k.gecikmis_asgari) > 0; }) || (v.krediler || []).some(function (k) { return Number(k.geciken) > 0; });
    var html = '<div class="bk">';
    // genel müdürlük kısayolu (banka sahibi)
    if (MS.yon.length) {
      html += MS.yon.map(function (b) {
        return '<div class="bk-kimlik" style="' + renkVar(b.renk) + ';padding:14px 16px;margin-bottom:12px" role="button" tabindex="0" onclick="bankaGenelMudurlukEkrani(' + Number(b.id) + ')">' +
          '<p style="margin:0 0 2px;opacity:.85;font-size:12.5px">Banka Genel Müdürlüğü</p><h2 style="font-size:21px">' + esc(b.ad) + '</h2>' +
          '<p>' + (Number(b.bekleyen) ? Number(b.bekleyen) + " başvuru kararını bekliyor" : "Bekleyen başvuru yok") + ' · Güven notu ' + esc(b.not || "—") + '</p></div>';
      }).join("");
    }
    html += '<div class="bk-ust"><div><small>Toplam varlığın</small><div class="bk-tutar">' + tl(v.toplam && v.toplam.varlik) + '</div>' +
      '<div class="bk-ikili"><span>Bankada <b>' + tl(v.toplam && v.toplam.banka) + '</b></span><span>Borçların <b>' + tl(v.toplam && v.toplam.borc) + '</b></span></div></div>' +
      notHalka(v.kredi_notu || 1100, v.not_ad) + '</div>';
    if (v.kara_liste) html += '<div class="bk-uyari">Takibe düşen bir kredin yüzünden ' + esc(zaman(v.kara_liste)) + ' tarihine kadar yeni kredi alamazsın.</div>';
    if (gec) html += '<div class="bk-uyari">Gecikmiş bir ödemen var. Kredi notun her gün düşer; Kartlar ya da Krediler sekmesinden şimdi öde.</div>';
    var bs = msBekleyenSayi(v);
    html += sekmeler([["ozet", "Hesaplarım", bs || ""], ["kartlar", "Kartlar"], ["krediler", "Krediler"], ["birikim", "Birikim"], ["bankalar", "Bankalar"]], MS.sekme, "msSekme");
    if (MS.sekme === "kartlar") html += msKartlar(v);
    else if (MS.sekme === "krediler") html += msKrediler(v);
    else if (MS.sekme === "birikim") html += msBirikim(v);
    else if (MS.sekme === "bankalar") html += msBankalar(v);
    else html += msOzet(v);
    html += '</div>';
    ekran("Mobil Şube", html);
  }

  function hesapKartlari(v, tikla) {
    var h = '<div class="bk-kaydir">';
    var d = v.devlet || {};
    h += plastik({ renk: "devlet", banka: "Devlet Bankası", tur: "Vadesiz", bakiye: tl(d.vadesiz, 2), alt1: d.iban || "", alt2: "", onclick: tikla ? "msHesapDetay('devlet')" : "" });
    (v.hesaplar || []).forEach(function (a) {
      h += plastik({ renk: a.renk, banka: a.ad, tur: "Vadesiz", bakiye: tl(a.vadesiz, 2), alt1: a.iban || "", alt2: "", onclick: tikla ? "msHesapDetay('b:" + Number(a.banka_id) + "')" : "" });
    });
    h += '<button type="button" class="bk-plastik bk-yeni" onclick="msSekme(\'bankalar\')"><span style="font-size:26px;line-height:1">+</span>Yeni hesap aç</button>';
    return h + '</div>';
  }

  function msOzet(v) {
    var h = hesapKartlari(v, true);
    h += '<div class="bk-hizli">' +
      '<button type="button" onclick="msFastAc()"><span>↗</span>Para gönder</button>' +
      '<button type="button" onclick="msArasiAc()"><span>⇄</span>Hesaplar arası</button>' +
      '<button type="button" onclick="msSekme(\'kartlar\')"><span>▭</span>Kart borcu</button>' +
      '<button type="button" onclick="msKrediAc()"><span>₺</span>Kredi çek</button></div>';
    h += msBekleyenHtml(v);
    // cüzdan
    h += kutu("Cüzdan ve hesaplar",
      satir({ bas: "Cüzdan (nakit)", alt: "Maaş ve ödemeler buraya gelir", sag: tl(v.cuzdan) }) +
      satir({ renk: "devlet", bas: "Devlet Bankası", alt: "Vadesiz · " + esc((v.devlet || {}).iban || ""), sag: tl((v.devlet || {}).vadesiz, 2), onclick: "msHesapDetay('devlet')" }) +
      (v.hesaplar || []).map(function (a) {
        var ek = [];
        if (Number(a.vadeli)) ek.push("Birikim " + tlKisa(a.vadeli));
        if (Number(a.kredi)) ek.push("Kredi " + tlKisa(a.kredi));
        if (Number(a.kart)) ek.push("Kart " + tlKisa(a.kart));
        return satir({ renk: a.renk, bas: esc(a.ad), alt: "Vadesiz" + (ek.length ? " · " + ek.join(" · ") : ""), sag: tl(a.vadesiz, 2), onclick: "msHesapDetay('b:" + Number(a.banka_id) + "')" });
      }).join(""));
    h += msHareketler(v.hareketler || [], MS.tumHareket ? 60 : 10);
    return h;
  }

  function msBekleyenHtml(v) {
    var b = v.bekleyen || {}, ic = "";
    (b.teklifler || []).forEach(function (x) {
      ic += satir({ bas: esc(x.banka) + " sana kredi teklif etti", alt: tl(x.tutar) + " · " + x.vade_gun + " gün · " + x.taksit_sayisi + " taksit · %" + sayi(x.faiz, 2) + " faiz · " + kalanSure(x.son),
        sag: '<button class="btn altin" style="margin:0;padding:8px 12px;width:auto" onclick="msTeklif(' + Number(x.id) + ')">İncele</button>' });
    });
    (b.bilgi || []).forEach(function (x) {
      ic += satir({ bas: esc(x.banka) + " mali bilgi istiyor", alt: "İstenen: " + esc(etiketler(x.istenen)),
        sag: '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="msBilgi(' + Number(x.banka_id) + ')">Yanıtla</button>' });
    });
    (b.kredi_bilgi || []).forEach(function (x) {
      ic += satir({ bas: esc(x.banka) + " kredin için bilgi istiyor", alt: "İstenen: " + esc(etiketler(x.istenen)),
        sag: '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="msKrediBilgi(' + Number(x.kredi_id) + ')">Yanıtla</button>' });
    });
    (b.pos || []).forEach(function (x) {
      ic += satir({ bas: esc(x.sirket) + " ödeme bekliyor", alt: esc(x.aciklama || "Satış") + " · " + zaman(x.olusturma),
        sag: '<button class="btn altin" style="margin:0;padding:8px 12px;width:auto" onclick="msPos(' + Number(x.id) + ',' + Number(x.tutar) + ')">' + tl(x.tutar) + '</button>' });
    });
    (v.kart_basvurulari || []).filter(function (x) { return (x.istenen || []).length && !(x.izin || []).length; }).forEach(function (x) {
      ic += satir({ bas: esc(x.banka) + " kart başvurun için izin istiyor", alt: "Paylaşılacak: " + esc(etiketler(x.istenen)),
        sag: '<button class="btn altin" style="margin:0;padding:8px 12px;width:auto" onclick="msKartIzin(' + Number(x.id) + ',true)">İzin ver</button>' });
    });
    return ic ? kutu("Senden yanıt bekleyenler", ic) : "";
  }

  function msHareketler(liste, adet) {
    if (!liste.length) return kutu("Son hareketler", '<div class="bk-bos">Henüz banka hareketin yok.</div>');
    var h = liste.slice(0, adet).map(function (x) {
      var t = Number(x.tutar);
      return satir({ renk: x.renk, bas: esc(x.aciklama || "İşlem"), alt: esc(x.kaynak) + " · " + zaman(x.zaman),
        sag: '<span class="' + (t >= 0 ? "art" : "eks") + '">' + (t > 0 ? "+" : "") + tl(t, Math.abs(t) % 1 ? 2 : 0) + '</span>' });
    }).join("");
    if (liste.length > adet) h += '<div class="bk-dugmeler">' + dugme("Bütün hareketleri göster", "MS_tumHareket()") + '</div>';
    return kutu("Son hareketler", h);
  }
  window.MS_tumHareket = function () { MS.tumHareket = true; msCiz(); };

  window.msHesapDetay = function (anahtar) {
    var v = MS.veri || {}; var a, ad, rk, iban, bak;
    if (anahtar === "devlet") { ad = "Devlet Bankası"; rk = "devlet"; iban = (v.devlet || {}).iban; bak = (v.devlet || {}).vadesiz; }
    else {
      a = (v.hesaplar || []).find(function (x) { return "b:" + x.banka_id === anahtar; });
      if (!a) return;
      ad = a.ad; rk = a.renk; iban = a.iban; bak = a.vadesiz;
    }
    var hrk = (v.hareketler || []).filter(function (x) { return x.kaynak === ad; }).slice(0, 8);
    bmodal('<h3 style="font-size:19px;font-weight:800;margin-bottom:10px">' + esc(ad) + '</h3>' +
      '<div class="bk">' + plastik({ renk: rk, banka: ad, tur: "Vadesiz hesap", bakiye: tl(bak, 2), alt1: iban || "", cls: "bk-buyuk" }) + '</div>' +
      '<div class="bk-ozet">Hesap numarası (IBAN): <b>' + esc(iban || "") + '</b><br>Bu numara yalnız sende ve bu bankada geçerlidir.</div>' +
      '<div class="bk-cips" style="margin-top:10px"><button type="button" onclick="msArasiAc(\'cuzdan\',\'' + anahtar + '\')">Cüzdandan yatır</button>' +
      '<button type="button" onclick="msArasiAc(\'' + anahtar + '\',\'cuzdan\')">Cüzdana çek</button>' +
      '<button type="button" onclick="msFastAc(\'' + anahtar + '\')">Para gönder</button>' +
      (anahtar !== "devlet" ? '<button type="button" onclick="msHesapKapat(' + Number(anahtar.slice(2)) + ')">Hesabı kapat</button>' : '') + '</div>' +
      (hrk.length ? '<div class="bk"><div class="bk-kutu">' + hrk.map(function (x) {
        var t = Number(x.tutar);
        return satir({ bas: esc(x.aciklama || "İşlem"), alt: zaman(x.zaman), sag: '<span class="' + (t >= 0 ? "art" : "eks") + '">' + (t > 0 ? "+" : "") + tl(t, 2) + '</span>' });
      }).join("") + '</div></div>' : '') +
      '<button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
  };

  function hesapSecenekleri(v, cuzdanDahil, secili) {
    var o = [];
    if (cuzdanDahil) o.push(["cuzdan", "Cüzdan (nakit) · " + tl(v.cuzdan)]);
    o.push(["devlet", "Devlet Bankası · " + tl((v.devlet || {}).vadesiz, 2)]);
    (v.hesaplar || []).forEach(function (a) { o.push(["b:" + a.banka_id, a.ad + " · " + tl(a.vadesiz, 2)]); });
    return o.map(function (x) { return '<option value="' + esc(x[0]) + '"' + (x[0] === secili ? " selected" : "") + '>' + esc(x[1]) + '</option>'; }).join("");
  }

  /* ---- Para gönder (havale / EFT / FAST) ---- */
  var FAST = { alici: null, hedef: null };
  window.msFastAc = function (kaynak) {
    var v = MS.veri || {}; FAST = { alici: null, hedef: null };
    bmodal('<h3 style="font-size:19px;font-weight:800">Para gönder</h3>' +
      '<p class="alt" style="margin:4px 0 10px">Aynı banka havale, başka banka EFT, Devlet Bankası ile özel banka arası FAST olarak anında gider.</p>' +
      '<div class="alan"><label for="fsAlici">Alıcının kullanıcı adı</label><div style="display:flex;gap:8px"><input id="fsAlici" autocomplete="off" placeholder="örn. Ulaskonu16"><button class="btn ikinci" style="margin:0;width:auto;padding:0 14px" onclick="msFastBul(this)">Bul</button></div></div>' +
      '<div id="fsHedefler"></div>' +
      '<div class="alan"><label for="fsKaynak">Hangi hesabımdan</label><select id="fsKaynak" onchange="msFastOzet()">' + hesapSecenekleri(v, false, kaynak || "devlet") + '</select></div>' +
      '<div class="alan"><label for="fsTutar">Tutar (₺)</label><input id="fsTutar" inputmode="decimal" placeholder="0" oninput="msFastOzet()"></div>' +
      '<div class="alan"><label for="fsNot">Açıklama (isteğe bağlı)</label><input id="fsNot" maxlength="100" placeholder="örn. kira"></div>' +
      '<div id="fsOzet"></div>' +
      '<button class="btn" id="fsGonder" onclick="msFastGonder(this)">Gönder</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msFastBul = async function (btn) {
    var kad = val("fsAlici").trim();
    if (!kad) return bildir("Alıcının kullanıcı adını yaz.", true);
    try {
      var r = await calis(btn, function () { return API.rpc("banka_alici", { p_kad: kad }); });
      FAST.alici = r.kad; FAST.hedef = (r.hesaplar && r.hesaplar[0] && r.hesaplar[0].hedef) || "devlet";
      var kaynak = val("fsKaynak");
      var ayni = (r.hesaplar || []).find(function (h) { return h.hedef === kaynak; });
      if (ayni) FAST.hedef = ayni.hedef;
      $id("fsHedefler").innerHTML = '<label style="display:block;font-size:12.5px;color:var(--mut);margin-bottom:5px">' + esc(r.kad) + ' adlı oyuncunun hesapları</label><div class="bk-cips">' +
        (r.hesaplar || []).map(function (h) {
          return '<button type="button" data-h="' + esc(h.hedef) + '" class="' + (h.hedef === FAST.hedef ? "on" : "") + '" onclick="msFastHedef(\'' + esc(h.hedef) + '\')">' + esc(h.ad) + '</button>';
        }).join("") + '</div>';
      msFastOzet();
    } catch (_) {}
  };
  window.msFastHedef = function (h) {
    FAST.hedef = h;
    document.querySelectorAll("#fsHedefler button").forEach(function (b) { b.classList.toggle("on", b.getAttribute("data-h") === h); });
    msFastOzet();
  };
  window.msFastOzet = function () {
    var el = $id("fsOzet"); if (!el) return;
    if (!FAST.alici) { el.innerHTML = ""; return; }
    var k = val("fsKaynak"), h = FAST.hedef, t = parse(val("fsTutar"));
    var yol = k === h ? (k === "devlet" ? "Havale (Devlet Bankası içi)" : "Havale (aynı banka)") : (k !== "devlet" && h !== "devlet" ? "EFT (bankalar arası)" : "FAST (anında)");
    el.innerHTML = '<div class="bk-ozet">Yöntem: <b>' + yol + '</b>' + (t > 0 ? '<br>' + esc(FAST.alici) + ' alacak: <b>' + tl(t) + '</b>' : '') +
      (k !== h && (k === "devlet" || h === "devlet") ? '<br><small>Günlük aktarım sınırına sayılır.</small>' : '') + '</div>';
  };
  window.msFastGonder = async function (btn) {
    var t = parse(val("fsTutar"));
    if (!FAST.alici) return bildir("Önce alıcıyı bul.", true);
    if (!(t >= 100)) return bildir("En az 100 ₺ gönderebilirsin.", true);
    try {
      var r = await calis(btn, function () {
        return API.rpc("banka_fast", { p_kaynak: val("fsKaynak"), p_alici: FAST.alici, p_hedef: FAST.hedef, p_tutar: Math.round(t), p_aciklama: val("fsNot") || null });
      });
      kapat(); bildir(tl(r && r.tutar || t) + " " + FAST.alici + " adlı oyuncuya gönderildi.");
      mobilSube();
    } catch (_) {}
  };

  /* ---- Hesaplar arası ---- */
  window.msArasiAc = function (kaynak, hedef) {
    var v = MS.veri || {};
    bmodal('<h3 style="font-size:19px;font-weight:800">Hesaplarım arası</h3>' +
      '<p class="alt" style="margin:4px 0 10px">Cüzdan, Devlet Bankası ve özel banka hesapların arasında masrafsız aktarım.</p>' +
      '<div class="alan"><label for="haK">Nereden</label><select id="haK">' + hesapSecenekleri(v, true, kaynak || "cuzdan") + '</select></div>' +
      '<div class="alan"><label for="haH">Nereye</label><select id="haH">' + hesapSecenekleri(v, true, hedef || "devlet") + '</select></div>' +
      '<div class="alan"><label for="haT">Tutar (₺)</label><input id="haT" inputmode="decimal" placeholder="0"></div>' +
      '<button class="btn" onclick="msArasiYap(this)">Aktar</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msArasiYap = async function (btn) {
    var t = parse(val("haT"));
    if (!(t >= 1)) return bildir("Geçerli bir tutar gir.", true);
    try {
      await calis(btn, function () { return API.rpc("banka_hesaplar_arasi", { p_kaynak: val("haK"), p_hedef: val("haH"), p_tutar: Math.round(t) }); }, "Aktarım tamamlandı.");
      kapat(); mobilSube();
    } catch (_) {}
  };
  window.msHesapKapat = async function (banka) {
    if (!await sor("Hesabı kapat", "Bu bankadaki vadesiz hesabın kapanacak. Kredin ya da birikimin varsa önce onları kapatmalısın.", "Hesabı kapat", true)) return;
    try { await calis(null, function () { return API.rpc("oyb_hesap_kapat", { p_banka: banka }); }, "Hesap kapatıldı."); kapat(); mobilSube(); } catch (_) {}
  };

  /* ---- Yanıt bekleyenler ---- */
  window.msTeklif = function (id) {
    var x = ((MS.veri.bekleyen || {}).teklifler || []).find(function (t) { return Number(t.id) === Number(id); }); if (!x) return;
    var plan = x.plan || {}, tak = plan.taksitler || plan.plan || [];
    bmodal('<h3 style="font-size:19px;font-weight:800">' + esc(x.banka) + ' kredi teklifi</h3>' +
      (x.mesaj ? '<p class="alt" style="margin:6px 0">“' + esc(x.mesaj) + '”</p>' : '') +
      '<div class="bk-ozet">Tutar <b>' + tl(x.tutar) + '</b><br>Vade ' + x.vade_gun + ' gün, ' + x.taksit_sayisi + ' taksit<br>Toplam faiz %' + sayi(x.faiz, 2) +
      (plan.toplam ? '<br>Toplam geri ödeme <b>' + tl(plan.toplam) + '</b>' : '') + '<br>Son kabul: ' + zaman(x.son) + '</div>' +
      (Array.isArray(tak) && tak.length ? '<div class="bk-ozet">' + tak.slice(0, 6).map(function (k, i) { return (i + 1) + '. taksit ' + zaman(k.vade) + ' · <b>' + tl(k.tutar) + '</b>'; }).join("<br>") + (tak.length > 6 ? '<br>…' : '') + '</div>' : '') +
      '<button class="btn" onclick="msTeklifYanit(this,' + Number(id) + ',true)">Teklifi kabul et, parayı cüzdanıma yatır</button>' +
      '<button class="btn ikinci" onclick="msTeklifYanit(this,' + Number(id) + ',false)">Reddet</button>');
  };
  window.msTeklifYanit = async function (btn, id, kabul) {
    try { await calis(btn, function () { return API.rpc("oyb_kredi_teklif_yanit", { p_id: id, p_kabul: kabul }); }, kabul ? "Kredi cüzdanına yattı." : "Teklif reddedildi."); kapat(); mobilSube(); } catch (_) {}
  };
  window.msBilgi = async function (banka) {
    var x = ((MS.veri.bekleyen || {}).bilgi || []).find(function (b) { return Number(b.banka_id) === Number(banka); });
    var ok = await sor("Mali bilgi izni", esc(x ? x.banka : "Banka") + " şu bilgileri görmek istiyor: " + esc(etiketler(x && x.istenen)) + ". İzin verirsen kredi değerlendirmen hızlanır.", "İzin ver");
    try { await calis(null, function () { return API.rpc("oyb_hesap_bilgi_yanit", { p_banka: banka, p_onay: ok, p_kapsam: null }); }, ok ? "İzin verildi." : "Talep reddedildi."); mobilSube(); } catch (_) {}
  };
  window.msKrediBilgi = async function (kredi) {
    var ok = await sor("Kredi için bilgi izni", "Banka kredin için mali bilgilerini görmek istiyor. İzin verirsen başvurun daha hızlı değerlendirilir.", "İzin ver");
    try { await calis(null, function () { return API.rpc("oyb_bilgi_yanit", { p_kredi: kredi, p_onay: ok, p_kapsam: null }); }, ok ? "İzin verildi." : "Talep reddedildi."); mobilSube(); } catch (_) {}
  };
  window.msKartIzin = async function (id, ok) {
    try { await calis(null, function () { return API.rpc("kart_belge_yanit", { p_basvuru: id, p_onay: ok }); }, ok ? "Bilgi izni verildi; banka başvurunu değerlendirecek." : "İzin verilmedi."); mobilSube(); } catch (_) {}
  };
  window.msPos = function (id, tutar) {
    var kartlar = (MS.veri.kartlar || []).filter(function (k) { return k.durum === "aktif" && Number(k.kullanilabilir) >= Number(tutar); });
    bmodal('<h3 style="font-size:19px;font-weight:800">Ödeme: ' + tl(tutar) + '</h3>' +
      '<div class="alan"><label for="posKart">Nasıl ödeyeceksin?</label><select id="posKart"><option value="nakit">Cüzdandan nakit · ' + tl(MS.veri.cuzdan) + '</option>' +
      kartlar.map(function (k) { return '<option value="' + Number(k.id) + '">' + esc(k.banka) + ' kartı •••• ' + esc(k.son_dort) + ' · kalan limit ' + tl(k.kullanilabilir) + '</option>'; }).join("") + '</select></div>' +
      '<button class="btn" onclick="msPosOde(this,' + Number(id) + ')">Öde</button><button class="btn ikinci" onclick="msPosRed(this,' + Number(id) + ')">Reddet</button>');
  };
  window.msPosOde = async function (btn, id) {
    var k = val("posKart");
    try {
      await calis(btn, function () { return k === "nakit" ? API.rpc("ib_pos_nakit_ode", { p_talep: id }) : API.rpc("kart_pos_yanit", { p_pos: id, p_kart: Number(k) }); }, "Ödeme yapıldı.");
      kapat(); mobilSube();
    } catch (_) {}
  };
  window.msPosRed = async function (btn, id) {
    try { await calis(btn, function () { return API.rpc("kart_pos_yanit", { p_pos: id, p_kart: null }); }, "Ödeme talebi reddedildi."); kapat(); mobilSube(); } catch (_) {}
  };

  /* ---- Kartlar ---- */
  function msKartlar(v) {
    var h = "", kartlar = v.kartlar || [];
    if (!kartlar.length) h += '<div class="bk-bilgi">Henüz kredi kartın yok. Bir bankaya başvurduğunda kartın burada görünür.</div>';
    kartlar.forEach(function (k) {
      var dolu = Number(k.limit) ? Math.min(100, Number(k.borc) / Number(k.limit) * 100) : 0;
      var e = k.ekstre;
      var DY = { aktif: "", donduruldu: "Donduruldu", kapali: "Kapatıldı", nakit_kapali: "Nakit avansa kapalı", takip: "Yasal takipte" };
      var durumYazi = Object.prototype.hasOwnProperty.call(DY, k.durum) ? DY[k.durum] : k.durum;
      h += '<div>' + plastik({ renk: k.renk, banka: k.banka, tur: "Kredi kartı", cip: true, cls: "bk-buyuk" + (k.durum !== "aktif" ? " dondu" : ""),
        bakiye: tl(k.kullanilabilir), bakiyeAlt: "kullanılabilir limit", alt1: "•••• •••• •••• " + k.son_dort, alt2: durumYazi }) + '</div>';
      var ic = '<div style="padding:12px 0 4px"><div class="bk-cubuk" style="--c:' + (dolu > 85 ? "var(--al)" : dolu > 60 ? "var(--warn)" : "var(--good)") + '"><i style="width:' + dolu.toFixed(1) + '%"></i></div>' +
        '<small style="color:var(--mut);font-size:12.5px">Borç ' + tl(k.borc, 2) + ' / limit ' + tl(k.limit) + '</small></div>';
      if (e) ic += satir({ bas: "Dönem borcu", alt: "Son ödeme " + zaman(e.son_odeme) + " · " + kalanSure(e.son_odeme), sag: tl(Number(e.toplam) - Number(e.odenen), 2), sagAlt: "Asgari " + tl(Math.max(0, Number(e.asgari) - Number(e.odenen)), 2) });
      if (Number(k.gecikmis_asgari) > 0) ic += '<div class="bk-uyari" style="margin:8px 0">Gecikmiş asgari ödeme: ' + tl(k.gecikmis_asgari, 2) + '. Ödemezsen kart kapanır ve kredi notun düşer.</div>';
      if (Number(k.nakit_avans) > 0) ic += satir({ bas: "Nakit avans bakiyesi", alt: "Günlük faiz işler", sag: tl(k.nakit_avans, 2) });
      ic += '<div class="bk-dugmeler">' + dugme("Borç öde", "msKartOde(" + Number(k.id) + ")", "altin") +
        (k.durum === "aktif" ? dugme("Nakit avans", "msAvans(" + Number(k.id) + ")") : "") +
        (k.durum === "aktif" || k.durum === "donduruldu" ? dugme(k.durum === "donduruldu" ? "Kartı aç" : "Kartı dondur", "msDondur(" + Number(k.id) + "," + (k.durum !== "donduruldu") + ")") : "") + '</div>';
      if ((k.hareketler || []).length) ic += (k.hareketler || []).slice(0, 5).map(function (a) {
        var od = a.tur === "odeme";
        return satir({ bas: esc(a.aciklama || a.tur), alt: zaman(a.zaman), sag: '<span class="' + (od ? "art" : "eks") + '">' + (od ? "+" : "−") + tl(a.tutar, 2) + '</span>' });
      }).join("");
      h += kutu("", ic);
    });
    var bas = v.kart_basvurulari || [];
    if (bas.length) h += kutu("Başvurularım", bas.map(function (b) {
      var izinBekliyor = (b.istenen || []).length && !(b.izin || []).length;
      return satir({ bas: esc(b.banka) + " · " + tl(b.istek) + " limit", alt: izinBekliyor ? "Banka mali bilgi izni bekliyor" : "Bankanın kararı bekleniyor · " + zaman(b.basvuru),
        sag: izinBekliyor ? '<button class="btn altin" style="margin:0;padding:8px 12px;width:auto" onclick="msKartIzin(' + Number(b.id) + ',true)">İzin ver</button>' : '<span class="bk-rozet s">Bekliyor</span>' });
    }).join(""));
    h += '<div class="bk-dugmeler">' + dugme("Yeni kart başvurusu", "msKartBasvur()", "altin") + '</div>';
    h += '<p class="bk-ipucu">Kart faizleri ve asgari ödeme oranları yasal tavanlarla sabittir. En fazla 2 aktif kartın olabilir; aynı bankadan ikinci kart verilmez.</p>';
    return h;
  }
  window.msKartOde = function (id) {
    var k = (MS.veri.kartlar || []).find(function (x) { return Number(x.id) === Number(id); }); if (!k) return;
    var e = k.ekstre || {}, asg = Math.max(0, Number(e.asgari || 0) - Number(e.odenen || 0)), donem = Math.max(0, Number(e.toplam || 0) - Number(e.odenen || 0));
    bmodal('<h3 style="font-size:19px;font-weight:800">Kart borcu öde</h3><p class="alt" style="margin:4px 0 10px">Ödeme cüzdanından yapılır (' + tl(MS.veri.cuzdan) + ').</p>' +
      '<div class="bk-cips">' + (asg > 0 ? '<button type="button" onclick="document.getElementById(\'koT\').value=\'' + asg.toFixed(2) + '\'">Asgari ' + tl(asg, 2) + '</button>' : '') +
      (donem > 0 ? '<button type="button" onclick="document.getElementById(\'koT\').value=\'' + donem.toFixed(2) + '\'">Dönem ' + tl(donem, 2) + '</button>' : '') +
      '<button type="button" onclick="document.getElementById(\'koT\').value=\'' + Number(k.borc).toFixed(2) + '\'">Tüm borç ' + tl(k.borc, 2) + '</button></div>' +
      '<div class="alan"><label for="koT">Tutar (₺)</label><input id="koT" inputmode="decimal"></div>' +
      '<button class="btn" onclick="msKartOdeYap(this,' + Number(id) + ')">Öde</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msKartOdeYap = async function (btn, id) {
    var t = parse(val("koT")); if (!(t > 0)) return bildir("Ödeme tutarını gir.", true);
    try { await calis(btn, function () { return API.rpc("kart_ode", { p_kart: id, p_tutar: Math.round(t * 100) / 100 }); }, "Kart borcu ödendi."); kapat(); mobilSube("kartlar"); } catch (_) {}
  };
  window.msAvans = function (id) {
    bmodal('<h3 style="font-size:19px;font-weight:800">Nakit avans</h3><p class="alt" style="margin:4px 0 10px">Para cüzdanına geçer. İşlem masrafı alınır ve günlük faiz işler.</p>' +
      '<div class="alan"><label for="avT">Tutar (₺)</label><input id="avT" inputmode="decimal"></div>' +
      '<button class="btn" onclick="msAvansYap(this,' + Number(id) + ')">Nakit çek</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msAvansYap = async function (btn, id) {
    var t = parse(val("avT")); if (!(t >= 100)) return bildir("En az 100 ₺ çekebilirsin.", true);
    try { await calis(btn, function () { return API.rpc("kart_nakit_avans", { p_kart: id, p_tutar: Math.round(t * 100) / 100 }); }, "Nakit avans cüzdanına geçti."); kapat(); mobilSube("kartlar"); } catch (_) {}
  };
  window.msDondur = async function (id, dondur) {
    try { await calis(null, function () { return API.rpc("kart_dondur", { p_kart: id, p_dondur: dondur }); }, dondur ? "Kart donduruldu." : "Kart yeniden açıldı."); mobilSube("kartlar"); } catch (_) {}
  };
  window.msKartBasvur = function () {
    var v = MS.veri || {};
    var bankalar = (v.bankalar || []).filter(function (b) { return b && b.hesabim && !b.bankam; });
    bmodal('<h3 style="font-size:19px;font-weight:800">Kredi kartı başvurusu</h3>' +
      '<p class="alt" style="margin:4px 0 10px">Özel bankalarda önce hesabın olmalı. Banka mali bilgilerini görmek isteyebilir.</p>' +
      '<div class="alan"><label for="kbB">Banka</label><select id="kbB"><option value="">Devlet Bankası</option>' +
      bankalar.map(function (b) { return '<option value="' + Number(b.id) + '">' + esc(b.ad) + (b.kart_otomatik ? " · anında karar" : "") + '</option>'; }).join("") + '</select></div>' +
      '<div class="alan"><label for="kbL">İstediğin limit (₺)</label><input id="kbL" inputmode="numeric" placeholder="örn. 50.000"></div>' +
      '<button class="btn" onclick="msKartBasvurYap(this)">Başvur</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msKartBasvurYap = async function (btn) {
    var l = parse(val("kbL")); if (!(l >= 1000)) return bildir("En az 1.000 ₺ limit iste.", true);
    var b = val("kbB");
    try { await calis(btn, function () { return API.rpc("kart_basvur", { p_banka: b ? Number(b) : null, p_limit: Math.round(l) }); }, "Başvurun alındı."); kapat(); mobilSube("kartlar"); } catch (_) {}
  };

  /* ---- Krediler ---- */
  function msKrediler(v) {
    var h = "", ks = v.krediler || [], dk = (v.devlet || {}).kredi;
    if (dk) {
      h += kutu("Devlet Bankası kredisi", satir({ renk: "devlet", bas: "Kalan borç " + tl(dk.kalan), alt: "Günlük taksit " + tl(dk.taksit) + (Number(dk.gecikmis) ? " · gecikmiş " + tl(dk.gecikmis) : "") + " · " + dk.gun + " gün",
        sag: dk.erken_kapama ? tl(dk.erken_kapama) : null, sagAlt: dk.erken_kapama ? "erken kapama" : null }) +
        '<div class="bk-dugmeler">' + dugme("Ödeme yap", "msDevletKrediOde()", "altin") + '</div>');
    }
    if (!ks.length && !dk) h += '<div class="bk-bilgi">Aktif kredin yok. Banka seçip paketleri karşılaştırarak anında ya da onaylı kredi çekebilirsin.</div>';
    ks.forEach(function (k) {
      if (k.durum === "basvuru") {
        h += kutu("", satir({ renk: k.renk, bas: esc(k.banka) + " · " + tl(k.anapara), alt: "Başvurun bankanın kararını bekliyor · " + zaman(k.basvuru), sag: '<span class="bk-rozet s">Bekliyor</span>' }) +
          '<div class="bk-dugmeler">' + dugme("Başvuruyu geri çek", "msKrediIptal(" + Number(k.id) + ")") + '</div>');
        return;
      }
      var odenen = Number(k.odenen_taksit || 0), top = Number(k.taksit_sayisi || 1);
      var ic = satir({ renk: k.renk, bas: esc(k.banka) + " kredisi", alt: tl(k.anapara) + " çekildi · " + k.vade_gun + " gün · " + top + " taksit", sag: tl(k.kalan, 2), sagAlt: "kalan" }) +
        '<div style="padding:2px 0 10px"><div class="bk-cubuk" style="--c:var(--good)"><i style="width:' + (odenen / top * 100).toFixed(1) + '%"></i></div><small style="color:var(--mut);font-size:12.5px">' + odenen + ' / ' + top + ' taksit ödendi</small></div>';
      if (k.siradaki) ic += satir({ bas: "Sıradaki taksit", alt: zaman(k.siradaki.vade) + " · " + kalanSure(k.siradaki.vade), sag: tl(k.siradaki.kalan, 2) });
      if (Number(k.geciken) > 0) ic += '<div class="bk-uyari" style="margin:8px 0">Geciken taksit: ' + tl(k.geciken, 2) + '. 12 saati geçerse banka icra takibi başlatabilir.</div>';
      if (k.icra) ic += '<div class="bk-uyari" style="margin:8px 0">Bu kredi için icra dosyası var (' + esc(k.icra) + ').</div>';
      ic += '<div class="bk-dugmeler">' + dugme("Taksit öde", "msKrediOde(" + Number(k.id) + ")", "altin") +
        (k.erken_kapama ? dugme("Erken kapat · " + tl(k.erken_kapama), "msErkenKapat(" + Number(k.id) + "," + Number(k.erken_kapama) + ")") : "") + '</div>';
      h += kutu("", ic);
    });
    h += '<div class="bk-dugmeler">' + dugme("Kredi başvurusu", "msKrediAc()", "altin") + '</div>';
    h += '<p class="bk-ipucu">Her bankanın kendi kredi paketleri vardır. Gelirin, kredi notun ve diğer borçların limitini belirler; bankalar kasalarını göstermez, güven notlarını gösterir.</p>';
    return h;
  }
  window.msKrediOde = function (id) {
    var k = (MS.veri.krediler || []).find(function (x) { return Number(x.id) === Number(id); }); if (!k) return;
    var sira = k.siradaki ? Number(k.siradaki.kalan) : 0, gec = Number(k.geciken || 0);
    bmodal('<h3 style="font-size:19px;font-weight:800">Kredi ödemesi</h3><p class="alt" style="margin:4px 0 10px">Cüzdanından ödenir (' + tl(MS.veri.cuzdan) + ').</p><div class="bk-cips">' +
      (gec > 0 ? '<button type="button" onclick="document.getElementById(\'kdT\').value=\'' + gec.toFixed(2) + '\'">Geciken ' + tl(gec, 2) + '</button>' : '') +
      (sira > 0 ? '<button type="button" onclick="document.getElementById(\'kdT\').value=\'' + sira.toFixed(2) + '\'">Sıradaki ' + tl(sira, 2) + '</button>' : '') +
      '<button type="button" onclick="document.getElementById(\'kdT\').value=\'' + Number(k.kalan).toFixed(2) + '\'">Tümü ' + tl(k.kalan, 2) + '</button></div>' +
      '<div class="alan"><label for="kdT">Tutar (₺)</label><input id="kdT" inputmode="decimal"></div>' +
      '<button class="btn" onclick="msKrediOdeYap(this,' + Number(id) + ')">Öde</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msKrediOdeYap = async function (btn, id) {
    var t = parse(val("kdT")); if (!(t > 0)) return bildir("Ödeme tutarını gir.", true);
    try { await calis(btn, function () { return API.rpc("oyb_kredi_ode", { p_id: id, p_tutar: Math.round(t * 100) / 100 }); }, "Ödeme alındı."); kapat(); mobilSube("krediler"); } catch (_) {}
  };
  window.msErkenKapat = async function (id, tutar) {
    if (!await sor("Krediyi erken kapat", "Kalan borcun " + tl(tutar) + " ödenerek kapanacak. Kullanılmayan günlerin faizi alınmaz.", "Kapat")) return;
    try { await calis(null, function () { return API.rpc("oyb_kredi_erken_kapat", { p_id: id }); }, "Kredi kapandı."); mobilSube("krediler"); } catch (_) {}
  };
  window.msKrediIptal = async function (id) {
    try { await calis(null, function () { return API.rpc("oyb_kredi_basvuru_iptal", { p_id: id }); }, "Başvuru geri çekildi."); mobilSube("krediler"); } catch (_) {}
  };
  window.msDevletKrediOde = function () {
    var dk = (MS.veri.devlet || {}).kredi || {};
    bmodal('<h3 style="font-size:19px;font-weight:800">Devlet Bankası kredisi</h3>' +
      '<div class="bk-cips"><button type="button" onclick="document.getElementById(\'dkT\').value=\'' + Number(dk.taksit || 0) + '\'">Günlük taksit ' + tl(dk.taksit) + '</button>' +
      (dk.erken_kapama ? '<button type="button" onclick="document.getElementById(\'dkT\').value=\'' + Number(dk.erken_kapama) + '\'">Erken kapama ' + tl(dk.erken_kapama) + '</button>' : '') + '</div>' +
      '<div class="alan"><label for="dkT">Tutar (₺)</label><input id="dkT" inputmode="numeric"></div>' +
      '<button class="btn" onclick="msDevletKrediOdeYap(this)">Öde</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msDevletKrediOdeYap = async function (btn) {
    var t = parse(val("dkT")); if (!(t > 0)) return bildir("Ödeme tutarını gir.", true);
    try { await calis(btn, function () { return API.rpc("kredi_ode", { p_miktar: Math.round(t) }); }, "Ödeme alındı."); kapat(); mobilSube("krediler"); } catch (_) {}
  };

  // Kredi başvurusu sihirbazı: banka → paket → tutar → plan → onay
  var KR = { banka: null, masa: null, paket: null };
  window.msKrediAc = function () {
    var v = MS.veri || {};
    var bankalar = (v.bankalar || []).filter(function (b) { return b && !b.bankam; });
    bmodal('<h3 style="font-size:19px;font-weight:800">Kredi başvurusu</h3><p class="alt" style="margin:4px 0 10px">Banka seç; paketleri, faizleri ve sana özel limitini gör.</p>' +
      '<div class="bk"><div class="bk-kutu">' +
      satir({ renk: "devlet", bas: "Devlet Bankası", alt: "Günlük taksitli ihtiyaç kredisi", sag: '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="msDevletKredi()">Seç</button>' }) +
      bankalar.map(function (b) {
        return satir({ renk: b.renk, bas: esc(b.ad) + " " + gnRozet(b.not), alt: (b.paket_sayisi ? b.paket_sayisi + " paket · en düşük faiz %" + sayi(b.en_dusuk_kredi, 2) : "Paket yok · günlük faiz %" + sayi(b.kredi24, 2)) + (b.hesabim ? "" : " · önce hesap aç"),
          sag: '<button class="btn ' + (b.hesabim ? "altin" : "ikinci") + '" style="margin:0;padding:8px 12px;width:auto" onclick="msKrediBanka(' + Number(b.id) + ')">' + (b.hesabim ? "Seç" : "Hesap aç") + '</button>' });
      }).join("") + '</div></div><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msKrediBanka = async function (id) {
    var b = (MS.veri.bankalar || []).find(function (x) { return x && Number(x.id) === Number(id); });
    if (b && !b.hesabim) {
      try { await calis(null, function () { return API.rpc("oyb_hesap_ac", { p_banka: id }); }, b.ad + " hesabın açıldı."); await msYukle(); } catch (_) { return; }
    }
    try {
      KR.masa = await API.rpc("oyb_kredi_masasi", { p_banka: id }); KR.banka = id; KR.paket = null;
    } catch (err) { return bildir(hata(err), true); }
    var m = KR.masa || {}, pk = (m.paketler || []).filter(function (p) { return p.aktif; });
    bmodal('<h3 style="font-size:19px;font-weight:800">' + esc((m.banka || {}).ad || "Banka") + ' kredi paketleri</h3>' +
      '<p class="alt" style="margin:4px 0 10px">Kredi notun ' + sayi(m.kredi_notu) + ' (' + esc(m.not_ad || "") + ').' + (m.baska_kredi ? ' Başka bir bankada aktif kredin ya da başvurun var.' : '') + '</p>' +
      (pk.length ? '<div class="bk"><div class="bk-kutu">' + pk.map(function (p) {
        var uygun = Number(m.kredi_notu) >= Number(p.min_not || 0) && Number(p.limitim) >= Number(p.min_tutar);
        return satir({ bas: esc(p.ad) + (p.otomatik ? ' <span class="bk-rozet y">Anında</span>' : ''), alt: p.vade_gun + " gün · " + p.taksit_sayisi + " taksit · toplam %" + sayi(p.faiz, 2) + " · " + tlKisa(p.min_tutar) + "–" + tlKisa(p.max_tutar) + (Number(p.min_not) ? " · not ≥ " + p.min_not : ""),
          sag: uygun ? '<button class="btn altin" style="margin:0;padding:8px 12px;width:auto" onclick="msKrediPaket(' + Number(p.id) + ')">Seç</button>' : '<span class="bk-rozet k">Uygun değil</span>', sagAlt: uygun ? "limitin " + tlKisa(p.limitim) : "" });
      }).join("") + '</div></div>' : '<div class="bk-ozet">Bu banka henüz paket tanımlamamış. Banka sana özel teklif gönderebilir.</div>') +
      '<button class="btn ikinci" onclick="msKrediAc()">Başka banka seç</button>');
  };
  window.msKrediPaket = function (pid) {
    var p = ((KR.masa || {}).paketler || []).find(function (x) { return Number(x.id) === Number(pid); }); if (!p) return;
    KR.paket = p;
    var ust = Math.min(Number(p.max_tutar), Number(p.limitim));
    bmodal('<h3 style="font-size:19px;font-weight:800">' + esc(p.ad) + '</h3>' +
      '<div class="bk-ozet">' + p.vade_gun + ' gün vade, ' + p.taksit_sayisi + ' eşit taksit, toplam faiz %' + sayi(p.faiz, 2) + '<br>Çekebileceğin: ' + tl(p.min_tutar) + ' – ' + tl(ust) + '</div>' +
      '<div class="alan"><label for="kpT">Tutar (₺)</label><input id="kpT" inputmode="numeric" placeholder="' + sayi(ust) + '"></div>' +
      '<div id="kpPlan"></div>' +
      '<button class="btn ikinci" onclick="msKrediPlan(this)">Ödeme planını gör</button>' +
      '<button class="btn" onclick="msKrediCek(this)">' + (p.otomatik ? "Krediyi çek" : "Başvur") + '</button>');
  };
  window.msKrediPlan = async function (btn) {
    var t = parse(val("kpT")); if (!(t > 0)) return bildir("Tutarı gir.", true);
    try {
      var r = await calis(btn, function () { return API.rpc("oyb_kredi_plan", { p_paket: KR.paket.id, p_tutar: Math.round(t) }); });
      var plan = r.plan || r, tak = plan.taksitler || plan.plan || [];
      $id("kpPlan").innerHTML = '<div class="bk-ozet">' + (r.engel ? '<b style="color:var(--al2)">' + esc(r.engel) + '</b><br>' : '') +
        (plan.toplam ? 'Toplam geri ödeme <b>' + tl(plan.toplam) + '</b><br>' : '') +
        (Array.isArray(tak) ? tak.slice(0, 8).map(function (k, i) { return (i + 1) + '. taksit ' + zaman(k.vade) + ' · ' + tl(k.tutar); }).join("<br>") : '') + '</div>';
    } catch (_) {}
  };
  window.msKrediCek = async function (btn) {
    var t = parse(val("kpT")); if (!(t > 0)) return bildir("Tutarı gir.", true);
    try {
      var r = await calis(btn, function () { return API.rpc("oyb_kredi_cek", { p_paket: KR.paket.id, p_tutar: Math.round(t) }); });
      kapat(); bildir(r && (r.durum === "aktif" || r.vade) ? "Kredi cüzdanına yattı." : "Başvurun bankaya iletildi.");
      mobilSube("krediler");
    } catch (_) {}
  };
  window.msDevletKredi = function () {
    bmodal('<h3 style="font-size:19px;font-weight:800">Devlet Bankası kredisi</h3><p class="alt" style="margin:4px 0 10px">Günlük eşit taksitle geri ödenir; gecikirse günlük %1 gecikme faizi işler.</p>' +
      '<div class="alan"><label for="dvT">Tutar (₺)</label><input id="dvT" inputmode="numeric"></div>' +
      '<div class="alan"><label for="dvG">Vade</label><select id="dvG"><option value="7">7 gün</option><option value="14">14 gün</option><option value="15">15 gün</option><option value="21">21 gün</option><option value="28">28 gün</option><option value="30" selected>30 gün</option></select></div>' +
      '<button class="btn" onclick="msDevletKrediCek(this)">Krediyi çek</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.msDevletKrediCek = async function (btn) {
    var t = parse(val("dvT")); if (!(t > 0)) return bildir("Tutarı gir.", true);
    try { await calis(btn, function () { return API.rpc("kredi_cek", { p_miktar: Math.round(t), p_gun: Number(val("dvG")) }); }, "Kredi cüzdanına yattı."); kapat(); mobilSube("krediler"); } catch (_) {}
  };

  /* ---- Birikim ---- */
  function msBirikim(v) {
    var d = v.devlet || {}, h = "", dv = d.vadeliler || [], mv = v.mevduatlar || [];
    if (!dv.length && !mv.length) h += '<div class="bk-bilgi">Paran cüzdanında boş durmasın. Vadeli hesap açarsan vade sonunda faiziyle geri alırsın.</div>';
    if (dv.length) h += kutu("Devlet Bankası vadeli", dv.map(function (x) {
      var saat = x.vade_saat || (x.gun ? x.gun * 24 : null);
      return satir({ renk: "devlet", bas: tl(x.anapara) + " · " + (saat ? saat + " saat" : "") + " · %" + sayi(x.oran, 3), alt: "Vade " + zaman(x.vade) + " · " + kalanSure(x.vade),
        sag: '+' + tl(x.biriken, 2), sagAlt: '<a href="#" onclick="msVadeliBoz(' + Number(x.id) + ');return false" style="color:var(--ink2)">Boz</a>' });
    }).join(""));
    if (mv.length) h += kutu("Özel bankalardaki birikimlerim", mv.map(function (x) {
      return satir({ renk: x.renk, bas: esc(x.banka) + " · " + tl(x.anapara), alt: (x.saat >= 168 ? "7 gün" : x.saat + " saat") + " · %" + sayi(x.oran, 2) + " · " + (x.vadesi_doldu ? "vadesi doldu" : kalanSure(x.vade)),
        sag: '+' + tl(x.getiri, 2), sagAlt: '<a href="#" onclick="msMevduatCek(' + Number(x.id) + ',' + (!!x.vadesi_doldu) + ');return false" style="color:var(--ink2)">' + (x.vadesi_doldu ? "Tahsil et" : "Boz") + '</a>' });
    }).join(""));
    // faiz karşılaştırma
    var o = d.oranlar || {};
    var kar = [["devlet", "Devlet Bankası", o.vadeli24s, "devlet"]];
    (v.bankalar || []).forEach(function (b) { if (b) kar.push(["b:" + b.id, b.ad, (b.vadeler || {})["24"], b.renk, b.mevduat7, b.not, b.bankam]); });
    h += kutu("Faiz karşılaştırması (24 saat)", kar.map(function (k) {
      return satir({ renk: k[3], bas: esc(k[1]) + (k[5] ? " " + gnRozet(k[5]) : ""), alt: k[4] != null ? "7 gün: %" + sayi(k[4], 2) : "Politika faizine bağlı", sag: yuzde(k[2], 3) });
    }).join(""));
    h += '<div class="bk-dugmeler">' + dugme("Yeni birikim hesabı", "msBirikimAc()", "altin") + '</div>';
    return h;
  }
  window.msBirikimAc = function () {
    var v = MS.veri || {};
    var bankalar = (v.bankalar || []).filter(function (b) { return b && !b.bankam; });
    bmodal('<h3 style="font-size:19px;font-weight:800">Yeni birikim hesabı</h3><p class="alt" style="margin:4px 0 10px">Para cüzdanından çekilir; vade sonunda faiziyle geri döner.</p>' +
      '<div class="alan"><label for="biB">Banka</label><select id="biB" onchange="msBirikimHesap()"><option value="devlet">Devlet Bankası</option>' +
      bankalar.map(function (b) { return '<option value="' + Number(b.id) + '">' + esc(b.ad) + ' · güven notu ' + esc(b.not || "—") + (b.hesabim ? "" : " · hesap açılır") + '</option>'; }).join("") + '</select></div>' +
      '<div class="alan"><label for="biV">Vade</label><select id="biV" onchange="msBirikimHesap()"></select></div>' +
      '<div class="alan"><label for="biT">Tutar (₺)</label><input id="biT" inputmode="numeric" placeholder="en az 1.000" oninput="msBirikimHesap()"></div>' +
      '<div id="biOzet"></div><button class="btn" onclick="msBirikimYap(this)">Birikimi başlat</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    msBirikimHesap(true);
  };
  window.msBirikimHesap = function (ilk) {
    var v = MS.veri || {}, b = val("biB"), sel = $id("biV"); if (!sel) return;
    var secenek, oran;
    if (b === "devlet") {
      var o = (v.devlet || {}).oranlar || {};
      secenek = [[1, "1 saat", o.vadeli1s], [3, "3 saat", o.vadeli3s], [6, "6 saat", o.vadeli6s], [12, "12 saat", o.vadeli12s], [24, "24 saat", o.vadeli24s]];
    } else {
      var bk = (v.bankalar || []).find(function (x) { return x && String(x.id) === b; }) || {}, vv = bk.vadeler || {};
      secenek = [[1, "1 saat", vv["1"]], [6, "6 saat", vv["6"]], [24, "24 saat", vv["24"]], [168, "7 gün", bk.mevduat7]];
    }
    var onceki = sel.value;
    sel.innerHTML = secenek.map(function (s) { return '<option value="' + s[0] + '">' + s[1] + ' · %' + sayi(s[2], 3) + '</option>'; }).join("");
    if (!ilk && secenek.some(function (s) { return String(s[0]) === onceki; })) sel.value = onceki;
    var sc = secenek.find(function (s) { return String(s[0]) === sel.value; }) || secenek[0];
    oran = Number(sc[2] || 0);
    var t = parse(val("biT"));
    $id("biOzet").innerHTML = t > 0 ? '<div class="bk-ozet">Vade sonunda <b>' + tl(t * (1 + oran / 100), 2) + '</b> (faiz +' + tl(t * oran / 100, 2) + ')</div>' : '';
  };
  window.msBirikimYap = async function (btn) {
    var b = val("biB"), saat = Number(val("biV")), t = parse(val("biT"));
    if (!(t >= 1000)) return bildir("En az 1.000 ₺ ile birikim başlatılır.", true);
    try {
      await calis(btn, async function () {
        if (b === "devlet") return API.rpc("vadeli_ac", { p_miktar: Math.round(t), p_gun: saat });
        var bk = (MS.veri.bankalar || []).find(function (x) { return x && String(x.id) === b; });
        if (bk && !bk.hesabim) await API.rpc("oyb_hesap_ac", { p_banka: Number(b) });
        return API.rpc("oyb_yatir", { p_banka: Number(b), p_tutar: Math.round(t), p_saat: saat });
      }, "Birikim hesabın açıldı.");
      kapat(); mobilSube("birikim");
    } catch (_) {}
  };
  window.msVadeliBoz = async function (id) {
    if (!await sor("Vadeli hesabı boz", "Vade dolmadan bozarsan faizin bir kısmını kaybedersin.", "Boz", true)) return;
    try { await calis(null, function () { return API.rpc("vadeli_boz", { p_id: id }); }, "Vadeli hesap kapandı."); mobilSube("birikim"); } catch (_) {}
  };
  window.msMevduatCek = async function (id, doldu) {
    if (!doldu && !await sor("Birikimi boz", "Vade dolmadan çekersen yalnız anaparanı alırsın; faiz ödenmez.", "Boz", true)) return;
    try { await calis(null, function () { return API.rpc("oyb_mevduat_cek", { p_id: id }); }, doldu ? "Birikimin faiziyle cüzdanına geçti." : "Anapara cüzdanına geçti."); mobilSube("birikim"); } catch (_) {}
  };

  /* ---- Bankalar ---- */
  function msBankalar(v) {
    var h = '<p class="bk-ipucu">Bankaların kasaları gizlidir. Seçim yaparken bağımsız güven notuna, faizlere ve paketlere bak.</p>';
    var d = (v.devlet || {}).oranlar || {};
    h += kutu("", satir({ renk: "devlet", bas: "Devlet Bankası", alt: "Politika faizi %" + sayi(d.politika, 1) + " · 24 saat vadeli %" + sayi(d.vadeli24s, 3) + " · herkesin hesabı açık", sag: '<span class="bk-rozet y">Hesabın var</span>' }));
    (v.bankalar || []).forEach(function (b) {
      if (!b) return;
      var ic = '<div class="bk-satir" style="border-top:0"><span class="bk-nokta" style="' + renkVar(b.renk) + ';width:14px;height:14px"></span><span class="bk-orta"><b style="font-size:16px">' + esc(b.ad) + '</b>' +
        (b.slogan ? '<small>“' + esc(b.slogan) + '”</small>' : '<small>' + sayi(b.musteri) + ' müşteri</small>') + '</span>' + gnRozet(b.not) + '</div>';
      ic += satir({ bas: "7 gün vadeli mevduat", sag: yuzde(b.mevduat7) }) + satir({ bas: "24 saat vadeli", sag: yuzde((b.vadeler || {})["24"], 3) }) +
        satir({ bas: "Kredi", alt: b.paket_sayisi ? b.paket_sayisi + " paket" + (b.kredi_otomatik ? " · anında karar" : "") : "Günlük faiz", sag: b.paket_sayisi ? "%" + sayi(b.en_dusuk_kredi, 2) + "'den" : yuzde(b.kredi24) }) +
        satir({ bas: "Kredi kartı", alt: b.kart_otomatik ? "Anında değerlendirme" : "Banka elle değerlendirir", sag: "" });
      ic += '<div class="bk-dugmeler">' + (b.bankam ? '<button class="btn" onclick="bankaGenelMudurlukEkrani(' + Number(b.id) + ')">Genel Müdürlük</button>' :
        b.hesabim ? '<span class="bk-rozet y" style="align-self:center">Hesabın var</span>' + dugme("Kredi paketleri", "msKrediBanka(" + Number(b.id) + ")") :
          dugme("Hesap aç", "msHesapAc(" + Number(b.id) + ")", "altin")) + '</div>';
      ic += '<div class="bk-dugmeler">' + dugme("Mevduat, kredi ve şube işlemleri", "ekranAc(function(){return bankaDetayEkrani(" + Number(b.id) + ")})", "ikinci") + '</div>';
      h += kutu("", ic);
    });
    if (!(v.bankalar || []).length) h += '<div class="bk-bos">Henüz oyuncuların kurduğu banka yok.</div>';
    h += '<div class="bk-dugmeler">' + dugme("Kendi bankanı kur", "msBankaKur()") + '</div>';
    return h;
  }
  window.msHesapAc = async function (id) {
    if (!await sor("Hesap aç", "Bu bankada kendi adına vadesiz hesap açılacak. Hesap açmak ücretsizdir.", "Hesap aç")) return;
    try { await calis(null, function () { return API.rpc("oyb_hesap_ac", { p_banka: id }); }, "Hesabın açıldı."); mobilSube("ozet"); } catch (_) {}
  };
  window.msBankaKur = function () {
    if (typeof window.bankaKurEkrani === "function") return ekranAc(window.bankaKurEkrani);
    if (typeof window.sirketKurModal === "function") return window.sirketKurModal("banka");
    bildir("Banka kurmak için Ekonomi › Şirketlerim › Şirket kur (sektör: banka, en az 1.000.000 ₺ sermaye).");
  };

  /* =====================================================================
     BANKA GENEL MÜDÜRLÜĞÜ (banka sahibi)
     ===================================================================== */
  var GM = { id: null, sekme: "ozet", veri: null, ara: "" };
  async function gmYukle() { GM.veri = await API.rpc("banka_genel_mudurluk", { p_banka: GM.id }); }
  async function genelMudurluk(id, sekme) {
    stilKur();
    if (id) GM.id = Number(id);
    if (sekme) GM.sekme = sekme;
    if (!GM.id) return bankaYonetimMerkezi();
    if (typeof yukleniyor === "function") yukleniyor("Genel Müdürlük");
    try { await gmYukle(); }
    catch (err) { return ekran("Genel Müdürlük", '<div class="bk"><div class="bk-uyari">' + esc(hata(err)) + '</div>' + dugme("Yeniden dene", "bankaGenelMudurlukEkrani(" + GM.id + ")", "altin") + '</div>'); }
    gmCiz();
  }
  window.bankaGenelMudurlukEkrani = function (id, sekme) {
    GM.id = Number(id) || GM.id; GM.sekme = sekme || "ozet"; GM.ara = "";
    var f = function () { return genelMudurluk(); };
    if (typeof ekranAc === "function") return ekranAc(f);
    return f();
  };
  window.gmSekme = function (s) { GM.sekme = s; gmCiz(); };
  window.gmYenile = function () { return genelMudurluk(); };

  async function bankaYonetimMerkezi() {
    stilKur();
    if (typeof yukleniyor === "function") yukleniyor("Bankalarım");
    var liste = [];
    try { liste = (await API.rpc("banka_yonettiklerim")) || []; }
    catch (err) { return ekran("Bankalarım", '<div class="bk"><div class="bk-uyari">' + esc(hata(err)) + '</div></div>'); }
    if (liste.length === 1) { GM.id = Number(liste[0].id); GM.sekme = "ozet"; return genelMudurluk(GM.id); }
    var h = '<div class="bk">';
    if (!liste.length) h += '<div class="bk-bilgi">Ortağı olduğun bir banka yok. Bir banka kurabilir ya da bir bankanın hissesini alabilirsin.</div>' + dugme("Kendi bankanı kur", "msBankaKur()", "altin");
    liste.forEach(function (b) {
      h += '<div class="bk-kimlik" style="' + renkVar(b.renk) + '" role="button" tabindex="0" onclick="bankaGenelMudurlukEkrani(' + Number(b.id) + ')"><h2>' + esc(b.ad) + '</h2><p>' +
        (Number(b.bekleyen) ? Number(b.bekleyen) + " başvuru bekliyor" : "Bekleyen başvuru yok") + (b.yonetebilir ? "" : " · yalnız izleme yetkin var") + '</p>' +
        '<div class="bk-harf"><b>' + esc(b.not || "—") + '</b><small>güven notu</small></div></div>';
    });
    ekran("Bankalarım", h + '</div>');
  }
  window.bankaYonetimMerkezi = bankaYonetimMerkezi;

  function gmCiz() {
    var v = GM.veri || {}, b = v.banka || {}, bil = v.bilanco || {}, be = v.bekleyen || {};
    var bekSayi = (be.krediler || []).length + (be.kartlar || []).length + (be.poslar || []).length;
    var h = '<div class="bk">';
    h += '<div class="bk-kimlik" style="' + renkVar(b.renk) + '"><p style="margin:0 0 2px">Genel Müdürlük</p><h2>' + esc(b.ad) + '</h2>' +
      '<p>' + (b.slogan ? "“" + esc(b.slogan) + "”" : "Kuruluş " + esc(zaman(b.kurulus))) + '</p>' +
      '<div class="bk-harf"><b style="color:' + (NOT_RENK[bil.not] || "#fff") + '">' + esc(bil.not || "—") + '</b><small>güven notu</small></div>' +
      '<div class="bk-km"><div><small>Kasa</small><b>' + tlKisa(bil.nakit) + '</b></div><div><small>Özkaynak</small><b>' + tlKisa(bil.ozkaynak) + '</b></div><div><small>Kredi verebilir</small><b>' + tlKisa(bil.kredi_verilebilir) + '</b></div></div></div>';
    if (!b.yonetebilir) h += '<div class="bk-bilgi">Bu bankanın ortağısın; karar vermek için yönetici ya da en az %50 ortak olman gerekir. Tabloları izleyebilirsin.</div>';
    h += sekmeler([["ozet", "Özet"], ["basvuru", "Başvurular", bekSayi || ""], ["kasa", "Kasa ve kâr"], ["urun", "Ürünler"], ["musteri", "Müşteriler"], ["ayar", "Kimlik ve ayarlar"]], GM.sekme, "gmSekme");
    if (GM.sekme === "basvuru") h += gmBasvurular(v);
    else if (GM.sekme === "kasa") h += gmKasa(v);
    else if (GM.sekme === "urun") h += gmUrunler(v);
    else if (GM.sekme === "musteri") h += gmMusteriler(v);
    else if (GM.sekme === "ayar") h += gmAyarlar(v);
    else h += gmOzet(v);
    ekran(b.ad || "Genel Müdürlük", h + '</div>');
  }

  function oranSatiri(ad, deger, bicim, dolu, renkKod, aciklama) {
    return '<div class="bk-oran"><div class="bk-ob"><span>' + ad + '</span><b>' + bicim + '</b></div>' +
      '<div class="bk-cubuk" style="--c:' + renkKod + '"><i style="width:' + Math.max(2, Math.min(100, dolu)).toFixed(0) + '%"></i></div><small>' + aciklama + '</small></div>';
  }
  function gmOzet(v) {
    var bil = v.bilanco || {}, be = v.bekleyen || {}, g7 = v.gelir7 || {}, g30 = v.gelir30 || {};
    var bek = (be.krediler || []).length + (be.kartlar || []).length + (be.poslar || []).length;
    var durumCumle = { saglam: "Bankan sağlam.", dikkat: "Bankan dikkat istiyor.", riskli: "Bankan riskli bölgede." }[bil.durum] || "";
    var h = '<div class="' + (bil.durum === "riskli" ? "bk-uyari" : "bk-bilgi") + '">' + durumCumle + " " +
      (bek ? bek + " başvuru kararını bekliyor. " : "Bekleyen başvuru yok. ") +
      (Number(bil.geciken_mevduat) > 0 ? "Vadesi gelmiş " + tl(bil.geciken_mevduat) + " mevduat ödemesi var; kasayı güçlendir. " : "") +
      (Number(bil.krediler_geciken) > 0 ? tl(bil.krediler_geciken) + " kredi gecikmede." : "") + '</div>';
    if (bek) h += '<div class="bk-dugmeler">' + dugme("Başvuruları aç", "gmSekme('basvuru')", "altin") + '</div>';
    // oranlar
    var lik = bil.likidite, syr = bil.sermaye_yeterlilik, npl = Number(bil.takipteki_oran || 0), km = bil.kredi_mevduat;
    h += kutu("Bankacılık oranları",
      oranSatiri("Likidite", lik, lik == null ? "Borç yok" : sayi(lik, 2) + " kat", lik == null ? 100 : lik / 2 * 100, lik == null || lik >= 1.2 ? "var(--good)" : lik >= 1 ? "var(--warn)" : "var(--al)", "Kasa, hemen ödenebilecek mevduatın kaç katı. 1,2 katın üstü güvenli.") +
      oranSatiri("Sermaye yeterliliği", syr, syr == null ? "Riskli varlık yok" : "%" + sayi(syr, 1), syr == null ? 100 : syr / 30 * 100, syr == null || syr >= 15 ? "var(--good)" : syr >= 12 ? "var(--warn)" : "var(--al)", "Özkaynağın risk ağırlıklı kredilere oranı. Yasal alt sınır %12.") +
      oranSatiri("Takipteki alacaklar", npl, "%" + sayi(npl, 1), npl * 4, npl <= 5 ? "var(--good)" : npl <= 15 ? "var(--warn)" : "var(--al)", "Geciken kredi ve kart borçlarının toplam alacağa oranı.") +
      oranSatiri("Kredi / mevduat", km, km == null ? "Mevduat yok" : "%" + sayi(km, 0), km == null ? 0 : km / 2, km == null || km <= 120 ? "var(--ink2)" : "var(--warn)", "Topladığın mevduatın ne kadarını krediye çevirdiğin."));
    // bilanço
    h += '<div class="bk-bil"><div><h4>Varlıklar</h4>' +
      '<div class="bk-bs"><span>Kasa</span><b>' + tlKisa(bil.nakit) + '</b></div>' +
      '<div class="bk-bs"><span>Krediler</span><b>' + tlKisa(bil.krediler) + '</b></div>' +
      '<div class="bk-bs"><span>Kart alacağı</span><b>' + tlKisa(bil.kart_alacak) + '</b></div>' +
      '<div class="bk-bs"><span>DİBS</span><b>' + tlKisa(bil.dibs) + '</b></div>' +
      '<div class="bk-bs bk-top"><span>Toplam</span><b>' + tlKisa(bil.varlik) + '</b></div></div>' +
      '<div><h4>Borçlar ve özkaynak</h4>' +
      '<div class="bk-bs"><span>Vadesiz mevduat</span><b>' + tlKisa(bil.vadesiz) + '</b></div>' +
      '<div class="bk-bs"><span>Vadeli mevduat</span><b>' + tlKisa(bil.vadeli_yukumluluk) + '</b></div>' +
      '<div class="bk-bs"><span>Sermaye</span><b>' + tlKisa(bil.sermaye) + '</b></div>' +
      '<div class="bk-bs"><span>Birikmiş kâr</span><b>' + tlKisa(bil.birikmis_kar) + '</b></div>' +
      '<div class="bk-bs bk-top"><span>Toplam</span><b>' + tlKisa(Number(bil.borc) + Number(bil.ozkaynak)) + '</b></div></div></div>';
    // gelir tablosu
    var gelir = function (g) {
      return [["Kredi faizi", g.kredi_faiz], ["Kart faizi", g.kart_faiz], ["POS komisyonu", g.pos_komisyon], ["DİBS getirisi", g.dibs], ["Faaliyet sonucu", g.faaliyet], ["Mevduat faizi", -Number(g.mevduat_faiz || 0)]];
    };
    var g7l = gelir(g7), g30l = gelir(g30);
    h += kutu("Gelir tablosu", '<div class="bk-satir" style="border-top:0;font-size:12.5px;color:var(--mut)"><span class="bk-orta"></span><span class="bk-sag" style="width:90px;font-weight:600">7 gün</span><span class="bk-sag" style="width:90px;font-weight:600">30 gün</span></div>' +
      g7l.map(function (r, i) {
        return '<div class="bk-satir"><span class="bk-orta"><b style="font-weight:500">' + r[0] + '</b></span><span class="bk-sag" style="width:90px">' + tlKisa(r[1]) + '</span><span class="bk-sag" style="width:90px">' + tlKisa(g30l[i][1]) + '</span></div>';
      }).join("") +
      '<div class="bk-satir"><span class="bk-orta"><b>Net kâr</b></span><span class="bk-sag" style="width:90px;color:' + (Number(g7.net) >= 0 ? "var(--good)" : "var(--al2)") + '">' + tlKisa(g7.net) + '</span><span class="bk-sag" style="width:90px;color:' + (Number(g30.net) >= 0 ? "var(--good)" : "var(--al2)") + '">' + tlKisa(g30.net) + '</span></div>');
    // hareketler
    var hr = (v.hareketler || []).slice(0, 12);
    h += kutu("Son kasa ve müşteri hareketleri", hr.length ? hr.map(function (x) {
      var t = Number(x.tutar);
      return satir({ bas: esc(x.aciklama), alt: (x.tur === "musteri" ? "Müşteri hesabı · " : "Banka kasası · ") + zaman(x.zaman), sag: t ? '<span class="' + (t >= 0 ? "art" : "eks") + '">' + (t > 0 ? "+" : "") + tlKisa(t) + '</span>' : "" });
    }).join("") : '<div class="bk-bos">Henüz hareket yok.</div>');
    return h;
  }

  function gmBasvurular(v) {
    var be = v.bekleyen || {}, b = v.banka || {}, yon = !!b.yonetebilir, h = "";
    var kr = be.krediler || [], ka = be.kartlar || [], po = be.poslar || [];
    if (!kr.length && !ka.length && !po.length) h += '<div class="bk-bos">Bekleyen başvuru yok. Otomatik onayı açarsan uygun başvurular anında sonuçlanır (Ürünler sekmesi).</div>';
    if (kr.length) h += kutu("Kredi başvuruları", kr.map(function (k) {
      var r = k.risk || {}, uygun = r.uygun !== false && Number(k.anapara) <= Number(r.azami_kredi || 0);
      return satir({ bas: esc(k.kad) + ' <span class="bk-rozet">' + sayi(k.not) + '</span>', alt: tl(k.anapara) + " · " + k.vade_gun + " gün · " + (k.taksit_sayisi || 1) + " taksit · %" + sayi(k.oran, 2) + " faiz · geri ödeme " + tl(k.toplam),
          sag: uygun ? '<span class="bk-rozet y">Uygun</span>' : '<span class="bk-rozet k">Riskli</span>', sagAlt: "azami " + tlKisa(r.azami_kredi) }) +
        '<p class="bk-ipucu" style="margin:0 0 6px">' + esc(r.neden || "") + (r.haftalik_gelir != null ? " · haftalık gelir " + tl(r.haftalik_gelir) : "") + (k.hesap === false ? " · hesabını kapatmış" : "") + '</p>' +
        (yon ? '<div class="bk-dugmeler">' + dugme("Onayla, parayı gönder", "gmKrediKarar(this," + Number(k.id) + ",true)", "altin") + dugme("Reddet", "gmKrediKarar(this," + Number(k.id) + ",false)") + '</div>' : '');
    }).join(""));
    if (ka.length) h += kutu("Kredi kartı başvuruları", ka.map(function (x) {
      var kap = x.kapasite || {}, bi = x.bilgi || {}, izinli = (x.izin || []).length > 0;
      var oneri = Math.max(0, Math.min(Number(x.istek), Number(kap.ek_limit || 0)));
      return satir({ bas: esc(x.kad), alt: "İstenen limit " + tl(x.istek) + " · " + zaman(x.basvuru), sag: kap.uygun ? '<span class="bk-rozet y">Uygun</span>' : '<span class="bk-rozet k">' + esc(kap.neden || "Uygun değil") + '</span>' }) +
        (izinli ? '<p class="bk-ipucu" style="margin:0 0 6px">Kredi notu ' + sayi(bi.kredi_notu) + ' · haftalık gelir ' + tl(bi.haftalik_gelir) + ' · nakit ' + tl(bi.nakit) + ' · önerilen limit ' + tl(oneri) + '</p>' :
          '<p class="bk-ipucu" style="margin:0 0 6px">Müşteri henüz mali bilgi izni vermedi.</p>') +
        (yon ? '<div class="bk-dugmeler">' + (izinli ? '<input id="gmKL' + Number(x.id) + '" inputmode="numeric" value="' + Math.round(oneri || x.istek) + '" aria-label="Limit" style="flex:1 1 110px;background:var(--panel2);border:1px solid var(--line2);border-radius:11px;padding:10px;color:var(--txt)">' +
          dugme("Kartı ver", "gmKartKarar(this," + Number(x.id) + ",true)", "altin") : dugme("Bilgi iste", "gmKartBilgi(this," + Number(x.id) + ")", "altin")) + dugme("Reddet", "gmKartKarar(this," + Number(x.id) + ",false)") + '</div>' : '');
    }).join(""));
    if (po.length) h += kutu("POS cihazı başvuruları", po.map(function (x) {
      return satir({ bas: esc(x.sirket), alt: esc(x.kad) + " · " + esc(sektorAd(x.sektor)) + " · " + zaman(x.basvuru) + (x.hesap === false ? " · başvuranın hesabı yok" : ""), sag: "%2 komisyon" }) +
        (yon ? '<div class="bk-dugmeler">' + (x.hesap === false ? '' : dugme("POS ver", "gmPosKarar(this," + Number(x.id) + ",true)", "altin")) + dugme("Reddet", "gmPosKarar(this," + Number(x.id) + ",false)") + '</div>' : '');
    }).join(""));
    return h;
  }
  window.gmKrediKarar = async function (btn, id, onay) {
    try { await calis(btn, function () { return API.rpc("oyb_kredi_karar", { p_id: id, p_onay: onay }); }, onay ? "Kredi kullandırıldı." : "Başvuru reddedildi."); genelMudurluk(); } catch (_) {}
  };
  window.gmKartKarar = async function (btn, id, onay) {
    var l = onay ? parse(val("gmKL" + id)) : null;
    if (onay && !(l >= 1000)) return bildir("Kart limiti en az 1.000 ₺ olmalı.", true);
    try { await calis(btn, function () { return API.rpc("kart_basvuru_karar", { p_basvuru: id, p_onay: onay, p_limit: onay ? Math.round(l) : null }); }, onay ? "Kart verildi." : "Başvuru reddedildi."); genelMudurluk(); } catch (_) {}
  };
  window.gmKartBilgi = async function (btn, id) {
    try { await calis(btn, function () { return API.rpc("kart_belge_iste", { p_basvuru: id, p_alanlar: ["kredi_notu", "maas", "nakit", "mulk", "sirket"] }); }, "Bilgi talebi müşteriye gitti."); genelMudurluk(); } catch (_) {}
  };
  window.gmPosKarar = async function (btn, id, onay) {
    try { await calis(btn, function () { return API.rpc("pos_basvuru_karar", { p_pos: id, p_onay: onay }); }, onay ? "POS cihazı verildi." : "Başvuru reddedildi."); genelMudurluk(); } catch (_) {}
  };

  function gmKasa(v) {
    var b = v.banka || {}, bil = v.bilanco || {}, yon = !!b.yonetebilir, oran = v.dibs_oran || {}, h = "";
    var ben = (b.ortaklar || []).find(function (o) { return o.ben; });
    h += kutu("Kasa", satir({ bas: "Kasadaki nakit", alt: "Müşteri mevduatı da bu kasadadır", sag: tl(bil.nakit) }) +
      satir({ bas: "Yasal rezerv ve tampon", alt: "Mevduat sahiplerinin güvencesi; kullanılamaz", sag: tl(bil.rezerv) }) +
      satir({ bas: "Emniyet payın", alt: "Otomatik kredilerde dokunulmayan tutar", sag: tl(bil.emniyet_payi) }) +
      satir({ bas: "Kredi verebileceğin", sag: tl(bil.kredi_verilebilir) }));
    // para koy / al
    h += kutu("Para koy, kâr al",
      satir({ bas: "Sermaye koy", alt: "Cüzdanından bankaya; payların değişmez, kredi kapasiten büyür", sag: '<button class="btn altin" style="margin:0;padding:8px 12px;width:auto" onclick="gmSermayeKoy()">Koy</button>' }) +
      satir({ bas: "Kâr payı dağıt", alt: "Dağıtılabilir " + tl(bil.dagitilabilir_kar) + " · %15 stopaj Hazine'ye", sag: yon ? '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="gmKarDagit()">Dağıt</button>' : '' }) +
      satir({ bas: "Sermaye azalt", alt: "Azaltılabilir " + tl(bil.sermaye_azaltilabilir) + " · vergisiz iade, sermaye 1 Mn ₺ altına inemez", sag: yon ? '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="gmSermayeAzalt()">Azalt</button>' : '' }) +
      (ben ? satir({ bas: "Haftalık kârım", alt: ben.kar_kasada ? "Payım bankada birikiyor (kredi kapasitesi büyür)" : "Payım her hafta cüzdanıma geçiyor", sag: '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="gmKarTercih(' + (!ben.kar_kasada) + ')">' + (ben.kar_kasada ? "Cüzdana geçsin" : "Bankada biriksin") + '</button>' }) : ''));
    // DİBS
    var acik = (v.dibs || []).filter(function (d) { return d.durum === "acik"; });
    var dibsIc = '<p class="bk-ipucu" style="margin:8px 0">Atıl parayı devlet tahviline yatır; risksizdir, vade sonunda kasaya kendiliğinden döner. Politika faizi %' + sayi(v.politika_faizi, 1) + '.</p>' +
      '<div class="bk-secim">' + [["1", "1 gün"], ["7", "7 gün"], ["30", "30 gün"]].map(function (g) {
        return '<button type="button" onclick="gmDibsAl(' + g[0] + ')"' + (yon ? '' : ' disabled') + '><b>' + g[1] + ' · %' + sayi(oran[g[0]], 3) + '</b><small>100.000 ₺ → +' + tl(1000 * Number(oran[g[0]] || 0), 0) + '</small></button>';
      }).join("") + '<button type="button" disabled><b>Alınabilir</b><small>' + tl(bil.dibs_alinabilir) + '</small></button></div>';
    dibsIc += acik.map(function (d) {
      return satir({ bas: tl(d.tutar) + " · " + d.gun + " gün · %" + sayi(d.oran, 3), alt: "Vade " + zaman(d.vade) + " · " + kalanSure(d.vade), sag: "+" + tl(d.getiri, 2), sagAlt: yon ? '<a href="#" onclick="gmDibsBoz(' + Number(d.id) + ');return false" style="color:var(--ink2)">Vadeden önce sat</a>' : '' });
    }).join("");
    h += kutu("DİBS (devlet tahvili)", dibsIc);
    // temettü geçmişi
    var tm = v.temettuler || [];
    if (tm.length) h += kutu("Dağıtım geçmişi", tm.map(function (x) {
      return satir({ bas: x.tur === "temettu" ? "Kâr payı" : "Sermaye iadesi", alt: esc(x.yapan || "") + " · " + zaman(x.zaman), sag: tl(x.brut), sagAlt: Number(x.stopaj) ? "stopaj " + tl(x.stopaj) : "" });
    }).join(""));
    return h;
  }
  window.gmSermayeKoy = function () {
    bmodal('<h3 style="font-size:19px;font-weight:800">Bankaya sermaye koy</h3><p class="alt" style="margin:4px 0 10px">Para cüzdanından banka kasasına geçer ve sermayeye eklenir. Ortaklık payları değişmez.</p>' +
      '<div class="alan"><label for="gmSK">Tutar (₺)</label><input id="gmSK" inputmode="numeric"></div>' +
      '<button class="btn" onclick="gmSermayeKoyYap(this)">Sermaye koy</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.gmSermayeKoyYap = async function (btn) {
    var t = parse(val("gmSK")); if (!(t >= 1)) return bildir("Tutarı gir.", true);
    try { await calis(btn, function () { return API.rpc("banka_sermaye_koy", { p_banka: GM.id, p_tutar: Math.round(t) }); }, "Sermaye kasaya eklendi."); kapat(); genelMudurluk(); } catch (_) {}
  };
  window.gmKarDagit = function () {
    var bil = (GM.veri || {}).bilanco || {}, ort = ((GM.veri || {}).banka || {}).ortaklar || [];
    bmodal('<h3 style="font-size:19px;font-weight:800">Kâr payı dağıt</h3><p class="alt" style="margin:4px 0 10px">Ortaklara paylarına göre dağıtılır; %15 stopaj kesilip Hazine\'ye aktarılır. Dağıtılabilir: <b>' + tl(bil.dagitilabilir_kar) + '</b></p>' +
      '<div class="bk-cips"><button type="button" onclick="document.getElementById(\'gmKD\').value=\'' + Math.floor(Number(bil.dagitilabilir_kar || 0) / 2) + '\';gmKarOnizle()">Yarısı</button><button type="button" onclick="document.getElementById(\'gmKD\').value=\'' + Math.floor(Number(bil.dagitilabilir_kar || 0)) + '\';gmKarOnizle()">Tamamı</button></div>' +
      '<div class="alan"><label for="gmKD">Brüt tutar (₺)</label><input id="gmKD" inputmode="numeric" oninput="gmKarOnizle()"></div><div id="gmKDo"></div>' +
      '<button class="btn" onclick="gmKarDagitYap(this)">Dağıt</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    window.gmKarOnizle = function () {
      var t = parse(val("gmKD")), el = $id("gmKDo"); if (!el) return;
      el.innerHTML = t > 0 ? '<div class="bk-ozet">' + ort.map(function (o) { var br = Math.round(t * o.pay / 100); return esc(o.kad) + " (%" + sayi(o.pay, 2) + "): net <b>" + tl(br - Math.round(br * 0.15)) + "</b>"; }).join("<br>") + '</div>' : '';
    };
  };
  window.gmKarDagitYap = async function (btn) {
    var t = parse(val("gmKD")); if (!(t >= 1000)) return bildir("En az 1.000 ₺ dağıtılabilir.", true);
    try { var r = await calis(btn, function () { return API.rpc("banka_kar_dagit", { p_banka: GM.id, p_tutar: Math.round(t) }); }); kapat(); bildir("Dağıtıldı: net " + tl(r.net) + ", stopaj " + tl(r.stopaj) + "."); genelMudurluk(); } catch (_) {}
  };
  window.gmSermayeAzalt = function () {
    var bil = (GM.veri || {}).bilanco || {};
    bmodal('<h3 style="font-size:19px;font-weight:800">Sermaye azalt</h3><p class="alt" style="margin:4px 0 10px">Ortaklara paylarına göre vergisiz iade edilir. En fazla <b>' + tl(bil.sermaye_azaltilabilir) + '</b>.</p>' +
      '<div class="alan"><label for="gmSA">Tutar (₺)</label><input id="gmSA" inputmode="numeric"></div>' +
      '<button class="btn" onclick="gmSermayeAzaltYap(this)">Sermayeyi azalt</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.gmSermayeAzaltYap = async function (btn) {
    var t = parse(val("gmSA")); if (!(t >= 10000)) return bildir("En az 10.000 ₺ azaltılabilir.", true);
    try { await calis(btn, function () { return API.rpc("banka_sermaye_azalt", { p_banka: GM.id, p_tutar: Math.round(t) }); }, "Sermaye ortaklara iade edildi."); kapat(); genelMudurluk(); } catch (_) {}
  };
  window.gmKarTercih = async function (kasada) {
    try { await calis(null, function () { return API.rpc("sirket_kar_birikim_ayarla", { p_sirket: GM.id, p_kasada: kasada }); }, kasada ? "Kâr payın bankada birikecek." : "Kâr payın cüzdanına geçecek."); genelMudurluk(); } catch (_) {}
  };
  window.gmDibsAl = function (gun) {
    var bil = (GM.veri || {}).bilanco || {}, o = ((GM.veri || {}).dibs_oran || {})[String(gun)];
    bmodal('<h3 style="font-size:19px;font-weight:800">' + gun + ' gün vadeli DİBS</h3><p class="alt" style="margin:4px 0 10px">Getiri %' + sayi(o, 3) + '. En fazla ' + tl(bil.dibs_alinabilir) + ' alınabilir.</p>' +
      '<div class="alan"><label for="gmDB">Tutar (₺)</label><input id="gmDB" inputmode="numeric" placeholder="en az 10.000"></div>' +
      '<button class="btn" onclick="gmDibsAlYap(this,' + Number(gun) + ')">Tahvil al</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.gmDibsAlYap = async function (btn, gun) {
    var t = parse(val("gmDB")); if (!(t >= 10000)) return bildir("En az 10.000 ₺ DİBS alınabilir.", true);
    try { var r = await calis(btn, function () { return API.rpc("banka_dibs_al", { p_banka: GM.id, p_tutar: Math.round(t), p_gun: gun }); }); kapat(); bildir("DİBS alındı; vade sonunda +" + tl(r.getiri, 2) + " getiri."); genelMudurluk(); } catch (_) {}
  };
  window.gmDibsBoz = async function (id) {
    if (!await sor("Tahvili vadeden önce sat", "Getiri alınmaz ve %0,2 kırım uygulanır.", "Sat", true)) return;
    try { await calis(null, function () { return API.rpc("banka_dibs_boz", { p_banka: GM.id, p_id: id }); }, "Tahvil satıldı, para kasaya döndü."); genelMudurluk(); } catch (_) {}
  };

  function gmUrunler(v) {
    var b = v.banka || {}, u = v.urunler || {}, ot = u.otomatik || {}, yon = !!b.yonetebilir, dis = yon ? "" : " disabled", h = "";
    var prof = b.risk_profili || "ozel";
    h += kutu("Risk profili", '<p class="bk-ipucu" style="margin:8px 0">Tek dokunuşla otomatik onay kurallarını ayarla. Sonra aşağıdan tek tek değiştirebilirsin.</p><div class="bk-secim">' +
      [["temkinli", "Temkinli", "Not ≥ 1.500 · en fazla 100 B ₺ otomatik"], ["dengeli", "Dengeli", "Not ≥ 1.100 · en fazla 300 B ₺ otomatik"], ["atak", "Atak", "Not ≥ 900 · en fazla 1 Mn ₺ otomatik"], ["manuel", "Her şeye ben karar veririm", "Otomatik onay kapalı"]].map(function (p) {
        return '<button type="button" class="' + (prof === p[0] ? "on" : "") + '" onclick="gmRisk(\'' + p[0] + '\')"' + dis + '><b>' + p[1] + '</b><small>' + p[2] + '</small></button>';
      }).join("") + '</div>');
    h += kutu("Otomatik onay", '<div class="bk-form" style="padding:8px 0">' +
      '<div class="bk-secim">' + [["pos", "POS cihazı", ot.pos], ["kart", "Kredi kartı", ot.kart], ["kredi", "Kredi", ot.kredi]].map(function (x) {
        return '<button type="button" id="gmOt_' + x[0] + '" class="' + (x[2] ? "on" : "") + '" onclick="this.classList.toggle(\'on\')"' + dis + '><b>' + x[1] + '</b><small>' + (x[2] ? "Otomatik" : "Elle") + '</small></button>';
      }).join("") + '</div>' +
      '<div class="alan"><label for="gmMN">Otomatik onay için asgari kredi notu (650–1.900)</label><input id="gmMN" inputmode="numeric" value="' + Number(u.asgari_not || 850) + '"' + dis + '></div>' +
      '<div class="alan"><label for="gmKM">Otomatik verilecek en yüksek kart limiti (₺)</label><input id="gmKM" inputmode="numeric" value="' + Number(u.kart_max || 500000) + '"' + dis + '></div>' +
      '<div class="alan"><label for="gmKrM">Otomatik verilecek en yüksek kredi (₺)</label><input id="gmKrM" inputmode="numeric" value="' + Number(u.kredi_max || 500000) + '"' + dis + '></div>' +
      (yon ? '<button class="btn" onclick="gmOtomatikKaydet(this)">Kuralları kaydet</button>' : '') + '</div>');
    var vd = u.vadeler || {};
    h += kutu("Mevduat faizleri", '<div class="bk-form" style="padding:8px 0">' +
      '<div class="alan"><label for="gmM7">7 gün vadeli (en fazla %1,8)</label><input id="gmM7" inputmode="decimal" value="' + sayi(u.mevduat7, 2) + '"' + dis + '></div>' +
      '<div class="bk-secim">' + [["1", "1 saat", 0.03], ["3", "3 saat", 0.07], ["6", "6 saat", 0.12], ["12", "12 saat", 0.18], ["24", "24 saat", 0.30]].map(function (x) {
        return '<div style="background:var(--panel2);border-radius:12px;padding:8px 10px"><label for="gmV' + x[0] + '" style="margin-bottom:3px">' + x[1] + ' (en fazla %' + sayi(x[2], 2) + ')</label><input id="gmV' + x[0] + '" inputmode="decimal" value="' + sayi(vd[x[0]], 2) + '"' + dis + ' style="padding:8px"></div>';
      }).join("") + '</div>' +
      (yon ? '<button class="btn" onclick="gmMevduatKaydet(this)">Faizleri kaydet</button>' : '') + '</div>');
    h += kutu("Kredi", satir({ bas: "Paketsiz kredi günlük faizi", alt: "Paket dışındaki başvurularda 24 saatlik faiz (en fazla %1)", sag: '<input id="gmK24" inputmode="decimal" value="' + sayi(u.kredi24, 2) + '"' + dis + ' style="width:80px;background:var(--panel2);border:1px solid var(--line2);border-radius:9px;padding:8px;color:var(--txt);text-align:right">' }) +
      (yon ? '<div class="bk-dugmeler">' + dugme("Günlük faizi kaydet", "gmKrediFaiz(this)") + '</div>' : '') +
      ((u.paketler || []).length ? (u.paketler || []).map(function (p) {
        return satir({ bas: esc(p.ad) + (p.aktif ? "" : ' <span class="bk-rozet">Pasif</span>') + (p.otomatik ? ' <span class="bk-rozet y">Anında</span>' : ''), alt: p.vade_gun + " gün · " + p.taksit_sayisi + " taksit · toplam %" + sayi(p.faiz, 2) + " · " + tlKisa(p.min_tutar) + "–" + tlKisa(p.max_tutar) + " · not ≥ " + p.min_not + " · " + p.kullanan + " aktif",
          sag: yon ? '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="gmPaket(' + Number(p.id) + ')">Düzenle</button>' : '' });
      }).join("") : '<div class="bk-bos">Kredi paketi yok. Paket tanımlarsan müşteriler kendi limitleriyle başvurur.</div>') +
      (yon ? '<div class="bk-dugmeler">' + dugme("Yeni kredi paketi", "gmPaket(0)", "altin") + '</div>' : ''));
    h += kutu("Kredi kartı ve POS", satir({ bas: "Kart faizleri", alt: "Yasal tavana bağlı: aylık %3,25–4,25, gecikmede +%0,30", sag: "" }) +
      satir({ bas: "POS komisyonu", alt: "Her kartlı satıştan banka kasasına", sag: "%" + sayi(u.pos_komisyon, 0) }));
    return h;
  }
  window.gmRisk = async function (p) {
    try { await calis(null, function () { return API.rpc("banka_risk_profili", { p_banka: GM.id, p_profil: p }); }, "Risk profili uygulandı; bekleyen uygun başvurular sonuçlandı."); genelMudurluk(); } catch (_) {}
  };
  window.gmOtomatikKaydet = async function (btn) {
    var on = function (k) { var el = $id("gmOt_" + k); return !!(el && el.classList.contains("on")); };
    try {
      await calis(btn, function () {
        return API.rpc("banka_yonetim_ayar_kaydet", { p_banka: GM.id, p_pos: on("pos"), p_kart: on("kart"), p_kredi: on("kredi"),
          p_min_not: Math.round(parse(val("gmMN"))), p_kart_max: Math.round(parse(val("gmKM"))), p_kredi_max: Math.round(parse(val("gmKrM"))) });
      }, "Kurallar kaydedildi.");
      genelMudurluk();
    } catch (_) {}
  };
  window.gmMevduatKaydet = async function (btn) {
    var vd = ((GM.veri || {}).urunler || {}).vadeler || {};
    try {
      await calis(btn, async function () {
        var m7 = parse(val("gmM7"));
        if (!isNaN(m7) && Math.abs(m7 - Number(((GM.veri || {}).urunler || {}).mevduat7)) > 0.0001) await API.rpc("banka_faiz_belirle", { p_banka: GM.id, p_faiz: Math.round(m7 * 100) / 100 });
        for (var s of ["1", "3", "6", "12", "24"]) {
          var x = parse(val("gmV" + s));
          if (!isNaN(x) && Math.abs(x - Number(vd[s])) > 0.0001) await API.rpc("oyb_oran_ayarla", { p_banka: GM.id, p_saat: Number(s), p_oran: Math.round(x * 100) / 100 });
        }
      }, "Mevduat faizleri güncellendi.");
      genelMudurluk();
    } catch (_) {}
  };
  window.gmKrediFaiz = async function (btn) {
    var f = parse(val("gmK24")); if (isNaN(f)) return bildir("Faizi gir.", true);
    try { await calis(btn, function () { return API.rpc("oyb_kredi_faiz_ayarla", { p_banka: GM.id, p_faiz: Math.round(f * 100) / 100 }); }, "Günlük kredi faizi güncellendi."); genelMudurluk(); } catch (_) {}
  };
  window.gmPaket = function (id) {
    var p = (((GM.veri || {}).urunler || {}).paketler || []).find(function (x) { return Number(x.id) === Number(id); }) ||
      { id: null, ad: "", vade_gun: 7, taksit_sayisi: 7, faiz: 8, min_tutar: 5000, max_tutar: 100000, otomatik: true, min_not: 1100, aktif: true };
    var alan = function (idx, ad, deger, tip) { return '<div class="alan"><label for="' + idx + '">' + ad + '</label><input id="' + idx + '" ' + (tip || 'inputmode="numeric"') + ' value="' + esc(deger) + '"></div>'; };
    bmodal('<h3 style="font-size:19px;font-weight:800">' + (p.id ? "Paketi düzenle" : "Yeni kredi paketi") + '</h3>' +
      alan("pkAd", "Paket adı", p.ad, 'maxlength="40"') + alan("pkV", "Vade (gün, 1–30)", p.vade_gun) + alan("pkT", "Taksit sayısı (1–30)", p.taksit_sayisi) +
      alan("pkF", "Toplam faiz % (0–20)", p.faiz, 'inputmode="decimal"') + alan("pkMin", "En az tutar (₺)", p.min_tutar) + alan("pkMax", "En çok tutar (₺)", p.max_tutar) +
      alan("pkN", "Asgari kredi notu", p.min_not) +
      '<div class="bk-cips"><button type="button" id="pkO" class="' + (p.otomatik ? "on" : "") + '" onclick="this.classList.toggle(\'on\')">Anında onay</button><button type="button" id="pkA" class="' + (p.aktif ? "on" : "") + '" onclick="this.classList.toggle(\'on\')">Satışta</button></div>' +
      '<button class="btn" onclick="gmPaketKaydet(this,' + (p.id ? Number(p.id) : 0) + ')">Kaydet</button>' +
      (p.id ? '<button class="btn ikinci" onclick="gmPaketSil(this,' + Number(p.id) + ')">Paketi kaldır</button>' : '') + '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.gmPaketKaydet = async function (btn, id) {
    var on = function (x) { var el = $id(x); return !!(el && el.classList.contains("on")); };
    try {
      await calis(btn, function () {
        return API.rpc("oyb_paket_kaydet", { p_banka: GM.id, p_id: id || null, p_ad: val("pkAd").trim(), p_vade_gun: Math.round(parse(val("pkV"))), p_taksit: Math.round(parse(val("pkT"))),
          p_faiz: Math.round(parse(val("pkF")) * 100) / 100, p_min: Math.round(parse(val("pkMin"))), p_max: Math.round(parse(val("pkMax"))), p_otomatik: on("pkO"), p_min_not: Math.round(parse(val("pkN"))), p_aktif: on("pkA") });
      }, "Paket kaydedildi.");
      kapat(); genelMudurluk();
    } catch (_) {}
  };
  window.gmPaketSil = async function (btn, id) {
    try { await calis(btn, function () { return API.rpc("oyb_paket_sil", { p_banka: GM.id, p_id: id }); }, "Paket satıştan kaldırıldı."); kapat(); genelMudurluk(); } catch (_) {}
  };

  function gmMusteriler(v) {
    var b = v.banka || {}, yon = !!b.yonetebilir, h = "", q = (GM.ara || "").toLocaleLowerCase("tr-TR");
    var ms = (v.musteriler || []).filter(function (m) { return !q || String(m.kad).toLocaleLowerCase("tr-TR").indexOf(q) >= 0; });
    h += '<div class="bk-form" style="margin-bottom:10px"><input id="gmAra" placeholder="Müşteri ara" value="' + esc(GM.ara) + '" oninput="gmAra(this.value)"></div>';
    var kr = (v.krediler || []).filter(function (k) { return Number(k.geciken) > 0; });
    if (kr.length) h += kutu("Geciken krediler", kr.map(function (k) {
      return satir({ bas: esc(k.kad) + " · kalan " + tl(k.kalan), alt: "Geciken " + tl(k.geciken) + (k.icra ? " · icra: " + esc(k.icra.durum) : ""),
        sag: yon && k.dava_acilabilir ? '<button class="btn altin" style="margin:0;padding:8px 12px;width:auto" onclick="gmIcra(' + Number(k.id) + ')">İcra başlat</button>' : '' });
    }).join(""));
    var gk = (v.kartlar || []).filter(function (k) { return Number(k.gecikmis_asgari) > 0; });
    if (gk.length) h += kutu("Geciken kart borçları", gk.map(function (k) {
      return satir({ bas: esc(k.kad) + " · •••• " + esc(k.son_dort), alt: "Gecikmiş asgari " + tl(k.gecikmis_asgari) + " · borç " + tl(k.borc), sag: '<span class="bk-rozet k">' + esc(k.durum) + '</span>' });
    }).join(""));
    h += kutu("Müşteriler (" + (v.musteriler || []).length + ")", ms.length ? ms.map(function (m) {
      var ek = [];
      if (Number(m.vadesiz)) ek.push("vadesiz " + tlKisa(m.vadesiz));
      if (Number(m.vadeli)) ek.push("vadeli " + tlKisa(m.vadeli));
      if (Number(m.kredi)) ek.push("kredi " + tlKisa(m.kredi));
      if (Number(m.kart)) ek.push("kart " + tlKisa(m.kart));
      return satir({ bas: esc(m.kad) + ' <span class="bk-rozet">' + sayi(m.not) + '</span>', alt: (ek.join(" · ") || "Henüz ürün yok") + (m.teklif ? " · teklifin bekliyor" : "") + (m.bilgi ? " · bilgi: " + esc(m.bilgi) : ""),
        sag: yon ? '<button class="btn ikinci" style="margin:0;padding:8px 12px;width:auto" onclick="gmMusteri(\'' + esc(m.kad).replace(/'/g, "\\'") + '\')">İşlem</button>' : '' });
    }).join("") : '<div class="bk-bos">' + (q ? "Aramaya uyan müşteri yok." : "Henüz müşterin yok. Faizlerini ve paketlerini cazip yaparak müşteri çek.") + '</div>');
    var ak = v.kartlar || [];
    if (ak.length) h += kutu("Verdiğin kartlar", ak.slice(0, 30).map(function (k) {
      return satir({ bas: esc(k.kad) + " · •••• " + esc(k.son_dort), alt: "Limit " + tl(k.limit) + " · " + esc(k.durum), sag: tl(k.borc), sagAlt: "borç" });
    }).join(""));
    return h;
  }
  window.gmAra = function (q) {
    GM.ara = q; var konum = q.length; gmCiz();
    var el = $id("gmAra"); if (el) { el.focus(); try { el.setSelectionRange(konum, konum); } catch (_) {} }
  };
  window.gmMusteri = function (kad) {
    bmodal('<h3 style="font-size:19px;font-weight:800">' + esc(kad) + '</h3>' +
      '<p class="alt" style="margin:4px 0 10px">Müşteriye özel kredi teklifi gönder ya da mali bilgilerini görmek için izin iste.</p>' +
      '<div class="alan"><label for="tkT">Teklif tutarı (₺)</label><input id="tkT" inputmode="numeric"></div>' +
      '<div class="alan"><label for="tkV">Vade (gün)</label><input id="tkV" inputmode="numeric" value="7"></div>' +
      '<div class="alan"><label for="tkS">Taksit sayısı</label><input id="tkS" inputmode="numeric" value="7"></div>' +
      '<div class="alan"><label for="tkF">Toplam faiz %</label><input id="tkF" inputmode="decimal" value="8"></div>' +
      '<div class="alan"><label for="tkM">Mesajın</label><input id="tkM" maxlength="200" placeholder="örn. Sadık müşterimize özel"></div>' +
      '<button class="btn" onclick="gmTeklif(this,\'' + esc(kad).replace(/'/g, "\\'") + '\')">Teklifi gönder (48 saat geçerli)</button>' +
      '<button class="btn ikinci" onclick="gmBilgiIste(this,\'' + esc(kad).replace(/'/g, "\\'") + '\')">Mali bilgi izni iste</button><button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
  };
  window.gmTeklif = async function (btn, kad) {
    try {
      await calis(btn, function () {
        return API.rpc("oyb_kredi_teklif_ver", { p_banka: GM.id, p_kad: kad, p_tutar: Math.round(parse(val("tkT"))), p_vade_gun: Math.round(parse(val("tkV"))),
          p_taksit: Math.round(parse(val("tkS"))), p_faiz: Math.round(parse(val("tkF")) * 100) / 100, p_mesaj: val("tkM") || null });
      }, "Teklif müşteriye gönderildi.");
      kapat(); genelMudurluk();
    } catch (_) {}
  };
  window.gmBilgiIste = async function (btn, kad) {
    try { await calis(btn, function () { return API.rpc("oyb_hesap_bilgi_iste", { p_banka: GM.id, p_kad: kad, p_kapsam: ["maas", "kira", "sirket", "gunluk", "mulk"] }); }, "Bilgi talebi gönderildi."); kapat(); genelMudurluk(); } catch (_) {}
  };
  window.gmIcra = function (kredi) {
    bmodal('<h3 style="font-size:19px;font-weight:800">İcra takibi başlat</h3><p class="alt" style="margin:4px 0 10px">Dosya Adliye\'ye gider; borçlu savunma yapabilir. Haczedilecek varlık türünü seç.</p>' +
      '<div class="alan"><label for="icT">Haciz türü</label><select id="icT"><option value="gelir">Gelir (maaş kesintisi)</option><option value="mulk">Mülk</option><option value="hisse">Şirket hissesi</option><option value="karma">Hepsi</option></select></div>' +
      '<div class="alan"><label for="icG">Gerekçe (en az 20 karakter)</label><textarea id="icG" rows="3">Kredi taksitleri vadesinde ödenmedi; ek ödeme süresi de doldu.</textarea></div>' +
      '<button class="btn" onclick="gmIcraYap(this,' + Number(kredi) + ')">Takibi başlat</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  };
  window.gmIcraYap = async function (btn, kredi) {
    try { await calis(btn, function () { return API.rpc("oyb_icra_baslat", { p_kredi: kredi, p_tur: val("icT"), p_gerekce: val("icG") }); }, "İcra dosyası açıldı."); kapat(); genelMudurluk(); } catch (_) {}
  };

  function gmAyarlar(v) {
    var b = v.banka || {}, yon = !!b.yonetebilir, dis = yon ? "" : " disabled", h = "";
    h += kutu("Banka kimliği", '<div class="bk-form" style="padding:8px 0"><label>Kurumsal renk (müşteri kartlarında ve hesaplarda görünür)</label><div class="bk-renkler">' +
      ["lacivert", "bordo", "zumrut", "turuncu", "mor", "altin", "turkuaz", "gece", "kirmizi", "gumus"].map(function (r) {
        return '<button type="button" title="' + renk(r)[2] + '" aria-label="' + renk(r)[2] + '" data-r="' + r + '" class="' + (b.renk === r ? "on" : "") + '" style="' + renkVar(r) + '" onclick="gmRenkSec(\'' + r + '\')"' + dis + '></button>';
      }).join("") + '</div>' +
      '<div class="alan"><label for="gmSl">Slogan (en fazla 80 karakter)</label><input id="gmSl" maxlength="80" value="' + esc(b.slogan || "") + '" placeholder="örn. Paranız bizde güvende"' + dis + '></div>' +
      '<div class="alan"><label for="gmEm">Emniyet payı (₺) — otomatik kredilerde kasada dokunulmayacak tutar</label><input id="gmEm" inputmode="numeric" value="' + Number(b.emniyet_payi || 0) + '"' + dis + '></div>' +
      (yon ? '<button class="btn" onclick="gmKimlikKaydet(this)">Kaydet</button>' : '') + '</div>');
    h += kutu("Kasa görünürlüğü", '<p class="bk-ipucu" style="margin:8px 0">Bankanın kasası varsayılan olarak yalnız ortaklarına görünür. Müşterilere güven vermek için açabilirsin.</p><div class="bk-secim">' +
      [["gizli", "Gizli", "Yalnız ortaklar görür"], ["herkes", "Herkese açık", "Bütün oyuncular kasayı görür"]].map(function (x) {
        return '<button type="button" class="' + (b.gizlilik === x[0] ? "on" : "") + '" onclick="gmGizlilik(\'' + x[0] + '\')"' + dis + '><b>' + x[1] + '</b><small>' + x[2] + '</small></button>';
      }).join("") + '</div>');
    h += kutu("Ortaklar", (b.ortaklar || []).map(function (o) {
      return satir({ bas: esc(o.kad) + (o.ben ? " (sen)" : ""), alt: o.kar_kasada ? "Kâr payı bankada birikiyor" : "Kâr payı cüzdanına geçiyor", sag: "%" + sayi(o.pay, 2) });
    }).join("") + (b.yonetici ? satir({ bas: "Atanmış yönetici", sag: esc(b.yonetici) }) : ""));
    return h;
  }
  var SECILEN_RENK = null;
  window.gmRenkSec = function (r) {
    SECILEN_RENK = r;
    document.querySelectorAll(".bk-renkler button").forEach(function (x) { x.classList.toggle("on", x.getAttribute("data-r") === r); });
  };
  window.gmKimlikKaydet = async function (btn) {
    var em = parse(val("gmEm"));
    try {
      await calis(btn, function () {
        return API.rpc("banka_politika_kaydet", { p_banka: GM.id, p_emniyet: isNaN(em) ? null : Math.round(em), p_renk: SECILEN_RENK || ((GM.veri || {}).banka || {}).renk || null, p_slogan: val("gmSl") });
      }, "Banka kimliği kaydedildi.");
      SECILEN_RENK = null; genelMudurluk();
    } catch (_) {}
  };
  window.gmGizlilik = async function (g) {
    try { await calis(null, function () { return API.rpc("kasa_gizlilik_ayarla", { p_tur: "sirket", p_id: GM.id, p_gorunurluk: g }); }, g === "gizli" ? "Kasa artık yalnız ortaklara görünür." : "Kasa herkese açıldı."); genelMudurluk(); } catch (_) {}
  };

  /* =====================================================================
     KASA GİZLİLİĞİ (bütün şirket, dernek ve gazeteler)
     ===================================================================== */
  async function kasaGizlilik() {
    stilKur();
    if (typeof yukleniyor === "function") yukleniyor("Kasa gizliliği");
    var d;
    try { d = await API.rpc("kasa_gizlilik_listem"); }
    catch (err) { return ekran("Kasa gizliliği", '<div class="bk"><div class="bk-uyari">' + esc(hata(err)) + '</div></div>'); }
    var h = '<div class="bk"><p class="bk-ipucu" style="margin-top:4px">Şirketlerinin, bankalarının, derneklerinin ve gazetelerinin kasası varsayılan olarak gizlidir; yalnız sahipleri ve ortakları görür. İstersen tek dokunuşla açabilirsin.</p>';
    var grup = function (bas, tur, liste, uyeSecenegi) {
      if (!liste.length) return "";
      return kutu(bas, liste.map(function (x) {
        var sec = [["gizli", "Gizli"], ["herkes", "Herkese açık"]];
        if (uyeSecenegi) sec.splice(1, 0, ["uyeler", "Üyelere açık"]);
        return '<div class="bk-satir" style="flex-wrap:wrap"><span class="bk-orta"><b>' + esc(x.ad) + '</b><small>Kasa ' + tl(x.kasa) + (x.sektor ? " · " + esc(sektorAd(x.sektor)) : "") + '</small></span>' +
          '<span class="bk-cips" style="display:flex;gap:6px;flex-wrap:wrap;width:100%">' + sec.map(function (s) {
            return '<button type="button" class="btn ' + (x.gorunurluk === s[0] ? "altin" : "ikinci") + '" style="margin:0;width:auto;flex:1;padding:8px 6px;font-size:13px"' + (x.ayarlayabilir ? '' : ' disabled title="Yalnız yönetici ya da %50 ortak değiştirebilir"') +
              ' onclick="kasaGizlilikAyarla(\'' + tur + '\',' + Number(x.id) + ',\'' + s[0] + '\')">' + s[1] + '</button>';
          }).join("") + '</span></div>';
      }).join(""));
    };
    h += grup("Şirketler ve bankalar", "sirket", d.sirketler || [], false) + grup("Dernekler", "dernek", d.dernekler || [], true) + grup("Gazeteler", "gazete", d.gazeteler || [], false);
    if (!(d.sirketler || []).length && !(d.dernekler || []).length && !(d.gazeteler || []).length) h += '<div class="bk-bos">Sahibi ya da yöneticisi olduğun bir kurum yok.</div>';
    ekran("Kasa gizliliği", h + '</div>');
  }
  window.kasaGizlilikEkrani = kasaGizlilik;
  window.kasaGizlilikAyarla = async function (tur, id, g) {
    try { await calis(null, function () { return API.rpc("kasa_gizlilik_ayarla", { p_tur: tur, p_id: id, p_gorunurluk: g }); }, "Kasa görünürlüğü güncellendi."); kasaGizlilik(); } catch (_) {}
  };

  /* =====================================================================
     YÖNLENDİRMELER: eski banka ekranları yeni uygulamaya açılır
     ===================================================================== */
  var ESKI = {};
  function sabitle(ad, fn) {
    try {
      var onceki = window[ad];
      if (typeof onceki === "function" && onceki !== fn) ESKI[ad] = onceki;
      Object.defineProperty(window, ad, { configurable: true, get: function () { return fn; }, set: function (yeni) { if (yeni !== fn) ESKI[ad] = yeni; } });
    } catch (_) { try { window[ad] = fn; } catch (__) {} }
  }
  window.BANKA_ESKI_EKRANLAR = ESKI;
  var subeAc = function () { return mobilSube(); };
  sabitle("internetBankaciligiEkrani", subeAc);
  sabitle("bankacilikMerkeziEkrani", subeAc);
  sabitle("bankaHesaplarimEkrani", subeAc);
  // Eski menülerin sekme adları: basvuru → Başvurular, ayar (otomatik kararlar) → Ürünler ve kurallar
  var gmHedef = function (sekme) { return sekme === "basvuru" ? "basvuru" : sekme === "ayar" ? "urun" : sekme === "kasa" ? "kasa" : "ozet"; };
  sabitle("bankaYonetimEkrani", function (id, sekme) { return id ? genelMudurluk(id, gmHedef(sekme)) : bankaYonetimMerkezi(); });
  sabitle("soBankaYonetimGit", function (sekme) {
    var hedef = gmHedef(sekme);
    if (GM.id) return window.bankaGenelMudurlukEkrani(GM.id, hedef);
    return API.rpc("banka_yonettiklerim").then(function (l) {
      l = l || [];
      if (!l.length) return bildir("Yönettiğin bir banka bulunamadı.", true);
      if (l.length === 1) return window.bankaGenelMudurlukEkrani(Number(l[0].id), hedef);
      return ekranAc(bankaYonetimMerkezi);
    }).catch(function (err) { bildir(hata(err), true); });
  });
  // Para gönder: her yerden açılan transfer penceresi artık FAST (alıcı adı doluysa kendiliğinden bulunur)
  var eskiParaGonder = window.paraGonderModal;
  if (typeof eskiParaGonder === "function") ESKI.paraGonderModal = eskiParaGonder;
  window.paraGonderModal = async function (kad) {
    stilKur();
    try { await msYukle(); }
    catch (err) { if (typeof ESKI.paraGonderModal === "function") return ESKI.paraGonderModal(kad); return bildir(hata(err), true); }
    window.msFastAc();
    if (kad && $id("fsAlici")) { $id("fsAlici").value = kad; window.msFastBul(null); }
  };
  // Eski devlet bankası ekranı istenirse ulaşılabilir kalsın
  window.devletBankasiKlasik = function () { var f = ESKI.bankaEkrani || window.bankaEkrani; if (typeof f === "function") return ekranAc(f); };
  stilKur();
})();
