/* Canlı sinyal — ekran açıkken veritabanını birkaç saniyede bir yoklamak yerine
   public.canli_sinyal satırının değişmesini dinler. Satırda mesaj veya para yoktur.
   Realtime bağlanamazsa (tablo henüz yok, soket koptu) eski hızdaki yoklama sürer.
   Bağlanınca yoklama yedeğe iner; kopunca yine hızlanır. */
(function (root) {
  "use strict";
  if (root.CANLI && root.CANLI.izle) return;

  var ekran = { kanal: null, timer: null, sonra: null, dinle: null, imza: "" };
  var kutu = { kanal: null, anahtar: "", dinle: null };

  function istemci() {
    try { return typeof API !== "undefined" && API && API.realtimeClient; } catch (e) { return null; }
  }
  function guvenli(k) {
    return typeof k === "string" && /^[a-z0-9_.:-]{1,80}$/i.test(k);
  }
  function gizli() {
    try { return typeof document !== "undefined" && document.hidden; } catch (e) { return false; }
  }
  function otomatikIzin() {
    try { return typeof YUK === "undefined" || !YUK || typeof YUK.otomatik !== "function" || YUK.otomatik(); }
    catch (e) { return true; }
  }
  function bekleyenKur(tazele, pencereMs) {
    var son = null, kuyruk = null, kapali = false;
    function calistir(zorla) {
      if (kapali || gizli() || !otomatikIzin()) return;
      var simdi = Date.now();
      if (!zorla && son != null && simdi - son < pencereMs) {
        if (!kuyruk) kuyruk = setTimeout(function () { kuyruk = null; calistir(true); }, pencereMs);
        return;
      }
      son = Date.now();
      Promise.resolve().then(tazele).catch(function () {});
    }
    return {
      calistir: function () { calistir(false); },
      kopar: function () { kapali = true; if (kuyruk) { clearTimeout(kuyruk); kuyruk = null; } }
    };
  }
  function kanalAc(anahtarlar, dinle) {
    var sb = istemci();
    if (!sb || typeof sb.channel !== "function" || !anahtarlar.length) return null;
    var ch = sb.channel("canli-" + anahtarlar.join("-").slice(0, 48) + "-" + Math.random().toString(36).slice(2, 7), { config: { private: false } });
    anahtarlar.forEach(function (k) {
      ["INSERT", "UPDATE"].forEach(function (ev) {
        ch.on("postgres_changes", { event: ev, schema: "public", table: "canli_sinyal", filter: "anahtar=eq." + k }, function () { dinle.calistir(); });
      });
    });
    return ch;
  }
  function saatKur(hedef, saglik, opts) {
    if (hedef.timer) { clearInterval(hedef.timer); hedef.timer = null; }
    var taban = saglik ? (opts.yedekMs || 90000) : (opts.hizliMs || 6000);
    var yay = opts.yayilim == null ? 1500 : opts.yayilim;
    var ms = taban + (yay > 0 ? Math.floor(Math.random() * yay) : 0);
    hedef.timer = setInterval(function () {
      if (gizli() || !otomatikIzin()) return;
      Promise.resolve().then(opts.tazele).catch(function () {});
    }, ms);
    hedef.ms = ms;
    try { if (typeof D !== "undefined" && D) D.canli = hedef.timer; } catch (e) {}
    return ms;
  }

  function ekranKopar() {
    var sb = istemci();
    if (ekran.kanal && sb && typeof sb.removeChannel === "function") {
      try { sb.removeChannel(ekran.kanal); } catch (e) {}
    }
    ekran.kanal = null;
    if (ekran.dinle) { ekran.dinle.kopar(); ekran.dinle = null; }
    if (ekran.sonra) { clearTimeout(ekran.sonra); ekran.sonra = null; }
    if (ekran.timer) {
      clearInterval(ekran.timer);
      try { if (typeof D !== "undefined" && D && D.canli === ekran.timer) D.canli = null; } catch (e) {}
      ekran.timer = null;
    }
    ekran.imza = "";
  }

  function izle(opts) {
    opts = opts || {};
    var anahtarlar = (opts.anahtarlar || []).filter(guvenli);
    var imza = anahtarlar.slice().sort().join("|") + "|" + (opts.hizliMs || 0) + "|" + (opts.sonraMs || 0);
    if (ekran.imza === imza && ekran.timer) return;
    ekranKopar();
    if (typeof opts.tazele !== "function") return;
    ekran.imza = imza;
    var pencere = opts.pencereMs || 1800;
    ekran.dinle = bekleyenKur(opts.tazele, pencere);
    var saglik = false;
    saatKur(ekran, false, opts);
    if (opts.sonraMs > 0 && opts.sonraMs < 12 * 3600 * 1000) {
      ekran.sonra = setTimeout(function () { ekran.dinle && ekran.dinle.calistir(); }, opts.sonraMs);
    }
    var ch = kanalAc(anahtarlar, ekran.dinle);
    if (!ch || typeof ch.subscribe !== "function") return;
    ekran.kanal = ch;
    ch.subscribe(function (durum) {
      if (ekran.kanal !== ch) return;
      var iyi = durum === "SUBSCRIBED";
      if (iyi === saglik) return;
      saglik = iyi;
      saatKur(ekran, iyi, opts);
    });
  }

  function kutuKopar() {
    var sb = istemci();
    if (kutu.kanal && sb && typeof sb.removeChannel === "function") {
      try { sb.removeChannel(kutu.kanal); } catch (e) {}
    }
    kutu.kanal = null;
    if (kutu.dinle) { kutu.dinle.kopar(); kutu.dinle = null; }
    kutu.anahtar = "";
  }
  function kutuBaslat() {
    var profil = typeof D !== "undefined" && D && D.durum && D.durum.profil;
    var id = profil && profil.id;
    if (!id) return;
    var anahtar = "kutu:" + id;
    if (!guvenli(anahtar) || (kutu.anahtar === anahtar && kutu.kanal)) return;
    kutuKopar();
    kutu.anahtar = anahtar;
    kutu.dinle = bekleyenKur(function () {
      if (typeof mesajBildirimKontrol === "function") return mesajBildirimKontrol();
    }, 1500);
    var ch = kanalAc([anahtar], kutu.dinle);
    if (!ch || typeof ch.subscribe !== "function") return;
    kutu.kanal = ch;
    ch.subscribe(function () {});
  }

  function sohbetAnahtari(kod) {
    var p = typeof D !== "undefined" && D && D.durum && D.durum.profil;
    if (!p || !kod) return null;
    if (kod === "genel" || kod === "meclis" || kod === "kabine" || kod === "divan") return "sohbet:" + kod;
    if ((kod === "il" || kod === "belediye") && p.il_id != null) return "sohbet:" + kod + ":" + p.il_id;
    if ((kod === "parti" || kod === "yonetim" || kod === "grup") && p.parti && p.parti.id != null) return "sohbet:" + kod + ":" + p.parti.id;
    return null;
  }

  var eskiDurdur = typeof canliDurdur === "function" ? canliDurdur : null;
  canliDurdur = function () {
    ekranKopar();
    if (typeof eskiDurdur === "function") return eskiDurdur.apply(this, arguments);
  };
  try { root.canliDurdur = canliDurdur; } catch (e) {}

  root.CANLI = {
    izle: izle,
    ekranKopar: ekranKopar,
    kutuBaslat: kutuBaslat,
    kutuKopar: kutuKopar,
    sohbetAnahtari: sohbetAnahtari,
    _ekran: function () { return ekran; },
    _kutu: function () { return kutu; }
  };
})(typeof window !== "undefined" ? window : globalThis);
