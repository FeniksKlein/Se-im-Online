/* =====================================================================
   Seçim Online — BAKANLIK MASASI (27.10.2026 · Masa 2.0: 06.11.2026)
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
    var ms = new Date(ts).getTime() - (typeof simdi === "function" ? simdi() : Date.now());
    if (ms <= 0) return "şimdi";
    var dk = Math.round(ms / 60000);
    if (dk < 60) return dk + " dk";
    var sa = Math.floor(dk / 60), d2 = dk % 60;
    if (sa < 48) return sa + " sa" + (d2 ? " " + d2 + " dk" : "");
    return Math.round(sa / 24) + " gün";
  };
  var hazirMi = function (ts) { return !ts || new Date(ts).getTime() <= (typeof simdi === "function" ? simdi() : Date.now()); };
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

  // İcraat / politika sonrası doğru ekran yenilensin (index.html bu adı çağırır)
  window.bakanSonrasiYenile = function () {
    if (document.getElementById("bmMasa") && BM.kod) return masaAc(BM.kod, BM.sekme);
    if (typeof devletEkrani === "function") return devletEkrani();
  };

  /* =====================================================================
     MASA 2.0 (06.11.2026) — tek resmî künye, sığan sekmeler, kullanışlı masa.
     Künye data-dk="kunye" taşır: makam_kurumsal.js ikinci bir künye eklemez.
     Sekme anahtarları aynı (ozet/icraat/etkinlik/butce/iletisim); "politika"
     artık İcraat sekmesinin başında. İşlem pencereleri (bm*Modal) değişmedi.
     ===================================================================== */
  var simdiMs = function () { try { return typeof simdi === "function" ? simdi() : Date.now(); } catch (_) { return Date.now(); } };
  var AY = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
  var parca = function (ts) {
    var d = new Date(ts); if (isNaN(d)) return null;
    var p = {}; new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", year: "numeric", month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
      .formatToParts(d).forEach(function (x) { p[x.type] = x.value; });
    return { g: +p.day, a: +p.month, y: +p.year, s: p.hour, d: p.minute };
  };
  var gunAnahtar = function (ms) { var p = parca(ms); return p ? p.y + "-" + p.a + "-" + p.g : ""; };
  var oncesi = function (ts) {                       // az önce · 5 dk önce · 3 sa önce · dün 16:10 · 4 Kasım
    var t = new Date(ts).getTime(); if (!isFinite(t)) return "";
    var ms = simdiMs() - t, p = parca(t);
    if (ms < 0) return ileri(ts);
    if (ms < 6e4) return "az önce";
    if (ms < 36e5) return Math.floor(ms / 6e4) + " dk önce";
    if (gunAnahtar(t) === gunAnahtar(simdiMs())) return Math.floor(ms / 36e5) + " sa önce";
    if (gunAnahtar(t) === gunAnahtar(simdiMs() - 864e5)) return "dün " + p.s + ":" + p.d;
    return p.g + " " + AY[p.a - 1];
  };
  var ileri = function (ts) {                        // bugün 23:10 · yarın 08:00 · 8 Kasım 23:10
    var t = new Date(ts).getTime(), p = parca(t); if (!p) return "";
    var k = gunAnahtar(t);
    if (k === gunAnahtar(simdiMs())) return "bugün " + p.s + ":" + p.d;
    if (k === gunAnahtar(simdiMs() + 864e5)) return "yarın " + p.s + ":" + p.d;
    return p.g + " " + AY[p.a - 1] + " " + p.s + ":" + p.d;
  };
  var tarihKisa = function (ts) { var p = parca(ts); return p ? p.g + " " + AY[p.a - 1] : ""; };
  var kesir = function (n) { return Number(n || 0).toLocaleString("tr-TR", { minimumFractionDigits: 0, maximumFractionDigits: 2 }); };
  var mrK = function (n) { return Number(n || 0).toLocaleString("tr-TR", { minimumFractionDigits: 0, maximumFractionDigits: 1 }) + " milyar ₺"; };
  var beklemeYaz = function (saat) {
    var s = Number(saat) || 0; if (!s) return "beklemesiz";
    if (s < 24) return s + " saatte bir";
    var g = s / 24; return (g % 1 ? kesir(g) : g) + " günde bir";
  };
  var hexRgb = function (h) { var m = /^#?([0-9a-f]{6})$/i.exec(h || ""); if (!m) return [75, 94, 168]; var n = parseInt(m[1], 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; };
  var karis = function (h1, h2, t) { var a = hexRgb(h1), b = hexRgb(h2); return "rgb(" + a.map(function (x, i) { return Math.round(x + (b[i] - x) * t); }).join(",") + ")"; };
  var saydam = function (h, a) { return "rgba(" + hexRgb(h).join(",") + "," + a + ")"; };
  var renkStil = function (kod) {
    var r = renk(kod);
    return "--a:" + r[0] + ";--b:" + r[1] + ";--k1:" + saydam(r[0], .46) + ";--k2:" + karis(r[1], r[0], .28) + ";--at:" + saydam(r[0], .17) + ";--ac:" + karis(r[0], "#ffffff", .5) + ";--a2:" + karis(r[0], "#ffffff", .16);
  };
  var sv = function (p) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>'; };
  // Her bakanlığa kendi simgesi (mühürde ve filigranda)
  var BIK = {
    adalet: sv('<path d="M12 3.5v16.5M8 20h8M4.5 7h15M12 5.5 4.5 7M12 5.5 19.5 7"/><path d="M4.5 7 2 13a2.5 2.5 0 0 0 5 0zM19.5 7 17 13a2.5 2.5 0 0 0 5 0z"/>'),
    disisleri: sv('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'),
    icisleri: sv('<path d="M12 3 4.5 6v5.5c0 4.6 3.2 8.4 7.5 9.5 4.3-1.1 7.5-4.9 7.5-9.5V6z"/><path d="m8.8 12 2.2 2.2 4.3-4.4"/>'),
    maliye: sv('<circle cx="12" cy="12" r="9"/><path d="M10 6.5v11M7.6 11l5.8-2.4M7.6 14l5.8-2.4M10 17.5c3.4 0 6-2.6 6-6"/>'),
    savunma: sv('<path d="M12 3 4.5 6v5.5c0 4.6 3.2 8.4 7.5 9.5 4.3-1.1 7.5-4.9 7.5-9.5V6z"/><path d="m12 7.8 1.3 2.6 2.8.4-2 2 .5 2.8-2.6-1.4-2.6 1.4.5-2.8-2-2 2.8-.4z"/>'),
    egitim: sv('<path d="m2 9.5 10-5 10 5-10 5z"/><path d="M6 11.5v4.8c0 1.5 2.7 3 6 3s6-1.5 6-3v-4.8M22 9.5V15"/>'),
    saglik: sv('<path d="M12 20s-7.5-4.5-9.2-9.2C1.5 7.2 3.8 4 7.1 4c2 0 3.6 1.1 4.9 2.8C13.3 5.1 14.9 4 16.9 4c3.3 0 5.6 3.2 4.3 6.8C19.5 15.5 12 20 12 20z"/><path d="M6.5 11.5h3l1.4-2.6 2.4 5 1.4-2.4h2.8"/>'),
    sanayi: sv('<path d="M3 21V10.5l5 3v-3l5 3V7l8 4v10z"/><path d="M3 21h18M7.5 17.5h1.5M12.5 17.5H14M17 17.5h1.5"/>'),
    ticaret: sv('<path d="M4.5 10v10h15V10"/><path d="M3 4h18l-1.4 4.6a2.4 2.4 0 0 1-4.6 0 2.4 2.4 0 0 1-4.6 0 2.4 2.4 0 0 1-4.6 0 2.4 2.4 0 0 1-1.4-.6z"/><path d="M10 20v-5h4v5"/>'),
    tarim: sv('<path d="M12 21V10"/><path d="M12 10C12 6 9.2 3 4 3c0 5.1 3 7 8 7zM12 14c0-4 2.8-7 8-7 0 5.1-3 7-8 7z"/>'),
    ulastirma: sv('<path d="M8.5 3 4 21M15.5 3 20 21M12 4.5v2.5M12 10.5v3M12 17v3"/>'),
    calisma: sv('<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5.2A2.2 2.2 0 0 1 11.2 3h1.6A2.2 2.2 0 0 1 15 5.2V7M3 13h18M10.5 13v2h3v-2"/>')
  };
  var bakIkon = function (kod) { return BIK[kod] || IK.bina; };
  var IK2 = {
    ok: sv('<path d="m9 6 6 6-6 6"/>'),
    saat: sv('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
    tik: sv('<path d="m5 12.5 4.5 4.5L19 7.5"/>'),
    konum: sv('<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>'),
    ulke: sv('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'),
    cimer: sv('<path d="M4 13h4l1.5 3h5L16 13h4"/><path d="M5.5 5h13L21 13v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-5z"/>'),
    soru: sv('<path d="M21 12a8.5 8.5 0 0 1-12.4 7.6L3 21l1.4-5.6A8.5 8.5 0 1 1 21 12z"/><path d="M9.8 9.6a2.3 2.3 0 0 1 4.4.9c0 1.6-2.2 2-2.2 3.2M12 16.6h.01"/>'),
    toren: sv('<path d="M3 21h18M5 21V10M9.5 21V10M14.5 21V10M19 21V10M2.5 10 12 3l9.5 7z"/>'),
    kisi: sv('<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>'),
    cikis: sv('<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l-5-5 5-5M5 12h11"/>'),
    giris: sv('<path d="M12 5v14M6 13l6 6 6-6"/>'),
    cikan: sv('<path d="M12 19V5M6 11l6-6 6 6"/>'),
    kilit: sv('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
    ayar: sv('<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1.5 14h5M9.5 8h5M17.5 16h5"/>'),
    yildiz: sv('<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>')
  };
  var ETKI_TERS = { enflasyon: 1, issizlik: 1 };       // azalması iyi olanlar
  var etkiCipleri = function (e2) {
    return Object.keys(e2 || {}).map(function (k) {
      var v = Number(e2[k]); if (!v) return "";
      var iyi = ETKI_TERS[k] ? v < 0 : v > 0;
      return '<span class="bmv-etki ' + (iyi ? "iyi" : "kotu") + '">' + esc(ETKI_AD[k] || k) + " " + (v > 0 ? "+" : "−") + kesir(Math.abs(v)) + '</span>';
    }).join("");
  };
  var halka = function (p) {
    var r = 15.5, c = 2 * Math.PI * r, d = Math.max(0, Math.min(100, Number(p) || 0)) / 100 * c;
    return '<svg class="bmv-halka" viewBox="0 0 36 36" aria-hidden="true"><circle cx="18" cy="18" r="' + r + '" class="z"/>' +
      (d > 0.05 ? '<circle cx="18" cy="18" r="' + r + '" class="d" stroke-dasharray="' + d.toFixed(2) + ' ' + c.toFixed(2) + '"/>' : '') + '</svg>';
  };
  var aktifMi = function (i) { return !!(i.aktif_bit && new Date(i.aktif_bit).getTime() > simdiMs()); };

  /* ---------------- stil ---------------- */
  (function () {
    if (document.getElementById("bmv-stil")) return;
    var css = [
      ".bmv{--g:#d9b25b;--g2:#f2d58f}",
      ".bmv [hidden]{display:none!important}.bmv-iz{display:block;height:0}",
      /* künye */
      ".bmv-kunye{position:relative;overflow:hidden;isolation:isolate;margin:0 0 12px;padding:16px 16px 14px;border-radius:24px;color:#fff;background:radial-gradient(120% 85% at 100% 0%,var(--k1),transparent 62%),linear-gradient(168deg,var(--k2),#0c1230 80%);border:1px solid rgba(217,178,91,.3);box-shadow:0 26px 44px -32px var(--a),inset 0 1px 0 rgba(255,255,255,.06)}",
      ".bmv-kunye::before{content:'';position:absolute;inset:6px;border-radius:19px;border:1px solid rgba(217,178,91,.13);pointer-events:none;z-index:-1}",
      ".bmv-kunye::after{content:'';position:absolute;inset:0;z-index:-2;pointer-events:none;background:repeating-radial-gradient(circle at 108% -14%,rgba(217,178,91,.085) 0 1px,transparent 1px 9px);-webkit-mask-image:linear-gradient(205deg,#000 8%,transparent 58%);mask-image:linear-gradient(205deg,#000 8%,transparent 58%)}",
      ".bmv-filigran{position:absolute;right:-26px;bottom:-30px;width:168px;height:168px;color:#fff;opacity:.04;z-index:-1;pointer-events:none}",
      ".bmv-filigran svg{width:100%;height:100%;stroke-width:1.1}",
      ".bmv-k-ust{display:flex;align-items:center;gap:13px}",
      ".bmv-muhur{flex:none;position:relative;width:58px;height:58px;border-radius:50%;display:grid;place-items:center;color:#f8eccb;background:radial-gradient(circle at 34% 28%,var(--ac),var(--a) 45%,var(--b));box-shadow:0 0 0 2px rgba(217,178,91,.9),0 0 0 5px rgba(217,178,91,.14),0 12px 22px -10px rgba(0,0,0,.85),inset 0 1px 1px rgba(255,255,255,.35)}",
      ".bmv-muhur::before{content:'';position:absolute;inset:4px;border-radius:50%;border:1px dashed rgba(248,236,203,.5)}",
      ".bmv-muhur svg{width:27px;height:27px;filter:drop-shadow(0 1px 1px rgba(0,0,0,.35))}",
      ".bmv-k-ad{min-width:0}",
      ".bmv-k-ad small{display:block;font-size:10.5px;font-weight:800;letter-spacing:1.6px;text-transform:uppercase;color:#d9c28d}",
      ".bmv-k-ad h2{margin:4px 0 0;font:700 25px/1.06 var(--disp);color:#f7eed6;letter-spacing:-.2px;overflow-wrap:anywhere}",
      ".bmv-bakan{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:14px;padding-top:12px;border-top:1px solid rgba(217,178,91,.17)}",
      ".bmv-bakan-kim{display:flex;align-items:center;gap:10px;min-width:0;background:none;border:0;padding:0;color:inherit;font:inherit;text-align:left;cursor:pointer}",
      ".bmv-bakan-kim .portre{width:36px!important;height:36px!important;flex:none;box-shadow:0 0 0 2px rgba(217,178,91,.55)}",
      ".bmv-bos-portre{flex:none;width:36px;height:36px;border-radius:50%;display:grid;place-items:center;background:rgba(255,255,255,.08);color:#aeb6d3}.bmv-bos-portre svg{width:18px;height:18px}",
      ".bmv-bakan-kim>span:last-child{min-width:0}",
      ".bmv-bakan-kim small{display:block;font-size:11.5px;color:#b6bdd8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".bmv-bakan-kim b{display:block;font-size:15px;line-height:1.3;overflow-wrap:anywhere}",
      ".bmv-parti{display:inline-block;margin-left:7px;white-space:nowrap;padding:1px 6px;border-radius:5px;font-size:11px;font-weight:800;font-style:normal;vertical-align:1px;background:var(--pr);color:#fff}",
      ".bmv-rol{flex:none;padding:5px 10px;border-radius:999px;font-size:11.5px;font-weight:800;background:rgba(217,178,91,.15);color:var(--g2);box-shadow:inset 0 0 0 1px rgba(217,178,91,.38);white-space:nowrap}",
      ".bmv-rol.acik{background:rgba(255,255,255,.07);color:#cfd5ea;box-shadow:inset 0 0 0 1px rgba(255,255,255,.14)}",
      ".bmv-kasa{margin-top:15px}",
      ".bmv-kasa small{display:block;font-size:12px;color:#b9c0db}",
      ".bmv-kasa>b{display:block;margin-top:3px;font:700 40px/1 var(--disp);font-variant-numeric:tabular-nums;letter-spacing:-.6px}",
      ".bmv-kasa>b span{margin-left:6px;font-size:16px;font-weight:600;color:#cfd5ea;letter-spacing:0}",
      ".bmv-gosterge{position:relative;height:8px;border-radius:8px;background:rgba(255,255,255,.1);margin-top:12px;overflow:hidden}",
      ".bmv-gosterge i{position:absolute;left:0;top:0;bottom:0;border-radius:8px;background:linear-gradient(90deg,#b98a2e,var(--g),#f6e3a8);box-shadow:0 0 12px rgba(242,213,143,.45)}",
      ".bmv-gosterge-alt{display:flex;justify-content:space-between;gap:8px;margin-top:6px;font-size:11.5px;color:#aeb6d3;font-variant-numeric:tabular-nums}",
      ".bmv-kpi{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));margin-top:14px;border-radius:15px;background:rgba(5,8,25,.34);box-shadow:inset 0 0 0 1px rgba(255,255,255,.07)}",
      ".bmv-kpi>div{padding:9px 10px 8px;min-width:0}.bmv-kpi>div+div{border-left:1px solid rgba(255,255,255,.07)}",
      ".bmv-kpi small{display:block;font-size:11px;color:#aeb6d3;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".bmv-kpi b{display:block;margin-top:2px;font:700 20px/1.1 var(--disp);font-variant-numeric:tabular-nums;white-space:nowrap}",
      ".bmv-kpi b span{font-size:12px;color:#aeb6d3;font-weight:600;margin-left:1px}",
      ".bmv-kpi em{display:block;font-style:normal;font-size:10.5px;color:#8f97b6;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".bmv-ajanda{display:flex;align-items:center;justify-content:space-between;gap:8px;width:100%;margin-top:12px;padding:11px 12px;border-radius:13px;border:1px solid rgba(217,178,91,.34);background:rgba(217,178,91,.07);color:var(--g2);font:inherit;font-size:13.5px;font-weight:800;cursor:pointer;text-align:left}",
      ".bmv-ajanda span{display:flex;align-items:center;gap:8px}.bmv-ajanda svg{width:17px;height:17px;flex:none}",
      ".bmv-ajanda:active,.bmv-eylem:active,.bmv-satir:active,.bmv-btn:active{transform:scale(.98)}",
      /* sekmeler (Dernekler ile aynı dil) */
      "#icerik .segment.bmv-sekme{position:sticky!important;top:-14px;z-index:6;margin:0 -16px 14px!important;padding:10px 16px!important;background:var(--bg)!important;box-shadow:0 10px 14px -14px rgba(0,0,0,.9)!important}",
      "#icerik .segment.bmv-sekme>button{flex:1 1 auto!important;min-width:0;padding:9px 9px!important;font-size:13.5px!important;position:relative}",
      "#icerik .segment.bmv-sekme>button .say{display:inline-grid;place-items:center;min-width:17px;height:17px;margin-left:5px;padding:0 4px;border-radius:9px;background:var(--al);color:#fff;font:800 10.5px/1 system-ui,sans-serif;font-style:normal;vertical-align:1px}",
      "#icerik .segment.bmv-sekme>button .nokta{display:inline-block;width:7px;height:7px;margin-left:5px;border-radius:50%;background:var(--al);vertical-align:2px;box-shadow:0 0 0 3px rgba(240,69,75,.22)}",
      "@media(max-width:380px){#icerik .segment.bmv-sekme{gap:4px!important}#icerik .segment.bmv-sekme>button{padding:8px 6px!important;font-size:12.5px!important}}",
      "@media(max-width:340px){#icerik .segment.bmv-sekme>button{padding:8px 4px!important;font-size:12px!important}#icerik .segment.bmv-sekme>button .say{display:none}}",
      /* başlıklar ve ortak */
      ".bmv-bas{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin:20px 2px 10px}",
      "#bmGovde>.bmv-bas:first-child{margin-top:2px}",
      ".bmv-bas h3{margin:0;font:700 20px/1.12 var(--disp);letter-spacing:-.2px}",
      ".bmv-bas>span{font-size:12px;color:var(--mut);white-space:nowrap;text-align:right}",
      ".bmv-bas .bmv-kirmizi{color:var(--al2);font-weight:800}",
      ".bmv-tumu{border:0;background:none;padding:0;color:var(--ink2);font:inherit;font-size:13px;font-weight:800;cursor:pointer}",
      ".bmv-not{margin:10px 4px 0;font-size:12.5px;line-height:1.5;color:var(--mut)}",
      ".bmv-bos{padding:22px 16px;text-align:center;color:var(--mut);font-size:14px;line-height:1.5}.bmv-bos b{display:block;color:var(--txt);font-size:15.5px;margin-bottom:3px}",
      ".bmv-liste{display:flex;flex-direction:column;background:var(--panel);border:1px solid var(--line);border-radius:18px;overflow:hidden}",
      ".bmv-satir{display:flex;align-items:center;gap:12px;width:100%;padding:12px 14px;background:none;border:0;color:inherit;text-align:left;font:inherit;cursor:pointer;min-width:0}",
      ".bmv-satir.statik{cursor:default}.bmv-satir.statik:active{transform:none}",
      ".bmv-liste>*+*{border-top:1px solid var(--line)}",
      ".bmv-satir-ik{flex:none;width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:var(--tb,var(--at));color:var(--tr,var(--ac));font-style:normal}",
      ".bmv-satir-ik svg{width:19px;height:19px}.bmv-satir-ik.y{background:rgba(52,201,138,.14);color:var(--good)}",
      ".bmv-satir-orta{flex:1;min-width:0}.bmv-satir-orta b{display:block;font-size:14.5px;line-height:1.3;overflow-wrap:anywhere}",
      ".bmv-satir-orta small{display:block;margin-top:2px;font-size:12.5px;line-height:1.4;color:var(--mut);overflow-wrap:anywhere;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden}",
      ".bmv-ok{flex:none;color:var(--faint)}.bmv-ok svg{width:17px;height:17px;display:block}",
      ".bmv-say{flex:none;display:inline-grid;place-items:center;min-width:24px;height:24px;padding:0 7px;border-radius:12px;background:var(--al);color:#fff;font-size:12.5px;font-weight:800;font-variant-numeric:tabular-nums}",
      ".bmv-rozet{flex:none;display:inline-flex;align-items:center;gap:4px;padding:3px 8px;border-radius:7px;font-size:11.5px;font-weight:800;background:var(--panel2);color:var(--txt2);white-space:nowrap}",
      ".bmv-rozet.yesil{background:rgba(52,201,138,.14);color:var(--good)}.bmv-rozet.kirmizi{background:var(--albg);color:var(--al2)}.bmv-rozet.uyari{background:rgba(242,179,61,.15);color:#F2C164}",
      ".bmv-btn{display:inline-flex;align-items:center;justify-content:center;gap:7px;width:100%;margin-top:12px;padding:12px 12px;border:0;border-radius:13px;background:var(--panel2);color:var(--txt);font:inherit;font-weight:800;font-size:14.5px;cursor:pointer;text-align:center}",
      ".bmv-btn svg{width:17px;height:17px;flex:none}",
      ".bmv-btn.birincil{background:linear-gradient(145deg,var(--a2),var(--a) 45%,var(--b));color:#fff;box-shadow:0 10px 22px -14px var(--a),inset 0 1px 0 rgba(255,255,255,.2)}",
      ".bmv-btn.cizgi{background:transparent;box-shadow:inset 0 0 0 1.5px var(--line2);color:var(--txt2)}",
      ".bmv-btn.kucuk{width:auto;margin-top:10px;padding:8px 12px;font-size:13px;border-radius:11px}",
      ".bmv-btn:disabled{opacity:.55;cursor:default}",
      ".bmv-btn.tam{margin-top:16px}",
      ".bmv-iki{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:0 0 4px}.bmv-iki.tek{grid-template-columns:1fr}.bmv-iki .bmv-btn{margin-top:0}",
      /* canlı etkinlik şeridi */
      ".bmv-canli{position:relative;display:block;width:100%;margin:0 0 4px;padding:13px 40px 13px 14px;border-radius:18px;border:1px solid rgba(240,69,75,.45);background:radial-gradient(120% 160% at 100% 0%,rgba(240,69,75,.22),transparent 60%),var(--panel);color:inherit;font:inherit;text-align:left;cursor:pointer}",
      ".bmv-canli>svg{position:absolute;right:14px;top:50%;width:18px;height:18px;transform:translateY(-50%);color:var(--txt2)}",
      ".bmv-canli-ust{display:flex;align-items:center;gap:10px;font-size:12px;color:var(--txt2)}",
      ".bmv-canli b{display:block;margin:5px 0 2px;font-size:15.5px;overflow-wrap:anywhere}.bmv-canli-alt{display:block;font-size:12.5px;color:var(--mut)}",
      ".bmv-nabiz{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:800;color:var(--al2);letter-spacing:.2px}",
      ".bmv-nabiz i{width:8px;height:8px;border-radius:50%;background:var(--al);animation:bmNabiz 1.6s infinite}",
      "@media (prefers-reduced-motion:reduce){.bmv-nabiz i{animation:none}}",
      /* masa: işlem ızgarası */
      ".bmv-izgara{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}",
      ".bmv-eylem{display:flex;flex-direction:column;align-items:center;gap:6px;min-width:0;padding:13px 6px 11px;border:0;border-radius:17px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);color:var(--txt);font:inherit;text-align:center;cursor:pointer}",
      ".bmv-eylem-ik{width:42px;height:42px;border-radius:14px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,var(--a2),var(--a) 50%,var(--b));box-shadow:0 8px 16px -10px var(--a),inset 0 1px 0 rgba(255,255,255,.25)}",
      ".bmv-eylem-ik svg{width:21px;height:21px}",
      ".bmv-eylem b{font-size:13px;line-height:1.2;font-weight:800}",
      ".bmv-eylem small{display:block;width:100%;font-size:11.5px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;text-align:center}",
      ".bmv-eylem small svg{width:12px;height:12px;vertical-align:-2px;margin-right:3px}",
      ".bmv-eylem.hazir small{color:var(--good);font-weight:700}.bmv-eylem.hazir small::before{content:'';display:inline-block;width:6px;height:6px;margin-right:4px;border-radius:50%;background:var(--good);vertical-align:1px}",
      ".bmv-eylem.uyari small{color:#F2C164;font-weight:700}.bmv-eylem.canli small{color:var(--al2);font-weight:700}",
      ".bmv-eylem.bekle .bmv-eylem-ik,.bmv-eylem.kapali .bmv-eylem-ik{filter:grayscale(.65) brightness(.75);box-shadow:none}.bmv-eylem.bekle b,.bmv-eylem.kapali b{color:var(--txt2)}",
      /* masa: haftalık görevler */
      ".bmv-gorevler{background:var(--panel);border:1px solid var(--line);border-radius:18px;overflow:hidden}",
      ".bmv-gorev{display:flex;align-items:center;gap:12px;padding:12px 14px;min-width:0}",
      ".bmv-gorev[role=button]{cursor:pointer}.bmv-gorev+.bmv-gorev{border-top:1px solid var(--line)}",
      ".bmv-gorev-halka{flex:none;position:relative;width:46px;height:46px;display:grid;place-items:center}",
      ".bmv-gorev-halka .bmv-halka{position:absolute;inset:0;width:100%;height:100%}",
      ".bmv-gorev-halka b{position:relative;font:700 12.5px/1 var(--disp);font-variant-numeric:tabular-nums}.bmv-gorev-halka b svg{width:18px;height:18px;display:block}",
      ".bmv-halka{transform:rotate(-90deg)}.bmv-halka circle{fill:none;stroke-width:3.2}.bmv-halka .z{stroke:var(--panel2)}.bmv-halka .d{stroke:var(--ac);stroke-linecap:round}",
      ".bmv-gorev.tamam .bmv-halka .d,.bmv-gorev.alindi .bmv-halka .d{stroke:var(--good)}.bmv-gorev.tamam .bmv-gorev-halka b,.bmv-gorev.alindi .bmv-gorev-halka b{color:var(--good)}",
      ".bmv-gorev-orta{flex:1;min-width:0}.bmv-gorev-orta b{display:block;font-size:14.5px}.bmv-gorev-orta small{display:block;margin-top:2px;font-size:12.5px;line-height:1.4;color:var(--mut)}",
      ".bmv-gorev.alindi .bmv-gorev-orta b{color:var(--txt2)}",
      ".bmv-odul{flex:none;padding:8px 12px;border:0;border-radius:11px;background:linear-gradient(145deg,#f6d77d,#d6a43a);color:#2b1d02;font:inherit;font-size:13px;font-weight:800;cursor:pointer;box-shadow:0 8px 16px -10px #d6a43a}",
      ".bmv-tamam{flex:none;display:inline-flex;align-items:center;gap:4px;font-size:12.5px;font-weight:800;color:var(--good)}.bmv-tamam svg{width:15px;height:15px}",
      ".bmv-gorev-alt{display:flex;align-items:center;gap:8px;padding:11px 14px;border-top:1px solid var(--line);font-size:12.5px;line-height:1.45;color:var(--mut);background:rgba(217,178,91,.05)}",
      ".bmv-gorev-alt svg{flex:none;width:16px;height:16px;color:var(--g)}",
      /* masa: politikalar özeti */
      ".bmv-pol-ozet{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:1px;width:100%;padding:0;border:1px solid var(--line);border-radius:18px;overflow:hidden;background:var(--line);color:inherit;font:inherit;text-align:left;cursor:pointer}",
      ".bmv-pol-ozet>span{display:block;padding:11px 13px;background:var(--panel);min-width:0}",
      ".bmv-pol-ozet small{display:block;font-size:12px;color:var(--mut)}.bmv-pol-ozet b{display:block;margin-top:2px;font:700 19px/1.15 var(--disp);font-variant-numeric:tabular-nums;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".bmv-pol-ozet em{display:block;font-style:normal;font-size:11px;color:var(--mut);margin-top:1px}.bmv-pol-ozet em.hazir{color:var(--good);font-weight:700}",
      /* karne */
      ".bmv-karne{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:14px}",
      ".bmv-karne-ust{display:flex;align-items:center;gap:14px}",
      ".bmv-karne-halka{flex:none;position:relative;width:84px;height:84px;display:grid;place-items:center}",
      ".bmv-karne-halka .bmv-halka{position:absolute;inset:0;width:100%;height:100%}.bmv-karne-halka .bmv-halka circle{stroke-width:3}",
      ".bmv-karne-halka b{position:relative;font:700 28px/1 var(--disp);font-variant-numeric:tabular-nums;text-align:center}.bmv-karne-halka b small{display:block;font:600 11px/1.2 system-ui,sans-serif;color:var(--mut);margin-top:2px}",
      ".bmv-karne-ust>div{min-width:0}.bmv-karne-not{display:block;font:700 19px/1.15 var(--disp)}",
      ".bmv-karne-ust p{margin:4px 0 0;font-size:13px;line-height:1.45;color:var(--txt2)}",
      ".bmv-karne-liste{display:grid;grid-template-columns:1fr 1fr;gap:12px 14px;margin-top:14px;padding-top:13px;border-top:1px solid var(--line)}",
      ".bmv-kp{min-width:0}.bmv-kp-ust{display:flex;justify-content:space-between;align-items:baseline;gap:6px;font-size:12.5px;color:var(--txt2)}",
      ".bmv-kp-ust span{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}",
      ".bmv-kp-ust b{flex:none;font-size:13px;color:var(--txt);font-variant-numeric:tabular-nums}.bmv-kp-ust b small{font-size:11px;color:var(--mut);font-weight:600}",
      ".bmv-kp-bar{height:5px;border-radius:5px;background:var(--panel2);overflow:hidden;margin:6px 0 4px}.bmv-kp-bar i{display:block;height:100%;border-radius:5px;background:linear-gradient(90deg,var(--a),var(--ac))}",
      ".bmv-kp.dolu .bmv-kp-bar i{background:linear-gradient(90deg,#1f9c69,#5fe0a8)}",
      ".bmv-kp>small{display:block;font-size:11.5px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      /* icraat / etkinlik kartları */
      ".bmv-ozet-serit{display:flex;flex-wrap:wrap;justify-content:space-between;gap:4px 10px;margin:0 0 4px;padding:11px 14px;border-radius:14px;background:var(--at);box-shadow:inset 0 0 0 1px var(--line);font-size:13px;color:var(--txt2)}",
      ".bmv-ozet-serit b{color:var(--txt);font-variant-numeric:tabular-nums}.bmv-ozet-serit span{white-space:nowrap}",
      ".bmv-icr{position:relative;margin:0 0 10px;padding:14px;border-radius:18px;background:var(--panel);border:1px solid var(--line);overflow:hidden}",
      ".bmv-icr::before{content:'';position:absolute;left:0;top:14px;bottom:14px;width:3px;border-radius:0 3px 3px 0;background:linear-gradient(180deg,var(--ac),var(--a))}",
      ".bmv-icr-ust{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:12px;color:var(--mut)}",
      ".bmv-kapsam,.bmv-sure{display:inline-flex;align-items:center;gap:5px;font-weight:700}.bmv-kapsam svg,.bmv-sure svg{width:13px;height:13px}",
      ".bmv-icr-bas{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-top:7px}",
      ".bmv-icr-bas h4{margin:0;font-size:16.5px;line-height:1.25;font-weight:800;overflow-wrap:anywhere}",
      ".bmv-fiyat{flex:none;font:700 17px/1.2 var(--disp);color:var(--txt);white-space:nowrap;font-variant-numeric:tabular-nums}",
      ".bmv-icr p{margin:5px 0 0;font-size:13.5px;line-height:1.5;color:var(--txt2);overflow-wrap:anywhere}",
      ".bmv-etkiler{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}",
      ".bmv-etki,.bmv-etkiler .cip{display:inline-flex;align-items:center;padding:4px 8px;border-radius:8px;font-size:12px;font-weight:700;background:var(--panel2);color:var(--txt2);margin:0!important}",
      ".bmv-etki.iyi{background:rgba(52,201,138,.13);color:var(--good)}.bmv-etki.kotu{background:var(--albg);color:var(--al2)}.bmv-etki.kidem{background:rgba(217,178,91,.13);color:var(--g2)}",
      ".bmv-meta{display:flex;flex-wrap:wrap;gap:4px 12px;margin-top:9px;font-size:12px;color:var(--mut)}",
      ".bmv-meta span+span::before{content:'·';margin-right:12px;margin-left:-6px;color:var(--faint)}",
      /* canlı etkinlik kartı */
      ".bmv-canli-kart{position:relative;margin:0 0 6px;padding:16px;border-radius:22px;background:radial-gradient(120% 140% at 100% 0%,rgba(240,69,75,.22),transparent 58%),linear-gradient(160deg,#25213f,#171a37);border:1px solid rgba(240,69,75,.45);box-shadow:0 18px 36px -26px rgba(240,69,75,.7)}",
      ".bmv-canli-kart .bmv-canli-ust{justify-content:space-between}.bmv-canli-kart .bmv-canli-ust>span:last-child{display:inline-flex;align-items:center;gap:5px}.bmv-canli-kart .bmv-canli-ust svg{width:13px;height:13px}",
      ".bmv-canli-kart h3{margin:9px 0 4px;font:700 24px/1.1 var(--disp);color:#fff;overflow-wrap:anywhere}",
      ".bmv-yer{display:flex;align-items:center;gap:5px;font-size:13px;color:var(--txt2)}.bmv-yer svg{width:14px;height:14px}",
      ".bmv-canli-kart blockquote{margin:10px 0 0;padding-left:12px;border-left:3px solid rgba(240,69,75,.6);font-family:Georgia,'Times New Roman',serif;font-size:14.5px;line-height:1.5;color:var(--txt);overflow-wrap:anywhere}",
      ".bmv-canli-sayac{display:flex;margin-top:13px;border-radius:13px;background:rgba(0,0,0,.2);box-shadow:inset 0 0 0 1px rgba(255,255,255,.07)}",
      ".bmv-canli-sayac div{flex:1;padding:8px 10px;min-width:0}.bmv-canli-sayac div+div{border-left:1px solid rgba(255,255,255,.08)}",
      ".bmv-canli-sayac small{display:block;font-size:11px;color:var(--mut)}.bmv-canli-sayac b{display:block;font:700 19px/1.15 var(--disp);color:#fff;font-variant-numeric:tabular-nums}",
      ".bmv-carpan{height:7px;border-radius:7px;background:rgba(255,255,255,.08);margin-top:12px;overflow:hidden}.bmv-carpan i{display:block;height:100%;border-radius:7px;background:linear-gradient(90deg,#f0454b,#ffb36b)}",
      ".bmv-carpan-alt{display:flex;justify-content:space-between;gap:8px;margin-top:5px;font-size:11.5px;color:var(--mut);font-variant-numeric:tabular-nums}",
      ".bmv-carpan-alt span:nth-child(2){color:var(--txt2);font-weight:700;text-align:center}",
      /* bütçe */
      ".bmv-tablo{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:0 0 12px}",
      ".bmv-tablo>div{padding:12px 13px;border-radius:15px;background:var(--panel);border:1px solid var(--line);min-width:0}",
      ".bmv-tablo small{display:block;font-size:12px;color:var(--mut)}",
      ".bmv-tablo b{display:block;margin-top:3px;font:700 22px/1.1 var(--disp);font-variant-numeric:tabular-nums;white-space:nowrap}",
      ".bmv-tablo b.art{color:var(--good)}",
      ".bmv-tablo em{display:block;font-style:normal;font-size:11px;color:var(--mut);margin-top:1px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".bmv-talep{padding:13px 14px}",
      ".bmv-talep-ust{display:flex;align-items:center;justify-content:space-between;gap:8px}.bmv-talep-ust b{font:700 19px/1.1 var(--disp);font-variant-numeric:tabular-nums}",
      ".bmv-talep p{margin:6px 0 2px;font-size:13.5px;line-height:1.45;color:var(--txt2);overflow-wrap:anywhere}.bmv-talep>small{display:block;font-size:12px;color:var(--mut)}",
      ".bmv-karar-not{margin-top:7px;padding:8px 10px;border-radius:10px;background:var(--panel2);font-size:12.5px;color:var(--txt2)}",
      ".bmv-dag{padding:11px 14px}",
      ".bmv-dag-ust{display:flex;justify-content:space-between;gap:10px;font-size:13.5px}.bmv-dag-ust>span:last-child{display:flex;gap:8px;font-variant-numeric:tabular-nums}",
      ".bmv-dag-bar{display:flex;gap:2px;height:6px;margin-top:7px;border-radius:6px;background:var(--panel2);overflow:hidden}",
      ".bmv-dag-bar i{display:block;height:100%}.bmv-dag-bar i.art{background:linear-gradient(90deg,#1f9c69,#5fe0a8)}.bmv-dag-bar i.eks{background:linear-gradient(90deg,#f0454b,#ff9a8a)}",
      ".art{color:var(--good)}.eks{color:var(--al2)}",
      ".bmv-defter{display:flex;align-items:center;gap:12px;padding:11px 14px;min-width:0}",
      ".bmv-defter-ik{flex:none;width:32px;height:32px;border-radius:10px;display:grid;place-items:center;background:var(--panel2);color:var(--mut);font-style:normal}",
      ".bmv-defter-ik svg{width:16px;height:16px}.bmv-defter-ik.art{background:rgba(52,201,138,.13);color:var(--good)}.bmv-defter-ik.eks{background:var(--albg);color:var(--al2)}",
      ".bmv-defter .bmv-satir-orta b{font-size:13.5px;font-weight:700}",
      ".bmv-tutar{flex:none;font-size:14.5px;font-variant-numeric:tabular-nums;white-space:nowrap}",
      ".bmv-defter-daha{display:block;width:100%;padding:12px;border:0;border-top:1px solid var(--line);background:none;color:var(--ink2);font:inherit;font-size:13.5px;font-weight:800;cursor:pointer}",
      ".bmv-liste.kisalt>.bmv-defter:nth-child(n+9){display:none}",
      ".bmv details.bkm-acil{margin:16px 0 0;border:1px solid var(--line);border-radius:16px}",
      /* iletişim */
      ".bmv-buyuk{display:flex;flex-direction:column;align-items:flex-start;gap:8px;min-width:0;padding:14px;border:0;border-radius:18px;background:linear-gradient(150deg,var(--at),transparent 70%),var(--panel);box-shadow:inset 0 0 0 1px var(--line2);color:inherit;font:inherit;text-align:left;cursor:pointer}",
      ".bmv-buyuk .bmv-eylem-ik{width:40px;height:40px}.bmv-buyuk b{font-size:15px}.bmv-buyuk small{font-size:12px;color:var(--mut);line-height:1.35}",
      ".bmv-buyuk.hazir small{color:var(--good);font-weight:700}.bmv-buyuk.bekle .bmv-eylem-ik{filter:grayscale(.65) brightness(.75);box-shadow:none}",
      ".bmv-basin{position:relative;margin:0 0 10px;padding:15px 15px 14px;border-radius:18px;background:var(--panel);border:1px solid var(--line);cursor:default}",
      ".bmv-basin.kisa{cursor:pointer}",
      ".bmv-basin-ust{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:11.5px;font-weight:800;color:var(--ac);letter-spacing:.2px}",
      ".bmv-basin-ust span{display:inline-flex;align-items:center;gap:5px}.bmv-basin-ust svg{width:14px;height:14px}.bmv-basin-ust time{font-weight:600;color:var(--mut)}",
      ".bmv-basin h4{margin:8px 0 6px;font-family:Georgia,'Times New Roman',serif;font-size:18.5px;line-height:1.3;font-weight:700;overflow-wrap:anywhere}",
      ".bmv-basin-metin{font-size:14px;line-height:1.6;color:var(--txt2);white-space:pre-line;overflow-wrap:anywhere;-webkit-user-select:text;user-select:text}",
      ".bmv-basin.kisa .bmv-basin-metin{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:4;overflow:hidden}",
      ".bmv-devam{display:none;margin-top:5px;font-size:12.5px;font-weight:800;color:var(--ink2)}.bmv-basin.kisa .bmv-devam{display:inline-block}",
      ".bmv-imza{margin-top:9px;font-size:12.5px;color:var(--mut);font-style:italic}",
      ".bmv-zc{position:relative;display:flex;gap:12px;padding:12px 14px 12px 14px}",
      ".bmv-zc>i{flex:none;position:relative;width:12px;margin-top:4px}.bmv-zc>i::before{content:'';position:absolute;left:1px;top:0;width:10px;height:10px;border-radius:50%;background:var(--ac);box-shadow:0 0 0 3px var(--at)}",
      ".bmv-zc>div{min-width:0}.bmv-zc b{display:block;font-size:14.5px}.bmv-zc small{display:block;font-size:12px;color:var(--mut);margin-top:1px}",
      ".bmv-zc p{margin:5px 0 0;font-size:13.5px;line-height:1.45;color:var(--txt2);font-style:italic;overflow-wrap:anywhere}",
      /* politika kartları (index.html politikaKartlari çıktısı) */
      ".bmv-pol .kart{margin:0 0 10px!important;padding:14px!important;border-radius:18px!important;background:var(--panel)!important;border:1px solid var(--line)!important;box-shadow:none!important}",
      ".bmv-pol .kart>div:first-child b{font-size:15.5px}.bmv-pol .kart .v{font:700 18px/1.1 var(--disp);color:var(--txt)}",
      ".bmv-pol .kart .btn{margin:10px 0 0!important}",
      ".bmv-istifa{display:flex;align-items:center;justify-content:center;gap:7px;width:100%;margin:22px 0 4px;padding:12px;border:0;background:none;color:var(--al2);font:inherit;font-size:14px;font-weight:700;cursor:pointer}",
      ".bmv-istifa svg{width:16px;height:16px}",
      "@media(max-width:360px){.bmv-bas{flex-wrap:wrap}.bmv-kpi small{font-size:10.5px}}",
      "@media(max-width:350px){.bmv-k-ad h2{font-size:22px}.bmv-muhur{width:50px;height:50px}.bmv-muhur svg{width:23px;height:23px}.bmv-kasa>b{font-size:34px}.bmv-kpi>div{padding:8px 7px}.bmv-kpi b{font-size:17px}.bmv-izgara{gap:6px}.bmv-eylem{padding:11px 3px 10px}.bmv-eylem b{font-size:12px}.bmv-eylem-ik{width:38px;height:38px}.bmv-karne-liste{grid-template-columns:1fr}.bmv-tablo b{font-size:19px}.bmv-iki:not(.tek){grid-template-columns:1fr}}",
      "@media(min-width:700px){.bmv-izgara{grid-template-columns:repeat(6,minmax(0,1fr))}.bmv-karne-liste{grid-template-columns:repeat(3,1fr)}}"
    ].join("\n");
    var st = document.createElement("style"); st.id = "bmv-stil"; st.textContent = css;
    document.head.appendChild(st);
  })();

  /* ---------------- künye ve sekmeler ---------------- */
  function kunyeHtml(v) {
    var k = Number(v.kasa) || 0, tv = Number(v.tavan) || 0, oran = tv ? Math.min(100, Math.max(0, k / tv * 100)) : 0;
    var bk = v.bakan, p = Math.round(Number(v.karne && v.karne.puan) || 0);
    var kim = bk
      ? '<button type="button" class="bmv-bakan-kim" data-kad="' + esc(bk.kad) + '" onclick="bmOyuncu(this)">' + (typeof portre === "function" ? portre(bk.kad, bk.parti && bk.parti.renk) : "") +
        '<span><small>' + esc(unvan(v.ad).length > 24 ? "Bakan" : unvan(v.ad)) + '</small><b>' + esc(bk.kad) + (bk.parti ? '<em class="bmv-parti" style="--pr:' + esc(bk.parti.renk || "#5b6690") + '">' + esc(bk.parti.kisa) + '</em>' : "") + '</b></span></button>'
      : '<div class="bmv-bakan-kim"><span class="bmv-bos-portre">' + IK2.kisi + '</span><span><small>Bakan atanmadı</small><b>' + (v.yurutme ? esc(v.yurutme) + ' vekâleten yönetiyor' : 'Makam boş') + '</b></span></div>';
    var rol = v.yetki === "bakan" ? '<span class="bmv-rol">Bakanlığın</span>' : v.yetki ? '<span class="bmv-rol">Vekâleten</span>' : '<span class="bmv-rol acik">Kamuya açık</span>';
    return '<header class="bmv-kunye" data-dk="kunye"><span class="bmv-filigran" aria-hidden="true">' + bakIkon(v.kod) + '</span>' +
      '<div class="bmv-k-ust"><span class="bmv-muhur">' + bakIkon(v.kod) + '</span><div class="bmv-k-ad"><small>T.C. · Bakanlık</small><h2>' + esc(v.ad) + '</h2></div></div>' +
      '<div class="bmv-bakan">' + kim + rol + '</div>' +
      '<div class="bmv-kasa"><small>Bakanlık kasası</small><b>' + sayi(k, 1) + '<span>milyar ₺</span></b>' +
      '<div class="bmv-gosterge" role="meter" aria-label="Kasa doluluğu" aria-valuemin="0" aria-valuemax="' + tv + '" aria-valuenow="' + k + '"><i style="width:' + oran.toFixed(1) + '%"></i></div>' +
      '<div class="bmv-gosterge-alt"><span>%' + sayi(oran, 0) + ' dolu</span><span>Tavan ' + sayi(tv, 0) + ' milyar ₺</span></div></div>' +
      '<div class="bmv-kpi"><div><small>Günlük ödenek</small><b>+' + sayi(v.gunluk, 2) + '</b><em>milyar ₺ / gün</em></div>' +
      '<div><small>Bütçe payı</small><b>%' + sayi(v.pay, 1) + '</b><em>cari giderden</em></div>' +
      '<div><small>Karne</small><b>' + p + '<span>/100</span></b><em>son 28 gün</em></div></div>' +
      (v.yetki === "bakan" ? '<button type="button" class="bmv-ajanda" data-dk-ajanda="1"><span>' + IK2.toren + 'Makam ajandası ve protokol</span>' + IK2.ok + '</button>' : "") +
      '</header>';
  }
  function sekmeListesi(v) {
    var y = v.yetki, s = v.sorumluluk || {};
    var odul = v.gorevler && v.gorevler.liste ? v.gorevler.liste.filter(function (x) { return x.tamam && !x.alindi; }).length : 0;
    var canli = (v.etkinlikler || []).some(function (e2) { return e2.aktif; });
    var bekleyen = y ? (Number(s.cimer_bekleyen) || 0) + (Number(s.soru_bekleyen) || 0) : 0;
    var ls = [["ozet", y ? "Masa" : "Özet", odul ? '<i class="say">' + odul + '</i>' : ""]];
    if (y) ls.push(["icraat", "İcraat", ""]);
    ls.push(["etkinlik", "Etkinlik", canli ? '<i class="nokta" aria-label="süren etkinlik var"></i>' : ""]);
    ls.push(["butce", "Bütçe", ""]);
    ls.push(["iletisim", y ? "İletişim" : "Açıklamalar", bekleyen ? '<i class="say">' + bekleyen + '</i>' : ""]);
    return ls;
  }
  function sekmeler(v) {
    var ls = sekmeListesi(v);
    if (BM.sekme === "politika") { BM.sekme = "icraat"; BM.polGit = true; }
    if (!ls.some(function (x) { return x[0] === BM.sekme; })) BM.sekme = "ozet";
    return '<i class="bmv-iz" aria-hidden="true"></i><div class="segment bmv-sekme" role="tablist">' + ls.map(function (x) {
      var a = BM.sekme === x[0];
      return '<button type="button" role="tab" data-s="' + x[0] + '" aria-selected="' + a + '" class="' + (a ? "aktif" : "") + '" onclick="bmSekme(\'' + x[0] + '\')">' + x[1] + x[2] + '</button>';
    }).join("") + '</div>';
  }
  function govdeHtml(v) {
    var s = BM.sekme;
    return s === "icraat" ? icraatSekme(v) : s === "etkinlik" ? etkinlikSekme(v) : s === "butce" ? butceSekme(v) : s === "iletisim" ? iletisimSekme(v) : ozetSekme(v);
  }
  function ciz() {
    var v = BM.v; if (!v) return;
    var h = '<div class="bkm bmv" id="bmMasa" style="' + renkStil(v.kod) + '">' + kunyeHtml(v) + sekmeler(v) + '<div id="bmGovde">' + govdeHtml(v) + '</div></div>';
    iskelet(kisaAd(v.ad), h, { geri: true });
    sonrasi(v);
  }
  function sonrasi(v) {
    if (BM.sekme === "icraat" && (v.politikalar || []).length && typeof politikaBagla === "function") { try { politikaBagla(); } catch (_) {} }
    var ic = document.getElementById("icerik");
    if (ic && typeof portreleriTazele === "function" && ic.querySelector("#bmMasa [data-portre]")) { try { var pr = portreleriTazele(ic); if (pr && pr.catch) pr.catch(function () {}); } catch (_) {} }
    if (BM.polGit) {
      BM.polGit = false;
      var hedef = document.getElementById("bmvPolitika");
      if (hedef && ic) ic.scrollTop = Math.max(0, hedef.getBoundingClientRect().top - ic.getBoundingClientRect().top + ic.scrollTop - 70);
    }
  }
  function sekmeyeKaydir() {               // sekme değişince yeni içerik sekme çubuğunun hemen altından başlasın
    var ic = document.getElementById("icerik"), iz = document.querySelector("#bmMasa .bmv-iz");
    if (!ic || !iz) return;
    var hedef = iz.getBoundingClientRect().top - ic.getBoundingClientRect().top + ic.scrollTop;
    if (ic.scrollTop > hedef) ic.scrollTop = Math.max(0, hedef);
  }
  window.bmSekme = function (s) {
    if (s === "politika") { s = "icraat"; BM.polGit = true; }
    BM.sekme = s;
    var g = document.getElementById("bmGovde"), v = BM.v;
    if (!g || !v || !document.querySelector('#bmMasa .bmv-sekme button[data-s="' + s + '"]')) return ciz();
    document.querySelectorAll("#bmMasa .bmv-sekme button").forEach(function (b) { var a = b.getAttribute("data-s") === BM.sekme; b.classList.toggle("aktif", a); b.setAttribute("aria-selected", a); });
    g.innerHTML = govdeHtml(v);
    if (!BM.polGit) sekmeyeKaydir();
    sonrasi(v);
  };
  window.bmOyuncu = function (el) { var k = el && el.getAttribute("data-kad"); if (k && typeof oyuncuKart === "function") oyuncuKart(k); };
  window.bmBilgi = function (el) { var m = el && el.getAttribute("data-m"); if (m) bildir(m); };
  window.bmCimerYeni = function () { try { if (typeof CIMER === "object" && CIMER) CIMER.sekme = "yeni"; } catch (_) {} if (typeof cimerEkrani === "function") ekranAc(cimerEkrani); };
  window.bmDefterAc = function (b) { var l = b && b.previousElementSibling; if (l) l.classList.remove("kisalt"); if (b) b.remove(); };

  /* ---------------- Masa (bakan) / Özet (herkes) ---------------- */
  function ozetSekme(v) {
    var y = v.yetki, h = "";
    var aktif = (v.etkinlikler || []).filter(function (e2) { return e2.aktif; })[0];
    if (aktif) h += canliSerit(aktif);
    if (y) {
      h += eylemIzgara(v);
      if (v.gorevler) h += gorevKart(v);
      h += sorumlulukKart(v);
      if ((v.politikalar || []).length) h += politikaOzet(v);
      h += karneKart(v);
      if (y === "bakan" && typeof bakanIstifa === "function") h += '<button type="button" class="bmv-istifa" onclick="bakanIstifa()">' + IK2.cikis + 'Bakanlıktan istifa et</button>';
    } else {
      h += karneKart(v) + yururlukKart(v) + sonAciklamalar(v) + cimerBasvur();
    }
    return h;
  }
  function canliSerit(e2) {
    var c = Math.min(2, 0.5 + 0.15 * (Number(e2.katilimci) || 0));
    return '<button type="button" class="bmv-canli" onclick="bmSekme(\'etkinlik\')"><span class="bmv-canli-ust"><span class="bmv-nabiz"><i></i>Sürüyor</span><span>' + esc(kalan(e2.bit)) + ' kaldı</span></span>' +
      '<b>' + esc(e2.ad) + (e2.il ? ' · ' + esc(e2.il) : '') + '</b><span class="bmv-canli-alt">' + sayi(e2.katilimci) + ' katılımcı · etki ×' + sayi(c, 2) + '</span>' + IK2.ok + '</button>';
  }
  function eylemIzgara(v) {
    var icrHazir = (v.icraatlar || []).filter(function (i) { return hazirMi(i.hazir); }).length;
    var suren = (v.etkinlikler || []).some(function (e2) { return e2.aktif; });
    var etkHazir = !suren && (v.etkinlik_turleri || []).some(function (t) { return hazirMi(t.hazir) && Number(v.kasa) >= Number(t.maliyet); });
    var z = v.ziyaret || {}, a = v.aciklama || {}, ta = v.talep_ayar || {};
    var talep = (v.talepler || []).filter(function (t) { return t.durum === "bekliyor"; })[0];
    var bakan = v.yetki === "bakan", kasaVar = Number(v.kasa) >= 0.1;
    var ls = [
      { ik: IK.icraat, ad: "İcraat başlat", js: "bmSekme('icraat')", d: icrHazir ? icrHazir + " hazır" : "Hazır icraat yok", c: icrHazir ? "hazir" : "" },
      { ik: IK.etkinlik, ad: "Etkinlik düzenle", js: "bmSekme('etkinlik')", d: suren ? "Sürüyor" : etkHazir ? "Hazır" : "Şimdilik yok", c: suren ? "canli" : etkHazir ? "hazir" : "" },
      hazirMi(z.hazir) ? { ik: IK.ziyaret, ad: "Saha ziyareti", js: "bmZiyaretModal()", d: mrK(z.maliyet), c: "hazir" }
        : { ik: IK.ziyaret, ad: "Saha ziyareti", d: kalan(z.hazir) + " sonra", c: "bekle", m: "Bir sonraki saha ziyareti " + ileri(z.hazir) + " yapılabilir." },
      hazirMi(a.hazir) ? { ik: IK.aciklama, ad: "Açıklama yap", js: "bmAciklamaModal()", d: "Hazır", c: "hazir" }
        : { ik: IK.aciklama, ad: "Açıklama yap", d: kalan(a.hazir) + " sonra", c: "bekle", m: "Bir sonraki bakanlık açıklaması " + ileri(a.hazir) + " yapılabilir." },
      !bakan ? { ik: IK.odenek, ad: "Ek ödenek iste", d: "Yalnız bakan", c: "kapali", m: "Ek ödeneği yalnız bakan isteyebilir." }
        : talep ? { ik: IK.odenek, ad: "Ek ödenek iste", d: "Karar bekliyor", c: "uyari", m: mrK(talep.tutar) + " talebin karar bekliyor; " + kalan(talep.bitis) + " içinde sonuçlanır." }
        : !hazirMi(ta.hazir) ? { ik: IK.odenek, ad: "Ek ödenek iste", d: kalan(ta.hazir) + " sonra", c: "bekle", m: "Yeni ek ödenek talebi " + ileri(ta.hazir) + " verilebilir." }
        : { ik: IK.odenek, ad: "Ek ödenek iste", js: "bmTalepModal()", d: "En çok " + sayi(ta.ust || 25, 0) + " milyar", c: "" },
      kasaVar ? { ik: IK.iade, ad: "Hazine'ye iade", js: "bmIadeModal()", d: "Geri gönder", c: "" }
        : { ik: IK.iade, ad: "Hazine'ye iade", d: "Kasa boş", c: "kapali", m: "Kasada iade edilecek ödenek yok." }
    ];
    return '<div class="bmv-bas"><h3>Şimdi yapabileceklerin</h3></div><div class="bmv-izgara">' + ls.map(function (t) {
      var tik = t.js ? 'onclick="' + t.js + '"' : 'onclick="bmBilgi(this)" data-m="' + esc(t.m || "") + '"';
      return '<button type="button" class="bmv-eylem ' + t.c + '" ' + tik + '><span class="bmv-eylem-ik">' + t.ik + '</span><b>' + t.ad + '</b><small>' + (t.c === "bekle" ? IK2.saat : "") + esc(t.d) + '</small></button>';
    }).join("") + '</div>';
  }
  var GOREV_GIT = { icraat2: "bmSekme('icraat')", il_icraat2: "bmSekme('icraat')", butce: "bmSekme('icraat')", etkinlik1: "bmSekme('etkinlik')", katilim5: "bmSekme('etkinlik')", ziyaret2: "bmZiyaretModal()", aciklama1: "bmAciklamaModal()" };
  function gorevKart(v) {
    var g = v.gorevler, ls = g.liste || [], alinan = ls.filter(function (x) { return x.alindi; }).length;
    var h = ls.map(function (x) {
      var hd = Number(x.hedef) || 1, il = Number(x.ilerleme) || 0, p = Math.min(100, il / hd * 100), para = x.kod === "butce";
      var orta = x.alindi || x.tamam ? IK2.tik : para ? "%" + Math.round(p) : sayi(il) + "/" + sayi(hd);
      var sag = x.alindi ? '<span class="bmv-tamam">' + IK2.tik + 'Alındı</span>'
        : x.tamam ? '<button type="button" class="bmv-odul" onclick="event.stopPropagation();bmGorevOdul(\'' + esc(x.kod) + '\')">Ödülü al</button>'
        : (GOREV_GIT[x.kod] ? '<span class="bmv-ok">' + IK2.ok + '</span>' : '');
      var git = !x.tamam && GOREV_GIT[x.kod] ? ' role="button" tabindex="0" onclick="' + GOREV_GIT[x.kod] + '"' : '';
      var alt = para && !x.tamam ? sayi(il, 1) + ' / ' + sayi(hd, 1) + ' milyar ₺ harcandı · ' + esc(x.aciklama) : esc(x.aciklama);
      return '<div class="bmv-gorev' + (x.alindi ? ' alindi' : x.tamam ? ' tamam' : '') + '"' + git + '><span class="bmv-gorev-halka">' + halka(x.tamam ? 100 : p) + '<b>' + orta + '</b></span>' +
        '<span class="bmv-gorev-orta"><b>' + esc(x.ad) + '</b><small>' + alt + '</small></span>' + sag + '</div>';
    }).join("");
    return '<div class="bmv-bas"><h3>Bu haftanın görevleri</h3><span>' + alinan + '/' + ls.length + ' · ' + esc(kalan(g.bitis)) + ' sonra yenilenir</span></div>' +
      '<section class="bmv-gorevler">' + h + '<div class="bmv-gorev-alt">' + IK2.yildiz + '<span>Her görev +' + sayi(g.odul, 1) + ' kıdem; üçü birden +' + sayi(g.bonus, 1) + ' kıdem ve Resmî Gazete\'de anılma.</span></div></section>';
  }
  function satir2(o) {
    return '<button type="button" class="bmv-satir" style="--tr:' + o.renk + ';--tb:' + saydam(o.renk, .15) + '" onclick="' + o.js + '"><i class="bmv-satir-ik">' + o.ik + '</i>' +
      '<span class="bmv-satir-orta"><b>' + o.bas + '</b><small>' + o.alt + '</small></span>' +
      (o.say ? '<span class="bmv-say">' + o.say + '</span>' : o.rozet ? '<span class="bmv-rozet ' + (o.rozetSinif || "uyari") + '">' + o.rozet + '</span>' : '') + '<span class="bmv-ok">' + IK2.ok + '</span></button>';
  }
  function sorumlulukKart(v) {
    var s = v.sorumluluk || {}, c = Number(s.cimer_bekleyen) || 0, q = Number(s.soru_bekleyen) || 0;
    var talep = (v.talepler || []).filter(function (t) { return t.durum === "bekliyor"; })[0];
    var ls = [
      satir2({ ik: IK2.cimer, renk: "#6fb3ff", bas: "CİMER başvuruları", alt: c ? c + " başvuru yanıt bekliyor · 72 saat içinde" : "Bekleyen başvuru yok", say: c, js: "bmCimer()" }),
      satir2({ ik: IK2.soru, renk: "#b9a6ff", bas: "Soru önergeleri", alt: q ? q + " yazılı soru yanıt bekliyor" : "Bekleyen soru yok", say: q, js: "bmSorular()" })
    ];
    if (talep) ls.push(satir2({ ik: IK.odenek, renk: "#f2b33d", bas: "Ek ödenek talebin", alt: mrK(talep.tutar) + " · " + esc(kalan(talep.bitis)) + " içinde karar verilecek", rozet: "Bekliyor", js: "bmSekme('butce')" }));
    if (typeof ihaleEkrani === "function") ls.push(satir2({ ik: IK.kasa, renk: "#5fd8a4", bas: "Kamu ihaleleri", alt: "Bakanlık projesi için ihale aç ve yönet", js: "bmIhale()" }));
    return '<div class="bmv-bas"><h3>Sorumlulukların</h3>' + (c + q ? '<span class="bmv-kirmizi">' + (c + q) + ' yanıt bekliyor</span>' : '<span>Hepsi güncel</span>') + '</div><div class="bmv-liste">' + ls.join("") + '</div>';
  }
  var PB = { tl_ay: " ₺/ay", tl_gun: " ₺/gün", tl: " ₺", binde: "‰", kat: "×", adet: " adet" };
  var polDeger = function (p) { return p.birim === "yuzde" ? "%" + sayi(p.deger, 1) : sayi(p.deger, 0) + (PB[p.birim] || ""); };
  function politikaOzet(v) {
    return '<div class="bmv-bas"><h3>Politikaların</h3><span>Değiştirmek için dokun</span></div><button type="button" class="bmv-pol-ozet" onclick="bmSekme(\'politika\')">' + v.politikalar.map(function (p) {
      return '<span><small>' + esc(p.ad) + '</small><b>' + esc(polDeger(p)) + '</b>' + (hazirMi(p.hazir) ? '<em class="hazir">Değiştirilebilir</em>' : '<em>' + esc(kalan(p.hazir)) + ' sonra</em>') + '</span>';
    }).join("") + '</button>';
  }
  function karneParcalar(k) {
    var m = function (x) { return Math.max(0, Math.min(1, x || 0)); };
    var top = (Number(k.cimer) || 0) + (Number(k.soru) || 0), yan = (Number(k.cimer_yanit) || 0) + (Number(k.soru_yanit) || 0);
    var oden = Number(k.odenek) || 0, harc = Number(k.harcama) || 0;
    return [
      { ad: "Haftalık görevler", d: sayi(k.gorev) + " / 12 görev ödülü", max: 30, o: m((Number(k.gorev) || 0) / 12), ip: "her hafta üç görevin ödülünü al" },
      { ad: "İcraat", d: sayi(k.icraat) + " / 6 icraat", max: 20, o: m((Number(k.icraat) || 0) / 6), ip: "28 günde altı icraat başlat" },
      { ad: "Etkinlik", d: sayi(k.etkinlik) + " / 3 etkinlik · " + sayi(k.katilim) + " katılım", max: 15, o: m((Number(k.etkinlik) || 0) / 3), ip: "28 günde üç etkinlik düzenle" },
      { ad: "Saha ziyareti", d: sayi(k.ziyaret) + " / 4 ziyaret", max: 10, o: m((Number(k.ziyaret) || 0) / 4), ip: "28 günde dört il ziyaret et" },
      { ad: "Başvuru yanıtı", d: top ? sayi(yan) + " / " + sayi(top) + " yanıtlandı" : "Yanıtlanacak başvuru yok", max: 15, o: top ? m(yan / top) : 1, ip: "CİMER başvurularını ve soru önergelerini yanıtla" },
      { ad: "Hizmet harcaması", d: sayi(harc, 1) + " / " + sayi(oden > 0 ? oden : 10, 1) + " milyar ₺", max: 10, o: oden > 0 ? m(harc / oden) : m(harc / 10), ip: "gelen ödeneği kamu hizmetine harca" }
    ];
  }
  function karneKart(v) {
    var k = v.karne || {}, p = Math.round(Number(k.puan) || 0), ls = karneParcalar(k);
    var en = ls.slice().sort(function (a, b) { return b.max * (1 - b.o) - a.max * (1 - a.o); })[0], kazanc = en ? en.max * (1 - en.o) : 0;
    var not = p >= 80 ? "Örnek bakan" : p >= 60 ? "İyi gidiyor" : p >= 40 ? "Ortalama" : p >= 20 ? "Zayıf" : "Çok zayıf";
    var aciklama = v.yetki && kazanc >= 1
      ? 'Puanını en çok <b>' + esc(en.ad.toLocaleLowerCase("tr-TR")) + '</b> yükseltir: ' + esc(en.ip) + ' (+' + sayi(kazanc, 0) + ' puana kadar).'
      : 'Seçmenler ve Meclis bakanı bu karneye bakarak değerlendirir.';
    return '<div class="bmv-bas"><h3>Bakan karnesi · son 28 gün</h3><span>Herkese açık</span></div><section class="bmv-karne">' +
      '<div class="bmv-karne-ust"><span class="bmv-karne-halka">' + halka(p) + '<b>' + p + '<small>/100</small></b></span><div><b class="bmv-karne-not">' + not + '</b><p>' + aciklama + '</p></div></div>' +
      '<div class="bmv-karne-liste">' + ls.map(function (x) {
        var puan = x.max * x.o;
        return '<div class="bmv-kp' + (x.o >= 1 ? ' dolu' : '') + '"><div class="bmv-kp-ust"><span>' + esc(x.ad) + '</span><b>' + sayi(puan, puan % 1 && puan < 10 ? 1 : 0) + '<small>/' + x.max + '</small></b></div>' +
          '<div class="bmv-kp-bar"><i style="width:' + (x.o * 100).toFixed(0) + '%"></i></div><small>' + esc(x.d) + '</small></div>';
      }).join("") + '</div></section>';
  }
  function yururlukKart(v) {
    var ls = (v.icraatlar || []).filter(aktifMi); if (!ls.length) return "";
    return '<div class="bmv-bas"><h3>Yürürlükteki icraatlar</h3><span>' + ls.length + '</span></div><div class="bmv-liste">' + ls.map(function (i) {
      return '<div class="bmv-satir statik"><i class="bmv-satir-ik y">' + IK.icraat + '</i><span class="bmv-satir-orta"><b>' + esc(i.ad) + '</b><small>' + esc(i.aciklama) + '</small></span><span class="bmv-rozet yesil">' + esc(kalan(i.aktif_bit)) + '</span></div>';
    }).join("") + '</div>';
  }
  function sonAciklamalar(v) {
    var l = ((v.aciklama || {}).son || []).slice(0, 2); if (!l.length) return "";
    return '<div class="bmv-bas"><h3>Son açıklamalar</h3><button type="button" class="bmv-tumu" onclick="bmSekme(\'iletisim\')">Tümü</button></div>' + l.map(aciklamaKart).join("");
  }
  function cimerBasvur() {
    if (typeof cimerEkrani !== "function") return "";
    return '<div class="bmv-liste" style="margin-top:16px">' + satir2({ ik: IK2.cimer, renk: "#6fb3ff", bas: "Bakanlığa başvur", alt: "CİMER'den şikâyet, öneri ya da bilgi talebi gönder", js: "bmCimerYeni()" }) + '</div>';
  }

  /* ---------------- İcraat (politikalar dahil) ---------------- */
  function icraatSekme(v) {
    var ls = v.icraatlar || [];
    var hazir = ls.filter(function (i) { return hazirMi(i.hazir); });
    var yur = ls.filter(function (i) { return !hazirMi(i.hazir) && aktifMi(i); });
    var bek = ls.filter(function (i) { return !hazirMi(i.hazir) && !aktifMi(i); });
    var h = '<div class="bmv-ozet-serit"><span>Kasada <b>' + mrK(v.kasa) + '</b></span><span><b>' + hazir.length + '</b> icraat uygulanabilir</span></div>';
    if ((v.politikalar || []).length) h += '<div class="bmv-bas" id="bmvPolitika"><h3>Politikalar</h3><span>Kalıcı ayar · Resmî Gazete</span></div><div class="bmv-pol">' + (typeof politikaKartlari === "function" ? politikaKartlari(v.politikalar) : "") + '</div>' +
      '<p class="bmv-not" style="margin-top:0">Bu ayarlar oyuncuların cüzdanına doğrudan yansır. Yeni değeri yazınca bütçeye etkisi hemen hesaplanır.</p>';
    if (!ls.length) return h + '<div class="bmv-liste" style="margin-top:12px"><div class="bmv-bos">Bu bakanlığın icraatı yok.</div></div>';
    if (hazir.length) h += '<div class="bmv-bas"><h3>Uygulanabilir</h3><span>' + hazir.length + ' icraat</span></div>' + hazir.map(function (i) { return icraatKart(i, v); }).join("");
    if (yur.length) h += '<div class="bmv-bas"><h3>Yürürlükte</h3><span>' + yur.length + '</span></div><div class="bmv-liste">' + yur.map(function (i) { return kisaIcraat(i, true); }).join("") + '</div>';
    if (bek.length) h += '<div class="bmv-bas"><h3>Bekleme süresinde</h3><span>' + bek.length + '</span></div><div class="bmv-liste">' + bek.map(function (i) { return kisaIcraat(i, false); }).join("") + '</div>';
    return h + '<p class="bmv-not">İcraat bedeli bakanlık kasasından düşer, etkisi hemen işler. Her icraat bekleme süresi dolunca yeniden uygulanabilir.</p>';
  }
  function icraatKart(i, v) {
    var para = Number(v.kasa) >= Number(i.maliyet), meta = [];
    if (i.sure_gun) meta.push(i.sure_gun + " gün sürer");
    meta.push(beklemeYaz(i.bekleme_saat));
    var oyuncu = typeof etkiCip === "function" ? etkiCip(i.oyuncu) : "", etk = etkiCipleri(i.etki);
    var dugme = para ? '<button type="button" class="bmv-btn birincil" onclick="icraatYap(\'' + esc(i.kod) + '\',' + (i.il_gerekli ? "true" : "false") + ')">Uygula · ' + mrK(i.maliyet) + '</button>'
      : v.yetki === "bakan" ? '<button type="button" class="bmv-btn" onclick="bmTalepModal()">' + IK.odenek + 'Kasa yetmiyor · ek ödenek iste</button>'
      : '<button type="button" class="bmv-btn" disabled>Kasada yeterli ödenek yok</button>';
    return '<article class="bmv-icr"><div class="bmv-icr-ust"><span class="bmv-kapsam">' + (i.il_gerekli ? IK2.konum + 'Seçilen ilde' : IK2.ulke + 'Ülke geneli') + '</span>' +
      (aktifMi(i) ? '<span class="bmv-rozet yesil">Yürürlükte · ' + esc(kalan(i.aktif_bit)) + '</span>' : '') + '</div>' +
      '<div class="bmv-icr-bas"><h4>' + esc(i.ad) + '</h4><b class="bmv-fiyat">' + mrK(i.maliyet) + '</b></div>' +
      (i.aciklama ? '<p>' + esc(i.aciklama) + '</p>' : '') + (etk || oyuncu ? '<div class="bmv-etkiler">' + etk + oyuncu + '</div>' : '') +
      '<div class="bmv-meta">' + meta.map(function (x) { return '<span>' + esc(x) + '</span>'; }).join("") + '</div>' + dugme + '</article>';
  }
  function kisaIcraat(i, yur) {
    return '<div class="bmv-satir statik"><i class="bmv-satir-ik' + (yur ? ' y' : '') + '">' + (yur ? IK.icraat : IK2.saat) + '</i><span class="bmv-satir-orta"><b>' + esc(i.ad) + '</b><small>' +
      (yur ? 'Etkisi sürüyor · tekrar ' + esc(ileri(i.hazir)) : 'Tekrar ' + esc(ileri(i.hazir)) + ' · ' + mrK(i.maliyet)) + '</small></span>' +
      (yur ? '<span class="bmv-rozet yesil">' + esc(kalan(i.aktif_bit)) + '</span>' : '<span class="bmv-rozet">' + esc(kalan(i.hazir)) + '</span>') + '</div>';
  }

  /* ---------------- Etkinlik ---------------- */
  var ETK_DURUM = { bitti: ["yesil", "Tamamlandı"], iptal: ["", "İptal"], aktif: ["kirmizi", "Sürüyor"] };
  function etkinlikSekme(v) {
    var h = "", y = v.yetki, aktif = (v.etkinlikler || []).filter(function (e2) { return e2.aktif; });
    aktif.forEach(function (e2) { h += canliEtkinlik(e2, v); });
    if (y) {
      var tl = v.etkinlik_turleri || [];
      h += '<div class="bmv-bas"><h3>Etkinlik düzenle</h3><span>Aynı anda bir etkinlik</span></div>' +
        (tl.length ? tl.map(function (t) { return etkTurKart(t, v, aktif.length > 0); }).join("") : '<div class="bmv-liste"><div class="bmv-bos">Bu bakanlığın etkinlik türü yok.</div></div>') +
        '<p class="bmv-not" style="margin-top:0">Etkinlik bakanlık kasasından ödenir ve süre boyunca herkese açıktır. Katılan oyuncular kıdem kazanır; katılım arttıkça etkisi ×2\'ye kadar büyür.</p>';
    } else if (!aktif.length) h += '<div class="bmv-liste"><div class="bmv-bos"><b>Şu an süren etkinlik yok</b>Bakanlık bir etkinlik düzenlediğinde burada görünür; katılan herkes kıdem kazanır.</div></div>';
    var biten = (v.etkinlikler || []).filter(function (e2) { return !e2.aktif; });
    if (biten.length) h += '<div class="bmv-bas"><h3>Geçmiş etkinlikler</h3><span>' + biten.length + '</span></div><div class="bmv-liste">' + biten.map(function (e2) {
      var s = e2.sonuc || {}, d = ETK_DURUM[e2.durum] || ["", e2.durum];
      return '<div class="bmv-satir statik"><i class="bmv-satir-ik">' + IK.etkinlik + '</i><span class="bmv-satir-orta"><b>' + esc(e2.ad) + (e2.il ? ' · ' + esc(e2.il) : '') + '</b><small>' +
        esc(tarihKisa(e2.bas)) + ' · ' + sayi(e2.katilimci) + ' katılımcı' + (s.carpan ? ' · etki ×' + sayi(s.carpan, 2) : '') + '</small></span><span class="bmv-rozet ' + d[0] + '">' + esc(d[1]) + '</span></div>';
    }).join("") + '</div>';
    return h + '<button type="button" class="bmv-btn tam cizgi" onclick="ekranAc(bakanlikEtkinlikleriEkrani)">Bütün bakanlıkların etkinlikleri</button>';
  }
  function canliEtkinlik(e2, v) {
    var n = Number(e2.katilimci) || 0, c = Math.min(2, 0.5 + 0.15 * n), oran = (c - 0.5) / 1.5 * 100, eksik = Math.max(0, 10 - n);
    return '<article class="bmv-canli-kart"><div class="bmv-canli-ust"><span class="bmv-nabiz"><i></i>Sürüyor</span><span>' + IK2.saat + esc(kalan(e2.bit)) + ' kaldı</span></div>' +
      '<h3>' + esc(e2.ad) + '</h3><div class="bmv-yer">' + (e2.il ? IK2.konum + esc(e2.il) : IK2.ulke + 'Ülke çapında') + ' · bitiş ' + esc(ileri(e2.bit)) + '</div>' +
      (e2.not ? '<blockquote>' + esc(e2.not) + '</blockquote>' : '') +
      '<div class="bmv-canli-sayac"><div><small>Katılımcı</small><b>' + sayi(n) + '</b></div>' + (e2.il ? '<div><small>İlden</small><b>' + sayi(e2.yerel || 0) + '</b></div>' : '') + '<div><small>Etki çarpanı</small><b>×' + sayi(c, 2) + '</b></div></div>' +
      '<div class="bmv-carpan"><i style="width:' + oran.toFixed(0) + '%"></i></div><div class="bmv-carpan-alt"><span>×0,5</span><span>' + (eksik ? eksik + ' katılım daha → ×2' : 'En yüksek etki') + '</span><span>×2</span></div>' +
      (v.yetki ? '<p class="bmv-not" style="margin:10px 0 0">Katılımı artırmak için partine, derneklere ve Kürsü\'de duyur.</p>'
        : '<button type="button" class="bmv-btn birincil" onclick="ekranAc(bakanlikEtkinlikleriEkrani)">Etkinliğe katıl, kıdem kazan</button>') + '</article>';
  }
  function etkTurKart(t, v, engel) {
    var hazir = hazirMi(t.hazir), para = Number(v.kasa) >= Number(t.maliyet);
    var dugme = engel ? '<button type="button" class="bmv-btn" disabled>Süren etkinlik bitince</button>'
      : !hazir ? '<button type="button" class="bmv-btn" disabled>' + IK2.saat + 'Tekrar ' + esc(ileri(t.hazir)) + '</button>'
      : para ? '<button type="button" class="bmv-btn birincil" onclick="bmEtkinlikModal(\'' + esc(t.kod) + '\')">Düzenle · ' + mrK(t.maliyet) + '</button>'
      : v.yetki === "bakan" ? '<button type="button" class="bmv-btn" onclick="bmTalepModal()">' + IK.odenek + 'Kasa yetmiyor · ek ödenek iste</button>'
      : '<button type="button" class="bmv-btn" disabled>Kasada yeterli ödenek yok</button>';
    return '<article class="bmv-icr"><div class="bmv-icr-ust"><span class="bmv-kapsam">' + (t.il_gerekli ? IK2.konum + 'Seçilen ilde' : IK2.ulke + 'Ülke çapında') + '</span><span class="bmv-sure">' + IK2.saat + sayi(t.sure_saat) + ' saat</span></div>' +
      '<div class="bmv-icr-bas"><h4>' + esc(t.ad) + '</h4><b class="bmv-fiyat">' + mrK(t.maliyet) + '</b></div>' + (t.aciklama ? '<p>' + esc(t.aciklama) + '</p>' : '') +
      '<div class="bmv-etkiler">' + etkiCipleri(t.etki) + '<span class="bmv-etki kidem">Katılana +' + sayi(t.kidem, 1) + ' kıdem</span></div>' + dugme + '</article>';
  }

  /* ---------------- Bütçe ---------------- */
  var TALEP_DURUM = { bekliyor: ["uyari", "Karar bekliyor"], onay: ["yesil", "Onaylandı"], red: ["kirmizi", "Reddedildi"], iptal: ["", "Geri çekildi"], dusen: ["", "Süresi doldu"] };
  function butceSekme(v) {
    var o7 = v.ozet7 || {}, y = v.yetki, k = Number(v.kasa) || 0, tv = Number(v.tavan) || 0, h = "";
    var kutucuk = function (ad, deger, birim, cls) { return '<div><small>' + ad + '</small><b class="' + (cls || "") + '">' + deger + '</b><em>' + birim + '</em></div>'; };
    h += '<div class="bmv-tablo">' + kutucuk("Son 7 gün giriş", "+" + sayi(o7.gelir, 2), "milyar ₺", "art") + kutucuk("Son 7 gün çıkış", "−" + sayi(o7.gider, 2), "milyar ₺") +
      kutucuk("Günlük ödenek", "+" + sayi(v.gunluk, 2), "milyar ₺ / gün") + kutucuk("Kasa doluluğu", "%" + sayi(tv ? k / tv * 100 : 0, 0), "tavan " + sayi(tv, 0) + " milyar ₺") + '</div>';
    if (y) {
      var bekl = (v.talepler || []).filter(function (t) { return t.durum === "bekliyor"; })[0];
      h += '<div class="bmv-iki' + (y === "bakan" ? '' : ' tek') + '">' + (y === "bakan" ? '<button type="button" class="bmv-btn birincil" onclick="bmTalepModal()"' + (bekl ? ' disabled' : '') + '>' + IK.odenek + (bekl ? 'Talebin karar bekliyor' : 'Ek ödenek iste') + '</button>' : '') +
        '<button type="button" class="bmv-btn" onclick="bmIadeModal()">' + IK.iade + 'Hazine\'ye iade et</button></div>';
    }
    var tal = v.talepler || [];
    if (tal.length) h += '<div class="bmv-bas"><h3>Ek ödenek talepleri</h3><span>' + tal.length + '</span></div><div class="bmv-liste">' + tal.map(function (t) {
      var r = TALEP_DURUM[t.durum] || ["", t.durum];
      return '<div class="bmv-talep"><div class="bmv-talep-ust"><b>' + mrK(t.tutar) + '</b><span class="bmv-rozet ' + r[0] + '">' + esc(r[1]) + '</span></div>' + (t.gerekce ? '<p>' + esc(t.gerekce) + '</p>' : '') +
        '<small>' + esc(oncesi(t.zaman)) + (t.durum === "bekliyor" ? ' · ' + esc(kalan(t.bitis)) + ' içinde karar verilmeli' : '') + '</small>' +
        (t.karar_not ? '<div class="bmv-karar-not">Karar notu: ' + esc(t.karar_not) + '</div>' : '') +
        (t.durum === "bekliyor" && y === "bakan" ? '<button type="button" class="bmv-btn kucuk cizgi" onclick="bmTalepGeriCek(' + Number(t.id) + ')">Geri çek</button>' : '') + '</div>';
    }).join("") + '</div>';
    var dg = (v.dagilim30 || []).filter(function (x) { return Number(x.giris) || Number(x.cikis); });
    if (dg.length) {
      var mx = Math.max.apply(null, dg.map(function (x) { return Number(x.giris) + Number(x.cikis); })) || 1;
      h += '<div class="bmv-bas"><h3>Son 30 gün: para nereden geldi, nereye gitti?</h3></div><div class="bmv-liste">' + dg.map(function (x) {
        var g = Number(x.giris) || 0, c = Number(x.cikis) || 0;
        return '<div class="bmv-dag"><div class="bmv-dag-ust"><span>' + esc(HAREKET_AD[x.tur] || x.tur) + '</span><span>' + (g ? '<b class="art">+' + sayi(g, 2) + '</b>' : '') + (c ? '<b class="eks">−' + sayi(c, 2) + '</b>' : '') + '</span></div>' +
          '<div class="bmv-dag-bar">' + (g ? '<i class="art" style="width:' + (g / mx * 100).toFixed(1) + '%"></i>' : '') + (c ? '<i class="eks" style="width:' + (c / mx * 100).toFixed(1) + '%"></i>' : '') + '</div></div>';
      }).join("") + '</div><p class="bmv-not">Tutarlar milyar ₺. Yeşil giriş, kırmızı çıkış.</p>';
    }
    var hr = v.hareketler || [];
    h += '<div class="bmv-bas"><h3>Hesap defteri</h3><span>Herkese açık · milyar ₺</span></div>';
    if (!hr.length) h += '<div class="bmv-liste"><div class="bmv-bos">Hesap defteri 27 Ekim 2026\'dan itibaren tutuluyor; ilk hareket burada görünecek.</div></div>';
    else {
      h += '<div class="bmv-liste' + (hr.length > 8 ? ' kisalt' : '') + '">' + hr.map(function (x) {
        var t = Number(x.tutar) || 0, tavan = x.tur === "tavan", cls = tavan ? "" : t > 0 ? "art" : "eks";
        return '<div class="bmv-defter"><i class="bmv-defter-ik ' + cls + '">' + (tavan ? IK2.kilit : t > 0 ? IK2.giris : IK2.cikan) + '</i><span class="bmv-satir-orta"><b>' + esc(x.aciklama) + '</b><small>' +
          esc(oncesi(x.zaman)) + (x.kim ? ' · ' + esc(x.kim) : '') + ' · bakiye ' + sayi(x.bakiye, 2) + '</small></span><b class="bmv-tutar ' + cls + '">' + (tavan ? 'tavan' : (t > 0 ? '+' : '−') + sayi(Math.abs(t), 2)) + '</b></div>';
      }).join("") + '</div>' + (hr.length > 8 ? '<button type="button" class="bmv-defter-daha" onclick="bmDefterAc(this)">Tüm hareketler (' + hr.length + ')</button>' : '');
    }
    return h + butceAnlat(v) + '<button type="button" class="bmv-btn tam cizgi" onclick="ekranAc(devletButcesiEkrani)">Devlet bütçesi ve bütün bakanlıklar</button>';
  }
  function butceAnlat(v) {
    return '<details class="bkm-acil"><summary>Bakanlık bütçesi nasıl işler?</summary><p>' +
      '1) Meclis\'in bütçe kanunu bu bakanlığa günlük cari harcamanın <b>%' + sayi(v.pay, 1) + '</b>\'ini verir: her gece kasaya <b>' + mr(v.gunluk, 2) + '</b> girer.<br>' +
      '2) Kasa en çok <b>' + sayi(v.tavan, 0) + ' milyar ₺</b> birikir; tavandaki kasaya giremeyen ödenek Hazine\'de kalır (boşa gitmez).<br>' +
      '3) İcraatlar, etkinlikler, saha ziyaretleri ve ihaleler bu kasadan ödenir. Para yetmezse ' + (v.sistem === "parlamenter" ? "Başbakan" : "Cumhurbaşkanı") + '\'ndan gerekçeli <b>ek ödenek</b> istenir; onaylanırsa Hazine\'den aktarılır.<br>' +
      '4) Kullanılmayan ödenek Hazine\'ye iade edilebilir. Her giriş ve çıkış hesap defterine kaynağıyla yazılır ve herkese açıktır.</p></details>';
  }

  /* ---------------- İletişim ---------------- */
  function buyukEylem(ik, ad, alt, hazir, js, mesaj) {
    var tik = hazir ? 'onclick="' + js + '"' : 'onclick="bmBilgi(this)" data-m="' + esc(mesaj) + '"';
    return '<button type="button" class="bmv-buyuk ' + (hazir ? 'hazir' : 'bekle') + '" ' + tik + '><span class="bmv-eylem-ik">' + ik + '</span><b>' + ad + '</b><small>' + esc(alt) + '</small></button>';
  }
  function aciklamaKart(x) {
    var uzun = String(x.metin || "").length > 240;
    return '<article class="bmv-basin' + (uzun ? ' kisa' : '') + '"' + (uzun ? ' onclick="this.classList.remove(\'kisa\')"' : '') + '><div class="bmv-basin-ust"><span>' + IK.aciklama + 'Basın açıklaması</span><time>' + esc(oncesi(x.zaman)) + '</time></div>' +
      '<h4>' + esc(x.baslik) + '</h4>' + (x.metin ? '<div class="bmv-basin-metin">' + esc(x.metin) + '</div>' : '') + (uzun ? '<span class="bmv-devam">Devamını oku</span>' : '') +
      (x.kad ? '<div class="bmv-imza">— ' + esc(x.kad) + '</div>' : '') + '</article>';
  }
  function iletisimSekme(v) {
    var h = "", z = v.ziyaret || {}, a = v.aciklama || {}, y = v.yetki;
    if (y) {
      var zh = hazirMi(z.hazir), ah = hazirMi(a.hazir), s = v.sorumluluk || {}, c = Number(s.cimer_bekleyen) || 0, q = Number(s.soru_bekleyen) || 0;
      h += '<div class="bmv-iki">' +
        buyukEylem(IK.ziyaret, "Saha ziyareti", zh ? mrK(z.maliyet) + " · " + beklemeYaz(z.bekleme_saat) : kalan(z.hazir) + " sonra yapılabilir", zh, "bmZiyaretModal()", "Bir sonraki saha ziyareti " + ileri(z.hazir) + " yapılabilir.") +
        buyukEylem(IK.aciklama, "Açıklama yap", ah ? "Resmî Gazete ve Gündem'de" : kalan(a.hazir) + " sonra yapılabilir", ah, "bmAciklamaModal()", "Bir sonraki bakanlık açıklaması " + ileri(a.hazir) + " yapılabilir.") + '</div>';
      h += '<div class="bmv-bas"><h3>Vatandaş ve Meclis</h3>' + (c + q ? '<span class="bmv-kirmizi">' + (c + q) + ' yanıt bekliyor</span>' : '') + '</div><div class="bmv-liste">' +
        satir2({ ik: IK2.cimer, renk: "#6fb3ff", bas: "CİMER başvuruları", alt: c ? c + " başvuru yanıt bekliyor" : "Bekleyen başvuru yok", say: c, js: "bmCimer()" }) +
        satir2({ ik: IK2.soru, renk: "#b9a6ff", bas: "Soru önergeleri", alt: q ? q + " yazılı soru yanıt bekliyor" : "Bekleyen soru yok", say: q, js: "bmSorular()" }) + '</div>';
    }
    var al = a.son || [], zl = z.son || [];
    h += '<div class="bmv-bas"><h3>Bakanlık açıklamaları</h3><span>' + al.length + '</span></div>' + (al.length ? al.map(aciklamaKart).join("") : '<div class="bmv-liste"><div class="bmv-bos">Henüz açıklama yok.</div></div>');
    h += '<div class="bmv-bas"><h3>Saha ziyaretleri</h3><span>' + zl.length + '</span></div>' + (zl.length ? '<div class="bmv-liste">' + zl.map(function (x) {
      return '<div class="bmv-zc"><i></i><div><b>' + esc(x.il) + '</b><small>' + esc(oncesi(x.zaman)) + (x.kad ? ' · ' + esc(x.kad) : '') + '</small>' + (x.not ? '<p>“' + esc(x.not) + '”</p>' : '') + '</div></div>';
    }).join("") + '</div>' : '<div class="bmv-liste"><div class="bmv-bos">Henüz saha ziyareti yok.</div></div>');
    if (!y) h += cimerBasvur();
    return h;
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
      '<div class="alan"><label>Açıklama</label><textarea id="bmAMetin" maxlength="3000" placeholder="Kamuoyuna ne duyurmak istiyorsun?"></textarea><div class="bkm-say" id="bmASay">0 / 1200</div></div>' +
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
      '<div class="alan"><label>Gerekçe (Resmî Gazete\'de yayımlanabilir)</label><textarea id="bmTGer" maxlength="1500" placeholder="Örn. Deprem bölgesindeki adliyelerin yeniden inşası için"></textarea></div>' +
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
      '<div class="alan"><label>' + (kabul ? "Not (isteğe bağlı)" : "Ret gerekçesi (isteğe bağlı)") + '</label><input id="bmKNot" maxlength="1000"></div>' +
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
