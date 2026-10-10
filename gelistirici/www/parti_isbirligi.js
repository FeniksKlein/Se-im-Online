/* Parti birlesmesi ve il bazli ortak milletvekili listesi; mevcut ittifak kartina eklenir. */
async function partiIsbirligiCiz(pid) {
  const root=document.getElementById("ittifakKart");
  if(!root) return;
  let d;
  try { d=await API.rpc("parti_isbirligi_durum",{p_parti:pid}); }
  catch(err) { root.insertAdjacentHTML("beforeend",'<div class="kart"><h2>Birleşme ve ortak liste</h2><p class="alt">'+e(hataCevir(err.message))+'</p></div>'); return; }
  if(!root.isConnected) return;
  const durum={bekliyor:"Yanıt bekliyor",kabul:"Kabul edildi",ret:"Reddedildi",iptal:"İptal edildi"};
  let h='<div class="kart"><h2>Parti birleşmesi</h2>';
  h+='<p class="alt">Kalıcı birleşmede teklif gönderen parti, karşı partinin çatısı altına katılır. İki genel başkan onayı gerekir. Üyeler ve parti kasası hedef partiye aktarılır; kaynak parti kapanır. Mevcut oyuncu paraları, makamlar ve geçmiş seçim kayıtları korunur.</p>';
  if(d.gb_miyim) h+='<button class="btn altin" onclick="partiBirlesmeModal('+pid+')">Başka partiyle birleşme teklif et</button>';
  if(d.birlesme_kilit) h+='<p class="kucuk" style="margin-top:8px">'+e(d.birlesme_kilit)+'</p>';
  (d.birlesmeler||[]).forEach(function(x) {
    const gelen=x.hedef && x.hedef.id===pid;
    h+='<div style="margin-top:10px;padding:12px;border-radius:10px;background:var(--panel2)"><b>'
      +e(x.kaynak?.kisa||"—")+' → '+e(x.hedef?.kisa||"—")+'</b> · <span class="rozet">'+e(durum[x.durum]||x.durum)+'</span>';
    if(x.durum==="kabul") h+='<p class="kucuk">Birleşme tamamlandı. Aktarılan kasa: '+tlYaz(x.tasinan_kasa||0)+'</p>';
    if(x.yanitlayabilirim && gelen) h+='<div class="satir"><button class="btn yarim" onclick="partiBirlesmeYanit('+pid+','+x.id+',true)">Kabul et</button><button class="btn yarim ikinci" onclick="partiBirlesmeYanit('+pid+','+x.id+',false)">Reddet</button></div>';
    if(x.iptal_edebilirim) h+='<button class="btn ikinci" onclick="partiBirlesmeIptal('+pid+','+x.id+')">Teklifi geri çek</button>';
    h+='</div>';
  });
  h+='</div><div class="kart"><h2>Ortak milletvekili listesi</h2>';
  h+='<p class="alt">Aynı ittifaktaki iki parti bir ilde tek listeyle seçime girer. Oylar o ilde ortak hesaplanır; seçilen adaylar kendi partilerinin milletvekili olur. Her iki genel başkan kabul etmelidir. Bu özellik normal seçim sayımında uygulanır. Test döneminde mevcut tüm kesinleşmiş adayların seçilmesi kuralı korunur.</p>';
  if(d.gb_miyim && d.mv_secim) h+='<button class="btn altin" onclick="mvOrtakListeModal('+pid+')">Ortak liste teklif et</button>';
  if(d.gb_miyim && !d.mv_secim) h+='<p class="kucuk">Yaklaşan açık genel seçim bulunmuyor.</p>';
  (d.ortak_listeler||[]).forEach(function(x) {
    h+='<div style="margin-top:10px;padding:12px;border-radius:10px;background:var(--panel2)"><b>'
      +e(x.il||"İl")+' · '+e(x.teklif_eden?.kisa||"—")+' + '+e(x.ortak?.kisa||"—")+'</b>';
    h+=' <span class="rozet">'+e(durum[x.durum]||x.durum)+'</span><div class="kucuk">Ortak liste adı: '+e(x.lider?.kisa||"—")+'</div>';
    if(x.yanitlayabilirim) h+='<div class="satir"><button class="btn yarim" onclick="mvOrtakListeYanit('+pid+','+x.id+',true)">Kabul et</button><button class="btn yarim ikinci" onclick="mvOrtakListeYanit('+pid+','+x.id+',false)">Reddet</button></div>';
    if(x.iptal_edebilirim) h+='<button class="btn ikinci" onclick="mvOrtakListeIptal('+pid+','+x.id+')">Teklifi geri çek</button>';
    h+='</div>';
  });
  h+='</div>';
  root.insertAdjacentHTML("beforeend",h);
}
async function partiBirlesmeModal(pid) {
  try {
    const ps=(await API.rpc("partiler")).filter(x=>x.id!==pid&&!x.kapali);
    if(!ps.length) return toast("Birleşilebilecek başka parti bulunmuyor.",true);
    const m=modal('<h3>Parti birleşmesi teklif et</h3><p class="alt">Senin partin, seçeceğin partinin çatısına katılarak kapanacak. Karşı tarafın genel başkanı kabul ederse bütün üyeler ve parti kasası devredilecek. Mevcut makamlar ve geçmiş seçimler korunacak.</p><div class="alan"><label>Katılacağın parti</label><select id="pbHedef">'+ps.map(x=>'<option value="'+x.id+'">'+e(x.ad)+'</option>').join("")+'</select></div><button class="btn altin" id="pbGonder">Birleşme teklifini gönder</button>');
    document.getElementById("pbGonder").onclick=async()=>{
      const b=document.getElementById("pbGonder"); b.disabled=true;
      try {
        await API.rpc("parti_birlesme_teklif",{p_hedef:Number(document.getElementById("pbHedef").value)});
        modalKapat(); toast("Birleşme teklifi karşı partiye gönderildi."); partiDetay(pid);
      } catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
    };
  } catch(err){toast(hataCevir(err.message),true);}
}
async function partiBirlesmeYanit(pid,id,kabul) {
  if(kabul && !await onayla("Kalıcı parti birleşmesi","Teklif gönderen partinin tüm üyeleri, kasası ve mevcut makam bağları partine aktarılacak. Kaynak parti kapatılacak. Bu işlem geri alınamaz.","Birleşmeyi kabul et",true))return;
  try {await API.rpc("parti_birlesme_yanit",{p_id:id,p_kabul:kabul}); toast(kabul?"Partiler birleşti.":"Birleşme teklifi reddedildi."); await durumYenile();partiDetay(pid);}
  catch(err){toast(hataCevir(err.message),true);}
}
async function partiBirlesmeIptal(pid,id) {
  try {await API.rpc("parti_birlesme_iptal",{p_id:id});toast("Teklif geri çekildi.");partiDetay(pid);}
  catch(err){toast(hataCevir(err.message),true);}
}
async function mvOrtakListeModal(pid) {
  try{
    const [b,ps]=await Promise.all([API.rpc("ittifak_bilgi",{p_parti:pid}),API.rpc("partiler")]);
    const ortakIds=new Set((b.ittifak?.uyeler||[]).map(x=>x.id));
    const secenek=ps.filter(x=>x.id!==pid&&ortakIds.has(x.id));
    if(!secenek.length)return toast("Ortak MV listesi için önce ittifak ortağın olmalı.",true);
    const ana=ps.find(x=>x.id===pid);
    const iller=[...VERI.iller].sort((a,b)=>a.ad.localeCompare(b.ad,"tr"));
    const m=modal('<h3>Ortak milletvekili listesi</h3><p class="alt">Seçilen ilde iki partinin oyları ortak listeye yazılır. Adaylar kendi partilerinde kalır. Teklif sandık açılmadan iki genel başkan tarafından onaylanmalıdır.</p>'
      +'<div class="alan"><label>İttifak ortağı</label><select id="mlOrtak">'+secenek.map(x=>'<option value="'+x.id+'">'+e(x.ad)+'</option>').join("")+'</select></div>'
      +'<div class="alan"><label>İl</label><select id="mlIl">'+iller.map(x=>'<option value="'+x.id+'">'+e(x.ad)+'</option>').join("")+'</select></div>'
      +'<div class="alan"><label>Ortak liste kimin adıyla yarışsın?</label><select id="mlLider"></select></div>'
      +'<button class="btn altin" id="mlGonder">Ortak liste teklif et</button>');
    const reset=()=>{
      const ortak=secenek.find(x=>x.id===Number(document.getElementById("mlOrtak").value));
      document.getElementById("mlLider").innerHTML='<option value="'+pid+'">'+e(ana?.kisa||"Benim partim")+'</option><option value="'+ortak.id+'">'+e(ortak.kisa)+'</option>';
    };
    document.getElementById("mlOrtak").onchange=reset;reset();
    document.getElementById("mlGonder").onclick=async()=>{
      const btn=document.getElementById("mlGonder");btn.disabled=true;
      try{
        await API.rpc("mv_ortak_liste_teklif",{p_ortak:Number(document.getElementById("mlOrtak").value),p_lider:Number(document.getElementById("mlLider").value),p_il:Number(document.getElementById("mlIl").value)});
        modalKapat();toast("Ortak liste teklifin iletildi.");partiDetay(pid);
      }catch(err){btn.disabled=false;toast(hataCevir(err.message),true);}
    };
  }catch(err){toast(hataCevir(err.message),true);}
}
async function mvOrtakListeYanit(pid,id,kabul){
  if(kabul&&!await onayla("Ortak listeyi kabul et","Bu ilde iki partinin oyları ortak hesaplanacak. Seçilecek milletvekilleri kendi partilerinde kalacak.","Kabul et"))return;
  try{await API.rpc("mv_ortak_liste_yanit",{p_id:id,p_kabul:kabul});toast(kabul?"Ortak liste kabul edildi.":"Ortak liste reddedildi.");partiDetay(pid);}
  catch(err){toast(hataCevir(err.message),true);}
}
async function mvOrtakListeIptal(pid,id){
  try{await API.rpc("mv_ortak_liste_iptal",{p_id:id});toast("Ortak liste teklifin geri çekildi.");partiDetay(pid);}
  catch(err){toast(hataCevir(err.message),true);}
}

async function mvOrtakListePusulaBilgi(s){
  if(!s||s.tur!=="mv"||!s.benim_il)return;
  try {
    const listeler=await API.rpc("mv_ortak_liste_gorunum",{p_secim:s.id,p_il:s.benim_il});
    (s.secenekler||[]).forEach(x=>{
      const m=(listeler||[]).find(z=>x.parti_id===z.parti1||x.parti_id===z.parti2);
      if(m)x.ortak_liste=m.ortaklar;
    });
  } catch(err){ /* Oylama yeni RPC devreye girmese de çalışır. */ }
}
