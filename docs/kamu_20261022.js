/* Secim Online | Kamu ekonomisi ve icra arayuzu 2026-10-22 */
(function(){
'use strict';
const esc=x=>typeof e==='function'?e(String(x==null?'':x)):String(x==null?'':x).replace(/[&<>"]/g,s=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[s]));
const num=x=>Number(x||0);
const money=x=>(typeof fmt==='function'?fmt(num(x),2):num(x).toLocaleString('tr-TR'))+' ₺';
const billion=x=>(typeof fmt==='function'?fmt(num(x),3):num(x).toFixed(3))+' milyar ₺';
const row=(label,val)=>'<div class="kv"><span>'+esc(label)+'</span><b>'+esc(val)+'</b></div>';
const btn=(label,act,cls)=>'<button class="btn '+(cls||'ikinci')+'" onclick="'+act+'">'+esc(label)+'</button>';
const para=(msg)=>'<p class="alt">'+msg+'</p>';
function error(err){toast(typeof hataCevir==='function'?hataCevir(err.message):err.message,true);}
function sayfa(title,html){iskelet(title,html,{geri:true});}
function baslik(title){yukleniyor(title);}
async function rpc(name,args){return API.rpc(name,args||{});}
window.kamuButceEkrani=async function(){
 baslik('Devlet Bütçesi');
 try{
  const d=await rpc('kamu_butce_panel'), a=d.ekonomi||{}, keys=['egitim','saglik','savunma','icisleri','ulastirma'];
  const names=['Eğitim','Sağlık','Savunma','İçişleri','Ulaştırma'];
  let html='<div class="kart"><h2>🏛️ Merkezi bütçe</h2>'+row('Hazine',billion(d.hazine))+row('Büyüme',num(a.buyume)+'%')+
   row('Enflasyon',num(a.enflasyon)+'%')+row('İşsizlik',num(a.issizlik)+'%')+
   para('Bütçe aktarımları Hazine hesabından ilgili bakanlığa geçer. Ekonomi göstergeleri mevcut politikalar ve kamu yatırımları yoluyla etkilenir.')+'</div>';
  html+='<div class="kart"><h2>Bakanlık ödenekleri</h2>'+ (d.bakanliklar||[]).map(v=>row(v.kod,billion(v.kasa))).join('')+'</div>';
  if(d.yetkili){
   html+='<div class="kart"><h2>Yeni bütçe tahsis kararı</h2>'+para('24 saatte bir toplam 0,001–5 milyar ₺ aktarılabilir. Payların toplamı %100 olmalıdır.')+
    '<div class="alan"><label>Toplam (milyar ₺)</label><input type="number" id="kb_toplam" value="1" min="0.001" max="5" step="0.001"></div>';
   keys.forEach((key,i)=>{html+='<div class="alan"><label>'+names[i]+' (%)</label><input type="number" id="kb_'+key+'" value="20" min="0" max="100" step="1"></div>';});
   html+=btn('Bütçeyi onayla','kamuButceKaydet()','altin')+'</div>';
  }
  html+='<div class="kart"><h2>Son bütçe kararları</h2>'+((d.kararlar||[]).map(v=>row(new Date(v.tarih).toLocaleString('tr-TR'),billion(v.toplam))).join('')||para('Henüz paylaştırma kararı alınmadı.'))+'</div>';
  sayfa('Devlet Bütçesi',html);
 }catch(err){sayfa('Devlet Bütçesi','<div class="kart">'+esc(err.message)+'</div>');}
};
window.kamuButceKaydet=async function(){
 try{
  const keys=['egitim','saglik','savunma','icisleri','ulastirma'], pay={};let total=0;
  keys.forEach(k=>{pay[k]=num(document.getElementById('kb_'+k).value);total+=pay[k];});
  if(total!==100){toast('Paylar toplamı %100 olmalı.',true);return;}
  if(!await onayla('Bütçe tahsisi','Hazine ödeneği bakanlıklara aktarılacak. İşlemi onaylıyor musun?','Aktar'))return;
  await rpc('kamu_butce_dagit',{p_toplam:num(document.getElementById('kb_toplam').value),p_paylar:pay});
  toast('Bütçe tahsis edildi.');window.kamuButceEkrani();
 }catch(err){error(err);}
};

window.kamuToptanEkrani=async function(){
 baslik('Şirketler Arası Ticaret');
 try{
  const d=await rpc('kamu_toptan_panel'); const my=(d.sirketler||[]).filter(s=>s.tur==='magaza');
  let html='<div class="kart"><h2>🏭 Fabrikadan mağazaya ticaret</h2>'+
    para('Mağaza teklif verir; fabrikanın yetkilisi kabul ettiğinde ürün stoku, şirket kasaları ve üretici vergisi mevcut ticaret motoruyla aynı işlemde güncellenir.')+'</div>';
  if(my.length){
   html+='<div class="kart"><h2>Toptan sipariş teklifi oluştur</h2><div class="alan"><label>Alıcı mağazam</label><select id="kt_alici">'+my.map(s=>'<option value="'+Number(s.id)+'">'+esc(s.ad)+'</option>').join('')+'</select></div>';
   html+='<div class="alan"><label>Fabrika ve ürünü</label><select id="kt_stok">'+(d.stoklar||[]).map(s=>
      '<option value="'+Number(s.sirket)+'|'+esc(s.urun)+'">'+esc(s.ad)+' · '+esc(s.urun)+' · '+s.adet+' adet · '+money(s.fiyat)+'</option>').join('')+'</select></div>';
   html+='<div class="alan"><label>Sipariş miktarı</label><input id="kt_adet" type="number" min="1" max="500" value="1"></div>'+
       btn('Teklif gönder','kamuToptanTeklif()','altin')+
       btn('Nakit + çekle ödeme teklif et','cekToptanTeklifModal()','ikinci')+
       '<p class="alt">Çekli ödemede satıcı kabul etmeden şirket kasasından para çıkmaz ve çek düzenlenmez. Peşin miktarı ve vadeyi sen belirlersin.</p></div>';
  }
  html+='<div class="kart"><h2>Gelen ve giden teklifler</h2>';
  (d.teklifler||[]).forEach(o=>{
   html+='<div class="kart"><b>'+esc(o.satici_ad)+' → '+esc(o.alici_ad)+'</b>'+
    row('Ürün ve miktar',o.urun+' × '+o.adet)+row('Toplam',money(o.toplam))+row('Durum',o.durum);
   if(o.durum==='teklif'&&o.satici_yetkili){
     html+=btn('Siparişi kabul et','kamuToptanKarar('+Number(o.id)+',"kabul")','altin')+
           btn('Reddet','kamuToptanKarar('+Number(o.id)+',"ret")');
   }
   if(o.durum==='teklif'&&o.alici_yetkili){
    html+=btn('Teklifi iptal et','kamuToptanKarar('+Number(o.id)+',"iptal")');
   }
   html+='</div>';
  });
  html+=(d.teklifler||[]).length?'':'<p class="alt">Henüz açık sipariş yok.</p>';
  html+='</div>';
  sayfa('Şirketler Arası Ticaret',html);
 }catch(err){sayfa('Şirketler Arası Ticaret','<div class="kart">'+esc(err.message)+'</div>');}
};
window.kamuToptanTeklif=async function(){
 try{
  const s=String(document.getElementById('kt_stok')?.value||'').split('|');
  if(s.length!==2)throw Error('Tedarikçi ürün seç');
  await rpc('kamu_toptan_islem',{p_eylem:'teklif',p_alici:Number(document.getElementById('kt_alici').value),
    p_satici:Number(s[0]),p_urun:s[1],p_adet:Number(document.getElementById('kt_adet').value)});
  toast('Ticaret teklifi fabrikaya gönderildi.');kamuToptanEkrani();
 }catch(err){error(err);}
};
window.kamuToptanKarar=async function(id,eylem){
 try{if(!await onayla('Ticaret sözleşmesi','İşlem: '+esc(eylem)+'. Onaylıyor musun?','Onayla'))return;
 await rpc('kamu_toptan_islem',{p_eylem:eylem,p_id:id});toast('Sipariş güncellendi.');kamuToptanEkrani();}catch(err){error(err);}
};

const kurumAdlari={vali:'Vali',emniyet_muduru:'İl Emniyet Müdürü',spk_baskani:'SPK Başkanı',rekabet_baskani:'Rekabet Kurumu Başkanı',
vergi_idaresi_baskani:'Vergi İdaresi Başkanı',belediye_genel_sekreteri:'Belediye Genel Sekreteri'};
window.kamuAtamaEkrani=async function(){
 baslik('Kamu Atamaları');
 try{
  const d=await rpc('kamu_kurum_panel');let html='<div class="kart"><h2>🏛️ Kamu kurumları</h2>'+
    para('Yetkili yönetici oyuncuya görev teklifi gönderir. Oyuncu kabul ettiğinde atanır. Kaydedilen kurum yöneticileri ile mevcut siyasi makamlar birbirinden ayrılır.')+'</div>';
  if(d.cb||(d.belediye_iller||[]).length){
   html+='<div class="kart"><h2>Atama teklifi gönder</h2><div class="alan"><label>Kurum</label><select id="ka_gorev">';
   Object.keys(kurumAdlari).forEach(k=>{if(d.cb||k==='belediye_genel_sekreteri')html+='<option value="'+k+'">'+kurumAdlari[k]+'</option>';});
   html+='</select></div><div class="alan"><label>İl numarası (yalnız il görevlerinde 1–81)</label><input type="number" id="ka_il" min="1" max="81" value="'+(d.belediye_iller||[])[0]+'"></div>'+
    '<div class="alan"><label>Oyuncu adı</label><input type="text" id="ka_kad" placeholder="Oyuncunun kullanıcı adı"></div>'+
    btn('Atama teklifi gönder','kamuAtamaTeklif()','altin')+'</div>';
  }
  html+='<div class="kart"><h2>Atamalarım ve aktif kurum yöneticileri</h2>';
  (d.atamalar||[]).forEach(a=>{
    html+='<div class="kart"><b>'+esc(kurumAdlari[a.gorev]||a.gorev)+'</b>'+
       row('Oyuncu',a.aday)+row('İl',a.il_id||'Türkiye')+row('Durum',a.durum);
    if(a.benim_teklifim&&a.durum==='teklif'){
     html+=btn('Görevi kabul et','kamuAtamaIslem('+a.id+',"cevap_kabul")','altin')+
      btn('Reddet','kamuAtamaIslem('+a.id+',"cevap_ret")');
    }
    if(a.ben_atadim&&a.durum==='teklif')html+=btn('Teklifi geri çek','kamuAtamaIslem('+a.id+',"iptal")');
    if(a.durum==='aktif'&&((a.gorev==='belediye_genel_sekreteri'&&(d.belediye_iller||[]).includes(a.il_id))||
        (a.gorev!=='belediye_genel_sekreteri'&&d.cb)))html+=btn('Görevden al','kamuAtamaIslem('+a.id+',"gorevden_al")');
    html+='</div>';
  });
  html+=(d.atamalar||[]).length?'':para('Henüz atama yok.');
  sayfa('Kamu Atamaları',html+'</div>');
 }catch(err){sayfa('Kamu Atamaları','<div class="kart">'+esc(err.message)+'</div>');}
};
window.kamuAtamaTeklif=async function(){
 try{
  const gorev=document.getElementById('ka_gorev').value;
  const local=['vali','emniyet_muduru','belediye_genel_sekreteri'].includes(gorev);
  await rpc('kamu_kurum_islem',{p_eylem:'teklif',p_gorev:gorev,p_kad:document.getElementById('ka_kad').value,
    p_il:local?Number(document.getElementById('ka_il').value):null});
  toast('Atama teklifi gönderildi.');kamuAtamaEkrani();
 }catch(err){error(err);}
};
window.kamuAtamaIslem=async function(id,eylem){
 try{
  if(!await onayla('Kamu ataması','İşlemi onaylıyor musun?','Onayla'))return;
  await rpc('kamu_kurum_islem',{p_eylem:eylem,p_id:id});toast('Atama kaydı güncellendi.');kamuAtamaEkrani();
 }catch(err){error(err);}
};

window.icraMerkeziEkrani=async function(){
 baslik('İcra ve Haciz');
 try{
  const [bas,all]=await Promise.all([rpc('icra_baslatilabilir'),rpc('icra_dosya_panel')]);
  let html='<div class="kart"><h2>⚖️ İcra ve haciz dairesi</h2>'+
   para('Özel alacakta kesinleşmiş karar ve 7 günlük ödeme emri; kamu alacağında 6183 kapsamında 15 günlük ödeme emri uygulanır. İtiraz incelenirken haciz yapılamaz. Haciz borçla sınırlıdır, kişisel borç için şirket kasasına el konulmaz.')+
   para('Banka veya cüzdan bakiyesi ve piyasa varlığı tahsil edilebilir; taşınmaz ve ortaklık payı kıymet takdiri ardından oyun içi açık artırmaya çıkarılır.')+'</div>';
  if((bas.krediler||[]).length||(bas.vergiler||[]).length){
   html+='<div class="kart"><h2>Yeni takip başlatılabilir</h2>';
   (bas.krediler||[]).forEach(c=>{html+='<div class="kart">'+row('Kredi #'+c.id,c.banka)+'<p>'+esc(c.borclu)+' · '+money(c.kalan)+'</p>'+
    btn('Ödeme emri gönder','icraTakipBaslat("kredi",'+Number(c.id)+')','altin')+'</div>';});
   (bas.vergiler||[]).forEach(c=>{html+='<div class="kart">'+row('Emlak vergisi #'+c.id,c.tip)+'<p>'+esc(c.borclu)+' · '+money(c.tutar)+'</p>'+
    btn('6183 ödeme emri gönder','icraTakipBaslat("emlak_vergisi",'+Number(c.id)+')','altin')+'</div>';});
   html+='</div>';
  }
  html+='<div class="kart"><h2>Takip dosyaları</h2>';
  (all.dosyalar||[]).forEach(d=>{
   const takip=Number(d.id),surdur=(d.durum==='haciz'||d.durum==='teblig'&&new Date(d.odeme_son).getTime()<=Date.now());
   html+='<div class="kart"><b>#'+takip+' · '+esc(d.kaynak)+'</b>'+
    row('Borçlu',d.borclu)+row('Kalan',money(d.kalan))+row('Durum',d.durum)+row('Ödeme sonu',new Date(d.odeme_son).toLocaleString('tr-TR'));
   if(d.itiraz)html+=para('İtiraz: '+esc(d.itiraz));
   if(d.ben_borclu&&d.durum==='teblig'&&Date.now()<new Date(d.odeme_son).getTime())
    html+='<div class="alan"><label>İtirazın</label><textarea id="ic_itiraz_'+takip+'" rows="3"></textarea></div>'+
        btn('Ödeme emrine itiraz et','icraItiraz('+takip+')');
   if(d.ben_hakim&&d.durum==='itiraz'&&!d.ben_borclu){
    html+='<div class="alan"><label>Kararın gerekçesi</label><textarea id="ic_karar_'+takip+'" rows="2"></textarea></div>'+
      btn('İtirazı kabul et','icraItirazKarar('+takip+',false)')+btn('İtirazı reddet','icraItirazKarar('+takip+',true)');
   }
   if(d.ben_alacakli&&surdur&&num(d.kalan)>0){
     html+=btn('Borçlunun haczedilebilir varlıkları','icraVarlikSec('+takip+')','altin');
   }
   html+='</div>';
  });
  html+=(all.dosyalar||[]).length?'':para('Bu hesaba ilişkin takip dosyası yok.');
  html+='</div><div class="kart"><h2>Elektronik haciz satışları</h2>';
  (all.ihaleler||[]).forEach(h=>{
   html+='<div class="kart"><b>İhale #'+Number(h.id)+' · '+esc(h.tur)+'</b>'+
     row('Takdir edilen değer',money(h.deger))+
     row('En yüksek teklif',money(h.teklif))+
     row('İhale bitişi',new Date(h.son).toLocaleString('tr-TR'))+
    '<div class="alan"><label>Teklif (₺)</label><input id="ic_teklif_'+h.id+'" type="number" min="'+Math.ceil(num(h.deger)*.5)+'" value="'+Math.max(Math.ceil(num(h.deger)*.5),Math.ceil(num(h.teklif)*1.01))+'"></div>'+
    btn('Teminatı bloke et ve teklif ver','icraTeklif('+Number(h.id)+')','altin')+
    (h.teklif_veren_benim?btn('Dosya kapandıysa teminat iadesi al','icraTemIade('+Number(h.id)+')'):'')+
    (Date.now()>=new Date(h.son).getTime()?btn('İhaleyi sonuçlandır','icraIhaleBitir('+Number(h.id)+')'):'')+
    '</div>';
  });
  html+=(all.ihaleler||[]).length?'':para('Açık artırma ilanı bulunmuyor.');
  sayfa('İcra ve Haciz',html+'</div>');
 }catch(err){sayfa('İcra ve Haciz','<div class="kart">'+esc(err.message)+'</div>');}
};
window.icraTakipBaslat=async function(k,id){
 try{if(!await onayla('Ödeme emri','Hukuki şartları sağlayan borçluya oyun içi ödeme emri tebliğ edilecek.','Tebliğ et'))return;
 await rpc('icra_takip_ac',{p_kaynak:k,p_kaynak_id:id});toast('Ödeme emri oluşturuldu.');icraMerkeziEkrani();}catch(err){error(err);}
};
window.icraItiraz=async function(id){
 try{await rpc('icra_itiraz_et',{p_id:id,p_gerekce:document.getElementById('ic_itiraz_'+id).value});
 toast('İtiraz kaydedildi; haciz askıya alındı.');icraMerkeziEkrani();}catch(err){error(err);}
};
window.icraItirazKarar=async function(id,red){
 try{const son=await rpc('icra_itiraz_karar',{p_id:id,p_ret:red,p_gerekce:document.getElementById('ic_karar_'+id).value});
 toast(son.durum==='itiraz'?'Oy kaydedildi: kesin karar için aynı yönde iki yargıç oyu gerekli.':'İtiraz kararı kesinleşti.');icraMerkeziEkrani();}catch(err){error(err);}
};
window.icraVarlikSec=async function(id){
 baslik('Haczedilebilir Varlıklar');
 try{
  const a=await rpc('icra_varliklar',{p_id:id});
  let html='<div class="kart"><h2>Dosya #'+id+' · Varlık araştırması</h2>'+
    para('Sadece borç tutarı kadar tahsilat yapılır. Banka ve cüzdanda haciz korumaları uygulanır.')+
    row('Cüzdan',money(a.cuzdan))+btn('Cüzdan haczi uygula','icraHaczet('+id+',"cuzdan")')+
    row('Banka',money(a.bankadaki))+btn('Banka e-haczi uygula','icraHaczet('+id+',"banka")')+'</div>';
  html+='<div class="kart"><h2>Borsa varlıkları</h2>';
  (a.borsa||[]).forEach(x=>{html+=row(x.kod,x.miktar+' × '+money(x.fiyat))+
    btn('Hisse/menkul kıymet haczi','icraHaczet('+id+',"borsa",null,"'+esc(x.kod)+'")');});
  html+='</div><div class="kart"><h2>Şirket ortaklık payları</h2>';
  (a.sirketler||[]).forEach(x=>{html+=row(x.ad,x.pay+'% · '+money(x.deger))+
    btn('Ortaklık payını satışa çıkar','icraHaczet('+id+',"sirket_payi",'+Number(x.id)+')');});
  html+='</div><div class="kart"><h2>Gayrimenkuller</h2>';
  (a.mulk||[]).forEach(x=>{html+=row(x.tip+' #'+x.id,money(x.deger))+
    btn('Kıymet takdiri ve e-satış','icraHaczet('+id+',"gayrimenkul",'+Number(x.id)+')');});
  sayfa('Haciz Varlıkları',html+'</div>'+btn('İcra dosyalarına dön','icraMerkeziEkrani()'));
 }catch(err){sayfa('Haciz Varlıkları','<div class="kart">'+esc(err.message)+'</div>');}
};
window.icraHaczet=async function(id,tur,varlik,kod){
 try{if(!await onayla('Haciz işlemi','Borçlunun varlığına kanuni limitler ve oyun kuralları içinde haciz uygulanacak.','Uygula'))return;
 const r=await rpc('icra_haczet',{p_id:id,p_tur:tur,p_varlik:varlik||null,p_kod:kod||null});
 toast(r.haciz_id?'Varlık açık artırmaya alındı.':'Tahsilat kaydedildi.');icraVarlikSec(id);}catch(err){error(err);}
};
window.icraTeklif=async function(id){
 try{
  const tutar=Number(document.getElementById('ic_teklif_'+id).value);
  if(!await onayla('İcra e-satış','Teklifin için '+money(tutar)+' hesabında bloke edilecek. Geçersen bloke iade edilir.','Teklif ver'))return;
  await rpc('icra_ihale_teklif',{p_haciz:id,p_tutar:tutar});toast('Teklif kaydedildi.');icraMerkeziEkrani();
 }catch(err){error(err);}
};
window.icraIhaleBitir=async function(id){
 try{await rpc('icra_ihale_sonuclandir',{p_haciz:id});toast('İhale sonuçlandırıldı.');icraMerkeziEkrani();}catch(err){error(err);}
};
window.icraTemIade=async function(id){
 try{
  if(!await onayla('Teminat iadesi','Borç tamamen ödenmiş veya vergi yükü nedeniyle geçersiz olmuşsa bloke ettiğin teklif tutarı iade edilir.','İade iste'))return;
  const r=await rpc('icra_ihale_tem_iade',{p_haciz:id});
  toast(money(r.iade)+' teminat iade edildi.');icraMerkeziEkrani();
 }catch(err){error(err);}
};
})();