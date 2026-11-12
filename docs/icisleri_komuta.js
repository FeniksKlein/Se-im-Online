/* Seçim Online · İçişleri Komuta Merkezi · 07.11.2026 */
(function(){
 "use strict";
 if(window.SO_ICISLERI_KOMUTA_20261107)return;
 window.SO_ICISLERI_KOMUTA_20261107=true;
 function temiz(v){return String(v==null?"":v).replace(/[&<>"']/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];});}
 function say(v){return Number(v||0).toLocaleString("tr-TR",{maximumFractionDigits:2});}
 function tarih(v){return v?new Date(v).toLocaleString("tr-TR"):"—";}
 function uiStyle(){
  if(document.getElementById("icKomutaCss"))return;
  var el=document.createElement("style");el.id="icKomutaCss";
  el.textContent="#icKomuta{color:var(--txt,#eff3ff);font:inherit;line-height:1.5}#icKomuta .ic-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px}#icKomuta .ic-kart{background:var(--panel2,#15213d);padding:13px;border-radius:13px;border:1px solid var(--line2,#4e648c);margin:10px 0}#icKomuta .ic-kart h3{margin:0 0 8px;font-size:17px}#icKomuta label{display:block;font-weight:700;font-size:14px;margin:10px 0 5px}#icKomuta input,#icKomuta textarea,#icKomuta select{box-sizing:border-box;display:block;width:100%;min-height:46px;padding:10px 12px;background:#111a34;border:1px solid #8192b4;color:#f5f7ff;-webkit-text-fill-color:#f5f7ff;border-radius:10px;font:inherit;font-size:16px;opacity:1}#icKomuta textarea{min-height:90px;resize:vertical}#icKomuta .btn{margin-top:10px;min-height:45px;white-space:normal}#icKomuta details{padding:10px 0;border-top:1px solid var(--line2,#4e648c)}#icKomuta summary{cursor:pointer;font-weight:750;overflow-wrap:anywhere}#icKomuta p,#icKomuta small{overflow-wrap:anywhere}#icKomuta .ic-durum{font-weight:800}#icKomuta .ic-help{font-size:13px;color:var(--mut,#cbd5e1)}";
  document.head.appendChild(el);
 }
 function formAlan(ad, etiket, val, uzun){
  return '<label>'+temiz(etiket)+'</label><textarea name="'+ad+'" minlength="'+(uzun||25)+'" maxlength="800" required>'+temiz(val||"")+'</textarea>';
 }
 function kararForm(fn,id,ek,btn){
  return '<form data-ic="'+temiz(fn)+'"><input type="hidden" name="p_id" value="'+Number(id)+'">'+ek+formAlan("p_gerekce","Gerekçeli karar (en az 25 karakter)","",25)+'<button class="btn altin" type="submit">'+temiz(btn)+'</button></form>';
 }
 function render(d){
  uiStyle();
  var h=['<div id="icKomuta"><div class="ic-kart"><h2>🛡️ İçişleri Bakanlığı · Komuta Merkezi</h2><p>81 ilde kamu güvenliği, valilik koordinasyonu, belediye denetimleri, afet müdahalesi ve oyuncuların hakları burada yönetilir.</p><p class="ic-help">Bakanlık makamı: '+(d.yetki?'Yetkilisiniz':'Vatandaş erişimi')+'. İdari inceleme mahkeme kararı olmadan para cezası veya kıdem kaybı yaratmaz.</p>'+(d.yetki?'<b>Bakanlık kasası: '+say(d.kasa_tl)+' ₺</b>':'')+'</div>'];
  if(d.yetki){
   h.push('<div class="ic-kart" style="border:2px solid #e9b75c;background:linear-gradient(135deg,#422a25,#1c2945)"><h3>🔒 Oyuncu Tutuklama Yetkisi</h3><p>Kullanıcı adını ve zorunlu gerekçeyi yazarak oyun içi tutuklama kararı verebilirsiniz. Kararlar 24 saat sürer ve kayıt altına alınır.</p><button class="btn altin" style="width:100%;min-height:53px;font-weight:850" type="button" onclick="window.yonetimTutuklamaAc()">🔒 OYUNCU TUTUKLA / DOSYALARI GÖR</button></div>');
   h.push('<div class="ic-kart"><h3>🏛️ Valilikler, kolluk ve hizmet icraatları</h3><form data-ic="icraat"><label>Görev seç</label><select name="p_kod">'+(d.icraatlar||[]).map(function(x){return '<option value="'+temiz(x.kod)+'">'+temiz(x.ad)+' · '+say(x.maliyet)+' milyar ₺</option>';}).join('')+'</select><p class="ic-help" id="icIcraatDetay">Her icraatın harcaması, etkisi ve bekleme süresi mevcut Bakanlık Masası sistemiyle kaydedilir.</p><label>Hedef il (ülke çapındaki kararlarda kullanılmaz)</label><select name="p_il"><option value="">Tüm Türkiye</option>'+(d.iller||[]).map(function(x){return '<option value="'+Number(x.id)+'">'+temiz(x.ad)+'</option>';}).join('')+'</select><button type="submit" class="btn altin">Bakanlık kararı uygula</button></form><button class="btn ikinci" type="button" data-ic-eylem="1">🚓 Eylemler, polis müdahaleleri ve uzlaşma</button></div>');
   h.push('<div class="ic-kart"><h3>🎁 Vatandaş destek kararları</h3><p>Günlük en çok 8 onay. Yardım 3.000 ₺, eğitim desteği +1 kıdem. Her onay bakanlık kasasına gider yazılır.</p></div>');
  }
  h.push('<div class="ic-kart"><h3>🙋 Oyuncu destek başvurusu</h3><form data-ic="basvur"><label>Başvuru türü</label><select name="p_tur"><option value="yardim">3.000 ₺ sosyal destek</option><option value="egitim">+1 kıdem eğitim programı</option></select>'+formAlan("p_gerekce","Neden destek istiyorsun? (25–600 karakter)","",25)+'<button type="submit" class="btn altin">Bakanlığa başvur</button></form></div>');
  if(d.yetki){
   h.push('<div class="ic-kart"><h3>🔎 Oyuncu hakkında inceleme</h3><p class="ic-help">Suç isnadı değil, gerekçeli oyun içi incelemedir. İşlem günlük 5 dosya ve oyuncu başına 7 günde 1 dosya ile sınırlıdır. İnceleme 48 saat sonra karar verilmezse sonuçsuz kalır.</p><label>Oyuncu adıyla ara</label><input type="search" id="icAra" placeholder="En az 2 karakter"><button class="btn ikinci" data-ic-search="1" type="button">Oyuncu ara</button><form data-ic="sorusturma"><label>Oyuncu seç</label><select name="p_hedef" id="icHedef" required><option value="">Önce oyuncu arayın</option></select><label>İncelemenin konusu</label><input name="p_konu" minlength="20" maxlength="180" placeholder="İncelemenin somut konusu" required>'+formAlan("p_delil","Oyun içi delil, işlem ve olay bağlantısı (40–800 karakter)","",40)+'<button type="submit" class="btn altin">Gerekçeli inceleme aç</button></form></div>');
  }
  if(d.yetki){
    h.push('<div class="ic-kart"><h3>🏅 Oyuncuya valilik veya emniyet müdürlüğü teklif et</h3><p>Atamalar gerçek oyunculara teklif edilir. Oyuncu kabul ederse 7 gün yetki alır; kendi ilinde güvenlik emri ve uzlaşma çalışması yapar. Teklif 24 saat geçerlidir.</p><form data-ic="atama"><label>Hedef il</label><select name="p_il">'+(d.iller||[]).map(function(i){return '<option value="'+Number(i.id)+'">'+temiz(i.ad)+'</option>';}).join('')+'</select><label>Görev</label><select name="p_tur"><option value="vali">Vali</option><option value="emniyet">İl emniyet müdürü</option></select><label>Oyuncu (aşağıdaki oyuncu arama alanından bulun)</label><select name="p_hedef" id="icAtamaHedef" required><option value="">Önce oyuncu arayın</option></select>'+formAlan('p_gerekce','Atamanın gerekçesi','',20)+'<button type="submit" class="btn altin">Görev teklif et · 50.000 ₺</button></form></div>');
  }
  if((d.atamalar||[]).length){
    h.push('<div class="ic-kart"><h3>🏛️ Valilik ve emniyet görev kayıtları</h3>');
    (d.atamalar||[]).forEach(function(a){
      h.push('<details><summary>#'+Number(a.id)+' · '+temiz(a.il)+' · '+(a.tur==='vali'?'Vali':'Emniyet Müdürü')+' · '+temiz(a.oyuncu)+' · '+temiz(a.durum)+'</summary><p>'+temiz(a.gerekce)+'</p><p class="ic-help">Görev bitişi: '+tarih(a.bitis)+'</p>');
      if(a.durum==='teklif'&&a.benim)h.push('<form data-ic="atama_yanit"><input type="hidden" name="p_id" value="'+Number(a.id)+'"><label>Atama teklifine cevabın</label><select name="p_kabul"><option value="true">Kabul et</option><option value="false">Reddet</option></select><button type="submit" class="btn altin">Yanıtla</button></form>');
      if(a.durum==='aktif'&&(a.benim||d.yetki)){
        h.push('<form data-ic="il_emir"><input type="hidden" name="p_atama" value="'+Number(a.id)+'"><label>İl güvenliği emri</label><select name="p_tur"><option value="devriye">Devriye gönder · 150.000 ₺</option><option value="takviye">Takviye gönder · 500.000 ₺ (kamuoyu tepkisi olabilir)</option><option value="uzlasma">Uzlaşma görevlileri gönder · 100.000 ₺</option></select>'+formAlan('p_gerekce','Somut güvenlik ve kamu yararı gerekçesi','',25)+'<button class="btn altin" type="submit">İl emrini uygula</button></form>');
        h.push('<form data-ic="atama_kapat"><input type="hidden" name="p_id" value="'+Number(a.id)+'">'+formAlan('p_gerekce',a.benim?'Görevden ayrılma gerekçesi':'Görevden alma gerekçesi','',20)+'<button class="btn ikinci" type="submit">'+(a.benim?'İstifa et':'Görevi bitir')+'</button></form>');
      }
      if(a.durum==='teklif'&&d.yetki)h.push('<form data-ic="atama_kapat"><input type="hidden" name="p_id" value="'+Number(a.id)+'">'+formAlan('p_gerekce','Teklifi geri çekme gerekçesi','',20)+'<button class="btn ikinci" type="submit">Teklifi geri çek</button></form>');
      h.push('</details>');
    });
    h.push('</div>');
  }
  if(d.kriz&&(d.kriz.bakan||d.kriz.yurutme)){
    h.push('<div class="ic-kart"><h3>🚨 Cumhurbaşkanlığı onaylı özel il güvenlik tedbirleri</h3><p class="ic-help">İçişleri Bakanı teklif eder, Cumhurbaşkanı gerekçeli kararla onaylar veya reddeder. Onaylanan tedbir 12 saat sürer, 2 milyon ₺ bakanlık ödeneği gerektirir ve ilin güvenlik/itibar göstergelerini etkiler. Oyuncuların oy, hesap, şirket ve iletişim haklarını kısıtlamaz.</p>');
    if(d.kriz.bakan){
      h.push('<form data-ic="kriz_teklif"><label>Özel tedbir önerilen il</label><select name="p_il">'+(d.kriz.iller||[]).map(function(i){return '<option value="'+Number(i.id)+'">'+temiz(i.ad)+'</option>';}).join('')+'</select>'+formAlan('p_gerekce','Kriz gerekçesi ve somut risk','',40)+'<button class="btn altin" type="submit">Cumhurbaşkanlığına teklif sun</button></form>');
    }
    (d.kriz.kararlar||[]).forEach(function(x){
      h.push('<details><summary>#'+Number(x.id)+' · '+temiz(x.il)+' · '+temiz(x.durum)+'</summary><p>'+temiz(x.gerekce)+'</p><p class="ic-help">Açılış: '+tarih(x.acilis)+' · Bitiş: '+tarih(x.bitis)+'</p>');
      if(d.kriz.yurutme&&x.durum==='onay_bekliyor'){
        h.push('<form data-ic="kriz_karar"><input type="hidden" name="p_id" value="'+Number(x.id)+'"><label>Cumhurbaşkanlığı kararı</label><select name="p_kabul"><option value="true">Onayla · 12 saat</option><option value="false">Reddet</option></select>'+formAlan('p_gerekce','Cumhurbaşkanlığı karar gerekçesi','',25)+'<button class="btn altin" type="submit">Kararı ilan et</button></form>');
      }else if(x.karar_gerekce) h.push('<p><b>Karar gerekçesi:</b> '+temiz(x.karar_gerekce)+'</p>');
      h.push('</details>');
    });
    h.push('</div>');
  }
  if((d.basvurular||[]).length){
   h.push('<div class="ic-kart"><h3>📨 Destek başvuruları</h3>');
   (d.basvurular||[]).forEach(function(b){
    h.push('<details><summary>#'+Number(b.id)+' · '+temiz(b.oyuncu)+' · '+(b.tur==='yardim'?'Sosyal yardım':'Eğitim')+' · '+temiz(b.durum)+'</summary><p>'+temiz(b.gerekce)+'</p><small>'+tarih(b.acilis)+'</small>');
    if(b.durum==='bekliyor'&&d.yetki){
     h.push('<form data-ic="basvuru_karar"><input name="p_id" type="hidden" value="'+Number(b.id)+'"><label>Karar</label><select name="p_kabul"><option value="true">Onayla</option><option value="false">Reddet</option></select>'+formAlan("p_gerekce","Gerekçeli karar","",20)+'<button class="btn altin" type="submit">Başvuruyu sonuçlandır</button></form>');
    }else if(b.karar_gerekce) h.push('<p>Karar gerekçesi: '+temiz(b.karar_gerekce)+'</p>');
    h.push('</details>');
   });
   h.push('</div>');
  }
  if((d.dosyalar||[]).length){
   h.push('<div class="ic-kart"><h3>⚖️ İncelemeler, savunmalar ve itirazlar</h3>');
   (d.dosyalar||[]).forEach(function(x){
    var durum=x.durum, benim=!!x.benim;
    h.push('<details><summary>#'+Number(x.id)+' · '+temiz(x.oyuncu)+' · '+temiz(x.konu)+' · <span class="ic-durum">'+temiz(durum)+'</span></summary><p><b>Dayanak:</b> '+temiz(x.delil)+'</p><p class="ic-help">Açılış: '+tarih(x.acilis)+' · Karar: '+tarih(x.karar_at)+'</p>');
    if(x.savunma)h.push('<p><b>Oyuncu savunması:</b> '+temiz(x.savunma)+'</p>');
    if(x.karar_gerekce)h.push('<p><b>Mahkeme:</b> '+temiz(x.karar_gerekce)+' · '+say(x.ceza)+' ₺ / '+say(x.kidem_kaybi)+' kıdem</p>');
    if(durum==='inceleme'&&benim&&!x.savunma)h.push('<form data-ic="savunma"><input type="hidden" name="p_id" value="'+Number(x.id)+'">'+formAlan("p_metin","Savunmanız (25–1000 karakter)","",25)+'<button type="submit" class="btn altin">Savunmamı sun</button></form>');
    if(durum==='inceleme'&&d.yargi)h.push(kararForm('hakim',x.id,'<label>Bağımsız hâkim kararı</label><select name="p_karar"><option value="aklandi">İnceleme kapansın / yaptırım yok</option><option value="ceza">Gerekçeli, azami 1.000 ₺ ve 1 kıdem cezası</option></select>','Hâkim kararını ver'));
    if(durum==='ceza'&&benim&&!x.itiraz_metni)h.push('<form data-ic="itiraz"><input type="hidden" name="p_id" value="'+Number(x.id)+'">'+formAlan("p_metin","Mahkemeye itiraz gerekçeniz","",25)+'<button type="submit" class="btn altin">24 saat içinde itiraz et</button></form>');
    if(durum==='itiraz'&&d.yargi)h.push(kararForm('itiraz_karar',x.id,'<label>İkinci hâkim kararı</label><select name="p_kaldir"><option value="true">Yaptırımı kaldır ve iade et</option><option value="false">İtirazı reddet</option></select>','İtiraz kararını açıkla'));
    if(x.itiraz_karar)h.push('<p><b>İtiraz sonucu:</b> '+temiz(x.itiraz_karar)+'</p>');
    h.push('</details>');
   });
   h.push('</div>');
  }
  h.push('<div class="ic-kart"><h3>📜 Devlet yetkilerinin sınırları</h3><p>Bakan denetim açabilir, kolluk için bütçe ayırabilir, uzlaşma teklif edebilir ve oyunculara yardım sağlayabilir. Oy kullanma, mesajlaşma, parti değiştirme, hesap erişimi, banka ve şirket faaliyetleri bu yeni denetimle otomatik kısıtlanmaz.</p></div></div>');
  return h.join('');
 }
 window.icisleriKomutaEkrani=async function(){
  if(typeof API==="undefined"||!API||typeof API.rpc!=="function"){if(typeof window.toast==="function")window.toast("Sunucu bağlantısı hazır değil. Tekrar giriş yapın.",true);return;}
  if(typeof window.yukleniyor==="function")yukleniyor("İçişleri Bakanlığı");
  try{var d=await API.rpc("icisleri_komuta_panel");try{d.kriz=await API.rpc("icisleri_kriz_panel");}catch(_){d.kriz=null;}iskelet("İçişleri · Komuta Merkezi",render(d),{geri:true});}
  catch(err){iskelet("İçişleri · Komuta Merkezi",'<div class="kart"><p>'+temiz(err.message||err)+'</p><button class="btn" onclick="icisleriKomutaEkrani()">Yeniden dene</button></div>',{geri:true});}
 };
 window.icisleriKomutaAc=function(){if(typeof window.ekranAc==="function")return ekranAc(window.icisleriKomutaEkrani);return window.icisleriKomutaEkrani();};
 document.addEventListener("submit",async function(ev){
  var f=ev.target.closest&&ev.target.closest('#icKomuta form[data-ic]');if(!f)return;
  ev.preventDefault();var cmd=f.getAttribute('data-ic'),b=f.querySelector('button[type="submit"]');if(b)b.disabled=true;
  var d=new FormData(f),fn,args;
  if(cmd==='icraat'){fn='icraat_yap';args={p_kod:d.get('p_kod'),p_il:d.get('p_il')?Number(d.get('p_il')):null};}
  else if(cmd==='basvur'){fn='icisleri_basvur';args={p_tur:d.get('p_tur'),p_gerekce:d.get('p_gerekce')};}
  else if(cmd==='basvuru_karar'){fn='icisleri_basvuru_karar';args={p_id:Number(d.get('p_id')),p_kabul:d.get('p_kabul')==='true',p_gerekce:d.get('p_gerekce')};}
  else if(cmd==='sorusturma'){fn='icisleri_sorusturma_ac';args={p_hedef:d.get('p_hedef'),p_konu:d.get('p_konu'),p_delil:d.get('p_delil')};}
  else if(cmd==='atama'){fn='icisleri_atama_teklif';args={p_il:Number(d.get('p_il')),p_tur:d.get('p_tur'),p_hedef:d.get('p_hedef'),p_gerekce:d.get('p_gerekce')};}
  else if(cmd==='atama_yanit'){fn='icisleri_atama_yanit';args={p_id:Number(d.get('p_id')),p_kabul:d.get('p_kabul')==='true'};}
  else if(cmd==='atama_kapat'){fn='icisleri_atama_kapat';args={p_id:Number(d.get('p_id')),p_gerekce:d.get('p_gerekce')};}
  else if(cmd==='il_emir'){fn='icisleri_il_emir_ver';args={p_atama:Number(d.get('p_atama')),p_tur:d.get('p_tur'),p_gerekce:d.get('p_gerekce')};}

  else if(cmd==='kriz_teklif'){fn='icisleri_kriz_teklif';args={p_il:Number(d.get('p_il')),p_gerekce:d.get('p_gerekce')};}
  else if(cmd==='kriz_karar'){fn='icisleri_kriz_karar';args={p_id:Number(d.get('p_id')),p_kabul:d.get('p_kabul')==='true',p_gerekce:d.get('p_gerekce')};}
  else if(cmd==='savunma'){fn='icisleri_savunma';args={p_id:Number(d.get('p_id')),p_metin:d.get('p_metin')};}
  else if(cmd==='hakim'){fn='icisleri_hakim_karar';args={p_id:Number(d.get('p_id')),p_karar:d.get('p_karar'),p_gerekce:d.get('p_gerekce')};}
  else if(cmd==='itiraz'){fn='icisleri_itiraz';args={p_id:Number(d.get('p_id')),p_metin:d.get('p_metin')};}
  else if(cmd==='itiraz_karar'){fn='icisleri_itiraz_karar';args={p_id:Number(d.get('p_id')),p_kaldir:d.get('p_kaldir')==='true',p_gerekce:d.get('p_gerekce')};}
  if(!fn){if(b)b.disabled=false;return;}
  try{await API.rpc(fn,args);if(typeof toast==="function")toast("İçişleri işlemi kaydedildi.");await window.icisleriKomutaEkrani();}
  catch(err){if(typeof toast==="function")toast(typeof hataCevir==="function"?hataCevir(err.message):err.message,true);if(b)b.disabled=false;}
 },true);
 document.addEventListener('click',async function(ev){
  var src=ev.target.closest&&ev.target.closest('[data-ic-search]');if(src){
   src.disabled=true;try{var sonuc=await API.rpc('icisleri_oyuncu_ara',{p_ara:document.getElementById('icAra').value});var s=document.getElementById('icHedef');var html='<option value="">Oyuncu seç</option>'+sonuc.map(function(x){return '<option value="'+temiz(x.id)+'">'+temiz(x.kad)+' · '+temiz(x.il)+'</option>';}).join('');if(s)s.innerHTML=html;var at=document.getElementById('icAtamaHedef');if(at)at.innerHTML=html;if(!sonuc.length&&typeof toast==="function")toast("Oyuncu bulunamadı");}catch(ex){if(typeof toast==="function")toast(ex.message,true);}finally{src.disabled=false;}
  }
  var ey=ev.target.closest&&ev.target.closest('[data-ic-eylem]');if(ey&&typeof window.sokakHareketleriEkrani==='function')return window.ekranAc?ekranAc(window.sokakHareketleriEkrani):sokakHareketleriEkrani();
 },true);
 function bagla(){
  if(typeof window.iskelet!=="function"||window.iskelet.__icKomuta)return;
  var onceki=window.iskelet;
  var yeni=function(baslik,govde,opt){
   if(typeof govde==='string'&&/^(?:Devlet|Yönetim|İçişleri Bakanlığı|Bakanlık Masası)$/.test(String(baslik))&&!govde.includes('icisleriKomutaAc')){
    govde='<div class="kart"><button class="btn ikinci" style="width:100%;min-height:48px;font-weight:750" onclick="window.icisleriKomutaAc()">🛡️ İçişleri Bakanlığı · Komuta Merkezi / Oyuncu Başvuruları</button></div>'+govde;
   }
   return onceki.call(this,baslik,govde,opt);
  };
  yeni.__icKomuta=true;window.iskelet=yeni;
 }

 // Cumhurbaşkanı ve İçişleri Bakanı için ortak gerekçeli tutuklama paneli.
 function ytEsc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
 window.yonetimTutuklamaAc=async function(){
  if(typeof window.API==='undefined'||!API||typeof API.rpc!=='function'){if(window.toast)toast('Oyun bağlantısı henüz kurulmadı.',true);return;}
  if(window.yukleniyor)yukleniyor('Tutuklama yetkisi');
  try {
   var kayitlar=await API.rpc('yonetim_tutuklama_liste');
   var govde='<div id="yonetimTutuklama"><div class="kart" style="border:2px solid #e8ad51;background:linear-gradient(130deg,#3c2b2c,#172441);padding:17px"><h2 style="margin:0 0 8px">🔒 Oyuncu Tutuklama Yetkisi</h2><p>Bu oyun içi makam yetkisi yalnız Cumhurbaşkanı ve İçişleri Bakanına açıktır. Tutuklama 24 saat sürer; hedef oyuncuya gerekçe bildirilir.</p>'
    +'<form data-yt="tutukla"><label for="ytOyuncu" style="display:block;margin-top:15px">Tutuklanacak oyuncunun kullanıcı adı</label><input id="ytOyuncu" name="kullanici" type="text" minlength="2" maxlength="60" autocomplete="off" placeholder="Kullanıcı adını aynen yazın" required style="display:block;box-sizing:border-box;width:100%;padding:13px;margin-top:6px;border-radius:10px;background:#111a34;color:white;border:1px solid #b6c0d3;font-size:16px">'
    +'<label for="ytGerekce" style="display:block;margin-top:12px">Tutuklama gerekçesi (zorunlu)</label><textarea id="ytGerekce" name="gerekce" minlength="10" maxlength="800" required placeholder="Somut oyun içi gerekçeyi yazın (en az 10 karakter)" style="box-sizing:border-box;width:100%;min-height:105px;padding:12px;margin-top:6px;border-radius:10px;background:#111a34;color:white;border:1px solid #b6c0d3;font-size:16px"></textarea>'
    +'<button type="submit" class="btn altin" style="width:100%;min-height:51px;font-weight:850;margin-top:12px">🔒 TUTUKLAMA KARARI VER</button></form></div>'
    +'<div class="kart"><h3>📋 Tutuklama kayıtları</h3>';
   if(!Array.isArray(kayitlar)||!kayitlar.length)govde+='<p>Henüz kayıt bulunmuyor.</p>';
   (Array.isArray(kayitlar)?kayitlar:[]).forEach(function(k){
    var aktif=k.durum==='aktif';
    govde+='<details style="padding:11px 0;border-bottom:1px solid #47536e"><summary style="cursor:pointer;font-weight:800">'+ytEsc(k.oyuncu)+' · '+(aktif?'🔒 Tutuklu':'✅ Sona erdi')+'</summary><p><b>Gerekçe:</b> '+ytEsc(k.gerekce)+'</p><small>Başlangıç: '+(k.baslangic?new Date(k.baslangic).toLocaleString('tr-TR'):'—')+' · Bitiş: '+(k.bitis?new Date(k.bitis).toLocaleString('tr-TR'):'—')+'</small>';
    if(aktif)govde+='<form data-yt="serbest"><input type="hidden" name="id" value="'+Number(k.id)+'"><label style="display:block;margin-top:10px">Serbest bırakma gerekçesi</label><textarea name="gerekce" minlength="10" maxlength="800" required style="box-sizing:border-box;width:100%;min-height:75px;padding:10px;margin-top:6px;border-radius:9px;background:#111a34;color:#fff;font-size:16px"></textarea><button class="btn ikinci" type="submit" style="margin-top:8px">Serbest bırak</button></form>';
    govde+='</details>';
   });
   govde+='</div></div>';
   iskelet('🔒 Tutuklama Yetkisi',govde,{geri:true});
  }catch(e){if(window.toast)toast(e.message||String(e),true);else alert(e.message||String(e));}
 };
 document.addEventListener('submit',async function(ev){
  var frm=ev.target.closest&&ev.target.closest('#yonetimTutuklama form[data-yt]');if(!frm)return;
  ev.preventDefault();
  var d=new FormData(frm),type=frm.getAttribute('data-yt'),name=String(d.get('kullanici')||'').trim();
  var args=type==='tutukla'?{p_kullanici_adi:name,p_gerekce:String(d.get('gerekce')||'').trim()}:{p_id:Number(d.get('id')),p_gerekce:String(d.get('gerekce')||'').trim()};
  if(type==='tutukla'&&!window.confirm(name+' isimli oyuncu hakkında 24 saatlik tutuklama kararı vermek istiyor musunuz?'))return;
  var btn=frm.querySelector('button[type="submit"]');if(btn)btn.disabled=true;
  try{
   await API.rpc(type==='tutukla'?'yonetim_tutuklama_yap':'yonetim_tutuklama_serbest',args);
   if(window.toast)toast(type==='tutukla'?'Tutuklama kararı kaydedildi.':'Oyuncu serbest bırakıldı.');
   await window.yonetimTutuklamaAc();
  }catch(e){if(window.toast)toast(e.message||String(e),true);else alert(e.message||String(e));if(btn)btn.disabled=false;}
 },true);

 // Devlet ve Cumhurbaşkanlığı yetki ekranlarında yalnız yetkili hesaba kısayol eklenir.
 var ytOncekiIskelet=window.iskelet;
 if(typeof ytOncekiIskelet==='function'&&!ytOncekiIskelet.__yonetimTutuklama){
  window.iskelet=function(baslik,govde,opt){
   var sonuc=ytOncekiIskelet.call(this,baslik,govde,opt);
   if(typeof baslik==='string'&&/^(?:Devlet|Yönetim|Cumhurbaşkanlığı|Cumhurbaşkanı|Cumhurbaşkanlığı Yetkileri|Bakanlık Masası)/i.test(baslik)&&typeof API!=='undefined'&&API&&typeof API.rpc==='function'){
    var alan=document.getElementById('icerik'),ilk=alan&&alan.firstElementChild;
    Promise.resolve().then(function(){return API.rpc('yonetim_tutuklama_liste');}).then(function(){
     if(!alan||!alan.isConnected||alan.firstElementChild!==ilk||alan.querySelector('#ytDevletKisayol'))return;
     var kart=document.createElement('div');kart.id='ytDevletKisayol';kart.className='kart';
     kart.style.cssText='border:2px solid #e8ad51;background:linear-gradient(110deg,#3c2929,#192744);margin:10px 0';
     kart.innerHTML='<h3>🔒 Oyuncu Tutuklama Yetkisi</h3><p>Hedef oyuncunun adını ve gerekçesini girerek tutuklama kararı verin.</p><button type="button" class="btn altin" onclick="window.yonetimTutuklamaAc()" style="width:100%;min-height:50px;font-weight:850">🔒 OYUNCU TUTUKLA</button>';
     alan.insertBefore(kart,alan.firstChild);
    }).catch(function(){});
   }
   return sonuc;
  };
  window.iskelet.__yonetimTutuklama=true;
 }
 bagla();
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bagla,{once:true});
})();
