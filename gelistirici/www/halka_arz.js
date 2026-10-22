// Şirket halka arzı — gerçek hayattaki SPK / Borsa İstanbul sürecine göre (sunucu: migrations/20261022_halka_arz_gercekci.sql)
// Süreç: A.Ş. → izahname + SPK başvurusu → SPK incelemesi → talep toplama → eşit dağıtım + iade → borsada işlem + satmama taahhüdü.
const HA_SEKTOR={tarim:"Tarım",sanayi:"Sanayi",teknoloji:"Teknoloji",ticaret:"Ticaret",insaat:"İnşaat",medya:"Medya",banka:"Banka",
 market:"Market",enerji:"Enerji",ozel_hastane:"Özel hastane",ozel_okul:"Özel okul",ulasim:"Ulaşım",turizm:"Turizm",lojistik:"Lojistik",
 oto_servis:"Oto servis",danismanlik:"Danışmanlık",e_ticaret:"E-ticaret",geri_donusum:"Geri dönüşüm",ajans:"Ajans",
 akaryakit:"Akaryakıt",yapi_market:"Yapı market",elektronik_magaza:"Elektronik",tekstil_magaza:"Giyim",mobilya_magaza:"Mobilya",oto_galeri:"Oto galeri"};
const HA_KURAL_VARSAYILAN={spk_saat:3,kilit_gun:7,soguma_tamam_gun:3,soguma_iptal_saat:24,min_faaliyet_gun:3,ilk_arz_min_pay:10,en_cok_pay:49,
 en_az_talep:1000,en_az_buyukluk:10000,spk_ucret:0.2,borsa_ucret:0.1,araci_komisyon:1.5,masraf_toplam:1.8};
let _ha=null,_haListe=[],_haIstek=0,_haZaman=null;
const haTL=x=>fmt(Math.round(Number(x)||0))+" ₺";
const haYuzde=x=>"%"+(Math.round((Number(x)||0)*100)/100).toLocaleString("tr-TR");
const haKural=d=>Object.assign({},HA_KURAL_VARSAYILAN,(d&&d.kural)||{});
function haKalan(bit){const ms=new Date(bit)-Date.now();if(ms<=0)return"süre doldu, sonuçlanıyor";const g=Math.floor(ms/864e5),s=Math.floor(ms%864e5/36e5),d=Math.floor(ms%36e5/6e4);return(g?g+" gün ":"")+(s?s+" sa ":"")+d+" dk kaldı"}
function haDurumAd(d){return{acik:"Süreç devam ediyor",tamam:"Tamamlandı",basarisiz:"Gerçekleşmedi",iptal:"İptal edildi"}[d]||d}
function haAsamaAd(a){return a.durum!=="acik"?haDurumAd(a.durum):a.asama==="spk"?"SPK incelemesinde":"Talep topluyor"}

function haCubuk(a){
 const hedef=Number(a.hedef)||1,talep=Number(a.toplanan)||0,kat=talep/hedef,o=Math.min(100,kat*100),as=Math.min(100,Number(a.asgari)/hedef*100);
 return `<div style="position:relative;height:12px;border-radius:6px;background:var(--panel2);overflow:hidden;margin:8px 0 4px" role="progressbar" aria-valuenow="${Math.round(o)}" aria-valuemin="0" aria-valuemax="100" aria-label="Talep doluluk oranı">
 <div style="height:100%;width:${o}%;background:${kat>1?"var(--good)":"var(--ink)"}"></div><div title="Asgari tutar" style="position:absolute;top:0;bottom:0;left:${as}%;width:2px;background:var(--al)"></div></div>
 <p class="kucuk">${haTL(talep)} talep / ${haTL(hedef)} büyüklük · ${kat>1?`<b style="color:var(--good)">${(Math.round(kat*100)/100).toLocaleString("tr-TR")} kat talep, eşit dağıtım yapılacak</b>`:`asgari ${haTL(a.asgari)} (kırmızı çizgi)`} · ${Number(a.yatirimci)||0} yatırımcı</p>`}

function haSurec(d){
 const a=d.acik,as=!!d.as_mi,k=haKural(d);
 const adim=!as?0:!a?1:a.asama==="spk"?2:3;
 const satir=(i,baslik,acik)=>{const dur=i<adim?"✓":i===adim?"●":"○";const renk=i<adim?"var(--good)":i===adim?"var(--ink2)":"var(--faint)";
  return `<div style="display:flex;gap:10px;align-items:flex-start;padding:7px 0;border-bottom:1px solid var(--line)"><b style="color:${renk};min-width:16px">${dur}</b><div><b style="font-size:14px">${baslik}</b><div class="kucuk">${acik}</div></div></div>`};
 return `<div class="kart"><h2>Halka arz süreci</h2>
  ${satir(0,"Anonim şirket (A.Ş.)","Halka arz yalnız A.Ş. yapılır. Ltd. Şti. önce şirket karnesinden dönüşür.")}
  ${satir(1,"İzahname ve SPK başvurusu",`Fiyat tespit raporu (şirket değeri), satış yöntemi, fon kullanım yeri. En az ${k.min_faaliyet_gun} günlük faaliyet geçmişi gerekir.`)}
  ${satir(2,"SPK incelemesi",`${k.spk_saat} saat sürer. Şartlar bozulursa (A.Ş. değilse, pay %50'nin altına düştüyse) SPK reddeder.`)}
  ${satir(3,"Talep toplama","24, 48 ya da 72 saat. Büyüklük dolsa da süre sonuna kadar sürer; yatırımcılar talebini artırabilir ya da geri alabilir.")}
  ${satir(4,"Dağıtım","Talep büyüklüğü aşarsa eşit dağıtım yapılır, artan para iade edilir. Asgari tutara ulaşılmazsa herkese iade edilir.")}
  ${satir(5,"Borsada işlem",`Paylar borsada işlem görür. Başvuran ve %5+ eski ortaklar ${k.kilit_gun} gün satmama taahhüdü altındadır.`)}
 </div>`}

// Şirketlerim ekranındaki her şirket kartına eklenen giriş
function halkaArzKart(s){
 return `<div class="kart" style="background:var(--panel2);margin:10px 0"><h3>Halka arz</h3>
 <p class="alt">${Number(s.pay)>=50?"Şirketini SPK onayıyla halka arz edip oyunculardan sermaye topla ya da payının bir kısmını sat.":"Bu şirketin halka arz durumunu ve yatırım hesabını gör."}</p>
 <button class="btn altin" onclick="halkaArzEkrani(${Number(s.id)})">${Number(s.pay)>=50?"Halka arz et / hesapla":"Halka arz durumu"}</button></div>`;
}

async function halkaArzEkrani(id){
 yukleniyor("Halka arz");
 try{
  const d=await API.rpc("halka_arz_durum",{p_sirket:id});_ha=d;_haListe=[];
  const k=haKural(d),benim=Number(d.payim)>=50,a=d.acik;
  iskelet("Halka arz",`
  <div class="kart"><h2>${e(d.ad)}</h2>
   <p class="alt">${e(HA_SEKTOR[d.sektor]||d.sektor)} · ${d.as_mi?'<span class="rozet">A.Ş.</span>':'<span class="rozet">Ltd. Şti.</span>'} ${d.halka_acik?'<span class="rozet yesil">Borsada</span>':""} · payın ${haYuzde(d.payim)}</p>
   <div class="kv"><span>Sermaye</span><b>${haTL(d.sermaye)}</b></div>
   <div class="kv"><span>Şirket kasası</span><b>${haTL(d.kasa)}</b></div>
   <div class="kv"><span>Haftalık net kâr tahmini</span><b>${d.ort_net==null?"—":haTL(d.ort_net)}</b></div>
   ${d.kilit_bit?`<p class="kucuk" style="color:var(--warn)">Satmama taahhüdü: bu şirketteki payların ${tarihSaat(d.kilit_bit)} tarihine kadar satılamaz.</p>`:""}
  </div>
  ${haSurec(d)}
  ${a?haAcikKart(a,true):""}
  ${Number(d.payim)>0?`<div class="kart"><h2>Kâr payı tercihin</h2>
   <p class="alt">Ortak olarak kâr payını cüzdanına alabilir ya da şirket kasasında bırakabilirsin.</p>
   <div class="kv"><span>Şu an</span><b>${d.kar_kasada?"Şirket kasasında kalsın":"Cüzdanıma gelsin"}</b></div>
   <button class="btn ikinci" onclick="haKarTercihDegistir(${Number(d.id)},${d.kar_kasada?"false":"true"})">${d.kar_kasada?"Kâr payımı cüzdanıma aktar":"Kâr payımı şirket kasasında biriktir"}</button></div>`:""}
  ${benim&&!a?haBasvuruKarti(d,k):""}
  ${!benim&&!a?`<div class="kart"><p class="alt">Halka arz başvurusunu şirketin en az %50'sine sahip ortak yapar.</p></div>`:""}
  ${(d.gecmis||[]).length?`<div class="kart"><h2>Geçmiş halka arzlar</h2>${d.gecmis.map(g=>`<div class="kv"><span>${tarihSaat(g.sonuc_zaman||g.bas)} · ${haDurumAd(g.durum)}</span><b>${haTL(g.satilan!=null?g.satilan:g.toplanan)}</b></div><p class="kucuk">${e(g.aciklama||"")}</p>`).join("")}</div>`:""}
  <button class="btn ikinci" onclick="halkaArzPazarEkrani()">Tüm halka arzlar</button>
  `,{geri:true});
  haHesapCiz();
  if(a&&!a.ben_baslattim)haTalepOnizle(a.id);
 }catch(err){iskelet("Halka arz",`<div class="bos">${e(hataCevir(err.message))}</div>`,{geri:true})}
}

function haBasvuruKarti(d,k){
 if(!d.as_mi)return `<div class="kart"><h2>Önce anonim şirket ol</h2>
   <p class="alt">Gerçekte olduğu gibi halka arz yalnız anonim şirketlerde yapılır. Dönüşüm için en az 250.000 ₺ sermaye ve ticaret sicili tescil harcı gerekir.</p>
   ${typeof sirketKarnesiEkrani==="function"?`<button class="btn altin" onclick="ekranAc(()=>sirketKarnesiEkrani(${Number(d.id)}))">Şirket karnesi · A.Ş.'ye dönüştür</button>`:""}</div>`;
 if(d.soguma_bit&&new Date(d.soguma_bit)>new Date())return `<div class="kart"><h2>SPK başvurusu</h2>
   <p class="alt">${e(d.soguma_neden||"Yeni başvuru için beklemen gerekiyor.")}</p>
   <div class="kv"><span>Başvuru açılış zamanı</span><b>${tarihSaat(d.soguma_bit)}</b></div></div>`;
 const deger=Math.round(Number(d.deger_onerilen)||Number(d.deger_en_az));
 const minPay=Number(d.min_pay)||0,hedefPay=Math.max(minPay+2,20);
 const varsayilan=Math.max(k.en_az_buyukluk,Math.round(deger*hedefPay/(100-hedefPay)/1000)*1000);
 return `<div class="kart"><h2>İzahname ve SPK başvurusu</h2>
  <p class="alt">Başvurunu SPK ${k.spk_saat} saat inceler, ardından talep toplama başlar. Süreç boyunca bu şirketin paylarını satamazsın.</p>
  <h3 style="margin-top:12px">1. Fiyat tespit raporu</h3>
  <div class="alan"><label for="ha_deger">Halka arz öncesi şirket değeri (₺)</label><input id="ha_deger" type="number" inputmode="numeric" min="${d.deger_en_az}" max="${d.deger_en_cok}" step="1000" value="${deger}" oninput="haHesapCiz()">
   <p class="kucuk">Rapora göre ${haTL(d.deger_en_az)} – ${haTL(d.deger_en_cok)} arası. Önerilen ${haTL(d.deger_onerilen)} (yaklaşık 26 haftalık kâr). Değer yükseldikçe aynı para için daha az pay satarsın, yatırımcı ilgisi düşebilir.</p></div>
  <h3>2. Satış yöntemi</h3>
  <div class="alan"><label for="ha_tutar">Sermaye artırımı: yeni pay satışı (₺)</label><input id="ha_tutar" type="number" inputmode="numeric" min="0" step="1000" value="${varsayilan}" oninput="haHesapCiz()">
   <p class="kucuk">Para şirketin kasasına ve sermayesine girer.</p></div>
  <div class="alan"><label for="ha_ortak">Ortak satışı: kendi payından satış (₺)</label><input id="ha_ortak" type="number" inputmode="numeric" min="0" step="1000" value="0" oninput="haHesapCiz()">
   <p class="kucuk">Para senin cüzdanına gelir; şirkete girmez. En fazla payının karşılığı kadar.</p></div>
  <h3>3. Talep toplama</h3>
  <div class="alan"><label for="ha_asgari">Asgari başarı tutarı</label><select id="ha_asgari" onchange="haHesapCiz()"><option value=".25">Büyüklüğün %25'i</option><option value=".5" selected>Büyüklüğün %50'si</option><option value=".75">Büyüklüğün %75'i</option><option value="1">Büyüklüğün tamamı</option></select></div>
  <div class="alan"><label for="ha_saat">Talep toplama süresi</label><select id="ha_saat"><option value="24">24 saat</option><option value="48">48 saat</option><option value="72" selected>72 saat</option></select></div>
  <div class="alan"><label for="ha_fon">Fon kullanım yeri (izahnamede görünür)</label><textarea id="ha_fon" class="alanmetin" maxlength="200" rows="2" style="min-height:70px" placeholder="Örn. İzmir'de yeni şube ve kapasite artışı"></textarea></div>
  <div id="ha_sonuc" aria-live="polite"></div>
  <button class="btn altin" id="ha_baslat" onclick="halkaArzBaslat(${Number(d.id)})">SPK'ya başvur</button>
 </div>`;
}

async function haKarTercihDegistir(id,kasada){
 try{
  await API.rpc("sirket_kar_birikim_ayarla",{p_sirket:id,p_kasada:kasada});
  toast(kasada?"Gelecek kâr payın şirket kasasında kalacak.":"Gelecek kâr payın cüzdanına aktarılacak.");
  halkaArzEkrani(id);
 }catch(err){toast(hataCevir(err.message),true)}
}

function haBasvuruHesap(){
 const d=_ha;if(!d)return null;const k=haKural(d);
 const sayi=id=>Math.max(0,Math.round(Number((document.getElementById(id)||{}).value)||0));
 let deger=sayi("ha_deger")||Math.round(Number(d.deger_onerilen));
 const degerUyari=deger<Number(d.deger_en_az)||deger>Number(d.deger_en_cok);
 deger=Math.min(Number(d.deger_en_cok),Math.max(Number(d.deger_en_az),deger));
 const yeni=sayi("ha_tutar"),ortak=sayi("ha_ortak"),hedef=yeni+ortak,post=deger+yeni;
 const oran=post?hedef/post*100:0,ortakSiniri=Math.floor(Number(d.payim)*deger/100);
 const masrafYeni=Math.round(yeni*k.masraf_toplam/100),masrafOrtak=Math.round(ortak*k.masraf_toplam/100);
 const asgari=Math.round(hedef*Number((document.getElementById("ha_asgari")||{}).value||.5));
 const benimSonra=post?(Number(d.payim)*deger/100-ortak)/post*100:0;
 let sinir="";
 if(hedef<k.en_az_buyukluk)sinir=`Halka arz büyüklüğü (sermaye artırımı + ortak satışı) en az ${haTL(k.en_az_buyukluk)} olmalı.`;
 else if(Number(d.sermaye)+yeni>1e8)sinir="Halka arz sonrası sermaye 100.000.000 ₺'yi aşamaz.";
 else if(ortak>ortakSiniri)sinir=`Ortak satışında en fazla ${haTL(ortakSiniri)} satabilirsin.`;
 else if(oran>k.en_cok_pay)sinir=`En fazla %${k.en_cok_pay} satılabilir; bu yapıyla ${haYuzde(oran)} satılıyor.`;
 else if(Number(d.min_pay)>0&&oran<Number(d.min_pay))sinir=`İlk halka arzda asgari halka açıklık %${d.min_pay}; bu yapıyla ${haYuzde(oran)} satılıyor.`;
 else if(asgari<10000)sinir="Asgari başarı tutarı en az 10.000 ₺ olmalı; büyüklüğü artır ya da daha yüksek asgari seç.";
 return {d,k,deger,degerUyari,yeni,ortak,hedef,post,oran,masrafYeni,masrafOrtak,asgari,benimSonra,sinir};
}

async function haHesapCiz(){
 const el=document.getElementById("ha_sonuc");const h=haBasvuruHesap();if(!el||!h)return;
 const {d,k}=h;
 const b=document.getElementById("ha_baslat");if(b)b.disabled=!!h.sinir;
 const ust=`<div class="kart" style="background:var(--panel2)">
  <div class="kv"><span>Halka arz büyüklüğü</span><b>${haTL(h.hedef)}</b></div>
  <div class="kv"><span>Satılacak pay</span><b>${haYuzde(h.oran)}${Number(d.min_pay)>0?` <span class="kucuk">(asgari %${d.min_pay}, azami %${k.en_cok_pay})</span>`:""}</b></div>
  <div class="kv"><span>Halka arz fiyatı (%1 pay)</span><b>${haTL(h.post/100)}</b></div>
  <div class="kv"><span>Arz sonrası şirket değeri</span><b>${haTL(h.post)}</b></div>
  <div class="kv"><span>Senin payın</span><b>${haYuzde(d.payim)} → ${haYuzde(h.benimSonra)}</b></div>
  <div class="kv"><span>Asgari başarı tutarı</span><b>${haTL(h.asgari)}</b></div>
  <div class="kv"><span>Masraflar (%${String(k.masraf_toplam).replace(".",",")})</span><b>${haTL(h.masrafYeni+h.masrafOrtak)}</b></div>
  <p class="kucuk">SPK kurul ücreti %${String(k.spk_ucret).replace(".",",")} ve Borsa İstanbul kotasyon ücreti %${String(k.borsa_ucret).replace(".",",")} hazineye gider; aracı kurum komisyonu %${String(k.araci_komisyon).replace(".",",")}. Masraflar yalnız arz gerçekleşirse kesilir.</p>
  ${h.yeni?`<div class="kv"><span>Şirkete net giriş (hepsi satılırsa)</span><b style="color:var(--good)">${haTL(h.yeni-h.masrafYeni)}</b></div>`:""}
  ${h.ortak?`<div class="kv"><span>Cüzdanına net giriş (hepsi satılırsa)</span><b style="color:var(--good)">${haTL(h.ortak-h.masrafOrtak)}</b></div>`:""}
  <div id="ha_kar"></div>
  ${h.degerUyari?`<p class="kucuk" style="color:var(--acc2)">Şirket değeri rapordaki aralığa (${haTL(d.deger_en_az)} – ${haTL(d.deger_en_cok)}) çekilerek hesaplandı.</p>`:""}
  ${h.sinir?`<p class="kucuk" style="color:var(--acc2)">${e(h.sinir)}</p>`:""}
  <p class="kucuk">Talep az gelirse satılan tutar asgari ile büyüklük arasında kalabilir; çok gelirse eşit dağıtım yapılır.</p></div>`;
 el.innerHTML=ust;
 const istek=++_haIstek;clearTimeout(_haZaman);
 _haZaman=setTimeout(async()=>{
  try{
   const r=await API.rpc("halka_arz_hesapla",{p_sirket:d.id,p_tutar:h.yeni,p_deger:h.deger});
   if(istek!==_haIstek||_ha!==d)return;const kar=document.getElementById("ha_kar");if(!kar)return;
   const once=Number(r.ort_net_simdi),sonra=Number(r.ort_net_sonra),renk=x=>x<0?"var(--acc2)":"var(--good)";
   kar.innerHTML=`<div class="kv"><span>Haftalık net kâr tahmini</span><b><span style="color:${renk(once)}">${haTL(once)}</span> → <span style="color:${renk(sonra)}">${haTL(sonra)}</span></b></div>
    <div class="kv"><span>Yatırımcılara düşen haftalık (tahmini)</span><b>${haTL(Math.max(0,sonra)*h.oran/100)}</b></div>`;
  }catch(_){}
 },350);
}

async function halkaArzBaslat(id){
 const h=haBasvuruHesap();if(!h)return;
 if(h.sinir){toast(h.sinir,true);return;}
 const saat=Number(document.getElementById("ha_saat").value),fon=(document.getElementById("ha_fon").value||"").trim();
 if(!confirm(`SPK'ya halka arz başvurusu yapılsın mı?\n\nBüyüklük: ${haTL(h.hedef)} (sermaye artırımı ${haTL(h.yeni)}${h.ortak?`, ortak satışı ${haTL(h.ortak)}`:""})\nŞirket değeri: ${haTL(h.deger)}\nSatılacak pay: ${haYuzde(h.oran)}\nAsgari: ${haTL(h.asgari)} · Talep toplama: ${saat} saat\n\nSPK incelemesi ${h.k.spk_saat} saat sürer. Süreç boyunca paylarını satamazsın.`))return;
 const btn=document.getElementById("ha_baslat");if(btn)btn.disabled=true;
 try{
  await API.rpc("halka_arz_basvur",{p_sirket:id,p_hedef:h.hedef,p_deger:h.deger,p_asgari:h.asgari,p_saat:saat,p_ortak_satis:h.ortak,p_fon_kullanim:fon||null});
  toast("Başvurun SPK'ya ulaştı; izahname inceleniyor.");halkaArzEkrani(id);
 }catch(err){toast(hataCevir(err.message),true);if(btn)btn.disabled=false;}
}

async function halkaArzIptal(arz,sirket){
 if(!confirm("Halka arz iptal edilsin mi?\nToplanan bütün talepler yatırımcılara iade edilir. Yeni başvuru için 24 saat beklemen gerekir."))return;
 try{await API.rpc("halka_arz_iptal",{p_arz:arz});toast("Halka arz iptal edildi; talepler iade edildi.");sirket?halkaArzEkrani(sirket):halkaArzPazarEkrani()}
 catch(err){toast(hataCevir(err.message),true)}
}

function haAcikKart(a,sirketEkrani){
 const spk=a.asama==="spk",talepBitti=new Date(a.bit)<=new Date();
 const kalanHak=Math.max(0,Number(a.hedef)-Number(a.talebim||0));
 const ortaklar=(a.ortaklar||[]).slice(0,5);
 return `<div class="kart"><h2>${sirketEkrani?"Süren halka arz":e(a.sirket)}</h2>
  <p class="alt"><span class="rozet ${spk?"":"yesil"}">${haAsamaAd(a)}</span> ${e(HA_SEKTOR[a.sektor]||a.sektor||"")} · başvuran ${e(a.baslatan||"")}</p>
  ${spk?`<p class="kucuk">İzahname SPK incelemesinde. Talep toplama ${a.spk_bit?tarihSaat(a.spk_bit):"yakında"} tarihinde başlayacak${a.spk_bit?" ("+haKalan(a.spk_bit)+")":""}.</p>`
       :`<p class="kucuk">Talep toplama ${tarihSaat(a.bit)} tarihinde bitiyor · ${haKalan(a.bit)}</p>${haCubuk(a)}`}
  <div class="kv"><span>Halka arz büyüklüğü</span><b>${haTL(a.hedef)}</b></div>
  <div class="kv"><span>Yöntem</span><b style="max-width:62%;text-align:right">${Number(a.ortak_satis)>0?`Sermaye artırımı ${haTL(a.yeni_pay_tutari)} + ortak satışı ${haTL(a.ortak_satis)}`:"Sermaye artırımı"}</b></div>
  <div class="kv"><span>Şirket değeri (arz öncesi)</span><b>${haTL(a.deger)}</b></div>
  <div class="kv"><span>Halka arz fiyatı (%1 pay)</span><b>${haTL(a.arz_fiyati||a.pay_fiyati_1)}</b></div>
  <div class="kv"><span>Satılacak pay</span><b>${haYuzde(a.satilan_pay_hedef)}</b></div>
  <div class="kv"><span>Asgari tutar</span><b>${haTL(a.asgari)}</b></div>
  <div class="kv"><span>Haftalık net kâr tahmini</span><b>${a.ort_net_simdi==null?"—":haTL(a.ort_net_simdi)+" → "+haTL(a.ort_net_hedef)}</b></div>
  ${a.fon_kullanim?`<div class="kv"><span>Fon kullanım yeri</span><b style="max-width:60%;text-align:right">${e(a.fon_kullanim)}</b></div>`:""}
  ${ortaklar.length?`<details style="margin-top:8px"><summary class="kucuk">İzahname · ortaklık yapısı</summary>${ortaklar.map(o=>`<div class="kv"><span>${e(o.kad)}</span><b>${haYuzde(o.pay)}</b></div>`).join("")}</details>`:""}
  ${Number(a.talebim)>0?`<div class="kv"><span>Talebin</span><b>${haTL(a.talebim)}</b></div>
   <div class="kv"><span>Şu anki taleplere göre tahmini tahsisin</span><b>${haTL(a.tahmini_tahsisim)}</b></div>`:""}
  ${a.ben_baslattim?`<button class="btn ikinci" onclick="halkaArzIptal(${Number(a.id)},${sirketEkrani?Number(a.sirket_id):0})">Halka arzı iptal et</button>`
   :spk||talepBitti?"":`<div class="alan"><label for="ha_talep_${a.id}">${Number(a.talebim)>0?"Ekleyeceğin tutar":"Talep tutarı"} (₺, en az 1.000 · en fazla ${haTL(kalanHak)})</label><input id="ha_talep_${a.id}" type="number" inputmode="numeric" min="1000" step="1000" max="${kalanHak}" value="${Math.max(0,Math.min(kalanHak,10000))}" oninput="haTalepOnizle(${Number(a.id)})"><p class="kucuk" id="ha_talep_ozet_${a.id}"></p></div>
   <button class="btn altin" id="ha_talep_btn_${a.id}" onclick="halkaArzTalep(${Number(a.id)},${sirketEkrani?Number(a.sirket_id):0})" ${kalanHak<1000?"disabled":""}>${Number(a.talebim)>0?"Talebimi artır":"Talep ver"}</button>
   ${Number(a.talebim)>0?`<button class="btn ikinci" onclick="halkaArzTalepGeri(${Number(a.id)},${sirketEkrani?Number(a.sirket_id):0})">Talebimi geri al</button>`:""}`}
 </div>`;
}
function haArzBul(id){return _ha&&_ha.acik&&_ha.acik.id===id?_ha.acik:_haListe.find(x=>x.id===id)}
function haTalepOnizle(id){
 const a=haArzBul(id),el=document.getElementById("ha_talep_ozet_"+id),inp=document.getElementById("ha_talep_"+id);if(!a||!el||!inp)return;
 const t=Math.max(0,Number(inp.value)||0),once=Number(a.talebim)||0,toplam=once+t,post=Number(a.deger)+Number(a.yeni_pay_tutari||a.hedef);
 const fazla=Number(a.toplanan)+t>Number(a.hedef);
 el.textContent=`${once>0?`Mevcut ${haTL(once)} + ek ${haTL(t)} = toplam ${haTL(toplam)}. `:""}Talebin tamamen karşılanırsa yaklaşık ${haYuzde(toplam/post*100)} ortak olursun.${fazla?" Toplam talep büyüklüğü aşıyor: sonunda eşit dağıtım yapılır, karşılanmayan kısım iade edilir.":""} Para talep toplama bitene kadar emanette kalır.`;
}
async function halkaArzTalep(arz,sirket){
 const a=haArzBul(arz),inp=document.getElementById("ha_talep_"+arz),btn=document.getElementById("ha_talep_btn_"+arz);
 const t=Number(inp&&inp.value),once=Number(a&&a.talebim)||0,kalanHak=a?Number(a.hedef)-once:0;
 if(!Number.isSafeInteger(t)||t<1000||t>kalanHak){toast(`Ek talep en az 1.000 ₺ olmalı; toplam talebin halka arz büyüklüğünü (${haTL(a?a.hedef:0)}) aşamaz.`,true);return;}
 if(!confirm((once>0?`${haTL(t)} ek talep eklensin mi?\nYeni toplam talebin: ${haTL(once+t)}`:`${haTL(t)} tutarında talep verilsin mi?`)+"\n\nPara talep toplama bitene kadar emanette kalır. Fazla talep gelirse eşit dağıtım yapılır ve artan para iade edilir; arz gerçekleşmezse tamamı iade edilir."))return;
 if(btn)btn.disabled=true;
 try{const r=await API.rpc("halka_arz_talep",{p_arz:arz,p_tutar:t});toast(`Talebin alındı. Toplam talebin: ${haTL(r.talebim)}.`);await (sirket?halkaArzEkrani(sirket):halkaArzPazarEkrani())}
 catch(err){toast(hataCevir(err.message),true)}
 finally{if(btn&&document.getElementById("ha_talep_"+arz)===inp)btn.disabled=false;}
}
async function halkaArzTalepGeri(arz,sirket){
 if(!confirm("Talebin geri alınsın mı? Para cüzdanına döner."))return;
 try{await API.rpc("halka_arz_talep_geri",{p_arz:arz});toast("Talebin geri alındı.");sirket?halkaArzEkrani(sirket):halkaArzPazarEkrani()}
 catch(err){toast(hataCevir(err.message),true)}
}

async function halkaArzPazarEkrani(){
 yukleniyor("Halka arzlar");
 try{
  const d=await API.rpc("halka_arz_liste");_ha=null;_haListe=d.acik||[];
  const k=haKural(d),talepte=_haListe.filter(a=>a.asama!=="spk"),spkda=_haListe.filter(a=>a.asama==="spk");
  const katildim=d.katildiklarim||[];
  iskelet("Halka arzlar",`
  <div class="kart"><h2>Halka arzlar</h2>
   <p class="alt">Oyuncu şirketlerinin halka arzlarına talep ver, ortak ol ve kârdan payını al. Cüzdanın: ${haTL(d.cuzdan)}.</p>
   <details><summary class="kucuk">Halka arz nasıl işler?</summary>
    <p class="kucuk">1) Şirket SPK'ya izahnameyle başvurur; SPK ${k.spk_saat} saat inceler. 2) Onaydan sonra talep toplama başlar (24–72 saat); süre sonuna kadar talebini artırabilir ya da geri alabilirsin. 3) Toplam talep büyüklüğü aşarsa tüm yatırımcılara eşit dağıtım yapılır, karşılanmayan paran iade edilir. 4) Asgari tutara ulaşılmazsa herkese iade edilir. 5) Arz tamamlanınca şirket borsada işlem görür; arzı yapan ve büyük eski ortaklar ${k.kilit_gun} gün pay satamaz (satmama taahhüdü).</p>
   </details>
   <button class="btn ikinci" onclick="sirketYonetimEkrani()">Şirketlerim</button></div>
  ${talepte.length?`<h2 class="bolum-bas" style="margin:16px 4px 8px">Talep toplayanlar</h2>${talepte.map(a=>haAcikKart(a,false)).join("")}`:'<div class="kart"><p class="alt">Şu anda talep toplayan halka arz yok.</p></div>'}
  ${spkda.length?`<h2 class="bolum-bas" style="margin:16px 4px 8px">SPK incelemesindekiler</h2>${spkda.map(a=>haAcikKart(a,false)).join("")}`:""}
  ${katildim.length?`<div class="kart"><h2>Katıldığım halka arzlar</h2>${katildim.map(g=>`<div class="kv"><span>${e(g.sirket)} · ${haDurumAd(g.durum)}</span><b>${g.durum==="tamam"?haTL(g.tahsisim)+" tahsis":haTL(g.iadem)+" iade"}</b></div>
    <p class="kucuk">${tarihSaat(g.sonuc_zaman)} · talebin ${haTL(g.talebim||(Number(g.tahsisim||0)+Number(g.iadem||0)))}${g.durum==="tamam"?` · ${haYuzde(g.arz_payim)} pay${Number(g.iadem)>0?` · ${haTL(g.iadem)} iade`:""}`:""}</p>`).join("")}</div>`:""}
  ${(d.son||[]).length?`<div class="kart"><h2>Son sonuçlananlar</h2>${d.son.map(g=>`<div class="kv"><span>${e(g.sirket)} · ${haDurumAd(g.durum)}</span><b>${haTL(g.satilan!=null?g.satilan:g.toplanan)}</b></div><p class="kucuk">${tarihSaat(g.sonuc_zaman)} · ${e(g.aciklama||"")}</p>`).join("")}</div>`:""}
  `,{geri:true});
  _haListe.forEach(a=>{if(!a.ben_baslattim&&a.asama!=="spk")haTalepOnizle(a.id)});
 }catch(err){iskelet("Halka arzlar",`<div class="bos">${e(hataCevir(err.message))}</div>`,{geri:true})}
}
