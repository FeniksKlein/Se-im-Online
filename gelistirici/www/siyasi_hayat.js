/* Seçim Simülasyonu Online — emlak, parlamento ve parti hayatı.
   Sunucu işlemleri RPC ile, oyuncu arayüzü sadece görünüm ile ilgilenir. */
async function emlakPazarEkrani(){
  yukleniyor("Gayrimenkul Pazarı");
  try{emlakPazarCiz(await API.rpc("mulk_pazar"));}
  catch(err){iskelet("Gayrimenkul Pazarı",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function emlakPazarCiz(d){
  const ilanlar=d.ilanlar||[];
  let h='<div class="kart"><h2>🏠 Oyuncular arası gayrimenkul pazarı</h2><p class="alt">Daire, dükkân ve villalarını istediğin fiyatla satışa çıkarabilir veya başka bir oyuncunun mülkünü satın alabilirsin. Satış tamamlanınca bedelin %2’si hazineye işlem vergisi olarak gider.</p><button class="btn ikinci" onclick="ekranAc(mulkEkrani)">Kendi mülklerim</button></div>';
  if(!ilanlar.length)h+='<div class="kart"><p class="alt">Henüz satılık mülk yok. İlk ilanı sen verebilirsin.</p></div>';
  ilanlar.forEach(function(x){
    h+='<div class="kart"><div class="kv"><b>'+e({daire:'Daire',dukkan:'Dükkân',villa:'Villa'}[x.tip]||x.tip)+' #'+x.mulk_id+' · '+e(x.il)+'</b><span class="rozet altin">'+(x.benim?'Senin ilanın':'Satılık')+'</span></div>';
    h+='<div class="kv"><span>Satış bedeli</span><b>'+tlYaz(x.fiyat)+'</b></div><div class="kv"><span>Haftalık kira</span><b>'+tlYaz(x.haftalik)+'</b></div><div class="kv"><span>Satıcı</span><b>'+e(x.satici)+'</b></div>';
    h+='<button class="btn '+(x.benim?'ikinci':'altin')+'" onclick="'+(x.benim?'emlakIlanIptal('+x.id+')':'emlakIlanAl('+x.id+','+Number(x.fiyat)+')')+'">'+(x.benim?'İlanımı kaldır':'Bu mülkü satın al')+'</button></div>';
  });
  iskelet("Gayrimenkul Pazarı",h,{geri:true});
}
function mulkIlanModal(id,alis){
  const m=modal('<h3 style="font-size:19px;font-weight:800">Gayrimenkulü satışa çıkar</h3><p class="alt">Mülk #'+Number(id)+'. İlan verirken mülk sende kalır. Bir oyuncu alırsa para cüzdanına geçer (%2 işlem vergisi düşülür). Alıcı bulunmazsa ilanı kaldırabilirsin.</p><div class="alan"><label>Satış fiyatı (₺)</label><input id="mulkFiyat" type="number" min="10000" step="1000" value="'+Math.max(10000,Math.round(alis*1.1))+'" inputmode="numeric"></div><button class="btn altin" id="mulkOK">Satış ilanı aç</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  $("#mulkOK",m).onclick=async function(){
    let b=$("#mulkOK",m),f=Math.round(Number($("#mulkFiyat",m).value));
    if(!Number.isFinite(f)||f<10000)return toast("En az 10.000 ₺ girmelisin.",true);
    b.disabled=true;try{await API.rpc("mulk_ilan_ver",{p_mulk:id,p_fiyat:f});modalKapat();toast("Satış ilanı açıldı.");emlakPazarEkrani();}catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
  };
}
async function emlakIlanAl(id,fiyat){
  if(!await onayla("Satılık mülk","Bu mülkü "+tlYaz(fiyat)+" karşılığında alacaksın. Satış işlemi geri alınamaz.","Satın al"))return;
  try{emlakPazarCiz(await API.rpc("mulk_ilan_satin_al",{p_ilan:id}));toast("Mülk artık senin!");}
  catch(err){toast(hataCevir(err.message),true);}
}
async function emlakIlanIptal(id){
  if(!await onayla("İlanı kaldır","Mülkün sende kalacak. Satış ilanını kaldırmak istiyor musun?","İlanı kaldır"))return;
  try{emlakPazarCiz(await API.rpc("mulk_ilan_iptal",{p_ilan:id}));toast("İlan kaldırıldı.");}
  catch(err){toast(hataCevir(err.message),true);}
}
async function maasEkrani(){
  yukleniyor("Meclis Maaş Düzenlemeleri");
  try{maasCiz(await API.rpc("maas_durum"));}
  catch(err){iskelet("Meclis Maaş Düzenlemeleri",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function maasCiz(d){
  const o=d.oranlar||{};
  let h='<div class="kart"><h2>⚖️ Meclis maaş düzenlemeleri</h2><p class="alt">Cumhurbaşkanı kendi maaşını, milletvekilleri vekil maaşını değiştirmeyi önerebilir. Teklif 24 saat milletvekili oyuna açık kalır. Kabul edilirse tüm ilgili makamlara aynı oran uygulanır.</p>';
  h+='<div class="kv"><span>Cumhurbaşkanı maaş katsayısı</span><b>×'+fmt(o.cb||1,2)+'</b></div><div class="kv"><span>Milletvekili maaş katsayısı</span><b>×'+fmt(o.mv||1,2)+'</b></div>';
  if(d.cb_miyim)h+='<button class="btn altin" onclick="maasTeklifModal(\'cb\','+Number(o.cb||1)+')">Cumhurbaşkanı maaşı teklif et</button>';
  if(d.vekil_miyim)h+='<button class="btn altin" onclick="maasTeklifModal(\'mv\','+Number(o.mv||1)+')">Milletvekili maaşı teklif et</button>';
  h+='</div>';
  (d.teklifler||[]).forEach(function(t){
    h+='<div class="kart"><div class="baslik"><b>'+(t.tur==='cb'?'Cumhurbaşkanı':'Milletvekili')+' maaşı</b><span class="rozet '+(t.durum==='kabul'?'yesil':t.durum==='ret'?'kirmizi':'altin')+'">'+e({oylamada:'Oylamada',kabul:'Kabul',ret:'Reddedildi'}[t.durum]||t.durum)+'</span></div>';
    h+='<div class="kv"><span>Eski → Önerilen</span><b>×'+fmt(t.eski,2)+' → ×'+fmt(t.yeni,2)+'</b></div><div class="kv"><span>Oylar</span><b>'+fmt(t.evet)+' evet / '+fmt(t.hayir)+' hayır</b></div><p class="kucuk">Bitiş: '+tarihSaat(t.bit)+'</p>';
    if(t.durum==='oylamada'&&d.vekil_miyim)h+='<div class="satir"><button class="btn yarim '+(t.oyum==='evet'?'altin':'ikinci')+'" onclick="maasOyVer('+t.id+',\'evet\')">Evet</button><button class="btn yarim '+(t.oyum==='hayir'?'altin':'ikinci')+'" onclick="maasOyVer('+t.id+',\'hayir\')">Hayır</button></div>';
    h+='</div>';
  });
  if(!(d.teklifler||[]).length)h+='<div class="kart"><p class="alt">Henüz maaş teklifi yok.</p></div>';
  iskelet("Maaş Düzenlemeleri",h,{geri:true});
}
function maasTeklifModal(tur,mevcut){
  const m=modal('<h3 style="font-size:19px;font-weight:800">Maaş değişikliği teklif et</h3><p class="alt">Mevcut katsayı ×'+fmt(mevcut,2)+'. Yeni katsayı 0,5 ile 3 arasında olmalı. Yürürlüğe girmesi için Meclis oylamasında kabul edilmesi gerekir.</p><div class="alan"><label>Yeni maaş katsayısı (ör. 1.10 = %10 zam)</label><input id="maasKatsayi" type="number" min="0.5" max="3" step="0.05" value="'+(mevcut+0.1).toFixed(2)+'"></div><button class="btn altin" id="maasOK">Meclise sun</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  $("#maasOK",m).onclick=async()=>{const b=$("#maasOK",m);b.disabled=true;try{await API.rpc("maas_teklif_ver",{p_tur:tur,p_carpan:Number($("#maasKatsayi",m).value)});modalKapat();toast("Meclis oylaması başladı.");maasEkrani();}catch(err){b.disabled=false;toast(hataCevir(err.message),true);}};
}
async function maasOyVer(id,oy){
  try{maasCiz(await API.rpc("maas_oyla",{p_teklif:id,p_oy:oy}));toast("Oyun kaydedildi.");}
  catch(err){toast(hataCevir(err.message),true);}
}
async function bakanSoruEkrani(){
  yukleniyor("Bakanlara Yazılı Sorular");
  try{bakanSoruCiz(await API.rpc("bakan_sorulari"));}
  catch(err){iskelet("Bakanlara Sorular",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function bakanSoruCiz(d){
  D._bakanSoru=d;
  let h='<div class="kart"><h2>📝 Yazılı soru önergeleri</h2><p class="alt">Milletvekilleri bakanlara günde üç soru sorabilir. Bakan cevapları Meclis arşivinde tüm oyunculara açık tutulur.</p>';
  if(d.vekilim)h+='<button class="btn altin" onclick="bakanSoruModal()">Bakanlığa yazılı soru ver</button>';
  h+='</div>';
  (d.sorular||[]).forEach(function(s){
    h+='<div class="kart"><h3>'+e(s.konu)+'</h3><p class="kucuk">'+e(s.bakanlik)+' · '+e(s.soran)+' · '+tarihSaat(s.zaman)+'</p><p style="margin:10px 0;white-space:pre-wrap">'+e(s.soru)+'</p>';
    h+=s.yanit?'<div class="olay"><b>Bakanın yanıtı</b><p style="white-space:pre-wrap;margin-top:6px">'+e(s.yanit)+'</p><div class="kucuk">'+e(s.yanitlayan)+' · '+tarihSaat(s.yanit_at)+'</div></div>':'<span class="rozet altin">Yanıt bekliyor</span>';
    if(s.cevaplayabilirim)h+='<button class="btn altin" onclick="bakanYanitModal('+s.id+')">Bakan olarak yanıtla</button>';
    h+='</div>';
  });
  if(!(d.sorular||[]).length)h+='<div class="kart"><p class="alt">Henüz soru sorulmadı.</p></div>';
  iskelet("Bakanlara Sorular",h,{geri:true});
}
function bakanSoruModal(){
  const d=D._bakanSoru||{bakanliklar:[]};
  const m=modal('<h3>Yazılı soru önergesi</h3><div class="alan"><label>Hangi bakanlık?</label><select id="soruBakan">'+(d.bakanliklar||[]).map(x=>'<option value="'+e(x.kod)+'">'+e(x.ad)+'</option>').join('')+'</select></div><div class="alan"><label>Konu</label><input id="soruKonu" maxlength="100"></div><div class="alan"><label>Soru metni</label><textarea id="soruMetin" class="alanmetin" maxlength="2000"></textarea></div><button class="btn altin" id="soruOK">Soruyu gönder</button>');
  $("#soruOK",m).onclick=async()=>{let b=$("#soruOK",m);b.disabled=true;try{await API.rpc("bakan_soru_sor",{p_bakanlik:$("#soruBakan",m).value,p_konu:$("#soruKonu",m).value,p_soru:$("#soruMetin",m).value});modalKapat();toast("Soru önergesi kaydedildi.");bakanSoruEkrani();}catch(err){b.disabled=false;toast(hataCevir(err.message),true);}};
}
function bakanYanitModal(id){
  const m=modal('<h3>Yazılı soruya yanıt</h3><div class="alan"><label>Bakanlık yanıtı</label><textarea class="alanmetin" maxlength="3000" id="bakanYanit"></textarea></div><button class="btn altin" id="bakanOK">Yanıtı yayımla</button>');
  $("#bakanOK",m).onclick=async()=>{let b=$("#bakanOK",m);b.disabled=true;try{await API.rpc("bakan_soru_yanit",{p_id:id,p_yanit:$("#bakanYanit",m).value});modalKapat();toast("Bakanlık yanıtı yayımlandı.");bakanSoruEkrani();}catch(err){b.disabled=false;toast(hataCevir(err.message),true);}};
}
async function anketEkrani(){
  yukleniyor("Haftalık Siyasi Anket");
  try{anketCiz(await API.rpc("anket_durum"));}
  catch(err){iskelet("Haftalık Siyasi Anket",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function anketCiz(d){
  let h='<div class="kart"><h2>🗳️ Haftalık parti anketi</h2><p class="alt">Sadece oyuna kayıtlı oyuncuların katıldığı oyun içi ankettir; gerçek Türkiye kamuoyunu temsil etmez. Oy her hafta yenilenir.</p><div class="kv"><span>Hafta</span><b>'+e(d.hafta)+'</b></div><div class="kv"><span>Katılım</span><b>'+fmt(d.toplam)+' oyuncu</b></div></div>';
  (d.partiler||[]).sort((a,b)=>b.oy-a.oy).forEach(function(x){
    const oran=d.toplam?100*x.oy/d.toplam:0;
    h+='<div class="kart"><div class="kv"><span><b>'+e(x.ad)+'</b></span><b>%'+fmt(oran,1)+' · '+fmt(x.oy)+' oy</b></div><div class="bar"><i style="width:'+oran+'%;background:'+e(x.renk)+'"></i></div>';
    if(!d.oyum)h+='<button class="btn ikinci" onclick="anketOyVer('+x.id+')">Bu partiye oy ver</button>';
    else if(Number(d.oyum)===Number(x.id))h+='<span class="rozet yesil">Bu haftaki tercihin</span>';
    h+='</div>';
  });
  iskelet("Haftalık Parti Anketi",h,{geri:true});
}
async function anketOyVer(id){
  if(!await onayla("Siyasi anket","Bu haftaki oyunu bu partiye vermek istiyor musun? Oyunu değiştiremezsin.","Oy ver"))return;
  try{anketCiz(await API.rpc("anket_oyla",{p_parti:id}));toast("Anket oyun kaydedildi.");}
  catch(err){toast(hataCevir(err.message),true);}
}
