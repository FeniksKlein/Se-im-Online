// node gelistirici/test/halk_tedbir_ui.js
// On iki yeni hükümet aracı: düğme metinleri, RPC bağlantısı ve HTML kaçışı.
const {JSDOM}=require('jsdom'),fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const kok=path.join(__dirname,'..','..');
const adlar=['Acil Hizmet Seferberliği','Bölgesel Vergi Tatili','İstihdam Taahhüt Paketi','Resmi Basın Brifingi','Acil Sosyal Destek Kartı','Güvenli Alan / Güzergâh','Meclis Araştırma Komisyonu','Bağımsız Gözlemci','İktidar Kapı Kapı','Gece Toplanma Kısıtı','İletişim Yavaşlatma','Kültür-Festival'];
const dom=new JSDOM('<main id="app"></main>',{runScripts:'outside-only'}),w=dom.window,calls=[];
w.e=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
w.yukleniyor=()=>{};w.toast=()=>{};w.hataCevir=s=>s;w.ekranAc=fn=>fn();w.iskelet=(t,h)=>w.document.getElementById('app').innerHTML=h;
const tedbir={tamam:true,eylemler:[{id:9,yonetebilir:true,katilimci:true,organizator:true,sirketler:[{id:4,ad:'Anadolu Un'}],bedeller:{hizmet:250000,vergi_tatil:300000,istihdam:200000,brifing:100000,sosyal_kart:4000,guzergah:100000,komisyon:100000,gozlemci:50000,kapi:100000,gece:100000,iletisim:150000,festival:150000},acabilir:['hizmet','vergi_tatil','istihdam','brifing','sosyal_kart','guzergah','komisyon','gozlemci','kapi','gece','iletisim','festival'],tedbirler:[{id:3,tur:'hizmet',ad:'Acil Hizmet Seferberliği',durum:'aktif',bedel:250000,gerekce:'İl hizmetini hemen yükseltmeyi taahhüt ediyoruz',karsi:['yetersiz','slogan']},{id:4,tur:'istihdam',ad:'İstihdam Taahhüt Paketi',durum:'aktif',bedel:200000,gerekce:'Şirketlerle birlikte iş sözü veriyoruz',karsi:['istihdam_soz','istihdam_grev']}]}]};
w.API={rpc:async(fn,args)=>{calls.push({fn,args});if(fn==='sokak_tedbir_panel')return tedbir;if(fn!=='sokak_uzlasma_panel')return {tamam:true};return {aktif:true,mudahale_yetki:true,icisleri_kasa_tl:1000000,baslatabilir:false,hukumet:true,iktidar:false,ayar:{baslatma_bedeli:50000},kaynaklar:[],iller:[],eylemler:[{id:9,ben_baslattim:true,bedeller:{masa:100000},katilimcilar:[],kararlar:[],il:'Muğla',parti:'Parti',gerekce:'Hizmet <img>',durum:'aktif',seviye:50,katilim:4,muhalefet_fonu:50000,iktidar_fonu:0,destekler:[]}]};}};
w.eval(fs.readFileSync(path.join(__dirname,'../www/halk_hareketleri.js'),'utf8'));
const q=s=>w.document.querySelector(s),qa=s=>[...w.document.querySelectorAll(s)],flush=()=>new Promise(r=>setImmediate(r));
(async()=>{
 await w.sokakHareketleriEkrani();
 const html=w.document.getElementById('app').innerHTML;
 assert.equal(q('img'),null,'gerekçe HTML kaçmalı');
 for(const ad of adlar) assert.ok(html.includes(ad),ad+' görünmeli');
 assert.ok(html.includes('Yetersiz buluyorum'));
 assert.ok(html.includes('Greve çağır'));
 q('.hhTedbir textarea').value='İldeki hizmet sözünü bugün uygulamaya alıyoruz';
 q('.hhTedbir [name=tur]').value='hizmet';
 q('.hhTedbir').dispatchEvent(new w.Event('submit',{cancelable:true}));
 await flush();
 const ac=calls.find(x=>x.fn==='sokak_tedbir_ac').args;
 assert.equal(ac.p_eylem,9); assert.equal(ac.p_tur,'hizmet'); assert.equal(ac.p_gerekce,'İldeki hizmet sözünü bugün uygulamaya alıyoruz');
 q('[data-hh-tur=yetersiz]').click();
 await flush();
 assert.equal(calls.find(x=>x.fn==='sokak_tedbir_hamle'&&x.args.p_tur==='yetersiz').args.p_metin,'hizmet');
 q('.hhTedbirSoz').dispatchEvent(new w.Event('submit',{cancelable:true}));
 await flush();
 assert.equal(calls.find(x=>x.args&&x.args.p_tur==='istihdam_soz').args.p_metin,'4');
 q('.hhTedbirHamle textarea').value='Söz yetmez, hizmet gelsin';
 q('.hhTedbirHamle').dispatchEvent(new w.Event('submit',{cancelable:true}));
 await flush();
 assert.equal(calls.find(x=>x.args&&x.args.p_tur==='slogan').args.p_metin,'Söz yetmez, hizmet gelsin');
 for(const dosya of ['www/halk-hareketleri-v2.js','docs/halk-org-davet.js','www/halk-org-davet.js']){
  const src=fs.readFileSync(path.join(kok,dosya),'utf8');
  for(const ad of adlar) assert.ok(src.includes(ad),dosya+' içinde '+ad);
  assert.ok(src.includes('sokak_tedbir_ac')&&src.includes('sokak_tedbir_hamle')&&src.includes('sokak_tedbir_panel'),dosya+' RPC');
  assert.ok(src.includes('Yetersiz')&&src.includes('Sahneyi')&&src.includes('İkna olmadım'),dosya+' karşı hamle');
 }
 console.log('PASS: 12 araç, bedel formu, yetersiz/slogan/şirket sözü ve üç arayüz');
 dom.window.close();
})().catch(e=>{console.error(e);process.exit(1)});
