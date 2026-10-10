/* Seçim Online — vatandaş etkileşimi: röportaj, düello, imza, dilekçe, dernek demokrasisi */
const SOS_BASLIK={roportaj:"Röportajlar",haber:"Basın cevap hakkı",duello:"Siyasi düellolar",imza:"İmza kampanyaları",dilekce:"Resmî dilekçeler"};
const SOS_DURUM={bekliyor:"Yanıt bekliyor",yanitlandi:"Yanıtlandı",reddedildi:"Reddedildi",yayinlandi:"Yayımlandı",davet:"Davet gönderildi",canli:"Canlı tartışma",oylama:"Halk oylaması",bitti:"Tamamlandı",acik:"İmzaya açık",basarili:"Hedefe ulaştı",sure_doldu:"Süresi doldu",kabul:"Kabul edildi",ret:"Reddedildi",islemde:"İşlemde"};
function sosDurum(s){return SOS_DURUM[s]||s||""}
function sosMetin(x){return '<p style="white-space:pre-wrap;margin:8px 0">'+e(x||"")+'</p>'}
function sosCardBas(s){return '<div class="kart"><h3>'+e(s)+'</h3>'}
async function sosRpc(ad,arg,sonra,basari){
 try{await API.rpc(ad,arg);modalKapat();toast(basari||"İşlem kaydedildi.");if(sonra)await sonra();}
 catch(err){toast(hataCevir(err.message),true);}
}
function sosMenu(aktif){
 return '<div class="kart"><h2>Vatandaş ve siyaset</h2><p class="alt">Gerçek oyuncuların röportajları, tartışmaları, imzaları ve resmî başvuruları.</p><div class="vit-dugme">'+
 Object.entries(SOS_BASLIK).map(([k,v])=>'<button class="btn '+(aktif===k?'altin':'ikinci')+'" onclick="sosEkran(\''+k+'\')">'+e(v)+'</button>').join("")+'</div></div>';
}
async function sosEkran(k){
 k=SOS_BASLIK[k]?k:"imza";
 yukleniyor(SOS_BASLIK[k]);
 try{
  let data=await API.rpc(({roportaj:"sos_roportajlar",haber:"sos_haberler",duello:"sos_duellolar",imza:"sos_imza_kampanyalari",dilekce:"sos_dilekceler"})[k]);
  let h=sosMenu(k);
  if(k==="roportaj"){
   h+='<div class="kart"><h2>Gazetecilerin röportajları</h2><p class="alt">Gazete sahibi veya kayıtlı köşe yazarı soru gönderebilir. Konuk yanıtlayabilir veya reddedebilir; gazeteci sonucu yayımlar.</p><button class="btn altin" onclick="sosRopDavetModal()">Röportaj daveti gönder</button></div>';
   for(const r of data){
    h+=sosCardBas(r.baslik)+'<div class="kucuk">'+e(r.gazete)+' · '+e(r.gazeteci)+' → '+e(r.konuk)+' · '+e(sosDurum(r.durum))+'</div>'+sosMetin("Soru: "+r.soru)+(r.yanit?sosMetin("Yanıt: "+r.yanit):"")+
      (r.cevaplayabilirim?'<div class="satir"><button class="btn yarim altin" onclick="sosRopYanitModal('+r.id+')">Yanıtla</button><button class="btn yarim ikinci" onclick="sosRpc(\'sos_roportaj_yanit\',{p_id:'+r.id+',p_kabul:false,p_yanit:null},()=>sosEkran(\'roportaj\'),\'Davet reddedildi.\')">Reddet</button></div>':"")+
      (r.yayinlayabilirim?'<button class="btn altin" onclick="sosRpc(\'sos_roportaj_yayinla\',{p_id:'+r.id+'},()=>sosEkran(\'roportaj\'),\'Röportaj gazetede yayımlandı.\')">Gazetemde yayımla</button>':"")+'</div>';
   }
   if(!data.length)h+='<div class="kart">Henüz röportaj yok.</div>';
  }
  if(k==="haber"){
   h+='<div class="kart"><h2>Haberlerde cevap hakkı</h2><p class="alt">Gazeteci haberin muhatabını işaretler. Hakkında haber yapılan oyuncu aynı haber altında yalnız bir kez resmî cevap yayımlayabilir.</p></div>';
   for(const a of data){
    h+=sosCardBas(a.baslik)+'<div class="kucuk">'+e(a.gazete)+' · '+e(a.yazar)+' · '+tarihSaat(a.zaman)+'</div>'+sosMetin(a.metin)+(a.hedef?'<p class="kucuk">Haber muhatabı: '+e(a.hedef)+'</p>':"")+
     (a.cevap?'<div class="olay"><b>'+e(a.hedef)+' · resmî cevap</b>'+sosMetin(a.cevap)+'</div>':"")+
     (a.etiketleyebilirim?'<button class="btn ikinci" onclick="sosHaberHedefModal('+a.id+')">Haberin muhatabını belirle</button>':"")+
     (a.cevaplayabilirim?'<button class="btn altin" onclick="sosHaberCevapModal('+a.id+')">Resmî cevap hakkımı kullan</button>':"")+'</div>';
   }
   if(!data.length)h+='<div class="kart">Henüz oyuncu gazetesinde haber yok.</div>';
  }
  if(k==="duello"){
   h+='<div class="kart"><h2>Canlı siyasi tartışmalar</h2><p class="alt">Parti başkanı, aday veya görevdeki siyasetçi davet gönderebilir. Kabul edilince sırayla üçer söz hakkı vardır. Ardından diğer oyuncular 24 saat oy verir.</p><button class="btn altin" onclick="sosDuelloDavetModal()">Tartışmaya davet et</button></div>';
   for(const d of data){
    const uc=d.davet_eden,ik=d.davet_edilen;
    h+=sosCardBas(d.baslik)+'<div class="kucuk">'+e(d.birinci)+' ↔ '+e(d.ikinci)+' · '+e(sosDurum(d.durum))+'</div>'+
      (d.durum==="canli"?'<p class="alt">'+d.tur_sayisi+'/6 konuşma yapıldı.</p>':"")+
      (d.sozler||[]).map(s=>'<div class="olay" style="margin-top:8px"><b>'+e(s.kad)+' · '+s.tur+'. söz</b>'+sosMetin(s.metin)+'</div>').join("")+
      (d.davet_bende?'<div class="satir"><button class="btn yarim altin" onclick="sosRpc(\'sos_duello_yanit\',{p_id:'+d.id+',p_kabul:true},()=>sosEkran(\'duello\'),\'Tartışma başladı.\')">Kabul et</button><button class="btn yarim ikinci" onclick="sosRpc(\'sos_duello_yanit\',{p_id:'+d.id+',p_kabul:false},()=>sosEkran(\'duello\'),\'Davet reddedildi.\')">Reddet</button></div>':"")+
      (d.sira_bende?'<button class="btn altin" onclick="sosDuelloKonusModal('+d.id+')">Söz sırası sende · Konuş</button>':"")+
      (d.durum==="oylama"?'<p class="kucuk">Halk oylaması: '+tarihSaat(d.oylama_bas)+' başlangıç, 24 saat açık.</p>'+(!d.benim_oyum?'<div class="satir"><button class="btn yarim ikinci" onclick="sosDuelloOy('+d.id+',\''+uc+'\')">'+e(d.birinci)+'</button><button class="btn yarim ikinci" onclick="sosDuelloOy('+d.id+',\''+ik+'\')">'+e(d.ikinci)+'</button></div>':'<p class="alt">Oyun kaydedildi.</p>'):"")+
      (d.durum==="bitti"?'<div class="rozet">Sonuç: '+e(d.birinci)+' '+d.oy_bir+' — '+d.oy_iki+' '+e(d.ikinci)+'</div>':"")+'</div>';
   }
   if(!data.length)h+='<div class="kart">Henüz siyasi tartışma yok.</div>';
  }
  if(k==="imza"){
   h+='<div class="kart"><h2>Vatandaş imza kampanyaları</h2><p class="alt">Hedef imza sayısı tamamlanınca konu otomatik olarak ilgili makamın resmî dilekçesine dönüşür. Süre 72 saat.</p><button class="btn altin" onclick="sosBasvuruModal(\'imza\')">İmza kampanyası başlat</button></div>';
   for(const a of data){
    h+=sosCardBas(a.baslik)+'<div class="kucuk">'+e(a.acan)+' · Muhatap: '+e(a.muhatap)+' · '+e(sosDurum(a.durum))+'</div>'+sosMetin(a.metin)+
      '<p class="kucuk">'+a.imza+' / '+a.esik+' imza · '+tarihSaat(a.bit)+' bitiş</p>'+
      (a.durum==="acik"&&!a.imzaladim?'<button class="btn altin" onclick="sosRpc(\'sos_imza_at\',{p_id:'+a.id+'},()=>sosEkran(\'imza\'),\'İmzan kaydedildi.\')">İmzala</button>':"")+
      (a.imzaladim?'<span class="rozet yesil">İmzaladın</span>':"")+
      (a.dilekce_id?'<button class="btn ikinci" onclick="sosEkran(\'dilekce\')">Resmî dilekçeyi gör</button>':"")+'</div>';
   }
   if(!data.length)h+='<div class="kart">Henüz imza kampanyası yok.</div>';
  }
  if(k==="dilekce"){
   h+='<div class="kart"><h2>Vatandaş dilekçeleri</h2><p class="alt">Cumhurbaşkanına, belediye başkanına veya milletvekiline açık dilekçe gönder. Yetkili işlemi başlatabilir, kabul edebilir veya reddedebilir. Her yanıt herkese açıktır.</p><button class="btn altin" onclick="sosBasvuruModal(\'dilekce\')">Yeni dilekçe gönder</button></div>';
   for(const a of data){
    h+=sosCardBas(a.baslik)+'<div class="kucuk">'+e(a.gonderen)+' → '+e(a.muhatap)+' · '+e(sosDurum(a.durum))+'</div>'+sosMetin(a.metin)+
      (a.cevap?'<div class="olay"><b>Resmî yanıt · '+e(sosDurum(a.durum))+'</b>'+sosMetin(a.cevap)+'</div>':"")+
      (a.cevaplayabilirim?'<button class="btn altin" onclick="sosDilekceYanitModal('+a.id+')">Makam adına cevap ver</button>':"")+'</div>';
   }
   if(!data.length)h+='<div class="kart">Henüz dilekçe yok.</div>';
  }
  iskelet(SOS_BASLIK[k],h,{geri:D.yigin.length>0});
 }catch(err){iskelet(SOS_BASLIK[k],sosMenu(k)+'<div class="kart"><p>'+e(hataCevir(err.message))+'</p></div>',{geri:D.yigin.length>0});}
}
function sosBasitModal(baslik,metinEtiket,onay,fn,min=10,max=3000){
 const m=modal('<h3>'+e(baslik)+'</h3><div class="alan"><label>'+e(metinEtiket)+'</label><textarea id="sosMet" class="alanmetin" minlength="'+min+'" maxlength="'+max+'" rows="5"></textarea></div><button class="btn altin" id="sosOK">'+e(onay)+'</button>');
 $('#sosOK',m).onclick=async()=>{const b=$('#sosOK',m);b.disabled=true;try{await fn($('#sosMet',m).value);modalKapat();}catch(err){toast(hataCevir(err.message),true);b.disabled=false;}};
}
function sosBasvuruModal(tur){
 const il=(window.VERI?.iller||[]).map(x=>'<option value="'+x.id+'">'+e(x.ad)+'</option>').join('');
 const m=modal('<h3>'+e(tur==="imza"?"İmza kampanyası aç":"Resmî dilekçe yaz")+'</h3><div class="alan"><label>İlgili makam</label><select id="sosMakam"><option value="cb">Cumhurbaşkanı</option><option value="bel">Belediye başkanı</option><option value="mv">Milletvekili</option></select></div>'+
 '<div class="alan" id="sosIlKut" style="display:none"><label>Belediye ili</label><select id="sosIl">'+il+'</select></div><div class="alan" id="sosKadKut" style="display:none"><label>Milletvekilinin kullanıcı adı</label><input id="sosKad" maxlength="30"></div>'+
 '<div class="alan"><label>Konu başlığı</label><input id="sosBaslik" maxlength="120" placeholder="Örneğin: Muğla’da ulaşım desteği"></div>'+
 '<div class="alan"><label>Talep metni</label><textarea id="sosAciklama" class="alanmetin" maxlength="3000" rows="5"></textarea></div>'+
 '<button class="btn altin" id="sosOK">'+(tur==="imza"?"Kampanyayı başlat":"Dilekçeyi gönder")+'</button>');
 const upd=()=>{$('#sosIlKut',m).style.display=$('#sosMakam',m).value==="bel"?"block":"none";$('#sosKadKut',m).style.display=$('#sosMakam',m).value==="mv"?"block":"none"};
 $('#sosMakam',m).onchange=upd;upd();
 $('#sosOK',m).onclick=async()=>{
  const b=$('#sosOK',m);b.disabled=true;
  try{await API.rpc(tur==="imza"?"sos_imza_baslat":"sos_dilekce_gonder",{
   p_makam:$('#sosMakam',m).value,p_il:$('#sosMakam',m).value==="bel"?Number($('#sosIl',m).value):null,
   p_kad:$('#sosKad',m).value.trim(),p_baslik:$('#sosBaslik',m).value.trim(),p_metin:$('#sosAciklama',m).value.trim()});
   modalKapat();toast(tur==="imza"?"Kampanya açıldı.":"Dilekçe gönderildi.");sosEkran(tur);
  }catch(err){toast(hataCevir(err.message),true);b.disabled=false;}
 };
}
async function sosRopDavetModal(){
 let b;try{b=await API.rpc('basin')}catch(err){return toast(hataCevir(err.message),true)}
 const g=[];if(b.benim)g.push(b.benim);for(const x of b.gazeteler||[])if(x.yaziyim&&!g.some(z=>z.id===x.id))g.push(x);
 if(!g.length)return toast("Röportaj göndermek için gazeten veya kabul edilmiş gazeteci görevin olmalı.",true);
 const m=modal('<h3>Röportaj daveti gönder</h3><div class="alan"><label>Gazete</label><select id="sosGazete">'+g.map(x=>'<option value="'+x.id+'">'+e(x.ad)+'</option>').join('')+'</select></div>'+
 '<div class="alan"><label>Konuk kullanıcı adı</label><input id="sosKonuk" maxlength="30"></div>'+
 '<div class="alan"><label>Röportaj başlığı</label><input id="sosBaslik" maxlength="120"></div>'+
 '<div class="alan"><label>Soru</label><textarea class="alanmetin" id="sosSoru" maxlength="3000"></textarea></div><button class="btn altin" id="sosOK">Daveti gönder</button>');
 $('#sosOK',m).onclick=async()=>{const btn=$('#sosOK',m);btn.disabled=true;try{
 await API.rpc("sos_roportaj_davet",{p_gazete:Number($('#sosGazete',m).value),p_kad:$('#sosKonuk',m).value.trim(),p_baslik:$('#sosBaslik',m).value.trim(),p_soru:$('#sosSoru',m).value.trim()});
 modalKapat();toast("Röportaj daveti gönderildi.");sosEkran("roportaj");
 }catch(err){toast(hataCevir(err.message),true);btn.disabled=false;}};
}
function sosRopYanitModal(id){sosBasitModal("Röportajı yanıtla","Yanıtın","Yanıtla ve gazeteciye gönder",async m=>{await API.rpc("sos_roportaj_yanit",{p_id:id,p_kabul:true,p_yanit:m});sosEkran("roportaj");});}
function sosHaberHedefModal(id){const m=modal('<h3>Habere muhatap ekle</h3><p class="alt">Haberde hakkında yazdığın oyuncuyu belirt. Oyuncu yalnız bir kez cevap yayımlayabilir.</p><div class="alan"><label>Kullanıcı adı</label><input id="sosKad" maxlength="30"></div><button class="btn altin" id="sosOK">Muhatabı belirle</button>');$('#sosOK',m).onclick=async()=>{const b=$('#sosOK',m);b.disabled=true;try{await API.rpc("sos_haber_hedefle",{p_yayin:id,p_kad:$('#sosKad',m).value.trim()});modalKapat();toast("Haberin muhatabı eklendi.");sosEkran("haber");}catch(err){toast(hataCevir(err.message),true);b.disabled=false;}};}
function sosHaberCevapModal(id){sosBasitModal("Resmî cevap hakkı","Habere bir defalık cevabın","Cevabı yayımla",async m=>{await API.rpc("sos_haber_cevapla",{p_yayin:id,p_metin:m});sosEkran("haber");});}
function sosDuelloDavetModal(){const m=modal('<h3>Siyasi düelloya davet et</h3><p class="alt">Parti genel başkanı, aday veya görevdeki siyasetçi olmalısın.</p><div class="alan"><label>Rakip kullanıcı adı</label><input id="sosKad" maxlength="30"></div><div class="alan"><label>Tartışma konusu</label><input id="sosBaslik" maxlength="120"></div><button class="btn altin" id="sosOK">Davet gönder</button>');$('#sosOK',m).onclick=async()=>{const b=$('#sosOK',m);b.disabled=true;try{await API.rpc("sos_duello_davet",{p_kad:$('#sosKad',m).value.trim(),p_baslik:$('#sosBaslik',m).value.trim()});modalKapat();toast("Tartışma daveti gönderildi.");sosEkran("duello");}catch(err){toast(hataCevir(err.message),true);b.disabled=false;}};}
function sosDuelloKonusModal(id){sosBasitModal("Söz sırası sende","Tartışmadaki konuşman","Konuşmayı yayımla",async m=>{await API.rpc("sos_duello_konus",{p_id:id,p_metin:m});sosEkran("duello");},10,2000);}
async function sosDuelloOy(id,user){try{await API.rpc("sos_duello_oyla",{p_id:id,p_aday:user});toast("Oyun kaydedildi.");sosEkran("duello");}catch(err){toast(hataCevir(err.message),true);}}
function sosDilekceYanitModal(id){const m=modal('<h3>Resmî dilekçe yanıtı</h3><div class="alan"><label>İşlem durumu</label><select id="sosDurum"><option value="islemde">İşleme alındı</option><option value="kabul">Kabul edildi</option><option value="ret">Reddedildi</option></select></div><div class="alan"><label>Gerekçeli cevap</label><textarea class="alanmetin" id="sosMet" maxlength="3000"></textarea></div><button class="btn altin" id="sosOK">Yanıtı yayımla</button>');$('#sosOK',m).onclick=async()=>{const b=$('#sosOK',m);b.disabled=true;try{await API.rpc("sos_dilekce_yanit",{p_id:id,p_durum:$('#sosDurum',m).value,p_cevap:$('#sosMet',m).value});modalKapat();toast("Resmî yanıt kaydedildi.");sosEkran("dilekce");}catch(err){toast(hataCevir(err.message),true);b.disabled=false;}};}
async function sosDernekPanel(id){
 yukleniyor("Dernek genel kurulu");
 try{
 const d=await API.rpc("sos_dernek_durum",{p_dernek:id}),s=d.secim;
 let h='<div class="kart"><h2>Demokratik dernek yönetimi</h2><p class="alt">Her 30 günde olağan genel kurul; üyelerin en az üçte birinin (en az 2 üye) imzasıyla olağanüstü genel kurul. Başkan ve dört yönetim üyesi seçilir. Yeni üyeler açık seçimde oy kullanamaz.</p><p>Üye sayısı: '+d.uye_sayisi+' · İmza eşiği: '+d.esik+'</p>'+
 (d.rolum==="baskan"&&(!s||s.durum==="bitti")?'<button class="btn altin" onclick="sosDernekIslem(\'sos_dernek_secim_ac\',{p_dernek:'+id+'},'+id+')">Genel kurul başlat</button>':"")+
 (d.rolum&&(!s||s.durum==="bitti")?'<button class="btn ikinci" onclick="sosDernekIslem(\'sos_dernek_imza\',{p_dernek:'+id+'},'+id+')">'+(d.talep&&d.talep.imzaladim?"Talebi imzaladın":"Olağanüstü genel kurul için imza ver")+'</button>':"")+
 (d.talep?'<div class="kucuk">Olağanüstü genel kurul talebi: '+d.talep.imza+'/'+d.esik+' imza · '+tarihSaat(d.talep.bit)+' bitiş</div>':"")+'</div>';
 if(s){
 h+='<div class="kart"><h2>Genel kurul · '+e(sosDurum(s.durum==="acik"?"acik":"bitti"))+'</h2>'+
 '<div class="kucuk">Adaylık bitiş: '+tarihSaat(s.aday_bit)+' · Sandık kapanış: '+tarihSaat(s.oy_bit)+'</div>'+
 (s.durum==="acik"&&d.rolum&&Date.now()<new Date(s.aday_bit).getTime()?
 '<div class="satir"><button class="btn yarim ikinci" onclick="sosDernekIslem(\'sos_dernek_aday\',{p_secim:'+s.id+',p_gorev:\'baskan\'},'+id+')">Başkan adayı ol</button><button class="btn yarim ikinci" onclick="sosDernekIslem(\'sos_dernek_aday\',{p_secim:'+s.id+',p_gorev:\'yonetim\'},'+id+')">Yönetim adayı ol</button></div>':"");
 for(const tur of ['baskan','yonetim']){
  h+='<h3 style="margin:12px 0 6px">'+(tur==="baskan"?"Başkan adayları":"Yönetim kurulu adayları")+'</h3>';
  const adaylar=(s.adaylar||[]).filter(a=>a.gorev===tur);
  for(const a of adaylar){
   h+='<div class="liste-satir"><div class="orta"><b>'+e(a.kad)+'</b>'+(s.durum==="bitti"?'<div class="kucuk">'+a.oy+' oy</div>':'')+'</div>'+
    (s.durum==="acik"&&d.rolum&&s.oy_hakkim&&Date.now()>=new Date(s.aday_bit).getTime()&&Date.now()<new Date(s.oy_bit).getTime()?
    '<button class="btn ikinci" onclick="sosDernekIslem(\'sos_dernek_oyla\',{p_secim:'+s.id+',p_gorev:\''+tur+'\',p_aday:\''+a.user_id+'\'},'+id+')">Oy ver</button>':'')+'</div>';
  }
  if(!adaylar.length)h+='<p class="alt">Henüz aday yok.</p>';
 }
 h+='</div>';
 }
 iskelet("Dernek genel kurulu",h,{geri:true});
 }catch(err){iskelet("Dernek genel kurulu",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
async function sosDernekIslem(ad,args,id){try{await API.rpc(ad,args);toast("İşlem kaydedildi.");sosDernekPanel(id);}catch(err){toast(hataCevir(err.message),true);}}
async function sosPartiPanel(id){
 yukleniyor("Olağanüstü kurultay imzaları");
 try{
 const d=await API.rpc("sos_parti_imza_durum",{p_parti:id}),k=d.kampanya;
 const h='<div class="kart"><h2>Parti içi demokrasi</h2><p class="alt">Parti üyelerinin en az üçte biri (en az iki üye) imza verirse mevcut seçim motorunda olağanüstü kurultay açılır. Genel başkanlık için üyeler aday olup oy verir.</p>'+
 '<p>Parti üyeleri: '+d.uye_sayisi+' · Gerekli imza: '+d.esik+'</p>'+
 (k?'<div class="olay"><b>'+e(sosDurum(k.durum))+'</b><p>'+k.imza+' / '+d.esik+' imza</p><p class="kucuk">'+tarihSaat(k.bit)+' bitiş</p>'+(k.secim_id?'<p class="kucuk">Kurultay seçimi #'+k.secim_id+'</p>':'')+'</div>':'')+
 (d.uyeyim&&(!k||k.durum==="sure_doldu"||(k.durum==="acik"&&!k.imzaladim))?
 '<button class="btn altin" onclick="sosPartiImzala('+id+')">'+(k&&k.durum==="acik"?"İmza ver":"Olağanüstü kurultay için imza kampanyası başlat")+'</button>':"")+
 (k&&k.durum==="acik"&&k.imzaladim?'<span class="rozet yesil">İmzaladın</span>':"")+
 '</div>';
 iskelet("Olağanüstü kurultay",h,{geri:true});
 }catch(err){iskelet("Olağanüstü kurultay",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
async function sosPartiImzala(id){try{await API.rpc('sos_parti_imzala',{p_parti:id});toast("İmzan kaydedildi.");sosPartiPanel(id);}catch(err){toast(hataCevir(err.message),true);}}
(function sosMenuBagla(){
 const ilave=(html)=>{const n=document.getElementById('icerik');if(n&&!n.querySelector('.sos-menu-karti'))n.insertAdjacentHTML('beforeend','<div class="sos-menu-karti">'+html+'</div>');};
 if(typeof gundemEkrani==="function"){const old=gundemEkrani;window.gundemEkrani=async function(...a){const r=await old.apply(this,a);ilave('<div class="kart"><h2>Toplum ve siyaset</h2><p class="alt">Canlı siyasi düellolara katıl, imza kampanyası aç, dilekçe gönder, gazetecilerle röportaj yap.</p><button class="btn altin" onclick="ekranAc(()=>sosEkran(\'imza\'))">Vatandaş etkileşimleri</button></div>');return r;};}
 if(typeof basinEkrani==="function"){const old=basinEkrani;window.basinEkrani=async function(...a){const r=await old.apply(this,a);ilave('<div class="kart"><h2>Röportaj ve cevap hakkı</h2><div class="vit-dugme"><button class="btn altin" onclick="ekranAc(()=>sosEkran(\'roportaj\'))">Röportajlar</button><button class="btn ikinci" onclick="ekranAc(()=>sosEkran(\'haber\'))">Cevap hakkı</button></div></div>');return r;};}
 if(typeof partilerEkrani==="function"){const old=partilerEkrani;window.partilerEkrani=async function(...a){const r=await old.apply(this,a);ilave('<div class="kart"><h2>Siyasi mücadele</h2><div class="vit-dugme"><button class="btn altin" onclick="ekranAc(()=>sosEkran(\'duello\'))">Canlı tartışmalar</button><button class="btn ikinci" onclick="ekranAc(()=>sosEkran(\'imza\'))">İmza kampanyaları</button></div></div>');return r;};}
 if(typeof partiDetay==="function"){const old=partiDetay;window.partiDetay=async function(id,...a){const r=await old.call(this,id,...a);ilave('<div class="kart"><h2>Olağanüstü kurultay</h2><p class="alt">Üyeler imza toplayarak genel başkan seçimi talep edebilir.</p><button class="btn ikinci" onclick="ekranAc(()=>sosPartiPanel('+Number(id)+'))">Kurultay imza süreci</button></div>');return r;};}
 if(typeof stkDetay==="function"){const old=stkDetay;window.stkDetay=async function(id,...a){const r=await old.call(this,id,...a);ilave('<div class="kart"><h2>Dernek genel kurulu</h2><p class="alt">Üyeler başkanlık veya yönetim için aday olabilir, oy verebilir ve olağanüstü genel kurul isteyebilir.</p><button class="btn altin" onclick="ekranAc(()=>sosDernekPanel('+Number(id)+'))">Genel kurul ve seçimler</button></div>');return r;};}
 if(typeof devletEkrani==="function"){const old=devletEkrani;window.devletEkrani=async function(...a){const r=await old.apply(this,a);ilave('<div class="kart"><h2>Vatandaş başvuruları</h2><button class="btn ikinci" onclick="ekranAc(()=>sosEkran(\'dilekce\'))">Resmî dilekçeler</button></div>');return r;};}
  if(typeof EKRAN!=='undefined'){EKRAN.gundem=window.gundemEkrani;EKRAN.parti=window.partilerEkrani;EKRAN.devlet=window.devletEkrani;}
})();