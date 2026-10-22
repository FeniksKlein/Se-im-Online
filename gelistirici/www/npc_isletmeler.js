/* Belediye, stoklu NPC isletmeleri ve sirket devir pazari · 2026-10-22 */
(function(){
"use strict";
if(window.NPC_ISLETMELER_UI_AKTIF)return;
window.NPC_ISLETMELER_UI_AKTIF=true;
const guvenli=x=>typeof e==="function"?e(String(x??"")):String(x??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const tl=x=>Math.round(Number(x)||0).toLocaleString("tr-TR")+" ₺";
const sayi=x=>Number(x)||0;
const mili=x=>Number(x||0).toLocaleString("tr-TR",{minimumFractionDigits:4,maximumFractionDigits:4})+" milyar ₺";
const tamid=x=>Number.isSafeInteger(Number(x))&&Number(x)>0?Number(x):0;
const hata=x=>typeof hataCevir==="function"?hataCevir(x?.message||String(x)):String(x?.message||x);
function kart(baslik,icerik){return '<section class="kart" style="margin-bottom:10px"><h3>'+guvenli(baslik)+'</h3>'+icerik+'</section>';}
function satir(k,v){return '<div class="kv"><span>'+guvenli(k)+'</span><b>'+guvenli(v)+'</b></div>';}
function buton(baslik,js,ikinci){return '<button class="btn '+(ikinci?"ikinci":"altin")+'" style="margin:5px 5px 4px 0" onclick="'+js+'">'+guvenli(baslik)+'</button>';}
function hataEkrani(baslik,err){iskelet(baslik,kart("İşlem gerçekleştirilemedi",'<p class="alt">'+guvenli(hata(err))+'</p>'),{geri:true});}

async function npcIsletmeEkrani(sirketId){
 const id=tamid(sirketId);yukleniyor("İşletme · Stok ve NPC satışları");
 try{
  const d=await API.rpc("npc_isletme_panel",{p_sirket:id});
  let html=kart(d.ad,
   '<p class="alt">Sanal müşteriler her gün bu şehirde alışveriş yapar. Stok ve şirket kasası olmadığında satış yapılamaz. Satış fiyatını, ürün alımını ve giderlerini yönetebilirsin.</p>'+
   satir("Şehir",d.il)+satir("Gelişmişlik puanı",d.gelisim)+
   satir("Belediye yatırımlarının talebe etkisi","%"+d.belediye_talep_bonus)+
   satir("Şirket kasası",tl(d.kasa))+
   satir("Son 7 gün NPC cirosu",tl(d.son_7_gun?.ciro))+
   satir("Son 7 gün stok alımı",tl(d.son_7_gun?.stok_alim))+
   satir("Son 7 gün satış vergisi",tl(d.son_7_gun?.vergi))+
   buton("↻ Güncelle","npcIsletmeEkrani("+id+")",true));
  for(const u of d.urunler||[]){
   const kod=String(u.kod||"").replace(/[^a-z_]/g,"");
   html+=kart(u.ad,
    satir("Depodaki stok",Number(u.stok).toLocaleString("tr-TR")+" birim")+
    satir("Ortalama alış maliyeti",tl(u.maliyet))+
    satir("NPC satış fiyatı",tl(u.fiyat))+
    satir("Toptan piyasadan alış",tl(u.alis)+"/birim")+
    satir("Şehir tavsiye satış fiyatı",tl(u.referans)+"/birim")+
    (d.yonetici&&d.aktif?
    buton("📦 Stok satın al","npcStokAl("+id+",'"+kod+"')")+
    buton("🏷️ Fiyat belirle","npcFiyatBelirle("+id+",'"+kod+"')",true):''));
  }
  const liste=(d.son_satislar||[]).filter(x=>x.tur==="npc_satis").slice(0,10);
  html+=kart("Gerçekleşen NPC satışları",
   liste.length?liste.map(x=>satir(x.urun+" · "+x.adet+" adet",tl(x.tutar)+" · vergi "+tl(x.vergi))).join(""):
   '<p class="alt">Henüz müşteri satışı yok. Stok aldıktan sonra saatlik ekonomi işlemleri başlar.</p>');
  iskelet("İşletme yönetimi",html,{geri:true});
 }catch(err){hataEkrani("İşletme yönetimi",err);}
}
function npcStokAl(sirketId,urun){
 const id=tamid(sirketId),kod=String(urun).replace(/[^a-z_]/g,"");
 const m=modal('<h3>📦 Toptan stok satın al</h3><p class="alt">Güncel piyasa bedeli şirket kasasından çıkar, satın alınan ürün depoya girer. Stoklar NPC satışlarında azalır.</p><div class="alan"><label>Adet / litre</label><input type="number" id="npcStokMiktar" min="1" max="10000" step="1" inputmode="numeric" value="100"></div><button class="btn altin" id="npcStokOnay">Stok satın al</button><button class="btn ikinci" onclick="modalKapat()">İptal</button>');
 m.querySelector("#npcStokOnay").onclick=async function(){
  const adet=Number(m.querySelector("#npcStokMiktar").value);
  if(!Number.isSafeInteger(adet)||adet<1||adet>10000){toast("Geçerli miktar 1–10.000 olmalı.",true);return;}
  if(!await onayla("Toptan stok alımı",adet+" birim "+kod+" stok şirket kasasından piyasa fiyatıyla alınacak.","Onayla"))return;
  this.disabled=true;
  try{
   const result=await API.rpc("npc_isletme_islem",{p_eylem:"al",p_sirket:id,p_urun:kod,p_adet:adet,p_fiyat:null});
   modalKapat();toast("Stok alındı. Ödenen: "+tl(result.tutar));await npcIsletmeEkrani(id);
  }catch(err){toast(hata(err),true);}finally{this.disabled=false;}
 };
}
function npcFiyatBelirle(sirketId,urun){
 const id=tamid(sirketId),kod=String(urun).replace(/[^a-z_]/g,"");
 const m=modal('<h3>🏷️ NPC satış fiyatı</h3><p class="alt">Güncel şehir referans fiyatının %80–130 aralığını kullan. Aşırı pahalı fiyatlar şehir ekonomisindeki talebi düşürebilir.</p><div class="alan"><label>Birim satış fiyatı (₺)</label><input type="number" id="npcFiyat" min="0.01" step="0.01" inputmode="decimal"></div><button class="btn altin" id="npcFiyatOnay">Fiyatı kaydet</button><button class="btn ikinci" onclick="modalKapat()">İptal</button>');
 m.querySelector("#npcFiyatOnay").onclick=async function(){
  const tutar=Number(m.querySelector("#npcFiyat").value);
  if(!Number.isFinite(tutar)||tutar<=0){toast("Geçerli fiyat gir.",true);return;}
  this.disabled=true;
  try{
   await API.rpc("npc_isletme_islem",{p_eylem:"fiyat",p_sirket:id,p_urun:kod,p_adet:null,p_fiyat:tutar});
   modalKapat();toast("Satış fiyatı değiştirildi.");await npcIsletmeEkrani(id);
  }catch(err){toast(hata(err),true);}finally{this.disabled=false;}
 };
}
async function sirketAlimSatimEkrani(){
 yukleniyor("Şirket alım-satım pazarı");
 try{
  const [k,v]=await Promise.all([API.rpc("sirket_liste"),API.rpc("sirket_vitrini")]);
  const benim=k.sirketler||[], vitrindeki=v.sirketler||[];
  const payim=new Map(benim.map(x=>[Number(x.id),Number(x.pay)]));
  const satilik=vitrindeki.filter(x=>x.satilik!=null);
  let html=kart("🏢 Şirket alım-satım pazarı",
   '<p class="alt">Marketini, fabrikayı, akaryakıt istasyonunu ya da diğer şirketini başka bir oyuncuya satabilirsin. %100 sahibi olduğun faal şirketleri listeleyebilirsin. Ortaklık hissesi satışı mevcut şirket finansmanı ekranından yapılır.</p>'+
   '<p class="alt">Devlet devir vergisi oyun içi damga tarifesiyle hesaplanır (şu anda %1). Alıcı satış bedelini, satıcı devir vergisini öder. Stoklar, şirket kasası ve faaliyet kayıtları şirkette kalır. İcra haczi ve konkordato devirleri sınırlar.</p>');
  const sahipler=vitrindeki.filter(x=>payim.get(Number(x.id))===100&&!x.halka_acik);
  html+=kart("Satışa çıkarabileceğim şirketler",sahipler.length?
   sahipler.map(s=>'<div style="padding:10px 0;border-bottom:1px solid var(--line)"><b>'+guvenli(s.ad)+'</b>'+satir("Sektör",s.sektor)+satir("Şirket kasası",tl(s.kasa))+
     (s.satilik!=null?satir("İlan fiyatı",tl(s.satilik)):"")+
     buton(s.satilik!=null?"İlanı güncelle":"Satışa çıkar","sirketSatisaCikar("+tamid(s.id)+")")+
     (s.satilik!=null?buton("İlanı kaldır","sirketSatisIptal("+tamid(s.id)+")",true):"")+'</div>').join(""):
   '<p class="alt">Satılabilecek %100 sahip olduğun faal şirket bulunamadı.</p>');
  const piyasa=satilik.filter(x=>!payim.has(Number(x.id)));
  html+=kart("Diğer oyuncuların satış ilanları",
    piyasa.length?piyasa.map(s=>'<div style="padding:10px 0;border-bottom:1px solid var(--line)"><b>'+guvenli(s.ad)+'</b>'+
       satir("Satıcı",s.sahip||s.kurucu)+satir("Sektör",s.sektor)+satir("Kasa",tl(s.kasa))+
       satir("Satış bedeli",tl(s.satilik))+
       buton("Şirketi satın al","sirketSatinAl("+tamid(s.id)+")")+'</div>').join(""):
       '<p class="alt">Şimdilik başka oyuncunun satılık şirketi yok.</p>');
  iskelet("Şirket Pazarı",html,{geri:true});
 }catch(err){hataEkrani("Şirket Pazarı",err);}
}
function sirketSatisaCikar(sirketId){
 const id=tamid(sirketId);
 const m=modal('<h3>Şirketi satışa çıkar</h3><p class="alt">Şirketin tamamına (%100) alıcı aranır. Satış gerçekleştiğinde yönetim, şirket kasası ve stoklar yeni sahibine geçer; satıcı satış üzerinden devir vergisi öder.</p><div class="alan"><label>Satış fiyatı (₺)</label><input type="number" id="sPazarFiyat" step="1" min="1000" max="1000000000" inputmode="numeric"></div><button id="sPazarKaydet" class="btn altin">İlanı yayımla</button><button class="btn ikinci" onclick="modalKapat()">İptal</button>');
 m.querySelector("#sPazarKaydet").onclick=async function(){
  const fiyat=Number(m.querySelector("#sPazarFiyat").value);
  if(!Number.isSafeInteger(fiyat)||fiyat<1000||fiyat>1000000000){toast("Geçerli tam sayı fiyat gir.",true);return;}
  if(!await onayla("Şirket satış ilanı","Şirketin tamamı "+tl(fiyat)+" bedelle satışa çıkacak.","İlanı aç"))return;
  this.disabled=true;
  try{await API.rpc("sirket_satiliga_cikar",{p_sirket:id,p_fiyat:fiyat});modalKapat();toast("Şirket satış ilanı açıldı.");await sirketAlimSatimEkrani();}
  catch(err){toast(hata(err),true);}finally{this.disabled=false;}
 };
}
async function sirketSatisIptal(id){
 if(!await onayla("İlanı kaldır","Şirketin satılık ilanını kaldırmak istiyor musun?","Kaldır"))return;
 try{await API.rpc("sirket_satiliga_cikar",{p_sirket:tamid(id),p_fiyat:null});toast("İlan kaldırıldı.");await sirketAlimSatimEkrani();}
 catch(err){toast(hata(err),true);}
}
async function sirketSatinAl(id){
 if(!await onayla("Şirket satın al","Satış bedeli cüzdanından düşülecek. Satıcıdan devir vergisi alınacak. Şirketin kasası, stokları, yükümlülükleri ve kayıtları birlikte devredilecek.","Satın al"))return;
 try{
  await API.rpc("sirket_satilik_al",{p_sirket:tamid(id)});
  toast("Şirket satın alındı. Şirketlerim ekranında görebilirsin.");await sirketAlimSatimEkrani();
 }catch(err){toast(hata(err),true);}
}
async function belediyeYatirimEkonomiEkrani(ilId){
 yukleniyor("Şehir yatırımlarının ekonomik etkisi");
 try{
  const d=await API.rpc("belediye_yatirim_ekonomi_panel",{p_il:Number(ilId)});
  let h=kart(d.il+" · Belediye ekonomisi",
    '<p class="alt">Oyuncu olmasa da şehirde NPC nüfusu ve ekonomi simülasyonu işler. Yatırımlar kalıcı vergi/ödenek çarpanı, bakım gideri, ticari müşteri talebi ve gelişmişlik hedefi oluşturur.</p>'+
    satir("Şehir gelişmişliği",d.gelisim)+satir("Halk memnuniyeti",d.memnuniyet)+
    satir("Belediye kasası",mili(d.kasa))+satir("Günlük toplam gelir",mili(d.gunluk_gelir))+
    satir("Günlük toplam gider",mili(d.gunluk_gider))+
    satir("Günlük net bütçe",mili(sayi(d.gunluk_gelir)-sayi(d.gunluk_gider)))+
    satir("Yatırım kaynaklı gelir/ödenek bonusu","%"+d.yatirim_gelir_yuzdesi)+
    satir("Yatırım bakım yükü","%"+d.yatirim_bakim_yuzdesi)+
    satir("NPC müşteri talebi etkisi","%"+d.npc_talep_yuzdesi)+
    satir("Gelişmişliğe kalıcı hedef katkısı","+"+d.kalici_gelisim_destegi));
  h+=kart("Yapılan belediye yatırımları",
   (d.yatirimlar||[]).map(x=>satir(x.ad,x.adet+" kez")).join("")||
   '<p class="alt">Henüz şehir yatırımı bulunmuyor.</p>');
  iskelet("Belediye ekonomi raporu",h,{geri:true});
 }catch(err){hataEkrani("Belediye ekonomi raporu",err);}
}
window.npcIsletmeEkrani=npcIsletmeEkrani;
window.npcStokAl=npcStokAl;
window.npcFiyatBelirle=npcFiyatBelirle;
window.sirketAlimSatimEkrani=sirketAlimSatimEkrani;
window.sirketSatisaCikar=sirketSatisaCikar;
window.sirketSatisIptal=sirketSatisIptal;
window.sirketSatinAl=sirketSatinAl;
window.belediyeYatirimEkonomiEkrani=belediyeYatirimEkonomiEkrani;

const oncekiBelediye=window.belediyeEkrani;
if(typeof oncekiBelediye==="function"){
 window.belediyeEkrani=async function(){
  await oncekiBelediye();
  const kartlar=document.querySelectorAll(".kart");
  if(!kartlar.length)return;
  try{
   const b=await API.rpc("belediye_paneli");
   if(!b||!b.il_id||kartlar[0].querySelector(".npc-bel-buton"))return;
   const btn=document.createElement("button");btn.className="btn ikinci npc-bel-buton";
   btn.style.marginTop="8px";btn.textContent="📊 Yatırım gelirleri · giderleri · NPC şehir ekonomisi";
   btn.onclick=()=>belediyeYatirimEkonomiEkrani(b.il_id);
   kartlar[0].appendChild(btn);
  }catch(_){}
 };
}
})();
