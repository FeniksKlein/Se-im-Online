/* Yeni cumhurbaşkanına karşılama, yemin ve ulusa sesleniş sahnesi.
   Yetkiyi cihaz değil, Supabase'deki aktif seçimle atanmış makam belirler. */
(function(){
"use strict";
const st=document.createElement("style");
st.textContent=".cbtor-bg{position:fixed;inset:0;z-index:9999;background:radial-gradient(circle at top,#28476f,#071025 75%);color:#f8f1e1;display:flex;align-items:center;justify-content:center;padding:12px;overflow-y:auto}.cbtor-panel{position:relative;width:min(100%,540px);max-height:96vh;overflow-y:auto;background:linear-gradient(145deg,#172d55,#0a1833);border:1px solid #b69b57;border-radius:20px;padding:28px 19px;text-align:center;box-shadow:0 20px 80px #000a}.cbtor-panel h1{font-size:clamp(26px,7vw,38px);line-height:1.15;color:#ffe3a1;margin:13px 0}.cbtor-panel h2{font-size:19px;margin:9px 0;color:white}.cbtor-panel p{font-size:15px;color:#dde4f1;line-height:1.7;margin:10px 0}.cbtor-selam{font-size:54px;animation:cbtor-parla 2s ease-in-out infinite}.cbtor-kucuk{font-size:11px;color:#d9be81;letter-spacing:.12em;font-weight:800}.cbtor-yemin{text-align:left;background:#071229;padding:16px;border-left:4px solid #e2be6c;font:17px/1.8 Georgia,serif;margin:15px 0}.cbtor-panel .cbtor-btn{display:block;width:100%;padding:14px;margin:13px 0 0;border-radius:10px;background:linear-gradient(95deg,#d3aa58,#f7db9b);color:#171e32;font-weight:900}.cbtor-btn:disabled{opacity:.55}.cbtor-panel .cbtor-alt{display:block;width:100%;border:1px solid #7184a2;border-radius:10px;color:white;padding:12px;margin-top:8px}.cbtor-kapat{position:absolute;right:10px;top:9px;color:#fff;background:#30476b;border-radius:50%;width:34px;height:34px;font-size:21px}.cbtor-textarea{width:100%;min-height:190px;border:1px solid #7890b2;border-radius:10px;background:#07152d;color:#fff;padding:13px;font-size:15px;line-height:1.6;resize:vertical}.cbtor-kurdele{height:4px;background:linear-gradient(90deg,#bd273a 0 40%,#fff 40% 60%,#bd273a 60%);margin:20px auto;width:80%;border-radius:6px}@keyframes cbtor-parla{50%{transform:scale(1.07);filter:drop-shadow(0 0 12px #ffe28b)}}@media(prefers-reduced-motion:reduce){.cbtor-selam{animation:none}}";
document.head.appendChild(st);
const yemin="Cumhurbaşkanı sıfatıyla devletin bağımsızlığını, milletin birliğini, Anayasa'yı, demokrasiyi ve hukukun üstünlüğünü koruyacağıma; görevimi tarafsızlık ve adaletle yerine getireceğime namusum ve şerefim üzerine ant içerim.";
const taslak="Aziz milletim,\n\nBugün sandıktan çıkan iradenizle Cumhurbaşkanlığı görevini devralıyorum. Bana duyduğunuz güven için teşekkür ediyorum.\n\nBu makamı tüm vatandaşların ortak emaneti görüyorum. Demokrasiyi, adaleti ve refahı güçlendirmek, farklı seslere kulak vermek için çalışacağım.\n\nGelin, geleceği birlikte inşa edelim.";
let acik=false,sonDeneme=0,sonMakam=null,kontrolEdiliyor=false;
function ses(){
 try{
  const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)return;
  const c=new Audio(),now=c.currentTime;
  [392,494,587,784].forEach(function(freq,i){
   const o=c.createOscillator(),v=c.createGain(),t=now+i*.22;
   o.type="triangle";o.frequency.value=freq;o.connect(v);v.connect(c.destination);
   v.gain.setValueAtTime(.0001,t);v.gain.exponentialRampToValueAtTime(.08,t+.04);
   v.gain.exponentialRampToValueAtTime(.0001,t+.28);o.start(t);o.stop(t+.3);
  });
  setTimeout(function(){c.close().catch(function(){});},1800);
 }catch(_){}
}
function kapat(){const d=document.getElementById("cbToreni");if(d)d.remove();acik=false;}
function ekran(baslik,govde){
 kapat();const d=document.createElement("div");d.id="cbToreni";d.className="cbtor-bg";
 d.innerHTML='<section class="cbtor-panel" role="dialog" aria-modal="true"><button class="cbtor-kapat" id="cbKapat" aria-label="Kapat">×</button><div class="cbtor-kucuk">SEÇİM SİMÜLASYONU ONLINE · CUMHURBAŞKANLIĞI</div><div class="cbtor-selam">🇹🇷</div><div class="cbtor-kurdele"></div><h1>'+e(baslik)+'</h1>'+govde+'<div class="cbtor-kurdele"></div><div class="cbtor-kucuk">Halkın iradesiyle · Yeni dönem</div></section>';
 document.body.appendChild(d);d.querySelector("#cbKapat").onclick=kapat;acik=true;return d;
}
function giris(t){
 const d=ekran("Milletin Yeni Cumhurbaşkanı",'<h2>Sayın '+e(t.kad)+', hoş geldiniz!</h2><p>Sandıktan çıkan sonuçlarla Cumhurbaşkanlığı makamını devraldınız. Cumhurbaşkanlığı kapıları açıldı. Tören kıtası ve bütün ülke sizi selamlıyor.</p><p>🎖️ Tebrik · 📜 Yemin töreni · 🎙️ Ulusa sesleniş</p><button class="cbtor-btn" id="cbBasla">Töreni başlat · Selamlama fanfarı</button><button class="cbtor-alt" id="cbSonra">Daha sonra</button>');
 d.querySelector("#cbBasla").onclick=function(){ses();yeminSayfa(t);};
 d.querySelector("#cbSonra").onclick=kapat;
}
function yeminSayfa(t){
 if(t.yemin_at){hitapSayfa(t);return;}
 const d=ekran("Cumhurbaşkanlığı Yemin Töreni",'<p>Meclis Genel Kurulu ve millet sizi dinliyor. Göreve başlama yeminini okuyun.</p><div class="cbtor-yemin">“'+e(yemin)+'”</div><button class="cbtor-btn" id="cbYemin">✋ Yemin ediyorum</button><p>Yemininiz, seçildiğiniz görev dönemiyle birlikte kayda alınacak.</p>');
 d.querySelector("#cbYemin").onclick=async function(){
  const b=this;b.disabled=true;b.textContent="Yemin kaydediliyor…";
  try{const r=await API.rpc("cb_yemin_et");t.yemin_at=r.yemin_at;ses();hitapSayfa(t);}
  catch(err){b.disabled=false;b.textContent="✋ Yemin ediyorum";toast(hataCevir(err.message),true);}
 };
}
function hitapSayfa(t){
 if(t.hitap_at){bitisSayfa(t);return;}
 const d=ekran("İlk Ulusa Sesleniş",'<p>Cumhurbaşkanlığı kürsüsündesiniz. Konuşmanızı yazın; ülke gündeminde ve tüm oyuncuların okuyabileceği arşivde yayımlansın.</p><textarea id="cbHitap" maxlength="2000" class="cbtor-textarea" aria-label="Ulusa sesleniş metni"></textarea><p>30–2000 karakter · Metni dilediğiniz gibi değiştirebilirsiniz.</p><button class="cbtor-btn" id="cbYayin">🎙️ Ulusa seslenişi yayımla</button><button class="cbtor-alt" id="cbSonra">Konuşmayı sonra yapacağım</button>');
 d.querySelector("#cbHitap").value=taslak;
 d.querySelector("#cbSonra").onclick=kapat;
 d.querySelector("#cbYayin").onclick=async function(){
  const b=this,metin=d.querySelector("#cbHitap").value.trim();
  if(metin.length<30||metin.length>2000){toast("Konuşma 30–2000 karakter olmalı.",true);return;}
  b.disabled=true;b.textContent="Yayımlanıyor…";
  try{const r=await API.rpc("cb_ulusa_seslen",{p_metin:metin});t.hitap_at=r.hitap_at;ses();bitisSayfa(t);}
  catch(err){b.disabled=false;b.textContent="🎙️ Ulusa seslenişi yayımla";toast(hataCevir(err.message),true);}
 };
}
function bitisSayfa(t){
 const d=ekran("Tören Tamamlandı",'<h2>Tebrikler, Cumhurbaşkanı '+e(t.kad)+'!</h2><p>Yemininiz ve ilk ulusa seslenişiniz arşive kaydedildi. Yeni dönemin ilk günü başladı.</p><button class="cbtor-btn" id="cbMakam">🏛️ Makamıma geç</button><button class="cbtor-alt" id="cbArsiv">📜 Konuşma arşivi</button>');
 d.querySelector("#cbMakam").onclick=function(){kapat();sekmeAc("yonetim");};
 d.querySelector("#cbArsiv").onclick=function(){kapat();ekranAc(window.cbUlusaSeslenislerEkrani);};
}
window.cbTorenAc=async function(){
 if(acik)return;
 try{const t=await API.rpc("cb_toren_durum");if(!t||!t.secim_id){toast("Tören yalnızca seçimle göreve gelmiş cumhurbaşkanına açıktır.",true);return;}
  if(t.hitap_at)bitisSayfa(t);else if(t.yemin_at)hitapSayfa(t);else giris(t);
 }catch(err){toast("Tören servisi henüz hazır değil: "+hataCevir(err.message),true);}
};
window.cbUlusaSeslenislerEkrani=async function(){
 yukleniyor("Ulusa seslenişler");
 try{
  const l=await API.rpc("cb_seslenisler");
  const h=Array.isArray(l)&&l.length?l.map(function(a){
   return '<div class="kart"><h3>🎙️ '+e(a.kad)+'</h3><p class="kucuk">'+tarihSaat(a.hitap_at)+'</p><p style="white-space:pre-wrap;line-height:1.8;margin-top:12px">'+e(a.hitap_metin)+'</p></div>';
  }).join(""):'<div class="kart"><p class="alt">Henüz yayımlanmış bir konuşma yok.</p></div>';
  iskelet("Ulusa seslenişler",h,{geri:true});
 }catch(err){iskelet("Ulusa seslenişler",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
};
// Her oyuncu Devlet sekmesinden ulusa sesleniş arşivini açabilir.
const eskiIskelet=iskelet;
iskelet=function(baslik,govde,sec){
 if(baslik==="Yönetim" && D.durum && D.durum.profil &&
    (D.durum.profil.makamlar||[]).some(x=>x.tur==="cb"))
  govde='<div class="kart"><button class="btn altin" onclick="cbTorenAc()">🇹🇷 Cumhurbaşkanlığı yemin törenim ve ulusa sesleniş</button></div>'+govde;
 if(baslik==="Devlet"||baslik==="Devlet yönetimi")
  govde='<div class="kart"><button class="btn ikinci" onclick="ekranAc(cbUlusaSeslenislerEkrani)">🎙️ Cumhurbaşkanlarının ulusa seslenişleri</button></div>'+govde;
 return eskiIskelet(baslik,govde,sec);
};
// Seçimden sonra yenilenen profil ilk defa CB yetkisi aldığında açılır.
const eskiDurum=durumYenile;
durumYenile=async function(){
 const r=await eskiDurum.apply(this,arguments),p=r&&r.profil;
 if(p&&Array.isArray(p.makamlar)&&p.makamlar.some(x=>x.tur==='cb')&&!acik&&!kontrolEdiliyor&&Date.now()-sonDeneme>30000){
  sonDeneme=Date.now();kontrolEdiliyor=true;
  Promise.resolve().then(async function(){
   try{
    const t=await API.rpc("cb_toren_durum");
    if(t&&t.secim_id&&!t.hitap_at&&sonMakam!==String(t.makam_id)){
     const key="cb_yeni_makam_"+t.makam_id;let goruldu=false;
     try{goruldu=sessionStorage.getItem(key)==="1";}catch(_){}
     if(!goruldu){
      sonMakam=String(t.makam_id);
      try{sessionStorage.setItem(key,"1");}catch(_){}
      setTimeout(function(){if(!acik)giris(t);},600);
     }
    }
   }catch(_){}finally{kontrolEdiliyor=false;}
  });
 }
 return r;
};
})();
