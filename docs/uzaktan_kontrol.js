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
   '<button class="btn ikinci" onclick="uzaktanKontrolYenile()">Sunucudan yenile</button></section>'+
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