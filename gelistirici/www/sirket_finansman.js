/* 11.11.2026 · Şirket finansmanı arayüzü
   1) Yatırım kredisi (sql/190): Şubeler › "Şube maliyeti" planının altına kredili açılış bölümü;
      Kasa / Sermaye sekmesinde açık yatırım kredileri ve erken ödeme.
   2) Ticari ödeme (sql/189): Kasa / Sermaye sekmesinde "Ticari borçlar" (bekleyen faturaları onayla/reddet,
      cari bakiye kadar kişiye öde); Çek Merkezi'nde kişiler için "Şirkete fatura / makbuz kes". */
(function () {
  "use strict";
  if (window.SO_SIRKET_FINANSMAN_V1) return;
  window.SO_SIRKET_FINANSMAN_V1 = true;

  function k(x) { return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function tl(x) { return (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺"; }
  function kv(a, b) { return '<div class="kv"><span class="k">' + k(a) + '</span><span class="v">' + b + "</span></div>"; }
  function hata(e) { toast(typeof hataCevir === "function" ? hataCevir(e && e.message || String(e)) : String(e && e.message || e), true); }
  async function sor(b, m, d) { return typeof onayla === "function" ? onayla(b, m, d || "Onayla") : confirm(m); }
  function yuzde(x) { return "%" + Number(x || 0).toLocaleString("tr-TR", { maximumFractionDigits: 2 }); }
  var DURUM = { aktif: "Ödeniyor", gecikmede: "Gecikmede", kapandi: "Kapandı", bekliyor: "Onay bekliyor", onaylandi: "Onaylandı · ödeme bekliyor", red: "Reddedildi", iptal: "İptal", odendi: "Ödendi" };

  /* ================= 1) YATIRIM KREDİSİ ================= */
  async function krediBolumu(id, il) {
    var kap = document.getElementById("sm_sube_teklif"); if (!kap) return;
    var eski = document.getElementById("ykBolum"); if (eski) eski.remove();
    var v; try { v = await API.rpc("yatirim_kredisi_panel", { p_sirket: Number(id), p_il: Number(il) }); } catch (_) { return; }
    if (!v || !v.yonetici) return;
    var h = '<div class="kart" id="ykBolum" style="margin:10px 0"><h3>Yatırım kredisiyle aç</h3>'
      + '<p class="alt">Banka şube yatırımının en fazla %70\'ini şirketine kredi olarak finanse eder. Kredi kimsenin cüzdanına geçmez, doğrudan bu şubeye harcanır; '
      + "geri ödeme her gün şirket kasasından eşit taksitle yapılır.</p>";
    if (!v.uygun) return kap.insertAdjacentHTML("beforeend", h + '<p class="kucuk">' + k(v.neden) + "</p></div>");
    var s = v.sube; if (!s) return kap.insertAdjacentHTML("beforeend", h + '<p class="kucuk">' + k(v.sube_hata || "Bu il için plan alınamadı.") + "</p></div>");
    var azami = Number(s.azami_kredi) || 0;
    h += kv("Yatırım bedeli", tl(s.acilis)) + kv("Azami kredi (%70)", "<b>" + tl(azami) + "</b>")
      + kv("İşletme rezervi (kasada kalır)", tl(s.rezerv)) + kv("Yıllık faiz (politika faizi + 4)", yuzde(v.oran))
      + '<div class="alan" style="margin-top:10px"><label for="ykTutar">Kredi tutarı (₺)</label><input id="ykTutar" type="number" inputmode="numeric" min="10000" step="1000" max="' + azami + '" value="' + azami + '"></div>'
      + '<div class="alan"><label for="ykVade">Vade</label><select id="ykVade"><option value="30">30 gün</option><option value="60" selected>60 gün</option><option value="90">90 gün</option></select></div>'
      + '<div id="ykOzet"></div>'
      + '<button class="btn altin" id="ykAc">Kredili şube aç</button></div>';
    kap.insertAdjacentHTML("beforeend", h);
    function ozet() {
      var kr = Math.max(0, Math.min(azami, Math.round(Number(document.getElementById("ykTutar").value) || 0)));
      var vd = Number(document.getElementById("ykVade").value) || 60, oran = Number(v.oran) || 0;
      var top = Math.round(kr * (1 + oran / 100 * vd / 365)), tak = Math.ceil(top / vd);
      var oz = Number(s.acilis) - kr + Number(s.rezerv), yeter = Number(s.kasa) >= oz;
      document.getElementById("ykOzet").innerHTML = kv("Öz katkı + rezerv (kasadan)", (yeter ? "" : '<span style="color:var(--bad)">') + tl(oz) + (yeter ? "" : "</span>"))
        + kv("Toplam geri ödeme", tl(top)) + kv("Günlük taksit", tl(tak) + " × " + vd + " gün")
        + (yeter ? "" : '<p class="kucuk">Kasada ' + tl(s.kasa) + " var; öz katkı için " + tl(oz - Number(s.kasa)) + " daha gerekli.</p>");
    }
    document.getElementById("ykTutar").oninput = ozet; document.getElementById("ykVade").onchange = ozet; ozet();
    document.getElementById("ykAc").onclick = async function () {
      var kr = Math.round(Number(document.getElementById("ykTutar").value) || 0), vd = Number(document.getElementById("ykVade").value);
      if (kr < 10000 || kr > azami) { toast("Kredi tutarı 10.000 ₺ ile " + tl(azami) + " arasında olmalı.", true); return; }
      if (!await sor("Kredili şube aç", s.il + " şubesi açılacak: " + tl(kr) + " yatırım kredisi (" + vd + " gün) + " + tl(Number(s.acilis) - kr) + " öz katkı şirket kasasından. Taksitler her gün şirket kasasından otomatik ödenir.", "Şubeyi aç")) return;
      this.disabled = true;
      try {
        var r = await API.rpc("sirket_sube_ac_kredili", { p_sirket: Number(id), p_il: Number(il), p_kredi: kr, p_vade: vd });
        toast(r.il + " şubesi açıldı. Günlük taksit: " + tl(r.gunluk_taksit));
        try { await window.sirketTekSirketEkrani(Number(id), "sube"); } catch (_) {}
      } catch (e) { hata(e); this.disabled = false; }
    };
  }
  function teklifBagla() {
    var f = window.sirketMerkezSubeTeklif; if (typeof f !== "function") return false; if (f._yk) return true;
    var yeni = async function (id) {
      var r = await f.apply(this, arguments);
      try { var il = Number((document.getElementById("sm_sube_il") || {}).value); if (il) await krediBolumu(id, il); } catch (_) {}
      return r;
    };
    yeni._yk = true; window.sirketMerkezSubeTeklif = yeni; return true;
  }

  async function krediListesi(id) {
    var v; try { v = await API.rpc("yatirim_kredisi_panel", { p_sirket: Number(id) }); } catch (_) { return ""; }
    var l = (v && v.krediler || []).filter(function (x) { return x.durum !== "kapandi"; });
    if (!l.length) return "";
    return '<section class="kart" id="ykListe"><h3>Yatırım kredileri</h3>' + l.map(function (x) {
      return '<div class="kart" style="margin:10px 0;background:var(--panel2)"><b>#' + x.id + " · " + k(x.amac) + "</b>"
        + kv("Durum", (x.durum === "gecikmede" ? '<span style="color:var(--bad)">' : "") + k(DURUM[x.durum] || x.durum) + (x.durum === "gecikmede" ? "</span>" : ""))
        + kv("Kalan borç", "<b>" + tl(x.kalan) + "</b>") + (Number(x.gecikmis) > 0 ? kv("Gecikmiş taksit", tl(x.gecikmis)) : "")
        + kv("Günlük taksit", tl(x.taksit)) + kv("Vade", x.odenen_gun + " / " + x.vade + " gün") + kv("Yıllık faiz", yuzde(x.oran))
        + (v.yonetici ? '<button class="btn ikinci" onclick="yatirimKredisiOde(' + x.id + "," + Number(id) + ')">Erken / gecikmiş ödeme yap</button>' : "") + "</div>";
    }).join("") + "</section>";
  }
  window.yatirimKredisiOde = async function (kid, sid) {
    var raw = prompt("Şirket kasasından ödenecek tutar (boş bırakılırsa kalan borcun tamamı):", "");
    if (raw === null) return;
    raw = String(raw).replace(/\./g, "").trim();
    if (raw && !/^\d+$/.test(raw)) { toast("Geçerli bir tutar gir.", true); return; }
    try { var r = await API.rpc("yatirim_kredisi_ode", { p_kredi: kid, p_tutar: raw ? Number(raw) : null }); toast(r.kapandi ? "Kredi kapandı." : "Ödeme yapıldı. Kalan: " + tl(r.kalan)); await window.sirketTekSirketEkrani(Number(sid), "para"); }
    catch (e) { hata(e); }
  };

  /* ================= 2) TİCARİ ÖDEME (şirket tarafı) ================= */
  async function ticariBorclar(id) {
    var v; try { v = await API.rpc("sirket_fatura_panel", { p_sirket: Number(id) }); } catch (_) { return ""; }
    if (!v) return "";
    var bek = v.bekleyen || [], bak = v.bakiyeler || [];
    if (!v.yetkili && !bek.length && !bak.length) return "";
    var h = '<section class="kart" id="tbKart"><h3>Ticari borçlar (fatura / makbuz)</h3>'
      + '<p class="alt">Şirket kişilere çek yazamaz. Bir kişi şirkete mal ya da hizmet verdiyse (telif, köşe yazısı, danışmanlık, tasarım, hukuki hizmet…) fatura keser; '
      + "onaylanan fatura kadar şirket kasasından doğrudan ödeme yapılır. Hizmet bedellerinde stopaj (telif %17, diğer %20) kesilip Hazine'ye aktarılır.</p>"
      + kv("Son 30 günlük faaliyet geliri", tl(v.gelir30)) + kv("30 günlük fatura onay tavanı (%30)", tl(v.tavan) + ' <span class="kucuk">· kalan ' + tl(v.kalan) + "</span>");
    if (bek.length) {
      h += '<div style="font-size:12.5px;font-weight:750;letter-spacing:.08em;text-transform:uppercase;color:var(--txt2);margin:16px 0 6px">Onay bekleyen</div>'
        + bek.map(function (f) {
          return '<div class="kart" style="margin:8px 0;background:var(--panel2)"><b>' + k(f.kad) + " · " + tl(f.tutar) + "</b>"
            + '<p class="kucuk" style="margin:4px 0">' + k(f.tur) + " · #" + f.id + '</p><p class="alt" style="margin:0 0 8px">' + k(f.aciklama) + "</p>"
            + (v.yetkili ? '<div style="display:flex;gap:8px"><button class="btn altin" style="flex:1;margin:0" onclick="faturaKarar(' + f.id + ",true," + Number(id) + ')">Onayla</button>'
              + '<button class="btn tehlike" style="flex:1;margin:0" onclick="faturaKarar(' + f.id + ",false," + Number(id) + ')">Reddet</button></div>' : "") + "</div>";
        }).join("");
    }
    if (bak.length) {
      h += '<div style="font-size:12.5px;font-weight:750;letter-spacing:.08em;text-transform:uppercase;color:var(--txt2);margin:16px 0 6px">Ödenecek cari bakiyeler · ' + tl(v.toplam_borc) + "</div>"
        + bak.map(function (b) {
          return kv(b.kad + " (" + b.adet + " fatura)", "<b>" + tl(b.bakiye) + "</b>")
            + (v.yetkili ? '<button class="btn ikinci" onclick="faturaOde(' + Number(id) + "," + JSON.stringify(b.kad).replace(/"/g, "&quot;") + "," + Number(b.bakiye) + ')">' + k(b.kad) + " kişisine öde</button>" : "");
        }).join("");
    }
    if (!bek.length && !bak.length) h += '<p class="kucuk" style="margin-top:8px">Bekleyen fatura ya da ödenecek bakiye yok.</p>';
    return h + "</section>";
  }
  window.faturaKarar = async function (fid, kabul, sid) {
    var not = kabul ? null : prompt("Red gerekçesi (isteğe bağlı):", "");
    if (!kabul && not === null) return;
    try { await API.rpc("sirket_fatura_karar", { p_id: fid, p_kabul: !!kabul, p_not: not || null }); toast(kabul ? "Fatura onaylandı; cari bakiyeye eklendi." : "Fatura reddedildi."); await window.sirketTekSirketEkrani(Number(sid), "para"); }
    catch (e) { hata(e); }
  };
  window.faturaOde = async function (sid, kad, bakiye) {
    var raw = prompt(kad + " kişisine ödenecek tutar (en fazla " + tl(bakiye) + "; boş bırakılırsa tamamı):", "");
    if (raw === null) return;
    raw = String(raw).replace(/\./g, "").trim();
    if (raw && !/^\d+$/.test(raw)) { toast("Geçerli bir tutar gir.", true); return; }
    try { var r = await API.rpc("sirket_kisi_ode", { p_sirket: Number(sid), p_kad: kad, p_tutar: raw ? Number(raw) : null });
      toast(tl(r.odenen) + " ödendi (stopaj " + tl(r.stopaj) + ", kişiye net " + tl(r.net) + ")."); await window.sirketTekSirketEkrani(Number(sid), "para"); }
    catch (e) { hata(e); }
  };

  /* Şirket ekranı: Kasa / Sermaye sekmesine ekler */
  function sirketBagla() {
    var f = window.sirketTekSirketEkrani; if (typeof f !== "function") return false; if (f._fin) return true;
    var yeni = async function (id, tab) {
      var r = await f.apply(this, arguments);
      if (tab === "para") {
        try {
          var parcalar = await Promise.all([krediListesi(id), ticariBorclar(id)]);
          var ic = document.getElementById("icerik"); if (!ic) return r;
          ["ykListe", "tbKart"].forEach(function (x) { var e = document.getElementById(x); if (e) e.remove(); });
          var html = parcalar.join("");
          if (html) { var cari = document.getElementById("ocKart"); if (cari) cari.insertAdjacentHTML("afterend", html); else ic.insertAdjacentHTML("beforeend", html); }
        } catch (_) {}
      }
      return r;
    };
    yeni._fin = true; window.sirketTekSirketEkrani = yeni; return true;
  }

  /* ================= 2) TİCARİ ÖDEME (kişi tarafı): Çek Merkezi ================= */
  var TURLER = [["telif", "Telif (kitap/eser)"], ["kose_yazisi", "Köşe yazısı / içerik"], ["danismanlik", "Danışmanlık"], ["tasarim_reklam", "Tasarım / reklam hizmeti"], ["hukuki", "Hukuki hizmet"], ["mal_satisi", "Mal satışı"], ["diger", "Diğer hizmet"]];
  window.faturaKesModal = function () {
    if (typeof modal !== "function") return;
    var m = modal('<h3>Şirkete fatura / makbuz kes</h3><p class="alt">Bir şirkete mal ya da hizmet verdiysen bedelini fatura ile iste. Şirket onaylarsa bu tutar şirketin sana cari borcu olur ve doğrudan cüzdanına ödenir (hizmetlerde stopaj kesilir). Ortağı ya da yöneticisi olduğun şirkete fatura kesemezsin.</p>'
      + '<div class="alan"><label for="fkAra">Şirket adı</label><input id="fkAra" placeholder="En az 2 harf yaz" autocomplete="off"><div id="fkSonuc"></div><input type="hidden" id="fkSirket"></div>'
      + '<div class="alan"><label for="fkTur">Tür</label><select id="fkTur">' + TURLER.map(function (t) { return '<option value="' + t[0] + '">' + t[1] + "</option>"; }).join("") + "</select></div>"
      + '<div class="alan"><label for="fkTutar">Tutar (₺)</label><input id="fkTutar" type="number" inputmode="numeric" min="100" step="1"></div>'
      + '<div class="alan"><label for="fkAciklama">Verdiğin mal / hizmet</label><textarea id="fkAciklama" maxlength="1000" rows="3" style="width:100%;box-sizing:border-box" placeholder="Örn. Kasım ayı 4 köşe yazısı; \'Yol\' kitabının ilk baskı telifi"></textarea></div>'
      + '<button class="btn altin" id="fkGonder">Faturayı gönder</button>');
    var z = null;
    m.querySelector("#fkAra").oninput = function () {
      var q = this.value.trim(); m.querySelector("#fkSirket").value = ""; clearTimeout(z);
      if (q.length < 2) { m.querySelector("#fkSonuc").innerHTML = ""; return; }
      z = setTimeout(async function () {
        try {
          var l = await API.rpc("sirket_fatura_ara", { p_ara: q });
          m.querySelector("#fkSonuc").innerHTML = (l || []).map(function (s) {
            return '<button type="button" class="liste-satir" style="width:100%;text-align:left;background:none;border:0;color:inherit;padding:10px 4px" data-id="' + s.id + '" data-ad="' + k(s.ad) + '"><b>' + k(s.ad) + '</b> <span class="kucuk">' + k(s.sektor) + "</span></button>";
          }).join("") || '<p class="kucuk">Şirket bulunamadı.</p>';
          m.querySelectorAll("#fkSonuc [data-id]").forEach(function (b) {
            b.onclick = function () { m.querySelector("#fkSirket").value = b.getAttribute("data-id"); m.querySelector("#fkAra").value = b.getAttribute("data-ad"); m.querySelector("#fkSonuc").innerHTML = ""; };
          });
        } catch (_) {}
      }, 250);
    };
    m.querySelector("#fkGonder").onclick = async function () {
      var sid = Number(m.querySelector("#fkSirket").value), t = Number(m.querySelector("#fkTutar").value), a = m.querySelector("#fkAciklama").value.trim();
      if (!sid) { toast("Listeden bir şirket seç.", true); return; }
      if (!Number.isSafeInteger(t) || t < 100) { toast("En az 100 ₺, tam sayı tutar gir.", true); return; }
      if (a.length < 10) { toast("Verdiğin mal ya da hizmeti en az 10 karakterle açıkla.", true); return; }
      this.disabled = true;
      try { await API.rpc("sirket_fatura_kes", { p_sirket: sid, p_tur: m.querySelector("#fkTur").value, p_tutar: t, p_aciklama: a }); if (typeof modalKapat === "function") modalKapat(); toast("Fatura şirkete gönderildi; onay bekliyor."); faturalarimEkle(); }
      catch (e) { hata(e); this.disabled = false; }
    };
  };
  window.faturaIptal = async function (fid) {
    try { await API.rpc("sirket_fatura_iptal", { p_id: fid }); toast("Fatura iptal edildi."); faturalarimEkle(); } catch (e) { hata(e); }
  };
  async function faturalarimEkle() {
    var ic = document.getElementById("icerik"); if (!ic) return;
    var v; try { v = await API.rpc("sirket_fatura_panel", {}); } catch (_) { v = { faturalarim: [] }; }
    var l = (v && v.faturalarim) || [];
    var h = '<section class="kart" id="fkKart"><h3>Şirketlere fatura / makbuz</h3><p class="alt">Şirketler kişilere çek yazamaz; bir şirkete mal ya da hizmet verdiysen fatura kes, şirket onaylayınca bedeli doğrudan cüzdanına öder.</p>'
      + '<button class="btn altin" onclick="faturaKesModal()">Şirkete fatura kes</button>'
      + (l.length ? l.slice(0, 10).map(function (f) {
        return kv("#" + f.id + " · " + f.sirket + " · " + f.tur, tl(f.tutar) + ' <span class="kucuk">' + k(DURUM[f.durum] || f.durum) + (Number(f.odenen) > 0 && f.durum !== "odendi" ? " · ödenen " + tl(f.odenen) : "") + "</span>")
          + (f.durum === "bekliyor" ? '<button class="btn ikinci kucuk" onclick="faturaIptal(' + f.id + ')">Faturayı iptal et</button>' : "");
      }).join("") : "") + "</section>";
    var eski = document.getElementById("fkKart");
    if (eski) { eski.outerHTML = h; return; }
    ic.insertAdjacentHTML("beforeend", h);
  }
  function cekBagla() {
    var f = window.cekMerkeziEkrani; if (typeof f !== "function") return false; if (f._fk) return true;
    var yeni = async function () { var r = await f.apply(this, arguments); try { await faturalarimEkle(); } catch (_) {} return r; };
    yeni._fk = true; window.cekMerkeziEkrani = yeni; return true;
  }

  function hepsi() { var a = teklifBagla(), b = sirketBagla(), c = cekBagla(); return a && b && c; }
  if (!hepsi()) setTimeout(hepsi, 1500);
})();
