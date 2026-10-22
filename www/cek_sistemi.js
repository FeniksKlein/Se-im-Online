/* Seçim Online - Çek Merkezi 23.10.2026 */
(function(){
'use strict';
if(window.CEK_SISTEMI_AKTIF)return;
window.CEK_SISTEMI_AKTIF=true;
function esc(x){return String(x==null?'':x).replace(/[&<>"']/g,function(z){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[z];});}
function money(x){return Number(x||0).toLocaleString('tr-TR',{minimumFractionDigits:0,maximumFractionDigits:2})+' ₺';}
function date(x){if(!x)return '—';var d=new Date(x+'T12:00:00');return isNaN(d)?esc(x):d.toLocaleDateString('tr-TR');}
function row(k,v){return '<div class="kv"><span>'+esc(k)+'</span><b>'+esc(v)+'</b></div>';}
function box(h,b){return '<div class="kart"><h3>'+h+'</h3>'+b+'</div>';}
function button(n,cmd,cls){return '<button type="button" class="btn '+(cls||'ikinci')+'" onclick="'+cmd+'">'+esc(n)+'</button>';}
function val(id){var e=document.getElementById(id);return e?e.value:'';}
function warn(msg){if(typeof toast==='function')toast(String(msg),true);else alert(msg);}
function good(msg){if(typeof toast==='function')toast(String(msg));}
async function rpc(a,b){return API.rpc(a,b||{});}
async function confirmIt(title,msg){
  return (typeof onayla==='function')?onayla(title,msg,'Onayla'):window.confirm(msg);
}
window.cekSirketSecimi=null;
window.cekSeciliHedef=null;
function companyOptions(items,blank){
 return (blank?'<option value="">Şahsi banka hesabım</option>':'')+
 (items||[]).map(function(s){return '<option value="'+Number(s.id)+'">'+esc(s.ad)+' · Kasa '+esc(money(s.kasa))+'</option>';}).join('');
}
function card(c,received,now){
 var status=c.durum==='aktif'?'Dolaşımda':c.durum==='karsiliksiz'?'⚠️ Karşılıksız':c.durum==='odendi'?'✅ Ödendi':'İade edildi';
 var body=row('Bedel',money(c.tutar))+row('Ödenen',money(c.odenen))+row('Kalan',money(Number(c.tutar)-Number(c.odenen)))+
 row('Çek tarihi',date(c.tarih))+row('Durum',status)+
 row('Düzenleyen',c.borclu_ad||c.duzenleyen_ad||'—')+
 row('Hamil',c.hamil_ad||'—')+(c.aciklama?'<p class="alt">'+esc(c.aciklama)+'</p>':'');
 var id=Number(c.id),remain=Number(c.tutar)-Number(c.odenen),out='';
 if(received && remain>0 && c.durum!=='iade'){
   if(c.durum==='aktif'){
     if(String(now)>=String(c.tarih))out+=button('🏦 Bankaya ibraz et','cekEylem("ibraz",'+id+')','altin');
     else out+='<p class="alt">Yazılı tarihten önce ibraz edilemez. Düzenleyen gönüllü ödeme yapabilir.</p>';
     if(Number(c.odenen)===0)out+=button('↪️ Çeki ciro et','cekCiro('+id+')');
     if(Number(c.odenen)===0)out+=button('↩ Çeki iade et','cekEylem("iade",'+id+')');
   }
   if(c.durum==='karsiliksiz'&&!c.takip)out+=button('⚖️ İcra takibi aç','cekEylem("takip",'+id+')','altin');
   else if(c.durum==='karsiliksiz'&&c.takip)out+='<p class="alt">İcra takip talebi kaydedildi.</p>';
 }
 if(!received&&remain>0&&c.durum!=='iade')out+=button('💳 Erken veya kalan ödemeyi yap','cekEylem("erken",'+id+')','altin');
 return '<div class="kart" style="border-left:3px solid var(--line2)"><h4>🧾 Çek #'+id+'</h4>'+body+out+'</div>';
}
window.cekMerkeziAc=async function(companyId){
 if(Number.isSafeInteger(Number(companyId))&&Number(companyId)>0)window.cekSirketSecimi=Number(companyId);
 if(typeof yukleniyor==='function')yukleniyor('Çek Yönetimi');
 try{
  var d=await rpc('cek_panel'),cs=d.sirketler||[],hs=d.hesaplar||[];
  var own=window.cekSirketSecimi,day=d.bugun;
  var head=box('🧾 Çek Yönetim Merkezi',
   '<p class="alt">Şahsi banka hesabın veya yönettiğin şirket adına çek düzenle, al, ciro et, erken öde ve tahsil et. Hesapta para yokken çek yazılabilir; ödeme zamanı gerçek bakiye kontrol edilir.</p>'+
    row('Şahsi vadesiz bakiyen',money(d.vadesiz))+
    row('Hesap sayısı',hs.length)+row('Bekleyen aldığım çek', (d.bende||[]).filter(function(c){return c.durum==='aktif'||c.durum==='karsiliksiz';}).length)+
    row('Bekleyen verdiğim çek',(d.verdiklerim||[]).filter(function(c){return c.durum==='aktif'||c.durum==='karsiliksiz';}).length));
  var defOpt='<select id="ck_defter_sirket">'+companyOptions(cs,true)+'</select>';
  var accountOptions=hs.map(function(h){var s=cs.find(function(o){return Number(o.id)===Number(h.sirket);});return '<option value="'+Number(h.id)+'"'+(own&&Number(h.sirket)===own?' selected':'')+'>'+
     esc(s?s.ad:'Şahsi çek hesabım')+' · '+Number(h.yaprak)+' yaprak</option>';}).join('');
  var form=box('📕 Çek defteri',
   '<p class="alt">Her defter 10 yapraklıdır. Yeni çek hesabı için şahsi vadesiz hesabın bulunmalı. Şirket çekleri şirketin kasasından ödenir.</p>'+
   '<div class="alan"><label>Çek defteri türü</label>'+defOpt+'</div>'+
   button('Yeni çek defteri al / yaprak yenile','cekDefterAl()','altin'));
  if(!hs.length)form+='<p class="alt">Henüz çek hesabın yok. Önce bir defter al.</p>';
  var issue=box('✍️ Yeni çek düzenle',
   hs.length?
     '<div class="alan"><label>Çek kesilecek hesap</label><select id="ck_hesap">'+accountOptions+'</select></div>'+
     '<div class="alan"><label>Lehtar oyuncu veya şirket ara</label><input id="ck_ara" maxlength="60" placeholder="Kullanıcı veya şirket adı"></div>'+
     button('Alıcı ara','cekHedefAra()')+'<div id="ck_sonuclar"></div><div id="ck_secili" class="alt">Henüz alıcı seçilmedi.</div>'+
     '<div class="alan"><label>Çek tutarı (₺)</label><input id="ck_tutar" type="number" min="100" max="1000000000" step="0.01" placeholder="250000"></div>'+
     '<div class="alan"><label>Çek üzerindeki ödeme tarihi</label><input id="ck_tarih" type="date" min="'+esc(day)+'" value="'+esc(day)+'"></div>'+
     '<div class="alan"><label>Açıklama</label><input id="ck_aciklama" maxlength="180" placeholder="Mal / arsa / hizmet bedeli"></div>'+
     button('Çeki düzenle ve teslim et','cekDuzenle()','altin')+
     '<p class="alt">Çek düzenleme anında bakiyeden para çıkmaz. Çek bedeli ancak ödeme/tahsil sırasında hesaptan alınır.</p>'
    :'<p class="alt">Çek düzenlemek için önce defter al.</p>');
  var received=(d.bende||[]).map(function(c){return card(c,true,day);}).join('')||'<p class="alt">Aldığın çek bulunmuyor.</p>';
  var sent=(d.verdiklerim||[]).map(function(c){return card(c,false,day);}).join('')||'<p class="alt">Düzenlediğin çek bulunmuyor.</p>';
  var info=box('⚖️ Çek ve hukuki sonuçları',
   '<p class="alt">Çek tarihinden önce ancak düzenleyenin gönüllü ödemesiyle tahsil yapılabilir. Tarihi gelen çek ibraz edildiğinde hesapta bulunan para kısmen veya tamamen tahsil edilir.</p>'+
   '<p class="alt">Karşılıksız çek düzenleyen yeni çek yazamaz; kredi notu olumsuz etkilenir ve hamil icra başvurusu açabilir. Mahkemeye bağlı cezalar otomatik mahkûmiyet değildir.</p>');
  iskelet('Çek Yönetimi',head+form+issue+box('📥 Aldığım / şirketlerimin aldığı çekler',received)+box('📤 Verdiğim / şirketlerimin verdiği çekler',sent)+info,{geri:true});
 }catch(e){iskelet('Çek Yönetimi',box('Hata','<p>'+esc(e.message||e)+'</p>'),{geri:true});}
};
window.cekDefterAl=async function(){
  var v=val('ck_defter_sirket');
  if(!await confirmIt('Çek defteri','Seçtiğin hesap için 10 yaprak çek defteri oluşturulsun mu?'))return;
  try{var x=await rpc('cek_islem',{p_eylem:'defter',p_veri:{sirket:v}});good('Çek defteri hazır. '+Number(x.yaprak)+' yaprak var.');window.cekMerkeziAc();}
  catch(e){warn(e.message||e);}
};
window.cekHedefAra=async function(){
 var q=val('ck_ara'),div=document.getElementById('ck_sonuclar');
 if(!div)return;
 div.innerHTML='<p class="alt">Alıcı aranıyor…</p>';
 try{
  var d=await rpc('cek_hedef_ara',{p_ara:q});
  var all=(d.oyuncular||[]).map(function(x){return {tur:'oyuncu',ad:x.ad,id:x.id};})
   .concat((d.sirketler||[]).map(function(x){return {tur:'sirket',ad:x.ad,id:x.id};}));
  window.cekAramaSonuclari=all;
  div.innerHTML=all.length?all.map(function(x,i){return button((x.tur==='oyuncu'?'👤 ':'🏢 ')+x.ad,'cekHedefSec('+i+')');}).join(''):'<p class="alt">Eşleşen oyuncu veya şirket bulunamadı.</p>';
 }catch(e){div.innerHTML='<p class="alt">'+esc(e.message||e)+'</p>';}
};
window.cekHedefSec=function(i){
 var x=(window.cekAramaSonuclari||[])[i];if(!x)return;
 window.cekSeciliHedef=x;
 var el=document.getElementById('ck_secili');if(el)el.textContent='Alıcı: '+x.ad+' ('+(x.tur==='oyuncu'?'oyuncu':'şirket')+')';
};
window.cekDuzenle=async function(){
 var x=window.cekSeciliHedef,account=Number(val('ck_hesap')),amt=Number(val('ck_tutar')),dt=val('ck_tarih');
 if(!x){warn('Önce alıcı seç.');return;}
 if(!Number.isFinite(amt)||amt<100||amt>1000000000||Math.round(amt*100)!==amt*100){warn('Geçerli çek tutarı gir.');return;}
 if(!dt){warn('Çek tarihini seç.');return;}
 if(!await confirmIt('Çek düzenle',x.ad+' lehine '+money(amt)+' tutarında '+date(dt)+' tarihli çek düzenleyip teslim edecek misin?'))return;
 var data={hesap:account,tutar:amt,tarih:dt,aciklama:val('ck_aciklama')};
 if(x.tur==='sirket')data.alici_sirket=Number(x.id);else data.alici=x.ad;
 try{var a=await rpc('cek_islem',{p_eylem:'duzenle',p_veri:data});good('Çek #'+a.id+' düzenlendi.');window.cekSeciliHedef=null;window.cekMerkeziAc();}
 catch(e){warn(e.message||e);}
};
window.cekEylem=async function(act,id){
 var descriptions={ibraz:'Bankaya ibraz edildiğinde mevcut bakiye kadar tahsilat yapılır. Eksik tutar karşılıksız kaydedilir. Devam?',takip:'Karşılıksız çek için icra talebi kaydedilsin mi?',iade:'Bu çeki düzenleyene iade ederek iptal etmek istiyor musun?'};
 var data={};
 if(act==='erken'){
  var raw=window.prompt('Ödemek istediğin tutarı yaz (TL). Tam ödeme için çekin kalan tutarını yaz.','');
  if(raw===null)return;
  var n=Number(raw.replace(',','.'));
  if(!Number.isFinite(n)||n<=0||Math.round(n*100)!==n*100){warn('Geçerli ödeme tutarı gir.');return;}
  data.tutar=n;
 }else if(!await confirmIt('Çek işlemi',descriptions[act]||'İşlemi onaylıyor musun?'))return;
 try{
   var x=await rpc('cek_islem',{p_eylem:act,p_id:Number(id),p_veri:data});
   good(act==='ibraz'?'Tahsil edilen: '+money(x.odenen)+' / Kalan: '+money(x.kalan):
     act==='erken'?'Ödenen: '+money(x.odenen):'Çek işlemi kaydedildi.');
   window.cekMerkeziAc();
 }catch(e){warn(e.message||e);}
};
window.cekCiro=async function(id){
 var q=window.prompt('Çeki ciro edeceğin oyuncunun kullanıcı adını veya şirketin tam unvanını yaz:');
 if(q===null)return;
 q=q.trim();if(q.length<2){warn('İsim en az iki karakter olmalı.');return;}
 try{
  var d=await rpc('cek_hedef_ara',{p_ara:q});
  var matches=(d.oyuncular||[]).map(function(x){return {ad:x.ad,tur:'oyuncu',id:x.id};})
   .concat((d.sirketler||[]).map(function(x){return {ad:x.ad,tur:'sirket',id:x.id};}))
   .filter(function(x){return x.ad.toLocaleLowerCase('tr-TR')===q.toLocaleLowerCase('tr-TR');});
  if(matches.length!==1){warn('Tam adla tek eşleşme bulunmalı. Şirketin tam unvanını veya oyuncunun kullanıcı adını yaz.');return;}
  var x=matches[0];
  if(!await confirmIt('Çek ciro', 'Çek #'+id+' '+x.ad+' hesabına ciro edilsin mi? Çek elinden çıkar.'))return;
  var a=x.tur==='sirket'?{alici_sirket:Number(x.id)}:{alici:x.ad};
  await rpc('cek_islem',{p_eylem:'ciro',p_id:Number(id),p_veri:a});
  good('Çek '+x.ad+' tarafına ciro edildi.');window.cekMerkeziAc();
 }catch(e){warn(e.message||e);}
};
})();