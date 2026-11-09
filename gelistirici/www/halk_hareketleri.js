/* SO_HALK_HAREKETLERI_V1 — web ve mobil ortak ekran */
/* 08.11.2026 · Halk Hareketleri formları okunur: koyu zemin, açık yazı, alt alta etiketler (iOS/Android) */
(function(){
 if(typeof document==='undefined'||document.getElementById('hh-temel-form-okunur'))return;
 var F='form.hhFon,form#hhYeni,form.hhYanit,form.hhKarar,form.hhKararYanit,form.hhTalep';
 var k=function(x){return F.split(',').map(function(f){return f+' '+x;}).join(',');};
 var st=document.createElement('style');st.id='hh-temel-form-okunur';
 st.textContent=[
  F+'{display:flex!important;flex-direction:column!important;align-items:stretch!important;gap:8px!important;width:100%!important;margin:12px 0 0!important;box-sizing:border-box!important}',
  k('label')+'{display:block!important;width:100%!important;margin:6px 0 0!important;color:#eef2ff!important;font-size:15px!important;font-weight:600!important;line-height:1.45!important}',
  k('select')+','+k('input')+','+k('textarea')+'{display:block!important;width:100%!important;max-width:100%!important;box-sizing:border-box!important;min-height:48px!important;margin:0!important;padding:12px 14px!important;font:400 16px/1.4 system-ui,-apple-system,sans-serif!important;color:#f5f7ff!important;-webkit-text-fill-color:#f5f7ff!important;background:#111a34!important;border:1px solid #7180ab!important;border-radius:12px!important;opacity:1!important;box-shadow:none!important}',
  k('select')+'{color-scheme:dark!important;-webkit-appearance:menulist!important;appearance:auto!important}',
  k('option')+'{color:#f5f7ff!important;background:#111a34!important}',
  k('textarea')+'{min-height:110px!important;resize:vertical!important}',
  k('input::placeholder')+','+k('textarea::placeholder')+'{color:#b6c1da!important;-webkit-text-fill-color:#b6c1da!important;opacity:1!important}',
  k('button')+'{width:100%!important;min-height:48px!important;margin-top:8px!important;white-space:normal!important}',
  k('p')+'{color:#d7ddf3!important}'
 ].join('\n');
 (document.head||document.documentElement).appendChild(st);
})();
async function sokakHareketleriEkrani(){
 yukleniyor('Halk Hareketleri');
 try {
  const d=await API.rpc('sokak_uzlasma_panel'),a=d.ayar||{},fmt=n=>Number(n||0).toLocaleString('tr-TR'),date=t=>t?new Date(t).toLocaleString('tr-TR'):'—';
  let td={eylemler:[]}; try{const p=await API.rpc('sokak_tedbir_panel'); if(p&&p.eylemler) td=p;}catch(ex){}
  const tb={}; (td.eylemler||[]).forEach(r=>{tb[Number(r.id)]=r;});
  let sd={eylemler:[]}; try{const p=await API.rpc('sokak_sert_panel'); if(p&&p.eylemler) sd=p;}catch(ex){}
  const sb={}; (sd.eylemler||[]).forEach(r=>{sb[Number(r.id)]=r;});
  let h='<div class="kart"><h2>📢 Halk Hareketleri</h2><p>Barışçıl gösteriler, ortak fonlama ve hükümetle uzlaşma.</p><details><summary>Kurallar ve kötüye kullanım sınırları</summary><p>Başlatma: muhalefet genel başkanı, 7 günlük hesap, ilde en az 3 aktif oyuncu ve 35/100 memnuniyetsizlik. Parti kasasından '+fmt(a.baslatma_bedeli)+' TL.</p><p>İlde tek eylem; kapanıştan sonra 7 gün bekleme. Parti başına tek aktif eylem ve 72 saat bekleme. Ülkede en fazla 6 eylem. Her kişi/kurum en fazla 3 eylemi destekleyebilir.</p><p>İlk süre 24 saat. Her '+fmt(a.baslatma_bedeli)+' TL ek protesto fonu 12 saat kazandırır; toplam en fazla 5 gün. Katılım için 3 günlük hesap gerekir. Türkiye’nin 81 ilinden katılım serbesttir.</p><p>Son 24 saat fon limiti: kişi '+fmt(a.baslatma_bedeli*2)+' TL, kurum '+fmt(a.baslatma_bedeli*5)+' TL. Uzlaşma tarafında bu limitler üç kattır. Eylem protesto fonu en fazla '+fmt(a.baslatma_bedeli*20)+' TL. Harcamalar iade edilmez.</p><p>Kırmızı: en az 75 puan ve Türkiye genelinden en az 3 gerçek katılımcı. Para tek başına yeterli değildir. Uzlaşma fonu protesto fonunun 3 katına ulaşınca eylem kapanır.</p><p>Erken seçim: en az 3 kırmızı il ve aktif ülkenin %20’si (en az 15 kişi), kesintisiz 72 saat. Yakın seçim, yeni hükümetin ilk 7 günü ve 14 günlük kriz seçimi beklemesi korunur. Cumhurbaşkanı seçimle devredene kadar görevde kalır.</p><p>Kırmızı eylemler büyümeyi ve hükümet memnuniyetini sınırlı etkiler; şirketlerin kâr beklentisi değerine en fazla %6 risk indirimi uygulanır. Hükümet açıklaması tek başına sayacı sıfırlamaz; fon veya gerçek hizmet iyileşmesi gerekir.</p></details></div>';
  if(d.kriz?.kirmizi_baslangic)h+='<div class="kart"><b>Ulusal kriz sayacı</b><p>Başlangıç: '+e(date(d.kriz.kirmizi_baslangic))+'</p><p>Koşullar bozulursa 72 saat sayacı sıfırlanır.</p></div>';
  if(!d.aktif)h+='<div class="kart">Halk hareketleri şu anda kapalı.</div>';
  if(d.aktif&&d.baslatabilir)h+='<div class="kart"><h3>Eylem başlat</h3><form id="hhYeni"><label>İl · memnuniyetsizlik</label><select name="il">'+(d.iller||[]).map(i=>'<option value="'+Number(i.id)+'">'+e(i.ad)+' · '+fmt(i.memnuniyetsizlik)+'/100</option>').join('')+'</select><label>Talep</label><select name="talep"><option value="hizmet">İl hizmet memnuniyeti +5 puan</option><option value="issizlik">İşsizlik −0,5 puan</option><option value="vergi">Vergi −1 puan</option></select><label>Somut talep ve gerekçe</label><textarea name="metin" minlength="15" maxlength="400" required></textarea><p>Parti kasasından '+fmt(a.baslatma_bedeli)+' TL harcanır.</p><button class="btn altin">Ücreti öde ve başlat</button></form></div>';
  const kaynak=(d.kaynaklar||[]).map((k,i)=>'<option value="'+i+'">'+e(k.ad)+'</option>').join('');
  for(const x of d.eylemler||[]){
   const active=d.aktif&&x.durum==='aktif',red=!!x.kirmizi_baslangic;
   h+='<div class="kart"><h3>'+e(x.il)+' · '+e(x.parti)+'</h3><p>'+e(x.gerekce)+'</p><p><b>'+(active?(red?'🔴 Kırmızı':Number(x.seviye)>=45?'🟠 Turuncu':'🟡 Sarı'):e(x.durum))+'</b> · '+fmt(x.seviye)+'/100 · '+fmt(x.katilim)+' katılım</p><p>Memnuniyetsizlik '+fmt(x.memnuniyetsizlik)+'/100<br>Bitiş '+e(date(x.bitis))+'</p><p>Protesto: '+fmt(x.muhalefet_fonu)+' TL<br>Uzlaşma: '+fmt(x.iktidar_fonu)+' TL<br>Yatışma için kalan: '+fmt(Math.max(0,x.muhalefet_fonu*3-x.iktidar_fonu))+' TL</p>';
   if(x.hukumet_yaniti)h+='<blockquote><b>Hükümet yanıtı</b><p>'+e(x.hukumet_yaniti)+'</p></blockquote>';
   if(active){
    if(!d.iktidar)h+='<button class="btn" data-hh-katil="'+Number(x.id)+'">Eyleme katıl</button>';
    h+='<form class="hhFon" data-id="'+Number(x.id)+'"><label>Taraf</label><select name="taraf">'+(!d.iktidar?'<option value="muhalefet">Protestoyu destekle</option>':'')+'<option value="iktidar">Uzlaşmayı destekle</option></select><label>Ödeme kaynağı</label><select name="kaynak">'+kaynak+'</select><label>Tutar (TL)</label><input name="tutar" type="number" min="1000" step="0.01" required><button class="btn altin">Fonu öde</button></form>';
    if(d.hukumet)h+='<form class="hhYanit" data-id="'+Number(x.id)+'"><label>Hükümetin çözüm yanıtı</label><textarea name="metin" minlength="20" maxlength="500" required></textarea><button class="btn">Yanıtı yayımla</button></form>';
   }
   h+=hhSozHTML(x,d)+hhHukumetHTML(x,d)+hhTedbirHTML(x,tb[Number(x.id)],fmt)+hhSertHTML(x,sb[Number(x.id)],fmt);
   h+='<details><summary>Destekçiler</summary>'+(x.destekler||[]).map(k=>'<p>'+e(k.ad||k.tur)+' · '+e(k.taraf==='iktidar'?'Uzlaşma':'Protesto')+' · '+fmt(k.tutar)+' TL</p>').join('')+'</details></div>';
  }
  if(!(d.eylemler||[]).length)h+='<div class="kart">Henüz eylem yok. Yeni eylem için ilin memnuniyetsizlik ve katılım şartlarını sağlaması gerekir.</div>';
  iskelet('Halk Hareketleri',h,{geri:true});
  async function run(b,fn,args){b.disabled=true;try{await API.rpc(fn,args);toast('İşlem tamamlandı');await sokakHareketleriEkrani();}catch(err){toast(hataCevir(err.message),true);b.disabled=false;}}
  hhHukumetBagla(run); hhSozBagla(run); hhTedbirBagla(run); hhSertBagla(run);
  document.getElementById('hhYeni')?.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(ev.currentTarget);run(ev.currentTarget.querySelector('button'),'sokak_talepli_baslat',{p_il:Number(f.get('il')),p_gerekce:String(f.get('metin')),p_tur:String(f.get('talep'))});});
  document.querySelectorAll('[data-hh-katil]').forEach(b=>b.addEventListener('click',()=>run(b,'sokak_destek',{p_eylem:Number(b.dataset.hhKatil),p_taraf:'muhalefet'})));
  document.querySelectorAll('.hhFon').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(form),k=d.kaynaklar[Number(f.get('kaynak'))];run(form.querySelector('button'),'sokak_destek',{p_eylem:Number(form.dataset.id),p_taraf:String(f.get('taraf')),p_kaynak:k.tur,p_kaynak_id:k.id,p_tutar:Number(f.get('tutar'))});}));
  document.querySelectorAll('.hhYanit').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();run(form.querySelector('button'),'sokak_yanit',{p_eylem:Number(form.dataset.id),p_metin:String(new FormData(form).get('metin'))});}));
 }catch(err){iskelet('Halk Hareketleri','<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
// Kaynak derlemesine kalıcı menü bağlantısı.
(function(){const eski=iskelet;iskelet=function(baslik,govde,opt){if(baslik==='Partiler')govde='<div class="kart"><button class="btn altin" onclick="ekranAc(sokakHareketleriEkrani)">📢 Halk Hareketleri · Protestolar ve uzlaşma</button></div>'+govde;return eski(baslik,govde,opt);};})();
const HH_TEDBIR={
 hizmet:['Acil Hizmet Seferberliği','Hizmet talebinde il memnuniyeti +4, 12 saat yoğunluk −8. Söz tutulmazsa ülke memnuniyeti −3.'],
 vergi_tatil:['Bölgesel Vergi Tatili','48 saat kent vergisi −1. Büyüme −0,2; diğer iller ve ülke memnuniyeti geriler.'],
 istihdam:['İstihdam Taahhüt Paketi','İşsizlik −0,3. Şirket sözü gelmezse indirim geri gelir, memnuniyet −2.'],
 brifing:['Resmi Basın Brifingi','12 saat tarafsız nabız hükümete eğilir. Karşı brifing etkiyi ters çevirir.'],
 sosyal_kart:['Acil Sosyal Destek Kartı','Kişi başı 4.000 TL, en çok 15 kişi. Oy satın alma şüphesi doğurur.'],
 guzergah:['Güvenli Alan / Güzergâh','Kabulde güç aynı kalır, kırmızı ekonomik hasar 24 saat sayılmaz. Ret veya dayatma inat artırır.'],
 komisyon:['Meclis Araştırma Komisyonu','24 saat yeni kırmızı yok. Muhalefet devralırsa talep kısmen uygulanır.'],
 gozlemci:['Bağımsız Gözlemci','Avukat katılınca 12 saat polis ve barikat kapalı. Sert müdahale ağır ceza yer.'],
 kapi:['İktidar Kapı Kapı','Açılıştan sonra üye başı 8.000 TL ve 3 saat bekleme. Muhalefet aynı ilde karşı çağrı yapar.'],
 gece:['Gece Toplanma Kısıtı','48 saat, 22.00–06.00 yeni katılım ve taktik kapalı. İl memnuniyeti −1, gündüz inat +2.'],
 iletisim:['İletişim Yavaşlatma','6 saat çağrı ve nabız durur. Mesaj ve oy hakkı durmaz. Ülke −2, kriz sayacı +6 saat.'],
 festival:['Kültür-Festival','Tarafsız oyuncu festivale gider. Ekmek yok oyun var tepkisi doğar; sahne işgal edilebilir.']
};
const HH_HAMLE={
 yetersiz:['Yetersiz buluyorum',false], ikna_olmadim:['İkna olmadım',false], slogan:['Sloganla yanıtla',true],
 basin_hukumet:['Brifinge katıl',false], basin_karsi:['Karşı brifing yaz',true], kart_cagri:['Kartı reddedin',false], kart_iade:['Kartı iade et',false],
 guzergah_kabul:['Güzergâhı kabul et',false], guzergah_ret:['Güzergâhı reddet',false], dayat:['Güzergâhı dayat',false],
 komisyon_iktidar:['Komisyona katıl',false], komisyon_muhalefet:['Komisyona muhalefet olarak katıl',false], komisyon_devral:['Komisyonu devral',false],
 gozlemci:['Gözlemci ol',false], gozlemci_ret:['Protokolü reddet',false], kapi_iktidar:['Kapı kapı dolaş',false], kapi_muhalefet:['Karşı çağrı yap',false],
 istihdam_grev:['Greve çağır',false], istihdam_soz:['Şirket sözü ver',false], otobus:['Miting otobüsü',false], dernek_davet:['Dernek daveti',false],
 festival:['Festivale git',false], festival_ayril:['Festivalden ayrıl',false], sahne:['Sahneyi işgal et',true], kisit_itiraz:['Kısıtı tanımıyorum',false]
};
function hhTedbirHTML(x,row,fmt){
 if(!row) return '';
 const id=Number(x.id); let h='<details class="hhTedbirKutu"><summary>🏛️ Yeni hükümet araçları</summary><p>Her aracın bedeli, riski ve karşı hamlesi vardır. Mesajlaşma ve seçim oyu kapanmaz.</p>';
 const ac=row.acabilir||[];
 if(row.yonetebilir&&ac.length){
  h+='<form class="hhTedbir" data-id="'+id+'"><label>Araç ve kamu gideri</label><select name="tur">'+ac.map(k=>{
   const ad=(HH_TEDBIR[k]||[k])[0], bed=k==='sosyal_kart'?'4.000 TL × en çok 15 kişi':fmt(row.bedeller&&row.bedeller[k])+' TL'+(k==='kapi'?' açılış':'');
   return '<option value="'+k+'">'+e(ad)+' · '+e(bed)+'</option>';
  }).join('')+'</select><p>'+ac.map(k=>'<span><b>'+e((HH_TEDBIR[k]||[k])[0])+':</b> '+e((HH_TEDBIR[k]||['',''])[1])+'</span>').join('<br>')+'</p><label>Gerekçe</label><textarea name="metin" minlength="20" maxlength="500" required></textarea><button class="btn altin">Kamu bütçesinden uygula</button></form>';
 }else if(row.yonetebilir) h+='<p>Şu an açılabilecek yeni araç yok. Talep türü, bekleme veya 12 saatte 3 araç sınırı dolmuş olabilir.</p>';
 for(const t of row.tedbirler||[]){
  h+='<div class="kart"><b>'+e(t.ad||t.tur)+'</b> · '+e(t.durum)+'<p>'+e(t.gerekce)+'</p><small>'+fmt(t.bedel)+' TL</small>';
  const karsi=(t.karsi||[]).filter(k=>k!=='istihdam_soz');
  if(karsi.length) h+='<div>'+karsi.map(k=>{
   const meta=HH_HAMLE[k]||[k,false];
   if(meta[1]) return '<form class="hhTedbirHamle" data-id="'+id+'" data-tur="'+e(k)+'"><label>'+e(meta[0])+'</label><textarea name="metin" minlength="'+(k==='basin_karsi'?20:6)+'" maxlength="'+(k==='basin_karsi'?500:90)+'" required></textarea><button class="btn">'+e(meta[0])+'</button></form>';
   return '<button class="btn" data-hh-hamle="'+id+'" data-hh-tur="'+e(k)+'" data-hh-parent="'+e(t.tur)+'">'+e(meta[0])+'</button>';
  }).join(' ')+'</div>';
  if((t.karsi||[]).includes('istihdam_soz')&&(row.sirketler||[]).length){
   h+='<form class="hhTedbirSoz" data-id="'+id+'"><label>Söz veren şirket</label><select name="sirket">'+(row.sirketler||[]).map(s=>'<option value="'+Number(s.id)+'">'+e(s.ad)+'</option>').join('')+'</select><button class="btn">İstihdam sözü ver</button></form>';
  }
  h+='</div>';
 }
 return h+'</details>';
}
const HH_SERT={
 safak:['Şafak Operasyonu','Yalnız 04.00–06.00. Nöbet azsa eylem biter; yeterli nöbet varsa eylem güçlenir.'],
 elebasi:['Elebaşı Gözaltısı','Organizatör ve en hareketli iki kişi 12 saat dışarıda. Avukat süreyi bir kez yarıya indirir.'],
 mali:['Mali Kuşatma','48 saat parti ve dernek fonu kapalı. Mahkeme aykırı derse 100.000 TL tazminat.'],
 kapatma:['Kapatma Davası Tehdidi','Parti harcaması iki kat. Hükümet kaybederse prestij ve memnuniyet düşer.'],
 ohal:['OHAL','Meclis onayıyla 72 saat ilde eylem yasağı ve yarı fiyat hükümet aracı. Memnuniyet düşer, erken seçim riski artar.'],
 propaganda:['Kara Propaganda','Yabancı destek manşeti tarafsızı soğutur. Çürütülürse skandal olur.'],
 bol:['Böl ve Yönet','Kabul ve direniş fraksiyonu. Birlik oyu böler.'],
 kusatma:['Kuşatma Çemberi','Yeni katılım yok, 6 saatte bir güç kaybı. Dayanışma ziyareti çemberi bozar.'],
 ihale:['İhale ve Lisans Kılıcı','Destekleyen şirketlerin ihalesi 48 saat askıda. Çekilmek baskıyı kaldırır.'],
 sanal:['Toplu Sanal Gözaltı','Beş kişi 6 saat oy ve sohbet kullanamaz. En ağır memnuniyet ve sempati bedeli.']
};
function hhSertHTML(x,row,fmt){
 if(!row||x.durum!=='aktif') return '';
 const id=Number(x.id), keys=Object.keys(HH_SERT);
 let h='<details class="hhSertKutu"><summary>⛔ On sert önlem</summary><p>Çabuk sonuç, sonra oy kaybı. Cumhurbaşkanı, İçişleri Bakanı veya ilin valisi. 12 saatte en çok 2.</p>';
 if(row.yetkili){
  h+='<form class="hhSert" data-id="'+id+'"><label>Önlem ve kamu gideri</label><select name="tur">'+keys.map(k=>'<option value="'+k+'">'+e(HH_SERT[k][0])+' · '+fmt(row.bedeller&&row.bedeller[k])+' TL</option>').join('')+'</select><p>'+keys.map(k=>'<b>'+e(HH_SERT[k][0])+':</b> '+e(HH_SERT[k][1])).join('<br>')+'</p><p>İstanbul saati '+Number(row.saat)+'. Şafak yalnız 04–06.</p><label>Gerekçe</label><textarea name="metin" minlength="20" maxlength="500" required></textarea><button class="btn altin">İçişleri bütçesinden uygula</button></form>';
 }
 for(const t of row.onlemler||[]) h+='<div class="kart"><b>'+e(t.ad||t.tur)+'</b> · '+e(t.durum)+'<p>'+e(t.gerekce)+'</p><small>'+fmt(t.bedel)+' TL</small></div>';
 if(row.katilimci) h+='<button class="btn" data-hh-sert="nobet" data-id="'+id+'">Nöbet listesine yazıl</button> <button class="btn" data-hh-sert="birlik" data-id="'+id+'">Birlik oyu</button> <button class="btn" data-hh-sert="cek" data-id="'+id+'">İhale baskısından çekil</button><form class="hhSertLider" data-id="'+id+'"><label>Yeni sözcü</label><input name="kad" required placeholder="Kullanıcı adı"><button class="btn">Sözcüye oy ver</button></form>';
 if(row.avukat) h+='<button class="btn" data-hh-sert="avukat" data-id="'+id+'">Elebaşı süresini yarıya indir</button>';
 if(row.gazeteci&&row.iktidar) h+='<button class="btn" data-hh-sert="manset" data-id="'+id+'">Yabancı destek manşetini yaz</button>';
 if((row.gazeteci&&!row.iktidar)||row.avukat) h+='<form class="hhSertCurut" data-id="'+id+'"><label>Propagandayı çürüt</label><textarea name="metin" minlength="12" maxlength="400" required></textarea><button class="btn">Kanıtla çürüt</button></form>';
 if(!row.katilimci&&!row.yetkili) h+='<button class="btn" data-hh-sert="ziyaret" data-id="'+id+'">Dayanışma ziyareti</button>';
 if(row.vekil&&row.ohal&&row.ohal.durum==='onay') h+='<button class="btn" data-hh-sert="ohal_oy" data-oy="evet" data-oid="'+Number(row.ohal.id)+'" data-id="'+id+'">OHAL\'e evet</button> <button class="btn" data-hh-sert="ohal_oy" data-oy="hayir" data-oid="'+Number(row.ohal.id)+'" data-id="'+id+'">OHAL\'e hayır</button>';
 if(row.yargi) for(const t of row.onlemler||[]) if((t.tur==='mali'||t.tur==='kapatma')&&t.durum==='aktif') h+='<button class="btn" data-hh-sert="yargi" data-oy="aykiri" data-sid="'+Number(t.id)+'" data-id="'+id+'">'+e(t.ad)+' aykırı</button> <button class="btn" data-hh-sert="yargi" data-oy="uygun" data-sid="'+Number(t.id)+'" data-id="'+id+'">Uygun bul</button>';
 if(row.fraksiyon) h+='<p>Fraksiyonun: '+(row.fraksiyon==='kabul'?'kabul':'direniş')+'</p>';
 return h+'</details>';
}
function hhSertBagla(run){
 document.querySelectorAll('.hhSert').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(form);run(form.querySelector('button'),'sokak_sert_islem',{p_eylem:Number(form.dataset.id),p_islem:'ac',p_veri:{tur:String(f.get('tur')),gerekce:String(f.get('metin'))}});}));
 document.querySelectorAll('.hhSertLider').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();run(form.querySelector('button'),'sokak_sert_islem',{p_eylem:Number(form.dataset.id),p_islem:'lider_oy',p_veri:{kad:String(new FormData(form).get('kad'))}});}));
 document.querySelectorAll('.hhSertCurut').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();run(form.querySelector('button'),'sokak_sert_islem',{p_eylem:Number(form.dataset.id),p_islem:'curut',p_veri:{metin:String(new FormData(form).get('metin'))}});}));
 document.querySelectorAll('[data-hh-sert]').forEach(b=>b.addEventListener('click',()=>{
  const islem=b.dataset.hhSert, veri={};
  if(islem==='ohal_oy'||islem==='yargi'){veri.oy=b.dataset.oy; veri.id=Number(b.dataset.oid||b.dataset.sid);}
  run(b,'sokak_sert_islem',{p_eylem:Number(b.dataset.id),p_islem:islem,p_veri:veri});
 }));
}
function hhTedbirBagla(run){
 document.querySelectorAll('.hhTedbir').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(form);run(form.querySelector('button'),'sokak_tedbir_ac',{p_eylem:Number(form.dataset.id),p_tur:String(f.get('tur')),p_gerekce:String(f.get('metin'))});}));
 document.querySelectorAll('.hhTedbirHamle').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();run(form.querySelector('button'),'sokak_tedbir_hamle',{p_eylem:Number(form.dataset.id),p_tur:form.dataset.tur,p_metin:String(new FormData(form).get('metin'))});}));
 document.querySelectorAll('.hhTedbirSoz').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();run(form.querySelector('button'),'sokak_tedbir_hamle',{p_eylem:Number(form.dataset.id),p_tur:'istihdam_soz',p_metin:String(new FormData(form).get('sirket'))});}));
 document.querySelectorAll('[data-hh-hamle]').forEach(b=>b.addEventListener('click',()=>run(b,'sokak_tedbir_hamle',{p_eylem:Number(b.dataset.hhHamle),p_tur:b.dataset.hhTur,p_metin:b.dataset.hhTur==='yetersiz'?b.dataset.hhParent:null})));
}
function hhHukumetHTML(x,d){
 const fmt=n=>Number(n||0).toLocaleString('tr-TR'),active=d.aktif&&x.durum==='aktif';
 const names={masa:'Uzlaşma masası',yonlendirme:'Bilgilendirme ve yönlendirme',uyari:'Sert siyasi uyarı',dagitma:'Ek bütçeyle dağıtma',yaptirim:'6 saatlik eylem yaptırımı'};
 let h='';
 if(active&&d.mudahale_yetki){
  h+='<details><summary>🏛️ Cumhurbaşkanı / İçişleri müdahalesi</summary><p>İçişleri kullanılabilir bütçe karşılığı: '+fmt(d.icisleri_kasa_tl)+' TL. Bütün giderler kamu kasasına kaydedilir.</p><p>Aynı eylemde 6 saatte bir; ülke çapında 24 saatte en fazla 4 karar.</p><ul><li>Uzlaşma: mevcut katılımcıların çoğunluğu 12 saat içinde kabul ederse 24 saatlik söz takibi başlar. Hedef gerçekleşirse kapanır; gerçekleşmezse eylem devam eder.</li><li>Yönlendirme: 12 saat boyunca yoğunluk −10 puan.</li><li>Sert uyarı: 6 saat −8 puan; ardından 18 saat +6 puan tepki ve ülke memnuniyetinde −1.</li><li>Dağıtma: en az 12 saat kırmızı olmalı; ülke çapında 48 saatte bir. Ülke memnuniyeti −4, il memnuniyeti −5.</li><li>Yaptırım: seçilen katılımcının yalnız bu eyleme katılım/fon hakkı 6 saat durur. İtiraz uygulamayı durdurur; hakim onaylayabilir/kaldırabilir. Hesap, oy hakkı ve diğer faaliyetler etkilenmez. Ülke memnuniyeti −1.</li></ul><form class="hhKarar" data-id="'+Number(x.id)+'"><label>Yöntem ve kamu gideri</label><select name="tur">'+Object.entries(names).map(([k,v])=>'<option value="'+k+'">'+e(v)+' · '+fmt(x.bedeller?.[k])+' TL</option>').join('')+'</select><label>Yalnız yaptırım için katılımcı</label><select name="hedef"><option value="">Katılımcı seç</option>'+(x.katilimcilar||[]).map(p=>'<option value="'+e(p.id)+'">'+e(p.ad)+'</option>').join('')+'</select><label>Karar gerekçesi / somut çözüm taahhüdü</label><textarea name="metin" minlength="20" maxlength="500" required></textarea><p>Harcama iade edilmez. Bir eylemde en fazla 3 yaptırım; aynı oyuncuya 7 günde bir uygulanabilir.</p><button class="btn altin">Kamu bütçesinden öde ve uygula</button></form></details>';
 }
 for(const k of x.kararlar||[]){
  let opts=[];
  if(active&&!k.suresi_doldu){
   if(!x.soz&&k.tur==='masa'&&k.durum==='aktif'&&x.ben_baslattim)opts=[['kabul','Uzlaşmayı kabul et ve eylemi bitir'],['ret','Teklifi reddet']];
   if(k.tur==='yaptirim'&&k.durum==='aktif'&&k.ben_hedefim)opts=[['itiraz','Yaptırıma itiraz et (uygulama durur)']];
   if(k.tur==='yaptirim'&&k.durum==='itiraz'&&k.yargi_yetki)opts=[['kaldirildi','Yargı: yaptırımı kaldır'],['onandi','Yargı: yaptırımı onayla']];
  }
  h+='<div class="kart"><b>'+e(names[k.tur]||k.tur)+'</b> · '+e(k.suresi_doldu?'Süresi doldu':k.durum)+'<p>'+e(k.gerekce)+'</p><small>'+e(k.yapan_ad)+' · '+fmt(k.bedel)+' TL'+(k.hedef_ad?' · Katılımcı: '+e(k.hedef_ad):'')+'</small>';
  if(k.cevap)h+='<p>Yanıt: '+e(k.cevap)+'</p>';
  if(opts.length)h+='<form class="hhKararYanit" data-id="'+Number(k.id)+'"><select name="islem">'+opts.map(o=>'<option value="'+o[0]+'">'+e(o[1])+'</option>').join('')+'</select><textarea name="metin" minlength="20" maxlength="500" placeholder="Gerekçeniz" required></textarea><button class="btn">Yanıtı kaydet</button></form>';
  h+='</div>';
 }
 return h;
}
function hhHukumetBagla(run){
 document.querySelectorAll('.hhKarar').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(form),tur=String(f.get('tur')),hedef=String(f.get('hedef'));if(tur==='yaptirim'&&!hedef){toast('Katılımcı seçmelisin',true);return;}if(tur==='masa'){run(form.querySelector('button'),'sokak_soz_teklif',{p_eylem:Number(form.dataset.id),p_metin:String(f.get('metin'))});return;}run(form.querySelector('button'),'sokak_hukumet_karar',{p_eylem:Number(form.dataset.id),p_tur:tur,p_gerekce:String(f.get('metin')),p_hedef:tur==='yaptirim'?hedef:null});}));
 document.querySelectorAll('.hhKararYanit').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(form);run(form.querySelector('button'),'sokak_karar_yanit',{p_karar:Number(form.dataset.id),p_islem:String(f.get('islem')),p_metin:String(f.get('metin'))});}));
}

function hhSozHTML(x,d){
 const labels={hizmet:'İl hizmet memnuniyeti +5 puan',issizlik:'İşsizlik −0,5 puan',vergi:'Vergi −1 puan'};
 let h='<div class="kart"><b>Somut talep: '+e(labels[x.talep]||'Henüz seçilmedi')+'</b>';
 if(!x.talep&&x.ben_baslattim&&x.durum==='aktif')h+='<form class="hhTalep" data-id="'+Number(x.id)+'"><select name="tur">'+Object.entries(labels).map(([k,v])=>'<option value="'+k+'">'+e(v)+'</option>').join('')+'</select><button class="btn">Talebi kesinleştir</button></form>';
 const s=x.soz;if(s){h+='<p>Uzlaşma: '+e(s.durum)+' · Evet '+Number(s.evet)+' / Hayır '+Number(s.hayir)+' / Seçmen '+Number(s.secmen)+'</p><p>Başlangıç '+Number(s.baslangic)+' → hedef '+Number(s.hedef)+' · Şimdi '+Number(s.olcum)+'</p><p>Oylama sonu: '+e(new Date(s.oy_sonu).toLocaleString('tr-TR'))+'</p>';
 if(s.son_tarih)h+='<p>Söz kontrolü: '+e(new Date(s.son_tarih).toLocaleString('tr-TR'))+'</p>';
 if(s.durum==='oylama'&&s.oy_hakki&&x.durum==='aktif')h+='<button class="btn" data-soz="'+Number(x.id)+'" data-oy="evet">Uzlaşmayı kabul et</button><button class="btn" data-soz="'+Number(x.id)+'" data-oy="hayir">Reddet</button>';
 }return h+'</div>';
}
function hhSozBagla(run){document.querySelectorAll('[data-soz]').forEach(b=>b.addEventListener('click',()=>run(b,'sokak_soz_oyla',{p_eylem:Number(b.dataset.soz),p_oy:b.dataset.oy==='evet'})));document.querySelectorAll('.hhTalep').forEach(f=>f.addEventListener('submit',ev=>{ev.preventDefault();run(f.querySelector('button'),'sokak_talep_sec',{p_eylem:Number(f.dataset.id),p_tur:String(new FormData(f).get('tur'))});}));}
