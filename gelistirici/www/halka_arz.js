// Şirket halka arzı ve yatırım hesaplayıcısı (sunucu: sql/62_halka_arz.sql)
const HA_ORAN={tarim:.12,sanayi:.15,teknoloji:.20,ticaret:.14,insaat:.18,medya:.16,banka:.08};
const HA_SEKTOR={tarim:"Tarım",sanayi:"Sanayi",teknoloji:"Teknoloji",ticaret:"Ticaret",insaat:"İnşaat",medya:"Medya",banka:"Banka"};
let _ha=null;
const haTL=x=>fmt(Math.round(Number(x)||0))+" ₺";
const haYuzde=x=>"%"+(Math.round((Number(x)||0)*100)/100).toLocaleString("tr-TR");
function haOrtNet(sermaye,sektor,asgari){return Math.round(sermaye*(HA_ORAN[sektor]||.08)-sermaye*.0525-asgari)}
function haKalan(bit){const ms=new Date(bit)-Date.now();if(ms<=0)return"süre doldu, sonuçlanıyor";const s=Math.floor(ms/36e5),d=Math.floor(ms%36e5/6e4);return(s?s+" sa ":"")+d+" dk kaldı"}
function haCubuk(a){const o=Math.min(100,Number(a.toplanan)/Number(a.hedef)*100),as=Math.min(100,Number(a.asgari)/Number(a.hedef)*100);
 return `<div style="position:relative;height:12px;border-radius:6px;background:var(--panel2);overflow:hidden;margin:8px 0 4px" role="progressbar" aria-valuenow="${Math.round(o)}" aria-valuemin="0" aria-valuemax="100">
 <div style="height:100%;width:${o}%;background:var(--ink)"></div><div title="Asgari" style="position:absolute;top:0;bottom:0;left:${as}%;width:2px;background:var(--al)"></div></div>
 <p class="kucuk">${haTL(a.toplanan)} / ${haTL(a.hedef)} toplandı · asgari ${haTL(a.asgari)} (kırmızı çizgi) · ${a.yatirimci} yatırımcı</p>`}

// Şirketlerim ekranındaki her şirket kartına eklenen giriş
function halkaArzKart(s){
 return `<div class="kart" style="background:var(--panel2);margin:10px 0"><h3>Halka arz ve yatırım hesabı</h3>
 <p class="alt">Dışarıdan yatırım gelirse haftalık kârın kaça çıkacağını hesapla${Number(s.pay)>=50?"; istersen şirketini halka arz edip diğer oyunculardan sermaye topla":""}.</p>
 <button class="btn altin" onclick="halkaArzEkrani(${s.id})">Hesapla${Number(s.pay)>=50?" / halka arz et":""}</button></div>`;
}

async function halkaArzEkrani(id){
 yukleniyor("Halka arz");
 try{
  const d=await API.rpc("halka_arz_durum",{p_sirket:id});_ha=d;
  const benim=Number(d.payim)>=50,a=d.acik;
  const varsayilan=Math.max(10000,Math.min(Number(d.en_fazla_tutar),Math.round(Number(d.sermaye))));
  iskelet("Halka arz",`
  <div class="kart"><h2>${e(d.ad)}</h2><p class="alt">${e(HA_SEKTOR[d.sektor]||d.sektor)}${d.halka_acik?" · halka açık şirket":""} · payın ${haYuzde(d.payim)}</p>
   <div class="kv"><span>Sermaye</span><b>${haTL(d.sermaye)}</b></div>
   <div class="kv"><span>Haftalık ortalama net kâr</span><b>${haTL(d.ort_net)}</b></div>
   <div class="kv"><span>Asgari ücret</span><b>${haTL(d.asgari_ucret)}</b></div></div>
  ${a?haAcikKart(a,true):""}
  <div class="kart"><h2>Yatırım hesaplayıcı</h2>
   <p class="alt">Şirkete yeni sermaye girerse haftalık ortalama kâr ve ortakların payı nasıl değişir? Haftalık kâr sermayeyle büyür; gider tarafındaki asgari ücret sabit kaldığı için büyüme oransal olandan da hızlıdır.</p>
   <div class="alan"><label>Gelecek yatırım (₺)</label><input id="ha_tutar" type="number" min="0" step="1000" value="${varsayilan}" oninput="haHesapCiz()"></div>
   <div class="alan"><label>Şirket değeri, yatırım öncesi (₺)</label><input id="ha_deger" type="number" min="${d.deger_en_az}" max="${d.deger_en_cok}" step="1000" value="${Math.round(d.deger_onerilen)}" oninput="haHesapCiz()">
    <p class="kucuk">${haTL(d.deger_en_az)} – ${haTL(d.deger_en_cok)} arası. Önerilen: ${haTL(d.deger_onerilen)} (yaklaşık 26 haftalık kâr). Değer yükseldikçe aynı para için daha az pay verirsin.</p></div>
   <div id="ha_sonuc" aria-live="polite"></div>
  </div>
  ${benim&&!a?`<div class="kart"><h2>Halka arzı başlat</h2>
   <p class="alt">Hesaplayıcıdaki yatırım tutarı hedef, şirket değeri arz fiyatı olur. Diğer oyuncular talep verir; paraları süre bitene kadar emanette kalır. Asgari tutara ulaşılırsa toplanan para şirketin sermayesine ve kasasına girer, yatırımcılar ortak olur. Ulaşılamazsa herkese iade edilir. Hedef dolarsa arz hemen tamamlanır.</p>
   <div class="alan"><label>Asgari başarı tutarı</label><select id="ha_asgari"><option value=".25">Hedefin %25'i</option><option value=".5" selected>Hedefin %50'si</option><option value=".75">Hedefin %75'i</option><option value="1">Hedefin tamamı</option></select></div>
   <div class="alan"><label>Talep toplama süresi</label><select id="ha_saat"><option value="24">24 saat</option><option value="48">48 saat</option><option value="72" selected>72 saat</option></select></div>
   <p class="kucuk">En fazla %49 pay satılabilir; sermaye 100.000.000 ₺'yi aşamaz. Bu şirket için en fazla ${haTL(d.en_fazla_tutar)} toplanabilir. Toplanan para sermayeye eklenir, kâr payı olarak dağıtılamaz.</p>
   <button class="btn altin" id="ha_baslat" onclick="halkaArzBaslat(${d.id})">Halka arzı başlat</button></div>`:""}
  ${!benim&&!a?`<div class="kart"><p class="alt">Halka arzı şirketin en az %50'sine sahip ortak başlatabilir.</p></div>`:""}
  ${(d.gecmis||[]).length?`<div class="kart"><h2>Geçmiş halka arzlar</h2>${d.gecmis.map(g=>`<div class="kv"><span>${tarihSaat(g.bas)} · ${haDurumAd(g.durum)}</span><b>${haTL(g.toplanan)}</b></div><p class="kucuk">${e(g.aciklama||"")}</p>`).join("")}</div>`:""}
  <button class="btn ikinci" onclick="halkaArzPazarEkrani()">Tüm açık halka arzlar</button>
  `,{geri:true});
  haHesapCiz();
 }catch(err){iskelet("Halka arz",`<div class="bos">${e(hataCevir(err.message))}</div>`,{geri:true})}
}
function haDurumAd(d){return{acik:"Talep topluyor",tamam:"Tamamlandı",basarisiz:"Gerçekleşmedi",iptal:"İptal edildi"}[d]||d}

function haHesapCiz(){
 const d=_ha,el=document.getElementById("ha_sonuc");if(!d||!el)return;
 const tutar=Math.max(0,Math.round(Number(document.getElementById("ha_tutar").value)||0));
 let deger=Math.round(Number(document.getElementById("ha_deger").value)||Number(d.deger_onerilen));
 const degerUyari=deger<Number(d.deger_en_az)||deger>Number(d.deger_en_cok);
 deger=Math.min(Number(d.deger_en_cok),Math.max(Number(d.deger_en_az),deger));
 const sermaye=Number(d.sermaye),asg=Number(d.asgari_ucret),post=deger+tutar;
 const once=haOrtNet(sermaye,d.sektor,asg),sonra=haOrtNet(sermaye+tutar,d.sektor,asg);
 const yatPay=post?tutar/post*100:0,benimOnce=Number(d.payim),benimSonra=benimOnce*deger/post;
 const yatHafta=Math.max(0,sonra)*yatPay/100,geri=yatHafta>0?Math.ceil(tutar/yatHafta):null;
 const sinir=sermaye+tutar>1e8?"Sermaye 100.000.000 ₺'yi aşar.":yatPay>49?"Halka arzda en fazla %49 pay satılabilir; tutarı düşür ya da şirket değerini artır.":"";
 const renk=x=>x<0?"var(--acc2)":"var(--good)";
 el.innerHTML=`<div class="kart" style="background:var(--panel2)">
  <div class="kv"><span></span><b>Şu an → Yatırımdan sonra</b></div>
  <div class="kv"><span>Sermaye</span><b>${haTL(sermaye)} → ${haTL(sermaye+tutar)}</b></div>
  <div class="kv"><span>Haftalık ortalama net kâr</span><b><span style="color:${renk(once)}">${haTL(once)}</span> → <span style="color:${renk(sonra)}">${haTL(sonra)}</span></b></div>
  <div class="kv"><span>Haftalık kâr artışı</span><b style="color:${renk(sonra-once)}">${sonra-once>=0?"+":""}${haTL(sonra-once)}</b></div>
  ${benimOnce>0?`<div class="kv"><span>Senin payın</span><b>${haYuzde(benimOnce)} → ${haYuzde(benimSonra)}</b></div>
  <div class="kv"><span>Sana düşen haftalık ortalama</span><b>${haTL(Math.max(0,once)*benimOnce/100)} → ${haTL(Math.max(0,sonra)*benimSonra/100)}</b></div>`:""}
  <div class="kv"><span>Yatırımcıların toplam payı</span><b>${haYuzde(yatPay)}</b></div>
  <div class="kv"><span>Yatırımcılara düşen haftalık ortalama</span><b>${haTL(yatHafta)}</b></div>
  ${geri?`<div class="kv"><span>Yatırımcının parasını geri kazanma süresi</span><b>~${geri} hafta</b></div>`:""}
  ${degerUyari?`<p class="kucuk" style="color:var(--acc2)">Şirket değeri ${haTL(d.deger_en_az)} – ${haTL(d.deger_en_cok)} aralığına çekilerek hesaplandı.</p>`:""}
  ${sinir?`<p class="kucuk" style="color:var(--acc2)">${sinir}</p>`:""}
  <p class="kucuk">Ortalama senaryodur; gerçek haftalık sonuç gelir ve gider dalgalanmasıyla değişir. Asgari ücret değişirse tahmin de değişir.</p></div>`;
 const b=document.getElementById("ha_baslat");if(b)b.disabled=!!sinir||tutar<10000;
}

async function halkaArzBaslat(id){
 const tutar=Math.round(Number(document.getElementById("ha_tutar").value)),deger=Math.round(Number(document.getElementById("ha_deger").value));
 const oran=Number(document.getElementById("ha_asgari").value),saat=Number(document.getElementById("ha_saat").value);
 const pay=tutar/(deger+tutar)*100;
 if(!confirm(`${haTL(tutar)} hedefle halka arz başlatılsın mı?\nŞirket değeri: ${haTL(deger)}\nSatılacak pay: ${haYuzde(pay)}\nAsgari: ${haTL(tutar*oran)} · Süre: ${saat} saat`))return;
 try{await API.rpc("halka_arz_baslat",{p_sirket:id,p_hedef:tutar,p_deger:deger,p_asgari:Math.round(tutar*oran),p_saat:saat});toast("Halka arz başladı; talepler toplanıyor.");halkaArzEkrani(id)}
 catch(err){toast(hataCevir(err.message),true)}
}
async function halkaArzIptal(arz,sirket){
 if(!confirm("Halka arz iptal edilsin mi? Toplanan bütün talepler yatırımcılara iade edilir."))return;
 try{await API.rpc("halka_arz_iptal",{p_arz:arz});toast("Halka arz iptal edildi; talepler iade edildi.");sirket?halkaArzEkrani(sirket):halkaArzPazarEkrani()}
 catch(err){toast(hataCevir(err.message),true)}
}

function haAcikKart(a,sirketEkrani){
 const kalan=Number(a.hedef)-Number(a.toplanan);
 return `<div class="kart"><h2>${sirketEkrani?"Açık halka arz":e(a.sirket)}</h2>
  <p class="alt">${e(HA_SEKTOR[a.sektor]||a.sektor)} · başlatan ${e(a.baslatan)} · ${haKalan(a.bit)}</p>
  ${haCubuk(a)}
  <div class="kv"><span>Şirket değeri (arz öncesi)</span><b>${haTL(a.deger)}</b></div>
  <div class="kv"><span>Satılan pay (hedef dolarsa)</span><b>${haYuzde(a.satilan_pay_hedef)}</b></div>
  <div class="kv"><span>Her 10.000 ₺ talep</span><b>≈ ${haYuzde(10000/(Number(a.deger)+Number(a.hedef))*100)} pay</b></div>
  <div class="kv"><span>Haftalık ortalama net kâr</span><b>${haTL(a.ort_net_simdi)} → ${haTL(a.ort_net_hedef)}</b></div>
  ${Number(a.talebim)>0?`<div class="kv"><span>Senin talebin</span><b>${haTL(a.talebim)}</b></div>`:""}
  ${a.ben_baslattim?`<button class="btn ikinci" onclick="halkaArzIptal(${a.id},${sirketEkrani?a.sirket_id:0})">Halka arzı iptal et</button>`:
   `<div class="alan"><label>Talep tutarı (₺, en az 1.000 · kalan ${haTL(kalan)})</label><input id="ha_talep_${a.id}" type="number" min="1000" step="1000" max="${kalan}" value="${Math.min(kalan,10000)}" oninput="haTalepOnizle(${a.id})"><p class="kucuk" id="ha_talep_ozet_${a.id}"></p></div>
   <button class="btn altin" onclick="halkaArzTalep(${a.id},${sirketEkrani?a.sirket_id:0})">Talep ver</button>
   ${Number(a.talebim)>0?`<button class="btn ikinci" onclick="halkaArzTalepGeri(${a.id},${sirketEkrani?a.sirket_id:0})">Talebimi geri al</button>`:""}`}
 </div>`;
}
let _haListe=[];
function haTalepOnizle(id){
 const a=_haListe.find(x=>x.id===id)||(_ha&&_ha.acik&&_ha.acik.id===id?_ha.acik:null),el=document.getElementById("ha_talep_ozet_"+id);if(!a||!el)return;
 const t=Math.max(0,Number(document.getElementById("ha_talep_"+id).value)||0),pay=t/(Number(a.deger)+Number(a.hedef))*100;
 el.textContent=`Hedef dolarsa yaklaşık ${haYuzde(pay)} ortak olursun; haftalık ortalama payın ≈ ${haTL(Math.max(0,a.ort_net_hedef)*pay/100)}. Hedef dolmazsa payın biraz daha büyük olur.`;
}
async function halkaArzTalep(arz,sirket){
 const t=Math.round(Number(document.getElementById("ha_talep_"+arz).value));
 if(!confirm(`${haTL(t)} talep verilsin mi? Para arz sonuçlanana kadar emanette kalır; arz gerçekleşmezse iade edilir.`))return;
 try{const r=await API.rpc("halka_arz_talep",{p_arz:arz,p_tutar:t});toast(r.durum==="tamam"?"Hedef doldu, halka arz tamamlandı; artık şirketin ortağısın.":"Talebin alındı.");sirket?halkaArzEkrani(sirket):halkaArzPazarEkrani()}
 catch(err){toast(hataCevir(err.message),true)}
}
async function halkaArzTalepGeri(arz,sirket){
 if(!confirm("Talebin geri alınsın mı? Para cüzdanına döner."))return;
 try{await API.rpc("halka_arz_talep_geri",{p_arz:arz});toast("Talebin geri alındı.");sirket?halkaArzEkrani(sirket):halkaArzPazarEkrani()}
 catch(err){toast(hataCevir(err.message),true)}
}

async function halkaArzPazarEkrani(){
 yukleniyor("Halka arzlar");
 try{
  const d=await API.rpc("halka_arz_liste");_haListe=d.acik||[];
  iskelet("Halka arzlar",`
  <div class="kart"><h2>Halka arzlar</h2><p class="alt">Oyuncu şirketlerinin halka arzlarına talep ver, şirkete ortak ol ve haftalık kârdan payını al. Cüzdanın: ${haTL(d.cuzdan)}</p>
   <button class="btn ikinci" onclick="sirketYonetimEkrani()">Şirketlerim</button></div>
  ${_haListe.length?_haListe.map(a=>haAcikKart(a,false)).join(""):'<div class="kart"><p class="alt">Şu anda talep toplayan halka arz yok.</p></div>'}
  ${(d.son||[]).length?`<div class="kart"><h2>Son sonuçlananlar</h2>${d.son.map(g=>`<div class="kv"><span>${e(g.sirket)} · ${haDurumAd(g.durum)}</span><b>${haTL(g.toplanan)}</b></div><p class="kucuk">${tarihSaat(g.sonuc_zaman)} · ${e(g.aciklama||"")}</p>`).join("")}</div>`:""}
  `,{geri:true});
  _haListe.forEach(a=>{if(!a.ben_baslattim)haTalepOnizle(a.id)});
 }catch(err){iskelet("Halka arzlar",`<div class="bos">${e(hataCevir(err.message))}</div>`,{geri:true})}
}
