/* 25.10.2026 — İnternet bankacılığı ve şirket kârı yönlendirme ekranı.
   Oyuncu bakiyelerine dokunmaz; banka işlemleri mevcut RPC'leri kullanır. */
(function(){
  if(window.__hesapDuzeltmeleri2510)return;
  window.__hesapDuzeltmeleri2510=true;

  function safe(x){return typeof e==="function"?e(String(x==null?"":x)):String(x==null?"":x).replace(/[&<>"']/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];});}
  function para(x){return typeof tlYaz==="function"?tlYaz(Number(x)||0):(Number(x)||0).toLocaleString("tr-TR")+" ₺";}
  function hata(x){var s=x&&x.message?x.message:String(x||"Beklenmeyen hata");return typeof hataCevir==="function"?hataCevir(s):s;}
  function btn(yazi,action,klass){return '<button type="button" class="btn '+(klass||"ikinci")+'" onclick="'+action+'">'+safe(yazi)+'</button>';}
  function kutu(bas,icerik){return '<section class="kart"><h2>'+safe(bas)+'</h2>'+icerik+'</section>';}
  function ac(fn){if(typeof window[fn]==="function"){ekranAc(window[fn]);}else{toast("Bu işlem henüz yüklenemedi. Oyunu yenileyip tekrar dene.",true);}}
  window.ibAc=function(ad){ac(ad);};
  window.internetBankaciligiEkrani=async function(){
    yukleniyor("İnternet bankacılığı");
    var istekler=await Promise.allSettled([
      API.rpc("banka"),API.rpc("oyb_liste"),API.rpc("oyb_portfoy"),API.rpc("internet_banka_hesaplarim")
    ]);
    var veri=istekler.map(function(r){return r.status==="fulfilled"?r.value:null;});
    if(!veri.some(function(v){return v!==null;})){
      return iskelet("İnternet bankacılığı",kutu("Bağlantı sorunu",'<p class="alt">'+safe(hata(istekler[0].reason))+'</p>'+btn("Yeniden dene","internetBankaciligiEkrani()","altin")),{geri:true});
    }
    var devlet=veri[0],liste=(veri[1]&&veri[1].bankalar)||[];
    var portfoy=veri[2]||{}, hesaplar=Array.isArray(veri[3])?veri[3]:[];
    var hesapIds=new Set(hesaplar.map(function(a){return Number(a.banka_id);}));
    var toplamHesap=hesaplar.length+1;
    var html='<p class="alt">Devlet bankası ve özel bankalardaki hesaplarını bu ekrandan yönetebilirsin.</p>';
    var govContent=devlet
      ?'<div class="kv"><span>Vadesiz bakiye</span><b>'+para(devlet.vadesiz&&devlet.vadesiz.bakiye)+'</b></div>'+
       '<div class="kv"><span>Toplam mevduat</span><b>'+para(devlet.mevduat)+'</b></div>'
      :'<p class="alt">Devlet bankası bilgileri yüklenemedi.</p>';
    html+=kutu("Devlet Bankası",govContent+btn("Devlet bankasına gir","ibAc('bankaEkrani')","altin"));
    var own='';
    if(hesaplar.length){
      hesaplar.forEach(function(h){
        var b=liste.find(function(x){return Number(x.id)===Number(h.banka_id);});
        own+='<div class="kv"><span><b>'+safe(h.ad||b&&b.ad||"Özel banka")+'</b><span class="kucuk" style="display:block">Aktif vadesiz hesap</span></span><span class="rozet yesil">Açık</span></div>';
      });
    }else own='<p class="alt">Henüz özel bankada açık hesabın yok.</p>';
    html+=kutu("Özel banka hesaplarım ("+hesaplar.length+")",own+btn("Özel banka işlemlerine git","ibAc('oyuncuBankaEkrani')","altin"));
    var active=(portfoy.mevduatlar||[]).filter(function(v){return !v.kapandi;});
    var kredi=(portfoy.krediler||[]).filter(function(k){return k.durum==="aktif"||k.durum==="gecikmis";});
    var vadeli=active.length?active.map(function(v){return '<div class="kv"><span>'+safe(v.banka)+' <span class="kucuk">'+safe(v.durum||"aktif")+'</span></span><b>'+para(v.anapara)+'</b></div>';}).join(""):'<p class="alt">Aktif özel banka vadeli mevduatın yok.</p>';
    html+=kutu("Vadeli mevduatlarım ("+active.length+")",vadeli+btn("Vadeli hesapları yönet","ibAc('oyuncuBankaEkrani')"));
    var borc=kredi.length?kredi.map(function(k){return '<div class="kv"><span>'+safe(k.banka)+' <span class="kucuk">'+safe(k.durum)+'</span></span><b>'+para(k.kalan)+'</b></div>';}).join(""):'<p class="alt">Aktif özel banka kredin bulunmuyor.</p>';
    html+=kutu("Kredilerim ("+kredi.length+")",borc+btn("Kredi detayları ve ödemeler","ibAc('oyuncuBankaEkrani')"));
    var banks=liste.filter(function(b){return !hesapIds.has(Number(b.id));});
    if(banks.length){
      var bhtml='<p class="alt">Özel bankalarda hesap açmadan kart, POS ve kredi başvurusu yapılamaz.</p>';
      banks.forEach(function(b){
        bhtml+='<div class="kv"><span><b>'+safe(b.ad)+'</b><span class="kucuk" style="display:block">Banka kasası '+para(b.kasa)+'</span></span><button class="btn ikinci" type="button" onclick="ibHesapAc('+Number(b.id)+')">Hesap aç</button></div>';
      });
      html+=kutu("Hesap açabileceğin bankalar",bhtml);
    }
    html+=kutu("Kart, POS ve transfer",btn("Kredi kartlarım","ibAc('kartlarimEkrani')")+
      btn("POS cihazlarım / başvurularım","ibAc('posBankaEkrani')")+
      btn("Banka transferi","paraGonderModal()"));
    var errors=istekler.filter(function(r){return r.status==="rejected";});
    if(errors.length)html+='<p class="alt" role="alert">Bazı banka bilgileri alınamadı: '+safe(hata(errors[0].reason))+'. Yeniden denemek için ekranı yenile.</p>';
    html+=btn("Bilgileri yenile","internetBankaciligiEkrani()");
    iskelet("İnternet bankacılığı",html,{geri:true});
  };
  window.bankacilikMerkeziEkrani=window.internetBankaciligiEkrani;
  window.ibHesapAc=async function(id){
    if(!Number.isSafeInteger(Number(id))||Number(id)<=0){toast("Geçersiz banka.",true);return;}
    if(typeof onayla==="function"&&!await onayla("Özel banka hesabı aç","Bu bankada kendi adına vadesiz hesap açılacak.","Hesap aç"))return;
    try{await API.rpc("oyb_hesap_ac",{p_banka:Number(id)});toast("Banka hesabın açıldı.");await internetBankaciligiEkrani();}
    catch(ex){toast(hata(ex),true);}
  };
  window.sirketKarTercihEkrani=async function(tekSirket){
    yukleniyor("Şirket kârı tercihlerim");
    try{
      var cevap=await Promise.all([API.rpc("sirket_liste"),API.rpc("sirket_kar_tercihleri")]);
      var sirketler=(cevap[0].sirketler||[]).filter(function(s){return !tekSirket||Number(s.id)===Number(tekSirket);});
      var tercihler=Array.isArray(cevap[1])?cevap[1]:[];
      var html='<p class="alt">Her şirket için kârın kendi payına düşen kısmının nereye aktarılacağını seçebilirsin. Değişiklik bundan sonraki hesaplamalara uygulanır; geçmişte kasada birikmiş tutarlar otomatik olarak şahsi cüzdana geçmez.</p>';
      if(!sirketler.length)html+='<div class="kart"><p class="alt">Bu şirkette ortaklık kaydın bulunamadı.</p></div>';
      sirketler.forEach(function(s){
        var t=tercihler.find(function(x){return Number(x.sirket_id)===Number(s.id);});
        var kasa=t&&t.kar_kasada===true;
        var secim='<div class="kv"><span>Mevcut tercihim</span><b>'+(kasa?'Şirket kasasında biriksin':'Şahsi cüzdanıma geçsin')+'</b></div>';
        secim+='<p class="alt">Şirket kasası '+para(s.kasa)+' · Ortaklık payım %'+safe(s.pay)+'</p>';
        secim+='<div class="satir" id="karTercih_'+Number(s.id)+'">'+
          btn((kasa?'✓ ':'')+"Şirket kasasında biriksin","sirketKarBirikimKaydet("+Number(s.id)+",true)",kasa?"altin":"ikinci")+
          btn((!kasa?'✓ ':'')+"Şahsi cüzdanıma geçsin","sirketKarBirikimKaydet("+Number(s.id)+",false)",!kasa?"altin":"ikinci")+
          '</div>';
        html+=kutu(s.ad,secim);
      });
      iskelet("Şirket kârı tercihlerim",html,{geri:true});
    }catch(ex){
      iskelet("Şirket kârı tercihlerim",kutu("İşlem yüklenemedi",'<p class="alt">'+safe(hata(ex))+'</p>'+btn("Tekrar dene","sirketKarTercihEkrani()")),{geri:true});
    }
  };
  window.sirketKarBirikimKaydet=async function(id,kasada){
    var bar=document.getElementById("karTercih_"+Number(id));
    if(bar){bar.querySelectorAll("button").forEach(function(b){b.disabled=true;});}
    try{
      var sonuc=await API.rpc("sirket_kar_birikim_ayarla",{p_sirket:Number(id),p_kasada:!!kasada});
      if(!sonuc||sonuc.kar_kasada!==!!kasada)throw new Error("Kâr tercihi doğrulanamadı.");
      toast(kasada?"Kâr bundan sonra şirket kasasında birikecek.":"Kâr bundan sonra şahsi cüzdanına geçecek.");
      await sirketKarTercihEkrani(Number(id));
    }catch(ex){toast(hata(ex),true);if(bar)bar.querySelectorAll("button").forEach(function(b){b.disabled=false;});}
  };
  // Operasyon merkezinin yeni şirket detayı için doğrudan giriş.
  if(typeof window.sirketPortfoyDetay==="function"){
    var eskiDetay=window.sirketPortfoyDetay;
    window.sirketPortfoyDetay=async function(id){
      var sonuc=await eskiDetay.apply(this,arguments);
      var e0=document.querySelector(".so-detail");
      if(e0&&!document.getElementById("karKisaYol_"+Number(id))){
        var bt=document.createElement("button");
        bt.type="button";bt.className="btn ikinci";bt.id="karKisaYol_"+Number(id);
        bt.textContent="Kâr kasada mı, cüzdanda mı biriksin? Ayarla";
        bt.onclick=function(){ekranAc(function(){sirketKarTercihEkrani(Number(id));});};
        e0.appendChild(bt);
      }
      return sonuc;
    };
  }
})();
