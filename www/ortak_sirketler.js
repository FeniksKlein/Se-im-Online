/* Seçim Online - Çok ortaklı şirket kuruluşu ve pay devri, 22.10.2026 */
(function(){
'use strict';
if(window.ORTAK_SIRKETLER_MODULU) return;
window.ORTAK_SIRKETLER_MODULU=true;
const esc=x=>String(x==null?'':x).replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const num=x=>Number(x||0);
const tl=x=>num(x).toLocaleString('tr-TR',{maximumFractionDigits:2})+' ₺';
const row=(a,b)=>'<div class="kv"><span>'+esc(a)+'</span><b>'+esc(b)+'</b></div>';
const btn=(label,fn,css='ikinci')=>'<button class="btn '+css+'" onclick="'+fn+'">'+esc(label)+'</button>';
const fmt=x=>x?new Date(x).toLocaleString('tr-TR'):'—';
const cities='Adana,Adıyaman,Afyonkarahisar,Ağrı,Amasya,Ankara,Antalya,Artvin,Aydın,Balıkesir,Bilecik,Bingöl,Bitlis,Bolu,Burdur,Bursa,Çanakkale,Çankırı,Çorum,Denizli,Diyarbakır,Edirne,Elazığ,Erzincan,Erzurum,Eskişehir,Gaziantep,Giresun,Gümüşhane,Hakkâri,Hatay,Isparta,Mersin,İstanbul,İzmir,Kars,Kastamonu,Kayseri,Kırklareli,Kırşehir,Kocaeli,Konya,Kütahya,Malatya,Manisa,Kahramanmaraş,Mardin,Muğla,Muş,Nevşehir,Niğde,Ordu,Rize,Sakarya,Samsun,Siirt,Sinop,Sivas,Tekirdağ,Tokat,Trabzon,Tunceli,Şanlıurfa,Uşak,Van,Yozgat,Zonguldak,Aksaray,Bayburt,Karaman,Kırıkkale,Batman,Şırnak,Bartın,Ardahan,Iğdır,Yalova,Karabük,Kilis,Osmaniye,Düzce'.split(',');
const sectors=[
['ticaret','Ticaret / Mağaza'],['sanayi','Sanayi / Fabrika'],['tarim','Tarım ve Hayvancılık'],
['teknoloji','Teknoloji'],['insaat','İnşaat / Müteahhitlik'],['medya','Medya ve Yayıncılık'],
['akaryakit','Akaryakıt İstasyonu'],['market','Market Zinciri'],['turizm','Turizm / Otelcilik'],
['lojistik','Kargo / Lojistik'],['enerji','Enerji Santrali'],['ulasim','Ulaşım Firması'],
['oto_galeri','Otomobil Galerisi'],['oto_servis','Oto Servis'],['elektronik_magaza','Elektronik Mağazası'],
['tekstil_magaza','Giyim Mağazası'],['mobilya_magaza','Mobilya Mağazası'],
['yapi_market','Yapı Market'],['e_ticaret','E-Ticaret Şirketi'],
['geri_donusum','Geri Dönüşüm'],['danismanlik','Danışmanlık Ofisi'],
['ozel_okul','Özel Okul'],['ozel_hastane','Özel Hastane']];
function err(e){toast(typeof hataCevir==='function'?hataCevir(e.message):String(e.message||e),true);}
async function rpc(name,args){return API.rpc(name,args||{});}
async function approve(title,body){return typeof onayla==='function'?onayla(title,body,'Onayla'):window.confirm(body);}
window.ortaklikEkrani=async function(){
 yukleniyor('Şirket Ortaklık Merkezi');
 try{
  const d=await rpc('ortak_sirket_panel');
  let html='<div class="kart"><h2>🤝 Şirket Ortaklık Merkezi</h2><p class="alt">Birlikte sermaye koyarak şirket kurabilir, yeni ortak kabul edebilir, hissenin tamamını ya da bir bölümünü bedelli veya bedelsiz devredebilirsin. Hisselerin toplamı her zaman %100 kalır.</p>'+
   '<p class="alt">Kuruluş için bütün ortakların daveti kabul etmesi ve son onay anında herkesin hesabında taahhüt ettiği paranın bulunması gerekir. Davetler 72 saat geçerlidir.</p></div>';
  html+='<div class="kart"><h3>🏗️ Birlikte yeni şirket kur</h3>'+
   '<div class="alan"><label>Yeni şirketin adı</label><input id="os_ad" maxlength="50" placeholder="Örnek: Ortaklar Ticaret Ltd."></div>'+
   '<div class="alan"><label>Sektör</label><select id="os_sektor" onchange="ortaklikSektorDegisti()">'+sectors.map(([k,v])=>'<option value="'+k+'">'+esc(v)+'</option>').join('')+'</select></div>'+
   '<div class="alan"><label>Şirket merkezi (il)</label><select id="os_il">'+cities.map((name,i)=>'<option value="'+(i+1)+'"'+(name==='Muğla'?' selected':'')+'>'+esc(name)+'</option>').join('')+'</select></div>'+
   '<div class="alan"><label>Sanayi üretim grubu / enerji santrali kaynağı</label><select id="os_urun"><option value="malzeme">Malzeme</option><option value="gida">Gıda</option><option value="teknoloji">Teknoloji</option></select></div>'+
   '<div class="alan"><label>Benim koyacağım kuruluş sermayesi (₺)</label><input id="os_kendi" type="number" inputmode="numeric" step="1" min="1" value="100000"></div>'+
   '<div class="alan"><label>Davet edilecek ortaklar (her satıra kullanıcı adı, sermaye)</label><textarea id="os_ortaklar" rows="3" placeholder="oyuncu1, 100000\noyuncu2, 50000"></textarea></div>'+
   '<p class="alt">En fazla 7 başka oyuncu. Toplam sermaye 100.000–100.000.000 ₺. Herkesin payı koyduğu sermayeye göre belirlenir. Para, şirket kurulana kadar hesaplardan çekilmez.</p>'+
   btn('Ortaklara kuruluş daveti gönder','ortakKurulusDavet()','altin')+'</div>';
  html+='<div class="kart"><h3>📨 Kuruluş davetleri</h3>';
  for(const k of (d.kuruluslar||[])){
   html+='<div class="kart"><b>'+esc(k.ad)+'</b>'+row('Sektör',k.sektor)+row('Toplam sermaye',tl(k.toplam))+
    row('Kurucu',k.kurucu)+row('Davet bitişi',fmt(k.bitis));
   for(const a of (k.katilimlar||[])){
    html+=row(a.kad+' · '+a.durum,tl(a.tutar));
    if(a.benim&&a.durum==='davet')html+=
     btn('Kabul et','ortakKurulusYanıtla('+k.id+',true)','altin')+
     btn('Reddet','ortakKurulusYanıtla('+k.id+',false)');
   }
   if(k.kurucu_benim){
    const ready=(k.katilimlar||[]).every(x=>x.durum==='kabul');
    if(ready)html+=btn('Tüm sermayeyi topla ve şirketi kur','ortakKurulusBitir('+k.id+')','altin');
    else html+='<p class="alt">Kuruluş bütün ortakların kabulünü bekliyor.</p>';
    html+=btn('Kuruluş teklifini iptal et','ortakKurulusIptal('+k.id+')');
   }
   html+='</div>';
  }
  if(!(d.kuruluslar||[]).length)html+='<p class="alt">Bekleyen kuruluş daveti yok.</p>';
  html+='</div><div class="kart"><h3>🏢 Ortak olduğum şirketler</h3>';
  const cs=d.sirketler||[];
  for(const s of cs){
   html+='<div class="kart"><b>'+esc(s.ad)+'</b>'+
    row('Benim hissem','%'+s.benim_pay)+row('Sermaye',tl(s.sermaye))+
    row('Şirket kasası',tl(s.kasa))+row('Ortaklık yapısı',s.tek_ortak?'Tek ortaklı · %100 benim':'Çok ortaklı')+
    (s.ortaklar||[]).map(a=>row(a.kad,'%'+a.pay)).join('')+
    btn('Bu şirketten pay devret / yeni ortak al','ortaklikHisseFormu('+s.id+')','altin')+'</div>';
  }
  if(!cs.length)html+='<p class="alt">Henüz ortak olduğun şirket bulunmuyor.</p>';
  html+='</div><div class="kart"><h3>💸 Hisse devri ve yeni ortak kabulü</h3>'+
   '<p class="alt">Bir oyuncuya hisseni ücretsiz devredebilir ya da istediğin fiyatla teklif gönderebilirsin. Alıcı kabul edince paylar değişir. Tüm hisseleri bir oyuncu toplarsa şirket tek ortaklı olur. Ücretli devirde para satıcıya gider, şirket kasasına değil.</p>'+
   '<div class="alan"><label>Hisse devredeceğim şirket</label><select id="os_sirket">'+cs.map(s=>'<option value="'+Number(s.id)+'">'+esc(s.ad)+' (%'+esc(s.benim_pay)+')</option>').join('')+'</select></div>'+
   '<div class="alan"><label>Hisseyi alacak oyuncu adı</label><input id="os_alici" maxlength="80" placeholder="Kullanıcı adı"></div>'+
   '<div class="alan"><label>Devredilecek şirket hissesi (%)</label><input id="os_pay" type="number" min="0.000001" max="100" step="0.000001" placeholder="25"></div>'+
   '<div class="alan"><label>Toplam devir bedeli (₺ · ücretsiz devir için 0)</label><input id="os_bedel" type="number" step="1" min="0" value="0"></div>'+
   btn('Hisse devir teklifi gönder','ortaklikDevirTeklif()','altin')+'</div>';
  html+='<div class="kart"><h3>📄 Bekleyen hisse devirleri</h3>';
  for(const x of d.devirler||[]){
   html+='<div class="kart"><b>'+esc(x.sirket)+'</b>'+
    row('Satıcı',x.satici)+row('Alıcı',x.alici)+row('Devredilecek pay','%'+x.pay)+
    row('Bedel',num(x.bedel)===0?'Bedelsiz':tl(x.bedel))+
    row('Teklif bitişi',fmt(x.bitis));
   if(x.benim_gelen)html+=btn('Devri kabul et','ortaklikDevirKarar('+x.id+',true)','altin')+
    btn('Devri reddet','ortaklikDevirKarar('+x.id+',false)');
   if(x.benim_teklifim)html+=btn('Teklifi iptal et','ortaklikDevirIptal('+x.id+')');
   html+='</div>';
  }
  if(!(d.devirler||[]).length)html+='<p class="alt">Bekleyen devir bulunmuyor.</p>';
  html+='</div>';
  iskelet('Şirket Ortaklık Merkezi',html,{geri:true});
 }catch(e){iskelet('Şirket Ortaklık Merkezi','<div class="kart">'+esc(e.message||e)+'</div>',{geri:true});}
};
const get=id=>document.getElementById(id)?.value||'';
window.ortaklikSektorDegisti=function(){
 const sector=get('os_sektor'),select=document.getElementById('os_urun');
 if(!select)return;
 if(sector==='enerji')select.innerHTML='<option value="dogalgaz">Doğalgaz</option><option value="komur">Kömür</option><option value="yenilenebilir">Yenilenebilir</option>';
 else select.innerHTML='<option value="malzeme">Malzeme</option><option value="gida">Gıda</option><option value="teknoloji">Teknoloji</option>';
};
window.ortakKurulusDavet=async function(){
 try{
  const rows=get('os_ortaklar').split(/\r?\n/).map(s=>s.trim()).filter(Boolean);
  const ortaklar=rows.map(s=>{
   const i=s.lastIndexOf(','); if(i<=0)throw Error('Her satır kullanıcı adı, tutar şeklinde olmalı.');
   const kad=s.slice(0,i).trim(),tutar=s.slice(i+1).trim().replace(/\s/g,'');
   if(!/^\d+$/.test(tutar)||Number(tutar)<=0||!Number.isSafeInteger(Number(tutar)))throw Error(kad+' için geçerli sermaye gir.');
   return {kad,tutar:Number(tutar)};
  });
  if(!ortaklar.length)throw Error('En az bir ortak davet et.');
  const params={p_ad:get('os_ad'),p_sektor:get('os_sektor'),p_il:Number(get('os_il')),
   p_urun:get('os_urun'),p_kendi:Number(get('os_kendi')),p_ortaklar:ortaklar};
  if(!await approve('Ortak şirket kuruluşu','Davetleri göndermek ve belirtilen sermaye paylarını önermek istiyor musun?'))return;
  await rpc('ortak_sirket_kur_teklif',params);toast('Kuruluş davetleri gönderildi.');ortaklikEkrani();
 }catch(e){err(e);}
};
window.ortakKurulusYanıtla=async function(id,k){try{
  if(!await approve('Ortaklık daveti',k?'Kuruluş günü belirtilen sermayeyi kendi hesabından yatırmayı kabul ediyor musun?':'Bu daveti reddediyor musun?'))return;
  await rpc('ortak_sirket_kur_karar',{p_id:Number(id),p_kabul:!!k});toast('Kararın kaydedildi.');ortaklikEkrani();
 }catch(e){err(e);}};
window.ortakKurulusBitir=async function(id){try{
  if(!await approve('Ortak şirket kur','Tüm ortakların bakiyelerinden sermayeler çekilerek yeni şirketin kasasına aktarılacak. Onaylıyor musun?'))return;
  await rpc('ortak_sirket_kur_tamamla',{p_id:Number(id)});toast('Ortak şirket kuruldu!');ortaklikEkrani();
 }catch(e){err(e);}};
window.ortakKurulusIptal=async function(id){try{
  if(!await approve('Kuruluşu iptal et','Kuruluş teklifini iptal ediyor musun?'))return;
  await rpc('ortak_sirket_kur_iptal',{p_id:Number(id)});toast('Kuruluş teklifi iptal edildi.');ortaklikEkrani();
 }catch(e){err(e);}};
window.ortaklikHisseFormu=function(id){
 const box=document.getElementById('os_sirket');if(box){box.value=String(id);box.scrollIntoView({behavior:'smooth',block:'center'});}
};
window.ortaklikDevirTeklif=async function(){try{
  const pay=Number(get('os_pay')),bedel=Number(get('os_bedel'));
  if(!Number.isFinite(pay)||pay<=0||pay>100||Math.round(pay*1e6)!==pay*1e6)throw Error('Geçerli hisse yüzdesi yaz.');
  if(!Number.isSafeInteger(bedel)||bedel<0)throw Error('Bedeli sıfır veya pozitif tam sayı gir.');
  if(!await approve('Hisse devri','%'+pay+' hisseyi '+(bedel===0?'bedelsiz':tl(bedel)+' karşılığında')+' teklif etmeyi onaylıyor musun?'))return;
  await rpc('ortak_sirket_devir_teklif',{p_sirket:Number(get('os_sirket')),p_kad:get('os_alici'),p_pay:pay,p_bedel:bedel});
  toast('Hisse devir teklifi gönderildi.');ortaklikEkrani();
 }catch(e){err(e);}};
window.ortaklikDevirKarar=async function(id,k){try{
  if(!await approve('Hisse devri',k?'Devir bedeli varsa hesabından tahsil edilip hisseler sana geçecek. Kabul ediyor musun?':'Teklifi reddediyor musun?'))return;
  await rpc('ortak_sirket_devir_karar',{p_id:Number(id),p_kabul:!!k});toast('Hisse devir işlemi güncellendi.');ortaklikEkrani();
 }catch(e){err(e);}};
window.ortaklikDevirIptal=async function(id){try{
  if(!await approve('Teklifi iptal et','Hisse devir teklifini iptal ediyor musun?'))return;
  await rpc('ortak_sirket_devir_iptal',{p_id:Number(id)});toast('Teklif iptal edildi.');ortaklikEkrani();
 }catch(e){err(e);}};

const previous=window.sirketYonetimEkrani;
if(typeof previous==='function')window.sirketYonetimEkrani=async function(){
 await previous.apply(this,arguments);
 const r=document.querySelector('.so-buttons');
 if(r&&!r.querySelector('.ortak-merkez-btn'))r.insertAdjacentHTML('afterbegin',
  '<button class="btn altin ortak-merkez-btn" onclick="ekranAc(ortaklikEkrani)">🤝 Ortak şirket kur · Hisse devri · Yeni ortak</button>');
};
const prevDetail=window.sirketPortfoyDetay;
if(typeof prevDetail==='function')window.sirketPortfoyDetay=async function(){
 await prevDetail.apply(this,arguments);
 const base=document.querySelector('.so-detail');
 if(base&&!document.querySelector('.ortak-merkez-detay'))base.insertAdjacentHTML('afterend',
  '<div class="kart ortak-merkez-detay"><h3>🤝 Ortaklık ve hisse yönetimi</h3>'+
  btn('Ortaklar · Hisseler · Bedelsiz veya ücretli devir','ekranAc(ortaklikEkrani)','altin')+'</div>');
};
})();