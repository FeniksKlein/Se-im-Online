/* Sahibinden benzeri emlak ilanları ve gerçek oyuncu pazarlığı */
"use strict";
const emlakAd={daire:"Daire",dukkan:"Dükkân",villa:"Villa"};
const emlakTL=x=>tlYaz(Number(x)||0);
let emlakIlanlar=[];
async function emlakYeniEkrani(){
 yukleniyor("Gayrimenkul pazarı");
 try{emlakYeniCiz(await API.rpc("mulk_pazar"));}
 catch(err){iskelet("Emlak pazarı",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function emlakYeniCiz(d){
 emlakIlanlar=d.ilanlar||[];
 iskelet("Emlak pazarı",`
 <div class="kart vit-manset"><h2>🏡 Oyuncudan Emlak</h2><p class="alt">Oyuncuların satılık mülklerini incele, ilanları karşılaştır, doğrudan satın al veya pazarlık yap.</p>
 <div class="vit-dugme"><button class="btn altin" onclick="emlakPazarliklarimEkrani()">Pazarlıklarım</button><button class="btn ikinci" onclick="ekranAc(mulkEkrani)">Mülklerim</button></div></div>
 <div class="vit-ozet"><span><b>${emlakIlanlar.length}</b> satılık ilan</span><span><b>%2</b> işlem vergisi</span></div>
 <div class="kart">
   <div class="vit-filtre"><div class="alan"><label>Mülk tipi</label><select id="emlakTip" onchange="emlakYeniListeCiz()">
      <option value="">Tümü</option><option value="daire">Daire</option><option value="dukkan">Dükkân</option><option value="villa">Villa</option></select></div>
    <div class="alan"><label>Azami satış fiyatı</label><input id="emlakMax" type="number" min="0" placeholder="Sınırsız" oninput="emlakYeniListeCiz()"></div></div>
    <div class="alan"><label>Sırala</label><select id="emlakSort" onchange="emlakYeniListeCiz()">
    <option value="son">En yeni ilan</option><option value="ucuz">En ucuz</option><option value="pahali">En pahalı</option><option value="kira">En yüksek kira</option></select></div>
 </div><div id="emlakYeniListe"></div>`,{geri:true});
 emlakYeniListeCiz();
}
function emlakYeniListeCiz(){
 const el=$("#emlakYeniListe");if(!el)return;
 const t=$("#emlakTip").value,max=Number($("#emlakMax").value||0),sort=$("#emlakSort").value;
 let l=emlakIlanlar.filter(x=>(!t||x.tip===t)&&(!max||x.fiyat<=max));
 l.sort((a,b)=>sort==="ucuz"?a.fiyat-b.fiyat:sort==="pahali"?b.fiyat-a.fiyat:sort==="kira"?b.haftalik-a.haftalik:b.id-a.id);
 el.innerHTML=l.map(x=>`<div class="kart vit-emlak"><div class="vit-bas">
  <span class="vit-logo">${x.tip==="daire"?"🏢":x.tip==="dukkan"?"🏪":"🏡"}</span><span class="orta">
  <b>${e(emlakAd[x.tip]||x.tip)} #${x.mulk_id}</b><span class="kucuk">📍 ${e(x.il)} · Sahibi: ${e(x.satici)}</span></span><span class="rozet ${x.benim?"yesil":"altin"}">${x.benim?"Benim":"Satılık"}</span></div>
  <div class="vit-emlak-fiyat">${emlakTL(x.fiyat)}</div>
  <div class="kv"><span>Haftalık kira</span><b>${emlakTL(x.haftalik)}</b></div>
  <button class="btn altin" onclick="emlakYeniDetay(${x.id})">İlanı incele / ${x.benim?"yönet":"pazarlık yap"}</button></div>`).join("")||'<div class="kart">Aradığın özelliklerde ilan yok.</div>';
}
function emlakYeniDetay(id){
 const x=emlakIlanlar.find(y=>y.id===id);if(!x){emlakYeniEkrani();return;}
 iskelet("Emlak ilanı",`<div class="kart vit-manset">
 <h2>${x.tip==="daire"?"🏢":x.tip==="dukkan"?"🏪":"🏡"} ${e(emlakAd[x.tip]||x.tip)} #${x.mulk_id}</h2>
 <p class="alt">📍 ${e(x.il)} · Satıcı: ${e(x.satici)}</p><div class="vit-emlak-fiyat">${emlakTL(x.fiyat)}</div>
 <div class="kv"><span>Haftalık kira geliri</span><b>${emlakTL(x.haftalik)}</b></div>
 <p class="kucuk">İlan fiyatı kirayı artırmaz. Satış tamamlanırsa %2 vergi satış bedelinden kesilir.</p>
 ${x.benim?`<button class="btn ikinci" onclick="emlakIlanIptal(${x.id})">İlanımı kaldır</button>`:
  `<button class="btn altin" onclick="emlakIlanAl(${x.id},${Number(x.fiyat)})">İlan fiyatından satın al</button>
    <button class="btn ikinci" onclick="emlakYeniTeklifModal(${x.id})">Satıcıyla pazarlık yap</button>`}
 </div><button class="btn ikinci" onclick="emlakYeniEkrani()">Diğer ilanlara dön</button>`,{geri:true});
}
function emlakYeniTeklifModal(id){
 const x=emlakIlanlar.find(y=>y.id===id);if(!x)return;
 const m=modal(`<h3>Satıcıya teklif gönder</h3><p class="alt">${e(x.satici)} · ${e(emlakAd[x.tip]||x.tip)} #${x.mulk_id}</p>
 <div class="kv"><span>İlan fiyatı</span><b>${emlakTL(x.fiyat)}</b></div>
 <div class="alan"><label>Teklif ettiğin fiyat</label><input id="emTeklif" type="number" min="10000" step="1000" value="${Math.max(10000,Math.round(x.fiyat*.9))}"></div>
 <p class="alt">Teklif göndermek para kesmez. Satıcının kabulüyle satış tamamlanır; satıcı karşı fiyat da önerebilir.</p>
 <button class="btn altin" id="emTeklifBtn">Satıcıya teklif gönder</button>`);
 $("#emTeklifBtn",m).onclick=async()=>{
  const b=$("#emTeklifBtn",m),f=Number($("#emTeklif",m).value);
  if(!Number.isSafeInteger(f)||f<10000||f>1e9){toast("Geçerli teklif gir.",true);return;}
  b.disabled=true;try{await API.rpc("emlak_pazarlik_teklif",{p_ilan:id,p_fiyat:f});modalKapat();toast("Teklif satıcıya bildirildi.");}
  catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
 };
}
async function emlakPazarliklarimEkrani(){
 yukleniyor("Emlak pazarlıkları");
 try{
 const l=await API.rpc("emlak_pazarliklarim");
 iskelet("Emlak pazarlıklarım",`<div class="kart"><h2>Gelen / gönderilen teklifler</h2><p class="alt">Satıcı teklifi kabul edebilir, reddedebilir veya karşı fiyat verebilir. Para ve tapu yalnızca anlaşma tamamlandığında aktarılır.</p></div>
 ${l.map(x=>`<div class="kart"><h3>${e(emlakAd[x.tip]||x.tip)} #${x.mulk_id} · ${e(x.il)}</h3>
 <p class="alt">${x.ben_saticiyim?"Alıcı: "+e(x.alici):"Satıcı: "+e(x.satici)}</p>
 <div class="kv"><span>İlk teklif</span><b>${emlakTL(x.teklif)}</b></div>
 ${x.karsi_teklif!=null?`<div class="kv"><span>Karşı fiyat</span><b>${emlakTL(x.karsi_teklif)}</b></div>`:""}
 <div class="kv"><span>Durum</span><b>${e({bekliyor:"Yanıt bekliyor",karsi:"Karşı teklif",kabul:"Satış tamamlandı",red:"Reddedildi",iptal:"İlan kapandı"}[x.durum]||x.durum)}</b></div>
 ${x.ben_saticiyim&&x.durum==="bekliyor"&&x.ilan_acik?`<div class="vit-dugme"><button class="btn altin" onclick="emSaticiYanit(${x.id},'kabul')">Kabul et</button><button class="btn ikinci" onclick="emSaticiYanit(${x.id},'red')">Reddet</button></div><button class="btn ikinci" onclick="emKarsiModal(${x.id},${x.teklif})">Karşı fiyat ver</button>`:""}
 ${x.ben_aliciyim&&x.durum==="karsi"&&x.ilan_acik?`<div class="vit-dugme"><button class="btn altin" onclick="emAliciYanit(${x.id},true)">Karşı fiyatı kabul et</button><button class="btn ikinci" onclick="emAliciYanit(${x.id},false)">Reddet</button></div>`:""}
 </div>`).join("")||'<div class="kart">Henüz bir pazarlık teklifi yok.</div>'}
 <button class="btn ikinci" onclick="emlakYeniEkrani()">Satılık ilanlara git</button>`,{geri:true});
 }catch(err){iskelet("Emlak pazarlıklarım",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
async function emSaticiYanit(id,karar){
 if(karar==="kabul"&&!await onayla("Satış teklifini kabul et","Teklif bedeliyle mülk el değiştirecek. İşlem geri alınamaz.","Satışı onayla"))return;
 try{await API.rpc("emlak_pazarlik_satici_yanit",{p_teklif:id,p_karar:karar,p_karsi:null});
 toast(karar==="kabul"?"Mülkün satıldı.":"Teklif reddedildi.");emlakPazarliklarimEkrani();}
 catch(err){toast(hataCevir(err.message),true);}
}
function emKarsiModal(id,onceki){
 const m=modal(`<h3>Karşı teklif gönder</h3><p class="alt">Alıcının fiyatı: ${emlakTL(onceki)}</p>
 <div class="alan"><label>Karşı satış bedeli</label><input id="emKarsi" type="number" min="10000" value="${Math.max(10000,Math.round(onceki*1.1))}"></div>
 <button class="btn altin" id="emKarsiBtn">Alıcıya bildir</button>`);
 $("#emKarsiBtn",m).onclick=async()=>{
 const b=$("#emKarsiBtn",m),f=Number($("#emKarsi",m).value);
 if(!Number.isSafeInteger(f)||f<10000||f>1e9){toast("Geçerli fiyat gir.",true);return;}
 b.disabled=true;try{await API.rpc("emlak_pazarlik_satici_yanit",{p_teklif:id,p_karar:"karsi",p_karsi:f});
 modalKapat();toast("Karşı teklif bildirildi.");emlakPazarliklarimEkrani();}
 catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
 };
}
async function emAliciYanit(id,onay){
 if(onay&&!await onayla("Karşı fiyatı kabul et","Bu bedeli ödeyerek mülkü satın alacaksın.","Satın al"))return;
 try{await API.rpc("emlak_pazarlik_alici_yanit",{p_teklif:id,p_kabul:onay});
 toast(onay?"Mülk satın alındı.":"Teklif reddedildi.");emlakPazarliklarimEkrani();}
 catch(err){toast(hataCevir(err.message),true);}
}
window.emlakPazarEkrani=emlakYeniEkrani;
window.emlakPazarCiz=emlakYeniCiz;
