/* =====================================================================
   Ekonomi güvenliği: şeffaflık (parti kasa defterleri, yönetim hediyeleri) ve MASAK paneli.
   Arka uç: 87_ekonomi_guvenligi.sql. İlişkili hesap kuralı ve fiyat bantları sunucuda tetikleyicilerle işler;
   ihlalde oyuncu açıklayıcı hata mesajı görür.
   ===================================================================== */
"use strict";
const GV = { sekme: "parti", parti: null, masakDurum: "yeni", masak: null };
const gvTL = (x) => tlYaz(Math.round(+x || 0));
const GV_TUR = { ani_servet: "Ani servet artışı", tekrarlayan_ticaret: "Tekrarlayan karşılıklı ticaret", parti_harcama: "Büyük parti harcaması", ihale_kayirma: "Aynı partiye ihale" };
const GV_DURUM = { yeni: "İncelenmedi", temiz: "Temiz", ihtar: "İhtar verildi", el_koyuldu: "El konuldu" };
const GV_IKON = '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z"/><path d="m9 12 2 2 4-4"/></svg>';
function gvHata(baslik, err){ iskelet(baslik, `<div class="kart">${e(hataCevir(err.message))}</div>`, { geri: true }); }

/* ---------------- Şeffaflık ---------------- */
async function seffaflikEkrani(){
  yukleniyor("Şeffaflık");
  try {
    const sek = `<div class="segment" style="margin-bottom:12px">${[["parti", "Parti kasaları"], ["hediye", "Yönetim hediyeleri"]].map(([k, a]) => `<button class="${GV.sekme === k ? "aktif" : ""}" onclick="GV.sekme='${k}';seffaflikEkrani()">${a}</button>`).join("")}</div>`;
    const ust = `<div class="kart"><div class="pz-bas"><span class="pz-logo">${GV_IKON}</span><div><h2>Herkes görsün</h2>
      <p class="alt">Partilerin kasasına giren ve çıkan her kuruş, yönetimin dağıttığı hediyeler ve haksız kazanca el koyma kararları burada herkese açık.</p></div></div>
      <p class="pz-not">Aynı cihazda açılmış hesaplar birbirleriyle alım-satım, ihale, sipariş ve anket işlemi yapamaz. Borsa, şirket ve emlak satışlarında fiyat bandı vardır. Şüpheli işlemleri MASAK inceler.</p></div>`;
    if (GV.sekme === "hediye") {
      const h = await API.rpc("yonetim_hediyeleri");
      iskelet("Şeffaflık", ust + sek + `
        <div class="kart"><h2>Yönetimin dağıttığı para</h2><div class="kv"><span>Toplam</span><b>${gvTL(h.toplam)}</b></div><div class="kv"><span>Alan oyuncu</span><b>${fmt(h.kisi)}</b></div>
          ${(h.liste || []).map(x => `<div class="kv"><span>${e(x.kad)}<span class="kucuk" style="display:block">${e(x.aciklama || "")} · ${tarihSaat(x.zaman)}</span></span><b>${gvTL(x.tutar)}</b></div>`).join("") || '<p class="alt">Kayıt yok.</p>'}</div>
        <div class="kart"><h2>MASAK el koyma kararları</h2>${(h.el_koyma || []).map(x => `<div class="kv"><span>${e(x.kad)}<span class="kucuk" style="display:block">${e(x.not || "")} · ${tarihSaat(x.zaman)}</span></span><b style="color:var(--al2)">${gvTL(x.tutar)}</b></div>`).join("") || '<p class="alt">El koyma kararı yok.</p>'}</div>`, { geri: true });
      return;
    }
    if (GV.parti == null) GV.parti = D.durum && D.durum.profil && D.durum.profil.parti ? D.durum.profil.parti.id : null;
    let d = null;
    if (GV.parti != null) d = await API.rpc("parti_kasa_defteri", { p_parti: GV.parti });
    else {
      const pl = await API.rpc("partiler").catch(() => []);
      const ilk = (pl || []).find(x => !x.kapali) || (pl || [])[0];
      if (ilk) { GV.parti = ilk.id; d = await API.rpc("parti_kasa_defteri", { p_parti: ilk.id }); }
    }
    if (!d) { iskelet("Şeffaflık", ust + sek + '<div class="kart"><p class="alt">Parti bulunamadı.</p></div>', { geri: true }); return; }
    iskelet("Şeffaflık", ust + sek + `
      <div class="alan"><label>Parti</label><select onchange="GV.parti=+this.value;seffaflikEkrani()">${(d.partiler || []).map(p => `<option value="${p.id}" ${p.id === d.id ? "selected" : ""}>${e(p.ad)} (${e(p.kisa)})</option>`).join("")}</select></div>
      <div class="kart"><h2>${e(d.ad)} kasası</h2><p class="alt">Genel başkan: ${e(d.gb || "-")}</p>
        <div class="pz-grid"><span><small>Kasada</small><b>${gvTL(d.kasa)}</b></span><span><small>30 günde giren</small><b style="color:var(--good)">${gvTL(d.giris_30g)}</b></span><span><small>30 günde çıkan</small><b style="color:var(--al2)">${gvTL(d.cikis_30g)}</b></span></div>
        ${(d.turler || []).length ? `<div style="margin-top:10px">${d.turler.map(x => `<div class="kv"><span>${e(x.tur)}</span><b>${+x.giris ? "+" + gvTL(x.giris) : ""}${+x.giris && +x.cikis ? " / " : ""}${+x.cikis ? "−" + gvTL(x.cikis) : ""}</b></div>`).join("")}</div>` : ""}</div>
      <div class="kart"><h2>Kasa defteri</h2>${(d.hareketler || []).map(h => `<div class="kv"><span>${e(h.aciklama)}<span class="kucuk" style="display:block">${tarihSaat(h.zaman)}</span></span><b style="color:${+h.tutar >= 0 ? "var(--good)" : "var(--al2)"}">${+h.tutar >= 0 ? "+" : "−"}${gvTL(Math.abs(h.tutar))}</b></div>`).join("") || '<p class="alt">Hareket yok.</p>'}</div>`, { geri: true });
  } catch (err) { gvHata("Şeffaflık", err); }
}

/* ---------------- MASAK paneli ---------------- */
async function masakEkrani(){
  yukleniyor("MASAK");
  try {
    const v = await API.rpc("admin_masak", { p_durum: GV.masakDurum });
    GV.masak = v;
    const say = v.sayilar || {};
    iskelet("MASAK", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${GV_IKON}</span><div><h2>Şüpheli işlem incelemesi</h2>
        <p class="alt">Sunucu olağan dışı para hareketlerini kendiliğinden kaydeder. İncele: temizse kapat, kuşkuluysa ihtar ver, haksız kazançsa paraya el koy (hazineye geçer, herkese açık listede görünür).</p></div></div>
        <p class="pz-not">Eşikler: 24 saatte ${gvTL((v.ayar || {}).masak_servet_esik)} üstü gelir · aynı iki oyuncu arasında 7 günde 3+ alım-satım · parti kasasından ${gvTL((v.ayar || {}).parti_masak_esik)} ya da kasanın %30'u üstü harcama · ihaleyi açanla aynı partiden kazanan.</p></div>
      <div class="segment" style="margin-bottom:12px">${Object.keys(GV_DURUM).map(k => `<button class="${GV.masakDurum === k ? "aktif" : ""}" onclick="GV.masakDurum='${k}';masakEkrani()">${GV_DURUM[k]} (${fmt(say[k] || 0)})</button>`).join("")}</div>
      ${(v.kayitlar || []).map(m => `<div class="kart"><div style="display:flex;justify-content:space-between;gap:8px;align-items:flex-start"><div style="min-width:0"><b>${e(GV_TUR[m.tur] || m.tur)}</b>
          <div class="kucuk">${tarihSaat(m.zaman)}${m.kad ? " · " + e(m.kad) : ""}${m.karsi ? " ↔ " + e(m.karsi) : ""}${m.parti ? " · " + e(m.parti) : ""}</div></div>${m.tutar ? `<b>${gvTL(m.tutar)}</b>` : ""}</div>
        <p style="margin-top:8px;font-size:14.5px">${e(m.aciklama)}</p>
        ${m.kad ? `<div class="kv"><span>Cüzdanı</span><b>${gvTL(m.para)}</b></div>` : ""}
        ${(m.bagli || []).length ? `<div class="kv"><span>Aynı cihazdaki hesaplar</span><b>${m.bagli.map(e).join(", ")}</b></div>` : ""}
        ${(m.son_gelirler || []).length ? `<details style="margin-top:6px"><summary class="kucuk" style="cursor:pointer">Son gelirleri</summary>${m.son_gelirler.map(h => `<div class="kv"><span>${e(h.tur)} · ${e(h.aciklama || "")}<span class="kucuk" style="display:block">${tarihSaat(h.zaman)}</span></span><b>${gvTL(h.tutar)}</b></div>`).join("")}</details>` : ""}
        ${m.durum === "yeni" ? `<div class="vit-dugme"><button class="btn ikinci yarim" onclick="masakKarar(${m.id},'temiz')">Temiz</button><button class="btn altin yarim" onclick="masakKarar(${m.id},'ihtar')">İhtar</button>${m.kad ? `<button class="btn tehlike yarim" onclick="masakKarar(${m.id},'el_koy')">El koy</button>` : ""}</div>`
          : `<p class="pz-not">${GV_DURUM[m.durum]}${m.karar_veren ? " · " + e(m.karar_veren) : ""}${m.el_koyulan ? " · " + gvTL(m.el_koyulan) : ""}${m.karar_not ? " · " + e(m.karar_not) : ""}</p>`}</div>`).join("")
        || '<div class="kart"><p class="alt">Bu durumda kayıt yok.</p></div>'}`, { geri: true });
  } catch (err) { gvHata("MASAK", err); }
}
function masakKarar(id, karar){
  const m = ((GV.masak || {}).kayitlar || []).find(x => x.id === id) || {};
  if (karar === "temiz") return masakGonder(id, karar, null, null);
  const md = modal(`<h3 style="font-size:19px;font-weight:800">${karar === "ihtar" ? "İhtar ver" : "Paraya el koy"}</h3>
    <p class="alt" style="margin-top:6px">${e(m.kad || "")} · ${e(GV_TUR[m.tur] || "")}. Oyuncuya gerekçeyle bildirim gider${karar === "el_koy" ? "; para hazineye aktarılır ve karar herkese açık listede görünür" : ""}.</p>
    ${karar === "el_koy" ? `<div class="alan"><label>El konulacak tutar (₺) · cüzdanında ${gvTL(m.para)}</label><input id="gvTutar" type="number" min="1" step="1000" value="${Math.round(Math.min(+m.tutar || 0, +m.para || 0))}"></div>` : ""}
    <div class="alan"><label>Gerekçe (en az 10 karakter)</label><textarea id="gvNot" rows="3" maxlength="300"></textarea></div>
    <button class="btn ${karar === "el_koy" ? "tehlike" : ""}" id="gvOnay">${karar === "ihtar" ? "İhtarı gönder" : "El koy"}</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
  $("#gvOnay", md).onclick = () => { const n = $("#gvNot", md).value.trim(); if (n.length < 10) { toast("Gerekçe en az 10 karakter olmalı.", true); return; } modalKapat(); masakGonder(id, karar, karar === "el_koy" ? Math.round(+$("#gvTutar", md).value || 0) : null, n); };
}
async function masakGonder(id, karar, tutar, not){
  try { await API.rpc("admin_masak_karar", { p_id: id, p_karar: karar, p_tutar: tutar, p_not: not }); toast("Karar kaydedildi."); masakEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Giriş noktaları ---------------- */
(function(){
  if (typeof iskelet !== "function") return;
  const eski = iskelet;
  window.iskelet = iskelet = function(baslik){
    const r = eski.apply(this, arguments);
    try {
      if (baslik === "Ekonomi merkezi") { const g = $(".br-git"); if (g && !g.querySelector(".gv-git")) g.insertAdjacentHTML("beforeend", `<button class="gv-git" onclick="ekranAc(seffaflikEkrani)" style="grid-column:span 2">${GV_IKON}<span><b>Şeffaflık</b><small>Parti kasa defterleri, yönetim hediyeleri, el koyma kararları</small></span></button>`); }
      if (baslik === "Yönetici paneli" || baslik === "Moderatör paneli") { const ic = $("#icerik"); if (ic && !ic.querySelector(".gv-ek")) ic.insertAdjacentHTML("afterbegin", `<div class="kart gv-ek"><h2>MASAK</h2><p class="alt">Şüpheli para hareketlerini incele; temiz, ihtar ya da el koyma kararı ver. Moderatörlere "MASAK (ekonomi denetimi)" yetkisiyle açılır.</p><button class="btn altin" onclick="ekranAc(masakEkrani)">Şüpheli işlemler</button></div>`); }
    } catch (_) {}
    return r;
  };
})();
window.seffaflikEkrani = seffaflikEkrani;
window.masakEkrani = masakEkrani;
