/* Urun bazli uretim, toptan ticaret, NPC magaza satislari ve franchise. */
(function(){
"use strict";
const TC={sekme:"uretim",veri:null,otoVeri:null};
const tm=x=>typeof e==="function"?e(String(x??"")):String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&#39;","'":"&#39;"}[c]));
const money=x=>typeof tlYaz==="function"?tlYaz(Math.round(Number(x)||0)):Math.round(Number(x)||0).toLocaleString("tr-TR")+" TL";
const date=x=>x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";
const title=(a,b)=>'<div class="bolum-bas"><h2>'+a+'</h2><span class="kucuk">'+b+'</span></div>';
const card=(a,b,buttons="")=>'<section class="kart tc-card"><h3>'+tm(a)+'</h3><p class="alt">'+b+'</p>'+buttons+'</section>';
const button=(name,action)=>'<button class="btn altin" onclick="'+action+'">'+name+'</button>';
const secondary=(name,action)=>'<button class="btn ikinci" onclick="'+action+'">'+name+'</button>';
const field=(id,name,val,min=0,max=100000000)=>'<div class="alan"><label>'+tm(name)+'</label><input id="'+id+'" type="number" min="'+min+'" max="'+max+'" inputmode="numeric" value="'+val+'" step="1"></div>';
const choices=(id,name,arr)=>'<div class="alan"><label>'+tm(name)+'</label><select id="'+id+'">'+arr.map(x=>'<option value="'+tm(x[0])+'">'+tm(x[1])+'</option>').join("")+'</select></div>';
const sel=(m,id)=>m.querySelector("#"+id)?.value??"";
const own=type=>(TC.veri?.sirketler||[]).filter(x=>x.tur===type&&x.yonetici);
const item=id=>(TC.veri?.urunler||[]).find(x=>x.kod===id);
const mine=(id)=> (TC.veri?.sirketler||[]).find(x=>x.id===Number(id));
const storeStock=id=>(TC.veri?.stok||[]).filter(x=>x.sirket===id);
const bizNames=(list)=>list.map(x=>[x.id,x.ad+" · Kasa "+money(x.kasa)]);
/* Fabrika bazinda sunucunun hesapladigi uretim deneyimi ve sermaye kapasitesi. */
const tcCapacityInfo=s=>s?.kapasite||{};
const tcCapacityMultiplier=s=>Math.max(1,Math.min(10,Number(tcCapacityInfo(s).katsayi)||1));
const tcBatchCapacity=(s,p)=>Math.ceil((Number(p?.parti)||0)*tcCapacityMultiplier(s));
function tcCapacityDescription(s){
 const c=tcCapacityInfo(s),mult=tcCapacityMultiplier(s);
 const produced=Number(c.tamamlanan_adet||0);
 const eq=Number(c.esdeger_parti||0);
 const nextProd=c.sonraki_uretim_esdeger==null?"Üretim tecrübesi üst seviyede":
   "Sonraki üretim bonusu: "+Math.max(0,Number(c.sonraki_uretim_esdeger)-eq).toFixed(2)+" eşdeğer parti sonra";
 const nextCap=c.sonraki_sermaye==null?"Sermaye bonusu üst seviyede":
   "Sonraki sermaye bonusu: "+money(c.sonraki_sermaye)+" sermayede";
 return "Üretim kapasitesi x"+mult.toLocaleString("tr-TR",{maximumFractionDigits:2})+
  " · Tamamlanan "+produced.toLocaleString("tr-TR")+" ürün · "+nextProd+" · "+nextCap;
}
function popup(head,inside,label,callback){
 const root=modal('<h3>'+tm(head)+'</h3>'+inside+'<button id="tcOK" class="btn altin">'+tm(label)+'</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 const b=root.querySelector("#tcOK");b.onclick=async()=>{b.disabled=true;try{await callback(root)}finally{b.disabled=false;}};
 return root;
}
async function action(kind,data,text){
 try{
  const result=await API.rpc("eko_ticaret_islem",{p_eylem:kind,p_veri:data});
  if(typeof modalKapat==="function")modalKapat();
  toast(text||"İşlem tamamlandı.");
  if(typeof durumYenile==="function")durumYenile().catch(()=>{});
  await ticaretMerkezEkrani();
  return result;
 }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);return null;}
}
/* Belediye ruhsatından tek ekranda gerçek fabrika kuruluşu. Şirket/para değişikliği
   yalnızca oyuncu onayından sonra sunucudaki mevcut eko_islem('kur') RPC'siyle yapılır. */
async function factoryWithPermit(preferredGroup){
 let permits;
 try{
  const v=await API.rpc("bel_ruhsat_merkezi");
  permits=(v.benim||[]).filter(r=>r.tur==="kur_fabrika"&&r.durum==="onay"&&
   r.sirket&&r.il_id&&r.karar_zamani&&
   (Date.now()-new Date(r.karar_zamani).getTime())<72*60*60*1000);
 }catch(err){toast(hataCevir(err.message),true);return;}
 if(!permits.length){
  if(await onayla("Fabrika ruhsatı gerekli",
   "Henüz geçerli, onaylı bir fabrika kuruluş ruhsatın görünmüyor. Ruhsat Merkezi üzerinden belediyeye başvurabilirsin.",
   "Ruhsat Merkezi'ne git")){
    if(typeof window.msRuhsatMerkeziAc==="function")window.msRuhsatMerkeziAc();
    else if(typeof window.belRuhsatMerkeziEkrani==="function")ekranAc(belRuhsatMerkeziEkrani);
    else toast("Ruhsat Merkezi için Ekonomi menüsünü aç.",true);
  }
  return;
 }
 const list=permits.map(r=>[r.id,r.sirket+" · İl "+r.il_id+" · Onaylı"]);
 const el=popup("Onaylı ruhsatla fabrika kur",
  '<p class="alt">Onaylanan fabrika ruhsatını kullanarak şirketini ve üretim tesisini aynı işlemde kur. Şirket adı ve il ruhsatla birebir eşleşir. Kuruluş sermayesi cüzdanından, belediye harcı şirket kasasından tahsil edilir.</p>'+
  choices("tcPermit","Kullanılacak ruhsat",list)+
  choices("tcPermitGroup","Üretilecek ürün grubu",[
   ["gida","🥖 Gıda (su, ekmek, un vb.)"],["teknoloji","💻 Teknoloji"],
   ["malzeme","🧱 İnşaat malzemeleri"]])+
  field("tcPermitCapital","Kuruluş sermayesi (TL)",250000,100000,100000000)+
  '<p class="alt" id="tcPermitInfo"></p>',
  "Fabrikayı kur",async root=>{
   const r=permits.find(x=>x.id===Number(sel(root,"tcPermit")));
   const capital=Number(sel(root,"tcPermitCapital"));
   const group=sel(root,"tcPermitGroup");
   if(!r||!["gida","teknoloji","malzeme"].includes(group)||
    !Number.isInteger(capital)||capital<100000||capital>100000000){
    toast("Geçerli ruhsat, üretim grubu ve sermaye seç.",true);return;
   }
   if(!await onayla("Fabrika kuruluşu",
    r.sirket+" adlı sanayi şirketi "+money(capital)+" sermayeyle kurulacak. Belediyenin ruhsat harcı ayrıca şirket kasasından kesilecek.",
    "Kur ve üretime bağla"))return;
   try{
    await API.rpc("eko_islem",{p_eylem:"kur",
     p_veri:{tur:"fabrika",il:Number(r.il_id),ad:r.sirket,urun:group,tutar:capital}});
    modalKapat();
    toast("Fabrikan kuruldu ve üretime bağlandı. Üretim emri verebilirsin.");
    if(typeof durumYenile==="function")durumYenile().catch(()=>{});
    await ticaretMerkezEkrani("uretim");
   }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);}
  });
 if(["gida","teknoloji","malzeme"].includes(preferredGroup))
  el.querySelector("#tcPermitGroup").value=preferredGroup;
 const info=()=>{
  const r=permits.find(x=>x.id===Number(sel(el,"tcPermit")));
  el.querySelector("#tcPermitInfo").textContent=r?
   "Ruhsat: "+r.sirket+" · Geçerlilik sonu: "+
   date(new Date(new Date(r.karar_zamani).getTime()+72*60*60*1000).toISOString()):"";
 };
 el.querySelector("#tcPermit").onchange=info;info();
}
/* Onaylı belediye ruhsatıyla yeni market şirketi kur ve mağazacılığa bağla.
   Sadece onaydan sonra mevcut sunucu RPC'sini çağırır; mevcut şirketler korunur. */
async function marketWithPermit(){
 let permits, cities;
 try{
  const v=await API.rpc("bel_ruhsat_merkezi");
  cities=v.iller||[];
  permits=(v.benim||[]).filter(r=>r.tur==="kur_magaza"&&r.durum==="onay"&&
   r.sirket&&r.il_id&&r.karar_zamani&&
   (Date.now()-new Date(r.karar_zamani).getTime())<72*60*60*1000);
 }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);return;}
 if(!permits.length){
  if(await onayla("Market ruhsatı gerekli",
   "Henüz geçerli, onaylı market kuruluş ruhsatın görünmüyor. Belediye Yatırım Ruhsat Merkezi'nden başvuru yapabilirsin.",
   "Ruhsat Merkezi'ne git")){
   if(typeof window.msRuhsatMerkeziAc==="function")window.msRuhsatMerkeziAc();
   else if(typeof window.belRuhsatMerkeziEkrani==="function")ekranAc(belRuhsatMerkeziEkrani);
   else toast("Ruhsat Merkezi için Ekonomi menüsünü aç.",true);
  }
  return;
 }
 const ilAdi=id=>cities.find(x=>Number(x.id)===Number(id))?.ad||"İl "+id;
 const el=popup("Onaylı ruhsatla market kur",
  '<p class="alt">Belediye onaylı market ruhsatını kullanarak aynı isim ve ilde yeni ticaret şirketiyle market aç. Ruhsat başvurusunu tekrar yapmazsın. Sermaye şahsi cüzdanından; ruhsat harcı yeni şirket kasasından bir kez tahsil edilir.</p>'+
  choices("tcMarketPermit","Onaylı market ruhsatı",
   permits.map(r=>[r.id,r.sirket+" · "+ilAdi(r.il_id)+" · Onaylı"]))+
  field("tcMarketCapital","Kuruluş sermayesi (TL)",200000,100000,100000000)+
  '<p class="alt" id="tcMarketPermitInfo"></p>',
  "Marketi kur",async root=>{
   const r=permits.find(x=>Number(x.id)===Number(sel(root,"tcMarketPermit")));
   const capital=Number(sel(root,"tcMarketCapital"));
   if(!r||!Number.isInteger(capital)||capital<100000||capital>100000000){
    toast("Geçerli ruhsat ve 100.000-100.000.000 TL arası sermaye seç.",true);return;
   }
   if(!await onayla("Market kuruluşunu onayla",
    ilAdi(r.il_id)+" ilinde "+r.sirket+" isimli market "+money(capital)+
    " sermayeyle kurulacak. Belediye ruhsat harcı yalnızca kuruluş sırasında şirket kasasından kesilecek.",
    "Kur ve mağazalara bağla"))return;
   try{
    await API.rpc("eko_islem",{p_eylem:"kur",
     p_veri:{tur:"magaza",il:Number(r.il_id),ad:r.sirket,tutar:capital}});
    modalKapat();
    toast("Market kuruldu. Üreticilerden stok alarak müşterilere satış yapabilirsin.");
    if(typeof durumYenile==="function")durumYenile().catch(()=>{});
    await ticaretMerkezEkrani("magaza");
   }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);}
  });
 const info=()=>{
  const r=permits.find(x=>Number(x.id)===Number(sel(el,"tcMarketPermit")));
  if(r)el.querySelector("#tcMarketPermitInfo").textContent="Ruhsat #"+r.id+
   " · "+ilAdi(r.il_id)+" · Son geçerlilik: "+
   date(new Date(new Date(r.karar_zamani).getTime()+72*60*60*1000).toISOString());
 };
 el.querySelector("#tcMarketPermit").onchange=info;info();
}
function convert(){
 const all=(TC.veri?.sirketler||[]).filter(x=>!x.tur&&x.yonetici);
 const allowed=all.filter(x=>["tarim","sanayi","teknoloji","ticaret","market"].includes(x.sektor));
 if(!allowed.length){
  toast("Üretime bağlanabilecek tarım, sanayi, teknoloji veya ticaret şirketin yok. Onaylı fabrika ruhsatın varsa aşağıdaki kuruluş butonunu kullan.",true);
  return;
 }
 const el=popup("Mevcut şirketi işletmeye bağla",
  '<p class="alt">Ayrı şirket kurmadan elindeki şirketi üretim veya mağazacılığa bağla. Eski otomatik gelirler yerine ticaret geliri işler.</p>'+
  choices("tcCompany","Şirket",allowed.map(x=>[x.id,x.ad+" · "+x.sektor]))+
  '<div id="tcConversion"></div>',"Bağla",async m=>{
    const s=mine(Number(sel(m,"tcCompany"))),tur=["tarim","sanayi","teknoloji"].includes(s.sektor)?"fabrika":"magaza";
    const group=tur==="fabrika"?sel(m,"tcGroup"):null;
    if(!await onayla("Ticaret faaliyeti başlasın","Şirketin eski otomatik faaliyet kazancı yerine ticaret faaliyetleri uygulanır.","Bağla"))return;
    try{
      await API.rpc("eko_ticaret_islem",{p_eylem:"bagla",p_veri:{sirket:s.id,urun:group}});
      modalKapat();toast("Şirket ekonomiye bağlandı.");await ticaretMerkezEkrani();
    }catch(err){toast(hataCevir(err.message),true);}
  });
 const update=()=>{
   const s=mine(Number(sel(el,"tcCompany"))),factory=["tarim","sanayi","teknoloji"].includes(s.sektor);
   const groups=s.sektor==="tarim"?[["gida","Gıda ve tüketim"]]:s.sektor==="teknoloji"?[["teknoloji","Teknoloji"]]:
    [["gida","Gıda"],["teknoloji","Teknoloji"],["malzeme","Yapı malzemeleri"]];
   el.querySelector("#tcConversion").innerHTML=factory?choices("tcGroup","Fabrikanın üretim grubu",groups):
     '<p class="alt">Bu şirket mağaza olarak bağlanacak. Sonra market, fast food veya kahve kategorisini seçebilirsin.</p>';
 };
 el.querySelector("#tcCompany").onchange=update;update();
}
function produce(id,preferredProduct){
 const firm=mine(id);
 if(!firm||firm.tur!=="fabrika"||!firm.yonetici){toast("Üretimi yönetebileceğin fabrika bulunamadı.",true);return;}
 const list=(TC.veri.urunler||[]).filter(x=>x.grup===firm.grup);
 if(!list.length){toast("Bu üretim grubunda ürün bulunamadı.",true);return;}
 const m=popup(firm.ad+" · Üretim emri",
 choices("tcItem","Üretilecek ürün",list.map(x=>[x.kod,x.ad]))+
 field("tcQty","Üretim adedi",10,1,500)+
 '<div class="tc-hint" id="tcDetails"></div>',
 "Üretimi başlat",async node=>{
  const p=item(sel(node,"tcItem")),qty=Number(sel(node,"tcQty"));
  const max=tcBatchCapacity(firm,p);
  if(!p||!Number.isInteger(qty)||qty<1||qty>max){toast("Bu fabrikanın güncel parti kapasitesi "+max+" adet. Adedi buna göre ayarla.",true);return;}
  await action("uret",{sirket:id,urun:p.kod,adet:qty},"Üretim emri verildi. Süre bitince stoklara eklenecek.");
 });
 const refresh=()=>{
   const p=item(sel(m,"tcItem")),qty=Number(sel(m,"tcQty"));
   if(!p)return;
   const max=tcBatchCapacity(firm,p);
   m.querySelector("#tcQty").max=max;
   m.querySelector("#tcDetails").textContent="Güncel parti kapasitesi "+max+" adet (başlangıç "+p.parti+
   ") · Süre "+p.dakika+" dk · Maliyet "+money(p.maliyet*qty)+
   " · Önerilen raf fiyatı "+money(p.satis)+" · "+tcCapacityDescription(firm);
 };
 if(preferredProduct&&list.some(x=>x.kod===preferredProduct))
  m.querySelector("#tcItem").value=preferredProduct;
 m.querySelector("#tcItem").onchange=refresh;m.querySelector("#tcQty").oninput=refresh;refresh();
}
function kitchenPrepare(id,preferred){
 const s=mine(id);
 if(!s||!s.yonetici||s.tur!=="magaza"||!["fastfood","kahve"].includes(s.kategori)){
  toast("Ürün hazırlama yalnızca fast-food ve kahvecilerde yapılabilir.",true);return;
 }
 const prods=(TC.veri?.urunler||[]).filter(x=>x.kategori===s.kategori);
 if(!prods.length){toast("Bu işletmeye uygun ürün yok.",true);return;}
 const m=popup(s.ad+" · Mutfakta ürün hazırla",
  '<p class="alt">Malzeme ve hazırlama maliyeti işletme kasasından hemen ödenir. Ürünler hazırlık bitince stoğa girer ve şehir sakinlerine saatlik satılır.</p>'+
  choices("tcKitchenItem","Ürün",prods.map(x=>[x.kod,x.ad]))+
  field("tcKitchenQty","Adet",10,1,250)+
  '<p class="tc-hint" id="tcKitchenDetails"></p>',
  "Hazırlamayı başlat",async root=>{
   const p=item(sel(root,"tcKitchenItem")),qty=Number(sel(root,"tcKitchenQty"));
   const max=p?Math.min(Number(p.parti)||0,250):0;
   if(!p||p.kategori!==s.kategori||!Number.isInteger(qty)||qty<1||qty>max){
    toast("Adet 1 ile "+max+" arasında olmalıdır.",true);return;
   }
   try{
    const result=await API.rpc("eko_magaza_hazirla",{p_sirket:id,p_urun:p.kod,p_adet:qty});
    modalKapat();toast(qty+" adet "+p.ad+" hazırlanıyor. Hazır olacağı saat: "+date(result.hazir));
    await ticaretMerkezEkrani("magaza");
   }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);}
  });
 if(preferred&&prods.some(x=>x.kod===preferred))m.querySelector("#tcKitchenItem").value=preferred;
 const update=()=>{
  const p=item(sel(m,"tcKitchenItem")),qty=Number(sel(m,"tcKitchenQty"))||0;
  if(!p)return;
  const max=Math.min(Number(p.parti)||0,250);
  m.querySelector("#tcKitchenQty").max=max;
  m.querySelector("#tcKitchenDetails").textContent="Parti üst sınırı "+max+
   " · Maliyet "+money(p.maliyet*qty)+" · Hazırlık "+Math.max(10,Math.ceil(p.dakika*.5))+
   " dakika · Önerilen satış fiyatı "+money(p.satis)+" / adet";
 };
 m.querySelector("#tcKitchenItem").onchange=update;
 m.querySelector("#tcKitchenQty").oninput=update;
 update();
}
function price(id,prod,current){
 const p=item(prod);
 popup("Ürün satış fiyatı",'<p class="alt">'+tm(p?.ad||prod)+' · Fiyat piyasa ve maliyet sınırları içinde olmalıdır.</p>'+
 field("tcPrice","Yeni birim satış fiyatı ₺",Number(current),1,100000000),
 "Fiyatı kaydet",m=>action("fiyat",{sirket:id,urun:prod,tutar:Number(sel(m,"tcPrice"))},"Fiyat güncellendi."));
}
function wholesale(id){
 const arr=(TC.veri?.tedarikciler||[]).filter(x=>Number(x.sirket)!==Number(id));
 if(!arr.length){toast("Şu an hazır stoku bulunan üretici yok.",true);return;}
 const m=popup(mine(id).ad+" · Toptan tedarik",
 choices("tcSupplier","Üretici ve stok",arr.map(x=>[x.sirket+"|"+x.urun,(item(x.urun)?.ad||x.urun)+" · "+x.ad+" · "+x.adet+" adet · "+money(x.fiyat)]))+
 field("tcQty","Alınacak adet",5,1,500)+
 '<p id="tcDetails" class="alt"></p>',
 "Toptan satın al",async root=>{
   const [producer,product]=sel(root,"tcSupplier").split("|"),qty=Number(sel(root,"tcQty"));
   if(!Number.isInteger(qty)||qty<1){toast("Adet geçersiz.",true);return;}
   if(!await onayla("Toptan stok al","Ürün bedeli mağazanın kasasından üreticinin kasasına aktarılacak.","Satın al"))return;
   await action("toptan",{sirket:id,hedef:Number(producer),urun:product,adet:qty},"Ürünler mağaza stoğuna eklendi.");
 });
 const update=()=>{
   const [supplier,product]=sel(m,"tcSupplier").split("|");
   const x=arr.find(x=>String(x.sirket)===supplier&&x.urun===product);
   m.querySelector("#tcDetails").textContent=x?"Stok "+x.adet+" adet · Toplam "+money(x.fiyat*Number(sel(m,"tcQty"))):"";
 };
 m.querySelector("#tcQty").oninput=update;m.querySelector("#tcSupplier").onchange=update;update();
}
function automation(id){
 const prods=(TC.veri?.urunler||[]).map(x=>[x.kod,x.ad+" · piyasa "+money(x.satis)]);
 const m=popup("Otomatik stok yenileme",
 '<p class="alt">7 gün boyunca ürün başına 12.000 TL oyun parası. Stok eşiğinin altına düştüğünde uygun fiyatlı bir oyuncu üreticisinden sipariş verilir. Param veya üretici stoku yoksa alım yapılmaz.</p>'+
 choices("tcItem","Ürün",prods)+field("tcMin","Yenileme eşiği",5,0,300)+
 field("tcQty","Sipariş adedi",20,1,500)+field("tcMax","Azami toptan birim fiyat ₺",500,1,100000000)+
 '<p id="tcAuto" class="alt"></p>',"Otomasyonu başlat / güncelle",async root=>{
   const p=item(sel(root,"tcItem"));
   await action("oto",{sirket:id,urun:p.kod,esik:Number(sel(root,"tcMin")),adet:Number(sel(root,"tcQty")),
   tutar:Number(sel(root,"tcMax")),aktif:true},"Otomatik tedarik ayarlandı.");
 });
 const update=()=>{
  const p=item(sel(m,"tcItem"));
  if(!p)return;
  m.querySelector("#tcMax").value=Math.round(p.satis*.9);
  const active=(TC.veri.oto||[]).find(x=>x.sirket===id&&x.urun===p.kod&&x.aktif&&new Date(x.bitis)>new Date());
  m.querySelector("#tcAuto").textContent=active?"Mevcut abonelik: "+date(active.bitis)+". Aktif sürede yeniden ücret alınmaz.":
   "Bu ürün için yeni 7 günlük abonelik: 12.000 TL";
 };
 m.querySelector("#tcItem").onchange=update;update();
}
function offAuto(sirket,urun){action("oto",{sirket,urun,aktif:false},"Otomatik tedarik kapatıldı.");}

/* Opt-in automation: factory production, own-factory supply and NPC sales switch. */
async function tcAutoAction(kind,data,label){
 try{
  await API.rpc("eko_otomasyon_ayarla",{p_eylem:kind,p_veri:data});
  if(typeof modalKapat==="function")modalKapat();
  toast(label||"Otomasyon ayarı kaydedildi.");
  await ticaretMerkezEkrani();
 }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);}
}
function tcAutoProduction(id,preferred){
 const s=mine(id);
 if(!s||s.tur!=="fabrika"||!s.yonetici){toast("Fabrika yönetim yetkin yok.",true);return;}
 const products=(TC.veri?.urunler||[]).filter(x=>x.grup===s.grup);
 if(!products.length){toast("Bu fabrikanın ürün kataloğu boş.",true);return;}
 const current=()=> (TC.otoVeri?.uretim||[]).find(x=>Number(x.sirket)===Number(id)&&x.urun===sel(m,"tcApItem"));
 const m=popup(s.ad+" · Otomatik üretim",
  '<p class="alt">Ücretsiz otomasyon ayarı. Fabrika stoğu belirlenen eşiğe düşünce, başka üretim emri yoksa, kasadan gerçek maliyeti ödeyerek yeni üretim başlar. Günlük bütçe sınırı ve üretim süresi geçerlidir.</p>'+
  choices("tcApItem","Ürün",products.map(x=>[x.kod,x.ad]))+
  field("tcApMin","Üretim başlatma stok eşiği",50,0,5000)+
  field("tcApQty","Üretim partisi (adet)",20,1,500)+
  field("tcApBudget","Günlük azami üretim harcaması (TL)",5000,100,100000000)+
  '<p id="tcApInfo" class="tc-hint"></p>',
  "Otomatik üretimi aç / güncelle",async root=>{
   const p=item(sel(root,"tcApItem")),min=Number(sel(root,"tcApMin"));
   const qty=Number(sel(root,"tcApQty")),budget=Number(sel(root,"tcApBudget"));
   if(!p||!Number.isInteger(min)||min<0||min>5000||
    !Number.isInteger(qty)||qty<1||qty>Math.min(500,tcBatchCapacity(s,p))||
    !Number.isFinite(budget)||budget<Math.max(100,Math.round(p.maliyet*qty))){
    toast("Stok, parti veya günlük bütçe geçersiz. Üretim maliyetini karşılayacak bütçe belirle.",true);return;
   }
   await tcAutoAction("uretim",{sirket:id,urun:p.kod,esik:min,adet:qty,butce:budget,aktif:true},
    "Fabrikanda otomatik üretim etkinleştirildi.");
  });
 if(preferred&&products.some(p=>p.kod===preferred))m.querySelector("#tcApItem").value=preferred;
 const update=()=>{
  const p=item(sel(m,"tcApItem"));if(!p)return;
  const a=current(),max=Math.min(500,tcBatchCapacity(s,p));
  m.querySelector("#tcApMin").value=a?.esik??50;
  m.querySelector("#tcApQty").value=Math.min(max,a?.miktar??Math.min(100,max));
  m.querySelector("#tcApQty").max=max;
  m.querySelector("#tcApBudget").value=a?.gunluk_butce??Math.max(100,Math.round(p.maliyet*max*3));
  m.querySelector("#tcApInfo").textContent="Parti sınırı "+max+" adet · Süre "+p.dakika+
   " dk · Birim üretim maliyeti "+money(p.maliyet)+
   (a?.aktif?" · Otomatik üretim AÇIK":" · Otomatik üretim KAPALI")+
   (a?.son_hata?" · Son uyarı: "+a.son_hata:"");
 };
 m.querySelector("#tcApItem").onchange=update;update();
}
function tcOwnSupply(id){
 const s=mine(id),factories=own("fabrika");
 if(!s||s.tur!=="magaza"||!s.yonetici){toast("Market yönetim yetkin yok.",true);return;}
 if(!factories.length){toast("Önce yönettiğin bir fabrika kur veya şirketini üretime bağla.",true);return;}
 const valid=f=> (TC.veri?.urunler||[]).filter(x=>x.grup===f.grup);
 const eligible=factories.filter(f=>valid(f).length);
 if(!eligible.length){toast("Fabrikalarında tedarik edilebilen ürün bulunamadı.",true);return;}
 const m=popup(s.ad+" · Kendi fabrikamdan otomatik al",
  '<p class="alt">Market stoğu eşiğe düşünce seçtiğin fabrikanın tamamlanmış üretiminden ürün alınır. Gerçek toptan bedel market kasasından fabrika kasasına aktarılır; üretim ve vergi kayıtları korunur. Hazır ürün, uygun fiyat veya bakiye yoksa bekler. Otomasyon için ayrıca abonelik ücreti yoktur.</p>'+
  choices("tcOsFactory","Fabrikan",eligible.map(x=>[x.id,x.ad+" · "+x.grup]))+
  choices("tcOsItem","Ürün",valid(eligible[0]).map(x=>[x.kod,x.ad]))+
  field("tcOsMin","Market yenileme stok eşiği",30,0,5000)+
  field("tcOsQty","Toptan alınacak adet",50,1,500)+
  field("tcOsMax","Azami toptan birim fiyat (TL)",200,1,100000000)+
  '<p id="tcOsInfo" class="tc-hint"></p>',
  "Kendi fabrikamdan otomatik al",async root=>{
   const f=Number(sel(root,"tcOsFactory")),p=item(sel(root,"tcOsItem"));
   const min=Number(sel(root,"tcOsMin")),qty=Number(sel(root,"tcOsQty"));
   const max=Number(sel(root,"tcOsMax"));
   if(!eligible.some(x=>Number(x.id)===f)||!p||
      !Number.isInteger(min)||min<0||min>5000||
      !Number.isInteger(qty)||qty<1||qty>500||
      !Number.isFinite(max)||max<p.maliyet||max>p.satis*3){
      toast("Fabrika, ürün, stok veya fiyat sınırı geçersiz.",true);return;
   }
   await tcAutoAction("kendi",{sirket:id,fabrika:f,urun:p.kod,esik:min,adet:qty,ust:max,aktif:true},
    "Fabrikan ile marketin arasında otomatik tedarik açıldı.");
  });
 const update=()=>{
  const f=eligible.find(x=>Number(x.id)===Number(sel(m,"tcOsFactory")));
  if(!f)return;
  const p=item(sel(m,"tcOsItem"));
  if(!p)return;
  const a=(TC.otoVeri?.kendi||[]).find(x=>Number(x.magaza)===Number(id)&&Number(x.fabrika)===Number(f.id)&&x.urun===p.kod);
  const stock=(TC.veri?.stok||[]).find(x=>Number(x.sirket)===Number(f.id)&&x.urun===p.kod);
  m.querySelector("#tcOsMin").value=a?.esik??30;
  m.querySelector("#tcOsQty").value=a?.miktar??50;
  m.querySelector("#tcOsMax").value=a?.ust??Math.max(p.maliyet,Math.min(p.satis*3,Number(stock?.fiyat)||p.satis*.9));
  m.querySelector("#tcOsInfo").textContent="Fabrikada hazır stok: "+Number(stock?.adet||0)+
   " adet · Toptan fiyat: "+(stock?money(stock.fiyat):"Henüz stok yok")+
   (a?.aktif?" · Otomatik alım AÇIK":" · Otomatik alım KAPALI")+
   (a?.son_hata?" · Son uyarı: "+a.son_hata:"");
 };
 const changeFactory=()=>{
  const f=eligible.find(x=>Number(x.id)===Number(sel(m,"tcOsFactory")));
  const list=valid(f||eligible[0]);
  m.querySelector("#tcOsItem").innerHTML=list.map(x=>'<option value="'+tm(x.kod)+'">'+tm(x.ad)+'</option>').join("");
  update();
 };
 m.querySelector("#tcOsFactory").onchange=changeFactory;
 m.querySelector("#tcOsItem").onchange=update;
 update();
}
function tcDisableProduction(sirket,urun){
 tcAutoAction("uretim",{sirket,urun,aktif:false},"Otomatik üretim kapatıldı.");
}
function tcDisableOwn(magaza,fabrika,urun){
 tcAutoAction("kendi",{sirket:magaza,fabrika,urun,aktif:false},"Kendi fabrikandan otomatik tedarik kapatıldı.");
}
function tcToggleSales(id,active){
 tcAutoAction("satis",{sirket:id,aktif:!!active},active?
  "Market için sanal müşteri satışı açıldı.":"Market için sanal müşteri satışı durduruldu.");
}

function storeType(id){
 const s=mine(id);
 popup("Mağaza faaliyet türü",'<p class="alt">Fast food, kahve ve market mağazaları farklı müşteri kitlelerine hizmet verir. Ürünlerin stokta olması yine zorunludur.</p>'+
 choices("tcType","Faaliyet",[
 ["market","🛒 Market / perakende"],["fastfood","🍔 Fast food"],["kahve","☕ Kahveci"]]),
 "Kaydet",m=>action("magaza_tur",{sirket:id,kategori:sel(m,"tcType")},"Faaliyet alanı değiştirildi."));
}
function brandSettings(){
 const stores=own("magaza").filter(x=>!x.bayilik);
 if(!stores.length){toast("Marka oluşturmak için bayilik bağlı olmayan bir mağazan olmalı.",true);return;}
 popup("Franchise zinciri kur / güncelle",
 choices("tcFirm","Marka sahibi mağaza",bizNames(stores))+
 choices("tcType","Zincir türü",[["market","🛒 Market"],["fastfood","🍔 Fast food"],["kahve","☕ Kahve"]])+
 field("tcFee","Tek seferlik isim hakkı ₺",25000,1000,1000000)+
 field("tcRoyalty","Cirodan alınacak pay (%)",5,1,15)+
 field("tcProfit","Pozitif net kârdan pay (%)",8,0,20)+
 '<p class="alt">Marka sahibi isim hakkını başlangıçta, ciro ve net kâr payını gerçekleşen satışlardan alır. Zarar paylaştırılmaz.</p>',
 "Markayı kaydet",m=>action("marka",{
 sirket:Number(sel(m,"tcFirm")),kategori:sel(m,"tcType"),tutar:Number(sel(m,"tcFee")),
 ciro:Number(sel(m,"tcRoyalty")),kar:Number(sel(m,"tcProfit"))
 },"Franchise kuralları kaydedildi."));
}
function franchiseBuy(id){
 const arr=own("magaza").filter(x=>!x.bayilik&&!x.marka&&x.id!==id);
 if(!arr.length){toast("Önce bayilik alabilecek bir mağazan olmalı.",true);return;}
 const m=(TC.veri.markalar||[]).find(x=>x.id===id);
 popup(tm(m?.ad)+" · Bayilik al",'<p class="alt">Zincir '+tm(m?.kategori)+' · İsim hakkı '+money(m?.bedel)+
 ' · Ciro payı %'+tm(m?.ciro_payi)+' · Pozitif net kâr payı %'+tm(m?.kar_payi)+'</p>'+
 choices("tcFirm","Bayilik açacak mağaza",bizNames(arr)),
 "Sözleşmeyi imzala",async el=>{
  if(!await onayla("Bayilik sözleşmesi","İsim hakkı mağaza kasasından markaya aktarılacak. Satışlarda belirlenen paylar kesilecek.","İmzala"))return;
  await action("bayilik",{sirket:Number(sel(el,"tcFirm")),hedef:id},"Franchise bayiliği açıldı.");
 });
}
function panel(){
 const d=TC.veri||{};
 let html="";
 const firms=d.sirketler||[];
 const available=firms.filter(x=>x.yonetici&&!x.tur&&
  ["tarim","sanayi","teknoloji","ticaret","market"].includes(x.sektor));
 const factory=own("fabrika");
 const situation=factory.length?"Üretim yapabileceğin fabrikan mevcut.":
  available.length?"Uygun şirketin var; üretime bağlayarak ürün üretebilirsin.":
  firms.length?"Şirketlerin var ancak üretime uygun bir fabrika şirketi görünmüyor. Enerji ve ajans şirketleri bu bölümde gıda üretemez.":
  "Henüz üretim şirketi kurmadın.";
 const hint=card("Ticaret sistemi",(TC.sekme==="magaza"
  ?"Market kurmak için onaylı belediye ruhsatını kullan veya mevcut ticaret şirketini mağazaya bağla."
  :tm(situation)+" Şirketlerim'de bir sanayi, tarım veya teknoloji şirketi kurabilir veya onaylı belediye ruhsatınla doğrudan fabrika açabilirsin."),
 (TC.sekme==="magaza"
  ?button("Onaylı ruhsatımla market kur","tcMarketPermit()")
  :button("Onaylı ruhsatımla fabrika kur","tcFactoryPermit()"))+
 secondary("Mevcut şirketimi bağla","tcConvert()")+
 secondary("Şirketlerime git","ekranAc(sirketYonetimEkrani)"));
 if(TC.sekme==="uretim"){
  html+=card("Üretim ve toptan satış","Gıda, teknoloji veya yapı malzemeleri üreten fabrikalarda farklı ürünlerin parti kapasitesi ve üretim süresi vardır. Üretim bedeli emir verildiğinde düşer, ürünler süre sonunda satış stoklarına geçer.");
  html+=hint;
  const arr=own("fabrika");
  for(const s of arr){
   const st=storeStock(s.id);
   html+=card("🏭 "+s.ad,"Faaliyet: "+tm(s.grup)+" · Kasa "+money(s.kasa)+
   " · Stokta "+st.reduce((n,x)=>n+Number(x.adet),0)+" ürün"+
   '<p class="tc-hint">'+tm(tcCapacityDescription(s))+"</p>",
   button("Üretim emri ver","tcProduce("+s.id+")")+
   secondary("⚙️ Otomatik üretim ayarla","tcAutoProduction("+s.id+")"));
   for(const a of (TC.otoVeri?.uretim||[]).filter(a=>Number(a.sirket)===Number(s.id)&&a.aktif)){
    const code=String(a.urun||"");if(!/^[a-z0-9_]+$/.test(code))continue;
    html+=card("⚙️ Otomatik üretim · "+(item(code)?.ad||code),
      "Eşik "+a.esik+" adet · Parti "+a.miktar+" adet · Günlük bütçe "+money(a.gunluk_butce)+
      (a.son_islem?" · Son üretim "+date(a.son_islem):"")+
      (a.son_hata?" · Uyarı: "+tm(a.son_hata):""),
      secondary("Otomatik üretimi durdur","tcDisableProduction("+s.id+",'"+code+"')"));
   }
   for(const x of st)html+=card((item(x.urun)?.ad||x.urun)+" · "+x.adet+" adet",
   "Birim stok maliyeti "+money(x.maliyet)+" · Toptan satış "+money(x.fiyat),
   secondary("Toptan fiyatı belirle","tcPrice("+s.id+",'"+x.urun+"',"+Number(x.fiyat)+")"));
  }
  html+=title("Üretim süreçleri","son 60 parti");
  for(const x of d.uretim||[])html+=card((item(x.urun)?.ad||x.urun)+" · "+x.adet+" adet",
   "Maliyet "+money(x.maliyet)+" · "+(x.tamam?"Stoklara aktarıldı":"Hazır olacağı zaman "+date(x.hazir)));
  html+=title("Üretilebilen ürünler",""+(d.urunler||[]).length+" çeşit");
  html+='<details class="tc-products"><summary style="padding:14px;border-radius:12px;background:var(--panel);color:var(--txt);cursor:pointer">Tüm ürünleri göster / gizle</summary><div style="padding-top:10px">';
  for(const p of d.urunler||[]){
   const f=factory.find(x=>x.grup===p.grup);
   const code=String(p.kod||"");
   const canProduce=!!f&&/^[a-z0-9_]+$/.test(code);
   html+=card(p.ad,
    tm(p.grup)+" · "+(canProduce?"Güncel parti kapasitesi "+tcBatchCapacity(f,p)+" (başlangıç "+p.parti+")":
    "Başlangıç parti kapasitesi "+p.parti)+" · "+p.dakika+" dakika · Birim maliyet "+money(p.maliyet)+
    " · Önerilen tüketici fiyatı "+money(p.satis),
    canProduce?button("Bu ürünü üret","tcProduce("+Number(f.id)+",'"+code+"')"):
    secondary("Bu ürünü üretmek için fabrika kur","tcFactoryPermit('"+(
     ["gida","teknoloji","malzeme"].includes(p.grup)?p.grup:"gida")+"')"));
  }
  html+='</div></details>';
 }
 if(TC.sekme==="magaza"){
  html+=card("Şehir müşterilerine satış","Marketler oyuncu fabrikalarından toptan alıp mahalle sakinleri ve ailelere satar. Fast-food ve kahveci kendi ürünlerini malzeme maliyeti ödeyerek hazırlar. Öğrenciler, çalışanlar ve aileler sanal müşteridir. Talep; günün saati, şehir gelişimi, rekabet, fiyat, stok ve günlük şehir kotasına göre değişir. Satış garanti değildir.");
  html+=hint;
  const shops=own("magaza");
  const cats={market:"🛒 Market",kahve:"☕ Kahveci",fastfood:"🍔 Fast food"};
  for(const s of shops){
   const st=storeStock(s.id),homeCook=["fastfood","kahve"].includes(s.kategori);
   const pending=(d.uretim||[]).filter(x=>Number(x.sirket)===Number(s.id)&&!x.tamam);
   const buyers=s.kategori==="fastfood"?"Öğrenciler, çalışanlar ve aileler":
    s.kategori==="kahve"?"Ofis çalışanları, öğrenciler ve kahve müşterileri":
    "Mahalle sakinleri ve aileler";
   html+=card((cats[s.kategori]||"🛍️ İşletme")+" · "+s.ad,
    "Kasa "+money(s.kasa)+" · Sermaye "+money(s.sermaye)+" · Stok "+
    st.reduce((a,x)=>a+Number(x.adet||0),0)+" adet · Alıcılar: "+tm(buyers)+
    '<div class="tc-hint">Sonraki saatlik müşteri kontrolü: '+
    tm(s.sonraki_satis?date(s.sonraki_satis):"Saatlik")+
    ' · Hazırlanmakta olan parti: '+pending.length+"</div>",
    (homeCook?button("Kendi ürünümü hazırla","tcKitchen("+s.id+")"):
      button("Fabrikadan ürün satın al","tcWholesale("+s.id+")"))+
    secondary("İşletme türü","tcType("+s.id+")")+
    secondary("🏭 Kendi fabrikamdan otomatik al","tcOwnSupply("+s.id+")")+
    secondary("⚙️ Dış üreticiden otomatik al","tcAutomation("+s.id+")")+
    secondary((TC.otoVeri?.satis||[]).find(x=>Number(x.sirket)===Number(s.id))?.aktif===false?
      "▶️ Otomatik satışı aç":"⏸️ Otomatik satışı durdur",
     "tcToggleSales("+s.id+","+
      ((TC.otoVeri?.satis||[]).find(x=>Number(x.sirket)===Number(s.id))?.aktif===false?"true":"false")+")"));
   for(const q of pending)html+=card("Hazırlanıyor · "+(item(q.urun)?.ad||q.urun),
    "Ürün: "+q.adet+" adet · Bitiş saati: "+date(q.hazir));
   for(const x of st){
    const code=String(x.urun||"");
    if(!/^[a-z0-9_]+$/.test(code))continue;
    html+=card((item(code)?.ad||code)+" · "+x.adet+" adet",
     "Ürün maliyeti "+money(x.maliyet)+" · Raf satış fiyatı "+money(x.fiyat),
     secondary("Raf fiyatını değiştir","tcPrice("+s.id+",'"+code+"',"+Number(x.fiyat)+")"));
   }
   for(const a of (TC.otoVeri?.kendi||[]).filter(a=>Number(a.magaza)===Number(s.id)&&a.aktif)){
    const code=String(a.urun||"");if(!/^[a-z0-9_]+$/.test(code))continue;
    const fac=mine(a.fabrika);
    html+=card("🏭 Kendi fabrikamdan · "+(item(code)?.ad||code),
      "Fabrika: "+tm(fac?.ad||String(a.fabrika))+" · Yenileme eşiği "+
      a.esik+" · Alınacak "+a.miktar+" adet"+
      (a.son_islem?" · Son alım "+date(a.son_islem):"")+
      (a.son_hata?" · Uyarı: "+tm(a.son_hata):""),
      secondary("Kendi fabrikamdan alımı kapat","tcDisableOwn("+s.id+","+Number(a.fabrika)+",'"+code+"')"));
   }
   for(const x of (d.oto||[]).filter(x=>Number(x.sirket)===Number(s.id)&&x.aktif))
    html+=card("Otomatik tedarik · "+(item(x.urun)?.ad||x.urun),
     "Stok eşiği "+x.esik+" · Sipariş "+x.miktar+" adet · Bitiş "+date(x.bitis),
     secondary("Otomatik siparişi kapat","tcDisable("+s.id+",'"+x.urun+"')"));
  }
  html+=title("Sanal müşterilere gerçekleşen satışlar","Son işlemler");
  const recent=(d.satislar||[]).filter(x=>shops.some(s=>Number(s.id)===Number(x.sirket)));
  if(!recent.length)html+=card("Henüz satış yapılmadı","Stok oluşturduktan sonra saatlik müşteri alımları başlayabilir; satış garanti edilmez.");
  for(const x of recent.slice(0,20)){
   const firm=shops.find(s=>Number(s.id)===Number(x.sirket));
   html+=card((item(x.urun)?.ad||x.urun)+" · "+(firm?.ad||"İşletme"),
    "Alıcı: "+tm(x.musteri||"Yerel müşteriler")+" · "+x.adet+" adet · "+date(x.zaman)+
    " · Ciro "+money(x.ciro)+" · Net kâr "+money(x.kar));
  }
  html+=title("Oyuncu fabrikalarındaki stoklar","Toptan satış teklifleri");
  if(!(d.tedarikciler||[]).length)html+=card("Hazır üretici stoğu yok","Fabrika üretimi tamamlandığında burada satış teklifi görünür.");
  for(const x of d.tedarikciler||[])html+=card((item(x.urun)?.ad||x.urun)+" · "+x.ad,
    x.adet+" adet · Toptan fiyat "+money(x.fiyat)+" / adet");
 }
 if(TC.sekme==="zincir"){
  html+=card("Gerçekçi mağaza zincirleri","Fast food, kahveci ve market markaları kur. Başka oyunculara isim hakkı sat, brüt cirodan pay ve <b>yalnızca pozitif net kârdan</b> ek ortaklık payı al.",
  button("Franchise markası kur","tcBrand()"));
  for(const s of own("magaza"))html+=card(s.ad,
   (s.marka?"Markan: "+tm(s.marka.kategori)+" · Cirodan %"+s.marka.ciro_payi+
     " · Kârdan %"+s.marka.kar_payi:
    s.bayilik?"Bayilik: "+s.bayilik.marka+" · Cirodan %"+s.bayilik.ciro_payi+" · Kârdan %"+s.bayilik.kar_payi:
    "Bağımsız mağaza"));
  html+=title("Bayilik alınabilen markalar","Oyuncu işletmeleri");
  if(!(d.markalar||[]).length)html+=card("Henüz franchise markası yok","Mağaza sahipleri kendi markalarını oluşturabilir.");
  for(const m of d.markalar||[])html+=card("🏷️ "+m.ad,
   "Tür: "+tm(m.kategori)+" · İsim hakkı "+money(m.bedel)+" · Ciro payı %"+m.ciro_payi+
   " · Net kâr payı %"+m.kar_payi,
   button("Bayilik al","tcBuyBrand("+m.id+")"));
 }
 if(TC.sekme==="rapor"){
  const rows=(d.satislar||[]),sum=k=>rows.reduce((a,b)=>a+Number(b[k]||0),0);
  html+=card("Son işlemlerin gelir tablosu",
   '<div class="kv"><span>Toplam ciro</span><b>'+money(sum("ciro"))+'</b></div>'+
   '<div class="kv"><span>Satılan ürün maliyeti</span><b>'+money(sum("maliyet"))+'</b></div>'+
   '<div class="kv"><span>Personel ve işletme gideri</span><b>'+money(sum("gider"))+'</b></div>'+
   '<div class="kv"><span>Vergi</span><b>'+money(sum("vergi"))+'</b></div>'+
   '<div class="kv"><span>Marka ciro payı</span><b>'+money(sum("royalty"))+'</b></div>'+
   '<div class="kv"><span>Marka net kâr payı</span><b>'+money(sum("kar_payi"))+'</b></div>'+
   '<div class="kv"><span>Hesaplanan net kâr / zarar</span><b>'+money(sum("kar"))+'</b></div>');
  if(!rows.length)html+=card("Satış raporu yok","Mağazalar stok tedarik edip sanal müşterilere satış yaptıkça gelir tablosu oluşur.");
  for(const x of rows.slice(0,40))html+=card((item(x.urun)?.ad||x.urun)+" · "+x.adet+" adet",
   "Tarih "+date(x.zaman)+" · Ciro "+money(x.ciro)+" · Net "+money(x.kar));
 }
 return html;
}
async function ticaretMerkezEkrani(tab){
 if(tab&&["uretim","magaza","zincir","rapor"].includes(tab))TC.sekme=tab;
 yukleniyor("Üretim ve Ticaret");
 try{
  [TC.veri,TC.otoVeri]=await Promise.all([API.rpc("eko_ticaret_panel"),API.rpc("eko_otomasyon_panel").catch(()=>({uretim:[],kendi:[],satis:[]}))]);
  const tabs=[["uretim","🏭 Üretim"],["magaza","🛍️ Mağazalar"],["zincir","🏷️ Zincirler"],["rapor","📊 Kâr / Zarar"]];
  const html='<style>.tc-hero{padding:18px;border-radius:18px;background:linear-gradient(120deg,#293963,#46346c);color:#fff}.tc-hero h2{font-size:26px;color:#fff;margin:0 0 6px}.tc-hero p{font-size:13px;color:#d4dbf2}.tc-tabs{display:flex;gap:7px;overflow-x:auto;padding:10px 0;margin-bottom:8px}.tc-tabs button{white-space:nowrap;flex:0 0 auto;padding:10px 13px;border-radius:12px;border:1px solid var(--line2);background:var(--panel);color:var(--txt)}.tc-tabs button.tc-selected{border-color:#a995ff;background:#383063}.tc-card{margin-bottom:10px}.tc-card h3{margin:0 0 8px}.tc-card .btn{margin-top:6px;margin-right:5px}.tc-hint{padding:12px;margin:12px 0;background:var(--panel2);border-radius:12px;color:var(--txt)}</style>'+
   '<section class="tc-hero"><h2>🏭 Üretim ve Ticaret</h2><p>Üret · Tedarik et · Sanal müşterilere sat · Franchise zinciri kur</p></section>'+
   '<div class="tc-tabs">'+tabs.map(([key,label])=>'<button class="'+(key===TC.sekme?"tc-selected":"")+
   '" onclick="ticaretMerkezEkrani(\''+key+'\')">'+label+'</button>').join("")+'</div>'+panel();
  iskelet("Üretim ve Ticaret",html,{geri:true});
 }catch(err){iskelet("Üretim ve Ticaret",card("Bağlantı sorunu",tm(typeof hataCevir==="function"?hataCevir(err.message):err.message)),{geri:true});}
}
window.ticaretMerkezEkrani=ticaretMerkezEkrani;
window.tcConvert=convert;window.tcProduce=produce;window.tcPrice=price;window.tcWholesale=wholesale;
window.tcAutomation=automation;window.tcDisable=offAuto;window.tcType=storeType;
window.tcAutoProduction=tcAutoProduction;window.tcOwnSupply=tcOwnSupply;
window.tcDisableProduction=tcDisableProduction;window.tcDisableOwn=tcDisableOwn;
window.tcToggleSales=tcToggleSales;
window.tcBrand=brandSettings;window.tcBuyBrand=franchiseBuy;
window.tcFactoryPermit=factoryWithPermit;
window.tcMarketPermit=marketWithPermit;
window.tcKitchen=kitchenPrepare;
})();