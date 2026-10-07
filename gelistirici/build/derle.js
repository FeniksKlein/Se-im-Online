// www/index.html + veri.js → dist/index.html (tek dosya)
const fs=require('fs'), path=require('path');
const kok=path.join(__dirname,'..');
let html=fs.readFileSync(path.join(kok,'www/index.html'),'utf8');
const veri=fs.readFileSync(path.join(kok,'www/veri.js'),'utf8');
html=html.replace('<script src="veri.js"></script>',()=>'<script>'+veri+'</script>');
html=html.replace('<script src="basin.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www/basin.js'),'utf8')+'</script>');
html=html.replace('<script src="siyasi-ekonomi.js"></script>',()=>'<script>'+fs.readFileSync(path.join(kok,'www/siyasi-ekonomi.js'),'utf8')+'</script>');
const surum=fs.readFileSync(path.join(kok,'SURUM'),'utf8').trim();
html=html.replace('"__SURUM__"', JSON.stringify(surum));
fs.mkdirSync(path.join(kok,'dist'),{recursive:true});
fs.writeFileSync(path.join(kok,'dist/index.html'),html);
console.log('dist/index.html', (html.length/1024).toFixed(0)+' KB', 'sürüm '+surum);
