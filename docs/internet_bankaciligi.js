/* Internet Bankaciligi 2026.10.23 - devlet ve oyuncu bankalari, gercek kayitlar ve RPC. */
(function(){
'use strict';
if(window.SO_IB_V1)return; window.SO_IB_V1=true;
var S={data:null,bank:null,tab:'ozet',busy:false};
var q=function(id){return document.getElementById(id);};
var esc=function(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});};
var para=function(n){return (Number(n)||0).toLocaleString('tr-TR',{minimumFractionDigits:0,maximumFractionDigits:2})+' ₺';};
var tarih=function(d){if(!d)return '—';var t=new Date(d);return isNaN(t.getTime())?'—':t.toLocaleDateString('tr-TR',{day:'2-digit',month:'short',year:'numeric'});};
var fmt=function(n){return Number(n||0).toLocaleString('tr-TR');};
var say=function(id){return Number(q(id)&&q(id).value||0);};
function kart(ad,govde,cls){return '<section class="ib-card '+(cls||'')+'"><h3>'+esc(ad)+'</h3>'+govde+'</section>';}
function row(ad,deger){return '<div class="ib-row"><span>'+esc(ad)+'</span><strong>'+esc(deger)+'</strong></div>';}
function btn(ad,action,cls){return '<button type="button" class="ib-btn '+(cls||'')+'" onclick="'+esc(action)+'">'+esc(ad)+'</button>';}
function inp(id,label,placeholder){return '<label class="ib-label" for="'+id+'">'+esc(label)+'</label><input class="ib-field" id="'+id+'" autocomplete="off" placeholder="'+esc(placeholder||'')+'">';}
function amount(id,label){return '<label class="ib-label" for="'+id+'">'+esc(label)+'</label><input class="ib-field" type="number" inputmode="decimal" min="1" step="0.01" id="'+id+'" placeholder="Tutar (₺)">';}
function notice(str){return '<div class="ib-note">'+esc(str)+'</div>';}
function rt(fn){if(typeof window[fn]!=='function'){toast('İşlem ekranı bulunamadı',true);return;} if(typeof ekranAc==='function')ekranAc(window[fn]);else window[fn]();}
function err(e){toast(typeof hataCevir==='function'?hataCevir(e.message||String(e)):e.message||String(e),true);}
function css(){
 if(q('ib-style'))return;
 var t=document.createElement('style');t.id='ib-style';t.textContent=[
 '.ib-root{color:#f1f4ff;max-width:940px;margin:0 auto;padding-bottom:48px}',
 '.ib-lead{padding:25px 20px 21px;background:linear-gradient(135deg,#2b3873,#161d3d 66%,#151a35);border:1px solid #44548e;border-radius:23px;margin:12px 0 15px;box-shadow:0 9px 29px #080c2233}',
 '.ib-eyebrow{font-size:11px;letter-spacing:2.3px;text-transform:uppercase;color:#bbcaff;font-weight:800}',
 '.ib-lead h2{color:#fff;font-size:25px;margin:10px 0;line-height:1.25;letter-spacing:-.6px}',
 '.ib-lead p{font-size:13px;color:#b9c3e4;margin:5px 0 0;line-height:1.6}',
 '.ib-lead .ib-amount{font-weight:850;font-size:32px;letter-spacing:-1px;color:white;overflow-wrap:anywhere}',
 '.ib-hero-row{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap}',
 '.ib-pill{border:1px solid #6981ba;border-radius:30px;padding:6px 10px;background:#192647;color:#d3e2ff;font-size:12px}',
 '.ib-bank{display:block;width:100%;color:inherit;text-align:left;background:linear-gradient(130deg,#202b53,#1a2444);border:1px solid #38466e;border-radius:17px;padding:16px;margin:10px 0;cursor:pointer}',
 '.ib-bank:active{transform:scale(.993)}.ib-bank-top{display:flex;gap:13px;align-items:center}',
 '.ib-logo{display:grid;place-items:center;width:46px;height:46px;flex:0 0 46px;border-radius:15px;background:#4255a1;color:white;font-size:22px}',
 '.ib-bank b{font-size:16px;display:block;color:#f3f5ff}.ib-bank small{display:block;color:#b7c2e4;margin-top:4px;line-height:1.45}',
 '.ib-balance{font-size:21px;font-weight:850;margin:14px 0 5px;color:#fff}',
 '.ib-minitext{color:#abb5d6;font-size:12px;line-height:1.5}',
 '.ib-mini{display:flex;gap:9px;flex-wrap:wrap;margin-top:10px}.ib-mini>span{font-size:11px;border-radius:9px;padding:5px 8px;background:#0e1835;color:#c7d2f3}',
 '.ib-h{font-size:16px;color:#e5eaff;margin:25px 0 9px;font-weight:850}',
 '.ib-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin:12px 0}',
 '.ib-stat{min-width:0;border:1px solid #3a4879;border-radius:15px;padding:13px;background:#1b2549}',
 '.ib-stat small{font-size:11px;color:#abb7d7;display:block;margin-bottom:6px}.ib-stat b{font-size:16px;overflow-wrap:anywhere;color:#fff}',
 '.ib-tabs{display:flex;overflow:auto;scrollbar-width:none;gap:7px;margin:16px -3px 12px;padding:3px}',
 '.ib-tabs button{white-space:nowrap;flex:0 0 auto;border:1px solid #3b4c7e;border-radius:12px;background:#182341;color:#b9c5e8;padding:11px 13px;font-size:12px;font-weight:750}',
 '.ib-tabs button[aria-selected=true]{background:#5964c8;color:#fff;border-color:#828cff}',
 '.ib-card{padding:16px;background:linear-gradient(150deg,#222c50,#1a2343);border:1px solid #364574;border-radius:18px;margin:11px 0}',
 '.ib-card h3{margin:0 0 13px;color:#eaf0ff;font-size:16px;line-height:1.35}',
 '.ib-row{display:flex;justify-content:space-between;gap:13px;border-top:1px solid #344163;padding:11px 0;font-size:13px;align-items:start}',
 '.ib-row:first-of-type{border-top:0}.ib-row span{color:#acb8db;flex:1}.ib-row strong{text-align:right;color:#edf1ff;overflow-wrap:anywhere;font-size:13px}',
 '.ib-btn{border:1px solid #6678e1;color:#fff;background:#515db9;border-radius:12px;font-weight:760;font-size:13px;padding:12px 15px;margin:7px 7px 0 0;max-width:100%;white-space:normal;min-height:41px}',
 '.ib-btn.alt{background:#202b52;border-color:#405388;color:#e0e7ff}.ib-btn.outline{background:transparent;color:#d5dfff;border-color:#6678b1}',
 '.ib-btn:active{opacity:.8}.ib-note{font-size:12px;line-height:1.65;color:#b9c9ef;padding:12px 13px;background:#152344;border-left:3px solid #7888ec;border-radius:10px;margin:12px 0}',
 '.ib-label{font-size:12px;color:#bbc6ea;margin:13px 0 5px;display:block;font-weight:700}',
 '.ib-field{box-sizing:border-box;display:block;width:100%;min-width:0;padding:12px 13px;background:#111b38;border:1px solid #475886;color:#fff;border-radius:11px;outline:none;font-size:15px}',
 '.ib-field:focus{border-color:#a2afff}.ib-txn{display:flex;justify-content:space-between;gap:13px;padding:12px 0;border-top:1px solid #344163;align-items:start}',
 '.ib-txn span{display:block;color:#edf0ff;font-size:13px}.ib-txn small{display:block;color:#9faed5;font-size:11px;margin-top:3px}.ib-txn b{font-size:13px;color:#d9e4ff;white-space:nowrap}',
 '.ib-credit{border-radius:18px;padding:19px;color:#fff;background:linear-gradient(125deg,#4a5da8,#182344);margin-bottom:13px;box-shadow:inset 0 0 40px #fff1}',
 '.ib-credit .ib-digits{font-size:21px;font-weight:800;letter-spacing:2px;margin:22px 0 10px}',
 '.ib-credit small{color:#dce4ff}.ib-empty{padding:22px 15px;border:1px dashed #4d5d87;border-radius:15px;color:#b5c1e2;font-size:13px;line-height:1.5}',
 '@media(max-width:360px){.ib-lead{padding:19px 15px}.ib-grid{gap:7px}.ib-stat{padding:10px}.ib-stat b{font-size:14px}}'
 ].join('');document.head.appendChild(t);
}
function draw(title,body){
 css();iskelet(title,'<main class="ib-root">'+body+'</main>',{geri:true});
}
function initial(){
 var d=S.data||{}, bs=d.banks||[],open=bs.filter(function(b){return !!b.hesabim;});
 var total=Number(d.devlet&&d.devlet.vadesiz||0)+open.reduce(function(a,b){return a+Number(b.vadesiz||0)+Number(b.mevduat||0);},0);
 var out='<div class="ib-lead"><div class="ib-eyebrow">Finansal hayatım</div><h2>İnternet Bankacılığı</h2><p>Tüm bankaların, kartların ve borçların tek yerde. İşlem yapmak için bankanı seç.</p><div class="ib-h">Toplam banka varlığım</div><div class="ib-amount">'+para(total)+'</div><div class="ib-mini"><span>'+ (open.length+1) +' aktif banka</span><span>Cüzdan: '+para(d.cuzdan)+'</span></div></div>';
 out+='<div class="ib-h">Hesaplarım</div>';
 out+=bankRow({id:'devlet',ad:'Devlet Bankası',hesabim:true,vadesiz:d.devlet&&d.devlet.vadesiz||0,mevduat:0,kredi_borcu:d.devlet&&d.devlet.kredi_borcu||0,kart_borcu:d.devlet&&d.devlet.kart_borcu||0},true);
 open.forEach(function(b){out+=bankRow(b,false);});
 if(!open.length)out+=notice('Özel bankada henüz hesabın yok. Aşağıdan bir banka seçerek hemen açabilirsin.');
 var closed=bs.filter(function(b){return !b.hesabim;});
 if(closed.length){out+='<div class="ib-h">Yeni banka hesabı aç</div>';closed.forEach(function(b){out+=bankRow(b,false);});}
 draw('İnternet Bankacılığı',out);
}
function bankRow(b,dev){
 var acik=b.hesabim, id=dev?'devlet':Number(b.id),name=esc(b.ad);
 return '<button type="button" class="ib-bank" onclick="ibBankaSec('+esc(JSON.stringify(id))+')"><div class="ib-bank-top"><div class="ib-logo">'+(dev?'🏛':'🏦')+'</div><div style="flex:1;min-width:0"><b>'+name+'</b><small>'+(acik?'Hesabım · Mobil şubeye gir':'Hesabın yok · Hesap aç')+'</small></div><span style="font-size:20px">›</span></div>'+
 (acik?'<div class="ib-balance">'+para(Number(b.vadesiz||0)+Number(b.mevduat||0))+'</div><div class="ib-minitext">Vadesiz + vadeli toplam</div><div class="ib-mini"><span>Kredi: '+para(b.kredi_borcu)+'</span><span>Kart borcu: '+para(b.kart_borcu)+'</span></div>':'<div class="ib-minitext" style="margin-top:11px">Bu bankadan kredi, kart, POS veya mevduat hizmeti almak için hesap aç.</div>')+'</button>';
}
function bankNow(){if(S.bank==='devlet')return {id:'devlet',ad:'Devlet Bankası',hesabim:true,vadesiz:(S.data.devlet||{}).vadesiz||0,mevduat:0,kredi_borcu:(S.data.devlet||{}).kredi_borcu||0,kart_borcu:(S.data.devlet||{}).kart_borcu||0};return (S.data.banks||[]).find(function(x){return Number(x.id)===Number(S.bank);});}
function cardsOf(b){
 return ((S.data.cards||{}).kartlar||[]).filter(function(k){
  if(b.id==='devlet')return (k.banka_id==null && /devlet/i.test(String(k.banka||''))) || String(k.banka||'').toLowerCase()==='devlet bankası';
  return k.banka_id!=null?Number(k.banka_id)===Number(b.id):String(k.banka||'')===String(b.ad);
 });
}
function loansOf(b){
 return ((S.data.port||{}).krediler||[]).filter(function(k){return String(k.banka||'')===String(b.ad);});
}
function depositsOf(b){
 return ((S.data.port||{}).mevduatlar||[]).filter(function(k){return Number(k.banka_id)===Number(b.id);});
}
function openStatement(k){return (k.ekstreler||[]).filter(function(e){return e.durum==='acik';}).sort(function(a,b){return Number(b.id)-Number(a.id);})[0];}
function bodyFor(b){
 var t=S.tab,h='';
 if(t==='ozet'){
  h+='<div class="ib-grid"><div class="ib-stat"><small>Vadesiz bakiyem</small><b>'+para(b.vadesiz)+'</b></div><div class="ib-stat"><small>Vadeli birikim</small><b>'+para(b.mevduat)+'</b></div><div class="ib-stat"><small>Kredi borcum</small><b>'+para(b.kredi_borcu)+'</b></div><div class="ib-stat"><small>Kart borcum</small><b>'+para(b.kart_borcu)+'</b></div></div>';
  h+=kart('Hızlı işlemler',btn('Para yatır / çek',"ibSekmeSec('hesap')")+btn('Para gönder',"ibSekmeSec('transfer')",'alt')+btn('Kartlarım',"ibSekmeSec('kart')",'alt')+btn('Kredilerim',"ibSekmeSec('kredi')",'alt')+btn('POS ve ödemeler',"ibSekmeSec('pos')",'alt')+btn('Çek defterim',"ibSekmeSec('cek')",'alt'));
  if(b.id!=='devlet')h+=kart('Banka bilgilerim',row('Banka adı',b.ad)+row('Hesap durumu','Açık')+notice('Her banka hesabının bakiyesi ayrıdır. Vadeli mevduat ve vadesiz bakiye ayrı izlenir.'));
 }
 if(t==='hesap'){
  h+=kart('Vadesiz TL hesabım',row('Hesap bakiyesi',para(b.vadesiz))+row('Bankam',b.ad)+(b.id==='devlet'?notice('Devlet Bankası vadesiz hesabında para yatırma ve çekme işlemleri mevcut banka sistemiyle sürer.')+btn('Devlet Bankası hesap işlemleri','ibDevletIslem()'):amount('ibVal','Para miktarı')+btn('Cüzdandan yatır','ibParaIslem("yatir")')+btn('Cüzdana çek','ibParaIslem("cek")','alt')));
  h+=b.id==='devlet'?kart('Diğer ürünler',btn('Vadeli / vadesiz işlemler','ibDevletIslem()')):kart('Vadeli mevduat',notice('Vadeli hesap ayrı tutulur. Erken bozulan mevduatta faiz kaybı uygulanır.')+amount('ibMevduat','Vadeli yatırılacak tutar')+'<label class="ib-label">Vade</label><select class="ib-field" id="ibVade"><option value="1">1 saat</option><option value="3">3 saat</option><option value="6">6 saat</option><option value="12">12 saat</option><option value="24">24 saat</option></select>'+btn('Vadeli hesap aç','ibVadeliAc()')+(depositsOf(b).map(function(d){return '<div class="ib-card" style="margin:12px 0">'+row('Ana para',para(d.anapara))+row('Faiz',('%'+fmt(d.oran)))+row('Vade tarihi',tarih(d.vade))+row('Durum',d.durum)+(d.durum==='aktif'||d.durum==='odeme_bekliyor'?btn('Mevduat tahsil / erken boz','ibVadeliCek('+Number(d.id)+')','alt'):'')+'</div>';}).join('')));
 }
 if(t==='transfer'){
  var targets=(S.data.banks||[]).filter(function(x){return x.hesabim||x.id!==b.id;});
  var selected='<label class="ib-label" for="ibHedefBanka">Alıcının bankası</label><select class="ib-field" id="ibHedefBanka"><option value="'+Number(b.id)+'">'+esc(b.ad)+' · Havale</option>'+targets.filter(function(x){return Number(x.id)!==Number(b.id);}).map(function(x){return '<option value="'+Number(x.id)+'">'+esc(x.ad)+' · EFT</option>';}).join('')+'</select>';
  h+=b.id==='devlet'?kart('Banka üzerinden transfer',notice('Devlet Bankası oyuncular arası transferleri kendi vadesiz hesapları üzerinden yürütür.')+btn('Para transferine git','ibDevletTransfer()')):kart('Havale ve EFT',row('Gönderen banka',b.ad)+row('Kullanılabilir bakiye',para(b.vadesiz))+selected+inp('ibAlici','Alıcı kullanıcı adı','Oyuncunun kullanıcı adı')+amount('ibHavaleTutar','Gönderilecek tutar')+notice('Aynı banka içi işlem havaledir. Bankalar arası işlem EFT olarak gerçekleşir. Alıcının seçilen bankada hesabı açık olmalıdır.')+btn('Transferi onayla','ibHavaleYap()'));
 }
 if(t==='kart'){
  var ks=cardsOf(b);
  if(!ks.length)h+='<div class="ib-empty">Bu bankaya ait kredi kartın henüz bulunmuyor.</div>';
  ks.forEach(function(k){
   var e=openStatement(k),remain=e?Math.max(0,Number(e.toplam||0)-Number(e.odenen||0)):0,min=e?Math.max(0,Number(e.asgari||0)-Number(e.odenen||0)):0;
   var zz='<div class="ib-credit"><div>'+esc(b.ad)+'</div><div class="ib-digits">•••• •••• •••• '+esc(k.son_dort||'0000')+'</div><small>'+esc(k.durum||'Aktif')+'</small></div>';
   zz+=row('Toplam kart limiti',para(k.limit))+row('Kalan kullanılabilir limit',para(k.kullanilabilir))+row('Güncel borç',para(k.borc))+row('Sonraki hesap kesim tarihi',tarih(k.kesim_at))+row('Ödenmemiş dönem borcu',para(remain))+row('Asgari ödeme',para(min))+row('Son ödeme tarihi',tarih(e&&e.son_odeme))+row('Gecikmiş asgari',para(k.gecikmis_asgari));
   if(Number(k.borc)>0){zz+=amount('ibKartTutar'+k.id,'Ödeme tutarı');if(min>0)zz+=btn('Asgarisini öde','ibKartOde('+Number(k.id)+','+min+')');zz+=btn('Borcun tamamını öde','ibKartOde('+Number(k.id)+','+Number(k.borc)+')','alt')+btn('Girdiğim tutarı öde','ibKartOde('+Number(k.id)+',0)','outline');}
   zz+='<div class="ib-h">Kart hareketleri</div>';var moves=k.hareketler||[];
   zz+=moves.length?moves.map(function(m){return '<div class="ib-txn"><div><span>'+esc(m.aciklama||m.tur)+'</span><small>'+tarih(m.zaman)+'</small></div><b>'+para(m.tutar)+'</b></div>';}).join(''):'<div class="ib-minitext">Kart hareketi bulunmuyor.</div>';
   h+=kart('Kredi kartım · #'+k.id,zz);
  });
  h+=kart('Yeni kredi kartı başvurusu',notice('Kredi kartı için banka hesabın açık olmalı. Belgeler yalnızca onayınla bankaya gösterilir. Kart ekstresi haftalıktır; taksitli POS işlemi yoktur.')+amount('ibLimit','Talep ettiğim kart limiti')+btn('Kredi kartı başvurusu yap','ibKartBasvur()'));
 }
 if(t==='kredi'){
  var ls=loansOf(b);
  if(b.id==='devlet'){h+=kart('Devlet Bankası kredilerim',row('Kalan toplam kredi borcum',para(b.kredi_borcu))+btn('Kredi başvurusu / kredi ödemesi','ibDevletIslem()'));}
  else{
   if(!ls.length)h+='<div class="ib-empty">Bu bankadan kullandığın kredi bulunmuyor.</div>';
   ls.forEach(function(k){h+=kart('Kredi #'+k.id,row('Anapara',para(k.anapara))+row('Toplam sözleşme',para(k.toplam))+row('Kalan borç',para(k.kalan))+row('Vade',tarih(k.vade))+row('Durum',k.durum)+(Number(k.kalan)>0?amount('ibKrediTutar'+k.id,'Kredi ödeme tutarı')+btn('Kredi borcumu öde','ibKrediOde('+Number(k.id)+')'):''));});
   h+=kart('Yeni ihtiyaç kredisi',notice('Kredi limiti ve faiz bankanın kasası, ödeme gücün ve kredi notuna göre hesaplanır. Bankanın onayı gerekir.')+amount('ibKrediIstek','Talep tutarı')+'<label class="ib-label">Vade</label><select class="ib-field" id="ibKrediVade"><option value="24">1 gün</option><option value="168">1 hafta</option><option value="336">2 hafta</option><option value="504">3 hafta</option><option value="672">4 hafta</option></select>'+btn('Kredi başvurusu gönder','ibKrediBasvur()'));
  }
 }
 if(t==='pos'){
  h+=notice('POS cihazı olan şirketlerden ürün veya hizmet alırken ödemeyi nakit (cüzdandan) ya da kredi kartından tek çekim yapabilirsin. Kartlı satışlarda komisyon satıcı şirketten %2 kesilir. Taksit yoktur.');
  var incoming=((S.data.pos||{}).gelen||[]);
  if(incoming.length)incoming.forEach(function(t){
   var options=((S.data.cards||{}).kartlar||[]).filter(function(k){return k.durum==='aktif'&&Number(k.kullanilabilir)>=Number(t.tutar);});
   var z=row('Satıcı şirket',t.sirket)+row('Ödenecek tutar',para(t.tutar))+row('Açıklama',t.aciklama);
   if(options.length){z+='<label class="ib-label">Ödeme yapılacak kredi kartı</label><select class="ib-field" id="ibPosKart'+t.id+'">'+options.map(function(k){return '<option value="'+Number(k.id)+'">'+esc(k.banka)+' · ••••'+esc(k.son_dort)+' · '+para(k.kullanilabilir)+'</option>';}).join('')+'</select>'+btn('Kredi kartı ile öde','ibPosKartOde('+Number(t.id)+')');}
   z+=btn('Nakit cüzdandan öde','ibPosNakitOde('+Number(t.id)+')','alt')+btn('Ödemeyi reddet','ibPosReddet('+Number(t.id)+')','outline');
   h+=kart('Bekleyen alışveriş · #'+t.id,z);
  });
  else h+=kart('Bekleyen ödeme','Şu anda sana gelen POS ödeme talebi yok.');
  h+=kart('Şirketim için POS cihazı',notice('Yönettiğin şirket adına seçtiğin özel bankada hesap açtıktan sonra POS başvurusu yapabilirsin.')+btn('POS cihazı başvurularım','ibGit("posBankaEkrani")')+btn('Kartlı satış oluştur','ibGit("kartPosEkrani")','alt'));
 }
 if(t==='cek'){
  h+=kart('Çek defterim ve çek işlemlerim',notice('Çek düzenleme, çek ciro etme, vadesinden önce ödeme ve karşılıksız çek takipleri mevcut sistemle devam eder.')+btn('Çek merkezi aç','ibCekAc()'));
 }
 if(t==='hareket'){
  if(b.id==='devlet'){h+=kart('Devlet Bankası hesap hareketleri',notice('Devlet bankasının vadesiz ve vadeli hesap dökümleri banka hesabı ekranında yer alır.')+btn('Hareketleri görüntüle','ibDevletIslem()'));}
  else{var hs=b.hareketler||[];h+=kart('Son hesap hareketlerim',hs.length?hs.map(function(x){return '<div class="ib-txn"><div><span>'+esc(x.aciklama)+'</span><small>'+tarih(x.zaman)+'</small></div><b>'+((Number(x.tutar)>0)?'+':'')+para(x.tutar)+'</b></div>';}).join(''):'<div class="ib-minitext">Bu hesapta henüz vadesiz işlem yapılmadı.</div>');}
 }
 return h;
}
function detail(){
 var b=bankNow();
 if(!b){S.bank=null;return initial();}
 var d=S.data||{};
 var h='<div class="ib-lead"><div class="ib-hero-row"><div class="ib-eyebrow">Güvenli mobil şube</div><span class="ib-pill">'+(b.hesabim?'● Aktif hesap':'○ Hesap açılmadı')+'</span></div><h2>'+esc(b.ad)+'</h2><p>'+(b.hesabim?'Vadesiz hesap bakiyen':'Banka ürünlerini kullanmak için hesap oluştur')+'</p><div class="ib-amount">'+para(b.vadesiz)+'</div><div style="margin-top:15px">'+btn('‹ Tüm bankalar','ibBankaSec("liste")','outline')+'</div></div>';
 if(!b.hesabim){h+=kart('Yeni hesap aç',notice('Bu bankadan kredi, kredi kartı, POS veya mevduat hizmeti almak için önce kişisel banka hesabı açmalısın. Mevcut cüzdan bakiyen değişmez.')+btn('Ücretsiz hesap aç','ibHesapAc()'));return draw('Banka hesabı aç',h);}
 var tabs=[['ozet','Genel Bakış'],['hesap','Hesaplar'],['transfer','Para Transferi'],['kart','Kartlarım'],['kredi','Krediler'],['pos','POS'],['cek','Çekler'],['hareket','Hareketler']];
 h+='<nav class="ib-tabs" aria-label="Banka işlemleri">'+tabs.map(function(t){return '<button type="button" aria-selected="'+(S.tab===t[0])+'" onclick="ibSekmeSec(\''+t[0]+'\')">'+t[1]+'</button>';}).join('')+'</nav>';
 h+=bodyFor(b); draw(b.ad+' · İnternet Bankacılığı',h);
}
async function load(){
 if(S.busy)return;
 S.busy=true;
 try{
  if(typeof yukleniyor==='function')yukleniyor('İnternet bankacılığı');
  var a=await Promise.all([
    API.rpc('ib_hesap_ozet'),
    API.rpc('kart_panel').catch(function(){return {kartlar:[]};}),
    API.rpc('oyb_portfoy').catch(function(){return {mevduatlar:[],krediler:[]};}),
    API.rpc('kart_pos_bekleyen').catch(function(){return {gelen:[]};})
  ]);
  var d=a[0]||{};S.data={banks:d.bankalar||[],devlet:d.devlet||{},cuzdan:d.cuzdan||0,cards:a[1]||{},port:a[2]||{},pos:a[3]||{}};
  if(S.bank===null||S.bank==='liste'){S.bank=null;initial();}else detail();
 }catch(ex){draw('İnternet Bankacılığı',kart('Bağlantı hatası',notice(ex.message||String(ex))+btn('Tekrar dene','ibYenile()')));}
 finally{S.busy=false;}
}
async function action(promise,metin){try{await promise;toast(metin||'İşlem başarılı');await load();}catch(ex){err(ex);}}
window.internetBankaciligiEkrani=function(){S.bank=null;S.tab='ozet';return load();};
window.ibYenile=load;
window.ibBankaSec=function(id){S.bank=id==='liste'?null:id;S.tab='ozet'; if(S.data){if(S.bank==null)initial();else detail();}else load();};
window.ibSekmeSec=function(tab){S.tab=tab;detail();};
window.ibGit=rt;
window.ibCekAc=function(){if(typeof window.cekMerkeziAc==='function')window.cekMerkeziAc();};
window.ibHesapAc=function(){var b=bankNow();if(!b||b.id==='devlet')return;action(API.rpc('oyb_hesap_ac',{p_banka:Number(b.id)}),'Bankanda hesabın açıldı');};
window.ibParaIslem=function(tur){var b=bankNow(),a=say('ibVal');if(!b||!(a>0))return toast('Geçerli tutar gir',true);if(!confirm(para(a)+' '+(tur==='yatir'?'yatırılsın mı?':'çekilsin mi?')))return;action(API.rpc('ib_vadesiz_islem',{p_banka:Number(b.id),p_tutar:a,p_islem:tur}),'Banka işlemin tamamlandı');};
window.ibHavaleYap=function(){var b=bankNow(),u=q('ibAlici'),a=say('ibHavaleTutar'),hedef=say('ibHedefBanka');if(!b||!u||!u.value.trim()||!(a>0)||!hedef)return toast('Banka, alıcı ve tutarı doldur',true);var eft=hedef!==Number(b.id);if(!confirm(esc(u.value.trim())+' kullanıcısına '+para(a)+(eft?' EFT':' havale')+' yapılsın mı?'))return;action(eft?API.rpc('ib_eft',{p_banka:Number(b.id),p_hedef_banka:hedef,p_alici:u.value.trim(),p_tutar:a}):API.rpc('ib_havale',{p_banka:Number(b.id),p_alici:u.value.trim(),p_tutar:a}),eft?'EFT gönderildi':'Havale gönderildi');};
window.ibVadeliAc=function(){var b=bankNow(),a=say('ibMevduat'),v=say('ibVade');if(!b||!(a>=1000))return toast('En az 1.000 TL vadeli yatır',true);if(!confirm(para(a)+' tutarında '+v+' saat vadeli mevduat açılacak. Onaylıyor musun?'))return;action(API.rpc('oyb_yatir',{p_banka:Number(b.id),p_tutar:a,p_saat:v}),'Vadeli hesap açıldı');};
window.ibVadeliCek=function(id){if(!confirm('Mevduatı şimdi tahsil etmek/erken bozmak istiyor musun?'))return;action(API.rpc('oyb_mevduat_cek',{p_id:id}),'Mevduat işlemi tamamlandı');};
window.ibKrediBasvur=function(){var b=bankNow(),a=say('ibKrediIstek'),v=say('ibKrediVade');if(!b||a<1000)return toast('En az 1.000 TL kredi tutarı yaz',true);if(!confirm(para(a)+' tutarında kredi başvurusu gönderilsin mi?'))return;action(API.rpc('oyb_kredi_basvur',{p_banka:Number(b.id),p_tutar:a,p_saat:v}),'Kredi başvurusu gönderildi');};
window.ibKrediOde=function(id){var a=say('ibKrediTutar'+id);if(!(a>0))return toast('Ödenecek tutarı gir',true);if(!confirm(para(a)+' kredi borcuna ödensin mi?'))return;action(API.rpc('oyb_kredi_ode',{p_id:id,p_tutar:a}),'Kredi borcu ödendi');};
window.ibKartBasvur=function(){var b=bankNow(),a=say('ibLimit');if(!b||!(a>=1000))return toast('En az 1.000 TL limit iste',true);action(API.rpc('kart_basvur',{p_banka:b.id==='devlet'?null:Number(b.id),p_limit:a}),'Kart başvurusu bankaya iletildi');};
window.ibKartOde=function(id,a){if(!(a>0))a=say('ibKartTutar'+id);if(!(a>0))return toast('Ödeme tutarı gir',true);if(!confirm(para(a)+' kart borcu ödemesi cüzdanından yapılsın mı?'))return;action(API.rpc('kart_ode',{p_kart:id,p_tutar:a}),'Kart borcu ödendi');};
window.ibPosNakitOde=function(id){if(!confirm('Bu alışverişi cüzdan bakiyenle nakit ödemek istiyor musun?'))return;action(API.rpc('ib_pos_nakit_ode',{p_talep:id}),'Nakit ödeme tamamlandı');};
window.ibPosKartOde=function(id){var a=say('ibPosKart'+id);if(!a)return toast('Kart seç',true);if(!confirm('Ödeme seçtiğin kredi kartına tek çekim yansıtılacak. Onaylıyor musun?'))return;action(API.rpc('kart_pos_yanit',{p_pos:id,p_kart:a}),'Kartlı ödeme tamamlandı');};
window.ibPosReddet=function(id){if(!confirm('Ödeme talebini reddetmek istiyor musun?'))return;action(API.rpc('kart_pos_yanit',{p_pos:id,p_kart:null}),'POS talebi reddedildi');};
window.ibDevletIslem=function(){rt('ibDevletEskiEkran');};
window.ibDevletTransfer=function(){if(typeof window.paraGonderModal==='function')window.paraGonderModal();};
function install(){
 if(typeof window.bankaEkrani==='function' && window.bankaEkrani!==window.internetBankaciligiEkrani){window.ibDevletEskiEkran=window.bankaEkrani;window.bankaEkrani=window.internetBankaciligiEkrani;}
 window.bankacilikMerkeziEkrani=window.internetBankaciligiEkrani;
 if(typeof window.bankaHesaplarimEkrani==='function')window.bankaHesaplarimEkrani=window.internetBankaciligiEkrani;
}
function labelFix(){
 document.querySelectorAll('button,a,.liste-satir,.so-link').forEach(function(el){
  if(el.childElementCount>5)return;
  if(el.textContent&&el.textContent.trim()==='Banka Hesaplarım'){el.textContent='İnternet Bankacılığı';}
  if(el.textContent&&el.textContent.trim()==='Banka hesaplarım'){el.textContent='İnternet Bankacılığı';}
 });
}
function start(){
 install();labelFix();var pending=false;
 new MutationObserver(function(){if(pending)return;pending=true;requestAnimationFrame(function(){pending=false;labelFix();});}).observe(document.body,{childList:true,subtree:true});
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();