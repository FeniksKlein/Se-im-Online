/* =====================================================================
   SEÇİM SİMÜLASYONU ONLINE — SİYASİ EKONOMİ ARAYÜZÜ
   2026.10.07-6
   ===================================================================== */
(function(){
  function kartBul(ad){
    return Array.from(document.querySelectorAll("#icerik .kart")).find(function(x){
      var h=x.querySelector("h2"); return h && h.textContent.trim()===ad;
    });
  }
  function modalGovde(){
    return document.querySelector(".modal .modal") || document.querySelector(".modal");
  }
  function yenileMetin(kok){
    if(!kok) return;
    kok.innerHTML=kok.innerHTML
      .replaceAll("İl teşkilat sorumlusu ata / görevi kaldır","Parti İl Başkanı ata / görevi kaldır")
      .replaceAll("İl teşkilat sorumlusu ata","Parti İl Başkanı ata")
      .replaceAll("İl Teşkilat Sorumlusu:","Parti İl Başkanı:")
      .replaceAll("Sorumlunun kullanıcı adı","İl başkanının kullanıcı adı")
      .replaceAll("Mevcut sorumlu:","Mevcut il başkanı:")
      .replaceAll("Bu ilde sorumlu yok.","Bu ilde parti il başkanı yok.")
      .replaceAll("atanmış il sorumlusu","atanmış Parti İl Başkanı");
  }

  window.partiAdModal = async function(pid){
    var p; try { p=await API.rpc("parti_detay",{p_parti:pid}); } catch(err){ return toast(hataCevir(err.message),true); }
    var h='<h3 style="font-size:19px;font-weight:800">Parti adını değiştir</h3>'
      +'<p class="alt">Parti adını ve kısa adını yalnızca genel başkan değiştirebilir. Değişiklik bütün üyelere bildirilir ve 7 gün boyunca tekrar değiştirilemez.</p>'
      +'<div class="alan"><label>Parti adı</label><input id="sePad" maxlength="40" value="'+e(p.ad)+'"></div>'
      +'<div class="alan"><label>Kısa ad</label><input id="sePkisa" maxlength="6" value="'+e(p.kisa)+'" style="text-transform:uppercase"></div>'
      +'<div class="hata-metin" id="sePah"></div>'
      +'<button class="btn altin" id="sePaok">Adı değiştir</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>';
    var m=modal(h);
    $("#sePaok",m).onclick=async function(){
      var b=$("#sePaok",m); b.disabled=true; $("#sePah",m).textContent="";
      try{
        await API.rpc("parti_ad_degistir",{p_ad:$("#sePad",m).value,p_kisa:$("#sePkisa",m).value.toLocaleUpperCase("tr")});
        modalKapat(); await durumYenile(); toast("Partinin adı değiştirildi."); partiDetay(pid);
      }catch(err){ b.disabled=false; $("#sePah",m).textContent=hataCevir(err.message); }
    };
  };

  window.partiTuzukModal = async function(pid){
    var t; try { t=await API.rpc("parti_tuzuk",{p_parti:pid}); } catch(err){ return toast(hataCevir(err.message),true); }
    var a=t.aktif, h='<h3 style="font-size:19px;font-weight:800">Parti tüzüğü</h3>';
    if(t.mevcut){
      h+='<div class="kart" style="margin:8px 0;background:var(--panel2)"><div class="kucuk">YÜRÜRLÜKTEKİ TÜZÜK'
        +(t.mevcut_at?' · '+tarih(t.mevcut_at):'')+'</div><div style="white-space:pre-wrap;margin-top:6px">'+e(t.mevcut)+'</div></div>';
    }else h+='<p class="alt">Partinin henüz üyelerin kabul ettiği bir tüzüğü yok.</p>';
    if(a){
      h+='<div class="olay oy"><div class="baslik"><b>'+e(a.baslik)+'</b><span class="rozet kirmizi">Üye oylaması</span></div>'
        +'<div class="kucuk" style="margin-top:5px">'+a.katilim+' / '+a.uye_sayisi+' üye oy kullandı · bitiş '+tarihSaat(a.bit)+'</div>'
        +'<div class="sayac" data-an="'+new Date(a.bit).getTime()+'">'+kalan(new Date(a.bit).getTime()-simdi())+'</div>'
        +'<div style="white-space:pre-wrap;margin-top:8px;font-size:14px">'+e(a.metin)+'</div>';
      if(a.uygun){
        h+='<div class="oybtn" style="margin-top:10px"><button class="'+(a.benim_oy==="evet"?"sec-kabul":"")+'" id="seTEvet">Evet</button>'
          +'<button class="'+(a.benim_oy==="hayir"?"sec-ret":"")+'" id="seTHayir">Hayır</button></div>';
      }else h+='<p class="kucuk">Oylama açıldığında parti üyesi olmadığın için bu oylamada oy hakkın yok.</p>';
      h+='</div>';
    }
    if(t.gb_mi && !a) h+='<button class="btn altin" id="seTTeklif">Yeni tüzüğü üyelerin oyuna sun</button>';
    if(t.gecmis && t.gecmis.length){
      h+='<div class="kart" style="margin:10px 0 0;background:var(--panel2)"><h2>Geçmiş oylamalar</h2>';
      t.gecmis.forEach(function(x){
        h+='<div class="kv"><span class="k">'+e(x.baslik)+'<div class="kucuk">'+(x.sonuc_at?tarihSaat(x.sonuc_at):'')+'</div></span>'
          +'<span class="v '+(x.durum==="kabul"?"iyi":"kotu")+'">'+(x.durum==="kabul"?"Kabul":"Ret")+' · '+x.evet+'-'+x.hayir+'</span></div>';
      });
      h+='</div>';
    }
    h+='<button class="btn ikinci" onclick="modalKapat()">Kapat</button>';
    var m=modal(h);
    if(a && a.uygun){
      $("#seTEvet",m).onclick=async function(){ try{ await API.rpc("parti_tuzuk_oyla",{p_teklif:a.id,p_oy:"evet"}); modalKapat(); toast("Evet oyun kaydedildi."); partiTuzukModal(pid); }catch(err){ toast(hataCevir(err.message),true); } };
      $("#seTHayir",m).onclick=async function(){ try{ await API.rpc("parti_tuzuk_oyla",{p_teklif:a.id,p_oy:"hayir"}); modalKapat(); toast("Hayır oyun kaydedildi."); partiTuzukModal(pid); }catch(err){ toast(hataCevir(err.message),true); } };
    }
    var tt=$("#seTTeklif",m); if(tt) tt.onclick=function(){ modalKapat(); partiTuzukTeklifModal(pid); };
  };

  window.partiTuzukTeklifModal = function(pid){
    var h='<h3 style="font-size:19px;font-weight:800">Yeni parti tüzüğü</h3>'
      +'<p class="alt">Tüzüğü yazıp üyelerin oyuna sunarsın. Oylama 24 saat açık kalır; kullanılan oylarda Evet, Hayırdan fazlaysa kabul edilir.</p>'
      +'<div class="alan"><label>Oylama başlığı</label><input id="seTTbas" maxlength="100" placeholder="Örn. Demokratik Parti Tüzüğü"></div>'
      +'<div class="alan"><label>Tüzük metni</label><textarea class="alanmetin" id="seTTmetin" maxlength="6000" style="min-height:180px" placeholder="Partinin amacı, üyelerin hakları, yönetim ilkeleri, aday belirleme esasları…"></textarea></div>'
      +'<div class="hata-metin" id="seTThata"></div>'
      +'<button class="btn altin" id="seTTok">24 saatlik oylamayı başlat</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>';
    var m=modal(h);
    $("#seTTok",m).onclick=async function(){
      var b=$("#seTTok",m); b.disabled=true; $("#seTThata",m).textContent="";
      try{
        await API.rpc("parti_tuzuk_teklif",{p_baslik:$("#seTTbas",m).value,p_metin:$("#seTTmetin",m).value});
        modalKapat(); toast("Tüzük üyelerin oyuna sunuldu."); partiTuzukModal(pid);
      }catch(err){ b.disabled=false; $("#seTThata",m).textContent=hataCevir(err.message); }
    };
  };

  var eskiPartiDetay=window.partiDetay;
  window.partiDetay=async function(id){
    await eskiPartiDetay(id);
    try{
      var p=await API.rpc("parti_detay",{p_parti:id}), yon=kartBul("Yönetim");
      if(yon && !yon.querySelector("#seTuzukBtn")){
        var b=document.createElement("button"); b.className="btn ikinci"; b.id="seTuzukBtn"; b.textContent="Parti tüzüğü ve oylamalar"; b.onclick=function(){ partiTuzukModal(id); }; yon.appendChild(b);
        if(p.gb && D.durum && D.durum.profil && p.gb===D.durum.profil.kad){
          var a=document.createElement("button"); a.className="btn ikinci"; a.textContent="Parti adını değiştir"; a.onclick=function(){ partiAdModal(id); }; yon.insertBefore(a,b);
        }
      }
      (p.uyeler||[]).filter(function(u){return u.il_baskani;}).forEach(function(u){
        Array.from(document.querySelectorAll("#icerik .liste-satir b")).forEach(function(el){
          if(el.textContent.indexOf(u.kad)>=0 && el.textContent.indexOf("İl Başkanı")<0) el.insertAdjacentHTML("beforeend",' <span class="rozet yesil">İl Başkanı</span>');
        });
      });
    }catch(_){}
  };

  var eskiTeskilat=window.teskilatKartCiz;
  window.teskilatKartCiz=async function(pid){
    await eskiTeskilat(pid);
    var el=$("#teskilatKart"); yenileMetin(el);
    if(el && el.querySelector(".kart") && el.textContent.indexOf("milletvekilliğiyle birlikte")<0){
      var n=document.createElement("p"); n.className="kucuk"; n.style.marginTop="8px"; n.innerHTML="<b>Parti İl Başkanlığı milletvekilliğiyle birlikte yürütülebilir.</b>";
      el.querySelector(".kart").appendChild(n);
    }
  };
  var eskiTG=window.teskilatGorevModal;
  window.teskilatGorevModal=function(pid){ eskiTG(pid); setTimeout(function(){ yenileMetin(modalGovde()); },0); };
  var eskiTA=window.teskilatAcModal;
  window.teskilatAcModal=function(pid){ eskiTA(pid); setTimeout(function(){ yenileMetin(modalGovde()); },0); };

  var eskiBankaCiz=window.bankaCiz;
  window.bankaCiz=function(b){
    eskiBankaCiz(b);
    var c=kartBul("Vadesiz hesap");
    if(c){
      Array.from(c.querySelectorAll(".kv")).forEach(function(r){
        var k=r.querySelector(".k"),v=r.querySelector(".v"); if(!k||!v) return;
        if(k.textContent.indexOf("Bugün işleyen faiz")===0){ k.textContent="Saatlik faiz kazancın"; v.classList.add("iyi"); v.textContent="+"+fmt(b.vadesiz.saatlik||0,2)+" ₺/saat"; }
        else if(k.textContent.indexOf("Günlük faiz kazancın")===0){ k.textContent="24 saatlik yaklaşık kazanç"; v.textContent=fmt(b.vadesiz.gunluk||0,2)+" ₺"; }
      });
      var p=c.querySelector("p.kucuk"); if(p) p.innerHTML='İstediğin an yatır, istediğin an çek. Faiz <b>her tamamlanan saatte doğrudan bakiyene eklenir</b>; para hesapta ne kadar durursa o kadar kazandırır.';
    }
    var t=kartBul("Vadeli hesap");
    if(t){
      var a=t.querySelector(".alt"); if(a) a.innerHTML='Parayı belli bir süre bağla, daha yüksek faiz al. Sabit faiz <b>saat saat birikir</b>; vade dolunca anapara ve faiz cüzdanına yatar. Erken bozarsan tamamlanmış saatler için vadesiz faiz alırsın.';
      var acik=(b.vadeliler||[]).filter(function(x){return x.durum==="acik";});
      var kutular=Array.from(t.querySelectorAll(".kart"));
      acik.forEach(function(x,i){
        if(kutular[i] && kutular[i].textContent.indexOf("Şu ana kadar biriken")<0){
          var d=document.createElement("div"); d.className="kucuk iyi"; d.textContent="Şu ana kadar biriken sabit faiz: +"+tlYaz(x.biriken||0)+" · saatlik +"+tlYaz(x.saatlik||0);
          var bt=kutular[i].querySelector("[data-boz]"); if(bt) kutular[i].insertBefore(d,bt); else kutular[i].appendChild(d);
        }
      });
    }
  };

  function afEtkiYaz(r){
    return 'Etkilenen <b>'+r.borclu+'</b> borçlu · silinecek toplam <b>'+tlYaz(r.silinecek)+'</b>'
      +' · hazine <b class="kotu">−'+fmt(r.hazine_maliyet,2)+' milyar ₺</b>'
      +' · enflasyon <b class="kotu">+'+fmt(r.enflasyon,2)+'</b>'
      +' · büyüme <b class="iyi">+'+fmt(r.buyume,2)+'</b>'
      +' · işsizlik <b class="iyi">'+fmt(r.issizlik,2)+'</b>'
      +' · memnuniyet <b class="iyi">+'+fmt(r.memnuniyet,2)+'</b>';
  }
  window.seBorcAffiModal=async function(kaynak){
    var r; try{ r=await API.rpc("borc_affi_onizle",{p_oran:50}); }catch(err){ return toast(hataCevir(err.message),true); }
    var vekil=kaynak==="mv";
    var h='<h3 style="font-size:19px;font-weight:800">'+(vekil?'Borç affı kanunu teklif et':'Cumhurbaşkanlığı borç affı')+'</h3>'
      +'<p class="alt">Aktif banka kredilerinin seçtiğin oranını siler. Oyuncuların borç yükü azalır; büyüme ve memnuniyet artar. Karşılığında hazine maliyeti ve enflasyon baskısı oluşur.</p>'
      +(vekil?'<div class="alan"><label>Kanun başlığı</label><input id="seAfBas" maxlength="120" value="Kredi Borçlarının Affedilmesi Hakkında Kanun"></div>':'')
      +'<div class="alan"><label>Affedilecek oran (%10-%100)</label><input id="seAfOran" type="number" min="10" max="100" step="5" value="50" inputmode="decimal"></div>'
      +'<p class="kucuk" id="seAfEtki">'+afEtkiYaz(r)+'</p>'
      +'<div class="alan"><label>'+(vekil?'Gerekçe':'Açıklama')+'</label><textarea class="alanmetin" id="seAfMetin" maxlength="3000" style="min-height:90px">Kredi borç yükünü azaltarak hane halkının ekonomik hareket alanını genişletmek amacıyla.</textarea></div>'
      +'<div class="hata-metin" id="seAfHata"></div><button class="btn altin" id="seAfOk">'+(vekil?'Meclis Başkanlığına sun':'İmzala ve yayımla')+'</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>';
    var m=modal(h), zaman=null, i=$("#seAfOran",m);
    i.oninput=function(){ clearTimeout(zaman); zaman=setTimeout(async function(){ try{ $("#seAfEtki",m).innerHTML=afEtkiYaz(await API.rpc("borc_affi_onizle",{p_oran:+i.value})); }catch(err){ $("#seAfEtki",m).textContent=hataCevir(err.message); } },250); };
    $("#seAfOk",m).onclick=async function(){
      var b=$("#seAfOk",m); b.disabled=true; $("#seAfHata",m).textContent="";
      try{
        var x=vekil
          ? await API.rpc("ekonomi_kanun_teklif",{p_tur:"borc_affi",p_baslik:$("#seAfBas",m).value,p_metin:$("#seAfMetin",m).value,p_deger:+i.value})
          : await API.rpc("borc_affi_kararname",{p_oran:+i.value,p_metin:$("#seAfMetin",m).value});
        modalKapat();
        if(vekil){ toast("Borç affı teklifin Meclis gündemine alındı."); ekranAc(function(){kanunEkrani(x.id);}); }
        else { toast(x.no+" sayılı borç affı kararı yürürlükte."); devletEkrani(); }
      }catch(err){ b.disabled=false; $("#seAfHata",m).textContent=hataCevir(err.message); }
    };
  };

  window.seVergiKanunModal=async function(){
    var u; try{ u=D._karne||await API.rpc("ulke_karnesi"); }catch(err){ return toast(hataCevir(err.message),true); }
    var h='<h3 style="font-size:19px;font-weight:800">Gelir vergisi kanunu</h3>'
      +'<p class="alt">Vergiyi düşürmek oyuncunun net gelirini ve büyümeyi destekler ama hazine gelirini azaltır. Artırmak bütçeyi güçlendirir; büyüme ve memnuniyeti baskılar.</p>'
      +'<div class="alan"><label>Kanun başlığı</label><input id="seVBas" maxlength="120" value="Gelir Vergisi Oranının Değiştirilmesi Hakkında Kanun"></div>'
      +'<div class="alan"><label>Yeni gelir vergisi (%0-%45) · şu an %'+fmt(u.vergi,1)+'</label><input id="seVOran" type="number" min="0" max="45" step="0.5" value="'+u.vergi+'" inputmode="decimal"></div>'
      +'<p class="kucuk" id="seVEtki"></p>'
      +'<div class="alan"><label>Gerekçe</label><textarea class="alanmetin" id="seVMetin" maxlength="3000" style="min-height:90px">Vergi yükü ile kamu gelirleri arasında yeni bir denge kurulması amacıyla.</textarea></div>'
      +'<div class="hata-metin" id="seVHata"></div><button class="btn altin" id="seVOk">Meclis Başkanlığına sun</button><button class="btn ikinci" onclick="modalKapat()">Vazgeç</button>';
    var m=modal(h),i=$("#seVOran",m),z=null;
    async function yaz(){
      try{
        var r=await API.rpc("politika_onizle",{p_kod:"vergi",p_deger:+i.value});
        $("#seVEtki",m).innerHTML=etkiOzet(r)+(r.oyuncu_net_fark?' · oyuncunun vergi yükü yaklaşık <b class="'+(r.oyuncu_net_fark>0?'iyi':'kotu')+'">'+(r.oyuncu_net_fark>0?'−':'+')+fmt(Math.abs(r.oyuncu_net_fark),1)+' puan</b>':'');
      }catch(err){ $("#seVEtki",m).textContent=hataCevir(err.message); }
    }
    i.oninput=function(){clearTimeout(z);z=setTimeout(yaz,250);}; yaz();
    $("#seVOk",m).onclick=async function(){
      var b=$("#seVOk",m); b.disabled=true; $("#seVHata",m).textContent="";
      try{
        var x=await API.rpc("ekonomi_kanun_teklif",{p_tur:"vergi",p_baslik:$("#seVBas",m).value,p_metin:$("#seVMetin",m).value,p_deger:+i.value});
        modalKapat(); toast("Vergi kanunu teklifin Meclis gündemine alındı."); ekranAc(function(){kanunEkrani(x.id);});
      }catch(err){b.disabled=false;$("#seVHata",m).textContent=hataCevir(err.message);}
    };
  };

  function ekonomiKartEkle(){
    var p=D.durum&&D.durum.profil, host=$("#icerik"); if(!p||!host||$("#seEkonomiKart")) return;
    var mv=(p.makamlar||[]).some(function(x){return x.tur==="mv";}), cb=!!p.cb_mi;
    if(!mv&&!cb) return;
    var d=document.createElement("div"); d.className="kart"; d.id="seEkonomiKart";
    d.innerHTML='<h2>Ekonomi kararları</h2><p class="alt">Borç affı ve vergi kararlarının oyuncuların cüzdanına ve ülke ekonomisine gerçek etkileri vardır.</p>'
      +(cb?'<button class="btn altin" onclick="seBorcAffiModal(\'cb\')">Cumhurbaşkanlığı borç affı</button>':'')
      +(mv?'<button class="btn ikinci" onclick="seBorcAffiModal(\'mv\')">Borç affı kanunu teklif et</button><button class="btn ikinci" onclick="seVergiKanunModal()">Vergi kanunu teklif et</button>':'');
    host.appendChild(d);
  }
  var eskiDevlet=window.devletEkrani;
  window.devletEkrani=async function(){ await eskiDevlet(); ekonomiKartEkle(); };

  var eskiVaat=window.vaatEditor;
  window.vaatEditor=async function(o){
    await eskiVaat(o);
    setTimeout(function(){
      var i=document.querySelector('.secenek[data-kod="borc_affi"] [data-hedef]');
      if(i && (!i.value || i.value==="undefined" || isNaN(+i.value))) i.value="50";
    },0);
  };
})();