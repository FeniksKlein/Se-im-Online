/* 08.11.2026 · Halk Hareketleri dayanıklılık katmanı
   Ekran, üst üste binen birkaç katmandan oluşur. Önceden herhangi bir katmandaki tek bir hata
   bütün ekranı "Sokak Eylemleri açılamadı" uyarısıyla düşürüyordu. Artık her katman ayrı korunur:
   biri çökerse diğerleri ve eylem işlemleri çalışmaya devam eder. Asıl teknik hata sunucuya
   (oyun.istemci_hata) yazılır; oyuncu yalnızca sade bir uyarı görür. */
(function(){
'use strict';
if(window.__hhSar)return;
let sonRapor=0;
function rapor(katman,err){
 try{
  console.error('Halk Hareketleri katmanı: '+katman,err);
  const simdi=Date.now();if(simdi-sonRapor<1500)return;sonRapor=simdi;
  const mesaj=String((err&&err.message)||err||'bilinmeyen hata');
  const yigin=String((err&&err.stack)||'');
  if(typeof API!=='undefined'&&API&&typeof API.rpc==='function')
   Promise.resolve(API.rpc('istemci_hata_kaydet',{p_ekran:'halk_hareketleri:'+katman,p_mesaj:mesaj,p_yigin:yigin,p_tarayici:String(navigator.userAgent||'')})).catch(function(){});
 }catch(_){}
}
function kabuk(){
 if(document.getElementById('hhOrgAnchor'))return;
 const govde='<div id="hhOrgAnchor"></div>';
 try{iskelet('Halk Hareketleri',govde,{geri:true});}catch(err){rapor('iskelet',err);}
 if(document.getElementById('hhOrgAnchor'))return;
 // Ekran iskeleti de çizilemediyse ana alana doğrudan sade bir sayfa koy.
 const alan=document.getElementById('icerik')||document.getElementById('app');
 if(!alan)return;
 alan.innerHTML='<div class="ust"><button class="geri" onclick="geriGit()" aria-label="Geri">‹</button><h1>Halk Hareketleri</h1></div><div style="padding:12px 16px 90px">'+govde+'</div>';
}
window.__hhSar=function(katman,fn){
 if(typeof fn!=='function'||fn.__hhKatman)return fn;
 const sarili=async function(){
  try{return await fn.apply(this,arguments);}
  catch(err){rapor(katman,err);kabuk();}
 };
 sarili.__hhKatman=katman;
 return sarili;
};
window.__hhRapor=rapor;
window.__hhKabuk=kabuk;
if(typeof sokakHareketleriEkrani==='function')sokakHareketleriEkrani=window.__hhSar('temel',sokakHareketleriEkrani);
})();

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
 // Partiler ekraninin eski / sade menulerinde kaybolan eylem girisini gorunur tut.
 if(baslik==='Partiler'&&!String(govde).includes('id="so-halk-quick-link"')){
  govde=`<div id="so-halk-quick-link" style="margin:12px 0 16px;position:relative;z-index:20;pointer-events:auto">
   <button type="button" data-so-halk-open="1" aria-label="Sokak Eylemleri ekranini ac"
    style="display:flex;align-items:center;gap:14px;width:100%;min-height:76px;text-align:left;padding:15px 17px;border:1px solid #ce9b65;border-radius:17px;color:#fff;background:linear-gradient(120deg,#51335c,#222d57);box-shadow:0 8px 22px #080e222e;cursor:pointer;position:relative;z-index:21;pointer-events:auto;touch-action:manipulation;-webkit-tap-highlight-color:transparent">
    <span aria-hidden="true" style="font-size:26px;line-height:1">📣</span>
    <span style="display:flex;flex:1;flex-direction:column;gap:4px;min-width:0">
     <strong style="font-size:17px;line-height:1.3;color:#fff">Sokak Eylemleri</strong>
     <small style="font-size:12px;line-height:1.4;color:#e3dbea">Eylem başlat · Katıl · Fonla · Yönet</small>
    </span>
    <span aria-hidden="true" style="font-size:26px;color:#f0bb78">›</span>
   </button></div>`+govde;
 }
 if(baslik==='Halk Hareketleri'&&!String(govde).includes('id="hhOrgAnchor"'))
  govde='<div id="hhOrgAnchor"></div>'+govde;
 return oldIskelet(baslik,govde,opt);
};
// Safari/WebView: Inline onclick kullanma; sayfa her cizildiginde degisen dugmeye
// sabit ve guvenli olay dinleyicisi ile gercek ekrani ac.
document.addEventListener('click',function(ev){
 const target=ev.target;
 if(!target||typeof target.closest!=='function')return;
 const btn=target.closest('#so-halk-quick-link button[data-so-halk-open]');
 if(!btn)return;
 ev.preventDefault();
 ev.stopPropagation();
 if(btn.disabled)return;
 btn.disabled=true;
 const fail=function(err){
  console.error('Sokak Eylemleri acilamadi',err);
  if(window.__hhRapor)window.__hhRapor('menu',err);
  if(window.__hhKabuk)window.__hhKabuk();
  if(!document.getElementById('hhCommand')&&typeof toast==='function')toast('Halk Hareketleri ekranı tam yüklenemedi. Sayfayı yenileyip tekrar dene.',true);
 };
 try{
  Promise.resolve(sokakHareketleriEkrani()).catch(fail).finally(function(){btn.disabled=false;});
 }catch(err){btn.disabled=false;fail(err);}
},true);
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
if(window.__hhSar&&typeof sokakHareketleriEkrani==='function')sokakHareketleriEkrani=window.__hhSar('org',sokakHareketleriEkrani);


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
    '<p><small>Para tek başına otomatik kırmızı eylem oluşturmaz; bunun için Türkiye genelinden en az 3 gerçek katılımcı gerekir. Müdahale gözaltı içermez, etkisi süre sonunda biter. Her harcama kayıtlara işlenir.</small></p></div>';
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
if(window.__hhSar&&typeof sokakHareketleriEkrani==='function')sokakHareketleriEkrani=window.__hhSar('finans',sokakHareketleriEkrani);


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
 '#hhCommand form{display:flex!important;flex-direction:column!important;align-items:stretch!important;gap:10px!important;min-width:0!important;width:100%!important;max-width:100%!important}',
 '#hhCommand form>label{display:block!important;width:100%!important;white-space:normal!important;color:#ecf1ff!important;font-size:15px!important;line-height:1.5!important;font-weight:700!important;margin:5px 0 0!important}',
 '#hhCommand form :is(input,select,textarea){display:block!important;width:100%!important;min-width:0!important;max-width:100%!important;position:static!important}',
 '#hhCommand :is(select,input,textarea,button):focus-visible{outline:3px solid #b8a5ff!important;outline-offset:2px!important}',
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
let lastCommandTab='events';
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
 '<nav class="hh-tabs" role="tablist" aria-label="Eylem yönetimi">'+link('events','🔥 Eylemler')+link('create','✊ Yeni eylem')+link('invite','🤝 Davetler')+link('legal','⚖️ Hukuk')+link('state','🏛️ Hükümet')+link('history','📰 Geçmiş')+link('tools','🧰 Diğer işlemler')+'</nav>';
 const pan=(name,content)=>'<div data-hh-panel="'+name+'" role="tabpanel" hidden>'+content+'</div>';
 let evhtml='<div class="hh-box"><h3>Canlı eylem haritası</h3><p>Parti ve dernek desteği ayrı; her oyuncu kendi adına, parti üyeliğinden bağımsız olarak da katılabilir. Katılım için eylemin ilinde yaşama şartı yoktur; Türkiye’nin 81 ilinden oyuncular katılabilir.</p><p><b>Eylemin gücü yalnız gerçek oyunculardan gelir:</b> katılımcılar ve taktikleri, tarafsız oyuncuların kamuoyu nabzı, karşı tarafta duranlar ve sahadaki görevliler. Para yalnız süreyi uzatır. İstediğin an eylemden ayrılabilirsin.</p></div>';
 if(!live.length)evhtml+='<div class="hh-empty">Şu anda aktif eylem yok. Yeni Eylem bölümünden bir hareket başlatılabilir.</div>';
 for(const x of live){
  const id=Number(x.id), pct=Math.max(0,Math.min(100,Number(x.seviye||0)));
  evhtml+='<article class="hh-box hh-event" data-hh-event="'+id+'"><div><span class="hh-pill live">● AKTİF</span><span class="hh-pill">'+esc(x.il)+'</span><span class="hh-pill">#'+id+'</span></div>'+
   '<h3>'+esc(x.parti||'Bağımsız eylem')+'</h3><p>'+esc(x.gerekce)+'</p>'+
   '<div class="hh-meter" aria-label="Eylem gücü '+num(x.seviye)+' / 100"><i style="width:'+pct+'%"></i></div>'+
   '<p><strong>Güç: '+num(x.seviye)+'/100</strong> · '+num(x.katilim)+' katılımcı</p>'+
   '<p class="hh-muted">Eylem fonu: <b>'+tl(x.muhalefet_fonu)+'</b> · Hükümet uzlaşma fonu: <b>'+tl(x.iktidar_fonu)+'</b><br>Bitiş: '+esc(dt(x.bitis))+'</p>'+
   (x.katildim?'<span class="hh-pill live">✓ Katılıyorsun · '+esc(x.katilim_sifatim||'Bağımsız')+'</span>':
      '<form data-hh-fn="sokak_katil_tercih" data-hh-id="'+id+'" class="hh-participate">'+
      '<label>Nasıl katılmak istiyorsun?</label><select name="katilim_sekli" required>'+
      '<option value="bagimsiz:">Bağımsız oyuncu olarak</option>'+
      opts((d.katilim_kuruluslari||[]).filter(y=>Number(y.eylem_id)===id),y=>y.tur+':'+y.id,y=>(y.tur==='parti'?'🏳️ Parti · ':'🏛️ Dernek · ')+y.ad)+
      '</select><button class="hh-action hh-primary">🙋 Eyleme katıl</button></form>')+
   '<details class="hh-detail"><summary>👥 Katılımcılar ve destekçiler ('+Number((x.destekler||[]).length)+')</summary>'+
   '<p class="hh-muted">Katılanların örgütlü veya bağımsız katılım biçimleri</p>'+
   (x.katilim_ayrintilari||[]).map(y=>'<div class="hh-log">'+esc(y.ad)+' · '+esc(y.sifat)+'</div>').join('')+
   ((x.destekler||[]).length?(x.destekler||[]).map(y=>'<div class="hh-log"><b>'+esc(y.ad||y.tur)+'</b> · '+esc(y.taraf==='iktidar'?'Uzlaşma':'Eylem')+' · '+tl(y.tutar)+'</div>').join(''):'<p>Henüz destekçi yok.</p>')+'</details>'+
   '<details class="hh-detail"><summary>💰 Eylemi fonla (süreyi uzatır)</summary><p class="hh-muted">Fon eylemin gücünü artırmaz; gücü yalnız gerçek katılımcılar belirler. Fon eylemin süresini uzatır.</p>'+
   '<form data-hh-fn="sokak_destek" data-hh-id="'+id+'"><label>Fon kaynağı: oyuncu / parti / dernek</label><select name="kaynak" required>'+
   opts(sources,x=>x.tur+':'+(x.id??''),x=>x.ad)+'</select>'+
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
  (g.on_inceleme?'<div class="hh-log">Hâkim ön incelemesi: <b>'+esc(g.on_inceleme==='serbest'?'Derhal serbest bırakıldı':'Mevcut gözaltı süresi onaylandı')+'</b><p>'+esc(g.on_inceleme_gerekce)+'</p></div>':'')+
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
  if(g.mahkeme_yetki&&isLive&&!g.on_inceleme&&!g.karar){
   law+='<details class="hh-detail"><summary>⚖️ Hâkim ön incelemesi – gözaltı kararı</summary><form data-hh-fn="sokak_gozalti_hakim_incele" data-hh-id="'+id+'">'+
   '<label>Gözaltı inceleme kararı</label><select name="p_karar"><option value="serbest">Derhal serbest bırak</option><option value="devam">Kalan gözaltı süresini onayla</option></select>'+
   '<label>Gerekçeli hâkim kararı</label><textarea name="p_gerekce" minlength="25" maxlength="700" required></textarea>'+
   '<p class="hh-muted">Bu karar bir tutuklama hükmü değildir; mevcut bir saatlik sürenin üzerine çıkmaz. İtiraz hakkı korunur.</p>'+
   '<button class="hh-action hh-primary">Gerekçeli kararı kaydet</button></form></details>';
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
 '<details class="hh-detail"><summary>💼 Bütçeyle müdahale</summary><p class="hh-muted">Bütçe tek başına etki etmez; tam etki için sahada 3 gerçek görevli gerekir.</p><form data-hh-fn="sokak_butce_mudahale" data-hh-id="'+Number(x.id)+'">'+
 '<label>Harcama (TL)</label><input type="number" name="p_tutar" min="'+Number(d.ayar?.baslatma_bedeli||50000)+'" max="2000000" step="1000" required>'+
 '<label>Somut gerekçe</label><textarea name="p_gerekce" minlength="25" maxlength="500" required></textarea>'+
 '<button class="hh-action">Bütçeyi kullan</button></form></details>'+
 '<details class="hh-detail"><summary>🚓 Polis sevki ve gözaltı</summary><form data-hh-fn="sokak_polis_gonder" data-hh-id="'+Number(x.id)+'">'+
 '<p class="hh-muted">Polis sahadaki gerçek görevlilerle çalışır: emri verdiğinde sen de sahaya çıkmış sayılırsın. Her görevli en çok 1 kişiyi gözaltına alır; etki görevli sayısıyla büyür, bütçeyle değil.</p><label>Sevk seviyesi</label><select name="p_seviye"><option value="dusuk">Düşük – gözaltı yok</option><option value="orta">Orta – en çok 2 kişi (sahadaki görevli kadar)</option><option value="yuksek">Yüksek – en çok 4 kişi (sahadaki görevli kadar)</option></select>'+
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
 html+=pan('history',history)+pan('tools','<div class="hh-box"><h3>Gelişmiş eylem işlemleri</h3><p>Koalisyon çağrıları, ayrıntılı hükümet kararları, polis geri çekme, somut uzlaşma ve söz oylaması gibi önceki araçlar bu bölümden kullanılabilir. Açıldığında eski işlem kartları aşağıda görünür.</p><button type="button" class="hh-action hh-primary" id="hhOldToggle">Gelişmiş işlemleri göster / gizle</button></div>')+'</section>';
 anchor.insertAdjacentHTML('afterbegin',html);
 const root=document.getElementById('hhCommand');
 // Eski coklu panelleri gizleyip tek komuta merkezinden yonet. Gereken eski islevler diger modullerde kalir.
 ['hhOrgUI','hhFinansUI','so-v2'].forEach(id=>{
  const old=document.getElementById(id);
  if(old&&old!==anchor&&!old.contains(root))old.style.display='none';
 });
 // Orijinal formlari gizle; ekran iskeletinin gezinme/baslik ogelerine dokunma.
 // Ilk ekranin (sari guc / taraf / fon) kartlari anchor ile ayni kapsayicidadir.
 const legacyBlocks=anchor.parentElement?[...anchor.parentElement.children].filter(el=>
  el!==anchor&&(el.classList.contains('kart')||el.matches('details,section')||el.id==='so-v2')):[];
 legacyBlocks.forEach(el=>{el.style.display='none';el.dataset.hhLegacyBlock='1';});
 const tabs=[...root.querySelectorAll('[data-hh-tab]')];
 function show(key){
  lastCommandTab=key;
  tabs.forEach(b=>b.setAttribute('aria-selected',String(b.dataset.hhTab===key)));
  root.querySelectorAll('[data-hh-panel]').forEach(panel=>{panel.hidden=panel.dataset.hhPanel!==key;});
  const legacyVisible=key==='tools'&&root.dataset.hhLegacy==='1';
  legacyBlocks.forEach(el=>{el.style.display=legacyVisible?'':'none';});
  ['hhOrgUI','hhFinansUI','so-v2'].forEach(id=>{const old=document.getElementById(id);if(old&&old!==anchor&&!old.contains(root))old.style.display=legacyVisible?'':'none';});
 }
 tabs.forEach(b=>b.addEventListener('click',()=>show(b.dataset.hhTab)));
 root.querySelector('#hhOldToggle')?.addEventListener('click',()=>{root.dataset.hhLegacy=root.dataset.hhLegacy==='1'?'0':'1';show('tools');});
 show(pending.some(z=>z.info.benim)?'legal':lastCommandTab);
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
  if(fn==='sokak_katil_tercih'){
   const source=String(args.katilim_sekli||'bagimsiz:').split(':');delete args.katilim_sekli;
   args.p_eylem=id;args.p_org_tur=source[0];args.p_org_id=source[0]==='bagimsiz'?null:Number(source[1]||0);
  }
  if(fn==='sokak_destek'){
   const source=String(args.kaynak||'oyuncu:').split(':');delete args.kaynak;
   args.p_kaynak=source[0];args.p_kaynak_id=source[0]==='oyuncu'?null:Number(source[1]||0);
   if(args.p_kaynak!=='oyuncu'&&!args.p_kaynak_id)return toast('Geçerli parti veya dernek seç',true);
   args.p_tutar=Number(args.p_tutar);args.p_taraf='muhalefet';args.p_eylem=id;
  }
  if(['sokak_eylem_sonlandir','sokak_basina_aciklama','sokak_yanit','sokak_butce_mudahale','sokak_polis_gonder'].includes(fn))args.p_eylem=id;
  if(['sokak_avukat_cagir','sokak_gozalti_itiraz','sokak_gozalti_mahkeme','sokak_baro_ata','sokak_gozalti_hakim_incele'].includes(fn))args.p_gozalti=id;
  if(fn==='sokak_eylem_sonlandir'&&!window.confirm('Bu eylemi kesin olarak sonlandırmak istiyor musun?'))return;
  if(fn==='sokak_butce_mudahale')args.p_tutar=Number(args.p_tutar);
  run(form.querySelector('button'),fn,args);
 }));
};
})();
if(window.__hhSar&&typeof sokakHareketleriEkrani==='function')sokakHareketleriEkrani=window.__hhSar('merkez',sokakHareketleriEkrani);

/* Deployment asset version: 20261107-4; source of truth for GitHub Pages. */

/* Asset refresh: 20261107-4b */

/* ═══════════════════════════════════════════════════════════════════
   HALK HAREKETLERİ 3.0 · SAHA KATMANI (09.11.2026)
   Eylemi büyüten de durduran da yalnız gerçek oyuncunun yaptığı bir şey.
   Sunucu: supabase/migrations/20261109090000_sokak_gercek_oyuncu.sql
   · Eylemden istediğin an ayrıl (katılımcı, karşı taraf, görevli)
   · Katılımcı taktikleri: nöbet, pankart (kendi sloganın), duran insan,
     barikat, çağrı, genel grev
   · Tarafsız oyuncuların kamuoyu nabzı, karşı tarafta yer alma
   · Görevli olarak sahaya çık / görevden ayrıl / kalkanı bırak
   · Devlet: valilik yasağı, gözaltı jesti, arabulucu heyeti,
     ulusa sesleniş, karşı miting çağrısı
   · Güç dökümü ve gerçek veriyle gece meydanı sinematiği
   ═══════════════════════════════════════════════════════════════════ */
(function(){
'use strict';
if(typeof sokakHareketleriEkrani!=='function')return;
const SAHA_CSS='so-hh-saha-v1';
if(!document.getElementById(SAHA_CSS)){
 const st=document.createElement('style');st.id=SAHA_CSS;
 st.textContent=[
 '#hhCommand .hh-saha{margin:12px 0 4px;padding:13px 12px;border:1px solid #4b5a8a;border-radius:15px;background:linear-gradient(160deg,rgba(40,34,92,.55),rgba(12,20,48,.55))}',
 '#hhCommand .hh-saha h4{margin:0 0 8px;font-size:15px;color:#fff;letter-spacing:.2px}',
 '#hhCommand .hh-chips{display:flex;flex-wrap:wrap;gap:6px;margin:4px 0 10px}',
 '#hhCommand .hh-chip{background:#26305a;border:1px solid #47548a;border-radius:10px;padding:5px 9px;font-size:13px;color:#dbe3f7}',
 '#hhCommand .hh-chip b{color:#fff}',
 '#hhCommand .hh-band{border-radius:12px;padding:10px 12px;margin:8px 0;font-size:14px;line-height:1.45}',
 '#hhCommand .hh-band.yasak{background:#4a2a1c;border:1px solid #a8653e;color:#ffd9c2}',
 '#hhCommand .hh-band.jest{background:#1d3f35;border:1px solid #3f8f73;color:#cff5e6}',
 '#hhCommand .hh-band.kalkan{background:#3b2a59;border:1px solid #a58cf0;color:#efe8ff}',
 '#hhCommand .hh-band.ben{background:#1f3a2f;border:1px solid #4ea47e;color:#d6f8e6}',
 '#hhCommand .hh-band.karsi{background:#402433;border:1px solid #b45f86;color:#ffdcec}',
 '#hhCommand .hh-band.gorev{background:#1f2f4f;border:1px solid #5d7fc5;color:#dbe7ff}',
 '#hhCommand .hh-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:8px 0}',
 '#hhCommand .hh-grid button.hh-action{font-size:14px!important}',
 '#hhCommand button.hh-ayril{background:#4b2232!important;border-color:#c0607f!important;color:#ffe3ec!important}',
 '#hhCommand .hh-seslenis{border:1px solid #c9a24a;background:#2d2817;border-radius:13px;padding:11px 12px;margin:8px 0;color:#fff2cf}',
 '#hhCommand .hh-seslenis blockquote{margin:6px 0 10px;padding:0 0 0 10px;border-left:3px solid #c9a24a;color:#fff6dc;white-space:pre-wrap}',
 '#hhCommand .hh-pankart{display:inline-block;background:#f2ead2;color:#2b2414;font-weight:800;border-radius:6px;padding:6px 10px;margin:4px 6px 4px 0;font-size:13px;transform:rotate(-1deg);box-shadow:0 2px 0 rgba(0,0,0,.35)}',
 '#hhCommand .hh-pankart small{display:block;font-weight:600;color:#6b5c38;font-size:11px}',
 '#hhCommand .hh-dokum{width:100%;border-collapse:collapse;font-size:13px}',
 '#hhCommand .hh-dokum td{padding:6px 4px;border-bottom:1px solid #34406a;color:#dbe3f7;vertical-align:top}',
 '#hhCommand .hh-dokum td:last-child{text-align:right;font-weight:800;white-space:nowrap}',
 '#hhCommand .hh-dokum td.art{color:#f0a0a8}#hhCommand .hh-dokum td.eks{color:#8fe0b5}',
 '@media(max-width:390px){#hhCommand .hh-grid{grid-template-columns:1fr}}',
 '#hhMeydan{position:fixed;inset:0;z-index:99999;background:#05060c;overflow:hidden;color:#fff;font:400 15px/1.5 -apple-system,BlinkMacSystemFont,system-ui,sans-serif}',
 '#hhMeydan .mg{position:absolute;inset:0;background:radial-gradient(120% 80% at 50% 0%,#2a1f47 0%,#120f22 45%,#05060c 100%)}',
 '#hhMeydan svg{position:absolute;left:0;right:0;bottom:0;width:100%;height:60%}',
 '#hhMeydan .mt{position:absolute;left:0;right:0;top:12%;text-align:center;padding:0 22px}',
 '#hhMeydan .mu{font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#ffe2b8;font-weight:800}',
 '#hhMeydan .ms{font-size:30px;font-weight:900;line-height:1.2;margin:10px 0;text-shadow:0 2px 24px rgba(255,170,80,.6);min-height:2.4em;transition:opacity .5s}',
 '#hhMeydan .mn{font-size:15px;color:#ffd98a;font-weight:800;font-variant-numeric:tabular-nums}',
 '#hhMeydan .mk{font-size:12.5px;color:#d7c9ff;margin-top:6px}',
 '#hhMeydan .mx{position:absolute;right:16px;bottom:calc(18px + env(safe-area-inset-bottom));min-height:46px;padding:10px 20px;border-radius:99px;background:rgba(0,0,0,.5);color:#fff;border:1px solid rgba(255,255,255,.35);font-weight:800;font-size:15px}',
 '#hhMeydan .pen{animation:hhPen 3.6s ease-in-out infinite}@keyframes hhPen{0%,100%{opacity:.25}45%{opacity:.95}}',
 '#hhMeydan .tel{animation:hhSalla 2.4s ease-in-out infinite}@keyframes hhSalla{0%,100%{transform:rotate(-7deg)}50%{transform:rotate(7deg)}}',
 '@media(prefers-reduced-motion:reduce){#hhMeydan .pen,#hhMeydan .tel{animation:none}}'
 ].join('\n');
 document.head.appendChild(st);
}
const esc=s=>String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
const num=x=>Number(x||0).toLocaleString('tr-TR',{maximumFractionDigits:1});
const saat=x=>x?new Date(x).toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'}):'—';
const TAKTIK=[
 {tur:'nobet',ik:'⛺',ad:'Nöbet tut',alt:'6 saat +2'},
 {tur:'duran',ik:'🧍',ad:'Duran insan',alt:'6 saat +3 · polis bedeli 2×'},
 {tur:'barikat',ik:'🧱',ad:'Barikat kur',alt:'+4 · sertleşme artar'},
 {tur:'cagri',ik:'📣',ad:'Çağrı yap',alt:'8 oyuncuya davet'}
];
let sonVeri=null;

const TD_AD={
 hizmet:['Acil Hizmet Seferberliği','Hizmet talebinde il memnuniyeti +4, 12 saat yoğunluk −8. Söz tutulmazsa ülke memnuniyeti −3. Karşı hamle: yetersiz.'],
 vergi_tatil:['Bölgesel Vergi Tatili','48 saat kent vergisi −1. Büyüme −0,2; diğer iller −0,5 memnuniyet. Karşı hamle: yetersiz.'],
 istihdam:['İstihdam Taahhüt Paketi','İşsizlik −0,3. Şirket söz vermezse indirim geri gelir. Karşı hamle: grev.'],
 brifing:['Resmi Basın Brifingi','12 saat nabız hükümete eğilir; basın katılırsa güçlenir. Karşı brifing ters çevirir.'],
 sosyal_kart:['Acil Sosyal Destek Kartı','4.000 TL × en çok 15 kişi. Oy satın alma şüphesi. Kart iade edilebilir.'],
 guzergah:['Güvenli Alan / Güzergâh','Kabulde güç aynı, düzen +5, ekonomik hasar durur. Ret +5, dayatma +8 inat.'],
 komisyon:['Meclis Araştırma Komisyonu','24 saat yeni kırmızı yok. Muhalefet vekili devralırsa talep kısmen uygulanır.'],
 gozlemci:['Bağımsız Gözlemci','Avukat katılınca 12 saat polis ve barikat kapalı. Sert müdahale ağır ceza yer.'],
 kapi:['İktidar Kapı Kapı','Üye başı 8.000 TL, 3 saatte bir. Muhalefet aynı ilde karşı çağrı yapar.'],
 gece:['Gece Toplanma Kısıtı','22.00–06.00 katılım ve taktik kapalı. İl −1, gündüz inat +2. Üç itiraz inadı +4 yapar.'],
 iletisim:['İletişim Yavaşlatma','6 saat çağrı ve nabız durur. Mesaj ve oy hakkı açık. Ülke −2, kriz +6 saat. Otobüs ve dernek daveti sürer.'],
 festival:['Kültür-Festival','Tarafsız oyuncu festivale gider. Ekmek yok oyun var +5. Sahne pankartla işgal edilir.']
};
const TD_HAMLE={
 yetersiz:'Yetersiz buluyorum',ikna_olmadim:'İkna olmadım',slogan:'Sloganla yanıtla',basin_hukumet:'Brifinge katıl',basin_karsi:'Karşı brifing yaz',
 kart_cagri:'Kartı reddedin diye çağır',kart_iade:'Kartı iade et',guzergah_kabul:'Güzergâhı kabul et',guzergah_ret:'Güzergâhı reddet',dayat:'Güzergâhı dayat',
 komisyon_iktidar:'Komisyona katıl',komisyon_muhalefet:'Muhalefet olarak katıl',komisyon_devral:'Komisyonu devral',gozlemci:'Gözlemci ol',gozlemci_ret:'Protokolü reddet',
 kapi_iktidar:'Kapı kapı dolaş · 8.000 TL',kapi_muhalefet:'Karşı çağrı yap · 8.000 TL',istihdam_grev:'Pakete karşı grev çağır',istihdam_soz:'Şirket sözü ver',
 otobus:'Miting otobüsü kaldır',dernek_davet:'Dernek daveti gönder',festival:'Festivale git',festival_ayril:'Festivalden ayrıl',sahne:'Sahneyi pankartla işgal et',kisit_itiraz:'Kısıtı tanımıyorum'
};
function tedbirHTML(row){
 if(!row) return '';
 const id=Number(row.id), ac=row.acabilir||[];
 let h='<details class="hh-detail"><summary>🏛️ On iki yeni hükümet aracı</summary><p class="hh-muted">Her birinin bedeli, riski ve karşı hamlesi var. Mesajlaşma ve seçim oyu kapanmaz.</p>';
 if(row.yonetebilir&&ac.length){
  h+='<form data-saha-form="tedbir" data-id="'+id+'"><label>Araç ve gider</label><select name="p_tur">'+ac.map(k=>{
   const bed=k==='sosyal_kart'?'4.000 TL × en çok 15 kişi':num(row.bedeller&&row.bedeller[k])+' TL';
   return '<option value="'+k+'">'+esc(TD_AD[k][0])+' · '+esc(bed)+'</option>';
  }).join('')+'</select><p class="hh-muted">'+ac.map(k=>'<b>'+esc(TD_AD[k][0])+':</b> '+esc(TD_AD[k][1])).join('<br>')+'</p><label>Gerekçe (20–500)</label><textarea name="p_gerekce" minlength="20" maxlength="500" required></textarea><button class="hh-action hh-primary">Kamu bütçesinden uygula</button></form>';
 }
 for(const t of row.tedbirler||[]){
  h+='<div class="hh-log"><b>'+esc(t.ad||t.tur)+'</b> · '+esc(t.durum)+' · '+num(t.bedel)+' TL<p>'+esc(t.gerekce)+'</p>';
  const ks=(t.karsi||[]).filter(k=>k!=='istihdam_soz'&&k!=='slogan'&&k!=='sahne'&&k!=='basin_karsi');
  if(ks.length) h+='<div class="hh-grid">'+ks.map(k=>'<button class="hh-action" data-saha-fn="sokak_tedbir_hamle" data-p=\'{"p_eylem":'+id+',"p_tur":"'+k+'"'+(k==='yetersiz'?',"p_metin":"'+t.tur+'"':'')+'}\'>'+esc(TD_HAMLE[k]||k)+'</button>').join('')+'</div>';
  for(const k of (t.karsi||[])) if(k==='slogan'||k==='sahne'||k==='basin_karsi'){
   h+='<form data-saha-form="tedbirmetin" data-id="'+id+'"><label>'+esc(TD_HAMLE[k])+'</label><input type="hidden" name="p_tur" value="'+k+'"><textarea name="p_metin" minlength="'+(k==='basin_karsi'?20:6)+'" maxlength="'+(k==='basin_karsi'?500:90)+'" required></textarea><button class="hh-action">'+esc(TD_HAMLE[k])+'</button></form>';
  }
  if((t.karsi||[]).includes('istihdam_soz')){
   h+='<form data-saha-form="tedbirsoz" data-id="'+id+'"><label>Söz veren şirket</label><select name="p_metin">'+(row.sirketler||[]).map(s=>'<option value="'+Number(s.id)+'">'+esc(s.ad)+'</option>').join('')+'</select><button class="hh-action hh-primary">İstihdam sözü ver</button></form>';
  }
  h+='</div>';
 }
 return h+'</details>';
}
const SERT_AD={
 safak:['Şafak Operasyonu','Yalnız 04.00–06.00. Nöbette az kişi varsa eylem hemen biter. Yeterli nöbet varsa operasyon tutmaz ve eylem güçlenir.'],
 elebasi:['Elebaşı Gözaltısı','Organizatör ve en hareketli iki kişi 12 saat dışarıda. Kalanlar yeni sözcü seçer. Avukat süreyi bir kez yarıya indirir.'],
 mali:['Mali Kuşatma','48 saat parti ve dernek kasasıyla süre uzatılamaz. Mahkeme aykırı derse 100.000 TL tazminat.'],
 kapatma:['Kapatma Davası Tehdidi','Dava sürerken partinin eylem harcaması iki kat. Hükümet kaybederse prestij ve memnuniyet düşer.'],
 ohal:['OHAL','Teklif Meclis onayına gider. Onaylanırsa 72 saat o ilde eylem ve yeni katılım yasak, hükümet araçları yarı fiyat. Ülke memnuniyeti düşer, erken seçim riski artar.'],
 propaganda:['Kara Propaganda','İktidar gazetecisi yabancı destek manşeti yazınca tarafsızlar soğur. Avukat ya da muhalif gazeteci çürütürse skandal olur.'],
 bol:['Böl ve Yönet','Katılımcılar kabul ve direniş diye ikiye ayrılır, güç düşer. Birlik oyu bunu bozar.'],
 kusatma:['Kuşatma Çemberi','Yeni katılım durur. İçeridekiler 6 saatte bir güç kaybeder. Dışarıdan dayanışma ziyareti çemberi bozar.'],
 ihale:['İhale ve Lisans Kılıcı','Destekleyen şirket sahiplerinin kamu ihalesi 48 saat askıya alınır. Çekilince baskı kalkar. İş dünyası tepki gösterir.'],
 sanal:['Toplu Sanal Gözaltı','Beş kişi 6 saat oy ve sohbet kullanamaz. Ülke memnuniyeti sert düşer, eyleme sempati ve basın skandalı doğar.']
};
function sertHTML(row){
 if(!row) return '';
 const id=Number(row.id), keys=Object.keys(SERT_AD);
 let h='<details class="hh-detail"><summary>⛔ On sert önlem</summary><p class="hh-muted">Çabuk sonuç verir, sonra oy kaybettirir. Cumhurbaşkanı, İçişleri Bakanı veya ilin valisi kullanır. 12 saatte en çok 2, aralarında 3 saat.</p>';
 if(row.yetkili){
  h+='<form data-saha-form="sert" data-id="'+id+'"><label>Önlem ve gider</label><select name="tur">'+keys.map(k=>'<option value="'+k+'">'+esc(SERT_AD[k][0])+' · '+num(row.bedeller&&row.bedeller[k])+' TL</option>').join('')+'</select><p class="hh-muted">'+keys.map(k=>'<b>'+esc(SERT_AD[k][0])+':</b> '+esc(SERT_AD[k][1])).join('<br>')+'</p><p class="hh-muted">İstanbul saati '+Number(row.saat)+'. Şafak yalnız 04–06 arasında.</p><label>Gerekçe (20–500)</label><textarea name="gerekce" minlength="20" maxlength="500" required></textarea><button class="hh-action hh-primary">İçişleri bütçesinden uygula</button></form>';
 }
 for(const t of row.onlemler||[]) h+='<div class="hh-log"><b>'+esc(t.ad||t.tur)+'</b> · '+esc(t.durum)+' · '+num(t.bedel)+' TL<p>'+esc(t.gerekce)+'</p></div>';
 if(row.ohal&&row.vekil&&row.ohal.durum==='onay'){
  h+='<div class="hh-band">OHAL oylaması · evet '+Number(row.ohal.evet||0)+' · hayır '+Number(row.ohal.hayir||0)+'<div class="hh-grid"><button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"ohal_oy","p_veri":{"id":'+Number(row.ohal.id)+',"oy":"evet"}}\'>OHAL\'e evet</button><button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"ohal_oy","p_veri":{"id":'+Number(row.ohal.id)+',"oy":"hayir"}}\'>OHAL\'e hayır</button></div></div>';
 }
 if(row.yargi){
  for(const t of row.onlemler||[]) if((t.tur==='mali'||t.tur==='kapatma')&&t.durum==='aktif'){
   h+='<div class="hh-grid"><button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"yargi","p_veri":{"id":'+Number(t.id)+',"oy":"aykiri"}}\'>'+esc(t.ad)+' hukuka aykırı</button><button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"yargi","p_veri":{"id":'+Number(t.id)+',"oy":"uygun"}}\'>Uygun bul</button></div>';
  }
 }
 if(row.katilimci){
  h+='<div class="hh-grid"><button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"nobet"}\'>Nöbet listesine yazıl</button><button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"birlik"}\'>Birlik oyu</button></div>';
  h+='<form data-saha-form="sertlider" data-id="'+id+'"><label>Yeni sözcü</label><input name="kad" required placeholder="Katılımcının kullanıcı adı"><button class="hh-action">Sözcüye oy ver</button></form>';
  if(row.fraksiyon) h+='<p class="hh-muted">Fraksiyonun: '+(row.fraksiyon==='kabul'?'kabul':'direniş')+'</p>';
  h+='<button class="hh-action" data-saha-fn="sokak_sert_islem" data-onay="Eylemden çekilince ihale baskısı da kalkar. Emin misin?" data-p=\'{"p_eylem":'+id+',"p_islem":"cek"}\'>İhale baskısından çekil</button>';
 }
 if(row.avukat) h+='<button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"avukat"}\'>Elebaşı süresini yarıya indir</button>';
 if(row.gazeteci&&row.iktidar) h+='<button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"manset"}\'>Yabancı destek manşetini yaz</button>';
 if((row.gazeteci&&!row.iktidar)||row.avukat) h+='<form data-saha-form="sertcurut" data-id="'+id+'"><label>Propagandayı çürüt</label><textarea name="metin" minlength="12" maxlength="400" required></textarea><button class="hh-action">Kanıtla çürüt</button></form>';
 if(!row.katilimci&&!row.yetkili) h+='<button class="hh-action" data-saha-fn="sokak_sert_islem" data-p=\'{"p_eylem":'+id+',"p_islem":"ziyaret"}\'>Dayanışma ziyareti</button>';
 return h+'</details>';
}
function sahaHTML(x){
 const dk=x.dokum||{};const id=Number(x.id);
 let h='<div class="hh-saha" data-saha="'+id+'"><h4>🧭 Sahada kim var?</h4>';
 h+='<div class="hh-chips">'+
  '<span class="hh-chip">👥 <b>'+num(dk.katilimci)+'</b> gerçek katılımcı</span>'+
  '<span class="hh-chip">🛡️ <b>'+num(dk.gorevli)+'</b> görevli</span>'+
  '<span class="hh-chip">🚩 <b>'+num(dk.karsi)+'</b> karşı tarafta</span>'+
  '<span class="hh-chip">❤️ Kamuoyu <b>'+num(dk.sempati)+'</b> <small>('+num(dk.destek)+' destek · '+num(dk.karsi_nabiz)+' karşı)</small></span>'+
  '<span class="hh-chip">🔥 Sertleşme <b>'+num(dk.sertlesme)+'</b></span></div>';
 (x.kalkan_birakanlar||[]).forEach(k=>{h+='<div class="hh-band kalkan">🫡 <b>'+esc(k.unvan)+' '+esc(k.ad)+'</b> kalkanını bırakıp meydana katıldı ('+esc(saat(k.zaman))+').</div>';});
 if(x.yasak)h+='<div class="hh-band yasak">🚧 <b>'+esc(x.yasak.unvan)+'</b> gösteri yasağı ilan etti · bitiş '+esc(saat(x.yasak.bitis))+'. Yeni katılım kapalı; meydandakiler kalabilir.<br><small>'+esc(x.yasak.gerekce)+'</small></div>';
 if(x.jest)h+='<div class="hh-band jest">🕊️ Hükümet jest yaptı: '+num(x.jest.serbest)+' gözaltı sona erdi · '+esc(saat(x.jest.bitis))+' saatine kadar gerilim düşük.</div>';
 if(x.grev_bitis)h+='<div class="hh-band yasak">🛑 <b>Genel grev</b> çağrısı sürüyor · '+esc(saat(x.grev_bitis))+' saatine kadar katılımcılar greve katılabilir.</div>';
 if(x.gorevliler&&x.gorevliler.length)h+='<p class="hh-muted">Sahadaki görevliler: '+x.gorevliler.map(g=>esc(g.unvan)+' '+esc(g.ad)).join(' · ')+'</p>';
 if(x.karsidakiler&&x.karsidakiler.length)h+='<p class="hh-muted">Karşı tarafta: '+x.karsidakiler.map(esc).join(', ')+'</p>';
 // ulusa sesleniş
 if(x.seslenis){const s=x.seslenis;
  h+='<div class="hh-seslenis">📺 <b>Ulusa sesleniş</b> · '+esc(s.yapan)+' · tepki süresi '+esc(saat(s.bitis))+'<blockquote>'+esc(s.metin)+'</blockquote>'+
   '<p class="hh-muted" style="color:#ffe9b3!important">'+num(s.ikna)+' kişi ikna oldu · '+num(s.olmadi)+' kişi olmadı'+(s.tepkim===true?' · senin tepkin: ikna oldum':s.tepkim===false?' · senin tepkin: olmadım':'')+'</p>';
  if(!(sonVeri&&sonVeri.cb))h+='<div class="hh-grid"><button class="hh-action" data-saha-fn="sokak_seslenis_tepki" data-p=\'{"p_seslenis":'+Number(s.id)+',"p_ikna":true}\'>👍 İkna oldum</button><button class="hh-action" data-saha-fn="sokak_seslenis_tepki" data-p=\'{"p_seslenis":'+Number(s.id)+',"p_ikna":false}\'>👎 İkna olmadım</button></div>';
  h+='</div>';
 }
 // benim yerim
 if(x.taraf==='muhalefet'){
  h+='<div class="hh-band ben">✊ <b>Bu eylemdesin.</b> Taktikler gücü artırır; her 3 saatte bir taktik uygulayabilirsin.'+(x.sonraki_taktik?' Sıradaki taktik: <b>'+esc(saat(x.sonraki_taktik))+'</b>.':'')+(x.gozaltindayim?' <b>Gözaltındasın</b>; süre bitene kadar taktik uygulayamazsın.':'')+'</div>';
  const kapali=!!x.sonraki_taktik||x.gozaltindayim;
  h+='<div class="hh-grid">'+TAKTIK.map(t=>'<button class="hh-action" '+(kapali?'disabled ':'')+'data-saha-fn="sokak_taktik_yap" data-p=\'{"p_eylem":'+id+',"p_tur":"'+t.tur+'"}\'>'+t.ik+' '+t.ad+'<br><small>'+t.alt+'</small></button>').join('')+
   (x.grev_bitis?'<button class="hh-action hh-primary" '+(kapali?'disabled ':'')+'data-saha-fn="sokak_taktik_yap" data-p=\'{"p_eylem":'+id+',"p_tur":"grev"}\'>🛑 Greve katıl<br><small>12 saat +1,5 · ekonomi yavaşlar</small></button>':'')+'</div>';
  h+='<details class="hh-detail"><summary>✍️ Pankartını yaz (kendi sloganın meydanda görünür)</summary><form data-saha-form="pankart" data-id="'+id+'"><label>Pankart yazısı (6–90 karakter)</label><input name="p_metin" maxlength="90" minlength="6" required placeholder="Örn. Ekmek, adalet, özgürlük!"><button class="hh-action hh-primary" '+(kapali?'disabled':'')+'>Pankartı kaldır</button></form></details>';
  if(x.ben_baslattim&&!x.grev_yapildi)h+='<button class="hh-action" data-saha-fn="sokak_grev_cagri" data-p=\'{"p_eylem":'+id+'}\' data-onay="Genel grev çağrısı eylem başına bir kez yapılır ve en az 5 gerçek katılımcı ister. Çağrı yapılsın mı?">🛑 Genel grev çağrısı yap (organizatör)</button>';
  h+='<button class="hh-action hh-ayril" style="margin-top:8px!important" data-saha-fn="sokak_eylemden_ayril" data-p=\'{"p_eylem":'+id+'}\' data-onay="Eylemden ayrılmak istediğine emin misin? Aynı eyleme 1 saat sonra yeniden katılabilirsin.">🚪 Eylemden ayrıl</button>';
 }else if(x.taraf==='iktidar'){
  h+='<div class="hh-band karsi">🚩 <b>Karşı taraftasın.</b> Burada durduğun sürece eylemin gücü azalır.</div>';
  h+='<button class="hh-action hh-ayril" data-saha-fn="sokak_eylemden_ayril" data-p=\'{"p_eylem":'+id+'}\' data-onay="Karşı taraftan ayrılmak istiyor musun? Aynı eyleme 1 saat sonra dönebilirsin.">🚪 Karşı taraftan ayrıl</button>';
 }else if(x.gorevdeyim){
  h+='<div class="hh-band gorev">🛡️ <b>Sahada görevdesin.</b> Burada durduğun sürece eylemin gücü azalır ve polis müdahalesi sahadaki görevli sayısıyla yapılır.</div>';
  h+='<button class="hh-action hh-ayril" data-saha-fn="sokak_gorevden_ayril" data-p=\'{"p_eylem":'+id+'}\' data-onay="Görevden ayrılmak istiyor musun?">🚪 Görevden ayrıl</button>';
  if(x.kalkan_hakki)h+='<details class="hh-detail"><summary>🫡 Kalkanı bırak ve meydana katıl</summary><p class="hh-muted">Görevi bırakıp eyleme katılırsın. Herkese duyurulur; İçişleri Bakanı bilgilendirilir.</p><form data-saha-form="kalkan" data-id="'+id+'"><label>Kamuoyuna söyleyeceğin söz (20–400 karakter)</label><textarea name="p_aciklama" minlength="20" maxlength="400" required></textarea><button class="hh-action hh-ayril">Kalkanımı bırakıyorum</button></form></details>';
 }else{
  const nb=x.nabzim;
  const devlet=!!(sonVeri&&sonVeri.yonetebilir);
  h+=(devlet?'<p class="hh-muted">Kamuoyu nabzı tarafsız oyuncuların sesidir; devlet yöneticileri oy veremez.</p><div class="hh-grid">':'<p class="hh-muted"><b>Kamuoyu nabzı:</b> eyleme taraf değilsen görüşün eylemin kamuoyu desteğini belirler.</p><div class="hh-grid">')+
   (devlet?'':'<button class="hh-action'+(nb===1?' hh-primary':'')+'" data-saha-fn="sokak_nabiz_ver" data-p=\'{"p_eylem":'+id+',"p_tavir":1}\'>❤️ Destekliyorum</button>'+
   '<button class="hh-action'+(nb===-1?' hh-primary':'')+'" data-saha-fn="sokak_nabiz_ver" data-p=\'{"p_eylem":'+id+',"p_tavir":-1}\'>👎 Karşıyım</button>')+
   (nb&&!devlet?'<button class="hh-action" data-saha-fn="sokak_nabiz_ver" data-p=\'{"p_eylem":'+id+',"p_tavir":0}\'>◌ Görüşümü geri al</button>':'')+
   '<button class="hh-action" data-saha-fn="sokak_karsi_katil" data-p=\'{"p_eylem":'+id+'}\' data-onay="Karşı tarafta yer almak istiyor musun? Bu eylemde artık katılımcı olamazsın; istediğin an ayrılabilirsin.">🚩 Karşı tarafta yer al</button>'+
   (sonVeri&&sonVeri.gorev_unvanim?'<button class="hh-action hh-primary" data-saha-fn="sokak_goreve_cik" data-p=\'{"p_eylem":'+id+'}\'>🛡️ '+esc(sonVeri.gorev_unvanim)+' olarak sahaya çık</button>':'')+
   '</div>';
 }
 if(x.yeniden_katilim)h+='<p class="hh-muted">Bu eylemden yakın zamanda ayrıldın; yeniden katılım <b>'+esc(saat(x.yeniden_katilim))+'</b> sonrası açılır.</p>';
 // heyet
 if((x.heyet||[]).length){
  h+='<details class="hh-detail" open><summary>🧓 Arabulucu heyeti</summary>';
  x.heyet.forEach(m=>{
   h+='<div class="hh-log"><b>'+esc(m.ad)+'</b> · '+esc(m.durum==='davet'?'yanıt bekleniyor':m.durum==='kabul'?'heyette':'reddetti')+(m.rapor?'<p>'+esc(m.rapor)+'</p>':'')+'</div>';
   if(m.ben&&m.durum==='davet')h+='<div class="hh-grid"><button class="hh-action hh-primary" data-saha-fn="sokak_heyet_yanit" data-p=\'{"p_eylem":'+id+',"p_kabul":true}\'>✓ Heyete katıl</button><button class="hh-action" data-saha-fn="sokak_heyet_yanit" data-p=\'{"p_eylem":'+id+',"p_kabul":false}\'>✕ Reddet</button></div>';
   if(m.ben&&m.durum==='kabul'&&!m.rapor)h+='<form data-saha-form="rapor" data-id="'+id+'"><label>Heyet raporun (40–1200 karakter)</label><textarea name="p_metin" minlength="40" maxlength="1200" required></textarea><button class="hh-action hh-primary">Raporu açıkla</button></form>';
  });
  h+='</details>';
 }
 // devlet araçları
 const V=sonVeri||{};
 if(x.yasak_yetki||V.yonetebilir||V.cb||V.karsi_cagri_yetki){
  h+='<details class="hh-detail"><summary>🏛️ Devletin sahadaki araçları</summary><p class="hh-muted">Hepsi gerçek kişilerle çalışır; etkisi güç dökümünde görünür.</p>';
  if(x.yasak_yetki&&!x.yasak)h+='<form data-saha-form="yasak" data-id="'+id+'"><label>🚧 Valilik gösteri yasağı (6 saat yeni katılım kapalı; kalanlar inatlaşır) · gerekçe</label><textarea name="p_gerekce" minlength="25" maxlength="500" required></textarea><button class="hh-action">Yasağı ilan et</button></form>';
  if(V.yonetebilir&&!x.jest)h+='<form data-saha-form="jest" data-id="'+id+'"><label>🕊️ Gözaltı jesti (tüm gözaltılar serbest, 6 saat gerilim düşer) · gerekçe</label><textarea name="p_gerekce" minlength="20" maxlength="500" required></textarea><button class="hh-action">Jest yap</button></form>';
  if(V.cb)h+='<form data-saha-form="heyet" data-id="'+id+'"><label>🧓 Arabulucu heyetine davet et (en çok 3, eylemde taraf olmayan) · kullanıcı adı</label><input name="p_kad" required maxlength="40" placeholder="Oyuncunun kullanıcı adı"><button class="hh-action">Heyete davet et</button></form>';
  if(V.cb&&!x.seslenis)h+='<form data-saha-form="seslenis" data-id="'+id+'"><label>📺 Ulusa sesleniş (oyuncular ikna olup olmadığını söyler; geri tepebilir) · konuşma metni</label><textarea name="p_metin" minlength="60" maxlength="1500" required></textarea><button class="hh-action hh-primary">Ulusa seslen</button></form>';
  if(V.karsi_cagri_yetki)h+='<button class="hh-action" data-saha-fn="sokak_karsi_cagri" data-p=\'{"p_eylem":'+id+'}\' data-onay="Parti üyelerine karşı miting çağrısı gönderilsin mi?">🚩 Parti üyelerini karşı mitinge çağır</button>';
  h+='</details>';
 }
 // pankartlar
 if((x.pankartlar||[]).length){
  h+='<details class="hh-detail" open><summary>📜 Meydandan sesler</summary><div>'+x.pankartlar.map(p=>'<span class="hh-pankart">'+esc(p.metin)+'<small>— '+esc(p.ad)+'</small></span>').join('')+'</div></details>';
 }
 // döküm
 if(dk.satirlar){
  h+='<details class="hh-detail"><summary>📊 Güç dökümü · toplam '+num(dk.toplam)+'</summary><table class="hh-dokum">'+
   dk.satirlar.filter(r=>Number(r.puan)!==0||/katılımcı|ağırlık|Düzen|komisyon|brifing/i.test(r.ad)).map(r=>'<tr><td>'+esc(r.ad)+'</td><td class="'+(Number(r.puan)>0?'art':Number(r.puan)<0?'eks':'')+'">'+(Number(r.puan)===0?'·':(Number(r.puan)>0?'+':'')+num(r.puan))+'</td></tr>').join('')+
   '</table><p class="hh-muted">Para eylemi güçlendirmez; yalnız süreyi uzatır. Kırmızı seviye için en az 3 gerçek katılımcı ve 75 puan gerekir.</p></details>';
 }
 if(Number(dk.katilimci)>0)h+='<button class="hh-action" style="margin-top:6px!important" data-saha-meydan="'+id+'">🌙 Meydanı izle</button>';
 h+='</div>';
 return h;
}

function meydanAc(id){
 const x=(sonVeri&&sonVeri.eylemler||[]).find(e=>Number(e.id)===Number(id)); if(!x)return;
 document.getElementById('hhMeydan')?.remove();
 const reduce=window.matchMedia&&window.matchMedia('(prefers-reduced-motion: reduce)').matches;
 const n=Number(x.dokum&&x.dokum.katilimci||0), g=Number(x.dokum&&x.dokum.gorevli||0);
 const W=400,H=300; let bina='',pen='',kal='',isik='',xx=0; const R=(a,b)=>a+Math.random()*(b-a);
 while(xx<W){const bw=Math.round(R(18,42)),bh=Math.round(R(30,95)),by=H-118-bh;bina+='<rect x="'+xx+'" y="'+by+'" width="'+bw+'" height="'+(bh+118)+'" fill="#0c0b16"/>';
  for(let wy=by+8;wy<H-125;wy+=11)for(let wx=xx+4;wx<xx+bw-5;wx+=8)if(Math.random()<.28)pen+='<rect class="pen" x="'+wx+'" y="'+wy+'" width="3.2" height="4.4" fill="#ffcf7a" style="animation-delay:'+R(0,4).toFixed(2)+'s"/>';
  xx+=bw+Math.round(R(1,4));}
 // Kalabalık gerçek katılımcı sayısıyla çizilir: her kafa bir oyuncu (en çok 60).
 const kisi=Math.min(60,n), sira=[{y:H-70,r:5},{y:H-40,r:7},{y:H-8,r:10}];
 // Dar ekranda kadraj ortadaki ~220 birimi gösterir: kalabalık ortada, kişi sayısı kadar genişlikte toplanır.
 const gen=Math.min(380,Math.max(70,kisi*16)), sol=W/2-gen/2;
 for(let i=0;i<kisi;i++){const s=sira[i%3];const cx=sol+(i+0.5)*gen/kisi+R(-4,4),cy=s.y+R(-2,2);
  kal+='<g fill="'+(i%3===2?'#06050c':i%3===1?'#100e1e':'#1b1730')+'"><circle cx="'+cx.toFixed(1)+'" cy="'+(cy-s.r*1.6).toFixed(1)+'" r="'+s.r+'"/><rect x="'+(cx-s.r*1.5).toFixed(1)+'" y="'+(cy-s.r*.7).toFixed(1)+'" width="'+(s.r*3)+'" height="'+(s.r*3)+'" rx="'+(s.r*1.2)+'"/></g>';
  const hy=cy-s.r*4.2; isik+='<g class="tel" style="animation-delay:'+R(0,2.2).toFixed(2)+'s;transform-origin:'+cx.toFixed(1)+'px '+cy.toFixed(1)+'px"><line x1="'+cx.toFixed(1)+'" y1="'+(cy-s.r*.4).toFixed(1)+'" x2="'+cx.toFixed(1)+'" y2="'+hy.toFixed(1)+'" stroke="#100e1e" stroke-width="'+(s.r*.55).toFixed(1)+'" stroke-linecap="round"/><circle cx="'+cx.toFixed(1)+'" cy="'+hy.toFixed(1)+'" r="'+(s.r*.45+.6).toFixed(1)+'" fill="#fff2cf" filter="url(#hhG)"/></g>';}
 // Sahadaki görevliler: mavi kalkan siluetleri (her biri gerçek bir oyuncu)
 let kalkan='';const gk=Math.min(8,g);for(let i=0;i<gk;i++){const cx=W/2-gk*14+i*28;kalkan+='<rect x="'+cx+'" y="'+(H-128)+'" width="16" height="22" rx="4" fill="#20325e" stroke="#6d8fd6" stroke-width="1.2"/>';}
 const svg='<svg viewBox="0 0 '+W+' '+H+'" preserveAspectRatio="xMidYMax slice" aria-hidden="true"><defs><filter id="hhG" x="-200%" y="-200%" width="500%" height="500%"><feGaussianBlur stdDeviation="2.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter><radialGradient id="hhH" cx="50%" cy="100%" r="70%"><stop offset="0" stop-color="#ffb35c" stop-opacity=".28"/><stop offset="1" stop-color="#ffb35c" stop-opacity="0"/></radialGradient></defs><rect width="'+W+'" height="'+H+'" fill="url(#hhH)"/>'+bina+pen+kalkan+kal+isik+'</svg>';
 const sloganlar=(x.pankartlar||[]).map(p=>({m:p.metin,a:p.ad}));
 if(!sloganlar.length)sloganlar.push({m:'Meydan seni bekliyor',a:''});
 const w=document.createElement('div');w.id='hhMeydan';w.setAttribute('role','dialog');w.setAttribute('aria-label','Meydan görünümü');
 w.innerHTML='<div class="mg"></div>'+svg+'<div class="mt"><div class="mu">Eylem #'+Number(id)+' · gerçek oyuncular</div><div class="ms" id="hhMs"></div><div class="mn"><span id="hhMn">0</span> kişi meydanda'+(g?' · '+g+' görevli sahada':'')+'</div><div class="mk" id="hhMk"></div></div><button class="mx" type="button">Kapat ▸</button>';
 document.body.appendChild(w);
 const kapat=()=>{clearInterval(w._t);w.remove();};
 w.querySelector('.mx').addEventListener('click',kapat);
 let i=0;const ms=w.querySelector('#hhMs'),mk=w.querySelector('#hhMk');
 const goster=()=>{const s=sloganlar[i%sloganlar.length];ms.style.opacity=0;setTimeout(()=>{ms.textContent=s.m;mk.textContent=s.a?'— '+s.a:'';ms.style.opacity=1;},reduce?0:350);i++;};
 goster(); if(sloganlar.length>1)w._t=setInterval(goster,3200);
 const mn=w.querySelector('#hhMn'); if(reduce){mn.textContent=n;}else{let t0=null;const adim=t=>{if(!document.getElementById('hhMeydan'))return;if(t0===null)t0=t;const p=Math.min(1,(t-t0)/1600);mn.textContent=Math.round(n*(1-Math.pow(1-p,3)));if(p<1)requestAnimationFrame(adim);};requestAnimationFrame(adim);}
}

const onceki=sokakHareketleriEkrani;
sokakHareketleriEkrani=async function(){
 await onceki.apply(this,arguments);
 const root=document.getElementById('hhCommand'); if(!root)return;
 let d; try{d=await API.rpc('sokak_saha_panel');}catch(err){console.warn('Saha paneli',err);return;}
 let td=null; try{td=await API.rpc('sokak_tedbir_panel');}catch(err){console.warn('Tedbir paneli',err);}
 const tedbirHarita={}; ((td&&td.eylemler)||[]).forEach(r=>{tedbirHarita[Number(r.id)]=r;});
 let sd=null; try{sd=await API.rpc('sokak_sert_panel');}catch(err){console.warn('Sert önlem paneli',err);}
 const sertHarita={}; ((sd&&sd.eylemler)||[]).forEach(r=>{sertHarita[Number(r.id)]=r;});
 sonVeri=d||{};
 (sonVeri.eylemler||[]).forEach(x=>{
  const art=root.querySelector('article.hh-event[data-hh-event="'+Number(x.id)+'"]'); if(!art)return;
  art.querySelector('.hh-saha')?.remove();
  // Katılımcıysan eski "Katılıyorsun" rozetinin altına; değilsen katıl formunun hemen altına yerleş.
  const yer=art.querySelector('form.hh-participate')||art.querySelector(':scope > .hh-pill.live')||art.querySelector('.hh-meter');
  // Karşı taraftaysan ya da görevliysen muhalefet "katıl" formu yanıltıcı olur: gizle.
  if((x.taraf==='iktidar'||x.gorevdeyim)&&art.querySelector('form.hh-participate'))art.querySelector('form.hh-participate').style.display='none';
  if(x.yasak&&!x.taraf&&art.querySelector('form.hh-participate'))art.querySelector('form.hh-participate').insertAdjacentHTML('beforebegin','<p class="hh-muted">🚧 Gösteri yasağı sürerken yeni katılım kapalı.</p>');
  (yer||art.firstElementChild).insertAdjacentHTML('afterend',sahaHTML(x)+tedbirHTML(tedbirHarita[Number(x.id)])+sertHTML(sertHarita[Number(x.id)]));
 });
 const run=async(btn,fn,args,okMsg)=>{
  if(btn)btn.disabled=true;
  try{const r=await API.rpc(fn,args);
   let m=okMsg||'İşlem kaydedildi';
   if(fn==='sokak_eylemden_ayril')m=r&&r.gozalti_suruyor?'Eylemden ayrıldın. Gözaltı süreci hukuken devam ediyor.':'Eylemden ayrıldın. 1 saat sonra yeniden katılabilirsin.';
   if(fn==='sokak_taktik_yap'&&args.p_tur==='cagri')m=(r&&r.cagrilan||0)+' oyuncuya çağrı gönderildi';
   if(fn==='sokak_goreve_cik')m='Sahadasın: '+(r&&r.unvan||'görevli');
   toast(m);await sokakHareketleriEkrani();
  }catch(ex){toast((typeof hataCevir==='function'?hataCevir(ex.message||String(ex)):(ex.message||String(ex))),true);if(btn)btn.disabled=false;}
 };
 root.querySelectorAll('[data-saha-fn]').forEach(b=>b.addEventListener('click',()=>{
  if(b.dataset.onay&&!window.confirm(b.dataset.onay))return;
  let p={};try{p=JSON.parse(b.dataset.p||'{}');}catch(_){}
  run(b,b.dataset.sahaFn,p);
 }));
 const FORM={pankart:['sokak_taktik_yap',f=>({p_tur:'pankart',p_metin:f.p_metin}),'Pankartın meydanda'],
  kalkan:['sokak_kalkan_birak',f=>({p_aciklama:f.p_aciklama}),'Kalkanını bıraktın; artık meydandasın'],
  rapor:['sokak_heyet_rapor',f=>({p_metin:f.p_metin}),'Heyet raporu açıklandı'],
  yasak:['sokak_yasak_koy',f=>({p_gerekce:f.p_gerekce}),'Gösteri yasağı ilan edildi'],
  jest:['sokak_jest_yap',f=>({p_gerekce:f.p_gerekce}),'Gözaltılar serbest bırakıldı'],
  heyet:['sokak_heyet_davet',f=>({p_kad:f.p_kad}),'Heyet daveti gönderildi'],
  seslenis:['sokak_seslenis_yap',f=>({p_metin:f.p_metin}),'Ulusa seslendin'],
  tedbir:['sokak_tedbir_ac',f=>({p_tur:f.p_tur,p_gerekce:f.p_gerekce}),'Hükümet aracı uygulandı'],
  tedbirmetin:['sokak_tedbir_hamle',f=>({p_tur:f.p_tur,p_metin:f.p_metin}),'Karşı hamle kaydedildi'],
  tedbirsoz:['sokak_tedbir_hamle',f=>({p_tur:'istihdam_soz',p_metin:f.p_metin}),'Şirket sözü kaydedildi'],
  sert:['sokak_sert_islem',f=>({p_islem:'ac',p_veri:{tur:f.tur,gerekce:f.gerekce}}),'Sert önlem uygulandı'],
  sertlider:['sokak_sert_islem',f=>({p_islem:'lider_oy',p_veri:{kad:f.kad}}),'Sözcü oyu kaydedildi'],
  sertcurut:['sokak_sert_islem',f=>({p_islem:'curut',p_veri:{metin:f.metin}}),'Çürütme kaydedildi']};
 root.querySelectorAll('form[data-saha-form]').forEach(f=>f.addEventListener('submit',ev=>{
  ev.preventDefault();const k=FORM[f.dataset.sahaForm];if(!k)return;
  if(f.dataset.sahaForm==='kalkan'&&!window.confirm('Kalkanını bırakıp eyleme katılmak istediğine emin misin? Herkese duyurulur.'))return;
  const v=Object.fromEntries(new FormData(f).entries());
  run(f.querySelector('button'),k[0],Object.assign({p_eylem:Number(f.dataset.id)},k[1](v)),k[2]);
 }));
 root.querySelectorAll('[data-saha-meydan]').forEach(b=>b.addEventListener('click',()=>meydanAc(b.dataset.sahaMeydan)));
};
if(window.__hhSar)sokakHareketleriEkrani=window.__hhSar('saha',sokakHareketleriEkrani);
window.__hhMeydanAc=meydanAc;
})();

/* Asset refresh: 20261109-4 (on sert önlem) */
(function(){
'use strict';
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const saat=t=>t?new Date(t).toLocaleString('tr-TR',{hour:'2-digit',minute:'2-digit',day:'2-digit',month:'2-digit'}):'';
function kart(bas,ic){return '<details class="hh-detail" open><summary>'+bas+'</summary>'+ic+'</details>';}
function islem(btn,eylem,ad,veri,mesaj){
 if(btn)btn.disabled=true;
 return API.rpc('sokak_meydan_islem',{p_eylem:eylem,p_islem:ad,p_veri:veri||{}}).then(()=>{toast(mesaj||'Kaydedildi');return sokakHareketleriEkrani();}).catch(ex=>{toast((typeof hataCevir==='function'?hataCevir(ex.message||String(ex)):String(ex.message||ex)),true);if(btn)btn.disabled=false;});
}
const onceki=sokakHareketleriEkrani;
sokakHareketleriEkrani=async function(){
 await onceki.apply(this,arguments);
 const root=document.getElementById('hhCommand')||document.getElementById('icerik');
 if(!root)return;
 let p; try{p=await API.rpc('sokak_meydan_panel');}catch(err){return;}
 let harita=null; try{harita=await API.rpc('sokak_kriz_harita');}catch(err){}
 let denetim=[]; try{denetim=await API.rpc('sokak_denetim_oku');}catch(err){}
 let h='<section id="hhMeydanEk">';
 (p.manset||[]).forEach(m=>{h+='<div class="hh-band yasak">SON DAKİKA · '+esc(m)+'</div>';});
 if(harita){
  h+=kart('🗺️ Canlı Türkiye kriz haritası','<div class="hh-chips">'+(harita.iller||[]).map(i=>{
   const renk=Number(i.memnuniyetsizlik)>=60?'#8c2f39':Number(i.memnuniyetsizlik)>=35?'#8a5a20':'#1d3b34';
   return '<span class="hh-chip" style="background:'+renk+(i.eylem?';animation:nabiz 1.6s ease-in-out infinite':'')+'">'+esc(i.ad)+' '+esc(i.memnuniyetsizlik)+(i.eylem?' · eylem':'')+'</span>';
  }).join('')+'</div><p class="hh-muted">'+(harita.serit||[]).map(esc).join(' · ')+'</p>');
 }
 h+=kart('📜 Meydanın hafızası',(p.hafiza||[]).map(x=>'<p><b>'+esc(x.ad)+'</b>'+(x.oradaydim?' · Oradaydım':'')+'<br>'+esc(x.slogan||'')+' · '+esc(x.sonuc||'')+'</p>').join('')||'<p class="hh-muted">Bitmiş eylemler burada adını ve sloganını saklar.</p>');
 (p.mesale||[]).forEach(m=>{h+='<p class="hh-muted">🔥 Meşale: il '+esc(m.kaynak)+' → il '+esc(m.hedef)+' · '+esc(m.durum)+' · '+esc(saat(m.varis))+'</p>';});
 const pus=p.pusula||{};
 h+='<p class="hh-muted">Hesap günü pusulası: sahada '+Number(pus.sahada||0)+' · yasak '+Number(pus.yasak||0)+' · anlaşma '+Number(pus.anlasma||0)+' · saf değiştirme '+Number(pus.saf||0)+' · sert önlem '+Number(pus.sert||0)+'</p>';
 for(const e of p.eylemler||[]){
  const id=Number(e.id);
  h+='<article class="kart" data-meydan="'+id+'"><h3>Eylem #'+id+' meydanı</h3>';
  if(e.son_gece){const s=e.son_gece; h+='<div class="hh-band">📡 Meydanda son gece · '+esc(s.durum)+' · '+esc(saat(s.bas))+' – '+esc(saat(s.bit))+(s.sonuc?' · '+esc(s.sonuc):'')+'</div><p>Güç: '+esc(e.seviye)+'/100</p>';}
  if(e.sohbet_hak){
   h+=kart('💬 Eylem sohbeti','<div class="hh-sohbet" data-sohbet="'+id+'">Yükleniyor…</div><form data-meydan-form="sohbet" data-id="'+id+'"><textarea name="metin" maxlength="400" required placeholder="Yalnız bu eylemin içindeki oyuncular görür"></textarea><button class="hh-action hh-primary">Gönder</button></form>');
  }
  if(e.muhbir_teklif) h+='<div class="hh-band">Gizli teklif: '+esc(e.muhbir_teklif.para)+' TL. Vaat: '+esc(e.muhbir_teklif.makam||'yok')+'<div class="hh-grid"><button class="hh-action" data-meydan-islem="muhbir_yanit" data-id="'+id+'" data-v=\'{"kabul":true}\'>Kabul</button><button class="hh-action" data-meydan-islem="muhbir_yanit" data-id="'+id+'" data-v=\'{"kabul":false}\'>Ret</button><button class="hh-action hh-ayril" data-meydan-islem="muhbir_yanit" data-id="'+id+'" data-v=\'{"ifsa":true}\'>İfşa et</button></div></div>';
  if(e.muhbirim) h+=kart('İçeriden bilgi','<form data-meydan-form="muhbir_sizdir" data-id="'+id+'"><textarea name="metin" maxlength="400" required placeholder="Sohbet ya da plan. Her sızıntı şüpheyi artırır."></textarea><button class="hh-action">Hükümete ilet</button></form>');
  if(p.yonetebilir&&e.iceri) h+=kart('İçeriden bilgi', (e.iceri||[]).map(s=>'<p><b>'+esc(s.ad)+'</b> · '+esc(s.metin)+'</p>').join('')||'<p class="hh-muted">Henüz sızıntı yok.</p>');
  if(e.katilimci) h+='<form data-meydan-form="muhbir_oy" data-id="'+id+'"><label>İfşa oyu (günde 1, en az 3 oy ve çoğunluk)</label><input name="kad" required placeholder="Şüphelinin kullanıcı adı"><button class="hh-action">Oy ver</button></form>';
  if(p.yonetebilir) h+='<form data-meydan-form="muhbir_teklif" data-id="'+id+'"><label>Muhbir teklifi</label><input name="kad" required placeholder="Katılımcının kullanıcı adı"><input name="para" type="number" min="0" max="80000" value="0" placeholder="TL"><input name="metin" maxlength="120" placeholder="Vaadedilen makam (zorunlu değil)"><button class="hh-action">Gizli teklif gönder</button></form><form data-meydan-form="muhbir_dik" data-id="'+id+'"><input name="kad" required placeholder="İktidardan, eyleme katılmış oyuncu"><button class="hh-action">İçeriden kişi olarak işaretle</button></form>';
  if(e.kirmizi_hat&&e.kirmizi_hat.durum==='bekliyor'&&e.baslatan) h+='<div class="hh-band">Kırmızı hat: '+esc(e.kirmizi_hat.teklif)+'<br>'+esc(e.kirmizi_hat.metin)+'<div class="hh-grid"><button class="hh-action" data-meydan="kirmizi_yanit" data-id="'+id+'" data-v=\'{"yanit":"kabul"}\'>Gizlice kabul</button><button class="hh-action" data-meydan="kirmizi_yanit" data-id="'+id+'" data-v=\'{"yanit":"ret"}\'>Ret</button><button class="hh-action hh-ayril" data-meydan="kirmizi_yanit" data-id="'+id+'" data-v=\'{"yanit":"ifsa"}\'>İfşa</button></div></div>';
  if(p.yonetebilir) h+='<form data-meydan-form="kirmizi_hat" data-id="'+id+'"><label>Kırmızı hat</label><select name="tur"><option value="bakanlik">Bakanlık sözü</option><option value="yatirim">İle yatırım</option><option value="af">Af</option></select><textarea name="metin" required></textarea><button class="hh-action">Gizli teklif</button></form>';
  (e.basin||[]).forEach(b=>{h+='<blockquote><b>'+esc(b.ad)+'</b> · güvenilir '+b.guvenilir+' · taraflı '+b.tarafli+'<br>'+esc(b.metin)+'<div class="hh-grid"><button class="hh-action" data-meydan-islem="basin_oy" data-id="'+id+'" data-v=\'{"id":'+Number(b.id)+',"oy":"guvenilir"}\'>Güvenilir</button><button class="hh-action" data-meydan-islem="basin_oy" data-id="'+id+'" data-v=\'{"id":'+Number(b.id)+',"oy":"tarafli"}\'>Taraflı</button></div></blockquote>';});
  if(p.gazeteci) h+='<form data-meydan-form="basin_yaz" data-id="'+id+'"><textarea name="metin" required placeholder="Sahadan canlı not"></textarea><button class="hh-action">Yayınla</button></form>';
  if(e.juri) h+='<p>Halk jürisi: '+esc(e.juri.durum)+' '+(e.juri.sonuc?esc(e.juri.sonuc):'')+'</p>'+(e.juri.sozler||[]).map(s=>'<p><b>'+esc(s.taraf)+':</b> '+esc(s.metin)+'</p>').join('')+(e.juri.uyeyim&&e.juri.durum==='oy'?'<div class="hh-grid"><button class="hh-action" data-meydan-islem="juri_oy" data-id="'+id+'" data-v=\'{"oy":"meydan"}\'>Meydan</button><button class="hh-action" data-meydan-islem="juri_oy" data-id="'+id+'" data-v=\'{"oy":"hukumet"}\'>Hükümet</button></div>':'')+(e.baslatan||p.yonetebilir?'<form data-meydan-form="juri_savun" data-id="'+id+'"><input name="metin" maxlength="180" required placeholder="Kısa söz"><button class="hh-action">Sözü yaz</button></form>':'');
  (e.boykot||[]).forEach(b=>{h+='<p>Boykot şirket #'+Number(b.sirket)+' · söz '+Number(b.soz||0)+' · müşteri '+esc(b.musteri??100)+' · '+esc(b.taraf||'yanıt yok')+' <button class="hh-action" data-meydan-islem="boykot_soz" data-id="'+id+'" data-v=\'{"id":'+Number(b.id)+'}\'>Söz veriyorum</button></p><form data-meydan-form="boykot_taraf" data-id="'+id+'"><input type="hidden" name="id" value="'+Number(b.id)+'"><select name="taraf"><option value="destekliyorum">Destekliyorum</option><option value="tarafsizim">Tarafsızım</option><option value="hukumetin_yanindayim">Hükümetin yanındayım</option></select><button class="hh-action">Şirket açıklaması</button></form>';});
  if(e.katilimci) h+='<form data-meydan-form="boykot_ac" data-id="'+id+'"><input name="sirket" type="number" required placeholder="Şirket numarası"><button class="hh-action">Boykot aç</button></form>';
  (p.hafiza||[]).filter(x=>x.oradaydim).forEach(x=>{h+='<form data-meydan-form="hafiza_oy" data-id="'+Number(x.eylem)+'"><input name="ad" maxlength="40" placeholder="'+esc(x.ad)+' için yeni ad"><button class="hh-action">Eylemin adını oyla</button></form>';});
  (e.belgeler||[]).forEach(b=>{h+='<p>İç not #'+Number(b.id)+' · '+esc(b.tur)+' · '+esc(b.metin)+(b.yayin?' · yayımlandı':'')+'</p>'+(p.kabine&&!b.yayin?'<form data-meydan-form="belge_sizdir" data-id="'+id+'"><input type="hidden" name="id" value="'+Number(b.id)+'"><input name="kad" required placeholder="Gazetecinin kullanıcı adı"><button class="hh-action">Belgeyi sızdır</button></form>':'')+(p.yonetebilir&&b.yayin&&!b.sorusturma?'<form data-meydan-form="belge_sorustur" data-id="'+id+'"><input type="hidden" name="id" value="'+Number(b.id)+'"><input name="kad" required placeholder="Şüphelinin kullanıcı adı"><button class="hh-action">Soruşturma aç</button></form>':'');});
  (e.mektuplar||[]).forEach(m=>{h+='<blockquote>'+esc(m.sahip)+': '+esc(m.metin)+'</blockquote>';});
  if(p.yonetebilir&&Number(e.seviye)>=60) h+='<button class="hh-action" data-meydan-islem="juri_baslat" data-id="'+id+'">Halk jürisini kur</button>';
  if(p.iktidar) h+='<form data-meydan-form="mektup_yaz" data-id="'+id+'"><textarea name="metin" required placeholder="İmzasız destek mektubu"></textarea><button class="hh-action">Mektubu bırak</button></form><form data-meydan-form="mektup_sor" data-id="'+id+'"><input name="id" type="number" required placeholder="Mektup no"><input name="kad" required placeholder="Şüphelinin kullanıcı adı"><button class="hh-action">Mektup soruşturması</button></form>';
  if(e.katilimci) h+='<form data-meydan-form="mesale_gonder" data-id="'+id+'"><input name="il" type="number" min="1" max="81" required placeholder="Meşalenin gideceği il"><button class="hh-action">Meşaleyi yolla</button></form>';
  h+='</article>';
 }
 if(p.vekil&&p.iktidar&&p.eylemler&&p.eylemler[0]) h+='<button class="hh-action" data-meydan-islem="meclis_gec" data-id="'+Number(p.eylemler[0].id)+'">Mecliste saf değiştirip meydana geç</button>';
 if(p.bakan) h+='<form data-meydan-form="istifa"><textarea name="metin" required placeholder="İstifa mektubu"></textarea><button class="hh-action hh-ayril">İstifayı yayımla</button></form>';
 (p.kabine_gizli||[]).forEach(k=>{h+='<p>Gizli kabine oyu #'+Number(k.id)+': '+esc(k.metin)+' · açıklanma '+esc(saat(k.aciklama))+'<button class="hh-action" data-meydan-islem="kabine_oy" data-v=\'{"id":'+Number(k.id)+',"oy":"evet"}\'>Evet</button><button class="hh-action" data-meydan-islem="kabine_oy" data-v=\'{"id":'+Number(k.id)+',"oy":"hayir"}\'>Hayır</button></p>';});
 if(p.meclis_hak) h+='<form data-meydan-form="gensoru_ac"><textarea name="metin" required placeholder="Gensoru gerekçesi"></textarea><button class="hh-action">Gensoru aç</button></form>';
 (p.mesale||[]).filter(m=>m.durum==='yolda'&&p.yonetebilir).forEach(m=>{h+='<button class="hh-action" data-meydan-islem="mesale_kir" data-v=\'{"id":'+Number(m.id)+'}\'>Meşale zincirini kes</button>';});
 if(Array.isArray(denetim)&&denetim.length) h+=kart('Denetim kaydı',denetim.map(d=>'<p>'+esc(saat(d.zaman))+' · '+esc(d.tur)+' · '+esc(d.yapan||'')+' → '+esc(d.hedef||'')+' · '+esc(d.metin||'')+'</p>').join(''));
 h+='</section>';
 const eski=root.querySelector('#hhMeydanEk'); if(eski)eski.remove();
 root.insertAdjacentHTML('afterbegin',h);
 async function sohbetCek(id){
  const kutu=root.querySelector('[data-sohbet="'+id+'"]'); if(!kutu)return;
  try{const rows=await API.rpc('sokak_sohbet_oku',{p_eylem:id}); kutu.innerHTML=(rows||[]).slice().reverse().map(m=>'<p><b>'+esc(m.ad)+'</b> '+esc(m.metin)+'</p>').join('')||'<p class="hh-muted">Henüz mesaj yok.</p>';}
  catch(ex){kutu.textContent='Sohbet açılamadı';}
 }
 const hh4Acik=!!(window.__hh4&&!window.__hh4.klasik);
 (p.eylemler||[]).forEach(e=>{if(e.sohbet_hak&&!hh4Acik)sohbetCek(Number(e.id));});
 const rt=typeof API!=='undefined'&&API.realtimeClient&&!hh4Acik;
 if(rt){(p.eylemler||[]).forEach(e=>{if(!e.sohbet_hak)return; const id=Number(e.id); try{rt.channel('eylem-sohbet-'+id).on('postgres_changes',{event:'INSERT',schema:'public',table:'sokak_eylem_sohbet',filter:'eylem_id=eq.'+id},()=>sohbetCek(id)).subscribe();}catch(err){}}); }
 root.querySelectorAll('[data-meydan-islem]').forEach(b=>b.addEventListener('click',()=>{
  let v={}; try{v=JSON.parse(b.dataset.v||'{}');}catch(_){}
  islem(b,b.dataset.id?Number(b.dataset.id):null,b.dataset.meydanIslem,v);
 }));
 root.querySelectorAll('form[data-meydan-form]').forEach(f=>f.addEventListener('submit',ev=>{
  ev.preventDefault(); const ad=f.dataset.meydanForm; const v=Object.fromEntries(new FormData(f).entries()); const id=f.dataset.id?Number(f.dataset.id):null;
  if(ad==='sohbet'){const btn=f.querySelector('button'); btn.disabled=true; API.rpc('sokak_sohbet_yaz',{p_eylem:id,p_metin:v.metin}).then(()=>{f.reset();btn.disabled=false;sohbetCek(id);}).catch(ex=>{toast(ex.message,true);btn.disabled=false;});return;}
  if(ad==='muhbir_teklif') v.para=Number(v.para||0);
  if(ad==='boykot_ac') v.sirket=Number(v.sirket);
  if(ad==='hafiza_oy'){islem(f.querySelector('button'),id,'hafiza_oy',{ad:v.ad});return;}
  islem(f.querySelector('button'),id,ad,v);
 }));
};
if(window.__hhSar)sokakHareketleriEkrani=window.__hhSar('meydan',sokakHareketleriEkrani);
})();

/* Asset refresh: 20261109-5 (eylem merkezi) */
(function(){
'use strict';
if(typeof sokakHareketleriEkrani!=='function')return;
if(!document.getElementById('em-stil')){
 const st=document.createElement('style'); st.id='em-stil';
 st.textContent='.em{margin:12px 0;padding:12px;border:1px solid #3d4d78;border-radius:16px;background:#10182e;color:#eef2ff}.em-ust{display:grid;gap:8px}.em-kicker{margin:0;letter-spacing:.08em;text-transform:uppercase;font-size:11px;color:#9eb0da}.em-sayi{font-size:28px;line-height:1.1}.em-bar{height:10px;border-radius:99px;background:#243154;overflow:hidden}.em-bar>span{display:block;height:100%;background:linear-gradient(90deg,#d46a4c,#e7b15a)}.em-ticker small{display:block;color:#b7c3e4}.em-oneri{margin:0;padding:8px 10px;border-radius:12px;background:#1a2748}.em-sekme{display:flex;gap:6px;overflow:auto;margin:10px 0}.em-sekme button{border:0;border-radius:999px;padding:8px 12px;background:#243154;color:#eef2ff}.em-sekme button.acik{background:#e7b15a;color:#1b1408}.em-grid{display:grid;grid-template-columns:1fr;gap:8px}@media(min-width:720px){.em-grid{grid-template-columns:1fr 1fr}}.em-kart{text-align:left;border:1px solid #3d4d78;border-radius:14px;padding:10px;background:#16213c;color:#eef2ff}.em-kart.secili{border-color:#e7b15a}.em-kart b{display:block}.em-kart small{color:#b7c3e4}.em-form{display:flex;flex-direction:column;gap:8px;margin-top:8px}.em-form textarea,.em-form select,.em-form input{width:100%;box-sizing:border-box;min-height:44px;border-radius:12px;border:1px solid #7180ab;background:#0d1428;color:#f5f7ff;padding:10px}.em-cekis{display:flex;height:16px;border-radius:99px;overflow:hidden;background:#243154}.em-cekis i{display:block;height:100%}.em-sayac{font-variant-numeric:tabular-nums;font-size:22px}.em-arsiv{margin-top:8px}';
 document.head.appendChild(st);
}
const HAMLE=[
 ['grev','✊','Genel Grev','İl kasasına giren para azalır.','150.000 TL'],
 ['yol','🚧','Yol Kapatma','İl geliri ve memnuniyet geriler.','80.000 TL'],
 ['aclik','🕯️','Açlık Grevi','Sempati saatle artar. Taktik kapanır.','0 TL'],
 ['vergi','🧾','Vergi İtaatsizliği','İl geliri düşer. Para cezası riski var.','120.000 TL'],
 ['oturma','🏛️','Bakanlık Önü Oturma','Seçilen bakanın itibarı geriler.','60.000 TL'],
 ['uluslararasi','🌍','Uluslararası Kamuoyu','Manşet ve memnuniyet bedeli.','100.000 TL'],
 ['zincir','🔗','Sivil İtaatsizlik Zinciri','Üç ilde eylem ister.','80.000 TL'],
 ['gensoru','📜','Gensoru Baskısı','İçişleri için meclis önergesi.','70.000 TL'],
 ['kalkan','🛡️','Boykot Kalkanı','İhale ve mali kuşatmayı durdurur.','90.000 TL'],
 ['isgal','🏢','Sembolik İşgal','Belediye veya valilik kararları durur.','200.000 TL']
];
const tl=n=>Number(n||0).toLocaleString('tr-TR')+' TL';
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function oneri(r){
 const t=r.isgal&&r.isgal.tahliye;
 if(t&&t.durum==='geri_sayim') return (r.yetkili||r.iktidar)?'Önerilen: operasyona katıl. Geri sayım sürüyor.':'Önerilen: binayı savun. Geri sayım sürüyor.';
 if(r.isgal&&r.isgal.durum==='aktif'&&r.katilimci&&Number(r.isgal.nobet)<2) return 'Önerilen: bina nöbeti. Nöbet seyrelirse işgal dağılır.';
 if(Number(r.saat)===0&&r.katilimci) return 'Önerilen: gece meşalesi. Işığını yak.';
 if(r.yetkili&&Number(r.seviye)>=60) return 'Önerilen: kuşatma ya da tahliye. Meydan kalabalık.';
 if(r.katilimci) return 'Önerilen: genel grev. İl gelirini keser, bedeli büyüktür.';
 return 'Önerilen: önce eyleme katıl. Hükümet yetkisi varsa bütçe sekmesine bak.';
}
function ayrilSatiri(ben){
 if(!ben||!ben.length) return '';
 return '<div class="em-grid">'+ben.map(b=>'<button type="button" class="em-kart em-ayril" data-em-ayril="'+esc(b.tur)+'" data-em-alt="'+esc(b.alt||'')+'">Ayrıl · '+esc(b.ad)+'</button>').join('')+'</div>';
}
function merkezHTML(r,td,sd,ben){
 const id=Number(r.id); const h=r.hazine||{}; const ig=r.isgal||null; const tv=ig&&ig.tahliye;
 const sem=Math.max(0,Math.min(100,Number(r.nabiz)||0));
 let x='<section class="em" data-em="'+id+'"><header class="em-ust"><div><p class="em-kicker">Eylem Merkezi</p><div class="em-sayi">'+Number(r.katilim||0)+' kişi</div><small>İl memnuniyeti '+esc(r.memnuniyet)+' · nabız '+esc(r.nabiz)+'</small></div>';
 x+='<div class="em-bar" aria-label="Nabız"><span style="width:'+sem+'%"></span></div>';
 if(arguments[4]){
  const d=arguments[4];
  x+='<div class="em-bar" aria-label="İvme"><span style="width:'+Math.max(0,Math.min(100,Number(d.ivme)||0))+'%;background:#7dcea0"></span></div><small>İvme '+esc(d.ivme)+' / 100</small>';
  x+='<div class="em-bar" aria-label="Yorgunluk"><span style="width:'+Math.max(0,Math.min(100,Number(d.yorgunluk)||0))+'%;background:#d46a4c"></span></div><small>Yorgunluk '+esc(d.yorgunluk)+' / 100 · tavan '+esc(d.tavan)+' kişi</small>';
  if(d.not) x+='<p class="em-oneri">'+esc(d.not)+'</p>';
 }
 x+='<div class="em-ticker">Eylemin hazineye maliyeti <b>'+tl(h.toplam_tl)+'</b><small>Saatlik '+tl(h.saatlik_tl)+'</small></div>';
 if(arguments[5]) x+='<div class="em-ticker">Eyleme aktarılan kaynak <b>'+tl(arguments[5].toplam)+'</b>'+(arguments[5].sinyal?'<small>Eyleme büyük kaynak aktarılıyor</small>':'')+'</div>';
 x+='<p class="em-oneri">'+esc(oneri(r))+'</p></header>';
 if(tv&&tv.durum==='geri_sayim'){
  const g=Number(tv.hukumet||0), s=Number(tv.savun||0)+(ig.nobet||0); const top=Math.max(1,g+s); const yuz=Math.round(100*g/top);
  x+='<div class="em-sayac" data-em-bit="'+esc(tv.bitis)+'">Tahliye geri sayımı</div><div class="em-cekis" aria-label="Tahliye dengesi"><i style="width:'+yuz+'%;background:#8ea2d6"></i><i style="width:'+(100-yuz)+'%;background:#d46a4c"></i></div><small>Operasyon '+g+' · Savunma '+(s)+'</small>';
 }
 x+='<div class="em-sekme"><button type="button" class="acik" data-em-tab="eylem">Eylemci</button><button type="button" data-em-tab="hukumet">Hükümet</button><button type="button" data-em-tab="isgal">Kuşatma</button><button type="button" data-em-tab="butce">Bütçe</button></div>';
 const eng=(arguments[4]&&arguments[4].engel)||{};
 x+='<div data-em-panel="eylem">'+ayrilSatiri(ben)+'<div class="em-grid">'+HAMLE.map(k=>'<button type="button" class="em-kart" data-em-kart="'+k[0]+'"'+(eng[k[0]]?' disabled':'')+'><b>'+k[1]+' '+k[2]+'</b><small>'+k[3]+'</small><small>'+(eng[k[0]]?esc(eng[k[0]]):'Bedel '+k[4])+'</small></button>').join('')+'</div>';
 x+='<div class="em-grid"><button type="button" class="em-kart" data-em-islem="mesale">🌙 Gece meşalesi · 00.00</button><button type="button" class="em-kart" data-em-islem="aclik">Açlık grevine yazıl</button><button type="button" class="em-kart" data-em-islem="nobet">Bina nöbeti · 1 saat</button><button type="button" class="em-kart" data-em-islem="ziyaret">Dayanışma ziyareti</button><button type="button" class="em-kart" data-em-islem="savun">Binayı savun</button><button type="button" class="em-kart" data-em-islem="katil">Eyleme katıl</button></div>';
 x+='<form class="em-form" data-em-form="kaynak"><label>Eyleme kaynak aktar</label><select name="kalem"><option value="ses">Ses sistemi</option><option value="ulasim">Ulaşım</option><option value="yemek">Yemek</option><option value="pankart">Pankart</option></select><select name="kaynak"><option value="parti">Örgütleyen parti</option><option value="dernek">Örgütleyen dernek</option><option value="oyuncu">Kendi cüzdanım</option></select><input name="kaynak_id" type="number" placeholder="Parti veya dernek no"><input name="tutar" type="number" min="10000" step="1" required placeholder="TL"><button class="hh-action hh-primary" type="submit">Kaynağı aktar</button></form>';
 x+='<form class="em-form" data-em-form="hamle"><input type="hidden" name="tur" value="grev"><label>Seçilen hamle</label><p class="em-secim">Genel Grev</p><label>Bina, yalnız işgalde</label><select name="bina"><option value="belediye">Belediye</option><option value="valilik">Valilik</option></select><label>Bakanlık, yalnız oturmada</label><input name="bakanlik" value="icisleri" maxlength="40"><label>Gerekçe</label><textarea name="gerekce" minlength="20" maxlength="300" required>Bu hamle ortak kararımızdır.</textarea><button class="hh-action hh-primary" type="submit">Hamleyi başlat</button></form>';
 x+='<form class="em-form" data-em-form="sizma"><label>İçeriden sızan not</label><textarea name="metin" maxlength="400" required placeholder="Hükümet planı"></textarea><button class="hh-action" type="submit">Notu eylem sohbetine bırak</button></form>';
 x+='</div>';
 const YAD={hizmet:'Acil Hizmet Seferberliği',vergi_tatil:'Bölgesel Vergi Tatili',istihdam:'İstihdam Taahhüt Paketi',brifing:'Resmi Basın Brifingi',sosyal_kart:'Acil Sosyal Destek Kartı',guzergah:'Güvenli Alan',komisyon:'Meclis Araştırma Komisyonu',gozlemci:'Bağımsız Gözlemci',kapi:'İktidar Kapı Kapı',gece:'Gece Toplanma Kısıtı',iletisim:'İletişim Yavaşlatma',festival:'Kültür-Festival'};
 const SAD={safak:'Şafak Operasyonu',elebasi:'Elebaşı Gözaltısı',mali:'Mali Kuşatma',kapatma:'Kapatma Davası Tehdidi',ohal:'OHAL',propaganda:'Kara Propaganda',bol:'Böl ve Yönet',kusatma:'Kuşatma Çemberi',ihale:'İhale ve Lisans Kılıcı',sanal:'Toplu Sanal Gözaltı'};
 const yumusak=(td&&td.acabilir)||Object.keys(YAD);
 const sert=(sd&&sd.bedeller)?Object.keys(sd.bedeller):Object.keys(SAD);
 x+='<div data-em-panel="hukumet" hidden><p>Yumuşak ve sert araçlar İçişleri bütçesinden düşer. Kasada para yoksa işlem açılmaz.</p>'+(arguments[5]&&arguments[5].sinyal?'<p class="em-oneri">Eyleme büyük kaynak aktarılıyor. Mali kuşatma ve ihale kılıcı bu izi daha sert kullanır.</p>':'');
 x+='<form class="em-form" data-em-form="tedbir"><label>Yumuşak araç</label><select name="tur">'+yumusak.map(k=>'<option value="'+esc(k)+'">'+esc(YAD[k]||k)+'</option>').join('')+'</select><textarea name="gerekce" minlength="20" maxlength="500" required>Bu aracı kamu bütçesinden uyguluyoruz.</textarea><button class="hh-action" type="submit">Yumuşak aracı uygula</button></form>';
 x+='<form class="em-form" data-em-form="sert"><label>Sert önlem</label><select name="tur">'+sert.map(k=>'<option value="'+esc(k)+'">'+esc(SAD[k]||k)+'</option>').join('')+'</select><textarea name="gerekce" minlength="20" maxlength="500" required>Bu sert önlemin gerekçesi kamuoyuna açıktır.</textarea><button class="hh-action" type="submit">Sert önlemi uygula</button></form></div>';
 x+='<div data-em-panel="isgal" hidden><p>'+(ig?esc(ig.bina)+' · '+esc(ig.durum)+' · güç '+esc(ig.guc)+' · nöbet '+Number(ig.nobet||0)+' · kuşatma '+Number(ig.kusatma||0):'Henüz işgal yok.')+'</p>';
 if(ig&&ig.teklif) x+='<p>Teklif: '+esc(ig.teklif.metin)+'</p><div class="em-grid"><button type="button" class="em-kart" data-em-islem="muzakere_oy" data-oy="evet">Teklifi kabul et</button><button type="button" class="em-kart" data-em-islem="muzakere_oy" data-oy="hayir">Teklifi reddet</button></div>';
 x+='<div class="em-grid"><button type="button" class="em-kart" data-em-islem="kusatma">Kuşatma başlat · 200.000 TL</button><button type="button" class="em-kart" data-em-islem="kusatma_nobet">Kuşatma nöbeti · 1 saat</button><button type="button" class="em-kart" data-em-islem="tahliye">Tahliye emri · 250.000 TL</button><button type="button" class="em-kart" data-em-islem="operasyon">Operasyona katıl</button></div>';
 x+='<form class="em-form" data-em-form="muzakere"><label>Müzakere teklifi · 100.000 TL</label><textarea name="metin" minlength="20" maxlength="400" required>Binayı boşaltırsanız talebin bir kısmını uygularız.</textarea><button class="hh-action" type="submit">Teklifi gönder</button></form></div>';
 x+='<div data-em-panel="butce" hidden><p>Her hükümet müdahalesi İçişleri kasasından çıkar. Eylem sürdükçe hazine, kalabalık ve sert hamleyle artan bir saatlik bedel yazar. Tutar iki tarafta da görünür.</p><p>Biriken: <b>'+tl(h.toplam_tl)+'</b></p><p>Saatlik: <b>'+tl(h.saatlik_tl)+'</b></p><a href="#hhMeydanEk">Sohbet ve muhbir avı</a></div></section>';
 return x;
}
const onceki=sokakHareketleriEkrani;
sokakHareketleriEkrani=async function(){
 await onceki.apply(this,arguments);
 const root=document.getElementById('hhCommand'); if(!root)return;
 let m=null,td=null,sd=null,denge=null,kaynak=null; const listeler={}; const kaynakHarita={};
 try{m=await API.rpc('sokak_eylem_merkezi');}catch(err){console.warn('Eylem merkezi',err);}
 try{denge=await API.rpc('sokak_denge_panel');}catch(err){console.warn('Denge',err);}
 try{kaynak=await API.rpc('sokak_kaynak_ozet');}catch(err){}
 ((kaynak&&kaynak.eylemler)||[]).forEach(r=>{kaynakHarita[Number(r.id)]=r;});
 try{td=await API.rpc('sokak_tedbir_panel');}catch(err){}
 try{sd=await API.rpc('sokak_sert_panel');}catch(err){}
 await Promise.all(((m&&m.eylemler)||[]).map(async r=>{try{listeler[Number(r.id)]=await API.rpc('sokak_katilim_liste',{p_eylem:Number(r.id)});}catch(err){}}));
 const harita={}; ((m&&m.eylemler)||[]).forEach(r=>{harita[Number(r.id)]=r;});
 const dengeHarita={}; ((denge&&denge.eylemler)||[]).forEach(r=>{
  const kat=Number(r.katilim||0), nab=Number(r.nabiz||0), iv=Number(r.ivme||0);
  const buyuk=iv<(denge.ayar&&denge.ayar.buyuk_ivme)||kat<(denge.ayar&&denge.ayar.buyuk_katilim)||nab<(denge.ayar&&denge.ayar.buyuk_nabiz);
  r.engel=buyuk?{grev:'İvme, kalabalık ya da nabız büyük hamle için yetersiz',isgal:'İvme, kalabalık ya da nabız büyük hamle için yetersiz',zincir:'İvme, kalabalık ya da nabız büyük hamle için yetersiz'}:{};
  dengeHarita[Number(r.id)]=r;
 });
 const ay=denge&&denge.ayar||{};
 let cagri='<section class="em" id="emCagri"><p class="em-kicker">Eylem çağrısı</p><p>Eylem keyfi açılmaz. İlde memnuniyet '+esc(ay.memnuniyet_esik)+' altında olmalı ya da son '+esc(ay.olay_saat)+' saatte sert önlem, skandal veya manşet olmalı. Depozito '+tl(ay.depozito)+' çağrı düşerse yanar. '+esc(ay.imza_sayisi)+' ayrı il sakini '+esc(ay.imza_saat)+' saat içinde imzalar. İlde '+esc(ay.il_bekleme_saat)+' saatte bir, organizatörde '+esc(ay.orgut_bekleme_saat)+' saatte bir yeni eylem. Ülke tavanı '+esc(ay.ulke_tavan)+'.</p>';
 cagri+=(denge&&denge.cagrilar||[]).map(c=>'<div class="em-kart"><b>Çağrı #'+Number(c.id)+' · '+esc(c.durum)+'</b><p>'+esc(c.gerekce)+'</p><p>İmza '+Number(c.imza||0)+' / '+Number(c.gerek||0)+'</p>'+(c.hata?'<p>'+esc(c.hata)+'</p>':'')+(c.benim&&c.durum==='hazir'?'<button type="button" class="hh-action" data-em-cagri="tamamla" data-id="'+Number(c.id)+'">Çağrıyı eyleme çevir</button>':'')+(!c.benim&&!c.imzaladim&&c.durum==='imza'?'<button type="button" class="hh-action" data-em-cagri="imza" data-id="'+Number(c.id)+'">İmza ver</button>':'')+'</div>').join('');
 cagri+='<form class="em-form" data-em-form="cagri"><label>İl numarası</label><input name="il" type="number" min="1" max="81" required><label>Talep</label><select name="talep"><option value="genel">Genel</option><option value="hizmet">Hizmet</option><option value="issizlik">İşsizlik</option><option value="vergi">Vergi</option></select><label>Kuruluş</label><select name="kaynak"><option value="parti">Parti</option><option value="dernek">Dernek</option></select><label>Kuruluş numarası</label><input name="kaynak_id" type="number" required><label>Gerekçe</label><textarea name="gerekce" minlength="20" maxlength="400" required></textarea><button class="hh-action hh-primary" type="submit"'+(ay.depozito==null?' disabled':'')+'>Çağrıyı aç</button></form></section>';
 root.querySelector('#emCagri')?.remove();
 root.insertAdjacentHTML('afterbegin',cagri);
 const tdHarita={}; ((td&&td.eylemler)||[]).forEach(r=>{tdHarita[Number(r.id)]=r;});
 const sdHarita={}; ((sd&&sd.eylemler)||[]).forEach(r=>{sdHarita[Number(r.id)]=r;});
 root.querySelectorAll('article.hh-event').forEach(art=>{
  const id=Number(art.getAttribute('data-hh-event')); const row=harita[id]; if(!row)return;
  art.querySelector(':scope > .em')?.remove();
  art.insertAdjacentHTML('afterbegin',merkezHTML(row,tdHarita[id],sdHarita[id],(listeler[id]&&listeler[id].ben)||[],dengeHarita[id],kaynakHarita[id]));
  if(!art.querySelector(':scope > .em-arsiv')){
   const arsiv=document.createElement('details'); arsiv.className='em-arsiv';
   arsiv.innerHTML='<summary>Eski düğme listesi</summary>';
   art.querySelectorAll(':scope > .hh-saha, :scope > details.hh-detail').forEach(n=>arsiv.appendChild(n));
   if(arsiv.children.length>1) art.appendChild(arsiv);
  }
 });
 const kos=async(btn,fn,args)=>{
  if(btn)btn.disabled=true;
  try{await API.rpc(fn,args); toast('Kaydedildi'); await sokakHareketleriEkrani();}
  catch(ex){toast((typeof hataCevir==='function'?hataCevir(ex.message||String(ex)):String(ex.message||ex)),true); if(btn)btn.disabled=false;}
 };
 root.querySelectorAll('.em').forEach(kutu=>{
  const id=Number(kutu.getAttribute('data-em'));
  if(!id) return;
  kutu.querySelectorAll('[data-em-tab]').forEach(b=>b.addEventListener('click',()=>{
   kutu.querySelectorAll('[data-em-tab]').forEach(x=>x.classList.toggle('acik',x===b));
   kutu.querySelectorAll('[data-em-panel]').forEach(p=>{p.hidden=p.getAttribute('data-em-panel')!==b.getAttribute('data-em-tab');});
  }));
  kutu.querySelectorAll('[data-em-kart]').forEach(b=>b.addEventListener('click',()=>{
   kutu.querySelectorAll('[data-em-kart]').forEach(x=>x.classList.toggle('secili',x===b));
   const tur=b.getAttribute('data-em-kart'); const form=kutu.querySelector('[data-em-form=hamle]');
   if(!form||b.disabled) return;
   form.querySelector('[name=tur]').value=tur;
   const ad=HAMLE.find(k=>k[0]===tur);
   form.querySelector('.em-secim').textContent=ad?ad[1]+' '+ad[2]:tur;
  }));
  kutu.querySelectorAll('[data-em-islem]').forEach(b=>b.addEventListener('click',()=>{
   const ad=b.getAttribute('data-em-islem');
   if(ad==='katil'){kos(b,'sokak_destek',{p_eylem:id,p_taraf:'muhalefet'});return;}
   if(b.classList.contains('em-ayril'))return;
   if(ad==='muzakere_oy'){kos(b,'sokak_eylem_merkezi_islem',{p_eylem:id,p_islem:'muzakere_oy',p_veri:{oy:b.getAttribute('data-oy')}});return;}
   kos(b,'sokak_eylem_merkezi_islem',{p_eylem:id,p_islem:ad,p_veri:{}});
  }));
  kutu.querySelectorAll('[data-em-ayril]').forEach(b=>b.addEventListener('click',()=>{
   if(!window.confirm('Bu katılımdan ayrılmak istediğine emin misin? Ödenen bedel geri gelmez.')) return;
   kos(b,'sokak_katilim_ayril',{p_eylem:id,p_tur:b.getAttribute('data-em-ayril'),p_alt:b.getAttribute('data-em-alt')||null});
  }));
  kutu.querySelector('[data-em-form=kaynak]')?.addEventListener('submit',ev=>{
   ev.preventDefault(); const f=new FormData(ev.currentTarget);
   if(!window.confirm('Bu para eyleme aktarılacak ve geri gelmez. Emin misin?')) return;
   kos(ev.currentTarget.querySelector('button'),'sokak_kaynak_aktar',{p_eylem:id,p_kaynak:String(f.get('kaynak')),p_kaynak_id:f.get('kaynak_id')?Number(f.get('kaynak_id')):null,p_kalem:String(f.get('kalem')),p_tutar:Number(f.get('tutar'))});
  });
  kutu.querySelector('[data-em-form=hamle]')?.addEventListener('submit',ev=>{
   ev.preventDefault(); const f=new FormData(ev.currentTarget); const tur=String(f.get('tur'));
   const suruyor=(harita[id].hamleler||[]).some(h=>h.tur===tur&&h.durum==='aktif');
   if(suruyor&&['grev','yol','vergi'].includes(tur)&&!kutu.querySelector('[data-em-ayril="'+tur+'"]')){
    kos(ev.currentTarget.querySelector('button'),'sokak_hamle_kisi_katil',{p_eylem:id,p_tur:tur}); return;
   }
   kos(ev.currentTarget.querySelector('button'),'sokak_eylem_merkezi_islem',{p_eylem:id,p_islem:'hamle',p_veri:{tur:tur,gerekce:String(f.get('gerekce')),bina:String(f.get('bina')),bakanlik:String(f.get('bakanlik'))}});
  });
  kutu.querySelector('[data-em-form=sizma]')?.addEventListener('submit',ev=>{
   ev.preventDefault(); kos(ev.currentTarget.querySelector('button'),'sokak_eylem_merkezi_islem',{p_eylem:id,p_islem:'sizma',p_veri:{metin:String(new FormData(ev.currentTarget).get('metin'))}});
  });
  kutu.querySelector('[data-em-form=tedbir]')?.addEventListener('submit',ev=>{
   ev.preventDefault(); const f=new FormData(ev.currentTarget);
   kos(ev.currentTarget.querySelector('button'),'sokak_tedbir_ac',{p_eylem:id,p_tur:String(f.get('tur')),p_gerekce:String(f.get('gerekce'))});
  });
  kutu.querySelector('[data-em-form=sert]')?.addEventListener('submit',ev=>{
   ev.preventDefault(); const f=new FormData(ev.currentTarget);
   kos(ev.currentTarget.querySelector('button'),'sokak_sert_islem',{p_eylem:id,p_islem:'ac',p_veri:{tur:String(f.get('tur')),gerekce:String(f.get('gerekce'))}});
  });
  kutu.querySelector('[data-em-form=muzakere]')?.addEventListener('submit',ev=>{
   ev.preventDefault(); kos(ev.currentTarget.querySelector('button'),'sokak_eylem_merkezi_islem',{p_eylem:id,p_islem:'muzakere',p_veri:{metin:String(new FormData(ev.currentTarget).get('metin'))}});
  });
 });
 root.querySelectorAll('[data-em-cagri]').forEach(b=>b.addEventListener('click',()=>{
  const ad=b.getAttribute('data-em-cagri');
  kos(b, ad==='imza'?'sokak_cagri_imza':'sokak_cagri_tamamla',{p_cagri:Number(b.getAttribute('data-id'))});
 }));
 root.querySelector('[data-em-form=cagri]')?.addEventListener('submit',ev=>{
  ev.preventDefault(); const f=new FormData(ev.currentTarget);
  kos(ev.currentTarget.querySelector('button'),'sokak_cagri_ac',{p_il:Number(f.get('il')),p_gerekce:String(f.get('gerekce')),p_talep:String(f.get('talep')),p_kaynak:String(f.get('kaynak')),p_kaynak_id:Number(f.get('kaynak_id'))});
 });
 if(window.__emSayac) clearInterval(window.__emSayac);
 window.__emSayac=setInterval(()=>{
  document.querySelectorAll('[data-em-bit]').forEach(el=>{
   const ms=new Date(el.getAttribute('data-em-bit')).getTime()-Date.now();
   const sn=Math.max(0,Math.floor(ms/1000));
   el.textContent='Tahliye geri sayımı '+String(Math.floor(sn/60)).padStart(2,'0')+':'+String(sn%60).padStart(2,'0');
  });
 },1000);
};
if(window.__hhSar)sokakHareketleriEkrani=window.__hhSar('merkez2',sokakHareketleriEkrani);
})();

/* ═══════════════════════════════════════════════════════════════════════════
   HALK HAREKETLERİ 4.0 · EYLEM MEYDANI (09.11.2026)
   Önceki katmanların hepsi (temel, org, finans, merkez, saha, meydan, merkez2)
   veriyi ve işlemleri sağlamaya devam eder; bu katman ekranı tek, düzenli bir
   uygulamaya çevirir:
   · Ana ekran: rolün, sana bekleyen işler (gelen kutusu), ulusal kriz göstergesi,
     canlı meydan kartları, eylem çağrısı sihirbazı, kriz haritası, geçmiş.
   · Eylem alanı: canlı meydan sahnesi (her gerçek katılımcı bir kişi), güç halkası,
     uyarı şeritleri ve sekmeler: Akış · Sohbet · Hamleler · Devlet · Kurumlar · Güç.
   · Bütün işlemler tek bir hamle kataloğundan çizilir: aynı kart, aynı alt sayfa.
   · "Klasik ekran" kaçış kapısı eski düzeni açar; hiçbir işlev kaybolmaz.
   Sunucu eki: supabase/migrations/20261109270000_halk_eylem_meydani.sql
   ═══════════════════════════════════════════════════════════════════════════ */
(function(){
'use strict';
if(typeof sokakHareketleriEkrani!=='function'||typeof iskelet!=='function')return;
const klasik=sokakHareketleriEkrani;
const S=window.__hh4||(window.__hh4={gorunum:'ana',eylem:null,sekme:'akis',klasik:false,taslak:{},akisFiltre:'hepsi',model:null,akis:{},sohbet:{},acik:{}});

/* ── stil ── */
if(!document.getElementById('hh4-stil')){
 const st=document.createElement('style');st.id='hh4-stil';
 st.textContent=`
#hh4{--k:#0a1024;--p:#111a33;--p2:#17223f;--c:#2b3a64;--t:#eef2ff;--m:#a8b4d4;--r:#ff5d6c;--o:#ff9b45;--y:#ffd166;--g:#46d39f;--b:#6ea8ff;--v:#a08cff;
 font:400 15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;color:var(--t);margin:-4px -4px 0;padding:0 0 30px;min-width:0}
#hh4 *{box-sizing:border-box}
#hh4 button{font:inherit;cursor:pointer}
#hh4 h2,#hh4 h3,#hh4 h4{margin:0;color:#fff;line-height:1.25}
#hh4 p{margin:6px 0;color:#d6ddf3}
#hh4 .m{color:var(--m)!important;font-size:13px}
#hh4 .hh4-blok{margin:14px 0}
#hh4 .hh4-bas{display:flex;align-items:center;justify-content:space-between;gap:8px;margin:18px 2px 8px}
#hh4 .hh4-bas h3{font-size:13px;letter-spacing:1.4px;text-transform:uppercase;color:#c9d3f2}
#hh4 .hh4-bas small{color:var(--m)}
/* hero */
#hh4 .hh4-hero{position:relative;overflow:hidden;border-radius:22px;padding:20px 18px 16px;background:radial-gradient(120% 140% at 0% 0%,#3b2a7a 0%,#1a2350 45%,#0d1530 100%);border:1px solid #3c3f86}
#hh4 .hh4-hero:after{content:"";position:absolute;inset:auto -40px -60px auto;width:220px;height:220px;border-radius:50%;background:radial-gradient(circle,rgba(255,93,108,.35),transparent 70%);pointer-events:none}
#hh4 .hh4-kicker{font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#c8bcff;font-weight:800}
#hh4 .hh4-hero h2{font-size:26px;margin:4px 0 2px;letter-spacing:-.3px}
#hh4 .hh4-serit{position:relative;overflow:hidden;white-space:nowrap;margin-top:12px;border-radius:10px;background:rgba(0,0,0,.28);border:1px solid rgba(255,255,255,.08);padding:7px 0;font-size:13px}
#hh4 .hh4-serit b{position:absolute;left:0;top:0;bottom:0;z-index:2;display:flex;align-items:center;padding:0 10px;background:var(--r);color:#fff;font-size:11px;letter-spacing:1px}
#hh4 .hh4-serit span{display:inline-block;padding-left:100%;animation:hh4kay 38s linear infinite;color:#ffe9ec}
@keyframes hh4kay{from{transform:translateX(0)}to{transform:translateX(-100%)}}
/* roller */
#hh4 .hh4-roller{display:flex;flex-wrap:wrap;gap:6px;margin-top:12px}
#hh4 .hh4-rol{display:inline-flex;align-items:center;gap:5px;border-radius:99px;padding:5px 11px;font-size:12.5px;font-weight:750;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.14);color:#f3f5ff}
#hh4 .hh4-rol.devlet{background:rgba(110,168,255,.18);border-color:rgba(110,168,255,.5)}
#hh4 .hh4-rol.meydan{background:rgba(255,93,108,.18);border-color:rgba(255,93,108,.5)}
/* ulusal kriz */
#hh4 .hh4-kriz{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:12px}
#hh4 .hh4-kriz div{background:rgba(0,0,0,.25);border:1px solid rgba(255,255,255,.08);border-radius:14px;padding:9px 10px}
#hh4 .hh4-kriz strong{display:block;font-size:20px;color:#fff;font-variant-numeric:tabular-nums}
#hh4 .hh4-kriz span{font-size:11.5px;color:var(--m);line-height:1.3;display:block}
#hh4 .hh4-kriz .tehlike strong{color:var(--r)}
/* gelen kutusu */
#hh4 .hh4-gelen{display:grid;gap:8px}
#hh4 .hh4-is{display:flex;gap:11px;align-items:flex-start;border-radius:16px;padding:12px;background:linear-gradient(135deg,#2a1f4f,#1a2140);border:1px solid #574aa8;text-align:left;width:100%;color:var(--t)}
#hh4 .hh4-is.acil{background:linear-gradient(135deg,#4a1a26,#241532);border-color:#c2475a}
#hh4 .hh4-is i{font-style:normal;font-size:22px;line-height:1}
#hh4 .hh4-is b{display:block;color:#fff}
#hh4 .hh4-is small{display:block;color:#cdd5f0;font-size:12.5px;margin-top:2px}
#hh4 .hh4-is .hh4-is-btn{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}
/* butonlar */
#hh4 .hh4-btn{display:inline-flex;align-items:center;justify-content:center;gap:6px;min-height:42px;padding:9px 14px;border-radius:12px;border:1px solid #4a5a8c;background:#243158;color:#fff;font-weight:750;font-size:14px;line-height:1.2;text-align:center}
#hh4 .hh4-btn.ana{background:linear-gradient(135deg,#7b62ff,#5b45e0);border-color:#a493ff}
#hh4 .hh4-btn.kirmizi{background:linear-gradient(135deg,#e2475a,#b02a45);border-color:#ff8b97}
#hh4 .hh4-btn.yesil{background:linear-gradient(135deg,#1f9a72,#167357);border-color:#55d6a8}
#hh4 .hh4-btn.hayalet{background:transparent;border-color:#3d4b78;color:#d5ddf5}
#hh4 .hh4-btn.kucuk{min-height:34px;padding:6px 10px;font-size:13px;border-radius:10px}
#hh4 .hh4-btn.tam{width:100%}
#hh4 .hh4-btn:disabled{opacity:.5;cursor:not-allowed}
/* meydan kartları */
#hh4 .hh4-meydanlar{display:grid;gap:12px}
@media(min-width:720px){#hh4 .hh4-meydanlar{grid-template-columns:1fr 1fr}}
#hh4 .hh4-mkart{position:relative;display:block;width:100%;text-align:left;border-radius:20px;padding:0;overflow:hidden;border:1px solid var(--c);background:var(--p);color:var(--t)}
#hh4 .hh4-mkart.kirmizi{border-color:#a8344a;box-shadow:0 0 0 1px rgba(255,93,108,.25),0 10px 30px -12px rgba(255,93,108,.55)}
#hh4 .hh4-mkart .ust{display:flex;gap:12px;align-items:center;padding:14px 14px 10px}
#hh4 .hh4-mkart .ic{min-width:0;flex:1}
#hh4 .hh4-mkart h4{font-size:17px}
#hh4 .hh4-mkart .alt{display:flex;flex-wrap:wrap;gap:6px;padding:0 14px 14px}
#hh4 .hh4-etiket{display:inline-flex;align-items:center;gap:4px;border-radius:99px;padding:3px 9px;font-size:12px;font-weight:750;background:#202c52;border:1px solid #34436f;color:#dfe5fa;white-space:nowrap}
#hh4 .hh4-etiket.ben{background:#163e33;border-color:#2f8a6c;color:#d4fbea}
#hh4 .hh4-etiket.uyari{background:#4a2a14;border-color:#a8692e;color:#ffe2bf}
#hh4 .hh4-etiket.tehlike{background:#4a1520;border-color:#b23b51;color:#ffd9df}
#hh4 .hh4-etiket.mavi{background:#15294d;border-color:#3d6fb7;color:#d7e7ff}
#hh4 .hh4-kalabalik{display:flex;padding:0 14px 12px}
#hh4 .hh4-kalabalik span.av{width:26px;height:26px;margin-right:-7px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:800;color:#1a1030;border:2px solid var(--p);background:#ffb48a}
#hh4 .hh4-kalabalik em{font-style:normal;margin-left:12px;color:var(--m);font-size:12.5px;align-self:center}
/* halka */
#hh4 .hh4-halka{flex:0 0 auto;position:relative;width:64px;height:64px}
#hh4 .hh4-halka svg{width:100%;height:100%;transform:rotate(-90deg)}
#hh4 .hh4-halka b{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:18px;color:#fff;font-variant-numeric:tabular-nums}
#hh4 .hh4-halka b small{font-size:9.5px;color:var(--m);font-weight:600;letter-spacing:.5px}
/* boş */
#hh4 .hh4-bos{border:1px dashed #3f4d7a;border-radius:18px;padding:22px 16px;text-align:center;color:#cfd7f2}
/* çağrı sihirbazı */
#hh4 .hh4-adim{display:flex;gap:8px;margin:10px 0 4px}
#hh4 .hh4-adim span{flex:1;border-radius:10px;padding:7px 8px;font-size:12px;background:#1b2648;border:1px solid #33416c;color:#cbd4f0;text-align:center}
#hh4 .hh4-adim span.ok{background:#173e33;border-color:#2f8a6c;color:#d4fbea}
#hh4 .hh4-panel{border-radius:18px;padding:14px;background:var(--p);border:1px solid var(--c)}
#hh4 details.hh4-ac{border-radius:16px;background:var(--p);border:1px solid var(--c);margin:10px 0}
#hh4 details.hh4-ac>summary{list-style:none;cursor:pointer;padding:13px 14px;font-weight:750;color:#fff;display:flex;align-items:center;gap:8px}
#hh4 details.hh4-ac>summary::-webkit-details-marker{display:none}
#hh4 details.hh4-ac>summary:after{content:"▾";margin-left:auto;color:var(--m);transition:transform .2s}
#hh4 details.hh4-ac[open]>summary:after{transform:rotate(180deg)}
#hh4 details.hh4-ac>.ic{padding:0 14px 14px}
/* kriz haritası */
#hh4 .hh4-harita{display:grid;grid-template-columns:repeat(9,minmax(0,1fr));gap:3px}
#hh4 .hh4-harita button{position:relative;aspect-ratio:1;border:0;border-radius:6px;padding:0;font-size:9.5px;font-weight:800;color:rgba(255,255,255,.88);line-height:1}
#hh4 .hh4-harita button.var{outline:2px solid #fff;outline-offset:-2px;animation:hh4nabiz 1.4s ease-in-out infinite}
@keyframes hh4nabiz{0%,100%{box-shadow:0 0 0 0 rgba(255,93,108,.0)}50%{box-shadow:0 0 0 5px rgba(255,93,108,.45)}}
#hh4 .hh4-lejant{display:flex;gap:10px;flex-wrap:wrap;margin-top:8px;font-size:12px;color:var(--m)}
#hh4 .hh4-lejant i{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:4px;vertical-align:-1px}
/* eylem ekranı */
#hh4 .hh4-geri{display:inline-flex;align-items:center;gap:6px;background:none;border:0;color:#c9d2f3;font-weight:700;padding:6px 2px;margin:2px 0 6px}
#hh4 .hh4-sahne{position:relative;border-radius:22px;overflow:hidden;border:1px solid #2f3d6c;background:#0b1430}
#hh4 .hh4-sahne svg{display:block;width:100%;height:auto}
#hh4 .hh4-sahne .bilgi{position:absolute;left:12px;right:12px;top:10px;display:flex;justify-content:space-between;align-items:flex-start;gap:8px;pointer-events:none}
#hh4 .hh4-sahne .bilgi h2{font-size:21px;text-shadow:0 2px 8px rgba(0,0,0,.6)}
#hh4 .hh4-sahne .bilgi p{margin:2px 0 0;font-size:12.5px;color:#e8ecff;text-shadow:0 1px 4px rgba(0,0,0,.7)}
#hh4 .hh4-canli{display:inline-flex;align-items:center;gap:5px;font-size:11px;font-weight:900;letter-spacing:1px;padding:4px 8px;border-radius:7px;background:var(--r);color:#fff}
#hh4 .hh4-canli:before{content:"";width:7px;height:7px;border-radius:50%;background:#fff;animation:hh4yanip 1s steps(2) infinite}
@keyframes hh4yanip{50%{opacity:.2}}
#hh4 .kisi{animation:hh4sallan 2.4s ease-in-out infinite;transform-box:fill-box;transform-origin:50% 100%}
@keyframes hh4sallan{0%,100%{transform:translateY(0)}50%{transform:translateY(-1.6px)}}
#hh4 .alev{animation:hh4alev .5s ease-in-out infinite alternate;transform-box:fill-box;transform-origin:50% 100%}
@keyframes hh4alev{from{transform:scaleY(.8);opacity:.75}to{transform:scaleY(1.15);opacity:1}}
#hh4 .kirmizi-isik{animation:hh4kirmizi 1.8s ease-in-out infinite}
@keyframes hh4kirmizi{0%,100%{opacity:.15}50%{opacity:.45}}
#hh4 .pankart{animation:hh4pankart 3.2s ease-in-out infinite;transform-box:fill-box;transform-origin:50% 100%}
@keyframes hh4pankart{0%,100%{transform:rotate(-2deg)}50%{transform:rotate(2deg)}}
#hh4 .hh4-gosterge{display:grid;grid-template-columns:auto 1fr;gap:12px;align-items:center;margin:12px 0}
#hh4 .hh4-cubuklar{display:grid;gap:7px}
#hh4 .hh4-cubuk{font-size:12px;color:var(--m)}
#hh4 .hh4-cubuk div{height:7px;border-radius:99px;background:#1f2a4c;overflow:hidden;margin-top:3px}
#hh4 .hh4-cubuk i{display:block;height:100%;border-radius:99px}
#hh4 .hh4-sayilar{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;margin:4px 0 10px}
#hh4 .hh4-sayilar div{background:var(--p);border:1px solid var(--c);border-radius:13px;padding:8px 6px;text-align:center}
#hh4 .hh4-sayilar strong{display:block;font-size:17px;color:#fff;font-variant-numeric:tabular-nums}
#hh4 .hh4-sayilar span{font-size:10.5px;color:var(--m);line-height:1.2;display:block}
#hh4 .hh4-uyarilar{display:grid;gap:7px;margin:8px 0}
#hh4 .hh4-uyari{border-radius:14px;padding:10px 12px;font-size:13.5px;border:1px solid;display:flex;gap:9px;align-items:flex-start}
#hh4 .hh4-uyari i{font-style:normal;font-size:18px;line-height:1.1}
#hh4 .hh4-uyari b{color:#fff}
#hh4 .hh4-uyari.kirmizi{background:#3c1420;border-color:#a8344a;color:#ffdfe4}
#hh4 .hh4-uyari.turuncu{background:#3b2512;border-color:#a8692e;color:#ffe6c9}
#hh4 .hh4-uyari.mavi{background:#13264a;border-color:#3d6fb7;color:#dce9ff}
#hh4 .hh4-uyari.yesil{background:#123a2f;border-color:#2f8a6c;color:#d4fbea}
#hh4 .hh4-uyari .hh4-is-btn{display:flex;gap:6px;flex-wrap:wrap;margin-top:7px}
#hh4 .hh4-cta{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:10px 0}
#hh4 .hh4-cta .tek{grid-column:1/-1}
/* sekmeler */
#hh4 .hh4-sekmeler{position:sticky;top:0;z-index:5;display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:8px 0;margin:6px 0 4px;background:linear-gradient(#0f1730 70%,rgba(15,23,48,0))}
#hh4 .hh4-sekmeler::-webkit-scrollbar{display:none}
#hh4 .hh4-sekmeler button{flex:0 0 auto;border:1px solid #33416c;background:#17213f;color:#cfd7f3;border-radius:99px;padding:8px 13px;font-size:13.5px;font-weight:750;position:relative}
#hh4 .hh4-sekmeler button.acik{background:#fff;color:#141a33;border-color:#fff}
#hh4 .hh4-sekmeler button sup{position:absolute;top:-4px;right:-3px;min-width:17px;height:17px;border-radius:99px;background:var(--r);color:#fff;font-size:10.5px;line-height:17px;padding:0 4px}
/* akış */
#hh4 .hh4-filtre{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;margin:2px 0 8px}
#hh4 .hh4-filtre button{flex:0 0 auto;border:1px solid #33416c;background:transparent;color:#cdd5f1;border-radius:99px;padding:5px 11px;font-size:12.5px}
#hh4 .hh4-filtre button.acik{background:#2b3a66;color:#fff}
#hh4 .hh4-akis{position:relative;padding-left:22px}
#hh4 .hh4-akis:before{content:"";position:absolute;left:9px;top:4px;bottom:4px;width:2px;background:linear-gradient(#3b4a7c,#1b2547)}
#hh4 .hh4-olay{position:relative;margin:0 0 10px;padding:9px 11px;border-radius:13px;background:var(--p);border:1px solid var(--c)}
#hh4 .hh4-olay:before{content:attr(data-ikon);position:absolute;left:-26px;top:7px;width:22px;height:22px;border-radius:50%;background:#1a2447;border:2px solid #3b4a7c;display:flex;align-items:center;justify-content:center;font-size:11px}
#hh4 .hh4-olay.kritik{border-color:#a8344a;background:#2a1220}
#hh4 .hh4-olay.devlet{border-left:3px solid var(--b)}
#hh4 .hh4-olay.meydan,#hh4 .hh4-olay.pankart{border-left:3px solid var(--o)}
#hh4 .hh4-olay.katil{border-left:3px solid var(--g)}
#hh4 .hh4-olay.ayril{border-left:3px solid #69739a;opacity:.85}
#hh4 .hh4-olay.aciklama{border-left:3px solid var(--v)}
#hh4 .hh4-olay.hukuk{border-left:3px solid #c9a7ff}
#hh4 .hh4-olay.para{border-left:3px solid var(--y)}
#hh4 .hh4-olay small{display:block;color:var(--m);font-size:11.5px;margin-bottom:2px}
#hh4 .hh4-olay p{margin:0;font-size:14px;color:#eef1ff}
#hh4 .hh4-gun{margin:12px 0 6px -22px;font-size:11.5px;letter-spacing:1.2px;text-transform:uppercase;color:#9aa6cc;font-weight:800}
/* sohbet */
#hh4 .hh4-sohbet{display:flex;flex-direction:column;border-radius:20px;border:1px solid var(--c);background:linear-gradient(#0e1730,#0b1226);overflow:hidden}
#hh4 .hh4-sohbet .bas{display:flex;align-items:center;gap:8px;padding:11px 13px;border-bottom:1px solid #222e55;background:rgba(255,255,255,.03)}
#hh4 .hh4-sohbet .bas b{flex:1}
#hh4 .hh4-sabit{margin:8px 10px 0;border-radius:12px;padding:8px 10px;background:#2b2412;border:1px solid #7a6327;font-size:13px;color:#ffeec7}
#hh4 .hh4-mesajlar{height:min(56vh,460px);overflow-y:auto;padding:10px 10px 14px;display:flex;flex-direction:column;gap:6px;scroll-behavior:smooth}
#hh4 .hh4-msj{max-width:84%;align-self:flex-start}
#hh4 .hh4-msj.ben{align-self:flex-end}
#hh4 .hh4-msj .balon{position:relative;border-radius:16px 16px 16px 5px;padding:8px 11px 7px;background:#1f2a50;border:1px solid #2f3d6e;color:#f1f4ff;font-size:14.5px;line-height:1.4;white-space:pre-wrap;overflow-wrap:anywhere}
#hh4 .hh4-msj.ben .balon{border-radius:16px 16px 5px 16px;background:linear-gradient(135deg,#5b45e0,#7357f0);border-color:#8d79ff}
#hh4 .hh4-msj.organizator .balon{border-color:#c79a32}
#hh4 .hh4-msj .ad{font-size:11.5px;font-weight:800;color:#ffb48a;margin:0 0 2px 4px}
#hh4 .hh4-msj .ad em{font-style:normal;font-weight:700;font-size:10.5px;padding:1px 6px;border-radius:99px;margin-left:5px;background:#3a2f12;color:#ffd98a}
#hh4 .hh4-msj .ad em.gozalti{background:#4a1520;color:#ffc7d0}
#hh4 .hh4-msj .ad em.ayrildi{background:#2a2f45;color:#b9c1dd}
#hh4 .hh4-msj .alt{display:flex;gap:6px;align-items:center;justify-content:flex-end;margin-top:2px;font-size:11px;color:#9eabd3}
#hh4 .hh4-msj.ben .alt{color:#e1dcff}
#hh4 .hh4-msj .alt button{border:0;background:rgba(255,255,255,.08);color:inherit;border-radius:99px;padding:1px 7px;font-size:11.5px}
#hh4 .hh4-msj .alt button.acik{background:#ffd166;color:#2b1d00}
#hh4 .hh4-yaz{display:flex;gap:8px;align-items:flex-end;padding:10px;border-top:1px solid #222e55;background:#0d152c}
#hh4 .hh4-yaz textarea{flex:1;min-height:44px!important;max-height:120px;resize:none!important;border-radius:14px!important;padding:11px 12px!important;font-size:15px!important}
#hh4 .hh4-yaz button{flex:0 0 auto;width:46px!important;height:46px;min-height:46px!important;border-radius:50%!important;padding:0!important;font-size:19px!important}
#hh4 .hh4-hizli{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;padding:8px 10px 0;background:#0d152c}
#hh4 .hh4-hizli button{flex:0 0 auto;border:1px solid #33416c;background:#17213f;color:#dbe2fa;border-radius:99px;padding:5px 10px;font-size:12.5px}
#hh4 .hh4-kilit{padding:34px 18px;text-align:center}
#hh4 .hh4-kilit i{font-style:normal;font-size:40px;display:block;margin-bottom:6px}
/* hamle kartları */
#hh4 .hh4-grup{margin:16px 0 6px}
#hh4 .hh4-grup h4{font-size:15px;display:flex;align-items:center;gap:8px}
#hh4 .hh4-grup h4 small{font-size:12px;color:var(--m);font-weight:500}
#hh4 .hh4-kartlar{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:8px}
@media(min-width:720px){#hh4 .hh4-kartlar{grid-template-columns:repeat(3,minmax(0,1fr))}}
#hh4 .hh4-hamle{position:relative;display:flex;flex-direction:column;gap:3px;text-align:left;min-height:96px;border-radius:16px;padding:11px 11px 10px;border:1px solid #33416c;background:linear-gradient(160deg,#1b2648,#131c38);color:var(--t)}
#hh4 .hh4-hamle .i{font-size:22px;line-height:1}
#hh4 .hh4-hamle b{font-size:14px;color:#fff;line-height:1.25}
#hh4 .hh4-hamle small{font-size:11.5px;color:#b8c3e4;line-height:1.3}
#hh4 .hh4-hamle .bedel{margin-top:auto;font-size:11px;font-weight:800;color:#ffd98a}
#hh4 .hh4-hamle.kilitli{opacity:.55}
#hh4 .hh4-hamle.kilitli .bedel{color:#c5cbe0}
#hh4 .hh4-hamle.yesil{border-color:#2f8a6c;background:linear-gradient(160deg,#14382f,#111c32)}
#hh4 .hh4-hamle.mavi{border-color:#3d6fb7;background:linear-gradient(160deg,#152a50,#111c34)}
#hh4 .hh4-hamle.altin{border-color:#8f7330;background:linear-gradient(160deg,#30270f,#141a30)}
#hh4 .hh4-hamle.turuncu{border-color:#a8692e;background:linear-gradient(160deg,#3a2412,#141a30)}
#hh4 .hh4-hamle.kirmizi{border-color:#a8344a;background:linear-gradient(160deg,#3a1220,#141a30)}
#hh4 .hh4-hamle.mor{border-color:#6b56d6;background:linear-gradient(160deg,#261d52,#141a30)}
#hh4 .hh4-hamle.aktif:after{content:"SÜRÜYOR";position:absolute;top:8px;right:8px;font-size:9.5px;font-weight:900;letter-spacing:.8px;padding:2px 6px;border-radius:6px;background:var(--g);color:#08261b}
/* güç tablosu */
#hh4 table.hh4-tablo{width:100%;border-collapse:collapse;font-size:13.5px}
#hh4 table.hh4-tablo td{padding:7px 4px;border-bottom:1px solid #222d52;color:#dfe5fa;vertical-align:top}
#hh4 table.hh4-tablo td:last-child{text-align:right;font-weight:800;font-variant-numeric:tabular-nums;white-space:nowrap}
#hh4 table.hh4-tablo td.art{color:#ff9aa6}
#hh4 table.hh4-tablo td.eks{color:#8fe3c3}
#hh4 .hh4-kisiler{display:flex;flex-wrap:wrap;gap:6px}
#hh4 .hh4-kisiler span{border-radius:99px;padding:4px 10px;font-size:12.5px;background:#1d2850;border:1px solid #33416c}
#hh4 .hh4-adim-ac{margin-top:8px}
@media(prefers-reduced-motion:reduce){#hh4 *{animation:none!important;transition:none!important}}
/* taşınan eski bloklar */
#hh4 [hidden]{display:none!important}
#hh4 [data-hh4-yuva]>*{margin-bottom:10px}
#hh4 .hh4-em{margin:8px 0 12px;border-radius:18px;background:var(--p);border-color:var(--c)}
#hh4 .hh4-em>header,#hh4 .hh4-em>.em-sekme,#hh4 .hh4-em a[href="#hhMeydanEk"]{display:none!important}
#hh4 .hh-saha{margin:8px 0;border-radius:18px}
#hh4 .hh-saha>h4,#hh4 .hh-saha>.hh-chips,#hh4 .hh-saha [data-saha-meydan],#hh4 .hh-saha details:has(.hh-dokum){display:none!important}
#hh4 article.hh4-kurum{background:transparent!important;border:0!important;padding:0!important;margin:0!important;box-shadow:none!important}
#hh4 [data-hh4-yuva] .hh-box,#hh4 [data-hh4-yuva] details.hh-detail{border-radius:16px}
#hh4 [data-hh4-yuva] [data-hh-panel]>.hh-box:first-child{background:transparent;border:0;padding:0}
#hh4 [data-hh4-yuva="bant"] .hh-band{border-radius:14px;margin:0 0 8px}

`;
 document.head.appendChild(st);
}

/* Eski katmanların stilleri yalnız eski kapsayıcıya bağlıydı; taşınan bloklar da aynı görünümü alsın. */
function ortakStil(){
 if(document.getElementById('hh4-ortak'))return;
 const metin=[...document.querySelectorAll('style')].map(x=>x.textContent||'').filter(t=>t.indexOf('#hhCommand')>=0).join('\n');
 if(!metin)return;
 const st=document.createElement('style');st.id='hh4-ortak';
 st.textContent=metin.replace(/#hhCommand(?![\w-])/g,'#hh4 [data-hh4-yuva]')+
  '\n#hh4 [data-hh4-yuva] button:not(.em-kart):not([class*="hh4-"]){min-height:44px;border-radius:12px;border:1px solid #61709a;background:#303b61;color:#fff;font-weight:700;padding:9px 12px}'+
  '\n#hh4 [data-hh4-yuva] button.hh-primary{background:#7967ed;border-color:#a898ff}\n#hh4 [data-hh4-yuva] button:is(.hh-ayril,.hh-danger){background:#4e2935;border-color:#e095a5}';
 document.head.appendChild(st);
}
ortakStil();

/* ── yardımcılar ── */
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const num=(x,d)=>Number(x||0).toLocaleString('tr-TR',{maximumFractionDigits:d==null?1:d});
const tl=x=>Number(x||0).toLocaleString('tr-TR',{maximumFractionDigits:0})+' TL';
const saat=x=>x?new Date(x).toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit',timeZone:'Europe/Istanbul'}):'—';
const tarih=x=>x?new Date(x).toLocaleString('tr-TR',{day:'numeric',month:'short',hour:'2-digit',minute:'2-digit',timeZone:'Europe/Istanbul'}):'—';
const jp=o=>esc(JSON.stringify(o));
const hata=ex=>(typeof hataCevir==='function'?hataCevir(ex&&ex.message||String(ex)):String(ex&&ex.message||ex));
const bildir=(m,h)=>{try{toast(m,!!h);}catch(_){}};
function kalan(b){const ms=Date.parse(b)-Date.now();if(!(ms>0))return 'süre doldu';const s=Math.floor(ms/1000),g=Math.floor(s/86400),h=Math.floor(s%86400/3600),dk=Math.floor(s%3600/60),sn=s%60;
 if(g)return g+'g '+h+'s';if(h)return h+'s '+String(dk).padStart(2,'0')+'dk';return String(dk).padStart(2,'0')+':'+String(sn).padStart(2,'0');}
const geri=b=>'<span data-hh4-geri="'+esc(b)+'">'+kalan(b)+'</span>';
const istSaat=()=>Number(new Date().toLocaleString('en-GB',{hour:'2-digit',hour12:false,timeZone:'Europe/Istanbul'}));
function bas(ad){const s=String(ad||'?').trim();return esc((s[0]||'?').toLocaleUpperCase('tr-TR'));}
function renkAd(ad){let h=0;for(const c of String(ad||''))h=(h*31+c.charCodeAt(0))%360;return 'hsl('+h+',75%,72%)';}
async function rpc(fn,args){try{return await API.rpc(fn,args||{});}catch(e){return null;}}
function seviyeRenk(s){s=Number(s||0);return s>=75?'#ff5d6c':s>=45?'#ff9b45':'#ffd166';}
function halka(s,boyut){
 const r=26,c=2*Math.PI*r,p=Math.max(0,Math.min(100,Number(s||0)));
 return '<div class="hh4-halka" style="'+(boyut?'width:'+boyut+'px;height:'+boyut+'px':'')+'" aria-label="Güç '+num(p)+' / 100"><svg viewBox="0 0 64 64"><circle cx="32" cy="32" r="'+r+'" fill="none" stroke="#1f2a4c" stroke-width="7"/>'+
  '<circle cx="32" cy="32" r="'+r+'" fill="none" stroke="'+seviyeRenk(p)+'" stroke-width="7" stroke-linecap="round" stroke-dasharray="'+(c*p/100).toFixed(1)+' '+c.toFixed(1)+'"/>'+
  '<line x1="'+(32+(r-4)*Math.cos(2*Math.PI*.75)).toFixed(1)+'" y1="'+(32+(r-4)*Math.sin(2*Math.PI*.75)).toFixed(1)+'" x2="'+(32+(r+4)*Math.cos(2*Math.PI*.75)).toFixed(1)+'" y2="'+(32+(r+4)*Math.sin(2*Math.PI*.75)).toFixed(1)+'" stroke="#fff" stroke-width="2"><title>Kırmızı eşik 75</title></line></svg>'+
  '<b>'+num(p,0)+'<small>GÜÇ</small></b></div>';
}
const TALEP={hizmet:'Belediye hizmeti +5',issizlik:'İşsizlik −0,5',vergi:'Vergi −1',genel:'Siyasi talep'};

/* ── veri: eski katmanlarla paylaşılan tek seferlik panel önbelleği ──
   Eski katmanlar aynı panelleri sırayla ister; bu çizim boyunca aynı istek bir kez gider. */
const OKU=/^sokak_(merkez_panel|saha_panel|tedbir_panel|sert_panel|meydan_panel|kriz_harita|eylem_merkezi|denge_panel|kaynak_ozet|org_panel|finans_panel|eylem_detay_panel|uzlasma_panel|katilim_liste|denetim_oku)$/;
function onbellekKur(){
 const asil=API.rpc,m=new Map();
 const sar=function(fn,args){
  if(OKU.test(String(fn))){const k=fn+'|'+JSON.stringify(args||{});
   if(!m.has(k))m.set(k,Promise.resolve().then(()=>asil.call(API,fn,args)).catch(e=>{m.delete(k);throw e;}));
   return m.get(k);}
  return asil.apply(API,arguments);
 };
 API.rpc=sar;
 return ()=>{if(API.rpc===sar)API.rpc=asil;};
}
async function modelYukle(){
 const [merkez,saha,harita,denge,em,kaynak,meydan]=await Promise.all(['sokak_merkez_panel','sokak_saha_panel','sokak_kriz_harita','sokak_denge_panel','sokak_eylem_merkezi','sokak_kaynak_ozet','sokak_meydan_panel'].map(f=>rpc(f)));
 if(!merkez)return null;
 const har=p=>{const o={};((p&&p.eylemler)||[]).forEach(r=>{o[Number(r.id)]=r;});return o;};
 const SA=har(saha),DG=har(denge),EM=har(em),KY=har(kaynak),now=Date.now(),tum=merkez.eylemler||[];
 const aktif=tum.filter(x=>x.durum==='aktif'&&Date.parse(x.bitis)>now).map(x=>{
  const id=Number(x.id),sa=SA[id]||{};
  return {id,x,sa,dg:DG[id]||null,em:EM[id]||null,ky:KY[id]||null,
   katilimci:!!(x.katildim||sa.taraf==='muhalefet'),karsi:sa.taraf==='iktidar',gorevde:!!sa.gorevdeyim,org:!!x.ben_baslattim,
   seviye:Number(x.seviye||0),kirmizi:!!x.kirmizi_baslangic,
   kisi:Number(sa.dokum&&sa.dokum.katilimci!=null?sa.dokum.katilimci:x.katilim||0)};
 });
 return {merkez,saha,harita,denge,meydan,aktif,gecmis:tum.filter(x=>!(x.durum==='aktif'&&Date.parse(x.bitis)>now)),
  yon:!!merkez.mudahale_yetki,iktidar:!!merkez.iktidar,unvan:saha&&saha.gorev_unvanim,
  gazeteci:!!(meydan&&meydan.gazeteci),vekil:!!(meydan&&meydan.vekil),kabine:!!(meydan&&meydan.kabine)};
}
const bul=id=>S.model&&S.model.aktif.find(e=>e.id===Number(id));

/* ── eski blokları topla: dinleyicileri bozulmadan yeni yerlerine taşınır ── */
function topla(kok){
 const P={eylem:{},cagri:null,hukuk:null,davet:null,gecmis:null,hafiza:null,kurumsal:[]};
 const al=id=>P.eylem[id]||(P.eylem[id]={hamle:[],devlet:[],kurum:[],bant:[],katil:null,destek:[]});
 const komut=kok.querySelector('#hhCommand');
 const panel=k=>komut&&komut.querySelector(':scope > [data-hh-panel="'+k+'"]');
 P.cagri=kok.querySelector('#emCagri');
 const hk=panel('legal'),dv=panel('invite'),gc=panel('history');
 if(hk&&hk.querySelector('form,button'))P.hukuk=hk;
 if(dv&&dv.querySelector('[data-hh-invite]'))P.davet=dv;
 if(gc)P.gecmis=gc;
 const st=panel('state');
 kok.querySelectorAll('article.hh-event[data-hh-event]').forEach(art=>{
  const id=Number(art.getAttribute('data-hh-event')),p=al(id);
  const em=art.querySelector('.em');if(em){em.classList.add('hh4-em');p.em=em;}
  const katil=art.querySelector('form.hh-participate');if(katil)p.katil=katil;
  const saha=art.querySelector('.hh-saha');
  if(saha){
   saha.querySelectorAll(':scope > details').forEach(d=>{const s=(d.querySelector('summary')||{}).textContent||'';if(/^\s*(🏛️|⛔)/.test(s))p.devlet.push(d);});
   saha.querySelectorAll('.hh-band').forEach(b=>{if(b.querySelector('button,form'))p.bant.push(b);});
   p.saha=saha;
  }
  art.querySelectorAll('details.hh-detail').forEach(d=>{if(!d.closest('.hh-saha')&&!d.closest('.em'))p.destek.push(d);});
 });
 if(st)st.querySelectorAll('form[data-hh-id]').forEach(f=>{const id=Number(f.getAttribute('data-hh-id'));const box=f.closest('.hh-box');if(box&&!al(id).devlet.includes(box))al(id).devlet.push(box);});
 const md=kok.querySelector('#hhMeydanEk');
 if(md){
  const DEVLET=/^(muhbir_teklif|muhbir_dik|kirmizi_hat|belge_sorustur)$/;
  md.querySelectorAll('article[data-meydan]').forEach(art=>{
   const id=Number(art.getAttribute('data-meydan')),p=al(id);
   art.querySelectorAll('[data-sohbet]').forEach(s=>{const d=s.closest('details');(d||s).remove();});
   art.querySelectorAll(':scope > .hh-band').forEach(b=>{if(b.querySelector('button'))p.bant.push(b);});
   art.querySelectorAll('form[data-meydan-form]').forEach(f=>{if(DEVLET.test(f.dataset.meydanForm))p.devlet.push(f);});
   art.querySelectorAll('[data-meydan-islem="juri_baslat"]').forEach(b=>p.devlet.push(b));
   art.querySelectorAll(':scope > details').forEach(d=>{const s=(d.querySelector('summary')||{}).textContent||'';if(/İçeriden bilgi/.test(s)&&!d.querySelector('[data-meydan-form="muhbir_sizdir"]'))p.devlet.push(d);});
   const h3=art.querySelector(':scope > h3');if(h3)h3.remove();
   art.classList.add('hh4-kurum');p.kurum.push(art);
  });
  const hf=[...md.querySelectorAll(':scope > details')].find(d=>/hafıza/i.test((d.querySelector('summary')||{}).textContent||''));
  if(hf)P.hafiza=hf;
  md.querySelectorAll(':scope > :is(form,button,p.hh-muted,details)').forEach(n=>{
   if(n===hf)return;const s=n.matches('details')?((n.querySelector('summary')||{}).textContent||''):'';
   if(/kriz haritası/i.test(s))return;
   if(n.matches('p.hh-muted')&&!/pusula|Meşale/.test(n.textContent))return;
   P.kurumsal.push(n);
  });
 }
 return P;
}
/* Taşınan formlarda elle sayı yazılan alanlar seçim listesine döner (adlar aynı kalır). */
function iyilestir(kok,M){
 const iller=(M.merkez.iller||[]).slice().sort((a,b)=>String(a.ad).localeCompare(String(b.ad),'tr'));
 const ilSec=(ad,gerekli)=>{const s=document.createElement('select');s.name=ad;if(gerekli)s.required=true;
  s.innerHTML='<option value="">İl seç</option>'+iller.map(i=>'<option value="'+Number(i.id)+'">'+esc(i.ad)+' · memnuniyetsizlik '+num(i.memnuniyetsizlik,0)+'</option>').join('');return s;};
 kok.querySelectorAll('input[name="il"][type="number"]').forEach(inp=>{const s=ilSec('il',inp.required);inp.replaceWith(s);});
 const ks=M.merkez.baslatma_kaynaklari||[];
 kok.querySelectorAll('form[data-em-form="cagri"]').forEach(f=>{
  const tur=f.querySelector('select[name="kaynak"]'),no=f.querySelector('input[name="kaynak_id"]');
  if(!tur||!no||!ks.length)return;
  const s=document.createElement('select');s.name='kaynak_sec';s.required=true;
  s.innerHTML=ks.map((k,i)=>'<option value="'+i+'">'+(k.tur==='parti'?'🏳️ ':'🏛️ ')+esc(k.ad)+'</option>').join('');
  const es=()=>{const k=ks[Number(s.value)]||ks[0];tur.value=k.tur;no.value=k.id;};
  s.addEventListener('change',es);
  const lb=no.previousElementSibling;if(lb&&lb.tagName==='LABEL')lb.textContent='Eylemi düzenleyen kuruluş';
  no.type='hidden';no.after(s);
  const tl0=tur.previousElementSibling;if(tl0&&tl0.tagName==='LABEL')tl0.remove();tur.style.display='none';es();
 });
 const adlar=new Set();(M.merkez.eylemler||[]).forEach(x=>(x.katilim_ayrintilari||[]).forEach(k=>adlar.add(k.ad)));
 (M.merkez.avukatlar||[]).forEach(a=>adlar.add(a.ad));
 let dl=document.getElementById('hh4-adlar');
 if(!dl){dl=document.createElement('datalist');dl.id='hh4-adlar';document.body.appendChild(dl);}
 dl.innerHTML=[...adlar].map(a=>'<option value="'+esc(a)+'">').join('');
 kok.querySelectorAll('input[name="kad"]').forEach(i=>{i.setAttribute('list','hh4-adlar');i.autocomplete='off';});

 /* kaynak aktarımında kuruluş numarası eylemin kuruluşundan dolar */
 kok.querySelectorAll('form[data-em-form="kaynak"]').forEach(f=>{
  const em=f.closest('.em');const id=em&&Number(em.getAttribute('data-em'));const x=(M.merkez.eylemler||[]).find(e=>Number(e.id)===id);
  const no=f.querySelector('input[name="kaynak_id"]'),tur=f.querySelector('select[name="kaynak"]');if(!x||!no||!tur)return;
  [...tur.options].forEach(o=>{if(o.value!=='oyuncu'&&o.value!==x.org_tur)o.remove();});
  no.type='hidden';no.value=x.org_id||'';
  const sync=()=>{no.value=tur.value==='oyuncu'?'':(x.org_id||'');};tur.addEventListener('change',sync);sync();
 });
 /* boykot: şirket numarası yerine adla arama */
 kok.querySelectorAll('input[name="sirket"]').forEach(no=>{
  if(no.dataset.hh4)return;no.dataset.hh4='1';
  const ara=document.createElement('input');ara.type='search';ara.placeholder='Şirket adı yaz (en az 2 harf)';ara.autocomplete='off';
  const dl2=document.createElement('datalist');dl2.id='hh4-sirket-'+Math.random().toString(36).slice(2,8);ara.setAttribute('list',dl2.id);
  let bulunan=[];let zam=null;
  ara.addEventListener('input',()=>{const q=ara.value.trim();const s=bulunan.find(b=>b.ad===q);if(s){no.value=s.id;return;}no.value='';
   clearTimeout(zam);if(q.length<2)return;zam=setTimeout(async()=>{const r=await rpc('sokak_sirket_ara',{p_q:q});bulunan=Array.isArray(r)?r:[];
    dl2.innerHTML=bulunan.map(b=>'<option value="'+esc(b.ad)+'">'+esc(b.sektor||'')+' · #'+Number(b.id)+'</option>').join('');},250);});
  no.type='hidden';no.after(ara,dl2);
 });
}

/* ── canlı meydan sahnesi: her gerçek katılımcı bir kişi ── */
function sahne(E){
 const x=E.x,sa=E.sa||{},dk=sa.dokum||{},em=E.em||{},h=istSaat(),gece=h<6||h>=20;
 const adlar=(x.katilim_ayrintilari||[]).map(k=>k.ad);
 const n=Math.min(48,E.kisi),g=Math.min(10,Number(dk.gorevli||(sa.gorevliler||[]).length||0)),ks=Math.min(10,Number(dk.karsi||(sa.karsidakiler||[]).length||0));
 let s='<svg viewBox="0 0 360 190" role="img" aria-label="'+esc(x.il)+' meydanı: '+E.kisi+' katılımcı, '+g+' görevli, '+ks+' karşı tarafta">'+
  '<defs><linearGradient id="hh4g" x1="0" y1="0" x2="0" y2="1">'+(gece?'<stop offset="0" stop-color="#050816"/><stop offset="1" stop-color="#18224a"/>':'<stop offset="0" stop-color="#2a5aa0"/><stop offset="1" stop-color="#8fb4e3"/>')+'</linearGradient>'+
  '<radialGradient id="hh4z" cx=".5" cy=".2" r=".8"><stop offset="0" stop-color="'+(gece?'#2a2f55':'#c9b79a')+'"/><stop offset="1" stop-color="'+(gece?'#10142c':'#7d6f5c')+'"/></radialGradient></defs>'+
  '<rect width="360" height="190" fill="url(#hh4g)"/>';
 if(gece){for(let i=0;i<26;i++)s+='<circle cx="'+((i*53)%360)+'" cy="'+((i*29)%70+4)+'" r="'+(i%3?0.7:1.1)+'" fill="#fff" opacity="'+(0.4+(i%4)*0.15)+'"/>';s+='<circle cx="318" cy="26" r="11" fill="#f4f1d9"/><circle cx="323" cy="22" r="10" fill="#0a1024"/>';}
 else s+='<circle cx="318" cy="28" r="13" fill="#ffe28a" opacity=".9"/>';
 const bin=[[0,70,34],[30,52,26],[52,82,30],[78,60,22],[96,44,34],[126,66,20],[230,58,26],[252,40,30],[278,74,24],[298,50,30],[324,66,36]];
 bin.forEach(([bx,by,bw],i)=>{s+='<rect x="'+bx+'" y="'+by+'" width="'+bw+'" height="'+(130-by)+'" fill="'+(gece?'#0d1330':'#3e5576')+'" opacity=".95"/>';
  if(gece)for(let j=0;j<4;j++)s+='<rect x="'+(bx+4+(j%2)*10)+'" y="'+(by+8+Math.floor(j/2)*14)+'" width="4" height="5" fill="#ffd27a" opacity="'+((i+j)%3?0.75:0.2)+'"/>';});
 const ig=em.isgal;
 if(ig&&ig.durum==='aktif'){
  s+='<rect x="146" y="58" width="80" height="72" fill="'+(gece?'#232a4d':'#d7cbb4')+'"/><polygon points="140,60 186,38 232,60" fill="'+(gece?'#2c345e':'#bfae90')+'"/>';
  for(let c=0;c<5;c++)s+='<rect x="'+(152+c*15)+'" y="68" width="6" height="58" fill="'+(gece?'#38407a':'#efe6d4')+'"/>';
  s+='<rect x="158" y="44" width="56" height="11" rx="2" fill="#ff5d6c"/><text x="186" y="52.5" text-anchor="middle" font-size="7.5" font-weight="800" fill="#fff">'+esc(String(ig.bina||'bina').toLocaleUpperCase('tr-TR'))+' İŞGALDE</text>';
 }
 s+='<ellipse cx="180" cy="168" rx="200" ry="44" fill="url(#hh4z)"/>';
 const kisiler=[];let sira=0,kalanK=n;
 while(kalanK>0&&sira<5){const adet=Math.min(kalanK,8+sira*3),y=150-sira*9,olcek=1-sira*0.1;
  for(let i=0;i<adet;i++)kisiler.push({x:140+(i-(adet-1)/2)*(15*olcek),y,o:olcek});kalanK-=adet;sira++;}
 kisiler.reverse().forEach((k,i)=>{const ad=adlar[i%Math.max(1,adlar.length)]||'',r=renkAd(ad||String(i));
  s+='<g class="kisi" style="animation-delay:'+((i*0.37)%2.4).toFixed(2)+'s"><path d="M'+(k.x-5*k.o).toFixed(1)+' '+(k.y+12*k.o).toFixed(1)+' q'+(5*k.o).toFixed(1)+' -'+(14*k.o).toFixed(1)+' '+(10*k.o).toFixed(1)+' 0z" fill="'+r+'" opacity=".9"/><circle cx="'+k.x.toFixed(1)+'" cy="'+(k.y-1*k.o).toFixed(1)+'" r="'+(3.6*k.o).toFixed(1)+'" fill="#f1c9a5"/>';
  if(gece&&i%3===0)s+='<path class="alev" d="M'+(k.x+4*k.o).toFixed(1)+' '+(k.y-9*k.o).toFixed(1)+' q2 -5 0 -9 q-2 4 0 9z" fill="#ffb347"/>';
  s+='</g>';});
 (sa.pankartlar||[]).slice(0,3).forEach((p,i)=>{const px=96+i*50,py=104-(i%2)*8,m=String(p.metin||'').slice(0,18);
  s+='<g class="pankart" style="animation-delay:'+(i*0.8)+'s"><line x1="'+(px+22)+'" y1="'+(py+14)+'" x2="'+(px+22)+'" y2="'+(py+34)+'" stroke="#6b4a2b" stroke-width="1.5"/><rect x="'+px+'" y="'+py+'" width="44" height="15" rx="2" fill="#fff6dc" stroke="#d9b56a"/><text x="'+(px+22)+'" y="'+(py+10)+'" text-anchor="middle" font-size="5.2" font-weight="800" fill="#7a1f1f">'+esc(m)+'</text></g>';});
 for(let i=0;i<g;i++){const gx=262+(i%5)*11,gy=146-Math.floor(i/5)*10;s+='<g><rect x="'+(gx-4)+'" y="'+(gy-2)+'" width="8" height="12" rx="2" fill="#3c6fd1"/><circle cx="'+gx+'" cy="'+(gy-5)+'" r="3.4" fill="#1d3f86"/><rect x="'+(gx-5.5)+'" y="'+(gy)+'" width="3" height="9" rx="1" fill="#9cc0ff" opacity=".85"/></g>';}
 for(let i=0;i<ks;i++){const kx=322+(i%3)*11,ky=150-Math.floor(i/3)*9;s+='<g opacity=".85"><rect x="'+(kx-4)+'" y="'+(ky-1)+'" width="8" height="11" rx="2" fill="#8a93b3"/><circle cx="'+kx+'" cy="'+(ky-4)+'" r="3.2" fill="#d6dcef"/></g>';}
 if(!n)s+='<text x="180" y="150" text-anchor="middle" font-size="11" fill="#e6eaff" opacity=".85">Meydan şu an boş</text>';
 if(E.kirmizi)s+='<rect class="kirmizi-isik" width="360" height="190" fill="#ff2d4b"/>';
 return s+'</svg>';
}

/* ── ana ekran ── */
function anaHTML(M){
 const ak=M.aktif,har=M.harita||{},kriz=(M.merkez&&M.merkez.kriz)||{};
 const serit=[...(har.manset||[]),...(har.serit||[])].filter(Boolean);
 const kirmizi=ak.filter(e=>e.kirmizi),kirmiziKisi=kirmizi.reduce((t,e)=>t+e.kisi,0);
 const roller=[];
 if(M.unvan)roller.push(['devlet','🏛️ '+M.unvan]);else if(M.yon)roller.push(['devlet','🏛️ Hükümet yetkilisi']);
 const kat=ak.filter(e=>e.katilimci).length;if(kat)roller.push(['meydan','✊ '+kat+' eylemde sahadasın']);
 const gor=ak.filter(e=>e.gorevde).length;if(gor)roller.push(['devlet','🦺 '+gor+' eylemde görevdesin']);
 if(M.iktidar&&!M.yon)roller.push(['','🏳️ İktidar saflarında']);
 if(M.gazeteci)roller.push(['','📰 Gazeteci']);if(M.vekil)roller.push(['','🏛️ Milletvekili']);if(M.kabine)roller.push(['','💼 Kabine üyesi']);
 if(!roller.length)roller.push(['','👀 Tarafsız gözlemci · kamuoyu nabzı senin elinde']);
 let h='<div class="hh4-hero"><div class="hh4-kicker">Seçim Online · Halk Hareketleri</div><h2>Meydanlar</h2>'+
  '<p class="m" style="margin:0">'+ak.length+' canlı eylem · '+ak.reduce((t,e)=>t+e.kisi,0)+' kişi sahada</p>'+
  '<div class="hh4-roller">'+roller.map(r=>'<span class="hh4-rol '+r[0]+'">'+esc(r[1])+'</span>').join('')+'</div>'+
  '<div class="hh4-kriz"><div class="'+(kirmizi.length>=3?'tehlike':'')+'"><strong>'+kirmizi.length+'/3</strong><span>Kırmızı il (ulusal kriz için)</span></div>'+
  '<div class="'+(kirmiziKisi>=15?'tehlike':'')+'"><strong>'+kirmiziKisi+'</strong><span>Kırmızı meydanlardaki kişi (en az 15)</span></div>'+
  '<div class="'+(kriz.kirmizi_baslangic?'tehlike':'')+'"><strong>'+(kriz.kirmizi_baslangic?geri(new Date(Date.parse(kriz.kirmizi_baslangic)+72*3600e3).toISOString()):'—')+'</strong><span>'+(kriz.kirmizi_baslangic?'Erken seçime kalan':'Kriz sayacı kapalı')+'</span></div></div>'+
  (serit.length?'<div class="hh4-serit"><b>SON DAKİKA</b><span>'+serit.map(esc).join('  •  ')+'</span></div>':'')+'</div>';
 const bek=ak.reduce((t,e)=>t+((S.parca&&S.parca.eylem[e.id]&&S.parca.eylem[e.id].bant.length)||0),0);
 if(bek||(S.parca&&S.parca.davet))h+='<div class="hh4-bas"><h3>🔔 Sana bekleyenler</h3><small>'+(bek+(S.parca&&S.parca.davet?1:0))+' iş</small></div><div class="hh4-gelen">'+
  ak.filter(e=>S.parca&&S.parca.eylem[e.id]&&S.parca.eylem[e.id].bant.length).map(e=>'<button type="button" class="hh4-is acil" data-hh4-ac="'+e.id+'"><i>⚡</i><span><b>'+esc(e.x.il)+' meydanında '+S.parca.eylem[e.id].bant.length+' yanıt bekleyen iş</b><small>Gizli teklifler, oylamalar ve çağrılar eylem ekranının en üstünde.</small></span></button>').join('')+
  (S.parca&&S.parca.davet?'<button type="button" class="hh4-is" data-hh4-kaydir="hh4Davet"><i>🤝</i><span><b>Kuruluşuna destek daveti var</b><small>Kabul, ret ya da çekimser yanıt ver.</small></span></button>':'')+'</div>';
 h+='<div class="hh4-bas"><h3>🔥 Canlı meydanlar</h3><small>Dokun, meydana gir</small></div>';
 if(!ak.length)h+='<div class="hh4-bos">Şu anda canlı eylem yok.<br><span class="m">Aşağıdaki çağrı bölümünden yeni bir hareket başlatılabilir.</span></div>';
 else h+='<div class="hh4-meydanlar">'+ak.map(e=>mkart(e)).join('')+'</div>';
 h+='<div class="hh4-bas"><h3>✊ Yeni hareket</h3><small>Çağrı → imza → eylem</small></div>'+
  '<details class="hh4-ac"'+(S.acik.cagri?' open':'')+' data-hh4-hatirla="cagri"><summary>📣 Eylem çağrısı aç ya da imza ver</summary><div class="ic"><div class="hh4-adim"><span class="ok">1 · Çağrı</span><span>2 · İl sakinlerinin imzası</span><span>3 · Eylem açılır</span></div><div data-hh4-yuva="cagri"></div></div></details>';
 if(S.parca&&S.parca.davet)h+='<details class="hh4-ac" open id="hh4Davet"><summary>🤝 Kuruluş davetleri</summary><div class="ic" data-hh4-yuva="davet"></div></details>';
 if(S.parca&&S.parca.hukuk)h+='<details class="hh4-ac"'+(S.acik.hukuk?' open':'')+' data-hh4-hatirla="hukuk" id="hh4Hukuk"><summary>⚖️ Gözaltı, avukat ve mahkeme</summary><div class="ic" data-hh4-yuva="hukuk"></div></details>';
 h+='<details class="hh4-ac"'+(S.acik.harita?' open':'')+' data-hh4-hatirla="harita"><summary>🗺️ Türkiye kriz haritası</summary><div class="ic">'+haritaHTML(har)+'</div></details>';
 if(S.parca&&S.parca.kurumsal.length)h+='<details class="hh4-ac"'+(S.acik.kurumsal?' open':'')+' data-hh4-hatirla="kurumsal"><summary>🏛️ Meclis, kabine ve kayıtlar</summary><div class="ic" data-hh4-yuva="kurumsal"></div></details>';
 h+='<details class="hh4-ac"'+(S.acik.gecmis?' open':'')+' data-hh4-hatirla="gecmis"><summary>📜 Geçmiş eylemler ve meydanın hafızası</summary><div class="ic" data-hh4-yuva="gecmis"></div></details>';
 h+='<details class="hh4-ac"><summary>❔ Nasıl işler?</summary><div class="ic"><p>• Eylemin gücü yalnız gerçek oyunculardan gelir: katılanlar, hamleleri, tarafsızların kamuoyu nabzı, karşı taraftakiler ve sahadaki görevliler.</p><p>• Kırmızı için en az 75 güç ve en az 3 gerçek katılımcı gerekir. Üç kırmızı il, yeterli kalabalıkla 72 saat sürerse erken seçim takvimi işler.</p><p>• Eylem çağrıyla başlar: depozito yatırılır, o ilde yaşayan oyuncular imza verir, imza dolunca eylem açılır.</p><p>• İstediğin an ayrılabilirsin; eylem sohbetini yalnız o an meydanda olanlar görür.</p></div></details>';
 h+='<p style="text-align:center;margin-top:18px"><button type="button" class="hh4-btn hayalet kucuk" data-hh4-klasik="1">Klasik görünümü aç</button></p>';
 return h;
}
function mkart(e){
 const x=e.x,sa=e.sa||{},em=e.em||{},adlar=(x.katilim_ayrintilari||[]).map(k=>k.ad);
 const et=[];
 if(e.katilimci)et.push(['ben','✊ Sahadasın']);if(e.gorevde)et.push(['mavi','🦺 Görevdesin']);if(e.karsi)et.push(['mavi','🚩 Karşı taraftasın']);if(e.org)et.push(['ben','⭐ Organizatör']);
 if(e.kirmizi)et.push(['tehlike','🔴 Kırmızı']);if(sa.yasak)et.push(['uyari','⛔ Yasak']);if(sa.grev_bitis)et.push(['uyari','✊ Grev']);
 if(em.isgal&&em.isgal.durum==='aktif')et.push(['tehlike','🏢 İşgal']);if(em.isgal&&em.isgal.tahliye&&em.isgal.tahliye.durum==='geri_sayim')et.push(['tehlike','⏳ Tahliye']);
 const b=S.parca&&S.parca.eylem[e.id]&&S.parca.eylem[e.id].bant.length;if(b)et.push(['tehlike','⚡ '+b+' iş']);
 return '<button type="button" class="hh4-mkart'+(e.kirmizi?' kirmizi':'')+'" data-hh4-ac="'+e.id+'"><div class="ust">'+halka(e.seviye)+
  '<div class="ic"><h4>'+esc(x.il)+' <span class="m">#'+e.id+'</span></h4><p class="m" style="margin:2px 0 0">'+esc(x.parti||'Bağımsız')+' · '+esc(TALEP[x.talep]||'Talep seçilmedi')+'</p>'+
  '<p style="margin:4px 0 0;font-size:13.5px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden">'+esc(x.gerekce)+'</p></div></div>'+
  '<div class="hh4-kalabalik">'+adlar.slice(0,7).map(a=>'<span class="av" style="background:'+renkAd(a)+'" title="'+esc(a)+'">'+bas(a)+'</span>').join('')+'<em>'+e.kisi+' kişi · '+geri(x.bitis)+' kaldı</em></div>'+
  '<div class="alt">'+et.map(t=>'<span class="hh4-etiket '+t[0]+'">'+esc(t[1])+'</span>').join('')+'</div></button>';
}
function haritaHTML(har){
 const iller=(har.iller||[]).slice().sort((a,b)=>Number(a.id)-Number(b.id));
 if(!iller.length)return '<p class="m">Harita verisi alınamadı.</p>';
 const renk=v=>{v=Number(v||0);return v>=60?'#a8283f':v>=45?'#b4532a':v>=35?'#9a7a24':v>=20?'#2f6a58':'#1f4a5a';};
 return '<div class="hh4-harita">'+iller.map(i=>'<button type="button" class="'+(i.eylem?'var':'')+'" style="background:'+renk(i.memnuniyetsizlik)+'" data-hh4-il="'+esc(i.ad)+' · memnuniyetsizlik '+num(i.memnuniyetsizlik,0)+(i.eylem?' · canlı eylem':'')+'" aria-label="'+esc(i.ad)+'">'+String(i.id).padStart(2,'0')+'</button>').join('')+'</div>'+
  '<div class="hh4-lejant"><span><i style="background:#1f4a5a"></i>sakin</span><span><i style="background:#9a7a24"></i>gergin</span><span><i style="background:#b4532a"></i>öfkeli</span><span><i style="background:#a8283f"></i>patlamaya hazır</span><span>⬜ canlı eylem</span></div>';
}

/* ── eylem ekranı ── */
const SEKMELER=[['akis','📡 Akış'],['sohbet','💬 Sohbet'],['hamle','✊ Hamleler'],['devlet','🏛️ Devlet'],['kurum','🎙️ Kurumlar'],['guc','📊 Güç']];
function eylemHTML(E){
 const x=E.x,sa=E.sa||{},dk=sa.dokum||{},dg=E.dg||{},em=E.em||{},hz=em.hazine||{};
 const cub=(ad,v,renk,yaz)=>'<div class="hh4-cubuk">'+ad+' <b style="color:#fff">'+yaz+'</b><div><i style="width:'+Math.max(0,Math.min(100,Number(v)||0))+'%;background:'+renk+'"></i></div></div>';
 let h='<button type="button" class="hh4-geri" data-hh4-ana="1">‹ Meydanlar</button>'+
  '<div class="hh4-sahne">'+sahne(E)+'<div class="bilgi"><div><h2>'+esc(x.il)+' meydanı</h2><p>#'+E.id+' · '+esc(x.parti||'Bağımsız')+' · '+esc(TALEP[x.talep]||'Talep seçilmedi')+'</p></div>'+
  '<div style="text-align:right"><span class="hh4-canli">CANLI</span><p>'+geri(x.bitis)+' kaldı</p></div></div></div>';
 h+='<div class="hh4-gosterge">'+halka(E.seviye,84)+'<div class="hh4-cubuklar">'+
  cub('Kamuoyu sempatisi',dk.sempati,'#46d39f',num(dk.sempati,0))+
  (dg.ivme!=null?cub('İvme',dg.ivme,'#6ea8ff',num(dg.ivme,0)):'')+
  (dg.yorgunluk!=null?cub('Yorgunluk',dg.yorgunluk,'#ff9b45',num(dg.yorgunluk,0)):'')+
  cub('Kırmızı eşiğe',Math.min(100,E.seviye/75*100),seviyeRenk(E.seviye),E.seviye>=75?'aşıldı':num(75-E.seviye,0)+' kaldı')+'</div></div>';
 h+='<div class="hh4-sayilar"><div><strong>'+E.kisi+'</strong><span>katılımcı</span></div><div><strong>'+num(dk.gorevli||0,0)+'</strong><span>görevli</span></div><div><strong>'+num(dk.karsi||0,0)+'</strong><span>karşı taraf</span></div><div><strong>'+(hz.toplam_tl!=null?num(Number(hz.toplam_tl)/1000,0)+'b':'—')+'</strong><span>hazine bedeli (TL)</span></div></div>';
 const U=[];
 if(E.kirmizi)U.push(['kirmizi','🔴','<b>Kırmızı seviyede.</b> Ulusal kriz sayacına katkı veriyor.']);
 if(sa.gozaltindayim)U.push(['kirmizi','🚓','<b>Gözaltındasın.</b> Ana ekrandaki hukuk bölümünden avukat çağırabilir, itiraz edebilirsin.']);
 if(em.isgal&&em.isgal.tahliye&&em.isgal.tahliye.durum==='geri_sayim')U.push(['kirmizi','⏳','<b>Tahliye geri sayımı:</b> '+geri(em.isgal.tahliye.bitis)+'. Hamleler sekmesinden tarafını seç.']);
 if(em.isgal&&em.isgal.durum==='aktif')U.push(['turuncu','🏢','<b>'+esc(em.isgal.bina)+' işgal altında.</b> Nöbet '+num(em.isgal.nobet,0)+' · güç '+num(em.isgal.guc,0)]);
 if(sa.yasak)U.push(['turuncu','⛔','<b>'+esc(sa.yasak.unvan)+' gösteri yasağı</b> · '+geri(sa.yasak.bitis)+' · yeni katılım kapalı']);
 if(sa.grev_bitis)U.push(['turuncu','✊','<b>Genel grev çağrısı sürüyor</b> · '+geri(sa.grev_bitis)]);
 if(sa.seslenis)U.push(['mavi','📺','<b>Cumhurbaşkanı seslendi:</b> '+num(sa.seslenis.ikna,0)+' ikna · '+num(sa.seslenis.olmadi,0)+' olmadı']);
 if(sa.jest)U.push(['yesil','🕊️','<b>Hükümetten jest:</b> '+num(sa.jest.serbest,0)+' gözaltı sona erdi']);
 if(dg.not)U.push(['mavi','💡','<b>Son hamle:</b> '+esc(dg.not)]);
 const p=S.parca&&S.parca.eylem[E.id]||{bant:[]};
 h+='<div class="hh4-uyarilar">'+U.map(u=>'<div class="hh4-uyari '+u[0]+'"><i>'+u[1]+'</i><div>'+u[2]+'</div></div>').join('')+(p.bant.length?'<div data-hh4-yuva="bant"></div>':'')+'</div>';
 h+='<div class="hh4-cta">';
 if(!E.katilimci&&!E.gorevde&&p.katil)h+='<div class="tek hh4-panel" style="padding:12px"><b>🙋 Meydana katıl</b><p class="m">Gücü gerçek katılımcılar belirler. İstediğin an ayrılabilirsin.</p><div data-hh4-yuva="katil"></div></div>';
 if(E.katilimci)h+='<button type="button" class="hh4-btn ana" data-hh4-sekme="hamle">✊ Hamle yap</button><button type="button" class="hh4-btn" data-hh4-sekme="sohbet">💬 Meydan sohbeti</button>';
 else if(M_yon())h+='<button type="button" class="hh4-btn" data-hh4-sekme="devlet">🏛️ Devlet masası</button><button type="button" class="hh4-btn hayalet" data-hh4-sekme="akis">📡 Gelişmeler</button>';
 h+='</div>';
 const ok=S.sohbet[E.id]&&S.sohbet[E.id].yeni||0, ak=S.akis[E.id]&&S.akis[E.id].yeni||0;
 h+='<nav class="hh4-sekmeler" role="tablist">'+SEKMELER.map(([k,ad])=>'<button type="button" role="tab" class="'+(S.sekme===k?'acik':'')+'" data-hh4-sekme="'+k+'">'+ad+(k==='sohbet'&&!E.katilimci?' 🔒':'')+
  (k==='sohbet'&&ok&&S.sekme!=='sohbet'?'<sup>'+ok+'</sup>':'')+(k==='akis'&&ak&&S.sekme!=='akis'?'<sup>'+ak+'</sup>':'')+'</button>').join('')+'</nav>';
 h+='<div data-hh4-sekme-ic="akis"'+(S.sekme==='akis'?'':' hidden')+'>'+akisKabuk(E)+'</div>';
 h+='<div data-hh4-sekme-ic="sohbet"'+(S.sekme==='sohbet'?'':' hidden')+'>'+sohbetKabuk(E)+'</div>';
 h+='<div data-hh4-sekme-ic="hamle"'+(S.sekme==='hamle'?'':' hidden')+'>'+
  (E.katilimci?'<p class="m">Sahadaki rolün, büyük hamleler ve katılımların. Her kartta bedel ve koşul yazar; kilitli kartlar nedenini gösterir.</p>':'<p class="m">Katılmadan da etkileyebilirsin: kamuoyu nabzı, karşı tarafta yer almak, dayanışma ve destek.</p>')+
  '<div data-hh4-yuva="em-hamle"></div><div data-hh4-yuva="saha"></div><div class="hh4-grup"><h4>🤲 Destek, davet ve duyuru</h4></div><div data-hh4-yuva="destek"></div></div>';
 h+='<div data-hh4-sekme-ic="devlet"'+(S.sekme==='devlet'?'':' hidden')+'><p class="m">Hükümetin attığı adımlar, açık önlemler ve onlara verilebilecek karşılıklar. Araçları Cumhurbaşkanı, İçişleri Bakanı ve ilin valisi kullanır; kartlarda bedel ve risk yazar.</p><div data-hh4-yuva="em-devlet"></div><div data-hh4-yuva="devlet"></div><div data-hh4-yuva="devlet-akis"></div></div>';
 h+='<div data-hh4-sekme-ic="kurum"'+(S.sekme==='kurum'?'':' hidden')+'><p class="m">Basın, jüri, boykot, meşale ve rolüne açık diğer işler.</p><div data-hh4-yuva="kurum"></div></div>';
 h+='<div data-hh4-sekme-ic="guc"'+(S.sekme==='guc'?'':' hidden')+'>'+gucHTML(E)+'</div>';
 return h;
}
function M_yon(){return !!(S.model&&S.model.yon);}
function gucHTML(E){
 const x=E.x,sa=E.sa||{},dk=sa.dokum||{},dg=E.dg||{},em=E.em||{},hz=em.hazine||{},ky=E.ky||{};
 const sat=(dk.satirlar||[]).filter(r=>Number(r.puan)!==0);
 let h='<div class="hh4-panel"><h4 style="margin-bottom:6px">Gücün dökümü · toplam '+num(dk.toplam!=null?dk.toplam:E.seviye)+'</h4>'+
  (sat.length?'<table class="hh4-tablo">'+sat.map(r=>'<tr><td>'+esc(r.ad)+'</td><td class="'+(Number(r.puan)>0?'art':'eks')+'">'+(Number(r.puan)>0?'+':'')+num(r.puan)+'</td></tr>').join('')+'</table>':'<p class="m">Henüz etki yok.</p>')+
  '<p class="m">Kırmızı eşik 75 ve en az 3 gerçek katılımcı. Para gücü artırmaz; yalnız süreyi uzatır ya da kaynak aktarımıyla sınırlı katkı yapar.</p></div>';
 h+='<div class="hh4-panel" style="margin-top:10px"><h4 style="margin-bottom:6px">Denge</h4><table class="hh4-tablo">'+
  '<tr><td>Kamuoyu nabzı (destek · karşı)</td><td>'+num(dk.destek,0)+' · '+num(dk.karsi_nabiz,0)+'</td></tr>'+
  (dg.ivme!=null?'<tr><td>İvme / yorgunluk</td><td>'+num(dg.ivme,0)+' / '+num(dg.yorgunluk,0)+'</td></tr>':'')+
  (dg.tavan!=null?'<tr><td>İldeki katılımcı tavanı</td><td>'+num(dg.tavan,0)+'</td></tr>':'')+
  '<tr><td>Eylem fonu · uzlaşma fonu</td><td>'+tl(x.muhalefet_fonu)+' · '+tl(x.iktidar_fonu)+'</td></tr>'+
  (ky.toplam!=null?'<tr><td>Aktarılan kaynak</td><td>'+tl(ky.toplam)+'</td></tr>':'')+
  (hz.toplam_tl!=null?'<tr><td>Hazine bedeli (saatlik)</td><td>'+tl(hz.toplam_tl)+' ('+tl(hz.saatlik_tl)+')</td></tr>':'')+
  '<tr><td>Bitiş</td><td>'+esc(tarih(x.bitis))+'</td></tr></table></div>';
 const kisi=(x.katilim_ayrintilari||[]),gor=sa.gorevliler||[],ks=sa.karsidakiler||[];
 h+='<div class="hh4-panel" style="margin-top:10px"><h4 style="margin-bottom:6px">Sahada kim var?</h4>'+
  '<p class="m">✊ Katılımcılar ('+kisi.length+')</p><div class="hh4-kisiler">'+(kisi.map(k=>'<span>'+esc(k.ad)+' <span class="m">· '+esc(k.sifat)+'</span></span>').join('')||'<span class="m">Kimse yok</span>')+'</div>'+
  (gor.length?'<p class="m">🦺 Görevliler</p><div class="hh4-kisiler">'+gor.map(g=>'<span>'+esc(g.ad)+' <span class="m">· '+esc(g.unvan)+'</span></span>').join('')+'</div>':'')+
  (ks.length?'<p class="m">🚩 Karşı taraf</p><div class="hh4-kisiler">'+ks.map(k=>'<span>'+esc(k)+'</span>').join('')+'</div>':'')+'</div>';
 return h;
}

/* ── akış ── */
const AKIS_IKON={kritik:'🔴',devlet:'🏛️',meydan:'✊',pankart:'📜',katil:'🙋',ayril:'🚶',karsi:'🚩',aciklama:'🎙️',hukuk:'⚖️',para:'💰',durum:'📌',genel:'•'};
const AKIS_FILTRE=[['hepsi','Hepsi'],['devlet','Devlet'],['meydan','Meydan'],['kisi','Kişiler'],['aciklama','Açıklamalar'],['diger','Para · hukuk']];
const filtreUy=(f,t)=>f==='hepsi'||(f==='meydan'&&(t==='meydan'||t==='pankart'||t==='kritik'))||(f==='kisi'&&(t==='katil'||t==='ayril'||t==='karsi'))||(f==='diger'&&(t==='para'||t==='hukuk'||t==='durum'||t==='genel'))||f===t;
function akisKabuk(E){
 return '<div class="hh4-filtre">'+AKIS_FILTRE.map(([k,ad])=>'<button type="button" class="'+(S.akisFiltre===k?'acik':'')+'" data-hh4-filtre="'+k+'">'+ad+'</button>').join('')+'</div><div data-hh4-akis="'+E.id+'">'+akisListe(E.id)+'</div>';
}
function akisListe(id,sadece){
 const A=S.akis[id];if(!A)return '<p class="m">Gelişmeler yükleniyor…</p>';
 const f=sadece||S.akisFiltre;const L=(A.liste||[]).filter(o=>filtreUy(f,o.tur));
 if(!L.length)return '<div class="hh4-bos">Bu filtrede gelişme yok.</div>';
 const gun=z=>{const d=new Date(z),b=new Date();const ay=x=>x.toLocaleDateString('tr-TR',{timeZone:'Europe/Istanbul'});return ay(d)===ay(b)?'Bugün':ay(d)===ay(new Date(b-864e5))?'Dün':d.toLocaleDateString('tr-TR',{day:'numeric',month:'long',timeZone:'Europe/Istanbul'});};
 let h='<div class="hh4-akis">',son='';
 L.forEach(o=>{const g=gun(o.zaman);if(g!==son){h+='<div class="hh4-gun">'+g+'</div>';son=g;}
  const m=String(o.metin||'').replace(/^Eylem #\d+:\s*/,'').replace(/^\[(muhalefet|hukumet|hukuk|basin)\]\s*/,(a,k)=>({muhalefet:'Eylem cephesinden açıklama · ',hukumet:'Hükümetten açıklama · ',hukuk:'Hukukçudan açıklama · ',basin:'Basından açıklama · '}[k]));
  h+='<div class="hh4-olay '+esc(o.tur)+'" data-ikon="'+(AKIS_IKON[o.tur]||'•')+'"><small>'+saat(o.zaman)+(A.gordu&&Date.parse(o.zaman)>A.gordu?' · <b style="color:#ffd166">yeni</b>':'')+'</small><p>'+esc(m)+'</p></div>';});
 return h+'</div>';
}
async function akisYukle(id){
 let r=await rpc('sokak_eylem_akis',{p_eylem:id,p_sinir:80});
 if(!Array.isArray(r))r=[];
 const A=S.akis[id]||(S.akis[id]={liste:[],gordu:0,yeni:0});
 const enYeni=r.length?Date.parse(r[0].zaman):0;
 if(A.gordu&&S.sekme!=='akis')A.yeni=r.filter(o=>Date.parse(o.zaman)>A.gordu).length;
 A.liste=r;if(!A.gordu||S.sekme==='akis'){A.gordu=Math.max(A.gordu||0,enYeni||Date.now());A.yeni=0;}
 const kutu=document.querySelector('#hh4 [data-hh4-akis="'+id+'"]');if(kutu)kutu.innerHTML=akisListe(id);
 const dv=document.querySelector('#hh4 [data-hh4-yuva="devlet-akis"]');
 if(dv)dv.innerHTML='<div class="hh4-grup"><h4>🕑 Hükümet adımları · son gelişmeler</h4></div>'+akisListe(id,'devlet');
 rozetGuncelle();
}

/* ── sohbet: yalnız meydandakiler ── */
const HIZLI=['✊ Meydandayım','Nöbet sırası bende','Avukat desteği lazım','Saat 21.00’de buluşalım','Pankartım hazır','Teşekkürler, birlikte güçlüyüz'];
function sohbetKabuk(E){
 if(!E.katilimci)return '<div class="hh4-sohbet"><div class="hh4-kilit"><i>🔒</i><h3>Meydan sohbeti</h3><p>Bu sohbeti yalnız o an eylemin içinde olan oyuncular görür ve yazar. Eylemden ayrılan bir daha göremez.</p>'+
  (S.parca&&S.parca.eylem[E.id]&&S.parca.eylem[E.id].katil?'<button type="button" class="hh4-btn ana" data-hh4-sekme="hamle">🙋 Katılıp sohbete gir</button>':'')+'</div></div>';
 const C=S.sohbet[E.id]||{};
 return '<div class="hh4-sohbet"><div class="bas"><span style="font-size:20px">💬</span><b>Meydan sohbeti</b><span class="hh4-etiket ben">🔒 '+(C.uye!=null?C.uye+' kişi':'yalnız meydandakiler')+'</span></div>'+
  '<div data-hh4-sabit="'+E.id+'">'+sabitHTML(E.id)+'</div>'+
  '<div class="hh4-mesajlar" data-hh4-mesajlar="'+E.id+'">'+mesajlarHTML(E.id)+'</div>'+
  '<div class="hh4-hizli">'+HIZLI.map(t=>'<button type="button" data-hh4-hizli="'+esc(t)+'">'+esc(t)+'</button>').join('')+'</div>'+
  '<form class="hh4-yaz" data-hh4-yaz="'+E.id+'"><textarea name="m" maxlength="400" rows="1" placeholder="Meydana yaz… (Enter gönderir)"'+(C.yazabilir===false?' disabled':'')+'>'+esc(S.taslak[E.id]||'')+'</textarea><button class="hh4-btn ana" aria-label="Gönder"'+(C.yazabilir===false?' disabled':'')+'>➤</button></form>'+
  (C.neden?'<p class="m" style="padding:0 12px 10px;margin:0">'+esc(C.neden)+'</p>':'')+'</div>';
}
function sabitHTML(id){
 const C=S.sohbet[id];if(!C||!C.sabit)return '';
 return '<div class="hh4-sabit">📌 <b>'+esc(C.sabit.ad)+':</b> '+esc(C.sabit.metin)+(C.sabitleyebilir?' <button type="button" class="hh4-btn hayalet kucuk" data-hh4-sabitle="" style="margin-left:6px;min-height:26px;padding:2px 8px">Kaldır</button>':'')+'</div>';
}
function mesajlarHTML(id){
 const C=S.sohbet[id];if(!C)return '<p class="m" style="text-align:center">Sohbet yükleniyor…</p>';
 const L=C.mesajlar||[];if(!L.length)return '<p class="m" style="text-align:center;margin-top:30px">Henüz mesaj yok. İlk sözü sen söyle ✊</p>';
 const ROL={organizator:'organizatör',gozalti:'gözaltında',ayrildi:'ayrıldı'};
 let h='',onceki=null;
 L.forEach(m=>{const ayni=onceki&&onceki.ad===m.ad&&Date.parse(m.zaman)-Date.parse(onceki.zaman)<300000;
  h+='<div class="hh4-msj'+(m.ben?' ben':'')+(m.rol==='organizator'?' organizator':'')+'">'+
   (!m.ben&&!ayni?'<div class="ad" style="color:'+renkAd(m.ad)+'">'+esc(m.ad)+(m.rol?'<em class="'+esc(m.rol)+'">'+esc(ROL[m.rol]||m.rol)+'</em>':'')+'</div>':'')+
   '<div class="balon">'+esc(m.metin)+'</div><div class="alt">'+(C.tepkiVar?'<button type="button" class="'+(m.tepkim?'acik':'')+'" data-hh4-tepki="'+Number(m.id)+'">✊ '+(m.tepki||'')+'</button>':'')+
   (C.sabitleyebilir?'<button type="button" data-hh4-sabitle="'+Number(m.id)+'" title="Sabitle">📌</button>':'')+'<span>'+saat(m.zaman)+'</span></div></div>';
  onceki=m;});
 return h;
}
async function sohbetYukle(id,kaydir){
 const E=bul(id);if(!E||!E.katilimci)return;
 let r=await rpc('sokak_sohbet_akis',{p_eylem:id}),C;
 if(r&&Array.isArray(r.mesajlar))C=Object.assign(r,{tepkiVar:true});
 else{const eski=await rpc('sokak_sohbet_oku',{p_eylem:id});if(!Array.isArray(eski))return;C={mesajlar:eski,yazabilir:true,tepkiVar:false};}
 const once=S.sohbet[id]||{};const sonId=Math.max(0,...(C.mesajlar||[]).map(m=>Number(m.id)));
 C.gordu=once.gordu||0;
 if(S.gorunum==='eylem'&&S.eylem===id&&S.sekme==='sohbet'){C.gordu=sonId;C.yeni=0;}
 else C.yeni=C.gordu?(C.mesajlar||[]).filter(m=>Number(m.id)>C.gordu&&!m.ben).length:0;
 if(!C.gordu&&!once.gordu)C.gordu=sonId;
 S.sohbet[id]=C;
 const kutu=document.querySelector('#hh4 [data-hh4-mesajlar="'+id+'"]');
 if(kutu){const altta=kutu.scrollHeight-kutu.scrollTop-kutu.clientHeight<80;kutu.innerHTML=mesajlarHTML(id);if(altta||kaydir)kutu.scrollTop=kutu.scrollHeight;}
 const sb=document.querySelector('#hh4 [data-hh4-sabit="'+id+'"]');if(sb)sb.innerHTML=sabitHTML(id);
 const f=document.querySelector('#hh4 [data-hh4-yaz="'+id+'"]');
 if(f){f.querySelector('textarea').disabled=C.yazabilir===false;f.querySelector('button').disabled=C.yazabilir===false;}
 rozetGuncelle();
}
function rozetGuncelle(){
 const id=S.eylem;if(S.gorunum!=='eylem'||!id)return;
 document.querySelectorAll('#hh4 .hh4-sekmeler button').forEach(b=>{
  const k=b.dataset.hh4Sekme,n=k==='sohbet'?(S.sohbet[id]&&S.sohbet[id].yeni||0):k==='akis'?(S.akis[id]&&S.akis[id].yeni||0):0;
  let sup=b.querySelector('sup');if(n&&S.sekme!==k){if(!sup){sup=document.createElement('sup');b.appendChild(sup);}sup.textContent=n;}else if(sup)sup.remove();
 });
}

/* ── yuvalar: taşınan eski bloklar yeni yerlerine ── */
function emGoster(em,mod,E){
 if(!em)return;
 const yetkili=M_yon()||!!(E&&E.em&&E.em.yetkili);
 em.querySelectorAll('[data-em-panel]').forEach(p=>{const k=p.getAttribute('data-em-panel');
  p.hidden=mod==='hamle'?k!=='eylem':!(k==='isgal'||k==='butce'||(k==='hukumet'&&yetkili));});
}
function yerlestir(kok){
 const P=S.parca;if(!P)return;
 const yuva=(ad,nodes)=>{const y=kok.querySelector('[data-hh4-yuva="'+ad+'"]');if(!y)return;(nodes||[]).forEach(n=>{if(!n)return;if(n.hasAttribute&&n.hasAttribute('data-hh-panel'))n.hidden=false;if(n.style&&n.style.display==='none')n.style.display='';y.appendChild(n);});};
 if(S.gorunum==='ana'){
  yuva('cagri',[P.cagri]);yuva('davet',[P.davet]);yuva('hukuk',[P.hukuk]);yuva('kurumsal',P.kurumsal);yuva('gecmis',[P.hafiza,P.gecmis]);
  return;
 }
 const E=bul(S.eylem),p=P.eylem[S.eylem];if(!E||!p)return;
 yuva('bant',p.bant);yuva('katil',[p.katil]);
 if(S.sekme==='devlet'){yuva('em-devlet',[p.em]);emGoster(p.em,'devlet',E);}else if(E.katilimci){yuva('em-hamle',[p.em]);emGoster(p.em,'hamle',E);}
 yuva('saha',[p.saha]);yuva('destek',p.destek);yuva('devlet',p.devlet);yuva('kurum',p.kurum);
 const ku=kok.querySelector('[data-hh4-yuva="kurum"]');if(ku&&!ku.children.length)ku.innerHTML='<div class="hh4-bos">Bu eylemde rolüne açık kurumsal bir işlem yok.</div>';
 const dv=kok.querySelector('[data-hh4-yuva="devlet"]');if(dv&&!dv.children.length&&!p.em)dv.innerHTML='<div class="hh4-bos">Bu eylemde şu an açık bir hükümet adımı yok.</div>';
}

/* ── çizim ── */
function gorunumCiz(){
 const kok=document.getElementById('hh4');if(!kok||!S.model)return;
 if(S.gorunum==='eylem'&&!bul(S.eylem))S.gorunum='ana';
 const E=S.gorunum==='eylem'?bul(S.eylem):null;
 kok.innerHTML=E?eylemHTML(E):anaHTML(S.model);
 yerlestir(kok);
 bagla(kok);
 if(E){
  akisYukle(E.id);if(E.katilimci)sohbetYukle(E.id,true);
  if(S.sekme==='sohbet'){const k=kok.querySelector('[data-hh4-mesajlar]');if(k)k.scrollTop=k.scrollHeight;}
 }
 canliKur();
}
function bagla(kok){
 kok.querySelectorAll('[data-hh4-ac]').forEach(b=>b.addEventListener('click',()=>{S.gorunum='eylem';S.eylem=Number(b.dataset.hh4Ac);S.sekme='akis';gorunumCiz();window.scrollTo&&window.scrollTo(0,0);const ic=document.getElementById('icerik');if(ic)ic.scrollTop=0;}));
 kok.querySelectorAll('[data-hh4-ana]').forEach(b=>b.addEventListener('click',()=>{S.gorunum='ana';gorunumCiz();const ic=document.getElementById('icerik');if(ic)ic.scrollTop=0;}));
 kok.querySelectorAll('[data-hh4-sekme]').forEach(b=>b.addEventListener('click',()=>{
  const k=b.dataset.hh4Sekme;if(S.sekme===k&&!b.closest('.hh4-cta,.hh4-kilit'))return;S.sekme=k;
  if(k==='sohbet'&&S.sohbet[S.eylem]){const C=S.sohbet[S.eylem];C.gordu=Math.max(C.gordu||0,...(C.mesajlar||[]).map(m=>Number(m.id)));C.yeni=0;}
  if(k==='akis'&&S.akis[S.eylem]){const A=S.akis[S.eylem];A.gordu=Date.now();A.yeni=0;}
  gorunumCiz();const nav=document.querySelector('#hh4 .hh4-sekmeler');if(nav&&nav.scrollIntoView)nav.scrollIntoView({block:'start',behavior:'smooth'});
 }));
 kok.querySelectorAll('[data-hh4-filtre]').forEach(b=>b.addEventListener('click',()=>{S.akisFiltre=b.dataset.hh4Filtre;
  kok.querySelectorAll('[data-hh4-filtre]').forEach(x=>x.classList.toggle('acik',x===b));const k=kok.querySelector('[data-hh4-akis]');if(k)k.innerHTML=akisListe(S.eylem);}));
 kok.querySelectorAll('[data-hh4-il]').forEach(b=>b.addEventListener('click',()=>bildir(b.dataset.hh4Il)));
 kok.querySelectorAll('[data-hh4-kaydir]').forEach(b=>b.addEventListener('click',()=>{const t=document.getElementById(b.dataset.hh4Kaydir);if(t){t.open=true;t.scrollIntoView({behavior:'smooth'});}}));
 kok.querySelectorAll('details[data-hh4-hatirla]').forEach(d=>d.addEventListener('toggle',()=>{S.acik[d.dataset.hh4Hatirla]=d.open;}));
 kok.querySelectorAll('[data-hh4-klasik]').forEach(b=>b.addEventListener('click',()=>{S.klasik=true;sokakHareketleriEkrani();}));
 const f=kok.querySelector('form[data-hh4-yaz]');
 if(f){const id=Number(f.dataset.hh4Yaz),ta=f.querySelector('textarea');
  const boy=()=>{ta.style.height='auto';ta.style.height=Math.min(120,ta.scrollHeight)+'px';};
  ta.addEventListener('input',()=>{S.taslak[id]=ta.value;boy();});
  ta.addEventListener('keydown',ev=>{if(ev.key==='Enter'&&!ev.shiftKey){ev.preventDefault();f.requestSubmit?f.requestSubmit():f.dispatchEvent(new Event('submit',{cancelable:true}));}});
  f.addEventListener('submit',async ev=>{ev.preventDefault();const m=ta.value.trim();if(!m)return;const btn=f.querySelector('button');btn.disabled=true;
   try{await API.rpc('sokak_sohbet_yaz',{p_eylem:id,p_metin:m});ta.value='';S.taslak[id]='';boy();await sohbetYukle(id,true);}
   catch(ex){bildir(hata(ex),true);}finally{btn.disabled=!!(S.sohbet[id]&&S.sohbet[id].yazabilir===false);ta.focus();}});
  kok.querySelectorAll('[data-hh4-hizli]').forEach(b=>b.addEventListener('click',()=>{ta.value=(ta.value?ta.value+' ':'')+b.dataset.hh4Hizli;S.taslak[id]=ta.value;boy();ta.focus();}));
 }
 kok.addEventListener('click',async ev=>{
  const t=ev.target.closest('[data-hh4-tepki],[data-hh4-sabitle]');if(!t||!kok.contains(t))return;
  const id=S.eylem;t.disabled=true;
  try{if(t.dataset.hh4Tepki!=null)await API.rpc('sokak_sohbet_tepki',{p_mesaj:Number(t.dataset.hh4Tepki)});
   else{const mid=t.dataset.hh4Sabitle;await API.rpc('sokak_sohbet_sabitle',{p_eylem:id,p_mesaj:mid?Number(mid):null});bildir(mid?'Mesaj sabitlendi':'Sabit mesaj kaldırıldı');}
   await sohbetYukle(id);}catch(ex){bildir(hata(ex),true);t.disabled=false;}
 });
}

/* ── canlı tazeleme ── */
function canliKur(){
 if(!(window.CANLI&&CANLI.izle))return;
 if(S.gorunum==='eylem'&&S.eylem){const id=S.eylem;
  CANLI.izle({anahtarlar:['halk:'+id,'eylem:'+id],tazele:()=>{akisYukle(id);sohbetYukle(id);},hizliMs:20000,yedekMs:90000,yayilim:1500});}
 else if(S.model&&S.model.aktif.length)CANLI.izle({anahtarlar:S.model.aktif.map(e=>'halk:'+e.id),tazele:()=>tazele(false),hizliMs:60000,yedekMs:120000,yayilim:3000});
}
setInterval(()=>{document.querySelectorAll('#hh4 [data-hh4-geri]').forEach(s=>{s.textContent=kalan(s.getAttribute('data-hh4-geri'));});},1000);

/* ── giriş noktası ── */
async function tazele(zorla){
 if(S.mesgul){S.tekrar=true;return;}
 S.mesgul=true;
 try{
  S.acik=S.acik||{};
  if(S.klasik){await klasik();klasikSerit();return;}
  const geriAl=onbellekKur();let M=null;
  try{await klasik();M=await modelYukle();}finally{geriAl();}
  const ic=document.getElementById('icerik');if(!ic||!M)return;
  const kayit=ic.scrollTop;
  let depo=document.getElementById('hh4-depo');if(depo)depo.remove();
  depo=document.createElement('div');depo.id='hh4-depo';depo.hidden=true;
  [...ic.childNodes].forEach(n=>depo.appendChild(n));
  const kok=document.createElement('section');kok.id='hh4';
  ic.appendChild(kok);ic.appendChild(depo);
  S.model=M;S.parca=topla(depo);iyilestir(depo,M);
  gorunumCiz();
  if(!zorla)ic.scrollTop=kayit;
 }finally{S.mesgul=false;if(S.tekrar){S.tekrar=false;setTimeout(()=>tazele(false),60);}}
}
function klasikSerit(){
 const ic=document.getElementById('icerik');if(!ic||document.getElementById('hh4-klasik'))return;
 const d=document.createElement('div');d.id='hh4-klasik';
 d.innerHTML='<button type="button" style="width:100%;margin:8px 0 12px;min-height:46px;border-radius:12px;border:1px solid #a493ff;background:linear-gradient(135deg,#7b62ff,#5b45e0);color:#fff;font-weight:800">✨ Yeni Halk Hareketleri görünümüne dön</button>';
 d.querySelector('button').addEventListener('click',()=>{S.klasik=false;sokakHareketleriEkrani();});
 ic.insertBefore(d,ic.firstChild);
}
sokakHareketleriEkrani=async function(){return tazele(false);};
if(window.__hhSar)sokakHareketleriEkrani=window.__hhSar('meydan4',sokakHareketleriEkrani);
})();

/* Asset refresh: 20261109-9 (Halk Hareketleri 4.0 · Eylem Meydanı) */


/* 09.11.2026 · Kesinleşen mahkeme kararı → Bakan fezlekesi → Cumhurbaşkanı incelemesi.
   Canlı dış modülde ve derlenmiş kaynakta aynı kod kullanılabilir. */
(function(){
 "use strict";
 if(window.SO_BAKAN_FEZLEKE_V1)return;
 if(typeof window.adliyeHtml!=="function"||typeof API==="undefined")return;
 window.SO_BAKAN_FEZLEKE_V1=true;
 function kac(x){return String(x==null?"":x).replace(/[&<>"']/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];});}
 function gun(x){try{return x?new Date(x).toLocaleString("tr-TR"):"—";}catch(_){return "—";}}
 function durum(x){return ({bekliyor:"Cumhurbaşkanlığı incelemesinde",gorevden_alindi:"Bakan görevden alındı",gorevde_tutuldu:"Bakan görevde tutuldu",gorev_sona_erdi:"Görev süresi sona erdi"})[x]||x;}
 var eski=window.adliyeHtml;
 window.adliyeHtml=async function(){
   var ana=await eski.apply(this,arguments),veri;
   try{veri=await API.rpc("bakan_fezleke_listesi");}catch(err){console.warn("Bakan fezlekeleri okunamadı",err);return ana;}
   var dosyalar=Array.isArray(veri&&veri.dosyalar)?veri.dosyalar:[];
   if(!dosyalar.length&&!veri.cb_miyim)return ana;
   var h='<section class="kart" aria-label="Cumhurbaşkanlığı bakan fezlekeleri"><h3>⚖️ Bakan Fezlekeleri · Cumhurbaşkanlığı</h3>'
    +'<p class="alt">Mahkemenin <b>kesinleşmiş</b> kararı sonrası düzenlenen fezlekeler burada incelenir. Fezleke tek başına bakanı görevden almaz.</p>'
    +(veri.cb_miyim?'<p class="alt">İşlem bekleyen: <b>'+Number(veri.bekleyen||0)+'</b></p>':'');
   if(!dosyalar.length)h+='<p class="alt">Bekleyen fezleke bulunmuyor.</p>';
   dosyalar.forEach(function(f){
     h+='<article class="kart" style="margin-top:12px;padding:14px;overflow-wrap:anywhere">'
       +'<b>Fezleke #'+Number(f.id)+' · '+kac(f.bakan)+'</b>'
       +'<div class="kucuk">'+kac(f.bakanlik)+' · Dava #'+Number(f.dava_id)+'</div>'
       +'<div class="kucuk">'+kac(durum(f.durum))+' · '+kac(gun(f.iletilme))+'</div>'
       +'<div class="kucuk"><b>Mahkeme kararı:</b> '+kac(f.karar)+' · '+kac(f.mahkeme_gerekce)+'</div>'
       +(f.cb_gerekce?'<p class="alt"><b>Cumhurbaşkanlığı gerekçesi:</b> '+kac(f.cb_gerekce)+'</p>':'')
       +'<button class="btn ikinci" style="width:100%;min-height:44px;margin-top:10px" onclick="adliyeDosya('+Number(f.dava_id)+')">Mahkeme dosyasını aç</button>'
       +(f.islem_yapabilirim
          ?'<button class="btn tehlike" style="width:100%;min-height:44px;margin-top:8px" onclick="bakanFezlekeKarar('+Number(f.id)+',\'gorevden_al\')">Bakanı görevden al</button>'
           +'<button class="btn ikinci" style="width:100%;min-height:44px;margin-top:8px" onclick="bakanFezlekeKarar('+Number(f.id)+',\'gorevde_tut\')">Görevde tut</button>'
          :'')+'</article>';
   });
   return h+'</section>'+ana;
 };
 window.bakanFezlekeKarar=function(id,karar){
   if(karar!=="gorevden_al"&&karar!=="gorevde_tut")return;
   var bas=karar==="gorevden_al"?"Bakanı görevden al":"Bakanı görevde tut";
   var m=modal('<div class="alan" style="display:block;width:100%;max-width:100%;box-sizing:border-box">'
      +'<label for="bfGerekce" style="display:block;font-size:15px;margin-bottom:8px">Cumhurbaşkanlığı karar gerekçesi</label>'
      +'<textarea id="bfGerekce" rows="5" minlength="20" maxlength="1200" placeholder="Mahkeme kararını değerlendirip gerekçenizi yazın..." style="display:block;width:100%;min-width:0;box-sizing:border-box;font-size:16px;line-height:1.5;background:#17233b;color:#fff;border:1px solid #778bad;border-radius:9px;padding:12px"></textarea>'
      +'</div><p class="alt">Bu karar resmi oyuna kaydedilir ve ilgili bakana bildirilir.</p>'
      +'<button class="btn altin" id="bfKaydet" style="width:100%;min-height:48px">'+bas+'</button>');
   if(typeof adlFormBaslik==="function")adlFormBaslik(m,"Fezleke #"+id+" · "+bas);
   m.querySelector("#bfKaydet").onclick=async function(){
     var g=m.querySelector("#bfGerekce").value.trim();
     if(g.length<20){toast("Gerekçe en az 20 karakter olmalıdır.",true);return;}
     if(typeof onayla==="function"&&!await onayla("Fezleke kararı",bas+" kararı verilsin mi?","Kararı onayla",true))return;
     var btn=m.querySelector("#bfKaydet");btn.disabled=true;
     try{
       await API.rpc("bakan_fezleke_karar",{p_id:id,p_karar:karar,p_gerekce:g});
       modalKapat();
       toast(karar==="gorevden_al"?"Bakan görevden alındı.":"Bakanın görevde kalması kararlaştırıldı.");
       if(typeof adliyeEkrani==="function")await adliyeEkrani();
     }catch(err){toast(typeof hataCevir==="function"?hataCevir(err.message):String(err.message||err),true);btn.disabled=false;}
   };
 };
})();
