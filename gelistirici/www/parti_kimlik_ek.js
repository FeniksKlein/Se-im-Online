/* Parti genel başkanı: amblem ve aday adaylığı ücreti yönetimi. */
async function partiAmblemModal(pid) {
  let p; try { p=await API.rpc("parti_detay",{p_parti:pid}); }
  catch(err){toast(hataCevir(err.message),true);return;}
  let secim=p.amblem;
  const m=modal(`<h3>Parti amblemini değiştir</h3>
    <p class="alt">Yalnızca görevdeki genel başkan değiştirebilir. Parti rengi korunur; seçimin üyelere ve seçim ekranına yansır. Önceki amblem kayıt altında kalır.</p>
    <div class="kart" style="text-align:center;background:var(--panel2)">
      <div id="paAmblemOnizle" style="width:64px;height:64px;display:grid;place-items:center;margin:0 auto 10px;border-radius:16px;background:${e(p.renk)}22"></div>
      <b id="paAmblemAd"></b>
    </div>
    <div class="amblemler" id="paAmblemSecenek" role="group" aria-label="Parti amblemleri">
      ${VERI.amblem.map(a=>`<button type="button" data-amblem="${e(a.id)}" title="${e(a.ad)}" aria-label="${e(a.ad)}">
      ${amblemSvg(a.id,p.renk)}</button>`).join("")}
    </div>
    <button type="button" class="btn altin" id="paAmblemKaydet">Amblemi kaydet</button>`);
  const ciz=()=>{
    const a=VERI.amblem.find(z=>z.id===secim)||VERI.amblem[0];
    const on=document.getElementById("paAmblemOnizle");
    on.innerHTML=amblemSvg(a.id,p.renk);
    const svg=on.querySelector("svg");if(svg){svg.style.width="45px";svg.style.height="45px";}
    document.getElementById("paAmblemAd").textContent=a.ad;
    m.querySelectorAll("[data-amblem]").forEach(x=>{
      const active=x.dataset.amblem===secim;
      x.classList.toggle("secili",active);x.setAttribute("aria-pressed",String(active));
    });
  };
  m.querySelectorAll("[data-amblem]").forEach(x=>x.onclick=()=>{secim=x.dataset.amblem;ciz();});
  ciz();
  document.getElementById("paAmblemKaydet").onclick=async()=>{
    const b=document.getElementById("paAmblemKaydet");b.disabled=true;
    try{await API.rpc("parti_amblem_degistir",{p_amblem:secim});
      modalKapat();toast("Partinin amblemi güncellendi.");await durumYenile();partiDetay(pid);}
    catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
  };
}
window.ucretModal=async function(pid){
  let t;
  try{t=await API.rpc("parti_ucret_tarife",{p_parti:pid});}
  catch(err){toast(hataCevir(err.message),true);return;}
  if(!t.genel_baskan_miyim&&!(typeof yetkiAlan==="function"&&yetkiAlan("mali",pid))){toast("Adaylık ücretlerini genel başkan ve Mali İşlerden Sorumlu Genel Başkan Yardımcısı belirler.",true);return;}
  const UC=[["mv_on","Milletvekili aday adaylığı"],["bel_on","Belediye başkanı aday adaylığı"],["kurultay","Genel başkanlık adaylığı"],["cb_on","Cumhurbaşkanı aday adaylığı"]];
  const m=modal(`<h3>Parti adaylık ücretlerini belirle</h3>
    <p class="alt">Her adaylık türü için taban ücretin 0–3 katı belirlenir (0 = ücretsiz). Ücretler parti kasasına girer. Mevcut ödemeler değişmez. Tabanlar ülke ekonomisine bağlıdır.</p>
    <p class="alt">Belediye adaylığı ücretleri illerin milletvekili sayısına göre değişir. Aşağıdaki TL tutarları senin iline (${e(t.il||"")}) göre örnektir.</p>
    ${UC.map(([tur,ad])=>`<div class="kart" style="background:var(--panel2);margin:8px 0">
      <b>${ad}</b><div class="kv"><span>Temel ücret</span><b>${tlYaz((t.taban||{})[tur]||0)}</b></div>
      <div class="alan"><label>Ücret katsayısı (0–3)</label><input type="number" data-u="${tur}" min="0" max="3" step="0.05" inputmode="decimal" value="${Number((t.carpanlar||{})[tur]??1)}"></div>
      <div class="kv"><span>Yeni adaylık ücreti</span><b class="iyi" id="ucretTL_${tur}">${tlYaz((t.guncel||{})[tur]||0)}</b></div>
    </div>`).join("")}
    <button class="btn altin" id="ucretKaydet">Ücretleri kaydet</button>`);
  const refresh=()=>{
    m.querySelectorAll("[data-u]").forEach(x=>{
      const id=x.dataset.u,v=Number(x.value),cost=Number((t.taban||{})[id]||0);
      const target=document.getElementById("ucretTL_"+id);
      target.textContent=Number.isFinite(v)&&v>=0&&v<=3?tlYaz(Math.round(cost*v)):"Geçersiz katsayı";
    });
  };
  m.querySelectorAll("[data-u]").forEach(x=>x.oninput=refresh);
  refresh();
  document.getElementById("ucretKaydet").onclick=async()=>{
    const vals={};let valid=true;
    m.querySelectorAll("[data-u]").forEach(x=>{
      const v=Number(x.value);if(!x.value.trim()||!Number.isFinite(v)||v<0||v>3||Math.round(v*100)!==v*100)valid=false;
      vals[x.dataset.u]=v;
    });
    if(!valid){toast("Katsayılar 0–3 arasında ve en fazla iki ondalıklı olmalı.",true);return;}
    const b=document.getElementById("ucretKaydet");b.disabled=true;
    try{await API.rpc("parti_ucret_ayarla",{p_ucret:vals});
      modalKapat();toast("Adaylık ücretleri kaydedildi.");partiKasaCiz(pid);}
    catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
  };
};
