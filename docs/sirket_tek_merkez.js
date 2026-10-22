/* sirket-merkezi-20261023: tek sirket, tek panel */
(function(){
'use strict';
if(window.SIRKET_TEK_MERKEZ_20261023)return;
window.SIRKET_TEK_MERKEZ_20261023=true;
const previous=window.sirketEskiYonetimEkrani||window.sirketYonetimEkrani;
const cities='Adana,Adıyaman,Afyonkarahisar,Ağrı,Amasya,Ankara,Antalya,Artvin,Aydın,Balıkesir,Bilecik,Bingöl,Bitlis,Bolu,Burdur,Bursa,Çanakkale,Çankırı,Çorum,Denizli,Diyarbakır,Edirne,Elazığ,Erzincan,Erzurum,Eskişehir,Gaziantep,Giresun,Gümüşhane,Hakkâri,Hatay,Isparta,Mersin,İstanbul,İzmir,Kars,Kastamonu,Kayseri,Kırklareli,Kırşehir,Kocaeli,Konya,Kütahya,Malatya,Manisa,Kahramanmaraş,Mardin,Muğla,Muş,Nevşehir,Niğde,Ordu,Rize,Sakarya,Samsun,Siirt,Sinop,Sivas,Tekirdağ,Tokat,Trabzon,Tunceli,Şanlıurfa,Uşak,Van,Yozgat,Zonguldak,Aksaray,Bayburt,Karaman,Kırıkkale,Batman,Şırnak,Bartın,Ardahan,Iğdır,Yalova,Karabük,Kilis,Osmaniye,Düzce'.split(',');
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
    action('Tüm şirketleri ve satılıkları gör','sirketVitrinEkrani()'));
   if((data.kuruluslar||[]).length||(data.devirler||[]).length)
    html+=sectionHeader('Bekleyen ortaklık işlemleri',
     kv('Kuruluş davetleri',(data.kuruluslar||[]).length)+kv('Hisse devirleri',(data.devirler||[]).length)+
     action('Davetlerimi gör','ekranAc(ortaklikEkrani)'));
   iskelet('Şirketlerim',html,{geri:true});
 } catch(e){iskelet('Şirketlerim',sectionHeader('Bir hata oluştu','<p>'+safe(e.message||e)+'</p>'),{geri:true});}
};
window.sirketKurulumFormuAc=function(){
 if(typeof window.sirketTumTurKur==='function')return window.sirketTumTurKur();
 if(typeof ekranAc==='function')return ekranAc(previous);
 return previous();
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
       '<div class="alan"><label>Arsa</label><select id="sm_yapi_arsa" onchange="sirketMerkezInsaatTeklif('+id+')">'+lands.map(a=>'<option value="'+a.id+'">'+safe(a.il)+' · #'+a.id+' · '+a.kapasite+' bölüm</option>').join('')+'</select></div>'+
       '<div class="alan"><label>Proje adı</label><input id="sm_yapi_ad" maxlength="70" placeholder="Örn. Feniks Konutları"></div>'+
       '<div class="alan"><label>Daire adedi</label><input id="sm_yapi_daire" type="number" inputmode="numeric" min="0" step="1" value="3" oninput="sirketMerkezInsaatTeklif('+id+')"></div>'+
       '<div class="alan"><label>Dükkân adedi</label><input id="sm_yapi_dukkan" type="number" inputmode="numeric" min="0" step="1" value="0" oninput="sirketMerkezInsaatTeklif('+id+')"></div>'+
       '<p class="sm-note">Daire ve dükkân sayısı değiştikçe kesin yapım bedeli sunucudan hesaplanır. Arsa alım bedeli tekrar ödenmez.</p>'+'<div id="sm_yapi_teklif" aria-live="polite"><p class="alt">Yapım maliyeti hesaplanıyor…</p></div>'+
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
       (manager?action('Satış fiyatını kaydet','sirketMerkezStokFiyat('+id+','+k+','+JSON.stringify(String(x.urun)).replace(/"/g,'&quot;')+')'):''))).join(''):
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
        '<h3>🛍️ İşletme ürünleri ve mağaza stoğu</h3><p class="sm-note">Şirket kasasıyla ürün al, satış fiyatını belirle. Oyun müşterileri stoktan otomatik satın alır.</p>'+
        (npc.urunler||[]).map((u,j)=>item('<b>'+safe(u.ad)+'</b>'+kv('Stok',u.stok+' adet')+
          kv('Alış fiyatı',money(u.alis))+kv('Satış fiyatı',money(u.fiyat))+
          (manager?'<div class="alan"><label>Mal alım adedi</label><input id="sm_npc_adet_'+j+'" type="number" min="1" max="10000" step="1" value="1"></div>'+
          action('Şirket kasasından mal al','sirketMerkezNpcIslem('+id+',\'al\','+safe(JSON.stringify(String(u.kod)))+','+j+')','altin')+
          '<div class="alan"><label>Satış fiyatı</label><input id="sm_npc_fiyat_'+j+'" type="number" min=".01" step=".01" value="'+Number(u.fiyat)+'"></div>'+
          action('Fiyatı değiştir','sirketMerkezNpcIslem('+id+',\'fiyat\','+safe(JSON.stringify(String(u.kod)))+','+j+')'):'')
        )).join('')+'<h3>NPC satış özeti</h3>'+kv('Son 7 gün ciro',money(npc.son_7_gun?.ciro))+
         kv('Satılan adet',npc.son_7_gun?.satilan||0):'')+
       (factory&&manager?stock.filter(x=>/^[a-z0-9_]+$/.test(String(x.urun))).map(x=>
      action('Kendi mağazama '+x.urun+' sat',"sirketToptanAlModal("+id+",'"+x.urun+"',0)")).join(''):'')+
     (store&&manager?(company?.kategori==='kahve'||company?.kategori==='fastfood'?
      action('Mutfakta ürün hazırlama','sirketPortfoyMutfak('+id+')','altin'):
      action('Gelişmiş toptan alış ve satış','sirketPortfoyTedarik('+id+')','altin')):'')+
     (company?.tur==='sigorta'?action('Sigorta poliçeleri ve hasarlar','ekranAc(sigortaIsletmeEkrani)','altin'):'')+
     (['akaryakit','yapi_market','elektronik_magaza','tekstil_magaza','mobilya_magaza','oto_galeri'].includes(s.sektor)?
      action('Stok al, NPC müşteriye sat','ekranAc(()=>npcIsletmeEkrani('+id+'))','altin'):'')+
     (s.sektor==='banka'?action('Mevduat ve kredi yönetimi','ekranAc(oyuncuBankaEkrani)'):'')+
     (s.sektor==='ajans'?action('Reklam ve anket yönetimi','ekranAc(()=>ajansYonetimEkrani('+id+'))'):'')+
     action('Fiyat / kalite / rekabet yönetimi','sirketMerkezPazarAc('+id+')')+
     action('İhaleler','ekranAc(ihaleEkrani)'));
  }
  iskelet(s.ad,html,{geri:true});
  if(tab==='insaat'&&s.sektor==='insaat'&&manager&&get('sm_yapi_teklif')){
   Promise.resolve().then(()=>window.sirketMerkezInsaatTeklif(id));
  }
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
let smInsaatTeklifSeri=0;
function smInsaatSecim(){
 return {arsa:Number(val('sm_yapi_arsa')),daire:Number(val('sm_yapi_daire')),dukkan:Number(val('sm_yapi_dukkan'))};
}
function smInsaatSecimGecerli(x){
 return x.arsa>0&&Number.isSafeInteger(x.daire)&&Number.isSafeInteger(x.dukkan)
  &&x.daire>=0&&x.dukkan>=0&&x.daire+x.dukkan>=1;
}
function smInsaatTeklifEkrani(id,d){
 const target=get('sm_yapi_teklif');
 if(!target)return;
 if(!d.gecerli){target.innerHTML=item('<p class="alt" style="color:var(--warn,#efb25b)">'+safe(d.hata||'İmar kapasitesine uygun daire ve dükkân sayıları seç.')+'</p>');return;}
 target.innerHTML=item('<h4>🏗️ İnşaat maliyeti, ruhsat ve finansman</h4>'+
   kv('Daire yapım gideri',money(d.daire_maliyeti))+
   kv('Dükkân yapım gideri',money(d.dukkan_maliyeti))+
   kv('Toplam inşaat maliyeti',money(d.toplam_maliyet))+
   kv((d.belediye||'Belediye')+' ruhsat harcı',money(d.ruhsat_harci))+
   kv('İnşaat + ruhsat toplam ödeme',money(d.toplam_odeme))+
   kv('Şirket kasasındaki para',money(d.mevcut_kasa))+
   (d.uygun?kv('İnşaattan sonra kalan para',money(d.kalan_kasa)):
    '<p class="sm-note" style="color:var(--warn,#efb25b)"><b>İnşaat ve ruhsat için kasa yetersiz. Eksik: '+money(d.eksik)+'</b></p>'+
    action('Eksik tutar için şirkete para yatır','sirketTekSirketEkrani('+id+',\'para\')','altin'))+
   kv('Tahmini yapım süresi',d.sure_saat+' saat')+
   '<p class="sm-note">Arsa için ödenmiş '+money(d.arsa_alis_bedeli)+
   ' tekrar ödenmez. <b>Onayla ve inşaata başla</b> dediğinde ruhsat harcı şirket kasasından '+
   safe(d.belediye||'ilgili belediye')+' Belediyesi kasasına aktarılır, inşaat otomatik başlar. '+
   'Ruhsat Merkezi üzerinden ayrıca başvuru yapman gerekmez.</p>');
}
window.sirketMerkezInsaatTeklif=async function(id){
 const target=get('sm_yapi_teklif');if(!target)return null;
 const x=smInsaatSecim(),seq=++smInsaatTeklifSeri;
 if(!smInsaatSecimGecerli(x)){
  target.innerHTML='<p class="alt">Maliyet için en az 1 daire veya dükkân seç; adetler sıfır ya da pozitif tam sayı olmalı.</p>';return null;
 }
 target.innerHTML='<p class="alt">İnşaat ve ruhsat maliyeti hesaplanıyor…</p>';
 try{
  const d=await call('sirket_insaat_ruhsat_teklif',{p_sirket:id,p_arsa:x.arsa,p_daire:x.daire,p_dukkan:x.dukkan});
  if(seq!==smInsaatTeklifSeri||get('sm_yapi_teklif')!==target)return null;
  smInsaatTeklifEkrani(id,d);return d;
 }catch(e){
  if(seq===smInsaatTeklifSeri&&get('sm_yapi_teklif')===target)
   target.innerHTML=item('<p class="alt">Maliyet hesaplanamadı: '+safe(e.message||e)+'</p>');
  return null;
 }
};
window.sirketMerkezInsaatBaslat=async function(id){
 const x=smInsaatSecim(),ad=val('sm_yapi_ad').trim();
 if(!smInsaatSecimGecerli(x)||!ad||ad.length>70){
  toast('Arsa, proje adı, daire ve dükkân adetlerini kontrol et.',true);return;
 }
 const btn=[...document.querySelectorAll('button')].find(b=>b.getAttribute('onclick')==='sirketMerkezInsaatBaslat('+Number(id)+')');
 if(btn?.disabled)return;
 if(btn)btn.disabled=true;
 try{
  // Değişen tarifeyi ve kasayı işlemin öncesinde tekrar kontrol et.
  const d=await call('sirket_insaat_ruhsat_teklif',{p_sirket:id,p_arsa:x.arsa,p_daire:x.daire,p_dukkan:x.dukkan});
  smInsaatTeklifEkrani(id,d);
  if(!d.gecerli){toast(d.hata||'Arsanın imar kapasitesi aşılıyor.',true);return;}
  if(!d.uygun){
   toast('İnşaat '+money(d.toplam_maliyet)+' + ruhsat '+money(d.ruhsat_harci)+
    '. Toplam '+money(d.toplam_odeme)+'; şirket kasasında '+money(d.mevcut_kasa)+
    ' var, '+money(d.eksik)+' eksik.',true);
   return;
  }
  if(Number(val('sm_yapi_arsa'))!==x.arsa||Number(val('sm_yapi_daire'))!==x.daire||
    Number(val('sm_yapi_dukkan'))!==x.dukkan||val('sm_yapi_ad').trim()!==ad){
   toast('Proje bilgileri değişti. Yeni maliyeti kontrol et.',true);return;
  }
  const messageText=ad+' · '+x.daire+' daire, '+x.dukkan+' dükkân\n'+
   'İnşaat maliyeti: '+money(d.toplam_maliyet)+'\n'+
   safe(d.belediye||'Belediye')+' ruhsat harcı: '+money(d.ruhsat_harci)+'\n'+
   'Toplam şirket kasasından çıkacak: '+money(d.toplam_odeme)+'\n'+
   'Kasada kalan: '+money(d.kalan_kasa)+'\n'+
   'Ruhsat harcı belediye kasasına aktarılacak ve inşaat otomatik başlayacak. Onaylıyor musun?';
  const ok=typeof onayla==='function'
    ?await onayla('Ruhsatı öde ve inşaata başla',messageText,'Onayla ve inşaata başla')
    :confirm(messageText);
  if(!ok)return;
  const sonuc=await call('sirket_insaat_ruhsatli_baslat',{
    p_sirket:id,p_arsa:x.arsa,p_ad:ad,p_daire:x.daire,p_dukkan:x.dukkan,
    p_beklenen_maliyet:Number(d.toplam_maliyet),p_beklenen_ruhsat:Number(d.ruhsat_harci)
  });
  toast('İnşaat başladı. '+money(sonuc.ruhsat_harci)+' ruhsat harcı '+safe(sonuc.belediye||'ilgili')+' Belediyesi kasasına aktarıldı.');
  await openCompany(id,'insaat');
 }catch(e){message(e);}
 finally{if(btn)btn.disabled=false;}
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
 if(!['al','fiyat'].includes(eylem))return;
 const p={p_eylem:eylem,p_sirket:Number(id),p_urun:String(urun)};
 if(eylem==='al'){
  const adet=Number(val('sm_npc_adet_'+index));
  if(!Number.isSafeInteger(adet)||adet<1||adet>10000){toast('1-10.000 arasında adet gir.',true);return;}
  p.p_adet=adet;
  if(!await ask('Şirket kasasından mal al',adet+' adet ürün şirket kasasından alınacak. Onaylıyor musun?'))return;
 }else{
  const fiyat=Number(val('sm_npc_fiyat_'+index));
  if(!Number.isFinite(fiyat)||fiyat<=0||Math.round(fiyat*100)/100!==fiyat){toast('Geçerli satış fiyatı gir.',true);return;}
  p.p_fiyat=fiyat;
 }
 try{await call('npc_isletme_islem',p);toast(eylem==='al'?'Ürün stoğa alındı.':'Satış fiyatı güncellendi.');await openCompany(id,'faaliyet');}
 catch(e){message(e);}
};
window.sirketYonetimEkrani=function(){return window.sirketlerimMerkezi();};
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
