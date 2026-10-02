// Mevcut oyundan harita ve amblem verisini çıkarır → veri.js
const fs=require('fs');
const src=fs.readFileSync('/home/claude/online/src/game-core.js','utf8');
function al(ad){
  const i=src.indexOf('const '+ad+'=');
  let j=src.indexOf('=',i)+1, d=0, k=j, str=null;
  for(;k<src.length;k++){
    const c=src[k];
    if(str){ if(c==='\\'){k++;continue;} if(c===str) str=null; continue; }
    if(c==='"'||c==="'"||c==='`'){str=c;continue;}
    if(c==='['||c==='{') d++;
    if(c===']'||c==='}'){ d--; if(d===0){k++;break;} }
  }
  return eval('('+src.slice(j,k)+')');
}
const ILDATA=al('ILDATA'), TR=al('TR_HARITA'), AMB=al('AMBLEMLER');
// oyunun il sırası → ad; bizim id = plaka. Ad eşlemesiyle plakaya çevir
const plakalar=fs.readFileSync('../sql/iller.sql','utf8').match(/\((\d+),'([^']+)',(\d+)\)/g).map(s=>{const m=s.match(/\((\d+),'([^']+)',(\d+)\)/);return {id:+m[1],ad:m[2],mv:+m[3]};});
const norm=s=>s.toLocaleLowerCase('tr').replace(/[^a-zçğıöşü]/g,'');
const harita={w:TR.w,h:TR.h,il:{}};
ILDATA.forEach((d,i)=>{
  const p=plakalar.find(x=>norm(x.ad)===norm(d[0]));
  if(!p) throw new Error('eşleşmedi: '+d[0]);
  harita.il[p.id]={d:TR.paths[i],x:Math.round(TR.cx[i]),y:Math.round(TR.cy[i])};
});
if(Object.keys(harita.il).length!==81) throw new Error('81 değil');
const amblem=AMB.map(a=>({id:a.id,ad:a.ad,svg:a.svg}));
// Oyundaki ay-yıldızın hilal yolu sıfır alanlı (görünmüyor) — düzgün bir hilalle değiştir
amblem[0].svg=amblem[0].svg.replace('M11 3a9 9 0 1 0 0 18 7.2 7.2 0 1 1 0-18z','M15.5 4.2A8.5 8.5 0 1 0 15.5 19.8A8 8 0 0 1 15.5 4.2Z');
const out='window.VERI='+JSON.stringify({harita,amblem,iller:plakalar})+';\n';
fs.writeFileSync('../www/veri.js',out);
console.log('veri.js',(out.length/1024).toFixed(0)+'KB', Object.keys(TR), amblem.length+' amblem');
