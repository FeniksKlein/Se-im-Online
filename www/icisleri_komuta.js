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
   h.push('<div class="ic-kart"><h3>🏛️ Valilikler, kolluk ve hizmet icraatları</h3><form data-ic="icraat"><label>Görev seç</label><select name="p_kod">'+(d.icraatlar||[]).map(function(x){return '<option value="'+temiz(x.kod)+'">'+temiz(x.ad)+' · '+say(x.maliyet)+' milyar ₺</option>';}).join('')+'</select><p class="ic-help" id="icIcraatDetay">Her icraatın harcaması, etkisi ve bekleme süresi mevcut Bakanlık Masası sistemiyle kaydedilir.</p><label>Hedef il (ülke çapındaki kararlarda kullanılmaz)</label><select name="p_il"><option value="">Tüm Türkiye</option>'+(d.iller||[]).map(function(x){return '<option value="'+Number(x.id)+'">'+temiz(x.ad)+'</option>';}).join('')+'</select><button type="submit" class="btn altin">Bakanlık kararı uygula</button></form><button class="btn ikinci" type="button" data-ic-eylem="1">🚓 Eylemler, polis müdahaleleri ve uzlaşma</button></div>');
   h.push('<div class="ic-kart"><h3>🎁 Vatandaş destek kararları</h3><p>Günlük en çok 8 onay. Yardım 3.000 ₺, eğitim desteği +1 kıdem. Her onay bakanlık kasasına gider yazılır.</p></div>');
  }
  h.push('<div class="ic-kart"><h3>🙋 Oyuncu destek başvurusu</h3><form data-ic="basvur"><label>Başvuru türü</label><select name="p_tur"><option value="yardim">3.000 ₺ sosyal destek</option><option value="egitim">+1 kıdem eğitim programı</option></select>'+formAlan("p_gerekce","Neden destek istiyorsun? (25–600 karakter)","",25)+'<button type="submit" class="btn altin">Bakanlığa başvur</button></form></div>');
  if(d.yetki){
   h.push('<div class="ic-kart"><h3>🔎 Oyuncu hakkında inceleme</h3><p class="ic-help">Suç isnadı değil, gerekçeli oyun içi incelemedir. İşlem günlük 5 dosya ve oyuncu başına 7 günde 1 dosya ile sınırlıdır. İnceleme 48 saat sonra karar verilmezse sonuçsuz kalır.</p><label>Oyuncu adıyla ara</label><input type="search" id="icAra" placeholder="En az 2 karakter"><button class="btn ikinci" data-ic-search="1" type="button">Oyuncu ara</button><form data-ic="sorusturma"><label>Oyuncu seç</label><select name="p_hedef" id="icHedef" required><option value="">Önce oyuncu arayın</option></select><label>İncelemenin konusu</label><input name="p_konu" minlength="20" maxlength="180" placeholder="İncelemenin somut konusu" required>'+formAlan("p_delil","Oyun içi delil, işlem ve olay bağlantısı (40–800 karakter)","",40)+'<button type="submit" class="btn altin">Gerekçeli inceleme aç</button></form></div>');
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
  if(!window.API||typeof API.rpc!=="function")return;
  if(typeof window.yukleniyor==="function")yukleniyor("İçişleri Bakanlığı");
  try{var d=await API.rpc("icisleri_komuta_panel");iskelet("İçişleri · Komuta Merkezi",render(d),{geri:true});}
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
   src.disabled=true;try{var sonuc=await API.rpc('icisleri_oyuncu_ara',{p_ara:document.getElementById('icAra').value});var s=document.getElementById('icHedef');s.innerHTML='<option value="">Oyuncu seç</option>'+sonuc.map(function(x){return '<option value="'+temiz(x.id)+'">'+temiz(x.kad)+' · '+temiz(x.il)+'</option>';}).join('');if(!sonuc.length&&typeof toast==="function")toast("Oyuncu bulunamadı");}catch(ex){if(typeof toast==="function")toast(ex.message,true);}finally{src.disabled=false;}
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
 bagla();
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bagla,{once:true});
})();
