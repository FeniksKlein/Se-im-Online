/* Seçim Online — Hayat > Görevler. Ödüller yalnız sunucuda doğrulanır. */
function gorevSec(alan, deger) {
  D["_gorev"+alan]=deger;
  D._gorevSayfa=1;
  gorevCiz();
}
async function gorevEkrani(){
  yukleniyor("Görevler");
  try{
    D._gorevVeri=await API.rpc("gorevlerim");
    if(!D._gorevDonem)D._gorevDonem="gunluk";
    if(!D._gorevKategori)D._gorevKategori="hepsi";
    if(!D._gorevDurum)D._gorevDurum="hepsi";
    if(!D._gorevSayfa)D._gorevSayfa=1;
    gorevCiz();
  }catch(err){
    iskelet("Görevler",'<div class="kart"><p>'+e(hataCevir(err.message))+'</p><button class="btn ikinci" onclick="gorevEkrani()">Tekrar dene</button></div>',{geri:true});
  }
}
function gorevCiz(){
  var d=D._gorevVeri;
  if(!d || !Array.isArray(d.gorevler))return;
  var donem=D._gorevDonem||"gunluk", kategori=D._gorevKategori||"hepsi", durum=D._gorevDurum||"hepsi";
  var donemler=[["gunluk","Günlük"],["haftalik","Haftalık"],["tek","Başarılar"]];
  var kaynak=d.gorevler.filter(x=>x.donem===donem);
  var kategoriler=[...new Set(kaynak.map(x=>x.kategori))].sort((a,b)=>a.localeCompare(b,"tr"));
  var hazir=x=>!x.alindi&&x.ilerleme>=x.hedef;
  var goster=kaynak.filter(x=>(kategori==="hepsi"||x.kategori===kategori)&&
    (durum==="hepsi"||durum==="hazir"&&hazir(x)||durum==="devam"&&!x.alindi&&!hazir(x)||durum==="alindi"&&x.alindi));
  goster.sort((a,b)=>{var z=x=>hazir(x)?0:x.alindi?2:1;
    return z(a)-z(b)||((b.ilerleme/b.hedef)-(a.ilerleme/a.hedef))||a.baslik.localeCompare(b.baslik,"tr");});
  var gunlukKalan=Math.max(0,Number(d.gunluk_limit)-Number(d.bugun_kazanilan));
  var durumAcik=donem==="gunluk"?"Her gün Türkiye saatiyle gece yarısı yenilenir.":
     donem==="haftalik"?"Her pazartesi Türkiye saatiyle gece yarısı yenilenir.":
     "Her başarının beş seviyesi var. Her seviyenin ödülü bir kez kazanılır.";
  var h='<div class="kart"><h2>Görev merkezi</h2><p class="alt">Siyasi hayat, ticaret ve toplumsal faaliyetlerle oyun parası kazan.</p>'+
    '<div class="kv"><span class="k">Toplam görev</span><b>'+d.gorevler.length+'</b></div>'+
    '<div class="kv"><span class="k">Bugün kazandığın</span><b>'+tlYaz(d.bugun_kazanilan)+'</b></div>'+
    '<div class="kv"><span class="k">Günlük kalan ödül</span><b>'+tlYaz(gunlukKalan)+'</b></div>'+
    '<div class="bar"><i style="width:'+Math.min(100,Number(d.bugun_kazanilan)*100/Math.max(1,Number(d.gunluk_limit)))+'%;background:var(--good)"></i></div>'+
    '<p class="kucuk" style="margin-top:9px">Günlük kazanç limiti '+tlYaz(d.gunluk_limit)+'. Yalnız sunucunun doğruladığı işlemler ödüllendirilir.</p></div>';
  h+='<div class="segment" style="margin:12px 0">'+donemler.map(function(x){
      return '<button class="'+(donem===x[0]?'aktif':'')+'" onclick="gorevSec(\'Donem\',\''+x[0]+'\')">'+x[1]+' · '+d.gorevler.filter(y=>y.donem===x[0]).length+'</button>';
    }).join("")+'</div>';
  h+='<p class="alt" style="margin-bottom:10px">'+durumAcik+' · '+kaynak.filter(hazir).length+' ödül almaya hazır</p>';
  h+='<div class="satir" style="gap:8px;margin-bottom:12px">'+
    '<div class="alan" style="flex:1;margin:0"><label>Kategori</label><select onchange="gorevSec(\'Kategori\',this.value)">'+
    '<option value="hepsi">Tüm kategoriler</option>'+
    kategoriler.map(function(x){return '<option value="'+e(x)+'" '+(kategori===x?'selected':'')+'>'+e(x)+'</option>';}).join("")+
    '</select></div><div class="alan" style="flex:1;margin:0"><label>Durum</label><select onchange="gorevSec(\'Durum\',this.value)">'+
    [["hepsi","Tümü"],["hazir","Ödüle hazır"],["devam","Devam eden"],["alindi","Alınan"]].map(function(x){
      return '<option value="'+x[0]+'" '+(durum===x[0]?'selected':'')+'>'+x[1]+'</option>';
    }).join("")+'</select></div></div>';
  var sinir=Math.max(1,D._gorevSayfa||1)*40;
  for(var x of goster.slice(0,sinir)){
    var yuzde=Math.min(100,Math.max(0,100*x.ilerleme/Math.max(1,x.hedef)));
    h+='<div class="kart" style="margin-bottom:10px"><div style="display:flex;justify-content:space-between;gap:8px">'+
       '<div class="orta"><span class="kucuk">'+e(x.kategori)+(x.seviye?' · Seviye '+x.seviye:'')+'</span><h3 style="font-size:17px">'+e(x.baslik)+'</h3></div>'+
       '<b style="color:var(--good);white-space:nowrap">'+(x.alindi?'✓ ':'+')+tlYaz(x.odul)+'</b></div>'+
       '<p class="alt" style="margin:7px 0">'+e(x.aciklama)+'</p>'+
       '<div class="bar"><i style="width:'+yuzde+'%;background:'+(hazir(x)||x.alindi?'var(--good)':'var(--ink)')+'"></i></div>'+
       '<div class="satir" style="align-items:center;justify-content:space-between;margin:8px 0 0">'+
       '<span class="kucuk">'+x.ilerleme+' / '+x.hedef+' ilerleme</span>';
    if(x.alindi) h+='<span class="rozet yesil">Ödül alındı</span>';
    else if(hazir(x))h+='<button class="btn altin" style="width:auto;padding:8px 12px;margin:0" onclick="gorevOdulAl('+Number(x.id)+')">Ödülü al</button>';
    else h+='<button class="btn ikinci" style="width:auto;padding:8px 12px;margin:0" onclick="gorevGit(\''+e(x.rota)+'\')">Göreve git ›</button>';
    h+='</div></div>';
  }
  if(!goster.length)h+='<div class="kart"><p class="alt">Bu filtrede görev bulunamadı. Kategori veya durumu değiştirebilirsin.</p></div>';
  if(goster.length>sinir)h+='<button class="btn ikinci" onclick="D._gorevSayfa++;gorevCiz()">Daha fazla göster · '+(goster.length-sinir)+' görev daha</button>';
  h+='<div class="kart"><p class="kucuk">Para ödülleri yalnız oyun içindir. Bir görev seviyesi aynı dönemde tekrar ödüllendirilemez. Bazı görevlerdeki ilerleme daha önce kazandığın başarılarla birlikte sayılabilir.</p></div>';
  iskelet("Görevler",h,{geri:true});
}
async function gorevOdulAl(id){
  var b=[...document.querySelectorAll("#icerik button")].filter(x=>x.getAttribute("onclick")==="gorevOdulAl("+id+")");
  b.forEach(x=>x.disabled=true);
  try{
    var r=await API.rpc("gorev_odul_al",{p_gorev:id});
    toast("Görev ödülü kazandın: +"+tlYaz(r.odul));
    await gorevEkrani();
    try{await durumYenile()}catch(_){}
  }catch(err){b.forEach(x=>x.disabled=false);toast(hataCevir(err.message),true);}
}
function gorevGit(k){
  if(["sohbet","parti","gundem","dernek","devlet"].includes(k)){sekmeAc(k);return;}
  if(k==="basin"){ekranAc(basinEkrani);return;}
  if(k==="sivil"){ekranAc(()=>sosEkran("imza"));return;}
  if(k==="sirket"){ekranAc(sirketVitrinEkrani);return;}
  if(k==="emlak"){ekranAc(emlakYeniEkrani);return;}
  sekmeAc("hayat");
}
