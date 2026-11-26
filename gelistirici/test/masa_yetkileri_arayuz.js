// Masa yetkileri + Yönetime Yaz arayüz testi (sahte RPC, 390 px): kilit/devir işaretleri, dosya, Tarafsızlık sekmesi. Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/mod_cikar_yon_arayuz.js [ekran-klasörü]
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
 yk_oyuncular:{toplam:1,liste:[{kad:"gürültücü",il:"İstanbul",parti:{kisa:"HP"},son_gorulme:dk(3),susturma_bitis:simdi}]}
};
// 19.11.2026: çıkar çatışması yöne göre — moderatör görünümü (yönetici değil) + yöneticinin Tarafsızlık sekmesi
R.durum.profil.yonetici=false;R.durum.profil.yetkiler={yonetici:false,moderator:true,liste:["kayit","sikayet","sustur","oyuncu_ara"]};
R.mod_merkez.ben.yonetici=false;R.mod_merkez.ben.yetkiler=["kayit","sikayet","sustur","oyuncu_ara","sohbet_tum"];
R.admin_sikayetler=[
 {tur:"mesaj",kayit_id:5,hedef:"partiliArkadas",sayi:3,nedenler:["hakaret"],ilk:dk(40),icerik:"Sen ne anlarsın siyasetten, otur oturduğun yerde!",gizli:false,hedef_sikayet_toplam:7,kilit:true,devir:false},
 {tur:"oyuncu",kayit_id:0,hedef:"digerPartili",sayi:1,nedenler:["spam"],ilk:dk(15),gizli:false,hedef_sikayet_toplam:1,kilit:false,devir:true},
 {tur:"yayin",kayit_id:9,hedef:"partiliIkinci",sayi:2,nedenler:["uygunsuz"],ilk:dk(90),icerik:"Propaganda metni örneği.",gizli:true,hedef_sikayet_toplam:2,kilit:true,devir:true}];
R.mod_talepler.karar=[Object.assign({},R.mod_talepler.karar[0],{tur:"sustur",sure:6,kilit:true,devir:false})];
Object.assign(R.mod_dosya,{lehe_kilit:"Çıkar çatışması: bu oyuncuyla aynı partidesiniz.",cikar_catismasi:null,korunan:false,susturma_bitis:simdi});
R.mod_dosya.yetkim=Object.assign({},R.mod_dosya.yetkim,{yonetici:false,hesap_kapat:false,sustur:true});
R.admin_mod_tarafsizlik={gun:30,baslangic:dk(3000),devir_sayi:2,
 moderatorler:[
  {kad:"yavuz02",kod:"G-04",birim:"icerik",parti:"İTF",ceza_ayni:1,lehe_ayni:0,devir:11,ceza_diger:19,lehe_diger:6,oran_ayni:8,oran_diger:76,isaret:"yumusak"},
  {kad:"halilmutlu",kod:"G-01",birim:"oyuncu",parti:"HP",ceza_ayni:6,lehe_ayni:0,devir:5,ceza_diger:14,lehe_diger:12,oran_ayni:55,oran_diger:54,isaret:null},
  {kad:"CELAL",kod:"G-05",birim:"finans",parti:null,ceza_ayni:0,lehe_ayni:0,devir:0,ceza_diger:3,lehe_diger:9,oran_ayni:null,oran_diger:25,isaret:null},
  {kad:"TuranRiver",kod:"G-02",birim:"oyuncu",parti:"MHP",ceza_ayni:0,lehe_ayni:0,devir:0,ceza_diger:0,lehe_diger:0,oran_ayni:null,oran_diger:null,isaret:null}],
 son:[{zaman:dk(12),kad:"halilmutlu",islem:"sikayet_gizle_sustur1",yon:"ceza",hedef:"partiliArkadas",ayrinti:"Sen ne anlarsın siyasetten"},
      {zaman:dk(55),kad:"yavuz02",islem:"devir",yon:"devir",hedef:"partiliIkinci",ayrinti:"şikâyet yayin:9 · Çıkar çatışması: bu oyuncuyla aynı partidesiniz."}],
 devirler:[{id:1,kaynak:"sikayet",hedef:"partiliIkinci",devreden:"yavuz02",sebep:"Çıkar çatışması: bu oyuncuyla aynı partidesiniz.",zaman:dk(150),yoneticide:true},
           {id:2,kaynak:"masak",hedef:"digerPartili",devreden:"CELAL",sebep:"",zaman:dk(20),yoneticide:false}]};

// 20.11.2026: masa yetkileri + Yönetime Yaz arayüz testi
const kisit={id:7,kod:"mali",ad:"Mali işlem dondurma",hedef:"gürültücü",baslangic:dk(60),bitis:new Date(Date.now()+48*3600e3).toISOString(),veren:"uygarzk",kurucu:false,onaylayan:null,gerekce:"Banka üzerinden şüpheli para döngüsü inceleniyor.",kaynak:"dogrudan",benim:false,iki_imza:false};
const sinir={sustur:{ad:"Susturma",var:false},engel:{ad:"Hesap engeli",var:true,tek:"24 saat",cift:"kalıcı dahil",tek_saat:24},mali:{ad:"Mali işlem dondurma",var:true,tek:"3 gün",cift:"30 gün",tek_saat:72,cift_saat:720},secim:{ad:"Seçim kısıtı",var:false}};
R.mod_merkez.ben.yetkiler=["kayit","ekonomi","mali_dondur","hesap_kapat","oyuncu_ara","ozet","sikayet","sustur"];R.mod_merkez.kuyruk.kutu={sayi:2,en_eski:dk(300)};R.mod_merkez.ben.sozlesme_at=simdi;R.mod_merkez.ben.birim="finans";
Object.assign(R.mod_dosya,{lehe_kilit:null,susturma_bitis:null,kisitlar:[kisit],sinirlar:sinir,ust_makam:true,sandik_acik:false});
R.mod_dosya.yetkim={sustur:true,hesap_kapat:true,mali_dondur:true,secim_kisit:false,yonetici:false};
R.mod_kutu={yonetici:false,masalar:[{kod:"icerik",ad:"İçerik Masası"},{kod:"oyuncu",ad:"Oyuncu Masası"},{kod:"finans",ad:"Finans Masası"}],talepler:[
 {id:31,kad:"yeniOyuncu",konu:"hile",konu_ad:"Para ve hile ihbarı",masa:"finans",masa_ad:"Finans Masası",durum:"yeni",zaman:dk(300),son_hareket:dk(300),hedef:"gürültücü",onceki:1,hedef_sikayet:2,platform:"android",
  mesajlar:[{gorevli:false,yazan:"oyuncu",metin:"Bu oyuncu küçük bir bankayı kullanarak sürekli para döndürüyor, uzun uzun anlatıyorum ki satır kırılsın ve taşma olmasın.",zaman:dk(300)},{gorevli:true,yazan:"uygarzk",metin:"İnceliyoruz.",zaman:dk(100)}]},
 {id:32,kad:"digerOyuncu",konu:"itiraz",konu_ad:"Yaptırıma itiraz",masa:"finans",masa_ad:"Finans Masası",durum:"yeni",zaman:dk(20),son_hareket:dk(20),mesajlar:[{gorevli:false,yazan:"oyuncu",metin:"Hesabım neden donduruldu?",zaman:dk(20)}]}]};
R.mod_kutu_yanitla=R.mod_kutu;R.mod_kutu_devret=R.mod_kutu;
R.admin_akis_sikayetleri=[{id:9,kad:"gürültücü",metin:"Uygunsuz Kürsü paylaşımı örneği.",gizli:false,sayi:3,nedenler:["hakaret","nefret"],ilk:dk(50),kilit:false,devir:false}];R.admin_akis_karar=[];
R.mod_kisitlar={aktif:[kisit,Object.assign({},kisit,{id:8,kod:"engel",ad:"Hesap engeli",onaylayan:"yavuz02",iki_imza:true})],sinirlar:sinir};R.mod_kisit_uygula=R.mod_kisitlar;R.mod_kisit_uzat=R.mod_kisitlar;
R.mod_yetki_tablosu={birimler:[{kod:"icerik",ad:"İçerik Masası",renk:"#e0a43a",yaptirimlar:[{kod:"sustur",ad:"Susturma",tek:"7 gün",cift:"30 gün"},{kod:"engel",ad:"Hesap engeli",tek:"24 saat",cift:"kalıcı dahil"}]},{kod:"finans",ad:"Finans Masası",renk:"#3fb67a",yaptirimlar:[{kod:"engel",ad:"Hesap engeli",tek:"24 saat",cift:"kalıcı dahil"},{kod:"mali",ad:"Mali işlem dondurma",tek:"3 gün",cift:"30 gün"}]}],ben:{birim:"finans",yonetici:false,sinirlar:sinir,son24:{}},kurallar:["Tek imza: masanın alanındaki yaptırımı kısa süreyle anında uygularsın.","İki imza: 24 saati aşan ve kalıcı engel, başka bir görevlinin onayıyla uygulanır; kurucu beklenmez."]};
R.mod_icerik_toplu_gizle={mesaj:4,kursu:2,yayin:0};
R.yonetime_yaz_bilgi={konular:[{kod:"sikayet",ad:"Oyuncu şikâyeti",aciklama:"Küfür, hakaret, taciz, bölücü ya da uygunsuz içerik; bir oyuncunun davranışı."},{kod:"hile",ad:"Para ve hile ihbarı",aciklama:"Banka, şirket, borsa, kredi ya da havale ile haksız kazanç."},{kod:"itiraz",ad:"Yaptırıma itiraz",aciklama:"Susturma, kısıt ya da başka bir yönetim kararına itiraz."}],acik:1,okunmamis:1,
 talepler:[{id:31,konu:"hile",konu_ad:"Para ve hile ihbarı",masa_ad:"Oyun yönetimi",durum:"yanitlandi",okundu:false,zaman:dk(300),hedef:"gürültücü",mesajlar:[{gorevli:false,yazan:"oyuncu",metin:"Bu oyuncu sürekli para döndürüyor.",zaman:dk(300)},{gorevli:true,yazan:"Görevli G-05",metin:"İnceliyoruz, teşekkürler.",zaman:dk(100)}]}]};
R.yonetime_yaz={tamam:true,id:33};R.yonetime_yaz_yanit=R.yonetime_yaz_bilgi;R.yonetime_yaz_okundu={tamam:true};
const KOPRU=`<script>window.__R=${JSON.stringify(R)};window.API_TEST={async rpc(fn,a){window.__son=(window.__son||[]);window.__son.push([fn,a]);if(fn in __R)return JSON.parse(JSON.stringify(__R[fn]));return null},async oturum(){return null},async kayit(){},async giris(){},async cikis(){}};</script>`;
const html=html0.replace(/<script src="https:[^"]+"><\/script>/g,'').replace('<body>','<body>'+KOPRU).replace('API = window.API_TEST || gercekApi();','API = window.API_TEST;');
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});
 const hatalar=[];p.on('pageerror',e=>hatalar.push(e.message));p.on('console',m=>{if(m.type()==='error')hatalar.push('console:'+m.text())});
 await p.setContent(html,{waitUntil:'load'});await p.waitForTimeout(800);
 await p.evaluate(()=>{API=window.API_TEST;D.durum=__R.durum;});
 const ekran=async(ad,fn)=>{await p.evaluate(()=>{if(window.SO_KESINTISIZ){SO_KESINTISIZ.eylem=Date.now();SO_KESINTISIZ.dokunus=0;}});await p.evaluate(fn);await p.waitForTimeout(900);if(hatalar.length)console.log('  hata:',hatalar.splice(0));
   const tas=await p.evaluate(()=>{const w=document.documentElement.clientWidth;return [...document.querySelectorAll('#icerik *,.modal *')].filter(x=>x.getBoundingClientRect().right>w+1).slice(0,3).map(x=>x.className+'|'+x.tagName)});
   await p.screenshot({path:(process.argv[2]||'/tmp/mm_ekran')+`/${ad}.png`,fullPage:false});console.log(ad,'taşma:',JSON.stringify(tas));};

 const say=(fn)=>p.evaluate((f)=>(window.__son||[]).filter(x=>x[0]===f).length,fn);
 await ekran('my1_merkez',()=>ekranAc(modMerkezi));
 const m1=await p.evaluate(()=>({kutu:!!document.querySelector('[data-k="kutu"]'),arac:[...document.querySelectorAll('.mm-arac [data-ac]')].map(b=>b.dataset.ac)}));console.log('merkez',JSON.stringify(m1));
 if(!m1.kutu||!m1.arac.includes('kisit')||!m1.arac.includes('kursu'))throw new Error('merkez: yeni girişler yok');
 await ekran('my2_kutu',()=>ekranAc(mmKutu));
 const k1=await p.evaluate(()=>({kart:document.querySelectorAll('.mm-kart[data-i]').length,vurgu:document.querySelectorAll('.mm-kart.vurgu').length}));console.log('kutu',JSON.stringify(k1));if(k1.kart!==2)throw new Error('talep kutusu');
 await p.evaluate(()=>{const k=document.querySelector('.mm-kart[data-i]');k.querySelector('textarea').value='Teşekkürler, bakıyoruz.';k.querySelector('[data-y="0"]').click()});await p.waitForTimeout(500);
 if(await say('mod_kutu_yanitla')!==1)throw new Error('yanıt gönderilmedi');
 await ekran('my3_devret',()=>document.querySelector('[data-devret]').click());
 await p.evaluate(()=>document.querySelector('.modal [data-m="kurucu"], #modal [data-m="kurucu"]').click());await p.waitForTimeout(500);if(await say('mod_kutu_devret')!==1)throw new Error('devir');
 await ekran('my4_kursu',()=>ekranAc(mmKursu));
 await p.evaluate(()=>document.querySelector('[data-k="gizle"]').click());await p.waitForTimeout(400);if(await say('admin_akis_karar')!==1)throw new Error('kürsü kararı');
 await ekran('my5_dosya',()=>mmDosyaAc('gürültücü'));
 const d1=await p.evaluate(()=>({mali:!!document.querySelector('[data-a="mali"]'),secim:!!document.querySelector('[data-a="secim"]'),toplu:!!document.querySelector('[data-a="toplu"]'),talep:!!document.querySelector('[data-a="talep"]'),uzat:!!document.querySelector('[data-kuzat]'),not:/Üst makam/.test(document.getElementById('icerik').textContent)}));
 console.log('dosya',JSON.stringify(d1));if(!d1.mali||d1.secim||!d1.toplu||!d1.talep||!d1.uzat||!d1.not)throw new Error('dosya: yeni düğmeler');
 await ekran('my6_mali',()=>document.querySelector('[data-a="mali"]').click());
 const s6=await p.evaluate(()=>[...document.querySelectorAll('#mmKS [data-v]')].map(b=>b.dataset.v));console.log('mali süreler',s6.join(','));if(s6.join(',')!=='24,48,72')throw new Error('tek imza süre sınırı');
 await p.evaluate(()=>{document.querySelector('#mmKG').value='Banka üzerinden şüpheli para döngüsü.';document.querySelector('#mmKOk').click()});await p.waitForTimeout(600);if(await say('mod_kisit_uygula')!==1)throw new Error('dondurma çağrısı');
 await ekran('my7_toplu',()=>document.querySelector('[data-a="toplu"]').click());
 await p.evaluate(()=>{document.querySelector('#mmTGG').value='Tekrarlanan spam paylaşımlar.';document.querySelector('#mmTGOk').click()});await p.waitForTimeout(600);if(await say('mod_icerik_toplu_gizle')!==1)throw new Error('toplu gizle');
 await ekran('my8_kisitlar',()=>ekranAc(mmKisitlar));
 const k8=await p.evaluate(()=>({uzat:document.querySelectorAll('[data-kuzat]').length,kaldir:document.querySelectorAll('[data-kkaldir]').length,tablo:/kalıcı dahil/.test(document.getElementById('icerik').textContent)}));console.log('kisitlar',JSON.stringify(k8));if(k8.uzat!==1||k8.kaldir!==1||!k8.tablo)throw new Error('kısıtlar ekranı');
 await ekran('my9_uzat',()=>document.querySelector('[data-kuzat]').click());
 await p.evaluate(()=>document.querySelector('#mmKUOk').click());await p.waitForTimeout(500);if(await say('mod_kisit_uzat')!==1)throw new Error('uzatma');
 if(!/yonetimeYazEkrani==='function'&&ekranAc\(yonetimeYazEkrani\)/.test(html0))throw new Error('Ben ekranında giriş yok');
 await ekran('yy2_yaz',()=>ekranAc(yonetimeYazEkrani));
 await p.evaluate(()=>{const b=document.querySelector('#yyYeni');if(b)b.click()});await p.waitForTimeout(300);
 const y2=await p.evaluate(()=>({konu:document.querySelectorAll('#yyKonular [data-k]').length,talep:document.querySelectorAll('.yy-satir[data-ac]').length,nokta:document.querySelectorAll('.yy-nokta').length}));console.log('yonetime yaz',JSON.stringify(y2));if(y2.konu!==3||y2.talep!==1||y2.nokta!==1)throw new Error('yönetime yaz ekranı');
 await p.evaluate(()=>{document.querySelector('#yyKonular [data-k="hile"]').click();document.querySelector('#yyMetin').value='Şu banka üzerinden sürekli para döndürülüyor, bakar mısınız?';document.querySelector('#yyGonder').click()});await p.waitForTimeout(700);
 if(await say('yonetime_yaz')!==1)throw new Error('talep gönderilmedi');
 const a1=await p.evaluate(()=>(window.__son||[]).filter(x=>x[0]==='yonetime_yaz')[0][1]);console.log('gönderilen',JSON.stringify(a1));if(a1.p_konu!=='hile')throw new Error('konu');
 await p.evaluate(()=>ekranAc(yonetimeYazEkrani));await p.waitForTimeout(600);
 await ekran('yy3_talep',()=>document.querySelector('[data-ac="31"]').click());
 await p.evaluate(()=>{document.querySelector('#yyY').value='Ek bilgi: dün akşam da oldu.';document.querySelector('#yyYGonder').click()});await p.waitForTimeout(500);if(await say('yonetime_yaz_yanit')!==1)throw new Error('oyuncu yanıtı');
 await ekran('yy4_sikayet_kisayol',()=>sikayetModal('oyuncu',null,'gürültücü'));
 await p.evaluate(()=>[...document.querySelectorAll('.modal button, #modal button')].find(b=>/kendi cümlelerimle/.test(b.textContent)).click());await p.waitForTimeout(900);
 const h1=await p.evaluate(()=>(document.querySelector('#yyHedef')||{}).value);console.log('kısayol hedef',h1);if(h1!=='gürültücü')throw new Error('şikâyet kısayolu');
 await p.screenshot({path:(process.argv[2]||'/tmp/mm_ekran')+'/yy5_kisayol.png'});
 console.log('HATALAR',hatalar.slice(0,5));if(hatalar.length)process.exitCode=1;await b.close();})();
