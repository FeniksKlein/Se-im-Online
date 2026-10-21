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
   '<h3>🏢 Tüm şirketleri kur</h3>'+
   '<p class="alt">Şirket türünü seç; belediye ruhsatı, sermaye ve faaliyet alanına göre gerçek şirket kurulsun. Fabrikalarda üretim ve toptan satış; mağazalarda stok ve sanal müşteri satışları; hizmetlerde günlük gelir-gider hesabı kullanılır.</p>'+
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
  const el=id=>m.querySelector("#"+id),type=el("stkType"),city=el("stkCity"),name=el("stkName");
  city.value=String(onayli?.il||home);
  if(onayli?.tur)type.value=String(onayli.tur);
  if(onayli?.ad)name.value=String(onayli.ad);
  if(onayli?.sermaye)el("stkMoney").value=String(onayli.sermaye);
  const current=()=>GROUPS.find(x=>x[0]===type.value)||GROUPS[0];
  const permission=(info)=>{
    if(info[2]==="none")return true;
    return (permits.benim||[]).some(p=>p.tur===info[2]&&p.durum==="onay"&&
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
    const how=category==="factory"?"Üretim emri ver → süreyi izle → ürün stoğuna geçsin → oyuncu mağazalarına toptan sat.":
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
  type.onchange=update;city.onchange=update;name.oninput=update;update();
  el("stkLicense").onclick=()=>{modalKapat();ekranAc(belRuhsatMerkeziEkrani);};
  el("stkCreate").onclick=async function(){
    const info=current(),sector=info[0],category=info[3],company=name.value.trim(),capital=Number(el("stkMoney").value),
      loc=Number(city.value),min=sector==="banka"?1000000:sector==="ajans"?150000:(minMap[sector]||100000);
    if(company.length<3||company.length>50){toast("Şirket adı 3–50 karakter olmalı.",true);return;}
    if(!Number.isSafeInteger(capital)||capital<min||capital>100000000){toast("Sermaye "+cash(min)+" ile 100.000.000 ₺ arasında tam sayı olmalı.",true);return;}
    if(!Number.isInteger(loc)||loc<1||loc>81){toast("Geçerli bir faaliyet ili seç.",true);return;}
    if(((category==="factory"&&sector!=="sanayi")||sector==="insaat"||sector==="ajans")&&loc!==home){toast("Bu şirket türü kayıtlı ikamet ilinde açılır. Başka şehirde fabrika açmak için sanayi sektörünü seç.",true);return;}
    if(!await onayla("Şirket kuruluşu",company+" için "+cash(capital)+" sermaye cüzdanından yatırılacak ve gerekli belediye harcı şirket kasasından kesilecek.","Kur"))return;
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
        permits.benim.push({tur:info[2],durum:"onay",sirket:company,il_id:loc,
          sektor:permitSector,karar_zamani:new Date().toISOString()});
      }
      let result;
      if(category==="service"){
        result=await API.rpc("pazar_sirket_kur",{p_ad:company,p_sektor:sector.split(":")[1],p_sermaye:capital,
          p_il:loc,p_kaynak:sector==="pazar:enerji"?el("stkEnergy").value:null});
      }else if(category==="agency"){
        result=await API.rpc("ajans_kur",{p_ad:company,p_sermaye:capital});
      }else if(category==="factory"&&sector!=="sanayi"){
        result=await API.rpc("sirket_kur_aktif",{p_ad:company,p_sektor:sector,p_sermaye:capital,
          p_urun:sector==="tarim"?"gida":"teknoloji"});
      }else if(category==="factory"){
        result=await API.rpc("eko_islem",{p_eylem:"kur",p_veri:{tur:"fabrika",ad:company,il:loc,urun:el("stkProd").value,tutar:capital}});
      }else if(category==="retail"||category==="insurance"){
        result=await API.rpc("eko_islem",{p_eylem:"kur",p_veri:{tur:category==="retail"?"magaza":"sigorta",ad:company,il:loc,tutar:capital}});
        if(category==="retail"&&sector!=="ticaret"){
          try{await API.rpc("eko_ticaret_islem",{p_eylem:"magaza_tur",p_veri:{sirket:Number(result.id),
            kategori:sector==="kahve"?"kahve":"fastfood"}});}
          catch(err){toast("Şirket kuruldu; mağaza kategorisini manuel seç: "+String(err.message||err),true);}
        }
      }else{
        result=await API.rpc("sirket_kur",{p_ad:company,p_sektor:sector,p_sermaye:capital});
      }
      if(!Number.isSafeInteger(Number(result?.id)))throw new Error("Kuruluş sonucu şirket numarası alınamadı. Şirketlerimden kontrol et.");
      modalKapat();toast(company+" kuruldu. Şirket faaliyetlerini açıyorum.");
      await window.sirketPortfoyDetay(Number(result.id));
    }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);}
    finally{this.disabled=false;}
  };
}
window.sirketTumTurKur=sirketTumTurKur;

const originalList=window.sirketYonetimEkrani;
if(typeof originalList==="function"){
 window.sirketYonetimEkrani=async function(){
   await originalList();
   const root=document.querySelector(".so-buttons");
   if(!root||root.querySelector(".stk-primary"))return;
   root.insertAdjacentHTML("afterbegin",'<button class="btn altin stk-primary" onclick="sirketTumTurKur()">➕ Her tür şirket kur</button>'+
    '<button class="btn ikinci" onclick="ekranAc(belRuhsatMerkeziEkrani)">🏛️ Belediye ruhsatlarını yönet</button>');
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
     if(["ozel_okul","ozel_hastane","ulasim","enerji","market","turizm","lojistik","oto_servis","danismanlik","e_ticaret","geri_donusum"].includes(sector)){
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
   }catch(err){
     const p=document.createElement("section");p.className="kart stk-sector-details";
     p.textContent="Faaliyet özeti alınamadı: "+String(err.message||err);
     base.insertAdjacentElement("afterend",p);
   }
 };
}
})();
