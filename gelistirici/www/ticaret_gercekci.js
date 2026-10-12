/* Urun bazli uretim, toptan ticaret, NPC magaza satislari ve franchise. */
(function(){
"use strict";
const TC={sekme:"uretim",veri:null};
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
function convert(){
 const all=(TC.veri?.sirketler||[]).filter(x=>!x.tur&&x.yonetici);
 const allowed=all.filter(x=>["tarim","sanayi","teknoloji","ticaret"].includes(x.sektor));
 if(!allowed.length){toast("Önce Şirketlerim ekranında tarım, sanayi, teknoloji veya ticaret şirketi kurmalısın.",true);return;}
 const el=popup("Mevcut şirketi işletmeye bağla",
  '<p class="alt">Ayrı şirket kurmadan elindeki şirketi üretim veya mağazacılığa bağla. Eski otomatik gelirler yerine ticaret geliri işler.</p>'+
  choices("tcCompany","Şirket",allowed.map(x=>[x.id,x.ad+" · "+x.sektor]))+
  '<div id="tcConversion"></div>',"Bağla",async m=>{
    const s=mine(Number(sel(m,"tcCompany"))),tur=["tarim","sanayi","teknoloji"].includes(s.sektor)?"fabrika":"magaza";
    const group=tur==="fabrika"?sel(m,"tcGroup"):null;
    if(!await onayla("Ticaret faaliyeti başlasın","Şirketin eski otomatik faaliyet kazancı yerine ticaret faaliyetleri uygulanır.","Bağla"))return;
    try{
      await API.rpc("eko_islem",{p_eylem:"etkinlestir",p_veri:{sirket:s.id,tur,urun:group}});
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
function produce(id){
 const firm=mine(id);
 const list=(TC.veri.urunler||[]).filter(x=>x.grup===firm.grup);
 if(!list.length){toast("Bu üretim grubunda ürün bulunamadı.",true);return;}
 const m=popup(firm.ad+" · Üretim emri",
 choices("tcItem","Üretilecek ürün",list.map(x=>[x.kod,x.ad]))+
 field("tcQty","Üretim adedi",10,1,500)+
 '<div class="tc-hint" id="tcDetails"></div>',
 "Üretimi başlat",async node=>{
  const p=item(sel(node,"tcItem")),qty=Number(sel(node,"tcQty"));
  if(!p||!Number.isInteger(qty)||qty<1||qty>p.parti){toast("Parti kapasitesi aşıldı.",true);return;}
  await action("uret",{sirket:id,urun:p.kod,adet:qty},"Üretim emri verildi. Süre bitince stoklara eklenecek.");
 });
 const refresh=()=>{
   const p=item(sel(m,"tcItem")),qty=Number(sel(m,"tcQty"));
   if(!p)return;
   m.querySelector("#tcQty").max=p.parti;
   m.querySelector("#tcDetails").textContent="Parti üst sınırı "+p.parti+" · Süre "+p.dakika+
   " dk · Maliyet "+money(p.maliyet*qty)+" · Önerilen raf fiyatı "+money(p.satis);
 };
 m.querySelector("#tcItem").onchange=refresh;m.querySelector("#tcQty").oninput=refresh;refresh();
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
 const hint=card("Ticaret sistemi","Şirketlerim ekranında şirket kurduktan sonra buradan üretim veya perakende faaliyetine bağlayabilirsin.",
 button("Mevcut şirketimi bağla","tcConvert()")+secondary("Şirketlerime git","ekranAc(sirketYonetimEkrani)"));
 if(TC.sekme==="uretim"){
  html+=card("Üretim ve toptan satış","Gıda, teknoloji veya yapı malzemeleri üreten fabrikalarda farklı ürünlerin parti kapasitesi ve üretim süresi vardır. Üretim bedeli emir verildiğinde düşer, ürünler süre sonunda satış stoklarına geçer.");
  html+=hint;
  const arr=own("fabrika");
  for(const s of arr){
   const st=storeStock(s.id);
   html+=card("🏭 "+s.ad,"Faaliyet: "+tm(s.grup)+" · Kasa "+money(s.kasa)+
   " · Stokta "+st.reduce((n,x)=>n+Number(x.adet),0)+" ürün",
   button("Üretim emri ver","tcProduce("+s.id+")"));
   for(const x of st)html+=card((item(x.urun)?.ad||x.urun)+" · "+x.adet+" adet",
   "Birim stok maliyeti "+money(x.maliyet)+" · Toptan satış "+money(x.fiyat),
   secondary("Toptan fiyatı belirle","tcPrice("+s.id+",'"+x.urun+"',"+Number(x.fiyat)+")"));
  }
  html+=title("Üretim süreçleri","son 60 parti");
  for(const x of d.uretim||[])html+=card((item(x.urun)?.ad||x.urun)+" · "+x.adet+" adet",
   "Maliyet "+money(x.maliyet)+" · "+(x.tamam?"Stoklara aktarıldı":"Hazır olacağı zaman "+date(x.hazir)));
  html+=title("Üretilebilen ürünler",""+(d.urunler||[]).length+" çeşit");
  for(const p of d.urunler||[])html+=card(p.ad,
    tm(p.grup)+" · Parti üst sınırı "+p.parti+" · "+p.dakika+" dakika · Birim maliyet "+money(p.maliyet)+
    " · Önerilen tüketici fiyatı "+money(p.satis));
 }
 if(TC.sekme==="magaza"){
  html+=card("Yapay müşteriye satış","Sanal müşteriler her saat şehrin gelişimi, ürün talebi, mağaza kategorisi, rekabet ve raf fiyatına göre alışveriş yapar. Stoklar gerçekten azalır; ciro, maliyet, personel gideri, vergi ve franchise payları rapora yansır.");
  html+=hint;
  const shops=own("magaza");
  for(const s of shops){
   const st=storeStock(s.id);
   const cats={market:"🛒 Market",kahve:"☕ Kahve",fastfood:"🍔 Fast food"};
   html+=card(cats[s.kategori]+" · "+s.ad,
   "Şirket kasası "+money(s.kasa)+" · Sermaye "+money(s.sermaye)+" · "+
   st.reduce((n,x)=>n+Number(x.adet),0)+" adet stok",
   button("Üreticiden ürün al","tcWholesale("+s.id+")")+
   secondary("Mağaza türü","tcType("+s.id+")")+
   secondary("Otomatik tedarik","tcAutomation("+s.id+")"));
   for(const x of st)html+=card((item(x.urun)?.ad||x.urun)+" · "+x.adet+" adet",
     "Alış maliyeti "+money(x.maliyet)+" · Raf fiyatı "+money(x.fiyat),
     secondary("Raf fiyatı değiştir","tcPrice("+s.id+",'"+x.urun+"',"+Number(x.fiyat)+")"));
   for(const x of (d.oto||[]).filter(x=>x.sirket===s.id&&x.aktif))
    html+=card("Otomatik tedarik · "+(item(x.urun)?.ad||x.urun),
    "Stok eşiği "+x.esik+" · Sipariş "+x.miktar+" adet · Son tarih "+date(x.bitis),
    secondary("Otomasyonu kapat","tcDisable("+s.id+",'"+x.urun+"')"));
  }
  html+=title("Oyuncu üreticilerinin stokları","Canlı teklif");
  if(!(d.tedarikciler||[]).length)html+=card("Üretici stoku yok","Üreticiler ürünlerini tamamladıkça listede görünür.");
  for(const x of d.tedarikciler||[])html+=card((item(x.urun)?.ad||x.urun)+" · "+x.ad,
    x.adet+" adet · Toptan "+money(x.fiyat)+" / adet");
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
  TC.veri=await API.rpc("eko_ticaret_panel");
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
window.tcBrand=brandSettings;window.tcBuyBrand=franchiseBuy;
})();