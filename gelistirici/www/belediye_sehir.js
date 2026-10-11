/* Sehir yonetimi: butce, hizmet karnesi, kriz masasi, binalar, ekonomi, borc, islem defteri */

// Kamu kasaları milyar ₺ tutulur; küçük tutarlar milyon/bin olarak yazılır.
function kasaYaz(v){
 const n=Number(v)||0,a=Math.abs(n);
 if(a>=1)return fmt(n,2)+" milyar ₺";
 if(a>=0.001)return fmt(n*1000,1)+" milyon ₺";
 if(a===0)return "0 ₺";
 return fmt(n*1e6,0)+" bin ₺";
}
const BM=(v)=>kasaYaz(v);
function karneRenk(p){return p>=65?"var(--good)":p>=45?"var(--warn)":"var(--al)";}
function karneCubuk(a){
 return `<div style="padding:8px 0;border-bottom:1px solid var(--line)"><div style="display:flex;justify-content:space-between;gap:8px"><b style="font-size:14px">${e(a.ad)}</b><b style="color:${karneRenk(a.puan)}">${fmt(a.puan,1)}</b></div>
 <div style="height:7px;border-radius:4px;background:var(--panel2);margin-top:6px;overflow:hidden"><div style="height:100%;width:${Math.max(2,Math.min(100,a.puan))}%;background:${karneRenk(a.puan)}"></div></div>
 ${(a.katkilar||[]).length?`<div class="kucuk" style="margin-top:5px">${a.katkilar.map(k=>`${e(k.kaynak)} <b style="color:${k.puan>=0?"var(--good)":"var(--al2)"}">${k.puan>0?"+":""}${fmt(k.puan,1)}</b>`).join(" · ")}</div>`:`<div class="kucuk" style="margin-top:5px">${e(a.aciklama)}</div>`}</div>`;
}
function kalanSure(t){const ms=new Date(t).getTime()-simdi();if(ms<=0)return "süre doldu";const s=Math.floor(ms/3600000),d=Math.floor(ms%3600000/60000);return s>0?`${s} sa ${d} dk`:`${d} dk`;}

async function belediyeSehirYonetimEkrani(){
 yukleniyor("Şehir Yönetimi");
 let x,dt=null;
 try{[x,dt]=await Promise.all([API.rpc("belediye_sehir_paneli"),API.rpc("belediye_detay_paneli").catch(()=>null)]);}
 catch(err){iskelet("Şehir Yönetimi",`<div class="kart">${e(hataCevir(err.message))}</div>`,{geri:D.yigin.length>0});return;}
 if(!x){iskelet("Şehir Yönetimi",`<div class="kart">Yalnızca görevdeki belediye başkanları şehir yönetimini kullanabilir.</div>`,{geri:D.yigin.length>0});return;}
 D._belediyeSehir=x;D._belediyeDetay=dt;
 const sekmeler=[["ozet","Bütçe"],...(dt?[["karne","Karne"],["kriz","Kriz"+(dt.kriz?" (1)":"")]]:[]),["binalar","Binalar"],["ekonomi","Ekonomi"],...(dt?[["borc","İller Bankası"]]:[]),["hareket","İşlem defteri"]];
 let mode=D._belediyeSehirMod||"ozet"; if(!sekmeler.some(s=>s[0]===mode))mode="ozet";
 const bn=x.binalar||[],pg=x.programlar||[],hareket=x.hareketler||[];
 const gel=Number(x.temel_gelir)+Number(x.bina_gelir),gider=Number(x.temel_gider)+Number(x.bina_gider);
 const borc=dt?Number(dt.kredi.toplam_borc)||0:0;
 const ana=`<div class="kart"><h2>${e(x.il_ad)} Belediye Başkanlığı</h2><p class="alt">Bütçe, hizmet karnesi, krizler, binalar ve borçlanma.</p>
 ${dt&&dt.kriz?`<div onclick="belediyeSehirMod('kriz')" style="cursor:pointer;margin:8px 0;padding:10px 12px;border-radius:10px;background:var(--albg);color:var(--al2);font-weight:700;font-size:14px">Kriz masası: ${e(dt.kriz.baslik)} · karar için ${kalanSure(dt.kriz.son)}</div>`:""}
 <div class="segment" style="display:flex;flex-wrap:wrap;gap:5px">${sekmeler.map(([k,ad])=>`<button class="${mode===k?"aktif":""}" onclick="belediyeSehirMod('${k}')">${ad}</button>`).join("")}</div></div>`;
 let icerik="";
 if(mode==="ozet"){
  icerik=`<div class="kart"><h2>Şehrin güncel durumu</h2>
  <div class="gosterge"><div><div class="ad">Belediye kasası</div><div class="deger" style="font-size:20px">${kasaYaz(x.kasa)}</div></div><div><div class="ad">Memnuniyet</div><div class="deger">${fmt(x.memnuniyet,1)}</div></div><div><div class="ad">Gelişmişlik</div><div class="deger">${fmt(x.gelisim,1)}</div></div></div>
  ${dt?`<div class="kv"><span class="k">Hizmet karnesi ortalaması</span><span class="v" style="color:${karneRenk(dt.karne.ortalama)}">${fmt(dt.karne.ortalama,1)} / 100</span></div>`:""}
  ${borc>0?`<div class="kv"><span class="k">İller Bankası borcu</span><span class="v kotu">${kasaYaz(borc)}</span></div>`:""}
  ${[["Günlük temel gelir",x.temel_gelir],["Binaların günlük geliri",x.bina_gelir],["Günlük temel gider",-Number(x.temel_gider)],["Binaların günlük bakımı",-Number(x.bina_gider)],["Tahmini günlük net gelir",gel-gider]].map(([k,v])=>`<div class="kv"><span class="k">${k}</span><span class="v ${Number(v)>=0?"iyi":"kotu"}">${v>0?"+":""}${BM(v)}</span></div>`).join("")}
  ${[["Çalışan binalar",bn.filter(v=>v.durum==="aktif").length],["Yapımı devam edenler",bn.filter(v=>v.durum==="insa").length],["Hizmet istihdamı (simülasyon)",x.istihdam],["Hizmet kapasitesi",x.kapasite],["Çevre puanı katkısı",x.cevre]].map(([k,v])=>`<div class="kv"><span class="k">${k}</span><span class="v">${fmt(v)}</span></div>`).join("")}
  <p class="kucuk">Vergi geliri kasada 60 günlük gelire kadar birikir; bağış ve kredi parası bu sınıra takılmaz.${dt?` Oyuncu bağışları kamu kuruyla çevrilir: ${fmt(dt.tl_milyar)} ₺ bağış kasaya 1 milyar ₺ ekler.`:""}</p></div>
  <div class="kart"><h2>Başkanlık işlemleri</h2><button class="btn altin" onclick="ekranAc(belediyeEkrani)">Vergiler, sosyal yardımlar, hizmetler ve eski yatırımlar</button>
  ${typeof belediyeHizmetIhaleEkrani==="function"?`<button class="btn ikinci" onclick="ekranAc(belediyeHizmetIhaleEkrani)">Belediye şirket ihaleleri</button>`:""}
  <button class="btn ikinci" onclick="belediyeKarneModal(${x.il_id})">Halkın gördüğü belediye karnesi</button></div>`;
 }else if(mode==="karne"){
  const k=dt.karne;
  icerik=`<div class="kart"><h2>Hizmet karnesi · ${fmt(k.ortalama,1)}</h2><p class="alt">Yedi hizmet alanında şehrin puanı. Binalar (seviyeyle artar), açık hizmetler, son 7 günün ekonomi programları ve kriz kararları puan verir. Karne ortalaması her gece halk memnuniyetini kendine doğru çeker; karne herkese açıktır.</p>
  <div class="kucuk">Taban puan ${fmt(k.taban,1)} (gelişmişlikten). Şehrin büyüklük katsayısı ×${fmt(k.olcek,2)}: büyük şehirde aynı puan için daha çok yatırım gerekir.</div></div>
  <div class="kart">${(k.alanlar||[]).map(karneCubuk).join("")}</div>`;
 }else if(mode==="kriz"){
  const kr=dt.kriz;
  icerik=kr?`<div class="kart"><span class="rozet kirmizi">Açık kriz</span><h2 style="margin-top:8px">${e(kr.baslik)}</h2><p>${e(kr.metin)}</p>
   <p class="kucuk">Karar için kalan süre: <b>${kalanSure(kr.son)}</b>. Karar verilmezse "başkan sessiz kaldı" sonucu işler. Kararın Akış'ta herkese duyurulur.</p></div>`+
   (kr.secenekler||[]).map(s=>{const m=Number(s.maliyet)||0,yeter=m<=0||Number(x.kasa)>=m;
    const etki=Object.entries(s.etki||{}).filter(([,v])=>v).map(([a,v])=>`${e(((dt.karne.alanlar||[]).find(z=>z.kod===a)||{}).ad||a)} ${v>0?"+":""}${v}`).join(", ");
    return `<div class="kart"><h3>${e(s.ad)}</h3><p class="kucuk">${e(s.aciklama||"")}</p>
    <div class="kv"><span class="k">${m<0?"Kasaya girecek":"Maliyet"}</span><span class="v ${m<0?"iyi":""}">${m===0?"Bedava":BM(Math.abs(m))}</span></div>
    <div class="kv"><span class="k">Memnuniyet</span><span class="v ${s.mem>=0?"iyi":"kotu"}">${s.mem>0?"+":""}${fmt(s.mem||0)}</span></div>
    ${s.gel?`<div class="kv"><span class="k">Gelişmişlik</span><span class="v iyi">+${fmt(s.gel,1)}</span></div>`:""}
    ${etki?`<div class="kv"><span class="k">Karne (14 gün)</span><span class="v">${etki}</span></div>`:""}
    ${s.sans&&s.sans<1?`<div class="kv"><span class="k">Başarı şansı</span><span class="v">%${fmt(s.sans*100)}</span></div>`:""}
    <button class="btn ${yeter?"altin":"ikinci"}" ${yeter?"":"disabled"} onclick="belediyeKrizKarar(${kr.id},'${e(s.k)}')">${yeter?"Bu kararı ver":"Kasa yetersiz (kredi çekebilirsin)"}</button></div>`;}).join("")
   :`<div class="kart"><h2>Kriz masası</h2><p class="alt">Şu an açık kriz yok. Görevdeki başkanın ilinde ara ara şehir olayı çıkar (kar, sel, grev, yatırım teklifi…). Bildirim gelir; 24 saat içinde karar vermelisin.</p></div>`;
  icerik+=`<div class="kart"><h2>Geçmiş kararlar</h2>${(dt.kriz_gecmis||[]).map(g=>`<div class="kv"><span class="k">${e(g.baslik)}<small class="kucuk" style="display:block">${g.durum==="sessiz"?"Karar verilmedi":e(g.secim_ad||"")}${g.sonuc&&g.sonuc!=="Başarılı"?" · "+e(g.sonuc):""} · ${tarihSaat(g.karar_zamani||g.baslangic)}</small></span><span class="v ${g.durum==="sessiz"?"kotu":""}">${Number(g.maliyet)?BM(-g.maliyet):g.durum==="sessiz"?"Sessiz":"—"}</span></div>`).join("")||'<p class="alt">Henüz kriz yaşanmadı.</p>'}</div>`;
 }else if(mode==="borc"){
  const kr=dt.kredi,bekle=kr.son_kredi&&simdi()-new Date(kr.son_kredi).getTime()<24*3600000;
  icerik=`<div class="kart"><h2>İller Bankası</h2><p class="alt">Belediye büyük yatırım ya da kriz için kredi çekebilir. Taksitler her gece kasadan düşer; kasada para yoksa taksit %5 gecikme cezasıyla borca eklenir, memnuniyet düşer ve üç gecikmede Sayıştay uyarısı herkese duyurulur. Borç şehre aittir; yeni başkan devralır.</p>
  <div class="kv"><span class="k">Toplam borç</span><span class="v ${borc>0?"kotu":""}">${kasaYaz(borc)}</span></div>
  <div class="kv"><span class="k">Kullanılabilir limit</span><span class="v">${kasaYaz(kr.limit)}</span></div>
  <div class="kv"><span class="k">Faiz (dönem boyunca)</span><span class="v">10 gün %${fmt(kr.faiz["10"]*100,2)} · 20 gün %${fmt(kr.faiz["20"]*100,2)} · 30 gün %${fmt(kr.faiz["30"]*100,2)}</span></div>
  ${Number(kr.limit)>=0.01&&!bekle?`<label class="kucuk" style="display:block;margin-top:10px">Tutar (milyon ₺)</label><input id="bkTutar" type="number" inputmode="decimal" min="10" step="10" max="${Math.floor(kr.limit*1000)}" value="${Math.max(10,Math.min(Math.floor(kr.limit*1000),Math.round(Number(dt.gunluk_gelir)*5000)))}" style="width:100%">
  <div class="segment" id="bkGun" style="margin-top:8px">${[10,20,30].map(g=>`<button class="${g===10?"aktif":""}" data-gun="${g}" onclick="this.parentNode.querySelectorAll('button').forEach(b=>b.classList.remove('aktif'));this.classList.add('aktif')">${g} gün</button>`).join("")}</div>
  <button class="btn altin" style="margin-top:10px" onclick="belediyeKrediAl()">Kredi çek</button>`:`<p class="kucuk">${bekle?"İller Bankası 24 saatte bir kredi verir.":"Limit dolu."}</p>`}</div>
  <div class="kart"><h2>Krediler</h2>${(kr.borclar||[]).map(b=>`<div style="padding:10px 0;border-bottom:1px solid var(--line)"><div style="display:flex;justify-content:space-between"><b>${kasaYaz(b.anapara)} · ${b.gun} gün</b><span class="rozet ${b.durum==="aktif"?(b.gecikme?"kirmizi":"altin"):"yesil"}">${b.durum==="aktif"?(b.gecikme?b.gecikme+" gecikme":"Ödeniyor"):"Kapandı"}</span></div>
   <div class="kv"><span class="k">Kalan / günlük taksit</span><span class="v">${kasaYaz(b.kalan)} / ${kasaYaz(b.taksit)}</span></div>
   ${b.durum==="aktif"?`<button class="btn ikinci" ${Number(x.kasa)>=Number(b.kalan)?"":"disabled"} onclick="belediyeKrediKapat(${b.id},${b.kalan})">Kalanı şimdi öde</button>`:""}</div>`).join("")||'<p class="alt">Kredi yok.</p>'}</div>`;
 }else if(mode==="binalar"){
  const groups=[...new Set(bn.map(v=>v.kategori))];
  icerik=`<div class="kart"><h2>Belediye binaları</h2><p class="alt">20 bina çeşidi · 3 geliştirme seviyesi. İnşaatlar süreyle tamamlanır; tamamlandıklarında gelişmişlik ve memnuniyeti artırır ve hizmet karnesine puan verir. Bakım ve gelirler her gün otomatik hesaplanır.</p></div>`+
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
  icerik=`<div class="kart"><h2>Ekonomik kararlar</h2><p class="alt">Esnaf, turizm, istihdam ve altyapı programlarıyla şehir ekonomisine müdahale et. Çevre, afet, ulaşım, burs ve konut programları 7 gün boyunca hizmet karnesine de puan verir. Bir karar 12 saatte bir; aynı program 48 saatte bir tekrarlanabilir.</p></div>`+
  pg.map(v=>{const bekle=!!(v.son&&simdi()-new Date(v.son).getTime()<48*3600000),ok=!kilit&&!bekle&&Number(x.kasa)>=Number(v.maliyet);
  return `<div class="kart"><h3>${e(v.ad)}</h3><p class="kucuk">${e(v.aciklama)}</p>
   <div class="kv"><span class="k">Maliyet</span><span class="v">${BM(v.maliyet)}</span></div>
   <div class="kv"><span class="k">Gelişim / memnuniyet</span><span class="v">+${fmt(v.gelisim)} / +${fmt(v.memnuniyet)}</span></div>
   <div class="kv"><span class="k">Hedeflenen istihdam (gösterge)</span><span class="v">${fmt(v.istihdam)}</span></div>
   ${v.son?`<p class="kucuk">En son: ${tarihSaat(v.son)}</p>`:""}
   <button class="btn ${ok?"altin":"ikinci"}" ${ok?"":"disabled"} onclick="belediyeSehirKarar('${e(v.kod)}')">${kilit?"12 saatlik bekleme":bekle?"48 saatlik program sınırı":Number(x.kasa)<Number(v.maliyet)?"Bütçe yetersiz":"Kararı uygula"}</button></div>`;}).join("");
 }else{
  icerik=`<div class="kart"><h2>Son belediye mali hareketleri</h2><p class="alt">Yatırımlar, bakım giderleri, bina kazançları, bağışlar, krediler ve kriz kararları.</p>${hareket.map(v=>`<div class="kv"><span class="k">${e(v.aciklama)}<small class="kucuk" style="display:block">${tarihSaat(v.zaman)}</small></span><span class="v ${Number(v.tutar)>=0?"iyi":"kotu"}">${BM(v.tutar)}</span></div>`).join("")||'<p class="alt">Henüz kayıt yok.</p>'}</div>`;
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
async function belediyeKrizKarar(id,k){
 const kr=D._belediyeDetay&&D._belediyeDetay.kriz,s=kr&&(kr.secenekler||[]).find(x=>x.k===k);if(!s)return;
 const m=Number(s.maliyet)||0;
 if(!await onayla(e(kr.baslik),`<b>${e(s.ad)}</b><br>${m>0?`Kasadan ${BM(m)} harcanacak.`:m<0?`Kasaya ${BM(-m)} girecek.`:"Kasadan para çıkmaz."} Kararın Akış'ta herkese duyurulur.`,"Kararı ver"))return;
 try{const r=await API.rpc("belediye_kriz_karar",{p_id:id,p_secim:k});toast(r.basarili?"Karar uygulandı.":"Karar verildi ama sonuç beklendiği gibi olmadı.",!r.basarili);belediyeSehirYonetimEkrani();}catch(err){toast(hataCevir(err.message),true);}
}
async function belediyeKrediAl(){
 const mn=Number((document.getElementById("bkTutar")||{}).value),b=document.querySelector("#bkGun button.aktif"),gun=b?+b.dataset.gun:10;
 if(!(mn>=10)){toast("En az 10 milyon ₺ girin.",true);return;}
 const kr=D._belediyeDetay.kredi,f=Number(kr.faiz[String(gun)]),t=mn/1000,top=t*(1+f);
 if(!await onayla("İller Bankası kredisi",`<b>${kasaYaz(t)}</b> kasaya girecek. ${gun} gün boyunca her gece <b>${kasaYaz(top/gun)}</b> taksit düşecek; toplam geri ödeme ${kasaYaz(top)}. Kredi Akış'ta duyurulur.`,"Krediyi çek"))return;
 try{await API.rpc("belediye_kredi_al",{p_tutar:t,p_gun:gun});toast("Kredi kasaya geçti.");belediyeSehirYonetimEkrani();}catch(err){toast(hataCevir(err.message),true);}
}
async function belediyeKrediKapat(id,kalan){
 if(!await onayla("Krediyi kapat",`Kalan borç <b>${kasaYaz(kalan)}</b> kasadan tek seferde ödenecek.`,"Öde ve kapat"))return;
 try{await API.rpc("belediye_kredi_kapat",{p_id:id});toast("Kredi kapatıldı.");belediyeSehirYonetimEkrani();}catch(err){toast(hataCevir(err.message),true);}
}
// Herkese açık karne: il sayfasından da açılır
async function belediyeKarneModal(il){
 const m=modal(`<div class="yukleniyor">Yükleniyor…</div>`);
 let d;try{d=await API.rpc("belediye_karnesi",{p_il:il});}catch(err){m.querySelector(".modal").innerHTML=`<div class="bos">Belediye karnesi henüz açılmadı.</div><button class="btn ikinci" onclick="modalKapat()">Kapat</button>`;return;}
 m.querySelector(".modal").innerHTML=`<div class="tutamak"></div><h3 style="font-size:22px;font-weight:900">${e(d.il_ad)} belediye karnesi</h3>
 <div class="alt">${d.baskan?`Başkan ${e(d.baskan.kad)}${d.baskan.parti?" · "+e(d.baskan.parti):""}`:"Başkanlık boş"}</div>
 <div class="gosterge" style="margin-top:12px"><div><div class="ad">Karne</div><div class="deger" style="color:${karneRenk(d.karne.ortalama)}">${fmt(d.karne.ortalama,1)}</div></div><div><div class="ad">Memnuniyet</div><div class="deger">${fmt(d.memnuniyet,1)}</div></div><div><div class="ad">Kasa</div><div class="deger" style="font-size:16px">${kasaYaz(d.kasa)}</div></div></div>
 ${Number(d.borc)>0?`<div class="kv"><span class="k">İller Bankası borcu</span><span class="v kotu">${kasaYaz(d.borc)}${d.gecikme?` · ${d.gecikme} gecikme`:""}</span></div>`:""}
 <div class="kv"><span class="k">Çalışan belediye binası</span><span class="v">${fmt(d.aktif_bina)}</span></div>
 <div class="kart" style="margin-top:12px">${(d.karne.alanlar||[]).map(a=>karneCubuk({...a,katkilar:[]})).join("")}</div>
 ${(d.krizler||[]).length?`<div class="kart"><h2>Son krizlerde başkanın kararları</h2>${d.krizler.map(k=>`<div class="kv"><span class="k">${e(k.baslik)}<small class="kucuk" style="display:block">${tarihSaat(k.zaman)}</small></span><span class="v ${k.durum==="sessiz"?"kotu":""}">${k.durum==="acik"?"Karar bekleniyor":k.durum==="sessiz"?"Sessiz kaldı":e(k.secim_ad||"")}</span></div>`).join("")}</div>`:""}
 <button class="btn ikinci" onclick="modalKapat()">Kapat</button>`;
}
window.kasaYaz=kasaYaz;
window.belediyeSehirYonetimEkrani=belediyeSehirYonetimEkrani;
window.belediyeSehirMod=belediyeSehirMod;
window.belediyeSehirBina=belediyeSehirBina;
window.belediyeSehirKarar=belediyeSehirKarar;
window.belediyeKrizKarar=belediyeKrizKarar;
window.belediyeKrediAl=belediyeKrediAl;
window.belediyeKrediKapat=belediyeKrediKapat;
window.belediyeKarneModal=belediyeKarneModal;
