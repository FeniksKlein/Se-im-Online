/* Ekonomi merkezi: banka ve şirket rehberleri */
"use strict";
const vitTL=x=>tlYaz(Number(x)||0);
const vitSektor={tarim:"Tarım",sanayi:"Sanayi",teknoloji:"Teknoloji",ticaret:"Ticaret",insaat:"İnşaat",medya:"Medya",banka:"Banka"};
let vitSirketler=[];
async function bankaRehberiEkrani(){
 yukleniyor("Oyuncu bankaları");
 try{
 const [d,p]=await Promise.all([API.rpc("oyb_liste"),API.rpc("oyb_portfoy")]);
 const l=(d.bankalar||[]).sort((a,b)=>b.kasa-a.kasa);
 iskelet("Oyuncu bankaları",`
 <div class="kart vit-manset"><h2>🏦 Bankalar çarşısı</h2><p class="alt">Bankaları karşılaştır, sana uygun faizli mevduat veya kredi imkanını seç. Her bankanın kendi şubesi ve ayrı yönetimi var.</p>
 <div class="vit-dugme"><button class="btn altin" onclick="bankaKurEkrani()">+ Banka kur</button><button class="btn ikinci" onclick="ekranAc(bankaEkrani)">Devlet bankası</button></div></div>
 <div class="vit-ozet"><span><b>${l.length}</b> oyuncu bankası</span><span><b>${(p.mevduatlar||[]).filter(x=>!x.kapandi).length}</b> açık mevduatın</span></div>
 ${l.map(b=>`<button class="kart vit-banka" onclick="bankaDetayEkrani(${b.id})">
   <div class="vit-bas"><span class="vit-logo">🏦</span><span class="orta"><b>${e(b.ad)}</b><span class="kucuk">Banka kasası ${vitTL(b.kasa)} ${b.bankam?"· Ortağısın":""}</span></span><span class="ok">›</span></div>
   <div class="vit-stats"><span><small>1 saat mevduat</small><b>%${fmt(oybVadeOrani(b,1),2)}</b></span><span><small>7 gün mevduat</small><b>%${fmt(oybVadeOrani(b,168),2)}</b></span><span><small>Kredi / 24 saat</small><b>%${fmt(b.kredi_faiz,2)}</b></span></div>
 </button>`).join("")||'<div class="kart"><p class="alt">Henüz oyuncu bankası yok. İlk bankayı sen kurabilirsin.</p></div>'}
 <button class="btn altin" onclick="bankaPortfoyEkrani()">Mevduatlarım ve kredilerim</button>
 <p class="alt">Oyuncu bankalarında devlet garantisi bulunmaz. Yatırmadan önce bankanın vade sonunda ödeme gücünü kontrol et.</p>`,{geri:true});
 }catch(err){iskelet("Bankalar",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
async function bankaDetayEkrani(id){
 yukleniyor("Banka şubesi");
 try{
  const d=await API.rpc("oyb_liste"),b=(d.bankalar||[]).find(x=>x.id===id);
  if(!b){toast("Banka bulunamadı.",true);bankaRehberiEkrani();return;}
  iskelet(e(b.ad),`<div class="kart vit-manset"><h2>🏦 ${e(b.ad)}</h2>
    <div class="kv"><span>Banka kasası</span><b>${vitTL(b.kasa)}</b></div>
    <div class="kv"><span>Kredi faizi / 24 saat</span><b>%${fmt(b.kredi_faiz,2)}</b></div>
    ${b.bankam?`<button class="btn altin" onclick="oybYonetim(${id})">Bankamı yönet</button>`:""}</div>
  <div class="kart"><h2>Mevduat faiz tablosu</h2><p class="alt">Faiz oranları seçilen vadenin tamamı içindir.</p>
    ${[1,3,6,12,24,168].map(h=>`<div class="kv"><span>${oybVadeEtiket(h)}</span><b>%${fmt(oybVadeOrani(b,h),2)}</b></div>`).join("")}</div>
  <div class="kart"><h2>Mevduat yatır</h2>
    <div class="alan"><label>Vade</label><select id="oyb_saat_${id}" onchange="oybVadeOnizle(${id})">${[1,3,6,12,24,168].map(h=>`<option value="${h}">${oybVadeEtiket(h)} · %${fmt(oybVadeOrani(b,h),2)}</option>`).join("")}</select></div>
    <div class="alan"><label>Yatırılacak tutar (₺)</label><input id="oyb_tutar_${id}" type="number" min="1000" max="10000000" step="1000" value="1000" oninput="oybVadeOnizle(${id})"></div>
    <p class="alt" id="oyb_onizleme_${id}">Beklenen getiriyi ve ödeme gücünü kontrol et.</p>
    <button class="btn ikinci" onclick="oyuncuBankaTeklif(${id})">Getiriyi ve riski hesapla</button>
    <button class="btn altin" ${b.bankam?"disabled":""} onclick="oyuncuBankaYatir(${id})">Mevduat yatır</button></div>
  <div class="kart"><h2>Kredi başvurusu</h2><p class="alt">Kredi faiz oranı (24 saat): %${fmt(b.kredi_faiz,2)}. Başvuruyu banka sahibi onaylar.</p>
    <div class="alan"><label>Kredi tutarı</label><input id="oyb_ktutar_${id}" type="number" min="1000" max="500000" value="10000"></div>
    <div class="alan"><label>Kredi vadesi</label><select id="oyb_ksaat_${id}">${[1,3,6,12,24].map(h=>`<option value="${h}">${h} saat</option>`).join("")}</select></div>
    <button class="btn altin" ${b.bankam?"disabled":""} onclick="oybKrediBasvur(${id})">Kredi talebi gönder</button></div>
  <button class="btn ikinci" onclick="bankaRehberiEkrani()">Diğer bankaları gör</button>`,{geri:true});
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
 <div class="vit-dugme"><button class="btn altin" onclick="sirketYonetimEkrani()">Şirketlerim / Şirket kur</button><button class="btn ikinci" onclick="sirketPazarEkrani()">Satılık şirketler</button></div></div>
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
 try{const d=await API.rpc("sirket_liste"),l=(d.pazar||[]).filter(x=>x.sektor!=="banka");
 iskelet("Satılık şirketler",`<div class="kart"><h2>Satılık şirketler</h2></div>
 ${l.map(x=>`<div class="kart"><h3>${e(x.ad)}</h3><p class="alt">${e(vitSektor[x.sektor]||x.sektor)}</p><div class="kv"><span>Fiyat</span><b>${vitTL(x.fiyat)}</b></div><button class="btn altin" onclick="sirketPazarAl(${x.id})">Satın al</button></div>`).join("")||'<div class="kart">Satılık şirket bulunmuyor.</div>'}`,{geri:true});
 }catch(err){iskelet("Şirket pazarı",'<div class="kart">'+e(hataCevir(err.message))+'</div>',{geri:true});}
}
window.oyuncuBankaEkrani=bankaRehberiEkrani;
window.sirketEkrani=sirketVitrinEkrani;
