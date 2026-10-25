/* Ülke Kriz Merkezi — 25.10.2026'da derlenen pakete geri taşındı (önceden yalnız canlı docs/index.html'deydi). Sunucu: kriz_merkezi, kriz_karar_ver, kriz_ayar_degistir. */
/* ============================================================
   ULKE KRIZ MERKEZI — seyrek, tercihli ve guvenli olaylar
   ============================================================ */
function krizGundemHtml(d) {
 if (!d) return "";
 const a=d.aktif;
 if (!a) return "";
 return '<div class="kart" style="border-top:3px solid #d58a36">'+
 '<div class="kucuk">⚠️ ÜLKE KRİZ MERKEZİ · '+e(a.kategori)+'</div>'+
 '<h2 style="margin:8px 0">'+e(a.baslik)+'</h2><p class="alt">'+e(a.aciklama)+'</p>'+
 '<p class="kucuk">Son karar zamanı: '+tarihSaat(a.karar_son)+'</p>'+
 '<button class="btn altin" onclick="ekranAc(krizMerkeziEkrani)">'+(a.karar_verebilirim?'Karar ver / incele':'Krizi incele')+'</button></div>';
}
async function krizMerkeziEkrani() {
 yukleniyor("Ülke Kriz Merkezi");
 let d;
 try { d=await API.rpc("kriz_merkezi"); }
 catch(err) { iskelet("Ülke Kriz Merkezi",'<div class="kart">'+e(hataCevir(err.message))+'</div>');return; }
 const x=d.aktif;
 let h='<div class="kart"><h2>🌿 Ülke Kriz Merkezi</h2>'+
 '<p class="alt">Oyunda iki ulusal kriz arasında en az '+Number(d.ayar.min_aralik_gun)+' gün bulunur. Haftalık yeni olay ihtimali %'+Number(d.ayar.haftalik_ihtimal)+'. Aynı anda ikinci kriz açılmaz.</p></div>';
 if (x) {
  h+='<div class="kart" style="border-top:3px solid #d58a36">'+
   '<span class="rozet">'+e(x.kategori)+'</span><h2>'+e(x.baslik)+'</h2>'+
   '<p>'+e(x.aciklama)+'</p><p class="kucuk">Karar bitişi: '+tarihSaat(x.karar_son)+'</p>';
  if(x.karar_verebilirim) {
   h+='<h3>Çözüm seçenekleri</h3><p class="alt">Bütçe kullanımı hazine bakiyesinin en çok %5’iyle ve 50.000 TL ile sınırlandırılmıştır. Karar tüm oyuncular için geçerli olur.</p>';
   h+=(x.secenekler||[]).map(o=>'<div style="padding:12px 0;border-top:1px solid var(--line)"><b>'+e(o.ad)+'</b>'+
    '<div class="kucuk">Azami hazine payı: %'+Math.round(100*Number(o.butce_payi))+' · ilgili sektör haftalık gelir etkisi: %'+((Number(o.sektor_carpan)-1)*100).toFixed(1)+'</div>'+
    '<button class="btn altin" onclick="krizKararVer('+Number(x.id)+','+e(JSON.stringify(o.kod))+')">Bu kararı uygula</button></div>').join('');
  } else h+='<p class="alt">Bu krizde karar yetkisi ilgili bakan ve cumhurbaşkanındadır. Gelişmeleri buradan takip edebilirsin.</p>';
  h+='</div>';
 } else h+='<div class="kart"><h2>Normal dönem</h2><p>Şu an aktif ulusal kriz bulunmuyor. Siyasi hayat, şirketler ve seçimler normal şekilde devam ediyor.</p></div>';
 h+='<div class="kart"><h2>Geçmiş krizler</h2>';
 h+=(d.arsiv||[]).map(z=>'<div class="liste-satir"><div class="orta"><b>'+e(z.baslik)+'</b>'+
  '<div class="kucuk">'+tarihSaat(z.bas)+' · '+(z.durum==='cozuldu'?'Yetkili kararı ile çözüldü':'Geçici planla kapatıldı')+
  ' · Kamu maliyeti: '+tlYaz(z.maliyet)+'</div></div></div>').join('')||'<p class="alt">Henüz yaşanmış kriz yok.</p>';
 h+='</div>';
 if(d.yonetici) {
  const oran=Number(d.ayar.haftalik_ihtimal);
  h+='<div class="kart"><h2>Yönetici · Kriz sıklığı</h2><p class="alt">Oyuncuları bunaltmamak için haftada en çok bir çekiliş yapılır ve minimum 14 gün aralık zorunludur.</p>'+
  '<label><input id="krizAktif" type="checkbox" '+(d.ayar.aktif?'checked':'')+'> Otomatik krizleri etkinleştir</label>'+
  '<label class="alan"><span>Haftalık olasılık</span><select id="krizIhtimal">'+[0,10,25,50].map(v=>'<option value="'+v+'" '+(oran===v?'selected':'')+'>%'+v+'</option>').join('')+'</select></label>'+
  '<button class="btn ikinci" onclick="krizAyarKaydet()">Sıklık ayarını kaydet</button></div>';
 }
 iskelet("Ülke Kriz Merkezi",h,{geri:true});
}
async function krizKararVer(id,kod) {
 if(!(typeof onayla==="function"?await onayla("Kriz kararı","Bu kriz kararını tüm ülke için uygulamak istiyor musun? Harcama devlet hazinesinden yapılacaktır.","Uygula"):confirm("Bu kriz kararını tüm ülke için uygulamak istiyor musun?")))return;
 try {
  const d=await API.rpc("kriz_karar_ver",{p_kriz:id,p_secenek:kod});
  toast("Kriz kararı uygulandı. Kamu maliyeti: "+tlYaz(d.maliyet));
  krizMerkeziEkrani();
 }catch(err){toast(hataCevir(err.message),true);}
}
async function krizAyarKaydet() {
 const aktif=!!($("#krizAktif")&&$("#krizAktif").checked);
 const oran=Number($("#krizIhtimal").value);
 try {
  await API.rpc("kriz_ayar_degistir",{p_aktif:aktif,p_ihtimal:oran});
  toast("Kriz sıklığı güncellendi.");krizMerkeziEkrani();
 }catch(err){toast(hataCevir(err.message),true);}
}
