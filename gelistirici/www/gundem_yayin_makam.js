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
 window.soAkisDaha=async function(){
   var dugme=document.getElementById("so-akis-daha");
   var kutu=document.getElementById("gAkisListe");
   if(!dugme||!kutu||dugme.disabled||typeof AKIS==="undefined"||typeof akisBagla!=="function")return;
   var liste=Array.isArray(AKIS.gundemListe)?AKIS.gundemListe:[];
   var son=liste[liste.length-1];if(!son){dugme.hidden=true;return;}
   dugme.disabled=true;dugme.textContent="Paylaşımlar yükleniyor…";
   try{
     var yeni=await API.rpc("akis_liste",{p_kapsam:"herkes",p_onceki:son.id,p_limit:20});
     yeni=Array.isArray(yeni)?yeni:[];
     var varOlan=new Set(liste.map(function(a){return String(a.id);}));
     AKIS.gundemListe=liste.concat(yeni.filter(function(a){return !varOlan.has(String(a.id));}));
     kutu.innerHTML=AKIS.gundemListe.map(akisSatirHtml).join("");
     akisBagla(kutu,function(){return AKIS.gundemListe;},window.soAkisYenile);
     dugme.hidden=yeni.length<20;
   }catch(err){
     if(typeof toast==="function")toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);
   }finally{dugme.disabled=false;dugme.textContent="Daha fazla paylaşım yükle";}
 };
 window.soAkisYenile=async function(){
   var kutu=document.getElementById("gAkisListe");if(!kutu||typeof AKIS==="undefined")return;
   try{
     var miktar=Math.min(100,Math.max(5,(AKIS.gundemListe||[]).length));
     var yeni=await API.rpc("akis_liste",{p_kapsam:"herkes",p_limit:miktar});
     AKIS.gundemListe=Array.isArray(yeni)?yeni:[];
     kutu.innerHTML=AKIS.gundemListe.map(akisSatirHtml).join("");
     akisBagla(kutu,function(){return AKIS.gundemListe;},window.soAkisYenile);
   }catch(_){}
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
   if(tur==="bakan"){
     var bolumler=document.querySelectorAll(".ynt-bolum");
     for(var i=0;i<bolumler.length;i++){
       if(/Bakanlık yönetim masası/.test(bolumler[i].textContent||"")){
         bolumler[i].scrollIntoView({behavior:"smooth",block:"start"});return;
       }
     }
     return go(typeof yonetimEkrani==="function"?yonetimEkrani:window.yonetimEkrani);
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
     ".so-canli-akis{margin:8px 0 16px}.so-canli-akis>.bolum-bas{margin:0 0 10px}.so-canli-akis .akis-kart{margin-bottom:0}.so-akis-daha{margin-top:12px;min-height:42px}.so-canli-oylama{margin:6px 0 16px}.so-canli-oylama>.bolum-bas{margin:0 0 9px}.so-canli-oylama>[id^=sec] .olay{margin:0 0 9px}"+
     ".so-kisa-kart:active,.so-makam-btn:active{transform:scale(.992);background:var(--panel3)}"+
     ".so-kisa-simge{flex:0 0 auto;font-size:23px}.so-kisa-metin{min-width:0;flex:1}.so-kisa-metin b{display:block;font-size:15px}.so-kisa-metin small{display:block;color:var(--mut);font-size:11.5px;line-height:1.3;margin-top:3px}.so-kisa-ok{color:var(--ink2);font-size:23px}"+
     ".so-secim-arsiv{margin:12px 0;scroll-margin-top:90px;padding:0!important;overflow:hidden}.so-secim-arsiv summary{list-style:none;display:flex;gap:10px;align-items:center;padding:15px;cursor:pointer}.so-secim-arsiv summary::-webkit-details-marker{display:none}.so-secim-arsiv summary b{display:block}.so-secim-arsiv summary small{color:var(--mut);font-size:12px;display:block;margin-top:3px}.so-secim-arsiv[open] summary{border-bottom:1px solid var(--line2)}.so-secim-arsiv-govde{padding:12px}.so-secim-arsiv-govde>.kart,.so-secim-arsiv-govde>[id^=sec]{margin:0 0 10px}.so-secim-arsiv-govde .olay{margin:0 0 10px}"+
     ".so-makam-secim{display:grid;grid-template-columns:repeat(1,minmax(0,1fr));gap:8px;margin-top:12px}.so-makam-btn{width:100%;display:flex;align-items:center;gap:12px;border:1px solid var(--line2);background:var(--panel2);border-radius:14px;color:var(--txt);text-align:left;padding:13px;cursor:pointer;font:inherit}.so-makam-emoji{font-size:23px;flex:0 0 28px}.so-makam-icerik{flex:1;min-width:0}.so-makam-icerik b{display:block;font-size:14px}.so-makam-icerik small{display:block;font-size:12px;color:var(--mut);margin-top:4px;line-height:1.3}.so-makam-ok{color:var(--ink2);font-size:24px}.so-makam-kart{border-color:rgba(168,149,255,.38)!important}.so-makam-hizli{margin:4px 0 12px}.so-makam-hizli button{width:100%;border-radius:13px;min-height:46px;text-align:left;padding:11px 13px;background:var(--panel2);color:var(--txt);border:1px solid var(--line2);font:inherit;font-weight:750}"+
     "@media(min-width:700px){.so-kisa-grid{grid-template-columns:repeat(4,minmax(0,1fr))}.so-makam-secim{grid-template-columns:repeat(2,minmax(0,1fr))}}";
   document.head.appendChild(style);
 }
 var kaynakIskelet=window.iskelet;
 if(typeof kaynakIskelet!=="function")return;
 function gundemYenile(html){
   var kok=document.createElement("div");kok.innerHTML=html;
   var eskigaz=kok.querySelector(".vit-gazete");if(eskigaz)eskigaz.remove();
   var hizli=document.createElement("section");hizli.className="so-gundem-kisa";hizli.setAttribute("aria-label","Basın ve yayın kısayolları");
   hizli.innerHTML='<div class="so-kisa-bas"><b>🗞️ Basın, yayın ve topluluk</b><span class="kucuk">Gündemin merkezi</span></div>'+
     '<div class="so-kisa-grid">'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'basin\')"><span class="so-kisa-simge">📰</span><span class="so-kisa-metin"><b>Gazeteler</b><small>Oyuncu gazeteleri ve köşe yazıları</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'turkiye\')"><span class="so-kisa-simge">🇹🇷</span><span class="so-kisa-metin"><b>Türkiye Gündemi</b><small>Otomatik haberler ve manşetler</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'kitap\')"><span class="so-kisa-simge">📚</span><span class="so-kisa-metin"><b>Kitaplar ve yayınevleri</b><small>Yayınları oku, satın al veya eser yayımla</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soGundemTakvimAc()"><span class="so-kisa-simge">🗳️</span><span class="so-kisa-metin"><b>Seçim takvimi</b><small>Yaklaşan tarihler ve eski sonuçlar</small></span><span class="so-kisa-ok">›</span></button>'+
     '</div>';
   // Gündemin ilk ekranında Akış ve basın/yayın bağlantıları kaydırmadan görünür.
   kok.insertBefore(hizli,kok.firstChild);
   // Mevcut çalışan Akış kartını alt bölgeden al ve Basın-Yayın'ın üzerine taşı.
   // Orijinal textarea, beğeni, yanıt ve etiket bağlayıcıları yerinde kalır.
   var akisKart=kok.querySelector(".akis-kart"), akisBolumu=null;
   if(akisKart){
     akisBolumu=document.createElement("section");
     akisBolumu.className="so-canli-akis";
     var akisBas=akisKart.previousElementSibling;
     if(akisBas&&akisBas.classList.contains("bolum-bas")&&/Akış/.test(akisBas.textContent||"")){
       akisBolumu.appendChild(akisBas);
     }else{
       akisBolumu.innerHTML='<div class="bolum-bas"><h2>Akış</h2><button class="kucuk" onclick="soYayinGit(\'akis\')">Tümünü gör ›</button></div>';
     }
     akisBolumu.appendChild(akisKart);
     var akisListe=akisKart.querySelector("#gAkisListe");
     if(akisListe&&akisListe.querySelectorAll(".akis-satir").length>=5){
       var daha=document.createElement("button");
       daha.type="button";daha.id="so-akis-daha";daha.className="btn ikinci so-akis-daha";
       daha.textContent="Daha fazla paylaşım yükle";daha.setAttribute("onclick","soAkisDaha()");
       akisKart.appendChild(daha);
     }
     kok.insertBefore(akisBolumu,hizli);
   }
   // Sandık gerçekten açık olduğu müddetçe oy kartlarını Akış'ın önüne taşı.
   // Adaylıklar, ileri tarihli seçimler, sayımlar ve bitenler burada gösterilmez.
   var an=typeof simdi==="function"?simdi():Date.now();
   var takvimAnlik=typeof D!=="undefined"&&D.durum&&Array.isArray(D.durum.takvim)?D.durum.takvim:[];
   var acikSandiklar=takvimAnlik.filter(function(s){
     var bas=Date.parse(s.oy_bas),bit=Date.parse(s.oy_bit);
     return s.asama==="oy"&&Number.isFinite(bas)&&Number.isFinite(bit)&&bas<=an&&an<bit;
   });
   if(acikSandiklar.length){
     var oyBolumu=document.createElement("section");
     oyBolumu.className="so-canli-oylama";
     oyBolumu.setAttribute("aria-label","Aktif seçimler ve oy kullanma");
     oyBolumu.innerHTML='<div class="bolum-bas"><h2>🗳️ Sandık açık</h2><span class="rozet kirmizi">Oy kullan</span></div>';
     acikSandiklar.forEach(function(s){
       var node=kok.querySelector('[id="sec'+Number(s.id)+'"]');
       if(node&&node.querySelector(".olay.oy"))oyBolumu.appendChild(node);
     });
     if(oyBolumu.querySelector('[id^="sec"]'))kok.insertBefore(oyBolumu,akisBolumu||hizli);
   }
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
   // Haftalar sonra gerçekleşecek seçim için kocaman ana geri sayım alanı kaplamasın.
   // Yakın (72 saat içindeki) seçimler ise Gündem başında görünmeye devam eder.
   var sahneSaat=kok.querySelector(".sahne .geri-sayim[data-an]");
   if(sahneSaat){
     var hedefAn=Number(sahneSaat.getAttribute("data-an"));
     if(Number.isFinite(hedefAn)&&hedefAn-Date.now()>72*3600000){
       var sahneKart=sahneSaat.closest(".sahne");
       if(sahneKart)alan.appendChild(sahneKart);
     }
   }
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
