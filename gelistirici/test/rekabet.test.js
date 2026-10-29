const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const source=fs.readFileSync(path.join(__dirname,'../www/rekabet.js'),'utf8');
(async()=>{
 let html='', buttons=[], refresh=null, loading=false;
 const fixture={zaman:new Date().toISOString(),oyuncu:[{ad:'<img onerror=alert(1)>',deger:123456}],sirket:[{ad:'Şirket A',deger:5000}],kar:[],satis:[],takipci:[],mulk:[]};
 const ctx={console,Date,Number,API:{rpc:async()=>fixture},document:{head:{appendChild(){}},createElement:()=>({}),getElementById:id=>id==='rp-loading'?(loading?{}:null):refresh,querySelectorAll:()=>buttons},iskelet:(title,s)=>{html=s;loading=s.includes('id="rp-loading"');buttons=[...s.matchAll(/data-rp="([^"]+)"/g)].map(m=>({dataset:{rp:m[1]}}));refresh={};}};
 ctx.window=ctx;vm.createContext(ctx);vm.runInContext(source,ctx);
 await ctx.rekabetEkrani();assert.equal(buttons.length,6);assert(html.includes('&lt;img onerror=alert(1)&gt;'));assert(!html.includes('<img onerror'));assert(html.includes('123.456'));
 buttons.find(b=>b.dataset.rp==='sirket').onclick();assert(html.includes('Şirket A'));
 buttons.find(b=>b.dataset.rp==='kar').onclick();assert(html.includes('henüz kayıt yok'));
 ctx.API.rpc=async()=>{throw new Error('<script>bad</script>')};await ctx.rekabetEkrani();assert(html.includes('Tekrar dene'));assert(!html.includes('<script>bad'));
 let finish;ctx.API.rpc=()=>new Promise(r=>finish=r);const pending=ctx.rekabetEkrani();ctx.iskelet('Diğer ekran','başka sayfa');finish(fixture);await pending;assert.equal(html,'başka sayfa');
 const kursu=fs.readFileSync(path.join(__dirname,'../www/kursu.js'),'utf8');
 vm.runInContext(kursu.slice(kursu.indexOf('  function nisan('),kursu.indexOf('  /* ---------- metin:')),ctx);ctx.esc=v=>String(v).replace(/"/g,'&quot;');
 const colors=['İzmir Belediye Başkanı','Ankara Milletvekili','Maliye Bakanı','Cumhurbaşkanı','Cumhurbaşkanı Yardımcısı'].map(u=>ctx.nisan(u).match(/color:([^";]+)/)[1]);assert.equal(new Set(colors).size,5);assert.equal(ctx.nisan(null),'');
 console.log('PASS: six boards, escaping, empty/error states, stale navigation and five distinct office colors');
})().catch(e=>{console.error(e);process.exit(1)});
