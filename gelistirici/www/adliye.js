/* ADLİYE: Yüksek Yargıç, parti sözcüsü, açık yargılama ve Cumhurbaşkanlığı affı */
const ADL_TURLER={hakaret:"Hakaret",iftira:"İftira",rusvet:"Rüşvet",yolsuzluk:"Yolsuzluk",usulsuzluk:"Usulsüz işlem",dolandiricilik:"Dolandırıcılık",diger:"Diğer"};
const ADL_CEZALAR={beraat:"Beraat",uyari:"Uyarı",sustur_1s:"1 saat sohbetten susturma",sustur_1g:"1 gün sohbetten susturma",sustur_1h:"1 hafta sohbetten susturma",vekillik_dusur:"Milletvekilliğinin düşürülmesi"};
let ADL={};
function adlTarih(t){return t?tarihSaat(t):"—";}
function adlEtiket(d){return d.durum==="karar"?(d.af_at?"Af çıkarıldı":"Karar verildi"):"Savunma aşaması";}
function adlFormBaslik(m,baslik){m.querySelector(".modal").insertAdjacentHTML("afterbegin",'<h3 style="font-size:20px;margin:0 0 12px">'+e(baslik)+'</h3>');}
function adlAlan(ad,id,tur="text",placeholder=""){return '<div class="alan"><label>'+e(ad)+'</label>'+ (tur==="textarea"?'<textarea id="'+id+'" rows="4" placeholder="'+e(placeholder)+'"></textarea>':'<input id="'+id+'" type="'+tur+'" placeholder="'+e(placeholder)+'">')+'</div>';}
async function adlIslem(fn,success,geri,modalKapatilsin=true){
 try{await fn();if(modalKapatilsin)modalKapat();toast(success);if(geri)await adliyeDosya(geri);else{D.devletSekme="adliye";await devletEkrani();}}
 catch(err){toast(hataCevir(err.message),true);}
}
async function adliyeHtml(){
 const d=await API.rpc("adliye_durum");ADL=d;
 const yer=d.partiler.find(p=>p.id===d.parti_id);
 const acik=d.davalar.filter(x=>x.durum==="acik");
 const bitmis=d.davalar.filter(x=>x.durum!=="acik");
 return '<div class="kart"><h3>Yüksek Yargı</h3>'
  +'<p class="alt">Herkese açık davalar · Tek Yüksek Yargıç · Sözlü savunma · Gerekçeli karar · Cumhurbaşkanlığı affı</p>'
  +'<div class="kv"><span class="k">Yüksek Yargıç</span><span class="v">'+e(d.hakim||"Henüz atanmadı")+'</span></div>'
  +(d.hakim_miyim?'<div class="rozet altin" style="margin-top:10px">Yüksek Yargıç yetkiniz aktif</div>':'')
  +(d.cb_miyim?'<button class="btn altin" onclick="adlHakimModal()">Yargıç ata veya görevden al</button><button class="btn ikinci" onclick="adlAfModal(null)">Genel af ilan et</button>':'')
  +'<button class="btn" onclick="adlDavaModal()">Dava aç</button></div>'
  +'<div class="kart"><h3>Parti Sözcüleri</h3><p class="alt">Sözcü, partisini doğrudan; parti üyelerini ise davalının izniyle savunur.</p>'
  +d.partiler.map(pa=>'<div class="liste-satir"><div class="orta"><b>'+e(pa.kisa||pa.ad)+'</b><div class="kucuk">Sözcü: '+e(pa.sozcu||"Atanmadı")+' · Genel başkan: '+e(pa.gb||"—")+'</div></div>'
      +(pa.gb_miyim?'<button class="btn ikinci" style="width:auto" onclick="adlSozcuModal('+pa.id+')">Ata / Al</button>':'')+'</div>').join("")
  +(!d.partiler.length?'<p class="alt">Kayıtlı parti bulunmuyor.</p>':'')+'</div>'
  +'<div class="bolum-bas"><h2>Açık davalar ('+acik.length+')</h2></div>'
  +(acik.length?acik.map(adlDavaKart).join(""):'<div class="kart"><p class="alt">Şu anda açık dava yok.</p></div>')
  +'<div class="bolum-bas"><h2>Karara bağlanan davalar</h2></div>'
  +(bitmis.length?bitmis.map(adlDavaKart).join(""):'<div class="kart"><p class="alt">Henüz karar verilmiş dava yok.</p></div>')
  +(d.aflar.length?'<div class="bolum-bas"><h2>Af kararları</h2></div><div class="kart">'+d.aflar.slice(0,8).map(a=>'<div class="liste-satir"><div class="orta"><b>'+e(a.tur==="genel"?"Genel af":"Bireysel af #"+a.dava_id)+'</b><div class="kucuk">'+e(a.cb)+' · '+e(a.gerekce)+' · '+adlTarih(a.zaman)+' · '+a.affedilen+' karar</div></div></div>').join("")+'</div>':'')
  +(d.atamalar.length?'<div class="bolum-bas"><h2>Yargıç atama ve görevden almalar</h2></div><div class="kart">'+d.atamalar.slice(0,8).map(a=>'<p class="alt">'+e(a.yapan)+' · '+e(a.yeni||"Görevden alma")+' · '+e(a.gerekce||"")+' · '+adlTarih(a.zaman)+'</p>').join("")+'</div>':'');
}
function adlDavaKart(d){
 const ad=d.davali||d.davali_parti||"—";
 return '<div class="kart" style="cursor:pointer" onclick="ekranAc(()=>adliyeDosya('+d.id+'))">'
   +'<div class="baslik"><b>Dosya #'+d.id+' · '+e(ADL_TURLER[d.tur]||d.tur)+'</b><span class="rozet">'+e(adlEtiket(d))+'</span></div>'
   +'<p class="alt">'+e(d.davaci_parti||d.davaci)+' → '+e(ad)+'</p>'
   +'<p style="margin-top:6px">'+e(d.iddia.length>170?d.iddia.slice(0,170)+"…":d.iddia)+'</p>'
   +(d.karar?'<p class="kucuk">Karar: '+e(ADL_CEZALAR[d.karar])+'</p>':'<p class="kucuk">Savunma süresi: '+adlTarih(d.savunma_son)+'</p>')
   +'<button class="btn ikinci">Duruşmayı izle</button></div>';
}
function adlHakimModal(){
 if(!ADL.cb_miyim)return toast("Bu yetki yalnız Cumhurbaşkanında.",true);
 const m=modal(adlAlan("Atanacak oyuncunun kullanıcı adı","adlHakim")+"<button class='btn altin' id='adlAta'>Yargıç ata</button>"
  +(ADL.hakim?adlAlan("Görevden alma gerekçesi","adlAlNeden","textarea")+"<button class='btn tehlike' id='adlAl'>Yargıcı görevden al</button>":""));
 adlFormBaslik(m,"Yüksek Yargıç");
 m.querySelector("#adlAta").onclick=()=>adlIslem(()=>API.rpc("adliye_hakim_ata",{p_kad:m.querySelector("#adlHakim").value}),"Yüksek Yargıç atandı.");
 if(m.querySelector("#adlAl"))m.querySelector("#adlAl").onclick=async()=>{
  const g=m.querySelector("#adlAlNeden").value;
  if(!await onayla("Yargıcı görevden al","Görevden alma gerekçesi kamuya açık kayıtlara eklenecek.","Görevden al",true))return;
  adlIslem(()=>API.rpc("adliye_hakim_al",{p_gerekce:g}),"Yüksek Yargıç görevden alındı.");
 };
}
function adlSozcuModal(parti){
 const pa=ADL.partiler.find(x=>x.id===parti);if(!pa||!pa.gb_miyim)return;
 const m=modal('<p class="alt">Sadece partinizin üyesini seçebilirsiniz. Boş bırakarak sözcüyü görevden alabilirsiniz.</p>'
  +adlAlan("Parti sözcüsü kullanıcı adı","adlSozcu","text","Görevden almak için boş bırakın")
  +'<button class="btn altin" id="adlSozcuOnay">Kararı uygula</button>');
 adlFormBaslik(m,pa.ad+" · Parti Sözcüsü");
 m.querySelector("#adlSozcuOnay").onclick=()=>adlIslem(
 ()=>API.rpc("adliye_sozcu_ata",{p_parti:parti,p_kad:m.querySelector("#adlSozcu").value||null}),
 "Parti sözcülüğü güncellendi.");
}
function adlDavaModal(){
 const secenek=Object.entries(ADL_TURLER).map(([k,v])=>'<option value="'+k+'">'+v+'</option>').join("");
 const partiler=ADL.partiler;
 const ben=partiler.filter(x=>x.gb_miyim||x.sozcu_muyum);
 const m=modal('<div class="alan"><label>Davalı türü</label><select id="adlHedefTur"><option value="oyuncu">Oyuncu</option><option value="parti">Siyasi parti</option></select></div>'
  +'<div class="alan" id="adlOyuncuKutu"><label>Davalı kullanıcı adı</label><input id="adlHedef" placeholder="Oyuncunun kullanıcı adı"></div>'
  +'<div class="alan" id="adlPartiKutu" style="display:none"><label>Davalı parti</label><select id="adlHedefParti">'+partiler.map(p=>'<option value="'+p.id+'">'+e(p.ad)+'</option>').join("")+'</select></div>'
  +'<div class="alan"><label>Dava türü</label><select id="adlTur">'+secenek+'</select></div>'
  +'<div class="alan"><label>Davacı olarak</label><select id="adlDavaciParti"><option value="">Kendi adıma</option>'+ben.map(p=>'<option value="'+p.id+'">'+e(p.ad)+' adına</option>').join("")+'</select></div>'
  +adlAlan("İddia (20–1600 karakter)","adlIddia","textarea")
  +adlAlan("Deliller ve olayın detayları","adlDelil","textarea","Örn. sohbet mesajının tarihi ve kanalı")
  +'<button class="btn altin" id="adlDavaAc">Davayı aç</button>');
 adlFormBaslik(m,"Adliyede yeni dava");
 m.querySelector("#adlHedefTur").onchange=()=>{
  const parti=m.querySelector("#adlHedefTur").value==="parti";
  m.querySelector("#adlOyuncuKutu").style.display=parti?"none":"block";
  m.querySelector("#adlPartiKutu").style.display=parti?"block":"none";
 };
 m.querySelector("#adlDavaAc").onclick=async()=>{
  const tur=m.querySelector("#adlHedefTur").value;
  try{
   const v=await API.rpc("adliye_dava_ac",{p_hedef_tur:tur,p_hedef:tur==="parti"?m.querySelector("#adlHedefParti").value:m.querySelector("#adlHedef").value,
    p_tur:m.querySelector("#adlTur").value,p_iddia:m.querySelector("#adlIddia").value,
    p_delil:m.querySelector("#adlDelil").value,p_davaci_parti:m.querySelector("#adlDavaciParti").value||null});
   modalKapat();toast("Dava #"+v.id+" açıldı.");D.devletSekme="adliye";await devletEkrani();
  }catch(err){toast(hataCevir(err.message),true);}
 };
}
async function adliyeDosya(id){
 yukleniyor("Dava #"+id);
 try{
  ADL=await API.rpc("adliye_durum");
  const d=ADL.davalar.find(x=>x.id===id);
  if(!d){iskelet("Adliye",'<div class="bos">Dava bulunamadı veya listede yer almıyor.</div>',{geri:true});return;}
  const r=await API.rpc("adliye_detay",{p_dava:id});
  const yetki=d.davalimiyim&&ADL.partiler.some(x=>x.id===ADL.parti_id&&x.sozcu);
  const sozHak=d.davalimiyim||d.sozcu_savunabilir||d.davacimiyim||ADL.partiler.some(x=>x.sozcu_muyum&&x.ad===d.davaci_parti);
  const tar=d.davali||d.davali_parti||"—";
  const head='<div class="kart"><div class="baslik"><b>#'+d.id+' · '+e(ADL_TURLER[d.tur]||d.tur)+'</b><span class="rozet">'+e(adlEtiket(d))+'</span></div>'
   +'<div class="kv"><span class="k">Davacı</span><span class="v">'+e(d.davaci_parti||d.davaci)+'</span></div>'
   +'<div class="kv"><span class="k">Davalı</span><span class="v">'+e(tar)+'</span></div>'
   +'<p class="alt">Açılış: '+adlTarih(d.acilis)+' · Savunma için son: '+adlTarih(d.savunma_son)+'</p>'
   +'<h3>İddia</h3><p style="white-space:pre-wrap">'+e(d.iddia)+'</p>'
   +(d.delil?'<h3>Sunulan deliller</h3><p style="white-space:pre-wrap">'+e(d.delil)+'</p>':'')
   +'</div>';
  const beyan='<div class="kart"><h3>Açık duruşma – taraf beyanları</h3>'
   +(r.beyanlar.length?r.beyanlar.map(b=>'<div class="liste-satir"><div class="orta"><b>'+e(b.yazar)+' · '+e(b.rol==="sozcu"?"Parti sözcüsü":b.rol==="davali"?"Savunma":"Davacı")+'</b><div class="kucuk">'+adlTarih(b.zaman)+'</div><p style="white-space:pre-wrap;margin-top:6px">'+e(b.metin)+'</p></div></div>').join(""):'<p class="alt">Henüz beyan verilmedi.</p>')
   +(d.durum==="acik"&&sozHak?'<button class="btn altin" onclick="adlBeyanModal('+id+')">Savunma / beyan ver</button>':'')
   +(d.durum==="acik"&&yetki?'<button class="btn ikinci" onclick="adlTemsil('+id+','+(!d.temsil_iznim)+')">'+(d.temsil_iznim?"Parti sözcüsü temsil iznini kaldır":"Parti sözcünü savunmaya yetkilendir")+'</button>':'')
   +'</div>';
  const karar=d.durum==="karar"?'<div class="kart"><h3>Gerekçeli karar</h3><b>'+e(ADL_CEZALAR[d.karar]||"—")+'</b>'
   +'<p style="white-space:pre-wrap;margin-top:8px">'+e(d.gerekce||"")+'</p><p class="alt">Yargıç: '+e(d.hakim||"—")+' · '+adlTarih(d.karar_at)+'</p>'
   +(d.af_at?'<span class="rozet yesil">Cumhurbaşkanlığı affı · '+adlTarih(d.af_at)+'</span><p class="alt">'+e(d.af_gerekce||"")+'</p>':'')
   +'</div>':'';
  const hakim=ADL.hakim_miyim&&d.durum==="acik"&&!d.davalimiyim&&!d.davacimiyim;
  const gerek=ADL.cb_miyim&&d.durum==="karar"&&!d.af_at&&d.karar!=="beraat";
  const eylem=(hakim?'<div class="kart"><button class="btn altin" onclick="adlKararModal('+id+')">Yargıç: karar ver</button></div>':'')
   +(gerek?'<div class="kart"><button class="btn ikinci" onclick="adlAfModal('+id+')">Cumhurbaşkanı: cezayı affet</button></div>':'');
  const yorum='<div class="kart"><h3>Herkese açık karar ve duruşma tartışması</h3>'
   +(r.yorumlar.length?r.yorumlar.map(y=>'<div class="liste-satir"><div class="orta"><b>'+e(y.yazar)+'</b><div class="kucuk">'+adlTarih(y.zaman)+'</div><p style="white-space:pre-wrap;margin-top:4px">'+e(y.metin)+'</p></div></div>').join(""):'<p class="alt">Henüz yorum yapılmadı.</p>')
   +'<button class="btn ikinci" onclick="adlYorumModal('+id+')">Duruşmaya yorum yaz</button></div>';
  iskelet("Dava #"+id,head+beyan+karar+eylem+yorum,{geri:true});
 }catch(err){iskelet("Dava #"+id,'<div class="bos">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function adlBeyanModal(id){
 const m=modal(adlAlan("Duruşma beyanınız / savunmanız","adlMetin","textarea")+"<button class='btn altin' id='adlOnay'>Beyanı yayımla</button>");
 adlFormBaslik(m,"Dava #"+id+" · Herkese açık beyan");
 m.querySelector("#adlOnay").onclick=()=>adlIslem(()=>API.rpc("adliye_beyan_ver",{p_dava:id,p_metin:m.querySelector("#adlMetin").value}),"Beyanınız yayımlandı.",id);
}
function adlTemsil(id,izin){
 adlIslem(()=>API.rpc("adliye_temsil_yetkisi",{p_dava:id,p_izin:izin}),izin?"Parti sözcünüze temsil yetkisi verildi.":"Temsil yetkisi kaldırıldı.",id,false);
}
function adlYorumModal(id){
 const m=modal(adlAlan("Yorumunuz","adlYorum","textarea")+"<button class='btn altin' id='adlOnay'>Yorumu yayımla</button>");
 adlFormBaslik(m,"Duruşma tartışması");
 m.querySelector("#adlOnay").onclick=()=>adlIslem(()=>API.rpc("adliye_yorum_yaz",{p_dava:id,p_metin:m.querySelector("#adlYorum").value}),"Yorumunuz yayımlandı.",id);
}
function adlKararModal(id){
 const opts=Object.entries(ADL_CEZALAR).map(([k,v])=>'<option value="'+k+'">'+e(v)+'</option>').join("");
 const m=modal('<div class="alan"><label>Mahkeme kararı</label><select id="adlCeza">'+opts+'</select></div>'
  +adlAlan("Gerekçeli karar","adlGerekce","textarea")
  +'<p class="alt">Kararlar ve gerekçeler herkese açık olacaktır. Görevden alınsanız da eski kararlarınız kayıtta kalır.</p>'
  +'<button class="btn altin" id="adlKarar">Kararı açıkla ve uygula</button>');
 adlFormBaslik(m,"Yüksek Yargıç · Dava #"+id);
 m.querySelector("#adlKarar").onclick=async()=>{
  if(!await onayla("Kararı kesinleştir","Seçtiğiniz ceza oyuncunun makamını veya sohbet yetkisini hemen etkileyebilir.","Kararı ver",true))return;
  adlIslem(()=>API.rpc("adliye_karar_ver",{p_dava:id,p_karar:m.querySelector("#adlCeza").value,p_gerekce:m.querySelector("#adlGerekce").value}),"Mahkeme kararı yayımlandı.",id);
 };
}
function adlAfModal(id){
 if(!ADL.cb_miyim)return;
 const m=modal('<p class="alt">'+(id===null?"Genel af, affedilmemiş bütün oyun içi mahkeme cezalarına uygulanır.":"Bireysel af yalnız bu dosyadaki cezaya uygulanır.")+'</p>'
  +adlAlan("Kamuya açık af gerekçesi","adlAfGerekce","textarea")
  +'<button class="btn altin" id="adlAf">Af kararı yayımla</button>');
 adlFormBaslik(m,id===null?"Cumhurbaşkanlığı genel affı":"Cumhurbaşkanlığı affı · #"+id);
 m.querySelector("#adlAf").onclick=async()=>{
  const gerekce=m.querySelector("#adlAfGerekce").value;
  if(!await onayla("Af kararı","Affın kapsamı ve gerekçesi kamuya açık kayıtlara geçer.","Affı yayımla",true))return;
  adlIslem(()=>API.rpc("adliye_af_cikar",{p_dava:id,p_gerekce:gerekce}),"Cumhurbaşkanlığı af kararı yayımlandı.",id);
 };
}

/* Parti detayındaki görünür makam yönetimi */
function partiSozcuModal(parti){
 const m=modal('<p class="alt">Partinizden bir oyuncuyu Parti Sözcüsü atayın. Boş bırakmanız mevcut sözcüyü görevden alır.</p>'
  +adlAlan("Parti Sözcüsü kullanıcı adı","yeniPartiSozcu","text","Görevden almak için boş bırakın")
  +'<button class="btn altin" id="partiSozcuOnay">Atamayı uygula</button>');
 adlFormBaslik(m,"Parti Sözcülüğü");
 m.querySelector("#partiSozcuOnay").onclick=async()=>{
  try {
   await API.rpc("adliye_sozcu_ata",{p_parti:parti,p_kad:m.querySelector("#yeniPartiSozcu").value||null});
   modalKapat();toast("Parti sözcülüğü güncellendi.");await partiDetay(parti);
  } catch(err){toast(hataCevir(err.message),true);}
 };
}
