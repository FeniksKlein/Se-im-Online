/*
 * SEÇİM SİMÜLASYONU ONLINE — EKONOMİ PREMIUM UI
 * 25.10.2026 | Sadece arayüz / yönlendirme. Finansal RPC, sunucu yetkisi,
 * bakiye, kredi limiti, faiz ve oyuncu kayıtları değiştirilmez.
 * Kurulum: docs/index.html kapanış body etiketi öncesine dosya yüklenir.
 * Derleme: gelistirici/build/derle.js ile tek dosyalı sürüme de eklenir.
 */
(function () {
  'use strict';
  if (window.SO_PREMIUM_EKONOMI_V1) return;
  window.SO_PREMIUM_EKONOMI_V1 = true;

  var B = {veri: null, banka: null, secme: 'ozet', filtre: '', seciliVade: '24', tutar: '1000', yonetim: []};
  var X = {
    lacivert:['#345bc8','#15234c'], bordo:['#bd456c','#43203d'],
    zumrut:['#249f86','#163e43'], turuncu:['#e4a65e','#553b41'],
    mor:['#977de9','#362c64'], altin:['#d5b66e','#5b4535'],
    turkuaz:['#39b7c9','#194453'], gece:['#8793b5','#252d49'],
    kirmizi:['#e66f77','#602c46'], gumus:['#aebbd1','#404964']
  };
  function esc(v){return String(v == null ? '' : v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}
  function money(v){if(v==null||v==='')return '—';var n=Number(v);return isFinite(n)?n.toLocaleString('tr-TR',{maximumFractionDigits:0})+' ₺':'—'}
  function shortMoney(v){if(v==null||v==='')return '—';var n=Number(v);if(!isFinite(n))return '—';var a=Math.abs(n),p=n<0?'−':'';if(a>=1e9)return p+(a/1e9).toLocaleString('tr-TR',{maximumFractionDigits:2})+' Mr ₺';if(a>=1e6)return p+(a/1e6).toLocaleString('tr-TR',{maximumFractionDigits:2})+' Mn ₺';if(a>=1e4)return p+(a/1e3).toLocaleString('tr-TR',{maximumFractionDigits:1})+' bin ₺';return money(n)}
  function pct(v,d){if(v==null||v==='')return '—';var n=Number(v);return isFinite(n)?'%'+n.toLocaleString('tr-TR',{maximumFractionDigits:d==null?2:d}):'—'}
  function num(v){var n=Number(v);return isFinite(n)?n:0}
  function tone(r){return X[r] || X.lacivert}
  function safeId(v){var n=Number(v);return Number.isSafeInteger(n)&&n>0?n:0}
  function action(fn){if(typeof fn==='function'){if(typeof window.ekranAc==='function')return window.ekranAc(fn);return fn()}if(typeof window.toast==='function')window.toast('Bu ekran yüklenemedi. Sayfayı yenileyip yeniden dene.',true)}
  function gotoSube(tab){return action(function(){if(typeof window.mobilSubeEkrani==='function')return window.mobilSubeEkrani(tab||'ozet');if(typeof window.toast==='function')window.toast('Mobil Şube modülü bulunamadı.',true)})}
  function screen(title,html){if(typeof window.iskelet==='function')return window.iskelet(title,html,{geri:!!(typeof D!=='undefined'&&D.yigin&&D.yigin.length)});if(typeof window.toast==='function')window.toast('Ekran açılamadı.',true)}
  function button(icon,title,desc,onclick,primary){return '<button type="button" class="pep-action'+(primary?' main':'')+'" onclick="'+onclick+'"><span class="pep-action-icon" aria-hidden="true">'+icon+'</span><b>'+esc(title)+'</b><small>'+esc(desc)+'</small></button>'}
  function section(title,aside,contents){return '<section class="pep-section"><div class="pep-title"><h3>'+esc(title)+'</h3>'+(aside?'<small>'+esc(aside)+'</small>':'')+'</div>'+contents+'</section>'}
  function label(k,v){return '<div class="pep-label"><small>'+esc(k)+'</small><b>'+esc(v)+'</b></div>'}
  function logError(err){if(typeof window.console!=='undefined'&&console.warn)console.warn('Ekonomi premium:',err)}

  var CSS = `
  /* Tüm Ekonomi: Mobil Şube seviyesinde tek bir premium sistem */
  .so-ekonomi{--pep-mint:#80e4c8;--pep-purple:#a894f6;--pep-ink:#131b38}
  .so-ekonomi .so-tabs{background:linear-gradient(90deg,#171d3e,#151c37)!important;padding:9px 5px 13px!important;gap:7px!important;box-shadow:0 8px 20px #080c2544;border:1px solid #384469!important;border-radius:16px!important;margin-bottom:12px!important}
  .so-ekonomi .so-tabs button{background:#20294d!important;border:1px solid #35456f!important;border-radius:13px!important;min-height:62px!important;min-width:77px!important;box-shadow:0 4px 8px #03061720;transition:background .16s,border-color .16s,transform .16s}
  .so-ekonomi .so-tabs button[aria-selected="true"]{background:linear-gradient(145deg,#1a4e5b,#1d3b4f)!important;border-color:#77d6c6!important;color:white!important;box-shadow:inset 0 -3px 0 #80e4c8,0 8px 16px #08142066!important}
  .so-ekonomi .so-tabs button:active{transform:scale(.97)}
  .so-ekonomi .so-econ-banner{background:radial-gradient(circle at 100% 0%,#50649b65,transparent 57%),linear-gradient(115deg,#193c50,#202d58)!important;border:1px solid #5d7d9b!important;border-radius:23px!important;box-shadow:0 12px 25px #050a2026!important;padding:21px 19px!important}
  .so-ekonomi .so-econ-banner h2{font-size:clamp(23px,5.4vw,28px)!important;font-weight:850;letter-spacing:-.6px}
  .so-ekonomi .so-econ-banner p{color:#d1dfed!important}
  .so-ekonomi .so-econ-section{margin:19px 0!important}
  .so-ekonomi .so-econ-section-head h3{font-size:17px!important;letter-spacing:-.2px}
  .so-ekonomi .so-econ-tile{background:linear-gradient(145deg,#202b51,#181f3d)!important;border:1px solid #3f4c78!important;border-radius:19px!important;padding:16px!important;min-height:122px!important;box-shadow:0 5px 13px #050a211c;transition:transform .15s,border-color .15s}
  .so-ekonomi .so-econ-tile.featured{background:linear-gradient(145deg,#174d56,#213a58)!important;border-color:#68c9b8!important}
  .so-ekonomi .so-econ-tile:active{transform:scale(.98)}
  .so-ekonomi .so-econ-tile b{color:#f7faff!important;font-weight:850!important}
  .so-ekonomi .so-econ-tile .so-econ-tile-icon{background:#5269a63f!important;border-radius:11px!important}
  .so-ekonomi .so-econ-kpi{background:linear-gradient(145deg,#1c2950,#16203e)!important;border-radius:16px!important;border-color:#405078!important}
  .so-ekonomi .so-econ-kpi.accent{background:linear-gradient(125deg,#174c54,#24395e)!important;border-color:#61bbae!important}
  .so-ekonomi .so-company{background:linear-gradient(145deg,#1d2c54,#17203c)!important;border-color:#44537b!important;border-radius:19px!important;padding:19px 17px!important}
  .so-ekonomi .so-company:focus-visible,.so-ekonomi button:focus-visible{outline:2px solid #8ee7d3!important;outline-offset:2px}
  .so-ekonomi .so-econ-more{background:linear-gradient(145deg,#1d2748,#151d37)!important;border-radius:17px!important}
  /* Ekonomi alt sayfalarında aynı kart, form, buton ve tablo hiyerarşisi. */
  #icerik.pep-economy-child>.kart,#icerik.pep-economy-child .kart{background:linear-gradient(145deg,#202b50,#171f3b);border:1px solid #43547c;border-radius:20px;box-shadow:0 7px 19px #070c241f}
  #icerik.pep-economy-child .kart h2,#icerik.pep-economy-child .kart h3{font-weight:850;letter-spacing:-.3px}
  #icerik.pep-economy-child .btn{border-radius:13px;min-height:43px;font-weight:800}
  #icerik.pep-economy-child .btn.altin{background:linear-gradient(120deg,#97e4d7,#c9b8ff);color:#13243b;border:0}
  #icerik.pep-economy-child input,#icerik.pep-economy-child select,#icerik.pep-economy-child textarea{border-radius:12px;max-width:100%}
  #icerik.pep-economy-child .segment{border-radius:14px;background:#1e2b50;overflow-x:auto;scrollbar-width:none}
  #icerik.pep-economy-child .segment button{border-radius:12px}
  #icerik.pep-economy-child .kv{gap:10px}

  .pep{--accent:#80e4c8;min-width:0;color:var(--txt,#f8f9ff);padding:0 0 20px}
  .pep *, .pep *::before,.pep *::after{box-sizing:border-box}
  .pep-hero{position:relative;overflow:hidden;border-radius:25px;background:radial-gradient(circle at 95% 5%,#779fe056,transparent 42%),linear-gradient(120deg,#202a5c,#202d50 45%,#163c4c);border:1px solid #506ba3;padding:23px 19px 21px;box-shadow:0 12px 30px #040b252c;margin:6px 0 16px}
  .pep-hero::before{content:'';position:absolute;right:-70px;top:-70px;width:230px;height:230px;border:1px solid #c2fdf333;border-radius:50%;pointer-events:none}
  .pep-eyebrow{font-size:11px;font-weight:850;color:#a2f1db;letter-spacing:1.4px;display:flex;align-items:center;gap:7px;margin-bottom:9px}
  .pep-hero h2{font-size:clamp(25px,6vw,35px);color:#fff;font-weight:900;letter-spacing:-.9px;line-height:1.1;margin:0 0 9px;overflow-wrap:anywhere}
  .pep-hero p{max-width:520px;color:#d0dbf0;line-height:1.52;font-size:13px;margin:0 0 15px}
  .pep-hero-actions{display:flex;gap:9px;flex-wrap:wrap}
  .pep-pill{display:inline-flex;align-items:center;justify-content:center;min-height:41px;border:1px solid #6b81b4;background:#34427099;color:#f9fbff;border-radius:13px;padding:10px 14px;font-size:13px;font-weight:800;cursor:pointer;text-decoration:none}
  .pep-pill.primary{background:linear-gradient(110deg,#7ce0c5,#94eace);border-color:#a4f6dc;color:#102e3b}
  .pep-pill:active{filter:brightness(1.08)}
  .pep-title{display:flex;justify-content:space-between;align-items:baseline;gap:10px;margin:0 3px 11px}
  .pep-title h3{margin:0;font-size:17px;color:#f7f9ff;font-weight:850;letter-spacing:-.25px}
  .pep-title small{font-size:11px;color:#acb9d5;text-align:right}
  .pep-section{margin:19px 0}
  .pep-kpis{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}
  .pep-stat{background:linear-gradient(145deg,#202b50,#17203d);border:1px solid #42527a;border-radius:17px;padding:15px 13px;min-width:0}
  .pep-stat small{display:block;color:#b5c1d8;font-size:11.5px;font-weight:600}
  .pep-stat strong{display:block;font-size:clamp(18px,5.2vw,25px);font-weight:850;letter-spacing:-.6px;font-variant-numeric:tabular-nums;overflow-wrap:anywhere;color:#fff;margin-top:7px}
  .pep-actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}
  .pep-action{display:flex;flex-direction:column;align-items:flex-start;gap:6px;min-width:0;min-height:116px;padding:15px 13px;border:1px solid #3d4d79;border-radius:18px;text-align:left;color:#f6f9ff;background:linear-gradient(155deg,#25315c,#192342);cursor:pointer;transition:transform .16s,border-color .16s}
  .pep-action.main{background:linear-gradient(145deg,#18535b,#1e4056);border-color:#6dc8b9}
  .pep-action:active{transform:scale(.98)}
  .pep-action .pep-action-icon{display:grid;place-items:center;background:#5b75ba40;width:36px;height:36px;border-radius:11px;font-size:19px;margin-bottom:1px}
  .pep-action b{font-size:14px;color:#fff;line-height:1.2}
  .pep-action small{font-size:11.5px;line-height:1.35;color:#b5c4da}
  .pep-banks{display:grid;grid-template-columns:minmax(0,1fr);gap:13px}
  .pep-bank{border-radius:22px;overflow:hidden;background:radial-gradient(circle at 100% 0%,var(--bank-accent,#679dde) 0%,transparent 40%),linear-gradient(135deg,#202c57,#19213e 67%);border:1px solid #55638c;box-shadow:0 10px 18px #060c2640;padding:16px;min-width:0}
  .pep-bank-top{display:flex;gap:12px;align-items:center;min-width:0}
  .pep-bank-icon{width:51px;height:51px;flex:0 0 51px;display:grid;place-items:center;border:1px solid #ffffff32;border-radius:16px;background:#0c1438a3;font-size:27px}
  .pep-bank-top .pep-bank-name{flex:1;min-width:0}
  .pep-bank-name h3{font-size:19px;line-height:1.15;color:white;letter-spacing:-.4px;margin:0 0 5px;overflow-wrap:anywhere}
  .pep-bank-name p{margin:0;color:#becbe4;font-size:11.5px;line-height:1.4}
  .pep-bank-chevron{font-size:23px;color:#d5ddff;flex:0 0 auto}
  .pep-rate-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:15px 0 11px}
  .pep-rate{min-width:0;background:#0b1330bb;border:1px solid #ffffff14;border-radius:13px;padding:11px 8px}
  .pep-rate small{display:block;color:#a9b8d4;font-size:10px;line-height:1.3}
  .pep-rate b{display:block;color:#fff;font-weight:850;font-size:16px;margin-top:7px;font-variant-numeric:tabular-nums;overflow-wrap:anywhere}
  .pep-bank-actions{display:flex;gap:9px;align-items:center;flex-wrap:wrap}
  .pep-tag{display:inline-flex;font-size:11px;font-weight:800;border-radius:99px;padding:5px 9px;background:#75dbbb28;color:#91f0c9;border:1px solid #6adbba40}
  .pep-tag.dim{color:#b9c8ec;background:#9da9f619;border-color:#a3b1f62c}
  .pep-bank-actions button{flex:1;min-height:41px;border-radius:11px;background:#849be332;border:1px solid #9eb7ec7a;color:white;font-weight:850;font-size:12.5px;cursor:pointer}
  .pep-bank-actions button.primary{background:#80e4c8;color:#123343;border-color:#b6ffeb}
  .pep-tabs{display:flex;gap:7px;overflow-x:auto;scrollbar-width:none;padding:2px 1px 10px;margin:0 -1px 10px;scroll-snap-type:x proximity}
  .pep-tabs::-webkit-scrollbar{display:none}
  .pep-tabs button{white-space:nowrap;flex:0 0 auto;padding:10px 15px;min-height:43px;border-radius:13px;background:#1f294b;color:#c9d2ed;border:1px solid #39466a;font-weight:850;font-size:13px;scroll-snap-align:start}
  .pep-tabs button.active{background:#e1edff;color:#151e38;border-color:#edf3ff;box-shadow:0 4px 14px #03092340}
  .pep-panel{border:1px solid #3e4c73;border-radius:19px;background:linear-gradient(145deg,#1c2748,#141c36);padding:17px;margin:12px 0}
  .pep-panel h3{margin:0 0 9px;color:#f8f9ff;font-size:17px}
  .pep-panel p{font-size:12.5px;color:#b8c5df;line-height:1.55;margin:5px 0 11px}
  .pep-info-row{display:flex;justify-content:space-between;align-items:baseline;gap:12px;padding:11px 0;border-bottom:1px solid #64719b3a}
  .pep-info-row:last-child{border-bottom:0}
  .pep-info-row span{font-size:12.5px;color:#b4c3dc}.pep-info-row b{font-size:14px;color:white;text-align:right;font-variant-numeric:tabular-nums}
  .pep-label{background:#0d1633;border:1px solid #344467;border-radius:14px;padding:12px 14px}
  .pep-label small{display:block;color:#a9b8d2;font-size:11px}.pep-label b{display:block;color:white;font-size:18px;margin-top:5px}
  .pep-label-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}
  .pep-field{display:flex;flex-direction:column;gap:6px;font-size:12px;font-weight:750;color:#e5edfb;margin:11px 0}
  .pep-field input,.pep-field select,.pep-search{display:block;max-width:100%;width:100%;border-radius:13px;border:1px solid #52628a;background:#0b1431;color:#fff;min-height:47px;padding:11px 13px;font-size:15px;outline-offset:2px}
  .pep-search{margin:0 0 14px;background:#182343}
  .pep-hint{font-size:11px;color:#b4c1da;line-height:1.5;margin:9px 0}
  .pep-notice{padding:13px;border:1px solid #4b648f;border-radius:14px;color:#cdd9ee;background:#1c2e52;font-size:12px;line-height:1.5}
  .pep-empty{text-align:center;padding:23px 14px;color:#b9c9dc;background:#17223e;border-radius:15px}
  .pep-showcase{margin:7px 0 15px;padding:17px;border-radius:20px;background:radial-gradient(circle at 90% 0%,#7d7df358,transparent 49%),linear-gradient(125deg,#2a3465,#1c3b53);border:1px solid #8284c0;box-shadow:0 8px 18px #070b2150}
  .pep-showcase-eyebrow{color:#aceee0;font-size:10px;font-weight:800;letter-spacing:1.1px;margin-bottom:7px}
  .pep-showcase b{display:block;color:#fff;font-size:22px;font-weight:900;letter-spacing:-.3px}
  .pep-showcase p{color:#d2daf0;font-size:12px;line-height:1.5;margin:6px 0 13px}
  .pep-showcase button{width:100%;background:linear-gradient(105deg,#8debce,#a0c8ff);border:0;border-radius:12px;padding:12px 16px;color:#172b41;font-weight:900;min-height:44px}
  @media(min-width:700px){.pep-banks{grid-template-columns:repeat(2,minmax(0,1fr))}.pep-kpis{grid-template-columns:repeat(4,minmax(0,1fr))}.pep-actions{grid-template-columns:repeat(4,minmax(0,1fr))}}
  @media(max-width:350px){.pep-hero{padding:17px 14px}.pep-bank{padding:12px}.pep-rate{padding:9px 6px}.pep-rate b{font-size:14px}.pep-action{padding:11px}}
  @media(prefers-reduced-motion:reduce){.pep-action,.pep-bank,.so-ekonomi .so-econ-tile{transition:none!important}}
  `;
  function css(){if(document.getElementById('pep-style'))return;var el=document.createElement('style');el.id='pep-style';el.textContent=CSS;document.head.appendChild(el)}

  async function fetchBanks(){
    if(typeof API==='undefined'||!API||typeof API.rpc!=='function')throw Error('Bankacılık sunucusuna bağlanılamadı.');
    var ret=await Promise.allSettled([API.rpc('banka_sube'),API.rpc('banka_yonettiklerim')]);
    if(ret[0].status!=='fulfilled')throw ret[0].reason;
    B.veri=ret[0].value||{};
    B.yonetim=ret[1].status==='fulfilled'&&Array.isArray(ret[1].value)?ret[1].value:[];
    return B.veri;
  }
  function bankById(id){return ((B.veri&&B.veri.bankalar)||[]).find(function(b){return safeId(b&&b.id)===safeId(id)})}
  function owned(b){return B.yonetim.some(function(x){return safeId(x&&x.id)===safeId(b.id)})||!!b.bankam}
  function bankaKart(b){
    var id=safeId(b&&b.id);if(!id)return '';
    var t=tone(b.renk),attr='style="--bank-accent:'+t[0]+'44"';
    var acik=b.slogan?'“'+esc(b.slogan)+'”':(num(b.musteri)+' müşteri');
    var status=b.hesabim?'Hesabın var':owned(b)?'Ortağısın':'Yeni banka';
    var rate24=(b.vadeler||{})['1'];
    var credit=b.paket_sayisi?pct(b.en_dusuk_kredi,2)+'’den':pct(b.kredi24,2);
    return '<article class="pep-bank" '+attr+'><div class="pep-bank-top"><div class="pep-bank-icon">🏦</div>'+
       '<div class="pep-bank-name"><h3>'+esc(b.ad||'Banka')+'</h3><p>'+acik+'</p></div><span class="pep-bank-chevron">›</span></div>'+
       '<div class="pep-bank-actions" style="margin:10px 0 0"><span class="pep-tag">Güven '+esc(b.not||'—')+'</span><span class="pep-tag dim">'+esc(status)+'</span></div>'+
       '<div class="pep-rate-grid"><div class="pep-rate"><small>1 saat mevduat</small><b>'+pct(rate24,3)+'</b></div><div class="pep-rate"><small>7 gün mevduat</small><b>'+pct(b.mevduat7,2)+'</b></div><div class="pep-rate"><small>Kredi / 24 saat</small><b>'+credit+'</b></div></div>'+
       '<div class="pep-bank-actions"><button class="primary" type="button" onclick="premiumBankaSec('+id+')">Bankayı incele</button>'+
       (owned(b)?'<button type="button" onclick="premiumBankaYonet('+id+')">Yönetim</button>':!b.hesabim?'<button type="button" onclick="premiumHesapAc('+id+')">Hesap aç</button>':'')+'</div></article>';
  }
  function directoryHtml(){
    var bankalar=(B.veri&&B.veri.bankalar)||[],filtre=B.filtre.trim().toLocaleLowerCase('tr-TR');
    var arr=bankalar.filter(function(b){return !filtre||String(b.ad||'').toLocaleLowerCase('tr-TR').includes(filtre)});
    return '<div class="pep"><header class="pep-hero"><div class="pep-eyebrow">✦ FİNANS / BANKALAR</div><h2>Bankalar Çarşısı</h2><p>Bankaların faizlerini ve güven notlarını karşılaştır. Hesaplarını Mobil Şube’den yönet, banka sahibiysen genel müdürlüğünü aç.</p><div class="pep-hero-actions"><button class="pep-pill primary" onclick="premiumSubeGit(\'bankalar\')">✦ Mobil Şube</button><button class="pep-pill" onclick="premiumBankaKur()">＋ Banka kur</button></div></header>'+
      '<div class="pep-kpis">'+label('Oyuncu bankası',String(bankalar.length))+label('Açık hesabım',String(bankalar.filter(function(x){return x.hesabim}).length))+'</div>'+
      section('Oyuncu bankaları','Gerçek oyun oranları',
      '<input class="pep-search" type="search" placeholder="Banka adıyla ara…" oninput="premiumBankaAra(this.value)" value="'+esc(B.filtre)+'" aria-label="Banka ara">'+
      '<div class="pep-banks" id="pepBankaListe">'+(arr.length?arr.map(bankaKart).join(''):'<p class="pep-empty">Bu isimde banka bulunamadı.</p>')+'</div>')+
      section('Kamu bankacılığı','Tek merkez', '<div class="pep-actions">'+button('🏛️','Devlet bankası','Mevduat ve krediler','premiumSubeGit(\'ozet\')',true)+button('📋','Krediler','Teklif ve ödeme planları','premiumSubeGit(\'krediler\')')+button('💳','Kartlar','Ekstre ve başvurular','premiumSubeGit(\'kartlar\')')+button('💰','Birikim','Mevduat ve getiriler','premiumSubeGit(\'birikim\')')+'</div>')+'</div>';
  }
  window.premiumBankaCarsisiEkrani=async function(){
    css(); if(typeof window.yukleniyor==='function')window.yukleniyor('Bankalar Çarşısı');
    try{await fetchBanks();screen('Oyuncu bankaları',directoryHtml())}
    catch(e){logError(e);screen('Oyuncu bankaları','<div class="pep"><p class="pep-notice">Bankalar yüklenemedi: '+esc(e&&e.message||e)+'</p><button class="pep-pill primary" onclick="premiumBankaCarsisiEkrani()">Yeniden dene</button></div>')}
  };
  window.premiumBankaAra=function(v){B.filtre=String(v||'');var root=document.getElementById('pepBankaListe');if(!root)return;var arr=((B.veri&&B.veri.bankalar)||[]).filter(function(b){return String(b.ad||'').toLocaleLowerCase('tr-TR').includes(B.filtre.trim().toLocaleLowerCase('tr-TR'))});root.innerHTML=arr.length?arr.map(bankaKart).join(''):'<p class="pep-empty">Bu isimde banka bulunamadı.</p>'};
  window.premiumBankaSec=function(id){return action(function(){return window.premiumBankaAc(id)})};
  window.premiumBankaYonet=function(id){var f=window.bankaGenelMudurlukEkrani;if(typeof f==='function')return action(function(){return f(id)});return gotoSube('ozet')};
  window.premiumHesapAc=function(id){if(typeof window.msHesapAc==='function')return window.msHesapAc(id);return gotoSube('bankalar')};
  window.premiumBankaKur=function(){if(typeof window.msBankaKur==='function')return window.msBankaKur();if(typeof window.bankaKurEkrani==='function')return action(window.bankaKurEkrani)};
  window.premiumSubeGit=gotoSube;

  function vadeKartlari(b){
    var r=b.vadeler||{};
    var d=[['1','1 saat'],['3','3 saat'],['6','6 saat'],['12','12 saat'],['24','24 saat']];
    if(b.mevduat7!=null)d.push(['168','7 gün']);
    var list=d.filter(function(x){return (x[0]==='168'?b.mevduat7:r[x[0]])!=null});
    if(!list.length)return '<p class="pep-hint">Bu bankada gösterilebilir vade oranı bulunmuyor. Mobil Şube’den güncel seçenekleri inceleyebilirsin.</p>';
    return '<div class="pep-label-grid">'+list.map(function(x){var rate=x[0]==='168'?b.mevduat7:r[x[0]];return label(x[1],pct(rate,3))}).join('')+'</div>';
  }
  function bankaPanel(b){
    var id=safeId(b.id),current=B.secme,v=b.vadeler||{};
    if(current==='krediler')return section('Kredi ürünleri','Ödeme planlarını Mobil Şube hesaplar',
      '<div class="pep-panel"><h3>Kredi masası</h3><p>Kredi notuna, gelirine ve banka limitlerine göre uygun paketler Mobil Şube içinde değerlendirilir. Günlük faiz bilgisi gösterge niteliğindedir.</p><div class="pep-kpis"><div class="pep-stat"><small>Kredi / 24 saat</small><strong>'+pct(b.kredi24,2)+'</strong></div><div class="pep-stat"><small>Aktif kredi paketi</small><strong>'+num(b.paket_sayisi)+'</strong></div></div><div class="pep-hero-actions" style="margin-top:14px"><button class="pep-pill primary" onclick="premiumKrediAc('+id+')">Kredi seçeneklerini aç</button><button class="pep-pill" onclick="premiumSubeGit(\'krediler\')">Borçlarım</button></div></div>');
    if(current==='mevduat')return section('Mevduat ve faiz','Bankanın ilan ettiği oyun oranları',
      '<div class="pep-panel"><h3>Vadeye göre faizler</h3><p>Oranlar seçilen vadenin tamamı içindir. Para yatırma ve çekme işlemleri Mobil Şube’de güvenle yapılır.</p>'+vadeKartlari(b)+'<div class="pep-hero-actions" style="margin-top:15px"><button class="pep-pill primary" onclick="premiumSubeGit(\'birikim\')">Mevduat yatır / hesapla</button></div></div>');
    if(current==='kartlar')return section('Kart ve başvurular','Hesabın ve kartların tek yerde',
      '<div class="pep-panel"><h3>Kart merkezi</h3><p>Kredi kartı başvurusu, limit, harcama, ekstre ve borç ödemesi Mobil Şube içinde yapılır. Başvurularını ve kart hareketlerini aynı yerden takip edebilirsin.</p><div class="pep-actions">'+button('💳','Kartlarım','Kart ve limit bilgileri','premiumSubeGit(\'kartlar\')',true)+button('🏧','Hesaplarım','Banka hesaplarını yönet','premiumSubeGit(\'ozet\')')+'</div></div>');
    if(current==='yonetim'&&owned(b))return section('Banka sahibi yönetimi','Yalnız yetkilendirilmiş kullanıcılar',
      '<div class="pep-panel"><h3>Genel Müdürlük</h3><p>Banka kasası, kredi ve POS başvuruları, faizler, otomatik kararlar ve banka bilançosu.</p><button class="pep-pill primary" onclick="premiumBankaYonet('+id+')">Genel Müdürlüğü aç</button></div>');
    return section('Hızlı işlemler','Mobil Şube üzerinden',
      '<div class="pep-actions">'+button('💳','Hesaplar','Banka ve bakiyeler','premiumSubeGit(\'ozet\')',true)+button('↗','Para gönder','Havale, EFT, FAST','premiumParaGonder()')+button('₺','Kredi çek','Teklifleri incele','premiumKrediAc('+id+')')+button('◷','Birikim','Vade ve faiz işlemleri','premiumSubeGit(\'birikim\')')+'</div>')+
      section('Faiz karşılaştırması','Güncel banka oranları',vadeKartlari(b))+
      '<button class="pep-pill" style="width:100%;margin-top:7px" onclick="premiumBankaCarsisiGit()">← Diğer bankaları karşılaştır</button>';
  }
  function bankaDetayHtml(){
    var b=B.banka;if(!b)return '<div class="pep-empty">Banka kaydı bulunamadı.</div>';
    var t=tone(b.renk),bankOwner=owned(b),kasa=b.kasa==null?'Gizli':shortMoney(b.kasa);
    var tabs=[['ozet','Özet'],['krediler','Krediler'],['mevduat','Mevduat'],['kartlar','Kartlar']];if(bankOwner)tabs.push(['yonetim','Yönetim']);
    var hero='<div class="pep-hero" style="background:radial-gradient(circle at 98% 0%,'+t[0]+'65,transparent 49%),linear-gradient(120deg,'+t[1]+',#172b4a)"><div class="pep-eyebrow">🏦 ÖZEL BANKACILIK</div><h2>'+esc(b.ad||'Banka')+'</h2><p>'+(b.slogan?esc(b.slogan):'Kredilerini, hesaplarını ve mevduatını tek merkezden yönet.')+'</p><div class="pep-hero-actions"><span class="pep-tag">Güven '+esc(b.not||'—')+'</span>'+(bankOwner?'<span class="pep-tag dim">Banka ortağı</span>':'')+'</div></div>';
    var kpi='<div class="pep-kpis"><div class="pep-stat"><small>7 gün mevduat</small><strong>'+pct(b.mevduat7,2)+'</strong></div><div class="pep-stat"><small>Kredi / 24 saat</small><strong>'+pct(b.kredi24,2)+'</strong></div><div class="pep-stat"><small>Müşteri sayısı</small><strong>'+num(b.musteri)+'</strong></div><div class="pep-stat"><small>Banka kasası</small><strong>'+esc(kasa)+'</strong></div></div>';
    var nav='<nav class="pep-tabs" role="tablist" aria-label="Banka bölümleri">'+tabs.map(function(t){return '<button role="tab" type="button" class="'+(B.secme===t[0]?'active':'')+'" aria-selected="'+(B.secme===t[0])+'" onclick="premiumBankaSekme(\''+t[0]+'\')">'+esc(t[1])+'</button>'}).join('')+'</nav>';
    return '<div class="pep">'+hero+kpi+nav+bankaPanel(b)+'</div>';
  }
  window.premiumBankaAc=async function(id){
    css();id=safeId(id);if(!id)return;
    if(!B.veri){try{await fetchBanks()}catch(err){logError(err);return screen('Banka', '<div class="pep-notice">Banka bilgileri yüklenemedi. Mobil Şube’den yeniden dene.</div>')}}
    var banka=bankById(id);if(!banka)return screen('Banka','<div class="pep-empty">Bu banka bulunamadı.</div>');
    B.banka=banka;B.secme='ozet';screen(banka.ad||'Banka',bankaDetayHtml());
  };
  window.premiumBankaSekme=function(secme){if(!B.banka)return;B.secme=secme;screen(B.banka.ad||'Banka',bankaDetayHtml())};
  window.premiumBankaCarsisiGit=function(){return action(window.premiumBankaCarsisiEkrani)};
  window.premiumKrediAc=function(id){return action(async function(){if(typeof window.mobilSubeEkrani==='function'){await window.mobilSubeEkrani('krediler');if(typeof window.msKrediBanka==='function')return window.msKrediBanka(id);}})};
  window.premiumParaGonder=function(){if(typeof window.paraGonderModal==='function')return window.paraGonderModal();return gotoSube('ozet')};

  /* Ekonomi ana ekranı: mevcut fonksiyonların üstüne tıklanabilir, tek bir Mobil Şube vitrini. */
  function showcase(){return '<div class="pep-showcase" id="pep-mobil-sube"><div class="pep-showcase-eyebrow">✦ TÜM BANKALAR TEK YERDE</div><b>Mobil Şube</b><p>Hesapların, kartların, kredilerin, birikimlerin ve para transferleri. Tek uygulama, bütün bankaların.</p><button type="button" onclick="premiumSubeGit(\'ozet\')">Mobil Şube’yi Aç　↗</button></div>'}
  function insertShowcase(){
    var wrapper=document.querySelector('.so-ekonomi');if(!wrapper)return;
    var current=wrapper.querySelector('.so-tabs [aria-selected="true"]');
    var sekme=current?(current.getAttribute('aria-label')||current.textContent||'').trim().toLocaleLowerCase('tr-TR'):'';
    if(sekme!=='özet'&&sekme!=='bankalar')return;
    var existing=wrapper.querySelector('#pep-mobil-sube, .so-ms-front');
    var banner=wrapper.querySelector('.so-econ-banner');if(!banner)return;
    if(!existing)banner.insertAdjacentHTML('afterend',showcase());
    if(sekme==='bankalar'){
      var bankLink=wrapper.querySelector('.so-econ-section');
      // Genel yönlendirme, orijinal bankacılık RPC'lerine bağlı tüm diğer kartlar korunur.
      if(bankLink&&!wrapper.querySelector('#pep-banka-carsi-buton')){
        bankLink.insertAdjacentHTML('afterbegin','<button type="button" class="pep-pill primary" id="pep-banka-carsi-buton" style="width:100%;margin:0 0 12px" onclick="premiumBankaCarsisiGit()">🏦 Oyuncu bankalarını karşılaştır　↗</button>');
      }
    }
  }
  function decorate(){
    if(!window.document||!document.body)return;
    css();insertShowcase();
    var content=document.getElementById('icerik');
    if(!content)return;
    // Sadece Ekonomi'ye bağlı eski alt sayfaları cilala; Mobil Şube'nin
    // çalışan premium görünümü, Adliye, Devlet ve diğer ekranlar değişmez.
    var active=typeof D!=='undefined'&&D.sekme==='ekonomi';
    var child=active&&!content.querySelector('.so-ekonomi')&&!content.querySelector('.bk')&&!content.querySelector('.pep');
    content.classList.toggle('pep-economy-child',!!child);
  }
  var queued=false;
  function schedule(){if(queued)return;queued=true;var fire=function(){queued=false;decorate()};if(typeof requestAnimationFrame==='function')requestAnimationFrame(fire);else Promise.resolve().then(fire)}
  function install(){
    css();schedule();
    // Eski oyuncu bankası listesinden premium vitrine geçilir; mevcut ödeme fonksiyonlarına dokunulmaz.
    window.bankaRehberiEkrani=window.premiumBankaCarsisiEkrani;
    if(typeof MutationObserver==='function'&&document.body){
      var target=document.getElementById('app')||document.body;
      new MutationObserver(schedule).observe(target,{childList:true,subtree:true});
    }
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});else install();
})();
