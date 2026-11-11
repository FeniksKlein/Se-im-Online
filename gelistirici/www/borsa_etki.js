/* 11.11.2026 · Borsanın ekonomiye etkisi — Piyasa panosuna "Piyasa durumu" kartı.
   Arka uç: sql/185_borsa_endeks_etki.sql (borsa_etki_durum). Yalnız okur. */
(function () {
  "use strict";
  if (window.SO_BORSA_ETKI_V1) return;
  window.SO_BORSA_ETKI_V1 = true;

  function k(x) { return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function sayi(x, isaret) { var n = Number(x) || 0; return (isaret && n > 0 ? "+" : "") + n.toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
  var RENK = { cokus: "#ff6b70", sert_dusus: "#ff8f6b", dusus: "#ffc061", normal: "#a9b1c8", yukselis: "#7dffbf", ralli: "#49e6a0" };

  function kartHtml(v) {
    var s = v && v.son; if (!s) return "";
    var y = v.yedi_gun || {}, renk = RENK[s.rejim] || "#a9b1c8";
    var cubuk = (v.gecmis || []).slice().reverse().map(function (g) {
      var h = Math.min(100, Math.max(6, Math.abs(Number(g.r1) || 0) * 6));
      return '<i title="' + k(g.gun) + " · %" + sayi(g.r1, true) + '" style="height:' + h + "%;background:" + (Number(g.r1) < 0 ? "#ff6b70" : "#49e6a0") + '"></i>';
    }).join("");
    return '<section class="kart be-kart" style="border-left:3px solid ' + renk + '">'
      + '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:10px"><h2 style="margin:0">Piyasa durumu</h2>'
      + '<span class="rozet" style="background:' + renk + '22;color:' + renk + ';font-weight:700">' + k(s.rejim_ad) + "</span></div>"
      + '<p class="alt" style="margin:8px 0 10px">' + k(s.aciklama) + "</p>"
      + '<div class="be-izgara"><div><small>Günlük</small><b style="color:' + (s.r1 < 0 ? "#ff8f93" : "#8ff0c0") + '">%' + sayi(s.r1, true) + "</b></div>"
      + "<div><small>7 gün</small><b>" + (s.r7 == null ? "—" : "%" + sayi(s.r7, true)) + "</b></div>"
      + "<div><small>Zirveden</small><b>%" + sayi(s.dd) + "</b></div></div>"
      + (cubuk ? '<div class="be-cubuk" aria-hidden="true">' + cubuk + "</div>" : "")
      + '<div class="kv"><span class="k">Son 7 günde büyümeye etkisi</span><span class="v">' + sayi(y.buyume, true) + " puan</span></div>"
      + '<div class="kv"><span class="k">Halkın memnuniyetine etkisi</span><span class="v">' + sayi(y.memnuniyet, true) + " puan</span></div>"
      + (Number(y.enflasyon) ? '<div class="kv"><span class="k">Enflasyona etkisi (risk primi)</span><span class="v">' + sayi(y.enflasyon, true) + " puan</span></div>" : "")
      + '<p class="kucuk" style="margin-top:8px">Endeks şirketlerin gerçek değer değişimini ölçer; ortakların kasaya koyduğu ya da şirketten çektiği para yükseliş/düşüş sayılmaz. '
      + "Sert düşüşler büyümeyi ve memnuniyeti azaltır, bu da şirket cirolarına ve istihdama yansır; yükselişler tersini yapar.</p></section>";
  }
  function stil() {
    if (document.getElementById("beStil")) return;
    var st = document.createElement("style"); st.id = "beStil";
    st.textContent = ".be-izgara{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:10px}.be-izgara>div{background:var(--panel2,#1a2033);border-radius:12px;padding:10px}"
      + ".be-izgara small{display:block;font-size:12px;color:var(--faint,#7c849d)}.be-izgara b{font-size:17px;font-variant-numeric:tabular-nums}"
      + ".be-cubuk{display:flex;align-items:flex-end;gap:3px;height:44px;margin:0 0 10px}.be-cubuk i{flex:1;border-radius:3px 3px 0 0;opacity:.85}";
    document.head.appendChild(st);
  }
  /* Piyasa panosu ve Borsa ekranı: ekran çizildikten sonra kartı başa (varsa hero sahnesinin altına) ekler. */
  function bagla(ad) {
    var f = window[ad];
    if (typeof f !== "function") return false;
    if (f._be) return true;
    var yeni = async function () {
      var r = await f.apply(this, arguments);
      try {
        var v = await API.rpc("borsa_etki_durum"), h = kartHtml(v), ic = document.getElementById("icerik");
        if (h && ic && !ic.querySelector(".be-kart")) {
          stil();
          var sahne = ic.querySelector(":scope>.e3-sahne, :scope>.pa-hero, :scope>.bolum-bas");
          if (sahne && sahne.classList.contains("bolum-bas")) sahne.insertAdjacentHTML("beforebegin", h);
          else if (sahne) sahne.insertAdjacentHTML("afterend", h); else ic.insertAdjacentHTML("afterbegin", h);
        }
      } catch (_) {}
      return r;
    };
    yeni._be = true;
    window[ad] = yeni;
    try { if (ad === "piyasaPanosuEkrani") piyasaPanosuEkrani = yeni; else if (ad === "borsaEkrani") borsaEkrani = yeni; } catch (_) {}
    return true;
  }
  ["piyasaPanosuEkrani", "borsaEkrani"].forEach(function (ad) { if (!bagla(ad)) setTimeout(function () { bagla(ad); }, 1500); });
})();
