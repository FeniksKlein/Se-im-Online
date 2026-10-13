const BEL_RUHSAT_TURLER = [["kur_fabrika","Fabrika kuruluşu"],["kur_magaza","Market / mağaza kuruluşu"],["kur_insaat","Müteahhitlik şirketi"],["kur_sigorta","Sigorta şirketi"],["kur_pazar","Okul / hastane / market / enerji şirketi"],["kur_sirket","Genel şirket kuruluşu"],["arsa_insaat","Arsa üzerinde inşaat"],["yeni_proje","Yeni konut projesi"],["sube","Mağaza şubesi açılışı"]];
function belTurAdi(tur) { return (BEL_RUHSAT_TURLER.find(v=>v[0]===tur)||[])[1]||tur; }

async function belRuhsatMerkeziEkrani(){
 yukleniyor("Yatırım Ruhsat Merkezi");
 let r,ek,pk;
 try{
  [r,ek,pk]=await Promise.all([
   API.rpc("bel_ruhsat_merkezi"),
   API.rpc("eko_panel").catch(()=>({benim:[]})),
   API.rpc("pazar_katalog").catch(()=>({sektorler:[],benim_il:1}))
  ]);
 }catch(err){iskelet("Yatırım Ruhsat Merkezi",`<div class="kart">${e(hataCevir(err.message))}</div>`,{geri:true});return;}
 window.BEL_RUHSAT_KAYNAK={r,ek,pk};
 const mali=r.mali;
 const ilSec=(r.iller||[]).map(i=>`<option value="${i.id}" ${i.id===(r.baskan_il||pk.benim_il)?"selected":""}>${e(i.ad)}</option>`).join("");
 const kart=`<div class="kart"><h2>🏛️ Belediye Yatırım Ruhsatları</h2><p class="alt">Fabrika, market, şirket, inşaat ve şube açılışlarında belediyeye başvur. Belediye başkanı onaylamadan yatırım başlayamaz. Onaylanan ruhsat 72 saat geçerlidir; gerçek harç, yatırım sırasında şirket kasasından belediye kasasına ödenir.</p>
 <div class="kv"><span class="k">Başvurularım</span><span class="v">${(r.benim||[]).length}</span></div></div>
 <div class="kart"><h3>Yeni yatırım başvurusu</h3>
  <div class="alan"><label>Yatırım türü</label><select id="blrTur" onchange="belRuhsatAlanDegisti()">${BEL_RUHSAT_TURLER.map(([k,a])=>`<option value="${k}">${e(a)}</option>`).join("")}</select></div>
  <div class="alan"><label>Yatırım yapılacak il</label><select id="blrIl" onchange="belRuhsatAlanDegisti()">${ilSec}</select></div>
  <div class="alan" id="blrSirketKutu" style="display:none"><label>Yatırımı yapan şirket (mevcut şirketin etkinleştirilmesi için seçilebilir)</label><select id="blrSirket" onchange="belRuhsatAlanDegisti()"></select></div>
  <div class="alan" id="blrAdKutu"><label>Kurulacak şirketin tam adı</label><input id="blrAd" maxlength="50" placeholder="Yatırımı yapacak şirketin adı"></div>
  <div class="alan" id="blrSektorKutu" style="display:none"><label>Şirket sektörü</label><select id="blrSektor">${(pk.sektorler||[]).map(x=>`<option value="${e(x.kod)}">${e(x.ad)}</option>`).join("")}</select></div>
  <div class="alan" id="blrHedefKutu" style="display:none"><label>Arsa / kiralanacak dükkân</label><select id="blrHedef"></select></div>
  <div class="alan"><label>Tahmini yatırım tutarı (TL)</label><input type="number" id="blrTutar" min="0" max="1000000000" step="1000" value="100000" inputmode="decimal"><small class="kucuk">Bilgi amaçlıdır; kesin harç gerçek işlem tutarına göre hesaplanır.</small></div>
  <button class="btn altin" onclick="belRuhsatBasvur()">Başvuruyu belediye başkanına gönder</button></div>
 <div class="kart"><h3>Başvuru geçmişim</h3>${(r.benim||[]).map(x=>`<div style="padding:10px 0;border-bottom:1px solid var(--line)">
 <b>#${x.id} · ${e(belTurAdi(x.tur))}</b> <span class="rozet ${x.durum==="onay"||x.durum==="kullanildi"?"yesil":x.durum==="red"?"kirmizi":"altin"}">${x.durum==="onay"?"Onaylandı":x.durum==="bekliyor"?"Başkan kararı bekleniyor":x.durum==="kullanildi"?"Kullanıldı":"Reddedildi"}</span>
 <div class="kucuk">${e((r.iller||[]).find(i=>i.id===x.il_id)?.ad||"")} · ${e(x.sirket||"")} ${x.hedef?"· Hedef #"+x.hedef:""} · ${tarihSaat(x.tarih)}</div>
 ${x.durum==="onay"?`<p class="kucuk">Onaylı tarife %${fmt(x.oran,2)} · taban ${fmt(x.taban)} TL. 72 saat içinde yatırım ekranından aynı işlemi gerçekleştir.</p>`:""}
 ${x.odenmis!=null?`<div class="kucuk">Ödenen belediye harcı: ${fmt(x.odenmis)} TL</div>`:""}
 ${x.gerekce?`<p class="kucuk">Başkan notu: ${e(x.gerekce)}</p>`:""}
 </div>`).join("")||'<p class="alt">Henüz yatırım ruhsatı başvurusu yapmadın.</p>'}</div>`;
 let baskan="";
 if(r.baskan_il){
 baskan=`<div class="kart"><h2>Başkanın ruhsat masası</h2><p class="alt">${(r.iller||[]).find(x=>x.id===r.baskan_il)?.ad||""} belediyesindeki her yatırım manuel onayına tabidir. Reddedilen başvuru ücret ödemez.</p>
 ${(r.bekleyen||[]).map(x=>`<div style="padding:12px 0;border-bottom:1px solid var(--line)">
 <b>#${x.id} · ${e(belTurAdi(x.tur))}</b><p class="kucuk">${e(x.oyuncu)} · ${e(x.sirket||"")} ${x.hedef?"· Hedef "+x.hedef:""}<br>Yatırım: ${fmt(x.yatirim)} TL · Tahmini harç: ${fmt(x.harc_tahmini)} TL</p>
 <button class="btn altin" onclick="belRuhsatKarar(${x.id},true)">Onay ver</button>
 <button class="btn ikinci" onclick="belRuhsatKarar(${x.id},false)">Gerekçeli reddet</button></div>`).join("")||'<p class="alt">Bekleyen yatırım başvurusu yok.</p>'}</div>
 <div class="kart"><h2>Harç tarifelerini yönet</h2><p class="kucuk">Oran %0–8, sabit taban 0–500.000 TL. Her tarife 24 saatte bir değiştirilebilir; onaylanmış ruhsatların oranı sonradan değişmez.</p>
 ${(r.tarifeler||[]).map((x,i)=>`<div style="padding:10px 0;border-bottom:1px solid var(--line)">
  <b>${e(belTurAdi(x.tur))}</b>
  <div class="alan"><label>Yatırım üzerinden %</label><input type="number" id="blrOran${i}" min="0" max="8" step="0.01" value="${x.oran}"></div>
  <div class="alan"><label>Asgari sabit harç (TL)</label><input type="number" id="blrTaban${i}" min="0" max="500000" step="1" value="${x.taban_tl}"></div>
  <button class="btn ikinci" onclick="belRuhsatTarife('${x.tur}',${i})">Tarifeyi kaydet</button></div>`).join("")}</div>
 ${mali?`<div class="kart"><h2>Belediye mali denetimi</h2><p class="alt">Yüksek giderler, bütçe açığı ve düşük nakit rezervi şehir ekonomisine zarar verir. Her gün mali denetim yapılır; tekrarlanan dengesizlik memnuniyeti ve gelişmişliği azaltır.</p>
  <div class="kv"><span class="k">Nakit / belediye kasası</span><b>${kasaYaz(mali.kasa)}</b></div>
  <div class="kv"><span class="k">Günlük düzenli gelir</span><b class="iyi">${kasaYaz(mali.gunluk_gelir)}</b></div>
  <div class="kv"><span class="k">Günlük düzenli gider</span><b class="kotu">${kasaYaz(mali.gunluk_gider)}</b></div>
  <div class="kv"><span class="k">Günlük net denge</span><b class="${mali.gunluk_net<0?"kotu":"iyi"}">${kasaYaz(mali.gunluk_net)}</b></div>
  <div class="kv"><span class="k">İller Bankası borcu</span><b>${kasaYaz(mali.borc)}</b></div>
  <div class="kv"><span class="k">Son 7 gün ek gelir / harcama</span><b>${kasaYaz(mali.son7_gelir)} / ${kasaYaz(mali.son7_gider)}</b></div>
  <div class="kv"><span class="k">Risk seviyesi</span><b>${e(mali.risk)}</b></div>
  ${(mali.gunlukler||[]).map(z=>`<div class="kv"><span class="k">${e(z.gun)} · bütçe açığı</span><span class="v">${kasaYaz(z.acik)} ${z.memnuniyet_kaybi?"· Memnuniyet −"+fmt(z.memnuniyet_kaybi,2):""}</span></div>`).join("")}</div>`:""}`;
 }
 iskelet("Yatırım Ruhsat Merkezi",kart+baskan,{geri:true});
 await belRuhsatAlanDegisti();
}

async function belRuhsatAlanDegisti(){
 const $tur=$("#blrTur"),$il=$("#blrIl"),$cs=$("#blrSirket"),$hedef=$("#blrHedef");
 if(!$tur||!$il||!window.BEL_RUHSAT_KAYNAK)return;
 const tur=$tur.value,il=Number($il.value),isim=tur.startsWith("kur_"),pazar=tur==="kur_pazar"||tur==="kur_sirket",hedefli=tur==="arsa_insaat"||tur==="sube";
 const gelen=(window.BEL_RUHSAT_KAYNAK.ek?.benim||[]).filter(s=>{
  if(tur==="arsa_insaat"||tur==="yeni_proje"||tur==="kur_insaat")return s.tur==="insaat"||s.sektor==="insaat";
  if(tur==="sube"||tur==="kur_magaza")return s.tur==="magaza"||s.sektor==="ticaret";
  if(tur==="kur_fabrika")return ["sanayi","tarim","teknoloji"].includes(s.sektor);
  if(tur==="kur_sigorta")return s.sektor==="ticaret";
  return true;
 });
 const eski=$cs?.value;
 const secenekler=(isim&&!pazar?'<option value="">Yeni şirket kurulacak</option>':"")+
 gelen.map(s=>`<option value="${s.id}">${e(s.ad)} (#${s.id})</option>`).join("");
 if($cs){$cs.innerHTML=secenekler;if(gelen.some(s=>String(s.id)===eski))$cs.value=eski;}
 const sid=Number($cs?.value||0);
 const kutu=$("#blrSirketKutu"),ad=$("#blrAdKutu"),sektor=$("#blrSektorKutu"),ht=$("#blrHedefKutu");
 if(kutu)kutu.style.display=pazar?"none":gelen.length||!isim?"block":"none";
 if(ad)ad.style.display=isim&&(!sid||pazar)?"block":"none";
 if(sektor)sektor.style.display=pazar?"block":"none";
 const sec=$("#blrSektor");
 if(sec){
  const onceki=sec.value;
  const secenek=tur==="kur_sirket"
   ?[["tarim","Tarım"],["sanayi","Sanayi"],["teknoloji","Teknoloji"],["ticaret","Ticaret"],["insaat","İnşaat"],["medya","Medya"],["ajans","Reklam ve anket ajansı"]]
   :(window.BEL_RUHSAT_KAYNAK.pk?.sektorler||[]).map(x=>[x.kod,x.ad]);
  sec.innerHTML=secenek.map(([kod,ad])=>`<option value="${e(kod)}">${e(ad)}</option>`).join("");
  if(secenek.some(x=>x[0]===onceki))sec.value=onceki;
 }
 if(ht)ht.style.display=hedefli?"block":"none";
 if(!hedefli||!$hedef)return;
 const reqId=window.BEL_RUHSAT_SIRA=(window.BEL_RUHSAT_SIRA||0)+1;
 $hedef.innerHTML='<option value="">Yükleniyor…</option>';
 try{
  const x=await API.rpc("eko_emlak_panel",{p_il:il});
  if(reqId!==window.BEL_RUHSAT_SIRA)return;
  const liste=tur==="arsa_insaat"
   ?(x.benim_arsalarim||[]).filter(a=>a.il===il&&a.sirket===sid).map(a=>({id:a.id,ad:`Arsa #${a.id} · ${a.kapasite} bağımsız bölüm`}))
   :(x.kiralik||[]).map(a=>({id:a.id,ad:`Dükkân #${a.id} · ${e(a.yapi)} · ${fmt(a.kira)} TL/hafta`}));
  $hedef.innerHTML=liste.map(z=>`<option value="${z.id}">${e(z.ad)}</option>`).join("")||'<option value="">Uygun arsa / dükkân bulunamadı</option>';
 }catch(_){$hedef.innerHTML='<option value="">Bilgi alınamadı</option>';}
}

async function belRuhsatBasvur(){
 const tur=$("#blrTur")?.value, il=Number($("#blrIl")?.value),sirket=Number($("#blrSirket")?.value||0)||null;
 const yeni=tur?.startsWith("kur_")&&(!sirket||tur==="kur_pazar");
 const ad=yeni?$("#blrAd")?.value?.trim():null, sektor=["kur_pazar","kur_sirket"].includes(tur)?$("#blrSektor")?.value:null;
 const hedef=["arsa_insaat","sube"].includes(tur)?Number($("#blrHedef")?.value||0)||null:null;
 const yatirim=Number($("#blrTutar")?.value);
 if(yeni&&(!ad||ad.length<3)){toast("Kurulacak şirketin adını yaz.",true);return;}
 if(["arsa_insaat","sube"].includes(tur)&&!hedef){toast("İşleme ait arsayı veya dükkânı seç.",true);return;}
 if(!Number.isFinite(yatirim)||yatirim<0||yatirim>1e9){toast("Geçerli yatırım tutarı gir.",true);return;}
 try{
  const res=await API.rpc("bel_ruhsat_basvur",{p_tur:tur,p_il:il,p_sirket:sirket,p_hedef:hedef,p_ad:ad,p_sektor:sektor,p_yatirim:yatirim});
  toast("Başvuru #"+res.id+" belediyeye gönderildi. Tahmini harç: "+fmt(res.tahmini_harc)+" TL");
  belRuhsatMerkeziEkrani();
 }catch(err){toast(hataCevir(err.message),true);}
}

async function belRuhsatKarar(id,onay){
 let gerekce=null;
 if(!onay){
  gerekce=prompt("Red gerekçesini yaz (en az 5 karakter):","");
  if(gerekce===null)return;
  if(gerekce.trim().length<5){toast("En az 5 karakterlik gerekçe yaz.",true);return;}
 }else if(!await onayla("Ruhsat onayı","Bu yatırım için 72 saat geçerli belediye ruhsatı verilecek. Harç, yatırım yapıldığında şirket kasasından tahsil edilecek.","Onayla"))return;
 try{await API.rpc("bel_ruhsat_karar",{p_id:id,p_onay:onay,p_gerekce:gerekce});toast(onay?"Yatırım ruhsatı onaylandı.":"Başvuru gerekçeli reddedildi.");belRuhsatMerkeziEkrani();}
 catch(err){toast(hataCevir(err.message),true);}
}

async function belRuhsatTarife(tur,sira){
 const oran=Number($("#blrOran"+sira)?.value),taban=Number($("#blrTaban"+sira)?.value);
 if(!Number.isFinite(oran)||oran<0||oran>8||!Number.isInteger(taban)||taban<0||taban>500000){toast("Oran %0–8 ve sabit tutar 0–500.000 TL olmalı.",true);return;}
 if(!await onayla("Harç tarifesi",`${e(belTurAdi(tur))} için %${fmt(oran,2)} ve ${fmt(taban)} TL asgari harç belirlemek istiyor musun?`,"Tarifeyi kaydet"))return;
 try{await API.rpc("bel_ruhsat_tarife_ayarla",{p_tur:tur,p_oran:oran,p_taban:taban});toast("Yeni harç tarifesi kaydedildi.");belRuhsatMerkeziEkrani();}
 catch(err){toast(hataCevir(err.message),true);}
}
