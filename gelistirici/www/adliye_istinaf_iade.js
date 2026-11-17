/* 17.11.2026 · Hukuk reformu (istinaf bozması sonrası iade, kesin kararlar, istinaf yargılama gideri).
   Arka uç: sql/zz_20261117_hukuk_reformu.sql
   - İstinafta bozulup Yüksek Mahkemeye iade edilen dosyada "Beraat" seçeneği gösterilmez;
     tazminat dosyasında yalnız tutar belirlenir. Kural sunucuda da zorunludur (adliye_oy_ver).
   - Uyarı ve 1 saatlik susturma kesin karardır; istinaf düğmesi gösterilmez.
   - İstinaf ekranında reddedilme halinde ödenecek yargılama gideri açıkça yazılır. */
(function(){
 'use strict';
 if(window.SO_ADLIYE_ISTINAF_IADE_V1)return;
 window.SO_ADLIYE_ISTINAF_IADE_V1=true;

 const KESIN=['uyari','sustur_1s'];
 const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const tl=n=>(typeof tlYaz==='function'?tlYaz(n):Number(n||0).toLocaleString('tr-TR')+' ₺');
 const dava=id=>((typeof ADL!=='undefined'&&ADL.davalar)||[]).find(x=>Number(x.id)===Number(id))||null;
 const iadeMi=d=>!!(d&&d.bozma_iade&&d.durum==='acik');
 const tazminatIadesi=d=>iadeMi(d)&&d.tur==='tazminat'&&!!d.davali;
 // Sunucudaki oyun.istinaf_gider ile aynı kural: maktu 50.000 ₺; tazminatta tutarın %10'u (en az 50.000, en çok 150.000 ₺)
 function gider(d){
  if(!d||d.tur!=='tazminat')return 50000;
  const tutar=Number(d.karar==='tazminat'?d.tazminat_tutar:d.tazminat_talep)||0;
  return Math.min(150000,Math.max(50000,Math.round(tutar*0.10/1000)*1000));
 }

 // 1) Dosya etiketi
 const eskiEtiket=window.adlEtiket;
 if(typeof eskiEtiket==='function'){
  window.adlEtiket=function(d,ek){
   if(iadeMi(d))return 'İstinaftan iade · '+(d.tur==='tazminat'?'tutar belirlenecek':'yaptırım belirlenecek');
   if(d&&d.durum==='karar'&&d.bozma_iade&&d.karar!=='dusme'&&!d.af_at)return 'Kesinleşti (bozmaya uyma)';
   return eskiEtiket.apply(this,arguments);
  };
 }

 // 2) Yüksek Mahkeme oy penceresi: iade edilen dosyada beraat yok
 const eskiKarar=window.adlKararModal;
 if(typeof eskiKarar==='function'){
  window.adlKararModal=function(id){
   const d=dava(id);
   const sonuc=eskiKarar.apply(this,arguments);
   if(!iadeMi(d))return sonuc;
   const sec=document.getElementById('adlCeza');
   if(!sec)return sonuc;
   const taz=tazminatIadesi(d);
   Array.from(sec.options).forEach(o=>{
    if(o.value==='beraat'||(taz&&o.value!=='tazminat'))o.remove();
   });
   if(taz&&!sec.querySelector('option[value="tazminat"]')){
    sec.insertAdjacentHTML('beforeend','<option value="tazminat">Tazminata hükmet (tutarı kendin gir)</option>');
   }
   if(sec.options.length){sec.selectedIndex=0;sec.dispatchEvent(new Event('change',{bubbles:true}));}
   if(taz)sec.disabled=sec.options.length<=1;
   const kutu=sec.closest('.modal')||sec.parentElement;
   const bilgi='<div class="kart" style="border-left:4px solid var(--altin,#c9a227);margin:0 0 12px">'
    +'<b>İstinaftan iade edilen dosya</b>'
    +'<p class="alt" style="margin-top:6px">İstinaf jürisi ilk derece kararını bozdu. Bozmaya uymak zorunludur: '
    +(taz?'yalnız <b>tazminat tutarını</b> belirleyin (en fazla '+esc(tl(Math.min(1000000,Number(d.tazminat_talep||0))))+').'
         :'yalnız <b>yaptırımı</b> belirleyin.')
    +' Beraat verilemez. Süre içinde çoğunluk oluşmazsa '
    +(taz?'verilen tutarların ortancasına, hiç oy yoksa talebin dörtte birine':'verilen oyların en hafifine, hiç oy yoksa uyarıya')
    +' hükmedilir. Bu karar kesindir.</p></div>';
   const alan=sec.closest('.alan');
   if(alan)alan.insertAdjacentHTML('beforebegin',bilgi);else if(kutu)kutu.insertAdjacentHTML('afterbegin',bilgi);
   return sonuc;
  };
 }

 // 3) İstinaf bölümü: kesin kararlar ve gider bilgisi
 const eskiIst=window.adlIstinafHtml;
 if(typeof eskiIst==='function'){
  window.adlIstinafHtml=function(d,ek){
   if(d&&d.durum==='karar'&&!(ek&&ek.istinaf)&&(KESIN.includes(d.karar)||d.bozma_iade)&&d.karar!=='dusme'){
    return '<div class="kart"><h3>İstinaf</h3><p class="alt">'
     +(d.bozma_iade?'Bu karar istinaf bozmasına uyularak verildi; kesindir, yeniden istinafa gidilemez.'
                   :'Uyarı ve 1 saatlik susturma hafif yaptırımdır; bu kararlar kesindir, istinafa gidilemez.')
     +'</p></div>';
   }
   let h=eskiIst.apply(this,arguments);
   if(d&&d.durum==='karar'&&ek&&ek.kesin===false&&!ek.istinaf&&h){
    h=h.replace(/<\/div>\s*$/,'<p class="kucuk" style="margin-top:6px">Başvuru reddedilirse (karar onanırsa) kararı kaybeden tarafa '
     +esc(tl(gider(d)))+' istinaf yargılama gideri yüklenir. Karar bozulursa gider yoktur.</p></div>');
   }
   return h;
  };
 }

 // 4) İstinaf başvuru penceresi: güncel kurallar
 window.adlIstinafModal=function(id){
  const d=dava(id);
  const m=modal('<p class="alt">İstinafı kurayla seçilen 3 kişilik jüri inceler. Davanın taraflarının partilerinden ve taraflarla son 30 günde davalık olanlardan kimse seçilmez; jüri mümkün olduğunca farklı partilerden oluşur. '
   +'Asıl üye 8 saat oyuna girmezse ya da 12 saat içinde oy vermezse yerine yedek geçer. 3 üyeden 2’si aynı yönde oy verince karar çıkar.</p>'
   +'<div class="kart" style="border-left:4px solid var(--kirmizi,#c0392b);margin:8px 0"><b>İstinaf yargılama gideri: '+esc(tl(gider(d)))+'</b>'
   +'<p class="alt" style="margin-top:6px">Başvurun reddedilirse (karar onanırsa) bu tutar kararı kaybeden tarafa yüklenir (CMK m.325, HMK m.326). Karar bozulursa gider ödenmez.'
   +(d&&d.karar==='beraat'?' Beraat bozulursa dosya, yaptırım ya da tutar belirlenmek üzere Yüksek Mahkemeye döner; o karar kesindir.':'')+'</p></div>'
   +adlAlan('İtiraz gerekçen (20–4000)','adlIstGerekce','textarea')
   +'<button class="btn altin" id="adlIstGonder">İstinafa başvur</button>');
  adlFormBaslik(m,'İstinaf · Dava #'+id);
  m.querySelector('#adlIstGonder').onclick=async()=>{
   if(typeof onayla==='function'&&!await onayla('İstinafa başvur','Reddedilirse '+tl(gider(d))+' yargılama gideri ödenir.','Başvur',true))return;
   adlIslem(()=>API.rpc('adliye_istinaf',{p_dava:id,p_gerekce:m.querySelector('#adlIstGerekce').value}),'İstinaf başvurun alındı; jüri kurayla seçildi.',id);
  };
 };
})();
