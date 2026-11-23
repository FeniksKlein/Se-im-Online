/* Ek İşler 2.0 — ücret, süre, günlük hak ve ödeme her zaman sunucuda doğrulanır
   (sql/zz_20261124_ek_isler_v2.sql). Bu dosya yalnız gösterir: iş listesi, sıralama, günlük hak,
   bugünkü kazanç, sıfırlanma saati, geçmiş ve ana ekrandaki "Ek İşler" şeridi. */
(function(){
"use strict";
let mesgul=false, SIRA="onerilen", SON=null, SON_FARK=0, sayacNo=0;
let OZET=null, OZET_T=0, ozetIstek=null, OZET_HATA_T=0;
try{const s=localStorage.getItem("ssk_ek_is_sira"); if(s&&["onerilen","kazanc","sure","tur"].includes(s))SIRA=s;}catch(_){/* depolama yoksa varsayılan */}
const esc=x=>typeof e==="function"?e(String(x??"")):String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const para=x=>typeof tlYaz==="function"?tlYaz(Number(x)||0):(Number(x)||0).toLocaleString("tr-TR")+" ₺";
const saat=x=>new Date(x).toLocaleString("tr-TR",{timeZone:"Europe/Istanbul",dateStyle:"short",timeStyle:"short"});
const saatKisa=x=>new Date(x).toLocaleTimeString("tr-TR",{timeZone:"Europe/Istanbul",hour:"2-digit",minute:"2-digit"});
const hataYaz=err=>typeof hataCevir==="function"?hataCevir(err&&err.message):String((err&&err.message)||err);
function sureYaz(dk){dk=Math.max(0,Math.round(Number(dk)||0));const s=Math.floor(dk/60),d=dk%60;return s?(s+" sa"+(d?" "+d+" dk":"")):(d+" dk");}
function kalanYaz(ms){
 const sn=Math.max(0,Math.ceil(ms/1000)),s=Math.floor(sn/3600),d=Math.floor(sn%3600/60),k=sn%60;
 return s?(s+" sa "+d+" dk"):d?(d+" dk "+(d<10?k+" sn":"")).trim():(k+" sn");
}
/* Sunucu göndermediyse: Türkiye saatiyle (UTC+3, yaz saati yok) bir sonraki 00.00 */
function geceYarisi(simdi){const t=new Date(simdi).getTime()+3*3600e3;return new Date((Math.floor(t/86400e3)+1)*86400e3-3*3600e3);}
function ucretYaz(is){const a=Number(is.asgari_ucret),b=Number(is.azami_ucret);return a===b?para(a):para(a)+" – "+para(b);}
function ortUcret(is){return (Number(is.asgari_ucret)+Number(is.azami_ucret))/2;}
function ozetle(d){
 const limit=Number(d.gunluk_limit)||0,yapilan=Number(d.bugun_yapilan)||0;
 const kalan=d.kalan!=null?Number(d.kalan):Math.max(0,limit-yapilan);
 const simdi=new Date(d.simdi||Date.now()).getTime();
 return {limit,yapilan,kalan,simdi,fark:simdi-Date.now(),sifir:new Date(d.sifirlanma||geceYarisi(simdi)).getTime()};
}

function stil(){
 if(typeof document==="undefined"||!document.head||document.getElementById("eiStil"))return;
 const s=document.createElement("style");s.id="eiStil";
 s.textContent=
 ".ei-ust h2{margin-bottom:4px}"+
 ".ei-hakbas{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-top:12px;font-size:15px;font-weight:700}"+
 ".ei-hakbas b{font-size:22px;font-weight:800;color:var(--ink2,#a895ff);white-space:nowrap}"+
 ".ei-hak{display:flex;gap:5px;margin-top:8px}"+
 ".ei-hak i{flex:1;display:block;height:9px;padding:0;margin:0;border-radius:6px;background:var(--ink2,#a895ff)}"+
 ".ei-hak i.ei-bos{background:var(--line2,rgba(164,184,255,.19))}"+
 ".ei-ozet{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:12px}"+
 ".ei-ozet>div{background:var(--panel2,#1d2850);border-radius:12px;padding:10px 12px;min-width:0}"+
 ".ei-ozet small{display:block;font-size:12.5px;color:var(--mut,#98a4c4);line-height:1.3}"+
 ".ei-ozet b{display:block;font-size:17px;font-weight:800;margin-top:3px;overflow-wrap:anywhere}"+
 ".ei-aktif{box-shadow:inset 0 0 0 1.5px rgba(168,149,255,.55)}"+
 ".ei-aktif.hazir{box-shadow:inset 0 0 0 1.5px rgba(52,201,138,.7)}"+
 ".ei-sayac{font-size:26px;font-weight:800;margin:8px 0 2px;font-variant-numeric:tabular-nums}"+
 ".ei-cubuk{height:8px;border-radius:6px;background:var(--line2,rgba(164,184,255,.19));overflow:hidden;margin-top:8px}"+
 ".ei-cubuk i{display:block;height:100%;border-radius:6px;background:var(--ink2,#a895ff)}"+
 ".ei-sirala{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:0 0 10px;padding:1px}"+
 ".ei-sirala::-webkit-scrollbar{display:none}"+
 ".ei-sirala button{flex:none;min-height:44px;padding:0 15px;border-radius:22px;font-size:14px;font-weight:700;color:var(--mut,#98a4c4);background:var(--panel,#151e3d)}"+
 ".ei-sirala button.aktif{background:var(--inkbg,rgba(123,97,255,.16));color:var(--txt,#eef1f8);box-shadow:inset 0 0 0 1.5px rgba(168,149,255,.55)}"+
 ".ei-liste{padding-top:4px;padding-bottom:4px}"+
 ".ei-grup{font-size:13px;font-weight:800;color:var(--mut,#98a4c4);text-transform:uppercase;letter-spacing:.4px;padding:14px 0 4px}"+
 ".ei-grup:first-child{padding-top:8px}"+
 ".ei-is{display:flex;align-items:center;gap:11px;padding:12px 0;border-top:1px solid var(--line,rgba(164,184,255,.1))}"+
 ".ei-liste>.ei-is:first-child,.ei-grup+.ei-is{border-top:0}"+
 ".ei-sim{flex:none;width:44px;height:44px;border-radius:13px;display:grid;place-items:center;font-size:23px;background:var(--panel2,#1d2850)}"+
 ".ei-m{flex:1;min-width:0}"+
 ".ei-m b{display:block;font-size:15.5px;line-height:1.25;overflow-wrap:anywhere}"+
 ".ei-m span{display:block;font-size:13.5px;color:var(--mut,#98a4c4);margin-top:3px;line-height:1.35}"+
 ".ei-m em{font-style:normal;font-weight:800;color:var(--good,#34c98a)}"+
 ".ei-m .ei-sart{color:var(--warn,#f2b33d)}"+
 ".ei-basla{flex:none;min-height:46px;min-width:76px;padding:0 13px;border-radius:13px;font-size:14.5px;font-weight:800;color:#fff;background:var(--ink,#7b61ff)}"+
 ".ei-basla:active{transform:scale(.97)}"+
 ".ei-basla:disabled{opacity:.4;pointer-events:none;background:var(--panel2,#1d2850);color:var(--txt2,#c9d1e6)}"+
 ".ei-serit{display:flex;align-items:center;gap:12px;width:100%;box-sizing:border-box;margin:0 0 12px;padding:12px 14px;border-radius:18px;text-align:left;color:var(--txt,#eef1f8);background:var(--panel,#151e3d);box-shadow:inset 0 0 0 1px var(--line2,rgba(164,184,255,.19))}"+
 ".ei-serit:active{transform:scale(.99)}"+
 ".ei-serit.hazir{box-shadow:inset 0 0 0 1.5px rgba(52,201,138,.7)}"+
 ".ei-serit .ei-si{flex:none;width:42px;height:42px;border-radius:13px;display:grid;place-items:center;font-size:22px;background:rgba(31,158,134,.2)}"+
 ".ei-serit .ei-sm{flex:1;min-width:0}"+
 ".ei-serit .ei-sm b{display:block;font-size:15.5px;font-weight:800}"+
 ".ei-serit .ei-sm span{display:block;font-size:13px;color:var(--mut,#98a4c4);margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}"+
 ".ei-serit .ei-sh{flex:none;font-size:14px;font-weight:800;color:var(--ink2,#a895ff);white-space:nowrap}"+
 "@media (max-width:340px){.ei-sim{width:38px;height:38px;font-size:20px}.ei-basla{min-width:66px;padding:0 9px}.ei-is{gap:8px}}";
 document.head.appendChild(s);
}

function sirali(isler){
 const l=(isler||[]).slice();
 if(SIRA==="kazanc")l.sort((a,b)=>ortUcret(b)-ortUcret(a)||a.sure_dakika-b.sure_dakika);
 else if(SIRA==="sure")l.sort((a,b)=>a.sure_dakika-b.sure_dakika||ortUcret(b)-ortUcret(a));
 else if(SIRA==="tur")l.sort((a,b)=>String(a.kategori_ad||"").localeCompare(String(b.kategori_ad||""),"tr")||ortUcret(b)-ortUcret(a));
 return l;
}
function isSatiri(is,durum){
 const sart=Number(is.min_kidem)>0?'<span class="ei-sart">Şart: en az '+esc(Number(is.min_kidem))+' kıdem puanı</span>':'';
 const kapali=durum.kilit||is.uygun===false;
 const etiket=durum.kilit==="suruyor"?"Sürüyor":durum.kilit==="hak"?"Hak doldu":is.uygun===false?"Şart var":"Başla";
 return '<div class="ei-is"><span class="ei-sim" aria-hidden="true">'+esc(is.simge)+'</span>'+
  '<div class="ei-m"><b>'+esc(is.ad)+'</b>'+
  '<span><em>'+ucretYaz(is)+'</em> · '+sureYaz(is.sure_dakika)+(is.kategori_ad&&SIRA!=="tur"?' · '+esc(is.kategori_ad):'')+'</span>'+
  '<span>'+esc(is.aciklama)+'</span>'+sart+'</div>'+
  '<button type="button" class="ei-basla" '+(kapali?'disabled':'onclick="ekIsBaslat(\''+esc(is.kod)+'\')"')+' aria-label="'+esc(is.ad)+': işe başla">'+etiket+'</button></div>';
}

/* sessiz=true: işlem sonrası tazeleme ("Yükleniyor" ekranı göstermeden). */
async function ekIslerEkrani(sessiz){
 if(sessiz!==true&&typeof yukleniyor==="function")yukleniyor("Ek İşler");
 stil();
 try{
  const d=await API.rpc("ek_is_paneli");
  SON=d; SON_FARK=new Date(d.simdi||Date.now()).getTime()-Date.now();
  ciz(d);
 }catch(err){
  SON=null;
  iskelet("Ek İşler",'<div class="kart"><p class="alt">'+esc(hataYaz(err))+'</p><button class="btn ikinci" onclick="ekIslerEkrani()">Tekrar dene</button></div>',{geri:true});
 }
}

function ciz(d){
  const o=ozetle(d), aktif=d.aktif;
  o.fark=SON_FARK; o.simdi=Date.now()+SON_FARK;
  const hazir=!!aktif&&(aktif.hazir===true||o.simdi>=new Date(aktif.bitis).getTime());
  OZET={gunluk_limit:o.limit,bugun_yapilan:o.yapilan,kalan:o.kalan,simdi:d.simdi,sifirlanma:d.sifirlanma,aktif:aktif?Object.assign({},aktif,{hazir}):null};OZET_T=Date.now();
  let noktalar="";for(let i=0;i<o.limit&&i<24;i++)noktalar+='<i'+(i<o.kalan?'':' class="ei-bos"')+'></i>';
  let html='<section class="kart ei-ust"><h2>💼 Ek İşler</h2>'+
   '<p class="alt">Bir iş seç, süresi dolunca ücretin cüzdanına yatsın. Aynı anda tek iş yapılır; başlanan iş iptal edilmez.</p>'+
   '<div class="ei-hakbas"><span>Günlük Ek İş Hakkı</span><b>'+o.kalan+'/'+o.limit+'</b></div>'+
   '<div class="ei-hak" role="img" aria-label="Kalan hak '+o.kalan+', toplam '+o.limit+'">'+noktalar+'</div>'+
   '<p class="kucuk" style="margin-top:6px">'+(o.kalan>0?'Bugün '+o.kalan+' iş daha yapabilirsin.':'Bugünkü hakların doldu.')+' Haklar her gece 00.00\'da (Türkiye saati) yenilenir.</p>'+
   '<div class="ei-ozet"><div><small>Bugün kazanılan</small><b>'+para(d.bugun_kazanilan)+'</b></div>'+
   '<div><small>Hakların yenilenmesine</small><b id="eiSifir">'+kalanYaz(o.sifir-o.simdi)+'</b></div></div></section>';
  if(aktif){
   const bas=new Date(aktif.baslama||d.simdi).getTime(),bit=new Date(aktif.bitis).getTime();
   const oran=hazir?100:Math.max(2,Math.min(100,Math.round((o.simdi-bas)/Math.max(1,bit-bas)*100)));
   html+='<section class="kart ei-aktif'+(hazir?' hazir':'')+'"><h2>'+esc(aktif.simge)+' '+(hazir?'İş bitti: ':'Devam eden iş: ')+esc(aktif.ad)+'</h2>'+
    '<div class="kv"><span>Ücretin</span><b>'+para(aktif.ucret)+'</b></div>'+
    '<div class="kv"><span>İşin bitişi (TR)</span><b>'+saat(aktif.bitis)+'</b></div>'+
    (hazir?'<p class="alt" style="margin-top:8px">Ödemen hazır. Ücretini al ya da doğrudan yeni bir işe başla; ücretin o anda yatar.</p>'+
      '<button type="button" class="btn" onclick="ekIsUcretAl('+Number(aktif.id)+')">Ücretimi al · '+para(aktif.ucret)+'</button>':
     '<div class="ei-sayac" id="eiSayac" data-bitis="'+bit+'">'+kalanYaz(bit-o.simdi)+'</div>'+
     '<div class="ei-cubuk"><i id="eiCubuk" data-bas="'+bas+'" style="width:'+oran+'%"></i></div>'+
     '<p class="alt" style="margin-top:8px">Süre dolmadan ödeme yapılmaz. Bu sırada başka bir ek işe başlayamazsın.</p>')+'</section>';
  }
  const kilit=aktif&&!hazir?"suruyor":o.kalan<=0?"hak":"";
  const liste=sirali(d.isler);
  html+='<div class="bolum-bas"><h2>İş seçenekleri</h2><span class="kucuk">'+liste.length+' iş</span></div>'+
   '<div class="ei-sirala" role="group" aria-label="Sıralama">'+
   [["onerilen","Önerilen"],["kazanc","En çok kazanç"],["sure","En kısa süre"],["tur","Meslek türü"]].map(x=>
    '<button type="button" class="'+(SIRA===x[0]?'aktif':'')+'" onclick="ekIsSirala(\''+x[0]+'\')">'+x[1]+'</button>').join('')+'</div>';
  let govde="",grup=null;
  for(const is of liste){
   if(SIRA==="tur"&&is.kategori_ad!==grup){grup=is.kategori_ad;govde+='<div class="ei-grup">'+esc(grup||"Diğer")+'</div>';}
   govde+=isSatiri(is,{kilit});
  }
  html+='<section class="kart ei-liste">'+(govde||'<p class="alt" style="padding:10px 0">Şu anda açık ek iş yok.</p>')+'</section>';
  html+='<section class="kart"><h2>Tamamlanan işlerim</h2>'+
   ((d.gecmis||[]).map(x=>'<div class="kv"><span>'+esc(x.simge)+' '+esc(x.ad)+' · '+saat(x.odendi_at)+'</span><b>+'+para(x.ucret)+'</b></div>').join('')||
    '<p class="alt">Henüz tamamladığın ek iş yok.</p>')+'</section>'+
   '<button type="button" class="btn ikinci" onclick="ekIslerEkrani()">↻ Durumu yenile</button>';
  iskelet("Ek İşler",html,{geri:true});
  sayacKur(o);
}

/* Geri sayım: ekran değişince kendiliğinden durur; iş bitince ekranı bir kez tazeler. */
function sayacKur(o){
 const no=++sayacNo;
 if(typeof document==="undefined"||typeof setTimeout!=="function")return;
 const adim=()=>{
  if(no!==sayacNo)return;
  const sf=document.getElementById("eiSifir"),sy=document.getElementById("eiSayac");
  if(!sf&&!sy)return;
  const simdi=Date.now()+o.fark;
  if(sf){if(simdi>=o.sifir){ekIslerEkrani(true);return;}sf.textContent=kalanYaz(o.sifir-simdi);}
  if(sy){
   const bit=Number(sy.dataset.bitis),kalan=bit-simdi;
   if(kalan<=0){ekIslerEkrani(true);return;}
   sy.textContent=kalanYaz(kalan);
   const c=document.getElementById("eiCubuk");
   if(c){const bas=Number(c.dataset.bas);c.style.width=Math.max(2,Math.min(100,(simdi-bas)/Math.max(1,bit-bas)*100))+"%";}
  }
  setTimeout(adim,1000);
 };
 setTimeout(adim,1000);
}

function ekIsSirala(m){
 if(!["onerilen","kazanc","sure","tur"].includes(m))return;
 SIRA=m;try{localStorage.setItem("ssk_ek_is_sira",m);}catch(_){/* depolama yoksa yalnız bu oturum */}
 if(SON)ciz(SON); else ekIslerEkrani();
}

async function ekIsBaslat(kod){
 if(mesgul)return;
 mesgul=true;
 try{
  const is=SON&&(SON.isler||[]).find(x=>x.kod===kod);
  if(is&&typeof onayla==="function"){
   const tamam=await onayla(esc(is.simge)+' '+esc(is.ad),
    'Bu iş <b>'+sureYaz(is.sure_dakika)+'</b> sürer ve <b>'+ucretYaz(is)+'</b> kazandırır. İş bitene kadar başka ek işe başlayamazsın; başlanan iş iptal edilmez ve günlük hakkından bir tane düşer.',
    'İşe başla');
   if(!tamam)return;
  }
  const x=await API.rpc("ek_is_baslat",{p_tur:kod});
  const once=x.onceki_odeme&&x.onceki_odeme.ucret?'Önceki işin ücreti yattı: +'+para(x.onceki_odeme.ucret)+'. ':'';
  toast(once+'Ek işe başladın. Bitiş: '+saatKisa(x.bitis)+' · Ücret: '+para(x.ucret));
  if(once){try{await durumYenile();}catch(_){/* Ödeme sunucuda kaydedildi. */}}
  await ekIslerEkrani(true);
 }catch(err){toast(hataYaz(err),true);try{await ekIslerEkrani(true);}catch(_){/* ekran eski hâliyle kalır */}}
 finally{mesgul=false;}
}

async function ekIsUcretAl(id){
 if(mesgul)return;
 mesgul=true;
 try{
  const x=await API.rpc("ek_is_ucret_al",{p_id:id});
  toast('Ek iş ücretin cüzdanına yatırıldı: +'+para(x.ucret));
  try{await durumYenile();}catch(_){/* Ödeme sunucuda kaydedildi. */}
  await ekIslerEkrani(true);
 }catch(err){toast(hataYaz(err),true);}
 finally{mesgul=false;}
}

/* ---------- Ana ekran şeridi ----------
   ekIsSeridi() hemen çizilir; durum (kalan hak, süren iş) en fazla dakikada bir küçük bir istekle doldurulur. */
function seritIcerik(z){
 if(!z)return {alt:"Çalış, süre dolunca ücretini al",hak:"",hazir:false};
 const o=ozetle(z),a=z.aktif,simdi=Date.now()+o.fark;
 if(a){
  const bitti=a.hazir===true||simdi>=new Date(a.bitis).getTime();
  if(bitti)return {alt:esc(a.ad)+" bitti: "+para(a.ucret)+" ödemen hazır",hak:o.kalan+"/"+o.limit,hazir:true};
  return {alt:esc(a.ad)+" sürüyor · "+saatKisa(a.bitis)+"'te biter",hak:o.kalan+"/"+o.limit,hazir:false};
 }
 return {alt:o.kalan>0?"Bugün "+o.kalan+" iş hakkın var":"Bugünkü hakların doldu · 00.00'da yenilenir",hak:o.kalan+"/"+o.limit,hazir:false};
}
function seritDoldur(){
 if(typeof document==="undefined")return;
 const c=seritIcerik(OZET);
 document.querySelectorAll("[data-ek-is-serit]").forEach(el=>{
  el.classList.toggle("hazir",c.hazir);
  const alt=el.querySelector(".ei-sm span"),hak=el.querySelector(".ei-sh");
  if(alt)alt.innerHTML=c.alt; if(hak)hak.textContent=c.hak;
 });
}
function ekIsSeritYenile(zorla){
 if(typeof API==="undefined"||!API||typeof API.rpc!=="function")return Promise.resolve();
 if(!zorla&&OZET&&Date.now()-OZET_T<60000){seritDoldur();return Promise.resolve();}
 if(!zorla&&OZET_HATA_T&&Date.now()-OZET_HATA_T<600000)return Promise.resolve();   // özet alınamadıysa 10 dk yeniden sorma
 if(ozetIstek)return ozetIstek;
 ozetIstek=API.rpc("ek_is_ozet").then(z=>{OZET=z;OZET_T=Date.now();OZET_HATA_T=0;seritDoldur();})
  .catch(()=>{OZET_HATA_T=Date.now();/* eski sunucu ya da bağlantı sorunu: şerit yine Ek İşler'i açar */})
  .then(()=>{ozetIstek=null;});
 return ozetIstek;
}
function ekIsSeridi(){
 stil();
 const c=seritIcerik(OZET&&Date.now()-OZET_T<60000?OZET:null);
 if(typeof setTimeout==="function")setTimeout(()=>ekIsSeritYenile(false),0);
 return '<button type="button" class="ei-serit'+(c.hazir?' hazir':'')+'" data-ek-is-serit onclick="ekIsAc()" aria-label="Ek İşler">'+
  '<span class="ei-si" aria-hidden="true">💼</span><span class="ei-sm"><b>Ek İşler</b><span>'+c.alt+'</span></span>'+
  '<span class="ei-sh">'+esc(c.hak)+'</span></button>';
}
function ekIsAc(){ if(typeof ekranAc==="function")ekranAc(()=>ekIslerEkrani()); else ekIslerEkrani(); }

window.ekIslerEkrani=ekIslerEkrani;
window.ekIsBaslat=ekIsBaslat;
window.ekIsUcretAl=ekIsUcretAl;
window.ekIsSirala=ekIsSirala;
window.ekIsSeridi=ekIsSeridi;
window.ekIsSeritYenile=ekIsSeritYenile;
window.ekIsAc=ekIsAc;
})();
