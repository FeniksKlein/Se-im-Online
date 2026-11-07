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


/* 2026-11-07 · HALK HAREKETLERI KOMUTA MERKEZI · okunurluk ve tum roller */
(function(){
'use strict';
if(typeof sokakHareketleriEkrani!=='function' || typeof iskelet!=='function')return;
var cssId='so-hh-command-style-v3';
if(!document.getElementById(cssId)){
 var st=document.createElement('style');st.id=cssId;
 st.textContent=[
 'body.so-hh-page{--hh-bg:#101831;--hh-panel:#192340;--hh-line:#43547d;--hh-text:#f4f7ff;--hh-muted:#c5cfe7;color:var(--hh-text)}',
 'body.so-hh-page :is(.kart,details,section,form){min-width:0;box-sizing:border-box;overflow-wrap:anywhere}',
 'body.so-hh-page .kart form{display:flex!important;flex-direction:column!important;gap:10px!important;align-items:stretch!important}',
 'body.so-hh-page .kart form>label{display:block!important;color:#ecf1ff!important;font-size:15px!important;font-weight:650!important;line-height:1.5!important;white-space:normal!important;margin:6px 0 0!important;max-width:100%!important}',
 'body.so-hh-page :is(select,input:not([type=checkbox]):not([type=radio]),textarea){display:block!important;position:static!important;box-sizing:border-box!important;width:100%!important;max-width:100%!important;min-width:0!important;min-height:48px!important;margin:0!important;padding:12px 14px!important;font:500 16px/1.4 -apple-system,BlinkMacSystemFont,system-ui,sans-serif!important;letter-spacing:normal!important;opacity:1!important;color:#f6f8ff!important;-webkit-text-fill-color:#f6f8ff!important;background:#111c37!important;border:1px solid #7789b4!important;border-radius:12px!important;box-shadow:none!important;text-align:left!important}',
 'body.so-hh-page :is(select,input,textarea)::placeholder{color:#b9c5df!important;-webkit-text-fill-color:#b9c5df!important;opacity:1!important}',
 'body.so-hh-page select{color-scheme:dark!important;-webkit-appearance:menulist!important;appearance:menulist!important;white-space:nowrap!important;text-overflow:ellipsis!important}',
 'body.so-hh-page select option{background:#17223c!important;color:#fff!important;-webkit-text-fill-color:#fff!important}',
 'body.so-hh-page textarea{height:auto!important;min-height:100px!important;resize:vertical!important;white-space:pre-wrap!important}',
 'body.so-hh-page form button{width:100%!important;min-height:48px!important;white-space:normal!important;line-height:1.35!important;padding:12px 14px!important;overflow-wrap:anywhere!important}',
 'body.so-hh-page :is(input,select,textarea,button):focus-visible{outline:3px solid #b8a5ff!important;outline-offset:2px!important}',
 '#hhCommand{font:400 15px/1.55 -apple-system,BlinkMacSystemFont,system-ui,sans-serif;color:#f4f7ff;min-width:0;display:block;width:100%;box-sizing:border-box;overflow-wrap:anywhere}',
 '#hhCommand *{box-sizing:border-box}',
 '#hhCommand h2{font-size:21px;line-height:1.25;margin:0 0 8px;color:#fff}',
 '#hhCommand h3{font-size:17px;line-height:1.3;margin:0 0 10px;color:#fff}',
 '#hhCommand p{margin:6px 0 12px;color:#d5ddf1;line-height:1.5}',
 '#hhCommand .hh-hero{border:1px solid #776adb;border-radius:20px;padding:22px 18px;background:linear-gradient(135deg,#272357,#17294c);margin:10px 0 15px}',
 '#hhCommand .hh-kickers{font-size:12px;letter-spacing:1.4px;text-transform:uppercase;color:#c7bbff;font-weight:800}',
 '#hhCommand .hh-stats{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-top:14px}',
 '#hhCommand .hh-stat{background:rgba(5,13,38,.42);padding:13px;border-radius:13px;border:1px solid #41466f}',
 '#hhCommand .hh-stat strong{display:block;color:#fff;font-size:22px;line-height:1.25}',
 '#hhCommand .hh-stat span{color:#d4daf3;font-size:12px}',
 '#hhCommand .hh-tabs{display:flex;gap:8px;overflow-x:auto;padding:2px 0 12px;scrollbar-width:thin;scroll-snap-type:x proximity}',
 '#hhCommand .hh-tab{flex:0 0 auto!important;width:auto!important;min-height:43px!important;padding:10px 12px!important;font-size:14px!important;background:#222c4e!important;color:#d8e0f4!important;border:1px solid #4b5a80!important;border-radius:12px!important;scroll-snap-align:start}',
 '#hhCommand .hh-tab[aria-selected=true]{background:#7867ed!important;color:white!important;border-color:#b0a5ff!important;font-weight:750!important}',
 '#hhCommand [data-hh-panel][hidden]{display:none!important}',
 '#hhCommand .hh-box{background:#192340;border:1px solid #3e4b70;border-radius:17px;padding:17px 15px;margin-bottom:12px;min-width:0}',
 '#hhCommand .hh-box.hh-event{border-left:4px solid #927cf8}',
 '#hhCommand .hh-pill{display:inline-block;padding:4px 10px;border-radius:99px;background:#344269;color:#f4f6ff;font-size:12px;font-weight:750;margin:0 6px 8px 0}',
 '#hhCommand .hh-pill.live{background:#29463f;color:#c8f7e8}',
 '#hhCommand .hh-pill.warn{background:#4a3c25;color:#ffe2a0}',
 '#hhCommand .hh-actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;margin:12px 0}',
 '#hhCommand button.hh-action{margin:0!important;min-height:46px!important;width:100%!important;background:#303b61!important;color:#fff!important;border:1px solid #61709a!important;border-radius:12px!important;padding:10px 8px!important;font-weight:700!important;white-space:normal!important}',
 '#hhCommand button.hh-primary{background:#7967ed!important;border-color:#a898ff!important;color:#fff!important}',
 '#hhCommand button.hh-danger{background:#4e2935!important;border-color:#e095a5!important}',
 '#hhCommand .hh-detail{margin:11px 0;border:1px solid #435274;border-radius:12px;padding:10px 12px;background:rgba(7,12,32,.26)}',
 '#hhCommand .hh-detail>summary{cursor:pointer;color:#eeeaff;font-weight:750;font-size:15px;line-height:1.5}',
 '#hhCommand .hh-detail[open]{padding-bottom:15px}',
 '#hhCommand .hh-detail form{margin-top:12px!important}',
 '#hhCommand .hh-muted{font-size:13px;color:#c7d0e4!important}',
 '#hhCommand .hh-meter{height:12px;background:#0c1430;border-radius:15px;overflow:hidden;margin:10px 0}',
 '#hhCommand .hh-meter>i{display:block;height:100%;background:linear-gradient(90deg,#74a7fb,#efb24b,#ef676e);border-radius:15px}',
 '#hhCommand .hh-log{border-left:2px solid #626dab;padding:8px 12px;margin:8px 0;color:#d8e0f2;font-size:13px}',
 '#hhCommand .hh-empty{padding:20px;text-align:center;border:1px dashed #64739c;border-radius:14px;color:#dbe1f5}',
 '#hhCommand .hh-divider{border:0;border-top:1px solid #4b5979;margin:16px 0}',
 '#hhCommand .hh-box button:disabled{opacity:.55!important}',
 '@media(max-width:390px){#hhCommand .hh-actions{grid-template-columns:1fr}#hhCommand .hh-stats{grid-template-columns:repeat(2,minmax(0,1fr))}}'
 ].join('\n');document.head.appendChild(st);
}
const oldIskelet=iskelet;
iskelet=function(title,body,options){
 document.body.classList.toggle('so-hh-page',title==='Halk Hareketleri');
 return oldIskelet(title,body,options);
};
const former=sokakHareketleriEkrani;
sokakHareketleriEkrani=async function(){
 await former();
 document.body.classList.add('so-hh-page');
 const anchor=document.getElementById('hhOrgAnchor')||document.getElementById('so-v2');
 if(!anchor)return;
 let d;
 try{d=await API.rpc('sokak_merkez_panel');}
 catch(err){console.warn('Halk Hareketleri merkez paneli',err);return;}
 document.getElementById('hhCommand')?.remove();
 const esc=x=>e(String(x??''));
 const num=x=>Number(x||0).toLocaleString('tr-TR',{maximumFractionDigits:1});
 const tl=x=>num(x)+' TL';
 const dt=x=>x?new Date(x).toLocaleString('tr-TR'):'—';
 const now=Date.now();
 const alive=x=>x.durum==='aktif'&&Date.parse(x.bitis)>now;
 const events=d.eylemler||[], live=events.filter(alive);
 const legal=events.flatMap(x=>(x.gozaltilar||[]).map(g=>({event:x,info:g})));
 const pending=legal.filter(x=>x.info.durum==='aktif'&&Date.parse(x.info.bitis)>now);
 const invitations=d.davetler||[];
 const sources=d.kaynaklar||[];
 const opts=(items,getVal,getText)=>items.map(x=>'<option value="'+esc(getVal(x))+'">'+esc(getText(x))+'</option>').join('');
 const parts=(d.davet_hedefleri||[]);
 const members=(d.baro_avukatlar||[]);
 const link=(key,title)=>'<button type="button" class="hh-tab" data-hh-tab="'+key+'" role="tab" aria-selected="false">'+title+'</button>';
 let html='<section id="hhCommand" aria-label="Halk Hareketleri komuta merkezi">'+
 '<div class="hh-hero"><div class="hh-kickers">SEÇİM ONLINE / HALK HAREKETLERİ</div>'+
 '<h2>📣 Halk Hareketleri Merkezi</h2><p>Eylemleri başlat, örgütleri birleştir, destek topla, hükümetle müzakere et ve hukuki süreçleri yönet.</p>'+
 '<div class="hh-stats"><div class="hh-stat"><strong>'+live.length+'</strong><span>Aktif eylem</span></div>'+
 '<div class="hh-stat"><strong>'+invitations.length+'</strong><span>Yanıt bekleyen davet</span></div>'+
 '<div class="hh-stat"><strong>'+num(live.reduce((s,x)=>s+Number(x.katilim||0),0))+'</strong><span>Katılım kaydı</span></div>'+
 '<div class="hh-stat"><strong>'+pending.length+'</strong><span>Aktif gözaltı</span></div></div></div>'+
 '<nav class="hh-tabs" role="tablist" aria-label="Eylem yönetimi">'+link('events','🔥 Eylemler')+link('create','✊ Yeni eylem')+link('invite','🤝 Davetler')+link('legal','⚖️ Hukuk')+link('state','🏛️ Hükümet')+link('history','📰 Geçmiş')+'</nav>';
 const pan=(name,content)=>'<div data-hh-panel="'+name+'" role="tabpanel" hidden>'+content+'</div>';
 let evhtml='<div class="hh-box"><h3>Canlı eylem haritası</h3><p>Parti ve dernek desteği ayrı; her oyuncu kendi adına, parti üyeliğinden bağımsız olarak da katılabilir. Fiziki katılım için mevcut il ve ikamet koşulları geçerlidir.</p></div>';
 if(!live.length)evhtml+='<div class="hh-empty">Şu anda aktif eylem yok. Yeni Eylem bölümünden bir hareket başlatılabilir.</div>';
 for(const x of live){
  const id=Number(x.id), pct=Math.max(0,Math.min(100,Number(x.seviye||0)));
  evhtml+='<article class="hh-box hh-event"><div><span class="hh-pill live">● AKTİF</span><span class="hh-pill">'+esc(x.il)+'</span><span class="hh-pill">#'+id+'</span></div>'+
   '<h3>'+esc(x.parti||'Bağımsız eylem')+'</h3><p>'+esc(x.gerekce)+'</p>'+
   '<div class="hh-meter" aria-label="Eylem gücü '+num(x.seviye)+' / 100"><i style="width:'+pct+'%"></i></div>'+
   '<p><strong>Güç: '+num(x.seviye)+'/100</strong> · '+num(x.katilim)+' katılımcı</p>'+
   '<p class="hh-muted">Eylem fonu: <b>'+tl(x.muhalefet_fonu)+'</b> · Hükümet uzlaşma fonu: <b>'+tl(x.iktidar_fonu)+'</b><br>Bitiş: '+esc(dt(x.bitis))+'</p>'+
   (x.katildim?'<span class="hh-pill live">✓ Katılıyorsun</span>':
      '<button type="button" class="hh-action hh-primary" data-hh-join="'+id+'">🙋 Eyleme bireysel katıl</button>')+
   '<details class="hh-detail"><summary>💰 Eylemi fonla ve güçlendir</summary>'+
   '<form data-hh-fn="sokak_destek" data-hh-id="'+id+'"><label>Para kaynağı</label><select name="p_kaynak" required>'+
   opts(sources,x=>x.tur,x=>x.ad)+'</select><label>Kaynak (parti / dernek seçimi)</label>'+
   '<select name="kaynak_id">'+opts(sources.filter(y=>y.id),x=>x.tur+':'+x.id,x=>x.ad)+'</select>'+
   '<label>Fon tutarı (TL, en az 1.000)</label><input name="p_tutar" type="number" min="1000" step="1000" required placeholder="Örn. 10000">'+
   '<button class="hh-action hh-primary">Eyleme fon gönder</button></form></details>';
  if(x.ben_baslattim){
   evhtml+='<details class="hh-detail"><summary>📨 Başka parti ve dernekleri davet et</summary>'+
    '<p>Kuruluş lideri kabul, ret veya çekimser yanıtı verebilir. Kabul sonrası üyeler kendi istekleriyle katılır.</p>'+
    '<form data-hh-fn="sokak_davet_gonder" data-hh-id="'+id+'"><label>Davet edilecek kuruluş</label>'+
    '<select name="hedef" required>'+opts(parts,x=>x.tur+':'+x.id,x=>(x.tur==='parti'?'🏳️ Parti · ':'🏛️ Dernek · ')+x.ad)+'</select>'+
    '<button class="hh-action hh-primary">Destek daveti gönder</button></form>'+
    ((x.davet_ozeti||[]).length?'<h3>Davet yanıtları</h3>'+x.davet_ozeti.map(y=>'<div class="hh-log">'+esc(y.kurulus)+' · <b>'+esc(y.durum)+'</b></div>').join(''):'')+'</details>'+
    '<details class="hh-detail"><summary>🛑 Eylemi sonlandır</summary><p>Sonlandırma kalıcıdır; geri açılmaz. Fon iadeleri otomatik yapılmaz.</p>'+
    '<form data-hh-fn="sokak_eylem_sonlandir" data-hh-id="'+id+'"><label>Sonlandırma gerekçesi</label>'+
    '<textarea name="p_gerekce" minlength="15" maxlength="500" required placeholder="Talepler karşılandı, strateji değişikliği, uzlaşma..."></textarea>'+
    '<button class="hh-action hh-danger">Eylemi bitir ve duyur</button></form></details>';
  }
  evhtml+='<details class="hh-detail"><summary>🎙️ Basın açıklaması yap</summary>'+
   '<form data-hh-fn="sokak_basina_aciklama" data-hh-id="'+id+'"><label>Açıklama sıfatı</label><select name="p_taraf">'+
   '<option value="basin">Oyuncu / basın</option><option value="muhalefet">Eylem destekçisi</option><option value="hukuk">Avukat</option>'+
   (d.mudahale_yetki?'<option value="hukumet">Hükümet</option>':'')+'</select>'+
   '<label>Halka açık açıklaman</label><textarea name="p_metin" minlength="30" maxlength="600" required></textarea>'+
   '<button class="hh-action">Açıklamayı yayımla</button></form></details></article>';
 }
 html+=pan('events',evhtml);
 let create='<div class="hh-box"><h3>Yeni hareket başlat</h3><p>Parti veya dernek lideri eylem açabilir. Memnuniyetsizlik ve asgari katılımcı şartı kaldırılmıştır; diğer mevcut oyun süre/bütçe limitleri geçerlidir.</p></div>';
 if((d.baslatma_kaynaklari||[]).length){
  create+='<div class="hh-box"><form data-hh-fn="sokak_org_baslat_bildirili"><label>Eylemi düzenleyen</label><select name="kaynak" required>'+
  opts(d.baslatma_kaynaklari,x=>x.tur+':'+x.id,x=>x.ad)+'</select>'+
  '<label>Eylem yapılacak il</label><select name="p_il" required>'+opts(d.iller||[],x=>x.id,x=>x.ad)+'</select>'+
  '<label>Somut talep</label><select name="p_tur"><option value="genel">Siyasi/toplumsal düzenleme</option><option value="hizmet">Belediye hizmetleri iyileşsin</option><option value="issizlik">İşsizlik azalsın</option><option value="vergi">Vergi indirilsin</option></select>'+
  '<label>Eylemin gerekçesi</label><textarea name="p_gerekce" minlength="15" maxlength="400" required placeholder="Eylem hangi olaya ya da karara tepki?"></textarea>'+
  '<label>Halka açık eylem bildirisi</label><textarea name="p_bildiri" minlength="30" maxlength="600" required placeholder="Taleplerimizi açıklıyor, tüm oyuncuları barışçıl eyleme çağırıyoruz..."></textarea>'+
  '<p class="hh-muted">Kuruluş kasasından '+tl(d.ayar?.baslatma_bedeli)+' alınır; eylem ve bildiri tek işlemde yayınlanır.</p>'+
  '<button class="hh-action hh-primary">🚩 Eylemi başlat ve bildiriyi yayımla</button></form></div>';
 }else create+='<div class="hh-empty">Eylem başlatmak için açık bir parti veya derneğin lideri olman gerekiyor.</div>';
 html+=pan('create',create);
 let invites='<div class="hh-box"><h3>Destek çağrıları</h3><p>Davet edilen parti/dernek yalnızca liderin kararıyla kurumsal destek verir. Üyeler otomatik katılmaz; bireysel katılım ayrıca seçilir.</p></div>';
 for(const inv of invitations)invites+='<div class="hh-box"><span class="hh-pill warn">YANIT BEKLİYOR</span><h3>'+esc(inv.kurulus)+' · '+esc(inv.il)+'</h3>'+
 '<p>'+esc(inv.eylem)+'</p><div class="hh-actions"><button class="hh-action hh-primary" data-hh-invite="'+Number(inv.id)+'" data-hh-choice="kabul">✓ Kabul et</button>'+
 '<button class="hh-action" data-hh-invite="'+Number(inv.id)+'" data-hh-choice="ret">✕ Reddet</button>'+
 '<button class="hh-action" data-hh-invite="'+Number(inv.id)+'" data-hh-choice="cekimser">◌ Çekimser kal</button></div></div>';
 if(!invitations.length)invites+='<div class="hh-empty">Liderliğini yaptığın kuruluşlara gelen açık davet yok.</div>';
 html+=pan('invite',invites);
 let law='<div class="hh-box"><h3>Gözaltı, savunma ve yargı</h3><p>Gözaltındaki oyuncu avukat isteyebilir veya baroya başvurabilir. Baro görevlendirir, avukat kabul eder, oyuncu/avukatı itiraz eder ve bağımsız hâkim gerekçeli karar verir. Gözaltı ile mahkûmiyet aynı şey değildir.</p></div>';
 for(const item of legal){
  const g=item.info,id=Number(g.id),isLive=g.durum==='aktif'&&Date.parse(g.bitis)>now;
  if(!isLive&&!g.benim&&!g.ben_avukat&&!g.mahkeme_yetki)continue;
  law+='<div class="hh-box"><span class="hh-pill '+(isLive?'warn':'')+'">'+esc(isLive?'GÖZALTINDA':g.durum)+'</span>'+
  '<h3>Dosya #'+id+' · '+esc(g.hedef)+'</h3><p class="hh-muted">Eylem #'+Number(item.event.id)+' · Bitiş '+esc(dt(g.bitis))+'</p>'+
  (g.avukat?'<p>Avukat: '+esc(g.avukat)+' · '+esc(g.avukat_durum)+'</p>':'')+
  (g.itiraz?'<div class="hh-log">Savunma / itiraz: '+esc(g.itiraz)+'</div>':'')+
  (g.karar?'<div class="hh-log">Mahkeme: '+esc(g.karar)+' · '+esc(g.karar_gerekce)+' · Tazminat: '+tl(g.tazminat)+'</div>':'');
  if(g.benim&&isLive){
   law+='<details class="hh-detail"><summary>👩‍⚖️ Avukat çağır</summary><form data-hh-fn="sokak_avukat_cagir" data-hh-id="'+id+'">'+
   '<label>Aktif ruhsatlı avukat</label><select name="p_avukat" required>'+
   opts(d.avukatlar||[],x=>x.id,x=>x.ad)+'</select><button class="hh-action">Avukat çağır</button></form></details>'+
   '<button class="hh-action hh-primary" data-hh-baro-request="'+id+'">⚖️ Barodan müdafi iste</button>';
  }
  if(g.ben_avukat&&g.avukat_durum==='cagrildi')law+='<div class="hh-actions"><button class="hh-action hh-primary" data-hh-law="'+id+'" data-hh-law-accept="1">Avukatlığı kabul et</button><button class="hh-action" data-hh-law="'+id+'" data-hh-law-accept="0">Reddet</button></div>';
  if(!g.itiraz&&(g.benim||(g.ben_avukat&&g.avukat_durum==='kabul'))&&Date.parse(g.baslangic)>now-86400000){
   law+='<details class="hh-detail"><summary>📝 Gözaltına itiraz et</summary><form data-hh-fn="sokak_gozalti_itiraz" data-hh-id="'+id+'">'+
   '<label>Savunma ve itiraz gerekçesi</label><textarea name="p_metin" minlength="20" maxlength="600" required></textarea>'+
   '<button class="hh-action hh-primary">İtiraz et, mahkemeye gönder</button></form></details>';
  }
  if(g.mahkeme_yetki&&g.itiraz&&!g.karar){
   law+='<details class="hh-detail"><summary>⚖️ Hâkim kararı ver</summary><form data-hh-fn="sokak_gozalti_mahkeme" data-hh-id="'+id+'">'+
   '<label>Gerekçeli karar türü</label><select name="p_karar"><option value="haksiz">Haksız gözaltı / tazminat</option><option value="uygun">Gözaltı hukuka uygun</option></select>'+
   '<label>Hâkim gerekçesi</label><textarea name="p_gerekce" minlength="25" maxlength="700" required></textarea>'+
   '<button class="hh-action hh-primary">Mahkeme kararını açıkla</button></form></details>';
  }
  if(g.benim&&Number(g.tazminat)>Number(g.tazminat_odendi))law+='<button class="hh-action" data-hh-comp="'+id+'">Tazminatı tahsil et ('+tl(Number(g.tazminat)-Number(g.tazminat_odendi))+')</button>';
  law+='</div>';
 }
 if(d.baro_baskani){
  law+='<div class="hh-box"><h3>🏛️ Baro müdafi atamaları</h3>';
  const reqs=(d.baro_talepleri||[]).filter(x=>x.durum==='bekliyor');
  if(!reqs.length)law+='<p>Bekleyen baro görevlendirme talebi yok.</p>';
  for(const y of reqs)law+='<form data-hh-fn="sokak_baro_ata" data-hh-id="'+Number(y.gozalti_id)+'">'+
   '<p><b>'+esc(y.hedef)+'</b> · Dosya #'+Number(y.gozalti_id)+' · '+esc(dt(y.basvuru))+'</p>'+
   '<label>Görevlendirilecek baro avukatı</label><select name="p_avukat" required>'+opts(members,x=>x.id,x=>x.ad)+'</select>'+
   '<button class="hh-action hh-primary">Baro adına müdafi görevlendir</button></form>';
  law+='</div>';
 }
 html+=pan('legal',law);
 let state='<div class="hh-box"><h3>Hükümet karşı hamleleri</h3><p>Uzlaşma, kamuoyu açıklaması ve bütçeli müdahaleler kamu kaynaklarına bağlıdır. Polis müdahalesi ve hukuki kararlar ayrı kaydedilir.</p></div>';
 if(d.mudahale_yetki)for(const x of live)state+='<div class="hh-box"><h3>'+esc(x.il)+' · '+esc(x.parti)+'</h3><p>Hükümet uzlaşma fonu: '+tl(x.iktidar_fonu)+'</p>'+
 '<form data-hh-fn="sokak_yanit" data-hh-id="'+Number(x.id)+'"><label>Hükümetin açıklaması ve çözüm önerisi</label><textarea name="p_metin" minlength="20" maxlength="600" required></textarea>'+
 '<button class="hh-action hh-primary">Hükümet yanıtını yayımla</button></form>'+
 '<details class="hh-detail"><summary>💼 Bütçeyle müdahale</summary><form data-hh-fn="sokak_butce_mudahale" data-hh-id="'+Number(x.id)+'">'+
 '<label>Harcama (TL)</label><input type="number" name="p_tutar" min="'+Number(d.ayar?.baslatma_bedeli||50000)+'" max="2000000" step="1000" required>'+
 '<label>Somut gerekçe</label><textarea name="p_gerekce" minlength="25" maxlength="500" required></textarea>'+
 '<button class="hh-action">Bütçeyi kullan</button></form></details>'+
 '<details class="hh-detail"><summary>🚓 Polis sevki ve gözaltı</summary><form data-hh-fn="sokak_polis_gonder" data-hh-id="'+Number(x.id)+'">'+
 '<label>Sevk seviyesi</label><select name="p_seviye"><option value="dusuk">Düşük – gözaltı yok</option><option value="orta">Orta – en çok 2 kişi</option><option value="yuksek">Yüksek – en çok 4 kişi</option></select>'+
 '<label>Kamu güvenliği gerekçesi</label><textarea name="p_gerekce" minlength="25" maxlength="500" required></textarea>'+
 '<button class="hh-action">Polis sevk et</button></form></details></div>';
 if(!d.mudahale_yetki)state+='<div class="hh-empty">Bu alanda işlem yapma yetkisi Cumhurbaşkanı ve İçişleri Bakanındadır. Eylemlerin durumunu Eylemler sekmesinden herkes görebilir.</div>';
 html+=pan('state',state);
 let history='<div class="hh-box"><h3>Geçmiş, kararlar ve basın</h3><p>Tüm işlemler kayıt altındadır. İlgili eylem sona erse de alınmış mahkeme kararları saklanır.</p></div>';
 for(const x of events){
  history+='<details class="hh-detail"><summary>#'+Number(x.id)+' · '+esc(x.il)+' · '+esc(x.parti)+' · '+esc(x.durum)+'</summary>'+
   '<p>'+esc(x.gerekce)+'</p>'+(x.kapanma_nedeni?'<p>Sonlandırma nedeni: '+esc(x.kapanma_nedeni)+'</p>':'')+
   '<p class="hh-muted">Başlangıç '+esc(dt(x.baslangic))+' · Bitiş '+esc(dt(x.bitis))+'</p>'+
   (x.davet_ozeti||[]).map(y=>'<div class="hh-log">Davet: '+esc(y.kurulus)+' · '+esc(y.durum)+'</div>').join('')+
   (x.aciklamalar||[]).map(y=>'<div class="hh-log"><b>'+esc(y.ad)+' / '+esc(y.taraf)+'</b> · '+esc(dt(y.zaman))+'<p>'+esc(y.metin)+'</p></div>').join('')+
   '</details>';
 }
 html+=pan('history',history)+'</section>';
 anchor.insertAdjacentHTML('afterbegin',html);
 const root=document.getElementById('hhCommand');
 // Eski coklu panelleri gizleyip tek komuta merkezinden yonet. Gereken eski islevler diger modullerde kalir.
 ['hhOrgUI','hhFinansUI','so-v2'].forEach(id=>{
  const old=document.getElementById(id);
  if(old&&old!==anchor&&!old.contains(root))old.style.display='none';
 });
 // Orijinal formlari gizle; ekran iskeletinin gezinme/baslik ogelerine dokunma.
 const tabs=[...root.querySelectorAll('[data-hh-tab]')];
 function show(key){
  tabs.forEach(b=>b.setAttribute('aria-selected',String(b.dataset.hhTab===key)));
  root.querySelectorAll('[data-hh-panel]').forEach(panel=>{panel.hidden=panel.dataset.hhPanel!==key;});
 }
 tabs.forEach(b=>b.addEventListener('click',()=>show(b.dataset.hhTab)));
 show(pending.some(z=>z.info.benim)?'legal':'events');
 async function run(btn,fn,args,success){
  if(btn)btn.disabled=true;
  try{
   await API.rpc(fn,args);
   toast(success||'İşlem kaydedildi');
   await sokakHareketleriEkrani();
  }catch(ex){toast(hataCevir(ex.message||String(ex)),true);if(btn)btn.disabled=false;}
 }
 root.querySelectorAll('[data-hh-join]').forEach(btn=>btn.addEventListener('click',()=>{
  run(btn,'sokak_destek',{p_eylem:Number(btn.dataset.hhJoin),p_taraf:'muhalefet',p_kaynak:'oyuncu',p_tutar:0},'Eyleme katıldın');
 }));
 root.querySelectorAll('[data-hh-invite]').forEach(btn=>btn.addEventListener('click',()=>{
  run(btn,'sokak_davet_karar',{p_davet:Number(btn.dataset.hhInvite),p_karar:btn.dataset.hhChoice},'Davet yanıtı kaydedildi');
 }));
 root.querySelectorAll('[data-hh-baro-request]').forEach(btn=>btn.addEventListener('click',()=>{
  run(btn,'sokak_baro_iste',{p_gozalti:Number(btn.dataset.hhBaroRequest)},'Baro avukatı talep edildi');
 }));
 root.querySelectorAll('[data-hh-law]').forEach(btn=>btn.addEventListener('click',()=>{
  run(btn,'sokak_avukat_cevap',{p_gozalti:Number(btn.dataset.hhLaw),p_kabul:btn.dataset.hhLawAccept==='1'});
 }));
 root.querySelectorAll('[data-hh-comp]').forEach(btn=>btn.addEventListener('click',()=>{
  run(btn,'sokak_gozalti_tazminat_tahsil',{p_gozalti:Number(btn.dataset.hhComp)});
 }));
 root.querySelectorAll('form[data-hh-fn]').forEach(form=>form.addEventListener('submit',ev=>{
  ev.preventDefault();
  const fn=form.dataset.hhFn, id=Number(form.dataset.hhId);
  const args=Object.fromEntries(new FormData(form).entries());
  if(fn==='sokak_org_baslat_bildirili'){
   const source=String(args.kaynak).split(':');delete args.kaynak;
   args.p_kaynak=source[0];args.p_kaynak_id=Number(source[1]);args.p_il=Number(args.p_il);
  }
  if(fn==='sokak_davet_gonder'){
   const dest=String(args.hedef).split(':');delete args.hedef;
   args.p_hedef_tur=dest[0];args.p_hedef_id=Number(dest[1]);args.p_eylem=id;
  }
  if(fn==='sokak_destek'){
   const source=String(args.p_kaynak||'oyuncu');
   const org=String(args.kaynak_id||'').split(':');delete args.kaynak_id;
   args.p_kaynak_id=source==='oyuncu'?null:Number(org[0]===source?org[1]:0);
   if(source!=='oyuncu'&&!args.p_kaynak_id)return toast('Parti/dernek para kaynağını doğru seç',true);
   args.p_tutar=Number(args.p_tutar);args.p_taraf='muhalefet';args.p_eylem=id;
  }
  if(['sokak_eylem_sonlandir','sokak_basina_aciklama','sokak_yanit','sokak_butce_mudahale','sokak_polis_gonder'].includes(fn))args.p_eylem=id;
  if(['sokak_avukat_cagir','sokak_gozalti_itiraz','sokak_gozalti_mahkeme','sokak_baro_ata'].includes(fn))args.p_gozalti=id;
  if(fn==='sokak_eylem_sonlandir'&&!window.confirm('Bu eylemi kesin olarak sonlandırmak istiyor musun?'))return;
  if(fn==='sokak_butce_mudahale')args.p_tutar=Number(args.p_tutar);
  run(form.querySelector('button'),fn,args);
 }));
};
})();

/* Deployment asset version: 20261107-4; source of truth for GitHub Pages. */

/* Asset refresh: 20261107-4b */
