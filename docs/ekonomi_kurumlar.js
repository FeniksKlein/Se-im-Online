/* =====================================================================
   Ekonomi kurumları: Merkez Bankası, belediye tahvili, SPK, konkordato/iflas.
   Arka uç: 93_ekonomi_kurumlar.sql. Ortak yardımcılar ekonomi_borsa.js / ekonomi_pazar.js'ten.
   ===================================================================== */
"use strict";
const EK = { mb: null, tahvil: null, spk: null, konk: null };
const ekTL = (x) => (typeof pzTL === "function" ? pzTL(x) : tlYaz(Math.round(+x || 0)));
const ekYuzde = (x, d) => "%" + fmt(+x || 0, d == null ? 1 : d);
const EK_IKON = {
  banka: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 10 12 4l9 6"/><path d="M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 21h18"/></svg>',
  tahvil: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M7 9h6M7 13h10M15 16.5h2"/><circle cx="17" cy="9" r="1.5"/></svg>',
  spk: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="10.5" cy="10.5" r="6"/><path d="m15 15 6 6"/><path d="m7.5 12 2-2 1.5 1.5 2.5-3"/></svg>',
  konk: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 2 20h20z"/><path d="M12 10v4M12 17h.01"/></svg>'
};
(function(){ const st = document.createElement("style"); st.textContent = `
.ek-faiz{font-family:var(--disp);font-size:44px;line-height:1;margin:6px 0 2px;color:var(--txt)}
.ek-cubuk{height:8px;border-radius:5px;background:var(--panel2);overflow:hidden;margin:8px 0 4px}
.ek-cubuk i{display:block;height:100%;background:var(--ink2);border-radius:5px}
.ek-sec{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;margin-top:8px}
.ek-sec button{padding:10px 4px;border-radius:10px;background:var(--panel2);color:var(--txt);font-weight:700;border:1px solid transparent}
.ek-sec button.secili{border-color:var(--ink2);color:var(--ink2)}
.ek-alan textarea{width:100%;min-height:70px;padding:12px;border-radius:10px;background:var(--bg);border:1px solid var(--line2);font-size:16px;color:var(--txt)}
`; document.head.appendChild(st); })();
function ekHata(baslik, err){ iskelet(baslik, `<div class="kart">${e(hataCevir(err.message))}</div>`, { geri: true }); }
const ekDurum = (d) => ({
  satista: '<span class="rozet altin">Satışta</span>', tutuluyor: '<span class="rozet">Vadesi bekleniyor</span>',
  odendi: '<span class="rozet yesil">Ödendi</span>', temerrut: '<span class="rozet kirmizi">Temerrüt</span>', iptal: '<span class="rozet">İptal</span>',
  acik: '<span class="rozet altin">İnceleniyor</span>', ceza: '<span class="rozet kirmizi">Ceza</span>', beraat: '<span class="rozet yesil">İhlal yok</span>',
  surec: '<span class="rozet altin">Konkordato</span>', kurtuldu: '<span class="rozet yesil">Kurtuldu</span>', iflas: '<span class="rozet kirmizi">İflas</span>'
})[d] || `<span class="rozet">${e(d)}</span>`;

/* ---------------- Merkez Bankası ---------------- */
async function merkezBankasiEkrani(){
  yukleniyor("Merkez Bankası");
  try {
    const m = EK.mb = await API.rpc("merkez_bankasi");
    const o = m.oranlar || {};
    const reel = +m.reel_faiz;
    const reelYazi = reel > 5 ? "Sıkı para politikası: enflasyon gerileme eğiliminde, büyüme yavaşlıyor."
      : reel < -2 ? "Gevşek para politikası: büyüme destekleniyor, enflasyon baskısı artıyor." : "Nötr para politikası.";
    const t = m.bekleyen_teklifim;
    iskelet("Merkez Bankası", `
      ${t ? `<div class="kart"><h2>Sana görev teklifi var</h2><p class="alt">${e(t.teklif_eden)} seni Merkez Bankası Başkanı olarak atamak istiyor. Başkan tarafsızdır: görevdeyken siyasi makam alamazsın; seçilirsen bankadaki görevin biter. Günlük bakan maaşının karşılığını alırsın.</p>
        <button class="btn" onclick="tcmbYanit(${t.id},true)">Görevi kabul et</button><button class="btn ikinci" onclick="tcmbYanit(${t.id},false)">Reddet</button></div>` : ""}
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${EK_IKON.banka}</span><div><h2>Politika faizi</h2>
        <p class="alt">${m.baskan ? `Başkan: <b>${e(m.baskan.kad)}</b>` : "Başkanlık boş"}${m.tcmb_karari ? "" : " · henüz PPK kararı yok, faiz enflasyona göre otomatik belirleniyor"}</p></div></div>
        <div class="ek-faiz">${ekYuzde(m.politika_faiz, 2)}</div>
        <div class="kucuk">Yıllık · reel faiz <b style="color:${reel >= 0 ? "var(--good)" : "var(--al2)"}">${reel >= 0 ? "+" : "−"}${ekYuzde(Math.abs(reel), 1)}</b></div>
        <p class="pz-not">${reelYazi}</p>
        <div class="br-izgara" style="margin-top:10px">
          <div class="br-kutu"><small>Enflasyon</small><b>${ekYuzde(m.enflasyon)}</b></div>
          <div class="br-kutu"><small>Büyüme</small><b>${ekYuzde(m.buyume)}</b></div>
          <div class="br-kutu"><small>30 gün vadeli mevduat</small><b>${ekYuzde(o.vadeli30, 2)}</b><span>dönem getirisi</span></div>
          <div class="br-kutu"><small>Kredi faizi</small><b>${ekYuzde(o.kredi, 2)}</b><span>aylık</span></div>
        </div>
        ${m.sonraki_karar ? `<p class="pz-not">Sonraki PPK toplantısı: ${tarihSaat(m.sonraki_karar)}</p>` : ""}</div>
      ${m.ben_baskan ? `<div class="kart"><h2>Para Politikası Kurulu kararı</h2>
        <p class="alt">Haftada bir karar verebilirsin; tek seferde en fazla 10 puan. Karar devlet bankasının mevduat ve kredi faizlerini hemen değiştirir, borsayı oynatır ve Resmî Gazete'de yayımlanır.</p>
        <div class="alan"><label>Yeni politika faizi (%)</label><input id="ekFaiz" type="number" min="0" max="100" step="0.25" value="${+m.politika_faiz}"></div>
        <div class="alan ek-alan"><label>Gerekçe (isteğe bağlı)</label><textarea id="ekGerekce" maxlength="500" placeholder="Enflasyondaki gidişat, büyüme, beklentiler…"></textarea></div>
        <button class="btn" onclick="ppkKarar()">Kararı açıkla</button></div>` : ""}
      ${m.ben_atayabilir ? `<div class="kart"><h2>Başkan ata</h2>
        <p class="alt">${e(m.yurutme_unvan || "Cumhurbaşkanı")} olarak başkanı sen atarsın. Aday teklifi kabul etmelidir ve aktif siyasi görevi olmamalıdır.</p>
        <div class="alan"><label>Oyuncu adı</label><input id="ekTcmbAday" type="text" autocomplete="off" placeholder="kullanıcı adı"></div>
        <button class="btn" onclick="tcmbAta()">Teklif gönder</button>
        ${m.baskan ? `<button class="btn tehlike" onclick="tcmbGorevdenAl()">Başkanı görevden al</button><p class="pz-not">Görevden alma piyasalarda güveni sarsar; borsa endeksi düşer.</p>` : ""}</div>` : ""}
      <div class="kart"><h2>Geçmiş kararlar</h2>${(m.kararlar || []).map(k => `<div class="pz-satir"><span class="sol"><b>${ekYuzde(k.onceki, 2)} → ${ekYuzde(k.yeni, 2)}</b>
          <span class="kucuk" style="display:block">${tarihSaat(k.zaman)} · ${e(k.baskan || "—")} · enflasyon ${ekYuzde(k.enflasyon)}</span>${k.gerekce ? `<span class="kucuk" style="display:block">${e(k.gerekce)}</span>` : ""}</span>
          <span class="sag"><b style="color:${+k.yeni > +k.onceki ? "var(--al2)" : +k.yeni < +k.onceki ? "var(--good)" : "var(--txt)"}">${+k.yeni > +k.onceki ? "▲" : +k.yeni < +k.onceki ? "▼" : "="} ${fmt(Math.abs(+k.yeni - +k.onceki), 2)}</b></span></div>`).join("")
        || '<p class="alt">Henüz PPK kararı yok.</p>'}</div>
      <div class="kart"><h2>Nasıl işler?</h2><p class="pz-not">${e(m.kural)}</p></div>`, { geri: true });
  } catch (err) { ekHata("Merkez Bankası", err); }
}
async function tcmbYanit(id, kabul){
  if (kabul && !await onayla("Merkez Bankası Başkanlığı", "Görevdeyken siyasi makam alamazsın. Kabul ediyor musun?", "Kabul et")) return;
  try { await API.rpc("tcmb_teklif_yanit", { p_teklif: id, p_kabul: kabul }); toast(kabul ? "Merkez Bankası Başkanı oldun." : "Teklif reddedildi."); merkezBankasiEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ppkKarar(){
  const f = Math.round((+$("#ekFaiz").value || 0) * 100) / 100, g = ($("#ekGerekce").value || "").trim();
  const eski = +(EK.mb || {}).politika_faiz;
  const yon = f > eski ? "yükseltilecek" : f < eski ? "indirilecek" : "sabit bırakılacak";
  if (!await onayla("PPK kararı", `Politika faizi %${fmt(eski, 2)} → %${fmt(f, 2)} (${yon}). Bir hafta değiştiremezsin.`, "Açıkla")) return;
  try { await API.rpc("ppk_faiz_karari", { p_faiz: f, p_gerekce: g || null }); toast("Faiz kararı açıklandı."); merkezBankasiEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function tcmbAta(){
  const k = ($("#ekTcmbAday").value || "").trim(); if (!k) return toast("Oyuncu adını yaz.", true);
  try { await API.rpc("tcmb_baskan_ata", { p_kad: k }); toast("Teklif gönderildi; aday kabul edince göreve başlar."); merkezBankasiEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function tcmbGorevdenAl(){
  if (!await onayla("Görevden alma", "Merkez Bankası Başkanı görevden alınacak. Borsa endeksi %2 düşer.", "Görevden al", true)) return;
  try { await API.rpc("tcmb_baskan_gorevden_al"); toast("Başkan görevden alındı."); merkezBankasiEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Belediye tahvilleri ---------------- */
async function belediyeTahvilEkrani(){
  yukleniyor("Belediye tahvilleri");
  try {
    const v = EK.tahvil = await API.rpc("belediye_tahvilleri");
    const b = v.belediyem, liste = v.tahviller || [];
    const satista = liste.filter(x => x.durum === "satista"), portfoy = liste.filter(x => +x.payim > 0);
    const kart = (x) => {
      const dolu = Math.min(100, (+x.toplanan / Math.max(1, +x.hedef)) * 100);
      return `<div class="kart"><div class="vit-bas"><span class="orta"><b>${e(x.il)} Belediyesi</b><span class="kucuk" style="display:block">${fmt(x.vade_gun)} gün vadeli · dönem getirisi ${ekYuzde(x.faiz, 2)} (yıllık ${ekYuzde(x.yillik)})</span></span>${ekDurum(x.durum)}</div>
        <div class="ek-cubuk"><i style="width:${dolu.toFixed(1)}%"></i></div>
        <div class="kv"><span>Toplanan / hedef</span><b>${ekTL(x.toplanan)} / ${ekTL(x.hedef)}</b></div>
        ${x.durum === "satista" ? `<div class="kv"><span>Satış bitişi</span><b>${tarihSaat(x.satis_bit)}</b></div>` : x.vade ? `<div class="kv"><span>Vade</span><b>${tarihSaat(x.vade)}</b></div>` : ""}
        ${+x.payim ? `<div class="kv"><span>Senin payın</span><b>${ekTL(x.payim)} → ${ekTL(Math.floor(+x.payim * (1 + +x.faiz / 100)))}</b></div>` : ""}
        ${x.durum === "temerrut" || x.durum === "odendi" ? `<div class="kv"><span>Yatırımcılara ödenen</span><b>${ekTL(x.odenen)}</b></div>` : ""}
        ${x.durum === "satista" && +x.toplanan < +x.hedef ? `<button class="btn yarim" onclick="tahvilAlModal(${x.id})">Tahvil al</button>` : ""}</div>`;
    };
    iskelet("Belediye tahvilleri", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${EK_IKON.tahvil}</span><div><h2>Belediyelere borç ver, faiz kazan</h2>
        <p class="alt">Belediye başkanları kasalarını güçlendirmek için tahvil çıkarır. Vadede paranı faiziyle geri alırsın; belediye kasası yetmezse temerrüde düşer ve alacağının yalnızca bir kısmı ödenir.</p></div></div>
        <p class="pz-not">${e(v.kural)} Politika faizi şu an ${ekYuzde(v.politika_faiz, 2)}.</p></div>
      ${b ? `<div class="kart"><h2>${e(b.il)} Belediyesi adına tahvil çıkar</h2>
        <p class="alt">Tek seferde en fazla ${ekTL(b.tavan)} (kasaya göre). Ödenmemiş toplam stok ${ekTL(b.acik_stok)}; sınır ${ekTL(+b.tavan * 2)}. Yıllık getiri en fazla ${ekYuzde(b.max_yillik_faiz)}.</p>
        <div class="alan"><label>Tutar (₺)</label><input id="ekThHedef" type="number" min="100000" step="10000" max="${+b.tavan}" value="${Math.min(+b.tavan, 100000)}"></div>
        <div class="alan"><label>Vade</label><div class="ek-sec" id="ekThVade">${[14, 30, 60].map(g => `<button type="button" data-g="${g}" class="${g === 30 ? "secili" : ""}">${g} gün</button>`).join("")}</div></div>
        <div class="alan"><label>Dönem getirisi (%)</label><input id="ekThFaiz" type="number" min="0.1" step="0.1" value="${fmt(Math.min(+v.politika_faiz + 5, +b.max_yillik_faiz) * 30 / 365, 1).replace(",", ".")}"></div>
        <p class="pz-not" id="ekThOzet"></p>
        <button class="btn" onclick="tahvilIhrac()">Tahvili ihraç et</button></div>` : ""}
      ${portfoy.length ? `<div class="bolum-bas"><h2>Tahvillerim</h2></div>${portfoy.map(kart).join("")}` : ""}
      <div class="bolum-bas"><h2>Satıştaki tahviller</h2></div>
      ${satista.filter(x => !+x.payim).map(kart).join("") || (satista.length ? "" : '<div class="kart"><p class="alt">Şu an satışta belediye tahvili yok.</p></div>')}
      ${liste.filter(x => x.durum !== "satista" && !+x.payim).length ? `<div class="bolum-bas"><h2>Son tahviller</h2></div>${liste.filter(x => x.durum !== "satista" && !+x.payim).map(kart).join("")}` : ""}`, { geri: true });
    if (b) {
      const ozet = () => {
        const h = +$("#ekThHedef").value || 0, f = +$("#ekThFaiz").value || 0, g = +($("#ekThVade .secili") || {}).dataset.g || 30;
        $("#ekThOzet").textContent = `Vadede ${ekTL(Math.round(h * (1 + f / 100)))} geri ödenecek. Yıllık karşılığı %${fmt(f * 365 / g, 1)}.`;
      };
      document.querySelectorAll("#ekThVade button").forEach(x => x.onclick = () => { document.querySelectorAll("#ekThVade button").forEach(y => y.classList.remove("secili")); x.classList.add("secili"); ozet(); });
      $("#ekThHedef").oninput = ozet; $("#ekThFaiz").oninput = ozet; ozet();
    }
  } catch (err) { ekHata("Belediye tahvilleri", err); }
}
async function tahvilIhrac(){
  const h = Math.round(+$("#ekThHedef").value || 0), f = Math.round((+$("#ekThFaiz").value || 0) * 100) / 100, g = +($("#ekThVade .secili") || {}).dataset.g || 30;
  if (!await onayla("Tahvil ihracı", `${ekTL(h)} · ${g} gün · %${fmt(f, 2)} getiri. Vadede belediye kasasından ${ekTL(Math.round(h * (1 + f / 100)))} ödenecek.`, "İhraç et")) return;
  try { await API.rpc("belediye_tahvil_ihrac", { p_hedef: h, p_faiz: f, p_vade_gun: g }); toast("Tahvil 48 saatliğine satışa çıktı."); belediyeTahvilEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
function tahvilAlModal(id){
  const x = ((EK.tahvil || {}).tahviller || []).find(z => z.id === id); if (!x) return;
  const kalan = +x.hedef - +x.toplanan;
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(x.il)} Belediyesi tahvili</h3>
    <p class="alt" style="margin-top:6px">${fmt(x.vade_gun)} gün vadeli, dönem getirisi %${fmt(x.faiz, 2)}. Kalan ${ekTL(kalan)}.</p>
    <div class="alan"><label>Tutar (₺)</label><input id="ekTaTutar" type="number" min="1000" step="1000" max="${kalan}" value="${Math.min(kalan, 10000)}"></div>
    <p class="pz-not" id="ekTaOzet"></p>
    <button class="btn" id="ekTaBtn">Satın al</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
  const ozet = () => { const t = +$("#ekTaTutar", m).value || 0; $("#ekTaOzet", m).textContent = `Vadede ${ekTL(Math.floor(t * (1 + +x.faiz / 100)))} alırsın (belediye ödeyebilirse).`; };
  $("#ekTaTutar", m).oninput = ozet; ozet();
  $("#ekTaBtn", m).onclick = async () => {
    const t = Math.round(+$("#ekTaTutar", m).value || 0);
    $("#ekTaBtn", m).disabled = true;
    try { await API.rpc("belediye_tahvil_al", { p_tahvil: id, p_tutar: t }); modalKapat(); toast("Tahvil alındı."); belediyeTahvilEkrani(); }
    catch (err) { $("#ekTaBtn", m).disabled = false; toast(hataCevir(err.message), true); }
  };
}

/* ---------------- SPK ---------------- */
async function spkEkrani(){
  yukleniyor("SPK");
  try {
    const v = EK.spk = await API.rpc("spk_ekrani");
    iskelet("Sermaye Piyasası Kurulu", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${EK_IKON.spk}</span><div><h2>Borsa gözetimi</h2>
        <p class="alt">SPK şüpheli işlemleri inceler. Şüphe veya ihbar suçun kanıtı değildir; ceza için gerçek işlem delili ve gerekçeli karar gerekir.</p></div></div>
        <p class="pz-not">${e(v.kural)}</p>
        ${v.yasagim ? `<p class="pz-not" style="color:var(--al2)">Borsa işlem yasağın ${tarihSaat(v.yasagim)} tarihine kadar sürüyor.</p>` : ""}</div>
      ${v.yetkili ? `<div class="kart"><h2>İnceleme başlat</h2><p class="alt">Hazine ve Maliye Bakanı olarak manipülasyon şüphesiyle inceleme açabilirsin. Bedel 0,5 milyar ₺ (bakanlık kasası). Günde en fazla 3.</p>
        <div class="alan"><label>Şirket</label><select id="ekSpkSirket">${(v.sirketler || []).map(s => `<option value="${s.id}">${e(s.ad)}</option>`).join("")}</select></div>
        <div class="alan"><label>Şüpheli oyuncu</label><input id="ekSpkKad" type="text" autocomplete="off" placeholder="kullanıcı adı"></div>
        <div class="alan ek-alan"><label>İddia</label><textarea id="ekSpkIddia" maxlength="500" placeholder="Ne gördün? Fiyat hareketi, zamanlama…"></textarea></div>
        <button class="btn" onclick="spkAc()">İncelemeyi başlat</button></div>` : ""}
      <div class="kart"><h2>İncelemeler</h2>${(v.incelemeler || []).map(x => {
        const delil = x.delil || {};
        return `<div class="pz-satir" style="align-items:flex-start"><span class="sol"><b>${e(x.sirket || "—")} · ${e(x.tur_ad)}</b>
          <span class="kucuk" style="display:block">${e(x.taraf1)}${x.taraf2 ? " ↔ " + e(x.taraf2) : ""} · ${e(x.acan)} · ${tarihSaat(x.bas)}</span>
          ${+x.tutar ? `<span class="kucuk" style="display:block">İncelenen işlem hacmi ${ekTL(x.tutar)} (tek başına kanıt değildir)</span>` : ""}
          ${x.iddia ? `<span class="kucuk" style="display:block">${e(x.iddia)}</span>` : ""}
          <span class="kucuk" style="display:block;color:${delil.yeterli ? "var(--good)" : "var(--al2)"}">${delil.yeterli ? "Doğrulanmış karşılıklı işlemler var; karar için ayrıca gerekçe gerekir." : "Ceza için somut karşılıklı işlem kanıtı bulunamadı."}</span>
          ${(delil.islemler || []).map(is => `<span class="kucuk" style="display:block">İşlem #${e(is.id)} · ${tarihSaat(is.zaman)} · ${e(is.satici)} → ${e(is.alici)} · ${ekTL(is.tutar)}</span>`).join("")}
          ${x.durum === "acik" ? `<span class="kucuk" style="display:block">Karar süresi: ${tarihSaat(x.bit)}</span>` : `<span class="kucuk" style="display:block">Kararı veren: ${e(x.karar_veren || "—")}${x.karar_zaman ? " · " + tarihSaat(x.karar_zaman) : ""}</span><span class="kucuk" style="display:block">Gerekçe: ${e(x.karar_not || "Önceki sistemde gerekçe kaydedilmemiş")}</span>`}
          ${v.yetkili && x.durum === "acik" && !x.taraf_benim ? `<span style="display:flex;gap:6px;margin-top:8px">${delil.yeterli ? `<button class="btn tehlike yarim" style="margin:0;padding:8px 12px" onclick="spkKarar(${x.id},true)">Gerekçeli ceza</button>` : ""}<button class="btn ikinci yarim" style="margin:0;padding:8px 12px" onclick="spkKarar(${x.id},false)">Cezasız kapat</button></span>` : ""}</span>
          <span class="sag">${ekDurum(x.durum)}${+x.ceza ? `<span class="kucuk" style="display:block">${ekTL(x.ceza)}</span>` : ""}</span></div>`;
      }).join("")
        || '<p class="alt">Henüz inceleme yok.</p>'}</div>`, { geri: true });
  } catch (err) { ekHata("SPK", err); }
}
async function spkAc(){
  const s = +$("#ekSpkSirket").value, k = ($("#ekSpkKad").value || "").trim(), i = ($("#ekSpkIddia").value || "").trim();
  if (!s || !k) return toast("Şirket ve oyuncu seç.", true);
  if (!await onayla("SPK incelemesi", `${e(k)} hakkında 72 saatlik inceleme başlayacak. Bakanlık kasasından 0,5 milyar ₺ çıkar.`, "Başlat")) return;
  try { await API.rpc("spk_inceleme_ac", { p_sirket: s, p_kad: k, p_aciklama: i }); toast("İnceleme başladı."); spkEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function spkKarar(id, ceza){
  const inceleme = ((EK.spk || {}).incelemeler || []).find(x => x.id === id);
  if (!inceleme) return toast("İnceleme bulunamadı.", true);
  const delil = inceleme.delil || {};
  if (ceza && !delil.yeterli) return toast("Somut borsa işlem kanıtı olmadan ceza verilemez.", true);
  const m = modal(`<h3 style="font-size:19px;font-weight:800">SPK #${id} · ${ceza ? "Ceza kararı" : "Cezasız kapatma"}</h3>
    <p class="alt" style="margin-top:8px">${e(inceleme.sirket)} · ${e(inceleme.taraf1)}. ${ceza ? "Sunucuda doğrulanan ters yönlü işlemler dışında hiçbir iddia tek başına kanıt sayılmaz. Ceza: doğrulanan hacmin %20'si (en az 10.000 ₺) ve 7 gün borsa yasağı." : "Dosya ceza verilmeksizin kapatılır."}</p>
    ${ceza ? `<p class="pz-not">İşlem numaraları: ${(delil.islem_idleri || []).map(x => "#" + e(x)).join(" ve ")} · Delil tutarı: ${ekTL(delil.toplam_tutar)}</p>` : ""}
    <div class="alan ek-alan"><label>Gerekçeli karar (zorunlu, en az 40 karakter)</label><textarea id="ekSpkKararNot" maxlength="500" placeholder="Hangi işlemler ne nedenle manipülasyon sayıldı veya neden ihlal bulunmadı? Somut açıklama yaz."></textarea></div>
    <p class="kucuk" id="ekSpkKararSayac">0 / 40 karakter</p>
    <button class="btn ${ceza ? "tehlike" : ""}" id="ekSpkKararOnay">${ceza ? "Gerekçeli ceza ver" : "Gerekçeyle kapat"}</button>
    <button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
  const alan = $("#ekSpkKararNot", m), sayac = $("#ekSpkKararSayac", m), btn = $("#ekSpkKararOnay", m);
  alan.oninput = () => { const n = alan.value.trim().length; sayac.textContent = `${n} / 40 karakter`; btn.disabled = n < 40; };
  alan.oninput();
  btn.onclick = async () => {
    const not = alan.value.trim();
    if (not.length < 40) return toast("En az 40 karakterlik somut karar gerekçesi yaz.", true);
    btn.disabled = true;
    try { await API.rpc("spk_karar", { p_id: id, p_ceza: ceza, p_not: not }); modalKapat(); toast("Gerekçeli karar kaydedildi."); spkEkrani(); }
    catch (err) { btn.disabled = false; toast(hataCevir(err.message), true); }
  };
}

/* ---------------- Konkordato ve iflas ---------------- */
async function konkordatoEkrani(){
  yukleniyor("Konkordato ve iflas");
  try {
    const v = EK.konk = await API.rpc("konkordato_ekrani");
    iskelet("Konkordato ve iflas", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${EK_IKON.konk}</span><div><h2>Batan şirketler</h2>
        <p class="alt">Zarar eden şirketlerin kasası eksiye düşer. Konkordato 14 günlük kurtarma süresidir; bu sürede ortaklar sermaye koymazsa şirket iflas eder.</p></div></div>
        <p class="pz-not">${e(v.kural)}</p></div>
      ${(v.riskli || []).length ? `<div class="kart"><h2>Zor durumdaki şirketlerim</h2>${v.riskli.map(s => `<div class="pz-satir"><span class="sol"><b>${e(s.ad)}</b>
          <span class="kucuk" style="display:block">Kasa ${ekTL(s.kasa)} · otomatik konkordato eşiği ${ekTL(s.otomatik_esik)}</span></span>
          <span class="sag">${s.surecte ? ekDurum("surec") : `<button class="btn altin yarim" style="margin:0;padding:8px 12px" onclick="konkordatoIlan(${s.id})">Konkordato ilan et</button>`}</span></div>`).join("")}
        <p class="pz-not">Kasayı artıya çekmek için Şirketlerim ekranından sermaye artırımı yap.</p>
        <button class="btn ikinci" onclick="ekranAc(sirketYonetimEkrani)">Şirketlerim</button></div>` : ""}
      <div class="kart"><h2>Süreçler</h2>${(v.surecler || []).map(k => `<div class="pz-satir"><span class="sol"><b>${e(k.sirket)}</b>
          <span class="kucuk" style="display:block">${k.durum === "surec" ? `Son gün ${tarihSaat(k.bit)} · kasa ${ekTL(k.kasa)}` : `${tarihSaat(k.sonuc_zaman || k.bit)} · başlangıç açığı ${ekTL(k.baslangic_kasa)}`}</span></span>
          <span class="sag">${ekDurum(k.durum)}</span></div>`).join("") || '<p class="alt">Şu an konkordatoda şirket yok.</p>'}</div>`, { geri: true });
  } catch (err) { ekHata("Konkordato ve iflas", err); }
}
async function konkordatoIlan(id){
  if (!await onayla("Konkordato", "Şirket 14 günlük konkordato sürecine girer ve bu Gündem'de duyurulur. Süre sonunda kasa hâlâ eksideyse şirket iflas eder.", "İlan et", true)) return;
  try { await API.rpc("sirket_konkordato_ilan", { p_sirket: id }); toast("Konkordato ilan edildi."); konkordatoEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Giriş noktaları ---------------- */
(function(){
  if (typeof iskelet !== "function") return;
  const eski = iskelet;
  window.iskelet = iskelet = function(baslik){
    const r = eski.apply(this, arguments);
    try {
      if (baslik === "Ekonomi merkezi") {
        const g = $(".br-git");
        if (g && !g.querySelector(".ek-ek")) g.insertAdjacentHTML("beforeend", `
          <button class="ek-ek" onclick="ekranAc(merkezBankasiEkrani)">${EK_IKON.banka}<span><b>Merkez Bankası</b><small>Politika faizi ve PPK kararları</small></span></button>
          <button class="ek-ek" onclick="ekranAc(belediyeTahvilEkrani)">${EK_IKON.tahvil}<span><b>Belediye tahvilleri</b><small>Belediyelere borç ver, faiz kazan</small></span></button>
          <button class="ek-ek" onclick="ekranAc(spkEkrani)">${EK_IKON.spk}<span><b>SPK</b><small>Borsa gözetimi ve cezalar</small></span></button>
          <button class="ek-ek" onclick="ekranAc(konkordatoEkrani)">${EK_IKON.konk}<span><b>Konkordato ve iflas</b><small>Batan şirketler</small></span></button>`);
      }
      if (baslik === "Şehir Yönetimi" && arguments[2] && /İller Bankası|Bütçe/.test(String(arguments[1] || ""))) {
        const ic = $("#icerik");
        if (ic && !ic.querySelector(".ek-ek")) ic.insertAdjacentHTML("beforeend", `<button class="btn ikinci ek-ek" onclick="ekranAc(belediyeTahvilEkrani)">Belediye tahvili çıkar</button>`);
      }
      if (baslik === "Borsa") { const ic = $("#icerik"); if (ic && !ic.querySelector(".ek-ek")) ic.insertAdjacentHTML("beforeend", `<button class="btn ikinci ek-ek" onclick="ekranAc(spkEkrani)">SPK gözetimi</button>`); }
    } catch (_) {}
    return r;
  };
})();
window.merkezBankasiEkrani = merkezBankasiEkrani;
window.belediyeTahvilEkrani = belediyeTahvilEkrani;
window.spkEkrani = spkEkrani;
window.konkordatoEkrani = konkordatoEkrani;
