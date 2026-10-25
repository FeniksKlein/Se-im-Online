/* 2026-10-25: Oyuncu islemleri ve stok kontrollu kuyumcu/doviz burosu merkezi. */
(function(){
"use strict";
if(window.MESLEK_OFIS_MODUL)return;
window.MESLEK_OFIS_MODUL=true;
var page="pazar",data=null,busy=false;
var h=function(s){return typeof e==="function"?e(String(s==null?"":s)):String(s==null?"":s).replace(/[&<>"']/g,function(x){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[x];});};
var n=function(x){return Number(x)||0;};
var money=function(x){return n(x).toLocaleString("tr-TR",{minimumFractionDigits:2,maximumFractionDigits:2})+" ₺";};
var amt=function(x){return n(x).toLocaleString("tr-TR",{maximumFractionDigits:4});};
var dt=function(x){return x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";};
var names={USD:"ABD doları",EUR:"Avro",GBP:"İngiliz sterlini",CHF:"İsviçre frangı",ALTIN:"Gram altın"};
function btn(t,fn,cl){return '<button type="button" class="btn '+(cl||"ikinci")+'" onclick="'+fn+'">'+h(t)+'</button>';}
function card(title,body){return '<section class="kart" style="margin-bottom:12px"><h2>'+h(title)+'</h2>'+body+'</section>';}
function row(k,v){return '<div class="kv"><span>'+h(k)+'</span><b>'+h(v)+'</b></div>';}
function fail(err){toast(typeof hataCevir==="function"?hataCevir(err.message||String(err)):String(err.message||err),true);}
function allowed(d,k){return (d.tur==="doviz"&&k!=="ALTIN")||(d.tur==="kuyumcu"&&k==="ALTIN");}
function getK(k){return (data.kurlar||[]).find(function(x){return x.kod===k;});}
function fresh(k){return k && Date.now()-new Date(k.guncelleme).getTime()<20*60*1000;}
function isMyShop(d){return d.benim===true;}
function tabs(){
var all=[["pazar","Piyasa ve dükkânlar"],["dukkan","Dükkânım"],["portfoy","Varlıklarım"]];
return '<div class="segment" style="display:flex;overflow-x:auto;gap:6px;margin:12px 0">'+all.map(function(t){return '<button type="button" class="'+(page===t[0]?"aktif":"")+'" onclick="meslekOfisEkrani(\''+t[0]+'\')">'+h(t[1])+'</button>';}).join("")+'</div>';
}
function quote(d,k,yon){
var price=n(k.fiyat)*(yon==="al"?1+n(d.makas)/100:1-n(d.makas)/100);
price*=yon==="al"?1+n(d.komisyon)/100:1-n(d.komisyon)/100;
return price;
}
function priceTable(){
var k=data.kurlar||[];
return card("Referans piyasa fiyatları",'<p class="alt">Döviz: TCMB son günlük gösterge kuru. Altın: Gold-API ons fiyatı × TCMB USD/TL / 31,1034768. Spot referanstır, gerçek kuyumcu perakende fiyatı değildir.</p>'+
(k.length?k.map(function(x){return row(names[x.kod]||x.kod,money(x.fiyat));}).join(""):'<p class="alt">Fiyatlar henüz sisteme yüklenmedi.</p>')+
'<p class="kucuk">Döviz bülteni: '+h(dt((k.find(function(x){return x.kod==="USD";})||{}).veri_tarihi))+' · Sisteme alma: '+h(dt(k[0]&&k[0].guncelleme))+' · Fiyat kaynağı ekranda belirtilir. Güncel veri yoksa ticaret durur.</p>'+
btn("Kurları güncelle","meslekKurYenile()","altin"));
}
function marketplace(){
var ds=(data.dukkanlar||[]).filter(function(d){return !d.benim;});
var out=priceTable();
out+=card("Oyuncu dükkânları",'<p class="alt">Müşteri olarak kuyumcu ve döviz bürolarını karşılaştır. Satışları dükkânın gerçek stokuyla, alımları gerçek kasasıyla sınırlıdır.</p>'+
(ds.length?ds.map(function(d){
 var ks=(data.kurlar||[]).filter(function(k){return allowed(d,k.kod);});
 return '<div style="border-top:1px solid var(--line);padding:12px 0">'+
 '<b>'+h(d.tur==="kuyumcu"?"Kuyumcu · ":"Döviz bürosu · ")+h(d.ad)+'</b>'+
 '<div class="kucuk">Alış-satış makası ±%'+h(d.makas)+' · Komisyon %'+h(d.komisyon)+' · İl kodu '+h(d.il_id||"—")+'</div>'+
 ks.map(function(k){var avail=n((d.stok||{})[k.kod]);return '<div class="kv"><span>'+h(names[k.kod])+'<span class="kucuk" style="display:block">Stok: '+h(amt(avail))+'</span></span>'+
 '<span style="text-align:right"><b>'+money(quote(d,k,"sat"))+' alış</b><span class="kucuk" style="display:block">'+money(quote(d,k,"al"))+' satış</span></span></div>'+
 '<div class="satir">'+btn("Satın al","meslekTicaretModal("+d.id+",\'"+k.kod+"\',\'al\')","altin")+
 btn("Sat","meslekTicaretModal("+d.id+",\'"+k.kod+"\',\'sat\')")+'</div>';}).join("")+'</div>';
 }).join(""):'<p class="alt">Henüz dükkân açılmadı. İlk açan sen olabilirsin.</p>'));
return out;
}
function management(){
var list=(data.dukkanlar||[]).filter(isMyShop);
var body='<p class="alt">İşletmeni kendi paranla aç; gerçek kurdan toptan stok tedarik et. Müşterilerle yapılan işlemler ve kasa hareketleri sunucuda kayıtlıdır.</p>';
body+=list.map(function(d){
 var codes=d.tur==="kuyumcu"?["ALTIN"]:["USD","EUR","GBP","CHF"];
 var content=row("Kasa",money(d.kasa))+row("Alış-satış makası (tek yön)", "%"+n(d.makas).toLocaleString("tr-TR"))+row("İşlem komisyonu", "%"+n(d.komisyon).toLocaleString("tr-TR"));
 content+='<div class="satir">'+btn("Kasaya para yatır","meslekKasaModal("+d.id+",\'yatir\')","altin")+
 btn("Kasadan para çek","meslekKasaModal("+d.id+",\'cek\')")+
 btn("Makas ayarla","meslekMakasModal("+d.id+")")+
 btn("Komisyon ayarla","meslekKomisyonModal("+d.id+")")+'</div>';
 content+=codes.map(function(k){var cur=getK(k);return '<div class="kv"><span>'+h(names[k])+'</span><b>'+amt((d.stok||{})[k])+'</b></div>'+
 btn("Stok tedarik et · "+k,"meslekTedarikModal("+d.id+",\'"+k+"\')");}).join("");
 return card((d.tur==="kuyumcu"?"Kuyumcum: ":"Döviz bürom: ")+d.ad,content);
 }).join("");
 for(var type of ["doviz","kuyumcu"]){if(!list.some(function(d){return d.tur===type;})){
  body+=card(type==="kuyumcu"?"Kuyumcu aç":"Döviz bürosu aç",
   '<p class="alt">Asgari sermaye 100.000 ₺ · açılış ruhsatı 5.000 ₺. Kalan sermaye dükkân kasasına geçer. Bu ilk sürümde kuyumcuda gram altın ticareti yapılır.</p>'+
   btn("Yeni dükkân aç","meslekDukkanAcModal(\'"+type+"\')","altin"));
 }}
 return body;
}
function portfolio(){
 var pf=data.portfoy||{};
 return card("Altın ve döviz birikimlerim",'<p class="alt">Bunlar kuyumcu/döviz ofisinden alınan yeni varlıklardır. Önceki sanal borsa yatırımların olduğu gibi korunmuştur.</p>'+
 ["USD","EUR","GBP","CHF","ALTIN"].map(function(k){var q=getK(k);return row(names[k]+" · "+amt(pf[k])+" birim",q?money(n(q.fiyat)*n(pf[k])):"—");}).join(""))+
 card("Son işlemler",((data.islemler||[]).length?(data.islemler||[]).map(function(x){return '<div class="kv"><span>'+h(x.kod)+' · '+h(x.yon)+'<span class="kucuk" style="display:block">'+h(dt(x.tarih))+'</span></span><b>'+money(x.tutar)+'</b></div>';}).join(""):'<p class="alt">Henüz alış-satış işlemin yok.</p>'));
}
async function render(tab){
 if(tab)page=["pazar","dukkan","portfoy"].includes(tab)?tab:"pazar";
 yukleniyor("Kuyumcu ve Döviz Çarşısı");
 try{
  data=await API.rpc("meslek_panel");
  var html='<section class="sahne"><div class="ne">EKONOMİ · MESLEKLER</div><h2 style="font-size:25px;margin:8px 0">Kuyumcu ve Döviz Çarşısı</h2><p class="alt">Gerçek referans kurlar, gerçek stok ve gerçek oyuncu işlemleri.</p></section>'+tabs();
  html+=page==="pazar"?marketplace():page==="dukkan"?management():portfolio();
  iskelet("Kuyumcu ve Döviz Çarşısı",html,{geri:true});
  // Ekran acilinca eski/eksik kurlari oturum sahibinin yetkisiyle sunucuda yenile.
  // Arka arkaya gelen talepler Edge Function onbellegine takilir.
  if(!busy&&((data.kurlar||[]).length<5||(data.kurlar||[]).some(function(k){return !fresh(k);}))){
   Promise.resolve().then(function(){if(!busy)window.meslekKurYenile();});
  }
 }catch(err){iskelet("Kuyumcu ve Döviz Çarşısı",card("Erişim hatası",'<p>'+h(err.message||err)+'</p>'+btn("Tekrar dene","meslekOfisEkrani()")),{geri:true});}
}
window.meslekOfisEkrani=render;
async function run(fn,args,onDone){
 if(busy)return;
 busy=true;
 try{var response=await API.rpc(fn,args||{});toast("İşlem tamamlandı.");if(typeof durumYenile==="function")durumYenile().catch(function(){});modalKapat();await render(page);if(onDone)onDone(response);}
 catch(err){fail(err);}finally{busy=false;}
}
function dialog(title,info,fields,commit){
 var m=modal('<h3>'+h(title)+'</h3><p class="alt">'+h(info)+'</p>'+fields+
 '<button class="btn altin" id="mzSubmit">İşlemi onayla</button>'+btn("Vazgeç","modalKapat()"));
 var b=m.querySelector("#mzSubmit");b.onclick=async function(){if(b.disabled)return;b.disabled=true;
 try{await commit(m);}finally{b.disabled=false;}};return m;
}
function numberField(id,label,value,step){return '<div class="alan"><label>'+h(label)+'</label><input id="'+id+'" type="number" min="0" step="'+(step||"1")+'" value="'+h(value)+'" inputmode="decimal"></div>';}
window.meslekDukkanAcModal=function(tur){
 dialog(tur==="kuyumcu"?"Kuyumcu aç":"Döviz bürosu aç","Kuruluş bedeli sermayeden 5.000 ₺ kesilir. Asgari sermaye 100.000 ₺.",
 '<div class="alan"><label>Dükkân adı</label><input id="mzName" type="text" maxlength="60" placeholder="Örnek: Feniks Döviz"></div>'+
 numberField("mzCapital","Kuruluş sermayesi (TL)",100000,1000),async function(el){
 var ad=el.querySelector("#mzName").value.trim(),v=Number(el.querySelector("#mzCapital").value);
 if(ad.length<3||!Number.isSafeInteger(v)||v<100000||v>100000000)return toast("Dükkân adı veya sermayesi geçersiz.",true);
 if(!await onayla("Dükkânı aç",money(v)+" şahsi cüzdanından tahsil edilecek; 5.000 ₺ ruhsat gideridir.","Aç"))return;
 await run("meslek_dukkan_ac",{p_tur:tur,p_ad:ad,p_sermaye:v});
 });
};
window.meslekMakasModal=function(id){
 var d=(data.dukkanlar||[]).find(function(x){return x.id===id&&x.benim;});if(!d)return;
 dialog("Alış-satış makası","Oran her iki yöne ayrı uygulanır. Döviz %0,25–3, kuyumcu %0,5–6.",numberField("mzSpread","Tek yön makas (%)",d.makas,0.05),async function(el){
 await run("meslek_makas_ayarla",{p_dukkan:id,p_makas:Number(el.querySelector("#mzSpread").value)});
 });
};
window.meslekKomisyonModal=function(id){
 var d=(data.dukkanlar||[]).find(function(x){return x.id===id&&x.benim;});if(!d)return;
 dialog("İşlem komisyonunu ayarla","Müşteri işlemlerinin tutarına eklenen veya tutardan kesilen komisyon. Sınır %0–2.",numberField("mzFee","İşlem komisyonu (%)",d.komisyon,0.05),async function(el){
  await run("meslek_komisyon_ayarla",{p_dukkan:id,p_oran:Number(el.querySelector("#mzFee").value)});
 });
};
window.meslekKasaModal=function(id,yon){
 var d=(data.dukkanlar||[]).find(function(x){return x.id===id&&x.benim;});if(!d)return;
 dialog(yon==="yatir"?"Dükkâna sermaye yatır":"Kasadan para çek","Şahsi cüzdanın ve dükkân kasan ayrı tutulur.",numberField("mzCash","Tutar (TL)",10000,100),async function(el){
 var v=Number(el.querySelector("#mzCash").value);if(!Number.isSafeInteger(v)||v<100||v>100000000)return toast("Geçersiz tutar.",true);
 await run("meslek_kasa",{p_dukkan:id,p_yon:yon,p_tutar:v});
 });
};
window.meslekTedarikModal=function(id,kod){
 var d=(data.dukkanlar||[]).find(function(x){return x.id===id&&x.benim;}),k=getK(kod);if(!d||!k)return toast("Önce piyasa kurunu güncelle.",true);
 dialog("Toptan "+names[kod]+" tedariki","Toptan maliyet: referans fiyat + %0,1. Para dükkân kasasından çıkar, stok dükkâna girer.",numberField("mzQty","Miktar",kod==="ALTIN"?1:100,0.0001),async function(el){
 var q=Number(el.querySelector("#mzQty").value);if(!Number.isFinite(q)||q<=0||q>100000||Math.abs(q*10000-Math.round(q*10000))>0.0001)return toast("Geçersiz miktar.",true);
 if(!fresh(k))return toast("Piyasa kuru eski. Önce yenile.",true);
 var total=Math.ceil(q*n(k.fiyat)*1.001);
 if(!await onayla("Toptan stok al",amt(q)+" "+kod+" için yaklaşık "+money(total)+" dükkân kasasından düşecek.","Tedarik et"))return;
 await run("meslek_stok_tedarik",{p_dukkan:id,p_kod:kod,p_miktar:q});
 });
};
window.meslekTicaretModal=function(id,kod,yon){
 var d=(data.dukkanlar||[]).find(function(x){return x.id===id;}),k=getK(kod);if(!d||!k||d.benim)return;
 var p=quote(d,k,yon),status=fresh(k)?"":"Kur bilgisi eski; önce Kurları güncelle.";
 dialog((yon==="al"?"Satın al: ":"Sat: ")+names[kod],"Dükkân: "+d.ad+" · birim fiyat "+money(p)+" · "+status,numberField("mzQty","Miktar ("+kod+")",kod==="ALTIN"?1:100,0.0001),async function(el){
 var q=Number(el.querySelector("#mzQty").value);if(!Number.isFinite(q)||q<=0||q>100000||Math.abs(q*10000-Math.round(q*10000))>0.0001)return toast("Geçersiz miktar.",true);
 if(!fresh(k))return toast("Kur süresi dolmuş; önce yenile.",true);
 var total=yon==="al"?Math.ceil(p*q):Math.floor(p*q);
 if(total<100)return toast("En az 100 ₺ işlem yapılır.",true);
 if(!await onayla("Alış-satışı onayla",amt(q)+" "+kod+" · Tahmini toplam "+money(total)+". Kesin fiyat sunucuda hesaplanır.","İşlemi gerçekleştir"))return;
 await run("meslek_ticaret",{p_dukkan:id,p_kod:kod,p_yon:yon,p_miktar:q});
 });
};
window.meslekKurYenile=async function(){
 if(busy)return;busy=true;try{
  var sess=await API.realtimeClient.auth.getSession(),token=sess.data&&sess.data.session&&sess.data.session.access_token;
  if(!token)throw new Error("Kur yenilemek için oturum aç.");
  var res=await fetch(AYAR.SUPABASE_URL+"/functions/v1/meslek-kur-yenile",{
   method:"POST",headers:{"content-type":"application/json",Authorization:"Bearer "+token,apikey:AYAR.SUPABASE_ANON},body:"{}"});
  var obj=await res.json();if(!res.ok||!obj.ok)throw new Error(obj.error||"Kur yenileme hatası");
  toast(obj.cached?"Kurlar güncel.":"Piyasa kurları yenilendi.");
  await render(page);
 }catch(err){fail(err);}finally{busy=false;}
};
})();