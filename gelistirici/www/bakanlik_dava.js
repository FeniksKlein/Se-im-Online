/* 18.11.2026 · Bakanlık adına dava: bakan (ya da vekili) bakanlığı adına oyuncuya dava açar.
   Harç bakanlık kasasından ödenir. İçişleri için son 7 günün eylemleri listelenir; düzenleyene tek dokunuşla dava hazırlanır.
   Kısayol: Adliye, Bakanlık masası ve bakanlık ekranlarının en üstünde. Yetki sunucuda (bakanlik_dava_ac) denetlenir. */
(function () {
  "use strict";
  if (window.SO_BAKANLIK_DAVA) return; window.SO_BAKANLIK_DAVA = true;
  var ST = { v: null, z: 0, sec: null, on: null };
  var TUR = [["diger", "Diğer (kanuna muhalefet vb.)"], ["hakaret", "Hakaret"], ["iftira", "İftira"], ["usulsuzluk", "Usulsüzlük"], ["yolsuzluk", "Yolsuzluk"], ["rusvet", "Rüşvet"], ["dolandiricilik", "Dolandırıcılık"]];
  var HAZIR = {
    icisleri: [["2911 · izinsiz gösteri", "diger", "2911 sayılı Toplantı ve Gösteri Yürüyüşleri Kanunu'na aykırı olarak izinsiz eylem düzenlemek ve kamu düzenini bozmak."],
               ["Halkı kin ve düşmanlığa tahrik", "diger", "Halkın bir kesimini diğer bir kesimine karşı kin ve düşmanlığa alenen tahrik etmek (TCK m.216)."],
               ["Görevli memura direnme", "diger", "Kamu görevlisinin görevini yapmasını engellemek için direnmek (TCK m.265)."]],
    adalet: [["Yargı görevini yapanı etkileme", "diger", "Yargı görevi yapanı etkilemeye teşebbüs (TCK m.277)."]],
    maliye: [["Vergi kaçakçılığı", "usulsuzluk", "Vergi Usul Kanunu m.359 kapsamında vergi kaçakçılığı."]],
    ticaret: [["Haksız rekabet", "usulsuzluk", "Türk Ticaret Kanunu kapsamında haksız rekabet ve tüketiciyi aldatma."]]
  };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  function tl(n) { return typeof tlYaz === "function" ? tlYaz(n) : Math.round(+n || 0).toLocaleString("tr-TR") + " ₺"; }
  function saat(t) { try { return new Date(t).toLocaleString("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }); } catch (e) { return ""; } }
  function hata(err) { var m = (err && err.message) || String(err); if (typeof hataCevir === "function") m = hataCevir(m); toast(m, true); }
  function yukle(zorla) { if (!zorla && ST.v && Date.now() - ST.z < 90000) return Promise.resolve(ST.v); return API.rpc("bakanlik_dava_bilgi").then(function (v) { ST.v = v; ST.z = Date.now(); return v; }); }

  var CSS = '.bdv label{display:block;font-size:15px;margin:12px 0 6px}.bdv input,.bdv textarea,.bdv select{display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;padding:12px;border-radius:12px;background:var(--panel2);color:var(--txt);border:1px solid var(--line2);color-scheme:dark}.bdv textarea{min-height:110px;line-height:1.45;resize:vertical}' +
    '.bdv .btn{width:100%;min-height:48px;margin-top:10px}.bdv .cip{display:inline-flex;min-height:38px;align-items:center;padding:6px 12px;margin:4px 6px 0 0;border-radius:999px;border:1px solid var(--line2);background:var(--panel2);color:var(--txt2);font:inherit;font-size:14px;font-weight:650}' +
    '.bdv .cip.on{background:var(--ink);border-color:var(--ink);color:#fff}.bdv .st{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid var(--line);font-size:14px}.bdv .st span:first-child{color:var(--mut)}' +
    '.bdv .ey{border:1px solid var(--line2);border-radius:14px;padding:11px;margin:8px 0;background:var(--panel2)}.bdv .ey b{font-size:15px}.bdv .alt{font-size:13px;color:var(--mut);line-height:1.4}';
  function stil() { if (!document.getElementById("bdvCss")) { var s = document.createElement("style"); s.id = "bdvCss"; s.textContent = CSS; document.head.appendChild(s); } }

  async function ekran() {
    stil(); yukleniyor("Bakanlık adına dava");
    var v; try { v = await yukle(true); } catch (err) { hata(err); return; }
    var bl = v.bakanliklar || [];
    if (!bl.length) { iskelet("Bakanlık adına dava", '<div class="kart"><p>Bu ekran yalnız bakanlar ve bakan vekilleri içindir.</p></div>', { geri: true }); return; }
    var b = bl.filter(function (x) { return x.kod === ST.sec; })[0] || bl[0]; ST.sec = b.kod;
    var L = v.limit || {}, on = ST.on || {}; ST.on = null;
    var hazir = HAZIR[b.kod] || [];
    var h = '<div class="bdv">' +
      (bl.length > 1 ? '<div class="kart">' + bl.map(function (x) { return '<button class="cip ' + (x.kod === b.kod ? "on" : "") + '" data-bdv-b="' + esc(x.kod) + '">' + esc(x.ad) + '</button>'; }).join("") + '</div>' : '') +
      '<div class="kart"><h2>' + esc(b.ad) + '</h2><p class="alt">Bakanlık davacı olur; dava metninin başında bakanlık adı ve bakan görünür. Harç (' + tl(L.harc) + ') bakanlık kasasından ödenir. Dava Yüksek Mahkeme’ye gider; davalı savunma yapar ya da avukat tutar. Görevdeki Cumhurbaşkanına ve dokunulmazlığı süren milletvekiline ceza davası açılamaz.</p>' +
      '<div class="st"><span>Kasa</span><span>' + tl(b.kasa_tl) + '</span></div>' +
      '<div class="st"><span>Bugün açılan</span><span>' + esc(b.bugun) + ' / ' + esc(L.gunluk) + '</span></div>' +
      '<div class="st"><span>Açık dava</span><span>' + esc(b.acik) + ' / ' + esc(L.acik) + '</span></div>' +
      '<div class="st" style="border:0"><span>Aynı oyuncuya</span><span>7 günde en çok ' + esc(L.kisi_haftalik) + '</span></div></div>';
    if (v.eylemler && b.kod === "icisleri") {
      h += '<div class="kart"><h3>Son 7 günün eylemleri</h3>' + (v.eylemler.length ? v.eylemler.map(function (e, i) {
        return '<div class="ey"><b>' + esc(e.il || "") + ' · ' + esc(e.baslatan) + '</b> <span class="alt">' + (e.aktif ? "sürüyor" : esc(e.durum)) + ' · ' + esc(saat(e.baslangic)) + '</span><div class="alt">' + esc(e.gerekce || "") + '</div>' +
          '<button class="btn ikinci" data-bdv-ey="' + i + '">Düzenleyene dava hazırla</button></div>'; }).join("") : '<p class="alt">Son 7 günde eylem yok.</p>') + '</div>';
    }
    h += '<div class="kart"><h3>Yeni dava</h3>' +
      (hazir.length ? '<div>' + hazir.map(function (x, i) { return '<button class="cip" data-bdv-h="' + i + '">' + esc(x[0]) + '</button>'; }).join("") + '</div>' : '') +
      '<form id="bdvForm"><label for="bdvKad">Davalı oyuncunun kullanıcı adı</label><input id="bdvKad" name="kad" required autocomplete="off" value="' + esc(on.kad || "") + '">' +
      '<label for="bdvTur">Dava türü</label><select id="bdvTur" name="tur">' + TUR.map(function (t) { return '<option value="' + t[0] + '"' + ((on.tur || "diger") === t[0] ? " selected" : "") + '>' + t[1] + '</option>'; }).join("") + '</select>' +
      '<label for="bdvIddia">İddia (20-5000 karakter)</label><textarea id="bdvIddia" name="iddia" minlength="20" maxlength="5000" required placeholder="Ne oldu, hangi kural ya da kanun ihlal edildi?">' + esc(on.iddia || "") + '</textarea>' +
      '<label for="bdvDelil">Deliller (isteğe bağlı)</label><textarea id="bdvDelil" name="delil" maxlength="5000" style="min-height:80px" placeholder="Mesaj, eylem numarası, tarih…">' + esc(on.delil || "") + '</textarea>' +
      '<button class="btn altin" type="submit">' + esc(b.ad) + ' adına dava aç</button></form></div>';
    var son = b.son || [];
    if (son.length) h += '<div class="kart"><h3>Bakanlığın son davaları</h3>' + son.map(function (d) {
      return '<div class="st"><span>#' + esc(d.id) + ' · ' + esc(d.davali || "") + ' · ' + esc(saat(d.acilis)) + '</span><span>' + esc(d.durum === "acik" ? "sürüyor" : (d.karar || d.durum)) + '</span></div>'; }).join("") + '</div>';
    iskelet("Bakanlık adına dava", h + '</div>', { geri: true });
    document.querySelectorAll("[data-bdv-b]").forEach(function (x) { x.onclick = function () { ST.sec = x.getAttribute("data-bdv-b"); ekran(); }; });
    document.querySelectorAll("[data-bdv-h]").forEach(function (x) { x.onclick = function () { var r = hazir[+x.getAttribute("data-bdv-h")]; document.getElementById("bdvTur").value = r[1]; document.getElementById("bdvIddia").value = r[2]; document.querySelectorAll("[data-bdv-h]").forEach(function (y) { y.classList.remove("on"); }); x.classList.add("on"); }; });
    document.querySelectorAll("[data-bdv-ey]").forEach(function (x) { x.onclick = function () {
      var e = v.eylemler[+x.getAttribute("data-bdv-ey")];
      ST.on = { kad: e.baslatan, tur: "diger", iddia: HAZIR.icisleri[0][2], delil: "Eylem #" + e.id + " · " + (e.il || "") + " · " + saat(e.baslangic) + (e.gerekce ? " · Eylem gerekçesi: " + e.gerekce : "") }; ekran(); }; });
    document.getElementById("bdvForm").onsubmit = async function (ev) {
      ev.preventDefault(); var f = new FormData(ev.target), btn = ev.target.querySelector("button");
      var kad = String(f.get("kad") || "").trim();
      if (!window.confirm(b.ad + " adına " + kad + " hakkında dava açılsın mı? Harç bakanlık kasasından ödenir.")) return;
      btn.disabled = true;
      try { var r = await API.rpc("bakanlik_dava_ac", { p_bakanlik: b.kod, p_kad: kad, p_tur: String(f.get("tur")), p_iddia: String(f.get("iddia") || "").trim(), p_delil: String(f.get("delil") || "").trim() });
        toast("Dava #" + r.id + " açıldı."); ST.z = 0; ekran(); }
      catch (err) { hata(err); btn.disabled = false; }
    };
  }
  window.bakanlikDavaEkrani = ekran;

  function kisayol(baslik) {
    if (typeof baslik !== "string" || !/^(Adliye|Bakanlık masası|.*Bakanlığı|Devlet)$/.test(baslik)) return;
    yukle(false).then(function (v) {
      var ic = document.getElementById("icerik");
      if (!v || !(v.bakanliklar || []).length || !ic || document.getElementById("bdvKisa")) return;
      ic.insertAdjacentHTML("afterbegin", '<div class="kart" id="bdvKisa"><button class="btn ikinci" style="width:100%;min-height:48px" onclick="ekranAc(bakanlikDavaEkrani)">' +
        (v.bakanliklar.length > 1 ? "Bakanlık adına dava aç" : v.bakanliklar[0].ad + " adına dava aç") + '</button></div>');
    }).catch(function () {});
  }
  function sar() {
    var once = window.iskelet; if (typeof once !== "function" || once.__bdv) return;
    var yeni = function (baslik) { var r = once.apply(this, arguments); try { kisayol(baslik); } catch (e) {} return r; };
    yeni.__bdv = true; for (var k in once) if (Object.prototype.hasOwnProperty.call(once, k)) yeni[k] = once[k];
    window.iskelet = yeni; try { iskelet = yeni; } catch (e) {}
  }
  sar(); setTimeout(sar, 3200);
})();
