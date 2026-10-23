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
   if(k==="kitap")return go(window.soKitapVitriniAc);
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
 var soTakvimSayfaHtml="";
 window.soSecimTakvimiEkrani=function(){
   var govde=soTakvimSayfaHtml||'<div class="kart"><p class="alt">Seçim bilgileri henüz yüklenmedi. Gündem sayfasından yeniden açabilirsin.</p></div>';
   return iskelet("Seçim takvimi",'<div class="so-menu-hero"><h2>🗳️ Seçim takvimi ve sonuçlar</h2><p>Seçim aşamaları, yaklaşan tarihler, adaylık işlemleri ve sonuçlar tek ekranda.</p></div>'+govde,{geri:true});
 };
 window.soGundemTakvimAc=function(){
   return go(window.soSecimTakvimiEkrani);
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

 // Gündem sıralaması için TEK KAYNAK: Mağaza > Sponsorlu > kayan VTR >
 // canlı oy verme > Basın/Yayın > gerçek Akış. Diğer Gündem blokları bu altılının arkasında.
 // Mağaza / sponsor / siyaset merkezi farklı async ekran oluşturuculardan geldiği için,
 // önceki sırayı bozan DOM eklemeleri ve yeni #icerik oluşumları birlikte izlenir.
 var soGundemGozlemci=null,soSiralamada=false;
 function soGundemDomSirala(icerik){
   if(!icerik||!icerik.isConnected||soSiralamada)return;
   var baslik=document.querySelector(".ust h1");
   if(!baslik||baslik.textContent.trim()!=="Gündem")return;
   var cocuklar=Array.from(icerik.children);
   function bul(sel){return cocuklar.find(function(x){return x.matches(sel);})||null;}
   var magaza=bul("#mgSerit,.mg-serit");
   var reklamlar=cocuklar.filter(function(x){return x.matches(".aj-sponsor,.aj-ek");});
   var kayan=bul(".serit");
   var secim=bul(".secim-ust,.so-canli-oylama");
   // Canlı seçim farklı modülden geldiğinde, içerikte görünen "Aktif Seçimler"
   // üst başlığından da tespit edilir (HTML sınıfı değişse bile).
   var asil=bul(".secim-ust");
   if(!asil){
     asil=cocuklar.find(function(x){
       return x!==secim && x.querySelector &&
         Array.from(x.querySelectorAll("h2,h3")).some(function(h){
           return /^Aktif Seçimler$/i.test((h.textContent||"").trim());
         }) && /Sandık açık/i.test(x.textContent||"");
     })||null;
   }
   if(asil){
     if(secim&&secim!==asil&&secim.classList.contains("so-canli-oylama")){
       secim.remove(); // Aynı açık sandık iki kez gösterilmesin.
     }
     secim=asil;
   }
   var yayin=bul(".so-gundem-kisa");
   var akis=bul(".so-canli-akis");
   var hafta=bul(".sm-gundem");
   // Akış her zaman Siyasi hafta kartından önce gelir; ikisi farklı zamanlarda yüklenebilir.
   var ust=[magaza].concat(reklamlar,[kayan,secim,yayin,akis,hafta]).filter(Boolean);
   if(ust.every(function(el,i){return icerik.children[i]===el;}))return;
   soSiralamada=true;
   try{
     var sonrakiler=icerik.firstChild;
     // Var olan öğeleri yeniden oluşturmadan taşı: veri, event ve içerik bozulmaz.
     for(var i=ust.length-1;i>=0;i--)icerik.insertBefore(ust[i],icerik.firstChild);
   }finally{soSiralamada=false;}
 }
 function soGundemSiralamayiBagla(){
   var icerik=document.getElementById("icerik");
   if(icerik)soGundemDomSirala(icerik);
 }
 function soGundemKaliciGozlemci(){
   if(soGundemGozlemci||typeof MutationObserver!=="function")return;
   // Tüm #app izlenir: iskelet #icerik'i baştan oluşturduğunda önceki gözlemci kaybolmasın.
   var app=document.getElementById("app")||document.body;
   soGundemGozlemci=new MutationObserver(function(){
     soGundemSiralamayiBagla();
   });
   soGundemGozlemci.observe(app,{childList:true,subtree:true});
   soGundemSiralamayiBagla();
 }
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
   // Basın ve yayın kısayolları Akıştan önce gelir; diğer Gündem kartları kendi sırasında kalır.
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
     hizli.insertAdjacentElement("afterend",akisBolumu);
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
     if(oyBolumu.querySelector('[id^="sec"]'))kok.insertBefore(oyBolumu,hizli);
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
   // Takvimin eski uzun kartlarını Gündem'den çıkar: kısayol artık ayrı ekran açar.
   // Mevcut seçim düğmeleri ve yetkiler aynen kullanılır; sunucu verisine dokunulmaz.
   var takvim=typeof D!=="undefined"&&D.durum&&Array.isArray(D.durum.takvim)?D.durum.takvim:[];
   var devam=document.createElement("div"),sonuclar=document.createElement("div"),gelecek=document.createElement("div");
   var sahneSaat=kok.querySelector(".sahne .geri-sayim[data-an]");
   if(sahneSaat){
     var hedefAn=Number(sahneSaat.getAttribute("data-an"));
     if(Number.isFinite(hedefAn)&&hedefAn-Date.now()>72*3600000){
       var sahneKart=sahneSaat.closest(".sahne");
       if(sahneKart)gelecek.appendChild(sahneKart);
     }
   }
   var eklenen=new Set();
   Array.from(kok.querySelectorAll('[id^="sec"]')).forEach(function(el){
     if(!/^sec\d+$/.test(el.id)||el.closest(".so-canli-oylama"))return;
     var id=Number(el.id.slice(3));
     var kayit=takvim.find(function(s){return Number(s.id)===id;});
     if(!kayit)return;
     eklenen.add(id);
     if(kayit.asama==="bitti")sonuclar.appendChild(el);
     else devam.appendChild(el);
   });
   // 36 saatlik ana sayfa sınırını aşmış geçmiş sonuçlar da kendi ekranında kalır.
   takvim.filter(function(s){return s.asama==="bitti"&&!eklenen.has(Number(s.id));})
     .sort(function(x,y){return Date.parse(y.sonuc_at||y.oy_bit)-Date.parse(x.sonuc_at||x.oy_bit);})
     .slice(0,30).forEach(function(s){
       if(typeof olayKarti!=="function")return;
       var kart=document.createElement("div");
       kart.id="sec"+Number(s.id);kart.innerHTML=olayKarti(s);
       if(kart.firstElementChild)sonuclar.appendChild(kart);
     });
   var takvimBas=null;
   Array.from(kok.querySelectorAll(".bolum-bas")).some(function(el){
     if(/^\s*Seçim takvimi\s*$/i.test((el.querySelector("h2")||{}).textContent||"")){takvimBas=el;return true;}
     return false;
   });
   if(takvimBas){
     var siradaki=takvimBas.nextElementSibling;
     if(siradaki&&siradaki.classList.contains("kart"))gelecek.appendChild(siradaki);
     takvimBas.remove();
   }
   // Oylama açıkken Gündem'in en üstündeki sandıklar korunur; takvimde de erişilir.
   var acik=kok.querySelector(".secim-ust"),canli=kok.querySelector(".so-canli-oylama");
   var bolum=function(bas,kutu){
     return kutu.children.length?'<div class="bolum-bas"><h2>'+bas+'</h2></div>'+kutu.innerHTML:"";
   };
   soTakvimSayfaHtml=(acik?acik.outerHTML:canli?canli.outerHTML:"")
     +bolum("Başvurular ve devam eden seçimler",devam)
     +bolum("Yaklaşan seçim takvimi",gelecek)
     +bolum("Sonuçlanan seçimler",sonuclar);
   if(!soTakvimSayfaHtml)soTakvimSayfaHtml='<div class="kart"><div class="bos">Şu an takvimde seçim veya sonuç bulunmuyor.</div></div>';
   // Gündem'deki başvuru/fırsat bağlantıları artık aşağı kaydırmak yerine bu ekranı açar.
   Array.from(kok.querySelectorAll("[onclick]")).forEach(function(el){
     var hedef=el.getAttribute("onclick")||"";
     if(hedef.indexOf("scrollIntoView")!==-1&&(hedef.indexOf("getElementById('sec")!==-1||hedef.indexOf("id^=sec")!==-1))
       el.setAttribute("onclick","soGundemTakvimAc()");
   });
   var secimBas=Array.from(kok.querySelectorAll(".bolum-bas")).find(function(el){
     return /^\s*Seçimler ve oylamalar\s*$/i.test((el.querySelector("h2")||{}).textContent||"");
   });
   if(secimBas&&(!secimBas.nextElementSibling||secimBas.nextElementSibling.classList.contains("bolum-bas")))secimBas.remove();
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
   var sonuc=kaynakIskelet.call(this,baslik,govde,opt);
   if(baslik==="Gündem"){
     soGundemKaliciGozlemci();
     soGundemSiralamayiBagla();
   }
   return sonuc;
 };
 stiller();
 soGundemKaliciGozlemci();
})();
