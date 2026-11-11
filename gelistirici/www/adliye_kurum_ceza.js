/* SO_ADLIYE_SERBEST_TUTAR_V1 — Kurum davalarında serbest tutarlı para cezası.
   Eski 10/50 bin TL seçenekleri sunucuda geriye dönük uyumluluk için kalır. */
(function(){
 'use strict';
 const once = window.adlKararModal;
 if(typeof once !== 'function') return;
 window.adlKararModal = function(id){
  const dv = ((typeof ADL!=="undefined"&&ADL.davalar)||[]).find(d=>Number(d.id)===Number(id));
  if(!dv || !dv.davali_kurum_tur) return once(id);
  const paraUygun = dv.davali_kurum_tur!=="makam"&&dv.tur!=="tazminat";
  const talep=Math.min(1000000,Number(dv.tazminat_talep||0));
  const tazminatUygun = dv.davali_kurum_tur!=="makam"&&dv.tur==="tazminat"&&talep>=1000;
  const secenekler=[['beraat','Beraat'],['uyari','Uyarı']];
  if(paraUygun)secenekler.push(['para_tutar','Para cezası — tutarı belirle']);
  if(tazminatUygun)secenekler.push(['tazminat','Tazminat — tutarı belirle']);
  const m=modal('<p class="alt">Kurum: '+e(dv.davali_kurum_ad||'Kurum')+'. Para cezası kurum kasasından Hazineye tahsil edilir; tazminat davacıya ödenir.</p>'
   +'<div class="alan"><label for="adlCeza">Mahkeme kararı</label><select id="adlCeza">'+secenekler.map(([k,v])=>'<option value="'+k+'">'+v+'</option>').join('')+'</select></div>'
   +(paraUygun?'<div class="alan" id="adlKurumParaKutu" style="display:none"><label for="adlKararParaTutar">Para cezası tutarı (₺)</label><input id="adlKararParaTutar" type="number" inputmode="numeric" min="1000" max="1000000" step="1" placeholder="1.000 – 1.000.000 ₺" style="width:100%;min-width:0;box-sizing:border-box;font-size:16px;color:var(--txt);background:var(--panel2)" autocomplete="off"></div>':'')
   +(tazminatUygun?'<div class="alan" id="adlKurumTazKutu" style="display:none"><label for="adlKararTazTutar">Tazminat tutarı (₺), üst sınır '+tlYaz(talep)+'</label><input id="adlKararTazTutar" type="number" inputmode="numeric" min="1000" max="'+talep+'" step="1" placeholder="Tutarı yazın" style="width:100%;min-width:0;box-sizing:border-box;font-size:16px;color:var(--txt);background:var(--panel2)" autocomplete="off"></div>':'')
   +'<div class="alan"><label for="adlGerekce">Gerekçeli karar (20–5000 karakter)</label><textarea id="adlGerekce" maxlength="5000" style="width:100%;min-width:0;box-sizing:border-box;font-size:16px" rows="4"></textarea></div>'
   +'<p class="alt">Heyetin çoğunluğu aynı karar ve tutarda birleşirse karar açıklanır. İstinaf hakkı korunur.</p>'
   +'<button class="btn altin" id="adlKarar">Oyumu ver</button>');
  adlFormBaslik(m,"Yüksek Mahkeme · Kurum Davası #"+id);
  const sec=m.querySelector('#adlCeza');
  sec.onchange=()=>{
   const p=m.querySelector('#adlKurumParaKutu');if(p)p.style.display=sec.value==='para_tutar'?'block':'none';
   const t=m.querySelector('#adlKurumTazKutu');if(t)t.style.display=sec.value==='tazminat'?'block':'none';
  };
  m.querySelector('#adlKarar').onclick=async()=>{
   const k=sec.value;
   const alan=k==='para_tutar'?m.querySelector('#adlKararParaTutar'):k==='tazminat'?m.querySelector('#adlKararTazTutar'):null;
   const tutar=alan?Number(alan.value):null,ust=k==='tazminat'?talep:1000000;
   if(alan&&(alan.value.trim()===''||!Number.isInteger(tutar)||tutar<1000||tutar>ust)){
    toast('Tutarı 1.000 ₺ ile '+tlYaz(ust)+' arasında tam sayı olarak girin.',true);alan.focus();return;
   }
   const gerekce=m.querySelector('#adlGerekce').value;
   if(gerekce.trim().length<20){toast('Gerekçeli karar en az 20 karakter olmalıdır.',true);return;}
   if(!await onayla('Oyunu ver','Çoğunluk oluşursa karar açıklanır. İstinaf yolu açıktır.','Oyumu ver',true))return;
   adlIslem(()=>k==='para_tutar'?API.rpc('adliye_para_oy',{p_dava:id,p_tutar:tutar,p_gerekce:gerekce})
     :k==='tazminat'?API.rpc('adliye_tazminat_oy',{p_dava:id,p_tutar:tutar,p_gerekce:gerekce})
     :API.rpc('adliye_oy_ver',{p_dava:id,p_karar:k,p_gerekce:gerekce}),'Oyun kaydedildi.',id);
  };
 };
})();
