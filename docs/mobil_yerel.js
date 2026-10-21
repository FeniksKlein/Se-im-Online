/* =====================================================================
   TELEFON UYGULAMASI BAĞLANTILARI (yalnız iOS/Android uygulamasında çalışır; web'de hiçbir şey yapmaz)
   - Android geri tuşu: açık pencereyi kapatır, bir önceki ekrana döner, alt sekmeden Gündem'e,
     Gündem'de uygulamayı arka plana alır (uygulamayı aniden kapatmaz).
   - Durum çubuğu oyunun lacivert zeminine uyar.
   ===================================================================== */
(function () {
  "use strict";
  const C = window.Capacitor;
  if (!C || typeof C.isNativePlatform !== "function" || !C.isNativePlatform()) return;
  const P = C.Plugins || {};
  try {
    if (P.App && typeof P.App.addListener === "function") {
      P.App.addListener("backButton", function () {
        try {
          if (document.querySelector("#modal")) { modalKapat(); return; }
          if (typeof D !== "undefined" && D && Array.isArray(D.yigin) && D.yigin.length) { geriGit(); return; }
          if (typeof D !== "undefined" && D && D.durum && D.sekme && D.sekme !== "gundem") { sekmeAc("gundem"); return; }
          if (typeof P.App.minimizeApp === "function") P.App.minimizeApp(); else P.App.exitApp();
        } catch (_) {}
      });
      // Uygulama arka plandan dönünce oturum yenilensin (bildirim rozetleri, sayaçlar)
      P.App.addListener("appStateChange", function (s) {
        try { if (s && s.isActive && typeof D !== "undefined" && D && D.durum && typeof durumYenile === "function") durumYenile().catch(function () {}); } catch (_) {}
      });
    }
  } catch (_) {}
  try {
    const SB = P.StatusBar;
    if (SB) {
      if (SB.setStyle) SB.setStyle({ style: "DARK" }).catch(function () {});
      if (C.getPlatform() === "android" && SB.setBackgroundColor) SB.setBackgroundColor({ color: "#0E1530" }).catch(function () {});
    }
  } catch (_) {}
})();
