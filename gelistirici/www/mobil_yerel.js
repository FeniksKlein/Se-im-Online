/* =====================================================================
   TELEFON UYGULAMASI BAĞLANTILARI (yalnız iOS/Android uygulamasında çalışır; web'de hiçbir şey yapmaz)
   - Android geri tuşu: açık pencereyi kapatır, bir önceki ekrana döner, alt sekmeden Gündem'e,
     Gündem'de uygulamayı arka plana alır (uygulamayı aniden kapatmaz).
   - Durum çubuğu oyunun lacivert zeminine uyar.
   - Reklam izinleri (Google rıza formu, iOS izleme izni) reklamdan önce sorulur.
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
  // Reklam izinleri: AB/İngiltere'deki oyunculara Google rıza formu (UMP), iOS'ta Apple izleme izni (ATT).
  // Uygulama açıldıktan kısa süre sonra bir kez sorulur; reklam isteği bu sorular bitince yapılır.
  // İzin verilmezse reklamlar kişiselleştirilmeden gösterilir, oyun aynen çalışır.
  try {
    const A = P.AdMob;
    if (A) {
      const izin = new Promise(function (bitti) {
        setTimeout(async function () {
          try {
            if (typeof A.requestConsentInfo === "function") {
              const r = await A.requestConsentInfo();
              if (r && r.status === "REQUIRED" && r.isConsentFormAvailable && typeof A.showConsentForm === "function") await A.showConsentForm();
            }
          } catch (_) {}
          try {
            // iOS izleme izni penceresini uygulamanın kendisi açar (SceneDelegate); burada yalnız cevap beklenir (en çok 20 sn).
            // İkinci bir istek göndermiyoruz: çift istek reklam katmanını kilitleyebiliyor.
            if (C.getPlatform() === "ios" && typeof A.trackingAuthorizationStatus === "function") {
              for (let i = 0; i < 40; i++) {
                const s = await A.trackingAuthorizationStatus();
                if (!s || s.status !== "notDetermined") break;
                await new Promise(function (r) { setTimeout(r, 500); });
              }
            }
          } catch (_) {}
          bitti();
        }, 1200);
      });
      if (typeof REKLAM !== "undefined" && REKLAM && typeof REKLAM.goster === "function") {
        const eski = REKLAM.goster;
        REKLAM.goster = async function () { try { await izin; } catch (_) {} return eski.apply(this, arguments); };
      }
    }
  } catch (_) {}
})();
