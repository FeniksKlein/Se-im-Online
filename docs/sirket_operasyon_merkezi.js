/* Sirketlerim: portfoy, uretim takibi, fabrika->magaza toptan satis. 2026-10-13 */
(function(){
 "use strict";
 if(window.SIRKET_OPERASYON_MODUL) return;
 window.SIRKET_OPERASYON_MODUL=true;
 const onceki=window.sirketYonetimEkrani;
 window.sirketEskiYonetimEkrani=onceki;
 const V={sirketler:[],ticaret:null,hata:"",ticaretHata:""};
 const guvenli=x=>typeof e==="function"?e(String(x??"")):String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
 const para=x=>(Math.round(Number(x)||0)).toLocaleString("tr-TR")+" ₺";
 const tarih=x=>x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";
 const simdi=()=>Date.now();
 const okId=x=>Number.isSafeInteger(Number(x))&&Number(x)>0?Number(x):0;
 const num=x=>Number(x)||0;
 const urunler=()=>V.ticaret?.urunler||[];
 const urun=k=>urunler().find(x=>x.kod===k);
 const firmalar=()=>V.ticaret?.sirketler||[];
 const firma=id=>V.sirketler.find(x=>num(x.id)===num(id));
 const etkin=id=>firmalar().find(x=>num(x.id)===num(id));
 const stok=id=>(V.ticaret?.stok||[]).filter(x=>num(x.sirket)===num(id)&&num(x.adet)>0);
 const emirler=id=>(V.ticaret?.uretim||[]).filter(x=>num(x.sirket)===num(id));
 const magaza=()=>firmalar().filter(x=>x.tur==="magaza"&&x.yonetici);
 const tedarik=()=>V.ticaret?.tedarikciler||[];
 const btn=(name,js,secondary)=>'<button class="btn '+(secondary?"ikinci":"altin")+'" onclick="'+js+'">'+guvenli(name)+'</button>';
 const box=(name,body,buttons)=>'<div class="kart so-firma"><h3>'+guvenli(name)+'</h3>'+body+(buttons||"")+'</div>';
 const satir=(a,b)=>'<div class="kv"><span>'+guvenli(a)+'</span><b>'+guvenli(b)+'</b></div>';
 const tip=s=>s?.tur==="fabrika"?"🏭 Fabrika":s?.tur==="magaza"?"🛒 Market / mağaza":
  s?.tur==="insaat"?"🏗️ İnşaat":s?.tur==="sigorta"?"🛡️ Sigorta":null;
 function stil(){
  return '<style id="sirketOperasyonCss">'+
   '.so-firma{margin:10px 0;padding:16px}.so-firma .btn{margin:7px 0 0}'+
   '.so-firma h3{margin:0 0 12px;font-size:20px}'+
   '.so-sec{background:var(--panel2);border:1px solid var(--line2);padding:12px;border-radius:12px;margin:9px 0}'+
   '.so-sec b{overflow-wrap:anywhere}.so-muted{color:var(--txt2);font-size:13px;line-height:1.5}'+
   '.so-buttons{display:grid;gap:7px}.so-list{display:grid;gap:8px}'+
   '.so-detail .kv{align-items:flex-start}.so-detail .kv b{max-width:60%;text-align:right}'+
   '</style>';
 }
 async function yenile(){
  const cevap=await Promise.allSettled([API.rpc("sirket_liste"),API.rpc("eko_ticaret_panel")]);
  V.hata=""; V.ticaretHata="";
  if(cevap[0].status==="fulfilled"&&Array.isArray(cevap[0].value?.sirketler))
   V.sirketler=cevap[0].value.sirketler;
  else{V.sirketler=[];V.hata=cevap[0].status==="rejected"?
   String(cevap[0].reason?.message||cevap[0].reason):"Şirket listesi getirilemedi.";}
  if(cevap[1].status==="fulfilled"&&cevap[1].value?.sirketler){
   V.ticaret=cevap[1].value;
  }else{V.ticaret=null;V.ticaretHata=cevap[1].status==="rejected"?
   String(cevap[1].reason?.message||cevap[1].reason):"Üretim verisi getirilemedi.";}
 }
 function emirDurum(q){
  if(q.tamam) return "Tamamlandı · stoklara aktarıldı ("+tarih(q.tamam)+")";
  if(!q.hazir)return "Üretim devam ediyor";
  if(new Date(q.hazir).getTime()<=simdi())return "Üretim süresi doldu · stok aktarımı bekleniyor (10 dakikada bir)";
  const dk=Math.ceil((new Date(q.hazir).getTime()-simdi())/60000);
  return "Üretimde · yaklaşık "+dk+" dk kaldı · Bitiş: "+tarih(q.hazir);
 }
 function kisaDurum(f){
  if(f?.tur==="fabrika"){
   const es=emirler(f.id),bek=es.filter(x=>!x.tamam);
   const elde=stok(f.id).reduce((n,x)=>n+num(x.adet),0);
   return bek.length+" devam eden üretim · "+elde+" hazır ürün";
  }
  if(f?.tur==="magaza")
   return stok(f.id).reduce((n,x)=>n+num(x.adet),0)+" adet mağaza stoğu · Sanal müşteri satışı";
  return f?.tur?"Faaliyet: "+f.tur:"Ortaklık / şirket yönetimi";
 }
 async function sirketPortfoyEkrani(){
  yukleniyor("Şirketlerim");
  await yenile();
  if(V.hata){
   iskelet("Şirketlerim",box("Şirketler yüklenemedi",'<p class="alt">'+guvenli(V.hata)+'</p>',
    btn("Yeniden dene","sirketYonetimEkrani()")), {geri:true});
   return;
  }
  const sir=V.sirketler.slice().sort((a,b)=>{
   const aT=etkin(a.id)?.tur,bT=etkin(b.id)?.tur;
   const rank=t=>t==="fabrika"?0:t==="magaza"?1:2;
   return rank(aT)-rank(bT)||num(b.pay)-num(a.pay)||num(a.id)-num(b.id);
  });
  let html=stil()+'<div class="kart"><h2>🏢 Şirket portföyüm</h2>'+
    '<p class="alt">Şirketlerin burada listelenir. Birine dokunarak üretimini, stoklarını, ticaretini veya ortaklığını yönet.</p>'+
    satir("Ortak olduğum şirket",sir.length+" şirket")+
    '<div class="so-buttons">'+btn("↻ Şirketleri ve stokları yenile","sirketYonetimEkrani()",true)+
    btn("Şirket kur · Sermaye / ortaklık işlemleri","ekranAc(sirketEskiYonetimEkrani)",true)+'</div></div>';
  if(V.ticaretHata)html+=box("Üretim verileri yüklenemedi",'<p class="alt">'+guvenli(V.ticaretHata)+'</p>');
  if(!sir.length)html+=box("Henüz şirket bulunamadı","<p>İlk şirketini kurarak başlayabilirsin.</p>",
   btn("Şirket kur","ekranAc(sirketEskiYonetimEkrani)"));
  for(const s of sir){
   const f=etkin(s.id),id=okId(s.id);
   const body='<div class="so-muted">'+guvenli(tip(f)||s.sektor)+
    ' · Ortaklık payı %'+guvenli(s.pay)+'</div>'+
    satir("Şirket kasası",para(s.kasa))+
    satir("Sermaye",para(s.sermaye))+
    '<div class="so-sec">'+guvenli(V.ticaretHata?"Üretim kayıtları yüklenemedi":kisaDurum(f))+'</div>';
   html+=box(s.ad,body,btn("Şirketin detaylarını aç","ekranAc(function(){sirketPortfoyDetay("+id+")})"));
  }
  html+='<div class="kart">'+btn("Şirket kur / Finansal yönetim","ekranAc(sirketEskiYonetimEkrani)",true)+
   btn("Üretim ve Ticaret","ekranAc(function(){ticaretMerkezEkrani()})",true)+'</div>';
  iskelet("Şirketlerim",html,{geri:true});
 }
 async function sirketPortfoyDetay(id){
  id=okId(id);yukleniyor("Şirket detayları");
  await yenile();
  const s=firma(id),f=etkin(id);
  if(!s){iskelet("Şirket detayları",box("Şirket bulunamadı","<p>Şirket sahibi veya ortaklığı değişmiş olabilir.</p>"),{geri:true});return;}
  let h=stil()+'<div class="kart so-detail"><h2>'+guvenli(s.ad)+'</h2>'+
   '<div class="so-muted">'+guvenli(tip(f)||s.sektor)+' · %'+guvenli(s.pay)+' pay</div>'+
   satir("Şirket kasası",para(s.kasa))+satir("Sermaye",para(s.sermaye))+
   '<div class="so-buttons">'+btn("↻ Güncelle","sirketPortfoyDetay("+id+")",true)+
   btn("Sermaye / hisseler / finans işlemleri","ekranAc(sirketEskiYonetimEkrani)",true)+'</div></div>';
  if(V.ticaretHata)h+=box("Üretim bilgisi yüklenemedi",'<p class="alt">'+guvenli(V.ticaretHata)+'</p>');
  if(f?.tur==="fabrika"&&f.yonetici){
   const em=emirler(id).slice().sort((a,b)=>num(b.id)-num(a.id));
   const ss=stok(id);
   h+='<div class="kart"><h2>🏭 Üretim takibi</h2><p class="alt">Her emrin bitiş saati aşağıda. Süre dolduktan sonra ürünlerin hazır stoğa aktarılması en geç bir sonraki periyodik işlemde gerçekleşir.</p>'+
    btn("Yeni üretim emri ver","sirketPortfoyUret("+id+")")+'</div>';
   if(!em.length)h+=box("Henüz üretim emri yok","<p class='alt'>Üretimi başlatınca burada siparişin durumunu görebilirsin.</p>");
   for(const q of em){
    const p=urun(q.urun);
    h+=box((p?.ad||q.urun)+" · "+num(q.adet)+" adet",
     satir("Durum",emirDurum(q))+satir("Planlanan bitiş",tarih(q.hazir))+
     satir("Üretim maliyeti",para(q.maliyet)));
   }
   h+='<div class="kart"><h2>📦 Satışa hazır fabrika stokları</h2>'+
    '<p class="alt">Üretim tamamlanıp stoğa geçince burada görünür. Diğer oyuncuların mağazaları da alabilir. Kendi marketine satarsan tutar market kasasından fabrika kasasına geçer.</p></div>';
   if(!ss.length)h+=box("Hazır ürün yok","<p class='alt'>Tamamlanan ürünler burada listelenecek.</p>");
   for(const x of ss){
    const code=String(x.urun||"");if(!/^[a-z0-9_]+$/.test(code))continue;
    const shops=magaza();
    h+=box(urun(code)?.ad||code,
      satir("Hazır stok",num(x.adet)+" adet")+satir("Toptan birim fiyat",para(x.fiyat)),
      (shops.length?btn("Kendi marketime toptan sat","sirketToptanAlModal("+id+",'"+code+"',0)"): "")+
      btn("Toptan fiyatı değiştir","sirketPortfoyFiyat("+id+",'"+code+"')",true));
   }
  } else if(f?.tur==="magaza"&&f.yonetici){
   const ss=stok(id),sales=(V.ticaret?.satislar||[]).filter(x=>num(x.sirket)===id);
   h+='<div class="kart"><h2>🛒 Mağaza ve satış</h2>'+
    '<p class="alt">Oyuncu fabrikalarından ürün satın al. Satın aldıkların mağazaya gelir; sanal müşteriler düzenli satış yaptıkça kasa gelir kazanır.</p>'+
    btn("Toptan ürün satın al","sirketPortfoyTedarik("+id+")")+'</div>';
   if(!ss.length)h+=box("Mağazada stok yok","<p class='alt'>Aşağıdaki tedarikçilerden ürün satın alabilirsin.</p>");
   for(const x of ss)h+=box(urun(x.urun)?.ad||x.urun,
     satir("Stok",num(x.adet)+" adet")+satir("Raf fiyatı",para(x.fiyat)));
   h+='<div class="kart"><h2>🏭 Oyuncu fabrikalarının satış stokları</h2></div>';
   const supplies=tedarik().filter(x=>num(x.sirket)!==id&&num(x.adet)>0);
   if(!supplies.length)h+=box("Hazır toptan stok yok","<p class='alt'>Fabrikalar üretimi tamamladıktan sonra burada satış açılır.</p>");
   for(const x of supplies){
    const code=String(x.urun||"");if(!/^[a-z0-9_]+$/.test(code))continue;
    h+=box((urun(code)?.ad||code)+" · "+x.ad,
      satir("Satılık miktar",num(x.adet)+" adet")+satir("Toptan fiyat",para(x.fiyat)),
      btn("Bu ürünü mağazama al","sirketToptanAlModal("+okId(x.sirket)+",'"+code+"',"+id+")"));
   }
   h+='<div class="kart"><h2>📊 Son müşteri satışları</h2></div>';
   if(!sales.length)h+=box("Henüz satış yok","<p class='alt'>Sanal müşteriler ancak hazır stok oluştuktan sonra satın alabilir.</p>");
   for(const x of sales.slice(0,12))h+=box((urun(x.urun)?.ad||x.urun)+" · "+num(x.adet)+" adet",
    satir("Zaman",tarih(x.zaman))+satir("Ciro",para(x.ciro))+satir("Net kâr",para(x.kar)));
  } else if(f?.tur==="fabrika"||f?.tur==="magaza") {
    h+=box("Ortaklık görünümü","<p class='alt'>İşlemleri şirketi yönetme yetkisi olan ortak yapabilir.</p>");
  } else {
    h+=box("Şirketin diğer işlemleri",
     "<p class='alt'>Bu şirketin üretim ve market faaliyeti yok. Finans, ortaklık ve ilgili sektör işlemleri şirket yönetiminde bulunur.</p>",
     btn("Şirket yönetimine git","ekranAc(sirketEskiYonetimEkrani)",true));
  }
  iskelet("Şirket detayları",h,{geri:true});
 }
 async function sirketPortfoyUret(id){
  if(typeof window.ticaretMerkezEkrani!=="function"||typeof window.tcProduce!=="function"){
   toast("Üretim modülü henüz yüklenmedi; sayfayı yenileyip tekrar dene.",true);return;
  }
  let ilk=true;
  ekranAc(async function(){
   try{
    await window.ticaretMerkezEkrani("uretim");
    if(ilk){ilk=false;window.tcProduce(id);}
   }catch(err){toast(String(err.message||err),true);}
  });
 }
 async function sirketPortfoyTedarik(id){
  if(typeof window.ticaretMerkezEkrani!=="function"||typeof window.tcWholesale!=="function"){
   toast("Ticaret ekranını açmak için sayfayı yenileyip tekrar dene.",true);return;
  }
  let ilk=true;
  ekranAc(async function(){
   try{
    await window.ticaretMerkezEkrani("magaza");
    if(ilk){ilk=false;window.tcWholesale(id);}
   }catch(err){toast(String(err.message||err),true);}
  });
 }
 function sirketToptanAlModal(supplier,code,buyer){
  supplier=okId(supplier);buyer=okId(buyer);code=String(code||"");
  const offer=tedarik().find(x=>num(x.sirket)===supplier&&x.urun===code);
  const options=magaza().filter(x=>!buyer||num(x.id)===buyer);
  if(!offer||!num(offer.adet)){toast("Hazır satılık stok bulunamadı. Verileri yenile.",true);return;}
  if(!options.length){toast("Satın alabileceğin mağazan bulunamadı.",true);return;}
  const max=Math.min(500,num(offer.adet));
  const modalEl=modal('<h3>Toptan ürün satın al</h3>'+
   '<p class="alt">'+guvenli(urun(code)?.ad||code)+" · "+guvenli(offer.ad)+
   " · "+max+" adede kadar · Birim "+para(offer.fiyat)+'</p>'+
   '<div class="alan"><label>Alıcı mağazan</label><select id="soBuyer">'+
   options.map(x=>'<option value="'+okId(x.id)+'">'+guvenli(x.ad)+" · "+para(x.kasa)+'</option>').join("")+
   '</select></div><div class="alan"><label>Adet</label><input id="soAdet" type="number" inputmode="numeric" min="1" max="'+max+'" value="'+Math.min(20,max)+'"></div>'+
   '<p id="soTutar" class="alt"></p><button class="btn altin" id="soBuy">Toptan satın al</button>'+
   '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  const qty=modalEl.querySelector("#soAdet"),bid=modalEl.querySelector("#soBuyer");
  const summary=()=>{
   const amount=Number(qty.value)||0;
   const b=options.find(x=>num(x.id)===num(bid.value));
   modalEl.querySelector("#soTutar").textContent="Toplam "+para(num(offer.fiyat)*amount)+
    " · Alıcı mağaza kasası "+para(b?.kasa||0);
  };
  qty.oninput=summary;bid.onchange=summary;summary();
  modalEl.querySelector("#soBuy").onclick=async function(){
   const adet=Number(qty.value),shop=okId(bid.value),b=options.find(x=>num(x.id)===shop);
   if(!Number.isSafeInteger(adet)||adet<1||adet>max){toast("Satın alma adedi geçersiz.",true);return;}
   if(!b||shop===supplier){toast("Geçerli alıcı mağaza seç.",true);return;}
   if(num(b.kasa)<num(offer.fiyat)*adet){toast("Market kasası bu alım için yetersiz.",true);return;}
   if(!await onayla("Toptan alımı onayla",
    adet+" adet "+(urun(code)?.ad||code)+" için "+para(num(offer.fiyat)*adet)+
    " mağaza kasasından fabrika kasasına aktarılacak.","Satın al"))return;
   this.disabled=true;
   try{
    await API.rpc("eko_ticaret_islem",{p_eylem:"toptan",
      p_veri:{sirket:shop,hedef:supplier,urun:code,adet:adet}});
    modalKapat();toast("Toptan alım tamamlandı. Ürünler mağaza stoğuna eklendi.");
    await sirketPortfoyDetay(shop);
   }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);}
   finally{this.disabled=false;}
  };
 }
 function sirketPortfoyFiyat(id,code){
  id=okId(id);code=String(code||"");
  const x=stok(id).find(z=>z.urun===code);
  if(!x||!etkin(id)?.yonetici)return toast("Fiyat değiştirilebilecek stok yok.",true);
  const m=modal('<h3>Toptan satış fiyatı</h3><p class="alt">'+guvenli(urun(code)?.ad||code)+'</p>'+
    '<div class="alan"><label>Birim fiyat (₺)</label><input id="soPrice" type="number" inputmode="numeric" min="1" value="'+num(x.fiyat)+'"></div>'+
    '<button class="btn altin" id="soPriceSave">Fiyatı kaydet</button>'+
    '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  m.querySelector("#soPriceSave").onclick=async function(){
   const value=Number(m.querySelector("#soPrice").value);
   if(!Number.isSafeInteger(value)||value<=0)return toast("Geçerli fiyat yaz.",true);
   this.disabled=true;
   try{
    await API.rpc("eko_ticaret_islem",{p_eylem:"fiyat",
     p_veri:{sirket:id,urun:code,tutar:value}});
    modalKapat();toast("Toptan fiyat değiştirildi.");
    await sirketPortfoyDetay(id);
   }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message),true);}
   finally{this.disabled=false;}
  };
 }
 window.sirketPortfoyDetay=sirketPortfoyDetay;
 window.sirketToptanAlModal=sirketToptanAlModal;
 window.sirketPortfoyUret=sirketPortfoyUret;
 window.sirketPortfoyTedarik=sirketPortfoyTedarik;
 window.sirketPortfoyFiyat=sirketPortfoyFiyat;
 window.sirketYonetimEkrani=sirketPortfoyEkrani;
})();
