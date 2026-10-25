/* =====================================================================
   OYUNCU BANKASI KREDİ MASASI. Arka uç: migrations/20261011_oyuncu_banka_kredi_masasi.sql
   Müşteri: hesap aç, paketleri gör, çekmeden önce ödeme planı, krediyi çek, teklifleri kabul et,
            mali bilgi izni ver, taksit öde, erken kapat.
   Banka sahibi: paket tanımla (vade, taksit, faiz, tutar, asgari not, otomatik), başvuruları onayla,
            hesap sahiplerinden mali bilgi iste, kredi teklif et, gecikende Adliye'de dava aç.
   ===================================================================== */
"use strict";
const KM = { banka: null, mod: "musteri", veri: null };
const KM_KAPSAM = { maas: "Maaş ve makam ücreti", gunluk: "Gelir dökümü (son gelirler)", mulk: "Gayrimenkul listesi", kira: "Kira gelirleri", sirket: "Şirket hisseleri" };
(function(){ const st = document.createElement("style"); st.textContent = `
.km-tablo{width:100%;border-collapse:collapse;font-size:13.5px;margin-top:8px}
.km-tablo th,.km-tablo td{padding:6px 4px;border-bottom:1px solid var(--line);text-align:right}
.km-tablo th:first-child,.km-tablo td:first-child{text-align:left}
.km-paket{border:1px solid var(--line);border-radius:12px;padding:12px;margin-top:10px}
.km-cip{display:inline-block;padding:3px 8px;border-radius:12px;background:var(--panel2);font-size:12.5px;font-weight:700;margin:4px 4px 0 0}
.km-engel{color:var(--gold2,#c9a227);font-weight:700;margin-top:6px}
.km-sat{display:flex;gap:8px;flex-wrap:wrap}.km-sat .btn{flex:1 1 140px}
.km-ozet{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
.km-ozet div{background:var(--panel2);border-radius:10px;padding:8px 10px}.km-ozet b{display:block;font-size:17px}
`; document.head.appendChild(st); })();

const kmTL = n => fmt(Math.round(Number(n) || 0)) + " ₺";
const kmVade = g => (Number(g) === Math.round(Number(g)) ? Number(g) : fmt(g, 1)) + " gün";
function kmAralik(gun, taksit){ const s = gun * 24 / taksit; return s % 24 === 0 ? (s / 24 === 1 ? "her gün" : `${s / 24} günde bir`) : `${s} saatte bir`; }
function kmPlanHtml(p){
  return `<table class="km-tablo"><tr><th>Taksit</th><th>Ödeme tarihi</th><th>Tutar</th></tr>
    ${(p.taksitler || []).map(t => `<tr><td>${t.sira}.</td><td>${tarihSaat(t.vade)}</td><td>${kmTL(t.tutar)}</td></tr>`).join("")}
    <tr><td><b>Toplam</b></td><td class="kucuk">faiz ${kmTL(p.faiz_tutari)}</td><td><b>${kmTL(p.toplam)}</b></td></tr></table>`;
}
// Sunucudaki planla aynı bölüşüm (teklif formunda anlık önizleme için)
function kmPlanHesap(tutar, gun, taksit, faiz){
  const toplam = Math.round(tutar * (1 + faiz / 100)), n = Math.max(1, taksit), saat = gun * 24, bas = Date.now();
  const taksitler = []; for (let i = 1; i <= n; i++) taksitler.push({ sira: i, vade: new Date(bas + Math.floor(saat * i / n) * 3600000).toISOString(), tutar: i === n ? toplam - Math.floor(toplam / n) * (n - 1) : Math.floor(toplam / n) });
  return { toplam, faiz_tutari: toplam - tutar, taksitler };
}
const kmTaksitSecenek = gun => Array.from({ length: 30 }, (_, i) => i + 1).filter(n => (gun * 24) % n === 0);

async function oybKrediMasasiEkrani(banka, sessiz){
  if (banka) KM.banka = +banka;
  if (sessiz !== true) yukleniyor("Kredi masası");
  let v; try { v = await API.rpc("oyb_kredi_masasi", { p_banka: KM.banka }); }
  catch (err) { iskelet("Kredi masası", `<div class="bos">${e(hataCevir(err.message))}</div>`, { geri: true }); return; }
  KM.veri = v;
  if (!v.yonetebilir) KM.mod = "musteri";
  let h = `<div class="kart"><h2>🏦 ${e(v.banka.ad)} · Kredi masası</h2>
    <div class="km-ozet"><div><span class="kucuk">Bankanın verebileceği kredi</span><b>${kmTL(v.banka.kredi_verilebilir)}</b></div>
      <div><span class="kucuk">Kredi notun</span><b>${v.kredi_notu} <small class="kucuk">${e(v.not_ad || "")}</small></b></div></div>
    ${v.yonetebilir ? `<div class="segment" style="margin-top:10px">${[["musteri", "Müşteri gözüyle"], ["yonetim", "Banka yönetimi"]].map(([k, a]) => `<button class="${KM.mod === k ? "aktif" : ""}" onclick="KM.mod='${k}';oybKrediMasasiEkrani(null,true)">${a}</button>`).join("")}</div>` : ""}</div>`;
  h += KM.mod === "yonetim" ? kmYonetimHtml(v) : kmMusteriHtml(v);
  iskelet("Kredi masası", h, { geri: true });
}

/* ---------------- Müşteri ---------------- */
function kmMusteriHtml(v){
  let h = "";
  if (!v.hesap) {
    h += `<div class="kart"><h2>Bu bankada hesabın yok</h2><p class="alt">Bu bankadan kredi çekmek, teklif almak için önce hesap açmalısın. Hesap açmak ücretsizdir; banka sahibi müşterisi olduğunu görür ve senden mali bilgi isteyebilir.</p>
      ${v.ortak ? `<p class="kucuk">Bu bankanın ortağısın; kendi bankandan kredi çekemezsin.</p>` : `<button class="btn altin" onclick="kmHesapAc()">Hesap aç</button>`}</div>`;
  }
  const b = v.bilgi_talebi;
  if (b && b.durum === "talep") {
    h += `<div class="kart"><h2>Banka senden mali bilgi istiyor</h2><p class="alt">İzin verdiğin bilgileri yalnız bu bankanın yöneticisi görür. İstemediğin kutuyu kaldırabilirsin.</p>
      ${b.istenen.map(x => `<label style="display:block;margin:6px 0"><input type="checkbox" name="kmIzin" value="${e(x)}" checked> ${e(KM_KAPSAM[x] || x)}</label>`).join("")}
      <div class="km-sat"><button class="btn altin" onclick="kmBilgiYanit(true)">Seçtiklerime izin ver</button><button class="btn ikinci" onclick="kmBilgiYanit(false)">Reddet</button></div></div>`;
  } else if (b) h += `<div class="kart"><p class="kucuk">Mali bilgi izni: ${b.durum === "izin" ? "verdin (" + b.izinli.map(x => e(KM_KAPSAM[x] || x)).join(", ") + ")" : "vermedin"}.</p></div>`;
  (v.tekliflerim || []).forEach(t => {
    h += `<div class="kart"><h2>Bankadan sana özel kredi teklifi</h2>
      <div><span class="km-cip">${kmTL(t.tutar)}</span><span class="km-cip">${kmVade(t.vade_gun)}</span><span class="km-cip">${t.taksit_sayisi} taksit · ${kmAralik(t.vade_gun, t.taksit_sayisi)}</span><span class="km-cip">faiz %${fmt(t.faiz, 2)}</span></div>
      ${t.mesaj ? `<p class="alt" style="margin-top:6px">“${e(t.mesaj)}”</p>` : ""}
      <p class="kucuk" style="margin-top:6px">Ödeme planı (bugün kabul edersen) · son kabul ${tarihSaat(t.son)}</p>${kmPlanHtml(t.plan)}
      <div class="km-sat" style="margin-top:8px"><button class="btn altin" onclick="kmTeklifYanit(${t.id},true)">Kabul et, krediyi kullan</button><button class="btn ikinci" onclick="kmTeklifYanit(${t.id},false)">Reddet</button></div></div>`;
  });
  const paketler = (v.paketler || []).filter(p => p.aktif);
  h += `<div class="kart"><h2>Kredi paketleri</h2>
    ${v.baska_kredi && !(v.kredilerim || []).some(k => ["aktif", "basvuru", "gecikmis"].includes(k.durum)) ? `<p class="km-engel">Başka bir oyuncu bankasında açık kredin var; o kapanmadan yeni kredi çekemezsin.</p>` : ""}
    ${paketler.map(p => `<div class="km-paket"><b>${e(p.ad)}</b> ${p.otomatik ? `<span class="rozet yesil">Anında</span>` : `<span class="rozet altin">Banka onaylı</span>`}
      <div><span class="km-cip">${kmVade(p.vade_gun)}</span><span class="km-cip">${p.taksit_sayisi} taksit · ${kmAralik(p.vade_gun, p.taksit_sayisi)}</span><span class="km-cip">faiz %${fmt(p.faiz, 2)}</span><span class="km-cip">${kmTL(p.min_tutar)} – ${kmTL(p.max_tutar)}</span>${p.min_not ? `<span class="km-cip">en az ${p.min_not} not</span>` : ""}</div>
      <p class="kucuk" style="margin-top:6px">Bu pakette çekebileceğin en yüksek tutar: <b>${kmTL(Math.max(0, p.limitim))}</b></p>
      <div class="alan"><label>Tutar (₺)</label><input id="kmTutar${p.id}" type="number" min="${p.min_tutar}" max="${p.max_tutar}" step="100" value="${Math.max(p.min_tutar, Math.min(p.max_tutar, Math.floor(Math.max(0, p.limitim) / 100) * 100 || p.min_tutar))}"></div>
      <div id="kmPlan${p.id}"></div>
      <div class="km-sat"><button class="btn ikinci" onclick="kmPlanGoster(${p.id})">Ödeme planını gör</button><button class="btn altin" id="kmCek${p.id}" disabled onclick="kmKrediCek(${p.id})">${p.otomatik ? "Krediyi çek" : "Başvur"}</button></div></div>`).join("") || `<p class="alt">Bu banka şu an kredi paketi sunmuyor.</p>`}</div>`;
  if ((v.kredilerim || []).length) h += `<div class="kart"><h2>Bu bankadaki kredilerim</h2>${v.kredilerim.map(kmKredimHtml).join("")}</div>`;
  if (v.hesap) h += `<div class="kart"><p class="kucuk">Hesabın ${tarihSaat(v.hesap.acilis)} tarihinde açıldı.</p><button class="btn ikinci" onclick="kmHesapKapat()">Hesabı kapat</button></div>`;
  return h;
}
function kmKredimHtml(k){
  const durum = { aktif: "Ödeniyor", gecikmis: "Taksit gecikti", basvuru: "Banka onayı bekleniyor", odendi: "Kapandı", reddedildi: "Reddedildi", iptal: "İptal" }[k.durum] || k.durum;
  const acik = k.durum === "aktif" || k.durum === "gecikmis";
  const sonraki = (k.taksitler || []).find(t => Number(t.odenen) < Number(t.tutar));
  return `<div class="km-paket"><div style="display:flex;justify-content:space-between;gap:8px"><b>Kredi #${k.id} · ${kmTL(k.anapara)}</b><span class="rozet ${k.durum === "gecikmis" ? "kirmizi" : k.durum === "odendi" ? "yesil" : "altin"}">${durum}</span></div>
    <div class="kv"><span class="k">Kalan borç</span><span class="v">${kmTL(k.kalan)}</span></div>
    <div class="kv"><span class="k">Vade / faiz</span><span class="v">${kmVade(k.vade_gun)} · %${fmt(k.oran, 2)}</span></div>
    ${k.erken_kapandi ? `<p class="kucuk">Erken kapattın; ${kmTL(k.erken_indirim)} faiz indirimi aldın.</p>` : ""}
    ${k.icra ? `<p class="km-engel">Adliye'de icra dosyası var (${e(k.icra)}).</p>` : ""}
    ${(k.taksitler || []).length ? `<details><summary class="kucuk" style="cursor:pointer">Ödeme planı</summary><table class="km-tablo"><tr><th>Taksit</th><th>Tarih</th><th>Kalan</th></tr>${k.taksitler.map(t => `<tr><td>${t.sira}.</td><td>${tarihSaat(t.vade)}</td><td>${Number(t.odenen) >= Number(t.tutar) ? "Ödendi" : kmTL(t.tutar - t.odenen)}</td></tr>`).join("")}</table></details>` : ""}
    ${acik ? `<div class="km-sat" style="margin-top:8px">${sonraki ? `<button class="btn altin" onclick="kmTaksitOde(${k.id},${Math.ceil(sonraki.tutar - sonraki.odenen)})">Sıradaki taksiti öde (${kmTL(sonraki.tutar - sonraki.odenen)})</button>` : ""}
      ${k.erken_kapama ? `<button class="btn ikinci" onclick="kmErkenKapat(${k.id})">Erken kapat: ${kmTL(k.erken_kapama.tutar)}${k.erken_kapama.indirim > 0 ? ` (${kmTL(k.erken_kapama.indirim)} indirim)` : ""}</button>` : ""}</div>` : ""}</div>`;
}
async function kmHesapAc(){ try { await islem(() => API.rpc("oyb_hesap_ac", { p_banka: KM.banka }), "Hesabın açıldı. Artık bu bankadan kredi çekebilirsin."); oybKrediMasasiEkrani(null, true); } catch (_) {} }
async function kmHesapKapat(){ if (!await onayla("Hesabı kapat", "Bu bankadaki hesabını kapatırsan kredi çekemez, teklif alamazsın.", "Kapat")) return;
  try { await islem(() => API.rpc("oyb_hesap_kapat", { p_banka: KM.banka }), "Hesabın kapatıldı."); oybKrediMasasiEkrani(null, true); } catch (_) {} }
async function kmBilgiYanit(onay){
  const a = [...document.querySelectorAll('input[name="kmIzin"]:checked')].map(x => x.value);
  if (onay && !a.length) { toast("İzin vereceğin en az bir bilgiyi seç.", true); return; }
  try { await islem(() => API.rpc("oyb_hesap_bilgi_yanit", { p_banka: KM.banka, p_onay: onay, p_kapsam: onay ? a : null }), onay ? "İzin verdiğin bilgiler bankayla paylaşıldı." : "Talebi reddettin."); oybKrediMasasiEkrani(null, true); } catch (_) {}
}
async function kmPlanGoster(id){
  const tutar = Math.round(+$("#kmTutar" + id).value), kut = $("#kmPlan" + id), btn = $("#kmCek" + id);
  btn.disabled = true;
  try {
    const p = await API.rpc("oyb_kredi_plan", { p_paket: id, p_tutar: tutar });
    kut.innerHTML = kmPlanHtml(p) + (p.uygun ? `<p class="kucuk" style="margin-top:6px">${p.otomatik ? "Onaylarsan kredi hemen cüzdanına geçer." : "Başvurun banka sahibine iletilir; onaylanınca kredi cüzdanına geçer."} Erken kapatırsan yalnız geçen süre kadar faiz ve kalan anaparanın %1'i alınır.</p>` : `<p class="km-engel">${e(p.engel)}</p>`);
    KM.plan = { id, tutar, p }; btn.disabled = !p.uygun;
  } catch (err) { kut.innerHTML = `<p class="km-engel">${e(hataCevir(err.message))}</p>`; }
}
async function kmKrediCek(id){
  const s = KM.plan; if (!s || s.id !== id || s.tutar !== Math.round(+$("#kmTutar" + id).value)) { kmPlanGoster(id); return; }
  if (!await onayla("Kredi sözleşmesi", `<b>${kmTL(s.tutar)}</b> çekiyorsun. ${s.p.taksit_sayisi} taksitte toplam <b>${kmTL(s.p.toplam)}</b> geri ödeyeceksin; son ödeme ${tarihSaat(s.p.son_odeme)}. Taksiti geciktirirsen banka Adliye'de dava açıp gelirine haciz koydurabilir.`, s.p.otomatik ? "Krediyi çek" : "Başvur")) return;
  try { const r = await API.rpc("oyb_kredi_cek", { p_paket: id, p_tutar: s.tutar }); toast(r.durum === "aktif" ? `${kmTL(s.tutar)} cüzdanına geçti.` : "Başvurun banka sahibine iletildi."); KM.plan = null; oybKrediMasasiEkrani(null, true); }
  catch (err) { toast(hataCevir(err.message), true); }
}
async function kmTeklifYanit(id, kabul){
  if (kabul) { const t = (KM.veri.tekliflerim || []).find(x => x.id === id);
    if (!await onayla("Kredi teklifi", `<b>${kmTL(t.tutar)}</b> kullanacaksın; ${t.taksit_sayisi} taksitte toplam <b>${kmTL(t.plan.toplam)}</b> geri ödeyeceksin.`, "Kabul et")) return; }
  try { await islem(() => API.rpc("oyb_kredi_teklif_yanit", { p_id: id, p_kabul: kabul }), kabul ? "Kredi cüzdanına geçti." : "Teklifi reddettin."); oybKrediMasasiEkrani(null, true); } catch (_) {}
}
async function kmTaksitOde(id, tutar){ try { await islem(() => API.rpc("oyb_kredi_ode", { p_id: id, p_tutar: tutar }), "Taksit ödendi."); oybKrediMasasiEkrani(null, true); } catch (_) {} }
async function kmErkenKapat(id){
  const k = (KM.veri.kredilerim || []).find(x => x.id === id), ek = k && k.erken_kapama; if (!ek) return;
  if (!await onayla("Krediyi erken kapat", `Kalan borcun ${kmTL(k.kalan)}. Şimdi kapatırsan <b>${kmTL(ek.tutar)}</b> ödersin: anapara, sürenin %${fmt(ek.gecen_oran, 1)}'i kadar faiz${ek.ucret ? ` ve ${kmTL(ek.ucret)} erken kapama ücreti` : ""}. İndirim: <b>${kmTL(ek.indirim)}</b>.`, "Kapat")) return;
  try { await islem(() => API.rpc("oyb_kredi_erken_kapat", { p_id: id }), "Kredin kapandı."); oybKrediMasasiEkrani(null, true); } catch (_) {}
}

/* ---------------- Banka yönetimi ---------------- */
function kmYonetimHtml(v){
  const sg = v.saglik || {};
  let h = `<div class="kart"><h2>Kasa ve likidite</h2>
    <div class="kv"><span class="k">Banka kasası</span><span class="v">${kmTL(sg.kasa)}</span></div>
    <div class="kv"><span class="k">Mevduat sahiplerine ayrılan güvence</span><span class="v">${kmTL(sg.asgari_likidite)}</span></div>
    <div class="kv"><span class="k">Kredi olarak verilebilecek para</span><span class="v">${kmTL(Math.max(0, sg.kredi_verilebilir))}</span></div>
    <p class="kucuk">Otomatik paketler kasada bu kadar para oldukça kredi verir; para bitince yeni kredi çıkmaz.</p></div>`;
  const bekleyen = (v.banka_kredileri || []).filter(k => k.durum === "basvuru"), aktif = (v.banka_kredileri || []).filter(k => k.durum === "aktif");
  if (bekleyen.length) h += `<div class="kart"><h2>Onay bekleyen başvurular</h2>${bekleyen.map(k => `<div class="km-paket"><b>${e(k.borclu)}</b> · ${kmTL(k.anapara)} · ${kmVade(k.vade_gun)} · %${fmt(k.oran, 2)}
      ${k.risk ? `<div class="kv"><span class="k">Kredi notu / gelirine göre limiti</span><span class="v">${k.risk.kredi_notu} / ${kmTL(k.risk.azami_kredi)}</span></div><p class="kucuk">${e(k.risk.neden || "")}</p>` : ""}
      <div class="km-sat"><button class="btn altin" onclick="kmKarar(${k.id},true)">Onayla</button><button class="btn ikinci" onclick="kmKarar(${k.id},false)">Reddet</button><button class="btn ikinci" onclick="kmBilgiIsteModal('${e(k.borclu)}')">Mali bilgi iste</button></div></div>`).join("")}</div>`;
  h += `<div class="kart"><h2>Kredi paketlerin</h2><p class="alt">Vade (1–30 gün), taksit sayısı, vadenin tamamı için faiz (%0–20), tutar aralığı ve asgari kredi notunu sen belirlersin. "Anında" paketlerde şartları tutan müşteri onayını beklemeden kredi çeker.</p>
    ${(v.paketler || []).map(p => `<div class="km-paket"><div style="display:flex;justify-content:space-between;gap:8px"><b>${e(p.ad)}</b><span class="rozet ${p.aktif ? "yesil" : ""}">${p.aktif ? (p.otomatik ? "Anında" : "Onaylı") : "Kapalı"}</span></div>
      <div><span class="km-cip">${kmVade(p.vade_gun)}</span><span class="km-cip">${p.taksit_sayisi} taksit</span><span class="km-cip">%${fmt(p.faiz, 2)}</span><span class="km-cip">${kmTL(p.min_tutar)} – ${kmTL(p.max_tutar)}</span><span class="km-cip">not ≥ ${p.min_not}</span></div>
      <button class="btn ikinci" onclick="kmPaketModal(${p.id})">Düzenle</button></div>`).join("") || `<p class="alt">Henüz paket yok.</p>`}
    ${(v.paketler || []).length < 8 ? `<button class="btn altin" onclick="kmPaketModal(null)">Yeni kredi paketi</button>` : ""}</div>`;
  h += `<div class="kart"><h2>Açık krediler</h2>${aktif.map(k => `<div class="km-paket"><div style="display:flex;justify-content:space-between;gap:8px"><b>${e(k.borclu)} · #${k.id}</b>${+k.geciken > 0 ? `<span class="rozet kirmizi">Gecikmiş ${kmTL(k.geciken)}</span>` : `<span class="rozet">${k.kaynak === "teklif" ? "Teklif" : k.kaynak === "paket" ? "Paket" : "Başvuru"}</span>`}</div>
      <div class="kv"><span class="k">Kalan / toplam</span><span class="v">${kmTL(k.kalan)} / ${kmTL(k.toplam)}</span></div>
      <div class="kv"><span class="k">Son ödeme</span><span class="v">${tarihSaat(k.vade)}</span></div>
      ${k.icra ? `<p class="kucuk">Adliye icra dosyası #${k.icra.id}: ${e(k.icra.durum)} (${e(k.icra.tur)})</p>` : k.dava_acilabilir ? `<button class="btn tehlike" onclick="kmDavaModal(${k.id},'${e(k.borclu)}')">Adliye'de dava aç / haciz iste</button>` : +k.geciken > 0 ? `<p class="kucuk">Taksit gecikti; 12 saatlik ek süre dolunca dava açabilirsin.</p>` : ""}</div>`).join("") || `<p class="alt">Açık kredi yok.</p>`}</div>`;
  h += `<div class="kart"><h2>Hesap sahipleri</h2><p class="alt">Bankanda hesabı olan oyuncular. Mali bilgilerini isteyebilir, inisiyatif alıp kendi şartlarınla kredi teklif edebilirsin.</p>
    ${(v.hesaplar || []).map(x => `<div class="km-paket"><div style="display:flex;justify-content:space-between;gap:8px"><a href="#" class="bag" onclick="oyuncuKart('${e(x.kad)}');return false"><b>${e(x.kad)}</b></a><span class="kucuk">not ${x.kredi_notu}</span></div>
      <div class="kucuk">${+x.borc > 0 ? `Bankana borcu ${kmTL(x.borc)}` : x.aktif_kredi ? "Başka bir bankada açık kredisi var" : "Açık kredisi yok"}${x.bilgi ? ` · mali bilgi: ${x.bilgi.durum === "izin" ? "izin verdi" : x.bilgi.durum === "ret" ? "reddetti" : "yanıt bekleniyor"}` : ""}${x.teklif ? ` · ${kmTL(x.teklif.tutar)} teklifin bekliyor` : ""}</div>
      <div class="km-sat" style="margin-top:6px"><button class="btn ikinci" onclick="kmBilgiIsteModal('${e(x.kad)}')">Mali bilgi iste</button>
        ${x.bilgi && x.bilgi.durum === "izin" ? `<button class="btn ikinci" onclick="kmDokumGoster('${e(x.kad)}')">Dökümü incele</button>` : ""}
        ${!x.aktif_kredi ? `<button class="btn altin" onclick="kmTeklifModal('${e(x.kad)}')">Kredi teklif et</button>` : ""}</div></div>`).join("") || `<p class="alt">Henüz hesap açan müşterin yok.</p>`}</div>`;
  const gt = (v.gonderilen_teklifler || []);
  if (gt.length) h += `<div class="kart"><h2>Gönderdiğin teklifler</h2>${gt.map(t => `<div class="kv"><span class="k">${e(t.kad)} · ${kmTL(t.tutar)} · ${kmVade(t.vade_gun)} · %${fmt(t.faiz, 2)}<small class="kucuk" style="display:block">${{ teklif: "Bekliyor · son " + tarihSaat(t.son), kabul: "Kabul edildi", ret: "Reddedildi", iptal: "İptal", suresi: "Süresi doldu" }[t.durum] || t.durum}</small></span>${t.durum === "teklif" ? `<button class="btn ikinci" style="width:auto" onclick="kmTeklifIptal(${t.id})">Geri çek</button>` : ""}</div>`).join("")}</div>`;
  return h;
}
async function kmKarar(id, onay){
  if (onay && !await onayla("Kredi onayı", "Kredi tutarı banka kasasından müşterinin cüzdanına geçer.", "Kredi ver")) return;
  try { await islem(() => API.rpc("oyb_kredi_karar", { p_id: id, p_onay: onay }), onay ? "Kredi kullandırıldı." : "Başvuru reddedildi."); oybKrediMasasiEkrani(null, true); } catch (_) {}
}
function kmPaketModal(id){
  const p = id ? (KM.veri.paketler || []).find(x => x.id === id) : { ad: "", vade_gun: 7, taksit_sayisi: 7, faiz: 5, min_tutar: 1000, max_tutar: 50000, otomatik: true, min_not: 900, aktif: true };
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${id ? "Paketi düzenle" : "Yeni kredi paketi"}</h3>
    <div class="alan"><label>Paket adı</label><input id="kpAd" maxlength="40" value="${e(p.ad)}" placeholder="Örn. Esnaf kredisi"></div>
    <div class="alan"><label>Vade (gün)</label><input id="kpVade" type="number" min="1" max="30" value="${p.vade_gun}"></div>
    <div class="alan"><label>Taksit sayısı</label><select id="kpTaksit"></select></div>
    <div class="alan"><label>Faiz (vadenin tamamı için, %)</label><input id="kpFaiz" type="number" min="0" max="20" step="0.1" value="${p.faiz}"></div>
    <div class="alan"><label>En az / en çok tutar (₺)</label><div class="km-sat"><input id="kpMin" type="number" min="1000" step="1000" value="${p.min_tutar}"><input id="kpMax" type="number" max="10000000" step="1000" value="${p.max_tutar}"></div></div>
    <div class="alan"><label>Asgari kredi notu (0–1900)</label><input id="kpNot" type="number" min="0" max="1900" step="50" value="${p.min_not}"></div>
    <label style="display:block;margin:8px 0"><input type="checkbox" id="kpOto" ${p.otomatik ? "checked" : ""}> Anında kredi (şartları tutana onaysız ver)</label>
    <label style="display:block;margin:8px 0"><input type="checkbox" id="kpAktif" ${p.aktif ? "checked" : ""}> Müşterilere açık</label>
    <p class="kucuk" id="kpOrnek"></p>
    <button class="btn altin" id="kpKaydet">Kaydet</button>`);
  const doldur = () => { const g = Math.max(1, Math.min(30, +$("#kpVade", m).value || 1)), sec = kmTaksitSecenek(g), eski = +$("#kpTaksit", m).value || p.taksit_sayisi;
    $("#kpTaksit", m).innerHTML = sec.map(n => `<option value="${n}"${n === (sec.includes(eski) ? eski : sec[sec.length - 1] >= g ? g : 1) ? " selected" : ""}>${n} taksit · ${kmAralik(g, n)}</option>`).join("");
    ornek(); };
  const ornek = () => { const g = +$("#kpVade", m).value, n = +$("#kpTaksit", m).value, f = +$("#kpFaiz", m).value, pl = kmPlanHesap(10000, g, n, f);
    $("#kpOrnek", m).textContent = `Örnek: 10.000 ₺ kredi → ${n} taksitte toplam ${kmTL(pl.toplam)} (faiz geliri ${kmTL(pl.faiz_tutari)}).`; };
  $("#kpVade", m).oninput = doldur; $("#kpTaksit", m).onchange = ornek; $("#kpFaiz", m).oninput = ornek; doldur();
  $("#kpKaydet", m).onclick = async () => {
    try { await islem(() => API.rpc("oyb_paket_kaydet", { p_banka: KM.banka, p_id: id, p_ad: $("#kpAd", m).value, p_vade_gun: +$("#kpVade", m).value, p_taksit: +$("#kpTaksit", m).value,
      p_faiz: +$("#kpFaiz", m).value, p_min: +$("#kpMin", m).value, p_max: +$("#kpMax", m).value, p_otomatik: $("#kpOto", m).checked, p_min_not: +$("#kpNot", m).value, p_aktif: $("#kpAktif", m).checked }), "Kredi paketi kaydedildi.");
      modalKapat(); oybKrediMasasiEkrani(null, true); } catch (_) {}
  };
}
function kmBilgiIsteModal(kad){
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(kad)} adlı müşteriden mali bilgi iste</h3>
    <p class="alt">Oyuncu izin verdiği kadarını paylaşır; izin verdikten sonra dökümü buradan incelersin.</p>
    ${Object.entries(KM_KAPSAM).map(([k, a]) => `<label style="display:block;margin:6px 0"><input type="checkbox" name="kbKap" value="${k}" checked> ${a}</label>`).join("")}
    <button class="btn altin" id="kbGonder">Talebi gönder</button>`);
  $("#kbGonder", m).onclick = async () => {
    const a = [...m.querySelectorAll('input[name="kbKap"]:checked')].map(x => x.value);
    if (!a.length) { toast("En az bir bilgi seç.", true); return; }
    try { await islem(() => API.rpc("oyb_hesap_bilgi_iste", { p_banka: KM.banka, p_kad: kad, p_kapsam: a }), "Talep oyuncuya iletildi."); modalKapat(); oybKrediMasasiEkrani(null, true); } catch (_) {}
  };
}
async function kmDokumGoster(kad){
  let d; try { d = await API.rpc("oyb_hesap_bilgi_dokum", { p_banka: KM.banka, p_kad: kad }); } catch (err) { toast(hataCevir(err.message), true); return; }
  const r = d.dokum || {}, rk = d.risk || {};
  let h = `<h3 style="font-size:19px;font-weight:800">${e(kad)} · mali döküm</h3>
    <div class="kv"><span class="k">Kredi notu</span><span class="v">${rk.kredi_notu ?? "—"} ${e(rk.not_ad || "")}</span></div>
    <div class="kv"><span class="k">7 günlük kredi limiti (sistem)</span><span class="v">${kmTL(rk.azami_kredi)}</span></div>`;
  if (r.maas) h += `<h4 style="margin-top:10px">Maaş ve makam</h4><div class="kv"><span class="k">Günlük net gelir</span><span class="v">${kmTL(r.maas.gunluk_net)}</span></div>`;
  if (r.gunluk) h += `<h4 style="margin-top:10px">Son gelirler</h4>${(r.son_gelirler || []).map(x => `<div class="kv"><span class="k">${e(x.aciklama || x.tur)}<small class="kucuk" style="display:block">${tarihSaat(x.zaman)}</small></span><span class="v">${kmTL(x.tutar)}</span></div>`).join("") || `<p class="kucuk">Gelir kaydı yok.</p>`}`;
  if (r.kira) h += `<h4 style="margin-top:10px">Kira</h4><div class="kv"><span class="k">Haftalık kira geliri</span><span class="v">${kmTL(r.kira.haftalik)}</span></div>`;
  if (r.mulk) { const l = (r.mulk.yatirim_gayrimenkulleri || []).concat(r.mulk.diger_gayrimenkuller || []);
    h += `<h4 style="margin-top:10px">Gayrimenkuller (${l.length})</h4>${l.map(x => `<div class="kv"><span class="k">${e(x.tip || "")} · ${e(x.il || "")}</span><span class="v">${kmTL(x.alis_bedeli)}</span></div>`).join("") || `<p class="kucuk">Gayrimenkulü yok.</p>`}`; }
  if (r.sirket) h += `<h4 style="margin-top:10px">Şirket hisseleri</h4>${r.sirket.map(x => `<div class="kv"><span class="k">${e(x.ad)} · %${fmt(x.pay, 1)}</span><span class="v">${kmTL(x.sermaye_pay_degeri)}</span></div>`).join("") || `<p class="kucuk">Hissesi yok.</p>`}`;
  modal(h);
}
function kmTeklifModal(kad){
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(kad)} adlı müşteriye kredi teklifi</h3>
    <div class="alan"><label>Tutar (₺)</label><input id="ktTutar" type="number" min="1000" step="1000" value="10000"></div>
    <div class="alan"><label>Vade (gün)</label><input id="ktVade" type="number" min="1" max="30" value="7"></div>
    <div class="alan"><label>Taksit sayısı</label><select id="ktTaksit"></select></div>
    <div class="alan"><label>Faiz (vadenin tamamı için, %)</label><input id="ktFaiz" type="number" min="0" max="20" step="0.1" value="5"></div>
    <div class="alan"><label>Mesajın (isteğe bağlı)</label><input id="ktMesaj" maxlength="300"></div>
    <div id="ktPlan"></div>
    <p class="kucuk">Teklif 48 saat geçerlidir; oyuncu ödeme planını görüp kabul ederse kredi banka kasasından kullandırılır.</p>
    <button class="btn altin" id="ktGonder">Teklifi gönder</button>`);
  const doldur = () => { const g = Math.max(1, Math.min(30, +$("#ktVade", m).value || 1)), sec = kmTaksitSecenek(g), eski = +$("#ktTaksit", m).value;
    $("#ktTaksit", m).innerHTML = sec.map(n => `<option value="${n}"${n === (sec.includes(eski) ? eski : 1) ? " selected" : ""}>${n} taksit · ${kmAralik(g, n)}</option>`).join(""); plan(); };
  const plan = () => { const t = Math.round(+$("#ktTutar", m).value || 0); if (t < 1000) { $("#ktPlan", m).innerHTML = ""; return; }
    $("#ktPlan", m).innerHTML = kmPlanHtml(kmPlanHesap(t, +$("#ktVade", m).value, +$("#ktTaksit", m).value, +$("#ktFaiz", m).value)); };
  $("#ktVade", m).oninput = doldur; $("#ktTaksit", m).onchange = plan; $("#ktFaiz", m).oninput = plan; $("#ktTutar", m).oninput = plan; doldur();
  $("#ktGonder", m).onclick = async () => {
    try { await islem(() => API.rpc("oyb_kredi_teklif_ver", { p_banka: KM.banka, p_kad: kad, p_tutar: Math.round(+$("#ktTutar", m).value), p_vade_gun: +$("#ktVade", m).value,
      p_taksit: +$("#ktTaksit", m).value, p_faiz: +$("#ktFaiz", m).value, p_mesaj: $("#ktMesaj", m).value || null }), "Teklif müşteriye iletildi."); modalKapat(); oybKrediMasasiEkrani(null, true); } catch (_) {}
  };
}
async function kmTeklifIptal(id){ try { await islem(() => API.rpc("oyb_kredi_teklif_iptal", { p_id: id }), "Teklif geri çekildi."); oybKrediMasasiEkrani(null, true); } catch (_) {} }
function kmDavaModal(id, kad){
  const m = modal(`<h3 style="font-size:19px;font-weight:800">${e(kad)} hakkında icra davası</h3>
    <p class="alt">Dava Adliye'ye gider; borçlu 24 saat içinde savunma yapar, mahkeme karar verir. Kabul edilirse seçtiğin yoldan tahsil edilir.</p>
    <div class="alan"><label>Tahsil yolu</label><select id="kdTur"><option value="gelir">Gelirine haciz (maaş, kira, şirket gelirinin %25'i)</option><option value="mulk">Gayrimenkulüne haciz</option><option value="hisse">Şirket hissesine haciz</option><option value="karma">Hepsi</option></select></div>
    <div class="alan"><label>Gerekçe (en az 20 karakter)</label><textarea class="alanmetin" id="kdGerekce" maxlength="1500">Borçlu kredi taksitini vadesinde ödemedi; alacağımızın tahsili için icra talep ediyoruz.</textarea></div>
    <button class="btn tehlike" id="kdAc">Davayı aç</button>`);
  $("#kdAc", m).onclick = async () => {
    try { await islem(() => API.rpc("oyb_icra_baslat", { p_kredi: id, p_tur: $("#kdTur", m).value, p_gerekce: $("#kdGerekce", m).value }), "Dava Adliye'ye iletildi."); modalKapat(); oybKrediMasasiEkrani(null, true); } catch (_) {}
  };
}

/* ---------------- Giriş noktaları ---------------- */
(function(){
  const kmGiris = id => `<div class="kart km-giris"><h2>💳 Kredi masası</h2><p class="alt">Hesap aç, paketleri karşılaştır, çekmeden önce ödeme planını gör; krediyi erken kapatırsan faiz indirimi al.</p>
    <button class="btn altin" onclick="ekranAc(()=>oybKrediMasasiEkrani(${+id}))">Kredi masasını aç</button></div>`;
  if (typeof bankaDetayEkrani === "function") {
    const eski = bankaDetayEkrani;
    window.bankaDetayEkrani = bankaDetayEkrani = async function(id){
      const r = await eski.apply(this, arguments);
      try { await API.rpc("oyb_kredi_masasi", { p_banka: +id }); } catch (_) { return r; }   // sunucu modülü yoksa eski ekran olduğu gibi kalır
      try { const ic = $("#icerik");
        if (ic && !ic.querySelector(".vit-bank-layout") && !ic.querySelector(".km-giris")) {
          // Eski "Kredi başvurusu" kartı kredi masasına taşındı
          ic.querySelectorAll(".kart").forEach(k => { const h2 = k.querySelector("h2"); if (h2 && /^Kredi başvurusu/.test(h2.textContent.trim())) k.remove(); });
          const ilk = ic.querySelector(".kart"); (ilk ? ilk : ic).insertAdjacentHTML(ilk ? "afterend" : "afterbegin", kmGiris(id));
        } } catch (_) {}
      return r;
    };
  }
  if (typeof oybYonetim === "function") {
    const eskiY = oybYonetim;
    window.oybYonetim = oybYonetim = async function(id){
      const r = await eskiY.apply(this, arguments);
      try { const ic = $("#icerik");
        if (ic && !ic.querySelector(".km-giris")) ic.insertAdjacentHTML("afterbegin", `<div class="kart km-giris"><h2>💳 Kredi masası</h2><p class="alt">Kredi paketlerini (vade, taksit, faiz, otomatik onay) belirle, müşterilerinden mali bilgi iste, kredi teklif et, geciken borçlular için dava aç.</p>
          <button class="btn altin" onclick="KM.mod='yonetim';ekranAc(()=>oybKrediMasasiEkrani(${+id}))">Kredi masasını yönet</button></div>`);
      } catch (_) {}
      return r;
    };
  }
})();
window.oybKrediMasasiEkrani = oybKrediMasasiEkrani;
