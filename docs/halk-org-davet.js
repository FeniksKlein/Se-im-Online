/* Halk hareketleri kuruluş liderliği ve canlı eylem davetleri */
(function(){
'use strict';

// Halk Hareketleri: iOS/Safari ve küçük ekranlarda erişilebilir form görünümü.
// Stiller yalnızca bu ekrandaki eylem/katılım formlarına uygulanır.
const hhStyleId='so-hh-form-okunurluk-v1';
if(!document.getElementById(hhStyleId)){
 const style=document.createElement('style');
 style.id=hhStyleId;
 style.textContent=`
 #hhOrgUI form, #so-v2 form {
   display:flex !important;
   flex-direction:column !important;
   align-items:stretch !important;
   gap:10px !important;
   width:100% !important;
   min-width:0 !important;
   box-sizing:border-box !important;
 }
 #hhOrgUI form > label, #so-v2 form > label {
   display:block !important;
   position:static !important;
   width:100% !important;
   margin:5px 0 0 !important;
   color:#eef2ff !important;
   font-size:15px !important;
   font-weight:600 !important;
   line-height:1.5 !important;
   white-space:normal !important;
 }
 #hhOrgUI form input:not([type="checkbox"]):not([type="radio"]),
 #hhOrgUI form select, #hhOrgUI form textarea,
 #so-v2 form input:not([type="checkbox"]):not([type="radio"]),
 #so-v2 form select, #so-v2 form textarea {
   display:block !important;
   position:static !important;
   width:100% !important;
   min-width:0 !important;
   max-width:100% !important;
   box-sizing:border-box !important;
   min-height:48px !important;
   margin:0 !important;
   padding:12px 14px !important;
   font:400 16px/1.45 system-ui,-apple-system,sans-serif !important;
   color:#f5f7ff !important;
   -webkit-text-fill-color:#f5f7ff !important;
   background-color:#111a34 !important;
   border:1px solid #7180ab !important;
   border-radius:12px !important;
   opacity:1 !important;
   box-shadow:none !important;
   vertical-align:middle !important;
 }
 #hhOrgUI form select, #so-v2 form select {
   color-scheme:dark !important;
   appearance:auto !important;
   -webkit-appearance:menulist !important;
   text-overflow:ellipsis !important;
 }
 #hhOrgUI form option, #so-v2 form option {
   color:#f5f7ff !important;
   background:#111a34 !important;
 }
 #hhOrgUI form textarea, #so-v2 form textarea {
   min-height:112px !important;
   height:auto !important;
   resize:vertical !important;
   overflow-wrap:anywhere !important;
 }
 #hhOrgUI form input::placeholder, #hhOrgUI form textarea::placeholder,
 #so-v2 form input::placeholder, #so-v2 form textarea::placeholder {
   color:#b6c1da !important;
   -webkit-text-fill-color:#b6c1da !important;
   opacity:1 !important;
 }
 #hhOrgUI form button, #so-v2 form button {
   display:block !important;
   width:100% !important;
   max-width:100% !important;
   box-sizing:border-box !important;
   min-height:48px !important;
   margin:10px 0 0 !important;
   padding:12px 14px !important;
   white-space:normal !important;
   line-height:1.4 !important;
   overflow-wrap:anywhere !important;
 }
 #hhOrgUI form :is(select,input,textarea):focus-visible,
 #so-v2 form :is(select,input,textarea):focus-visible {
   outline:2px solid #bea5f5 !important;
   outline-offset:2px !important;
 }
 #hhOrgUI .kart, #so-v2 .kart { min-width:0; overflow-wrap:anywhere; }
 `;
 document.head.appendChild(style);
}

const oldIskelet=iskelet;
iskelet=function(baslik,govde,opt){
 if(baslik==='Halk Hareketleri'&&!String(govde).includes('id="hhOrgAnchor"'))
  govde='<div id="hhOrgAnchor"></div>'+govde;
 return oldIskelet(baslik,govde,opt);
};
const prev=sokakHareketleriEkrani;
sokakHareketleriEkrani=async function(){
 await prev();
 const area=document.getElementById('hhOrgAnchor')||document.getElementById('so-v2');
 if(!area||document.getElementById('hhOrgUI'))return;
 let d;
 try{d=await API.rpc('sokak_org_panel');}
 catch(err){toast(hataCevir(err.message||String(err)),true);return;}
 const esc=v=>e(String(v??'')),trNum=v=>Number(v||0).toLocaleString('tr-TR');
 const sources=d.baslatma_kaynaklari||[], targets=d.davet_hedefleri||[];
 const active=x=>d.aktif&&x.durum==='aktif'&&Date.parse(x.bitis)>Date.now();
 const createOptions=sources.map(o=>'<option value="'+esc(o.tur)+':'+Number(o.id)+'">'+esc(o.tur==='parti'?'Parti':'Dernek')+' · '+esc(o.ad)+'</option>').join('');
 const targetOptions=targets.map(o=>'<option value="'+esc(o.tur)+':'+Number(o.id)+'">'+esc(o.tur==='parti'?'Parti':'Dernek')+' · '+esc(o.ad)+'</option>').join('');
 let html='<div class="kart" id="hhOrgVersion"><h2>📢 Her parti ve dernek eylem başlatabilir</h2>'+
  '<p>Parti genel başkanları ve dernek başkanları, kendi kuruluşları adına eylem açabilir. İlde aktif oyuncu sayısı ve memnuniyetsizlik ön şartı yoktur. Eylem başladıktan sonra diğer parti ve dernekler davet edilebilir; daveti kabul eden kuruluş para yatırmadan ortak destekçi olur.</p>'+
  '<p><small>Hesabın en az 7 günlük olmalı. Kuruluş kasasından '+trNum(d.ayar?.baslatma_bedeli)+' TL alınır. İl, kuruluş ve ülke çapındaki bekleme/sayı sınırları devam eder.</small></p></div>';
 if(d.aktif&&sources.length){
  html+='<div class="kart"><h3>Yeni eylem başlat</h3><form id="hhOrgCreate">'+
   '<label>Eylemi başlatan parti / dernek</label><select name="kaynak" required>'+createOptions+'</select>'+
   '<label>İl</label><select name="il" required>'+(d.iller||[]).map(i=>'<option value="'+Number(i.id)+'">'+esc(i.ad)+'</option>').join('')+'</select>'+
   '<label>Talep</label><select name="tur"><option value="genel">Genel / siyasi ve toplumsal bir talep</option><option value="hizmet">İl hizmet memnuniyeti +5</option><option value="issizlik">İşsizlik −0,5</option><option value="vergi">Vergi −1</option></select>'+
   '<label>Eylemin gerekçesi ve talebi</label><textarea name="gerekce" minlength="15" maxlength="400" required placeholder="Hangi karara veya soruna karşı eylem düzenleniyor?"></textarea>'+
   '<button class="btn altin">Kuruluş kasasından '+trNum(d.ayar?.baslatma_bedeli)+' TL öde ve başlat</button></form></div>';
 }
 if((d.davetler||[]).length){
  html+='<div class="kart"><h3>📨 Kuruluşlarına gelen eylem davetleri</h3>';
  for(const inv of d.davetler){
   html+='<div class="kart"><b>'+esc(inv.kurulus)+' · '+esc(inv.il)+'</b><p>'+esc(inv.eylem)+'</p>'+
   '<button class="btn altin" data-hh-accept="'+Number(inv.id)+'">Daveti kabul et</button> '+
   '<button class="btn" data-hh-reject="'+Number(inv.id)+'">Reddet</button></div>';
  }
  html+='</div>';
 }
 for(const x of d.eylemler||[]){
  if(!active(x)||!x.ben_baslattim)continue;
  html+='<div class="kart"><details><summary><b>📨 Eylem #'+Number(x.id)+' · Parti / dernek davet et</b></summary>'+
   '<p>'+esc(x.il)+' · '+esc(x.parti)+' · Davet edilen kuruluş lideri katılımı onaylar. Davet için ek ücret gerekmez.</p>';
  if(targets.length){
   html+='<form class="hhOrgInvite" data-id="'+Number(x.id)+'"><label>Davet edilecek parti veya dernek</label>'+
    '<select name="hedef">'+targetOptions+'</select><button class="btn altin">Davet gönder</button></form>';
  }else html+='<p>Davet edilecek açık parti veya dernek bulunamadı.</p>';
  html+='</details></div>';
 }
 area.insertAdjacentHTML('afterbegin','<section id="hhOrgUI">'+html+'</section>');
 // Eski istemci alanını ve güncelliğini yitirmiş başlatma açıklamalarını kaldır.
 const oldForm=document.getElementById('hhYeni');if(oldForm)oldForm.closest('.kart')?.remove();
 document.querySelectorAll('details').forEach(details=>{
  const title=details.querySelector('summary')?.textContent||'';
  if(!title.includes('Kurallar ve kötüye kullanım sınırları'))return;
  const pp=details.querySelectorAll('p');
  if(pp[0])pp[0].textContent='Başlatma: Her parti genel başkanı ve dernek başkanı, en az 7 günlük hesap ve kuruluş kasasından '+trNum(d.ayar?.baslatma_bedeli)+' TL ile eylem başlatabilir. İlde aktif oyuncu ve memnuniyetsizlik ön şartı yoktur.';
  if(pp[1])pp[1].textContent=pp[1].textContent.replaceAll('Parti başına','Kuruluş başına');
 });
 const note='Yeni eylem için ilin memnuniyetsizlik ve katılım şartlarını sağlaması gerekir.';
 document.querySelectorAll('.kart').forEach(card=>{if(card.textContent?.trim()==='Henüz eylem yok. '+note)card.textContent='Henüz eylem yok. Bir parti veya dernek başkanı ilk eylemi başlatabilir.';});
 area.querySelectorAll('small').forEach(s=>{
  if(s.textContent.includes('Yeni eylem için genel başkanlık'))s.textContent='Eylemi parti veya dernek lideri başlatabilir; ilde aktif oyuncu ve memnuniyetsizlik ön şartı yoktur. Bütçe ve bekleme sınırları korunur.';
 });
 async function send(btn,fn,args){
  btn.disabled=true;
  try{await API.rpc(fn,args);toast('İşlem başarıyla kaydedildi');await sokakHareketleriEkrani();}
  catch(ex){toast(hataCevir(ex.message||String(ex)),true);btn.disabled=false;}
 }
 const form=document.getElementById('hhOrgCreate');
 form?.addEventListener('submit',ev=>{
  ev.preventDefault();const a=new FormData(form),[tur,id]=String(a.get('kaynak')).split(':');
  send(form.querySelector('button'),'sokak_org_baslat',{
   p_il:Number(a.get('il')),p_gerekce:String(a.get('gerekce')),p_tur:String(a.get('tur')),
   p_kaynak:tur,p_kaynak_id:Number(id)
  });
 });
 document.querySelectorAll('.hhOrgInvite').forEach(form=>form.addEventListener('submit',ev=>{
  ev.preventDefault();const [tur,id]=String(new FormData(form).get('hedef')).split(':');
  send(form.querySelector('button'),'sokak_davet_gonder',{p_eylem:Number(form.dataset.id),p_hedef_tur:tur,p_hedef_id:Number(id)});
 }));
 document.querySelectorAll('[data-hh-accept]').forEach(btn=>btn.addEventListener('click',()=>send(btn,'sokak_davet_yanit',{p_davet:Number(btn.dataset.hhAccept),p_kabul:true})));
 document.querySelectorAll('[data-hh-reject]').forEach(btn=>btn.addEventListener('click',()=>send(btn,'sokak_davet_yanit',{p_davet:Number(btn.dataset.hhReject),p_kabul:false})));
};
})();


/* SO_HALK_FINANS_V1 — Protesto vs hükümet bütçe rekabeti */
(function(){
 'use strict';
 const previous=sokakHareketleriEkrani;
 sokakHareketleriEkrani=async function(){
  await previous();
  const root=document.getElementById('hhOrgAnchor')||document.getElementById('so-v2');
  if(!root||document.getElementById('hhFinansUI'))return;
  let d;
  try{d=await API.rpc('sokak_finans_panel');}
  catch(err){console.warn('Halk bütçe paneli',err);return;}
  const esc=x=>e(String(x??''));
  const fmt=x=>Number(x||0).toLocaleString('tr-TR',{maximumFractionDigits:2});
  const money=x=>fmt(x)+' TL';
  let html='<section id="hhFinansUI"><div class="kart"><h2>⚖️ Eylem ve hükümet bütçe rekabeti</h2>'+
    '<p>Eylem daha çok fonlandıkça gücü artar. Hükümet de kamu bütçesinden daha fazla harcayarak 12 saat boyunca eylemin gücünü azaltabilir. Harcama arttıkça etki yükselir ama ek paranın verimi azalır; yüksek harcama sonrasında kamuoyu tepkisi oluşabilir.</p>'+
    '<p><small>Para tek başına otomatik kırmızı eylem oluşturmaz; bunun için en az 3 gerçek yerel katılımcı gerekir. Müdahale gözaltı içermez, etkisi süre sonunda biter. Her harcama kayıtlara işlenir.</small></p></div>';
  const list=(d.eylemler||[]).filter(x=>x.durum==='aktif'&&Date.parse(x.bitis)>Date.now());
  for(const x of list){
   const max=Number(x.max_butce||d.baslatma_bedeli||50000);
   const min=Number(d.baslatma_bedeli||50000);
   const base=Number(x.muhalefet_fonu||0);
   const oldReduction=Number(x.mudahale_puani||0);
   const pct=Math.min(100,Math.max(0,Number(x.seviye||0)));
   html+='<div class="kart"><h3>⚔️ '+esc(x.il)+' · '+esc(x.kurulus)+' · Eylem #'+Number(x.id)+'</h3>'+
    '<p><b>Mevcut eylem gücü: '+fmt(x.seviye)+'/100</b></p>'+
    '<div style="width:100%;height:13px;background:rgba(128,128,128,.24);border-radius:9px;overflow:hidden"><div style="height:100%;width:'+pct+'%;background:linear-gradient(90deg,#e3b151,#ef5959);border-radius:9px"></div></div>'+
    '<p>Protesto fonu: <b>'+money(x.muhalefet_fonu)+'</b> · Fona bağlı güç: <b>+'+fmt(x.fon_guc_puani)+'</b> / 60</p>'+
    '<p>Hükümet uzlaşma fonu: <b>'+money(x.iktidar_fonu)+'</b> · Güncel müdahale katkısı: <b>'+fmt(oldReduction)+'</b> puan</p>'+
    '<p><small>Hükümetin bütçeli müdahale harcaması: '+money(x.harcanan)+'. Polis: '+money(x.polis_gider)+'. Diğer kararlar: '+money(x.karar_gider)+'.</small></p>';
   if(d.mudahale_yetki){
    html+='<details><summary><b>🏛️ Kamu bütçesiyle müdahaleyi artır</b></summary>'+
     '<p>İçişleri kullanılabilir bütçesi: '+money(d.icisleri_kasa_tl)+'. İşlem başına '+money(min)+' – '+money(max)+'. Her 6 saatte bir müdahale; ülke çapında 24 saatte toplam 4 müdahale sınırı.</p>'+
     '<form class="hhFinButce" data-id="'+Number(x.id)+'" data-protesto="'+base+'" data-min="'+min+'" data-max="'+max+'">'+
     '<label>Hükümetin harcayacağı tutar (TL)</label><input name="tutar" type="number" min="'+min+'" max="'+max+'" step="1000" value="'+min+'" required>'+
     '<p class="hhFinTahmin">Tahmini etkisi hesaplanıyor...</p>'+
     '<label>Müdahalenin kamu güvenliği ve diyalog gerekçesi</label>'+
     '<textarea name="gerekce" minlength="25" maxlength="500" required placeholder="Somut gerekçenizi ve uygulanacak önlemleri belirtin."></textarea>'+
     '<button class="btn altin">Kamu bütçesinden harca ve uygula</button></form></details>';
   }
   if((x.mudahaleler||[]).length){
    html+='<details><summary>📒 Kamu müdahale geçmişi ('+x.mudahaleler.length+')</summary>';
    for(const m of x.mudahaleler){
     html+='<p><b>'+money(m.bedel)+'</b> · '+esc(m.durum)+' · -'+fmt(m.etki)+' puan'+(Number(m.tepki)>0?' · sonrasında +'+fmt(m.tepki)+' tepki':'')+
      '<br><small>'+esc(new Date(m.zaman).toLocaleString('tr-TR'))+' · '+esc(m.gerekce)+'</small></p>';
    }
    html+='</details>';
   }
   html+='</div>';
  }
  if(!list.length)html+='<div class="kart">Aktif eylem olduğunda protesto fonu, hükümet harcamaları ve anlık güç dengesi burada gösterilecek.</div>';
  html+='</section>';
  root.insertAdjacentHTML('afterbegin',html);
  root.querySelectorAll('.hhFinButce').forEach(form=>{
   const amount=form.querySelector('[name=tutar]'),out=form.querySelector('.hhFinTahmin');
   const calc=()=>{
    const val=Number(amount.value||0),base=Math.max(1,Number(d.baslatma_bedeli||50000)),protesto=Math.max(1,Number(form.dataset.protesto));
    const effect=Math.min(40,12*Math.log(1+Math.max(0,val)/base))*(.75+.25*Math.min(1,Math.max(0,val)/protesto));
    const backlash=Math.min(12,Math.max(0,3*Math.log(1+Math.max(0,val)/base)-4));
    out.textContent='Tahmin: -'+fmt(effect)+' puan / 12 saat · ardından +'+fmt(backlash)+' puan kamuoyu tepkisi / 12 saat';
   };
   amount.addEventListener('input',calc);calc();
   form.addEventListener('submit',async ev=>{
    ev.preventDefault();
    const btn=form.querySelector('button'),val=Number(amount.value);
    if(!Number.isFinite(val)||val<Number(form.dataset.min)||val>Number(form.dataset.max))return toast('Geçersiz müdahale tutarı',true);
    btn.disabled=true;
    try{
     const result=await API.rpc('sokak_butce_mudahale',{p_eylem:Number(form.dataset.id),p_tutar:val,p_gerekce:String(new FormData(form).get('gerekce'))});
     toast('Kamu bütçesinden '+money(result?.bedel)+' harcandı. Etki -'+fmt(result?.etki)+' puan.');
     await sokakHareketleriEkrani();
    }catch(err){toast(hataCevir(err.message||String(err)),true);btn.disabled=false;}
   });
  });
 };
})();
