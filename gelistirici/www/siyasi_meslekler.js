/* Siyasi meslekler: danismanlik ve parti ekipleri. Mevcut ekran/RPC kalibi. */
(function(){
"use strict";
if(window.SO_SIYASI_MESLEKLER_V1)return;
window.SO_SIYASI_MESLEKLER_V1=true;
function esc(x){return String(x==null?"":x).replace(/[&<>"']/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];});}
function toastH(m,h){if(typeof toast==="function")toast(m,!!h);else if(h)alert(m);}
function hata(e){return (typeof hataCevir==="function")?hataCevir(e&&e.message||String(e)):String(e&&e.message||e);}
var isimler={mv_danismani:"Milletvekili Danışmanı",belediye_danismani:"Belediye Danışmanı",parti_kampanya:"Parti Kampanya Görevlisi",parti_organizasyon:"Parti Organizasyon Görevlisi"};
var css='style="width:100%;box-sizing:border-box;padding:11px;margin:6px 0 12px;border-radius:10px"';
window.siyasiMesleklerEkrani=async function(){
 if(typeof iskelet!=="function" || typeof API==="undefined")return;
 if(typeof yukleniyor==="function")yukleniyor("Siyasi ekipler");
 try{
  var d=await API.rpc("siyasi_mesleklerim");
  var davetler=Array.isArray(d&&d.davetler)?d.davetler:[];
  var gorevler=Array.isArray(d&&d.gorevler)?d.gorevler:[];
  var yetkiler=Array.isArray(d&&d.yetkiler)?d.yetkiler:[];
  var html='<div class="kart"><h2>🤝 Siyasi Ekiplerim</h2><p class="alt">Gerçek oyuncularla siyasi ekip kurabilir, davet kabul edebilir ve görevden ayrılabilirsin. Bu görevlerin kamu kasasına erişimi yoktur.</p></div>';
  html+='<div class="kart"><h3>Gelen davetler ('+davetler.length+')</h3>';
  html+=davetler.map(function(x){var id=Number(x.id);if(!Number.isSafeInteger(id))return "";
   return '<p><b>'+esc(isimler[x.tur]||x.tur)+'</b> · '+esc(x.veren)+'<small> · Son yanıt: '+esc(new Date(x.bitis).toLocaleString("tr-TR"))+'</small></p>'+
   '<button type="button" class="btn altin" onclick="soSiyasiMeslekCevap('+id+',true)">Kabul et</button> '+
   '<button type="button" class="btn ikinci" onclick="soSiyasiMeslekCevap('+id+',false)">Reddet</button>';
  }).join('')||'<p class="alt">Bekleyen davetin yok.</p>';
  html+='</div><div class="kart"><h3>Aktif siyasi görevlerim ('+gorevler.length+')</h3>';
  html+=gorevler.map(function(x){var id=Number(x.id);if(!Number.isSafeInteger(id))return "";
   return '<p><b>'+esc(isimler[x.tur]||x.tur)+'</b> · Kurum #'+esc(x.kurum)+'</p>'+
   '<button type="button" class="btn ikinci" onclick="soSiyasiMeslekIstifa('+id+')">Görevden ayrıl</button>';
  }).join('')||'<p class="alt">Aktif danışmanlık veya ekip görevin yok.</p>';
  html+='</div>';
  if(yetkiler.length){
   html+='<div class="kart"><h3>Oyuncuyu ekibe davet et</h3><label for="so-siyasi-yetki">Görev / kurum</label>'+
     '<select id="so-siyasi-yetki" '+css+'>'+yetkiler.map(function(x){
        return '<option value="'+esc(x.tur)+'|'+esc(x.kurum)+'">'+esc(x.ad)+' · #'+esc(x.kurum)+'</option>';
      }).join('')+'</select>'+
     '<label for="so-siyasi-ad">Davet edeceğin oyuncunun kullanıcı adı</label>'+
     '<input id="so-siyasi-ad" maxlength="50" autocomplete="off" placeholder="Oyuncu kullanıcı adı" '+css+'>'+
     '<button type="button" class="btn altin" onclick="soSiyasiMeslekDavet()">Davet gönder</button>'+
     '<p class="alt">Davet 48 saat geçerli. Oyuncunun açık kabulü olmadan görevlendirme yapılamaz.</p></div>';
  }
  iskelet("Siyasi Ekipler",html,{geri:true});
 }catch(e){iskelet("Siyasi Ekipler",'<div class="kart"><h3>İşlem açılamadı</h3><p>'+esc(hata(e))+'</p></div>',{geri:true});}
};
window.soSiyasiMeslekDavet=async function(){
 var sec=document.getElementById("so-siyasi-yetki");var ad=document.getElementById("so-siyasi-ad");
 if(!sec||!ad||!ad.value.trim())return toastH("Oyuncu kullanıcı adını gir.",true);
 var parts=sec.value.split("|");var kurum=Number(parts[1]);
 if(!isimler[parts[0]]||!Number.isSafeInteger(kurum))return toastH("Geçersiz kurum/görev.",true);
 try{await API.rpc("siyasi_meslek_davet_gonder",{p_tur:parts[0],p_kurum:kurum,p_kullanici:ad.value.trim()});
   toastH("Davet gönderildi.");return window.siyasiMesleklerEkrani();
 }catch(e){toastH(hata(e),true);}
};
window.soSiyasiMeslekCevap=async function(id,kabul){
 try{await API.rpc("siyasi_meslek_davet_cevap",{p_davet:id,p_kabul:!!kabul});
   toastH(kabul?"Görevi kabul ettin.":"Daveti reddettin.");return window.siyasiMesleklerEkrani();
 }catch(e){toastH(hata(e),true);}
};
window.soSiyasiMeslekIstifa=async function(id){
 if(!window.confirm("Bu siyasi görevden ayrılmak istiyor musun?"))return;
 try{await API.rpc("siyasi_meslek_istifa",{p_gorev:id});toastH("Görevden ayrıldın.");return window.siyasiMesleklerEkrani();}
 catch(e){toastH(hata(e),true);}
};
// Siyasi ekranlara küçük, tekil bir giriş kartı ekle; mevcut görünümü değiştirme.
if(typeof iskelet==="function"){
 var onceki=iskelet;
 iskelet=function(baslik,govde,secenek){
  if(typeof govde==="string" && /^(Siyaset|Partim|Devlet|Meclis|Belediye|Parti Yönetimi)/i.test(String(baslik||""))
   && govde.indexOf('id="so-siyasi-ekip-giris"')===-1){
   govde='<div class="kart" id="so-siyasi-ekip-giris"><h3>🤝 Siyasi ekip</h3><p class="alt">Danışmanlık, kampanya ve organizasyon görevleri.</p>'+
    '<button type="button" class="btn ikinci" onclick="siyasiMesleklerEkrani()">Siyasi Ekiplerim</button></div>'+govde;
  }
  return onceki.call(this,baslik,govde,secenek);
 };
}
})();