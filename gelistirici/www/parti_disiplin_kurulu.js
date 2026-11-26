/* 26.11.2026 · Parti MYK + seçilmiş Disiplin Kurulu ekranı.
   parti_yasam.js'deki eski "üye oylaması" ekranının (partiDisiplinEkrani) yerine geçer.
   Sunucu: zz_20261126_parti_disiplin_kurulu.sql (pdk_* RPC'leri). Sunucu eskiyse eski ekran açılır. */
(function(){
const PDK_DURUM={myk:['MYK oylamasında','altin'],myk_ret:['MYK reddetti','yesil'],savunma:['Savunma bekleniyor','sari'],kurul:['Kurul oylamasında','sari'],
  karar:['Karar verildi · itiraz süresi','kirmizi'],itiraz:['İtiraz incelemesinde','sari'],kesin:['Kesinleşti',''],dustu:['Dosya düştü','yesil']};
const PDK_CEZA={beraat:'Beraat',uyari:'Uyarı',kinama:'Kınama',gecici:'Geçici çıkarma',kesin:'Kesin ihraç'};
const PDK_SIRA=['beraat','uyari','kinama','gecici','kesin'];
let PDK=null;
const t=x=>x?tarihSaat(x):'—';
const tl=n=>(typeof tlYaz==='function'?tlYaz(n):fmt(n)+' ₺');

const eskiEkran=typeof partiDisiplinEkrani==='function'?partiDisiplinEkrani:null;
window.partiDisiplinEkrani=async function(pid){
  yukleniyor("MYK ve Disiplin Kurulu");
  let d,b;
  try{[d,b]=await Promise.all([API.rpc("pdk_panel",{p_parti:pid}),API.rpc("pdk_benim").catch(()=>null)]);}
  catch(err){
    if(eskiEkran&&/pdk_panel|function|could not find/i.test(String(err.message)))return eskiEkran(pid);
    return iskelet("MYK ve Disiplin Kurulu",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});
  }
  PDK={pid,d,b};pdkCiz();
};

function pdkBilgi(k){
  return '<div class="kart"><details><summary style="cursor:pointer;font-weight:700">Disiplin süreci nasıl işler? (Aç)</summary>'
  +'<div class="kv"><span class="k">1 · Sevk</span><span class="v">MYK (genel başkan + yardımcılar) gerekçe, kanıt ve ceza istemiyle önerir; '+k.myk_saat+' saatte salt çoğunlukla sevk eder.</span></div>'
  +'<div class="kv"><span class="k">2 · Savunma</span><span class="v">Üyenin '+k.savunma_saat+' saati var. İsteğe bağlı tedbir: dosya sürerken parti sohbetine yazamaz.</span></div>'
  +'<div class="kv"><span class="k">3 · Karar</span><span class="v">Seçilmiş Disiplin Kurulu '+k.kurul_saat+' saatte karar verir (kurul yoksa kurayla 3 üye). Yeter sayı 2/3; çıkarma için kurul tamsayısının salt çoğunluğu gerekir. Kurul istenenden ağır ceza veremez.</span></div>'
  +'<div class="kv"><span class="k">4 · İtiraz</span><span class="v">Geçici/kesin çıkarmaya '+k.itiraz_saat+' saatte bir kez, '+tl(k.itiraz_harc)+' harçla. Partiden bağımsız 3 kişilik gizli heyet bakar; kabul edilirse ceza kalkar ve harç iade edilir.</span></div>'
  +'<div class="kv"><span class="k">Adalet kilitleri</span><span class="v">Kurultay sürerken disiplin yok · imza kampanyasındakiler önerilemez · haftalık ihraç sınırı · genel başkan sevk edilemez · ihraç edilen '+k.yasak_gun+' gün aynı partiye dönemez.</span></div>'
  +'</details></div>';
}

function pdkCiz(){
  const {pid,d,b}=PDK, ben=d.ben||{};
  let h='<div class="kart"><h2>'+e(d.parti.kisa)+' · MYK ve Disiplin Kurulu</h2><p class="alt">Disipline sevki MYK yapar, kararı partinin seçtiği Disiplin Kurulu verir. Üyeler tek tek oylamaz.</p>';
  if(d.kilit)h+='<div class="rozet sari" style="margin-top:8px">Kurultay kilidi: '+t(d.kilit)+' tarihine kadar yeni disiplin önerisi yok</div>';
  if(ben.askida)h+='<div class="rozet kirmizi" style="margin-top:8px">Hakkında tedbir/ceza var: '+t(ben.askida)+' tarihine kadar parti sohbetine yazamazsın</div>';
  if(ben.myk)h+='<button class="btn tehlike" style="margin-top:12px" onclick="pdkOnerModal()"'+(d.kilit?' disabled':'')+'>Üyeyi disipline öner</button><p class="kucuk">Bu hafta kesin ihraç istemli dosya: '+fmt(d.kota.kullanilan)+' / '+fmt(d.kota.sinir)+'</p>';
  h+='</div>';
  h+=pdkBilgi(d.kurallar);
  // kişisel dosyalar (başka partideyken de görünür)
  const benimki=((b&&b.dosyalarim)||[]).filter(x=>x.ben&&(x.ben.savunabilir||x.ben.itiraz_edebilir));
  benimki.forEach(x=>{h+=pdkDosya(x,true);});
  // MYK
  h+='<div class="kart"><h3>Merkez Yürütme Kurulu (MYK)</h3>'+(d.myk.length?d.myk.map(m=>'<div class="kv"><span class="k">'+e(m.gorev)+'</span><span class="v">'+e(m.ad||m.kad)+'</span></div>').join(''):'<p class="alt">Genel başkan seçilmedi.</p>')
   +'<p class="kucuk">MYK üyeleri parti yönetimi sohbetini kullanır ve Disiplin Kurulu\'na aday olamaz.</p></div>';
  // Kurul
  const asil=d.kurul.filter(k=>k.tur==='asil'), yedek=d.kurul.filter(k=>k.tur==='yedek');
  h+='<div class="kart"><h3>Disiplin Kurulu</h3>';
  if(asil.length)h+=asil.map(k=>'<div class="kv"><span class="k">Asil '+k.sira+'</span><span class="v">'+e(k.ad||k.kad)+' <span class="kucuk">('+fmt(k.oy)+' oy)</span></span></div>').join('')
    +(yedek.length?yedek.map(k=>'<div class="kv"><span class="k">Yedek</span><span class="v">'+e(k.ad||k.kad)+'</span></div>').join(''):'');
  else h+='<p class="alt">Kurul henüz seçilmedi. Bu sürede her dosya için son 3 günde aktif, MYK dışı üyeler arasından kurayla 3 asil + 2 yedek görevlendirilir.</p>';
  if(asil.length&&asil.length<5)h+='<p class="kucuk">Asil üye sayısı 5\'in altında; dosyalar kurayla kurulan kurulda görülür.</p>';
  if(ben.kurul)h+='<div class="rozet altin" style="margin-top:8px">Kurul üyesisin ('+(ben.kurul==='asil'?'asil':'yedek')+')</div>';
  h+='</div>';
  h+=pdkSecimHtml(d.secim);
  // dosyalar
  h+='<div class="kart"><h3>Dosyalar</h3>'+(d.dosyalar.length?'':'<p class="alt">Henüz disiplin dosyası yok.</p>')+'</div>';
  d.dosyalar.forEach(x=>{ if(!benimki.some(y=>y.id===x.id)) h+=pdkDosya(x,false); });
  iskelet("MYK ve Disiplin Kurulu",h,{geri:true});
}

function pdkSecimHtml(s){
  if(!s||(s.durum!=='aday'&&s.durum!=='oy'))return '';
  let h='<div class="kart"><h3>Disiplin Kurulu seçimi</h3>';
  if(s.durum==='aday'){
    h+='<p class="alt">Adaylık '+t(s.aday_bit)+' tarihinde kapanır, ardından 24 saat oylama. Her üye tek oy verir; en çok oy alan 7 kişi asil, sonraki 3 kişi yedek olur.</p>';
    if(s.aday_miyim)h+='<div class="rozet yesil">✓ Adaysın</div><button class="btn ikinci" onclick="pdkCekil()">Adaylıktan çekil</button>';
    else if(s.aday_engel)h+='<p class="kucuk">'+e(s.aday_engel)+'</p>';
    else h+='<button class="btn altin" onclick="pdkAdayModal()">Disiplin Kurulu\'na aday ol</button>';
  }else{
    h+='<p class="alt">Oylama '+t(s.oy_bit)+' tarihinde kapanır. '+fmt(s.oy_sayisi)+' üye oy verdi.</p>';
    if(s.oy_engel)h+='<p class="kucuk">'+e(s.oy_engel)+'</p>';
    if(s.oyum)h+='<div class="rozet yesil">Oyun: '+e(s.oyum)+' (değiştirebilirsin)</div>';
  }
  h+=(s.adaylar||[]).map(a=>'<div class="liste-satir"><div class="orta"><b>'+e(a.ad||a.kad)+'</b>'+(a.tanitim?'<div class="kucuk" style="white-space:pre-wrap">'+e(a.tanitim)+'</div>':'')+'</div>'
     +(s.durum==='oy'&&!s.oy_engel&&s.oyum!==a.kad?'<button class="btn yarim" style="max-width:120px" onclick="pdkOy(\''+e(a.kad)+'\')">Oy ver</button>':'')+'</div>').join('')
   ||'<p class="kucuk">Henüz aday yok.</p>';
  return h+'</div>';
}

function pdkSure(x){
  const s={myk:['MYK kararı',x.myk_son],savunma:['Savunma son',x.savunma_son],kurul:['Kurul kararı son',x.karar_son],karar:['İtiraz son',x.itiraz_son],itiraz:['Heyet kararı son',x.itiraz_karar_son]}[x.durum];
  return s?'<div class="kv"><span class="k">'+s[0]+'</span><span class="v">'+t(s[1])+'</span></div>':'';
}

function pdkDosya(x,kendi){
  const ben=x.ben||{}, dr=PDK_DURUM[x.durum]||[x.durum,''];
  let h='<div class="kart">'+(kendi?'<div class="rozet kirmizi" style="margin-bottom:8px">Hakkındaki dosya'+(x.parti?' · '+e(x.parti):'')+'</div>':'')
   +'<div style="display:flex;justify-content:space-between;gap:10px;align-items:flex-start"><b>'+e(x.hedef_ad||x.hedef)+'</b><span class="rozet '+dr[1]+'">'+e(dr[0])+'</span></div>'
   +'<div class="kv"><span class="k">Sebep</span><span class="v">'+e(x.sebep_ad||x.sebep)+'</span></div>'
   +'<div class="kv"><span class="k">İstem</span><span class="v">'+e(x.istem_ad)+(x.istem==='gecici'?' ('+x.gecici_gun+' gün)':'')+(x.tedbir?' · tedbirli':'')+'</span></div>'
   +pdkSure(x)
   +'<details style="margin-top:8px"><summary style="cursor:pointer;font-weight:600">Gerekçe, kanıt ve savunma</summary>'
   +'<p class="alt" style="white-space:pre-wrap"><b>Gerekçe:</b> '+e(x.gerekce)+'</p><p class="alt" style="white-space:pre-wrap"><b>Kanıt:</b> '+e(x.kanit||'—')+'</p>'
   +'<p class="alt" style="white-space:pre-wrap"><b>Savunma:</b> '+(x.savunma?e(x.savunma):'<i>verilmedi</i>')+'</p>'
   +(x.itiraz_gerekce?'<p class="alt" style="white-space:pre-wrap"><b>İtiraz:</b> '+e(x.itiraz_gerekce)+'</p>':'')+'</details>';
  if(x.durum==='myk')h+='<div class="kv"><span class="k">MYK oyu</span><span class="v">'+fmt(x.myk_evet)+' evet / '+fmt(x.myk_hayir)+' hayır · '+fmt(x.myk_n)+' üye</span></div>';
  if(['savunma','kurul'].includes(x.durum)||x.heyet_n)h+='<div class="kv"><span class="k">Kurul</span><span class="v">'+(x.heyet_tur==='kura'?'Kurayla ':'Seçilmiş kurul · ')+fmt(x.heyet_n)+' üye'+(x.durum==='kurul'?' · '+fmt(x.kurul_oy_veren)+' oy verdi':'')+(x.uzatildi?' · yedekler çağrıldı':'')+'</span></div>';
  if(x.sonuc)h+='<div class="kv"><span class="k">Karar</span><span class="v"><b>'+e(x.sonuc_ad)+'</b>'+(x.ceza_bit?' · bitiş '+t(x.ceza_bit):'')+'</span></div>';
  if(x.itiraz_sonuc)h+='<div class="kv"><span class="k">İtiraz</span><span class="v">'+(x.itiraz_sonuc==='iptal'?'Kabul edildi, karar kaldırıldı':'Reddedildi, karar kesinleşti')+'</span></div>';
  if(x.durum==='dustu'&&x.sonuc_ozet&&x.sonuc_ozet.neden)h+='<p class="kucuk">'+e(x.sonuc_ozet.neden)+'</p>';
  // eylemler
  if(ben.myk_oyabilir){
    h+=(ben.myk_oy?'<p class="kucuk">Oyun: '+(ben.myk_oy==='evet'?'Sevk edilsin':'Sevk edilmesin')+' (değiştirebilirsin)</p>':'')
     +'<div class="satir"><button class="btn yarim tehlike" onclick="pdkMykOy('+x.id+',\'evet\')">Sevk edilsin</button><button class="btn yarim ikinci" onclick="pdkMykOy('+x.id+',\'hayir\')">Sevk edilmesin</button></div>';
  }
  if(ben.savunabilir)h+='<button class="btn altin" onclick="pdkSavunmaModal('+x.id+')">Savunmanı yaz</button>';
  if(ben.kurul_oyabilir)h+=(ben.kurul_oy?'<p class="kucuk">Oyun: '+e(PDK_CEZA[ben.kurul_oy])+' (değiştirebilirsin)</p>':'<p class="kucuk">Kurul üyesi olarak oyunu kullan.</p>')
     +'<button class="btn" onclick="pdkKurulModal('+x.id+',\''+x.istem+'\')">Kurul oyu ver</button>';
  if(ben.itiraz_edebilir)h+='<button class="btn ikinci" onclick="pdkItirazModal('+x.id+')">Karara itiraz et · '+tl(PDK.d.kurallar.itiraz_harc)+'</button>';
  return h+'</div>';
}

async function pdkYenile(veri,mesaj){
  if(mesaj)toast(mesaj);
  if(veri&&veri.dosyalar&&PDK){PDK.d=veri;try{PDK.b=await API.rpc("pdk_benim");}catch(_){}
    pdkCiz();}
  else if(PDK&&PDK.pid)partiDisiplinEkrani(PDK.pid);
  else pdkItirazEkrani();
}
async function pdkCagir(ad,arg,mesaj,btn){
  if(btn)btn.disabled=true;
  try{const r=await API.rpc(ad,arg);modalKapat();await pdkYenile(r,mesaj);}
  catch(err){if(btn)btn.disabled=false;toast(hataCevir(err.message),true);}
}

window.pdkOnerModal=function(){
  const d=PDK.d;
  const m=modal('<h3>Üyeyi disipline öner</h3><p class="alt">Öneri MYK\'da '+d.kurallar.myk_saat+' saat oylanır; salt çoğunluk sağlanırsa Disiplin Kurulu\'na sevk edilir.</p>'
   +'<div class="alan"><label>Üye (Ad Soyad ya da kullanıcı adı)</label><input id="pdkHedef" maxlength="60" autocomplete="off"></div>'
   +'<div class="alan"><label>Sebep</label><select id="pdkSebep">'+d.sebepler.map(s=>'<option value="'+e(s.kod)+'">'+e(s.ad)+'</option>').join('')+'</select></div>'
   +'<div class="alan"><label>Ceza istemi (kurul daha hafifini verebilir)</label><select id="pdkIstem"><option value="uyari">Uyarı</option><option value="kinama">Kınama</option><option value="gecici">Geçici çıkarma (3–14 gün)</option><option value="kesin">Kesin ihraç</option></select></div>'
   +'<div class="alan" id="pdkGunAlan" style="display:none"><label>Geçici çıkarma süresi (gün)</label><input id="pdkGun" type="number" min="3" max="14" value="7" inputmode="numeric"></div>'
   +'<label class="onay"><input type="checkbox" id="pdkTedbir"><span>Tedbir: dosya sürerken parti sohbetine yazamasın</span></label>'
   +'<div class="alan"><label>Gerekçe</label><textarea class="alanmetin" id="pdkGerekce" maxlength="2000" placeholder="Ne oldu, hangi kurala aykırı?"></textarea></div>'
   +'<div class="alan"><label>Kanıt</label><textarea class="alanmetin" id="pdkKanit" maxlength="1000" placeholder="Mesaj alıntısı, paylaşım, tarih/saat"></textarea></div>'
   +'<button class="btn tehlike" id="pdkOK">MYK oylamasına sun</button>');
  const ist=$("#pdkIstem",m);ist.onchange=()=>{$("#pdkGunAlan",m).style.display=ist.value==='gecici'?'':'none';};
  $("#pdkOK",m).onclick=function(){pdkCagir("pdk_oner",{p_hedef:$("#pdkHedef",m).value,p_sebep:$("#pdkSebep",m).value,p_istem:ist.value,
    p_gecici_gun:ist.value==='gecici'?parseInt($("#pdkGun",m).value,10):null,p_tedbir:$("#pdkTedbir",m).checked,
    p_gerekce:$("#pdkGerekce",m).value,p_kanit:$("#pdkKanit",m).value},"Öneri MYK oylamasına sunuldu.",this);};
};
window.pdkMykOy=async function(id,oy){
  if(!await onayla("MYK oylaması",oy==='evet'?"Üye Disiplin Kurulu'na sevk edilsin mi?":"Sevke karşı oy vereceksin.","Oy ver",oy==='evet'))return;
  pdkCagir("pdk_myk_oy",{p_dosya:id,p_oy:oy},"MYK oyun kaydedildi.");
};
window.pdkSavunmaModal=function(id){
  const m=modal('<h3>Savunma</h3><p class="alt">Savunmanı gönderdiğinde kurul oylaması hemen başlar. Bir kez gönderilir.</p><div class="alan"><label>Savunman</label><textarea class="alanmetin" id="pdkSav" maxlength="3000"></textarea></div><button class="btn altin" id="pdkOK">Savunmayı gönder</button>');
  $("#pdkOK",m).onclick=function(){pdkCagir("pdk_savunma",{p_dosya:id,p_metin:$("#pdkSav",m).value},"Savunman kurula iletildi.",this);};
};
window.pdkKurulModal=function(id,istem){
  const sec=PDK_SIRA.slice(0,PDK_SIRA.indexOf(istem)+1);
  const m=modal('<h3>Kurul oyu</h3><p class="alt">Gerekçeyi, kanıtı ve savunmayı okuduktan sonra karar ver. Oyların tek tek kimin olduğu gösterilmez.</p>'
   +'<div class="alan"><label>Kararın</label><select id="pdkKO">'+sec.map(s=>'<option value="'+s+'">'+PDK_CEZA[s]+'</option>').join('')+'</select></div>'
   +'<div class="alan"><label>Kısa gerekçe (isteğe bağlı)</label><textarea class="alanmetin" id="pdkKG" maxlength="500"></textarea></div><button class="btn" id="pdkOK">Oyu kaydet</button>');
  $("#pdkOK",m).onclick=function(){pdkCagir("pdk_kurul_oy",{p_dosya:id,p_oy:$("#pdkKO",m).value,p_gerekce:$("#pdkKG",m).value},"Kurul oyun kaydedildi.",this);};
};
window.pdkItirazModal=function(id){
  const m=modal('<h3>Karara itiraz</h3><p class="alt">İtiraz bir kez yapılır; '+tl(PDK.d.kurallar.itiraz_harc)+' harç cüzdanından alınır. Partiden bağımsız 3 kişilik heyet 72 saatte karar verir. Kabul edilirse harç iade edilir.</p><div class="alan"><label>İtiraz gerekçen</label><textarea class="alanmetin" id="pdkIt" maxlength="2000"></textarea></div><button class="btn ikinci" id="pdkOK">İtiraz et</button>');
  $("#pdkOK",m).onclick=function(){pdkCagir("pdk_itiraz",{p_dosya:id,p_gerekce:$("#pdkIt",m).value},"İtirazın heyete gönderildi.",this);};
};
window.pdkAdayModal=function(){
  const m=modal('<h3>Disiplin Kurulu adaylığı</h3><p class="alt">Kurul üyesi tarafsız ve gerekçeli karar verir. Seçilirsen MYK görevi alamazsın.</p><div class="alan"><label>Kısa tanıtım (isteğe bağlı)</label><textarea class="alanmetin" id="pdkTan" maxlength="400"></textarea></div><button class="btn altin" id="pdkOK">Aday ol</button>');
  $("#pdkOK",m).onclick=function(){pdkCagir("pdk_aday_ol",{p_tanitim:$("#pdkTan",m).value},"Adaylığın alındı.",this);};
};
window.pdkCekil=async function(){
  if(!await onayla("Adaylıktan çekil","Disiplin Kurulu adaylığından çekilmek istiyor musun?","Çekil",true))return;
  pdkCagir("pdk_aday_cekil",{},"Adaylıktan çekildin.");
};
window.pdkOy=async function(kad){
  if(!await onayla("Disiplin Kurulu seçimi",kad+" adayına oy vereceksin. Tek oyun var; süre bitene kadar değiştirebilirsin.","Oy ver"))return;
  pdkCagir("pdk_secim_oy",{p_aday:kad},"Oyun kaydedildi.");
};

// ---- Adliye › Parti Disiplin İtirazları (itiraz heyeti görevleri ve kişinin kendi dosyaları)
window.pdkItirazEkrani=async function(){
  yukleniyor("Parti Disiplin İtirazları");
  let b;try{b=await API.rpc("pdk_benim");}catch(err){return iskelet("Parti Disiplin İtirazları",'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
  PDK={pid:null,d:{kurallar:{itiraz_harc:25000}},b};
  let h='<div class="kart"><h2>Parti Disiplin İtirazları</h2><p class="alt">Kurayla seçildiğin itiraz heyeti görevleri ve hakkındaki disiplin dosyaları. Heyet üyelerinin adı taraflara gösterilmez.</p></div>';
  (b.itiraz_gorevlerim||[]).forEach(x=>{
    h+='<div class="kart"><div style="display:flex;justify-content:space-between;gap:10px"><b>'+e(x.parti)+' · '+e(x.hedef_ad||x.hedef)+'</b><span class="rozet '+(x.durum==='itiraz'?'sari':'')+'">'+(x.durum==='itiraz'?'Karar bekliyor':'Sonuçlandı')+'</span></div>'
     +'<div class="kv"><span class="k">Kurul kararı</span><span class="v">'+e(x.sonuc_ad)+'</span></div><div class="kv"><span class="k">Sebep</span><span class="v">'+e(x.sebep_ad||x.sebep)+'</span></div>'
     +(x.durum==='itiraz'?'<div class="kv"><span class="k">Son</span><span class="v">'+t(x.itiraz_karar_son)+'</span></div>':'')
     +'<p class="alt" style="white-space:pre-wrap"><b>Gerekçe:</b> '+e(x.gerekce)+'</p><p class="alt" style="white-space:pre-wrap"><b>Kanıt:</b> '+e(x.kanit||'—')+'</p>'
     +'<p class="alt" style="white-space:pre-wrap"><b>Savunma:</b> '+(x.savunma?e(x.savunma):'<i>verilmedi</i>')+'</p><p class="alt" style="white-space:pre-wrap"><b>İtiraz:</b> '+e(x.itiraz_gerekce||'')+'</p>'
     +(x.ben&&x.ben.itiraz_oyabilir?(x.ben.itiraz_oy?'<p class="kucuk">Oyun: '+(x.ben.itiraz_oy==='iptal'?'Karar kaldırılsın':'Karar onaylansın')+'</p>':'')
       +'<div class="satir"><button class="btn yarim" onclick="pdkItirazOy('+x.id+',\'onay\')">Karar onaylansın</button><button class="btn yarim ikinci" onclick="pdkItirazOy('+x.id+',\'iptal\')">Karar kaldırılsın</button></div>':'')+'</div>';
  });
  (b.dosyalarim||[]).forEach(x=>{h+=pdkDosya(x,true);});
  if(!(b.itiraz_gorevlerim||[]).length&&!(b.dosyalarim||[]).length)h+='<div class="kart"><p class="alt">Şu an görevin ya da dosyan yok.</p></div>';
  iskelet("Parti Disiplin İtirazları",h,{geri:true});
};
window.pdkItirazOy=async function(id,oy){
  if(!await onayla("İtiraz heyeti",oy==='iptal'?"Disiplin kararı kaldırılsın mı?":"Disiplin kararı onaylansın mı?","Oy ver"))return;
  try{await API.rpc("pdk_itiraz_oy",{p_dosya:id,p_oy:oy});toast("Oyun kaydedildi.");pdkItirazEkrani();}catch(err){toast(hataCevir(err.message),true);}
};

// Adliye ekranının başına, görevi ya da dosyası olana kısa kart
if(typeof adliyeHtml==='function'){
  const eski=adliyeHtml;
  window.adliyeHtml=adliyeHtml=async function(){
    const [h,b]=await Promise.all([eski.apply(this,arguments),API.rpc("pdk_benim").catch(()=>null)]);
    if(!b)return h;
    const g=(b.itiraz_gorevlerim||[]).filter(x=>x.durum==='itiraz').length, k=(b.dosyalarim||[]).filter(x=>x.ben&&(x.ben.savunabilir||x.ben.itiraz_edebilir)).length;
    if(!g&&!k)return h;
    return '<div class="kart"><h3>Parti Disiplin İtirazları</h3><p class="alt">'+(g?fmt(g)+' itiraz dosyasında heyet üyesisin. ':'')+(k?'Hakkında işlem bekleyen disiplin dosyası var.':'')+'</p><button class="btn altin" onclick="ekranAc(pdkItirazEkrani)">Aç</button></div>'+h;
  };
}
// Açılışta bir kez istemci sürümünü bildir (sunucu, yeni sürüme geçen oyuncu oranı %70'i bulunca kurul seçimlerini kendiliğinden açar)
(function bildir(n){
  try{
    if(typeof D!=='undefined'&&D.durum&&D.durum.profil&&typeof API!=='undefined'){
      const pl=window.Capacitor&&typeof window.Capacitor.getPlatform==='function'?window.Capacitor.getPlatform():'web';
      API.rpc("istemci_bildir",{p_surum:String(window.UYGULAMA_SURUM||'?'),p_platform:pl}).catch(()=>{});
      return;
    }
  }catch(_){}
  if(n<120)setTimeout(()=>bildir(n+1),5000);
})(0);
})();
