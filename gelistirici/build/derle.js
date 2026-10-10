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
for (const m of ['parti_yasam.js','aday_sirket_ek.js','parti_kimlik_ek.js','otomatik_gazete.js'])
  html=html.replace(`<script src="${m}"></script>`,()=>'<script>'+fs.readFileSync(path.join(kok,'www',m),'utf8')+'</script>');
// Yazı tipi: yazi/ klasöründeki WOFF dosyaları base64 olarak gömülür (internetsiz çalışır)
const yazi=(dosya,kalinlik)=>`@font-face{font-family:"Kurul Display";font-style:normal;font-weight:${kalinlik};font-display:swap;src:url(data:font/woff;base64,${fs.readFileSync(path.join(kok,'www/yazi',dosya)).toString('base64')}) format("woff")}`;
html=html.replace('/*YAZITIPI*/',()=>yazi('kurul-regular.woff',400)+yazi('kurul-bold.woff',700));
for (const m of ['arayuz.js','sivil_toplum.js','kurucu_ideoloji.js','ekonomi_vitrin.js','emlak_vitrin.js'])
  html=html.replace(`<script src="${m}"></script>`,()=>'<script>'+fs.readFileSync(path.join(kok,'www',m),'utf8')+'</script>');
const surum=fs.readFileSync(path.join(kok,'SURUM'),'utf8').trim();
html=html.replace('"__SURUM__"', JSON.stringify(surum));
fs.mkdirSync(path.join(kok,'dist'),{recursive:true});
fs.writeFileSync(path.join(kok,'dist/index.html'),html);
console.log('dist/index.html', (html.length/1024).toFixed(0)+' KB', 'sürüm '+surum);
