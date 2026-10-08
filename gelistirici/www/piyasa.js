/* Ortak piyasa ve Kazı Kazan ekranları. Ödül/fiyat/ödeme yalnızca Supabase RPC'de belirlenir. */
async function kazikazanEkrani(){
  yukleniyor("Kazı Kazan");
  try{kazikazanCiz(await API.rpc("kazikazan_durum"));}
  catch(err){iskelet("Kazı Kazan",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function kazikazanCiz(d,son){
  var html='<div class="kart" style="border:2px solid var(--gold)"><h2>🎰 Kazı Kazan · 100 ₺</h2>';
  if(son){html+='<div style="background:var(--panel2);text-align:center;padding:22px 12px;border-radius:16px;margin:12px 0"><p class="kucuk">KARTININ ÖDÜLÜ</p><div class="para '+(son.odul>100?'iyi':son.odul===0?'kotu':'')+'" style="font-size:40px">'+tlYaz(son.odul)+'</div><b>'+(son.odul===0?'Bu kart boş çıktı.':son.odul===100?'Bilet paranı geri aldın.':'Ödül cüzdanına yatırıldı!')+'</b></div>';}
  html+='<div class="kv"><span>Cüzdanım</span><b>'+tlYaz(son?son.cuzdan:d.cuzdan)+'</b></div>';
  html+='<button class="btn altin" onclick="kazikazanOyna()">🎟️ 100 ₺’ye yeni kart aç</button><p class="kucuk">Sanal oyun parası. Kartın sonucu sunucuda belirlenir, kazanma garantisi yoktur.</p></div>';
  html+='<div class="kart"><h2>Olasılık ve ödüller</h2>';
  [[0,"72%"],[100,"18%"],[200,"7%"],[1000,"2,5%"],[5000,"0,45%"],[10000,"0,05%"]].forEach(function(x){html+='<div class="kv"><span>'+tlYaz(x[0])+'</span><b>'+x[1]+'</b></div>';});
  html+='<p class="kucuk">Ortalama beklenen ödül 84,50 ₺/kart; uzun vadede devletin beklenen net payı 15,50 ₺/kart. Tek bir oyun sonucu değişebilir.</p></div>';
  html+='<div class="kart"><h2>Geçmiş kartlarım</h2><p class="alt">'+fmt(d.toplam_bilet)+' kart · Kazanılan '+tlYaz(d.toplam_odul)+'</p>';
  (d.son||[]).forEach(function(x){html+='<div class="kv"><span>#'+Number(x.id)+' · '+tarihSaat(x.zaman)+'</span><b class="'+(x.odul>100?'iyi':x.odul===0?'kotu':'')+'">'+tlYaz(x.odul)+'</b></div>';});
  html+='</div>';iskelet("Kazı Kazan",html,{geri:true});
}
async function kazikazanOyna(){
  if(!await onayla("Kazı Kazan","100 ₺ tutarında sanal kart açılacak. Boş çıkabilir. Onaylıyor musun?","Kartı aç"))return;
  try{var sonuc=await API.rpc("kazikazan_oyna");kazikazanCiz(await API.rpc("kazikazan_durum"),sonuc);}
  catch(err){bildir(hataCevir(err.message),true);}
}
function piyasaMiniGrafik(arr){
  if(!Array.isArray(arr)||arr.length<2)return '<p class="kucuk">Grafik için fiyat geçmişi oluşuyor.</p>';
  var v=arr.map(Number),min=Math.min.apply(null,v),max=Math.max.apply(null,v),f=Math.max(max-min,0.000001);
  var pts=v.map(function(p,i){return (i*300/(v.length-1)).toFixed(1)+','+(47-(p-min)*42/f).toFixed(1);}).join(' ');
  return '<svg role="img" aria-label="Son 24 saatin fiyat grafiği" viewBox="0 0 300 52" width="100%" height="52" preserveAspectRatio="none"><polyline points="'+pts+'" fill="none" stroke="'+(v[v.length-1]>=v[0]?'var(--good)':'var(--acc)')+'" stroke-width="2.4" stroke-linecap="round"/></svg>';
}
async function piyasaEkrani(){
  yukleniyor("Yatırım Borsası");
  try{piyasaCiz(await API.rpc("piyasa_durum"));}
  catch(err){iskelet("Yatırım Borsası",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function piyasaCiz(d){
  D._piyasa=d;
  var liste=d.varliklar||[],makro=d.makro||{},portfoy=liste.reduce(function(s,x){return s+Number(x.deger||0);},0);
  var html='<div class="kart" style="border:2px solid var(--gold)"><h2>📊 Tüm oyuncular için ortak piyasa</h2>';
  html+='<div class="kv"><span>Cüzdan</span><b>'+tlYaz(d.cuzdan)+'</b></div><div class="kv"><span>Portföy değeri</span><b>'+tlYaz(portfoy)+'</b></div>';
  html+='<p class="kucuk">Fiyat saati: '+tarihSaat(d.saat)+' · Her saat tek sunucu fiyatı. Herkes aynı fiyatı görür. Fiyatlar yükselebilir veya düşebilir. Bu fiyatlar gerçek borsa verileri değil, oyun ekonomisinin simülasyonudur.</p>';
  html+='<button class="btn ikinci" onclick="piyasaEkrani()">↻ Fiyatları yenile</button></div>';
  html+='<div class="kart"><h2>İktidarın ekonomi karnesi · Piyasa etkisi</h2>';
  [["Enflasyon","enflasyon"],["Büyüme","buyume"],["İşsizlik","issizlik"]].forEach(function(x){html+='<div class="kv"><span>'+x[0]+'</span><b>%'+fmt(makro[x[1]],1)+'</b></div>';});
  html+='<div class="kv"><span>Devlet hazinesi (oyun birimi)</span><b>'+fmt(makro.hazine,2)+'</b></div><div class="kv"><span>Devlet borcu (oyun birimi)</span><b>'+fmt(makro.borc,2)+'</b></div>';
  html+='<p class="kucuk">Enflasyon, borç, hazinenin durumu, büyüme ve işsizlik ortak kurları etkiler. Rastlantısal piyasa dalgalanmaları nedeniyle kazanç garanti değildir.</p></div>';
  liste.forEach(function(x){
    var deg=Number(x.degisim||0),deger=Number(x.deger||0),maliyet=Number(x.maliyet||0),kar=deger-maliyet;
    html+='<div class="kart"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><div><b>'+e(x.ad)+'</b><div class="kucuk">'+e(x.kod)+' · '+(x.sinif==='doviz'?'Döviz':x.sinif==='altin'?'Altın':'Sanal hisse grubu')+'</div></div>';
    html+='<div style="text-align:right"><b style="font-size:19px">'+tlYaz(x.fiyat)+'</b><div class="'+(deg>=0?'iyi':'kotu')+'">'+(deg>=0?'+':'')+'%'+fmt(deg,2)+' / saat</div></div></div>';
    html+='<div style="margin-top:8px">'+piyasaMiniGrafik(x.gecmis)+'</div>';
    html+='<div class="kv"><span>Miktarım</span><b>'+fmt(x.miktar,6)+'</b></div><div class="kv"><span>Portföy değeri</span><b>'+tlYaz(deger)+'</b></div>';
    html+='<div class="kv"><span>Kâr / zarar (gerçekleşmemiş)</span><b class="'+(kar>=0?'iyi':'kotu')+'">'+(kar>=0?'+':'')+tlYaz(kar)+'</b></div>';
    html+='<div class="satir"><button class="btn yarim altin" data-piyasa-kod="'+e(x.kod)+'" data-piyasa-yon="al">Al</button><button class="btn yarim ikinci" data-piyasa-kod="'+e(x.kod)+'" data-piyasa-yon="sat" '+(Number(x.miktar)<=0?'disabled':'')+'>Sat</button></div></div>';
  });
  html+='<div class="kart"><h2>Son işlemlerim</h2>';
  (d.islemler||[]).forEach(function(x){html+='<div class="kv"><span>'+ (x.yon==='al'?'🟢 Alış':'🔴 Satış')+' · '+e(x.kod)+'<div class="kucuk">'+tarihSaat(x.zaman)+' · '+fmt(x.miktar,6)+' adet · komisyon '+tlYaz(x.komisyon)+'</div></span><b>'+tlYaz(x.brut)+'</b></div>';});
  html+='<p class="kucuk">Alış ve satışta %0,3 komisyon (en az 1 ₺) hazineye gider. Açığa satış ve kaldıraç yoktur.</p></div>';
  iskelet("Yatırım Borsası",html,{geri:true});
  document.querySelectorAll('[data-piyasa-kod]').forEach(function(b){b.onclick=function(){piyasaEmir(b.dataset.piyasaKod,b.dataset.piyasaYon);};});
}
function piyasaEmir(kod,yon){
  var d=D._piyasa,v=(d.varliklar||[]).find(function(x){return x.kod===kod;});if(!v)return;
  var max=yon==='al'?Math.max(0,Math.floor(Number(d.cuzdan)/1.003)):Math.floor(Number(v.deger));
  var m=modal('<h3 style="font-size:19px;font-weight:800">'+e(v.ad)+' · '+(yon==='al'?'Alış':'Satış')+'</h3>'+
     '<p class="alt">Görünen fiyat: '+tlYaz(v.fiyat)+' · %0,3 komisyon, en az 1 ₺. Emir güncel sunucu fiyatından işlenir.</p>'+
     '<div class="alan"><label>Tutar (₺, en az 100)</label><input type="number" id="pTutar" min="100" step="100" value="'+Math.min(max,1000)+'" inputmode="numeric"></div>'+
     '<p class="kucuk">Yaklaşık azami işlem: '+tlYaz(max)+'</p><button class="btn altin" id="pOk">İşlemi onayla</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  $("#pOk",m).onclick=async function(){
    var tutar=Math.round(Number($("#pTutar",m).value)),b=$("#pOk",m);
    if(!Number.isFinite(tutar)||tutar<100||tutar>max){bildir("Tutar 100 ₺ ile kullanılabilir bakiye arasında olmalı.",true);return;}
    b.disabled=true;
    try{var r=await API.rpc("piyasa_emir",{p_kod:kod,p_yon:yon,p_tutar:tutar});modalKapat();bildir((yon==='al'?'Alış':'Satış')+' gerçekleşti. Komisyon: '+tlYaz(r.komisyon));piyasaEkrani();}
    catch(err){b.disabled=false;bildir(hataCevir(err.message),true);}
  };
}
