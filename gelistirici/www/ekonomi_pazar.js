/* =====================================================================
   Rekabetçi şirketler, kamu ihaleleri, sektör politikası. Arka uç: 84_ekonomi_pazar_ihale.sql
   Şirket bir ilde faaliyet gösterir; sahibi fiyat ve kalite seçer, pazarı aynı ildeki
   rakiplerle paylaşır. Belediye başkanı ve bakanlar ihale açar, inşaat şirketleri teklif verir.
   ===================================================================== */
"use strict";
const PZ = { ihaleSekme: "acik", detay: null, secim: {} };
const PZ_FIYAT = { 1: "Ucuz", 2: "Orta", 3: "Premium" };
const PZ_KALITE = { 0: "Asgari", 1: "Standart", 2: "İyi", 3: "Üst düzey" };
const PZ_KAYNAK = { komur: "Kömür", dogalgaz: "Doğalgaz", yenilenebilir: "Güneş ve rüzgâr" };
const PZ_POL = { normal: "Normal", tesvik: "Teşvikte", denetim: "Sıkı denetimde" };
const PZ_YONTEM = {
  standart: { ad: "Standart yapım", oran: 0.70, not: "Şartnameye uygun iş. Etki tam." },
  kaliteli: { ad: "Kaliteli yapım", oran: 0.85, not: "Daha pahalı; etki %35 fazla, şirket iş deneyimi puanı kazanır." },
  tasarruflu: { ad: "Tasarruflu yapım", oran: 0.55, not: "Ucuz malzeme; kâr artar ama etki düşer. Denetimde yakalanırsa hakedişin yarısı ödenmez, %20 ceza ve 14 gün ihale yasağı." }
};
const PZ_IKON = {
  sirket: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18M5 21V8l5-3v16M10 21V3l9 4v14"/><path d="M13 9h3M13 13h3M13 17h3"/></svg>',
  ihale: '<svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="m14 13-7.5 7.5a2.1 2.1 0 0 1-3-3L11 10"/><path d="m16 16 6-6M8 8l6-6M9 7l8 8M21 11l-8-8"/></svg>'
};
const pzTL = (x) => tlYaz(Math.round(Number(x) || 0));
const pzIsaret = (x) => (Number(x) > 0 ? "+" : "") + pzTL(x);
const pzRenk = (x) => Number(x) >= 0 ? "var(--good)" : "var(--al2)";
const pzMilyar = (x) => fmt(Number(x) || 0, 2) + " milyar ₺";
(function(){ const st = document.createElement("style"); st.textContent = `
.pz-bas{display:flex;align-items:center;gap:12px}
.pz-logo{width:46px;height:46px;border-radius:12px;background:var(--inkbg);color:var(--ink2);display:grid;place-items:center;flex:none}
.pz-net{font-family:var(--disp);font-size:30px;font-weight:700;line-height:1.1;margin-top:4px}
.pz-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px;margin-top:12px}
.pz-grid span{background:var(--bg);border-radius:9px;padding:9px 7px;min-width:0}
.pz-grid small{display:block;font-size:10.5px;color:var(--mut)}
.pz-grid b{display:block;font-size:14px;margin-top:4px;overflow-wrap:anywhere}
.pz-secim{display:grid;grid-template-columns:repeat(var(--n,3),minmax(0,1fr));gap:6px;margin-top:6px}
.pz-secim button{padding:10px 4px;border-radius:10px;background:var(--panel2);font-weight:700;font-size:13.5px;border:1.5px solid transparent;color:var(--txt)}
.pz-secim button.aktif{border-color:var(--ink2);color:var(--ink2)}
.pz-secim button small{display:block;font-size:11px;font-weight:600;margin-top:3px}
.pz-tablo{width:100%;border-collapse:collapse;font-size:13px}
.pz-tablo th,.pz-tablo td{padding:7px 4px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}
.pz-tablo th:first-child,.pz-tablo td:first-child{text-align:left}
.pz-tablo td.on{color:var(--ink2);font-weight:800}
.pz-satir{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:11px 0;border-bottom:1px solid var(--line);width:100%;text-align:left;color:var(--txt)}
.pz-satir:last-child{border-bottom:0}
.pz-satir .sol{min-width:0}
.pz-satir .sag{text-align:right;flex:none}
.pz-cubuk{height:6px;border-radius:3px;background:var(--bg);overflow:hidden;margin-top:6px}
.pz-cubuk i{display:block;height:100%;background:var(--ink2)}
.pz-not{font-size:12.5px;color:var(--mut);margin-top:6px;line-height:1.45}
.pz-kaydir{overflow-x:auto}
`; document.head.appendChild(st); })();

function pzHata(baslik, err){ iskelet(baslik, `<div class="kart">${e(hataCevir(err.message))}</div>`, { geri: true }); }
function pzPolRozet(d){ return d === "tesvik" ? `<span class="rozet yesil">Teşvikte</span>` : d === "denetim" ? `<span class="rozet sari">Sıkı denetim</span>` : ""; }

/* ---------------- Rekabetçi şirketler merkezi ---------------- */
async function pazarMerkezEkrani(){
  yukleniyor("Rekabetçi şirketler");
  try {
    const k = await API.rpc("pazar_katalog");
    PZ.katalog = k;
    iskelet("Rekabetçi şirketler", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${PZ_IKON.sirket}</span><div><h2>Kendi işini kur, rakiplerinle yarış</h2>
        <p class="alt">Şirketin seçtiğin ilde faaliyet gösterir. O ilin pazarını aynı türdeki oyuncu şirketleriyle paylaşırsın: boş ilde kazanırsın, kalabalık ilde fiyat savaşı zarar ettirir.</p></div></div>
        <p class="pz-not">Fiyatını ve kaliteni sen seçersin. Haftalık kâr ortaklara ödenir, %${fmt(k.kurumlar)} kurumlar vergisi hazineye, belediyenin ruhsat harcı il kasasına gider. Kasası biten şirket iflas eder.</p></div>
      <div class="kart"><h2>Üç adımda şirket</h2>
        <div class="kv"><span>1. Aşağıdan şirket türünü seç</span><b>Okul, hastane, market…</b></div>
        <div class="kv"><span>2. Haritadan rakibi az ili seç</span><b>Fırsat çubuğu</b></div>
        <div class="kv"><span>3. Kurduktan sonra otopilotu aç</span><b>İstersen</b></div>
        <p class="pz-not">Otopilot her hafta en kârlı fiyat ve kaliteyi kendisi seçer (gelirin %4'ü yönetici ücreti). İstersen kararları kendin verirsin; danışman her zaman en iyi ayarı önerir.</p>
        ${typeof ekonomiMerkeziEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(ekonomiMerkeziEkrani)">Ekonomi merkezi ve piyasa raporu</button>` : ""}</div>
      <div class="bolum-bas"><h2>Şirketlerim</h2></div>
      <div class="kart">${(k.sirketlerim || []).map(s => `<button class="pz-satir" onclick="ekranAc(()=>pazarDetayEkrani(${s.id}))">
          <span class="sol"><b>${e(s.ad)}</b><span class="kucuk" style="display:block">${e(pzSektorAd(s.sektor))} · ${e(s.il)} · Payın %${fmt(s.pay, 1)}</span></span>
          <span class="sag">${s.aktif ? `<b>${pzTL(s.kasa)}</b><span class="kucuk" style="display:block">kasa</span>` : `<span class="rozet kirmizi">İflas</span>`}</span></button>`).join("")
        || '<p class="alt">Henüz rekabetçi şirketin yok. Aşağıdan bir tür seç, haritadan ilini belirle.</p>'}</div>
      <div class="bolum-bas"><h2>Şirket türleri</h2><span class="kucuk">Dokun, il seç</span></div>
      ${(k.sektorler || []).map(s => `<button class="kart vit-banka" onclick="ekranAc(()=>pazarHaritaEkrani('${s.kod}'))">
          <div class="vit-bas"><span class="orta"><b>${e(s.ad)}</b> ${pzPolRozet(s.politika)}<span class="kucuk" style="display:block">${e(s.aciklama)}</span></span><span class="ok">›</span></div>
          <div class="vit-stats"><span><small>Asgari sermaye</small><b>${pzTL(s.min_sermaye)}</b></span><span><small>Oyundaki şirket</small><b>${fmt(s.sirket_sayisi)}</b></span><span><small>Politikayı belirleyen</small><b>${e(s.bakan || "Cumhurbaşkanı (vekâleten)")}</b></span></div></button>`).join("")}
      <div class="kart"><h2>Eski türlere sektör politikası</h2><p class="alt">Tarım, sanayi, teknoloji, ticaret ve inşaat şirketlerinin kazancı da bakanların teşvik (+%15) ve denetim (−%8) kararlarından etkilenir.</p>
        ${(k.eski_politikalar || []).map(x => `<div class="kv"><span>${e(x.ad)}</span><b>${PZ_POL[x.politika]}</b></div>`).join("")}</div>
      <button class="btn ikinci" onclick="ekranAc(ihaleEkrani)">Kamu ihaleleri</button>`, { geri: true });
  } catch (err) { pzHata("Rekabetçi şirketler", err); }
}
function pzSektorAd(kod){
  const s = ((PZ.katalog || {}).sektorler || []).find(x => x.kod === kod);
  return s ? s.ad : (typeof vitSektor === "object" && vitSektor[kod]) || kod;
}

/* ---------------- Pazar haritası: hangi ilde fırsat var? ---------------- */
async function pazarHaritaEkrani(sektor){
  yukleniyor("Pazar haritası");
  try {
    if (!PZ.katalog) PZ.katalog = await API.rpc("pazar_katalog");
    const h = await API.rpc("pazar_harita", { p_sektor: sektor });
    PZ.harita = h;
    const s = (PZ.katalog.sektorler || []).find(x => x.kod === sektor) || {};
    const enIyi = Math.max(1, ...(h.iller || []).map(x => +x.firsat));
    iskelet(e(h.ad), `
      <div class="kart"><h2>${e(h.ad)} için il seç</h2><p class="alt">${e(s.aciklama || "")}</p>
        <p class="pz-not">Haftalık pazar, ilin nüfusuna ve gelişmişliğine göre o ilde bu tür hizmete harcanan toplam paradır. Rakip sayısı arttıkça payın küçülür. Büyük ilde kazanmak için kapasite (sermaye) gerekir; küçük ilde büyük sermayenin giderleri ağır gelir.</p>
        ${pzPolRozet(s.politika)}</div>
      <div class="alan"><input id="pzIlAra" placeholder="İl ara" oninput="pazarHaritaSuz()"></div>
      <div class="kart" id="pzIlListe">${pazarHaritaSatirlar(h.iller, enIyi, sektor)}</div>`, { geri: true });
  } catch (err) { pzHata("Pazar haritası", err); }
}
function pazarHaritaSatirlar(iller, enIyi, sektor){
  return iller.map(i => `<button class="pz-satir" data-il="${e(i.il.toLocaleLowerCase("tr"))}" onclick="pazarKurModal('${sektor}',${i.il_id})">
    <span class="sol" style="flex:1"><b>${e(i.il)}</b>${i.benim ? ' <span class="rozet">İlin</span>' : ""}
      <span class="kucuk" style="display:block">Pazar ${pzTL(i.pazar)}/hafta · ${i.rakip ? fmt(i.rakip) + " rakip" : "rakip yok"}${+i.ruhsat ? ` · harç %${fmt(i.ruhsat, 1)}` : ""}</span>
      <span class="pz-cubuk"><i style="width:${Math.max(4, Math.round(100 * i.firsat / enIyi))}%"></i></span></span>
    <span class="ok">›</span></button>`).join("");
}
function pazarHaritaSuz(){
  const a = ($("#pzIlAra").value || "").toLocaleLowerCase("tr").trim();
  document.querySelectorAll("#pzIlListe .pz-satir").forEach(b => { b.style.display = !a || b.dataset.il.includes(a) ? "" : "none"; });
}
function pazarKurModal(sektor, ilId){
  const s = ((PZ.katalog || {}).sektorler || []).find(x => x.kod === sektor) || {};
  const il = ((PZ.harita || {}).iller || []).find(x => x.il_id === ilId) || {};
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(il.il)} · ${e(s.ad)}</h3>
    <p class="alt" style="margin-top:6px">Haftalık pazar ${pzTL(il.pazar)}, ${il.rakip ? fmt(il.rakip) + " rakip var" : "henüz rakip yok"}. Sermaye cüzdanından çıkar ve şirket kasası olur.</p>
    <div class="alan"><label>Şirket adı</label><input id="pzAd" maxlength="50" placeholder="Örn. ${e(il.il)} ${e(s.ad)}"></div>
    <div class="alan"><label>Kuruluş sermayesi (₺)</label><input id="pzSermaye" type="number" min="${s.min_sermaye}" step="1000" value="${s.min_sermaye}"></div>
    ${sektor === "enerji" ? `<div class="alan"><label>Enerji kaynağı</label><select id="pzKaynak">${Object.entries(PZ_KAYNAK).map(([k, a]) => `<option value="${k}" ${k === "dogalgaz" ? "selected" : ""}>${a}</option>`).join("")}</select>
      <p class="pz-not">Kömür ucuzdur ama ilin memnuniyetini düşürür ve sıkı denetimde ceza yer. Doğalgazın maliyeti dolar kuruna bağlıdır. Güneş ve rüzgâr pahalıdır ama markanı ve ilin gelişimini büyütür.</p></div>` : ""}
    <p class="pz-not">Sermaye arttıkça kapasite ve personel gideri birlikte artar. Kurduktan sonra fiyatını, kaliteni ve ilini değiştirebilirsin.</p>
    <button class="btn" id="pzKurBtn">Şirketi kur</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>`);
  $("#pzKurBtn", m).onclick = async () => {
    const ad = $("#pzAd", m).value.trim(), ser = Number($("#pzSermaye", m).value), b = $("#pzKurBtn", m);
    if (ad.length < 3 || ad.length > 50) { toast("Şirket adı 3-50 karakter olmalı.", true); return; }
    if (!Number.isSafeInteger(ser) || ser < s.min_sermaye) { toast(`En az ${pzTL(s.min_sermaye)} sermaye gerekir.`, true); return; }
    b.disabled = true;
    try {
      const r = await API.rpc("pazar_sirket_kur", { p_ad: ad, p_sektor: sektor, p_sermaye: ser, p_il: ilId, p_kaynak: sektor === "enerji" ? $("#pzKaynak", m).value : null });
      modalKapat(); toast("Şirket kuruldu.");
      if (typeof durumYenile === "function") durumYenile().catch(() => {});
      ekranAc(() => pazarDetayEkrani(r.id));
    } catch (err) { b.disabled = false; toast(hataCevir(err.message), true); }
  };
}

/* ---------------- Şirket yönetimi ---------------- */
async function pazarDetayEkrani(id){
  yukleniyor("Şirket");
  try {
    const [d, dn] = await Promise.all([API.rpc("pazar_detay", { p_sirket: id }), API.rpc("pazar_danisman", { p_sirket: id }).catch(() => null)]);
    PZ.detay = d; PZ.danisman = dn; PZ.secim = { fiyat: d.fiyat, kalite: d.kalite, kaynak: d.kaynak };
    const t = d.tahmin || {};
    iskelet(e(d.ad), `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${PZ_IKON.sirket}</span><div style="min-width:0"><h2>${e(d.ad)}</h2>
        <p class="alt">${e(d.sektor_ad)} · ${e(d.il)} · ${d.hafta ? fmt(d.hafta) + ". hafta" : "yeni açıldı"}</p></div></div>
        ${d.aktif ? `<div class="pz-grid"><span><small>Şirket kasası</small><b>${pzTL(d.kasa)}</b></span><span><small>Sermaye</small><b>${pzTL(d.sermaye)}</b></span><span><small>Marka</small><b>${fmt(d.marka)} / 100</b></span></div>
        <p class="pz-not">Sonraki haftalık hesap: ${tarihSaat(d.sonraki)}${d.kasa < d.sermaye * 0.25 ? ' · <b style="color:var(--al2)">Kasa eriyor, iflas riski var.</b>' : ""}</p>` : `<p class="alt" style="margin-top:8px"><span class="rozet kirmizi">İflas etti</span> Kasası tükendiği için faaliyet durdu.</p>`}</div>
      ${d.aktif && dn ? pazarYonetimKart(d, dn) : ""}
      ${d.aktif ? `<div class="kart"><h2>Bu haftanın tahmini</h2><p class="alt">Bugünkü ayarlarınla ve rakiplerinle hesaplanır. Gerçek sonuç %10 oynayabilir.</p>
        <div class="pz-net" style="color:${pzRenk(t.net)}">${pzIsaret(t.net)}</div><div class="kucuk">net / hafta · sermayenin %${fmt(t.getiri, 1)}'i</div>
        <div class="kv"><span>Pazardaki payın</span><b>%${fmt(t.pay, 1)} · ${t.rakip ? fmt(t.rakip) + " rakip" : "rakipsiz"}</b></div>
        <div class="kv"><span>İlin haftalık pazarı</span><b>${pzTL(t.pazar)}</b></div>
        <div class="kv"><span>Gelir</span><b>${pzTL(t.gelir)}${t.kapasite_dolu ? ' <span class="rozet sari">Kapasite dolu</span>' : ""}</b></div>
        <div class="kv"><span>Sabit gider + personel</span><b>${pzTL(t.gider - t.kalite_gider - t.kaynak_gider)}</b></div>
        ${t.kalite_gider ? `<div class="kv"><span>Kalite bütçesi</span><b>${pzTL(t.kalite_gider)}</b></div>` : ""}
        ${t.kaynak_gider ? `<div class="kv"><span>Yakıt (dolara bağlı)</span><b>${pzTL(t.kaynak_gider)}</b></div>` : ""}
        ${t.ruhsat ? `<div class="kv"><span>Belediye ruhsat harcı (%${fmt(t.ruhsat_oran, 1)})</span><b>${pzTL(t.ruhsat)}</b></div>` : ""}
        ${t.ceza ? `<div class="kv"><span>Sıkı denetim cezası</span><b style="color:var(--al2)">${pzTL(t.ceza)}</b></div>` : ""}
        <div class="kv"><span>Kurumlar vergisi</span><b>${pzTL(t.vergi)}</b></div>
        ${t.politika !== "normal" ? `<p class="pz-not">${e(d.sektor_ad)} sektörü şu an ${PZ_POL[t.politika].toLocaleLowerCase("tr")}.</p>` : ""}
        ${t.kapasite_dolu ? `<p class="pz-not">Talep kapasitenden fazla. Sermaye artırırsan daha çok müşteriye hizmet verirsin.</p>` : ""}</div>` : ""}
      ${d.aktif && d.yonetici ? pazarAyarKart(d) : ""}
      ${d.aktif && !d.yonetici ? `<div class="kart"><p class="alt">Şirketin kararlarını en büyük ortak verir.</p></div>` : ""}
      <div class="kart"><h2>${e(d.il)}'daki rakipler</h2>${(d.rakipler || []).map(r => `<div class="pz-satir"><span class="sol"><b>${e(r.ad)}</b><span class="kucuk" style="display:block">${e(r.sahip)} · ${pzTL(r.sermaye)} sermaye${r.kaynak ? " · " + PZ_KAYNAK[r.kaynak] : ""}</span></span>
          <span class="sag"><b>${PZ_FIYAT[r.fiyat]}</b><span class="kucuk" style="display:block">Kalite ${PZ_KALITE[r.kalite].toLocaleLowerCase("tr")} · marka ~${fmt(r.marka)}</span></span></div>`).join("") || '<p class="alt">Bu ilde rakibin yok. Pazar senin, ama boş pazar başkalarının da gözü önünde.</p>'}</div>
      <div class="kart"><h2>Haftalık raporlar</h2>${(d.raporlar || []).length ? `<div class="pz-kaydir"><table class="pz-tablo"><tr><th>Hafta</th><th>Pay</th><th>Gelir</th><th>Gider</th><th>Net</th></tr>
        ${d.raporlar.map(r => `<tr><td>${tarih(r.zaman)}</td><td>%${fmt(r.pay, 1)}</td><td>${pzTL(r.gelir)}</td><td>${pzTL(+r.gider + +r.ruhsat + +r.vergi + +r.ceza)}</td><td style="color:${pzRenk(r.net)}">${pzIsaret(r.net)}</td></tr>`).join("")}</table></div>`
        : '<p class="alt">İlk haftalık rapor bir hafta sonra çıkar.</p>'}</div>
      <div class="kart"><h2>Ortaklar</h2>${(d.ortaklar || []).map(o => `<div class="kv"><span>${e(o.kad)}</span><b>%${fmt(o.pay, 2)}</b></div>`).join("")}
        <p class="pz-not">Pay satışı, kâr payı tercihi ve halka arz "Şirketlerim" ekranındadır.</p>
        <button class="btn ikinci" onclick="ekranAc(sirketYonetimEkrani)">Şirketlerim</button></div>`, { geri: true });
    pazarAyarOnizle();
  } catch (err) { pzHata("Şirket", err); }
}
function pazarAyarKart(d){
  const enerji = d.sektor === "enerji";
  return `<div class="kart"><h2>Kararların</h2><p class="alt">Değişiklik bir sonraki haftalık hesaba işler. Aşağıdaki tahmin rakiplerin bugünkü ayarlarına göredir.${(PZ.danisman || {}).otopilot ? " Otopilot açıkken fiyat ve kaliteyi her hafta otopilot belirler." : ""}</p>
    <div class="alan"><label>Fiyat politikası</label><div class="pz-secim" id="pzFiyat">${[1, 2, 3].map(f => `<button data-v="${f}" onclick="pazarSec('fiyat',${f})">${PZ_FIYAT[f]}<small id="pzF${f}"></small></button>`).join("")}</div></div>
    <div class="alan"><label>Kalite bütçesi</label><div class="pz-secim" id="pzKalite" style="--n:4">${[0, 1, 2, 3].map(k => `<button data-v="${k}" onclick="pazarSec('kalite',${k})">${PZ_KALITE[k]}<small id="pzK${k}"></small></button>`).join("")}</div></div>
    ${enerji ? `<div class="alan"><label>Enerji kaynağı</label><div class="pz-secim" id="pzKaynak">${Object.keys(PZ_KAYNAK).map(k => `<button data-v="${k}" onclick="pazarSec('kaynak','${k}')">${PZ_KAYNAK[k]}<small id="pzY${k}"></small></button>`).join("")}</div>
      <p class="pz-not">Kaynak tahmini bugünkü fiyat ve kaliteyle hesaplanır.</p></div>` : ""}
    <div class="kv" style="margin-top:8px"><span>Bu ayarla tahmini net</span><b id="pzOnizNet"></b></div>
    <button class="btn" id="pzKaydet" onclick="pazarAyarKaydet()">Kararı uygula</button>
    <details style="margin-top:12px"><summary class="kucuk" style="cursor:pointer">Tüm fiyat ve kalite seçeneklerinin tablosu</summary>
      <div class="pz-kaydir"><table class="pz-tablo" style="margin-top:8px"><tr><th>Fiyat \\ Kalite</th>${[0, 1, 2, 3].map(k => `<th>${PZ_KALITE[k]}</th>`).join("")}</tr>
      ${[1, 2, 3].map(f => `<tr><td>${PZ_FIYAT[f]}</td>${[0, 1, 2, 3].map(k => { const x = pazarSenaryo(f, k); return `<td id="pzT${f}${k}" style="color:${pzRenk(x && x.net)}">${x ? pzIsaret(x.net) : "-"}</td>`; }).join("")}</tr>`).join("")}</table></div></details>
    <div class="alan" style="margin-top:14px"><label>Başka ile taşı (bedel ${pzTL(d.tasima_bedel)}, marka %60 erir, 7 günde bir)</label>
      <select id="pzTasiIl">${[...VERI.iller].sort((a, b) => a.ad.localeCompare(b.ad, "tr")).map(i => `<option value="${i.id}" ${i.id === d.il_id ? "selected" : ""}>${e(i.ad)}</option>`).join("")}</select></div>
    <button class="btn ikinci" onclick="pazarTasi()">Şirketi taşı</button></div>`;
}
const PZ_SAGLIK = { karda: ["yesil", "Kârda"], basabas: ["sari", "Başa baş"], zararda: ["kirmizi", "Zararda"], iflas_riski: ["kirmizi", "İflas riski"], iflas: ["kirmizi", "İflas etti"] };
function pazarYonetimKart(d, dn){
  const [renk, ad] = PZ_SAGLIK[dn.saglik] || ["", ""];
  const o = dn.oneri;
  return `<div class="kart"><div style="display:flex;justify-content:space-between;align-items:center;gap:8px"><h2>Yönetim</h2><span class="rozet ${renk}">${ad}</span></div>
    ${dn.otopilot ? `<p class="alt">Otopilot açık: her hafta en kârlı fiyat ve kaliteyi kendisi seçiyor. Yönetici ücreti gelirin %${fmt(dn.yonetici_ucret)}'ü.</p>`
      : o && dn.oneri_farkli ? `<p class="alt">Danışman önerisi: <b>${PZ_FIYAT[o.fiyat]} fiyat, ${PZ_KALITE[o.kalite].toLocaleLowerCase("tr")} kalite</b>. Tahmini net ${pzIsaret(o.net)} (şu an ${pzIsaret(dn.mevcut_net)}).</p>
        ${d.yonetici ? `<button class="btn" onclick="pazarOneriUygula()">Öneriyi uygula</button>` : ""}`
      : `<p class="alt">Ayarların şu an en kârlı seçenek. Rakipler değişirse danışman yeni öneri verir.</p>`}
    ${d.yonetici ? `<div class="kv" style="margin-top:8px"><span>Otopilot<span class="kucuk" style="display:block">Haftalık en iyi ayar · gelirin %${fmt(dn.yonetici_ucret)}'ü</span></span>
      <button class="btn ${dn.otopilot ? "ikinci" : "altin"} yarim" style="margin:0;flex:none;padding:9px 14px" onclick="pazarOtopilot(${!dn.otopilot})">${dn.otopilot ? "Kapat" : "Aç"}</button></div>` : ""}
    ${dn.saglik === "zararda" || dn.saglik === "iflas_riski" ? `<p class="pz-not">Zarardan çıkmak için: öneriyi uygula, rakibi az bir ile taşın ya da sermayeyi artır.</p>` : ""}</div>`;
}
async function pazarOneriUygula(){
  const d = PZ.detay, o = (PZ.danisman || {}).oneri; if (!o) return;
  try { const t = await API.rpc("pazar_ayarla", { p_sirket: d.id, p_fiyat: o.fiyat, p_kalite: o.kalite, p_kaynak: d.sektor === "enerji" ? d.kaynak : null }); toast(`Öneri uygulandı. Tahmini net ${pzIsaret(t.net)}.`); pazarDetayEkrani(d.id); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function pazarOtopilot(acik){
  const d = PZ.detay;
  try { await API.rpc("pazar_otopilot", { p_sirket: d.id, p_acik: acik }); toast(acik ? "Otopilot açıldı; en kârlı ayar uygulandı." : "Otopilot kapandı; kararlar sende."); pazarDetayEkrani(d.id); }
  catch (err) { toast(hataCevir(err.message), true); }
}
function pazarSenaryo(f, k){ return ((PZ.detay || {}).senaryo || []).find(x => x.fiyat === f && x.kalite === k); }
function pazarSec(alan, v){ PZ.secim[alan] = v; pazarAyarOnizle(); }
function pazarAyarOnizle(){
  const d = PZ.detay; if (!d || !d.yonetici || !d.aktif) return;
  const s = PZ.secim;
  document.querySelectorAll("#pzFiyat button").forEach(b => b.classList.toggle("aktif", +b.dataset.v === s.fiyat));
  document.querySelectorAll("#pzKalite button").forEach(b => b.classList.toggle("aktif", +b.dataset.v === s.kalite));
  document.querySelectorAll("#pzKaynak button").forEach(b => b.classList.toggle("aktif", b.dataset.v === s.kaynak));
  [1, 2, 3].forEach(f => { const x = pazarSenaryo(f, s.kalite), el = $("#pzF" + f); if (el && x) { el.textContent = pzIsaret(x.net); el.style.color = pzRenk(x.net); } });
  [0, 1, 2, 3].forEach(k => { const x = pazarSenaryo(s.fiyat, k), el = $("#pzK" + k); if (el && x) { el.textContent = pzIsaret(x.net); el.style.color = pzRenk(x.net); } });
  const kay = (d.senaryo || []).filter(x => x.kaynak);
  kay.forEach(x => { const el = $("#pzY" + x.kaynak); if (el) { el.textContent = pzIsaret(x.net); el.style.color = pzRenk(x.net); } });
  for (let f = 1; f <= 3; f++) for (let k = 0; k <= 3; k++) { const td = $("#pzT" + f + k); if (td) td.classList.toggle("on", f === s.fiyat && k === s.kalite); }
  const x = pazarSenaryo(s.fiyat, s.kalite), net = $("#pzOnizNet");
  if (net && x) {
    const kaynakDegisti = d.sektor === "enerji" && s.kaynak !== d.kaynak;
    net.innerHTML = kaynakDegisti ? `<span class="kucuk">Kaynak değişince yeniden hesaplanır</span>` : `<span style="color:${pzRenk(x.net)}">${pzIsaret(x.net)}</span> <span class="kucuk">· pay %${fmt(x.pay, 1)}</span>`;
  }
  const deg = s.fiyat !== d.fiyat || s.kalite !== d.kalite || s.kaynak !== d.kaynak, b = $("#pzKaydet");
  if (b) { b.disabled = !deg; b.textContent = deg ? "Kararı uygula" : "Mevcut ayar"; }
}
async function pazarAyarKaydet(){
  const d = PZ.detay, s = PZ.secim, b = $("#pzKaydet");
  b.disabled = true;
  try {
    const t = await API.rpc("pazar_ayarla", { p_sirket: d.id, p_fiyat: s.fiyat, p_kalite: s.kalite, p_kaynak: d.sektor === "enerji" ? s.kaynak : null });
    toast(`Uygulandı. Tahmini haftalık net ${pzIsaret(t.net)}.`);
    pazarDetayEkrani(d.id);
  } catch (err) { b.disabled = false; toast(hataCevir(err.message), true); }
}
async function pazarTasi(){
  const d = PZ.detay, il = +$("#pzTasiIl").value;
  if (il === d.il_id) { toast("Şirket zaten bu ilde.", true); return; }
  if (!await onayla("Şirketi taşı", `${e(d.ad)} ${e(ilAd(il))} iline taşınacak. Kasadan ${pzTL(d.tasima_bedel)} çıkar, marka değeri %60 erir.`, "Taşı")) return;
  try { const t = await API.rpc("pazar_tasi", { p_sirket: d.id, p_il: il }); toast(`Taşındı. Yeni ilde tahmini net ${pzIsaret(t.net)}.`); pazarDetayEkrani(d.id); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Kamu ihaleleri ---------------- */
async function ihaleEkrani(){
  yukleniyor("Kamu ihaleleri");
  try {
    const v = await API.rpc("ihale_ekrani");
    PZ.ihale = v;
    const y = v.yetki || {}, makamVar = !!(y.belediye_il || (y.bakanliklar || []).length);
    if (PZ.ihaleSekme === "masa" && !makamVar) PZ.ihaleSekme = "acik";
    const sek = [["acik", `Açık (${v.acik.length})`], ["yapim", `Yapımda (${v.yapim.length})`], ["biten", "Sonuçlanan"]].concat(makamVar ? [["masa", "Makam masası"]] : []);
    const liste = PZ.ihaleSekme === "acik" ? v.acik : PZ.ihaleSekme === "yapim" ? v.yapim : v.biten;
    iskelet("Kamu ihaleleri", `
      <div class="kart"><div class="pz-bas"><span class="pz-logo">${PZ_IKON.ihale}</span><div><h2>Devletin işini sen yap</h2>
        <p class="alt">Belediye başkanları ve bakanlar kendi kasalarından ihale açar. İnşaat şirketleri kapalı zarfla teklif verir; en düşük geçerli teklif kazanır.</p></div></div>
        <p class="pz-not">Yapım maliyeti yaklaşık bedelin %70'idir; daha düşük teklif zarar ettirir. İhaleyi açan, ortağı olduğu şirkete ihale veremez. Kazanan şirket ve ortakları gazetede yayımlanır.</p>
        ${(v.insaat_sirketlerim || []).length ? "" : `<p class="pz-not">Teklif verebilmek için bir inşaat şirketin olmalı.</p><button class="btn ikinci" onclick="ekranAc(sirketYonetimEkrani)">İnşaat şirketi kur</button>`}</div>
      <div class="segment" style="margin-bottom:12px">${sek.map(([k, a]) => `<button class="${PZ.ihaleSekme === k ? "aktif" : ""}" onclick="PZ.ihaleSekme='${k}';ihaleEkrani()">${a}</button>`).join("")}</div>
      ${PZ.ihaleSekme === "masa" ? ihaleMasaHtml(v) : (liste.map(x => ihaleKartHtml(x, v)).join("") || `<div class="kart"><p class="alt">${PZ.ihaleSekme === "acik" ? "Şu an teklife açık ihale yok. Belediye başkanları ve bakanlar ihale açtığında burada görünür." : "Kayıt yok."}</p></div>`)}`, { geri: true });
  } catch (err) { pzHata("Kamu ihaleleri", err); }
}
function ihaleKartHtml(x, v){
  const sirketler = v.insaat_sirketlerim || [];
  const durum = x.durum === "acik" ? `<span class="rozet altin">Teklif: <span data-an="${new Date(x.bit).getTime()}">${kalan(new Date(x.bit).getTime() - simdi())}</span></span>`
    : x.durum === "yapim" ? `<span class="rozet">Teslim ${tarihSaat(x.teslim_at)}</span>`
    : x.durum === "tamam" ? (x.sonuc === "yakalandi" ? `<span class="rozet kirmizi">Denetime takıldı</span>` : `<span class="rozet yesil">Teslim edildi</span>`)
    : x.durum === "teklifsiz" ? `<span class="rozet">Teklif gelmedi</span>` : `<span class="rozet">İptal</span>`;
  let govde = "";
  if (x.durum === "acik") {
    const benim = x.tekliflerim || [];
    govde = `<div class="kv"><span>Teklifler</span><b>${fmt(x.teklif_say)} zarf (kapalı)</b></div>
      ${benim.map(t => `<div class="kv"><span>Senin teklifin · ${e(t.sirket)}</span><b>${pzTL(t.tutar)} <button class="bag" onclick="ihaleTeklifGeri(${x.id},${t.sirket_id})">geri al</button></b></div>`).join("")}
      ${sirketler.length && !x.acan_benim ? `<div class="alan"><label>Teklif veren şirket</label><select id="ihS${x.id}">${sirketler.map(s => `<option value="${s.id}" ${s.yasak_bit || s.deneyim < x.deneyim ? "disabled" : ""}>${e(s.ad)} · kasa ${pzTL(s.kasa)}${s.yasak_bit ? " · yasaklı" : ""}${s.deneyim < x.deneyim ? " · deneyim yetersiz" : ""}</option>`).join("")}</select></div>
        <div class="alan"><label>Teklif tutarı (₺) · ${pzTL(x.tavan * 0.4)} – ${pzTL(x.tavan)}</label><input id="ihT${x.id}" type="number" step="1000" min="${Math.round(x.tavan * 0.4)}" max="${x.tavan}" value="${Math.round(x.tavan * 0.85 / 1000) * 1000}"></div>
        <p class="pz-not">Standart yapım maliyeti ${pzTL(x.tavan * 0.7)}. Kazanırsan bu tutar şirket kasasından hemen çıkar, teslimde teklifin ödenir.</p>
        <button class="btn" onclick="ihaleTeklifVer(${x.id})">Kapalı zarf teklif ver</button>` : ""}
      ${x.acan_benim ? `<button class="btn tehlike" onclick="ihaleIptal(${x.id})">İhaleyi iptal et</button>` : ""}`;
  } else if (x.durum === "yapim") {
    govde = `<div class="kv"><span>Yüklenici</span><b>${e(x.kazanan)}</b></div><div class="kv"><span>Bedel</span><b>${pzTL(x.bedel)}</b></div>
      ${x.kazanan_benim ? `<div class="alan"><label>Yapım yöntemi</label><div class="pz-secim">${Object.entries(PZ_YONTEM).map(([k, y]) => `<button class="${x.benim_yontem === k ? "aktif" : ""}" onclick="ihaleYontem(${x.id},'${k}')">${y.ad.replace(" yapım", "")}<small>kâr ${pzIsaret(x.bedel - x.tavan * y.oran)}</small></button>`).join("")}</div>
        <p class="pz-not">${e(PZ_YONTEM[x.benim_yontem || "standart"].not)}</p></div>` : ""}`;
  } else if (x.durum === "tamam" || x.durum === "teklifsiz") {
    govde = x.kazanan ? `<div class="kv"><span>Yüklenici</span><b>${e(x.kazanan)}${x.kazanan_parti ? " · " + e(x.kazanan_parti) : ""}</b></div><div class="kv"><span>Bedel</span><b>${pzTL(x.bedel)}</b></div>
      ${x.yontem ? `<div class="kv"><span>Yöntem</span><b>${PZ_YONTEM[x.yontem].ad}</b></div>` : ""}` : "";
    if ((x.teklifler || []).length) govde += `<details style="margin-top:8px"><summary class="kucuk" style="cursor:pointer">Açılan zarflar (${x.teklifler.length})</summary>${x.teklifler.map(t => `<div class="kv"><span>${e(t.sirket)}</span><b>${pzTL(t.tutar)}</b></div>`).join("")}</details>`;
  }
  return `<div class="kart"><div style="display:flex;justify-content:space-between;gap:8px;align-items:flex-start"><div style="min-width:0"><b>${e(x.ad)}</b>
      <div class="kucuk">${e(x.kurum_ad)} · ${e(x.il)} · açan ${e(x.acan)}${x.acan_unvan ? " (" + e(x.acan_unvan) + ")" : ""}</div></div>${durum}</div>
    <div class="pz-grid"><span><small>Yaklaşık maliyet</small><b>${pzTL(x.tavan)}</b></span><span><small>Yapım süresi</small><b>${fmt(x.sure_gun)} gün</b></span><span><small>İle katkı</small><b>${x.gelisim ? "+" + fmt(x.gelisim, 1) + " gelişim" : ""}${x.gelisim && x.memnuniyet ? " · " : ""}${x.memnuniyet ? "+" + fmt(x.memnuniyet, 1) + " memnuniyet" : ""}</b></span></div>
    ${x.deneyim ? `<p class="pz-not">En az ${fmt(x.deneyim)} teslim edilmiş iş deneyimi ister.</p>` : ""}${govde}</div>`;
}
function ihaleMasaHtml(v){
  const y = v.yetki || {};
  const projeler = y.projeler || [];
  const bel = projeler.filter(p => p.kurum === "belediye"), bak = projeler.filter(p => p.kurum === "bakanlik");
  const ilSec = `<select id="ihIl">${[...VERI.iller].sort((a, b) => a.ad.localeCompare(b.ad, "tr")).map(i => `<option value="${i.id}">${e(i.ad)}</option>`).join("")}</select>`;
  const projeSatir = (p) => `<option value="${p.kod}">${e(p.ad)} · ${pzTL(p.tavan)} · ${pzMilyar(p.butce)}</option>`;
  return `
    ${y.belediye_il ? `<div class="kart"><h2>${e(y.belediye_il_ad)} Belediyesi</h2><div class="kv"><span>Belediye kasası</span><b>${pzMilyar(y.belediye_kasa)}</b></div>
      <div class="alan"><label>Proje</label><select id="ihBelProje">${bel.map(projeSatir).join("")}</select></div>
      <div class="alan"><label>Teklif süresi</label><select id="ihBelSaat"><option value="12">12 saat</option><option value="24" selected>24 saat</option><option value="48">48 saat</option></select></div>
      <p class="pz-not">Bütçe ihale açılınca kasadan ayrılır. Teklif gelmezse ya da ihaleyi iptal edersen geri döner; en düşük teklifle kalan fark da kasaya döner.</p>
      <button class="btn" onclick="ihaleAc('bel')">İhaleye çık</button></div>
      <div class="kart"><h2>İşyeri ruhsat harcı</h2><p class="alt">İlindeki rekabetçi şirketlerin haftalık gelirinden belediye kasasına pay. Yüksek harç kasayı doldurur ama yatırımcıyı başka ile kaçırır.</p>
        <div class="alan"><label>Oran: %<b id="ihRuhsatYaz">${fmt(y.ruhsat || 0, 1)}</b></label><input id="ihRuhsat" type="range" min="0" max="8" step="0.5" value="${y.ruhsat || 0}" oninput="$('#ihRuhsatYaz').textContent=fmt(+this.value,1)"></div>
        <button class="btn ikinci" onclick="ihaleRuhsat()">Harcı uygula</button></div>` : ""}
    ${(y.bakanliklar || []).map(b => { const bp = bak.filter(p => p.bakanlik === b.kod); return `<div class="kart"><h2>${e(b.ad)}</h2>${y.vekalet ? `<p class="pz-not">Bakan atanmadığı için Cumhurbaşkanı olarak vekâleten yönetiyorsun.</p>` : ""}
      <div class="kv"><span>Bakanlık kasası</span><b>${pzMilyar(b.kasa)}</b></div>
      ${bp.length ? `<div class="alan"><label>Proje</label><select id="ihBak_${b.kod}">${bp.map(projeSatir).join("")}</select></div>
        <div class="alan"><label>Yapılacak il</label>${ilSec.replace('id="ihIl"', `id="ihBakIl_${b.kod}"`)}</div>
        <div class="alan"><label>Teklif süresi</label><select id="ihBakSaat_${b.kod}"><option value="12">12 saat</option><option value="24" selected>24 saat</option><option value="48">48 saat</option></select></div>
        <button class="btn" onclick="ihaleAc('${b.kod}')">İhaleye çık</button>` : ""}</div>`; }).join("")}
    ${(y.sektorler || []).length ? `<div class="kart"><h2>Sektör politikası</h2><p class="alt">Teşvik ${fmt(y.tesvik_bedel)} milyar ₺ bakanlık kasasından ödenir ve sektörün pazarını 7 gün %15 büyütür. Sıkı denetim pazarı %8 daraltır; kalitesiz hizmete ve kömüre ceza keser; inşaatta tasarruflu ihale işlerinin yakalanma ihtimalini artırır. 24 saatte bir değiştirilebilir.</p>
      ${y.sektorler.map(s => `<div style="margin-top:12px"><b>${e(s.ad)}</b> <span class="kucuk">${PZ_POL[s.durum]}${s.bit ? " · " + tarihSaat(s.bit) + "'e kadar" : ""}</span>
        <div class="pz-secim">${["normal", "tesvik", "denetim"].map(d => `<button class="${s.durum === d ? "aktif" : ""}" onclick="ihalePolitika('${s.sektor}','${d}')">${d === "normal" ? "Normal" : d === "tesvik" ? "Teşvik" : "Denetim"}</button>`).join("")}</div></div>`).join("")}</div>` : ""}`;
}
async function ihaleAc(kaynak){
  const bel = kaynak === "bel";
  const proje = bel ? $("#ihBelProje").value : $("#ihBak_" + kaynak).value;
  const il = bel ? (PZ.ihale.yetki || {}).belediye_il : +$("#ihBakIl_" + kaynak).value;
  const saat = +(bel ? $("#ihBelSaat") : $("#ihBakSaat_" + kaynak)).value;
  const p = ((PZ.ihale.yetki || {}).projeler || []).find(x => x.kod === proje) || {};
  if (!await onayla("İhaleye çık", `${e(p.ad)} · ${e(ilAd(il))}. ${pzMilyar(p.butce)} kasadan ayrılacak; yaklaşık maliyet ${pzTL(p.tavan)}. Teklifler ${saat} saat toplanır.`, "İhaleyi aç")) return;
  try { await API.rpc("ihale_ac", { p_proje: proje, p_il: il, p_saat: saat }); toast("İhale ilan edildi."); PZ.ihaleSekme = "acik"; ihaleEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ihaleTeklifVer(id){
  const sirket = +$("#ihS" + id).value, tutar = Number($("#ihT" + id).value);
  if (!Number.isSafeInteger(tutar)) { toast("Tutar tam sayı olmalı.", true); return; }
  try { await API.rpc("ihale_teklif", { p_ihale: id, p_sirket: sirket, p_tutar: tutar }); toast("Teklifin zarfa kondu. Sonuç süre bitince açıklanır."); ihaleEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ihaleTeklifGeri(id, sirket){
  try { await API.rpc("ihale_teklif_geri", { p_ihale: id, p_sirket: sirket }); toast("Teklif geri alındı."); ihaleEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ihaleIptal(id){
  if (!await onayla("İhaleyi iptal et", "Bütçe kasaya döner, verilen teklifler düşer.", "İptal et", true)) return;
  try { await API.rpc("ihale_iptal", { p_ihale: id }); toast("İhale iptal edildi."); ihaleEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ihaleYontem(id, yontem){
  if (yontem === "tasarruflu" && !await onayla("Tasarruflu yapım", e(PZ_YONTEM.tasarruflu.not), "Riski al", true)) return;
  try { await API.rpc("ihale_yontem", { p_ihale: id, p_yontem: yontem }); toast(PZ_YONTEM[yontem].ad + " seçildi."); ihaleEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ihalePolitika(sektor, durum){
  const s = (((PZ.ihale || {}).yetki || {}).sektorler || []).find(x => x.sektor === sektor) || {};
  if (s.durum === durum) return;
  const metin = durum === "tesvik" ? `${e(s.ad)} sektörüne 7 günlük teşvik. Bakanlık kasasından ${fmt(PZ.ihale.yetki.tesvik_bedel)} milyar ₺ çıkar.`
    : durum === "denetim" ? `${e(s.ad)} sektöründe 7 günlük sıkı denetim. Pazar daralır, kalitesiz şirketlere ceza kesilir.` : `${e(s.ad)} sektöründeki özel uygulama sona erer.`;
  if (!await onayla("Sektör politikası", metin + " Karar Resmî Gazete'de yayımlanır.", "Uygula")) return;
  try { await API.rpc("sektor_politika_ayarla", { p_sektor: sektor, p_durum: durum }); toast("Politika uygulandı."); ihaleEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function ihaleRuhsat(){
  const oran = +$("#ihRuhsat").value;
  try { await API.rpc("il_ruhsat_ayarla", { p_oran: oran }); toast(`Ruhsat harcı %${fmt(oran, 1)} oldu.`); ihaleEkrani(); }
  catch (err) { toast(hataCevir(err.message), true); }
}

/* ---------------- Mevcut ekranlara giriş noktaları ---------------- */
(function(){
  if (typeof vitSektor === "object") Object.assign(vitSektor, { ozel_okul: "Özel Okul", ozel_hastane: "Özel Hastane", market: "Market Zinciri", ulasim: "Ulaşım Firması", enerji: "Enerji Santrali" });
  const kartlar = `<button class="vit-ana-kart pz-ek" onclick="ekranAc(pazarMerkezEkrani)"><span class="vit-ikon" style="color:var(--ink2)">${PZ_IKON.sirket}</span><b>Rekabetçi şirketler</b><span>Okul, hastane, market, ulaşım, enerji kur; rakiplerinle yarış</span></button>
    <button class="vit-ana-kart pz-ek" onclick="ekranAc(ihaleEkrani)"><span class="vit-ikon" style="color:var(--ink2)">${PZ_IKON.ihale}</span><b>Kamu ihaleleri</b><span>Belediye ve bakanlık ihalelerine teklif ver</span></button>`;
  if (typeof iskelet === "function") {
    const eski = iskelet;
    window.iskelet = iskelet = function(baslik, govde, opt){
      const r = eski.apply(this, arguments);
      try {
        if (baslik === "Hayat") { const g = $(".vit-ana-izgara"); if (g && !g.querySelector(".pz-ek")) g.insertAdjacentHTML("beforeend", kartlar); }
        if (baslik === "Şirketler") { const d = $(".vit-dugme"); if (d && !d.querySelector(".pz-ek")) d.insertAdjacentHTML("beforeend", `<button class="btn altin pz-ek" onclick="ekranAc(pazarMerkezEkrani)">Rekabetçi şirket kur</button><button class="btn ikinci pz-ek" onclick="ekranAc(ihaleEkrani)">Kamu ihaleleri</button>`); }
        if (baslik === "Şirketlerimi yönet" || baslik === "Şirketlerim") {
          const ic = $("#icerik"); if (ic && !ic.querySelector(".pz-ek")) ic.insertAdjacentHTML("afterbegin", `<div class="kart pz-ek"><h2>Rekabetçi şirketler ve ihaleler</h2><p class="alt">Okul, hastane, market, ulaşım ve enerji şirketlerinin fiyat ve kalite kararlarını ayrı ekrandan yönetirsin. İnşaat şirketlerin kamu ihalelerine girebilir.</p><button class="btn altin" onclick="ekranAc(pazarMerkezEkrani)">Rekabetçi şirketlerim</button><button class="btn ikinci" onclick="ekranAc(ihaleEkrani)">Kamu ihaleleri</button></div>`);
        }
      } catch (_) {}
      return r;
    };
  }
  if (typeof devletEkrani === "function") {
    const eskiDevlet = devletEkrani;
    window.devletEkrani = devletEkrani = async function(){
      const r = await eskiDevlet.apply(this, arguments);
      try { const ic = $("#icerik"); if (ic && !ic.querySelector(".pz-ek")) ic.insertAdjacentHTML("beforeend", `<div class="kart pz-ek"><h2>Kamu ihaleleri ve sektör politikası</h2><p class="alt">Belediye ve bakanlık ihaleleri, yükleniciler, skandallar. Makamdaysan ihale aç, sektörlere teşvik ya da denetim uygula.</p><button class="btn altin" onclick="ekranAc(ihaleEkrani)">İhale ve ekonomi masası</button></div>`); } catch (_) {}
      return r;
    };
    if (typeof EKRAN === "object" && EKRAN) EKRAN.devlet = () => devletEkrani();
  }
})();
window.pazarMerkezEkrani = pazarMerkezEkrani;
window.ihaleEkrani = ihaleEkrani;
