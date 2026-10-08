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

/* Alıcı bağış sırasında değiştirilmez; işlem doğrudan ziyaret edilen sayfaya aittir. */
function bagisHedefModal(tur, hedefId, hedefAdi, sonra){
 const turAdi={oyuncu:"Oyuncuya para hediye et",parti:"Partiye bağış yap",gazete:"Gazeteye bağış yap"};
 if(!Object.prototype.hasOwnProperty.call(turAdi,tur))throw new Error("Desteklenmeyen bağış türü");
 const hedef=String(hedefId||"").trim(), ad=String(hedefAdi||"");
 if(!hedef||!ad){toast("Bağışın alıcısı belirlenemedi.",true);return;}
 const m=modal(`<h3 style="font-size:19px;font-weight:800">🎁 ${e(turAdi[tur])}</h3>
  <p class="alt">Bağış doğrudan <b>${e(ad)}</b> ${tur==="oyuncu"?"oyuncusunun cüzdanına":tur==="parti"?"partisinin kasasına":"gazetesinin kasasına"} aktarılır. Günlük üst sınır yok; cüzdanında yeterli paran olması gerekir.</p>
  <div class="kart" style="background:var(--panel2);margin:12px 0">
    <div class="kv"><span>Alıcı</span><b>${e(ad)}</b></div>
    <div class="kv"><span>İşlem</span><b>${tur==="oyuncu"?"Para hediyesi":"Karşılıksız bağış"}</b></div>
  </div>
  <div class="alan"><label for="bhTutar">Gönderilecek tutar (₺)</label>
    <input id="bhTutar" type="number" min="1" step="1" value="1000" inputmode="numeric" required></div>
  <div class="alan"><label for="bhNot">Açıklama (isteğe bağlı)</label>
    <input id="bhNot" maxlength="150" placeholder="Bağışınla ilgili notun"></div>
  <p class="kucuk">Bu işlem geri alınamaz. Başka bir oyuncuyu veya kurumu seçmek için ilgili sayfaya gitmelisin.</p>
  <button class="btn altin" id="bhOnay">Bağışı / para gönderimini onayla</button>
  <button class="btn ikinci" id="bhVazgec">Vazgeç</button>`);
 const btn=$("#bhOnay",m), cancel=$("#bhVazgec",m);
 cancel.onclick=()=>modalKapat();
 btn.onclick=async()=>{
   if(btn.disabled)return;
   const raw=$("#bhTutar",m).value.trim();
   const miktar=Number(raw), note=$("#bhNot",m).value.trim();
   if(!raw||!Number.isSafeInteger(miktar)||miktar<1){toast("Pozitif tam sayı olarak bir TL tutarı gir.",true);return;}
   btn.disabled=true;
   const kabul=await onayla("Bağışı onayla",
    `${e(ad)} adlı alıcıya ${tlYaz(miktar)} gönderilecek. Cüzdanından düşecek ve işlem geri alınamayacak. Devam edilsin mi?`,"Evet, gönder");
   if(!kabul)return;
   try{
     const sonuc=await API.rpc("serbest_bagis",{
        p_tur:tur,p_id:hedef,p_tutar:miktar,p_aciklama:note||null
     });
     modalKapat();
     D._hayat=null;
     toast(`${tlYaz(miktar)} ${sonuc.hedef||ad} hesabına aktarıldı.`);
     if(typeof sonra==="function")await sonra();
   }catch(err){toast(hataCevir(err.message),true);}
 };
}
