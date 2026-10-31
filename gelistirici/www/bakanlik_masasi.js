/* =====================================================================
   Seçim Online — BAKANLIK MASASI (27.10.2026)
   • Bakanın tek ekranı: Özet · İcraat · Etkinlik · Bütçe · İletişim · Politika
   • Bütçe mantığı: günlük ödenek (bütçe kanunu payı) → kasa → harcama;
     ek ödenek talebi (yürütme onayı), Hazine'ye iade, hesap defteri.
   • Haftalık 3 görev (kıdem ödülü), bakan karnesi, etkinlikler (oyuncular
     katılır, kıdem kazanır), saha ziyareti, bakanlık açıklaması.
   • Herkes için: Bakanlık etkinlikleri, bakanlık sayfası (salt okunur),
     Devlet bütçesi (yürütme: talepleri onaylar, ödenek aktarır, tahsis yapar).
   Sunucu: gelistirici/sql/142_bakanlik_masasi.sql. Para/kasa işlemleri yalnız
   sunucu fonksiyonlarıyla yapılır; bu dosya arayüzdür.
   ===================================================================== */
(function () {
  "use strict";
  if (window.SO_BAKANLIK_MASASI_V1) return;
  window.SO_BAKANLIK_MASASI_V1 = true;

  /* ---------------- yardımcılar ---------------- */
  var esc = function (x) {
    return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  };
  var sayi = function (n, d) {
    return Number(n || 0).toLocaleString("tr-TR", { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 });
  };
  var mr = function (n, d) { return sayi(n, d == null ? 1 : d) + " milyar ₺"; };
  var zaman = function (ts) {
    if (!ts) return "—";
    try { return typeof tarihSaat === "function" ? tarihSaat(ts) : new Date(ts).toLocaleString("tr-TR"); } catch (_) { return String(ts); }
  };
  var kalan = function (ts) {
    if (!ts) return "";
    var ms = new Date(ts).getTime() - Date.now();
    if (ms <= 0) return "şimdi";
    var dk = Math.round(ms / 60000);
    if (dk < 60) return dk + " dk";
    var sa = Math.floor(dk / 60), d2 = dk % 60;
    if (sa < 48) return sa + " sa" + (d2 ? " " + d2 + " dk" : "");
    return Math.round(sa / 24) + " gün";
  };
  var hazirMi = function (ts) { return !ts || new Date(ts).getTime() <= Date.now(); };
  var hata = function (err) {
    var m = err && err.message ? err.message : String(err || "Beklenmeyen hata");
    return typeof hataCevir === "function" ? hataCevir(m) : m;
  };
  var bildir = function (m, h) { if (typeof toast === "function") toast(m, h); };
  var rpc = function (ad, arg) { return API.rpc(ad, arg || {}); };
  var profil = function () { return (typeof D === "object" && D && D.durum && D.durum.profil) || null; };
  var illerSirali = function () {
    try { return VERI.iller.slice().sort(function (a, b) { return a.ad.localeCompare(b.ad, "tr"); }); } catch (_) { return []; }
  };
  var ilSecici = function (id, secili) {
    return '<select id="' + id + '">' + illerSirali().map(function (i) {
      return '<option value="' + Number(i.id) + '"' + (Number(secili) === Number(i.id) ? " selected" : "") + '>' + esc(i.ad) + '</option>';
    }).join("") + '</select>';
  };
  var ETKI_AD = { memnuniyet: "memnuniyet", buyume: "büyüme", enflasyon: "enflasyon", issizlik: "işsizlik", hazine: "hazine", gelisim: "il gelişmişliği", il_memnuniyet: "il memnuniyeti" };
  var etkiYazi = function (e2) {
    return Object.keys(e2 || {}).map(function (k) {
      var v = Number(e2[k]); return (ETKI_AD[k] || k) + " " + (v > 0 ? "+" : "") + sayi(v, Math.abs(v) < 1 ? 2 : 1);
    }).join(" · ");
  };
  var RENK = {
    adalet: ["#8e3446", "#2b1220"], disisleri: ["#2a6f9f", "#0f2740"], icisleri: ["#2f6f58", "#10261e"],
    maliye: ["#b9862a", "#3a2808"], savunma: ["#5d6f34", "#1b2410"], egitim: ["#3a78c2", "#0f2442"],
    saglik: ["#c9465a", "#3b0f16"], sanayi: ["#6a5bc6", "#1d1745"], ticaret: ["#cf7a2b", "#3a1d06"],
    tarim: ["#4c9a45", "#122a11"], ulastirma: ["#2f8fa0", "#0b2a30"], calisma: ["#9a5cc0", "#2a1338"]
  };
  var renk = function (kod) { return RENK[kod] || ["#4b5ea8", "#151c3d"]; };
  var kisaAd = function (ad) { return String(ad || "").replace(" Bakanlığı", ""); };
  var unvan = function (ad) { return String(ad || "").replace("Bakanlığı", "Bakanı"); };
  var HAREKET_AD = {
    gunluk: "Günlük ödenek", odenek: "Ek ödenek", tahsis: "Bütçe tahsisi", icraat: "İcraat", etkinlik: "Etkinlik",
    ziyaret: "Saha ziyareti", ihale: "Kamu ihalesi", tesvik: "Teşvik", denetim: "Denetim", dava: "Dava / icra",
    iade: "Hazine'ye iade", aktarim: "Ödenek aktarımı", tavan: "Tavan", gelir: "Diğer giriş", gider: "Diğer çıkış"
  };
  var IK = {
    kasa: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="14" rx="3"/><path d="M3 10.5h18M16.5 15h1.5M7 6V5a2 2 0 0 1 2-2h8"/></svg>',
    icraat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
    etkinlik: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 22V4M5 4h12l-2 4 2 4H5"/><circle cx="17" cy="19" r="2"/></svg>',
    ziyaret: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s-7-6.2-7-12a7 7 0 0 1 14 0c0 5.8-7 12-7 12z"/><circle cx="12" cy="9" r="2.5"/></svg>',
    aciklama: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11v2a1 1 0 0 0 1 1h3l6 5V5L7 10H4a1 1 0 0 0-1 1zM17 8a5 5 0 0 1 0 8"/></svg>',
    odenek: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18M17 7.5c0-1.9-2.2-3-5-3s-5 1.1-5 3 2 2.7 5 3.4 5 1.6 5 3.6-2.2 3-5 3-5-1.1-5-3"/></svg>',
    iade: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/></svg>',
    gorev: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5"/></svg>',
    bina: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18M5 21V10M9.5 21V10M14.5 21V10M19 21V10M2.5 10 12 3l9.5 7z"/></svg>'
  };

  /* ---------------- stil ---------------- */
  (function () {
    if (document.getElementById("bkm-stil")) return;
    var css = [
      ".bkm{--r:16px}",
      ".bkm .bkm-kimlik{border-radius:20px;padding:18px 18px 16px;color:#fff;position:relative;overflow:hidden;background:linear-gradient(140deg,var(--a),var(--b));margin-bottom:12px;box-shadow:0 18px 34px -24px var(--a)}",
      ".bkm .bkm-kimlik::after{content:'';position:absolute;inset:0;pointer-events:none;background:repeating-radial-gradient(circle at 115% -10%,rgba(255,255,255,.07) 0 1px,transparent 1px 10px),radial-gradient(120% 80% at 0% 0%,rgba(255,255,255,.14),transparent 60%)}",
      ".bkm .bkm-kimlik>*{position:relative;z-index:1}",
      ".bkm .bkm-kimlik .bkm-ust{display:flex;align-items:center;gap:10px}",
      ".bkm .bkm-kimlik .bkm-amb{width:40px;height:40px;border-radius:12px;display:grid;place-items:center;background:rgba(255,255,255,.16);flex:none}",
      ".bkm .bkm-kimlik .bkm-amb svg{width:22px;height:22px}",
      ".bkm .bkm-kimlik h2{font-family:var(--disp);font-size:22px;line-height:1.1;margin:0}",
      ".bkm .bkm-kimlik .bkm-alt{opacity:.85;font-size:13px;margin-top:2px}",
      ".bkm .bkm-kimlik .bkm-kasa{margin-top:16px;display:flex;align-items:flex-end;justify-content:space-between;gap:10px}",
      ".bkm .bkm-kimlik .bkm-kasa small{display:block;font-size:12px;opacity:.8}",
      ".bkm .bkm-kimlik .bkm-kasa b{font-family:var(--disp);font-size:32px;line-height:1;font-variant-numeric:tabular-nums}",
      ".bkm .bkm-kimlik .bkm-kasa b span{font-size:15px;font-weight:600;opacity:.85}",
      ".bkm .bkm-kimlik .bkm-cubuk{height:7px;border-radius:7px;background:rgba(255,255,255,.16);margin-top:10px;overflow:hidden}",
      ".bkm .bkm-kimlik .bkm-cubuk i{display:block;height:100%;border-radius:7px;background:linear-gradient(90deg,#fff,rgba(255,255,255,.65))}",
      ".bkm .bkm-kimlik .bkm-uc{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:12px}",
      ".bkm .bkm-kimlik .bkm-uc div{background:rgba(0,0,0,.22);border-radius:11px;padding:8px 10px;min-width:0}",
      ".bkm .bkm-kimlik .bkm-uc small{display:block;font-size:11px;opacity:.78;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".bkm .bkm-kimlik .bkm-uc b{font-variant-numeric:tabular-nums;font-size:14.5px;white-space:nowrap}",
      ".bkm .bkm-sekme{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 -16px 12px;padding:6px 16px 8px;position:sticky;top:-14px;z-index:3;background:var(--bg)}",
      ".bkm .bkm-sekme::-webkit-scrollbar{display:none}",
      ".bkm .bkm-sekme button{flex:none;padding:8px 13px;border-radius:999px;background:var(--panel);color:var(--txt2);font-size:13.5px;font-weight:700;white-space:nowrap}",
      ".bkm .bkm-sekme button.on{background:var(--txt);color:var(--bg)}",
      ".bkm .bkm-sekme button i{font-style:normal;display:inline-grid;place-items:center;min-width:18px;height:18px;border-radius:9px;background:var(--al);color:#fff;font-size:11px;margin-left:6px;padding:0 5px}",
      ".bkm .bkm-kutu{background:var(--panel);border-radius:14px;padding:4px 14px;margin-bottom:12px}",
      ".bkm .bkm-kutu>h3{font-size:13px;color:var(--mut);font-weight:600;padding:12px 0 4px;margin:0;display:flex;justify-content:space-between;gap:8px}",
      ".bkm .bkm-satir{display:flex;align-items:center;gap:12px;padding:12px 0;border-top:1px solid var(--line)}",
      ".bkm .bkm-kutu>h3+.bkm-satir,.bkm .bkm-kutu>.bkm-satir:first-child{border-top:0}",
      ".bkm .bkm-orta{flex:1;min-width:0}",
      ".bkm .bkm-orta b{display:block;font-size:14.5px}",
      ".bkm .bkm-orta small{display:block;color:var(--mut);font-size:12.5px;margin-top:2px;line-height:1.4}",
      ".bkm .bkm-sag{text-align:right;font-variant-numeric:tabular-nums;font-weight:700;white-space:nowrap}",
      ".bkm .bkm-sag small{display:block;font-weight:500;color:var(--mut);font-size:12px}",
      ".bkm .bkm-ik{flex:none;width:38px;height:38px;border-radius:12px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,var(--a),var(--b))}",
      ".bkm .bkm-ik svg{width:19px;height:19px}",
      ".bkm .bkm-hizli{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:0 0 12px}",
      ".bkm .bkm-hizli button{background:var(--panel);border-radius:14px;padding:12px 4px 10px;display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;font-weight:700;color:var(--txt2);line-height:1.15;text-align:center;position:relative}",
      ".bkm .bkm-hizli button span{width:36px;height:36px;border-radius:12px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,var(--a),var(--b))}",
      ".bkm .bkm-hizli button span svg{width:19px;height:19px}",
      ".bkm .bkm-hizli button em{position:absolute;top:6px;right:8px;font-style:normal;font-size:10.5px;color:var(--mut);font-weight:600}",
      ".bkm .bkm-hizli button:disabled{opacity:.5}",
      ".bkm .bkm-gorev{padding:12px 0;border-top:1px solid var(--line)}",
      ".bkm .bkm-gorev:first-of-type{border-top:0}",
      ".bkm .bkm-gorev .bkm-gb{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}",
      ".bkm .bkm-gorev b{font-size:14.5px}",
      ".bkm .bkm-gorev small{display:block;color:var(--mut);font-size:12.5px;margin-top:2px;line-height:1.4}",
      ".bkm .bkm-bar{height:7px;border-radius:7px;background:var(--panel2);overflow:hidden;margin:9px 0 2px}",
      ".bkm .bkm-bar i{display:block;height:100%;border-radius:7px;background:linear-gradient(90deg,var(--a),var(--c,#fff))}",
      ".bkm .bkm-rozet{display:inline-block;padding:3px 8px;border-radius:7px;font-size:11.5px;font-weight:700;background:var(--panel2);color:var(--txt2);white-space:nowrap}",
      ".bkm .bkm-rozet.y{background:rgba(52,201,138,.14);color:var(--good)}.bkm .bkm-rozet.k{background:var(--albg);color:var(--al2)}.bkm .bkm-rozet.s{background:rgba(242,179,61,.14);color:var(--warn)}",
      ".bkm .bkm-mini{padding:7px 12px;border-radius:10px;font-size:13px;font-weight:800;background:linear-gradient(145deg,var(--a),var(--b));color:#fff;white-space:nowrap}",
      ".bkm .bkm-mini:disabled{opacity:.45}",
      ".bkm .bkm-mini.ikinci{background:var(--panel2);color:var(--txt)}",
      ".bkm .bkm-karne{display:flex;gap:14px;align-items:center;padding:12px 0}",
      ".bkm .bkm-halka{flex:none;width:78px;height:78px;border-radius:50%;display:grid;place-items:center;text-align:center;background:conic-gradient(var(--a) calc(var(--p)*1%),var(--panel2) 0);position:relative}",
      ".bkm .bkm-halka::before{content:'';position:absolute;inset:7px;border-radius:50%;background:var(--panel)}",
      ".bkm .bkm-halka span{position:relative;font-family:var(--disp);font-weight:700;font-size:22px;line-height:1}",
      ".bkm .bkm-halka small{position:relative;display:block;font-size:10px;color:var(--mut);margin-top:2px}",
      ".bkm .bkm-cips{display:flex;flex-wrap:wrap;gap:6px}",
      ".bkm .bkm-cips span{background:var(--panel2);border-radius:8px;padding:4px 8px;font-size:12px;color:var(--txt2)}",
      ".bkm .bkm-bilgi{background:var(--inkbg);color:var(--txt2);border-radius:12px;padding:11px 13px;font-size:13.5px;margin-bottom:12px;line-height:1.5}",
      ".bkm .bkm-uyari{background:var(--albg);color:var(--al2);border-radius:12px;padding:11px 13px;font-size:13.5px;margin-bottom:12px}",
      ".bkm .bkm-bos{text-align:center;color:var(--mut);padding:18px 10px;font-size:14px}",
      ".bkm details.bkm-acil{background:var(--panel);border-radius:14px;padding:0 14px;margin-bottom:12px}",
      ".bkm details.bkm-acil summary{padding:13px 0;font-weight:700;cursor:pointer;list-style:none;display:flex;justify-content:space-between}",
      ".bkm details.bkm-acil summary::after{content:'+';color:var(--mut);font-weight:700}",
      ".bkm details.bkm-acil[open] summary::after{content:'−'}",
      ".bkm details.bkm-acil p{font-size:13.5px;color:var(--txt2);line-height:1.55;padding-bottom:12px;margin:0}",
      ".bkm .bkm-dag{padding:9px 0;border-top:1px solid var(--line)}",
      ".bkm .bkm-dag:first-of-type{border-top:0}",
      ".bkm .bkm-dag .bkm-db{display:flex;justify-content:space-between;font-size:13.5px;gap:8px}",
      ".bkm .bkm-dag .bkm-bar{height:6px;margin:6px 0 0}",
      ".bkm .bkm-etk{background:var(--panel);border-radius:16px;padding:14px;margin-bottom:12px;position:relative;overflow:hidden}",
      ".bkm .bkm-etk.canli{box-shadow:inset 0 0 0 1.5px var(--a)}",
      ".bkm .bkm-etk h4{font-size:16px;margin:0 0 3px}",
      ".bkm .bkm-etk p{font-size:13px;color:var(--txt2);margin:4px 0 8px;line-height:1.45}",
      ".bkm .bkm-etk .bkm-ebil{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0 10px}",
      ".bkm .bkm-etk .bkm-ebil span{background:var(--panel2);border-radius:8px;padding:4px 8px;font-size:12px;color:var(--txt2)}",
      ".bkm .bkm-etk .bkm-tepki{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}",
      ".bkm .bkm-etk .bkm-tepki button{padding:10px 4px;border-radius:12px;background:var(--panel2);font-weight:700;font-size:13px;color:var(--txt);border:1.5px solid transparent}",
      ".bkm .bkm-etk .bkm-tepki button.on{border-color:var(--a);background:color-mix(in srgb,var(--a) 18%,var(--panel2))}",
      ".bkm .bkm-canli{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:800;color:var(--al2)}",
      ".bkm .bkm-canli::before{content:'';width:8px;height:8px;border-radius:50%;background:var(--al);box-shadow:0 0 0 0 var(--al);animation:bmNabiz 1.6s infinite}",
      "@keyframes bmNabiz{0%{box-shadow:0 0 0 0 rgba(224,86,91,.6)}70%{box-shadow:0 0 0 8px rgba(224,86,91,0)}100%{box-shadow:0 0 0 0 rgba(224,86,91,0)}}",
      "@media (prefers-reduced-motion:reduce){.bkm .bkm-canli::before{animation:none}}",
      ".bkm .bkm-tablo{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:2px 0 12px}",
      ".bkm .bkm-tablo>div{background:var(--panel);border-radius:13px;padding:11px 12px}",
      ".bkm .bkm-tablo small{display:block;font-size:12px;color:var(--mut)}",
      ".bkm .bkm-tablo b{font-variant-numeric:tabular-nums;font-size:16px}",
      ".bkm .bkm-artı{color:var(--good)}.bkm .bkm-eksi{color:var(--txt)}",
      ".bkm-modal .alan{margin-bottom:10px}.bkm-modal label{display:block;font-size:12.5px;color:var(--mut);margin-bottom:5px}",
      ".bkm-modal input,.bkm-modal select,.bkm-modal textarea{width:100%;background:var(--panel2);border:1px solid var(--line2);border-radius:11px;padding:11px 12px;color:var(--txt);font-size:15px;font-family:inherit}",
      ".bkm-modal textarea{min-height:110px;resize:vertical;line-height:1.45}",
      ".bkm-modal .bkm-ozet{background:var(--panel2);border-radius:11px;padding:10px 12px;font-size:13.5px;margin:6px 0 10px;line-height:1.5}",
      ".bkm-modal .bkm-cips{display:flex;gap:6px;flex-wrap:wrap;margin:4px 0 10px}",
      ".bkm-modal .bkm-cips button{padding:8px 11px;border-radius:999px;background:var(--panel2);font-size:13px;font-weight:700;color:var(--txt2);border:1.5px solid transparent}",
      ".bkm-modal .bkm-cips button.on{border-color:var(--ink2);color:var(--txt);background:var(--inkbg)}",
      ".bkm-modal .bkm-say{font-size:12px;color:var(--mut);text-align:right;margin-top:3px}",
      ".bkm-kart{border-radius:18px;padding:15px;margin:10px 0 12px;color:#fff;position:relative;overflow:hidden;background:linear-gradient(140deg,var(--a),var(--b))}",
      ".bkm-kart::after{content:'';position:absolute;inset:0;pointer-events:none;background:repeating-linear-gradient(115deg,rgba(255,255,255,.05) 0 2px,transparent 2px 14px)}",
      ".bkm-kart>*{position:relative;z-index:1}",
      ".bkm-kart .bkm-kb{display:flex;justify-content:space-between;align-items:center;gap:8px}",
      ".bkm-kart .bkm-kb b{font-family:var(--disp);font-size:18px;line-height:1.15}",
      ".bkm-kart .bkm-kb span{font-size:11.5px;font-weight:800;background:rgba(0,0,0,.25);border-radius:7px;padding:3px 8px;white-space:nowrap}",
      ".bkm-kart .bkm-ks{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-top:12px}",
      ".bkm-kart .bkm-ks div{background:rgba(0,0,0,.22);border-radius:10px;padding:7px 9px;min-width:0}",
      ".bkm-kart .bkm-ks small{display:block;font-size:10.5px;opacity:.8}",
      ".bkm-kart .bkm-ks b{font-size:14px;font-variant-numeric:tabular-nums;white-space:nowrap}",
      ".bkm-kart .bkm-kn{font-size:12.5px;opacity:.9;margin-top:10px;line-height:1.4}",
      ".bkm-kart button.bkm-kac{display:block;width:100%;margin-top:12px;padding:12px;border-radius:12px;background:#fff;color:#141a33;font-weight:800;font-size:15px}",
      ".bkm-serit{display:flex;align-items:center;gap:12px;border-radius:16px;padding:12px 14px;margin:0 0 12px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line2);cursor:pointer}",
      ".bkm-serit .bkm-sik{flex:none;width:40px;height:40px;border-radius:12px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,var(--a),var(--b))}",
      ".bkm-serit .bkm-sik svg{width:20px;height:20px}",
      ".bkm-serit .bkm-so{flex:1;min-width:0}.bkm-serit .bkm-so b{display:block;font-size:14.5px}.bkm-serit .bkm-so small{display:block;color:var(--mut);font-size:12.5px;margin-top:1px}",
      ".bkm-serit .bkm-ok{color:var(--mut);font-size:20px}"
    ].join("\n");
    var st = document.createElement("style"); st.id = "bkm-stil"; st.textContent = css;
    document.head.appendChild(st);
  })();

  var BM = { kod: null, sekme: "ozet", v: null };
  var stilAB = function (kod) { var r = renk(kod); return "--a:" + r[0] + ";--b:" + r[1]; };

  /* ---------------- ortak parçalar ---------------- */
  var kutu = function (baslik, ic, sag) { return '<section class="bkm-kutu">' + (baslik ? '<h3><span>' + baslik + '</span>' + (sag || "") + '</h3>' : "") + ic + '</section>'; };
  var satir = function (o) {
    return '<div class="bkm-satir"' + (o.tik ? ' role="button" tabindex="0" style="cursor:pointer" onclick="' + o.tik + '"' : "") + '>' + (o.ik ? '<span class="bkm-ik">' + o.ik + '</span>' : "") +
      '<span class="bkm-orta"><b>' + o.bas + '</b>' + (o.alt ? '<small>' + o.alt + '</small>' : "") + '</span>' + (o.sag != null ? '<span class="bkm-sag">' + o.sag + '</span>' : "") + '</div>';
  };
  var mini = function (ad, eylem, ikinci, kapali) {
    return '<button type="button" class="bkm-mini' + (ikinci ? " ikinci" : "") + '"' + (kapali ? " disabled" : "") + ' onclick="' + eylem + '">' + ad + '</button>';
  };
  function bmModal(html) { var m = modal('<div class="bkm-modal">' + html + '</div>'); return m; }

  /* =====================================================================
     1) BAKANLIK MASASI
     ===================================================================== */
  async function masaAc(kod, sekme) {
    if (!kod) return;
    var ayni = BM.v && BM.v.kod === kod && document.getElementById("bmMasa");
    if (!ayni) BM.sekme = sekme || "ozet"; else if (sekme) BM.sekme = sekme;
    BM.kod = kod;
    if (!ayni) yukleniyor("Bakanlık masası");
    try {
      BM.v = await rpc("bakanlik_masasi", { p_kod: kod });
      D._bmPaneller = [{ kod: kod, icraatlar: BM.v.icraatlar || [] }];
      ciz();
    } catch (err) {
      iskelet("Bakanlık masası", '<div class="kart"><p class="alt">' + esc(hata(err)) + '</p></div>', { geri: true });
    }
  }
  window.bakanlikMasasiEkrani = masaAc;
  window.bmSekme = function (s) { BM.sekme = s; ciz(); };

  // İcraat / politika sonrası doğru ekran yenilensin (index.html bu adı çağırır)
  window.bakanSonrasiYenile = function () {
    if (document.getElementById("bmMasa") && BM.kod) return masaAc(BM.kod, BM.sekme);
    if (typeof devletEkrani === "function") return devletEkrani();
  };

  function sekmeler(v) {
    var y = v.yetki, g = v.gorevler && v.gorevler.liste ? v.gorevler.liste.filter(function (x) { return x.tamam && !x.alindi; }).length : 0;
    var aktifEtk = (v.etkinlikler || []).some(function (e2) { return e2.aktif; });
    var bekleyen = (v.sorumluluk && (Number(v.sorumluluk.cimer_bekleyen || 0) + Number(v.sorumluluk.soru_bekleyen || 0))) || 0;
    var ls = [["ozet", "Özet" + (g ? "<i>" + g + "</i>" : "")]];
    if (y) ls.push(["icraat", "İcraat"]);
    ls.push(["etkinlik", "Etkinlik" + (aktifEtk ? "<i>●</i>" : "")]);
    ls.push(["butce", "Bütçe"]);
    ls.push(["iletisim", y ? "İletişim" + (bekleyen ? "<i>" + bekleyen + "</i>" : "") : "Açıklamalar"]);
    if (y && (v.politikalar || []).length) ls.push(["politika", "Politika"]);
    if (!ls.some(function (x) { return x[0] === BM.sekme; })) BM.sekme = "ozet";
    return '<nav class="bkm-sekme">' + ls.map(function (x) {
      return '<button type="button" class="' + (BM.sekme === x[0] ? "on" : "") + '" onclick="bmSekme(\'' + x[0] + '\')">' + x[1] + '</button>';
    }).join("") + '</nav>';
  }

  function kimlik(v) {
    var oran = v.tavan ? Math.min(100, Math.max(0, Number(v.kasa) / Number(v.tavan) * 100)) : 0;
    var bk = v.bakan;
    var alt = bk ? (unvan(v.ad) + " " + esc(bk.kad) + (bk.parti ? " · " + esc(bk.parti.kisa) : "")) :
      (v.yurutme ? "Bakan atanmadı · " + esc(v.yurutme) + " vekâleten yönetiyor" : "Bakan atanmadı");
    return '<section class="bkm-kimlik" style="' + stilAB(v.kod) + '">' +
      '<div class="bkm-ust"><span class="bkm-amb">' + IK.bina + '</span><div style="min-width:0"><h2>' + esc(v.ad) + '</h2><div class="bkm-alt">' + alt + '</div></div></div>' +
      '<div class="bkm-kasa"><div><small>Bakanlık kasası</small><b>' + sayi(v.kasa, 1) + ' <span>milyar ₺</span></b></div>' +
      (v.yetki ? '<span class="bkm-rozet" style="background:rgba(0,0,0,.25);color:#fff">' + (v.yetki === "bakan" ? "Bakanlığın" : "Vekâleten") + '</span>' : '<span class="bkm-rozet" style="background:rgba(0,0,0,.25);color:#fff">Kamuya açık</span>') + '</div>' +
      '<div class="bkm-cubuk" title="Kasa / tavan"><i style="width:' + oran.toFixed(1) + '%"></i></div>' +
      '<div class="bkm-uc"><div><small>Günlük ödenek</small><b>+' + sayi(v.gunluk, 2) + '</b></div><div><small>Bütçe payı</small><b>%' + sayi(v.pay, 1) + '</b></div><div><small>Kasa tavanı</small><b>' + sayi(v.tavan, 0) + '</b></div></div>' +
      '</section>';
  }

  function ciz() {
    var v = BM.v; if (!v) return;
    var h = '<div class="bkm" id="bmMasa" style="' + stilAB(v.kod) + '">' + kimlik(v) + sekmeler(v);
    if (BM.sekme === "icraat") h += icraatSekme(v);
    else if (BM.sekme === "etkinlik") h += etkinlikSekme(v);
    else if (BM.sekme === "butce") h += butceSekme(v);
    else if (BM.sekme === "iletisim") h += iletisimSekme(v);
    else if (BM.sekme === "politika") h += politikaSekme(v);
    else h += ozetSekme(v);
    h += '</div>';
    iskelet(kisaAd(v.ad), h, { geri: true });
    if (BM.sekme === "politika" && typeof politikaBagla === "function") { try { politikaBagla(); } catch (_) {} }
  }

  /* ---------- Özet ---------- */
  function ozetSekme(v) {
    var y = v.yetki, h = "";
    if (y) {
      var etkHazir = (v.etkinlik_turleri || []).some(function (t) { return hazirMi(t.hazir) && Number(v.kasa) >= Number(t.maliyet); }) && !(v.etkinlikler || []).some(function (e2) { return e2.aktif; });
      var icrHazir = (v.icraatlar || []).filter(function (i) { return hazirMi(i.hazir); }).length;
      var talepBekl = (v.talepler || []).some(function (t) { return t.durum === "bekliyor"; });
      h += '<div class="bkm-hizli">' +
        hizli(IK.icraat, "İcraat başlat", "bmSekme('icraat')", icrHazir ? icrHazir + " hazır" : "") +
        hizli(IK.etkinlik, "Etkinlik düzenle", "bmSekme('etkinlik')", etkHazir ? "hazır" : "") +
        hizli(IK.ziyaret, "Saha ziyareti", "bmZiyaretModal()", hazirMi(v.ziyaret && v.ziyaret.hazir) ? "" : kalan(v.ziyaret.hazir)) +
        hizli(IK.aciklama, "Açıklama yap", "bmAciklamaModal()", hazirMi(v.aciklama && v.aciklama.hazir) ? "" : kalan(v.aciklama.hazir)) +
        hizli(IK.odenek, "Ek ödenek iste", "bmTalepModal()", talepBekl ? "bekliyor" : "", y !== "bakan") +
        hizli(IK.iade, "Hazine'ye iade", "bmIadeModal()", "") +
        '</div>';
    }
    if (v.gorevler) h += gorevKutu(v);
    h += karneKutu(v);
    if (y) {
      var s = v.sorumluluk || {};
      h += kutu("Sorumlulukların",
        satir({ ik: IK.aciklama, bas: "CİMER başvuruları", alt: Number(s.cimer_bekleyen) ? Number(s.cimer_bekleyen) + " başvuru yanıt bekliyor (72 saat içinde)" : "Bekleyen başvuru yok", sag: Number(s.cimer_bekleyen) ? '<span class="bkm-rozet k">' + Number(s.cimer_bekleyen) + '</span>' : "›", tik: "bmCimer()" }) +
        satir({ ik: IK.bina, bas: "Soru önergeleri", alt: Number(s.soru_bekleyen) ? Number(s.soru_bekleyen) + " yazılı soru yanıt bekliyor" : "Bekleyen soru yok", sag: Number(s.soru_bekleyen) ? '<span class="bkm-rozet k">' + Number(s.soru_bekleyen) + '</span>' : "›", tik: "bmSorular()" }) +
        (typeof ihaleEkrani === "function" ? satir({ ik: IK.kasa, bas: "Kamu ihaleleri", alt: "Bakanlık projesi için ihale aç ve yönet", sag: "›", tik: "bmIhale()" }) : ""));
    }
    var aktif = (v.etkinlikler || []).filter(function (e2) { return e2.aktif; })[0];
    if (aktif) h += '<div class="bkm-serit" onclick="bmSekme(\'etkinlik\')"><span class="bkm-sik">' + IK.etkinlik + '</span><span class="bkm-so"><b>' + esc(aktif.ad) + '</b><small><span class="bkm-canli">Sürüyor</span> · ' + Number(aktif.katilimci) + ' katılımcı · ' + kalan(aktif.bit) + ' kaldı</small></span><span class="bkm-ok">›</span></div>';
    h += butceAnlat(v);
    if (y === "bakan" && typeof bakanIstifa === "function") h += '<button class="btn tehlike" onclick="bakanIstifa()">Bakanlıktan istifa et</button>';
    return h;
  }
  function hizli(ik, ad, eylem, rozet, kapali) {
    return '<button type="button" onclick="' + eylem + '"' + (kapali ? " disabled" : "") + '><span>' + ik + '</span>' + ad + (rozet ? '<em>' + esc(rozet) + '</em>' : "") + '</button>';
  }
  function gorevKutu(v) {
    var g = v.gorevler, ls = g.liste || [];
    var alinan = ls.filter(function (x) { return x.alindi; }).length;
    var h = ls.map(function (x) {
      var p = x.hedef ? Math.min(100, Number(x.ilerleme) / Number(x.hedef) * 100) : 0;
      var dugme = x.alindi ? '<span class="bkm-rozet y">Alındı</span>' : x.tamam ? mini("Ödülü al", "bmGorevOdul('" + esc(x.kod) + "')") : '<span class="bkm-rozet">' + sayi(x.ilerleme, x.kod === "butce" ? 1 : 0) + ' / ' + sayi(x.hedef, x.kod === "butce" ? 1 : 0) + '</span>';
      return '<div class="bkm-gorev"><div class="bkm-gb"><div><b>' + esc(x.ad) + '</b><small>' + esc(x.aciklama) + '</small></div>' + dugme + '</div><div class="bkm-bar"><i style="width:' + p.toFixed(0) + '%"></i></div></div>';
    }).join("");
    return kutu("Bu haftanın görevleri", h + '<p class="kucuk" style="padding:4px 0 12px;color:var(--mut)">Her görev +' + sayi(g.odul, 1) + ' kıdem; üçü birden +' + sayi(g.bonus, 1) + ' kıdem ve Resmî Gazete\'de anılma. Görevler pazartesi yenilenir (' + kalan(g.bitis) + ' sonra).</p>',
      '<span class="bkm-rozet' + (alinan === 3 ? " y" : "") + '">' + alinan + '/3</span>');
  }
  function karneKutu(v) {
    var k = v.karne || {}, p = Number(k.puan || 0);
    var cevap = Number(k.cimer || 0) + Number(k.soru || 0);
    return kutu("Bakan karnesi · son 28 gün",
      '<div class="bkm-karne"><div class="bkm-halka" style="--p:' + p + '"><div><span>' + p + '</span><small>/100</small></div></div>' +
      '<div class="bkm-cips">' +
      '<span>' + Number(k.icraat || 0) + ' icraat</span><span>' + Number(k.etkinlik || 0) + ' etkinlik · ' + Number(k.katilim || 0) + ' katılım</span>' +
      '<span>' + Number(k.ziyaret || 0) + ' saha ziyareti</span><span>' + Number(k.gorev || 0) + '/12 haftalık görev</span>' +
      '<span>' + (cevap ? (Number(k.cimer_yanit || 0) + Number(k.soru_yanit || 0)) + '/' + cevap + ' başvuru yanıtlandı' : 'yanıtlanacak başvuru yok') + '</span>' +
      '<span>' + sayi(k.harcama, 1) + ' milyar ₺ hizmete harcandı</span></div></div>' +
      '<p class="kucuk" style="padding:0 0 12px;color:var(--mut)">Karne herkese açıktır; seçmenler ve Meclis bakanı buna bakarak değerlendirir.</p>');
  }
  function butceAnlat(v) {
    return '<details class="bkm-acil"><summary>Bakanlık bütçesi nasıl işler?</summary><p>' +
      '1) Meclis\'in bütçe kanunu bu bakanlığa günlük cari harcamanın <b>%' + sayi(v.pay, 1) + '</b>\'ini verir: her gece kasaya <b>' + mr(v.gunluk, 2) + '</b> girer.<br>' +
      '2) Kasa en çok <b>' + sayi(v.tavan, 0) + ' milyar ₺</b> birikir; tavandaki kasaya giremeyen ödenek Hazine\'de kalır (boşa gitmez).<br>' +
      '3) İcraatlar, etkinlikler, saha ziyaretleri ve ihaleler bu kasadan ödenir. Para yetmezse ' + (v.sistem === "parlamenter" ? "Başbakan" : "Cumhurbaşkanı") + '\'ndan gerekçeli <b>ek ödenek</b> istenir; onaylanırsa Hazine\'den aktarılır.<br>' +
      '4) Kullanılmayan ödenek Hazine\'ye iade edilebilir. Her giriş ve çıkış hesap defterine kaynağıyla yazılır ve herkese açıktır.</p></details>';
  }

  /* ---------- İcraat ---------- */
  function icraatSekme(v) {
    var ls = v.icraatlar || [];
    if (!ls.length) return '<div class="bkm-bos">Bu bakanlığın icraatı yok.</div>';
    var kart = function (ic) {
      var hazir = hazirMi(ic.hazir), aktif = ic.aktif_bit && new Date(ic.aktif_bit).getTime() > Date.now();
      var para = Number(v.kasa) >= Number(ic.maliyet);
      var ek = [];
      if (ic.sure_gun) ek.push(ic.sure_gun + " gün");
      ek.push(ic.il_gerekli ? "seçilen ilde" : "tüm ülkede");
      ek.push(Number(ic.bekleme_saat) / 24 + " günde bir");
      var etki = typeof etkiYaz === "function" ? etkiYaz(ic.etki) : etkiYazi(ic.etki);
      var oyuncu = typeof etkiCip === "function" ? etkiCip(ic.oyuncu) : "";
      return '<section class="bkm-etk">' +
        '<div style="display:flex;justify-content:space-between;gap:8px;align-items:flex-start"><h4>' + esc(ic.ad) + '</h4>' + (aktif ? '<span class="bkm-rozet y">Yürürlükte</span>' : '<span class="bkm-rozet">' + mr(ic.maliyet, 0) + '</span>') + '</div>' +
        '<p>' + esc(ic.aciklama) + '</p>' + (oyuncu ? '<div style="margin:-2px 0 6px">' + oyuncu + '</div>' : "") +
        '<div class="bkm-ebil">' + (etki ? '<span>' + esc(etki) + '</span>' : "") + ek.map(function (x) { return '<span>' + esc(x) + '</span>'; }).join("") + '</div>' +
        (hazir ? '<button type="button" class="btn ' + (para ? "altin" : "ikinci") + '" style="margin:0" onclick="icraatYap(\'' + esc(ic.kod) + '\',' + (ic.il_gerekli ? "true" : "false") + ')">' + (para ? "Uygula · " + mr(ic.maliyet, 0) : "Kasada yeterli ödenek yok — ek ödenek iste") + '</button>'
               : '<button type="button" class="btn ikinci" style="margin:0" disabled>Tekrar: ' + esc(zaman(ic.hazir)) + ' (' + kalan(ic.hazir) + ')</button>') +
        '</section>';
    };
    var ulusal = ls.filter(function (x) { return !x.il_gerekli; }), il = ls.filter(function (x) { return x.il_gerekli; });
    return '<div class="bkm-bilgi">İcraat bedeli bakanlık kasasından düşer; etkisi hemen işler. Görev rozetli olanlar haftalık bakanlık görevleridir.</div>' +
      (ulusal.length ? '<h3 class="kucuk" style="margin:4px 2px 8px;color:var(--mut)">Ülke geneli</h3>' + ulusal.map(kart).join("") : "") +
      (il.length ? '<h3 class="kucuk" style="margin:10px 2px 8px;color:var(--mut)">İl bazlı</h3>' + il.map(kart).join("") : "");
  }

  /* ---------- Etkinlik ---------- */
  function etkinlikSekme(v) {
    var h = "", aktif = (v.etkinlikler || []).filter(function (e2) { return e2.aktif; });
    if (aktif.length) aktif.forEach(function (e2) { h += etkinlikKart(e2, v, true); });
    if (v.yetki) {
      h += '<div class="bkm-bilgi">Etkinlik bakanlık kasasından ödenir ve ' + 'süre boyunca herkese açıktır. Oyuncular katılıp kıdem kazanır; katılım arttıkça etkinliğin etkisi ×2\'ye kadar büyür. Aynı anda bir etkinlik sürebilir.</div>';
      (v.etkinlik_turleri || []).forEach(function (t) {
        var hazir = hazirMi(t.hazir), para = Number(v.kasa) >= Number(t.maliyet), engel = aktif.length > 0;
        h += '<section class="bkm-etk"><div style="display:flex;justify-content:space-between;gap:8px"><h4>' + esc(t.ad) + '</h4><span class="bkm-rozet">' + mr(t.maliyet, 0) + '</span></div>' +
          '<p>' + esc(t.aciklama) + '</p><div class="bkm-ebil"><span>' + Number(t.sure_saat) + ' saat</span><span>' + (t.il_gerekli ? "seçilen ilde" : "ülke çapında") + '</span><span>katılana +' + sayi(t.kidem, 1) + ' kıdem</span><span>etki: ' + esc(etkiYazi(t.etki)) + '</span></div>' +
          (engel ? '<button class="btn ikinci" style="margin:0" disabled>Süren etkinlik bitince</button>' :
           !hazir ? '<button class="btn ikinci" style="margin:0" disabled>Tekrar: ' + esc(zaman(t.hazir)) + '</button>' :
           '<button class="btn ' + (para ? "altin" : "ikinci") + '" style="margin:0" onclick="bmEtkinlikModal(\'' + esc(t.kod) + '\')">' + (para ? "Düzenle" : "Kasada yeterli ödenek yok") + '</button>') +
          '</section>';
      });
    } else if (!aktif.length) h += '<div class="bkm-bos">Şu an süren bir bakanlık etkinliği yok.</div>';
    var biten = (v.etkinlikler || []).filter(function (e2) { return !e2.aktif; });
    if (biten.length) h += kutu("Geçmiş etkinlikler", biten.map(function (e2) {
      var s = e2.sonuc || {};
      return satir({ ik: IK.etkinlik, bas: esc(e2.ad) + (e2.il ? " · " + esc(e2.il) : ""), alt: zaman(e2.bas) + " · " + Number(e2.katilimci) + " katılımcı" + (s.carpan ? " · etki ×" + sayi(s.carpan, 2) : ""), sag: e2.durum === "bitti" ? '<span class="bkm-rozet y">Tamamlandı</span>' : '<span class="bkm-rozet">' + esc(e2.durum) + '</span>' });
    }).join(""));
    return h + '<button class="btn ikinci" onclick="ekranAc(bakanlikEtkinlikleriEkrani)">Bütün bakanlıkların etkinlikleri</button>';
  }
  function etkinlikKart(e2, v, masada) {
    return '<section class="bkm-etk canli"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><span class="bkm-canli">Sürüyor</span><span class="kucuk">' + kalan(e2.bit) + ' kaldı</span></div>' +
      '<h4 style="margin-top:6px">' + esc(e2.ad) + (e2.il ? ' · ' + esc(e2.il) : "") + '</h4>' + (e2.not ? '<p>“' + esc(e2.not) + '”</p>' : "") +
      '<div class="bkm-ebil"><span>' + Number(e2.katilimci) + ' katılımcı</span>' + (e2.il ? '<span>' + Number(e2.yerel || 0) + ' ilden</span>' : "") + '<span>bitiş ' + esc(zaman(e2.bit)) + '</span></div>' +
      (masada ? '<p class="kucuk" style="color:var(--mut);margin:0">Katılımı artırmak için partine, derneklere ve Kürsü\'de duyur. Kapanışta etki çarpanı: ×' + sayi(Math.min(2, 0.5 + 0.15 * Number(e2.katilimci)), 2) + '</p>' : "") +
      '</section>';
  }

  /* ---------- Bütçe ---------- */
  function butceSekme(v) {
    var o7 = v.ozet7 || {}, h = "";
    h += '<div class="bkm-tablo"><div><small>Son 7 gün giriş</small><b class="bkm-artı">+' + sayi(o7.gelir, 2) + '</b></div><div><small>Son 7 gün çıkış</small><b>−' + sayi(o7.gider, 2) + '</b></div>' +
      '<div><small>Günlük ödenek</small><b>+' + sayi(v.gunluk, 2) + '</b></div><div><small>Kasa doluluğu</small><b>%' + sayi(v.tavan ? Number(v.kasa) / Number(v.tavan) * 100 : 0, 0) + '</b></div></div>';
    if (v.yetki) {
      var bekl = (v.talepler || []).filter(function (t) { return t.durum === "bekliyor"; })[0];
      h += '<div style="display:flex;gap:8px;margin-bottom:12px">' +
        (v.yetki === "bakan" ? '<button class="btn altin" style="margin:0;flex:1" onclick="bmTalepModal()"' + (bekl ? " disabled" : "") + '>' + (bekl ? "Talebin karar bekliyor" : "Ek ödenek iste") + '</button>' : "") +
        '<button class="btn ikinci" style="margin:0;flex:1" onclick="bmIadeModal()">Hazine\'ye iade et</button></div>';
    }
    var tal = v.talepler || [];
    if (tal.length) h += kutu("Ek ödenek talepleri", tal.map(function (t) {
      var ROZ = { bekliyor: ['s', "Karar bekliyor"], onay: ['y', "Onaylandı"], red: ['k', "Reddedildi"], iptal: ['', "Geri çekildi"], dusen: ['', "Süresi doldu"] }[t.durum] || ['', t.durum];
      return satir({ ik: IK.odenek, bas: mr(t.tutar, 1), alt: esc(t.gerekce) + '<br>' + zaman(t.zaman) + (t.durum === "bekliyor" ? " · " + kalan(t.bitis) + " içinde karar verilmeli" : "") + (t.karar_not ? '<br>Not: ' + esc(t.karar_not) : ""),
        sag: '<span class="bkm-rozet ' + ROZ[0] + '">' + ROZ[1] + '</span>' + (t.durum === "bekliyor" && v.yetki === "bakan" ? '<br><button class="bkm-mini ikinci" style="margin-top:6px" onclick="bmTalepGeriCek(' + Number(t.id) + ')">Geri çek</button>' : "") });
    }).join(""));
    var dg = (v.dagilim30 || []).filter(function (x) { return Number(x.giris) || Number(x.cikis); });
    if (dg.length) {
      var mx = Math.max.apply(null, dg.map(function (x) { return Math.max(Number(x.giris), Number(x.cikis)); })) || 1;
      h += kutu("Son 30 günde para nereden geldi, nereye gitti?", dg.map(function (x) {
        var giris = Number(x.giris), cikis = Number(x.cikis), deger = giris >= cikis ? giris : cikis;
        return '<div class="bkm-dag"><div class="bkm-db"><span>' + esc(HAREKET_AD[x.tur] || x.tur) + '</span><b class="' + (giris >= cikis ? "bkm-artı" : "") + '">' + (giris >= cikis ? "+" + sayi(giris, 2) : "−" + sayi(cikis, 2)) + '</b></div><div class="bkm-bar"><i style="width:' + (deger / mx * 100).toFixed(0) + '%"></i></div></div>';
      }).join("") + '<div style="height:8px"></div>');
    }
    var hr = v.hareketler || [];
    h += kutu("Hesap defteri", hr.length ? hr.map(function (x) {
      var t = Number(x.tutar);
      return satir({ bas: esc(x.aciklama), alt: zaman(x.zaman) + (x.kim ? " · " + esc(x.kim) : "") + " · bakiye " + sayi(x.bakiye, 2),
        sag: x.tur === "tavan" ? '<span class="bkm-rozet">tavan</span>' : '<span class="' + (t > 0 ? "bkm-artı" : "") + '">' + (t > 0 ? "+" : "−") + sayi(Math.abs(t), 2) + '</span>' });
    }).join("") : '<div class="bkm-bos">Hesap defteri 27 Ekim 2026\'dan itibaren tutuluyor; ilk hareket burada görünecek.</div>');
    return h + butceAnlat(v) + '<button class="btn ikinci" onclick="ekranAc(devletButcesiEkrani)">Devlet bütçesi ve bütün bakanlıklar</button>';
  }

  /* ---------- İletişim ---------- */
  function iletisimSekme(v) {
    var h = "", z = v.ziyaret || {}, a = v.aciklama || {};
    if (v.yetki) {
      h += '<div style="display:flex;gap:8px;margin-bottom:12px">' +
        '<button class="btn altin" style="margin:0;flex:1" onclick="bmZiyaretModal()"' + (hazirMi(z.hazir) ? "" : " disabled") + '>' + (hazirMi(z.hazir) ? "Saha ziyareti · " + mr(z.maliyet, 1) : "Ziyaret: " + kalan(z.hazir)) + '</button>' +
        '<button class="btn altin" style="margin:0;flex:1" onclick="bmAciklamaModal()"' + (hazirMi(a.hazir) ? "" : " disabled") + '>' + (hazirMi(a.hazir) ? "Açıklama yap" : "Açıklama: " + kalan(a.hazir)) + '</button></div>';
      var s = v.sorumluluk || {};
      h += kutu("Vatandaş ve Meclis",
        satir({ ik: IK.aciklama, bas: "CİMER başvuruları", alt: Number(s.cimer_bekleyen) + " bekleyen", sag: "›", tik: "bmCimer()" }) +
        satir({ ik: IK.bina, bas: "Soru önergeleri", alt: Number(s.soru_bekleyen) + " bekleyen", sag: "›", tik: "bmSorular()" }));
    }
    h += kutu("Bakanlık açıklamaları", (a.son || []).length ? a.son.map(function (x) {
      return '<div class="bkm-satir" style="display:block"><b style="display:block;font-size:14.5px">' + esc(x.baslik) + '</b><small style="display:block;color:var(--mut);font-size:12px;margin:2px 0 6px">' + zaman(x.zaman) + (x.kad ? " · " + esc(x.kad) : "") + '</small><div style="font-size:13.5px;line-height:1.5;white-space:pre-wrap">' + esc(x.metin) + '</div></div>';
    }).join("") : '<div class="bkm-bos">Henüz açıklama yok.</div>');
    h += kutu("Saha ziyaretleri", (z.son || []).length ? z.son.map(function (x) {
      return satir({ ik: IK.ziyaret, bas: esc(x.il), alt: zaman(x.zaman) + (x.kad ? " · " + esc(x.kad) : "") + (x.not ? '<br>“' + esc(x.not) + '”' : "") });
    }).join("") : '<div class="bkm-bos">Henüz saha ziyareti yok.</div>');
    return h;
  }

  /* ---------- Politika ---------- */
  function politikaSekme(v) {
    return '<div class="bkm-bilgi">Bu ayarlar oyuncuların cüzdanına doğrudan yansır; her değişiklik Resmî Gazete\'de yayımlanır.</div>' +
      '<div class="kart" style="padding-top:4px">' + (typeof politikaKartlari === "function" ? politikaKartlari(v.politikalar) : "") + '</div>';
  }

  /* ---------- eylemler ---------- */
  async function islemYap(ad, arg, mesaj) {
    try {
      var r = await rpc(ad, arg);
      if (r && r.kod && r.icraatlar) { BM.v = r; D._bmPaneller = [{ kod: r.kod, icraatlar: r.icraatlar || [] }]; }
      if (typeof modalKapat === "function") modalKapat();
      if (mesaj) bildir(typeof mesaj === "function" ? mesaj(r) : mesaj);
      if (document.getElementById("bmMasa")) ciz();
      return r;
    } catch (err) { bildir(hata(err), true); return null; }
  }
  window.bmGorevOdul = function (kod) {
    islemYap("bakanlik_gorev_odul_al", { p_kod: BM.kod, p_gorev: kod }, function (r) { return "+" + sayi(r && r.kazanilan, 1) + " kıdem kazandın."; });
  };
  window.bmCimer = function () { if (typeof CIMER === "object" && CIMER) CIMER.sekme = "gelen"; if (typeof cimerEkrani === "function") ekranAc(cimerEkrani); };
  window.bmSorular = function () { if (typeof bakanSoruEkrani === "function") ekranAc(bakanSoruEkrani); else bildir("Soru önergeleri ekranı yüklenemedi.", true); };
  window.bmIhale = function () { if (typeof PZ === "object" && PZ) PZ.ihaleSekme = "masa"; ekranAc(ihaleEkrani); };

  window.bmEtkinlikModal = function (turKod) {
    var v = BM.v, t = (v.etkinlik_turleri || []).filter(function (x) { return x.kod === turKod; })[0]; if (!t) return;
    var p = profil() || {};
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">' + esc(t.ad) + '</h3><p class="alt" style="margin:4px 0 10px">' + esc(t.aciklama) + '</p>' +
      (t.il_gerekli ? '<div class="alan"><label>Etkinlik hangi ilde?</label>' + ilSecici("bmEtkIl", p.il_id) + '</div>' : "") +
      '<div class="alan"><label>Davet notu (isteğe bağlı, en çok 200 karakter)</label><input id="bmEtkNot" maxlength="200" placeholder="Örn. Bütün hemşehrilerimizi bekliyoruz"></div>' +
      '<div class="bkm-ozet">Maliyet: <b>' + mr(t.maliyet, 1) + '</b> (bakanlık kasasından) · ' + Number(t.sure_saat) + ' saat sürer · katılan her oyuncu +' + sayi(t.kidem, 1) + ' kıdem kazanır' + (t.il_gerekli ? ' (başka ilden katılan yarısını)' : '') + '.<br>Kapanışta etki: ' + esc(etkiYazi(t.etki)) + ' × katılım çarpanı (0,5–2).</div>' +
      '<button class="btn altin" id="bmEtkOk">Etkinliği başlat</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    m.querySelector("#bmEtkOk").onclick = async function () {
      this.disabled = true;
      var il = t.il_gerekli ? Number(m.querySelector("#bmEtkIl").value) : null;
      var r = await islemYap("bakanlik_etkinlik_duzenle", { p_tur: t.kod, p_il: il, p_not: m.querySelector("#bmEtkNot").value || null },
        function (r2) { return "Etkinlik başladı." + (r2 && r2.bildirilen ? " " + r2.bildirilen + " hemşehriye duyuruldu." : ""); });
      if (!r) this.disabled = false;
    };
  };
  window.bmZiyaretModal = function () {
    var v = BM.v, z = v.ziyaret || {}, p = profil() || {};
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">Saha ziyareti</h3><p class="alt" style="margin:4px 0 10px">Bir ili ziyaret edip vatandaşlarla buluş, kurumları denetle. İlin memnuniyeti ve gelişmişliği artar; ildeki oyunculara bildirim gider.</p>' +
      '<div class="alan"><label>Hangi il?</label>' + ilSecici("bmZIl", p.il_id) + '</div>' +
      '<div class="alan"><label>Ziyaret notu (isteğe bağlı)</label><input id="bmZNot" maxlength="200" placeholder="Örn. Yeni adliye binasının temelini attık"></div>' +
      '<div class="bkm-ozet">Maliyet: <b>' + mr(z.maliyet, 1) + '</b> · ' + Number(z.bekleme_saat) + ' saatte bir · aynı ile 72 saatte bir.</div>' +
      '<button class="btn altin" id="bmZOk">Ziyareti yap</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    m.querySelector("#bmZOk").onclick = async function () {
      this.disabled = true;
      var r = await islemYap("bakanlik_saha_ziyareti", { p_kod: BM.kod, p_il: Number(m.querySelector("#bmZIl").value), p_not: m.querySelector("#bmZNot").value || null }, "Saha ziyareti Resmî Gazete'de yayımlandı.");
      if (!r) this.disabled = false;
    };
  };
  window.bmAciklamaModal = function () {
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">Bakanlık açıklaması</h3><p class="alt" style="margin:4px 0 10px">Açıklama Resmî Gazete\'de duyuru olarak yayımlanır ve Gündem\'de görünür. Bağlantı paylaşılamaz.</p>' +
      '<div class="alan"><label>Başlık</label><input id="bmABas" maxlength="120" placeholder="Örn. Okullarda ücretsiz öğle yemeği başlıyor"></div>' +
      '<div class="alan"><label>Açıklama</label><textarea id="bmAMetin" maxlength="1200" placeholder="Kamuoyuna ne duyurmak istiyorsun?"></textarea><div class="bkm-say" id="bmASay">0 / 1200</div></div>' +
      '<button class="btn altin" id="bmAOk">Yayımla</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    var ta = m.querySelector("#bmAMetin"); ta.oninput = function () { m.querySelector("#bmASay").textContent = ta.value.length + " / 1200"; };
    m.querySelector("#bmAOk").onclick = async function () {
      this.disabled = true;
      var r = await islemYap("bakanlik_aciklama_yap", { p_kod: BM.kod, p_baslik: m.querySelector("#bmABas").value, p_metin: ta.value }, "Açıklama yayımlandı.");
      if (!r) this.disabled = false;
    };
  };
  window.bmTalepModal = function () {
    var v = BM.v, ta = v.talep_ayar || {}, ust = Number(ta.ust || 25);
    if (!hazirMi(ta.hazir)) { bildir("Yeni talep " + zaman(ta.hazir) + " sonrasında verilebilir.", true); return; }
    var oner = Math.min(ust, Math.max(1, Math.ceil(Number(v.gunluk || 1) * 5)));
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">Ek ödenek talebi</h3><p class="alt" style="margin:4px 0 10px">Talep ' + esc(v.yurutme || "yürütmeye") + '\'e gider. ' + Number(ta.sure_saat || 72) + ' saat içinde karar verilmezse düşer. Onaylanırsa tutar Hazine\'den kasana aktarılır.</p>' +
      '<div class="alan"><label>Tutar (1 – ' + sayi(ust, 0) + ' milyar ₺)</label><input id="bmTTutar" type="number" min="1" max="' + ust + '" step="0.5" value="' + oner + '" inputmode="decimal"></div>' +
      '<div class="bkm-cips">' + [5, 10, 15, ust].filter(function (x, i, a) { return x <= ust && a.indexOf(x) === i; }).map(function (x) { return '<button type="button" data-t="' + x + '">' + sayi(x, 0) + ' milyar</button>'; }).join("") + '</div>' +
      '<div class="alan"><label>Gerekçe (Resmî Gazete\'de yayımlanabilir)</label><textarea id="bmTGer" maxlength="400" placeholder="Örn. Deprem bölgesindeki adliyelerin yeniden inşası için"></textarea></div>' +
      '<button class="btn altin" id="bmTOk">Talebi gönder</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    m.querySelectorAll("[data-t]").forEach(function (b) { b.onclick = function () { m.querySelector("#bmTTutar").value = b.dataset.t; }; });
    m.querySelector("#bmTOk").onclick = async function () {
      this.disabled = true;
      var r = await islemYap("bakanlik_odenek_iste", { p_kod: BM.kod, p_tutar: Number(m.querySelector("#bmTTutar").value), p_gerekce: m.querySelector("#bmTGer").value }, "Talep gönderildi; kararı bildirim olarak gelecek.");
      if (!r) this.disabled = false;
    };
  };
  window.bmTalepGeriCek = async function (id) {
    if (!(await onayla("Talebi geri çek", "Ek ödenek talebin iptal edilecek.", "Geri çek"))) return;
    islemYap("bakanlik_odenek_geri_cek", { p_id: id }, "Talep geri çekildi.");
  };
  window.bmIadeModal = function () {
    var v = BM.v, max = Math.floor(Number(v.kasa) * 10) / 10;
    if (max < 0.1) { bildir("Kasada iade edilecek ödenek yok.", true); return; }
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">Hazine\'ye iade</h3><p class="alt" style="margin:4px 0 10px">Kullanmayacağın ödeneği Hazine\'ye geri gönder. İade kayda geçer ve karnede tasarruf olarak görünür.</p>' +
      '<div class="alan"><label>Tutar (en çok ' + sayi(max, 1) + ' milyar ₺)</label><input id="bmITutar" type="number" min="0.1" max="' + max + '" step="0.1" value="' + Math.min(max, 1) + '" inputmode="decimal"></div>' +
      '<button class="btn altin" id="bmIOk">İade et</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    m.querySelector("#bmIOk").onclick = async function () {
      this.disabled = true;
      var r = await islemYap("bakanlik_hazineye_iade", { p_kod: BM.kod, p_tutar: Number(m.querySelector("#bmITutar").value) }, "Ödenek Hazine'ye iade edildi.");
      if (!r) this.disabled = false;
    };
  };

  /* =====================================================================
     2) YÖNETİM / HÜKÜMET İÇİNDEKİ KISA KART (eski uzun panelin yerine)
     ===================================================================== */
  window.bakanPanelHtml = function (panel, vekalet) {
    if (!panel) return "";
    var hazir = (panel.icraatlar || []).filter(function (ic) { return hazirMi(ic.hazir); }).length;
    var yururluk = (panel.icraatlar || []).filter(function (ic) { return ic.aktif_bit && new Date(ic.aktif_bit).getTime() > Date.now(); }).length;
    return '<div class="bkm-kart" style="' + stilAB(panel.kod) + '"><div class="bkm-kb"><b>' + esc(panel.ad) + '</b><span>' + (vekalet ? "Vekâleten" : "Bakanlığın") + '</span></div>' +
      '<div class="bkm-ks"><div><small>Kasa</small><b>' + sayi(panel.kasa, 1) + ' mr</b></div><div><small>Günlük ödenek</small><b>+' + sayi(panel.gunluk, 2) + '</b></div><div><small>Hazır icraat</small><b>' + hazir + '/' + (panel.icraatlar || []).length + '</b></div></div>' +
      '<div class="bkm-kn">' + (yururluk ? yururluk + " icraat yürürlükte · " : "") + 'İcraat, etkinlik, saha ziyareti, bütçe ve haftalık görevler masada.</div>' +
      '<button type="button" class="bkm-kac" onclick="ekranAc(function(){return bakanlikMasasiEkrani(\'' + esc(panel.kod) + '\')})">Bakanlık masasını aç</button>' +
      (vekalet ? "" : '<button type="button" class="btn tehlike" style="margin:10px 0 0" onclick="bakanIstifa()">Bakanlıktan istifa et</button>') + '</div>';
  };
  // Bildirimden ya da aramadan "masama git"
  window.bakanlikMasamAc = function () {
    var p = profil() || {}, b = (p.makamlar || []).filter(function (x) { return x.tur === "bakan"; })[0];
    if (b && b.bakanlik) return ekranAc(function () { return masaAc(b.bakanlik); });
    return ekranAc(devletButcesiEkrani);
  };

  /* =====================================================================
     3) BAKANLIK ETKİNLİKLERİ (herkes)
     ===================================================================== */
  var ET = { v: null };
  async function etkinliklerEkrani() {
    yukleniyor("Bakanlık etkinlikleri");
    try { ET.v = await rpc("bakanlik_etkinlikleri", { p_limit: 40 }); etkCiz(); }
    catch (err) { iskelet("Bakanlık etkinlikleri", '<div class="kart"><p class="alt">' + esc(hata(err)) + '</p></div>', { geri: true }); }
  }
  window.bakanlikEtkinlikleriEkrani = etkinliklerEkrani;
  function etkCiz() {
    var d = ET.v || {}, ls = d.liste || [], ilim = d.il_id;
    var aktif = ls.filter(function (x) { return x.aktif; }), biten = ls.filter(function (x) { return !x.aktif; });
    var hak = Math.max(0, Number(d.gunluk_odul || 2) - Number(d.bugun_odul || 0));
    var h = '<div class="bkm">';
    h += '<div class="bkm-bilgi">Bakanlar fuar, şenlik, tören ve buluşmalar düzenler. Katıl, tepkini göster: <b>bugün ' + hak + ' ödüllü katılım hakkın var</b> (her biri +0,5 kıdem; başka ilin etkinliği yarısı). Katılım ne kadar yüksekse etkinliğin ülkeye ve ile etkisi o kadar büyük olur.</div>';
    if (!aktif.length) h += '<div class="bkm-bos">Şu an süren bakanlık etkinliği yok. Bakanlar etkinlik düzenleyince burada ve Gündem\'de görünür.</div>';
    aktif.forEach(function (x) {
      var t = x.tepkiler || {};
      var ab = stilAB(x.bakanlik);
      h += '<section class="bkm-etk canli" style="' + ab + '"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><span class="bkm-canli">Sürüyor</span><span class="kucuk">' + kalan(x.bit) + ' kaldı</span></div>' +
        '<h4 style="margin-top:6px">' + esc(x.ad) + (x.il ? ' · ' + esc(x.il) : ' · ülke çapında') + '</h4>' +
        '<div class="kucuk" style="color:var(--mut)">' + esc(x.bakanlik_ad) + ' · düzenleyen ' + esc(x.kad || "") + '</div>' +
        '<p>' + esc(x.aciklama) + '</p>' + (x.not ? '<p style="font-style:italic">“' + esc(x.not) + '”</p>' : "") +
        '<div class="bkm-ebil"><span>' + Number(x.katilimci) + ' katılımcı</span><span>👏 ' + Number(t.destek || 0) + ' · 🙋 ' + Number(t.katildim || 0) + ' · 🤔 ' + Number(t.elestiri || 0) + '</span>' +
        (x.il_id && ilim && Number(x.il_id) === Number(ilim) ? '<span>senin ilin: tam ödül</span>' : x.il_id ? '<span>başka il: yarım ödül</span>' : "") + '</div>' +
        (x.duzenleyen_benim ? '<p class="kucuk" style="color:var(--mut);margin:0">Bu etkinliği sen düzenledin.</p>' :
         '<div class="bkm-tepki">' + [["katildim", "Katıldım"], ["destek", "Destekliyorum"], ["elestiri", "Eleştiriyorum"]].map(function (r) {
           return '<button type="button" class="' + (x.benim === r[0] ? "on" : "") + '" onclick="bmKatil(' + Number(x.id) + ',\'' + r[0] + '\')">' + r[1] + '</button>';
         }).join("") + '</div>' + (x.benim ? '<p class="kucuk" style="color:var(--mut);margin:8px 0 0">Katıldın; tepkini değiştirebilirsin.</p>' : "")) +
        '</section>';
    });
    if (biten.length) h += kutu("Son 48 saatte tamamlananlar", biten.map(function (x) {
      var s = x.sonuc || {};
      return satir({ bas: esc(x.ad) + (x.il ? " · " + esc(x.il) : ""), alt: esc(x.bakanlik_ad) + " · " + Number(x.katilimci) + " katılımcı" + (s.carpan ? " · etki ×" + sayi(s.carpan, 2) : "") + (s.etki ? " · " + esc(etkiYazi(s.etki)) : ""), sag: '<span class="bkm-rozet y">Tamamlandı</span>' });
    }).join(""));
    h += '<button class="btn ikinci" onclick="ekranAc(devletButcesiEkrani)">Bakanlıklar ve devlet bütçesi</button></div>';
    iskelet("Bakanlık etkinlikleri", h, { geri: true });
  }
  window.bmKatil = async function (id, tepki) {
    try {
      var r = await rpc("bakanlik_etkinlik_katil", { p_id: id, p_tepki: tepki });
      bildir(r && r.guncellendi ? "Tepkin güncellendi." : r && Number(r.odul) > 0 ? "Katıldın: +" + sayi(r.odul, 2) + " kıdem." : (r && r.not) || "Katılımın kaydedildi.");
      ET.v = await rpc("bakanlik_etkinlikleri", { p_limit: 40 });
      var h1 = document.querySelector("header.ust h1");
      if (h1 && h1.textContent === "Bakanlık etkinlikleri") etkCiz();
    } catch (err) { bildir(hata(err), true); }
  };

  /* =====================================================================
     4) DEVLET BÜTÇESİ (herkes görür; yürütme karar verir)
     ===================================================================== */
  var DB = { v: null };
  async function butceEkrani() {
    yukleniyor("Devlet bütçesi");
    try { DB.v = await rpc("yurutme_butce_masasi"); dbCiz(); }
    catch (err) { iskelet("Devlet bütçesi", '<div class="kart"><p class="alt">' + esc(hata(err)) + '</p></div>', { geri: true }); }
  }
  window.devletButcesiEkrani = butceEkrani;
  window.kamuButceEkrani = butceEkrani;      // menüdeki "Devlet bütçesi" bağlantısı
  function dbCiz() {
    var d = DB.v || {}, hs = d.hesap || {}, ls = d.bakanliklar || [], y = d.yetkili;
    var yur = d.sistem === "parlamenter" ? "Başbakan" : "Cumhurbaşkanı";
    var mb = d.maliye && d.maliye.bugun;   // 31.10.2026: gerçekleşen bütçe (modül 158); yoksa tahmini cari bütçe
    var h = '<div class="bkm" style="--a:#3d5bd9;--b:#141c46">';
    h += '<section class="bkm-kimlik"><div class="bkm-ust"><span class="bkm-amb">' + IK.kasa + '</span><div><h2>Merkezi Yönetim Bütçesi</h2><div class="bkm-alt">' + (d.yurutme ? yur + " " + esc(d.yurutme) : "Yürütme boş") + '</div></div></div>' +
      '<div class="bkm-kasa"><div><small>Hazine</small><b>' + sayi(d.hazine, 1) + ' <span>milyar ₺</span></b></div>' +
      (d.maliye && d.maliye.varlik_fonu != null ? '<div style="text-align:right"><small>Varlık Fonu</small><b style="font-size:17px">' + sayi(d.maliye.varlik_fonu, 0) + '</b></div>' : '') + '</div>' +
      (mb ? '<div style="font-size:11px;opacity:.78;margin-top:12px">Bugün gerçekleşen (milyar ₺)</div><div class="bkm-uc" style="margin-top:6px"><div><small>Gelir</small><b>+' + sayi(mb.gelir, 2) + '</b></div><div><small>Harcama</small><b>' + sayi(mb.harcama, 2) + '</b></div><div><small>Denge</small><b>' + (Number(mb.denge) >= 0 ? "+" : "") + sayi(mb.denge, 2) + '</b></div></div>'
        : '<div class="bkm-uc"><div><small>Günlük gelir</small><b>' + sayi(hs.gelir, 2) + '</b></div><div><small>Günlük gider</small><b>' + sayi(hs.gider, 2) + '</b></div><div><small>Günlük denge</small><b>' + (Number(hs.denge) >= 0 ? "+" : "") + sayi(hs.denge, 2) + '</b></div></div>') +
      '</section>';
    var bek = (d.talepler || []).filter(function (t) { return t.durum === "bekliyor"; });
    if (y && bek.length) h += kutu("Karar bekleyen ek ödenek talepleri", bek.map(function (t) {
      return '<div class="bkm-satir" style="display:block"><div style="display:flex;justify-content:space-between;gap:8px"><b>' + esc(kisaAd(t.ad)) + ' · ' + mr(t.tutar, 1) + '</b><span class="bkm-rozet s">' + kalan(t.bitis) + '</span></div>' +
        '<small style="display:block;color:var(--mut);margin:3px 0 8px">' + esc(t.kad || "") + ': ' + esc(t.gerekce) + '</small>' +
        '<div style="display:flex;gap:8px"><button class="bkm-mini" onclick="bmKarar(' + Number(t.id) + ',true)">Onayla</button><button class="bkm-mini ikinci" onclick="bmKarar(' + Number(t.id) + ',false)">Reddet</button></div></div>';
    }).join(""), '<span class="bkm-rozet k">' + bek.length + '</span>');
    else if (bek.length) h += kutu("Karar bekleyen ek ödenek talepleri", bek.map(function (t) {
      return satir({ ik: IK.odenek, bas: esc(kisaAd(t.ad)) + " · " + mr(t.tutar, 1), alt: esc(t.gerekce), sag: '<span class="bkm-rozet s">bekliyor</span>' });
    }).join(""));
    h += kutu("Bakanlıklar · kasa, günlük ödenek, karne", ls.map(function (b) {
      return '<div class="bkm-satir" role="button" tabindex="0" style="cursor:pointer" onclick="ekranAc(function(){return bakanlikMasasiEkrani(\'' + esc(b.kod) + '\')})">' +
        '<span class="bkm-ik" style="' + stilAB(b.kod) + '">' + IK.bina + '</span><span class="bkm-orta"><b>' + esc(kisaAd(b.ad)) + (b.aktif_etkinlik ? ' <span class="bkm-canli" style="font-size:11px">etkinlik</span>' : "") + '</b>' +
        '<small>' + (b.bakan ? esc(b.bakan) : "Bakan yok · vekâleten") + ' · pay %' + sayi(b.pay, 1) + ' · +' + sayi(b.gunluk, 2) + '/gün · 7 günde ' + sayi(b.harcama7, 1) + ' harcadı</small></span>' +
        '<span class="bkm-sag">' + sayi(b.kasa, 1) + '<small>karne ' + Number(b.puan || 0) + '</small></span></div>';
    }).join(""));
    if (y) {
      h += kutu(yur + " araçları",
        satir({ ik: IK.aktarim || IK.iade, bas: "Bakanlıklar arası ödenek aktar", alt: "Bir bakanlığın kasasının en çok %" + sayi(d.aktarim_oran, 0) + "'i, " + Number(d.aktarim_bekleme_saat) + " saatte bir", sag: "›", tik: "bmAktarModal()" }) +
        (d.cb ? satir({ ik: IK.kasa, bas: "Merkezi bütçe tahsisi", alt: "Hazine'den 12 bakanlığa paylı aktarım (24 saatte bir, en çok 5 milyar ₺)" + (d.son_tahsis ? " · son " + zaman(d.son_tahsis) : ""), sag: "›", tik: "bmTahsisModal()" }) : "") +
        (typeof kararnameModal === "function" && d.sistem !== "parlamenter" ? satir({ ik: IK.aciklama, bas: "Kararnameyle ek ödenek", alt: "Tek bakanlığa 1–30 milyar ₺ (Resmî Gazete)", sag: "›", tik: "kararnameModal('odenek')" }) : ""));
    }
    var gec = (d.talepler || []).filter(function (t) { return t.durum !== "bekliyor"; });
    if (gec.length) h += kutu("Son 14 günün talepleri", gec.slice(0, 12).map(function (t) {
      var R = { onay: ["y", "Onay"], red: ["k", "Ret"], iptal: ["", "Geri çekildi"], dusen: ["", "Düştü"] }[t.durum] || ["", t.durum];
      return satir({ bas: esc(kisaAd(t.ad)) + " · " + mr(t.tutar, 1), alt: zaman(t.zaman) + (t.karar_not ? " · " + esc(t.karar_not) : ""), sag: '<span class="bkm-rozet ' + R[0] + '">' + R[1] + '</span>' });
    }).join(""));
    var p = profil() || {};
    var mv = (p.makamlar || []).some(function (x) { return x.tur === "mv"; });
    h += '<details class="bkm-acil"><summary>Devlet bütçesi nasıl işler?</summary><p>' +
      'Hazine\'nin geliri gelir vergisi (oyuncu maaşlarından kesilen dahil), KDV/ÖTV, şirket vergileri, harçlar ve cezalardan; gideri bakanlık ödenekleri, belediye payı, sosyal destek, partilere Hazine yardımı ve faizden oluşur. ' +
      'Meclis bütçe kanunuyla 12 bakanlığın payını belirler; bu paylar her gece bakanlık kasalarına ödenek olarak akar (kasa tavanı ' + sayi(d.tavan, 0) + ' milyar ₺, aşan kısım Hazine\'de kalır). ' +
      yur + ' gerekçeli ek ödenek taleplerini onaylar ya da reddeder, bakanlıklar arasında ödenek aktarabilir. Her onay Hazine\'den düşer; devlet gelirinden fazla harcarsa bütçe açığı enflasyonu ve faizi yükseltir, fazla verirse enflasyon düşer. Hazine eksiye düşerse açık Merkez Bankası kaynağıyla kapanır. Bütün hareketler herkese açıktır.</p></details>';
    if (mv && typeof kanunTeklifEkrani === "function") h += '<button class="btn ikinci" onclick="ekranAc(function(){return kanunTeklifEkrani(\'butce\')})">Meclis\'e bütçe kanunu teklifi ver</button>';
    h += '<button class="btn ikinci" onclick="ekranAc(bakanlikEtkinlikleriEkrani)">Bakanlık etkinlikleri</button></div>';
    iskelet("Devlet bütçesi", h, { geri: true });
  }
  IK.aktarim = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3l4 4-4 4"/><path d="M3 7h18"/><path d="M7 21l-4-4 4-4"/><path d="M21 17H3"/></svg>';
  async function dbIslem(ad, arg, mesaj) {
    try { DB.v = await rpc(ad, arg); if (typeof modalKapat === "function") modalKapat(); bildir(mesaj); if (DB.v && DB.v.bakanliklar) dbCiz(); else butceEkrani(); return true; }
    catch (err) { bildir(hata(err), true); return false; }
  }
  window.bmKarar = function (id, kabul) {
    var t = ((DB.v && DB.v.talepler) || []).filter(function (x) { return Number(x.id) === Number(id); })[0] || {};
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">' + (kabul ? "Ek ödeneği onayla" : "Talebi reddet") + '</h3>' +
      '<div class="bkm-ozet"><b>' + esc(t.ad || "") + '</b> · ' + mr(t.tutar, 1) + '<br>' + esc(t.gerekce || "") + '</div>' +
      (kabul ? (function () {
        var hz = Number(DB.v && DB.v.hazine), son = hz - Number(t.tutar || 0);
        return '<p class="alt">Tutar Hazine\'den bakanlık kasasına aktarılır ve Resmî Gazete\'de yayımlanır.</p>' +
          '<div class="bkm-ozet">Hazine: <b>' + mr(hz, 1) + '</b> → <b>' + mr(son, 1) + '</b>' +
          (son < 0 ? '<br><b>Hazine\'de yeterli nakit yok.</b>' : '<br>Bakanlık bu parayı harcadığında, devlet gelirinden fazla harcıyorsa bütçe açığı büyür; açık sürerse enflasyon yükselir.') + '</div>';
      })() : "") +
      '<div class="alan"><label>' + (kabul ? "Not (isteğe bağlı)" : "Ret gerekçesi (isteğe bağlı)") + '</label><input id="bmKNot" maxlength="300"></div>' +
      '<button class="btn ' + (kabul ? "altin" : "tehlike") + '" id="bmKOk">' + (kabul ? "Onayla ve aktar" : "Reddet") + '</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    m.querySelector("#bmKOk").onclick = async function () {
      this.disabled = true;
      var ok = await dbIslem("bakanlik_odenek_karar", { p_id: id, p_kabul: !!kabul, p_not: m.querySelector("#bmKNot").value || null }, kabul ? "Ek ödenek onaylandı." : "Talep reddedildi.");
      if (!ok) this.disabled = false;
    };
  };
  window.bmAktarModal = function () {
    var ls = (DB.v && DB.v.bakanliklar) || [];
    var sec = function (id, def) { return '<select id="' + id + '">' + ls.map(function (b) { return '<option value="' + esc(b.kod) + '"' + (b.kod === def ? " selected" : "") + '>' + esc(kisaAd(b.ad)) + ' · ' + sayi(b.kasa, 1) + '</option>'; }).join("") + '</select>'; };
    var zengin = ls.slice().sort(function (a, b) { return Number(b.kasa) - Number(a.kasa); });
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">Ödenek aktarımı</h3><p class="alt" style="margin:4px 0 10px">Kaynak bakanlığın kasasının en çok %' + sayi(DB.v.aktarim_oran, 0) + '\'i aktarılabilir. İki bakana da bildirim gider; Resmî Gazete\'de yayımlanır.</p>' +
      '<div class="alan"><label>Kaynak bakanlık</label>' + sec("bmAK", zengin[0] && zengin[0].kod) + '</div>' +
      '<div class="alan"><label>Hedef bakanlık</label>' + sec("bmAH", zengin[zengin.length - 1] && zengin[zengin.length - 1].kod) + '</div>' +
      '<div class="alan"><label>Tutar (milyar ₺, en az 0,5)</label><input id="bmAT" type="number" min="0.5" step="0.5" value="1" inputmode="decimal"></div>' +
      '<button class="btn altin" id="bmAOk2">Aktar</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    m.querySelector("#bmAOk2").onclick = async function () {
      this.disabled = true;
      var ok = await dbIslem("bakanlik_odenek_aktar", { p_kaynak: m.querySelector("#bmAK").value, p_hedef: m.querySelector("#bmAH").value, p_tutar: Number(m.querySelector("#bmAT").value) }, "Ödenek aktarıldı.");
      if (!ok) this.disabled = false;
    };
  };
  window.bmTahsisModal = function () {
    var ls = (DB.v && DB.v.bakanliklar) || [];
    var m = bmModal('<h3 style="font-size:19px;font-weight:800">Merkezi bütçe tahsisi</h3><p class="alt" style="margin:4px 0 10px">Hazine\'den seçtiğin bakanlıklara paylı aktarım. Payların toplamı %100 olmalı; boş bıraktığın bakanlık pay almaz. 24 saatte bir yapılabilir.</p>' +
      '<div class="alan"><label>Toplam (0,001 – 5 milyar ₺)</label><input id="bmTT" type="number" min="0.001" max="5" step="0.1" value="2" inputmode="decimal"></div>' +
      ls.map(function (b) { return '<div class="alan" style="display:flex;align-items:center;gap:10px;margin-bottom:6px"><label style="flex:1;margin:0">' + esc(kisaAd(b.ad)) + '</label><input data-pay="' + esc(b.kod) + '" type="number" min="0" max="100" step="1" placeholder="%" style="width:90px" inputmode="numeric"></div>'; }).join("") +
      '<div class="bkm-ozet" id="bmTTop">Toplam pay: %0</div>' +
      '<button class="btn altin" id="bmTTOk">Tahsis et</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    var topla = function () { var s = 0; m.querySelectorAll("[data-pay]").forEach(function (i) { s += Number(i.value || 0); }); m.querySelector("#bmTTop").textContent = "Toplam pay: %" + s; return s; };
    m.querySelectorAll("[data-pay]").forEach(function (i) { i.oninput = topla; });
    m.querySelector("#bmTTOk").onclick = async function () {
      var pay = {}; m.querySelectorAll("[data-pay]").forEach(function (i) { if (Number(i.value) > 0) pay[i.dataset.pay] = Number(i.value); });
      if (topla() !== 100) { bildir("Payların toplamı %100 olmalı.", true); return; }
      this.disabled = true;
      try {
        await rpc("kamu_butce_dagit", { p_toplam: Number(m.querySelector("#bmTT").value), p_paylar: pay });
        modalKapat(); bildir("Bütçe tahsis edildi."); butceEkrani();
      } catch (err) { bildir(hata(err), true); this.disabled = false; }
    };
  };

  /* =====================================================================
     5) GÜNDEM ŞERİDİ ve DEVLET › HÜKÜMET KARTI
     ===================================================================== */
  var sonSerit = 0;
  function gundemSerit() {
    if (Date.now() - sonSerit < 1500) return; sonSerit = Date.now();
    rpc("bakanlik_etkinlikleri", { p_limit: 10 }).then(function (d) {
      var ic = document.getElementById("icerik"), h1 = document.querySelector("header.ust h1");
      if (!ic || !h1 || h1.textContent !== "Gündem" || document.getElementById("bmGundemSerit")) return;
      var ak = ((d && d.liste) || []).filter(function (x) { return x.aktif && !x.duzenleyen_benim; });
      if (!ak.length) return;
      var ilim = d.il_id, ilde = ak.filter(function (x) { return x.il_id && Number(x.il_id) === Number(ilim); })[0], x = ilde || ak[0];
      var katilmadi = ak.filter(function (y) { return !y.benim; }).length;
      var el = document.createElement("div");
      el.id = "bmGundemSerit"; el.className = "bkm-serit"; el.setAttribute("role", "button"); el.setAttribute("style", stilAB(x.bakanlik));
      el.onclick = function () { ekranAc(etkinliklerEkrani); };
      el.innerHTML = '<span class="bkm-sik">' + IK.etkinlik + '</span><span class="bkm-so"><b>' + esc(x.ad) + (x.il ? " · " + esc(x.il) : "") + '</b><small><span class="bkm-canli">Bakanlık etkinliği</span> · ' + (katilmadi ? "katıl, kıdem kazan" : "katıldın") + (ak.length > 1 ? " · " + ak.length + " etkinlik sürüyor" : "") + '</small></span><span class="bkm-ok">›</span>';
      var kum = ic.querySelector(".pa-kumbara, [data-pa-hizli]");
      var hedef = kum ? (ic.querySelector("[data-pa-hizli]") || kum) : null;
      if (hedef && hedef.parentNode) hedef.parentNode.insertBefore(el, hedef.nextSibling); else ic.insertBefore(el, ic.firstChild);
    }).catch(function () {});
  }
  function hukumetKart() {
    var ic = document.getElementById("icerik"); if (!ic || document.getElementById("bmHukumetKart")) return;
    var seg = ic.querySelector(".segment .aktif"); if (!seg || !/Hükümet/.test(seg.textContent)) return;
    var p = profil() || {}, b = (p.makamlar || []).filter(function (x) { return x.tur === "bakan"; })[0];
    var el = document.createElement("div"); el.id = "bmHukumetKart"; el.className = "kart";
    el.innerHTML = '<h2>Bakanlıklar</h2><p class="alt" style="margin-bottom:8px">Bakanlık kasaları, ödenek talepleri, bakan karneleri ve oyunculara açık bakanlık etkinlikleri.</p>' +
      (b ? '<button class="btn altin" onclick="bakanlikMasamAc()">Bakanlık masam</button>' : "") +
      '<button class="btn ' + (b ? "ikinci" : "altin") + '" onclick="ekranAc(devletButcesiEkrani)">Devlet bütçesi ve bakanlık sayfaları</button>' +
      '<button class="btn ikinci" onclick="ekranAc(bakanlikEtkinlikleriEkrani)">Bakanlık etkinlikleri — katıl, kıdem kazan</button>';
    var seg2 = ic.querySelector(".segment");
    var ilk = seg2 ? seg2.nextElementSibling : ic.firstElementChild;
    if (ilk && ilk.nextSibling) ic.insertBefore(el, ilk.nextSibling); else ic.appendChild(el);
  }
  if (typeof iskelet === "function") {
    var eskiIskelet = iskelet;
    iskelet = window.iskelet = function (baslik) {
      var r = eskiIskelet.apply(this, arguments);
      try {
        if (baslik === "Gündem") setTimeout(gundemSerit, 30);
        else if (baslik === "Devlet" && typeof D === "object" && D && (D.devletSekme || "hukumet") === "hukumet") setTimeout(hukumetKart, 30);
      } catch (_) {}
      return r;
    };
  }
})();
