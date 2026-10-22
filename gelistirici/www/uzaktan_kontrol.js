/* 22.10.2026 - Sunucudan oyun yönetimi, canlı senkron ve güvenli modül anahtarları.
 * Bu modül telefonun paketlenmiş JS'ini değiştirmez: yalnızca izinli sunucu
 * durumunu okur ve zaten bulunan ekranları yeniler. */
(function(){
"use strict";
if(window.UZAKTAN_KONTROL_YUKLENDI)return;
window.UZAKTAN_KONTROL_YUKLENDI=true;
const S={rev:null,moduller:{},baglandi:false,kanal:null,suruyor:false,sonEkran:0,baslatiliyor:false,sonSinyal:0};
const safe=x=>typeof e==="function"?e(String(x??"")):String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const modulAcik=kod=>S.moduller[kod]!==false;
window.UZAKTAN={durum:S,modulAcik,sorgula:()=>guncelle(true)};
function hazir(){return typeof API!=="undefined"&&API&&typeof API.rpc==="function";}
function aktarYuklu(){return typeof D!=="undefined"&&D&&D.durum&&D.durum.profil;}
function cizimIzin(){return typeof document!=="undefined"&&!document.hidden&&
 typeof yenidenCiz==="function"&&typeof D!=="undefined"&&D&&
 (!D.yigin||D.yigin.length===0)&&!document.querySelector("#modal")&&
 Date.now()-S.sonEkran>4500;}
function moduGizle(){
  const root=document.querySelector("#icerik");
  if(!root)return;
  const tipler={"sirket_pazari":"sirketAlimSatimEkrani","npc_isletme":"npcIsletmeEkrani"};
  root.querySelectorAll("button[onclick]").forEach(b=>{
    const a=b.getAttribute("onclick")||"";
    for(const [k,fn] of Object.entries(tipler)){
      if(a.includes(fn)){b.disabled=!modulAcik(k);b.title=modulAcik(k)?"":"Bu özellik oyun yönetimi tarafından geçici olarak kapatıldı.";break;}
    }
  });
}
async function baglan(){
 if(S.baglandi||!hazir()||!API.realtimeClient)return;
 const client=API.realtimeClient;
 try{
  S.kanal=client.channel("oyun-uzaktan-yonetim", {config:{private:false}})
   .on("postgres_changes",{event:"UPDATE",schema:"public",table:"oyun_kontrol_sinyali"},()=>{
     if(Date.now()-S.sonSinyal<450)return;
     S.sonSinyal=Date.now();
     guncelle(false).catch(()=>{});
   }).subscribe();
  S.baglandi=true;
 }catch(err){S.baglandi=false;}
}
async function guncelle(zorla){
 if(S.suruyor||!hazir()||document.hidden)return;
 S.suruyor=true;
 try{
  const oturum=await API.oturum();
  if(!oturum){S.rev=null;S.moduller={};S.baglandi=false;return;}
  await baglan();
  const d=await API.rpc("uzaktan_kontrol_durum");
  if(!d||!Number.isFinite(Number(d.rev)))return;
  const yeni=Number(d.rev)!==S.rev;
  S.moduller=d.moduller&&typeof d.moduller==="object"?d.moduller:{};
  S.rev=Number(d.rev);
  if(yeni&&aktarYuklu()){
   if(typeof uygulamaAyarYukle==="function")await uygulamaAyarYukle();
   if(typeof surumKontrol==="function"&&await surumKontrol()===false)return;
   if(typeof durumYenile==="function")await durumYenile();
   if(cizimIzin()){S.sonEkran=Date.now();yenidenCiz();}
  }
  moduGizle();
 }catch(err){
  // Websocket kopsa bile 45 saniyelik kontrol ve uygulamaya dönüş sürer.
  // Sunucu kapalıyken çalışan ekranları zorla kapatma.
 }finally{S.suruyor=false;}
}
window.uzaktanKontrolYenile=()=>guncelle(true);
async function uzaktanKontrolAdminEkrani(){
 if(!aktarYuklu()||D.durum.profil.yonetici!==true){
   if(typeof toast==="function")toast("Yalnızca oyun sahibi uzaktan modül ayarlarını değiştirebilir.",true);
   return;
 }
 if(typeof yukleniyor==="function")yukleniyor("Canlı Oyun Yönetimi");
 try{
  const [list,durum]=await Promise.all([API.rpc("uzaktan_kontrol_ayarlari"),API.rpc("uzaktan_kontrol_durum")]);
  const v=Array.isArray(list)?list:[];
  const html='<section class="kart"><h2>📡 Canlı Oyun Yönetimi</h2>'+
   '<p class="alt">Sunucu tarafındaki işlemler (para, makam, seçim, yasak, vergi, ekonomi) anında geçerlidir. Bu ayarlar telefona yeni kod indirmez. Bağlı cihazlara güvenli değişiklik sinyali gönderilir; bağlantı kesilirse otomatik tekrar kontrol edilir.</p>'+
   '<div class="kv"><span>Kontrol revizyonu</span><b>'+safe(durum.rev)+'</b></div>'+
   '<div class="kv"><span>Son işlem</span><b>'+safe(durum.tur)+'</b></div>'+
   '<div class="kv"><span>Canlı bağlantı</span><b>'+safe(S.baglandi?"Etkin (yedek sorgulama açık)":"Yedek sorgulama açık")+'</b></div>'+
   '<button class="btn ikinci" onclick="uzaktanKontrolYenile()">Sunucudan yenile</button>'+
   '<button class="btn altin" onclick="uzaktanKontrolYayin()">📣 Tüm açık telefonlara yenileme sinyali gönder</button></section>'+
   v.map(m=>'<section class="kart"><h3>'+safe(m.ad)+'</h3><p class="alt">'+safe(m.aciklama)+'</p>'+
   '<p class="kucuk">Durum: <b>'+(m.acik?"Açık":"Kapalı")+'</b></p>'+
   '<button class="btn '+(m.acik?"ikinci":"altin")+'" onclick="uzaktanModulDegistir(\''+String(m.kod).replace(/[^a-z0-9_]/g,"")+'\','+(!m.acik)+')">'+
   (m.acik?"Geçici olarak kapat":"Yeniden aç")+'</button></section>').join("");
  iskelet("Canlı Oyun Yönetimi",html,{geri:true});
 }catch(err){
  iskelet("Canlı Oyun Yönetimi",'<div class="kart"><p class="alt">'+safe(err.message||err)+'</p></div>',{geri:true});
 }
}
async function uzaktanModulDegistir(kod,acik){
 if(!["sirket_pazari","npc_isletme"].includes(kod))return;
 if(typeof onayla==="function"&&!await onayla("Sunucu üzerinden değişiklik",
   kod+" modülünü "+(acik?"açmak":"kapatmak")+" istiyor musun? İşlem kayıt altına alınır.",
   acik?"Etkinleştir":"Devre dışı bırak"))return;
 try{
  await API.rpc("uzaktan_kontrol_ayarla",{p_kod:kod,p_acik:!!acik});
  if(typeof toast==="function")toast("Sunucu modülü güncellendi.");
  S.rev=null;await guncelle(true);await uzaktanKontrolAdminEkrani();
 }catch(err){if(typeof toast==="function")toast(String(err.message||err),true);}
}
async function uzaktanKontrolYayin(){
 if(typeof onayla==="function"&&!await onayla("Canlı oyun yenileme",
   "Sunucu, bağlı oyunculara oyun verilerini yeniden okuma sinyali gönderecek. Bu işlem hesaplara para veya makam vermez.",
   "Yenileme sinyali gönder"))return;
 try{
  await API.rpc("uzaktan_kontrol_yayin");
  if(typeof toast==="function")toast("Bağlı cihazlara yenileme sinyali gönderildi.");
  await guncelle(true);
  await uzaktanKontrolAdminEkrani();
 }catch(err){if(typeof toast==="function")toast(String(err.message||err),true);}
}
window.uzaktanKontrolYayin=uzaktanKontrolYayin;
window.uzaktanKontrolAdminEkrani=uzaktanKontrolAdminEkrani;
window.uzaktanModulDegistir=uzaktanModulDegistir;
// Mevcut yönetici paneli içinde erişilebilir, ancak moderatöre açılmaz.
if(typeof window.iskelet==="function"){
 const eski=window.iskelet;
 window.iskelet=iskelet=function(baslik,govde,opt){
  const r=eski.apply(this,arguments);
  if(baslik==="Kontrol Merkezi"&&typeof D!=="undefined"&&
     D?.durum?.profil?.yonetici===true){
    const ic=document.querySelector("#kmIc");
    if(ic&&!document.querySelector("#uzaktan-yonetim-menu")){
     ic.insertAdjacentHTML("beforebegin",
      '<div class="kart" id="uzaktan-yonetim-menu"><button class="btn altin" onclick="ekranAc(uzaktanKontrolAdminEkrani)">📡 Canlı Oyun Yönetimi · Mağaza güncellemesiz ayarlar</button></div>');
    }
  }
  moduGizle();
  return r;
 };
}
window.addEventListener("load",()=>{
  setTimeout(()=>guncelle(true),1400);
  setInterval(()=>guncelle(false),45000);
});
document.addEventListener("visibilitychange",()=>{if(!document.hidden)guncelle(false);});
window.addEventListener("focus",()=>{guncelle(false);});
window.addEventListener("online",()=>{guncelle(false);});
})();

/* Adliye kurum davaları (22.10.2026): Web ve telefon paketinde ortak arayüz. */
(function(){
 "use strict";
 if(window.ADL_KURUM_20261022)return;
 window.ADL_KURUM_20261022=true;
 if(typeof ADL_TURLER!=="undefined")ADL_TURLER.tazminat="Tazminat";
 const eskiKarar=window.adlKararModal;
 const kurumTurleri={sirket:"Şirket / banka / sigorta",dernek:"Dernek",belediye:"Belediye",makam:"Kamu makamı",bakanlik:"Bakanlık",gazete:"Gazete"};
 window.adlDavaModal=async function(){
  let kurumlar=[];
  try{
   kurumlar=await API.rpc("adliye_kurum_listesi");
   if(!Array.isArray(kurumlar))kurumlar=[];
  }catch(err){toast("Kurum listesi yüklenemedi: "+hataCevir(err.message),true);return;}
  const partiler=ADL.partiler||[];
  const ben=partiler.filter(x=>x.gb_miyim||x.sozcu_muyum);
  const secenek=Object.entries(ADL_TURLER).map(([k,v])=>'<option value="'+e(k)+'">'+e(v)+'</option>').join("");
  const m=modal('<div class="alan"><label>Davalı türü</label><select id="adlHedefTur">'
   +'<option value="oyuncu">Oyuncu</option><option value="parti">Siyasi parti</option>'
   +Object.entries(kurumTurleri).map(([k,v])=>'<option value="'+k+'">'+e(v)+'</option>').join("")+'</select></div>'
   +'<div class="alan" id="adlOyuncuKutu"><label>Davalı kullanıcı adı</label><input id="adlHedef" placeholder="Kullanıcı adı"></div>'
   +'<div class="alan" id="adlPartiKutu" style="display:none"><label>Davalı parti</label><select id="adlHedefParti">'
   +partiler.map(x=>'<option value="'+x.id+'">'+e(x.ad)+'</option>').join("")+'</select></div>'
   +'<div id="adlKurumKutu" style="display:none">'
   +'<div class="alan"><label>Kurum ara</label><input id="adlKurumAra" placeholder="Ad, şehir veya makam adı"></div>'
   +'<div class="alan"><label>Davalı kurum</label><select id="adlKurum"></select></div>'
   +'<p class="alt">Kurumun yetkilisi davada savunma yapabilir. Mahkemenin para cezaları kurum kasasından tahsil edilir; kişisel cüzdandan değil.</p></div>'
   +'<div class="alan"><label>Dava türü</label><select id="adlTur">'+secenek+'</select></div>'
   +'<p class="alt" id="adlSucAciklamasi"></p>'
   +'<div class="alan" id="adlTazKutu" style="display:none"><label>Talep edilen tazminat (₺)</label>'
   +'<input id="adlTazTutar" type="number" min="1000" max="500000" step="1" placeholder="1000–500000"></div>'
   +'<div class="alan"><label>Davacı olarak</label><select id="adlDavaciParti"><option value="">Kendi adıma</option>'
   +ben.map(x=>'<option value="'+x.id+'">'+e(x.ad)+' adına</option>').join("")+'</select></div>'
   +adlAlan("İddia (20–1600 karakter)","adlIddia","textarea")
   +adlAlan("Delil ve işlem kayıtları","adlDelil","textarea","Örn. işlem zamanı, işlem numarası")
   +'<button class="btn altin" id="adlDavaAc">Davayı aç</button>');
  adlFormBaslik(m,"Adliyede yeni dava");
  const hedef=m.querySelector("#adlHedefTur"),turSec=m.querySelector("#adlTur"),ksec=m.querySelector("#adlKurum");
  function listele(){
   const arama=m.querySelector("#adlKurumAra").value.trim().toLocaleLowerCase("tr");
   const liste=kurumlar.filter(x=>x.tur===hedef.value&&(!arama||String(x.ad).toLocaleLowerCase("tr").includes(arama))).slice(0,300);
   ksec.innerHTML=liste.length?liste.map(x=>'<option value="'+e(String(x.id))+'">'+e(String(x.ad))+'</option>').join(""):'<option value="">Eşleşen kurum bulunamadı</option>';
  }
  function guncelle(){
   const secim=hedef.value;
   const kurum=Object.prototype.hasOwnProperty.call(kurumTurleri,secim);
   m.querySelector("#adlOyuncuKutu").style.display=secim==="oyuncu"?"block":"none";
   m.querySelector("#adlPartiKutu").style.display=secim==="parti"?"block":"none";
   m.querySelector("#adlKurumKutu").style.display=kurum?"block":"none";
   const tazOption=turSec.querySelector('option[value="tazminat"]');
   tazOption.disabled=!kurum||secim==="makam";
   if(tazOption.disabled&&turSec.value==="tazminat")turSec.value="diger";
   m.querySelector("#adlTazKutu").style.display=kurum&&turSec.value==="tazminat"?"block":"none";
   m.querySelector("#adlSucAciklamasi").textContent=turSec.value==="tazminat"
    ?"Kurumun oyun içinde sebep olduğu kanıtlanabilir zararlar için 1.000–500.000 ₺ talep edilebilir."
    :(ADL_SUCLAR[turSec.value]||"");
   if(kurum)listele();
  }
  hedef.onchange=guncelle;
  turSec.onchange=guncelle;
  m.querySelector("#adlKurumAra").oninput=listele;
  guncelle();
  m.querySelector("#adlDavaAc").onclick=async()=>{
   const secim=hedef.value,kurum=Object.prototype.hasOwnProperty.call(kurumTurleri,secim);
   const davali=kurum?ksec.value:secim==="parti"?m.querySelector("#adlHedefParti").value:m.querySelector("#adlHedef").value.trim();
   if(!davali){toast("Davalıyı seçmelisiniz.",true);return;}
   const taz=turSec.value==="tazminat",tutar=taz?Number(m.querySelector("#adlTazTutar").value):null;
   if(taz&&(!Number.isInteger(tutar)||tutar<1000||tutar>500000)){toast("Tazminat talebi 1.000–500.000 ₺ arasında olmalıdır.",true);return;}
   const args={p_hedef_tur:secim,p_hedef:String(davali),p_tur:turSec.value,
    p_iddia:m.querySelector("#adlIddia").value,p_delil:m.querySelector("#adlDelil").value,
    p_davaci_parti:m.querySelector("#adlDavaciParti").value||null};
   if(kurum)args.p_tazminat_talep=taz?tutar:null;
   try{
    const v=await API.rpc(kurum?"adliye_kurum_dava_ac":"adliye_dava_ac",args);
    modalKapat();toast("Dava #"+v.id+" açıldı.");
    if(D.sekme==="adliye")await adliyeEkrani();else{D.devletSekme="adliye";await devletEkrani();}
   }catch(err){toast(hataCevir(err.message),true);}
  };
 };
 window.adlKararModal=function(id){
  const dv=(ADL.davalar||[]).find(x=>x.id===id)||{};
  if(!dv.davali_kurum_tur)return eskiKarar(id);
  const secenekler=["beraat","uyari",...(dv.davali_kurum_tur==="makam"?[]:["para_10b","para_50b"]),
   ...(dv.tur==="tazminat"&&dv.davali_kurum_tur!=="makam"?["tazminat"]:[])];
  const m=modal('<p class="alt">Davalı: '+e(dv.davali_kurum_ad||"Kurum")
   +'. Kuruma verilen parasal yaptırımlar kurum kasasından tahsil edilir.</p>'
   +'<div class="alan"><label>Mahkeme kararı</label><select id="adlCeza">'
   +secenekler.map(k=>'<option value="'+k+'">'+e(k==="tazminat"?"Kurumdan tazminat":ADL_CEZALAR[k]||k)+'</option>').join("")+'</select></div>'
   +(secenekler.includes("tazminat")?'<div class="alan" id="adlKurumTazKutu" style="display:none">'
    +'<label>Hükmedilecek tazminat (üst sınır '+tlYaz(dv.tazminat_talep||500000)+')</label>'
    +'<input id="adlKararTazTutar" type="number" min="1000" max="'+Number(dv.tazminat_talep||500000)+'" step="1"></div>':"")
   +adlAlan("Gerekçeli karar (20–2000 karakter)","adlGerekce","textarea")
   +'<p class="alt">Oy çoğunluğu sağlanırsa karar yayımlanır. İstinaf hakkı ve süresi devam eder.</p>'
   +'<button class="btn altin" id="adlKarar">Oyumu ver</button>');
  adlFormBaslik(m,"Yüksek Mahkeme · Kurum Davası #"+id);
  const karar=m.querySelector("#adlCeza");
  if(secenekler.includes("tazminat"))karar.onchange=()=>{
   m.querySelector("#adlKurumTazKutu").style.display=karar.value==="tazminat"?"block":"none";
  };
  m.querySelector("#adlKarar").onclick=async()=>{
   if(!await onayla("Oyunu ver","Heyette çoğunluk sağlanırsa gerekçeli karar açıklanır.","Oyumu ver",true))return;
   const k=karar.value,tutar=k==="tazminat"?Number(m.querySelector("#adlKararTazTutar").value):null;
   if(k==="tazminat"&&(!Number.isInteger(tutar)||tutar<1000||tutar>Number(dv.tazminat_talep||500000))){
    toast("Tazminat miktarı geçerli sınırlar içinde olmalıdır.",true);return;
   }
   adlIslem(()=>k==="tazminat"
    ?API.rpc("adliye_tazminat_oy",{p_dava:id,p_tutar:tutar,p_gerekce:m.querySelector("#adlGerekce").value})
    :API.rpc("adliye_oy_ver",{p_dava:id,p_karar:k,p_gerekce:m.querySelector("#adlGerekce").value}),"Oyun kaydedildi.",id);
  };
 };
})();
