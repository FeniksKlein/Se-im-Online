// node gelistirici/test/sert_ui.js
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const {JSDOM}=require('jsdom');
const kok=path.join(__dirname,'..','..');
const adlar=['Şafak Operasyonu','Elebaşı Gözaltısı','Mali Kuşatma','Kapatma Davası Tehdidi','OHAL','Kara Propaganda','Böl ve Yönet','Kuşatma Çemberi','İhale ve Lisans Kılıcı','Toplu Sanal Gözaltı'];
const karsilar=['Nöbet listesine yazıl','Birlik oyu','Sözcüye oy ver','Elebaşı süresini yarıya indir','Kanıtla çürüt','Dayanışma ziyareti','İhale baskısından çekil','Yabancı destek manşetini yaz'];
const davet=fs.readFileSync(path.join(kok,'docs/halk-org-davet.js'),'utf8');
assert.equal(davet,fs.readFileSync(path.join(kok,'www/halk-org-davet.js'),'utf8'));
for(const s of adlar.concat(karsilar).concat(['sokak_sert_islem','sokak_sert_panel','İçişleri bütçesinden uygula','sert önlem'])) assert.ok(davet.includes(s),s);
for(const dosya of ['gelistirici/www/halk_hareketleri.js','www/halk-hareketleri-v2.js']){
 const src=fs.readFileSync(path.join(kok,dosya),'utf8');
 for(const ad of adlar) assert.ok(src.includes(ad),dosya+' '+ad);
 assert.ok(src.includes('sokak_sert_islem')&&src.includes('sokak_sert_panel'),dosya);
}
const sql=fs.readFileSync(path.join(kok,'supabase/migrations/20261109210000_halk_sert_onlem.sql'),'utf8');
for(const s of ['sokak_sert_yetkili','04.00–06.00','salt_cogunluk','sokak_ohal_aktif','Dayanışma','100000','adliye_dava_ac','sokak_sert_tick','sokak_eylem_ohal_engel']) assert.ok(sql.includes(s),s);
assert.equal(sql.includes('Eylem açılış çapası'),false);
assert.ok(fs.readFileSync(path.join(kok,'docs/HALK_HAREKETLERI.md'),'utf8').includes('On sert önlem'));
assert.ok(fs.readFileSync(path.join(kok,'gelistirici/sql/159_rpc_yuzey.sql'),'utf8').includes('sokak_sert_panel'));

const dom=new JSDOM('<main id="app"></main>',{runScripts:'outside-only'}),w=dom.window,calls=[];
w.e=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
w.yukleniyor=()=>{};w.toast=()=>{};w.hataCevir=s=>s;w.ekranAc=fn=>fn();w.iskelet=(t,h)=>w.document.getElementById('app').innerHTML=h;
const sert={tamam:true,eylemler:[{id:9,yetkili:true,katilimci:true,avukat:true,gazeteci:false,iktidar:false,vekil:false,yargi:false,saat:5,fraksiyon:'direnis',bedeller:{safak:200000,elebasi:150000,mali:250000,kapatma:100000,ohal:300000,propaganda:100000,bol:150000,kusatma:200000,ihale:150000,sanal:400000},onlemler:[],ohal:null}]};
w.API={rpc:async(fn,args)=>{calls.push({fn,args});
 if(fn==='sokak_sert_panel')return sert;
 if(fn==='sokak_tedbir_panel')return {eylemler:[]};
 if(fn==='sokak_uzlasma_panel')return {aktif:true,baslatabilir:false,hukumet:false,iktidar:false,ayar:{baslatma_bedeli:50000},kaynaklar:[],iller:[],eylemler:[{id:9,durum:'aktif',il:'Ankara',parti:'Parti',gerekce:'Talep',seviye:40,katilim:8,muhalefet_fonu:50000,iktidar_fonu:0,destekler:[]}]};
 return {tamam:true};}};
w.eval(fs.readFileSync(path.join(__dirname,'../www/halk_hareketleri.js'),'utf8'));
(async()=>{
 await w.sokakHareketleriEkrani();
 const html=w.document.getElementById('app').innerHTML;
 for(const ad of adlar) assert.ok(html.includes(ad),ad);
 assert.ok(html.includes('Nöbet listesine yazıl')&&html.includes('Birlik oyu')&&html.includes('direniş'));
 w.document.querySelector('.hhSert textarea').value='Şafak operasyonunu bu meydan için uyguluyoruz';
 w.document.querySelector('.hhSert [name=tur]').value='safak';
 w.document.querySelector('.hhSert').dispatchEvent(new w.Event('submit',{cancelable:true}));
 await new Promise(r=>setImmediate(r));
 const ac=calls.find(x=>x.fn==='sokak_sert_islem'&&x.args.p_islem==='ac').args;
 assert.equal(ac.p_eylem,9);
 assert.equal(ac.p_veri.tur,'safak');
 assert.equal(ac.p_veri.gerekce,'Şafak operasyonunu bu meydan için uyguluyoruz');
 w.document.querySelector('[data-hh-sert=nobet]').click();
 await new Promise(r=>setImmediate(r));
 assert.equal(calls.find(x=>x.args&&x.args.p_islem==='nobet').args.p_eylem,9);
 console.log('PASS: on sert önlem, bedel formu, nöbet ve üç arayüz');
 dom.window.close();
})().catch(e=>{console.error(e);process.exit(1)});
