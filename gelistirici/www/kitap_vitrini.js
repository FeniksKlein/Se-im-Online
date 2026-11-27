/* Seçim Online — Kitaplar ve Yayınevleri 2.0 (2026-11-05).
   Vitrin (kapaklı raf + katalog), haftalık çok satanlar, yayınevi/yazar yarışı ve imza günleri.
   Veri: uc_kitap_panel (kitaplar) + kitap_rekabet (haftalık sıralama, imza günleri; sunucu 164).
   Ödeme: uc_kitap_islem 'satinal' ve kitap_imza_islem. Hesap istemcide değiştirilmez. */
(function(){
"use strict";
if(window.SO_KITAP_VITRINI_V2)return;
window.SO_KITAP_VITRINI_V2=true;

var veri=null,rek=null,sekme="vitrin",arama="",islemde=false,istek=0,yvAcik=null;
try{var _s=sessionStorage.getItem("kt_sekme");if(_s)sekme=_s;}catch(_){}
var e=function(v){return String(v==null?"":v).replace(/[&<>"']/g,function(c){
 return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];
});};
var sayi=function(v){return Math.max(0,Number(v)||0).toLocaleString("tr-TR",{maximumFractionDigits:0});};
var para=function(v){return sayi(v)+" ₺";};
var id=function(v){var n=Number(v);return Number.isSafeInteger(n)&&n>0?n:0;};
var AY=["Ocak","Şubat","Mart","Nisan","Mayıs","Haziran","Temmuz","Ağustos","Eylül","Ekim","Kasım","Aralık"];
var simdiMs=function(){return typeof simdi==="function"?simdi():Date.now();};
function trTarih(ts){
 var d=new Date(ts);if(isNaN(d))return {g:"",a:"",s:""};
 var p={};new Intl.DateTimeFormat("tr-TR",{timeZone:"Europe/Istanbul",day:"numeric",month:"numeric",hour:"2-digit",minute:"2-digit",weekday:"long",hourCycle:"h23"})
  .formatToParts(d).forEach(function(x){p[x.type]=x.value;});
 return {g:p.day,a:AY[(+p.month||1)-1],s:p.hour+":"+p.minute,hg:p.weekday};
}
function kalanYaz(ms){
 if(ms<=0)return "şimdi";
 var dk=Math.floor(ms/60000),g=Math.floor(dk/1440),sa=Math.floor(dk%1440/60),d=dk%60;
 if(g>0)return g+" gün "+sa+" sa";
 if(sa>0)return sa+" sa "+d+" dk";
 return Math.max(1,d)+" dk";
}
// Türkçe bulunma eki (İstanbul'da, İzmir'de, Sinop'ta)
function ekDe(ad){
 var s=String(ad||"");if(!s)return s;
 var k=s.toLocaleLowerCase("tr-TR"),v="a",son=k.slice(-1);
 for(var i=k.length-1;i>=0;i--){var c=k[i];if("aıouâû".indexOf(c)>=0){v="a";break;}if("eiöüî".indexOf(c)>=0){v="e";break;}}
 return s+"'"+("fstkçşhp".indexOf(son)>=0?"t":"d")+v;
}
var SVG={
 kalem:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/></svg>',
 konum:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/></svg>',
 ara:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></svg>',
 yukari:'<svg viewBox="0 0 12 12" aria-hidden="true"><path d="M6 2.5 10 8H2z" fill="currentColor"/></svg>',
 asagi:'<svg viewBox="0 0 12 12" aria-hidden="true"><path d="M6 9.5 2 4h8z" fill="currentColor"/></svg>'
};

/* ---------- Stil ---------- */
function stil(){
 if(document.getElementById("so-kitap-stil-v2"))return;
 var css=document.createElement("style");css.id="so-kitap-stil-v2";
 css.textContent=[
 /* kapak */
 ".kt-kapak{position:relative;flex:none;display:flex;flex-direction:column;overflow:hidden;isolation:isolate;border-radius:2px 6px 6px 2px;background:linear-gradient(160deg,var(--k1),var(--k2));color:var(--ky);font-family:Georgia,'Times New Roman',serif;box-shadow:inset 0 1px 0 rgba(255,255,255,.12),0 14px 24px -14px rgba(0,0,0,.85),3px 3px 0 -1px rgba(0,0,0,.28)}",
 ".kt-kapak .kt-sirt{position:absolute;left:0;top:0;bottom:0;width:8%;background:linear-gradient(90deg,rgba(0,0,0,.38),rgba(255,255,255,.14) 55%,rgba(0,0,0,.18));z-index:2}",
 ".kt-kapak b{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:5;overflow:hidden;font-weight:700;line-height:1.08;overflow-wrap:break-word;letter-spacing:-.01em}",
 ".kt-kapak b::after{content:'';display:block;width:30%;height:2px;margin-top:.55em;background:var(--km)}",
 ".kt-kapak em{margin-top:auto;font-style:normal;letter-spacing:.07em;opacity:.9;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}",
 ".kt-kapak small{opacity:.62;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-family:-apple-system,system-ui,sans-serif;letter-spacing:.02em}",
 ".kt-v1::before{content:'';position:absolute;inset:6% 7% 6% 13%;border:1px solid var(--km);opacity:.55;pointer-events:none}",
 ".kt-v2 b{margin-top:22%;margin-left:-6%;margin-right:-12%;padding:.45em 12% .5em 6%;background:var(--km);color:var(--k2)}",
 ".kt-v2 b::after{display:none}",
 ".kt-s{width:50px;height:72px;padding:9px 5px 6px 9px}.kt-s b{font-size:7px;-webkit-line-clamp:4}.kt-s em,.kt-s small{display:none}",
 ".kt-m{width:106px;height:152px;padding:15px 9px 10px 15px}.kt-m b{font-size:14px}.kt-m em{font-size:8.5px}.kt-m small{font-size:7.5px;margin-top:2px}",
 ".kt-l{width:124px;height:178px;padding:17px 10px 11px 17px}.kt-l b{font-size:17px}.kt-l em{font-size:10px}.kt-l small{font-size:8.5px;margin-top:3px}",
 ".kt-m.kt-uzun b{font-size:11.5px}.kt-l.kt-uzun b{font-size:14px}.kt-s.kt-uzun b{font-size:6px}",
 /* sekmeler */
 "#icerik .segment.kt-segment{position:sticky!important;top:-14px;z-index:6;margin:-14px -16px 16px!important;padding:12px 16px 10px!important;background:var(--bg)!important}","#icerik .segment.kt-segment>button{padding:9px 13px!important}",
 /* raf */
 ".kt-raf-bas{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin:2px 0 12px}",
 ".kt-raf-bas h2,.kt-bolum h2{font-family:var(--disp);font-size:22px;font-weight:700;line-height:1.1;margin:0}",
 ".kt-raf-bas span,.kt-bolum-bas span{font-size:12px;color:var(--mut);white-space:nowrap}",
 ".kt-raf{display:flex;gap:14px;overflow-x:auto;scroll-snap-type:x mandatory;scroll-padding:0 16px;padding:12px 16px 2px;margin:-8px -16px 0;scrollbar-width:none}",
 ".kt-raf::-webkit-scrollbar{display:none}",
 ".kt-raf-oge{flex:none;width:112px;scroll-snap-align:start;text-align:left;display:flex;flex-direction:column;gap:9px;padding:0;background:none;border:0;color:inherit;cursor:pointer}",
 ".kt-raf-kap{position:relative;padding:0 3px 10px;align-self:flex-start}",
 ".kt-raf-kap::after{content:'';position:absolute;left:-10px;right:-12px;bottom:0;height:10px;border-radius:2px;background:linear-gradient(180deg,#2a3768,#1a2349);box-shadow:0 8px 14px -6px rgba(0,0,0,.7)}",
 ".kt-no{position:absolute;z-index:3;top:-7px;left:-5px;min-width:28px;height:28px;padding:0 6px;border-radius:14px;display:grid;place-items:center;font:700 16px/1 var(--disp);background:var(--paper);color:var(--paperInk);box-shadow:0 4px 10px -4px rgba(0,0,0,.6)}",
 ".kt-no.bir{background:#F2B33D;color:#2a1d00}",
 ".kt-raf-oge strong{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden;font-size:13px;line-height:1.25;font-weight:700}",
 ".kt-raf-oge span{font-size:12px;color:var(--mut);margin-top:-5px}",
 ".kt-sayilar{display:flex;gap:0;margin:18px 0 22px;border-top:1px solid var(--line2);border-bottom:1px solid var(--line2)}",
 ".kt-sayilar div{flex:1;padding:11px 4px;text-align:center}.kt-sayilar div+div{border-left:1px solid var(--line)}",
 ".kt-sayilar b{display:block;font:700 21px/1.1 var(--disp);font-variant-numeric:tabular-nums}.kt-sayilar small{font-size:11.5px;color:var(--mut)}",
 /* katalog */
 ".kt-bolum{margin:22px 0 10px}.kt-bolum-bas{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-bottom:10px}",
 ".kt-ara{position:relative;margin:0 0 10px}.kt-ara svg{position:absolute;left:12px;top:50%;width:17px;height:17px;transform:translateY(-50%);color:var(--mut);pointer-events:none}",
 ".kt-ara input{display:block;width:100%;box-sizing:border-box;padding:12px 12px 12px 38px;border-radius:12px;background:var(--panel);border:1px solid var(--line2);color:var(--txt);font-size:15px}",
 ".kt-liste{display:flex;flex-direction:column;background:var(--panel);border:1px solid var(--line);border-radius:16px;overflow:hidden}",
 ".kt-satir{display:flex;align-items:center;gap:13px;padding:12px 13px;cursor:pointer;min-width:0}",
 ".kt-satir+.kt-satir{border-top:1px solid var(--line)}",
 ".kt-satir:active{background:rgba(255,255,255,.03)}",
 ".kt-satir-bilgi{flex:1;min-width:0}",
 ".kt-satir-bilgi h3{font-family:Georgia,'Times New Roman',serif;font-size:16px;font-weight:700;line-height:1.25;margin:0 0 3px;overflow-wrap:anywhere}",
 ".kt-satir-bilgi p{margin:0;font-size:12.5px;color:var(--mut);line-height:1.4;overflow-wrap:anywhere}",
 ".kt-satir-bilgi .kt-mini{display:flex;flex-wrap:wrap;gap:4px 12px;margin-top:6px;font-size:12px;color:var(--txt2)}",
 ".kt-satir-bilgi .kt-mini b{font-variant-numeric:tabular-nums;color:var(--txt)}",
 ".kt-satir-eylem{flex:none;display:flex;flex-direction:column;align-items:flex-end;gap:6px}",
 ".kt-al{border:0;border-radius:10px;padding:9px 11px;font-weight:800;font-size:13px;background:var(--ink);color:#fff;white-space:nowrap;cursor:pointer}",
 ".kt-al:disabled{opacity:.5}",
 ".kt-etiket{font-size:11.5px;font-weight:700;color:var(--mut);white-space:nowrap}",
 ".kt-etiket.iyi{color:var(--good)}.kt-etiket.mor{color:var(--ink2)}",
 ".kt-bos{padding:22px 16px;text-align:center;color:var(--mut);font-size:14px;line-height:1.5}",
 /* paneller ve sıralamalar */
 ".kt-panel{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:16px 15px;margin:0 0 14px}",
 ".kt-panel h3{font-family:var(--disp);font-size:20px;font-weight:700;margin:0 0 3px}",
 ".kt-panel>p,.kt-not{margin:0;color:var(--mut);font-size:12.5px;line-height:1.45}",
 ".kt-sira{list-style:none;margin:12px 0 0;padding:0}",
 /* yayınevi kartları ve sayfası (27.11.2026) */
 ".kt-yvk-liste{display:grid;gap:10px;margin:0 0 14px}",
 "@media(min-width:700px){.kt-yvk-liste{grid-template-columns:1fr 1fr}}",
 ".kt-yvk{display:flex;align-items:center;gap:12px;width:100%;text-align:left;background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:13px 14px;color:inherit;cursor:pointer;min-width:0}",
 ".kt-yvk-arma{flex:none;width:46px;height:46px;border-radius:12px;display:grid;place-items:center;font:700 19px/1 var(--disp);color:#fff;letter-spacing:.5px}",
 ".kt-yvk-arma.buyuk{width:62px;height:62px;border-radius:16px;font-size:25px}",
 ".kt-yvk-bilgi{flex:1;min-width:0}.kt-yvk-bilgi b{display:block;font-size:15.5px;line-height:1.25;overflow-wrap:anywhere}",
 ".kt-yvk-bilgi small{display:block;color:var(--mut);font-size:12.5px;line-height:1.4;margin-top:2px;overflow-wrap:anywhere}",
 ".kt-yvk .ok{flex:none;color:var(--mut);font-size:22px}",
 ".kt-yv-geri{display:inline-flex;align-items:center;gap:6px;background:none;border:0;color:var(--mut);font-weight:700;font-size:13.5px;padding:4px 0 12px;cursor:pointer}",
 ".kt-yv-ust{display:flex;align-items:center;gap:14px;margin-bottom:14px;min-width:0}",
 ".kt-yv-ust h2{font-family:var(--disp);font-size:24px;line-height:1.12;margin:0;overflow-wrap:anywhere}",
 ".kt-yv-ust p{margin:4px 0 0;color:var(--mut);font-size:12.5px;line-height:1.4}",
 ".kt-ist{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:0 0 14px}",
 ".kt-ist div{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:11px 8px;text-align:center;min-width:0}",
 ".kt-ist b{display:block;font:700 20px/1.1 var(--disp);font-variant-numeric:tabular-nums}",
 ".kt-ist small{display:block;color:var(--mut);font-size:11px;line-height:1.25;margin-top:3px}",
 ".kt-kisi{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:9px 0;min-width:0}",
 ".kt-kisi+.kt-kisi{border-top:1px solid var(--line)}",
 ".kt-kisi button{background:none;border:0;padding:0;color:var(--ink2);font-weight:800;font-size:14.5px;text-align:left;cursor:pointer;overflow-wrap:anywhere;min-width:0}",
 ".kt-kisi span{color:var(--mut);font-size:12.5px;white-space:nowrap;flex:none}",
 ".kt-sira li{display:flex;align-items:center;gap:12px;padding:10px 0;min-width:0;cursor:pointer}",
 ".kt-sira li+li{border-top:1px solid var(--line)}",
 ".kt-sira .kt-rank{width:30px;flex:none;text-align:center;font:700 26px/1 var(--disp);color:var(--txt2);font-variant-numeric:tabular-nums}",
 ".kt-sira li:first-child .kt-rank{color:#F2B33D}",
 ".kt-sira .kt-ad{flex:1;min-width:0}.kt-sira .kt-ad b{display:block;font-size:14.5px;line-height:1.25;overflow-wrap:anywhere}",
 ".kt-sira .kt-ad small{display:block;font-size:12px;color:var(--mut);margin-top:2px;overflow-wrap:anywhere}",
 ".kt-sira .kt-deger{flex:none;text-align:right}.kt-sira .kt-deger b{display:block;font:700 19px/1.1 var(--disp);font-variant-numeric:tabular-nums}",
 ".kt-sira .kt-deger small{font-size:11px;color:var(--mut)}",
 ".kt-hareket{display:inline-flex;align-items:center;gap:2px;font-size:11px;font-weight:800;margin-top:2px}",
 ".kt-hareket svg{width:9px;height:9px}.kt-hareket.ust{color:var(--good)}.kt-hareket.alt{color:var(--al2)}.kt-hareket.yeni{color:var(--ink2)}.kt-hareket.ayni{color:var(--faint)}",
 ".kt-cubuk{height:6px;border-radius:6px;background:rgba(255,255,255,.07);margin-top:7px;overflow:hidden}.kt-cubuk i{display:block;height:100%;border-radius:6px;background:linear-gradient(90deg,var(--ink),var(--ink2))}",
 ".kt-sira li:first-child .kt-cubuk i{background:linear-gradient(90deg,#c98b14,#F2B33D)}",
 ".kt-sen{display:inline-block;margin-left:6px;padding:1px 6px;border-radius:5px;font-size:10.5px;font-weight:800;background:var(--inkbg);color:var(--ink2);vertical-align:2px}",
 ".kt-sayac-bas{display:flex;align-items:center;justify-content:space-between;gap:8px;flex-wrap:wrap;margin-top:6px;font-size:12px;color:var(--mut)}",
 ".kt-sayac-bas b{color:var(--txt);font-variant-numeric:tabular-nums}",
 /* imza bileti */
 ".kt-bilet{display:flex;min-width:0;margin:0 0 12px;border-radius:18px;background:var(--panel);border:1px solid var(--line2);overflow:hidden;position:relative}",
 ".kt-bilet-tarih{flex:none;width:76px;padding:14px 6px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;background:var(--paper);color:var(--paperInk);position:relative}",
 ".kt-bilet-tarih::after{content:'';position:absolute;right:-1px;top:8px;bottom:8px;border-right:2px dashed rgba(14,21,48,.35)}",
 ".kt-bilet-tarih b{font:700 34px/1 var(--disp)}.kt-bilet-tarih span{font-size:12px;font-weight:700}.kt-bilet-tarih time{margin-top:6px;font:700 15px/1 var(--disp);font-variant-numeric:tabular-nums;padding:4px 7px;border-radius:7px;background:rgba(14,21,48,.08)}",
 ".kt-bilet-govde{flex:1;min-width:0;padding:13px 14px 14px}",
 ".kt-bilet h4{font-family:Georgia,'Times New Roman',serif;font-size:17px;font-weight:700;line-height:1.25;margin:5px 0 3px;overflow-wrap:anywhere}",
 ".kt-bilet p{margin:0;font-size:12.5px;color:var(--mut);line-height:1.45;overflow-wrap:anywhere}",
 ".kt-bilet p svg{width:13px;height:13px;vertical-align:-2px;margin-right:2px}",
 ".kt-durum{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:800;color:var(--ink2)}",
 ".kt-bilet.canli{border-color:rgba(240,69,75,.55);box-shadow:0 0 0 1px rgba(240,69,75,.18),0 18px 36px -24px rgba(240,69,75,.6)}",
 ".kt-bilet.canli .kt-durum{color:var(--al2)}",
 ".kt-bilet.canli .kt-durum i{width:8px;height:8px;border-radius:50%;background:var(--al);box-shadow:0 0 0 0 rgba(240,69,75,.6);animation:ktNabiz 1.6s infinite}",
 ".kt-bilet.bitti{opacity:.92}.kt-bilet.bitti .kt-bilet-tarih{background:var(--panel2);color:var(--txt2)}.kt-bilet.bitti .kt-bilet-tarih::after{border-color:var(--line2)}.kt-bilet.bitti .kt-bilet-tarih time{background:rgba(255,255,255,.06)}",
 ".kt-bilet.bitti .kt-durum{color:var(--mut)}",
 "@keyframes ktNabiz{0%{box-shadow:0 0 0 0 rgba(240,69,75,.55)}70%{box-shadow:0 0 0 8px rgba(240,69,75,0)}100%{box-shadow:0 0 0 0 rgba(240,69,75,0)}}",
 "@media (prefers-reduced-motion:reduce){.kt-bilet.canli .kt-durum i{animation:none}}",
 ".kt-ilerleme{height:7px;border-radius:7px;background:rgba(255,255,255,.08);overflow:hidden;margin:11px 0 5px}.kt-ilerleme i{display:block;height:100%;border-radius:7px;background:linear-gradient(90deg,var(--al),#ff9a7a)}",
 ".kt-bilet:not(.canli) .kt-ilerleme i{background:linear-gradient(90deg,var(--ink),var(--ink2))}",
 ".kt-bilet small{font-size:12px;color:var(--txt2)}",
 ".kt-bilet-eylem{display:flex;flex-wrap:wrap;gap:7px;margin-top:11px}",
 ".kt-bilet-eylem button{flex:1 1 auto;min-width:0;border:0;border-radius:10px;padding:10px 12px;font-weight:800;font-size:13.5px;cursor:pointer;background:var(--panel2);color:var(--txt)}",
 ".kt-bilet-eylem button.birincil{background:var(--ink);color:#fff}.kt-bilet.canli .kt-bilet-eylem button.birincil{background:var(--al);color:#fff}",
 ".kt-bilet-eylem button:disabled{opacity:.55}",
 ".kt-bilet-eylem .tamam{flex:1 1 auto;display:inline-flex;align-items:center;justify-content:center;padding:10px 12px;border-radius:10px;font-size:13px;font-weight:800;color:var(--good);background:rgba(52,201,138,.1)}",
 ".kt-imza-giris{position:relative;overflow:hidden;border-radius:20px;padding:18px 16px;margin:0 0 18px;background:radial-gradient(120% 140% at 100% 0%,rgba(240,69,75,.22),transparent 55%),linear-gradient(160deg,#1d2650,#151c3b);border:1px solid var(--line2)}",
 ".kt-imza-giris h3{font-family:var(--disp);font-size:23px;font-weight:700;margin:0 0 6px}",
 ".kt-imza-giris p{margin:0 0 12px;color:var(--txt2);font-size:13.5px;line-height:1.5}",
 ".kt-imza-giris ul{margin:0 0 4px;padding:0;list-style:none;display:grid;gap:6px;font-size:12.5px;color:var(--mut)}",
 ".kt-imza-giris li{padding-left:14px;position:relative}.kt-imza-giris li::before{content:'';position:absolute;left:2px;top:7px;width:5px;height:5px;border-radius:50%;background:var(--al2)}",
 ".kt-buyuk{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;margin-top:12px;border:0;border-radius:13px;padding:14px;font-weight:800;font-size:15px;background:var(--paper);color:var(--paperInk);cursor:pointer}",
 ".kt-buyuk svg{width:18px;height:18px}",
 ".kt-afis{display:flex;gap:12px;align-items:center;margin:0 0 18px;padding:12px 14px;border-radius:16px;cursor:pointer;background:linear-gradient(100deg,rgba(240,69,75,.2),rgba(240,69,75,.04));border:1px solid rgba(240,69,75,.4)}",
 ".kt-afis .kt-afis-yazi{flex:1;min-width:0}.kt-afis b{display:block;font-size:14px;line-height:1.3;overflow-wrap:anywhere}.kt-afis small{display:block;font-size:12px;color:var(--txt2);margin-top:2px}",
 ".kt-afis .kt-durum{margin-bottom:2px}.kt-afis.canli .kt-durum{color:var(--al2)}",
 ".kt-afis.canli .kt-durum i{width:8px;height:8px;border-radius:50%;background:var(--al);animation:ktNabiz 1.6s infinite}",
 ".kt-afis .ok{flex:none;font-size:22px;color:var(--txt2)}",
 /* detay */
 ".kt-detay-ust{display:flex;gap:15px;align-items:flex-start;margin:4px 0 12px}",
 ".kt-detay-ust .bilgi{flex:1;min-width:0}",
 ".kt-detay-ust .tur{font-size:12px;font-weight:700;color:var(--ink2)}",
 ".kt-detay-ust h3{font-family:Georgia,'Times New Roman',serif!important;font-size:22px!important;line-height:1.2!important;margin:4px 0 8px!important;overflow-wrap:anywhere}",
 ".kt-detay-ust p{margin:0 0 2px;font-size:13px;color:var(--txt2);overflow-wrap:anywhere}",
 ".kt-rozetler{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}",
 ".kt-rozet{display:inline-flex;align-items:center;gap:5px;padding:4px 8px;border-radius:7px;font-size:11.5px;font-weight:800;background:var(--panel2);color:var(--txt2)}",
 ".kt-rozet.altin{background:rgba(242,179,61,.16);color:#F2C164}.kt-rozet.kirmizi{background:var(--albg);color:var(--al2)}.kt-rozet.yesil{background:rgba(52,201,138,.13);color:var(--good)}",
 ".kt-ozet{font-family:Georgia,'Times New Roman',serif;font-size:15px;line-height:1.6;color:var(--txt);white-space:pre-line;overflow-wrap:anywhere;margin:0 0 14px}",
 ".kt-istat{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));margin:0 0 6px;border:1px solid var(--line2);border-radius:13px;overflow:hidden}",
 ".kt-istat div{padding:9px 4px;text-align:center}.kt-istat div+div{border-left:1px solid var(--line)}",
 ".kt-istat b{display:block;font:700 17px/1.15 var(--disp);font-variant-numeric:tabular-nums}.kt-istat small{font-size:11px;color:var(--mut)}",
 ".kt-oku{max-height:56vh;overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.75;font-size:16px;font-family:Georgia,'Times New Roman',serif;color:var(--paperInk);background:var(--paper);padding:18px 16px;border-radius:12px;margin-top:10px;user-select:text;-webkit-user-select:text}",
 /* dosyalarım (26.11.2026) */
 ".kt-dosya{background:var(--panel);border:1px solid var(--line);border-radius:18px;padding:15px 14px;margin:0 0 14px}",
 ".kt-dosya-ust{display:flex;gap:13px;align-items:flex-start;min-width:0}",
 ".kt-dosya-ust .bilgi{flex:1;min-width:0}",
 ".kt-dosya-ust h3{font-family:Georgia,'Times New Roman',serif;font-size:17px;font-weight:700;line-height:1.25;margin:0 0 4px;overflow-wrap:anywhere}",
 ".kt-dosya-ust p{margin:0;font-size:12.5px;color:var(--mut);line-height:1.4}",
 ".kt-yv{margin-top:12px;padding:12px 12px 4px;border-radius:13px;background:var(--panel2);border:1px solid var(--line2)}",
 ".kt-yv-bas{display:flex;justify-content:space-between;align-items:baseline;gap:8px;margin-bottom:8px;min-width:0}",
 ".kt-yv-bas b{font-size:14.5px;overflow-wrap:anywhere}.kt-yv-bas small{flex:none;font-size:11.5px;font-weight:800;color:var(--mut)}",
 ".kt-adimlar{list-style:none;margin:0;padding:0}",
 ".kt-adimlar li{position:relative;padding:0 0 12px 24px;font-size:13.5px;line-height:1.4;color:var(--txt2)}",
 ".kt-adimlar li::before{content:'';position:absolute;left:4px;top:4px;width:10px;height:10px;border-radius:50%;background:var(--panel);border:2px solid var(--line2);box-sizing:border-box}",
 ".kt-adimlar li::after{content:'';position:absolute;left:8px;top:16px;bottom:0;width:2px;background:var(--line2)}",
 ".kt-adimlar li:last-child::after{display:none}",
 ".kt-adimlar li.ok::before{background:var(--good);border-color:var(--good)}",
 ".kt-adimlar li.simdi::before{background:var(--ink2);border-color:var(--ink2);box-shadow:0 0 0 4px rgba(123,97,255,.18)}",
 ".kt-adimlar li.kirmizi::before{background:var(--al2);border-color:var(--al2)}",
 ".kt-adimlar li b{color:var(--txt);font-weight:700}.kt-adimlar li small{display:block;font-size:12px;color:var(--mut);overflow-wrap:anywhere}",
 ".kt-gerekce{display:block;margin-top:4px;padding:8px 10px;border-radius:9px;background:var(--albg);color:var(--txt);font-size:13px;overflow-wrap:anywhere}",
 ".kt-dugmeler{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}",
 ".kt-dugmeler button{flex:1 1 140px;min-width:0;min-height:44px;border:0;border-radius:11px;padding:10px 12px;font-weight:800;font-size:14px;cursor:pointer;background:var(--panel2);color:var(--txt);white-space:normal}",
 ".kt-dugmeler button.birincil{background:var(--ink);color:#fff}.kt-dugmeler button.tehlike{background:var(--albg);color:var(--al2)}",
 ".kt-yv .kt-dugmeler{margin:2px 0 10px}",
 ".kt-dosya-afis{display:flex;gap:12px;align-items:center;margin:0 0 18px;padding:12px 14px;border-radius:16px;cursor:pointer;background:linear-gradient(100deg,rgba(123,97,255,.2),rgba(123,97,255,.04));border:1px solid rgba(123,97,255,.35)}",
 ".kt-dosya-afis div{flex:1;min-width:0}.kt-dosya-afis b{display:block;font-size:14px;line-height:1.3}.kt-dosya-afis small{display:block;font-size:12px;color:var(--txt2);margin-top:2px}",
 ".kt-dosya-afis .ok{flex:none;font-size:22px;color:var(--txt2)}",
 /* form */
 ".kt-form .alan{margin-bottom:12px}.kt-form label{display:block;font-size:12.5px;font-weight:700;color:var(--txt2);margin-bottom:5px}",
 ".kt-form select{display:block;width:100%;padding:12px;border-radius:11px;background:var(--panel2);border:1px solid var(--line2);color:var(--txt);font-size:15px}",
 ".kt-form .iki{display:grid;grid-template-columns:1.4fr 1fr;gap:8px}",
 ".kt-secim{display:grid;grid-template-columns:1fr 1fr;gap:8px}.kt-secim label{display:flex;align-items:center;gap:8px;margin:0;padding:11px 10px;border-radius:11px;background:var(--panel2);border:1px solid var(--line2);font-size:13.5px;color:var(--txt)}",
 ".kt-tahmin{margin:4px 0 12px;padding:12px 13px;border-radius:13px;background:var(--panel2);border:1px solid var(--line2);font-size:13px;line-height:1.5;color:var(--txt2)}",
 ".kt-tahmin b{color:var(--txt)}.kt-tahmin .hata{color:var(--al2)}",
 "@media(max-width:350px){.kt-istat{grid-template-columns:repeat(2,minmax(0,1fr))}.kt-istat div:nth-child(3){border-left:0}.kt-istat div:nth-child(n+3){border-top:1px solid var(--line)}.kt-bilet-tarih{width:64px}.kt-bilet-tarih b{font-size:28px}.kt-satir-eylem .kt-al{padding:8px 9px;font-size:12px}}",
 "@media(min-width:700px){.kt-liste.kt-iki{display:grid;grid-template-columns:1fr 1fr}.kt-liste.kt-iki .kt-satir+.kt-satir{border-top:0}.kt-liste.kt-iki .kt-satir{border-bottom:1px solid var(--line)}}"
 ].join("");
 document.head.appendChild(css);
}

/* ---------- Kapak üretimi ---------- */
var PALET=[
 ["#123F4D","#0B2A35","#E8C16A","#F3F0E8"],["#5E1A2A","#3E0F1B","#F0D5A2","#FBEFE4"],
 ["#1E3B2A","#12271B","#D9C792","#EEF1E6"],["#1B2A5C","#101A3E","#F4F6FB","#F4F6FB"],
 ["#46224F","#2C1433","#F2BFD3","#F8EEF4"],["#2A2C33","#17181C","#F2B33D","#F1F1EE"],
 ["#6E2F14","#4A1D0A","#F4DEC2","#FBF3EA"],["#DCE1EC","#C5CCDD","#7B61FF","#1B2140"],
 ["#0E5A4A","#073A30","#9FE3C9","#EAF7F2"],["#24305E","#7B61FF","#FFFFFF","#FFFFFF"]
];
function ozet(s){var h=2166136261;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;}
function kapak(k,boy){
 var h=ozet(String(k.id)+"|"+String(k.baslik||"")),p=PALET[h%PALET.length],v=(h>>>5)%3,t=String(k.baslik||"Kitap");
 // Uzun Türkçe kelimeler ortadan bölünmesin: en uzun kelimeye göre yazı küçülür
 var enUzun=t.split(/\s+/).reduce(function(m,w){return Math.max(m,w.length);},0);
 var taban={s:7,m:14,l:17}[boy]||14,olc=enUzun>15?.68:enUzun>12?.78:enUzun>10?.88:1;
 if(t.length>26)olc=Math.min(olc,.82);
 if(v===2)olc*=.94;
 return '<div class="kt-kapak kt-'+boy+' kt-v'+v+'" style="--k1:'+p[0]+';--k2:'+p[1]+';--km:'+p[2]+';--ky:'+p[3]+'" aria-hidden="true">'+
  '<i class="kt-sirt"></i><b style="font-size:'+(taban*olc).toFixed(1)+'px">'+e(t)+'</b><em>'+e(k.yazar||"")+'</em><small>'+e(k.yayinevi_ad||"")+'</small></div>';
}

/* ---------- Veri yardımcıları ---------- */
function kitaplar(){
 return (Array.isArray(veri&&veri.kitaplar)?veri.kitaplar:[]).filter(function(k){return k&&k.durum==="yayinda"&&id(k.id);});
}
function kitapBul(x){var n=id(x);return kitaplar().find(function(k){return id(k.id)===n;});}
function haftaMap(){var m={};((rek&&rek.haftalik)||[]).forEach(function(x){m[id(x.kitap_id)]=x;});return m;}
function gecenMap(){var m={};((rek&&rek.gecen)||[]).forEach(function(x){m[id(x.kitap_id)]=x;});return m;}
function imzaliMi(kid){return ((rek&&rek.imzali)||[]).some(function(x){return id(x)===id(kid);});}
function imzalar(){return Array.isArray(rek&&rek.imza)?rek.imza:[];}
function duzenlenebilir(){return Array.isArray(rek&&rek.duzenlenebilir)?rek.duzenlenebilir:[];}
function hareket(simdiki,eski){
 if(!simdiki)return "";
 if(!eski)return '<span class="kt-hareket yeni">yeni</span>';
 if(eski>simdiki)return '<span class="kt-hareket ust" title="'+(eski-simdiki)+' sıra yükseldi">▲'+(eski-simdiki)+'</span>';
 if(eski<simdiki)return '<span class="kt-hareket alt" title="'+(simdiki-eski)+' sıra düştü">▼'+(simdiki-eski)+'</span>';
 return '<span class="kt-hareket ayni">aynı</span>';
}
function eylemHtml(k){
 var satin=k.aldim===true,benim=k.yazar_benim===true,stok=Number(k.stok)||0;
 if(benim)return '<span class="kt-etiket mor">Yazarı sensin</span>';
 if(satin)return '<span class="kt-etiket iyi">'+(imzaliMi(k.id)?"İmzalı nüshan var":"Kitaplığında")+'</span>';
 if(stok<=0)return '<span class="kt-etiket">Stok tükendi</span>';
 return '<button type="button" class="kt-al" onclick="event.stopPropagation();soKitapSatinal('+id(k.id)+')">'+e(para(k.fiyat))+'</button>';
}

/* ---------- Bölümler ---------- */
function afisHtml(){
 var t=simdiMs(),l=imzalar().filter(function(x){return x.durum==="canli";});
 var ev=l[0]||imzalar().filter(function(x){return x.durum==="planli"&&new Date(x.baslangic)-t<48*3600e3;})[0];
 if(!ev)return "";
 var canli=ev.durum==="canli",z=trTarih(ev.baslangic);
 return '<div class="kt-afis'+(canli?' canli':'')+'" role="button" tabindex="0" onclick="soKitapSekme(\'imza\')" onkeydown="if(event.key===\'Enter\')soKitapSekme(\'imza\')">'+
  '<div class="kt-afis-yazi"><span class="kt-durum">'+(canli?'<i></i>İmza masası açık':'Yaklaşan imza günü')+'</span>'+
  '<b>'+e(ev.yazar)+' · '+e(ev.baslik)+'</b><small>'+e(ekDe(ev.il_ad))+(canli?', kapanışa <span data-kt-sayac="'+e(ev.bitis)+'">'+e(kalanYaz(new Date(ev.bitis)-t))+'</span>':', '+e(z.g+" "+z.a+" "+z.s))+(l.length>1?' · '+(l.length-1)+' masa daha':'')+'</small></div>'+
  '<span class="ok" aria-hidden="true">›</span></div>';
}
function rafHtml(){
 var hm=haftaMap(),list=kitaplar(),haftalik=((rek&&rek.haftalik)||[]).map(function(x){return kitapBul(x.kitap_id);}).filter(Boolean);
 var baslik="Bu haftanın çok satanları",alt=(rek&&rek.hafta?rek.hafta.no+". hafta":"");
 var raf=haftalik.slice(0,8);
 if(!raf.length){
  raf=list.slice().sort(function(a,b){return (Number(b.satilan)||0)-(Number(a.satilan)||0)||id(b.id)-id(a.id);}).slice(0,8);
  baslik="Çok satanlar";alt="Tüm zamanlar";
 }
 if(!raf.length)return '<div class="kt-panel"><div class="kt-bos">Henüz basılmış kitap yok. İlk kitabı sen yazıp bir yayınevine sunabilirsin.</div>'+yazBtn()+'</div>';
 return '<div class="kt-raf-bas"><h2>'+e(baslik)+'</h2><span>'+e(alt)+'</span></div>'+
  '<div class="kt-raf" role="list">'+raf.map(function(k,i){
   var adet=hm[id(k.id)]?hm[id(k.id)].adet:null;
   return '<button type="button" role="listitem" class="kt-raf-oge" onclick="soKitapDetay('+id(k.id)+')" aria-label="'+e((i+1)+". "+k.baslik)+'">'+
    '<span class="kt-raf-kap"><span class="kt-no'+(i===0?' bir':'')+'">'+(i+1)+'</span>'+kapak(k,"m")+'</span>'+
    '<strong>'+e(k.baslik)+'</strong><span>'+(adet!=null?e(sayi(adet))+" adet bu hafta":e(sayi(k.satilan))+" adet")+'</span></button>';
  }).join("")+'</div>';
}
function sayilarHtml(){
 var list=kitaplar(),pub=((rek&&rek.yayinevleri)||[]).filter(function(y){return Number(y.kitap)>0;}).length||(Array.isArray(veri&&veri.yayinevleri)?veri.yayinevleri.length:0);
 var toplam=list.reduce(function(n,k){return n+(Number(k.satilan)||0);},0);
 var hafta=((rek&&rek.haftalik)||[]).reduce(function(n,x){return n+(Number(x.adet)||0);},0);
 return '<div class="kt-sayilar"><div><b>'+sayi(list.length)+'</b><small>Kitap</small></div><div><b>'+sayi(pub)+'</b><small>Yayınevi</small></div>'+
  '<div><b>'+sayi(rek?hafta:toplam)+'</b><small>'+(rek?"Bu hafta satış":"Toplam satış")+'</small></div></div>';
}
function satirHtml(k){
 var hm=haftaMap()[id(k.id)];
 return '<div class="kt-satir" role="button" tabindex="0" data-kt-ara="'+e([k.baslik,k.yazar,k.tur,k.yayinevi_ad].join(" ").toLocaleLowerCase("tr-TR"))+'" onclick="soKitapDetay('+id(k.id)+')" onkeydown="if(event.key===\'Enter\')soKitapDetay('+id(k.id)+')">'+
  kapak(k,"s")+'<div class="kt-satir-bilgi"><h3>'+e(k.baslik)+'</h3><p>'+e(k.yazar||"Bilinmiyor")+' · '+e(k.yayinevi_ad||"—")+'</p>'+
  '<div class="kt-mini"><span><b>'+e(sayi(k.satilan))+'</b> satış</span>'+(hm?'<span><b>'+e(sayi(hm.adet))+'</b> bu hafta</span>':'')+'<span>'+e(k.tur||"Kitap")+'</span></div></div>'+
  '<div class="kt-satir-eylem">'+eylemHtml(k)+'</div></div>';
}
function yazBtn(){
 return typeof window.ucYeniAc==="function"?'<button type="button" class="btn ikinci" onclick="ucYeniAc(\'kitap\')">Kitap yaz ya da yayınevini yönet</button>':'';
}
function vitrinHtml(){
 var hepsi=kitaplar().slice().sort(function(a,b){return id(b.id)-id(a.id);});
 return dosyaAfisHtml()+afisHtml()+rafHtml()+sayilarHtml()+
  '<div class="kt-bolum"><div class="kt-bolum-bas"><h2>Katalog</h2><span>'+e(sayi(hepsi.length))+' kitap</span></div>'+
  '<div class="kt-ara">'+SVG.ara+'<input type="search" id="soKitapAra" aria-label="Kitap, yazar veya yayınevi ara" placeholder="Kitap, yazar ya da yayınevi ara" value="'+e(arama)+'" oninput="soKitapFiltre(this.value)"></div>'+
  '<div class="kt-liste kt-iki" id="soKitapKatalog">'+(hepsi.length?hepsi.map(satirHtml).join(""):'<div class="kt-bos">Katalogda henüz kitap yok.</div>')+'</div>'+
  '<p class="kt-not" id="soKitapAraBos" hidden style="margin-top:10px">Aramana uyan kitap yok.</p></div>'+
  '<div style="margin-top:16px">'+yazBtn()+'</div>';
}
function geriSayimHtml(){
 if(!rek||!rek.hafta)return "";
 return '<div class="kt-sayac-bas"><span>Hafta Pazartesi 00:00\'da kapanır, liste Türkiye Gündem\'de açıklanır.</span><span>Kalan <b data-kt-sayac="'+e(rek.hafta.bit)+'">'+e(kalanYaz(new Date(rek.hafta.bit)-simdiMs()))+'</b></span></div>';
}
function listeHtml(){
 if(!rek)return '<div class="kt-panel"><div class="kt-bos">Haftalık liste şu anda yüklenemedi. Biraz sonra tekrar dene.</div></div>';
 var gm=gecenMap(),h=(rek.haftalik||[]).filter(function(x){return kitapBul(x.kitap_id);});
 var en=h.length?Number(h[0].adet)||1:1;
 var sira=h.length?'<ol class="kt-sira">'+h.slice(0,10).map(function(x){
   var k=kitapBul(x.kitap_id),g=gm[id(x.kitap_id)];
   return '<li onclick="soKitapDetay('+id(k.id)+')"><span class="kt-rank">'+x.sira+'</span>'+kapak(k,"s")+
    '<div class="kt-ad"><b>'+e(k.baslik)+(k.yazar_benim?'<span class="kt-sen">Sen</span>':'')+'</b><small>'+e(k.yazar)+' · '+e(k.yayinevi_ad)+'</small>'+
    '<div class="kt-cubuk"><i style="width:'+Math.max(4,Math.round((Number(x.adet)||0)/en*100))+'%"></i></div></div>'+
    '<div class="kt-deger"><b>'+e(sayi(x.adet))+'</b><small>adet</small><div>'+hareket(x.sira,g&&g.sira)+'</div></div></li>';
  }).join("")+'</ol>':'<div class="kt-bos">Bu hafta henüz satış yok. İlk satış listeyi açar.</div>';
 var gecen=(rek.gecen||[]).filter(function(x){return kitapBul(x.kitap_id);}).slice(0,5);
 var tum=kitaplar().slice().sort(function(a,b){return (Number(b.satilan)||0)-(Number(a.satilan)||0);}).slice(0,5);
 var kisa=function(arr,f,adetAl){return '<ol class="kt-sira">'+arr.map(function(x,i){var k=f(x);return '<li onclick="soKitapDetay('+id(k.id)+')"><span class="kt-rank">'+(i+1)+'</span><div class="kt-ad"><b>'+e(k.baslik)+'</b><small>'+e(k.yazar)+'</small></div><div class="kt-deger"><b>'+e(sayi(adetAl(x,k)))+'</b><small>adet</small></div></li>';}).join("")+'</ol>';};
 return '<section class="kt-panel"><h3>'+e(rek.hafta.no)+'. hafta çok satanlar</h3><p>Satış adedine göre. Oklar geçen haftaya göre sırayı gösterir.</p>'+geriSayimHtml()+sira+'</section>'+
  (gecen.length?'<section class="kt-panel"><h3>Geçen hafta</h3>'+kisa(gecen,function(x){return kitapBul(x.kitap_id);},function(x){return x.adet;})+'</section>':'')+
  (tum.length?'<section class="kt-panel"><h3>Tüm zamanların en çok satanları</h3>'+kisa(tum,function(k){return k;},function(x,k){return k.satilan;})+'</section>':'');
}
function yayineviHtml(){
 if(yvAcik!=null&&yayineviBul(yvAcik))return yayineviSayfaHtml(yvAcik);
 if(!rek)return tumYayinevleriHtml()+ '<div class="kt-panel"><div class="kt-bos">Yayınevi sıralaması şu anda yüklenemedi.</div></div>';
 var y=(rek.yayinevleri||[]).filter(function(x){return Number(x.kitap)>0||Number(x.toplam_adet)>0;});
 var en=Math.max(1,Number(y[0]&&y[0].hafta_adet)||0);
 var yl=y.length?'<ol class="kt-sira">'+y.map(function(x,i){
   var ga=Number(x.gecen_adet)||0,ha=Number(x.hafta_adet)||0;
   var sh=sahipBul(x);
   return '<li'+(id(x.id)?' onclick="soYayineviAc('+id(x.id)+')"':' style="cursor:default"')+'><span class="kt-rank">'+(i+1)+'</span><div class="kt-ad"><b>'+e(x.ad)+(x.benim?'<span class="kt-sen">Senin</span>':'')+'</b>'+
    '<small>'+(sh?'Sahibi '+e(sh)+' · ':'')+e(sayi(x.kitap))+' kitap · toplam '+e(sayi(x.toplam_adet))+' satış'+(Number(x.imza)>0?' · '+e(sayi(x.imza))+' imza günü':'')+'</small>'+
    '<div class="kt-cubuk"><i style="width:'+Math.max(ha?4:0,Math.round(ha/en*100))+'%"></i></div></div>'+
    '<div class="kt-deger"><b>'+e(sayi(ha))+'</b><small>bu hafta</small><div class="kt-not">'+e(para(x.hafta_ciro))+'</div></div></li>';
  }).join("")+'</ol>':'<div class="kt-bos">Henüz kitap basan yayınevi yok.</div>';
 var yz=(rek.yazarlar||[]);
 var yzl=yz.length?'<ol class="kt-sira">'+yz.slice(0,10).map(function(x,i){
   return '<li data-kad="'+e(x.kad)+'" onclick="soKitapOyuncu(this)"><span class="kt-rank">'+(i+1)+'</span><div class="kt-ad"><b>'+e(x.kad)+(x.benim?'<span class="kt-sen">Sen</span>':'')+'</b><small>'+e(sayi(x.kitap))+' kitap · bu hafta '+e(sayi(x.hafta_adet))+' satış</small></div>'+
    '<div class="kt-deger"><b>'+e(sayi(x.toplam_adet))+'</b><small>toplam</small></div></li>';
  }).join("")+'</ol>':'<div class="kt-bos">Henüz yayımlanmış yazar yok.</div>';
 return tumYayinevleriHtml()+'<section class="kt-panel"><h3>Yayınevleri yarışı</h3><p>Bu haftaki satış adedine göre sıralanır; tutar bu haftanın cirosudur.</p>'+geriSayimHtml()+yl+'</section>'+
  '<section class="kt-panel"><h3>Yazarlar</h3><p>Toplam satışa göre ilk 10 yazar.</p>'+yzl+'</section>'+yazBtn();
}
/* 25.11.2026: yayınevi sahipleri — uc_kitap_panel yayinevleri {sahip, bekleyen, yayinlanan} */
function panelYayinevleri(){return Array.isArray(veri&&veri.yayinevleri)?veri.yayinevleri:[];}
function sahipBul(x){var p=panelYayinevleri().filter(function(y){return (x.id!=null&&id(y.id)===id(x.id))||y.ad===x.ad;})[0];return p&&p.sahip?p.sahip:"";}
/* 27.11.2026: herkese açık yayınevi sayfası — sahibi/ortakları, çıkardığı kitaplar, yazarları, imza günleri */
function yayineviBul(x){var n=id(x);return panelYayinevleri().filter(function(y){return id(y.id)===n;})[0]||null;}
function yvKitaplar(yid){var n=id(yid);return kitaplar().filter(function(k){return id(k.yayinevi)===n;});}
function yvRek(y){return ((rek&&rek.yayinevleri)||[]).filter(function(x){return (x.id!=null&&id(x.id)===id(y.id))||x.ad===y.ad;})[0]||null;}
function yvSahipYazi(y){
 var o=Array.isArray(y.ortaklar)?y.ortaklar:[];
 if(o.length>1)return o.length+" ortaklı · yöneten "+(y.yonetici||y.sahip||o[0].kad);
 var s=y.sahip||y.yonetici||(o[0]&&o[0].kad);
 return s?"Sahibi "+s:"Sahibi belirsiz";
}
function yvArma(y,buyuk){
 var ad=String(y.ad||"?").trim(),h=ozet(String(y.id)+"|"+ad),p=PALET[h%PALET.length];
 var bas=ad.split(/\s+/).slice(0,2).map(function(w){return w.charAt(0);}).join("").toLocaleUpperCase("tr-TR");
 return '<span class="kt-yvk-arma'+(buyuk?' buyuk':'')+'" style="background:linear-gradient(145deg,'+p[0]+','+p[1]+')" aria-hidden="true">'+e(bas)+'</span>';
}
function tumYayinevleriHtml(){
 var l=panelYayinevleri().slice().sort(function(a,b){return (Number(b.yayinlanan)||0)-(Number(a.yayinlanan)||0)||String(a.ad).localeCompare(String(b.ad),"tr");});
 if(!l.length)return "";
 var benim=(veri&&veri.benim_yayinevleri||[]).map(id);
 return '<div class="kt-bolum" style="margin-top:4px"><div class="kt-bolum-bas"><h2>Yayınevleri</h2><span>'+e(sayi(l.length))+' yayınevi</span></div>'+
  '<p class="kt-not" style="margin:-4px 0 12px">Bir yayınevine dokun: sahibini, çıkardığı kitapları ve yazarlarını gör.</p><div class="kt-yvk-liste">'+l.map(function(y){
   var top=yvKitaplar(y.id).reduce(function(t,k){return t+(Number(k.satilan)||0);},0);
   return '<button type="button" class="kt-yvk" onclick="soYayineviAc('+id(y.id)+')">'+yvArma(y)+'<span class="kt-yvk-bilgi"><b>'+e(y.ad)+(benim.indexOf(id(y.id))>=0?'<span class="kt-sen">Senin</span>':'')+'</b>'+
    '<small>'+e(yvSahipYazi(y))+(y.il?' · '+e(y.il):'')+'</small><small>'+e(sayi(y.yayinlanan))+' kitap · '+e(sayi(top))+' satış'+(Number(y.bekleyen)>0?' · '+e(sayi(y.bekleyen))+' dosya bekliyor':'')+'</small></span><span class="ok" aria-hidden="true">›</span></button>';
  }).join("")+'</div></div>';
}
function yayineviSayfaHtml(yid){
 var y=yayineviBul(yid),r=yvRek(y)||{},kl=yvKitaplar(y.id).slice().sort(function(a,b){return (Number(b.satilan)||0)-(Number(a.satilan)||0)||id(b.id)-id(a.id);});
 var top=kl.reduce(function(t,k){return t+(Number(k.satilan)||0);},0);
 var benim=(veri&&veri.benim_yayinevleri||[]).map(id).indexOf(id(y.id))>=0;
 var o=Array.isArray(y.ortaklar)?y.ortaklar.slice():[];
 if(!o.length&&(y.sahip||y.yonetici))o=[{kad:y.sahip||y.yonetici,pay:null}];
 var kisi=function(kad,sag){return '<div class="kt-kisi"><button type="button" data-kad="'+e(kad)+'" onclick="soKitapOyuncu(this)">'+e(kad)+'</button><span>'+sag+'</span></div>';};
 var yon=y.yonetici||y.sahip||"";
 var sahipler=o.length?o.map(function(x){
   var et=[];if(x.pay!=null)et.push("%"+String(x.pay).replace(".",","));if(o.length>1&&x.kad===yon)et.push("yönetici");
   return kisi(x.kad,e(et.join(" · ")));
  }).join("")+(Number(y.ortak_sayisi)>o.length?'<p class="kt-not" style="margin-top:6px">ve '+e(sayi(Number(y.ortak_sayisi)-o.length))+' küçük ortak daha</p>':''):'<div class="kt-bos">Sahiplik bilgisi yok.</div>';
 var ym={};kl.forEach(function(k){var a=k.yazar||"Bilinmiyor";(ym[a]=ym[a]||{kad:a,n:0,s:0}).n++;ym[a].s+=Number(k.satilan)||0;});
 var yz=Object.keys(ym).map(function(a){return ym[a];}).sort(function(a,b){return b.s-a.s||b.n-a.n;});
 var im=imzalar().filter(function(x){return (x.yayinevi!=null?id(x.yayinevi)===id(y.id):x.yayinevi_ad===y.ad)&&x.durum!=="bitti";});
 var tarih="";try{if(y.kurulus)tarih=new Date(y.kurulus).toLocaleDateString("tr-TR",{day:"numeric",month:"long",year:"numeric",timeZone:"Europe/Istanbul"});}catch(_){}
 return '<button type="button" class="kt-yv-geri" onclick="soYayineviAc(null)">‹ Bütün yayınevleri</button>'+
  '<div class="kt-yv-ust">'+yvArma(y,true)+'<div style="min-width:0"><h2>'+e(y.ad)+(benim?'<span class="kt-sen">Senin</span>':'')+'</h2>'+
  '<p>'+[y.il?e(y.il):"",tarih?"Kuruluş "+e(tarih):""].filter(Boolean).join(" · ")+'</p></div></div>'+
  '<div class="kt-ist"><div><b>'+e(sayi(kl.length))+'</b><small>yayımlanan kitap</small></div><div><b>'+e(sayi(top))+'</b><small>toplam satış</small></div><div><b>'+e(sayi(r.hafta_adet||0))+'</b><small>bu hafta satış</small></div>'+
  '<div><b>'+e(sayi(yz.length))+'</b><small>yazar</small></div><div><b>'+e(sayi(r.imza||0))+'</b><small>imza günü</small></div><div><b>'+e(sayi(y.bekleyen||0))+'</b><small>bekleyen dosya</small></div></div>'+
  '<section class="kt-panel"><h3>'+(o.length>1?"Ortakları":"Sahibi")+'</h3><p>Ada dokununca oyuncunun kartı açılır.</p><div style="margin-top:6px">'+sahipler+'</div></section>'+
  '<div class="kt-bolum"><div class="kt-bolum-bas"><h2>Çıkardığı kitaplar</h2><span>'+(kl.length?e(sayi(kl.length))+' kitap':'')+'</span></div>'+
  (kl.length?'<div class="kt-liste kt-iki">'+kl.map(satirHtml).join("")+'</div>':'<div class="kt-panel"><div class="kt-bos">Bu yayınevi henüz kitap yayımlamadı.</div></div>')+'</div>'+
  (yz.length?'<section class="kt-panel"><h3>Yazarları</h3><p>Bu yayınevinden kitabı çıkan yazarlar.</p><div style="margin-top:6px">'+yz.map(function(a){return kisi(a.kad,e(sayi(a.n))+' kitap · '+e(sayi(a.s))+' satış');}).join("")+'</div></section>':'')+
  (im.length?'<div class="kt-bolum"><div class="kt-bolum-bas"><h2>İmza günleri</h2><span>'+e(sayi(im.length))+'</span></div>'+im.map(biletHtml).join("")+'</div>':'')+
  (benim?'':yazBtn().replace("Kitap yaz ya da yayınevini yönet","Bu yayınevine kitap gönder"));
}
function biletHtml(ev){
 var t=simdiMs(),z=trTarih(ev.baslangic),canli=ev.durum==="canli",bitti=ev.durum==="bitti";
 var hedef=Math.max(1,Number(ev.hedef)||Number(ev.satis)||1),yuzde=Math.min(100,Math.round((Number(ev.satis)||0)/hedef*100));
 var durum=canli?'<i></i>Masa açık · kapanışa <span data-kt-sayac="'+e(ev.bitis)+'">'+e(kalanYaz(new Date(ev.bitis)-t))+'</span>':
  bitti?'Tamamlandı':'<span data-kt-sayac="'+e(ev.baslangic)+'">'+e(kalanYaz(new Date(ev.baslangic)-t))+'</span> sonra';
 var b=[];
 if(canli&&!ev.yazar_benim&&!ev.aldim&&Number(ev.stok)>0)b.push('<button type="button" class="birincil" onclick="soImzaAl('+id(ev.id)+')">İmzalı nüsha al · '+e(para(ev.fiyat))+'</button>');
 if(ev.imzali_aldim)b.push('<span class="tamam">İmzalı nüshan alındı</span>');
 else if(canli&&ev.aldim&&!ev.yazar_benim)b.push('<span class="tamam">Kitap zaten kitaplığında</span>');
 if(!bitti&&!ev.benim&&!ev.yazar_benim){
  if(ev.katildim){if(!ev.imzali_aldim)b.push('<span class="tamam">Katılıyorsun</span>');}
  else b.push('<button type="button" class="'+(canli?'':'birincil')+'" onclick="soImzaKatil('+id(ev.id)+')">'+(canli?"Masaya uğra":"Katılacağım")+'</button>');
 }
 if(ev.benim&&ev.durum==="planli")b.push('<button type="button" onclick="soImzaIptal('+id(ev.id)+')">İptal et</button>');
 var alt=bitti?e(sayi(ev.satis))+' nüsha imzalandı · '+e(sayi(ev.katilim))+' okur katıldı':
  e(sayi(ev.satis))+' / '+e(sayi(hedef))+' nüsha · '+e(sayi(ev.katilim))+' okur'+(Number(ev.yerel)>0?' ('+e(sayi(ev.yerel))+' yerel)':'')+(Number(ev.stok)<=0&&canli?' · masada kitap kalmadı':'');
 return '<article class="kt-bilet '+(canli?'canli':bitti?'bitti':'planli')+'">'+
  '<div class="kt-bilet-tarih"><b>'+e(z.g)+'</b><span>'+e(z.a)+'</span><time>'+e(z.s)+'</time></div>'+
  '<div class="kt-bilet-govde"><span class="kt-durum">'+durum+'</span>'+
  '<h4>'+e(ev.baslik)+'</h4><p>'+e(ev.yazar)+' · '+SVG.konum+e(ev.il_ad)+'</p><p>'+e(ev.yayinevi_ad)+(ev.benim?' · Düzenleyen sensin':'')+'</p>'+
  (ev.durum==="planli"?'<p style="margin-top:6px">Masada tahmini '+e(sayi(hedef))+' nüsha; her katılan okur bu sayıyı artırır.</p>':'<div class="kt-ilerleme"><i style="width:'+yuzde+'%"></i></div><small>'+alt+'</small>')+
  (b.length?'<div class="kt-bilet-eylem">'+b.join("")+'</div>':'')+'</div></article>';
}
function imzaHtml(){
 if(!rek)return '<div class="kt-panel"><div class="kt-bos">İmza günleri şu anda yüklenemedi.</div></div>';
 var d=duzenlenebilir(),l=imzalar(),k=rek.kurallar||{};
 var c=l.filter(function(x){return x.durum==="canli";}),p=l.filter(function(x){return x.durum==="planli";}),b=l.filter(function(x){return x.durum==="bitti";});
 var giris='<section class="kt-imza-giris"><h3>İmza günü</h3><p>Yazar ya da yayınevi bir ilin kültür merkezinde '+e(k.sure_saat||3)+' saatlik imza masası kurar. Masa açıkken kitap satılır; büyük şehirde ve katılan okur arttıkça daha çok satılır.</p>'+
  '<ul><li>Salon kirası ilin büyüklüğüne göre değişir ve o ilin belediyesine ödenir.</li><li>Aynı ildeki okurun katılımı iki kat sayılır.</li><li>Stokta en az '+e(k.min_stok||10)+' nüsha olmalı; aynı kitaba '+e(k.bekleme_saat||48)+' saatte bir imza günü.</li></ul>'+
  (d.length?'<button type="button" class="kt-buyuk" onclick="soImzaDuzenleAc()">'+SVG.kalem+'İmza günü düzenle</button>':
   '<p style="margin:12px 0 0;font-size:12.5px;color:var(--mut)">İmza günü düzenlemek için yayımlanmış bir kitabın yazarı ya da yayınevinin yöneticisi olmalısın.</p>')+'</section>';
 var bolum=function(bas,arr,bos){return '<div class="kt-bolum"><div class="kt-bolum-bas"><h2>'+bas+'</h2><span>'+(arr.length?sayi(arr.length):"")+'</span></div>'+(arr.length?arr.map(biletHtml).join(""):'<div class="kt-panel"><div class="kt-bos">'+bos+'</div></div>')+'</div>';};
 return giris+(c.length?bolum("Şimdi imza masasında",c,""):"")+bolum("Yaklaşan imza günleri",p,"Planlanmış imza günü yok. İlk masayı sen kurabilirsin.")+(b.length?bolum("Son imza günleri",b.slice(0,8),""):"");
}
/* ---------- Dosyalarım (26.11.2026) ----------
   Yazar gönderdiği kitabı ve her yayınevindeki aşamasını görür: gönderildi → yayınevi gördü → karar (72 saat).
   Metni okur, başka yayınevine de gönderir (aynı anda en çok 3), bekleyen dosyayı geri çeker.
   Yayınevi yöneticisine gelen dosyalar listelenir. Sunucu: uc_kitap_panel + uc_kitap_islem (kopya_gonder, geri_cek). */
var RET={ret:"Yayınevi reddetti",sure:"Süre doldu, dosya sana iade edildi",geri_cekti:"Dosyayı geri çektin",baska_yayinevi:"Başka yayınevinde yayımlandığı için geri çekildi"};
function yeniSunucu(){return !!(veri&&veri.inceleme_saat);}
function tumKitaplar(){return Array.isArray(veri&&veri.kitaplar)?veri.kitaplar:[];}
function tumBul(x){var n=id(x);return tumKitaplar().find(function(k){return id(k.id)===n;});}
function benimYayinevleri(){return (Array.isArray(veri&&veri.benim_yayinevleri)?veri.benim_yayinevleri:[]).map(id);}
function eserGruplari(){
 var m={},sira=[];
 tumKitaplar().filter(function(k){return k&&k.yazar_benim===true;}).forEach(function(k){
  var g=id(k.eser)||id(k.id);
  if(!m[g]){m[g]=[];sira.push(g);}
  m[g].push(k);
 });
 return sira.map(function(g){
  var l=m[g].slice().sort(function(a,b){return new Date(b.gonderim||0)-new Date(a.gonderim||0)||id(b.id)-id(a.id);});
  return {eser:g,dosyalar:l,ana:l.find(function(k){return k.durum==="yayinda";})||l[0]};
 }).sort(function(a,b){return new Date(b.ana.gonderim||0)-new Date(a.ana.gonderim||0);});
}
function gelenDosyalar(){
 var b=benimYayinevleri();
 return tumKitaplar().filter(function(k){return k&&k.durum==="teklif"&&b.indexOf(id(k.yayinevi))>=0;});
}
function kisaTarih(ts){var z=trTarih(ts);return z.g?z.g+" "+z.a+" "+z.s:"—";}
function sonKarar(k){
 if(k.son_karar)return new Date(k.son_karar).getTime();
 var g=new Date(k.gonderim||0).getTime();return g?g+(Number(veri&&veri.inceleme_saat)||72)*3600e3:0;
}
function adimlarHtml(k){
 var a=[];
 a.push('<li class="ok"><b>Gönderildi</b><small>'+e(kisaTarih(k.gonderim))+'</small></li>');
 if(k.durum==="teklif"){
  if(yeniSunucu())a.push(k.incelendi?'<li class="ok"><b>Yayınevi dosyanı gördü</b><small>'+e(kisaTarih(k.incelendi))+'</small></li>':'<li class="simdi"><b>Yayınevinin dosyayı açması bekleniyor</b><small>Yayınevi yöneticisine bildirim gitti.</small></li>');
  var son=sonKarar(k);
  a.push('<li class="'+(k.incelendi?"simdi":"")+'"><b>Karar bekleniyor</b><small>'+(son?(yeniSunucu()?'En geç '+e(kisaTarih(son))+' · kalan <span data-kt-sayac="'+e(new Date(son).toISOString())+'">'+e(kalanYaz(son-simdiMs()))+'</span>. Karar çıkmazsa dosya sana iade edilir.':'Gönderimden bu yana '+e(kalanYaz(simdiMs()-new Date(k.gonderim).getTime()))+' geçti.'):'')+'</small></li>');
  a.push('<li><b>Baskı ve yayım</b><small>Yayınevi onaylarsa baskı giderini öder, kitabın vitrine çıkar.</small></li>');
 }else if(k.durum==="yayinda"){
  if(k.incelendi)a.push('<li class="ok"><b>Yayınevi dosyanı gördü</b><small>'+e(kisaTarih(k.incelendi))+'</small></li>');
  a.push('<li class="ok"><b>Onaylandı, basıldı ve yayımlandı</b><small>'+e(kisaTarih(k.yayin||k.karar))+' · '+e(sayi(k.satilan))+' satış · stok '+e(sayi(k.stok))+'</small></li>');
 }else{
  if(k.incelendi&&k.ret_kod!=="geri_cekti")a.push('<li class="ok"><b>Yayınevi dosyanı gördü</b><small>'+e(kisaTarih(k.incelendi))+'</small></li>');
  a.push('<li class="kirmizi"><b>'+e(RET[k.ret_kod]||"Yayınevi reddetti")+'</b><small>'+(k.karar?e(kisaTarih(k.karar)):'')+'</small>'+(k.ret_gerekce?'<span class="kt-gerekce">Gerekçe: '+e(k.ret_gerekce)+'</span>':'')+'</li>');
 }
 return '<ol class="kt-adimlar">'+a.join("")+'</ol>';
}
function durumEtiket(k){
 return k.durum==="yayinda"?"YAYINDA":k.durum==="teklif"?"İNCELEMEDE":k.ret_kod==="geri_cekti"?"GERİ ÇEKİLDİ":k.ret_kod==="sure"?"İADE EDİLDİ":k.ret_kod==="baska_yayinevi"?"GERİ ÇEKİLDİ":"REDDEDİLDİ";
}
function eserHtml(g){
 var k=g.ana,yayinda=g.dosyalar.some(function(x){return x.durum==="yayinda";});
 var bekleyen=g.dosyalar.filter(function(x){return x.durum==="teklif";});
 var ozetYazi=yayinda?"Yayında · "+e(k.yayinevi_ad):bekleyen.length?bekleyen.length+" yayınevinde inceleniyor":"Şu an hiçbir yayınevinde değil — yeniden gönderebilirsin";
 var gecmis=g.dosyalar.filter(function(x){return !yayinda||x.durum==="yayinda";});
 if(yayinda)gecmis=g.dosyalar.filter(function(x){return x.durum==="yayinda";});
 var bloklar=gecmis.map(function(x){
  var d=[];
  if(x.durum==="teklif"&&yeniSunucu())d.push('<button type="button" class="tehlike" onclick="soDosyaGeriCek('+id(x.id)+')">Bu yayınevinden geri çek</button>');
  return '<div class="kt-yv"><div class="kt-yv-bas"><b>'+e(x.yayinevi_ad||"Yayınevi")+(x.yayinevi_sahip?' <span class="kt-not">· sahibi '+e(x.yayinevi_sahip)+'</span>':'')+'</b><small>'+durumEtiket(x)+'</small></div>'+adimlarHtml(x)+(d.length?'<div class="kt-dugmeler">'+d.join("")+'</div>':'')+'</div>';
 }).join("");
 var b=[];
 b.push('<button type="button" onclick="soDosyaOku('+id(k.id)+')">Kitabımı oku</button>');
 if(yayinda)b.push('<button type="button" class="birincil" onclick="soKitapDetay('+id(k.id)+')">Vitrinde gör</button>');
 else if(yeniSunucu()&&bekleyen.length<3)b.push('<button type="button" class="birincil" onclick="soDosyaGonder('+id(k.id)+')">'+(bekleyen.length?"Başka yayınevine de gönder":"Bir yayınevine gönder")+'</button>');
 else if(!yeniSunucu()&&typeof window.ucYeniAc==="function")b.push('<button type="button" class="birincil" onclick="ucYeniAc(\'kitap\')">Yayınevi işlemleri</button>');
 return '<article class="kt-dosya"><div class="kt-dosya-ust">'+kapak(k,"s")+'<div class="bilgi"><h3>'+e(k.baslik)+'</h3><p>'+e(k.tur||"Kitap")+' · senin fiyatın '+e(para(k.fiyat))+'</p><p style="margin-top:4px;color:var(--txt2);font-weight:700">'+ozetYazi+'</p></div></div>'+
  bloklar+'<div class="kt-dugmeler">'+b.join("")+'</div>'+
  (!yayinda&&bekleyen.length>0&&bekleyen.length<3&&yeniSunucu()?'<p class="kt-not" style="margin-top:8px">Aynı kitabı aynı anda en çok 3 yayınevine sunabilirsin. İlk yayımlayan yayınevi kazanır, diğer dosyalar kendiliğinden geri çekilir.</p>':'')+
  '</article>';
}
function dosyalarHtml(){
 var gr=eserGruplari(),gelen=gelenDosyalar(),out="";
 out+='<section class="kt-panel"><h3>Dosyalarım</h3><p>Yayınevine gönderdiğin kitapları ve her yayınevindeki aşamasını buradan takip edersin. '+(yeniSunucu()?'Yayınevinin karar için '+e(veri.inceleme_saat)+' saati var; karar çıkmazsa dosya sana iade edilir ve hemen başka yayınevine gönderebilirsin.':'')+'</p>'+
  (typeof window.ucYeniAc==="function"?'<div class="kt-dugmeler"><button type="button" class="birincil" onclick="ucYeniAc(\'kitap\')">Yeni kitap yaz ve gönder</button></div>':'')+'</section>';
 if(gelen.length){
  out+='<section class="kt-panel"><h3>Yayınevine gelen dosyalar</h3><p>Yönettiğin yayınevinde karar bekleyen '+e(sayi(gelen.length))+' dosya var. Süresinde karar vermezsen dosya yazarına iade edilir.</p><ol class="kt-sira">'+
   gelen.map(function(k){var son=sonKarar(k);
    return '<li style="cursor:default"><div class="kt-ad"><b>'+e(k.baslik)+'</b><small>'+e(k.yazar||"")+' · '+e(k.yayinevi_ad||"")+'</small></div>'+
     '<div class="kt-deger"><b style="font-size:14px">'+(son?'<span data-kt-sayac="'+e(new Date(son).toISOString())+'">'+e(kalanYaz(son-simdiMs()))+'</span>':'—')+'</b><small>karar için kalan</small></div></li>';
   }).join("")+'</ol>'+(typeof window.ucYeniAc==="function"?'<div class="kt-dugmeler"><button type="button" class="birincil" onclick="ucYeniAc(\'kitap\')">Metni incele ve karar ver</button></div>':'')+'</section>';
 }
 if(!gr.length)out+='<div class="kt-panel"><div class="kt-bos">Henüz bir yayınevine kitap göndermedin. Gönderdiğin kitaplar ve aşamaları burada görünür.</div></div>';
 else out+=gr.map(eserHtml).join("");
 return out;
}
function dosyaAfisHtml(){
 var gr=eserGruplari(),bek=0,iade=0;
 gr.forEach(function(g){
  if(g.dosyalar.some(function(x){return x.durum==="yayinda";}))return;
  var b=g.dosyalar.filter(function(x){return x.durum==="teklif";}).length;
  if(b)bek++;else iade++;
 });
 var gelen=gelenDosyalar().length;
 if(!bek&&!iade&&!gelen)return "";
 var p=[];
 if(bek)p.push(bek+" kitabın incelemede");
 if(iade)p.push(iade+" kitabın yeniden gönderilmeyi bekliyor");
 if(gelen)p.push("yayınevine gelen "+gelen+" dosya karar bekliyor");
 return '<div class="kt-dosya-afis" role="button" tabindex="0" onclick="soKitapSekme(\'dosya\')" onkeydown="if(event.key===\'Enter\')soKitapSekme(\'dosya\')"><div><b>Dosyalarım</b><small>'+e(p.join(" · "))+'</small></div><span class="ok" aria-hidden="true">›</span></div>';
}
function gorunum(){
 var tabs=[["vitrin","Vitrin"],["dosya","Dosyalarım"],["liste","Liste"],["yayinevi","Yayınevleri"],["imza","İmza günü"]];
 var canliSay=imzalar().filter(function(x){return x.durum==="canli";}).length;
 var govde=sekme==="liste"?listeHtml():sekme==="yayinevi"?yayineviHtml():sekme==="imza"?imzaHtml():sekme==="dosya"?dosyalarHtml():vitrinHtml();
 return '<div class="segment kt-segment" role="tablist">'+tabs.map(function(t){
   return '<button type="button" role="tab" aria-selected="'+(sekme===t[0])+'" class="'+(sekme===t[0]?"aktif":"")+'" onclick="soKitapSekme(\''+t[0]+'\')">'+t[1]+(t[0]==="imza"&&canliSay?' <span style="display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--al);vertical-align:2px;margin-left:3px" aria-label="açık masa var"></span>':'')+'</button>';
  }).join("")+'</div><div id="ktGovde">'+govde+'</div>';
}
function ciz(){
 iskelet("Kitaplar ve yayınevleri",gorunum(),{geri:true});
 if(arama)window.soKitapFiltre(arama);
 sayacBaslat();
}
function sayacBaslat(){
 if(typeof canliDurdur==="function")canliDurdur();
 if(typeof D==="undefined"||!document.querySelector("[data-kt-sayac]"))return;
 D.canli=setInterval(function(){
  var el=document.querySelectorAll("[data-kt-sayac]");
  if(!el.length){clearInterval(D.canli);D.canli=null;return;}
  el.forEach(function(x){x.textContent=kalanYaz(new Date(x.getAttribute("data-kt-sayac"))-simdiMs());});
 },15000);
}

/* ---------- Dış işlevler ---------- */
window.soYayineviAc=function(yid){
 yvAcik=yid==null?null:id(yid);
 if(yvAcik!=null&&!yayineviBul(yvAcik)){yvAcik=null;if(typeof toast==="function")toast("Yayınevi bilgisi bulunamadı.",true);return;}
 sekme="yayinevi";
 try{sessionStorage.setItem("kt_sekme",sekme);}catch(_){}
 ciz();
 var ic=document.getElementById("icerik");if(ic)ic.scrollTop=0;
};
window.soKitapOyuncu=function(el){var k=el&&el.getAttribute("data-kad");if(k&&typeof oyuncuKart==="function")oyuncuKart(k);};
window.soKitapSekme=function(k){
 yvAcik=null;
 sekme=["vitrin","dosya","liste","yayinevi","imza"].indexOf(k)>=0?k:"vitrin";
 try{sessionStorage.setItem("kt_sekme",sekme);}catch(_){}
 var g=document.getElementById("ktGovde");
 if(!g||!veri){ciz();return;}
 ciz();
 var ic=document.getElementById("icerik");if(ic)ic.scrollTop=0;
};
window.soKitapFiltre=function(q){
 arama=String(q||"");
 var a=arama.trim().toLocaleLowerCase("tr-TR"),n=0;
 document.querySelectorAll("#soKitapKatalog [data-kt-ara]").forEach(function(el){
  var g=!a||el.getAttribute("data-kt-ara").indexOf(a)>=0;el.hidden=!g;el.style.display=g?"":"none";if(g)n++;
 });
 var b=document.getElementById("soKitapAraBos");if(b)b.hidden=n>0||!a;
};
window.soKitapVitriniAc=async function(){
 var n=++istek;
 stil();
 if(!veri&&typeof yukleniyor==="function")yukleniyor("Kitaplar ve yayınevleri");
 try{
  var s=await Promise.allSettled([API.rpc("uc_kitap_panel"),API.rpc("kitap_rekabet")]);
  if(n!==istek)return;
  if(s[0].status!=="fulfilled"||!s[0].value||!Array.isArray(s[0].value.kitaplar))throw (s[0].reason||new Error("Kitap listesi alınamadı."));
  veri=s[0].value;
  rek=s[1].status==="fulfilled"&&s[1].value&&typeof s[1].value==="object"?s[1].value:null;
  ciz();
 }catch(err){
  if(n!==istek)return;
  var mesaj=typeof hataCevir==="function"?hataCevir(err&&err.message||String(err)):String(err&&err.message||err);
  iskelet("Kitaplar ve yayınevleri",'<div class="kt-panel"><h3>Kitaplar yüklenemedi</h3><p>'+e(mesaj)+'</p><button class="btn ikinci" onclick="soKitapVitriniAc()">Tekrar dene</button></div>',{geri:true});
 }
};
window.soKitapDetay=function(kid){
 var k=kitapBul(kid);if(!k)return;
 var hm=haftaMap()[id(k.id)],sira=hm?hm.sira:null,stok=Number(k.stok)||0;
 var imza=imzalar().find(function(x){return id(x.kitap_id)===id(k.id)&&x.durum!=="bitti";});
 var duz=duzenlenebilir().find(function(x){return id(x.kitap_id)===id(k.id);});
 var roz=[];
 if(sira&&sira<=3)roz.push('<span class="kt-rozet altin">Bu hafta '+sira+'. sırada</span>');
 if(imzaliMi(k.id))roz.push('<span class="kt-rozet yesil">İmzalı nüshan var</span>');
 else if(k.aldim)roz.push('<span class="kt-rozet yesil">Kitaplığında</span>');
 if(imza)roz.push('<span class="kt-rozet kirmizi">'+(imza.durum==="canli"?"İmza masası açık":"İmza günü: "+e(trTarih(imza.baslangic).g+" "+trTarih(imza.baslangic).a))+'</span>');
 var b=[];
 var okunur=typeof k.icerik==="string"&&k.icerik.length>0;
 if(okunur)b.push('<button class="btn" onclick="soKitapOku('+id(k.id)+')">Kitabı oku</button>');
 if(!k.aldim&&!k.yazar_benim&&stok>0)b.push('<button class="btn" onclick="soKitapSatinal('+id(k.id)+')">Satın al · '+e(para(k.fiyat))+'</button>');
 if(imza)b.push('<button class="btn altin" onclick="modalKapat();soKitapSekme(\'imza\')">İmza gününü gör</button>');
 else if(duz&&!duz.engel)b.push('<button class="btn altin" onclick="soImzaDuzenleAc('+id(k.id)+')">İmza günü düzenle</button>');
 b.push('<button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
 modal('<div class="kt-detay-ust">'+kapak(k,"l")+'<div class="bilgi"><span class="tur">'+e(k.tur||"Kitap")+'</span><h3>'+e(k.baslik)+'</h3>'+
  '<p>'+e(k.yazar||"Bilinmiyor")+'</p><p style="color:var(--mut)">'+(id(k.yayinevi)&&yayineviBul(k.yayinevi)?'<a href="#" style="color:inherit;text-decoration:underline;text-underline-offset:3px" onclick="if(typeof modalKapat===\'function\')modalKapat();soYayineviAc('+id(k.yayinevi)+');return false">'+e(k.yayinevi_ad||"—")+' ›</a>':e(k.yayinevi_ad||"—"))+'</p>'+(roz.length?'<div class="kt-rozetler">'+roz.join("")+'</div>':'')+'</div></div>'+
  (k.ozet?'<p class="kt-ozet">'+e(String(k.ozet).slice(0,600))+'</p>':'')+
  '<div class="kt-istat"><div><b>'+e(para(k.fiyat))+'</b><small>Fiyat</small></div><div><b>'+e(sayi(k.satilan))+'</b><small>Toplam satış</small></div>'+
  '<div><b>'+e(sayi(hm?hm.adet:0))+'</b><small>Bu hafta</small></div><div><b>'+e(sayi(stok))+'</b><small>Stok</small></div></div>'+
  (duz&&duz.engel&&!imza?'<p class="kt-not" style="margin-top:8px">İmza günü: '+e(duz.engel)+'</p>':'')+b.join(""));
};
window.soKitapOku=function(kid){
 var k=kitapBul(kid);
 if(!k||typeof k.icerik!=="string"||!k.icerik){
  if(typeof toast==="function")toast("Kitabı okumak için önce satın alman gerekiyor.",true);
  return;
 }
 modal('<h3 style="font-family:Georgia,serif">'+e(k.baslik)+'</h3><p class="alt">'+e(k.yazar||"—")+' · '+e(k.yayinevi_ad||"—")+'</p>'+
  '<div class="kt-oku">'+e(k.icerik)+'</div><button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
};
window.soKitapSatinal=async function(kid){
 var k=kitapBul(kid);
 if(!k||islemde)return;
 if(k.aldim||k.yazar_benim||Number(k.stok)<=0){if(typeof toast==="function")toast("Bu kitap şu anda satın alınamıyor.",true);return;}
 var acik=imzalar().find(function(x){return id(x.kitap_id)===id(k.id)&&x.durum==="canli";});
 if(acik){modalKapat();return window.soImzaAl(acik.id);}
 var onay=typeof onayla!=="function"||await onayla("Kitap satın al",e(k.baslik)+" için cüzdanından "+e(para(k.fiyat))+" düşülecek.","Satın al");
 if(!onay)return;
 islemde=true;
 try{
  await API.rpc("uc_kitap_islem",{p_islem:"satinal",p_id:id(kid),p_veri:{}});
  if(typeof toast==="function")toast("Kitap kitaplığına eklendi. Artık okuyabilirsin.");
  if(typeof durumYenile==="function")Promise.resolve(durumYenile()).catch(function(){});
  await window.soKitapVitriniAc();
 }catch(err){
  if(typeof toast==="function")toast(typeof hataCevir==="function"?hataCevir(err.message||String(err)):String(err.message||err),true);
 }finally{islemde=false;}
};

/* ---------- İmza günü işlemleri ---------- */
async function imzaIslem(islem,eid,veriObj,basari){
 if(islemde)return null;islemde=true;
 try{
  var r=await API.rpc("kitap_imza_islem",{p_islem:islem,p_id:id(eid),p_veri:veriObj||{}});
  if(typeof modalKapat==="function")modalKapat();
  if(basari&&typeof toast==="function")toast(basari);
  if(typeof durumYenile==="function")Promise.resolve(durumYenile()).catch(function(){});
  await window.soKitapVitriniAc();
  return r;
 }catch(err){
  if(typeof toast==="function")toast(typeof hataCevir==="function"?hataCevir(err.message||String(err)):String(err.message||err),true);
  return null;
 }finally{islemde=false;}
}
window.soImzaKatil=function(eid){return imzaIslem("katil",eid,{},"Katılımın kaydedildi. Masaya uğrayan her okur satışı artırır.");};
window.soImzaAl=async function(eid){
 var ev=imzalar().find(function(x){return id(x.id)===id(eid);});if(!ev)return;
 var ok=typeof onayla!=="function"||await onayla("İmzalı nüsha al",e(ev.yazar)+" «"+e(ev.baslik)+"» kitabını senin için imzalayacak. Cüzdanından "+e(para(ev.fiyat))+" düşülecek.","Satın al");
 if(ok)return imzaIslem("imzali_al",eid,{},"İmzalı nüshan kitaplığına eklendi.");
};
window.soImzaIptal=async function(eid){
 var ev=imzalar().find(function(x){return id(x.id)===id(eid);});if(!ev)return;
 var iade=Math.round((Number(ev.maliyet)||0)/2);
 var ok=typeof onayla!=="function"||await onayla("İmza gününü iptal et","Salon kirasının yarısı ("+e(para(iade))+") iade edilir, kalan yarısı belediyede kalır. Katılan okurlara bildirim gider.","İptal et",true);
 if(ok)return imzaIslem("iptal",eid,{},"İmza günü iptal edildi.");
};
function saatSecenek(){var h=[];for(var s=0;s<24;s++)for(var d=0;d<60;d+=30){var x=String(s).padStart(2,"0")+":"+String(d).padStart(2,"0");h.push(x);}return h;}
function istTarih(ms){
 var p={};new Intl.DateTimeFormat("en-CA",{timeZone:"Europe/Istanbul",year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",hourCycle:"h23"}).formatToParts(new Date(ms)).forEach(function(x){p[x.type]=x.value;});
 return {gun:p.year+"-"+p.month+"-"+p.day,saat:p.hour+":"+p.minute};
}
function gunSecenek(){
 var o=[],t=simdiMs();
 for(var i=0;i<8;i++){
  var ms=t+i*86400e3,g=istTarih(ms).gun,z=trTarih(ms);
  if(o.some(function(x){return x[0]===g;}))continue;
  o.push([g,i===0?"Bugün":i===1?"Yarın":z.g+" "+z.a+" "+z.hg]);
 }
 return o;
}
window.soImzaDuzenleAc=function(onSecili){
 var d=duzenlenebilir();
 if(!d.length){if(typeof toast==="function")toast("İmza günü düzenleyebileceğin yayımlanmış bir kitabın yok.",true);return;}
 var uc=(rek.ucretler||[]).slice().sort(function(a,b){return String(a.ad).localeCompare(String(b.ad),"tr");});
 var benimIl=id(rek.il)||34;
 var secili=d.find(function(x){return id(x.kitap_id)===id(onSecili)&&!x.engel;})||d.find(function(x){return !x.engel;})||d[0];
 // Varsayılan: en az 1 saat sonrası, bir sonraki yarım saat (Türkiye UTC+3, yarım saat sınırları aynı)
 var bas=istTarih(Math.ceil((simdiMs()+60*60000)/1800000)*1800000),gun=bas.gun,saat=bas.saat;
 modal('<h3>İmza günü düzenle</h3><p class="alt">Masa seçtiğin saatte açılır ve '+e((rek.kurallar||{}).sure_saat||3)+' saat sürer.</p>'+
  '<form class="kt-form" id="ktImzaForm">'+
  '<div class="alan"><label for="ktImzaKitap">Kitap</label><select id="ktImzaKitap">'+d.map(function(x){
    return '<option value="'+id(x.kitap_id)+'"'+(x.engel?' disabled':'')+(x===secili?' selected':'')+'>'+e(x.baslik)+(x.engel?' — uygun değil':' · stok '+sayi(x.stok))+'</option>';
   }).join("")+'</select></div>'+
  '<div class="alan"><label for="ktImzaIl">İl</label><select id="ktImzaIl">'+uc.map(function(x){
    return '<option value="'+id(x.il)+'"'+(id(x.il)===benimIl?' selected':'')+'>'+e(x.ad)+' · '+e(para(x.ucret))+'</option>';
   }).join("")+'</select></div>'+
  '<div class="alan"><label for="ktImzaGun">Başlangıç</label><div class="iki"><select id="ktImzaGun" aria-label="Gün">'+gunSecenek().map(function(x){return '<option value="'+x[0]+'"'+(x[0]===gun?' selected':'')+'>'+e(x[1])+'</option>';}).join("")+'</select>'+
  '<select id="ktImzaSaat" aria-label="Saat">'+saatSecenek().map(function(x){return '<option'+(x===saat?' selected':'')+'>'+x+'</option>';}).join("")+'</select></div></div>'+
  '<div class="alan" id="ktImzaOdemeAlan"></div>'+
  '<div class="kt-tahmin" id="ktImzaTahmin" aria-live="polite"></div>'+
  '<button class="btn" type="submit" id="ktImzaGonder">İmza gününü planla</button></form>'+
  '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 var $k=document.getElementById("ktImzaKitap"),$i=document.getElementById("ktImzaIl"),$g=document.getElementById("ktImzaGun"),$s=document.getElementById("ktImzaSaat");
 function secim(){
  var x=d.find(function(y){return id(y.kitap_id)===id($k.value);})||{},k=kitapBul(x.kitap_id)||{},u=uc.find(function(y){return id(y.il)===id($i.value);})||{};
  var oa=document.getElementById("ktImzaOdemeAlan");
  if(x.yazar&&x.yayinevi){
   var onceki=(document.querySelector('input[name="ktOdeme"]:checked')||{}).value||"yayinevi";
   oa.innerHTML='<label>Ödeme</label><div class="kt-secim"><label><input type="radio" name="ktOdeme" value="yayinevi"'+(onceki==="yayinevi"?" checked":"")+'> Yayınevi kasası</label><label><input type="radio" name="ktOdeme" value="cuzdan"'+(onceki==="cuzdan"?" checked":"")+'> Cüzdanım</label></div>';
  }else oa.innerHTML='<p class="kt-not">Ödeme: '+(x.yayinevi?e(x.yayinevi_ad)+' kasasından':'cüzdanından')+'</p>';
  var iso=$g.value+"T"+$s.value+":00+03:00",ms=new Date(iso).getTime(),now=simdiMs(),hata="";
  if(!(ms>=now+15*60000))hata="Başlangıç en erken 15 dakika sonrası olabilir.";
  else if(ms>now+7*86400e3)hata="İmza günü en geç 7 gün sonrasına planlanabilir.";
  var tal=Math.max(.1,Number(u.talep)||1),fiyat=Math.max(100,Number(k.fiyat)||400);
  var tah=Math.min((rek.kurallar||{}).tavan||150,Math.round(30*Math.sqrt(tal)*Math.pow(400/fiyat,.55)));
  var stok=Number(x.stok)||0;
  document.getElementById("ktImzaTahmin").innerHTML=(x.engel?'<span class="hata">'+e(x.engel)+'</span>':
   'Salon kirası <b>'+e(para(u.ucret))+'</b>, '+e(u.ad||"")+' belediyesine ödenir.<br>Katılımsız tahmini satış <b>'+e(sayi(Math.min(tah,stok)))+' nüsha</b>'+(tah>stok?' (stok '+e(sayi(stok))+' ile sınırlı)':'')+'. Katılan her okur bu sayıyı artırır.'+
   (hata?'<br><span class="hata">'+e(hata)+'</span>':''));
  document.getElementById("ktImzaGonder").disabled=!!(x.engel||hata);
  document.getElementById("ktImzaGonder").textContent="İmza gününü planla · "+para(u.ucret);
  return {x:x,iso:iso,hata:hata||x.engel};
 }
 [$k,$i,$g,$s].forEach(function(el){el.addEventListener("change",secim);});
 document.getElementById("ktImzaOdemeAlan").addEventListener("change",secim);
 secim();
 document.getElementById("ktImzaForm").onsubmit=function(ev){
  ev.preventDefault();
  var s=secim();if(s.hata){if(typeof toast==="function")toast(s.hata,true);return;}
  var od=(document.querySelector('input[name="ktOdeme"]:checked')||{}).value||(s.x.yayinevi?"yayinevi":"cuzdan");
  document.getElementById("ktImzaGonder").disabled=true;
  var onceki=sekme;sekme="imza";
  imzaIslem("duzenle",s.x.kitap_id,{il:id($i.value),baslangic:s.iso,odeme:od},"İmza günü planlandı. İldeki oyunculara duyuruldu.").then(function(r){
   if(r){try{sessionStorage.setItem("kt_sekme",sekme);}catch(_){}}
   else{sekme=onceki;var b=document.getElementById("ktImzaGonder");if(b)b.disabled=false;}
  });
 };
};

/* ---------- Dosyalarım işlemleri (26.11.2026) ---------- */
window.soDosyaOku=function(kid){
 var k=tumBul(kid);
 if(!k||typeof k.icerik!=="string"||!k.icerik){if(typeof toast==="function")toast("Kitabın metni şu anda açılamadı. Ekranı yenileyip tekrar dene.",true);return;}
 modal('<h3 style="font-family:Georgia,serif">'+e(k.baslik)+'</h3><p class="alt">'+e(k.tur||"Kitap")+' · '+e(sayi(k.icerik.length))+' karakter</p>'+
  (k.ozet?'<p class="kt-ozet" style="font-size:14px;margin-bottom:10px">'+e(String(k.ozet))+'</p>':'')+
  '<div class="kt-oku">'+e(k.icerik)+'</div><button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
};
async function dosyaIslem(islem,kid,veriObj,basari){
 if(islemde)return false;islemde=true;
 try{
  await API.rpc("uc_kitap_islem",{p_islem:islem,p_id:id(kid),p_veri:veriObj||{}});
  if(typeof modalKapat==="function")modalKapat();
  if(basari&&typeof toast==="function")toast(basari);
  sekme="dosya";try{sessionStorage.setItem("kt_sekme",sekme);}catch(_){}
  await window.soKitapVitriniAc();
  return true;
 }catch(err){
  if(typeof toast==="function")toast(typeof hataCevir==="function"?hataCevir(err.message||String(err)):String(err.message||err),true);
  return false;
 }finally{islemde=false;}
}
window.soDosyaGonder=function(kid){
 var k=tumBul(kid);if(!k)return;
 var g=id(k.eser)||id(k.id);
 var bekleyenYv=tumKitaplar().filter(function(x){return x.yazar_benim&&(id(x.eser)||id(x.id))===g&&x.durum==="teklif";}).map(function(x){return id(x.yayinevi);});
 var l=panelYayinevleri().filter(function(y){return bekleyenYv.indexOf(id(y.id))<0;}).sort(function(a,b){return String(a.ad).localeCompare(String(b.ad),"tr");});
 if(!l.length){if(typeof toast==="function")toast("Kitabını gönderebileceğin başka yayınevi yok.",true);return;}
 var sec=l.map(function(y){return '<option value="'+id(y.id)+'">'+e(y.ad+(y.sahip?" · sahibi "+y.sahip:"")+(Number(y.bekleyen)>0?" · "+y.bekleyen+" bekleyen dosya":"")+" · "+sayi(y.yayinlanan)+" yayımlanan")+'</option>';}).join("");
 var m=modal('<h3>'+(bekleyenYv.length?"Başka yayınevine de gönder":"Yayınevine gönder")+'</h3><p class="alt">«'+e(k.baslik)+'» · Metin, tanıtım ve '+e(para(k.fiyat))+' fiyatın aynen gider.</p>'+
  '<div class="kt-form" style="margin-top:12px"><div class="alan"><label for="ktDosyaYv">Yayınevi</label><select id="ktDosyaYv">'+sec+'</select></div></div>'+
  '<p class="kt-not" style="margin-bottom:12px">Yayınevinin karar için '+e((veri&&veri.inceleme_saat)||72)+' saati var. Kitabın aynı anda en çok 3 yayınevinde incelenebilir; biri yayımlarsa diğer dosyalar kendiliğinden geri çekilir.</p>'+
  '<button class="btn" id="ktDosyaGonder">Gönder</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 var b=m.querySelector("#ktDosyaGonder");
 b.onclick=async function(){
  if(b.disabled)return;b.disabled=true;
  var ok=await dosyaIslem("kopya_gonder",k.id,{yayinevi:id(m.querySelector("#ktDosyaYv").value)},"Kitabın yayınevine gönderildi. Aşamaları Dosyalarım'dan takip edebilirsin.");
  if(!ok&&document.body.contains(b))b.disabled=false;
 };
};
window.soDosyaGeriCek=async function(kid){
 var k=tumBul(kid);if(!k)return;
 var ok=typeof onayla!=="function"||await onayla("Dosyayı geri çek","«"+e(k.baslik)+"» "+e(k.yayinevi_ad||"")+" yayınevinden geri çekilecek. Kitabın sende kalır; istediğin zaman başka bir yayınevine gönderebilirsin.","Geri çek",true);
 if(ok)return dosyaIslem("geri_cek",kid,{},"Dosya geri çekildi.");
};
})();
