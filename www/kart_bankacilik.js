/* Bankacilik ve kredi kartlari: devlet bankasi, oyuncu bankalari, haftalik ekstre, POS.
   Sunucu otoriter: limit, bakiyeler, tahsilat ve kredi riski sadece RPC uzerinden hesaplanir. */
(function(){
 "use strict";
 if(window.BANKACILIK_KART_MODUL)return;
 window.BANKACILIK_KART_MODUL=true;
 var state={panel:null,pos:null}, esc=function(x){return typeof e==="function"?e(String(x==null?"":x)):String(x==null?"":x).replace(/&/g,"&amp;").replace(/</g,"&lt;");};
 var money=function(x){return (Number(x)||0).toLocaleString("tr-TR",{maximumFractionDigits:2})+" ₺";};
 var tarih=function(x){return x?new Date(x).toLocaleString("tr-TR",{dateStyle:"short",timeStyle:"short"}):"—";};
 var btn=function(title,action,secondary){return '<button type="button" class="btn '+(secondary?"ikinci":"altin")+'" onclick="'+action+'">'+title+'</button>';};
 var fld=function(label,v){return '<div class="kv"><span>'+label+'</span><b>'+v+'</b></div>';};
 var card=function(title,body){return '<div class="kart"><h2>'+title+'</h2>'+body+'</div>';};
 var err=function(ex){toast(typeof hataCevir==="function"?hataCevir(ex.message):ex.message,true);};
 function app(title,body){iskelet(title,body,{geri:true});}
 function sec(id){return document.getElementById(id);}
 function asNumber(id){return Number(sec(id)&&sec(id).value||0);}
 function act(promise,cb){Promise.resolve(promise).then(function(result){if(result!==null){toast("İşlem başarılı");if(cb)cb(result);}}).catch(err);}
 window.bankacilikMerkeziEkrani=function(){
  var html=card("🏛️ Devlet bankası","<p class='alt'>Devlet bankası hesabın, kredilerin, mevduat, haftalık kart ve borçların.</p>"+
     btn("Devlet Bankasını Aç","ekranAc(bankaEkrani)")+
     btn("Devlet Bankası Kredi Kartı","ekranAc(kartlarimEkrani)",true));
  html+=card("🏦 Oyuncuların bankaları","<p class='alt'>Oyuncuların kurduğu özel bankaları ve sundukları vadeli hesap/kredi ürünlerini incele. Banka sahibiysen yönetim ekranına gir.</p>"+
     btn("Oyuncu Bankalarını Aç","ekranAc(bankaRehberiEkrani)"));
  html+=card("💳 Kredi Kartlarım","<p class='alt'>Kart limitim, dönem borcum, hesap kesim tarihi, asgari ödeme, tüm hareketler ve POS talepleri.</p>"+
     btn("Kredi Kartlarımı Gör","ekranAc(kartlarimEkrani)"));
  html+=card("💸 Diğer bankacılık işlemleri",btn("Çek defterim","cekMerkeziAc()",true)+btn("Havale / para gönder","paraGonderModal()",true)+btn("POS / Kartla ödeme","ekranAc(kartPosEkrani)",true)+btn("POS Cihazı Başvuruları ve Banka POS Yönetimi","ekranAc(posBankaEkrani)",true));
  app("Bankacılık",html);
 };
 window.kartlarimEkrani=async function(){
  yukleniyor("Kredi kartlarım");
  try{
   var data=await Promise.all([API.rpc("kart_panel"),API.rpc("kart_pos_bekleyen")]);
   state.panel=data[0]||{};state.pos=data[1]||{};
   var p=state.panel, html=card("💳 Kredi Kartlarım",
    "<p class='alt'>Her kartta hesap kesimi 7 günde bir yapılır. Kesimden 7 gün sonra ödeme son günüdür. Kart limitine göre asgari ödeme %20 veya %40'tır; asgarisini ödeyenin kartı kapanmaz, kalan borç faizlenir.</p>");
   if(!(p.kartlar||[]).length)html+=card("Aktif kartın yok","<p class='alt'>Aşağıdan devlet ya da oyuncu bankasına kredi kartı başvurusu yap.</p>");
   (p.kartlar||[]).forEach(function(k){
    var acik=(k.ekstreler||[]).filter(function(x){return x.durum==="acik";}).sort(function(a,b){return a.id-b.id;})[0];
    var st=k.durum==="aktif"?"Aktif":k.durum==="donduruldu"?"Geçici olarak donduruldu":k.durum==="nakit_kapali"?"Nakit avansa kapalı":k.durum==="takip"?"Yasal takip":"Kullanıma kapalı";
    var body='<div class="kart" style="background:linear-gradient(140deg,#283657,#151d33);color:white;border-radius:16px;margin:9px 0 13px;padding:17px"><div style="opacity:.75;font-size:12px">'+esc(k.banka)+'</div>'+
      '<div style="font-weight:800;font-size:25px;letter-spacing:2px;margin:15px 0">•••• •••• •••• '+esc(k.son_dort)+'</div><div>'+st+'</div></div>';
    body+=fld("Kart limiti",money(k.limit))+fld("Kullanılabilir limit",money(k.kullanilabilir))+fld("Güncel toplam borç",money(k.borc))+fld("Sonraki hesap kesimi",tarih(k.kesim_at));
    if(Number(k.gecikmis_asgari)>0)body+=fld("Gecikmiş asgari ödeme",money(k.gecikmis_asgari))+"<p class=\"alt\">Gecikmiş asgari tutarı ödersen gecikme sayacı durur; kalan borcunu ödemeye devam edebilirsin.</p>";
    if(acik){
      body+=fld("Ödenmesi gereken ekstre",money(Math.max(0,acik.toplam-acik.odenen)))+
        fld("Kalan asgari tutar",money(Math.max(0,acik.asgari-acik.odenen)))+
        fld("Son ödeme günü",tarih(acik.son_odeme));
      body+=btn("Asgarisini Öde","kartOdemeYap("+k.id+",'asgari')")+
            btn("İstediğim Tutarı Öde","kartOdemeYap("+k.id+",'diger')",true);
    }
    if(Number(k.borc)>0)body+=btn("Borcun Tamamını Öde","kartOdemeYap("+k.id+",'tam')",!acik);
    if(k.durum==="aktif"){
      body+=btn("Nakit Avans Çek","kartAvansYap("+k.id+")",true);
      body+=btn("Kartımı Dondur","kartDondurYap("+k.id+",true)",true);
    }else if(k.durum==="donduruldu"){
      body+=btn("Kartımı Yeniden Aç","kartDondurYap("+k.id+",false)");
    }
    if((k.ekstreler||[]).length){
      body+='<h3 style="margin-top:16px">Hesap özetleri</h3>';
      (k.ekstreler||[]).forEach(function(a){body+='<div class="kart">'+fld("Kesim",tarih(a.kesim))+fld("Son ödeme",tarih(a.son_odeme))+fld("Dönem borcu",money(a.toplam))+fld("Asgari",money(a.asgari))+fld("Ödenen",money(a.odenen))+fld("Durum",esc(a.durum))+'</div>';});
    }
    if((k.hareketler||[]).length){
      body+='<h3 style="margin-top:16px">Hareketler</h3>';
      (k.hareketler||[]).forEach(function(h){body+='<div class="kv"><span style="max-width:65%;overflow-wrap:anywhere">'+esc(h.aciklama||h.tur)+'<small style="display:block">'+tarih(h.zaman)+'</small></span><b>'+((h.tur==="odeme"||h.tur==="iade")?"-":"+")+money(h.tutar)+'</b></div>';});
    }
    html+=card("💳 "+esc(k.banka)+" · #"+k.id,body);
   });
   var banks=(p.bankalar||[]);
   var options='<option value="">Devlet Bankası</option>'+banks.map(function(b){return '<option value="'+b.id+'">'+esc(b.ad)+' · Kasa '+money(b.kasa)+'</option>';}).join("");
   html+=card("Yeni kredi kartı başvurusu",
      '<p class="alt">Kart limiti talebin, kredi notun, gelirin ve bankanın kasasındaki kullanılabilir para birlikte değerlendirilir. Banka mali belgelerini ancak onay verirsen inceler.</p>'+
      '<div class="alan"><label>Banka</label><select id="bkBasvBanka">'+options+'</select></div>'+
      '<div class="alan"><label>Talep ettiğin kart limiti (TL)</label><input id="bkBasvTutar" type="number" min="1000" value="10000"></div>'+
      btn("Kart Başvurusu Yap","kartBasvurYap()"));
   (p.basvurular||[]).forEach(function(b){
     var body=fld("Talep edilen limit",money(b.istek))+fld("Durum",esc(b.durum));
     if(b.durum==="bekliyor" && !(b.izin||[]).length){
       body+='<p class="alt">İstenen bilgiler: '+(b.istenen||[]).map(function(a){return esc(a);}).join(", ")+'</p>'+
         '<p class="alt">Onay verirsen bilgiler doğrudan oyun veritabanından bankaya aktarılır.</p>'+
         btn("Belgeleri Paylaşmayı Onayla","kartBilgiIzni("+b.id+",true)")+
         btn("İzin Verme","kartBilgiIzni("+b.id+",false)",true);
     } else if(b.durum==="bekliyor")body+='<p class="alt">Finansal bilgi iznin verildi; banka kararı bekleniyor.</p>';
     html+=card("Başvurum · "+esc(b.banka),body);
   });
   if((p.yonetilen||[]).length){
     html+=card("🏦 Bankamın kart başvuruları","<p class='alt'>İzin verilen bilgileri kontrol edip banka kasasına ve riske göre limit belirle.</p>");
     (p.yonetilen||[]).forEach(function(b){
       var body=fld("Başvuran",esc(b.oyuncu))+fld("Talep",money(b.istek))+fld("İstenen belgeler",esc((b.istenen||[]).join(", ")));
       if((b.izin||[]).length){
         Object.keys(b.bilgi||{}).forEach(function(a){body+=fld(esc(a),esc(typeof b.bilgi[a]==="object"?JSON.stringify(b.bilgi[a]):b.bilgi[a]));});
         body+='<div class="alan"><label>Onaylanacak limit (TL)</label><input type="number" id="bkLim'+b.id+'" value="'+Math.round(b.istek)+'" min="1000"></div>'+
           btn("Kartı Onayla","kartBankaKarar("+b.id+",true)")+
           btn("Reddet","kartBankaKarar("+b.id+",false)",true);
       } else {
         body+='<div style="display:flex;flex-wrap:wrap;gap:10px">'+
         ["kredi_notu","maas","nakit","mulk","sirket"].map(function(x){return '<label><input type="checkbox" name="bkAlan'+b.id+'" value="'+x+'" '+(["kredi_notu","maas"].includes(x)?"checked":"")+'>'+x+'</label>';}).join("")+
         '</div>'+btn("Mali Bilgi İste","kartBankaBelgeIste("+b.id+")",true)+btn("Başvuruyu Reddet","kartBankaKarar("+b.id+",false)",true);
       }
       html+=card("🏦 "+esc(b.banka)+" · "+esc(b.oyuncu),body);
     });
   }
   html+=btn("POS Talebi / Kartla Ödeme","ekranAc(kartPosEkrani)",true)+btn("Bankacılık Merkezine Dön","ekranAc(bankacilikMerkeziEkrani)",true);
   app("Kredi Kartlarım",html);
  }catch(ex){app("Kredi Kartlarım",card("Bağlantı hatası",esc(ex.message)));}
 };
 window.kartBasvurYap=async function(){
  try{await API.rpc("kart_basvur",{p_banka:sec("bkBasvBanka").value?Number(sec("bkBasvBanka").value):null,p_limit:asNumber("bkBasvTutar")});toast("Başvuru oluşturuldu");kartlarimEkrani();}catch(ex){err(ex);}
 };
 window.kartBilgiIzni=async function(id,ok){try{await API.rpc("kart_belge_yanit",{p_basvuru:id,p_onay:ok});toast(ok?"Bilgi paylaşımına izin verildi":"Bilgi paylaşımı reddedildi");kartlarimEkrani();}catch(ex){err(ex);}};
 window.kartBankaBelgeIste=async function(id){try{
   var fields=[].slice.call(document.querySelectorAll('input[name="bkAlan'+id+'"]:checked')).map(function(x){return x.value;});
   if(!fields.includes("kredi_notu")){toast("Risk değerlendirmesi için kredi notu gerekir.",true);return;}
   await API.rpc("kart_belge_iste",{p_basvuru:id,p_alanlar:fields});toast("Oyuncuya izin talebi gönderildi");kartlarimEkrani();
  }catch(ex){err(ex);}};
 window.kartBankaKarar=async function(id,onay){try{
   var limit=sec("bkLim"+id);
   await API.rpc("kart_basvuru_karar",{p_basvuru:id,p_onay:onay,p_limit:onay?Number(limit&&limit.value):null});
   toast(onay?"Kart düzenlendi":"Başvuru reddedildi");kartlarimEkrani();
  }catch(ex){err(ex);}};
 window.kartOdemeYap=async function(id,secenek){
  var k=(state.panel&&state.panel.kartlar||[]).find(function(x){return x.id===id;});
  if(!k)return toast("Kart bulunamadı",true);
  var acik=(k.ekstreler||[]).filter(function(x){return x.durum==="acik";}).sort(function(a,b){return a.id-b.id;})[0];
  var tutar=secenek==="tam"?Number(k.borc):secenek==="asgari"?Math.max(0,Number(acik&&acik.asgari||0)-Number(acik&&acik.odenen||0)):null;
  if(secenek==="diger"){tutar=Number(prompt("Ödemek istediğin tutar (TL)",acik?Math.max(0,acik.toplam-acik.odenen):k.borc));}
  if(!(tutar>0))return toast("Ödeme tutarı sıfırdan büyük olmalı",true);
  if(!confirm(money(tutar)+" tutarında kart borcu ödemesini cüzdanından yapmak istiyor musun?"))return;
  try{await API.rpc("kart_ode",{p_kart:id,p_tutar:tutar});toast("Kart borcu ödendi");kartlarimEkrani();}catch(ex){err(ex);}
 };
 window.kartAvansYap=async function(id){
   var tutar=Number(prompt("Nakit avans tutarı (TL) — ayrıca %2 işlem ücreti uygulanır","1000"));
   if(!(tutar>=100))return;
   if(!confirm("Nakit avans "+money(tutar)+" + işlem ücreti ile cüzdanına aktarılsın mı?"))return;
   try{await API.rpc("kart_nakit_avans",{p_kart:id,p_tutar:tutar});toast("Nakit avans yatırıldı");kartlarimEkrani();}catch(ex){err(ex);}
 };

 window.posBankaEkrani=async function(){
  yukleniyor("POS cihazları ve banka yönetimi");
  try{
   var d=await API.rpc("pos_banka_panel");state.posBanks=d||{};
   var html=card("🏦 POS Cihazı ve Banka Yönetimi",
     "<p class='alt'>Şirketin için bir oyuncu bankasına başvur. Banka otomatik onayı açmışsa POS hemen aktif olur; kapalıysa banka yetkilisi onaylar. Komisyon her tek çekim kartlı satışın %2'sidir. Taksit yoktur.</p>"+
     btn("Kartlı satış ekranı","ekranAc(kartPosEkrani)",true));
   if((d.sirketler||[]).length){
     (d.sirketler||[]).forEach(function(f){
       var owned=(d.poslar||[]).filter(function(p){return p.sirket_id===f.id;});
       var options=(d.bankalar||[]).filter(function(b){return !owned.some(function(p){return p.banka_id===b.id && ["aktif","bekliyor"].includes(p.durum);});})
         .map(function(b){return '<option value="'+b.id+'">'+esc(b.ad)+' · '+(b.otomatik?"Anında onay":"Banka onayı")+' · %2</option>';}).join("");
       var body='<p class="alt">Bankalara başvurarak tek çekim POS cihazı edinebilirsin.</p>';
       owned.forEach(function(p){
         var color=p.durum==="aktif"?"✅ ":p.durum==="bekliyor"?"⏳ ":"";
         body+=card(color+esc(p.banka),fld("Durum",esc(p.durum))+fld("Komisyon","%2")+
           fld("Aktif satış hacmi",money(p.hacim))+fld("Komisyon toplamı",money(p.kesilen_komisyon)));
       });
       if(options){
         body+='<div class="alan"><label>POS başvurusu yapılacak banka</label><select id="pbBank'+f.id+'">'+options+'</select></div>'+
           btn("Bankaya POS Başvurusu Gönder","posBasvurYap("+f.id+")");
       }else if(!(d.bankalar||[]).length)body+='<p class="alt">Henüz oyuncu bankası bulunmuyor.</p>';
       html+=card("🏢 "+esc(f.ad)+" · POS cihazları",body);
     });
   }else html+=card("Şirket hesabı","<p class='alt'>Başvuru yapmak için kendi şirketini kurmalı veya yönetim yetkisi almalısın.</p>");
   (d.yonetilen_bankalar||[]).forEach(function(b){
     var body=fld("Kasa",money(b.kasa))+fld("POS satış hacmi",money(b.satis_hacmi))+
         fld("Tahsil edilmiş net POS komisyonu",money(b.toplam_komisyon))+
         '<p class="alt">Banka otomatik başvuruları kabul edebilir veya başvuruları tek tek değerlendirebilir. Komisyon %2 sabittir.</p>'+
         '<div class="alan"><label>Başvuru onay sistemi</label><select id="pbAuto'+b.id+'">'+
         '<option value="false" '+(!b.otomatik?"selected":"")+'>Manuel — banka yönetimi onaylar</option>'+
         '<option value="true" '+(b.otomatik?"selected":"")+'>Otomatik — başvurular anında kabul</option>'+
         '</select></div>'+btn("Başvuru Politikasını Kaydet","posOtomatikKaydet("+b.id+")");
     var applications=b.basvurular||[];
     if(!applications.length)body+='<p class="alt">Bu bankada henüz POS başvurusu yok.</p>';
     applications.forEach(function(p){
       var actions=p.durum==="bekliyor"?
         btn("POS'u Onayla","posBankadanKarar("+p.id+",true)")+
         btn("Reddet","posBankadanKarar("+p.id+",false)",true)
         :p.durum==="aktif"?btn("POS'u İptal Et","posBankadanKarar("+p.id+",false)",true):"";
       body+=card(esc(p.sirket),fld("Başvuru",tarih(p.basvuru))+fld("Durum",esc(p.durum))+actions);
     });
     html+=card("🏦 "+esc(b.ad)+" · POS yönetimi",body);
   });
   html+=btn("Bankacılığa Dön","ekranAc(bankacilikMerkeziEkrani)",true);
   app("POS Cihazları",html);
  }catch(ex){app("POS Cihazları",card("Sistem uyarısı",esc(ex.message)));}
 };
 window.posBasvurYap=async function(sirket){
  try{
   var el=sec("pbBank"+sirket);
   if(!el||!el.value){toast("Başvuru yapılacak bankayı seç",true);return;}
   var data=await API.rpc("pos_basvur",{p_sirket:sirket,p_banka:Number(el.value)});
   toast(data.durum==="aktif"?"POS cihazın otomatik onaylandı":"Başvurun bankaya gönderildi");
   posBankaEkrani();
  }catch(ex){err(ex);}
 };
 window.posOtomatikKaydet=async function(banka){
  try{
   var otomatik=sec("pbAuto"+banka).value==="true";
   if(!confirm(otomatik?"Bekleyen POS başvurularını da otomatik onaylamak istiyor musun?":"Yeni POS başvuruları manuel incelemeye alınsın mı?"))return;
   await API.rpc("pos_banka_otomatik",{p_banka:banka,p_otomatik:otomatik});
   toast("POS onay modu değişti");posBankaEkrani();
  }catch(ex){err(ex);}
 };
 window.posBankadanKarar=async function(pos,onay){
  if(!confirm(onay?"POS cihazı %2 komisyonla etkinleştirilsin mi?":"Bu POS başvurusu/cihazı reddedilsin veya kapatılsın mı?"))return;
  try{await API.rpc("pos_basvuru_karar",{p_pos:pos,p_onay:onay});toast("Banka POS kararı işlendi");posBankaEkrani();}catch(ex){err(ex);}
 };

 window.kartPosEkrani=async function(){
  yukleniyor("POS ve kartla ödeme");
  try{
   var results=await Promise.all([API.rpc("kart_pos_bekleyen"),API.rpc("kart_panel"),API.rpc("pos_banka_panel")]);
   state.pos=results[0]||{};state.panel=results[1]||{};state.posBanks=results[2]||{};
   var p=state.pos,k=state.panel.kartlar||[],pd=state.posBanks;
   var html=card("🏪 POS · Tek Çekim Kartla Ödeme",
   "<p class='alt'>Satıcı şirketin bankadan onaylı POS cihazı olmalı. Karttan tam satış bedeli çekilir; satıcıya %98 net tutar geçer, POS bankası %2 komisyon kazanır. Taksit yok.</p>"+
   btn("POS cihazım ve başvurular","ekranAc(posBankaEkrani)",true));
   (p.gelen||[]).forEach(function(t){
      var options=k.filter(function(a){return a.durum==="aktif"&&Number(a.kullanilabilir)>=Number(t.tutar);})
      .map(function(a){return '<option value="'+a.id+'">'+esc(a.banka)+' · '+esc(a.son_dort)+' ('+money(a.kullanilabilir)+')</option>';}).join("");
      html+=card("Gelen POS isteği · "+esc(t.sirket),
      fld("Tek çekim",money(t.tutar))+fld("Mal / hizmet",esc(t.aciklama))+
      '<div class="alan"><label>Ödeme kartın</label><select id="bkPosKart'+t.id+'">'+options+'</select></div>'+
      (options?btn("Tek Çekim Kartla Öde","kartPosYanit("+t.id+",true)"):'<p class="alt">Yeterli limitli kartın bulunmuyor.</p>')+
      btn("Talebi Reddet","kartPosYanit("+t.id+",false)",true));
   });
   if(!(p.gelen||[]).length)html+=card("Gelen talepler","<p class='alt'>Şu anda bekleyen ödeme talebin bulunmuyor.</p>");
   (p.sirketler||[]).forEach(function(f){
      var options=(pd.poslar||[]).filter(function(x){return x.sirket_id===f.id && x.durum==="aktif";})
        .map(function(x){return '<option value="'+x.id+'">'+esc(x.banka)+' · %2 komisyon</option>';}).join("");
      if(!options){
        html+=card(esc(f.ad)+" · POS alınmadı",'<p class="alt">Kartlı satış yapmak için bir oyuncu bankasından POS cihazı al.</p>'+
         btn("POS başvurusu yap","ekranAc(posBankaEkrani)"));
        return;
      }
      html+=card("🏢 "+esc(f.ad)+" · Yeni Kartlı Satış",
       '<p class="alt">Müşterinin kartına tek çekim uygulanır. Net tahsilat satışın %98’idir.</p>'+
       '<div class="alan"><label>POS cihazı / bankası</label><select id="bkPosDevice'+f.id+'">'+options+'</select></div>'+
       '<div class="alan"><label>Alıcı kullanıcı adı</label><input id="bkPosMusteri'+f.id+'" placeholder="Kullanıcı adı"></div>'+
       '<div class="alan"><label>Satış bedeli (TL)</label><input type="number" min="1" step="0.01" id="bkPosTutar'+f.id+'"></div>'+
       '<div class="alan"><label>Mal / hizmet açıklaması</label><input id="bkPosAciklama'+f.id+'" placeholder="Satılan ürün veya hizmet"></div>'+
       '<p class="alt">Örnek: 10.000 TL satış → 9.800 TL şirkete, 200 TL POS bankasına.</p>'+
       btn("Tek Çekim POS Talebi Gönder","kartPosTalepYap("+f.id+")"));
   });
   (p.giden||[]).forEach(function(t){html+=card("Gönderdiğim talep · "+esc(t.musteri),fld("Tutar",money(t.tutar))+fld("Satış",esc(t.aciklama))+fld("Durum",esc(t.durum))+(t.durum==="odendi"?btn("Kartlı Satışı İade Et","kartPosIadeYap("+t.id+")",true):""));});
   html+=btn("Kredi Kartlarıma Dön","ekranAc(kartlarimEkrani)",true);
   app("POS ve Kartla Ödeme",html);
  }catch(ex){app("POS",card("Bağlantı hatası",esc(ex.message)));}
 };
 window.kartPosTalepYap=async function(sirket){try{
  var id=Number(sirket)||asNumber("bkPosSirket");
  var device=sec("bkPosDevice"+id);
  if(!device||!device.value){toast("Onaylı POS cihazını seç",true);return;}
  await API.rpc("pos_satis_talep",{p_sirket:id,p_pos:Number(device.value),
    p_oyuncu:sec("bkPosMusteri"+id).value,
    p_tutar:asNumber("bkPosTutar"+id),p_aciklama:sec("bkPosAciklama"+id).value});
  toast("Tek çekim POS talebi gönderildi");kartPosEkrani();
 }catch(ex){err(ex);}};
 window.kartPosYanit=async function(id,onay){try{
  var kart=sec("bkPosKart"+id), kim=kart&&kart.value?Number(kart.value):null;
  if(onay&&!kim){toast("Uygun limitli aktif kartın yok",true);return;}
  if(onay&&!confirm("POS ödemesini kartınla onaylıyor musun?"))return;
  await API.rpc("kart_pos_yanit",{p_pos:id,p_kart:onay?kim:null});
  toast(onay?"Kartla ödeme tamamlandı":"POS talebi reddedildi");state.panel=null;kartPosEkrani();
 }catch(ex){err(ex);}};
 window.kartDondurYap=async function(id,freeze){
  if(!confirm(freeze?"Kartını geçici olarak alışverişe ve nakit avansa kapatmak istiyor musun?":"Kartı tekrar kullanıma açmak istiyor musun?"))return;
  try{await API.rpc("kart_dondur",{p_kart:id,p_dondur:freeze});toast(freeze?"Kart donduruldu":"Kart tekrar açıldı");kartlarimEkrani();}catch(ex){err(ex);}
 };
 window.kartPosIadeYap=async function(id){
  if(!confirm("Satış bedeli şirket kasasından geri ödenecek; kart borcu veya müşteri bakiyesi düzeltilecek. İadeyi onaylıyor musun?"))return;
  try{await API.rpc("kart_pos_iade",{p_pos:id});toast("POS satışı iade edildi");state.panel=null;kartPosEkrani();}catch(ex){err(ex);}
 };
})();