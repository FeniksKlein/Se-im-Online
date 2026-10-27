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
      ${cb ? `<button class="btn altin" onclick="cbTorenAc()">🇹🇷 Yemin törenim ve ulusa sesleniş</button>` : ""}
      ${cb ? `<button class="btn ikinci" onclick="sekmeAc('meclis')">Meclis ve onay bekleyen kanunlar</button>` : ""}
      ${cb && typeof devletButcesiEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(devletButcesiEkrani)">Devlet bütçesi · ek ödenek talepleri</button>` : ""}
      ${cb && ihaleVar ? `<button class="btn ikinci" onclick="PZ.ihaleSekme='masa';ekranAc(ihaleEkrani)">Kamu ihaleleri (bakanı olmayan bakanlıklar)</button>` : ""}</div>`;
  }

  // 3) Bakanlık — paneller doğrudan burada
  if (bakan) {
    h += `<div class="kart ynt-bolum"><h2>Bakanlık yönetim masası</h2><p class="alt">Bu kararlar yalnızca görevli olduğun bakanlıklara aittir. İcraat bedeli bakanlık kasasından karşılanır.</p>
      ${ihaleVar ? `<button class="btn ikinci" onclick="PZ.ihaleSekme='masa';ekranAc(ihaleEkrani)">Kamu ihalesi aç / yönet</button>` : ""}
      ${typeof bakanSoruEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(bakanSoruEkrani)">Soru önergeleri</button>` : ""}
      ${typeof bakanlikEtkinlikleriEkrani === "function" ? `<button class="btn ikinci" onclick="ekranAc(bakanlikEtkinlikleriEkrani)">Bakanlık etkinlikleri</button>` : ""}</div>`;
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


/* Yeni cumhurbaşkanına karşılama, yemin ve ulusa sesleniş sahnesi.
   Yetkiyi cihaz değil, Supabase'deki aktif seçimle atanmış makam belirler. */
(function(){
"use strict";
const st=document.createElement("style");
st.textContent=".cbtor-bg{position:fixed;inset:0;z-index:9999;background:radial-gradient(circle at top,#28476f,#071025 75%);color:#f8f1e1;display:flex;align-items:center;justify-content:center;padding:12px;overflow-y:auto}.cbtor-panel{position:relative;width:min(100%,540px);max-height:96vh;overflow-y:auto;background:linear-gradient(145deg,#172d55,#0a1833);border:1px solid #b69b57;border-radius:20px;padding:28px 19px;text-align:center;box-shadow:0 20px 80px #000a}.cbtor-panel h1{font-size:clamp(26px,7vw,38px);line-height:1.15;color:#ffe3a1;margin:13px 0}.cbtor-panel h2{font-size:19px;margin:9px 0;color:white}.cbtor-panel p{font-size:15px;color:#dde4f1;line-height:1.7;margin:10px 0}.cbtor-selam{font-size:54px;animation:cbtor-parla 2s ease-in-out infinite}.cbtor-kucuk{font-size:11px;color:#d9be81;letter-spacing:.12em;font-weight:800}.cbtor-yemin{text-align:left;background:#071229;padding:16px;border-left:4px solid #e2be6c;font:17px/1.8 Georgia,serif;margin:15px 0}.cbtor-panel .cbtor-btn{display:block;width:100%;padding:14px;margin:13px 0 0;border-radius:10px;background:linear-gradient(95deg,#d3aa58,#f7db9b);color:#171e32;font-weight:900}.cbtor-btn:disabled{opacity:.55}.cbtor-panel .cbtor-alt{display:block;width:100%;border:1px solid #7184a2;border-radius:10px;color:white;padding:12px;margin-top:8px}.cbtor-kapat{position:absolute;right:10px;top:9px;color:#fff;background:#30476b;border-radius:50%;width:34px;height:34px;font-size:21px}.cbtor-textarea{width:100%;min-height:190px;border:1px solid #7890b2;border-radius:10px;background:#07152d;color:#fff;padding:13px;font-size:15px;line-height:1.6;resize:vertical}.cbtor-kurdele{height:4px;background:linear-gradient(90deg,#bd273a 0 40%,#fff 40% 60%,#bd273a 60%);margin:20px auto;width:80%;border-radius:6px}@keyframes cbtor-parla{50%{transform:scale(1.07);filter:drop-shadow(0 0 12px #ffe28b)}}@media(prefers-reduced-motion:reduce){.cbtor-selam{animation:none}}";
document.head.appendChild(st);
const yemin="Cumhurbaşkanı sıfatıyla devletin bağımsızlığını, milletin birliğini, Anayasa'yı, demokrasiyi ve hukukun üstünlüğünü koruyacağıma; görevimi tarafsızlık ve adaletle yerine getireceğime namusum ve şerefim üzerine ant içerim.";
const taslak="Aziz milletim,\n\nBugün sandıktan çıkan iradenizle Cumhurbaşkanlığı görevini devralıyorum. Bana duyduğunuz güven için teşekkür ediyorum.\n\nBu makamı tüm vatandaşların ortak emaneti görüyorum. Demokrasiyi, adaleti ve refahı güçlendirmek, farklı seslere kulak vermek için çalışacağım.\n\nGelin, geleceği birlikte inşa edelim.";
let acik=false,sonDeneme=0,sonMakam=null,kontrolEdiliyor=false;
function ses(){
 try{
  const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;
  const c=new Audio(),now=c.currentTime;
  [392,494,587,784].forEach(function(freq,i){
   const o=c.createOscillator(),v=c.createGain(),t=now+i*.22;
   o.type="triangle";o.frequency.value=freq;o.connect(v);v.connect(c.destination);
   v.gain.setValueAtTime(.0001,t);v.gain.exponentialRampToValueAtTime(.08,t+.04);
   v.gain.exponentialRampToValueAtTime(.0001,t+.28);o.start(t);o.stop(t+.3);
  });
  setTimeout(function(){c.close().catch(function(){});},1800);
 }catch(_){}
}
function kapat(){const d=document.getElementById("cbToreni");if(d)d.remove();acik=false;}
function ekran(baslik,govde){
 kapat();const d=document.createElement("div");d.id="cbToreni";d.className="cbtor-bg";
 d.innerHTML='<section class="cbtor-panel" role="dialog" aria-modal="true"><button class="cbtor-kapat" id="cbKapat" aria-label="Kapat">×</button><div class="cbtor-kucuk">SEÇİM SİMÜLASYONU ONLINE · CUMHURBAŞKANLIĞI</div><div class="cbtor-selam">🇹🇷</div><div class="cbtor-kurdele"></div><h1>'+e(baslik)+'</h1>'+govde+'<div class="cbtor-kurdele"></div><div class="cbtor-kucuk">Halkın iradesiyle · Yeni dönem</div></section>';
 document.body.appendChild(d);d.querySelector("#cbKapat").onclick=kapat;acik=true;return d;
}
function giris(t){
 const d=ekran("Milletin Yeni Cumhurbaşkanı",'<h2>Sayın '+e(t.kad)+', hoş geldiniz!</h2><p>Sandıktan çıkan sonuçlarla Cumhurbaşkanlığı makamını devraldınız. Cumhurbaşkanlığı kapıları açıldı. Tören kıtası ve bütün ülke sizi selamlıyor.</p><p>🎖️ Tebrik · 📜 Yemin töreni · 🎙️ Ulusa sesleniş</p><button class="cbtor-btn" id="cbBasla">Töreni başlat · Selamlama fanfarı</button><button class="cbtor-alt" id="cbSonra">Daha sonra</button>');
 d.querySelector("#cbBasla").onclick=function(){ses();yeminSayfa(t);};
 d.querySelector("#cbSonra").onclick=kapat;
}
function yeminSayfa(t){
 if(t.yemin_at){hitapSayfa(t);return;}
 const d=ekran("Cumhurbaşkanlığı Yemin Töreni",'<p>Meclis Genel Kurulu ve millet sizi dinliyor. Göreve başlama yeminini okuyun.</p><div class="cbtor-yemin">“'+e(yemin)+'”</div><button class="cbtor-btn" id="cbYemin">✋ Yemin ediyorum</button><p>Yemininiz, seçildiğiniz görev dönemiyle birlikte kayda alınacak.</p>');
 d.querySelector("#cbYemin").onclick=async function(){
  const b=this;b.disabled=true;b.textContent="Yemin kaydediliyor…";
  try{const r=await API.rpc("cb_yemin_et");t.yemin_at=r.yemin_at;ses();hitapSayfa(t);}
  catch(err){b.disabled=false;b.textContent="✋ Yemin ediyorum";toast(hataCevir(err.message),true);}
 };
}
function hitapSayfa(t){
 if(t.hitap_at){bitisSayfa(t);return;}
 const d=ekran("İlk Ulusa Sesleniş",'<p>Cumhurbaşkanlığı kürsüsündesiniz. Konuşmanızı yazın; ülke gündeminde ve tüm oyuncuların okuyabileceği arşivde yayımlansın.</p><textarea id="cbHitap" maxlength="2000" class="cbtor-textarea" aria-label="Ulusa sesleniş metni"></textarea><p>30–2000 karakter · Metni dilediğiniz gibi değiştirebilirsiniz.</p><button class="cbtor-btn" id="cbYayin">🎙️ Ulusa seslenişi yayımla</button><button class="cbtor-alt" id="cbSonra">Konuşmayı sonra yapacağım</button>');
 d.querySelector("#cbHitap").value=taslak;
 d.querySelector("#cbSonra").onclick=kapat;
 d.querySelector("#cbYayin").onclick=async function(){
  const b=this,metin=d.querySelector("#cbHitap").value.trim();
  if(metin.length<30||metin.length>2000){toast("Konuşma 30–2000 karakter olmalı.",true);return;}
  b.disabled=true;b.textContent="Yayımlanıyor…";
  try{const r=await API.rpc("cb_ulusa_seslen",{p_metin:metin});t.hitap_at=r.hitap_at;ses();bitisSayfa(t);}
  catch(err){b.disabled=false;b.textContent="🎙️ Ulusa seslenişi yayımla";toast(hataCevir(err.message),true);}
 };
}
function bitisSayfa(t){
 const d=ekran("Tören Tamamlandı",'<h2>Tebrikler, Cumhurbaşkanı '+e(t.kad)+'!</h2><p>Yemininiz ve ilk ulusa seslenişiniz arşive kaydedildi. Yeni dönemin ilk günü başladı.</p><button class="cbtor-btn" id="cbMakam">🏛️ Makamıma geç</button><button class="cbtor-alt" id="cbArsiv">📜 Konuşma arşivi</button>');
 d.querySelector("#cbMakam").onclick=function(){kapat();sekmeAc("yonetim");};
 d.querySelector("#cbArsiv").onclick=function(){kapat();ekranAc(window.cbUlusaSeslenislerEkrani);};
}
window.cbTorenAc=async function(){
 if(acik)return;
 try{const t=await API.rpc("cb_toren_durum");if(!t||!t.secim_id){toast("Tören yalnızca seçimle göreve gelmiş cumhurbaşkanına açıktır.",true);return;}
  if(t.hitap_at)bitisSayfa(t);else if(t.yemin_at)hitapSayfa(t);else giris(t);
 }catch(err){toast("Tören servisi henüz hazır değil: "+hataCevir(err.message),true);}
};
window.cbUlusaSeslenislerEkrani=async function(){
 yukleniyor("Ulusa seslenişler");
 try{
  const l=await API.rpc("cb_seslenisler");
  const h=Array.isArray(l)&&l.length?l.map(function(a){
   return '<div class="kart"><h3>🎙️ '+e(a.kad)+'</h3><p class="kucuk">'+tarihSaat(a.hitap_at)+'</p><p style="white-space:pre-wrap;line-height:1.8;margin-top:12px">'+e(a.hitap_metin)+'</p></div>';
  }).join(""):'<div class="kart"><p class="alt">Henüz yayımlanmış bir konuşma yok.</p></div>';
  iskelet("Ulusa seslenişler",h,{geri:true});
 }catch(err){iskelet("Ulusa seslenişler",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
};
// Her oyuncu Devlet sekmesinden ulusa sesleniş arşivini açabilir.
const eskiIskelet=iskelet;
iskelet=function(baslik,govde,sec){
 if(baslik==="Devlet"||baslik==="Devlet yönetimi")
  govde='<div class="kart"><button class="btn ikinci" onclick="ekranAc(cbUlusaSeslenislerEkrani)">🎙️ Cumhurbaşkanlarının ulusa seslenişleri</button></div>'+govde;
 return eskiIskelet(baslik,govde,sec);
};
// Seçimden sonra yenilenen profil ilk defa CB yetkisi aldığında açılır.
const eskiDurum=durumYenile;
durumYenile=async function(){
 const r=await eskiDurum.apply(this,arguments),p=r&&r.profil;
 if(p&&Array.isArray(p.makamlar)&&p.makamlar.some(x=>x.tur==='cb')&&!acik&&!kontrolEdiliyor&&Date.now()-sonDeneme>30000){
  sonDeneme=Date.now();kontrolEdiliyor=true;
  Promise.resolve().then(async function(){
   try{
    const t=await API.rpc("cb_toren_durum");
    if(t&&t.secim_id&&!t.hitap_at&&sonMakam!==String(t.makam_id)){
     const key="cb_yeni_makam_"+t.makam_id;let goruldu=false;
     try{goruldu=sessionStorage.getItem(key)==="1";}catch(_){}
     if(!goruldu){
      sonMakam=String(t.makam_id);
      try{sessionStorage.setItem(key,"1");}catch(_){}
      setTimeout(function(){if(!acik)giris(t);},600);
     }
    }
   }catch(_){}finally{kontrolEdiliyor=false;}
  });
 }
 return r;
};
})();
