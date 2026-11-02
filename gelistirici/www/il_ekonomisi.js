/* İl ekonomisi (sunucu 161 · 02.11.2026)
   Şehre göre işyeri kuruluş gideri, üretim/alış maliyeti ve NPC müşteri yoğunluğu.
   Veri: TÜİK ADNKS 2025 il nüfusu, TÜİK il bazında GSYH 2024 (kişi başı $), SEGE kademesi, oyundaki il gelişimi.
   window.ilEkonomiBilgi(il)            → sunucu bilgisi (5 dk önbellek)
   window.ilEkoKartHtml(d, {gider,tur}) → kısa şehir kartı
   window.ilEkoKurulusSatiri(el, il, tur, {sektor}) → kuruluş pencerelerine şehir kartı + kuruluş gideri
   window.ilEkonomileriEkrani()          → 81 ilin karşılaştırması */
(function () {
  "use strict";
  if (window.SO_IL_EKONOMI_V1) return;
  window.SO_IL_EKONOMI_V1 = true;

  var esc = function (s) {
    return typeof e === "function" ? e(String(s == null ? "" : s)) :
      String(s == null ? "" : s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; });
  };
  var tl = function (x) { return Math.round(Number(x) || 0).toLocaleString("tr-TR") + " ₺"; };
  var kat = function (x) { return "×" + Number(x == null ? 1 : x).toLocaleString("tr-TR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); };
  var nufusYaz = function (n) {
    n = Number(n) || 0;
    return n >= 1e6 ? (n / 1e6).toLocaleString("tr-TR", { maximumFractionDigits: 2 }) + " milyon" : Math.round(n / 1e3).toLocaleString("tr-TR") + " bin";
  };
  var hata = function (err) { return typeof hataCevir === "function" ? hataCevir(err && err.message || String(err)) : String(err && err.message || err); };

  // ---------------------------------------------------------------- stil
  function stil() {
    if (document.getElementById("ile-stil")) return;
    var s = document.createElement("style");
    s.id = "ile-stil";
    s.textContent =
      ".ile-kart{margin:10px 0;padding:12px 14px;border-radius:14px;background:var(--panel2,#1b2547);border:1px solid var(--line2,#2c3866);color:var(--txt,#e8ecf8)}" +
      ".ile-kart.ile-yuk{color:var(--mut,#98a4c4);font-size:13px}" +
      ".ile-bas{display:flex;flex-wrap:wrap;align-items:baseline;gap:4px 10px;margin-bottom:8px}" +
      ".ile-bas b{font-size:15px}.ile-bas span{font-size:12.5px;color:var(--mut,#98a4c4)}" +
      ".ile-izgara{display:grid;grid-template-columns:1fr 1fr;gap:8px 14px}" +
      "@media(max-width:340px){.ile-izgara{grid-template-columns:1fr}}" +
      ".ile-olcu small{display:flex;justify-content:space-between;font-size:12px;color:var(--mut,#98a4c4)}" +
      ".ile-olcu small b{color:var(--txt,#e8ecf8);font-weight:600}" +
      ".ile-cubuk{height:6px;border-radius:4px;background:rgba(255,255,255,.08);margin-top:4px;overflow:hidden}" +
      ".ile-cubuk i{display:block;height:100%;border-radius:4px;background:var(--c,#8f7cff)}" +
      ".ile-gider{margin-top:10px;padding:9px 11px;border-radius:10px;background:rgba(143,124,255,.12);font-size:13px;line-height:1.45}" +
      ".ile-gider b{font-size:15px}" +
      ".ile-not{margin-top:8px;font-size:12px;color:var(--mut,#98a4c4);line-height:1.45}" +
      ".ile-sekme{display:flex;gap:6px;overflow-x:auto;margin:10px 0}" +
      ".ile-sekme button{flex:0 0 auto;padding:8px 12px;border-radius:10px;border:1px solid var(--line2,#2c3866);background:var(--panel,#141c38);color:var(--txt,#e8ecf8);font-size:13px}" +
      ".ile-sekme button.on{border-color:#a995ff;background:#383063}" +
      ".ile-ara{width:100%;box-sizing:border-box;padding:10px 12px;border-radius:10px;border:1px solid var(--line2,#2c3866);background:var(--panel,#141c38);color:var(--txt,#e8ecf8);font-size:14px}" +
      ".ile-satir{display:grid;grid-template-columns:28px 1fr auto;gap:2px 10px;align-items:center;padding:10px 4px;border-top:1px solid var(--line2,#2c3866);cursor:pointer}" +
      ".ile-satir:first-child{border-top:0}" +
      ".ile-satir .no{font-size:12px;color:var(--mut,#98a4c4);text-align:right}" +
      ".ile-satir .ad b{display:block;font-size:14.5px}.ile-satir .ad small{font-size:12px;color:var(--mut,#98a4c4)}" +
      ".ile-satir .deg{text-align:right;font-size:14px;font-weight:600;white-space:nowrap}.ile-satir .deg small{display:block;font-size:11.5px;font-weight:400;color:var(--mut,#98a4c4)}" +
      ".ile-satir .cb{grid-column:2 / 4}";
    document.head.appendChild(s);
  }

  // ---------------------------------------------------------------- veri
  var onbellek = {};
  async function bilgi(il) {
    il = Number(il);
    if (!il) return null;
    var c = onbellek[il];
    if (c && Date.now() - c.t < 5 * 60 * 1000) return c.v;
    var v = await API.rpc("il_ekonomi_bilgi", { p_il: il });
    onbellek[il] = { t: Date.now(), v: v };
    return v;
  }
  window.ilEkonomiBilgi = bilgi;

  // ---------------------------------------------------------------- kart
  function olcu(ad, deger, min, max, maliyetMi) {
    var v = Number(deger == null ? 1 : deger), oran = Math.max(0.04, Math.min(1, (v - min) / (max - min)));
    var renk = maliyetMi ? (v >= 1.25 ? "var(--warn,#f2b33d)" : v <= 0.85 ? "var(--good,#34c98a)" : "#8f7cff")
                         : (v >= 1.25 ? "var(--good,#34c98a)" : v <= 0.6 ? "var(--warn,#f2b33d)" : "#8f7cff");
    return '<div class="ile-olcu"><small><span>' + esc(ad) + '</span><b>' + kat(v) + '</b></small>' +
      '<div class="ile-cubuk" style="--c:' + renk + '"><i style="width:' + Math.round(oran * 100) + '%"></i></div></div>';
  }
  var TUR_AD = { fabrika: "fabrika", magaza: "mağaza", insaat: "müteahhit ofisi", sigorta: "sigorta acentesi", pazar: "işletme" };
  function kartHtml(d, opt) {
    stil();
    opt = opt || {};
    if (!d) return "";
    var aktif = d.aktif !== false;
    var h = '<div class="ile-kart"><div class="ile-bas"><b>' + esc(d.il || ("İl " + d.il_id)) + ' ekonomisi</b>' +
      (aktif ? '<span>Nüfus ' + nufusYaz(d.nufus) + ' · kişi başı gelir ' + Math.round(Number(d.gsyh_kisi_usd) || 0).toLocaleString("tr-TR") +
        ' $ (Türkiye ' + kat(d.gelir) + ')</span>' : '<span>Şehir çarpanları şu an kapalı; her ilde aynı.</span>') + '</div>';
    h += '<div class="ile-izgara">' +
      olcu("Kira ve kuruluş", d.kurulus, 0.5, 2.0, true) +
      olcu("Müşteri yoğunluğu", d.talep, 0.2, 6.0, false) +
      olcu("Alım gücü", d.alim_gucu, 0.6, 1.4, false) +
      olcu("Fiyat düzeyi", d.fiyat, 0.9, 1.15, true) +
      olcu("Üretim maliyeti", d.uretim, 0.9, 1.2, true) +
      '</div>';
    if (opt.gider != null && aktif) {
      h += '<div class="ile-gider">Bu ilde ' + esc(TUR_AD[opt.tur] || "işyeri") + ' açmanın kuruluş gideri: <b>' + tl(opt.gider) + '</b>' +
        '<br><small>Kira depozitosu, tadilat ve donanım. Kuruluşta bir kez, yeni şirketin kasasından düşer; belediye harcı ayrıca kesilir.</small></div>';
    }
    if (opt.not !== false) {
      h += '<div class="ile-not">Büyük ve zengin şehirde kira, işçilik ve fiyatlar yüksek; müşteri de çok. Küçük şehirde açmak ucuz ama müşteri az.</div>';
    }
    return h + '</div>';
  }
  window.ilEkoKartHtml = kartHtml;

  window.ilEkoKurulusSatiri = async function (hedef, il, tur, opt) {
    if (!hedef) return;
    opt = opt || {};
    var istek = (hedef._ileIstek = (hedef._ileIstek || 0) + 1);
    stil();
    if (!il) { hedef.innerHTML = ""; return; }
    hedef.innerHTML = '<div class="ile-kart ile-yuk">Şehir ekonomisi yükleniyor…</div>';
    try {
      var d = await bilgi(il);
      if (hedef._ileIstek !== istek) return;
      var gider = null;
      if (tur === "pazar" && opt.sektor) {
        var s = (d.pazar_sektorleri || []).filter(function (x) { return x.kod === opt.sektor; })[0];
        gider = s ? s.gider : null;
      } else if (tur && d.kurulus_gideri) {
        gider = d.kurulus_gideri[tur];
      }
      hedef.innerHTML = kartHtml(d, { gider: gider, tur: tur, not: opt.not });
    } catch (err) {
      if (hedef._ileIstek === istek) hedef.innerHTML = "";
    }
  };

  // ---------------------------------------------------------------- 81 il ekranı
  var LS = { sira: "kurulus", ara: "", veri: null };
  var SIRALAR = [
    ["kurulus", "Kuruluş maliyeti"], ["talep", "Müşteri yoğunluğu"], ["gelir", "Kişi başı gelir"],
    ["nufus", "Nüfus"], ["ucuz", "En ucuz"]
  ];
  function listeHtml() {
    var v = LS.veri || {}, iller = (v.iller || []).slice();
    var q = (LS.ara || "").toLocaleLowerCase("tr-TR");
    var anahtar = { kurulus: "kurulus", talep: "talep", gelir: "gsyh_kisi_usd", nufus: "nufus", ucuz: "kurulus" }[LS.sira];
    iller.sort(function (a, b) {
      var x = Number(a[anahtar]) || 0, y = Number(b[anahtar]) || 0;
      return LS.sira === "ucuz" ? x - y : y - x;
    });
    var h = "";
    iller.forEach(function (d, i) {
      if (q && String(d.il).toLocaleLowerCase("tr-TR").indexOf(q) < 0) return;
      var deg, alt;
      if (LS.sira === "talep") { deg = kat(d.talep); alt = "müşteri"; }
      else if (LS.sira === "gelir") { deg = Math.round(Number(d.gsyh_kisi_usd) || 0).toLocaleString("tr-TR") + " $"; alt = "kişi başı"; }
      else if (LS.sira === "nufus") { deg = nufusYaz(d.nufus); alt = "nüfus"; }
      else { deg = tl(d.gider_fabrika); alt = "fabrika açılışı"; }
      h += '<div class="ile-satir" role="button" tabindex="0" onclick="ilEkoDetay(' + Number(d.il_id) + ')">' +
        '<span class="no">' + (i + 1) + '</span>' +
        '<span class="ad"><b>' + esc(d.il) + '</b><small>Kira ' + kat(d.kurulus) + ' · müşteri ' + kat(d.talep) + ' · mağaza ' + tl(d.gider_magaza) + '</small></span>' +
        '<span class="deg">' + deg + '<small>' + alt + '</small></span></div>';
    });
    return h || '<div class="ile-not">Bu adla il bulunamadı.</div>';
  }
  function ciz() {
    var v = LS.veri || {};
    var h = '<div class="kart"><h2>Şehir ekonomileri</h2><p class="alt">Bir işletmenin kuruluş gideri, kira ve işçilik maliyeti, ürün ve mal alış fiyatları ' +
      've NPC müşterilerin ne kadar alışveriş yaptığı açıldığı şehre göre değişir. İstanbul ve Ankara pahalıdır ama müşterisi boldur; ' +
      'Tunceli, Bayburt, Artvin gibi küçük illerde açmak ucuz ama müşteri azdır.</p>' +
      (v.aktif === false ? '<p class="alt"><b>Şehir çarpanları şu an kapalı.</b></p>' : '') +
      '<p class="ile-not">Kaynak: ' + esc(v.kaynak || "TÜİK") + '.</p></div>';
    h += '<input class="ile-ara" id="ileAra" placeholder="İl ara" value="' + esc(LS.ara) + '" oninput="ilEkoAra(this.value)">';
    h += '<div class="ile-sekme">' + SIRALAR.map(function (s) {
      return '<button type="button" class="' + (s[0] === LS.sira ? "on" : "") + '" onclick="ilEkoSira(\'' + s[0] + '\')">' + s[1] + '</button>';
    }).join("") + '</div>';
    h += '<div class="kart" id="ileListe">' + listeHtml() + '</div>';
    h += '<div class="kart"><h3>Çarpanlar nasıl hesaplanıyor?</h3><p class="alt">' +
      '<b>Kira ve kuruluş:</b> kişi başı gelir ve şehir büyüklüğü (×0,5–×2,0). Kuruluş gideri ve şube kirası bununla çarpılır.<br>' +
      '<b>Müşteri yoğunluğu:</b> nüfus ve gelir (×0,2–×6,0). Market, kahveci ve fast food için günlük müşteri kotası ile akaryakıt, galeri, mobilya gibi stoklu işletmelerin satışları bununla büyür.<br>' +
      '<b>Alım gücü:</b> müşterinin harcaması ve fiyat toleransı (×0,6–×1,4).<br>' +
      '<b>Fiyat düzeyi:</b> raf ve toptan referans fiyatları (×0,90–×1,15).<br>' +
      '<b>Üretim maliyeti:</b> fabrikada işçilik, enerji ve kira (×0,90–×1,20).<br>' +
      'Belediyenin yatırımlarıyla gelişen il, bu çarpanlarda %10\'a kadar yükselir.</p></div>';
    iskelet("Şehir ekonomileri", h, { geri: true });
  }
  async function ekran() {
    stil();
    try { yukleniyor("Şehir ekonomileri"); } catch (_) {}
    try { LS.veri = await API.rpc("il_ekonomi_liste"); }
    catch (err) { iskelet("Şehir ekonomileri", '<div class="kart"><p class="alt">' + esc(hata(err)) + '</p></div>', { geri: true }); return; }
    ciz();
  }
  window.ilEkonomileriEkrani = ekran;
  window.ilEkoSira = function (s) { LS.sira = s; ciz(); };
  window.ilEkoAra = function (q) {
    LS.ara = q;
    var l = document.getElementById("ileListe");
    if (l) l.innerHTML = listeHtml();
  };
  window.ilEkoDetay = async function (il) {
    try {
      var d = await bilgi(il);
      var g = d.kurulus_gideri || {}, mg = d.musteri_gunluk || {}, ms = d.magaza_saatlik || {};
      var satir = function (a, b) { return '<div class="kv"><span>' + a + '</span><b>' + b + '</b></div>'; };
      var pz = (d.pazar_sektorleri || []).slice().sort(function (a, b) { return Number(a.gider) - Number(b.gider); });
      modal('<h3>' + esc(d.il) + '</h3>' + kartHtml(d, { not: false }) +
        '<h4 style="margin:14px 0 6px">Kuruluş giderleri (bir kez)</h4>' +
        satir("Fabrika", tl(g.fabrika)) + satir("Market / kahveci / fast food", tl(g.magaza)) +
        satir("Müteahhit ofisi", tl(g.insaat)) + satir("Sigorta acentesi", tl(g.sigorta)) +
        (pz.length ? '<details style="margin-top:6px"><summary style="cursor:pointer;padding:6px 0">Hizmet ve stoklu işletmeler (' + pz.length + ')</summary>' +
          pz.map(function (x) { return satir(esc(x.ad), tl(x.gider)); }).join("") + '</details>' : '') +
        '<h4 style="margin:14px 0 6px">NPC müşteriler</h4>' +
        satir("Günlük market müşterisi (şehir)", Number(mg.market || 0).toLocaleString("tr-TR")) +
        satir("Günlük fast food müşterisi (şehir)", Number(mg.fastfood || 0).toLocaleString("tr-TR")) +
        satir("Günlük kahve müşterisi (şehir)", Number(mg.kahve || 0).toLocaleString("tr-TR")) +
        satir("Bir marketin saatlik müşterisi", Number(ms.market || 0).toLocaleString("tr-TR")) +
        '<p class="ile-not">Şehirdeki müşteri kotası o şehirdeki bütün mağazalar arasında paylaşılır; rakip arttıkça her mağazaya düşen pay azalır.</p>' +
        '<button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
    } catch (err) { toast(hata(err), true); }
  };

  // ---------------------------------------------------------------- menü araması
  function aramaEkle() {
    var ind = window.SO_MENU_ARAMA_INDEKSI;
    if (!ind || !ind.ekonomi) return false;
    if (!ind.ekonomi.some(function (x) { return x[1] === "Şehir ekonomileri"; }))
      ind.ekonomi.push(["📍", "Şehir ekonomileri", "81 ilde kuruluş gideri, kira, fiyat ve müşteri yoğunluğu", "soMenuGit('ilEkonomileriEkrani')",
        "şehir il ekonomi kuruluş gideri kira maliyet müşteri talep npc nüfus gelir istanbul ankara fabrika mağaza dükkan açılış"]);
    return true;
  }
  if (!aramaEkle()) setTimeout(aramaEkle, 1500);

})();
