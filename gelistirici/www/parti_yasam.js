/* Partilerin haftalık iletişimi ve demokratik disiplin oylamaları. */
async function grupToplantiEkrani(pid){
  yukleniyor("Parti Grup Toplantıları");
  try{grupToplantiCiz(pid,await API.rpc("grup_duyurulari",{p_parti:pid}));}
  catch(err){iskelet("Parti Grup Toplantıları",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function grupToplantiCiz(pid,d){
  let h='<div class="kart"><h2>Parti yönetiminin grup konuşmaları</h2><p class="alt">Genel başkan ve Tanıtım ve Medyadan Sorumlu Genel Başkan Yardımcısı üyelere konuşma yayımlayabilir; duyurular arşivlenir ve üyeler bildirim alır.</p>';
  if(d.yazabilirim||(typeof yetkiAlan==='function'&&yetkiAlan('tanitim',pid)))h+='<button class="btn altin" onclick="grupKonusmaModal('+pid+')">Yeni grup konuşması yap</button>';
  h+='</div>';
  (d.kayitlar||[]).forEach(function(k){h+='<div class="kart"><h3>'+e(k.baslik)+'</h3><p class="kucuk">'+e(k.yazan)+' · '+tarihSaat(k.tarih)+'</p><p style="white-space:pre-wrap;margin-top:10px">'+e(k.metin)+'</p></div>';});
  if(!(d.kayitlar||[]).length)h+='<div class="kart"><p class="alt">Henüz konuşma yapılmadı.</p></div>';
  iskelet("Grup Toplantıları",h,{geri:true});
}
function grupKonusmaModal(pid){
  const m=modal('<h3>Yeni grup konuşması</h3><div class="alan"><label>Konuşma başlığı</label><input maxlength="120" id="grupBaslik" placeholder="Örnek: Ekonomi gündemi"></div><div class="alan"><label>Konuşma metni</label><textarea class="alanmetin" id="grupMetin" maxlength="3000"></textarea></div><button class="btn altin" id="grupOK">Yayımla</button>');
  $("#grupOK",m).onclick=async()=>{let b=$("#grupOK",m);b.disabled=true;try{await API.rpc("grup_duyuru_yayinla",{p_baslik:$("#grupBaslik",m).value,p_metin:$("#grupMetin",m).value});modalKapat();toast("Konuşma üyelere duyuruldu.");grupToplantiEkrani(pid);}catch(err){b.disabled=false;toast(hataCevir(err.message),true);}};
}
async function partiDisiplinEkrani(pid){
  yukleniyor("Parti Disiplin Kurulu");
  try{partiDisiplinCiz(pid,await API.rpc("disiplin_durum",{p_parti:pid}));}
  catch(err){iskelet("Parti Disiplin Kurulu",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function partiDisiplinCiz(pid,d){
  let h='<div class="kart"><h2>Parti disiplin kurulu</h2><p class="alt">Genel başkan ve Siyasi ve Hukuki İşlerden Sorumlu Genel Başkan Yardımcısı üyeyi disiplin oylamasına sevk edebilir. İhraç için 24 saatlik oylamada hedef üye hariç seçmenlerin çoğunluğu gerekir. Genel başkan bu yolla ihraç edilemez.</p>';
  if(d.gb_miyim||(typeof yetkiAlan==='function'&&yetkiAlan('hukuk',pid)))h+='<button class="btn altin" onclick="partiDisiplinModal('+pid+')">Üyeyi disipline sevk et</button>';
  h+='</div>';
  (d.kayitlar||[]).forEach(function(k){
    let bitti=k.durum!=='oylamada';
    h+='<div class="kart"><div style="display:flex;justify-content:space-between;gap:10px"><b>'+e(k.hedef)+'</b><span class="rozet '+(k.durum==='ihrac'?'kirmizi':k.durum==='ret'?'yesil':'altin')+'">'+e({oylamada:'Oylama sürüyor',ihrac:'İhraç edildi',ret:'Öneri reddedildi'}[k.durum]||k.durum)+'</span></div><p class="alt" style="margin-top:8px">'+e(k.gerekce)+'</p><div class="kv"><span>Oylama</span><b>'+fmt(k.evet)+' evet / '+fmt(k.hayir)+' hayır</b></div><p class="kucuk">Oylama bitişi: '+tarihSaat(k.bit)+'</p>';
    if(!bitti&&d.uye_miyim&&!k.oyum)h+='<div class="satir"><button class="btn yarim tehlike" onclick="partiDisiplinOy('+pid+','+k.id+',\'evet\')">İhraç edilsin</button><button class="btn yarim ikinci" onclick="partiDisiplinOy('+pid+','+k.id+',\'hayir\')">İhraç edilmesin</button></div>';
    else if(k.oyum)h+='<div class="kucuk">Kullandığın oy: '+(k.oyum==='evet'?'İhraç edilsin':'İhraç edilmesin')+'</div>';
    h+='</div>';
  });
  if(!(d.kayitlar||[]).length)h+='<div class="kart"><p class="alt">Henüz disiplin oylaması yok.</p></div>';
  iskelet("Parti Disiplin Kurulu",h,{geri:true});
}
function partiDisiplinModal(pid){
  const m=modal('<h3>Üyeyi disipline sevk et</h3><p class="alt">Partinin üyeleri 24 saat oy kullanacak. İhraç için üye çoğunluğu gerekir.</p><div class="alan"><label>Üyenin kullanıcı adı</label><input id="disKad" maxlength="40"></div><div class="alan"><label>Gerekçe</label><textarea class="alanmetin" id="disGerekce" maxlength="500"></textarea></div><button class="btn tehlike" id="disOK">Oylamayı başlat</button>');
  $("#disOK",m).onclick=async()=>{let b=$("#disOK",m);b.disabled=true;try{await API.rpc("disiplin_baslat",{p_hedef:$("#disKad",m).value,p_gerekce:$("#disGerekce",m).value});modalKapat();toast("Disiplin oylaması başladı.");partiDisiplinEkrani(pid);}catch(err){b.disabled=false;toast(hataCevir(err.message),true);}};
}
async function partiDisiplinOy(pid,id,oy){
  if(!await onayla("Disiplin oylaması","Tercihini kaydetmek istiyor musun?","Oy ver"))return;
  try{partiDisiplinCiz(pid,await API.rpc("disiplin_oyla",{p_id:id,p_oy:oy}));toast("Oyun kaydedildi.");}catch(err){toast(hataCevir(err.message),true);}
}
