(function(){
'use strict';
if(window.BANKA_YONETIM_V1)return;window.BANKA_YONETIM_V1=true;
var byStyle=document.getElementById('banka-yonetim-contrast');
if(!byStyle){
 byStyle=document.createElement('style');
 byStyle.id='banka-yonetim-contrast';
 byStyle.textContent=[
  '.by-ui .by-ayar{display:grid;gap:16px;max-width:560px;}',
  '.by-ui .by-note{margin:0 0 4px;color:#bfcbed;line-height:1.5;font-size:0.94rem;}',
  '.by-ui .by-field{display:flex;flex-direction:column;gap:7px;min-width:0;}',
  '.by-ui .by-label{display:block;color:#f0f4ff;font-size:0.96rem;font-weight:650;line-height:1.4;}',
  '.by-ui .alan{display:block;box-sizing:border-box;width:100%;max-width:560px;min-height:48px;padding:11px 14px;border:1px solid #7d8eb9 !important;border-radius:11px !important;background:#182547 !important;color:#f8faff !important;-webkit-text-fill-color:#f8faff !important;opacity:1 !important;caret-color:#fff;font-size:16px !important;font-weight:500;line-height:1.45;box-shadow:none !important;color-scheme:dark;}',
  '.by-ui select.alan{appearance:auto;-webkit-appearance:menulist;cursor:pointer;}',
  '.by-ui select.alan option{background:#182547;color:#f8faff;}',
  '.by-ui .alan:focus{outline:2px solid #9cb5ff !important;outline-offset:2px;}',
  '.by-ui .alan::placeholder{color:#c2cce1 !important;-webkit-text-fill-color:#c2cce1 !important;opacity:1;}',
  '.by-ui .by-ayar .btn{min-height:48px;font-size:1rem;}',
  '@media (max-width:600px){.by-ui .by-ayar{gap:14px;}.by-ui .alan{max-width:100%;}}'
 ].join('');
 document.head.appendChild(byStyle);
}

var S={id:0,tab:'ozet',data:null};
function e(x){return String(x==null?'':x).replace(/[&<>"']/g,function(a){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[a]})}
function tl(x){return (Number(x)||0).toLocaleString('tr-TR',{maximumFractionDigits:2})+' ₺'}
function dt(x){return x?new Date(x).toLocaleString('tr-TR'):'—'}
function b(t,a){return '<button class="btn ikinci" style="width:100%;margin-top:9px" onclick="'+a+'">'+e(t)+'</button>'}
function row(k,v){return '<div class="kv"><span>'+e(k)+'</span><b>'+e(v)+'</b></div>'}
function box(t,c){return '<section class="kart"><h2>'+e(t)+'</h2>'+c+'</section>'}
function error(x){toast(typeof hataCevir==='function'?hataCevir(x.message||String(x)):String(x.message||x),true)}
function render(){
 var d=S.data,i=d.istatistik,a=d.ayar,h=box('🏦 '+d.banka.ad,
 row('Kasa',tl(d.banka.kasa))+row('Sermaye',tl(d.banka.sermaye))+
 row('Kredi verilebilir',tl(d.saglik.kredi_verilebilir))+b('← Şirket ekranına dön','sirketTekSirketEkrani('+S.id+')'));
 h+='<div class="sm-tabs">'+[['ozet','Özet'],['basvuru','Başvurular'],['musteri','Müşteriler'],['islem','İşlemler'],['ayar','Onay ayarları']].map(function(x){
 return '<button class="btn ikinci" onclick="bankaYonetimSekme(\''+x[0]+'\')">'+e(x[1])+'</button>'}).join('')+'</div>';
 if(S.tab==='ozet')h+=box('Banka özeti',row('Müşteri',i.musteri)+row('Aktif POS',i.aktif_pos)+row('Aktif kredi kartı',i.aktif_kart)+row('Aktif kredi',i.aktif_kredi)+
 row('Bekleyen POS',i.bekleyen_pos)+row('Bekleyen kart',i.bekleyen_kart)+row('Bekleyen kredi',i.bekleyen_kredi)+row('POS komisyon geliri',tl(i.pos_komisyon))+
 row('Mevduat',tl(i.mevduat))+row('Kredilerden alacak',tl(i.kredi_alacak))+b('Başvuruları aç','bankaYonetimSekme("basvuru")'));
 if(S.tab==='basvuru'){
 h+=box('POS başvuruları',(d.poslar.length?d.poslar.map(function(x){return box(x.sirket,row('Başvuran',x.oyuncu)+row('Durum',x.durum)+(x.durum==='bekliyor'?b('Onayla','bankaYonetimKarar("pos",'+x.id+',true)')+b('Reddet','bankaYonetimKarar("pos",'+x.id+',false)'):''))}).join(''):'Başvuru yok'));
 h+=box('Kredi kartı başvuruları',(d.kartlar.length?d.kartlar.map(function(x){var izin=(x.izin||[]).indexOf('kredi_notu')>=0;var details=izin?Object.keys(x.bilgi||{}).map(function(k){return row(k,JSON.stringify(x.bilgi[k]))}).join(''):'Müşterinin bilgi paylaşım izni bekleniyor';
 return box(x.oyuncu,row('İstenen limit',tl(x.istek))+row('Durum',x.durum)+details+(x.durum==='bekliyor'?
 (izin?'<input class="alan" id="bylimit'+x.id+'" type="number" min="1000" value="'+x.istek+'">'+b('Onayla','bankaYonetimKarar("kart",'+x.id+',true)'):b('Mali bilgi izni iste','bankaYonetimBilgi('+x.id+')'))+
 b('Reddet','bankaYonetimKarar("kart",'+x.id+',false)'):''))}).join(''):'Başvuru yok'));
 h+=box('Kredi başvuruları',(d.krediler.length?d.krediler.map(function(x){return box(x.oyuncu,row('Kredi tutarı',tl(x.anapara))+row('Durum',x.durum)+row('Kalan borç',tl(x.kalan))+
 (x.risk?row('Kredi notu',x.risk.kredi_notu)+row('Azami kredi',tl(x.risk.azami_kredi)):'')+(x.durum==='basvuru'?b('Onayla','bankaYonetimKarar("kredi",'+x.id+',true)')+b('Reddet','bankaYonetimKarar("kredi",'+x.id+',false)'):''))}).join(''):'Başvuru yok'));
 }
 if(S.tab==='musteri')h+=box('Müşteriler · '+i.musteri,(d.musteriler.length?d.musteriler.map(function(x){return box(x.kad,row('Hesap açılışı',dt(x.acilis))+row('Aktif kredi',x.aktif_kredi)+row('Aktif kart',x.aktif_kart)+row('Vadeli mevduat',tl(x.mevduat)))}).join(''):'Aktif müşteri yok'));
 if(S.tab==='islem')h+=box('Banka kasa hareketleri',(d.hareketler.length?d.hareketler.map(function(x){return row(dt(x.zaman),tl(x.tutar))+'<p class="alt">'+e(x.aciklama)+'</p>'}).join(''):'Hareket yok'))+
 box('POS işlemleri',(d.pos_islemler.length?d.pos_islemler.map(function(x){return row(x.sirket,tl(x.tutar))+row('Komisyon',tl(x.komisyon))}).join(''):'POS tahsilatı yok'))+
 box('Banka hesap işlemleri',(d.banka_islemler&&d.banka_islemler.length?d.banka_islemler.map(function(x){
 return row(dt(x.zaman)+' · '+x.oyuncu,tl(x.tutar))+'<p class="alt">'+e(x.aciklama)+'</p>'
 }).join(''):'Banka hesap işlemi yok'));
 if(S.tab==='ayar'){
  var select=function(id,v){return '<select id="'+id+'" class="alan" aria-label="'+id+'"><option value="false"'+(!v?' selected':'')+'>Manuel karar</option><option value="true"'+(v?' selected':'')+'>Otomatik karar</option></select>'};
  var field=function(id,label,control){return '<div class="by-field"><label class="by-label" for="'+id+'">'+label+'</label>'+control+'</div>'};
  h+=box('Banka onay politikaları','<div class="by-ayar"><p class="by-note">Otomatik modda limit, kredi notu ve banka likiditesi değerlendirilir.</p>'+
   field('bypos','POS başvuruları',select('bypos',a.pos))+
   field('bykart','Kredi kartı başvuruları',select('bykart',a.kart))+
   field('bykredi','Kredi başvuruları',select('bykredi',a.kredi))+
   field('bynot','Asgari kredi notu','<input class="alan" type="number" inputmode="numeric" id="bynot" min="0" step="1" value="'+a.min_not+'">')+
   field('bykartmax','Otomatik azami kart limiti (₺)','<input class="alan" type="number" inputmode="numeric" id="bykartmax" min="0" step="1" value="'+a.kart_max+'">')+
   field('bykredimax','Otomatik azami kredi (₺)','<input class="alan" type="number" inputmode="numeric" id="bykredimax" min="0" step="1" value="'+a.kredi_max+'">')+
   b('Politikayı kaydet','bankaYonetimAyarKaydet()')+'</div>');
 }
 h='<div class="by-ui">'+h+'</div>';
 iskelet(d.banka.ad+' · Banka Yönetimi',h,{geri:true});
}
window.bankaYonetimEkrani=async function(id,tab){try{
 S.id=Number(id);S.tab=tab||'ozet';yukleniyor('Banka yönetimi');
 S.data=await API.rpc('banka_yonetim_panel',{p_banka:S.id});render();
}catch(x){iskelet('Banka Yönetimi',box('Erişim hatası',e(x.message)),{geri:true});error(x)}};
window.bankaYonetimSekme=function(t){S.tab=t;render()};
window.bankaYonetimBilgi=async function(id){try{await API.rpc('kart_belge_iste',{p_basvuru:id,p_alanlar:['kredi_notu','maas','nakit']});toast('Bilgi paylaşma izni istendi');bankaYonetimEkrani(S.id,S.tab)}catch(x){error(x)}};
window.bankaYonetimKarar=async function(t,id,yes){if(!confirm((yes?'Başvuruyu onayla':'Başvuruyu reddet')+'?'))return;try{
 var f=t==='pos'?'pos_basvuru_karar':t==='kart'?'kart_basvuru_karar':'oyb_kredi_karar';
 var args=t==='pos'?{p_pos:id,p_onay:yes}:t==='kart'?{p_basvuru:id,p_onay:yes,p_limit:yes?Number(document.getElementById('bylimit'+id).value):null}:{p_id:id,p_onay:yes};
 await API.rpc(f,args);toast(yes?'Başvuru onaylandı':'Başvuru reddedildi');bankaYonetimEkrani(S.id,S.tab);
}catch(x){error(x)}};
window.bankaYonetimAyarKaydet=async function(){try{
 var val=function(id){return document.getElementById(id).value};
 await API.rpc('banka_yonetim_ayar_kaydet',{p_banka:S.id,p_pos:val('bypos')==='true',p_kart:val('bykart')==='true',p_kredi:val('bykredi')==='true',
 p_min_not:Number(val('bynot')),p_kart_max:Number(val('bykartmax')),p_kredi_max:Number(val('bykredimax'))});
 toast('Banka politikası kaydedildi');bankaYonetimEkrani(S.id,'ayar');
}catch(x){error(x)}};
})();