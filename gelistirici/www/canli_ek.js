/* =====================================================================
   CANLI EK — kademeli seçim gecesi, boş makam fırsatları, kısa paylaşım akışı,
   başarımlar + ay raporu kartı, "Bugün Türkiye'de" özeti, titreşim ve ses.
   Ana betikten sonra yüklenir. Arka uç işlevleri (modül 75, 77, 78, 79) henüz yoksa
   her parça sessizce görünmez olur; mevcut ekranlar bozulmaz.
   ===================================================================== */
"use strict";

/* ---------- Titreşim ve ses ---------- */
const HAPTIK = {
  hafif(){ try { const H = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Haptics; if (H && H.impact) { H.impact({ style: "LIGHT" }); return; } if (navigator.vibrate) navigator.vibrate(18); } catch (_) {} },
  guclu(){ try { const H = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Haptics; if (H && H.notification) { H.notification({ type: "SUCCESS" }); return; } if (navigator.vibrate) navigator.vibrate([40, 60, 40, 60, 90]); } catch (_) {} }
};
const SES = {
  kapali(){ try { return localStorage.getItem("ses_kapali") === "1"; } catch (_) { return false; } },
  ayarla(k){ try { localStorage.setItem("ses_kapali", k ? "1" : "0"); } catch (_) {} },
  _ctx: null,
  nota(frek, bas, sure, ses){
    try {
      const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
      this._ctx = this._ctx || new AC(); const c = this._ctx; if (c.state === "suspended") c.resume();
      const o = c.createOscillator(), g = c.createGain(); o.type = "sine"; o.frequency.value = frek;
      g.gain.setValueAtTime(0.0001, c.currentTime + bas); g.gain.exponentialRampToValueAtTime(ses || 0.12, c.currentTime + bas + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + bas + sure);
      o.connect(g); g.connect(c.destination); o.start(c.currentTime + bas); o.stop(c.currentTime + bas + sure + 0.05);
    } catch (_) {}
  },
  tik(){ if (!this.kapali()) { this.nota(660, 0, 0.12, 0.08); } },
  fanfar(){ if (!this.kapali()) { [523, 659, 784, 1047].forEach((f, i) => this.nota(f, i * 0.14, 0.3, 0.12)); } }
};

/* ---------- Biçimler ---------- */
(function(){
  const st = document.createElement("style");
  st.textContent = `
.gece-kart{border:1px solid var(--al);background:linear-gradient(180deg,var(--albg),transparent 70%)}
.gece-bas{display:flex;align-items:center;gap:8px;justify-content:space-between}
.gece-bas b{font-family:var(--disp);font-size:19px}
.gece-iller{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
.gece-il{padding:4px 8px;border-radius:6px;background:var(--panel2);font-size:12.5px}
.gece-il i{font-style:normal;color:var(--txt2)}
.gece-not{margin-top:8px;padding:8px 10px;border-radius:8px;background:var(--panel2);font-size:13.5px}
.akis-yaz textarea{width:100%;min-height:76px;padding:12px;border-radius:10px;background:var(--bg);border:1px solid var(--line2);outline:none;font-size:16px;resize:vertical}
.akis-gonder{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:6px}
.akis-gonder .btn{width:auto;margin:0;padding:9px 18px}
.etiket-cipler{display:flex;flex-wrap:wrap;gap:6px;margin-top:8px}
.etiket-cip{padding:5px 10px;border-radius:14px;background:var(--panel2);font-size:13.5px;font-weight:700;color:var(--ink2);cursor:pointer;border:1px solid transparent}
.etiket-cip.aktif{border-color:var(--ink2)}
.akis-satir{display:flex;gap:10px;padding:12px 0;border-bottom:1px solid var(--line)}
.akis-satir .metin{white-space:pre-wrap;overflow-wrap:anywhere;font-size:15px;margin-top:2px}
.akis-satir .etk{color:var(--ink2);font-weight:700;cursor:pointer}
.akis-alt{display:flex;gap:16px;margin-top:6px;font-size:13px;color:var(--txt2)}
.akis-alt button{color:inherit;font-size:13px;padding:2px 0}
.akis-alt .acik{color:var(--al2);font-weight:700}
.sekme-cip{display:flex;gap:6px;margin:10px 0}
.sekme-cip button{flex:1;padding:8px 6px;border-radius:8px;background:var(--panel2);font-weight:700;font-size:14px}
.sekme-cip button.aktif{background:var(--ink);color:#fff}
.rapor-kart{background:linear-gradient(160deg,#101a40,#1b2760 60%,#2a1a55);color:#fff;border-radius:16px;padding:20px 18px}
.rapor-kart h2{font-family:var(--disp);font-size:26px;margin:2px 0 12px;color:#fff}
.rapor-kart .ks{color:rgba(255,255,255,.7);font-size:13px}
.rapor-izgara{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:12px}
.rapor-izgara div{background:rgba(255,255,255,.1);border-radius:10px;padding:10px 6px;text-align:center}
.rapor-izgara b{display:block;font-family:var(--disp);font-size:24px}
.rapor-izgara span{font-size:12px;color:rgba(255,255,255,.75)}
.basarim-satir{display:flex;align-items:center;gap:12px;padding:10px 0;border-bottom:1px solid var(--line)}
.basarim-rozet{width:42px;height:42px;border-radius:50%;display:grid;place-items:center;font-family:var(--disp);font-weight:700;font-size:15px;flex:none}
.basarim-rozet.bronz{background:#8c5a2b;color:#fff}.basarim-rozet.gumus{background:#aeb6c4;color:#1a2038}.basarim-rozet.altin{background:#d9b04a;color:#2b2105}
.basarim-satir.kilitli{opacity:.45}
.ozet-kart li{margin:6px 0 0 18px;font-size:14.5px}
`;
  document.head.appendChild(st);
})();

/* ---------- 1) SEÇİM GECESİ: canlı sayım paneli ---------- */
const GECE = { durum: {} };
function sureYaz(sn){ sn = Math.max(0, Math.round(sn)); const d = Math.floor(sn / 60), s = sn % 60; return d ? `${d} dk ${String(s).padStart(2, "0")} sn` : `${s} sn`; }
function geceKartHtml(s){
  const g = s.gece; if (!g) return "";
  if (g.basliyor) return `<div class="kart gece-kart"><div class="gece-bas"><b>Sayım birazdan başlıyor</b><span class="rozet kirmizi">Canlı</span></div>
    <div class="alt">Sandıklar kapandı. Sonuçlar il il açılacak; ilk iller ${sureYaz(g.saniye_kaldi)} sonra gelir.</div></div>`;
  const benimIl = s.tur === "mv" || s.tur === "cb" || s.tur === "cb2" ? String(s.benim_il || (D.durum && D.durum.profil && D.durum.profil.il_id) || "") : "";
  const acik = (s.sonuc && s.sonuc.iller) || {};
  const ilAcildi = benimIl && (s.tur === "mv" ? !!acik[benimIl] : (g.son_acilan || []).some(x => String(x.il_id) === benimIl) || g.acilan_il >= g.toplam_il);
  const ilNotu = benimIl && s.tur === "mv" ? (acik[benimIl] ? `<div class="gece-not">${e(ilAd(+benimIl))} açıldı. Sonucu aşağıda.</div>` : `<div class="gece-not">${e(ilAd(+benimIl))} henüz açılmadı. Sandığı bekliyoruz.</div>`) : "";
  return `<div class="kart gece-kart" id="geceKart"><div class="gece-bas"><b>Canlı sayım</b><span class="rozet kirmizi">${g.acilan_il}/${g.toplam_il} il</span></div>
    <div class="bar"><i style="width:${Math.min(100, g.yuzde)}%;background:var(--al)"></i></div>
    <div class="kv" style="margin-top:8px"><span class="k">Sayılan sandık</span><span class="v">%${String(g.yuzde).replace(".", ",")}</span></div>
    ${g.onde ? `<div class="kv"><span class="k">Şu an önde</span><span class="v">${e(g.onde)}</span></div>` : ""}
    <div class="kv"><span class="k">Kalan süre</span><span class="v" data-an="${new Date(g.bitis).getTime()}">${sureYaz(g.saniye_kaldi)}</span></div>
    ${ilNotu}
    ${(g.son_acilan || []).length ? `<div class="gece-iller">${g.son_acilan.map(x => `<span class="gece-il"><b>${e(x.ad)}</b> <i>${e(x.onde || "")}</i></span>`).join("")}</div>` : ""}
    <div style="display:flex;justify-content:space-between;margin-top:8px"><span class="kucuk">Sonuçlar küçük illerden büyüğe doğru açılır.</span>
      <button class="kucuk" style="text-decoration:underline" onclick="SES.ayarla(!SES.kapali());this.textContent=SES.kapali()?'Ses kapalı':'Ses açık'">${SES.kapali() ? "Ses kapalı" : "Ses açık"}</button></div></div>`;
}
// secimEkrani çizdikten sonra çağrılır
function geceKancasi(s){
  const onceki = GECE.durum[s.id];
  const g = s.gece;
  if (g && (g.aktif || g.basliyor)) {
    const ic = $("#icerik"); if (ic) ic.insertAdjacentHTML("afterbegin", geceKartHtml(s));
    if (onceki && g.aktif && g.acilan_il > onceki.acilan_il) {
      HAPTIK.hafif(); SES.tik();
      const benimIl = String(s.benim_il || "");
      if (s.tur === "mv" && benimIl && s.sonuc && s.sonuc.iller && s.sonuc.iller[benimIl] && !onceki.benimAcik) { HAPTIK.guclu(); toast(`${ilAd(+benimIl)} sonuçları açıldı.`); }
    }
    const benimAcik = !!(s.sonuc && s.sonuc.iller && s.sonuc.iller[String(s.benim_il || "")]);
    GECE.durum[s.id] = { acilan_il: g.acilan_il || 0, aktif: true, benimAcik };
    D.canli = setInterval(() => { if (!document.hidden && (!window.YUK || YUK.otomatik())) secimEkrani(s.id, true); }, 15000 + Math.floor(Math.random() * 4000));
  } else if (onceki && onceki.aktif) {
    GECE.durum[s.id] = { aktif: false };
    HAPTIK.guclu(); SES.fanfar(); toast("Sayım tamamlandı. Kesin sonuçlar açıklandı.");
  }
}

/* ---------- Gündem: ek kartlar ---------- */
async function gundemEkVeri(iste){
  const [canli, firsat, etiket, ozet, akis, cimer] = await Promise.all([
    iste("secim_gecesi_aktif", undefined, []), iste("bos_makam_firsatlari", undefined, []),
    iste("akis_gundem", undefined, null), iste("gun_ozeti", undefined, null), iste("kursu_akis", { p_sekme: "herkes", p_imlec: null, p_limit: 3 }, null),
    typeof cimerGundemHtml === "function" ? iste("cimer", undefined, null) : null]);
  return { canli: canli || [], firsat: firsat || [], etiket, ozet, akis: (akis && akis.liste || []).map(x => x.g), cimer };
}
function gundemEkUst(ek){
  if (!ek || !ek.canli.length) return "";
  return ek.canli.map(c => `<div class="kart gece-kart" style="cursor:pointer" onclick="ekranAc(()=>secimEkrani(${c.secim_id}))">
    <div class="gece-bas"><b>${c.tur === "mv" ? "Genel seçim" : "Cumhurbaşkanlığı"} sayımı sürüyor</b><span class="rozet kirmizi">Canlı</span></div>
    <div class="bar"><i style="width:${Math.min(100, +c.yuzde || 0)}%;background:var(--al)"></i></div>
    <div class="kucuk" style="margin-top:6px">Sandıkların %${String(c.yuzde || 0).replace(".", ",")}'i sayıldı · Canlı izle</div></div>`).join("");
}
function firsatGit(f){
  const pid = D.durum && D.durum.profil && D.durum.profil.parti && D.durum.profil.parti.id;
  if (f.ekran === "parti" && pid) return `ekranAc(()=>partiDetay(${pid}))`;
  return `(document.querySelector('[id^=sec]')||document.body).scrollIntoView({behavior:'smooth'})`;
}
function gundemEkAlt(ek){
  if (!ek) return "";
  let h = "";
  if (ek.firsat.length) {
    h += `<div class="bolum-bas"><h2>Fırsatlar</h2><span class="kucuk">${ek.firsat.length}</span></div><div class="kart">${ek.firsat.slice(0, 4).map(f =>
      `<div class="giris-satir" onclick="${firsatGit(f).replace(/"/g, "&quot;")}"><span class="yik">${IKON.kalem}</span><span class="orta"><b>${e(f.metin)}</b></span><span class="ok">›</span></div>`).join("")}</div>`;
  }
  if (ek.ozet && ek.ozet.gelismeler && ek.ozet.gelismeler.length) {
    h += `<div class="bolum-bas"><h2>Bugün Türkiye'de</h2></div><div class="kart ozet-kart"><ul style="margin:0;padding:0">${ek.ozet.gelismeler.slice(0, 4).map(x => `<li>${e(x.metin)}</li>`).join("")}</ul></div>`;
  }
  if (ek.cimer && typeof cimerGundemHtml === "function") h += cimerGundemHtml(ek.cimer);
  if (ek.etiket === null) return h;   // arka uç modülü henüz kurulmamış
  const et = ek.etiket || [];
  AKIS.gundemListe = ek.akis || [];
  h += `<div class="bolum-bas"><h2>Akış</h2><button class="kucuk" style="color:var(--ink2);font-weight:700" onclick="ekranAc(()=>akisEkrani())">Tümünü gör ›</button></div>
    <div class="kart akis-kart">
      <div id="gAkisListe">${AKIS.gundemListe.map(akisSatirHtml).join("") || `<div class="bos" style="padding:12px 0">Henüz paylaşım yok. İlk sözü sen söyle.</div>`}</div>
      <button class="btn ikinci" onclick="ekranAc(()=>kursuEkrani())">Devamını okumak için Kürsü’ye git →</button>
    </div>
    <div class="kart"><button class="giris-satir" style="border:0;padding:4px 0" onclick="ekranAc(raporEkrani)"><span class="yik">${IKON.anket}</span><span class="orta"><b>Raporum ve başarımlarım</b><span class="kucuk">Bu ayın özeti, paylaşılabilir kart</span></span><span class="ok">›</span></button></div>`;
  setTimeout(() => {
    const k = $("#gAkisListe"); if (!k) return;
    akisBagla(k, () => AKIS.gundemListe, window.soAkisYenile);
  }, 0);
  return h;
}

/* ---------- 4) AKIŞ — sosyal platform ---------- */
const AKIS = { kapsam: "herkes", etiket: null, liste: [], bitti: false, gundemListe: [] };
const AKIS_IKON = {
  begen: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 10v11H4V10zM7 10l4-7a2 2 0 0 1 3 2l-1 5h6a2 2 0 0 1 2 2.3l-1.3 7A2 2 0 0 1 17.7 21H7"/></svg>',
  begenme: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 14V3h3v11zM17 14l-4 7a2 2 0 0 1-3-2l1-5H5a2 2 0 0 1-2-2.3l1.3-7A2 2 0 0 1 6.3 3H17"/></svg>',
  yanit: '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>',
  menu: '<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><circle cx="5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="19" cy="12" r="1.8"/></svg>'
};
(function(){ const st = document.createElement("style"); st.textContent = `
.akis-satir{position:relative}
.akis-ust{display:flex;align-items:baseline;gap:6px;flex-wrap:wrap;min-width:0}
.akis-ust .zaman{color:var(--txt2);font-size:13px}
.akis-unvan{color:var(--txt2);font-size:12.5px;margin-top:1px}
.akis-alt{display:flex;align-items:center;gap:4px;margin-top:8px;font-size:13.5px;color:var(--txt2)}
.akis-alt button{display:inline-flex;align-items:center;gap:6px;padding:5px 10px 5px 6px;border-radius:16px;color:inherit;font-size:13.5px;font-weight:600}
.akis-alt button:active{background:var(--panel2)}
.akis-alt .acik-begen{color:var(--ok,#3ccf8e)}
.akis-alt .acik-begenme{color:var(--al2)}
.akis-alt .bosluk{flex:1}
.akis-kart .akis-yaz textarea,.akis-yaz textarea{min-height:64px}
.konu-ana{font-size:17px}
.konu-ana .metin{font-size:17px}
`; document.head.appendChild(st); })();
function gecenZaman(ts){
  const s = Math.max(0, (simdi() - new Date(ts).getTime()) / 1000);
  if (s < 60) return "şimdi"; if (s < 3600) return Math.floor(s / 60) + " dk"; if (s < 86400) return Math.floor(s / 3600) + " sa";
  if (s < 7 * 86400) return Math.floor(s / 86400) + " g"; return tarih(ts);
}
function akisMetinHtml(m){
  // Etiketleri ham metinde bul: önce HTML'e çevirirsek &#39; içindeki #39 da etiket sanılır.
  const metin = String(m ?? "");
  let html = "", son = 0;
  for (const eslesme of metin.matchAll(/#([\p{L}\p{N}_]{2,30})/gu)) {
    html += e(metin.slice(son, eslesme.index));
    const t = eslesme[1];
    html += `<span class="etk" data-etk="${e(t.toLowerCase())}">#${e(t)}</span>`;
    son = eslesme.index + eslesme[0].length;
  }
  return html + e(metin.slice(son));
}
function akisSatirHtml(a, opt){
  opt = opt || {};
  const dislikeVar = a.begenmeme !== undefined;
  return `<div class="akis-satir${opt.ana ? " konu-ana" : ""}" data-id="${a.id}">${portre(a.kad, a.parti && a.parti.renk, 40)}<div style="flex:1;min-width:0">
    <div class="akis-ust"><b onclick="oyuncuKart('${e(a.kad)}')" style="cursor:pointer">${e(a.kad)}</b>${a.parti ? " " + partiRozet(a.parti, true) : ""}<span class="zaman">· ${gecenZaman(a.zaman)}</span></div>
    ${a.unvan || a.il ? `<div class="akis-unvan">${a.unvan ? e(a.unvan) : ""}${a.unvan && a.il ? " · " : ""}${a.il ? e(a.il) : ""}</div>` : ""}
    <div class="metin" ${opt.ana ? "" : `data-konu="${a.id}" style="cursor:pointer"`}>${akisMetinHtml(a.metin)}</div>
    <div class="akis-alt">
      ${a.yanit !== undefined ? `<button data-yanitla="${a.id}" aria-label="Yanıtla">${AKIS_IKON.yanit}<span>${a.yanit || ""}</span></button>` : ""}
      <button class="${a.begendim ? "acik-begen" : ""}" data-tepki="begen" data-id="${a.id}" aria-label="Beğen">${AKIS_IKON.begen}<span>${a.begeni || ""}</span></button>
      ${dislikeVar ? `<button class="${a.begenmedim ? "acik-begenme" : ""}" data-tepki="begenme" data-id="${a.id}" aria-label="Beğenme">${AKIS_IKON.begenme}<span>${a.begenmeme || ""}</span></button>` : ""}
      <span class="bosluk"></span>
      <button data-menu="${a.id}" aria-label="Seçenekler">${AKIS_IKON.menu}</button></div></div></div>`;
}
function akisYazHtml(id, yer){
  return `<div class="akis-yaz"><textarea id="${id}Metin" maxlength="280" placeholder="${e(yer)}"></textarea>
    <div class="akis-gonder"><span class="kucuk" id="${id}Sayac">0/280</span><button class="btn" id="${id}Gonder">Paylaş</button></div></div>`;
}
function akisYazBagla(id, sonra, yanitId){
  const t = $("#" + id + "Metin"), b = $("#" + id + "Gonder"); if (!t || !b) return;
  t.oninput = () => { $("#" + id + "Sayac").textContent = `${t.value.length}/280`; };
  b.onclick = async () => {
    b.disabled = true;
    try {
      if (yanitId) await API.rpc("akis_yanit_yaz", { p_id: yanitId, p_metin: t.value }); else await API.rpc("akis_yaz", { p_metin: t.value });
      t.value = ""; $("#" + id + "Sayac").textContent = "0/280"; HAPTIK.hafif(); toast(yanitId ? "Yanıtın gönderildi." : "Paylaşıldı.");
      if (sonra) await sonra();
    } catch (err) { toast(hataCevir(err.message), true); }
    b.disabled = false;
  };
}
// Bir liste kabının içindeki düğmeleri bağlar. liste(): o kaptaki paylaşım dizisi; yenile(): silme/engel sonrası
function akisBagla(k, liste, yenile){
  const bul = id => (liste() || []).find(x => x.id === id);
  k.querySelectorAll("[data-etk]").forEach(el => el.onclick = ev => { ev.stopPropagation(); ekranAc(() => akisEkrani(el.dataset.etk)); });
  k.querySelectorAll("[data-konu]").forEach(el => el.onclick = () => ekranAc(() => akisKonuEkrani(+el.dataset.konu)));
  k.querySelectorAll("[data-yanitla]").forEach(el => el.onclick = () => ekranAc(() => akisKonuEkrani(+el.dataset.yanitla, true)));
  k.querySelectorAll("[data-tepki]").forEach(el => el.onclick = async () => {
    const id = +el.dataset.id, a = bul(id); if (!a) return;
    const tur = el.dataset.tepki;
    try {
      const r = a.begenmeme === undefined ? await API.rpc("akis_begen", { p_id: id }) : await API.rpc("akis_tepki", { p_id: id, p_tepki: tur });
      Object.assign(a, r); HAPTIK.hafif();
      const satir = el.closest(".akis-satir"); const yeni = document.createElement("div"); yeni.innerHTML = akisSatirHtml(a, { ana: satir.classList.contains("konu-ana") });
      satir.replaceWith(yeni.firstElementChild); akisBagla(k, liste, yenile);
    } catch (err) { toast(hataCevir(err.message), true); }
  });
  k.querySelectorAll("[data-menu]").forEach(el => el.onclick = () => akisMenu(bul(+el.dataset.menu), yenile));
}
function akisMenu(a, yenile){
  if (!a) return;
  if (a.benim) {
    const m = modal(`<h3 style="font-size:19px;font-weight:800">Paylaşımın</h3><button class="btn tehlike" id="amSil">Paylaşımı sil</button>`);
    $("#amSil", m).onclick = async () => { try { await islem(() => API.rpc("akis_sil", { p_id: a.id }), "Paylaşım silindi."); modalKapat(); if (yenile) yenile(); } catch (_) {} };
    return;
  }
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(a.kad)}</h3><p class="alt">Uygunsuz bir paylaşımı şikâyet edebilir ya da bu kullanıcıyı engelleyebilirsin. 3 ayrı şikâyette paylaşım otomatik gizlenir.</p>
    <div class="alan"><select id="skNeden"><option value="hakaret">Hakaret</option><option value="nefret">Nefret söylemi</option><option value="spam">Spam</option><option value="taciz">Taciz</option><option value="uygunsuz">Uygunsuz içerik</option><option value="diger">Diğer</option></select></div>
    <button class="btn tehlike" id="skGonder">Şikâyet et</button><button class="btn ikinci" id="skEngel">Bu kullanıcıyı engelle</button>`);
  $("#skGonder", m).onclick = async () => { try { await islem(() => API.rpc("akis_sikayet_et", { p_id: a.id, p_neden: $("#skNeden", m).value }), "Şikâyetin alındı."); modalKapat(); } catch (_) {} };
  $("#skEngel", m).onclick = async () => { try { await islem(() => API.rpc("engelle", { p_kad: a.kad }), `${a.kad} engellendi.`); modalKapat(); if (yenile) yenile(); } catch (_) {} };
}
async function akisYukle(daha){
  const son = daha && AKIS.liste.length ? AKIS.liste[AKIS.liste.length - 1].id : null;
  const yeni = await API.rpc("akis_liste", { p_kapsam: AKIS.kapsam, p_etiket: AKIS.etiket, p_onceki: son, p_limit: 20 });
  AKIS.liste = daha ? AKIS.liste.concat(yeni) : yeni; AKIS.bitti = yeni.length < 20;
}
function akisListeCiz(){
  const k = $("#akisListe"); if (!k) return;
  k.innerHTML = (AKIS.liste.map(a => akisSatirHtml(a)).join("") || `<div class="bos">${AKIS.etiket ? "Bu etikette paylaşım yok." : "Henüz paylaşım yok. İlk sözü sen söyle."}</div>`) + (AKIS.bitti ? "" : `<button class="btn ikinci" id="akisDaha">Daha fazla</button>`);
  const d = $("#akisDaha"); if (d) d.onclick = async () => { try { await akisYukle(true); akisListeCiz(); } catch (err) { toast(hataCevir(err.message), true); } };
  akisBagla(k, () => AKIS.liste, async () => { await akisYukle(false); akisListeCiz(); });
}
async function akisEkrani(etiket, sessiz){
  if (!sessiz) { AKIS.kapsam = "herkes"; AKIS.etiket = etiket ? String(etiket).replace(/^#/, "").toLowerCase() : null; }
  yukleniyor("Akış");
  let gundem = [];
  try { [gundem] = await Promise.all([API.rpc("akis_gundem").catch(() => []), akisYukle(false)]); }
  catch (err) { iskelet("Akış", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
  const kapsamlar = [["herkes", "Herkes"], ["il", "İlim"], ["parti", "Partim"]];
  iskelet("Akış", `
    <div class="kart">${akisYazHtml("akis", "Ne düşünüyorsun? #etiket kullanabilirsin")}</div>
    ${gundem.length ? `<div class="bolum-bas" style="margin-top:4px"><h2 style="font-size:17px">Gündemdekiler</h2></div><div class="etiket-cipler" style="margin:0 0 6px">${gundem.map(x => `<span class="etiket-cip${AKIS.etiket === x.etiket ? " aktif" : ""}" data-gundem="${e(x.etiket)}">#${e(x.etiket)} <span class="kucuk">${x.kisi} kişi</span></span>`).join("")}</div>` : ""}
    ${AKIS.etiket ? `<div class="kart" style="display:flex;justify-content:space-between;align-items:center"><b>#${e(AKIS.etiket)}</b><button class="kucuk" id="etiketKaldir" style="text-decoration:underline">Süzgeci kaldır</button></div>` : ""}
    <div class="sekme-cip">${kapsamlar.map(([k, ad]) => `<button data-kapsam="${k}" class="${AKIS.kapsam === k ? "aktif" : ""}">${ad}</button>`).join("")}</div>
    <div class="kart" id="akisListe"></div>
    <p class="kucuk" style="text-align:center">Beğeni ve beğenmeme sayıları herkese açıktır; kimin verdiği görünmez. Hakaret, küfür ve bağlantı yasaktır.</p>`, { geri: true });
  akisListeCiz();
  akisYazBagla("akis", async () => { await akisYukle(false); akisListeCiz(); });
  document.querySelectorAll("[data-kapsam]").forEach(el => el.onclick = async () => { AKIS.kapsam = el.dataset.kapsam; akisEkrani(AKIS.etiket, true); });
  document.querySelectorAll("[data-gundem]").forEach(el => el.onclick = () => { AKIS.etiket = AKIS.etiket === el.dataset.gundem ? null : el.dataset.gundem; akisEkrani(AKIS.etiket, true); });
  const ek = $("#etiketKaldir"); if (ek) ek.onclick = () => { AKIS.etiket = null; akisEkrani(null, true); };
}
// Bir paylaşım ve altındaki yanıtlar
async function akisKonuEkrani(id, yaz){
  yukleniyor("Paylaşım");
  let k;
  try { k = await API.rpc("akis_konu", { p_id: id }); }
  catch (err) { iskelet("Paylaşım", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
  const hepsi = () => [k.ana].concat(k.yanitlar);
  iskelet("Paylaşım", `<div class="kart" id="konuKap">${akisSatirHtml(k.ana, { ana: true })}
      <div class="bolum-bas" style="margin:12px 0 0"><h2 style="font-size:16px">Yanıtlar</h2><span class="kucuk">${k.yanitlar.length}</span></div>
      ${k.yanitlar.map(y => akisSatirHtml(y)).join("") || `<div class="bos" style="padding:10px 0">Henüz yanıt yok.</div>`}</div>
    <div class="kart">${akisYazHtml("yanit", `${k.ana.kad} kişisine yanıt yaz…`)}</div>`, { geri: true });
  const kap = $("#konuKap");
  akisBagla(kap, hepsi, () => akisKonuEkrani(k.ana.id));
  kap.querySelectorAll("[data-konu]").forEach(el => el.onclick = null);
  kap.querySelectorAll("[data-yanitla]").forEach(el => el.onclick = () => { const t = $("#yanitMetin"); if (t) t.focus(); });
  akisYazBagla("yanit", () => akisKonuEkrani(k.ana.id), k.ana.id);
  if (yaz) setTimeout(() => { const t = $("#yanitMetin"); if (t) { t.scrollIntoView({ block: "center" }); t.focus(); } }, 50);
}

/* ---------- 5) AY RAPORU VE BAŞARIMLAR ---------- */
const RAPOR = { ay: null };
function raporKartHtml(r){
  return `<div class="rapor-kart" id="raporKart"><div class="ks">${e(r.ay_ad)} raporu</div><h2>${e(r.kad)}</h2>
    <div class="ks">${r.unvan ? e(r.unvan) + " · " : ""}${r.parti ? e(r.parti.ad) + " · " : "Bağımsız · "}${e(r.il || "")}</div>
    <div class="rapor-izgara"><div><b>${r.paylasim}</b><span>paylaşım</span></div><div><b>${r.begeni}</b><span>beğeni</span></div><div><b>${r.basarim_toplam}</b><span>başarım</span></div>
      <div><b>${String(r.makam_gun).replace(".", ",")}</b><span>makam günü</span></div>
      ${r.parti ? `<div><b>${r.parti_vekil || 0}</b><span>parti vekili</span></div><div><b>${r.parti_sira || "-"}.</b><span>parti sırası</span></div>` : `<div><b>${(r.yeni_makamlar || []).length}</b><span>yeni makam</span></div><div><b>${(r.yeni_basarimlar || []).length}</b><span>yeni başarım</span></div>`}</div>
    ${(r.yeni_basarimlar || []).length ? `<div class="ks" style="margin-top:12px">Bu ay kazandıkların: ${r.yeni_basarimlar.map(x => e(x.ad)).join(", ")}</div>` : ""}
    <div class="ks" style="margin-top:12px;opacity:.7">Seçim Simülasyonu Online</div></div>`;
}
function raporResmi(r){
  return new Promise(res => {
    const c = document.createElement("canvas"); c.width = 1080; c.height = 1350; const x = c.getContext("2d");
    const gr = x.createLinearGradient(0, 0, 1080, 1350); gr.addColorStop(0, "#101a40"); gr.addColorStop(.6, "#1b2760"); gr.addColorStop(1, "#2a1a55");
    x.fillStyle = gr; x.fillRect(0, 0, 1080, 1350);
    const fam = '"Kurul Display", system-ui, sans-serif';
    x.fillStyle = "rgba(255,255,255,.7)"; x.font = `500 38px ${fam}`; x.fillText(`${r.ay_ad} raporu`, 80, 150);
    x.fillStyle = "#fff"; x.font = `700 92px ${fam}`; x.fillText(r.kad, 80, 270, 920);
    x.fillStyle = "rgba(255,255,255,.8)"; x.font = `500 38px ${fam}`;
    x.fillText([r.unvan, r.parti && r.parti.ad, r.il].filter(Boolean).join(" · "), 80, 340, 920);
    const kutu = [[r.paylasim, "paylaşım"], [r.begeni, "beğeni"], [r.basarim_toplam, "başarım"], [String(r.makam_gun).replace(".", ","), "makam günü"], [r.parti ? r.parti_vekil || 0 : (r.yeni_makamlar || []).length, r.parti ? "parti vekili" : "yeni makam"], [r.parti ? (r.parti_sira || "-") + "." : (r.yeni_basarimlar || []).length, r.parti ? "parti sırası" : "yeni başarım"]];
    kutu.forEach((k, i) => {
      const bx = 80 + (i % 3) * 300, by = 430 + Math.floor(i / 3) * 270;
      x.fillStyle = "rgba(255,255,255,.1)"; x.beginPath(); x.roundRect ? x.roundRect(bx, by, 270, 230, 24) : x.rect(bx, by, 270, 230); x.fill();
      x.fillStyle = "#fff"; x.textAlign = "center"; x.font = `700 90px ${fam}`; x.fillText(String(k[0]), bx + 135, by + 118, 240);
      x.fillStyle = "rgba(255,255,255,.75)"; x.font = `500 32px ${fam}`; x.fillText(k[1], bx + 135, by + 175); x.textAlign = "left";
    });
    if ((r.yeni_basarimlar || []).length) { x.fillStyle = "rgba(255,255,255,.85)"; x.font = `500 34px ${fam}`; x.fillText("Bu ay: " + r.yeni_basarimlar.map(b => b.ad).join(", "), 80, 1020, 920); }
    x.fillStyle = "rgba(255,255,255,.55)"; x.font = `500 34px ${fam}`; x.fillText("Seçim Simülasyonu Online", 80, 1260);
    c.toBlob(b => res(b), "image/png");
  });
}
async function raporPaylas(r){
  try {
    const blob = await raporResmi(r); const dosya = new File([blob], `rapor-${r.ay}.png`, { type: "image/png" });
    if (navigator.canShare && navigator.canShare({ files: [dosya] })) { await navigator.share({ files: [dosya], text: r.paylasim_metni }); return; }
    if (navigator.share) { await navigator.share({ text: r.paylasim_metni }); return; }
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = dosya.name; document.body.appendChild(a); a.click(); a.remove(); toast("Rapor kartı indirildi.");
  } catch (err) { if (err && err.name === "AbortError") return; try { await navigator.clipboard.writeText(r.paylasim_metni); toast("Rapor metni kopyalandı."); } catch (_) { toast("Paylaşılamadı.", true); } }
}
async function raporEkrani(ay){
  yukleniyor("Raporum");
  let r, b;
  try { [r, b] = await Promise.all([API.rpc("ay_raporu", { p_ay: typeof ay === "string" ? ay : null }), API.rpc("basarimlar")]); }
  catch (err) { iskelet("Raporum", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
  const onceki = (() => { const [y, m] = r.ay.split("-").map(Number); const d = new Date(Date.UTC(y, m - 2, 15)); return d.toISOString().slice(0, 10); })();
  const sonraki = (() => { const [y, m] = r.ay.split("-").map(Number); const d = new Date(Date.UTC(y, m, 15)); return d.toISOString().slice(0, 10); })();
  const simdikiAy = new Date(simdi() + 3 * 3600e3).toISOString().slice(0, 7);
  iskelet("Raporum", `${raporKartHtml(r)}
    <div class="vit-dugme"><button class="btn altin" id="rpPaylas">Kartı paylaş</button><button class="btn ikinci" id="rpOnceki">Önceki ay</button></div>
    ${r.ay < simdikiAy ? `<button class="btn ikinci" id="rpSonraki">Sonraki ay</button>` : ""}
    <div class="bolum-bas"><h2>Başarımlar</h2><span class="kucuk">${b.filter(x => x.kazandi).length}/${b.length}</span></div>
    <div class="kart">${b.map(x => `<div class="basarim-satir${x.kazandi ? "" : " kilitli"}"><div class="basarim-rozet ${e(x.sinif)}">${e(x.ad.slice(0, 1))}</div>
      <div class="orta"><b>${e(x.ad)}</b><div class="kucuk">${e(x.aciklama)}${x.kazandi && x.zaman ? " · " + tarih(x.zaman) : ""}</div></div></div>`).join("")}</div>`, { geri: true });
  $("#rpPaylas").onclick = () => raporPaylas(r);
  $("#rpOnceki").onclick = () => raporEkrani(onceki);
  const sn = $("#rpSonraki"); if (sn) sn.onclick = () => raporEkrani(sonraki);
}
