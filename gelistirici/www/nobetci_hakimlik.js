/* 21.11.2026 · Nöbetçi hâkimlik (Gözaltı ve Avukat ekranına eklenir)
   • Cumhurbaşkanı / İçişleri Bakanı: gözaltındakini suçlama ve delille nöbetçi hâkimliğe sevk eder.
   • Şüpheli ya da avukatı: savunma yazar.
   • Yüksek Mahkeme üyesi (nöbetçi hâkim): serbest bırakma · adli kontrol · tutuklama. Ceza/beraat açılan davada verilir.
   Yetkiler sunucuda denetlenir (nobetci_* RPC'leri). */
(function () {
  "use strict";
  if (window.SO_NOBETCI_V1) return;
  window.SO_NOBETCI_V1 = true;
  var ST = { v: null, z: 0 };
  var SUC = { hakaret: "Hakaret", iftira: "İftira", rusvet: "Rüşvet", yolsuzluk: "Yolsuzluk", usulsuzluk: "Usulsüzlük", dolandiricilik: "Dolandırıcılık", diger: "Diğer" };
  var DURUM = { bekliyor: ["Karar bekleniyor", "#f2b33d"], serbest: ["Serbest bırakıldı", "#34c98a"], adli_kontrol: ["Adli kontrol", "#6ea8ff"],
    tutuklama: ["Tutuklama", "#f0454b"], sure_doldu: ["Süre doldu · serbest", "#98a4c4"], dustu: ["Dosya düştü", "#98a4c4"] };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function rpc(fn, a) { return API.rpc(fn, a || {}); }
  function hata(err) { var m = (err && err.message) || String(err); if (typeof hataCevir === "function") m = hataCevir(m); toast(m, true); }
  function saat(t) { try { return new Date(t).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) { return ""; } }
  function kalan(t) { var ms = new Date(t).getTime() - Date.now(); if (!(ms > 0)) return "süre doldu"; var dk = Math.ceil(ms / 60000), sa = Math.floor(dk / 60); return (sa ? sa + " sa " : "") + (dk % 60) + " dk"; }
  function etiket(d) { var x = DURUM[d] || [d, "#98a4c4"]; return '<span class="gz-etiket" style="background:' + x[1] + '26;color:' + x[1] + '">' + esc(x[0]) + '</span>'; }
  function makam(m) { return m === "cumhurbaskani" ? "Cumhurbaşkanlığı" : "İçişleri Bakanlığı"; }
  function acik(t) { return t && new Date(t).getTime() > Date.now(); }

  async function yukle(zorla) {
    if (!zorla && ST.v && Date.now() - ST.z < 60000) return ST.v;
    ST.v = await rpc("nobetci_panel"); ST.z = Date.now(); return ST.v;
  }

  function iddiaHtml(d) {
    return '<p class="kucuk" style="margin:8px 0 0"><b>Suçlama (' + esc(SUC[d.suc_tur] || d.suc_tur) + '):</b></p><div class="gz-aciklama" style="white-space:pre-wrap">' + esc(d.iddia) + '</div>' +
      (d.delil ? '<p class="kucuk" style="margin:8px 0 0"><b>Delil:</b></p><div class="gz-aciklama" style="white-space:pre-wrap">' + esc(d.delil) + '</div>' : '');
  }
  function savunmaForm(id, mevcut, kimin) {
    return '<form data-nh-savunma="' + esc(id) + '"><label>' + esc(kimin) + '</label>' +
      '<textarea name="metin" minlength="20" maxlength="3000" required placeholder="Suçlamaya karşı savunmanızı yazın. Hâkim kararını bu savunmayı okuyarak verir.">' + esc(mevcut || "") + '</textarea>' +
      '<button class="btn altin" type="submit">' + (mevcut ? "Savunmayı güncelle" : "Savunmayı sun") + '</button></form>';
  }

  // Şüphelinin kendi dosyası
  function dosyamHtml(d, sure) {
    if (d.durum === "bekliyor" && acik(d.son)) {
      return '<div class="gz-kapak" style="background:radial-gradient(120% 90% at 100% 0%,rgba(110,168,255,.25),transparent 60%),linear-gradient(170deg,#15203a,#141a33);border-color:rgba(110,168,255,.5)">' +
        '<h2>Nöbetçi hâkimliğe sevk edildiniz</h2><div class="kucuk">' + esc(makam(d.makam)) + ' · ' + esc(d.sevk_eden) + ' · Sevk #' + esc(d.id) + ' · Nöbetçi hâkim: ' + esc(d.nobetci || "—") + '</div>' +
        '<div class="gz-sayac" data-gz-bitis="' + esc(d.son) + '">' + esc(kalan(d.son)) + '</div><div class="kucuk">içinde karar verilir · son ' + esc(saat(d.son)) + '</div></div>' +
        '<div class="kart"><h3>Sevk dosyanız</h3>' + iddiaHtml(d) +
        '<div class="gz-uyari">Hâkim üç karardan birini verir: <b>serbest bırakma</b>, <b>adli kontrol</b> (serbest kalır, tutuksuz yargılanırsınız) ya da <b>tutuklama</b> (' + esc(sure.tutukluluk_saat) + ' saat daha, tutuklu yargılanırsınız). Süresinde karar çıkmazsa serbest kalırsınız. Ceza ya da beraat bu aşamada verilmez; açılacak davada mahkeme karar verir.</div>' +
        savunmaForm(d.id, d.savunma, "Savunmanız") + '</div>';
    }
    var h = '<div class="kart"><h3>Nöbetçi hâkimlik dosyanız · #' + esc(d.id) + '</h3>' + etiket(d.durum) +
      (d.hakim ? '<span class="gz-etiket">Hâkim: ' + esc(d.hakim) + '</span>' : '') + (d.karar_at ? '<span class="gz-etiket">' + esc(saat(d.karar_at)) + '</span>' : '');
    if (d.durum === "tutuklama" && acik(d.tutukluluk_bitis)) h += '<div class="gz-uyari">Tutukluluğunuz ' + esc(saat(d.tutukluluk_bitis)) + ' tarihine kadar sürer (' + esc(kalan(d.tutukluluk_bitis)) + '). Cumhurbaşkanı ya da İçişleri Bakanı sizi daha önce tahliye edebilir.</div>';
    if (d.gerekce) h += '<p class="kucuk" style="margin:8px 0 0"><b>Karar gerekçesi:</b></p><div class="gz-aciklama" style="white-space:pre-wrap">' + esc(d.gerekce) + '</div>';
    if (d.dava_id) h += '<p>Yargılama <b>dava #' + esc(d.dava_id) + '</b> dosyasında sürüyor. Savunmanızı Adliye ekranından yazabilir ya da avukat tutabilirsiniz.</p>';
    return h + '</div>';
  }

  function muvekkilHtml(ls) {
    if (!ls.length) return "";
    var h = '<div class="kart"><h3>Müvekkil sevk dosyaları (' + ls.length + ')</h3>';
    ls.forEach(function (d) {
      h += '<div class="gz-dosya"><h4>' + esc(d.hedef) + '</h4><span class="gz-etiket">Sevk #' + esc(d.id) + '</span><span class="gz-etiket" data-gz-bitis-kisa="' + esc(d.son) + '">' + esc(kalan(d.son)) + ' kaldı</span>' +
        iddiaHtml(d) + savunmaForm(d.id, d.savunma, "Müvekkiliniz adına savunma") + '</div>';
    });
    return h + '</div>';
  }

  function hakimHtml(v) {
    var ls = v.hakim_dosyalari || [], s = v.sureler || {};
    var h = '<div class="kart" style="border:1px solid rgba(110,168,255,.6)"><h3>Nöbetçi hâkimlik (' + ls.length + ')</h3>' +
      '<p>Bugünün nöbetçi hâkimi: <b>' + esc(v.nobetci_hakim || "—") + '</b>. Sevk edilen dosyaya ilk ' + esc(s.oncelik_dk) + ' dakika yalnız nöbetçi hâkim bakar; sonra diğer üyeler de karar verebilir. Süresinde karar çıkmazsa şüpheli serbest kalır.</p>';
    if (!ls.length) h += '<p>Karar bekleyen sevk dosyası yok.</p>';
    ls.forEach(function (d) {
      h += '<div class="gz-dosya"><h4>' + esc(d.hedef) + '</h4><span class="gz-etiket">Sevk #' + esc(d.id) + ' · ' + esc(makam(d.makam)) + ' · ' + esc(d.sevk_eden) + '</span>' +
        '<span class="gz-etiket" data-gz-bitis-kisa="' + esc(d.son) + '">' + esc(kalan(d.son)) + ' kaldı</span>' +
        (d.nobetci_benim ? '<span class="gz-etiket yesil">Nöbetçi sizsiniz</span>' : '<span class="gz-etiket">Nöbetçi: ' + esc(d.nobetci || "—") + '</span>') +
        (d.gozalti_gerekce ? '<p class="kucuk" style="margin:8px 0 0">Gözaltı gerekçesi: ' + esc(d.gozalti_gerekce) + '</p>' : '') + iddiaHtml(d) +
        (d.savunma ? '<p class="kucuk" style="margin:8px 0 0"><b>Savunma (' + esc(d.savunma_yazan || "") + '):</b></p><div class="gz-aciklama" style="white-space:pre-wrap">' + esc(d.savunma) + '</div>'
          : '<p class="kucuk" style="margin:8px 0 0">Henüz savunma sunulmadı.</p>');
      if (!d.bakabilir) h += '<div class="gz-uyari">Çıkar çatışması: bu dosyaya bakamazsınız.</div>';
      else h += '<form data-nh-karar="' + esc(d.id) + '"><label>Karar</label><select name="karar" required>' +
        '<option value="">Karar seçin</option><option value="serbest">Serbest bırakma</option><option value="adli_kontrol">Adli kontrol (tutuksuz yargılama, dava açılır)</option>' +
        '<option value="tutuklama">Tutuklama (' + esc(s.tutukluluk_saat) + ' saat, dava açılır)</option></select>' +
        '<label>Gerekçe</label><textarea name="gerekce" minlength="25" maxlength="2000" required placeholder="Kararınızın hukuki gerekçesi (en az 25 karakter). Gerekçe şüpheliye ve sevk eden makama bildirilir."></textarea>' +
        '<button class="btn altin" type="submit">Kararı ver</button><small>Ceza ya da beraat bu aşamada verilmez; adli kontrol ve tutuklamada dava kendiliğinden açılır.</small></form>';
      h += '</div>';
    });
    return h + '</div>';
  }

  function sevkHtml(v) {
    var ls = v.sevk_edilebilir || [], s = v.sureler || {};
    var h = '<div class="kart" style="border:1px solid rgba(242,179,61,.6)"><h3>Nöbetçi hâkimliğe sevk</h3>' +
      '<p>Gözaltındaki oyuncuyu suçlama ve delille nöbetçi hâkimliğe sevk edebilirsiniz. Hâkim ' + esc(s.sorgu_saat) + ' saat içinde serbest bırakma, adli kontrol ya da tutuklama kararı verir; adli kontrol ve tutuklamada dava açılır. Sevk etmezseniz oyuncu gözaltı süresi dolunca serbest kalır. Bir gözaltı yalnız bir kez sevk edilir.</p>';
    if (!ls.length) h += '<p>Sevk edilebilecek devam eden gözaltı yok.</p>';
    ls.forEach(function (g) {
      h += '<div class="gz-dosya"><h4>' + esc(g.hedef) + '</h4><span class="gz-etiket">Gözaltı #' + esc(g.id) + '</span><span class="gz-etiket" data-gz-bitis-kisa="' + esc(g.bitis) + '">' + esc(kalan(g.bitis)) + ' kaldı</span>' +
        '<p class="kucuk" style="margin:8px 0 0">Gözaltı gerekçesi: ' + esc(g.gerekce) + '</p>';
      if (g.sevk) h += '<p>' + etiket(g.sevk.durum) + '<span class="gz-etiket">Sevk #' + esc(g.sevk.id) + '</span></p>';
      else h += '<details><summary>Nöbetçi hâkimliğe sevk et</summary><form data-nh-sevk="' + esc(g.id) + '" data-nh-kad="' + esc(g.hedef) + '">' +
        '<label>Suçlama türü</label><select name="tur" required>' + (v.suc_turleri || []).map(function (k) { return '<option value="' + esc(k) + '">' + esc(SUC[k] || k) + '</option>'; }).join("") + '</select>' +
        '<label>Suçlama (ne yaptığı iddia ediliyor)</label><textarea name="iddia" minlength="20" maxlength="3000" required placeholder="Olayı, tarihini ve suç oluşturduğunu düşündüğünüz davranışı yazın."></textarea>' +
        '<label>Delil (isteğe bağlı)</label><textarea name="delil" maxlength="3000" style="min-height:70px" placeholder="Paylaşım, tanık, belge…"></textarea>' +
        '<button class="btn altin" type="submit">Nöbetçi hâkimliğe sevk et</button></form></details>';
      h += '</div>';
    });
    return h + '</div>';
  }

  function sonHtml(ls) {
    if (!ls.length) return "";
    return '<div class="kart"><h3>Son nöbetçi hâkimlik kararları</h3>' + ls.map(function (d) {
      return '<div class="gz-satir"><span>#' + esc(d.id) + ' · ' + esc(d.hedef) + ' · ' + esc(SUC[d.suc_tur] || d.suc_tur) + '</span><span>' + etiket(d.durum) + (d.dava_id ? ' <span class="gz-etiket">Dava #' + esc(d.dava_id) + '</span>' : '') + '</span></div>';
    }).join("") + '</div>';
  }

  async function ekle() {
    var kok = document.getElementById("gzEkran"); if (!kok || kok.querySelector("#nhBolum")) return;
    var v; try { v = await yukle(true); } catch (e) { return; }
    kok = document.getElementById("gzEkran"); if (!kok || kok.querySelector("#nhBolum")) return;
    var d = v.dosyam, ust = d && d.durum === "bekliyor" && acik(d.son);
    var h = '<div id="nhBolum">';
    if (d) h += dosyamHtml(d, v.sureler || {});
    h += muvekkilHtml(v.muvekkil_dosyalari || []);
    if (v.hakim_mi) h += hakimHtml(v);
    if (v.sevk_yetkisi) h += sevkHtml(v);
    h += sonHtml(v.son_kararlar || []) + '</div>';
    if (h === '<div id="nhBolum"></div>') return;
    if (ust || (v.hakim_mi && (v.hakim_dosyalari || []).length)) kok.insertAdjacentHTML("afterbegin", h);
    else kok.insertAdjacentHTML("beforeend", h);
  }

  async function islem(btn, fn, mesaj) {
    if (btn) btn.disabled = true;
    try {
      var r = await fn();
      if (r && r.tamam === false) toast(r.mesaj || "İşlem yapılamadı.", true); else toast(mesaj);
      ST.z = 0; if (typeof gozaltiMerkeziEkrani === "function") gozaltiMerkeziEkrani();
    } catch (err) { hata(err); if (btn) btn.disabled = false; }
  }
  document.addEventListener("submit", function (ev) {
    var f = ev.target; if (!f || !f.closest || !f.closest("#nhBolum")) return;
    ev.preventDefault(); ev.stopPropagation();
    var d = new FormData(f), b = f.querySelector('button[type="submit"]');
    if (f.hasAttribute("data-nh-sevk")) {
      var kad = f.getAttribute("data-nh-kad") || "Oyuncu";
      if (!window.confirm(kad + " nöbetçi hâkimliğe sevk edilsin mi? Bu gözaltı bir daha sevk edilemez.")) return;
      islem(b, function () { return rpc("nobetci_sevk_et", { p_kaynak: "yonetim", p_id: Number(f.getAttribute("data-nh-sevk")), p_tur: String(d.get("tur") || ""), p_iddia: String(d.get("iddia") || "").trim(), p_delil: String(d.get("delil") || "").trim() }); }, kad + " nöbetçi hâkimliğe sevk edildi.");
    } else if (f.hasAttribute("data-nh-savunma")) {
      islem(b, function () { return rpc("nobetci_savunma", { p_sevk: Number(f.getAttribute("data-nh-savunma")), p_metin: String(d.get("metin") || "").trim() }); }, "Savunma hâkime sunuldu.");
    } else if (f.hasAttribute("data-nh-karar")) {
      var k = String(d.get("karar") || ""), ad = { serbest: "Serbest bırakma", adli_kontrol: "Adli kontrol", tutuklama: "Tutuklama" }[k];
      if (!ad) { toast("Karar seçin.", true); return; }
      if (!window.confirm(ad + " kararı verilsin mi? Karar geri alınamaz.")) return;
      islem(b, function () { return rpc("nobetci_karar", { p_sevk: Number(f.getAttribute("data-nh-karar")), p_karar: k, p_gerekce: String(d.get("gerekce") || "").trim() }); }, "Karar verildi: " + ad + ".");
    }
  }, true);
  document.addEventListener("click", function (ev) {
    var t = ev.target.closest && ev.target.closest("[data-nh-ac]"); if (!t) return;
    ev.preventDefault();
    if (typeof gozaltiMerkeziEkrani === "function") ekranAc(gozaltiMerkeziEkrani);
  }, true);

  // Her ekranda ince şerit: nöbetçi hâkime bekleyen dosya, şüpheliye sevk
  function serit() {
    var ic = document.getElementById("icerik"), eski = document.getElementById("nhSerit"), v = ST.v;
    var hd = v && v.hakim_mi ? (v.hakim_dosyalari || []).filter(function (d) { return d.bakabilir && acik(d.son); }) : [];
    var bas = "", alt = "", anah = "";
    if (hd.length) { bas = "Nöbetçi hâkimlik: " + hd.length + " dosya karar bekliyor"; alt = "İlk dosyada " + kalan(hd[0].son) + " kaldı; karar çıkmazsa şüpheli serbest kalır."; anah = "h" + hd.length + "|" + hd[0].id; }
    if (!ic || !bas || document.getElementById("gzEkran")) { if (eski) eski.remove(); return; }
    if (eski && eski.getAttribute("data-a") === anah && eski.nextElementSibling === ic) return;
    if (eski) eski.remove();
    ic.insertAdjacentHTML("beforebegin", '<div id="nhSerit" data-a="' + esc(anah) + '" style="display:flex;align-items:center;gap:10px;border-radius:14px;padding:10px 12px;margin:6px 10px;background:linear-gradient(110deg,#16305a,#1b2142);border:1px solid rgba(110,168,255,.6);color:#fff">' +
      '<span style="flex:1;min-width:0;font-size:14px;line-height:1.4"><b style="display:block;font-size:15px">' + esc(bas) + '</b>' + esc(alt) + '</span>' +
      '<button type="button" data-nh-ac style="flex:0 0 auto;min-height:44px;padding:0 12px;border-radius:12px;border:0;background:#6ea8ff;color:#0b1430;font-weight:800;font-size:14px">Aç</button></div>');
  }
  function sar() {
    var once = window.iskelet; if (typeof once !== "function" || once.__nh) return;
    var yeni = function (baslik) {
      var r = once.apply(this, arguments);
      try { if (baslik === "Gözaltı ve Avukat") setTimeout(ekle, 0); serit(); } catch (e) {}
      return r;
    };
    yeni.__nh = true;
    for (var k in once) if (Object.prototype.hasOwnProperty.call(once, k)) yeni[k] = once[k];
    window.iskelet = yeni; try { iskelet = yeni; } catch (e) {}
  }
  function yokla() {
    sar();
    if (document.hidden || typeof D === "undefined" || !(D.durum && D.durum.profil)) return;
    // Yük koruması: şerit yalnız hâkimler içindir; hâkim olmayan oyuncu 30 dakikada bir yoklar (ekranı açınca zaten tazelenir).
    if (ST.v && !ST.v.hakim_mi && Date.now() - ST.z < 1800000) return;
    yukle(true).then(serit).catch(function () {});
  }
  sar(); setTimeout(sar, 3200); setTimeout(yokla, 4200); setInterval(yokla, 180000);
})();
