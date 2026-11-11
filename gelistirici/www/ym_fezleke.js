/* 11.11.2026 · Yüksek Mahkeme fezlekesi → TBMM → Meclis soruşturması → Yüce Divan.
   Arka uç: sql/183_ym_fezleke_meclis.sql (ym_fezleke_* RPC'leri).
   Adliye ekranına (Yüksek Mahkeme üyeleri yazar/imzalar) ve Meclis › Yasama sekmesine
   (vekiller önerge imzalar, gizli oy kullanır; ilgili bakan savunma verir) bölüm ekler. */
(function () {
  "use strict";
  if (window.SO_YM_FEZLEKE_V1) return;
  window.SO_YM_FEZLEKE_V1 = true;

  var ACIK = { imza: 1, onerge: 1, oylama1: 1, komisyon: 1, oylama2: 1 };
  var ADIMLAR = [["imza", "Mahkeme"], ["onerge", "Önerge"], ["oylama1", "Soruşturma"], ["komisyon", "Komisyon"], ["oylama2", "Yüce Divan"]];
  var SON = null;

  function k(x) { return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function para(x) { return k(x).replace(/\n{2,}/g, "</p><p>").replace(/\n/g, "<br>"); }
  function tarih(x) { try { return x ? new Date(x).toLocaleString("tr-TR", { day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" }) : "—"; } catch (_) { return "—"; } }
  function kalan(x) {
    if (!x) return "";
    var ms = new Date(x) - Date.now(); if (ms <= 0) return "süre doldu";
    var s = Math.floor(ms / 36e5); return s >= 24 ? Math.floor(s / 24) + " gün " + (s % 24) + " sa kaldı" : s + " sa " + Math.floor((ms % 36e5) / 6e4) + " dk kaldı";
  }
  function hata(err) { toast(typeof hataCevir === "function" ? hataCevir(err && err.message || String(err)) : String(err && err.message || err), true); }
  async function panel() { var v = await API.rpc("ym_fezleke_panel"); SON = v; return v; }
  function stil() {
    if (document.getElementById("ymfStil")) return;
    var s = document.createElement("style"); s.id = "ymfStil";
    s.textContent = ".ymf-adim{display:flex;gap:4px;margin:12px 0 6px}.ymf-adim>div{flex:1;min-width:0;text-align:center}.ymf-adim i{display:block;height:4px;border-radius:3px;background:var(--line2,#2a3350)}"
      + ".ymf-adim>div.tamam i{background:var(--ink2,#a99bff)}.ymf-adim>div.simdi i{background:var(--v5-altin,#d9b45b)}.ymf-adim span{display:block;font-size:11px;color:var(--faint,#7c849d);margin-top:5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}"
      + ".ymf-adim>div.simdi span{color:var(--txt,#fff);font-weight:650}.ymf-dosya{margin-top:12px;padding:14px;overflow-wrap:anywhere;cursor:pointer}"
      + ".ymf-ust{display:flex;align-items:flex-start;gap:10px}.ymf-ust .orta{flex:1;min-width:0}.ymf-ust b{display:block;font-size:16px;line-height:1.3}"
      + ".ymf-rozet{display:inline-block;font-size:12px;font-weight:650;padding:3px 9px;border-radius:999px;background:rgba(217,180,91,.14);color:#F1D48A;margin-top:6px}"
      + ".ymf-rozet.bitti{background:rgba(255,255,255,.06);color:var(--txt2,#c9cfdf)}.ymf-rozet.ret{background:rgba(239,67,73,.12);color:#ff9a9e}.ymf-rozet.sevk{background:rgba(125,255,191,.12);color:#8ff0c0}"
      + ".ymf-metin{font-size:15px;line-height:1.6;color:var(--txt,#f4f6fb)}.ymf-metin p{margin:0 0 10px}.ymf-baslik{font-size:12.5px;font-weight:750;letter-spacing:.08em;text-transform:uppercase;color:var(--txt2,#c9cfdf);margin:16px 0 6px}"
      + "#ymfIsnat,#ymfDelil,#ymfHukuki,#ymfSav,#ymfBaslik,#ymfHedef{width:100%;box-sizing:border-box;display:block}"
      + ".ymf-sayac{font-size:12.5px;color:var(--faint,#7c849d);text-align:right;margin-top:-6px;margin-bottom:8px}.ymf-oy{display:flex;gap:8px}.ymf-oy .btn{flex:1;margin:0!important}";
    document.head.appendChild(s);
  }
  function adimHtml(d) {
    var i = ADIMLAR.findIndex(function (a) { return a[0] === d; });
    if (d === "yuce_divan") i = ADIMLAR.length;
    return '<div class="ymf-adim">' + ADIMLAR.map(function (a, j) {
      return '<div class="' + (i < 0 ? "" : j < i ? "tamam" : j === i ? "simdi" : "") + '"><i></i><span>' + a[1] + "</span></div>";
    }).join("") + "</div>";
  }
  function rozet(f) {
    var c = f.durum === "yuce_divan" ? "sevk" : f.durum === "ret" ? "ret" : ACIK[f.durum] ? "" : "bitti";
    return '<span class="ymf-rozet ' + c + '">' + k(f.durum_ad) + (ACIK[f.durum] && f.asama_bit ? " · " + k(kalan(f.asama_bit)) : "") + "</span>";
  }
  function ozet(f, v) {
    if (f.durum === "imza") return "Yüksek Mahkeme imzaları: " + (f.imzalar || []).length + " / " + (v.imza_gerek || 1);
    if (f.durum === "onerge") return "Soruşturma önergesi: " + Number(f.onerge_imza || 0) + " / " + v.esik.onerge + " vekil imzası";
    if (f.durum === "oylama1") return "Gizli oylama · katılım " + Number(f.katilim || 0) + " · kabul için " + v.esik.sorusturma + " oy (3/5)";
    if (f.durum === "komisyon") return "Soruşturma Komisyonu incelemesi" + (f.savunma ? " · savunma verildi" : " · savunma bekleniyor");
    if (f.durum === "oylama2") return "Gizli oylama · katılım " + Number(f.katilim || 0) + " · sevk için " + v.esik.sevk + " oy (2/3)";
    return f.sonuc || "";
  }
  function kartHtml(f, v) {
    return '<article class="kart ymf-dosya" onclick="ymFezlekeAc(' + Number(f.id) + ')">'
      + '<div class="ymf-ust"><div class="orta"><div class="kucuk">Fezleke #' + Number(f.id) + " · " + k(f.makam) + "</div><b>" + k(f.baslik) + "</b>"
      + '<div class="kucuk" style="margin-top:4px">Hakkında: <b style="display:inline;font-size:inherit">' + k(f.bakan) + "</b></div>" + rozet(f) + "</div></div>"
      + (f.durum === "ret" || f.durum === "dusmus" || f.durum === "geri_cekildi" ? "" : adimHtml(f.durum))
      + '<div class="kucuk">' + k(ozet(f, v)) + "</div>"
      + (f.imzalayabilirim || f.onerge_imzalayabilirim || f.oy_verebilirim || (f.savunabilirim && !f.savunma)
        ? '<div class="kucuk" style="color:var(--v5-altin2,#f1d48a);margin-top:6px;font-weight:650">İşlem bekliyor · dosyayı aç</div>' : "")
      + "</article>";
  }

  /* ---------------- Adliye: Yüksek Mahkeme ---------------- */
  if (typeof window.adliyeHtml === "function") {
    var eskiAdliye = window.adliyeHtml;
    window.adliyeHtml = async function () {
      var ana = await eskiAdliye.apply(this, arguments), v;
      try { v = await panel(); } catch (err) { console.warn("Fezlekeler okunamadı", err); return ana; }
      stil();
      var liste = v.dosyalar || [];
      if (!v.ym_uyesi && !liste.length) return ana;
      var h = '<section class="kart" aria-label="Yüksek Mahkeme fezlekeleri"><h3>⚖️ Fezlekeler · Yüksek Mahkeme → TBMM</h3>'
        + '<p class="alt">Görevdeki bir bakan ya da Cumhurbaşkanı Yardımcısı hakkında görevle ilgili suç isnadı varsa Yüksek Mahkeme fezleke düzenler. '
        + "Üyelerin çoğunluğu imzalayınca fezleke TBMM'ye gider; Meclis soruşturması ve Yüce Divan'a sevk kararını milletvekilleri verir.</p>"
        + (v.ym_uyesi ? '<button class="btn altin" style="margin-top:4px" onclick="ymFezlekeYaz()">Fezleke yaz</button>' : "")
        + (liste.length ? liste.slice(0, 12).map(function (f) { return kartHtml(f, v); }).join("") : '<div class="bos" style="margin-top:12px">Henüz fezleke yok.</div>')
        + "</section>";
      return h + ana;
    };
  }

  /* ---------------- Meclis › Yasama ---------------- */
  function yasamaBagla() {
    if (typeof window.meclisYasamaHtml !== "function" || window.meclisYasamaHtml._ymf) return !!(window.meclisYasamaHtml && window.meclisYasamaHtml._ymf);
    var eski = window.meclisYasamaHtml;
    var yeni = async function () {
      var ana = await eski.apply(this, arguments), v;
      try { v = await panel(); } catch (err) { return ana; }
      stil();
      var l = (v.dosyalar || []).filter(function (f) { return f.durum !== "imza" && f.durum !== "geri_cekildi"; });
      var acik = l.filter(function (f) { return ACIK[f.durum]; }), biten = l.filter(function (f) { return !ACIK[f.durum]; });
      var h = '<div class="kart"><h2>Fezlekeler · Meclis soruşturması</h2>'
        + '<p class="alt">Yüksek Mahkeme fezlekesi üzerine: önerge için ' + v.esik.onerge + " imza (salt çoğunluk), soruşturma açılması için "
        + v.esik.sorusturma + " oy (3/5), Yüce Divan'a sevk için " + v.esik.sevk + " oy (2/3). Oranlar " + v.dolu + " dolu sandalyeye göre; oylama gizlidir. Yüce Divan'a sevk edilen bakan görevden düşer.</p>"
        + (acik.length ? acik.map(function (f) { return kartHtml(f, v); }).join("") : '<div class="bos" style="margin-top:10px">Meclis gündeminde fezleke yok.</div>')
        + (biten.length ? '<div class="ymf-baslik">Sonuçlananlar</div>' + biten.slice(0, 8).map(function (f) { return kartHtml(f, v); }).join("") : "")
        + "</div>";
      return acik.length ? h + ana : ana + h;
    };
    yeni._ymf = true;
    window.meclisYasamaHtml = yeni;
    try { meclisYasamaHtml = yeni; } catch (_) {}
    return true;
  }
  if (!yasamaBagla()) setTimeout(yasamaBagla, 1500);

  /* ---------------- Dosya ayrıntısı ---------------- */
  async function yenile() {
    try {
      if (typeof D !== "undefined" && D.sekme === "meclis" && typeof meclisEkrani === "function") return await meclisEkrani();
      if (typeof adliyeEkrani === "function" && typeof D !== "undefined" && D.sekme === "adliye") return await adliyeEkrani();
      if (typeof devletEkrani === "function") return await devletEkrani();
    } catch (_) {}
  }
  window.ymFezlekeAc = async function (id) {
    var v = SON; try { v = await panel(); } catch (_) {}
    var f = ((v && v.dosyalar) || []).find(function (x) { return Number(x.id) === Number(id); });
    if (!f) { toast("Dosya bulunamadı.", true); return; }
    stil();
    var islem = "";
    if (f.imzalayabilirim) islem += '<button class="btn altin" data-ymf="imzala">Fezlekeyi imzala</button>';
    if (f.geri_cekebilirim) islem += '<button class="btn ikinci" data-ymf="geri">Taslağı geri çek</button>';
    if (f.onerge_imzalayabilirim) islem += '<button class="btn altin" data-ymf="onerge">Soruşturma önergesini imzala</button>';
    else if (f.onerge_imzaladim && f.durum === "onerge") islem += '<p class="kucuk">Önergeyi imzaladın.</p>';
    if (f.oy_verebilirim) islem += '<div class="ymf-baslik">' + (f.durum === "oylama1" ? "Meclis soruşturması açılsın mı?" : "Yüce Divan'a sevk edilsin mi?") + "</div>"
      + (f.benim_oyum ? '<p class="kucuk">Oyun: <b>' + (f.benim_oyum === "kabul" ? "Kabul" : "Ret") + "</b> · süre bitene kadar değiştirebilirsin.</p>" : "")
      + '<div class="ymf-oy"><button class="btn altin" data-ymf="kabul">Kabul</button><button class="btn tehlike" data-ymf="ret">Ret</button></div>';
    if (f.savunabilirim) islem += '<button class="btn ikinci" data-ymf="savunma">' + (f.savunma ? "Savunmayı güncelle" : "Yazılı savunma ver") + "</button>";
    var oySonuc = function (o, ad) { return o ? '<div class="kv"><span class="k">' + ad + '</span><span class="v">' + o.kabul + " kabul · " + o.ret + " ret (gerekli " + o.gerek + ")</span></div>" : ""; };
    var m = modal('<div class="kucuk">Fezleke #' + Number(f.id) + " · " + k(f.makam) + "</div>"
      + '<h3 style="font-size:20px;margin:4px 0 6px">' + k(f.baslik) + "</h3>" + rozet(f)
      + (f.durum === "ret" || f.durum === "dusmus" || f.durum === "geri_cekildi" ? "" : adimHtml(f.durum))
      + '<div class="kv"><span class="k">Hakkında</span><span class="v">' + k(f.bakan) + "</span></div>"
      + '<div class="kv"><span class="k">Düzenleyen</span><span class="v">' + k(f.yazan) + "</span></div>"
      + '<div class="kv"><span class="k">İmzalayan üyeler</span><span class="v">' + k((f.imzalar || []).join(", ")) + "</span></div>"
      + (f.gonderilme ? '<div class="kv"><span class="k">TBMM\'ye gönderildi</span><span class="v">' + k(tarih(f.gonderilme)) + "</span></div>" : "")
      + (ACIK[f.durum] && f.asama_bit ? '<div class="kv"><span class="k">Aşama süresi</span><span class="v">' + k(kalan(f.asama_bit)) + "</span></div>" : "")
      + '<div class="kv"><span class="k">Durum</span><span class="v">' + k(ozet(f, v)) + "</span></div>"
      + oySonuc(f.oy1, "Soruşturma oylaması") + oySonuc(f.oy2, "Sevk oylaması")
      + (islem ? '<div style="margin:14px 0 4px;display:grid;gap:8px">' + islem + "</div>" : "")
      + '<div class="ymf-baslik">Suç isnadı ve olaylar</div><div class="ymf-metin"><p>' + para(f.isnat) + "</p></div>"
      + (f.deliller ? '<div class="ymf-baslik">Deliller</div><div class="ymf-metin"><p>' + para(f.deliller) + "</p></div>" : "")
      + '<div class="ymf-baslik">Hukuki değerlendirme ve talep</div><div class="ymf-metin"><p>' + para(f.hukuki) + "</p></div>"
      + (f.savunma ? '<div class="ymf-baslik">' + k(f.bakan) + " · yazılı savunma</div><div class=\"ymf-metin\"><p>" + para(f.savunma) + "</p></div>" : "")
      + '<button class="btn ikinci" style="margin-top:14px" onclick="modalKapat()">Kapat</button>');
    m.querySelectorAll("[data-ymf]").forEach(function (b) {
      b.onclick = async function () {
        var tur = b.getAttribute("data-ymf");
        if (tur === "savunma") { modalKapat(); return ymFezlekeSavunma(f); }
        var soru = { imzala: ["Fezlekeyi imzala", "İmzan Yüksek Mahkeme adına kayda geçer. Çoğunluk sağlanınca fezleke TBMM'ye gider."],
          geri: ["Taslağı geri çek", "Fezleke TBMM'ye gönderilmeden kapatılır."],
          onerge: ["Önergeyi imzala", "Meclis soruşturması açılması için önergeye imza veriyorsun."],
          kabul: ["Kabul oyu", "Oy gizlidir; yalnız toplam sonuç açıklanır."], ret: ["Ret oyu", "Oy gizlidir; yalnız toplam sonuç açıklanır."] }[tur];
        if (typeof onayla === "function" && !await onayla(soru[0], soru[1], soru[0], tur === "geri" || tur === "ret")) return;
        b.disabled = true;
        try {
          if (tur === "imzala") await API.rpc("ym_fezleke_imzala", { p_id: f.id });
          else if (tur === "geri") await API.rpc("ym_fezleke_geri_cek", { p_id: f.id });
          else if (tur === "onerge") await API.rpc("ym_fezleke_onerge_imzala", { p_id: f.id });
          else await API.rpc("ym_fezleke_oy", { p_id: f.id, p_oy: tur });
          modalKapat(); toast(tur === "kabul" || tur === "ret" ? "Oyun kaydedildi." : "İşlem tamam."); await yenile();
        } catch (err) { b.disabled = false; hata(err); }
      };
    });
  };

  function sayacli(id, enAz, enCok, etiket, satir, ipucu) {
    return '<div class="alan"><label for="' + id + '">' + k(etiket) + "</label><textarea id=\"" + id + '" rows="' + satir + '" maxlength="' + enCok + '" placeholder="' + k(ipucu || "") + '"></textarea></div>'
      + '<div class="ymf-sayac" data-sayac="' + id + '" data-min="' + enAz + '" data-max="' + enCok + '">0 / ' + enCok + "</div>";
  }
  function sayacBagla(m) {
    m.querySelectorAll("[data-sayac]").forEach(function (s) {
      var t = m.querySelector("#" + s.getAttribute("data-sayac")), en = +s.getAttribute("data-min"), ust = +s.getAttribute("data-max");
      var yaz = function () { var n = t.value.trim().length; s.textContent = n.toLocaleString("tr-TR") + " / " + ust.toLocaleString("tr-TR") + (n && n < en ? " · en az " + en : ""); };
      t.addEventListener("input", yaz); yaz();
    });
  }

  window.ymFezlekeYaz = async function () {
    var v = SON; try { v = await panel(); } catch (err) { return hata(err); }
    var hedef = (v.hedefler || []).filter(function (h) { return !h.acik; });
    if (!hedef.length) { toast("Hakkında fezleke yazılabilecek (açık dosyası olmayan) görevli bakan ya da CB yardımcısı yok.", true); return; }
    stil();
    var m = modal('<h3 style="font-size:20px;margin:0 0 6px">Fezleke yaz</h3>'
      + '<p class="alt">Görevle ilgili suç isnadını olaylar, deliller ve hukuki gerekçeyle yaz. Görevdeki üyelerin çoğunluğu (' + v.imza_gerek + ") imzalayınca TBMM Başkanlığına gönderilir.</p>"
      + '<div class="alan"><label for="ymfHedef">Hakkında fezleke düzenlenen</label><select id="ymfHedef">'
      + hedef.map(function (h) { return '<option value="' + k(h.kad) + '">' + k(h.kad) + " · " + k(h.makam) + "</option>"; }).join("") + "</select></div>"
      + '<div class="alan"><label for="ymfBaslik">Başlık</label><input id="ymfBaslik" maxlength="150" placeholder="Örn. İhale sürecinde görevi kötüye kullanma iddiası"></div>'
      + sayacli("ymfIsnat", 100, 8000, "Suç isnadı ve olaylar", 7, "Ne oldu, ne zaman, hangi işlemle? Olayları sırasıyla anlat.")
      + sayacli("ymfDelil", 0, 6000, "Deliller (isteğe bağlı)", 4, "Kayıtlar, işlem numaraları, tanıklar, belgeler…")
      + sayacli("ymfHukuki", 50, 6000, "Hukuki değerlendirme ve talep", 5, "İsnat edilen suçun unsurları ve Meclis soruşturması açılması talebi")
      + '<button class="btn altin" id="ymfGonder">Fezlekeyi imzala ve kaydet</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    sayacBagla(m);
    m.querySelector("#ymfGonder").onclick = async function () {
      var b = this, val = function (id) { return m.querySelector(id).value.trim(); };
      if (val("#ymfBaslik").length < 10) return toast("Başlık en az 10 karakter olmalı.", true);
      if (val("#ymfIsnat").length < 100) return toast("Suç isnadı ve olaylar en az 100 karakter olmalı.", true);
      if (val("#ymfHukuki").length < 50) return toast("Hukuki değerlendirme en az 50 karakter olmalı.", true);
      if (typeof onayla === "function" && !await onayla("Fezleke", val("#ymfHedef") + " hakkında fezleke kaydedilsin mi?", "Kaydet")) return;
      b.disabled = true;
      try {
        var r = await API.rpc("ym_fezleke_yaz", { p_hedef: val("#ymfHedef"), p_baslik: val("#ymfBaslik"), p_isnat: val("#ymfIsnat"), p_deliller: val("#ymfDelil"), p_hukuki: val("#ymfHukuki") });
        modalKapat(); toast(r && r.durum === "onerge" ? "Fezleke TBMM'ye gönderildi." : "Fezleke kaydedildi; diğer üyelerin imzası bekleniyor."); await yenile();
      } catch (err) { b.disabled = false; hata(err); }
    };
  };

  window.ymFezlekeSavunma = function (f) {
    stil();
    var m = modal('<h3 style="font-size:20px;margin:0 0 6px">Yazılı savunma</h3><p class="alt">Fezleke #' + Number(f.id) + " · savunman dosyaya eklenir ve tüm milletvekillerine açıktır.</p>"
      + sayacli("ymfSav", 20, 6000, "Savunma metni", 8, "")
      + '<button class="btn altin" id="ymfSavGonder">Savunmayı gönder</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    if (f.savunma) m.querySelector("#ymfSav").value = f.savunma;
    sayacBagla(m);
    m.querySelector("#ymfSavGonder").onclick = async function () {
      var b = this; b.disabled = true;
      try { await API.rpc("ym_fezleke_savunma", { p_id: f.id, p_metin: m.querySelector("#ymfSav").value.trim() }); modalKapat(); toast("Savunman TBMM'ye iletildi."); await yenile(); }
      catch (err) { b.disabled = false; hata(err); }
    };
  };
})();
