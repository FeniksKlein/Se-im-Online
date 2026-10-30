// Cumhurbaşkanı yardımcıları: dosya, kabine toplantısı, vekâlet ve denetim masası.
// Yetki denetimi yalnız Supabase RPC içinde yapılır; arayüzdeki görünürlük güvenlik sınırı değildir.
(function () {
  if (typeof window.cbYrdDosyaAc === 'function') return;
  if (typeof hukumetHtml !== 'function') return;
  let sonPanel = null;
  const TUR = { gorev:'Bakanlık görevi', proje:'Devlet projesi', kriz:'Kriz masası', kararname:'Kararname taslağı',
    toplanti:'Bakanlar Kurulu', aciklama:'Basın açıklaması', yerel:'Belediye görüşmesi', ekonomi:'Ekonomi önerisi' };
  const DURUM = { bekliyor:'Yanıt bekliyor', calisiliyor:'Çalışılıyor', tamamlandi:'Tamamlandı',
    onay_bekliyor:'CB onayı bekliyor', onaylandi:'Onaylandı', reddedildi:'Reddedildi', yayimlandi:'Yayımlandı' };
  const ALAN = { ekonomi:'Ekonomi ve yatırım', sosyal:'İç yönetim ve sosyal politikalar', genel:'Genel koordinasyon' };
  const BAKANLIKLAR = [ ['adalet','Adalet'],['disisleri','Dışişleri'],['icisleri','İçişleri'],
    ['maliye','Hazine ve Maliye'],['savunma','Millî Savunma'],['egitim','Millî Eğitim'],
    ['saglik','Sağlık'],['sanayi','Sanayi ve Teknoloji'],['ticaret','Ticaret'],
    ['tarim','Tarım ve Orman'],['ulastirma','Ulaştırma ve Altyapı'],['calisma','Çalışma ve Sosyal Güvenlik'] ];
  const EKONOMI = ['maliye','sanayi','ticaret','tarim','ulastirma','calisma'];
  const ALAN_SEC = Object.entries(ALAN).map(([k,v])=>`<option value="${k}">${e(v)}</option>`).join('');
  const kendiKad = () => D.durum && D.durum.profil && D.durum.profil.kad;
  const tarihYaz = t => t ? tarihSaat(t) : '—';
  const btn = (metin,fn,cls='ikinci') => `<button class="btn ${cls}" style="margin-top:8px" onclick="${fn}">${metin}</button>`;
  const bakanlikSecenek = p => {
    const alan = (p.alanlar||[]).find(a=>a.sira===p.yardimci_sira)?.alan || 'genel';
    return BAKANLIKLAR.filter(([k])=>alan==='genel'||(alan==='ekonomi')===EKONOMI.includes(k));
  };

  function cbYrdHtml(p) {
    sonPanel=p;
    const yonetici=p.cb_miyim, yardimci=p.yardimci_sira!=null;
    if (!yonetici && !yardimci && !p.bakan_miyim) return '';
    const performans = p.performans||[];
    const baslik = `<div class="kart cb-yrd-masasi"><h2>Cumhurbaşkanı Yardımcıları · Yönetim Masası</h2>
      <p class="alt">Bakanlıklara görev ve proje verilir, yanıtlar izlenir, karar taslakları onaya sunulur. Harcama, atama ve kararname yetkisi Cumhurbaşkanında kalır.</p>
      ${p.parlamenter?'<p class="alt">Parlamenter sistemde koordinasyon yetkisi Başbakandadır; yardımcıların geçmiş dosyaları yalnız görüntülenir.</p>':''}
      ${(p.alanlar||[]).map(a=>{const perf=performans.find(x=>x.sira===a.sira)||{};
        return `<div class="liste-satir"><div class="orta"><b>${a.sira}. Yardımcı: ${e(a.kad||'Boş makam')}</b>
          <div class="kucuk">${e(ALAN[a.alan]||a.alan)} · Performans ${Number(perf.puan??50)}/100 · Tamamlanan ${Number(perf.tamamlanan||0)} · Geciken ${Number(perf.geciken||0)}</div></div>
          ${yonetici?`<button class="rozet altin" onclick="cbYrdAlanSec(${Number(a.sira)})">Alan belirle</button>`:''}</div>`;
      }).join('')}
      ${yonetici?`<p class="kucuk" style="margin-top:8px">Sınırlı vekâlet: ${p.vekalet?`${Number(p.vekalet.sira)}. yardımcı · ${tarihYaz(p.vekalet.bitis)} tarihine kadar`:'Yok'}</p>
        ${btn('Vekâlet ver veya kaldır','cbYrdVekaletSec()')}`:''}
      ${yardimci&&!p.parlamenter?btn('Yeni görev, toplantı veya öneri oluştur','cbYrdDosyaAc()','altin'):''}</div>`;
    const dosyalar=p.dosyalar||[];
    const dosyaHtml = dosyalar.map(d=>{
      const oylar=d.oylar||[];
      const bana=d.hedef===kendiKad();
      const bakanToplanti=p.kabine_miyim && d.tur==='toplanti';
      const bakanKriz=p.kabine_miyim && d.tur==='kriz'&&!d.bakanlik;
      const benYardimci=yardimci&&d.yardimci===kendiKad();
      const yanitVerebilir=['bekliyor','calisiliyor'].includes(d.durum)&&(
        bana||(benYardimci&&['toplanti','kriz','yerel'].includes(d.tur))||bakanToplanti||bakanKriz);
      const vekil=p.vekalet&&p.vekalet.sira===p.yardimci_sira&&d.sira!==p.yardimci_sira;
      const onaylayabilir=d.durum==='onay_bekliyor'&&(yonetici||(vekil&&d.tur!=='kararname'));
      return `<details class="vekil-bakanlik" style="margin-top:9px"><summary><b>#${Number(d.id)} · ${e(d.baslik)}</b>
         <span class="kucuk"> · ${e(DURUM[d.durum]||d.durum)}</span></summary>
         <div style="padding:10px 0"><div class="kucuk">${e(TUR[d.tur]||d.tur)} · ${e(d.yardimci||'')} · ${e(d.bakanlik||d.il||'Ülke geneli')} · Son tarih ${tarihYaz(d.son_tarih)}</div>
         <p style="margin-top:8px;white-space:pre-wrap">${e(d.aciklama)}</p>
         ${d.yanit?`<p class="alt">Son yanıt: ${e(d.yanit)}</p>`:''}
         ${d.tur==='kararname'?`<p class="kucuk">Kararname türü: ${e(d.veri?.tur||'serbest')}${d.veri?.veri?.miktar?' · Tutar: '+e(String(d.veri.veri.miktar)):''}</p>`:''}
         ${d.tur==='toplanti'?`<p class="alt">Kabine oyları: ${oylar.filter(x=>x.oy).length} kabul · ${oylar.filter(x=>!x.oy).length} ret</p>
           ${oylar.map(o=>`<div class="kucuk">${e(o.kad)}: ${o.oy?'Kabul':'Ret'} — ${e(o.gerekce)}</div>`).join('')}
           ${['bekliyor','calisiliyor'].includes(d.durum)&&(yonetici||yardimci||p.kabine_miyim)?btn('Toplantıda oy ve görüş bildir',`cbYrdToplantiOyla(${Number(d.id)})`):''}`:''}
         ${yanitVerebilir?btn('İlerleme veya sonuç bildir',`cbYrdDosyaYanit(${Number(d.id)})`):''}
         ${onaylayabilir?`${btn('Onayla',`cbYrdDosyaKarar(${Number(d.id)},true)`,'altin')}
           ${btn('Reddet',`cbYrdDosyaKarar(${Number(d.id)},false)`,'tehlike')}`:''}
         </div></details>`;
    }).join('');
    return baslik+`<div class="kart cb-yrd-dosyalar"><h2>Hükümet görev dosyaları (${dosyalar.length})</h2>
      <p class="alt">Bakanlar ve belediye başkanları kendilerine gönderilen işleri buradan yanıtlar. Onay bekleyen ekonomi önerilerini Cumhurbaşkanı karara bağlar.</p>
      ${dosyaHtml||'<p class="alt">Henüz görev dosyası açılmadı.</p>'}</div>`;
  }

  async function yenile() { if (typeof devletEkrani==='function') await devletEkrani(); }
  window.cbYrdAlanSec = function (sira) {
    const a=(sonPanel?.alanlar||[]).find(x=>x.sira===sira);
    const m=modal(`<h3>${sira}. Yardımcının görev alanı</h3><p class="alt">Seçilen alan bakanlıklara görev gönderme yetkisini sınırlar.</p>
      <div class="alan"><label>Sorumluluk alanı</label><select id="cya">${ALAN_SEC}</select></div><button class="btn altin" id="cykaydet">Kaydet</button>`);
    $('#cya',m).value=a?.alan||'genel';
    $('#cykaydet',m).onclick=async()=>{try{await islem(()=>API.rpc('cb_yrd_alan_ayarla',{p_sira:sira,p_alan:$('#cya',m).value}),'Görev alanı güncellendi.');modalKapat();await yenile();}catch(_){}};
  };
  window.cbYrdVekaletSec = function () {
    const m=modal(`<h3>Sınırlı koordinasyon vekâleti</h3><p class="alt">Yardımcı, başka yardımcının ekonomik önerisini değerlendirebilir. Atama, kararname ve para harcama yetkisi verilmez. Cumhurbaşkanı değişirse geçersizdir.</p>
      <div class="alan"><label>Yardımcı</label><select id="cyvs">${(sonPanel?.alanlar||[]).filter(a=>a.kad).map(a=>`<option value="${a.sira}">${a.sira}. ${e(a.kad)}</option>`).join('')}</select></div>
      <div class="alan"><label>Süre</label><select id="cyvh"><option value="0">Mevcut vekâleti kaldır</option><option value="1">1 saat</option><option value="3">3 saat</option><option value="6">6 saat</option><option value="12">12 saat</option><option value="24">24 saat</option></select></div>
      <button class="btn altin" id="cyvg">Uygula</button>`);
    $('#cyvh',m).value='3';
    $('#cyvg',m).onclick=async()=>{try{await islem(()=>API.rpc('cb_yrd_vekalet_ayarla',{p_sira:+$('#cyvs',m).value,p_saat:+$('#cyvh',m).value}),'Vekâlet ayarı güncellendi.');modalKapat();await yenile();}catch(_){}};
  };
  window.cbYrdDosyaAc = function () {
    if (!sonPanel?.yardimci_sira||sonPanel.parlamenter) return;
    const bakanlar=bakanlikSecenek(sonPanel);
    const iller=(typeof VERI!=='undefined'&&Array.isArray(VERI.iller)?VERI.iller:[]).slice().sort((a,b)=>a.ad.localeCompare(b.ad,'tr'));
    const m=modal(`<h3>Yeni Cumhurbaşkanlığı koordinasyon dosyası</h3>
      <div class="alan"><label>İşlem</label><select id="cytur">${Object.entries(TUR).map(([k,v])=>`<option value="${k}">${e(v)}</option>`).join('')}</select></div>
      <div class="alan"><label>Başlık</label><input id="cybas" maxlength="120" placeholder="En az 5 karakter"></div>
      <div class="alan"><label>Gerekçe, çalışma veya toplantı gündemi</label><textarea id="cyac" maxlength="2000" rows="5" placeholder="En az 15 karakter"></textarea></div>
      <div class="alan" id="cybakanalan"><label>Sorumlu bakanlık</label><select id="cybakan"><option value="">Tüm bakanlıklar / seçilmedi</option>${bakanlar.map(([k,v])=>`<option value="${k}">${e(v)}</option>`).join('')}</select></div>
      <div class="alan" id="cyilalan"><label>İl</label><select id="cyil"><option value="">Ülke geneli</option>${iller.map(i=>`<option value="${Number(i.id)}">${e(i.ad)}</option>`).join('')}</select></div>
      <div class="alan" id="cykalan"><label>Kararname türü</label><select id="cykt"><option value="serbest">Serbest karar (mali etkisi yok)</option><option value="odenek">Bakanlığa ek ödenek</option><option value="il_destek">İl kalkınma desteği</option></select></div>
      <div class="alan" id="cymalan"><label>Kararname tutarı (milyar ₺, 1-30)</label><input id="cymik" type="number" min="1" max="30" value="5"></div>
      <div class="alan"><label>Hedef süre</label><select id="cygun"><option value="1">1 gün</option><option value="3" selected>3 gün</option><option value="7">7 gün</option><option value="14">14 gün</option></select></div>
      <div class="kucuk" id="cybilgi"></div><button class="btn altin" id="cygonder">Dosyayı oluştur</button>`);
    const form=()=>{
      const tur=$('#cytur',m).value, kt=$('#cykt',m).value;
      $('#cybakanalan',m).style.display=['gorev','proje','kriz'].includes(tur)||(tur==='kararname'&&kt==='odenek')?'':'none';
      $('#cyilalan',m).style.display=['yerel','proje','kriz'].includes(tur)||(tur==='kararname'&&kt==='il_destek')?'':'none';
      $('#cykalan',m).style.display=tur==='kararname'?'':'none';
      $('#cymalan',m).style.display=tur==='kararname'&&kt!=='serbest'?'':'none';
      $('#cybilgi',m).textContent=tur==='kararname'?'Taslak Cumhurbaşkanının imzasıyla mevcut kararname motorunda yürürlüğe girer.':
        tur==='aciklama'?'Günde bir basın açıklaması Gündem ve resmî haber akışına girer.':
        tur==='toplanti'?'Bakanlara toplantı çağrısı ve gündem bildirimi gönderilir.':'Bakan veya belediye başkanı görev dosyasına yanıt verebilir.';
    };
    $('#cytur',m).onchange=form;$('#cykt',m).onchange=form;form();
    $('#cygonder',m).onclick=async()=>{
      const tur=$('#cytur',m).value, kt=$('#cykt',m).value;
      const bakanlik=(!$('#cybakanalan',m).style.display&&$('#cybakan',m).value)||null;
      const il=(!$('#cyilalan',m).style.display&&+$('#cyil',m).value)||null;
      if(['gorev','proje'].includes(tur)&&!bakanlik) return toast('Bakanlık seçmelisin.',true);
      if(tur==='kararname'&&kt==='odenek'&&!bakanlik) return toast('Ödenek için bakanlık seçmelisin.',true);
      if((tur==='yerel'||(tur==='kararname'&&kt==='il_destek'))&&!il) return toast('İl seçmelisin.',true);
      const miktar=+$('#cymik',m).value;
      if(tur==='kararname'&&kt!=='serbest'&&(!Number.isFinite(miktar)||miktar<1||miktar>30)) return toast('Tutar 1-30 milyar ₺ olmalı.',true);
      const veri=tur==='kararname'?{tur:kt,veri:kt==='odenek'?{miktar,bakanlik}:kt==='il_destek'?{miktar,il_id:il}:{}}:{};
      try{await islem(()=>API.rpc('cb_yrd_dosya_ac',{p_tur:tur,p_baslik:$('#cybas',m).value,p_aciklama:$('#cyac',m).value,
        p_bakanlik:bakanlik,p_il:il,p_gun:+$('#cygun',m).value,p_veri:veri}),'Dosya açıldı.');modalKapat();await yenile();}catch(_){}
    };
  };
  window.cbYrdDosyaYanit = function (id) {
    const m=modal(`<h3>#${id} · Görev yanıtı</h3><div class="alan"><label>Durum</label><select id="cydur"><option value="calisiliyor">Çalışılıyor</option><option value="tamamlandi">Tamamlandı</option></select></div>
      <div class="alan"><label>Açıklama ve sonuç</label><textarea id="cyyan" rows="4" maxlength="1000" placeholder="Ne yapıldığını somut olarak anlat"></textarea></div>
      <button id="cyy" class="btn altin">Yanıtla</button>`);
    $('#cyy',m).onclick=async()=>{try{await islem(()=>API.rpc('cb_yrd_dosya_yanitla',{p_id:id,p_durum:$('#cydur',m).value,p_yanit:$('#cyyan',m).value}),'Görev güncellendi.');modalKapat();await yenile();}catch(_){}};
  };
  window.cbYrdToplantiOyla = function (id) {
    const m=modal(`<h3>#${id} · Kabine görüşü</h3><div class="alan"><label>Oy</label><select id="cyoy"><option value="true">Kabul</option><option value="false">Ret</option></select></div>
      <div class="alan"><label>Görüşün</label><textarea id="cygor" maxlength="500" rows="3" placeholder="En az 10 karakter"></textarea></div><button id="cyok" class="btn altin">Oyumu kaydet</button>`);
    $('#cyok',m).onclick=async()=>{try{await islem(()=>API.rpc('cb_yrd_toplanti_oyla',{p_id:id,p_oy:$('#cyoy',m).value==='true',p_gerekce:$('#cygor',m).value}),'Kabine oyun kaydedildi.');modalKapat();await yenile();}catch(_){}};
  };
  window.cbYrdDosyaKarar = async function (id,kabul) {
    const dosya=(sonPanel?.dosyalar||[]).find(d=>d.id===id);
    const uyari=kabul&&dosya?.tur==='kararname'?'Onaylarsan kararname derhal yürürlüğe girer; mali etkiler ve anayasal günlük sınır uygulanır.':'Bu karar dosyası için seçimini onaylıyor musun?';
    if(!await onayla(kabul?'Dosyayı onayla':'Dosyayı reddet',uyari,kabul?'Onayla':'Reddet',!kabul))return;
    try{await islem(()=>API.rpc('cb_yrd_dosya_karar',{p_id:id,p_kabul:kabul,p_gerekce:null}),kabul?'Onaylandı.':'Reddedildi.');await yenile();}catch(_){}
  };

  /* ---- Cumhurbaşkanlığı makam kimliği (30.10.2026): mühür, makam plakaları, resmî yazı biçiminde teklif ---- */
  const MUHUR = '<svg viewBox="0 0 48 48" aria-hidden="true"><circle cx="24" cy="24" r="22" fill="none" stroke="currentColor" stroke-width="1.3" opacity=".6"/><circle cx="24" cy="24" r="18.6" fill="none" stroke="currentColor" stroke-width=".8" stroke-dasharray="1.1 2.1" opacity=".7"/>'
    + '<path d="M24 11.5l1.4 2.9 3.2.5-2.3 2.2.5 3.2-2.8-1.5-2.8 1.5.5-3.2-2.3-2.2 3.2-.5z" fill="currentColor"/><path d="M14 34.5h20M16 34.5v-9M32 34.5v-9M21.3 34.5v-9M26.7 34.5v-9M13.5 25.5L24 20l10.5 5.5z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/></svg>';
  const KOLTUK = '<svg viewBox="0 0 48 48" aria-hidden="true"><path d="M15 21V12.5A3.5 3.5 0 0 1 18.5 9h11a3.5 3.5 0 0 1 3.5 3.5V21M11 22.5h26v8H11zM14 30.5V38M34 30.5V38" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  const SIRA_AD = { 1:'Birinci', 2:'İkinci' };
  const TRH = new Intl.DateTimeFormat('tr-TR',{timeZone:'Europe/Istanbul',day:'numeric',month:'long',year:'numeric'});
  const trh = t => { try { return TRH.format(new Date(t)); } catch (_) { return ''; } };
  const portreYap = (kad,renk,boy) => { try { return portre(kad,renk,boy); } catch (_) { return `<span class="cbm-bas">${e(String(kad||'?').slice(0,2).toLocaleUpperCase('tr-TR'))}</span>`; } };
  function tazele(k){ try { if (typeof portreleriTazele==='function') portreleriTazele(k); } catch (_) {} }

  function serit(alt, baslik) {
    return `<div class="cbm-serit"><span class="cbm-muhur">${MUHUR}</span><div><small>${e(alt)}</small><b>${e(baslik)}</b></div></div>`;
  }
  function atamaHtml(y) {
    if (!y || !y.cb_miyim) return '';
    const bek=y.bekleyen||[];
    const plaka = s => {
      const b=bek.find(x=>x.sira===s.sira), sira=Number(s.sira), renk=s.parti&&s.parti.renk;
      return `<div class="cbm-plaka${s.kad?'':' bos'}">
        <div class="cbm-sira"><span>${sira}</span>${SIRA_AD[sira]||''} Yardımcı</div>
        <div class="cbm-kisi">${s.kad?`<button type="button" class="cbm-portre" onclick="oyuncuKart('${e(s.kad)}')" style="--pr:${e(renk||'#8a93b3')}">${portreYap(s.kad,renk,58)}</button>`:`<span class="cbm-koltuk">${KOLTUK}</span>`}
          <b>${s.kad?e(s.kad):'Makam boş'}</b>
          <small>${s.kad?(s.parti?e(s.parti.kisa):'Bağımsız')+(s.bas?' · '+e(trh(s.bas))+"'den beri":''):'Atama bekliyor'}</small></div>
        ${b?`<div class="cbm-bekle">Teklif yazısı iletildi<br><b>${e(b.aday)}</b></div>`:''}
        <div class="cbm-eylem">
          <button type="button" class="cbm-btn ana" onclick="cbYrdAtaModal(${sira})">${s.kad?'Değiştir':'Ata'}</button>
          ${s.kad?`<button type="button" class="cbm-btn kirmizi" onclick="cbYrdGorevdenAl(${sira},'${e(s.kad)}')">Görevden al</button>`:''}
          ${b?`<button type="button" class="cbm-btn" onclick="cbYrdTeklifGeri(${sira})">Teklifi geri çek</button>`:''}
        </div></div>`;
    };
    return `<section class="cbm">${serit('Türkiye Cumhuriyeti Cumhurbaşkanlığı','Cumhurbaşkanı Yardımcıları')}
      <div class="cbm-plakalar">${(y.yardimcilar||[]).map(plaka).join('')}</div>
      <p class="cbm-dip">Atama, oyuncuya resmî teklif yazısıyla bildirilir; kabul ettiği an göreve başlar ve diğer makamlarını korur. Aynı makama yeni teklif, öncekinin yerine geçer.</p></section>`;
  }
  function yaziHtml(o) {
    return `<article class="cbm-yazi">
      <header><span class="cbm-muhur">${MUHUR}</span><div><b>T.C.</b><b>CUMHURBAŞKANLIĞI</b><small>Özel Kalem Müdürlüğü</small></div></header>
      <div class="cbm-kunye"><span>Sayı : ${e(o.sayi)}</span><span>${e(o.tarih)}</span></div>
      <div class="cbm-kunye"><span>Konu : ${e(o.konu)}</span></div>
      <p class="cbm-hitap">Sayın ${e(o.alici)},</p>
      <p>${o.govde}</p>
      <div class="cbm-imza"><span>${e(o.imzalayan)}</span><small>Cumhurbaşkanı</small></div>
    </article>`;
  }
  function teklifHtml(l) {
    if (!l || !l.length) return '';
    const ben=kendiKad()||'';
    return `<section class="cbm cbm-teklif">${serit('Size resmî yazı ulaştı','Atama teklifi')}
      ${l.map(t=>yaziHtml({ sayi:`CB.ÖK-${new Date(t.zaman||Date.now()).getFullYear()}/${Number(t.id)}`, tarih:trh(t.zaman||Date.now()),
        konu:`${SIRA_AD[t.sira]||t.sira+'.'} Cumhurbaşkanı Yardımcılığı`, alici:ben, imzalayan:t.teklif_eden,
        govde:`Anayasa ve Cumhurbaşkanlığı kararnameleri çerçevesinde, <b>${Number(t.sira)}. Cumhurbaşkanı Yardımcılığı</b> görevine atanmanız uygun görülmüştür. Görevi kabul etmeniz hâlinde mevcut makamlarınız korunacaktır.<br><br>Bilgilerinize rica ederim.` })
        +`<div class="cbm-eylem genis"><button type="button" class="cbm-btn ana" onclick="cbYrdTeklifYanit(${Number(t.id)},true)">Görevi kabul ediyorum</button>
          <button type="button" class="cbm-btn" onclick="cbYrdTeklifYanit(${Number(t.id)},false)">Teşekkür ederek reddet</button></div>`).join('')}</section>`;
  }
  window.cbYrdTeklifKarti = teklifHtml;

  window.cbYrdAtaModal = function (sira) {
    if (![1,2].includes(sira)) return;
    const m=modal(`<div class="cbm-modal">${serit('Atama teklifi',`${sira}. Cumhurbaşkanı Yardımcısı`)}
      <p class="cbm-dip" style="margin:4px 0 10px">Aday seçin; teklif yazısını göndermeden önce önizleyeceksiniz.</p>
      <label class="cbm-ara"><input id="cyAra" autocapitalize="off" autocomplete="off" spellcheck="false" placeholder="Oyuncu adıyla arayın"></label>
      <div id="cyListe" class="cbm-liste"><div class="kucuk">Yükleniyor…</div></div></div>`);
    const kutu=$('#cyListe',m), inp=$('#cyAra',m); let z=null, son=[];
    const ara=async()=>{
      try{
        son=await API.rpc('cb_yardimcisi_adaylari',{p_ara:inp.value.trim()})||[];
        kutu.innerHTML=son.map(x=>`<button type="button" class="cbm-aday${x.uygun?'':' pasif'}" data-kad="${e(x.kad)}"${x.uygun?'':' disabled'}>
          <span class="cbm-aday-p" style="--pr:${e(x.parti&&x.parti.renk||'#8a93b3')}">${portreYap(x.kad,x.parti&&x.parti.renk,40)}</span>
          <span class="cbm-aday-m"><b>${e(x.kad)}</b><small>${[x.parti?x.parti.kisa:'Bağımsız',x.il,x.bakanlik?x.bakanlik.replace('Bakanlığı','Bakanı'):x.statu].filter(Boolean).map(e).join(' · ')}${x.engel?` · <i>${e(x.engel)}</i>`:''}</small></span>
          <span class="cbm-ok">›</span></button>`).join('')||'<div class="bos">Eşleşen oyuncu yok.</div>';
        tazele(kutu);
      }catch(err){kutu.innerHTML=`<div class="kucuk">${e(hataCevir(err.message))}</div>`;}
    };
    inp.oninput=()=>{clearTimeout(z);z=setTimeout(ara,250);};
    kutu.onclick=ev=>{
      const s=ev.target.closest('[data-kad]'); if(!s||s.disabled)return; const kad=s.dataset.kad;
      const govde=m.querySelector('.cbm-modal');
      govde.innerHTML=`${yaziHtml({ sayi:`CB.ÖK-${new Date().getFullYear()}/…`, tarih:trh(Date.now()), konu:`${SIRA_AD[sira]} Cumhurbaşkanı Yardımcılığı`, alici:kad, imzalayan:kendiKad()||'',
          govde:`Anayasa ve Cumhurbaşkanlığı kararnameleri çerçevesinde, <b>${sira}. Cumhurbaşkanı Yardımcılığı</b> görevine atanmanız uygun görülmüştür. Görevi kabul etmeniz hâlinde mevcut makamlarınız korunacaktır.<br><br>Bilgilerinize rica ederim.` })}
        <div class="cbm-eylem genis"><button type="button" class="cbm-btn ana" id="cyGonder">Mühürle ve gönder</button><button type="button" class="cbm-btn" id="cyGeri">Başka aday seç</button></div>`;
      $('#cyGeri',m).onclick=()=>{modalKapat();window.cbYrdAtaModal(sira);};
      $('#cyGonder',m).onclick=async()=>{
        const b=$('#cyGonder',m); b.disabled=true; b.classList.add('muhur');
        try{await islem(()=>API.rpc('cb_yardimcisi_ata',{p_sira:sira,p_kad:kad}),`Teklif yazısı ${kad} adlı oyuncuya iletildi.`);modalKapat();await yenile();}catch(_){b.disabled=false;b.classList.remove('muhur');}
      };
    };
    ara(); setTimeout(()=>{try{inp.focus();}catch(_){}} ,60);
  };
  window.cbYrdGorevdenAl = async function (sira,kad) {
    if(!await onayla('Görevden alma kararı',`${kad}, ${sira}. Cumhurbaşkanı Yardımcılığı görevinden alınacaktır. Karar kendisine resmî bildirimle iletilir; diğer makamları korunur.`,'Kararı imzala',true))return;
    try{await islem(()=>API.rpc('cb_yardimcisi_gorevden_al',{p_sira:sira}),'Görevden alma kararı yürürlüğe girdi.');await yenile();}catch(_){}
  };
  window.cbYrdTeklifGeri = async function (sira) {
    if(!await onayla('Teklifi geri çek',`${sira}. Cumhurbaşkanı Yardımcılığı için gönderilen teklif yazısı geri çekilecek.`,'Geri çek'))return;
    try{await islem(()=>API.rpc('cb_yardimcisi_teklif_geri',{p_sira:sira}),'Teklif yazısı geri çekildi.');await yenile();}catch(_){}
  };

  (function stil(){
    if (document.getElementById('cbmStil')) return;
    const G='#d9b25b', G2='#e8cf8f';
    const css=`
.cbm{position:relative;margin:12px 0;padding:16px 14px 14px;border-radius:18px;background:linear-gradient(180deg,rgba(217,178,91,.07),rgba(217,178,91,0) 46%),var(--panel,#151E3D);border:1px solid rgba(217,178,91,.26);box-shadow:0 18px 40px -26px rgba(0,0,0,.8),inset 0 1px 0 rgba(255,255,255,.04);overflow:hidden}
.cbm::before{content:"";position:absolute;inset:6px;border:1px solid rgba(217,178,91,.10);border-radius:13px;pointer-events:none}
.cbm-serit{display:flex;align-items:center;gap:12px;padding-bottom:12px;margin-bottom:12px;border-bottom:1px solid rgba(217,178,91,.22)}
.cbm-serit small{display:block;font-size:11.5px;letter-spacing:.5px;color:#c9b88f}
.cbm-serit b{display:block;font-family:var(--disp);font-size:21px;font-weight:800;color:#f3ead2;letter-spacing:.2px;line-height:1.15}
.cbm-muhur{flex:none;width:46px;height:46px;border-radius:50%;display:grid;place-items:center;color:${G};background:radial-gradient(circle at 50% 30%,rgba(217,178,91,.22),rgba(217,178,91,.04));box-shadow:0 0 0 1px rgba(217,178,91,.4) inset,0 8px 20px -10px rgba(217,178,91,.6)}
.cbm-muhur svg{width:40px;height:40px}
.cbm-plakalar{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.cbm-plaka{position:relative;display:flex;flex-direction:column;align-items:center;text-align:center;padding:12px 10px;border-radius:14px;background:rgba(8,12,30,.45);border:1px solid rgba(217,178,91,.2)}
.cbm-plaka.bos{border-style:dashed;background:rgba(8,12,30,.25)}
.cbm-sira{display:flex;align-items:center;gap:6px;font-size:11.5px;letter-spacing:.4px;color:#c9b88f}
.cbm-sira span{width:20px;height:20px;border-radius:50%;display:grid;place-items:center;font-family:var(--disp);font-weight:800;font-size:12px;color:#1b1607;background:linear-gradient(135deg,${G2},#b8913f)}
.cbm-kisi{display:flex;flex-direction:column;align-items:center;gap:3px;margin:10px 0 8px;min-width:0;width:100%}
.cbm-portre{padding:0;border:0;background:none;cursor:pointer;border-radius:50%;box-shadow:0 0 0 2px #0e1530,0 0 0 3.5px var(--pr),0 10px 22px -10px rgba(0,0,0,.8)}
.cbm-portre .portre,.cbm-portre svg.portre{width:58px!important;height:58px!important;border-radius:50%;display:block}
.cbm-koltuk{width:58px;height:58px;border-radius:50%;display:grid;place-items:center;color:rgba(217,178,91,.55);border:1px dashed rgba(217,178,91,.4)}.cbm-koltuk svg{width:30px;height:30px}
.cbm-kisi b{margin-top:5px;font-family:var(--disp);font-size:16.5px;color:#f3ead2;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cbm-plaka.bos .cbm-kisi b{color:#a9b2cf}
.cbm-kisi small{font-size:11.5px;color:#a9b2cf;line-height:1.35}
.cbm-bas{width:58px;height:58px;border-radius:50%;display:grid;place-items:center;background:#283563;font-weight:800}
.cbm-bekle{width:100%;margin-bottom:8px;padding:6px 8px;border-radius:9px;font-size:11.5px;line-height:1.35;color:#c9b88f;background:rgba(217,178,91,.08);border:1px solid rgba(217,178,91,.2)}.cbm-bekle b{color:${G2}}
.cbm-eylem{display:flex;flex-direction:column;gap:6px;width:100%;margin-top:auto}
.cbm-eylem.genis{flex-direction:row;margin-top:12px}.cbm-eylem.genis .cbm-btn{flex:1}
.cbm-btn{min-height:38px;padding:0 10px;border-radius:10px;border:1px solid rgba(217,178,91,.34);background:rgba(217,178,91,.06);color:${G2};font:inherit;font-size:13.5px;font-weight:700;cursor:pointer;-webkit-tap-highlight-color:transparent}
.cbm-btn:active{transform:scale(.97)}
.cbm-btn.ana{border:0;background:linear-gradient(135deg,${G2},#b8913f);color:#1b1607;box-shadow:0 8px 18px -10px rgba(217,178,91,.9)}
.cbm-btn.kirmizi{border-color:rgba(240,69,75,.38);background:rgba(240,69,75,.07);color:#ff8f94}
.cbm-btn.muhur{animation:cbmMuhur .6s ease}
@keyframes cbmMuhur{40%{transform:scale(.9) rotate(-3deg)}100%{transform:none}}
.cbm-dip{margin:12px 2px 0;font-size:12px;line-height:1.5;color:#a9b2cf}
.cbm-yazi{position:relative;padding:18px 16px 16px;border-radius:6px;background:#f6f2e7;color:#26221a;font-family:Georgia,"Times New Roman",serif;box-shadow:0 18px 36px -18px rgba(0,0,0,.85),0 0 0 1px rgba(0,0,0,.08) inset}
.cbm-yazi::after{content:"";position:absolute;inset:0;border-radius:6px;pointer-events:none;background:repeating-linear-gradient(0deg,rgba(0,0,0,.012) 0 2px,transparent 2px 4px)}
.cbm-yazi header{display:flex;flex-direction:column;align-items:center;text-align:center;gap:6px;margin-bottom:12px}
.cbm-yazi header .cbm-muhur{color:#9c7a2c;background:none;box-shadow:0 0 0 1px rgba(156,122,44,.45) inset}
.cbm-yazi header b{display:block;font-size:13.5px;letter-spacing:1.4px;font-weight:700}.cbm-yazi header small{display:block;font-size:12px;color:#5f584a;font-style:italic}
.cbm-kunye{display:flex;justify-content:space-between;gap:10px;font-size:12.5px;color:#4b4538;margin-top:2px}
.cbm-hitap{margin:14px 0 8px!important;font-weight:700}
.cbm-yazi p{margin:0;font-size:15px;line-height:1.6;color:#26221a}
.cbm-imza{display:flex;flex-direction:column;align-items:flex-end;margin-top:16px;padding-top:8px}
.cbm-imza span{font-family:"Snell Roundhand","Segoe Script","Brush Script MT",cursive;font-size:22px;color:#1f3a7a;line-height:1;transform:rotate(-4deg)}
.cbm-imza small{margin-top:6px;padding-top:4px;border-top:1px solid #8e8572;min-width:120px;text-align:center;font-size:12px;color:#4b4538;letter-spacing:.4px}
.cbm-teklif .cbm-yazi{margin-bottom:2px}
.cbm-modal .cbm-serit{margin-top:-2px}
.cbm-ara{display:block}.cbm-ara input{width:100%;height:44px;padding:0 14px;border-radius:12px;border:1px solid rgba(217,178,91,.3);background:rgba(8,12,30,.5);color:var(--txt);font:inherit;font-size:15px;outline:none;box-sizing:border-box}
.cbm-ara input:focus{border-color:rgba(217,178,91,.7)}
.cbm-liste{max-height:48vh;overflow:auto;margin-top:10px;display:flex;flex-direction:column;gap:6px}
.cbm-aday{display:flex;align-items:center;gap:11px;width:100%;padding:9px 10px;border-radius:12px;border:1px solid var(--line,rgba(164,184,255,.1));background:rgba(255,255,255,.03);color:var(--txt);font:inherit;text-align:left;cursor:pointer}
.cbm-aday:active{background:rgba(217,178,91,.08)}.cbm-aday.pasif{opacity:.5;cursor:default}
.cbm-aday-p{flex:none;border-radius:50%;box-shadow:0 0 0 2px var(--pr)}.cbm-aday-p .portre,.cbm-aday-p svg.portre{width:40px!important;height:40px!important;border-radius:50%;display:block}.cbm-aday-p .cbm-bas{width:40px;height:40px;font-size:13px}
.cbm-aday-m{flex:1;min-width:0;display:flex;flex-direction:column}.cbm-aday-m b{font-size:15px}.cbm-aday-m small{font-size:12px;color:var(--mut,#98A4C4);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.cbm-aday-m i{font-style:normal;color:${G2}}
.cbm-ok{color:${G};font-size:22px}
.cb-yrd-masasi,.cb-yrd-dosyalar{border:1px solid rgba(217,178,91,.22)!important;background:linear-gradient(180deg,rgba(217,178,91,.05),transparent 40%),var(--panel,#151E3D)!important}
.cb-yrd-masasi h2,.cb-yrd-dosyalar h2{font-family:var(--disp);color:#f3ead2;padding-bottom:8px;border-bottom:1px solid rgba(217,178,91,.2)}
@media (max-width:340px){.cbm-plakalar{grid-template-columns:1fr}}`;
    const st=document.createElement('style'); st.id='cbmStil'; st.textContent=css; (document.head||document.documentElement).appendChild(st);
  })();
  window.cbYrdTeklifYanit = async function (id,kabul) {
    if(!await onayla(kabul?'Göreve kabul':'Teklife ret',kabul?'Cumhurbaşkanı Yardımcılığı görevini kabul ediyorsunuz. Karar resmî olarak kayda geçer; diğer makamlarınız korunur.':'Teklif yazısı teşekkürle reddedilecek ve Cumhurbaşkanına bildirilecek.',kabul?'Kabul ediyorum':'Reddet',!kabul))return;
    try{await islem(()=>API.rpc('cb_yardimcisi_yanit',{p_teklif:id,p_kabul:kabul}),kabul?'Cumhurbaşkanı Yardımcılığı görevine başladınız.':'Teklif reddedildi.');try{await durumYenile();}catch(_){}
      if(document.querySelector('.ust h1')&&document.querySelector('.ust h1').textContent.trim()==='Bildirimler'&&typeof bildirimEkrani==='function')bildirimEkrani(); else await yenile();}catch(_){}
  };

  const asil=hukumetHtml;
  window.hukumetHtml=hukumetHtml=async function () {
    const govde=await asil.apply(this,arguments);
    const [panel,yrd,tek]=await Promise.all([
      API.rpc('cb_yrd_panel').catch(()=>null),
      API.rpc('cb_yardimcilari').catch(()=>null),
      API.rpc('cb_yardimcisi_tekliflerim').catch(()=>[])
    ]);
    let ust='';
    try { ust=teklifHtml(tek)+atamaHtml(yrd)+(panel?cbYrdHtml(panel):''); } catch (_) {} // Yeni SQL henüz yüklenmediyse mevcut oyun kesintisiz çalışır.
    return ust+govde;
  };
})();
