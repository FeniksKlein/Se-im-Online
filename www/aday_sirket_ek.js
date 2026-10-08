
/* Parti adayı görünürlüğü ve şirket finans detayları. Sürüm 2026.10.08-11. */
async function partiAdayKartiCiz(pid){
 const el=document.getElementById("partiAdayKart");if(!el)return;
 try{
  const [d,b]=await Promise.all([
   API.rpc("parti_aday_kart",{p_parti:pid}),
   API.rpc("bel_destek_durum",{p_parti:pid})
  ]);
  if(!document.getElementById("partiAdayKart"))return;
  const cb=d.cb;
  const name=cb&&cb.aday?`<b style="font-size:19px">${e(cb.aday)}</b><div class="alt">${e(cb.aday_partisi||"")} · ${e(cb.donem||"")}</div>`:
   `<span class="alt">${cb&&cb.asama==="onsecim_bekliyor"?"Üyelerin ön seçimi bekleniyor":cb&&cb.asama==="destek_bekliyor"?"Desteklenen partinin kesin adayı henüz belli değil":"Kesin Cumhurbaşkanı adayı henüz açıklanmadı"}</span>`;
  const rows=(array)=>array.map(a=>`<div class="kv"><span>${e(a.kad)} · ${e(a.il||"Türkiye geneli")}</span><b>${e(a.tur==="mv_on"?"Milletvekili":a.tur==="cb_on"||a.tur==="cb"?"Cumhurbaşkanı":a.tur==="bel"?"Belediye":"Aday")}</b></div>`).join("");
  el.innerHTML=`<div class="kart" style="border:1px solid var(--gold)">
    <h2>🗳️ Adaylarımız ve desteklediğimiz adaylar</h2>
    <div class="kart" style="background:var(--panel2)"><h3>🇹🇷 Cumhurbaşkanı adayımız</h3>${name}
      ${cb&&(cb.destekleyenler||[]).length?`<div class="kucuk">Destekleyenler: ${cb.destekleyenler.map(p=>e(p.kisa)).join(", ")}</div>`:""}
    </div>
    ${(d.kesin_adaylar||[]).length?`<h3>Kesinleşmiş adaylarımız</h3>${rows(d.kesin_adaylar)}`:""}
    ${d.uye_mi?`<h3>Milletvekili ve Cumhurbaşkanı aday adayları</h3>
      <p class="alt">Başvuru yapan gerçek oyuncular (yalnız parti üyeleri görebilir).</p>
      ${(d.aday_adaylari||[]).length?rows(d.aday_adaylari):"<p class='alt'>Bu dönemde henüz başvuran aday adayı yok.</p>"}`:""}
    ${(b.desteklerim||[]).length?`<h3>Belediye başkanlığında desteklediğimiz adaylar</h3>
      ${(b.desteklerim||[]).map(x=>`<div class="kv"><span>${e(x.il)} · ${e(x.kad)} (${e(x.parti)})</span>
        ${d.genel_baskan_mi&&b.acik?`<button class="btn ikinci" onclick="belDestekGeriCek(${pid},${x.il_id})">Geri çek</button>`:""}
      </div>`).join("")}`:""}
    ${d.genel_baskan_mi?`<button class="btn ikinci" onclick="cbKararModal()">Cumhurbaşkanı adayını belirle / destekle</button>
     <button class="btn ikinci" onclick="belDestekModal(${pid})">🏙️ Belediye ortak adayını açıkla / destekle</button>
     <button class="btn altin" onclick="partiAdayTanitModal(${pid})">📣 Bir adayı tanıt</button>`:""}
    ${(d.tanitimlar||[]).length?`<h3>Aday tanıtımları</h3>
      ${d.tanitimlar.map(t=>`<div class="kart" style="background:var(--panel2);margin-top:8px"><b>${e(t.kad)}</b>
      <span class="rozet">${t.kitle==="herkes"?"Herkese açık":"Yalnız üyelere"}</span>
      <p style="white-space:pre-wrap;margin-top:8px">${e(t.metin)}</p><div class="kucuk">${e(t.yayinlayan)} · ${tarihSaat(t.zaman)}</div></div>`).join("")}`:""}
   </div>`;
 }catch(err){el.innerHTML=`<div class="kart"><h2>Adaylarımız</h2><p class="alt">${e(hataCevir(err.message))}</p></div>`;}
}
async function partiAdayTanitModal(pid){
 try{
  const d=await API.rpc("parti_aday_kart",{p_parti:pid});
  let a=[...(d.kesin_adaylar||[]),...(d.aday_adaylari||[])];
  if(d.cb&&d.cb.asama==="kesin"&&d.cb.aday_parti_id!==pid){
   const sec=await API.rpc("cb_destek_secenekleri");
   const hedef=(sec.secenekler||[]).find(x=>x.parti_id===d.cb.aday_parti_id);
   if(hedef)a.push({id:hedef.aday_id,kad:hedef.aday,il:"Türkiye geneli"});
  }
  a=[...new Map(a.map(x=>[x.id,x])).values()];
  if(!a.length){toast("Henüz tanıtılabilecek aday bulunmuyor.",true);return;}
  const m=modal(`<h3>📣 Aday tanıtımı</h3><p class="alt">24 saatte en fazla 3 aday tanıtımı. Kitleyi genel başkan seçer.</p>
   <div class="alan"><label>Aday</label><select id="adt_kisi">${a.map(x=>`<option value="${x.id}">${e(x.kad)} · ${e(x.il||"Türkiye")}</option>`).join("")}</select></div>
   <div class="alan"><label>Kim görsün?</label><select id="adt_kitle"><option value="herkes">Herkes</option><option value="uyeler">Yalnız parti üyeleri</option></select></div>
   <div class="alan"><label>Aday tanıtımı (20–600 karakter)</label><textarea id="adt_metin" class="alanmetin" maxlength="600" placeholder="Adayın tecrübesi, çalışmaları ve hedefleri..."></textarea></div>
   <button class="btn altin" id="adt_yayin">Tanıtımı yayınla</button>`);
  document.getElementById("adt_yayin").onclick=async()=>{
   try{await API.rpc("parti_aday_tanit",{p_aday:+document.getElementById("adt_kisi").value,p_kitle:document.getElementById("adt_kitle").value,p_metin:document.getElementById("adt_metin").value});
   modalKapat();toast("Tanıtım yayınlandı.");partiAdayKartiCiz(pid)}catch(err){toast(hataCevir(err.message),true)}
  };
 }catch(err){toast(hataCevir(err.message),true)}
}
async function belDestekModal(pid){
 try{
  const b=await API.rpc("bel_destek_durum",{p_parti:pid});
  if(!b.acik){toast("Belediye ön seçimi sonuçlandıktan sonra, oy verme başlamadan ortak aday açıklayabilirsin.",true);return;}
  if(!(b.adaylar||[]).length){toast("Henüz başka partinin kesinleşmiş belediye adayı yok.",true);return;}
  const m=modal(`<h3>🏙️ Belediye ortak adayı</h3><p class="alt">Bir başka partinin kesinleşmiş gerçek adayını desteklersin. Aynı ilde kendi adayın varsa pusuladan çekilir. İttifak ortağıysa ittifakın ortak adayı olur.</p>
   <div class="alan"><label>Desteklenecek aday</label><select id="bel_hedef">${b.adaylar.map(x=>`<option value="${x.id}">${e(x.il)} · ${e(x.kad)} · ${e(x.parti)}${x.ortak?" (ittifak)":""}</option>`).join("")}</select></div>
   <button class="btn altin" id="bel_karar">Adayı destekle</button>`);
  document.getElementById("bel_karar").onclick=async()=>{
   const x=b.adaylar.find(z=>z.id===+document.getElementById("bel_hedef").value);
   if(!x)return;
   if(!await onayla("Aday desteği","Bu ilde partinin kendi adayı varsa çekilecek, "+e(x.kad)+" tek aday olarak desteklenecek. Onaylıyor musun?","Destekle"))return;
   try{await API.rpc("bel_aday_destek",{p_il:x.il_id,p_hedef_parti:x.parti_id});modalKapat();toast("Aday desteği açıklandı.");partiAdayKartiCiz(pid)}
   catch(err){toast(hataCevir(err.message),true)}
  };
 }catch(err){toast(hataCevir(err.message),true)}
}
async function belDestekGeriCek(pid,il){
 if(!await onayla("Desteği geri çek","Seçim başlamadan destek geri çekilecek. Varsa eski ön seçim adayın geri gelecek.","Geri çek"))return;
 try{await API.rpc("bel_destek_geri_cek",{p_il:il});toast("Destek geri çekildi.");partiAdayKartiCiz(pid)}
 catch(err){toast(hataCevir(err.message),true)}
}
function sirketMiniFinans(s,asgari){
 const rate={tarim:.12,sanayi:.15,teknoloji:.20,ticaret:.14,insaat:.18,medya:.16,banka:.08}[s.sektor]||.08;
 const gelir=Number(s.sermaye)*rate,gider=Number(s.sermaye)*.0525+Number(asgari||0);
 const net=gelir-gider;
 return `<div class="kart" style="background:var(--panel2);margin:10px 0">
  <h3>📊 7 günlük faaliyet tahmini</h3>
  <div class="kv"><span>Ortalama gelir</span><b>${fmt(Math.round(gelir))} ₺</b></div>
  <div class="kv"><span>Ortalama gider</span><b>${fmt(Math.round(gider))} ₺</b></div>
  <div class="kv"><span>Net kâr / zarar tahmini</span><b style="color:${net<0?"var(--acc2)":"var(--good)"}">${fmt(Math.round(net))} ₺</b></div>
  <p class="alt">Gerçek gelir ve gider 7 günde bir değişir; bu tahmin garanti değildir. Bankaların mevduat ve kredileri ayrıca hesaplanır.</p>
  <button class="btn altin" onclick="sirketFinansDetay(${s.id})">Gelir, gider, kasa ve geçmişi gör</button>
 </div>`;
}
async function sirketFinansDetay(id){
 yukleniyor("Şirket finans raporu");
 try{
  const x=await API.rpc("sirket_finans_ozeti",{p_sirket:id});
  const rows=(x.islemler||[]).map(h=>`<div class="kart" style="background:var(--panel2)">
   <b>${tarihSaat(h.tarih)}</b>
   <div class="kv"><span>Brüt faaliyet geliri</span><b>${h.faaliyet_gelir==null?"Eski hareketlerde ayrıştırılmamış":fmt(h.faaliyet_gelir)+" ₺"}</b></div>
   <div class="kv"><span>Personel + işletme gideri</span><b>${h.faaliyet_gider==null?"Eski hareketlerde ayrıştırılmamış":fmt(h.faaliyet_gider)+" ₺"}</b></div>
   <div class="kv"><span>Net faaliyet / hareket</span><b>${fmt(h.net)} ₺</b></div>
   ${h.dagitilan_kar!=null?`<div class="kv"><span>Ortaklara toplam dağıtım</span><b>${fmt(h.dagitilan_kar)} ₺</b></div>`:""}
   <p class="alt">${e(h.aciklama||"")}</p>
  </div>`).join("");
  iskelet("Şirket finans raporu",`
   <div class="kart"><h2>🏢 ${e(x.ad)}</h2><p class="alt">${e(x.sektor)} · Hisse payın: %${fmt(x.benim_payim,2)}</p>
    <div class="kv"><span>Şirket sermayesi</span><b>${fmt(x.sermaye)} ₺</b></div>
    <div class="kv"><span>Şirketin mevcut kasası</span><b>${fmt(x.kasa)} ₺</b></div>
    <div class="kv"><span>Dağıtılabilecek kâr</span><b>${fmt(x.dagitilabilir_kar)} ₺</b></div>
    <div class="kv"><span>Sonraki 7 günlük hesap</span><b>${tarihSaat(x.sonraki_hesaplama)}</b></div>
   </div>
   <div class="kart"><h2>📈 Bir sonraki 7 günün tahmini</h2>
     <div class="kv"><span>Olası brüt gelir</span><b>${fmt(x.tahmini_gelir_min)} – ${fmt(x.tahmini_gelir_max)} ₺</b></div>
     <div class="kv"><span>Olası gider</span><b>${fmt(x.tahmini_gider_min)} – ${fmt(x.tahmini_gider_max)} ₺</b></div>
     <div class="kv"><span>Net kâr/zarar aralığı</span><b>${fmt(x.tahmini_net_min)} – ${fmt(x.tahmini_net_max)} ₺</b></div>
     <div class="kv"><span>Ortalama net tahmin</span><b>${fmt(x.tahmini_ortalama_net)} ₺</b></div>
     <p class="alt">Gelir sermaye ve sektör kapasitesinden; gider asgari ücret ve işletme maliyetlerinden oluşur. Gerçek sonuçlar değişebilir. Bankalarda kredi, mevduat ve faiz yükümlülükleri ayrıca izlenir.</p>
   </div>
   <div class="kart"><h2>📜 Gerçekleşen son şirket hareketleri</h2>${rows||"<p class='alt'>Henüz faaliyet hareketi yok.</p>"}</div>
   <button class="btn ikinci" onclick="sirketEkrani()">Şirketlerime geri dön</button>
  `,{geri:true});
 }catch(err){iskelet("Şirket finans raporu",`<div class="bos">${e(hataCevir(err.message))}</div>`,{geri:true})}
}
