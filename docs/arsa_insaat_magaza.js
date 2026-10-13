/* Belediyeler arsa, insaat, tapu, dukkan kiralama ve magaza zincirleri. */
(function(){
"use strict";
const EA={il:null,sekme:"arsa",veri:null,eskiler:[]};
const safe=x=>typeof e==="function"?e(String(x??"")):String(x??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const para=x=>typeof tlYaz==="function"?tlYaz(Math.round(Number(x)||0)):Math.round(Number(x)||0).toLocaleString("tr-TR")+" TL";
const when=x=>x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";
const opts=(xs,key="id",name="ad")=>(xs||[]).map(x=>'<option value="'+Number(x[key])+'">'+safe(x[name])+'</option>').join("");
const box=(title,info,buttons="")=>'<section class="kart ea-card"><h3>'+safe(title)+'</h3><p class="alt">'+info+'</p>'+buttons+'</section>';
const btn=(title,call,second=false)=>'<button class="btn '+(second?"ikinci":"altin")+'" onclick="'+call+'">'+title+'</button>';
const num=(id,title,value,min=0,max=1000000000)=>'<div class="alan"><label>'+title+'</label><input id="'+id+'" type="number" inputmode="numeric" min="'+min+'" max="'+max+'" step="1" value="'+value+'"></div>';
const select=(id,title,options)=>'<div class="alan"><label>'+title+'</label><select id="'+id+'">'+options+'</select></div>';
const get=(m,id)=>m.querySelector("#"+id)?.value||"";
async function act(kind,veri,ok){
 try{
  const x=await API.rpc("eko_emlak_islem",{p_eylem:kind,p_veri:veri});
  if(typeof modalKapat==="function")modalKapat();
  toast(ok||"İşlem tamamlandı.");
  await arsaEkrani(EA.il);
  if(typeof durumYenile==="function")durumYenile().catch(()=>{});
  return x;
 }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);return null;}
}
function dialog(title,body,label,done){
 const m=modal('<h3>'+safe(title)+'</h3>'+body+'<button id="eaGo" class="btn altin">'+label+'</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 const b=m.querySelector("#eaGo");b.onclick=async()=>{b.disabled=true;try{await done(m)}finally{b.disabled=false}};
 return m;
}
function companyOptions(xs){return opts(xs);}
async function buyLand(id){
 const firms=EA.veri?.muteahhitler||[];
 if(!firms.length){toast("Önce İş Dünyası bölümünden müteahhitlik şirketi kur.",true);return;}
 const a=(EA.veri.arsalar||[]).find(x=>Number(x.id)===Number(id));
 dialog("Belediye arsası satın al",'<p class="alt">'+safe(EA.veri.il_adi)+' · '+safe(a?.m2)+' m² · İmar kapasitesi '+safe(a?.kademe)+' bölüm · Bedel '+para(a?.fiyat)+' şirket kasasından ödenir ve belediyeye gelir olur.</p>'+select("eaFirm","Alıcı müteahhitlik şirketi",companyOptions(firms)),
 "Arsayı satın al",async m=>{if(!await onayla("Arsa alımını onayla","Arsa bedeli seçtiğin şirketin kasasından düşecek.","Satın al"))return;await act("arsa_al",{arsa:id,sirket:Number(get(m,"eaFirm"))},"Arsa şirketine geçti.");});
}
function beginBuild(id){
 const a=(EA.veri.benim_arsalarim||[]).find(x=>Number(x.id)===Number(id));
 if(!a)return;
 const m=dialog("İnşaat projesi oluştur",
 '<p class="alt">Bu arsanın toplam imar hakkı '+safe(a.kapasite)+' bağımsız bölüm. Daire ve dükkân sayısı arttıkça maliyet yükselir. Arsa alım bedeli inşaat maliyetine dahil değildir. Yapım süresi 12–96 saattir.</p>'+
 '<div class="alan"><label>Proje adı</label><input id="eaName" maxlength="70" placeholder="Örn. Yatağan Yaşam Konutları"></div>'+
 num("eaD","Daire sayısı",Math.min(3,Number(a.kapasite)),0,40)+num("eaK","Dükkân sayısı",0,0,12)+
 '<p id="eaCapacity" class="alt"></p>',
 "İnşaata başla",async el=>{
  const d=Number(get(el,"eaD")),k=Number(get(el,"eaK"));
  const maxShop=Math.max(1,Math.ceil(Number(a.kapasite)*.3));
  if(!Number.isInteger(d)||!Number.isInteger(k)||d<0||k<0||d+k<1||d+k>Number(a.kapasite)||k>maxShop){toast("İmar hakkı veya dükkân sınırı aşıldı.",true);return;}
  if(!await onayla("İnşaatı başlat","Yapım maliyeti müteahhitlik şirketinin kasasından tahsil edilecek.","İnşaata başla"))return;
  await act("insaata_basla",{arsa:id,ad:get(el,"eaName"),daire:d,dukkan:k},"İnşaat başladı.");
 });
 const update=()=>{const d=Number(get(m,"eaD")),k=Number(get(m,"eaK")),maxShop=Math.max(1,Math.ceil(Number(a.kapasite)*.3));m.querySelector("#eaCapacity").textContent="Toplam "+(d+k)+" / "+a.kapasite+" · En fazla "+maxShop+" dükkân · Süre "+(d+k<=5?12:d+k<=10?24:d+k<=20?48:96)+" saat";};
 m.querySelector("#eaD").addEventListener("input",update);m.querySelector("#eaK").addEventListener("input",update);update();
}
function setPrice(id,current){
 dialog("Bağımsız bölüm satış fiyatı",num("eaMoney","İstediğin satış bedeli ₺",Number(current),100,1000000000)+"<p class='alt'>Yeni fiyat tüm oyuncuların satış listesinde görünür.</p>","Fiyatı kaydet",m=>act("fiyat_belirle",{bolum:id,tutar:Number(get(m,"eaMoney"))},"Fiyat güncellendi."));
}
async function buyUnit(id){
 const x=(EA.veri.satilik||[]).find(x=>Number(x.id)===Number(id));if(!x)return;
 if(!await onayla("Tapu satın al","Bedel "+para(x.fiyat)+" ve %2 alıcı tapu harcı cüzdanından düşecek. Tapu hesabına geçecek.","Satın al"))return;
 await act("bolum_al",{bolum:id},"Yeni tapun oluşturuldu.");
}
function setRent(id,current){
 dialog("Dükkânı kiraya ver",num("eaMoney","Haftalık kira bedeli ₺",Math.max(100,Number(current)||1000),100,10000000)+"<p class='alt'>Kiracı mağaza ilk haftalık kirayı peşin öder, sonraki kiralar 7 günde bir tahsil edilir.</p>","Kiraya çıkar",m=>act("kira_belirle",{bolum:id,tutar:Number(get(m,"eaMoney"))},"Dükkân kiralama listesine eklendi."));
}
async function rentShop(id){
 const stores=EA.veri?.magazalar||[];
 if(!stores.length){toast("Önce İş Dünyası bölümünde bir mağaza şirketi kurmalısın.",true);return;}
 const x=(EA.veri.kiralik||[]).find(y=>Number(y.id)===Number(id));
 dialog("Mağaza şubesi aç",'<p class="alt">'+safe(x?.yapi)+' · '+safe(x?.m2)+' m² · Haftalık '+para(x?.kira)+'. İlk hafta kirası ve açılış gideri mağaza kasasından düşer.</p>'+select("eaFirm","Kiracı mağaza şirketi",companyOptions(stores)),
 "Dükkânı kirala",async m=>{if(!await onayla("Şube aç","Kira ve açılış maliyetini şirketin ödeyecek.","Şubeyi aç"))return;await act("sube_ac",{bolum:id,sirket:Number(get(m,"eaFirm"))},"Yeni şuben açıldı.");});
}
async function collect(id){
 if(!await onayla("Şube gününü kapat","Günlük şube kârı hesaplanır. Vadesi gelen haftalık kira önce şirket kasasından ödenir.","Geliri işle"))return;
 await act("sube_gelir",{sube:id},"Günlük şube geliri işlendi.");
}
function body(){
 const d=EA.veri||{},tab=EA.sekme;
 let html="";
 if(tab==="arsa"){
  html+=box("Belediye arsaları","<b>"+safe(d.il_adi)+"</b> · İl gelişmişliği "+safe(d.gelisim)+" / 100 · Temel daire değeri "+para(d.baz_daire)+". Parsel fiyatları şehir değerlerine ve imar kapasitesine bağlı.");
  for(const a of d.arsalar||[])html+=box(a.kademe+" bölümlük imarlı arsa","Alan: "+safe(a.m2)+" m² · Belediye satış bedeli: <b>"+para(a.fiyat)+"</b><br>Durum: "+(a.durum==="satilik"?"Satılık":"Satıldı"),a.durum==="satilik"?btn("Müteahhitlik şirketiyle satın al","eaArsaAl("+a.id+")"):"");
 }
 if(tab==="insaat"){
  html+=box("İnşaat projeleri","Arsa satın al, projeye daire ve dükkân dağılımı ver. Küçük projeler 12, büyük projeler 96 saate kadar sürer.");
  const lots=d.benim_arsalarim||[];
  if(!lots.length)html+=box("İmar hakkın hazır değil","Önce Belediyelerin Arsaları bölümünden müteahhitlik şirketin için arsa satın al.");
  for(const a of lots)html+=box("Arsa #"+a.id+" · "+a.kapasite+" bağımsız bölüm","Satın alınan arsa "+para(a.fiyat)+" · Kapasite "+a.kapasite,btn("Projeyi hazırla","eaBuild("+a.id+")"));
  for(const y of d.yapilar||[])html+=box(y.ad,"Müteahhit: "+safe(y.sirket_ad)+" · "+y.daire+" daire, "+y.dukkan+" dükkân · İnşaat gideri "+para(y.maliyet)+" · "+(y.hazir?"Tamamlandı":"Teslim: "+when(y.bitis)));
 }
 if(tab==="pazar"){
  html+=box("Yeni daire ve dükkânlar","Bitmiş projelerdeki bağımsız bölümler satıştadır. Müteahhit fiyatı kendisi belirleyebilir; alımda %2 tapu harcı uygulanır.");
  if(!(d.satilik||[]).length)html+=box("Şimdilik satılık mülk yok","Yeni inşaatlar tamamlandığında burada satışa çıkar.");
  const owned=new Set((d.muteahhitler||[]).map(x=>Number(x.id)));
  for(const x of d.satilik||[])html+=box((x.tur==="daire"?"🏠 Daire":"🏬 Dükkân")+" #"+x.id,"Proje: "+safe(x.yapi)+" · "+x.m2+" m² · "+safe(x.sirket_ad)+"<br><b>Satış: "+para(x.fiyat)+"</b>",btn("Satın al","eaUnitBuy("+x.id+")")+(owned.has(Number(x.sirket))?btn("Fiyatı değiştir","eaPrice("+x.id+","+Number(x.fiyat)+")",true):""));
 }
 if(tab==="kira"){
  html+=box("Kiraya verilecek dükkânlar","Dükkân sahipleri haftalık kira belirler. Mağazalar bu yerleri kiralayarak ayrı şubeler açabilir.");
  if(!(d.kiralik||[]).length)html+=box("Kiralanabilir dükkân yok","Dükkân sahibi kiralık ilan açınca burada görünecek.");
  for(const x of d.kiralik||[])html+=box("🏬 "+x.yapi+" · #"+x.id,x.m2+" m² · Haftalık kira <b>"+para(x.kira)+"</b>",btn("Mağazamla kirala","eaRent("+x.id+")"));
 }
 if(tab==="sube"){
  html+=box("Mağaza zincirlerim","Aynı mağaza şirketi farklı şehirlerde birden fazla dükkân kiralayabilir. Her şube için 24 saatte bir sermaye, şehir gelişimi ve yerel rekabete göre gelir hesaplanır.");
  if(!(d.benim_subelerim||[]).length)html+=box("Henüz şuben yok","Kiralık Dükkânlar bölümünden yeni mağaza açabilirsin.");
  for(const x of d.benim_subelerim||[])html+=box("🛍️ "+x.magaza+" · "+x.yapi,"İl: "+(typeof ilAd==="function"?safe(ilAd(x.il)):x.il)+" · Haftalık kira "+para(x.kira)+" · Toplam şube kârı "+para(x.toplam_gelir)+"<br>Sonraki kira: "+when(x.sonraki_kira)+" · Son gelir: "+when(x.son_gelir),btn("Günlük geliri işle","eaCollect("+x.id+")"));
 }
 if(tab==="benim"){
  html+=box("Tapularım ve kiralarım","Satın alınan daireler ve dükkânlar burada görünür. Dükkânını haftalık kira karşılığı diğer oyuncuların mağazalarına verebilirsin.");
  if(!(d.benim_mulklerim||[]).length)html+=box("Henüz tapun yok","Satılık Daire ve Dükkân bölümünden satın alabilirsin.");
  for(const x of d.benim_mulklerim||[])html+=box((x.tur==="daire"?"🏠 Daire":"🏬 Dükkân")+" #"+x.id,"Proje: "+safe(x.yapi)+" · "+x.m2+" m² · "+(x.kirada?"Kirada":x.kira?"Kiralık ilan: "+para(x.kira)+"/hafta":"Henüz kiraya verilmedi"),x.tur==="dukkan"&&!x.kirada?btn("Haftalık kira belirle","eaSetRent("+x.id+","+Number(x.kira||1000)+")"):"");
  if(EA.eskiler.length){
   html+=box("Önceden edinilmiş tapular","Eski dönemde alınan gayrimenkuller korunur. Bu tapulardan yeni satış ya da devir yapılamaz.");
   for(const x of EA.eskiler) html+=box("📜 "+safe(x.tip)+" #"+Number(x.id),safe(x.il)+" · Eski alış: "+para(x.alis)+" · Haftalık kira: "+para(x.haftalik));
  }
 }
 return html;
}
async function arsaEkrani(il){
 if(il!==undefined&&il!==null)EA.il=Number(il);
 yukleniyor("Arsa ve Gayrimenkul");
 try{
  const v=await API.rpc("eko_emlak_panel",{p_il:EA.il||null});EA.veri=v;EA.il=Number(v.il);
  if(EA.sekme==="benim"){
   try {const old=await API.rpc("mulk_liste");EA.eskiler=Array.isArray(old?.mulkler)?old.mulkler:[];}
   catch(_) {EA.eskiler=[];}
  }
  const cities=Array.from({length:81},(_,i)=>i+1).map(i=>'<option value="'+i+'"'+(i===EA.il?" selected":"")+'>'+String(i).padStart(2,"0")+" · "+safe(typeof ilAd==="function"?ilAd(i):"İl "+i)+'</option>').join("");
  const tabs=[["arsa","🏞️ Arsalar"],["insaat","🏗️ İnşaat"],["pazar","🏘️ Satılık"],["kira","🔑 Kiralık"],["sube","🛍️ Zincirler"],["benim","📜 Tapularım"]];
  const html='<style>.ea-tabs{display:flex;overflow-x:auto;gap:7px;padding:0 0 10px;margin:10px 0 14px}.ea-tabs button{flex:0 0 auto;white-space:nowrap;border:1px solid var(--line2);background:var(--panel);color:var(--txt);padding:10px 12px;border-radius:13px;font-weight:750}.ea-tabs button.ea-current{border-color:#a995ff;background:#40345f}.ea-card{margin-bottom:10px}.ea-card h3{margin:0 0 6px}.ea-card .btn{margin:8px 0 0}.ea-top{background:linear-gradient(130deg,#243861,#352c66);padding:17px;border-radius:17px;color:#fff}.ea-top h2{margin:0 0 7px;color:#fff}.ea-top p{font-size:12px;color:#d2d8ec}.ea-il{width:100%;background:#131934;color:#fff;border:1px solid #6c6499;border-radius:10px;padding:13px;font-size:15px;margin-top:12px}</style>'+
  '<section class="ea-top"><h2>🏙️ Şehir Emlak ve İnşaat</h2><p>Belediye arsaları, gerçek tapular, müteahhitlik, kira ve mağaza zincirleri</p><select class="ea-il" aria-label="Şehir seç" onchange="arsaEkrani(Number(this.value))">'+cities+'</select></section>'+
  '<div class="ea-tabs">'+tabs.map(([k,ad])=>'<button class="'+(k===EA.sekme?"ea-current":"")+'" onclick="eaTab(\''+k+'\')">'+ad+'</button>').join("")+'</div>'+body();
  iskelet("Şehir Emlak ve İnşaat",html,{geri:true});
 }catch(err){iskelet("Şehir Emlak ve İnşaat",box("Bağlantı sorunu",safe(typeof hataCevir==="function"?hataCevir(err.message):err.message)),{geri:true});}
}
window.arsaEkrani=arsaEkrani;
window.eaTab=k=>{if(["arsa","insaat","pazar","kira","sube","benim"].includes(k)){EA.sekme=k;arsaEkrani(EA.il);}};
window.eaArsaAl=buyLand;window.eaBuild=beginBuild;window.eaPrice=setPrice;window.eaUnitBuy=buyUnit;
window.eaSetRent=setRent;window.eaRent=rentShop;window.eaCollect=collect;
if(typeof window.iskelet==="function"){
 const old=window.iskelet;
 window.iskelet=iskelet=function(baslik,govde,opt){
  const result=old.apply(this,arguments);
  if(baslik==="İş Dünyası"){
   const grid=document.querySelector(".id-grid");
   if(grid&&!grid.querySelector(".ea-entry"))grid.insertAdjacentHTML("beforeend",
    '<button class="id-kart ea-entry" onclick="arsaEkrani()"><span class="emo">🏙️</span><b>Arsalar ve Gayrimenkul</b><small>Belediye arsaları · İnşaat · Tapu · Kira · Mağaza zinciri</small></button>');
  }
  return result;
 };
}
})();