/* Kişisel kasa: mevcut yatırım, çarşı ve şirket pozisyonlarının ortak görünümü. */
(function(){
'use strict';
if(window.YATIRIM_KASASI_V1)return;window.YATIRIM_KASASI_V1=true;

var esc=v=>String(v==null?'':v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
var money=v=>v==null?'—':Number(v).toLocaleString('tr-TR',{minimumFractionDigits:2,maximumFractionDigits:2})+' ₺';
var qty=v=>Number(v||0).toLocaleString('tr-TR',{maximumFractionDigits:8});
function hareket(x){if(x.onceki_fiyat==null||Number(x.onceki_fiyat)<=0||x.fiyat==null)return '';var fark=(Number(x.fiyat)/Number(x.onceki_fiyat)-1)*100;return '<span style="font-weight:700;color:'+(fark>0?'#22a06b':fark<0?'#db5757':'inherit')+'">'+(fark>0?'+':'')+fark.toLocaleString('tr-TR',{minimumFractionDigits:2,maximumFractionDigits:2})+'%</span>';}
function row(k,v){return '<div class="kv"><span>'+esc(k)+'</span><b>'+esc(v)+'</b></div>'}
function summary(d){return row('Nakit cüzdan',money(d.nakit))+row('Yatırımların güncel değeri',money(d.yatirim_degeri))+
 '<p class="kucuk">Yatırımlar nakit bakiyene eklenmez; satış tamamlandığında net bedel cüzdanına geçer.'+(d.eksik_deger?' '+esc(d.eksik_deger)+' varlığın fiyatı bulunamadığı için toplama dahil edilmedi.':'')+'</p>'}
function item(x,i){
 var unit=x.kaynak==='sirket'?'% pay':x.sinif==='altin'?'gram':x.sinif==='doviz'?x.kod:'adet';
 var s='<section class="kart" style="margin:10px 0;overflow-wrap:anywhere"><h3>'+esc(x.ad)+'</h3><p class="kucuk">'+esc(x.aciklama)+'</p>'+
 row('Kasandaki miktar',qty(x.miktar)+' '+unit)+row(x.kaynak==='sirket'?'%1 pay değeri':'Güncel birim fiyat',money(x.fiyat))+row('Güncel toplam değer',money(x.deger))+(hareket(x)?'<div class="kv"><span>Son fiyat değişimi</span>'+hareket(x)+'</div>':'');
 if(x.maliyet!=null)s+=row('Kalan yatırım maliyeti',money(x.maliyet))+row('Gerçekleşmemiş kâr / zarar',money(x.kar));
 if(x.fiyat_zamani)s+='<p class="kucuk">Fiyat zamanı: '+esc(new Date(x.fiyat_zamani).toLocaleString('tr-TR'))+'</p>';
 if(x.eski)s+='<p class="kucuk" style="color:var(--warn)">Son bilinen kur gösteriliyor. Alım-satım öncesinde çarşıdan kuru yenile.</p>';
 s+='<button class="btn ikinci" data-kasa-index="'+i+'">'+(x.islem_acik?'Al / sat':'Varlığı incele')+'</button></section>';return s;
}
function bind(root,d){root.querySelectorAll('[data-kasa-index]').forEach(b=>{b.onclick=function(){var x=d.varliklar[Number(b.dataset.kasaIndex)];if(!x)return;
 if(x.kaynak==='piyasa')return ekranAc(piyasaEkrani);
 if(x.kaynak==='carsi')return ekranAc(function(){return meslekOfisEkrani('pazar')});
 if(x.islem_acik)return ekranAc(function(){return borsaSirketEkrani(Number(x.sirket_id))});
 if(typeof sirketDetayEkrani==='function')return ekranAc(function(){return sirketDetayEkrani(Number(x.sirket_id))});
 return ekranAc(borsaEkrani);
}})}
async function fill(root,detail){
 if(root.dataset.loading==='1')return;root.dataset.loading='1';
 try{var d=await API.rpc('yatirim_kasam');if(!root.isConnected)return;
 root.innerHTML='<h2>Kasam ve yatırımlarım</h2>'+summary(d)+(detail?
 '<p class="alt">Fiyat değiştikçe yatırımlarının değeri değişir. Alım-satımda güncel sunucu fiyatı veya seçtiğin şirket satış emri, ilgili komisyon ve makas uygulanır. Gösterilen değer satış garantisi değildir.</p>':
 '<p class="alt">Hisse senetlerin, şirket payların, altınların ve dövizlerin tek yerde.</p>')+
 ((d.varliklar||[]).length?(detail?d.varliklar.map(item).join(''):(d.varliklar||[]).map(x=>row(x.ad+' · '+qty(x.miktar)+(x.kaynak==='sirket'?'%':''),money(x.deger)+(hareket(x)?' ('+hareket(x).replace(/<[^>]*>/g,'')+')':''))).join('')):'<p class="alt">Kasanda henüz yatırım varlığı yok.</p>')+
 (detail?'<button class="btn ikinci" id="kasa-yenile">Fiyatları ve miktarları yenile</button>':'<button class="btn altin" onclick="ekranAc(yatirimKasamEkrani)">Kasamı aç · al / sat</button>');
 bind(root,d);var b=root.querySelector('#kasa-yenile');if(b)b.onclick=()=>fill(root,true);
 }catch(err){if(root.isConnected){root.innerHTML='<h2>Kasam ve yatırımlarım</h2><p>'+esc(err.message||err)+'</p><button class="btn ikinci">Yeniden dene</button>';root.querySelector('button').onclick=()=>fill(root,detail)}}
 finally{root.dataset.loading='0'}
}
window.yatirimKasamEkrani=function(){iskelet('Kasam ve yatırımlarım','<section class="kart" id="yatirim-kasa-detay">Yatırımların yükleniyor…</section>',{geri:true});return fill(document.getElementById('yatirim-kasa-detay'),true)};
function decorate(){
 if(typeof D==='undefined'||!D.durum||D.yigin.length||!['hayat','ekonomi'].includes(D.sekme))return;
 var root=document.getElementById('icerik');if(!root||root.querySelector('#yatirim-kasa-ozet'))return;
 if(D.sekme==='ekonomi'){
  var tab=root.querySelector('.so-tabs [aria-selected="true"]');
  if(!tab||!['Özet','Yatırım'].includes(tab.getAttribute('aria-label')))return;
 }
 var anchor=root.querySelector('.so-econ-banner, .sahne');if(!anchor)return;
 var box=document.createElement('section');box.id='yatirim-kasa-ozet';box.className='kart';box.style.margin='12px 0';box.innerHTML='<h2>Kasam ve yatırımlarım</h2><p>Varlıkların yükleniyor…</p>';anchor.after(box);fill(box,false);
}
function install(){var queued=false;new MutationObserver(()=>{if(queued)return;queued=true;requestAnimationFrame(()=>{queued=false;decorate()})}).observe(document.getElementById('app')||document.body,{childList:true,subtree:true});decorate()}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
document.addEventListener('visibilitychange',()=>{var root=document.getElementById('yatirim-kasa-detay');if(!document.hidden&&root)fill(root,true)});
})();
