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
 (p.eylemler||[]).forEach(e=>{if(e.sohbet_hak)sohbetCek(Number(e.id));});
 const rt=typeof API!=='undefined'&&API.realtimeClient;
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
 x+='<p class="em-oneri">'+esc(oneri(r))+'</p></header>';
 if(tv&&tv.durum==='geri_sayim'){
  const g=Number(tv.hukumet||0), s=Number(tv.savun||0)+(ig.nobet||0); const top=Math.max(1,g+s); const yuz=Math.round(100*g/top);
  x+='<div class="em-sayac" data-em-bit="'+esc(tv.bitis)+'">Tahliye geri sayımı</div><div class="em-cekis" aria-label="Tahliye dengesi"><i style="width:'+yuz+'%;background:#8ea2d6"></i><i style="width:'+(100-yuz)+'%;background:#d46a4c"></i></div><small>Operasyon '+g+' · Savunma '+(s)+'</small>';
 }
 x+='<div class="em-sekme"><button type="button" class="acik" data-em-tab="eylem">Eylemci</button><button type="button" data-em-tab="hukumet">Hükümet</button><button type="button" data-em-tab="isgal">Kuşatma</button><button type="button" data-em-tab="butce">Bütçe</button></div>';
 const eng=(arguments[4]&&arguments[4].engel)||{};
 x+='<div data-em-panel="eylem">'+ayrilSatiri(ben)+'<div class="em-grid">'+HAMLE.map(k=>'<button type="button" class="em-kart" data-em-kart="'+k[0]+'"'+(eng[k[0]]?' disabled':'')+'><b>'+k[1]+' '+k[2]+'</b><small>'+k[3]+'</small><small>'+(eng[k[0]]?esc(eng[k[0]]):'Bedel '+k[4])+'</small></button>').join('')+'</div>';
 x+='<div class="em-grid"><button type="button" class="em-kart" data-em-islem="mesale">🌙 Gece meşalesi · 00.00</button><button type="button" class="em-kart" data-em-islem="aclik">Açlık grevine yazıl</button><button type="button" class="em-kart" data-em-islem="nobet">Bina nöbeti · 1 saat</button><button type="button" class="em-kart" data-em-islem="ziyaret">Dayanışma ziyareti</button><button type="button" class="em-kart" data-em-islem="savun">Binayı savun</button><button type="button" class="em-kart" data-em-islem="katil">Eyleme katıl</button></div>';
 x+='<form class="em-form" data-em-form="hamle"><input type="hidden" name="tur" value="grev"><label>Seçilen hamle</label><p class="em-secim">Genel Grev</p><label>Bina, yalnız işgalde</label><select name="bina"><option value="belediye">Belediye</option><option value="valilik">Valilik</option></select><label>Bakanlık, yalnız oturmada</label><input name="bakanlik" value="icisleri" maxlength="40"><label>Gerekçe</label><textarea name="gerekce" minlength="20" maxlength="300" required>Bu hamle ortak kararımızdır.</textarea><button class="hh-action hh-primary" type="submit">Hamleyi başlat</button></form>';
 x+='<form class="em-form" data-em-form="sizma"><label>İçeriden sızan not</label><textarea name="metin" maxlength="400" required placeholder="Hükümet planı"></textarea><button class="hh-action" type="submit">Notu eylem sohbetine bırak</button></form>';
 x+='</div>';
 const YAD={hizmet:'Acil Hizmet Seferberliği',vergi_tatil:'Bölgesel Vergi Tatili',istihdam:'İstihdam Taahhüt Paketi',brifing:'Resmi Basın Brifingi',sosyal_kart:'Acil Sosyal Destek Kartı',guzergah:'Güvenli Alan',komisyon:'Meclis Araştırma Komisyonu',gozlemci:'Bağımsız Gözlemci',kapi:'İktidar Kapı Kapı',gece:'Gece Toplanma Kısıtı',iletisim:'İletişim Yavaşlatma',festival:'Kültür-Festival'};
 const SAD={safak:'Şafak Operasyonu',elebasi:'Elebaşı Gözaltısı',mali:'Mali Kuşatma',kapatma:'Kapatma Davası Tehdidi',ohal:'OHAL',propaganda:'Kara Propaganda',bol:'Böl ve Yönet',kusatma:'Kuşatma Çemberi',ihale:'İhale ve Lisans Kılıcı',sanal:'Toplu Sanal Gözaltı'};
 const yumusak=(td&&td.acabilir)||Object.keys(YAD);
 const sert=(sd&&sd.bedeller)?Object.keys(sd.bedeller):Object.keys(SAD);
 x+='<div data-em-panel="hukumet" hidden><p>Yumuşak ve sert araçlar İçişleri bütçesinden düşer. Kasada para yoksa işlem açılmaz.</p>';
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
 let m=null,td=null,sd=null,denge=null; const listeler={};
 try{m=await API.rpc('sokak_eylem_merkezi');}catch(err){console.warn('Eylem merkezi',err);}
 try{denge=await API.rpc('sokak_denge_panel');}catch(err){console.warn('Denge',err);}
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
  art.insertAdjacentHTML('afterbegin',merkezHTML(row,tdHarita[id],sdHarita[id],(listeler[id]&&listeler[id].ben)||[],dengeHarita[id]));
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
