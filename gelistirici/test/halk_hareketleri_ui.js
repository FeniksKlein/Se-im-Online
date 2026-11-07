// npm install --no-save jsdom@26.1.0
const {JSDOM}=require('jsdom'),fs=require('fs'),assert=require('node:assert/strict');
const dom=new JSDOM('<main id="app"></main>',{runScripts:'outside-only'}),w=dom.window,calls=[];
w.e=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
w.yukleniyor=()=>{};w.toast=()=>{};w.hataCevir=s=>s;w.ekranAc=fn=>fn();w.iskelet=(t,h)=>w.document.getElementById('app').innerHTML=h;
w.API={rpc:async(fn,args)=>{calls.push({fn,args});if(fn!=='sokak_eylemler')return {tamam:true};return {aktif:true,baslatabilir:true,hukumet:true,iktidar:false,ayar:{baslatma_bedeli:50000},kaynaklar:[{tur:'oyuncu',id:null,ad:'Cüzdan'},{tur:'parti',id:7,ad:'Partim'}],iller:[{id:48,ad:'Muğla',memnuniyetsizlik:40}],eylemler:[{id:9,il:'Muğla',parti:'Parti',gerekce:'<img src=x onerror=alert(1)>',durum:'aktif',seviye:50,katilim:4,muhalefet_fonu:50000,iktidar_fonu:0,destekler:[]}]};}};
w.eval(fs.readFileSync(require('path').join(__dirname,'../www/halk_hareketleri.js'),'utf8'));
const q=s=>w.document.querySelector(s),flush=()=>new Promise(r=>setImmediate(r));
(async()=>{
 await w.sokakHareketleriEkrani();assert.equal(q('img'),null);
 q('[data-hh-katil]').click();await flush();assert.equal(calls.find(x=>x.fn==='sokak_destek').args.p_eylem,9);
 q('.hhFon [name=kaynak]').value='1';q('.hhFon [name=tutar]').value='10000';q('.hhFon').dispatchEvent(new w.Event('submit',{cancelable:true}));await flush();
 assert.deepEqual(JSON.parse(JSON.stringify(calls.filter(x=>x.fn==='sokak_destek').at(-1).args)),{p_eylem:9,p_taraf:'muhalefet',p_kaynak:'parti',p_kaynak_id:7,p_tutar:10000});
 q('#hhYeni textarea').value='Belediye hizmetlerinde iyileştirme talebimiz';q('#hhYeni').dispatchEvent(new w.Event('submit',{cancelable:true}));await flush();assert.equal(calls.find(x=>x.fn==='sokak_eylem_baslat').args.p_il,48);
 q('.hhYanit textarea').value='Taleplere karşı somut çözüm paketi hazırlıyoruz.';q('.hhYanit').dispatchEvent(new w.Event('submit',{cancelable:true}));await flush();assert.equal(calls.find(x=>x.fn==='sokak_yanit').args.p_eylem,9);
 console.log('PASS: DOM render, XSS escaping, participation, funding, creation, government response');dom.window.close();
})().catch(e=>{console.error(e);process.exit(1)});
