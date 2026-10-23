/* Secim Online - 23 Ekim 2026: Bankacilik, cek defteri ve onayli karma ticaret */
(function(){
'use strict';
if(window.CEK_BANKA_MERKEZI_V1)return;
window.CEK_BANKA_MERKEZI_V1=true;
var style=document.getElementById('cek-merkezi-kontrast');
if(!style){
 style=document.createElement('style');style.id='cek-merkezi-kontrast';
 style.textContent=[
  '.cek-bank-ui .btn{color:#f7f9ff!important;-webkit-text-fill-color:#f7f9ff!important;opacity:1!important;font-weight:650!important;}',
  '.cek-bank-ui .btn.altin{background:#33477d!important;border:1px solid #7791db!important;color:#ffffff!important;-webkit-text-fill-color:#ffffff!important;}',
  '.cek-bank-ui .kart .kv b{color:#fff!important;-webkit-text-fill-color:#fff!important;}'
 ].join('');
 document.head.appendChild(style);
}

var CACHE={panel:null,teklifler:[],toptan:[],ek:null,iptaller:[],sirket:null};
var esc=function(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});};
var para=function(v){return Number(v||0).toLocaleString('tr-TR',{maximumFractionDigits:2})+' ₺';};
var tarih=function(v){if(!v)return '—';var d=new Date(String(v).length===10?String(v)+'T12:00:00':v);return isNaN(d.getTime())?esc(v):d.toLocaleDateString('tr-TR');};
var buton=function(ad,js,cls){return '<button type="button" class="btn '+(cls||'ikinci')+'" onclick="'+esc(js)+'">'+esc(ad)+'</button>';};
var satir=function(label,val){return '<div class="kv"><span>'+esc(label)+'</span><b>'+esc(val)+'</b></div>';};
var kart=function(title,html){return '<section class="kart"><h2>'+esc(title)+'</h2>'+html+'</section>';};
var hata=function(err){toast(typeof hataCevir==='function'?hataCevir(err.message||String(err)):(err.message||String(err)),true);};
var kim=function(id){return Number(id)||0;};
function yenile(){CACHE.panel=null;return window.cekMerkeziEkrani();}
function kisaDurum(c){var s={aktif:'Dolaşımda',odendi:'Ödendi',iade:'İade edildi',karsiliksiz:'Karşılıksız',bekliyor:'Satıcının onayında',kabul:'Kabul edildi',red:'Reddedildi',iptal:'İptal edildi',gecersiz:'Süresi doldu'};return s[c]||c||'—';}

function iptalKontrol(c,rol){
 if(c.durum==='iptal')return '<p class="alt">✅ Bu çek iki tarafın onayıyla iptal edilmiştir; artık geçersizdir.</p>';
 if(c.durum!=='aktif'||Number(c.odenen||0)>0)return '';
 var kayit=(CACHE.iptaller||[]).find(function(x){return Number(x.cek_id)===Number(c.id);});
 var bekliyor=kayit&&kayit.durum==='bekliyor'&&!kayit.hamil_degisikligi;
 var benimOnayim=bekliyor&&(rol==='veren'?kayit.veren_onay:kayit.hamil_onay);
 if(bekliyor){
  var h='<p class="alt" style="color:#e6ecff;font-weight:600">İptal isteği bekliyor · Veren: '+(kayit.veren_onay?'Onayladı':'Bekleniyor')+
   ' · Hamil: '+(kayit.hamil_onay?'Onayladı':'Bekleniyor')+'</p>';
  if(!benimOnayim)h+=buton('İptali onayla','cekIptalKarar('+c.id+',"onay")','altin')+
      buton('İptali reddet','cekIptalKarar('+c.id+',"reddet")');
  else if(kayit.talep_eden_benim)h+=buton('İptal talebimi geri al','cekIptalKarar('+c.id+',"vazgec")');
  return h;
 }
 return buton('Karşılıklı iptal talebi gönder','cekIptalKarar('+c.id+',"talep")');
}
window.cekIptalKarar=async function(id,eylem){
 var msgs={
  talep:'İptal talebin karşı tarafa gidecek. Çek ancak veren ve mevcut hamil ayrı ayrı onayladığında geçersiz olacaktır.',
  onay:'Bu iptal isteğini onaylıyor musun? İki tarafın onayı tamamlanırsa çek geçersiz olacaktır.',
  reddet:'İptal isteğini reddetmek istiyor musun? Çek geçerli kalacak.',
  vazgec:'Gönderdiğin iptal isteğini geri almak istiyor musun? Çek geçerli kalacak.'
 };
 if(!await onayla('Çek #'+id+' · İptal işlemi',msgs[eylem]||'İşlemi onaylıyor musun?','Onayla'))return;
 try{
  var r=await API.rpc('cek_iptal_islem',{p_cek:Number(id),p_eylem:eylem});
  toast(r.durum==='onaylandi'?'Çek iki tarafın onayıyla iptal edildi ve geçersiz.':
    r.durum==='bekliyor'?'Talep kaydedildi. Karşı tarafın onayı bekleniyor.':
    r.durum==='reddedildi'?'İptal reddedildi; çek geçerliliğini koruyor.':'İptal talebi geri alındı.');
  await yenile();
 }catch(err){hata(err);}
};

function bugunArtir(ymd,days){var d=new Date((ymd||new Date().toISOString().slice(0,10))+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10);}

window.cekMerkeziAc=function(sirket){
 CACHE.sirket=sirket?kim(sirket):null;
 if(typeof ekranAc==='function')ekranAc(function(){window.cekMerkeziEkrani();});
 else window.cekMerkeziEkrani();
};
window.cekMerkeziEkrani=async function(){
 if(typeof yukleniyor==='function')yukleniyor('Bankacılık ve Çek Merkezi');
 try{
  var r=await Promise.all([
   API.rpc('cek_panel'),
   API.rpc('cek_ticaret_panel'),
   API.rpc('cek_toptan_panel').catch(function(){return [];}),
   API.rpc('cek_ek_panel').catch(function(){return null;}),
   API.rpc('cek_iptal_panel')
  ]);
  CACHE.panel=r[0]; CACHE.teklifler=r[1]||[]; CACHE.toptan=r[2]||[]; CACHE.ek=r[3]; CACHE.iptaller=r[4]||[];
  var p=r[0],hesap=p.hesaplar||[],sirketler=p.sirketler||[];
  var gelecek=(p.verdiklerim||[]).filter(function(c){return c.durum==='aktif' || c.durum==='karsiliksiz';});
  var bekleyen=(CACHE.teklifler||[]).filter(function(t){return t.durum==='bekliyor';});
  var first=kart('🏦 Banka ve çek işlemleri',
   '<p class="alt">Çek defterini buradan al; aldığın ve verdiğin çekleri, vade tarihlerini ve teklifleri tek sayfadan yönet.</p>'+
   buton('İnternet Bankacılığı · tüm hesaplarım','ekranAc(internetBankaciligiEkrani)','altin')+
   buton('Oyuncu bankaları','ekranAc(oyuncuBankaEkrani)')+
   buton('Yeni çek defteri al','cekDefterModal()','altin')+
   buton('Çek düzenle / çek ver','cekDuzenleModal()')+
   satir('Bankada vadesiz bakiyem',para(p.vadesiz))+
   satir('Aktif ödeme yükümlülüğüm',para(gelecek.reduce(function(s,c){return s+Number(c.tutar)-Number(c.odenen||0);},0)))+
   satir('Onay bekleyen teklifler',bekleyen.length));
  var defter=kart('📒 Çek defterlerim',hesap.length?hesap.map(function(h){
   var s=(sirketler||[]).find(function(x){return x.id===h.sirket;});
   return '<div class="liste-satir"><span class="orta"><b>'+(h.sirket?esc(s?s.ad:'Şirket #'+h.sirket):'Şahsi çek defterim')+'</b><span class="kucuk">Defter #'+h.id+' · '+h.yaprak+' kullanılabilir yaprak</span></span>'+
    '<span>'+buton('Çek yaz','cekDuzenleModal('+h.id+')')+'</span></div>';
  }).join(''):'<p class="alt">Henüz çek defterin yok. Banka hesabın varsa üstteki düğmeden alabilirsin.</p>');
  var trade=kart('🤝 Çekli ticaret teklifleri · Satıcı onayı',
   '<p class="alt">Bir ilanı nakit + çekle satın almak için ödeme ekranında “Çekle ödeme teklif et” seç. Teklifin satıcı kabul etmeden ne para gider ne de çek kesilir. Onaydan sonra devir ve ödeme birlikte yapılır.</p>'+
   buton('Satılık hisseler',typeof window.sirketHissePazariEkrani==='function'?'ekranAc(sirketHissePazariEkrani)':'ekranAc(cekHissePazariEkrani)')+
   (typeof yatirimPazarEkrani==='function'?buton('Gayrimenkul pazarı','ekranAc(yatirimPazarEkrani)'):'')+
   (typeof kamuToptanEkrani==='function'?buton('Şirketlerin mal ticareti','ekranAc(kamuToptanEkrani)'):'')+
   (CACHE.teklifler.length?CACHE.teklifler.map(function(o){
    var html='<div class="kart" style="margin:9px 0;background:var(--panel2)"><b>#'+o.id+' · '+esc(o.varlik||o.tur)+'</b>'+
      '<p class="kucuk">'+(o.benim?'Satıcı: '+esc(o.satici_ad):'Alıcı: '+esc(o.alici_ad))+'</p>'+
      satir('Satış bedeli',para(o.fiyat))+satir('Nakit',para(o.nakit))+satir('Çek',para(o.cek_tutar))+
      satir('Çek tarihi',tarih(o.cek_tarih))+satir('Durum',kisaDurum(o.durum));
    if(o.durum==='bekliyor'){
      if(o.saticiyim)html+=buton('Teklifi kabul et','cekTeklifKarar('+o.id+',"kabul")','altin')+buton('Reddet','cekTeklifKarar('+o.id+',"red")');
      if(o.benim)html+=buton('Teklifimi iptal et','cekTeklifKarar('+o.id+',"iptal")');
    }
    return html+'</div>';
   }).join(''):'<p class="alt">Henüz çekli ticaret teklifin yok.</p>'));
  var issued=kart('📤 Verdiğim çekler',(p.verdiklerim||[]).length?(p.verdiklerim||[]).map(function(c){
   var kalan=Math.max(0,Number(c.tutar)-Number(c.odenen||0));
   var html='<div class="kart" style="margin:9px 0;background:var(--panel2)"><h3>Çek #'+c.id+' · '+esc(c.hamil_ad||'Alıcı')+'</h3>'+
    satir('Çek tutarı',para(c.tutar))+satir('Kalan borç',para(kalan))+satir('Ödeme tarihi',tarih(c.tarih))+
    satir('Durum',kisaDurum(c.durum));
   if(kalan>0&&(c.durum==='aktif'||c.durum==='karsiliksiz')) html+=buton('Şimdi öde / erken öde','cekHareket('+c.id+',"erken")','altin');
   html+=iptalKontrol(c,'veren');
   return html+'</div>';
  }).join(''):'<p class="alt">Verdiğin çek bulunmuyor.</p>');
  var received=kart('📥 Aldığım çekler',(p.bende||[]).length?(p.bende||[]).map(function(c){
    var kalan=Math.max(0,Number(c.tutar)-Number(c.odenen||0));
    var h='<div class="kart" style="margin:9px 0;background:var(--panel2)"><h3>Çek #'+c.id+' · '+esc(c.borclu_ad||c.duzenleyen_ad)+'</h3>'+
     satir('Çek tutarı',para(c.tutar))+satir('Tahsil edilmemiş',para(kalan))+
     satir('Vade',tarih(c.tarih))+satir('Durum',kisaDurum(c.durum));
    if(c.durum==='aktif'&&kalan>0){
      h+=buton('Çeki bankaya ibraz et','cekHareket('+c.id+',"ibraz")')+
        buton('Çeki ciro et','cekHareket('+c.id+',"ciro")')+
        '';
    }
    if(c.durum==='karsiliksiz'&&kalan>0&&!c.takip)h+=buton('İcra takibini başlat','cekHareket('+c.id+',"takip")','altin');
    h+=iptalKontrol(c,'hamil');
    return h+'</div>';
  }).join(''):'<p class="alt">Aldığın çek bulunmuyor.</p>');
  var bulk=(CACHE.toptan||[]).filter(function(x){return x.durum==='bekliyor';});
  var bulkHtml=bulk.length?kart('🏭 Şirketler arası çekli mal teklifleri',bulk.map(function(x){
   return '<div class="kart"><b>#'+x.id+' · '+esc(x.magaza)+' → '+esc(x.uretici)+'</b>'+
     '<p class="alt">'+esc(x.adet)+' × '+esc(x.urun)+' · Toplam '+para(x.toplam)+' · Nakit '+para(x.nakit||0)+' + Çek '+para(Number(x.toplam)-Number(x.nakit||0))+' · '+tarih(x.cek_tarih)+'</p>'+
     (x.satici_yetkilisi?buton('Satışı kabul et','cekToptanKarar('+x.id+',"kabul")','altin')+buton('Reddet','cekToptanKarar('+x.id+',"red")'):'')+
     (x.teklif_sahibi?buton('Teklifi iptal et','cekToptanKarar('+x.id+',"iptal")'):'')+'</div>';
  }).join('')):'';
  var legal=kart('⚖️ Karşılıksız çek ve yaptırımlar',
   '<p class="alt">Vade günü otomatik banka/şirket kasası tahsilatı yapılır. Bakiye yetersizse kalan borç karşılıksız sayılır; kredi notu düşer, yeni çek defteri ve yeni çek düzenleme engellenir. Alacaklı icra takibi başlatabilir. Kısmi veya erken ödeme yapılabilir.</p>'+
   ((CACHE.ek&&CACHE.ek.tazminatlar||[]).length?(CACHE.ek.tazminatlar||[]).map(function(x){
    return satir('Çek #'+x.cek_id+' takip tazminatı',para(x.kalan))+
      buton('Tazminat ödemesi','cekTazminat('+x.cek_id+')');
   }).join(''):''));
  iskelet('Bankacılık ve Çek Merkezi','<div class="cek-bank-ui">'+first+defter+trade+bulkHtml+issued+received+legal+'</div>',{geri:true});
 }catch(er){iskelet('Bankacılık ve Çek Merkezi',kart('Bağlantı hatası','<p>'+esc(er.message||String(er))+'</p>'+buton('Tekrar dene','cekMerkeziEkrani()')),{geri:true});}
};

window.cekDefterModal=async function(){
 try{
  var p=CACHE.panel||await API.rpc('cek_panel');CACHE.panel=p;
  var sec='<option value="">Şahsi çek defteri</option>'+(p.sirketler||[]).map(function(s){return '<option value="'+s.id+'">'+esc(s.ad)+' · Şirket çeki</option>';}).join('');
  var m=modal('<h3>Çek karnesi / çek defteri al</h3><p class="alt">Bir defter 10 yaprak içerir. Yeni defter için mevcut yaprak sayın 2 veya altında olmalı. Karşılıksız açık çekin varsa yeni defter alamazsın.</p>'+
    '<div class="alan"><label>Hesap sahibi</label><select id="ckDefSahip">'+sec+'</select></div>'+
    '<button class="btn altin" id="ckDefOnay">Çek defteri al</button>');
  m.querySelector('#ckDefOnay').onclick=async function(){
    this.disabled=true;try{var s=m.querySelector('#ckDefSahip').value;await API.rpc('cek_islem',{p_eylem:'defter',p_veri:{sirket:s}});
      modalKapat();toast('Çek defterin açıldı. Çek Merkezi içinde kullanabilirsin.');await yenile();
    }catch(er){hata(er);this.disabled=false;}
  };
 }catch(er){hata(er);}
};
window.cekDuzenleModal=async function(hesapId){
 try{
  var p=CACHE.panel||await API.rpc('cek_panel');CACHE.panel=p;
  var hs=(p.hesaplar||[]).filter(function(h){return h.yaprak>0;});
  if(!hs.length){toast('Önce çek defteri al.',true);return window.cekDefterModal();}
  var options=hs.map(function(h){
   var s=(p.sirketler||[]).find(function(x){return x.id===h.sirket;});
   return '<option value="'+h.id+'"'+(Number(hesapId)===h.id?' selected':'')+'>'+(h.sirket?esc(s?s.ad:'Şirket #'+h.sirket):'Şahsi')+' · '+h.yaprak+' yaprak</option>';
  }).join('');
  var m=modal('<h3>Çek düzenle</h3><p class="alt">Bağımsız çek düzenleme menüsüdür; mülk veya hisse satın almaz. Ticaret ödemelerinde önce satıcının onayına sunulan “Çekle ödeme teklif et” seçeneğini kullanmalısın.</p>'+
    '<div class="alan"><label>Çek defterim</label><select id="ckHesap">'+options+'</select></div>'+
    '<div class="alan"><label>Alıcı oyuncunun kullanıcı adı</label><input id="ckAlici" placeholder="Kullanıcı adı"></div>'+
    '<div class="alan"><label>Veya alıcı şirket ID (isteğe bağlı)</label><input id="ckSirket" type="number" min="1"></div>'+
    '<div class="alan"><label>Çek tutarı (₺)</label><input id="ckTutar" type="number" min="100" max="1000000000" step="0.01"></div>'+
    '<div class="alan"><label>Çek / ödeme tarihi</label><input id="ckVade" type="date" min="'+p.bugun+'" max="'+bugunArtir(p.bugun,365)+'" value="'+bugunArtir(p.bugun,7)+'"></div>'+
    '<div class="alan"><label>Açıklama</label><input id="ckAciklama" maxlength="180"></div>'+
    '<button id="ckYaz" class="btn altin">Çeki düzenle ve teslim et</button>');
  m.querySelector('#ckYaz').onclick=async function(){
    this.disabled=true;
    var v={hesap:m.querySelector('#ckHesap').value,alici:m.querySelector('#ckAlici').value.trim(),
      alici_sirket:m.querySelector('#ckSirket').value,tutar:m.querySelector('#ckTutar').value,
      tarih:m.querySelector('#ckVade').value,aciklama:m.querySelector('#ckAciklama').value};
    try{var r=await API.rpc('cek_islem',{p_eylem:'duzenle',p_veri:v});
       modalKapat();toast('Çek #'+r.id+' düzenlendi.');await yenile();
    }catch(er){hata(er);this.disabled=false;}
  };
 }catch(er){hata(er);}
};

window.cekHareket=async function(id,eylem){
 var c=((CACHE.panel&&CACHE.panel.verdiklerim)||[]).concat((CACHE.panel&&CACHE.panel.bende)||[]).find(function(v){return v.id===id;});
 var veri={};
 if(eylem==='erken'){
  var kalan=c?Math.max(0,Number(c.tutar)-Number(c.odenen||0)):0;
  var miktar=prompt('Çek #'+id+' için ne kadar ödeme yapmak istiyorsun? Banka vadesiz hesabında veya şirket kasasında yeterli para olmalı.',String(kalan));
  if(miktar===null)return;veri.tutar=Number(miktar);
  if(!Number.isFinite(veri.tutar)||veri.tutar<=0||veri.tutar>kalan){toast('Geçerli bir ödeme tutarı gir.',true);return;}
 }
 if(eylem==='ciro'){
  var alici=prompt('Çeki devredeceğin oyuncunun kullanıcı adını gir:','');
  if(alici===null)return;if(!alici.trim())return toast('Oyuncu adı gerekli.',true);
  veri.alici=alici.trim();
 }
 if(!await onayla('Çek işlemi','Çek #'+id+' için '+({erken:'ödeme',ibraz:'bankaya ibraz',iade:'iade',ciro:'ciro',takip:'icra takibi'}[eylem]||eylem)+' işlemini onaylıyor musun?','Onayla'))return;
 try{await API.rpc('cek_islem',{p_eylem:eylem,p_id:id,p_veri:veri});toast('Çek işlemi tamamlandı.');await yenile();}
 catch(er){hata(er);}
};
window.cekTazminat=async function(id){
 var t=prompt('Çek #'+id+' takip tazminatı için ödenecek tutar:','');
 if(t===null)return;
 try{await API.rpc('cek_tazminat_ode',{p_cek:id,p_tutar:Number(t)});toast('Tazminat ödendi.');yenile();}
 catch(er){hata(er);}
};
window.cekToptanKarar=async function(id,eylem){
 if(!await onayla('Çekli mal ticareti','Teklif #'+id+' için '+(eylem==='kabul'?'satışı kabul et':'işlemi iptal/reddet')+' işlemi yapılsın mı?','Onayla'))return;
 try{await API.rpc('cek_toptan_islem',{p_eylem:eylem,p_veri:{id:id}});toast('Çekli mal ticareti güncellendi.');yenile();}
 catch(er){hata(er);}
};
window.cekTeklifKarar=async function(id,eylem){
 var o=(CACHE.teklifler||[]).find(function(x){return x.id===id;});
 if(!o)return toast('Teklif yenilenmeli.',true);
 var mesaj=eylem==='kabul'?'Bu teklifi kabul ettiğinde '+para(o.nakit)+' nakit alacak, '+para(o.cek_tutar)+' vadeli çek alacak ve satış konusu varlığı alıcıya devredeceksin. Vade: '+tarih(o.cek_tarih)+'. Onaylıyor musun?':
 'Bu teklif reddedilecek / iptal edilecek. Para, çek ve varlık değişmeyecek.';
 if(!await onayla('Çekli ödeme teklifi #'+id,mesaj,eylem==='kabul'?'Satışı kabul et':'İşlemi tamamla'))return;
 try{var r=await API.rpc('cek_ticaret_islem',{p_eylem:eylem,p_veri:{id:id}});
  toast(r.tamam===false?'Teklifin süresi dolmuş.':'Teklif güncellendi.');await yenile();
 }catch(er){hata(er);}
};

window.cekTicaretTeklifModal=async function(tur,ilan,fiyat,isim){
 try{
  var p=CACHE.panel||await API.rpc('cek_panel');CACHE.panel=p;
  var hs=(p.hesaplar||[]).filter(function(h){return h.sirket==null&&h.yaprak>0;});
  if(!hs.length){toast('Bu satın alma için kişisel çek defteri gerekiyor.',true);return window.cekDefterModal();}
  var bedel=Math.round(Number(fiyat)*100)/100;
  if(!Number.isFinite(bedel)||bedel<100)throw Error('Çekle ödemeye uygun ilan tutarı değil.');
  var cash=Math.floor((bedel*0.6)*100)/100;
  var options=hs.map(function(h){return '<option value="'+h.id+'">Şahsi çek defteri #'+h.id+' · '+h.yaprak+' yaprak</option>';}).join('');
  var m=modal('<h3>Nakit + çekle ödeme teklif et</h3><p class="alt">'+esc(isim||'Satılık varlık')+
    '</p>'+satir('İlan bedeli',para(bedel))+
    '<p class="kucuk">Satıcı kabul ederse nakit hemen ödenir, çek borcun vade tarihinde tahsil edilir. Kabul edilmeden çek kesilmez veya mülkiyet devredilmez.</p>'+
    '<div class="alan"><label>Peşin nakit (₺)</label><input id="ctNakit" type="number" step="0.01" min="0" max="'+bedel+'" value="'+cash+'"></div>'+
    '<div class="alan"><label>Çek tutarı (₺)</label><input id="ctCek" type="number" min="100" step="0.01" max="'+bedel+'" value="'+(Math.round((bedel-cash)*100)/100)+'"></div>'+
    '<div class="alan"><label>Çek defteri</label><select id="ctHesap">'+options+'</select></div>'+
    '<div class="alan"><label>Çek tarihi</label><input id="ctVade" type="date" min="'+p.bugun+'" max="'+bugunArtir(p.bugun,365)+'" value="'+bugunArtir(p.bugun,7)+'"></div>'+
    (tur==='tapu'?'<p class="alt">Tapu harçları ayrıca nakit olarak ödenir: alıcı %2, satıcı %2.</p>':'')+
    '<p class="alt" id="ctToplam">Nakit ve çek toplamı '+para(bedel)+' olmalı.</p>'+
    '<button id="ctGonder" class="btn altin">Satıcıya onay için gönder</button>');
  var nak=m.querySelector('#ctNakit'),cek=m.querySelector('#ctCek'),etiket=m.querySelector('#ctToplam');
  nak.oninput=function(){if(!nak.value.trim())return;cek.value=(Math.round((bedel-Number(nak.value))*100)/100).toFixed(2);etiket.textContent='Toplam: '+para(Number(nak.value)+Number(cek.value))+' / '+para(bedel);};
  cek.oninput=function(){if(!cek.value.trim())return;nak.value=(Math.round((bedel-Number(cek.value))*100)/100).toFixed(2);etiket.textContent='Toplam: '+para(Number(nak.value)+Number(cek.value))+' / '+para(bedel);};
  m.querySelector('#ctGonder').onclick=async function(){
   var n=Number(nak.value),c=Number(cek.value);
   if(n<0||c<100||Math.round((n+c)*100)!==Math.round(bedel*100)){toast('Nakit + çek toplamı ilan bedeline eşit olmalı; çek en az 100 ₺.',true);return;}
   this.disabled=true;
   try{var r=await API.rpc('cek_ticaret_islem',{p_eylem:'teklif',p_veri:{
    tur:tur,ilan:ilan,nakit:n,cek:c,hesap:Number(m.querySelector('#ctHesap').value),
    vade:m.querySelector('#ctVade').value}});
    modalKapat();toast('Çekli ödeme teklifin (#'+r.id+') satıcıya gönderildi. Satıcı onayı bekleniyor.');
   }catch(er){hata(er);this.disabled=false;}
  };
 }catch(er){hata(er);}
};
function odemeSecimi(tur,id,fiyat,ad,nakitIslem){
 var m=modal('<h3>Ödeme yöntemini seç</h3><p class="alt">'+esc(ad||'Satın alma')+'</p>'+
  satir('Satış bedeli',para(fiyat))+
  '<p class="kucuk">Nakit ödemede varlık hemen devredilir. Çekli ödemede satıcıya kabul veya ret için teklif gider; kabul edilirse devir yapılır.</p>'+
  '<button class="btn altin" id="ctCash">Tamamını nakit öde</button>'+
  '<button class="btn ikinci" id="ctMixed">Çekle ödeme teklif et · nakit + çek</button>');
 m.querySelector('#ctCash').onclick=function(){modalKapat();nakitIslem();};
 m.querySelector('#ctMixed').onclick=function(){modalKapat();window.cekTicaretTeklifModal(tur,id,fiyat,ad);};
}
// Eski nakit ödeme yolunu korurken çekli teklif seçeneğini de sun.
var oncekiHisse=window.sirketHisseSatinAl;
if(typeof oncekiHisse==='function'){
 window.sirketHisseSatinAl=function(id){
  var i=(window._sirketHisseAktifIlanlar||[]).find(function(x){return Number(x.id)===Number(id);});
  if(!i)return oncekiHisse(id);
  odemeSecimi('hisse',id,Number(i.bedel),i.ad+' · %'+i.pay+' hisse',function(){oncekiHisse(id);});
 };
}
var oncekiTapu=window.ypAlimOnay;
if(typeof oncekiTapu==='function'){
 window.ypAlimOnay=function(eylem,veri,fiyat){
  if(eylem!=='ilan_al')return oncekiTapu(eylem,veri,fiyat);
  odemeSecimi('tapu',Number(veri.ilan),Number(fiyat),'Gayrimenkul ilanı #'+veri.ilan,
    function(){oncekiTapu(eylem,veri,fiyat);});
 };
}
// Kişisel banka hesabı ve çek kısa yolları yalnızca Hayat ekranında gösterilir.
var oncekiIskelet=window.iskelet;
if(typeof oncekiIskelet==='function'){
 window.iskelet=function(baslik,govde,opt){
  if(baslik==='Hayat'){
   var kisayol='<div class="kart" id="cek-bank-quick"><h2>🏦 Bankacılık ve Çekler</h2>'+
    '<p class="alt">Banka hesabı · çek defteri · verdiğim/aldığım çekler · nakit + çek teklifleri</p>'+
    buton('🌐 İnternet Bankacılığı','ekranAc(internetBankaciligiEkrani)','altin')+
    buton('📒 Çek Defterim ve Çek Merkezi','cekMerkeziAc()','altin')+
    buton('🤝 Çek teklifleri','cekMerkeziAc()')+
    '</div>';
   govde=kisayol+govde;
  }
  return oncekiIskelet.call(this,baslik,govde,opt);
 };
}

window.cekToptanTeklifModal=async function(){
 var ma=Number(document.getElementById('kt_alici')?.value);
 var stokRaw=String(document.getElementById('kt_stok')?.value||'').split('|');
 var ad=Number(document.getElementById('kt_adet')?.value);
 if(!ma||stokRaw.length!==2||!Number.isInteger(ad)||ad<1||ad>500)return toast('Önce mağazanı, ürününü ve geçerli adet seç.',true);
 try{
  var res=await Promise.all([API.rpc('cek_panel'),API.rpc('kamu_toptan_panel')]);
  var panel=res[0],data=res[1];
  var hs=(panel.hesaplar||[]).filter(function(h){return Number(h.sirket)===ma&&Number(h.yaprak)>0;});
  if(!hs.length){toast('Mağazan adına çek defteri almalısın. Bankacılık ve Çek Merkezinden şirket defteri al.',true);return window.cekDefterModal();}
  var urun=(data.stoklar||[]).find(function(s){return Number(s.sirket)===Number(stokRaw[0])&&s.urun===stokRaw[1];});
  if(!urun)return toast('Bu stok artık satışta değil. Listeyi yenile.',true);
  if(Number(urun.adet)<ad)return toast('Satıcının stoğu yeterli değil.',true);
  var toplam=Math.round(Number(urun.fiyat)*ad);
  if(!Number.isSafeInteger(toplam)||toplam<100||toplam>1000000000) return toast('Çekli satış için tutar en az 100 ₺ olmalı.',true);
  var pesin=Math.round(toplam*0.6);
  var m=modal('<h3>Mal ticareti · nakit + çek</h3>'+
   '<p class="alt">'+esc(urun.ad)+' · '+esc(stokRaw[1])+' · '+ad+' adet</p>'+
   satir('Alışveriş toplamı',para(toplam))+
   '<p class="kucuk">Satıcıya kabul veya ret bildirimi gönderilecek. Kabul edilirse mağaza kasasından peşinat çıkacak, kalan tutara vadeli çek düzenlenecek ve mallar teslim edilecek.</p>'+
   '<div class="alan"><label>Peşin nakit (mağaza kasasından)</label><input id="ckMalNakit" type="number" min="0" max="'+(toplam-100)+'" step="0.01" value="'+pesin+'"></div>'+
   '<p class="alt" id="ckMalKalan">Vadeli çek: '+para(toplam-pesin)+'</p>'+
   '<div class="alan"><label>Mağazanın çek defteri</label><select id="ckMalDefter">'+hs.map(function(h){return '<option value="'+h.id+'">Defter #'+h.id+' · '+h.yaprak+' yaprak</option>';}).join('')+'</select></div>'+
   '<div class="alan"><label>Çek ödeme tarihi</label><input id="ckMalVade" type="date" min="'+panel.bugun+'" max="'+bugunArtir(panel.bugun,365)+'" value="'+bugunArtir(panel.bugun,7)+'"></div>'+
   '<button id="ckMalGonder" class="btn altin">Satıcıya ödeme teklifini gönder</button>');
  var input=m.querySelector('#ckMalNakit');
  input.oninput=function(){m.querySelector('#ckMalKalan').textContent='Vadeli çek: '+para(toplam-Number(input.value||0));};
  m.querySelector('#ckMalGonder').onclick=async function(){
   var n=Number(input.value);
   if(!Number.isFinite(n)||n<0||n!==Math.round(n*100)/100||toplam-n<100){
    return toast('Peşinat 0–'+para(toplam-100)+' aralığında olmalı. Çek en az 100 ₺.',true);
   }
   this.disabled=true;
   try{
    var sonuc=await API.rpc('cek_toptan_islem',{p_eylem:'teklif',p_veri:{
     magaza:ma,uretici:Number(stokRaw[0]),urun:stokRaw[1],adet:ad,
     hesap:Number(m.querySelector('#ckMalDefter').value),tarih:m.querySelector('#ckMalVade').value,nakit:n
    }});
    modalKapat();toast('Nakit + çek teklifi (#'+sonuc.id+') satıcıya gönderildi. Satıcı Çek Merkezinden kabul veya ret verebilir.');
    window.kamuToptanEkrani();
   }catch(er){hata(er);this.disabled=false;}
  };
 }catch(er){hata(er);}
};

// Web sürümünde eski hisse pazar sayfası bulunmayabilir; çekli alım için doğrudan pazar.
window.cekHissePazariEkrani=async function(){
 if(typeof yukleniyor==='function')yukleniyor('Hisse Pazarı · Nakit ve Çek');
 try{
  var p=await API.rpc('sirket_hisse_pazar'),l=p.ilanlar||[];
  var html=kart('🏢 Satılık şirket hisseleri',
   '<p class="alt">Hisseyi doğrudan nakitle alabilir veya satıcıya nakit + çek teklif edebilirsin. Çekli teklifte hisseler yalnızca satıcı onaylayınca devredilir.</p>'+
   buton('Çek tekliflerini ve defterimi aç','cekMerkeziAc()'));
  html+=kart('Hisse ilanları',l.length?l.map(function(i){
   var id=Number(i.id),bedel=Number(i.bedel);
   return '<div class="kart" style="margin:9px 0;background:var(--panel2)">'+
    '<h3>'+esc(i.ad)+' · %'+esc(i.pay)+' hisse</h3>'+
    satir('Satıcı',i.satici)+satir('Sektör',i.sektor)+satir('İlan bedeli',para(bedel))+
    (i.benim?'<p class="alt">Bu ilan sana ait.</p>':
      buton('Nakit satın al','cekHisseNakitleAl('+id+')','altin')+
      buton('Nakit + çek teklif et','cekTicaretTeklifModal("hisse",'+id+','+bedel+',"Hisse ilanı #'+id+'")'))+
    '</div>';
  }).join(''):'<p class="alt">Satılık şirket hissesi bulunmuyor.</p>');
  iskelet('Hisse Pazarı · Nakit ve Çek',html,{geri:true});
 }catch(er){iskelet('Hisse Pazarı · Nakit ve Çek',kart('İşlem yapılamadı','<p>'+esc(er.message)+'</p>'),{geri:true});}
};
window.cekHisseNakitleAl=async function(id){
 if(!await onayla('Hisseyi nakit satın al','İlandaki tüm satış bedeli nakit olarak cüzdanından tahsil edilecek. Devam edilsin mi?','Nakit satın al'))return;
 try{await API.rpc('sirket_hisse_ilan_al',{p_ilan:id});toast('Hisse satın alındı.');window.cekHissePazariEkrani();}
 catch(er){hata(er);}
};

})();