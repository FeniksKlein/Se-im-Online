/* Seçim Online — Adliye ve Ekonomi sekmeli menüleri, 23.10.2026.
   Yalnız istemci navigasyonudur. Para, yetki, dava ve şirket işlemleri
   mevcut RPC ve ekranlarında kalır; oyuncu verisini değiştirmez. */
(function () {
  "use strict";
  if (window.SO_MENU_MERKEZLERI_V1) return;
  window.SO_MENU_MERKEZLERI_V1 = true;
  if (!document.getElementById('banka-yonetim-loader')) {
    var bankScript=document.createElement('script');
    bankScript.id='banka-yonetim-loader';
    bankScript.src='./banka_yonetim.js?v=20261025b';
    bankScript.onload=function(){
      if(document.getElementById('banka-sahibi-iyilestirme'))return;
      var ui=document.createElement('script');
      ui.id='banka-sahibi-iyilestirme';
      ui.src='./banka_sahibi_paneli.js?v=20261025b';
      document.head.appendChild(ui);
    };
    document.head.appendChild(bankScript);
  }

  var adliyeSekmeleri = [
    ["mahkeme", "Mahkeme"], ["avukatlar", "Avukatlar"], ["ofisler", "Avukat Ofisleri"],
    ["acik", "Açık Davalar"], ["itiraz", "İtirazlar"], ["biten", "Biten Davalar"],
    ["icra", "İcradan Satılıklar"], ["baro", "Baro"]
  ];
  var ekonomiSekmeleri = [
    ["genel", "Özet", "◈"], ["sirketlerim", "Şirketlerim", "🏢"],
    ["sirketler", "Ticaret", "🛒"], ["bankalar", "Bankalar", "🏦"],
    ["piyasalar", "Yatırım", "📈"], ["emlak", "Emlak", "🏠"],
    ["giris", "Diğer", "✦"]
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
      ["🏦","Mobil Şube","Bütün hesaplar, kartlar, krediler, birikim ve para gönderme","soMenuGit('mobilSubeEkrani')","banka devlet bankası mevduat havale eft fast internet bankacılığı"],
      ["🏛️","Banka Genel Müdürlüğü","Bankanın kasası, başvurular, faizler, kâr payı ve DİBS","soMenuGit('bankaYonetimMerkezi')","banka sahibi yönetim kasa"],
      ["🔒","Kasa gizliliği","Şirket, banka, dernek ve gazete kasasını kim görsün","soMenuGit('kasaGizlilikEkrani')","gizli kasa görünürlük"],
      ["💳","Kredi kartlarım","Kart limitleri, ekstre, hesap kesimi, borç","soMenuGit('kartlarimEkrani')","kredi kartı borç"],
      ["🏪","POS ve kartlı satış","Şirketime POS, kartla ödeme","soMenuGit('kartPosEkrani')","pos cihazı komisyon"],
      ["🧾","Çek defteri","Çek al, yaz, ciro et, öde","soMenuGit('cekMerkeziAc')","çek karnesi vadeli çek"],
      ["💸","Para gönder","Banka havalesi ve oyuncuya ödeme","soMenuGit('paraGonderModal')","havale transfer"],
      ["💰","Şirket kasasına para yatır","Şirketini seçerek sermaye ve nakit ekle","soMenuSec('ekonomi','sirketlerim')","para koy kasa"],
      ["🏗️","İnşaat ve şube yönetimi","Arsa, ruhsat, projeler ve şube açma","soMenuSec('ekonomi','sirketlerim')","müteahhit bina maliyet"],
      ["📒","Kredilerim ve mevduatlarım","Özel banka borçlarım ve hesaplarım","soMenuGit('bankaPortfoyEkrani')","vadeli borç faiz"],
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
    s.textContent+="\n.so-ekonomi{--econ-accent:#78d2c7;--econ-gold:#efd399;min-width:0;padding-bottom:12px}\n.so-ekonomi .so-tabs{position:sticky;top:0;z-index:8;gap:7px;background:var(--bg,#0c1428);border:0;border-bottom:1px solid var(--line,#303a56);border-radius:0;padding:9px 2px 11px;margin:0 -2px 14px;scroll-snap-type:x proximity}\n.so-ekonomi .so-tabs button{min-height:58px;padding:8px 13px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;scroll-snap-align:start;border:1px solid var(--line2,#354463);border-radius:13px;background:var(--panel2,#141f35);font-weight:750;color:var(--txt2,#bac4d6);min-width:75px}\n.so-ekonomi .so-tabs button[aria-selected=\"true\"]{color:#f3fffe;border-color:#46988f;background:linear-gradient(145deg,#224f54,#193346);box-shadow:inset 0 -2px 0 #78d2c7,0 3px 12px #09182b55}\n.so-econ-tab-icon{font-size:18px;line-height:1.1}\n.so-ekonomi .so-menu-arama{margin:2px 0 12px;border-radius:14px;background:var(--panel2,#162039)}\n.so-econ-banner{position:relative;overflow:hidden;padding:21px 18px;border-radius:19px;background:linear-gradient(125deg,#143a43,#173149 55%,#293b5e);border:1px solid #41737c;margin-bottom:16px;box-shadow:0 9px 24px #0002;color:#f3f9fd}\n.so-econ-banner:after{content:\"\";position:absolute;right:-29px;top:-44px;width:145px;height:145px;border-radius:100%;background:radial-gradient(circle,#89e0bf39,transparent 72%);pointer-events:none}\n.so-econ-eyebrow{display:flex;align-items:center;gap:6px;font-size:10px;letter-spacing:1.5px;font-weight:850;color:#a3f1dc;margin-bottom:8px}\n.so-econ-banner h2{font-size:clamp(21px,5vw,27px);line-height:1.18;letter-spacing:-.4px;color:#fff;margin:0 0 8px}\n.so-econ-banner p{font-size:13px;max-width:520px;line-height:1.55;color:#c9e1e9;margin:0}\n.so-econ-quick{display:flex;flex-wrap:wrap;gap:8px;margin-top:15px}\n.so-econ-quick button{min-height:38px;border:1px solid #88d7c5;border-radius:10px;background:#8be2c8;color:#0d2b34;padding:8px 12px;font-weight:800;cursor:pointer}\n.so-econ-quick button + button{background:#ffffff16;color:#effefa;border-color:#ffffff70}\n.so-econ-section{margin:16px 0}\n.so-econ-section-head{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:10px}\n.so-econ-section-head h3{font-size:16px;color:var(--txt,#fff);margin:0;line-height:1.3}\n.so-econ-section-head small{font-size:11px;color:var(--txt2,#aebacf);text-align:right}\n.so-econ-tiles{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}\n.so-econ-tile{display:flex;flex-direction:column;gap:6px;align-items:flex-start;min-width:0;min-height:126px;padding:14px 12px;background:var(--panel,#19253e);color:var(--txt,#fff);border:1px solid var(--line2,#374a66);border-radius:16px;text-align:left;cursor:pointer}\n.so-econ-tile:active{transform:scale(.985);border-color:#78d2c7}\n.so-econ-tile b{font-size:14px;line-height:1.25}\n.so-econ-tile small{color:var(--txt2,#b3bfd3);font-size:11.5px;line-height:1.35}\n.so-econ-tile .so-econ-tile-icon{display:flex;align-items:center;justify-content:center;width:34px;height:34px;border-radius:10px;background:#569b9730;font-size:19px;margin-bottom:2px}\n.so-econ-tile.featured{background:linear-gradient(145deg,#1b4749,#1b3945);border-color:#4daca5}\n.so-econ-utility{display:flex;gap:8px;flex-wrap:wrap;margin:14px 0}\n.so-econ-utility button{flex:1 1 130px;min-height:44px;padding:9px 10px;border:1px solid var(--line2,#43526c);border-radius:12px;background:var(--panel,#1d2944);color:var(--txt,#fff);font-weight:750}\n.so-econ-metrics{display:flex;gap:8px;margin:0 0 14px;flex-wrap:wrap}\n.so-econ-metric{flex:1 1 100px;padding:11px 12px;background:var(--panel2,#14233a);border:1px solid var(--line2,#35506a);border-radius:13px}\n.so-econ-metric strong{display:block;font-size:18px;color:var(--txt,#fff)}\n.so-econ-metric span{display:block;font-size:11px;color:var(--txt2,#bec6d6);margin-top:3px}\n.so-econ-intro{font-size:12px;line-height:1.5;color:var(--txt2,#bfcee0);margin:3px 1px 11px}\n.so-econ-more{margin:14px 0;border:1px solid var(--line2,#37465f);border-radius:14px;padding:12px;background:var(--panel2,#142038)}\n.so-econ-more summary{cursor:pointer;color:var(--txt,#fff);font-size:13px;font-weight:800;list-style-position:inside;min-height:28px}\n.so-econ-more .so-grid{margin-top:12px}\n.so-ekonomi .so-company{border-radius:15px;transition:border-color .16s;background:var(--panel,#202b46)}\n.so-ekonomi .so-company:hover,.so-ekonomi .so-company:focus-visible{border-color:#78d2c7}\n.so-ekonomi .so-menu-hero{display:none}\n@media(min-width:700px){.so-econ-tiles{grid-template-columns:repeat(4,minmax(0,1fr))}.so-ekonomi .so-tabs{justify-content:space-around}.so-ekonomi .so-tabs button{flex:1}}\n@media(max-width:360px){.so-econ-tiles{gap:7px}.so-econ-tile{padding:12px 10px;min-height:125px}.so-econ-banner{padding:18px 14px}}\n@media(prefers-reduced-motion:reduce){.so-econ-tile:active{transform:none}}\n";
    s.textContent+="\n/* Ozette ust sekmelerin kopyasi yerine kisa ekonomik veriler. */\n.so-ekonomi .so-econ-banner{padding:17px 17px 16px;margin-bottom:14px}\n.so-ekonomi .so-econ-banner h2{font-size:22px;margin-bottom:5px}\n.so-ekonomi .so-econ-banner p{font-size:12.5px}\n.so-econ-overview .so-econ-section{margin:14px 0 18px}\n.so-econ-kpi-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}\n.so-econ-kpi{position:relative;min-width:0;padding:13px 12px;border:1px solid var(--line2,#37465c);background:var(--panel,#182341);border-radius:15px;overflow:hidden}\n.so-econ-kpi strong{display:block;color:var(--txt,#fff);font-size:clamp(19px,4.3vw,25px);font-variant-numeric:tabular-nums;line-height:1.2;overflow-wrap:anywhere;margin:5px 0}\n.so-econ-kpi span{color:var(--txt2,#c1cbe0);font-size:12px;font-weight:700}\n.so-econ-kpi small{display:block;color:var(--txt2,#b1bdd1);font-size:10.5px;line-height:1.35}\n.so-econ-kpi.accent{background:linear-gradient(140deg,#173e47,#1c344b);border-color:#448e88}\n.so-econ-kpi .up{color:#80dfb9}.so-econ-kpi .down{color:#f3a5a5}\n.so-econ-overview-note{margin:8px 2px 12px;color:var(--txt2,#b6c6d5);font-size:11px;line-height:1.45}\n.so-econ-overview-link{display:flex;width:100%;align-items:center;justify-content:space-between;gap:10px;background:var(--panel2,#1b2841);border:1px solid var(--line2,#364762);border-radius:12px;color:var(--txt,#fff);text-align:left;cursor:pointer;min-height:44px;padding:10px 13px;font-size:12.5px;font-weight:750}\n.so-econ-overview .so-econ-tiles{gap:9px}\n.so-econ-overview .so-econ-tile{min-height:101px;padding:12px 11px;gap:5px}\n.so-econ-overview .so-econ-tile .so-econ-tile-icon{width:29px;height:29px;font-size:17px}\n.so-econ-overview .so-econ-tile b{font-size:13.5px}\n.so-econ-overview .so-econ-tile small{font-size:11px}\n@media(min-width:700px){.so-econ-kpi-grid{grid-template-columns:repeat(4,minmax(0,1fr))}}\n";
    s.textContent+="\n/* Ekonomi - Mobil Sube temali ortak tasarim standardi */\n.so-ekonomi{--eco-mint:#9ae5d1;--eco-stroke:rgba(154,184,244,.24);--eco-card:#1a2645}\n.so-ekonomi .so-tabs{margin-bottom:13px!important;border-bottom:1px solid #8fbce934!important;box-shadow:0 9px 15px -17px #000!important}\n.so-ekonomi .so-tabs button{background:linear-gradient(145deg,#222f54,#17213f)!important;border-color:#adc2f522!important;border-radius:15px!important;min-width:83px!important;padding:9px 13px!important}\n.so-ekonomi .so-tabs button[aria-selected=true]{color:#112c3b!important;background:linear-gradient(130deg,#a8ecdf,#72d2c4)!important;border-color:#c7fff5!important;box-shadow:0 5px 16px -10px #6fe0c5!important}\n.so-ekonomi .so-econ-tab-icon{font-size:20px!important}\n.so-ekonomi .so-econ-banner{border-radius:23px;border-color:#7abdbd6e;background:linear-gradient(130deg,#163e50,#22355b 62%,#302d62);box-shadow:0 20px 30px -28px #000;min-height:105px;padding:18px 18px}\n.so-ekonomi .so-econ-banner:after{width:190px;height:190px;background:radial-gradient(circle,#b4b4ff27,transparent 66%)}\n.so-ekonomi .so-econ-banner h2{font-size:clamp(22px,5.3vw,30px);font-family:var(--disp),sans-serif;letter-spacing:.1px}\n.so-ekonomi .so-econ-banner p{color:#c4deed}\n.so-ekonomi .so-menu-arama{border-radius:15px;background:#171f3c;border-color:#9cb6ef3a;min-height:48px}\n.so-ekonomi .so-econ-section{margin:19px 0}\n.so-ekonomi .so-econ-section-head{margin-bottom:11px}\n.so-ekonomi .so-econ-section-head h3{font-family:var(--disp),sans-serif;font-size:21px}\n.so-ekonomi .so-econ-section-head small{max-width:45%;font-size:10.5px}\n.so-ekonomi .so-econ-tiles{gap:9px}\n.so-ekonomi .so-econ-tile{min-height:112px;border-radius:17px;background:linear-gradient(145deg,#1c2a4b,#171e3b);border:1px solid #abc2f22c;padding:13px 12px;box-shadow:0 9px 20px -23px #000}\n.so-ekonomi .so-econ-tile.featured{background:linear-gradient(125deg,#22544f,#1b3e50);border-color:#83d6c28a}\n.so-ekonomi .so-econ-tile .so-econ-tile-icon{border-radius:11px;width:38px;height:38px;font-size:20px;background:linear-gradient(135deg,#566aaa3d,#8bd5c22d)}\n.so-ekonomi .so-econ-tile b{font-size:15px;font-weight:780}\n.so-ekonomi .so-econ-tile small{font-size:11.5px;line-height:1.45}\n.so-ekonomi .so-econ-kpi{border-radius:17px;background:linear-gradient(135deg,#1c294b,#171f3c);border-color:#b6c6fc38;min-height:108px;box-shadow:0 10px 24px -24px #000}\n.so-ekonomi .so-econ-kpi strong{font-family:var(--disp),sans-serif;font-size:clamp(22px,5vw,28px)}\n.so-ekonomi .so-econ-kpi.accent{background:linear-gradient(140deg,#194751,#1c3454);border-color:#87dacc79}\n.so-ekonomi .so-econ-overview-link{margin-top:10px;border-radius:14px;background:#253459;border-color:#adbefe30;min-height:48px}\n.so-ekonomi .so-econ-more{border-radius:17px;border-color:#adbbeb38;background:linear-gradient(135deg,#1d2946,#141d39)}\n.so-ekonomi .so-company{position:relative;border:1px solid #94afd85b;border-radius:19px!important;background:linear-gradient(125deg,#203252,#192342)!important;padding:16px!important;overflow:hidden;box-shadow:0 11px 19px -23px #000;margin-bottom:11px!important}\n.so-ekonomi .so-company:before{content:\"\";position:absolute;width:4px;left:0;top:0;bottom:0;background:#8bd8c6}\n.so-ekonomi .so-company b{font-family:var(--disp),sans-serif;font-size:19px!important;color:#f2f7ff}\n.so-ekonomi .so-company small{font-size:12px;color:#b9c6df;line-height:1.5}\n.so-ekonomi .so-company strong{color:#b0eddc;font-variant-numeric:tabular-nums}\n.so-ekonomi .so-link{border-radius:15px!important;background:linear-gradient(140deg,#1b2949,#18203c);border-color:#a7b9e33c;min-height:72px}\n.so-ekonomi .so-link-ikon{border-radius:12px;background:#52769b27}\n.so-ekonomi .so-ara{border-radius:14px;border-color:#9caff245;background:#0f1833}\n.so-ms-front{display:grid;grid-template-columns:minmax(0,1fr) auto;align-items:center;gap:10px;padding:16px 15px;margin:0 0 14px;border-radius:20px;border:1px solid #8ce7c481;background:linear-gradient(126deg,#214b56,#243358 75%,#302e6a);position:relative;overflow:hidden;color:#f4fffc}\n.so-ms-front:after{content:\"\";position:absolute;width:128px;height:128px;right:-35px;top:-37px;border-radius:50%;box-shadow:0 0 0 20px #ffffff05,0 0 0 43px #ffffff05;pointer-events:none}\n.so-ms-front>*{position:relative;z-index:1}\n.so-ms-front-icon{width:52px;height:52px;border-radius:15px;display:grid;place-items:center;background:#8cf0d52b;border:1px solid #a1ebdf73;font-size:25px}\n.so-ms-front-name{font-family:var(--disp),sans-serif;font-size:22px;line-height:1.1;font-weight:800;display:block;margin:4px 0}\n.so-ms-front-tag{font-size:10px;font-weight:900;letter-spacing:1.2px;color:#a2eedb}\n.so-ms-front p{color:#d0deed;font-size:12px;line-height:1.5;margin:5px 0 0}\n.so-ms-front-actions{grid-column:1/-1;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:2px}\n.so-ms-front-actions button{border-radius:12px;min-height:45px;background:#a2f0dd;border:1px solid #c6fff3;color:#10313d;font-weight:800;font-size:13px;padding:8px}\n.so-ms-front-actions button+button{background:#ffffff16;border-color:#d0e4ff56;color:#f3faff}\n.so-ms-front.compact{margin-top:0;margin-bottom:15px}\n.so-ms-front.compact .so-ms-front-name{font-size:21px}\n@media(min-width:690px){.so-ekonomi .so-econ-tiles{grid-template-columns:repeat(3,minmax(0,1fr))}.so-ms-front{grid-template-columns:minmax(0,1fr) auto}}\n@media(max-width:350px){.so-ms-front{padding:13px}.so-ekonomi .so-econ-tile{padding:11px 10px}.so-ekonomi .so-econ-tiles{gap:7px}}\n";
    s.textContent+="\n/* Detay ekranlarinda Mobil Sube seviyesi: mevcut islevler korunur, yalniz gorunum iyilesir. */\n#icerik.so-econ-deep{--eco-detail-line:rgba(163,185,240,.22)}\n#icerik.so-econ-deep .kart{border-radius:20px;border:1px solid var(--eco-detail-line);background:linear-gradient(135deg,#1b284a,#151e39);box-shadow:0 12px 25px -26px #000;margin-bottom:13px}\n#icerik.so-econ-deep .kart h2,#icerik.so-econ-deep .kart h3{font-family:var(--disp),sans-serif;line-height:1.15;letter-spacing:.1px}\n#icerik.so-econ-deep .kart h2{font-size:clamp(20px,5.2vw,26px)}\n#icerik.so-econ-deep .kart h3{font-size:19px}\n#icerik.so-econ-deep .kart .alt{color:#c0cce2;line-height:1.55}\n#icerik.so-econ-deep .kart .kv{padding-top:11px;padding-bottom:11px;border-bottom-color:rgba(166,193,250,.16);gap:12px}\n#icerik.so-econ-deep .kart .kv b{font-variant-numeric:tabular-nums}\n#icerik.so-econ-deep .kart .btn,#icerik.so-econ-deep>.btn{border-radius:13px;min-height:44px;font-weight:750}\n#icerik.so-econ-deep .alan label{display:block;color:#bbc9e1;font-size:12px;font-weight:700;margin-bottom:6px}\n#icerik.so-econ-deep .alan input,#icerik.so-econ-deep .alan select,#icerik.so-econ-deep .alan textarea{min-width:0;max-width:100%;border-radius:13px;border:1px solid rgba(162,182,233,.30);background:#101a35;color:#f6f9ff;min-height:45px}\n#icerik.so-econ-deep .vit-banka{border-radius:18px;background:linear-gradient(135deg,#233456,#192342);border-color:#b2c3f436}\n#icerik.so-econ-deep .vit-manset{background:linear-gradient(130deg,#1d4851,#1d3055 70%,#262456);border-color:#6cbea958}\n#icerik.so-econ-deep .vit-ozet{gap:10px}\n#icerik.so-econ-deep .vit-ozet>span{border-radius:15px;background:#1b294a;border:1px solid #a6bbec32;padding:11px}\n#icerik.so-econ-deep .vit-stats>span{border-radius:12px;background:#0e1732a8;padding:10px 8px}\n#icerik.so-econ-deep .segment{border-radius:14px;overflow-x:auto}\n#icerik.so-econ-deep .segment button{min-height:40px;border-radius:12px}\n#icerik.so-econ-deep .btn:focus-visible,#icerik.so-econ-deep button:focus-visible{outline:2px solid #93e6d3;outline-offset:2px}\n@media(max-width:370px){#icerik.so-econ-deep .kart{padding:13px}#icerik.so-econ-deep .vit-stats>span{padding:9px 5px}}\n";
    document.head.appendChild(s);
  }
  function tablar(grup){
    var dizi=grup==="adliye"?adliyeSekmeleri:ekonomiSekmeleri;
    return '<nav class="so-tabs" role="tablist" aria-label="'+(grup==="adliye"?"Adliye bölümleri":"Ekonomi bölümleri")+'">'
      +dizi.map(function(x){var aktif=secim[grup]===x[0];
        return '<button type="button" role="tab" aria-selected="'+aktif+'" aria-label="'+esc(x[1])+'"'
          +' onclick="soMenuSec(\''+grup+'\',\''+x[0]+'\')">'
          +(grup==="ekonomi"?'<span class="so-econ-tab-icon" aria-hidden="true">'+x[2]+'</span>':'')
          +'<span>'+esc(x[1])+'</span></button>';
      }).join("")+'</nav>';
  }
  function ciz(grup,icerik){
    var bas=grup==="adliye"?"Adliye":"Ekonomi";
    if(D.sekme!==grup || D.yigin.length) return;
    iskelet(bas,(grup==="ekonomi"?'<div class="so-ekonomi">':"")+tablar(grup)+aramaKutusu(grup)+icerik+(grup==="ekonomi"?"</div>":""));
    var nav=document.querySelector(".so-tabs"),aktif=nav&&nav.querySelector('[aria-selected="true"]');
    if(nav&&aktif)nav.scrollLeft=Math.max(0,aktif.offsetLeft-nav.offsetLeft-nav.clientWidth/3);
  }
  function gecerli(grup,no){return no===istek[grup]&&D.sekme===grup&&!D.yigin.length;}
  window.soMenuSec=function(grup,sekme){
    var dizi=grup==="adliye"?adliyeSekmeleri:ekonomiSekmeleri;
    if(grup==="ekonomi"&&sekme==="islemler")sekme="sirketler";
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

  /* Ekonomi vitrini: özet -> tek dokunuşla ilgili üst sekme. */
  function eTile(ikon,bas,alt,hedef,featured){
    return '<button type="button" class="so-econ-tile'+(featured?' featured':'')+'" onclick="'+hedef+'">'
      +'<span class="so-econ-tile-icon" aria-hidden="true">'+ikon+'</span>'
      +'<b>'+esc(bas)+'</b><small>'+esc(alt)+'</small></button>';
  }
  function eBolum(bas,alt,liste){
    return '<section class="so-econ-section"><div class="so-econ-section-head"><h3>'+esc(bas)+'</h3>'
      +(alt?'<small>'+esc(alt)+'</small>':'')+'</div><div class="so-econ-tiles">'+liste.join("")+'</div></section>';
  }
  function mobilSubeOneCikar(kisa){
    return '<section class="so-ms-front'+(kisa?' compact':'')+'"><div>'
      +'<span class="so-ms-front-tag">◈ BANKACILIK · TEK MERKEZ</span>'
      +'<strong class="so-ms-front-name">Mobil Şube</strong>'
      +'<p>Hesapların, kredi kartların, kredilerin ve birikimlerin tek ekranda.</p></div>'
      +'<span class="so-ms-front-icon" aria-hidden="true">💳</span>'
      +'<div class="so-ms-front-actions">'
      +'<button type="button" onclick="soMenuGit(\'mobilSubeEkrani\')">Mobil Şube'+'’yi aç</button>'
      +'<button type="button" onclick="paraGonderModal()">↗ Para gönder</button></div></section>';
  }
  function ekonomiHero(s){
    var map={
      genel:["Ekonominin nabzı","Ekonomik göstergeler, şirket getirilerin ve önemli işlemlerin tek ekranda."],
      sirketlerim:["Şirketlerim","Kasalarını, şubelerini, projelerini ve ortaklıklarını yönet."],
      sirketler:["Ticaret merkezi","Şirket kur, iş yap, mal al-sat ve ticari işlemlerini izle."],
      bankalar:["Bankalar","Hesapların, kartların, para transferi ve banka yönetimi tek yerde."],
      piyasalar:["Yatırımlar","Borsa, altın, döviz ve halka arz fırsatları."],
      emlak:["Gayrimenkul","Arsa, konut, işyeri, kira ve inşaat yatırımları."],
      giris:["Diğer ekonomik faaliyetler","İş kolları, sigorta, ruhsat ve uzmanlık hizmetleri."]
    };
    var d=map[s]||map.genel;
    if(s==='genel')return '';
    return '<header class="so-econ-banner"><div class="so-econ-eyebrow">◆ EKONOMİ MERKEZİ</div>'
      +'<h2>'+esc(d[0])+'</h2><p>'+esc(d[1])+'</p>'

      +'</header>';
  }
  /* Özet bir kategori listesi değildir: canlı göstergeler + kişisel durum + işlem kısayolları. */
  function eGercekSayi(x){
    if(x===null||x===undefined||x==="")return null;
    var n=Number(x);return Number.isFinite(n)?n:null;
  }
  function eYuzde(x,ondalik){
    var n=eGercekSayi(x);
    return n===null?"—":"%"+n.toLocaleString("tr-TR",{maximumFractionDigits:ondalik===undefined?1:ondalik});
  }
  function eKisaPara(x){
    var n=eGercekSayi(x);if(n===null)return "—";
    var a=Math.abs(n), eksi=n<0?"−":"";
    if(a>=1e9)return eksi+(a/1e9).toLocaleString("tr-TR",{maximumFractionDigits:2})+" Mr ₺";
    if(a>=1e6)return eksi+(a/1e6).toLocaleString("tr-TR",{maximumFractionDigits:2})+" Mn ₺";
    if(a>=1e4)return eksi+(a/1e3).toLocaleString("tr-TR",{maximumFractionDigits:1})+" bin ₺";
    return eksi+Math.round(a).toLocaleString("tr-TR")+" ₺";
  }
  function eKpi(ad,deger,aciklama,renk){
    return '<div class="so-econ-kpi'+(renk?' accent':'')+'"><span>'+esc(ad)+'</span>'
      +'<strong>'+esc(deger)+'</strong>'+(aciklama?'<small>'+esc(aciklama)+'</small>':'')+'</div>';
  }
  function eKpiBolum(bas,acik,kartlar){
    return '<section class="so-econ-section"><div class="so-econ-section-head"><h3>'+esc(bas)+'</h3>'
      +'<small>'+esc(acik)+'</small></div><div class="so-econ-kpi-grid">'+kartlar.join("")+'</div></section>';
  }
  async function ekonomiGenel(){
    // Üç sorgu aynı anda çalışır. Eksik yanıtlar göstergeye hayali 0 olarak yazılmaz.
    var sonuclar=await Promise.allSettled([
      API.rpc("piyasa_panosu"),API.rpc("merkez_bankasi"),API.rpc("banka_yonetilen_liste")
    ]);
    var p=sonuclar[0].status==="fulfilled"?sonuclar[0].value:null;
    var m=sonuclar[1].status==="fulfilled"?sonuclar[1].value:null;
    var b=sonuclar[2].status==="fulfilled"?sonuclar[2].value:null;
    var bankalar=Array.isArray(b)?b:[];
    var endeks=p&&p.endeks?p.endeks:{};
    var benim=p&&p.benim?p.benim:{};
    var göstergeler=[];
    if(eGercekSayi(endeks.deger)!==null){
      var dg=eGercekSayi(endeks.degisim),detay="Şirketler endeksi";
      if(dg!==null)detay="Dünkü kapanışa göre "+(dg>0?"▲ ":dg<0?"▼ ":"= ")+eYuzde(Math.abs(dg),1);
      göstergeler.push(eKpi("Şirketler endeksi",Number(endeks.deger).toLocaleString("tr-TR",{maximumFractionDigits:2}),detay,true));
    }
    if(m&&eGercekSayi(m.enflasyon)!==null)göstergeler.push(eKpi("Enflasyon",eYuzde(m.enflasyon,1),"Oyundaki güncel oran"));
    if(m&&eGercekSayi(m.politika_faiz)!==null)göstergeler.push(eKpi("Politika faizi",eYuzde(m.politika_faiz,2),"Yıllık"));
    if(m&&eGercekSayi(m.buyume)!==null)göstergeler.push(eKpi("Ekonomik büyüme",eYuzde(m.buyume,1),"Oyundaki güncel oran"));
    var gosterge='<section class="so-econ-section"><div class="so-econ-section-head"><h3>Türkiye ekonomisi</h3>'
      +'<small>Canlı oyun verileri</small></div>'
      +(göstergeler.length?'<div class="so-econ-kpi-grid">'+göstergeler.join("")+'</div>'
        :'<p class="so-econ-overview-note">Ekonomik göstergeler şu anda alınamıyor. Detaylı piyasa panosundan tekrar deneyebilirsin.</p>')
      +'<button type="button" class="so-econ-overview-link" onclick="soMenuGit(\'piyasaPanosuEkrani\')">'
      +'<span>📊 Detaylı piyasa panosu ve şirketler endeksi</span><span aria-hidden="true">›</span></button></section>';
    var kisisel=[];
    if(Array.isArray(benim.sirketler))kisisel.push(eKpi("Ortak olduğum şirket",String(benim.sirketler.length),"Şirket portföyüm"));
    if(eGercekSayi(benim.portfoy)!==null)kisisel.push(eKpi("Şirket paylarımın değeri",eKisaPara(benim.portfoy),"Tahmini portföy değeri"));
    if(eGercekSayi(benim.bugun)!==null)kisisel.push(eKpi("Bugünkü kâr payım",eKisaPara(benim.bugun),"Bugünkü şirket getirisi"));
    if(eGercekSayi(benim.hafta)!==null)kisisel.push(eKpi("Son 7 günlük kâr",eKisaPara(benim.hafta),"Şirket paylarımdan"));
    if(bankalar.length)kisisel.push(eKpi("Yönettiğim banka",String(bankalar.length),"Banka sahipliği"));
    var durum=kisisel.length?eKpiBolum("Benim ekonomik durumum","Kişisel şirket performansım",kisisel):"";
    var islemler=eBolum("Hemen işlem yap","Kategoriler değil, doğrudan işlemler",[
      eTile("➕","Şirket kur","Yeni şirket kuruluşu","soMenuGit('sirketKurulumFormuAc')",true),
      eTile("💸","Para gönder","Oyuncuya banka transferi","soMenuGit('paraGonderModal')"),
      eTile("🤝","Ortaklık işlemleri","Davetler, ortaklık, hisse devri","soMenuGit('ortaklikEkrani')"),
      eTile("📋","İhaleye katıl","Kamu ihalesine teklif ver","soMenuGit('ihaleEkrani')")
    ]);
    var yonet=bankalar.length?eBolum("Banka sahibi işlemlerim","Doğrudan yönetim",[
      eTile("🏦","Bankamı yönet","Kasa ve banka yönetimi","soBankaYonetimGit('ozet')",true),
      eTile("📥","Başvuruları incele","Kredi, POS ve kart başvuruları","soBankaYonetimGit('basvuru')"),
      eTile("⚙️","Otomatik kararlar","Onay ve ret kuralları","soBankaYonetimGit('ayar')")
    ]):"";
    return '<div class="so-econ-overview">'+mobilSubeOneCikar(false)+gosterge+durum+islemler+yonet+'</div>';
  }
  function bankalarGenel(){
    return mobilSubeOneCikar(true)
      +eBolum("Bankalar ve kuruluş","Bankaları keşfet ve karşılaştır",[
        eTile("🏦","Oyuncu bankaları","Faizler, kasa ve banka şubeleri","soMenuGit('bankaRehberiEkrani')",true),
        eTile("📊","Bankaları karşılaştır","Vade, kredi ve güven notu","ekranAc(function(){return mobilSubeEkrani('bankalar')})"),
        eTile("➕","Özel banka kur","Banka kuruluşu ve sermaye","soMenuGit('bankaKurEkrani')")
      ])
      +eBolum("Ticari bankacılık","Kısayollar",[
        eTile("🧾","Çek defterim","Çek yaz, tahsil et, öde","soMenuGit('cekMerkeziAc')"),
        eTile("🏪","POS yönetimi","Cihazlar ve kartlı satış","soMenuGit('kartPosEkrani')"),
        eTile("📄","Finansal dosyalar","Mevduatlar ve kredilerim","ekranAc(function(){return mobilSubeEkrani('birikim')})")
      ]);
  }
  async function bankalarHtml(){
    var z="",b=[];
    try{var r=await API.rpc("banka_yonettiklerim");if(Array.isArray(r))b=r;}catch(_){
      try{var r2=await API.rpc("banka_yonetilen_liste");if(Array.isArray(r2))b=r2;}catch(err){
        z+='<p class="so-econ-intro">Banka yönetim bilgileri şu an yüklenemedi: '+esc(err.message||err)+'</p>';
      }
    }
    if(b.length){
      z+=eBolum("Benim bankalarım","Genel Müdürlük: kasa, başvurular, faizler, kâr payı ve DİBS",b.map(function(x,i){
        var bek=Number(x.bekleyen)||0;
        var alt=(x.not?"Güven notu "+x.not+" · ":"")+(bek?bek+" başvuru bekliyor":"Bekleyen başvuru yok");
        return eTile("🏛️",x.ad||"Banka",alt,"bankaGenelMudurlukEkrani("+Number(x.id)+")",i===0);
      }));
    }
    return bankalarGenel()+z;
  }
  window.soMenuBanka=function(id,tab){
    if(typeof window.bankaYonetimEkrani!=="function"){
      toast("Banka yönetimi yükleniyor. Sayfayı yenileyip yeniden dene.",true);return;
    }
    return ekranAc(function(){return bankaYonetimEkrani(Number(id),tab||'ozet');});
  };
  window.soBankaYonetimGit=async function(tab){
    try{
      var own=(await API.rpc("banka_yonetilen_liste"))||[];
      if(!own.length)return toast("Yönetim yetkin olan bir banka bulunamadı.",true);
      if(own.length>1){
        soMenuSec('ekonomi','bankalar');
        toast("Yöneteceğin bankayı 'Benim Bankalarım' alanından seç.");return;
      }
      return window.soMenuBanka(Number(own[0].id),tab||'ozet');
    }catch(err){toast("Banka yönetimi açılamadı: "+String(err&&err.message||err),true);}
  };
  async function sirketlerimHtml(){
    try{
      var d=await API.rpc("ortak_sirket_panel");
      var list=(d.sirketler||[]).slice().sort(function(a,b){return String(a.ad).localeCompare(String(b.ad),"tr");});
      var top='<div class="so-econ-metrics">'
        +'<div class="so-econ-metric"><strong>'+list.length+'</strong><span>Şirket / ortaklık</span></div>'
        +'<div class="so-econ-metric"><strong>'+list.filter(function(s){return Number(s.benim_pay)>=50;}).length+'</strong><span>Yönetim payım olan</span></div></div>';
      var z=top+baslik("Şirket portföyüm","Şirketini seçerek kasa, sermaye, şube, üretim ve projeleri yönet.");
      if(!list.length)z+=bos("Henüz şirketin yok. Aşağıdan şirket kurabilirsin.");
      else z+='<input type="search" class="so-ara" aria-label="Şirketlerimde ara" placeholder="Şirket veya sektör ara…" oninput="soMenuSirketAra(this.value)" /><div id="so-sirket-liste">'+list.map(function(s){
        return '<button type="button" class="so-company" onclick="soMenuSirket('+Number(s.id)+')">'
          +'<b>🏢 '+esc(s.ad)+' <span style="float:right;color:#9ee8d4">›</span></b>'
          +'<small>'+esc(s.sektor)+' · Hissen %'+esc(s.benim_pay)+'</small>'
          +'<strong>Kasa '+trPara(s.kasa)+' · Sermaye '+trPara(s.sermaye)+'</strong>'
          +'<small>Yönetim paneli, şubeler, stok, inşaat ve ortaklık</small></button>';
      }).join("")+'</div>';
      if((d.kuruluslar||[]).length||(d.devirler||[]).length)
        z+=kart("Bekleyen ortaklık işlemleri",'<p class="alt">Kuruluş daveti: '+(d.kuruluslar||[]).length
         +' · Hisse devri: '+(d.devirler||[]).length+'</p>'
         +link("🤝","Davetler ve ortaklıklar","Gelen tekliflere yanıt ver.","soMenuGit('ortaklikEkrani')"));
      return z+baslik("Şirket işlemleri","Yeni şirket, ortaklık ve sahip olduğun şirketlerin finansmanı.")
        +grids([
          link("➕","Yeni şirket kur","Şehir, sektör ve kuruluş sermayesi belirle.","soMenuGit('sirketKurulumFormuAc')"),
          link("🤝","Ortaklık merkezi","Birlikte şirket kur, hisse devret, pay satın al.","soMenuGit('ortaklikEkrani')"),
          link("📊","Şirketlerimin gelirleri","Kâr, zarar ve finansal raporlarını incele.","soMenuGit('sirketlerimMerkezi')"),
          link("💼","Finans ve kazanç","Şirket gelirlerini incele, finansı yönet.","soMenuGit('sirketlerimMerkezi')")
        ]);
    }catch(err){
      return kart("Şirketlerim",'<p class="alt">Şirket listesi alınamadı: '+esc(err.message)+'</p>'
      +link("🏢","Şirket yönetimine git","Alternatif şirket listesi.","soMenuGit('sirketlerimMerkezi')"));
    }
  }
  function sirketlerHtml(){
    return eBolum("Şirket kur ve keşfet","Şirket pazarı",[
      eTile("➕","Yeni şirket kur","Sektör, şehir, sermaye seç","soMenuGit('sirketKurulumFormuAc')",true),
      eTile("🏢","Tüm şirketler","Şirketleri ve sahiplerini keşfet","soMenuGit('sirketVitrinEkrani')"),
      eTile("🏷️","Satılık şirketler","İlanları incele ve şirket satın al","soMenuGit('sirketPazarEkrani')"),
      eTile("🤝","Hisse ve ortaklık","Şirket hisseleri ve ortaklıklar","soMenuGit('sirketHissePazariEkrani')")
    ])
    +eBolum("Üretim ve ticaret","İşletmeler ve satış",[
      eTile("🏭","İş dünyası","Fabrika, franchise ve üretim","soMenuGit('isDunyasiEkrani')"),
      eTile("🛍️","Market ve mağaza","Ürünler, şirketler ve ticaret","soMenuGit('pazarMerkezEkrani')"),
      eTile("📦","Toptan ticaret","Mal ve stok alım-satımı","soMenuGit('kamuToptanEkrani')"),
      eTile("📋","Kamu ihaleleri","İlanlar ve teklif işlemleri","soMenuGit('ihaleEkrani')")
    ])
    +eBolum("Ödeme ve kayıtlar","Ticari işlemler",[
      eTile("📜","İşlem geçmişim","Alış ve satış hareketleri","soMenuGit('ticaretGecmisimEkrani')"),
      eTile("💸","Para gönder","Banka transferi yap","soMenuGit('paraGonderModal')"),
      eTile("🧾","Çeklerim","Çek düzenle, öde ve takip et","soMenuGit('cekMerkeziAc')"),
      eTile("🏪","POS yönetimi","POS başvuruları ve satış","soMenuGit('kartPosEkrani')")
    ]);
  }
  function piyasalarHtml(){
    return eBolum("Yatırım araçları","Alım-satım",[
      eTile("📈","Altın ve döviz","Fiyatlar ve alım satım","soMenuGit('piyasaEkrani')",true),
      eTile("💱","Kuyumcu ve döviz ofisleri","Oyuncu dükkânları, alış-satış","soMenuGit('meslekOfisEkrani')"),
      eTile("📊","Borsa","Hisseler ve piyasa hareketleri","soMenuGit('borsaEkrani')"),
      eTile("🚀","Halka arzlar","Yeni şirketlere yatırım","soMenuGit('halkaArzPazarEkrani')"),
      eTile("🧾","Belediye tahvilleri","Tahvil getirileri ve işlemler","soMenuGit('belediyeTahvilEkrani')")
    ])
    +eBolum("Ekonomik görünüm","Rapor ve istatistikler",[
      eTile("📊","Ekonomi raporu","Piyasa, büyüme ve rekabet","soMenuGit('ekonomiMerkeziEkrani')")
    ])
    +'<details class="so-econ-more"><summary>Düzenleyici kurumlar</summary>'
    +grids([
      link("🏛️","Merkez Bankası","Faiz ve PPK kararları.","soMenuGit('merkezBankasiEkrani')"),
      link("⚖️","Sermaye Piyasası Kurulu","Sermaye piyasası düzeni.","soMenuGit('spkEkrani')"),
      link("📉","Rekabet Kurumu","Piyasa rekabeti.","soMenuGit('rekabetEkrani')")
    ])+'</details>';
  }
  function emlakHtml(){
    return eBolum("Gayrimenkul piyasası","Satın al, sat, kiraya ver",[
      eTile("🏠","Emlak pazarı","Ev, işyeri ve arsa ilanları","soMenuGit('emlakYeniEkrani')",true),
      eTile("🏡","Yatırım pazarı","Ticari mülk ve kira getirisi","soMenuGit('yatirimPazarEkrani')"),
      eTile("🏗️","İnşaatlarım","Şirketimi açıp projeleri yönet","soMenuSec('ekonomi','sirketlerim')"),
      eTile("🏬","İşyerlerim","Şube ve dükkân yönetimi","soMenuSec('ekonomi','sirketlerim')")
    ]);
  }
  function girisHtml(){
    return eBolum("İşletme hizmetleri","Gündelik işlemler",[
      eTile("🛡️","Sigorta","Poliçe ve hasar işlemleri","soMenuGit('msSigortaAc')",true),
      eTile("🏛️","Ruhsatlar","İşyeri ve inşaat ruhsatları","soMenuGit('msRuhsatMerkeziAc')"),
      eTile("💼","Ek işler","Kurye, taksi, özel ders ve işler","soMenuGit('ekIslerEkrani')"),
      eTile("📢","Ajanslar","Reklam ve kamuoyu araştırması","soMenuGit('ajansMerkezEkrani')")
    ])
    +'<details class="so-econ-more"><summary>Daha fazla faaliyet ve hizmet</summary>'
    +grids([
      link("🌾","Tarım ve hayvancılık","Üretim, hasat ve tedarik.","soMenuUc('tarim')"),
      link("📚","Kitap ve yayınevi","Kitap yaz, bas ve sat.","soMenuUc('kitap')"),
      link("📺","Medya","Yayıncılık ve medya şirketleri.","soMenuUc('medya')"),
      link("🎟️","Organizasyon","Etkinlik ve biletli işler.","soMenuUc('etkinlik')"),
      link("⚖️","Konkordato ve iflas","İşletme borç yapılandırmaları.","soMenuGit('konkordatoEkrani')"),
      link("📢","İhale ilan panosu","Tüm kamu ihaleleri.","soMenuGit('msIhaleMerkeziAc')"),
      link("🤝","Siyasi bağışlar","Şirketten siyasi bağış.","soMenuGit('siyasiBagisEkrani')")
    ])+'</details>';
  }
  /* Eski işlem bağlantılarına uyumluluk: yeni Ticaret sekmesi. */
  function islemlerHtml(){return sirketlerHtml();}
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
  /* Mobil ekonomide sekmeler piyasa panosunun ustunde gorunsun. Piyasa
     panosunun verisini ya da baska ekranlarin siralamasini degistirmez. */
  (function(){
    let scheduled=false;
    function yerlestir(){
      if(typeof D==='undefined'||D.sekme!=='ekonomi'||D.yigin.length){
        const eski=document.getElementById('so-tabs-piyasa-ust');
        if(eski)eski.remove();
        return;
      }
      const nav=document.querySelector('#icerik .so-ekonomi .so-tabs');
      if(!nav)return;
      const root=document.getElementById('app')||document.body;
      const panolar=[...root.querySelectorAll('.kart,.sahne,.piyasa-panosu,.piyasa-ozet')];
      const pano=panolar.find(el=>{
        if(el.closest('#icerik'))return false;
        const txt=(el.querySelector('h2,h3,small,.kucuk')||el).textContent||'';
        return /piyasa panosu|şirketler endeksi/i.test(txt) && /piyasa panosu|şirketler endeksi/i.test(el.textContent||'');
      });
      const once=document.getElementById('so-tabs-piyasa-ust');
      if(!pano){if(once)once.remove();nav.style.display='';return;}
      if(once && once.dataset.from===nav.dataset.soNavId && once.nextElementSibling===pano)return;
      if(once)once.remove();
      // Ustte orijinal sekmelerin calisan bir kopyasi. Butonlar zaten
      // soMenuSec'e yonlenir, piyasa karti yerinden koparilmaz.
      if(!nav.dataset.soNavId)nav.dataset.soNavId=String(Date.now())+String(Math.random());
      const sarmal=document.createElement('div');
      sarmal.className='so-ekonomi';sarmal.id='so-tabs-piyasa-ust';
      sarmal.dataset.from=nav.dataset.soNavId;
      sarmal.style.cssText='margin:0 0 4px;padding:0;';
      const yeni=nav.cloneNode(true);
      yeni.style.cssText='position:relative;top:auto;z-index:8;margin:8px 0 12px;width:100%;';
      sarmal.appendChild(yeni);
      pano.parentNode.insertBefore(sarmal,pano);
      nav.style.display='none';
    }
    const obs=new MutationObserver(()=>{
      if(scheduled)return;
      scheduled=true;
      requestAnimationFrame(()=>{scheduled=false;yerlestir();});
    });
    obs.observe(document.getElementById('app')||document.body,{childList:true,subtree:true});
    yerlestir();
  })();
  /* Alt islem ekranlari da Ekonomi tasarim dilini kullanir; Mobil Sube kendi stilini korur. */
  function soEkonomiDerinStil(){
    var kutu=document.getElementById("icerik");if(!kutu)return;
    var uygun=typeof D==="object"&&D&&D.sekme==="ekonomi"
      &&!kutu.querySelector(".so-ekonomi,.bk,.vit-premium");
    if(kutu.classList.contains("so-econ-deep")!==!!uygun)kutu.classList.toggle("so-econ-deep",!!uygun);
  }
  if(typeof MutationObserver==="function"&&document.body){
    new MutationObserver(soEkonomiDerinStil).observe(document.body,{childList:true,subtree:true});
    soEkonomiDerinStil();
  }
})();


/* SO_GUNDEM_BASIN_MAKAMLAR_V2 — Gündem kısayolları, kısa seçim arşivi ve tıklanabilir makamlar.
   Sadece görünüm / mevcut ekranlara yönlendirme; RPC, seçim verisi ve yetkilere dokunmaz. */
(function(){
 "use strict";
 if(window.SO_GUNDEM_BASIN_MAKAMLAR_V2)return;
 window.SO_GUNDEM_BASIN_MAKAMLAR_V2=true;

 function temiz(x){return String(x==null?"":x).replace(/[&<>"']/g,function(c){
   return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];
 });}
 function profil(){return typeof D!=="undefined"&&D.durum&&D.durum.profil?D.durum.profil:null;}
 function go(f){
   if(typeof f!=="function"){if(typeof toast==="function")toast("Bu bölüm henüz yüklenmedi. Sayfayı yenileyip yeniden dene.",true);return;}
   if(typeof ekranAc==="function")return ekranAc(f);
   return f();
 }
 window.soYayinGit=function(k){
   if(k==="akis")return go(typeof akisEkrani==="function"?akisEkrani:window.akisEkrani);
   if(k==="basin")return go(typeof basinEkrani==="function"?basinEkrani:window.basinEkrani);
   if(k==="turkiye")return go(typeof otomatikGazeteEkrani==="function"?function(){return otomatikGazeteEkrani();}:window.otomatikGazeteEkrani);
   if(k==="kitap")return go(window.soKitapVitriniAc);
 };
 window.soAkisDaha=async function(){
   var dugme=document.getElementById("so-akis-daha");
   var kutu=document.getElementById("gAkisListe");
   if(!dugme||!kutu||dugme.disabled||typeof AKIS==="undefined"||typeof akisBagla!=="function")return;
   var liste=Array.isArray(AKIS.gundemListe)?AKIS.gundemListe:[];
   var son=liste[liste.length-1];if(!son){dugme.hidden=true;return;}
   dugme.disabled=true;dugme.textContent="Paylaşımlar yükleniyor…";
   try{
     var yeni=await API.rpc("akis_liste",{p_kapsam:"herkes",p_onceki:son.id,p_limit:20});
     yeni=Array.isArray(yeni)?yeni:[];
     var varOlan=new Set(liste.map(function(a){return String(a.id);}));
     AKIS.gundemListe=liste.concat(yeni.filter(function(a){return !varOlan.has(String(a.id));}));
     kutu.innerHTML=AKIS.gundemListe.map(akisSatirHtml).join("");
     akisBagla(kutu,function(){return AKIS.gundemListe;},window.soAkisYenile);
     dugme.hidden=yeni.length<20;
   }catch(err){
     if(typeof toast==="function")toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);
   }finally{dugme.disabled=false;dugme.textContent="Daha fazla paylaşım yükle";}
 };
 window.soAkisYenile=async function(){
   var kutu=document.getElementById("gAkisListe");if(!kutu||typeof AKIS==="undefined")return;
   try{
     var miktar=Math.min(100,Math.max(5,(AKIS.gundemListe||[]).length));
     var yeni=await API.rpc("akis_liste",{p_kapsam:"herkes",p_limit:miktar});
     AKIS.gundemListe=Array.isArray(yeni)?yeni:[];
     kutu.innerHTML=AKIS.gundemListe.map(akisSatirHtml).join("");
     akisBagla(kutu,function(){return AKIS.gundemListe;},window.soAkisYenile);
   }catch(_){}
 };
 var soTakvimSayfaHtml="";
 window.soSecimTakvimiEkrani=function(){
   var govde=soTakvimSayfaHtml||'<div class="kart"><p class="alt">Seçim bilgileri henüz yüklenmedi. Gündem sayfasından yeniden açabilirsin.</p></div>';
   return iskelet("Seçim takvimi",'<div class="so-menu-hero"><h2>🗳️ Seçim takvimi ve sonuçlar</h2><p>Seçim aşamaları, yaklaşan tarihler, adaylık işlemleri ve sonuçlar tek ekranda.</p></div>'+govde,{geri:true});
 };
 window.soGundemTakvimAc=function(){
   return go(window.soSecimTakvimiEkrani);
 };
 window.soMakamGit=function(tur){
   var p=profil();
   if(!p)return;
   var yetkili=(p.makamlar||[]).some(function(m){return m.tur===tur;});
   if(tur==="parti"){
     if(!(p.parti&&(p.gb||p.gb_vekaleten||p.gby)))return;
     var id=Number(p.parti.id);
     return go(typeof partiDetay==="function"&&id>0?function(){return partiDetay(id);}:null);
   }
   if(!yetkili)return;
   if(tur==="bel"){
     if(typeof D!=="undefined")D._belediyeSehirMod="ozet";
     return go(typeof belediyeSehirYonetimEkrani==="function"?belediyeSehirYonetimEkrani:window.belediyeSehirYonetimEkrani);
   }
   if(tur==="bakan"){
     var bolumler=document.querySelectorAll(".ynt-bolum");
     for(var i=0;i<bolumler.length;i++){
       if(/Bakanlık yönetim masası/.test(bolumler[i].textContent||"")){
         bolumler[i].scrollIntoView({behavior:"smooth",block:"start"});return;
       }
     }
     return go(typeof yonetimEkrani==="function"?yonetimEkrani:window.yonetimEkrani);
   }
   if(["tbmm","bskv","grup_bskv","mv"].indexOf(tur)!==-1)return sekmeAc("meclis");
   if(["cb","cb_yardimcisi","bakan"].indexOf(tur)!==-1){
     D.devletSekme="hukumet";
     return sekmeAc("devlet");
   }
 };
 window.soMakamimAc=function(){
   var dugmeler=document.querySelectorAll(".segment button,.sekme-cip button");
   for(var i=0;i<dugmeler.length;i++){
     if(/Makam(ım|larım)?/i.test(dugmeler[i].textContent||"")){dugmeler[i].click();return;}
   }
   if(typeof yonetimEkrani==="function")return go(yonetimEkrani);
   if(typeof sekmeAc==="function")return sekmeAc("devlet");
 };
 function stiller(){
   if(document.getElementById("so-gundem-makam-stil"))return;
   var style=document.createElement("style");style.id="so-gundem-makam-stil";
   style.textContent=
     ".so-gundem-kisa{margin:4px 0 16px}.so-kisa-bas{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:0 2px 9px}.so-kisa-bas b{font-weight:850;font-size:16px}"+
     ".so-kisa-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.so-kisa-kart{display:flex;align-items:center;gap:10px;min-width:0;min-height:73px;border:1px solid var(--line2);border-radius:17px;background:var(--panel2);color:var(--txt);text-align:left;padding:12px;cursor:pointer;font:inherit}"+
     ".so-canli-akis{margin:8px 0 16px}.so-canli-akis>.bolum-bas{margin:0 0 10px}.so-canli-akis .akis-kart{margin-bottom:0}.so-akis-daha{margin-top:12px;min-height:42px}.so-canli-oylama{margin:6px 0 16px}.so-canli-oylama>.bolum-bas{margin:0 0 9px}.so-canli-oylama>[id^=sec] .olay{margin:0 0 9px}"+
     ".so-kisa-kart:active,.so-makam-btn:active{transform:scale(.992);background:var(--panel3)}"+
     ".so-kisa-simge{flex:0 0 auto;font-size:23px}.so-kisa-metin{min-width:0;flex:1}.so-kisa-metin b{display:block;font-size:15px}.so-kisa-metin small{display:block;color:var(--mut);font-size:11.5px;line-height:1.3;margin-top:3px}.so-kisa-ok{color:var(--ink2);font-size:23px}"+
     ".so-secim-arsiv{margin:12px 0;scroll-margin-top:90px;padding:0!important;overflow:hidden}.so-secim-arsiv summary{list-style:none;display:flex;gap:10px;align-items:center;padding:15px;cursor:pointer}.so-secim-arsiv summary::-webkit-details-marker{display:none}.so-secim-arsiv summary b{display:block}.so-secim-arsiv summary small{color:var(--mut);font-size:12px;display:block;margin-top:3px}.so-secim-arsiv[open] summary{border-bottom:1px solid var(--line2)}.so-secim-arsiv-govde{padding:12px}.so-secim-arsiv-govde>.kart,.so-secim-arsiv-govde>[id^=sec]{margin:0 0 10px}.so-secim-arsiv-govde .olay{margin:0 0 10px}"+
     ".so-makam-secim{display:grid;grid-template-columns:repeat(1,minmax(0,1fr));gap:8px;margin-top:12px}.so-makam-btn{width:100%;display:flex;align-items:center;gap:12px;border:1px solid var(--line2);background:var(--panel2);border-radius:14px;color:var(--txt);text-align:left;padding:13px;cursor:pointer;font:inherit}.so-makam-emoji{font-size:23px;flex:0 0 28px}.so-makam-icerik{flex:1;min-width:0}.so-makam-icerik b{display:block;font-size:14px}.so-makam-icerik small{display:block;font-size:12px;color:var(--mut);margin-top:4px;line-height:1.3}.so-makam-ok{color:var(--ink2);font-size:24px}.so-makam-kart{border-color:rgba(168,149,255,.38)!important}.so-makam-hizli{margin:4px 0 12px}.so-makam-hizli button{width:100%;border-radius:13px;min-height:46px;text-align:left;padding:11px 13px;background:var(--panel2);color:var(--txt);border:1px solid var(--line2);font:inherit;font-weight:750}"+
     "@media(min-width:700px){.so-kisa-grid{grid-template-columns:repeat(4,minmax(0,1fr))}.so-makam-secim{grid-template-columns:repeat(2,minmax(0,1fr))}}";
   document.head.appendChild(style);
 }
 var kaynakIskelet=window.iskelet;
 if(typeof kaynakIskelet!=="function")return;

 // Gündem sıralaması için TEK KAYNAK: Mağaza > Sponsorlu > kayan VTR >
 // canlı oy verme > Basın/Yayın > gerçek Akış. Diğer Gündem blokları bu altılının arkasında.
 // Mağaza / sponsor / siyaset merkezi farklı async ekran oluşturuculardan geldiği için,
 // önceki sırayı bozan DOM eklemeleri ve yeni #icerik oluşumları birlikte izlenir.
 var soGundemGozlemci=null,soSiralamada=false;
 function soGundemDomSirala(icerik){
   if(!icerik||!icerik.isConnected||soSiralamada)return;
   var baslik=document.querySelector(".ust h1");
   if(!baslik||baslik.textContent.trim()!=="Gündem")return;
   var cocuklar=Array.from(icerik.children);
   function bul(sel){return cocuklar.find(function(x){return x.matches(sel);})||null;}
   var magaza=bul("#mgSerit,.mg-serit");
   var reklamlar=cocuklar.filter(function(x){return x.matches(".aj-sponsor,.aj-ek");});
   var kayan=bul(".serit");
   var secim=bul(".secim-ust,.so-canli-oylama");
   // Canlı seçim farklı modülden geldiğinde, içerikte görünen "Aktif Seçimler"
   // üst başlığından da tespit edilir (HTML sınıfı değişse bile).
   var asil=bul(".secim-ust");
   if(!asil){
     asil=cocuklar.find(function(x){
       return x!==secim && x.querySelector &&
         Array.from(x.querySelectorAll("h2,h3")).some(function(h){
           return /^Aktif Seçimler$/i.test((h.textContent||"").trim());
         }) && /Sandık açık/i.test(x.textContent||"");
     })||null;
   }
   if(asil){
     if(secim&&secim!==asil&&secim.classList.contains("so-canli-oylama")){
       secim.remove(); // Aynı açık sandık iki kez gösterilmesin.
     }
     secim=asil;
   }
   var yayin=bul(".so-gundem-kisa");
   var akis=bul(".so-canli-akis");
   var hafta=bul(".sm-gundem");
   // Akış her zaman Siyasi hafta kartından önce gelir; ikisi farklı zamanlarda yüklenebilir.
   var ust=[magaza].concat(reklamlar,[kayan,secim,yayin,akis,hafta]).filter(Boolean);
   if(ust.every(function(el,i){return icerik.children[i]===el;}))return;
   soSiralamada=true;
   try{
     var sonrakiler=icerik.firstChild;
     // Var olan öğeleri yeniden oluşturmadan taşı: veri, event ve içerik bozulmaz.
     for(var i=ust.length-1;i>=0;i--)icerik.insertBefore(ust[i],icerik.firstChild);
   }finally{soSiralamada=false;}
 }
 function soGundemSiralamayiBagla(){
   var icerik=document.getElementById("icerik");
   if(icerik)soGundemDomSirala(icerik);
 }
 function soGundemKaliciGozlemci(){
   if(soGundemGozlemci||typeof MutationObserver!=="function")return;
   // Tüm #app izlenir: iskelet #icerik'i baştan oluşturduğunda önceki gözlemci kaybolmasın.
   var app=document.getElementById("app")||document.body;
   soGundemGozlemci=new MutationObserver(function(){
     soGundemSiralamayiBagla();
   });
   soGundemGozlemci.observe(app,{childList:true,subtree:true});
   soGundemSiralamayiBagla();
 }
 function gundemYenile(html){
   var kok=document.createElement("div");kok.innerHTML=html;
   var eskigaz=kok.querySelector(".vit-gazete");if(eskigaz)eskigaz.remove();
   var hizli=document.createElement("section");hizli.className="so-gundem-kisa";hizli.setAttribute("aria-label","Basın ve yayın kısayolları");
   hizli.innerHTML='<div class="so-kisa-bas"><b>🗞️ Basın, yayın ve topluluk</b><span class="kucuk">Gündemin merkezi</span></div>'+
     '<div class="so-kisa-grid">'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'basin\')"><span class="so-kisa-simge">📰</span><span class="so-kisa-metin"><b>Gazeteler</b><small>Oyuncu gazeteleri ve köşe yazıları</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'turkiye\')"><span class="so-kisa-simge">🇹🇷</span><span class="so-kisa-metin"><b>Türkiye Gündemi</b><small>Otomatik haberler ve manşetler</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soYayinGit(\'kitap\')"><span class="so-kisa-simge">📚</span><span class="so-kisa-metin"><b>Kitaplar ve yayınevleri</b><small>Yayınları oku, satın al veya eser yayımla</small></span><span class="so-kisa-ok">›</span></button>'+
       '<button type="button" class="so-kisa-kart" onclick="soGundemTakvimAc()"><span class="so-kisa-simge">🗳️</span><span class="so-kisa-metin"><b>Seçim takvimi</b><small>Yaklaşan tarihler ve eski sonuçlar</small></span><span class="so-kisa-ok">›</span></button>'+
     '</div>';
   // Basın ve yayın kısayolları Akıştan önce gelir; diğer Gündem kartları kendi sırasında kalır.
   kok.insertBefore(hizli,kok.firstChild);
   // Mevcut çalışan Akış kartını alt bölgeden al ve Basın-Yayın'ın üzerine taşı.
   // Orijinal textarea, beğeni, yanıt ve etiket bağlayıcıları yerinde kalır.
   var akisKart=kok.querySelector(".akis-kart"), akisBolumu=null;
   if(akisKart){
     akisBolumu=document.createElement("section");
     akisBolumu.className="so-canli-akis";
     var akisBas=akisKart.previousElementSibling;
     if(akisBas&&akisBas.classList.contains("bolum-bas")&&/Akış/.test(akisBas.textContent||"")){
       akisBolumu.appendChild(akisBas);
     }else{
       akisBolumu.innerHTML='<div class="bolum-bas"><h2>Akış</h2><button class="kucuk" onclick="soYayinGit(\'akis\')">Tümünü gör ›</button></div>';
     }
     akisBolumu.appendChild(akisKart);
     var akisListe=akisKart.querySelector("#gAkisListe");
     if(akisListe&&akisListe.querySelectorAll(".akis-satir").length>=5){
       var daha=document.createElement("button");
       daha.type="button";daha.id="so-akis-daha";daha.className="btn ikinci so-akis-daha";
       daha.textContent="Daha fazla paylaşım yükle";daha.setAttribute("onclick","soAkisDaha()");
       akisKart.appendChild(daha);
     }
     hizli.insertAdjacentElement("afterend",akisBolumu);
   }
   // Sandık gerçekten açık olduğu müddetçe oy kartlarını Akış'ın önüne taşı.
   // Adaylıklar, ileri tarihli seçimler, sayımlar ve bitenler burada gösterilmez.
   var an=typeof simdi==="function"?simdi():Date.now();
   var takvimAnlik=typeof D!=="undefined"&&D.durum&&Array.isArray(D.durum.takvim)?D.durum.takvim:[];
   var acikSandiklar=takvimAnlik.filter(function(s){
     var bas=Date.parse(s.oy_bas),bit=Date.parse(s.oy_bit);
     return s.asama==="oy"&&Number.isFinite(bas)&&Number.isFinite(bit)&&bas<=an&&an<bit;
   });
   if(acikSandiklar.length){
     var oyBolumu=document.createElement("section");
     oyBolumu.className="so-canli-oylama";
     oyBolumu.setAttribute("aria-label","Aktif seçimler ve oy kullanma");
     oyBolumu.innerHTML='<div class="bolum-bas"><h2>🗳️ Sandık açık</h2><span class="rozet kirmizi">Oy kullan</span></div>';
     acikSandiklar.forEach(function(s){
       var node=kok.querySelector('[id="sec'+Number(s.id)+'"]');
       if(node&&node.querySelector(".olay.oy"))oyBolumu.appendChild(node);
     });
     if(oyBolumu.querySelector('[id^="sec"]'))kok.insertBefore(oyBolumu,hizli);
   }
   // Belediye yönetimi yalnız Devlet > Makamlarım alanında yer alsın.
   var silindi=0;
   kok.querySelectorAll(".liste-satir,.giris-satir,.yapilacak").forEach(function(el){
     if(/Belediyesini yönet|Belediyeyi yönet/.test(el.textContent||"")){el.remove();silindi++;}
   });
   kok.querySelectorAll(".olay").forEach(function(el){
     if(Array.from(el.querySelectorAll("button")).some(function(b){return /Belediyeyi yönet/.test(b.textContent||"");})){el.remove();silindi++;}
   });
   if(silindi){
     kok.querySelectorAll(".bolum-bas").forEach(function(b){
       if((b.querySelector("h2")||{}).textContent==="Bugün"){
         var say=b.querySelector(".kucuk");
         if(say&&/^\d+\s+iş$/.test(say.textContent.trim())){
           say.textContent=Math.max(0,Number(say.textContent.match(/\d+/)[0])-1)+" iş";
         }
       }
     });
   }
   // Takvimin eski uzun kartlarını Gündem'den çıkar: kısayol artık ayrı ekran açar.
   // Mevcut seçim düğmeleri ve yetkiler aynen kullanılır; sunucu verisine dokunulmaz.
   var takvim=typeof D!=="undefined"&&D.durum&&Array.isArray(D.durum.takvim)?D.durum.takvim:[];
   var devam=document.createElement("div"),sonuclar=document.createElement("div"),gelecek=document.createElement("div");
   var sahneSaat=kok.querySelector(".sahne .geri-sayim[data-an]");
   if(sahneSaat){
     var hedefAn=Number(sahneSaat.getAttribute("data-an"));
     if(Number.isFinite(hedefAn)&&hedefAn-Date.now()>72*3600000){
       var sahneKart=sahneSaat.closest(".sahne");
       if(sahneKart)gelecek.appendChild(sahneKart);
     }
   }
   var eklenen=new Set();
   Array.from(kok.querySelectorAll('[id^="sec"]')).forEach(function(el){
     if(!/^sec\d+$/.test(el.id)||el.closest(".so-canli-oylama"))return;
     var id=Number(el.id.slice(3));
     var kayit=takvim.find(function(s){return Number(s.id)===id;});
     if(!kayit)return;
     eklenen.add(id);
     if(kayit.asama==="bitti")sonuclar.appendChild(el);
     else devam.appendChild(el);
   });
   // 36 saatlik ana sayfa sınırını aşmış geçmiş sonuçlar da kendi ekranında kalır.
   takvim.filter(function(s){return s.asama==="bitti"&&!eklenen.has(Number(s.id));})
     .sort(function(x,y){return Date.parse(y.sonuc_at||y.oy_bit)-Date.parse(x.sonuc_at||x.oy_bit);})
     .slice(0,30).forEach(function(s){
       if(typeof olayKarti!=="function")return;
       var kart=document.createElement("div");
       kart.id="sec"+Number(s.id);kart.innerHTML=olayKarti(s);
       if(kart.firstElementChild)sonuclar.appendChild(kart);
     });
   var takvimBas=null;
   Array.from(kok.querySelectorAll(".bolum-bas")).some(function(el){
     if(/^\s*Seçim takvimi\s*$/i.test((el.querySelector("h2")||{}).textContent||"")){takvimBas=el;return true;}
     return false;
   });
   if(takvimBas){
     var siradaki=takvimBas.nextElementSibling;
     if(siradaki&&siradaki.classList.contains("kart"))gelecek.appendChild(siradaki);
     takvimBas.remove();
   }
   // Oylama açıkken Gündem'in en üstündeki sandıklar korunur; takvimde de erişilir.
   var acik=kok.querySelector(".secim-ust"),canli=kok.querySelector(".so-canli-oylama");
   var bolum=function(bas,kutu){
     return kutu.children.length?'<div class="bolum-bas"><h2>'+bas+'</h2></div>'+kutu.innerHTML:"";
   };
   soTakvimSayfaHtml=(acik?acik.outerHTML:canli?canli.outerHTML:"")
     +bolum("Başvurular ve devam eden seçimler",devam)
     +bolum("Yaklaşan seçim takvimi",gelecek)
     +bolum("Sonuçlanan seçimler",sonuclar);
   if(!soTakvimSayfaHtml)soTakvimSayfaHtml='<div class="kart"><div class="bos">Şu an takvimde seçim veya sonuç bulunmuyor.</div></div>';
   // Gündem'deki başvuru/fırsat bağlantıları artık aşağı kaydırmak yerine bu ekranı açar.
   Array.from(kok.querySelectorAll("[onclick]")).forEach(function(el){
     var hedef=el.getAttribute("onclick")||"";
     if(hedef.indexOf("scrollIntoView")!==-1&&(hedef.indexOf("getElementById('sec")!==-1||hedef.indexOf("id^=sec")!==-1))
       el.setAttribute("onclick","soGundemTakvimAc()");
   });
   var secimBas=Array.from(kok.querySelectorAll(".bolum-bas")).find(function(el){
     return /^\s*Seçimler ve oylamalar\s*$/i.test((el.querySelector("h2")||{}).textContent||"");
   });
   if(secimBas&&(!secimBas.nextElementSibling||secimBas.nextElementSibling.classList.contains("bolum-bas")))secimBas.remove();
   return kok.innerHTML;
 }
 function makamDetay(tur){
   if(tur==="bel")return ["🏙️","Belediye bütçesi, binalar, vergiler ve hizmetler"];
   if(tur==="cb")return ["🇹🇷","Hükümet, kabine, politika ve devlet kararları"];
   if(tur==="cb_yardimcisi")return ["🏛️","Cumhurbaşkanlığı ve hükümet işleri"];
   if(tur==="bakan")return ["📋","Bakanlık politikaları, icraatlar ve ihaleler"];
   if(tur==="tbmm"||tur==="bskv"||tur==="grup_bskv")return ["⚖️","Meclis yönetimi, teklifler ve oylamalar"];
   if(tur==="mv")return ["🗳️","Kanun teklifleri, oylamalar ve soru önergeleri"];
   return ["🏅","Makam işlemlerini aç"];
 }
 function devletYenile(html){
   var p=profil();if(!p)return html;
   var makamlar=Array.isArray(p.makamlar)?p.makamlar.slice():[];
   var rol=makamlar.map(function(m){
     var tur=String(m.tur||"");var ac=makamDetay(tur),label="";
     try{label=typeof makamYaz==="function"?makamYaz(m):"";}catch(_){}
     if(!label)label=m.il_ad&&tur==="bel"?m.il_ad+" Belediye Başkanı":tur;
     return {tur:tur,label:label,ikon:ac[0],desc:ac[1]};
   }).filter(function(m){return m.tur;});
   if(p.parti&&(p.gb||p.gb_vekaleten||p.gby)){
     rol.push({tur:"parti",label:p.gb?"Genel Başkan":p.gb_vekaleten?"Genel Başkan (vekâleten)":"Genel Başkan Yardımcısı",ikon:"🏳️",desc:"Parti teşkilatı, adaylar, ittifaklar ve parti kasası"});
   }
   var kok=document.createElement("div");kok.innerHTML=html;
   if(!rol.length)return html;
   var eski=kok.querySelector(".ynt-makamlar"), kart=eski&&eski.closest(".kart");
   if(!kart){
     Array.from(kok.querySelectorAll(".kart")).some(function(el){
       var h=el.querySelector("h2");if(h&&/^\s*Makamların\s*$/.test(h.textContent||"")){kart=el;return true;}
       return false;
     });
   }
   var grid=document.createElement("div");grid.className="so-makam-secim";
   grid.innerHTML=rol.map(function(r){
     return '<button type="button" class="so-makam-btn" onclick="soMakamGit(\''+temiz(r.tur)+'\')">'+
       '<span class="so-makam-emoji">'+r.ikon+'</span><span class="so-makam-icerik"><b>'+temiz(r.label)+'</b><small>'+temiz(r.desc)+'</small></span><span class="so-makam-ok">›</span></button>';
   }).join("");
   if(kart){
     kart.classList.add("so-makam-kart");
     var h=kart.querySelector("h2");
     if(h)h.textContent="🎖️ Makamlarım";
     var acik=kart.querySelector(".alt");
     if(acik)acik.textContent="Bir makama dokunarak yetkili olduğun işlem ekranını aç.";
     if(eski)eski.replaceWith(grid);
     else kart.appendChild(grid);
   }else{
     // Devlet'in diğer sekmelerinde makamlar sayfasına tek tuşla dön.
     var oner=document.createElement("div");oner.className="so-makam-hizli";
     oner.innerHTML='<button type="button" onclick="soMakamimAc()">🎖️ Makamlarım · '+rol.length+' görev →</button>';
     var tabs=kok.querySelector(".segment");
     if(tabs)tabs.insertAdjacentElement("afterend",oner);
     else kok.insertBefore(oner,kok.firstChild);
   }
   return kok.innerHTML;
 }
 window.iskelet=function(baslik,govde,opt){
   if(typeof govde==="string"){
     try{
       if(baslik==="Gündem")govde=gundemYenile(govde);
       else if(baslik==="Devlet"||baslik==="Yönetim")govde=devletYenile(govde);
     }catch(err){if(window.console&&console.warn)console.warn("Gündem/Makam kısayolları:",err);}
   }
   var sonuc=kaynakIskelet.call(this,baslik,govde,opt);
   if(baslik==="Gündem"){
     soGundemKaliciGozlemci();
     soGundemSiralamayiBagla();
   }
   return sonuc;
 };
 stiller();
 soGundemKaliciGozlemci();
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
