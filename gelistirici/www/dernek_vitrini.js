/* Seçim Online — Dernekler 2.0 (2026-11-05).
   Ana sayfa: künye + 4 sekme (Derneklerim · Keşfet · Sokak · Yardım). Üyesi olunan dernekler artık iki kez listelenmez.
   Dernek sayfası: künye (amblem, amaç, sayılar), yönetim masası, Akış/Üyeler/Şubeler/Kasa sekmeleri ve diğer bölümler.
   Veri: dernekler, dernek_akis, dernek_detay; Yardım sekmesi açılınca dernek_kampanya_vitrin + dernek_ziyaret_taleplerim.
   Sunucu ve RPC'ler değişmedi. İşlem pencereleri (stkKatil, stkBagisModal, stkEylemModal, stkSubeModal, stkUyeIslem,
   stkKurModal, stkFaaliyetEkrani, sosDernekPanel…) eski modüllerden aynen kullanılır. */
(function () {
"use strict";
if (window.SO_DERNEK_VITRINI_V2) return;
window.SO_DERNEK_VITRINI_V2 = true;

var S = { liste: null, akis: null, sekme: null, ara: "", alan: "tumu", yardim: null, yardimZaman: 0, yardimYukleniyor: false, detay: {}, dsekme: "akis", istek: 0, dIstek: 0 };
try { var _s = sessionStorage.getItem("dv_sekme"); if (_s) S.sekme = _s; var _d = sessionStorage.getItem("dv_dsekme"); if (_d) S.dsekme = _d; } catch (_) {}

var esc = function (v) { return String(v == null ? "" : v).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); };
var sayi = function (v) { return Math.max(0, Number(v) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }); };
var para = function (v) { return typeof tlYaz === "function" ? tlYaz(v) : sayi(v) + " ₺"; };
var nid = function (v) { var n = Number(v); return Number.isSafeInteger(n) && n > 0 ? n : 0; };
var dizi = function (v) { return Array.isArray(v) ? v : []; };
var simdiMs = function () { return typeof simdi === "function" ? simdi() : Date.now(); };
var AY = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
function parca(ts) {
  var d = new Date(ts); if (isNaN(d)) return null;
  var p = {}; new Intl.DateTimeFormat("tr-TR", { timeZone: "Europe/Istanbul", year: "numeric", month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .formatToParts(d).forEach(function (x) { p[x.type] = x.value; });
  return { g: +p.day, a: +p.month, y: +p.year, s: p.hour, d: p.minute };
}
function gunAnahtar(ms) { var p = parca(ms); return p ? p.y + "-" + p.a + "-" + p.g : ""; }
function tarihYaz(ts) { var p = parca(ts); return p ? p.g + " " + AY[p.a - 1] : ""; }
function zamanYaz(ts) {                                   // geçmiş: az önce / 5 dk önce / 3 sa önce / dün 16:10 / 4 Kasım
  var t = new Date(ts).getTime(); if (!isFinite(t)) return "";
  var ms = simdiMs() - t, p = parca(t);
  if (ms < 0) return ileriYaz(ts);
  if (ms < 6e4) return "az önce";
  if (ms < 36e5) return Math.floor(ms / 6e4) + " dk önce";
  if (gunAnahtar(t) === gunAnahtar(simdiMs())) return Math.floor(ms / 36e5) + " sa önce";
  if (gunAnahtar(t) === gunAnahtar(simdiMs() - 864e5)) return "dün " + p.s + ":" + p.d;
  return p.g + " " + AY[p.a - 1];
}
function ileriYaz(ts) {                                   // gelecek: bugün 23:10 / yarın 23:10 / 8 Kasım 23:10
  var t = new Date(ts).getTime(), p = parca(t); if (!p) return "";
  var k = gunAnahtar(t);
  if (k === gunAnahtar(simdiMs())) return "bugün " + p.s + ":" + p.d;
  if (k === gunAnahtar(simdiMs() + 864e5)) return "yarın " + p.s + ":" + p.d;
  return p.g + " " + AY[p.a - 1] + " " + p.s + ":" + p.d;
}
function kalanYaz(ms) {
  if (ms <= 0) return "şimdi";
  var dk = Math.ceil(ms / 6e4), g = Math.floor(dk / 1440), sa = Math.floor(dk % 1440 / 60), d = dk % 60;
  if (g > 0) return g + " gün" + (sa ? " " + sa + " sa" : "");
  if (sa > 0) return sa + " sa" + (d ? " " + d + " dk" : "");
  return d + " dk";
}
function ekDe(ad) {                                       // İzmir'de, Sinop'ta, Muş'ta
  var s = String(ad || ""); if (!s) return s;
  var k = s.toLocaleLowerCase("tr-TR"), v = "a", son = k.slice(-1);
  for (var i = k.length - 1; i >= 0; i--) { var c = k[i]; if ("aıouâû".indexOf(c) >= 0) { v = "a"; break; } if ("eiöüî".indexOf(c) >= 0) { v = "e"; break; } }
  return s + "'" + ("fstkçşhp".indexOf(son) >= 0 ? "t" : "d") + v;
}
function hata(err) { var m = err && err.message || String(err || ""); return typeof hataCevir === "function" ? hataCevir(m) : m; }
function benKad() { try { return D.durum.profil.kad || ""; } catch (_) { return ""; } }
function hex2(h, a) { var m = /^#?([0-9a-f]{6})$/i.exec(h || ""); if (!m) return "rgba(223,127,69," + a + ")"; var n = parseInt(m[1], 16); return "rgba(" + (n >> 16 & 255) + "," + (n >> 8 & 255) + "," + (n & 255) + "," + a + ")"; }
function koyu(h, o) { var m = /^#?([0-9a-f]{6})$/i.exec(h || ""); if (!m) return "#3a2219"; var n = parseInt(m[1], 16), r = n >> 16 & 255, g = n >> 8 & 255, b = n & 255, k = [11, 17, 48];
  var f = function (x, y) { return Math.round(x + (y - x) * o); }; return "rgb(" + f(r, k[0]) + "," + f(g, k[1]) + "," + f(b, k[2]) + ")"; }

/* ---------- Çalışma alanları: ad ve renk ---------- */
var ALAN = {
  genel: ["Genel", "#df7f45"], emek: ["Emek ve Sendika", "#e0565b"], cevre: ["Çevre", "#2f9e64"], hak: ["İnsan Hakları", "#d4a233"],
  genclik: ["Gençlik", "#2e86de"], kadin: ["Kadın", "#c94a7d"], egitim: ["Eğitim", "#3a9fd6"], esnaf: ["Esnaf ve Meslek", "#d9932b"],
  hayvan: ["Hayvan Hakları", "#b07a45"], kultur: ["Kültür ve Sanat", "#8a68f2"], yerel: ["Kent ve Yerel", "#16a0a6"]
};
var ALAN_SIRA = ["genel", "emek", "cevre", "hak", "genclik", "kadin", "egitim", "esnaf", "hayvan", "kultur", "yerel"];
function alanRenk(k) { return (ALAN[k] || ALAN.genel)[1]; }
function alanAd(d) { return d.alan_ad || (ALAN[d.alan] || ["Genel"])[0]; }
var DURAK = { "ve": 1, "ile": 1, "için": 1, "derneği": 1, "dernegi": 1, "vakfı": 1, "vakfi": 1, "der.": 1, "the": 1, "of": 1 };
function monogram(ad) {
  var w = String(ad || "").split(/[\s\-–—_.,'’"]+/).filter(function (x) { return x && !DURAK[x.toLocaleLowerCase("tr-TR")] && /[\p{L}\p{N}]/u.test(x); });
  if (!w.length) return "D";
  var h = w.length > 1 ? Array.from(w[0])[0] + Array.from(w[1])[0] : Array.from(w[0]).slice(0, 2).join("");
  return h.toLocaleUpperCase("tr-TR");
}
function amblem(d, boy) {
  var r = alanRenk(d.alan);
  return '<span class="dv-amblem ' + (boy || "") + '" style="--a:' + r + ';--a2:' + koyu(r, .55) + '" aria-hidden="true">' + esc(monogram(d.ad)) + '</span>';
}

/* ---------- Simgeler ---------- */
var sv = function (p) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>'; };
var IK = {
  dernek: sv('<path d="M4 21V9l8-5 8 5v12"/><path d="M9 21v-6h6v6"/><path d="M8 10h8"/>'),
  arti: sv('<path d="M12 5v14M5 12h14"/>'),
  ara: sv('<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>'),
  megafon: sv('<path d="M3 11v2a1 1 0 0 0 1 1h2l5 4V6L6 10H4a1 1 0 0 0-1 1z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M18.5 5.5a9 9 0 0 1 0 13"/>'),
  belge: sv('<path d="M14 3H6a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V8z"/><path d="M14 3v5h5M8.5 13h7M8.5 17h5"/>'),
  el: sv('<path d="M7 11V5.5a1.5 1.5 0 0 1 3 0V10m0-1.5V4a1.5 1.5 0 0 1 3 0v6m0-4.5a1.5 1.5 0 0 1 3 0V11m0-3a1.5 1.5 0 0 1 3 0v6a7 7 0 0 1-7 7h-1.5a6 6 0 0 1-4.6-2.2L4 15.2a1.6 1.6 0 0 1 2.4-2.1L7 14"/>'),
  bayrak: sv('<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'),
  konum: sv('<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>'),
  kalp: sv('<path d="M12 20s-7.5-4.6-9.2-9.3C1.5 7.1 3.8 4 7.1 4c2 0 3.6 1.1 4.9 2.8C13.3 5.1 14.9 4 16.9 4c3.3 0 5.6 3.1 4.3 6.7C19.5 15.4 12 20 12 20z"/>'),
  el2: sv('<path d="M11 14h2a2 2 0 0 0 0-4h-3c-.6 0-1.1.2-1.4.6L3 16"/><path d="m7 20 1.6-1.4c.3-.4.8-.6 1.4-.6h4c1.1 0 2.1-.4 2.8-1.2l4.6-4.4a2 2 0 0 0-2.8-2.9l-4.2 3.9"/><path d="m2 15 6 6"/>'),
  sandik: sv('<path d="M4 11h16v9H4z"/><path d="M8 11V5h8v6M10 8h4"/>'),
  sube: sv('<path d="M3 21h18M5 21V10l7-5 7 5v11"/><path d="M10 21v-5h4v5"/>'),
  kasa: sv('<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h3"/>'),
  kilit: sv('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
  kisiler: sv('<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M21.5 20a6.5 6.5 0 0 0-4-6"/>'),
  ok: sv('<path d="m9 6 6 6-6 6"/>'),
  takvim: sv('<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>'),
  cikis: sv('<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l-5-5 5-5M5 12h11"/>'),
  ayar: sv('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>')
};
var TUR = {
  protesto: { ad: "Protesto", ik: "bayrak", r: "#ff7479" },
  basin: { ad: "Basın açıklaması", ik: "megafon", r: "#6fb3ff" },
  bildiri: { ad: "Bildiri", ik: "belge", r: "#b9a6ff" },
  destek: { ad: "Destek açıklaması", ik: "el", r: "#5fd8a4" }
};
var KAMP_TUR = { agac: "Ağaçlandırma", gida: "Gıda yardımı", burs: "Öğrenci bursu", hayvan: "Sokak hayvanları", temizlik: "Çevre temizliği", kultur: "Kültür ve sanat" };
var ZIY_DURUM = { bekliyor: ["Yanıt bekliyor", "altin"], kabul: ["Kabul edildi", "yesil"], red: ["Reddedildi", "kirmizi"], tamam: ["Gerçekleşti", ""] };

/* ---------- Stil ---------- */
function stil() {
  if (document.getElementById("so-dernek-stil-v2")) return;
  var css = document.createElement("style"); css.id = "so-dernek-stil-v2";
  css.textContent = [
  ".dv{--dv1:#df7f45;--dv2:#43241f}",".dv [hidden]{display:none!important}",".dv-iz{display:block;height:0}",
  /* künye kartı (premium kurum kartının dili; kendi işlem düğmesiyle) */
  ".dv .dv-kunye .pa-ust{padding-right:84px}",
  ".dv .dv-kunye .dv-cta{position:relative;display:inline-flex;align-items:center;gap:6px;margin-top:12px;padding:8px 13px 8px 10px;border:0;border-radius:999px;background:rgba(255,255,255,.94);color:#43241f;font-weight:800;font-size:13.5px;cursor:pointer;box-shadow:0 8px 18px -10px rgba(0,0,0,.6)}",
  ".dv .dv-kunye .dv-cta svg{width:16px;height:16px}",
  ".dv .dv-kunye .dv-cta:active{transform:scale(.97)}",
  /* sekmeler */
  "#icerik .segment.dv-sekme{position:sticky!important;top:-14px;z-index:6;margin:0 -16px 14px!important;padding:10px 16px!important;background:var(--bg)!important;box-shadow:0 10px 14px -14px rgba(0,0,0,.9)!important}",
  "#icerik .segment.dv-sekme>button{flex:1 1 auto!important;padding:9px 10px!important;min-width:0;position:relative}",
  "#icerik .segment.dv-sekme>button .dv-n{margin-left:5px;font-size:12px;opacity:.6;font-variant-numeric:tabular-nums}",
  "#icerik .segment.dv-sekme>button .dv-nokta{display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--al);margin-left:5px;vertical-align:2px;box-shadow:0 0 0 3px rgba(240,69,75,.2)}",
  "@media(max-width:360px){#icerik .segment.dv-sekme>button{padding:8px 6px!important;font-size:12.5px!important}#icerik .segment.dv-sekme>button .dv-n{display:none}}",
  /* başlıklar */
  ".dv-bas{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin:20px 2px 10px}",
  ".dv-bas:first-child{margin-top:4px}",
  ".dv-bas h2{font-family:var(--disp);font-size:21px;font-weight:700;line-height:1.1;margin:0;letter-spacing:-.2px}",
  ".dv-bas span{font-size:12px;color:var(--mut);white-space:nowrap}",
  ".dv-not{margin:10px 4px 0;font-size:12.5px;line-height:1.5;color:var(--mut)}",
  ".dv-bos{padding:26px 18px;text-align:center;color:var(--mut);font-size:14px;line-height:1.5}",
  ".dv-bos b{display:block;color:var(--txt);font-size:16px;margin-bottom:4px}",
  /* amblem */
  ".dv-amblem{flex:none;display:grid;place-items:center;width:46px;height:46px;border-radius:14px;background:linear-gradient(145deg,var(--a),var(--a2));color:#fff;font:700 17px/1 var(--disp);letter-spacing:.3px;box-shadow:inset 0 1px 0 rgba(255,255,255,.25),inset 0 0 0 1px rgba(255,255,255,.10),0 8px 16px -10px var(--a)}",
  ".dv-amblem.k{width:38px;height:38px;border-radius:12px;font-size:14px}",
  ".dv-amblem.l{width:68px;height:68px;border-radius:20px;font-size:26px;box-shadow:inset 0 1px 0 rgba(255,255,255,.28),inset 0 0 0 1.5px rgba(255,255,255,.16),0 0 0 4px rgba(255,255,255,.05),0 14px 26px -14px var(--a)}",
  /* liste */
  ".dv-liste{display:flex;flex-direction:column;background:var(--panel);border:1px solid var(--line);border-radius:18px;overflow:hidden}",
  ".dv-satir{display:flex;align-items:center;gap:13px;width:100%;padding:12px 14px;background:none;border:0;color:inherit;text-align:left;cursor:pointer;min-width:0;font:inherit}",
  ".dv-satir+.dv-satir{border-top:1px solid var(--line)}",
  ".dv-satir[hidden]{display:none!important}",
  ".dv-satir:active{background:rgba(255,255,255,.035)}",
  ".dv-satir-orta{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px}",
  ".dv-satir-orta .dv-ad{font-size:15px;font-weight:700;line-height:1.28;color:var(--txt);display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden;overflow-wrap:anywhere}",
  ".dv-satir-orta small{font-size:12.5px;color:var(--mut);line-height:1.35;overflow-wrap:anywhere}",
  ".dv-satir-sag{flex:none;display:flex;align-items:center;gap:8px;color:var(--faint)}",
  ".dv-satir-sag svg{width:17px;height:17px}",
  ".dv-sayi{flex-direction:column;align-items:flex-end;gap:0;min-width:34px}",
  ".dv-sayi b{font:700 20px/1 var(--disp);color:var(--txt);font-variant-numeric:tabular-nums}",
  ".dv-sayi small{font-size:11px;color:var(--mut);margin-top:2px}",
  ".dv-rol{display:inline-flex;align-items:center;padding:2px 7px;border-radius:6px;font-size:11px;font-weight:800;background:var(--panel2);color:var(--txt2);white-space:nowrap;vertical-align:1px}",
  ".dv-rol.altin{background:rgba(242,179,61,.16);color:#F2C164}.dv-rol.mor{background:var(--inkbg);color:var(--ink2)}.dv-rol.yesil{background:rgba(52,201,138,.13);color:var(--good)}.dv-rol.kirmizi{background:var(--albg);color:var(--al2)}",
  ".dv-satir-orta small .dv-rol{margin-right:6px}",
  /* arama ve alan çipleri */
  ".dv-ara{position:relative;margin:0 0 10px}.dv-ara svg{position:absolute;left:13px;top:50%;width:17px;height:17px;transform:translateY(-50%);color:var(--mut);pointer-events:none}",
  ".dv-ara input{display:block;width:100%;box-sizing:border-box;padding:12px 12px 12px 39px;border-radius:13px;background:var(--panel);border:1px solid var(--line2);color:var(--txt);font-size:15px;-webkit-user-select:text;user-select:text}",
  ".dv-ara input::placeholder{color:var(--faint)}",
  ".dv-alanlar{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 -16px 12px;padding:0 16px 2px}",
  ".dv-alanlar::-webkit-scrollbar{display:none}",
  ".dv-alanlar button{flex:none;display:inline-flex;align-items:center;gap:6px;padding:7px 11px;border-radius:999px;border:0;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line2);color:var(--txt2);font-size:13px;font-weight:700;cursor:pointer;white-space:nowrap}",
  ".dv-alanlar button i{width:8px;height:8px;border-radius:50%;background:var(--c)}",
  ".dv-alanlar button small{font-size:11.5px;color:var(--mut);font-variant-numeric:tabular-nums}",
  ".dv-alanlar button.aktif{background:var(--paper);color:var(--paperInk);box-shadow:none}.dv-alanlar button.aktif small{color:#59607a}",
  /* çağrı kartı */
  ".dv-cagri{display:flex;align-items:center;gap:13px;margin:14px 0 0;padding:14px;border-radius:18px;background:radial-gradient(130% 160% at 100% 0%,rgba(223,127,69,.26),transparent 60%),linear-gradient(160deg,#1d2650,#151c3b);border:1px solid var(--line2);cursor:pointer;width:100%;text-align:left;color:inherit;font:inherit}",
  ".dv-cagri .dv-cagri-ik{flex:none;width:44px;height:44px;border-radius:14px;display:grid;place-items:center;background:linear-gradient(145deg,#df7f45,#8d3f22);color:#fff}",
  ".dv-cagri .dv-cagri-ik svg{width:22px;height:22px}",
  ".dv-cagri span.orta{flex:1;min-width:0}.dv-cagri b{display:block;font-size:15px}.dv-cagri small{display:block;font-size:12.5px;color:var(--txt2);margin-top:2px;line-height:1.4}",
  ".dv-cagri .ok{flex:none;color:var(--txt2)}.dv-cagri .ok svg{width:18px;height:18px}",
  /* akış satırları (açıklamalar) */
  ".dv-akis{display:flex;flex-direction:column;background:var(--panel);border:1px solid var(--line);border-radius:18px;overflow:hidden}",
  ".dv-oge{display:flex;gap:12px;padding:13px 14px;cursor:pointer;min-width:0}",
  ".dv-oge+.dv-oge{border-top:1px solid var(--line)}",
  ".dv-oge:active{background:rgba(255,255,255,.03)}",
  ".dv-oge-ik{flex:none;width:34px;height:34px;border-radius:11px;display:grid;place-items:center;background:var(--tb);color:var(--tr);margin-top:1px}",
  ".dv-oge-ik svg{width:18px;height:18px}",
  ".dv-oge-govde{flex:1;min-width:0}",
  ".dv-oge-ust{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:11.5px;font-weight:800;color:var(--tr);letter-spacing:.1px}",
  ".dv-oge-ust time{flex:none;font-weight:600;color:var(--mut)}",
  ".dv-oge h4{margin:4px 0 2px;font-size:15px;font-weight:700;line-height:1.3;color:var(--txt);overflow-wrap:anywhere}",
  ".dv-oge .dv-kim{display:block;font-size:12.5px;color:var(--txt2);overflow-wrap:anywhere}",
  ".dv-oge .dv-kim a,.dv-kim-bag{color:var(--ink2);font-weight:700;text-decoration:none;background:none;border:0;padding:0;font:inherit;cursor:pointer}",
  ".dv-oge-metin{margin:6px 0 0;font-size:13.5px;line-height:1.5;color:var(--txt2);white-space:pre-line;overflow-wrap:anywhere;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;overflow:hidden}",
  ".dv-oge.acik .dv-oge-metin{display:block;-webkit-line-clamp:unset;color:var(--txt);font-size:14.5px;user-select:text;-webkit-user-select:text}",
  ".dv-oge-ek{display:none;flex-wrap:wrap;gap:7px;margin-top:10px}.dv-oge.acik .dv-oge-ek{display:flex}",
  ".dv-oge-daha{display:inline-block;margin-top:4px;font-size:12px;font-weight:700;color:var(--mut)}.dv-oge.acik .dv-oge-daha{display:none}",
  /* düğmeler */
  ".dv-dugme{display:inline-flex;align-items:center;justify-content:center;gap:7px;border:0;border-radius:11px;padding:10px 13px;font-weight:800;font-size:13.5px;cursor:pointer;background:var(--panel2);color:var(--txt);font-family:inherit}",
  ".dv-dugme svg{width:16px;height:16px}",
  ".dv-dugme.birincil{background:var(--ink);color:#fff}.dv-dugme.kirmizi{background:var(--al);color:#fff}.dv-dugme.cizgi{background:transparent;box-shadow:inset 0 0 0 1.5px var(--line2);color:var(--txt2)}",
  ".dv-dugme.tam{display:flex;width:100%;padding:13px;font-size:15px;border-radius:13px}",
  ".dv-dugme:disabled{opacity:.5}",
  ".dv-dugme:active{transform:scale(.98)}",
  /* protestolar */
  ".dv-eylem{position:relative;margin:0 0 12px;padding:15px 15px 14px;border-radius:20px;background:radial-gradient(120% 140% at 100% 0%,rgba(240,69,75,.24),transparent 58%),linear-gradient(160deg,#25213f,#171a37);border:1px solid rgba(240,69,75,.45);box-shadow:0 18px 36px -26px rgba(240,69,75,.7)}",
  ".dv-durum{display:inline-flex;align-items:center;gap:7px;font-size:12px;font-weight:800;color:var(--al2);letter-spacing:.2px}",
  ".dv-durum i{width:8px;height:8px;border-radius:50%;background:var(--al);animation:dvNabiz 1.6s infinite}",
  ".dv-eylem-ust{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:12px;color:var(--txt2)}",
  ".dv-eylem-ust span:last-child{display:inline-flex;align-items:center;gap:4px}.dv-eylem-ust svg{width:13px;height:13px}",
  ".dv-eylem h3{margin:8px 0 3px;font:700 22px/1.12 var(--disp);color:#fff;overflow-wrap:anywhere;letter-spacing:-.2px}",
  ".dv-eylem p{margin:6px 0 0;font-size:13.5px;line-height:1.5;color:var(--txt2);overflow-wrap:anywhere}",
  ".dv-eylem .dv-kim{font-size:13px;color:var(--txt2)}",
  ".dv-eylem-sayac{display:flex;gap:0;margin:12px 0 0;border-radius:12px;background:rgba(0,0,0,.18);box-shadow:inset 0 0 0 1px rgba(255,255,255,.07)}",
  ".dv-eylem-sayac div{flex:1;padding:8px 10px}.dv-eylem-sayac div+div{border-left:1px solid rgba(255,255,255,.08)}",
  ".dv-eylem-sayac small{display:block;font-size:11px;color:var(--mut)}.dv-eylem-sayac b{display:block;font:700 18px/1.15 var(--disp);color:#fff;font-variant-numeric:tabular-nums}",
  ".dv-eylem .dv-dugme{margin-top:12px}",
  ".dv-eylem .dv-tamam{display:flex;align-items:center;justify-content:center;gap:6px;margin-top:12px;padding:11px;border-radius:12px;background:rgba(52,201,138,.12);color:var(--good);font-weight:800;font-size:14px}",
  ".dv-eylem .dv-uyari{margin-top:12px;padding:10px 12px;border-radius:12px;background:rgba(0,0,0,.18);font-size:12.5px;color:var(--txt2);line-height:1.45}",
  "@keyframes dvNabiz{0%{box-shadow:0 0 0 0 rgba(240,69,75,.55)}70%{box-shadow:0 0 0 8px rgba(240,69,75,0)}100%{box-shadow:0 0 0 0 rgba(240,69,75,0)}}",
  "@media (prefers-reduced-motion:reduce){.dv-durum i{animation:none}}",
  /* yaklaşan protesto bileti */
  ".dv-bilet{display:flex;min-width:0;margin:0 0 10px;border-radius:18px;background:var(--panel);border:1px solid var(--line2);overflow:hidden;cursor:pointer}",
  ".dv-bilet-tarih{flex:none;width:72px;padding:12px 6px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;background:var(--paper);color:var(--paperInk);position:relative}",
  ".dv-bilet-tarih::after{content:'';position:absolute;right:-1px;top:8px;bottom:8px;border-right:2px dashed rgba(14,21,48,.3)}",
  ".dv-bilet-tarih b{font:700 30px/1 var(--disp)}.dv-bilet-tarih span{font-size:12px;font-weight:700}",
  ".dv-bilet-tarih time{margin-top:5px;font:700 14px/1 var(--disp);font-variant-numeric:tabular-nums;padding:4px 7px;border-radius:7px;background:rgba(14,21,48,.08)}",
  ".dv-bilet-govde{flex:1;min-width:0;padding:12px 14px 13px}",
  ".dv-bilet-govde .dv-oge-ust{color:var(--al2)}",
  ".dv-bilet-govde h4{margin:4px 0 3px;font-size:15.5px;font-weight:700;line-height:1.3;overflow-wrap:anywhere}",
  ".dv-bilet-govde p{margin:0;font-size:12.5px;color:var(--mut);line-height:1.45;overflow-wrap:anywhere}",
  ".dv-bilet-govde p svg{width:13px;height:13px;vertical-align:-2px;margin-right:2px}",
  /* kampanyalar ve ziyaretler */
  ".dv-kampanya,.dv-ziyaret{margin:0 0 12px;padding:15px;border-radius:18px;background:var(--panel);border:1px solid var(--line)}",
  ".dv-kampanya-ust{display:flex;align-items:center;justify-content:space-between;gap:8px}",
  ".dv-kampanya-ust time{font-size:12px;color:var(--mut);white-space:nowrap}",
  ".dv-kampanya h4,.dv-ziyaret h4{margin:8px 0 2px;font-size:16px;font-weight:700;line-height:1.3;overflow-wrap:anywhere}",
  ".dv-kampanya .dv-kim-bag,.dv-ziyaret .dv-kim-bag{font-size:13px}",
  ".dv-cubuk{height:8px;border-radius:8px;background:rgba(255,255,255,.07);overflow:hidden;margin:12px 0 7px}",
  ".dv-cubuk i{display:block;height:100%;border-radius:8px;background:linear-gradient(90deg,#34c98a,#9ff0cb)}",
  ".dv-kampanya-alt{display:flex;justify-content:space-between;gap:8px;font-size:12.5px;color:var(--mut);font-variant-numeric:tabular-nums}",
  ".dv-kampanya-alt b{color:var(--txt)}",
  ".dv-kampanya .dv-dugme,.dv-ziyaret .dv-dugme{margin-top:12px}",
  ".dv-ziyaret p{margin:6px 0 0;font-size:13.5px;line-height:1.5;color:var(--txt2);overflow-wrap:anywhere}",
  ".dv-ziyaret .dv-iki{display:grid;grid-template-columns:1fr 1fr;gap:8px}.dv-ziyaret .dv-iki .dv-dugme{margin-top:12px}",
  ".dv-ziyaret small{display:block;margin-top:6px;font-size:12px;color:var(--mut)}",
  /* dernek sayfası künyesi */
  ".dv-dk{position:relative;overflow:hidden;isolation:isolate;margin:0 0 12px;padding:16px 16px 14px;border-radius:24px;background:radial-gradient(120% 120% at 0% 0%,var(--at),transparent 62%),linear-gradient(170deg,#1d2650,#141b39);border:1px solid var(--line2);box-shadow:0 22px 40px -30px var(--a)}",
  ".dv-dk-ust{display:flex;gap:14px;align-items:center}",
  ".dv-dk-bilgi{flex:1;min-width:0}",
  ".dv-alan-cip{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:800;color:var(--ac)}",
  ".dv-alan-cip i{width:7px;height:7px;border-radius:50%;background:var(--a)}",
  ".dv-dk h2{margin:4px 0 3px;font:700 25px/1.08 var(--disp);letter-spacing:-.3px;color:#fff;overflow-wrap:anywhere}",
  ".dv-dk-bilgi p{margin:0;font-size:12.5px;color:var(--txt2);line-height:1.4}",
  ".dv-amac{position:relative;margin:14px 0 0;padding:0 0 0 14px;border-left:3px solid var(--a);font-family:Georgia,'Times New Roman',serif;font-size:15px;line-height:1.55;color:var(--txt);overflow-wrap:anywhere;white-space:pre-line}",
  ".dv-amac.kisa{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;overflow:hidden}",
  ".dv-amac-ac{display:inline-block;margin:6px 0 0 17px;padding:0;border:0;background:none;color:var(--ink2);font-weight:700;font-size:13px;cursor:pointer}",
  ".dv-istat{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));margin:14px 0 0;border-radius:14px;background:rgba(5,8,25,.25);box-shadow:inset 0 0 0 1px rgba(255,255,255,.07)}",
  ".dv-istat div{padding:9px 4px 8px;text-align:center;min-width:0}.dv-istat div+div{border-left:1px solid rgba(255,255,255,.07)}",
  ".dv-istat b{display:block;font:700 18px/1.15 var(--disp);color:#fff;font-variant-numeric:tabular-nums;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
  ".dv-istat b.gizli{display:flex;justify-content:center;align-items:center;gap:3px;height:20.7px;font-size:14px;color:var(--txt2)}.dv-istat b.gizli svg{width:13px;height:13px}",
  ".dv-istat small{display:block;font-size:11px;color:var(--mut)}",
  ".dv-dk-alt{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:12px;font-size:13px;color:var(--txt2);min-width:0}",
  ".dv-baskan{display:flex;align-items:center;gap:8px;min-width:0;background:none;border:0;padding:0;color:inherit;font:inherit;cursor:pointer;text-align:left}",
  ".dv-baskan .portre{width:28px!important;height:28px!important;flex:none}",
  ".dv-baskan span{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.dv-baskan b{color:var(--txt)}",
  ".dv-islem{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:0 0 14px}",
  ".dv-islem.tek{grid-template-columns:1fr}",
  ".dv-islem .dv-dugme{padding:13px 10px;font-size:15px;border-radius:13px}",
  /* yönetim masası */
  ".dv-masa{margin:0 0 14px;padding:14px;border-radius:20px;background:var(--panel);border:1px solid var(--line)}",
  ".dv-masa-bas{display:flex;align-items:baseline;justify-content:space-between;gap:8px;margin:0 2px 11px}",
  ".dv-masa-bas h3{margin:0;font:700 18px/1.1 var(--disp)}.dv-masa-bas span{font-size:11.5px;color:var(--mut);text-align:right}",
  ".dv-masa-izgara{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px}",
  ".dv-masa-btn{display:flex;flex-direction:column;align-items:center;gap:6px;min-width:0;padding:11px 4px 10px;border:0;border-radius:15px;background:var(--panel2);color:var(--txt);text-align:center;cursor:pointer;font:inherit}",
  ".dv-masa-btn:active{transform:scale(.97)}",
  ".dv-masa-btn>i{flex:none;width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:var(--tb);color:var(--tr)}",
  ".dv-masa-btn>i svg{width:19px;height:19px}",
  ".dv-masa-btn b{display:block;max-width:100%;font-size:12.5px;line-height:1.2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.dv-masa-btn small{display:block;font-size:10.5px;color:var(--mut);line-height:1.2;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}",
  ".dv-masa-btn.kirmizi{background:linear-gradient(145deg,rgba(240,69,75,.22),rgba(240,69,75,.08));box-shadow:inset 0 0 0 1px rgba(240,69,75,.35)}",
  /* üyeler, şubeler, kasa */
  ".dv-uye{display:flex;align-items:center;gap:12px;padding:10px 14px;min-width:0}",
  ".dv-uye+.dv-uye{border-top:1px solid var(--line)}",
  ".dv-uye .dv-uye-kim{flex:1;min-width:0;display:flex;align-items:center;gap:11px;background:none;border:0;padding:0;color:inherit;font:inherit;text-align:left;cursor:pointer}",
  ".dv-uye .portre{width:40px!important;height:40px!important;flex:none}",
  ".dv-uye .dv-uye-kim span{min-width:0}.dv-uye b{display:block;font-size:14.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}",
  ".dv-uye small{display:block;font-size:12px;color:var(--mut);margin-top:1px}",
  ".dv-uye .dv-dugme{flex:none;padding:7px 11px;font-size:12.5px}",
  ".dv-iller{display:flex;flex-wrap:wrap;gap:7px;padding:14px}",
  ".dv-il{display:inline-flex;align-items:center;gap:6px;padding:7px 11px;border-radius:10px;background:var(--panel2);font-size:13px;font-weight:700;color:var(--txt2)}",
  ".dv-il.merkez{background:var(--at);color:#fff;box-shadow:inset 0 0 0 1px var(--a)}",
  ".dv-il small{font-size:10.5px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:var(--ac)}",
  ".dv-panel-alt{padding:12px 14px 14px;border-top:1px solid var(--line)}",
  ".dv-panel-alt p{margin:0 0 10px;font-size:12.5px;color:var(--mut);line-height:1.5}",
  ".dv-kasa-ust{display:flex;align-items:baseline;justify-content:space-between;gap:10px;padding:14px}",
  ".dv-kasa-ust small{font-size:12px;color:var(--mut)}.dv-kasa-ust b{font:700 26px/1 var(--disp);font-variant-numeric:tabular-nums}",
  ".dv-hareket{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 14px;border-top:1px solid var(--line)}",
  ".dv-hareket span{min-width:0;font-size:13.5px;overflow-wrap:anywhere}.dv-hareket small{display:block;font-size:11.5px;color:var(--mut);margin-top:1px}",
  ".dv-hareket b{flex:none;font-variant-numeric:tabular-nums;font-size:14px}.dv-hareket b.art{color:var(--good)}.dv-hareket b.eks{color:var(--al2)}",
  ".dv-gizlilik{display:flex;align-items:center;justify-content:space-between;gap:10px;width:100%;padding:12px 14px;border:0;border-top:1px solid var(--line);background:none;color:var(--txt2);font:inherit;font-size:13px;cursor:pointer;text-align:left}",
  ".dv-gizlilik svg{width:16px;height:16px;flex:none}",
  /* diğer bölümler */
  ".dv-baglar{display:flex;flex-direction:column;margin:4px 0 0;background:var(--panel);border:1px solid var(--line);border-radius:18px;overflow:hidden}",
  ".dv-bag{display:flex;align-items:center;gap:12px;width:100%;padding:12px 14px;background:none;border:0;color:inherit;text-align:left;cursor:pointer;font:inherit}",
  ".dv-bag+.dv-bag{border-top:1px solid var(--line)}",
  ".dv-bag:active{background:rgba(255,255,255,.03)}",
  ".dv-bag>i{flex:none;width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:var(--tb);color:var(--tr)}",
  ".dv-bag>i svg{width:19px;height:19px}",
  ".dv-bag span.orta{flex:1;min-width:0}.dv-bag b{display:block;font-size:14.5px}.dv-bag small{display:block;font-size:12px;color:var(--mut);margin-top:2px;line-height:1.35}",
  ".dv-bag .ok{flex:none;color:var(--faint)}.dv-bag .ok svg{width:17px;height:17px}",
  ".dv-ayril{display:flex;align-items:center;justify-content:center;gap:7px;width:100%;margin:16px 0 4px;padding:12px;border:0;background:none;color:var(--al2);font-weight:700;font-size:14px;cursor:pointer;font-family:inherit}",
  ".dv-ayril svg{width:16px;height:16px}",
  ".dv-kapali{margin:0 0 14px;padding:12px 14px;border-radius:14px;background:var(--albg);color:var(--al2);font-size:13.5px;font-weight:700;text-align:center}",
  /* tek yayın sayfası */
  ".dv-makale{margin:0 0 14px;padding:18px 16px;border-radius:22px;background:var(--panel);border:1px solid var(--line2)}",
  ".dv-makale .dv-oge-ust{font-size:12px}",
  ".dv-makale h2{margin:10px 0 12px;font-family:Georgia,'Times New Roman',serif;font-size:24px;line-height:1.22;font-weight:700;overflow-wrap:anywhere}",
  ".dv-makale-kim{display:flex;align-items:center;gap:11px;padding:10px 0;border-top:1px solid var(--line);border-bottom:1px solid var(--line);background:none;border-left:0;border-right:0;width:100%;color:inherit;text-align:left;font:inherit;cursor:pointer}",
  ".dv-makale-kim>span:not(.dv-amblem){flex:1;min-width:0}.dv-makale-kim b{display:block;font-size:14.5px}.dv-makale-kim small{display:block;font-size:12px;color:var(--mut)}",
  ".dv-makale-metin{margin:14px 0 0;font-family:Georgia,'Times New Roman',serif;font-size:16.5px;line-height:1.7;color:var(--txt);white-space:pre-line;overflow-wrap:anywhere;user-select:text;-webkit-user-select:text}",
  ".dv-makale-konu{margin-top:14px;font-size:13px;color:var(--txt2)}",
  ".dv-makale .dv-dugme{margin-top:12px}",
  "@media(max-width:360px){.dv-masa-bas{flex-direction:column;align-items:flex-start;gap:3px}.dv-masa-bas span{text-align:left}}",
  "@media(max-width:350px){.dv-istat{grid-template-columns:repeat(2,minmax(0,1fr))}.dv-istat div:nth-child(3){border-left:0}.dv-istat div:nth-child(n+3){border-top:1px solid rgba(255,255,255,.07)}.dv-masa-btn{padding:9px 2px}.dv-masa-btn>i{width:34px;height:34px}.dv-bilet-tarih{width:62px}.dv-bilet-tarih b{font-size:26px}.dv-dk h2{font-size:22px}}",
  "@media(min-width:700px){.dv-liste.dv-iki{display:grid;grid-template-columns:1fr 1fr}.dv-liste.dv-iki .dv-satir+.dv-satir{border-top:0}.dv-liste.dv-iki .dv-satir{border-bottom:1px solid var(--line)}}"
  ].join("");
  document.head.appendChild(css);
}

/* ---------- ortak parçalar ---------- */
function benimDernekler() { return dizi(S.liste).filter(function (x) { return x.uyesiyim; }); }
function baskanligim() { var b = benKad(); return b ? dizi(S.liste).filter(function (x) { return x.baskan === b; })[0] || null : null; }
function rolRozet(d) {
  var b = benKad();
  if (b && d.baskan === b) return '<span class="dv-rol altin">Başkan</span>';
  return d.uyesiyim ? '<span class="dv-rol">Üyesin</span>' : "";
}
function dernekSatir(d, mod) {
  var i = nid(d.id); if (!i) return "";
  var ara = [d.ad, alanAd(d), d.merkez, d.baskan].join(" ").toLocaleLowerCase("tr-TR");
  var meta = esc(alanAd(d)) + " · " + esc(d.merkez || "—") + " · " + sayi(d.sube) + " şube";
  if (mod === "benim") {
    return '<button type="button" class="dv-satir" data-dv-dernek="' + i + '" onclick="dvDernekAc(' + i + ')">' + amblem(d) +
      '<span class="dv-satir-orta"><b class="dv-ad">' + esc(d.ad) + '</b><small>' + esc(alanAd(d)) + " · " + esc(d.merkez || "—") + " · " + sayi(d.uye) + ' üye</small></span>' +
      '<span class="dv-satir-sag">' + (d.baskan && d.baskan === benKad() ? '<span class="dv-rol altin">Başkan</span>' : '') + IK.ok + '</span></button>';
  }
  return '<button type="button" class="dv-satir" data-dv-dernek="' + i + '" data-alan="' + esc(d.alan || "genel") + '" data-ara="' + esc(ara) + '" onclick="dvDernekAc(' + i + ')">' + amblem(d) +
    '<span class="dv-satir-orta"><b class="dv-ad">' + esc(d.ad) + '</b><small>' + rolRozet(d) + meta + '</small></span>' +
    '<span class="dv-satir-sag dv-sayi"><b>' + sayi(d.uye) + '</b><small>üye</small></span></button>';
}
function turBilgi(t) { return TUR[t] || TUR.basin; }
function turStil(t) { var x = turBilgi(t); return "--tr:" + x.r + ";--tb:" + hex2(x.r, .14); }
function eylemSatir(x, opt) {                   // açıklama / bildiri / destek / biten protesto: kısa satır, dokununca açılır
  opt = opt || {};
  var i = nid(x.id); if (!i) return "";
  var t = turBilgi(x.tur), dId = nid(x.dernek && x.dernek.id);
  var ust = x.tur === "protesto" ? "Protesto" + (x.il ? " · " + esc(x.il) : "") + (x.bitti ? " · " + sayi(x.katilim) + " kişi katıldı" : "") : esc(t.ad);
  var zaman = x.tur === "protesto" ? (x.bitti ? zamanYaz(x.bit || x.bas) : ileriYaz(x.bas)) : zamanYaz(x.zaman);
  var kim = [];
  if (opt.dernekAdi !== false && x.dernek) kim.push('<a href="#" onclick="event.stopPropagation();dvDernekAc(' + dId + ');return false">' + esc(x.dernek.ad) + '</a>');
  if (x.hedef_ad) kim.push((x.tur === "destek" ? "Desteklenen: " : "Konu: ") + esc(x.hedef_ad));
  var kId = x.hedef_tur === "kanun" && /^[0-9]+$/.test(String(x.hedef_id || "")) ? nid(x.hedef_id) : 0;
  var ek = [];
  if (opt.dernekAdi !== false && dId) ek.push('<button type="button" class="dv-dugme" onclick="event.stopPropagation();dvDernekAc(' + dId + ')">Derneğin sayfası</button>');
  if (kId && typeof kanunEkrani === "function") ek.push('<button type="button" class="dv-dugme" onclick="event.stopPropagation();ekranAc(()=>kanunEkrani(' + kId + '))">İlgili kanun teklifi</button>');
  var uzun = String(x.metin || "").length > 150;
  return '<article class="dv-oge" data-dv-eylem="' + i + '" style="' + turStil(x.tur) + '" onclick="dvEylemAc(this)">' +
    '<span class="dv-oge-ik">' + IK[t.ik] + '</span><div class="dv-oge-govde">' +
    '<div class="dv-oge-ust"><span>' + ust + '</span><time>' + esc(zaman) + '</time></div>' +
    '<h4>' + esc(x.baslik) + '</h4>' + (kim.length ? '<span class="dv-kim">' + kim.join(" · ") + '</span>' : "") +
    (x.metin ? '<p class="dv-oge-metin">' + esc(x.metin) + '</p>' + (uzun ? '<span class="dv-oge-daha">Devamını oku</span>' : "") : "") +
    (ek.length ? '<div class="dv-oge-ek">' + ek.join("") + '</div>' : "") + '</div></article>';
}
function katilimHtml(x) {
  var i = nid(x.id);
  if (x.katildim) return '<div class="dv-tamam">✓ Protestodasın</div>';
  if (x.benim_ilim) return '<button type="button" class="dv-dugme kirmizi tam" onclick="stkProtestoKatil(' + i + ')">' + IK.bayrak + 'Protestoya katıl</button>';
  return '<div class="dv-uyari">Yalnız ' + esc(x.il) + ' il kaydı olanlar katılabilir. Bitince katılım Gündem\'e haber olur.</div>';
}
function canliKart(x, opt) {
  opt = opt || {};
  var dId = nid(x.dernek && x.dernek.id), bit = new Date(x.bit).getTime();
  return '<article class="dv-eylem canli" data-dv-eylem="' + nid(x.id) + '">' +
    '<div class="dv-eylem-ust"><span class="dv-durum"><i></i>CANLI</span><span>' + IK.konum + esc(x.il) + '</span></div>' +
    '<h3>' + esc(x.baslik) + '</h3>' +
    (opt.dernekAdi !== false && x.dernek ? '<button type="button" class="dv-kim-bag dv-kim" onclick="dvDernekAc(' + dId + ')">' + esc(x.dernek.ad) + '</button>' : "") +
    (x.hedef_ad ? '<div class="dv-kim">Konu: ' + esc(x.hedef_ad) + '</div>' : "") +
    (x.metin ? '<p>' + esc(x.metin) + '</p>' : "") +
    '<div class="dv-eylem-sayac"><div><small>Meydanda</small><b>' + sayi(x.katilim) + ' kişi</b></div><div><small>Bitmesine</small><b data-dv-sayac="' + esc(x.bit) + '">' + esc(kalanYaz(bit - simdiMs())) + '</b></div></div>' +
    katilimHtml(x) + '</article>';
}
function biletKart(x, opt) {
  opt = opt || {};
  var p = parca(x.bas) || { g: "", a: 1, s: "", d: "" }, dId = nid(x.dernek && x.dernek.id);
  var git = opt.dernekAdi !== false && dId ? ' onclick="dvDernekAc(' + dId + ')"' : "";
  return '<article class="dv-bilet" data-dv-eylem="' + nid(x.id) + '"' + git + '>' +
    '<div class="dv-bilet-tarih"><b>' + p.g + '</b><span>' + AY[p.a - 1].slice(0, 3) + '</span><time>' + p.s + ':' + p.d + '</time></div>' +
    '<div class="dv-bilet-govde"><div class="dv-oge-ust"><span>Protesto</span><time data-dv-sayac-on="' + esc(x.bas) + '">' + esc(kalanYaz(new Date(x.bas).getTime() - simdiMs())) + ' sonra</time></div>' +
    '<h4>' + esc(x.baslik) + '</h4><p>' + IK.konum + esc(x.il) + (opt.dernekAdi !== false && x.dernek ? ' · ' + esc(x.dernek.ad) : "") + '</p></div></article>';
}
function protestoAyir(l) {
  var t = simdiMs(), c = [], y = [], b = [];
  dizi(l).forEach(function (x) {
    if (x.tur !== "protesto") return;
    if (x.canli) c.push(x); else if (x.bitti || new Date(x.bit).getTime() <= t) b.push(x); else y.push(x);
  });
  y.sort(function (a, z) { return new Date(a.bas) - new Date(z.bas); });
  return { canli: c, yakin: y, bitti: b };
}

/* ---------- Ana sayfa ---------- */
function kunyeHtml() {
  var l = dizi(S.liste), ben = benimDernekler(), bas = baskanligim();
  var pr = protestoAyir(S.akis && S.akis.protestolar), son = simdiMs() - 864e5;
  var acik = dizi(S.akis && S.akis.aciklamalar).filter(function (x) { return new Date(x.zaman).getTime() >= son; }).length;
  var cta = bas ? '<button type="button" class="dv-cta" onclick="dvDernekAc(' + nid(bas.id) + ')">' + IK.dernek + 'Derneğine git</button>'
    : (typeof stkKurModal === "function" ? '<button type="button" class="dv-cta" onclick="stkKurModal()">' + IK.arti + 'Dernek kur</button>' : "");
  return '<section class="pa-hero dv-kunye" data-pa-hero="dernek" style="--a1:#df7f45;--a2:#43241f"><span class="pa-isilti" aria-hidden="true"></span>' +
    '<div class="pa-sag"><div class="pa-muhur">' + IK.dernek + '</div></div>' +
    '<div class="pa-ust"><small>Sivil toplum</small><b>' + (l.length ? sayi(l.length) + ' dernek ve vakıf' : 'Dernekler') + '</b>' +
    '<p>Üye ol, sesini yükselt, sahada iz bırak.</p>' + cta + '</div>' +
    '<div class="pa-veri"><div><small>Üyeliğin</small><b>' + ben.length + ' / 5</b></div>' +
    '<div><small>Protesto</small><b>' + (pr.canli.length + pr.yakin.length) + '</b></div>' +
    '<div><small>Açıklama</small><b>' + acik + '</b></div></div></section>';
}
function sekmelerHtml(aktif) {
  var pr = protestoAyir(S.akis && S.akis.protestolar), ben = benimDernekler().length;
  var tabs = [["benim", "Derneklerim", ben ? '<span class="dv-n">' + ben + '</span>' : ""], ["kesfet", "Keşfet", ""],
    ["sokak", "Sokak", pr.canli.length ? '<span class="dv-nokta" aria-label="canlı protesto var"></span>' : ""], ["yardim", "Yardım", ""]];
  return '<i class="dv-iz" aria-hidden="true"></i><div class="segment dv-sekme" role="tablist">' + tabs.map(function (t) {
    return '<button type="button" role="tab" data-s="' + t[0] + '" aria-selected="' + (aktif === t[0]) + '" class="' + (aktif === t[0] ? "aktif" : "") + '" onclick="dvSekme(\'' + t[0] + '\')">' + t[1] + t[2] + '</button>';
  }).join("") + '</div>';
}
function kurCagri(metin) {
  if (baskanligim() || typeof stkKurModal !== "function") return "";
  return '<button type="button" class="dv-cagri" onclick="stkKurModal()"><span class="dv-cagri-ik">' + IK.arti + '</span><span class="orta"><b>Kendi derneğini kur</b><small>' + esc(metin) + '</small></span><span class="ok">' + IK.ok + '</span></button>';
}
function benimHtml() {
  var ben = benimDernekler();
  if (!ben.length) return '<div class="dv-liste"><div class="dv-bos"><b>Henüz bir derneğe üye değilsin</b>Görüşlerine yakın bir derneğe katıl ya da kendi derneğini kur. En fazla 5 derneğe üye olabilirsin.</div></div>' +
    '<button type="button" class="dv-dugme tam" style="margin-top:12px" onclick="dvSekme(\'kesfet\')">' + IK.ara + 'Dernekleri keşfet</button>' + kurCagri("Kurucusu olarak başkan olursun; kayıtlı olduğun il merkez şube olur.");
  var bas = baskanligim();
  return '<div class="dv-bas"><h2>Üyesi olduğun dernekler</h2><span>' + ben.length + ' / 5</span></div>' +
    '<div class="dv-liste dv-iki">' + ben.map(function (d) { return dernekSatir(d, "benim"); }).join("") + '</div>' +
    '<p class="dv-not">' + (ben.length >= 5 ? 'Üyelik sınırına ulaştın. Yeni bir derneğe katılmak için birinden ayrılman gerekir.' : 'En fazla 5 derneğe üye olabilirsin; ' + (5 - ben.length) + ' hakkın kaldı.') +
    (bas ? '' : ' Bir oyuncu yalnız bir derneğin başkanı olabilir.') + '</p>' +
    haberlerHtml(ben) +
    (ben.length < 5 ? kurCagri("Kurucusu olarak başkan olursun; kayıtlı olduğun il merkez şube olur.") : "");
}
// Üyesi olunan derneklerin son eylemleri (Sokak sekmesindeki akıştan süzülür; ek istek yok)
function haberlerHtml(ben) {
  var ids = {}; ben.forEach(function (d) { ids[nid(d.id)] = 1; });
  var benim = function (x) { return x && x.dernek && ids[nid(x.dernek.id)]; };
  var a = S.akis || {}, pr = protestoAyir(dizi(a.protestolar).filter(benim));
  var ac = pr.bitti.concat(dizi(a.aciklamalar).filter(benim)).sort(function (x, y) { return new Date(y.tur === "protesto" ? y.bit : y.zaman) - new Date(x.tur === "protesto" ? x.bit : x.zaman); }).slice(0, 3);
  if (!pr.canli.length && !pr.yakin.length && !ac.length) return "";
  return '<div class="dv-bas"><h2>Derneklerinden haberler</h2><span>Son eylemler</span></div>' +
    pr.canli.map(function (x) { return canliKart(x); }).join("") + pr.yakin.slice(0, 2).map(function (x) { return biletKart(x); }).join("") +
    (ac.length ? '<div class="dv-akis">' + ac.map(function (x) { return eylemSatir(x); }).join("") + '</div>' : "");
}
function kesfetHtml() {
  var l = dizi(S.liste);
  if (!l.length) return '<div class="dv-liste"><div class="dv-bos"><b>Henüz dernek yok</b>İlk sivil toplum kuruluşunu sen kur.</div></div>' + kurCagri("Kurucusu olarak başkan olursun.");
  var say = {}; l.forEach(function (d) { var k = ALAN[d.alan] ? d.alan : "genel"; say[k] = (say[k] || 0) + 1; });
  var alanlar = ALAN_SIRA.filter(function (k) { return say[k]; });
  if (S.alan !== "tumu" && !say[S.alan]) S.alan = "tumu";
  return (l.length >= 6 ? '<div class="dv-ara">' + IK.ara + '<input id="dvAra" type="search" enterkeyhint="search" autocomplete="off" placeholder="Dernek, il ya da başkan ara" value="' + esc(S.ara) + '" oninput="dvAra(this.value)" aria-label="Dernek ara"></div>' : "") +
    (alanlar.length > 1 ? '<div class="dv-alanlar dv-yatay" role="group" aria-label="Çalışma alanı">' +
      '<button type="button" data-alan="tumu" class="' + (S.alan === "tumu" ? "aktif" : "") + '" onclick="dvAlan(\'tumu\')">Tümü <small>' + l.length + '</small></button>' +
      alanlar.map(function (k) { return '<button type="button" data-alan="' + k + '" class="' + (S.alan === k ? "aktif" : "") + '" style="--c:' + ALAN[k][1] + '" onclick="dvAlan(\'' + k + '\')"><i></i>' + esc(ALAN[k][0]) + ' <small>' + say[k] + '</small></button>'; }).join("") + '</div>' : "") +
    '<div class="dv-liste dv-iki" id="dvKatalog">' + l.map(function (d) { return dernekSatir(d, "kesfet"); }).join("") + '</div>' +
    '<div class="dv-liste" id="dvAraBos" hidden style="margin-top:10px"><div class="dv-bos"><b>Eşleşen dernek yok</b>Başka bir ad ya da il dene.</div></div>' +
    '<p class="dv-not">Sıralama üye sayısına göre. Bir derneğe dokun: amacını, üyelerini ve eylemlerini gör.</p>' + kurCagri("Aradığın dernek yok mu? Kurucusu olarak başkan olursun.");
}
function sokakHtml() {
  var a = S.akis || {}, pr = protestoAyir(a.protestolar), ac = dizi(a.aciklamalar);
  if (!pr.canli.length && !pr.yakin.length && !pr.bitti.length && !ac.length)
    return '<div class="dv-liste"><div class="dv-bos"><b>Sokaklar sakin</b>Henüz bir protesto ya da açıklama yok. Dernekler yönetim masasından protesto düzenler, basın açıklaması yapar.</div></div>';
  var h = "";
  if (pr.canli.length) h += '<div class="dv-bas"><h2>Şimdi sokakta</h2><span>' + pr.canli.length + ' protesto</span></div>' + pr.canli.map(function (x) { return canliKart(x); }).join("");
  if (pr.yakin.length) h += '<div class="dv-bas"><h2>Yaklaşan protestolar</h2><span>3 gün içinde</span></div>' + pr.yakin.map(function (x) { return biletKart(x); }).join("");
  var akis = pr.bitti.concat(ac).sort(function (x, y) { return new Date(y.tur === "protesto" ? y.bit : y.zaman) - new Date(x.tur === "protesto" ? x.bit : x.zaman); });
  if (akis.length) h += '<div class="dv-bas"><h2>Son açıklamalar</h2><span>Basın · bildiri · destek</span></div><div class="dv-akis">' + akis.map(function (x) { return eylemSatir(x); }).join("") + '</div>' +
    '<p class="dv-not">Bir açıklamaya dokun, metnin tamamını oku.</p>';
  return h;
}
function yardimHtml(baglam) {
  var y = S.yardim;
  if (!y) return '<div class="dv-liste"><div class="dv-bos">' + (S.yardimHata ? '<b>Kampanyalar yüklenemedi</b>' + esc(S.yardimHata) + '<br><button type="button" class="dv-dugme" style="margin-top:12px" onclick="dvYardimYukle(true)">Tekrar dene</button>' : 'Yükleniyor…') + '</div></div>';
  var h = "", z = dizi(y.ziyaret), k = dizi(y.kampanya);
  if (z.length) h += '<div class="dv-bas"><h2>Partine gelen ziyaret talepleri</h2><span>' + z.length + '</span></div>' + z.map(ziyaretKart).join("");
  h += '<div class="dv-bas"><h2>Açık yardım kampanyaları</h2><span>' + k.length + ' kampanya</span></div>';
  h += k.length ? k.map(kampanyaKart).join("") : '<div class="dv-liste"><div class="dv-bos"><b>Şu an açık kampanya yok</b>Dernek yönetimleri sosyal faaliyetler bölümünden bağış kampanyası açabilir.</div></div>';
  h += '<p class="dv-not">Kampanya bağışları yalnız kampanyanın amacına harcanabilir. Oyun içindeki fidan ve yardımlar gerçek dünyada yapılmış sayılmaz.</p>';
  return h;
}
function kampanyaKart(x) {
  var i = nid(x.id), dId = nid(x.dernek_id), hedef = Math.max(1, Number(x.hedef) || 0), top = Math.max(0, Number(x.toplanan) || 0);
  var oran = Math.min(100, Math.round(100 * top / hedef)), kal = new Date(x.bitis).getTime() - simdiMs();
  return '<article class="dv-kampanya" data-kampanya="' + i + '"><div class="dv-kampanya-ust"><span class="dv-rol yesil">' + esc(KAMP_TUR[x.tur] || "Yardım kampanyası") + '</span><time>' + (kal > 0 ? esc(kalanYaz(kal)) + ' kaldı' : 'Süresi doldu') + '</time></div>' +
    '<h4>' + esc(x.baslik) + '</h4>' + (dId ? '<button type="button" class="dv-kim-bag" onclick="dvDernekAc(' + dId + ')">' + esc(x.dernek) + '</button>' : '<span class="dv-kim">' + esc(x.dernek) + '</span>') +
    '<div class="dv-cubuk" role="progressbar" aria-valuenow="' + oran + '" aria-valuemin="0" aria-valuemax="100"><i style="width:' + oran + '%"></i></div>' +
    '<div class="dv-kampanya-alt"><span><b>' + esc(para(top)) + '</b> / ' + esc(para(hedef)) + '</span><span>%' + oran + '</span></div>' +
    (kal > 0 && hedef - top >= 100 ? '<button type="button" class="dv-dugme birincil tam" onclick="dvKampanyaBagis(' + i + ')">' + IK.kalp + 'Bağış yap</button>' : '') + '</article>';
}
function ziyaretKart(z) {
  var i = nid(z.id), dId = nid(z.dernek_id), d = ZIY_DURUM[z.durum] || [z.durum, ""], t = new Date(z.tarih).getTime();
  var eylem = z.durum === "bekliyor" && t > simdiMs() ? '<div class="dv-iki"><button type="button" class="dv-dugme birincil" onclick="dvZiyaret(' + i + ',true)">Kabul et</button><button type="button" class="dv-dugme cizgi" onclick="dvZiyaret(' + i + ',false)">Reddet</button></div>'
    : z.durum === "kabul" && t <= simdiMs() ? '<button type="button" class="dv-dugme birincil tam" onclick="dvZiyaretTamam(' + i + ')">Görüşmeyi tamamla</button>' : "";
  return '<article class="dv-ziyaret"><div class="dv-kampanya-ust"><span class="dv-rol ' + d[1] + '">' + esc(d[0]) + '</span><time>' + esc(ileriYaz(z.tarih)) + '</time></div>' +
    '<h4>' + (dId ? '<button type="button" class="dv-kim-bag" style="font-size:16px" onclick="dvDernekAc(' + dId + ')">' + esc(z.dernek) + '</button>' : esc(z.dernek)) + '</h4>' +
    '<small>' + esc(z.parti) + ' genel merkezini ziyaret etmek istiyor</small><p>' + esc(z.konu) + '</p>' + eylem + '</article>';
}
function aktifSekme() {
  var s = S.sekme;
  if (["benim", "kesfet", "sokak", "yardim"].indexOf(s) < 0) s = benimDernekler().length ? "benim" : "kesfet";
  return s;
}
function govdeHtml(s) { return s === "kesfet" ? kesfetHtml() : s === "sokak" ? sokakHtml() : s === "yardim" ? yardimHtml("kok") : benimHtml(); }
function kokMu() { try { return D.sekme === "dernek" && !D.yigin.length; } catch (_) { return true; } }
function kokCiz() {
  var kok = kokMu(), s = aktifSekme();
  iskelet(kok ? "Dernekler" : "Sivil toplum", '<div class="dv" data-dv="kok">' + kunyeHtml() + sekmelerHtml(s) + '<div id="dvGovde">' + govdeHtml(s) + '</div></div>', { geri: !kok });
  temizle();
  if (s === "kesfet") suz();
  sayacBaslat();
  if (s === "yardim" && (!S.yardim || simdiMs() - S.yardimZaman > 60e3)) window.dvYardimYukle(false);
}
// Eski modüllerin iskelet sarmalarının eklediği kartlar artık sayfanın kendi bölümlerinde: görünmesin.
function temizle() {
  var ic = document.getElementById("icerik"); if (!ic) return;
  ic.querySelectorAll(":scope>.kart").forEach(function (k) {
    if (k.querySelector('[onclick*="stkSosyalVitrin"],[onclick*="stkFaaliyetEkrani"],[onclick*="stkUyeDestekEkrani"],[onclick*="sosDernekPanel"]')) k.remove();
  });
  ic.querySelectorAll(":scope>.sos-menu-karti").forEach(function (k) { if (k.querySelector('[onclick*="sosDernekPanel"]')) k.remove(); });
  if (typeof portreleriTazele === "function" && ic.querySelector(".dv [data-portre]")) portreleriTazele(ic).catch(function () {});
}
function sayacBaslat() {
  if (typeof canliDurdur === "function") canliDurdur();
  if (typeof D === "undefined" || !document.querySelector("[data-dv-sayac],[data-dv-sayac-on]")) return;
  D.canli = setInterval(function () {
    var a = document.querySelectorAll("[data-dv-sayac]"), b = document.querySelectorAll("[data-dv-sayac-on]");
    if (!a.length && !b.length) { clearInterval(D.canli); D.canli = null; return; }
    a.forEach(function (x) { x.textContent = kalanYaz(new Date(x.getAttribute("data-dv-sayac")) - simdiMs()); });
    b.forEach(function (x) { x.textContent = kalanYaz(new Date(x.getAttribute("data-dv-sayac-on")) - simdiMs()) + " sonra"; });
  }, 30000);
}
function sekmeyeKaydir(sec) {                       // sekme değişince yeni içerik sekme çubuğunun hemen altından başlasın
  var ic = document.getElementById("icerik"), s = document.querySelector(sec), iz = s && s.previousElementSibling;
  if (!ic || !iz || !iz.classList.contains("dv-iz")) return;
  var hedef = iz.getBoundingClientRect().top - ic.getBoundingClientRect().top + ic.scrollTop;
  if (ic.scrollTop > hedef) ic.scrollTop = Math.max(0, hedef);
}
function suz() {
  var a = String(S.ara || "").trim().toLocaleLowerCase("tr-TR"), n = 0;
  document.querySelectorAll("#dvKatalog [data-dv-dernek]").forEach(function (el) {
    var g = (S.alan === "tumu" || el.getAttribute("data-alan") === S.alan) && (!a || el.getAttribute("data-ara").indexOf(a) >= 0);
    el.hidden = !g; if (g) n++;
  });
  var b = document.getElementById("dvAraBos"); if (b) b.hidden = n > 0;
}

/* ---------- Dış işlevler: ana sayfa ---------- */
window.stkEkrani = async function () {
  stil();
  var n = ++S.istek, kok = kokMu(), baslik = kok ? "Dernekler" : "Sivil toplum";
  if (S.liste) kokCiz(); else if (typeof yukleniyor === "function") { yukleniyor(baslik); temizle(); }
  try {
    var r = await Promise.all([API.rpc("dernekler"), API.rpc("dernek_akis", { p_limit: 15 }).catch(function () { return null; })]);
    if (n !== S.istek) return;
    var eski = JSON.stringify([S.liste, S.akis]);
    S.liste = dizi(r[0]); S.akis = r[1] && typeof r[1] === "object" ? r[1] : (S.akis || { protestolar: [], aciklamalar: [] });
    if (eski !== JSON.stringify([S.liste, S.akis]) || !document.querySelector('.dv[data-dv="kok"]')) kokCiz();
  } catch (err) {
    if (window.console) console.warn("Dernekler:", err);
    if (n !== S.istek || document.querySelector('.dv[data-dv="kok"]')) return;
    iskelet(baslik, '<div class="dv"><div class="dv-liste"><div class="dv-bos"><b>Dernekler yüklenemedi</b>' + esc(hata(err)) + '<br><button type="button" class="dv-dugme" style="margin-top:12px" onclick="stkEkrani()">Tekrar dene</button></div></div></div>', { geri: !kok });
  }
};
window.dvSekme = function (k) {
  S.sekme = ["benim", "kesfet", "sokak", "yardim"].indexOf(k) >= 0 ? k : "benim";
  try { sessionStorage.setItem("dv_sekme", S.sekme); } catch (_) {}
  var g = document.getElementById("dvGovde");
  if (!g || !S.liste) { window.stkEkrani(); return; }
  document.querySelectorAll(".dv-sekme button").forEach(function (b) { var a = b.getAttribute("data-s") === S.sekme; b.classList.toggle("aktif", a); b.setAttribute("aria-selected", a); });
  g.innerHTML = govdeHtml(S.sekme);
  if (S.sekme === "kesfet") suz();
  sayacBaslat();
  sekmeyeKaydir(".dv-sekme");
  if (S.sekme === "yardim" && (!S.yardim || simdiMs() - S.yardimZaman > 60e3)) window.dvYardimYukle(false);
};
window.dvAra = function (q) { S.ara = String(q || ""); suz(); };
window.dvAlan = function (k) {
  S.alan = ALAN[k] ? k : "tumu";
  document.querySelectorAll(".dv-alanlar button").forEach(function (b) { b.classList.toggle("aktif", b.getAttribute("data-alan") === S.alan); });
  suz();
};
window.dvDernekAc = function (id) { var i = nid(id); if (i && typeof ekranAc === "function") ekranAc(function () { return window.stkDetay(i); }); };
window.dvEylemAc = function (el) {
  if (!el || (window.getSelection && String(window.getSelection()).length)) return;
  el.classList.toggle("acik");
};
window.dvYardimYukle = async function (zorla) {
  if (S.yardimYukleniyor) return;
  if (!zorla && S.yardim && simdiMs() - S.yardimZaman < 60e3) return;
  S.yardimYukleniyor = true; S.yardimHata = null;
  var no = typeof D !== "undefined" ? D._ekranNo : 0;
  try {
    var r = await Promise.allSettled([API.rpc("dernek_kampanya_vitrin"), API.rpc("dernek_ziyaret_taleplerim")]);
    if (r[0].status !== "fulfilled" && r[1].status !== "fulfilled") throw r[0].reason;
    S.yardim = { kampanya: r[0].status === "fulfilled" ? dizi(r[0].value) : [], ziyaret: r[1].status === "fulfilled" ? dizi(r[1].value) : [] };
    S.yardimZaman = simdiMs();
  } catch (err) { S.yardimHata = hata(err); }
  S.yardimYukleniyor = false;
  if (typeof D !== "undefined" && D._ekranNo !== no) return;          // oyuncu başka ekrana geçti
  var g = document.getElementById("dvGovde");
  if (g && S.sekme === "yardim" && document.querySelector('.dv[data-dv="kok"]')) g.innerHTML = yardimHtml("kok");
  var t = document.getElementById("dvYardimTek");
  if (t) t.innerHTML = yardimHtml("ayri");
};
async function yardimSonra() {
  S.yardimZaman = 0;
  await window.dvYardimYukle(true);
}
window.dvKampanyaBagis = function (kid) {
  var k = dizi(S.yardim && S.yardim.kampanya).filter(function (x) { return nid(x.id) === nid(kid); })[0]; if (!k) return;
  var kalan = Math.max(0, Math.floor(Number(k.hedef) - Number(k.toplanan)));
  var hizli = [500, 1000, 5000].filter(function (v) { return v < kalan; });
  var m = modal('<h3>' + esc(k.baslik) + '</h3><p class="alt">' + esc(k.dernek) + ' · Bağışın yalnız bu kampanyanın amacına harcanır. Hedefe kalan: <b>' + esc(para(kalan)) + '</b></p>' +
    '<div class="alan"><label for="dvBagis">Tutar (₺)</label><input id="dvBagis" type="number" inputmode="numeric" min="100" step="100" max="' + kalan + '" value="' + Math.min(1000, kalan) + '"></div>' +
    '<div class="dv-alanlar" style="margin:0 0 6px;padding:0;overflow:visible;flex-wrap:wrap">' + hizli.map(function (v) { return '<button type="button" data-v="' + v + '">' + esc(para(v)) + '</button>'; }).join("") + '<button type="button" data-v="' + kalan + '">Kalanın tamamı</button></div>' +
    '<div class="hata-metin" id="dvBagisHata"></div><button class="btn" id="dvBagisTamam">Bağış yap</button>');
  m.querySelectorAll("[data-v]").forEach(function (b) { b.onclick = function () { m.querySelector("#dvBagis").value = b.getAttribute("data-v"); }; });
  m.querySelector("#dvBagisTamam").onclick = async function () {
    var b = this, tutar = Math.round(Number(m.querySelector("#dvBagis").value));
    if (!(tutar >= 100)) { m.querySelector("#dvBagisHata").textContent = "Bağış en az 100 ₺ olmalı."; return; }
    b.disabled = true;
    try { await API.rpc("dernek_kampanya_bagis", { p_kampanya: nid(kid), p_tutar: tutar }); modalKapat(); toast("Bağışın kampanyaya ulaştı. Teşekkürler!"); await yardimSonra(); }
    catch (err) { b.disabled = false; m.querySelector("#dvBagisHata").textContent = hata(err); }
  };
};
window.dvZiyaret = async function (zid, kabul) {
  if (!kabul && !(await onayla("Ziyaret talebini reddet", "Derneğin başkanına reddettiğin bildirilecek.", "Reddet", true))) return;
  try { await API.rpc("dernek_ziyaret_yanit", { p_ziyaret: nid(zid), p_kabul: !!kabul }); toast(kabul ? "Ziyaret kabul edildi." : "Ziyaret talebi reddedildi."); await yardimSonra(); }
  catch (err) { toast(hata(err), true); }
};
window.dvZiyaretTamam = async function (zid) {
  if (!(await onayla("Görüşmeyi tamamla", "Görüşmenin gerçekleştiğini onaylıyorsun. Dernek ve parti bilgisi Gündem'e yansıyacak.", "Tamamla"))) return;
  try { await API.rpc("dernek_ziyaret_tamamla", { p_ziyaret: nid(zid) }); toast("Görüşme Gündem'e kaydedildi."); await yardimSonra(); }
  catch (err) { toast(hata(err), true); }
};
// Menüden "Sosyal etki merkezi" ile açılan ayrı ekran: aynı Yardım görünümü.
window.stkSosyalVitrin = async function () {
  stil();
  iskelet("Yardım kampanyaları", '<div class="dv" data-dv="yardim"><div id="dvYardimTek">' + yardimHtml("ayri") + '</div></div>', { geri: typeof D !== "undefined" && D.yigin && D.yigin.length > 0 });
  temizle();
  await window.dvYardimYukle(!S.yardim || simdiMs() - S.yardimZaman > 30e3);
};

/* ---------- Dernek sayfası ---------- */
var DSEKME = ["akis", "uyeler", "subeler", "kasa"];
function detayKunye(d) {
  var r = alanRenk(d.alan), ben = benKad();
  var rol = d.rolum === "baskan" ? '' : d.rolum === "yonetim" ? '<span class="dv-rol mor">Yönetim kurulundasın</span>' : d.rolum ? '<span class="dv-rol">Üyesin</span>' : "";
  var kasa = d.kasa === null || d.kasa === undefined ? '<b class="gizli">' + IK.kilit + 'Gizli</b>' : '<b>' + esc(kisaPara(d.kasa)) + '</b>';
  var baskan = d.baskan || (dizi(d.uyeler).filter(function (u) { return u.rol === "baskan"; })[0] || {}).kad;
  var uzun = String(d.amac || "").length > 110;
  return '<header class="dv-dk" style="--a:' + r + ';--at:' + hex2(r, .24) + ';--ac:' + mix(r) + '">' +
    '<div class="dv-dk-ust">' + amblem(d, "l") + '<div class="dv-dk-bilgi"><span class="dv-alan-cip"><i></i>' + esc(alanAd(d)) + '</span>' +
    '<h2>' + esc(d.ad) + '</h2><p>Merkez ' + esc(d.merkez || "—") + (d.kurulus ? ' · ' + esc(tarihYaz(d.kurulus)) + '\'den beri' : '') + '</p></div></div>' +
    (d.amac ? '<blockquote class="dv-amac' + (uzun ? ' kisa' : '') + '" id="dvAmac">' + esc(d.amac) + '</blockquote>' + (uzun ? '<button type="button" class="dv-amac-ac" onclick="dvAmacAc(this)">Devamını oku</button>' : '') : '') +
    '<div class="dv-istat"><div><b>' + sayi(dizi(d.uyeler).length) + '</b><small>üye</small></div><div><b>' + sayi(dizi(d.subeler).length) + '</b><small>şube</small></div>' +
    '<div>' + kasa + '<small>kasa</small></div><div><b>' + sayi(dizi(d.eylemler).length) + '</b><small>eylem</small></div></div>' +
    '<div class="dv-dk-alt">' + (baskan ? '<button type="button" class="dv-baskan" data-kad="' + esc(baskan) + '" onclick="dvOyuncu(this)">' + (typeof portre === "function" ? portre(baskan) : "") + '<span>Başkan <b>' + esc(baskan) + '</b>' + (baskan === ben ? " (sen)" : "") + '</span></button>' : '<span></span>') + rol + '</div></header>';
}
function kisaPara(v) {
  var n = Number(v) || 0, a = Math.abs(n);
  if (a >= 1e9) return (n / 1e9).toLocaleString("tr-TR", { maximumFractionDigits: 1 }) + " mr ₺";
  if (a >= 1e6) return (n / 1e6).toLocaleString("tr-TR", { maximumFractionDigits: 1 }) + " mn ₺";
  if (a >= 1e5) return Math.round(n / 1e3).toLocaleString("tr-TR") + " bin ₺";
  return para(n);
}
function mix(h) { var m = /^#?([0-9a-f]{6})$/i.exec(h || ""); if (!m) return "#f2b38e"; var n = parseInt(m[1], 16), f = function (x) { return Math.round(x + (255 - x) * .45); };
  return "rgb(" + f(n >> 16 & 255) + "," + f(n >> 8 & 255) + "," + f(n & 255) + ")"; }
function islemHtml(d) {
  if (d.kapali) return '<div class="dv-kapali">Bu dernek kapandı.</div>';
  var i = nid(d.id);
  if (d.rolum) return '<div class="dv-islem tek"><button type="button" class="dv-dugme" onclick="stkBagisModal(' + i + ')">' + IK.kalp + 'Derneğe bağış yap</button></div>';
  return '<div class="dv-islem"><button type="button" class="dv-dugme birincil" onclick="stkKatil(' + i + ')">' + IK.arti + 'Üye ol</button><button type="button" class="dv-dugme" onclick="stkBagisModal(' + i + ')">' + IK.kalp + 'Bağış yap</button></div>';
}
function masaHtml(d) {
  if (!d.yetkili || d.kapali || typeof stkEylemModal !== "function") return "";
  var i = nid(d.id);
  var btn = function (tur, ad, alt, cls) { return '<button type="button" class="dv-masa-btn ' + (cls || "") + '" style="' + turStil(tur) + '" aria-label="' + esc(turBilgi(tur).ad) + '" onclick="stkEylemModal(' + i + ',\'' + tur + '\')"><i>' + IK[turBilgi(tur).ik] + '</i><b>' + ad + '</b><small>' + alt + '</small></button>'; };
  return '<section class="dv-masa"><div class="dv-masa-bas"><h3>Yönetim masası</h3><span>Günde 3 açıklama · 1 protesto</span></div><div class="dv-masa-izgara">' +
    btn("protesto", "Protesto", "düzenle", "kirmizi") + btn("basin", "Basın", "açıklaması") +
    btn("bildiri", "Bildiri", "yayımla") + btn("destek", "Destek", "açıkla") + '</div></section>';
}
function dSekmelerHtml(d, aktif) {
  var tabs = [["akis", "Akış", ""], ["uyeler", "Üyeler", '<span class="dv-n">' + dizi(d.uyeler).length + '</span>'], ["subeler", "Şubeler", '<span class="dv-n">' + dizi(d.subeler).length + '</span>']];
  if (Array.isArray(d.hareketler)) tabs.push(["kasa", "Kasa", ""]);
  return '<i class="dv-iz" aria-hidden="true"></i><div class="segment dv-sekme dv-dsekme" role="tablist">' + tabs.map(function (t) {
    return '<button type="button" role="tab" data-s="' + t[0] + '" aria-selected="' + (aktif === t[0]) + '" class="' + (aktif === t[0] ? "aktif" : "") + '" onclick="dvDSekme(\'' + t[0] + '\')">' + t[1] + t[2] + '</button>';
  }).join("") + '</div>';
}
function dAkisHtml(d) {
  var l = dizi(d.eylemler), pr = protestoAyir(l), diger = l.filter(function (x) { return x.tur !== "protesto"; });
  if (!l.length) return '<div class="dv-liste"><div class="dv-bos"><b>Henüz eylem yok</b>' + (d.yetkili ? 'Yönetim masasından ilk açıklamayı yap ya da protesto düzenle.' : 'Dernek açıklama yaptığında ya da protesto düzenlediğinde burada görünür.') + '</div></div>';
  var h = pr.canli.map(function (x) { return canliKart(x, { dernekAdi: false }); }).join("") + pr.yakin.map(function (x) { return biletKart(x, { dernekAdi: false }); }).join("");
  var akis = pr.bitti.concat(diger).sort(function (x, y) { return new Date(y.tur === "protesto" ? y.bit || y.bas : y.zaman) - new Date(x.tur === "protesto" ? x.bit || x.bas : x.zaman); });
  if (akis.length) h += '<div class="dv-akis">' + akis.map(function (x) { return eylemSatir(x, { dernekAdi: false }); }).join("") + '</div>';
  return h;
}
function dUyelerHtml(d) {
  var rolAd = { baskan: ["Başkan", "altin"], yonetim: ["Yönetim kurulu", "mor"] }, yonet = d.rolum === "baskan" && !d.kapali && typeof stkUyeIslem === "function";
  var l = dizi(d.uyeler);
  if (!l.length) return '<div class="dv-liste"><div class="dv-bos">Üye yok.</div></div>';
  return '<div class="dv-liste">' + l.map(function (u) {
    var r = rolAd[u.rol];
    return '<div class="dv-uye"><button type="button" class="dv-uye-kim" data-kad="' + esc(u.kad) + '" onclick="dvOyuncu(this)">' + (typeof portre === "function" ? portre(u.kad) : "") +
      '<span><b>' + esc(u.kad) + '</b><small>' + (r ? '<span class="dv-rol ' + r[1] + '">' + r[0] + '</span> ' : '') + esc(u.il || "") + '</small></span></button>' +
      (yonet && u.rol !== "baskan" ? '<button type="button" class="dv-dugme" data-kad="' + esc(u.kad) + '" data-rol="' + esc(u.rol) + '" onclick="dvUyeYonet(this)">Yönet</button>' : '') + '</div>';
  }).join("") + '</div>' +
    (d.rolum === "baskan" ? '<p class="dv-not">Yönetim kurulu (en fazla 4 kişi) dernek adına açıklama yapar, protesto düzenler ve şube açar.</p>' : '');
}
function dSubelerHtml(d) {
  var l = dizi(d.subeler), u = d.sube_ucretleri || {}, r = alanRenk(d.alan);
  return '<div class="dv-liste" style="--a:' + r + ';--at:' + hex2(r, .28) + ';--ac:' + mix(r) + '"><div class="dv-iller">' + l.map(function (s) {
    return '<span class="dv-il' + (s.merkez ? ' merkez' : '') + '">' + esc(s.il) + (s.merkez ? '<small>Merkez</small>' : '') + '</span>';
  }).join("") + '</div>' +
    (d.yetkili && !d.kapali && typeof stkSubeModal === "function" ? '<div class="dv-panel-alt"><p>Protesto yalnız şubesi olan illerde yapılır. Şube bedeli dernek kasasından ödenir: küçük il ' + esc(para(u["1"])) + ', orta il ' + esc(para(u["2"])) + ', büyük il ' + esc(para(u["3"])) + '.</p>' +
      '<button type="button" class="dv-dugme birincil tam" onclick="stkSubeModal(' + nid(d.id) + ')">' + IK.sube + 'Yeni şube aç</button></div>' : '') + '</div>';
}
function dKasaHtml(d) {
  var l = dizi(d.hareketler);
  return '<div class="dv-liste"><div class="dv-kasa-ust"><small>Dernek kasası</small><b>' + (d.kasa == null ? 'Gizli' : esc(para(d.kasa))) + '</b></div>' +
    (l.length ? l.map(function (h) { var t = Number(h.tutar) || 0; return '<div class="dv-hareket"><span>' + esc(h.aciklama) + '<small>' + esc(zamanYaz(h.zaman)) + '</small></span><b class="' + (t >= 0 ? 'art' : 'eks') + '">' + (t >= 0 ? '+' : '−') + esc(para(Math.abs(t))) + '</b></div>'; }).join("")
      : '<div class="dv-hareket"><span>Henüz kasa hareketi yok.</span></div>') +
    (d.rolum === "baskan" && typeof kasaGizlilikEkrani === "function" ? '<button type="button" class="dv-gizlilik" onclick="ekranAc(kasaGizlilikEkrani)"><span>' + IK.kilit.replace('<svg', '<svg style="vertical-align:-3px;margin-right:6px"') + 'Kasa kime görünsün?</span>' + IK.ok + '</button>' : '') + '</div>' +
    '<p class="dv-not">Son 15 hareket. Kasa hareketlerini yalnız başkan ve yönetim kurulu görür.</p>';
}
function dGovdeHtml(d, s) { return s === "uyeler" ? dUyelerHtml(d) : s === "subeler" ? dSubelerHtml(d) : s === "kasa" ? dKasaHtml(d) : dAkisHtml(d); }
function baglarHtml(d) {
  var i = nid(d.id), l = [];
  var bag = function (ik, renk, ad, alt, js) { return '<button type="button" class="dv-bag" style="--tr:' + renk + ';--tb:' + hex2(renk, .15) + '" onclick="' + js + '"><i>' + IK[ik] + '</i><span class="orta"><b>' + ad + '</b><small>' + alt + '</small></span><span class="ok">' + IK.ok + '</span></button>'; };
  if (typeof window.stkFaaliyetEkrani === "function") l.push(bag("el2", "#5fd8a4", "Sosyal faaliyetler", d.yetkili ? "Kampanya aç, proje ve hizmet başlat, gönüllü topla" : "Kampanyalar, projeler ve gönüllü etkinlikleri", "ekranAc(()=>stkFaaliyetEkrani(" + i + "))"));
  if (d.rolum && typeof window.stkUyeDestekEkrani === "function") l.push(bag("kalp", "#ff8fa8", "Üye yardımları", d.yetkili ? "Üyelerin destek başvurularını değerlendir" : "Dernekten ihtiyaç, taşınma ya da eğitim desteği iste", "ekranAc(()=>stkUyeDestekEkrani(" + i + "))"));
  if (d.rolum && typeof window.sosDernekPanel === "function") l.push(bag("sandik", "#6fb3ff", "Genel kurul ve seçimler", "Başkan ve yönetim seçimi, olağanüstü genel kurul", "ekranAc(()=>sosDernekPanel(" + i + "))"));
  if (d.kapali || !l.length) return "";
  return '<div class="dv-bas"><h2>Derneğin diğer bölümleri</h2></div><div class="dv-baglar">' + l.join("") + '</div>';
}
function detayCiz(d) {
  var s = S.dsekme; if (DSEKME.indexOf(s) < 0 || (s === "kasa" && !Array.isArray(d.hareketler))) s = "akis";
  D._stk = d;
  iskelet(esc(d.ad), '<div class="dv" data-dv="detay" data-id="' + nid(d.id) + '">' + detayKunye(d) + islemHtml(d) + masaHtml(d) + dSekmelerHtml(d, s) +
    '<div id="dvDGovde">' + dGovdeHtml(d, s) + '</div>' + baglarHtml(d) +
    (d.rolum && !d.kapali && typeof stkAyril === "function" ? '<button type="button" class="dv-ayril" onclick="stkAyril(' + nid(d.id) + ')">' + IK.cikis + 'Dernekten ayrıl</button>' : '') + '</div>', { geri: true });
  temizle();
  sayacBaslat();
  var am = document.getElementById("dvAmac");          // gerçekten kesilmiyorsa "Devamını oku" gereksiz
  if (am && am.classList.contains("kisa") && am.scrollHeight <= am.clientHeight + 2) { am.classList.remove("kisa"); var ab = document.querySelector(".dv-amac-ac"); if (ab) ab.remove(); }
}
window.stkDetay = async function (id) {
  stil();
  var i = nid(id); if (!i) return;
  var n = ++S.dIstek, onb = S.detay[i];
  if (onb) detayCiz(onb); else if (typeof yukleniyor === "function") { yukleniyor("Dernek"); temizle(); }
  try {
    var d = await API.rpc("dernek_detay", { p_dernek: i });
    if (n !== S.dIstek) return;
    if (!d || !nid(d.id)) throw new Error("Dernek bulunamadı.");
    var degisti = JSON.stringify(onb) !== JSON.stringify(d);
    S.detay[i] = d;
    if (degisti || !document.querySelector('.dv[data-dv="detay"][data-id="' + i + '"]')) detayCiz(d);
  } catch (err) {
    if (n !== S.dIstek) return;
    if (onb) { toast(hata(err), true); return; }
    iskelet("Dernek", '<div class="dv"><div class="dv-liste"><div class="dv-bos"><b>Dernek açılamadı</b>' + esc(hata(err)) + '</div></div></div>', { geri: true });
  }
};
window.dvDSekme = function (k) {
  S.dsekme = DSEKME.indexOf(k) >= 0 ? k : "akis";
  try { sessionStorage.setItem("dv_dsekme", S.dsekme); } catch (_) {}
  var g = document.getElementById("dvDGovde"), d = typeof D !== "undefined" ? D._stk : null;
  if (!g || !d) return;
  document.querySelectorAll(".dv-dsekme button").forEach(function (b) { var a = b.getAttribute("data-s") === S.dsekme; b.classList.toggle("aktif", a); b.setAttribute("aria-selected", a); });
  g.innerHTML = dGovdeHtml(d, S.dsekme);
  temizle(); sayacBaslat();
  sekmeyeKaydir(".dv-dsekme");
};
window.dvAmacAc = function (b) { var a = document.getElementById("dvAmac"); if (a) a.classList.remove("kisa"); if (b) b.remove(); };
window.dvOyuncu = function (el) { var k = el && el.getAttribute("data-kad"); if (k && typeof oyuncuKart === "function") oyuncuKart(k); };
window.dvUyeYonet = function (el) {
  var d = typeof D !== "undefined" ? D._stk : null, k = el && el.getAttribute("data-kad");
  if (d && k && typeof stkUyeIslem === "function") stkUyeIslem(nid(d.id), k, el.getAttribute("data-rol") || "uye");
};

/* ---------- Tek yayın (bildirimden açılan açıklama) ---------- */
window.stkYayinGoster = async function (id) {
  stil();
  if (typeof yukleniyor === "function") yukleniyor("Yayın");
  var x;
  try { x = await API.rpc("dernek_eylem_oku", { p_eylem: nid(id) }); }
  catch (err) { iskelet("Yayın", '<div class="dv"><div class="dv-liste"><div class="dv-bos">' + esc(hata(err)) + '</div></div></div>', { geri: true }); return; }
  if (!x || !x.id) { iskelet("Yayın", '<div class="dv"><div class="dv-liste"><div class="dv-bos">Bu yayın kaldırılmış ya da artık erişilemiyor.</div></div></div>', { geri: true }); return; }
  var t = turBilgi(x.tur), dId = nid(x.dernek && x.dernek.id);
  var kId = x.hedef_tur === "kanun" && /^[0-9]+$/.test(String(x.hedef_id || "")) ? nid(x.hedef_id) : 0;
  var zaman = x.tur === "protesto" ? ileriYaz(x.bas) : zamanYaz(x.zaman);
  var govde = x.tur === "protesto" && x.canli ? canliKart(x)
    : '<article class="dv-makale" style="' + turStil(x.tur) + '"><div class="dv-oge-ust"><span>' + esc(t.ad) + (x.il ? ' · ' + esc(x.il) : '') + '</span><time>' + esc(zaman) + '</time></div>' +
      '<h2>' + esc(x.baslik) + '</h2>' +
      (x.dernek ? '<button type="button" class="dv-makale-kim" onclick="dvDernekAc(' + dId + ')">' + amblem({ ad: x.dernek.ad, alan: x.dernek.alan }, "k") + '<span><b>' + esc(x.dernek.ad) + '</b><small>' + (x.yazan ? esc(x.yazan) + ' yayımladı' : 'Derneğin sayfasına git') + '</small></span>' + IK.ok.replace('<svg', '<svg style="width:17px;height:17px;color:var(--faint)"') + '</button>' : '') +
      (x.metin ? '<div class="dv-makale-metin">' + esc(x.metin) + '</div>' : '') +
      (x.hedef_ad ? '<div class="dv-makale-konu">' + (x.tur === "destek" ? 'Desteklenen: ' : 'Konu: ') + '<b>' + esc(x.hedef_ad) + '</b></div>' : '') +
      (x.tur === "protesto" && x.bitti ? '<div class="dv-makale-konu">Protesto ' + sayi(x.katilim) + ' kişinin katılımıyla tamamlandı.</div>' : '') +
      (kId && typeof kanunEkrani === "function" ? '<button type="button" class="dv-dugme tam" onclick="ekranAc(()=>kanunEkrani(' + kId + '))">İlgili kanun teklifine git</button>' : '') + '</article>';
  iskelet(esc(t.ad), '<div class="dv">' + govde + '</div>', { geri: true });
  sayacBaslat();
};

// sekmeAc('dernek') EKRAN haritası üzerinden stkEkrani'yi çağırır; açıkça bağla.
try { if (typeof EKRAN !== "undefined" && EKRAN) EKRAN.dernek = function () { return window.stkEkrani(); }; } catch (_) {}
})();
