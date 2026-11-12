/* 11.11.2026 · Öne çıkan giriş kartı — Gündem (TV Kanalları), Devlet (Valilik) ve Ekonomi (Ticaret Odası)
   ekranlarının üst bölümünde canlı durumu gösteren, belirgin giriş kartı. Sunucu: 200_one_cikan_ozet.sql.
   Yalnız görünüm ve gezinme; hiçbir işlem yapmaz. */
(function () {
  "use strict";
  if (window.SO_ONE_CIKAN) return;

  var SV = function (ic) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ic + "</svg>"; };
  var IK = {
    tv: SV('<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M8 21h8M9 2l3 4 3-4"/><path d="M10.5 9.8v4.4l3.8-2.2z" fill="currentColor" stroke="none"/>'),
    oda: SV('<path d="M3 21h18M5 21V10h5v11M10 21V4h6v17M16 21v-8h3v8"/><path d="M13 8h.01M13 12h.01M13 16h.01"/>'),
    vali: SV('<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>')
  };
  // "Yeni" etiketi yayından sonraki iki hafta görünür
  var YENI_BITIS = new Date("2026-11-26T00:00:00+03:00").getTime();
  var yeniMi = function () { try { return (typeof simdi === "function" ? simdi() : Date.now()) < YENI_BITIS; } catch (_) { return Date.now() < YENI_BITIS; } };
  var esc = function (x) { return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); };

  function stil() {
    if (document.getElementById("ocGirisStil")) return;
    var s = document.createElement("style"); s.id = "ocGirisStil";
    s.textContent = [
      ".oc-giris{display:flex;align-items:center;gap:12px;width:100%;box-sizing:border-box;margin:0 0 14px;padding:13px 14px;border-radius:18px;border:1px solid rgba(var(--r),.5);",
      "background:linear-gradient(135deg,rgba(var(--r),.20),rgba(var(--r),.04)),var(--panel,#151E3D);box-shadow:0 16px 30px -24px rgba(var(--r),.95);color:var(--txt,#e9ebf3);font:inherit;text-align:left;cursor:pointer;-webkit-tap-highlight-color:transparent}",
      ".oc-giris:active{transform:scale(.985)}",
      ".oc-giris:focus-visible{outline:2px solid rgba(var(--r),1);outline-offset:2px}",
      ".oc-giris .oc-ik{flex:none;width:44px;height:44px;border-radius:14px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,rgba(var(--r),1),rgba(var(--r),.55));box-shadow:inset 0 1px 0 rgba(255,255,255,.3)}",
      ".oc-giris .oc-ik svg{width:22px;height:22px}",
      ".oc-giris .oc-g{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}",
      ".oc-giris .oc-g small{display:flex;align-items:center;gap:6px;flex-wrap:wrap;font-size:11px;font-weight:800;letter-spacing:.07em;text-transform:uppercase;color:var(--rl)}",
      ".oc-giris .oc-g b{font-size:15.5px;line-height:1.25;color:#f3f5fb;overflow-wrap:anywhere}",
      ".oc-giris .oc-g em{font-style:normal;font-size:12.5px;line-height:1.4;color:#a9b2cf;overflow-wrap:anywhere}",
      ".oc-giris .oc-git{flex:none;font-size:12.5px;font-weight:800;color:#fff;background:rgba(var(--r),.92);padding:7px 11px;border-radius:999px;white-space:nowrap}",
      ".oc-giris i{font-style:normal}",
      ".oc-giris .oc-yeni{font-size:10px;letter-spacing:.05em;color:#10131f;background:#ffd166;padding:1px 6px;border-radius:999px}",
      ".oc-giris .oc-canli{font-size:10px;letter-spacing:.06em;color:#fff;background:#e5484d;padding:1px 7px;border-radius:999px;animation:ocNabiz 1.6s ease-in-out infinite}",
      ".oc-giris.canli{border-color:rgba(229,72,77,.85)}",
      "@keyframes ocNabiz{50%{opacity:.55}}",
      "@media (prefers-reduced-motion:reduce){.oc-giris .oc-canli{animation:none}.oc-giris:active{transform:none}}",
      "@media (max-width:350px){.oc-giris{gap:10px;padding:12px}.oc-giris .oc-ik{width:38px;height:38px;border-radius:12px}.oc-giris .oc-git{padding:6px 9px}}"
    ].join("");
    document.head.appendChild(s);
  }

  // o: { id, ikon, renk: "r,g,b", acik: "#hex", etiket, baslik, alt, git, onclick, canli }
  function imza(o) { return [o.etiket, o.baslik, o.alt, o.git, o.onclick, o.canli ? 1 : 0, yeniMi() ? 1 : 0].join("|"); }
  function html(o) {
    return '<button type="button" class="oc-giris' + (o.canli ? " canli" : "") + '" id="' + esc(o.id) + '" data-imza="' + esc(imza(o)) + '" style="--r:' + esc(o.renk) + ";--rl:" + esc(o.acik) + '" onclick="' + esc(o.onclick) + '">'
      + '<span class="oc-ik">' + (IK[o.ikon] || "") + "</span>"
      + '<span class="oc-g"><small>' + (o.canli ? '<i class="oc-canli">Canlı</i>' : "") + "<span>" + esc(o.etiket) + "</span>" + (!o.canli && yeniMi() ? '<i class="oc-yeni">Yeni</i>' : "") + "</small>"
      + "<b>" + esc(o.baslik) + "</b><em>" + esc(o.alt) + "</em></span>"
      + '<span class="oc-git">' + esc(o.git) + "</span></button>";
  }
  // Kartı yerleştirir ya da günceller. bul(icerik) → { el, yer: "afterend" | "beforebegin" | "afterbegin" }
  function koy(o, bul) {
    try {
      stil();
      var ic = document.getElementById("icerik"); if (!ic) return false;
      var el = document.getElementById(o.id);
      if (el && !ic.contains(el)) { el.remove(); el = null; }
      if (el && el.dataset.imza !== imza(o)) {
        var gecici = document.createElement("div"); gecici.innerHTML = html(o);
        el.replaceWith(gecici.firstChild); el = document.getElementById(o.id);
      }
      var c = bul(ic); if (!c || !c.el) return !!el;
      if (!el) { c.el.insertAdjacentHTML(c.yer, html(o)); return true; }
      var dogru = c.yer === "afterend" ? c.el.nextElementSibling === el : c.yer === "beforebegin" ? c.el.previousElementSibling === el : c.el.firstElementChild === el;
      if (!dogru) c.el.insertAdjacentElement(c.yer, el);
      return true;
    } catch (_) { return false; }
  }
  // Ekran çizildikten hemen sonra ve diğer katmanlar yerleşince konumu yeniden doğrular
  function tekrarla(fn) { fn(); setTimeout(fn, 80); setTimeout(fn, 500); }

  window.SO_ONE_CIKAN = { koy: koy, html: html, stil: stil, tekrarla: tekrarla, yeniMi: yeniMi };
})();
