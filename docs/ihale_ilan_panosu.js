/* Belediye hizmetleri ile kamu yapim ihalelerinin ortak ilan ve teklif panosu.
   Mevcut iki ihale motorunun yetki, butce ve kapali zarf kurallari korunur. */
"use strict";
const IP = { tur: "tum", gorunum: "acik", veri: null, islem: false };
const IP_SEKTOR = { insaat: "İnşaat", teknoloji: "Teknoloji", ticaret: "Ticaret", sanayi: "Sanayi", tarim: "Tarım", hizmet: "Hizmet" };
const IP_DURUM = { acik: "Teklife açık", yapim: "Yapımda", is_verildi: "İş teslim bekliyor", tamam: "Tamamlandı", tamamlandi: "Tamamlandı", iptal: "İptal", teklifsiz: "Teklif gelmedi", teklif_yok: "Teklif gelmedi", basarisiz: "Süresinde teslim edilmedi" };

function ipPara(t){ return Number(t || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺"; }
function ipTarih(t){ return t ? new Date(t).toLocaleString("tr-TR", { dateStyle: "short", timeStyle: "short" }) : "—"; }
function ipNum(n){ return Number.isFinite(Number(n)) ? Number(n) : 0; }
function ipSecim(tur, gorunum){ IP.tur = tur; IP.gorunum = gorunum; return ihaleIlanPanosu(); }

function ipKart(x, data){
  const belediye = x._tur === "hizmet";
  const acik = x.durum === "acik" && new Date(belediye ? x.teklif_bit : x.bit).getTime() > Date.now();
  const il = belediye ? x.il + " Belediyesi" : x.kurum_ad;
  const bas = belediye ? x.baslik : x.ad;
  const tutar = belediye ? x.butce : x.tavan;
  const bitis = belediye ? x.teklif_bit : x.bit;
  const teklifSay = belediye ? x.teklif_sayisi : x.teklif_say;
  const teklifim = belediye ? (x.benim_tekliflerim || []) : (x.tekliflerim || []);
  const benim = belediye ? x.teslim_yetkim : x.kazanan_benim;
  const durumYazisi = !acik && x.durum === "acik" ? "Süre doldu · sonuç bekleniyor" : IP_DURUM[x.durum] || x.durum;
  let govde = `<div class="kart ip-kart">
    <div class="ip-ust"><span class="rozet ${acik ? "yesil" : ""}">${belediye ? "Belediye hizmet ihalesi" : "Kamu yapım ihalesi"}</span><span class="rozet ${acik ? "altin" : ""}">${acik ? "Teklife açık" : e(durumYazisi)}</span></div>
    <h2>${e(bas)}</h2><p class="alt">${e(il || "Kamu kurumu")}${belediye ? "" : " · " + e(x.il || "Türkiye")} · ${belediye ? e(IP_SEKTOR[x.sektor] || x.sektor) : "İnşaat"}</p>
    ${belediye && x.aciklama ? `<p class="ip-aciklama">${e(x.aciklama)}</p>` : ""}
    <div class="kv"><span>Azami ihale bedeli</span><b>${ipPara(tutar)}</b></div>
    <div class="kv"><span>Teklif sayısı</span><b>${ipNum(teklifSay)} kapalı zarf</b></div>
    ${acik ? `<div class="kv"><span>Son teklif zamanı</span><b>${ipTarih(bitis)}</b></div>` : ""}`;

  if (acik) {
    if (teklifim.length) govde += `<p class="ip-benim">Senin teklifin: ${teklifim.map(t => ipPara(belediye ? t.teklif : t.tutar)).join(" · ")}</p>`;
    if (belediye) {
      const sirketler = (data.hizmet.sirketlerim || []).filter(s => s.sektor === x.sektor);
      if (sirketler.length) {
        govde += `<div class="alan"><label>Teklif verecek şirket</label><select id="ipS_h${ipNum(x.id)}">${sirketler.map(s => `<option value="${ipNum(s.id)}">${e(s.ad)} · pay %${ipNum(s.pay)}</option>`).join("")}</select></div>
          <div class="alan"><label>Kapalı teklif (${ipPara(Math.ceil(tutar * .6))} – ${ipPara(tutar)})</label><input id="ipT_h${ipNum(x.id)}" type="number" inputmode="numeric" min="${Math.ceil(tutar * .6)}" max="${tutar}" step="1" placeholder="${Math.round(tutar * .9)}"></div>
          <button class="btn altin" onclick="ipTeklifVer('hizmet',${ipNum(x.id)})">Teklif ver / güncelle</button>`;
      } else govde += `<p class="ip-not">Teklif için bu sektörde faal bir şirketin ve en az %25 payın olmalı.</p>`;
      if (x.baskanim && ipNum(teklifSay) === 0) govde += `<button class="btn ikinci" onclick="ipHizmetIptal(${ipNum(x.id)})">İhaleyi iptal et</button>`;
    } else {
      const sirketler = (data.kamu.insaat_sirketlerim || []);
      if (sirketler.length && !x.acan_benim) {
        govde += `<div class="alan"><label>İnşaat şirketi</label><select id="ipS_k${ipNum(x.id)}">${sirketler.map(s => `<option value="${ipNum(s.id)}" ${s.yasak_bit || ipNum(s.deneyim) < ipNum(x.deneyim) ? "disabled" : ""}>${e(s.ad)}${s.yasak_bit ? " · ihale yasağı" : ""}${ipNum(s.deneyim) < ipNum(x.deneyim) ? " · deneyim yetersiz" : ""}</option>`).join("")}</select></div>
          <div class="alan"><label>Kapalı teklif (${ipPara(Math.ceil(tutar * .4))} – ${ipPara(tutar)})</label><input id="ipT_k${ipNum(x.id)}" type="number" inputmode="numeric" min="${Math.ceil(tutar * .4)}" max="${tutar}" step="1000" placeholder="${Math.round(tutar * .85 / 1000) * 1000}"></div>
          <p class="ip-not">Yaklaşık yapım maliyeti ${ipPara(tutar * .7)}; düşük teklif şirketi zarara sokabilir.</p><button class="btn altin" onclick="ipTeklifVer('kamu',${ipNum(x.id)})">Kapalı teklif gönder</button>`;
      } else if (!sirketler.length) govde += `<p class="ip-not">Bu ihale için faal bir inşaat şirketi gerekiyor.</p>`;
      teklifim.forEach(t => { govde += `<button class="btn ikinci" onclick="ipKamuGeri(${ipNum(x.id)},${ipNum(t.sirket_id)})">${e(t.sirket)} teklifini geri çek</button>`; });
    }
  } else if (belediye) {
    if (x.kazanan) govde += `<div class="kv"><span>Kazanan şirket</span><b>${e(x.kazanan)} · ${ipPara(x.kazanan_teklif)}</b></div>`;
    if (x.durum === "is_verildi") {
      govde += `<p class="ip-not">Son teslim: ${ipTarih(x.son_teslim)}</p>`;
      if (benim && Date.now() >= new Date(x.secim_zamani).getTime() + 6 * 3600000) govde += `<button class="btn altin" onclick="ipHizmetTeslim(${ipNum(x.id)})">İşi tamamla, hakedişi al</button>`;
    }
  } else {
    if (x.kazanan) govde += `<div class="kv"><span>Yüklenici</span><b>${e(x.kazanan)}</b></div>`;
    if (x.bedel != null) govde += `<div class="kv"><span>İhale bedeli</span><b>${ipPara(x.bedel)}</b></div>`;
    if (x.durum === "yapim" && benim) govde += `<button class="btn ikinci" onclick="PZ.ihaleSekme='yapim';ekranAc(ihaleEkrani)">Yapım işini yönet</button>`;
  }
  return govde + `</div>`;
}

async function ihaleIlanPanosu(){
  yukleniyor("İhale İlan Panosu");
  const [kR, hR] = await Promise.allSettled([API.rpc("ihale_ekrani"), API.rpc("belediye_is_pazar")]);
  if (kR.status !== "fulfilled" && hR.status !== "fulfilled") {
    iskelet("İhale İlan Panosu", `<div class="kart"><p>${e(hataCevir(kR.reason?.message || hR.reason?.message || "İhaleler yüklenemedi"))}</p><button class="btn ikinci" onclick="ihaleIlanPanosu()">Tekrar dene</button></div>`, { geri: true });
    return;
  }
  const kamu = kR.status === "fulfilled" ? kR.value : { acik: [], yapim: [], biten: [], insaat_sirketlerim: [] };
  const hizmet = hR.status === "fulfilled" ? hR.value : { ihaleler: [], sirketlerim: [] };
  IP.veri = { kamu, hizmet };
  PZ.ihale = kamu;
  const tumu = [...(kamu.acik || []), ...(kamu.yapim || []), ...(kamu.biten || [])].map(x => ({ ...x, _tur: "kamu" }))
    .concat((hizmet.ihaleler || []).map(x => ({ ...x, _tur: "hizmet" })));
  const acik = tumu.filter(x => x.durum === "acik" && new Date(x._tur === "hizmet" ? x.teklif_bit : x.bit).getTime() > Date.now());
  const gosterilecek = tumu.filter(x => (IP.tur === "tum" || IP.tur === x._tur) && (IP.gorunum === "acik"
    ? acik.includes(x) : IP.gorunum === "gecmis" ? !acik.includes(x)
      : x._tur === "hizmet" ? !!(x.benim_tekliflerim || []).length || !!x.teslim_yetkim : !!(x.tekliflerim || []).length || !!x.kazanan_benim));
  gosterilecek.sort((a,b) => IP.gorunum === "acik"
    ? new Date(a._tur === "hizmet" ? a.teklif_bit : a.bit) - new Date(b._tur === "hizmet" ? b.teklif_bit : b.bit)
    : ipNum(b.id) - ipNum(a.id));
  const yetki = (kamu.yetki || {});
  const makam = !!(yetki.belediye_il || (yetki.bakanliklar || []).length);
  const belediyeyim = (D.durum?.profil?.makamlar || []).some(m => m.tur === "bel");
  const buton = (tur, ad, adet) => `<button class="${IP.tur === tur ? "aktif" : ""}" onclick="ipSecim('${tur}',IP.gorunum)">${ad}${adet != null ? " (" + adet + ")" : ""}</button>`;
  let html = `<div class="kart"><h2>📢 Herkesin görebildiği ihale ilanları</h2><p class="alt">Türkiye'deki belediyelerin hizmet ihaleleri ile belediye/bakanlık yapım ihaleleri burada ilan edilir. Şartları sağlayan oyuncu şirketleri kapalı teklif verebilir; diğer oyuncular da süreci ve kazananları izleyebilir.</p>
    <div class="ip-ozet"><div><b>${acik.length}</b><span>Açık ilan</span></div><div><b>${acik.filter(x=>x._tur==="hizmet").length}</b><span>Hizmet</span></div><div><b>${acik.filter(x=>x._tur==="kamu").length}</b><span>Yapım</span></div></div>
    <button class="btn ikinci" onclick="ihaleIlanPanosu()">↻ İlanları yenile</button></div>
    ${(kR.status !== "fulfilled" || hR.status !== "fulfilled") ? `<div class="kart ip-not">Bir ihale kaynağı yüklenemedi; diğer ilanlar gösteriliyor.</div>` : ""}
    <div class="segment ip-segment">${buton("tum", "Tümü", acik.length)}${buton("hizmet", "Belediye hizmet", acik.filter(x=>x._tur==="hizmet").length)}${buton("kamu", "Kamu yapım", acik.filter(x=>x._tur==="kamu").length)}</div>
    <div class="segment ip-segment"><button class="${IP.gorunum==="acik"?"aktif":""}" onclick="ipSecim(IP.tur,'acik')">Teklife açık</button><button class="${IP.gorunum==="benim"?"aktif":""}" onclick="ipSecim(IP.tur,'benim')">İhalelerim</button><button class="${IP.gorunum==="gecmis"?"aktif":""}" onclick="ipSecim(IP.tur,'gecmis')">Sonuçlar</button></div>
    ${gosterilecek.length ? gosterilecek.map(x => ipKart(x, IP.veri)).join("") : `<div class="kart"><p class="alt">Bu kategoride ilan bulunmuyor. Yeni ihale açıldığında burada görünecek.</p></div>`}
    ${belediyeyim || makam ? `<div class="kart"><h2>İhale açma masası</h2><p class="alt">Yalnızca yetkili belediye başkanı veya bakan kendi kurumunun bütçesinden ihale açabilir.</p>
      ${belediyeyim ? `<button class="btn altin" onclick="ekranAc(belediyeHizmetIhaleEkrani)">Belediye hizmet ihalesi aç</button>` : ""}
      ${makam ? `<button class="btn ikinci" onclick="PZ.ihaleSekme='masa';ekranAc(ihaleEkrani)">Kamu yapım ihalesi aç</button>` : ""}</div>` : ""}
    <div class="kart"><p class="ip-not">Teklifler sonuçlanana kadar diğer şirketlere açıklanmaz. İlgili sektörde şirketi olmayanlar Ekonomi → Şirketler menüsünden şirket kurabilir. Belediye başkanının ortak olduğu şirket, o belediyenin ihalesine katılamaz.</p></div>`;
  iskelet("İhale İlan Panosu", html, { geri: true });
}

async function ipTeklifVer(tur, id){
  if (IP.islem) return;
  const k = (tur === "hizmet" ? "h" : "k") + Number(id);
  const sirket = Number(document.getElementById("ipS_" + k)?.value);
  const tutar = Number(document.getElementById("ipT_" + k)?.value);
  const tum = IP.veri && (tur === "hizmet" ? IP.veri.hizmet.ihaleler : IP.veri.kamu.acik);
  const ilan = (tum || []).find(x => Number(x.id) === Number(id));
  const ust = Number(tur === "hizmet" ? ilan?.butce : ilan?.tavan);
  const alt = Math.ceil(ust * (tur === "hizmet" ? .6 : .4));
  if (!ilan || !Number.isSafeInteger(sirket) || sirket <= 0 || !Number.isSafeInteger(tutar) || tutar < alt || tutar > ust) {
    toast("Şirketini seç ve şartname aralığında tam TL tutarı yaz.", true); return;
  }
  IP.islem = true;
  try {
    await API.rpc(tur === "hizmet" ? "belediye_is_teklif_ver" : "ihale_teklif", { p_ihale: Number(id), p_sirket: sirket, p_tutar: tutar });
    toast("Kapalı teklifin kaydedildi. Sonuç teklif süresi bitince açıklanacak."); await ihaleIlanPanosu();
  } catch(err) { toast(hataCevir(err.message), true); }
  finally { IP.islem = false; }
}
async function ipKamuGeri(id, sirket){
  if (IP.islem || !await onayla("Teklifi geri çek", "Teklif süresi bitmeden zarfını geri çekmek istiyor musun?", "Geri çek")) return;
  IP.islem = true;
  try { await API.rpc("ihale_teklif_geri", { p_ihale: Number(id), p_sirket: Number(sirket) }); toast("Teklif geri çekildi."); await ihaleIlanPanosu(); }
  catch(err) { toast(hataCevir(err.message), true); } finally { IP.islem = false; }
}
async function ipHizmetTeslim(id){
  if (IP.islem || !await onayla("İşi teslim et", "Hizmet tamamlandı mı? Onaylayınca hakediş şirket kasasına aktarılır.", "Teslim et")) return;
  IP.islem = true;
  try { await API.rpc("belediye_is_tamamla", { p_ihale: Number(id) }); toast("Hizmet teslim edildi, ödeme gerçekleşti."); await ihaleIlanPanosu(); }
  catch(err) { toast(hataCevir(err.message), true); } finally { IP.islem = false; }
}
async function ipHizmetIptal(id){
  if (IP.islem || !await onayla("İhaleyi iptal et", "Teklif almamış ilanı iptal edince bütçe belediye kasasına döner.", "İptal et")) return;
  IP.islem = true;
  try { await API.rpc("belediye_is_iptal", { p_ihale: Number(id) }); toast("İhale iptal edildi."); await ihaleIlanPanosu(); }
  catch(err) { toast(hataCevir(err.message), true); } finally { IP.islem = false; }
}

(function(){
  if (!document.getElementById("ipStil")) {
    const css = document.createElement("style"); css.id = "ipStil";
    css.textContent = `.ip-ozet{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:14px 0}.ip-ozet>div{background:var(--panel2);padding:12px 8px;border-radius:10px;text-align:center}.ip-ozet b{display:block;font-size:24px;font-family:var(--disp)}.ip-ozet span{display:block;color:var(--txt2);font-size:12px}.ip-segment{margin:10px 0;overflow-x:auto}.ip-segment button{white-space:nowrap}.ip-ust{display:flex;flex-wrap:wrap;gap:7px;margin-bottom:8px}.ip-kart h2{margin-bottom:4px;overflow-wrap:anywhere}.ip-aciklama{white-space:pre-wrap;overflow-wrap:anywhere;margin:12px 0}.ip-benim{color:var(--good);font-weight:700;margin:12px 0}.ip-not{font-size:12px;line-height:1.5;color:var(--txt2);margin:10px 0}`;
    document.head.appendChild(css);
  }
})();
window.ihaleIlanPanosu = ihaleIlanPanosu;
