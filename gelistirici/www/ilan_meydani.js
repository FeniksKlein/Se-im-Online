/* Seçim Online — İlan Meydanı (25.10.2026)
   Oyuncudan oyuncuya ilan pazarı: konut, işyeri, arsa, satılık şirket, şirket hissesi.
   Kategoriler, vitrin, arama ve filtre, ilan detayı, teklif / karşı teklif / hemen al,
   Güvenli Ödeme (teklif tutarı bloke edilir), ilan ver, öne çıkar, ilanlarım ve teklifler.
   Para ve devir işlemleri yalnız sunucu fonksiyonlarıyla yapılır; bu dosya arayüzdür.
   Sunucu: gelistirici/sql/139_ilan_meydani.sql */
(function () {
  "use strict";
  if (window.ILAN_MEYDANI) return;
  window.ILAN_MEYDANI = true;

  /* ---------------- yardımcılar ---------------- */
  var esc = function (x) {
    return String(x == null ? "" : x).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  };
  var arg = function (s) { return esc(JSON.stringify(String(s == null ? "" : s))); };
  var sayi = function (n) { return Number(n || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }); };
  var tl = function (n) { return n == null || isNaN(Number(n)) ? "—" : sayi(n) + " ₺"; };
  var payYaz = function (p) { return "%" + Number(p || 0).toLocaleString("tr-TR", { maximumFractionDigits: 2 }); };
  var parse = function (v) {
    v = String(v == null ? "" : v).trim().replace(/\s/g, "").replace(/₺/g, "");
    if (/^\d{1,3}(\.\d{3})+(,\d+)?$/.test(v)) v = v.replace(/\./g, "").replace(",", ".");
    else v = v.replace(",", ".");
    var n = Number(v);
    return isFinite(n) ? n : NaN;
  };
  var hata = function (err) {
    var m = err && err.message ? err.message : String(err || "Beklenmeyen hata");
    return typeof hataCevir === "function" ? hataCevir(m) : m;
  };
  var bildir = function (m, h) { if (typeof toast === "function") toast(m, h); };
  var $id = function (x) { return document.getElementById(x); };
  var ekran = function (baslik, govde) {
    iskelet(baslik, govde, { geri: typeof D !== "undefined" && !!(D.yigin && D.yigin.length) });
  };
  var sor = function (baslik, metin, buton, tehlike) {
    return typeof onayla === "function" ? onayla(baslik, metin, buton, tehlike) : Promise.resolve(confirm(metin));
  };
  var kapat = function () { if (typeof modalKapat === "function") modalKapat(); };
  var simdi = function () { return Date.now(); };
  var tarihKisa = function (ts) {
    if (!ts) return "";
    var d = new Date(ts), b = new Date();
    var gun = Math.floor((new Date(b.getFullYear(), b.getMonth(), b.getDate()) - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 864e5);
    if (gun <= 0) return "Bugün";
    if (gun === 1) return "Dün";
    return d.toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
  };
  var kalan = function (ts) {
    if (!ts) return "";
    var ms = new Date(ts).getTime() - simdi();
    if (ms <= 0) return "süresi doldu";
    var dk = Math.round(ms / 60000);
    if (dk < 60) return dk + " dk kaldı";
    var sa = Math.round(dk / 60);
    if (sa < 48) return sa + " saat kaldı";
    return Math.round(sa / 24) + " gün kaldı";
  };
  async function calis(btn, fn, basari) {
    var b = btn && btn.tagName ? btn : null;
    if (b) { if (b.disabled) return; b.disabled = true; }
    try { var r = await fn(); if (basari) bildir(typeof basari === "function" ? basari(r) : basari); return r; }
    catch (err) { bildir(hata(err), true); throw err; }
    finally { if (b) b.disabled = false; }
  }
  function imModal(html) {
    var m = modal('<div class="im-modal">' + html + '</div>');
    var ilk = m.querySelector("input:not([type=checkbox]),select,textarea");
    if (ilk) setTimeout(function () { try { ilk.focus(); } catch (_) {} }, 60);
    return m;
  }
  function iller() {
    try { if (typeof VERI !== "undefined" && VERI.iller) return VERI.iller.slice().sort(function (a, b) { return a.ad.localeCompare(b.ad, "tr"); }); } catch (_) {}
    return [];
  }
  async function cuzdanTazele() { if (typeof durumYenile === "function") { try { await durumYenile(); } catch (_) {} } }

  var KAT = {
    konut: { ad: "Konut", alt: "Satılık daire", gorsel: "daire" },
    isyeri: { ad: "İşyeri", alt: "Satılık dükkân", gorsel: "dukkan" },
    arsa: { ad: "Arsa", alt: "Satılık arsa", gorsel: "arsa" },
    sirket: { ad: "Satılık şirket", alt: "Devren satılık işletmeler", gorsel: "sirket" },
    hisse: { ad: "Şirket hissesi", alt: "Ortaklık payları", gorsel: "hisse" },
    muteahhit: { ad: "Müteahhitten sıfır", alt: "Yeni projelerden konut ve dükkân", gorsel: "daire" }
  };
  var KAT_BASLIK = { tumu: "Tüm ilanlar", emlak: "Emlak ilanları", sirketler: "Şirket ilanları" };
  var katAd = function (k) { return (KAT[k] && KAT[k].ad) || KAT_BASLIK[k] || "İlanlar"; };
  var SIRALA = [["akilli", "Önerilen"], ["yeni", "En yeni"], ["ucuz", "En ucuz"], ["pahali", "En pahalı"]];

  /* ---------------- ilan görselleri (çizim; fotoğraf yerine) ---------------- */
  var PAL = [["#2E5A8C", "#142B4A"], ["#5B3F8C", "#241843"], ["#1F6B63", "#0D3330"], ["#8C4A2E", "#40200E"], ["#3B4F7A", "#18213C"], ["#6E2F55", "#331327"]];
  function gorsel(tip, tohum, pay) {
    var i = Math.abs(Number(tohum) || 0) % PAL.length, p = PAL[i], gid = "imgr" + i;
    var s = '<svg viewBox="0 0 120 90" preserveAspectRatio="xMidYMid slice" aria-hidden="true" focusable="false">' +
      '<defs><linearGradient id="' + gid + '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + p[0] + '"/><stop offset="1" stop-color="' + p[1] + '"/></linearGradient></defs>' +
      '<rect width="120" height="90" fill="url(#' + gid + ')"/>';
    var n = Number(tohum) || 0;
    if (tip === "daire") {
      s += '<circle cx="98" cy="17" r="7" fill="#fff" opacity=".16"/><rect y="79" width="120" height="11" fill="#000" opacity=".22"/>' +
        '<rect x="12" y="48" width="22" height="31" fill="#C9D2E6" opacity=".55"/><rect x="34" y="20" width="52" height="59" rx="2" fill="#EDF1F8" opacity=".94"/>';
      for (var r = 0; r < 5; r++) for (var c = 0; c < 4; c++) {
        var yan = ((r * 4 + c + n) % 5) === 0;
        s += '<rect x="' + (39 + c * 11.5) + '" y="' + (26 + r * 9) + '" width="7" height="5" rx="1" fill="' + (yan ? "#F6D88A" : "#2B3A5C") + '"/>';
      }
      s += '<rect x="55" y="69" width="10" height="10" fill="#2B3A5C"/><rect x="88" y="56" width="20" height="23" fill="#B8C3DA" opacity=".45"/>';
    } else if (tip === "dukkan") {
      s += '<rect y="79" width="120" height="11" fill="#000" opacity=".22"/><rect x="20" y="30" width="80" height="49" fill="#EFE8DC"/>' +
        '<rect x="34" y="20" width="52" height="10" rx="2" fill="#24314F"/><rect x="44" y="23.5" width="32" height="3" rx="1.5" fill="#F2B33D"/>';
      for (var k = 0; k < 8; k++) s += '<rect x="' + (20 + k * 10) + '" y="34" width="10" height="10" fill="' + (k % 2 ? "#F4EFE7" : "#C8463D") + '"/>';
      s += '<path d="M20 44h80l-3 4H23z" fill="#000" opacity=".12"/><rect x="26" y="50" width="42" height="22" fill="#8FB6D9" opacity=".85"/>' +
        '<rect x="74" y="50" width="18" height="29" fill="#5A4636"/><circle cx="88" cy="65" r="1.2" fill="#F2B33D"/>';
    } else if (tip === "arsa") {
      s += '<circle cx="24" cy="18" r="8" fill="#FFE6A6" opacity=".35"/><rect y="50" width="120" height="40" fill="#3E6B3A"/>' +
        '<path d="M0 62 L120 56 M0 72 L120 64 M0 84 L120 74" stroke="#6FA068" stroke-width="1.4" opacity=".7"/>';
      for (var f = 0; f < 10; f++) s += '<rect x="' + (6 + f * 12) + '" y="52" width="2" height="9" fill="#D9C6A0"/>';
      s += '<path d="M6 55h110" stroke="#D9C6A0" stroke-width="1.2"/><rect x="90" y="36" width="3" height="16" fill="#5B3B22"/>' +
        '<circle cx="91.5" cy="33" r="10" fill="#2C5A2A"/><path d="M34 34v24" stroke="#EEE" stroke-width="1.4"/><path d="M34 34l12 4-12 4z" fill="#F2B33D"/>';
    } else if (tip === "sirket") {
      s += '<rect y="79" width="120" height="11" fill="#000" opacity=".22"/><rect x="20" y="40" width="24" height="39" fill="#B9C6DE" opacity=".75"/>' +
        '<rect x="46" y="12" width="30" height="67" fill="#DCE6F5"/><rect x="80" y="30" width="22" height="49" fill="#C6D1E6" opacity=".85"/>';
      for (var h = 0; h < 10; h++) s += '<rect x="49" y="' + (16 + h * 6) + '" width="24" height="3" fill="' + (((h + n) % 4) === 0 ? "#F6D88A" : "#5C7BAF") + '" opacity=".75"/>';
      for (var w = 0; w < 5; w++) s += '<rect x="24" y="' + (45 + w * 6) + '" width="16" height="2.5" fill="#4B6390" opacity=".7"/><rect x="84" y="' + (35 + w * 8) + '" width="14" height="3" fill="#4B6390" opacity=".7"/>';
    } else {
      var oran = Math.max(1, Math.min(100, Number(pay) || 25)) / 100, cx = 44, cy = 45, rr = 26;
      s += '<circle cx="' + cx + '" cy="' + cy + '" r="' + rr + '" fill="#E6EBF5" opacity=".92"/>';
      if (oran >= 0.999) s += '<circle cx="' + cx + '" cy="' + cy + '" r="' + rr + '" fill="#F2B33D"/>';
      else {
        var a = oran * Math.PI * 2 - Math.PI / 2, x2 = cx + rr * Math.cos(a), y2 = cy + rr * Math.sin(a);
        s += '<path d="M' + cx + ' ' + cy + ' L' + cx + ' ' + (cy - rr) + ' A' + rr + ' ' + rr + ' 0 ' + (oran > 0.5 ? 1 : 0) + ' 1 ' + x2.toFixed(1) + ' ' + y2.toFixed(1) + ' Z" fill="#F2B33D"/>';
      }
      s += '<rect x="80" y="52" width="8" height="22" rx="1" fill="#fff" opacity=".55"/><rect x="92" y="42" width="8" height="32" rx="1" fill="#fff" opacity=".7"/><rect x="104" y="30" width="8" height="44" rx="1" fill="#fff" opacity=".85"/>';
    }
    return s + "</svg>";
  }

  /* ---------------- stil ---------------- */
  function stilKur() {
    if ($id("im-stil")) return;
    var css = [
      ".im{--imr:14px}",
      ".im .im-arama{display:flex;gap:8px;margin:0 0 12px}",
      ".im .im-arama input{flex:1;min-width:0;background:var(--panel2);border:1px solid var(--line2);border-radius:12px;padding:11px 12px;color:var(--txt);font-size:15px}",
      ".im .im-arama .btn{flex:none;width:auto;margin:0;padding:10px 14px}",
      ".im .im-hesap{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 -16px 14px;padding:0 16px}",
      ".im .im-hesap::-webkit-scrollbar{display:none}",
      ".im .im-hesap button{flex:none;padding:8px 12px;border-radius:999px;background:var(--panel);color:var(--txt2);font-size:13px;font-weight:700;white-space:nowrap}",
      ".im .im-hesap button.ana{background:var(--ink2);color:#0E1530}",
      ".im .im-hesap button i{font-style:normal;display:inline-grid;place-items:center;min-width:18px;height:18px;border-radius:9px;background:var(--al);color:#fff;font-size:11px;margin-left:6px;padding:0 5px}",
      ".im h3.im-bas{font-size:15px;margin:16px 2px 8px;display:flex;justify-content:space-between;align-items:baseline;gap:8px}",
      ".im h3.im-bas small{font-size:12.5px;color:var(--mut);font-weight:500}",
      ".im h3.im-bas button{font-size:13px;color:var(--ink2);font-weight:700;background:none;padding:0}",
      ".im .im-katlar{display:grid;grid-template-columns:1fr 1fr;gap:8px}",
      ".im .im-kat{display:flex;align-items:center;gap:10px;background:var(--panel);border-radius:var(--imr);padding:8px 10px 8px 8px;text-align:left;min-width:0}",
      ".im .im-kat .im-kf{flex:none;width:44px;height:34px;border-radius:8px;overflow:hidden}",
      ".im .im-kat .im-kf svg{width:100%;height:100%;display:block}",
      ".im .im-kat b{display:block;font-size:13.5px;line-height:1.2;overflow-wrap:anywhere}",
      ".im .im-kat small{display:block;font-size:12px;color:var(--mut)}",
      ".im .im-kat span{min-width:0}",
      ".im .im-acil{display:flex;align-items:center;justify-content:space-between;width:100%;margin-top:8px;background:var(--albg);color:var(--al2);border-radius:var(--imr);padding:11px 14px;font-weight:700;font-size:14px}",
      ".im .im-vitrin{display:grid;grid-template-columns:1fr 1fr;gap:10px}",
      ".im .im-vk{background:var(--panel);border-radius:var(--imr);overflow:hidden;text-align:left;display:flex;flex-direction:column;min-width:0}",
      ".im .im-vk .im-vf{position:relative;aspect-ratio:4/3;display:block}",
      ".im .im-vk .im-vf svg{width:100%;height:100%;display:block}",
      ".im .im-vk .im-vb{padding:8px 10px 10px;min-width:0;display:block}",
      ".im .im-vk .im-vb b{display:block;font-family:var(--disp);font-size:17px;font-variant-numeric:tabular-nums;line-height:1.1}",
      ".im .im-vk .im-vb span{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;font-size:13px;line-height:1.3;margin-top:3px}",
      ".im .im-vk .im-vb small{display:block;color:var(--mut);font-size:11.5px;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".im .im-vk .im-et{position:absolute;left:6px;top:6px;display:flex;gap:4px;flex-wrap:wrap}",
      ".im .im-r,.im-modal .im-r{display:inline-block;padding:2px 6px;border-radius:6px;font-size:11px;font-weight:800;line-height:1.35;vertical-align:middle}",
      ".im .im-r.acil{background:#E0343E;color:#fff}.im .im-r.dus{background:rgba(52,201,138,.16);color:var(--good)}",
      ".im .im-r.vit{background:#F2B33D;color:#2A1D04}.im .im-r.sifir{background:#2F8F6B;color:#fff}.im .im-r.ben{background:var(--inkbg);color:var(--ink2)}",
      ".im .im-r.gri{background:var(--panel2);color:var(--txt2)}",
      ".im .im-liste{display:flex;flex-direction:column;gap:8px}",
      ".im .im-satir{display:flex;gap:11px;background:var(--panel);border-radius:var(--imr);padding:8px;text-align:left;border:1.5px solid transparent;width:100%;min-width:0}",
      ".im .im-satir.renkli{border-color:#F2B33D;background:linear-gradient(180deg,rgba(242,179,61,.10),var(--panel) 60%)}",
      ".im .im-satir.renkli .im-sb{font-weight:800}",
      ".im .im-satir .im-sf{flex:none;width:96px;height:74px;border-radius:10px;overflow:hidden;position:relative;display:block}",
      ".im .im-satir .im-sf svg{width:100%;height:100%;display:block}",
      ".im .im-satir .im-si{flex:1;min-width:0;display:flex;flex-direction:column}",
      ".im .im-satir .im-sb{font-size:14px;font-weight:600;line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}",
      ".im .im-satir small{display:block;color:var(--mut);font-size:12px;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
      ".im .im-satir .im-sp{margin-top:auto;padding-top:4px;display:flex;align-items:center;gap:6px;flex-wrap:wrap}",
      ".im .im-satir .im-sp b{font-family:var(--disp);font-size:17px;font-variant-numeric:tabular-nums}",
      ".im .im-daha{width:100%;margin-top:10px}",
      ".im .im-bos{text-align:center;color:var(--mut);padding:26px 12px;font-size:14px;line-height:1.5;background:var(--panel);border-radius:var(--imr)}",
      ".im .im-filtre{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 -16px 10px;padding:0 16px}",
      ".im .im-filtre::-webkit-scrollbar{display:none}",
      ".im .im-filtre button{flex:none;padding:8px 12px;border-radius:999px;background:var(--panel);color:var(--txt2);font-size:13px;font-weight:700;white-space:nowrap;border:1.5px solid transparent}",
      ".im .im-filtre button.on{background:var(--inkbg);border-color:var(--ink2);color:var(--txt)}",
      ".im .im-sonuc{font-size:13px;color:var(--mut);margin:0 2px 8px}",
      ".im .im-df{border-radius:16px;overflow:hidden;aspect-ratio:4/3;position:relative;margin-bottom:12px;max-height:320px;width:100%}",
      ".im .im-df svg{width:100%;height:100%;display:block}",
      ".im .im-df .im-et{position:absolute;left:10px;top:10px;display:flex;gap:5px;flex-wrap:wrap}",
      ".im .im-df .im-no{position:absolute;right:10px;bottom:10px;background:rgba(0,0,0,.45);color:#fff;font-size:12px;padding:3px 8px;border-radius:7px;font-variant-numeric:tabular-nums}",
      ".im .im-fav{position:absolute;right:10px;top:10px;width:40px;height:40px;border-radius:50%;background:rgba(0,0,0,.42);color:#fff;font-size:20px;display:grid;place-items:center}",
      ".im .im-fav.on{color:#FF5A6A}",
      ".im .im-fiyat{font-family:var(--disp);font-weight:700;font-size:32px;line-height:1.05;font-variant-numeric:tabular-nums}",
      ".im .im-fiyat s{font-family:inherit;font-size:16px;color:var(--mut);margin-left:8px;font-weight:600}",
      ".im .im-dbas{font-size:18px;font-weight:700;line-height:1.3;margin:6px 0 4px}",
      ".im .im-yer{color:var(--mut);font-size:13px}",
      ".im .im-aks{display:flex;gap:8px;margin:14px 0}",
      ".im .im-aks .btn{flex:1;margin:0;padding:13px 10px;font-size:15px}",
      ".im .im-kutu{background:var(--panel);border-radius:var(--imr);padding:4px 14px;margin-bottom:12px}",
      ".im .im-kutu>h4{font-size:13px;color:var(--mut);font-weight:600;padding:12px 0 4px}",
      ".im .im-tablo div{display:flex;justify-content:space-between;gap:12px;padding:9px 0;border-top:1px solid var(--line);font-size:14px}",
      ".im .im-tablo div:first-child{border-top:0}",
      ".im .im-tablo span{color:var(--mut)}.im .im-tablo b{text-align:right;font-weight:600}",
      ".im .im-aciklama{white-space:pre-wrap;font-size:14.5px;line-height:1.55;padding:6px 0 14px}",
      ".im .im-satici{display:flex;align-items:center;gap:12px;padding:12px 0}",
      ".im .im-satici .im-av{flex:none;width:44px;height:44px;border-radius:50%;display:grid;place-items:center;background:var(--inkbg);color:var(--ink2);font-family:var(--disp);font-weight:700;font-size:19px}",
      ".im .im-satici b{display:block;font-size:15px}.im .im-satici small{display:block;color:var(--mut);font-size:12.5px}",
      ".im .im-guven{display:flex;gap:10px;background:rgba(52,201,138,.09);border:1px solid rgba(52,201,138,.28);border-radius:var(--imr);padding:11px 13px;font-size:13px;line-height:1.45;color:var(--txt2);margin-bottom:12px}",
      ".im .im-guven b{color:var(--good)}",
      ".im .im-durum{background:var(--inkbg);border-radius:var(--imr);padding:12px 14px;margin-bottom:12px;font-size:14px;line-height:1.45}",
      ".im .im-durum.uyari{background:var(--albg);color:var(--al2)}",
      ".im .im-dg{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}.im .im-dg .btn{flex:1 1 110px;margin:0;padding:10px;font-size:14px}",
      ".im .im-teklif{padding:12px 0;border-top:1px solid var(--line)}",
      ".im .im-kutu>h4+.im-teklif{border-top:0}",
      ".im .im-teklif .im-tu{display:flex;justify-content:space-between;align-items:baseline;gap:8px}",
      ".im .im-teklif .im-tu b{font-family:var(--disp);font-size:18px;font-variant-numeric:tabular-nums}",
      ".im .im-teklif small{color:var(--mut);font-size:12.5px;display:block;margin-top:2px}",
      ".im .im-teklif q{display:block;font-size:13px;color:var(--txt2);margin-top:4px;quotes:none}",
      ".im .im-sekme{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 -16px 12px;padding:6px 16px 8px;position:sticky;top:-14px;z-index:3;background:var(--bg)}",
      ".im .im-sekme::-webkit-scrollbar{display:none}",
      ".im .im-sekme button{flex:none;padding:8px 13px;border-radius:999px;background:var(--panel);color:var(--txt2);font-size:13.5px;font-weight:700;white-space:nowrap}",
      ".im .im-sekme button.on{background:var(--txt);color:var(--bg)}",
      ".im .im-sekme button i{font-style:normal;display:inline-grid;place-items:center;min-width:18px;height:18px;border-radius:9px;background:var(--al);color:#fff;font-size:11px;margin-left:6px;padding:0 5px}",
      ".im .im-ipucu,.im-modal .im-ipucu{font-size:13px;color:var(--mut);line-height:1.45;margin:4px 2px 10px}",
      ".im .im-varlik{display:flex;align-items:center;gap:11px;padding:12px 0;border-top:1px solid var(--line)}",
      ".im .im-kutu>h4+.im-varlik{border-top:0}",
      ".im .im-varlik .im-vk2{flex:none;width:58px;height:44px;border-radius:9px;overflow:hidden}",
      ".im .im-varlik .im-vk2 svg{width:100%;height:100%;display:block}",
      ".im .im-varlik .im-vo{flex:1;min-width:0}.im .im-varlik .im-vo b{display:block;font-size:14.5px}",
      ".im .im-varlik .im-vo small{display:block;color:var(--mut);font-size:12.5px}",
      ".im .im-varlik .im-vd{display:flex;flex-direction:column;gap:6px;flex:none}",
      ".im .im-varlik .im-vd .btn{margin:0;padding:8px 12px;font-size:13px;width:auto;min-height:0}",
      ".im .im-form .alan,.im-modal .alan{margin-bottom:12px}",
      ".im .im-form label,.im-modal label{display:block;font-size:12.5px;color:var(--mut);margin-bottom:5px}",
      ".im .im-form input,.im .im-form textarea,.im .im-form select,.im-modal input,.im-modal select,.im-modal textarea{width:100%;background:var(--panel2);border:1px solid var(--line2);border-radius:11px;padding:11px 12px;color:var(--txt);font-size:15px;font-family:inherit}",
      ".im .im-form textarea,.im-modal textarea{min-height:92px;resize:vertical}",
      ".im .im-cips,.im-modal .im-cips{display:flex;gap:6px;flex-wrap:wrap;margin:6px 0 2px}",
      ".im .im-cips button,.im-modal .im-cips button{padding:7px 11px;border-radius:999px;background:var(--panel2);font-size:12.5px;font-weight:700;color:var(--txt2)}",
      ".im .im-anahtar,.im-modal .im-anahtar{display:flex !important;align-items:center;gap:10px;padding:10px 0;font-size:14px !important;margin-bottom:0 !important;line-height:1.35;color:var(--txt) !important}",
      ".im .im-anahtar input,.im-modal .im-anahtar input{width:22px !important;height:22px;flex:none;accent-color:var(--ink2)}",
      ".im .im-anahtar small,.im-modal .im-anahtar small{display:block;color:var(--mut);font-size:12.5px}",
      ".im .im-paket{display:flex !important;gap:10px;align-items:flex-start;background:var(--panel2);border-radius:12px;padding:11px 12px;margin-bottom:8px;border:1.5px solid transparent;cursor:pointer;color:var(--txt) !important;font-size:14px !important}",
      ".im .im-paket.on{border-color:var(--ink2);background:var(--inkbg)}",
      ".im .im-paket input{width:20px !important;height:20px;flex:none;margin-top:1px;accent-color:var(--ink2)}",
      ".im .im-paket b,.im-modal .im-paket b{display:block;font-size:14px}.im .im-paket small,.im-modal .im-paket small{display:block;color:var(--mut);font-size:12.5px;line-height:1.35;margin-top:2px}",
      ".im .im-paket em,.im-modal .im-paket em{font-style:normal;font-weight:800;margin-left:auto;white-space:nowrap;font-variant-numeric:tabular-nums}",
      ".im-modal .im-paket{display:flex;gap:10px;align-items:flex-start;background:var(--panel2);border-radius:12px;padding:11px 12px;margin-bottom:8px;width:100%;text-align:left;color:var(--txt)}",
      ".im .im-toplam,.im-modal .im-toplam{background:var(--panel2);border-radius:12px;padding:10px 13px;font-size:14px;line-height:1.7;margin:8px 0 12px}",
      ".im .im-toplam div,.im-modal .im-toplam div{display:flex;justify-content:space-between;gap:10px}",
      ".im .im-toplam b,.im-modal .im-toplam b{font-variant-numeric:tabular-nums}",
      ".im .im-toplam .t,.im-modal .im-toplam .t{border-top:1px solid var(--line2);margin-top:4px;padding-top:4px;font-weight:800}",
      ".im .im-hata,.im-modal .im-hata{color:var(--al2);font-size:13px;margin-top:5px}",
      ".im-modal h3{font-size:19px;margin-bottom:4px}",
      ".im-modal .im-dg{display:flex;gap:8px;margin-top:6px}.im-modal .im-dg .btn{flex:1;margin:0}",
      ".im .im-link{background:none;padding:0;color:var(--ink2);font-weight:700;font-size:13px;text-align:left}",
      "@media (min-width:560px){.im .im-vitrin{grid-template-columns:repeat(3,1fr)}.im .im-katlar{grid-template-columns:repeat(3,1fr)}}",
      "@media (max-width:350px){.im .im-satir .im-sf{width:82px;height:64px}.im .im-fiyat{font-size:28px}.im .im-kat{gap:8px;padding:7px}.im .im-kat .im-kf{width:36px;height:28px}.im .im-kat b{font-size:13px}}",
      "@media (prefers-reduced-motion:no-preference){.im .im-satir,.im .im-vk,.im .im-kat{transition:transform .12s}.im .im-satir:active,.im .im-vk:active,.im .im-kat:active{transform:scale(.985)}}"
    ].join("\n");
    var st = document.createElement("style"); st.id = "im-stil"; st.textContent = css;
    document.head.appendChild(st);
  }

  /* ---------------- ortak parçalar ---------------- */
  function rozetler(x, yer) {
    var r = "";
    if (x.acil) r += '<span class="im-r acil">Acil</span>';
    if (yer !== "vitrin" && x.vitrin) r += '<span class="im-r vit">Vitrin</span>';
    if (x.dustu) r += '<span class="im-r dus">↓ Fiyatı düştü</span>';
    if (x.benim) r += '<span class="im-r ben">Senin ilanın</span>';
    return r;
  }
  function satir(x) {
    return '<button type="button" class="im-satir' + (x.renkli ? " renkli" : "") + '" onclick="imAc(' + Number(x.id) + ')">' +
      '<span class="im-sf">' + gorsel(x.gorsel, x.id, x.pay) + '</span>' +
      '<span class="im-si"><span class="im-sb">' + esc(x.baslik) + '</span>' +
      '<small>' + esc(x.ozellik || "") + '</small>' +
      '<small>' + esc(x.il || "Türkiye") + " · " + esc(tarihKisa(x.siralama || x.tarih)) + '</small>' +
      '<span class="im-sp"><b>' + tl(x.fiyat) + '</b>' + rozetler(x) + '</span></span></button>';
  }
  function vitrinKart(x) {
    return '<button type="button" class="im-vk" onclick="imAc(' + Number(x.id) + ')">' +
      '<span class="im-vf">' + gorsel(x.gorsel, x.id, x.pay) + '<span class="im-et">' + rozetler(x, "vitrin") + '</span></span>' +
      '<span class="im-vb"><b>' + tl(x.fiyat) + '</b><span>' + esc(x.baslik) + '</span><small>' + esc(x.il || "Türkiye") + '</small></span></button>';
  }
  function mutKart(m) {
    return '<button type="button" class="im-vk" onclick="imMuteahhitAl(' + Number(m.bolum) + ',' + Number(m.fiyat) + ',' + Number(m.harc || 0) + ',' + arg(m.proje) + ')">' +
      '<span class="im-vf">' + gorsel(m.tur, m.yapi, null) + '<span class="im-et"><span class="im-r sifir">Sıfır</span></span></span>' +
      '<span class="im-vb"><b>' + tl(m.fiyat) + '</b><span>' + esc(m.proje) + ' · ' + (m.tur === "daire" ? "Daire" : "Dükkân") + '</span>' +
      '<small>' + esc(m.il) + ' · ' + esc(m.firma) + ' · ' + Number(m.adet) + ' adet</small></span></button>';
  }
  function bos(metin, dugme) {
    return '<div class="im-bos">' + metin + (dugme ? '<div style="margin-top:12px">' + dugme + '</div>' : '') + '</div>';
  }

  /* =====================================================================
     ANA SAYFA
     ===================================================================== */
  var IM = { ana: null, tarife: null };
  async function anaSayfa() {
    stilKur();
    if (!IM.ana) yukleniyor("İlan Meydanı");
    var v;
    try { v = await API.rpc("ilan_meydani", { p_filtre: {} }); }
    catch (err) { return ekran("İlan Meydanı", '<div class="im">' + bos(esc(hata(err)), '<button class="btn" onclick="ilanMeydaniEkrani()">Yeniden dene</button>') + '</div>'); }
    IM.ana = v; IM.tarife = v.tarife || IM.tarife;
    var k = v.kategoriler || {}, b = v.benim || {};
    var h = '<div class="im">';
    h += '<form class="im-arama" onsubmit="event.preventDefault();imAra(this.q.value)"><input name="q" type="search" enterkeyhint="search" placeholder="Daire, dükkân, şirket, il ara" aria-label="İlanlarda ara"><button class="btn" type="submit">Ara</button></form>';
    h += '<div class="im-hesap"><button type="button" class="ana" onclick="ilanVerEkrani()">+ İlan ver</button>' +
      '<button type="button" onclick="ilanHesabimEkrani(\'ilanlar\')">İlanlarım' + (b.aktif_ilan ? ' (' + Number(b.aktif_ilan) + ')' : '') + '</button>' +
      '<button type="button" onclick="ilanHesabimEkrani(\'gelen\')">Gelen teklifler' + (b.gelen ? '<i>' + Number(b.gelen) + '</i>' : '') + '</button>' +
      '<button type="button" onclick="ilanHesabimEkrani(\'giden\')">Tekliflerim' + (b.karsi ? '<i>' + Number(b.karsi) + '</i>' : (b.giden ? ' (' + Number(b.giden) + ')' : '')) + '</button>' +
      '<button type="button" onclick="ilanHesabimEkrani(\'favori\')">Favoriler' + ((b.favori || []).length ? ' (' + b.favori.length + ')' : '') + '</button></div>';
    h += '<h3 class="im-bas">Kategoriler <small>' + Number(k.toplam || 0) + ' ilan yayında</small></h3><div class="im-katlar">';
    ["konut", "isyeri", "arsa", "sirket", "hisse", "muteahhit"].forEach(function (kk) {
      h += '<button type="button" class="im-kat" onclick="imKategori(\'' + kk + '\')"><span class="im-kf">' + gorsel(KAT[kk].gorsel, kk.length, 30) + '</span>' +
        '<span><b>' + KAT[kk].ad + '</b><small>' + Number(k[kk] || 0) + ' ilan</small></span></button>';
    });
    h += '</div>';
    if (k.acil) h += '<button type="button" class="im-acil" onclick="imAcilListe()"><span>Acil satılıklar</span><span>' + Number(k.acil) + ' ilan ›</span></button>';
    h += '<h3 class="im-bas">Vitrin <small>Öne çıkarılan ilanlar</small></h3>';
    h += (v.vitrin || []).length ? '<div class="im-vitrin">' + v.vitrin.map(vitrinKart).join("") + '</div>'
      : bos('Vitrin şu an boş. İlanını vitrine taşıyıp İlan Meydanı’na giren herkesin ilk gördüğü ilan yap.', '<button class="btn ikinci" onclick="ilanVerEkrani()">İlan ver</button>');
    if ((v.muteahhit || []).length) {
      h += '<h3 class="im-bas">Müteahhitten sıfır <button type="button" onclick="imKategori(\'muteahhit\')">Tümü ›</button></h3>' +
        '<div class="im-vitrin">' + v.muteahhit.slice(0, 4).map(mutKart).join("") + '</div>';
    }
    h += '<h3 class="im-bas">Son ilanlar <button type="button" onclick="imKategori(\'tumu\')">Tümü ›</button></h3>';
    h += (v.liste || []).length ? '<div class="im-liste">' + v.liste.slice(0, 10).map(satir).join("") + '</div>'
      : bos('Henüz ilan yok. İlk ilanı sen ver: evini, dükkânını, şirketini ya da hisseni satışa çıkar.', '<button class="btn" onclick="ilanVerEkrani()">İlan ver</button>');
    h += '<p class="im-ipucu" style="margin-top:14px">İlan ücretleri ve öne çıkarma paketleri Hazine’ye gelir yazılır. Emlak satışlarında alıcı ve satıcıdan %2 tapu harcı, şirket devirlerinde satıcıdan damga vergisi alınır.</p>';
    h += '</div>';
    ekran("İlan Meydanı", h);
  }
  window.ilanMeydaniEkrani = function () { IM.ana = null; return anaSayfa(); };
  window.imAc = function (id) { return ekranAc(function () { return detay(Number(id)); }); };
  window.imKategori = function (k) { var f = { kategori: k, sirala: "akilli", sayfa: 1 }; return ekranAc(function () { return liste(f); }); };
  window.imAcilListe = function () { var f = { kategori: "tumu", acil: true, sirala: "akilli", sayfa: 1 }; return ekranAc(function () { return liste(f); }); };
  window.imAra = function (q) {
    q = String(q || "").trim();
    var f = { kategori: "tumu", ara: q, sirala: "akilli", sayfa: 1 };
    return ekranAc(function () { return liste(f); });
  };
  window.imSaticiIlanlari = function (kad) { var f = { kategori: "tumu", satici: kad, sirala: "yeni", sayfa: 1 }; return ekranAc(function () { return liste(f); }); };

  /* =====================================================================
     LİSTE (kategori / arama)
     ===================================================================== */
  var AKTIF = null;
  function filtreParam(f) {
    var p = { kategori: f.kategori || "tumu", sirala: f.sirala || "akilli", sayfa: f.sayfa || 1 };
    ["il", "min", "max", "sektor", "ara", "satici"].forEach(function (k) { if (f[k] !== undefined && f[k] !== null && f[k] !== "") p[k] = f[k]; });
    if (f.acil) p.acil = true;
    return p;
  }
  async function liste(f, ekle) {
    stilKur();
    AKTIF = f;
    var baslik = f.satici ? f.satici + " ilanları" : f.acil ? "Acil satılıklar" : f.ara ? "“" + f.ara + "” araması" : katAd(f.kategori);
    if (!ekle) { f.sayfa = 1; if (!f._v) yukleniyor(baslik); }
    var v;
    try { v = await API.rpc("ilan_meydani", { p_filtre: filtreParam(f) }); }
    catch (err) { return ekran(baslik, '<div class="im">' + bos(esc(hata(err))) + '</div>'); }
    if (AKTIF !== f) return;
    f._v = v; IM.tarife = v.tarife || IM.tarife;
    f._liste = (ekle && f._liste ? f._liste : []).concat(v.liste || []);
    listeCiz(f, baslik);
  }
  function listeCiz(f, baslik) {
    var v = f._v || {}, mut = f.kategori === "muteahhit";
    var h = '<div class="im">';
    h += '<form class="im-arama" onsubmit="event.preventDefault();imFiltreAra(this.q.value)"><input name="q" type="search" enterkeyhint="search" value="' + esc(f.ara || "") + '" placeholder="Bu listede ara" aria-label="Bu listede ara"><button class="btn" type="submit">Ara</button></form>';
    var etiket = [];
    if (f.il) { var il = iller().filter(function (x) { return String(x.id) === String(f.il); })[0]; etiket.push(il ? il.ad : "İl"); }
    if (f.min || f.max) etiket.push((f.min ? tl(f.min) : "0") + " – " + (f.max ? tl(f.max) : "∞"));
    if (f.sektor) { var se = (v.sektorler || []).filter(function (x) { return x.kod === f.sektor; })[0]; etiket.push(se ? se.ad : f.sektor); }
    h += '<div class="im-filtre"><button type="button" class="' + (etiket.length ? "on" : "") + '" onclick="imFiltreAc()">Filtrele' + (etiket.length ? " · " + esc(etiket.join(", ")) : "") + '</button>';
    if (!mut) SIRALA.forEach(function (s) { h += '<button type="button" class="' + ((f.sirala || "akilli") === s[0] ? "on" : "") + '" onclick="imSirala(\'' + s[0] + '\')">' + s[1] + '</button>'; });
    if (!mut) h += '<button type="button" class="' + (f.acil ? "on" : "") + '" onclick="imAcilDegis()">Acil</button>';
    h += '</div>';
    if (mut) {
      var m = v.muteahhit || [];
      h += '<p class="im-ipucu">Müteahhitlerin tamamladığı projelerden ilk sahibi sen ol. Fiyata alıcı %2 tapu harcı eklenir.</p>';
      h += m.length ? '<div class="im-vitrin">' + m.map(mutKart).join("") + '</div>' : bos('Şu an satışta sıfır konut ya da dükkân yok. İnşaat şirketleri proje bitirdikçe burada görünür.');
    } else {
      var l = f._liste || [];
      h += '<p class="im-sonuc">' + Number(v.toplam || 0) + ' ilan</p>';
      h += l.length ? '<div class="im-liste">' + l.map(satir).join("") + '</div>'
        : bos(f.ara || etiket.length || f.acil ? 'Bu filtreye uyan ilan yok. Filtreleri gevşetip yeniden dene.' : 'Bu kategoride henüz ilan yok.',
              '<button class="btn ikinci" onclick="ilanVerEkrani()">İlan ver</button>');
      if (l.length < Number(v.toplam || 0)) h += '<button type="button" class="btn ikinci im-daha" onclick="imDaha(this)">Daha fazla göster</button>';
      if (["konut", "isyeri", "tumu", "emlak"].indexOf(f.kategori) >= 0 && (v.muteahhit || []).length && !f.satici && !f.acil) {
        h += '<h3 class="im-bas">Müteahhitten sıfır</h3><div class="im-vitrin">' + v.muteahhit.slice(0, 4).map(mutKart).join("") + '</div>';
      }
    }
    h += '</div>';
    ekran(baslik, h);
  }
  window.imSirala = function (s) { if (!AKTIF) return; AKTIF.sirala = s; liste(AKTIF); };
  window.imAcilDegis = function () { if (!AKTIF) return; AKTIF.acil = !AKTIF.acil; liste(AKTIF); };
  window.imFiltreAra = function (q) { if (!AKTIF) return; AKTIF.ara = String(q || "").trim(); liste(AKTIF); };
  window.imDaha = function (btn) { if (!AKTIF) return; if (btn) btn.disabled = true; AKTIF.sayfa = (AKTIF.sayfa || 1) + 1; liste(AKTIF, true); };
  window.imFiltreAc = function () {
    var f = AKTIF; if (!f) return;
    var sirketli = ["tumu", "sirket", "hisse", "sirketler"].indexOf(f.kategori) >= 0;
    var sek = (f._v && f._v.sektorler) || [];
    var h = '<h3>Filtrele</h3>' +
      '<div class="alan"><label for="imfKat">Kategori</label><select id="imfKat">' +
      [["tumu", "Tüm ilanlar"], ["emlak", "Tüm emlak"], ["konut", "Konut"], ["isyeri", "İşyeri"], ["arsa", "Arsa"], ["sirketler", "Tüm şirket ilanları"], ["sirket", "Satılık şirket"], ["hisse", "Şirket hissesi"], ["muteahhit", "Müteahhitten sıfır"]]
        .map(function (k) { return '<option value="' + k[0] + '"' + (f.kategori === k[0] ? " selected" : "") + '>' + k[1] + '</option>'; }).join("") + '</select></div>' +
      '<div class="alan"><label for="imfIl">İl</label><select id="imfIl"><option value="">Tüm Türkiye</option>' +
      iller().map(function (x) { return '<option value="' + Number(x.id) + '"' + (String(f.il) === String(x.id) ? " selected" : "") + '>' + esc(x.ad) + '</option>'; }).join("") + '</select></div>' +
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px"><div class="alan"><label for="imfMin">En az (₺)</label><input id="imfMin" inputmode="numeric" value="' + esc(f.min || "") + '" placeholder="0"></div>' +
      '<div class="alan"><label for="imfMax">En çok (₺)</label><input id="imfMax" inputmode="numeric" value="' + esc(f.max || "") + '" placeholder="Sınırsız"></div></div>' +
      (sirketli && sek.length ? '<div class="alan"><label for="imfSek">Sektör</label><select id="imfSek"><option value="">Tüm sektörler</option>' +
        sek.map(function (s) { return '<option value="' + esc(s.kod) + '"' + (f.sektor === s.kod ? " selected" : "") + '>' + esc(s.ad) + '</option>'; }).join("") + '</select></div>' : '') +
      '<div class="im-dg"><button class="btn" onclick="imFiltreUygula()">Sonuçları göster</button><button class="btn ikinci" onclick="imFiltreTemizle()">Temizle</button></div>';
    imModal(h);
  };
  window.imFiltreUygula = function () {
    var f = AKTIF; if (!f) return;
    f.kategori = $id("imfKat").value || "tumu";
    f.il = $id("imfIl").value || "";
    var mn = parse($id("imfMin").value), mx = parse($id("imfMax").value);
    f.min = isFinite(mn) && mn > 0 ? Math.round(mn) : ""; f.max = isFinite(mx) && mx > 0 ? Math.round(mx) : "";
    f.sektor = $id("imfSek") ? $id("imfSek").value : "";
    kapat(); liste(f);
  };
  window.imFiltreTemizle = function () {
    var f = AKTIF; if (!f) return;
    f.il = ""; f.min = ""; f.max = ""; f.sektor = ""; f.acil = false; f.ara = "";
    kapat(); liste(f);
  };

  /* Müteahhitten sıfır: mevcut ilk satış işlemiyle (eko_emlak_islem) satın alınır */
  window.imMuteahhitAl = async function (bolum, fiyat, harc, proje) {
    var toplam = Number(fiyat) + Number(harc || Math.round(fiyat * 0.02));
    var ok = await sor("Sıfır taşınmaz al", proje + " projesinden " + tl(fiyat) + " bedelle satın alıyorsun. Alıcı %2 tapu harcıyla birlikte cüzdanından " + tl(toplam) + " düşülecek.", "Satın al");
    if (!ok) return;
    try {
      await calis(null, function () { return API.rpc("eko_emlak_islem", { p_eylem: "bolum_al", p_veri: { bolum: Number(bolum) } }); }, "Tapu senin! İstediğin zaman İlan Meydanı’nda “İlan ver” ile satabilirsin.");
      await cuzdanTazele();
      if (typeof yenidenCiz === "function") yenidenCiz();
    } catch (_) {}
  };

  /* =====================================================================
     İLAN DETAYI
     ===================================================================== */
  var DT = { v: null };
  async function detay(id) {
    stilKur();
    if (!DT.v || DT.v.id !== id) yukleniyor("İlan");
    var v;
    try { v = await API.rpc("ilan_detay", { p_ilan: id }); }
    catch (err) { return ekran("İlan", '<div class="im">' + bos(esc(hata(err))) + '</div>'); }
    DT.v = v;
    var yayinda = v.durum === "yayinda";
    var h = '<div class="im">';
    h += '<div class="im-df">' + gorsel(v.gorsel, v.id, v.pay) + '<span class="im-et">' + rozetler(v) + '</span>' +
      '<button type="button" class="im-fav' + (v.favori ? " on" : "") + '" aria-pressed="' + !!v.favori + '" aria-label="' + (v.favori ? "Favorilerden çıkar" : "Favorilere ekle") + '" onclick="imFavori(' + Number(v.id) + ',' + (!v.favori) + ')">' + (v.favori ? "♥" : "♡") + '</button>' +
      '<span class="im-no">İlan no ' + Number(v.no) + '</span></div>';
    h += '<div class="im-fiyat">' + tl(v.fiyat) + (v.dustu && v.onceki_fiyat ? '<s>' + tl(v.onceki_fiyat) + '</s>' : '') + '</div>';
    h += '<div class="im-dbas">' + esc(v.baslik) + '</div>';
    h += '<div class="im-yer">' + esc(v.il || "Türkiye") + ' · ' + esc(tarihKisa(v.tarih)) + ' · ' + Number(v.goruntulenme || 0) + ' kişi baktı' + (v.favori_sayisi ? ' · ' + Number(v.favori_sayisi) + ' favori' : '') + '</div>';

    if (!yayinda) {
      var dm = { satildi: "Bu ilan satıldı" + (v.satis_bedeli ? " (" + tl(v.satis_bedeli) + ")" : "") + ".", kaldirildi: "Satıcı bu ilanı yayından kaldırdı.", suresi_doldu: "Bu ilanın yayın süresi doldu.", gecersiz: "İlandaki varlık artık satılabilir durumda değil; ilan yayından kalktı." };
      h += '<div class="im-durum uyari" style="margin-top:12px">' + esc(dm[v.durum] || "İlan yayında değil.") + '</div>';
    } else if (v.benim) {
      h += saticiPaneli(v);
    } else {
      h += aliciPaneli(v);
    }

    h += '<section class="im-kutu"><h4>İlan bilgileri</h4><div class="im-tablo">' +
      (v.bilgi || []).map(function (r) { return '<div><span>' + esc(r[0]) + '</span><b>' + esc(r[1]) + '</b></div>'; }).join("") + '</div></section>';
    if (v.mali) {
      h += '<section class="im-kutu"><h4>Mali bilgiler' + (v.benim && !v.mali.acik ? ' · yalnız sen görüyorsun' : '') + '</h4><div class="im-tablo">' +
        '<div><span>Şirket kasası</span><b>' + tl(v.mali.kasa) + '</b></div><div><span>Sermaye</span><b>' + tl(v.mali.sermaye) + '</b></div>' +
        '<div><span>Defter değeri</span><b>' + tl(v.mali.defter) + '</b></div></div></section>';
    } else if (v.varlik === "sirket" || v.varlik === "hisse") {
      h += '<p class="im-ipucu">Satıcı şirketin kasa bilgisini ilanda paylaşmadı. Teklif notunda sorabilirsin.</p>';
    }
    if (v.aciklama) h += '<section class="im-kutu"><h4>Açıklama</h4><div class="im-aciklama">' + esc(v.aciklama) + '</div></section>';
    var sb = v.satici_bilgi || {};
    h += '<section class="im-kutu"><h4>Satıcı</h4><div class="im-satici"><span class="im-av">' + esc(String(sb.kad || "?").charAt(0).toLocaleUpperCase("tr-TR")) + '</span>' +
      '<span style="flex:1;min-width:0"><b>' + esc(sb.kad || v.satici) + '</b><small>' + (sb.il ? esc(sb.il) + ' · ' : '') + 'Üyelik ' + esc(sb.uye || "") + '</small>' +
      '<small>' + Number(sb.satis || 0) + ' satış · ' + Number(sb.aktif || 0) + ' yayında ilan</small></span>' +
      (Number(sb.aktif || 0) > 1 && !v.benim ? '<button type="button" class="btn ikinci" style="width:auto;margin:0;padding:8px 12px;font-size:13px" onclick="imSaticiIlanlari(' + arg(sb.kad) + ')">İlanları</button>' : '') + '</div></section>';
    if (v.yonetici && !v.benim && yayinda) h += '<button type="button" class="btn ikinci" style="margin-bottom:12px" onclick="imKaldir(' + Number(v.id) + ',true)">Yönetici: ilanı yayından kaldır</button>';
    if ((v.benzer || []).length) h += '<h3 class="im-bas">Benzer ilanlar</h3><div class="im-liste">' + v.benzer.map(satir).join("") + '</div>';
    h += '</div>';
    ekran("İlan", h);
  }
  function guvenKutusu(v) {
    var harc = v.alici_harc ? ' Emlakta alıcıdan %2 tapu harcı alınır (' + tl(v.alici_harc) + ').' : '';
    return '<div class="im-guven"><span aria-hidden="true">🛡️</span><span><b>Güvenli Ödeme.</b> Teklif verdiğinde tutar cüzdanından ayrılıp bloke edilir. Satıcı kabul ederse tapu ya da hisse anında sana geçer; reddederse veya 48 saatte yanıt gelmezse paran iade edilir.' + harc + '</span></div>';
  }
  function aliciPaneli(v) {
    var h = '', t = v.teklifim;
    if (t && (t.durum === "bekliyor" || t.durum === "karsi")) {
      if (t.durum === "karsi") {
        var fark = Number(t.karsi) - Number(t.tutar);
        h += '<div class="im-durum" style="margin-top:12px"><b>Satıcı karşı teklif verdi: ' + tl(t.karsi) + '</b><br>Senin teklifin ' + tl(t.tutar) + '. Kabul edersen ' + tl(fark + (v.alici_harc ? Math.round(fark * 0.02) : 0)) + ' daha cüzdanından düşülür ve ilan sana geçer. ' + esc(kalan(t.bitis)) + '.' +
          '<div class="im-dg"><button class="btn" onclick="imKarsiYanit(' + Number(t.id) + ',true,this)">Kabul et, satın al</button><button class="btn ikinci" onclick="imKarsiYanit(' + Number(t.id) + ',false,this)">Reddet</button></div></div>';
      } else {
        h += '<div class="im-durum" style="margin-top:12px"><b>Teklifin satıcıda: ' + tl(t.tutar) + '</b><br>' + tl(t.emanet) + ' Güvenli Ödeme’de bloke. ' + esc(kalan(t.bitis)) + '.' +
          '<div class="im-dg"><button class="btn ikinci" onclick="imTeklifModal(' + Number(v.id) + ')">Teklifi güncelle</button><button class="btn ikinci" onclick="imGeriCek(' + Number(t.id) + ',this)">Geri çek</button></div></div>';
      }
    } else {
      h += '<div class="im-aks">' + (v.pazarlik ? '<button class="btn ikinci" onclick="imTeklifModal(' + Number(v.id) + ')">Teklif ver</button>' : '') +
        '<button class="btn" onclick="imHemenAl(' + Number(v.id) + ')">Hemen al</button></div>';
      if (t && t.durum === "red") h += '<p class="im-ipucu">Önceki teklifin kabul edilmedi. Yeni bir teklif verebilirsin.</p>';
    }
    if (v.pazarlik) h += guvenKutusu(v);
    else h += '<p class="im-ipucu">Satıcı bu ilanda pazarlık kabul etmiyor; ilan fiyatından satın alabilirsin.</p>';
    return h;
  }
  function saticiPaneli(v) {
    var paket = v.paketler || {}, aktif = [];
    var ad = { vitrin: "Vitrin", ust_sira: "Üst sıra", acil: "Acil", renkli: "Renkli çerçeve" };
    Object.keys(ad).forEach(function (k) { if (paket[k] && new Date(paket[k]).getTime() > simdi()) aktif.push(ad[k] + " (" + kalan(paket[k]) + ")"); });
    var h = '<div class="im-durum" style="margin-top:12px"><b>Bu senin ilanın.</b> Yayın süresi: ' + esc(kalan(v.bitis)) + '.' +
      (aktif.length ? '<br>Öne çıkarma: ' + esc(aktif.join(", ")) : '') +
      '<div class="im-dg"><button class="btn" onclick="imOneCikarModal(' + Number(v.id) + ')">Öne çıkar</button><button class="btn ikinci" onclick="imDuzenleModal(' + Number(v.id) + ')">Düzenle</button><button class="btn ikinci" onclick="imKaldir(' + Number(v.id) + ')">Kaldır</button></div></div>';
    var tk = v.teklifler || [];
    var acik = tk.filter(function (t) { return t.durum === "bekliyor" || t.durum === "karsi"; });
    h += '<section class="im-kutu"><h4>Teklifler' + (acik.length ? ' · ' + acik.length + ' açık' : '') + '</h4>';
    h += tk.length ? tk.slice(0, 12).map(function (t) { return teklifSatiri(t, v); }).join("") : '<p class="im-ipucu" style="padding:4px 0 12px">Henüz teklif yok. Öne çıkararak daha çok alıcıya ulaşabilirsin.</p>';
    h += '</section>';
    return h;
  }
  var DURUM_AD = { bekliyor: "Yanıt bekliyor", karsi: "Karşı teklif verildi", kabul: "Kabul edildi", red: "Reddedildi", geri_cekildi: "Geri çekildi", suresi_doldu: "Süresi doldu", kapandi: "İlan kapandı" };
  function teklifSatiri(t, v) {
    var oran = v && v.fiyat ? Math.round(Number(t.tutar) / Number(v.fiyat) * 100) : null;
    var h = '<div class="im-teklif"><div class="im-tu"><span><b>' + tl(t.tutar) + '</b>' + (oran ? ' <span class="im-r gri">%' + oran + '</span>' : '') + '</span><span class="im-r ' + (t.durum === "bekliyor" ? "ben" : "gri") + '">' + esc(DURUM_AD[t.durum] || t.durum) + '</span></div>' +
      '<small>' + esc(t.alici || t.kisi || "") + ' · ' + esc(tarihKisa(t.zaman)) + (t.durum === "bekliyor" || t.durum === "karsi" ? ' · ' + esc(kalan(t.bitis)) : '') + '</small>' +
      (t.karsi ? '<small>Karşı teklifin: ' + tl(t.karsi) + '</small>' : '') + (t.not ? '<q>“' + esc(t.not) + '”</q>' : '');
    if (t.durum === "bekliyor") {
      h += '<div class="im-dg"><button class="btn" onclick="imTeklifKabul(' + Number(t.id) + ',' + Number(t.tutar) + ',this)">Kabul et</button>' +
        '<button class="btn ikinci" onclick="imKarsiModal(' + Number(t.id) + ',' + Number(t.tutar) + ',' + Number(v ? v.fiyat : t.fiyat) + ')">Karşı teklif</button>' +
        '<button class="btn ikinci" onclick="imTeklifRed(' + Number(t.id) + ',this)">Reddet</button></div>';
    } else if (t.durum === "karsi") {
      h += '<div class="im-dg"><button class="btn ikinci" onclick="imTeklifRed(' + Number(t.id) + ',this)">Karşı teklifi geri al</button></div>';
    }
    return h + '</div>';
  }

  /* ---- detay eylemleri ---- */
  function yenile() { if (typeof yenidenCiz === "function") yenidenCiz(); }
  window.imFavori = async function (id, ekle) {
    try { await calis(null, function () { return API.rpc("ilan_favori", { p_ilan: id, p_ekle: !!ekle }); }, ekle ? "Favorilere eklendi." : "Favorilerden çıkarıldı."); yenile(); } catch (_) {}
  };
  window.imHemenAl = async function (id) {
    var v = DT.v; if (!v || v.id !== id) return;
    var harc = Number(v.alici_harc || 0), toplam = Number(v.fiyat) + harc;
    var ok = await sor("Hemen al", "“" + v.baslik + "” ilanını " + tl(v.fiyat) + " bedelle satın alıyorsun." +
      (harc ? " Alıcı %2 tapu harcı " + tl(harc) + "; toplam " + tl(toplam) + " cüzdanından düşülecek." : " Bedel cüzdanından düşülecek.") +
      " Devir anında tamamlanır.", "Satın al");
    if (!ok) return;
    try {
      await calis(null, function () { return API.rpc("ilan_hemen_al", { p_ilan: id, p_fiyat: Number(v.fiyat) }); }, "Hayırlı olsun! Satın alma tamamlandı.");
      await cuzdanTazele();
      yenile();
    } catch (_) {}
  };
  window.imTeklifModal = function (id) {
    var v = DT.v; if (!v || v.id !== id) return;
    var t = v.teklifim && (v.teklifim.durum === "bekliyor" || v.teklifim.durum === "karsi") ? v.teklifim : null;
    var oneri = t ? Number(t.tutar) : Math.max(Math.ceil(v.fiyat * 0.5), Math.round(v.fiyat * 0.9 / 1000) * 1000);
    var h = '<h3>' + (t ? "Teklifini güncelle" : "Teklif ver") + '</h3><p class="im-ipucu">' + esc(v.baslik) + ' · İlan fiyatı ' + tl(v.fiyat) + '</p>' +
      '<div class="alan"><label for="imTk">Teklifin (₺)</label><input id="imTk" inputmode="numeric" value="' + sayi(oneri) + '" oninput="imTeklifOzet()"></div>' +
      '<div class="im-cips">' + [5, 10, 15, 20].map(function (o) { return '<button type="button" onclick="imTkYuzde(' + o + ')">%' + o + ' aşağı</button>'; }).join("") + '</div>' +
      '<div class="alan" style="margin-top:10px"><label for="imTkNot">Satıcıya not (isteğe bağlı)</label><textarea id="imTkNot" maxlength="280" placeholder="Örneğin: Bugün devralabilirim.">' + esc(t && t.not ? t.not : "") + '</textarea></div>' +
      '<div class="im-toplam" id="imTkOzet"></div><div class="im-hata" id="imTkHata"></div>' +
      '<p class="im-ipucu">Tutar Güvenli Ödeme ile bloke edilir; kabul edilmezse ya da 48 saatte yanıt gelmezse iade edilir.</p>' +
      '<div class="im-dg"><button class="btn" id="imTkBtn" onclick="imTeklifGonder(' + Number(id) + ',this)">Teklifi gönder</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button></div>';
    DT.harcVar = !!v.alici_harc;
    imModal(h);
    window.imTeklifOzet();
  };
  window.imTkYuzde = function (o) { var v = DT.v; if (!v) return; $id("imTk").value = sayi(Math.max(Math.ceil(v.fiyat * 0.5), Math.round(v.fiyat * (1 - o / 100)))); window.imTeklifOzet(); };
  window.imTeklifOzet = function () {
    var v = DT.v, el = $id("imTkOzet"); if (!v || !el) return;
    var n = parse($id("imTk").value), err = "";
    if (!isFinite(n) || n <= 0) err = "Geçerli bir tutar yaz.";
    else if (n >= v.fiyat) err = "Teklifin ilan fiyatına eşit ya da yüksek; doğrudan “Hemen al” ile satın alabilirsin.";
    else if (n < Math.ceil(v.fiyat * 0.5)) err = "Teklif ilan fiyatının en az yarısı (" + tl(Math.ceil(v.fiyat * 0.5)) + ") olmalı.";
    var harc = DT.harcVar && isFinite(n) ? Math.round(n * 0.02) : 0;
    el.innerHTML = '<div><span>Teklif</span><b>' + (isFinite(n) ? tl(n) : "—") + '</b></div>' + (DT.harcVar ? '<div><span>Tapu harcı (%2)</span><b>' + tl(harc) + '</b></div>' : '') +
      '<div class="t"><span>Bloke edilecek</span><b>' + (isFinite(n) ? tl(n + harc) : "—") + '</b></div>';
    $id("imTkHata").textContent = err;
    var b = $id("imTkBtn"); if (b) b.disabled = !!err;
  };
  window.imTeklifGonder = async function (id, btn) {
    var n = Math.round(parse($id("imTk").value)), not = ($id("imTkNot").value || "").trim();
    try {
      await calis(btn, function () { return API.rpc("ilan_teklif_ver", { p_ilan: id, p_tutar: n, p_not: not || null }); }, "Teklifin satıcıya iletildi. Yanıt gelince bildirim alacaksın.");
      kapat();
      await cuzdanTazele();
      yenile();
    } catch (_) {}
  };
  window.imGeriCek = async function (tid, btn) {
    var ok = await sor("Teklifi geri çek", "Teklifin geri çekilecek ve bloke tutar cüzdanına iade edilecek.", "Geri çek");
    if (!ok) return;
    try { await calis(btn, function () { return API.rpc("ilan_teklif_geri_cek", { p_teklif: tid }); }, "Teklifin geri çekildi, emanetin iade edildi."); await cuzdanTazele(); yenile(); } catch (_) {}
  };
  window.imKarsiYanit = async function (tid, kabul, btn) {
    if (kabul) {
      var ok = await sor("Karşı teklifi kabul et", "Karşı teklif tutarıyla satın alıyorsun. Aradaki fark cüzdanından düşülecek ve devir anında tamamlanacak.", "Kabul et");
      if (!ok) return;
    }
    try {
      await calis(btn, function () { return API.rpc("ilan_karsi_yanit", { p_teklif: tid, p_kabul: !!kabul }); }, kabul ? "Hayırlı olsun! Satın alma tamamlandı." : "Karşı teklifi reddettin; emanetin iade edildi.");
      await cuzdanTazele();
      yenile();
    } catch (_) {}
  };
  window.imTeklifKabul = async function (tid, tutar, btn) {
    var ok = await sor("Teklifi kabul et", tl(tutar) + " teklifini kabul ediyorsun. Tutar alıcının bloke parasından anında hesabına geçer ve ilandaki varlık alıcıya devredilir. Bu işlem geri alınamaz.", "Kabul et ve sat");
    if (!ok) return;
    try {
      await calis(btn, function () { return API.rpc("ilan_teklif_yanit", { p_teklif: tid, p_karar: "kabul" }); }, "Satış tamamlandı. Bedel cüzdanına geçti.");
      await cuzdanTazele();
      yenile();
    } catch (_) {}
  };
  window.imTeklifRed = async function (tid, btn) {
    try { await calis(btn, function () { return API.rpc("ilan_teklif_yanit", { p_teklif: tid, p_karar: "red" }); }, "Teklif reddedildi; alıcının parası iade edildi."); yenile(); } catch (_) {}
  };
  window.imKarsiModal = function (tid, tutar, fiyat) {
    var orta = Math.round((Number(tutar) + Number(fiyat)) / 2 / 1000) * 1000;
    if (orta <= tutar) orta = Number(tutar) + 1000;
    if (orta > fiyat) orta = Number(fiyat);
    var h = '<h3>Karşı teklif ver</h3><p class="im-ipucu">Alıcının teklifi ' + tl(tutar) + ', ilan fiyatın ' + tl(fiyat) + '. Alıcı 48 saat içinde kabul ederse satış tamamlanır.</p>' +
      '<div class="alan"><label for="imKt">Karşı teklifin (₺)</label><input id="imKt" inputmode="numeric" value="' + sayi(orta) + '"></div>' +
      '<div class="im-cips"><button type="button" onclick="document.getElementById(\'imKt\').value=\'' + sayi(orta) + '\'">Ortası</button><button type="button" onclick="document.getElementById(\'imKt\').value=\'' + sayi(fiyat) + '\'">İlan fiyatı</button></div>' +
      '<div class="im-dg" style="margin-top:12px"><button class="btn" onclick="imKarsiGonder(' + Number(tid) + ',this)">Karşı teklifi gönder</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button></div>';
    imModal(h);
  };
  window.imKarsiGonder = async function (tid, btn) {
    var n = Math.round(parse($id("imKt").value));
    if (!isFinite(n) || n <= 0) return bildir("Geçerli bir tutar yaz.", true);
    try { await calis(btn, function () { return API.rpc("ilan_teklif_yanit", { p_teklif: tid, p_karar: "karsi", p_karsi: n }); }, "Karşı teklifin alıcıya iletildi."); kapat(); yenile(); } catch (_) {}
  };
  window.imKaldir = async function (id, yonetici) {
    var ok = await sor(yonetici ? "İlanı kaldır (yönetici)" : "İlanı kaldır", "İlan yayından kalkacak; açık tekliflerin bloke tutarları alıcılara iade edilecek. Ödenen ilan ücreti iade edilmez.", "Kaldır", true);
    if (!ok) return;
    try { await calis(null, function () { return API.rpc("ilan_kaldir", { p_ilan: id }); }, "İlan yayından kaldırıldı."); yenile(); } catch (_) {}
  };
  window.imDuzenleModal = function (id) {
    var v = DT.v; if (!v || v.id !== id) return;
    var bant = v.bant || {};
    var h = '<h3>İlanı düzenle</h3>' +
      '<div class="alan"><label for="imDf">Fiyat (₺)</label><input id="imDf" inputmode="numeric" value="' + sayi(v.fiyat) + '"></div>' +
      (bant.alt ? '<p class="im-ipucu">İzin verilen aralık: ' + tl(bant.alt) + ' – ' + tl(bant.ust) + '. Fiyatı düşürürsen ilanda “Fiyatı düştü” etiketi görünür.</p>' : '') +
      '<div class="alan"><label for="imDb">Başlık</label><input id="imDb" maxlength="70" value="' + esc(v.baslik) + '"></div>' +
      '<div class="alan"><label for="imDa">Açıklama</label><textarea id="imDa" maxlength="1200">' + esc(v.aciklama || "") + '</textarea></div>' +
      '<label class="im-anahtar"><input type="checkbox" id="imDp"' + (v.pazarlik ? " checked" : "") + '><span>Teklif kabul ediyorum<small>Kapatırsan alıcılar yalnız ilan fiyatından alabilir.</small></span></label>' +
      (v.varlik === "sirket" || v.varlik === "hisse" ? '<label class="im-anahtar"><input type="checkbox" id="imDm"' + (v.mali_goster ? " checked" : "") + '><span>Kasa ve sermayeyi ilanda göster<small>Kapalıyken şirket kasası alıcılardan gizli kalır.</small></span></label>' : '') +
      '<div class="im-dg"><button class="btn" onclick="imDuzenleKaydet(' + Number(id) + ',this)">Kaydet</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button></div>';
    imModal(h);
  };
  window.imDuzenleKaydet = async function (id, btn) {
    var veri = { fiyat: Math.round(parse($id("imDf").value)), baslik: $id("imDb").value, aciklama: $id("imDa").value, pazarlik: $id("imDp").checked };
    if ($id("imDm")) veri.mali_goster = $id("imDm").checked;
    if (!isFinite(veri.fiyat)) return bildir("Geçerli bir fiyat yaz.", true);
    try { await calis(btn, function () { return API.rpc("ilan_duzenle", { p_ilan: id, p_veri: veri }); }, "İlan güncellendi."); kapat(); yenile(); } catch (_) {}
  };
  window.imOneCikarModal = function (id) {
    var tar = (IM.tarife || []).filter(function (a) { return ["vitrin", "ust_sira", "acil", "renkli", "yukari"].indexOf(a.kod) >= 0; });
    var h = '<h3>Öne çıkar</h3><p class="im-ipucu">İlanını daha çok alıcıya göster. Ücret cüzdanından düşülür ve Hazine’ye gelir yazılır.</p>' +
      tar.map(function (a) {
        return '<button type="button" class="im-paket" onclick="imOneCikar(' + Number(id) + ',\'' + esc(a.kod) + '\',this)">' +
          '<span style="flex:1;min-width:0"><b>' + esc(a.ad) + (a.gun ? ' · ' + Number(a.gun) + ' gün' : '') + '</b><small>' + esc(a.aciklama || "") + '</small></span><em>' + tl(a.tutar) + '</em></button>';
      }).join("") + '<div class="im-dg"><button class="btn ikinci" onclick="modalKapat()">Kapat</button></div>';
    imModal(h);
  };
  window.imOneCikar = async function (id, kod, btn) {
    try { await calis(btn, function () { return API.rpc("ilan_one_cikar", { p_ilan: id, p_paket: kod }); }, "İlanın öne çıkarıldı."); kapat(); await cuzdanTazele(); yenile(); } catch (_) {}
  };

  /* =====================================================================
     İLAN VER
     ===================================================================== */
  var IV = { v: null, secim: null, paket: {}, form: null };
  // 1. adım: satılacak varlığı seç (geri gelindiğinde seçim sıfırlanır)
  async function ivAdim1() {
    stilKur();
    IV.secim = null;
    if (!IV.v) yukleniyor("İlan ver");
    try { IV.v = await API.rpc("ilan_varliklarim"); IM.tarife = IV.v.tarife || IM.tarife; }
    catch (err) { return ekran("İlan ver", '<div class="im">' + bos(esc(hata(err))) + '</div>'); }
    return varlikSec();
  }
  // 2. adım: fiyat, başlık, öne çıkarma
  function ivAdim2() {
    stilKur();
    if (!IV.secim || !IV.form) return varlikSec();
    return ilanFormu();
  }
  function ucret(kod) { var a = ((IV.v && IV.v.tarife) || IM.tarife || []).filter(function (x) { return x.kod === kod; })[0]; return a ? Number(a.tutar) : 0; }
  function varlikSec() {
    var v = IV.v || {}, h = '<div class="im">';
    h += '<p class="im-ipucu">Satmak istediğin varlığı seç. İlan 30 gün yayında kalır; aynı anda en fazla ' + Number(v.limit || 10) + ' ilanın olabilir (şu an ' + Number(v.aktif || 0) + ').</p>';
    var emlak = (v.tapular || []).concat(v.bolumler || []);
    h += '<section class="im-kutu"><h4>Emlak · ilan ücreti ' + tl(ucret("ilan_emlak")) + '</h4>';
    if (emlak.length) {
      emlak.forEach(function (x) {
        var tip = x.tip === "daire" ? "Daire" : x.tip === "dukkan" ? "Dükkân" : "Arsa";
        var engel = x.ilanda ? "Zaten ilanda" : x.kirada ? "Kiracısı var" : x.baska_pazar ? "Yatırım Pazarı’nda satılık" : "";
        h += '<div class="im-varlik"><span class="im-vk2">' + gorsel(x.tip, x.id, null) + '</span><span class="im-vo"><b>' + tip + ' · ' + esc(x.il) + '</b>' +
          '<small>' + Number(x.alan_m2) + ' m²' + (x.proje ? ' · ' + esc(x.proje) : '') + ' · rayiç ' + tl(x.rayic) + '</small>' + (engel ? '<small style="color:var(--warn)">' + esc(engel) + '</small>' : '') + '</span>' +
          '<span class="im-vd">' + (engel ? '' : '<button class="btn" onclick="imVarlikSec(\'' + x.varlik + '\',' + Number(x.id) + ')">Sat</button>') + '</span></div>';
      });
    } else {
      h += '<p class="im-ipucu" style="padding:4px 0 12px">Adına kayıtlı konut, dükkân ya da arsa yok. Müteahhitten sıfır bölümünden ya da diğer oyuncuların ilanlarından alabilirsin.</p>';
    }
    h += '</section>';
    var sir = v.sirketler || [];
    h += '<section class="im-kutu"><h4>Şirketler · tamamı ' + tl(ucret("ilan_sirket")) + ', hisse ' + tl(ucret("ilan_hisse")) + '</h4>';
    if (v.sirket_pazari === false) h += '<p class="im-ipucu">Şirket pazarı şu an geçici olarak kapalı.</p>';
    if (sir.length) {
      sir.forEach(function (s) {
        var engel = s.banka ? "Bankalar İlan Meydanı’nda satılamaz" : v.sirket_pazari === false ? "Şirket pazarı kapalı" : "";
        var tamOk = !engel && s.tam && !s.ilanda_sirket && !s.ilanda_hisse;
        var hisseOk = !engel && Number(s.kullanilabilir) > 0 && !s.ilanda_sirket && !s.ilanda_hisse;
        h += '<div class="im-varlik"><span class="im-vk2">' + gorsel("sirket", s.id, null) + '</span><span class="im-vo"><b>' + esc(s.ad) + '</b>' +
          '<small>' + esc(s.sektor_ad) + ' · payın ' + payYaz(s.pay) + '</small>' +
          (engel ? '<small style="color:var(--warn)">' + esc(engel) + '</small>' : s.ilanda_sirket ? '<small style="color:var(--warn)">Şirketin tamamı ilanda</small>' : s.ilanda_hisse ? '<small style="color:var(--warn)">Hisse ilanın yayında</small>' : '') + '</span>' +
          '<span class="im-vd">' + (tamOk ? '<button class="btn" onclick="imVarlikSec(\'sirket\',' + Number(s.id) + ')">Tamamını sat</button>' : '') +
          (hisseOk ? '<button class="btn ikinci" onclick="imVarlikSec(\'hisse\',' + Number(s.id) + ')">Hisse sat</button>' : '') + '</span></div>';
      });
    } else {
      h += '<p class="im-ipucu" style="padding:4px 0 12px">Ortağı olduğun bir şirket yok.</p>';
    }
    h += '</section></div>';
    ekran("İlan ver", h);
  }
  window.imVarlikSec = function (varlik, id) {
    var v = IV.v || {}, x;
    if (varlik === "tapu") x = (v.tapular || []).filter(function (a) { return a.id === id; })[0];
    else if (varlik === "bolum") x = (v.bolumler || []).filter(function (a) { return a.id === id; })[0];
    else x = (v.sirketler || []).filter(function (a) { return a.id === id; })[0];
    if (!x) return;
    IV.secim = { varlik: varlik, x: x };
    IV.paket = {};
    var tipAd = x.tip === "daire" ? "daire" : x.tip === "dukkan" ? "dükkân" : "arsa";
    var pay = varlik === "hisse" ? Math.min(25, Math.floor(Number(x.kullanilabilir) * 100) / 100) : null;
    IV.form = {
      baslik: varlik === "sirket" ? (x.ad + " — devren satılık").slice(0, 70)
        : varlik === "hisse" ? (x.ad + " — " + payYaz(pay) + " hisse").slice(0, 70)
        : (x.il + " " + tipAd + ", " + x.alan_m2 + " m²").replace(/^./, function (c) { return c.toLocaleUpperCase("tr-TR"); }),
      aciklama: "", pay: pay, pazarlik: true, mali: false, fiyat: null
    };
    var b = bantHesap();
    IV.form.fiyat = varlik === "tapu" || varlik === "bolum" ? Number(x.rayic) : Math.round((b.alt + Math.min(b.ust, b.alt * 3)) / 2 / 1000) * 1000 || b.alt;
    if (IV.form.fiyat < b.alt) IV.form.fiyat = b.alt;
    if (IV.form.fiyat > b.ust) IV.form.fiyat = b.ust;
    return ekranAc(ivAdim2);
  };
  function bantHesap() {
    var s = IV.secim; if (!s) return { alt: 1000, ust: 1e9 };
    var x = s.x;
    if (s.varlik === "tapu" || s.varlik === "bolum") return { alt: Number(x.alt), ust: Number(x.ust), rayic: Number(x.rayic) };
    if (s.varlik === "sirket") return { alt: Number(x.sirket_alt), ust: Number(x.sirket_ust) };
    var pay = Number(IV.form && IV.form.pay) || 0;
    if (!x.bant_acik) return { alt: 1000, ust: 1e9 };
    return { alt: Math.max(1000, Math.round(Number(x.birim_alt || 0) * pay)), ust: Math.min(1e9, Math.max(1000, Math.round(Number(x.birim_ust || 0) * pay))) };
  }
  function ilanFormu() {
    var s = IV.secim, x = s.x, F = IV.form, b = bantHesap();
    var h = '<div class="im"><div class="im-form">';
    var ust = s.varlik === "sirket" ? x.ad + " · şirketin tamamı" : s.varlik === "hisse" ? x.ad + " · hisse satışı" : (x.tip === "daire" ? "Daire" : x.tip === "dukkan" ? "Dükkân" : "Arsa") + " · " + x.il + " · " + x.alan_m2 + " m²";
    h += '<div class="im-varlik" style="border-top:0;padding-top:0"><span class="im-vk2">' + gorsel(s.varlik === "tapu" || s.varlik === "bolum" ? x.tip : s.varlik, x.id, F.pay) + '</span><span class="im-vo"><b>' + esc(ust) + '</b><small><button type="button" class="im-link" onclick="geriGit()">Başka varlık seç</button></small></span></div>';
    if (s.varlik === "hisse") {
      h += '<div class="alan"><label for="ivPay">Satılacak pay (%) · en fazla ' + payYaz(x.kullanilabilir) + '</label><input id="ivPay" inputmode="decimal" value="' + String(F.pay).replace(".", ",") + '" oninput="imIvPay(this.value)"></div>';
    }
    h += '<div class="alan"><label for="ivFiyat">Fiyat (₺)</label><input id="ivFiyat" inputmode="numeric" value="' + sayi(F.fiyat) + '" oninput="imIvAlan(\'fiyat\',this.value)"></div>';
    h += '<p class="im-ipucu" id="ivBant">' + bantMetni(b) + '</p>';
    if (b.rayic) h += '<div class="im-cips" style="margin:-4px 0 12px"><button type="button" onclick="imIvFiyat(' + b.rayic + ')">Rayiç</button><button type="button" onclick="imIvFiyat(' + Math.round(b.rayic * 0.9) + ')">%10 altı</button><button type="button" onclick="imIvFiyat(' + Math.round(b.rayic * 1.2) + ')">%20 üstü</button></div>';
    h += '<div class="alan"><label for="ivBaslik">İlan başlığı</label><input id="ivBaslik" maxlength="70" value="' + esc(F.baslik) + '" oninput="imIvAlan(\'baslik\',this.value)"></div>';
    h += '<div class="alan"><label for="ivAciklama">Açıklama (isteğe bağlı)</label><textarea id="ivAciklama" maxlength="1200" placeholder="' + (s.varlik === "sirket" || s.varlik === "hisse" ? "Şirketin işleri, müşterileri, neden sattığın…" : "Konumu, kira durumu, neden sattığın…") + '" oninput="imIvAlan(\'aciklama\',this.value)">' + esc(F.aciklama) + '</textarea></div>';
    h += '<label class="im-anahtar"><input type="checkbox"' + (F.pazarlik ? " checked" : "") + ' onchange="imIvAlan(\'pazarlik\',this.checked)"><span>Teklif kabul ediyorum<small>Alıcılar pazarlık yapabilir; teklif tutarı Güvenli Ödeme ile bloke edilir.</small></span></label>';
    if (s.varlik === "sirket" || s.varlik === "hisse") {
      h += '<label class="im-anahtar"><input type="checkbox"' + (F.mali ? " checked" : "") + ' onchange="imIvAlan(\'mali\',this.checked)"><span>Kasa ve sermayeyi ilanda göster<small>Kapalı kalırsa şirket kasası alıcılardan gizli kalır.</small></span></label>';
    }
    h += '<h3 class="im-bas" style="margin-top:8px">Öne çıkar <small>isteğe bağlı</small></h3>';
    ((IV.v && IV.v.tarife) || IM.tarife || []).filter(function (a) { return ["vitrin", "ust_sira", "acil", "renkli"].indexOf(a.kod) >= 0; }).forEach(function (a) {
      var on = !!IV.paket[a.kod];
      h += '<label class="im-paket' + (on ? " on" : "") + '"><input type="checkbox"' + (on ? " checked" : "") + ' onchange="imIvPaket(\'' + esc(a.kod) + '\',this.checked)">' +
        '<span style="flex:1;min-width:0"><b>' + esc(a.ad) + ' · ' + Number(a.gun) + ' gün</b><small>' + esc(a.aciklama || "") + '</small></span><em>' + tl(a.tutar) + '</em></label>';
    });
    h += '<div class="im-toplam" id="ivToplam"></div><div class="im-hata" id="ivHata"></div>';
    h += '<button class="btn" id="ivBtn" onclick="imIlanYayinla(this)">Öde ve yayınla</button>';
    h += '<p class="im-ipucu" style="margin-top:10px">' + (s.varlik === "tapu" || s.varlik === "bolum" ? "Satış olunca bedelden %2 tapu harcı düşülür; alıcı da %2 öder." : "Satış olunca bedelden damga vergisi düşülür.") + ' İlan ücreti iade edilmez.</p>';
    h += '</div></div>';
    IV.kodIlan = s.varlik === "sirket" ? "ilan_sirket" : s.varlik === "hisse" ? "ilan_hisse" : "ilan_emlak";
    ekran("İlan ver", h);
    toplamCiz();
  }
  function bantMetni(b) {
    return (b.rayic ? "İl rayici " + tl(b.rayic) + ". " : "") + "Fiyat " + tl(b.alt) + " ile " + tl(b.ust) + " arasında olmalı" +
      (IV.secim && (IV.secim.varlik === "sirket" || IV.secim.varlik === "hisse") ? " (şirketin kasa ve sermayesine göre; bu aralığı yalnız sen görürsün)." : ".");
  }
  function toplamCiz() {
    var el = $id("ivToplam"); if (!el) return;
    var ilanU = ucret(IV.kodIlan), pak = 0;
    Object.keys(IV.paket).forEach(function (k) { if (IV.paket[k]) pak += ucret(k); });
    var cz = Number((IV.v && IV.v.cuzdan) || 0), top = ilanU + pak;
    el.innerHTML = '<div><span>İlan ücreti</span><b>' + tl(ilanU) + '</b></div>' + (pak ? '<div><span>Öne çıkarma</span><b>' + tl(pak) + '</b></div>' : '') +
      '<div class="t"><span>Ödenecek</span><b>' + tl(top) + '</b></div><div><span>Cüzdanın</span><b>' + tl(cz) + '</b></div>';
    var b = bantHesap(), F = IV.form, err = "";
    if (IV.secim.varlik === "hisse" && (!(F.pay > 0) || F.pay > Number(IV.secim.x.kullanilabilir))) err = "Satılacak pay 0 ile " + payYaz(IV.secim.x.kullanilabilir) + " arasında olmalı.";
    else if (!isFinite(F.fiyat) || F.fiyat < b.alt || F.fiyat > b.ust) err = "Fiyat " + tl(b.alt) + " ile " + tl(b.ust) + " arasında olmalı.";
    else if (String(F.baslik || "").trim().length < 5) err = "Başlık en az 5 karakter olmalı.";
    else if (top > cz) err = "Cüzdanında yeterli para yok.";
    $id("ivHata").textContent = err;
    var btn = $id("ivBtn"); if (btn) btn.disabled = !!err;
  }
  window.imIvAlan = function (k, v) {
    if (!IV.form) return;
    if (k === "fiyat") IV.form.fiyat = Math.round(parse(v));
    else IV.form[k] = v;
    toplamCiz();
  };
  window.imIvFiyat = function (n) { IV.form.fiyat = Math.round(n); var el = $id("ivFiyat"); if (el) el.value = sayi(n); toplamCiz(); };
  window.imIvPay = function (v) {
    var n = parse(v); IV.form.pay = isFinite(n) ? Math.round(n * 100) / 100 : NaN;
    var b = bantHesap(), el = $id("ivBant"); if (el) el.textContent = bantMetni(b);
    var x = IV.secim.x;
    if (isFinite(IV.form.pay)) {
      var bas = $id("ivBaslik");
      if (bas && /— %[\d,]+ hisse$/.test(bas.value)) { bas.value = (x.ad + " — " + payYaz(IV.form.pay) + " hisse").slice(0, 70); IV.form.baslik = bas.value; }
    }
    toplamCiz();
  };
  window.imIvPaket = function (k, on) {
    IV.paket[k] = !!on;
    document.querySelectorAll(".im .im-paket").forEach(function (el) { var c = el.querySelector("input"); el.classList.toggle("on", !!(c && c.checked)); });
    toplamCiz();
  };
  window.imIlanYayinla = async function (btn) {
    var s = IV.secim, F = IV.form;
    var veri = { varlik: s.varlik, id: s.x.id, baslik: F.baslik, aciklama: F.aciklama, fiyat: F.fiyat, pazarlik: !!F.pazarlik, mali_goster: !!F.mali,
      paketler: Object.keys(IV.paket).filter(function (k) { return IV.paket[k]; }) };
    if (s.varlik === "hisse") veri.pay = F.pay;
    try {
      var r = await calis(btn, function () { return API.rpc("ilan_ver", { p_veri: veri }); }, function (x) { return "İlanın yayında! İlan no " + x.no + "."; });
      IV.secim = null; IV.v = null; IV.form = null;
      await cuzdanTazele();
      // İlan ver adımlarını geçmişten çıkar, yeni ilanın sayfasını aç
      if (typeof D !== "undefined" && D.yigin) { D.yigin.pop(); D.yigin.pop(); }
      return ekranAc(function () { return detay(Number(r.id)); });
    } catch (_) {}
  };
  window.ilanVerEkrani = function () { IV.secim = null; IV.v = null; IV.form = null; return ekranAc(ivAdim1); };

  /* =====================================================================
     HESABIM: ilanlarım, gelen / verdiğim teklifler, favoriler
     ===================================================================== */
  var HS = { sekme: "ilanlar", v: null };
  async function hesabim() {
    stilKur();
    if (!HS.v) yukleniyor("İlanlarım");
    try { HS.v = await API.rpc("ilan_hesabim"); IM.tarife = HS.v.tarife || IM.tarife; }
    catch (err) { return ekran("İlanlarım", '<div class="im">' + bos(esc(hata(err))) + '</div>'); }
    hesabimCiz();
  }
  function hesabimCiz() {
    var v = HS.v || {}, s = HS.sekme;
    var gelenAcik = (v.gelen || []).filter(function (t) { return t.durum === "bekliyor"; }).length;
    var karsi = (v.giden || []).filter(function (t) { return t.durum === "karsi"; }).length;
    var h = '<div class="im"><nav class="im-sekme" role="tablist">' +
      [["ilanlar", "İlanlarım"], ["gelen", "Gelen teklifler", gelenAcik], ["giden", "Tekliflerim", karsi], ["favori", "Favoriler"]].map(function (x) {
        return '<button type="button" role="tab" aria-selected="' + (s === x[0]) + '" class="' + (s === x[0] ? "on" : "") + '" onclick="imHsSekme(\'' + x[0] + '\')">' + x[1] + (x[2] ? '<i>' + x[2] + '</i>' : '') + '</button>';
      }).join("") + '</nav>';
    if (s === "ilanlar") {
      var l = v.ilanlar || [];
      h += '<button class="btn" style="margin-bottom:12px" onclick="ilanVerEkrani()">+ Yeni ilan ver</button>';
      h += l.length ? '<div class="im-liste">' + l.map(function (x) {
        var dur = x.durum === "yayinda" ? "Yayında · " + kalan(x.bitis) : x.durum === "satildi" ? "Satıldı · " + tl(x.satis_bedeli) : x.durum === "kaldirildi" ? "Kaldırıldı" : x.durum === "suresi_doldu" ? "Süresi doldu" : "Yayından kalktı";
        var ek = Object.assign({}, x, { ozellik: dur + " · " + Number(x.goruntulenme || 0) + " görüntülenme" + (x.favori_sayisi ? " · " + x.favori_sayisi + " favori" : "") + (x.teklif ? " · " + x.teklif + " teklif" : ""), benim: false });
        return satir(ek);
      }).join("") + '</div>' : bos('Henüz ilan vermedin. Evini, dükkânını, şirketini ya da hisseni birkaç dokunuşla satışa çıkar.', '<button class="btn ikinci" onclick="ilanVerEkrani()">İlan ver</button>');
    } else if (s === "gelen") {
      var g = v.gelen || [];
      h += g.length ? '<section class="im-kutu"><h4>İlanlarına gelen teklifler</h4>' + g.map(function (t) {
        return '<div style="padding-top:10px"><button type="button" class="im-link" onclick="imAc(' + Number(t.ilan) + ')">' + esc(t.baslik) + ' · ' + tl(t.fiyat) + ' ›</button></div>' + teklifSatiri(t, { fiyat: t.fiyat });
      }).join("") + '</section>' : bos('İlanlarına henüz teklif gelmedi.');
    } else if (s === "giden") {
      var gd = v.giden || [];
      h += gd.length ? '<section class="im-kutu"><h4>Verdiğin teklifler</h4>' + gd.map(function (t) {
        var x = '<div class="im-teklif"><div class="im-tu"><span><b>' + tl(t.tutar) + '</b></span><span class="im-r ' + (t.durum === "karsi" ? "acil" : t.durum === "bekliyor" ? "ben" : "gri") + '">' + esc(DURUM_AD[t.durum] || t.durum) + '</span></div>' +
          '<small><button type="button" class="im-link" style="font-size:12.5px" onclick="imAc(' + Number(t.ilan) + ')">' + esc(t.baslik) + '</button> · ilan ' + tl(t.fiyat) + ' · satıcı ' + esc(t.kisi) + '</small>';
        if (t.durum === "bekliyor") x += '<small>' + tl(t.emanet) + ' Güvenli Ödeme’de · ' + esc(kalan(t.bitis)) + '</small><div class="im-dg"><button class="btn ikinci" onclick="imGeriCekHs(' + Number(t.id) + ',this)">Teklifi geri çek</button></div>';
        if (t.durum === "karsi") x += '<small>Satıcının karşı teklifi: <b>' + tl(t.karsi) + '</b> · ' + esc(kalan(t.bitis)) + '</small><div class="im-dg"><button class="btn" onclick="imKarsiHs(' + Number(t.id) + ',true,this)">Kabul et</button><button class="btn ikinci" onclick="imKarsiHs(' + Number(t.id) + ',false,this)">Reddet</button></div>';
        return x + '</div>';
      }).join("") + '</section>' : bos('Henüz teklif vermedin. Beğendiğin ilanda “Teklif ver”e dokun.', '<button class="btn ikinci" onclick="ekranAc(ilanMeydaniEkrani)">İlanlara göz at</button>');
    } else {
      var fv = v.favoriler || [];
      h += fv.length ? '<div class="im-liste">' + fv.map(function (x) {
        return x.durum === "yayinda" ? satir(x) : satir(Object.assign({}, x, { ozellik: "Yayında değil", acil: false, vitrin: false }));
      }).join("") + '</div>' : bos('Favori ilanın yok. İlan detayındaki kalbe dokunarak takip etmeye başla.');
    }
    h += '</div>';
    ekran("İlanlarım", h);
  }
  window.imHsSekme = function (s) { HS.sekme = s; hesabimCiz(); };
  window.imGeriCekHs = async function (tid, btn) {
    try { await calis(btn, function () { return API.rpc("ilan_teklif_geri_cek", { p_teklif: tid }); }, "Teklifin geri çekildi, emanetin iade edildi."); await cuzdanTazele(); hesabim(); } catch (_) {}
  };
  window.imKarsiHs = async function (tid, kabul, btn) {
    if (kabul) { var ok = await sor("Karşı teklifi kabul et", "Karşı teklif tutarıyla satın alıyorsun; aradaki fark cüzdanından düşülecek.", "Kabul et"); if (!ok) return; }
    try {
      await calis(btn, function () { return API.rpc("ilan_karsi_yanit", { p_teklif: tid, p_kabul: !!kabul }); }, kabul ? "Hayırlı olsun! Satın alma tamamlandı." : "Karşı teklifi reddettin; emanetin iade edildi.");
      await cuzdanTazele();
      hesabim();
    } catch (_) {}
  };
  window.ilanHesabimEkrani = function (sekme) { HS.sekme = sekme || "ilanlar"; HS.v = null; return ekranAc(hesabim); };

  /* =====================================================================
     ESKİ EKRANLARDAN YÖNLENDİRME
     Eski "Emlak pazarı" kapandı (boş liste döner); artık İlan Meydanı'nın emlak bölümü açılır.
     ===================================================================== */
  try {
    window.emlakYeniEkrani = function () { var f = { kategori: "emlak", sirala: "akilli", sayfa: 1 }; return liste(f); };
  } catch (_) {}
  stilKur();
})();
