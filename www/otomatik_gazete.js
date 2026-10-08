/* Türkiye Gündem: doğrulanmış kayıtları aktaran ücretsiz, otomatik gazete. */
const TG_KAT={siyaset:"Siyaset",secim:"Seçimler",adaylar:"Adaylar",ittifak:"İttifak",ekonomi:"Ekonomi",meclis:"Meclis",yerel:"Yerel",gundem:"Gündem",bulten:"Bülten"};
const TG_RENK={siyaset:"🏛️",secim:"🗳️",adaylar:"🎤",ittifak:"🤝",ekonomi:"📈",meclis:"⚖️",yerel:"🏙️",gundem:"📰",bulten:"📌"};
let tgCache={};
function tgTarih(t){return t?new Date(t).toLocaleString("tr-TR",{dateStyle:"long",timeStyle:"short"}):"—"}
async function otomatikGazeteEkrani(kategori=null,offset=0){
 yukleniyor("Türkiye Gündem");
 try{
  const d=await API.rpc("ajans_haberler",{p_limit:30,p_kategori:kategori,p_offset:offset});
  const bas=d.manset||d.haberler[0],items=(d.haberler||[]).filter(x=>!bas||x.id!==bas.id);
  if(offset===0)tgCache={};(d.haberler||[]).forEach(x=>tgCache[x.id]=x);
  if(bas)tgCache[bas.id]=bas;
  const tabs=[[null,"Tümü"],...Object.entries(TG_KAT).map(([k,v])=>[k,v])];
  const tab=`<div class="tg-secimler">${tabs.map(([k,v])=>`<button class="tg-filtre ${k===kategori?"secili":""}" onclick="otomatikGazeteEkrani(${k?JSON.stringify(k):"null"},0)">${e(v)}</button>`).join("")}</div>`;
  const lead=bas?`<article class="tg-manset" onclick="tgHaberOku(${bas.id})" tabindex="0" role="button" onkeydown="if(event.key==='Enter')tgHaberOku(${bas.id})">
    <span class="tg-ust">SON DAKİKA / GÜNÜN MANŞETİ</span>
    <span class="tg-kategori">${TG_RENK[bas.kategori]||"📰"} ${e(TG_KAT[bas.kategori]||bas.kategori)}</span>
    <h2>${e(bas.baslik)}</h2><p>${e(bas.ozet)}</p>
    <div class="tg-meta">${tgTarih(bas.zaman)} · Haberin tamamını oku →</div>
  </article>`:"";
  const cards=items.map(h=>`<article class="tg-haber">
    <div class="tg-gorev">${TG_RENK[h.kategori]||"📰"} ${e(TG_KAT[h.kategori]||h.kategori)}${h.parti?" · "+e(h.parti):""}${h.il?" · "+e(h.il):""}</div>
    <h3>${e(h.baslik)}</h3><p>${e(h.ozet)}</p>
    <div class="tg-meta">${tgTarih(h.zaman)}</div>
    <button class="tg-oku" onclick="tgHaberOku(${h.id})">Haberin devamı →</button>
  </article>`).join("");
  iskelet("Türkiye Gündem",`
    <section class="tg-kapak"><div class="tg-saat">OYUNCU GAZETESİ DEĞİL · OTOMATİK HABER MERKEZİ</div>
      <h1>TÜRKİYE <span>GÜNDEM</span></h1>
      <div class="tg-slogan">Siyasetin nabzı burada atıyor.</div>
      <div class="tg-baslik-alt"><span>Ücretsiz</span><span>5 dakikada bir güncellenir</span><span>${tgTarih(d.yayin_tarihi)}</span></div>
    </section>
    <section class="tg-tanitim"><span>● CANLI OYUN HABERLERİ</span>
      <p>Haberler gerçek oyuncuların parti, seçim, adaylık ve ekonomi kayıtlarından üretilir. Gerçek olmayan olay veya sonuç uydurulmaz. Parti tanıtımları siyasi açıklama olarak belirtilir.</p>
    </section>
    ${tab}
    ${offset===0?lead:""}
    <div class="tg-govde"><div class="tg-bolum-bas"><h2>SON GELİŞMELER</h2><span>${fmt(d.toplam,0)} haber</span></div>
    <div class="tg-liste">${cards||"<div class='kart'>Bu kategoride henüz yayımlanmış haber bulunmuyor.</div>"}</div></div>
    <div class="satir"><button class="btn ikinci yarim" onclick="otomatikGazeteEkrani(${kategori?JSON.stringify(kategori):"null"},Math.max(0,${offset}-30))" ${offset===0?"disabled":""}>← Önceki</button>
    <button class="btn altin yarim" onclick="otomatikGazeteEkrani(${kategori?JSON.stringify(kategori):"null"},${offset}+30)" ${offset+30>=d.toplam?"disabled":""}>Daha fazla →</button></div>
    <button class="btn ikinci" onclick="basinEkrani()">Oyuncuların gazetelerine dön</button>
  `,{geri:true});
 }catch(err){iskelet("Türkiye Gündem",`<div class="kart"><h2>Gazete geçici olarak okunamıyor</h2>
    <p class="alt">${e(hataCevir(err.message))}</p>
    <button class="btn ikinci" onclick="otomatikGazeteEkrani()">Tekrar dene</button></div>`,{geri:true});}
}
function tgHaberOku(id){
 const h=tgCache[id];if(!h){otomatikGazeteEkrani();return;}
 iskelet("Türkiye Gündem",`
  <section class="tg-kapak"><div class="tg-saat">TÜRKİYE GÜNDEM · HABER ARŞİVİ</div><h1>TÜRKİYE <span>GÜNDEM</span></h1>
   <div class="tg-slogan">Otomatik ve ücretsiz haber merkezi</div></section>
  <article class="tg-detay"><div class="tg-gorev">${TG_RENK[h.kategori]||"📰"} ${e(TG_KAT[h.kategori]||h.kategori)}</div>
    <h1>${e(h.baslik)}</h1><div class="tg-meta">Yayımlanma: ${tgTarih(h.zaman)} · Kaynak: gerçek oyun kayıtları</div>
    <div class="tg-ozet">${e(h.ozet)}</div><div class="tg-tam">${e(h.metin)}</div>
    <div class="tg-dipnot">Haberler oyun içindeki kayıtlı olaylara dayanır. Gazete hiçbir adayın destekçisi değildir.</div>
  </article><button class="btn altin" onclick="otomatikGazeteEkrani()">← Gazete ana sayfasına dön</button>
 `,{geri:true});
}
async function serbestBagisEkrani(){
 yukleniyor("Bağış / Para Gönder");
 try{
  const [dest,gecmis]=await Promise.all([API.rpc("bagis_hedefleri"),API.rpc("bagis_gecmisim")]);
  const turler=[["oyuncu","👤 Oyuncuya"],["parti","🏛️ Siyasi partiye"],["sirket","🏢 Şirkete"],["gazete","📰 Oyuncu gazetesine"],["il","🏙️ İle / belediye kalkınmasına"],["devlet","🇹🇷 Devlet hazinesine"]];
  const history=(gecmis.hareketler||[]).slice(0,15).map(x=>`<div class="kv">
    <span>${e(x.alici)}<span class="kucuk"> · ${tgTarih(x.tarih)}</span></span><b>−${tlYaz(x.tutar)}</b></div>`).join("");
  iskelet("Serbest bağış / para gönder",`
    <div class="kart"><h2>🤝 İstediğin kadar bağış yap</h2>
      <p class="alt">Günlük bağış tavanı yoktur. Tek sınır cüzdanında gerçekten bulunan oyun parasıdır. Para alıcının cüzdanına, kurumun kasasına veya kamu hazinesine geçer. İşlem kayıt altına alınır.</p>
      <div class="alan"><label>Alıcı türü</label><select id="serbest_bagis_tur">${turler.map(([id,ad])=>`<option value="${id}">${ad}</option>`).join("")}</select></div>
      <div id="serbest_bagis_hedef_alan"></div>
      <div class="alan"><label>Bağış tutarı (₺)</label><input id="serbest_bagis_tutar" type="number" min="1" step="1" value="1000" inputmode="numeric"/></div>
      <div class="alan"><label>Not (isteğe bağlı)</label><input id="serbest_bagis_not" maxlength="150" placeholder="Örnek: Kampanyalar için destek"/></div>
      <button class="btn altin" id="serbest_bagis_gonder">Bağışla / Gönder</button>
      <p class="kucuk">Not: Bağış geri alınamaz. Şirket bağışı karşılığında ortaklık hissesi verilmez. Bağış, banka mevduatı veya kredi işlemi değildir.</p>
    </div>
    <div class="kart"><h2>📜 Bağış geçmişim</h2>${history||"<p class='alt'>Henüz serbest bağış kaydın yok.</p>"}</div>
  `,{geri:true});
  const sel=document.getElementById("serbest_bagis_tur"),area=document.getElementById("serbest_bagis_hedef_alan");
  const draw=()=>{
   const k=sel.value, data=dest[({parti:"partiler",sirket:"sirketler",gazete:"gazeteler",il:"iller"})[k]]||[];
   if(k==="oyuncu"){area.innerHTML=`<div class="alan"><label>Oyuncu kullanıcı adı</label><input id="serbest_bagis_alici" maxlength="40" autocomplete="off" placeholder="Oyuncu adı"/></div>`;return;}
   if(k==="devlet"){area.innerHTML="<p class='alt'>Bağış doğrudan devlet hazinesine aktarılır.</p>";return;}
   area.innerHTML=`<div class="alan"><label>Alıcı ${e(k)}</label>
     <select id="serbest_bagis_alici">${data.map(x=>`<option value="${x.id}">${e(x.ad)}</option>`).join("")}</select></div>`;
  };
  sel.onchange=draw;draw();
  const btn=document.getElementById("serbest_bagis_gonder");
  btn.onclick=async()=>{
   if(btn.disabled)return;
   const tur=sel.value,tutar=Number(document.getElementById("serbest_bagis_tutar").value),
     id=tur==="devlet"?"1":document.getElementById("serbest_bagis_alici")?.value,
     aciklama=document.getElementById("serbest_bagis_not").value.trim();
   if(!Number.isSafeInteger(tutar)||tutar<1||!id?.trim()){toast("Geçerli alıcı ve pozitif tam TL tutarı gir.",true);return;}
   if(!await onayla("Bağış onayı",tlYaz(tutar)+" tutarında bağış yapmak üzeresin. Bu işlem geri alınamaz. Devam edilsin mi?","Bağışla"))return;
   btn.disabled=true;
   try{const x=await API.rpc("serbest_bagis",{p_tur:tur,p_id:id,p_tutar:tutar,p_aciklama:aciklama||null});
    D._hayat=null;toast(tlYaz(tutar)+" "+x.hedef+" hesabına aktarıldı.");serbestBagisEkrani();}
   catch(err){btn.disabled=false;toast(hataCevir(err.message),true)}
  };
 }catch(err){iskelet("Bağış / Para Gönder",`<div class="kart"><p class="alt">${e(hataCevir(err.message))}</p></div>`,{geri:true});}
}
