const fs=require('fs');
const path=require('path');
const vm=require('vm');
const assert=require('assert');
const root=path.join(__dirname,'..');
const sql=fs.readFileSync(path.join(root,'sql','109_ek_is_yeni_sektorler.sql'),'utf8');
const ui=fs.readFileSync(path.join(root,'www','ek_isler.js'),'utf8');
const sirket=fs.readFileSync(path.join(root,'www','sirket_tum_turler.js'),'utf8');
const menu=fs.readFileSync(path.join(root,'www','menu_sade.js'),'utf8');
const doc=fs.readFileSync(path.join(root,'..','docs','index.html'),'utf8');
const sektorler=['turizm','lojistik','oto_servis','danismanlik','e_ticaret','geri_donusum'];
for(const kod of sektorler){
 assert(sql.includes("('"+kod+"'"),'SQL sektörü eksik: '+kod);
 assert(sirket.includes('pazar:'+kod),'Kuruluş seçeneği eksik: '+kod);
}
assert(sql.includes('create unique index if not exists ek_is_tek_aktif'),'Tek aktif iş koruması yok');
assert(sql.includes('for update'),'Eş zamanlı isteklere satır kilidi yok');
assert(sql.includes("and user_id=p.id for update"),'İş ödemesinde sahiplik kontrolü yok');
assert(sql.includes("and odendi_at is null"),'Tekrar ödeme koruması yok');
assert(sql.includes('oyun.para_islem(p.id,k.ucret'),'Ödeme hareket defterine işlenmiyor');
assert(sql.includes('at time zone \'Europe/Istanbul\''),'Günlük sayaç Türkiye saatine bağlı değil');
assert(sql.includes("3 then"),'Günlük iş limiti uygulanmıyor');
assert(sql.includes('enable row level security'),'RLS yok');
assert(sql.includes('to authenticated'),'RPC izinleri eksik');
assert(menu.includes('ekranAc(ekIslerEkrani)'),'Ekonomi menüsünde ek iş yok');
// 24.11.2026: yayındaki sayfa tek dosyadır; ek işler modülü içine gömülü olmalı (eski "src=ek_isler.js?v=" denetimi geçersizdi).
assert(doc.includes('window.ekIslerEkrani=ekIslerEkrani'),'Yayındaki sayfada ek iş modülü yok');
// 24.11.2026: Ek İşler 2.0 — günlük hak artık ayardan okunur (başlangıç 5); ayrıntılı testler ek_isler_v2.py ve ek_isler_v2_arayuz.js
const v2=fs.readFileSync(path.join(root,'sql','zz_20261124_ek_isler_v2.sql'),'utf8');
assert(v2.includes('oyun.ek_is_gunluk_limit()')&&v2.includes('if yap >= lim then'),'Günlük hak ayardan okunmuyor');
assert(v2.includes("update oyun.ek_is_ayar set gunluk_limit = 5"),'Günlük hak başlangıcı 5 değil');
assert(v2.includes('for update')&&v2.includes("and odendi_at is null"),'Ek İşler 2.0 kilit/tekrar ödeme koruması yok');

let calls=[],lastHtml='';
const window={};
const panel={gunluk_limit:3,bugun_yapilan:1,bugun_kazanilan:700,simdi:'2026-10-19T12:00:00Z',
 isler:[{kod:'kurye',ad:'Paket Kuryeliği',simge:'🚲',aciklama:'Paket taşı',sure_dakika:45,asgari_ucret:550,azami_ucret:850}],
 aktif:null,gecmis:[]};
const ctx={window,Date,Number,String,console,
 API:{rpc:async(name,params)=>{calls.push({name,params});if(name==='ek_is_paneli')return panel;
  if(name==='ek_is_baslat')return {bitis:'2026-10-19T13:00:00Z',ucret:700};
  if(name==='ek_is_ucret_al')return {ucret:700};}},
 yukleniyor:()=>{},iskelet:(_title,html)=>{lastHtml=html;},toast:()=>{},durumYenile:async()=>{},
 tlYaz:n=>n+' ₺',hataCevir:x=>x,e:x=>String(x)};
vm.runInNewContext(ui,ctx,{filename:'ek_isler.js'});
(async()=>{
 assert.equal(typeof window.ekIslerEkrani,'function');
 await window.ekIslerEkrani();
 assert(lastHtml.includes('Paket Kuryeliği'));
 assert(lastHtml.includes('>Başla<'));
 assert(lastHtml.includes('Günlük Ek İş Hakkı')&&lastHtml.includes('2/3'));
 await window.ekIsBaslat('kurye');
 assert(calls.some(x=>x.name==='ek_is_baslat'&&x.params.p_tur==='kurye'));
 panel.aktif={id:3,ad:'Paket Kuryeliği',simge:'🚲',bitis:'2026-10-19T11:59:00Z',ucret:700};
 await window.ekIslerEkrani();
 assert(lastHtml.includes('Ücretimi al'));
 assert(lastHtml.includes('İş bitti'));
 await window.ekIsUcretAl(3);
 assert(calls.some(x=>x.name==='ek_is_ucret_al'&&x.params.p_id===3));
 console.log('Ek işler ve yeni sektör arayüz testleri başarılı.');
})().catch(e=>{console.error(e);process.exitCode=1;});
