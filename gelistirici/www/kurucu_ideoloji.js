/* Parti kuruluşu, kurucu davetleri ve ideoloji oylamaları — 2026-10-09 */
"use strict";
const IDEOLOJI_SECENEK = [
  ["merkez_sag","Merkez sağ"],["merkez_sol","Merkez sol"],
  ["sosyal_demokrat","Sosyal demokrat"],["muhafazakar","Muhafazakâr"],
  ["liberal","Liberal"],["milliyetci","Milliyetçi"],
  ["turk_milliyetcisi","Türk milliyetçisi"],["sosyalist","Sosyalist"],
  ["kemalist","Kemalist"],["islamci","İslamcı"],
  ["demokratik_sol","Demokratik sol"],["yesil_siyaset","Yeşil siyaset"],
  ["populist","Popülist"],["karma","Karma ideoloji"]
];
const ideolojiAdi = (kod) => (IDEOLOJI_SECENEK.find(([k])=>k===kod)||[kod,kod])[1];
const ideolojiYaz = (liste) => (liste || []).map(ideolojiAdi).join(" · ") || "Henüz belirlenmedi";
function ideolojiSecimHtml(liste=[],id="ideolojiSec"){
  return '<div class="alan"><label>İdeolojiler (en az 1, en fazla 3)</label>'+
    '<div id="'+id+'" class="ideoloji-izgara">'+IDEOLOJI_SECENEK.map(([kod,ad])=>
      '<button type="button" class="ideoloji-kutu'+(liste.includes(kod)?' secili':'')+'" data-ideo="'+kod+'" aria-pressed="'+liste.includes(kod)+'">'+e(ad)+'</button>').join('')+'</div>'+
    '<p class="kucuk">Parti kimliğini belirleyen 1–3 ideoloji seç.</p></div>';
}
function ideolojiSecimBagla(kok){
  const yer=kok.querySelector(".ideoloji-izgara");
  if(!yer) return ()=>[];
  yer.onclick=ev=>{
    const b=ev.target.closest("button[data-ideo]");if(!b)return;
    if(!b.classList.contains("secili")&&yer.querySelectorAll("button.secili").length>=3){
      toast("En fazla 3 ideoloji seçebilirsin.",true);return;
    }
    b.classList.toggle("secili");
    b.setAttribute("aria-pressed",b.classList.contains("secili")?"true":"false");
  };
  return ()=>[...yer.querySelectorAll("button.secili")].map(b=>b.dataset.ideo);
}
async function kurucuDavetModal(){
  let data;
  try{data=await API.rpc("kurucu_davetlerim");}
  catch(err){toast(hataCevir(err.message),true);return;}
  const gelen=data.gelen||[],b=data.basvurum;
  const m=modal('<h3>Kurucular kurulu</h3><p class="alt">Parti kurmak için başvuran kişinin dışında en az üç ayrı oyuncunun EVET onayı gerekir. Davetliler kabul ederse parti kuruluşunda üye olurlar.</p>'+
    (b?'<div class="kart"><h3>'+e(b.ad)+' · '+e(b.kisa)+'</h3><p class="alt">Kurucu onayı: <b>'+b.onay+'/3</b> · Son: '+e(tarihSaat(b.bit))+'</p>'+
      '<p class="kucuk">'+e(ideolojiYaz(b.ideolojiler))+'</p>'+
      (b.davetler||[]).map(d=>'<div class="kv"><span>'+e(d.kad)+'</span><b>'+e({evet:"Kabul",hayir:"Ret",bekliyor:"Bekliyor"}[d.durum]||d.durum)+'</b></div>').join('')+
      '<button class="btn altin" id="kurucularTamamla" '+(b.onay<3?'disabled':'')+'>Onayları tamamla ve partiyi kur</button>'+
      '<button class="btn ikinci" id="kurucuIptal">Başvuruyu iptal et</button></div>':'')+
    (gelen.length?'<h3>Bana gelen davetler</h3>'+gelen.map(d=>
      '<div class="kart"><b>'+e(d.ad)+' ('+e(d.kisa)+')</b><div class="alt">Seni '+e(d.kurucu)+' kurucular kuruluna çağırıyor.</div>'+
      '<div class="kucuk">İdeolojiler: '+e(ideolojiYaz(d.ideolojiler))+' · Son: '+e(tarihSaat(d.bit))+'</div>'+
      '<div class="satir"><button class="btn altin" data-davet="'+d.id+'" data-yanit="evet">Kabul et</button>'+
      '<button class="btn ikinci" data-davet="'+d.id+'" data-yanit="hayir">Reddet</button></div></div>').join(''):'')+
    (!b&&!gelen.length?'<p class="alt">Bekleyen kurucu başvurusu veya davetin yok.</p>':'')+
    '<button class="btn ikinci" id="kurucuKapat">Kapat</button>');
  m.querySelector("#kurucuKapat").onclick=()=>modalKapat();
  m.querySelectorAll("button[data-davet]").forEach(x=>x.onclick=async()=>{
    x.disabled=true;
    try{
      await API.rpc("kurucu_davet_yanit",{p_basvuru:+x.dataset.davet,p_kabul:x.dataset.yanit==="evet"});
      toast(x.dataset.yanit==="evet"?"Daveti kabul ettin.":"Daveti reddettin.");
      kurucuDavetModal();
    }catch(err){x.disabled=false;toast(hataCevir(err.message),true);}
  });
  if(b){
    m.querySelector("#kurucularTamamla").onclick=async()=>{
      const btn=m.querySelector("#kurucularTamamla");btn.disabled=true;
      try{
        await API.rpc("parti_kur_tamamla",{p_basvuru:b.id});
        modalKapat();toast("Kurucular kuruluyla partin resmen kuruldu.");
        D.yigin=[];D.sekme="parti";await durumYenile();partilerEkrani();
      }catch(err){btn.disabled=false;toast(hataCevir(err.message),true);}
    };
    m.querySelector("#kurucuIptal").onclick=async()=>{
      if(!await onayla("Başvuruyu iptal et","Kurucu davetleri geçersiz olur. Henüz kuruluş ücreti kesilmedi.","Başvuruyu iptal et",true))return;
      try{await API.rpc("parti_kur_iptal",{p_basvuru:b.id});toast("Başvuru iptal edildi.");kurucuDavetModal();}
      catch(err){toast(hataCevir(err.message),true);}
    };
  }
}
async function ideolojiOylamaModal(pid){
  let d;try{d=await API.rpc("ideoloji_durum",{p_parti:pid});}catch(err){toast(hataCevir(err.message),true);return;}
  const t=d.teklif;
  const gb=!!(D.durum?.profil?.gb && D.durum.profil.parti?.id===pid);
  const canVote=t&&t.durum==="acik"&&t.oy_hakkim&&t.benim_oyum==null&&new Date(t.bit).getTime()>simdi();
  const m=modal('<h3>Parti ideolojileri</h3><p class="alt">Mevcut: '+e(ideolojiYaz(d.ideolojiler))+'</p>'+
    (t?'<div class="kart"><b>Son ideoloji teklifi</b><p class="alt">'+e(ideolojiYaz(t.ideolojiler))+'</p>'+
      '<div class="kucuk">Durum: '+e({acik:"Oylamada",kabul:"Kabul",red:"Reddedildi"}[t.durum]||t.durum)+
      ' · EVET '+t.evet+' · HAYIR '+t.hayir+' · Kabul için '+t.gerekli+' EVET gerekli</div>'+
      (canVote?'<div class="satir"><button class="btn altin" data-ideoloji-oy="evet">Evet</button><button class="btn ikinci" data-ideoloji-oy="hayir">Hayır</button></div>':'')+'</div>':'')+
    (gb&&(!t||t.durum!=="acik"||new Date(t.bit).getTime()<=simdi())?
      '<h3>Üyelere yeni ideoloji öner</h3><p class="alt">Teklif 48 saat oylamada kalır. Onay için teklif açıldığı andaki bütün üyelerin yarısından fazlasının EVET oyu gerekir.</p>'+
      ideolojiSecimHtml(d.ideolojiler,"ideolojiOySec")+'<button class="btn altin" id="ideolojiTeklif">Oylamaya sun</button>':'')+
    '<button class="btn ikinci" id="ideolojiKapat">Kapat</button>');
  const secilen=ideolojiSecimBagla(m);
  m.querySelector("#ideolojiKapat").onclick=()=>modalKapat();
  m.querySelectorAll("[data-ideoloji-oy]").forEach(b=>b.onclick=async()=>{
    b.disabled=true;try{
      const r=await API.rpc("ideoloji_oyla",{p_teklif:t.id,p_evet:b.dataset.ideolojiOy==="evet"});
      toast(r.durum==="kabul"?"Çoğunluk onayladı. İdeolojiler değişti.":"Oyun kaydedildi.");
      ideolojiOylamaModal(pid);partiKimlikKartCiz(pid);
    }catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
  });
  const teklif=m.querySelector("#ideolojiTeklif");
  if(teklif)teklif.onclick=async()=>{
    const sec=secilen();if(sec.length<1||sec.length>3){toast("1–3 ideoloji seç.",true);return;}
    teklif.disabled=true;
    try{await API.rpc("ideoloji_teklif_ver",{p_ideolojiler:sec});
      toast("Üyelere ideoloji değişikliği oylaması gönderildi.");ideolojiOylamaModal(pid);
    }catch(err){teklif.disabled=false;toast(hataCevir(err.message),true);}
  };
}

/* Eski doğrudan parti kurma ekranının yerine kurucu onaylı akış. */
function partiKurEkrani(){
  const ozelKurucu=!!(D.durum&&D.durum.profil&&(D.durum.profil.kad||"").toLocaleLowerCase("tr")==="eyetkin");
  let renk=RENKLER[6],amb=VERI.amblem[0].id;
  iskelet("Parti kur",
    '<div class="kart" id="onizleme"></div>'+
    '<div class="kart">'+
    '<div class="alan"><label>Parti adı (5–40 karakter)</label><input id="ad" maxlength="40" placeholder="Örn. Yarın Partisi"></div>'+
    '<div class="alan"><label>Kısa ad (2–6 harf)</label><input id="kisa" maxlength="6" placeholder="Örn. YP" style="text-transform:uppercase"></div>'+
    '<div class="alan"><label>Renk</label><div class="renkler">'+RENKLER.map(r=>'<button data-r="'+r+'" style="background:'+r+'"></button>').join("")+'</div></div>'+
    '<div class="alan"><label>Amblem</label><div class="amblemler">'+VERI.amblem.map(a=>'<button data-a="'+a.id+'" title="'+e(a.ad)+'">'+amblemSvg(a.id,"#fff")+'</button>').join("")+'</div></div>'+
    ideolojiSecimHtml([],"kurulusIdeoloji")+
    (ozelKurucu
      ? '<p class="alt">Bu hesaba özel: 3 kurucu üye bulmadan ve kuruluş ücreti ödemeden partini hemen kurabilirsin.</p>'
      : '<div class="alan"><label for="kurucuNick">Kurucu adayı oyuncu adları (en az 3)</label>'+
        '<textarea id="kurucuNick" class="alanmetin" rows="4" placeholder="Her satıra bir kullanıcı adı yaz"></textarea></div>'+
        '<p class="alt">Oyunculara kurucular kurulu daveti gönderilir. Kurucu dışında en az 3 kişi EVET demedikçe parti kurulmaz. Onay verenler kuruluş tamamlandığında yeni partiye katılır.</p>')+
    '<p class="kucuk" id="kurUcret">Kuruluş sermayesi hesaplanıyor…</p>'+
    '<div class="hata-metin" id="hata"></div>'+
    '<button class="btn altin" id="kur">'+(ozelKurucu?'Partiyi hemen kur':'Kurucu davetlerini gönder')+'</button>'+
    (ozelKurucu?'':'<button class="btn ikinci" id="kurDavetGor">Kurucu davetlerini gör</button>')+'</div>',
    {geri:true,sekmesiz:true});
  const secilen=ideolojiSecimBagla(document);
  if(ozelKurucu){
    $("#kurUcret").innerHTML='<b>Kuruluş ücreti: 0 ₺</b> · 3 kurucu üye şartı bu hesaba uygulanmaz.';
  }else{
    API.rpc("vatandaslik").then(v=>{
      const pk=v.parti_kurma,el=$("#kurUcret");if(!el||!pk)return;
      el.innerHTML='<b>Gerekli sermaye: '+tlYaz(Math.max(25000,pk.ucret||0))+'</b> · Cüzdandaki: '+tlYaz(pk.para||0)+
        '. Başvuru ücretsizdir; sermaye yalnızca kuruluş tamamlandığında alınır.';
    }).catch(()=>{});
  }
  const ciz=()=>{
    const ad=$("#ad").value||"Parti adı",kisa=($("#kisa").value||"KISA").toLocaleUpperCase("tr");
    $("#onizleme").innerHTML='<div style="display:flex;gap:12px;align-items:center">'+amblemKutu({renk,amblem:amb},56)+
      '<div><b style="font-size:18px">'+e(ad)+'</b><div style="color:'+renk+';font-weight:800">'+e(kisa)+'</div></div></div>';
    document.querySelectorAll(".renkler button").forEach(b=>b.classList.toggle("secili",b.dataset.r===renk));
    document.querySelectorAll(".amblemler button").forEach(b=>{b.classList.toggle("secili",b.dataset.a===amb);b.querySelector("svg").style.color=renk;});
  };
  document.querySelectorAll(".renkler button").forEach(b=>b.onclick=()=>{renk=b.dataset.r;ciz();});
  document.querySelectorAll(".amblemler button").forEach(b=>b.onclick=()=>{amb=b.dataset.a;ciz();});
  $("#ad").oninput=ciz;$("#kisa").oninput=ciz;ciz();
  if(!ozelKurucu) $("#kurDavetGor").onclick=()=>kurucuDavetModal();
  $("#kur").onclick=async()=>{
    const ideolojiler=secilen(),nickler=ozelKurucu?[]:$("#kurucuNick").value.split(/[\n,]+/).map(x=>x.trim()).filter(Boolean);
    if(ideolojiler.length<1||ideolojiler.length>3){$("#hata").textContent="En az 1 en fazla 3 ideoloji seç.";return;}
    if(!ozelKurucu&&new Set(nickler.map(x=>x.toLocaleLowerCase("tr"))).size<3){
      $("#hata").textContent="Kendinden başka en az üç farklı oyuncunun kullanıcı adını yaz.";return;
    }
    $("#hata").textContent="";$("#kur").disabled=true;
    try{
      if(ozelKurucu){
        await API.rpc("eyetkin_parti_kur",{
          p_ad:$("#ad").value,p_kisa:$("#kisa").value.toLocaleUpperCase("tr"),
          p_renk:renk,p_amblem:amb,p_ideolojiler:ideolojiler
        });
        toast("Partin kuruldu. Kurucu daveti ve ücret gerekmiyor.");
        await durumYenile();
        sekmeAc("parti");
      }else{
        await API.rpc("parti_kur_baslat",{
          p_ad:$("#ad").value,p_kisa:$("#kisa").value.toLocaleUpperCase("tr"),
          p_renk:renk,p_amblem:amb,p_ideolojiler:ideolojiler,p_kadlar:nickler
        });
        toast("Kurucu adaylarına bildirim gönderildi. En az üç kabul bekleniyor.");
        sekmeAc("parti");kurucuDavetModal();
      }
    }catch(err){$("#hata").textContent=hataCevir(err.message);$("#kur").disabled=false;}
  };
}
// Eski sürümün parti kurma fonksiyonunun bu ekranı ezmesini önle.
window.partiKurEkrani = partiKurEkrani;
