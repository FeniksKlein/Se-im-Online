// www/index.html + veri.js → dist/index.html (tek dosya)
const fs=require('fs'), path=require('path');
const kok=path.join(__dirname,'..');
let html=fs.readFileSync(path.join(kok,'www/index.html'),'utf8');
const veri=fs.readFileSync(path.join(kok,'www/veri.js'),'utf8');
html=html.replace('<script src="veri.js"></script>',()=>'<script>'+veri+'</script>');
fs.mkdirSync(path.join(kok,'dist'),{recursive:true});
fs.writeFileSync(path.join(kok,'dist/index.html'),html);
console.log('dist/index.html', (html.length/1024).toFixed(0)+' KB');
