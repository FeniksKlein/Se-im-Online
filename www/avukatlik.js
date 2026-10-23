/* Seçim Online — Avukatlık (kontenjanlı ruhsat) · 23.10.2026 sürümü.
   Mevcut Adliye'ye zarar vermeyen eklenti. Kontenjan, bekleme listesi, askı/yenileme, rastgele sınav,
   baro kaydı uyarısı ve yönetici kontenjan ayarı. */
(function(){
'use strict';
if(typeof adliyeHtml!=='function'||typeof adliyeDosya!=='function')return;
const h=x=>typeof e==='function'?e(String(x??'')):String(x??'').replace(/[&<>"']/g,'');
const money=n=>Number(n||0).toLocaleString('tr-TR',{maximumFractionDigits:0})+' ₺';
const stamp=d=>d?(typeof tarihSaat==='function'?tarihSaat(d):new Date(d).toLocaleString('tr-TR')):'—';
const RPC=(k,v)=>API.rpc(k,v||{});
const error=err=>toast(typeof hataCevir==='function'?hataCevir(err.message):err.message,true);
const op=(v,t)=>'<option value="'+h(v)+'">'+h(t)+'</option>';
const TA='style="width:100%;padding:12px;border-radius:10px;background:var(--bg);border:1px solid var(--line2);outline:none;font-size:16px;resize:vertical"';
const cuzdan=()=>{try{return Number(D.durum.profil.cuzdan.para)||0}catch(_){return null}};
async function act(k,v,msg,reload){
 try{let result=await RPC(k,v);if(msg)toast(msg);if(reload==='dava')await adliyeDosya(v.p_dava);
 else if(typeof reload==='number')await adliyeDosya(reload);
 else await adliyeEkrani();return result;}catch(err){error(err);return null;}
}
function islemButon(label,fn,cls){return '<button class="btn '+(cls||'ikinci')+'" onclick='+fn+'>'+label+'</button>'}
function disiplinRozet(d){
 if(!d)return '';
 const p=[];if(d.uyari)p.push(d.uyari+' uyarı');if(d.kinama)p.push(d.kinama+' kınama');if(d.yasak)p.push(d.yasak+' işten yasaklama');
 return p.length?' · <span style="color:var(--warn)">Disiplin: '+h(p.join(', '))+'</span>':'';
}
function avukatKart(a){
 return '<div class="liste-satir"><div class="orta"><b>Av. '+h(a.kad)+'</b>'+(a.sicil?' <span class="rozet altin">Sicil '+h(a.sicil)+'</span>':' <span class="rozet sari">Baro kaydı yok</span>')
  +'<div class="kucuk">'+h(a.burosu||'Bağımsız avukat')+' · '+Number(a.tamamlanan)+' sonuçlanan · '+Number(a.kazanilan)+' kazanılan'+disiplinRozet(a.disiplin)+'</div>'
  +'<div class="kucuk">Başarı: '+(a.oran==null?'Henüz kesinleşmiş dava yok':'%'+h(a.oran))+(a.ruhsat_at?' · Ruhsat: '+h(stamp(a.ruhsat_at)):'')+'</div></div></div>';
}
function kontenjanHtml(s){
 const kb=s.kontenjan_bilgi||{},kota=Number(s.kontenjan)||0,aktif=Number(s.aktif_avukat)||0,dol=kota?Math.min(100,Math.round(aktif*100/kota)):100;
 const formul=kb.elle!=null?'Yönetici sabit kontenjan belirledi: '+h(kb.elle)
  :'Her '+h(kb.oran||10)+' aktif oyuncuya 1 ruhsat (en az '+h(kb.min??2)+') · Son 7 günde aktif oyuncu: '+h(kb.aktif_oyuncu??'—');
 const liste=(s.bekleme_listesi||[]);
 return '<div class="kv"><span class="k">Kontenjan (dolu / toplam)</span><span class="v">'+aktif+' / '+kota+(aktif<kota?' · '+(kota-aktif)+' boş':' · dolu')+'</span></div>'
  +'<div class="bar"><i style="width:'+dol+'%;background:'+(aktif>=kota?'var(--warn)':'var(--good)')+'"></i></div>'
  +'<p class="kucuk" style="margin-top:6px">'+formul+'</p>'
  +'<div class="kv"><span class="k">Bekleme listesi</span><span class="v">'+Number(s.bekleyen||0)+' aday</span></div>'
  +(liste.length?'<details><summary style="cursor:pointer;font-weight:700;font-size:13.5px">Sırayı göster</summary>'
    +liste.map(x=>'<div class="liste-satir"><div class="orta"><b>'+h(x.sira)+'. '+h(x.kad)+(x.benim?' (sen)':'')+'</b><div class="kucuk">Başvuru: '+h(stamp(x.basvuru))+'</div></div></div>').join('')
    +'<p class="kucuk">Son 7 günde oyuna girmeyen adaylar sırayı tıkamaz; döndüklerinde yerleri korunur.</p></details>':'')
  +'<div class="kv"><span class="k">Ruhsat harcı</span><span class="v">'+money(s.harc||100000)+' · yalnız kontenjana yerleşince</span></div>';
}
function ruhsatDurumHtml(s){
 const a=s.akademi||{},ruh=s.ruhsat||{},baro=s.baro||{};
 const para=cuzdan(),harc=Number(s.harc||100000);
 if(ruh.durum==='aktif'){
  let z='<div class="rozet yesil">Ruhsatlı avukat'+(baro.sicil&&baro.uyeyim?' · Baro sicil '+h(baro.sicil):'')+'</div>';
  if(!baro.uyeyim){
   z+='<p class="alt" style="margin-top:8px"><b>Mesleği icra etmek için Türkiye Barosu levhasına kaydolmalısın.</b> Kayıt olmadan teklif veremez, savunma sunamaz, büro açamazsın.</p>'
    +islemButon('Türkiye Barosu levhasına kaydol','"baroKaydol()"','altin');
  }else if(s.engel){
   z+='<p class="alt" style="margin-top:8px;color:var(--warn)">'+h(s.engel)+'</p>';
  }
  if(baro.uyeyim)z+=islemButon('🏛️ Türkiye Barosu binasına gir','"baroAc()"','altin')+islemButon('Hukuk bürosu işlemleri','"avukatBuroPanel()"');
  z+='<button class="btn tehlike" style="margin-top:14px" onclick="avukatRuhsatBirak()">Ruhsatımı askıya al (kontenjanı bırak)</button>';
  return z;
 }
 if(ruh.durum==='bekliyor'){
  return '<p class="alt">Bekleme listesinde <b>'+h(ruh.sira||'?')+'. sıradasın.</b> Kontenjan açıldığında ruhsatın kendiliğinden verilir'+(ruh.harc_odendi?' (harç alınmaz).':'; harç cüzdanından tahsil edilir.')+'</p>'
   +(!ruh.harc_odendi&&para!=null&&para<harc?'<p class="alt" style="color:var(--warn)">Cüzdanında '+money(para)+' var; sıran geldiğinde en az '+money(harc)+' olmalı. Yoksa sıran korunur ama sonraki aday önce yerleşir.</p>':'')
   +islemButon('Sıramı yenile','"avukatRuhsat()"');
 }
 if(ruh.durum==='askida'&&['pasif','istek'].includes(ruh.gerekce)){
  return '<p class="alt">Ruhsatın askıda ('+(ruh.gerekce==='pasif'?'uzun süre oyuna girilmedi':'kendi isteğinle')+(ruh.askida_at?' · '+h(stamp(ruh.askida_at)):'')+'). Yeniden etkinleştirince harç ödemeden bekleme listesine girersin; boş kontenjan varsa hemen açılır.</p>'
   +islemButon('Ruhsatımı yeniden etkinleştir','"avukatRuhsatYenile()"','altin');
 }
 if(ruh.durum==='askida'||ruh.durum==='iptal')return '<p class="alt">Ruhsat durumu: '+h(ruh.durum)+'</p>';
 if(!s.hesap_uygun)return '<p class="alt">Hukuk Akademisine başlamak için hesabın en az 7 günlük olmalı.</p>';
 if(!s.akademi)return islemButon('Hukuk Akademisine kaydol','"avukatEgitim()"','altin')+islemButon('Ders notlarına göz at','"avukatDersNotlari()"');
 if(!a.sinav_gecildi&&new Date(a.egitim_bitti)>new Date())
  return '<p class="alt">24 saatlik eğitim sürüyor. Sınav açılışı: '+h(stamp(a.egitim_bitti))+'</p>'+islemButon('Ders notlarını oku','"avukatDersNotlari()"');
 if(!a.sinav_gecildi){
  const bekle=a.son_sinav&&new Date(a.son_sinav).getTime()+864e5>Date.now();
  return '<p class="alt">60 soruluk bankadan her denemede farklı 20 soru gelir; en az 16 doğru gerekir. Başarısız olursan 24 saat sonra yeni bir setle tekrar denersin.</p>'
   +(a.son_puan!=null?'<p class="alt">Son puan: '+h(a.son_puan)+'/20'+(bekle?' · Yeni deneme: '+h(stamp(new Date(new Date(a.son_sinav).getTime()+864e5))):'')+'</p>':'')
   +(bekle?'':islemButon('20 soruluk hukuk sınavını aç','"avukatSinavAc()"','altin'))+islemButon('Ders notlarını oku','"avukatDersNotlari()"');
 }
 if(!a.pratik1||!a.pratik2)
  return '<p class="alt">Hukuk sınavını geçtin ('+h(a.son_puan)+'/20). Uygulamalı staj vakaları: '+(a.pratik1?'✅':'○')+' 1 · '+(a.pratik2?'✅':'○')+' 2.</p>'+islemButon('Uygulamalı vakaları çöz','"avukatPratikAc()"','altin');
 return '<p class="alt">Eğitimi, sınavı ve stajı tamamladın. Başvurunca bekleme listesine girersin; boş kontenjan varsa ruhsatın hemen verilir.</p>'
  +(para!=null&&para<harc?'<p class="alt" style="color:var(--warn)">Ruhsat harcı için cüzdanında en az '+money(harc)+' olmalı (şu an '+money(para)+').</p>':'')
  +islemButon('Ruhsat başvurusu yap','"avukatRuhsat()"','altin');
}
const OLAY={basvuru:'Başvuru',aktif:'Ruhsat',askida:'Askı',yenileme:'Yenileme',sinav:'Sınav',baro_kayit:'Baro',baro_ayrildi:'Baro',baro_silindi:'Baro',baro_baskan:'Baro',disiplin:'Disiplin'};
function hukukCiz(s,primler){
 let z='<div class="kart"><h2>⚖️ Avukatlık ve Kontenjan</h2><p class="alt">Yol: 7 günlük hesap → 24 saatlik Hukuk Akademisi → 20 soruluk sınav (16 doğru) → iki staj vakası → kontenjanlı ruhsat → Türkiye Barosu levhasına kayıt. Hukuki savunmayı yalnız ruhsatlı, baroya kayıtlı ve dosyaya vekâlet almış avukat sunar.</p>';
 z+=kontenjanHtml(s);
 z+='<div style="margin-top:10px">'+ruhsatDurumHtml(s)+'</div>';
 if(s.yonetici)z+='<button class="btn ikinci" style="margin-top:10px" onclick="avukatKontenjanAyar()">⚙️ Kontenjan ayarı (yönetici)</button>';
 if((s.gecmis||[]).length)z+='<details style="margin-top:12px"><summary style="cursor:pointer;font-weight:700;font-size:13.5px">Ruhsat geçmişim</summary>'
  +s.gecmis.map(g=>'<div class="liste-satir"><div class="orta"><b>'+h(OLAY[g.olay]||g.olay)+'</b><div class="kucuk">'+h(g.aciklama)+' · '+h(stamp(g.zaman))+'</div></div></div>').join('')+'</details>';
 z+='</div>';
 if((primler||[]).length)z+='<div class="kart"><h3>Dava kazanma primi hesaplarım</h3>'+(primler||[]).map(k=>'<div class="liste-satir"><div class="orta"><b>Dava #'+k.dava+' · '+money(k.prim)+' prim</b><div class="kucuk">Ödenen: '+money(k.odenen)+' · Kalan: '+money(k.kalan)+' · '+h(k.muvekkil)+'</div></div>'+(k.ben_avukatim&&k.kalan>0?'<button class="btn ikinci" style="width:auto" onclick="avukatPrimTahsil('+k.id+')">Prim tahsil et</button>':'')+'</div>').join('')+'</div>';
 if(s.benim_burom)z+='<div class="kart"><h3>Hukuk bürom</h3><b>'+h(s.benim_burom.ad)+'</b>'+islemButon('Avukat davet et','"avukatDavet('+Number(s.benim_burom.id)+')"')+'</div>';
 z+='<div class="kart"><h3>Avukatlar ('+(s.avukatlar||[]).length+')</h3><p class="alt">Başarı oranı yalnız kesinleşmiş, düşmemiş gerçek davalardan hesaplanır. Disiplin cezaları Türkiye Barosu kararlarıdır.</p>'
 +(s.avukatlar||[]).map(avukatKart).join('')+(!(s.avukatlar||[]).length?'<p class="alt">Henüz ruhsatlı avukat yok.</p>':'')+'</div>';
 z+='<div class="kart"><h3>Hukuk büroları</h3>'
 +(s.burolar||[]).map(b=>'<div class="liste-satir"><div class="orta"><b>'+h(b.ad)+'</b><div class="kucuk">'+h(b.sehir)+' · Kurucu: '+h(b.kurucu)+' · '+b.uye_sayi+' avukat</div></div></div>').join('')
 +(!(s.burolar||[]).length?'<p class="alt">Henüz hukuk bürosu açılmamış.</p>':'')+'</div>';
 return z;
}
const oncekiHtml=adliyeHtml;
adliyeHtml=async function(){
 let eski=await oncekiHtml();
 try{const [s,prim]=await Promise.all([RPC('avukat_durum'),RPC('avukat_primlerim').catch(()=>[])]);window.AVUKAT_DURUM=s;return hukukCiz(s,prim)+eski;}
 catch(err){return '<div class="kart"><h3>Avukatlık</h3><p class="alt">Avukatlık paneli yüklenemedi: '+h(err.message)+'</p></div>'+eski;}
};
const DERS=[
 ['Avukatlık mesleği','Türkiye\'de meslek 1136 sayılı Avukatlık Kanunu ile düzenlenir. Avukat olmak için staj (gerçekte bir yıl) ve bir baronun levhasına yazılmak gerekir. Oyunda bunun karşılığı akademi + sınav + staj vakaları + kontenjanlı ruhsat + Türkiye Barosu kaydıdır.'],
 ['Baro','Baro, avukatların meslek örgütüdür. Organları seçimle belirlenir; baro başkanını levhaya kayıtlı avukatlar seçer. Gerçekte bir ilde baro kurulabilmesi için en az 30 avukat gerekir. Barolar adli yardım bürosuyla ödeme gücü olmayanlara avukat sağlar.'],
 ['Meslek kuralları','Avukat sır saklamak zorundadır, reklam yapamaz, aynı işte karşı tarafa hizmet vermişse işi reddetmelidir. Müvekkilin parasını kendi işinde kullanmak ve karşı tarafla gizlice anlaşmak ağır meslek ihlalidir.'],
 ['Disiplin','Avukatlık Kanunu\'ndaki disiplin cezaları: uyarma, kınama, para cezası, işten çıkarma ve meslekten çıkarma. Oyunda baro başkanı uyarı, kınama ve 3 ya da 7 gün işten yasaklama verebilir.'],
 ['Ücret','Avukatlık ücreti sözleşmeyle belirlenir; Avukatlık Asgari Ücret Tarifesi\'ni Türkiye Barolar Birliği hazırlar. Başarıya bağlı ücret dava değerinin %25\'ini aşamaz. Harç ise yargılama gideridir, avukat ücreti değildir.'],
 ['Temel ilkeler','Masumiyet karinesi: suçluluğu hükmen sabit oluncaya kadar kimse suçlu sayılamaz. Kanunsuz suç ve ceza olmaz. Herkes iddia ve savunma ile adil yargılanma hakkına sahiptir. Duruşmalar kural olarak herkese açıktır.'],
 ['Yargı yolları','İlk derece kararını bölge adliye mahkemesi istinafta inceler; adli yargıda temyiz mercii Yargıtay\'dır. İdari yargının en üst mahkemesi Danıştay\'dır. Anayasa Mahkemesine bireysel başvuru, yollar tüketildikten sonra 30 gün içinde yapılır. YSK kararları kesindir.'],
 ['Yüce Divan ve HSK','Cumhurbaşkanı, TBMM Başkanı ve bakanlar görevleriyle ilgili suçlardan Anayasa Mahkemesince Yüce Divan sıfatıyla yargılanır. Hâkim ve savcıların atanması, nakli ve disiplini Hâkimler ve Savcılar Kurulu\'nun işidir.'],
 ['Usul kavramları','Islah: kendi usul işlemini düzeltmek. Feragat: davacının talebinden vazgeçmesi. Kabul: davalının talebi kabullenmesi. Hüküm: davayı çözen karar. Kesin hüküm: kanun yolu kalmamış karar. Talep sonucu: dilekçede mahkemeden istenen şey. Hâkimin tarafsızlığından şüphe varsa taraf hâkimi reddedebilir.'],
 ['Kişiler ve kurumlar','Müdafi: şüpheli/sanığın avukatı. Bilirkişi: teknik konuda görüş veren uzman. Vekâletname: avukatın temsil yetkisini gösteren belge. İcra dairesi: kesinleşmiş alacağı zorla tahsil eder. İşçilik alacaklarında dava öncesi arabuluculuk zorunludur; belirli suçlarda uzlaştırma uygulanır.'],
 ['İspat ve delil','İspat yükü kural olarak iddia ettiği olaya dayanarak hak talep edene düşer. En güçlü delil doğrulanabilir kayıttır; sohbet delillerinde tarih, kanal ve içerik doğrulanabilir olmalıdır. Delil yoksa belirsizlik açıkça söylenir, delil uydurulmaz.'],
 ['Oyunda dava','Taraf beyanı olayları anlatır, avukat savunması hukuki gerekçeyi. Kesinleşmemiş karar "kanun yolu açık karar" diye anlatılır. Davanın düşmesi esas hakkında kazanan belirlenmeden dosyanın kapanmasıdır. Başarı oranı yalnız kesinleşmiş kararlarla ölçülür.']
];
window.avukatDersNotlari=function(){
 const m=modal('<p class="alt">Sınav bu notlardaki konulardan gelir. Notlar bilgilendirme amaçlıdır; gerçek hukuki danışmanlık yerine geçmez.</p>'
  +DERS.map(([b,t])=>'<div class="kart" style="background:var(--bg)"><b>'+h(b)+'</b><p class="alt" style="margin-top:4px">'+h(t)+'</p></div>').join('')
  +'<button class="btn ikinci" onclick="modalKapat()">Kapat</button>');
 adlFormBaslik(m,'Hukuk Akademisi · Ders notları');
};
window.avukatEgitim=()=>act('avukat_akademiye_katil',{},'Hukuk Akademisine kaydoldun; 24 saatlik eğitim başladı.');
window.avukatRuhsat=async function(){
 try{const r=await RPC('avukat_ruhsat_basvur');
  toast(r.durum==='aktif'?'Tebrikler, ruhsatın verildi! Şimdi Türkiye Barosu levhasına kaydol.':r.neden==='harc'?'Bekleme listesinde '+(r.sira||'?')+'. sıradasın; harç için cüzdanında en az 100.000 ₺ olmalı.':'Bekleme listesinde '+(r.sira||'?')+'. sıradasın. Kontenjan açılınca ruhsatın otomatik verilir.');
  await adliyeEkrani();}catch(err){error(err);}
};
window.avukatRuhsatYenile=async function(){
 try{const r=await RPC('avukat_ruhsat_yenile');toast(r.durum==='aktif'?'Ruhsatın yeniden etkinleşti.':'Bekleme listesine girdin ('+(r.sira||'?')+'. sıra). Harç alınmayacak.');await adliyeEkrani();}catch(err){error(err);}
};
window.avukatRuhsatBirak=async function(){
 if(!await onayla('Ruhsatı askıya al','Kontenjandaki yerin sıradaki adaya açılır, açık dosyalardaki vekâletlerin biter ve baro kaydın askıya girer. Daha sonra harç ödemeden yeniden sıraya girebilirsin.','Askıya al',true))return;
 act('avukat_ruhsat_birak',{},'Ruhsatın askıya alındı; kontenjanın sıradaki adaya açıldı.');
};
window.avukatKontenjanAyar=function(){
 const s=window.AVUKAT_DURUM||{},kb=s.kontenjan_bilgi||{};
 const m=modal('<p class="alt">Sabit kontenjan boş bırakılırsa formül uygulanır: her N aktif oyuncuya 1 ruhsat, en az M. Kontenjan düşürülürse mevcut avukatların ruhsatı alınmaz; yalnız yeni yerleşme durur.</p>'
  +'<div class="alan"><label>Sabit kontenjan (boş = otomatik)</label><input id="akElle" type="number" min="0" max="1000" value="'+(kb.elle??'')+'"></div>'
  +'<div class="alan"><label>Kaç aktif oyuncuya 1 ruhsat (N)</label><input id="akOran" type="number" min="1" max="1000" value="'+h(kb.oran??10)+'"></div>'
  +'<div class="alan"><label>En az kontenjan (M)</label><input id="akMin" type="number" min="0" max="1000" value="'+h(kb.min??2)+'"></div>'
  +'<div class="alan"><label>Pasif avukatın ruhsatı kaç gün sonra askıya alınsın</label><input id="akPasif" type="number" min="3" max="365" value="'+h(kb.pasif_gun??14)+'"></div>'
  +'<button class="btn altin" id="akKaydet">Kaydet</button>');
 adlFormBaslik(m,'Avukatlık kontenjanı');
 m.querySelector('#akKaydet').onclick=async()=>{
  const v=id=>{const x=m.querySelector(id).value.trim();return x===''?null:Number(x);};
  try{const r=await RPC('avukat_kontenjan_ayarla',{p_elle:v('#akElle'),p_oran:v('#akOran'),p_min:v('#akMin'),p_pasif_gun:v('#akPasif')});modalKapat();toast('Kontenjan: '+r.kontenjan);await adliyeEkrani();}catch(err){error(err);}
 };
};
window.avukatSinavAc=async function(){
 try{
 const s=await RPC('avukat_durum');
 if(!(s.sinav_sorular||[]).length)throw Error('Sınav henüz açılmadı.');
 const html='<p class="alt">20 soruyu cevapla; puan sunucuda hesaplanır. Her denemede soru seti değişir.</p>'+s.sinav_sorular.map((q,i)=>
 '<div class="kart"><b>'+(i+1)+'. '+h(q.soru)+'</b><div class="alan"><select id="hukSoru'+q.id+'">'+op('','Cevap seç')
 +(q.secenekler||[]).map((v,j)=>op(j+1,(j+1)+') '+v)).join('')+'</select></div></div>').join('')
 +'<button class="btn altin" id="hukSinavGonder">Sınavı teslim et</button>';
 const m=modal(html);adlFormBaslik(m,'Hukuk Akademisi sınavı');
 m.querySelector('#hukSinavGonder').onclick=async()=>{
  const cevap={};for(const q of s.sinav_sorular){let v=m.querySelector('#hukSoru'+q.id).value;if(!v)return toast('Lütfen bütün soruları cevaplayın.',true);cevap[q.id]=Number(v);}
  try{const r=await RPC('avukat_sinav_gonder',{p_cevaplar:cevap});
   const yanlis=(r.yanlislar||[]);
   const mm=modal('<p style="font-size:20px;font-weight:800">'+h(r.puan)+'/'+h(r.toplam||20)+' · '+(r.gecti?'Başarılı 🎉':'Başarısız')+'</p>'
    +'<p class="alt">'+(r.gecti?'Şimdi iki uygulamalı staj vakasını çöz.':'24 saat sonra yeni bir soru setiyle tekrar deneyebilirsin. Ders notları sana yardımcı olur.')+'</p>'
    +(yanlis.length?'<h3 style="font-size:16px;margin-top:10px">Yanlış cevapladığın sorular</h3>'+yanlis.map(x=>'<p class="kucuk">• '+h(x)+'</p>').join(''):'')
    +'<button class="btn" onclick="modalKapat();adliyeEkrani()">Tamam</button>');
   adlFormBaslik(mm,'Sınav sonucu');
  }catch(err){error(err);}
 };
 }catch(err){error(err);}
};
window.avukatPratikAc=async function(){
 try{
 const s=await RPC('avukat_durum'),a=s.akademi||{};
 const html=(s.uygulamalar||[]).filter(x=>!a['pratik'+x.id]).map(x=>
 '<div class="kart"><h3>Uygulamalı vaka '+x.id+'</h3><p>'+h(x.soru)+'</p><div class="alan"><select id="hukPratik'+x.id+'">'+op('','Seç')+x.secenekler.map((v,j)=>op(j+1,v)).join('')+'</select></div><button class="btn ikinci" onclick="avukatPratikGonder('+x.id+')">Yanıtı ver</button></div>').join('');
 const m=modal(html||'<p>İki vaka tamamlandı.</p>');adlFormBaslik(m,'Staj uygulaması');
 }catch(err){error(err);}
};
window.avukatPratikGonder=async id=>{
 const el=document.getElementById('hukPratik'+id);
 if(!el||!el.value)return toast('Cevabını seç.',true);
 try{let r=await RPC('avukat_pratik_gonder',{p_senaryo:id,p_cevap:Number(el.value)});modalKapat();toast(r.gecti?'Vaka başarıyla tamamlandı.':'Yanıt uygun bulunmadı; 15 dakika sonra tekrar dene.');await adliyeEkrani();}catch(err){error(err);}
};
window.avukatBuroPanel=async function(){
 try{
 const d=await RPC('avukat_durum');
 const il=await RPC('avukat_iller');
 const davetler=await RPC('avukat_buro_davetler');
 let html='<p class="alt">Büro kuruluş bedeli 250.000 ₺. Bir avukat aynı anda yalnız bir aktif büroda çalışabilir.</p>';
 if(!d.benim_burom)html+='<div class="alan"><label>Büro adı</label><input id="hukBuroAd" maxlength="90" placeholder="Örnek: Adalet Hukuk Bürosu"></div><div class="alan"><label>Kuruluş ili</label><select id="hukBuroIl">'+(il||[]).map(x=>op(x.id,x.ad)).join('')+'</select></div><button class="btn altin" id="hukBuroAc">Hukuk bürosu aç</button>';
 else html+='<h3>'+h(d.benim_burom.ad)+'</h3><button class="btn ikinci" onclick="avukatDavet('+d.benim_burom.id+')">Avukat davet et</button>';
 html+='<h3>Gelen büro davetleri</h3>'+(davetler||[]).map(x=>'<div class="liste-satir"><div class="orta"><b>'+h(x.ad)+'</b><div class="kucuk">'+h(x.kurucu)+'</div></div><button class="btn ikinci" style="width:auto" onclick="avukatDavetYanit('+x.id+',true)">Kabul</button><button class="btn ikinci" style="width:auto" onclick="avukatDavetYanit('+x.id+',false)">Reddet</button></div>').join('')+(!(davetler||[]).length?'<p class="alt">Davet yok.</p>':'');
 const m=modal(html);adlFormBaslik(m,'Hukuk büroları');
 if(!d.benim_burom)m.querySelector('#hukBuroAc').onclick=async()=>{
  const ad=m.querySelector('#hukBuroAd').value,il=Number(m.querySelector('#hukBuroIl').value);
  try{await RPC('avukat_buro_ac',{p_ad:ad,p_il:il});modalKapat();toast('Hukuk bürosu kuruldu.');await adliyeEkrani();}catch(err){error(err);}
 };
 }catch(err){error(err);}
};
window.avukatDavet=bid=>{
 const m=modal('<div class="alan"><label>Davet edeceğiniz avukatın kullanıcı adı</label><input id="hukDavetKad"></div><button class="btn altin" id="hukDavetEt">Davet gönder</button>');
 adlFormBaslik(m,'Hukuk bürosuna avukat davet et');
 m.querySelector('#hukDavetEt').onclick=async()=>{try{await RPC('avukat_buro_davet',{p_buro:bid,p_kad:m.querySelector('#hukDavetKad').value});modalKapat();toast('Davet gönderildi.');}catch(err){error(err);}};
};
window.avukatDavetYanit=(bid,kabul)=>act('avukat_buro_davet_cevap',{p_buro:bid,p_kabul:kabul},'Davet yanıtlandı.');
function davaHukukHtml(data,davaId,calisabilir){
 let html='<div class="kart" id="avukatHukukPanel"><h3>⚖️ Vekâlet ve avukat teklifleri</h3><p class="alt">Mahkemeye savunma ve beyanı yalnız ruhsatlı, baroya kayıtlı ve müvekkilce yetkilendirilmiş avukat sunar; taraflar (kişi, parti, kurum) mahkemeye doğrudan yazamaz. Ücret pazarlıkla belirlenir; başarı primi en fazla %25 olabilir.</p>';
 if(calisabilir)html+='<button class="btn altin" onclick="avukatTeklifModal('+davaId+')">Bu davaya avukatlık teklifi ver</button>';
 (data.vekaletler||[]).forEach(v=>{html+='<div class="liste-satir"><div class="orta"><b>Av. '+h(v.avukat)+' · '+h(v.taraf==='davaci'?'Davacı vekili':'Davalı vekili')+'</b><div class="kucuk">'+(Number(v.ucret)>0?money(v.ucret):'Ücretsiz / adli yardım')+' · '+(v.aktif?'Aktif vekâlet':'Sona erdi')+'</div></div>'+(v.aktif&&v.benim?'<button class="btn ikinci" style="width:auto" onclick="avukatVekaletIptal('+v.id+','+davaId+')">Vekâleti bitir</button>':'')+'</div>';});
 (data.teklifler||[]).forEach(t=>{html+='<div class="liste-satir"><div class="orta"><b>Av. '+h(t.avukat)+' · '+h(t.taraf==='davaci'?'Davacı tarafı':'Davalı tarafı')+'</b><div class="kucuk">Teklif: '+money(t.tutar)+' · Başarı primi: %'+h(t.prim)+' · '+h(t.durum)+'</div>'+(t.aciklama?'<p class="kucuk">'+h(t.aciklama)+'</p>':'')+'</div>'+(t.durum==='bekliyor'&&t.cevaplayabilirim?'<div style="display:flex;flex-direction:column;gap:4px"><button class="btn altin" style="width:auto" onclick="avukatTeklifKarar('+t.id+',true,'+davaId+')">Kabul et</button><button class="btn ikinci" style="width:auto" onclick="avukatKarsiTeklifModal('+t.id+','+davaId+')">Pazarlık</button><button class="btn ikinci" style="width:auto" onclick="avukatTeklifKarar('+t.id+',false,'+davaId+')">Reddet</button></div>':'')+'</div>';});
 (data.pazarlik||[]).forEach(z=>{html+='<div class="liste-satir"><div class="orta"><b>Karşı teklif: Av. '+h(z.avukat)+'</b><div class="kucuk">'+money(z.tutar)+' · %'+h(z.prim)+' prim · '+h(z.durum)+'</div></div>'+(z.avukat_miyim&&z.durum==='bekliyor'?'<button class="btn altin" style="width:auto" onclick="avukatPazarlikKarar('+z.teklif_id+',true,'+davaId+')">Kabul et</button><button class="btn ikinci" style="width:auto" onclick="avukatPazarlikKarar('+z.teklif_id+',false,'+davaId+')">Reddet</button>':'')+'</div>';});
 if((data.vekaletler||[]).some(v=>v.aktif&&v.avukat_miyim))html+='<button class="btn altin" onclick="avukatSavunmaModal('+davaId+')">Vekil sıfatıyla hukuki savunma ver</button>';
 return html+'</div>';
}
const oncekiDosya=adliyeDosya;
adliyeDosya=async function(id){
 await oncekiDosya(id);
 try{
  const root=document.getElementById('icerik');
  if(!root||!root.textContent.includes('Dava')&& !root.textContent.includes('#'+id))return;
  const [x,s,pazarlik]=await Promise.all([RPC('avukat_dava_durum',{p_dava:id}),RPC('avukat_durum'),RPC('avukat_pazarlik_liste',{p_dava:id}).catch(()=>[])]);
  x.pazarlik=pazarlik;
  if(document.getElementById('icerik')!==root)return;
  for(const button of root.querySelectorAll('button')){
    if(button.textContent.trim()==='Savunma / beyan ver')button.textContent='Olay beyanı ver (avukat savunması değil)';
  }
  const kayit=await RPC('adliye_detay',{p_dava:id}).catch(()=>null);
  for(const beyan of (kayit?.beyanlar||[]).filter(b=>b.rol==='avukat')){
    const satir=Array.from(root.querySelectorAll('.liste-satir')).find(n=>n.querySelector('p')?.textContent.trim()===beyan.metin.trim()&&n.querySelector('b')?.textContent.includes(beyan.yazar));
    if(satir){const bas=satir.querySelector('b');if(bas)bas.textContent='Av. '+beyan.yazar+' · Hukuki savunma';}
  }
  const eski=root.querySelector('#avukatHukukPanel');if(eski)eski.remove();
  const host=document.createElement('div');host.innerHTML=davaHukukHtml(x,id,s.calisabilir===true||(s.calisabilir==null&&s.ruhsat?.durum==='aktif'));
  root.insertAdjacentElement('afterbegin',host.firstElementChild);
 }catch(err){console.warn('Hukuk paneli:',err.message);}
};
window.avukatTeklifModal=id=>{
 const m=modal('<p class="alt">Ücret serbest pazarlıkla belirlenir. Peşin ücret kabulde doğrudan cüzdanına aktarılır; tahsil edilen tazminat üzerinden başarı primi en fazla %25 olabilir (Avukatlık Kanunu m.164).</p><div class="alan"><label>Temsil edeceğin taraf</label><select id="hukTaraf">'+op('davaci','Davacı')+op('davali','Davalı')+'</select></div><div class="alan"><label>Peşin ücret (₺)</label><input id="hukFiyat" type="number" min="0" step="1" value="100000"></div><div class="alan"><label>Tahsil edilen tazminat üzerinden prim (%)</label><input id="hukPrim" type="number" min="0" max="25" step="1" value="0"></div><div class="alan"><label>Teklif mesajı</label><textarea id="hukAcik" maxlength="500" rows="3" '+TA+'></textarea></div><button class="btn altin" id="hukTeklifGonder">Teklifi gönder</button>');
 adlFormBaslik(m,'Dava #'+id+' avukatlık teklifi');
 m.querySelector('#hukTeklifGonder').onclick=async()=>{
  try{await RPC('avukat_teklif_ver',{p_dava:id,p_taraf:m.querySelector('#hukTaraf').value,p_tutar:Number(m.querySelector('#hukFiyat').value),p_prim:Number(m.querySelector('#hukPrim').value),p_aciklama:m.querySelector('#hukAcik').value});modalKapat();toast('Avukatlık teklifi gönderildi.');await adliyeDosya(id);}catch(err){error(err);}
 };
};
window.avukatTeklifKarar=async(tid,kabul,id)=>{
 if(kabul&&!await onayla('Avukatlık sözleşmesini kabul et','Belirlenen ücret cüzdanından anında kesilerek avukata gönderilir.','Kabul et',true))return;
 try{await RPC('avukat_teklif_karar',{p_teklif:tid,p_kabul:kabul});toast(kabul?'Vekâlet sözleşmesi kuruldu.':'Teklif reddedildi.');await adliyeDosya(id);}catch(err){error(err);}
};
window.avukatVekaletIptal=async(vid,id)=>{
 if(!await onayla('Vekâleti sonlandır','Vekâlet ilişkisi sona erecek. Daha önce ödenen hizmet bedeli kendiliğinden iade edilmez.','Sonlandır',true))return;
 try{await RPC('avukat_vekalet_iptal',{p_vekalet:vid});toast('Vekâlet sonlandırıldı.');await adliyeDosya(id);}catch(err){error(err);}
};
window.avukatSavunmaModal=id=>{
 const m=modal('<div class="alan"><label>Hukuki savunma ve gerekçeler (20–2500 karakter)</label><textarea id="hukSavunma" rows="6" maxlength="2500" '+TA+'></textarea></div><button class="btn altin" id="hukSavGonder">Mahkemeye savunma sun</button>');
 adlFormBaslik(m,'Dava #'+id+' · Avukat savunması');
 m.querySelector('#hukSavGonder').onclick=async()=>{try{await RPC('avukat_savunma_ver',{p_dava:id,p_metin:m.querySelector('#hukSavunma').value});modalKapat();toast('Avukat savunması mahkemeye sunuldu.');await adliyeDosya(id);}catch(err){error(err);}};
};
window.avukatPrimTahsil=async id=>{try{const r=await RPC('avukat_prim_tahsil',{p_kayit:id});toast('Prim tahsil: '+money(r.tahsil));await adliyeEkrani();}catch(err){error(err);}};
window.avukatPazarlikKarar=async(id,kabul,dava)=>{try{await RPC('avukat_pazarlik_karar',{p_teklif:id,p_kabul:kabul});toast(kabul?'Karşı teklifi kabul ettin; müvekkil sözleşmeyi imzalayabilir.':'Karşı teklif reddedildi.');await adliyeDosya(dava);}catch(err){error(err);}};
window.avukatKarsiTeklifModal=(id,dava)=>{
 const m=modal('<div class="alan"><label>Karşı teklif ücreti (₺)</label><input id="hukKarsiTutar" type="number" min="0" step="1"></div><div class="alan"><label>Başarı primi (%)</label><input id="hukKarsiPrim" type="number" min="0" max="25" step="1" value="0"></div><button class="btn altin" id="hukKarsiGonder">Karşı teklif gönder</button>');
 adlFormBaslik(m,'Avukatla ücret pazarlığı');
 m.querySelector('#hukKarsiGonder').onclick=async()=>{try{await RPC('avukat_karsi_teklif',{p_teklif:id,p_tutar:Number(m.querySelector('#hukKarsiTutar').value),p_prim:Number(m.querySelector('#hukKarsiPrim').value)});modalKapat();toast('Karşı teklif avukata iletildi.');await adliyeDosya(dava);}catch(err){error(err);}};
};
})();
