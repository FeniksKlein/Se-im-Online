/* SEÇİM ONLINE · İÇİŞLERİ KOMUTA MERKEZİ EK SİSTEMLER V2
   Koruma, ihbar, mahkeme, kurum denetimi, ödül, kamu anlaşması, siyasi sorumluluk.
   Yalnız sunucu RPC'lerini kullanır; yetkiler SQL tarafında denetlenir.
*/
(function(){
'use strict';
if(window.SO_ICISLERI_EK_V2)return;
window.SO_ICISLERI_EK_V2=true;
if(typeof window.icisleriKomutaEkrani!=='function')return;
function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function n(v){return Number(v||0).toLocaleString('tr-TR');}
function date(v){return v?new Date(v).toLocaleString('tr-TR'):'—';}
function area(name,min=40,max=900){return '<label>'+esc(name)+'</label><textarea name="'+esc(name==='Gerekçe'?'p_gerekce':name==='Rapor'?'p_rapor':'p_metin')+'" minlength="'+min+'" maxlength="'+max+'" required></textarea>';}
function field(name,label,min=25,max=800){return '<label>'+esc(label)+'</label><textarea name="'+esc(name)+'" minlength="'+min+'" maxlength="'+max+'" required></textarea>';}
function sel(name,label,opts){return '<label>'+esc(label)+'</label><select name="'+esc(name)+'">'+opts.map(a=>'<option value="'+esc(a[0])+'">'+esc(a[1])+'</option>').join('')+'</select>';}
function hidden(name,val){return '<input type="hidden" name="'+esc(name)+'" value="'+esc(val)+'">';}
function form(fn,content,btn){return '<form data-ic-extra="'+esc(fn)+'">'+content+'<button type="submit" class="btn altin">'+esc(btn)+'</button></form>';}
function textRow(title,content){return '<div class="ic-kart"><h3>'+title+'</h3>'+content+'</div>';}
function choice(id){return '<select name="p_hedef" class="ic-extra-kisi" required><option value="">Aşağıdan oyuncu arayıp seç</option></select>';}
function linkedTarget(){return '<label>Hedef oyuncu</label>'+choice();}
function section(title,body){return '<details class="ic-kart" style="margin:10px 0;padding:12px;border:1px solid var(--line2,#556587);border-radius:13px"><summary style="cursor:pointer;font-weight:800;font-size:17px;padding:9px 0">'+esc(title)+'</summary>'+body+'</details>';}
function judgeSelect(){return sel('p_onay','Mahkeme kararı',[['true','Onayla'],['false','Reddet']]);}
function minister(d){return !!d.bakan;}
function formTitle(text){return '<p class="ic-help">'+esc(text)+'</p>';}
function render(d){
 let html='<div id="icExtraUI">';
 html+=section('📋 Dosya ve oyuncu arama',
 '<p class="ic-help">İhbar kesin hüküm değildir. Kurum dosyalarında gerçek oyun şirketleri, dernekler, belediyeler ve makamlar seçilir.</p>'+
 formTitle('Bakan veya oyuncu, olay dosyasını bu menüden görüntüleyebilir. Gerekçeli ve kayıtlı işlemler uygulanır.')+
 '<label>Oyuncu ara</label><input id="icExKisiAra" type="search" placeholder="Oyuncu adının en az 2 harfi" autocomplete="off"><button type="button" class="btn ikinci" data-ic-x-search="kisi">Oyuncu bul</button>'+
 '<label>Şirket, dernek, belediye veya makam ara</label>'+
 sel('kurum_ara_tur','Kurum türü',[['sirket','Şirket'],['dernek','Dernek'],['belediye','Belediye'],['makam','Kamu makamı']])+
 '<input id="icExKurumAra" type="search" placeholder="Kurum adı veya oyuncu" autocomplete="off"><button type="button" class="btn ikinci" data-ic-x-search="kurum">Kurum bul</button>'+
 '<select class="ic-extra-kurum" aria-label="Bulunan kurum"><option value="">Önce kurum ara</option></select>');
 html+=section('📣 Tehdit, yolsuzluk ve usulsüzlük ihbarı',
 form('olay_bildir',
 sel('p_tur','İhbar türü', [['tehdit','Tehdit'],['ihbar','Oyun içi kural ihlali'],['yolsuzluk','Yolsuzluk'],['denetim','Şirket/dernek denetim talebi'],['siyasi','Belediye/siyasi makam sorunu'],['kriz','Güvenlik krizi']])+
 sel('p_kurum_tur','Şikâyet edilen tür', [['oyuncu','Oyuncu'],['sirket','Şirket'],['dernek','Dernek'],['belediye','Belediye'],['makam','Siyasi makam']])+
 '<label>İlgili oyuncu (oyuncu türünde zorunlu)</label>'+choice()+
 '<label>İlgili kurum (kurum türünde zorunlu)</label><select name="p_kurum_id" class="ic-extra-kurum"><option value="">Önce kurum ara</option></select>'+
 '<label>Dosya konusu</label><input name="p_baslik" minlength="18" maxlength="180" required placeholder="Oyun içi olayın kısa açıklaması">'+
 field('p_delil','Olay, işlem numarası, oyun içi delil ve zaman bilgileri (en az 40 karakter)',40,1200),
 'İhbar kaydet'));
 html+=section('🛡️ Oyuncu koruma ve tanık güvenliği',
 form('koruma_basvur',sel('p_tur','Koruma türü',[['koruma','24 saat polis koruması'],['tanik','Tanık koruma (kendi dosyası gerekli)']])+
 '<label>İlgili dosya numarası (tanık korumasında zorunlu)</label><input type="number" min="1" step="1" name="p_olay" placeholder="Dosya #">'+
 field('p_gerekce','Somut koruma gerekçesi (40–800 karakter)',40,800),'Koruma talep et')+
 '<p class="ic-help">Koruma rastgele protesto gözaltısı riskini azaltır; yargı kararıyla yapılan işlemleri engellemez.</p>');
 if(minister(d)){
 html+=section('🏅 Oyuncuyu devlet nişanıyla ödüllendir',
 '<p>Onaylanan ödül: 2.000 TL, +1 kıdem ve oyuncu profilinde devlet nişanı. Günlük sınır 3, aynı oyuncuya 7 günlük bekleme.</p>'+
 form('odul',linkedTarget()+sel('p_tur','Ödül türü',[['kahramanlik','Kamu Güvenliği Kahramanlığı'],['afet','Afet Dayanışma Nişanı'],['kamu_hizmeti','Kamu Hizmeti Nişanı']])+
 field('p_gerekce','Gerçek oyun içi başarı ve resmi gerekçe',40,800),'Ödülü ver'));
 html+=section('🤝 Gerçek oyuncuya kamu hizmeti anlaşması',
 '<p>Gerçek oyuncuya teklif gönderilir, oyuncu kabul eder, faaliyet raporu sunar; Bakanlık tamamlanan işi inceler. Onaylanan faaliyete 4.000 TL ve 0,5 kıdem ödenir.</p>'+
 form('anlasma_teklif',linkedTarget()+sel('p_kurum_tur','Kurum türü',[['oyuncu','Oyuncu'],['sirket','Şirket (kurucusu/yöneticisi olmalı)'],['dernek','Dernek (başkanı olmalı)'],['belediye','Belediye başkanı']])+
 '<label>Şirket / dernek / belediye (oyuncu türünde boş)</label><select name="p_kurum_id" class="ic-extra-kurum"><option value="">Oyuncu / kurum seç</option></select>'+
 sel('p_tur','Proje türü',[['afet','Afet dayanışması'],['guvenlik','Toplumsal güvenlik'],['toplum','Kamu hizmeti']])+
 field('p_aciklama','İşin kapsamı ve teslim şartı (60–900 karakter)',60,900),'Resmî anlaşma teklif et'));
 }
 html+=section('🏛️ Bakanlık hesap verme ve siyasi sorumluluk',
 form('sorumluluk_sor',
 '<label>Özel güvenlik kararı numarası (isteğe bağlı)</label><input name="p_karar" type="number" min="1" step="1">'+
 '<label>Kendi ihbar dosyamın numarası (isteğe bağlı)</label><input name="p_olay" type="number" min="1" step="1">'+
 '<label>Somut siyasi soru</label><input name="p_konu" maxlength="180" minlength="25" required>'+
 field('p_metin','İçişleri Bakanlığının yanıtlaması gereken konu (50–1000 karakter)',50,1000),
 'Yazılı soru gönder')+
 '<p class="ic-help">Siyasi kriz, gösteri müdahalesi ve belediye soruşturmaları için açıklama isteyebilirsin. Yanıtlar Resmî Gazete kaydına girer.</p>');
 const cases=d.olaylar||[];
 html+=section('📂 İhbar, inceleme ve kurum soruşturması dosyaları ('+cases.length+')',
 cases.length?cases.map(x=>{
 let s='<details><summary>#'+Number(x.id)+' · '+esc(x.baslik)+' · '+esc(x.durum)+'</summary>'+
 '<p><b>Tür:</b> '+esc(x.tur)+' / '+esc(x.kurum_tur)+(x.kurum_id?' #'+Number(x.kurum_id):'')+
 ' · <b>Hedef:</b> '+esc(x.hedef_ad||'Belirlenmedi')+'</p>'+
 '<p><b>Delil:</b> '+esc(x.delil)+'</p><p class="ic-help">Açılış: '+date(x.acilis)+' · Bildiren: '+esc(x.basvuran_ad)+'</p>';
 if(x.savunma)s+='<p><b>Oyuncu savunması:</b> '+esc(x.savunma)+'</p>';
 if(x.bakan_gerekce)s+='<p><b>Bakanlık gerekçesi:</b> '+esc(x.bakan_gerekce)+'</p>';
 if(x.beni_ilgilendirir&&['inceleme','adliye'].includes(x.durum)&&!x.savunma)s+=form('olay_savun',hidden('p_id',x.id)+field('p_metin','Savunma ve oyun içi deliller',30,1200),'Savunmamı kaydet');
 if(minister(d)&&['ihbar','inceleme','adliye'].includes(x.durum)){
  s+=form('olay_sevk',hidden('p_id',x.id)+sel('p_islem','Bakanlık işlemi',
   [['inceleme','İncelemeye al'],['adliye','Adliyeye sevk et (önce inceleme)'],['reddedildi','İhbarı reddet'],['kapandi','Dosyayı kapat']])+
   field('p_gerekce','Gerekçeli ve kayıtlı işlem (25–700 karakter)',25,700),'Dosyayı güncelle');
  if(x.durum==='adliye'&&x.hedef){
   s+=form('tedbir_iste',hidden('p_olay',x.id)+sel('p_tur','Bağımsız hâkime önerilecek tedbir',
    [['ifade','Oyuncuyu ifadeye çağır (12 saat)'],['arama','Kurum kayıtlarını inceleme izni'],['gozalti','30 dakikalık gözaltı talebi'],['faaliyet','2 saat şirket kamu işi/ihale kısıtı'],['ihale','12 saat şirket ihale kısıtı'],['ceza','Sınırlı para cezası'],['tazminat','Haksız işlem tazminatı']])+
    '<label>Para cezası veya tazminat (yalnız bunlarda zorunlu, diğerlerinde 0)</label><input type="number" name="p_tutar" min="0" step="1" value="0">'+
    field('p_gerekce','Somut delil ve hâkimden istenen karar (40–1000 karakter)',40,1000),'Hâkime tedbir öner');
  }
 }
 return s+'</details>';
 }).join(''):'<p>Şimdilik görüntülenebilen dosya yok.</p>');
 const protects=d.korumalar||[];
 html+=section('🔐 Koruma kararları ('+protects.length+')',
 protects.map(x=>'<details><summary>#'+Number(x.id)+' · '+esc(x.hedef_ad)+' · '+esc(x.tur)+' · '+esc(x.durum)+'</summary><p>'+esc(x.gerekce)+'</p>'+
 '<p class="ic-help">Başvuru: '+date(x.basvuru_at)+' · Bitiş: '+date(x.bitis)+'</p>'+
 (x.karar_gerekce?'<p>Karar: '+esc(x.karar_gerekce)+'</p>':'')+
 (minister(d)&&x.durum==='bekliyor'?form('koruma_karar',hidden('p_id',x.id)+sel('p_kabul','Karar',[['true','Koruma tahsis et'],['false','Reddet']])+field('p_gerekce','Kararın gerekçesi',25,600),'Koruma kararını ver'):'')+'</details>').join('')||'<p>Henüz koruma kaydı yok.</p>');
 const measures=d.tedbirler||[];
 html+=section('⚖️ Mahkeme, ifade ve avukat ('+measures.length+')',
 measures.map(x=>{
 let s='<details><summary>#'+Number(x.id)+' · '+esc(x.tur)+' · '+esc(x.hedef_ad)+' · '+esc(x.durum)+'</summary>'+
 '<p><b>İlgili dosya:</b> #'+Number(x.olay_id)+' · '+esc(x.gerekce)+'</p>'+
 '<p class="ic-help">Başvuru: '+date(x.acilis)+' · Bitiş: '+date(x.bitis)+' · Tutar: '+n(x.tutar)+' TL</p>';
 if(x.karar_gerekce)s+='<p><b>Hâkim kararı:</b> '+esc(x.karar_gerekce)+'</p>';
 if(x.inceleme_ozet)s+='<p><b>İzinli kurum incelemesi:</b> '+esc(x.inceleme_ozet)+'</p>';
 if(x.ifade)s+='<p><b>Oyuncu ifadesi:</b> '+esc(x.ifade)+'</p>';
 if(x.avukat)s+='<p><b>Avukat:</b> '+esc(x.avukat)+' · '+esc(x.avukat_durum)+'</p>';
 if(x.itiraz_metin)s+='<p><b>İtiraz:</b> '+esc(x.itiraz_metin)+'</p>';
 if(x.itiraz_karar)s+='<p><b>İtiraz kararı:</b> '+esc(x.itiraz_karar)+'</p>';
 if(x.durum==='talep'&&d.hakim)s+=form('tedbir_karar',hidden('p_id',x.id)+judgeSelect()+field('p_gerekce','Bağımsız hâkimin gerekçeli kararı',30,900),'Mahkeme kararını ver');
 if(x.durum==='onay'&&x.tur==='ifade'&&x.benim&&!x.ifade)s+=form('ifade_ver',hidden('p_id',x.id)+field('p_metin','Oyun içi resmî ifade',30,1000),'İfademi gönder');
 if(x.benim&&['talep','onay','itiraz'].includes(x.durum)&&x.avukat_durum!=='kabul'){
  s+=form('avukat_cagir',hidden('p_id',x.id)+
   '<label>Avukat seç</label><select name="p_avukat">'+(d.avukatlar||[]).map(a=>'<option value="'+esc(a.id)+'">'+esc(a.ad)+'</option>').join('')+'</select>'+
   '<button type="button" style="display:none"></button>','Ruhsatlı avukat çağır');
 }
 if(x.avukatim&&x.avukat_durum==='cagrildi')s+=form('avukat_yanit',hidden('p_id',x.id)+sel('p_kabul','Avukatlık daveti',[['true','Kabul et'],['false','Reddet']]),'Davete yanıt ver');
 if(x.durum==='onay'&&x.benim&&x.tur!=='tazminat')s+=form('tedbir_itiraz',hidden('p_id',x.id)+field('p_metin','Mahkemeye itiraz / oyuncunun hakları',30,800),'Karara itiraz et');
 if(x.durum==='itiraz'&&d.hakim)s+=form('tedbir_itiraz_karar',hidden('p_id',x.id)+sel('p_kaldir','İkinci hâkim kararı',[['true','Kaldır / para iadesi'],['false','Mevcut kararı onayla']])+field('p_gerekce','İkinci hâkim gerekçesi',30,800),'İtirazı sonuçlandır');
 return s+'</details>';
 }).join('')||'<p>Aktif mahkeme tedbiri yok. Dosyalara otomatik yaptırım uygulanmaz.</p>');
 const deals=d.anlasmalar||[];
 html+=section('🤝 Kamu hizmeti anlaşmaları ('+deals.length+')',
 deals.map(x=>{
 let s='<details><summary>#'+Number(x.id)+' · '+esc(x.oyuncu_ad)+' · '+esc(x.tur)+' · '+esc(x.durum)+'</summary><p>'+esc(x.aciklama)+'</p>'+
 '<p class="ic-help">'+date(x.olusturma)+' · Destek: '+n(x.odeme)+' TL</p>';
 if(x.rapor)s+='<p><b>Faaliyet raporu:</b> '+esc(x.rapor)+'</p>';
 if(x.karar_gerekce)s+='<p><b>Bakanlık kararı:</b> '+esc(x.karar_gerekce)+'</p>';
 if(x.benim&&x.durum==='teklif')s+=form('anlasma_yanit',hidden('p_id',x.id)+sel('p_kabul','Teklif cevabı',[['true','Kabul et'],['false','Reddet']]),'Yanıtla');
 if(x.benim&&x.durum==='kabul')s+=form('anlasma_rapor',hidden('p_id',x.id)+field('p_rapor','Gerçekleştirdiğin kamu hizmeti',60,900),'Faaliyet raporunu sun');
 if(minister(d)&&x.durum==='tamamlandi')s+=form('anlasma_kapat',hidden('p_id',x.id)+sel('p_onay','Bakanlık kontrolü',[['true','Hizmeti onayla ve öde'],['false','Raporu reddet']])+field('p_gerekce','Gerekçeli inceleme kararı',25,800),'Sonuçlandır');
 return s+'</details>';
 }).join('')||'<p>Henüz anlaşma kaydı yok.</p>');
 html+=section('🗣️ İçişleri Bakanına yöneltilen sorular',
 (d.sorular||[]).map(x=>{
 let s='<details><summary>#'+Number(x.id)+' · '+esc(x.konu)+' · '+esc(x.durum)+'</summary><p>'+esc(x.metin)+'</p><p class="ic-help">'+esc(x.basvuran_ad)+' · '+date(x.zaman)+'</p>';
 if(x.yanit)s+='<p><b>Bakanın cevabı:</b> '+esc(x.yanit)+'</p>';
 if(minister(d)&&x.durum==='bekliyor')s+=form('sorumluluk_yanit',hidden('p_id',x.id)+field('p_metin','Resmî bakanlık yanıtı',50,1200),'Resmî yanıt ver');
 return s+'</details>';
 }).join('')||'<p>Yazılı soru kaydı bulunmuyor.</p>');
 html+=section('🏅 Son kamu ödülleri', (d.oduller||[]).map(x=>
 '<p><b>'+esc(x.hedef_ad)+'</b> · '+esc(x.tur)+' · '+n(x.para)+' TL <small>'+date(x.zaman)+'</small><br>'+esc(x.gerekce)+'</p>').join('')||'<p>Henüz nişan verilmedi.</p>');
 html+=section('⚖️ Haklar ve denetim',
 '<p class="ic-help">İçişleri Bakanının başlattığı soruşturmalar otomatik ceza vermez. Deliller ve gerekçeli kararlar arşivlenir. Hâkim onayı gereken tedbirlerde savunma, ruhsatlı avukat çağrısı ve itiraz hakkı vardır. İtiraz süresince yeni kısıtlayıcı tedbir askıya alınır. Hiçbir yeni işlem oy verme, mesajlaşma, banka veya hesap erişimini kapatmaz. Kolluk ve kamu harcamaları bütçe ve sıklık sınırlarına tabidir.</p>');
 return html+'</div>';
}
const old=window.icisleriKomutaEkrani;
window.icisleriKomutaEkrani=async function(){
 await old.apply(this,arguments);
 const node=document.getElementById('icKomuta');
 if(!node)return;
 try{
  const d=await API.rpc('icisleri_ek_panel');
  const root=document.getElementById('icKomuta');
  if(!root||root.querySelector('#icExtraUI'))return;
  root.insertAdjacentHTML('beforeend',render(d));
 }catch(err){
  const root=document.getElementById('icKomuta');
  if(root&&!root.querySelector('#icExtraUI'))root.insertAdjacentHTML('beforeend','<div class="ic-kart"><h3>Yeni İçişleri sistemleri</h3><p>'+esc(err.message||String(err))+'</p></div>');
 }
};
const rpcMap={
 olay_bildir:['icisleri_olay_bildir',['p_tur','p_kurum_tur','p_kurum_id','p_hedef','p_baslik','p_delil']],
 olay_sevk:['icisleri_olay_sevk',['p_id','p_islem','p_gerekce']],
 olay_savun:['icisleri_olay_savun',['p_id','p_metin']],
 koruma_basvur:['icisleri_koruma_basvur',['p_tur','p_gerekce','p_olay']],
 koruma_karar:['icisleri_koruma_karar',['p_id','p_kabul','p_gerekce']],
 tedbir_iste:['icisleri_tedbir_iste',['p_olay','p_tur','p_gerekce','p_tutar']],
 tedbir_karar:['icisleri_tedbir_karar',['p_id','p_onay','p_gerekce']],
 ifade_ver:['icisleri_ifade_ver',['p_id','p_metin']],
 avukat_cagir:['icisleri_avukat_cagir',['p_id','p_avukat']],
 avukat_yanit:['icisleri_avukat_yanit',['p_id','p_kabul']],
 tedbir_itiraz:['icisleri_tedbir_itiraz',['p_id','p_metin']],
 tedbir_itiraz_karar:['icisleri_tedbir_itiraz_karar',['p_id','p_kaldir','p_gerekce']],
 odul:['icisleri_odul_ver',['p_hedef','p_tur','p_gerekce']],
 anlasma_teklif:['icisleri_anlasma_teklif',['p_oyuncu','p_kurum_tur','p_kurum_id','p_tur','p_aciklama']],
 anlasma_yanit:['icisleri_anlasma_yanit',['p_id','p_kabul']],
 anlasma_rapor:['icisleri_anlasma_rapor',['p_id','p_rapor']],
 anlasma_kapat:['icisleri_anlasma_kapat',['p_id','p_onay','p_gerekce']],
 sorumluluk_sor:['icisleri_sorumluluk_sor',['p_karar','p_olay','p_konu','p_metin']],
 sorumluluk_yanit:['icisleri_sorumluluk_yanit',['p_id','p_metin']]
};
document.addEventListener('submit',async ev=>{
 const f=ev.target.closest&&ev.target.closest('#icExtraUI form[data-ic-extra]');
 if(!f)return;
 ev.preventDefault();ev.stopImmediatePropagation();
 const entry=rpcMap[f.dataset.icExtra];if(!entry)return;
 const data=new FormData(f),args={},button=f.querySelector('button[type="submit"]');
 for(const key of entry[1]){
  let v=data.has(key)?data.get(key):null;
  if(key==='p_oyuncu'&&!v)v=data.get('p_hedef');
  if(key==='p_hedef'&&f.dataset.icExtra==='olay_bildir'&&data.get('p_kurum_tur')!=='oyuncu')v=null;
  if(key==='p_kurum_id'&&data.get('p_kurum_tur')==='oyuncu')v=null;
  if(['p_id','p_olay','p_karar','p_kurum_id','p_tutar'].includes(key))v=v===''||v==null?(key==='p_tutar'?0:null):Number(v);
  if(['p_onay','p_kabul','p_kaldir'].includes(key))v=v==='true';
  args[key]=v;
 }
 if(button)button.disabled=true;
 try{await API.rpc(entry[0],args);if(typeof toast==='function')toast('İşlem kaydedildi.');await window.icisleriKomutaEkrani();}
 catch(err){if(typeof toast==='function')toast(typeof hataCevir==='function'?hataCevir(err.message):err.message,true);if(button)button.disabled=false;}
},true);
document.addEventListener('click',async ev=>{
 const btn=ev.target.closest&&ev.target.closest('#icExtraUI [data-ic-x-search]');
 if(!btn)return;
 btn.disabled=true;
 try{
  const root=document.getElementById('icExtraUI');
  const kind=btn.dataset.icXSearch, search=kind==='kisi'?root.querySelector('#icExKisiAra').value:root.querySelector('#icExKurumAra').value;
  const t=kind==='kisi'?'':root.querySelector('select[name="kurum_ara_tur"]').value;
  const data=await API.rpc(kind==='kisi'?'icisleri_kisi_ara':'icisleri_kurum_ara',kind==='kisi'?{p_ara:search}:{p_tur:t,p_ara:search});
  const options='<option value="">Seç</option>'+(data||[]).map(x=>'<option value="'+esc(x.id)+'">'+esc(x.ad)+'</option>').join('');
  root.querySelectorAll(kind==='kisi'?'.ic-extra-kisi':'.ic-extra-kurum').forEach(s=>s.innerHTML=options);
  if(typeof toast==='function')toast(data.length?'Arama sonuçları yüklendi':'Sonuç bulunamadı',!data.length);
 }catch(err){if(typeof toast==='function')toast(err.message,true);}
 finally{btn.disabled=false;}
},true);
})();
