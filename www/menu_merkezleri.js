/* Seçim Online — Adliye ve Ekonomi sekmeli menüleri, 23.10.2026.
   Yalnız istemci navigasyonudur. Para, yetki, dava ve şirket işlemleri
   mevcut RPC ve ekranlarında kalır; oyuncu verisini değiştirmez. */
(function () {
  "use strict";
  if (window.SO_MENU_MERKEZLERI_V1) return;
  window.SO_MENU_MERKEZLERI_V1 = true;
  if (!document.getElementById('banka-yonetim-loader')) {
    var bankScript = document.createElement('script');
    bankScript.id = 'banka-yonetim-loader';
    bankScript.src = './banka_yonetim.js?v=20261023e';
    document.head.appendChild(bankScript);
  }

  var adliyeSekmeleri = [
    ["mahkeme", "Mahkeme"], ["avukatlar", "Avukatlar"], ["ofisler", "Avukat Ofisleri"],
    ["acik", "Açık Davalar"], ["itiraz", "İtirazlar"], ["biten", "Biten Davalar"],
    ["icra", "İcradan Satılıklar"], ["baro", "Baro"]
  ];
  var ekonomiSekmeleri = [
    ["genel", "Genel Bakış"], ["sirketlerim", "Şirketlerim"],
    ["bankalar", "Bankalar"], ["sirketler", "Şirketler"],
    ["piyasalar", "Piyasalar"], ["emlak", "Gayrimenkul"], ["giris","İş Dünyası"], ["islemler", "İşlemler"]
  ];
  var secim = { adliye:"mahkeme", ekonomi:"genel" };
  var istek = { adliye:0, ekonomi:0 };
  var adlVeri = null;
  var adlCache={html:null,data:null,at:0};
  var istCache={html:null,at:0};
  var esc = function(x){ return String(x == null ? "" : x).replace(/[&<>"']/g,function(y){
    return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[y];
  }); };
  var trPara = function(x){ return Number(x || 0).toLocaleString("tr-TR",{maximumFractionDigits:0}) + " ₺"; };
  var tarih = function(x){ return x ? new Date(x).toLocaleString("tr-TR") : "—"; };
  var kart = function(bas, govde){ return '<section class="kart so-panel"><h2>'+bas+'</h2>'+govde+'</section>'; };
  var bos = function(yazi){ return '<div class="kart so-bos">'+esc(yazi)+'</div>'; };
  var chip = function(n, bas){ return '<div class="so-stat"><b>'+esc(n)+'</b><small>'+esc(bas)+'</small></div>'; };
  var link = function(ikon, ad, aciklama, hedef, meta){
    return '<button type="button" class="so-link" onclick="'+hedef+'"><span class="so-link-ikon" aria-hidden="true">'+ikon+'</span>'
      +'<span class="so-link-orta"><b>'+esc(ad)+'</b><small>'+esc(aciklama)+'</small></span>'
      +(meta?'<span class="so-link-meta">'+esc(meta)+'</span>':'')+'<span class="so-ok" aria-hidden="true">›</span></button>';
  };
  var grids = function(dizi){ return '<div class="so-grid">'+dizi.join("")+'</div>'; };
  var baslik = function(bas, acik){ return '<div class="so-bas"><b>'+bas+'</b><p>'+acik+'</p></div>'; };


  /* İşlem Bul: kullanıcı hangi sekmede olduğuna bakmadan doğru işleme ulaşır. */
  var aramaIndeksi = {
    adliye:[
      ["⚖️","Dava aç","Avukatla dava başvurusu, delil ve davalı","adlDavaModal()","mahkeme hukuk dava aç"],
      ["📂","Açık davalar","Devam eden yargılama ve duruşmalar","soMenuSec('adliye','acik')","dava dosya duruşma"],
      ["📜","Biten davalar","Kararlar ve kapanan dosyalar","soMenuSec('adliye','biten')","sonuç kesin hüküm"],
      ["📝","İtiraz edilen davalar","İstinaf, jüri ve seçim itirazları","soMenuSec('adliye','itiraz')","istinaf şikayet"],
      ["👩‍⚖️","Avukatlar","Ruhsat, kontenjan ve başarı yüzdeleri","soMenuSec('adliye','avukatlar')","hukuk akademi sınav staj"],
      ["🏢","Avukat ofisleri","Hukuk büroları, vekalet ve ücretler","soMenuSec('adliye','ofisler')","büro vekil avukat"],
      ["🏛️","Türkiye Barosu","Levhaya kayıt, disiplin ve üyelik","soMenuSec('adliye','baro')","baro adli yardım aidat"],
      ["🔨","İcradan satılıklar","Elektronik haciz satışları, açık artırmalar","soMenuSec('adliye','icra')","haciz e-satış mal"],
      ["📁","İcra dosyaları","Ödeme emirleri, alacak ve itiraz","soMenuGit('icraMerkeziEkrani')","icra takip borç"],
      ["⚖️","Yüksek Mahkeme","Yargıçlar ve yargı yönetimi","soMenuSec('adliye','mahkeme')","mahkeme hakim"]
    ],
    ekonomi:[
      ["🏢","Şirketlerim","Kasaya para, şubelerim, inşaat ve finans","soMenuSec('ekonomi','sirketlerim')","müteahhit firma kasa sermaye"],
      ["🏛️","İnternet Bankacılığı","Tüm hesaplarım, kart ve krediler","soMenuGit('internetBankaciligiEkrani')","devlet bankası mevduat"],
      ["🏦","Oyuncu bankaları","Özel bankalar, kredi ve faizler","soMenuGit('bankaRehberiEkrani')","özel banka kredi"],
      ["💳","Kredi kartlarım","Kart limitleri, ekstre, hesap kesimi, borç","soMenuGit('kartlarimEkrani')","kredi kartı borç"],
      ["🏪","POS ve kartlı satış","Şirketime POS, kartla ödeme","soMenuGit('kartPosEkrani')","pos cihazı komisyon"],
      ["🧾","Çek defteri","Çek al, yaz, ciro et, öde","soMenuGit('cekMerkeziAc')","çek karnesi vadeli çek"],
      ["💸","Para gönder","Banka havalesi ve oyuncuya ödeme","soMenuGit('paraGonderModal')","havale transfer"],
      ["💰","Şirket kasasına para yatır","Şirketini seçerek sermaye ve nakit ekle","soMenuSec('ekonomi','sirketlerim')","para koy kasa"],
      ["🏗️","İnşaat ve şube yönetimi","Arsa, ruhsat, projeler ve şube açma","soMenuSec('ekonomi','sirketlerim')","müteahhit bina maliyet"],
      ["📒","Tüm Banka Hesaplarım","Banka hesapları ve borçlarım","soMenuGit('internetBankaciligiEkrani')","vadeli borç faiz"],
      ["➕","Yeni şirket kur","Sektör, şehir ve kuruluş sermayesi","soMenuGit('sirketKurulumFormuAc')","şirket işletme"],
      ["🤝","Şirket ortaklıkları","Ortak ekle, çıkar, hisse devret","soMenuGit('ortaklikEkrani')","ortaklık"],
      ["📈","Hisse pazarı","Hisse al, sat ve yatırım yap","soMenuGit('sirketHissePazariEkrani')","borsa"],
      ["🚀","Halka arzlar","Yeni hisse alımları ve sonuçlar","soMenuGit('halkaArzPazarEkrani')","halka arz"],
      ["🏡","Gayrimenkul pazarı","Arsa, daire ve dükkan tapuları","soMenuGit('yatirimPazarEkrani')","mülk tapu kira"],
      ["🏪","Toptan ticaret","Şirketler arası ürün ve mal alım satımı","soMenuGit('kamuToptanEkrani')","mal stok"],
      ["🧾","İşlem geçmişim","Alım satım hareketlerim","soMenuGit('ticaretGecmisimEkrani')","rapor fatura"],
      ["📋","Kamu ihaleleri","Belediye ve devlet ihaleleri","soMenuGit('ihaleEkrani')","ihale teklif"],
      ["🛡️","Sigorta ve hasar","Poliçe, hasar ve işyeri sigortası","soMenuGit('msSigortaAc')","sigorta"]
    ]
  };
  function norm(s){return String(s||"").toLocaleLowerCase("tr-TR").normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/ı/g,"i");}
  function aramaKutusu(grup){
    return '<div class="so-menu-arama"><span aria-hidden="true">⌕</span><input type="search"'
      +' aria-label="Menülerde işlem ara" placeholder="'+(grup==="adliye"?"Dava, avukat, istinaf, icra ara…":"Şirket, POS, çek, kredi, inşaat ara…")+'"'
      +' autocomplete="off" oninput="soMenuIslemAra(this.value,\''+grup+'\')" /></div>'
      +'<div id="so-menu-sonuclar" class="so-menu-sonuclar" aria-live="polite" hidden></div>';
  }
  window.soMenuIslemAra=function(yazi,grup){
    var kutu=document.getElementById("so-menu-sonuclar");if(!kutu)return;
    var q=norm(String(yazi||"").trim());if(!q){kutu.innerHTML="";kutu.hidden=true;return;}
    var liste=(aramaIndeksi[grup]||[]).filter(function(x){return norm(x[1]+" "+x[2]+" "+x[4]).includes(q);}).slice(0,7);
    kutu.hidden=false;
    kutu.innerHTML='<div class="so-arama-bas">Arama sonuçları · '+liste.length+'</div>'
      +(liste.map(function(x){return link(x[0],x[1],x[2],x[3]);}).join("")
        ||'<div class="so-bos">Buna uygun işlem bulunamadı. Başka bir kelime dene.</div>');
  };
  window.soMenuSirketAra=function(yazi){
    var q=norm(yazi);
    document.querySelectorAll("#so-sirket-liste .so-company").forEach(function(b){
      b.style.display=norm(b.textContent).includes(q)?"":"none";
    });
  };

  function stil(){
    if(document.getElementById("so-menu-style"))return;
    var s=document.createElement("style");s.id="so-menu-style";
    s.textContent=
      '.so-tabs{display:flex;gap:6px;overflow-x:auto;overscroll-behavior-x:contain;scrollbar-width:none;'
      +'padding:5px 4px 7px;margin:0 0 14px;border-radius:15px;background:var(--panel2,#141b38);'
      +'border:1px solid var(--line,#2f3555);-webkit-overflow-scrolling:touch;position:sticky;top:0;z-index:6}'
      +'.so-tabs::-webkit-scrollbar{display:none}'
      +'.so-tabs button{white-space:nowrap;flex:0 0 auto;min-height:40px;border:1px solid transparent;border-radius:12px;'
      +'padding:8px 12px;background:transparent;color:var(--txt2,#929bb8);font-size:13.5px;font-weight:750;cursor:pointer}'
      +'.so-tabs button[aria-selected="true"]{color:var(--txt,#fff);background:var(--panel,#293359);'
      +'border-color:var(--line2,#46527d);box-shadow:0 2px 7px #0003}'
      +'.so-menu-hero{padding:15px 16px;margin-bottom:12px;border:1px solid var(--line2,#3a446f);'
      +'border-radius:17px;background:linear-gradient(135deg,var(--panel,#263058),var(--panel2,#101936));}'
      +'.so-menu-hero h2{font-size:20px;margin:0 0 4px;line-height:1.2}'
      +'.so-menu-hero p{font-size:13px;color:var(--txt2,#a5aec7);line-height:1.5;margin:0}'
      +'.so-bas{display:flex;flex-direction:column;gap:3px;margin:14px 2px 10px}'
      +'.so-bas b{font-size:16px}.so-bas p{font-size:12.5px;color:var(--txt2);margin:0;line-height:1.45}'
      +'.so-grid{display:grid;grid-template-columns:minmax(0,1fr);gap:8px;margin-bottom:12px}'
      +'.so-link{display:flex;align-items:center;gap:12px;width:100%;padding:13px 12px;border-radius:14px;'
      +'background:var(--panel,#212b4b);border:1px solid var(--line2,#343d63);color:var(--txt,#fff);'
      +'text-align:left;cursor:pointer;min-height:69px;min-width:0}'
      +'.so-link:active{transform:scale(.992);border-color:var(--ink2,#9b87ff)}'
      +'.so-link-ikon{width:38px;height:38px;flex:0 0 38px;border-radius:11px;display:flex;align-items:center;'
      +'justify-content:center;background:var(--panel2,#111936);font-size:20px}'
      +'.so-link-orta{min-width:0;flex:1}.so-link-orta b{font-size:14.5px;display:block;line-height:1.3}'
      +'.so-link-orta small{display:block;color:var(--txt2,#abb3cc);font-size:12px;line-height:1.45;margin-top:4px}'
      +'.so-link-meta{font-weight:800;font-size:12px;color:var(--ink2,#a999ff);white-space:nowrap}'
      +'.so-ok{font-size:25px;flex:0 0 auto;color:var(--txt2,#a1abc7)}'
      +'.so-stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-bottom:12px}'
      +'.so-stat{padding:12px 6px;text-align:center;background:var(--panel,#1c2546);border:1px solid var(--line2);border-radius:12px}'
      +'.so-stat b{display:block;font-size:21px;color:var(--txt,#fff)}.so-stat small{display:block;font-size:11px;'
      +'color:var(--txt2,#a4adc7);margin-top:4px}'
      +'.so-panel{margin-bottom:12px}.so-panel h2{font-size:16px;margin-bottom:10px}'
      +'.so-bos{text-align:center;color:var(--txt2,#a0a9c1);padding:22px 12px;line-height:1.5}'
      +'.so-action{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}'
      +'.so-action .btn{margin:0;flex:1;min-width:125px}'
      +'.so-ara{box-sizing:border-box;width:100%;margin:0 0 11px;padding:12px;border-radius:12px;'
      +'border:1px solid var(--line2,#35406b);background:var(--panel,#202948);color:var(--txt,#fff);font-size:16px}'
      +'.so-dava{margin:0 0 10px}.so-dava .kart{margin:0}'
      +'.so-note{font-size:12px;line-height:1.5;color:var(--txt2,#a2abc3);margin:8px 2px 13px}'
      +'.so-company{display:block;width:100%;text-align:left;background:var(--panel,#222b4a);'
      +'border:1px solid var(--line2,#3b456e);border-radius:16px;color:var(--txt,#fff);padding:15px;margin:8px 0;cursor:pointer}'
      +'.so-company b{display:block;font-size:16px}.so-company small{display:block;color:var(--txt2);margin-top:5px}'
      +'.so-company strong{display:block;margin-top:12px;font-size:14px}'
      +'.so-menu-arama{display:flex;align-items:center;gap:10px;margin:-2px 0 14px;padding:0 12px;'
      +'border:1px solid var(--line2,#394365);border-radius:12px;background:var(--panel,#202948);color:var(--txt2,#abb3ce)}'
      +'.so-menu-arama span{font-size:25px;line-height:1}'
      +'.so-menu-arama input{flex:1;min-width:0;padding:12px 0;color:var(--txt,#fff);background:transparent;'
      +'border:0;outline:none;font-size:15px}'
      +'.so-menu-arama:focus-within{border-color:var(--ink2,#a291ff)}'
      +'.so-menu-sonuclar{padding:10px;margin:-6px 0 14px;border:1px solid var(--line2,#394365);'
      +'border-radius:12px;background:var(--panel2,#182243)}'
      +'.so-menu-sonuclar[hidden]{display:none}.so-menu-sonuclar .so-link{margin-top:7px}'
      +'.so-arama-bas{font-size:12px;font-weight:800;color:var(--txt2);padding:4px}'

      +'@media(min-width:620px){.so-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}'
      +'@media(max-width:360px){.so-stats{gap:5px}.so-stat b{font-size:17px}.so-tabs button{padding:8px 10px}}';
    document.head.appendChild(s);
  }
  function tablar(grup){
    var dizi = grup==="adliye" ? adliyeSekmeleri : ekonomiSekmeleri;
    return '<nav class="so-tabs" role="tablist" aria-label="'+(grup==="adliye"?"Adliye bölümleri":"Ekonomi bölümleri")+'">'
      +dizi.map(function(x){return '<button type="button" role="tab" aria-selected="'+(secim[grup]===x[0])+'"'
      +' onclick="soMenuSec(\''+grup+'\',\''+x[0]+'\')">'+esc(x[1])+'</button>';}).join("")+'</nav>';
  }
  function ciz(grup,icerik){
    var bas=grup==="adliye"?"Adliye":"Ekonomi";
    if(D.sekme!==grup || D.yigin.length) return;
    iskelet(bas,tablar(grup)+aramaKutusu(grup)+icerik);
    var nav=document.querySelector(".so-tabs"),aktif=nav&&nav.querySelector('[aria-selected="true"]');
    if(nav&&aktif)nav.scrollLeft=Math.max(0,aktif.offsetLeft-nav.offsetLeft-nav.clientWidth/3);
  }
  function gecerli(grup,no){return no===istek[grup]&&D.sekme===grup&&!D.yigin.length;}
  window.soMenuSec=function(grup,sekme){
    var dizi=grup==="adliye"?adliyeSekmeleri:ekonomiSekmeleri;
    if(!dizi.some(function(x){return x[0]===sekme;}))return;
    secim[grup]=sekme;
    if(grup==="adliye")window.adliyeEkrani(true);else window.ekonomiSekmeEkrani();
  };
  window.soMenuGit=function(ad){
    var direk=["cekMerkeziAc","baroAc","sirketKurulumFormuAc","paraGonderModal","msSigortaAc","msRuhsatMerkeziAc"];
    var fn=window[ad];
    if(typeof fn!=="function"){toast("Bu işlem henüz kullanılamıyor: "+ad,true);return;}
    if(direk.indexOf(ad)>=0)return fn();
    return ekranAc(fn);
  };
  window.soMenuUc=function(tur){
    if(typeof window.ucYeniAc==="function")return window.ucYeniAc(tur);
    toast("Bu iş kolunun ekranı yüklenemedi.",true);
  };
  window.soMenuSirket=function(id,tab){
    if(typeof window.sirketTekSirketEkrani!=="function")return toast("Şirket yönetimi açılmadı.",true);
    var no=Number(id),sek=tab||"genel";
    return ekranAc(function(){return window.sirketTekSirketEkrani(no,sek);});
  };
  window.soMenuAra=function(metin){
    var q=String(metin||"").toLocaleLowerCase("tr-TR");
    document.querySelectorAll("#so-dava-liste .so-dava").forEach(function(el){
      el.style.display=el.textContent.toLocaleLowerCase("tr-TR").includes(q)?"":"none";
    });
  };

  /* Adliye: eski ekranların iş kurallarını yeniden yazmak yerine gerçek kayıtları gruplar. */
  function grupla(html){
    var host=document.createElement("div");host.innerHTML=html;
    var grup={mahkeme:[],avukatlar:[],ofisler:[],baro:[],itiraz:[],icra:[]},durum="mahkeme";
    Array.from(host.children).forEach(function(el){
      var basEl=el.querySelector(":scope > h2, :scope > h3, :scope > .baslik > b");
      var h=basEl?basEl.textContent.trim():"";
      if(el.classList.contains("bolum-bas")){
        var t=el.textContent.trim();
        if(/^Açık davalar/i.test(t)){durum="acik";return;}
        if(/^Karara bağlanan davalar/i.test(t)){durum="biten";return;}
        if(/^İtiraz edilen davalar/i.test(t)){durum="itiraz";return;}
        if(/^İcradan satılıklar/i.test(t)){durum="icra";return;}
        durum="mahkeme";
        grup.mahkeme.push(el.outerHTML);return;
      }
      if(el.id==="hukukIslerimKart"){grup.mahkeme.push(el.outerHTML);return;}
      if(/(Avukatlar\s*\(|Avukatlık ve Kontenjan|Dava kazanma primi hesaplarım)/i.test(h)){grup.avukatlar.push(el.outerHTML);return;}
      if(/^(Hukuk büroları|Hukuk bürom)/i.test(h)){grup.ofisler.push(el.outerHTML);return;}
      if(/Türkiye Barosu/i.test(h)){grup.baro.push(el.outerHTML);return;}
      if(/^(Seçim sonuçlarına itiraz|İtiraz dosyaları)/i.test(h)){grup.itiraz.push(el.outerHTML);return;}
      if(el.getAttribute("onclick") && el.getAttribute("onclick").includes("adliyeDosya("))return;
      if(durum==="acik"||durum==="biten")return;
      if(durum==="itiraz"&&el.querySelector('[onclick*="adliyeItirazListesiAc"]'))return;
      if(durum==="icra"){grup.icra.push(el.outerHTML);return;}
      if(el.querySelector(":scope > details > summary") && /Kredi icra mahkemesi/i.test(el.textContent)){grup.icra.push(el.outerHTML);return;}
      if(el.querySelector(":scope > button[onclick^='adlDavaModal']"))return;
      grup.mahkeme.push(el.outerHTML);
    });
    return grup;
  }
  function davalarHtml(l,metin){
    var ara='<input type="search" class="so-ara" aria-label="Dava ara" placeholder="Dosya, davacı veya davalı ara..." oninput="soMenuAra(this.value)">';
    var satir=(l||[]).map(function(d){
      return '<div class="so-dava">'+(typeof adlDavaKart==="function"?adlDavaKart(d):link("⚖️","Dosya #"+d.id,d.iddia||"","ekranAc(function(){adliyeDosya("+Number(d.id)+")})"))+'</div>';
    }).join("");
    return baslik(metin,(l||[]).length+" dosya listeleniyor. Dosyayı açarak savunmaları ve kararları inceleyebilirsin.")
      +(l.length?ara+'<div id="so-dava-liste">'+satir+'</div>':bos("Bu bölümde henüz dava bulunmuyor."));
  }
  async function itirazHtml(){
    if(istCache.html && Date.now()-istCache.at<15000)return istCache.html;
    var list=(adlVeri&&adlVeri.davalar||[]).filter(function(d){return d.durum==="karar";}).slice(0,100);
    var hepsi=[],hatalar=0;
    for(var i=0;i<list.length;i+=8){
      var grup=list.slice(i,i+8);
      var r=await Promise.allSettled(grup.map(function(d){return API.rpc("adliye_dava_ek",{p_dava:d.id});}));
      r.forEach(function(x,j){if(x.status==="fulfilled"&&x.value&&x.value.istinaf)hepsi.push({d:grup[j],i:x.value.istinaf});else if(x.status==="rejected")hatalar++;});
    }
    var z=baslik("İstinaf ve itirazlar","Karara karşı yapılan itirazlar, jüri incelemeleri ve seçim sonuçlarına itirazlar.");
    z+=kart("Dava istinafları",'<p class="so-note">'+hepsi.length+' itirazlı dava · '+list.length+' karar dosyası incelendi'
      +(hatalar?' · '+hatalar+' dosya okunamadı':'')+'</p>'
      +(hepsi.map(function(x){
        return link("⚖️","Dosya #"+x.d.id+" · "+(ADL_TURLER[x.d.tur]||x.d.tur),
        "İtiraz eden: "+(x.i.basvuran||"—")+" · Durum: "+(x.i.durum||"—"),
        "ekranAc(function(){adliyeDosya("+Number(x.d.id)+")})");
      }).join("")||'<p class="alt">Şu anda istinaf başvurusu görünen dava yok.</p>'));
    istCache={html:z,at:Date.now()};
    return z;
  }
  async function icraHtml(){
    var d=await API.rpc("icra_dosya_panel");
    var ih=d.ihaleler||[];
    var html=baslik("İcradan satılıklar","Gerçek oyun içi haciz satışları; teklif ve teminat işlemleri sunucu tarafından doğrulanır.")
      +'<div class="so-stats">'+chip(ih.length,"Açık artırma")+chip((d.dosyalar||[]).length,"Takip dosyası")+chip("₺","Teklif para birimi")+'</div>';
    html+=(ih.length?ih.map(function(x){
      var taban=Math.ceil(Number(x.deger||0)*.5),en=Math.ceil(Number(x.teklif||0)*1.01);
      return kart("İhale #"+Number(x.id)+" · "+esc(x.tur),
        '<div class="kv"><span>Takdir değeri</span><b>'+trPara(x.deger)+'</b></div>'
        +'<div class="kv"><span>En yüksek teklif</span><b>'+trPara(x.teklif)+'</b></div>'
        +'<div class="kv"><span>Teklif sonu</span><b>'+esc(tarih(x.son))+'</b></div>'
        +'<div class="alan"><label>Teklif tutarı (₺)</label><input id="ic_teklif_'+Number(x.id)+'" type="number" min="'+taban+'" value="'+Math.max(taban,en)+'"></div>'
        +'<button class="btn altin" onclick="soIcraTeklif('+Number(x.id)+')">Teminatı bloke et ve teklif ver</button>'
        +(x.teklif_veren_benim?'<button class="btn ikinci" onclick="icraTemIade('+Number(x.id)+')">Teminat iadesi al</button>':'')
        +(Date.now()>=new Date(x.son).getTime()?'<button class="btn ikinci" onclick="icraIhaleBitir('+Number(x.id)+')">İhaleyi sonuçlandır</button>':''));
    }).join(""):bos("Şu an icradan satışa çıkarılmış bir mal veya hisse bulunmuyor."));
    return html+grids([link("📁","İcra dosyaları ve haciz","Ödeme emirleri, itirazlar, e-haciz ve dosya işlemleri.","soMenuGit('icraMerkeziEkrani')")]);
  }
  window.soIcraTeklif=async function(id){
    var inp=document.getElementById("ic_teklif_"+id),tutar=Number(inp&&inp.value);
    if(!Number.isFinite(tutar)||tutar<=0)return toast("Geçerli teklif tutarı gir.",true);
    if(!await onayla("İcra e-satış","Teklifin için "+trPara(tutar)+" teminat bloke edilecek. Onaylıyor musun?","Teklif ver"))return;
    try{await API.rpc("icra_ihale_teklif",{p_haciz:id,p_tutar:tutar});toast("Teklif kaydedildi.");window.adliyeEkrani();}
    catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):err.message,true);}
  };
  async function adliyeYeniEkrani(kisaOnbellek){
    // Eylem sonrası menü yeniden açılıyorsa eski alt ekran geçmişini temizle.
    if(D.yigin.length)D.yigin=[];
    var no=++istek.adliye,s=secim.adliye;
    ciz("adliye",'<div class="so-menu-hero"><h2>⚖️ Adliye</h2><p>Mahkeme, avukatlar, dava süreçleri ve icra satışları tek merkezde.</p></div>'
      +'<div class="yukleniyor">Yükleniyor…</div>');
    try{
      if(s==="icra"){
        var ic=await icraHtml();
        if(gecerli("adliye",no))ciz("adliye",'<div class="so-menu-hero"><h2>İcradan Satılıklar</h2><p>İhale, teklif, dosya ve haciz işlemleri.</p></div>'+ic);
        return;
      }
      var html;
      if(kisaOnbellek && adlCache.html && Date.now()-adlCache.at<15000){
        html=adlCache.html;
        adlVeri=adlCache.data;
        if(adlVeri)ADL=adlVeri;
      }else{
        html=await adliyeHtml();
        if(!gecerli("adliye",no))return;
        adlVeri=typeof ADL!=="undefined"?ADL:null;
        adlCache={html:html,data:adlVeri,at:Date.now()};
        istCache.at=0;
      }
      if(!gecerli("adliye",no))return;
      var blok=grupla(html),d=adlVeri||{davalar:[]},l=d.davalar||[];
      var acik=l.filter(function(x){return x.durum==="acik";});
      var biten=l.filter(function(x){return x.durum!=="acik";});
      var ozet='<div class="so-stats">'+chip(acik.length,"Açık dava")+chip(biten.length,"Karara bağlanan")
        +chip((d.mahkeme&&d.mahkeme.uyeler||[]).filter(function(x){return x.kad;}).length,"Mahkeme üyesi")+'</div>';
      var z='';
      if(s==="mahkeme"){
        z=ozet+grids([link("➕","Dava aç / hukuki talep","Delilleri ve davalı bilgilerini girerek avukata başvur.","adlDavaModal()"),
          link("📂","Açık davaları gör","Devam eden duruşmalar ve dosyalar.","soMenuSec('adliye','acik')")]);
        z+=blok.mahkeme.join("")||bos("Mahkeme paneli yüklenemedi.");
      }else if(s==="avukatlar"){
        z=baslik("Avukatlar ve ruhsat","Ruhsat, kontenjan, hukuk akademisi, baro sicili ve gerçek dava başarıları.")
          +grids([link("🏛️","Türkiye Barosu","Levhaya kayıt, disiplin ve adli yardım.","soMenuSec('adliye','baro')"),
            link("🏢","Avukat ofisleri","Hukuk bürolarını ve kendi ofisini yönet.","soMenuSec('adliye','ofisler')")])
          +(blok.avukatlar.join("")||bos("Avukatlık bilgileri şu anda getirilemiyor."));
      }else if(s==="ofisler"){
        z=baslik("Avukat ofisleri","Bürolar, çalışan avukatlar ve temsil hizmetleri.")
          +grids([link("➕","Hukuk bürom / büro aç","Ruhsatın ve baro kaydın uygunsa büro işlemlerini yürüt.","soMenuGit('avukatBuroPanel')"),
            link("👩‍⚖️","Tüm avukatlar","Avukatların dava geçmişlerini ve başarılarını gör.","soMenuSec('adliye','avukatlar')")])
          +(blok.ofisler.join("")||bos("Henüz hukuk bürosu bulunmuyor."));
      }else if(s==="acik"){
        z=davalarHtml(acik,"Açık davalar")+(blok.mahkeme.filter(function(x){return x.includes('id="hukukIslerimKart"');}).join(""));
      }else if(s==="biten"){
        z=davalarHtml(biten,"Sonuçlanan davalar");
      }else if(s==="itiraz"){
        z=await itirazHtml();if(!gecerli("adliye",no))return;
        z+=blok.itiraz.filter(function(x){return !x.includes("adliyeItirazListesiAc");}).join("");
      }else if(s==="baro"){
        z=baslik("Türkiye Barosu","Levhaya kayıt, meslek örgütü, avukatlık ve adli yardım.")
          +grids([link("🏛️","Baro binasına gir","Üyeysen pano, seçim, disiplin ve aidat işlemleri.","soMenuGit('baroAc')"),
             link("⚖️","Ruhsat ve kontenjan","Akademi, sınav, ruhsat başvurusu.","soMenuSec('adliye','avukatlar')")])
          +(blok.baro.join("")||bos("Baro verisi şu anda yüklenemedi."));
      }
      if(gecerli("adliye",no))ciz("adliye",'<div class="so-menu-hero"><h2>'+esc(adliyeSekmeleri.find(function(x){return x[0]===s;})[1])+'</h2>'
        +'<p>İlgili bütün kayıtlar ve işlemler bu bölümde.</p></div>'+z);
    }catch(err){
      if(gecerli("adliye",no))ciz("adliye",kart("Adliye yüklenemedi",'<p class="alt">'+esc(typeof hataCevir==="function"?hataCevir(err.message):err.message)+'</p>'
        +'<button class="btn ikinci" onclick="adliyeEkrani()">Yeniden dene</button>'));
    }
  }

  /* Ekonomi: Hayat ekranındaki maaş ve kişisel yaşam korunur, ticaret ayrı sekmededir. */
  function ekonomiHero(s){
    var map={
      genel:["Ekonomi Merkezi","Şirketlerin, bankaların, piyasaların ve mülklerin için hızlı erişim."],
      sirketlerim:["Şirketlerim","Ortak olduğun şirkete dokun: kasa, mal, şube, inşaat, ortaklık ve finans tek ekranda."],
      bankalar:["Bankalar ve Finans","Devlet bankası, özel bankalar, kart, POS, çek ve kredi hesapları."],
      sirketler:["Şirket Pazarı","Şirketleri, ortaklıkları, satış ilanlarını ve halka arzları keşfet."],
      piyasalar:["Piyasalar","Borsa, yatırım araçları, ekonomik gelişmeler ve fiyatlar."],
      emlak:["Gayrimenkul","Arsa, ev, dükkân, kira ve yatırım fırsatları."],
      giris:["İş Dünyası","Sigorta, ajanslar, ruhsatlar, yeni iş kolları ve ek gelir yolları."],
      islemler:["İşlem Merkezi","Havale, alım-satım geçmişi, ihale ve ödeme işlemleri."]
    };
    var d=map[s]||map.genel;
    return '<div class="so-menu-hero"><h2>'+esc(d[0])+'</h2><p>'+esc(d[1])+'</p></div>';
  }
  async function ekonomiGenel(){
    var sahipKartlari="";
    try{
      var yonetilen=(await API.rpc("banka_yonetilen_liste"))||[];
      if(yonetilen.length) sahipKartlari=baslik("🏦 Banka Sahibi Yönetimi","Sana ait bankaların başvurularını, müşterilerini ve otomatik onay ayarlarını buradan yönet.")
        +grids([link("🏦","Banka Yönetim Panelim","POS · kredi kartı · kredi başvuruları / onay ve ret","soBankaYonetimGit('basvuru')","Yönetim")]);
    }catch(_){/* Kişisel banka erişimi hata verse de ekonomi ekranı açılır. */}
    return sahipKartlari+baslik("En çok kullanılan işlemler","Bir dokunuşla işleminin olduğu bölüme git.")
      +grids([
        link("🏢","Şirketlerim","Kasalarım, şubeler, projeler ve hisse ortaklıkları.","soMenuSec('ekonomi','sirketlerim')"),
        link("🏦","Bankalar","Hesaplarım, mevduat, kredi ve kredi kartı.","soMenuSec('ekonomi','bankalar')"),
        link("🏡","Gayrimenkul","Arsa, ev, dükkân ve kiralık mülkler.","soMenuSec('ekonomi','emlak')"),
        link("📈","Piyasalar","Borsa, altın, döviz ve ekonomik veriler.","soMenuSec('ekonomi','piyasalar')")
      ])
      +baslik("Diğer merkezler","Alım-satım ve ödeme işlemleri de ayrı bölümlerde.")
      +grids([
        link("🏬","Şirketler ve ilanlar","Yeni şirket kur, şirket satın al, halka arza katıl.","soMenuSec('ekonomi','sirketler')"),
        link("💸","Para ve ticaret işlemleri","Para gönderme, çek, ihale ve işlem geçmişi.","soMenuSec('ekonomi','islemler')"),
        link("🛡️","İş Dünyası","Sigorta, iş kolları, ruhsat ve ek işler.","soMenuSec('ekonomi','giris')")
      ]);
  }
  function bankalarGenel(){
    return baslik("Banka hesapları","Devlet bankasıyla oyuncu bankaları ayrı yönetilir.")
      +grids([
        link("🏛️","Devlet Bankası","Vadeli / vadesiz hesap, para yatırma ve çekme.","soMenuGit('bankaEkrani')"),
        link("🏦","Oyuncu bankaları","Faizleri karşılaştır, mevduat yatır, kredi başvur.","soMenuGit('bankaRehberiEkrani')"),
        link("📒","Mevduat ve kredilerim","Özel bankalardaki vadeler, geri ödemeler ve başvurular.","soMenuGit('bankaPortfoyEkrani')"),
        link("➕","Yeni banka kur","Yeni özel banka kur, sermayesini belirle.","soMenuGit('bankaKurEkrani')")
      ])
      +baslik("Kartlar ve ticari ödemeler","Kredi kartın, POS, çek defteri ve kart borçların.")
      +grids([
        link("💳","Kredi Kartlarım","Kart başvurusu, limit, harcama, ekstre ve borç ödeme.","soMenuGit('kartlarimEkrani')"),
        link("🏪","POS / Kartlı ödeme","Şirket POS başvuruları ve kartlı satış talepleri.","soMenuGit('kartPosEkrani')"),
        link("🧾","Çek defterim","Çek al, ver, ciro et, erken öde ve takibini yap.","soMenuGit('cekMerkeziAc')"),
        link("💸","Para transferi","Banka havalesiyle diğer oyuncuya para gönder.","soMenuGit('paraGonderModal')")
      ]);
  }
  async function bankalarHtml(){
    var z="";
    try{
      var b=(await API.rpc("banka_yonetilen_liste"))||[];
      if(b.length)z+=baslik("🏦 Banka Sahibi Yönetimi","Banka sahibiysen tüm onay/ret işlemlerin burada. Müşteri bankacılığıyla karışmaz.")
        +grids([
          link("📥","Başvuruları Yönet","POS, kredi kartı ve kredi başvurularını gör, onayla veya reddet.","soBankaYonetimGit('basvuru')","Yönetim"),
          link("⚙️","Otomatik Karar Ayarları","POS, kredi kartı ve kredi için otomatik / manuel kurallar.","soBankaYonetimGit('ayar')","Yönetim")
        ])
        +baslik("Benim bankalarım","Bankanın adına dokunarak yönetimini aç.")
        +grids(b.map(function(x){return link("🏦",x.ad,"Banka kasası: "+trPara(x.kasa),"soMenuBanka("+Number(x.id)+",'basvuru')","Yönetim");}));
    }catch(_){/* Oyuncu müşteri olarak bankacılığı kullanmaya devam edebilir. */}
    return z+bankalarGenel();
  }
  window.soMenuBanka=function(id,tab){
    if(typeof window.bankaYonetimEkrani!=="function")return toast("Banka yönetimi yüklenmedi. Sayfayı yenile.",true);
    return ekranAc(function(){return bankaYonetimEkrani(Number(id),tab||'basvuru');});
  };
  window.soBankaYonetimGit=async function(tab){
    try{
      var list=(await API.rpc("banka_yonetilen_liste"))||[];
      if(!list.length)return toast("Yönetim yetkin olan banka bulunamadı.",true);
      if(list.length>1){
        soMenuSec('ekonomi','bankalar');
        return toast("Yöneteceğin bankayı 'Benim bankalarım' bölümünden seç.",false);
      }
      return window.soMenuBanka(Number(list[0].id),tab||'basvuru');
    }catch(err){return toast("Banka yönetimi açılamadı: "+String(err&&err.message||err),true);}
  };
  async function sirketlerimHtml(){
    try{
      var d=await API.rpc("ortak_sirket_panel");
      var list=(d.sirketler||[]).slice().sort(function(a,b){return String(a.ad).localeCompare(String(b.ad),"tr");});
      var z=baslik("Ortak olduğum şirketler","Aşağıdan bir şirkete dokun, o şirkete ait tüm bölümlere gir.");
      if(!list.length)z+=bos("Henüz şirketin yok. Aşağıdaki Yeni Şirket Kur düğmesini kullanabilirsin.");
      else z+='<input type="search" class="so-ara" aria-label="Şirketlerim içinde ara" placeholder="Şirket adı veya sektör ara..." oninput="soMenuSirketAra(this.value)" /><div id="so-sirket-liste">' + list.map(function(s){
        return '<button type="button" class="so-company" onclick="soMenuSirket('+Number(s.id)+')">'
          +'<b>🏢 '+esc(s.ad)+' <span style="float:right">›</span></b>'
          +'<small>'+esc(s.sektor)+' · Hissen %'+esc(s.benim_pay)+'</small>'
          +'<strong>Kasa: '+trPara(s.kasa)+' · Sermaye: '+trPara(s.sermaye)+'</strong>'
          +'<small>Detaylar, kasaya para koyma, mal, şube, inşaat, ortaklık, finans</small></button>';
      }).join("") + "</div>";
      if((d.kuruluslar||[]).length||(d.devirler||[]).length)
        z+=kart("Bekleyen ortaklık işlemleri",'<p class="alt">Kuruluş daveti: '+(d.kuruluslar||[]).length
         +' · Hisse devri: '+(d.devirler||[]).length+'</p>'
         +link("🤝","Davetler ve ortaklıklar","Gelen tekliflere yanıt ver.","soMenuGit('ortaklikEkrani')"));
      return z+baslik("Şirket işlemleri","Yeni şirket, ortaklık ve sahip olduğun şirketlerin finansmanı.")
        +grids([
          link("➕","Yeni şirket kur","Şehir, sektör ve kuruluş sermayesi belirle.","soMenuGit('sirketKurulumFormuAc')"),
          link("🤝","Ortaklık merkezi","Birlikte şirket kur, hisse devret, pay satın al.","soMenuGit('ortaklikEkrani')"),
          link("📊","Şirketlerimin gelirleri","Kâr, zarar ve finansal raporlarını incele.","soMenuGit('sirketlerimMerkezi')"),
          link("🏗️","İnşaat ve şubelerim","Şirket merkezinde kasa, arsalar, inşaat ve şubeler.","soMenuGit('sirketlerimMerkezi')")
        ]);
    }catch(err){
      return kart("Şirketlerim",'<p class="alt">Şirket listesi alınamadı: '+esc(err.message)+'</p>'
      +link("🏢","Şirket yönetimine git","Alternatif şirket listesi.","soMenuGit('sirketlerimMerkezi')"));
    }
  }
  function sirketlerHtml(){
    return baslik("Şirket kur ve ticaret yap","İlanlar ve piyasa işlemleri ayrı ekranlarda.")
      +grids([
        link("🏢","Tüm şirketler","Sektör, kâr, sermaye ve şirket sahipleri.","soMenuGit('sirketVitrinEkrani')"),
        link("➕","Şirket kur","Kendi şirketini veya ortaklı şirketi oluştur.","soMenuGit('sirketKurulumFormuAc')"),
        link("🏪","Satılık şirketler","Satın alma ilanları ve şirket bilgileri.","soMenuGit('sirketPazarEkrani')"),
        link("🤝","Hisse pazarı","Hisse al, sat, ortak ol ve devret.","soMenuGit('sirketHissePazariEkrani')"),
        link("🚀","Halka arzlar","Şirket halka arzları ve yatırım başvuruları.","soMenuGit('halkaArzPazarEkrani')"),
        link("🏬","Rekabetçi işletmeler","Market, okul, hastane, fabrika ve ticaret.","soMenuGit('pazarMerkezEkrani')"),
        link("📦","Toptan ticaret","Şirketler arasında mal alım-satımı.","soMenuGit('kamuToptanEkrani')"),
        link("📋","Kamu ihaleleri","Devlet ve belediye işlerine teklif ver.","soMenuGit('ihaleEkrani')"),
        link("🛡️","Sigorta şirketleri","Şirket sigortası, poliçe ve hasar işlemleri.","soMenuGit('msSigortaAc')"),
        link("🏭","İş dünyası","Üretim, fabrika, mağaza, franchise ve işletmeler.","soMenuGit('isDunyasiEkrani')")
      ]);
  }
  function piyasalarHtml(){
    return baslik("Yatırım ve ekonomi","Canlı işlem yapılabilen yatırım pazarları.")
      +grids([
        link("📈","Altın, döviz ve hisseler","Piyasa fiyatlarını incele, yatırım al veya sat.","soMenuGit('piyasaEkrani')"),
        link("📊","Borsa","Borsa işlemleri ve hisse hareketleri.","soMenuGit('borsaEkrani')"),
        link("🧾","Belediye tahvilleri","Belediyelere yatırım yap, faiz getirilerini incele.","soMenuGit('belediyeTahvilEkrani')"),
        link("📊","Ekonomi merkezi","Piyasa raporu, büyüme, rekabet ve veriler.","soMenuGit('ekonomiMerkeziEkrani')"),
        link("🚀","Halka arzlar","Yeni şirket hisseleri ve sonuçları.","soMenuGit('halkaArzPazarEkrani')"),
        link("🏦","Mevduat fırsatları","Banka vadelerini ve oranlarını karşılaştır.","soMenuSec('ekonomi','bankalar')"),
        link("🏛️","Merkez Bankası","Politika faizini ve PPK kararlarını incele.","soMenuGit('merkezBankasiEkrani')"),
        link("⚖️","Sermaye Piyasası Kurulu","Borsa denetimi ve piyasa düzeni.","soMenuGit('spkEkrani')"),
        link("📉","Rekabet Kurumu","Piyasa ve şirket rekabeti soruşturmaları.","soMenuGit('rekabetEkrani')")
      ]);
  }
  function emlakHtml(){
    return baslik("Gayrimenkul ve yatırımlar","Şehirlerde satılık ve kiralık taşınmazları yönet.")
      +grids([
        link("🏠","Gayrimenkul pazarı","Arsa, ev ve dükkân satın al.","soMenuGit('emlakYeniEkrani')"),
        link("🏡","Yatırım pazarı","Yatırımlık taşınmaz ve ticari mülk ilanları.","soMenuGit('yatirimPazarEkrani')"),
        link("🏗️","İnşaat şirketlerim","Şirketi seçip arsa ve inşaatlarına gir.","soMenuSec('ekonomi','sirketlerim')"),
        link("💼","Şirketler ve şubeler","İşyerlerini ve büyüyen işletmelerini yönet.","soMenuSec('ekonomi','sirketlerim')")
      ]);
  }
  function girisHtml(){
    return baslik("İşletmeler ve ek kazanç","Şirket türü, ruhsat, sigorta ve yeni faaliyet alanları.")
      +grids([
        link("🛡️","Sigorta ve risk merkezi","Poliçe yaptır, hasar ve sigorta şirketlerini yönet.","soMenuGit('msSigortaAc')"),
        link("💼","Ek işler","Kurye, taksi, özel ders, tasarım ve tamirat.","soMenuGit('ekIslerEkrani')"),
        link("🏛️","Ruhsat merkezi","İşyeri, fabrika, mağaza ve inşaat ruhsatları.","soMenuGit('msRuhsatMerkeziAc')"),
        link("📦","Üretim ve iş dünyası","Fabrika, mağaza, inşaat, franchise ve ticaret.","soMenuGit('isDunyasiEkrani')"),
        link("🌾","Tarım ve hayvancılık","Tarlalar, hasat, hayvancılık ve tedarik.","soMenuUc('tarim')"),
        link("📚","Kitap ve yayınevi","Kitap yaz, baskı yap ve telif kazan.","soMenuUc('kitap')"),
        link("📺","Medya ve yayıncılık","Televizyon, gazete ve medya faaliyetleri.","soMenuUc('medya')"),
        link("🎟️","Etkinlik ve organizasyon","Konser, konferans, fuar, bilet ve sponsor.","soMenuUc('etkinlik')"),
        link("📢","Reklam ve anket ajansı","Reklam kampanyaları ve kamuoyu araştırmaları.","soMenuGit('ajansMerkezEkrani')"),
        link("⚖️","Konkordato ve iflas","Zor durumdaki işletmelerin süreçleri.","soMenuGit('konkordatoEkrani')"),
        link("📢","İhale İlan Panosu","Bütün kamu hizmeti ve yapım ilanları.","soMenuGit('msIhaleMerkeziAc')"),
        link("🤝","Siyasi bağışlar","Şirketlerin partilere bağış işlemleri.","soMenuGit('siyasiBagisEkrani')")
      ]);
  }

  function islemlerHtml(){
    return baslik("Ödeme ve işlem kayıtları","Bankacılık ve ticaret işlemleri kendi yerlerinde.")
      +grids([
        link("💸","Para gönder","Banka havalesi yap.","soMenuGit('paraGonderModal')"),
        link("🧾","Çeklerim","Çek düzenle, kabul et, öde ve tahsil et.","soMenuGit('cekMerkeziAc')"),
        link("💳","Kredi Kartlarım / POS","Kartla ödeme al veya yap.","soMenuGit('kartPosEkrani')"),
        link("📜","Alım-satım geçmişim","Gerçekleşen ticari işlem kayıtların.","soMenuGit('ticaretGecmisimEkrani')"),
        link("📋","Kamu ihaleleri","İhale ilanları ve tekliflerin.","soMenuGit('ihaleEkrani')"),
        link("⚖️","İcra ve haciz","Alacak takibi, icra dosyası, e-satış.","soMenuGit('icraMerkeziEkrani')"),
        link("🏛️","Devlet bütçesi","Kamu ekonomisi ve harcamalar.","soMenuGit('kamuButceEkrani')")
      ]);
  }
  async function ekonomiYeniEkrani(){
    // Eylem sonrası menü yeniden açılıyorsa eski alt ekran geçmişini temizle.
    if(D.yigin.length)D.yigin=[];
    var no=++istek.ekonomi, s=secim.ekonomi;
    ciz("ekonomi",ekonomiHero(s)+'<div class="yukleniyor">Yükleniyor…</div>');
    var z="";
    if(s==="genel")z=await ekonomiGenel();
    else if(s==="sirketlerim")z=await sirketlerimHtml();
    else if(s==="bankalar")z=await bankalarHtml();
    else if(s==="sirketler")z=sirketlerHtml();
    else if(s==="piyasalar")z=piyasalarHtml();
    else if(s==="emlak")z=emlakHtml();
    else if(s==="giris")z=girisHtml();
    else if(s==="islemler")z=islemlerHtml();
    if(gecerli("ekonomi",no))ciz("ekonomi",ekonomiHero(s)+z);
  }
  window.ekonomiSekmeEkrani=ekonomiYeniEkrani;
  window.ekonomiEkrani=ekonomiYeniEkrani;
  /* Menüler ekranlar arası geri navigasyonla çalışır: D.yigin ve işlem RPC'leri aynen korunur. */
  window.adliyeEkrani=adliyeEkrani=adliyeYeniEkrani;
  if(typeof EKRAN==="object"&&EKRAN){
    EKRAN.adliye=function(){return window.adliyeEkrani();};
    EKRAN.ekonomi=function(){return window.ekonomiSekmeEkrani();};
  }
  stil();
})();


/* 2026-10-23 — Milli Piyango ve Kazı Kazan oyundan çıkarıldı.
   Eski ekranlar yeniden çizildiğinde de bağlantılar gizlenir.
   Sunucu RPC'leri ayrıca kapatılır; bu katman yalnızca arayüzdür. */
(function () {
  "use strict";
  if (window.SO_SANS_OYUNLARI_KALDIRILDI) return;
  window.SO_SANS_OYUNLARI_KALDIRILDI = true;
  function kaldirildi() {
    if (typeof window.bildir === "function") window.bildir("Bu şans oyunu kaldırıldı.");
    else if (typeof window.toast === "function") window.toast("Bu şans oyunu kaldırıldı.");
  }
  window.piyangoEkrani = kaldirildi;
  window.piyangoAl = kaldirildi;
  window.kazikazanEkrani = kaldirildi;
  window.kazikazanOyna = kaldirildi;
  function temizle() {
    var kok = document.getElementById("icerik");
    if (!kok) return;
    kok.querySelectorAll("button[onclick], a[onclick]").forEach(function (el) {
      var cagri = el.getAttribute("onclick") || "";
      var ad = (el.textContent || "").trim();
      if (/\b(?:piyangoEkrani|piyangoAl|kazikazanEkrani|kazikazanOyna)\b/.test(cagri) ||
          /^(?:Milli Piyango|Kazı Kazan|Kazı kazan)(?:\s|·|$)/i.test(ad)) el.remove();
    });
    kok.querySelectorAll("h2").forEach(function (baslik) {
      if (baslik.textContent.trim().toLocaleLowerCase("tr-TR") !== "şans oyunları") return;
      var ust = baslik.closest(".bolum-bas");
      if (!ust) return;
      var kart = ust.nextElementSibling;
      if (kart && kart.classList.contains("kart") && !kart.querySelector("button,a")) kart.remove();
      ust.remove();
    });
  }
  function baslat() {
    temizle();
    if (typeof MutationObserver !== "function" || !document.body) return;
    var sirada = false;
    new MutationObserver(function () {
      if (sirada) return;
      sirada = true;
      Promise.resolve().then(function () { sirada = false; temizle(); });
    }).observe(document.body, {childList:true, subtree:true});
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", baslat, {once:true});
  else baslat();
})();
