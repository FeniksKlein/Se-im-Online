/* Seçim Online — Kitaplar ve Yayınevleri vitrini (2026-10-23).
   Veri: mevcut uc_kitap_panel; ödeme: mevcut uc_kitap_islem.
   Yalnız sunucudan gelen yayımlanmış kitaplar listelenir; kullanıcı hesabı istemcide değiştirilmez. */
(function(){
"use strict";
if(window.SO_KITAP_VITRINI_V1)return;
window.SO_KITAP_VITRINI_V1=true;
var veri=null,alimIslemi=false,istek=0;
var e=function(v){return String(v==null?"":v).replace(/[&<>"']/g,function(c){
 return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];
});};
var para=function(v){return Math.max(0,Number(v)||0).toLocaleString("tr-TR",{maximumFractionDigits:0})+" ₺";};
var sayi=function(v){return Math.max(0,Number(v)||0).toLocaleString("tr-TR",{maximumFractionDigits:0});};
var id=function(v){var n=Number(v);return Number.isSafeInteger(n)&&n>0?n:0;};
function stil(){
 if(document.getElementById("so-kitap-stil"))return;
 var css=document.createElement("style");css.id="so-kitap-stil";
 css.textContent=[
 ".sk-hero{margin:0 0 14px;padding:19px 18px;background:linear-gradient(130deg,rgba(123,97,255,.25),var(--panel));border:1px solid var(--line2);border-radius:18px}",
 ".sk-hero h2{font-family:var(--disp,inherit);font-size:27px;margin:0 0 7px}.sk-hero p{margin:0;color:var(--mut);line-height:1.45;font-size:13px}",
 ".sk-ozet{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:12px 0}",
 ".sk-ozet>div{background:var(--panel2);border:1px solid var(--line2);border-radius:12px;padding:11px 7px;text-align:center}",
 ".sk-ozet b{display:block;font-size:19px;font-weight:800;line-height:1.3}.sk-ozet small{display:block;color:var(--mut);font-size:11px;margin-top:3px}",
 ".sk-bas{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:20px 0 10px}.sk-bas h2{font-family:var(--disp,inherit);font-size:21px;margin:0}.sk-bas small{font-size:12px;color:var(--mut)}",
 ".sk-kitap{border:1px solid var(--line2);background:var(--panel);border-radius:16px;margin:0 0 10px;padding:14px;min-width:0}",
 ".sk-kitap-ust{display:flex;align-items:flex-start;gap:13px}.sk-kapak{width:56px;min-width:56px;height:76px;border-radius:4px 9px 9px 4px;background:linear-gradient(125deg,#6047a8,#263965);border-left:5px solid #a895ff;display:flex;align-items:center;justify-content:center;font-size:27px;box-shadow:3px 4px 0 rgba(0,0,0,.17)}",
 ".sk-sira{background:rgba(168,149,255,.17);color:var(--ink2);border-radius:7px;padding:3px 7px;font-size:11px;font-weight:800;display:inline-block;margin:0 0 5px}",
 ".sk-kitap h3{font-size:17px;margin:0 0 5px;line-height:1.3;overflow-wrap:anywhere}.sk-alt{font-size:12px;color:var(--mut);line-height:1.45;overflow-wrap:anywhere}",
 ".sk-acik{color:var(--txt2);font-size:13px;margin:11px 0 9px;line-height:1.5;overflow-wrap:anywhere;white-space:pre-line}",
 ".sk-bilgiler{display:flex;flex-wrap:wrap;gap:7px;margin:10px 0}.sk-bilgiler span{padding:5px 8px;background:var(--panel2);border:1px solid var(--line);font-size:12px;color:var(--txt2);border-radius:9px}",
 ".sk-bilgiler b{color:var(--txt)}.sk-islem{display:flex;gap:7px;flex-wrap:wrap;margin-top:10px}.sk-islem button{width:auto!important;min-width:0!important;flex:1 1 130px;margin:0!important}",
 ".sk-ara{display:flex;align-items:center;gap:7px;margin:0 0 14px}.sk-ara input{display:block;width:100%;min-width:0;box-sizing:border-box;background:var(--panel2);border:1px solid var(--line2);border-radius:12px;color:var(--txt);padding:13px;font:inherit;font-size:15px}",
 ".sk-yayinevi{background:var(--panel);border:1px solid var(--line2);border-radius:14px;margin-bottom:8px;padding:12px}.sk-yayinevi summary{cursor:pointer;font-weight:800;list-style:none}.sk-yayinevi summary::-webkit-details-marker{display:none}.sk-yayinevi .alt{margin:7px 0 0}",
 ".sk-bos{padding:18px 13px;text-align:center;color:var(--mut);background:var(--panel);border:1px dashed var(--line2);border-radius:14px}",
 ".sk-oku{max-height:52vh;overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.7;font-size:15px;color:var(--txt);background:var(--panel2);padding:12px;border-radius:11px}",
 "@media(min-width:700px){.sk-katalog{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.sk-katalog .sk-kitap{margin:0}}"
 ].join("");
 document.head.appendChild(css);
}
function kitaplar(){
 return (Array.isArray(veri&&veri.kitaplar)?veri.kitaplar:[]).filter(function(k){
 return k&&k.durum==="yayinda"&&id(k.id);
 });
}
function alan(k,rank){
 var satin=k.aldim===true,benim=k.yazar_benim===true,stok=Number(k.stok)||0;
 var sahibim=satin||benim||(typeof k.icerik==="string"&&k.icerik.length>0);
 var butonlar=[];
 if(sahibim&&typeof k.icerik==="string"&&k.icerik.length>0)
   butonlar.push('<button class="btn ikinci" onclick="soKitapOku('+id(k.id)+')">📖 Kitabı oku</button>');
 if(!satin&&!benim&&stok>0)
   butonlar.push('<button class="btn altin" onclick="soKitapSatinal('+id(k.id)+')">Satın al · '+para(k.fiyat)+'</button>');
 if(satin)butonlar.push('<span class="rozet yesil">✓ Kitaplığımda</span>');
 else if(benim)butonlar.push('<span class="rozet yesil">✍️ Yazarı sensin</span>');
 else if(stok<=0)butonlar.push('<span class="rozet">Stok tükendi</span>');
 var oz=String(k.ozet||"").slice(0,380);
 return '<article class="sk-kitap" data-kitap-ara="'+e([k.baslik,k.yazar,k.tur,k.yayinevi_ad].join(" ").toLocaleLowerCase("tr-TR"))+'">'+
   '<div class="sk-kitap-ust"><div class="sk-kapak" aria-hidden="true">📖</div><div style="flex:1;min-width:0">'+
   (rank?'<span class="sk-sira">🏆 '+rank+'. en çok satan</span>':'')+
   '<h3>'+e(k.baslik)+'</h3><div class="sk-alt">Yazar: '+e(k.yazar||"Bilinmiyor")+
   ' · '+e(k.tur||"Kitap")+'<div>Yayınevi: '+e(k.yayinevi_ad||"—")+'</div></div></div></div>'+
   (oz?'<p class="sk-acik">'+e(oz)+'</p>':'')+
   '<div class="sk-bilgiler"><span>Fiyat <b>'+para(k.fiyat)+'</b></span><span>Satış <b>'+sayi(k.satilan)+' adet</b></span><span>Stok <b>'+sayi(stok)+'</b></span></div>'+
   '<div class="sk-islem">'+butonlar.join("")+'</div></article>';
}
function gorunum(){
 var list=kitaplar(),sirali=list.slice().sort(function(a,b){
  return (Number(b.satilan)||0)-(Number(a.satilan)||0)||id(b.id)-id(a.id);
 });
 var top=sirali.slice(0,5),hepsi=list.slice().sort(function(a,b){return id(b.id)-id(a.id);});
 var pub=Array.isArray(veri&&veri.yayinevleri)?veri.yayinevleri:[];
 var adet=list.reduce(function(n,k){return n+(Number(k.satilan)||0);},0);
 var topHtml=top.length?top.map(function(k,i){return alan(k,i+1);}).join(""):'<div class="sk-bos">Henüz basılmış ve satışa sunulmuş kitap bulunmuyor.</div>';
 var pubs=pub.length?pub.slice().sort(function(a,b){return String(a.ad).localeCompare(String(b.ad),"tr");}).map(function(p){
   var kitaplarim=list.filter(function(k){return id(k.yayinevi)===id(p.id);});
   return '<details class="sk-yayinevi"><summary>🏢 '+e(p.ad)+' · '+sayi(kitaplarim.length)+' kitap ▾</summary>'+
     '<div class="alt">'+(kitaplarim.length?kitaplarim.map(function(k){return e(k.baslik);}).join(" · "):"Henüz basılmış kitabı yok.")+'</div></details>';
 }).join(""):'<div class="sk-bos">Henüz bir yayınevi bulunmuyor.</div>';
 return '<section class="sk-hero"><h2>📚 Kitaplar ve yayınevleri</h2><p>Oyundaki yayımlanmış kitapları keşfet, satışları karşılaştır ve oyun cüzdanınla satın al. Satın aldığın kitapları burada okuyabilirsin.</p></section>'+
 '<div class="sk-ozet"><div><b>'+sayi(list.length)+'</b><small>Yayımlanan kitap</small></div><div><b>'+sayi(adet)+'</b><small>Toplam satış</small></div><div><b>'+sayi(pub.length)+'</b><small>Yayınevi</small></div></div>'+
 '<div class="sk-bas"><h2>🏆 En çok satan 5 kitap</h2><small>Satış adedine göre</small></div><div class="sk-katalog">'+topHtml+'</div>'+
 '<div class="sk-bas"><h2>📚 Kitaplık · Tüm kitaplar</h2><small>'+sayi(list.length)+' eser</small></div>'+
 '<div class="sk-ara"><input type="search" id="soKitapAra" aria-label="Kitap, yazar veya yayınevi ara" placeholder="Kitap, yazar veya yayınevi ara…" oninput="soKitapFiltre(this.value)"></div>'+
 '<div class="sk-katalog" id="soKitapKatalog">'+(hepsi.length?hepsi.map(function(k){return alan(k,0);}).join(""):'<div class="sk-bos">Katalogda henüz kitap bulunmuyor.</div>')+'</div>'+
 '<div class="sk-bas"><h2>🏢 Yayınevleri</h2><small>'+sayi(pub.length)+' yayınevi</small></div>'+pubs+
 '<p class="kucuk" style="margin-top:13px">Satış sayıları oyundaki gerçek kayıtlarından alınır. Sıralamada eşit satışlar için yeni basımlar önce gösterilir. Tutarlar oyun parasıdır.</p>';
}
window.soKitapFiltre=function(q){
 var arama=String(q||"").trim().toLocaleLowerCase("tr-TR");
 var liste=document.querySelectorAll("#soKitapKatalog [data-kitap-ara]");
 liste.forEach(function(el){el.hidden=!el.dataset.kitapAra.includes(arama);el.style.display=el.hidden?"none":"";});
};
window.soKitapVitriniAc=async function(){
 var n=++istek;
 stil();
 if(typeof yukleniyor==="function")yukleniyor("Kitaplar ve yayınevleri");
 try{
   var sonuc=await API.rpc("uc_kitap_panel");
   if(n!==istek)return;
   if(!sonuc||!Array.isArray(sonuc.kitaplar))throw new Error("Kitap listesi alınamadı.");
   veri=sonuc;
   iskelet("Kitaplar ve yayınevleri",gorunum(),{geri:true});
 }catch(err){
   if(n!==istek)return;
   var mesaj=typeof hataCevir==="function"?hataCevir(err.message||String(err)):String(err.message||err);
   iskelet("Kitaplar ve yayınevleri",'<div class="kart"><h2>Kitaplar yüklenemedi</h2><p class="alt">'+e(mesaj)+'</p><button class="btn ikinci" onclick="soKitapVitriniAc()">Tekrar dene</button></div>',{geri:true});
 }
};
window.soKitapOku=function(bookId){
 var k=kitaplar().find(function(x){return id(x.id)===id(bookId);});
 if(!k||typeof k.icerik!=="string"||!k.icerik){
   if(typeof toast==="function")toast("Kitabı okumak için önce satın alman gerekiyor.",true);
   return;
 }
 modal('<h3>'+e(k.baslik)+'</h3><p class="alt">Yazar: '+e(k.yazar||"—")+' · '+e(k.yayinevi_ad||"—")+'</p>'+
 '<div class="sk-oku">'+e(k.icerik)+'</div><button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
};
window.soKitapSatinal=async function(bookId){
 var k=kitaplar().find(function(x){return id(x.id)===id(bookId);});
 if(!k||alimIslemi)return;
 if(k.aldim||k.yazar_benim||Number(k.stok)<=0){
   if(typeof toast==="function")toast("Bu kitap şu anda satın alınamıyor.",true);return;
 }
 var onay=typeof onayla!=="function"||await onayla("Kitap satın al",k.baslik+" · "+para(k.fiyat)+" cüzdanından düşecek.","Satın al");
 if(!onay)return;
 alimIslemi=true;
 try{
   await API.rpc("uc_kitap_islem",{p_islem:"satinal",p_id:id(bookId),p_veri:{}});
   if(typeof toast==="function")toast("Kitap satın alındı. Artık kitabı okuyabilirsin.");
   if(typeof durumYenile==="function")Promise.resolve(durumYenile()).catch(function(){});
   await window.soKitapVitriniAc();
 }catch(err){
   if(typeof toast==="function")toast(typeof hataCevir==="function"?hataCevir(err.message||String(err)):String(err.message||err),true);
 }finally{alimIslemi=false;}
};
})();
