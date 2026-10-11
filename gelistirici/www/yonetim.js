/* =====================================================================
   YÖNETİM — oyuncunun bütün makamları tek alt menüde (ilk oyundaki gibi).
   "Bakanlığım" ve "Belediyem" sekmelerinin yerine geçer. Kimde hangi makam
   varsa (belediye başkanı, CB, CB yardımcısı, bakan, TBMM görevleri, vekil,
   genel başkan / GB yardımcısı) işlemlerini buradan yapar.
   Belediye başkanlığı en üstte durur; makama gelen CİMER başvuruları da
   ekranın başında gösterilir. Sunucu değişikliği yok, mevcut RPC'ler kullanılır.
   ===================================================================== */
"use strict";
IKON.yonetim = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M3 12.5h18M10.5 12.5v2h3v-2"/></svg>';
const YONETIM_SIRA = ["bel", "cb", "cb_yardimcisi", "bakan", "tbmm", "bskv", "grup_bskv", "mv"];
(function(){ const st = document.createElement("style"); st.textContent = `
.ynt-makamlar{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}
.ynt-makamlar span{padding:6px 10px;border-radius:16px;background:var(--panel2);font-weight:700;font-size:13.5px}
.ynt-bolum{border-left:4px solid var(--gold2,#c9a227)}
.ynt-bolum .btn{margin-top:8px}
.ynt-cimer{display:flex;align-items:center;gap:12px;cursor:pointer}
.ynt-cimer .cimer-logo{width:42px;height:42px;font-size:11px;border-radius:11px}
`; document.head.appendChild(st); })();

function yonetimProfil(){ return (D.durum && D.durum.profil) || null; }
function yonetimMakamlari(){
  const p = yonetimProfil(); if (!p) return [];
  return (p.makamlar || []).slice().sort((a, b) => {
    const ia = YONETIM_SIRA.indexOf(a.tur), ib = YONETIM_SIRA.indexOf(b.tur);
    return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
  });
}
function yonetimParti(){ const p = yonetimProfil(); return !!(p && p.parti && (p.gb || p.gb_vekaleten || p.gby)); }
// Alt menüde "Yönetim" sekmesi: en az bir makamı ya da parti yönetim görevi olana açılır
function yonetimVarMi(){ return yonetimMakamlari().length > 0 || yonetimParti(); }
// CİMER başvurusu alabilen makamlar: belediye başkanı, bakan, Cumhurbaşkanı (boş bakanlıklara CB bakar)
function cimerMakamVar(){ return yonetimMakamlari().some(x => x.tur === "bel" || x.tur === "bakan" || x.tur === "cb"); }

async function yonetimEkrani(){
  yukleniyor("Yönetim");
  try { await durumYenile(); }
  catch (err) { iskelet("Yönetim", `<div class="bos">${e(hataCevir(err.message))}</div>`); return; }
  const p = yonetimProfil() || {};
  const mk = yonetimMakamlari();
  if (!yonetimVarMi()) {
    iskelet("Yönetim", `<div class="kart"><h2>Şu an bir görevin yok</h2>
      <p class="alt">Seçimle ya da atamayla bir makama geldiğinde (belediye başkanı, milletvekili, bakan, Cumhurbaşkanı, parti yöneticisi) o makamın bütün işlemleri burada açılır.</p>
      <button class="btn altin" onclick="sekmeAc('gundem')">Seçim takvimine bak</button></div>`);
    return;
  }
  const iste = async (ad, arg, yedek) => { try { const r = await API.rpc(ad, arg); return r == null ? yedek : r; } catch (_) { return yedek; } };
  const bel = mk.find(x => x.tur === "bel");
  const bakan = mk.some(x => x.tur === "bakan");
  const cb = mk.some(x => x.tur === "cb");
  const cby = mk.find(x => x.tur === "cb_yardimcisi");
  const meclisMk = mk.filter(x => ["mv", "tbmm", "bskv", "grup_bskv"].includes(x.tur));
  const [cimer, sehir, paneller] = await Promise.all([
    cimerMakamVar() ? iste("cimer", undefined, null) : null,
    bel ? iste("belediye_sehir_paneli", undefined, null) : null,
    bakan ? iste("bakanlik_panellerim", undefined, []) : []
  ]);
  D._bakanPanelleri = Array.isArray(paneller) ? paneller : [];
  const ihaleVar = typeof ihaleEkrani === "function";

  // Makam listesi
  const etiketler = mk.map(makamYaz);
  if (p.gb) etiketler.push("Genel Başkan");
  else if (p.gb_vekaleten) etiketler.push("Genel Başkan (vekâleten)");
  if (p.gby) etiketler.push("Genel Başkan Yardımcısı");
  let h = `<div class="kart"><h2>Makamların</h2><p class="alt">Görev yaptığın her makamın işlemleri aşağıda.</p>
    <div class="ynt-makamlar">${etiketler.map(x => `<span>${e(x)}</span>`).join("")}</div></div>`;

  // CİMER: makama gelen başvurular
  if (cimerMakamVar()) {
    const gelen = (cimer && cimer.gelen) || [];
    const bekleyen = gelen.filter(b => b.yanitlayabilirim && b.durum !== "sonuclandi");
    h += `<div class="kart"><div class="ynt-cimer" onclick="CIMER.sekme='gelen';ekranAc(cimerEkrani)">
        <span class="cimer-logo">CİMER</span>
        <span style="flex:1;min-width:0"><b>${bekleyen.length ? `Makamına ${bekleyen.length} başvuru geldi` : "Makamına gelen başvurular"}</b>
        <span class="kucuk" style="display:block">${bekleyen.length ? e(bekleyen[0].konu) + (bekleyen.length > 1 ? ` ve ${bekleyen.length - 1} başvuru daha` : "") : "Şu an bekleyen başvuru yok. Gelenler 72 saat içinde yanıtlanmalı."}</span></span>
        ${bekleyen.length ? `<span class="rozet kirmizi">${bekleyen.length}</span>` : `<span class="ok">›</span>`}</div></div>`;
  }

  // 1) Belediye başkanlığı — en üstte
  if (bel) {
    h += `<div class="kart ynt-bolum"><div class="baslik" style="display:flex;justify-content:space-between;gap:8px;align-items:center"><h2 style="margin:0">🏙️ ${e(bel.il_ad || "")} Belediyesi</h2><span class="rozet altin">Belediye başkanı</span></div>
      ${sehir ? `<div class="gosterge" style="margin-top:10px"><div><div class="ad">Belediye kasası</div><div class="deger" style="font-size:18px">${kasaYaz(sehir.kasa)}</div></div><div><div class="ad">Memnuniyet</div><div class="deger">${fmt(sehir.memnuniyet, 1)}</div></div><div><div class="ad">Gelişmişlik</div><div class="deger">${fmt(sehir.gelisim, 1)}</div></div></div>` : ""}
      <button class="btn altin" onclick="D._belediyeSehirMod='ozet';ekranAc(belediyeSehirYonetimEkrani)">Şehir yönetimi: bütçe, binalar, ekonomi</button>
      <button class="btn ikinci" onclick="ekranAc(belediyeEkrani)">Vergiler, sosyal yardımlar ve hizmetler</button>
      ${ihaleVar ? `<button class="btn ikinci" onclick="PZ.ihaleSekme='masa';ekranAc(ihaleEkrani)">Kamu ihalesi aç / yönet</button>` : ""}
      ${typeof belediyeHizmetIhaleEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(belediyeHizmetIhaleEkrani)">Belediye hizmet ihaleleri</button>` : ""}
      <button class="btn ikinci" onclick="CIMER.sekme='gelen';ekranAc(cimerEkrani)">Belediyeye gelen CİMER başvuruları</button></div>`;
  }

  // 2) Cumhurbaşkanlığı
  if (cb || cby) {
    h += `<div class="kart ynt-bolum"><div class="baslik" style="display:flex;justify-content:space-between;gap:8px;align-items:center"><h2 style="margin:0">Cumhurbaşkanlığı</h2><span class="rozet altin">${cb ? "Cumhurbaşkanı" : e(makamYaz(cby))}</span></div>
      <p class="alt" style="margin-top:6px">${cb ? "Kabineyi kur, bakanları ata, politikaları ve bütçeyi belirle, kanunları onayla ya da iade et." : "Hükümetin çalışmalarını izle ve Cumhurbaşkanına destek ol."}</p>
      <button class="btn altin" onclick="D.devletSekme='hukumet';sekmeAc('devlet')">Hükümet ve kabine</button>
      ${cb ? `<button class="btn ikinci" onclick="sekmeAc('meclis')">Meclis ve onay bekleyen kanunlar</button>` : ""}
      ${cb && ihaleVar ? `<button class="btn ikinci" onclick="PZ.ihaleSekme='masa';ekranAc(ihaleEkrani)">Kamu ihaleleri (bakanı olmayan bakanlıklar)</button>` : ""}</div>`;
  }

  // 3) Bakanlık — paneller doğrudan burada
  if (bakan) {
    h += `<div class="kart ynt-bolum"><h2>Bakanlık yönetim masası</h2><p class="alt">Bu kararlar yalnızca görevli olduğun bakanlıklara aittir. İcraat bedeli bakanlık kasasından karşılanır.</p>
      ${ihaleVar ? `<button class="btn ikinci" onclick="PZ.ihaleSekme='masa';ekranAc(ihaleEkrani)">Kamu ihalesi aç / yönet</button>` : ""}
      ${typeof bakanSoruEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(bakanSoruEkrani)">Soru önergeleri</button>` : ""}</div>`;
    h += D._bakanPanelleri.length && typeof bakanPanelHtml === "function"
      ? D._bakanPanelleri.map(pn => bakanPanelHtml(pn, false)).join("")
      : `<div class="kart"><p class="alt">Bakanlık yetkin henüz aktif değil. Teklifi Bildirimler bölümünden kabul etmelisin.</p></div>`;
  }

  // 4) Meclis görevleri
  if (meclisMk.length) {
    h += `<div class="kart ynt-bolum"><div class="baslik" style="display:flex;justify-content:space-between;gap:8px;align-items:center"><h2 style="margin:0">TBMM</h2><span class="rozet">${meclisMk.map(x => e(makamYaz(x))).join(" · ")}</span></div>
      <p class="alt" style="margin-top:6px">Kanun teklifi ver, oylamalara katıl, Meclis seçimlerini takip et.</p>
      <button class="btn altin" onclick="sekmeAc('meclis')">Meclis'e git</button>
      ${typeof kanunTeklifEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(()=>kanunTeklifEkrani())">Kanun teklifi ver</button>` : ""}
      ${typeof bakanSoruEkrani === "function" && !bakan ? `<button class="btn ikinci" onclick="ekranAc(bakanSoruEkrani)">Soru önergeleri</button>` : ""}</div>`;
  }

  // 5) Parti yönetimi
  if (yonetimParti()) {
    h += `<div class="kart ynt-bolum"><div class="baslik" style="display:flex;justify-content:space-between;gap:8px;align-items:center"><h2 style="margin:0">${e(p.parti.ad || "Parti")}</h2><span class="rozet altin">${p.gb ? "Genel Başkan" : p.gb_vekaleten ? "GB vekili" : "GB Yardımcısı"}</span></div>
      <p class="alt" style="margin-top:6px">Parti teşkilatı, adaylar, ittifaklar ve parti kasası.</p>
      <button class="btn altin" onclick="ekranAc(()=>partiDetay(${+p.parti.id}))">Parti yönetimine git</button></div>`;
  }

  iskelet("Yönetim", h);
  if (bakan && typeof politikaBagla === "function") politikaBagla();
}

// Eski "Bakanlığım" ve "Belediyem" bağlantıları (bildirimler, Gündem kartları) Yönetim'e yönlenir
if (typeof EKRAN === "object" && EKRAN) {
  EKRAN.yonetim = () => yonetimEkrani();
  EKRAN.bakanlik = () => { D.sekme = "yonetim"; return yonetimEkrani(); };
  EKRAN.belediye = () => { D.sekme = "yonetim"; return yonetimEkrani(); };
}
window.yonetimEkrani = yonetimEkrani;
window.yonetimVarMi = yonetimVarMi;
window.cimerMakamVar = cimerMakamVar;
