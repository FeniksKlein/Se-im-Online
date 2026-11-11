/* 11.11.2026 · Ortaklar cari hesabı (adat faizli borçlanma) — şirket › Kasa / Sermaye sekmesine kart ekler.
   Arka uç: sql/188_ortak_cari_hesap.sql (ortak_cari_panel, ortak_cari_cek, ortak_cari_ode). */
(function () {
  "use strict";
  if (window.SO_ORTAK_CARI_V1) return;
  window.SO_ORTAK_CARI_V1 = true;

  function k(x) { return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function tl(x) { return (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺"; }
  function kv(a, b) { return '<div class="kv"><span class="k">' + k(a) + '</span><span class="v">' + b + "</span></div>"; }
  function hata(e) { toast(typeof hataCevir === "function" ? hataCevir(e && e.message || String(e)) : String(e && e.message || e), true); }
  var TUR = { cekim: "Borç çekildi", odeme: "Borç ödendi", faiz_odendi: "Adat faizi ödendi", faiz_borca: "Faiz borca eklendi" };

  function kartHtml(id, v) {
    var oran = Number(v.oran || 0).toLocaleString("tr-TR", { maximumFractionDigits: 2 });
    var h = '<section class="kart oc-kart" id="ocKart"><h3>Ortaklar cari hesabı</h3>'
      + '<p class="alt">Hakim ortak, şirketin serbest kârından (sermaye ve şirket borçları hariç) payı oranında borç çekebilir. '
      + "Borca her gün Merkez Bankası politika faizi üzerinden adat faizi işler ve faiz şirket kasasına gelir yazılır. Borç şirketin alacağı olarak defterde durur.</p>"
      + kv("Yıllık adat faizi", "%" + oran)
      + kv("Serbest kâr", tl(v.serbest)) + kv("Payın", "%" + k(v.pay))
      + kv("Çekebileceğin tutar", "<b>" + tl(v.limit) + "</b>");
    if (Number(v.acik_cek) > 0) h += kv("Açık çek borçları (ayrılır)", tl(v.acik_cek));
    if (Number(v.borc) > 0) {
      h += '<div class="oc-borc">' + kv("Cari hesap borcun", "<b>" + tl(v.borc) + "</b>") + kv("Günlük adat faizi", tl(v.gunluk_faiz))
        + kv("Bugüne kadar ödenen faiz", tl(v.toplam_faiz)) + "</div>";
    }
    if (v.neden) h += '<p class="kucuk" style="margin-top:8px">' + k(v.neden) + "</p>";
    if (Number(v.limit) >= 1000) {
      h += '<div class="alan" style="margin-top:10px"><label for="ocTutar">Çekilecek tutar (₺)</label><input id="ocTutar" type="number" inputmode="numeric" min="1000" step="1" max="' + Number(v.limit) + '" placeholder="En fazla ' + tl(v.limit) + '"></div>'
        + '<button class="btn altin" id="ocCek" onclick="ortakCariCek(' + Number(id) + ')">Adat faizli borç çek</button>';
    }
    if (Number(v.borc) > 0) {
      h += '<div class="alan" style="margin-top:12px"><label for="ocOde">Ödenecek tutar (₺, boş bırakılırsa tamamı)</label><input id="ocOde" type="number" inputmode="numeric" min="1" step="1" max="' + Math.ceil(Number(v.borc)) + '"></div>'
        + '<button class="btn ikinci" onclick="ortakCariOde(' + Number(id) + ')">Borcu öde</button>';
    }
    if ((v.ortaklar || []).length && Number(v.sirket_alacak) > 0) {
      h += '<div class="ymf-baslik" style="font-size:12.5px;font-weight:750;letter-spacing:.08em;text-transform:uppercase;color:var(--txt2);margin:16px 0 6px">Şirketin ortaklardan alacağı · ' + tl(v.sirket_alacak) + "</div>"
        + v.ortaklar.map(function (o) { return kv(o.kad, tl(o.borc)); }).join("");
    }
    if ((v.hareketler || []).length) {
      h += '<details style="margin-top:12px"><summary class="kucuk" style="cursor:pointer">Son hareketler</summary>'
        + v.hareketler.map(function (x) {
          return kv((TUR[x.tur] || x.tur) + " · " + new Date(x.zaman).toLocaleDateString("tr-TR"), tl(x.tutar) + ' <span class="kucuk">→ borç ' + tl(x.borc) + "</span>");
        }).join("") + "</details>";
    }
    return h + "</section>";
  }

  async function ekle(id) {
    var ic = document.getElementById("icerik"); if (!ic || ic.querySelector("#ocKart")) return;
    var v; try { v = await API.rpc("ortak_cari_panel", { p_sirket: Number(id) }); } catch (_) { return; }
    if (!v) return;
    if (Number(v.pay) < 50 && !(Number(v.borc) > 0)) return;   // azınlık ortağına göstermeye gerek yok
    ic = document.getElementById("icerik"); if (!ic || ic.querySelector("#ocKart")) return;
    var hedef = Array.prototype.slice.call(ic.querySelectorAll(".kart")).filter(function (x) { return /Cüzdanımdan şirketime/.test(x.textContent); })[0];
    var html = kartHtml(id, v);
    if (hedef) hedef.insertAdjacentHTML("afterend", html); else ic.insertAdjacentHTML("beforeend", html);
  }

  function bagla() {
    var f = window.sirketTekSirketEkrani;
    if (typeof f !== "function") return false;
    if (f._oc) return true;
    var yeni = async function (id, tab) {
      var r = await f.apply(this, arguments);
      if (tab === "para") { try { await ekle(id); } catch (_) {} }
      return r;
    };
    yeni._oc = true;
    window.sirketTekSirketEkrani = yeni;
    return true;
  }
  if (!bagla()) setTimeout(bagla, 1500);

  async function yenile(id) { try { await window.sirketTekSirketEkrani(Number(id), "para"); } catch (_) {} }

  window.ortakCariCek = async function (id) {
    var el = document.getElementById("ocTutar"), raw = (el && el.value || "").trim(), t = Number(raw);
    if (!/^\d+$/.test(raw) || t < 1000) { toast("En az 1.000 ₺, tam sayı tutar gir.", true); return; }
    var ok = typeof onayla === "function"
      ? await onayla("Adat faizli borç", tl(t) + " şirket kasasından cüzdanına geçecek ve şirkete borçlanacaksın. Borca her gün politika faizi üzerinden adat faizi işler; faiz cüzdanından şirkete ödenir. Diğer ortaklara bildirim gider.", "Borcu çek")
      : confirm("Borç çekilsin mi?");
    if (!ok) return;
    var b = document.getElementById("ocCek"); if (b) b.disabled = true;
    try { var r = await API.rpc("ortak_cari_cek", { p_sirket: Number(id), p_tutar: t }); toast(tl(t) + " cüzdanına geçti. Cari hesap borcun: " + tl(r.borc)); await yenile(id); }
    catch (e) { hata(e); if (b) b.disabled = false; }
  };
  window.ortakCariOde = async function (id) {
    var el = document.getElementById("ocOde"), raw = (el && el.value || "").trim();
    if (raw && !/^\d+$/.test(raw)) { toast("Geçerli bir tutar gir.", true); return; }
    try { var r = await API.rpc("ortak_cari_ode", { p_sirket: Number(id), p_tutar: raw ? Number(raw) : null }); toast(tl(r.odenen) + " ödendi. Kalan borç: " + tl(r.borc)); await yenile(id); }
    catch (e) { hata(e); }
  };
})();
