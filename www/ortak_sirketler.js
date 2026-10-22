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
  const cs=d.sirketler||[];
  const wallet=await rpc('sirket_kasa_bilgi');
  const secili=Number(window.osSeciliSirket||0);
  html+='</div><div class="kart"><h3>💰 Kendi paranı şirket kasasına aktar</h3>'+
   '<p class="alt">Şube, mağaza, arsa, inşaat veya üretim yatırımı için şirket kasasında yeterli para yoksa kişisel cüzdanından yatırabilirsin. Hisse oranların değişmez. Katkı kâr veya satış geliri sayılmaz.</p>'+
   row('Kişisel cüzdanım',tl(wallet.bakiye))+
   '<div class="alan"><label>Para yatırılacak şirket</label><select id="os_yatir_sirket">'+
   cs.map(s=>'<option value="'+Number(s.id)+'"'+(secili===Number(s.id)?' selected':'')+'>'+
     esc(s.ad)+' · Kasada '+esc(tl(s.kasa))+'</option>').join('')+'</select></div>'+
   '<div class="alan"><label>Kişisel cüzdanımdan aktarılacak tutar (₺)</label>'+
   '<input id="os_yatir_tutar" type="number" min="1" max="100000000" step="1" inputmode="numeric" placeholder="Örnek: 250000"></div>'+
   '<p class="alt">Bu işlem yalnızca bakiyen kadar yapılabilir. Aynı tutar kişisel hesabından düşer ve seçtiğin şirketin kasasına eklenir. Şirketin sermaye üst limiti 100 milyon ₺.</p>'+
   (cs.length?btn('Şirket kasasına para yatır','ortaklikKasayaYatir()','altin'):'<p class="alt">Para yatırmak için önce bir şirkete ortak olmalısın.</p>')+
   '</div><div class="kart"><h3>🏬 Yeni Şube Yatırım Planlayıcısı</h3>'+
   '<p class="alt">Şube açmadan önce bulunduğu ildeki talebi, haftalık ciroyu, stok maliyetini, kirayı, çalışanları ve tahmini net kârı gör. Açılış bedeli artık sabit 25.000 ₺ değil. Şirket kasasında hem yatırım bedeli hem de işletme rezervi bulunmalı.</p>'+
   '<div class="alan"><label>Şube açacak şirket</label><select id="os_sube_sirket" onchange="window.osSonTeklif=null;document.getElementById(\'os_sube_sonuc\').innerHTML=\'\'">'+
   cs.map(s=>'<option value="'+Number(s.id)+'"'+(secili===Number(s.id)?' selected':'')+'>'+
     esc(s.ad)+' · '+esc(s.sektor)+'</option>').join('')+'</select></div>'+
   '<div class="alan"><label>Şubenin açılacağı il</label><select id="os_sube_il" onchange="window.osSonTeklif=null;document.getElementById(\'os_sube_sonuc\').innerHTML=\'\'">'+
   cities.map((il,i)=>'<option value="'+(i+1)+'"'+(il==='Muğla'?' selected':'')+'>'+esc(il)+'</option>').join('')+'</select></div>'+
   (cs.length?btn('Şube maliyet ve kâr tahmini hesapla','sirketSubeMaliyetHesapla()','altin'):'<p class="alt">Önce bir şirkete ortak olmalısın.</p>')+
   '<div id="os_sube_sonuc"></div></div><div class="kart"><h3>🏢 Ortak olduğum şirketler</h3>';
  for(const s of cs){
   html+='<div class="kart"><b>'+esc(s.ad)+'</b>'+
    row('Benim hissem','%'+s.benim_pay)+row('Sermaye',tl(s.sermaye))+
    row('Şirket kasası',tl(s.kasa))+row('Ortaklık yapısı',s.tek_ortak?'Tek ortaklı · %100 benim':'Çok ortaklı')+
    (s.ortaklar||[]).map(a=>row(a.kad,'%'+a.pay)).join('')+
    btn('Kasaya şahsi para yatır','sirketKasasiAc('+Number(s.id)+')','altin')+
    btn('Yeni şube aç · maliyet hesapla','sirketSubePlanAc('+Number(s.id)+')')+
    btn('Şube gelir/gider raporu','sirketSubeRapor('+Number(s.id)+')')+
    btn('Bu şirketten pay devret / yeni ortak al','ortaklikHisseFormu('+s.id+')')+'</div>';
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
window.sirketKasasiAc=function(id){
 window.osSeciliSirket=Number(id)||0;
 if(typeof ekranAc==='function')ekranAc(window.ortaklikEkrani);
 else window.ortaklikEkrani();
};
window.sirketSubePlanAc=function(id){
 window.osSeciliSirket=Number(id)||0;
 if(typeof ekranAc==='function')ekranAc(window.ortaklikEkrani);
 else window.ortaklikEkrani();
};
window.sirketSubeMaliyetHesapla=async function(){
 const sid=Number(get('os_sube_sirket')), il=Number(get('os_sube_il'));
 const div=document.getElementById('os_sube_sonuc');
 if(!div)return;
 try{
  div.innerHTML='<p class="alt">Şehrin pazar şartları hesaplanıyor…</p>';
  const d=await rpc('sirket_sube_teklif',{p_sirket:sid,p_il:il});
  window.osSonTeklif=d;
  let html='<div class="kart"><h3>📊 '+esc(d.il)+' · '+esc(d.sirket)+'</h3>'+
    row('Dekorasyon, ekipman',tl(d.dekorasyon_donanim))+
    row('Kira / güvence depozitosu',tl(d.depozito))+
    row('İlk ürün ve stok alımı',tl(d.ilk_stok||0))+
    row('Personel hazırlığı',tl(d.personel_hazirlik))+
    row('Ruhsat ve açılış işlemleri',tl(d.izin_ruhsat))+
    row('Toplam açılış yatırımı',tl(d.acilis_maliyeti))+
    row('Kasada korunacak işletme rezervi',tl(d.isletme_rezervi))+
    row('Gerekli şirket kasası',tl(d.gerekli_kasa))+
    row('Mevcut şirket kasası',tl(d.mevcut_kasa));
  if(d.haftalik_ciro!=null){
   html+=row('Haftalık tahmini ciro',tl(d.haftalik_ciro))+
     row('Haftalık toplam maliyet ve vergiler',tl(d.haftalik_gider))+
     row('Haftalık net kâr / zarar',tl(d.haftalik_net))+
     row('Şube yatırımının tahmini geri dönüşü',d.geri_donus_hafta?
       esc(d.geri_donus_hafta)+' oyun haftası':'Kârlılık yok · amortisman hesaplanamıyor');
  }else html+='<p class="alt">Bu sektör için güvenilir şube satış tahmini henüz bulunmuyor.</p>';
  html+=d.yeterli?
    '<p class="alt">Şirket kasası yatırım ve rezerv için yeterli.</p>'+
      btn('Şubeyi bu bütçeyle aç','sirketSubeTeklifiOnayla()','altin'):
    '<p class="alt">Şirket kasasında '+esc(tl(d.eksik))+' eksik bulunuyor. Kişisel paranı şirkete yatırabilirsin.</p>'+
      btn('Şirket kasasına para aktar','sirketKasasiAc('+sid+')','altin');
  html+='</div>';
  div.innerHTML=html;
  div.scrollIntoView({behavior:'smooth',block:'nearest'});
 }catch(e){window.osSonTeklif=null;div.innerHTML='<div class="kart">'+esc(e.message||e)+'</div>';err(e);}
};
window.sirketSubeTeklifiOnayla=async function(){
 try{
  const d=window.osSonTeklif;
  const sid=Number(get('os_sube_sirket')),il=Number(get('os_sube_il'));
  if(!d||Number(d.sirket_id)!==sid||Number(d.il_id)!==il)
   throw Error('Yatırım şartları değişti. Önce tekrar tahmin hesapla.');
  const ok=await approve('Şube açılışını onayla',
    esc(d.il)+' ilinde şube açılacak. Açılış bedeli '+tl(d.acilis_maliyeti)+
    ' şirket kasasından düşecek; '+tl(d.isletme_rezervi)+
    ' işletme rezervi kalacak. Onaylıyor musun?');
  if(!ok)return;
  const r=await rpc('sirket_sube_ac_ilde',{p_sirket:sid,p_il:il});
  window.osSonTeklif=null;toast('Şube açıldı. Şirket kasasından '+tl(r.bedel)+' yatırıldı.');
  await sirketSubeRapor(sid);
 }catch(e){err(e);}
};
window.ortaklikKasayaYatir=async function(){
 try{
  const sid=Number(get('os_yatir_sirket'));
  const raw=get('os_yatir_tutar').trim();
  if(!/^\d+$/.test(raw))throw Error('Tam sayı para tutarı gir.');
  const tutar=Number(raw);
  if(!Number.isSafeInteger(tutar)||tutar<1||tutar>100000000)
   throw Error('1 ile 100 milyon TL arasında geçerli tutar gir.');
  const sec=document.getElementById('os_yatir_sirket');
  const ad=sec?.selectedOptions?.[0]?.textContent||'seçilen şirket';
  if(!await approve('Şirket kasasına para yatır',
    tl(tutar)+' kendi cüzdanından düşülüp '+ad+' kasasına eklenecek. Hisse oranın değişmeyecek. Onaylıyor musun?'))return;
  await rpc('sirket_kasa_yatir',{p_sirket:sid,p_tutar:tutar});
  window.osSeciliSirket=sid;
  toast(tl(tutar)+' şirket kasasına aktarıldı.');
  await ortaklikEkrani();
 }catch(e){err(e);}
};
window.sirketSubeRapor=async function(id){
 yukleniyor('Şube gelir ve giderleri');
 try{
  const d=await rpc('sirket_sube_finans',{p_sirket:Number(id)});
  let html='<div class="kart"><h2>🏬 '+esc(d.ad)+' – Şube ekonomisi</h2>'+
   '<p class="alt">Haftalık tahmini rakamlar: her ilde müşteri talebi, rakipler, çalışanlar, kira, enerji ve satış maliyeti dikkate alınır. Gerçekleşen satışlar değişebilir.</p>'+
   row('Ek şube sayısı',String(d.sube_sayisi))+
   row('Ek şubelerin haftalık cirosu',tl(d.sube_gelir))+
   row('Ek şubelerin haftalık gideri',tl(d.sube_gider))+
   row('Şirket toplam haftalık ciro',tl(d.haftalik_toplam_gelir))+
   row('Şirket toplam haftalık gider',tl(d.haftalik_toplam_gider))+
   row('Tahmini toplam net kâr (vergiler sonrası)',tl(d.haftalik_net))+
   '</div>';
  for(const s of d.subeler||[]){
   html+='<div class="kart"><h3>📍 '+esc(s.il)+' şubesi</h3>'+
    row('Haftalık satış',tl(s.gelir))+
    row('Satış / ürün maliyeti',tl(s.satis_maliyeti))+
    row('Personel',tl(s.personel))+
    row('Kira ve sabit gider',tl(s.kira_enerji))+
    row('Toplam işletme gideri',tl(s.gider))+
    row('Vergi öncesi şube katkısı',tl(s.tahmini_net))+
    row('Tahmini şehir pazar payı','%'+esc(s.pazar_payi))+
    '</div>';
  }
  if(!(d.subeler||[]).length)
   html+='<div class="kart"><p>Şirketin ek şubesi bulunmuyor. Yeni şube açınca buradaki gelir ve giderler hesaplanacak.</p></div>';
  html+='<div class="kart">'+
    btn('Ortaklık merkezine dön','ekranAc(ortaklikEkrani)')+' '+
    btn('Şirket kasasına para yatır','sirketKasasiAc('+Number(d.id)+')','altin')+
    '</div>';
  iskelet('Şube Gelir ve Giderleri',html,{geri:true});
 }catch(e){iskelet('Şube Gelir ve Giderleri','<div class="kart">'+esc(e.message||e)+'</div>',{geri:true});}
};
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
 if(r&&!r.querySelector('.sirket-kasa-menu-btn'))r.insertAdjacentHTML('afterbegin',
  '<button class="btn altin sirket-kasa-menu-btn" onclick="sirketKasasiAc()">💰 Şirket kasasına kendi paramdan yatır</button>');
};
const prevDetail=window.sirketPortfoyDetay;
if(typeof prevDetail==='function')window.sirketPortfoyDetay=async function(){
 await prevDetail.apply(this,arguments);
 const base=document.querySelector('.so-detail');
 if(base&&!document.querySelector('.ortak-merkez-detay'))base.insertAdjacentHTML('afterend',
  '<div class="kart ortak-merkez-detay"><h3>🤝 Ortaklık ve hisse yönetimi</h3>'+
  btn('Ortaklar · Hisseler · Bedelsiz veya ücretli devir','ekranAc(ortaklikEkrani)','altin')+'</div>');
 const pane=document.querySelector('.ortak-merkez-detay');
 if(pane&&!pane.querySelector('.sirket-kasa-detay-btn')){
  const item=arguments[0];const sid=Number(item&&typeof item==='object'?item.id:item)||0;
  pane.insertAdjacentHTML('beforeend','<div class="sirket-kasa-detay-btn">'+
   btn('💰 Kişisel paramdan şirkete aktar','sirketKasasiAc('+sid+')','altin')+
   (sid?btn('📊 Şube gelir/gider raporu','sirketSubeRapor('+sid+')'):'')+'</div>');
 }
};

/* sirket-merkezi-20261023: tek sirket, tek panel */
(function(){
const safe=x=>String(x==null?'':x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money=x=>(Number(x)||0).toLocaleString('tr-TR',{maximumFractionDigits:2})+' ₺';
const kv=(a,b)=>'<div class="kv"><span>'+safe(a)+'</span><b>'+safe(b)+'</b></div>';
const action=(name,fn,color)=>'<button type="button" class="btn '+(color||'ikinci')+'" onclick="'+fn+'">'+safe(name)+'</button>';
const get=id=>document.getElementById(id);
const val=id=>get(id)?.value||'';
const item=(body)=>'<div class="kart" style="margin:10px 0">'+body+'</div>';
const message=e=>toast(typeof hataCevir==='function'?hataCevir(e.message||String(e)):String(e.message||e),true);
const call=(name,args)=>API.rpc(name,args||{});
const ask=(a,b)=>typeof onayla==='function'?onayla(a,b,'Onayla'):Promise.resolve(confirm(b));
const pages=[['genel','Özet'],['para','Kasa / Sermaye'],['faaliyet','Mal / Faaliyet'],['sube','Şubeler'],['insaat','Arsa / İnşaat'],['ortak','Ortaklık'],['finans','Finans']];
function header(s){return '<div class="kart"><h2>'+safe(s.ad)+'</h2><p class="alt">'+safe(s.sektor)+' · Hissen %'+safe(s.benim_pay)+'</p>'+
  kv('Şirket kasası',money(s.kasa))+kv('Kayıtlı sermaye',money(s.sermaye))+
  '<button class="btn ikinci" onclick="ekranAc(sirketlerimMerkezi)">← Şirketlerime dön</button></div>';}
function shortDate(x){return x?new Date(x).toLocaleString('tr-TR'):'—';}
function sectionHeader(title,body){return '<div class="kart"><h3>'+safe(title)+'</h3>'+body+'</div>';}
function openCompany(id,tab){return window.sirketTekSirketEkrani(Number(id),tab||'genel');}
function companyButton(s){
 return '<button type="button" class="sm-company" onclick="sirketTekSirketEkrani('+Number(s.id)+')">'+
 '<span class="sm-company-head">'+safe(s.ad)+' <span style="opacity:.65">›</span></span>'+
 '<span class="alt">'+safe(s.sektor)+' · Payın %'+safe(s.benim_pay)+'</span>'+
 '<span class="sm-company-values"><span>Kasa <b>'+money(s.kasa)+'</b></span><span>Sermaye <b>'+money(s.sermaye)+'</b></span></span></button>';
}
if(!document.getElementById('sm-style')){
 const style=document.createElement('style');style.id='sm-style';
 style.textContent='.sm-company{display:block;width:100%;background:var(--panel2);color:var(--txt);border:1px solid var(--line2);border-radius:15px;text-align:left;padding:16px;margin:10px 0;cursor:pointer}.sm-company-head{display:flex;justify-content:space-between;font-size:19px;font-weight:800;gap:8px}.sm-company .alt{display:block;margin-top:6px}.sm-company-values{display:flex;justify-content:space-between;gap:8px;font-size:13px;margin-top:12px}.sm-company-values b{display:block;font-size:17px}.sm-tabs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px;margin:14px 0}.sm-tabs .btn{width:100%;margin:0;padding:12px 5px;font-size:13px;min-height:45px}.sm-tabs .sm-active{border:2px solid var(--ink2);color:var(--ink2)}.sm-note{font-size:13px;color:var(--txt2);line-height:1.55}.sm-form .alan{margin:12px 0}.sm-project{padding:10px;border-radius:12px;background:var(--panel2);margin:9px 0}.sm-project .btn{margin-top:7px}';
 document.head.appendChild(style);
}
window.sirketlerimMerkezi=async function(){
 if(typeof yukleniyor==='function')yukleniyor('Şirketlerim');
 try {
   const data=await call('ortak_sirket_panel');
   const list=(data.sirketler||[]).slice().sort((a,b)=>String(a.ad).localeCompare(String(b.ad),'tr'));
   let html=sectionHeader('🏢 Şirketlerim','<p class="alt">İşlem yapmak istediğin şirketin üzerine dokun. Kasa, para yatırma, mal alım-satımı, şube ve proje yönetimi artık şirketin kendi ekranında.</p>'+
   (list.length?list.map(companyButton).join(''):'<p class="alt">Henüz şirket ortaklığın yok.</p>'));
   html+=sectionHeader('Yeni şirket ve ortaklık',
    action('＋ Yeni şirket kur','sirketKurulumFormuAc()','altin')+
    action('🤝 Ortaklarla şirket kur / hisse devri','ekranAc(ortaklikEkrani)')+
    action('🧾 Çek Merkezi · çek al/ver/tahsil et','cekMerkeziAc()')+
    action('Tüm şirketleri ve satılıkları gör','sirketVitrinEkrani()'));
   if((data.kuruluslar||[]).length||(data.devirler||[]).length)
    html+=sectionHeader('Bekleyen ortaklık işlemleri',
     kv('Kuruluş davetleri',(data.kuruluslar||[]).length)+kv('Hisse devirleri',(data.devirler||[]).length)+
     action('Davetlerimi gör','ekranAc(ortaklikEkrani)'));
   iskelet('Şirketlerim',html,{geri:true});
 } catch(e){iskelet('Şirketlerim',sectionHeader('Bir hata oluştu','<p>'+safe(e.message||e)+'</p>'),{geri:true});}
};
window.sirketKurulumFormuAc=function(){
 if(typeof previous==='function')return ekranAc(previous);
 return window.sirketlerimMerkezi();
};
window.sirketTekSirketEkrani=async function(id,tab){
 id=Number(id);tab=tab||'genel';
 if(!Number.isSafeInteger(id)||id<1){toast('Geçerli şirket seç.',true);return;}
 yukleniyor('Şirket paneli');
 try {
  const [d,w,locations]=await Promise.all([
   call('ortak_sirket_panel'),
   call('sirket_kasa_bilgi').catch(()=>null),
   call('sirket_yerleri',{p_sirket:id}).catch(()=>null)
  ]);
  const s=(d.sirketler||[]).find(x=>Number(x.id)===id);
  if(!s)throw Error('Bu şirket aktif değil veya ortağı değilsin.');
  const manager=!!locations?.yonetici;
  let html=header(s);
  html+=action('🧾 Bu şirketin çekleri ve çekle ödeme','cekMerkeziAc('+id+')');
  const visible=pages.filter(x=>x[0]!=='insaat'||s.sektor==='insaat');
  html+='<div class="sm-tabs">'+visible.map(p=>'<button class="btn ikinci'+(tab===p[0]?' sm-active':'')+
   '" onclick="sirketTekSirketEkrani('+id+',\''+p[0]+'\')">'+safe(p[1])+'</button>').join('')+'</div>';
  if(tab==='genel'){
    html+=sectionHeader('Şirket yönetim merkezi',
     '<p class="alt">Şirketin tüm işlemleri üstteki bölümlerde. Para yatırmak için başka menüye girmen gerekmiyor.</p>'+
     kv('Şahsi cüzdanın',money(w?.bakiye))+kv('Yönetim yetkisi',manager?'Var':'Ortak olarak görüntüleme')+
     kv('Merkez',locations?.merkez?.il||'—')+kv('Ek şube sayısı',(locations?.subeler||[]).length)+
     action('💰 Şirket kasasına para koy','sirketTekSirketEkrani('+id+',\'para\')','altin')+
     (s.sektor==='insaat'?action('🏗️ Arsa ve inşaatlarım','sirketTekSirketEkrani('+id+',\'insaat\')'):'')+
     action('📦 Mal ve faaliyet işlemleri','sirketTekSirketEkrani('+id+',\'faaliyet\')')+
     action('🏬 Şubelerimi yönet','sirketTekSirketEkrani('+id+',\'sube\')')+
     action('📊 Finans ve hareketler','sirketTekSirketEkrani('+id+',\'finans\')'));
  }else if(tab==='para'){
    const room=Math.max(0,100000000-Number(s.sermaye||0));
    html+=sectionHeader('💰 Cüzdanımdan şirketime para aktar',
      '<p class="sm-note">Para şahsi cüzdanından düşer, sadece bu şirketin kasasına ve kayıtlı sermayesine eklenir. Hisse oranların değişmez; satış geliri veya kâr sayılmaz.</p>'+
      kv('Şahsi cüzdanım',money(w?.bakiye))+kv('Şirket kasası',money(s.kasa))+
      kv('Eklenebilecek azami tutar',money(room))+
      '<div class="alan"><label>Yatırılacak tutar (₺)</label><input type="number" inputmode="numeric" id="sm_para" min="1" max="'+Math.min(room,100000000)+'" step="1" placeholder="Örneğin 500.000"></div>'+
      (room?'<button class="btn altin" id="sm_yatir" onclick="sirketMerkezParaYatir('+id+')">Parayı şirkete aktar</button>':'<p class="alt">Şirket 100 milyon TL sermaye sınırında.</p>')+
      '<p class="sm-note">Kasadan şahsi cüzdana para çekmek bu işlemle mümkün değildir. Kâr dağıtımı ve ortaklık işlemleri ayrı yetkilere tabidir.</p>');
  }else if(tab==='ortak'){
    html+=sectionHeader('Ortaklık ve hisse yönetimi',
     kv('Sana ait pay','%'+s.benim_pay)+
     (s.ortaklar||[]).map(o=>kv(o.kad,'%'+o.pay)).join('')+
     '<p class="sm-note">Yeni ortak, bedelli veya bedelsiz pay devri için ortaklık merkezini kullan.</p>'+
     action('🤝 Bu şirketin hisselerini yönet','sirketOrtaklikAc('+id+')','altin')+
     action('Şirket karnesi ve genel kurul','sirketKarnesiAc('+id+')'));
  }else if(tab==='finans'){
    let f=null,error='';
    try{f=await call('sirket_finans_ozeti',{p_sirket:id});}catch(e){error=e.message||String(e);}
    html+=sectionHeader('Gelir, gider ve kasa raporu',
      (f?(kv('Güncel kasa',money(f.kasa))+kv('Sermaye',money(f.sermaye))+
      kv('Dağıtılabilir kâr',money(f.dagitilabilir_kar))+
      kv('Tahmini haftalık gelir',money(f.tahmini_gelir_min)+' – '+money(f.tahmini_gelir_max))+
      kv('Tahmini haftalık gider',money(f.tahmini_gider_min)+' – '+money(f.tahmini_gider_max))+
      kv('Tahmini ortalama net',money(f.tahmini_ortalama_net))+
      kv('Sonraki hesaplama',shortDate(f.sonraki_hesaplama))+
      '<h3>Kasa hareketleri</h3>'+
      (f.islemler||[]).map(x=>item('<b>'+money(x.net)+'</b><p class="alt">'+safe(x.aciklama)+' · '+shortDate(x.tarih)+'</p>')).join('')):'<p class="alt">'+safe(error)+'</p>')+
      (manager?'<div class="alan"><label>Kasadan dağıtılacak kâr (₺)</label><input id="sm_kar_tutar" type="number" inputmode="numeric" step="1" min="1"></div>'+
        action('Kâr payı dağıt','sirketMerkezKarDagit('+id+')'):'<p class="sm-note">Kâr payı kararı için şirket yönetim yetkisi gerekir.</p>'));
  }else if(tab==='sube'){
    let sf=null;try{sf=await call('sirket_sube_finans',{p_sirket:id});}catch(_){}
    html+=sectionHeader('🏬 Şubeler ve işyerleri',
      kv('Merkez',locations?.merkez?.il||'—')+kv('Ek şube sayısı',(locations?.subeler||[]).length)+
      (locations?.subeler||[]).map(x=>item('<b>'+safe(x.il)+' şubesi</b><p class="alt">Açılış: '+shortDate(x.acilis)+'</p>')).join('')+
      (!locations?.subeler?.length?'<p class="alt">Bu şirketin henüz ek şubesi bulunmuyor.</p>':'')+
      (sf?kv('Toplam haftalık ciro',money(sf.haftalik_toplam_gelir))+
         kv('Toplam haftalık gider',money(sf.haftalik_toplam_gider))+
         kv('Tahmini net',money(sf.haftalik_net))+
         action('Ayrıntılı şube gelir/gider raporu','sirketSubeRapor('+id+')'):'')+
      (manager?'<h3>Yeni şube aç</h3><p class="sm-note">Önce şehrin açılış maliyetini, gerekli işletme rezervini ve beklenen kazancı sorgula. Şube masrafı şirket kasasından düşer.</p>'+
       '<div class="alan"><label>İl seç</label><select id="sm_sube_il">'+cities.map((c,i)=>'<option value="'+(i+1)+'">'+safe(c)+'</option>').join('')+'</select></div>'+
       action('Şube maliyeti ve kâr tahmini','sirketMerkezSubeTeklif('+id+')','altin')+
       '<div id="sm_sube_teklif"></div>':'<p class="sm-note">Yeni şubeyi yalnızca yetkili şirket yöneticisi açabilir.</p>'));
  }else if(tab==='insaat' && s.sektor==='insaat'){
    let cp=null,error='';
    try{cp=await call('sirket_insaat_portfoyu',{p_sirket:id});}catch(e){error=e.message||String(e);}
    const lands=cp?.arsalar||[],projects=cp?.projeler||[];
    html+=sectionHeader('🏗️ Arsa ve inşaat yönetimi',
      '<p class="sm-note">Projeler 81 ilde toplu gösterilir. Arsa bedeli ve yapım maliyeti şirket kasasından karşılanır.</p>'+
      kv('Şirket kasası',money(s.kasa))+
      kv('İnşaata hazır arsa',lands.length)+kv('Toplam proje',projects.length)+
      kv('Devam eden proje',projects.filter(p=>!p.tamamlandi).length)+
      (error?'<p class="alt">'+safe(error)+'</p>':'')+
      (manager?action('Belediyeden yeni arsa al','sirketArsaPazari('+id+','+Number(locations?.merkez?.il_id||34)+')','altin'):'')+
      '<h3>Şirkete ait boş arsalar</h3>'+
      (lands.length?lands.map(a=>item('<b>'+safe(a.il)+' · Arsa #'+Number(a.id)+'</b>'+
         kv('Alan',a.m2+' m²')+kv('İmar kapasitesi',a.kapasite+' bağımsız bölüm')+kv('Alış bedeli',money(a.alis_bedeli)))).join(''):'<p class="alt">Yapılaşmaya hazır boş arsa yok.</p>')+
      (manager&&lands.length?'<h3>Yeni inşaat başlat</h3>'+
       '<div class="alan"><label>Arsa</label><select id="sm_yapi_arsa">'+lands.map(a=>'<option value="'+a.id+'">'+safe(a.il)+' · #'+a.id+' · '+a.kapasite+' bölüm</option>').join('')+'</select></div>'+
       '<div class="alan"><label>Proje adı</label><input id="sm_yapi_ad" maxlength="70" placeholder="Örn. Feniks Konutları"></div>'+
       '<div class="alan"><label>Daire adedi</label><input id="sm_yapi_daire" type="number" inputmode="numeric" min="0" step="1" value="3"></div>'+
       '<div class="alan"><label>Dükkân adedi</label><input id="sm_yapi_dukkan" type="number" inputmode="numeric" min="0" step="1" value="0"></div>'+
       '<p class="sm-note">İmar kapasitesi aşılmaz. İnşaat maliyeti işlem sırasında sunucuda hesaplanır ve şirket kasasından kesilir.</p>'+
       action('Seçili arsada inşaata başla','sirketMerkezInsaatBaslat('+id+')','altin'):'')+
      '<h3>Devam eden ve tamamlanan inşaatlar</h3>'+
      (projects.length?projects.map(p=>item('<b>'+safe(p.ad)+'</b><p class="alt">'+safe(p.il)+' · '+safe(p.tamamlandi?'Tamamlandı':'İnşaat devam ediyor')+'</p>'+
        kv('Daire / Dükkân',p.daire+' / '+p.dukkan)+kv('Yapım maliyeti',money(p.maliyet))+
        kv('Bitiş',shortDate(p.bitis))+kv('Satılan bölüm',p.satilan+' / '+(Number(p.daire)+Number(p.dukkan)))+
        '<details><summary>Bağımsız bölümleri ve satış fiyatlarını göster</summary>'+
        (p.bolumler||[]).map(b=>item('<b>'+safe(b.tur)+' #'+b.sira+'</b>'+
          kv('Durum',b.satildi?'Satıldı':'Satılık')+kv('Fiyat',money(b.fiyat))+
          (!b.satildi&&manager?'<div class="alan"><label>Yeni satış fiyatı (₺)</label><input type="number" id="sm_bolum_'+b.id+'" min="100" step="1" value="'+Number(b.fiyat)+'"></div>'+
           action('Fiyatı güncelle','sirketMerkezBolumFiyat('+id+','+b.id+')'):'')
        )).join('')+'</details>')).join(''):'<p class="alt">Bu şirkete ait başlayan inşaat bulunmuyor.</p>'));
  }else if(tab==='faaliyet'){
    let t=null,error='',npc=null;
     try{t=await call('eko_ticaret_panel');}catch(e){error=e.message||String(e);}
     try{npc=await call('npc_isletme_panel',{p_sirket:id});}catch(_){};
    const company=t?.sirketler?.find(x=>Number(x.id)===id);
    const stock=(t?.stok||[]).filter(x=>Number(x.sirket)===id);
    const production=(t?.uretim||[]).filter(x=>Number(x.sirket)===id);
    const sales=(t?.satislar||[]).filter(x=>Number(x.sirket)===id).slice(0,8);
    const vendors=(t?.tedarikciler||[]).filter(x=>Number(x.sirket)!==id&&Number(x.adet)>0);
    window.smTedarikciler=vendors;
    const factory=company?.tur==='fabrika',store=company?.tur==='magaza';
    const products=(t?.urunler||[]).filter(x=>x.grup===company?.grup);
    html+=sectionHeader('📦 Mal, stok ve işletme faaliyetleri',
     '<p class="sm-note">Alış, üretim, stok fiyatı, satış ve sektör kararları bu şirkete aittir; başka şirketin kasası kullanılmaz.</p>'+
     kv('İşletme türü',company?.tur||s.sektor)+
     (error?'<p>'+safe(error)+'</p>':'')+
     '<h3>Mevcut stok</h3>'+
     (stock.length?stock.map((x,k)=>item('<b>'+safe(x.urun)+'</b>'+kv('Adet',x.adet)+kv('Alış/üretim birim maliyeti',money(x.maliyet))+
       '<div class="alan"><label>Satış fiyatı (₺)</label><input id="sm_fiyat_'+k+'" type="number" step="1" min="1" value="'+Number(x.fiyat||0)+'"></div>'+
       (manager?action('Satış fiyatını kaydet','sirketMerkezStokFiyat('+id+','+k+','+JSON.stringify(String(x.urun))+')'):''))).join(''):
       '<p class="alt">Bu şirket için listelenen stok bulunmuyor.</p>')+
     (factory&&manager?'<h3>Fabrika üretimi</h3>'+
      '<div class="alan"><label>Ürün</label><select id="sm_urun">'+products.map(p=>'<option value="'+safe(p.kod)+'">'+safe(p.ad)+' · Maliyet '+money(p.maliyet)+'</option>').join('')+'</select></div>'+
      '<div class="alan"><label>Üretilecek adet</label><input id="sm_adet" type="number" min="1" step="1" value="10"></div>'+
      action('Üretim emri ver','sirketMerkezTicaretYap('+id+',\'uret\')','altin'):'')+
     (store&&manager?'<h3>Mal satın al / Toptan tedarik</h3>'+
      '<div class="alan"><label>Satıcı ve ürün</label><select id="sm_satici">'+vendors.map((v,k)=>'<option value="'+k+'">'+safe(v.ad)+' · '+safe(v.urun)+' · '+v.adet+' adet · '+money(v.fiyat)+'/adet</option>').join('')+'</select></div>'+
      '<div class="alan"><label>Alınacak adet</label><input id="sm_adet" type="number" min="1" step="1" value="1"></div>'+
      (vendors.length?action('Şirket kasasıyla mal al','sirketMerkezTicaretYap('+id+',\'toptan\')','altin'):'<p class="alt">Şu an stoklu tedarikçi bulunmuyor.</p>'):'')+
     '<h3>Üretim emirleri</h3>'+
     (production.length?production.slice(0,8).map(p=>item(safe(p.urun)+' · '+p.adet+' adet'+
       kv('Durum',p.tamam?'Tamamlandı':p.hazir?'Hazır':'Üretimde')+
       kv('Maliyet',money(p.maliyet)))).join(''):'<p class="alt">Bekleyen üretim emri yok.</p>')+
     '<h3>Gerçekleşen satışlar</h3>'+
     (sales.length?sales.map(x=>item(safe(x.urun)+' · '+x.adet+' adet'+kv('Ciro',money(x.ciro))+
       kv('Net kâr',money(x.kar))+'<p class="alt">'+shortDate(x.zaman)+'</p>')).join(''):'<p class="alt">Henüz kayıtlı satış yok.</p>')+
     ((npc?.urunler||[]).length?
        '<h3>🛍️ İşletme ürünleri ve mağaza stoğu</h3><p class="sm-note">Şirket kasasıyla mal al. Satış fiyatını belirle; oyun müşterileri stoktan otomatik alım yapar.</p>'+
        (npc.urunler||[]).map((u,j)=>item('<b>'+safe(u.ad)+'</b>'+
           kv('Stok',u.stok+' adet')+kv('Alış fiyatı',money(u.alis))+kv('Satış fiyatı',money(u.fiyat))+
           (manager?'<div class="alan"><label>Mal alım adedi</label><input id="sm_npc_adet_'+j+'" type="number" min="1" max="10000" step="1" value="1"></div>'+
           action('Şirket kasasından mal al','sirketMerkezNpcIslem('+id+',\'al\','+JSON.stringify(String(u.kod))+','+j+')','altin')+
           '<div class="alan"><label>Satış fiyatı</label><input id="sm_npc_fiyat_'+j+'" type="number" min=".01" step=".01" value="'+Number(u.fiyat)+'"></div>'+
           action('Fiyatı değiştir','sirketMerkezNpcIslem('+id+',\'fiyat\','+JSON.stringify(String(u.kod))+','+j+')'):'')
        )).join('')+
        '<h3>Son 7 gün NPC satışları</h3>'+kv('Toplam ciro',money(npc.son_7_gun?.ciro))+
        kv('Satılan ürün adedi',npc.son_7_gun?.satilan||0):'')+
      action('Fiyat / kalite / rekabet yönetimi','sirketMerkezPazarAc('+id+')')+
     action('İhaleler','ekranAc(ihaleEkrani)'));
  }
  iskelet(s.ad,html,{geri:true});
 }catch(e){iskelet('Şirket paneli',sectionHeader('Şirket açılamadı','<p>'+safe(e.message||e)+'</p>'+
   action('Şirketlerime dön','ekranAc(sirketlerimMerkezi)')),{geri:true});}
};
window.sirketMerkezParaYatir=async function(id){
 const raw=val('sm_para').trim(),tutar=Number(raw),b=get('sm_yatir');
 if(!/^\d+$/.test(raw)||!Number.isSafeInteger(tutar)||tutar<1||tutar>100000000){toast('Geçerli, pozitif bir tam sayı gir.',true);return;}
 if(!await ask('Şirket kasasına para aktar',money(tutar)+' şahsi cüzdanından düşüp seçili şirketin kasasına eklenecek. Hisse oranın değişmeyecek.'))return;
 if(b)b.disabled=true;
 try{await call('sirket_kasa_yatir',{p_sirket:id,p_tutar:tutar});toast(money(tutar)+' şirket kasasına yatırıldı.');await openCompany(id,'para');}
 catch(e){message(e);if(b)b.disabled=false;}
};
window.sirketMerkezKarDagit=async function(id){
 const tutar=Number(val('sm_kar_tutar'));
 if(!Number.isSafeInteger(tutar)||tutar<=0){toast('Pozitif tutar gir.',true);return;}
 if(!await ask('Kâr dağıtımı',money(tutar)+' dağıtılabilir kârın ortaklara dağıtılmasını onaylıyor musun?'))return;
 try{await call('sirket_kar_payi',{p_sirket:id,p_tutar:tutar});toast('Kâr payı dağıtıldı.');await openCompany(id,'finans');}catch(e){message(e);}
};
window.sirketOrtaklikAc=function(id){window.osSeciliSirket=id;return ekranAc(ortaklikEkrani);};
window.sirketMerkezPazarAc=async function(id){
 try{await call('pazar_detay',{p_sirket:id});return ekranAc(()=>pazarDetayEkrani(id));}
 catch(e){toast('Bu sektörün pazar karar ekranı yok; stok ve finans işlemlerini buradan yönetebilirsin.',true);}
};
window.sirketMerkezSubeTeklif=async function(id){
 const il=Number(val('sm_sube_il')),container=get('sm_sube_teklif');
 if(!container)return;
 container.innerHTML='<p class="alt">Maliyet hesaplanıyor…</p>';
 try{
  const d=await call('sirket_sube_teklif',{p_sirket:id,p_il:il});
  container.innerHTML=item('<b>'+safe(d.il)+' şube yatırım planı</b>'+
   kv('Açılış maliyeti',money(d.acilis_maliyeti))+
   kv('Korunması gereken işletme rezervi',money(d.isletme_rezervi))+
   kv('Gerekli toplam kasa',money(d.gerekli_kasa))+
   kv('Mevcut kasa',money(d.mevcut_kasa))+
   (d.haftalik_ciro==null?'':kv('Beklenen haftalık ciro',money(d.haftalik_ciro)))+
   (d.haftalik_net==null?'':kv('Beklenen haftalık net',money(d.haftalik_net)))+
   (Number(d.eksik)>0?
     '<p class="alt">Eksik kasa: '+money(d.eksik)+'</p>'+action('Önce şirkete para aktar','sirketTekSirketEkrani('+id+',\'para\')','altin'):
     action('Bu ilde şubeyi aç','sirketMerkezSubeAc('+id+','+il+')','altin')));
 }catch(e){container.innerHTML=item('<p>'+safe(e.message||e)+'</p>');}
};
window.sirketMerkezSubeAc=async function(id,il){
 try{
  const d=await call('sirket_sube_teklif',{p_sirket:id,p_il:il});
  if(!await ask('Şube aç',safe(d.il)+' için '+money(d.acilis_maliyeti)+' şirket kasasından ödenecek. Onaylıyor musun?'))return;
  await call('sirket_sube_ac_ilde',{p_sirket:id,p_il:il});
  toast('Yeni şube açıldı.');await openCompany(id,'sube');
 }catch(e){message(e);}
};
window.sirketArsaPazari=async function(id,il){
 id=Number(id);il=Number(il)||34;
 yukleniyor('Şirket arsa pazarı');
 try{
  const [p,d]=await Promise.all([call('eko_emlak_panel',{p_il:il}),call('ortak_sirket_panel')]);
  if(!(d.sirketler||[]).some(x=>Number(x.id)===id&&x.sektor==='insaat'))throw Error('Bu müteahhitlik şirketinin ortağı değilsin.');
  const html=sectionHeader('🏗️ Şirkete arsa al',
   '<p class="sm-note">Seçtiğin arsayı şahsi cüzdanına değil, doğrudan bu şirketin adına satın alırsın. Para şirket kasasından ödenir.</p>'+
   '<div class="alan"><label>İl</label><select id="sm_arsa_il" onchange="sirketArsaPazari('+id+',Number(this.value))">'+
   cities.map((c,i)=>'<option value="'+(i+1)+'"'+(i+1===il?' selected':'')+'>'+safe(c)+'</option>').join('')+'</select></div>'+
   (p.arsalar||[]).filter(a=>a.durum==='satilik').map(a=>item('<b>'+safe(p.il_adi)+' · '+a.kademe+' bölümlük arsa</b>'+
    kv('Alan',a.m2+' m²')+kv('Arsa fiyatı',money(a.fiyat))+
    action('Şirket kasasından arsayı al','sirketMerkezArsaAl('+id+','+a.id+','+Number(a.fiyat)+')','altin'))).join('')+
   (!(p.arsalar||[]).some(a=>a.durum==='satilik')?'<p class="alt">Bu ilde belediye arsa stoğu tükenmiş.</p>':'')+
   action('İnşaat şirketine dön','sirketTekSirketEkrani('+id+',\'insaat\')'));
  iskelet('Arsa satın al',html,{geri:true});
 }catch(e){iskelet('Arsa satın al',item('<p>'+safe(e.message||e)+'</p>'),{geri:true});}
};
window.sirketMerkezArsaAl=async function(id,aid,fiyat){
 if(!await ask('Şirket adına arsa al',money(fiyat)+' şirket kasasından düşülerek arsa şirket adına alınacak. Onaylıyor musun?'))return;
 try{await call('eko_emlak_islem',{p_eylem:'arsa_al',p_veri:{arsa:aid,sirket:id}});toast('Arsa şirket adına alındı.');await openCompany(id,'insaat');}
 catch(e){message(e);}
};
window.sirketMerkezInsaatBaslat=async function(id){
 const arsa=Number(val('sm_yapi_arsa')),ad=val('sm_yapi_ad').trim(),daire=Number(val('sm_yapi_daire')),dukkan=Number(val('sm_yapi_dukkan'));
 if(!arsa||!ad||ad.length>70||!Number.isSafeInteger(daire)||!Number.isSafeInteger(dukkan)||daire<0||dukkan<0||daire+dukkan<1){toast('Arsa, proje adı, daire ve dükkân adetlerini kontrol et.',true);return;}
 if(!await ask('İnşaatı başlat',ad+' için '+daire+' daire, '+dukkan+' dükkân yapılacak. Sunucunun hesapladığı yapım maliyeti şirket kasasından alınacak. Onaylıyor musun?'))return;
 try{await call('eko_emlak_islem',{p_eylem:'insaata_basla',p_veri:{arsa:arsa,ad:ad,daire:daire,dukkan:dukkan}});toast('İnşaat projesi başlatıldı.');await openCompany(id,'insaat');}catch(e){message(e);}
};
window.sirketMerkezBolumFiyat=async function(id,bolum){
 const tutar=Number(val('sm_bolum_'+bolum));
 if(!Number.isSafeInteger(tutar)||tutar<100||tutar>1000000000){toast('100 - 1 milyar TL arasında fiyat gir.',true);return;}
 try{await call('eko_emlak_islem',{p_eylem:'fiyat_belirle',p_veri:{bolum:bolum,tutar:tutar}});toast('Satış fiyatı güncellendi.');await openCompany(id,'insaat');}
 catch(e){message(e);}
};
window.sirketMerkezStokFiyat=async function(id,index,urun){
 const tutar=Number(val('sm_fiyat_'+index));
 if(!Number.isSafeInteger(tutar)||tutar<1){toast('Geçerli satış fiyatı gir.',true);return;}
 try{await call('eko_ticaret_islem',{p_eylem:'fiyat',p_veri:{sirket:id,urun:urun,tutar:tutar}});toast('Ürün satış fiyatı güncellendi.');await openCompany(id,'faaliyet');}catch(e){message(e);}
};
window.sirketMerkezTicaretYap=async function(id,eylem){
 const adet=Number(val('sm_adet'));
 if(!Number.isSafeInteger(adet)||adet<1){toast('Geçerli adet gir.',true);return;}
 let data={sirket:id,adet:adet};
 if(eylem==='uret')data.urun=val('sm_urun');
 else if(eylem==='toptan'){
  const x=(window.smTedarikciler||[])[Number(val('sm_satici'))];
  if(!x){toast('Satıcı seç.',true);return;}
  data.hedef=Number(x.sirket);data.urun=x.urun;
 }else return;
 if(!await ask(eylem==='uret'?'Üretim emri':'Toptan mal satın al',
  adet+' adet '+safe(data.urun)+' için şirket kasasından ücret alınacak. Onaylıyor musun?'))return;
 try{await call('eko_ticaret_islem',{p_eylem:eylem,p_veri:data});toast(eylem==='uret'?'Üretim başlatıldı.':'Ürünler şirket stoğuna alındı.');await openCompany(id,'faaliyet');}
 catch(e){message(e);}
};
// Eski, genel şirket ekranlarından bu tekil yönetim paneline ulaş.
window.sirketMerkezNpcIslem=async function(id,eylem,urun,index){
 if(eylem!=='al'&&eylem!=='fiyat')return;
 const p={p_eylem:eylem,p_sirket:Number(id),p_urun:String(urun)};
 if(eylem==='al'){
  const adet=Number(val('sm_npc_adet_'+index));
  if(!Number.isSafeInteger(adet)||adet<1||adet>10000){toast('1–10.000 arasında adet gir.',true);return;}
  p.p_adet=adet;
  if(!await ask('Şirket kasasından mal al',adet+' adet ürün şirket kasasından satın alınacak. Onaylıyor musun?'))return;
 }else{
  const fiyat=Number(val('sm_npc_fiyat_'+index));
  if(!Number.isFinite(fiyat)||fiyat<=0||Math.round(fiyat*100)/100!==fiyat){toast('İki ondalıklı satış fiyatı gir.',true);return;}
  p.p_fiyat=fiyat;
 }
 try{await call('npc_isletme_islem',p);toast(eylem==='al'?'Ürün stoğa alındı.':'Satış fiyatı güncellendi.');await openCompany(id,'faaliyet');}
 catch(e){message(e);}
};
// Tek merkez: eski ekonomi/portfoy menulerinin yonetim islevi her zaman sirket secimine gider.
window.sirketYonetimEkrani=function(){return window.sirketlerimMerkezi();};
window.sirketYonetimMerkeziAc=function(id){return id?openCompany(id,'genel'):window.sirketlerimMerkezi();};
// Eski ekranlarda butona basmak veya kartin kendisine dokunmak ayni sirketi acar.
document.addEventListener('click',function(event){
 const node=event.target.closest('button,a,[role="button"],.kart');
 if(!node || node.closest('.sm-company,.sm-tabs'))return;
 const label=(node.textContent||'').trim().toLocaleLowerCase('tr');
 const legacy=node.closest('.so-firma');
 if(legacy){
   const m=legacy.innerHTML.match(/(?:sirketPortfoyDetay|sirketTekSirketEkrani|sirketKasasiAc)\\((\\d+)\\)/);
   if(m && (node===legacy || /detaylarini ac|detaylarını aç|sirketin detay|şirketin detay|sirket yonet|şirket yönet|karne/.test(label))){
      event.preventDefault();event.stopImmediatePropagation();openCompany(Number(m[1]),'genel');return;
   }
 }
 // Mevcut genel ekranlarin ortaklik menusu haric eski 'sirketlerim' girisini sadeleştir.
 if(/^(şirketlerim ve şirket kur|şirketlerim ve şirket kur ›|tüm şirketleri gör)$/.test(label)){
    event.preventDefault();event.stopImmediatePropagation();window.sirketlerimMerkezi();
 }
},true);
window.sirketKasasiAc=function(id){return id?openCompany(id,'para'):window.sirketlerimMerkezi();};
window.sirketPortfoyDetay=function(id){return openCompany(id&&typeof id==='object'?id.id:id,'genel');};
// Eski portföy kutusunda herhangi bir yere dokunmak şirketi açsın.
document.addEventListener('click',function(ev){
 if(ev.target.closest('button,a,input,select,textarea,label,summary,details'))return;
 const card=ev.target.closest('.so-firma');
 if(!card)return;
 const match=card.innerHTML.match(/sirketPortfoyDetay\((\d+)\)/);
 if(!match)return;
 ev.preventDefault();ev.stopImmediatePropagation();
 openCompany(Number(match[1]),'genel');
},true);
})();

})();

;(function(){
 if(document.querySelector('script[data-so-cek]'))return;
 var s=document.createElement('script');s.src='cek_sistemi.js?v=20261023a';s.setAttribute('data-so-cek','1');
 document.head.appendChild(s);
})();
