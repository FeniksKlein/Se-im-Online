/* 2026-10-25 Kuyumcu ve Doviz Carsisi: oyun.meslek_* guvenli RPC entegrasyonu */
(function(){
"use strict";
if(window.__meslekOfis2610)return;
window.__meslekOfis2610=true;
const M={data:null,tur:"doviz",yeniliyor:false};
const esc=x=>typeof e==="function"?e(String(x==null?"":x)):String(x==null?"":x).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const tl=x=>Number(x||0).toLocaleString("tr-TR",{minimumFractionDigits:0,maximumFractionDigits:2})+" ₺";
const miktar=x=>Number(x||0).toLocaleString("tr-TR",{maximumFractionDigits:4});
const zaman=x=>x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";
const isim={USD:"Amerikan Doları",EUR:"Avro",GBP:"İngiliz Sterlini",CHF:"İsviçre Frangı",ALTIN:"Gram Altın"};
const label={doviz:"Döviz Bürosu",kuyumcu:"Kuyumcu"};
const error=x=>typeof hataCevir==="function"?hataCevir(x?.message||String(x)):String(x?.message||x);
const btn=(s,fun,secondary)=>'<button type="button" class="btn '+(secondary?"ikinci":"altin")+'" onclick="'+fun+'">'+esc(s)+'</button>';
const line=(k,v)=>'<div class="kv"><span>'+esc(k)+'</span><b>'+esc(v)+'</b></div>';
const card=(title,body)=>'<section class="kart meslek-kart"><h3>'+esc(title)+'</h3>'+body+'</section>';
const get=(id)=>document.getElementById(id);
const dukkan=id=>(M.data?.dukkanlar||[]).find(x=>Number(x.id)===Number(id));
const rate=kod=>(M.data?.kurlar||[]).find(x=>x.kod===kod);
const codes=tur=>tur==="kuyumcu"?["ALTIN"]:["USD","EUR","GBP","CHF"];
const num=id=>Number(get(id)?.value);
function css(){return '<style id="meslek-ui-style">'+
'.meslek-hero{padding:18px;margin-bottom:12px;border:1px solid #9b83ec66;border-radius:18px;background:linear-gradient(125deg,#18284b,#3d3172)}.meslek-hero h2{font-size:26px;color:#fff;margin:5px 0}.meslek-hero .alt{color:#d4c9f4}'+
'.meslek-tabs{display:flex;gap:8px;overflow-x:auto;scrollbar-width:none;margin:12px 0}.meslek-tabs button{white-space:nowrap;flex:1;border-radius:12px;background:var(--panel2);border:1px solid var(--line2);padding:12px 14px;font-weight:700}.meslek-tabs button.active{border-color:#aa91ff;background:#55467b}'+
'.meslek-rate-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:10px 0}.meslek-rate{background:#ffffff0b;border:1px solid var(--line2);border-radius:12px;padding:10px 11px}.meslek-rate small{display:block;color:var(--mut);font-size:11px}.meslek-rate b{font-size:19px;color:var(--txt)}'+
'.meslek-kart{margin:11px 0}.meslek-kart h3{font-size:19px;margin-bottom:8px}.meslek-btns{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px;margin-top:9px}.meslek-btns .btn{width:100%;margin:0}.meslek-item{padding:12px 0;border-bottom:1px solid var(--line)}.meslek-item:last-child{border-bottom:0}'+
'</style>'}
const q=status=>status?'<div class="kucuk">'+esc(status)+'</div>':"";
async function refreshRates(force=false){
 if(M.yeniliyor)return;
 if(!force&&(M.data?.kurlar?.length||0)===5&&M.data.kurlar.every(x=>Date.now()-new Date(x.guncelleme).getTime()<10*60000))return;
 M.yeniliyor=true;
 try{
  if(!API.realtimeClient?.functions?.invoke)throw new Error("Fiyat servisi kullanılamıyor.");
  const r=await API.realtimeClient.functions.invoke("meslek-kurlari",{body:{}});
  if(r.error)throw r.error;
  if(r.data?.ok===false)throw new Error(r.data.hata||"Fiyat verisi alınamadı.");
  M.data=await API.rpc("meslek_panel");
 }catch(err){M._rateError=error(err);}
 finally{M.yeniliyor=false}
}
async function open(which,force=false){
 M.tur=which==="kuyumcu"?"kuyumcu":"doviz";
 yukleniyor("Kuyumcu ve Döviz Çarşısı");
 try{
  M.data=await API.rpc("meslek_panel");
  M._rateError="";
  await refreshRates(force);
  render();
 }catch(ex){
  iskelet("Kuyumcu ve Döviz Çarşısı",card("Bağlantı sorunu",'<p class="alt">'+esc(error(ex))+'</p>'+btn("Tekrar dene","meslekOfisEkrani()")),{geri:true});
 }
}
function render(){
 const d=M.data||{}, now=Date.now(), mine=(d.dukkanlar||[]).filter(x=>x.benim), all=(d.dukkanlar||[]).filter(x=>x.tur===M.tur);
 const tur=M.tur, r=codes(tur), name=label[tur];
 const stale=(d.kurlar||[]).length<5||r.some(k=>!rate(k)||now-new Date(rate(k).guncelleme).getTime()>20*60000);
 let html=css()+'<section class="meslek-hero"><div class="ne">İŞ DÜNYASI · FİNANSAL ÇARŞI</div><h2>Kuyumcu ve Döviz</h2><p class="alt">Kendi dükkânını işlet, oyuncularla gerçek referans kurlara bağlı alışveriş yap. Kazanç, stok ve kasa üzerinden hesaplanır.</p></section>';
 html+='<div class="meslek-tabs"><button class="'+(tur==="doviz"?"active":"")+'" onclick="meslekOfisEkrani(\'doviz\')">Döviz büroları</button><button class="'+(tur==="kuyumcu"?"active":"")+'" onclick="meslekOfisEkrani(\'kuyumcu\')">Kuyumcular</button></div>';
 html+=card("Referans piyasa fiyatları",'<p class="alt">'+(tur==="doviz"?"TCMB günlük gösterge kurlarıdır; serbest piyasada anlık işlem kuru değildir.":"Gram altın, Gold API ons spot fiyatı ve TCMB dolar kuru ile hesaplanır; kuyumcu ürün fiyatları farklı olabilir.")+'</p>'+
  '<div class="meslek-rate-grid">'+r.map(k=>'<div class="meslek-rate"><small>'+esc(isim[k])+'</small><b>'+(rate(k)?tl(rate(k).fiyat):"—")+'</b><small>'+(rate(k)?esc(zaman(rate(k).veri_tarihi)):"Veri bekleniyor")+'</small></div>').join("")+'</div>'+
  (stale?'<p class="alt" role="alert">Güncel referans bağlantısı yok. Yeni fiyat gelene kadar alış-satış işlemleri kapalıdır.</p>':'<p class="alt">Fiyatlar referans amaçlıdır; dükkân fiyatları ve gerçek kurlar farklı olabilir.</p>')+
  (M._rateError?'<p class="alt" role="alert">Kur güncellenemedi: '+esc(M._rateError)+'</p>':'')+
  btn("Piyasa kurlarını yenile","meslekFiyatYenile()",true));
 html+=card("Cüzdanım ve varlıklarım",line("Kullanılabilir cüzdan",tl(d.cuzdan))+
  r.map(k=>line(isim[k]+" bakiyem",miktar(d.portfoy?.[k]||0)+(k==="ALTIN"?" gram":" "+k))).join("")+
  '<p class="alt">Çarşı portföyü, eski sanal yatırım borsasından ayrıdır. Geçmiş yatırım varlıkların korunur.</p>');
 html+=card("Mesleğim ve dükkân yönetimi",mine.filter(x=>x.tur===tur).map(s=>'<div class="meslek-item"><h3>'+esc(s.ad)+'</h3>'+
  line("Şirket kasası",tl(s.kasa))+line("Alış-satış farkı","%"+miktar(s.makas))+
  r.map(k=>line(isim[k]+" stoğu",miktar(s.stok?.[k]||0))).join("")+
  '<div class="meslek-btns">'+btn("Kasaya para yatır","meslekKasaIslem("+Number(s.id)+",'yatir')")+
  btn("Kasadan para çek","meslekKasaIslem("+Number(s.id)+",'cek')",true)+
  btn("Toptan stok al","meslekStokAl("+Number(s.id)+")")+
  btn("Fiyat makasını değiştir","meslekMakas("+Number(s.id)+")",true)+'</div></div>').join("")+
  (mine.some(x=>x.tur===tur)?'':btn("+ Yeni "+name+" aç","meslekDukkanAc('"+tur+"')"))+
  '<p class="alt">Kuruluşta 5.000 ₺ ruhsat bedeli düşer; kalan sermaye dükkân kasasına geçer. İlk stok otomatik gelmez.</p>');
 html+=card(tur==="doviz"?"Döviz büroları":"Kuyumcular",
  (all.length?all.map(s=>'<div class="meslek-item"><b>'+esc(s.ad)+'</b><p class="kucuk">İl kodu: '+(s.il_id||"—")+' · Alış-satış farkı %'+miktar(s.makas)+(s.benim?" · Senin dükkânın":"")+'</p>'+
  r.map(k=>{const p=rate(k)?.fiyat||0;const buy=p*(1+Number(s.makas)/100),sell=p*(1-Number(s.makas)/100);
  return '<div class="kv"><span>'+esc(isim[k])+'<small class="kucuk" style="display:block">Dükkân alışı '+tl(sell)+' / satışı '+tl(buy)+'</small></span><b>'+miktar(s.stok?.[k]||0)+'</b></div>'+
   (s.benim?'':'<div class="meslek-btns">'+btn("Al","meslekAlSat("+Number(s.id)+",'"+k+"','al')")+btn("Sat","meslekAlSat("+Number(s.id)+",'"+k+"','sat')",true)+'</div>');}).join("")+
  '</div>').join(""):'<p class="alt">Bu türde henüz dükkân açılmadı. İlk dükkânı kuran sen olabilirsin.</p>'));
 html+=card("Son ticari işlemler",(d.islemler||[]).slice(0,15).map(x=>'<div class="kv"><span>'+esc(x.kod)+' · '+esc(x.yon==='tedarik'?"Toptan alım":x.yon==='al'?"Müşterinin alımı":"Müşterinin satışı")+'<small class="kucuk" style="display:block">'+esc(zaman(x.tarih))+' · '+miktar(x.miktar)+'</small></span><b>'+tl(x.tutar)+'</b></div>').join("")||'<p class="alt">Henüz kayıtlı işlem yok.</p>');
 iskelet("Kuyumcu ve Döviz Çarşısı",html,{geri:true});
}
async function yenile(){await open(M.tur,true);}
function dlg(title,html,action){
 const m=modal('<h3>'+esc(title)+'</h3>'+html+'<button class="btn altin" id="meslekOnay">İşlemi onayla</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 const b=m.querySelector("#meslekOnay");b.onclick=async()=>{
  if(b.disabled)return;
  b.disabled=true;
  try{
    const r=await action(m);
    if(r===false)return;
    modalKapat();toast("İşlem gerçekleştirildi.");await open(M.tur);
    if(typeof durumYenile==="function")durumYenile().catch(()=>{});
  }catch(ex){toast(error(ex),true)}finally{b.disabled=false}
 };
}
function field(id,name,value,min,step){
 return '<div class="alan"><label>'+esc(name)+'</label><input id="'+id+'" type="number" min="'+min+'" step="'+(step||"1")+'" value="'+value+'" inputmode="decimal"></div>';
}
function kur(t){
 const bas=label[t],m=modal('<h3>'+esc(bas)+' aç</h3><div class="alan"><label>Dükkân adı</label><input id="meslekAd" maxlength="60" placeholder="Örn. Ege Altın ve Döviz"></div>'+field("meslekSermaye","Kuruluş sermayesi (en az 100.000 ₺)",200000,100000)+
 '<p class="alt">5.000 ₺ ruhsat bedeli kuruluş sermayesinden kesilecek. Dükkân sahibi yatırdığı parayı ileride kasadan geri çekebilir.</p><button class="btn altin" id="meslekKurOnay">Dükkân aç</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 m.querySelector("#meslekKurOnay").onclick=async function(){
  const ad=m.querySelector("#meslekAd").value.trim(),ser=Number(m.querySelector("#meslekSermaye").value);
  if(ad.length<3||ad.length>60||!Number.isInteger(ser)||ser<100000||ser>100000000){toast("İsim veya sermaye geçersiz.",true);return;}
  if(typeof onayla==="function"&&!await onayla("Dükkân kuruluşu",tl(ser)+" cüzdanından çıkarılacak, 5.000 ₺ ruhsat bedeli düşecek.","Kur"))return;
  this.disabled=true;
  try{await API.rpc("meslek_dukkan_ac",{p_tur:t,p_ad:ad,p_sermaye:ser});modalKapat();toast("Dükkân açıldı.");await open(t);if(typeof durumYenile==="function")durumYenile().catch(()=>{});}
  catch(ex){toast(error(ex),true);}finally{this.disabled=false}
 };
}
function kasa(id,yon){const s=dukkan(id);if(!s||!s.benim)return;
 dlg(s.ad+" · "+(yon==="yatir"?"Kasaya yatır":"Kasadan çek"),'<p class="alt">Şirket kasası: '+tl(s.kasa)+'</p>'+field("meslekIslemMiktar","Tutar (₺)",10000,100),
 async m=>{const v=Number(m.querySelector("#meslekIslemMiktar").value);if(!Number.isInteger(v)||v<100||v>100000000)throw Error("Geçersiz tutar");
 await API.rpc("meslek_kasa",{p_dukkan:id,p_yon:yon,p_tutar:v});});
}
function stokAl(id){const s=dukkan(id);if(!s||!s.benim)return;
 const opts=codes(s.tur).map(k=>'<option value="'+k+'">'+esc(isim[k])+' · '+(rate(k)?tl(rate(k).fiyat):"Kur alınamadı")+'</option>').join("");
 dlg(s.ad+" · Toptan stok",'<p class="alt">Stok doğrudan dükkân kasasından TCMB/spot referans fiyata yakın bedelle alınır. Tedarik primi yaklaşık %0,1.</p><div class="alan"><label>Ürün</label><select id="meslekKod">'+opts+'</select></div>'+field("meslekMiktar","Miktar",1,0.0001,0.0001),
 async m=>{const k=m.querySelector("#meslekKod").value,v=Number(m.querySelector("#meslekMiktar").value);
 if(!Number.isFinite(v)||v<=0||v>100000||Math.abs(v*10000-Math.round(v*10000))>1e-6)throw Error("Miktar 4 ondalıkla sınırlı.");
 await API.rpc("meslek_stok_tedarik",{p_dukkan:id,p_kod:k,p_miktar:v});});
}
function makas(id){const s=dukkan(id);if(!s||!s.benim)return;
 dlg(s.ad+" · Alış-satış farkı",'<p class="alt">Alım ve satım fiyatı referans kurun iki tarafında simetrik belirlenir. Değişiklik sonraki işlemlere uygulanır.</p>'+
 field("meslekMakas","Fiyat makası (%)",s.makas,s.tur==="doviz"?0.25:0.5,0.05),
 async m=>{let x=Number(m.querySelector("#meslekMakas").value);if(!Number.isFinite(x))throw Error("Geçersiz oran.");
 await API.rpc("meslek_makas_ayarla",{p_dukkan:id,p_makas:x});});
}
function trade(id,k,y){
 const s=dukkan(id),p=rate(k);if(!s||!p||s.benim)return;
 const price=Number(p.fiyat)*(y==="al"?1+Number(s.makas)/100:1-Number(s.makas)/100);
 dlg(s.ad+" · "+isim[k]+" "+(y==="al"?"al":"sat"),
 '<p class="alt">Referans: '+tl(p.fiyat)+' · Tahmini işlem fiyatı: '+tl(price)+' · İşlem, o anki sunucu kuru üzerinden kesinleşir.</p>'+
 line("Dükkân stoku",miktar(s.stok?.[k]||0))+line("Portföyündeki miktar",miktar(M.data.portfoy?.[k]||0))+
 field("meslekTicMiktar",k==="ALTIN"?"Gram miktarı":"Döviz miktarı",1,0.0001,0.0001),
 async m=>{let a=Number(m.querySelector("#meslekTicMiktar").value);
 if(!Number.isFinite(a)||a<=0||a>100000||Math.abs(a*10000-Math.round(a*10000))>1e-6)throw Error("Geçersiz miktar");
 if(typeof onayla==="function"&&!await onayla("Alış-satışı onayla",miktar(a)+" "+k+" için yaklaşık "+tl(a*price)+" tutarında işlem yapılacak.","Onayla"))return false;
 await API.rpc("meslek_ticaret",{p_dukkan:id,p_kod:k,p_yon:y,p_miktar:a});});
}
window.meslekOfisEkrani=open;
window.meslekFiyatYenile=yenile;
window.meslekDukkanAc=kur;
window.meslekKasaIslem=kasa;
window.meslekStokAl=stokAl;
window.meslekMakas=makas;
window.meslekAlSat=trade;
})();