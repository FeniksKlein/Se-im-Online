// Offline browser-logic regression: no production connection or player changes.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');

const sql=fs.readFileSync(path.join(__dirname,'../sql/101_cb_yrd_guclu.sql'),'utf8');
const js=fs.readFileSync(path.join(__dirname,'../www/cb_yrd.js'),'utf8');
assert.match(sql,/security definer/g);
assert.match(sql,/cb_yrd_aktif_sira\(p\.id\)/);
assert.match(sql,/v\.vekil=p\.id/);
assert.match(sql,/public\.kararname_cikar/);
assert.match(sql,/enable row level security/g);
assert.doesNotMatch(sql,/truncate\s+table|drop\s+table\s+oyun\.makamlar/i);

const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const actions=[];
const panel={cb_miyim:true,yardimci_sira:null,bakan_miyim:false,kabine_miyim:false,parlamenter:false,
 alanlar:[{sira:1,alan:'ekonomi',kad:'Asistan A'},{sira:2,alan:'sosyal',kad:'Asistan B'}],
 vekalet:null,performans:[{sira:1,tamamlanan:1,geciken:0,puan:60}],
 dosyalar:[{id:7,tur:'kararname',baslik:'Ödenek teklifi',aciklama:'Proje için ek bütçe öneriyorum.',yardimci:'Asistan A',
   sira:1,bakanlik:'maliye',il:null,durum:'onay_bekliyor',veri:{tur:'odenek',veri:{miktar:5}},oylar:[]} ]};
const ctx={
 console, window:null, D:{durum:{profil:{kad:'Başkan'}}},
 API:{rpc:async(name,args)=>{actions.push([name,args]);if(name==='cb_yrd_panel')return panel;return {tamam:true};}},
 hukumetHtml:async()=>'<section id="orijinal">Mevcut oyun</section>',
 e:escape,tarihSaat:s=>s,modal:()=>({}),toast:()=>{},onayla:async()=>true,
 islem:async(fn)=>fn(),modalKapat:()=>{},devletEkrani:async()=>{},
 VERI:{iller:[]}, $:()=>null
};ctx.window=ctx;
vm.createContext(ctx);
vm.runInContext(js,ctx);
(async()=>{
 const cb=await ctx.hukumetHtml();
 assert.match(cb,/Ödenek teklifi/);
 assert.match(cb,/Alan belirle/);
 assert.match(cb,/cbYrdDosyaKarar\(7,true\)/);
 assert.match(cb,/id="orijinal"/);
 await ctx.cbYrdDosyaKarar(7,true);
 assert.ok(actions.some(([ad,p])=>ad==='cb_yrd_dosya_karar'&&p.p_id===7&&p.p_kabul===true));
 panel.cb_miyim=false;panel.yardimci_sira=1;panel.dosyalar=[{...panel.dosyalar[0],id:8,tur:'gorev',durum:'bekliyor',baslik:'<script>alert(1)</script>',hedef:'Maliye',yardimci:'Başkan'}];
 const deputy=await ctx.hukumetHtml();
 assert.match(deputy,/Yeni görev, toplantı veya öneri oluştur/);
 assert.doesNotMatch(deputy,/<script>alert/);
 assert.match(deputy,/&lt;script&gt;/);
 panel.yardimci_sira=null;panel.bakan_miyim=true;panel.kabine_miyim=true;
 const minister=await ctx.hukumetHtml();
 assert.doesNotMatch(minister,/Yeni görev, toplantı veya öneri oluştur/);
 console.log('cb_yrd_guclu: arayüz ve yetki görünürlüğü tamam');
})().catch(e=>{console.error(e);process.exitCode=1;});
