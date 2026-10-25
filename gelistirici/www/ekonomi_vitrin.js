/* Ekonomi merkezi: banka ve şirket rehberleri */
"use strict";
const vitTL=x=>tlYaz(Number(x)||0);
const vitSektor={tarim:"Tarım",sanayi:"Sanayi",teknoloji:"Teknoloji",ticaret:"Ticaret",insaat:"İnşaat",medya:"Medya",banka:"Banka"};
let vitSirketler=[];

/* Mobil Sube gorunumuyle uyumlu, her bankacilik ekraninda ortak premium arayuz. */
function vitPremiumStyle(){
 if(document.getElementById("vit-premium-css"))return;
 const s=document.createElement("style");s.id="vit-premium-css";s.textContent=`
.vit-premium{--vp-green:#87dbc8;--vp-border:rgba(169,195,255,.19);--vp-panel:#172345;min-width:0;padding:1px 1px 18px}
.vit-premium *{box-sizing:border-box}
.vit-premium .vit-hero{background:linear-gradient(130deg,#173e52 0%,#1b385b 57%,#292f5b 100%);border:1px solid rgba(133,202,208,.38);border-radius:22px;padding:20px 18px 18px;position:relative;overflow:hidden;box-shadow:0 18px 28px -22px #000}
.vit-premium .vit-hero:after{content:"";position:absolute;width:195px;height:195px;border-radius:50%;right:-52px;top:-70px;background:radial-gradient(circle,rgba(114,222,202,.2),transparent 68%);pointer-events:none}
.vit-premium .vit-hero>*{position:relative;z-index:1}
.vit-premium .vit-eyebrow{text-transform:uppercase;letter-spacing:1.5px;font-size:10px;font-weight:900;color:#b0f0e5;display:flex;align-items:center;gap:7px}
.vit-premium .vit-hero h2{font-family:var(--disp),sans-serif;font-size:clamp(26px,6vw,34px);line-height:1.04;margin:10px 0 8px;letter-spacing:-.3px;color:#fff}
.vit-premium .vit-hero p{color:#cfdfec;line-height:1.5;font-size:13px}
.vit-premium .vit-hero-actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;margin-top:15px}
.vit-premium .vit-hero-actions button{min-height:46px;padding:9px 10px;border-radius:13px;background:#9cebd7;border:1px solid #bdf5e9;color:#15313e;font-size:13px;font-weight:800}
.vit-premium .vit-hero-actions button+button{background:rgba(255,255,255,.11);border:1px solid rgba(216,243,255,.38);color:#f6ffff}
.vit-premium .vit-ticker{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;margin:12px 0 14px}
.vit-premium .vit-ticker>div{background:var(--panel,#172344);border:1px solid var(--vp-border);border-radius:16px;padding:14px 13px}
.vit-premium .vit-ticker strong{display:block;font-family:var(--disp),sans-serif;font-size:25px;line-height:1.2;font-variant-numeric:tabular-nums}
.vit-premium .vit-ticker small{color:var(--txt2,#abb9d3);font-size:11.5px}
.vit-premium .vit-list-title{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:20px 2px 11px}
.vit-premium .vit-list-title h3{font-size:17px;font-weight:800}
.vit-premium .vit-list-title span{color:var(--txt2,#aebcd2);font-size:11px;text-align:right}
.vit-premium .vit-bank-card{display:block;width:100%;text-align:left;padding:16px;border-radius:20px;border:1px solid var(--vp-border);background:linear-gradient(130deg,#202c54,#182342);color:var(--txt,#f8faff);margin-bottom:11px;box-shadow:0 10px 28px -21px #000;position:relative;overflow:hidden}
.vit-premium .vit-bank-card::before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--vp-accent,#79d7bf);opacity:.85}
.vit-premium .vit-bank-card:active{transform:scale(.991);border-color:var(--vp-accent,#79d7bf)}
.vit-premium .vit-bank-top{display:flex;align-items:center;gap:12px}
.vit-premium .vit-bank-icon{width:48px;height:48px;border-radius:14px;display:grid;place-items:center;flex:0 0 48px;background:linear-gradient(135deg,var(--vp-accent,#5c80d6),#13233e);font-size:25px;box-shadow:inset 0 1px 0 #ffffff2e}
.vit-premium .vit-bank-name{flex:1;min-width:0}
.vit-premium .vit-bank-name b{font-family:var(--disp),sans-serif;font-size:21px;line-height:1.1;display:block}
.vit-premium .vit-bank-name small{display:block;color:var(--txt2,#aebad0);margin-top:5px;font-size:11.5px;line-height:1.4}
.vit-premium .vit-bank-chevron{font-size:25px;color:#cad8f5}
.vit-premium .vit-bank-stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px;margin-top:14px}
.vit-premium .vit-bank-stats>span{min-width:0;background:#0c1530a8;border:1px solid #ffffff0e;border-radius:12px;padding:10px 8px}
.vit-premium .vit-bank-stats small{display:block;font-size:10px;line-height:1.35;color:#b5c2d7}
.vit-premium .vit-bank-stats b{display:block;font-variant-numeric:tabular-nums;font-size:15px;margin-top:4px}
.vit-premium .vit-note{font-size:12px;line-height:1.5;color:var(--txt2,#afbed6);margin:12px 3px}
.vit-premium .vit-brand{border-radius:21px;padding:19px 16px 17px;background:linear-gradient(135deg,var(--vp-a,#294783),var(--vp-b,#192344));border:1px solid #ffffff30;box-shadow:0 14px 28px -20px #000;overflow:hidden;position:relative}
.vit-premium .vit-brand:after{content:"";position:absolute;width:220px;height:220px;border:1px solid #ffffff19;border-radius:50%;right:-85px;top:-95px;box-shadow:0 0 0 25px #ffffff06,0 0 0 52px #ffffff05;pointer-events:none}
.vit-premium .vit-brand>*{position:relative;z-index:1}
.vit-premium .vit-brand-head{display:flex;align-items:center;gap:12px}
.vit-premium .vit-brand-head h2{font-family:var(--disp),sans-serif;font-size:clamp(24px,6vw,34px);line-height:1.05;color:#fff}
.vit-premium .vit-brand small{color:#d7e6ff;font-size:11px}
.vit-premium .vit-brand-kpis{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px;margin-top:18px}
.vit-premium .vit-brand-kpis div{padding:12px 10px;border-radius:12px;background:rgba(3,12,29,.25);border:1px solid #ffffff1d}
.vit-premium .vit-brand-kpis b{display:block;font-variant-numeric:tabular-nums;font-size:18px;line-height:1.25;margin-top:4px;color:#fff;overflow-wrap:anywhere}
.vit-premium .vit-sekme{display:flex;overflow-x:auto;overscroll-behavior-x:contain;-webkit-overflow-scrolling:touch;gap:8px;padding:13px 2px 12px;margin:0 -2px 9px;scrollbar-width:none;position:sticky;top:0;z-index:4;background:var(--bg,#0e1530)}
.vit-premium .vit-sekme::-webkit-scrollbar{display:none}
.vit-premium .vit-sekme button{flex:0 0 auto;min-height:40px;padding:10px 14px;border-radius:24px;border:1px solid #ffffff0b;background:var(--panel,#182343);font-size:13px;font-weight:800;white-space:nowrap;color:#becbe0}
.vit-premium .vit-sekme button[aria-selected="true"]{background:#f3f5ff;color:#101831;border-color:#fff}
.vit-premium .vit-bank-pane[hidden]{display:none!important}
.vit-premium .vit-pane-card{border-radius:17px;background:linear-gradient(140deg,#1a284c,#161e3a);border:1px solid var(--vp-border);padding:16px;margin:0 0 12px;min-width:0}
.vit-premium .vit-pane-card h3{font-family:var(--disp),sans-serif;font-size:21px;line-height:1.2;margin-bottom:6px}
.vit-premium .vit-pane-card p{color:var(--txt2,#afbdd5);font-size:12px;margin-bottom:12px;line-height:1.5}
.vit-premium .vit-actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}
.vit-premium .vit-action{min-width:0;text-align:left;padding:13px 11px;border:1px solid #a0b1e23b;background:#243158;color:#fff;border-radius:14px;min-height:92px}
.vit-premium .vit-action em{display:grid;place-items:center;width:32px;height:32px;background:#948bdb2b;color:#dfdcff;border-radius:9px;margin-bottom:7px;font-size:19px;font-style:normal}
.vit-premium .vit-action b{display:block;font-size:12.5px}
.vit-premium .vit-action small{display:block;font-size:10px;color:#b8c7e0;margin-top:4px}
.vit-premium .vit-rate-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:12px 0}
.vit-premium .vit-rate-grid>div{border-radius:12px;background:#0c1631a6;border:1px solid #ffffff14;padding:11px 8px}
.vit-premium .vit-rate-grid small{display:block;color:#bdc9db;font-size:10px}
.vit-premium .vit-rate-grid strong{display:block;font-size:17px;margin-top:4px;font-variant-numeric:tabular-nums}
.vit-premium .vit-pane-card .alan{margin-bottom:12px}
.vit-premium .vit-pane-card label{display:block;color:#c6d0e6;font-size:12.5px;font-weight:650;margin:0 0 6px}
.vit-premium .vit-pane-card input,.vit-premium .vit-pane-card select{display:block;width:100%;min-height:48px;padding:11px 13px;border:1px solid #7284ae55;background:#0c142f;border-radius:12px;font-size:16px;color:#f9faff}
.vit-premium .vit-pane-card .btn{display:block;width:100%;min-height:45px;margin:9px 0 0;border-radius:12px;font-size:13.5px;font-weight:800}
.vit-premium .vit-pane-card .btn.altin{background:linear-gradient(120deg,#80dcc8,#b5f1e3);color:#122b38;border:1px solid #b4f4e4}
.vit-premium .vit-pane-card .btn:disabled{opacity:.48}
.vit-premium .vit-mini-line{display:flex;justify-content:space-between;gap:8px;border-top:1px solid #ffffff19;padding:11px 0}
.vit-premium .vit-mini-line b{font-variant-numeric:tabular-nums;text-align:right}
.vit-premium .vit-inline-cta{width:100%;min-height:44px;border-radius:12px;background:#26365f;border:1px solid #849be84a;color:#f4f6ff;font-weight:800;margin:7px 0}
.vit-premium .vit-portfolio-cta{width:100%;min-height:48px;border-radius:13px;border:1px solid #5b8b9e;background:#1c3949;color:#e7fff9;font-weight:800;margin:4px 0 12px}
@media(max-width:365px){.vit-premium .vit-bank-stats b{font-size:13px}.vit-premium .vit-rate-grid strong{font-size:14px}.vit-premium .vit-hero-actions button{font-size:12px}.vit-premium .vit-brand-kpis b{font-size:15px}}
@media(min-width:700px){.vit-premium .vit-bank-stats{grid-template-columns:repeat(3,minmax(0,1fr))}.vit-premium .vit-actions{grid-template-columns:repeat(4,minmax(0,1fr))}}
`;
 document.head.appendChild(s);
}
function vitBankSekme(tab){
 const root=document.getElementById("vit-bank-screen");if(!root)return;
 root.querySelectorAll(".vit-bank-pane").forEach(function(x){x.hidden=x.getAttribute("data-vit-tab")!==tab;});
 root.querySelectorAll(".vit-sekme button").forEach(function(x){x.setAttribute("aria-selected",String(x.getAttribute("data-tab")===tab));});
}
window.vitBankSekme=vitBankSekme;
function vitBankRenk(id){
 var colors=[["#3253a5","#121e49"],["#096c74","#143051"],["#6841ae","#262350"],["#875b2c","#2a294e"]];
 return colors[Math.abs(Number(id)||0)%colors.length];
}
function vitAction(icon,title,detail,onclick){
 return '<button type="button" class="vit-action" onclick="'+onclick+'"><em aria-hidden="true">'+icon+'</em><b>'+title+'</b>'+(detail?'<small>'+detail+'</small>':'')+'</button>';
}
function vitBankRate(b,h){
 return '<div><small>'+oybVadeEtiket(h)+'</small><strong>%'+fmt(oybVadeOrani(b,h),2)+'</strong></div>';
}

async function bankaRehberiEkrani(){
 yukleniyor("Oyuncu bankaları");
 try{
  const result=await Promise.all([API.rpc("oyb_liste"),API.rpc("oyb_portfoy")]),d=result[0]||{},p=result[1]||{};
  const list=(d.bankalar||[]).slice().sort((a,b)=>Number(b.kasa||0)-Number(a.kasa||0));
  vitPremiumStyle();
  var html='<div class="vit-premium vit-bank-market">'
    +'<header class="vit-hero"><span class="vit-eyebrow">✧ FİNANS MERKEZİ · BANKALAR</span>'
    +'<h2>Bankanı seç,<br>paranı yönet.</h2><p>Tüm bankaların vadelerini ve kredi oranlarını karşılaştır. Her bankanın yönetimi ve kasası birbirinden bağımsızdır.</p>'
    +'<div class="vit-hero-actions">'
    +'<button type="button" onclick="ekranAc(mobilSubeEkrani)">◈ Mobil Şube</button>'
    +'<button type="button" onclick="bankaKurEkrani()">＋ Banka kur</button></div></header>'
    +'<div class="vit-ticker"><div><strong>'+list.length+'</strong><small>Oyuncu bankası</small></div>'
    +'<div><strong>'+(p.mevduatlar||[]).filter(x=>!x.kapandi).length+'</strong><small>Açık mevduatım</small></div></div>'
    +'<div class="vit-list-title"><h3>Bankaları keşfet</h3><span>Oranları karşılaştır</span></div>';
  html+=list.map(function(b){
    const c=vitBankRenk(b.id);
    return '<button type="button" class="vit-bank-card" style="--vp-accent:'+c[0]+'" onclick="bankaDetayEkrani('+Number(b.id)+')">'
      +'<span class="vit-bank-top"><span class="vit-bank-icon">🏦</span>'
      +'<span class="vit-bank-name"><b>'+e(b.ad)+'</b><small>Kasa: '+vitTL(b.kasa)+(b.bankam?' · <strong style="color:#97e7d0">Ortağısın</strong>':'')+'</small></span>'
      +'<span class="vit-bank-chevron">›</span></span>'
      +'<span class="vit-bank-stats">'
      +'<span><small>1 saat mevduat</small><b>%'+fmt(oybVadeOrani(b,1),2)+'</b></span>'
      +'<span><small>7 gün mevduat</small><b>%'+fmt(oybVadeOrani(b,168),2)+'</b></span>'
      +'<span><small>Kredi / 24 saat</small><b>%'+fmt(b.kredi_faiz,2)+'</b></span>'
      +'</span></button>';
  }).join("")||'<div class="vit-pane-card"><p>Henüz oyuncu bankası bulunmuyor.</p></div>';
  html+='<button type="button" class="vit-portfolio-cta" onclick="ekranAc(function(){return mobilSubeEkrani(\'birikim\')})">📒 Mevduatlarım ve kredi portföyüm</button>'
    +'<button type="button" class="vit-inline-cta" onclick="ekranAc(function(){return mobilSubeEkrani(\'bankalar\')})">Devlet Bankası ve tüm hesap seçenekleri</button>'
    +'<p class="vit-note">Özel banka mevduatlarında devlet garantisi bulunmaz. Bankanın ödeme gücünü incele.</p></div>';
  iskelet("Oyuncu bankaları",html,{geri:true});
 }catch(err){iskelet("Bankalar",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
async function bankaDetayEkrani(id){
 yukleniyor("Banka şubesi");
 try{
  id=Number(id);
  const result=await Promise.all([API.rpc("oyb_liste"),API.rpc("oyb_urunler",{p_banka:id})]),d=result[0]||{},ur=result[1]||{};
  window.BK_BANKA_URUN=window.BK_BANKA_URUN||{};
  window.BK_BANKA_URUN[id]=ur.urunler||[];
  const b=(d.bankalar||[]).find(x=>Number(x.id)===id);
  if(!b){toast("Banka bulunamadı.",true);bankaRehberiEkrani();return;}
  vitPremiumStyle();
  const c=vitBankRenk(id);
  const bankOwner=!!b.bankam;
  const rateHours=[1,3,6,12,24,168];
  let html='<div class="vit-premium vit-bank-layout" id="vit-bank-screen">'
   +'<header class="vit-brand" style="--vp-a:'+c[0]+';--vp-b:'+c[1]+'">'
   +'<div class="vit-eyebrow">◆ ÖZEL BANKA ŞUBESİ</div>'
   +'<div class="vit-brand-head" style="margin-top:10px"><div class="vit-bank-icon">🏦</div><h2>'+e(b.ad)+'</h2></div>'
   +'<div class="vit-brand-kpis">'
   +'<div><small>Banka kasası</small><b>'+vitTL(b.kasa)+'</b></div>'
   +'<div><small>Kredi faizi / 24 saat</small><b>%'+fmt(b.kredi_faiz,2)+'</b></div>'
   +'<div><small>1 saat mevduat</small><b>%'+fmt(oybVadeOrani(b,1),2)+'</b></div>'
   +'<div><small>7 gün mevduat</small><b>%'+fmt(oybVadeOrani(b,168),2)+'</b></div></div></header>'
   +'<nav class="vit-sekme" aria-label="Banka şubesi sekmeleri" role="tablist">';
  const tabs=[["ozet","Özet"],["mevduat","Mevduat"],["kredi","Krediler"],["basvurular","Başvurular"],["islem","İşlemler"]];
  if(bankOwner)tabs.push(["yonetim","Yönetim"]);
  html+=tabs.map(x=>'<button type="button" role="tab" data-tab="'+x[0]+'" aria-selected="'+(x[0]==="ozet")+'" onclick="vitBankSekme(\''+x[0]+'\')">'+x[1]+'</button>').join("")+'</nav>';
  html+='<section class="vit-bank-pane" data-vit-tab="ozet">'
    +'<div class="vit-pane-card"><h3>Hızlı işlemler</h3><p>Banka işlemlerini tek dokunuşla yönet.</p>'
    +'<div class="vit-actions">'
    +vitAction("📈","Mevduat yatır","Vadeni seç, getiriyi gör","vitBankSekme(\'mevduat\')")
    +vitAction("💳","Kredi kullan","Limit ve ödeme planı","vitBankSekme(\'kredi\')")
    +vitAction("📱","Mobil Şube","Tüm banka hesapların","ekranAc(mobilSubeEkrani)")
    +vitAction("📂","Başvurular","Dosyaların ve izinlerin","vitBankSekme(\'basvurular\')")
    +'</div></div>'
    +'<div class="vit-pane-card"><h3>Mevduat fırsatları</h3><p>Seçtiğin vade için toplam faiz oranı. Yıllık faiz olarak yorumlama.</p>'
    +'<div class="vit-rate-grid">'+[1,24,168].map(h=>vitBankRate(b,h)).join("")+'</div>'
    +'<button class="vit-inline-cta" onclick="vitBankSekme(\'mevduat\')">Tüm vadeler ve getiri hesabı ›</button></div>'
    +'<button class="vit-inline-cta" onclick="bankaRehberiEkrani()">↗ Diğer bankaları karşılaştır</button></section>';
  html+='<section class="vit-bank-pane" data-vit-tab="mevduat" hidden>'
    +'<div class="vit-pane-card"><h3>Vadeli mevduat oranları</h3><p>Faiz oranları seçilen vadenin tamamı için geçerlidir.</p>'
    +'<div class="vit-rate-grid">'+rateHours.map(h=>vitBankRate(b,h)).join("")+'</div></div>'
    +'<div class="vit-pane-card"><h3>Yeni mevduat yatır</h3><p>Getiri ve ödeme gücünü yatırım yapmadan önce incele.</p>'
    +'<div class="alan"><label for="oyb_saat_'+id+'">Vade seç</label>'
    +'<select id="oyb_saat_'+id+'" onchange="oybVadeOnizle('+id+')">'+rateHours.map(h=>'<option value="'+h+'">'+oybVadeEtiket(h)+' · %'+fmt(oybVadeOrani(b,h),2)+'</option>').join("")+'</select></div>'
    +'<div class="alan"><label for="oyb_tutar_'+id+'">Yatırılacak tutar (₺)</label><input id="oyb_tutar_'+id+'" type="number" inputmode="decimal" min="1000" max="10000000" step="1000" value="1000" oninput="oybVadeOnizle('+id+')"></div>'
    +'<p class="vit-note" id="oyb_onizleme_'+id+'">Beklenen getiri ve ödeme gücü hesaplanmadı.</p>'
    +'<button class="btn ikinci" onclick="oyuncuBankaTeklif('+id+')">Getiriyi ve riski hesapla</button>'
    +'<button class="btn altin" '+(bankOwner?"disabled":"")+' onclick="oyuncuBankaYatir('+id+')">Mevduat yatır</button></div></section>';
  html+='<section class="vit-bank-pane" data-vit-tab="kredi" hidden>'
    +'<div class="vit-pane-card"><h3>Kredi seçenekleri</h3><p>Başvurudan önce ödeme takvimini, kredi notunu ve limitini görüntüle.</p>'
    +'<button class="btn altin" onclick="ekranAc(function(){return oybKrediMasasiEkrani('+id+')})">💳 Kredi masasını aç</button></div>'
    +'<div class="vit-pane-card"><h3>Kredi talebi</h3><p>24 saatlik faiz: %'+fmt(b.kredi_faiz,2)+'</p>'
    +'<div class="vit-note" id="oyb_kredi_risk_'+id+'">Limitin gelire, kredi notuna ve borçlarına göre belirlenir.</div>'
    +'<button class="btn ikinci" onclick="oybKrediRiskGoster('+id+')">Kredi notumu ve limitimi gör</button>'
    +'<div class="alan"><label for="oyb_ktutar_'+id+'">Kredi tutarı (₺)</label><input id="oyb_ktutar_'+id+'" type="number" inputmode="decimal" min="1000" max="500000" value="10000"></div>'
    +'<div class="alan"><label for="oyb_ksaat_'+id+'">Kredi vadesi</label>'
    +'<select id="oyb_ksaat_'+id+'" onchange="oybKrediRiskGoster('+id+')">'+(ur.urunler||[]).filter(x=>x.aktif).map(x=>'<option value="'+x.saat+'">'+bkUrunAdi(x.saat)+' · '+x.taksit+' taksit · ek faiz %'+fmt(x.ek_faiz,2)+'</option>').join("")+'</select></div>'
    +'<button class="btn altin" '+(bankOwner?"disabled":"")+' onclick="oybKrediBasvur('+id+')">Kredi talebi gönder</button></div></section>';
  html+='<section class="vit-bank-pane" data-vit-tab="basvurular" hidden>'
    +'<div class="vit-pane-card"><h3>Başvurularım ve finansal izinler</h3><p>Kredilerin, kredi paketlerin, ödeme takvimlerin ve bankanın bilgi talepleri.</p>'
    +'<button class="btn altin" onclick="bankaKrediDosyaEkrani('+id+')">Kredi dosyalarımı aç</button>'
    +'<button class="btn ikinci" onclick="ekranAc(function(){return mobilSubeEkrani(\'krediler\')})">Mobil Şube · Kredilerim</button></div></section>';
  html+='<section class="vit-bank-pane" data-vit-tab="islem" hidden>'
    +'<div class="vit-pane-card"><h3>Bankacılık işlemleri</h3><p>Hesap açma, transfer, kart ve tüm bankacılık işlemleri tek merkezde.</p>'
    +'<div class="vit-actions">'
    +vitAction("➕","Hesap aç","Bankaları incele","ekranAc(function(){return mobilSubeEkrani(\'bankalar\')})")
    +vitAction("↗","Para gönder","Havale / FAST","paraGonderModal()")
    +vitAction("💳","Kartlarım","Borçlar ve limitler","ekranAc(function(){return mobilSubeEkrani(\'kartlar\')})")
    +vitAction("📱","Mobil Şube","Hesaplar ve birikim","ekranAc(mobilSubeEkrani)")
    +'</div></div></section>';
  if(bankOwner)html+='<section class="vit-bank-pane" data-vit-tab="yonetim" hidden>'
    +'<div class="vit-pane-card"><h3>Banka Genel Müdürlüğü</h3><p>Kasa, faiz oranları, müşteriler, kredi ve POS başvuruları, otomatik kararlar.</p>'
    +'<button class="btn altin" onclick="ekranAc(function(){return bankaGenelMudurlukEkrani('+id+')})">🏦 Bankamı yönet</button>'
    +'<button class="btn ikinci" onclick="oybYonetim('+id+')">Klasik banka yönetimi</button></div></section>';
  html+='</div>';
  iskelet(e(b.ad),html,{geri:true});
 }catch(err){iskelet("Banka şubesi",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
async function bankaPortfoyEkrani(){
 yukleniyor("Bankacılık portföyüm");
 try{
 const d=await API.rpc("oyb_portfoy");
 iskelet("Bankacılık portföyüm",`
 <div class="kart"><h2>Mevduatlarım</h2>
 ${(d.mevduatlar||[]).map(x=>`<div class="vit-kayit"><b>${e(x.banka)}</b><div class="kv"><span>Anapara</span><b>${vitTL(x.anapara)}</b></div>
 <div class="kv"><span>Getiri</span><b>${vitTL(x.getiri)}</b></div><div class="kv"><span>Çekim zamanı</span><b>${oybTarih(x.vade)}</b></div>
 <div class="kucuk">${x.kapandi?"Kapatıldı":x.durum==="odeme_bekliyor"?"Ödeme bekleniyor":"Açık"}</div>
 ${!x.kapandi?`<button class="btn ikinci" onclick="oybMevduatCek(${x.id},${x.durum==="aktif"})">Çek</button>`:""}</div>`).join("")||'<p class="alt">Mevduatın yok.</p>'}</div>
 <div class="kart"><h2>Kredilerim</h2>
 ${(d.krediler||[]).map(x=>`<div class="vit-kayit"><b>${e(x.banka)}</b><div class="kv"><span>Kalan borç</span><b>${vitTL(x.kalan)}</b></div><div class="kucuk">${e(x.durum)}</div>
 ${x.durum==="basvuru"?`<button class="btn ikinci" onclick="oybKrediBasvuruIptal(${x.id})">Başvuruyu iptal et</button>`:""}
 ${["aktif","gecikmis"].includes(x.durum)?`<div class="alan"><label>Ödenecek tutar</label><input id="oyb_kode_${x.id}" type="number" min="1" value="${Math.ceil(x.kalan)}"></div><button class="btn altin" onclick="oybKrediOde(${x.id})">Öde</button>`:""}</div>`).join("")||'<p class="alt">Kredin yok.</p>'}</div>
 <button class="btn altin" onclick="bankaKrediDosyaEkrani()">Kredi taksitlerim / mali bilgi izinlerim</button>
 <button class="btn ikinci" onclick="bankaRehberiEkrani()">Banka rehberine dön</button>`,{geri:true});
 }catch(err){iskelet("Bankacılık portföyüm",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function bankaKurEkrani(){
 iskelet("Banka kur",`<div class="kart"><h2>Yeni banka kur</h2><p class="alt">Banka asgari kuruluş sermayesi 1.000.000 ₺. Faizleri kurduktan sonra banka yönetiminden ayarlayabilirsin.</p>
 <div class="alan"><label>Banka adı</label><input id="vitBankaAd" maxlength="50"></div>
 <div class="alan"><label>Kuruluş sermayesi</label><input id="vitBankaSermaye" type="number" min="1000000" value="1000000"></div><button class="btn altin" id="vitBankaKur">Bankayı kur</button></div>`,{geri:true});
 $("#vitBankaKur").onclick=async()=>{
 const ad=$("#vitBankaAd").value.trim(),v=Number($("#vitBankaSermaye").value),b=$("#vitBankaKur");
 if(ad.length<3||ad.length>50||!Number.isSafeInteger(v)||v<1000000||v>1e8){toast("Banka adı veya sermayesi geçersiz.",true);return;}
 b.disabled=true;try{await API.rpc("sirket_kur",{p_ad:ad,p_sektor:"banka",p_sermaye:v});toast("Bankan kuruldu.");bankaRehberiEkrani();}
 catch(err){b.disabled=false;toast(hataCevir(err.message),true);}
 };
}
async function sirketVitrinEkrani(){
 yukleniyor("Şirketler");
 try{
 const d=await API.rpc("sirket_vitrini");vitSirketler=d.sirketler||[];
 iskelet("Şirketler",`<div class="kart vit-manset"><h2>🏢 Türkiye şirket rehberi</h2><p class="alt">Gerçek oyuncuların şirketleri, sahipleri ve paydaşları. Kâr ve vergi sıralamaları gerçek faaliyet kayıtlarından hesaplanır.</p>
 <div class="vit-dugme"><button class="btn altin" onclick="sirketYonetimEkrani()">Şirketlerim / Şirket kur</button><button class="btn ikinci" onclick="sirketPazarEkrani()">Satılık şirketler</button><button class="btn ikinci" onclick="halkaArzPazarEkrani()">Halka arzlar</button></div></div>
 <div class="vit-ozet"><span><b>${vitSirketler.length}</b> şirket</span><span><b>${vitSirketler.reduce((a,b)=>a+(b.ortaklar||[]).length,0)}</b> ortaklık kaydı</span></div>
 <div class="kart"><h3>Sıralama</h3>
 <select id="vitSirketSort" onchange="sirketVitrinListeCiz()"><option value="kazanc">En çok net kazanan</option><option value="vergi">En çok vergi ödeyen (kayıtlı)</option><option value="sermaye">En yüksek sermaye</option><option value="yeni">En yeni şirket</option></select>
 <div class="alan"><label>Sektör</label><select id="vitSirketTur" onchange="sirketVitrinListeCiz()"><option value="">Tüm sektörler</option>${Object.entries(vitSektor).filter(x=>x[0]!=="banka").map(([k,v])=>`<option value="${k}">${v}</option>`).join("")}</select></div>
 <p class="kucuk">Henüz şirket vergisi kaydı olmayanlarda 0 ₺ gösterilir. Geçmişte kaydı tutulmayan vergiler tahmin edilmez.</p></div>
 <div id="vitSirketListe"></div>`,{geri:true});sirketVitrinListeCiz();
 }catch(err){iskelet("Şirketler",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
function sirketVitrinListeCiz(){
 const el=$("#vitSirketListe");if(!el)return;
 const sort=$("#vitSirketSort").value,tur=$("#vitSirketTur").value;
 const key={kazanc:"net_kazanc",vergi:"vergi",sermaye:"sermaye"}[sort];
 const l=vitSirketler.filter(x=>!tur||x.sektor===tur).sort((a,b)=>key?Number(b[key]||0)-Number(a[key]||0)||a.id-b.id:new Date(b.kurulus)-new Date(a.kurulus));
 const tumuSifir=(sort==="vergi"||sort==="kazanc")&&l.length>0&&l.every(x=>Number(x[sort==="vergi"?"vergi":"net_kazanc"]||0)===0);
 el.innerHTML=(tumuSifir?'<div class="kart"><p class="alt">Henüz '+(sort==="vergi"?"şirketler adına ödenmiş vergi":"şirket faaliyet kazancı")+' kaydı yok. Bu nedenle gerçek bir sıralama henüz oluşmadı; şirketleri aşağıdan keşfedebilirsin.</p></div>':'')+l.map((x,i)=>`<button class="kart vit-banka" onclick="sirketDetayEkrani(${x.id})">
 <div class="vit-bas"><span class="vit-logo">🏢</span><span class="orta"><b>${tumuSifir?'':(i+1)+'. '}${e(x.ad)}</b><span class="kucuk">${e(vitSektor[x.sektor]||x.sektor)} · En büyük ortak: ${e((x.ortaklar||[])[0]?.kad||x.sahip)}</span></span><span class="ok">›</span></div>
 <div class="vit-stats"><span><small>Net kazanç</small><b>${vitTL(x.net_kazanc)}</b></span><span><small>Kayıtlı vergi</small><b>${vitTL(x.vergi)}</b></span><span><small>Şirket kasası</small><b>${vitTL(x.kasa)}</b></span></div></button>`).join("")||'<div class="kart"><p class="alt">Bu kriterlerde şirket bulunmuyor.</p></div>';
}
function sirketDetayEkrani(id){
 const x=vitSirketler.find(z=>z.id===id);if(!x){sirketVitrinEkrani();return;}
 iskelet(e(x.ad),`<div class="kart vit-manset"><h2>🏢 ${e(x.ad)}</h2><p class="alt">${e(vitSektor[x.sektor]||x.sektor)} · Kuruluş ${tarihSaat(x.kurulus)}</p>
 <div class="kv"><span>Kurucu</span><b>${e(x.kurucu||x.sahip)}</b></div><div class="kv"><span>En büyük pay sahibi</span><b>${e(x.sahip)}</b></div><div class="kv"><span>Sermaye</span><b>${vitTL(x.sermaye)}</b></div>
 <div class="kv"><span>Şirket kasası</span><b>${vitTL(x.kasa)}</b></div></div>
 <div class="kart"><h2>Pay sahipleri</h2>${(x.ortaklar||[]).map(o=>`<div class="kv"><span>${e(o.kad)}</span><b>%${fmt(o.pay,2)}</b></div>`).join("")||'<p class="alt">Ortak bulunamadı.</p>'}</div>
 <div class="kart"><h2>Şirket faaliyet raporu</h2><div class="kv"><span>Gerçekleşen brüt gelir</span><b>${vitTL(x.toplam_gelir)}</b></div>
 <div class="kv"><span>Gerçekleşen net kâr / zarar</span><b>${vitTL(x.net_kazanc)}</b></div><div class="kv"><span>Kaydedilen vergi</span><b>${vitTL(x.vergi)}</b></div>
 <p class="kucuk">Kayıtlara geçmiş tüm dönemlerin toplamıdır; eksik eski veriler hesaplanmaz.</p>
 ${x.satilik?`<div class="kv"><span>Satılık fiyatı</span><b>${vitTL(x.satilik)}</b></div><button class="btn altin" onclick="sirketPazarAl(${x.id})">Satın al</button>`:""}</div>
 <button class="btn ikinci" onclick="sirketVitrinEkrani()">Şirketlere dön</button>`,{geri:true});
}
async function sirketPazarEkrani(){
 yukleniyor("Satılık şirketler");
 try{const d=await API.rpc("sirket_liste"),l=(d.pazar||[]).filter(x=>x.sektor!=="banka"),benimTamSirketler=new Set((d.sirketler||[]).filter(s=>Number(s.pay)===100).map(s=>Number(s.id)));
 iskelet("Satılık şirketler",`<div class="kart"><h2>Satılık şirketler</h2></div>
 ${l.map(x=>`<div class="kart"><h3>${e(x.ad)}</h3><p class="alt">${e(vitSektor[x.sektor]||x.sektor)}</p><div class="kv"><span>Fiyat</span><b>${vitTL(x.fiyat)}</b></div>${benimTamSirketler.has(Number(x.id))?`<button class="btn ikinci" onclick="sirketSatistanCikar(${x.id},'pazar')">İlanımı kaldır</button>`:`<button class="btn altin" onclick="sirketPazarAl(${x.id})">Satın al</button>`}</div>`).join("")||'<div class="kart">Satılık şirket bulunmuyor.</div>'}`,{geri:true});
 }catch(err){iskelet("Şirket pazarı",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
window.oyuncuBankaEkrani=bankaRehberiEkrani;
window.sirketEkrani=sirketVitrinEkrani;
