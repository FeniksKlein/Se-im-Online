/* Seçim Online — Avukatlık B Modeli. Mevcut Adliye'ye zarar vermeyen eklenti. */
(function(){
'use strict';
if(typeof adliyeHtml!=='function'||typeof adliyeDosya!=='function')return;
const h=x=>typeof e==='function'?e(String(x??'')):String(x??'').replace(/[&<>"']/g,'');
const money=n=>Number(n||0).toLocaleString('tr-TR',{maximumFractionDigits:0})+' ₺';
const stamp=d=>d?new Date(d).toLocaleString('tr-TR'):'—';
const RPC=(k,v)=>API.rpc(k,v||{});
const error=err=>toast(typeof hataCevir==='function'?hataCevir(err.message):err.message,true);
const op=(v,t)=>'<option value="'+h(v)+'">'+h(t)+'</option>';
async function act(k,v,msg,reload){
 try{let result=await RPC(k,v);toast(msg);if(reload==='dava')await adliyeDosya(v.p_dava);
 else if(typeof reload==='number')await adliyeDosya(reload);
 else await adliyeEkrani();return result;}catch(err){error(err);return null;}
}
function islemButon(label,fn){return '<button class="btn ikinci" onclick='+fn+'>'+label+'</button>'}
function avukatKart(a){
 return '<div class="liste-satir"><div class="orta"><b>Av. '+h(a.kad)+'</b><div class="kucuk">'+h(a.burosu||'Bağımsız avukat')+' · '+Number(a.tamamlanan)+' sonuçlanan dava · '+Number(a.kazanilan)+' kazanılan</div><div class="kucuk">Başarı: '+(a.oran==null?'Henüz sonuçlanmış dava yok':'%'+h(a.oran))+'</div></div></div>';
}
function hukukCiz(s,primler){
 const a=s.akademi||{}, ruh=s.ruhsat||{};
 let z='<div class="kart"><h2>⚖️ Avukatlık ve Hukuk Büroları</h2><p class="alt">B modeli: 7 günlük hesap, 24 saatlik hukuk eğitimi, 20 soruluk sınav (en az 16 doğru), iki uygulamalı vaka ve kontenjan. Hukuki savunma sadece ruhsatlı, dosyaya vekâletli avukatlar tarafından sunulur. Taraflar yine kendi olgu beyanlarını verebilir.</p>';
 z+='<div class="kv"><span class="k">Aktif ruhsat / kontenjan</span><span class="v">'+s.aktif_avukat+' / '+s.kontenjan+'</span></div>';
 z+='<div class="kv"><span class="k">Ruhsat harcı</span><span class="v">100.000 ₺ · yalnız kontenjana yerleşince</span></div>';
 if(ruh.durum==='aktif'){
  z+='<div class="rozet yesil">Ruhsatlı avukat · Aktif</div>'+islemButon('Hukuk bürosu işlemleri','"avukatBuroPanel()"');
 }else if(ruh.durum==='bekliyor'){
  z+='<p class="alt">Başvuru sırası: '+h(ruh.sira)+' · yeni kontenjan açılırsa sıradaki uygun aday ruhsatını alabilir.</p>'+islemButon('Ruhsat sıramı kontrol et','"avukatRuhsat()"');
 }else if(ruh.durum==='askida'||ruh.durum==='iptal'){
  z+='<p class="alt">Ruhsat durumu: '+h(ruh.durum)+'</p>';
 }else if(!s.hesap_uygun){
  z+='<p class="alt">Eğitime başlamak için hesabın 7 günü tamamlamalı.</p>';
 }else if(!s.akademi){
  z+=islemButon('Hukuk Akademisi eğitimine başla','"avukatEgitim()"');
 }else if(!a.sinav_gecildi&&new Date(a.egitim_bitti)>new Date()){
  z+='<p class="alt">24 saatlik eğitim sürüyor. Sınav açılışı: '+stamp(a.egitim_bitti)+'</p>';
 }else if(!a.sinav_gecildi){
  z+='<p class="alt">Sınavda 20 sorunun en az 16 tanesini doğru cevaplamalısın. Başarısız olursan 24 saat sonra yeniden denersin.</p>'
   +(a.son_puan!=null?'<p class="alt">Son puan: '+a.son_puan+'/20</p>':'')
   +islemButon('20 soruluk hukuk sınavını aç','"avukatSinavAc()"');
 }else if(!a.pratik1||!a.pratik2){
  z+='<p class="alt">Hukuk sınavını geçtin ('+a.son_puan+'/20). Uygulamalı staj vakaları: '+(a.pratik1?'✅':'○')+' 1 · '+(a.pratik2?'✅':'○')+' 2.</p>'+islemButon('Uygulamalı vakaları çöz','"avukatPratikAc()"');
 }else{
  z+='<p class="alt">Eğitimi, sınavı ve stajı tamamladın. Kontenjan varsa ruhsat bedeli cüzdanından tahsil edilir; doluysa bekleme listesine girersin.</p>'+islemButon('Baroya ruhsat başvurusu yap','"avukatRuhsat()"');
 }
 z+='</div>';
 if((primler||[]).length)z+='<div class="kart"><h3>Dava kazanma primi hesaplarım</h3>'+(primler||[]).map(k=>'<div class="liste-satir"><div class="orta"><b>Dava #'+k.dava+' · '+money(k.prim)+' prim</b><div class="kucuk">Ödenen: '+money(k.odenen)+' · Kalan: '+money(k.kalan)+' · '+h(k.muvekkil)+'</div></div>'+(k.ben_avukatim&&k.kalan>0?'<button class="btn ikinci" onclick="avukatPrimTahsil('+k.id+')">Prim tahsil et</button>':'')+'</div>').join('')+'</div>'; 
 if(s.benim_burom)z+='<div class="kart"><h3>Hukuk bürom</h3><b>'+h(s.benim_burom.ad)+'</b>'+islemButon('Avukat davet et','"avukatDavet('+Number(s.benim_burom.id)+')"')+'</div>';
 z+='<div class="kart"><h3>Avukatlar ('+(s.avukatlar||[]).length+')</h3><p class="alt">Kazanma oranı, yalnız kesinleşmiş ve düşmemiş gerçek davalardan hesaplanır; bir sonraki davayı otomatik belirlemez.</p>'
 +(s.avukatlar||[]).map(avukatKart).join('')+(!(s.avukatlar||[]).length?'<p class="alt">Henüz ruhsatlı avukat yok.</p>':'')+'</div>';
 z+='<div class="kart"><h3>Hukuk büroları</h3>'
 +(s.burolar||[]).map(b=>'<div class="liste-satir"><div class="orta"><b>'+h(b.ad)+'</b><div class="kucuk">'+h(b.sehir)+' · Kurucu: '+h(b.kurucu)+' · '+b.uye_sayi+' avukat</div></div></div>').join('')
 +(!(s.burolar||[]).length?'<p class="alt">Henüz hukuk bürosu açılmamış.</p>':'')+'</div>';
 return z;
}
const oncekiHtml=adliyeHtml;
adliyeHtml=async function(){
 let eski=await oncekiHtml();
 try{const [s,prim]=await Promise.all([RPC('avukat_durum'),RPC('avukat_primlerim').catch(()=>[])]);return hukukCiz(s,prim)+eski;}
 catch(err){return '<div class="kart"><h3>Avukatlık</h3><p class="alt">Avukatlık paneli yüklenemedi: '+h(err.message)+'</p></div>'+eski;}
};
window.avukatEgitim=()=>act('avukat_akademiye_katil',{},'Hukuk Akademisine kaydoldun; 24 saatlik eğitim başladı.');
window.avukatRuhsat=()=>act('avukat_ruhsat_basvur',{},'Ruhsat başvurun değerlendirildi.');
window.avukatSinavAc=async function(){
 try{
 const s=await RPC('avukat_durum');
 if(!(s.sinav_sorular||[]).length)throw Error('Sınav henüz açılmadı.');
 const html='<p class="alt">20 soruyu cevapla; başarı puanı sunucuda hesaplanır.</p>'+s.sinav_sorular.map((q,i)=>
 '<div class="kart"><b>'+(i+1)+'. '+h(q.soru)+'</b><div class="alan"><select id="hukSoru'+q.id+'">'+op('','Cevap seç')
 +(q.secenekler||[]).map((v,j)=>op(j+1,(j+1)+') '+v)).join('')+'</select></div></div>').join('')
 +'<button class="btn altin" id="hukSinavGonder">Sınavı teslim et</button>';
 const m=modal(html);adlFormBaslik(m,'Hukuk Akademisi sınavı');
 m.querySelector('#hukSinavGonder').onclick=async()=>{
  const cevap={};for(const q of s.sinav_sorular){let v=m.querySelector('#hukSoru'+q.id).value;if(!v)return toast('Lütfen bütün soruları cevaplayın.',true);cevap[q.id]=Number(v);}
  try{const r=await RPC('avukat_sinav_gonder',{p_cevaplar:cevap});modalKapat();toast('Sınav: '+r.puan+'/20 · '+(r.gecti?'Başarılı!':'24 saat sonra tekrar dene.'));await adliyeEkrani();}catch(err){error(err);}
 };
 }catch(err){error(err);}
};
window.avukatPratikAc=async function(){
 try{
 const s=await RPC('avukat_durum'),a=s.akademi||{};
 const html=(s.uygulamalar||[]).filter(x=>!a['pratik'+x.id]).map(x=>
 '<div class="kart"><h3>Uygulamalı vaka '+x.id+'</h3><p>'+h(x.soru)+'</p><div class="alan"><select id="hukPratik'+x.id+'">'+op('','Seç')+x.secenekler.map((v,j)=>op(j+1,v)).join('')+'</select></div><button class="btn ikinci" onclick="avukatPratikGonder('+x.id+')">Yanıtı ver</button></div>').join('');
 const m=modal(html||'<p>İki vaka tamamlandı.</p>');adlFormBaslik(m,'Staj uygulaması');
 }catch(err){error(err);}
};
window.avukatPratikGonder=async id=>{
 const el=document.getElementById('hukPratik'+id);
 if(!el||!el.value)return toast('Cevabını seç.',true);
 try{let r=await RPC('avukat_pratik_gonder',{p_senaryo:id,p_cevap:Number(el.value)});modalKapat();toast(r.gecti?'Vaka başarıyla tamamlandı.':'Yanıt uygun bulunmadı; daha sonra tekrar dene.');await adliyeEkrani();}catch(err){error(err);}
};
window.avukatBuroPanel=async function(){
 try{
 const d=await RPC('avukat_durum');
 const il=await RPC('avukat_iller');
 const davetler=await RPC('avukat_buro_davetler');
 let html='<p class="alt">Büro kuruluş bedeli 250.000 ₺. Bir avukat aynı anda yalnız bir aktif büroda çalışabilir.</p>';
 if(!d.benim_burom)html+='<div class="alan"><label>Büro adı</label><input id="hukBuroAd" maxlength="90" placeholder="Örnek: Adalet Hukuk Bürosu"></div><div class="alan"><label>Kuruluş ili</label><select id="hukBuroIl">'+(il||[]).map(x=>op(x.id,x.ad)).join('')+'</select></div><button class="btn altin" id="hukBuroAc">Hukuk bürosu aç</button>';
 else html+='<h3>'+h(d.benim_burom.ad)+'</h3><button class="btn ikinci" onclick="avukatDavet('+d.benim_burom.id+')">Avukat davet et</button>';
 html+='<h3>Gelen büro davetleri</h3>'+(davetler||[]).map(x=>'<div class="liste-satir"><div class="orta"><b>'+h(x.ad)+'</b><div class="kucuk">'+h(x.kurucu)+'</div></div><button class="btn ikinci" onclick="avukatDavetYanit('+x.id+',true)">Kabul</button><button class="btn ikinci" onclick="avukatDavetYanit('+x.id+',false)">Reddet</button></div>').join('')+(!(davetler||[]).length?'<p class="alt">Davet yok.</p>':'');
 const m=modal(html);adlFormBaslik(m,'Hukuk büroları');
 if(!d.benim_burom)m.querySelector('#hukBuroAc').onclick=async()=>{
  const ad=m.querySelector('#hukBuroAd').value,il=Number(m.querySelector('#hukBuroIl').value);
  try{await RPC('avukat_buro_ac',{p_ad:ad,p_il:il});modalKapat();toast('Hukuk bürosu kuruldu.');await adliyeEkrani();}catch(err){error(err);}
 };
 }catch(err){error(err);}
};
window.avukatDavet=bid=>{
 const m=modal('<div class="alan"><label>Davet edeceğiniz avukatın kullanıcı adı</label><input id="hukDavetKad"></div><button class="btn altin" id="hukDavetEt">Davet gönder</button>');
 adlFormBaslik(m,'Hukuk bürosuna avukat davet et');
 m.querySelector('#hukDavetEt').onclick=async()=>{try{await RPC('avukat_buro_davet',{p_buro:bid,p_kad:m.querySelector('#hukDavetKad').value});modalKapat();toast('Davet gönderildi.');}catch(err){error(err);}};
};
window.avukatDavetYanit=(bid,kabul)=>act('avukat_buro_davet_cevap',{p_buro:bid,p_kabul:kabul},'Davet yanıtlandı.');
function davaHukukHtml(data,davaId,ruhsat){
 let html='<div class="kart"><h3>⚖️ Vekâlet ve avukat teklifleri</h3><p class="alt">Hukuki savunmayı yalnız ruhsatlı, müvekkilce yetkilendirilmiş avukat verir. Taraflar olaylara ilişkin kendi beyanlarını sunabilir. Avukatlık ücreti tarafların anlaşmasına bağlıdır.</p>';
 if(ruhsat)html+='<button class="btn altin" onclick="avukatTeklifModal('+davaId+')">Bu davaya avukatlık teklifi ver</button>';
 (data.vekaletler||[]).forEach(v=>{html+='<div class="liste-satir"><div class="orta"><b>'+h(v.avukat)+' · '+h(v.taraf==='davaci'?'Davacı vekili':'Davalı vekili')+'</b><div class="kucuk">'+money(v.ucret)+' · '+(v.aktif?'Aktif vekâlet':'Sona erdi')+'</div></div>'+(v.aktif&&v.benim?'<button class="btn ikinci" onclick="avukatVekaletIptal('+v.id+','+davaId+')">Vekâleti bitir</button>':'')+'</div>';});
 (data.teklifler||[]).forEach(t=>{html+='<div class="liste-satir"><div class="orta"><b>'+h(t.avukat)+' · '+h(t.taraf==='davaci'?'Davacı tarafı':'Davalı tarafı')+'</b><div class="kucuk">Teklif: '+money(t.tutar)+' · Başarı primi: %'+h(t.prim)+' · '+h(t.durum)+'</div>'+(t.aciklama?'<p class="kucuk">'+h(t.aciklama)+'</p>':'')+'</div>'+(t.durum==='bekliyor'&&t.cevaplayabilirim?'<button class="btn altin" onclick="avukatTeklifKarar('+t.id+',true,'+davaId+')">Kabul et</button><button class="btn ikinci" onclick="avukatKarsiTeklifModal('+t.id+','+davaId+')">Pazarlık</button><button class="btn ikinci" onclick="avukatTeklifKarar('+t.id+',false,'+davaId+')">Reddet</button>':'')+'</div>';});
 (data.pazarlik||[]).forEach(z=>{html+='<div class="liste-satir"><div class="orta"><b>Karşı teklif: '+h(z.avukat)+'</b><div class="kucuk">'+money(z.tutar)+' · %'+h(z.prim)+' prim · '+h(z.durum)+'</div></div>'+(z.avukat_miyim&&z.durum==='bekliyor'?'<button class="btn altin" onclick="avukatPazarlikKarar('+z.teklif_id+',true,'+davaId+')">Kabul et</button><button class="btn ikinci" onclick="avukatPazarlikKarar('+z.teklif_id+',false,'+davaId+')">Reddet</button>':'')+'</div>';});
 if((data.vekaletler||[]).some(v=>v.aktif&&v.avukat_miyim))html+='<button class="btn altin" onclick="avukatSavunmaModal('+davaId+')">Vekil sıfatıyla hukuki savunma ver</button>';
 return html+'</div>';
}
const oncekiDosya=adliyeDosya;
adliyeDosya=async function(id){
 await oncekiDosya(id);
 try{
  const root=document.getElementById('icerik');
  if(!root||!root.textContent.includes('Dava')&& !root.textContent.includes('#'+id))return;
  const [x,s,pazarlik]=await Promise.all([RPC('avukat_dava_durum',{p_dava:id}),RPC('avukat_durum'),RPC('avukat_pazarlik_liste',{p_dava:id}).catch(()=>[])]);
  x.pazarlik=pazarlik;
  if(document.getElementById('icerik')!==root)return;
  // Eski Adliye etiketleri hukuki savunma ile taraf beyanini ayirmiyordu.
  for(const button of root.querySelectorAll('button')){
    if(button.textContent.trim()==='Savunma / beyan ver')button.textContent='Olay beyanı ver (avukat savunması değil)';
  }
  const kayit=await RPC('adliye_detay',{p_dava:id}).catch(()=>null);
  for(const beyan of (kayit?.beyanlar||[]).filter(b=>b.rol==='avukat')){
    const satir=Array.from(root.querySelectorAll('.liste-satir')).find(n=>n.querySelector('p')?.textContent.trim()===beyan.metin.trim()&&n.querySelector('b')?.textContent.includes(beyan.yazar));
    if(satir){const bas=satir.querySelector('b');if(bas)bas.textContent='Av. '+beyan.yazar+' · Hukuki savunma';}
  }
  const host=document.createElement('div');host.innerHTML=davaHukukHtml(x,id,s.ruhsat?.durum==='aktif');
  root.insertAdjacentElement('afterbegin',host);
 }catch(err){console.warn('Hukuk paneli:',err.message);}
};
window.avukatTeklifModal=id=>{
 const m=modal('<p class="alt">Ücret serbest pazarlıkla belirlenir. Peşin ücret kabulde doğrudan cüzdanına aktarılır; tazminat üzerinden başarı primi ayrıca sözleşmede belirtilir.</p><div class="alan"><label>Temsil edeceğin taraf</label><select id="hukTaraf">'+op('davaci','Davacı')+op('davali','Davalı')+'</select></div><div class="alan"><label>Peşin ücret (₺)</label><input id="hukFiyat" type="number" min="0" step="1" value="100000"></div><div class="alan"><label>Tahsil edilen tazminat üzerinden prim (%)</label><input id="hukPrim" type="number" min="0" max="30" step="1" value="0"></div><div class="alan"><label>Teklif mesajı</label><textarea id="hukAcik" maxlength="500" rows="3"></textarea></div><button class="btn altin" id="hukTeklifGonder">Teklifi gönder</button>');
 adlFormBaslik(m,'Dava #'+id+' avukatlık teklifi');
 m.querySelector('#hukTeklifGonder').onclick=async()=>{
  try{await RPC('avukat_teklif_ver',{p_dava:id,p_taraf:m.querySelector('#hukTaraf').value,p_tutar:Number(m.querySelector('#hukFiyat').value),p_prim:Number(m.querySelector('#hukPrim').value),p_aciklama:m.querySelector('#hukAcik').value});modalKapat();toast('Avukatlık teklifi gönderildi.');await adliyeDosya(id);}catch(err){error(err);}
 };
};
window.avukatTeklifKarar=async(tid,kabul,id)=>{
 if(kabul&&!await onayla('Avukatlık sözleşmesini kabul et','Belirlenen ücret cüzdanından anında kesilerek avukata gönderilir.','Kabul et',true))return;
 try{await RPC('avukat_teklif_karar',{p_teklif:tid,p_kabul:kabul});toast(kabul?'Vekâlet sözleşmesi kuruldu.':'Teklif reddedildi.');await adliyeDosya(id);}catch(err){error(err);}
};
window.avukatVekaletIptal=async(vid,id)=>{
 if(!await onayla('Vekâleti sonlandır','Vekâlet işlemi sona erecek. Daha önce ödenen hizmet bedeli kendiliğinden iade edilmez.','Sonlandır',true))return;
 try{await RPC('avukat_vekalet_iptal',{p_vekalet:vid});toast('Vekâlet sonlandırıldı.');await adliyeDosya(id);}catch(err){error(err);}
};
window.avukatSavunmaModal=id=>{
 const m=modal('<div class="alan"><label>Hukuki savunma ve gerekçeler (20–2500 karakter)</label><textarea id="hukSavunma" rows="6" maxlength="2500"></textarea></div><button class="btn altin" id="hukSavGonder">Mahkemeye savunma sun</button>');
 adlFormBaslik(m,'Dava #'+id+' · Avukat savunması');
 m.querySelector('#hukSavGonder').onclick=async()=>{try{await RPC('avukat_savunma_ver',{p_dava:id,p_metin:m.querySelector('#hukSavunma').value});modalKapat();toast('Avukat savunması mahkemeye sunuldu.');await adliyeDosya(id);}catch(err){error(err);}};
};
window.avukatPrimTahsil=async id=>{try{const r=await RPC('avukat_prim_tahsil',{p_kayit:id});toast('Prim tahsil: '+money(r.tahsil));await adliyeEkrani();}catch(err){error(err);}};
window.avukatPazarlikKarar=async(id,kabul,dava)=>{try{await RPC('avukat_pazarlik_karar',{p_teklif:id,p_kabul:kabul});toast(kabul?'Karşı teklifi kabul ettin; müvekkil sözleşmeyi imzalayabilir.':'Karşı teklif reddedildi.');await adliyeDosya(dava);}catch(err){error(err);}};
window.avukatKarsiTeklifModal=(id,dava)=>{
 const m=modal('<div class="alan"><label>Karşı teklif ücreti (₺)</label><input id="hukKarsiTutar" type="number" min="0" step="1"></div><div class="alan"><label>Başarı primi (%)</label><input id="hukKarsiPrim" type="number" min="0" max="30" step="1" value="0"></div><button class="btn altin" id="hukKarsiGonder">Karşı teklif gönder</button>');
 adlFormBaslik(m,'Avukatla ücret pazarlığı');
 m.querySelector('#hukKarsiGonder').onclick=async()=>{try{await RPC('avukat_karsi_teklif',{p_teklif:id,p_tutar:Number(m.querySelector('#hukKarsiTutar').value),p_prim:Number(m.querySelector('#hukKarsiPrim').value)});modalKapat();toast('Karşı teklif avukata iletildi.');await adliyeDosya(dava);}catch(err){error(err);}};
};
})();
