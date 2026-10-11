/* =====================================================================
   Reklam ve anket ajansları. Arka uç: 86_reklam_anket_ajansi.sql
   Partiler ve adaylar oyuncuların kurduğu ajanslardan reklam ve kamuoyu araştırması satın alır.
   Reklam hedef ildeki oyuncuların Gündem'inde "Sponsorlu" kart olarak çıkar; anketi gerçek oyuncular cevaplar.
   ===================================================================== */
"use strict";
const AJ = { il: null, liste: null, yonetim: null };
const ajTL = (x) => tlYaz(Math.round(+x || 0));
const AJ_FIYAT = { 1: "Ucuz", 2: "Orta", 3: "Premium" }, AJ_KALITE = { 0: "Asgari", 1: "Standart", 2: "İyi", 3: "Üst düzey" };
const AJ_IKON = '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11v2a1 1 0 0 0 1 1h3l6 5V5L7 10H4a1 1 0 0 0-1 1z"/><path d="M17 8a5 5 0 0 1 0 8M20 5a9 9 0 0 1 0 14"/></svg>';
(function(){ const st = document.createElement("style"); st.textContent = `
.aj-sponsor{border:1.5px solid var(--parti,var(--ink2));position:relative}
.aj-sponsor .etiket{font-size:11px;font-weight:700;color:var(--mut);letter-spacing:.2px}
.aj-sponsor .metin{font-size:16px;font-weight:700;margin-top:6px;line-height:1.4;overflow-wrap:anywhere}
.aj-anket .secenek{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
.aj-anket .secenek button{padding:9px 12px;border-radius:18px;background:var(--panel2);font-weight:700;font-size:14px;color:var(--txt);border:1.5px solid transparent}
.aj-anket .secenek button i{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:6px}
.aj-cubuk{display:flex;align-items:center;gap:8px;margin-top:7px;font-size:13.5px}
.aj-cubuk .ad{width:64px;flex:none;font-weight:700;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.aj-cubuk .bar{flex:1;height:10px;border-radius:5px;background:var(--bg);overflow:hidden}
.aj-cubuk .bar i{display:block;height:100%}
.aj-cubuk .oran{width:48px;text-align:right;flex:none}
.aj-yildiz{display:flex;gap:4px;margin-top:8px}.aj-yildiz button{font-size:22px;color:var(--warn);padding:2px 4px}
.aj-onizle{margin-top:8px;padding:12px;border-radius:12px;background:var(--bg);border:1.5px dashed var(--line)}
`; document.head.appendChild(st); })();
function ajHata(baslik, err){ iskelet(baslik, `<div class="kart">${e(hataCevir(err.message))}</div>`, { geri: true }); }
function ajIlSecim(secili, fn){
  return `<select onchange="${fn}(this.value===''?null:+this.value)"><option value="" ${secili == null ? "selected" : ""}>Tüm Türkiye</option>${[...VERI.iller].sort((a, b) => a.ad.localeCompare(b.ad, "tr")).map(i => `<option value="${i.id}" ${i.id === secili ? "selected" : ""}>${e(i.ad)}</option>`).join("")}</select>`;
}
function ajSonucHtml(s){
  if (!s) return "";
  const kararsiz = +s.kararsiz_yuzde || 0;
  return `<div style="margin-top:8px">${(s.partiler || []).map(p => `<div class="aj-cubuk"><span class="ad">${e(p.kisa)}</span><span class="bar"><i style="width:${Math.min(100, +p.yuzde || 0)}%;background:${e(p.renk || "var(--ink2)")}"></i></span><span class="oran">%${fmt(p.yuzde, 1)}</span></div>`).join("")}
    <p class="pz-not">${fmt(s.n)} katılımcı · kararsız %${fmt(kararsiz, 1)}${s.hata != null ? ` · hata payı ±${fmt(s.hata, 1)} puan` : ""}. Oranlar kararını verenler arasındadır.</p></div>`;
}

/* ---------------- Ajanslar ve siparişler ---------------- */
async function ajansMerkezEkrani(){
  yukleniyor("Reklam ve anket");
  try {
    if (AJ.il === null && D.durum && D.durum.profil && AJ._ilKuruldu !== true) { AJ.il = D.durum.profil.il_id; AJ._ilKuruldu = true; }
    const v = await API.rpc("ajans_liste", { p_il: AJ.il });
    AJ.liste = v;
    iskelet("Reklam ve anket", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${AJ_IKON}</span><div><h2>Kampanyanı gerçek oyunculara ulaştır</h2>
        <p class="alt">Reklam, seçtiğin ildeki oyuncuların Gündem ekranında "Sponsorlu" kart olarak çıkar. Anket ise o ildeki oyunculara "Bugün seçim olsa hangi partiye oy verirdin?" diye sorar; sonuç yalnız sana gelir.</p></div></div>
        <p class="pz-not">Bu ajansları oyuncular kurar ve işletir. Parti adına genel başkan parti kasasından, adaylar kendi cebinden öder. Oy günü ve öncesindeki 24 saatte anket sonucu yayımlanamaz.</p></div>
      <div class="alan"><label>Hedef: ${e(v.il)} · reklam alanı ${fmt(v.reklam_dolu)}/${fmt(v.reklam_sinir)} dolu</label>${ajIlSecim(v.il_id, "ajansIlSec")}</div>
      ${(v.ajanslar || []).map(a => `<div class="kart"><div style="display:flex;justify-content:space-between;gap:8px;align-items:flex-start"><div style="min-width:0"><b>${e(a.ad)}</b>
          <div class="kucuk">${e(a.sahip)} · ${AJ_FIYAT[a.fiyat]} fiyat · kalite ${AJ_KALITE[a.kalite].toLocaleLowerCase("tr")}${a.puan ? ` · ${fmt(a.puan, 1)}/5 puan` : ""} · ${fmt(a.is_sayisi)} iş</div></div>
          <span class="rozet ${a.dolu >= a.kapasite ? "kirmizi" : ""}">${fmt(a.dolu)}/${fmt(a.kapasite)} iş</span></div>
        <div class="pz-grid"><span><small>Reklam</small><b>${ajTL(a.reklam_ucret)}</b><small>${fmt(a.reklam_saat)} saat${a.kalite >= 2 ? " + bildirim" : ""}</small></span><span><small>Anket</small><b>${ajTL(a.anket_ucret)}</b><small>24 saat</small></span><span><small>Katılım ödülü</small><b>${ajTL(a.anket_odul)}</b><small>kişi başı</small></span></div>
        ${a.benim ? `<p class="pz-not">Bu senin ajansın.</p>` : `<div class="vit-dugme"><button class="btn yarim" ${a.dolu >= a.kapasite ? "disabled" : ""} onclick="ajansSiparisModal(${a.id},'reklam')">Reklam ver</button><button class="btn altin yarim" ${a.dolu >= a.kapasite ? "disabled" : ""} onclick="ajansSiparisModal(${a.id},'anket')">Anket yaptır</button></div>`}</div>`).join("")
        || '<div class="kart"><p class="alt">Henüz ajans yok. İlk reklam ve anket ajansını sen kurabilirsin.</p></div>'}
      <div class="kart"><h2>Siparişlerim</h2>${(v.islerim || []).map(ajansIsHtml).join("") || '<p class="alt">Henüz siparişin yok.</p>'}</div>
      <div class="kart"><h2>Ajans işlet</h2>${v.ajansim ? `<p class="alt">Ajansının fiyatını, kalitesini ve gelen işleri yönet.</p><button class="btn altin" onclick="ekranAc(()=>ajansYonetimEkrani(${v.ajansim}))">Ajansımı yönet</button>`
        : `<p class="alt">Partiler ve adaylar kampanya döneminde reklam ve anket satın alır. Kalite arttıkça reklam uzun sürer ve bildirim gider, anket katılımcısına daha çok ödül verilir; ama gider de artar.</p>
        <div class="alan"><label>Ajans adı</label><input id="ajAd" maxlength="50"></div>
        <div class="alan"><label>Sermaye (₺) · en az 150.000</label><input id="ajSermaye" type="number" min="150000" step="10000" value="300000"></div>
        <button class="btn" onclick="ajansKur()">Ajansı kur</button>`}</div>`, { geri: true });
  } catch (err) { ajHata("Reklam ve anket", err); }
}
function ajansIlSec(il){ AJ.il = il; ajansMerkezEkrani(); }
function ajansIsHtml(j){
  const durum = j.durum === "yayinda" ? `<span class="rozet altin">Yayında · ${tarihSaat(j.bit)}'e kadar</span>` : `<span class="rozet">Bitti</span>`;
  let ic = "";
  if (j.tur === "reklam") ic = `<div class="aj-onizle"><span class="kucuk">Sponsorlu</span><div style="font-weight:700;margin-top:4px">${e(j.metin)}</div></div><p class="pz-not">${fmt(j.gosterim)} oyuncu gördü.</p>`;
  else ic = j.sonuc ? ajSonucHtml(j.sonuc) : `<p class="pz-not">${fmt(j.katilim)} oyuncu cevapladı. Sonuç süre bitince gelir.</p>`;
  const yay = j.tur === "anket" && j.sonuc && !j.yayimlandi && (j.benim || j.kaynak === "parti") ? `<button class="btn ikinci" onclick="ajansYayimla(${j.id})">Sonucu yayımla</button>` : j.yayimlandi ? `<p class="pz-not">Yayımlandı: ${tarihSaat(j.yayimlandi)}</p>` : "";
  const puan = j.benim && j.durum === "bitti" && !j.puan ? `<div class="aj-yildiz" aria-label="Ajansı puanla">${[1, 2, 3, 4, 5].map(n => `<button onclick="ajansPuanla(${j.id},${n})" aria-label="${n} puan">★</button>`).join("")}</div>` : j.puan ? `<p class="pz-not">Puanın: ${j.puan}/5</p>` : "";
  return `<div class="pz-satir" style="display:block"><div style="display:flex;justify-content:space-between;gap:8px"><b>${j.tur === "reklam" ? "Reklam" : "Anket"} · ${e(j.il)}</b>${durum}</div>
    <div class="kucuk">${e(j.ajans)} · ${ajTL(j.ucret)} · ${j.kaynak === "parti" ? e(j.parti || "parti") + " kasasından" : "kendi cebinden"}</div>${ic}${yay}${puan}</div>`;
}
function ajansSiparisModal(sirket, tur){
  const v = AJ.liste, a = (v.ajanslar || []).find(x => x.id === sirket); if (!a) return;
  const ucret = tur === "reklam" ? a.reklam_ucret : a.anket_ucret;
  const parti = v.parti;
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${tur === "reklam" ? "Reklam ver" : "Anket yaptır"} · ${e(v.il)}</h3>
    <p class="alt" style="margin-top:6px">${e(a.ad)} · ${ajTL(ucret)}. ${tur === "reklam" ? `${fmt(a.reklam_saat)} saat boyunca ${e(v.il)}'deki oyuncuların Gündem'inde görünür${a.kalite >= 2 ? " ve başlarken bildirim gider" : ""}.` : `24 saat boyunca ${e(v.il)}'deki oyunculara sorulur; her katılımcıya ${ajTL(a.anket_odul)} ödül verilir. Sonuç yalnız sana gelir, istersen yayımlarsın.`}</p>
    <div class="alan"><label>Ödeme</label><select id="ajKaynak">${parti ? `<option value="parti">${e(parti.kisa)} parti kasası (${ajTL(parti.kasa)})</option>` : ""}<option value="kisi">Kendi cebim (${ajTL(v.cuzdan)})</option></select></div>
    ${tur === "reklam" ? `<div class="alan"><label>Reklam metni (10-200 karakter)</label><textarea id="ajMetin" maxlength="200" rows="3" placeholder="Örn. İzmir için temiz yönetim! Pazar günü mitingimize bekliyoruz."></textarea></div>
      <div class="aj-onizle"><span class="kucuk">Sponsorlu · önizleme</span><div id="ajOnizle" style="font-weight:700;margin-top:4px;overflow-wrap:anywhere"></div></div>` : ""}
    <button class="btn" id="ajSiparisBtn">Siparişi ver (${ajTL(ucret)})</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
  if (tur === "reklam") { const o = () => { $("#ajOnizle", m).textContent = $("#ajMetin", m).value || "Metnin burada görünecek"; }; $("#ajMetin", m).oninput = o; o(); }
  $("#ajSiparisBtn", m).onclick = async () => {
    const metin = tur === "reklam" ? $("#ajMetin", m).value.trim() : null;
    if (tur === "reklam" && (metin.length < 10 || metin.length > 200)) { toast("Reklam metni 10-200 karakter olmalı.", true); return; }
    $("#ajSiparisBtn", m).disabled = true;
    try { await API.rpc("ajans_siparis", { p_sirket: sirket, p_tur: tur, p_il: v.il_id, p_kaynak: $("#ajKaynak", m).value, p_metin: metin }); modalKapat(); toast(tur === "reklam" ? "Reklamın yayında." : "Anket başladı; sonuç 24 saat sonra."); ajansMerkezEkrani(); }
    catch (err) { $("#ajSiparisBtn", m).disabled = false; toast(hataCevir(err.message), true); }
  };
}
async function ajansYayimla(id){
  if (!await onayla("Anket sonucunu yayımla", "Sonuç Gündem akışında herkese duyurulur. Ajansın adı ve hata payı da yazılır.", "Yayımla")) return;
  try { await API.rpc("ajans_anket_yayimla", { p_is: id }); toast("Anket sonucu yayımlandı."); ajansMerkezEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ajansPuanla(id, puan){
  try { await API.rpc("ajans_puanla", { p_is: id, p_puan: puan }); toast("Teşekkürler, puanın ajansın markasına işlendi."); ajansMerkezEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ajansKur(){
  const ad = ($("#ajAd").value || "").trim(), ser = Math.round(+$("#ajSermaye").value || 0);
  if (ad.length < 3) { toast("Ajans adı en az 3 karakter olmalı.", true); return; }
  try { const r = await API.rpc("ajans_kur", { p_ad: ad, p_sermaye: ser }); toast("Ajansın kuruldu."); ekranAc(() => ajansYonetimEkrani(r.id)); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Ajans yönetimi ---------------- */
async function ajansYonetimEkrani(id){
  yukleniyor("Ajansım");
  try {
    const y = await API.rpc("ajans_yonetim", { p_sirket: id });
    AJ.yonetim = y;
    const tahmin = +y.hafta_gelir - +y.hafta_odul - +y.haftalik_gider;
    iskelet(e(y.ad), `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${AJ_IKON}</span><div style="min-width:0"><h2>${e(y.ad)}</h2><p class="alt">Reklam ve anket ajansı${y.puan ? ` · ${fmt(y.puan, 1)}/5 puan` : ""}</p></div></div>
        ${y.aktif ? "" : '<p class="alt"><span class="rozet kirmizi">İflas etti</span></p>'}
        <div class="pz-grid"><span><small>Kasa</small><b>${ajTL(y.kasa)}</b></span><span><small>Marka</small><b>${fmt(y.marka)}/100</b></span><span><small>İşler</small><b>${fmt(y.dolu)}/${fmt(y.kapasite)}</b></span></div></div>
      <div class="kart"><h2>Bu hafta</h2>
        <div class="kv"><span>Sipariş geliri</span><b>${ajTL(y.hafta_gelir)}</b></div>
        <div class="kv"><span>Ödenen katılım ödülleri</span><b>${ajTL(y.hafta_odul)}</b></div>
        <div class="kv"><span>Haftalık gider (sabit, personel, kalite)</span><b>${ajTL(y.haftalik_gider)}</b></div>
        <div class="kv"><span>Şimdilik net (vergi öncesi)</span><b style="color:${tahmin >= 0 ? "var(--good)" : "var(--al2)"}">${ajTL(tahmin)}</b></div>
        <p class="pz-not">Hesap ${tarihSaat(y.sonraki)} tarihinde kapanır; kâr ortaklara dağıtılır, %20'si kurumlar vergisi.</p></div>
      ${y.yonetici && y.aktif ? `<div class="kart"><h2>Kararların</h2>
        <div class="alan"><label>Fiyat</label><div class="pz-secim" id="ajF">${[1, 2, 3].map(f => `<button data-v="${f}" class="${f === y.fiyat ? "aktif" : ""}" onclick="ajansSec('fiyat',${f})">${AJ_FIYAT[f]}</button>`).join("")}</div></div>
        <div class="alan"><label>Kalite</label><div class="pz-secim" id="ajK" style="--n:4">${[0, 1, 2, 3].map(k => `<button data-v="${k}" class="${k === y.kalite ? "aktif" : ""}" onclick="ajansSec('kalite',${k})">${AJ_KALITE[k]}</button>`).join("")}</div></div>
        <p class="pz-not">Kalite: reklam ${12}+8×kalite saat sürer (şu an ${fmt(y.reklam_saat)}), kalite 2 ve üstünde reklam başlarken bildirim gider; anket katılımcısına ${ajTL(y.anket_odul)} ödül. Kapasite = 1 + kalite + her 300.000 ₺ sermaye. Kalite gideri haftada sermayenin %1,2'si × kalite.</p>
        <button class="btn" id="ajKaydet" onclick="ajansKaydet()" disabled>Mevcut ayar</button></div>` : ""}
      <div class="kart"><h2>Fiyat listen</h2><div class="pz-kaydir"><table class="pz-tablo"><tr><th>Hedef</th><th>Reklam</th><th>Anket</th></tr>
        <tr><td>Küçük il</td><td>${ajTL(y.fiyatlar.kucuk.reklam)}</td><td>${ajTL(y.fiyatlar.kucuk.anket)}</td></tr>
        <tr><td>Büyük il</td><td>${ajTL(y.fiyatlar.buyuk.reklam)}</td><td>${ajTL(y.fiyatlar.buyuk.anket)}</td></tr>
        <tr><td>Tüm Türkiye</td><td>${ajTL(y.fiyatlar.turkiye.reklam)}</td><td>${ajTL(y.fiyatlar.turkiye.anket)}</td></tr></table></div></div>
      <div class="kart"><h2>Gelen işler</h2>${(y.isler || []).map(j => `<div class="pz-satir"><span class="sol"><b>${j.tur === "reklam" ? "Reklam" : "Anket"} · ${e(j.il)}</b><span class="kucuk" style="display:block">${e(j.parti || j.veren)} · ${ajTL(j.ucret)} · ${j.tur === "reklam" ? fmt(j.gosterim) + " gösterim" : fmt(j.katilim) + " katılımcı"}</span></span><span class="sag">${j.durum === "yayinda" ? '<span class="rozet altin">Yayında</span>' : j.puan ? `<span class="rozet">${j.puan}/5</span>` : '<span class="rozet">Bitti</span>'}</span></div>`).join("") || '<p class="alt">Henüz iş gelmedi. Fiyatın ve markan müşteri getirir.</p>'}</div>`, { geri: true });
    AJ.secim = { fiyat: y.fiyat, kalite: y.kalite };
  } catch (err) { ajHata("Ajansım", err); }
}
function ajansSec(alan, v){
  AJ.secim[alan] = v; const y = AJ.yonetim;
  document.querySelectorAll("#ajF button").forEach(b => b.classList.toggle("aktif", +b.dataset.v === AJ.secim.fiyat));
  document.querySelectorAll("#ajK button").forEach(b => b.classList.toggle("aktif", +b.dataset.v === AJ.secim.kalite));
  const deg = AJ.secim.fiyat !== y.fiyat || AJ.secim.kalite !== y.kalite, b = $("#ajKaydet");
  b.disabled = !deg; b.textContent = deg ? "Kararı uygula" : "Mevcut ayar";
}
async function ajansKaydet(){
  try { await API.rpc("ajans_ayarla", { p_sirket: AJ.yonetim.id, p_fiyat: AJ.secim.fiyat, p_kalite: AJ.secim.kalite }); toast("Ajans ayarları güncellendi."); ajansYonetimEkrani(AJ.yonetim.id); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Gündem: sponsorlu reklam ve anket kartı ---------------- */
function ajansGundemHtml(g){
  if (!g) return "";
  let h = "";
  if (g.reklam) h += `<div class="kart aj-sponsor aj-ek" style="--parti:${e(g.reklam.renk || "var(--ink2)")}"><div class="etiket">Sponsorlu · ${e(g.reklam.kim)}</div><div class="metin">${e(g.reklam.metin)}</div><div class="kucuk" style="margin-top:6px">${e(g.reklam.ajans)} aracılığıyla</div></div>`;
  if (g.anket) h += `<div class="kart aj-anket aj-ek" id="ajAnket"><div class="etiket kucuk">Kamuoyu araştırması · ${e(g.anket.ajans)} · ${e(g.anket.hedef)}</div>
    <h3 style="margin-top:4px">Bugün seçim olsa hangi partiye oy verirdin?</h3>
    <p class="pz-not">Cevabın gizli kalır; ajans yalnız toplam oranları raporlar.${+g.anket.odul ? ` Katılım ödülü ${ajTL(g.anket.odul)}.` : ""}</p>
    <div class="secenek">${(g.anket.partiler || []).map(p => `<button onclick="ajansAnketCevap(${g.anket.id},${p.id})"><i style="background:${e(p.renk || "#888")}"></i>${e(p.kisa)}</button>`).join("")}<button onclick="ajansAnketCevap(${g.anket.id},null)">Kararsızım</button></div></div>`;
  return h;
}
async function ajansAnketCevap(id, parti){
  try { const r = await API.rpc("ajans_anket_cevap", { p_is: id, p_parti: parti }); toast(+r.odul ? `Teşekkürler! ${ajTL(r.odul)} cüzdanına yattı.` : "Teşekkürler, cevabın kaydedildi."); const k = $("#ajAnket"); if (k) k.remove(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Giriş noktaları ---------------- */
(function(){
  if (typeof gundemEkrani === "function") {
    const eskiG = gundemEkrani;
    window.gundemEkrani = gundemEkrani = async function(){
      const r = await eskiG.apply(this, arguments);
      try {
        const g = await API.rpc("ajans_gundem");
        const ic = $("#icerik");
        if (ic && D.sekme === "gundem" && !ic.querySelector(".aj-ek")) ic.insertAdjacentHTML("afterbegin", ajansGundemHtml(g));
      } catch (_) {}
      return r;
    };
    if (typeof EKRAN === "object" && EKRAN) EKRAN.gundem = () => gundemEkrani();
  }
  if (typeof iskelet === "function") {
    const eski = iskelet;
    window.iskelet = iskelet = function(baslik){
      const r = eski.apply(this, arguments);
      try {
        if (baslik === "Ekonomi merkezi") { const g = $(".br-git"); if (g && !g.querySelector(".aj-git")) g.insertAdjacentHTML("beforeend", `<button class="aj-git" onclick="ekranAc(ajansMerkezEkrani)" style="grid-column:span 2">${AJ_IKON}<span><b>Reklam ve anket ajansları</b><small>Kampanya reklamı ver, kamuoyu araştırması yaptır ya da ajans kur</small></span></button>`); }
        if (baslik === "Hayat") { const g = $(".vit-ana-izgara"); if (g && !g.querySelector(".aj-ek2")) g.insertAdjacentHTML("beforeend", `<button class="vit-ana-kart aj-ek2" onclick="ekranAc(ajansMerkezEkrani)"><span class="vit-ikon" style="color:var(--ink2)">${AJ_IKON}</span><b>Reklam ve anket</b><span>Kampanya reklamı, kamuoyu araştırması, ajans kur</span></button>`); }
      } catch (_) {}
      return r;
    };
  }
  if (typeof vitSektor === "object") vitSektor.ajans = "Reklam ve Anket Ajansı";
})();
window.ajansMerkezEkrani = ajansMerkezEkrani;
window.ajansYonetimEkrani = ajansYonetimEkrani;
