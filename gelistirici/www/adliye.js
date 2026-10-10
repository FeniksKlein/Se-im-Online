/* ADLİYE: Yüksek Yargıç, parti sözcüsü, açık yargılama ve Cumhurbaşkanlığı affı */
async function adliyeEkrani(){
  yukleniyor("Adliye");
  try{iskelet("Adliye",await adliyeHtml());}
  catch(err){iskelet("Adliye",'<div class="bos">'+e(hataCevir(err.message))+'</div>');}
}
const ADL_TURLER={hakaret:"Hakaret",iftira:"İftira",rusvet:"Rüşvet",yolsuzluk:"Yolsuzluk",usulsuzluk:"Usulsüz işlem",dolandiricilik:"Dolandırıcılık",diger:"Diğer"};
const ADL_CEZALAR={beraat:"Beraat",uyari:"Uyarı",sustur_1s:"1 saat sohbetten susturma",sustur_1g:"1 gün sohbetten susturma",sustur_1h:"1 hafta sohbetten susturma",vekillik_dusur:"Milletvekilliğinin düşürülmesi"};

const ADL_SUCLAR={
 hakaret:"Doğrudan kişiyi aşağılayan veya küçük düşüren sözler. Siyasi eleştiri ve görüş ayrılığı tek başına suç değildir.",
 iftira:"Bir oyuncuya veya partiye bilerek gerçek dışı ağır bir eylem isnat etmek. İddiayı doğrulayan kanıt aranır.",
 rusvet:"Makam, oy, ihale veya kamu yetkisi karşılığında oyun içi maddi menfaat teklif etmek, almak veya vermek.",
 yolsuzluk:"Kamu ya da kurum kaynaklarını yetkisiz kişisel çıkar için kullanmak, zimmete geçirmek veya kayırmacılık yapmak.",
 usulsuzluk:"Makamın görev sınırlarını, seçim ve ihale kurallarını veya oyun içi resmî işlem kurallarını ihlal etmek.",
 dolandiricilik:"Yanlış beyanla başka oyuncunun oyun parasını, mülkünü, hissesini veya hakkını hileyle elde etmek.",
 diger:"Oyun kurallarıyla çelişen başka somut eylemler. Hangi kuralın ihlal edildiği dilekçede açıklanmalıdır."
};
function adlSozcuGorevleri(){
 return '<p class="alt"><b>Parti sözcüsü ne yapar?</b> Yalnız genel başkan tarafından kendi parti üyeleri arasından atanır veya görevden alınır. Parti adına açılan veya partiye karşı açılan davalarda partiyi temsil edip savunma ve beyan sunar. Bir parti üyesinin kişisel davasında ise ancak o üyenin dosyaya özel izniyle savunma yapabilir. Sözcü yargıç değildir, ceza veremez ve hiçbir üyeyi izinsiz temsil edemez.</p>';
}
function adlBilgiHtml(){
 const suclar=Object.entries(ADL_SUCLAR).map(([kod,metin])=>'<div class="liste-satir"><div class="orta"><b>'+e(ADL_TURLER[kod])+'</b><div class="kucuk">'+e(metin)+'</div></div></div>').join('');
 return '<div class="kart"><h3>Adliye ne işe yarar?</h3>'
  +'<p class="alt">Adliye, Seçim Simülasyonu Online oyuncuları arasındaki <b>oyun içi</b> anlaşmazlıkların delilli dava ve açık duruşmayla incelendiği bir sistemdir. Gerçek hayattaki mahkeme veya ceza hukuku yerine geçmez.</p>'
  +'<div class="kv"><span class="k">Dava açma</span><span class="v">Oyuncu veya yetkili parti temsilcisi iddiayı ve delilleri bildirir.</span></div>'
  +'<div class="kv"><span class="k">Savunma</span><span class="v">Davalı yanıt verebilir; parti sözcüsü yalnız yetkisi varsa temsil edebilir.</span></div>'
  +'<div class="kv"><span class="k">Yargılama</span><span class="v">Yüksek Yargıç delilleri inceler, gerekçeli kararını açıklar. Davalar herkesçe izlenebilir.</span></div>'
  +'<div class="kv"><span class="k">Af</span><span class="v">Cumhurbaşkanı bireysel veya genel af ilan edebilir. Gerekçeler kamuya açıktır.</span></div>'
  +'<p class="alt"><b>Unutmayın:</b> Fikir ayrılığı, muhalefet etmek ve kanıtlanmamış suçlamalar otomatik olarak suç değildir.</p>'
  +'<details style="margin-top:12px"><summary style="cursor:pointer;font-weight:700">Hangi davranışlar suç sayılır? (Aç)</summary>'
  +'<p class="alt">Aşağıdaki tanımlar yalnız oyun içindeki davranışlara uygulanır. Mesaj, işlem kaydı, belge ve savunmalar değerlendirilmelidir.</p>'+suclar+'</details>'
  +'<details style="margin-top:12px"><summary style="cursor:pointer;font-weight:700">Olası cezalar ve yapay zekâ önerisi (Aç)</summary>'
  +'<p class="alt">Olası kararlar: beraat, uyarı, 1 saat / 1 gün / 1 hafta sohbetten susturma veya aktif milletvekilliğinin düşürülmesi. Bir siyasi partiye yalnız beraat veya uyarı verilebilir. Suçla ceza arasında otomatik ve değişmez bir eşleşme yoktur.</p>'
  +'<p class="alt">Yüksek Yargıç, delil ve savunmalardan hareketle gerekçeli <b>AI ceza önerisi</b> isteyebilir. AI hizmeti yapılandırılmadıysa sistem açıkça kurallı ön değerlendirme gösterir. Hiçbiri kesin hüküm vermez; cezayı yalnız yargıç uygular.</p></details></div>';
}

let ADL={};
function adlTarih(t){return t?tarihSaat(t):"—";}
function adlEtiket(d){return d.durum==="karar"?(d.af_at?"Af çıkarıldı":"Karar verildi"):"Savunma aşaması";}
function adlFormBaslik(m,baslik){m.querySelector(".modal").insertAdjacentHTML("afterbegin",'<h3 style="font-size:20px;margin:0 0 12px">'+e(baslik)+'</h3>');}
function adlAlan(ad,id,tur="text",placeholder=""){return '<div class="alan"><label>'+e(ad)+'</label>'+ (tur==="textarea"?'<textarea id="'+id+'" rows="4" placeholder="'+e(placeholder)+'"></textarea>':'<input id="'+id+'" type="'+tur+'" placeholder="'+e(placeholder)+'">')+'</div>';}
async function adlIslem(fn,success,geri,modalKapatilsin=true){
 try{await fn();if(modalKapatilsin)modalKapat();toast(success);if(geri)await adliyeDosya(geri);else{if(D.sekme==="adliye")await adliyeEkrani();else{D.devletSekme="adliye";await devletEkrani();}}}
 catch(err){toast(hataCevir(err.message),true);}
}

function adlSiyasiHtml(){
 const a=ADL.siyasi||{oneriler:[],secimler:[],itirazlar:[]};
 const secimler=a.secimler||[],oneriler=a.oneriler||[],itirazlar=a.itirazlar||[];
 const adayHak=ADL.partiler.filter(p=>p.gb_miyim);
 const itirazHak=ADL.partiler.filter(p=>p.gb_miyim||p.sozcu_muyum);
 return '<div class="kart"><h3>Yüksek Yargıç aday önerileri</h3>'
  +'<p class="alt">Yargıç istifa ettiğinde, görevden alındığında veya yeni yargıç atandığında öneri dönemi yenilenir. Partilerin genel başkanları bir sonraki yargıç için istedikleri oyuncuyu kamuya açık olarak önerebilir. Öneriler bağlayıcı değildir. <b>Son atama ve görevden alma yetkisi Cumhurbaşkanındadır.</b></p>'
  +'<div class="kv"><span class="k">Aday önerisi dönemi</span><span class="v">'+e(a.oneri_donemi||1)+'</span></div>'
  +oneriler.map(o=>'<div class="liste-satir"><div class="orta"><b>'+e(o.parti)+'</b><div class="kucuk">Yargıç adayımız: '+e(o.aday)+'</div>'+(o.aciklama?'<p class="alt">'+e(o.aciklama)+'</p>':'')+'</div></div>').join('')
  +(!oneriler.length?'<p class="alt">Bu dönem için henüz parti önerisi yok.</p>':'')
  +adayHak.map(p=>'<button class="btn ikinci" onclick="adlYargicOnerModal('+p.id+')">'+e(p.kisa||p.ad)+' adına aday öner / değiştir</button>').join('')
  +'</div>'
  +'<div class="kart"><h3>Seçim sonuçlarına itiraz</h3>'
  +'<p class="alt">Seçim sonuçları açıklandıktan sonra <b>48 saat içinde</b> siyasi partinin genel başkanı veya parti sözcüsü, gerekçe ve delil göstererek başvurabilir. Her parti aynı seçime bir defa itiraz edebilir. İtirazlar herkese açık; değerlendirme ve nihai gerekçeli karar Yüksek Yargıca aittir.</p>'
  +'<p class="alt">İtirazın kabulü, seçim oylarını veya seçilmiş makamları otomatik değiştirmez. Yeniden sayım ya da seçim sonucunu düzeltme ayrı işlem gerektirir.</p>'
  +secimler.map(se=>'<div class="liste-satir"><div class="orta"><b>Seçim #'+se.id+' · '+e(se.tur)+' · '+e(se.donem)+'</b><div class="kucuk">İtiraz sonu: '+adlTarih(se.itiraz_son)+'</div></div>'
   +(itirazHak.length?'<button class="btn ikinci" style="width:auto" onclick="adlSecimItirazModal('+se.id+')">İtiraz et</button>':'')+'</div>').join('')
  +(!secimler.length?'<p class="alt">Şu anda 48 saatlik itiraz süresi açık olan bir seçim yok.</p>':'')
  +'<h3>İtiraz dosyaları</h3>'
  +itirazlar.map(i=>'<div class="liste-satir"><div class="orta"><b>İtiraz #'+i.id+' · '+e(i.parti)+'</b><div class="kucuk">Seçim #'+i.secim_id+' · '+e(i.secim_tur)+' · '+e(i.secim_donem)+' · '+e(i.durum==='bekliyor'?'İnceleniyor':i.durum==='kabul'?'İtiraz kabul edildi':'İtiraz reddedildi')+'</div><p class="alt">'+e(i.gerekce)+'</p>'
    +(i.deliller?'<p class="kucuk">Deliller: '+e(i.deliller)+'</p>':'')
    +(i.karar_gerekce?'<p class="kucuk">Yargıç kararı: '+e(i.karar_gerekce)+'</p>':'')
    +'</div>'+(ADL.hakim_miyim&&i.durum==='bekliyor'?'<button class="btn ikinci" style="width:auto" onclick="adlSecimItirazKararModal('+i.id+')">Karar ver</button>':'')+'</div>').join('')
  +(!itirazlar.length?'<p class="alt">Henüz sonuç itirazı yapılmadı.</p>':'')
  +'</div>';
}
function adlYargicOnerModal(parti){
 const p=ADL.partiler.find(x=>x.id===parti);
 const m=modal('<p class="alt">Partinizin yeni Yüksek Yargıç adayı kim olsun? Önerinizi bütün oyuncular görebilir. Cumhurbaşkanı bu öneriyle bağlı değildir. Aynı dönem içindeki önerinizi değiştirebilirsiniz.</p>'
 +adlAlan('Yargıç adayı kullanıcı adı','adlOnerAday','text','Aday oyuncunun kullanıcı adı')
 +adlAlan('Kamuya açık gerekçe (isteğe bağlı)','adlOnerGerekce','textarea')
 +'<button class="btn altin" id="adlOnerGonder">Aday önerisini yayımla</button>');
 adlFormBaslik(m,'Partinin Yüksek Yargıç adayı'+(p?' · '+p.ad:''));
 m.querySelector('#adlOnerGonder').onclick=async()=>{
  const kad=m.querySelector('#adlOnerAday').value,acik=m.querySelector('#adlOnerGerekce').value;
  try{
   await API.rpc('adliye_yargic_oner',{p_parti:parti,p_kad:kad,p_aciklama:acik});
   modalKapat();toast('Partinizin yargıç adayı kamuya duyuruldu.');
   if(D.sekme==='adliye')await adliyeEkrani();else await partiDetay(parti);
  }catch(err){toast(hataCevir(err.message),true);}
 };
}
function adlSecimItirazModal(secim){
 const a=ADL.siyasi||{secimler:[]};
 const se=(a.secimler||[]).find(x=>x.id===secim);
 const partiler=ADL.partiler.filter(p=>p.gb_miyim||p.sozcu_muyum);
 if(!se||!partiler.length)return toast('Partiniz adına sonuç itirazı yapma yetkiniz yok.',true);
 const m=modal('<p class="alt">Yalnız sonuç açıklanmış seçimlere, açıklamadan itibaren 48 saat içinde başvuru yapılır. Somut iddia ve delil ekleyin.</p>'
 +'<div class="alan"><label>İtiraz eden parti</label><select id="adlItParti">'+partiler.map(p=>'<option value="'+p.id+'">'+e(p.ad)+'</option>').join('')+'</select></div>'
 +adlAlan('İtiraz gerekçesi (30–1600 karakter)','adlItGerekce','textarea')
 +adlAlan('Deliller, olay tarihleri ve kayıtlar','adlItDelil','textarea')
 +'<button class="btn altin" id="adlItGonder">Seçim sonucuna itiraz et</button>');
 adlFormBaslik(m,'Seçim #'+se.id+' · '+se.tur+' · '+se.donem);
 m.querySelector('#adlItGonder').onclick=async()=>{
  try{
   const v=await API.rpc('adliye_secim_itiraz_ac',{p_secim:secim,p_parti:Number(m.querySelector('#adlItParti').value),p_gerekce:m.querySelector('#adlItGerekce').value,p_deliller:m.querySelector('#adlItDelil').value});
   modalKapat();toast('Seçim itirazı #'+v.id+' kaydedildi.');await adliyeEkrani();
  }catch(err){toast(hataCevir(err.message),true);}
 };
}
function adlSecimItirazKararModal(id){
 if(!ADL.hakim_miyim)return;
 const a=ADL.siyasi||{itirazlar:[]};
 const it=(a.itirazlar||[]).find(i=>i.id===id&&i.durum==='bekliyor');
 if(!it)return;
 const m=modal('<p class="alt">'+e(it.parti)+' · Seçim #'+it.secim_id+'</p>'
 +'<p class="alt">Gerekçe: '+e(it.gerekce)+'</p><p class="alt">Delil: '+e(it.deliller||'Sunulmadı')+'</p>'
 +'<div class="alan"><label>İtiraz kararı</label><select id="adlItKarar"><option value="ret">İtirazı reddet</option><option value="kabul">İtirazı kabul et (otomatik yeniden sayım yapmaz)</option></select></div>'
 +adlAlan('Kamuya açık gerekçeli karar','adlItNeden','textarea')
 +'<button class="btn altin" id="adlItKararGonder">Kararı açıklayıp kaydet</button>');
 adlFormBaslik(m,'Yüksek Yargıç · Seçim itirazı #'+id);
 m.querySelector('#adlItKararGonder').onclick=async()=>{
  const karar=m.querySelector('#adlItKarar').value,gerekce=m.querySelector('#adlItNeden').value;
  try{await API.rpc('adliye_secim_itiraz_karar',{p_itiraz:id,p_karar:karar,p_gerekce:gerekce});
   modalKapat();toast('İtiraz kararı yayımlandı. Seçim sonucu otomatik değiştirilmedi.');await adliyeEkrani();
  }catch(err){toast(hataCevir(err.message),true);}
 };
}
async function adlYargicIstifa(){
 if(!ADL.hakim_miyim)return;
 if(!await onayla('Yüksek Yargıçlıktan istifa','İstifanız hemen geçerli olacak; yeni yargıcı Cumhurbaşkanı atayacak.','İstifa et',true))return;
 try{await API.rpc('adliye_hakim_istifa');toast('Yüksek Yargıç görevinden istifa ettiniz.');await adliyeEkrani();}
 catch(err){toast(hataCevir(err.message),true);}
}

async function adliyeHtml(){
 const [d,siyasi]=await Promise.all([API.rpc("adliye_durum"),API.rpc("adliye_siyasi_bilgi")]);ADL={...d,siyasi};
 const yer=d.partiler.find(p=>p.id===d.parti_id);
 const acik=d.davalar.filter(x=>x.durum==="acik");
 const bitmis=d.davalar.filter(x=>x.durum!=="acik");
 return adlBilgiHtml()+'<div class="kart"><h3>Yüksek Yargı</h3>'
  +'<p class="alt">Herkese açık davalar · Tek Yüksek Yargıç · Sözlü savunma · Gerekçeli karar · Cumhurbaşkanlığı affı</p>'
  +'<div class="kv"><span class="k">Yüksek Yargıç</span><span class="v">'+e(d.hakim||"Henüz atanmadı")+'</span></div>'
  +(d.hakim_miyim?'<div class="rozet altin" style="margin-top:10px">Yüksek Yargıç yetkiniz aktif</div><button class="btn tehlike" onclick="adlYargicIstifa()">Yüksek Yargıç görevinden istifa et</button>':'')
  +(d.cb_miyim?'<button class="btn altin" onclick="adlHakimModal()">Yargıç ata veya görevden al</button><button class="btn ikinci" onclick="adlAfModal(null)">Genel af ilan et</button>':'')
  +'<button class="btn" onclick="adlDavaModal()">Dava aç</button></div>'
  +adlSiyasiHtml()
  +'<div class="kart"><h3>Parti Sözcüleri</h3>'+adlSozcuGorevleri()
  +d.partiler.map(pa=>'<div class="liste-satir"><div class="orta"><b>'+e(pa.kisa||pa.ad)+'</b><div class="kucuk">Sözcü: '+e(pa.sozcu||"Atanmadı")+' · Genel başkan: '+e(pa.gb||"—")+'</div></div>'
      +'<button class="btn ikinci" style="width:auto" onclick="ekranAc(()=>partiDetay('+pa.id+'))">Parti sayfası</button>'+'</div>').join("")
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
 const m=modal('<p class="alt">Partilerin kamuya açık yargıç adayları öneri niteliğindedir. Son atama ve görevden alma yetkisi Cumhurbaşkanındadır.</p>'+adlAlan("Atanacak oyuncunun kullanıcı adı","adlHakim")+"<button class='btn altin' id='adlAta'>Yargıç ata</button>"
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
 const m=modal(adlSozcuGorevleri()+'<p class="alt">Sadece partinizin üyesini seçebilirsiniz. Boş bırakarak sözcüyü görevden alabilirsiniz.</p>'
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
  +'<p class="alt" id="adlSucAciklamasi">'+e(ADL_SUCLAR.hakaret)+'</p>'
  +'<div class="alan"><label>Davacı olarak</label><select id="adlDavaciParti"><option value="">Kendi adıma</option>'+ben.map(p=>'<option value="'+p.id+'">'+e(p.ad)+' adına</option>').join("")+'</select></div>'
  +adlAlan("İddia (20–1600 karakter)","adlIddia","textarea")
  +adlAlan("Deliller ve olayın detayları","adlDelil","textarea","Örn. sohbet mesajının tarihi ve kanalı")
  +'<button class="btn altin" id="adlDavaAc">Davayı aç</button>');
 adlFormBaslik(m,"Adliyede yeni dava");
 m.querySelector("#adlTur").onchange=()=>{m.querySelector("#adlSucAciklamasi").textContent=ADL_SUCLAR[m.querySelector("#adlTur").value]||"";};
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
   modalKapat();toast("Dava #"+v.id+" açıldı.");if(D.sekme==="adliye")await adliyeEkrani();else{D.devletSekme="adliye";await devletEkrani();}
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

async function adlAiOnerModal(id,m){
 const alan=m.querySelector("#adlAiSonuc"),buton=m.querySelector("#adlAiOner");
 if(!alan||!buton)return;
 buton.disabled=true;alan.textContent="Dosya ve savunmalar inceleniyor…";
 try{
  if(typeof API.aiCezaOner!=="function")throw Error("Bu sürümde AI öneri bağlantısı bulunmuyor.");
  const d=await API.aiCezaOner(id);
  if(!d||!Object.prototype.hasOwnProperty.call(ADL_CEZALAR,d.ceza))throw Error("Geçerli ceza önerisi alınamadı.");
  alan.innerHTML='<div class="kart" style="padding:12px"><p class="kucuk"><b>'+e(d.kaynak==="yapay_zeka"?"YAPAY ZEKÂ ÖNERİSİ":"KURALLI ÖN DEĞERLENDİRME")+'</b></p>'
   +'<p style="margin-top:8px"><b>Önerilen: '+e(ADL_CEZALAR[d.ceza])+'</b></p>'
   +'<p class="alt" style="white-space:pre-wrap;margin-top:8px">'+e(d.gerekce||"")+'</p>'
   +(d.alternatif?'<p class="kucuk"><b>Alternatif değerlendirme:</b> '+e(d.alternatif)+'</p>':"")
   +'<p class="kucuk">'+e(d.uyari||"Bu öneri bağlayıcı değildir.")+'</p>'
   +'<button type="button" class="btn ikinci" id="adlOneriyiSec">Öneriyi forma aktar (karar verilmez)</button></div>';
  alan.querySelector("#adlOneriyiSec").onclick=()=>{
   m.querySelector("#adlCeza").value=d.ceza;
   m.querySelector("#adlGerekce").value=String(d.gerekce||"").slice(0,1900);
   toast("Öneri forma aktarıldı. Nihai kararı yalnız siz verebilirsiniz.");
  };
 }catch(err){alan.textContent="Öneri alınamadı: "+hataCevir(err.message);}
 finally{buton.disabled=false;}
}

function adlKararModal(id){
 const opts=Object.entries(ADL_CEZALAR).map(([k,v])=>'<option value="'+k+'">'+e(v)+'</option>').join("");
 const m=modal('<div class="alan"><label>Mahkeme kararı</label><select id="adlCeza">'+opts+'</select></div>'
  +'<button type="button" class="btn ikinci" id="adlAiOner">Yapay zekâdan ceza önerisi al</button>'
  +'<div id="adlAiSonuc" role="status" class="alt" style="padding:8px 0">Bu öneri mahkeme kararı değildir.</div>'
  +adlAlan("Gerekçeli karar","adlGerekce","textarea")
  +'<p class="alt">Kararlar ve gerekçeler herkese açık olacaktır. Görevden alınsanız da eski kararlarınız kayıtta kalır.</p>'
  +'<button class="btn altin" id="adlKarar">Kararı açıkla ve uygula</button>');
 adlFormBaslik(m,"Yüksek Yargıç · Dava #"+id);
 m.querySelector("#adlAiOner").onclick=()=>adlAiOnerModal(id,m);
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
 const m=modal(adlSozcuGorevleri()+'<p class="alt">Partinizden bir oyuncuyu Parti Sözcüsü atayın. Boş bırakmanız mevcut sözcüyü görevden alır.</p>'
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
