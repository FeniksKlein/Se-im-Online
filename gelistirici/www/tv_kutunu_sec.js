/* Seçim Online TV · Kutunu Seç. Gerçek DOM/CSS oyun ekranı, sadece sunucuya bağlı RPC. */
(function () {
 "use strict";
 if (window.SO_TV_KUTU) return;
 const R = (fn, params) => API.rpc(fn, params);
 const money = x => (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
 const esc = v => String(v == null ? "" : v).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
 const $ = id => document.getElementById(id);
 let timer = null, polling = false, active = 0, last = "", pending = false;
 const vals = [0,100,250,500,1000,1500,2000,3000,5000,7500,10000,12500,15000,20000,30000,50000];
 function cssOnce() {
  if ($("tvks-css")) return;
  const style = document.createElement("style"); style.id = "tvks-css";
  style.textContent = [
   ".tvks{margin:12px 0 18px;color:#f4f6ff;font:15px/1.45 system-ui,-apple-system,sans-serif;--kg:#ffd77c;--kl:#f6b949;--kd:#101d3b}",
   ".tvks *{box-sizing:border-box}.tvks-shell{overflow:hidden;border-radius:20px;border:1px solid #d99c42;box-shadow:0 8px 34px #0009,0 0 0 2px #182d5b;background:radial-gradient(ellipse at 50% 10%,#294781 0,#101d3e 40%,#080f23 100%)}",
   ".tvks-head{padding:19px 16px 14px;background:linear-gradient(180deg,#1f3562,#101b34);text-align:center;border-bottom:2px solid #a87533;position:relative}",
   ".tvks-head:before{content:'◆';position:absolute;top:8px;left:16px;color:#c78b37}.tvks-head:after{content:'◆';position:absolute;top:8px;right:16px;color:#c78b37}",
   ".tvks-brand{font-size:clamp(25px,6vw,40px);font-weight:1000;letter-spacing:.065em;color:#ffe29a;text-shadow:0 2px 0 #7a451e,0 0 24px #e8a33b88}",
   ".tvks-sub{font-size:12px;letter-spacing:.09em;color:#c9d7ee;text-transform:uppercase;margin-top:3px}",
   ".tvks-live{display:inline-flex;align-items:center;gap:6px;color:#fff;background:#be2733;border-radius:99px;font-size:11px;font-weight:900;padding:5px 10px;vertical-align:6px;margin-left:9px;letter-spacing:.03em}",
   ".tvks-layout{display:grid;grid-template-columns:minmax(0,1fr) minmax(145px,215px);gap:13px;padding:14px;min-width:0}",
   ".tvks-briefs{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px 8px;padding:16px 8px 13px;background:linear-gradient(180deg,#1b315a70,#12234755);border-radius:14px;box-shadow:inset 0 -9px 30px #0005}",
   ".tvks-box{position:relative;min-width:0;min-height:72px;border-radius:9px;border:2px solid #e7b558;background:linear-gradient(145deg,#ffebac 0%,#a36c22 19%,#f6cc72 42%,#8a4f16 69%,#cf902e 100%);box-shadow:inset 0 2px 1px #ffe9aa,inset 0 -8px 12px #6b3a1c88,0 5px 10px #000a;color:#1d1730;font-weight:1000;font-size:20px;text-align:center;display:flex;align-items:center;justify-content:center;cursor:pointer;transition:transform .16s,box-shadow .16s;overflow:visible}",
   ".tvks-box:before{content:'';position:absolute;height:9px;width:40%;top:-12px;left:30%;border:3px solid #e7ad4c;border-bottom:0;border-radius:6px 6px 0 0;background:#80501a}",
   ".tvks-box .tvks-boxno{display:grid;place-items:center;border:1px solid #eecc75;border-radius:6px;color:#f9f0d1;background:linear-gradient(#1f335d,#0a1227);min-width:42%;padding:4px 3px;text-shadow:0 1px 2px #000}",
   ".tvks-box:disabled{cursor:default}.tvks-box:enabled:active{transform:scale(.96)}.tvks-box.mine{border-color:#ff545f;box-shadow:0 0 20px #fa3b4a99,0 5px 12px #0009;background:linear-gradient(145deg,#fc8588,#a72034 70%,#6c1426)}",
   ".tvks-box.opened{background:linear-gradient(#132449,#071225);border-color:#4b6d97;box-shadow:inset 0 2px 16px #0007;color:#ffe0a0;font-size:clamp(10px,2.7vw,15px)}.tvks-box.opened .tvks-boxno{display:block;font-size:10px;color:#adbee0;margin-right:3px;min-width:auto;padding:2px 3px}",
   ".tvks-box.winner{animation:tvks-glow 1.25s ease-in-out infinite alternate}.tvks-box.winner .tvks-boxno{font-size:14px}",
   "@keyframes tvks-glow{from{box-shadow:0 0 10px #efac36,inset 0 2px 1px #ffe9aa}to{box-shadow:0 0 38px #ffc954,inset 0 2px 1px #ffe9aa}}",
   ".tvks-side{border:1px solid #977441;background:#0b142bcc;border-radius:12px;padding:10px;min-width:0}",
   ".tvks-side h3{font-size:12px;letter-spacing:.05em;text-transform:uppercase;color:#ffe3a0;margin:0 0 8px;text-align:center}",
   ".tvks-prizes{display:grid;grid-template-columns:1fr;gap:4px;max-height:365px;overflow:auto;scrollbar-width:thin}.tvks-prize{padding:5px 7px;border-radius:6px;font-size:12px;font-weight:800;color:#fff;border:1px solid #334769;text-align:center;background:#18284a}",
   ".tvks-prize.lost{opacity:.30;text-decoration:line-through}.tvks-prize.high{color:#161e2f;background:linear-gradient(130deg,#fff0ac,#c38c33);border-color:#ffda86}",
   ".tvks-note{color:#c6d4eb;font-size:12px;text-align:center;padding:7px 10px}.tvks-round{display:flex;flex-wrap:wrap;justify-content:center;align-items:center;gap:7px;padding:8px 9px;font-size:13px;color:#c5d4f5}",
   ".tvks-tag{border:1px solid #bd8e44;border-radius:99px;background:#39291d;color:#ffe2a0;padding:5px 11px;font-weight:800;white-space:normal}",
   ".tvks-card{margin:0 14px 14px;border:1px solid #d2a24e;border-radius:14px;padding:15px;background:linear-gradient(140deg,#16254e,#0b1328);box-shadow:inset 0 0 26px #0a1235}",
   ".tvks-card h3{color:#ffdf94;margin:0 0 8px;font-size:17px}.tvks-card p{margin:5px 0;color:#d0dbf0}",
   ".tvks-controls{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}.tvks-btn{border-radius:12px;min-height:46px;padding:10px 16px;cursor:pointer;font-size:16px;font-weight:900;flex:1;min-width:120px;background:linear-gradient(#ffe9a6,#c7902e);border:1px solid #ffd67b;color:#191a30;box-shadow:0 2px 0 #764a20}",
   ".tvks-btn.green{background:linear-gradient(#b5ffd4,#209659);border-color:#76ffc2;color:#0b2019}.tvks-btn.red{background:linear-gradient(#ff9da3,#b93042);border-color:#f97683;color:white}.tvks-btn:disabled{opacity:.52;cursor:not-allowed}",
   ".tvks-offer{font-size:clamp(28px,7vw,43px);font-weight:1000;color:#ffe9a5;text-shadow:0 0 22px #f3a54199;text-align:center;padding:4px}",
   ".tvks-winner{font-size:clamp(30px,7vw,48px);font-weight:1000;text-align:center;color:#fff0b9;text-shadow:0 0 22px #ffd466}",
   ".tvks-applicants{font-size:12px;color:#9fb4d7;overflow-wrap:anywhere}.tvks-sm{font-size:12px;color:#a6badd}.tvks-end{background:linear-gradient(135deg,#503211,#94571b 48%,#312653);text-align:center;padding:14px;border:1px solid #eabc69;border-radius:13px}",
   ".tvks-broadcast{width:100%;min-height:170px;padding:13px;background:radial-gradient(ellipse at 50% 20%,#365483,#0d1830 75%);display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center;border-radius:10px}",
   ".tvks-broadcast b{color:#ffdf91;font-size:clamp(20px,5vw,30px);font-weight:1000;text-shadow:0 0 12px #edaa3999}.tvks-broadcast small{font-size:12px;color:#d5e0f6}",
   ".tvks-mini-boxes{display:grid;grid-template-columns:repeat(8,minmax(0,1fr));gap:4px;width:min(100%,340px);margin:12px auto 4px}",
   ".tvks-mini-box{font-size:11px;min-width:0;border:1px solid #e2aa4e;border-radius:5px;color:#ffdfa5;background:linear-gradient(130deg,#81501f,#443015);padding:5px 0;font-weight:900}",
   ".tvks-mini-box.out{opacity:.25;text-decoration:line-through}.tvks-mini-box.picked{background:#a92937;color:white;box-shadow:0 0 11px #fb4250}",
   "@media(max-width:570px){.tvks-layout{grid-template-columns:minmax(0,1fr);gap:8px;padding:10px}.tvks-prizes{grid-template-columns:repeat(4,minmax(0,1fr));max-height:none}.tvks-prize{font-size:10px;padding:5px 2px}.tvks-side{padding:8px}.tvks-box{min-height:59px;font-size:17px}.tvks-box.opened{font-size:11px;flex-wrap:wrap}.tvks-box.opened .tvks-boxno{font-size:9px}.tvks-card{margin:0 10px 10px;padding:12px}.tvks-controls{gap:8px}.tvks-btn{width:100%;min-width:0}.tvks-briefs{gap:15px 7px}}"
  ].join("\n");
  document.head.appendChild(style);
 }
 function statusText(d) {
   const names={basvuru:"Yarışmacı başvuruları",secim:"Yarışmacı kendi kutusunu seçiyor",acilis:"Kutular açılıyor",teklif:"Bankacı teklifi",final:"Büyük final",bitti:"Yarışma tamamlandı",iptal:"Yarışma iptal edildi"};
   return names[d.durum] || "Kutunu Seç";
 }
 function board(d) {
   const canAct=!!d.benim_siram && d.program_durum==="canli";
   return (d.kutular||[]).map(box=>{
    let opened=!!box.acik, mine=!!box.benim, revealed=box.tutar!==null && box.tutar!==undefined;
    let act = canAct && ((d.durum==="secim" && !mine) || (d.durum==="acilis" && !opened && !mine));
    let cls="tvks-box"+(opened?" opened":"")+(mine?" mine":"")+(d.durum==="bitti"&&mine?" winner":"");
    let val=opened||revealed?money(box.tutar):String(box.no);
    return '<button type="button" class="'+cls+'"'+(act?' onclick="SO_TV_KUTU.box('+Number(box.no)+')"':" disabled")+' aria-label="'+esc("Kutu "+box.no+(opened?", "+val:mine?", seçtiğin kutu":""))+'">'+
     (opened||revealed?'<span class="tvks-boxno">'+Number(box.no)+'</span>':'')+'<span>'+esc(val)+'</span></button>';
   }).join("");
 }
 function scene(program) {
  let d=null;try{const obj=last?JSON.parse(last):null;if(obj&&Number(obj.program)===Number(program.id))d=obj;}catch(_){}
  const boxes=(d&&d.kutular||Array.from({length:16},(_,i)=>({no:i+1}))).map(b=>
    '<span class="tvks-mini-box'+(b.acik?' out':'')+(b.benim?' picked':'')+'">'+Number(b.no)+'</span>').join("");
  const durum=d?statusText(d):(program.durum==="planli"?"Yayın öncesi":"Kutular hazırlanıyor");
  const m=d&&d.durum==="teklif"?' · BANKACI: '+money(d.teklif):d&&d.durum==="bitti"?' · KAZANÇ: '+money(d.odenen):"";
  return '<div class="tvks-broadcast"><b>🧳 KUTUNU SEÇ</b><small>'+esc(durum+m)+'</small>'+
   '<div class="tvks-mini-boxes">'+boxes+'</div><small>50.000 ₺ büyük ödül · otomatik bankacı · canlı yarışma</small></div>';
 }
 function content(d) {
   const cur=new Set((d.kalan_oduller||[]).map(Number));
   const side=vals.slice().reverse().map(v=>'<div class="tvks-prize '+(!cur.has(v)?"lost":v===50000?"high":"")+'">'+esc(money(v))+'</div>').join("");
   const state=statusText(d); const action=d.benim_siram;
   const header='<div class="tvks-head"><div class="tvks-brand">▣ KUTUNU SEÇ <span class="tvks-live">'+(d.program_durum==="canli"?"● CANLI":d.program_durum==="planli"?"YAKINDA":"SONUÇ")+'</span></div><div class="tvks-sub">'+esc(d.kanal)+' · 16 KUTU · BÜYÜK ÖDÜL 50.000 ₺</div></div>';
   let info='<div class="tvks-round"><span class="tvks-tag">'+esc(state)+'</span><span>'+esc(d.yarismaci?"Yarışmacı: "+d.yarismaci:"Yarışmacı henüz seçilmedi")+'</span><span>🧳 Açılan: '+Number(d.acilan_sayi)+'/14</span></div>';
   let panel='';
   if(d.durum==="basvuru"){
      panel='<h3>🎙️ Yarışmacı başvuruları</h3><p>Başvurular arasından sistem bir yarışmacı seçecek. Başvuru ücretsizdir; kutuların değerlerini kimse değiştiremez.</p>'+
      '<p><b>'+Number(d.basvuru_sayisi)+'</b> başvuru · başlangıç: '+esc(new Date(d.bas).toLocaleString("tr-TR",{day:"2-digit",month:"2-digit",hour:"2-digit",minute:"2-digit"}))+'</p>'+
      '<p class="tvks-applicants">'+(d.basvurular||[]).map(esc).join(" · ")+'</p><div class="tvks-controls">'+
      (!d.basvurdum&&d.uygun?'<button class="tvks-btn" onclick="SO_TV_KUTU.apply()">Başvur</button>':d.basvurdum?'<p>✓ Başvurun kayıtlı.</p>':'<p class="tvks-sm">Katılım: 7 günlük hesap, uygun ödül geçmişi ve kanal ekibinden bağımsızlık.</p>')+
      (d.yonetici&&d.program_durum==="canli"?'<button class="tvks-btn green" onclick="SO_TV_KUTU.start()"'+(Number(d.basvuru_sayisi)<5?' disabled':'')+'>Yarışmacıyı rastgele seç</button>':"")+'</div>';
   }else if(d.durum==="secim"){
     panel='<h3>🎁 Önce kendi kutunu seç</h3><p>'+esc(d.yarismaci||"Yarışmacı")+' 1 ile 16 arasında bir kutu seçiyor. Bu kutu final için kapalı kalacak.</p>'+
        (action?'<p>Altın kutulardan birine dokun.</p>':'<p>Yarışmacının kararını bekliyoruz.</p>');
   }else if(d.durum==="acilis"){
     const n=Number(d.acilan_sayi);
     const next = n<5?5:n<9?9:n<12?12:14;
     panel='<h3>📦 Kutuları açma turu</h3><p>Seçilen kutu <b>'+Number(d.secilen)+'</b> · Şimdi diğer kutulardan birini aç.</p>'+
       '<p>Bankacının sonraki teklifi için bu turda <b>'+(next-n)+'</b> kutu daha açılacak.</p>'+
       (action?'<p>Kutunun numarasına dokunarak açabilirsin.</p>':'<p>Yarışmacının kutu açmasını izliyorsun.</p>');
   }else if(d.durum==="teklif"){
     panel='<h3>📞 Bankacı arıyor!</h3><p>Kalan kapalı kutuların beklenen değerinden sunucuda hesaplanmış resmi teklif:</p>'+
       '<div class="tvks-offer">'+esc(money(d.teklif))+'</div><p>Teklifi kabul edersen yarışma biter; devam edersen sıradaki kutular açılır.</p>'+
       (action?'<div class="tvks-controls"><button class="tvks-btn green" onclick="SO_TV_KUTU.play(\'kabul\')">✓ Teklifi kabul et</button>'+
        '<button class="tvks-btn red" onclick="SO_TV_KUTU.play(\'devam\')">➜ Devam et</button></div>':'<p>Yarışmacının kararını bekliyoruz.</p>');
   }else if(d.durum==="final"){
     panel='<h3>🏆 Son iki kutu!</h3><p>Seçtiğin <b>'+Number(d.secilen)+'. kutu</b> kapalı kaldı. Kendi kutunu tutabilir veya diğer kapalı kutuyla değiştirebilirsin.</p>'+
      (action?'<div class="tvks-controls"><button class="tvks-btn green" onclick="SO_TV_KUTU.play(\'tut\')">Kendi kutumu tut</button>'+
       '<button class="tvks-btn red" onclick="SO_TV_KUTU.play(\'degistir\')">Kutumu değiştir</button></div>':'<p>Final kararını yarışmacı verecek.</p>');
   }else if(d.durum==="bitti"){
     panel='<div class="tvks-end"><h3>✨ KAZANDINIZ! ✨</h3><div class="tvks-winner">'+esc(money(d.odenen))+'</div>'+
       '<p>Sonuçlanan oyun ödülü: '+esc(money(d.asil_odul))+' · Kanala iade: '+esc(money(d.iade))+'</p>'+
       '<p>Ödül işlemi sunucuda tamamlandı ve kayda alındı.</p></div>';
   }else{
     panel='<h3>Yarışma kapandı</h3><p>Oynanmayan yarışmanın ödül teminatı kanal kasasına iade edildi.</p>';
   }
   return '<div class="tvks-shell">'+header+info+'<div class="tvks-layout"><div class="tvks-briefs">'+board(d)+'</div>'+
   '<aside class="tvks-side"><h3>💰 Kalan ödüller</h3><div class="tvks-prizes">'+side+'</div></aside></div>'+
   '<div class="tvks-card">'+panel+'</div><div class="tvks-note">Oyun parasıyla oynanır. Sunucu ve kanal sahibi sonucu, kutu tutarlarını veya bankacının teklifini değiştiremez.</div></div>';
 }
 async function refresh(id, force) {
  const root=$("tvKutuK");
  if(!root || active!==Number(id) || root.dataset.program!==String(id) || document.hidden || polling) return;
  polling=true;
  try{
   const d=await R("tv_kutu_durum",{p_program:Number(id)});
   if(active!==Number(id)||!$("tvKutuK")) return;
   const signature=JSON.stringify(d);
   if(force||last!==signature){
    last=signature;$("tvKutuK").innerHTML=content(d);
    const tv=$("tvSahne");if(tv && $("tvKutuK") && active===Number(id))tv.innerHTML=scene({id:id,durum:d.program_durum});
   }
  }catch(err){if($("tvKutuK")) $("tvKutuK").innerHTML='<div class="tvks-card">Kutunu Seç verisi alınamadı: '+esc(err&&err.message||"Sunucu hatası")+'</div>';}
  finally{polling=false;}
 }
 async function act(fn,args) {
  if(pending || !active) return; pending=true;
  try{
   await R(fn,args);await refresh(active,true);
   if(window._tvTaz) window._tvTaz().catch(()=>{});
  }catch(err){if(typeof toast==="function")toast(String(err&&err.message||"İşlem başarısız"),true);}
  finally{pending=false;}
 }
 const api={
  mount(id){
   id=Number(id); const root=$("tvKutuK"); if(!root)return;
   cssOnce();active=id;last="";polling=false;root.dataset.program=String(id);
   root.innerHTML='<div class="tvks-card">🧳 Kutunu Seç sahnesi hazırlanıyor…</div>';
   if(timer)clearInterval(timer);
   refresh(id,true);
   timer=setInterval(()=>{if(!$("tvKutuK")||$("tvKutuK").dataset.program!==String(id)){clearInterval(timer);timer=null;return;}refresh(id,false)},5000);
  },
  apply(){return act("tv_kutu_basvur",{p_program:active});},
  start(){return act("tv_kutu_baslat",{p_program:active});},
  box(no){return act("tv_kutu_oyna",{p_program:active,p_islem:(last&&JSON.parse(last).durum==="secim")?"sec":"ac",p_kutu:Number(no)});},
  play(code){return act("tv_kutu_oyna",{p_program:active,p_islem:code,p_kutu:null});},
  refresh(){return refresh(active,true);},
  scene:scene
 };
 window.SO_TV_KUTU=api;
})();