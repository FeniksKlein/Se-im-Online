/* Dernekler: sosyal faaliyet, bağış kampanyası ve parti ziyaretleri. */
(function () {
  if (window.STK_FAALIYET_MODUL) return;
  window.STK_FAALIYET_MODUL = true;

  var TUR = {agac:"Ağaçlandırma / hatıra ormanı", gida:"Gıda yardımı", burs:"Öğrenci bursu", hayvan:"Sokak hayvanları", temizlik:"Çevre temizliği", kultur:"Kültür ve sanat"};
  var GON = {fidan:"Fidan dikimi", temizlik:"Çevre temizliği", gida:"Yardım dağıtımı", egitim:"Eğitim gönüllülüğü", hayvan:"Hayvan bakımı", kultur:"Kültür buluşması"};
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
      var sonuc = await Promise.all([API.rpc("dernek_faaliyetler",{p_dernek:id}),API.rpc("dernek_detay",{p_dernek:id})]);
      var r = sonuc[0], rolum = sonuc[1] && sonuc[1].rolum;
      var kamp = Array.isArray(r.kampanyalar) ? r.kampanyalar : [];
      var proj = Array.isArray(r.projeler) ? r.projeler : [];
      var etkin = Array.isArray(r.etkinlikler) ? r.etkinlikler : [];
      var ziyaret = Array.isArray(r.ziyaretler) ? r.ziyaretler : [];
      var acik = kamp.filter(function(k) {return k.acik;}).length;
      var h = '<div class="kart"><h2>Dernek sosyal faaliyet merkezi</h2><p class="alt">' + e(r.ad) + ' · Sanal oyun dünyasındaki faaliyetler, gerçek dünyada dikim veya yardım yapıldığı anlamına gelmez.</p>' +
        '<div class="kv"><span class="k">Toplam kasa</span><b>' + tlYaz(r.kasa) + '</b></div>' +
        '<div class="kv"><span class="k">Serbest harcama bütçesi</span><b>' + tlYaz(r.serbest) + '</b></div>' +
        '<div class="kv"><span class="k">Amaçlı kampanyalara ayrılan</span><b>' + tlYaz(Math.max(0,Number(r.kasa)-Number(r.serbest))) + '</b></div>' +
        '<div class="kv"><span class="k">Açık kampanya</span><b>' + acik + '</b></div></div>';
      if (r.yetkili) h += '<div class="kart"><h2>Yeni faaliyet</h2>' +
        '<div class="vit-dugme"><button class="btn canli" onclick="stkProjeModal(' + id + ')">🌳 Ağaçlandır / Yardım yap</button><button class="btn altin" onclick="stkKampanyaAcModal(' + id + ')">Bağış kampanyası aç</button></div>' +
        '<div class="vit-dugme"><button class="btn ikinci" onclick="stkEtkinlikModal(' + id + ')">Gönüllü etkinliği düzenle</button><button class="btn ikinci" onclick="stkZiyaretModal(' + id + ')">Partiye ziyaret talep et</button></div></div>';
      if (rolum === 'baskan') h += '<div class="kart"><h2>Dernek kasasından para çek</h2><p class="alt">Yalnız serbest kasa çekilebilir. İşlem, gerekçesiyle birlikte dernek hesap hareketlerine ve Gündem\'e kaydedilir.</p>' +
         '<div class="kv"><span class="k">Çekilebilir tutar</span><b>' + tlYaz(r.serbest) + '</b></div>' +
         '<button class="btn altin" ' + (Number(r.serbest) < 1 ? 'disabled ' : '') + 'onclick="stkParaCekModal(' + id + ',' + Number(r.serbest) + ')">Kasadan para çek</button></div>';
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

  window.stkParaCekModal = function (id, serbest) {
    var m = modal('<h3>Dernek kasasından para çek</h3><p class="alt">Başkan olarak yalnız serbest kasadan kişisel cüzdanına para aktarabilirsin. Yardım kampanyalarına ayrılan para korunur. Çekim ve gerekçesi kayıt altındadır.</p>' +
      '<p class="kucuk">Çekilebilir: ' + tlYaz(serbest) + '</p>' +
      alan('Tutar (TL)', '<input id="sfParaTutar" type="number" min="1" max="' + Math.floor(serbest) + '" step="1">') +
      alan('Para çekme gerekçesi', '<textarea id="sfParaGerekce" maxlength="200" placeholder="Örn. Dernek yönetim giderinin karşılanması"></textarea>') +
      sorun + buton('Parayı cüzdanıma aktar', 'sfParaCek'));
    islem(m, 'sfParaCek', async function () {
      var tutar = Number(input(m,'sfParaTutar'));
      var gerekce = input(m,'sfParaGerekce').trim();
      if (!Number.isSafeInteger(tutar) || tutar < 1 || tutar > serbest) throw new Error('Tutar serbest kasa bakiyesini aşamaz.');
      if (gerekce.length < 5) throw new Error('İşlem gerekçesi en az 5 karakter olmalı.');
      if (!await onayla('Dernek kasasından para çek',tlYaz(tutar) + ' kişisel cüzdanına aktarılacak ve işlem Gündem\'de görülecek. Onaylıyor musun?', 'Parayı çek')) return null;
      return API.rpc('dernek_para_cek',{p_dernek:id,p_tutar:tutar,p_aciklama:gerekce});
    },'Dernek kasasından para cüzdanına aktarıldı.',function(){return stkFaaliyetEkrani(id);});
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
          govde = '<div class="kart"><h2>🌳 Dernek faaliyetleri</h2><p class="alt">Hatıra ormanı oluştur, yardım kampanyası aç, gönüllüleri topla, siyasi partilerle görüş.</p>' +
            '<button class="btn altin" onclick="ekranAc(()=>stkFaaliyetEkrani(' + Number(D._stk.id) + '))">Sosyal faaliyetler ve kampanyalar</button></div>' + govde;
        }
      }
      return eski.call(this,baslik,govde,opt);
    };
  }
})();