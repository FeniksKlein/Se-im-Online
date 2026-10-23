/* Seçim Online — Türkiye Barosu · 23.10.2026
   Levhaya yalnız ruhsatlı avukatlar kaydolur; baro binasına yalnız kayıtlı avukatlar girer
   (yönetici denetim amacıyla salt okunur görebilir). Pano/duyuru, avukat bekleyen davalar,
   adli yardım, levha, başkanlık seçimi, disiplin ve aidat. Adliye ekranına ve dava dosyasına eklenir. */
(function(){
'use strict';
if(typeof adliyeHtml!=='function'||typeof adliyeDosya!=='function'||window.BARO_YUKLENDI)return;
window.BARO_YUKLENDI=true;
const h=x=>typeof e==='function'?e(String(x??'')):String(x??'').replace(/[&<>"']/g,'');
const money=n=>Number(n||0).toLocaleString('tr-TR',{maximumFractionDigits:0})+' ₺';
const stamp=d=>d?(typeof tarihSaat==='function'?tarihSaat(d):new Date(d).toLocaleString('tr-TR')):'—';
const RPC=(k,v)=>API.rpc(k,v||{});
const error=err=>toast(typeof hataCevir==='function'?hataCevir(err.message):err.message,true);
const temiz=x=>String(x??'').replace(/['"\\<>&`]/g,'');
const TA='style="width:100%;padding:12px;border-radius:10px;background:var(--bg);border:1px solid var(--line2);outline:none;font-size:16px;resize:vertical"';
const TURLER={hakaret:'Hakaret',iftira:'İftira',rusvet:'Rüşvet',yolsuzluk:'Yolsuzluk',usulsuzluk:'Usulsüz işlem',dolandiricilik:'Dolandırıcılık',diger:'Diğer',tazminat:'Tazminat davası'};
const CEZA={ret:'Şikâyet reddedildi',uyari:'Uyarma',kinama:'Kınama',isten_yasak_3:'3 gün işten yasaklama',isten_yasak_7:'7 gün işten yasaklama'};
const KASA_TUR={ruhsat_payi:'Ruhsat harcı payı',giris:'Giriş keseneği',aidat:'Aidat',adli_yardim:'Adli yardım ücreti'};
let SEKME='pano', SON=null;
function yenile(){if(typeof yenidenCiz==='function')yenidenCiz();else baroEkrani();}

/* ---------- Adliye ekranındaki Baro kartı ---------- */
function baroKart(d){
 let z='<div class="kart cizgili" style="--parti:var(--gold)"><h2>🏛️ '+h(d.ad||'Türkiye Barosu')+'</h2>'
  +'<div class="kv"><span class="k">Levhaya kayıtlı avukat</span><span class="v">'+Number(d.uye_sayi||0)+'</span></div>'
  +'<div class="kv"><span class="k">Baro başkanı</span><span class="v">'+(d.baskan?'Av. '+h(d.baskan)+(d.gecici?' (geçici · en kıdemli üye)':''):'Henüz yok')+'</span></div>'
  +'<div class="kv"><span class="k">Sonraki başkanlık seçimi</span><span class="v">'+h(stamp(d.sonraki_secim))+'</span></div>';
 if(d.icerde){
  z+='<button class="btn altin" onclick="baroAc()">Baro binasına gir'+(d.gozlemci?' (yönetici gözlemi)':'')+'</button>';
 }else if(d.kayit_olabilir){
  z+='<p class="alt" style="margin-top:8px">Ruhsatın aktif. Mesleği icra etmek için levhaya kaydolmalısın. Giriş keseneği '+money(d.giris_ucret)+', aylık aidat '+money(d.aidat)+'.</p>'
   +(d.benim_durum==='silindi'?'<p class="alt" style="color:var(--warn)">Aidat borcu nedeniyle levhadan silinmiştin; yeniden kaydolabilirsin.</p>':'')
   +'<button class="btn altin" onclick="baroKaydol()">Levhaya kaydol</button>';
 }else{
  z+='<p class="alt" style="margin-top:8px">🔒 Baro binasına yalnız ruhsatlı ve levhaya kayıtlı avukatlar girebilir. Avukat olmak için aşağıdaki Hukuk Akademisi adımlarını tamamla ve kontenjandan ruhsat al.</p>';
 }
 return z+'</div>';
}
// Baro kartı mahkeme bölümünün (ve "Dava aç"ın) hemen altına, Parti Sözcüleri'nin üstüne yerleşir.
const BARO_YER=['<div id="adlSozcuYeri"></div>','<div class="kart"><h3>Parti Sözcüleri','<div class="bolum-bas"><h2>Açık davalar'];
const oncekiHtml=adliyeHtml;
adliyeHtml=async function(){
 const [govde,d]=await Promise.all([oncekiHtml(),RPC('baro_durum').catch(()=>null)]);
 if(!d)return govde;
 const kart=baroKart(d);
 for(const y of BARO_YER){const i=govde.indexOf(y);if(i>=0)return govde.slice(0,i)+kart+govde.slice(i);}
 return govde+kart;
};

/* ---------- Eylemler ---------- */
window.baroKaydol=async function(){
 let d=null;try{d=await RPC('baro_durum');}catch(_){}
 const ucret=d?money(d.giris_ucret):'giriş keseneği', aidat=d?money(d.aidat):'';
 if(!await onayla('Türkiye Barosu levhasına kaydol','Giriş keseneği '+ucret+' cüzdanından alınıp baro kasasına aktarılır. Aylık aidat '+aidat+' her 30 günde bir otomatik tahsil edilir; 7 gün ödenmezse levhadan silinirsin.','Kaydol',false))return;
 try{const r=await RPC('baro_kaydol');toast('Levhaya '+r.sicil+' sicil numarasıyla kaydoldun. Hoş geldin, Av.!');
  yenile();}catch(err){error(err);}
};
window.baroAc=()=>ekranAc(baroEkrani);

/* ---------- Baro binası ---------- */
async function baroEkrani(){
 yukleniyor('Türkiye Barosu');
 let d;
 try{const [x,isl]=await Promise.all([RPC('baro_durum'),RPC('hukuk_islerim').catch(()=>null)]);d=x;d.isler=isl;if(isl)window.HUKUK_ISLER=isl;SON=d;}catch(err){iskelet('Türkiye Barosu','<div class="bos">'+h(typeof hataCevir==='function'?hataCevir(err.message):err.message)+'</div>',{geri:true});return;}
 if(!d.icerde){iskelet('Türkiye Barosu','<div class="kart"><h2>🔒 Kapı kapalı</h2><p class="alt">Bu binaya yalnız ruhsatlı ve Türkiye Barosu levhasına kayıtlı avukatlar girebilir.</p>'
  +(d.kayit_olabilir?'<button class="btn altin" onclick="baroKaydol()">Levhaya kaydol</button>':'<button class="btn ikinci" onclick="geriGit()">Adliye\'ye dön</button>')+'</div>',{geri:true});return;}
 const sek=[['pano','Pano'],['davalar','Davalar'],['levha','Levha'],['secim','Seçim'],['disiplin','Disiplin'],['hesap','Hesabım']];
 const bekAdli=(d.adli_yardim||[]).filter(x=>x.durum==='bekliyor').length, bekDis=(d.disiplin||[]).filter(x=>x.karar_verebilirim).length;
 const bekIs=((d.isler||{}).acik||[]).length+((d.isler||{}).ustlendigim||[]).filter(j=>j.durum==='vekil_atandi').length;
 const rozet=k=>k==='davalar'&&(bekIs||(bekAdli&&d.baskanim))?' ('+(bekIs+(d.baskanim?bekAdli:0))+')':k==='disiplin'&&bekDis?' ('+bekDis+')':'';
 let z='<div class="kart"><div class="baslik"><b>🏛️ '+h(d.ad)+'</b>'+(d.baskanim?'<span class="rozet altin">Baro başkanısın'+(d.gecici?' (geçici)':'')+'</span>':d.gozlemci?'<span class="rozet sari">Yönetici gözlemi</span>':'')+'</div>'
  +'<div class="kv"><span class="k">Başkan</span><span class="v">'+(d.baskan?'Av. '+h(d.baskan)+(d.gecici?' · geçici (en kıdemli üye)':''):'—')+'</span></div>'
  +'<div class="kv"><span class="k">Üye</span><span class="v">'+Number(d.uye_sayi)+' avukat</span></div>'
  +'<div class="kv"><span class="k">Baro kasası</span><span class="v">'+money(d.kasa)+'</span></div></div>'
  +'<div class="segment" style="margin:0 0 12px">'+sek.map(([k,a])=>'<button class="'+(SEKME===k?'aktif':'')+'" onclick="baroSekme(\''+k+'\')">'+a+rozet(k)+'</button>').join('')+'</div>';
 z+=({pano:panoHtml,davalar:davalarHtml,levha:levhaHtml,secim:secimHtml,disiplin:disiplinHtml,hesap:hesapHtml}[SEKME]||panoHtml)(d);
 iskelet('Türkiye Barosu',z,{geri:true});
}
window.baroEkrani=baroEkrani;
window.baroSekme=k=>{SEKME=k;baroEkrani();};

function panoHtml(d){
 let z='<div class="kart"><h3>📌 Duyurular</h3>';
 if(d.baskanim)z+='<div class="alan"><textarea id="baroDuyuruMetin" rows="3" maxlength="1000" placeholder="Bütün üyelere bildirim olarak gider" '+TA+'></textarea></div><button class="btn altin" onclick="baroMesaj(true)">Duyuru yayımla</button>';
 z+=(d.duyurular||[]).map(m=>'<div class="liste-satir"><div class="orta"><b>Başkan Av. '+h(m.yazar)+'</b><p style="white-space:pre-wrap;margin-top:4px">'+h(m.metin)+'</p><div class="kucuk">'+h(stamp(m.zaman))+'</div></div>'+(m.silebilirim?'<button class="btn ikinci" style="width:auto" onclick="baroMesajSil('+m.id+')">Sil</button>':'')+'</div>').join('')
  +(!(d.duyurular||[]).length?'<p class="alt">Henüz duyuru yok.</p>':'')+'</div>';
 z+='<div class="kart"><h3>💬 Meslektaşlar panosu</h3><p class="alt">Yalnız levhaya kayıtlı avukatlar okur ve yazar.</p>';
 if(d.uyeyim)z+='<div class="alan"><textarea id="baroMesajMetin" rows="2" maxlength="1000" placeholder="Meslektaşlarına yaz…" '+TA+'></textarea></div><button class="btn" onclick="baroMesaj(false)">Gönder</button>';
 z+=(d.mesajlar||[]).map(m=>'<div class="liste-satir"><div class="orta"><b>Av. '+h(m.yazar)+(m.benim?' (sen)':'')+'</b><p style="white-space:pre-wrap;margin-top:4px">'+h(m.metin)+'</p><div class="kucuk">'+h(stamp(m.zaman))+'</div></div>'+(m.silebilirim?'<button class="btn ikinci" style="width:auto" onclick="baroMesajSil('+m.id+')">Sil</button>':'')+'</div>').join('')
  +(!(d.mesajlar||[]).length?'<p class="alt">Pano boş. İlk mesajı sen yaz.</p>':'')+'</div>';
 return z;
}
window.baroMesaj=async duyuru=>{
 const el=document.getElementById(duyuru?'baroDuyuruMetin':'baroMesajMetin');
 const metin=(el&&el.value||'').trim();if(!metin)return toast('Önce bir şey yaz.',true);
 try{await RPC('baro_mesaj_gonder',{p_metin:metin,p_duyuru:!!duyuru});toast(duyuru?'Duyuru bütün üyelere gönderildi.':'Mesaj panoya eklendi.');yenile();}catch(err){error(err);}
};
window.baroMesajSil=async id=>{
 if(!await onayla('Mesajı sil','Mesaj panodan kaldırılacak.','Sil',true))return;
 try{await RPC('baro_mesaj_sil',{p_mesaj:id});toast('Mesaj silindi.');yenile();}catch(err){error(err);}
};

function islerHtml(d){
 const v=d.isler||{},kart=window.hukukIsKart;
 if(typeof kart!=='function')return '';
 const ust=(v.ustlendigim||[]),acik=(v.acik||[]);
 return '<div class="kart"><h3>📂 Avukat arayan hukuki işler ('+acik.length+')</h3><p class="alt">Dava açmak, seçim sonucuna itiraz etmek ya da parti kapatma davasında savunma vermek isteyenlerin talepleri. Teklifin kabul edilirse ücret emanete alınır; dilekçeyi mahkemeye sunduğunda sana geçer.</p>'
  +(acik.length?acik.map(j=>kart(j,'acik')).join(''):'<p class="alt">Şu an avukat arayan iş yok.</p>')+'</div>'
  +(ust.length?'<div class="kart"><h3>🗂️ Üstlendiğim işler</h3>'+ust.map(j=>kart(j,'avukat')).join('')+'</div>':'');
}
function davalarHtml(d){
 const ben=d.ben||{};
 let z=islerHtml(d)+'<div class="kart"><h3>🔎 Avukat bekleyen davalar ('+(d.bekleyen_davalar||[]).length+')</h3><p class="alt">Açık davalarda vekili olmayan taraflar. Dosyayı açıp ilgili tarafa ücret teklifi verebilirsin.'+(ben.calisabilir===false&&ben.engel?' <b style="color:var(--warn)">'+h(ben.engel)+'</b>':'')+'</p>'
  +(d.bekleyen_davalar||[]).map(x=>'<div class="liste-satir"><div class="orta"><b>Dosya #'+x.id+' · '+h(TURLER[x.tur]||x.tur)+'</b><div class="kucuk">'+h(x.davaci||'—')+' → '+h(x.davali||'—')+'</div>'
   +'<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:5px">'+(x.davaci_bos?'<span class="rozet">Davacı vekili aranıyor</span>':'')+(x.davali_bos?'<span class="rozet">Davalı vekili aranıyor</span>':'')
   +(x.adli_yardim?'<span class="rozet sari">Adli yardım talebi</span>':'')+(x.teklif?'<span class="rozet">'+x.teklif+' bekleyen teklif</span>':'')+(x.taraf_miyim?'<span class="rozet kirmizi">Tarafısın</span>':'')+'</div>'
   +'<div class="kucuk">Savunma süresi: '+h(stamp(x.savunma_son))+'</div></div><button class="btn ikinci" style="width:auto" onclick="ekranAc(()=>adliyeDosya('+x.id+'))">Dosyayı aç</button></div>').join('')
  +(!(d.bekleyen_davalar||[]).length?'<p class="alt">Şu an avukat bekleyen açık dava yok.</p>':'')+'</div>';
 const adli=d.adli_yardim||[];
 z+='<div class="kart"><h3>🤝 Adli yardım</h3><p class="alt">Cüzdanında '+money(d.adli_yardim_sinir)+'\'den az parası olan taraflar dava dosyasından ücretsiz avukat isteyebilir. Başkan gönüllü bir avukatı görevlendirir; avukata baro kasasından '+money(d.adli_yardim_ucret)+' ödenir (başkan kendini görevlendirirse ücret ödenmez).</p>'
  +adli.map(y=>'<div class="liste-satir"><div class="orta"><b>Dosya #'+y.dava+' · '+(y.taraf==='davaci'?'Davacı':'Davalı')+' · '+h(y.talep_eden)+'</b>'
   +'<div class="kucuk">'+h({bekliyor:'Görevlendirme bekliyor',atandi:'Av. '+(y.avukat||'')+' görevlendirildi'+(Number(y.ucret)?' · '+money(y.ucret):''),ret:'Reddedildi',iptal:'Düştü'}[y.durum]||y.durum)+' · '+h(stamp(y.zaman))+'</div>'
   +(y.gerekce?'<p class="kucuk">Talep: '+h(y.gerekce)+'</p>':'')+(y.karar_gerekce?'<p class="kucuk">Karar: '+h(y.karar_gerekce)+'</p>':'')+'</div>'
   +(d.baskanim&&y.durum==='bekliyor'?'<button class="btn altin" style="width:auto" onclick="baroAdliKararModal('+y.id+')">Karar ver</button>':'')+'</div>').join('')
  +(!adli.length?'<p class="alt">Henüz adli yardım talebi yok.</p>':'')+'</div>';
 return z;
}
window.baroAdliKararModal=id=>{
 const d=SON||{},y=(d.adli_yardim||[]).find(x=>x.id===id);if(!y)return;
 const g=d.gonulluler||[];
 const m=modal('<p class="alt">Dosya #'+y.dava+' · '+h(y.talep_eden)+' · '+(y.taraf==='davaci'?'davacı':'davalı')+' tarafı</p><p class="alt">Talep: '+h(y.gerekce)+'</p>'
  +(g.length?'<div class="alan"><label>Görevlendirilecek avukat</label><select id="baroAdliAvukat">'+g.map(a=>'<option value="'+h(a.id)+'">Av. '+h(a.kad)+(a.baskan?' (kendim · ücretsiz)':' · gönüllü')+'</option>').join('')+'</select></div>'
    +'<div class="alan"><label>Not (isteğe bağlı)</label><input id="baroAdliNot" maxlength="300"></div><button class="btn altin" id="baroAdliAta">Görevlendir</button>':'<p class="alt">Gönüllü avukat yok. Üyeler Hesabım sekmesinden adli yardım gönüllüsü olabilir.</p>')
  +'<div class="alan"><label>Ret gerekçesi</label><input id="baroAdliRet" maxlength="500" placeholder="En az 10 karakter"></div><button class="btn tehlike" id="baroAdliReddet">Talebi reddet</button>');
 adlFormBaslik(m,'Adli yardım talebi');
 const ata=m.querySelector('#baroAdliAta');
 if(ata)ata.onclick=async()=>{try{const r=await RPC('baro_adli_yardim_karar',{p_talep:id,p_avukat:m.querySelector('#baroAdliAvukat').value,p_gerekce:m.querySelector('#baroAdliNot').value});modalKapat();toast(r.durum==='atandi'?'Avukat görevlendirildi.':'Talep düştü (dava kapandı ya da taraf avukat tuttu).');yenile();}catch(err){error(err);}};
 m.querySelector('#baroAdliReddet').onclick=async()=>{try{await RPC('baro_adli_yardim_karar',{p_talep:id,p_avukat:null,p_gerekce:m.querySelector('#baroAdliRet').value});modalKapat();toast('Talep reddedildi.');yenile();}catch(err){error(err);}};
};

function dis(dd){const p=[];if(dd&&dd.uyari)p.push(dd.uyari+' uyarı');if(dd&&dd.kinama)p.push(dd.kinama+' kınama');if(dd&&dd.yasak)p.push(dd.yasak+' yasak');return p.join(', ');}
function levhaHtml(d){
 const l=d.levha||[];
 return '<div class="kart"><h3>📜 Baro levhası ('+l.length+')</h3><p class="alt">Sicil numarası kayıt sırasını gösterir; geçici başkanlık en küçük sicilli üyededir.</p>'
  +l.map(u=>'<div class="liste-satir"><div class="orta"><b>Av. '+h(u.kad)+'</b> <span class="rozet altin">Sicil '+h(u.sicil)+'</span>'+(u.baskan?' <span class="rozet yesil">Başkan</span>':'')+(u.gonullu?' <span class="rozet">Adli yardım gönüllüsü</span>':'')
   +'<div class="kucuk">'+h(u.il||'')+' · '+h(u.burosu||'Bağımsız')+' · '+Number(u.aktif_dosya||0)+' aktif dosya · Kayıt: '+h(stamp(u.kayit))+'</div>'
   +(dis(u.disiplin)?'<div class="kucuk" style="color:var(--warn)">Disiplin sicili: '+h(dis(u.disiplin))+'</div>':'')
   +(u.yasak_bitis?'<div class="kucuk" style="color:var(--al2)">İşten yasaklı: '+h(stamp(u.yasak_bitis))+'\'e kadar</div>':'')+'</div></div>').join('')
  +(!l.length?'<p class="alt">Levha boş.</p>':'')+'</div>';
}

function secimHtml(d){
 const s=d.secim, simdiMs=typeof simdi==='function'?simdi():Date.now();
 let z='<div class="kart"><h3>🗳️ Baro başkanlığı seçimi</h3><p class="alt">Her ay yapılır: adaylık ayın 15\'i 00:00 ile 20\'si 10:00 arası, oylama 20\'si 10:00–20:00 (Türkiye saati). Aday olmak için mesleği icra edebilen bir üye olmalısın; oylama başlamadan önce kayıtlı her üyenin bir oyu vardır. Eşitlikte kıdemli (küçük sicilli) aday kazanır. Aday çıkmazsa mevcut başkan devam eder.</p>'
  +'<div class="kv"><span class="k">Sonraki oylama</span><span class="v">'+h(stamp(d.sonraki_secim))+'</span></div></div>';
 if(!s||(s.durum==='bitti'||s.durum==='iptal')&&new Date(s.oy_son).getTime()<simdiMs-30*864e5){
  return z+'<div class="kart"><p class="alt">Bu ay henüz seçim takvimi açılmadı.</p></div>';
 }
 const DUR={aday:'Adaylık dönemi',oy:'Oylama sürüyor',bitti:'Sonuçlandı',iptal:'Aday çıkmadı'};
 z+='<div class="kart"><div class="baslik"><b>Dönem '+h(s.donem)+'</b><span class="rozet'+(s.durum==='oy'?' kirmizi':'')+'">'+h(DUR[s.durum]||s.durum)+'</span></div>'
  +'<p class="kucuk">Oylama: '+h(stamp(s.oy_bas))+' – '+h(stamp(s.oy_son))+'</p>';
 if(s.durum==='bitti'){
  z+='<p style="margin-top:8px"><b>Kazanan: Av. '+h(s.kazanan||'—')+'</b> · Katılım: '+Number(s.katilim||0)+' oy</p>'
   +(s.sonuc||[]).map(r=>'<div class="kv"><span class="k">Av. '+h(r.aday)+'</span><span class="v">'+Number(r.oy)+' oy</span></div>').join('');
 }else{
  z+=(s.adaylar||[]).map(a=>'<div class="liste-satir"><div class="orta"><b>Av. '+h(a.kad)+(a.benim?' (sen)':'')+'</b><p class="alt" style="white-space:pre-wrap">'+h(a.vaat)+'</p></div>'
    +(s.durum==='oy'&&s.oy_hakkim&&!s.oyum?'<button class="btn altin" style="width:auto" onclick="baroOyVer(\''+h(a.id)+'\',\''+h(temiz(a.kad))+'\')">Oy ver</button>':'')+'</div>').join('')
   +(!(s.adaylar||[]).length?'<p class="alt">Henüz aday yok.</p>':'');
  if(s.durum==='oy')z+=s.oyum?'<p class="alt" style="margin-top:8px">Oyunu Av. '+h(s.oyum)+' için kullandın.</p>':!s.oy_hakkim?'<p class="alt" style="margin-top:8px">Oylama başladıktan sonra kaydolduğun için bu seçimde oy hakkın yok.</p>':'';
  if(s.durum==='aday'&&d.uyeyim){
   z+=s.adayim?'<button class="btn tehlike" onclick="baroAdaylikCekil()">Adaylıktan çekil</button><button class="btn ikinci" onclick="baroAdayModal()">Vaadimi güncelle</button>'
    :'<button class="btn altin" onclick="baroAdayModal()">Başkanlığa aday ol</button>';
  }
 }
 return z+'</div>';
}
window.baroAdayModal=()=>{
 const m=modal('<p class="alt">Vaadin bütün üyelere görünür. Adaylık döneminde istediğin kadar güncelleyebilirsin.</p><div class="alan"><label>Seçim vaadi (10–600 karakter)</label><textarea id="baroVaat" rows="5" maxlength="600" '+TA+'></textarea></div><button class="btn altin" id="baroAdayGonder">Adaylığımı açıkla</button>');
 adlFormBaslik(m,'Baro başkanlığı adaylığı');
 m.querySelector('#baroAdayGonder').onclick=async()=>{try{await RPC('baro_aday_ol',{p_vaat:m.querySelector('#baroVaat').value});modalKapat();toast('Adaylığın açıklandı.');yenile();}catch(err){error(err);}};
};
window.baroAdaylikCekil=async()=>{
 if(!await onayla('Adaylıktan çekil','Adaylığın geri alınır; dönem bitmeden yeniden aday olabilirsin.','Çekil',true))return;
 try{await RPC('baro_adaylik_cekil');toast('Adaylıktan çekildin.');yenile();}catch(err){error(err);}
};
window.baroOyVer=async(id,ad)=>{
 if(!await onayla('Oyunu kullan','Av. '+ad+' için oy vereceksin. Oy değiştirilemez.','Oy ver',false))return;
 try{await RPC('baro_oy_ver',{p_aday:id});toast('Oyun kaydedildi.');yenile();}catch(err){error(err);}
};

function disiplinHtml(d){
 const l=d.disiplin||[];
 return '<div class="kart"><h3>⚖️ Disiplin kurulu</h3><p class="alt">Müvekkiller ve dosya tarafları avukatı dava dosyasından baroya şikâyet eder. Başkan uyarma, kınama ya da 3/7 gün işten yasaklama verebilir; işten yasaklanan avukatın açık dosyalardaki vekâleti biter. Başkan kendisi hakkındaki şikâyete karar veremez. Kararlar bütün üyelere açıktır.</p>'
  +l.map(x=>'<div class="liste-satir"><div class="orta"><b>Av. '+h(x.avukat)+'</b> <span class="rozet'+(x.durum==='bekliyor'?' sari':x.ceza&&x.ceza!=='ret'?' kirmizi':'')+'">'+h(x.durum==='bekliyor'?'İnceleniyor':CEZA[x.ceza]||x.ceza)+'</span>'
   +'<div class="kucuk">Dosya #'+h(x.dava||'—')+' · '+h(stamp(x.zaman))+(x.sikayetci?' · Şikâyetçi: '+h(x.sikayetci):'')+'</div>'
   +(x.metin?'<p class="kucuk" style="white-space:pre-wrap">Şikâyet: '+h(x.metin)+'</p>':'')
   +(x.karar_gerekce?'<p class="kucuk">Gerekçe: '+h(x.karar_gerekce)+'</p>':'')
   +(x.bitis?'<p class="kucuk">Yasak bitişi: '+h(stamp(x.bitis))+'</p>':'')+'</div>'
   +(x.karar_verebilirim?'<button class="btn altin" style="width:auto" onclick="baroDisiplinModal('+x.id+')">Karar ver</button>':'')+'</div>').join('')
  +(!l.length?'<p class="alt">Disiplin kaydı yok.</p>':'')+'</div>';
}
window.baroDisiplinModal=id=>{
 const x=((SON||{}).disiplin||[]).find(k=>k.id===id);if(!x)return;
 const m=modal('<p class="alt">Av. '+h(x.avukat)+' · Dosya #'+h(x.dava||'—')+'</p><p class="alt" style="white-space:pre-wrap">'+h(x.metin||'')+'</p>'
  +'<div class="alan"><label>Karar</label><select id="baroDisCeza">'+Object.entries(CEZA).map(([k,v])=>'<option value="'+k+'">'+h(v)+'</option>').join('')+'</select></div>'
  +'<div class="alan"><label>Gerekçe (20–1000 karakter, üyelere açık)</label><textarea id="baroDisGerekce" rows="4" maxlength="1000" '+TA+'></textarea></div><button class="btn altin" id="baroDisGonder">Kararı açıkla</button>');
 adlFormBaslik(m,'Disiplin kararı');
 m.querySelector('#baroDisGonder').onclick=async()=>{try{await RPC('baro_sikayet_karar',{p_sikayet:id,p_ceza:m.querySelector('#baroDisCeza').value,p_gerekce:m.querySelector('#baroDisGerekce').value});modalKapat();toast('Disiplin kararı açıklandı.');yenile();}catch(err){error(err);}};
};

function hesapHtml(d){
 const b=d.ben;
 if(!b)return '<div class="kart"><p class="alt">Bu bölüm yalnız levhaya kayıtlı üyeler içindir.</p></div>';
 const kalanGun=Math.ceil((new Date(b.aidat_bitis).getTime()-Date.now())/864e5);
 return '<div class="kart"><h3>🪪 Üyelik</h3>'
  +'<div class="kv"><span class="k">Sicil numarası</span><span class="v">'+h(b.sicil)+'</span></div>'
  +'<div class="kv"><span class="k">İlk kayıt</span><span class="v">'+h(stamp(b.ilk_kayit))+'</span></div>'
  +'<div class="kv"><span class="k">Mesleği icra</span><span class="v">'+(b.calisabilir?'✅ Serbest':'⛔ '+h(b.engel||'Engelli'))+'</span></div>'
  +'<div class="kv"><span class="k">Aidat ödendiği tarih</span><span class="v">'+h(stamp(b.aidat_bitis))+(kalanGun<0?' · <span style="color:var(--al2)">gecikmede</span>':'')+'</span></div>'
  +'<p class="kucuk">Aylık aidat '+money(d.aidat)+'; süresi dolunca cüzdanından otomatik alınır. En fazla 3 ay peşin ödenebilir.</p>'
  +'<button class="btn ikinci" onclick="baroAidatOde()">1 aylık aidatı peşin öde</button>'
  +'<div class="kv" style="margin-top:10px"><span class="k">Adli yardım gönüllüsü</span><span class="v">'+(b.gonullu?'Evet':'Hayır')+'</span></div>'
  +'<p class="kucuk">Gönüllüler, ödeme gücü olmayan oyunculara başkan tarafından ücretsiz avukat olarak atanabilir; ücretini baro kasası öder.</p>'
  +'<button class="btn '+(b.gonullu?'ikinci':'altin')+'" onclick="baroGonullu('+(!b.gonullu)+')">'+(b.gonullu?'Gönüllülükten çık':'Adli yardım gönüllüsü ol')+'</button></div>'
  +'<div class="kart"><h3>💼 Baro kasası hareketleri</h3><p class="alt">Kasa; ruhsat harçlarının %25\'i, giriş keseneği ve aidatlarla dolar; adli yardım ücretlerine harcanır. Herkes için şeffaftır.</p>'
  +(d.kasa_hareket||[]).map(k=>'<div class="kv"><span class="k">'+h(KASA_TUR[k.tur]||k.tur)+'<div class="kucuk">'+h(k.aciklama)+' · '+h(stamp(k.zaman))+'</div></span><span class="v" style="color:'+(Number(k.tutar)<0?'var(--al2)':'var(--good)')+'">'+(Number(k.tutar)>0?'+':'')+money(k.tutar)+'</span></div>').join('')
  +(!(d.kasa_hareket||[]).length?'<p class="alt">Henüz hareket yok.</p>':'')+'</div>'
  +'<div class="kart"><button class="btn tehlike" onclick="baroAyril()">Barodan ayrıl</button><p class="kucuk">Ayrılırsan mesleği icra edemezsin ve açık dosyalardaki vekâletlerin biter. Ruhsatın kontenjanda kalır; yeniden kaydolabilirsin.</p></div>';
}
window.baroAidatOde=async()=>{try{const r=await RPC('baro_aidat_ode');toast('Aidat ödendi · yeni tarih: '+stamp(r.aidat_bitis));yenile();}catch(err){error(err);}};
window.baroGonullu=async v=>{try{await RPC('baro_gonullu',{p_acik:!!v});toast(v?'Adli yardım gönüllüsü oldun.':'Gönüllülükten çıktın.');yenile();}catch(err){error(err);}};
window.baroAyril=async()=>{
 if(!await onayla('Barodan ayrıl','Mesleği icra edemezsin; açık dosyalardaki vekâletlerin biter. Yeniden kaydolurken giriş keseneği tekrar alınır.','Ayrıl',true))return;
 try{const r=await RPC('baro_ayril');toast('Barodan ayrıldın'+(r.kapanan_vekalet?' · '+r.kapanan_vekalet+' vekâlet sona erdi':'')+'.');geriGit();}catch(err){error(err);}
};

/* ---------- Dava dosyasında Baro kartı (adli yardım + şikâyet) ---------- */
const oncekiDosya=adliyeDosya;
adliyeDosya=async function(id){
 await oncekiDosya(id);
 try{
  const root=document.getElementById('icerik');if(!root)return;
  const b=await RPC('baro_dava_bilgi',{p_dava:id});
  if(document.getElementById('icerik')!==root)return;
  let z='';
  if(b.benim_taraf&&b.dava_acik&&!b.vekilim_var){
   const bek=(b.talepler||[]).find(t=>t.durum==='bekliyor'&&t.taraf===b.benim_taraf);
   if(bek)z+='<p class="alt">Adli yardım talebin başkanın kararını bekliyor.</p>';
   else if(Number(b.baro_uye_sayi)===0)z+='<p class="alt">Baroya henüz kayıtlı avukat olmadığı için adli yardım verilemiyor.</p>';
   else if(b.cuzdan!=null&&Number(b.cuzdan)<Number(b.sinir))z+='<p class="alt">Avukat tutacak paran yoksa Türkiye Barosu\'ndan ücretsiz avukat isteyebilirsin.</p><button class="btn altin" onclick="baroAdliIste('+id+')">Adli yardım iste (ücretsiz avukat)</button>';
   else z+='<p class="kucuk">Adli yardım yalnız cüzdanında '+money(b.sinir)+'\'den az parası olanlara verilir.</p>';
  }
  const benim=(b.talepler||[]).filter(t=>t.durum!=='bekliyor');
  if(benim.length)z+=benim.map(t=>'<p class="kucuk">Adli yardım: '+h({atandi:'Av. '+(t.avukat||'')+' görevlendirildi',ret:'reddedildi'+(t.karar_gerekce?' ('+t.karar_gerekce+')':''),iptal:'düştü'}[t.durum]||t.durum)+'</p>').join('');
  if((b.sikayet_edilebilir||[]).length)z+='<details style="margin-top:8px"><summary style="cursor:pointer;font-weight:700;font-size:13.5px">Bir avukatı baroya şikâyet et</summary>'
   +b.sikayet_edilebilir.map(a=>'<button class="btn ikinci" onclick="baroSikayetModal(\''+h(a.id)+'\','+id+',\''+h(temiz(a.kad))+'\')">Av. '+h(a.kad)+' hakkında şikâyet</button>').join('')+'</details>';
  if(!z)return;
  const kart=document.createElement('div');kart.className='kart';kart.id='baroDavaKart';
  kart.innerHTML='<h3>🏛️ Türkiye Barosu</h3>'+z;
  const eski=root.querySelector('#baroDavaKart');if(eski)eski.remove();
  const panel=root.querySelector('#avukatHukukPanel');
  if(panel)panel.insertAdjacentElement('afterend',kart);else root.insertAdjacentElement('afterbegin',kart);
 }catch(err){console.warn('Baro dosya kartı:',err.message);}
};
window.baroAdliIste=id=>{
 const m=modal('<p class="alt">Talebin baro başkanına ve gönüllü avukatlara bildirilir. Görevlendirilen avukat sana ücretsiz vekâlet eder; ücretini baro kasası öder.</p><div class="alan"><label>Neden avukata ihtiyacın var? (10–500 karakter)</label><textarea id="baroAdliGerekce" rows="4" maxlength="500" '+TA+'></textarea></div><button class="btn altin" id="baroAdliGonder">Talep gönder</button>');
 adlFormBaslik(m,'Dava #'+id+' · Adli yardım talebi');
 m.querySelector('#baroAdliGonder').onclick=async()=>{try{await RPC('baro_adli_yardim_iste',{p_dava:id,p_gerekce:m.querySelector('#baroAdliGerekce').value});modalKapat();toast('Adli yardım talebin baroya iletildi.');await adliyeDosya(id);}catch(err){error(err);}};
};
window.baroSikayetModal=(avukat,dava,ad)=>{
 const m=modal('<p class="alt">Şikâyetin baro başkanına gider; avukata şikâyet yapıldığı bildirilir. Asılsız şikâyetler reddedilir. Aynı avukat hakkında aynı anda yalnız bir bekleyen şikâyetin olabilir.</p><div class="alan"><label>Şikâyet (30–1500 karakter)</label><textarea id="baroSikayetMetin" rows="5" maxlength="1500" '+TA+'></textarea></div><button class="btn tehlike" id="baroSikayetGonder">Şikâyeti gönder</button>');
 adlFormBaslik(m,'Av. '+ad+' · Baroya şikâyet');
 m.querySelector('#baroSikayetGonder').onclick=async()=>{try{await RPC('baro_sikayet_et',{p_avukat:avukat,p_dava:dava,p_metin:m.querySelector('#baroSikayetMetin').value});modalKapat();toast('Şikâyetin baroya iletildi.');}catch(err){error(err);}};
};
})();
