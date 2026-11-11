/* 11.11.2026 — Karikatür dergileri: ayrı raf, beş şablon, sayı başına satın alma.
 * Satın alınmamış sayıların içeriği istemciye gönderilmez (dergi_sayi_detay RPC).
 */
(function(){
'use strict';
if(window.SO_KARIKATUR_DERGI_V1)return;
window.SO_KARIKATUR_DERGI_V1=true;
var DR_SABLON={
 meclis:{ad:'Meclis Atışması',sahne:'🏛️ TBMM',zemin:'meclis',karakter1:'Milletvekili',karakter2:'Bakan',sol:'Bütçe nerede?',sag:'Ben de onu arıyorum!'},
 tv:{ad:'Canlı TV Düellosu',sahne:'📺 CANLI YAYIN',zemin:'tv',karakter1:'Muhalefet',karakter2:'İktidar',karakter3:'Moderatör',sol:'Halk bunu unutmaz!',sag:'Ankette öndeyiz!',orta:'Süreniz doldu!'},
 eylem:{ad:'Sokak Eylemi',sahne:'📢 MEYDAN',zemin:'eylem',karakter1:'Eylemci',karakter2:'Yetkili',sol:'Geçim yoksa huzur da yok!',sag:'Masa kuralım, konuşalım!'},
 adliye:{ad:'Adliye Sahnesi',sahne:'⚖️ MAHKEME',zemin:'adliye',karakter1:'Avukat',karakter2:'Sanık',karakter3:'Hâkim',sol:'Delil burada sayın hâkim!',sag:'Bu tamamen siyasi!',orta:'Sırayla konuşun!'},
 kapak:{ad:'Mizah Dergisi Kapağı',sahne:'🪑 KOLTUK',zemin:'kapak',karakter1:'Siyasetçi',sol:'Bu koltuk sallanıyor!',sag:'',orta:''}
};
var DR_SABLONLAR=Object.keys(DR_SABLON);
var DR_SAYFALAR=[], DR_AKTIF=0, DR_DERGI=0, DR_KAYDEDILIYOR=false;
function drEsc(x){return typeof e==='function'?e(String(x==null?'':x)):String(x==null?'':x).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
function drTL(n){return typeof tlYaz==='function'?tlYaz(n):Number(n||0).toLocaleString('tr-TR')+' ₺';}
function drStil(){
 if(document.getElementById('drStil'))return;
 var css=[
 '.dr-hero{padding:17px;border-radius:20px;background:linear-gradient(140deg,#242b5c,#3c2558);margin:0 0 14px;color:#f7f6ff}',
 '.dr-hero h2{font-size:23px;margin:0 0 6px;color:white}.dr-hero p{color:#cbd3f2;font-size:14px;margin:0}',
 '.dr-raflar{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:12px 0 16px}',
 '.dr-raf{appearance:none;width:100%;min-width:0;display:flex;flex-direction:column;gap:9px;text-align:left;border:1px solid #45517c;border-radius:19px;padding:16px 13px;background:linear-gradient(140deg,#2b355f,#151d3c);color:white;cursor:pointer;min-height:166px}',
 '.dr-raf strong{font-size:18px;line-height:1.3}.dr-raf small{font-size:13px;color:#c6d0eb;line-height:1.45}.dr-raf .dr-ikon{font-size:35px}',
 '.dr-sekme{display:flex;gap:9px;margin:12px 0 16px}.dr-sekme button{flex:1;min-width:0;min-height:48px;font-size:14px}',
 '.dr-kart{background:linear-gradient(155deg,#202b54,#141b39);border:1px solid #43517c;border-radius:18px;padding:15px;margin:0 0 12px;overflow-wrap:anywhere}',
 '.dr-kart h3{font-size:19px;margin:0 0 8px;color:#fff}.dr-kart p{font-size:14px;color:#bac5e0;margin:5px 0 11px}',
 '.dr-sayilar{display:flex;gap:8px;overflow-x:auto;padding:5px 0 11px}',
 '.dr-sayi{min-width:155px;max-width:190px;flex:0 0 155px;text-align:left;background:#1a2348;border:1px solid #4e5c87;border-radius:15px;padding:11px;color:#fff;cursor:pointer}',
 '.dr-sayi b,.dr-sayi small,.dr-sayi span{display:block;overflow-wrap:anywhere}.dr-sayi b{font-size:14px}.dr-sayi small{font-size:12px;color:#b9c5e5;margin-top:4px}.dr-sayi .dr-kapak-min{margin:0 0 8px;height:85px;display:grid;place-items:center;background:linear-gradient(135deg,#a0223e,#dd4436 55%,#f8c44b);border-radius:9px;font-size:40px;border:3px solid #e9d6a9}',
 '.dr-kilit{background:rgba(255,255,255,.08);border-radius:12px;padding:13px;text-align:center;color:#eee;font-weight:700;font-size:14px}',
 '.dr-editor{display:grid;gap:10px}.dr-editor label{display:block;font-size:15px;line-height:1.4;color:#e6edff;font-weight:700;margin:4px 0 5px}',
 '.dr-editor input,.dr-editor textarea,.dr-editor select{display:block;width:100%!important;min-width:0;box-sizing:border-box;padding:11px 12px;border:1px solid #6674a1;background:#141b37;color:#fff;border-radius:12px;font-size:16px;line-height:1.5;min-height:48px;color-scheme:dark}',
 '.dr-editor textarea{min-height:80px;resize:vertical}.dr-editor button{min-height:46px}',
 '.dr-sablonlar{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}',
 '.dr-sablon{font-size:13px;text-align:left;border-radius:13px;border:1px solid #647199;background:#1a2448;color:#e6eafa;padding:10px;min-height:56px;cursor:pointer}',
 '.dr-sablon.secili{border:2px solid #f4cf64;background:#303861;color:white}',
 '.dr-balon{position:relative;display:block;background:#fff;color:#1b1c2d;padding:12px 10px;border:3px solid #1a1b2b;border-radius:24px;line-height:1.25;font-weight:800;font-size:clamp(14px,4vw,20px);text-align:center;overflow-wrap:anywhere;min-height:32px}',
 '.dr-balon:after{content:"";position:absolute;bottom:-11px;left:38%;width:15px;height:15px;background:white;border-bottom:3px solid #1a1b2b;border-right:3px solid #1a1b2b;transform:rotate(45deg)}',
 '.dr-cizim{position:relative;isolation:isolate;overflow:hidden;border:5px solid #201c2b;border-radius:16px;padding:13px 10px 17px;box-shadow:0 9px 20px #0004;min-height:290px;color:#141b2f;background:#f9dfb0}',
 '.dr-cizim:before{content:"";position:absolute;inset:0;z-index:-1;opacity:.8;background:repeating-linear-gradient(115deg,transparent 0 21px,#ffffff1b 23px 26px)}',
 '.dr-cizim.meclis{background:linear-gradient(#dcc5a4 0 42%,#b56042 42%,#5a2f37 100%)}',
 '.dr-cizim.tv{background:linear-gradient(150deg,#0d295e,#384bd8 55%,#e74b91)}',
 '.dr-cizim.eylem{background:linear-gradient(#74b7e4 0 39%,#c8bbad 39% 70%,#496c6f 70%)}',
 '.dr-cizim.adliye{background:linear-gradient(#b59b75 0 25%,#6d412c 25% 100%)}',
 '.dr-cizim.kapak{background:linear-gradient(140deg,#d22e42,#f8cb54 60%,#ee6f38)}',
 '.dr-baslik{font:900 clamp(17px,5vw,26px)/1.15 system-ui,sans-serif;text-align:center;text-transform:uppercase;color:#fff;background:#aa202b;border:3px solid #231525;transform:rotate(-1deg);padding:8px 5px;box-shadow:4px 4px 0 #202028;margin-bottom:14px;overflow-wrap:anywhere}',
 '.dr-sahne-ad{font-size:12px;letter-spacing:1px;text-align:center;font-weight:900;color:#fff;background:#131b43bf;padding:5px;border-radius:8px;margin-bottom:10px}',
 '.dr-figurlar{display:flex;align-items:flex-end;justify-content:space-evenly;gap:8px;margin:4px 0 0}',
 '.dr-figur{flex:1;min-width:0;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:10px}',
 '.dr-figur .dr-yuz{width:100%;display:flex;justify-content:center;filter:drop-shadow(2px 4px 0 #0005)}.dr-figur .dr-vektor{width:min(100%,126px);height:auto;display:block}',
 '.dr-figur b{display:block;color:#fff;background:#18234fdb;border:1px solid #fff6;border-radius:9px;padding:4px 6px;text-align:center;font-size:12px;min-height:21px;overflow-wrap:anywhere}',
 '.dr-figur .dr-balon{width:100%;box-sizing:border-box}.dr-figur .dr-balon:empty{display:none}',
 '.dr-ortab{margin:0 auto 10px;max-width:75%}.dr-sahne-alt{margin-top:10px;text-align:center;color:#fff;font-weight:900;font-size:12px;letter-spacing:1px}',
 '.dr-sayfagecis{display:flex;flex-wrap:wrap;gap:6px;margin:9px 0}.dr-sayfagecis button{min-height:43px;padding:9px 12px}',
 '@media(max-width:380px){.dr-raflar{grid-template-columns:1fr}.dr-sablonlar{grid-template-columns:1fr 1fr}.dr-figur .dr-vektor{width:min(100%,98px)}.dr-balon{font-size:14px}}'
 ];
 var el=document.createElement('style');el.id='drStil';el.textContent=css.join('');document.head.appendChild(el);
}
function drKisayol(){
 return '<div class="dr-sekme"><button class="btn ikinci" onclick="ekranAc(basinYayinRafEkrani)">‹ Tüm raflar</button>'+
 '<button class="btn ikinci" onclick="ekranAc(basinEkrani)">Gazeteler</button>'+
 '<button class="btn altin" onclick="ekranAc(dergiRafEkrani)">Dergiler</button></div>';
}
window.basinYayinRafEkrani=function(){
 drStil();iskelet('Gazeteler ve Dergiler','<div class="dr-hero"><h2>🗞️ Gazeteler ve Dergiler</h2><p>İstediğin rafı seç. Gazeteler abonelikle, karikatür dergileri ise tek tek sayı satın alınarak okunur.</p></div>'+
 '<div class="dr-raflar"><button class="dr-raf" onclick="ekranAc(basinEkrani)"><span class="dr-ikon">📰</span><strong>Gazeteler rafı</strong><small>Gazeteler, haberler, köşe yazarları ve abonelikler</small></button>'+
 '<button class="dr-raf" onclick="ekranAc(dergiRafEkrani)"><span class="dr-ikon">📚</span><strong>Karikatür dergileri rafı</strong><small>Beş çizgi roman şablonu, yeni sayılar ve satın aldıkların</small></button></div>'+
 '<div class="dr-kart"><h3>🗞️ Türkiye Gündem</h3><p>Oyunun ücretsiz otomatik haberlerini oku.</p><button class="btn ikinci" onclick="otomatikGazeteEkrani()">Türkiye Gündem aç</button></div>',{geri:true});
};
function drTemaIco(t){return {meclis:'🏛️',tv:'📺',eylem:'📢',adliye:'⚖️',kapak:'🪑'}[t]||'🖍️';}
function drVektorKarakter(tur,no){
 var ceket=['#1b326c','#53295c','#283e53'][no%3],sac=['#29232d','#59545e','#51372f'][no%3];
 var ten=['#ffd3a0','#ffbd86','#efb983'][no%3],kizgin=no===0,hakim=tur==='adliye'&&no===2;
 var mimik=kizgin?'<path d="M42 66l22 -10M82 56l24 10" stroke="#332331" stroke-width="6" stroke-linecap="round"/>':'<path d="M42 58l23 3M84 62l23 -4" stroke="#332331" stroke-width="5" stroke-linecap="round"/>';
 var agiz=kizgin?'<path d="M60 111q20 -12 39 1q-12 22 -30 15z" fill="#692536" stroke="#37222d" stroke-width="3"/>':'<path d="M61 113Q81 126 101 109" fill="none" stroke="#6b3736" stroke-width="5" stroke-linecap="round"/>';
 var aksesuar=tur==='eylem'&&no===0?'<path d="M15 119l34 -21v30l-34 13z" fill="#ed3845" stroke="#29202b" stroke-width="5"/>':tur==='tv'?'<path d="M124 167V127" stroke="#2c2736" stroke-width="5"/><circle cx="124" cy="125" r="8" fill="#c7d6ec" stroke="#292333" stroke-width="3"/>':hakim?'<path d="M108 146l24 -27" stroke="#532b21" stroke-width="8" stroke-linecap="round"/>':'';
 return '<svg class="dr-vektor" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 155 175" role="img" aria-label="Çizgi karakter">'+
 '<ellipse cx="79" cy="165" rx="68" ry="10" fill="#110d22" opacity=".25"/>'+
 '<path d="M7 173Q8 138 44 125l27 12 26 -12q42 0 52 48z" fill="'+(hakim?'#202330':ceket)+'" stroke="#2d2232" stroke-width="6"/>'+
 '<path d="M58 126l19 22 20 -22 12 47H47z" fill="'+(hakim?'#30333c':'#f7e7d8')+'" stroke="#30222f" stroke-width="3"/>'+
 '<path d="M74 139l10 -1 7 26 -10 9 -10 -10z" fill="#d43249" stroke="#352432" stroke-width="2"/>'+
 '<path d="M39 56q-8 24 0 46q10 26 42 28q34 0 44 -32q10 -25 -4 -48q-22 -31 -45 -28q-28 1 -37 34z" fill="'+ten+'" stroke="#342632" stroke-width="5"/>'+
 '<path d="M37 64Q19 36 41 23q13 -16 34 -9q19 -10 38 4q24 12 10 46q-12 -16 -22 -28Q80 50 61 36Q46 51 37 64Z" fill="'+sac+'" stroke="#2f2632" stroke-width="5"/>'+
 '<ellipse cx="58" cy="79" rx="16" ry="14" fill="#fff" stroke="#332432" stroke-width="3"/><ellipse cx="97" cy="79" rx="16" ry="14" fill="#fff" stroke="#332432" stroke-width="3"/>'+
 '<circle cx="'+(kizgin?'65':'58')+'" cy="78" r="5" fill="#292330"/><circle cx="'+(kizgin?'104':'96')+'" cy="78" r="5" fill="#292330"/>'+
 mimik+'<ellipse cx="79" cy="101" rx="17" ry="13" fill="#eaa071" stroke="#4d2c36" stroke-width="3"/>'+agiz+
 (no===1?'<path d="M120 105q12 12 -2 20q-12 -8 2 -20z" fill="#80d6f6" stroke="#276d87" stroke-width="2"/>':'')+
 aksesuar+'</svg>';
}
function drPanelHTML(p){
 p=p||{};var t=DR_SABLON[p.sablon]||DR_SABLON.meclis;
 var k1=drEsc(p.karakter1||t.karakter1||'Kişi 1'),k2=drEsc(p.karakter2||t.karakter2||'Kişi 2'),k3=drEsc(p.karakter3||t.karakter3||'Moderatör');
 var f1='<div class="dr-figur"><div class="dr-balon">'+drEsc(p.sol||'')+'</div><div class="dr-yuz">'+drVektorKarakter(p.sablon,0)+'</div><b>'+k1+'</b></div>';
 var f2='<div class="dr-figur"><div class="dr-balon">'+drEsc(p.sag||'')+'</div><div class="dr-yuz">'+drVektorKarakter(p.sablon,1)+'</div><b>'+k2+'</b></div>';
 var mid=(p.sablon==='tv'||p.sablon==='adliye')?'<div class="dr-figur"><div class="dr-balon">'+drEsc(p.orta||'')+'</div><div class="dr-yuz">'+drVektorKarakter(p.sablon,2)+'</div><b>'+k3+'</b></div>':'';
 return '<article class="dr-cizim '+drEsc(t.zemin)+'"><div class="dr-baslik">'+drEsc(p.baslik||t.ad)+'</div><div class="dr-sahne-ad">'+drEsc(t.sahne)+'</div>'+
 '<div class="dr-figurlar">'+f1+(p.sablon==='kapak'?'':mid+f2)+'</div><div class="dr-sahne-alt">SEÇİM ONLINE • SİYASİ MİZAH</div></article>';
}
window.dergiRafEkrani=async function(){
 drStil();yukleniyor('Karikatür Dergileri');
 var d;try{d=await API.rpc('dergi_raf');}catch(err){iskelet('Karikatür Dergileri','<div class="kart">'+drEsc(hataCevir(err.message))+'</div>',{geri:true});return;}
 var list=d.dergiler||[], sayilar=d.sayilar||[], benim=d.benim;
 var own=benim?'<div class="dr-kart"><h3>✒️ '+drEsc(benim.ad)+'</h3><p>Toplam dergi satışları: '+drEsc(drTL(benim.kasa))+' • Satılan sayı: '+Number(benim.toplam_satis||0)+'</p><p>🔒 Satış bedelleri dergi kayıtlarında tutulur; cüzdana çekilemez veya başka oyuncuya aktarılamaz.</p><button class="btn altin" onclick="dergiSayiEditor('+Number(benim.id)+')">Yeni sayı hazırla</button> <button class="btn ikinci" onclick="dergiKapat('+Number(benim.id)+')">Dergiyi kapat</button></div>'
 :'<div class="dr-kart"><h3>✒️ Kendi mizah dergini aç</h3><p>Kuruluş bedeli: '+drEsc(drTL(d.kurulus_ucreti))+'. Her sayıya 1-1.000 TL fiyat belirlersin. Sayıları yalnız satın alanlar okur.</p><button class="btn altin" onclick="dergiKurModal('+Number(d.kurulus_ucreti||0)+')">Karikatür dergisi kur</button></div>';
 var html='<div class="dr-hero"><h2>🎭 Karikatür Dergileri</h2><p>Çizim bilmeden hazır sahneler ve konuşma balonlarıyla siyasi mizah. En fazla 1.000 TL. Satın almadan sayfa içeriği görünmez.</p></div>'+drKisayol()+own;
 var alinmis=sayilar.filter(function(x){return x.satin_aldim;});
 if(alinmis.length) html+='<section class="dr-kart"><h3>📚 Satın aldığım sayılar</h3><p>Bir kez aldığın sayılar kitaplığında kalır; yeniden ödeme yapmadan açabilirsin.</p><div class="dr-sayilar">'+alinmis.map(function(x){return '<button class="dr-sayi" onclick="dergiSayiEkrani('+Number(x.id)+')"><span class="dr-kapak-min">'+drTemaIco(x.sablon)+'</span><b>'+drEsc(x.dergi)+'</b><small>'+Number(x.no)+'. sayı • '+drEsc(x.baslik)+'</small><small>✅ Okumaya hazır</small></button>';}).join('')+'</div></section>';
 var kapananSayilar=sayilar.filter(function(x){return x.sahibim&&!list.some(function(g){return Number(g.id)===Number(x.dergi_id);});});
 if(kapananSayilar.length) html+='<section class="dr-kart"><h3>📕 Kapattığım dergilerin arşivi</h3><p>Yeni satışa kapalıdır. Yayımladığın eski sayılarını inceleyebilirsin.</p><div class="dr-sayilar">'+kapananSayilar.map(function(x){return '<button class="dr-sayi" onclick="dergiSayiEkrani('+Number(x.id)+')"><span class="dr-kapak-min">'+drTemaIco(x.sablon)+'</span><b>'+drEsc(x.dergi)+'</b><small>'+Number(x.no)+'. sayı • '+drEsc(x.baslik)+'</small><small>🔒 Yayını durduruldu</small></button>';}).join('')+'</div></section>';
 if(!list.length) html+='<div class="dr-kart"><p>Henüz dergi yok. İlk dergiyi sen kurabilirsin.</p></div>';
 list.forEach(function(g){
   var ss=sayilar.filter(function(s){return Number(s.dergi_id)===Number(g.id);});
   html+='<section class="dr-kart"><h3>📕 '+drEsc(g.ad)+'</h3><p>'+drEsc(g.slogan||'Mizah dergisi')+' • Sahibi: '+drEsc(g.sahip)+' • '+ss.length+' sayı</p>';
   html+=ss.length?'<div class="dr-sayilar">'+ss.map(function(s){
    return '<button class="dr-sayi" onclick="dergiSayiEkrani('+Number(s.id)+')"><span class="dr-kapak-min">'+drTemaIco(s.sablon)+'</span><b>'+drEsc(s.baslik)+'</b><small>'+Number(s.no)+'. sayı • '+drEsc(drTL(s.fiyat))+'</small><small>'+(s.sahibim?'✒️ Yayıncısın':s.satin_aldim?'✅ Satın alındı':'🔒 Satın al ve oku')+'</small></button>';
   }).join('')+'</div>':'<p>Henüz yayımlanmış sayı yok.</p>';
   html+='</section>';
 });
 iskelet('Gazeteler ve Dergiler / Dergiler',html,{geri:true});
};
window.dergiKurModal=function(ucret){
 basinForm('Karikatür dergisi kur','<p class="alt">Dergi için cüzdanından '+drEsc(drTL(ucret))+' alınır. Gazete sahibi olman dergi kurmana engel değildir.</p>'+
  basinAlan('drAd','Dergi adı','required minlength="4" maxlength="40"')+
  basinAlan('drSlogan','Dergi sloganı','maxlength="100"'),
 'Dergiyi kur','dergi_kur',function(m){return {p_ad:$('#drAd',m).value.trim(),p_slogan:$('#drSlogan',m).value.trim()};},function(){ekranAc(dergiRafEkrani);});
};
window.dergiKapat=async function(id){
 if(!await onayla('Dergiyi kapat','Yeni sayi ve satis durur. Daha once satin alinan sayilar oyuncunun kitapliginda kalir. Kalan satis geliri cekilemez.','Dergiyi kapat'))return;
 try{
  await API.rpc('dergi_kapat',{p_dergi:id});
  toast('Dergin kapatildi; satin alinan sayilar okunmaya devam edecek.');
  ekranAc(dergiRafEkrani);
 }catch(err){toast(hataCevir(err.message),true);}
};
window.dergiSayiEkrani=async function(id,d0){
 drStil();yukleniyor('Karikatür dergisi');
 var d=d0;try{if(!d)d=await API.rpc('dergi_sayi_detay',{p_sayi:id});}
 catch(err){iskelet('Karikatür dergisi','<div class="kart">'+drEsc(hataCevir(err.message))+'</div>',{geri:true});return;}
 var html=drKisayol()+'<div class="dr-hero"><h2>'+drEsc(d.dergi)+' • '+Number(d.no)+'. sayı</h2><p>'+drEsc(d.baslik)+' • '+drEsc(drTL(d.fiyat))+'</p></div>';
 if(!d.erisim){
  html+='<div class="dr-kart"><div class="dr-kilit">🔒 Bu sayı kilitli<br>Konuşmalar ve karikatür sayfaları yalnız satın alanlara açılır.</div><p>'+Number(d.sayfa_sayisi)+' karikatür içeriyor. '+drEsc(drTL(d.fiyat))+' ödeyerek bu sayıya kalıcı erişim kazanabilirsin.</p>'+
   '<button id="drSatin" class="btn altin" style="width:100%;min-height:50px" onclick="dergiSayiSatinAl('+Number(d.id)+')">Bu sayıyı satın al • '+drEsc(drTL(d.fiyat))+'</button></div>';
 }else{
  html+='<div class="dr-kart"><p>✅ '+(d.sahibim?'Bu sayının yayıncısısın.':'Bu sayıyı satın aldın. İstediğin zaman tekrar okuyabilirsin.')+'</p></div>';
  (d.sayfalar||[]).forEach(function(p,i){html+='<section class="dr-kart"><p>Karikatür '+(i+1)+' / '+d.sayfalar.length+'</p>'+drPanelHTML(p)+'</section>';});
 }
 iskelet('Karikatür Dergisi • '+Number(d.no)+'. sayı',html,{geri:true});
};
window.dergiSayiSatinAl=async function(id){
 var b=document.getElementById('drSatin');if(!b||b.disabled)return;b.disabled=true;b.textContent='Satın alınıyor…';
 try{var d=await API.rpc('dergi_sayi_satinal',{p_sayi:id});toast('Sayı kitaplığına eklendi.');dergiSayiEkrani(id,d);}
 catch(err){toast(hataCevir(err.message),true);b.disabled=false;b.textContent='Tekrar dene';}
};
function drBos(t){
 var s=DR_SABLON[t]||DR_SABLON.meclis;
 return {sablon:t,baslik:s.ad,karakter1:s.karakter1||'',karakter2:s.karakter2||'',karakter3:s.karakter3||'',sol:s.sol||'',sag:s.sag||'',orta:s.orta||''};
}
function drField(id,title,val,max,ta){
 return '<div><label for="'+id+'">'+drEsc(title)+'</label>'+(ta?'<textarea id="'+id+'" maxlength="'+max+'" oninput="drOku()">'+drEsc(val)+'</textarea>':
 '<input id="'+id+'" type="text" maxlength="'+max+'" value="'+drEsc(val)+'" oninput="drOku()"/>')+'</div>';
}
window.dergiSayiEditor=function(id){
 drStil();DR_DERGI=id;DR_SAYFALAR=[drBos('meclis')];DR_AKTIF=0;DR_KAYDEDILIYOR=false;drEditorCiz();
};
function drEditorCiz(){
 var p=DR_SAYFALAR[DR_AKTIF],t=DR_SABLON[p.sablon];
 var tabs=DR_SAYFALAR.map(function(z,i){return '<button type="button" class="btn '+(i===DR_AKTIF?'altin':'ikinci')+'" onclick="drSayfaSec('+i+')">'+(i+1)+'. sayfa</button>';}).join('');
 var cards=DR_SABLONLAR.map(function(k){return '<button type="button" class="dr-sablon '+(k===p.sablon?'secili':'')+'" onclick="drSablonSec(\''+k+'\')">'+drTemaIco(k)+' '+drEsc(DR_SABLON[k].ad)+'</button>';}).join('');
 var html=drKisayol()+'<div class="dr-hero"><h2>✒️ Yeni dergi sayısı</h2><p>Hazır şablonları düzenle. Bir sayıda 1-4 karikatür olabilir. Yayımlandıktan sonra içeriği değiştirilmez.</p></div>'+
 '<div class="dr-kart dr-editor">'+drField('drSayiBas','Sayı başlığı',window.__drBaslik||'Haftanın Siyasi Mizahı',90,false)+
 '<div><label for="drSayiFiyat">Tek sayı fiyatı (₺)</label><input id="drSayiFiyat" type="number" min="1" max="1000" step="1" value="'+Number(window.__drFiyat||500)+'" oninput="drOku()"/></div>'+
 '<h3>Karikatür '+(DR_AKTIF+1)+' / '+DR_SAYFALAR.length+'</h3><div class="dr-sayfagecis">'+tabs+'</div>'+
 '<div class="dr-sablonlar">'+cards+'</div>'+
 drField('drKarBas','Karikatür başlığı',p.baslik,90,false)+
 drField('drK1','1. karakter adı',p.karakter1,45,false)+
 (p.sablon==='kapak'?'':drField('drK2','2. karakter adı',p.karakter2,45,false))+
 ((p.sablon==='tv'||p.sablon==='adliye')?drField('drK3','3. karakter adı',p.karakter3,45,false):'')+
 drField('drSol','1. konuşma balonu',p.sol,200,true)+
 (p.sablon==='kapak'?'':drField('drSag','2. konuşma balonu',p.sag,200,true))+
 ((p.sablon==='tv'||p.sablon==='adliye')?drField('drOrta','3. konuşma balonu',p.orta,200,true):'')+
 '<h3>Canlı önizleme</h3><div id="drOnizleme">'+drPanelHTML(p)+'</div>'+
 '<button class="btn ikinci" onclick="drSayfaEkle()" '+(DR_SAYFALAR.length>=4?'disabled':'')+'>+ Karikatür sayfası ekle</button>'+
 (DR_SAYFALAR.length>1?'<button class="btn ikinci" onclick="drSayfaSil()">Bu sayfayı sil</button>':'')+
 '<button id="drYayinBtn" class="btn altin" style="width:100%;min-height:52px" onclick="drSayiYayinla()">Sayıyı yayımla</button></div>';
 iskelet('Yeni Dergi Sayısı',html,{geri:true});
}
window.drOku=function(){
 var g=function(k){var x=document.getElementById(k);return x?x.value:null;};
 var p=DR_SAYFALAR[DR_AKTIF];if(!p)return;
 var mapping={baslik:'drKarBas',karakter1:'drK1',karakter2:'drK2',karakter3:'drK3',sol:'drSol',sag:'drSag',orta:'drOrta'};
 Object.keys(mapping).forEach(function(k){var v=g(mapping[k]);if(v!==null)p[k]=v;});
 var bas=g('drSayiBas');if(bas!==null)window.__drBaslik=bas;
 var fiyat=g('drSayiFiyat');if(fiyat!==null)window.__drFiyat=fiyat;
 var v=document.getElementById('drOnizleme');if(v)v.innerHTML=drPanelHTML(p);
};
window.drSayfaSec=function(i){drOku();DR_AKTIF=i;drEditorCiz();};
window.drSablonSec=function(k){drOku();var old=DR_SAYFALAR[DR_AKTIF];DR_SAYFALAR[DR_AKTIF]=Object.assign(drBos(k),{baslik:old.baslik||DR_SABLON[k].ad,sol:old.sol||DR_SABLON[k].sol,sag:old.sag||DR_SABLON[k].sag});drEditorCiz();};
window.drSayfaEkle=function(){drOku();if(DR_SAYFALAR.length>=4)return;DR_SAYFALAR.push(drBos('meclis'));DR_AKTIF=DR_SAYFALAR.length-1;drEditorCiz();};
window.drSayfaSil=function(){drOku();if(DR_SAYFALAR.length<=1)return;DR_SAYFALAR.splice(DR_AKTIF,1);DR_AKTIF=Math.max(0,DR_AKTIF-1);drEditorCiz();};
window.drSayiYayinla=async function(){
 drOku();if(DR_KAYDEDILIYOR)return;
 var bas=String(window.__drBaslik||'').trim(),fiyat=Number(window.__drFiyat);
 if(bas.length<4||bas.length>90){toast('Sayı başlığı 4-90 karakter olmalı.',true);return;}
 if(!Number.isInteger(fiyat)||fiyat<1||fiyat>1000){toast('Sayı fiyatı 1-1000 TL arasında olmalı.',true);return;}
 DR_KAYDEDILIYOR=true;var b=document.getElementById('drYayinBtn');if(b){b.disabled=true;b.textContent='Yayımlanıyor…';}
 try{
  var r=await API.rpc('dergi_sayi_yayinla',{p_dergi:DR_DERGI,p_baslik:bas,p_fiyat:fiyat,p_sayfalar:DR_SAYFALAR});
  toast(r.no+'. sayı yayımlandı.');window.__drBaslik='';window.__drFiyat=500;
  dergiSayiEkrani(r.id);
 }catch(err){toast(hataCevir(err.message),true);DR_KAYDEDILIYOR=false;if(b){b.disabled=false;b.textContent='Sayıyı yayımla';}}
};
})();