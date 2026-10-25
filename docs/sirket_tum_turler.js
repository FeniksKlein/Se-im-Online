/* Tum sirketlerin tek merkezden kurulmasi ve faaliyet yonetimi. */
(function(){
"use strict";
if(window.TUM_SIRKETLER_AKTIF)return;
window.TUM_SIRKETLER_AKTIF=true;
const safe=s=>typeof e==="function"?e(String(s??"")):String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const cash=x=>(Math.round(Number(x)||0)).toLocaleString("tr-TR")+" ₺";
const GROUPS=[
 ["tarim","🌾 Tarım / Gıda üretimi","kur_fabrika","factory"],
 ["sanayi","🏭 Sanayi / Fabrika","kur_fabrika","factory"],
 ["teknoloji","💻 Teknoloji üretimi","kur_fabrika","factory"],
 ["ticaret","🛒 Market","kur_magaza","retail"],
 ["fastfood","🍔 Fast food","kur_magaza","retail"],
 ["kahve","☕ Kahveci","kur_magaza","retail"],
 ["insaat","🏗️ Müteahhitlik","kur_insaat","build"],
 ["sigorta","🛡️ Sigorta şirketi","kur_sigorta","insurance"],
 ["medya","📰 Medya şirketi","kur_sirket","legacy"],
 ["ajans","📣 Reklam ve anket ajansı","kur_sirket","agency"],
 ["banka","🏦 Banka","none","legacy"],
 ["pazar:market","🏬 Market zinciri (haftalık pazar)","kur_pazar","service"],
 ["pazar:enerji","⚡ Enerji santrali","kur_pazar","service"],
 ["pazar:ozel_hastane","🏥 Özel hastane","kur_pazar","service"],
 ["pazar:ozel_okul","🎓 Özel okul","kur_pazar","service"],
 ["pazar:ulasim","🚌 Ulaşım firması","kur_pazar","service"],
 ["pazar:turizm","🏨 Turizm ve otelcilik","kur_pazar","service"],
 ["pazar:lojistik","📦 Kargo ve lojistik","kur_pazar","service"],
 ["pazar:oto_servis","🔧 Oto servis ve bakım","kur_pazar","service"],
 ["pazar:danismanlik","📋 Danışmanlık ofisi","kur_pazar","service"],
 ["pazar:e_ticaret","🛍️ E-ticaret şirketi","kur_pazar","service"],
 ["pazar:akaryakit","⛽ Akaryakıt istasyonu","kur_pazar","service"],
 ["pazar:yapi_market","🧱 Yapı market","kur_pazar","service"],
 ["pazar:elektronik_magaza","📱 Elektronik mağazası","kur_pazar","service"],
 ["pazar:tekstil_magaza","👕 Giyim mağazası","kur_pazar","service"],
 ["pazar:mobilya_magaza","🛋️ Mobilya mağazası","kur_pazar","service"],
 ["pazar:oto_galeri","🚗 İkinci el oto galeri","kur_pazar","service"],
 ["pazar:geri_donusum","♻️ Geri dönüşüm tesisi","kur_pazar","service"]
];
async function sirketTumTurKur(onayli){
  let permits,market;
  try{[permits,market]=await Promise.all([API.rpc("bel_ruhsat_merkezi"),API.rpc("pazar_katalog")]);}
  catch(err){toast("Şirket türleri ve ruhsatlar yüklenemedi: "+String(err.message||err),true);return;}
  const minMap=Object.fromEntries((market.sektorler||[]).map(x=>["pazar:"+x.kod,Number(x.min_sermaye)||100000]));
  const home=Number(market.benim_il)||1;
  const allCities=Array.isArray(permits.iller)?permits.iller:[];
  const cityList=allCities.length?allCities.map(x=>'<option value="'+Number(x.id)+'">'+safe(x.ad)+'</option>').join(""):
    '<option value="'+home+'">Kayıtlı il (#'+home+')</option>';
  const m=modal(
   '<h3>🏢 Sıfırdan bağımsız şirket kur</h3>'+
   '<p class="alt">Bu ekrandan mevcut şirketlerinden tamamen bağımsız, yeni bir şirket kurarsın. Yeni şirketin ayrı kasası, ayrı şirket numarası ve başlangıçta %100 sana ait ortaklık payı olur. Başka şirketine şube veya ortaklık olarak bağlanmaz.</p>'+
   '<div class="alan"><label>Şirket türü</label><select id="stkType">'+GROUPS.map(x=>'<option value="'+x[0]+'">'+x[1]+'</option>').join("")+'</select></div>'+
   '<div class="alan"><label>Şirket adı</label><input id="stkName" maxlength="50" placeholder="3–50 karakter"></div>'+
   '<div class="alan"><label>Faaliyet ili</label><select id="stkCity">'+cityList+'</select></div>'+
   '<div class="alan"><label>Kuruluş sermayesi (₺)</label><input id="stkMoney" type="number" inputmode="numeric" min="100000" max="100000000" value="250000"></div>'+
   '<div class="alan" id="stkProdBox"><label>Fabrika üretim grubu</label><select id="stkProd"><option value="gida">Gıda</option><option value="teknoloji">Teknoloji</option><option value="malzeme">İnşaat malzemeleri</option></select></div>'+
   '<div class="alan" id="stkEnergyBox" style="display:none"><label>Enerji kaynağı</label><select id="stkEnergy"><option value="yenilenebilir">Yenilenebilir</option><option value="dogalgaz">Doğalgaz</option><option value="komur">Kömür</option></select></div>'+
   '<div class="kart" style="margin-top:12px"><p id="stkDescription" class="alt"></p><p id="stkPermit" class="alt"></p></div>'+
   '<button class="btn ikinci" id="stkLicense">🏛️ Ruhsat ve harç bilgileri</button>'+
   '<button class="btn altin" id="stkCreate">Şirketi kur</button>'+
   '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>'
  );
  // Find the visible sheet even if a modal implementation returns no wrapper.
  const root=m&&typeof m.querySelector==="function"?m:document.getElementById("modal");
  const el=id=>root?.querySelector?.("#"+id)||document.getElementById(id);
  const type=el("stkType"),city=el("stkCity"),name=el("stkName");
  if(!type||!city||!name||!el("stkCreate")||!el("stkLicense")){
    toast("Şirket kuruluş formu açılamadı. Sayfayı yenileyip tekrar dene.",true);return;
  }
  city.value=String(onayli?.il||home);
  if(onayli?.tur)type.value=String(onayli.tur);
  if(onayli?.ad)name.value=String(onayli.ad);
  if(onayli?.sermaye)el("stkMoney").value=String(onayli.sermaye);
  const current=()=>GROUPS.find(x=>x[0]===type.value)||GROUPS[0];
  const permission=(info)=>{
    if(info[2]==="none")return true;
    return (permits.benim||[]).some(p=>p.sirket_id==null&&p.tur===info[2]&&p.durum==="onay"&&
      String(p.sirket||"").trim()===name.value.trim()&&Number(p.il_id)===Number(city.value)&&
      (!p.karar_zamani||Date.now()-new Date(p.karar_zamani).getTime()<72*3600000)&&
      (info[3]!=="service"||!p.sektor||p.sektor===info[0].split(":")[1])&&
      (info[2]!=="kur_sirket"||!p.sektor||p.sektor===info[0]));
  };
  function update(){
    const info=current(),sektor=info[0],category=info[3];
    const min=sektor==="banka"?1000000:sektor==="ajans"?150000:(minMap[sektor]||100000);
    el("stkMoney").min=String(min);
    if(Number(el("stkMoney").value)<min)el("stkMoney").value=String(min);
    el("stkProdBox").style.display=category==="factory"?"":"none";
    el("stkEnergyBox").style.display=sektor==="pazar:enerji"?"":"none";
    if(sektor==="tarim")el("stkProd").value="gida";
    if(sektor==="teknoloji")el("stkProd").value="teknoloji";
    const how=["akaryakit","yapi_market","elektronik_magaza","tekstil_magaza","mobilya_magaza","oto_galeri"].includes(sektor)?"Önce şirket kasasından toptan stok al; fiyat belirle, NPC müşterilere yalnızca gerçek stoktan sat. Stok bitince satış durur, bakım gideri sürer.":category==="factory"?"Üretim emri ver → süreyi izle → ürün stoğuna geçsin → oyuncu mağazalarına toptan sat.":
      category==="retail"?"Stok satın al veya mutfakta üret → müşteri talebine göre saatlik satış yap → ciro, vergi, gider ve kârı izle.":
      category==="build"?"Arsa al, belediye izniyle inşaat yap, tamamlanan konutları ve dükkânları sat.":
      category==="insurance"?"Poliçe primi, hasar rezervi, tazminat ve şirket kârı.":
      category==="service"?"Günlük hizmet geliri, personel, vergi ve diğer giderler; fiyat, kalite ve rakiplerle değişir. Kâr garanti değildir, zarar da oluşabilir.":
      category==="agency"?"Oyunculara reklam kampanyası ve kamuoyu anketi satar; fiyat ve çalışan kapasitesini yönet.":
      sektor==="banka"?"Mevduat, kredi, faiz, banka kasası ve finans işlemleri.":
      "Sözleşmeler, ortaklıklar ve haftalık faaliyet geliri-gideri.";
    el("stkDescription").textContent=how+" Asgari sermaye: "+cash(min)+".";
    el("stkPermit").textContent=info[2]==="none"?"Banka türü mevcut kuruluş ve finans kurallarına tabidir.":
      permission(info)?"✅ Onaylı belediye ruhsatı bulundu. Kuruluşta harç kesilir.":
      "✅ Şirketi kurduğunda kuruluş ruhsatı sistem tarafından anında onaylanacak. Harç kuruluşta tahsil edilir.";
    el("stkCreate").textContent=category==="factory"?"Fabrikayı kur ve üretimi aç":
      category==="retail"?"Mağazayı kur ve satışa aç":"Şirketi kur ve faaliyete başlat";
  }
  // Bind actions before rendering secondary information so they remain clickable.
  el("stkLicense").onclick=()=>{modalKapat();ekranAc(belRuhsatMerkeziEkrani);};
  el("stkCreate").onclick=async function(){
    const info=current(),sector=info[0],category=info[3],company=name.value.trim(),capital=Number(el("stkMoney").value),
      loc=Number(city.value),min=sector==="banka"?1000000:sector==="ajans"?150000:(minMap[sector]||100000);
    if(company.length<3||company.length>50){toast("Şirket adı 3–50 karakter olmalı.",true);return;}
    if(!Number.isSafeInteger(capital)||capital<min||capital>100000000){toast("Sermaye "+cash(min)+" ile 100.000.000 ₺ arasında tam sayı olmalı.",true);return;}
    if(!Number.isInteger(loc)||loc<1||loc>81){toast("Geçerli bir faaliyet ili seç.",true);return;}
    if(!await onayla("Sıfırdan bağımsız şirket kurulumu",company+" ayrı bir şirket olarak kurulacak; başka hiçbir şirketine bağlanmayacak. "+cash(capital)+" sermaye cüzdanından yatırılacak ve gerekli belediye harcı yeni şirket kasasından kesilecek.","Kur"))return;
    this.disabled=true;
    try{
      // Kurulus ruhsati belediye baskani karari beklemeden verilir.
      // Mevcut gecerli ruhsat varsa tekrar basvuru yapilmaz.
      if(!permission(info)&&info[2]!=="none"){
        const permitSector=info[2]==="kur_pazar"?sector.split(":")[1]:info[2]==="kur_sirket"?sector:null;
        const approval=await API.rpc("bel_ruhsat_basvur",{
          p_tur:info[2],p_il:loc,p_sirket:null,p_hedef:null,
          p_ad:company,p_sektor:permitSector,p_yatirim:capital
        });
        if(approval?.durum!=="onay")throw new Error("Kuruluş ruhsatı otomatik onaylanamadı. Lütfen tekrar dene.");
        if(!Array.isArray(permits.benim))permits.benim=[];
        permits.benim.push({tur:info[2],durum:"onay",sirket_id:null,sirket:company,il_id:loc,
          sektor:permitSector,karar_zamani:new Date().toISOString()});
      }
      let result;
      if(category==="service"){
        result=await API.rpc("pazar_sirket_kur",{p_ad:company,p_sektor:sector.split(":")[1],p_sermaye:capital,
          p_il:loc,p_kaynak:sector==="pazar:enerji"?el("stkEnergy").value:null});
      }else if(category==="agency"){
        result=await API.rpc("ajans_kur_ilde",{p_ad:company,p_sermaye:capital,p_il:loc});
      }else if(category==="factory"&&sector!=="sanayi"){
        result=await API.rpc("sirket_kur_aktif_ilde",{p_ad:company,p_sektor:sector,p_sermaye:capital,
          p_urun:sector==="tarim"?"gida":"teknoloji",p_il:loc});
      }else if(category==="factory"){
        result=await API.rpc("eko_islem",{p_eylem:"kur",p_veri:{tur:"fabrika",ad:company,il:loc,urun:el("stkProd").value,tutar:capital}});
      }else if(category==="retail"||category==="insurance"){
        result=await API.rpc("eko_islem",{p_eylem:"kur",p_veri:{tur:category==="retail"?"magaza":"sigorta",ad:company,il:loc,tutar:capital}});
        if(category==="retail"&&sector!=="ticaret"){
          try{await API.rpc("eko_ticaret_islem",{p_eylem:"magaza_tur",p_veri:{sirket:Number(result.id),
            kategori:sector==="kahve"?"kahve":"fastfood"}});}
          catch(err){toast("Şirket kuruldu; mağaza kategorisini manuel seç: "+String(err.message||err),true);}
        }
      }else if(category==="build"){
        // The database's eko_insaat_sirket_tanit trigger registers the
        // contractor and consumes its auto-approved municipality permit.
        // Do not call eko_islem('kur') here: it would insert a duplicate operator.
        result=await API.rpc("sirket_kur_ilde",{p_ad:company,p_sektor:"insaat",p_sermaye:capital,p_il:loc});
      }else{
        result=await API.rpc("sirket_kur_ilde",{p_ad:company,p_sektor:sector,p_sermaye:capital,p_il:loc});
      }
      if(!Number.isSafeInteger(Number(result?.id)))throw new Error("Kuruluş sonucu şirket numarası alınamadı. Şirketlerimden kontrol et.");
      modalKapat();toast(company+" ayrı bir şirket olarak kuruldu (#"+Number(result.id)+").");
      try{await window.sirketPortfoyDetay(Number(result.id));}
      catch(detailsError){console.error("Yeni şirket detay ekranı:",detailsError);toast("Şirket kuruldu, ancak detay ekranı açılamadı. Şirketlerimden yeni şirketini görebilirsin.",true);if(typeof window.sirketYonetimEkrani==="function")await window.sirketYonetimEkrani();}
    }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);}
    finally{this.disabled=false;}
  };
  type.onchange=update;city.onchange=update;name.oninput=update;
  try{update();}catch(err){
    console.error("Şirket kuruluş görünümü:",err);
    toast("Şirket ayrıntıları yüklenemedi; kuruluş düğmeleri kullanılabilir.",true);
  }
}
window.sirketTumTurKur=sirketTumTurKur;

window.sirketSehirSubesiAc=function(id){
  id=Number(id);
  if(!Number.isSafeInteger(id)||id<=0)return;
  const iller=(Array.isArray(VERI?.iller)?VERI.iller:[]).slice().sort((a,b)=>a.ad.localeCompare(b.ad,"tr"));
  if(!iller.length){toast("Şehir listesi yüklenmedi. Sayfayı yenileyip tekrar dene.",true);return;}
  const popup=modal('<h3>🏢 Yeni şirket şubesi</h3>'+
    '<p class="alt">Şirketin sektörü ve senin ikamet ilin ne olursa olsun Türkiye\'deki 81 ilden birinde şube açabilirsin. '+
    'Şube açılış bedeli 25.000 ₺ şirket kasasından tahsil edilir. Aynı şehirde ikinci kez şube açılmaz.</p>'+
    '<div class="alan"><label>Şubenin açılacağı il</label><select id="stkBranchCity">'+
    iller.map(x=>'<option value="'+Number(x.id)+'">'+safe(x.ad)+'</option>').join("")+'</select></div>'+
    '<button class="btn altin" id="stkBranchSubmit">Şubeyi aç</button>'+
    '<button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>');
  const root=popup&&typeof popup.querySelector==="function"?popup:document;
  const btn=root.querySelector("#stkBranchSubmit"),select=root.querySelector("#stkBranchCity");
  if(!btn||!select){toast("Şube formu açılamadı.",true);return;}
  btn.onclick=async function(){
    const il=Number(select.value);
    if(!Number.isInteger(il)||il<1||il>81)return;
    if(!await onayla("Şube açılışı","Seçilen ilde şube açmak için şirket kasasından 25.000 ₺ tahsil edilecek.","Aç"))return;
    btn.disabled=true;
    try{
      const r=await API.rpc("sirket_sube_ac_ilde",{p_sirket:id,p_il:il});
      modalKapat();
      toast((r.il||"Seçilen il")+" şubesi açıldı.");
      await window.sirketPortfoyDetay(id);
    }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);}
    finally{btn.disabled=false;}
  };
};


const originalList=window.sirketYonetimEkrani;
if(typeof originalList==="function"){
 window.sirketYonetimEkrani=async function(){
   await originalList();
   const root=document.querySelector(".so-buttons");
   if(!root||root.querySelector(".stk-primary"))return;
   root.insertAdjacentHTML("afterbegin",'<button class="btn altin stk-primary" onclick="sirketTumTurKur()">➕ Her tür şirket kur</button>'+
    '<button class="btn ikinci" onclick="ekranAc(belRuhsatMerkeziEkrani)">🏛️ Belediye ruhsatlarını yönet</button>'+
    '<button class="btn altin" onclick="sirketAlimSatimEkrani()">🏢 Şirket alım-satım pazarı</button>');
 };
}

const originalDetail=window.sirketPortfoyDetay;
if(typeof originalDetail==="function"){
 window.sirketPortfoyDetay=async function(id){
   await originalDetail(id);
   const base=document.querySelector(".so-detail");
   if(!base)return;
   try{
     const d=await API.rpc("sirket_liste"),s=(d.sirketler||[]).find(x=>Number(x.id)===Number(id));
     if(!s||document.querySelector(".stk-sector-details"))return;
     let html="",description="";
     const sid=Number(id),sector=String(s.sektor||"");
     if(["akaryakit","yapi_market","elektronik_magaza","tekstil_magaza","mobilya_magaza","oto_galeri"].includes(sector)){
       description='<p class="alt">Bu işletmede piyasa fiyatıyla stok alırsın, ürün başına fiyat belirler, gün içinde NPC müşterilere gerçek stoktan satış yaparsın. Sermayeden otomatik ikinci gelir yaratılmaz. Şirketin giderleri, satışları ve vergileri kayıt altındadır.</p>';
       html='<button class="btn altin" onclick="npcIsletmeEkrani('+sid+')">📦 Stok · NPC müşterileri · Fiyatlandırma</button>';
     }else if(["ozel_okul","ozel_hastane","ulasim","enerji","market","turizm","lojistik","oto_servis","danismanlik","e_ticaret","geri_donusum"].includes(sector)){
       const labels={ozel_okul:"Öğrenci kayıtları ve eğitim hizmetleri",ozel_hastane:"Hasta hizmetleri ve sağlık satışı",
         ulasim:"Yolcu ve sefer gelirleri",enerji:"Enerji üretimi ve satış",market:"Market zinciri satışları",
         turizm:"Konaklama ve turizm hizmetleri",lojistik:"Kargo, depo ve taşımacılık hizmetleri",
         oto_servis:"Araç bakım ve onarım hizmetleri",danismanlik:"Müşteri danışmanlığı ve ofis hizmetleri",
         e_ticaret:"İnternet mağazası ve uzaktan satış",geri_donusum:"Atık toplama ve geri kazanım hizmetleri"};
       const p=s.pazar_tahmin||{};
       description='<p class="alt">'+safe(labels[sector])+': rekabet, kapasite, personel, kalite ve talep haftalık faaliyet sonuçlarını belirler.</p>'+
         '<div class="kv"><span>Tahmini haftalık ciro</span><b>'+cash(p.gelir)+'</b></div>'+
         '<div class="kv"><span>Tahmini haftalık gider</span><b>'+cash(p.gider)+'</b></div>';
       html='<button class="btn altin" onclick="ekranAc(()=>pazarDetayEkrani('+sid+'))">Üretim / hizmet, satış, fiyat ve kapasiteyi yönet</button>';
     }else if(sector==="insaat"){
       description='<p class="alt">Arsa ve inşaat aşamaları, onaylanan ruhsatlar, projeler ve tamamlanan mülk satışları.</p>';
       html='<button class="btn altin" onclick="ekranAc(arsaEkrani)">Arsa · İnşaat · Konut satışı</button>';
     }else if(sector==="banka"){
       description='<p class="alt">Banka mevduatı, kredi ürünleri, faizler, müşteri işlemleri ve banka kasası.</p>';
       html='<button class="btn altin" onclick="ekranAc(oyuncuBankaEkrani)">Bankacılık işlemlerini aç</button>';
     }else if(sector==="ajans"){
       description='<p class="alt">Oyuncu partilerine ve adaylara reklam ve anket hizmetleri sat; kampanya, fiyat, iş kapasitesi ve geliri yönet.</p>';
       html='<button class="btn altin" onclick="ekranAc(()=>ajansYonetimEkrani('+sid+'))">Reklam ve anket siparişlerini yönet</button>';
     }else if(sector==="medya"){
       description='<p class="alt">Reklam ve hizmet sözleşmeleri, giderler, ortaklık ve şirket finansmanı.</p>';
       html='<button class="btn altin" onclick="ekranAc(isDunyasiEkrani)">Sözleşme ve hizmet satışları</button>';
     }else if(sector==="ticaret"){
       description='<p class="alt">Mağaza stok ve satışları veya sigorta poliçeleri için iş dünyası faaliyet merkezi.</p>';
       html='<button class="btn altin" onclick="ekranAc(isDunyasiEkrani)">İşletme ve satış işlemlerini yönet</button>';
     }else{
       description='<p class="alt">Üretim, stok, toptan satış, ortaklık, sermaye ve mali işlemler kendi yönetim ekranlarından yapılır.</p>';
       html='<button class="btn altin" onclick="ekranAc(()=>ticaretMerkezEkrani())">Üretim / stok / satış</button>';
     }
     const panel=document.createElement("section");panel.className="kart stk-sector-details";
     panel.innerHTML='<h3>⚙️ Sektörel faaliyet ve satış</h3>'+description+html+
       '<button class="btn ikinci" onclick="ekranAc(sirketEskiYonetimEkrani)">Şirket finansmanı ve ortaklıklar</button>';
     base.insertAdjacentElement("afterend",panel);

     // The headquarters and branch registry is common to all company types.
     // Locations are informational for existing enterprises; new branches
     // charge the company treasury and are validated by the database.
     try {
       const places=await API.rpc("sirket_yerleri",{p_sirket:sid});
       const out=document.createElement("section");
       out.className="kart stk-branch-locations";
       const head=places.merkez||{},branches=places.subeler||[];
       const rows=branches.length?branches.map(b=>
         '<div class="kv"><span>🏢 Şube #'+Number(b.id)+'</span><b>'+safe(b.il||"İl #"+b.il_id)+'</b></div>'
       ).join(""):'<p class="alt">Henüz şube açılmamış.</p>';
       out.innerHTML='<h3>📍 Şirket merkezi ve şubeler</h3>'+
         '<div class="kv"><span>Şirket merkezi</span><b>'+safe(head.il||"İl #"+head.il_id)+'</b></div>'+
         rows+(places.yonetici?
         '<button class="btn altin" onclick="sirketSehirSubesiAc('+sid+')">🏢 İstediğin ilde şube aç · '+cash(places.acilis_bedeli)+'</button>':'');
       panel.insertAdjacentElement("afterend",out);
     }catch(err){
       console.warn("Şirket şube bilgileri yüklenemedi:",err);
     }

   }catch(err){
     const p=document.createElement("section");p.className="kart stk-sector-details";
     p.textContent="Faaliyet özeti alınamadı: "+String(err.message||err);
     base.insertAdjacentElement("afterend",p);
   }
 };
}
})();

/* Belediye ekonomisi, stoklu NPC isletmeleri ve vergili sirket pazari. */
(function(){
 if(document.getElementById("npc-isletmeler-modulu"))return;
 const sc=document.createElement("script");sc.id="npc-isletmeler-modulu";
 sc.src="npc_isletmeler.js?v=20261025-2";sc.async=false;
 document.body.appendChild(sc);
})();
