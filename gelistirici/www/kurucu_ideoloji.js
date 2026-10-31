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
  /* 31.10.2026: ekip partisi — kurucular kurulu oyuncu sayısıyla büyür, kuruluş fonu birlikte toplanır (151_uzun_soluklu_ekonomi.sql) */
  const gelen=data.gelen||[],b=data.basvurum,onaylar=data.onayladiklarim||[],k=data.kurallar||{};
  const kurul=(b&&b.kurucu_kurulu)||k.kurucu_kurulu||4,gerek=(b&&b.gerekli!=null)?b.gerekli:Math.max(3,kurul-1);
  const fon=(b&&b.fon)||k.fon||0,harc=(b&&b.harc)||k.harc||0,minK=k.katki_min||10000;
  const davetSayisi=b?(b.davetler||[]).length:0,kalanDavet=Math.max(0,50-davetSayisi);
  const cubuk=(v,top)=>{const y=top>0?Math.max(0,Math.min(100,100*v/top)):0;
    return '<div style="height:8px;border-radius:5px;background:rgba(255,255,255,.08);overflow:hidden;margin:6px 0 4px"><i style="display:block;height:100%;width:'+y+'%;border-radius:5px;background:linear-gradient(90deg,#e8cf8f,#b8913f)"></i></div>';};
  const katkiAlan=(id,bid,kalan)=>'<div class="alan"><label for="'+id+'">Kuruluş fonuna katkı (₺)</label>'+
    '<input id="'+id+'" type="number" inputmode="numeric" min="'+Math.min(minK,kalan)+'" max="'+kalan+'" step="1000" placeholder="En az '+tlYaz(Math.min(minK,kalan))+'"></div>'+
    '<button class="btn ikinci" data-katki="'+id+'" data-basvuru="'+bid+'">Katkı yap</button>'+
    '<p class="kucuk">Fonda eksik: '+tlYaz(kalan)+'. Parti kurulmazsa ya da onayını geri çekersen katkın cüzdanına iade edilir.</p>';
  const durumAd={evet:"Onayladı",hayir:"Ret / geri çekti",bekliyor:"Bekliyor"};
  let html='<h3>Kurucular kurulu</h3><p class="alt">Parti kurmak ekip işidir: sen dahil en az <b>'+kurul+'</b> kişilik kurucular kurulu, <b>'+tlYaz(harc)+'</b> harç ve <b>'+tlYaz(fon)+
    '</b> kuruluş fonu gerekir. Fon partinin kasasına geçer; kurucular birlikte toplar. Kurucu üyeler en az "'+e(k.ortak_statu||"Vatandaş")+'" statüsünde ve '+(k.ortak_hesap_gun||7)+
    ' günlük hesaba sahip olmalı; aynı cihazdaki hesaplar ve son 30 günde başka partiyi kuranlar sayılmaz.</p>';
  if(b){
    const toplanan=b.toplanan||0,kalan=Math.max(0,fon-toplanan),yeter=b.onay>=gerek;
    html+='<div class="kart"><h3>'+e(b.ad)+' · '+e(b.kisa)+'</h3>'+
      '<p class="alt">Kurucu onayı: <b>'+b.onay+'/'+gerek+'</b> · Son: '+e(tarihSaat(b.bit))+'</p>'+cubuk(b.onay,gerek)+
      '<p class="alt">Kuruluş fonu: <b>'+tlYaz(toplanan)+' / '+tlYaz(fon)+'</b>'+(b.kurucu_katki>0?' · senin katkın '+tlYaz(b.kurucu_katki):'')+'</p>'+cubuk(toplanan,fon)+
      '<p class="kucuk">'+e(ideolojiYaz(b.ideolojiler))+'</p>'+
      (b.davetler||[]).map(d=>'<div class="kv"><span>'+e(d.kad)+(d.katki>0?' · '+tlYaz(d.katki):'')+
        (d.engel?'<br><small style="color:#ffb3b8">Sayılmaz: '+e(d.engel)+'</small>':'')+'</span><b>'+e(durumAd[d.durum]||d.durum)+'</b></div>').join('')+
      (kalan>0?katkiAlan('kurucuKatkiBen',b.id,kalan):'<p class="kucuk">Kuruluş fonu tamamlandı.</p>')+
      (kalanDavet>0?'<div class="alan"><label for="kurucuYeniNick">Yeni kurucu adayları ekle</label>'+
        '<textarea id="kurucuYeniNick" class="alanmetin" rows="3" placeholder="Her satıra bir kullanıcı adı yaz"></textarea>'+
        '<p class="kucuk">Başvurunu iptal etmeden yeni kişilere davet gönderebilirsin. Kalan davet hakkı: '+kalanDavet+'</p></div>'+
        '<div class="hata-metin" id="kurucuEkleHata"></div><button class="btn ikinci" id="kurucuEkle">Yeni davetleri gönder</button>':
        '<p class="kucuk">50 kurucu daveti sınırına ulaştın.</p>')+
      '<p class="kucuk">Kuruluşta cüzdanından '+tlYaz(harc)+' harç'+(kalan>0?' ve fonun eksik kalan '+tlYaz(kalan)+'’si':'')+' alınır.</p>'+
      '<button class="btn altin" id="kurucularTamamla" '+(yeter?'':'disabled')+'>'+(yeter?'Partiyi kur':'Partiyi kur ('+(gerek-b.onay)+' onay daha gerekli)')+'</button>'+
      '<button class="btn ikinci" id="kurucuIptal">Başvuruyu iptal et</button></div>';
  }
  if(onaylar.length) html+='<h3>Kurucu üyesi olduğum başvurular</h3>'+onaylar.map(o=>{
    const of=o.fon||fon,ot=o.toplanan||0,kalan=Math.max(0,of-ot);
    return '<div class="kart"><b>'+e(o.ad)+' ('+e(o.kisa)+')</b><div class="alt">Başvuran: '+e(o.kurucu)+' · onay '+o.onay+'/'+o.gerekli+' · Son: '+e(tarihSaat(o.bit))+'</div>'+
      cubuk(ot,of)+'<div class="kucuk">Kuruluş fonu: '+tlYaz(ot)+' / '+tlYaz(of)+(o.katki>0?' · senin katkın '+tlYaz(o.katki):'')+'</div>'+
      (kalan>0?katkiAlan('kurucuKatki'+o.id,o.id,kalan):'')+
      '<button class="btn ikinci" data-davet="'+o.id+'" data-yanit="hayir" data-geri="1">Onayımı geri çek</button></div>';}).join('');
  if(gelen.length) html+='<h3>Bana gelen davetler</h3>'+gelen.map(d=>
    '<div class="kart"><b>'+e(d.ad)+' ('+e(d.kisa)+')</b><div class="alt">Seni '+e(d.kurucu)+' kurucular kuruluna çağırıyor · onay '+(d.onay||0)+'/'+(d.gerekli||gerek)+'</div>'+
    '<div class="kucuk">İdeolojiler: '+e(ideolojiYaz(d.ideolojiler))+' · Son: '+e(tarihSaat(d.bit))+'</div>'+
    (d.engel?'<p class="kucuk" style="color:#ffb3b8">Şu an kurucu üye olamazsın: '+e(d.engel)+'</p>':'')+
    '<div class="satir"><button class="btn altin" data-davet="'+d.id+'" data-yanit="evet"'+(d.engel?' disabled':'')+'>Kabul et</button>'+
    '<button class="btn ikinci" data-davet="'+d.id+'" data-yanit="hayir">Reddet</button></div></div>').join('');
  if(!b&&!gelen.length&&!onaylar.length) html+='<p class="alt">Bekleyen kurucu başvurusu veya davetin yok.</p>';
  html+='<button class="btn ikinci" id="kurucuKapat">Kapat</button>';
  const m=modal(html);
  m.querySelector("#kurucuKapat").onclick=()=>modalKapat();
  m.querySelectorAll("button[data-davet]").forEach(x=>x.onclick=async()=>{
    if(x.dataset.geri&&!await onayla("Onayını geri çek","Kurucular kurulundan çıkarsın; kuruluş fonuna katkın varsa cüzdanına iade edilir.","Onayımı geri çek",true))return;
    x.disabled=true;
    try{
      await API.rpc("kurucu_davet_yanit",{p_basvuru:+x.dataset.davet,p_kabul:x.dataset.yanit==="evet"});
      toast(x.dataset.geri?"Onayını geri çektin.":x.dataset.yanit==="evet"?"Daveti kabul ettin. Dilersen kuruluş fonuna katkı yapabilirsin.":"Daveti reddettin.");
      kurucuDavetModal();
    }catch(err){x.disabled=false;toast(hataCevir(err.message),true);}
  });
  m.querySelectorAll("button[data-katki]").forEach(x=>x.onclick=async()=>{
    const inp=m.querySelector("#"+x.dataset.katki),tutar=Math.round(Number(inp&&inp.value||0));
    if(!tutar||tutar<=0){toast("Katkı tutarını yaz.",true);return;}
    x.disabled=true;
    try{
      const r=await API.rpc("kurucu_katki",{p_basvuru:+x.dataset.basvuru,p_tutar:tutar});
      toast(tlYaz(r.katki)+" katkı yapıldı. Fonda toplanan: "+tlYaz(r.toplanan)+" / "+tlYaz(r.fon)+".");
      try{await durumYenile();}catch(_){}
      kurucuDavetModal();
    }catch(err){x.disabled=false;toast(hataCevir(err.message),true);}
  });
  if(b){
    const ekle=m.querySelector("#kurucuEkle");
    if(ekle)ekle.onclick=async()=>{
      const nickler=m.querySelector("#kurucuYeniNick").value.split(/[\n,]+/).map(x=>x.trim()).filter(Boolean);
      const hata=m.querySelector("#kurucuEkleHata");
      if(!nickler.length){hata.textContent="Davet edilecek en az bir kullanıcı adı yaz.";return;}
      if(nickler.length>kalanDavet){hata.textContent="En fazla "+kalanDavet+" yeni kişi davet edebilirsin.";return;}
      if(new Set(nickler.map(x=>x.toLocaleLowerCase("tr"))).size!==nickler.length){hata.textContent="Aynı kullanıcı adını iki kez yazma.";return;}
      hata.textContent="";ekle.disabled=true;
      try{
        const sonuc=await API.rpc("kurucu_davet_ekle",{p_basvuru:b.id,p_kadlar:nickler});
        toast(sonuc.eklenen+" yeni kurucu daveti gönderildi.");
        kurucuDavetModal();
      }catch(err){ekle.disabled=false;hata.textContent=hataCevir(err.message);}
    };
    m.querySelector("#kurucularTamamla").onclick=async()=>{
      const btn=m.querySelector("#kurucularTamamla");
      const kalan=Math.max(0,fon-(b.toplanan||0));
      if(!await onayla("Partiyi kur",tlYaz(harc)+" harç"+(kalan>0?" ve fonun eksik kalan "+tlYaz(kalan)+"’si":"")+" cüzdanından alınacak. Kuruluş fonu partinin kasasına geçer.","Partiyi kur"))return;
      btn.disabled=true;
      try{
        await API.rpc("parti_kur_tamamla",{p_basvuru:b.id});
        modalKapat();toast("Kurucular kuruluyla partin resmen kuruldu.");
        D.yigin=[];D.sekme="parti";await durumYenile();partilerEkrani();
      }catch(err){btn.disabled=false;toast(hataCevir(err.message),true);}
    };
    m.querySelector("#kurucuIptal").onclick=async()=>{
      if(!await onayla("Başvuruyu iptal et","Kurucu davetleri geçersiz olur; kuruluş fonundaki bütün katkılar sahiplerine iade edilir.","Başvuruyu iptal et",true))return;
      try{await API.rpc("parti_kur_iptal",{p_basvuru:b.id});toast("Başvuru iptal edildi; katkılar iade edildi.");kurucuDavetModal();}
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
  const serbestAd=!!(D.durum&&D.durum.profil&&(D.durum.profil.kad||"").toLocaleLowerCase("tr")==="matestappen");
  const ozelKurucu=!!(D.durum&&D.durum.profil&&["eyetkin","celal","matestappen"].includes((D.durum.profil.kad||"").toLocaleLowerCase("tr")));
  let renk=RENKLER[6],amb=VERI.amblem[0].id,gerekliDavet=6;
  iskelet("Parti kur",
    '<div class="kart" id="onizleme"></div>'+
    '<div class="kart">'+
    '<div class="alan"><label>Parti adı ('+(serbestAd?'1–80 karakter, serbest':'5–40 karakter')+')</label><input id="ad" maxlength="'+(serbestAd?'80':'40')+'" placeholder="Örn. Yarın Partisi"></div>'+
    '<div class="alan"><label>Kısa ad (2–6 harf)</label><input id="kisa" maxlength="6" placeholder="Örn. YP" style="text-transform:uppercase"></div>'+
    '<div class="alan"><label>Renk</label><div class="renkler">'+RENKLER.map(r=>'<button data-r="'+r+'" style="background:'+r+'"></button>').join("")+'</div></div>'+
    '<div class="alan"><label>Amblem</label><div class="amblemler">'+VERI.amblem.map(a=>'<button data-a="'+a.id+'" title="'+e(a.ad)+'">'+amblemSvg(a.id,"#fff")+'</button>').join("")+'</div></div>'+
    ideolojiSecimHtml([],"kurulusIdeoloji")+
    (ozelKurucu
      ? '<p class="alt">'+(serbestAd?'Bu hesap için parti adı serbest: 1–80 karakter. Mevcut başka partinin adını ya da kısaltmasını kullanamazsın. ':'')+'3 kurucu üye bulmadan ve kuruluş ücreti ödemeden partini hemen kurabilirsin.</p>'
      : '<div class="alan"><label for="kurucuNick" id="kurucuNickEtiket">Kurucu adayı oyuncu adları</label>'+
        '<textarea id="kurucuNick" class="alanmetin" rows="5" placeholder="Her satıra bir kullanıcı adı yaz"></textarea></div>'+
        '<p class="alt" id="kurucuAciklama">Oyunculara kurucular kurulu daveti gönderilir. Yeterli kurucu EVET demedikçe parti kurulmaz. Onay verenler kuruluş tamamlandığında yeni partiye katılır ve kuruluş fonuna katkı yapabilir.</p>')+
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
      if(pk.kurucu)gerekliDavet=Math.max(1,pk.kurucu-1);
      const et=$("#kurucuNickEtiket");if(et)et.textContent="Kurucu adayı oyuncu adları (en az "+gerekliDavet+")";
      const ac=$("#kurucuAciklama");
      if(ac&&pk.kurucu)ac.innerHTML='Kurucular kurulu sen dahil en az <b>'+pk.kurucu+'</b> kişi olmalı. Kurucu üyeler en az "'+e(pk.ortak_statu||"Vatandaş")+'" statüsünde ve '+(pk.ortak_hesap_gun||7)+
        ' günlük hesaba sahip olmalı; aynı cihazdaki hesaplar sayılmaz. Onay verenler kuruluşta yeni partiye katılır ve kuruluş fonuna katkı yapabilir.';
      el.innerHTML=(pk.harc!=null?'<b>Kuruluş: '+tlYaz(pk.harc)+' harç + '+tlYaz(pk.fon)+' kuruluş fonu</b> (fon partinin kasasına geçer, kurucular birlikte toplar)':'<b>Gerekli sermaye: '+tlYaz(Math.max(25000,pk.ucret||0))+'</b>')+
        ' · Cüzdandaki: '+tlYaz(pk.para||0)+'. Başvuru ücretsizdir; tutarlar yalnızca kuruluş tamamlandığında alınır.'+
        (pk.engel?'<br><span style="color:#ffb3b8">'+e(pk.engel)+'</span>':'');
      if(pk.engel){const kb=$("#kur");if(kb)kb.disabled=true;}
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
    if(!ozelKurucu&&new Set(nickler.map(x=>x.toLocaleLowerCase("tr"))).size<gerekliDavet){
      $("#hata").textContent="Kendinden başka en az "+gerekliDavet+" farklı oyuncunun kullanıcı adını yaz.";return;
    }
    $("#hata").textContent="";$("#kur").disabled=true;
    try{
      if(ozelKurucu){
        await API.rpc(serbestAd?"matestappen_parti_kur":"eyetkin_parti_kur",{
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
        toast("Kurucu adaylarına bildirim gönderildi. En az "+gerekliDavet+" kabul bekleniyor.");
        sekmeAc("parti");kurucuDavetModal();
      }
    }catch(err){$("#hata").textContent=hataCevir(err.message);$("#kur").disabled=false;}
  };
}
// Eski sürümün parti kurma fonksiyonunun bu ekranı ezmesini önle.
window.partiKurEkrani = partiKurEkrani;
