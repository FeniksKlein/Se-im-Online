/* =====================================================================
   KESİNTİSİZ EKRAN (31.10.2026) — Otomatik tazeleme oyuncunun işini bozmasın
   Sorun: açık ekran kendiliğinden yenilenince sayfa en üste atılıyor,
   Gündem'deki Kürsü kutusuna yazılan metin siliniyordu.
   Kurallar:
    1) Aynı ekran kendiliğinden yeniden çizilirken "Yükleniyor…" ile sayfa silinmez;
       eski içerik yeni veri gelene kadar kalır, kaydırma konumu korunur.
    2) Otomatik bir tazeleme (zamanlayıcı, uygulamaya dönüş, sunucu sinyali)
       oyuncu yazı yazarken, yazılmış ama gönderilmemiş bir metin varken,
       bir pencere açıkken ya da son birkaç saniyede kaydırırken/dokunurken
       YAPILMAZ; bir sonraki uygun anda yapılır.
    3) Oyuncunun kendi dokunuşuyla başlayan çizimler her zaman yapılır.
   index.html ve diğer modüllerin iskelet sarmalarının en dışında çalışır
   (derle.js'de en son gömülür).
   ===================================================================== */
(function () {
  'use strict';
  if (window.SO_KESINTISIZ_V1) return;
  window.SO_KESINTISIZ_V1 = true;
  var S = { eylem: 0, dokunus: 0, oto: 0, atlanan: 0, bekleyen: false };
  var simdi = function () { return Date.now(); };

  function yaziAlani(el) {
    if (!el || el === document.body || !el.tagName) return false;
    if (el.isContentEditable) return true;
    var t = el.tagName;
    if (t === 'TEXTAREA' || t === 'SELECT') return true;
    return t === 'INPUT' && /^(text|search|email|number|tel|url|password|)$/i.test(el.getAttribute('type') || '');
  }

  // Bilinçli eylem: düğmeye/bağlantıya dokunma, gönderme, Enter. Yazı alanına dokunmak eylem sayılmaz (yazmaya başlamaktır).
  function eylemKaydet(ev) {
    var h = ev.target;
    S.dokunus = simdi();
    if (yaziAlani(h)) return;
    S.eylem = simdi();
  }
  document.addEventListener('pointerdown', eylemKaydet, true);
  document.addEventListener('click', eylemKaydet, true);
  document.addEventListener('submit', function () { S.eylem = simdi(); }, true);
  document.addEventListener('keydown', function (ev) {
    S.dokunus = simdi();
    if (ev.key === 'Enter' && !(ev.target && ev.target.tagName === 'TEXTAREA')) S.eylem = simdi();
  }, true);
  ['touchstart', 'touchmove', 'wheel'].forEach(function (t) { document.addEventListener(t, function () { S.dokunus = simdi(); }, { capture: true, passive: true }); });
  document.addEventListener('scroll', function () { S.dokunus = simdi(); }, { capture: true, passive: true });

  function taslakVar() {
    var ic = document.getElementById('icerik'); if (!ic) return false;
    var l = ic.querySelectorAll('textarea, input');
    for (var i = 0; i < l.length; i++) {
      var x = l[i];
      if (!yaziAlani(x) || x.disabled || x.readOnly) continue;
      if (x.value && x.value !== x.defaultValue) return true;
    }
    return false;
  }
  function katmanAcik() {
    return !!(document.getElementById('modal') || document.getElementById('krYaz') ||
      document.querySelector('.kr-yaz-arka, [role="dialog"][aria-modal="true"]'));
  }
  function mesgul() {
    if (yaziAlani(document.activeElement)) return true;
    if (katmanAcik()) return true;
    if (taslakVar()) return true;
    if (simdi() - S.dokunus < 4000) return true;
    return false;
  }
  // Son kullanıcı eyleminden 10 sn sonra ya da otomatik bir tetikten sonra gelen çizim otomatiktir
  function otomatik() { return simdi() - S.eylem > 10000 || S.oto > S.eylem; }
  window.SO_MESGUL = mesgul;
  window.SO_OTOMATIK = otomatik;
  window.SO_KESINTISIZ = S;

  // Uygulamaya dönüş ve sunucu sinyali otomatik tetiktir (index.html'deki dinleyiciden önce çalışır)
  window.addEventListener('visibilitychange', function () { if (!document.hidden) S.oto = simdi(); }, true);
  window.addEventListener('focus', function () { S.oto = simdi(); }, true);

  function baglaIskelet() {
    if (typeof iskelet !== 'function' || iskelet._ks) return false;
    var eski = iskelet;
    var yeni = function (baslik, govde) {
      try {
        var ic = document.getElementById('icerik');
        var anahtar = (typeof D === 'object' && D ? D.sekme + '|' + (D._ekranNo || 0) : '') + '|' + baslik;
        var ayni = !!ic && typeof D === 'object' && D && D._sonAnahtar === anahtar;
        if (ayni && otomatik()) {
          // 1) Aynı ekran kendiliğinden tazelenirken içerik "Yükleniyor…" ile silinmesin (kaydırma korunur)
          if (typeof govde === 'string' && /^\s*<div class="yukleniyor">/.test(govde)) return;
          // 2) Oyuncu bir şey yaparken otomatik tazeleme ertelenir
          if (mesgul()) { S.atlanan++; S.bekleyen = true; return; }
        }
      } catch (_) {}
      S.bekleyen = false;
      return eski.apply(this, arguments);
    };
    yeni._ks = true;
    try { iskelet = yeni; } catch (_) {}
    window.iskelet = yeni;
    return true;
  }
  function baglaYenidenCiz() {
    if (typeof yenidenCiz !== 'function' || yenidenCiz._ks) return false;
    var eski = yenidenCiz;
    var yeni = function () {
      S.oto = simdi();
      if (mesgul()) { S.atlanan++; S.bekleyen = true; return; }
      return eski.apply(this, arguments);
    };
    yeni._ks = true;
    try { yenidenCiz = yeni; } catch (_) {}
    window.yenidenCiz = yeni;
    return true;
  }
  baglaIskelet(); baglaYenidenCiz();
  // Sonradan yüklenen modüller iskeleti yeniden sararsa en dışta kalmak için bir kez daha dene
  setTimeout(function () { baglaIskelet(); baglaYenidenCiz(); }, 2500);

  // Ertelenen tazeleme: oyuncu işini bitirip 20 sn boyunca boşta kalınca bir kez yapılır (yalnız ana sekme ekranında)
  setInterval(function () {
    if (!S.bekleyen || document.hidden || mesgul()) return;
    if (simdi() - S.dokunus < 20000 || simdi() - S.eylem < 20000) return;
    S.bekleyen = false;
    try { if (typeof D === 'object' && D && (!D.yigin || !D.yigin.length) && typeof EKRAN === 'object' && EKRAN[D.sekme]) { S.oto = simdi(); EKRAN[D.sekme](); } } catch (_) {}
  }, 5000);
})();
