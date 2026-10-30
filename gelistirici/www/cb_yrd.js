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

  /* ---- Atama / görevden alma (30.10.2026): CB tek dokunuşla atar, değiştirir, görevden alır ---- */
  function atamaHtml(y) {
    if (!y || !y.cb_miyim) return '';
    const bek=y.bekleyen||[];
    return `<div class="kart cb-yrd-atama"><h2>Cumhurbaşkanı Yardımcıları</h2>
      <p class="alt" style="margin-bottom:6px">İki yardımcı atayabilirsin. Seçtiğin oyuncuya teklif gider; kabul edince göreve başlar, diğer makamlarını korur. Yeni teklif aynı makamdaki eski teklifin yerine geçer.</p>
      ${(y.yardimcilar||[]).map(s=>{const b=bek.find(x=>x.sira===s.sira); const sira=Number(s.sira);
        return `<div class="liste-satir" style="display:block"><div class="orta"><b>${sira}. Cumhurbaşkanı Yardımcısı</b>
          <div class="kucuk">${s.kad?`<a class="bag" href="#" onclick="oyuncuKart('${e(s.kad)}');return false">${e(s.kad)}</a> · ${s.parti?e(s.parti.kisa):'Bağımsız'}`:'Boş makam'}
          ${b?`<span style="color:var(--gold2)"> · Teklif bekleniyor: ${e(b.aday)}</span>`:''}</div></div>
          <div class="satir" style="gap:8px;margin-top:8px">
            <button class="btn ${s.kad?'ikinci':'altin'}" style="flex:1;margin:0" onclick="cbYrdAtaModal(${sira})">${s.kad?'Değiştir':'Ata'}</button>
            ${s.kad?`<button class="btn tehlike" style="flex:1;margin:0" onclick="cbYrdGorevdenAl(${sira},'${e(s.kad)}')">Görevden al</button>`:''}
            ${b?`<button class="btn ikinci" style="flex:1;margin:0" onclick="cbYrdTeklifGeri(${sira})">Teklifi geri çek</button>`:''}
          </div></div>`;}).join('')}</div>`;
  }
  function teklifHtml(l) {
    if (!l || !l.length) return '';
    return `<div class="olay basvuru"><div class="baslik"><b>Cumhurbaşkanı Yardımcılığı teklifi</b><span class="rozet altin">Yanıt bekliyor</span></div>
      ${l.map(t=>`<p class="alt" style="margin-top:6px">Cumhurbaşkanı ${e(t.teklif_eden)} seni ${Number(t.sira)}. Cumhurbaşkanı Yardımcısı olarak atamak istiyor. Kabul edersen mevcut makamların korunur.</p>
        <div class="satir" style="gap:8px;margin-top:8px">
          <button class="btn altin" style="flex:1;margin:0" onclick="cbYrdTeklifYanit(${Number(t.id)},true)">Kabul et</button>
          <button class="btn ikinci" style="flex:1;margin:0" onclick="cbYrdTeklifYanit(${Number(t.id)},false)">Reddet</button></div>`).join('')}</div>`;
  }
  window.cbYrdTeklifKarti = teklifHtml;
  window.cbYrdAtaModal = function (sira) {
    if (![1,2].includes(sira)) return;
    const m=modal(`<h3 style="font-size:19px;font-weight:800">${sira}. Cumhurbaşkanı Yardımcısı</h3>
      <p class="alt">Listeden bir oyuncuya dokun; teklif hemen gönderilir.</p>
      <div class="alan"><label>Oyuncu ara</label><input id="cyAra" autocapitalize="off" autocomplete="off" spellcheck="false" placeholder="Kullanıcı adı"></div>
      <div id="cyListe" style="max-height:48vh;overflow:auto"><div class="kucuk">Yükleniyor…</div></div>`);
    const kutu=$('#cyListe',m), inp=$('#cyAra',m); let z=null;
    const ara=async()=>{
      try{
        const l=await API.rpc('cb_yardimcisi_adaylari',{p_ara:inp.value.trim()})||[];
        kutu.innerHTML=l.map(x=>`<div class="liste-satir" data-kad="${e(x.kad)}" style="cursor:pointer;${x.uygun?'':'opacity:.55'}"><div class="orta"><b>${e(x.kad)}</b> ${x.parti?`<span class="kucuk" style="color:${e(x.parti.renk)}">${e(x.parti.kisa)}</span>`:'<span class="kucuk">Bağımsız</span>'}
          <div class="kucuk">${e(x.il||'')} · ${e(x.statu||'')}${x.bakanlik?' · '+e(x.bakanlik.replace('Bakanlığı','Bakanı')):''}${x.engel?` · <span style="color:var(--gold2)">${e(x.engel)}</span>`:''}</div></div><span class="rozet altin">Teklif et</span></div>`).join('')||'<div class="bos">Eşleşen oyuncu yok.</div>';
      }catch(err){kutu.innerHTML=`<div class="kucuk">${e(hataCevir(err.message))}</div>`;}
    };
    inp.oninput=()=>{clearTimeout(z);z=setTimeout(ara,250);};
    kutu.onclick=async ev=>{
      const s=ev.target.closest('[data-kad]'); if(!s)return; const kad=s.dataset.kad;
      try{await islem(()=>API.rpc('cb_yardimcisi_ata',{p_sira:sira,p_kad:kad}),`${kad} adlı oyuncuya ${sira}. yardımcılık teklifi gönderildi.`);modalKapat();await yenile();}catch(_){}
    };
    ara(); setTimeout(()=>{try{inp.focus();}catch(_){}} ,60);
  };
  window.cbYrdGorevdenAl = async function (sira,kad) {
    if(!await onayla('Görevden al',`${kad}, ${sira}. Cumhurbaşkanı Yardımcılığı görevinden alınacak. Diğer makamları korunur.`,'Görevden al',true))return;
    try{await islem(()=>API.rpc('cb_yardimcisi_gorevden_al',{p_sira:sira}),'Yardımcı görevden alındı.');await yenile();}catch(_){}
  };
  window.cbYrdTeklifGeri = async function (sira) {
    try{await islem(()=>API.rpc('cb_yardimcisi_teklif_geri',{p_sira:sira}),'Teklif geri çekildi.');await yenile();}catch(_){}
  };
  window.cbYrdTeklifYanit = async function (id,kabul) {
    if(!await onayla('Cumhurbaşkanı Yardımcılığı',kabul?'Görevi kabul edersen diğer makamların korunur.':'Teklifi reddetmek istiyor musun?',kabul?'Kabul et':'Reddet',!kabul))return;
    try{await islem(()=>API.rpc('cb_yardimcisi_yanit',{p_teklif:id,p_kabul:kabul}),kabul?'Cumhurbaşkanı Yardımcısı olarak göreve başladın.':'Teklifi reddettin.');try{await durumYenile();}catch(_){}
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
