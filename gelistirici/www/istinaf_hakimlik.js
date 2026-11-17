/* Istinaf Hakimligi 2.0 - Gonullu hukuk kariyeri, 3 kisilik heyet ve dosya kabul ekrani.
   Tum yetkiler sunucu RPC tarafindan denetlenir; bu modul para/makam/oy verisini yerel olarak degistirmez. */
(function(){
 "use strict";
 if(window.SO_ISTINAF_HAKIMLIK_V2)return;
 window.SO_ISTINAF_HAKIMLIK_V2=true;
 var sonDavetler="", hakimMi=false, suruyor=false, enSonKontrol=0;
 function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){
   return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];
 });}
 function bilgi(s,hata){if(typeof toast==='function')toast(String(s),!!hata);
   else if(hata)window.alert(String(s));}
 function hata(e){return (typeof hataCevir==='function')?hataCevir((e&&e.message)||String(e)):String((e&&e.message)||e);}
 function tarih(s){return s?new Date(s).toLocaleString('tr-TR'):'—';}
 function tus(kod,metin,style){return '<button type="button" class="btn '+(style||'ikinci')+'" onclick="'+kod+'">'+metin+'</button>';}
 function kadroBilgi(d){
  if(!d.hakim)return d.akademi_tamam
   ?'<p class="alt">Hukuk Akademisi sınavını ve iki uygulamalı dosyayı tamamlamışsın. Mesleğe başvurarak gönüllü istinaf hâkimi olabilirsin.</p>'
   :'<p class="alt">Başvuru için Hukuk Akademisi sınavı ve iki uygulamalı staj dosyası gerekli. Önce Adliye › Avukatlık eğitimi bölümünden tamamla.</p>';
  if(d.durum==='askida')return '<p class="alt">Hâkimliğin askıda. Yeni görevlendirme alamazsın.</p>';
  if(d.durum==='pasif')return '<p class="alt">Hâkimlik görevin pasif; yeniden başvurabilirsin.</p>';
  return '<p class="alt">Göreve '+(d.hazir?'hazırsın. Hazırlık süren '+tarih(d.hazir_son)+' tarihinde bitiyor.':'hazır değilsin. Müsait olduğunda hazır durumunu aç.')+'</p>';
 }
 window.istinafHakimlikEkrani=async function(){
  if(typeof yukleniyor==='function')yukleniyor('İstinaf Hâkimliği');
  try{
   var d=await API.rpc('istinaf_hakim_panel');
   hakimMi=!!(d.hakim&&d.durum==='aktif');
   var h='<div class="kart"><h2>⚖️ İstinaf Hâkimliği</h2>'+
    '<p class="alt">Bağımsız hukuk kariyeri. Dosyalar yalnızca göreve hazır gönüllü hâkimlere teklif edilir. Kabul etmeden ceza veya sorumluluk doğmaz.</p>'+
    '<p class="kucuk">Kadrodaki hâkim: '+esc(d.kadro)+' / '+esc(d.kontenjan)+
    ' · 3 hâkimli heyet · 10 dk kabul · 6 saat karar (+4 saat gerekçeli ek süre)</p>'+
    kadroBilgi(d);
   if(!d.hakim||d.durum==='pasif'){
    h+=d.akademi_tamam&&d.uygun?tus('istinafHakimBasvur()','Hâkimliğe başvur','altin')
     :'<p class="alt">Başvuru şartları: Hukuk Akademisi, tarafsızlık, aktif siyasi görevin ve avukatlık temsilinin bulunmaması.</p>';
   } else if(d.durum==='aktif'){
    h+=d.hazir?tus('istinafHakimHazir(false)','Müsait değilim')
      :tus('istinafHakimHazir(true)','Göreve hazırım','altin');
    h+=' '+tus('istinafHakimIstifa()','Hâkimlikten ayrıl','ikinci');
   }
   h+='</div><div class="kart"><h3>Bekleyen görev davetleri</h3>';
   var davetler=Array.isArray(d.davetler)?d.davetler:[];
   h+=davetler.map(function(x){
     var id=Number(x.id),dava=Number(x.dava_id);
     if(!Number.isSafeInteger(id)||!Number.isSafeInteger(dava))return '';
     return '<div class="liste-satir"><div class="orta"><b>Dosya #'+dava+'</b><p class="alt">Görevi kabul için son: '+esc(tarih(x.bit))+'</p>'+
      '<div class="vit-dugme">'+tus('istinafHakimDavetCevap('+id+',true)','Kabul et','altin')+
      tus('istinafHakimDavetCevap('+id+',false)','Müsait değilim')+
      tus('ekranAc(()=>adliyeDosya('+dava+'))','Dosyayı incele')+'</div></div></div>';
   }).join('')||'<p class="alt">Bekleyen görev davetin yok.</p>';
   h+='</div><div class="kart"><h3>Üzerimdeki dosyalar</h3>';
   var dosyalar=Array.isArray(d.dosyalar)?d.dosyalar:[];
   h+=dosyalar.map(function(x){
     var id=Number(x.dava_id);if(!Number.isSafeInteger(id))return '';
     return '<div class="liste-satir"><div class="orta"><b>Dosya #'+id+'</b>'+
      '<p class="alt">'+(x.durum==='karar'?'Heyet tamamlandı; gerekçeli karar süresi: '+esc(tarih(x.bit)):
      'Diğer hâkimlerin kabulü bekleniyor.')+(x.oy?' · Oy kullanıldı':'')+'</p>'+
      tus('ekranAc(()=>adliyeDosya('+id+'))','Dosyayı aç','altin')+'</div></div>';
   }).join('')||'<p class="alt">Açık istinaf dosyan yok.</p>';
   h+='</div><div class="kart"><p class="alt">Görevlendirilen hâkim tarafsız olmak zorundadır. Oy kullanmayan kişi yüzünden dava otomatik onanmaz; sistem uygun yedek hâkim arar.</p></div>';
   if(typeof iskelet==='function')iskelet('İstinaf Hâkimliği',h,{geri:true});
  }catch(e){if(typeof iskelet==='function')iskelet('İstinaf Hâkimliği',
   '<div class="kart"><h3>İşlem açılamadı</h3><p>'+esc(hata(e))+'</p></div>',{geri:true});}
 };
 window.istinafHakimBasvur=async function(){
  try{await API.rpc('istinaf_hakim_basvur');bilgi('İstinaf hâkimliği kadrosuna kabul edildin. Göreve hazır durumunu açabilirsin.');await window.istinafHakimlikEkrani();}
  catch(e){bilgi(hata(e),true);}
 };
 window.istinafHakimHazir=async function(hazir){
  try{await API.rpc('istinaf_hakim_hazir',{p_hazir:!!hazir});bilgi(hazir?'2 saat boyunca görev tekliflerine açıksın.':'Yeni dosya daveti almayacaksın.');await window.istinafHakimlikEkrani();}
  catch(e){bilgi(hata(e),true);}
 };
 window.istinafHakimDavetCevap=async function(id,kabul){
  try{var r=await API.rpc('istinaf_hakim_davet_cevap',{p_davet:id,p_kabul:!!kabul});
   bilgi(r&&r.tamam===false?String(r.neden||'Davetin süresi doldu.'):kabul?'Görevi kabul ettin. Heyet tamamlandığında karar süren başlayacak.':'Davet reddedildi.');
   await window.istinafHakimlikEkrani();}
  catch(e){bilgi(hata(e),true);}
 };
 window.istinafHakimIstifa=async function(){
  if(!window.confirm('İstinaf hâkimliği mesleğinden ayrılmak istiyor musun? Açık kabul edilmiş dosyalar tamamlanmalıdır.'))return;
  try{await API.rpc('istinaf_hakim_istifa');bilgi('İstinaf hâkimliğinden ayrıldın.');await window.istinafHakimlikEkrani();}
  catch(e){bilgi(hata(e),true);}
 };
 // Sadece kayitli hâkimleri 90 sn aralikla yokla; 3.000 normal oyuncuya poll maliyeti yukleme.
 async function yokla(ilk){
  if(suruyor||document.hidden||typeof API==='undefined'||typeof API.rpc!=='function')return;
  if(!ilk&&!hakimMi)return;
  if(!ilk&&Date.now()-enSonKontrol<85000)return;
  suruyor=true;enSonKontrol=Date.now();
  try{
   var d=await API.rpc('istinaf_hakim_panel');
   hakimMi=!!(d.hakim&&d.durum==='aktif');
   var davetler=Array.isArray(d.davetler)?d.davetler:[];
   var kimlik=davetler.map(function(v){return v.id;}).join(',');
   var top=document.querySelector('.ust');
   var b=document.getElementById('istinaf-hakim-uyari');
   if(davetler.length){
    if(!b&&top){b=document.createElement('button');b.id='istinaf-hakim-uyari';b.className='ikon';
      b.type='button';b.onclick=function(){if(typeof ekranAc==='function')ekranAc(istinafHakimlikEkrani);else istinafHakimlikEkrani();};top.appendChild(b);}
    if(b){b.textContent='⚖️'+davetler.length;b.title='Bekleyen istinaf hâkimi davetleri';}
    if(kimlik!==sonDavetler)bilgi('⚖️ İstinaf hâkimliği görev davetin var. Kabul için 10 dakika.');
   }else if(b){b.remove();}
   sonDavetler=kimlik;
  }catch(e){/* Ağ geçici kesintisi veya henüz migration yok; ana oyunu etkileme. */}
  finally{suruyor=false;}
 }
 window.addEventListener('focus',function(){yokla(false);});
 document.addEventListener('visibilitychange',function(){if(!document.hidden)yokla(false);});
 setTimeout(function(){yokla(true);},6500);
 setInterval(function(){yokla(false);},90000);
})();