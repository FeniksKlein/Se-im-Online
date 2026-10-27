/* =====================================================================
   MAĞAZA (sunucu: sql/115_magaza.sql)
   - Mağazaya giriş: üst çubuktaki cüzdan (altın +, her ekranda), Gündem'in en üstündeki şerit,
     Hayat › Mağaza ve Profilim › Mağaza. Ürünler: Başlangıç Paketi, Siyaset Kartı (30 gün), ₺ paketleri,
     Reklamsız Ödüller ve Destekçi Rozeti. Fiyatlar telefonda App Store / Google Play'den gelir;
     web'de yalnız vitrin gösterilir.
   - Siyaset Kartı günlük ödülü (Hayat ve Mağaza ekranında).
   - Reklamsız Ödüller ya da aktif Kart: "Reklam izle" reklam göstermeden ödül verir.
   - Destekçi yıldızı ve Kart rozeti: sohbette, oyuncu kartında ve profilde adın yanında.
   - Yöneticiye satış özeti.
   ===================================================================== */
(function () {
  "use strict";
  if (window.MGZ_YUKLENDI) return;
  window.MGZ_YUKLENDI = true;

  const stil = document.createElement("style");
  stil.textContent = `
  .mg-rz{display:inline-flex;align-items:center;vertical-align:-2px;margin-left:5px;gap:3px}
  .mg-rz svg{width:14px;height:14px}
  .mg-rz .mg-yildiz{color:#F2C94C}
  .mg-rz .mg-kart{font-size:10.5px;font-weight:800;letter-spacing:.2px;padding:1px 6px;border-radius:6px;background:var(--inkbg);color:var(--ink2);line-height:1.5}
  h3 .mg-rz svg{width:20px;height:20px} h3 .mg-rz .mg-kart{font-size:12px;padding:2px 8px}
  .mg-vitrin{position:relative;border-radius:18px;padding:18px 16px 16px;margin-bottom:12px;overflow:hidden;
    background:radial-gradient(120% 90% at 100% 0%,rgba(123,97,255,.35),transparent 60%),linear-gradient(160deg,var(--panel2),var(--panel));border:1px solid var(--line2)}
  .mg-vitrin.altin{background:radial-gradient(120% 90% at 100% 0%,rgba(242,201,76,.28),transparent 60%),linear-gradient(160deg,var(--panel2),var(--panel))}
  .mg-vitrin h2{font-size:22px;margin:2px 0 4px} .mg-vitrin .alt{margin:0 0 10px}
  .mg-etiket{display:inline-block;font-size:12px;font-weight:800;padding:3px 9px;border-radius:999px;background:var(--ink);color:#fff}
  .mg-vitrin.altin .mg-etiket{background:#F2C94C;color:#1a1530}
  .mg-liste{list-style:none;margin:0 0 12px;padding:0}
  .mg-liste li{display:flex;gap:9px;align-items:flex-start;padding:5px 0;font-size:15px;line-height:1.35}
  .mg-liste li svg{flex:0 0 18px;width:18px;height:18px;color:var(--good);margin-top:1px}
  .mg-fiyat{width:auto !important;flex:0 0 auto;min-width:104px;padding:10px 14px !important;margin:0 !important;font-weight:800;white-space:nowrap;display:inline-flex !important;justify-content:center;align-items:center}
  .mg-satir{display:flex;align-items:center;gap:12px;padding:12px 0;border-bottom:1px solid var(--line)}
  .mg-satir:last-child{border-bottom:0}
  .mg-satir .orta{flex:1;min-width:0}
  .mg-miktar{font-size:20px;font-weight:800;font-variant-numeric:tabular-nums}
  .mg-ikon{flex:0 0 44px;width:44px;height:44px;border-radius:12px;display:grid;place-items:center;background:var(--inkbg);color:var(--ink2)}
  .mg-ikon svg{width:24px;height:24px}
  .mg-kartdurum{background:var(--inkbg);border-radius:14px;padding:12px 14px;margin-bottom:12px;display:flex;gap:12px;align-items:center}
  .mg-kartdurum .orta{flex:1;min-width:0}
  .mg-not{font-size:12.5px;color:var(--faint);line-height:1.45;margin:10px 2px 0}
  .mg-sahip{color:var(--good);font-weight:800;font-size:14px;white-space:nowrap}
  .mg-not a{color:var(--ink2);font-weight:700}
  .ust .para-cip.mg-cip{display:inline-flex;align-items:center;gap:6px;padding:0 4px 0 10px}
  .mg-arti{width:24px;height:24px;border-radius:7px;background:linear-gradient(160deg,#F5D06A,#E0A82E);color:#1a1530;display:grid;place-items:center;flex:none}
  .mg-arti svg{width:15px;height:15px}
  .mg-cip .mg-nokta{position:absolute;top:-3px;right:-3px;width:10px;height:10px;border-radius:50%;background:var(--al);border:2px solid var(--bg)}
  .mg-serit{display:flex;align-items:center;gap:12px;width:100%;text-align:left;border-radius:16px;padding:12px 14px;margin:0 0 12px;cursor:pointer;color:inherit;font:inherit;
    background:radial-gradient(120% 140% at 100% 0%,rgba(242,201,76,.30),transparent 62%),linear-gradient(160deg,var(--panel2),var(--panel));border:1px solid rgba(242,201,76,.38)}
  .mg-serit .mg-ikon{background:rgba(242,201,76,.16);color:#F2C94C}
  .mg-serit .orta{flex:1;min-width:0} .mg-serit b{display:block;font-size:16px} .mg-serit .kucuk{display:block}
  .mg-serit .ok{color:#F2C94C;font-size:22px;font-weight:700}
  .km-band + .serit{margin-top:0}
  `;
  document.head.appendChild(stil);

  const M = window.MGZ = window.MGZ || { durum: null, rozet: {}, rozetZaman: 0 };
  const hata = (err) => toast(hataCevir((err && err.message) || String(err)), true);
  const tl = (n) => fmt(Math.round(Number(n) || 0)) + "\u00a0₺";
  const SVG = {
    yildiz: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.6l2.9 6.1 6.6.8-4.9 4.5 1.3 6.6L12 17.3l-5.9 3.3 1.3-6.6-4.9-4.5 6.6-.8z"/></svg>',
    tik: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.2 4.2L19 7"/></svg>',
    para: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v6c0 1.7 3.1 3 7 3s7-1.3 7-3V6"/><path d="M5 12v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/></svg>',
    kart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="3"/><path d="M3 10h18M7 15h4"/></svg>',
    reklam: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="13" rx="3"/><path d="M10 9l5 2.5-5 2.5z"/><path d="M4 21L20 3"/></svg>',
    canta: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 8h14l-1.2 11.2a2 2 0 0 1-2 1.8H8.2a2 2 0 0 1-2-1.8z"/><path d="M9 8V6.5a3 3 0 0 1 6 0V8"/></svg>',
    arti: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    hediye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="9" width="18" height="12" rx="2"/><path d="M3 13h18M12 9v12"/><path d="M12 9c-2-4-6-4-6-1.5S9 9 12 9zm0 0c2-4 6-4 6-1.5S15 9 12 9z"/></svg>'
  };

  /* ---------- Rozetler (sohbet, oyuncu kartı, profil) ---------- */
  function rozetHtml(kad) {
    const r = M.rozet[kad]; if (!r) return "";
    const l = r.split(",");
    return `<span class="mg-rz">${l.includes("destekci") ? `<span class="mg-yildiz" title="Destekçi">${SVG.yildiz}</span>` : ""}${l.includes("kart") ? `<span class="mg-kart" title="Siyaset Kartı">Kart</span>` : ""}</span>`;
  }
  M.rozetHtml = rozetHtml;
  async function rozetleriYukle(zorla) {
    if (!zorla && Date.now() - M.rozetZaman < 5 * 60 * 1000) return;
    M.rozetZaman = Date.now();
    try { M.rozet = (await API.rpc("magaza_rozetler")) || {}; M.rozetYuklendi = true; rozetleriUygula(); } catch (_) { /* eski sunucu */ }
  }
  // Ekranda zaten çizilmiş sohbet balonlarına rozet ekle (rozet listesi sonradan geldiyse)
  function rozetleriUygula() {
    document.querySelectorAll(".balon[data-kad]").forEach(b => {
      const kim = b.querySelector(".kim"); if (!kim || kim.querySelector(".mg-rz")) return;
      const rz = rozetHtml(b.dataset.kad); const ad = kim.querySelector("span");
      if (rz && ad) ad.insertAdjacentHTML("afterend", rz);
    });
  }
  if (typeof balonHtml === "function") {
    const eskiBalon = balonHtml;
    window.balonHtml = balonHtml = function (m, ozel) {
      let h = eskiBalon(m, ozel);
      if (!M.rozetYuklendi && !M._rozetIstek) { M._rozetIstek = true; rozetleriYukle(true).finally(() => { M._rozetIstek = false; }); }
      const rz = m && m.kad ? rozetHtml(m.kad) : "";
      if (rz) { const i = h.indexOf('<div class="kim">'); if (i >= 0) { const j = h.indexOf("</span>", i); if (j > 0) h = h.slice(0, j + 7) + rz + h.slice(j + 7); } }
      return h;
    };
  }
  if (typeof oyuncuKart === "function") {
    const eskiKart = oyuncuKart;
    window.oyuncuKart = oyuncuKart = async function (kad) {
      const r = await eskiKart.apply(this, arguments);
      try {
        await rozetleriYukle();
        const rz = rozetHtml(kad), h3 = document.querySelector("#modal .modal h3");
        if (rz && h3 && !h3.querySelector(".mg-rz")) h3.insertAdjacentHTML("beforeend", rz);
      } catch (_) {}
      return r;
    };
  }
  if (typeof iskelet === "function") {
    const eskiIskelet = iskelet;
    window.iskelet = iskelet = function (baslik, govde, opt) {
      if (baslik === "Profilim" && typeof govde === "string" && D.durum && D.durum.profil) {
        const p = D.durum.profil, rz = rozetHtml(p.kad);
        if (rz) govde = govde.replace(`<h3>${e(p.kad)}</h3>`, `<h3>${e(p.kad)}${rz}</h3>`);
        govde = `<button class="giris-satir" onclick="ekranAc(magazaEkrani)" style="margin-bottom:12px"><span class="yik">${SVG.kart}</span><span class="orta"><b>Mağaza</b><span class="kucuk">Siyaset Kartı, ₺ paketleri, Destekçi Rozeti</span></span><span class="ok">›</span></button>` + govde;
      }
      if (baslik === "Gündem" && typeof govde === "string") {
        // Haber şeridinin hemen altına (şerit yoksa en üste)
        const sr = gundemSeridi(), i = govde.indexOf('<div class="serit"'), j = i >= 0 ? govde.indexOf("</div></div>", i) : -1;
        govde = j > 0 ? govde.slice(0, j + 12) + sr + govde.slice(j + 12) : sr + govde;
      }
      const r = eskiIskelet.call(this, baslik, govde, opt);
      try { cipGuncelle(); } catch (_) {}
      return r;
    };
  }
  // Üst çubuktaki cüzdan: tutara dokununca cüzdan hareketleri (son 24 saat, kaynaklarıyla) açılır,
  // altın + işareti mağazayı açar (27.10.2026: eskiden ikisi de mağazayı açıyordu). Kart ödülü hazırsa kırmızı nokta.
  function cipGuncelle() {
    const c = document.querySelector(".ust .para-cip"); if (!c) return;
    if (!c.classList.contains("mg-cip")) {
      c.classList.add("mg-cip"); c.setAttribute("onclick", "ekranAc(typeof cuzdanEkrani==='function'?cuzdanEkrani:magazaEkrani)");
      c.setAttribute("aria-label", "Cüzdan: gelen ve giden paralar"); c.title = "Cüzdan";
      c.insertAdjacentHTML("beforeend", `<span class="mg-arti" role="button" aria-label="Mağaza: cüzdanına ₺ ekle" title="Mağaza" onclick="event.stopPropagation();ekranAc(magazaEkrani)">${SVG.arti}</span>`);
    }
    const nokta = !!(M.durum && M.durum.kart && M.durum.kart.odul_alinabilir);
    const n = c.querySelector(".mg-nokta");
    if (nokta && !n) c.insertAdjacentHTML("beforeend", `<span class="mg-nokta"></span>`); else if (!nokta && n) n.remove();
  }
  // Gündem'in en üstünde mağaza şeridi
  function gundemSeridi() {
    const d = M.durum;
    if (d && d.satis_acik === false) return "";
    const gunluk = d && d.kart ? d.kart.gunluk : 7500;
    if (d && d.kart && d.kart.aktif && d.kart.odul_alinabilir)
      return `<div class="mg-serit" id="mgSerit" role="button" onclick="ekranAc(magazaEkrani)"><span class="mg-ikon">${SVG.kart}</span><span class="orta"><b>Kart ödülün hazır</b><span class="kucuk">Bugünkü ${tl(gunluk)} seni bekliyor</span></span><button class="btn altin mg-fiyat" onclick="event.stopPropagation();MGZ.kartOdulAl()">${tl(gunluk)} al</button></div>`;
    const bas = d && (d.paketler || []).find(p => p.urun_id === "baslangic_paketi" && p.alinabilir);
    const alt = bas ? `Başlangıç Paketi: ${tl(bas.miktar)} ve ${bas.gun} günlük Siyaset Kartı`
      : d && d.kart && d.kart.aktif ? `Siyaset Kartın aktif · ${kalanGun(d.kart.bitis)}`
      : `Siyaset Kartı: her gün ${tl(gunluk)} · ₺ paketleri · Destekçi Rozeti`;
    return `<div class="mg-serit" id="mgSerit" role="button" onclick="ekranAc(magazaEkrani)"><span class="mg-ikon">${SVG.canta}</span><span class="orta"><b>Mağaza</b><span class="kucuk">${e(alt)}</span></span><span class="ok">›</span></div>`;
  }
  function seritTazele() {
    const s = document.querySelector("#mgSerit"); if (s) { const y = gundemSeridi(); if (y) s.outerHTML = y; else s.remove(); }
    try { cipGuncelle(); } catch (_) {}
  }
  M.seritTazele = seritTazele;

  /* ---------- Durum ---------- */
  async function durumYukle() {
    try { M.durum = await API.rpc("magaza_durum"); } catch (_) { M.durum = M.durum || null; }
    try { seritTazele(); } catch (_) {}
    return M.durum;
  }
  M.durumYukle = durumYukle;

  /* ---------- Reklamsız ödül ---------- */
  if (typeof REKLAM === "object" && REKLAM && typeof REKLAM.goster === "function") {
    const eskiGoster = REKLAM.goster;
    REKLAM.goster = async function () {
      const d = M.durum || await durumYukle();
      if (d && d.reklamsiz) return true;
      return eskiGoster.apply(this, arguments);
    };
  }

  /* ---------- Hayat ekranı: Kart ödülü, reklamsız etiketi, mağaza kısayolu ---------- */
  function hayatSus() {
    const d = M.durum; if (!d) return;
    const r = document.querySelector("#hReklam");
    if (r && d.reklamsiz && r.firstChild && r.firstChild.nodeType === 3) r.firstChild.textContent = "Ödülü al";
    const mg = document.querySelector("#hMagaza .kucuk"); if (mg) mg.textContent = "Kart ve ₺ paketleri";
    if (document.querySelector("#mgHayat")) return;
    const yer = r && r.closest(".satir"); if (!yer) return;
    let html = "";
    if (d.kart && d.kart.aktif) {
      html = `<div class="mg-kartdurum" id="mgHayat"><span class="mg-ikon">${SVG.kart}</span><div class="orta"><b>Siyaset Kartı</b><div class="kucuk">${kalanGun(d.kart.bitis)} · her gün ${tl(d.kart.gunluk)}</div></div>
        ${d.kart.odul_alinabilir ? `<button class="btn altin mg-fiyat" id="mgKartAl">${tl(d.kart.gunluk)} al</button>` : `<span class="mg-sahip">Bugün alındı</span>`}</div>`;
    } else if (d.satis_acik !== false) {
      html = `<button class="giris-satir" id="mgHayat" onclick="ekranAc(magazaEkrani)" style="margin:-2px 0 12px"><span class="yik">${SVG.kart}</span><span class="orta"><b>Siyaset Kartı</b><span class="kucuk">Her gün ${tl(d.kart ? d.kart.gunluk : 7500)}, reklamsız ödüller ve Kart rozeti</span></span><span class="ok">›</span></button>`;
    }
    if (!html) return;
    yer.insertAdjacentHTML("afterend", html);
    const b = document.querySelector("#mgKartAl"); if (b) b.onclick = kartOdulAl;
  }
  async function kartOdulAl() {
    const b = document.querySelector("#mgKartAl"); if (b) b.disabled = true;
    try {
      const r = await API.rpc("kart_odul_al"); M.durum = r;
      toast(`Siyaset Kartı ödülü: +${tl(r.sonuc.odul)}`);
      if (typeof rozetGuncelle === "function") rozetGuncelle();
      if (document.querySelector("#mgEkran")) magazaCiz(); else if (typeof hayatEkrani === "function" && document.querySelector("#hReklam")) hayatEkrani();
      seritTazele();
    } catch (err) { hata(err); if (b) b.disabled = false; }
  }
  M.kartOdulAl = kartOdulAl;
  if (typeof hayatCiz === "function") {
    const eskiHayat = hayatCiz;
    window.hayatCiz = hayatCiz = function (h) {
      const r = eskiHayat.apply(this, arguments);
      try { if (M.durum) hayatSus(); else durumYukle().then(hayatSus); } catch (_) {}
      return r;
    };
  }
  const kalanGun = (bitis) => {
    const ms = new Date(bitis).getTime() - (typeof simdi === "function" ? simdi() : Date.now());
    if (ms <= 0) return "süresi doldu";
    if (ms >= 86400000) return `${Math.ceil(ms / 86400000 - 0.01)} gün kaldı`;
    return `${Math.max(1, Math.ceil(ms / 3600000))} saat kaldı`;
  };

  /* ---------- Mağaza ekranı ---------- */
  let URUN = [];          // mağazadan gelen ürünler (fiyatlı)
  let MAGAZA_HATA = null; // satın almaya hazır değilse açıklama
  const yerel = () => typeof ODEME === "object" && ODEME && ODEME.eklenti();

  window.magazaEkrani = async function magazaEkrani() {
    yukleniyor("Mağaza");
    const d = await durumYukle();
    if (!d) { iskelet("Mağaza", `<div class="bos">Mağaza yüklenemedi. Bağlantını kontrol edip yeniden dene.</div>`, { geri: true }); return; }
    URUN = []; MAGAZA_HATA = null;
    if (d.satis_acik === false) MAGAZA_HATA = "Mağaza şu an kapalı. Kısa süre sonra yeniden açılacak.";
    else if (yerel()) {
      try { await ODEME.hazirla(); URUN = await ODEME.urunler(d.paketler.map(p => p.urun_id)); }
      catch (err) { MAGAZA_HATA = hataCevir((err && err.message) || String(err)); }
    }
    magazaCiz();
  };
  // eski giriş noktaları yeni ekrana gider
  window.magazaModal = magazaModal = function () { modalKapat(); ekranAc(window.magazaEkrani); };

  function fiyatDugme(p) {
    if (p.sahip) return `<span class="mg-sahip">Sende var</span>`;
    if (!p.alinabilir) return `<span class="mg-sahip">Alındı</span>`;
    const u = URUN.find(x => x.identifier === p.urun_id);
    if (u) return `<button class="btn altin mg-fiyat" data-urun="${e(p.urun_id)}">${e(u.priceString)}</button>`;
    return `<button class="btn ikinci mg-fiyat" disabled title="Satın alma telefondaki uygulamada">${e(p.fiyat || "—")}</button>`;
  }
  function magazaCiz() {
    const d = M.durum, P = d.paketler || [];
    const bul = (id) => P.find(p => p.urun_id === id);
    const bas = bul("baslangic_paketi"), kart = P.find(p => p.tur === "kart"), paralar = P.filter(p => p.tur === "para"), kalicilar = P.filter(p => p.tur === "kalici");
    const gunluk = d.kart ? d.kart.gunluk : 7500;
    const madde = (t) => `<li>${SVG.tik}<span>${t}</span></li>`;
    const durumNot = MAGAZA_HATA ? `<div class="km-uyari" style="margin-bottom:12px">${e(MAGAZA_HATA)}</div>`
      : !yerel() ? `<div class="mg-kartdurum"><span class="mg-ikon">${SVG.kart}</span><div class="orta"><b>Satın alma telefonda</b><div class="kucuk">Ürünleri App Store ya da Google Play'deki Seçim Online uygulamasından alabilirsin. Aldıkların bu hesapta, web'de de geçerlidir.</div></div></div>` : "";
    const kartDurum = d.kart && d.kart.aktif ? `<div class="mg-kartdurum"><span class="mg-ikon">${SVG.kart}</span><div class="orta"><b>Siyaset Kartın aktif</b><div class="kucuk">${kalanGun(d.kart.bitis)} · her gün ${tl(gunluk)} · reklamsız ödüller</div></div>
      ${d.kart.odul_alinabilir ? `<button class="btn altin mg-fiyat" id="mgKartAl">${tl(gunluk)} al</button>` : `<span class="mg-sahip">Bugün alındı</span>`}</div>` : "";
    const vitrinBas = bas && bas.alinabilir ? `<section class="mg-vitrin altin">
        <span class="mg-etiket">${e(bas.etiket || "Tek sefer")}</span><h2>${e(bas.ad)}</h2><p class="alt">Siyasete güçlü bir başlangıç. Hesap başına bir kez.</p>
        <ul class="mg-liste">${madde(`Cüzdanına <b>${tl(bas.miktar)}</b>`)}${madde(`<b>${bas.gun} günlük</b> Siyaset Kartı: her gün ${tl(gunluk)}`)}${madde("Kart süresince reklamsız ödüller ve Kart rozeti")}</ul>
        <div style="display:flex;justify-content:flex-end">${fiyatDugme(bas)}</div></section>` : "";
    const vitrinKart = kart ? `<section class="mg-vitrin">
        <span class="mg-etiket">${e(kart.etiket || "En avantajlı")}</span><h2>Siyaset Kartı</h2><p class="alt">${kart.gun} gün boyunca her gün kazandırır. Kartın varken alırsan süre üstüne eklenir.</p>
        <ul class="mg-liste">${madde(`Hemen <b>${tl(kart.miktar)}</b>`)}${madde(`Her gün <b>${tl(gunluk)}</b> Kart ödülü (${kart.gun} günde ${tl(kart.miktar + gunluk * kart.gun)})`)}${madde("Reklam izlemeden günlük reklam ödülleri")}${madde(`Adının yanında ${`<span class="mg-rz"><span class="mg-kart">Kart</span></span>`} rozeti`)}</ul>
        <div style="display:flex;justify-content:space-between;align-items:center;gap:10px"><span class="kucuk">${kart.gun} gün · otomatik yenilenmez</span>${fiyatDugme(kart)}</div></section>` : "";
    const paraListe = paralar.length ? `<div class="bolum-bas"><h2>Oyun parası</h2><span class="kucuk">Cüzdan: ${tl(d.para)}</span></div>
      <div class="kart">${paralar.map(p => `<div class="mg-satir"><span class="mg-ikon">${SVG.para}</span><div class="orta"><div class="mg-miktar">${tl(p.miktar)}</div><div class="kucuk">${e(p.ad)}${p.etiket ? ` · <span style="color:var(--good);font-weight:700">${e(p.etiket)}</span>` : ""}</div></div>${fiyatDugme(p)}</div>`).join("")}</div>` : "";
    const kaliciListe = kalicilar.length ? `<div class="bolum-bas"><h2>Kalıcı</h2><span class="kucuk">Bir kez al, hep senin</span></div>
      <div class="kart">${kalicilar.map(p => `<div class="mg-satir"><span class="mg-ikon" ${p.hak === "destekci" ? 'style="color:#F2C94C;background:rgba(242,201,76,.14)"' : ""}>${p.hak === "destekci" ? SVG.yildiz : SVG.reklam}</span><div class="orta"><b>${e(p.ad)}</b><div class="kucuk">${e(p.aciklama || "")}</div></div>${fiyatDugme(p)}</div>`).join("")}</div>` : "";
    const yonetici = D.durum && D.durum.profil && D.durum.profil.yonetici ? `<div class="kart" id="mgSatis"><h2>Satış özeti · son 30 gün</h2><div class="kucuk">Yükleniyor…</div></div>` : "";
    iskelet("Mağaza", `<div id="mgEkran"></div>${durumNot}${kartDurum}${vitrinBas}${vitrinKart}${paraListe}${kaliciListe}
      ${yerel() ? `<button class="btn ikinci" id="mgGeri">Satın alımları geri yükle</button>` : ""}
      <p class="mg-not">Ödeme Apple ya da Google hesabından alınır ve mağazanın onayından sonra birkaç saniye içinde hesabına işlenir. Oyun parası gerçek paraya çevrilemez, devredilemez. Oy, makam ve seçim sonucu satılmaz; satın alınan para da oyunun günlük bağış ve yayın sınırlarına tabidir. <a href="https://feniksklein.github.io/Se-im-Online/gizlilik.html" target="_blank" rel="noopener">Gizlilik</a></p>
      ${yonetici}`, { geri: true });
    document.querySelectorAll("[data-urun]").forEach(b => b.onclick = () => satinAl(b.dataset.urun, b));
    const ka = document.querySelector("#mgKartAl"); if (ka) ka.onclick = kartOdulAl;
    const gy = document.querySelector("#mgGeri"); if (gy) gy.onclick = geriYukle;
    if (yonetici) satisOzeti();
  }
  M.magazaCiz = magazaCiz;

  const iz = (d) => d ? JSON.stringify([d.para, d.kart && d.kart.bitis, d.haklar, (d.paketler || []).map(p => p.alinabilir)]) : "";
  async function satinAl(id, b) {
    const u = URUN.find(x => x.identifier === id); if (!u) return;
    const p = (M.durum.paketler || []).find(x => x.urun_id === id);
    b.disabled = true;
    const once = iz(M.durum);
    try { await ODEME.al(u); }
    catch (err) { b.disabled = false; if (!/cancel/i.test(String(err && (err.code || err.message)))) hata(err); return; }
    toast("Ödeme alındı, hesabına işleniyor…");
    for (let i = 0; i < 20; i++) {
      await new Promise(r => setTimeout(r, 2000));
      await durumYukle();
      if (iz(M.durum) !== once) {
        await rozetleriYukle(true);
        if (document.querySelector("#mgEkran")) magazaCiz();
        if (typeof rozetGuncelle === "function") rozetGuncelle();
        toast(p && p.tur === "para" ? `Cüzdanına ${tl(p.miktar)} eklendi. Teşekkürler!` : `${p ? p.ad : "Ürün"} hesabına eklendi. Teşekkürler!`);
        return;
      }
    }
    toast("Ödeme alındı; mağaza onayı biraz gecikebilir. Birkaç dakika içinde hesabında olacak.");
    if (document.querySelector("#mgEkran")) magazaCiz();
  }
  async function geriYukle() {
    const b = document.querySelector("#mgGeri"); if (b) b.disabled = true;
    try {
      await ODEME.hazirla(); await ODEME.eklenti().restorePurchases();
      toast("Satın alımların kontrol ediliyor…");
      await new Promise(r => setTimeout(r, 4000));
      await durumYukle(); await rozetleriYukle(true);
      if (document.querySelector("#mgEkran")) magazaCiz();
      toast("Satın alımların güncellendi.");
    } catch (err) { hata(err); if (b) b.disabled = false; }
  }
  async function satisOzeti() {
    const k = document.querySelector("#mgSatis"); if (!k) return;
    try {
      const s = await API.rpc("yk_satislar", { p_gun: 30 }), t = s.toplam;
      k.innerHTML = `<h2>Satış özeti · son 30 gün</h2>
        <div class="kv"><span class="k">Satış</span><span class="v">${fmt(t.adet)} adet · ${fmt(t.alici)} alıcı</span></div>
        <div class="kv"><span class="k">Brüt (mağaza fiyatı)</span><span class="v">${fmt(t.brut_try, 2)} ₺</span></div>
        <div class="kv"><span class="k">İade</span><span class="v">${fmt(t.iade)}</span></div>
        ${(s.urunler || []).map(u => `<div class="kv"><span class="k">${e(u.ad)}</span><span class="v">${fmt(u.adet)} · ${fmt(u.brut_try, 2)} ₺</span></div>`).join("")}
        <div class="kucuk" style="margin-top:6px">Brüt tutardan Apple/Google payı (%15–30) ve KDV düşülür. Ayrıntı: Kontrol Merkezi › Veri › satin_almalar.</div>`;
    } catch (err) { k.innerHTML = `<h2>Satış özeti</h2><div class="kucuk">${e(hataCevir(err.message))}</div>`; }
  }

  /* ---------- Açılış ---------- */
  const hazir = () => typeof API !== "undefined" && API && typeof D !== "undefined" && D && D.durum;
  setTimeout(() => { if (hazir()) { rozetleriYukle(); durumYukle(); } }, 2500);
  setInterval(() => { if (hazir() && !document.hidden) rozetleriYukle(); }, 5 * 60 * 1000);
})();
