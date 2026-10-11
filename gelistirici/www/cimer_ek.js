/* =====================================================================
   CİMER — vatandaş başvuruları (dilekçenin yerine). Arka uç: 81_cimer.sql
   Başvuru kişiye değil makama gider; o makamda kim oturuyorsa o görür ve yanıtlar.
   ===================================================================== */
"use strict";
const CIMER = { sekme: "yeni", veri: null };
const CIMER_KAT = { sikayet: "Şikâyet", talep: "Talep", oneri: "Öneri", bilgi: "Bilgi edinme" };
const CIMER_SONUC = { olumlu: "Olumlu", olumsuz: "Olumsuz", bilgi: "Bilgi verildi" };
(function(){ const st = document.createElement("style"); st.textContent = `
.cimer-bas{display:flex;align-items:center;gap:12px}
.cimer-logo{width:46px;height:46px;border-radius:12px;background:linear-gradient(150deg,#c8102e,#8b0b20);color:#fff;display:grid;place-items:center;font-family:var(--disp);font-weight:700;font-size:13px;letter-spacing:.5px;flex:none}
.cimer-kat{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}
.cimer-kat button{padding:8px 12px;border-radius:18px;background:var(--panel2);font-weight:700;font-size:14px;border:1px solid transparent}
.cimer-kat button.secili{border-color:var(--ink2);color:var(--ink2)}
.cimer-satir{padding:12px 0;border-bottom:1px solid var(--line)}
.cimer-satir:last-child{border-bottom:0}
.cimer-satir .ust{display:flex;justify-content:space-between;gap:8px;align-items:flex-start}
.cimer-cevap{margin-top:8px;padding:10px 12px;border-radius:10px;background:var(--panel2);font-size:14px;white-space:pre-wrap;overflow-wrap:anywhere}
.cimer-metin{margin-top:6px;font-size:14.5px;white-space:pre-wrap;overflow-wrap:anywhere}
.cimer-karne{width:100%;border-collapse:collapse;font-size:13.5px}
.cimer-karne th,.cimer-karne td{padding:8px 4px;border-bottom:1px solid var(--line);text-align:right}
.cimer-karne th:first-child,.cimer-karne td:first-child{text-align:left}
`; document.head.appendChild(st); })();

function cimerDurumRozet(b){
  if (b.durum === "sonuclandi") return `<span class="rozet ${b.sonuc === "olumlu" ? "yesil" : ""}">${CIMER_SONUC[b.sonuc] || "Sonuçlandı"}</span>`;
  if (b.suresi_gecti) return `<span class="rozet kirmizi">Süresi geçti</span>`;
  return `<span class="rozet altin">${b.durum === "inceleniyor" ? "İnceleniyor" : "Bekliyor"}</span>`;
}
function cimerSatirHtml(b, gelen){
  return `<div class="cimer-satir"><div class="ust"><div style="min-width:0"><b>${e(b.konu)}</b>
      <div class="kucuk">${e(b.kurum)} · ${CIMER_KAT[b.kategori] || ""}${b.imza_sayisi ? ` · ${b.imza_sayisi} imzalı toplu başvuru` : ""} · ${tarihSaat(b.zaman)}</div>
      ${gelen ? `<div class="kucuk">Başvuran: <a href="#" class="bag" onclick="oyuncuKart('${e(b.gonderen)}');return false">${e(b.gonderen)}</a>${b.gonderen_il ? " · " + e(b.gonderen_il) : ""}</div>` : ""}</div>${cimerDurumRozet(b)}</div>
    <div class="cimer-metin">${e(b.metin)}</div>
    ${b.cevap ? `<div class="cimer-cevap"><b>${e(b.cevaplayan || "")}</b>${b.cevaplayan_unvan ? ` <span class="kucuk">${e(b.cevaplayan_unvan)}</span>` : ""}<div style="margin-top:4px">${e(b.cevap)}</div></div>` : ""}
    ${!gelen && b.durum === "sonuclandi" && b.memnun == null ? `<div class="vit-dugme"><button class="btn ikinci" onclick="cimerDegerlendir(${b.id},true)">Memnun kaldım</button><button class="btn ikinci" onclick="cimerDegerlendir(${b.id},false)">Memnun kalmadım</button></div>` : ""}
    ${!gelen && b.memnun != null ? `<div class="kucuk" style="margin-top:6px">Değerlendirmen: ${b.memnun ? "memnun kaldın" : "memnun kalmadın"}</div>` : ""}
    ${gelen && b.yanitlayabilirim ? `<div class="vit-dugme">${b.durum === "bekliyor" ? `<button class="btn ikinci" onclick="cimerIncele(${b.id})">İncelemeye al</button>` : ""}<button class="btn altin" onclick="cimerYanitModal(${b.id})">Resmî yanıt ver</button></div>` : ""}</div>`;
}
function cimerYeniHtml(v){
  const k = v.kurumlar || {};
  const bakan = (k.bakanliklar || []);
  const iller = (VERI.iller || []).slice().sort((a, b) => a.ad.localeCompare(b.ad, "tr"));
  return `<div class="kart"><h2>Yeni başvuru</h2>
    <p class="alt">Şikâyet, talep, öneri ya da bilgi edinme başvurunu ilgili kuruma ilet. Başvurun o makamda görev yapan kişiye gider; yalnız sen ve o makam görürsün. Bugün ${v.bugun_kalan} başvuru hakkın kaldı.</p>
    <div class="alan"><label>Kurum</label><select id="cmHedef"><option value="bakanlik">Bakanlık</option><option value="belediye">Belediye</option><option value="cb">Cumhurbaşkanlığı</option></select></div>
    <div class="alan" id="cmBakKut"><label>Bakanlık</label><select id="cmBak">${bakan.map(b => `<option value="${e(b.kod)}">${e(b.ad)} — ${b.bakan ? e(b.bakan) : "bakan yok, Cumhurbaşkanı bakar"}</option>`).join("")}</select></div>
    <div class="alan" id="cmIlKut" hidden><label>Belediye</label><select id="cmIl">${iller.map(i => `<option value="${i.id}"${i.id === k.il_id ? " selected" : ""}>${e(i.ad)} Belediyesi</option>`).join("")}</select>
      <div class="kucuk" id="cmIlNot" style="margin-top:4px"></div></div>
    <div class="kucuk" id="cmCbNot" hidden style="margin-top:6px">${k.cb ? `Başvurun Cumhurbaşkanı ${e(k.cb)} makamına iletilir.` : "Cumhurbaşkanlığı makamı boş; başvurun seçilecek Cumhurbaşkanına iletilir."}</div>
    <div class="alan"><label>Başvuru türü</label><div class="cimer-kat" id="cmKat">${Object.entries(CIMER_KAT).map(([kk, ad], i) => `<button type="button" data-kat="${kk}" class="${i === 0 ? "secili" : ""}">${ad}</button>`).join("")}</div></div>
    <div class="alan"><label>Konu</label><input id="cmKonu" maxlength="100" placeholder="Kısa bir başlık"></div>
    <div class="alan"><label>Başvurun</label><textarea class="alanmetin" id="cmMetin" maxlength="2000" placeholder="Sorunu, ne istediğini ve nerede olduğunu açıkça yaz."></textarea><div class="kucuk" id="cmSayac">0/2000</div></div>
    <button class="btn" id="cmGonder"${v.bugun_kalan ? "" : " disabled"}>Başvuruyu gönder</button>
    <p class="kucuk" style="margin-top:8px">Kurumların 72 saat içinde yanıt vermesi beklenir; yanıt süreleri herkese açık kurum karnesinde görünür. Hakaret içeren başvurular kabul edilmez.</p></div>`;
}
function cimerYeniBagla(){
  const h = $("#cmHedef"); if (!h) return;
  const goster = () => { $("#cmBakKut").hidden = h.value !== "bakanlik"; $("#cmIlKut").hidden = h.value !== "belediye"; $("#cmCbNot").hidden = h.value !== "cb"; ilNot(); };
  const ilNot = () => { const n = $("#cmIlNot"); if (!n) return; const k = CIMER.veri.kurumlar || {};
    n.textContent = +$("#cmIl").value === k.il_id ? (k.belediye_baskani ? `Belediye başkanı: ${k.belediye_baskani}` : "Bu belediyenin şu an başkanı yok; başvurun seçilecek başkana iletilir.") : "Başvurun o ilin belediye başkanına iletilir; başkan yoksa seçilince ulaşır."; };
  h.onchange = goster; $("#cmIl").onchange = ilNot; goster();
  let kat = "sikayet";
  document.querySelectorAll("#cmKat [data-kat]").forEach(b => b.onclick = () => { kat = b.dataset.kat; document.querySelectorAll("#cmKat button").forEach(x => x.classList.toggle("secili", x === b)); });
  const m = $("#cmMetin"); m.oninput = () => { $("#cmSayac").textContent = `${m.value.length}/2000`; };
  $("#cmGonder").onclick = async () => {
    const b = $("#cmGonder"); b.disabled = true;
    try {
      const r = await API.rpc("cimer_basvur", { p_hedef: h.value, p_bakanlik: h.value === "bakanlik" ? $("#cmBak").value : null, p_il: h.value === "belediye" ? +$("#cmIl").value : null,
        p_kategori: kat, p_konu: $("#cmKonu").value, p_metin: m.value });
      toast(r.muhatap_var ? "Başvurun ilgili makama iletildi." : "Başvurun kaydedildi; makam dolunca iletilecek.");
      HAPTIK && HAPTIK.hafif && HAPTIK.hafif();
      CIMER.sekme = "benim"; cimerEkrani(true);
    } catch (err) { toast(hataCevir(err.message), true); b.disabled = false; }
  };
}
async function cimerEkrani(sessiz){
  if (sessiz !== true) yukleniyor("CİMER");
  let v, karne = [];
  try { [v, karne] = await Promise.all([API.rpc("cimer"), CIMER.sekme === "karne" ? API.rpc("cimer_karne") : Promise.resolve([])]); }
  catch (err) { iskelet("CİMER", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
  CIMER.veri = v;
  const bekleyen = v.gelen.filter(b => b.yanitlayabilirim).length;
  const sekmeler = [["yeni", "Yeni başvuru"], ["benim", `Başvurularım${v.basvurularim.length ? " · " + v.basvurularim.length : ""}`]]
    .concat(v.gelen.length || CIMER.sekme === "gelen" || (typeof cimerMakamVar === "function" && cimerMakamVar()) ? [["gelen", `Makamıma gelen${bekleyen ? " · " + bekleyen : ""}`]] : [])
    .concat([["karne", "Kurum karnesi"]]);
  if (!sekmeler.some(s => s[0] === CIMER.sekme)) CIMER.sekme = "yeni";
  let govde = `<div class="kart"><div class="cimer-bas"><div class="cimer-logo">CİMER</div><div><b style="font-family:var(--disp);font-size:20px">Cumhurbaşkanlığı İletişim Merkezi</b>
      <div class="kucuk">Bakanlıklara, belediyelere ve Cumhurbaşkanlığına başvur</div></div></div></div>
    <div class="sekme-cip" style="flex-wrap:wrap">${sekmeler.map(([k, ad]) => `<button data-cs="${k}" class="${CIMER.sekme === k ? "aktif" : ""}">${ad}</button>`).join("")}</div>`;
  if (CIMER.sekme === "yeni") govde += cimerYeniHtml(v);
  else if (CIMER.sekme === "benim") govde += `<div class="kart">${v.basvurularim.map(b => cimerSatirHtml(b, false)).join("") || `<div class="bos">Henüz başvurun yok.</div>`}</div>`;
  else if (CIMER.sekme === "gelen") govde += `<div class="kart"><p class="alt">Makamına gelen başvurular. Görevi devralırsan bekleyen başvurular da sana geçer; 72 saatte yanıtlanmayanlar kurum karnende gecikmiş görünür.</p>${v.gelen.map(b => cimerSatirHtml(b, true)).join("") || `<div class="bos">Bekleyen başvuru yok.</div>`}</div>`;
  else govde += `<div class="kart"><h2>Kurum karnesi</h2><p class="alt">Son 30 gün. Başvuranların kimliği gösterilmez.</p>
      ${karne.length ? `<table class="cimer-karne"><tr><th>Kurum</th><th>Başvuru</th><th>Yanıt</th><th>Geciken</th><th>Ort. süre</th><th>Memnun</th></tr>
      ${karne.map(x => `<tr><td>${e(x.kurum)}</td><td>${x.basvuru}</td><td>${x.yanit}</td><td>${x.geciken || "-"}</td><td>${x.ort_saat != null ? String(x.ort_saat).replace(".", ",") + " sa" : "-"}</td><td>${x.memnuniyet != null ? "%" + x.memnuniyet : "-"}</td></tr>`).join("")}</table>` : `<div class="bos">Henüz başvuru yok.</div>`}</div>`;
  iskelet("CİMER", govde, { geri: true });
  document.querySelectorAll("[data-cs]").forEach(b => b.onclick = () => { CIMER.sekme = b.dataset.cs; cimerEkrani(true); });
  if (CIMER.sekme === "yeni") cimerYeniBagla();
}
async function cimerIncele(id){ try { await islem(() => API.rpc("cimer_yanitla", { p_id: id, p_durum: "inceleniyor", p_sonuc: null, p_cevap: null }), "Başvuru incelemeye alındı."); cimerEkrani(true); } catch (_) {} }
async function cimerDegerlendir(id, memnun){ try { await islem(() => API.rpc("cimer_degerlendir", { p_id: id, p_memnun: memnun }), "Değerlendirmen kaydedildi."); cimerEkrani(true); } catch (_) {} }
function cimerYanitModal(id){
  const b = ((CIMER.veri || {}).gelen || []).find(x => x.id === id); if (!b) return;
  const m = modal(`<h3 style="font-size:19px;font-weight:800">Resmî yanıt</h3><p class="alt">${e(b.kurum)} adına “${e(b.konu)}” başvurusunu yanıtlıyorsun.</p>
    <div class="alan"><label>Sonuç</label><select id="cmSonuc"><option value="olumlu">Olumlu — talep karşılandı</option><option value="olumsuz">Olumsuz — karşılanamadı</option><option value="bilgi">Bilgi verildi</option></select></div>
    <div class="alan"><label>Yanıt metni</label><textarea class="alanmetin" id="cmCevap" maxlength="2000"></textarea></div>
    <button class="btn altin" id="cmYanitGonder">Yanıtı gönder</button>`);
  $("#cmYanitGonder", m).onclick = async () => {
    try { await islem(() => API.rpc("cimer_yanitla", { p_id: id, p_durum: "sonuclandi", p_sonuc: $("#cmSonuc", m).value, p_cevap: $("#cmCevap", m).value }), "Yanıtın başvurana iletildi."); modalKapat(); cimerEkrani(true); } catch (_) {}
  };
}
// Gündem kartı: makamına gelen bekleyen başvurular + CİMER girişi
function cimerGundemHtml(c){
  if (!c) return "";
  const bekleyen = (c.gelen || []).filter(b => b.yanitlayabilirim && b.durum !== "sonuclandi");
  return `<div class="kart"><button class="giris-satir" style="border:0;padding:4px 0" onclick="CIMER.sekme='${bekleyen.length ? "gelen" : "yeni"}';ekranAc(cimerEkrani)">
      <span class="yik"><span class="cimer-logo" style="width:34px;height:34px;font-size:9px;border-radius:9px">CİMER</span></span>
      <span class="orta"><b>${bekleyen.length ? `Makamına ${bekleyen.length} CİMER başvurusu geldi` : "CİMER'e başvur"}</b><span class="kucuk">${bekleyen.length ? e(bekleyen[0].konu) : "Şikâyet ve taleplerini bakanlıklara, belediyelere ilet"}</span></span><span class="ok">›</span></button></div>`;
}
