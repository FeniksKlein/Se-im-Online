/* =====================================================================
   Ekonomi merkezi (piyasa raporu), borsa, Rekabet Kurumu, siyasi bağışlar.
   Arka uç: 85_ekonomi_borsa_rekabet.sql. Ortak yardımcılar ekonomi_pazar.js'ten (pzTL, PZ_IKON…).
   ===================================================================== */
"use strict";
const BR = { sirket: null };
const brTL = (x) => (typeof pzTL === "function" ? pzTL(x) : tlYaz(Math.round(+x || 0)));
const brYuzde = (a, b) => (+b ? ((+a - +b) / +b * 100) : 0);
const brDegisim = (a, b) => { const d = brYuzde(a, b); return !+b || Math.abs(d) < 0.05 ? `<span class="kucuk">değişmedi</span>` : `<span style="color:${d > 0 ? "var(--good)" : "var(--al2)"}">${d > 0 ? "▲" : "▼"} %${fmt(Math.abs(d), 1)}</span>`; };
const BR_IKON = {
  borsa: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3v18h18"/><path d="m7 15 4-4 3 3 6-7"/><path d="M15 7h5v5"/></svg>',
  terazi: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18M6 21h12M4 7h16M7 7l-3 6h6zM17 7l-3 6h6z"/></svg>',
  bagis: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 5.6-7 10-7 10z"/></svg>',
  rapor: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 17v-4M12 17V9M16 17v-6"/></svg>'
};
(function(){ const st = document.createElement("style"); st.textContent = `
.br-izgara{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-bottom:12px}
.br-kutu{background:var(--panel);border-radius:14px;padding:12px;min-width:0}
.br-kutu small{display:block;font-size:11px;color:var(--mut)}
.br-kutu b{display:block;font-family:var(--disp);font-size:22px;margin-top:4px;overflow-wrap:anywhere}
.br-kutu span{font-size:12px}
.br-git{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-bottom:12px}
.br-git button{display:flex;align-items:center;gap:10px;background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:12px;text-align:left;color:var(--txt);min-width:0}
.br-git button b{display:block;font-size:14.5px}.br-git button small{display:block;font-size:11.5px;color:var(--mut);line-height:1.3}
.br-git svg{flex:none;color:var(--ink2)}
.br-spark{width:100%;height:64px;display:block;margin-top:8px}
.br-cip{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:6px;vertical-align:middle}
`; document.head.appendChild(st); })();
function brHata(baslik, err){ iskelet(baslik, `<div class="kart">${e(hataCevir(err.message))}</div>`, { geri: true }); }
function brSpark(noktalar){
  const v = (noktalar || []).map(x => +x.fiyat || +x.net || 0);
  if (v.length < 2) return "";
  const en = Math.min(...v), ek = Math.max(...v), w = 300, h = 60, ad = (ek - en) || 1;
  const pts = v.map((y, i) => `${(i / (v.length - 1) * w).toFixed(1)},${(h - 4 - (y - en) / ad * (h - 8)).toFixed(1)}`).join(" ");
  return `<svg class="br-spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-hidden="true"><polyline points="${pts}" fill="none" stroke="var(--ink2)" stroke-width="2.5" vector-effect="non-scaling-stroke"/></svg>`;
}

/* ---------------- Ekonomi merkezi ---------------- */
async function ekonomiMerkeziEkrani(){
  yukleniyor("Ekonomi merkezi");
  try {
    const r = await API.rpc("piyasa_raporu");
    const endeksYazi = r.endeks < 0.97 ? "ucuz" : r.endeks > 1.03 ? "pahalı" : "dengeli";
    const g = r.benim_gecim;
    iskelet("Ekonomi merkezi", `
      <div class="br-izgara">
        <div class="br-kutu"><small>Piyasa fiyat endeksi</small><b>${fmt(r.endeks, 2)}</b><span>Market ve enerji ${endeksYazi}</span></div>
        <div class="br-kutu"><small>Enflasyon</small><b>%${fmt(r.enflasyon, 1)}</b><span>Büyüme %${fmt(r.buyume, 1)}</span></div>
        <div class="br-kutu"><small>${e(r.benim_il_ad)} geçim etkisi</small><b style="color:${g == null ? "var(--txt)" : g >= 0 ? "var(--good)" : "var(--al2)"}">${g == null ? "yok" : (g > 0 ? "−%" : "+%") + fmt(Math.abs(g), 1)}</b><span>${g == null ? "İlinde market ve enerji şirketi yok" : g >= 0 ? "Yerel piyasa geçimini ucuzlatıyor" : "Yerel piyasa geçimi pahalılaştırıyor"}</span></div>
        <div class="br-kutu"><small>Kurumlar vergisi (7 gün)</small><b>${brTL(r.kurumlar_7g)}</b><span>Ruhsat harcı ${brTL(r.ruhsat_7g)}</span></div>
      </div>
      <div class="br-git">
        <button onclick="ekranAc(belRuhsatMerkeziEkrani)">🏛️<span><b>Belediye yatırım ruhsatları</b><small>İnşaat, fabrika, market ve harç başvuruları</small></span></button>
        <button onclick="ekranAc(pazarMerkezEkrani)">${PZ_IKON.sirket}<span><b>Şirket kur</b><small>Okul, hastane, market, ulaşım, enerji</small></span></button>
        <button onclick="ekranAc(borsaEkrani)">${BR_IKON.borsa}<span><b>Borsa</b><small>${fmt(r.borsa.sirket)} şirket · ${brTL(r.borsa.deger)}</small></span></button>
        <button onclick="ekranAc(ihaleEkrani)">${PZ_IKON.ihale}<span><b>Kamu ihaleleri</b><small>${fmt(r.ihale.acik)} açık · ${fmt(r.ihale.yapim)} yapımda</small></span></button>
        <button onclick="ekranAc(rekabetEkrani)">${BR_IKON.terazi}<span><b>Rekabet Kurumu</b><small>Kartel ve tekel soruşturmaları</small></span></button>
        <button onclick="ekranAc(siyasiBagisEkrani)">${BR_IKON.bagis}<span><b>Siyasi bağışlar</b><small>Şirketlerin partilere bağışları</small></span></button>
        <button onclick="ekranAc(sirketVitrinEkrani)">${BR_IKON.rapor}<span><b>Şirket rehberi</b><small>Tüm şirketler, kâr ve vergi</small></span></button>
      </div>
      <div class="kart"><h2>Sektör liderleri</h2><p class="alt">Son 7 günde en çok kazanan rekabetçi şirketler.</p>
        ${(r.sektorler || []).map(s => `<div class="pz-satir"><span class="sol"><b>${e(s.ad)}</b> ${typeof pzPolRozet === "function" ? pzPolRozet(s.politika) : ""}<span class="kucuk" style="display:block">${s.lider ? `${e(s.lider.ad)} · ${e(s.lider.il)} · ${e(s.lider.sahip)}` : "Henüz rapor yok"}</span></span>
          <span class="sag">${s.lider ? `<b style="color:${pzRenk(s.lider.net)}">${pzIsaret(s.lider.net)}</b>` : ""}<span class="kucuk" style="display:block">${fmt(s.sayi)} şirket</span></span></div>`).join("")}
        <p class="pz-not">Eski türlerde ${fmt(r.eski_sayi)} şirket daha var.</p></div>
      ${(r.ucuz_iller || []).length || (r.pahali_iller || []).length ? `<div class="kart"><h2>Geçimin en ucuz ve en pahalı olduğu iller</h2><p class="alt">Market ve enerji şirketlerinin fiyatları o ilde yaşayan herkesin geçim masrafını değiştirir.</p>
        ${(r.ucuz_iller || []).map(x => `<div class="kv"><span>${e(x.il)}</span><b style="color:var(--good)">geçim −%${fmt(x.deger, 1)}</b></div>`).join("")}
        ${(r.pahali_iller || []).map(x => `<div class="kv"><span>${e(x.il)}</span><b style="color:var(--al2)">geçim +%${fmt(-x.deger, 1)}</b></div>`).join("")}</div>` : ""}
      ${(r.rekabet || []).length ? `<div class="kart"><h2>Son rekabet kararları</h2>${r.rekabet.map(x => `<div class="pz-satir"><span class="sol"><b>${e(x.il)} · ${e(x.sektor)}</b><span class="kucuk" style="display:block">${e(x.karar || "Soruşturma sürüyor")}</span></span><span class="sag">${x.durum === "ihlal" ? '<span class="rozet kirmizi">İhlal</span>' : x.durum === "temiz" ? '<span class="rozet yesil">Temiz</span>' : '<span class="rozet altin">Sürüyor</span>'}</span></div>`).join("")}</div>` : ""}
      ${(r.bagislar || []).length ? `<div class="kart"><h2>Son siyasi bağışlar</h2>${r.bagislar.map(x => `<div class="kv"><span><i class="br-cip" style="background:${e(x.renk || "#888")}"></i>${e(x.sirket)} → ${e(x.parti)}</span><b>${brTL(x.tutar)}</b></div>`).join("")}</div>` : ""}
      <div class="kart"><h2>Ekonomi nasıl işler?</h2>
        <p class="pz-not">Şirketler haftada bir hesaplanır; kârın %20'si kurumlar vergisi olarak hazineye gider. Bakanlar sektörlere teşvik ya da denetim uygular, belediye başkanları ruhsat harcı koyar ve ihale açar. Ticaret Bakanı Rekabet Kurumu'yla kartelleri cezalandırır. Ucuz ve rekabetçi market ile enerji ilinin geçimini ucuzlatır; pahalı tekel herkesi zorlar.</p></div>`, { geri: D.yigin.length > 0 });
  } catch (err) { brHata("Ekonomi merkezi", err); }
}

/* ---------------- Borsa ---------------- */
async function borsaEkrani(){
  yukleniyor("Borsa");
  try {
    const v = await API.rpc("borsa_liste");
    const liste = v.sirketler || [];
    const portfoy = liste.filter(s => +s.benim_pay > 0);
    iskelet("Borsa", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${BR_IKON.borsa}</span><div><h2>Halka açık şirketler</h2>
        <p class="alt">Halka arz edilmiş şirketlerin payları burada oyuncular arasında el değiştirir. Pay sahibi haftalık kârdan payı kadar alır.</p></div></div>
        <p class="pz-not">Fiyat "%1 pay" içindir. Şirketin fiyatı yeterli hacim, bağımsız yatırımcılar ve gerçek şirket verileriyle, 24 saatte en fazla %5 değişir. Şüpheli hacim fiyatı etkilemez. Alıcıdan %${fmt(v.komisyon, 1)} komisyon alınır ve hazineye gider. Şirketini borsaya açmak için "Şirketlerim"den halka arz yap.</p></div>
      ${portfoy.length ? `<div class="kart"><h2>Portföyüm</h2>${portfoy.map(s => `<div class="kv"><span>${e(s.ad)} · %${fmt(s.benim_pay, 2)}</span><b>${brTL(s.benim_pay * s.son)}</b></div>`).join("")}
        <p class="pz-not">Portföyün değeri onaylı piyasa fiyatıyla hesaplanır. Küçük pay işlemleri şirket değerini değiştirmez.</p></div>` : ""}
      ${liste.map(s => `<button class="kart vit-banka" onclick="ekranAc(()=>borsaSirketEkrani(${s.id}))">
        <div class="vit-bas"><span class="orta"><b>${e(s.ad)}</b><span class="kucuk" style="display:block">${e(typeof pzSektorAd === "function" ? pzSektorAd(s.sektor) : s.sektor)}${+s.benim_pay ? ` · payın %${fmt(s.benim_pay, 2)}` : ""}</span></span><span class="ok">›</span></div>
        <div class="vit-stats"><span><small>%1 pay</small><b>${brTL(s.son)}</b>${brDegisim(s.son, s.dun)}</span><span><small>Haftalık kâr (ort.)</small><b style="color:${pzRenk(s.haftalik_net)}">${brTL(s.haftalik_net)}</b></span><span><small>Satışta</small><b>${+s.satista ? "%" + fmt(s.satista, 2) : "yok"}</b></span></div></button>`).join("")
        || '<div class="kart"><p class="alt">Henüz halka açık şirket yok. İlk halka arzı sen yapabilirsin.</p></div>'}`, { geri: true });
  } catch (err) { brHata("Borsa", err); }
}
async function borsaSirketEkrani(id){
  yukleniyor("Borsa");
  try {
    const b = await API.rpc("borsa_sirket", { p_sirket: id });
    BR.sirket = b;
    const satilabilir = Math.max(0, +b.benim_pay - (+b.kilitli_pay || 0) - +b.benim_satista);
    const yillik = +b.haftalik_net * 52, deger = +b.son * 100;
    iskelet(e(b.ad), `
      <div class="kart"><h2>${e(b.ad)}</h2><p class="alt">${e(typeof pzSektorAd === "function" ? pzSektorAd(b.sektor) : b.sektor)}${b.aktif ? "" : ' · <span class="rozet kirmizi">İflas</span>'}</p>
        <div class="pz-net">${brTL(b.son)}</div><div class="kucuk">%1 pay · son 24 saat ${brDegisim(b.son, b.dun)}</div>
        ${brSpark(b.gunluk)}
        ${b.devre_kesici ? `<p class="pz-not" style="color:var(--al2)">⏸ Devre kesici etkin: işlemler ${e(new Date(b.devre_kesici).toLocaleTimeString("tr-TR", {hour:"2-digit",minute:"2-digit"}))} saatine kadar durduruldu.</p>` : ""}
        <p class="pz-not">Onaylanmış piyasa fiyatı esas alınır. Çok küçük ve şüpheli işlemler şirketin piyasa değerini değiştirmez.</p>
        <div class="pz-grid"><span><small>Piyasa değeri</small><b>${brTL(deger)}</b></span><span><small>Haftalık kâr (ort.)</small><b style="color:${pzRenk(b.haftalik_net)}">${brTL(b.haftalik_net)}</b></span><span><small>Fiyat / kazanç</small><b>${yillik > 0 ? fmt(deger / yillik, 1) + " yıl" : "kâr yok"}</b></span></div>
        <p class="pz-not">${+b.haftalik_net > 0 ? `%1 pay haftada yaklaşık ${brTL(b.haftalik_net / 100)} kâr payı getirir (şirket kârı dağıtıyorsa).` : "Şirket son haftalarda zarar ediyor; kâr payı ödenmiyor."}</p>
        ${typeof sirketRaporuEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(function(){return sirketRaporuEkrani(${Number(b.id)})})">Mali inceleme raporu · ciro, kâr marjı, sermaye</button>` : ""}</div>
      <div class="kart"><h2>Satış emirleri</h2>${(b.emirler || []).map(x => `<div class="pz-satir"><span class="sol"><b>%${fmt(x.kalan, 2)} pay · ${brTL(x.birim)}/%1</b><span class="kucuk" style="display:block">${e(x.satici)}${x.benim ? " (sen)" : ""} · toplam ${brTL(x.kalan * x.birim)}</span></span>
          <span class="sag">${x.benim ? `<button class="btn tehlike yarim" style="margin:0;padding:8px 12px" onclick="borsaIptal(${x.id})">İptal</button>` : b.aktif && !b.devre_kesici ? `<button class="btn yarim" style="margin:0;padding:8px 12px" onclick="borsaAlModal(${x.id})">Al</button>` : ""}</span></div>`).join("")
        || '<p class="alt">Şu an satışta pay yok.</p>'}</div>
      ${satilabilir > 0 && b.aktif && !b.devre_kesici ? `<div class="kart"><h2>Pay sat</h2><p class="alt">Sahip olduğun %${fmt(b.benim_pay, 2)}; son 24 saatte aldığın ve henüz satılamayan %${fmt(b.kilitli_pay || 0, 2)}; satışta %${fmt(b.benim_satista, 2)}.</p>
        <div class="alan"><label>Satılacak pay (%)</label><input id="brSatPay" type="number" min="0.1" max="${satilabilir}" step="0.1" value="${Math.min(satilabilir, 5)}"></div>
        <div class="alan"><label>%1 pay fiyatı (₺)</label><input id="brSatFiyat" type="number" min="${Math.max(100,Math.round(+b.son*0.90))}" max="${Math.round(+b.son*1.10)}" step="100" value="${Math.max(100, Math.round(+b.son / 100) * 100)}"></div>
        <button class="btn altin" onclick="borsaSat()">Satış emri ver</button></div>` : ""}
      <div class="kart"><h2>Son işlemler</h2>${(b.islemler || []).map(x => `<div class="kv"><span>${tarihSaat(x.zaman)} · %${fmt(x.pay, 2)}<span class="kucuk" style="display:block">${e(x.satici)} → ${e(x.alici)}</span></span><b>${brTL(x.birim)}</b></div>`).join("") || '<p class="alt">Henüz işlem olmadı.</p>'}</div>
      <div class="kart"><h2>Ortaklar</h2>${(b.ortaklar || []).map(o => `<div class="kv"><span>${e(o.kad)}</span><b>%${fmt(o.pay, 2)}</b></div>`).join("")}</div>`, { geri: true });
  } catch (err) { brHata("Borsa", err); }
}
function borsaAlModal(emir){
  const b = BR.sirket, x = (b.emirler || []).find(z => z.id === emir); if (!x) return;
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(b.ad)} payı al</h3>
    <p class="alt" style="margin-top:6px">%1 pay ${brTL(x.birim)}. Satışta %${fmt(x.kalan, 2)}. Cüzdanında ${brTL(b.cuzdan)}.</p>
    <div class="alan"><label>Alınacak pay (%)</label><input id="brAlPay" type="number" min="0.01" max="${x.kalan}" step="0.01" value="${Math.min(+x.kalan, 1)}"></div>
    <p class="pz-not" id="brAlOzet"></p>
    <button class="btn" id="brAlBtn">Satın al</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
  const ozet = () => { const p = +$("#brAlPay", m).value || 0, t = Math.round(p * x.birim), k = Math.round(t * (+b.komisyon || 0.5) / 100);
    $("#brAlOzet", m).textContent = `Tutar ${brTL(t)} + komisyon ${brTL(k)} = ${brTL(t + k)}. Haftalık kâr payı yaklaşık ${brTL(b.haftalik_net * p / 100)}.`; };
  $("#brAlPay", m).oninput = ozet; ozet();
  $("#brAlBtn", m).onclick = async () => {
    const p = Math.round((+$("#brAlPay", m).value || 0) * 100) / 100;
    $("#brAlBtn", m).disabled = true;
    try { await API.rpc("borsa_al", { p_emir: emir, p_pay: p }); modalKapat(); toast(`%${fmt(p, 2)} pay alındı.`); borsaSirketEkrani(b.id); }
    catch (err) { $("#brAlBtn", m).disabled = false; toast(hataCevir(err.message), true); }
  };
}
async function borsaSat(){
  const b = BR.sirket, p = Math.round((+$("#brSatPay").value || 0) * 100) / 100, f = Math.round(+$("#brSatFiyat").value || 0);
  try { await API.rpc("borsa_sat", { p_sirket: b.id, p_pay: p, p_birim: f }); toast("Satış emrin borsada."); borsaSirketEkrani(b.id); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function borsaIptal(emir){
  try { await API.rpc("borsa_iptal", { p_emir: emir }); toast("Emir iptal edildi."); borsaSirketEkrani(BR.sirket.id); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Rekabet Kurumu ---------------- */
async function rekabetEkrani(){
  yukleniyor("Rekabet Kurumu");
  try {
    const v = await API.rpc("rekabet_ekrani");
    BR.rekabet = v;
    const durumRozet = (d) => d === "ihlal" ? '<span class="rozet kirmizi">İhlal</span>' : d === "temiz" ? '<span class="rozet yesil">Temiz</span>' : '<span class="rozet altin">Sürüyor</span>';
    iskelet("Rekabet Kurumu", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${BR_IKON.terazi}</span><div><h2>Kartele ve tekele karşı</h2>
        <p class="alt">Ticaret Bakanı bir ildeki bir pazar için 24 saatlik soruşturma açar. Karar otomatik çıkar ve Resmî Gazete'de yayımlanır.</p></div></div>
        <div class="kv"><span>Kartel</span><b>İldeki tüm rakipler premium fiyatta</b></div>
        <div class="kv"><span>Hâkim durum</span><b>Tek şirket %55+ pay ve premium</b></div>
        <div class="kv"><span>Paravan yapı</span><b>Aynı kişinin birden çok şirketi</b></div>
        <p class="pz-not">Ceza: şirket kasasının %8'i hazineye; fiyat ortaya çekilir. Şirket sahibi soruşturma açılınca bildirim alır ve 24 saat içinde fiyatını düşürebilir.</p></div>
      ${v.yetkili ? `<div class="kart"><h2>Soruşturma aç</h2><p class="alt">Bedel ${fmt(v.bedel, 1)} milyar ₺, Ticaret Bakanlığı kasasından (kasada ${fmt(v.kasa, 2)} milyar ₺). Günde en fazla 3.</p>
        <div class="alan"><label>İl</label><select id="rkIl">${[...VERI.iller].sort((a, b) => a.ad.localeCompare(b.ad, "tr")).map(i => `<option value="${i.id}">${e(i.ad)}</option>`).join("")}</select></div>
        <div class="alan"><label>Pazar</label><select id="rkSektor">${(v.sektorler || []).map(s => `<option value="${s.kod}">${e(s.ad)}</option>`).join("")}</select></div>
        <button class="btn" onclick="rekabetAc()">Soruşturmayı başlat</button></div>` : ""}
      <div class="kart"><h2>Premium fiyatlı pazarlar</h2><p class="alt">Premium fiyat uygulayan şirketlerin bulunduğu pazarlar.</p>
        ${(v.riskli || []).map(z => `<div class="pz-satir"><span class="sol"><b>${e(z.il)} · ${e(z.sektor_ad)}</b><span class="kucuk" style="display:block">${fmt(z.firma)} şirket · ${fmt(z.sahip)} sahip${z.hepsi_premium && z.firma > 1 ? " · hepsi premium" : ""}</span></span>
          ${v.yetkili ? `<span class="sag"><button class="btn altin yarim" style="margin:0;padding:8px 12px" onclick="rekabetAc(${z.il_id},'${z.sektor}')">Soruştur</button></span>` : ""}</div>`).join("") || '<p class="alt">Premium fiyatlı pazar yok.</p>'}</div>
      <div class="kart"><h2>Soruşturmalar</h2>${(v.sorusturmalar || []).map(x => `<div class="pz-satir"><span class="sol"><b>${e(x.il)} · ${e(x.sektor)}</b>
          <span class="kucuk" style="display:block">${e(x.karar || `Karar ${tarihSaat(x.bit)}`)} · açan ${e(x.acan)}</span></span><span class="sag">${durumRozet(x.durum)}${+x.ceza ? `<span class="kucuk" style="display:block">${brTL(x.ceza)}</span>` : ""}</span></div>`).join("")
        || '<p class="alt">Henüz soruşturma açılmadı.</p>'}</div>`, { geri: true });
  } catch (err) { brHata("Rekabet Kurumu", err); }
}
async function rekabetAc(il, sektor){
  il = il || +$("#rkIl").value; sektor = sektor || $("#rkSektor").value;
  const sad = ((BR.rekabet || {}).sektorler || []).find(s => s.kod === sektor);
  if (!await onayla("Rekabet soruşturması", `${e(ilAd(il))} · ${e(sad ? sad.ad : sektor)} pazarı 24 saat incelenecek. Bakanlık kasasından 0,5 milyar ₺ çıkar.`, "Başlat")) return;
  try { await API.rpc("rekabet_ac", { p_il: il, p_sektor: sektor }); toast("Soruşturma başladı; karar 24 saat sonra."); rekabetEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Siyasi bağışlar ---------------- */
async function siyasiBagisEkrani(){
  yukleniyor("Siyasi bağışlar");
  try {
    const v = await API.rpc("siyasi_bagislar");
    iskelet("Siyasi bağışlar", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${BR_IKON.bagis}</span><div><h2>Şeffaf siyasi finansman</h2>
        <p class="alt">Şirketler partilere bağış yapabilir; her bağış herkesin görebileceği bu listede ve Gündem akışında yayımlanır.</p></div></div>
        <p class="pz-not">Bir şirket 7 günde en fazla sermayesinin %20'si kadar bağış yapabilir. Bankalar bağış yapamaz. Bağışı şirketin en büyük ortağı yapar; para şirket kasasından çıkar.</p></div>
      ${(v.sirketlerim || []).length ? `<div class="kart"><h2>Şirketin adına bağış yap</h2>
        <div class="alan"><label>Şirket</label><select id="sbSirket">${v.sirketlerim.map(s => `<option value="${s.id}">${e(s.ad)} · kalan sınır ${brTL(s.kalan)}</option>`).join("")}</select></div>
        <div class="alan"><label>Parti</label><select id="sbParti">${(v.partiler || []).map(p => `<option value="${p.id}">${e(p.ad)} (${e(p.kisa)})</option>`).join("")}</select></div>
        <div class="alan"><label>Tutar (₺)</label><input id="sbTutar" type="number" min="1000" step="1000" value="10000"></div>
        <button class="btn" onclick="siyasiBagisYap()">Bağışı yap ve yayımla</button></div>` : ""}
      <div class="kart"><h2>Son 30 gün, parti parti</h2>${(v.parti_toplam || []).map(x => `<div class="kv"><span><i class="br-cip" style="background:${e(x.renk || "#888")}"></i>${e(x.parti)}<span class="kucuk" style="display:block">${fmt(x.sirket)} şirketten</span></span><b>${brTL(x.tutar)}</b></div>`).join("") || '<p class="alt">Son 30 günde şirket bağışı yok.</p>'}</div>
      <div class="kart"><h2>Tüm bağışlar</h2>${(v.son || []).map(x => `<div class="pz-satir"><span class="sol"><b>${e(x.sirket)} → ${e(x.kisa)}</b><span class="kucuk" style="display:block">${e(x.veren)} · ${tarihSaat(x.zaman)}</span></span><span class="sag"><b>${brTL(x.tutar)}</b></span></div>`).join("") || '<p class="alt">Henüz bağış yok.</p>'}</div>`, { geri: true });
  } catch (err) { brHata("Siyasi bağışlar", err); }
}
async function siyasiBagisYap(){
  const sirket = +$("#sbSirket").value, parti = +$("#sbParti").value, tutar = Math.round(+$("#sbTutar").value || 0);
  const pAd = $("#sbParti").selectedOptions[0].textContent;
  if (!await onayla("Siyasi bağış", `${brTL(tutar)} şirket kasasından ${e(pAd)} kasasına geçecek ve herkese açık yayımlanacak.`, "Bağışla")) return;
  try { await API.rpc("sirket_parti_bagis", { p_sirket: sirket, p_parti: parti, p_tutar: tutar }); toast("Bağış yapıldı ve yayımlandı."); siyasiBagisEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Giriş noktaları ---------------- */
(function(){
  if (typeof iskelet !== "function") return;
  const eski = iskelet;
  window.iskelet = iskelet = function(baslik){
    const r = eski.apply(this, arguments);
    try {
      if (baslik === "Hayat") { const g = $(".vit-ana-izgara"); if (g && !g.querySelector(".br-ek")) g.insertAdjacentHTML("afterbegin", `<button class="vit-ana-kart br-ek" onclick="ekranAc(ekonomiMerkeziEkrani)"><span class="vit-ikon" style="color:var(--ink2)">${BR_IKON.rapor}</span><b>Ekonomi merkezi</b><span>Piyasa raporu, borsa, şirketler, ihaleler, Rekabet Kurumu</span></button>`); }
      if (baslik === "Rekabetçi şirketler" || baslik === "Kamu ihaleleri") { const ic = $("#icerik"); if (ic && !ic.querySelector(".br-ek")) ic.insertAdjacentHTML("beforeend", `<button class="btn ikinci br-ek" onclick="ekranAc(ekonomiMerkeziEkrani)">Ekonomi merkezi</button>`); }
    } catch (_) {}
    return r;
  };
})();
window.ekonomiMerkeziEkrani = ekonomiMerkeziEkrani;
window.borsaEkrani = borsaEkrani;
window.rekabetEkrani = rekabetEkrani;
window.siyasiBagisEkrani = siyasiBagisEkrani;
