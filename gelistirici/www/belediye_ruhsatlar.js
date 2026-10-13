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
  <div class="alan"><label>Yatırım türü</label><select id="blrTur" onchange="belRuhsatTuruDegisti()">${BEL_RUHSAT_TURLER.map(([k,a])=>`<option value="${k}">${e(a)}</option>`).join("")}</select></div>
  <div class="alan"><label>Yatırım yapılacak il</label><select id="blrIl" onchange="belRuhsatAlanDegisti(true)">${ilSec}</select></div>
  <div class="alan" id="blrModKutu" style="display:none"><label>Kuruluş yöntemi</label><select id="blrMode" onchange="belRuhsatAlanDegisti(true)"><option value="yeni">➕ Yeni şirket kuracağım</option><option value="mevcut">🏢 Mevcut şirketimi faaliyete bağlayacağım</option></select><p class="alt">Yeni şirket varsayılandır. Mevcut şirket bağlama açıkça seçilmelidir.</p></div>
  <div class="alan" id="blrSirketKutu" style="display:none"><label>Bağlanacak mevcut şirket</label><select id="blrSirket" onchange="belRuhsatAlanDegisti()"></select><p class="alt">Ruhsat yalnızca seçtiğin mevcut şirket için geçerli olur.</p></div>
  <div class="alan" id="blrAdKutu"><label>Kurulacak şirketin tam adı</label><input id="blrAd" maxlength="50" placeholder="Yatırımı yapacak şirketin adı"></div>
  <div class="alan" id="blrSektorKutu" style="display:none"><label>Şirket sektörü</label><select id="blrSektor">${(pk.sektorler||[]).map(x=>`<option value="${e(x.kod)}">${e(x.ad)}</option>`).join("")}</select></div>
  <div class="alan" id="blrHedefKutu" style="display:none"><label>Arsa / kiralanacak dükkân</label><select id="blrHedef"></select></div>
  <div class="alan"><label>Tahmini yatırım tutarı (TL)</label><input type="number" id="blrTutar" min="0" max="1000000000" step="1000" value="100000" inputmode="decimal"><small class="kucuk">Bilgi amaçlıdır; kesin harç gerçek işlem tutarına göre hesaplanır.</small></div>
  <button class="btn altin" onclick="belRuhsatBasvur()">Başvuruyu belediye başkanına gönder</button></div>
 <div class="kart"><h3>Başvuru geçmişim</h3>${(r.benim||[]).map(x=>`<div style="padding:10px 0;border-bottom:1px solid var(--line)">
 <b>#${x.id} · ${e(belTurAdi(x.tur))}</b> <span class="rozet ${x.durum==="onay"||x.durum==="kullanildi"?"yesil":x.durum==="red"?"kirmizi":"altin"}">${x.durum==="onay"?"Onaylandı":x.durum==="bekliyor"?"Başkan kararı bekleniyor":x.durum==="kullanildi"?"Kullanıldı":"Reddedildi"}</span>
 <div class="kucuk">${e((r.iller||[]).find(i=>i.id===x.il_id)?.ad||"")} · ${e(x.sirket||"")} ${x.hedef?"· Hedef #"+x.hedef:""} · ${tarihSaat(x.tarih)}</div>
 ${x.durum==="onay"?`<p class="kucuk">Onaylı tarife %${fmt(x.oran,2)} · taban ${fmt(x.taban)} TL. 72 saat içinde yatırım ekranından aynı işlemi gerçekleştir.</p>`:""}
 ${x.durum==="onay"&&x.tur?.startsWith("kur_")&&!x.sirket_id&&x.sirket_adi&&
    x.karar_zamani&&Date.now()-new Date(x.karar_zamani).getTime()<72*3600000?
    `<button class="btn altin" onclick="belOnayliRuhsatlaKur(${x.id})">🏢 Bu onaylı ruhsatla şirket kur</button>`:""}
 ${["kur_sirket","kur_pazar"].includes(x.tur)&&x.sirket_id?
    `<p class="alt">⚠️ Eski sistem bu yeni şirket ruhsatını mevcut bir şirkete bağlamış. Bu ruhsatla yeni şirket kurulamaz; yanlış bağlamadan doğan eski kaydın saklanır.</p><button class="btn ikinci" onclick="belHataliRuhsatYeniBasvuru(${x.id})">Yeni şirket adına doğru ruhsat başvurusu aç</button>`:""}
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

function belRuhsatTuruDegisti(){
 const mode=$("#blrMode");
 if(mode)mode.value="yeni";
 belRuhsatAlanDegisti(true);
}
async function belRuhsatAlanDegisti(modeDegisti=false){
 const tEl=$("#blrTur"), cityEl=$("#blrIl"), selector=$("#blrSirket"), box=$("#blrSirketKutu"),
   modeBox=$("#blrModKutu"), modeEl=$("#blrMode"), nameBox=$("#blrAdKutu"), nameEl=$("#blrAd"),
   sectorBox=$("#blrSektorKutu"), targetBox=$("#blrHedefKutu"), targetEl=$("#blrHedef");
 if(!tEl||!cityEl||!window.BEL_RUHSAT_KAYNAK)return;
 const kind=tEl.value, city=Number(cityEl.value);
 const companyPermit=kind.startsWith("kur_"), service=kind==="kur_pazar"||kind==="kur_sirket";
 const flexible=["kur_fabrika","kur_magaza","kur_insaat","kur_sigorta"].includes(kind);
 const needsCompany=["arsa_insaat","yeni_proje","sube"].includes(kind);
 if(modeBox)modeBox.style.display=flexible?"":"none";
 const mode=flexible&&modeEl?.value==="mevcut"?"mevcut":"yeni";
 const existingMode=needsCompany||(flexible&&mode==="mevcut");
 if(modeDegisti&&selector)selector.value="";
 const available=(window.BEL_RUHSAT_KAYNAK.ek?.benim||[]).filter(company=>{
   if(kind==="arsa_insaat"||kind==="yeni_proje"||kind==="kur_insaat")return company.tur==="insaat"||company.sektor==="insaat";
   if(kind==="sube"||kind==="kur_magaza")return company.tur==="magaza"||company.sektor==="ticaret";
   if(kind==="kur_fabrika")return ["sanayi","tarim","teknoloji"].includes(company.sektor);
   if(kind==="kur_sigorta")return company.sektor==="ticaret";
   return true;
 });
 const previously=selector?.value||"";
 if(selector){
   selector.innerHTML='<option value="">— Şirket seç —</option>'+available.map(company=>
    '<option value="'+Number(company.id)+'">'+e(company.ad)+' (#'+Number(company.id)+')</option>').join("");
   if(!modeDegisti&&available.some(company=>String(company.id)===previously))selector.value=previously;
   else selector.value="";
   selector.disabled=!existingMode;
 }
 const companyId=existingMode?Number(selector?.value||0):0;
 if(box)box.style.display=existingMode?"":"none";
 if(nameBox)nameBox.style.display=companyPermit&&!existingMode?"":"none";
 if(nameEl)nameEl.disabled=companyPermit&&existingMode;
 if(sectorBox)sectorBox.style.display=service?"":"none";
 const sectorEl=$("#blrSektor");
 if(sectorEl){
   const old=sectorEl.value;
   const choices=kind==="kur_sirket"?
    [["tarim","Tarım"],["sanayi","Sanayi"],["teknoloji","Teknoloji"],["ticaret","Ticaret"],["insaat","İnşaat"],["medya","Medya"],["ajans","Reklam ve anket ajansı"]]:
    (window.BEL_RUHSAT_KAYNAK.pk?.sektorler||[]).map(x=>[x.kod,x.ad]);
   sectorEl.innerHTML=choices.map(([code,label])=>'<option value="'+e(code)+'">'+e(label)+'</option>').join("");
   if(choices.some(x=>x[0]===old))sectorEl.value=old;
 }
 const targeted=kind==="arsa_insaat"||kind==="sube";
 if(targetBox)targetBox.style.display=targeted?"":"none";
 if(!targeted||!targetEl)return;
 const request=window.BEL_RUHSAT_SIRA=(window.BEL_RUHSAT_SIRA||0)+1;
 if(!companyId){targetEl.innerHTML='<option value="">Önce şirket seç</option>';return;}
 targetEl.innerHTML='<option value="">Yükleniyor…</option>';
 try{
  const v=await API.rpc("eko_emlak_panel",{p_il:city});
  if(request!==window.BEL_RUHSAT_SIRA)return;
  const choices=kind==="arsa_insaat"?
   (v.benim_arsalarim||[]).filter(a=>a.il===city&&a.sirket===companyId).map(a=>({id:a.id,ad:"Arsa #"+a.id+" · "+a.kapasite+" bağımsız bölüm"})):
   (v.kiralik||[]).map(a=>({id:a.id,ad:"Dükkân #"+a.id+" · "+a.yapi+" · "+fmt(a.kira)+" TL/hafta"}));
  targetEl.innerHTML=choices.map(a=>'<option value="'+Number(a.id)+'">'+e(a.ad)+'</option>').join("")||'<option value="">Uygun arsa / dükkân bulunamadı</option>';
 }catch(err){if(request===window.BEL_RUHSAT_SIRA)targetEl.innerHTML='<option value="">Bilgi alınamadı</option>';}
}

async function belOnayliRuhsatlaKur(id){
 const info=(window.BEL_RUHSAT_KAYNAK?.r?.benim||[]).find(x=>Number(x.id)===Number(id));
 if(!info||info.durum!=="onay"||info.sirket_id||!info.sirket_adi||
   !info.karar_zamani||Date.now()-new Date(info.karar_zamani).getTime()>=72*3600000){
  toast("Kuruluş için geçerli bir onaylı ruhsat bulunamadı.",true);return;
 }
 const tur=info.tur==="kur_fabrika"?"sanayi":info.tur==="kur_magaza"?"ticaret":
   info.tur==="kur_insaat"?"insaat":info.tur==="kur_sigorta"?"sigorta":
   info.tur==="kur_pazar"?"pazar:"+info.sektor:info.tur==="kur_sirket"?info.sektor:null;
 if(!tur){toast("Bu ruhsatın bağlı olduğu şirket türü tanımlanamadı.",true);return;}
 if(typeof window.sirketTumTurKur!=="function"){
  toast("Kuruluş modülünü yüklemek için oyunu yenile.",true);return;
 }
 await window.sirketTumTurKur({tur,ad:info.sirket_adi,il:Number(info.il_id),
  sermaye:Math.max(tur==="ajans"?150000:tur==="banka"?1000000:100000,Number(info.tahmini)||100000)});
}
window.belOnayliRuhsatlaKur=belOnayliRuhsatlaKur;

async function belHataliRuhsatYeniBasvuru(id){
 const info=(window.BEL_RUHSAT_KAYNAK?.r?.benim||[]).find(x=>Number(x.id)===Number(id));
 if(!info||!["kur_sirket","kur_pazar"].includes(info.tur)||!info.sirket_id)return;
 if(!await onayla("Yanlış bağlı ruhsat",
   "Eski ruhsatın silinmeyecek veya harcı tekrar kesilmeyecek. Yeni şirketin gerçek adıyla yeni başvuru oluşturup belediye onayı alabilirsin.","Yeni başvuru aç"))return;
 const type=$("#blrTur"),city=$("#blrIl"),amount=$("#blrTutar");
 if(type)type.value=info.tur;
 if(city)city.value=String(info.il_id);
 if(amount)amount.value=String(info.tahmini||100000);
 belRuhsatTuruDegisti();
 const sector=$("#blrSektor");if(sector&&info.sektor)sector.value=info.sektor;
 const name=$("#blrAd");if(name){name.value="";name.focus();}
 toast("Yanlış bağlantılı eski ruhsat korunuyor. Yeni kurulacak şirketin adını yazarak yeni başvuru yap.");
}
window.belHataliRuhsatYeniBasvuru=belHataliRuhsatYeniBasvuru;

async function belRuhsatBasvur(){
 const kind=$("#blrTur")?.value, city=Number($("#blrIl")?.value);
 const flexible=["kur_fabrika","kur_magaza","kur_insaat","kur_sigorta"].includes(kind);
 const mode=flexible&&$("#blrMode")?.value==="mevcut"?"mevcut":"yeni";
 const existingRequired=["arsa_insaat","yeni_proje","sube"].includes(kind);
 const companyId=existingRequired||mode==="mevcut"?Number($("#blrSirket")?.value||0)||null:null;
 const newCompany=kind?.startsWith("kur_")&&companyId===null;
 const known=(window.BEL_RUHSAT_KAYNAK?.ek?.benim||[]).find(x=>Number(x.id)===companyId);
 const companyName=newCompany?$("#blrAd")?.value?.trim():(flexible&&companyId?known?.ad:null);
 const sector=["kur_pazar","kur_sirket"].includes(kind)?$("#blrSektor")?.value:null;
 const target=["arsa_insaat","sube"].includes(kind)?Number($("#blrHedef")?.value||0)||null:null;
 const investment=Number($("#blrTutar")?.value);
 if((existingRequired||mode==="mevcut")&&!companyId){toast("Mevcut şirketi açıkça seçmelisin.",true);return;}
 if((existingRequired||mode==="mevcut")&&!known){toast("Şirket sahibi olduğun kayıtlar arasında bulunamadı.",true);return;}
 if(newCompany&&(!companyName||companyName.length<3||companyName.length>50)){toast("Yeni kurulacak şirketin adını 3–50 karakter yaz.",true);return;}
 if(flexible&&mode==="mevcut"&&!await onayla("Mevcut şirkete bağlama",
  known.ad+" (#"+known.id+") şirketinin bu belediye ruhsatına bağlanmasını onaylıyor musun? Bu işlem yeni şirket oluşturmaz.","Bu şirkete bağla"))return;
 if(["arsa_insaat","sube"].includes(kind)&&!target){toast("İşleme ait arsayı veya dükkânı seç.",true);return;}
 if(!Number.isFinite(investment)||investment<0||investment>1e9){toast("Geçerli yatırım tutarı gir.",true);return;}
 try{
  const response=await API.rpc("bel_ruhsat_basvur",{p_tur:kind,p_il:city,p_sirket:companyId,
   p_hedef:target,p_ad:companyName||null,p_sektor:sector,p_yatirim:investment});
  toast("Başvuru #"+response.id+" belediyeye gönderildi. Tahmini harç: "+fmt(response.tahmini_harc)+" TL");
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
