
/* 25.10.2026 Ekonomi kartları erişim onarımı — salt-okunur gelir raporu */
(function(){
"use strict";
if(window.SO_EKONOMI_MENU_ONARIM_20261025)return;
window.SO_EKONOMI_MENU_ONARIM_20261025=true;
var escapeHTML=function(x){return String(x==null?"":x).replace(/[&<>"']/g,function(ch){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[ch]})};
var tl=function(x){return Number(x||0).toLocaleString("tr-TR",{maximumFractionDigits:2})+" ₺"};
window.soSirketGelirRaporlari=async function(){
 if(typeof window.yukleniyor==="function")window.yukleniyor("Şirket gelir ve gider raporları");
 try{
  var d=await API.rpc("ortak_sirket_panel");
  var companies=Array.isArray(d&&d.sirketler)?d.sirketler:[];
  var items=companies.map(function(s){
   var id=Number(s.id);
   if(!Number.isSafeInteger(id)||id<=0)return "";
   return '<div class="kart" style="margin:10px 0">'+
    '<h3>🏢 '+escapeHTML(s.ad)+'</h3>'+
    '<p class="alt">'+escapeHTML(s.sektor)+' · Hissen %'+escapeHTML(s.benim_pay)+'</p>'+
    '<div class="kv"><span>Güncel şirket kasası</span><b>'+tl(s.kasa)+'</b></div>'+
    '<div class="kv"><span>Şirket sermayesi</span><b>'+tl(s.sermaye)+'</b></div>'+
    '<button type="button" class="btn altin" onclick="soMenuSirket('+id+',\'finans\')">Gelir, gider, kâr ve kasa hareketlerini aç</button>'+
    '</div>';
  }).join("");
  var html='<div class="kart"><h2>📊 Şirketlerimin gelirleri</h2>'+
   '<p class="alt">Güncel şirketlerini seçerek haftalık gelir ve gider tahminlerini, dağıtılabilir kârı ve kasa hareketlerini görebilirsin.</p></div>'+
   (items||'<div class="kart"><p>Henüz şirketin yok.</p><button class="btn altin" type="button" onclick="soMenuGit(\'sirketKurulumFormuAc\')">Yeni şirket kur</button></div>');
  window.iskelet("Şirketlerimin gelirleri",html,{geri:true});
 }catch(err){
  window.iskelet("Şirket gelirleri",'<div class="kart"><h3>Rapor yüklenemedi</h3><p>'+escapeHTML(err&&err.message||err)+'</p><button class="btn ikinci" type="button" onclick="soSirketGelirRaporlari()">Yeniden dene</button></div>',{geri:true});
 }
};
})();

/* 25.10.2026 Ekonomi menü kısayollarının eksik hedefleri: yeni ekranlara yönlendir (sunucu değişikliği yok) */
(function(){
"use strict";
if(window.SO_EKONOMI_KISAYOL_ONARIM_20261025)return;
window.SO_EKONOMI_KISAYOL_ONARIM_20261025=true;
function kur(){
 // Kredi kartları artık Mobil Şube › Kartlar sekmesinde.
 window.kartlarimEkrani=function(){ if(typeof window.mobilSubeEkrani==="function")return window.mobilSubeEkrani("kartlar"); };
 if(typeof window.sirketHissePazariEkrani!=="function"&&typeof window.cekHissePazariEkrani==="function")window.sirketHissePazariEkrani=window.cekHissePazariEkrani;
 if(typeof window.arsaEkrani!=="function")window.arsaEkrani=function(){
  if(typeof window.imKategori==="function")return window.imKategori("arsa");
  if(typeof window.ilanMeydaniEkrani==="function")return window.ilanMeydaniEkrani();
 };
 if(typeof window.sirketlerimMerkezi!=="function"&&typeof window.soSirketGelirRaporlari==="function")window.sirketlerimMerkezi=window.soSirketGelirRaporlari;
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",kur,{once:true});else kur();
})();

