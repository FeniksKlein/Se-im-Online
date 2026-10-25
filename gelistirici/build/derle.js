// www/index.html + veri.js → dist/index.html (tek dosya)
const fs=require('fs'), path=require('path');
const kok=path.join(__dirname,'..');
let html=fs.readFileSync(path.join(kok,'www/index.html'),'utf8');
const veri=fs.readFileSync(path.join(kok,'www/veri.js'),'utf8');
html=html.replace('<script src="veri.js"></script>',()=>'<script>'+veri+'</script>');
html=html.replace('<script src="basin.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www/basin.js'),'utf8')+'</script>');
html=html.replace('<script src="piyasa.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www/piyasa.js'),'utf8')+'</script>');
html=html.replace('<script src="siyasi_hayat.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www/siyasi_hayat.js'),'utf8')+'</script>');
// Ayrı modüller tek dosyaya gömülür (sıra önemli değildir; hepsi global fonksiyon tanımlar)
for (const m of ['parti_yasam.js','parti_isbirligi.js','aday_sirket_ek.js','parti_kimlik_ek.js','otomatik_gazete.js'])
  html=html.replace(`<script src="${m}"></script>`,()=>'<script>'+fs.readFileSync(path.join(kok,'www',m),'utf8')+'</script>');
// Yazı tipi: yazi/ klasöründeki WOFF dosyaları base64 olarak gömülür (internetsiz çalışır)
const yazi=(dosya,kalinlik)=>`@font-face{font-family:"Kurul Display";font-style:normal;font-weight:${kalinlik};font-display:swap;src:url(data:font/woff;base64,${fs.readFileSync(path.join(kok,'www/yazi',dosya)).toString('base64')}) format("woff")}`;
html=html.replace('/*YAZITIPI*/',()=>yazi('kurul-regular.woff',400)+yazi('kurul-bold.woff',700));
for (const m of ['arayuz.js','sivil_toplum.js','kurucu_ideoloji.js','ekonomi_vitrin.js','emlak_vitrin.js','toplum_ek.js','gorevler.js','halka_arz.js','adliye.js','avukatlik.js','baro.js','avukat_zorunlu.js','canli_ek.js','secim_detay_sonuclar.js','cimer_ek.js','ekonomi_pazar.js','is_dunyasi.js','ekonomi_borsa.js','ekonomi_kurumlar.js','ajans.js','guvenlik.js','banka_kredi_icra.js','belediye_sehir.js','yonetim.js','banka_kredi_masasi.js','belediye_ruhsatlar.js','menu_sade.js','ek_isler.js','dernek_faaliyet.js','sirket_operasyon_merkezi.js','sirket_tum_turler.js','ekonomi3.js','oyuncu_arama.js','cb_yrd.js','siyaset_merkezi.js','gorunum_cila.js','yonetici_kontrol.js','mobil_yerel.js','magaza.js','uzaktan_kontrol.js','bildirim_merkezi.js'])
  html=html.replace(`<script src="${m}"></script>`,()=>'<script>'+fs.readFileSync(path.join(kok,'www',m),'utf8')+'</script>');
// Eski kaynak şablonunda cb_yrd.js etiketi bulunmasa da uygulama paketi yeni masayı içersin.
if (!html.includes('cbYrdDosyaAc')) html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','cb_yrd.js'),'utf8')+'</script></body>');
// Yeni ekonomi arayuzunu tek dosyalik iOS/Android paketine gom; internetten ek JS istemesin.
html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','uc_ekonomi_yeni.js'),'utf8')+'</script></body>');
html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','ihale_ilan_panosu.js'),'utf8')+'</script></body>');
// Ortak sermayeli kurulus ve hisse devirleri mobil pakete gomulur.
html=html.replace('<script src="ortak_sirketler.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','ortak_sirketler.js'),'utf8')+'</script>');
// Yeni mulk sigortasi da uygulama paketinde calisir.
html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','sigorta_afet.js'),'utf8')+'</script></body>');
// NPC isletmeleri ve sirket pazari tek dosyalik iOS/Android paketine dahildir.
html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','npc_isletmeler.js'),'utf8')+'</script></body>');
// Bankacılık 2.0 (Mobil Şube, Banka Genel Müdürlüğü, kasa gizliliği) mobil pakete gömülür.
html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','bankacilik.js'),'utf8')+'</script></body>');
html=html.replace('<script src="kamu_20261022.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','kamu_20261022.js'),'utf8')+'</script>');
// Gündem, basın-yayın, kitaplar ve makamlar için kaynakla eşit mobil menü düzeni.
html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','gundem_yayin_makam.js'),'utf8')+'</script></body>');
// Kitap vitrini, en çok satanlar, kitaplığı ve güvenli satın almayı çevrimdışı paket koduna ekle.
html=html.replace('</body>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','kitap_vitrini.js'),'utf8')+'</script></body>');
// Bankacilik ve sirket kârı tercihlerinin web ve mobil paketlerde aynı olması için göm.
html=html.replace('<script src="hesap_duzeltmeleri_20261025.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www','hesap_duzeltmeleri_20261025.js'),'utf8')+'</script>');
const surum=fs.readFileSync(path.join(kok,'SURUM'),'utf8').trim();
html=html.replace('"__SURUM__"', JSON.stringify(surum));
fs.mkdirSync(path.join(kok,'dist'),{recursive:true});
fs.writeFileSync(path.join(kok,'dist/index.html'),html);
console.log('dist/index.html', (html.length/1024).toFixed(0)+' KB', 'sürüm '+surum);
