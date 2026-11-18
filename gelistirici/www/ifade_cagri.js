/* 18.11.2026 · İfadeye çağırma ve zorla getirme (Gözaltı ve Avukat ekranına eklenir)
   • Çağrılan oyuncu: geri sayım, yazılı ifade ver, çağrıyı reddet; her ekranda ince uyarı şeridi.
   • Cumhurbaşkanı / İçişleri Bakanı: ifadeye çağır (konu + süre), dosyalar, ifadeyi oku, gelmeyen/reddedeni zorla getir (gözaltı), iptal.
   Yetkiler sunucuda denetlenir (ifade_* RPC'leri). */
(function () {
  "use strict";
  if (window.SO_IFADE_V1) return;
  window.SO_IFADE_V1 = true;
  var ST = { v: null, z: 0 };
  var DURUM = { bekliyor: ["İfade bekleniyor", "#f2b33d"], ifade_verildi: ["İfade verildi", "#34c98a"], reddetti: ["Çağrıyı reddetti", "#f0454b"],
    gelmedi: ["Süresinde gelmedi", "#f0454b"], zorla_getirildi: ["Zorla getirildi", "#c18a3e"], iptal: ["İptal edildi", "#98a4c4"] };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function rpc(fn, a) { return API.rpc(fn, a || {}); }
  function hata(err) { var m = (err && err.message) || String(err); if (typeof hataCevir === "function") m = hataCevir(m); toast(m, true); }
  function saat(t) { try { return new Date(t).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) { return ""; } }
  function kalan(t) { var ms = new Date(t).getTime() - Date.now(); if (!(ms > 0)) return "süre doldu"; var dk = Math.ceil(ms / 60000), sa = Math.floor(dk / 60); return (sa ? sa + " sa " : "") + (dk % 60) + " dk"; }
  function etiket(d) { var x = DURUM[d] || [d, "#98a4c4"]; return '<span class="gz-etiket" style="background:' + x[1] + '26;color:' + x[1] + '">' + esc(x[0]) + '</span>'; }
  function acikBenim(v) { return ((v && v.benim) || []).filter(function (c) { return !c.ifade && (c.durum === "bekliyor" || c.durum === "gelmedi" || c.durum === "zorla_getirildi"); }); }

  async function yukle(zorla) {
    if (!zorla && ST.v && Date.now() - ST.z < 60000) return ST.v;
    ST.v = await rpc("ifade_cagrilari"); ST.z = Date.now(); return ST.v;
  }

  function benimHtml(c) {
    var gec = c.durum !== "bekliyor";
    return '<div class="gz-kapak" style="background:radial-gradient(120% 90% at 100% 0%,rgba(242,179,61,.25),transparent 60%),linear-gradient(170deg,#2a2215,#141a33);border-color:rgba(242,179,61,.5)">' +
      '<h2>İfadeye çağrıldınız</h2><div class="kucuk">' + esc(c.makam) + ' · ' + esc(c.cagiran) + ' · Çağrı #' + esc(c.id) + '</div>' +
      (c.durum === "bekliyor" ? '<div class="gz-sayac" data-gz-bitis="' + esc(c.son) + '">' + esc(kalan(c.son)) + '</div><div class="kucuk">içinde ifade vermelisiniz · son ' + esc(saat(c.son)) + '</div>'
        : '<div class="gz-sayac" style="color:#ff8a8f;font-size:22px">' + (c.durum === "zorla_getirildi" ? "Zorla getirildiniz" : "Süre doldu") + '</div>') + '</div>' +
      '<div class="kart"><h3>Çağrının konusu</h3><p>' + esc(c.konu) + '</p>' +
      (gec && c.durum !== "zorla_getirildi" ? '<div class="gz-uyari">Süresinde ifade vermediniz. ' + (c.zorla_son ? esc(saat(c.zorla_son)) + ' tarihine kadar' : 'Bir süre') + ' zorla getirilip gözaltına alınabilirsiniz. Şimdi ifade verirseniz zorla getirme kararı verilemez.</div>' : '') +
      (c.durum === "zorla_getirildi" ? '<div class="gz-uyari">Gözaltındayken de ifadenizi verebilirsiniz. Tahliyeye Cumhurbaşkanı ya da İçişleri Bakanı karar verir.</div>' : '') +
      '<form data-if-ver="' + esc(c.id) + '"><label>Yazılı ifadeniz</label><textarea name="metin" minlength="20" maxlength="3000" required placeholder="Olay hakkında bildiklerinizi ve savunmanızı yazın. Avukatınız varsa önce onunla görüşebilirsiniz."></textarea>' +
      '<button class="btn altin" type="submit">İfademi ver</button></form>' +
      (c.durum === "bekliyor" ? '<details style="margin-top:8px"><summary>Çağrıyı reddet</summary><form data-if-red="' + esc(c.id) + '"><label>Gerekçe (isteğe bağlı)</label><textarea name="gerekce" maxlength="500" style="min-height:70px"></textarea>' +
        '<button class="btn ikinci" type="submit">Çağrıyı reddet</button><small>Reddederseniz zorla getirilip gözaltına alınabilirsiniz (CMK m.146).</small></form></details>' : '') +
      '</div>';
  }

  function yetkiliHtml(v) {
    var a = v.ayar || {}, ls = v.dosyalar || [];
    var h = '<div class="kart" style="border:1px solid rgba(242,179,61,.6)"><h3>İfadeye çağır</h3>' +
      '<p>Oyuncu belirttiğiniz süre içinde yazılı ifade verir ya da çağrıyı reddeder. Gelmeyen ya da reddeden oyuncu hakkında ' + esc(a.pencere) + ' saat içinde <b>zorla getirme</b> kararı verip ' + esc(a.zorla_saat) + ' saat gözaltına alabilirsiniz (sebepsiz gözaltı kotanızı harcamaz). Bugün: ' + esc(a.bugun || 0) + ' / ' + esc(a.gunluk) + '. Görevdeki Cumhurbaşkanı ve dokunulmazlığı süren milletvekili çağrılamaz.</p>' +
      '<form data-if-cagir><label>Oyuncunun kullanıcı adı</label><input name="kad" minlength="2" maxlength="60" autocomplete="off" required placeholder="Kullanıcı adını aynen yazın">' +
      '<label>Konu (hangi olay hakkında)</label><textarea name="konu" minlength="10" maxlength="600" required placeholder="Örn. 17 Kasım İstanbul eylemindeki olaylar"></textarea>' +
      '<label>İfade vermesi için süre</label><select name="sure">' + [6, 12, 24, 48, 72].filter(function (s) { return s >= (a.min || 6) && s <= (a.max || 72); }).map(function (s) {
        return '<option value="' + s + '"' + (s === +a.varsayilan ? " selected" : "") + '>' + s + ' saat</option>'; }).join("") + '</select>' +
      '<button class="btn altin" type="submit">İfadeye çağır</button></form></div>';
    h += '<div class="kart"><h3>İfade dosyaları (' + ls.length + ')</h3>';
    if (!ls.length) h += '<p>Açık ya da son 14 günde kapanmış ifade çağrısı yok.</p>';
    ls.forEach(function (c) {
      var zorla = (c.durum === "gelmedi" || c.durum === "reddetti") && !c.ifade && c.zorla_son && new Date(c.zorla_son) > new Date();
      h += '<div class="gz-dosya"><h4>' + esc(c.hedef) + '</h4>' + etiket(c.durum) + '<span class="gz-etiket">#' + esc(c.id) + ' · ' + esc(c.cagiran) + '</span>' +
        (c.durum === "bekliyor" ? '<span class="gz-etiket" data-gz-bitis-kisa="' + esc(c.son) + '">' + esc(kalan(c.son)) + ' kaldı</span>' : '') +
        (c.gozaltinda ? '<span class="gz-etiket kirmizi">Şu an gözaltında</span>' : '') +
        '<p class="kucuk" style="margin:8px 0 0">Konu: ' + esc(c.konu) + '</p>' +
        (c.ret_gerekce ? '<p class="kucuk">Ret gerekçesi: ' + esc(c.ret_gerekce) + '</p>' : '') +
        (c.ifade ? '<details><summary>İfadeyi oku (' + esc(saat(c.ifade_at)) + ')</summary><div class="gz-aciklama" style="white-space:pre-wrap">' + esc(c.ifade) + '</div></details>' : '') +
        (zorla ? '<form data-if-zorla="' + esc(c.id) + '"><label>Ek gerekçe (isteğe bağlı)</label><input name="gerekce" maxlength="200"><button class="btn altin" type="submit">Zorla getir ve gözaltına al</button><small>Son: ' + esc(saat(c.zorla_son)) + '</small></form>' : '') +
        ((c.durum === "bekliyor" || c.durum === "gelmedi" || c.durum === "reddetti") ? '<button class="btn ikinci" type="button" data-if-iptal="' + esc(c.id) + '">Çağrıyı iptal et</button>' : '') +
        '</div>';
    });
    return h + '</div>';
  }

  async function ekle() {
    var kok = document.getElementById("gzEkran"); if (!kok || kok.querySelector("#ifBolum")) return;
    var v; try { v = await yukle(true); } catch (e) { return; }
    kok = document.getElementById("gzEkran"); if (!kok || kok.querySelector("#ifBolum")) return;
    var acik = acikBenim(v), h = '<div id="ifBolum">' + acik.map(benimHtml).join("");
    var gecmis = (v.benim || []).filter(function (c) { return acik.indexOf(c) < 0; });
    if (gecmis.length) h += '<div class="kart"><h3>İfade çağrılarım</h3>' + gecmis.map(function (c) { return '<div class="gz-satir"><span>#' + esc(c.id) + ' · ' + esc(c.makam) + '</span><span>' + etiket(c.durum) + '</span></div>'; }).join("") + '</div>';
    if (v.yetkili) h += yetkiliHtml(v);
    h += '</div>';
    if (acik.length) kok.insertAdjacentHTML("afterbegin", h);
    else { var y = kok.querySelector('[data-gz-karar]'); var kart = y && y.closest(".kart"); if (kart) kart.insertAdjacentHTML("beforebegin", h); else kok.insertAdjacentHTML("beforeend", h); }
  }

  async function islem(btn, fn, mesaj) {
    if (btn) btn.disabled = true;
    try { await fn(); toast(mesaj); ST.z = 0; if (typeof gozaltiMerkeziEkrani === "function") gozaltiMerkeziEkrani(); }
    catch (err) { hata(err); if (btn) btn.disabled = false; }
  }
  document.addEventListener("submit", function (ev) {
    var f = ev.target; if (!f || !f.closest || !f.closest("#ifBolum")) return;
    ev.preventDefault();
    var d = new FormData(f), b = f.querySelector('button[type="submit"]');
    if (f.hasAttribute("data-if-cagir")) {
      var kad = String(d.get("kad") || "").trim();
      if (!window.confirm(kad + " ifadeye çağrılsın mı?")) return;
      islem(b, function () { return rpc("ifade_cagir", { p_kad: kad, p_konu: String(d.get("konu") || "").trim(), p_sure_saat: Number(d.get("sure")) }); }, kad + " ifadeye çağrıldı.");
    } else if (f.hasAttribute("data-if-ver")) {
      islem(b, function () { return rpc("ifade_ver", { p_id: Number(f.getAttribute("data-if-ver")), p_metin: String(d.get("metin") || "").trim() }); }, "İfadeniz iletildi.");
    } else if (f.hasAttribute("data-if-red")) {
      if (!window.confirm("Çağrıyı reddederseniz zorla getirilip gözaltına alınabilirsiniz. Emin misiniz?")) return;
      islem(b, function () { return rpc("ifade_reddet", { p_id: Number(f.getAttribute("data-if-red")), p_gerekce: String(d.get("gerekce") || "").trim() || null }); }, "Çağrıyı reddettiniz.");
    } else if (f.hasAttribute("data-if-zorla")) {
      if (!window.confirm("Zorla getirme kararıyla oyuncu gözaltına alınacak. Onaylıyor musunuz?")) return;
      islem(b, function () { return rpc("ifade_zorla_getir", { p_id: Number(f.getAttribute("data-if-zorla")), p_gerekce: String(d.get("gerekce") || "").trim() || null }); }, "Zorla getirme kararı verildi; oyuncu gözaltına alındı.");
    }
  }, true);
  document.addEventListener("click", function (ev) {
    var t = ev.target.closest && ev.target.closest("[data-if-iptal],[data-if-ac]"); if (!t) return;
    ev.preventDefault();
    if (t.hasAttribute("data-if-ac")) { if (typeof gozaltiMerkeziEkrani === "function") ekranAc(gozaltiMerkeziEkrani); return; }
    if (!window.confirm("İfade çağrısı iptal edilsin mi?")) return;
    islem(t, function () { return rpc("ifade_iptal", { p_id: Number(t.getAttribute("data-if-iptal")) }); }, "Çağrı iptal edildi.");
  }, true);

  // Her ekranda: açık çağrı varsa ince şerit
  function serit() {
    var ic = document.getElementById("icerik"), eski = document.getElementById("ifSerit");
    var acik = acikBenim(ST.v).filter(function (c) { return c.durum !== "zorla_getirildi"; });
    if (!ic || !acik.length || document.getElementById("gzEkran")) { if (eski) eski.remove(); return; }
    var c = acik[0], anah = c.id + "|" + c.durum;
    if (eski && eski.getAttribute("data-a") === anah && eski.nextElementSibling === ic) return;
    if (eski) eski.remove();
    ic.insertAdjacentHTML("beforebegin", '<div id="ifSerit" data-a="' + esc(anah) + '" style="display:flex;align-items:center;gap:10px;border-radius:14px;padding:10px 12px;margin:6px 10px;background:linear-gradient(110deg,#4a3818,#1b2142);border:1px solid rgba(242,179,61,.6);color:#fff">' +
      '<span style="flex:1;min-width:0;font-size:14px;line-height:1.4"><b style="display:block;font-size:15px">' + (c.durum === "bekliyor" ? "İfadeye çağrıldınız · " + esc(kalan(c.son)) + " kaldı" : "İfade süreniz doldu") + '</b>' +
      (c.durum === "bekliyor" ? "Süresinde ifade vermezseniz zorla getirilebilirsiniz." : "Zorla getirilmeden önce hâlâ ifade verebilirsiniz.") + '</span>' +
      '<button type="button" data-if-ac style="flex:0 0 auto;min-height:44px;padding:0 12px;border-radius:12px;border:0;background:#f2b33d;color:#2a1a08;font-weight:800;font-size:14px">Aç</button></div>');
  }
  function sar() {
    var once = window.iskelet; if (typeof once !== "function" || once.__if) return;
    var yeni = function (baslik) {
      var r = once.apply(this, arguments);
      try { if (baslik === "Gözaltı ve Avukat") setTimeout(ekle, 0); serit(); } catch (e) {}
      return r;
    };
    yeni.__if = true;
    for (var k in once) if (Object.prototype.hasOwnProperty.call(once, k)) yeni[k] = once[k];
    window.iskelet = yeni; try { iskelet = yeni; } catch (e) {}
  }
  function yokla() {
    sar();
    if (document.hidden || typeof D === "undefined" || !(D.durum && D.durum.profil)) return;
    yukle(true).then(serit).catch(function () {});
  }
  sar(); setTimeout(sar, 3000); setTimeout(yokla, 3500); setInterval(yokla, 120000);
  document.addEventListener("visibilitychange", function () { if (!document.hidden) setTimeout(yokla, 800); });
  window.ifadeCagrilariYenile = function () { return yukle(true).then(serit); };
})();
