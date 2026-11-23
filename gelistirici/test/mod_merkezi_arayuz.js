// Moderasyon Merkezi arayüz testi (sahte RPC, 390 px). Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/mod_merkezi_arayuz.js [ekran-klasörü]
const fs=require('fs'),path=require('path');const {chromium}=require('playwright');fs.mkdirSync(process.argv[2]||'/tmp/mm_ekran',{recursive:true});
const html0=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
const simdi=new Date().toISOString(), dk=(n)=>new Date(Date.now()-n*60000).toISOString();
const birimler=[["kayit","Kayıt ve Kimlik Masası","#5b8def","kimlik"],["sohbet","Sohbet ve Küfür Denetimi","#e0a43a","sohbet"],["sikayet","Şikâyet ve Destek Masası","#c86cd8","sikayet"],["masak","MASAK · Finans Denetimi","#3fb67a","masak"],["secim","Seçim Güvenliği ve Çoklu Hesap","#4fc1d6","sandik"],["yaptirim","Yaptırım Kurulu","#e5574f","terazi"],["topluluk","Topluluk ve Duyuru","#f07f3c","megafon"]].map(([kod,ad,renk,ikon],i)=>({kod,ad,renk,ikon,hedef:2,aciklama:"Bu birim ilgili işleri yürütür ve kuyruğu temiz tutar.",yetkiler:["kayit","oyuncu_ara"].concat(kod==="sohbet"?["sikayet","sustur"]:kod==="yaptirim"?["hesap_kapat","sustur"]:[]),uyeler:i<5?[{kad:["halilmutlu","TuranRiver","mustafaozdm","yavuz02","CELAL"][i],rutbe:i==0?"sorumlu":"moderator",cevrimici:i%2==0,son_gorulme:dk(30)}]:[]}));
const mods=["halilmutlu","TuranRiver","mustafaozdm","yavuz02","CELAL","uygarzk","mehmetemincelik"].map((k,i)=>({kad:k,ad_soyad:"Ad Soyad",birim:i<5?birimler[i].kod:"genel",birim_gecerli:i<5,rutbe:i==0?"sorumlu":"moderator",yetkiler:["kayit","oyuncu_ara"],ek:i>4?["para","makam"]:[],kritik:i>4?["makam","para"]:[],cevrimici:i%2==0,son_gorulme:dk(40),islem_1g:i,islem_7g:20-i*2,islem_30g:60-i,kayit_7g:5,son_islem:dk(10)}));
const R={
 durum:{simdi,profil:{kad:"ArvenTora",yonetici:true,il_id:34,yetkiler:{yonetici:true,moderator:false,liste:[]},cuzdan:{para:1e8}},okunmamis:{bildirim:0,ozel:0}},
 mod_merkez:{zaman:simdi,ben:{kad:"ArvenTora",yonetici:true,yetkiler:["kayit","sikayet","sustur","hesap_kapat","oyuncu_ara","ekonomi","coklu_hesap","duyuru","destek","para","makam"],rutbe:"moderator"},birimler,
  kuyruk:{kayit:{sayi:3,en_eski:dk(45)},sikayet:{sayi:2,en_eski:dk(30)},sohbet:{sayi:41,isaretli:3},masak:{sayi:102,en_eski:dk(50000)},destek:{sayi:1,en_eski:dk(20)},talep:{sayi:1,en_eski:dk(10)},taleplerim:{sayi:0},coklu:{sayi:1}},
  istatistik:{bugun:4,hafta:32,sira:1,ekip:7,cevrimici:2,ekip_hafta:48},son_islemlerim:[{islem:"kayit_onay",hedef:"yeniOyuncu",zaman:dk(5)},{islem:"yk_sustur",hedef:"gürültücü",zaman:dk(50)}],kritik_uyari:2},
 admin_kayit_basvurulari:[{user_id:"u1",kad:"tayyip_34",ad_soyad:"Recep Tayyip Erdoğan",il:"İstanbul",olusturma:dk(90),basvuru_at:dk(45),durum:"beklemede",red_sayisi:1,uyari:"Recep Tayyip Erdoğan (Cumhurbaşkanı)",onceki_red:[{ad_soyad:"Tayyip Erdoğan",neden:"Gerçek siyasetçi adı kullanılamaz.",veren:"halilmutlu",zaman:dk(100)}]},{user_id:"u2",kad:"ahmet_y",ad_soyad:"Ahmet Yılmaz",il:"Ankara",olusturma:dk(30),basvuru_at:dk(20),durum:"beklemede",red_sayisi:0},{user_id:"u3",kad:"zeynep",ad_soyad:"Zeynep Kaya",il:"İzmir",olusturma:dk(30),basvuru_at:dk(10),durum:"onaylandi",karar_veren:"CELAL",karar_at:dk(5)}],
 mod_ustlenmeler:{},mod_ustlen:{tamam:true},
 admin_sikayetler:[{tur:"mesaj",kayit_id:5,hedef:"gürültücü",sayi:3,nedenler:["hakaret","spam"],ilk:dk(300),icerik:"Sen ne anlarsın siyasetten, otur oturduğun yerde!",gizli:false,hedef_sikayet_toplam:7}],
 mod_sohbet_nobeti:{kanallar:[{kanal:"il:34",ad:"İstanbul sohbeti",sayi:12}],mesajlar:[{id:1,kanal:"genel",kanal_ad:"Genel",kad:"gürültücü",metin:"HESAP VERİN HALKA HESAP VERİN",zaman:dk(3),gizli:false,isaret:["buyuk_harf","tekrar"],sikayet:1},{id:2,kanal:"meclis",kanal_ad:"Meclis",kad:"vekil1",metin:"Yüce Meclisi saygıyla selamlıyorum.",zaman:dk(8),gizli:false,isaret:[]},{id:3,kanal:"il:34",kanal_ad:"İstanbul sohbeti",kad:"spamci",metin:"bedava para t.me/xyz 0532 111 22 33",zaman:dk(12),gizli:true,isaret:["baglanti","telefon"]}]},
 mod_dosya:{id:"x",kad:"gürültücü",ad_soyad:"Mehmet Demir",il:"İstanbul",parti:{ad:"Halkın Partisi",kisa:"HP",renk:"#e5574f",gb:false},unvan:"Vatandaş",makamlar:[],para:125000,kidem:340,olusturma:dk(9000),son_gorulme:dk(4),cevrimici:true,susturma_bitis:new Date(Date.now()+3600e3).toISOString(),yasakli:false,korunan:false,onayli:false,
   sikayet_ozet:{toplam:7,acik:2,kisi:4},sikayet_ettigi:1,notlar:[{yazan:"halilmutlu",metin:"Genel sohbette iki kez uyarıldı.",zaman:dk(200)}],gecmis:[{kad:"halilmutlu",islem:"yk_sustur",ayrinti:"6 saat · hakaret",zaman:dk(60)}],mesajlar:[{kanal:"genel",metin:"HESAP VERİN",zaman:dk(3),gizli:false}],bagli:[{kad:"gurultucu2",yasakli:true,olusturma:dk(5000)}],masak:[],talepler:[{tur:"engel",sure:3,gerekce:"Tekrarlanan hakaret",durum:"acik",talep_eden:"TuranRiver",zaman:dk(10)}],
   yetkim:{sustur:true,hesap_kapat:true,yonetici:true}},
 mod_talepler:{karar:[{id:1,tur:"engel",hedef:"gürültücü",sure:3,gerekce:"Genel sohbette tekrarlanan hakaret ve küfür.",kanit:"Genel · 18.11 10:01: ...",talep_eden:"TuranRiver",zaman:dk(10),durum:"acik",hedef_durum:{sikayet:7,onceki_yaptirim:1}}],benim:[],diger_acik:[],son_kararlar:[]},
 mod_destek:[{id:12,kad:"yeniOyuncu",kategori:"hata",metin:"Seçim ekranında oy veremiyorum, buton gri kalıyor.",zaman:dk(20),durum:"yeni",platform:"ios",surum:"2026.11.17-8",onceki:0}],
 admin_mod_ekip:{birimler,yetkiler:[["ozet","Özet"],["sikayet","Şikâyetler"],["sustur","Susturma"],["hesap_kapat","Engelleme"],["oyuncu_ara","Oyuncu inceleme"],["eposta","E-posta görme",1],["duyuru","Duyuru"],["coklu_hesap","Çoklu hesap"],["kurallar","Kurallar",1],["ekonomi","MASAK"],["para","Para ve kıdem",1],["makam","Görev verme",1],["kayit","Kayıt onayı",0,1],["destek","Destek"]].map(([kod,ad,k,t])=>({kod,ad,aciklama:"Açıklama metni burada yer alır.",kritik:!!k,temel:!!t})),moderatorler:mods},
 mod_gunluk:[{id:5,kad:"halilmutlu",islem:"kayit_onay",hedef:"ahmet",ayrinti:"Ahmet Yılmaz",zaman:dk(5)}],
 mod_tv_liste:{programlar:[{id:60,baslik:"KAMARBEY VURDURUYOR 🏳️‍🌈👌🏻",durum:"canli",tur:"haber",bas:dk(30),izleyici:10,kanal_id:12,kanal:"Türk Tv",sunucu:"karahanlı",sahip:"İskender"},{id:61,baslik:"Akşam Bülteni",durum:"planli",tur:"haber",bas:dk(-60),izleyici:0,kanal_id:9,kanal:"Kanaltürk Tv",sunucu:"MusaOzkan",sahip:"mücahiterbakan"}],kanallar:[{id:12,ad:"Türk Tv",slogan:"Tek yürek Tek Millet",sahip:"İskender",canli:1,planli:0},{id:9,ad:"Kanaltürk Tv",slogan:"Türkiyenin Kanalı KanalTürk",sahip:"mücahiterbakan",canli:0,planli:1}],kapali:[{id:4,ad:"Haber Odası",sahip:"eskiOyuncu",zaman:dk(100),gerekce:"Bölücü içerikli yayınlar.",kapatan:"Oyun Kurucusu"}]},
 yk_oyuncular:{toplam:1,liste:[{kad:"gürültücü",il:"İstanbul",parti:{kisa:"HP"},son_gorulme:dk(3),susturma_bitis:simdi}]}
};
const KOPRU=`<script>window.__R=${JSON.stringify(R)};window.API_TEST={async rpc(fn,a){window.__son=(window.__son||[]);window.__son.push([fn,a]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return null},async kayit(){},async giris(){},async cikis(){}};</script>`;
const html=html0.replace(/<script src="https:[^"]+"><\/script>/g,'').replace('<body>','<body>'+KOPRU).replace('API = window.API_TEST || gercekApi();','API = window.API_TEST;');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});
 const hatalar=[];p.on('pageerror',e=>hatalar.push(e.message));p.on('console',m=>{if(m.type()==='error')hatalar.push('console:'+m.text())});
 await p.setContent(html,{waitUntil:'load'});await p.waitForTimeout(800);
 await p.evaluate(()=>{API=window.API_TEST;D.durum=__R.durum;});
 const ekran=async(ad,fn)=>{await p.evaluate(()=>{if(window.SO_KESINTISIZ){SO_KESINTISIZ.eylem=Date.now();SO_KESINTISIZ.dokunus=0;}});await p.evaluate(fn);await p.waitForTimeout(900);if(hatalar.length)console.log('  hata:',hatalar.splice(0));
   const tas=await p.evaluate(()=>{const w=document.documentElement.clientWidth;return [...document.querySelectorAll('#icerik *,.modal *')].filter(x=>x.getBoundingClientRect().right>w+1).slice(0,3).map(x=>x.className+'|'+x.tagName)});
   await p.screenshot({path:(process.argv[2]||'/tmp/mm_ekran')+`/${ad}.png`,fullPage:false});console.log(ad,'taşma:',JSON.stringify(tas));};
 await ekran('1_pano',()=>yoneticiEkrani());
 await p.evaluate(()=>document.getElementById('icerik').scrollTo(0,600));await p.waitForTimeout(200);await p.screenshot({path:''+(process.argv[2]||'/tmp/mm_ekran')+'/1b_pano.png'});
 await ekran('2_kayit',()=>ekranAc(mmKayit));
 await ekran('2b_ret',()=>document.getElementById('mmRed').click());
 await p.evaluate(()=>modalKapat());
 await ekran('3_sikayet',()=>ekranAc(mmSikayet));
 await ekran('4_nobet',()=>ekranAc(mmNobet));
 await ekran('4b_islem',()=>document.querySelector('.mm-mesaj').click());
 await p.evaluate(()=>modalKapat());
 await ekran('5_dosya',()=>mmDosyaAc('gürültücü'));
 await ekran('5b_engel',()=>document.querySelector('[data-a="engel"]').click());
 await p.evaluate(()=>modalKapat());
 await ekran('6_talep',()=>ekranAc(mmTalepler));
 await ekran('7_destek',()=>ekranAc(mmDestek));
 await ekran('8_ekip',()=>ekranAc(mmEkip));
 await ekran('8b_duzenle',()=>document.querySelector('[data-m]').click());
 await p.evaluate(()=>modalKapat());
 await ekran('9_gunluk',()=>ekranAc(mmGunluk));
 await ekran('10_duyuru',()=>ekranAc(mmDuyuru));
 await ekran('11_tv',()=>ekranAc(mmTv));
 await ekran('11b_kes',()=>document.querySelector('[data-kes]').click());
 await p.evaluate(()=>modalKapat());
 await ekran('11c_kapat',()=>document.querySelector('[data-kkapat]').click());
 await p.evaluate(()=>modalKapat());
 console.log('HATALAR',hatalar.slice(0,5));await b.close();})();
