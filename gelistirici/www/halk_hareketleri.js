/* SO_HALK_HAREKETLERI_V1 — web ve mobil ortak ekran */
async function sokakHareketleriEkrani(){
 yukleniyor('Halk Hareketleri');
 try {
  const d=await API.rpc('sokak_eylemler'),a=d.ayar||{},fmt=n=>Number(n||0).toLocaleString('tr-TR'),date=t=>t?new Date(t).toLocaleString('tr-TR'):'—';
  let h='<div class="kart"><h2>📢 Halk Hareketleri</h2><p>Barışçıl gösteriler, ortak fonlama ve hükümetle uzlaşma.</p><details><summary>Kurallar ve kötüye kullanım sınırları</summary><p>Başlatma: muhalefet genel başkanı, 7 günlük hesap, ilde en az 3 aktif oyuncu ve 35/100 memnuniyetsizlik. Parti kasasından '+fmt(a.baslatma_bedeli)+' TL.</p><p>İlde tek eylem; kapanıştan sonra 7 gün bekleme. Parti başına tek aktif eylem ve 72 saat bekleme. Ülkede en fazla 6 eylem. Her kişi/kurum en fazla 3 eylemi destekleyebilir.</p><p>İlk süre 24 saat. Her '+fmt(a.baslatma_bedeli)+' TL ek protesto fonu 12 saat kazandırır; toplam en fazla 5 gün. Katılım için 3 günlük hesap ve ilde 3 günlük ikamet gerekir.</p><p>Son 24 saat fon limiti: kişi '+fmt(a.baslatma_bedeli*2)+' TL, kurum '+fmt(a.baslatma_bedeli*5)+' TL. Uzlaşma tarafında bu limitler üç kattır. Eylem protesto fonu en fazla '+fmt(a.baslatma_bedeli*20)+' TL. Harcamalar iade edilmez.</p><p>Kırmızı: en az 75 puan, 40 memnuniyetsizlik ve en az 5 yerel katılımcı (aktif ilin %30’u). Para tek başına yeterli değildir. Uzlaşma fonu protesto fonunun 3 katına ulaşınca eylem kapanır.</p><p>Erken seçim: en az 3 kırmızı il ve aktif ülkenin %20’si (en az 15 kişi), kesintisiz 72 saat. Yakın seçim, yeni hükümetin ilk 7 günü ve 14 günlük kriz seçimi beklemesi korunur. Cumhurbaşkanı seçimle devredene kadar görevde kalır.</p><p>Kırmızı eylemler büyümeyi ve hükümet memnuniyetini sınırlı etkiler; şirketlerin kâr beklentisi değerine en fazla %6 risk indirimi uygulanır. Hükümet açıklaması tek başına sayacı sıfırlamaz; fon veya gerçek hizmet iyileşmesi gerekir.</p></details></div>';
  if(d.kriz?.kirmizi_baslangic)h+='<div class="kart"><b>Ulusal kriz sayacı</b><p>Başlangıç: '+e(date(d.kriz.kirmizi_baslangic))+'</p><p>Koşullar bozulursa 72 saat sayacı sıfırlanır.</p></div>';
  if(!d.aktif)h+='<div class="kart">Halk hareketleri şu anda kapalı.</div>';
  if(d.aktif&&d.baslatabilir)h+='<div class="kart"><h3>Eylem başlat</h3><form id="hhYeni"><label>İl · memnuniyetsizlik</label><select name="il">'+(d.iller||[]).map(i=>'<option value="'+Number(i.id)+'">'+e(i.ad)+' · '+fmt(i.memnuniyetsizlik)+'/100</option>').join('')+'</select><label>Somut talep ve gerekçe</label><textarea name="metin" minlength="15" maxlength="400" required></textarea><p>Parti kasasından '+fmt(a.baslatma_bedeli)+' TL harcanır.</p><button class="btn altin">Ücreti öde ve başlat</button></form></div>';
  const kaynak=(d.kaynaklar||[]).map((k,i)=>'<option value="'+i+'">'+e(k.ad)+'</option>').join('');
  for(const x of d.eylemler||[]){
   const active=d.aktif&&x.durum==='aktif',red=!!x.kirmizi_baslangic;
   h+='<div class="kart"><h3>'+e(x.il)+' · '+e(x.parti)+'</h3><p>'+e(x.gerekce)+'</p><p><b>'+(active?(red?'🔴 Kırmızı':Number(x.seviye)>=45?'🟠 Turuncu':'🟡 Sarı'):e(x.durum))+'</b> · '+fmt(x.seviye)+'/100 · '+fmt(x.katilim)+' katılım</p><p>Memnuniyetsizlik '+fmt(x.memnuniyetsizlik)+'/100<br>Bitiş '+e(date(x.bitis))+'</p><p>Protesto: '+fmt(x.muhalefet_fonu)+' TL<br>Uzlaşma: '+fmt(x.iktidar_fonu)+' TL<br>Yatışma için kalan: '+fmt(Math.max(0,x.muhalefet_fonu*3-x.iktidar_fonu))+' TL</p>';
   if(x.hukumet_yaniti)h+='<blockquote><b>Hükümet yanıtı</b><p>'+e(x.hukumet_yaniti)+'</p></blockquote>';
   if(active){
    if(!d.iktidar)h+='<button class="btn" data-hh-katil="'+Number(x.id)+'">Yerel katılım ver</button>';
    h+='<form class="hhFon" data-id="'+Number(x.id)+'"><label>Taraf</label><select name="taraf">'+(!d.iktidar?'<option value="muhalefet">Protestoyu destekle</option>':'')+'<option value="iktidar">Uzlaşmayı destekle</option></select><label>Ödeme kaynağı</label><select name="kaynak">'+kaynak+'</select><label>Tutar (TL)</label><input name="tutar" type="number" min="1000" step="0.01" required><button class="btn altin">Fonu öde</button></form>';
    if(d.hukumet)h+='<form class="hhYanit" data-id="'+Number(x.id)+'"><label>Hükümetin çözüm yanıtı</label><textarea name="metin" minlength="20" maxlength="500" required></textarea><button class="btn">Yanıtı yayımla</button></form>';
   }
   h+='<details><summary>Destekçiler</summary>'+(x.destekler||[]).map(k=>'<p>'+e(k.ad||k.tur)+' · '+e(k.taraf==='iktidar'?'Uzlaşma':'Protesto')+' · '+fmt(k.tutar)+' TL</p>').join('')+'</details></div>';
  }
  if(!(d.eylemler||[]).length)h+='<div class="kart">Henüz eylem yok. Yeni eylem için ilin memnuniyetsizlik ve katılım şartlarını sağlaması gerekir.</div>';
  iskelet('Halk Hareketleri',h,{geri:true});
  async function run(b,fn,args){b.disabled=true;try{await API.rpc(fn,args);toast('İşlem tamamlandı');await sokakHareketleriEkrani();}catch(err){toast(hataCevir(err.message),true);b.disabled=false;}}
  document.getElementById('hhYeni')?.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(ev.currentTarget);run(ev.currentTarget.querySelector('button'),'sokak_eylem_baslat',{p_il:Number(f.get('il')),p_gerekce:String(f.get('metin'))});});
  document.querySelectorAll('[data-hh-katil]').forEach(b=>b.addEventListener('click',()=>run(b,'sokak_destek',{p_eylem:Number(b.dataset.hhKatil),p_taraf:'muhalefet'})));
  document.querySelectorAll('.hhFon').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(form),k=d.kaynaklar[Number(f.get('kaynak'))];run(form.querySelector('button'),'sokak_destek',{p_eylem:Number(form.dataset.id),p_taraf:String(f.get('taraf')),p_kaynak:k.tur,p_kaynak_id:k.id,p_tutar:Number(f.get('tutar'))});}));
  document.querySelectorAll('.hhYanit').forEach(form=>form.addEventListener('submit',ev=>{ev.preventDefault();run(form.querySelector('button'),'sokak_yanit',{p_eylem:Number(form.dataset.id),p_metin:String(new FormData(form).get('metin'))});}));
 }catch(err){iskelet('Halk Hareketleri','<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
// Kaynak derlemesine kalıcı menü bağlantısı.
(function(){const eski=iskelet;iskelet=function(baslik,govde,opt){if(baslik==='Partiler')govde='<div class="kart"><button class="btn altin" onclick="ekranAc(sokakHareketleriEkrani)">📢 Halk Hareketleri · Protestolar ve uzlaşma</button></div>'+govde;return eski(baslik,govde,opt);};})();
