/* Vergi oranları, günlük kâr payı ve Meclis kanun teklifleri. */
(function(){
"use strict";
const VE={panel:null};
const esc=x=>typeof e==="function"?e(String(x??"")):String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const tl=x=>typeof tlYaz==="function"?tlYaz(Math.round(Number(x)||0)):Math.round(Number(x)||0).toLocaleString("tr-TR")+" TL";
const dt=x=>x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";
const btn=(label,call)=>'<button class="btn altin" onclick="'+call+'">'+label+'</button>';
const sec=(label,call)=>'<button class="btn ikinci" onclick="'+call+'">'+label+'</button>';
const card=(head,contents,action="")=>'<section class="kart ve-card"><h3>'+esc(head)+'</h3>'+contents+action+'</section>';
const input=(id,lab,val,placeholder="")=>'<div class="alan"><label>'+esc(lab)+'</label><input id="'+id+'" value="'+esc(val??"")+'" placeholder="'+esc(placeholder)+'"></div>';
const amount=(id,lab,val,min=0,max=100000000)=>'<div class="alan"><label>'+esc(lab)+'</label><input type="number" id="'+id+'" value="'+Number(val||0)+'" min="'+min+'" max="'+max+'" step="1" inputmode="numeric"></div>';
const dropdown=(id,lab,options)=>'<div class="alan"><label>'+esc(lab)+'</label><select id="'+id+'">'+options.map(x=>'<option value="'+esc(x[0])+'">'+esc(x[1])+'</option>').join("")+'</select></div>';
const get=(root,id)=>root.querySelector("#"+id)?.value??"";
function modalForm(title,body,label,submit){
 const root=modal('<h3>'+esc(title)+'</h3>'+body+'<button class="btn altin" id="veSave">'+esc(label)+'</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 const b=root.querySelector("#veSave");b.onclick=async()=>{b.disabled=true;try{await submit(root)}finally{b.disabled=false;}};
 return root;
}
const taxes=()=>VE.panel?.vergiler||[];
const live=x=>taxes().find(t=>t.kod===x);
async function refresh(){await vergiIsletmeEkrani();}
function withdraw(id){
 const s=(VE.panel?.sirketler||[]).find(s=>Number(s.id)===Number(id));
 if(!s)return;
 const lim=Math.floor(Math.max(0,Math.min(Number(s.benim_hak),Number(s.kasa)-Number(s.sermaye))));
 const rates=taxes().filter(t=>t.aktif&&t.matrah==="dagitim").reduce((n,x)=>n+Number(x.oran||0),0);
 modalForm("Günlük kâr payımı çek",
 '<p class="alt">'+esc(s.ad)+' · Şirket sermayesi '+tl(s.sermaye)+
 ' · Tamamlanmış günlerdeki kendi hak edişin '+tl(s.benim_hak)+
 ' · Tahmini nakit çekim sınırın '+tl(lim)+'. Vergi ve borç rezervi sunucuda ayrıca kontrol edilir.</p>'+
 amount("veMoney","Brüt çekilecek kâr payı (en az 100 TL)",Math.max(100,lim),100,100000000)+
 '<p class="alt">Tahmini toplam kâr payı vergisi %'+rates.toLocaleString("tr-TR")+
 '. Kesinti Hazinenin hesabına gider; net tutar şahsi cüzdanına aktarılır.</p>',
 "Kâr payımı çek",async m=>{
  const sum=Number(get(m,"veMoney"));
  if(!Number.isSafeInteger(sum)||sum<100){toast("Çekim en az 100 TL ve tam sayı olmalı.",true);return;}
  if(!await onayla("Kâr payı dağıtımı",
    "Brüt "+tl(sum)+" tutarındaki kâr payın, yürürlükteki stopaj ve diğer dağıtım vergileri düşülerek şahsi cüzdanına aktarılacak.","Çek"))return;
  try{
   const x=await API.rpc("eko_gunluk_kar_cek",{p_sirket:id,p_tutar:sum});
   modalKapat();
   toast("Net "+tl(x.net)+" cüzdanına aktarıldı. Vergi kesintisi "+tl(x.stopaj)+".");
   if(typeof durumYenile==="function")durumYenile().catch(()=>{});
   await refresh();
  }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):err.message,true);}
 });
}
function offerTax(){
 const types=taxes();
 const m=modalForm("Vergi kanunu teklifi",
 '<p class="alt">Yalnızca milletvekilleri kanun önerebilir. Teklif Meclis görüşmesi, oylama ve yürürlüğe giriş aşamalarından geçmeden vergi değişmez.</p>'+
 dropdown("veAction","Teklif işlemi",[["oran","Mevcut verginin oranını değiştir"],["kaldir","Mevcut vergiyi kaldır"],["yeni","Yeni vergi oluştur"]])+
 dropdown("veCode","Mevcut vergi",types.map(t=>[t.kod,t.ad+" · %"+t.oran]))+
 '<div id="veNewTax">'+input("veNewCode","Yeni vergi kodu","","ornek_vergi")+
 input("veNewName","Yeni vergi adı","","Örneğin Çevre Vergisi")+
 dropdown("veBase","Vergi matrahı",[["satis","Satış/ciro"],["kar","Şirket kârı"],["dagitim","Ortak kâr payı"],["sozlesme","Sözleşme bedeli"],["genel_gelir","Genel gelir"]])+'</div>'+
 amount("veRate","Yeni vergi oranı (%)",20,0,50)+
 input("veTitle","Kanun teklifi başlığı","","Örneğin Kurumlar Vergisi Düzenlemesi")+
 '<div class="alan"><label>Kanun gerekçesi</label><textarea id="veReason" maxlength="3000" rows="4" placeholder="Gerekçeyi en az 10 karakterle yaz"></textarea></div>'+
 '<p class="alt" id="veNote"></p>',
 "Meclise teklif gönder",async root=>{
  const op=get(root,"veAction"),code=op==="yeni"?get(root,"veNewCode").trim():get(root,"veCode"),
    rate=op==="kaldir"?0:Number(get(root,"veRate"));
  if(op!=="kaldir"&&(!Number.isFinite(rate)||rate<0||rate>50)){toast("Oran %0-%50 arasında olmalı.",true);return;}
  const title=get(root,"veTitle").trim(),reason=get(root,"veReason").trim();
  if(title.length<5||reason.length<10){toast("Kanun başlığı veya gerekçesi çok kısa.",true);return;}
  if(!await onayla("Vergi kanun teklifi",title+" başlıklı teklif Meclisin değerlendirmesine sunulsun mu?","Teklif et"))return;
  try{
   const ret=await API.rpc("eko_vergi_kanun_teklif",{
    p_kod:code,p_islem:op,p_oran:rate,
    p_ad:op==="yeni"?get(root,"veNewName").trim():live(code)?.ad||"Vergi",
    p_matrah:op==="yeni"?get(root,"veBase"):live(code)?.matrah||"kar",
    p_baslik:title,p_metin:reason
   });
   modalKapat();toast("Kanun teklifi Meclise sunuldu (#"+ret.id+").");
   await refresh();
  }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):err.message,true);}
 });
 const update=()=>{
  const isNew=get(m,"veAction")==="yeni",isOff=get(m,"veAction")==="kaldir";
  m.querySelector("#veNewTax").style.display=isNew?"":"none";
  m.querySelector("#veCode").closest(".alan").style.display=isNew?"none":"";
  m.querySelector("#veRate").closest(".alan").style.display=isOff?"none":"";
  m.querySelector("#veNote").textContent=isOff?
   "Vergi kaldırılırsa geçmişte tahsil edilen tutarlar değişmez; yalnızca yeni işlemler etkilenir.":
   "Yeni oran kanun yürürlüğe girdiğinde uygulanır; geçmiş şirket gelirleri yeniden hesaplanmaz.";
 };
 m.querySelector("#veAction").onchange=update;update();
}
async function vergiIsletmeEkrani(){
 yukleniyor("Vergiler ve Kâr Payı");
 try{
  VE.panel=await API.rpc("eko_vergi_panel");
  const d=VE.panel,types=d.vergiler||[],cs=d.sirketler||[];
  const style='<style>.ve-head{border-radius:17px;padding:19px;background:linear-gradient(125deg,#263957,#493471);color:#fff;margin-bottom:12px}.ve-head h2{color:#fff;margin:0 0 7px;font-size:25px}.ve-head p{font-size:12px;color:#d6dbef;margin:0}.ve-card{margin:0 0 10px}.ve-card h3{margin:0 0 7px}.ve-card .btn{margin:7px 7px 0 0}.ve-tax{display:flex;gap:8px;align-items:center;justify-content:space-between}.ve-tax span{font-size:12px}.ve-tax b{font-size:18px}.ve-facts{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin:9px 0}.ve-facts>span{padding:10px;border:1px solid var(--line2);border-radius:10px;color:var(--txt);font-size:12px}.ve-facts b{display:block;margin-top:5px;font-size:17px}</style>';
  let html=style+'<div class="ve-head"><h2>🏛️ Vergiler ve Kâr Payı</h2><p>Şirketin günlük faaliyet kârı, ortak hak edişi, Hazine vergileri ve Meclis yasaları</p></div>';
  html+='<div class="bolum-bas"><h2>Vergi oranları</h2><span class="kucuk">Yürürlükteki oyun kanunları</span></div>';
  for(const x of types)html+=card(x.ad,
    '<div class="ve-tax"><span>Matrah: '+esc(({satis:"Satış/ciro",kar:"Kâr",dagitim:"Ortak dağıtımı",sozlesme:"Sözleşme",genel_gelir:"Genel gelir"})[x.matrah]||x.matrah)+
    '<br><span class="kucuk">'+(x.aktif?"Yürürlükte":"Kaldırıldı")+'</span></span><b>'+(
    x.aktif?"%"+Number(x.oran).toLocaleString("tr-TR"):"—")+'</b></div>');
  html+='<div class="bolum-bas"><h2>Şirketlerimde günlük kâr</h2></div>';
  if(!cs.length)html+=card("Aktif ticaret işletmen yok",'<p class="alt">Şirketlerim bölümünden şirket kurup üretim veya mağaza olarak faaliyete bağlayabilirsin.</p>');
  for(const x of cs){
   const payable=Math.floor(Math.max(0,Math.min(Number(x.benim_hak),Number(x.kasa)-Number(x.sermaye))));
   html+=card(x.ad,
    '<div class="ve-facts"><span>Şahsi hissem<b>%'+Number(x.payim).toLocaleString("tr-TR")+'</b></span>'+
    '<span>Şirket kasası<b>'+tl(x.kasa)+'</b></span>'+
    '<span>Bugünkü ciro<b>'+tl(x.bugun_ciro)+'</b></span>'+
    '<span>Bugünkü net kâr<b>'+tl(x.bugun_kar)+'</b></span>'+
    '<span>Önceki günlerden hak ettiğim<b>'+tl(x.benim_hak)+'</b></span>'+
    '<span>Tahmini çekilebilir<b>'+tl(payable)+'</b></span></div>'+
    '<p class="alt">Son 7 günde şirkete yazılan vergiler: '+tl(x.son7_vergi)+
    '. Bugünkü kâr gece yarısından sonra hak ediş hesabına dahil olur.</p>',
    btn("Şahsi cüzdanıma kâr çek","veWithdraw("+x.id+")"));
  }
  html+='<div class="bolum-bas"><h2>Meclis ve yeni vergi kanunları</h2></div>';
  html+=card("Vergi kanunu teklif et",'<p class="alt">KDV, kurumlar vergisi, kâr payı stopajı, gelir vergisi, damga vergisi ve yeni vergi türleri. Kanun yalnızca Meclis süreci tamamlandıktan sonra işler.</p>',
   btn("Kanun teklifi hazırla","veTaxLaw()"));
  for(const x of (d.meclis_teklifleri||[]))html+=card(x.baslik,
    '<p class="alt">'+esc(x.kod)+" · "+esc(x.islem)+" · Durum: "+esc(x.durum)+'</p>',
    sec("Kanunu görüntüle","veLawDetail("+Number(x.id)+")"));
  html+='<div class="bolum-bas"><h2>Son şahsi kâr ödemelerim</h2></div>';
  if(!(d.odemeler||[]).length)html+=card("Henüz şahsi kâr çekimi yok",'<p class="alt">İlk günlük kârın kesinleşince buradan çekebilirsin.</p>');
  for(const x of d.odemeler||[])html+=card(x.sirket+" · "+dt(x.zaman),
   '<p class="alt">Brüt '+tl(x.brut)+" · Stopaj ve diğer vergiler "+tl(x.stopaj)+
   " · Cüzdana geçen net <b>"+tl(x.net)+'</b></p>');
  iskelet("Vergiler ve Kâr Payı",html,{geri:true});
 }catch(err){iskelet("Vergiler ve Kâr Payı",card("Bağlantı sorunu",
  '<p class="alt">'+esc(typeof hataCevir==="function"?hataCevir(err.message):err.message)+'</p>'),{geri:true});}
}
window.vergiIsletmeEkrani=vergiIsletmeEkrani;
window.veWithdraw=withdraw;window.veTaxLaw=offerTax;
window.veLawDetail=id=>{
 if(typeof kanunDetayEkrani==="function")kanunDetayEkrani(id);
 else if(typeof kanunDetay==="function")kanunDetay(id);
 else {toast("Kanun #"+id+" Meclis kanunlar listesinde.",false);}
};
if(typeof window.iskelet==="function"){
 const former=window.iskelet;
 window.iskelet=iskelet=function(baslik,govde,opts){
  const result=former.apply(this,arguments);
  if(baslik==="Şirketlerim"){
   const root=document.querySelector("#icerik .kart");
   if(root&&!document.querySelector(".ve-entry"))root.insertAdjacentHTML("beforeend",
    '<button class="btn altin ve-entry" onclick="vergiIsletmeEkrani()">🏛️ Vergiler ve Günlük Kâr Payı</button>');
  }
  if(baslik==="Meclis"){
   const root=document.querySelector("#icerik");
   if(root&&!root.querySelector(".ve-entry"))root.insertAdjacentHTML("afterbegin",
    '<div class="kart ve-entry" style="margin-bottom:12px"><h3>🏛️ Şirket vergileri kanunları</h3><p class="alt">KDV, kurumlar, stopaj, gelir, damga ve yeni vergiler için kanun teklifi oluştur.</p>'+
    '<button class="btn altin" onclick="vergiIsletmeEkrani()">Vergi kanunları ve teklif ekranı</button></div>');
  }
  return result;
 };
}
})();