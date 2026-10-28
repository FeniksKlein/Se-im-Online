/* Seçim Online — Mahkemede avukat zorunluluğu + Parti Sözcüsü resmî açıklama makamı · 23.10.2026
   - Dava açma, seçim itirazı: "hukuki iş" talebi → avukat teklifleri → ücret emanette → avukat mahkemeye sunar.
   - Savunma/beyan ve istinaf yalnız avukattan; taraf düğmeleri kaldırılır (yargıcın çağırdığı ilgili taraf tanık beyanı verebilir).
   - Parti sözcüsü Adliye'den çıkar; parti sayfasında resmî açıklama yapar.
   avukatlik.js ve baro.js'ten SONRA yüklenir. */
(function(){
'use strict';
if(typeof adliyeHtml!=='function'||typeof adliyeDosya!=='function'||window.AVUKAT_ZORUNLU_YUKLENDI)return;
window.AVUKAT_ZORUNLU_YUKLENDI=true;
const h=x=>typeof e==='function'?e(String(x??'')):String(x??'').replace(/[&<>"']/g,'');
const money=n=>Number(n||0).toLocaleString('tr-TR',{maximumFractionDigits:0})+' ₺';
const stamp=d=>d?(typeof tarihSaat==='function'?tarihSaat(d):new Date(d).toLocaleString('tr-TR')):'—';
const RPC=(k,v)=>API.rpc(k,v||{});
const error=err=>toast(typeof hataCevir==='function'?hataCevir(err.message):err.message,true);
const TA='style="width:100%;padding:12px;border-radius:10px;background:var(--bg);border:1px solid var(--line2);outline:none;font-size:16px;resize:vertical"';
const KURUM={sirket:'Şirket / banka / sigorta',dernek:'Dernek',belediye:'Belediye',makam:'Kamu makamı',bakanlik:'Bakanlık',gazete:'Gazete'};
const TUR_AD={dava:'Dava açılışı',secim_itiraz:'Seçim itirazı',pkd_savunma:'Parti kapatma savunması'};
const DURUM={avukat_bekliyor:['Avukat aranıyor','sari'],vekil_atandi:['Avukat çalışıyor','altin'],sunuldu:['Mahkemeye sunuldu','yesil'],iptal:['Geri çekildi','']};
const davaTur=k=>(typeof ADL_TURLER!=='undefined'&&ADL_TURLER[k])||k||'';
function yenile(){if(typeof yenidenCiz==='function')yenidenCiz();else adliyeEkrani();}

/* ---------- Parti sözcüsünün yeni görevi ---------- */
const SOZCU_METNI='<p class="alt"><b>Parti sözcüsü ne yapar?</b> Partinin resmî sesidir: parti adına açıklama yapar. Açıklamalar parti sayfasında yayımlanır, Gündem akışına düşer ve üyelere bildirilir. Parti, mahkemede genel başkan tarafından doğrudan veya isteğe bağlı avukat aracılığıyla temsil edilir. Sözcüyü yalnız genel başkan atar ve görevden alır.</p>';
window.adlSozcuGorevleri=()=>SOZCU_METNI;
// Sözcü listesi artık Adliye'de gösterilmez; yerine baro ve hukuki iş kartlarının yerleşeceği işaret bırakılır.
window.adlSozcuListesiHtml=()=>'<div id="adlSozcuYeri"></div>';

/* ---------- Adliye metinleri + Hukuki işlerim kartı ---------- */
const METIN=[];
function isKart(j,gorunum){
 const [dAd,dRenk]=DURUM[j.durum]||[j.durum,''];
 let baslik=TUR_AD[j.tur]||j.tur;
 if(j.tur==='dava')baslik+=' · '+davaTur(j.dava_tur)+' → '+(j.hedef_ad||'—');
 else baslik+=' · '+(j.hedef_ad||'');
 let z='<div class="liste-satir" style="align-items:flex-start"><div class="orta"><b>Hukuki iş #'+j.id+' · '+h(baslik)+'</b> <span class="rozet '+dRenk+'">'+h(dAd)+'</span>'
  +'<div class="kucuk">Müvekkil: '+h(j.muvekkil)+(j.parti?' ('+h(j.parti)+' adına)':'')+(j.tazminat?' · Tazminat talebi '+money(j.tazminat):'')+' · '+h(stamp(j.olusturma))+'</div>'
  +(j.avukat?'<div class="kucuk">Vekil: Av. '+h(j.avukat)+' · Ücret '+money(j.ucret)+(Number(j.prim)?' · Prim %'+h(j.prim):'')+(Number(j.emanet)?' · Emanette '+money(j.emanet):'')+'</div>':'')
  +'<details><summary class="kucuk" style="cursor:pointer">Metni göster</summary><p class="kucuk" style="white-space:pre-wrap">'+h(j.metin)+'</p>'+(j.delil?'<p class="kucuk" style="white-space:pre-wrap">Delil: '+h(j.delil)+'</p>':'')+'</details>';
 if(gorunum==='muvekkil'&&j.durum==='avukat_bekliyor'){
  const tk=(j.teklifler||[]).filter(t=>t.durum==='bekliyor');
  z+=tk.length?tk.map(t=>'<div class="kart" style="background:var(--bg);margin:6px 0"><b>Av. '+h(t.avukat)+' · '+money(t.tutar)+(Number(t.prim)?' + %'+h(t.prim)+' başarı primi':'')+'</b>'+(t.aciklama?'<p class="kucuk">'+h(t.aciklama)+'</p>':'')
    +'<div style="display:flex;gap:6px"><button class="btn altin yarim" onclick="hukukIsTeklifKarar('+t.id+',true)">Kabul et</button><button class="btn ikinci yarim" onclick="hukukIsTeklifKarar('+t.id+',false)">Reddet</button></div></div>').join('')
   :'<p class="kucuk">Henüz teklif yok. Baroya kayıtlı avukatlara bildirildi.</p>';
  z+='<div style="display:flex;gap:6px"><button class="btn ikinci yarim" onclick="hukukIsDavet('+j.id+')">Avukat davet et</button><button class="btn tehlike yarim" onclick="hukukIsIptal('+j.id+',false)">Geri çek</button></div>';
 }else if(gorunum==='muvekkil'&&j.durum==='vekil_atandi'){
  z+='<p class="kucuk">Avukatın dilekçeyi hazırlıyor. Ücretin sunuma kadar emanette; geri çekersen iade edilir.</p><button class="btn tehlike" onclick="hukukIsIptal('+j.id+',false)">Talebi geri çek</button>';
 }else if(gorunum==='avukat'&&j.durum==='vekil_atandi'){
  z+='<div style="display:flex;gap:6px"><button class="btn altin yarim" onclick="hukukIsSunModal('+j.id+')">Dilekçeyi mahkemeye sun</button><button class="btn tehlike yarim" onclick="hukukIsIptal('+j.id+',true)">Vekâletten çekil</button></div>';
 }else if(gorunum==='acik'){
  const benim=(j.teklifler||[]).find(t=>t.benim&&t.durum==='bekliyor');
  z+=benim?'<p class="kucuk">Teklifin: '+money(benim.tutar)+(Number(benim.prim)?' + %'+h(benim.prim):'')+' · müvekkilin kararı bekleniyor.</p>'
   :(j.muvekkilim?'<p class="kucuk">Bu senin işin.</p>':'<button class="btn altin" onclick="hukukIsTeklifModal('+j.id+')">Teklif ver'+(Number(j.teklif_sayi)?' ('+j.teklif_sayi+' teklif var)':'')+'</button>');
 }
 if(j.dava_id)z+='<button class="btn ikinci" onclick="ekranAc(()=>adliyeDosya('+j.dava_id+'))">Dava #'+j.dava_id+' dosyasına git</button>';
 return z+'</div></div>';
}
window.hukukIsKart=isKart;
function islerimHtml(v){
 const benim=v.benim||[],ust=v.ustlendigim||[];
 if(!benim.length&&!ust.length)return '';
 return '<div class="kart" id="hukukIslerimKart"><h3>⚖️ Hukuki işlerim</h3><p class="alt">Doğrudan dava açma hakkın saklıdır. Avukatla çalışmak isteğe bağlıdır; kabul ettiğin avukatlık ücreti dilekçe sunuluncaya kadar emanette bekler.</p>'
  +(benim.length?'<h3 style="font-size:16px;margin-top:8px">Müvekkili olduğum işler</h3>'+benim.map(j=>isKart(j,'muvekkil')).join(''):'')
  +(ust.length?'<h3 style="font-size:16px;margin-top:8px">Avukatı olduğum işler</h3>'+ust.map(j=>isKart(j,'avukat')).join(''):'')+'</div>';
}

// Adliye girişindeki menü sırası: mahkeme → avukatlar / bürolar / baro → davalar → icra.
// Var olan mahkeme, baro ve icra işlemleri değiştirilmez; yalnız kartların görünme sırası düzenlenir.
function adliyeListeDuzeni(html){
 if(typeof document==='undefined')return html;
 const kutu=document.createElement('div');kutu.innerHTML=html;
 const baslik=el=>el.querySelector(':scope > h3')?.textContent.trim()||'';
 const bolum=el=>el.querySelector(':scope > h2')?.textContent.trim()||'';
 const diger=[...kutu.children].filter(el=>{
  const t=baslik(el);
  return t==='Anayasa Mahkemesi'||t==='Yüksek Yargıç aday önerileri'
   ||t==='Seçim sonuçlarına itiraz'
   ||!!el.querySelector(':scope > details > summary')?.textContent.includes('Adliye ne işe yarar?');
 });
 const kararBas=[...kutu.children].find(el=>bolum(el).startsWith('Karara bağlanan davalar'));
 if(kararBas){
  const bas=document.createElement('div');bas.className='bolum-bas';
  bas.innerHTML='<h2>İtiraz edilen davalar</h2>';
  const kart=document.createElement('div');kart.className='kart';
  kart.innerHTML='<p class="alt">İstinaf başvurusu yapılan dosyaları, incelemede olanları ve itiraz kararlarını görüntüle.</p>'
   +'<button class="btn ikinci" onclick="adliyeItirazListesiAc()">İtiraz edilen davaları göster</button>';
  kutu.insertBefore(bas,kararBas);kutu.insertBefore(kart,kararBas);
  kararBas.querySelector('h2').textContent='Karara bağlanan davalar';
 }
 const icra=[...kutu.children].find(el=>el.querySelector(':scope > details > summary')?.textContent.includes('Kredi icra mahkemesi'));
 if(icra){
  const bas=document.createElement('div');bas.className='bolum-bas';
  bas.innerHTML='<h2>İcradan satılıklar ve haciz ihaleleri</h2>';
  const digerBas=[...kutu.children].find(el=>/^(Af kararları|Yargıç atama ve görevden almalar)/.test(bolum(el)));
  if(digerBas){kutu.insertBefore(bas,digerBas);kutu.insertBefore(icra,digerBas);}
  else kutu.insertBefore(bas,icra);
 }
 // İlgili işlemler kaybolmaz; yoğun dosya listelerini bölmemesi için listenin ardından sunulur.
 diger.forEach(el=>kutu.appendChild(el));
 return kutu.innerHTML;
}
window.adliyeItirazListesiAc=()=>ekranAc(async function(){
 yukleniyor('İtiraz edilen davalar');
 const davalar=((typeof ADL!=='undefined'&&ADL.davalar)||[]).filter(x=>x.durum==='karar').slice(0,100);
 const dosyalar=[];let hata=0;
 // İtiraz bilgisi dava listesindeki özetten ayrı olduğu için yalnız bu ekran açılınca sorgulanır.
 for(let n=0;n<davalar.length;n+=8){
  const grup=davalar.slice(n,n+8);
  const cevap=await Promise.allSettled(grup.map(d=>API.rpc('adliye_dava_ek',{p_dava:d.id})));
  cevap.forEach((son,i)=>{
   if(son.status!=='fulfilled'){hata++;return;}
   if(son.value&&son.value.istinaf)dosyalar.push({dava:grup[i],ek:son.value});
  });
 }
 const kartlar=dosyalar.map(k=>{
  const d=k.dava,ist=k.ek.istinaf;
  return '<div class="kart"><div class="baslik"><b>Dosya #'+Number(d.id)+' · '+e(ADL_TURLER[d.tur]||d.tur)+'</b>'
   +'<span class="rozet">'+e(adlEtiket(d,k.ek))+'</span></div>'
   +'<p class="alt">İtiraz eden: '+e(ist.basvuran||'—')+' · Durum: '+e(ist.durum||'—')+'</p>'
   +'<button class="btn ikinci" onclick="ekranAc(()=>adliyeDosya('+Number(d.id)+'))">Dava ve itiraz dosyasını aç</button></div>';
 }).join('');
 iskelet('İtiraz edilen davalar',
  '<div class="kart"><p class="alt">Adliye kayıtlarındaki son '+davalar.length+' karar dosyası kontrol edildi.</p>'
  +(hata?'<p class="alt">Bazı dosyaların itiraz bilgisi alınamadı ('+hata+').</p>':'')+'</div>'
  +(kartlar||'<div class="kart"><p class="alt">Görüntülenebilen kayıtlar arasında itiraz edilen dava yok.</p></div>'),
  {geri:true});
});

const oncekiHtml=adliyeHtml;
adliyeHtml=async function(){
 const [govde,v]=await Promise.all([oncekiHtml(),RPC('hukuk_islerim').catch(()=>null)]);
 window.HUKUK_ISLER=v;
 let z=govde;
 for(const [a,b] of METIN)z=z.split(a).join(b);
 const kart=v?islerimHtml(v):'';
 if(kart){
  const yer='<div id="adlSozcuYeri"></div>';
  z=z.includes(yer)?z.replace(yer,yer+kart):z+kart;
 }
 return adliyeListeDuzeni(z);
};

/* ---------- Dava talebi (eski "Dava aç" yerine) ---------- */
/* ---------- Avukat tutmak isteğe bağlı: doğrudan dava aç ---------- */
window.adlDavaModal=async function(){
 let kurumlar=[];
 try { kurumlar=await RPC('adliye_kurum_listesi'); if(!Array.isArray(kurumlar))kurumlar=[]; } catch(_) { kurumlar=[]; }
 const partiler=(typeof ADL!=='undefined'&&ADL.partiler)||[];
 const gbPartiler=partiler.filter(x=>x.gb_miyim);
 const turler=Object.entries(typeof ADL_TURLER!=='undefined'?ADL_TURLER:{}).map(([k,v])=>'<option value="'+h(k)+'">'+h(v)+'</option>').join('')+'<option value="tazminat">Tazminat</option>';
 const m=modal('<p class="alt"><b>Davayı kendin açabilirsin.</b> Avukat tutmak isteğe bağlıdır; istersen dava açıldıktan sonra Baro veya dava dosyası üzerinden avukat tutabilirsin. Dava harcı uygulanır.</p>'
  +'<div class="alan"><label>Davalı türü</label><select id="hiHedefTur"><option value="oyuncu">Oyuncu</option><option value="parti">Siyasi parti</option>'
  +Object.entries(KURUM).map(([k,v])=>'<option value="'+k+'">'+h(v)+'</option>').join('')+'</select></div>'
  +'<div class="alan" id="hiOyuncuKutu"><label>Davalı kullanıcı adı</label><input id="hiHedef" placeholder="Oyuncu kullanıcı adı"></div>'
  +'<div class="alan" id="hiPartiKutu" style="display:none"><label>Davalı parti</label><select id="hiHedefParti">'+partiler.map(x=>'<option value="'+x.id+'">'+h(x.ad)+'</option>').join('')+'</select></div>'
  +'<div id="hiKurumKutu" style="display:none"><div class="alan"><label>Kurum ara</label><input id="hiKurumAra" placeholder="Kurum adı veya şehir"></div><div class="alan"><label>Davalı kurum</label><select id="hiKurum"></select></div></div>'
  +'<div class="alan"><label>Dava türü</label><select id="hiTur">'+turler+'</select></div><p class="kucuk" id="hiSuc"></p>'
  +'<div class="alan" id="hiTazKutu" style="display:none"><label>Talep edilen tazminat (₺)</label><input id="hiTaz" type="number" min="1000" max="500000" step="1" placeholder="1000–500000"></div>'
  +'<div class="alan"><label>Davacı olarak</label><select id="hiDavaci"><option value="">Kendi adıma</option>'+gbPartiler.map(x=>'<option value="'+x.id+'">'+h(x.ad)+' adına (genel başkan olarak)</option>').join('')+'</select></div>'
  +'<div class="alan"><label>İddia ve dava gerekçesi (20–1600 karakter)</label><textarea id="hiIddia" rows="5" maxlength="1600" '+TA+' placeholder="Olayı ve hangi oyun kuralının ihlal edildiğini açıkla"></textarea></div>'
  +'<div class="alan"><label>Deliller ve işlem kayıtları</label><textarea id="hiDelil" rows="4" maxlength="1600" '+TA+' placeholder="Oyun içi mesaj, işlem, tarih ve kanıtları belirt"></textarea></div>'
  +'<button class="btn altin" id="hiGonder">Davayı doğrudan aç</button>');
 adlFormBaslik(m,'Yeni dava · avukat zorunlu değil');
 const sec=m.querySelector('#hiHedefTur'), tur=m.querySelector('#hiTur'), ks=m.querySelector('#hiKurum'), dv=m.querySelector('#hiDavaci');
 function listele(){
  const ara=m.querySelector('#hiKurumAra').value.trim().toLocaleLowerCase('tr');
  const l=kurumlar.filter(x=>x.tur===sec.value&&(!ara||String(x.ad).toLocaleLowerCase('tr').includes(ara))).slice(0,300);
  ks.innerHTML=l.length?l.map(x=>'<option value="'+h(String(x.id))+'">'+h(String(x.ad))+'</option>').join(''):'<option value="">Eşleşen kurum yok</option>';
 }
 function guncelle(){
  const s=sec.value, kurum=Object.prototype.hasOwnProperty.call(KURUM,s);
  m.querySelector('#hiOyuncuKutu').style.display=s==='oyuncu'?'block':'none';
  m.querySelector('#hiPartiKutu').style.display=s==='parti'?'block':'none';
  m.querySelector('#hiKurumKutu').style.display=kurum?'block':'none';
  const taz=tur.querySelector('option[value="tazminat"]');
  taz.disabled=s==='parti'||s==='makam'||(s==='oyuncu'&&dv.value!=='');
  if(taz.disabled&&tur.value==='tazminat')tur.value='diger';
  m.querySelector('#hiTazKutu').style.display=tur.value==='tazminat'?'block':'none';
  m.querySelector('#hiSuc').textContent=tur.value==='tazminat'?'Kanıtlanabilir oyun içi zarar için 1.000–500.000 ₺ tazminat isteyebilirsin.':((typeof ADL_SUCLAR!=='undefined'&&ADL_SUCLAR[tur.value])||'');
  if(kurum)listele();
 }
 sec.onchange=guncelle;tur.onchange=guncelle;dv.onchange=guncelle;m.querySelector('#hiKurumAra').oninput=listele;guncelle();
 m.querySelector('#hiGonder').onclick=async()=>{
  const s=sec.value, kurum=Object.prototype.hasOwnProperty.call(KURUM,s);
  const hedef=kurum?ks.value:s==='parti'?m.querySelector('#hiHedefParti').value:m.querySelector('#hiHedef').value.trim();
  const iddia=m.querySelector('#hiIddia').value.trim(), delil=m.querySelector('#hiDelil').value.trim();
  const davaciParti=dv.value?Number(dv.value):null;
  if(!hedef)return toast('Davalı oyuncu, parti veya kurum seç.',true);
  if(iddia.length<20)return toast('İddiayı en az 20 karakterle açıkla.',true);
  const taz=tur.value==='tazminat'?Number(m.querySelector('#hiTaz').value):null;
  if(tur.value==='tazminat'&&(!Number.isInteger(taz)||taz<1000||taz>500000))return toast('Tazminat talebi 1.000–500.000 ₺ olmalı.',true);
  const btn=m.querySelector('#hiGonder');btn.disabled=true;
  try {
   let r;
   if(kurum) r=await RPC('adliye_kurum_dava_ac',{p_hedef_tur:s,p_hedef:String(hedef),p_tur:tur.value,p_iddia:iddia,p_delil:delil,p_davaci_parti:davaciParti,p_tazminat_talep:taz});
   else if(tur.value==='tazminat') r=await RPC('adliye_tazminat_davasi_ac',{p_hedef:String(hedef),p_talep:taz,p_iddia:iddia,p_delil:delil});
   else r=await RPC('adliye_dava_ac',{p_hedef_tur:s,p_hedef:String(hedef),p_tur:tur.value,p_iddia:iddia,p_delil:delil,p_davaci_parti:davaciParti});
   modalKapat();toast('Dava #'+r.id+' açıldı. Avukat tutmak isteğe bağlıdır.');
   ekranAc(()=>adliyeDosya(r.id));
  } catch(err) { btn.disabled=false; error(err); }
 };
};

/* ---------- Seçim itirazına doğrudan başvuru ---------- */
window.adlSecimItirazModal=function(secim){
 const a=(typeof ADL!=='undefined'&&ADL.siyasi)||{secimler:[]};
 const se=(a.secimler||[]).find(x=>x.id===secim);
 const partiler=((typeof ADL!=='undefined'&&ADL.partiler)||[]).filter(x=>x.gb_miyim);
 if(!se)return toast('Seçim bulunamadı.',true);
 if(!partiler.length)return toast('Seçim itirazını ilgili partinin genel başkanı yapabilir.',true);
 const m=modal('<p class="alt">Genel başkan olarak itirazını kendin sunabilirsin. Avukat tutmak isteğe bağlıdır. Sonuçlardan itibaren 48 saatlik süre geçerlidir.</p>'
  +'<div class="alan"><label>İtiraz eden parti</label><select id="hsParti">'+partiler.map(p=>'<option value="'+p.id+'">'+h(p.ad)+'</option>').join('')+'</select></div>'
  +'<div class="alan"><label>İtiraz gerekçesi (30–1600 karakter)</label><textarea id="hsGerekce" rows="4" maxlength="1600" '+TA+'></textarea></div>'
  +'<div class="alan"><label>Deliller ve olay kayıtları</label><textarea id="hsDelil" rows="4" maxlength="3000" '+TA+'></textarea></div>'
  +'<button class="btn altin" id="hsGonder">İtirazı doğrudan gönder</button>');
 adlFormBaslik(m,'Seçim #'+se.id+' · '+h(se.tur)+' · '+h(se.donem));
 m.querySelector('#hsGonder').onclick=async()=>{
  const btn=m.querySelector('#hsGonder');btn.disabled=true;
  try {
   const r=await RPC('adliye_secim_itiraz_ac',{p_secim:secim,p_parti:Number(m.querySelector('#hsParti').value),p_gerekce:m.querySelector('#hsGerekce').value,p_deliller:m.querySelector('#hsDelil').value});
   modalKapat();toast('Seçim itirazı #'+r.id+' mahkemeye iletildi.');yenile();
  } catch(err) { btn.disabled=false;error(err); }
 };
};

/* ---------- Hukuki iş eylemleri ---------- */
const isBul=id=>{const v=window.HUKUK_ISLER||{};return [...(v.benim||[]),...(v.ustlendigim||[]),...(v.acik||[])].find(j=>j.id===id);};
window.hukukIsTeklifKarar=async(tid,kabul)=>{
 if(kabul&&!await onayla('Avukatı seç','Ücret cüzdanından alınıp emanete konur; avukat dilekçeyi mahkemeye sunduğunda ona geçer. Sunulmadan geri çekersen iade edilir.','Kabul et',false))return;
 try{await RPC('hukuk_is_teklif_karar',{p_teklif:tid,p_kabul:kabul});toast(kabul?'Avukatın atandı; dilekçeyi hazırlıyor.':'Teklif reddedildi.');yenile();}catch(err){error(err);}
};
window.hukukIsIptal=async(id,avukat)=>{
 if(!await onayla(avukat?'Vekâletten çekil':'Talebi geri çek',avukat?'Emanetteki ücret müvekkile iade edilir ve iş yeniden avukat aramaya başlar.':'Talep kapanır; emanetteki ücret varsa iade edilir.',avukat?'Çekil':'Geri çek',true))return;
 try{const r=await RPC('hukuk_is_iptal',{p_is:id});toast(Number(r.iade)?'İade: '+money(r.iade):'İşlem tamam.');yenile();}catch(err){error(err);}
};
window.hukukIsDavet=id=>{
 const m=modal('<div class="alan"><label>Avukatın kullanıcı adı</label><input id="hdKad"></div><button class="btn altin" id="hdGonder">Davet gönder</button>');
 adlFormBaslik(m,'Hukuki iş #'+id+' · avukat davet et');
 m.querySelector('#hdGonder').onclick=async()=>{try{await RPC('hukuk_is_davet',{p_is:id,p_kad:m.querySelector('#hdKad').value});modalKapat();toast('Davet gönderildi.');}catch(err){error(err);}};
};
window.hukukIsTeklifModal=id=>{
 const j=isBul(id)||{};
 const taz=j.dava_tur==='tazminat';
 const m=modal('<p class="alt">'+h(TUR_AD[j.tur]||'')+(j.hedef_ad?' · '+h(j.hedef_ad):'')+' · Müvekkil: '+h(j.muvekkil||'')+'</p>'
  +'<div class="alan"><label>Ücret (₺) — kabul edilirse emanete alınır, dilekçeyi sunduğunda sana geçer</label><input id="htTutar" type="number" min="0" step="1" value="10000"></div>'
  +(taz?'<div class="alan"><label>Tahsil edilen tazminattan başarı primi (%0–25)</label><input id="htPrim" type="number" min="0" max="25" step="1" value="0"></div>':'')
  +'<div class="alan"><label>Müvekkile notun</label><textarea id="htNot" rows="3" maxlength="500" '+TA+'></textarea></div><button class="btn altin" id="htGonder">Teklifi gönder</button>');
 adlFormBaslik(m,'Hukuki iş #'+id+' · teklif');
 m.querySelector('#htGonder').onclick=async()=>{
  try{await RPC('hukuk_is_teklif_ver',{p_is:id,p_tutar:Number(m.querySelector('#htTutar').value),p_prim:taz?Number(m.querySelector('#htPrim').value):0,p_aciklama:m.querySelector('#htNot').value});
   modalKapat();toast('Teklifin müvekkile iletildi.');yenile();}catch(err){error(err);}
 };
};
window.hukukIsSunModal=id=>{
 const j=isBul(id)||{};
 const dava=j.tur==='dava';
 const m=modal('<p class="alt">'+h(TUR_AD[j.tur]||'')+(j.hedef_ad?' · '+h(j.hedef_ad):'')+' · Müvekkil: '+h(j.muvekkil||'')+'</p>'
  +'<p class="kucuk">Dilekçe müvekkilin adına mahkemeye verilir'+(dava?'; dava harcı müvekkilin cüzdanından alınır ve dosyada davacı vekili olarak görünürsün':'')+'. Sunduğunda emanetteki '+money(j.emanet)+' sana ödenir.</p>'
  +'<div class="alan"><label>'+(j.tur==='pkd_savunma'?'Savunma metni (50–3000)':dava?'Dilekçe / iddia (20–1600)':'İtiraz gerekçesi (30–1600)')+'</label><textarea id="hsMetin" rows="7" maxlength="3000" '+TA+'></textarea></div>'
  +(j.tur!=='pkd_savunma'?'<div class="alan"><label>Deliller</label><textarea id="hsDl" rows="3" maxlength="3000" '+TA+'></textarea></div>':'')
  +'<button class="btn altin" id="hsSun">Mahkemeye sun</button>');
 adlFormBaslik(m,'Hukuki iş #'+id+' · dilekçe');
 m.querySelector('#hsMetin').value=j.metin||'';
 const dl=m.querySelector('#hsDl');if(dl)dl.value=j.delil||'';
 m.querySelector('#hsSun').onclick=async()=>{
  try{const r=await RPC('hukuk_is_sun',{p_is:id,p_metin:m.querySelector('#hsMetin').value,p_delil:dl?dl.value:null});
   modalKapat();toast(r.dava_id?'Dava #'+r.dava_id+' açıldı; vekil olarak dosyadasın.':'Başvuru mahkemeye sunuldu.');
   if(r.dava_id)ekranAc(()=>adliyeDosya(r.dava_id));else yenile();}catch(err){error(err);}
 };
};

/* ---------- Doğrudan savunma ve istinaf erişimi, avukat isteğe bağlı ---------- */
const oncekiDosya=adliyeDosya;
adliyeDosya=async function(id){
 await oncekiDosya(id);
 try {
  const root=document.getElementById('icerik');if(!root)return;
  const b=await RPC('baro_dava_bilgi',{p_dava:id});
  if(document.getElementById('icerik')!==root)return;
  const butonlar=[...root.querySelectorAll('button')].map(x=>x.textContent.trim());
  let ek='';
  if(b.dava_acik&&b.muvekkil_taraf&&!butonlar.some(x=>x.includes('Savunma / beyan ver')))
   ek+='<button class="btn altin" onclick="adlBeyanModal('+Number(id)+')">Kendi savunmamı / beyanımı sun</button>';
  if(b.istinaf_acik&&b.muvekkil_taraf===b.kaybeden&&!butonlar.some(x=>x.includes('İstinafa başvur')))
   ek+='<button class="btn altin" onclick="adlIstinafModal('+Number(id)+')">Avukatsız istinafa başvur</button>';
  if(b.muvekkil_taraf)
   ek+='<p class="kucuk" style="margin-top:8px">Bu davada kendini temsil edebilir veya isteğe bağlı olarak Baro üzerinden avukat tutabilirsin.</p>';
  if(ek){
   const d=document.createElement('div');d.className='kart';d.innerHTML=ek;
   const panel=root.querySelector('#avukatHukukPanel');
   if(panel)panel.insertAdjacentElement('beforebegin',d);
   else root.appendChild(d);
  }
 }catch(err){console.warn('İsteğe bağlı avukat gösterimi:',err.message);}
};
window.avukatIstinafModal=id=>{
 const m=modal('<p class="alt">Müvekkilin adına istinaf başvurusu yaparsın. Kurayla seçilen 3 kişilik tarafsız jüri kararı onaylar ya da bozar; her davada bir kez başvurulur.</p><div class="alan"><label>İstinaf gerekçesi (20–1500)</label><textarea id="aiGerekce" rows="5" maxlength="1500" '+TA+'></textarea></div><button class="btn altin" id="aiGonder">İstinafa başvur</button>');
 adlFormBaslik(m,'Dava #'+id+' · vekil istinafı');
 m.querySelector('#aiGonder').onclick=async()=>{try{const r=await RPC('avukat_istinaf',{p_dava:id,p_gerekce:m.querySelector('#aiGerekce').value});modalKapat();toast('İstinaf başvurusu alındı; '+(r.juri||3)+' kişilik jüri belirlendi.');await adliyeDosya(id);}catch(err){error(err);}};
};

/* ---------- Parti sayfası: sözcü kartı + resmî açıklamalar ---------- */
if(typeof window.partiDetay==='function'){
 const eskiParti=window.partiDetay;
 window.partiDetay=async function(id){
  await eskiParti(id);
  try{
   const root=document.getElementById('icerik');if(!root)return;
   const kart=[...root.querySelectorAll('.kart')].find(k=>k.querySelector('h3')&&k.querySelector('h3').textContent.trim()==='Parti Sözcüsü');
   const v=await RPC('parti_aciklamalari',{p_parti:id});
   if(document.getElementById('icerik')!==root)return;
   if(kart){const p=[...kart.querySelectorAll('p.alt')].find(x=>x.textContent.includes('sözcüsünün görevi')||x.textContent.includes('sözcüsü ne yapar'));if(p)p.outerHTML=SOZCU_METNI;}
   const yeni=document.createElement('div');yeni.className='kart';yeni.id='partiAciklamaKart';
   yeni.innerHTML='<h3>📢 Resmî açıklamalar</h3>'
    +(v.yazabilirim?'<div class="alan"><label>Başlık</label><input id="paBaslik" maxlength="120"></div><div class="alan"><label>Açıklama (10–2000)</label><textarea id="paMetin" rows="4" maxlength="2000" '+TA+'></textarea></div>'
      +'<button class="btn altin" onclick="partiAciklamaYap('+id+')">Parti adına açıkla</button><p class="kucuk">Açıklama Gündem akışına düşer ve bütün üyelere bildirilir. 15 dakikada bir açıklama yapılabilir.</p>':'')
    +((v.aciklamalar||[]).map(a=>'<div class="liste-satir"><div class="orta"><b>'+h(a.baslik)+'</b><div class="kucuk">'+(a.rol==='sozcu'?'Parti Sözcüsü':'Genel Başkan')+' '+h(a.yazar)+' · '+h(stamp(a.zaman))+'</div><p style="white-space:pre-wrap;margin-top:4px">'+h(a.metin)+'</p></div>'
      +(a.silebilirim?'<button class="btn ikinci" style="width:auto" onclick="partiAciklamaSil('+a.id+','+id+')">Kaldır</button>':'')+'</div>').join('')||'<p class="alt">Henüz resmî açıklama yapılmadı.</p>');
   if(kart)kart.insertAdjacentElement('afterend',yeni);else root.appendChild(yeni);
  }catch(err){console.warn('Parti açıklamaları:',err.message);}
 };
}
window.partiAciklamaYap=async pid=>{
 const b=document.getElementById('paBaslik'),t=document.getElementById('paMetin');
 try{await RPC('parti_aciklama_yap',{p_parti:pid,p_baslik:b?b.value:'',p_metin:t?t.value:''});toast('Resmî açıklama yayımlandı.');await window.partiDetay(pid);}catch(err){error(err);}
};
window.partiAciklamaSil=async(aid,pid)=>{
 if(!await onayla('Açıklamayı kaldır','Açıklama parti sayfasından kaldırılır.','Kaldır',true))return;
 try{await RPC('parti_aciklama_sil',{p_id:aid});toast('Açıklama kaldırıldı.');await window.partiDetay(pid);}catch(err){error(err);}
};
})();
