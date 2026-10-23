/* SO_GUNDEM_BASIN_MAKAMLAR_V2 — Gündem kısayolları, kısa seçim arşivi ve tıklanabilir makamlar.
   Sadece görünüm / mevcut ekranlara yönlendirme; RPC, seçim verisi ve yetkilere dokunmaz. */
(function(){
 "use strict";
 if(window.SO_GUNDEM_BASIN_MAKAMLAR_V2)return;
 window.SO_GUNDEM_BASIN_MAKAMLAR_V2=true;

 function temiz(x){return String(x==null?"":x).replace(/[&<>"']/g,function(c){
   return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];
 });}
 function profil(){return typeof D!=="undefined"&&D.durum&&D.durum.profil?D.durum.profil:null;}
 function go(f){
   if(typeof f!=="function"){if(typeof toast==="function")toast("Bu bölüm henüz yüklenmedi. Sayfayı yenileyip yeniden dene.",true);return;}
   if(typeof ekranAc==="function")return ekranAc(f);
   return f();
 }
 window.soYayinGit=function(k){
   if(k==="akis")return go(typeof akisEkrani==="function"?akisEkrani:window.akisEkrani);
   if(k==="basin")return go(typeof basinEkrani==="function"?basinEkrani:window.basinEkrani);
   if(k==="turkiye")return go(typeof otomatikGazeteEkrani==="function"?function(){return otomatikGazeteEkrani();}:window.otomatikGazeteEkrani);
   if(k==="kitap")return go(typeof window.ucEkonomiEkrani==="function"?function(){return window.ucEkonomiEkrani("kitap");}:null);
 };
 window.soGundemTakvimAc=function(){
   var detay=document.getElementById("so-secim-arsiv");
   if(!detay){if(typeof sekmeAc==="function")sekmeAc("gundem");return;}
   detay.open=true;
   detay.scrollIntoView({behavior:"smooth",block:"start"});
 };
 window.soMakamGit=function(tur){
   var p=profil();
   if(!p)return;
   var yetkili=(p.makamlar||[]).some(function(m){return m.tur===tur;});
   if(tur==="parti"){
     if(!(p.parti&&(p.gb||p.gb_vekaleten||p.gby)))return;
     var id=Number(p.parti.id);
     return go(typeof partiDetay==="function"&&id>0?function(){return partiDetay(id);}:null);
   }
   if(!yetkili)return;
   if(tur==="bel"){
     if(typeof D!=="undefined")D._belediyeSehirMod="ozet";
     return go(typeof belediyeSehirYonetimEkrani==="function"?belediyeSehirYonetimEkrani:window.belediyeSehirYonetimEkrani);
   }
   if(["tbmm","bskv","grup_bskv","mv"].indexOf(tur)!==-1)return sekmeAc("meclis");
   if(["cb","cb_yardimcisi","bakan"].indexOf(tur)!==-1){
     D.devletSekme="hukumet";
     return sekmeAc("devlet");
   }
 };
 window.soMakamimAc=function(){
   var dugmeler=document.querySelectorAll(".segment button,.sekme-cip button");
   for(var i=0;i<dugmeler.length;i++){
     if(/Makam(ım|larım)?/i.test(dugmeler[i].textContent||"")){dugmeler[i].click();return;}
   }
   if(typeof yonetimEkrani==="function")return go(yonetimEkrani);
   if(typeof sekmeAc==="function")return sekmeAc("devlet");
 };
 function stiller(){
   if(document.getElementById("so-gundem-makam-stil"))return;
   var style=document.createElement("style");style.id="so-gundem-makam-stil";
   style.textContent=
     ".so-gundem-kisa{margin:4px 0 16px}.so-kisa-bas{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:0 2px 9px}.so-kisa-bas b{font-weight:850;font-size:16px}"+
     ".so-kisa-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.so-kisa-kart{display:flex;align-items:center;gap:10px;min-width:0;min-height:73px;border:1px solid var(--line2);border-radius:17px;background:var(--panel2);color:var(--txt);text-align:left;padding:12px;cursor:pointer;font:inherit}"+
     ".so-kisa-kart.so-akis{grid-column:1/-1;background:linear-gradient(110deg,rgba(123,97,255,.30),var(--panel2) 72%);border-color:rgba(168,149,255,.45)}"+
     ".so-kisa-kart:active,.so-makam-btn:active{transform:scale(.992);background:var(--panel3)}"+
     ".so-kisa-simge{flex:0 0 auto;font-size:23px}.so-kisa-metin{min-width:0;flex:1}.so-kisa-metin b{display:block;font-size:15px}.so-kisa-metin small{display:block;color:var(--mut);font-size:11.5px;line-height:1.3;margin-top:3px}.so-kisa-ok{color:var(--ink2);font-size:23px}"+
     ".so-secim-arsiv{margin:12px 0;scroll-margin-top:90px;padding:0!important;overflow:hidden}.so-secim-arsiv summary{list-style:none;display:flex;gap:10px;align-items:center;padding:15px;cursor:pointer}.so-secim-arsiv summary::-webkit-details-marker{display:none}.so-secim-arsiv summary b{display:block}.so-secim-arsiv summary small{color:var(--mut);font-size:12px;display:block;margin-top:3px}.so-secim-arsiv[open] summary{border-bottom:1px solid var(--line2)}.so-secim-arsiv-govde{padding:12px}.so-secim-arsiv-govde>.kart,.so-secim-arsiv-govde>[id^=sec]{margin:0 0 10px}.so-secim-arsiv-govde .olay{margin:0 0 10px}"+
     ".so-makam-secim{display:grid;grid-template-columns:repeat(1,minmax(0,1fr));gap:8px;margin-top:12px}.so-makam-btn{width:100%;display:flex;align-items:center;gap:12px;border:1px solid var(--line2);background:var(--panel2);border-radius:14px;color:var(--txt);text-align:left;padding:13px;cursor:pointer;font:inherit}.so-makam-emoji{font-size:23px;flex:0 0 28px}.so-makam-icerik{flex:1;min-width:0}.so-makam-icerik b{display:block;font-size:14px}.so-makam-icerik small{display:block;font-size:12px;color:var(--mut);margin-top:4px;line-height:1.3}.so-makam-ok{color:var(--ink2);font-size:24px}.so-makam-kart{border-color:rgba(168,149,255,.38)!important}.so-makam-hizli{margin:4px 0 12px}.so-makam-hizli button{width:100%;border-radius:13px;min-height:46px;text-align:left;padding:11px 13px;background:var(--panel2);color:var(--txt);border:1px solid var(--line2);font:inherit;font-weight:750}"+
     "@media(min-width:700px){.so-kisa-grid{grid-template-columns:repeat(4,minmax(0,1fr))}.so-kisa-kart.so-akis{grid-column:span 2}.so-makam-secim{grid-template-columns:repeat(2,minmax(0,1fr))}}";
   document.head.appendChild(style);
 }
 var kaynakIskelet=window.iskelet;
 if(typeof kaynakIskelet!=="function")return;
 function gundemYenile(html){
   var kok=document.createElement("div");kok.innerHTML=html;
   var eskigaz=kok.querySelector(".vit-gazete");if(eskigaz)eskigaz.remove();
   var hizli=document.createElement("section");hizli.className="so-gundem-kisa";hizli.setAttribute("aria-label","Gündem, akış ve yayın kısayolları");
   hizli.innerHTML='<div class="so-kisa-bas"><b>🗞️ Basın, yayın ve topluluk</b><span class="kucuk">Gündemin merkezi</span></div>'+
     '<div class="so-kisa-grid">'+
       '<button type="button" class="so-kisa-kart so-akis" onclick="soYayinGit(\'akis\')"><span class="so-kisa-simge">💬</span><span class="so-kisa-metin"><b>Oyuncu Akışı</b><small>Paylaşımlar, yorumlar ve en çok konuşulanlar</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'basin\')"><span class="so-kisa-simge">📰</span><span class="so-kisa-metin"><b>Gazeteler</b><small>Oyuncu gazeteleri ve köşe yazıları</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'turkiye\')"><span class="so-kisa-simge">🇹🇷</span><span class="so-kisa-metin"><b>Türkiye Gündemi</b><small>Otomatik haberler ve manşetler</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'kitap\')"><span class="so-kisa-simge">📚</span><span class="so-kisa-metin"><b>Kitaplar ve yayınevleri</b><small>Yayınları oku, satın al veya eser yayımla</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soGundemTakvimAc()"><span class="so-kisa-simge">🗳️</span><span class="so-kisa-metin"><b>Seçim takvimi</b><small>Yaklaşan tarihler ve eski sonuçlar</small></span><span class="so-kisa-ok">›</span></button>'+
     '</div>';
   // Gündemin ilk ekranında Akış ve basın/yayın bağlantıları kaydırmadan görünür.
   kok.insertBefore(hizli,kok.firstChild);
   // Belediye yönetimi yalnız Devlet > Makamlarım alanında yer alsın.
   var silindi=0;
   kok.querySelectorAll(".liste-satir,.giris-satir,.yapilacak").forEach(function(el){
     if(/Belediyesini yönet|Belediyeyi yönet/.test(el.textContent||"")){el.remove();silindi++;}
   });
   kok.querySelectorAll(".olay").forEach(function(el){
     if(Array.from(el.querySelectorAll("button")).some(function(b){return /Belediyeyi yönet/.test(b.textContent||"");})){el.remove();silindi++;}
   });
   if(silindi){
     kok.querySelectorAll(".bolum-bas").forEach(function(b){
       if((b.querySelector("h2")||{}).textContent==="Bugün"){
         var say=b.querySelector(".kucuk");
         if(say&&/^\d+\s+iş$/.test(say.textContent.trim())){
           say.textContent=Math.max(0,Number(say.textContent.match(/\d+/)[0])-1)+" iş";
         }
       }
     });
   }
   var arsiv=document.createElement("details");arsiv.id="so-secim-arsiv";arsiv.className="kart so-secim-arsiv";
   arsiv.innerHTML='<summary><span style="font-size:24px">🗳️</span><span style="flex:1"><b>Seçim takvimi ve sonuçları</b><small>İleri tarihli seçimler ve biten oylamalar burada</small></span><span class="so-kisa-ok">⌄</span></summary><div class="so-secim-arsiv-govde"></div>';
   var alan=arsiv.querySelector(".so-secim-arsiv-govde"), biten=0;
   var takvim=(typeof D!=="undefined"&&D.durum&&D.durum.takvim)||[];
   Array.from(kok.querySelectorAll('[id^="sec"]')).forEach(function(el){
     if(!/^sec\d+$/.test(el.id))return;
     var id=Number(el.id.slice(3));
     var kayit=Array.isArray(takvim)?takvim.find(function(s){return Number(s.id)===id;}):null;
     var rozet=el.querySelector(".rozet");
     var tamam=kayit?kayit.asama==="bitti":!!(rozet&&/Sonuçlandı/.test(rozet.textContent||""));
     if(tamam){alan.appendChild(el);biten++;}
   });
   var takvimBas=null;
   Array.from(kok.querySelectorAll(".bolum-bas")).some(function(el){
     if(/^\s*Seçim takvimi\s*$/i.test((el.querySelector("h2")||{}).textContent||"")){takvimBas=el;return true;}
     return false;
   });
   if(takvimBas){
     var siradaki=takvimBas.nextElementSibling;
     if(siradaki&&siradaki.classList.contains("kart")){alan.appendChild(siradaki);}
     takvimBas.remove();
   }
   if(biten||alan.children.length){
     var ozet=arsiv.querySelector("summary small");
     ozet.textContent=(biten?biten+" sonuçlandı · ":"")+"Gelecek seçimler ve tüm sonuçlar";
     var bugun=Array.from(kok.querySelectorAll(".bolum-bas")).find(function(el){return (el.querySelector("h2")||{}).textContent==="Bugün";});
     var bugunKarti=bugun&&bugun.nextElementSibling;
     if(bugunKarti&&bugunKarti.parentNode===kok)bugunKarti.insertAdjacentElement("afterend",arsiv);
     else kok.appendChild(arsiv);
   }else{
     // Seçim verisi henüz gelmediyse kısayol yine de açıklayıcı kalır.
     arsiv.querySelector(".so-secim-arsiv-govde").innerHTML='<div class="bos">Şu an kaydedilmiş gelecek seçim veya sonuç bulunmuyor.</div>';
     kok.appendChild(arsiv);
   }
   return kok.innerHTML;
 }
 function makamDetay(tur){
   if(tur==="bel")return ["🏙️","Belediye bütçesi, binalar, vergiler ve hizmetler"];
   if(tur==="cb")return ["🇹🇷","Hükümet, kabine, politika ve devlet kararları"];
   if(tur==="cb_yardimcisi")return ["🏛️","Cumhurbaşkanlığı ve hükümet işleri"];
   if(tur==="bakan")return ["📋","Bakanlık politikaları, icraatlar ve ihaleler"];
   if(tur==="tbmm"||tur==="bskv"||tur==="grup_bskv")return ["⚖️","Meclis yönetimi, teklifler ve oylamalar"];
   if(tur==="mv")return ["🗳️","Kanun teklifleri, oylamalar ve soru önergeleri"];
   return ["🏅","Makam işlemlerini aç"];
 }
 function devletYenile(html){
   var p=profil();if(!p)return html;
   var makamlar=Array.isArray(p.makamlar)?p.makamlar.slice():[];
   var rol=makamlar.map(function(m){
     var tur=String(m.tur||"");var ac=makamDetay(tur),label="";
     try{label=typeof makamYaz==="function"?makamYaz(m):"";}catch(_){}
     if(!label)label=m.il_ad&&tur==="bel"?m.il_ad+" Belediye Başkanı":tur;
     return {tur:tur,label:label,ikon:ac[0],desc:ac[1]};
   }).filter(function(m){return m.tur;});
   if(p.parti&&(p.gb||p.gb_vekaleten||p.gby)){
     rol.push({tur:"parti",label:p.gb?"Genel Başkan":p.gb_vekaleten?"Genel Başkan (vekâleten)":"Genel Başkan Yardımcısı",ikon:"🏳️",desc:"Parti teşkilatı, adaylar, ittifaklar ve parti kasası"});
   }
   var kok=document.createElement("div");kok.innerHTML=html;
   if(!rol.length)return html;
   var eski=kok.querySelector(".ynt-makamlar"), kart=eski&&eski.closest(".kart");
   if(!kart){
     Array.from(kok.querySelectorAll(".kart")).some(function(el){
       var h=el.querySelector("h2");if(h&&/^\s*Makamların\s*$/.test(h.textContent||"")){kart=el;return true;}
       return false;
     });
   }
   var grid=document.createElement("div");grid.className="so-makam-secim";
   grid.innerHTML=rol.map(function(r){
     return '<button type="button" class="so-makam-btn" onclick="soMakamGit(\''+temiz(r.tur)+'\')">'+
       '<span class="so-makam-emoji">'+r.ikon+'</span><span class="so-makam-icerik"><b>'+temiz(r.label)+'</b><small>'+temiz(r.desc)+'</small></span><span class="so-makam-ok">›</span></button>';
   }).join("");
   if(kart){
     kart.classList.add("so-makam-kart");
     var h=kart.querySelector("h2");
     if(h)h.textContent="🎖️ Makamlarım";
     var acik=kart.querySelector(".alt");
     if(acik)acik.textContent="Bir makama dokunarak yetkili olduğun işlem ekranını aç.";
     if(eski)eski.replaceWith(grid);
     else kart.appendChild(grid);
   }else{
     // Devlet'in diğer sekmelerinde makamlar sayfasına tek tuşla dön.
     var oner=document.createElement("div");oner.className="so-makam-hizli";
     oner.innerHTML='<button type="button" onclick="soMakamimAc()">🎖️ Makamlarım · '+rol.length+' görev →</button>';
     var tabs=kok.querySelector(".segment");
     if(tabs)tabs.insertAdjacentElement("afterend",oner);
     else kok.insertBefore(oner,kok.firstChild);
   }
   return kok.innerHTML;
 }
 window.iskelet=function(baslik,govde,opt){
   if(typeof govde==="string"){
     try{
       if(baslik==="Gündem")govde=gundemYenile(govde);
       else if(baslik==="Devlet"||baslik==="Yönetim")govde=devletYenile(govde);
     }catch(err){if(window.console&&console.warn)console.warn("Gündem/Makam kısayolları:",err);}
   }
   return kaynakIskelet.call(this,baslik,govde,opt);
 };
 stiller();
})();
