/* SEÇİM ONLINE · HALK HAREKETLERİ V2 · olay, polis, hukuk */
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

const eskiIskelet=iskelet;
iskelet=function(baslik,govde,opt){
 if(baslik==='Halk Hareketleri'&&!String(govde).includes('id="so-v2"')) govde='<div id="so-v2"></div>'+govde;
 return eskiIskelet(baslik,govde,opt);
};
const eskiEkran=sokakHareketleriEkrani;
sokakHareketleriEkrani=async function(){
 await eskiEkran();
 const mount=document.getElementById('so-v2');
 if(!mount)return;
 mount.innerHTML='<div class="kart">🛡️ Olaylar, ortak eylemler ve gözaltı/mahkeme kayıtları yükleniyor...</div>';
 try{
  const d=await API.rpc('sokak_ek_panel');
  const esc=t=>e(String(t??'')),num=t=>Number(t||0).toLocaleString('tr-TR');
  const saat=t=>t?new Date(t).toLocaleString('tr-TR'):'—';
  const aktif=x=>x.durum==='aktif'&&Date.parse(x.bitis)>Date.now();
  let h='<div class="kart"><h2>📰 Olaylardan Doğan Halk Hareketleri</h2><p>Zam, vergi, enflasyon, işsizlik, hazine sıkıntısı, kararname ve eksik kabine gibi gerçek oyun olaylarından eylem doğar. En az iki muhalefet partisi de herhangi bir konuda ortak çağrı yapabilir.</p><p><small>Yeni eylem için genel başkanlık, 7 günlük hesap, bütçe ve bekleme kuralları geçerlidir. Olay temelli eylemde ayrıca 35 memnuniyetsizlik eşiği aranmaz. Aynı il ve parti bekleme sınırları korunur.</small></p></div>';
  if(d.aktif&&d.koalisyon_baslatabilir){
   h+='<div class="kart"><details><summary><b>🤝 Partiler arası ortak eylem çağrısı aç</b></summary><p>Farklı iki muhalefet partisi onay verince ortak olay doğar. Konu serbesttir; 48 saatlik çağrı süresi ve 72 saatlik yeniden çağrı sınırı vardır.</p><form data-so-fn="sokak_koalisyon_cagri"><label>Çağrı başlığı</label><input name="p_baslik" minlength="12" maxlength="120" required placeholder="Örn. Bakan atamalarındaki gecikmeye tepki"><label>Ortak gerekçe ve talepler</label><textarea name="p_aciklama" minlength="35" maxlength="500" required></textarea><button class="btn altin">Diğer partileri davet et</button></form></details></div>';
  }
  if((d.koalisyonlar||[]).length){
   h+='<div class="kart"><h3>🤝 Açık ortak çağrılar</h3>';
   for(const c of d.koalisyonlar){
    h+='<div class="kart"><b>'+esc(c.baslik)+'</b><p>'+esc(c.aciklama)+'</p><p><small>'+num(c.sayi)+' parti · '+esc((c.partiler||[]).join(', '))+' · '+esc(saat(c.bitis))+' son</small></p>';
    if(d.koalisyon_baslatabilir&&!c.katildim)h+='<button class="btn" data-so-join="'+Number(c.id)+'">Partim adına katıl</button>';
    h+='</div>';
   }
   h+='</div>';
  }
  if(d.aktif&&d.baslatabilir){
   const ol=(d.olaylar||[]),ill=(d.iller||[]);
   h+='<div class="kart"><h3>📣 Gerçek oyun olayı üzerinden eylem başlat</h3>';
   if(ol.length){
    h+='<form data-so-fn="sokak_olay_baslat"><label>Eylemin dayandığı olay</label><select name="p_olay">'+ol.map(o=>'<option value="'+Number(o.id)+'">'+esc(o.baslik)+' · '+esc(o.tur)+'</option>').join('')+'</select>';
    h+='<label>Eylem ili</label><select name="p_il">'+ill.map(i=>'<option value="'+Number(i.id)+'">'+esc(i.ad)+'</option>').join('')+'</select><label>Talep türü</label><select name="p_tur"><option value="genel">Olayın geri çekilmesi / politika değişikliği</option><option value="hizmet">İl hizmetleri +5</option><option value="issizlik">İşsizlik −0,5</option><option value="vergi">Vergi −1</option></select><label>Somut gerekçe</label><textarea name="p_gerekce" minlength="20" maxlength="400" placeholder="Hükümetten hangi değişikliği istiyorsunuz?" required></textarea><button class="btn altin">Olay temelli eylem başlat · '+num(d.ayar?.baslatma_bedeli)+' TL</button></form>';
    h+='<details><summary>Dayanak olayları ve süreleri</summary>'+ol.slice(0,35).map(o=>'<p><b>'+esc(o.baslik)+'</b> · '+esc(o.tur)+'<br>'+esc(o.aciklama)+'<br><small>Son başlatma: '+esc(saat(o.bitis))+'</small></p>').join('')+'</details>';
   }else h+='<p>Şu anda kaydedilmiş geçerli bir olay yok. Yeni ekonomik/siyasi kararlar veya iki partili ortak çağrılar burada görünür.</p>';
   h+='</div>';
  }
  h+='<div class="kart"><h2>🛡️ Polis, gözaltı, avukat ve mahkeme</h2><p><b>Düşük bütçe:</b> devriye, gözaltı yok (50.000 TL). <b>Orta bütçe:</b> en çok 2 katılımcı (150.000 TL). <b>Yüksek bütçe:</b> en çok 4 katılımcı (400.000 TL). Gözaltılar 1 saattir; katılımcılar rastgele seçilir, 24 saatte tekrar alınamaz.</p><p>Yalnız eylem katılımı ve gözaltı süresince il değiştirme engellenir. Oy kullanma, mesaj, şirket ve bankacılık açık kalır. Gözaltı mahkemede itirazla derhal durur; haksız gözaltı tazminatı verilebilir.</p><p><b>Türkiye geneli katılım:</b> 81 ildeki oyuncular, partiler ve dernekler protestoya destek verebilir. Katılım için eylemin ilinde ikamet etme şartı yoktur.</p></div>';
  for(const x of d.eylemler||[]){
   const open=aktif(x);
   h+='<div class="kart"><h3>'+esc(x.il)+' · '+esc(x.parti)+' · Eylem #'+Number(x.id)+'</h3>';
   if(x.olay)h+='<p><b>Dayanak:</b> '+esc(x.olay.baslik)+' ('+esc(x.olay.tur)+')</p>';
   if(open&&d.mudahale_yetki){
    const base=Number(d.ayar?.baslatma_bedeli||50000);
    h+='<details><summary>🚓 Polis sevk et (Cumhurbaşkanı / İçişleri Bakanı)</summary><p>Kamu kasası yeterli değilse işlem gerçekleşmez. Aynı eyleme 6 saatte bir, ülke çapında 24 saatte en fazla 4 müdahale yapılabilir. Polis gücü arttıkça tepki ve memnuniyet kaybı artar.</p>';
    h+='<form data-so-fn="sokak_polis_gonder" data-so-id="'+Number(x.id)+'"><label>Müdahale seviyesi</label><select name="p_seviye"><option value="dusuk">Düşük · devriye / 0 gözaltı · '+num(base)+' TL</option><option value="orta">Orta · en çok 2 gözaltı · '+num(base*3)+' TL</option><option value="yuksek">Yüksek · en çok 4 gözaltı · '+num(base*8)+' TL</option></select><label>Somut kamu güvenliği gerekçesi</label><textarea name="p_gerekce" minlength="25" maxlength="500" required></textarea><button class="btn altin">Polis görevlendir</button></form></details>';
   }
   const pol=x.polis||[];
   if(pol.length){
    h+='<details open><summary>🚓 Polis müdahaleleri ('+pol.length+')</summary>';
    for(const p of pol){
     h+='<p><b>'+esc(p.seviye)+' müdahale</b> · '+esc(saat(p.zaman))+' · '+num(p.bedel)+' TL · '+num(p.alinan)+' gözaltı'+(p.geri_cekildi?' · Geri çekildi':'')+'<br>'+esc(p.gerekce)+'</p>';
     if(d.mudahale_yetki&&!p.geri_cekildi&&Date.now()-Date.parse(p.zaman)<3*3600000){
      h+='<form data-so-fn="sokak_polis_geri_cek" data-so-id="'+Number(p.id)+'"><textarea name="p_gerekce" minlength="20" maxlength="500" placeholder="Polis çekme gerekçesi" required></textarea><button class="btn">Polisi geri çek ve gözaltıları bitir</button></form>';
     }
    }
    h+='</details>';
   }
   const goz=x.gozaltilar||[];
   if(goz.length){
    h+='<details open><summary>⚖️ Gözaltılar ve duruşmalar ('+goz.length+')</summary>';
    for(const g of goz){
     const live=g.durum==='aktif'&&Date.parse(g.bitis)>Date.now();
     h+='<div class="kart"><b>'+esc(g.hedef)+'</b> · '+esc(live?'Gözaltında':g.durum)+' · '+esc(saat(g.bitis))+' son';
     if(g.avukat)h+='<p>Avukat: '+esc(g.avukat)+' ('+esc(g.avukat_durum)+')</p>';
     if(g.itiraz)h+='<p><b>İtiraz:</b> '+esc(g.itiraz)+'</p>';
     if(g.karar)h+='<p><b>Mahkeme:</b> '+esc(g.karar)+' · '+esc(g.karar_gerekce||'')+'<br>Tazminat: '+num(g.tazminat)+' TL, ödenen '+num(g.tazminat_odendi)+' TL</p>';
     if(g.benim&&live&&(d.avukatlar||[]).length){
      h+='<form data-so-fn="sokak_avukat_cagir" data-so-id="'+Number(g.id)+'"><label>Avukat çağır</label><select name="p_avukat">'+d.avukatlar.map(a=>'<option value="'+esc(a.id)+'">'+esc(a.ad)+'</option>').join('')+'</select><button class="btn">Avukat çağır</button></form>';
     }
     if(g.ben_avukat&&g.avukat_durum==='cagrildi'){
      h+='<button class="btn" data-so-law="'+Number(g.id)+'" data-so-accept="true">Avukatlık teklifini kabul et</button> <button class="btn" data-so-law="'+Number(g.id)+'" data-so-accept="false">Reddet</button>';
     }
     if(!g.itiraz&&(g.benim||(g.ben_avukat&&g.avukat_durum==='kabul'))&&Date.now()-Date.parse(g.baslangic)<24*3600000){
      h+='<form data-so-fn="sokak_gozalti_itiraz" data-so-id="'+Number(g.id)+'"><label>Mahkemeye itiraz (gözaltı hemen sona erer)</label><textarea name="p_metin" minlength="20" maxlength="600" required></textarea><button class="btn altin">Gözaltına itiraz et</button></form>';
     }
     if(g.mahkeme_yetki&&g.itiraz&&!g.karar){
      h+='<form data-so-fn="sokak_gozalti_mahkeme" data-so-id="'+Number(g.id)+'"><label>Bağımsız mahkeme kararı</label><select name="p_karar"><option value="haksiz">Haksız gözaltı: tazminat kararı</option><option value="uygun">Müdahale hukuka uygun</option></select><textarea name="p_gerekce" minlength="25" maxlength="700" placeholder="Gerekçeli karar" required></textarea><button class="btn">Kararı açıkla</button></form>';
     }
     if(g.benim&&Number(g.tazminat)>Number(g.tazminat_odendi))h+='<button class="btn" data-so-pay="'+Number(g.id)+'">Ödenmemiş tazminatı tahsil et</button>';
     h+='</div>';
    }
    h+='</details>';
   }
   h+='<details><summary>🎙️ Açıklamalar ve kamuoyu ('+(x.aciklamalar||[]).length+')</summary>';
   h+='<form data-so-fn="sokak_basina_aciklama" data-so-id="'+Number(x.id)+'"><label>Açıklama sıfatı</label><select name="p_taraf"><option value="basin">Basın / oyuncu yorumu</option><option value="muhalefet">Eylem katılımcısı veya örgütleyen parti</option><option value="hukuk">Ruhsatlı avukat</option>'+(d.mudahale_yetki?'<option value="hukumet">Hükümet</option>':'')+'</select><textarea name="p_metin" minlength="30" maxlength="600" placeholder="Halka açık açıklama metni" required></textarea><button class="btn">Basın açıklamasını yayımla</button></form>';
   h+=(x.aciklamalar||[]).map(y=>'<blockquote><b>'+esc(y.ad)+' · '+esc(y.taraf)+'</b><br>'+esc(y.metin)+'<br><small>'+esc(saat(y.zaman))+'</small></blockquote>').join('');
   h+='</details></div>';
  }
  mount.innerHTML=h;
  async function rpc(btn,fn,args){
   if(btn)btn.disabled=true;
   try{
    const val=await API.rpc(fn,args);
    const msg=fn==='sokak_polis_gonder'?'Polis görevlendirildi. Gözaltına alınan oyuncu: '+num(val?.gozalti_sayisi):'İşlem kaydedildi';
    toast(msg);
    await sokakHareketleriEkrani();
   }catch(err){
    toast(hataCevir(err.message||String(err)),true);
    if(btn)btn.disabled=false;
   }
  }
  mount.querySelectorAll('form[data-so-fn]').forEach(form=>form.addEventListener('submit',event=>{
   event.preventDefault();
   const args=Object.fromEntries(new FormData(form).entries());
   const fn=form.dataset.soFn,id=Number(form.dataset.soId);
   if(['sokak_polis_gonder','sokak_basina_aciklama'].includes(fn)) args.p_eylem=id;
   if(['sokak_polis_geri_cek'].includes(fn))args.p_polis=id;
   if(['sokak_avukat_cagir','sokak_gozalti_itiraz','sokak_gozalti_mahkeme'].includes(fn)) args.p_gozalti=id;
   if(fn==='sokak_olay_baslat'){args.p_il=Number(args.p_il);args.p_olay=Number(args.p_olay);}
   rpc(form.querySelector('button'),fn,args);
  }));
  mount.querySelectorAll('[data-so-join]').forEach(btn=>btn.addEventListener('click',()=>rpc(btn,'sokak_koalisyon_katil',{p_cagri:Number(btn.dataset.soJoin)})));
  mount.querySelectorAll('[data-so-law]').forEach(btn=>btn.addEventListener('click',()=>rpc(btn,'sokak_avukat_cevap',{p_gozalti:Number(btn.dataset.soLaw),p_kabul:btn.dataset.soAccept==='true'})));
  mount.querySelectorAll('[data-so-pay]').forEach(btn=>btn.addEventListener('click',()=>rpc(btn,'sokak_gozalti_tazminat_tahsil',{p_gozalti:Number(btn.dataset.soPay)})));
 }catch(err){
  mount.innerHTML='<div class="kart">Yeni halk hareketleri paneli yüklenemedi: '+e(hataCevir(err.message||String(err)))+'</div>';
 }
};
})();

/* Halk hareketleri kuruluş liderliği ve canlı eylem davetleri */
(function(){
'use strict';
const prev=sokakHareketleriEkrani;
sokakHareketleriEkrani=async function(){
 await prev();
 const area=document.getElementById('so-v2');
 if(!area)return;
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
