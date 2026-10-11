/* OYUNCU BANKALARI: vadeli kredi urunleri, oyuncu izni, Adliye icra ve haciz */
const BK_KAPSAM={maas:"Maaş ve makam ücreti",mulk:"Gayrimenkul listesi",kira:"Kira gelirleri",sirket:"Şirket hisseleri",gunluk:"Günlük gelir"};
function bkUrunAdi(s){return s===24?"1 gün":s===72?"3 gün":s>=168?(s/168)+" hafta":s+" saat";}
function bkTL(n){return fmt(Number(n||0))+" ₺";}
function bkKontrol(v){return Array.isArray(v)?v:[];}
function bkTarih(x){return x?new Date(x).toLocaleString("tr-TR"):"—";}
function bkBilgiAd(x){return BK_KAPSAM[x]||x;}
async function bkIslem(ad,params,mesaj,son){
 try{const r=await API.rpc(ad,params);toast(mesaj||"İşlem kaydedildi.");if(son)await son();return r;}
 catch(err){toast(hataCevir(err.message),true);return null;}
}
async function bankaKrediDosyaEkrani(id){
 yukleniyor("Kredi sözleşmeleri");
 try{
  const bankID=Number(id||0);
  const [p,izin,benim,bank]=await Promise.all([
   API.rpc("oyb_portfoy"),API.rpc("oyb_bilgi_bekleyen"),
   API.rpc("oyb_kredi_ekler",{p_banka:null}),
   bankID?API.rpc("oyb_yonetim",{p_banka:bankID}).catch(()=>null):Promise.resolve(null)
  ]);
  const [urunler,bankaEk]=bankID&&bank?await Promise.all([
   API.rpc("oyb_urunler",{p_banka:bankID}),
   API.rpc("oyb_kredi_ekler",{p_banka:bankID})
  ]):[{urunler:[]},[]];
  let html='<div class="kart"><h2>🏦 Kredi sözleşmeleri ve hesap dökümü</h2><p class="alt">Başvuru sırasında vade ve taksit planı oluşur. Banka, ayrıntılı mali bilgilerini yalnızca verdiğin izin kapsamında inceleyebilir. Borcun vadesi geçerse Adliye üzerinden yargı kararı ile icra takibi yapılabilir.</p></div>';
  if(bank){
   html+='<div class="kart"><h2>'+e(bank.ad)+' · Kredi ürünleri</h2><p class="alt">Bu vadelerin hangilerini satacağını, taksit sayısını ve ilave faiz oranını belirleyebilirsin. Eski sözleşmeler değişmez.</p>';
   bkKontrol(urunler.urunler).forEach(x=>{
    const key=bankID+'_'+x.saat;
    html+='<div class="kart"><b>'+bkUrunAdi(x.saat)+'</b>'+
     '<div class="alan"><label><input type="checkbox" id="bk_aktif_'+key+'" '+(x.aktif?'checked':'')+'> Başvuruya açık</label></div>'+
     '<div class="alan"><label>Taksit adedi</label><select id="bk_taksit_'+key+'">'+
     [1,2,3,4].filter(n=>x.saat%n===0).map(n=>'<option value="'+n+'" '+(n===x.taksit?'selected':'')+'>'+n+' taksit</option>').join('')+'</select></div>'+
     '<div class="alan"><label>Vade ek faizi (%)</label><input type="number" min="0" max="3" step="0.01" id="bk_ek_'+key+'" value="'+x.ek_faiz+'"></div>'+
     '<button class="btn ikinci" onclick="bkUrunKaydet('+bankID+','+x.saat+')">Kredi paketini kaydet</button></div>';
   });
   html+='</div><div class="kart"><h2>Kredi başvuruları · Finansal bilgi iste</h2>';
   const bm=new Map(bkKontrol(bankaEk).map(x=>[Number(x.id),x]));
   bkKontrol(bank.krediler).forEach(k=>{
    const ext=bm.get(Number(k.id))||{},km=Number(k.id),vade=Date.parse(k.vade||0);
    const kapsam=Object.keys(BK_KAPSAM);
    html+='<div class="kart"><b>'+e(k.borclu)+' · Kredi #'+km+'</b>'+
     '<div class="kv"><span>Kalan</span><b>'+bkTL(k.kalan)+'</b></div>'+
     '<p class="alt">Durum: '+e(k.durum)+' · İzin: '+e(ext.bilgi_durum||"yok")+'</p>';
    if(k.durum==='basvuru'){
     html+='<p class="alt">İstenecek belgeleri seç:</p>'+
      kapsam.map(a=>'<label style="display:block;margin:5px 0"><input type="checkbox" name="bk_iste_'+km+'" value="'+a+'" checked> '+e(bkBilgiAd(a))+'</label>').join('')+
      '<button class="btn ikinci" onclick="bkBilgiIste('+km+','+bankID+')">Oyuncudan belge izni iste</button>';
    }
    if(ext.bilgi_durum==='izin')
     html+='<button class="btn ikinci" onclick="bkBilgiGoster('+km+')">İzinli finansal dökümü incele</button>';
    if((k.durum==='gecikmis'||(k.durum==='aktif'&&vade<Date.now()))&&Number(k.kalan)>0)
     html+='<button class="btn tehlike" onclick="bkIcraBasvur('+km+')">Adliye üzerinden icra davası aç</button>';
    html+='</div>';
   });
   html+='</div>';
  }
  html+='<div class="kart"><h2>Benden istenen mali bilgiler</h2>';
  bkKontrol(izin).filter(x=>x.durum==='talep'||x.durum==='izin').forEach(x=>{
   html+='<div class="kart"><b>'+e(x.banka)+' · Kredi #'+Number(x.kredi_id)+'</b>'+
    '<p class="alt">Talep edilen bilgiler: '+bkKontrol(x.istenen).map(bkBilgiAd).map(e).join(", ")+'</p>'+
    '<p class="alt">Durum: '+(x.durum==='talep'?'Onay bekleniyor':'Onaylandı')+'</p>';
   if(x.durum==='talep'){
    html+='<p class="alt">Yalnız paylaşmak istediklerini işaretle:</p>'+
    bkKontrol(x.istenen).map(a=>'<label style="display:block;margin:5px 0"><input type="checkbox" name="bk_ver_'+Number(x.kredi_id)+'" value="'+e(a)+'" checked> '+e(bkBilgiAd(a))+'</label>').join('')+
    '<div class="satir"><button class="btn yarim altin" onclick="bkBilgiYanit('+Number(x.kredi_id)+',true)">Seçilenlere izin ver</button>'+
    '<button class="btn yarim ikinci" onclick="bkBilgiYanit('+Number(x.kredi_id)+',false)">Reddet</button></div>';
   }
   html+='</div>';
  });
  html+='</div><div class="kart"><h2>Kredi ödeme takvimim</h2>';
  const kendim=new Map(bkKontrol(benim).map(x=>[Number(x.id),x]));
  bkKontrol(p.krediler).forEach(k=>{
   const x=kendim.get(Number(k.id))||{};
   html+='<div class="kart"><b>'+e(k.banka)+' · #'+Number(k.id)+'</b>'+
    '<p class="alt">Kalan: '+bkTL(k.kalan)+' · '+e(k.durum)+'</p>'+
    bkKontrol(x.taksitler).map(y=>'<div class="kv"><span>'+y.sira+'. taksit · '+bkTarih(y.vade)+'</span><b>'+bkTL(Math.max(0,y.tutar-y.odenen))+'</b></div>').join('')+
    (k.durum==='basvuru'?'<button class="btn ikinci" onclick="oybKrediBasvuruIptal('+Number(k.id)+')">Başvurumu iptal et</button>':'')+
    (['aktif','gecikmis'].includes(k.durum)?'<div class="alan"><label>Ödeme tutarı (₺)</label><input id="oyb_kode_'+Number(k.id)+'" type="number" min="1" value="'+Math.ceil(k.kalan)+'"></div><button class="btn altin" onclick="bkBorcOde('+Number(k.id)+','+bankID+')">Borcumu öde</button>':'')+
   '</div>';
  });
  html+='</div><button class="btn ikinci" onclick="bankaRehberiEkrani()">Banka rehberine dön</button>';
  iskelet("Kredi sözleşmeleri",html,{geri:true});
 }catch(err){iskelet("Kredi sözleşmeleri",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
async function bkBorcOde(id,bank){
 const tutar=Number(document.getElementById("oyb_kode_"+id)?.value);
 await bkIslem("oyb_kredi_ode",{p_id:id,p_tutar:tutar},"Kredi ödemesi kaydedildi.",()=>bankaKrediDosyaEkrani(bank));
}
async function bkUrunKaydet(bank,saat){
 const key=bank+"_"+saat;
 const p_aktif=!!document.getElementById("bk_aktif_"+key)?.checked;
 const p_taksit=Number(document.getElementById("bk_taksit_"+key)?.value);
 const p_ek_faiz=Number(document.getElementById("bk_ek_"+key)?.value);
 await bkIslem("oyb_urun_ayarla",{p_banka:bank,p_saat:saat,p_aktif,p_taksit,p_ek_faiz},"Kredi ürünü güncellendi.",()=>bankaKrediDosyaEkrani(bank));
}
async function bkBilgiIste(kredi,bank){
 const a=[...document.querySelectorAll('input[name="bk_iste_'+kredi+'"]:checked')].map(x=>x.value);
 if(!a.length){toast("En az bir mali bilgi seç.",true);return;}
 await bkIslem("oyb_bilgi_talep",{p_kredi:kredi,p_kapsam:a},"Oyuncuya bilgi talebi iletildi.",()=>bankaKrediDosyaEkrani(bank));
}
async function bkBilgiYanit(kredi,onay){
 const a=[...document.querySelectorAll('input[name="bk_ver_'+kredi+'"]:checked')].map(x=>x.value);
 if(onay&&!a.length){toast("En az bir bilgiye izin ver veya isteği reddet.",true);return;}
 await bkIslem("oyb_bilgi_yanit",{p_kredi:kredi,p_onay:onay,p_kapsam:onay?a:[]},"İzin tercihin kaydedildi.",()=>bankaKrediDosyaEkrani());
}
async function bkBilgiGoster(kredi){
 try{
  const r=await API.rpc("oyb_bilgi_dokumu",{p_kredi:kredi});
  const dok=r.dokum||{};
  let rows=Object.entries(dok).map(([k,v])=>'<div class="kart"><b>'+e(bkBilgiAd(k))+'</b><pre style="white-space:pre-wrap;word-break:break-word;font-size:12px">'+e(JSON.stringify(v,null,2))+'</pre></div>').join('');
  const m=modal('<p class="alt">Oyuncunun izin verdiği bilgileri içerir. İzin verilmeyen alanlar açıklanmaz.</p>'+rows);
  if(typeof adlFormBaslik==='function')adlFormBaslik(m,"İzinli mali döküm · Kredi #"+kredi);
 }catch(err){toast(hataCevir(err.message),true);}
}
async function bkIcraBasvur(kredi){
 const types=[["gelir","Gelir haczi"],["mulk","Gayrimenkul icra satışı"],["hisse","Şirket hissesi icra satışı"],["karma","Gelir ve varlık haczi"]];
 const m=modal('<p class="alt">Başvuru Adliye’ye iletilir. Borçlu 24 saat içinde savunma yapabilir. Yargıçların en az ikisi onaylamadan ve karar kesinleşmeden haciz uygulanmaz. Kredinin vadesi üzerinden en az 12 saat geçmiş olmalı.</p>'+
 '<div class="alan"><label>Talep edilen icra yolu</label><select id="bk_icra_tur">'+types.map(x=>'<option value="'+x[0]+'">'+x[1]+'</option>').join('')+'</select></div>'+
 '<div class="alan"><label>Dava gerekçesi (20–1500 karakter)</label><textarea id="bk_icra_gerekce" rows="3">Kredi #'+Number(kredi)+' vadesinde ödenmedi. Kalan borcun tahsili için icra takibi talep ediyorum.</textarea></div>'+
 '<button class="btn tehlike" id="bk_icra_submit">Adliye icra davası aç</button>');
 if(typeof adlFormBaslik==='function')adlFormBaslik(m,"İcra davası · Kredi #"+kredi);
 m.querySelector("#bk_icra_submit").onclick=async()=>{
  const r=await bkIslem("oyb_icra_baslat",{p_kredi:kredi,p_tur:m.querySelector("#bk_icra_tur").value,p_gerekce:m.querySelector("#bk_icra_gerekce").value},"İcra davası Adliye’ye gönderildi.",()=>adliyeEkrani());
  if(r)modalKapat();
 };
}
function bkIcraEtiket(d){return {acik:"Savunma / karar bekleniyor",kabul:"İcra kararı kabul",ret:"Talep reddedildi",itiraz:"İtiraz incelemesinde",kapandi:"Borç kapandı"}[d.durum]||d.durum;}
async function icraAdliyeKarti(){
 try{
  const [dd,hh]=await Promise.all([API.rpc("oyb_icra_dosyalar"),API.rpc("oyb_icra_haciz_liste")]);
  const ds=bkKontrol(dd),hs=bkKontrol(hh.ihaleler),va=bkKontrol(hh.varliklar);
  let h='<div class="kart"><details><summary style="cursor:pointer;font-weight:700">🏦 Kredi icra mahkemesi ('+ds.length+' dosya) ve haciz ihaleleri ('+hs.length+')</summary>'+
  '<p class="alt">Burası yalnız oyun içi finansal uyuşmazlıklar içindir. Banka geciken borç için dava açar, borçlu savunma yapar. Tarafsız iki mahkeme üyesi karar verir. İlk karara 24 saat içinde itiraz mümkündür. Gelire ancak kesinleşen kararda %25’e kadar kesinti uygulanır; haczedilen varlıklar borçla mahsuplaştırılarak icrada satılır, fazla tutar borçluya iade edilir.</p>';
  ds.forEach(d=>{
   h+='<div class="kart"><b>Dosya #'+Number(d.id)+' · '+e(d.banka)+'</b><p class="alt">'+
    e(d.borclu)+' · '+e(bkIcraEtiket(d))+' · '+e(d.tur)+' · Kalan '+bkTL(d.kalan)+'</p>'+
    '<p>'+e(d.gerekce)+'</p><p class="alt">Savunma: '+e(d.savunma||"Henüz sunulmadı")+'</p>'+
    '<p class="alt">Savunma sonu: '+bkTarih(d.savunma_son)+' · Kesinleşme: '+bkTarih(d.kesin_son)+'</p>';
   if(d.borclu_muyum&&d.durum==='acik'&&Date.parse(d.savunma_son)>Date.now())
    h+='<div class="alan"><label>Savunmam (10–1500 karakter)</label><textarea id="bk_sav_'+d.id+'" rows="3"></textarea></div><button class="btn ikinci" onclick="bkIcraSavun('+d.id+')">Savunmayı gönder</button>';
   if(d.borclu_muyum&&d.durum==='kabul'&&Date.parse(d.kesin_son)>Date.now()&&!d.itiraz_at)
    h+='<div class="alan"><label>İtiraz gerekçesi</label><textarea id="bk_it_'+d.id+'" rows="2"></textarea></div><button class="btn ikinci" onclick="bkIcraItiraz('+d.id+')">İtiraz et</button>';
   if(d.hakim_miyim&&['acik','itiraz'].includes(d.durum)){
    h+='<div class="alan"><label>Gerekçeli karar</label><textarea id="bk_karar_'+d.id+'" rows="2"></textarea></div>'+
     '<div class="satir"><button class="btn yarim altin" onclick="bkIcraOy('+d.id+',true)">Haczi kabul et</button><button class="btn yarim ikinci" onclick="bkIcraOy('+d.id+',false)">Reddet</button></div>';
   }
   if(d.itiraz)h+='<p class="alt">İtiraz: '+e(d.itiraz)+'</p>';
   if(d.oylar?.length)h+='<details><summary>Yargıç oyları</summary>'+d.oylar.map(o=>'<p class="alt">'+e(o.uye)+' · '+e(o.asama)+' · '+e(o.karar)+' · '+e(o.gerekce)+'</p>').join('')+'</details>';
   if(d.banka_yetkilisi&&d.durum==='kabul'&&Date.parse(d.kesin_son)<=Date.now()){
    const assets=va.filter(x=>Number(x.icra_id)===Number(d.id));
    h+='<details><summary>Haczedilebilecek varlıklar ('+assets.length+')</summary>'+
    assets.map(a=>'<div class="liste-satir"><div class="orta"><b>'+e(a.ad)+'</b><p class="alt">İcra fiyatı: '+bkTL(a.tahmini)+'</p></div>'+
      '<button class="btn ikinci" onclick="bkHacizBaslat('+Number(d.id)+',\''+e(a.tur)+'\','+Number(a.varlik_id)+')">Satışa çıkar</button></div>').join('')+'</details>';
   }
   h+='</div>';
  });
  if(!ds.length)h+='<p class="alt">Şu anda kredi icra davası yok.</p>';
  if(hs.length)h+='<h3>Mahkeme onaylı icra satışları</h3>';
  hs.forEach(x=>{
   h+='<div class="kart"><b>'+e(x.banka)+' · #'+Number(x.icra_id)+'</b><p class="alt">'+
    e(x.borclu)+' · '+e(x.tur)+' #'+Number(x.varlik_id)+' · '+bkTL(x.fiyat)+'</p>'+
    '<button class="btn altin" onclick="bkHacizAl('+Number(x.id)+')">İcradan satın al</button></div>';
  });
  return h+'</details></div>';
 }catch(err){return '<div class="kart"><p class="alt">İcra dosyaları yüklenemedi: '+e(hataCevir(err.message))+'</p></div>';}
}
async function bkIcraSavun(id){await bkIslem("oyb_icra_savun",{p_icra:id,p_savunma:document.getElementById("bk_sav_"+id)?.value},"Savunman kaydedildi.",adliyeEkrani);}
async function bkIcraItiraz(id){await bkIslem("oyb_icra_itiraz",{p_icra:id,p_gerekce:document.getElementById("bk_it_"+id)?.value},"İtirazın mahkemeye gönderildi.",adliyeEkrani);}
async function bkIcraOy(id,onay){await bkIslem("oyb_icra_karar",{p_icra:id,p_karar:onay?"kabul":"ret",p_gerekce:document.getElementById("bk_karar_"+id)?.value},"Mahkeme oyun kaydedildi.",adliyeEkrani);}
async function bkHacizBaslat(id,tur,varlik){if(!await onayla("İcra satışına çıkar","Bu varlık mahkeme kararı kapsamında satışa çıkarılacak. Devam edilsin mi?","Satışa çıkar"))return;await bkIslem("oyb_icra_haciz_sec",{p_icra:id,p_tur:tur,p_varlik:varlik},"İcra satış ilanı açıldı.",adliyeEkrani);}
async function bkHacizAl(id){if(!await onayla("İcra satışı","Bu oyun içi varlığı belirtilen sabit fiyattan satın alacaksın. Ödeme borca mahsup edilecek, fazlası borçluya kalacak. Onaylıyor musun?","Satın al"))return;await bkIslem("oyb_icra_haciz_al",{p_haciz:id},"İcra satışı tamamlandı.",adliyeEkrani);}


/* GITHUB PAGES: tek dosyali surum icin uyumluluk baglantilari.
   Kaynak derlendikten sonra da JS modulu yeniden baglanabilir. */
(function bkSayfaBaglantilari(){
 if(window.__BK_ICRA_BAGLANDI)return;
 window.__BK_ICRA_BAGLANDI=true;
 const eskiDetay=window.bankaDetayEkrani;
 if(typeof eskiDetay==="function" && !eskiDetay.toString().includes("oyb_urunler")){
  window.bankaDetayEkrani=async function(id){
   await eskiDetay(id);
   try{
    const r=await API.rpc("oyb_urunler",{p_banka:id});
    window.BK_BANKA_URUN=window.BK_BANKA_URUN||{};
    window.BK_BANKA_URUN[id]=r.urunler||[];
    const sel=document.getElementById("oyb_ksaat_"+id);
    if(sel){
     sel.innerHTML=(r.urunler||[]).filter(x=>x.aktif).map(x=>'<option value="'+Number(x.saat)+'">'+bkUrunAdi(x.saat)+' · '+Number(x.taksit)+' taksit · ek faiz %'+fmt(x.ek_faiz,2)+'</option>').join("");
     if(!sel.options.length)sel.insertAdjacentHTML("beforeend",'<option value="">Banka kredi başvurularını kapattı</option>');
     const kart=sel.closest(".kart");
     if(kart&&!kart.querySelector(".bk-sozlesme"))kart.insertAdjacentHTML("beforeend",'<button class="btn ikinci bk-sozlesme" onclick="bankaKrediDosyaEkrani('+Number(id)+')">Ödeme takvimleri, kredi dosyaları ve bilgi izinleri</button>');
    }
   }catch(err){toast(hataCevir(err.message),true);}
  };
 }
 const eskiYonetim=window.oybYonetim;
 if(typeof eskiYonetim==="function"&&!eskiYonetim.toString().includes("bankaKrediDosyaEkrani")){
  window.oybYonetim=async function(id){
   await eskiYonetim(id);
   const root=document.querySelector("#icerik")||document.querySelector("main")||document;
   if(root.querySelector(".bk-kredi-yonetimi"))return;
   const kart=[...root.querySelectorAll(".kart")].find(x=>x.textContent?.includes("Faiz oranlarını yönet"));
   if(kart)kart.insertAdjacentHTML("beforeend",'<button class="btn altin bk-kredi-yonetimi" onclick="bankaKrediDosyaEkrani('+Number(id)+')">Kredi paketlerini, belgeleri ve icrayı yönet</button>');
  };
 }
 const eskiPortfoy=window.bankaPortfoyEkrani;
 if(typeof eskiPortfoy==="function"&&!eskiPortfoy.toString().includes("bankaKrediDosyaEkrani")){
  window.bankaPortfoyEkrani=async function(){
   await eskiPortfoy();
   const root=document.querySelector("#icerik")||document.querySelector("main")||document;
   const kart=[...root.querySelectorAll(".kart")].find(x=>x.textContent?.includes("Kredilerim"));
   if(kart&&!kart.querySelector(".bk-kredi-portfoy"))kart.insertAdjacentHTML("beforeend",'<button class="btn altin bk-kredi-portfoy" onclick="bankaKrediDosyaEkrani()">Kredi taksitlerim ve bilgi izinlerim</button>');
  };
 }
 const eskiAdliye=window.adliyeHtml;
 if(typeof eskiAdliye==="function"&&!eskiAdliye.toString().includes("icraAdliyeKarti")){
  window.adliyeHtml=async function(){return (await eskiAdliye())+(await icraAdliyeKarti());};
 }
 const eskiRisk=window.oybKrediRiskGoster;
 if(typeof eskiRisk==="function"&&!eskiRisk.toString().includes("BK_BANKA_URUN")){
  window.oybKrediRiskGoster=async function(id){
   const sel=document.getElementById("oyb_ksaat_"+id);
   const saat=Number(sel?.value);
   if(!saat)return;
   await eskiRisk(id);
   const urun=(window.BK_BANKA_URUN?.[id]||[]).find(x=>Number(x.saat)===saat);
   if(!urun)return;
   const el=document.getElementById("oyb_kredi_risk_"+id);
   try{
    const offer=await API.rpc("kredi_uygunluk",{p_banka:id,p_saat:saat});
    const toplamFaiz=Math.min(19.5,Number(offer.oran)+Number(urun.ek_faiz));
    const tutar=Number(document.getElementById("oyb_ktutar_"+id)?.value||0);
    const toplam=Math.round(tutar*(1+toplamFaiz/100));
    const taksit=Math.ceil(toplam/Math.max(1,Number(urun.taksit)));
    if(el)el.insertAdjacentHTML("beforeend",'<div class="kart"><div class="kv"><span>Kesin vade faizi (ek faiz dahil)</span><b>%'+fmt(toplamFaiz,2)+'</b></div><div class="kv"><span>Taksit sayısı</span><b>'+Number(urun.taksit)+'</b></div><div class="kv"><span>Toplam geri ödeme</span><b>'+bkTL(toplam)+'</b></div><div class="kv"><span>Yaklaşık taksit</span><b>'+bkTL(taksit)+'</b></div></div>');
   }catch(err){if(el)el.textContent=hataCevir(err.message);}
  };
 }
 const eskiBasvur=window.oybKrediBasvur;
 if(typeof eskiBasvur==="function"&&!eskiBasvur.toString().includes("BK_BANKA_URUN")){
  window.oybKrediBasvur=async function(id){
   const tutar=Number(document.getElementById("oyb_ktutar_"+id)?.value);
   const saat=Number(document.getElementById("oyb_ksaat_"+id)?.value);
   if(!Number.isSafeInteger(tutar)||tutar<1000||tutar>500000||!saat){toast("Tutar veya kredi vadesi geçersiz.",true);return;}
   try{
    const teklif=await API.rpc("kredi_uygunluk",{p_banka:id,p_saat:saat});
    if(tutar>Number(teklif.azami_kredi)||!teklif.uygun){toast("Kredi limitin "+bkTL(teklif.azami_kredi)+". "+(teklif.neden||""),true);return;}
    const urun=(window.BK_BANKA_URUN?.[id]||[]).find(x=>Number(x.saat)===saat&&x.aktif);
    if(!urun){toast("Banka bu vade için kredi paketi sunmuyor.",true);return;}
    const oran=Math.min(19.5,Number(teklif.oran)+Number(urun.ek_faiz));
    const toplam=Math.round(tutar*(1+oran/100));
    const sure=bkUrunAdi(saat);
    if(!await onayla("Özel banka kredisi",bkTL(tutar)+" · "+sure+" · "+urun.taksit+" taksit · Faiz %"+fmt(oran,2)+" · Toplam geri ödeme "+bkTL(toplam)+". Başvuruyu bankaya gönder?","Başvur"))return;
    const r=await API.rpc("oyb_kredi_basvur",{p_banka:id,p_tutar:tutar,p_saat:saat});
    toast("Kredi talebin bankaya iletildi. Toplam geri ödeme "+bkTL(r.toplam)+".");
    if(typeof bankaDetayEkrani==="function")await bankaDetayEkrani(id);
   }catch(err){toast(hataCevir(err.message),true);}
  };
 }
})();
