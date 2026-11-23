// Genel Kurul söz şeridi arayüz testi (sahte RPC, 390 px). Önce: node gelistirici/build/derle.js
// Çalıştır: NODE_PATH=/opt/npm-tools/node_modules node gelistirici/test/meclis_soz_arayuz.js [klasör]
const fs=require('fs'),path=require('path');const {chromium}=require('playwright');const KL=process.argv[2]||'/tmp/msz';fs.mkdirSync(KL,{recursive:true});
const html0=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
const simdi=new Date().toISOString(),dk=n=>new Date(Date.now()+n*60000).toISOString();
const turler=[{kod:'kisisel',ad:'Şahsı adına',sinir:800},{kod:'grup',ad:'Grup adına',sinir:1500},{kod:'yerinden',ad:'Yerinden kısa söz',sinir:250}];
const D={bos:{zaman:simdi,yazabilir:true,serbest:false,baskanlik:false,baskanlik_cevrimici:true,turler,soz:null,bekleyen:null,sira:null,sira_sayi:2},
 bekle:{zaman:simdi,yazabilir:true,baskanlik:false,baskanlik_cevrimici:true,turler,soz:null,bekleyen:{id:1,tur:'kisisel',ad:'Şahsı adına',istek:simdi,otomatik:dk(5),sira:3},sira_sayi:3},
 soz:{zaman:simdi,yazabilir:true,baskanlik:false,baskanlik_cevrimici:true,turler,soz:{id:1,tur:'kisisel',ad:'Şahsı adına',sinir:800,bitis:dk(15)},bekleyen:null,sira_sayi:0},
 baskan:{zaman:simdi,yazabilir:true,baskanlik:true,baskanlik_sinir:600,baskanlik_cevrimici:true,turler,soz:null,bekleyen:null,sira_sayi:2,sira:[{id:5,kad:'vekilAhmet',parti:'HP',tur:'kisisel',ad:'Şahsı adına',istek:simdi,otomatik:dk(5)},{id:6,kad:'grupBaskanvekili',parti:'MP',tur:'grup',ad:'Grup adına',istek:simdi,otomatik:dk(4)}]}};
const KOPRU=`<script>window.__D=${JSON.stringify(D)};window.__mod='bos';window.API_TEST={async rpc(fn,a){if(fn==='sohbet_oku')return{baslik:'Genel Kurul',mesajlar:[{id:1,kad:'vekilAhmet',metin:'Sayın Başkan, değerli milletvekilleri; bütçe üzerine söz almış bulunuyorum.',zaman:'${simdi}'}],yazabilir:true};if(fn==='meclis_soz_durum')return JSON.parse(JSON.stringify(__D[__mod]));if(fn==='meclis_soz_iste'){__mod='bekle';return __D.bekle}if(fn==='sohbet_ozet')return{kanallar:[{kanal:'meclis',baslik:'Genel Kurul',yazabilir:true}]};return null},async oturum(){return null}};</script>`;
const html=html0.replace(/<script src="https:[^"]+"><\/script>/g,'').replace('<body>','<body>'+KOPRU);
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2});
 const hatalar=[];p.on('pageerror',e=>hatalar.push(e.message));
 await p.setContent(html,{waitUntil:'load'});await p.waitForTimeout(800);
 await p.evaluate(()=>{API=window.API_TEST;D.durum={simdi:new Date().toISOString(),profil:{kad:'vekilBen',il_id:34,yetkiler:{liste:[]},cuzdan:{para:1}},okunmamis:{bildirim:0,ozel:0}};});
 for(const m of ['bos','bekle','soz','baskan']){
  await p.evaluate(async(mm)=>{window.__mod=mm;await ekranAc(()=>sohbetTasarim.kanal('meclis'));},m);await p.waitForTimeout(1200);
  if(m==='soz')await p.evaluate(()=>{const t=document.querySelector('#yaz');t.value='x'.repeat(820);t.dispatchEvent(new Event('input'));});
  const d=await p.evaluate(()=>({kutu:!!document.querySelector('#mszKutu'),kapali:document.querySelector('#yaz')&&document.querySelector('#yaz').disabled,say:(document.querySelector('#mszSay')||{}).textContent,
    tas:[...document.querySelectorAll('#mszKutu *')].filter(x=>x.getBoundingClientRect().right>document.documentElement.clientWidth+1).length}));
  console.log(m,JSON.stringify(d));await p.screenshot({path:KL+'/'+m+'.png'});}
 console.log('HATALAR',hatalar.slice(0,5));await b.close();})();
