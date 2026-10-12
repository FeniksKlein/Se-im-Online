/* Is Dunyasi 2026-10-13 — mevcut ekonomi ekranlarina bagli yeni ticaret paneli. */
const ID = {veri:null, sekme:"ozet"};
const ID_BAS = {
 ozet:["🏙️","Genel bakış"], sozlesme:["🤝","Sözleşmeler"], sigorta:["🛡️","Sigorta"], birlesme:["🔗","Birleşmeler"]
};
const idTL=n=>tlYaz(Math.round(Number(n)||0));
const idTxt=n=>e(String(n===null||n===undefined?"":n));
const idAd=t=>({fabrika:"Fabrika",magaza:"Mağaza",insaat:"Müteahhit",sigorta:"Sigortacı",sanayi:"Sanayi",tarim:"Tarım",teknoloji:"Teknoloji",ticaret:"Ticaret",medya:"Medya",banka:"Banka"})[t]||t||"Mevcut şirket";
const idUrun=u=>({gida:"Gıda",teknoloji:"Teknoloji",malzeme:"İnşaat malzemesi"})[u]||u;
const idTarih=t=>t?new Date(t).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";
const idMine=(tur,yonetici=true)=>((ID.veri||{}).benim||[]).filter(s=>(!tur||s.tur===tur)&&(!yonetici||s.yonetici!==false));
const idOpt=(liste,ek)=>liste.map(s=>'<option value="'+Number(s.id)+'">'+idTxt(s.ad)+(ek&&s.stok!==undefined?' · '+s.stok+' stok':'')+'</option>').join("");
const idKutu=(baslik,metin,aksiyon,label)=>'<div class="id-bilgi"><b>'+baslik+'</b><p>'+metin+'</p>'+(aksiyon?'<button class="btn altin" onclick="'+aksiyon+'">'+label+'</button>':'')+'</div>';
function idBicim(){
 return '<style id="isDunyasiCss">.id-hero{border-radius:20px;padding:20px 17px;background:linear-gradient(135deg,#1D355B,#41328D 70%,#6852CA);border:1px solid #8271d03c;box-shadow:0 12px 30px #080c2270;margin-bottom:14px}.id-hero .id-kicker{color:#e3d7ff;font-size:11px;letter-spacing:1.9px;font-weight:800}.id-hero h2{font:800 31px/1.08 var(--disp);margin:6px 0;color:#fff}.id-hero p{color:#d8dbec;font-size:13px}.id-stat{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px;margin-top:15px}.id-stat span{background:#ffffff19;border:1px solid #ffffff25;border-radius:10px;padding:10px 7px;min-width:0}.id-stat small{display:block;color:#d9d1ef;font-size:10px}.id-stat b{font-size:20px;color:white}.id-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-bottom:15px}.id-kart{text-align:left;display:flex;flex-direction:column;align-items:flex-start;min-height:111px;border:1px solid #ffffff1d;border-radius:16px;padding:14px;background:linear-gradient(145deg,#222e56,#18203f);box-shadow:0 3px 13px #0002}.id-kart .emo{font-size:29px}.id-kart b{font-size:14px;color:#fff;margin-top:5px}.id-kart small{font-size:11px;color:#b6c0db;line-height:1.3;margin-top:3px}.id-kart.aktif{border-color:#a995ff;background:linear-gradient(140deg,#44386e,#20284c)}.id-bilgi{padding:15px;margin:0 0 10px;border:1px solid var(--line2);border-radius:14px;background:var(--panel)}.id-bilgi b{color:var(--txt);font-size:15px}.id-bilgi p{color:var(--mut);margin:5px 0 11px;font-size:12px}.id-bilgi .btn{margin-top:7px}.id-small{font-size:11px;color:var(--mut)}.id-quick{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}.id-quick button{flex:1 1 45%;border-radius:10px;background:var(--panel2);padding:11px;color:var(--txt);font-size:12px;font-weight:800}@media(max-width:330px){.id-kart{padding:10px;min-height:105px}.id-stat b{font-size:16px}}</style>';
}
function idAltPanel(){
 const d=ID.veri||{}, k=ID.sekme, m=d.benim||[];
 const select=(tur)=>idMine(tur);
 const bos=s=>'<div class="kart"><p class="alt">'+s+'</p></div>';
 const sat=(h,alt)=>'<div class="kv"><span>'+h+'</span><b>'+alt+'</b></div>';
 let out="";
 if(k==="ozet"){
   out='<div class="kart"><h2>Benim işletmelerim</h2>'+(m.length?m.map(s=>sat(idTxt(s.ad),idAd(s.tur||s.sektor)+' · '+idTL(s.kasa)+' · %'+s.pay)).join(""):'<p class="alt">Henüz şirketin yok. İlk işletmeni kurabilirsin.</p>')+'</div>';
   out+='<div class="id-quick"><button onclick="ekranAc(sirketYonetimEkrani)">🏢 Mevcut şirketlerim</button><button onclick="ekranAc(halkaArzPazarEkrani)">📈 Halka arzlar</button><button onclick="ekranAc(pazarMerkezEkrani)">📊 Rekabetçi pazar</button><button onclick="ekranAc(emlakYeniEkrani)">🏡 Emlak pazarı</button></div>';
   out+=idKutu("Üretim · Mağaza · Franchise","Çok çeşitli ürünleri üret, oyunculardan stok tedarik et, zamanlı sanal müşteri satışları yap; fast food, kahve ve market zincirleri kur.","ticaretMerkezEkrani()","Üretim ve ticarete git");
   out+=idKutu("Mevcut şirketini kullan","Halka açık olmayan %100 sahibi olduğun şirketini yeni sisteme taşıyabilirsin. Bu işlemden sonra eski otomatik kâr yerine gerçek ticaret kazancı işler.","idEskiSirket()","Şirketimi ekonomiye bağla");
 }
 if(k==="uretim"){
   out=idKutu("Fabrika kur","Gıda, teknoloji veya inşaat malzemesi üret. Gerçek şirket kasandan üretim maliyeti öde; ürününü diğer oyuncu mağazalarına sat.","idEskiSirket()","Şirketimi ekonomiye bağla");
   for(const s of select("fabrika"))out+=idKutu(idTxt(s.ad),idUrun(s.urun)+" · Kasada "+idTL(s.kasa)+" · "+s.stok+" adet stok · Birim toptan fiyat "+idTL(s.uretim_fiyat),"idFabrikaModal("+s.id+")","Üretim ve fiyatı yönet");
   out+='<div class="bolum-bas"><h2>Üreticiler</h2></div>'+(d.fabrikalar||[]).map(s=>sat(idTxt(s.ad)+" · "+idUrun(s.urun),idTL(s.fiyat)+" · "+s.stok+" adet")).join("")||bos("Henüz üretici yok.");
 }
 if(k==="magaza"){
   out=idKutu("Mağaza işlet","Şirket kasandan toptan ürün satın al. Mağazan sınırlı günlük sanal müşteri talebine satış yapar. Rakip sayısı ve yüksek fiyat satış limitini düşürür; ürün bazlı KDV satış sırasında tahsil edilir.","idEskiSirket()","Şirketimi ekonomiye bağla");
   for(const s of select("magaza"))out+=idKutu(idTxt(s.ad),"Kasa "+idTL(s.kasa)+" · Toplam stok "+s.stok+" · Baz satış fiyatı "+idTL(s.perakende_fiyat),"idMagazaModal("+s.id+")","Stok ve satış yönetimi");
 }
 if(k==="insaat"){
   out=idKutu("Müteahhitlik","Projeye harcanan para şirket kasandan çıkar. İnşaat 24 saatte tamamlanır, 81 ilde mevcut emlak kotasına ve tapu sistemine bağlı daire, dükkân veya villa satılır.","idEskiSirket()","Şirketimi ekonomiye bağla");
   for(const s of select("insaat"))out+=idKutu(idTxt(s.ad),"Şirket kasası: "+idTL(s.kasa),"idProjeModal("+s.id+")","Yeni proje başlat");
   out+='<div class="bolum-bas"><h2>Satıştaki projeler</h2></div>'+(d.projeler||[]).map(p=>idKutu(idTxt(p.sirket)+" · "+idTxt(p.tip),idTxt(p.kalan)+" adet · "+idTL(p.birim_fiyat)+" / adet · "+(new Date(p.hazir)>new Date()?"Hazır olacağı zaman: "+idTarih(p.hazir):"Teslime hazır"),new Date(p.hazir)>new Date()?null:"idProjeSatinAl("+p.id+")","Konut satın al")).join("");
 }
 if(k==="sozlesme"){
   out=idKutu("Ticari sözleşme yap","Şirketler arası 3 günlük hizmet sözleşmesi imzala. Alıcı tutarı güvenli emanet hesaba ayırır; teslimi onaylayınca satıcı alır. Vade dolarsa alıcı geri alabilir.","idSozlesmeYeni()","Sözleşme teklifi gönder");
   out+='<div class="bolum-bas"><h2>Aktif teklifler ve işler</h2></div>'+(d.sozlesmeler||[]).map(c=>{
    const al=idMine().some(s=>s.id===c.alici_id),sa=idMine().some(s=>s.id===c.satici_id);
    let btn=c.durum==="teklif"&&al?"idSozlesmeKarar("+c.id+",'sozlesme_kabul')":
      c.durum==="teklif"&&sa?"idSozlesmeKarar("+c.id+",'sozlesme_iptal')":
      c.durum==="aktif"&&sa?"idSozlesmeKarar("+c.id+",'sozlesme_teslim')":
      c.durum==="teslim"&&al?"idSozlesmeKarar("+c.id+",'sozlesme_onay')":
      c.durum==="aktif"&&al&&new Date(c.vade)<new Date()?"idSozlesmeKarar("+c.id+",'sozlesme_iptal')":null;
    const text= c.durum==="teklif"&&al?"Teklifi kabul et":c.durum==="teklif"?"Teklifi iptal et":c.durum==="aktif"&&sa?"Teslim edildi":c.durum==="teslim"?"Teslimatı onayla":"Vade sonrası iptal";
    return idKutu(idTxt(c.satici)+" → "+idTxt(c.alici),idTxt(c.konu)+" · "+idTL(c.bedel)+" · "+idTxt(c.durum)+" · Vade "+idTarih(c.vade),btn,text);
   }).join("");
 }
 if(k==="sigorta"){
   out=idKutu("Sigorta sektörü","Oyuncular 3 günlük poliçe satın alır. Prim şirket kasasına gelir; şirket tazminat için yeterli rezerv tutmalıdır. 48 saat sonra sunucu tarafında tek seferlik hasar kontrolü yapılır.","idEskiSirket()","Şirketimi ekonomiye bağla");
   out+='<div class="bolum-bas"><h2>Sigorta teklifleri</h2></div>'+(d.sigortalar||[]).map(s=>idKutu(idTxt(s.ad),"Sigorta kasası "+idTL(s.kasa)+" · Prim teminatın %12'si","idPoliceModal("+s.id+")","Poliçe satın al")).join("");
   out+='<div class="bolum-bas"><h2>Poliçelerim</h2></div>'+(d.policeler||[]).map(p=>idKutu(idTxt(p.sirket)+" · "+idTxt(p.durum),"Prim "+idTL(p.prim)+" · Teminat "+idTL(p.teminat)+" · "+idTarih(p.bit),p.durum==="aktif"?"idPoliceKontrol("+p.id+")":null,"Hasar durumunu kontrol et")).join("");
 }
 if(k==="marka"){
   out=idKutu("Markanı zincire dönüştür","Mağazana isim hakkı bedeli ve %1-15 ciro payı belirle. Diğer mağazalar şube olur; her sanal müşteri satışından otomatik ciro payı kazanırsın.","idMarkaModal()","Marka ve franchise ayarları");
   out+='<div class="bolum-bas"><h2>Franchise veren markalar</h2></div>'+(d.markalar||[]).map(s=>idKutu(idTxt(s.ad),"İsim hakkı "+idTL(s.bedel)+" · Ciro payı %"+s.oran,"idFranchiseModal("+s.id+")","Bayilik al")).join("");
   out+=(d.subeler||[]).length?'<div class="kart"><h2>Bayiliklerim</h2>'+(d.subeler||[]).map(s=>sat(idTxt(s.marka),"Ciro payı %"+s.oran)).join("")+'</div>':"";
 }
 if(k==="birlesme"){
   out=idKutu("Şirket satın al ve birleştir","Mevcut hisse pazarı üzerinden şirket paylarını al. İki şirketin de %100 sahibiysen uygun koşullarda kasalarını ve sermayelerini tek şirket altında birleştirebilirsin. Halka açık şirketler ve bankalar korunur.","idBirlesmeModal()","İki şirketi birleştir");
   out+='<div class="id-quick"><button onclick="ekranAc(sirketYonetimEkrani)">📜 Hisse pazarı</button><button onclick="ekranAc(sirketPazarEkrani)">🏢 Satılık şirketler</button></div>';
 }
 return out||bos("Bu bölümde henüz işlem bulunmuyor.");
}
async function isDunyasiEkrani(){
 yukleniyor("İş Dünyası");
 try{
   ID.veri=await API.rpc("eko_panel");
   const d=ID.veri,m=d.benim||[],oz=m.reduce((a,s)=>a+Number(s.kasa||0)*Number(s.pay||0)/100,0);
   iskelet("İş Dünyası",idBicim()+
    '<section class="id-hero"><div class="id-kicker">EKONOMİ · TİCARET · YATIRIM</div><h2>İş Dünyası</h2><p>Üret, yatırım yap, satış gerçekleştir. Kendi ticaret imparatorluğunu kur.</p><div class="id-stat"><span><small>Şirketlerin</small><b>'+m.length+'</b></span><span><small>Kasa payların</small><b>'+idTL(oz)+'</b></span><span><small>İşletmelerim</small><b>'+m.filter(x=>!!x.tur).length+'</b></span></div></section>'+
    '<div class="id-grid"><button class="id-kart" style="border-color:#a995ff;background:linear-gradient(140deg,#44386e,#20284c)" onclick="ticaretMerkezEkrani()"><span class="emo">🏭</span><b>Üretim ve Ticaret</b><small>68 ürün · Sanal müşteri · Franchise · Mağaza zinciri</small></button>'+Object.entries(ID_BAS).map(([k,v])=>'<button class="id-kart '+(ID.sekme===k?'aktif':'')+'" onclick="idSekme(\''+k+'\')"><span class="emo">'+v[0]+'</span><b>'+v[1]+'</b><small>'+({ozet:"Ekonomik varlıklarını yönet",uretim:"Fabrika ve toptan satış",magaza:"Perakende ve stok",sozlesme:"Gerçek oyuncu anlaşmaları",sigorta:"Poliçe ve risk yönetimi",marka:"Marka zinciri oluştur",birlesme:"Şirket imparatorluğu kur"})[k]+'</small></button>').join("")+'</div>'+
    '<div class="bolum-bas"><h2>'+ID_BAS[ID.sekme][0]+' '+ID_BAS[ID.sekme][1]+'</h2><span class="kucuk">Canlı ekonomi</span></div>'+idAltPanel(),{geri:true});
 }catch(err){iskelet("İş Dünyası",'<div class="kart"><h2>Bağlantı kontrolü</h2><p class="alt">'+idTxt(hataCevir(err.message))+'</p></div>',{geri:true});}
}
function idSekme(t){if(!ID_BAS[t])return;ID.sekme=t;isDunyasiEkrani();}
async function idIslem(eylem,veri,sonuc){
 try{const r=await API.rpc("eko_islem",{p_eylem:eylem,p_veri:veri});if(typeof modalKapat==="function")modalKapat();toast(sonuc||"İşlem tamamlandı.");if(typeof durumYenile==="function")durumYenile().catch(()=>{});await isDunyasiEkrani();return r;}
 catch(err){toast(hataCevir(err.message),true);return null;}
}
function idModal(title,body,button,fn){
 const m=modal('<h3>'+idTxt(title)+'</h3>'+body+'<button class="btn altin" id="idKaydet">'+button+'</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
 const b=$("#idKaydet",m);
 b.onclick=async()=>{b.disabled=true;try{await fn(m)}finally{b.disabled=false}};
}
const idInput=(id,label,value,min,max)=>'<div class="alan"><label>'+label+'</label><input id="'+id+'" type="number" inputmode="numeric" min="'+(min||0)+'" '+(max?'max="'+max+'"':'')+' step="1" value="'+value+'"></div>';
const idSelect=(id,label,items)=>'<div class="alan"><label>'+label+'</label><select id="'+id+'">'+items+'</select></div>';
const idValue=(m,id)=>$("#"+id,m).value;
function idEskiSirket(){
 const mine=(ID.veri.benim||[]).filter(s=>!s.tur&&Number(s.pay)===100&&s.sektor!=="banka");
 if(!mine.length){toast("Uygun şirketin yok. Önce Şirketlerim ekranından şirket kurup ardından ekonomiye bağlamalısın.",true);return;}
 const types='<option value="fabrika">🏭 Fabrika</option><option value="magaza">🛍️ Mağaza</option><option value="insaat">🏗️ Müteahhitlik</option><option value="sigorta">🛡️ Sigorta</option>';
 idModal("Mevcut şirketi bağla",'<p class="alt">Yalnızca %100 sahibi olduğun halka kapalı şirketler dönüştürülebilir. Eski pasif kazanç yerine faaliyet kazancı geçer.</p>'+
 idSelect("idSirket","Şirket",idOpt(mine))+
 idSelect("idTur","Faaliyet alanı",types)+
 '<div id="idUrunAlan">'+idSelect("idUrun","Üretilecek ürün grubu",'<option value="gida">Gıda</option><option value="teknoloji">Teknoloji</option><option value="malzeme">İnşaat malzemesi</option>')+'</div>'+
 '<p class="alt" id="idTurAciklama"></p>',
 "Şirketi dönüştür",async el=>{
  if(!await onayla("Şirket dönüşümü","Şirketin eski otomatik kazancı duracak ve sektör faaliyetleri başlayacak.","Dönüştür"))return;
  await idIslem("etkinlestir",{sirket:Number(idValue(el,"idSirket")),tur:idValue(el,"idTur"),urun:idValue(el,"idTur")==="fabrika"?idValue(el,"idUrun"):null},"Şirket ticaret sistemine bağlandı.");
 });
 const m=document.querySelector("#idSirket")?.closest(".modal")||document;
 const co=m.querySelector("#idSirket"),type=m.querySelector("#idTur"),area=m.querySelector("#idUrunAlan"),msg=m.querySelector("#idTurAciklama");
 if(!co||!type)return;
 const refresh=()=>{
  const sel=mine.find(x=>Number(x.id)===Number(co.value));const sector=sel?.sektor;
  const allowed=sector==="insaat"?["insaat"]:sector==="ticaret"?["magaza","sigorta"]:["sanayi","teknoloji","tarim"].includes(sector)?["fabrika"]:[];
  [...type.options].forEach(o=>o.disabled=!allowed.includes(o.value));
  if(!allowed.includes(type.value))type.value=allowed[0]||"fabrika";
  if(area)area.style.display=type.value==="fabrika"?"":"none";
  if(msg)msg.textContent=type.value==="sigorta"?"Sigorta şirketi poliçe satar; fabrika ürünü bulunmaz.":type.value==="insaat"?"Müteahhit arsaya bina yapar; fabrika ürünü bulunmaz.":type.value==="magaza"?"Mağaza ürünleri fabrikalardan satın alır.":"Fabrika, üreteceği ürün grubunu seçer.";
 };
 co.addEventListener("change",refresh);type.addEventListener("change",refresh);refresh();
}
function idFabrikaModal(s){
 idModal("Fabrika üretimi",idInput("idAdet","Üretim adedi (1-250)",10,1,250),"Üret",m=>idIslem("uretim",{sirket:s,adet:Number(idValue(m,"idAdet"))},"Stoklara eklendi."));
 const md=document.querySelector("#idKaydet");
 if(md){const b=document.createElement("button");b.className="btn ikinci";b.textContent="Toptan fiyatı değiştir";md.parentNode.insertBefore(b,md);b.onclick=()=>idModal("Yeni toptan fiyat",idInput("idTutar","Birim fiyat ₺",6000,1000,50000),"Fiyatı kaydet",m=>idIslem("fiyat",{sirket:s,tutar:Number(idValue(m,"idTutar"))},"Toptan fiyat güncellendi."));}
}
function idMagazaModal(s){
 const fab=(ID.veri.fabrikalar||[]).filter(f=>f.stok>0);
 const sel=idSelect("idFab","Tedarikçi fabrika",idOpt(fab,true));
 const ur=idSelect("idUrun","Satılacak ürün",["gida","teknoloji","malzeme"].map(x=>'<option value="'+x+'">'+idUrun(x)+'</option>').join(""));
 idModal("Mağaza: toptan ürün al",'<p class="alt">Ürün bedeli mağaza kasasından fabrikaya geçer. Dilediğin zaman sanal müşterilere satış yapabilirsin.</p>'+sel+idInput("idAdet","Adet",5,1,250),"Toptan satın al",m=>idIslem("toptan",{sirket:s,hedef:Number(idValue(m,"idFab")),adet:Number(idValue(m,"idAdet"))},"Mağaza stoklarına işlendi."));
 // Ayrı butonlar aynı modalin icinde, ek alanlar.
 const md=document.querySelector("#idKaydet");
 if(md){
  const b=document.createElement("button");b.className="btn ikinci";b.textContent="Stoktan müşterilere sat";
  md.parentNode.insertBefore(b,md);
  b.onclick=()=>idModal("Mağaza satış",ur+idInput("idAdet","Satış adedi (1-100)",5,1,100),"Satış yap",m=>idIslem("satis",{sirket:s,urun:idValue(m,"idUrun"),adet:Number(idValue(m,"idAdet"))},"Ürünler satıldı."));
  const p=document.createElement("button");p.className="btn ikinci";p.textContent="Perakende fiyatını değiştir";
  md.parentNode.insertBefore(p,md);
  p.onclick=()=>idModal("Mağaza satış fiyatı",'<p class="alt">Gıda için baz fiyat. Teknoloji ve malzeme fiyatları ürün maliyetine göre otomatik ayarlanır; aşırı fiyat müşteri talebini azaltır.</p>'+idInput("idTutar","Baz satış fiyatı ₺",9500,7000,14000),"Fiyatı güncelle",m=>idIslem("fiyat",{sirket:s,tutar:Number(idValue(m,"idTutar"))},"Perakende fiyat güncellendi."));
 }
}
function idProjeModal(s){
 idModal("Yeni inşaat projesi",idSelect("idTip","Gayrimenkul türü",'<option value="daire">Daire</option><option value="dukkan">Dükkân</option><option value="villa">Villa</option>')+idInput("idAdet","Bağımsız bölüm sayısı (1-8)",2,1,8)+'<p class="alt">Maliyet şirket kasasından çıkar. Proje 24 saatte tamamlanır.</p>',"Projeyi başlat",m=>idIslem("proje",{sirket:s,tip:idValue(m,"idTip"),adet:Number(idValue(m,"idAdet"))},"İnşaat başladı."));
}
async function idProjeSatinAl(p){
 if(!await onayla("Gayrimenkul al","Birim satış fiyatı ve tapu harcı cüzdanından alınacak. Onaylıyor musun?","Satın al"))return;
 await idIslem("konut_al",{proje:p},"Tapu adına düzenlendi.");
}
function idSozlesmeYeni(){
 const mine=idMine();if(!mine.length){toast("Önce yönetebileceğin bir şirket gerekli.",true);return;}
 const others=ID.veri.benim||[];
 idModal("Ticari sözleşme öner",idSelect("idA","Satıcı şirketin",idOpt(mine))+
 idSelect("idB","Alıcı şirket",(ID.veri.sirketler||[]).filter(s=>!mine.some(a=>a.id===s.id)).map(s=>'<option value="'+s.id+'">'+idTxt(s.ad)+'</option>').join(""))+
 '<div class="alan"><label>İş veya hizmet açıklaması</label><input id="idKonu" maxlength="140" placeholder="Örn. teknoloji malzemesi tedariki"></div>'+
 idInput("idTutar","Toplam sözleşme bedeli ₺",50000,1000,10000000),"Teklifi gönder",m=>idIslem("sozlesme_teklif",{sirket:Number(idValue(m,"idA")),hedef:Number(idValue(m,"idB")),konu:idValue(m,"idKonu"),tutar:Number(idValue(m,"idTutar"))},"Sözleşme teklifi gönderildi."));
}
async function idSozlesmeKarar(id,eylem){
 if(!await onayla("Sözleşme işlemi","Bu sözleşmenin durumunu değiştirmek istiyor musun?","Onayla"))return;
 await idIslem(eylem,{id},"Sözleşme güncellendi.");
}
function idPoliceModal(id){
 idModal("Sigorta poliçesi","<p class='alt'>Prim teminatın %12'si, koruma 3 gün. Poliçenin sonucu 48 saat sonra bir kez belirlenir.</p>"+
 idInput("idTutar","Sigorta teminatı ₺",50000,5000,500000),"Poliçe al",m=>idIslem("police_al",{hedef:id,tutar:Number(idValue(m,"idTutar"))},"Poliçen başladı."));
}
async function idPoliceKontrol(id){await idIslem("police_kontrol",{id},"Hasar kontrolü tamamlandı.");}
function idMarkaModal(){
 const mag=idMine("magaza");if(!mag.length){toast("Önce bir mağazan olmalı.",true);return;}
 idModal("Mağazanı marka yap",idSelect("idSirket","Mağaza",idOpt(mag))+
 idInput("idTutar","Bayilik isim hakkı ₺",25000,1000,1000000)+
 idInput("idAdet","Ciro payı % (1-15)",5,1,15),"Marka kaydet",m=>idIslem("marka_ac",{sirket:Number(idValue(m,"idSirket")),tutar:Number(idValue(m,"idTutar")),adet:Number(idValue(m,"idAdet"))},"Franchise markası açıldı."));
}
function idFranchiseModal(marka){
 const mag=idMine("magaza");if(!mag.length){toast("Önce bir mağaza kur.",true);return;}
 idModal("Franchise bayiliği",idSelect("idSirket","Bayilik açacak mağaza",idOpt(mag)), "İsim hakkını öde",m=>idIslem("franchise_al",{sirket:Number(idValue(m,"idSirket")),hedef:marka},"Mağazan artık franchise şubesi."));
}
function idBirlesmeModal(){
 const m=idMine().filter(s=>Number(s.pay)===100);
 if(m.length<2){toast("İki şirkette de %100 paya sahip olmalısın.",true);return;}
 idModal("İki şirketi birleştir",'<p class="alt">Devrolan şirketin kasası ve sermayesi diğerine geçer. İşlem geri alınamaz. Banka, halka açık ve aktif yükümlülüğü bulunan şirketlerde engellenir.</p>'+
 idSelect("idAlan","Devam edecek şirket",idOpt(m))+idSelect("idKatilan","Devrolacak şirket",idOpt(m)),
 "Birleştir",async x=>{
  const a=Number(idValue(x,"idAlan")),b=Number(idValue(x,"idKatilan"));
  if(a===b){toast("Farklı şirketler seç.",true);return;}
  if(!await onayla("Kesin şirket birleşmesi","Devrolan şirket kapanacak ve kasası devam edecek şirkete aktarılacak. Bu işlem geri alınamaz.","Birleştir"))return;
  await idIslem("birles",{sirket:a,hedef:b},"Şirketler birleştirildi.");
 });
}
window.isDunyasiEkrani=isDunyasiEkrani;
(function(){
 if(typeof iskelet!=="function")return;
 const onceki=iskelet;
 window.iskelet=iskelet=function(baslik,govde,opt){
   const sonuc=onceki.apply(this,arguments);
   try{
    if(baslik==="Hayat"){
     const grid=document.querySelector(".vit-ana-izgara");
     if(grid&&!grid.querySelector(".id-giris"))grid.insertAdjacentHTML("afterbegin",'<button class="vit-ana-kart id-giris" style="grid-column:1 / -1;background:linear-gradient(110deg,#232e5a,#48378d);border:1px solid #977cff;min-height:82px;flex-direction:row;align-items:center;gap:12px;text-align:left" onclick="ekranAc(isDunyasiEkrani)"><span class="vit-ikon" style="font-size:33px">🌐</span><span style="display:flex;flex-direction:column;gap:4px"><b style="font-size:18px">İŞ DÜNYASI</b><span>Üretim · Ticaret · İnşaat · Sigorta · Franchise</span></span><span class="ok">›</span></button>');
    }
    if(baslik==="Şirketler"){
      const el=document.querySelector(".vit-dugme");
      if(el&&!el.querySelector(".id-giris"))el.insertAdjacentHTML("afterbegin",'<button class="btn altin id-giris" onclick="ekranAc(isDunyasiEkrani)">🌐 İş Dünyası · 7 yeni sistem</button>');
    }
   }catch(err){console.warn("İş Dünyası giriş hatası:",err);}
   return sonuc;
 };
})();

/* Zamanli uretim ve magaza zincirleri (ayri isletme kurma ekrani yok). */
(function(){
 if(document.getElementById("ticaretGercekciModul"))return;
 const script=document.createElement("script");
 script.id="ticaretGercekciModul";script.src="ticaret_gercekci.js?v=20261013-5";script.async=false;
 document.body.appendChild(script);
})();
