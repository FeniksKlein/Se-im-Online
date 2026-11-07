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

// Eylem formlarının altındaki bildiri kartları telefon ekranında taşmaz.
if(!document.getElementById('hh-kapsamli-bildiri-css')){
 const s=document.createElement('style');s.id='hh-kapsamli-bildiri-css';
 s.textContent=`
 #hhOrgUI .hhBildirOnizleme {margin:14px 0;background:#172140;border:1px solid #4c608d;border-radius:14px;padding:14px}
 #hhOrgUI .hhBildirOnizleme p {margin:7px 0;overflow-wrap:anywhere;white-space:pre-wrap}
 #hhOrgUI .hhDetayKart {margin:12px 0;padding:12px;background:#172140;border:1px solid #48577f;border-radius:12px}
 #hhOrgUI .hhDetayKart summary {cursor:pointer;padding:6px 0;line-height:1.5;overflow-wrap:anywhere}
 #hhOrgUI .hhDetayKart p {line-height:1.5;overflow-wrap:anywhere}
 #hhOrgUI .hhOrnekKonular {display:flex;flex-wrap:wrap;gap:8px}
 #hhOrgUI .hhOrnekKonular button {font-size:13px;max-width:100%;white-space:normal}
 #hhOrgUI #hhBildiriSayac {color:#c5cbed}
 `;
 document.head.appendChild(s);
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
 // Bildirili eylemler için eklenen ayrı, kalıcı ve herkese açık eylem bilgileri.
 let hhDetaylar=[];
 try{const kayitlar=await API.rpc('sokak_eylem_detay_panel');if(Array.isArray(kayitlar))hhDetaylar=kayitlar;}
 catch(ex){console.warn('Eylem bildiri paneli',ex);}

 const active=x=>d.aktif&&x.durum==='aktif'&&Date.parse(x.bitis)>Date.now();
 const createOptions=sources.map(o=>'<option value="'+esc(o.tur)+':'+Number(o.id)+'">'+esc(o.tur==='parti'?'Parti':'Dernek')+' · '+esc(o.ad)+'</option>').join('');
 const targetOptions=targets.map(o=>'<option value="'+esc(o.tur)+':'+Number(o.id)+'">'+esc(o.tur==='parti'?'Parti':'Dernek')+' · '+esc(o.ad)+'</option>').join('');
 let html='<div class="kart" id="hhOrgVersion"><h2>📢 Her parti ve dernek eylem başlatabilir</h2>'+
  '<p>Parti genel başkanları ve dernek başkanları, kendi kuruluşları adına eylem açabilir. İlde aktif oyuncu sayısı ve memnuniyetsizlik ön şartı yoktur. Eylem başladıktan sonra diğer parti ve dernekler davet edilebilir; daveti kabul eden kuruluş para yatırmadan ortak destekçi olur.</p>'+
  '<p><small>Hesabın en az 7 günlük olmalı. Kuruluş kasasından '+trNum(d.ayar?.baslatma_bedeli)+' TL alınır. İl, kuruluş ve ülke çapındaki bekleme/sayı sınırları devam eder.</small></p></div>';
 if(d.aktif&&sources.length){
  html+='<div class="kart"><h3>📢 Yeni halk hareketi düzenle</h3>'+
   '<p>Bir eylemin adı, dayandığı somut olay, muhatabı, talepleri ve halka yayımlanacak resmi bildirisi açıkça belirtilir. Tüm bilgiler eylemin kaydında kalır.</p>'+
   '<form id="hhOrgCreate">'+
   '<label>Eylemi düzenleyen parti veya dernek</label><select name="kaynak" required>'+createOptions+'</select>'+
   '<label>Eylemin düzenleneceği il</label><select name="il" required>'+(d.iller||[]).map(i=>'<option value="'+Number(i.id)+'">'+esc(i.ad)+'</option>').join('')+'</select>'+
   '<label>Eylemin başlığı</label><input name="baslik" minlength="8" maxlength="90" required placeholder="Örn. Hayat Pahalılığına Karşı Halk Buluşması">'+
   '<label>Eylemin başlatılma sebebi</label><select name="sebep" required>'+
   ['Ekonomik kriz','Zam ve vergiler','Enflasyon ve hayat pahalılığı','İşsizlik ve istihdam','Hükümet kararı','Bakan atanmaması','Hak ve özgürlükler','Adalet ve yargı','Yolsuzluk iddiaları','Belediye hizmetleri','Çevre ve doğa','Eğitim ve sağlık','Demokrasi ve seçimler','Diğer toplumsal mesele'].map(v=>'<option>'+esc(v)+'</option>').join('')+'</select>'+
   '<label>Eylemin muhatabı / taleplerin yöneltildiği makam</label><select name="muhatap" required>'+
   ['Cumhurbaşkanlığı','Hükümet','İçişleri Bakanlığı','İlgili Bakanlık','TBMM','Belediye','Kamu Kurumu','İşverenler','Kamuoyu'].map(v=>'<option>'+esc(v)+'</option>').join('')+'</select>'+
   '<label>Hangi karar veya olay eyleme sebep oldu?</label><textarea name="olay" minlength="12" maxlength="200" required placeholder="Somut karar, zam, atama, ekonomik gelişme veya yaşanan olayı açıkla."></textarea>'+
   '<label>Hükümetten / muhataptan somut talepler</label><textarea name="talepler" minlength="20" maxlength="500" required placeholder="Örn. Zam kararının geri alınması, yeni bir çözüm takvimi açıklanması, kamuoyuna hesap verilmesi."></textarea>'+
   '<label>Oyun içi talep ve etkisi</label><select name="tur"><option value="genel">Genel siyasi / toplumsal talep</option><option value="hizmet">İl hizmet memnuniyeti +5</option><option value="issizlik">İşsizlik −0,5</option><option value="vergi">Vergi −1</option></select>'+
   '<label>Eylem sloganı (isteğe bağlı)</label><input name="slogan" maxlength="90" placeholder="Örn. Geçim İçin, Adalet İçin!">'+
   '<label>Halka açıklanacak eylem bildirisi</label><textarea name="bildiri" minlength="60" maxlength="600" required placeholder="Kuruluşumuz adına halkımıza sesleniyoruz... Neden toplandığımızı ve taleplerimizi açıklayın."></textarea>'+
   '<small id="hhBildiriSayac">0 / 600 karakter · Bildiri kamuoyuna yayımlanır.</small>'+
   '<div class="kart hhBildirOnizleme" aria-live="polite"><b>📰 Kamuoyuna duyuru önizlemesi</b><div id="hhBildiriOnizleme"><p>Başlık, sebep, talepler ve bildiri yazdıkça burada görünecek.</p></div></div>'+
   '<button type="submit" class="btn altin">Kuruluş kasasından '+trNum(d.ayar?.baslatma_bedeli)+' TL öde, eylemi ve bildiriyi yayımla</button></form>'+
   '<details><summary><b>💡 Eylem konusu için örnek taslaklar</b></summary>'+
   '<p>Hazır taslaklar sadece örnektir. Oyundaki gerçek karara veya olaya göre değiştirmelisin.</p>'+
   '<div class="hhOrnekKonular"><button type="button" class="btn" data-hh-ornek="zam">Zam ve vergi</button> '+
   '<button type="button" class="btn" data-hh-ornek="bakan">Eksik kabine</button> '+
   '<button type="button" class="btn" data-hh-ornek="issizlik">İşsizlik</button> '+
   '<button type="button" class="btn" data-hh-ornek="belediye">Belediye hizmetleri</button> '+
   '<button type="button" class="btn" data-hh-ornek="adalet">Adalet talebi</button></div></details></div>';

 }
 // Bildiri ve talepler yalnızca oluşturanın değil, diğer partilerin ve oyuncuların da görebileceği açıklıklardır.
 if(hhDetaylar.length){
  html+='<div class="kart"><h3>📰 Eylem bildirileri, gerekçeleri ve talepler</h3>'+
   '<p>Kuruluşların yayımladığı bildirileri okuyabilir, hangi soruna tepki verdiklerini ve ne istediklerini görebilirsin.</p>';
  for(const x of hhDetaylar.slice(0,15)){
   html+='<details class="hhDetayKart"><summary><b>'+esc(x.baslik)+'</b></summary>'+
    '<p><b>Başlatma sebebi:</b> '+esc(x.sebep)+'</p>'+
    '<p><b>Muhatap:</b> '+esc(x.muhatap)+'</p>'+
    '<p><b>Dayanak olan karar / olay:</b> '+esc(x.olay)+'</p>'+
    '<p><b>Somut talepler:</b> '+esc(x.talepler).replaceAll('\\n','<br>')+'</p>'+
    (x.slogan?'<p><b>Slogan:</b> “'+esc(x.slogan)+'”</p>':'')+
    '<div class="kart"><b>📜 Resmî eylem bildirisi</b><p>'+esc(x.bildiri).replaceAll('\\n','<br>')+'</p></div></details>';
  }
  html+='</div>';
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
 const ornekler={
  zam:{baslik:'Zam ve Vergi Kararlarına Karşı Halk Buluşması',sebep:'Zam ve vergiler',muhatap:'Hükümet',olay:'Oyun içinde duyurulan zam ve vergi artışlarının hane bütçeleri üzerindeki etkilerine itiraz ediyoruz.',talepler:'Zam kararlarının yeniden değerlendirilmesini, geçim yükünün hafifletilmesini ve kamuoyuna açıklama yapılmasını talep ediyoruz.',slogan:'Geçim İçin Birlikteyiz!',bildiri:'Kamuoyuna duyurulur: Alınan zam ve vergi kararları halkın geçimini zorlaştırmaktadır. Barışçıl gösterimizle kararların gözden geçirilmesini, çözüm takvimi açıklanmasını ve vatandaşların sesinin duyulmasını istiyoruz.'},
  bakan:{baslik:'Kabine Atamaları ve Yönetim Sorumluluğu Eylemi',sebep:'Bakan atanmaması',muhatap:'Cumhurbaşkanlığı',olay:'Oyun yönetimindeki boş bakanlıkların kamu hizmetlerinde belirsizlik yaratmasına dikkat çekiyoruz.',talepler:'Boş bakanlıklara atama yapılmasını, görev dağılımının açıklanmasını ve hizmetlerin aksatılmamasını talep ediyoruz.',slogan:'Yönetimde Belirsizliğe Son!',bildiri:'Halkımıza saygıyla duyuruyoruz: Kamu yönetimindeki boş makamların ve belirsizliğin giderilmesini istiyoruz. Barışçıl eylemimiz, sorumlu makamlardan atama takvimi ve şeffaf bilgilendirme beklemektedir.'},
  issizlik:{baslik:'İş ve Geçim Hakkı İçin Dayanışma Eylemi',sebep:'İşsizlik ve istihdam',muhatap:'İlgili Bakanlık',olay:'Oyun ekonomisinde istihdam olanaklarının yetersizliğine ve işsizlik riskine tepki gösteriyoruz.',talepler:'İstihdamı artıracak tedbirlerin açıklanmasını, yeni iş alanları oluşturulmasını ve ekonomik destek planı hazırlanmasını istiyoruz.',slogan:'İş, Emek, Güvence!',bildiri:'Emek ve geçim mücadelesi için bir araya geliyoruz. İşsizliği azaltacak gerçekçi adımlar, şeffaf ekonomik hedefler ve çalışanların haklarını koruyacak çözümler talep ediyoruz. Eylemimiz barışçıldır.'},
  belediye:{baslik:'Yaşanabilir Kent ve Hizmet Hakkı Buluşması',sebep:'Belediye hizmetleri',muhatap:'Belediye',olay:'Oyun ilindeki belediye hizmetlerinin aksaması ve vatandaş beklentilerinin karşılanamamasına itiraz ediyoruz.',talepler:'Hizmetlerin iyileştirilmesini, harcama planının açıklanmasını ve eksik hizmetler için somut bir takvim hazırlanmasını istiyoruz.',slogan:'Kent Bizim, Söz Bizim!',bildiri:'Kent sakinleri olarak daha düzenli ve ulaşılabilir belediye hizmetleri istiyoruz. Belediye yönetimini şeffaf açıklama yapmaya, aksayan hizmetleri gidermeye ve çözüm takvimini halkla paylaşmaya çağırıyoruz.'},
  adalet:{baslik:'Hukukun Üstünlüğü ve Adalet İçin Buluşma',sebep:'Adalet ve yargı',muhatap:'Kamu Kurumu',olay:'Oyun içindeki bir kamu veya yargı kararının adalet ve şeffaflık bakımından tartışma yaratmasına itiraz ediyoruz.',talepler:'Kararların gerekçelerinin açıklanmasını, tarafsız inceleme yapılmasını ve hukuka uygun çözüm üretilmesini talep ediyoruz.',slogan:'Herkes İçin Adalet!',bildiri:'Adalet ve hukuk güvenliği bütün oyuncular için gereklidir. Barışçıl eylemimizle tartışmalı kararların gerekçelendirilmesini, bağımsız denetimi ve hak arama yollarının açık tutulmasını talep ediyoruz.'}
 };
 if(form){
  const preview=form.querySelector('#hhBildiriOnizleme'),counter=form.querySelector('#hhBildiriSayac');
  const update=()=>{
   const a=new FormData(form),val=k=>String(a.get(k)||'').trim();
   const parts=[
    ['Başlık',val('baslik')],['Sebep',val('sebep')],['Muhatap',val('muhatap')],
    ['Dayanak olan olay',val('olay')],['Talepler',val('talepler')],
    ['Slogan',val('slogan')],['Resmî bildiri',val('bildiri')]
   ];
   preview.innerHTML=parts.map(([ad,v])=>'<p><b>'+esc(ad)+':</b> '+esc(v||'Henüz girilmedi').replaceAll('\\n','<br>')+'</p>').join('');
   counter.textContent=val('bildiri').length+' / 600 karakter · Bildiri kamuoyuna yayımlanır.';
  };
  form.addEventListener('input',update);
  form.addEventListener('change',update);
  document.querySelectorAll('[data-hh-ornek]').forEach(btn=>btn.addEventListener('click',()=>{
   const t=ornekler[btn.dataset.hhOrnek];if(!t)return;
   Object.entries(t).forEach(([k,v])=>{const field=form.elements.namedItem(k);if(field)field.value=v;});
   update();form.querySelector('[name=baslik]')?.scrollIntoView({behavior:'smooth',block:'center'});
  }));
  update();
  form.addEventListener('submit',ev=>{
   ev.preventDefault();
   if(!form.reportValidity())return;
   const a=new FormData(form),[tur,id]=String(a.get('kaynak')).split(':');
   const val=k=>String(a.get(k)||'').trim();
   send(form.querySelector('button[type=submit]'),'sokak_org_baslat_kapsamli',{
    p_il:Number(a.get('il')),p_tur:val('tur'),p_kaynak:tur,p_kaynak_id:Number(id),
    p_baslik:val('baslik'),p_sebep:val('sebep'),p_muhatap:val('muhatap'),
    p_olay:val('olay'),p_talepler:val('talepler'),p_slogan:val('slogan'),p_bildiri:val('bildiri')
   });
  });
 }
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
