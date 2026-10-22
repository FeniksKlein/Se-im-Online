/* Sigorta ve Afet Merkezi: şehir hasarları, konut/dükkan poliçeleri ve onarım. */
(function(){
"use strict";
const esc=x=>String(x===null||x===undefined?"":x).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const tl=x=>Math.round(Number(x)||0).toLocaleString("tr-TR")+" ₺";
const d=x=>x?new Date(x).toLocaleDateString("tr-TR"):"—";
let veri=null;
function sat(k,v){return '<div class="kv"><span>'+esc(k)+'</span><b>'+esc(v)+'</b></div>';}
async function ac(){
 if(typeof yukleniyor==="function")yukleniyor("Sigorta ve Doğal Afetler");
 try{
  veri=await API.rpc("sigorta_afet_panel");
  const x=veri, ev=x.mulkler||[], ins=x.sigortacilar||[], pol=x.policeler||[], has=x.hasarlar||[], afet=x.afetler||[];
  let out='<section class="kart"><h2>🏠 Mülk ve doğal afet sigortası</h2>'+
   '<p class="alt">Ev, dükkân ve diğer gayrimenkullere düşük olasılıkla deprem, sel, yangın, fırtına veya şiddetli rüzgâr hasarı gelebilir. Sigortasız hasarın onarımını sahibi öder ve onarılmayan mülkün kira getirisi azalır. Poliçeli mülk hasar gerçekleşirse teminat ve muafiyet sınırlarında tazminat alır. İlk risk tarihi: 25 Ekim 2026.</p>'+
   sat("Mülk",ev.length)+sat("Aktif sigortalı",ev.filter(v=>v.aktif_police).length)+
   sat("Gerçekleşen afet",afet.length)+
   '<p class="alt">Konut/dükkân sigortası: 7 gün, teminatın %0,5’i prim (asgari 200 ₺), hasarın %10’u muafiyet (asgari 1.000 ₺). Sigorta şirketleri yeterli rezerv olmadan poliçe satamaz.</p>'+
   '<button class="btn altin" onclick="sigortaMulkPoliceAc()">Mülkü sigortala</button>'+
   '<button class="btn ikinci" onclick="sigortaSirketKur()">Sigorta şirketi kur</button>'+
   '<button class="btn ikinci" onclick="sigortaIsletmeEkrani()">İşletme ve fabrika sigortası</button></section>';
  out+='<div class="bolum-bas"><h2>Gayrimenkullerim</h2></div>';
  if(!ev.length)out+='<section class="kart"><p class="alt">Henüz gayrimenkulün yok. Gayrimenkul menüsünden ev veya dükkân satın alabilirsin.</p></section>';
  for(const m of ev){
   out+='<section class="kart"><h3>'+esc(m.tur)+' · '+esc(m.il)+' (#'+Number(m.id)+')</h3>'+
   sat("Alış bedeli",tl(m.bedel))+sat("Haftalık kira",tl(m.kira))+
   sat("Sigorta",m.aktif_police?"Aktif":"Yok")+sat("Onarım borcu",tl(m.onarim_borcu))+
   (Number(m.onarim_borcu)>0?'<button class="btn ikinci" onclick="sigortaMulkOnarAc('+Number(m.id)+')">Hasarı onar</button>':'')+
   (!m.aktif_police?'<button class="btn altin" onclick="sigortaMulkPoliceAc('+Number(m.id)+')">Bu mülkü sigortala</button>':'')+'</section>';
  }
  out+='<div class="bolum-bas"><h2>Sigorta şirketleri</h2></div>';
  for(const s of ins)out+='<section class="kart"><h3>'+esc(s.ad)+'</h3>'+
    sat("Şirket kasası",tl(s.kasa))+sat("Mülk teminat yükü",tl(s.aktif_mulk_teminati))+
    '<button class="btn ikinci" onclick="sigortaMulkPoliceAc(null,'+Number(s.id)+')">Bu şirketten poliçe al</button></section>';
  if(!ins.length)out+='<section class="kart"><p class="alt">Henüz sigortacı bulunmuyor; şirket kurulduğunda poliçe alınabilir.</p></section>';
  out+='<div class="bolum-bas"><h2>Poliçelerim ve sigortaladıklarım</h2></div>';
  if(!pol.length)out+='<section class="kart"><p class="alt">Poliçe kaydı yok.</p></section>';
  for(const p of pol)out+='<section class="kart"><h3>Mülk #'+Number(p.mulk)+' · '+esc(p.sigortaci)+'</h3>'+
    sat("Durum",p.durum==="aktif"?"Aktif":"Süresi dolmuş")+
    sat("Prim",tl(p.prim))+sat("Teminat",tl(p.teminat))+
    '<p class="alt">'+d(p.bas)+' — '+d(p.bit)+'</p></section>';
  out+='<div class="bolum-bas"><h2>Hasarlar ve tazminatlar</h2></div>';
  if(!has.length)out+='<section class="kart"><p class="alt">Henüz hasar dosyası yok. Olaylar yalnızca sunucuda otomatik oluşturulur.</p></section>';
  for(const h of has)out+='<section class="kart"><h3>'+esc(h.olay)+' · '+esc(h.il)+'</h3>'+
    '<p class="alt">Mülk #'+Number(h.mulk)+' · '+esc(h.gun)+'</p>'+
    sat("Hasar",tl(h.zarar))+sat("Hak edilen tazminat",tl(h.tazminat))+
    sat("Ödenen",tl(h.odenen))+'</section>';
  out+='<div class="bolum-bas"><h2>Son şehir afetleri</h2></div>';
  if(!afet.length)out+='<section class="kart"><p class="alt">Henüz kaydedilmiş doğal afet yok.</p></section>';
  for(const a of afet)out+='<section class="kart"><h3>'+esc(a.il)+' · '+esc(a.olay)+'</h3>'+
   '<p class="alt">'+esc(a.gun)+' · Etkilenen varlık: '+Number(a.etkilenen)+'</p></section>';
  iskelet("Sigorta ve Doğal Afetler",out,{geri:true});
 }catch(err){
  iskelet("Sigorta ve Doğal Afetler",'<section class="kart"><p class="alt">'+esc(err?.message||String(err))+'</p>'+
   '<button class="btn ikinci" onclick="sigortaAfetEkrani()">Tekrar dene</button></section>',{geri:true});
 }
}
function poliModal(mulkId,insId){
 const ev=veri?.mulkler||[], ins=veri?.sigortacilar||[];
 const aday=ev.filter(x=>!x.aktif_police);
 if(!aday.length){toast("Sigortalanabilecek mülkün bulunmuyor.",true);return;}
 if(!ins.length){toast("Henüz sigorta şirketi yok.",true);return;}
 modal('<h3>Mülk sigortası</h3><p class="alt">Poliçe 7 gün geçerlidir. Prim cüzdanından alınır; hasar anında karşı şirketin kasasından tazminat ödenir.</p>'+
 '<div class="alan"><label>Mülk</label><select id="saM">'+aday.map(x=>'<option value="'+Number(x.id)+'">'+esc(x.tur)+' · '+esc(x.il)+' · '+tl(x.bedel)+'</option>').join("")+'</select></div>'+
 '<div class="alan"><label>Sigorta şirketi</label><select id="saS">'+ins.map(x=>'<option value="'+Number(x.id)+'">'+esc(x.ad)+'</option>').join("")+'</select></div>'+
 '<div class="alan"><label>Teminat (₺)</label><input id="saT" type="number" inputmode="numeric" min="10000" max="2000000" step="1000" value="50000"></div>'+
 '<p id="saInfo" class="alt"></p><button class="btn altin" id="saBuy">Poliçeyi satın al</button>'+
 '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 const root=document.getElementById("modal")||document;
 const elm=id=>root.querySelector("#"+id)||document.getElementById(id);
 const m=elm("saM"),s=elm("saS"),t=elm("saT"),info=elm("saInfo"),buy=elm("saBuy");
 if(!m||!s||!t||!info||!buy){toast("Poliçe formu açılmadı.",true);return;}
 if(aday.some(x=>Number(x.id)===Number(mulkId)))m.value=String(mulkId);
 if(ins.some(x=>Number(x.id)===Number(insId)))s.value=String(insId);
 const refresh=()=>{
  const asset=aday.find(x=>Number(x.id)===Number(m.value));
  const max=Math.min(2000000,Math.floor(Number(asset?.bedel)||0));
  const cover=Number(t.value);
  const valid=Number.isSafeInteger(cover)&&cover>=10000&&cover<=max;
  t.max=String(max);
  info.textContent="En fazla "+tl(max)+" teminat · Prim "+tl(Math.max(200,Math.round(cover*0.005)))+" · Muafiyet %10 (en az 1.000 ₺).";
  buy.disabled=!valid;
 };
 m.onchange=refresh;t.oninput=refresh;refresh();
 buy.onclick=async()=>{
  if(buy.disabled)return;buy.disabled=true;
  try{
   const p=await API.rpc("sigorta_mulk_police_al",{
    p_mulk:Number(m.value),p_sigortaci:Number(s.value),p_teminat:Number(t.value)
   });
   modalKapat();toast("Poliçen başladı. Prim: "+tl(p.prim));
   if(typeof durumYenile==="function")durumYenile().catch(()=>{});
   await ac();
  }catch(ex){toast(String(ex?.message||ex),true);buy.disabled=false;}
 };
}
function onarModal(id){
 const m=(veri?.mulkler||[]).find(x=>Number(x.id)===Number(id));
 if(!m||Number(m.onarim_borcu)<=0){toast("Onarılacak hasar yok.",true);return;}
 modal('<h3>Hasarlı mülkü onar</h3><p class="alt">Kalan onarım borcu: '+tl(m.onarim_borcu)+
 '. Bedel cüzdanından ödenir; tüm borç kapanınca kira eski seviyesine çıkar.</p>'+
 '<div class="alan"><label>Onarım tutarı (₺)</label><input id="saFix" type="number" min="1" max="'+Math.floor(Number(m.onarim_borcu))+'" value="'+Math.floor(Number(m.onarim_borcu))+'"></div>'+
 '<button class="btn altin" id="saRepair">Onarım bedelini öde</button>'+
 '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 const btn=document.getElementById("saRepair"),field=document.getElementById("saFix");
 if(!btn||!field)return;
 btn.onclick=async()=>{
  const value=Number(field.value);
  if(!Number.isSafeInteger(value)||value<=0||value>Number(m.onarim_borcu)){toast("Geçerli tutar gir.",true);return;}
  btn.disabled=true;
  try{
   await API.rpc("sigorta_mulk_onar",{p_mulk:Number(id),p_tutar:value});
   modalKapat();toast("Mülk onarımı kaydedildi.");
   if(typeof durumYenile==="function")durumYenile().catch(()=>{});
   await ac();
  }catch(ex){toast(String(ex?.message||ex),true);btn.disabled=false;}
 };
}
window.sigortaAfetEkrani=ac;
window.sigortaMulkPoliceAc=poliModal;
window.sigortaMulkOnarAc=onarModal;
})();


/* Sigorta menüsünden afet sigortasına geçiş; eski menüler değişmeden kalır. */
(function(){
 const previous=window.sigortaIsletmeEkrani;
 if(typeof previous!=="function" || previous._sigAfetBaglandi)return;
 async function withAfet(){
  const result=await previous.apply(this,arguments);
  try{
   const header=Array.from(document.querySelectorAll("h2")).find(x=>x.textContent&&x.textContent.includes("İşletme sigortaları"));
   const section=header&&header.closest("section");
   if(section&&!section.querySelector(".sigorta-afet-ac")){
    const button=document.createElement("button");
    button.className="btn altin sigorta-afet-ac";
    button.type="button";
    button.textContent="🏠 Ev, dükkân ve doğal afet sigortası";
    button.onclick=()=>window.sigortaAfetEkrani();
    section.appendChild(button);
   }
  }catch(err){console.warn("Afet sigortası menü bağlama:",err);}
  return result;
 }
 withAfet._sigAfetBaglandi=true;
 window.sigortaIsletmeEkrani=withAfet;
})();


/* Eski uygulama paketi dahil: kendi sigorta şirketine bağlı farklı işletme de poliçe alabilir.
   Sunucu da şirket IDsinin aynı olmasını ve teminat sınırını denetler. */
(function(){
 "use strict";
 const format=n=>Math.round(Number(n)||0).toLocaleString("tr-TR")+" ₺";
 const escapeHtml=t=>String(t??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
 function insuranceOffer(offer){
  if(typeof API==="undefined"||typeof modal!=="function"){if(typeof toast==="function")toast("Sigorta sistemi açılamadı.",true);return;}
  (async()=>{
   try{
    const d=await API.rpc("sigorta_isletme_panel");
    const companies=d.sirketler||[], insurers=d.sigortacilar||[];
    if(!companies.length){toast("Önce sigortalatacağın şirketi kur.",true);return;}
    if(!insurers.length){toast("Sigorta şirketi bulunamadı.",true);return;}
    const options=a=>a.map(x=>'<option value="'+Number(x.id)+'">'+escapeHtml(x.ad)+'</option>').join("");
    const popup=modal('<h3>🛡️ İşletmemi sigortala</h3>'+
      '<p class="alt">Sahibi olduğun ayrı sigorta şirketini de seçebilirsin. Prim şirket kasasından ödenir. Teminat 72 saat sürer.</p>'+
      '<div class="alan"><label>Sigortalanacak şirket</label><select id="ownInsCompany">'+options(companies)+'</select></div>'+
      '<div class="alan"><label>Sigorta şirketi</label><select id="ownInsInsurer">'+options(insurers)+'</select></div>'+
      '<div class="alan"><label>Teminat (₺)</label><input id="ownInsCover" type="number" inputmode="numeric" min="10000" max="500000" step="1000" value="50000"></div>'+
      '<p id="ownInsInfo" class="alt"></p>'+
      '<button class="btn altin" id="ownInsBuy" type="button">Poliçe satın al</button>'+
      '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
    const el=id=>(popup&&typeof popup.querySelector==="function"?popup.querySelector("#"+id):null)||document.getElementById(id);
    const c=el("ownInsCompany"),i=el("ownInsInsurer"),v=el("ownInsCover"),status=el("ownInsInfo"),buy=el("ownInsBuy");
    if(!c||!i||!v||!status||!buy)throw Error("Poliçe formu yüklenemedi.");
    if(insurers.some(s=>Number(s.id)===Number(offer)))i.value=String(offer);
    function check(){
      const co=companies.find(s=>Number(s.id)===Number(c.value));
      const max=Math.min(500000,Math.round(Number(co?.sermaye||0)*1.5));
      const n=Number(v.value);
      const ownSelf=Number(c.value)===Number(i.value);
      const active=(d.policeler||[]).some(p=>p.durum==="aktif"&&Number(p.isletme)===Number(c.value));
      const valid=!active&&!ownSelf&&Number.isSafeInteger(n)&&n>=10000&&n<=max;
      status.textContent=active?"Seçili şirketin yürürlükte poliçesi var.":ownSelf?"Bir şirket bizzat kendisine poliçe kesemez. Ayrı sigorta şirketi seç.":"En fazla "+format(max)+" teminat; prim "+format(Math.max(300,Math.round(n*0.02)))+"; muafiyet %10.";
      v.max=String(max);buy.disabled=!valid;
    }
    c.onchange=check;i.onchange=check;v.oninput=check;check();
    buy.onclick=async()=>{
      if(buy.disabled)return;buy.disabled=true;
      try{
        const policy=await API.rpc("sigorta_isletme_police_al",{
          p_isletme:Number(c.value),p_sigortaci:Number(i.value),p_teminat:Number(v.value)
        });
        modalKapat();toast("İşletme poliçen düzenlendi. Prim: "+format(policy.prim));
        if(typeof durumYenile==="function")durumYenile().catch(()=>{});
        if(typeof window.sigortaIsletmeEkrani==="function")await window.sigortaIsletmeEkrani();
      }catch(err){toast(typeof hataCevir==="function"?hataCevir(err?.message||String(err)):String(err?.message||err),true);check();}
    };
   }catch(err){toast(typeof hataCevir==="function"?hataCevir(err?.message||String(err)):String(err?.message||err),true);}
  })();
 }
 window.sigortaPoliceAc=insuranceOffer;
})();
