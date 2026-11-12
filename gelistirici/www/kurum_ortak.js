/* 12.11.2026 · Kurum ekranları ortak parçaları — TV Kanalları, Ticaret Odası, Valilik.
   Ekran içi sekme çubuğu (sayfa yenilenmeden geçiş, seçim yeniden çizimde korunur), aşama çizgisi, sayaç kutuları.
   Yalnız görünüm; hiçbir sunucu çağrısı yapmaz. */
(function () {
  "use strict";
  if (window.SO_KX) return;
  var esc = function (x) { return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); };
  var SEC = {};

  function stil() {
    if (document.getElementById("kxStil")) return;
    var s = document.createElement("style"); s.id = "kxStil";
    s.textContent = [
      /* sekme çubuğu: ekranın üstüne yapışır, yatay kayar */
      ".kx-sek{position:sticky;top:0;z-index:6;display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 -2px 12px;padding:8px 2px;background:linear-gradient(var(--bg) 78%,rgba(14,21,48,0))}",
      ".kx-sek::-webkit-scrollbar{display:none}",
      ".kx-sek button{flex:none;display:inline-flex;align-items:center;gap:7px;min-height:40px;padding:0 14px;border-radius:999px;font-size:14px;font-weight:750;color:var(--mut);background:var(--panel);box-shadow:inset 0 0 0 1px var(--line2);white-space:nowrap}",
      ".kx-sek button[aria-selected=true]{color:#fff;background:var(--kx,#7B61FF);box-shadow:none}",
      ".kx-sek button i{font-style:normal;min-width:20px;height:20px;padding:0 6px;border-radius:999px;display:inline-grid;place-items:center;font-size:11.5px;font-weight:800;background:rgba(255,255,255,.14);color:inherit}",
      ".kx-sek button i.uyari{background:#F2B33D;color:#1a1405}",
      ".kx-pan[hidden]{display:none!important}",
      ".kx-pan{animation:kxGir .22s ease-out}",
      "@keyframes kxGir{from{opacity:0;transform:translateY(4px)}}",
      /* aşama çizgisi (gerçek sıra olan süreçler için) */
      ".kx-adim{display:flex;margin:4px 0 14px;padding:0;list-style:none;counter-reset:kx}",
      ".kx-adim li{flex:1;min-width:0;position:relative;text-align:center;font-size:11.5px;line-height:1.25;color:var(--faint);padding-top:30px}",
      ".kx-adim li::before{counter-increment:kx;content:counter(kx);position:absolute;top:0;left:50%;transform:translateX(-50%);width:24px;height:24px;border-radius:50%;display:grid;place-items:center;font-size:12px;font-weight:800;background:var(--panel2);color:var(--mut);box-shadow:inset 0 0 0 1.5px var(--line2);z-index:1}",
      ".kx-adim li::after{content:'';position:absolute;top:11px;left:-50%;width:100%;height:2px;background:var(--line2)}",
      ".kx-adim li:first-child::after{display:none}",
      ".kx-adim li.tamam{color:var(--txt2)}.kx-adim li.tamam::before{content:'✓';background:var(--kx,#7B61FF);color:#fff;box-shadow:none}.kx-adim li.tamam::after,.kx-adim li.simdi::after{background:var(--kx,#7B61FF)}",
      ".kx-adim li.simdi{color:#fff;font-weight:750}.kx-adim li.simdi::before{background:#fff;color:#10142a;box-shadow:0 0 0 4px rgba(255,255,255,.14)}",
      /* sayaç kutuları */
      ".kx-sayilar{display:grid;grid-template-columns:repeat(var(--n,3),minmax(0,1fr));gap:8px;margin:12px 0 0}",
      ".kx-sayilar>div{min-width:0;padding:10px 10px 9px;border-radius:12px;background:rgba(255,255,255,.055);box-shadow:inset 0 0 0 1px rgba(255,255,255,.07)}",
      ".kx-sayilar b{display:block;font-family:var(--disp);font-size:21px;line-height:1.1;font-variant-numeric:tabular-nums;color:#fff}",
      ".kx-sayilar small{display:block;margin-top:3px;font-size:12px;line-height:1.3;color:var(--txt2)}",
      /* dikkat şeridi: oyuncunun yapması gerekenler */
      ".kx-dikkat{display:flex;align-items:center;gap:10px;width:100%;margin:0 0 8px;padding:11px 12px;border-radius:14px;text-align:left;background:rgba(242,179,61,.10);box-shadow:inset 0 0 0 1px rgba(242,179,61,.38);color:var(--txt)}",
      ".kx-dikkat .kx-d-g{flex:1;min-width:0}.kx-dikkat b{display:block;font-size:14.5px;line-height:1.3}.kx-dikkat small{display:block;font-size:12.5px;line-height:1.35;color:var(--txt2);margin-top:2px}",
      ".kx-dikkat .kx-d-git{flex:none;font-size:13px;font-weight:800;padding:8px 12px;border-radius:999px;background:#F2B33D;color:#1a1405}",
      ".kx-alan-bas{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin:18px 2px 8px}",
      ".kx-alan-bas h3{font-size:17px;font-weight:800;color:var(--txt)}.kx-alan-bas span{font-size:12.5px;color:var(--mut)}",
      ".kx-alan-bas:first-child{margin-top:2px}",
      ".kx-sayilar b{white-space:nowrap}",
      "@media (max-width:390px){.kx-sayilar b{font-size:18px}.kx-sayilar>div{padding:9px 8px 8px}}",
      "@media (max-width:350px){.kx-sayilar{gap:6px}.kx-sayilar b{font-size:15px}.kx-sayilar small{font-size:11.5px}}",
      "@media (prefers-reduced-motion:reduce){.kx-pan{animation:none}}"
    ].join("");
    document.head.appendChild(s);
  }

  // liste: [[anahtar, ad, rozet, rozetUyari]]
  function sekmeler(ad, liste, aktif, renk) {
    stil();
    return '<div class="kx-sek" role="tablist" data-kx="' + esc(ad) + '"' + (renk ? ' style="--kx:' + esc(renk) + '"' : "") + ">" + liste.map(function (x) {
      return '<button type="button" role="tab" data-k="' + esc(x[0]) + '" aria-selected="' + (x[0] === aktif) + '" onclick="SO_KX.gec(\'' + esc(ad) + "','" + esc(x[0]) + '\')">' + esc(x[1])
        + (x[2] ? '<i class="' + (x[3] ? "uyari" : "") + '">' + esc(x[2]) + "</i>" : "") + "</button>";
    }).join("") + "</div>";
  }
  function pano(ad, k, aktif, html) { return '<div class="kx-pan" role="tabpanel" data-kx-pan="' + esc(ad) + '" data-k="' + esc(k) + '"' + (k === aktif ? "" : " hidden") + ">" + html + "</div>"; }
  function gec(ad, k) {
    SEC[ad] = k;
    var bar = document.querySelector('[data-kx="' + ad + '"]');
    document.querySelectorAll('[data-kx="' + ad + '"] button').forEach(function (b) { b.setAttribute("aria-selected", String(b.dataset.k === k)); });
    document.querySelectorAll('[data-kx-pan="' + ad + '"]').forEach(function (p) { p.hidden = p.dataset.k !== k; });
    if (!bar) return;
    var b = bar.querySelector('[data-k="' + k + '"]');
    if (b) bar.scrollLeft = Math.max(0, b.offsetLeft - (bar.clientWidth - b.offsetWidth) / 2);
    var ic = document.getElementById("icerik");
    if (ic && bar.getBoundingClientRect().top <= ic.getBoundingClientRect().top + 1) bar.scrollIntoView({ block: "start" });
  }
  function secili(ad, liste, varsayilan) { var k = SEC[ad]; return liste.some(function (x) { return x[0] === k; }) ? k : varsayilan; }
  function adimlar(liste, simdiNo) { stil(); return '<ol class="kx-adim">' + liste.map(function (a, i) { return '<li class="' + (i < simdiNo ? "tamam" : i === simdiNo ? "simdi" : "") + '">' + esc(a) + "</li>"; }).join("") + "</ol>"; }
  function sayilar(liste) { stil(); return '<div class="kx-sayilar" style="--n:' + liste.length + '">' + liste.map(function (x) { return "<div><b>" + x[0] + "</b><small>" + esc(x[1]) + "</small></div>"; }).join("") + "</div>"; }
  function dikkat(baslik, alt, git, onclick) { stil(); return '<button type="button" class="kx-dikkat" onclick="' + esc(onclick) + '"><span class="kx-d-g"><b>' + esc(baslik) + "</b>" + (alt ? "<small>" + esc(alt) + "</small>" : "") + '</span><span class="kx-d-git">' + esc(git) + "</span></button>"; }
  function bas(baslik, yan) { stil(); return '<div class="kx-alan-bas"><h3>' + esc(baslik) + "</h3>" + (yan ? "<span>" + esc(yan) + "</span>" : "") + "</div>"; }
  // aynı ada her zaman aynı renk tonu
  function ton(s) { var h = 0; String(s || "").split("").forEach(function (c) { h = (h * 31 + c.charCodeAt(0)) % 360; }); return h; }
  function harfler(ad, n) { return (String(ad || "").trim().split(/\s+/).filter(Boolean).slice(0, n || 2).map(function (w) { return w[0]; }).join("") || "?").toLocaleUpperCase("tr-TR"); }

  window.SO_KX = { stil: stil, sekmeler: sekmeler, pano: pano, gec: gec, secili: secili, adimlar: adimlar, sayilar: sayilar, dikkat: dikkat, bas: bas, ton: ton, harfler: harfler, esc: esc, SEC: SEC };
})();
