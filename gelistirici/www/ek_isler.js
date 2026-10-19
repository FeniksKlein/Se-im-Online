/* Ek işler: ücretler ve çalışma süresi her zaman sunucuda doğrulanır. */
(function(){
"use strict";
let mesgul=false;
const esc=x=>typeof e==="function"?e(String(x??"")):String(x??"");
const para=x=>typeof tlYaz==="function"?tlYaz(Number(x)||0):(Number(x)||0).toLocaleString("tr-TR")+" ₺";
const saat=x=>new Date(x).toLocaleString("tr-TR",{timeZone:"Europe/Istanbul",dateStyle:"short",timeStyle:"short"});

async function ekIslerEkrani(){
 yukleniyor("Ek işler");
 try{
  const d=await API.rpc("ek_is_paneli");
  const aktif=d.aktif, kalan=Math.max(0,Number(d.gunluk_limit)-Number(d.bugun_yapilan));
  const bitti=aktif&&new Date(d.simdi).getTime()>=new Date(aktif.bitis).getTime();
  let html='<section class="kart"><h2>💼 Ek iş ilanları</h2>'+
   '<p class="alt">Şirket kurmadan çalış, süren dolunca kazancını cüzdanına al. Aynı anda yalnızca bir iş; Türkiye saatiyle günde en fazla 3 iş yapabilirsin.</p>'+
   '<div class="kv"><span>Bugün yapılan / başlatılan</span><b>'+Number(d.bugun_yapilan)+' / '+Number(d.gunluk_limit)+'</b></div>'+
   '<div class="kv"><span>Bugün ödenen</span><b>'+para(d.bugun_kazanilan)+'</b></div>'+
   '<div class="kv"><span>Kalan iş hakkı</span><b>'+kalan+'</b></div></section>';
  if(aktif){
   html+='<section class="kart" style="border-color:var(--ink2)"><h2>'+esc(aktif.simge)+' Devam eden iş: '+esc(aktif.ad)+'</h2>'+
    '<div class="kv"><span>Ücretin</span><b>'+para(aktif.ucret)+'</b></div>'+
    '<div class="kv"><span>İşin bitişi (TR)</span><b>'+saat(aktif.bitis)+'</b></div>'+
    (bitti?'<p class="alt">İş bitti! Ödemen hazır.</p><button class="btn altin" onclick="ekIsUcretAl('+Number(aktif.id)+')">Ücretimi al</button>':
    '<p class="alt">Süre dolmadan ödeme yapılamaz. Bu sırada başka bir ek işe başlayamazsın.</p>')+'</section>';
  }
  html+='<div class="bolum-bas"><h2>İş seçenekleri</h2><span class="kucuk">Ücretler iş başında belirlenir</span></div>';
  for(const is of d.isler||[]){
   const uygun=!aktif&&kalan>0;
   html+='<section class="kart"><h3>'+esc(is.simge)+' '+esc(is.ad)+'</h3>'+
    '<p class="alt">'+esc(is.aciklama)+'</p>'+
    '<div class="kv"><span>Çalışma süresi</span><b>'+Number(is.sure_dakika)+' dakika</b></div>'+
    '<div class="kv"><span>Olası ücret</span><b>'+para(is.asgari_ucret)+' – '+para(is.azami_ucret)+'</b></div>'+
    '<button class="btn '+(uygun?'altin':'ikinci')+'" '+(uygun?'onclick="ekIsBaslat(\''+esc(is.kod)+'\')"':'disabled')+'>'+
    (uygun?'İşe başla':aktif?'Devam eden işin var':'Günlük hak doldu')+'</button></section>';
  }
  html+='<section class="kart"><h3>Son ödemelerim</h3>'+
   ((d.gecmis||[]).map(x=>'<div class="kv"><span>'+esc(x.simge)+' '+esc(x.ad)+' · '+saat(x.odendi_at)+'</span><b>+'+para(x.ucret)+'</b></div>').join('')||
    '<p class="alt">Henüz tamamladığın ek iş yok.</p>')+'</section>'+
   '<button class="btn ikinci" onclick="ekIslerEkrani()">↻ Durumu yenile</button>';
  iskelet("Ek işler",html,{geri:true});
 }catch(err){iskelet("Ek işler",'<div class="kart"><p class="alt">'+esc(typeof hataCevir==="function"?hataCevir(err.message):err.message)+'</p><button class="btn ikinci" onclick="ekIslerEkrani()">Tekrar dene</button></div>',{geri:true});}
}

async function ekIsBaslat(kod){
 if(mesgul)return;
 mesgul=true;
 try{
  const x=await API.rpc("ek_is_baslat",{p_tur:kod});
  toast('Ek işe başladın. Bitiş: '+saat(x.bitis)+' · Ücret: '+para(x.ucret));
  await ekIslerEkrani();
 }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);}
 finally{mesgul=false;}
}

async function ekIsUcretAl(id){
 if(mesgul)return;
 mesgul=true;
 try{
  const x=await API.rpc("ek_is_ucret_al",{p_id:id});
  toast('Ek iş ücretin cüzdanına yatırıldı: +'+para(x.ucret));
  try{await durumYenile();}catch(_){/* Ödeme sunucuda kaydedildi. */}
  await ekIslerEkrani();
 }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);}
 finally{mesgul=false;}
}

window.ekIslerEkrani=ekIslerEkrani;
window.ekIsBaslat=ekIsBaslat;
window.ekIsUcretAl=ekIsUcretAl;
})();
