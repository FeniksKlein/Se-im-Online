/* =====================================================================
   Seçim Online — CÜZDAN HAREKETLERİ (27.10.2026)
   Oyuncu bildirimi: "Cüzdanda son 1 günün gelen-giden parasını ve kaynağını
   görebiliyorduk, şimdi bulamıyoruz." Üst çubuktaki cüzdan tutarı artık bu
   ekranı açar (+ işareti mağazayı açar). Hayat ekranına da kısayol eklenir.
   Sunucu: public.cuzdan_hareketleri(p_saat) — yalnız okur.
   ===================================================================== */
(function () {
  "use strict";
  if (window.SO_CUZDAN_HAREKET_V1) return;
  window.SO_CUZDAN_HAREKET_V1 = true;

  var esc = function (x) {
    return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  };
  var tl = function (n) {
    if (typeof tlYaz === "function") return tlYaz(n);
    return Math.round(Number(n || 0)).toLocaleString("tr-TR") + " ₺";
  };
  var zaman = function (ts) {
    try { return typeof tarihSaat === "function" ? tarihSaat(ts) : new Date(ts).toLocaleString("tr-TR"); } catch (_) { return ""; }
  };
  var TUR = {
    maas: ["Maaş", "maaş kumbarası"], hemsehri: ["Hemşehri desteği", "belediye"], destek: ["Sosyal destek", "devlet"],
    hosgeldin: ["Hoş geldin desteği", "belediye"], ikramiye: ["İkramiye", "devlet"], yardim: ["Afet / sosyal yardım", "devlet"],
    gorev: ["Görev ödülü", "görevler"], ek_is: ["Ek iş", "meslek"], meslek: ["Meslek ve dükkân", "meslek"],
    sirket: ["Şirketler", "kuruluş, sermaye, kâr payı, satış"], piyasa: ["Yatırım (altın, döviz, hisse)", "piyasa"],
    banka: ["Banka", "yatırma / çekme"], mevduat: ["Mevduat", "banka"], kredi: ["Kredi", "banka"], oyb_kredi: ["Oyuncu bankası kredisi", "banka"],
    haciz: ["Haciz", "icra"], icra_haciz: ["Gelir haczi", "icra"], icra_satis: ["İcra satışı", "icra"], icra_fazla: ["İcra fazlası iadesi", "icra"],
    tahvil: ["Tahvil", "belediye"], kira: ["Kira geliri", "mülk"], emlak: ["Emlak vergisi", "belediye"], servet: ["Servet vergisi", "devlet"],
    tasinma: ["Taşınma", "il değiştirme"], bagis: ["Bağış", "kalkınma / kişi"], dernek: ["Dernek", "bağış / aidat"],
    parti_destek: ["Parti desteği", "parti"], parti_kur: ["Parti kuruluşu", "parti"], parti_kur_iade: ["Parti kuruluş iadesi", "parti"],
    teskilat: ["Teşkilat", "parti"], aday: ["Adaylık", "harç / iade"], miting: ["Miting", "kampanya"], kampanya: ["Kampanya", "reklam siparişi"],
    reklam: ["Propaganda / reklam", "kampanya"], reklam_odul: ["Reklam ödülü", "reklam izle"], adliye: ["Adliye", "harç, dava, iade"],
    muzayede: ["Müzayede", "pey / iade"], iade: ["İade", "çeşitli"], piyango: ["Milli Piyango", "şans oyunları"], kazikazan: ["Kazı Kazan", "şans oyunları"],
    gazete_gelir: ["Gazete geliri", "basın"], gazete_kur: ["Gazete kuruluşu", "basın"], havale: ["Havale", "oyuncuya / oyuncudan"],
    satin_alma: ["Mağaza", "₺ paketi"], magaza: ["Mağaza", "₺ paketi"], ihale: ["İhale", "kamu"], ihale_iade: ["İhale iadesi", "kamu"],
    ceza: ["Ceza", "adli / idari"], hibe: ["Hibe", "çeşitli"], yonetici: ["Oyun yönetimi", "düzeltme"],
    // 30.10.2026: Ekonomik Denge
    vergi: ["Servet vergisi", "Ekonomik Denge · kademeli"], fon: ["Fırsat Eşitliği Fonu", "servet vergisinden destek"],
    ulasim: ["Ulaşım", "miting otobüsü"]
  };
  TUR.servet = ["Servet vergisi (kanun)", "Meclis"];
  var turAd = function (t) { return (TUR[t] && TUR[t][0]) || String(t || "Diğer").replace(/_/g, " ").replace(/^./, function (c) { return c.toLocaleUpperCase("tr-TR"); }); };
  var turAlt = function (t) { return (TUR[t] && TUR[t][1]) || ""; };

  (function () {
    if (document.getElementById("cz-stil")) return;
    var css = [
      ".cz .cz-ust{border-radius:20px;padding:18px;color:#fff;background:linear-gradient(140deg,#6d55e6,#1f1b4d);margin-bottom:12px;position:relative;overflow:hidden}",
      ".cz .cz-ust::after{content:'';position:absolute;inset:0;pointer-events:none;background:radial-gradient(120% 80% at 100% 0%,rgba(255,255,255,.14),transparent 60%)}",
      ".cz .cz-ust>*{position:relative;z-index:1}",
      ".cz .cz-ust small{display:block;font-size:12.5px;opacity:.8}",
      ".cz .cz-ust b.cz-para{display:block;font-family:var(--disp);font-size:34px;line-height:1.1;font-variant-numeric:tabular-nums;margin-top:2px}",
      ".cz .cz-uc{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:14px}",
      ".cz .cz-uc div{background:rgba(0,0,0,.22);border-radius:11px;padding:8px 10px;min-width:0}",
      ".cz .cz-uc small{font-size:11px}",
      ".cz .cz-uc b{display:block;font-variant-numeric:tabular-nums;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".cz .cz-sec{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin:0 0 12px}",
      ".cz .cz-sec button{padding:9px 6px;border-radius:12px;background:var(--panel);color:var(--txt2);font-weight:700;font-size:13.5px}",
      ".cz .cz-sec button.on{background:var(--txt);color:var(--bg)}",
      ".cz .cz-kutu{background:var(--panel);border-radius:14px;padding:4px 14px;margin-bottom:12px}",
      ".cz .cz-kutu h3{font-size:13px;color:var(--mut);font-weight:600;padding:12px 0 4px;margin:0}",
      ".cz .cz-g{padding:10px 0;border-top:1px solid var(--line)}",
      ".cz .cz-kutu h3+.cz-g{border-top:0}",
      ".cz .cz-g .cz-gb{display:flex;justify-content:space-between;gap:10px;align-items:baseline}",
      ".cz .cz-g .cz-gb span{min-width:0}",
      ".cz .cz-g .cz-gb b{font-size:14.5px}",
      ".cz .cz-g .cz-gb small{display:block;color:var(--mut);font-size:12px}",
      ".cz .cz-g .cz-gb em{font-style:normal;font-weight:700;font-variant-numeric:tabular-nums;white-space:nowrap;text-align:right}",
      ".cz .cz-g .cz-gb em small{font-weight:500}",
      ".cz .cz-cubuk{display:flex;height:6px;border-radius:6px;overflow:hidden;background:var(--panel2);margin-top:7px}",
      ".cz .cz-cubuk i{display:block;height:100%}",
      ".cz .cz-cubuk i.g{background:var(--good)}.cz .cz-cubuk i.c{background:var(--al)}",
      ".cz .cz-s{display:flex;gap:10px;align-items:flex-start;padding:11px 0;border-top:1px solid var(--line)}",
      ".cz .cz-kutu h3+.cz-s,.cz .cz-kutu .cz-filtre+.cz-s{border-top:0}",
      ".cz .cz-s .cz-so{flex:1;min-width:0}",
      ".cz .cz-s .cz-so div{font-size:14px;line-height:1.35;word-break:break-word}",
      ".cz .cz-s .cz-so small{display:block;color:var(--mut);font-size:12px;margin-top:2px}",
      ".cz .cz-s .cz-t{font-weight:800;font-variant-numeric:tabular-nums;white-space:nowrap}",
      ".cz .iyi{color:var(--good)}.cz .kotu{color:var(--al2)}",
      ".cz .cz-filtre{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;padding:6px 0 8px}",
      ".cz .cz-filtre::-webkit-scrollbar{display:none}",
      ".cz .cz-filtre button{flex:none;padding:6px 11px;border-radius:999px;background:var(--panel2);color:var(--txt2);font-size:12.5px;font-weight:700}",
      ".cz .cz-filtre button.on{background:var(--inkbg);color:var(--txt);box-shadow:inset 0 0 0 1.5px var(--ink2)}",
      ".cz .cz-bos{text-align:center;color:var(--mut);padding:18px 8px;font-size:14px}",
      ".cz .cz-alt{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:12px}",
      ".cz .cz-alt .btn{margin:0}",
      ".cz-serit{display:flex;align-items:center;gap:12px;border-radius:16px;padding:12px 14px;margin:0 0 12px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line2);cursor:pointer}",
      ".cz-serit .cz-si{flex:none;width:40px;height:40px;border-radius:12px;display:grid;place-items:center;color:#fff;background:linear-gradient(145deg,#8a68f2,#3a2a8a)}",
      ".cz-serit .cz-si svg{width:20px;height:20px}",
      ".cz-serit .cz-ss{flex:1;min-width:0}.cz-serit .cz-ss b{display:block;font-size:14.5px}.cz-serit .cz-ss small{display:block;color:var(--mut);font-size:12.5px;margin-top:1px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".cz-serit .cz-ok{color:var(--mut);font-size:20px}"
    ].join("\n");
    var st = document.createElement("style"); st.id = "cz-stil"; st.textContent = css; document.head.appendChild(st);
  })();

  var CZ = { saat: 24, v: null, filtre: null };
  async function cuzdanEkrani() {
    if (!CZ.v) yukleniyor("Cüzdan");
    try { CZ.v = await API.rpc("cuzdan_hareketleri", { p_saat: CZ.saat }); ciz(); }
    catch (err) {
      iskelet("Cüzdan", '<div class="kart"><p class="alt">' + esc(typeof hataCevir === "function" ? hataCevir(err.message) : err.message) + '</p></div>', { geri: true });
    }
  }
  window.cuzdanEkrani = cuzdanEkrani;
  window.czSaat = function (s) { CZ.saat = s; CZ.filtre = null; cuzdanEkrani(); };
  window.czFiltre = function (t) { CZ.filtre = CZ.filtre === t ? null : t; ciz(); };

  function ciz() {
    var v = CZ.v || {}, gr = v.gruplar || [], ls = v.liste || [];
    var donem = { 24: "son 24 saat", 72: "son 3 gün", 168: "son 7 gün" }[v.saat] || ("son " + v.saat + " saat");
    var net = Number(v.giris || 0) - Number(v.cikis || 0);
    var h = '<div class="cz">';
    h += '<section class="cz-ust"><small>Cüzdanın</small><b class="cz-para">' + tl(v.para) + '</b>' +
      '<div class="cz-uc"><div><small>Gelen · ' + esc(donem) + '</small><b>+' + tl(v.giris) + '</b></div><div><small>Giden</small><b>−' + tl(v.cikis) + '</b></div><div><small>Net</small><b>' + (net >= 0 ? "+" : "−") + tl(Math.abs(net)) + '</b></div></div>' +
      (Number(v.vergi || 0) > 0 ? '<small style="margin-top:10px">Gelen tutarlar nettir; kaynağında ayrıca ' + tl(v.vergi) + ' vergi kesildi (maaş gelir vergisi, temettü stopajı, tapu harcı).</small>' : '') + '</section>';
    if (typeof window.vergiRehberiEkrani === "function") {
      h += '<div class="cz-serit" role="button" tabindex="0" onclick="ekranAc(vergiRehberiEkrani)"><span class="cz-si" style="background:linear-gradient(145deg,#e8cf8f,#9a7630);color:#1b1607">₺</span><span class="cz-ss"><b>Param nereye gitti?</b><small>Vergiler, kesintiler ve paranın şu an durduğu yerler</small></span><span class="cz-ok">›</span></div>';
    }
    h += '<div class="cz-sec">' + [[24, "Son 24 saat"], [72, "3 gün"], [168, "7 gün"]].map(function (x) {
      return '<button type="button" class="' + (Number(v.saat) === x[0] ? "on" : "") + '" onclick="czSaat(' + x[0] + ')">' + x[1] + '</button>';
    }).join("") + '</div>';
    if (gr.length) {
      var mx = Math.max.apply(null, gr.map(function (g) { return Number(g.giris) + Number(g.cikis); })) || 1;
      h += '<section class="cz-kutu"><h3>Para nereden geldi, nereye gitti?</h3>' + gr.map(function (g) {
        var gi = Number(g.giris), ci = Number(g.cikis), n = gi - ci;
        return '<div class="cz-g" role="button" tabindex="0" style="cursor:pointer" onclick="czFiltre(\'' + esc(g.tur) + '\')"><div class="cz-gb"><span><b>' + esc(turAd(g.tur)) + '</b><small>' + Number(g.adet) + ' işlem' + (turAlt(g.tur) ? ' · ' + esc(turAlt(g.tur)) : '') + '</small></span>' +
          '<em class="' + (n >= 0 ? "iyi" : "kotu") + '">' + (n >= 0 ? "+" : "−") + tl(Math.abs(n)) + (gi && ci ? '<small style="display:block;color:var(--mut)">+' + tl(gi) + ' / −' + tl(ci) + '</small>' : "") + '</em></div>' +
          '<div class="cz-cubuk"><i class="g" style="width:' + (gi / mx * 100).toFixed(1) + '%"></i><i class="c" style="width:' + (ci / mx * 100).toFixed(1) + '%"></i></div></div>';
      }).join("") + '<div style="height:8px"></div></section>';
    }
    var goster = CZ.filtre ? ls.filter(function (x) { return x.tur === CZ.filtre; }) : ls;
    var turler = []; ls.forEach(function (x) { if (turler.indexOf(x.tur) < 0) turler.push(x.tur); });
    h += '<section class="cz-kutu"><h3>Bütün hareketler (' + Number(v.adet || 0) + ')</h3>' +
      (turler.length > 1 ? '<div class="cz-filtre"><button type="button" class="' + (CZ.filtre ? "" : "on") + '" onclick="czFiltre(null)">Hepsi</button>' + turler.map(function (t) {
        return '<button type="button" class="' + (CZ.filtre === t ? "on" : "") + '" onclick="czFiltre(\'' + esc(t) + '\')">' + esc(turAd(t)) + '</button>';
      }).join("") + '</div>' : "") +
      (goster.length ? goster.map(function (x) {
        var t = Number(x.tutar);
        return '<div class="cz-s"><div class="cz-so"><div>' + esc(x.aciklama || turAd(x.tur)) + '</div><small>' + esc(zaman(x.zaman)) + ' · ' + esc(turAd(x.tur)) + (Number(x.vergi) ? ' · vergi ' + tl(x.vergi) : '') + '</small></div>' +
          '<span class="cz-t ' + (t >= 0 ? "iyi" : "kotu") + '">' + (t >= 0 ? "+" : "−") + tl(Math.abs(t)) + '</span></div>';
      }).join("") : '<div class="cz-bos">Bu dönemde cüzdanına para girişi ya da çıkışı olmadı.</div>') +
      (Number(v.adet || 0) > ls.length ? '<p class="kucuk" style="color:var(--mut);padding:4px 0 12px">Son ' + ls.length + ' hareket gösteriliyor; özet yukarıda bütün hareketleri kapsar.</p>' : '') +
      '</section>';
    h += '<div class="cz-alt">' + (typeof mobilSubeEkrani === "function" ? '<button class="btn ikinci" onclick="ekranAc(mobilSubeEkrani)">Mobil Şube</button>' : '<button class="btn ikinci" onclick="sekmeAc(\'hayat\')">Hayat</button>') +
      (typeof magazaEkrani === "function" ? '<button class="btn altin" onclick="ekranAc(magazaEkrani)">Mağaza · ₺ ekle</button>' : '<button class="btn ikinci" onclick="sekmeAc(\'hayat\')">Hayat</button>') + '</div>';
    h += '<p class="kucuk" style="color:var(--mut);text-align:center;margin:0 0 16px">Bankadaki hareketler Mobil Şube\'de; şirket kasası hareketleri şirketin Finans sayfasındadır.</p></div>';
    iskelet("Cüzdan", h, { geri: true });
  }

  // Hayat ekranına kısayol şeridi (son 24 saat özeti)
  var IKON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7h11l-3-3M17 17H6l3 3"/></svg>';
  var son = 0;
  function hayatSerit() {
    if (Date.now() - son < 1500) return; son = Date.now();
    API.rpc("cuzdan_hareketleri", { p_saat: 24 }).then(function (v) {
      var ic = document.getElementById("icerik"), h1 = document.querySelector("header.ust h1");
      if (!ic || !h1 || h1.textContent.trim() !== "Hayat" || document.getElementById("czHayatSerit")) return;
      var el = document.createElement("div");
      el.id = "czHayatSerit"; el.className = "cz-serit"; el.setAttribute("role", "button"); el.tabIndex = 0;
      el.onclick = function () { ekranAc(cuzdanEkrani); };
      el.innerHTML = '<span class="cz-si">' + IKON + '</span><span class="cz-ss"><b>Cüzdan hareketleri</b><small>Son 24 saat: +' + tl(v.giris) + ' gelen · −' + tl(v.cikis) + ' giden · ' + Number(v.adet || 0) + ' işlem</small></span><span class="cz-ok">›</span>';
      var hz = ic.querySelector("[data-pa-hizli]");
      if (hz && hz.parentNode) hz.parentNode.insertBefore(el, hz.nextSibling); else ic.insertBefore(el, ic.firstChild);
    }).catch(function () {});
  }
  if (typeof iskelet === "function") {
    var eski = iskelet;
    iskelet = window.iskelet = function (baslik) {
      var r = eski.apply(this, arguments);
      try { if (baslik === "Hayat" && arguments[1] && String(arguments[1]).indexOf("Yükleniyor") < 0) setTimeout(hayatSerit, 40); } catch (_) {}
      return r;
    };
  }
})();
