/* 2026-10-14 | Tarim, kitap/yayinevi ve biletli etkinlik arayuzleri */
(function(){
"use strict";
// Kitap yazma kutulari: koyu temada okunurluk ve mobilde tam genislik.
(function(){const st=document.createElement("style");st.textContent=`
#ucSummary,#ucContent{display:block!important;box-sizing:border-box!important;width:100%!important;max-width:100%!important;min-width:0!important;background:var(--panel2,#111831)!important;color:var(--txt,#f5f6ff)!important;-webkit-text-fill-color:var(--txt,#f5f6ff)!important;border:1px solid var(--line2,#3c496e)!important;border-radius:12px!important;padding:12px 14px!important;font-size:16px!important;line-height:1.5!important;opacity:1!important;resize:vertical}
#ucSummary{min-height:115px!important}#ucContent{min-height:220px!important}
#ucSummary::placeholder,#ucContent::placeholder{color:var(--muted,#98a4bf)!important}
`;document.head.appendChild(st)})();
const E= s=>typeof e==="function"?e(String(s??"")):String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const TL=n=>Math.round(Number(n)||0).toLocaleString("tr-TR")+" ₺";
const DT=x=>x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";
const NAME={uc_bugday:"🌾 Buğday",uc_sebze:"🥬 Sebze",uc_sut:"🥛 Süt",uc_et:"🥩 Et"};
let tab="tarim",cache=null,busy=false,medyaOdak=0;
const btn=(label,act,alt=false)=>'<button class="btn '+(alt?'ikinci':'altin')+'" onclick="'+act+'">'+E(label)+'</button>';
const card=(head,desc,actions="")=>'<div class="kart" style="margin-bottom:10px;padding:15px"><h3 style="margin-bottom:7px">'+E(head)+'</h3><p class="alt">'+desc+'</p>'+actions+'</div>';
const opts=arr=>arr.map(x=>'<option value="'+E(x[0])+'">'+E(x[1])+'</option>').join("");
const field=(id,label,value,type="text",min=null,max=null)=>'<div class="alan"><label>'+E(label)+'</label><input id="'+id+'" type="'+type+'" value="'+E(value??"")+'"'+(min!==null?' min="'+min+'"':'')+(max!==null?' max="'+max+'"':'')+'></div>';
const select=(id,label,items)=>'<div class="alan"><label>'+E(label)+'</label><select id="'+id+'">'+opts(items)+'</select></div>';
const area=(id,label,value="",rows=4)=>'<div class="alan"><label>'+E(label)+'</label><textarea id="'+id+'" rows="'+rows+'">'+E(value)+'</textarea></div>';
const val=(el,id)=>el.querySelector("#"+id)?.value??"";
const note=msg=>'<p class="alt">'+E(msg)+'</p>';
const companyButton=btn("🏢 Şirketlerime git","ekranAc(sirketYonetimEkrani)",true);
function dialog(title,content,label,action){
 const m=modal("<h3>"+E(title)+"</h3>"+content+'<button class="btn altin" id="ucSubmit">'+E(label)+'</button>'+btn("Vazgeç","modalKapat()",true));
 const b=m.querySelector("#ucSubmit");
 b.onclick=async()=>{
   if(b.disabled)return;b.disabled=true;
   try{const ok=await action(m);if(ok!==false){modalKapat();toast("İşlem tamamlandı.");if(typeof durumYenile==="function")durumYenile().catch(()=>{});await open(tab);}}
   catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);}
   finally{b.disabled=false;}
 };
 return m;
}
async function command(func,args){return API.rpc(func,args)}
const farmCo=()=>cache?.sirketler||[];
const pressCo=()=>cache?.yayinevleri||[];
const eventCo=()=>cache?.sirketler||[];
async function open(which){
 tab=["tarim","kitap","etkinlik","medya"].includes(which)?which:"tarim";
 yukleniyor("Yeni ekonomi");
 try{
  cache=await API.rpc({tarim:"uc_tarim_panel",kitap:"uc_kitap_panel",etkinlik:"uc_etkinlik_panel",medya:"uc_medya_panel"}[tab]);
  const tabs=[["tarim","🌾 Tarım ve çiftlik"],["kitap","📚 Kitap ve yayınevi"],["etkinlik","🎟️ Etkinlikler"],["medya","🏢 Medya ve yayınevleri"]];
  const head='<section class="sahne"><div class="ne">İŞ DÜNYASI · YENİ FAALİYETLER</div><h2 style="font-size:25px;margin:9px 0">Üret, yayımla, organize et</h2><p class="alt">Her işlem mevcut şirketin ve oyuncunun gerçek oyun bakiyesine bağlıdır. Satışlar ve giderler kalıcıdır.</p></section>'+
   '<div class="segment" style="overflow-x:auto;margin:14px 0">'+tabs.map(x=>'<button class="'+(tab===x[0]?'aktif':'')+'" onclick="ucEkonomiEkrani(\''+x[0]+'\')">'+x[1]+'</button>').join("")+'</div>';
  const body=tab==="tarim"?renderFarm():tab==="kitap"?renderBooks():tab==="medya"?renderMedia():renderEvents();
  iskelet("Yeni Ekonomi",head+body);
 }catch(err){iskelet("Yeni Ekonomi",card("Bağlantı hatası",E(err.message||String(err)),btn("Tekrar dene","ucEkonomiEkrani('"+tab+"')")));toast(err.message||String(err),true);}
}
window.ucEkonomiEkrani=open;
function farmDialog(action,sirket,meta){
 const st=farmCo().find(x=>Number(x.id)===Number(sirket));
 if(!st)return toast("Tarım şirketini seç.",true);
 if(action==="hasat")return actFarm("hasat",sirket,1,null,meta);
 if(action==="sut")return actFarm("sut",sirket,1);
 let content=note("Şirket: "+st.ad+" · Kasası: "+TL(st.kasa));
 if(action==="tarla_al")content+=field("ucQty","Alınacak tarla (30.000 ₺ / adet)",1,"number",1,10);
 if(action==="hayvan_al")content+=field("ucQty","Hayvan satın al (12.000 ₺ / adet)",1,"number",1,20);
 if(action==="kesim")content+=field("ucQty","Kesime gönderilecek hayvan (et stoğuna aktarılır)",1,"number",1,20);
 if(action==="ek")content+=select("ucUrun","Ekim ürünü",[["uc_bugday","🌾 Buğday (24 saat)"],["uc_sebze","🥬 Sebze (18 saat)"]])+
 field("ucQty","Ekim yapılacak tarla",1,"number",1,10)+note("Tohum ve işçilik masrafı şirketten kesilir. Mevsim ve kuraklık hasat miktarını etkiler.");
 dialog({tarla_al:"Tarla satın al",hayvan_al:"Hayvan satın al",kesim:"Et üretimi",ek:"Yeni ekim"}[action],
  content,"İşlemi onayla",async el=>{
   const qty=Number(val(el,"ucQty"));if(!Number.isInteger(qty)||qty<1)return toast("Geçerli miktar seç.",true),false;
   if(typeof onayla==="function" && !await onayla("Şirket harcaması",st.ad+" adına bu işlem için şirket kasandan gider oluşabilir. Onaylıyor musun?","Onayla"))return false;
   await command("uc_tarim_islem",{p_islem:action,p_sirket:Number(sirket),p_adet:qty,p_urun:action==="ek"?val(el,"ucUrun"):null,p_ekim:null});
 });
}
async function actFarm(action,sirket,qty=1,product=null,ekim=null){
 try{const r=await command("uc_tarim_islem",{p_islem:action,p_sirket:Number(sirket),p_adet:qty,p_urun:product,p_ekim:ekim});
 toast("İşlem gerçekleşti"+(r.adet?" · "+r.adet+" ürün":"")); await open("tarim");
 }catch(err){toast(err.message||String(err),true);}
}
window.ucFarmBagla=async function(id){
  try{
   if(typeof onayla==="function"&&!await onayla("Eski tarım şirketi bağlantısı",
   "Mevcut tarım şirketin üretim yapan gıda fabrikasına bağlanacak. Şirketin sahibi ve bakiyesi korunur.","Üretime bağla"))return;
   await API.rpc("eko_ticaret_islem",{p_eylem:"bagla",p_veri:{sirket:Number(id),urun:"gida"}});
   toast("Tarım şirketin gıda üretimine bağlandı.");
   await open("tarim");
  }catch(err){toast(err.message||String(err),true);}
};
window.ucFarmModal=farmDialog;window.ucFarmDo=actFarm;
function renderFarm(){
 const companies=farmCo(), plots=cache?.ekimler||[], stocks=cache?.stok||[];
 let out=card("🌾 Tarım ve hayvancılık","Buğday, sebze, süt ve et üret. Ürünlerin mevcut fabrika stokuna girer ve oyuncu marketleri bunları toptan satın alabilir.<p><b>Mevsim:</b> yazın verim yüksek, kışın düşük; şehre göre kuraklık değişir. Boş tarlada ekim yapabilir, hasadı hazır olduğunda toplayabilirsin.</p>",
 btn("Yeni tarım şirketi kur", "ekranAc(sirketYonetimEkrani)",true));
 if(!companies.length)return out+card("Henüz tarım işletmen yok","Mevcut şirket kurma ve belediye ruhsatı sisteminden Tarım / Gıda üretimi şirketi kur. Şirket otomatik gıda fabrikasına bağlandıktan sonra buradan tarla ve hayvan alabilirsin.",companyButton);
 for(const s of companies){
   if(s.bagli===false){
     out+=card("🚜 "+s.ad+" · Üretim bağlantısı gerekli",
       "Bu eski tarım şirketi gıda fabrikası sistemine henüz bağlanmamış. Mevcut sermaye ve şirket kasası korunur. Tam sahibiysen üretim bağlantısını aktif edebilirsin.",
       btn("Gıda üretimine bağla","ucFarmBagla("+s.id+")"));
     continue;
   }
   const pending=plots.filter(x=>Number(x.sirket)===Number(s.id));
   const used=pending.reduce((sum,x)=>sum+Number(x.tarla),0);
   out+=card("🚜 "+s.ad,"Şirket kasası: <b>"+TL(s.kasa)+"</b> · Tarla: <b>"+s.tarla+"</b> (boş "+Math.max(0,s.tarla-used)+") · Hayvan: <b>"+s.hayvan+"</b> · İl #"+s.il,
   btn("Tarla al","ucFarmModal('tarla_al',"+s.id+")")+
   btn("Ekim yap","ucFarmModal('ek',"+s.id+")")+
   btn("Hayvan al","ucFarmModal('hayvan_al',"+s.id+")")+
   btn("🥛 Süt sağ","ucFarmDo('sut',"+s.id+")")+
   btn("🥩 Et üret","ucFarmModal('kesim',"+s.id+")"));
   for(const x of pending){
     const ready=new Date(x.hazir).getTime()<=Date.now();
     out+=card(NAME[x.urun]||x.urun,"Ekim #"+x.id+" · "+x.tarla+" tarla · Hasat: "+DT(x.hazir)+" · Verim katsayısı: "+Number(x.verim).toFixed(2),
       ready?btn("Hasadı topla","ucFarmDo('hasat',"+s.id+",1,null,"+x.id+")"):note("⏳ Büyüme devam ediyor."));
   }
   const own=stocks.filter(x=>Number(x.sirket)===Number(s.id));
   if(own.length)out+=card("📦 "+s.ad+" · Satılabilir stok",own.map(x=>E(NAME[x.urun]||x.urun)+" · <b>"+x.adet+" adet</b> · Toptan: "+TL(x.fiyat)).join("<p>")+"</p>",
      btn("Stok fiyatını yönet","ticaretMerkezEkrani('uretim')",true));
 }
 return out;
}
function bookDialog(mode,id){
 if(mode==="teklif"){
  const arr=pressCo();
  if(!arr.length)return toast("Henüz yayınevi bulunmuyor. Medya şirketi kurulmalı.",true);
  return dialog("📖 Kitap dosyası gönder",
   select("ucPress","Yayınevi",arr.map(x=>[x.id,x.ad]))+
   field("ucTitle","Kitap başlığı","")+
   select("ucGenre","Tür",[["Siyasi hatırat","Siyasi hatırat"],["Araştırma","Araştırma"],["Roman","Roman"],["Ekonomi","Ekonomi"],["Anı","Anı"]])+
   area("ucSummary","Kitap tanıtımı (en fazla 600 karakter)","",3)+
   area("ucContent","Kitabın tam metni (100–15.000 karakter)","",10)+
   field("ucAuthorPrice","Kitabın satış fiyatı (100–2.000 ₺)",300,"number",100,2000)+
   note("Satış fiyatını sen belirlersin. Yayınevi baskı ücretini ödeyip kitabını onaylar; diğer oyuncular cüzdanlarından satın alabilir. Her satıştan %15 telif alırsın."),
   "Yayınevine gönder",async el=>{
    const price=Number(val(el,"ucAuthorPrice"));
    if(!Number.isInteger(price)||price<100||price>2000){toast("Kitap fiyatını 100 ile 2.000 ₺ arasında belirle.",true);return false;}
    await command("uc_kitap_islem",{p_islem:"teklif",p_id:Number(val(el,"ucPress")),p_veri:{baslik:val(el,"ucTitle"),tur:val(el,"ucGenre"),ozet:val(el,"ucSummary"),icerik:val(el,"ucContent"),fiyat:price}});
  });
 }
 const k=(cache?.kitaplar||[]).find(x=>Number(x.id)===Number(id));if(!k)return;
 if(mode==="oku")return modal("<h3>"+E(k.baslik)+"</h3>"+note("Yazar: "+k.yazar+" · "+k.tur)+
   '<div style="max-height:50vh;overflow:auto;white-space:pre-wrap;line-height:1.6">'+E(k.icerik)+'</div>'+btn("Kapat","modalKapat()",true));
 if(mode==="satinal")return confirmBook(id,k);
 if(mode==="reddet")return bookAct("reddet",id,{});
 if(mode==="fiyat"){
   if(!k.yazar_benim)return toast("Kitap fiyatını yalnızca yazarı değiştirebilir.",true);
   return dialog("💰 Kitabın satış fiyatı",note(k.baslik+" · Mevcut fiyat: "+TL(k.fiyat))+
     field("ucNewPrice","Yeni satış fiyatı (100–2.000 ₺)",k.fiyat,"number",100,2000)+
     note("Satış geliri yayınevine, %15 telif yazara aktarılır. Yayımlanmış kitapların fiyatı 24 saatte bir değiştirilebilir."),
     "Fiyatı kaydet",async el=>{
       const price=Number(val(el,"ucNewPrice"));
       if(!Number.isInteger(price)||price<100||price>2000){toast("100–2.000 ₺ arasında tam sayı yaz.",true);return false;}
       await command("uc_kitap_islem",{p_islem:"fiyat",p_id:Number(id),p_veri:{fiyat:price}});
     });
 }
 const reprint=mode==="yenibaski";
 return dialog(reprint?"📚 Yeni baskı":"📚 Basım ve yayım",
  note(k.baslik+" · Yayınevi: "+k.yayinevi_ad)+
  note("Yazarın belirlediği satış fiyatı: "+TL(k.fiyat))+
  field("ucCopies","Basılacak adet (10–200)",50,"number",10,200)+
  note("Baskı maliyeti satış fiyatının %40'ıdır. Yazar her satıştan %15 telif alır. Satışlar vergiye tabidir."),
  reprint?"Yeni baskı yap":"Onayla ve yayımla",async el=>{
    const qty=Number(val(el,"ucCopies")),price=Number(k.fiyat);
    if(!Number.isInteger(qty)||qty<10||qty>200){toast("10–200 adet arasında baskı seç.",true);return false;}
    if(typeof onayla==="function" && !await onayla("Baskı masrafı",qty+" kopya için "+TL(qty*price*.4)+" şirket kasasından kesilecek.","Basımı onayla"))return false;
    await command("uc_kitap_islem",{p_islem:mode,p_id:Number(id),p_veri:{adet:qty}});
  });
}
async function confirmBook(id,k){
 if(typeof onayla==="function" && !await onayla("Kitap satın al",k.baslik+" için "+TL(k.fiyat)+" cüzdanından düşecek.","Satın al"))return;
 await bookAct("satinal",id,{});
}
async function bookAct(mode,id,data){
 try{const result=await command("uc_kitap_islem",{p_islem:mode,p_id:Number(id),p_veri:data||{}});
 toast("Kitap işlemi tamamlandı"+(result.telif?" · Yazar telifi: "+TL(result.telif):""));
 if(typeof durumYenile==="function")durumYenile().catch(()=>{});
 await open("kitap");
 }catch(err){toast(err.message||String(err),true);}
}
window.ucBookModal=bookDialog;window.ucBookDo=bookAct;
function renderBooks(){
 let out=card("📚 Kitap yaz, yayımla, telif kazan","Kitabına satış fiyatını <b>yazar olarak sen belirlersin</b>. Yayınevi yöneticisi onaylar ve baskı giderini karşılar. Yayımlanan kitabı diğer oyuncular oyun parasıyla satın alır; kitap, satın alanın kitaplığında kalır. Ayrıca sanal okur satışı yapılır. Yazar her satıştan <b>%15 telif</b> alır.",
 btn("✍️ Kitap yaz ve gönder","ucBookModal('teklif',0)")+
 btn("🏢 Yayınevlerini ve kitaplarını gör","ucEkonomiEkrani(\'medya\')",true)+
 btn("🏗️ Medya şirketi kur","ekranAc(sirketYonetimEkrani)",true));
 const manages=cache?.benim_yayinevleri||[];
 for(const k of cache?.kitaplar||[]){
   const own=manages.some(id=>Number(id)===Number(k.yayinevi));
   const detail="Yazar: "+E(k.yazar)+" · Yayınevi: "+E(k.yayinevi_ad)+"<p>"+E(k.ozet)+"</p>"+
   "Durum: <b>"+E(k.durum)+"</b> · Stok: "+k.stok+" · Satılan: "+k.satilan+
   (k.durum==="yayinda"?" · Fiyat: "+TL(k.fiyat):k.yazar_benim?" · Belirlediğin fiyat: "+TL(k.fiyat):"");
   let acts="";
   if(k.durum==="yayinda")acts+=(k.icerik?btn("📖 Oku","ucBookModal('oku',"+k.id+")",true):"")+
      (!k.aldim&&!k.yazar_benim&&k.stok>0?btn("📕 "+TL(k.fiyat)+" · Satın al","ucBookModal('satinal',"+k.id+")"):"")+
      (k.aldim?note("✅ Kitaplığında · İstediğin zaman okuyabilirsin."):(!k.yazar_benim&&k.stok<=0?note("Stok tükendi; yayınevi yeni baskı yaptığında satın alabilirsin."):"")); 
   acts+=btn("🏢 Yayınevi sayfası","ucMedyaAc("+k.yayinevi+")",true);
   if(k.yazar_benim && (k.durum==="teklif"||k.durum==="yayinda"))acts+=btn("💰 Fiyatı belirle / değiştir","ucBookModal('fiyat',"+k.id+")",true);
   if(own&&k.durum==="teklif")acts+=btn("Yayımla","ucBookModal('yayinla',"+k.id+")")+btn("Reddet","ucBookDo('reddet',"+k.id+")",true)+btn("Metni incele","ucBookModal('oku',"+k.id+")",true);
   if(own&&k.durum==="yayinda")acts+=btn("Yeni baskı","ucBookModal('yenibaski',"+k.id+")");
   out+=card(k.baslik,detail,acts);
 }
 if(!(cache?.kitaplar||[]).length)out+=card("Henüz kitap yok","İlk eserini yayınevine gönderebilirsin.");
 return out;
}

/* Medya ve yayınevleri: herkese açık şirketler, yayımlanmış kitaplar ve destek. */
function renderMedia(){
 const entries=cache?.sirketler||[];
 let out=card("🏢 Medya şirketleri ve yayınevleri",
 "Millet TV gibi medya şirketlerini ve reklam ajanslarını incele. Yayımlanmış kitapların fiyat ve stok durumunu gör, oyun parasıyla satın al veya şirkete destek ol. <b>Kitapların tam metni burada gösterilmez.</b>",
 btn("📚 Kitaplığıma git","ucEkonomiEkrani('kitap')",true));
 out+='<div class="alan" style="margin:12px 0"><label>🔎 Şirket veya sahip ara</label><input id="ucMedyaAra" type="search" placeholder="Örn. Millet TV" oninput="ucMedyaFiltrele(this.value)" style="width:100%"></div>';
 if(!entries.length)return out+card("Henüz medya şirketi yok","Oyuncular şirket kurma bölümünden medya şirketi açabilir.");
 for(const s of entries){
   const publications=Array.isArray(s.kitaplar)?s.kitaplar:[];
   const media=s.sektor==="medya";
   let books='<div class="alt" style="margin:12px 0 7px;font-weight:700">📕 Yayımlanan kitaplar</div>';
   if(!media)books=note("Bu şirket reklam ajansıdır. Kitap yayımlama medya şirketleri üzerinden yapılır.");
   else if(!publications.length)books+=note("Bu yayınevinin henüz satışa sunulmuş kitabı yok. Bekleyen teklifler yayımlanıncaya kadar listelenmez.");
   else for(const k of publications){
     const canBuy=!k.benim&&!k.aldim&&Number(k.stok)>0;
     books+='<div style="border:1px solid var(--line2,#354364);border-radius:12px;padding:12px;margin:8px 0">'+
       '<b>'+E(k.baslik)+'</b><div class="alt">Yazar: '+E(k.yazar||"—")+' · '+E(k.tur||"Kitap")+'</div>'+
       '<p class="alt" style="white-space:pre-line">'+E(k.ozet||"")+'</p>'+
       '<div class="alt">Fiyat: <b>'+TL(k.fiyat)+'</b> · Stok: '+Number(k.stok)+' · Satılan: '+Number(k.satilan)+'</div>'+
       (canBuy?btn("📕 Satın al · "+TL(k.fiyat),"ucMedyaKitapAl("+k.id+")"):
         (k.aldim?note("✅ Kitaplığında · Tam metni Kitap bölümünde okuyabilirsin."):
          k.benim?note("✍️ Bu kitabın yazarı sensin."):note("Şu anda stok yok.")))+
       '</div>';
   }
   const key=E((s.ad+" "+(s.sahip||"")).toLocaleLowerCase("tr-TR"));
   out+='<div class="kart uc-medya-kart" data-arama="'+key+'" data-medya="'+Number(s.id)+'" style="margin-bottom:12px;padding:14px">'+
     '<details'+(Number(medyaOdak)===Number(s.id)?' open':'')+'>'+
     '<summary style="cursor:pointer;list-style:none;display:flex;gap:10px;justify-content:space-between;align-items:center">'+
       '<span style="font-weight:800;font-size:19px">'+(media?'📺 ':'📢 ')+E(s.ad)+'</span>'+
       '<span class="alt">'+(media?'Medya / Yayınevi':'Reklam ajansı')+' · ›</span>'+
     '</summary>'+
     '<p class="alt" style="margin-top:10px">Yönetici: <b>'+E(s.sahip||"—")+'</b> · '+(media?'Yayımlanan kitap: '+publications.length:'Ajans hizmetleri')+'</p>'+
     '<p class="alt">Toplam oyuncu desteği: <b>'+TL(s.destek_toplam)+'</b> · '+Number(s.destek_sayisi)+' işlem</p>'+
     books+
     btn("💝 Bu şirkete bağış yap","ucMedyaBagis("+s.id+")")+
     '</details></div>';
 }
 return out;
}
window.ucMedyaFiltrele=function(q){
 const txt=String(q||"").trim().toLocaleLowerCase("tr-TR");
 document.querySelectorAll(".uc-medya-kart").forEach(el=>{
  el.style.display=el.dataset.arama.includes(txt)?"":"none";
 });
};
window.ucMedyaAc=async function(id){
 medyaOdak=Number(id);
 await open("medya");
 try{document.querySelector('.uc-medya-kart[data-medya="'+medyaOdak+'"]')?.scrollIntoView({block:"nearest"});}catch(_){}
};
window.ucMedyaBagis=function(id){
 const s=(cache?.sirketler||[]).find(x=>Number(x.id)===Number(id));
 if(!s)return toast("Şirketi yeniden açıp dene.",true);
 medyaOdak=Number(id);
 return dialog("💝 "+s.ad+" şirketine destek ol",
   note("Bağış cüzdanından alınır ve doğrudan şirket kasasına eklenir. Bir satış veya kâr işlemi değildir.")+
   field("ucMedyaTutar","Bağış miktarı (100–1.000.000 ₺)",1000,"number",100,1000000)+
   note("Aynı şirkete 24 saatte en fazla 10 işlem ve toplam 5 milyon ₺ destek gönderilebilir."),
   "Bağışı gönder",async el=>{
     const amount=Number(val(el,"ucMedyaTutar"));
     if(!Number.isInteger(amount)||amount<100||amount>1000000){
       toast("100 ile 1.000.000 ₺ arasında tam sayı gir.",true);return false;
     }
     if(typeof onayla==="function"&&!await onayla("Şirkete bağış onayı",
       s.ad+" şirketine "+TL(amount)+" göndermek istiyor musun?","Gönder"))return false;
     await command("uc_medya_bagis",{p_sirket:Number(id),p_tutar:amount});
   });
};
window.ucMedyaKitapAl=async function(id){
 const k=(cache?.sirketler||[]).flatMap(x=>x.kitaplar||[]).find(x=>Number(x.id)===Number(id));
 if(!k||k.aldim||k.benim||Number(k.stok)<=0)return toast("Kitap satın almaya uygun değil.",true);
 if(typeof onayla==="function"&&!await onayla("Kitap satın al",
   k.baslik+" kitabı için "+TL(k.fiyat)+" cüzdanından düşecek.","Satın al"))return;
 try{
   await command("uc_kitap_islem",{p_islem:"satinal",p_id:Number(id),p_veri:{}});
   toast("Kitap satın alındı! Kitaplığımdan okuyabilirsin.");
   if(typeof durumYenile==="function")durumYenile().catch(()=>{});
   await open("medya");
 }catch(err){toast(err.message||String(err),true);}
};

function eventDialog(mode,id){
 if(mode==="kur"){
  const companies=eventCo().filter(s=>["medya","ajans"].includes(s.sektor));
  if(!companies.length)return toast("Önce bir medya veya ajans şirketi kur.",true);
  const when=new Date(Date.now()+48*3600000).toISOString().slice(0,16);
  return dialog("🎟️ Yeni organizasyon",select("ucCompany","Organizatör şirket",companies.map(x=>[x.id,x.ad+" · "+TL(x.kasa)]))+
   field("ucName","Etkinlik adı","")+
   select("ucType","Etkinlik tipi",[["konferans","Konferans"],["forum","Ekonomik forum"],["konser","Konser"],["fuar","Fuar"]])+
   select("ucCity","Etkinlik ili",(cache?.iller||[]).map(x=>[x.id,x.ad]))+
   field("ucDate","Etkinlik tarihi (12 saat–7 gün içinde)",when,"datetime-local")+
   field("ucCapacity","Salon kapasitesi (30–500)",100,"number",30,500)+
   field("ucTicket","Bilet fiyatı (50–3000 ₺)",400,"number",50,3000)+
   note("Salon kirası = 5.000 ₺ + kapasite × 80 ₺. Ayrıca gerçekleşen bilet cirosunun %15'i personel ve hizmet gideridir. Sponsorluk gelirleri ayrıdır."),
   "Organizasyonu oluştur",async el=>{
    const cap=Number(val(el,"ucCapacity")),ticket=Number(val(el,"ucTicket"));
    if(typeof onayla==="function" && !await onayla("Salon ve organizasyon kirası",TL(5000+cap*80)+" şirket kasasından peşin kesilecek.","Etkinlik kur"))return false;
    const dt=new Date(val(el,"ucDate"));
    if(!Number.isFinite(dt.getTime()))return toast("Geçerli tarih seç.",true),false;
    await command("uc_etkinlik_islem",{p_islem:"kur",p_id:Number(val(el,"ucCompany")),
      p_veri:{baslik:val(el,"ucName"),tur:val(el,"ucType"),il:Number(val(el,"ucCity")),
        zaman:dt.toISOString(),kapasite:cap,bilet:ticket}});
   });
 }
 const evt=(cache?.etkinlikler||[]).find(x=>Number(x.id)===Number(id));if(!evt)return;
 if(mode==="bilet_al")return eventAct("bilet_al",id,{});
 if(mode==="sponsor"){
   const companies=eventCo().filter(s=>Number(s.id)!==Number(evt.sirket));
   if(!companies.length)return toast("Sponsor olmak için başka bir şirket yönetmelisin.",true);
   return dialog("🤝 Etkinliğe sponsor ol",note(evt.baslik+" · Organizatör: "+evt.sirket_ad)+
     select("ucCompany","Sponsor şirket",companies.map(x=>[x.id,x.ad+" · "+TL(x.kasa)]))+
     field("ucAmount","Sponsor katkısı (1000–100.000 ₺)",5000,"number",1000,100000)+
     note("Tutar sponsor şirketten organizatör şirkete geçer; aynı şirket aynı etkinliğe yalnız bir kez sponsor olabilir."),
     "Sponsorluğu öde",async el=>{
      const amount=Number(val(el,"ucAmount"));
      if(typeof onayla==="function"&&!await onayla("Sponsorluk ödemesi",TL(amount)+" sponsor şirketin kasasından organizatöre gönderilecek.","Öde"))return false;
      await command("uc_etkinlik_islem",{p_islem:"sponsor",p_id:Number(id),
        p_veri:{sirket:Number(val(el,"ucCompany")),tutar:amount}});
     });
 }
}
async function eventAct(mode,id,data){
 try{
  const evt=(cache?.etkinlikler||[]).find(x=>Number(x.id)===Number(id));
  if(mode==="bilet_al"&&typeof onayla==="function" && !await onayla("Bilet satın al",evt.baslik+" etkinliğine "+TL(evt.bilet)+" ödeyerek katıl.","Bilet al"))return;
  await command("uc_etkinlik_islem",{p_islem:mode,p_id:Number(id),p_veri:data||{}});
  toast("Etkinlik işlemi tamamlandı.");if(typeof durumYenile==="function")durumYenile().catch(()=>{});
  await open("etkinlik");
 }catch(err){toast(err.message||String(err),true);}
}
window.ucEtkinlikIptal=async function(id){
 const ev=(cache?.etkinlikler||[]).find(x=>Number(x.id)===Number(id));
 if(!ev||ev.durum!=="planlandi")return;
 if(!confirm("Etkinliği iptal etmek istiyor musun? Biletler ve sponsorluklar iade edilecek; salon gideri iade edilmez."))return;
 try{
  await API.rpc("uc_etkinlik_iptal",{p_id:Number(id),p_neden:"Organizatör talebi"});
  toast("Etkinlik iptal edildi; iadeler yapıldı.");
  await open("etkinlik");
 }catch(ex){toast(ex.message||String(ex),true);}
};
window.ucEventModal=eventDialog;window.ucEventDo=eventAct;
function renderEvents(){
 let out=card("🎟️ Konferans, konser ve fuarlar","Oyuncular kendi medya veya ajans şirketleriyle etkinlik düzenleyebilir. Mekân kirasını öder, bilet fiyatını ve salon kapasitesini seçer; gerçek oyuncular ile sınırlı sayıdaki sanal ziyaretçiler bilet alır. Bitişte vergiler ve personel gideri düşülür.",
  btn("➕ Organizasyon düzenle","ucEventModal('kur',0)")+
  btn("🏢 Şirketlerim","ekranAc(sirketYonetimEkrani)",true));
 const list=[...(cache?.etkinlikler||[])].sort((a,b)=>new Date(b.zaman)-new Date(a.zaman));
 for(const ev of list){
  const city=(cache?.iller||[]).find(x=>Number(x.id)===Number(ev.il));
  const openSale=ev.durum==="planlandi" && new Date(ev.zaman)>new Date() && ev.satilan<ev.kapasite;
  out+=card("🎤 "+ev.baslik,E(ev.tur)+" · "+E(city?.ad||"İl "+ev.il)+" · "+DT(ev.zaman)+
   "<p>Organizatör: "+E(ev.sirket_ad)+"</p>"+
   "<b>"+TL(ev.bilet)+"</b> / bilet · "+ev.satilan+"/"+ev.kapasite+" satıldı"+
   "<p>Sponsor: "+TL(ev.sponsor)+" · Bilet cirosu: "+TL(ev.ciro)+" · Salon gideri: "+TL(ev.mekan)+"</p>"+
   (ev.durum==="bitti"?"<b>Net sonuç: "+TL(ev.kar)+"</b>":ev.durum==="iptal"?"<b>Etkinlik iptal edildi · İadeler yapıldı.</b>":"⏳ Etkinlik günü sanal katılım da hesaplanacak."),
   (openSale&&!ev.biletim?btn("🎟️ Bilet al","ucEventDo('bilet_al',"+ev.id+")"):"")+
   (ev.biletim?note("✅ Biletin var"):"")+
   (ev.durum==="planlandi"?btn("Sponsor ol","ucEventModal('sponsor',"+ev.id+")",true):"")+
   (ev.durum==="planlandi" && (cache?.sirketler||[]).some(s=>Number(s.id)===Number(ev.sirket))?btn("Etkinliği İptal Et","ucEtkinlikIptal("+ev.id+")",true):""));
 }
 if(!list.length)out+=card("Henüz organizasyon yok","İlk konferansı, konseri veya fuarı sen düzenleyebilirsin.");
 return out;
}
})();