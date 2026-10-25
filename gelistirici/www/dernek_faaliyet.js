/* Dernekler: sosyal faaliyet, bağış kampanyası ve parti ziyaretleri. */
(function () {
  if (window.STK_FAALIYET_MODUL) return;
  window.STK_FAALIYET_MODUL = true;

  var TUR = {agac:"Ağaçlandırma / hatıra ormanı", gida:"Gıda yardımı", burs:"Öğrenci bursu", hayvan:"Sokak hayvanları", temizlik:"Çevre temizliği", kultur:"Kültür ve sanat"};
  var GON = {fidan:"Fidan dikimi", temizlik:"Çevre temizliği", gida:"Yardım dağıtımı", egitim:"Eğitim gönüllülüğü", hayvan:"Hayvan bakımı", kultur:"Kültür buluşması"};
  var PROGRAM = {asevi:"Aşevi ve sıcak yemek", etut:"Ücretsiz etüt merkezi", afet:"Afet hazırlık merkezi", hayvanbakim:"Hayvan bakım noktası", kulturmerkezi:"Kültür ve sanat atölyesi", meslek:"Meslek edindirme kursu", saglik:"Koruyucu sağlık etkinliği"};
  var UYE_DESTEK = {ihtiyac:"İhtiyaç yardımı",tasinma:"Taşınma desteği",hukuk:"Dava harcı desteği",egitim:"Eğitim katılım bursu",gonullu:"Gönüllü emeği desteği"};
  var UYE_MAX = {ihtiyac:2000,tasinma:1500,hukuk:4000,egitim:1800,gonullu:1200};
  var UYE_ACIK = {
    ihtiyac:"Cüzdan + banka toplamı 12.000 TL veya az, mülkü ve yatırımı olmayan üyeler için.",
    tasinma:"Son 14 günde şehir değiştiren üyeler için.",
    hukuk:"Son 14 günde gerçekten ödediğin dava harcının en fazla %60'ı.",
    egitim:"Derneğin eğitim / meslek programına en az 2 saat önce katılmış üyeler için.",
    gonullu:"Son 14 gün içinde tamamlanan dernek gönüllü etkinliğine katılan üyeler için."
  };
  var durumAd = {bekliyor:"Yanıt bekliyor", kabul:"Kabul edildi", red:"Reddedildi", tamam:"Gerçekleşti"};
  var tarihGir = function (ekGun) {
    var t = trParca(new Date(simdi() + (ekGun || 1) * 86400000));
    return t.y + "-" + String(t.a).padStart(2,"0") + "-" + String(t.g).padStart(2,"0") + "T" + String(t.s).padStart(2,"0") + ":" + String(t.d).padStart(2,"0");
  };
  var tarihApi = function (v) { return v ? v + ":00+03:00" : null; };
  var turOps = function (tipler) { return Object.keys(tipler).map(function(k) { return '<option value="' + k + '">' + e(tipler[k]) + '</option>'; }).join(""); };
  var input = function (m,id) { var x = m.querySelector("#" + id); return x ? x.value : ""; };
  var fail = function (m,err) { var x = m.querySelector(".sf-hata"); if(x) x.textContent = hataCevir(err.message || String(err)); };
  var islem = function (m,btn,fn,success,done) {
    var b = m.querySelector("#" + btn);
    b.onclick = async function () {
      b.disabled = true;
      try { var r = await fn(); if (r === null) { b.disabled = false; return; } modalKapat(); toast(success); if(done) await done(r); }
      catch(err) { b.disabled = false; fail(m,err); }
    };
  };
  var alan = function (ad,ic) { return '<div class="alan"><label>' + ad + '</label>' + ic + '</div>'; };
  var sorun = '<div class="hata-metin sf-hata"></div>';
  var buton = function (ad,id) { return '<button class="btn altin" id="' + id + '">' + ad + '</button>'; };
  var ss = function (name,desc,onclick) { return '<button type="button" class="giris-satir" onclick="' + onclick + '"><span class="orta"><b>' + name + '</b><span class="kucuk">' + desc + '</span></span><span class="ok">›</span></button>'; };

  window.stkFaaliyetEkrani = async function (id) {
    yukleniyor("Dernek faaliyetleri");
    try {
      var res = await Promise.all([API.rpc("dernek_faaliyetler",{p_dernek:id}), API.rpc("dernek_program_ozet",{p_dernek:id})]);
      var r = res[0], program = res[1] || {};
      var kamp = Array.isArray(r.kampanyalar) ? r.kampanyalar : [];
      var proj = Array.isArray(r.projeler) ? r.projeler : [];
      var etkin = Array.isArray(r.etkinlikler) ? r.etkinlikler : [];
      var ziyaret = Array.isArray(r.ziyaretler) ? r.ziyaretler : [];
      var acik = kamp.filter(function(k) {return k.acik;}).length;
      var h = '<div class="kart"><h2>Dernek sosyal faaliyet merkezi</h2><p class="alt">' + e(r.ad) + ' · Sanal oyun dünyasındaki faaliyetler, gerçek dünyada dikim veya yardım yapıldığı anlamına gelmez.</p>' +
        '<div class="kv"><span class="k">Toplam kasa</span><b>' + (typeof gizliTL==='function'?gizliTL(r.kasa,tlYaz):tlYaz(r.kasa)) + '</b></div>' +
        '<div class="kv"><span class="k">Serbest harcama bütçesi</span><b>' + tlYaz(r.serbest) + '</b></div>' +
        '<div class="kv"><span class="k">Amaçlı kampanyalara ayrılan</span><b>' + (r.kasa==null?(typeof gizliTL==='function'?gizliTL(null,tlYaz):tlYaz(null)):tlYaz(Math.max(0,Number(r.kasa)-Number(r.serbest)))) + '</b></div>' +
        '<div class="kv"><span class="k">Açık kampanya</span><b>' + acik + '</b></div></div>';
      if (r.yetkili) h += '<div class="kart"><h2>Yeni faaliyet</h2>' +
        '<div class="vit-dugme"><button class="btn canli" onclick="stkProjeModal(' + id + ')">🌳 Ağaçlandır / Yardım yap</button><button class="btn altin" onclick="stkKampanyaAcModal(' + id + ')">Bağış kampanyası aç</button></div>' +
        '<div class="vit-dugme"><button class="btn ikinci" onclick="stkEtkinlikModal(' + id + ')">Gönüllü etkinliği düzenle</button><button class="btn ikinci" onclick="stkZiyaretModal(' + id + ')">Partiye ziyaret talep et</button></div></div>';
      var etki = program.etki || {}, programlar = program.programlar || [], etkiKayit = program.etkiler || [];
      h += '<div class="kart"><h2>🤝 Gerçek oyunculara / üyelere destek</h2>' +
        '<p class="alt">Dernek, kendi üyelerine oyun içinde karşılığı olan ihtiyaç, taşınma, dava harcı, eğitim ve gönüllülük yardımı ödeyebilir. Üye başvurur, yönetim onaylar, ödeme doğrudan oyun cüzdanına aktarılır.</p>' +
        '<button class="btn canli" onclick="stkUyeDestekEkrani(' + id + ')">Üye yardımları · başvurular · onaylar</button>' +
        '<p class="kucuk">Yardımlar yalnız serbest kasadan ödenir. Dernek yönetimi kendi başvurusunu onaylayamaz.</p></div>';
      h += '<div class="bolum-bas"><h2>🏘️ Sosyal hizmetler ve şehir etkisi</h2></div>' +
        '<div class="kart"><p class="alt">Derneğin parasını 7 günlük gerçekçi hizmetlere ayır. Oyuncular gönüllü katılabilir; şehir gelişimi ve memnuniyet küçük ama kalıcı katkılar alır.</p>' +
        '<div class="kv"><span class="k">Dernek etki puanı</span><b>' + Number(etki.puan||0).toLocaleString("tr-TR") + '</b></div>' +
        '<div class="kv"><span class="k">Toplam sosyal harcama</span><b>' + tlYaz(etki.toplam_harcama||0) + '</b></div>' +
        '<div class="kv"><span class="k">Hizmet verilen NPC / hedef</span><b>' + Number(etki.erisim||0).toLocaleString("tr-TR") + '</b></div>' +
        '<div class="kv"><span class="k">Faaliyet / gönüllü katılımı</span><b>' + Number(etki.faaliyet_sayisi||0) + ' / ' + Number(etki.gonullu_sayisi||0) + '</b></div>' +
        (r.yetkili ? '<button class="btn altin" onclick="stkProgramModal(' + id + ')">+ Dernek bütçesiyle hizmet başlat</button>' : '') +
        '</div>';
      h += '<div class="bolum-bas"><h2>Aktif ve geçmiş hizmetler</h2><span class="kucuk">' + programlar.length + ' kayıt</span></div>';
      h += programlar.length ? programlar.map(function(z) {
        var aktif = new Date(z.bit).getTime() > simdi();
        return '<div class="kart"><span class="rozet ' + (aktif?'altin':'') + '">' + (aktif?'Hizmet devam ediyor':'Tamamlandı') + '</span>' +
          '<h3>' + e(PROGRAM[z.tur]||z.tur) + '</h3><p class="kucuk">' + e(z.il) + ' · Paket ' + Number(z.paket) +
          ' · Bitiş: ' + tarihSaat(z.bit) + '</p>' +
          '<div class="kv"><span class="k">7 günlük dernek gideri</span><b>' + tlYaz(z.ucret) + '</b></div>' +
          '<div class="kv"><span class="k">Hedef hizmet kapasitesi</span><b>' + Number(z.hedef).toLocaleString("tr-TR") + ' kişi</b></div>' +
          '<div class="kv"><span class="k">Gönüllüler</span><b>' + Number(z.gonullu||0) + '</b></div>' +
          (aktif && z.benim_ilim && !z.katildim ? '<button class="btn ikinci" onclick="stkProgramGonulluKatil(' + z.id + ',' + id + ')">Gönüllü destek ver</button>' :
            z.katildim ? '<span class="rozet">Gönüllü katıldın</span>' : '') + '</div>';
      }).join("") : '<div class="kart"><p class="alt">Henüz bütçeden finanse edilen bir sosyal hizmet yok.</p></div>';
      if (etkiKayit.length) h += '<div class="bolum-bas"><h2>Harcamanın somut karşılığı</h2></div>' +
        etkiKayit.slice(0,12).map(function(x) {
          return '<div class="kart"><b>' + e(PROGRAM[x.tur]||TUR[x.tur]||x.tur) + '</b>' +
            '<p class="kucuk">' + e(x.il) + ' · ' + tarihSaat(x.zaman) + ' · ' + (x.kaynak==='program'?'7 günlük hizmet':'Sosyal proje') + '</p>' +
            '<div class="kv"><span class="k">Harcanan / hedef kapasite</span><b>' + tlYaz(x.tutar) + ' / ' + Number(x.erisim||0) + ' kişi</b></div>' +
            '<div class="kv"><span class="k">Şehir gelişimi / memnuniyet katkısı</span><b>+' +
            Number(x.gelisim||0).toLocaleString("tr-TR",{maximumFractionDigits:3}) + ' / +' +
            Number(x.memnuniyet||0).toLocaleString("tr-TR",{maximumFractionDigits:3}) + '</b></div></div>';
        }).join("");
      h += '<div class="bolum-bas"><h2>Bağış ve yardım kampanyaları</h2><span class="kucuk">' + kamp.length + ' kampanya</span></div>';
      h += kamp.length ? kamp.map(function(k) {
        var kalan = Math.max(0,Number(k.hedef)-Number(k.toplanan));
        var oran = Math.min(100,Math.round(100*Number(k.toplanan)/Number(k.hedef)));
        return '<div class="kart"><span class="rozet altin">' + e(TUR[k.tur]||k.tur) + '</span><h3>' + e(k.baslik) + '</h3><p class="alt">' + e(k.aciklama) + '</p>' +
          '<div class="kv"><span class="k">Toplanan / hedef</span><b>' + tlYaz(k.toplanan) + ' / ' + tlYaz(k.hedef) + '</b></div>' +
          '<div style="height:8px;background:var(--panel2);border-radius:8px;overflow:hidden;margin:8px 0"><div style="width:' + oran + '%;height:8px;background:var(--good);border-radius:8px"></div></div>' +
          '<p class="kucuk">Harcandı: ' + tlYaz(k.harcanan) + ' · Kalan amaçlı bütçe: ' + tlYaz(Math.max(0,Number(k.toplanan)-Number(k.harcanan))) + '</p>' +
          (k.acik && kalan >= 100 ? '<button class="btn altin" onclick="stkKampanyaBagisModal(' + k.id + ',' + id + ',' + kalan + ')">Bu kampanyaya bağış yap</button>' : '<span class="rozet">' + (k.acik ? "Hedef tamamlandı" : "Bağışa kapalı") + '</span>') + '</div>';
      }).join("") : '<div class="kart"><p class="alt">Henüz yardım kampanyası düzenlenmedi.</p></div>';
      h += '<div class="bolum-bas"><h2>Gerçekleştirilen sosyal projeler</h2><span class="kucuk">Son ' + proj.length + ' faaliyet</span></div>';
      h += proj.length ? proj.map(function(x) {
        return '<div class="kart"><b>' + (x.orman ? '🌳 ' : '') + e(x.baslik) + '</b>' +
          '<p class="kucuk">' + e(TUR[x.tur]||x.tur) + ' · ' + e(x.il) + ' · ' + tarihSaat(x.zaman) + '</p>' +
          '<div class="kv"><span class="k">Adet</span><b>' + Number(x.adet).toLocaleString("tr-TR") + '</b></div>' +
          '<div class="kv"><span class="k">Dernek harcaması</span><b>' + tlYaz(x.tutar) + '</b></div>' +
          (x.orman ? '<span class="rozet altin">Hatıra ormanı</span>' : '') + '</div>';
      }).join("") : '<div class="kart"><p class="alt">Henüz proje gerçekleştirilmedi.</p></div>';
      h += '<div class="bolum-bas"><h2>Gönüllü etkinlikleri</h2></div>';
      h += etkin.length ? etkin.map(function(x) {
        var bitti = new Date(x.bit).getTime() <= simdi();
        return '<div class="kart"><span class="rozet">' + e(GON[x.tur]||x.tur) + '</span><h3>' + e(x.baslik) + '</h3><p class="alt">' + e(x.aciklama) + '</p>' +
          '<p class="kucuk">' + e(x.il) + ' · ' + tarihSaat(x.bas) + ' · 2 saat · ' + x.katilim + ' gönüllü</p>' +
          (!bitti && !x.katildim && x.benim_ilim ? '<button class="btn ikinci" onclick="stkGonulluKatil(' + x.id + ',' + id + ')">Gönüllü katıl</button>' :
            x.katildim ? '<span class="rozet">Katıldın</span>' : bitti ? '<span class="rozet">Tamamlandı</span>' : '<span class="kucuk">Sadece aynı ildeki oyuncular katılabilir</span>') + '</div>';
      }).join("") : '<div class="kart"><p class="alt">Henüz gönüllü etkinlik planlanmadı.</p></div>';
      h += '<div class="bolum-bas"><h2>Partilerle görüşmeler</h2></div>';
      h += ziyaret.length ? ziyaret.map(function(z) {
        return '<div class="kart"><h3>' + e(z.parti) + '</h3><p>' + e(z.konu) + '</p><p class="kucuk">' + tarihSaat(z.tarih) + '</p><span class="rozet">' + e(durumAd[z.durum]||z.durum) + '</span>' +
          (z.yanitlayabilirim && z.durum === "bekliyor" ? '<div class="vit-dugme"><button class="btn ikinci" onclick="stkZiyaretYanit(' + z.id + ',' + id + ',true)">Kabul et</button><button class="btn tehlike" onclick="stkZiyaretYanit(' + z.id + ',' + id + ',false)">Reddet</button></div>' : '') +
          (z.durum === "kabul" && new Date(z.tarih).getTime() <= simdi() && (r.yetkili||z.yanitlayabilirim) ? '<button class="btn altin" onclick="stkZiyaretTamamla(' + z.id + ',' + id + ')">Ziyareti tamamla</button>' : '') + '</div>';
      }).join("") : '<div class="kart"><p class="alt">Henüz ziyaret kaydı yok.</p></div>';
      iskelet("Sosyal faaliyetler · " + e(r.ad),h,{geri:true});
    } catch(err) { iskelet("Dernek faaliyetleri",'<div class="kart"><p class="alt">' + e(hataCevir(err.message)) + '</p></div>',{geri:true}); }
  };

  // Üyeye doğrudan ödenen, oyun içi kanıta dayalı sosyal destek ekranı.
  window.stkUyeDestekEkrani = async function(id) {
    yukleniyor("Dernek üye destekleri");
    try {
      var r=await API.rpc("dernek_uye_destek_liste",{p_dernek:id});
      var talepler=Array.isArray(r.talepler)?r.talepler:[],
          benim=talepler.filter(function(z){return z.benim;}),
          bekleyen=talepler.filter(function(z){return z.durum==="bekliyor";});
      var h='<div class="kart"><h2>🤝 Dernek üyelerine doğrudan yardım</h2>' +
        '<p class="alt">Bu yardımlar NPC yerine doğrudan oyundaki gerçek üyelere yarar sağlar. Onaylanan tutar dernek kasasından çıkar, üyenin oyun cüzdanına yatar. Kampanyalara ayrılmış bağışlar kullanılamaz.</p>' +
        '<div class="kv"><span class="k">Serbest dernek bütçesi</span><b>'+tlYaz(r.serbest)+'</b></div>' +
        '<div class="kv"><span class="k">Bekleyen destek talebi</span><b>'+bekleyen.length+'</b></div>' +
        '<button class="btn altin" onclick="stkUyeDestekBasvurModal('+id+')">+ Yardım başvurusu yap</button>' +
        '</div>';
      h+='<div class="bolum-bas"><h2>Yardım türleri</h2></div>';
      h+='<div class="kart">'+Object.keys(UYE_DESTEK).map(function(k){
        return '<div class="kv"><span class="k"><b>'+e(UYE_DESTEK[k])+'</b><span class="kucuk">'+e(UYE_ACIK[k])+'</span></span><b>≤ '+tlYaz(UYE_MAX[k])+'</b></div>';
      }).join("")+
      '<p class="kucuk">Hesap en az 48 saatlik, üyelik en az 24 saatlik olmalı. Son 7 günde yardım alan yeniden alamaz; aynı tür için 21 gün beklenir.</p></div>';
      if(r.yetkili) h+='<div class="bolum-bas"><h2>Yönetim · destek talepleri</h2><span class="kucuk">'+bekleyen.length+' bekleyen</span></div>';
      else h+='<div class="bolum-bas"><h2>Başvurularım</h2><span class="kucuk">'+benim.length+'</span></div>';
      var gorunen=r.yetkili?talepler:benim;
      h+=gorunen.length?gorunen.map(function(z){
        var st=z.durum==="onay"?"Onaylandı":z.durum==="red"?"Reddedildi":z.durum==="iptal"?"İptal":"Yönetim kararı bekliyor";
        return '<div class="kart"><span class="rozet">'+st+'</span>'+
          '<h3>'+e(UYE_DESTEK[z.tur]||z.tur)+' · '+tlYaz(z.tutar)+'</h3>'+
          (r.yetkili?'<p class="kucuk">Başvuran: '+e(z.uye)+'</p>':'')+
          '<p>'+e(z.aciklama)+'</p><p class="kucuk">Başvuru: '+tarihSaat(z.basvuru)+'</p>'+
          (z.ret_gerekcesi?'<p class="kucuk">Gerekçe: '+e(z.ret_gerekcesi)+'</p>':'')+
          (z.degerlendirebilirim?'<div class="vit-dugme">'+
            '<button class="btn altin" onclick="stkUyeDestekKarar('+z.id+','+id+',true)">Onayla ve öde</button>'+
            '<button class="btn ikinci" onclick="stkUyeDestekKarar('+z.id+','+id+',false)">Reddet</button></div>':
            z.durum==="bekliyor"&&z.benim&&r.yetkili?'<p class="kucuk">Kendi başvurunu değerlendiremezsin; diğer yönetici onaylamalı.</p>':'')+
          '</div>';
      }).join(""):'<div class="kart"><p class="alt">Henüz kayıtlı destek başvurusu bulunmuyor.</p></div>';
      iskelet("Dernek üye yardımları",h,{geri:true});
    }catch(err){iskelet("Dernek üye yardımları",'<div class="kart"><p class="alt">'+e(hataCevir(err.message||String(err)))+'</p></div>',{geri:true});}
  };

  window.stkUyeDestekBasvurModal=async function(id){
    try {
      var bilgi=await API.rpc("dernek_uye_destek_liste",{p_dernek:id});
      var kanit=bilgi.kanitlar||{};
      var m=modal('<h3>Üyelik yardım başvurusu</h3>'+
        '<p class="alt">Yönetim onaylarsa tutar doğrudan oyun cüzdanına geçer. Başvurmak ödeme garantisi değildir.</p>'+
        alan("Yardım türü",'<select id="udTur">'+turOps(UYE_DESTEK)+'</select>')+
        '<p class="kucuk" id="udAcik"></p>'+
        alan("Katılım / ödeme kaydı",'<select id="udKanit"></select>')+
        alan("Başvuru tutarı (oyun TL)",'<input type="number" id="udTutar" min="100" max="4000" step="1" value="1000">')+
        '<p class="kucuk" id="udLimit"></p>'+
        alan("Başvuru gerekçesi",'<textarea id="udGerekce" class="alanmetin" maxlength="350" placeholder="Yardıma neden ihtiyacın var? (en az 5 karakter)"></textarea>')+
        sorun+buton("Başvuruyu yönetim kuruluna ilet","udBasvur"));
      var sonTur="";
      var yenile=function(){
        var tur=input(m,"udTur"),sec=m.querySelector("#udKanit"),opt=Array.isArray(kanit[tur])?kanit[tur]:[];
        var eskiSecim=sonTur===tur?sec.value:"";
        sonTur=tur;
        m.querySelector("#udAcik").textContent=UYE_ACIK[tur]||"";
        var gerekli=tur==="hukuk"||tur==="egitim"||tur==="gonullu";
        var satir=m.querySelector("#udKanit").parentNode;
        satir.style.display=gerekli?"":"none";
        sec.innerHTML=gerekli?
          '<option value="">Kanıt kaydı seç</option>'+opt.map(function(x){return '<option value="'+Number(x.id)+'">'+
             e(x.ad||"Katılım kaydı")+(x.tutar?' · '+tlYaz(x.tutar):'')+'</option>';}).join(""):
          '<option value="">Ek kayıt gerekmiyor</option>';
        if (eskiSecim && Array.from(sec.options).some(function(o){return o.value===eskiSecim;}))sec.value=eskiSecim;
        var ust=UYE_MAX[tur]||1000;
        if(tur==="hukuk"&&Number(sec.value)>0){
          var oz=opt.find(function(z){return Number(z.id)===Number(sec.value);});
          if(oz)ust=Math.min(ust,Math.floor(Number(oz.tutar)*.60));
        }
        m.querySelector("#udLimit").textContent="Başvuru üst sınırı: "+tlYaz(ust)+
          (gerekli&&!opt.length?" · Uygun kanıtın henüz yok.":"")+
          " · Diğer üyelik ve bakiye şartları sunucuda kontrol edilir.";
        m.querySelector("#udTutar").max=ust;
        if(Number(input(m,"udTutar"))>ust||!Number(input(m,"udTutar")))
          m.querySelector("#udTutar").value=Math.max(100,Math.min(ust,1000));
      };
      m.querySelector("#udTur").onchange=yenile;
      m.querySelector("#udKanit").onchange=yenile;
      yenile();
      islem(m,"udBasvur",async function(){
        var tur=input(m,"udTur"),ref=input(m,"udKanit");
        if(["hukuk","egitim","gonullu"].includes(tur)&&!ref)throw new Error("Önce kanıtlanan harcamayı veya katılımı seç.");
        return API.rpc("dernek_uye_destek_basvur",{
          p_dernek:id,p_tur:tur,p_tutar:Number(input(m,"udTutar")),
          p_aciklama:input(m,"udGerekce"),p_referans:ref?Number(ref):null
        });
      },"Başvurun yönetim kuruluna iletildi.",function(){return stkUyeDestekEkrani(id);});
    }catch(err){toast(hataCevir(err.message||String(err)),true);}
  };

  window.stkUyeDestekKarar=async function(talep,id,onay){
    try{
      if(!await onayla(onay?"Dernek bütçesinden ödeme":"Başvuruyu reddet",
        onay?"Bu onay gerçek bir oyuncunun cüzdanına oyun TL aktarır. Yalnızca serbest dernek kasası kullanılacak. Devam edilsin mi?":
          "Üyenin bu yardım başvurusunu reddetmek istiyor musun?",
        onay?"Onayla ve aktar":"Reddet"))return;
      await API.rpc("dernek_uye_destek_karar",{p_basvuru:talep,p_onay:!!onay,p_gerekce:onay?null:"Dernek yönetimi tarafından uygun görülmedi."});
      toast(onay?"Yardım cüzdana aktarıldı ve muhasebeleştirildi.":"Başvuru reddedildi.");
      await stkUyeDestekEkrani(id);
    }catch(err){toast(hataCevir(err.message||String(err)),true);}
  };

  window.stkKampanyaAcModal = function (id) {
    var m = modal('<h3>Yardım kampanyası aç</h3><p class="alt">Oyuncuların bağışları yalnız seçilen sosyal amaç için kullanılabilir. Aynı anda en fazla dört açık kampanya.</p>' +
      alan("Kampanya türü",'<select id="sfTur">' + turOps(TUR) + '</select>') +
      alan("Başlık",'<input id="sfBaslik" maxlength="100" placeholder="Örnek: Muğla Hatıra Ormanı">') +
      alan("Açıklama",'<textarea id="sfAciklama" class="alanmetin" maxlength="1000" placeholder="Toplanan paranın nasıl kullanılacağını açıkla"></textarea>') +
      alan("Bağış hedefi (TL)",'<input id="sfHedef" type="number" step="1" min="1000" max="100000000" value="25000">') +
      alan("Süre (gün)",'<input id="sfGun" type="number" step="1" min="1" max="30" value="7">') +
      sorun + buton("Kampanyayı başlat","sfKaydet"));
    islem(m,"sfKaydet",function(){return API.rpc("dernek_kampanya_ac",{p_dernek:id,p_tur:input(m,"sfTur"),p_baslik:input(m,"sfBaslik"),
      p_aciklama:input(m,"sfAciklama"),p_hedef:Number(input(m,"sfHedef")),p_gun:Number(input(m,"sfGun"))});},"Kampanya yayımlandı.",function(){return stkFaaliyetEkrani(id);});
  };
  window.stkKampanyaBagisModal = function (kampanya,dernek,kalan) {
    var m = modal('<h3>Yardım kampanyasına bağış</h3><p class="alt">Bu bağış kampanya amacına ayrılır. Hedefe kalan: ' + tlYaz(kalan) + '</p>' +
      alan("Bağışın (TL)",'<input id="sfMiktar" type="number" min="100" step="1" max="' + kalan + '" value="' + Math.min(1000,kalan) + '">') +
      sorun + buton("Bağışı gerçekleştir","sfGonder"));
    islem(m,"sfGonder",function(){return API.rpc("dernek_kampanya_bagis",{p_kampanya:kampanya,p_tutar:Number(input(m,"sfMiktar"))});},
      "Bağışın kampanya hesabına kaydedildi.",function(){return stkFaaliyetEkrani(dernek);});
  };
  window.stkProjeModal = async function (id) {
    var d = D._stk, iller = d && d.id === id && Array.isArray(d.subeler) ? d.subeler.map(function(s){return {id:s.il_id,ad:s.il};}) : [];
    if (!iller.length) {
      try { var r = await API.rpc("dernek_faaliyetler",{p_dernek:id}); iller = r.subeler; }
      catch(err) { toast(hataCevir(err.message),true); return; }
    }
    var kampanya = [], fiyat = {};
    try { var pair = await Promise.all([API.rpc("dernek_faaliyetler",{p_dernek:id}),API.rpc("dernek_proje_fiyatlar")]);
      kampanya = pair[0].kampanyalar||[]; fiyat = pair[1]||{}; }
    catch(err) { toast(hataCevir(err.message),true); return; }
    var m = modal('<h3>Dernek bütçesiyle sosyal proje</h3><p class="alt">Faaliyet oyun içinde anında kaydedilir, bedeli kasadan düşer. 500 ve üzeri fidanla hatıra ormanı oluşur.</p>' +
      alan("Faaliyet",'<select id="sfTur">' + turOps(TUR) + '</select>') +
      alan("İl (şube şartı)",'<select id="sfIl">' + iller.map(function(x){return '<option value="' + x.id + '">' + e(x.ad) + '</option>';}).join("") + '</select>') +
      alan("Proje adı",'<input id="sfBaslik" maxlength="100" value="Dernek sosyal yardım projesi">') +
      alan("Adet",'<input id="sfAdet" type="number" min="1" max="5000" step="1" value="50">') +
      alan("Finansman",'<select id="sfKaynak"></select>') +
      '<p class="alt" id="sfMaliyet"></p>' + sorun + buton("Bütçeden harca ve gerçekleştir","sfYap"));
    var yenile = function () {
      var tur = input(m,"sfTur"), adet = Number(input(m,"sfAdet"));
      var kaynak = m.querySelector("#sfKaynak"), eski = kaynak.value;
      kaynak.innerHTML = '<option value="">Serbest dernek kasası</option>' +
        kampanya.filter(function(k){return k.tur===tur && Number(k.toplanan)>Number(k.harcanan);})
          .map(function(k){return '<option value="' + k.id + '">' + e(k.baslik) + ' · ' + tlYaz(k.toplanan-k.harcanan) + ' ayrılmış</option>';}).join("");
      if(Array.from(kaynak.options).some(function(x){return x.value===eski;})) kaynak.value=eski;
      var unit = Number(fiyat[tur]||0);
      m.querySelector("#sfMaliyet").textContent = 'Birim maliyet: ' + tlYaz(unit) + ' · Toplam maliyet: ' +
         (Number.isSafeInteger(adet) && adet>0 && adet<=5000 ? tlYaz(unit*adet) : 'Geçersiz adet') +
         (tur==="agac" ? " · 50+ fidan, 500+ hatıra ormanı" : "");
    };
    m.querySelector("#sfTur").onchange=yenile; m.querySelector("#sfAdet").oninput=yenile; yenile();
    islem(m,"sfYap",async function(){
      var tur = input(m,"sfTur"), adet = Number(input(m,"sfAdet"));
      if(!Number.isSafeInteger(adet)||adet<1||adet>5000||tur==="agac"&&adet<50) throw new Error(tur==="agac" ? "Ağaçlandırma en az 50 fidan gerektirir." : "Adet 1-5000 olmalı.");
      var maliyet = adet*Number(fiyat[tur]||0);
      if(!maliyet || !await onayla("Sosyal proje harcaması",tlYaz(maliyet) + " dernek kasasından düşülecek. Bu işlemi onaylıyor musun?","Harca ve uygula")) return null;
      return API.rpc("dernek_proje_yap",{p_dernek:id,p_tur:tur,p_il:Number(input(m,"sfIl")),p_adet:adet,p_baslik:input(m,"sfBaslik"),
        p_kampanya:input(m,"sfKaynak")?Number(input(m,"sfKaynak")):null});
    },"Sosyal proje gerçekleştirildi.",function(r){if(r) return stkFaaliyetEkrani(id);});
  };
  window.stkProgramModal = async function (id) {
    try {
      var sonuc = await Promise.all([API.rpc("dernek_faaliyetler",{p_dernek:id}),API.rpc("dernek_program_katalog")]);
      var dernek = sonuc[0], katalog = Array.isArray(sonuc[1]) ? sonuc[1] : [];
      var iller = Array.isArray(dernek.subeler) ? dernek.subeler : [];
      if(!dernek.yetkili) throw new Error("Bu harcamayı sadece dernek yönetimi yapabilir.");
      if(!iller.length || !katalog.length) throw new Error("Hizmet seçeneği ya da dernek şubesi bulunamadı.");
      var m = modal('<h3>Dernek sosyal hizmet programı</h3>' +
        '<p class="alt">Seçtiğin şehirde 7 gün süren hizmet başlatılır. Para yalnız serbest dernek kasasından düşer; kampanyalara tahsisli bağışlara dokunulmaz. Aynı anda en fazla 4 hizmet yürütülebilir.</p>' +
        '<div class="kv"><span class="k">Serbest dernek bütçesi</span><b>' + tlYaz(dernek.serbest) + '</b></div>' +
        alan("Hizmet ve bütçe paketi",'<select id="sfProgramTur">' + katalog.map(function(x,i){
          return '<option value="' + i + '">' + e(x.ad) + ' · ' + (x.paket===1?'Küçük':x.paket===2?'Orta':'Büyük') + ' paket</option>';
        }).join("") + '</select>') +
        alan("Hizmet verilecek il",'<select id="sfProgramIl">' + iller.map(function(x){
          return '<option value="' + Number(x.id) + '">' + e(x.ad) + '</option>';
        }).join("") + '</select>') +
        '<p class="alt" id="sfProgramAciklama"></p>' +
        '<div class="kv"><span class="k">7 günlük toplam gider</span><b id="sfProgramUcret"></b></div>' +
        '<div class="kv"><span class="k">Hizmet kapasitesi</span><b id="sfProgramKapasite"></b></div>' +
        '<div class="kv"><span class="k">Tahmini şehir gelişimi / memnuniyet katkısı</span><b id="sfProgramEtki"></b></div>' +
        '<p class="kucuk">Şehir üzerindeki gerçek etki tekrar edilen faaliyetlerde azalır. Program ücretleri oyun ekonomisine göre hesaplanır. Gönüllüler ayrıca katılabilir.</p>' +
        sorun + buton("Bütçeden karşıla ve başlat","sfProgramBaslat"));
      var secili = function(){return katalog[Number(input(m,"sfProgramTur"))];};
      var yenile = function(){
        var z=secili(); if(!z) return;
        m.querySelector("#sfProgramAciklama").textContent=z.aciklama;
        m.querySelector("#sfProgramUcret").textContent=tlYaz(z.ucret);
        m.querySelector("#sfProgramKapasite").textContent=Number(z.hedef).toLocaleString("tr-TR")+" kişi";
        m.querySelector("#sfProgramEtki").textContent="+"+z.gelisim+" / +"+z.memnuniyet;
        m.querySelector("#sfProgramBaslat").disabled=Number(z.ucret)>Number(dernek.serbest);
      };
      m.querySelector("#sfProgramTur").onchange=yenile;
      yenile();
      islem(m,"sfProgramBaslat",async function(){
        var z=secili();
        if(!z) throw new Error("Hizmet seçimi geçersiz.");
        if(!await onayla("Dernek bütçesinden hizmet",e(z.ad)+" için "+tlYaz(z.ucret)+" harcanacak. Program 7 gün sürecek. Onaylıyor musun?","Harca ve başlat")) return null;
        return API.rpc("dernek_program_baslat",{p_dernek:id,p_tur:z.tur,p_paket:Number(z.paket),p_il:Number(input(m,"sfProgramIl"))});
      },"Sosyal hizmet başlatıldı. Şehir etkisi kaydedildi.",function(){return stkFaaliyetEkrani(id);});
    }catch(err){toast(hataCevir(err.message||String(err)),true);}
  };
  window.stkProgramGonulluKatil = async function(programId,dernekId){
    try{
      await API.rpc("dernek_program_katil",{p_program:programId});
      toast("Gönüllü katılımın kaydedildi. Derneğin etki puanı arttı.");
      return stkFaaliyetEkrani(dernekId);
    }catch(err){toast(hataCevir(err.message||String(err)),true);}
  };
  window.stkEtkinlikModal = function (id) {
    var d = D._stk;
    var load = async function() {
      var iller = d && d.id === id ? d.subeler.map(function(x){return {id:x.il_id,ad:x.il};}) :
        (await API.rpc("dernek_faaliyetler",{p_dernek:id})).subeler;
      var m = modal('<h3>Gönüllü etkinliği oluştur</h3><p class="alt">Şubenin bulunduğu ildeki tüm oyuncular katılabilir. Etkinlik 2 saat sürer.</p>' +
        alan("Etkinlik türü",'<select id="sfTur">' + turOps(GON) + '</select>') +
        alan("İl",'<select id="sfIl">' + iller.map(function(x){return '<option value="' + x.id + '">' + e(x.ad) + '</option>';}).join("") + '</select>') +
        alan("Başlık",'<input id="sfBaslik" maxlength="100" placeholder="Örnek: Kıyı temizliği gönüllüleri">') +
        alan("Açıklama",'<textarea id="sfAciklama" class="alanmetin" maxlength="1000"></textarea>') +
        alan("Başlangıç · Türkiye saati",'<input id="sfTarih" type="datetime-local" value="' + tarihGir(1) + '">') +
        sorun + buton("Etkinliği duyur","sfKaydet"));
      islem(m,"sfKaydet",function(){return API.rpc("dernek_etkinlik_ac",{p_dernek:id,p_tur:input(m,"sfTur"),p_il:Number(input(m,"sfIl")),
        p_baslik:input(m,"sfBaslik"),p_aciklama:input(m,"sfAciklama"),p_bas:tarihApi(input(m,"sfTarih"))});},
        "Gönüllü etkinliği duyuruldu.",function(){return stkFaaliyetEkrani(id);});
    };
    load().catch(function(err){toast(hataCevir(err.message),true);});
  };
  window.stkGonulluKatil = async function (etkinlik,id) {
    try { await API.rpc("dernek_gonullu_katil",{p_etkinlik:etkinlik}); toast("Gönüllü katılımın kaydedildi."); stkFaaliyetEkrani(id); }
    catch(err){toast(hataCevir(err.message),true);}
  };
  window.stkZiyaretModal = async function (id) {
    try {
      var partiler = await API.rpc("partiler");
      var m = modal('<h3>Parti ziyareti talep et</h3><p class="alt">Talep parti genel başkanına bildirilir. Kabul edilirse belirlenen tarihte ziyaret gerçekleştirilebilir.</p>' +
        alan("Ziyaret edilecek parti",'<select id="sfParti">' + partiler.map(function(x){return '<option value="' + x.id + '">' + e(x.ad) + '</option>';}).join("") + '</select>') +
        alan("Ziyaret ve görüşme konusu",'<textarea id="sfKonu" class="alanmetin" maxlength="600" placeholder="Derneğin taleplerini ve görüşme gündemini yaz"></textarea>') +
        alan("Önerilen tarih · Türkiye saati",'<input id="sfTarih" type="datetime-local" value="' + tarihGir(1) + '">') +
        sorun + buton("Ziyaret talebini gönder","sfKaydet"));
      islem(m,"sfKaydet",function(){return API.rpc("dernek_ziyaret_teklif",{p_dernek:id,p_parti:Number(input(m,"sfParti")),
        p_konu:input(m,"sfKonu"),p_tarih:tarihApi(input(m,"sfTarih"))});},"Ziyaret talebi partiye iletildi.",function(){return stkFaaliyetEkrani(id);});
    } catch(err){toast(hataCevir(err.message),true);}
  };
  window.stkZiyaretYanit = async function(ziyaret,dernek,kabul) {
    try { await API.rpc("dernek_ziyaret_yanit",{p_ziyaret:ziyaret,p_kabul:kabul}); toast(kabul?"Ziyaret kabul edildi.":"Ziyaret reddedildi.");
      if(dernek) stkFaaliyetEkrani(dernek); else stkSosyalVitrin(); }
    catch(err){toast(hataCevir(err.message),true);}
  };
  window.stkZiyaretTamamla = async function(ziyaret,dernek) {
    if(!await onayla("Ziyareti tamamla","Görüşmenin gerçekleştiğini onaylıyorsun. Dernek ve parti bilgisi Gündem'e yansıyacak.","Tamamla")) return;
    try { await API.rpc("dernek_ziyaret_tamamla",{p_ziyaret:ziyaret}); toast("Parti ziyareti Gündem'e kaydedildi.");
      if(dernek) stkFaaliyetEkrani(dernek); else stkSosyalVitrin(); }
    catch(err){toast(hataCevir(err.message),true);}
  };
  window.stkSosyalVitrin = async function() {
    yukleniyor("Yardım kampanyaları");
    try {
      var res = await Promise.all([API.rpc("dernek_kampanya_vitrin"),API.rpc("dernek_ziyaret_taleplerim")]);
      var kampanya = res[0]||[], ziyaret = res[1]||[];
      var h = '<div class="kart"><h2>Dernekler · yardım ve sosyal etki</h2><p class="alt">Oyuncuların açık bağış kampanyalarını destekle, partin için gelen resmî ziyaret taleplerini yanıtla.</p></div>';
      if(ziyaret.length) h += '<div class="bolum-bas"><h2>Partine gelen ziyaret talepleri</h2></div>' + ziyaret.map(function(z){
        return '<div class="kart"><h3>' + e(z.dernek) + '</h3><p class="kucuk">' + e(z.parti) + ' · ' + tarihSaat(z.tarih) + '</p><p>' + e(z.konu) + '</p><span class="rozet">' + e(durumAd[z.durum]||z.durum) + '</span>' +
          (z.durum==="bekliyor" ? '<div class="vit-dugme"><button class="btn ikinci" onclick="stkZiyaretYanit(' + z.id + ',null,true)">Kabul et</button><button class="btn tehlike" onclick="stkZiyaretYanit(' + z.id + ',null,false)">Reddet</button></div>' :
          z.durum==="kabul" && new Date(z.tarih).getTime()<=simdi() ? '<button class="btn altin" onclick="stkZiyaretTamamla(' + z.id + ',null)">Görüşmeyi tamamla</button>' : '') + '</div>';
      }).join("");
      h += '<div class="bolum-bas"><h2>Açık yardım kampanyaları</h2><span class="kucuk">' + kampanya.length + '</span></div>';
      h += kampanya.length ? kampanya.map(function(x){
        return '<div class="kart"><h3>' + e(x.baslik) + '</h3><p class="alt">' + e(x.dernek) + ' · ' + e(TUR[x.tur]||x.tur) + '</p>' +
          '<div class="kv"><span class="k">Toplanan / hedef</span><b>' + tlYaz(x.toplanan) + ' / ' + tlYaz(x.hedef) + '</b></div>' +
          '<button class="btn altin" onclick="stkKampanyaBagisModal(' + x.id + ',' + x.dernek_id + ',' + (Number(x.hedef)-Number(x.toplanan)) + ')">Bağış yap</button>' +
          '<button class="btn ikinci" onclick="ekranAc(()=>stkFaaliyetEkrani(' + x.dernek_id + '))">Derneğe git</button></div>';
      }).join("") : '<div class="kart"><p class="alt">Şu anda açık kampanya yok.</p></div>';
      iskelet("Sosyal etki ve yardımlar",h,{geri:true});
    } catch(err) { iskelet("Sosyal etki ve yardımlar",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true}); }
  };

  // Daha önceki menüleri bozmadan dernek detaylarına ve Dernekler ana sayfasına işlevsel giriş ekle.
  if(typeof iskelet==="function") {
    var eski = iskelet;
    window.iskelet = iskelet = function(baslik,govde,opt) {
      if(typeof govde==="string") {
        if(baslik==="Dernekler"||baslik==="Sivil toplum") {
          govde = '<div class="kart"><h2>🌱 Sosyal etki ve yardım merkezi</h2><p class="alt">Bağış kampanyaları, gönüllü etkinlikleri ve partilere gelen ziyaret talepleri.</p><button class="btn altin" onclick="ekranAc(stkSosyalVitrin)">Kampanyaları ve ziyaret taleplerini aç</button></div>' + govde;
        }
        if(window.D && D._stk && opt && opt.geri && baslik===e(D._stk.ad) && !D._stk.kapali) {
          govde = '<div class="kart"><h2>🌳 Dernek faaliyetleri ve üyelik destekleri</h2><p class="alt">Projeler, yardım kampanyaları, gönüllüler ve doğrudan üyelerin oyun cüzdanlarına ödenen yardımlar.</p>' +
            '<div class="vit-dugme"><button class="btn altin" onclick="ekranAc(()=>stkFaaliyetEkrani(' + Number(D._stk.id) + '))">Sosyal faaliyetler</button>' +
            (D._stk.rolum?'<button class="btn canli" onclick="ekranAc(()=>stkUyeDestekEkrani(' + Number(D._stk.id) + '))">Üye destekleri</button>':'') +
            '</div></div>' + govde;
        }
      }
      return eski.call(this,baslik,govde,opt);
    };
  }
})();