/* Sehir yonetimi: bina, butce, ekonomi */

const BM=(v)=>fmt(Number(v)||0,4)+" mlr ₺";
async function belediyeSehirYonetimEkrani(){
 yukleniyor("Şehir Yönetimi");
 let x;try{x=await API.rpc("belediye_sehir_paneli");}catch(err){iskelet("Şehir Yönetimi",`<div class="kart">${e(hataCevir(err.message))}</div>`,{geri:D.yigin.length>0});return;}
 if(!x){iskelet("Şehir Yönetimi",`<div class="kart">Yalnızca görevdeki belediye başkanları şehir yönetimini kullanabilir.</div>`,{geri:D.yigin.length>0});return;}
 D._belediyeSehir=x;
 const mode=D._belediyeSehirMod||"ozet",bn=x.binalar||[],pg=x.programlar||[], hareket=x.hareketler||[];
 const gel=Number(x.temel_gelir)+Number(x.bina_gelir), gider=Number(x.temel_gider)+Number(x.bina_gider);
 const ana=`<div class="kart"><h2>🏙️ ${e(x.il_ad)} · Belediye Başkanlığı</h2><p class="alt">Hizmet, bütçe, ekonomi, bina ve yatırımlar için şehir simülasyonu.</p>
 <div class="segment" style="display:flex;flex-wrap:wrap;gap:5px">${[["ozet","Bütçe"],["binalar","Binalar"],["ekonomi","Ekonomi"],["hareket","İşlem defteri"]].map(([k,ad])=>`<button class="${mode===k?"aktif":""}" onclick="belediyeSehirMod('${k}')">${ad}</button>`).join("")}</div></div>`;
 let icerik="";
 if(mode==="ozet"){
  icerik=`<div class="kart"><h2>Şehrin güncel durumu</h2>
  <div class="gosterge"><div><div class="ad">Belediye kasası</div><div class="deger">${fmt(x.kasa,3)}<small class="kucuk"> mlr ₺</small></div></div><div><div class="ad">Memnuniyet</div><div class="deger">${fmt(x.memnuniyet,1)}</div></div><div><div class="ad">Gelişmişlik</div><div class="deger">${fmt(x.gelisim,1)}</div></div></div>
  ${[["Günlük temel gelir",x.temel_gelir],["Binaların günlük geliri",x.bina_gelir],["Günlük temel gider",-Number(x.temel_gider)],["Binaların günlük bakımı",-Number(x.bina_gider)],["Tahmini günlük net gelir",gel-gider]].map(([k,v])=>`<div class="kv"><span class="k">${k}</span><span class="v ${Number(v)>=0?"iyi":"kotu"}">${v>0?"+":""}${BM(v)}</span></div>`).join("")}
  ${[["Çalışan binalar",bn.filter(v=>v.durum==="aktif").length],["Yapımı devam edenler",bn.filter(v=>v.durum==="insa").length],["Hizmet istihdamı (simülasyon)",x.istihdam],["Hizmet kapasitesi",x.kapasite],["Çevre puanı katkısı",x.cevre]].map(([k,v])=>`<div class="kv"><span class="k">${k}</span><span class="v">${fmt(v)}</span></div>`).join("")}
  <p class="kucuk">Binaların gelirleri ve bakım giderleri günlük tahsil edilir; inşaat bedelleri ayrıca kasadan düşer.</p></div>
  <div class="kart"><h2>Başkanlık işlemleri</h2><button class="btn altin" onclick="ekranAc(belediyeEkrani)">Vergiler, sosyal yardımlar, hizmetler ve eski yatırımlar</button>
  <button class="btn ikinci" onclick="ekranAc(belediyeHizmetIhaleEkrani)">Belediye şirket ihaleleri</button></div>`;
 }else if(mode==="binalar"){
  const groups=[...new Set(bn.map(v=>v.kategori))];
  icerik=`<div class="kart"><h2>Belediye binaları</h2><p class="alt">20 bina çeşidi · 3 geliştirme seviyesi. İnşaatlar süreyle tamamlanır; tamamlandıklarında şehrin gelişmişlik ve memnuniyet puanını artırır. Bakım ve gelirler her gün otomatik hesaplanır.</p></div>`+
  groups.map(g=>`<details class="kart" ${bn.some(v=>v.kategori===g&&v.durum!=="yok")?"open":""}><summary style="cursor:pointer;font-weight:800">${e(g)} (${bn.filter(v=>v.kategori===g).length})</summary>`+
  bn.filter(v=>v.kategori===g).map(v=>{
   const empty=v.durum==="yok",ask=v.durum==="askida",ins=v.durum==="insa",full=v.seviye>=3;
   const tur=empty?"insa":ask?"yeniden_ac":"yukselt";
   const bedel=empty?v.maliyet:ask?v.yeniden_ac_maliyet:v.yukseltme_maliyet;
   const ok=!ins&&!full&&Number(x.kasa)>=Number(bedel);
   return `<div style="padding:10px 0;border-bottom:1px solid #7775"><div style="display:flex;justify-content:space-between;gap:8px"><b>${e(v.ad)}</b><span class="rozet ${v.durum==="aktif"?"yesil":"altin"}">${empty?"Yok":ins?"İnşaat":ask?"Askıda":"Seviye "+v.seviye}</span></div>
   <p class="kucuk">${e(v.aciklama)}</p>
   <div class="kv"><span class="k">Günlük bakım / gelir (seviye başına)</span><span class="v">−${BM(v.gunluk_bakim)} / +${BM(v.gunluk_gelir)}</span></div>
   <div class="kv"><span class="k">Gelişim / memnuniyet</span><span class="v">+${fmt(v.gelisim)} / +${fmt(v.memnuniyet)}</span></div>
   <div class="kv"><span class="k">İstihdam / kapasite</span><span class="v">${fmt(v.istihdam)} / ${fmt(v.kapasite)}</span></div>
   ${ins?`<p class="kucuk">Tamamlanma: ${tarihSaat(v.bitis)} · Hedef seviye ${v.hedef}</p>`:`<div class="kv"><span class="k">Yatırım bedeli</span><span class="v">${full?"—":BM(bedel)}</span></div>`}
   <button class="btn ${ok?"altin":"ikinci"}" ${ok?"":"disabled"} onclick="belediyeSehirBina('${e(v.kod)}','${tur}')">${ins?"İnşaat sürüyor":full?"Azami seviye":!ok?"Bütçe yetersiz":empty?"İnşa et":ask?"Tekrar aç":"Seviye yükselt"}</button></div>`;
  }).join("")+"</details>").join("");
 }else if(mode==="ekonomi"){
  const kilit=x.son_program&&simdi()-new Date(x.son_program).getTime()<12*3600000;
  icerik=`<div class="kart"><h2>Ekonomik kararlar</h2><p class="alt">Esnaf, turizm, istihdam ve altyapı yatırımlarıyla şehir ekonomisine müdahale et. Bir karar 12 saatte bir; aynı program 48 saatte bir tekrarlanabilir.</p></div>`+
  pg.map(v=>{const bekle=!!(v.son&&simdi()-new Date(v.son).getTime()<48*3600000),ok=!kilit&&!bekle&&Number(x.kasa)>=Number(v.maliyet);
  return `<div class="kart"><h3>${e(v.ad)}</h3><p class="kucuk">${e(v.aciklama)}</p>
   <div class="kv"><span class="k">Maliyet</span><span class="v">${BM(v.maliyet)}</span></div>
   <div class="kv"><span class="k">Gelişim / memnuniyet</span><span class="v">+${fmt(v.gelisim)} / +${fmt(v.memnuniyet)}</span></div>
   <div class="kv"><span class="k">Hedeflenen istihdam (gösterge)</span><span class="v">${fmt(v.istihdam)}</span></div>
   ${v.son?`<p class="kucuk">En son: ${tarihSaat(v.son)}</p>`:""}
   <button class="btn ${ok?"altin":"ikinci"}" ${ok?"":"disabled"} onclick="belediyeSehirKarar('${e(v.kod)}')">${kilit?"12 saatlik bekleme":bekle?"48 saatlik program sınırı":Number(x.kasa)<Number(v.maliyet)?"Bütçe yetersiz":"Kararı uygula"}</button></div>`;}).join("");
 }else{
  icerik=`<div class="kart"><h2>Son belediye mali hareketleri</h2><p class="alt">Yatırımlar, bakım giderleri, bina kazançları ve alınan kararlar.</p>${hareket.map(v=>`<div class="kv"><span class="k">${e(v.aciklama)}<small class="kucuk" style="display:block">${tarihSaat(v.zaman)}</small></span><span class="v ${Number(v.tutar)>=0?"iyi":"kotu"}">${BM(v.tutar)}</span></div>`).join("")||'<p class="alt">Henüz kayıt yok.</p>'}</div>`;
 }
 iskelet("Şehir Yönetimi",ana+icerik,{geri:D.yigin.length>0});
}
function belediyeSehirMod(k){D._belediyeSehirMod=k;belediyeSehirYonetimEkrani();}
async function belediyeSehirBina(kod,tur){
 const d=D._belediyeSehir,v=d.binalar.find(x=>x.kod===kod),bedel=tur==="insa"?v.maliyet:tur==="yeniden_ac"?v.yeniden_ac_maliyet:v.yukseltme_maliyet;
 if(!await onayla(e(v.ad),`Kasadan <b>${BM(bedel)}</b> harcanacak. Yeni bina ve yükseltmeler günlük bakım gideri gerektirir.`, "Yatırımı onayla"))return;
 try{await API.rpc("belediye_bina_islem",{p_kod:kod,p_islem:tur});toast("Yatırım başlatıldı.");belediyeSehirYonetimEkrani();}catch(err){toast(hataCevir(err.message),true);}
}
async function belediyeSehirKarar(kod){
 const d=D._belediyeSehir,v=d.programlar.find(x=>x.kod===kod);
 if(!await onayla(e(v.ad),`Şehir bütçesinden <b>${BM(v.maliyet)}</b> harcanacak. Memnuniyet +${fmt(v.memnuniyet)} ve gelişmişlik +${fmt(v.gelisim)} olarak etkilenecek.`, "Kararı uygula"))return;
 try{await API.rpc("belediye_ekonomi_programi",{p_kod:kod});toast("Ekonomik karar uygulandı.");belediyeSehirYonetimEkrani();}catch(err){toast(hataCevir(err.message),true);}
}
window.belediyeSehirYonetimEkrani=belediyeSehirYonetimEkrani;
window.belediyeSehirMod=belediyeSehirMod;
window.belediyeSehirBina=belediyeSehirBina;
window.belediyeSehirKarar=belediyeSehirKarar;
