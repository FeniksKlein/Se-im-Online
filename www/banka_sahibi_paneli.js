/* Banka sahibi için kasa finansmanı ve kontrol paneli — 25.10.2026 */
(function(){
'use strict';
if(window.SO_BANKA_SAHIBI_V2)return;
window.SO_BANKA_SAHIBI_V2=true;
var bankaId=null;
var oncekiEkran=window.bankaYonetimEkrani;
var oncekiSekme=window.bankaYonetimSekme;
if(typeof oncekiEkran!=='function')return;

var st=document.createElement('style');
st.textContent='.bs-kontrol{padding:14px;margin:12px 0;border:1px solid #627caf;border-radius:16px;background:#152547;color:#f4f7ff}.bs-kontrol h2{color:#fff;font-size:1.2rem;margin:0 0 8px}.bs-kontrol p{line-height:1.5;color:#c9d7f4}.bs-kontrol input{display:block;width:100%;box-sizing:border-box;min-height:50px;padding:11px;margin:10px 0;border:2px solid #819bd1;border-radius:10px;background:#0c1936;color:#fff;font-size:17px;-webkit-text-fill-color:#fff}.bs-kontrol .bs-buttons{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.bs-kontrol button{min-height:46px;margin-top:5px}.bs-kontrol label{display:block;font-weight:700;margin-top:9px}';
document.head.appendChild(st);

function panelEkle(){
 if(!bankaId)return;
 var main=document.getElementById('icerik');
 if(!main||main.querySelector('#bsKasaYonetim'))return;
 var baslik=document.querySelector('.ust h1');
 if(baslik&&!/Banka Yönetimi/i.test(baslik.textContent||''))return;
 var ui=document.createElement('section');
 ui.id='bsKasaYonetim';ui.className='bs-kontrol';
 ui.innerHTML='<h2>🏦 Banka Sahibi · Hızlı Yönetim</h2>'+
 '<p>Bankaya para yatır, kasa likiditesini güçlendir, başvuruları değerlendir. Otomatik onayda dahi oyuncunun geliri, mevcut bütün kart limitleri, borçları ve kredi notu kontrol edilir.</p>'+
 '<div class="bs-buttons">'+
 '<button type="button" class="btn ikinci" data-bs-go="basvuru">📥 Başvurular</button>'+
 '<button type="button" class="btn ikinci" data-bs-go="ayar">⚙️ Otomatik Karar</button>'+
 '</div>'+
 '<h2 style="margin-top:18px">💰 Şahsi Paramdan Bankaya Yatır</h2>'+
 '<p>Yatırdığın tutar kişisel cüzdanından düşer; banka kasasına ve sermayesine eklenir. Karşılıksız para yaratılmaz.</p>'+
 '<label for="bsYatirTutar">Yatırılacak tutar (TL)</label>'+
 '<input id="bsYatirTutar" type="number" min="1" max="100000000" step="1" placeholder="Örn. 100000" inputmode="numeric">'+
 '<button type="button" class="btn" id="bsYatirBtn" style="width:100%">💰 Banka Kasasına Para Aktar</button>';
 main.prepend(ui);
 ui.querySelectorAll('[data-bs-go]').forEach(function(btn){
  btn.addEventListener('click',function(){window.bankaYonetimSekme(btn.dataset.bsGo)});
 });
 ui.querySelector('#bsYatirBtn').addEventListener('click',window.bankaSahibiParaYatir);
}
window.bankaSahibiParaYatir=async function(){
 var el=document.getElementById('bsYatirTutar');
 var btn=document.getElementById('bsYatirBtn');
 if(!el||!bankaId)return;
 var para=Number(el.value);
 if(!Number.isSafeInteger(para)||para<1||para>100000000){
  el.setCustomValidity('1 ile 100.000.000 TL arasında tam sayı gir.');el.reportValidity();return;
 }
 el.setCustomValidity('');
 if(!confirm(para.toLocaleString('tr-TR')+' TL şahsi cüzdanından banka kasasına aktarılsın mı?'))return;
 btn.disabled=true;
 try{
  var r=await API.rpc('sirket_kasa_yatir',{p_sirket:bankaId,p_tutar:para});
  if(!r||r.tamam!==true)throw new Error('Para yatırıldığı doğrulanamadı');
  toast('Banka kasasına para yatırıldı: '+para.toLocaleString('tr-TR')+' TL');
  await window.bankaYonetimEkrani(bankaId,'ozet');
 }catch(e){toast('Para aktarılmadı: '+String(e.message||e),true);btn.disabled=false}
};
window.bankaYonetimEkrani=async function(id,tab){
 bankaId=Number(id);
 var result=await oncekiEkran.apply(this,arguments);
 panelEkle();return result;
};
if(typeof oncekiSekme==='function'){
 window.bankaYonetimSekme=function(tab){
  var result=oncekiSekme.apply(this,arguments);
  panelEkle();return result;
 };
}
})();