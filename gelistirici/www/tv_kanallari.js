/* 11.11.2026 · TV Kanalları — sunucu modülü 198.
   Kanal kurma, maaşlı sunucu, zamanlı canlı program (siyasi düello / söyleşi / haber), konuk daveti, canlı yazışma,
   izleyici sayısı ve listesi, alkış / yuh, düello oylaması, izleyici başına ücretli reklam. Mevcut ekranlara dokunmaz.
   12.11.2026 · Yayın Merkezi tasarımı: yayın monitörü, saatli yayın akışı, kanal logoları, düello köşeleri, ekran içi sekmeler.
   RPC'ler, parametreler ve form alanı kimlikleri aynen korunur.
   15.11.2026 · TV 2.0 "Canlı yayın" (sunucu 209): gerçek TV çerçevesi (kanal logosu, CANLI, reyting/pay, alt bant, kayan yazı,
   kumandayla kanal değiştirme), anlık emoji yağmuru ve salon ısısı, seyirci kürsüsü (yorum, soru, "ben de soruyorum", ekrana alma),
   canlı bağlantı (söz iste → yayına al), canlı anket, bilgi yarışması (süreli soru, hız puanı, ödül havuzu, soru bankası),
   reklam arası, kanal takibi ve program hatırlatma, kanal seviyesi, haftalık reyting tablosu. Stüdyo tv_canli ile yalnız
   değişeni çeker (1000 izleyicide hafif); sunucu eskiyse tv_detay ile eskisi gibi çalışır. */
(function () {
  "use strict";
  if (window.SO_TV_KANALLARI_V1) return;
  window.SO_TV_KANALLARI_V1 = true;

  const rpc = (fn, a) => API.rpc(fn, a);
  const KX = () => window.SO_KX;
  const tl = x => (Number(x) || 0).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
  const n = x => (Number(x) || 0).toLocaleString("tr-TR");
  const kv = (a, b) => `<div class="kv"><span class="k">${a}</span><span class="v">${b}</span></div>`;
  const bos = m => `<div class="tvx-bos">${m}</div>`;
  const kisi = k => k ? `<b>${e(k.kad)}</b>${k.unvan ? ` <span class="kucuk" style="color:var(--gold2)">${e(k.unvan)}</span>` : ""}` : "—";
  const hataEkran = (b, err) => iskelet(b, `<div class="bos">${e(hataCevir(err.message))}</div><button class="btn ikinci" onclick="yenidenCiz()">Tekrar dene</button>`, { geri: true });
  const benimKad = () => { try { return D.durum.profil.kad; } catch (_) { return ""; } };
  // kesintisiz_ekran.js, kullanıcı eylemi olmadan gelen çizimleri erteleyebilir; seçim kutusu gibi düğme dışı eylemleri bildirir
  const eylem = () => { try { if (window.SO_KESINTISIZ) window.SO_KESINTISIZ.eylem = Date.now(); } catch (_) {} };
  const ROL = { sunucu: "Sunucu", konuk: "Konuk", reklam: "Reklam" };
  const SURELER = [[10, "10 dakika"], [15, "15 dakika"], [20, "20 dakika"], [30, "30 dakika"], [45, "45 dakika"], [60, "1 saat"], [90, "1,5 saat"], [120, "2 saat"], [180, "3 saat"]];
  const TUR = { duello: ["Siyasi düello", "İki ya da daha çok konuk tartışır, izleyiciler en ikna ediciyi oylar."], soylesi: ["Söyleşi", "Sunucu konuklarına soru sorar; seyirci sorularını ekrana alabilir."], haber: ["Haber programı", "Sunucu gündemi aktarır, konuk çağırabilir, canlı anket açabilir."],
    yarisma: ["Bilgi yarışması", "Sunucu süreli sorular sorar; izleyiciler yarışır, hızlı ve doğru bilen puan toplar. Kanal kasasından ödül havuzu koyabilirsin."],
    acik_oturum: ["Açık oturum · Halk soruyor", "Söz seyircide: sorular oylanır, sunucu en çok desteklenenleri ekrana alır, izleyicileri canlı bağlantıyla stüdyoya bağlar."] };
  const EMOJI = [["alkis", "👏", "Alkış"], ["kahkaha", "😂", "Kahkaha"], ["sasirma", "😮", "Şaşkınlık"], ["ofke", "😡", "Öfke"], ["kalp", "❤️", "Sevgi"], ["ates", "🔥", "Ateş"]];
  const EMO = Object.fromEntries(EMOJI.map(x => [x[0], x[1]]));
  // Bilgi yarışması için hazır soru bankası (sunucu tek dokunuşla forma doldurur; doğru cevap ilk sıradadır, form karıştırır)
  const SORU_BANKASI = [
    ["TBMM kaç milletvekilinden oluşur?", "600", "550", "450", "650"], ["Türkiye Cumhuriyeti hangi yıl ilan edildi?", "1923", "1920", "1925", "1938"],
    ["TBMM ilk kez hangi tarihte açıldı?", "23 Nisan 1920", "29 Ekim 1923", "19 Mayıs 1919", "30 Ağustos 1922"], ["Türkiye'nin en kalabalık ili hangisidir?", "İstanbul", "Ankara", "İzmir", "Bursa"],
    ["Yüzölçümü en büyük ilimiz hangisidir?", "Konya", "Sivas", "Erzurum", "Ankara"], ["Türkiye'de kaç il vardır?", "81", "79", "80", "82"],
    ["Cumhurbaşkanının görev süresi kaç yıldır?", "5", "4", "6", "7"], ["Milletvekili seçilebilme yaşı kaçtır?", "18", "21", "25", "30"],
    ["Türkiye'nin en yüksek dağı hangisidir?", "Ağrı Dağı", "Erciyes", "Uludağ", "Kaçkar"], ["Tamamı Türkiye'de akan en uzun nehir hangisidir?", "Kızılırmak", "Sakarya", "Yeşilırmak", "Seyhan"],
    ["Türkiye'nin en büyük gölü hangisidir?", "Van Gölü", "Tuz Gölü", "Beyşehir Gölü", "Eğirdir Gölü"], ["İstiklal Marşı'nın şairi kimdir?", "Mehmet Akif Ersoy", "Namık Kemal", "Ziya Gökalp", "Yahya Kemal"],
    ["Kadınlara milletvekili seçme ve seçilme hakkı hangi yıl tanındı?", "1934", "1930", "1946", "1950"], ["Türkiye'de ilk çok partili genel seçim hangi yıl yapıldı?", "1946", "1950", "1923", "1960"],
    ["Türk Medeni Kanunu ilk kez hangi yıl kabul edildi?", "1926", "1924", "1928", "1934"], ["Harf İnkılabı hangi yıl yapıldı?", "1928", "1926", "1932", "1924"],
    ["Soyadı Kanunu hangi yıl çıkarıldı?", "1934", "1928", "1937", "1930"], ["Türk lirasının uluslararası kodu nedir?", "TRY", "TRL", "TUR", "TLR"],
    ["Anayasa Mahkemesi kaç üyeden oluşur?", "15", "11", "17", "21"], ["Türkiye NATO'ya hangi yıl katıldı?", "1952", "1949", "1955", "1960"],
    ["Hangisi bir Karadeniz ili değildir?", "Malatya", "Rize", "Artvin", "Ordu"], ["Gaziantep hangi coğrafi bölgededir?", "Güneydoğu Anadolu", "Akdeniz", "Doğu Anadolu", "İç Anadolu"],
    ["Plaka kodu 35 olan il hangisidir?", "İzmir", "Antalya", "Bursa", "Adana"], ["TBMM Başkanı'nı kim seçer?", "Milletvekilleri", "Cumhurbaşkanı", "Halk", "Anayasa Mahkemesi"],
    ["Cumhurbaşkanı adayı olmak için en az kaç yaşında olmak gerekir?", "40", "35", "30", "45"], ["TBMM'de kanun teklifini kim verebilir?", "Milletvekilleri", "Bakanlar", "Valiler", "Belediye başkanları"],
    ["Genel seçimler kaç yılda bir yapılır?", "5", "4", "6", "7"], ["Hangisi Türkiye'nin kara komşusu değildir?", "Ukrayna", "Gürcistan", "İran", "Ermenistan"],
    ["Plaka kodu 06 olan il hangisidir?", "Ankara", "Adana", "Antalya", "Aydın"], ["Hangisi TBMM'nin görevlerinden biridir?", "Kanun yapmak", "Dava görmek", "Vali atamak", "Belediye bütçesi onaylamak"]];
  const ANKET_HAZIR = [["Konuğumuzu ikna edici buldunuz mu?", "Evet", "Hayır", "Kararsızım"], ["Bu konuda hükümet doğru yolda mı?", "Evet", "Hayır", "Kısmen"],
    ["Sizce bugün seçim olsa kazanan kim olur?", "İktidar", "Muhalefet", "Belli değil"], ["Programı nasıl buldunuz?", "Harika", "İyi", "Sıkıcı"]];
  // düello köşe renkleri: 1. konuk mavi, 2. konuk kırmızı, sonrakiler sırayla
  const KOSE = ["#4C8DFF", "#F0454B", "#2FBF8F", "#F2B33D", "#B07CFF", "#3FC5E0"];
  const ton = s => (KX() ? KX().ton(s) : 250);
  const harf = s => (KX() ? KX().harfler(s, 2) : "TV");
  const logo = (ad, cls) => `<span class="tvx-logo ${cls || ""}" style="--h:${ton(ad)}" aria-hidden="true">${e(harf(ad))}</span>`;

  function stil() {
    if (KX()) KX().stil();
    if (document.getElementById("tvStil")) return;
    const s = document.createElement("style"); s.id = "tvStil";
    s.textContent = `
      .tv-canli{display:inline-flex;align-items:center;gap:5px;background:#F0454B;color:#fff;font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;padding:2px 8px 2px 7px;border-radius:999px;margin-right:6px;vertical-align:middle;line-height:1.5}
      .tv-canli::before{content:"";width:6px;height:6px;border-radius:50%;background:#fff;animation:tvNabiz 1.4s ease-in-out infinite}
      @keyframes tvNabiz{50%{opacity:.25}}
      @media (prefers-reduced-motion:reduce){.tv-canli::before{animation:none}}
      .tvx{--kx:#E23A40}
      .tvx .tvx-bos{padding:14px 2px;font-size:14px;line-height:1.45;color:var(--mut)}
      /* kanal logosu: kanal adından üretilen istasyon amblemi */
      .tvx-logo{flex:none;display:inline-grid;place-items:center;width:34px;height:34px;border-radius:10px;font-family:var(--disp);font-weight:700;font-size:15px;letter-spacing:.02em;color:#fff;
        background:linear-gradient(150deg,hsl(var(--h) 70% 52%),hsl(calc(var(--h) + 40) 62% 30%));box-shadow:inset 0 1px 0 rgba(255,255,255,.28),0 4px 12px -6px hsl(var(--h) 70% 40%)}
      .tvx-logo.b{width:58px;height:58px;border-radius:16px;font-size:24px}
      .tvx-logo.k{width:26px;height:26px;border-radius:8px;font-size:12px}
      /* yayın monitörü */
      .tvx-ekran{position:relative;display:block;width:100%;text-align:left;margin:0 0 12px;padding:14px 14px 13px;border-radius:20px;overflow:hidden;color:#F4F6FF;
        background:radial-gradient(120% 90% at 85% 0%,hsl(var(--h,350) 60% 30% / .55),transparent 60%),linear-gradient(180deg,#0A0F24,#060917);
        box-shadow:inset 0 0 0 1px rgba(255,255,255,.08),inset 0 0 40px rgba(0,0,0,.5),0 18px 34px -26px #000}
      .tvx-ekran::after{content:"";position:absolute;inset:0;pointer-events:none;background:repeating-linear-gradient(0deg,rgba(255,255,255,.025) 0 1px,transparent 1px 3px);border-radius:inherit}
      .tvx-ekran.canli{box-shadow:inset 0 0 0 1.5px rgba(240,69,75,.75),inset 0 0 40px rgba(0,0,0,.5),0 18px 34px -22px rgba(240,69,75,.6)}
      .tvx-e-ust{display:flex;align-items:center;gap:9px;position:relative;z-index:1}
      .tvx-e-ust .tvx-e-kanal{flex:1;min-width:0;font-weight:800;font-size:14px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
      .tvx-e-ust .tvx-e-saat{font-variant-numeric:tabular-nums;font-size:12.5px;color:#C9D1E6}
      .tvx-e-orta{position:relative;z-index:1;margin:22px 0 14px}
      .tvx-e-orta small{display:block;font-size:12.5px;color:#FF9A9E;font-weight:750;margin-bottom:4px}
      .tvx-ekran:not(.canli) .tvx-e-orta small{color:#B5C3FF}
      .tvx-e-orta h2{font-family:var(--disp);font-size:25px;line-height:1.12;margin:0;color:#fff;text-wrap:balance;overflow-wrap:anywhere}
      .tvx-e-orta p{margin:7px 0 0;font-size:13px;line-height:1.4;color:#C9D1E6;overflow-wrap:anywhere}
      .tvx-e-alt{position:relative;z-index:1;display:flex;align-items:center;gap:12px}
      .tvx-e-alt .tvx-izl{flex:1;min-width:0;font-size:12.5px;color:#C9D1E6;line-height:1.3}
      .tvx-e-alt .tvx-izl b{display:block;font-family:var(--disp);font-size:24px;line-height:1;color:#fff;font-variant-numeric:tabular-nums}
      .tvx-e-alt .btn{width:auto;flex:none;margin:0;padding:11px 18px;min-height:44px}
      .tvx-cubuk{display:flex;height:5px;border-radius:3px;overflow:hidden;margin:0 0 14px;position:relative;z-index:1}
      .tvx-cubuk i{flex:1}
      .tvx-sayac{font-family:var(--disp);font-size:30px;line-height:1;color:#fff;font-variant-numeric:tabular-nums;letter-spacing:.01em}
      /* gelen teklif / davet */
      .tvx-gelen{padding:13px 14px;border-radius:16px;margin:0 0 10px;background:linear-gradient(135deg,rgba(242,179,61,.13),rgba(242,179,61,.03));box-shadow:inset 0 0 0 1px rgba(242,179,61,.4)}
      .tvx-gelen h2{font-size:16px;margin:0 0 4px}
      .tvx-gelen p{font-size:14px;line-height:1.45;color:var(--txt2);margin:0 0 10px}
      .tv-iki{display:flex;gap:8px;flex-wrap:wrap}
      .tv-iki .btn{flex:1;min-width:120px;margin:0}
      /* yayın akışı: saat sütunlu liste */
      .tvx-gun{font-size:13px;font-weight:800;color:var(--txt2);margin:14px 2px 6px}
      .tvx-gun:first-child{margin-top:0}
      .tvx-akis{display:flex;gap:12px;width:100%;text-align:left;padding:12px;border-radius:14px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);margin-bottom:8px;color:var(--txt)}
      .tvx-akis .tvx-saat{flex:none;width:52px;font-family:var(--disp);font-size:20px;line-height:1.1;font-variant-numeric:tabular-nums;color:#fff}
      .tvx-akis .tvx-saat small{display:block;font-family:inherit;font-size:11.5px;font-weight:600;color:var(--mut);margin-top:3px}
      .tvx-akis .tvx-a-g{flex:1;min-width:0}
      .tvx-akis .tvx-a-g b{display:block;font-size:15px;line-height:1.3;overflow-wrap:anywhere}
      .tvx-akis .tvx-a-g span{display:flex;align-items:center;gap:6px;margin-top:5px;font-size:12.5px;color:var(--mut);overflow-wrap:anywhere}
      .tvx-akis .tvx-a-g em{display:block;font-style:normal;font-size:12.5px;color:var(--txt2);margin-top:4px;overflow-wrap:anywhere}
      .tvx-akis.canli{box-shadow:inset 0 0 0 1.5px rgba(240,69,75,.6);background:linear-gradient(90deg,rgba(240,69,75,.10),transparent 60%),var(--panel)}
      .tvx-akis.canli .tvx-saat{color:#FF8A8E}
      .tvx-akis .tvx-ok{flex:none;align-self:center;color:var(--faint);font-size:20px}
      /* kanal ızgarası */
      .tvx-izgara{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}
      .tvx-kanal{position:relative;display:flex;flex-direction:column;align-items:flex-start;gap:9px;padding:13px 12px 12px;min-width:0;border-radius:16px;text-align:left;color:var(--txt);background:var(--panel);box-shadow:inset 0 0 0 1px var(--line)}
      .tvx-kanal b{font-size:15px;line-height:1.25;overflow-wrap:anywhere}
      .tvx-kanal small{font-size:12px;line-height:1.35;color:var(--mut);overflow-wrap:anywhere}
      .tvx-kanal .tv-canli{position:absolute;top:12px;right:10px;margin:0}
      .tvx-kanal.ben{box-shadow:inset 0 0 0 1.5px rgba(242,179,61,.6)}
      /* kanal kurma: canlı amblem önizlemesi */
      .tvx-kur{display:flex;align-items:center;gap:12px;margin-bottom:12px}
      .tvx-kur b{display:block;font-size:17px}
      .tvx-kur small{font-size:12.5px;color:var(--mut)}
      /* kanal künyesi */
      .tvx-kunye{display:flex;gap:13px;align-items:center}
      .tvx-kunye h2{font-family:var(--disp);font-size:24px;line-height:1.1;margin:0;overflow-wrap:anywhere}
      .tvx-kunye p{margin:4px 0 0;font-size:13.5px;color:var(--txt2);line-height:1.4;overflow-wrap:anywhere}
      .tv-satir{padding:11px 0;border-bottom:1px solid var(--line2);overflow-wrap:anywhere}
      .tv-satir:last-child{border-bottom:0}
      .tv-satir .btn{margin-top:8px}
      .tvx-kasa{font-family:var(--disp);font-size:32px;line-height:1.05;color:#fff;font-variant-numeric:tabular-nums;margin:2px 0 4px}
      /* stüdyo */
      .tvx-kose{display:grid;grid-template-columns:repeat(var(--n,2),minmax(0,1fr));gap:8px;margin:0 0 12px}
      .tvx-kose .btn{position:relative;display:flex;flex-direction:column;align-items:flex-start;justify-content:flex-start;gap:2px;margin:0;padding:11px 11px 12px;min-height:76px;text-align:left;border-radius:14px;color:var(--txt);
        background:linear-gradient(160deg,color-mix(in srgb,var(--k) 22%,transparent),transparent 70%),var(--panel);box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--k) 45%,transparent)}
      .tvx-kose .btn.altin{box-shadow:inset 0 0 0 2px var(--k),0 8px 18px -12px var(--k)}
      .tvx-kose .btn b{font-size:15px;line-height:1.2;overflow-wrap:anywhere}
      .tvx-kose .btn small{font-size:12px;color:var(--txt2)}
      .tvx-kose .btn .tvx-pay{font-family:var(--disp);font-size:22px;line-height:1.1;color:#fff;font-variant-numeric:tabular-nums;margin-top:4px}
      .tvx-kose .btn .tvx-bar{position:absolute;left:11px;right:11px;bottom:7px;height:3px;border-radius:2px;background:rgba(255,255,255,.1);overflow:hidden}
      .tvx-kose .btn .tvx-bar i{display:block;height:100%;background:var(--k)}
      .tvx-kose .btn .tvx-sec{position:absolute;top:9px;right:9px;font-size:10.5px;font-weight:800;padding:1px 7px;border-radius:999px;background:var(--k);color:#fff}
      .tvx-oyb{margin:0 0 4px}
      .tvx-oyb h2{font-size:16px;margin:0 0 3px}
      .tvx-oyb p{font-size:12.5px;color:var(--mut);margin:0 0 10px;line-height:1.4}
      .tv-oda{max-height:56vh;min-height:170px;overflow-y:auto;overscroll-behavior:contain;padding:2px 2px 4px}
      .tv-mesaj{max-width:88%;margin:0 0 10px;padding:9px 12px 10px;border-radius:16px;overflow-wrap:anywhere;background:var(--panel2);box-shadow:inset 3px 0 0 var(--k,var(--ink2))}
      .tv-mesaj p{margin:4px 0 0;font-size:15px;line-height:1.45;white-space:pre-wrap;color:var(--txt)}
      .tv-mesaj .tvx-m-bas{display:flex;align-items:baseline;gap:7px;flex-wrap:wrap;font-size:13px}
      .tv-mesaj .tvx-m-bas b{color:var(--k,var(--txt))}
      .tv-mesaj .tvx-m-bas .kucuk{color:var(--faint)}
      .tv-mesaj.sunucu{max-width:100%;background:rgba(255,255,255,.04);box-shadow:inset 0 0 0 1px var(--line2);--k:#E8EBF6}
      .tv-mesaj.konuk.sag{margin-left:auto;box-shadow:inset -3px 0 0 var(--k)}
      .tv-mesaj.konuk.sag .tvx-m-bas{justify-content:flex-end}
      .tv-mesaj.reklam{max-width:100%;display:flex;gap:10px;align-items:center;background:repeating-linear-gradient(135deg,rgba(242,179,61,.10) 0 10px,rgba(242,179,61,.05) 10px 20px);box-shadow:inset 0 0 0 1px rgba(242,179,61,.3)}
      .tv-mesaj.reklam p{margin:0;font-size:14px}
      .tv-rol{display:inline-block;flex:none;font-size:10.5px;font-weight:800;text-transform:uppercase;letter-spacing:.05em;padding:1px 7px;border-radius:999px;border:1px solid currentColor;color:var(--mut)}
      .tv-mesaj.reklam .tv-rol{color:#F2B33D}
      .tvx-yaz{display:flex;gap:8px;align-items:flex-end}
      .tvx-yaz textarea{flex:1;min-width:0;min-height:48px;max-height:140px;resize:vertical;font-size:16px}
      .tvx-yaz .btn{width:auto;flex:none;margin:0;min-height:48px;padding:0 18px}
      .tvx-tepki{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin:0 0 12px}
      .tvx-tepki .btn{margin:0;min-height:52px;font-size:15px}
      .tvx-tepki .btn i{font-style:normal;font-variant-numeric:tabular-nums;opacity:.75;font-weight:700;margin-left:2px}
      .tv-izl{margin:8px 0 0;font-size:14px;line-height:1.6;overflow-wrap:anywhere}
      .tv-sponsor{font-size:12.5px;color:#C9D1E6;margin-top:10px;position:relative;z-index:1;overflow-wrap:anywhere}
      .tv-yaz{width:100%;min-height:64px;resize:vertical}
      .tvx-tur{display:grid;gap:8px;margin:0 0 4px}
      .tvx-tur label{display:flex;gap:10px;align-items:flex-start;padding:11px 12px;border-radius:12px;background:var(--panel2);box-shadow:inset 0 0 0 1px var(--line2);cursor:pointer}
      .tvx-tur label:has(input:checked){box-shadow:inset 0 0 0 2px var(--kx)}
      .tvx-tur input{margin-top:3px;accent-color:#E23A40;width:18px;height:18px;flex:none}
      .tvx-tur b{display:block;font-size:14.5px}.tvx-tur small{display:block;font-size:12.5px;color:var(--mut);line-height:1.35;margin-top:2px}
      .tvx-ozet{font-size:13px;color:var(--txt2);margin:4px 0 0}
      /* ===== 209 · canlı TV çerçevesi ===== */
      .tvx-tv{position:relative;overflow:hidden;margin:0 0 12px;border-radius:20px;color:#F4F6FF;isolation:isolate;
        background:radial-gradient(130% 80% at 80% -10%,hsl(var(--h,350) 70% 34% / .65),transparent 60%),radial-gradient(90% 70% at 0% 110%,hsl(calc(var(--h,350) + 50) 60% 22% / .55),transparent 60%),linear-gradient(180deg,#0B1028,#05070F);
        box-shadow:inset 0 0 0 1px rgba(255,255,255,.08),0 22px 40px -28px #000}
      .tvx-tv.canli{box-shadow:inset 0 0 0 1.5px rgba(240,69,75,.7),0 22px 40px -24px rgba(240,69,75,.55)}
      .tvx-tv::after{content:"";position:absolute;inset:0;pointer-events:none;z-index:3;background:repeating-linear-gradient(0deg,rgba(255,255,255,.022) 0 1px,transparent 1px 3px),radial-gradient(120% 90% at 50% 40%,transparent 60%,rgba(0,0,0,.45))}
      .tvx-tv-ust{position:relative;z-index:2;display:flex;align-items:center;gap:8px;padding:12px 12px 0}
      .tvx-bug{display:flex;align-items:center;gap:7px;min-width:0;flex:1;color:#fff;text-align:left;background:none;padding:0}
      .tvx-bug b{font-size:13.5px;font-weight:800;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;letter-spacing:.01em}
      .tvx-chip{flex:none;display:inline-flex;align-items:center;gap:4px;font-size:11px;font-weight:800;letter-spacing:.03em;padding:3px 8px;border-radius:999px;background:rgba(255,255,255,.1);color:#E8EBF6;font-variant-numeric:tabular-nums;white-space:nowrap}
      .tvx-chip.takip{background:rgba(242,179,61,.18);color:#FFD27A}
      button.tvx-chip{min-height:26px}
      .tvx-sahne{position:relative;z-index:2;min-height:178px;padding:16px 14px 12px;display:flex;flex-direction:column;justify-content:center}
      .tvx-tur-et{font-size:11.5px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:#FF9A9E;margin-bottom:6px}
      .tvx-tv:not(.canli) .tvx-tur-et{color:#B5C3FF}
      .tvx-sahne h2{font-family:var(--disp);font-size:24px;line-height:1.12;margin:0;color:#fff;text-wrap:balance;overflow-wrap:anywhere}
      .tvx-sahne p{margin:7px 0 0;font-size:13.5px;line-height:1.45;color:#C9D1E6;overflow-wrap:anywhere}
      .tvx-soz{animation:tvGir .35s ease-out}
      .tvx-soz q{display:block;quotes:"“" "”";font-family:var(--disp);font-size:20px;line-height:1.3;color:#fff;overflow-wrap:anywhere;display:-webkit-box;-webkit-line-clamp:5;-webkit-box-orient:vertical;overflow:hidden}
      .tvx-soz q::before{content:open-quote;color:var(--k,#FF8A8E);margin-right:2px}.tvx-soz q::after{content:close-quote;color:var(--k,#FF8A8E)}
      .tvx-soz .tvx-kim{display:flex;align-items:center;gap:8px;margin-top:10px;font-size:13px;color:#C9D1E6}
      .tvx-soz .tvx-kim i{flex:none;width:26px;height:26px;border-radius:50%;display:grid;place-items:center;font-style:normal;font-weight:800;font-size:12px;color:#fff;background:var(--k,#E23A40)}
      .tvx-soz .tvx-kim b{color:#fff}
      .tvx-izs{display:inline-flex;align-self:flex-start;gap:6px;align-items:center;font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;padding:3px 9px;border-radius:6px;background:#F2B33D;color:#1a1405;margin-bottom:8px}
      @keyframes tvGir{from{opacity:0;transform:translateY(6px)}}
      /* soru / anket grafiği (ekranın içinde, dokunulabilir) */
      .tvx-q h2{font-size:20px}
      .tvx-q .tvx-q-ust{display:flex;align-items:center;gap:8px;margin-bottom:8px}
      .tvx-q .tvx-q-ust .tvx-tur-et{margin:0;flex:1}
      .tvx-q .tvx-sn{flex:none;font-family:var(--disp);font-size:18px;font-variant-numeric:tabular-nums;color:#fff;line-height:1}
      .tvx-geri{height:4px;border-radius:2px;background:rgba(255,255,255,.12);overflow:hidden;margin:10px 0 12px}
      .tvx-geri i{display:block;height:100%;background:linear-gradient(90deg,#F2B33D,#F0454B);transition:width 1s linear}
      .tvx-opts{display:grid;grid-template-columns:1fr 1fr;gap:8px}
      .tvx-opt{position:relative;overflow:hidden;display:flex;align-items:center;gap:8px;min-height:50px;padding:9px 10px;border-radius:12px;text-align:left;color:#fff;font-size:14.5px;font-weight:700;line-height:1.25;
        background:rgba(255,255,255,.07);box-shadow:inset 0 0 0 1px rgba(255,255,255,.14);overflow-wrap:anywhere}
      .tvx-opt::before{content:"";position:absolute;inset:0 auto 0 0;width:var(--p,0%);background:rgba(255,255,255,.12);transition:width .6s ease;z-index:0}
      .tvx-opt>*{position:relative;z-index:1}
      .tvx-opt .tvx-hf{flex:none;width:24px;height:24px;border-radius:7px;display:grid;place-items:center;font-size:12px;font-weight:900;background:rgba(255,255,255,.14)}
      .tvx-opt .tvx-yz{margin-left:auto;font-variant-numeric:tabular-nums;font-size:13px;color:#E8EBF6;flex:none}
      .tvx-opt.secili{box-shadow:inset 0 0 0 2px #F2B33D}.tvx-opt.secili .tvx-hf{background:#F2B33D;color:#1a1405}
      .tvx-opt.dogru{box-shadow:inset 0 0 0 2px #2FBF8F;background:rgba(47,191,143,.22)}.tvx-opt.dogru .tvx-hf{background:#2FBF8F}
      .tvx-opt.yanlis{opacity:.62}
      .tvx-opt:disabled{cursor:default}
      .tvx-q-alt{margin-top:9px;font-size:12.5px;color:#C9D1E6}
      .tvx-q-alt b{color:#fff}
      /* reklam arası */
      .tvx-rek{text-align:center}
      .tvx-rek .tvx-rek-et{display:inline-block;font-size:11px;font-weight:900;letter-spacing:.14em;padding:3px 10px;border-radius:5px;background:repeating-linear-gradient(135deg,#F2B33D 0 8px,#E5A22A 8px 16px);color:#1a1405;margin-bottom:10px}
      .tvx-rek .tvx-rek-k{position:relative;min-height:84px}
      .tvx-rek .tvx-rek-k>div{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;opacity:0;animation:tvRek var(--t,12s) infinite;animation-delay:calc(var(--i) * var(--d,6s))}
      .tvx-rek .tvx-rek-k b{font-family:var(--disp);font-size:24px;color:#fff;overflow-wrap:anywhere}
      .tvx-rek .tvx-rek-k span{font-size:14px;color:#E8EBF6;margin-top:4px;overflow-wrap:anywhere}
      .tvx-rek .tvx-rek-k>div:only-child{opacity:1;animation:none}
      @keyframes tvRek{0%{opacity:0;transform:scale(.97)}6%,44%{opacity:1;transform:none}50%,100%{opacity:0}}
      /* alt bant + kayan yazı */
      .tvx-altbant{position:relative;z-index:2;display:flex;align-items:stretch;margin:0 12px;border-radius:8px 8px 0 0;overflow:hidden;font-size:12.5px;line-height:1.25}
      .tvx-altbant .tvx-ab-k{flex:none;display:flex;align-items:center;padding:6px 9px;font-weight:900;letter-spacing:.04em;background:hsl(var(--h,350) 70% 48%);color:#fff;text-transform:uppercase;font-size:11px}
      .tvx-altbant .tvx-ab-m{flex:1;min-width:0;padding:6px 9px;background:rgba(255,255,255,.92);color:#0B1028;font-weight:750;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
      .tvx-kayan{position:relative;z-index:2;display:flex;align-items:center;margin:0 12px 10px;height:28px;border-radius:0 0 8px 8px;overflow:hidden;background:rgba(5,7,15,.82);font-size:12.5px}
      .tvx-kayan .tvx-ky-et{flex:none;height:100%;display:flex;align-items:center;padding:0 8px;font-size:10.5px;font-weight:900;letter-spacing:.08em;background:#F0454B;color:#fff}
      .tvx-kayan .tvx-ky-i{flex:1;min-width:0;overflow:hidden;white-space:nowrap;mask-image:linear-gradient(90deg,transparent,#000 12px,#000 calc(100% - 12px),transparent)}
      .tvx-kayan .tvx-ky-i span{display:inline-block;padding-left:100%;animation:tvKay var(--sure,24s) linear infinite;color:#E8EBF6}
      .tvx-kayan .tvx-ky-i span b{color:#FFD27A;font-weight:800}
      @keyframes tvKay{to{transform:translateX(-100%)}}
      .tvx-tv-alt{position:relative;z-index:2;display:block;padding:0 12px 12px;font-size:12.5px;line-height:1.45;color:#C9D1E6}
      .tvx-tv-alt #tvSayac{margin:0;color:#E8EBF6}
      .tvx-tv-alt .tvx-tv-bil{display:flex;flex-wrap:wrap;align-items:center;gap:4px 8px;margin-top:4px}
      .tvx-sahne-k{position:relative}
      /* uçan tepkiler */
      .tvx-ucan{position:absolute;inset:0;z-index:4;pointer-events:none;overflow:hidden}
      .tvx-ucan .tvx-u{position:absolute;bottom:40px;font-size:26px;line-height:1;animation:tvUc var(--s,2.6s) ease-out forwards;will-change:transform,opacity;filter:drop-shadow(0 3px 6px rgba(0,0,0,.45))}
      @keyframes tvUc{0%{opacity:0;transform:translate(0,10px) scale(.6)}12%{opacity:1;transform:translate(calc(var(--x) * .2),-20px) scale(1.15)}100%{opacity:0;transform:translate(var(--x),-230px) scale(.9)}}
      /* kumanda: kanal değiştir */
      .tvx-kum{position:absolute;z-index:5;top:50%;transform:translateY(-50%);width:30px;height:46px;border-radius:10px;display:grid;place-items:center;font-size:20px;color:#fff;background:rgba(5,7,15,.55);box-shadow:inset 0 0 0 1px rgba(255,255,255,.14)}
      .tvx-kum.sol{left:4px}.tvx-kum.sag{right:4px}
      .tvx-tv.kumanda .tvx-sahne{padding-left:40px;padding-right:40px}
      /* emoji çubuğu ve salon ısısı */
      .tvx-emo{margin:0 0 12px}
      .tvx-emo-d{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:6px}
      .tvx-emo-d button{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;min-height:58px;border-radius:14px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);font-size:24px;line-height:1;transition:transform .12s}
      .tvx-emo-d button:active{transform:scale(.9)}
      .tvx-emo-d button small{font-size:11px;font-weight:800;color:var(--mut);font-variant-numeric:tabular-nums}
      .tvx-emo-d button.pat{animation:tvPat .35s ease-out}
      @keyframes tvPat{40%{transform:scale(1.18)}}
      .tvx-isi{display:flex;align-items:center;gap:10px;margin-top:9px;font-size:12.5px;color:var(--txt2)}
      .tvx-isi .tvx-isi-c{flex:1;height:8px;border-radius:5px;background:var(--panel2);overflow:hidden;box-shadow:inset 0 0 0 1px var(--line2)}
      .tvx-isi .tvx-isi-c i{display:block;height:100%;width:var(--p,0%);border-radius:inherit;background:linear-gradient(90deg,#4C8DFF,#F2B33D 55%,#F0454B);transition:width .8s ease}
      .tvx-isi b{color:var(--txt);font-variant-numeric:tabular-nums}
      /* yarışma tablosu */
      .tvx-yar{margin:0 0 12px}
      .tvx-yar .tvx-havuz{display:flex;align-items:center;gap:12px;padding:12px 13px;border-radius:16px;background:linear-gradient(135deg,rgba(242,179,61,.2),rgba(242,179,61,.04));box-shadow:inset 0 0 0 1px rgba(242,179,61,.45)}
      .tvx-yar .tvx-havuz b{font-family:var(--disp);font-size:26px;line-height:1;color:#FFD27A;font-variant-numeric:tabular-nums}
      .tvx-yar .tvx-havuz small{display:block;font-size:12px;color:var(--txt2);margin-top:3px}
      .tvx-sira{display:flex;align-items:center;gap:10px;padding:9px 2px;border-bottom:1px solid var(--line2);font-size:14px}
      .tvx-sira:last-child{border-bottom:0}
      .tvx-sira .tvx-mad{flex:none;width:26px;height:26px;border-radius:50%;display:grid;place-items:center;font-size:12px;font-weight:900;background:var(--panel2);color:var(--txt2)}
      .tvx-sira .tvx-mad.m1{background:#F2B33D;color:#1a1405}.tvx-sira .tvx-mad.m2{background:#C9D1E6;color:#10142a}.tvx-sira .tvx-mad.m3{background:#C98A4B;color:#1a1405}
      .tvx-sira b{flex:1;min-width:0;overflow-wrap:anywhere}.tvx-sira span{flex:none;font-variant-numeric:tabular-nums;color:var(--txt2)}
      .tvx-sira.ben{background:rgba(242,179,61,.07);border-radius:10px;padding-left:6px;padding-right:6px}
      /* seyirci kürsüsü */
      .tvx-sey-akis{max-height:46vh;min-height:120px;overflow-y:auto;overscroll-behavior:contain;padding:2px}
      .tvx-y{display:flex;gap:9px;align-items:flex-start;padding:8px 0;border-bottom:1px solid var(--line2);font-size:14px;line-height:1.4;overflow-wrap:anywhere}
      .tvx-y:last-child{border-bottom:0}
      .tvx-y .tvx-y-a{flex:none;width:28px;height:28px;border-radius:50%;display:grid;place-items:center;font-size:12px;font-weight:800;color:#fff;background:hsl(var(--h) 55% 40%)}
      .tvx-y .tvx-y-g{flex:1;min-width:0}.tvx-y .tvx-y-g b{font-size:13px;margin-right:6px}.tvx-y .tvx-y-g small{color:var(--faint);font-size:11.5px}
      .tvx-y .tvx-y-g p{margin:2px 0 0;color:var(--txt)}
      .tvx-y.ekranda{background:rgba(242,179,61,.07);border-radius:10px;padding:8px 6px}
      .tvx-y .tvx-y-et{display:inline-block;font-size:10.5px;font-weight:800;padding:1px 6px;border-radius:5px;background:rgba(76,141,255,.18);color:#9DBDFF;margin-left:4px;vertical-align:1px}
      .tvx-y .tvx-y-et.e{background:rgba(242,179,61,.2);color:#FFD27A}
      .tvx-y .tvx-y-b{display:flex;gap:6px;flex-wrap:wrap;margin-top:6px}
      .tvx-mini{display:inline-flex;align-items:center;gap:5px;min-height:34px;padding:0 11px;border-radius:999px;font-size:12.5px;font-weight:750;background:var(--panel2);color:var(--txt);box-shadow:inset 0 0 0 1px var(--line2)}
      .tvx-mini.on{background:rgba(242,179,61,.18);color:#FFD27A;box-shadow:inset 0 0 0 1px rgba(242,179,61,.5)}
      .tvx-mini.kirmizi{color:#FF9A9E}
      .tvx-soru{padding:11px 12px;border-radius:14px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);margin-bottom:8px}
      .tvx-soru p{margin:0 0 4px;font-size:15px;line-height:1.4;overflow-wrap:anywhere}
      .tvx-soru small{font-size:12px;color:var(--mut)}
      .tvx-yazk{display:grid;gap:8px;margin-bottom:12px}
      .tvx-yazk textarea{width:100%;min-height:52px;max-height:120px;resize:vertical;font-size:16px;box-sizing:border-box}
      .tvx-yazk label.tvx-onay{display:flex;align-items:center;gap:9px;font-size:14px;color:var(--txt2);min-height:40px}
      .tvx-yazk label.tvx-onay input{width:20px;height:20px;accent-color:#F2B33D;flex:none}
      .tv-mesaj.sistem{max-width:100%;text-align:center;background:none;box-shadow:none;padding:4px 8px;margin:0 0 10px}
      .tv-mesaj.sistem p{display:inline-block;margin:0;padding:5px 11px;border-radius:999px;font-size:12.5px;font-weight:700;color:var(--txt2);background:rgba(255,255,255,.06);box-shadow:inset 0 0 0 1px var(--line2)}
      .tv-mesaj.seyirci{max-width:100%;background:rgba(242,179,61,.08);box-shadow:inset 3px 0 0 #F2B33D;--k:#FFD27A}
      .tv-mesaj.seyirci .tv-rol{color:#F2B33D}
      /* reji masası */
      .tvx-reji{box-shadow:inset 0 0 0 1px rgba(76,141,255,.35)}
      .tvx-reji h2{display:flex;align-items:center;gap:8px}
      .tvx-reji h2 small{font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;padding:2px 8px;border-radius:999px;background:rgba(76,141,255,.18);color:#9DBDFF}
      .tvx-reji h3{font-size:15px;margin:16px 0 8px}
      .tvx-reji .tvx-r-sec{display:grid;gap:8px}
      .tvx-reji .tvx-r-sec label.tvx-dogru{display:flex;align-items:center;gap:8px}
      .tvx-reji .tvx-r-sec label.tvx-dogru input[type=radio]{flex:none;width:20px;height:20px;accent-color:#2FBF8F}
      .tvx-reji .tvx-r-sec label.tvx-dogru input[type=text]{flex:1;min-width:0;font-size:16px}
      .tvx-reji .tvx-hazir{display:flex;gap:6px;overflow-x:auto;scrollbar-width:none;padding-bottom:2px}
      .tvx-reji .tvx-hazir::-webkit-scrollbar{display:none}
      .tvx-reji .tvx-hazir button{flex:none}
      .tvx-kisi-s{display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:1px solid var(--line2);flex-wrap:wrap}
      .tvx-kisi-s:last-child{border-bottom:0}
      .tvx-kisi-s>span{flex:1;min-width:0;overflow-wrap:anywhere}
      /* kanal seviyesi, takip */
      .tvx-sev{display:inline-flex;align-items:center;gap:5px;font-size:11px;font-weight:800;letter-spacing:.03em;padding:2px 8px;border-radius:999px;background:rgba(76,141,255,.16);color:#9DBDFF;white-space:nowrap}
      .tvx-sev.k2{background:rgba(47,191,143,.16);color:#7FE0BC}.tvx-sev.k3{background:rgba(242,179,61,.18);color:#FFD27A}.tvx-sev.k4{background:rgba(240,69,75,.2);color:#FF9A9E}
      .tvx-ilerle{margin-top:12px}
      .tvx-ilerle .tvx-isi-c{height:8px;border-radius:5px;background:var(--panel2);overflow:hidden}
      .tvx-ilerle .tvx-isi-c i{display:block;height:100%;width:var(--p,0%);background:linear-gradient(90deg,#4C8DFF,#2FBF8F)}
      .tvx-ilerle small{display:block;margin-top:6px;font-size:12.5px;color:var(--txt2);line-height:1.4}
      .tvx-takipler{display:flex;gap:8px;overflow-x:auto;scrollbar-width:none;margin:0 0 12px;padding:2px}
      .tvx-takipler::-webkit-scrollbar{display:none}
      .tvx-takipler button{flex:none;display:flex;align-items:center;gap:7px;padding:7px 11px 7px 7px;border-radius:999px;background:var(--panel);box-shadow:inset 0 0 0 1px var(--line);font-size:13px;font-weight:750;color:var(--txt);max-width:220px}
      .tvx-takipler button span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
      .tvx-takipler button.canli{box-shadow:inset 0 0 0 1.5px rgba(240,69,75,.7)}
      .tvx-etiket{display:inline-flex;align-items:center;gap:4px;font-size:11px;font-weight:800;padding:1px 7px;border-radius:999px;background:rgba(242,179,61,.16);color:#FFD27A;margin-right:4px}
      .tvx-etiket.mavi{background:rgba(76,141,255,.16);color:#9DBDFF}
      /* reyting tablosu */
      .tvx-rey{display:flex;align-items:center;gap:10px;padding:10px 2px;border-bottom:1px solid var(--line2);width:100%;text-align:left;color:var(--txt)}
      .tvx-rey:last-child{border-bottom:0}
      .tvx-rey .tvx-rey-n{flex:none;width:24px;font-family:var(--disp);font-size:18px;color:var(--mut);text-align:center;font-variant-numeric:tabular-nums}
      .tvx-rey .tvx-rey-n.ilk{color:#FFD27A}
      .tvx-rey .tvx-rey-g{flex:1;min-width:0}
      .tvx-rey .tvx-rey-g b{display:block;font-size:14.5px;line-height:1.3;overflow-wrap:anywhere}
      .tvx-rey .tvx-rey-g small{display:block;font-size:12px;color:var(--mut);margin-top:2px;overflow-wrap:anywhere}
      .tvx-rey .tvx-rey-c{height:4px;border-radius:2px;background:var(--panel2);margin-top:6px;overflow:hidden}
      .tvx-rey .tvx-rey-c i{display:block;height:100%;width:var(--p);background:linear-gradient(90deg,#E23A40,#F2B33D)}
      .tvx-rey .tvx-rey-s{flex:none;text-align:right;font-variant-numeric:tabular-nums;font-size:13px;color:var(--txt2)}
      .tvx-rey .tvx-rey-s b{display:block;font-family:var(--disp);font-size:18px;color:#fff}
      .tvx-bitti{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-top:12px}
      .tvx-bitti>div{padding:9px 8px;border-radius:12px;background:rgba(255,255,255,.06);text-align:center}
      .tvx-bitti b{display:block;font-family:var(--disp);font-size:20px;color:#fff;font-variant-numeric:tabular-nums;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .tvx-bitti small{font-size:11.5px;color:#C9D1E6}
      .tvx-akis .tvx-a-g .tv-canli,.tvx-akis .tvx-a-g .tvx-etiket{display:inline-flex;margin-top:0;width:auto}
      .tvx-akis .tvx-a-g .tvx-etiket{margin:2px 4px 0 0}
      #tvStudyo .kx-sek{position:relative;top:auto}
      @media (prefers-reduced-motion:reduce){.tvx-kayan .tvx-ky-i span{animation-duration:80s}.tvx-ucan{display:none}.tvx-soz,.tvx-emo-d button.pat{animation:none}.tvx-rek .tvx-rek-k>div{animation:none;opacity:1;position:relative}.tvx-rek .tvx-rek-k>div+div{display:none}}
      @media (max-width:350px){.tvx-emo-d{grid-template-columns:repeat(3,minmax(0,1fr))}.tvx-sahne h2{font-size:21px}.tvx-soz q{font-size:18px}.tvx-opts{grid-template-columns:1fr}.tvx-bitti b{font-size:17px}}
      @media (max-width:350px){.tvx-e-orta h2{font-size:21px}.tvx-kose{grid-template-columns:1fr 1fr}.tvx-akis .tvx-saat{width:46px;font-size:18px}}`;
    document.head.appendChild(s);
  }

  /* ------------------------------------------------------------------ ortak parçalar */
  function progZaman(p) {
    if (p.durum === "canli") return p.acik_uclu ? "Sunucu bitirene kadar" : "Bitiş " + saatYaz(p.bit);
    if (p.durum === "planli") return tarihSaat(p.bas) + (p.acik_uclu ? " · sunucu bitirene kadar" : " – " + saatYaz(p.bit));
    if (p.durum === "iptal") return "İptal edildi";
    return "Bitti · " + tarihSaat(p.bit);
  }
  const konukYazi = p => (p.konuklar || []).length ? "Konuklar: " + p.konuklar.map(e).join(", ") : "";
  // 209: ana ekran eki (takip, hatırlatma, kanal seviyeleri); sunucu eskiyse boş kalır
  let EK = null;
  const hatirlatildi = id => !!EK && (EK.hatirlat || []).indexOf(Number(id)) >= 0;
  const takipte = id => !!EK && (EK.takip || []).indexOf(Number(id)) >= 0;
  const kanalEk = id => (EK && EK.kanallar && EK.kanallar[String(id)]) || null;
  const seviyeRozet = sv => sv ? `<span class="tvx-sev k${Number(sv.kademe) || 1}">${e(sv.ad)}</span>` : "";
  function akisEtiket(p) {
    const h = [];
    if (p.tur === "yarisma" && Number(p.odul) > 0) h.push(`<span class="tvx-etiket">Ödül ${tl(p.odul)}</span>`);
    if (p.durum === "planli" && hatirlatildi(p.id)) h.push(`<span class="tvx-etiket mavi">Hatırlatma kurulu</span>`);
    const bek = EK && EK.hatirlat_sayi ? Number(EK.hatirlat_sayi[String(p.id)]) || 0 : 0;
    if (p.durum === "planli" && bek > 0) h.push(`<span class="tvx-etiket mavi">${n(bek)} kişi bekliyor</span>`);
    return h.length ? `<em>${h.join("")}</em>` : "";
  }
  // yayın akışı satırı: solda saat, sağda program
  function akisSatir(p, kanalGoster) {
    const canli = p.durum === "canli", bitti = p.durum === "bitti" || p.durum === "iptal";
    const saat = canli ? `<span class="tvx-saat">${saatYaz(p.bas)}<small>şimdi</small></span>`
      : bitti ? `<span class="tvx-saat">${saatYaz(p.bas)}<small>${tarih(p.bas)}</small></span>`
      : `<span class="tvx-saat">${saatYaz(p.bas)}<small>${p.acik_uclu ? "açık uçlu" : saatYaz(p.bit) + "’e dek"}</small></span>`;
    return `<button type="button" class="tvx-akis${canli ? " canli" : ""}" onclick="tvStudyoAc(${Number(p.id)})">${saat}
      <span class="tvx-a-g">${canli ? '<span class="tv-canli" style="margin:0 0 4px">Canlı</span>' : ""}<b>${e(p.baslik)}</b>
        <span>${kanalGoster ? logo(p.kanal, "k") + e(p.kanal) + " · " : ""}${e(p.tur_ad)} · sunucu ${e(p.sunucu || "—")}</span>
        ${konukYazi(p) ? `<em>${konukYazi(p)}</em>` : ""}
        ${akisEtiket(p)}
        <em>${canli ? `${n(p.izleyici)} izleyici · ${progZaman(p)}` : bitti ? `${p.durum === "iptal" ? "İptal edildi" : n(p.izleyici) + " izleyici" + (Number(p.zirve) > 0 ? " · zirve " + n(p.zirve) : "")}` : ""}${p.reklam ? ` · ${p.reklam} reklam` : ""}</em>
      </span><span class="tvx-ok" aria-hidden="true">›</span></button>`;
  }
  // akışı güne göre gruplar (aynı gün başlığı tekrar etmez)
  function gunluAkis(liste, kanalGoster) {
    let son = "", h = "";
    const bugun = tarih(simdi()), yarin = tarih(simdi() + 864e5);
    liste.forEach(p => { const g = tarih(p.bas); if (g !== son) { son = g; h += `<div class="tvx-gun">${g === bugun ? "Bugün" : g === yarin ? "Yarın" : g}</div>`; } h += akisSatir(p, kanalGoster); });
    return h;
  }
  // yayın monitörü: canlı program ya da sıradaki yayın
  function monitor(p, canliSayi) {
    if (!p) return `<div class="tvx-ekran"><div class="tvx-cubuk">${["#e8e8e8", "#e3d84a", "#4ad6d9", "#4ad65a", "#d64ad0", "#d9473f", "#3f4fd9"].map(c => `<i style="background:${c};opacity:.55"></i>`).join("")}</div>
      <div class="tvx-e-orta" style="margin-top:6px"><small>Yayın yok</small><h2>Şu an canlı yayın yok</h2><p>Kanalların planladığı programlar Akış sekmesinde. Kendi kanalını kurup ilk yayını sen açabilirsin.</p></div></div>`;
    const canli = p.durum === "canli";
    if (!canli) {
      const ms = new Date(p.bas).getTime() - simdi();
      return `<button type="button" class="tvx-ekran" style="--h:${ton(p.kanal)}" onclick="tvStudyoAc(${Number(p.id)})">
        <div class="tvx-e-ust">${logo(p.kanal)}<span class="tvx-e-kanal">${e(p.kanal)}</span><span class="tvx-e-saat">${tarihSaat(p.bas)}</span></div>
        <div class="tvx-e-orta"><small>Sıradaki yayın · ${e(p.tur_ad)}</small><h2>${e(p.baslik)}</h2><p>Sunucu ${e(p.sunucu || "—")}${konukYazi(p) ? " · " + konukYazi(p) : ""}</p></div>
        <div class="tvx-e-alt"><span class="tvx-izl">Başlamasına<span class="tvx-sayac" style="display:block;margin-top:3px">${kalan(ms)}</span></span><span class="btn ikinci">Programa git</span></div></button>`;
    }
    return `<button type="button" class="tvx-ekran canli" style="--h:${ton(p.kanal)}" onclick="tvStudyoAc(${Number(p.id)})">
      <div class="tvx-e-ust">${logo(p.kanal)}<span class="tvx-e-kanal">${e(p.kanal)}</span><span class="tv-canli" style="margin:0">Canlı</span></div>
      <div class="tvx-e-orta"><small>${e(p.tur_ad)}</small><h2>${e(p.baslik)}</h2><p>Sunucu ${e(p.sunucu || "—")}${konukYazi(p) ? " · " + konukYazi(p) : ""}</p></div>
      <div class="tvx-e-alt"><span class="tvx-izl"><b>${n(p.izleyici)}</b>izleyici · ${progZaman(p)}${canliSayi > 1 ? `<br>${canliSayi - 1} canlı yayın daha` : ""}</span><span class="btn canli">Yayını izle</span></div></button>`;
  }
  // eski çağrılar için (başka modüller progKart beklemez ama ad korunur)
  const progKart = (p, kanalGoster) => akisSatir(p, kanalGoster);
  window.tvStudyoAc = id => ekranAc(() => window.tvStudyoEkrani(id));
  window.tvKanalAc = id => ekranAc(() => window.tvKanalEkrani(id));
  const yaziyor = kok => { const k = document.getElementById(kok); return !!k && Array.prototype.some.call(k.querySelectorAll("input,textarea"), x => x.type !== "checkbox" && x.type !== "radio" && x.type !== "hidden" && (x.value || "").trim() !== ""); };

  /* ------------------------------------------------------------------ Gündem: öne çıkan TV kartı + canlı rozeti (45 sn önbellek) */
  let rozetOn = { t: 0, d: null };
  const ozetSifirla = () => { rozetOn.t = 0; };
  function gundemKartVeri(d) {
    const o = { id: "tvGundemKart", ikon: "tv", renk: "229,72,77", acik: "#ffb1b5", etiket: "TV Kanalları", git: "Aç", onclick: "ekranAc(tvKanallariEkrani)", canli: false };
    d = d || {};
    if (d.ilk) {
      o.canli = true; o.etiket = d.ilk.kanal + " · " + d.ilk.tur_ad; o.baslik = d.ilk.baslik;
      o.alt = `${d.ilk.izleyici} kişi izliyor · sunucu ${d.ilk.sunucu || ""}${Number(d.canli) > 1 ? " · " + (d.canli - 1) + " canlı yayın daha" : ""}`;
      o.git = "İzle"; o.onclick = "tvStudyoAc(" + Number(d.ilk.id) + ")";
    } else if (Number(d.davet) > 0) {
      o.baslik = d.davet + " program davetin var"; o.alt = "Bir TV programına konuk olarak çağrıldın; yanıtını bekliyorlar."; o.git = "Yanıtla";
    } else if (Number(d.teklif) > 0) {
      o.baslik = "Sunuculuk teklifin var"; o.alt = "Bir TV kanalı sana günlük ücretle sunuculuk teklif etti."; o.git = "Yanıtla";
    } else if (d.siradaki) {
      o.etiket = "TV Kanalları · yayın akışı"; o.baslik = tarihSaat(d.siradaki.bas) + " · " + d.siradaki.baslik;
      o.alt = `${d.siradaki.kanal} · ${d.siradaki.tur_ad}${Number(d.yakinda) > 1 ? " · " + d.yakinda + " program planlandı" : ""}`; o.git = "Akış";
    } else {
      o.baslik = "Canlı yayınlar ve siyasi düellolar";
      o.alt = Number(d.kanal) > 0 ? `${d.kanal} kanal var; şu an yayın yok. Yayın akışına bak ya da kendi kanalını kur.` : "Henüz kanal yok. İlk TV kanalını sen kur; program yap, reklam al.";
    }
    return o;
  }
  const gundemde = () => { try { const h = document.querySelector("header.ust h1"); return D.sekme === "gundem" && !(D.yigin || []).length && !!h && h.textContent.trim() === "Gündem"; } catch (_) { return false; } };
  function gundemKartKoy(d) {
    if (!window.SO_ONE_CIKAN || !gundemde()) return;
    window.SO_ONE_CIKAN.koy(gundemKartVeri(d), ic => {
      const hz = ic.querySelector('.pa-hizli[data-pa-hizli="gundem"]'); if (hz) return { el: hz, yer: "afterend" };
      const ks = ic.querySelector(".so-gundem-kisa"); if (ks) return { el: ks, yer: "beforebegin" };
      return { el: ic, yer: "afterbegin" };
    });
  }
  window.tvGundemRozet = async function () {
    const yaz = d => { if (!d) return; const h = Number(d.canli) > 0 || d.ilk ? '<span class="tv-canli" style="margin:0 0 0 4px">Canlı</span>' : "";
      document.querySelectorAll(".tv-gundem-rozet").forEach(el => { if (el.innerHTML !== h) el.innerHTML = h; }); };
    try {
      stil();
      if (window.SO_ONE_CIKAN) window.SO_ONE_CIKAN.tekrarla(() => gundemKartKoy(rozetOn.d));
      yaz(rozetOn.d);
      if (rozetOn.d && Date.now() - rozetOn.t < 45000) return;
      rozetOn = { t: Date.now(), d: rozetOn.d };
      const d = await rpc("tv_canli_ozet"); rozetOn = { t: Date.now(), d }; yaz(d); gundemKartKoy(d);
    } catch (_) {}
  };

  /* ------------------------------------------------------------------ ana ekran: Yayın Merkezi */
  window.tvKanallariEkrani = async function () {
    stil();
    if (!document.getElementById("tvKok")) yukleniyor("TV Kanalları");
    let d; try { [d, EK] = await Promise.all([rpc("tv_liste"), rpc("tv_liste_ek").catch(() => null)]); } catch (err) { return hataEkran("TV Kanalları", err); }
    const teklif = d.sunucu_teklif || [], davet = d.davetlerim || [], canli = d.canli || [], yakinda = d.yakinda || [], biten = d.biten || [], kanallar = d.kanallar || [], sun = d.sunuculuk || [];
    const enCok = canli.slice().sort((a, b) => (b.izleyici || 0) - (a.izleyici || 0))[0];
    const SEK = [["yayin", "Yayında", canli.length ? String(canli.length) : ""], ["akis", "Akış", yakinda.length ? String(yakinda.length) : ""], ["kanallar", "Kanallar", String(kanallar.length)], ["reyting", "Reyting"],
      ["kanalim", d.kanalim ? "Kanalım" : sun.length ? "Kanallarım" : "Kanal kur"], ["arsiv", "Arşiv"]];
    const akt = KX() ? KX().secili("tv", SEK, "yayin") : "yayin";
    const pano = (k, h) => KX() ? KX().pano("tv", k, akt, h) : h;
    const gelen = teklif.map(x => `<section class="tvx-gelen"><h2>Sunuculuk teklifi</h2>
        <p><b>${e(x.kanal)}</b> (sahibi ${e(x.sahip)}) sana günlük <b>${tl(x.gunluk_ucret)}</b> ücretle sunuculuk teklif ediyor. Ücret her gün kanal kasasından cüzdanına ödenir; dilediğinde ayrılabilirsin.</p>
        <div class="tv-iki"><button class="btn altin" onclick="tvSunucuYanit(${x.kanal_id},true)">Kabul et</button><button class="btn ikinci" onclick="tvSunucuYanit(${x.kanal_id},false)">Reddet</button></div></section>`).join("")
      + (davet.length ? `<section class="tvx-gelen"><h2>Program davetlerin</h2>${davet.map(p => `<div class="tv-satir"><b>${e(p.baslik)}</b>
        <div class="kucuk">${e(p.kanal)} · ${e(p.tur_ad)} · sunucu ${e(p.sunucu || "")} · ${progZaman(p)}</div>
        <div class="tv-iki" style="margin-top:8px"><button class="btn altin" onclick="tvKonukYanit(${p.id},true,true)">Katılıyorum</button><button class="btn ikinci" onclick="tvKonukYanit(${p.id},false,true)">Katılamam</button></div></div>`).join("")}</section>` : "");
    const kanalimHtml = (d.kanalim ? `<section class="kart"><div class="tvx-kunye">${logo(d.kanalim.ad, "b")}<div><h2>${e(d.kanalim.ad)}</h2><p>Kanalının sahibisin. Program aç, sunucu al, reklamları onayla.</p></div></div>
          <button class="btn altin" style="margin-top:12px" onclick="tvKanalAc(${d.kanalim.id})">Kanalımı yönet</button></section>`
        : `<section class="kart"><h2>TV kanalı kur</h2>
          <div class="tvx-kur">${logo("Yeni Kanal", "b").replace('aria-hidden="true"', 'id="tvKurLogo" aria-hidden="true"')}<div><b id="tvKurAd">Kanalının adı</b><small>Kanal amblemi adından oluşur.</small></div></div>
          <p class="alt">Canlı programlar ve siyasi düellolar düzenle, maaşlı sunucu çalıştır, yayınlarına reklam alıp para kazan. Yayın lisansı <b>${tl(d.kur_ucret)}</b>, cüzdanından ödenir.</p>
          <div class="alan"><label for="tvKAd">Kanal adı</label><input id="tvKAd" maxlength="40" placeholder="Örn. Başkent TV" oninput="tvKurOnizle(this.value)"></div>
          <div class="alan"><label for="tvKSlogan">Slogan (isteğe bağlı)</label><input id="tvKSlogan" maxlength="120"></div>
          <button class="btn altin" onclick="tvKanalKur()">Kanalı kur</button></section>`)
      + (sun.length ? `<section class="kart"><h2>Sunuculuk yaptığım kanallar</h2>${sun.map(x => `<div class="tv-satir" style="display:flex;gap:10px;align-items:center;flex-wrap:wrap">${logo(x.kanal)}<span style="flex:1;min-width:0"><b>${e(x.kanal)}</b><br><span class="kucuk">günlük ${tl(x.gunluk_ucret)}</span></span>
          <button class="btn ikinci" style="margin:0" onclick="tvKanalAc(${x.kanal_id})">Kanala git, program aç</button></div>`).join("")}</section>` : "");
    iskelet("TV Kanalları", `<div id="tvKok" class="tvx">
      ${monitor(enCok || yakinda[0], canli.length)}
      ${gelen}
      ${KX() ? KX().sekmeler("tv", SEK, akt, "#E23A40") : ""}
      ${pano("yayin", `${takipSerit(kanallar, canli)}
        ${enCok ? (KX() ? KX().bas("Şu an yayında", canli.length + " yayın") : "<h2>Şu an yayında</h2>") + canli.map(p => akisSatir(p, true)).join("")
          : (KX() ? KX().bas("Şu an yayında") : "") + bos("Şu an canlı yayın yok.") + (yakinda.length ? `<button class="btn ikinci" onclick="SO_KX.gec('tv','akis')">Yayın akışına bak</button>` : "")}`)}
      ${pano("akis", (KX() ? KX().bas("Yayın akışı", "saati gelince kendiliğinden başlar") : "<h2>Yayın akışı</h2>") + (yakinda.length ? gunluAkis(yakinda, true) : bos("Planlanmış program yok."))) }
      ${pano("kanallar", (KX() ? KX().bas("Kanallar", kanallar.length + " kanal") : "<h2>Kanallar</h2>") + (kanallar.length ? `<div class="tvx-izgara">${kanallar.map(k => `<button type="button" class="tvx-kanal${d.kanalim && d.kanalim.id === k.id ? " ben" : ""}" onclick="tvKanalAc(${k.id})">${k.canli ? '<span class="tv-canli">Canlı</span>' : ""}${logo(k.ad)}
          <span><b>${e(k.ad)}</b></span>${kanalEk(k.id) ? `<span>${seviyeRozet(kanalEk(k.id).seviye)}</span>` : ""}<small>${k.slogan ? e(k.slogan) + "<br>" : ""}Sahibi ${e(k.sahip)}<br>${n(k.program)} program · ${n(k.toplam_izleyici)} izlenme${kanalEk(k.id) ? ` · ${n(kanalEk(k.id).takipci)} takipçi` : ""}${takipte(k.id) ? "<br><b style=\"color:#FFD27A;font-size:12px\">Takip ediyorsun</b>" : ""}</small></button>`).join("")}</div>` : bos("Henüz kurulmuş kanal yok. İlk kanalı sen kur.")))}
      ${pano("reyting", `<div id="tvReytingK">${bos("Reyting tablosu yükleniyor…")}</div>`)}
      ${pano("kanalim", kanalimHtml)}
      ${pano("arsiv", (KX() ? KX().bas("Biten programlar") : "<h2>Biten programlar</h2>") + (biten.map(p => akisSatir(p, true)).join("") || bos("Henüz biten program yok.")))}
    </div>`, { geri: D.yigin.length > 0 });
    const rb = document.querySelector('[data-kx="tv"] button[data-k="reyting"]');
    if (rb) rb.addEventListener("click", () => window.tvReytingYukle());
    if (akt === "reyting") window.tvReytingYukle();
    const taz = async () => { if (!document.getElementById("tvKok") || document.hidden || $("#modal") || yaziyor("tvKok")) return; window.tvKanallariEkrani(); };
    if (window.CANLI && CANLI.izle) CANLI.izle({ anahtarlar: [], tazele: taz, hizliMs: 30000, yedekMs: 30000, yayilim: 3000 });
  };
  // takip ettiğin kanallar: canlı olan önce, dokununca yayına ya da kanala gider
  function takipSerit(kanallar, canli) {
    if (!EK || !(EK.takip || []).length) return "";
    const liste = kanallar.filter(k => takipte(k.id)).sort((a, b) => (b.canli ? 1 : 0) - (a.canli ? 1 : 0));
    if (!liste.length) return "";
    return (KX() ? KX().bas("Takip ettiklerin", liste.filter(k => k.canli).length ? liste.filter(k => k.canli).length + " canlı" : "") : "") + `<div class="tvx-takipler">${liste.map(k => {
      const pr = canli.find(p => Number(p.kanal_id) === Number(k.id));
      return `<button type="button" class="${pr ? "canli" : ""}" onclick="${pr ? `tvStudyoAc(${Number(pr.id)})` : `tvKanalAc(${Number(k.id)})`}">${logo(k.ad, "k")}<span>${e(k.ad)}</span>${pr ? '<span class="tv-canli" style="margin:0">Canlı</span>' : ""}</button>`; }).join("")}</div>`;
  }
  let reytingOn = { t: 0, d: null };
  window.tvReytingYukle = async function () {
    const kok = document.getElementById("tvReytingK"); if (!kok) return;
    let d = reytingOn.d;
    if (!d || Date.now() - reytingOn.t > 60000) {
      try { d = await rpc("tv_reyting"); reytingOn = { t: Date.now(), d }; }
      catch (err) { kok.innerHTML = bos("Reyting tablosu şu an açılamadı: " + e(hataCevir(err.message))); return; }
    }
    const k2 = document.getElementById("tvReytingK"); if (k2) k2.innerHTML = reytingHtml(d);
  };
  function reytingHtml(d) {
    const pr = d.programlar || [], ka = d.kanallar || [], su = d.sunucular || [], du = d.duellocular || [], ya = d.yarismacilar || [];
    const enCok = Math.max(1, ...pr.map(p => Number(p.izleyici) || 0)), kEn = Math.max(1, ...ka.map(k => Number(k.izlenme) || 0));
    const satir = (i, bas, alt, sag, sagAlt, oran, onclick) => `<${onclick ? `button type="button" onclick="${onclick}"` : "div"} class="tvx-rey"><span class="tvx-rey-n${i === 0 ? " ilk" : ""}">${i + 1}</span>
      <span class="tvx-rey-g"><b>${bas}</b><small>${alt}</small>${oran != null ? `<span class="tvx-rey-c" style="--p:${Math.max(4, Math.round(oran * 100))}%"><i></i></span>` : ""}</span>
      <span class="tvx-rey-s"><b>${sag}</b>${sagAlt}</span></${onclick ? "button" : "div"}>`;
    const gh = d.gecen_hafta && d.gecen_hafta.ozet && !d.gecen_hafta.ozet.kurulum ? d.gecen_hafta.ozet : null;
    return `<section class="kart"><div class="tvx-kunye"><span class="tvx-logo b" style="--h:42" aria-hidden="true">R</span><div><h2>Haftanın reytingleri</h2><p>Son 7 gün · her pazartesi resmî tablo haber olur</p></div></div>
        ${KX() ? KX().sayilar([[n(d.program_sayi), "program"], [n(d.izlenme), "izlenme"], [n((d.baz || {}).cevrimici), "şu an çevrimiçi"]]) : ""}</section>
      ${gh && (gh.kanallar || [])[0] ? `<section class="tvx-gelen" style="margin-top:10px"><h2>Geçen haftanın birincisi: ${e(gh.kanallar[0].ad)}</h2><p>${n(gh.kanallar[0].izlenme)} izlenme${(gh.programlar || [])[0] ? ` · en çok izlenen program "${e(gh.programlar[0].baslik)}" (${n(gh.programlar[0].izleyici)} izleyici)` : ""}</p></section>` : ""}
      ${KX() ? KX().bas("En çok izlenen programlar") : "<h2>En çok izlenen programlar</h2>"}<section class="kart">${pr.map((p, i) => satir(i, e(p.baslik), `${e(p.kanal)} · ${e(p.tur_ad)} · ${e(p.sunucu || "")}`, n(p.izleyici), "izleyici", (Number(p.izleyici) || 0) / enCok, `tvStudyoAc(${Number(p.id)})`)).join("") || bos("Bu hafta henüz biten program yok.")}</section>
      ${KX() ? KX().bas("Kanal sıralaması") : ""}<section class="kart">${ka.map((k, i) => satir(i, e(k.ad), `${e(k.seviye || "")} · ${n(k.program)} program · ${n(k.takipci)} takipçi`, n(k.izlenme), "izlenme", (Number(k.izlenme) || 0) / kEn, `tvKanalAc(${Number(k.id)})`)).join("") || bos("Henüz sıralama yok.")}</section>
      ${su.length ? (KX() ? KX().bas("Ekranın yüzleri", "en çok izlenen sunucular") : "") + `<section class="kart">${su.map((x, i) => satir(i, e(x.kad), n(x.program) + " program", n(x.izlenme), "izlenme")).join("")}</section>` : ""}
      ${du.length ? (KX() ? KX().bas("Düello şampiyonları") : "") + `<section class="kart">${du.map((x, i) => satir(i, e(x.kad), n(x.oy) + " izleyici oyu", n(x.galibiyet), "galibiyet")).join("")}</section>` : ""}
      ${ya.length ? (KX() ? KX().bas("Yarışma şampiyonları") : "") + `<section class="kart">${ya.map((x, i) => satir(i, e(x.kad), `${n(x.derece)} derece · ${tl(x.odul)} ödül`, n(x.birincilik), "birincilik")).join("")}</section>` : ""}`;
  }
  window.tvKurOnizle = v => {
    const ad = (v || "").trim(), l = document.getElementById("tvKurLogo"), b = document.getElementById("tvKurAd");
    if (l) { l.style.setProperty("--h", ton(ad || "Yeni Kanal")); l.textContent = harf(ad || "Yeni Kanal"); }
    if (b) b.textContent = ad || "Kanalının adı";
  };

  const anaCalis = async (fn, basari, sonra) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(typeof basari === "function" ? basari(r) : basari); if (sonra) await sonra(r); else await yenidenCiz(); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKanalKur = async () => {
    const ad = ($("#tvKAd").value || "").trim(), sl = ($("#tvKSlogan").value || "").trim();
    if (ad.length < 3) return toast("Kanal adı en az 3 karakter olmalı.", true);
    if (!await onayla("TV kanalı kur", `"${e(ad)}" kanalı kurulacak. Yayın lisansı ${tl(250000)} cüzdanından alınır ve iade edilmez.`, "Kanalı kur")) return;
    return anaCalis(() => rpc("tv_kanal_kur", { p_ad: ad, p_slogan: sl || null }), "Kanalın kuruldu.", r => { $("#tvKAd").value = ""; $("#tvKSlogan").value = ""; window.tvKanalAc(r.id); });
  };
  window.tvSunucuYanit = (kanal, kabul) => anaCalis(() => rpc("tv_sunucu_yanit", { p_kanal: kanal, p_kabul: kabul }), kabul ? "Sunuculuk sözleşmen başladı." : "Teklif reddedildi.");
  window.tvKonukYanit = (prog, kabul, listeden) => anaCalis(() => rpc("tv_konuk_yanit", { p_program: prog, p_kabul: kabul }), kabul ? "Programa konuk oldun." : "Davet reddedildi.",
    listeden && kabul ? () => window.tvStudyoAc(prog) : null);

  /* ------------------------------------------------------------------ kanal ekranı */
  window.tvKanalEkrani = async function (id) {
    stil();
    if (!document.getElementById("tvKanalKok")) yukleniyor("TV kanalı");
    let d, ek; try { [d, ek] = await Promise.all([rpc("tv_kanal_detay", { p_kanal: id }), rpc("tv_kanal_ek", { p_kanal: id }).catch(() => null)]); } catch (err) { return hataEkran("TV kanalı", err); }
    const sv = ek && ek.seviye;
    const sunucular = d.sunucular || [], aktifSun = sunucular.filter(s => s.durum === "aktif"), ben = benimKad();
    const benSunucu = !d.benim && aktifSun.some(s => s.kad === ben);
    const programlar = d.programlar || [], gecmis = d.gecmis || [], bekleyen = d.bekleyen_reklam || [];
    const canliP = programlar.find(p => p.durum === "canli");
    const SEK = [["akis", "Yayın akışı", programlar.length ? String(programlar.length) : ""]]
      .concat(d.yayinciyim ? [["program", "Program aç"]] : [])
      .concat(d.benim ? [["kasa", "Kasa ve reklam", bekleyen.length ? String(bekleyen.length) : "", bekleyen.length > 0], ["sunucu", "Sunucular", String(aktifSun.length)]] : [])
      .concat([["arsiv", "Geçmiş"]]);
    const varsay = d.benim && bekleyen.length ? "kasa" : "akis";
    const akt = KX() ? KX().secili("tvk" + id, SEK, varsay) : varsay;
    const pano = (k, h) => KX() ? KX().pano("tvk" + id, k, akt, h) : h;
    const kasaHtml = d.benim ? `
      <section class="kart"><h2>Kanal kasası</h2>
        <div class="tvx-kasa">${tl(d.kasa)}</div>
        <p class="alt">Reklam gelirleri kasaya girer, sunucu ücretleri kasadan ödenir. Kasadaki parayı cüzdanına çekebilirsin.</p>
        <div class="alan" style="margin-top:8px"><label for="tvKasaT">Tutar (₺)</label><input id="tvKasaT" type="number" inputmode="numeric" min="100" step="100"></div>
        <div class="tv-iki"><button class="btn ikinci" onclick="tvKasa(${d.id},'yatir')">Kasaya yatır</button><button class="btn altin" onclick="tvKasa(${d.id},'cek')">Cüzdanıma çek</button></div>
        ${(d.hareketler || []).length ? `<details style="margin-top:12px"><summary class="kucuk" style="cursor:pointer">Kasa hareketleri (${d.hareketler.length})</summary>${d.hareketler.map(h => kv(e(h.aciklama || "") + " · " + tarihSaat(h.zaman), `<span style="color:${Number(h.tutar) < 0 ? "var(--al2)" : "var(--good)"}">${tl(h.tutar)}</span>`)).join("")}</details>` : ""}</section>
      <section class="kart"><h2>Onay bekleyen reklam talepleri</h2>
        ${bekleyen.map(r => `<div class="tv-satir"><b>${e(r.marka)}</b> <span class="kucuk">${e(r.sirket || r.veren)} · bütçe ${tl(r.butce)} · izleyici başına ${tl(r.birim)}</span>
          <div class="kucuk">"${e(r.metin)}" · program: ${e(r.program)} (${tarihSaat(r.program_bas)})</div>
          <div class="kucuk" style="color:var(--good)">En çok ${n(Math.floor(r.butce / Math.max(1, r.birim)))} izleyiciye kadar gelir getirir.</div>
          <div class="tv-iki" style="margin-top:8px"><button class="btn altin" onclick="tvReklamKarar(${r.id},true,${d.id})">Onayla</button><button class="btn ikinci" onclick="tvReklamKarar(${r.id},false,${d.id})">Reddet</button></div></div>`).join("") || bos("Bekleyen reklam talebi yok.")}</section>
      <section class="kart"><h2>Reklam ayarları</h2>
        <p class="alt">Reklamverenler programlarına bütçeli reklam verir; sen onaylarsın. Program bitince izleyici sayısı × birim ücret kadar (en çok bütçe) kazanırsın; %${d.reklam_vergisi} reklam vergisi kesilir.</p>
        <div class="alan"><label for="tvUcret">İzleyici başına reklam ücreti (₺, 50 – 2.000)</label><input id="tvUcret" type="number" inputmode="numeric" min="50" max="2000" step="10" data-ilk="${Number(d.izleyici_ucret)}" placeholder="${Number(d.izleyici_ucret)}"></div>
        <div class="alan"><label for="tvSlogan">Slogan</label><input id="tvSlogan" maxlength="120" placeholder="${e(d.slogan || "Slogan yaz")}"></div>
        <button class="btn ikinci" onclick="tvAyar(${d.id})">Kaydet</button></section>` : "";
    const sunucuHtml = d.benim ? `<section class="kart"><h2>Sunucular</h2>
        <p class="alt">Bir oyuncuya günlük ücretle sunuculuk teklif et. Kabul ederse ücreti her gün kanal kasasından ödenir; kasa yetmezse sözleşme sona erer.</p>
        ${sunucular.map(s => `<div class="tv-satir">${kisi(s)} <span class="kucuk">${s.durum === "aktif" ? "sunucu · " + tarih(s.bas) + " tarihinden beri" : "teklif bekliyor"} · günlük ${tl(s.gunluk_ucret)}${s.durum === "aktif" ? " · toplam " + tl(s.toplam) : ""}</span>
          <button class="btn ikinci" onclick="tvSunucuCikar(${d.id},'${e(s.kad)}',${s.durum === "aktif"})">${s.durum === "aktif" ? "Sözleşmeyi bitir" : "Teklifi geri çek"}</button></div>`).join("") || bos("Henüz sunucu yok; programları kendin sunabilirsin.")}
        ${aktifSun.length ? `<p class="kucuk" style="margin-top:6px">Günlük toplam sunucu gideri ${tl(aktifSun.reduce((t, s) => t + (Number(s.gunluk_ucret) || 0), 0))}; kasa bunu ${Math.floor((Number(d.kasa) || 0) / Math.max(1, aktifSun.reduce((t, s) => t + (Number(s.gunluk_ucret) || 0), 0)))} gün karşılar.</p>` : ""}
        <h3 style="margin-top:14px;font-size:15px">Yeni sunucu</h3>
        <div class="alan" style="margin-top:8px"><label for="tvSunKad">Kullanıcı adı</label><input id="tvSunKad" autocapitalize="off" maxlength="40"></div>
        <div class="alan"><label for="tvSunUcret">Günlük ücret (₺, 500 – 100.000)</label><input id="tvSunUcret" type="number" inputmode="numeric" min="500" max="100000" step="100"></div>
        <button class="btn ikinci" onclick="tvSunucuTeklif(${d.id})">Sunuculuk teklif et</button></section>` : "";
    const programAc = d.yayinciyim ? `
      <section class="kart"><h2>Program aç</h2>
        <p class="alt">Başlangıcı boş bırakırsan yayın hemen başlar. Tarih ve saat seçersen program yayın akışına girer ve saati gelince kendiliğinden başlar. Konukları programı açtıktan sonra çağırırsın.</p>
        <input type="hidden" id="tvTur" value="duello">
        <div class="tvx-tur" role="radiogroup" aria-label="Program türü">${Object.keys(TUR).map(k => `<label><input type="radio" name="tvTurSec" value="${k}"${k === "duello" ? " checked" : ""} onchange="document.getElementById('tvTur').value=this.value;var o=document.getElementById('tvOdulAlan');if(o)o.hidden=this.value!=='yarisma'"><span><b>${TUR[k][0]}</b><small>${TUR[k][1]}</small></span></label>`).join("")}</div>
        <div class="alan"><label for="tvBaslik">Başlık</label><input id="tvBaslik" maxlength="90" placeholder="Örn. Ekonomi düellosu"></div>
        <div class="alan"><label for="tvAcik">Kısa açıklama (isteğe bağlı)</label><input id="tvAcik" maxlength="300"></div>
        <div class="alan"><label for="tvBas">Başlangıç (cihazının saatine göre; boş = hemen)</label><input id="tvBas" type="datetime-local"></div>
        <div class="alan"><label for="tvSure">Süre</label><select id="tvSure">${SURELER.map(s => `<option value="${s[0]}"${s[0] === 30 ? " selected" : ""}>${s[1]}</option>`).join("")}<option value="">Sunucu bitirene kadar (en çok 3 saat)</option></select></div>
        ${d.benim && aktifSun.length ? `<div class="alan"><label for="tvSun">Sunucu</label><select id="tvSun"><option value="">Ben sunacağım</option>${aktifSun.map(s => `<option value="${e(s.kad)}">${e(s.kad)}</option>`).join("")}</select></div>` : ""}
        ${d.benim ? `<div class="alan" id="tvOdulAlan" hidden><label for="tvOdul">Yarışma ödül havuzu (₺, isteğe bağlı · yalnız bilgi yarışmasında, kanal kasasından)</label><input id="tvOdul" type="number" inputmode="numeric" min="1000" max="100000" step="1000" placeholder="Örn. 25000 · kasada ${tl(d.kasa)}"></div>` : ""}
        <p class="kucuk">${sv ? `${e(sv.ad)}: günde en çok ${Number(sv.gunluk)} program.` : "Bir kanal günde en çok 4 program açabilir."} Yarışmada sorular yayın sırasında Reji masasından sorulur; ödülü ilk üç alır (%50 · %30 · %20).</p>
        <button class="btn altin" onclick="tvProgramAc(${d.id})">Programı aç</button></section>` : "";
    iskelet(d.ad, `<div id="tvKanalKok" class="tvx">
      <section class="kart" style="margin-bottom:12px"><div class="tvx-kunye">${logo(d.ad, "b")}<div style="min-width:0"><h2>${e(d.ad)}</h2>${d.slogan ? `<p>${e(d.slogan)}</p>` : ""}
          ${ek ? `<p style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-top:6px">${seviyeRozet(sv)}<span class="kucuk">${n(ek.takipci)} takipçi${ek.hafta_sira ? ` · bu hafta ${n(ek.hafta_sira)}. sırada` : ""}</span></p>` : ""}</div></div>
        ${ek && !d.benim ? `<button class="btn ${ek.takip ? "ikinci" : "altin"}" style="margin-top:12px" id="tvTakipB" onclick="tvTakip(${d.id},${!ek.takip},'kanal')">${ek.takip ? "Takip ediliyor · bırak" : "Takip et · canlı yayına girince haber ver"}</button>` : ""}
        ${sv ? seviyeIlerle(sv, ek) : ""}
        ${KX() ? KX().sayilar([[n(programlar.length), "planlı / süren"], [n(gecmis.length), "geçmiş program"], [tl(d.izleyici_ucret).replace(" ₺", "₺"), "izleyici başı reklam"]]) : ""}
        <div style="margin-top:10px">${kv("Sahibi", kisi(d.sahip))}${kv("Kuruluş", tarih(d.kurulus))}${kv("Sunucular", aktifSun.map(s => e(s.kad)).join(", ") || "—")}${kv("İzleyici başına reklam ücreti", tl(d.izleyici_ucret))}</div>
        ${canliP ? `<button class="btn canli" style="margin-top:10px" onclick="tvStudyoAc(${canliP.id})">Şu an yayında: ${e(canliP.baslik)}</button>` : ""}
        ${benSunucu ? `<button class="btn ikinci" style="margin-top:8px" onclick="tvSunucuAyril(${d.id})">Sunuculuktan ayrıl</button>` : ""}</section>
      ${KX() ? KX().sekmeler("tvk" + id, SEK, akt, "#E23A40") : ""}
      ${pano("akis", (programlar.length ? gunluAkis(programlar, false) : bos("Planlanmış ya da süren program yok.")) + (d.yayinciyim ? `<button class="btn ikinci" onclick="SO_KX.gec('tvk${id}','program')">Yeni program aç</button>` : ""))}
      ${d.yayinciyim ? pano("program", programAc) : ""}
      ${d.benim ? pano("kasa", kasaHtml) + pano("sunucu", sunucuHtml) : ""}
      ${pano("arsiv", (KX() ? KX().bas("Geçmiş programlar") : "<h2>Geçmiş programlar</h2>") + (gecmis.map(p => akisSatir(p, false)).join("") || bos("Henüz biten program yok.")))}
    </div>`, { geri: true });
  };
  function seviyeIlerle(sv, ek) {
    const son = sv.sonraki_esik == null, alt = Number(sv.esik) || 0, ust = Number(sv.sonraki_esik) || 1, top = Number(sv.toplam) || 0;
    const oran = son ? 100 : Math.max(3, Math.min(100, Math.round(100 * (top - alt) / Math.max(1, ust - alt))));
    return `<div class="tvx-ilerle"><span class="tvx-isi-c" style="--p:${oran}%;display:block"><i></i></span>
      <small>${son ? `En üst seviye: günde ${Number(sv.gunluk)} program.` : `${n(top)} / ${n(ust)} izlenme · ${e(sv.sonraki_ad)} olunca günde ${Number(sv.sonraki_gunluk)} program`}${ek && ek.rekor ? ` · rekor: "${e(ek.rekor.baslik)}" ${n(ek.rekor.izleyici)} izleyici` : ""}</small></div>`;
  }
  window.tvTakip = async (kanal, ac, nereden) => {
    try {
      const r = await rpc("tv_takip", { p_kanal: kanal, p_ac: ac }); toast(ac ? "Takip ediyorsun: kanal canlı yayına girince bildirim gelir." : "Takibi bıraktın.");
      if (EK) { EK.takip = (EK.takip || []).filter(x => x !== kanal); if (ac) EK.takip.push(kanal); }
      if (nereden === "kanal") return window.tvKanalEkrani(kanal);
      if (window._tvStudyoId && S && S.c && document.getElementById("tvStudyo")) { S.c.takip = r.takip; S.c.takipci = r.takipci; window.tvStudyoEkrani(S.id, S.d, S.c); }
    } catch (err) { toast(hataCevir(err.message), true); }
  };
  const kanalCalis = async (id, fn, basari) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(basari); await window.tvKanalEkrani(id); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvKasa = async (id, yon) => {
    const el = $("#tvKasaT"), t = Math.round(Number(el.value) || 0); if (t < 100) return toast("En az 100 ₺ gir.", true);
    el.value = "";
    return kanalCalis(id, () => rpc("tv_kasa", { p_kanal: id, p_yon: yon, p_tutar: t }), yon === "yatir" ? tl(t) + " kasaya yatırıldı." : tl(t) + " cüzdanına geçti.");
  };
  window.tvAyar = id => {
    const u = $("#tvUcret"), s = $("#tvSlogan"), uv = (u.value || "").trim(), sv = (s.value || "").trim();
    if (!uv && !sv) return toast("Değiştirmek istediğin alanı doldur.", true);
    u.value = ""; s.value = "";
    return kanalCalis(id, () => rpc("tv_kanal_ayar", { p_kanal: id, p_slogan: sv || null, p_izleyici_ucret: uv ? Number(uv) : null }), "Kaydedildi.");
  };
  window.tvReklamKarar = (rid, onay, kanal) => kanalCalis(kanal, () => rpc("tv_reklam_karar", { p_reklam: rid, p_onay: onay }), onay ? "Reklam onaylandı." : "Reklam reddedildi, bütçe iade edildi.");
  window.tvSunucuTeklif = id => {
    const k = $("#tvSunKad"), u = $("#tvSunUcret"), kad = (k.value || "").trim(), uc = Math.round(Number(u.value) || 0);
    if (!kad || uc < 500) return toast("Kullanıcı adı ve en az 500 ₺ günlük ücret gir.", true);
    k.value = ""; u.value = "";
    return kanalCalis(id, () => rpc("tv_sunucu_teklif", { p_kanal: id, p_kad: kad, p_gunluk: uc }), "Teklif gönderildi.");
  };
  window.tvSunucuCikar = async (id, kad, aktif) => {
    if (aktif && !await onayla("Sözleşmeyi bitir", `${e(kad)} ile sunuculuk sözleşmesi sona erecek.`, "Bitir", true)) return;
    return kanalCalis(id, () => rpc("tv_sunucu_bitir", { p_kanal: id, p_kad: kad }), aktif ? "Sözleşme sona erdi." : "Teklif geri çekildi.");
  };
  window.tvSunucuAyril = async id => { if (!await onayla("Sunuculuktan ayrıl", "Bu kanaldaki sunuculuk sözleşmen sona erecek.", "Ayrıl", true)) return; return kanalCalis(id, () => rpc("tv_sunucu_bitir", { p_kanal: id, p_kad: null }), "Kanaldan ayrıldın."); };
  window.tvProgramAc = async id => {
    const baslik = ($("#tvBaslik").value || "").trim(), bas = $("#tvBas").value, sure = $("#tvSure").value, sun = $("#tvSun") ? $("#tvSun").value : "";
    if (baslik.length < 4) return toast("Program başlığı en az 4 karakter olmalı.", true);
    let basIso = null;
    if (bas) { const t = new Date(bas); if (isNaN(t.getTime())) return toast("Başlangıç tarihi geçersiz.", true); basIso = t.toISOString(); }
    try {
      const tur = $("#tvTur").value, odul = $("#tvOdul") ? Math.round(Number($("#tvOdul").value) || 0) : 0;
      const r = await rpc("tv_program_ac", { p_kanal: id, p_tur: tur, p_baslik: baslik, p_aciklama: ($("#tvAcik").value || "").trim() || null,
        p_bas: basIso, p_dakika: sure ? Number(sure) : null, p_sunucu: sun || null });
      $("#tvBaslik").value = ""; $("#tvAcik").value = ""; $("#tvBas").value = ""; ozetSifirla();
      if (tur === "yarisma" && odul >= 1000) {
        try { await rpc("tv_odul_koy", { p_program: r.id, p_tutar: odul }); $("#tvOdul").value = ""; toast("Ödül havuzu: " + tl(odul)); }
        catch (err) { toast("Program açıldı ama ödül konamadı: " + hataCevir(err.message), true); }
      }
      toast(r.durum === "canli" ? "Yayın başladı." : "Program yayın akışına eklendi.");
      window.tvStudyoAc(r.id);
    } catch (err) { toast(hataCevir(err.message), true); }
  };

  /* ------------------------------------------------------------------ stüdyo (yayın) ekranı — 209 canlı TV */
  // konuğun köşe rengi ve yönü (düelloda karşılıklı)
  function koseler(d) {
    const m = {}; (d.konuk_liste || []).forEach((k, i) => { m[k.kad] = { renk: KOSE[i % KOSE.length], sag: i % 2 === 1 }; }); return m;
  }
  const ROL2 = Object.assign({}, ROL, { seyirci: "İzleyici", sistem: "Stüdyo" });
  function mesajHtml(m, ks) {
    if (m.rol === "reklam") return `<div class="tv-mesaj reklam"><span class="tv-rol">Reklam</span><p>${e(m.metin)}</p></div>`;
    if (m.rol === "sistem") return `<div class="tv-mesaj sistem"><p>${e(m.metin)}</p></div>`;
    if (m.rol === "seyirci") return `<div class="tv-mesaj seyirci"><div class="tvx-m-bas"><span class="tv-rol">Ekrandaki izleyici</span>${kisi(m.kisi)} <span class="kucuk">${saatYaz(m.zaman)}</span></div><p>${e(m.metin)}</p></div>`;
    const k = ks && m.kisi && ks[m.kisi.kad];
    const sinif = m.rol === "konuk" ? "konuk" + (k && k.sag ? " sag" : "") : "sunucu";
    return `<div class="tv-mesaj ${sinif}"${k && m.rol === "konuk" ? ` style="--k:${k.renk}"` : ""}><div class="tvx-m-bas"><span class="tv-rol">${ROL2[m.rol] || ""}</span>${kisi(m.kisi)} <span class="kucuk">${saatYaz(m.zaman)}</span></div><p>${e(m.metin)}</p></div>`;
  }
  const odaHtml = d => { const ks = koseler(d); return (d.mesajlar || []).map(m => mesajHtml(m, ks)).join("") || bos(d.durum === "planli" ? "Yayın henüz başlamadı. Saati gelince sunucu ve konuklar burada konuşur." : d.durum === "iptal" ? "Program iptal edildi." : "Henüz söz alınmadı."); };
  function sayacHtml(d) {
    const z = d.izleyiciler || {};
    return `${d.durum === "canli" ? `<b>${z.anlik || 0}</b> kişi izliyor · toplam ${z.toplam || 0} izleyici` : `${z.toplam || 0} izleyici`} · ${d.alkis} alkış · ${d.yuh} yuh`;
  }
  function izleyiciHtml(d) {
    const z = d.izleyiciler || {}, l = z.liste || [], sayi = d.durum === "canli" ? (z.anlik || 0) : (z.toplam || 0);
    return `<details ${window._tvIzlAcik ? "open" : ""} ontoggle="window._tvIzlAcik=this.open"><summary style="cursor:pointer"><b>${d.durum === "canli" ? "Şu an izleyenler" : "İzleyenler"} (${sayi})</b></summary>
      <p class="tv-izl">${l.map(e).join(" · ") || "Henüz izleyici yok."}${sayi > l.length ? ` · ve ${sayi - l.length} kişi daha` : ""}</p></details>`;
  }
  const konusmaci = d => d.rolum === "sunucu" || d.rolum === "konuk";
  function tepkiHtml(d) {
    const acik = !konusmaci(d) && (d.durum === "canli" || (d.durum === "bitti" && d.oy_penceresi));
    if (!acik) return "";
    return `<div class="tvx-tepki"><button class="btn ${d.tepkim === "alkis" ? "altin" : "ikinci"}" onclick="tvTepki(${d.id},'alkis')">Alkışla <i>${n(d.alkis)}</i></button><button class="btn ${d.tepkim === "yuh" ? "tehlike" : "ikinci"}" onclick="tvTepki(${d.id},'yuh')">Yuhala <i>${n(d.yuh)}</i></button></div>`;
  }
  function oyHtml(d) {
    const ks = koseler(d), kabul = (d.konuk_liste || []).filter(k => k.durum === "kabul");
    if (d.tur !== "duello" || !kabul.length) return "";
    const top = kabul.reduce((t, k) => t + (Number(k.oy) || 0), 0) || 1;
    const kose = (k, dugme) => { const r = (ks[k.kad] || {}).renk || KOSE[0], pay = Math.round(100 * (Number(k.oy) || 0) / top);
      return `<${dugme ? `button type="button" class="btn ${d.oyum === k.kad ? "altin" : "ikinci"}" onclick="tvOyla(${d.id},'${e(k.kad)}')"` : 'div class="btn ikinci"'} style="--k:${r}">${d.oyum === k.kad ? '<span class="tvx-sec">Oyun</span>' : ""}
        <b>${e(k.kad)}</b><small>${k.unvan ? e(k.unvan) : "Konuk"}</small><span class="tvx-pay">%${pay}</span><small>${n(k.oy)} oy</small><span class="tvx-bar"><i style="width:${pay}%"></i></span></${dugme ? "button" : "div"}>`; };
    if (d.oy_acik && !konusmaci(d)) return `<section class="tvx-oyb"><h2>En ikna edici kim?</h2><p>Oylama, düello bittikten 15 dakika sonra kapanır. Oyunu değiştirebilirsin.</p>
      <div class="tvx-kose" style="--n:${Math.min(3, kabul.length)}">${kabul.map(k => kose(k, true)).join("")}</div></section>`;
    return `<section class="tvx-oyb"><h2>İzleyici oylaması</h2><p>${d.oy_acik ? "Oylama sürüyor; sunucu ve konuklar oy kullanamaz." : d.durum === "bitti" ? "Oylama kapandı." : "Oylama yayın başlayınca açılır."}</p>
      <div class="tvx-kose" style="--n:${Math.min(3, kabul.length)}">${kabul.slice().sort((a, b) => b.oy - a.oy).map(k => kose(k, false)).join("")}</div></section>`;
  }
  const konukImza = d => (d.konuk_liste || []).map(k => k.kad + ":" + k.durum).join(",");
  const imza = d => [d.durum, d.rolum, konukImza(d), (d.reklamlarim || []).map(r => r.id + ":" + r.durum).join(","), (d.reklamlar || []).length, d.oy_acik ? 1 : 0].join("|");
  const hazirla = d => { d.oy_penceresi = d.durum === "bitti" && simdi() < new Date(d.bit).getTime() + 15 * 60e3; return d; };
  const baslik2 = s => String(s || "").trim().split(/\s+/).slice(0, 2).map(w => w[0] || "").join("").toLocaleUpperCase("tr-TR") || "?";

  /* ---- canlı katman durumu (tv_canli) ---- */
  let S = null;
  const enBuyuk = (l, v) => l.reduce((m, x) => Math.max(m, Number(x.id) || 0), v || 0);
  function durumKur(id, d, c, onceki) {
    const k = onceki && onceki.id === id ? onceki : null;
    S = { id, d, c: c || null, eski: k ? k.eski : c === false, sonMesaj: enBuyuk(d.mesajlar || []), yorumlar: k ? k.yorumlar : [], sonYorum: k ? k.sonYorum : 0,
      emojiOnce: k ? k.emojiOnce : null, gonderilen: k ? k.gonderilen : {}, emojiSon: k ? k.emojiSon : 0, anahtar: {}, kayan: "" };
    if (c) yerlestir(c, true);
  }
  // tv_canli yanıtını yerel duruma işler (yeni mesajlar, yorumlar, sayaçlar, tepki yağmuru)
  function yerlestir(c, ilk) {
    const d = S.d; S.c = c;
    (c.mesajlar || []).forEach(m => { if (Number(m.id) > S.sonMesaj) { d.mesajlar = (d.mesajlar || []).concat([m]); S.sonMesaj = Number(m.id); } });
    if ((d.mesajlar || []).length > 400) d.mesajlar = d.mesajlar.slice(-400);
    (c.yorumlar || []).forEach(y => { if (Number(y.id) > S.sonYorum) { S.yorumlar.push(y); S.sonYorum = Number(y.id); } });
    if (S.yorumlar.length > 150) S.yorumlar = S.yorumlar.slice(-150);
    const z = d.izleyiciler || (d.izleyiciler = {});
    if (c.izleyici) { z.anlik = c.izleyici.anlik; z.toplam = c.izleyici.toplam; }
    ["alkis", "yuh"].forEach(x => { if (c[x] != null) d[x] = c[x]; });
    if ("tepkim" in c) d.tepkim = c.tepkim;
    if ("oyum" in c) d.oyum = c.oyum;
    (c.konuk_oy || []).forEach(o => { const k = (d.konuk_liste || []).find(x => x.kad === o.kad); if (k) k.oy = o.oy; });
    const top = c.emoji || {};
    if (S.emojiOnce && !ilk) EMOJI.forEach(([t]) => {
      const fark = (Number(top[t]) || 0) - (Number(S.emojiOnce[t]) || 0); if (fark <= 0) return;
      const ben = Math.min(fark, S.gonderilen[t] || 0); S.gonderilen[t] = (S.gonderilen[t] || 0) - ben;
      if (fark - ben > 0) ucur(t, fark - ben, false);
    });
    S.emojiOnce = Object.assign({}, top);
  }
  function ucur(tur, adet, ben) {
    const kat = document.getElementById("tvUcan"); if (!kat) return;
    const n2 = Math.min(ben ? 1 : 14, adet);
    for (let i = 0; i < n2; i++) setTimeout(() => {
      if (kat.childElementCount > 40) return;
      const u = document.createElement("span"); u.className = "tvx-u"; u.textContent = EMO[tur] || "👏";
      u.style.left = (ben ? 70 + Math.random() * 18 : 8 + Math.random() * 80) + "%";
      u.style.setProperty("--x", Math.round(Math.random() * 80 - 40) + "px"); u.style.setProperty("--s", (2.2 + Math.random()).toFixed(2) + "s");
      if (ben) u.style.fontSize = "32px";
      u.addEventListener("animationend", () => u.remove()); kat.appendChild(u);
    }, ben ? 0 : i * (2600 / n2) + Math.random() * 200);
  }
  const sonKonusma = d => { const l = d.mesajlar || []; for (let i = l.length - 1; i >= 0; i--) if (l[i].rol === "sunucu" || l[i].rol === "konuk" || l[i].rol === "seyirci") return l[i]; return null; };
  const kalanSn = ts => Math.max(0, Math.ceil((new Date(ts).getTime() - simdi()) / 1000));
  const oyVerebilir = (d, c, a) => a.tur === "yarisma" ? !konusmaci(d) && !(c && c.kanal_sahibi) && d.rolum !== "sahip" : d.rolum !== "sunucu";

  /* ---- ekran (sahne) ---- */
  function anketHtml(d, c, a) {
    const kap = a.kapandi || kalanSn(a.kapanis) <= 0, yar = a.tur === "yarisma", sec = a.secenekler || [], oy = a.oylar, top = Number(a.toplam) || 0;
    const yetki = oyVerebilir(d, c, a), kilit = yar && a.secimim != null;
    const pay = i => oy && top ? Math.round(100 * (Number(oy[i]) || 0) / top) : 0;
    const dugmeler = sec.map((x, i) => {
      const cls = ["tvx-opt"]; if (a.secimim === i) cls.push("secili");
      if (yar && kap && a.dogru != null) cls.push(i === a.dogru ? "dogru" : "yanlis");
      const kapali = kap || !yetki || kilit;
      const goster = oy && (!yar || kap || (c && c.yonetici));
      return `<button type="button" class="${cls.join(" ")}" style="--p:${goster ? pay(i) : 0}%"${kapali ? " disabled" : ` onclick="tvAnketOy(${a.id},${i})"`}><span class="tvx-hf">${String.fromCharCode(65 + i)}</span><span>${e(x)}</span>${goster ? `<span class="tvx-yz">%${pay(i)}</span>` : ""}</button>`;
    }).join("");
    let alt;
    if (!yetki) alt = yar ? (konusmaci(d) ? "Stüdyodakiler yarışamaz; izleyicilerin cevaplarını görüyorsun." : "Kanal sahibi yarışamaz.") : `${n(top)} oy`;
    else if (yar && kap) alt = a.secimim == null ? `Bu soruya cevap vermedin. Doğru cevap ${String.fromCharCode(65 + (a.dogru || 0))}.` : a.secimim === a.dogru ? `<b>Doğru!</b> +${n(a.puanim || 0)} puan` : `Yanlış. Doğru cevap <b>${String.fromCharCode(65 + (a.dogru || 0))}) ${e(sec[a.dogru] || "")}</b>.`;
    else if (kilit) alt = "Cevabın kilitlendi; süre bitince doğru cevap açıklanır.";
    else if (yar) alt = "Hızlı ol: doğru cevap 100 puan + hız bonusu. İlk dokunuşun kilitlenir.";
    else alt = kap ? `Anket kapandı · ${n(top)} oy` : `${n(top)} oy · oyunu süre bitene dek değiştirebilirsin`;
    const sure = Math.max(1, (new Date(a.kapanis).getTime() - new Date(a.acilis).getTime()) / 1000);
    return `<div class="tvx-q"><div class="tvx-q-ust"><span class="tvx-tur-et">${yar ? "Yarışma · Soru " + n(a.no) : "Canlı anket"}</span><span class="tvx-sn" data-tv-sn="${e(a.kapanis)}">${kap ? (yar ? "Süre bitti" : "Kapandı") : kalanSn(a.kapanis) + " sn"}</span></div>
      <h2>${e(a.soru)}</h2><div class="tvx-geri"><i data-tv-bar="${e(a.kapanis)}" data-tv-sure="${sure}" style="width:${kap ? 0 : Math.round(100 * kalanSn(a.kapanis) / sure)}%"></i></div>
      <div class="tvx-opts">${dugmeler}</div><div class="tvx-q-alt">${alt}</div></div>`;
  }
  function sahneHtml(d, c) {
    const canli = d.durum === "canli", planli = d.durum === "planli";
    if (canli && c && c.reklam_arasi) {
      const r = c.reklam_arasi.reklamlar || [];
      return `<div class="tvx-rek"><span class="tvx-rek-et">REKLAM ARASI · <span data-tv-sn="${e(c.reklam_arasi.bitis)}">${kalanSn(c.reklam_arasi.bitis)} sn</span></span>
        <div class="tvx-rek-k" style="--t:${Math.max(1, r.length) * 6}s;--d:6s">${r.map((x, i) => `<div style="--i:${i}"><b>${e(x.marka)}</b><span>${e(x.metin)}</span></div>`).join("") || "<div><b>Birazdan</b><span>Yayın kaldığı yerden sürecek.</span></div>"}</div></div>`;
    }
    const a = c && c.anket;
    if (canli && a && (!a.kapandi || kalanSn(a.kapanis) > -90)) return anketHtml(d, c, a);
    if (planli) return `<div class="tvx-tur-et">${e(d.tur_ad)} · ${tarihSaat(d.bas)}</div><h2>${e(d.baslik)}</h2>${d.aciklama ? `<p>${e(d.aciklama)}</p>` : ""}
      <p style="margin-top:12px">Başlamasına <span class="tvx-sayac" style="display:block;margin-top:4px" data-tv-geri="${e(d.bas)}">${kalan(new Date(d.bas).getTime() - simdi())}</span></p>
      ${c && !konusmaci(d) ? `<div class="tv-iki" style="margin-top:12px"><button class="btn ${c.hatirlat ? "ikinci" : "altin"}" onclick="tvHatirlat(${d.id},${!c.hatirlat})">${c.hatirlat ? "Hatırlatma kurulu · kaldır" : "Hatırlat · başlayınca haber ver"}</button></div>` : ""}`;
    if (!canli) {
      const z = d.izleyiciler || {}, y = c && c.yarisma, kaz = y && (y.kazananlar || [])[0];
      const duel = d.tur === "duello" ? (d.konuk_liste || []).filter(k => k.durum === "kabul").sort((p, q) => (q.oy || 0) - (p.oy || 0))[0] : null;
      const emo = c && c.emoji ? EMOJI.map(([t, i]) => [i, Number(c.emoji[t]) || 0]).sort((p, q) => q[1] - p[1])[0] : null;
      return `<div class="tvx-tur-et">${d.durum === "iptal" ? "İptal edildi" : "Yayın sona erdi"}</div><h2>${e(d.baslik)}</h2>
        ${kaz ? `<p>Yarışmanın birincisi <b style="color:#FFD27A">${e(kaz.kad)}</b> · ${n(kaz.puan)} puan${Number(kaz.tutar) > 0 ? " · " + tl(kaz.tutar) : ""}</p>` : duel && duel.oy ? `<p>İzleyici oylamasında önde: <b style="color:#FFD27A">${e(duel.kad)}</b> (${n(duel.oy)} oy)</p>` : ""}
        ${d.durum === "bitti" ? `<div class="tvx-bitti"><div><b>${n(z.toplam || 0)}</b><small>izleyici</small></div><div><b>${n(c && c.izleyici ? c.izleyici.zirve : d.zirve || 0)}</b><small>zirve</small></div><div><b>${emo && emo[1] ? emo[0] + " " + n(emo[1]) : n(d.alkis)}</b><small>${emo && emo[1] ? "en çok tepki" : "alkış"}</small></div></div>` : ""}`;
    }
    const sk = c && c.ekranda && simdi() - new Date(c.ekranda.zaman).getTime() < 75e3 ? c.ekranda : null;
    if (sk) return `<div class="tvx-soz" style="--k:#F2B33D"><span class="tvx-izs">${sk.soru ? "İzleyici sorusu" : "İzleyici yorumu"}</span><q>${e(sk.metin)}</q>
      <div class="tvx-kim"><i>${e(baslik2(sk.kad))}</i><span><b>${e(sk.kad)}</b> · seyirci kürsüsünden</span></div></div>`;
    const m = sonKonusma(d);
    if (m && m.kisi) {
      const ks = koseler(d), r = m.rol === "konuk" ? ((ks[m.kisi.kad] || {}).renk || KOSE[0]) : m.rol === "seyirci" ? "#F2B33D" : "hsl(" + ton(d.kanal) + " 70% 52%)";
      return `<div class="tvx-soz" style="--k:${r}"><div class="tvx-tur-et">${e(d.tur_ad)}</div><q>${e(m.metin)}</q>
        <div class="tvx-kim"><i>${e(baslik2(m.kisi.kad))}</i><span><b>${e(m.kisi.kad)}</b>${m.kisi.unvan ? " · " + e(m.kisi.unvan) : ""} · ${m.rol === "sunucu" ? "sunucu" : m.rol === "seyirci" ? "izleyici" : "konuk"}</span></div></div>`;
    }
    return `<div class="tvx-tur-et">${e(d.tur_ad)}</div><h2>${e(d.baslik)}</h2><p>${d.aciklama ? e(d.aciklama) : "Yayın başladı; ilk söz sunucuda."}</p>`;
  }
  function altBantHtml(d) {
    const m = d.durum === "canli" ? sonKonusma(d) : null;
    const et = d.durum === "canli" ? "Canlı" : d.durum === "planli" ? "Yakında" : "Arşiv";
    const metin = m && m.kisi ? `${m.kisi.kad}${m.kisi.unvan ? " · " + m.kisi.unvan : ""} — ${d.baslik}` : `${d.baslik} · sunucu ${(d.sunucu_kisi || {}).kad || d.sunucu || ""}`;
    return `<span class="tvx-ab-k">${et}</span><span class="tvx-ab-m">${e(metin)}</span>`;
  }
  function kayanHtml(d) {
    const l = (S && S.yorumlar || []).slice(-14);
    const metin = l.length ? l.map(y => `<b>${e(y.kad)}</b> ${y.soru ? "soruyor: " : ""}${e(y.metin)}`).join("&nbsp;&nbsp;&nbsp;•&nbsp;&nbsp;&nbsp;")
      : d.durum === "canli" ? `Seyirci kürsüsü açık: yorumunu yaz, sorunu sor, söz iste&nbsp;&nbsp;&nbsp;•&nbsp;&nbsp;&nbsp;${e(d.kanal)} · ${e(d.baslik)}`
      : `${e(d.kanal)} · ${e(d.baslik)} · ${e(progZaman(d))}`;
    const uz = metin.replace(/<[^>]+>|&nbsp;/g, " ").length;
    return { k: metin, h: `<span style="--sure:${Math.max(14, Math.round(uz * 0.2))}s">${metin}</span>` };
  }
  function reytingChip(d, c) {
    if (!c) return "";
    if (d.durum === "canli") return `<span class="tvx-chip" title="Reyting: aktif oyunculara oran · Pay: şu an çevrimiçi olanlara oran">Rtg %${String(c.reyting).replace(".", ",")} · Pay %${n(c.pay || 0)}</span>`;
    return c.izleyici && c.izleyici.zirve ? `<span class="tvx-chip">Zirve ${n(c.izleyici.zirve)}</span>` : "";
  }
  /* ---- emoji, ısı, yarışma, seyirci, reji ---- */
  function isiHtml(c, d) {
    const isi = Number(c && c.isi) || 0, anlik = Math.max(1, Number((d.izleyiciler || {}).anlik) || 1);
    const p = Math.min(100, Math.round(100 * isi / Math.max(6, anlik * 3)));
    const ad = p >= 80 ? "Yangın yeri" : p >= 50 ? "Coşkulu" : p >= 20 ? "Hareketli" : "Sakin";
    return `<div class="tvx-isi"><span>Salon ısısı</span><span class="tvx-isi-c" style="--p:${Math.max(isi ? 4 : 0, p)}%"><i></i></span><b>${ad}</b></div>`;
  }
  function emojiHtml(d, c) {
    if (d.durum !== "canli" || !c) return "";
    const say = c.emoji || {};
    const dugme = !konusmaci(d) ? `<div class="tvx-emo-d" data-v5-yok>${EMOJI.map(([t, i, ad]) => `<button type="button" aria-label="${ad}" data-emo="${t}" onclick="tvEmoji('${t}',this)">${i}<small>${n(say[t] || 0)}</small></button>`).join("")}</div>` : "";
    return `<section class="tvx-emo">${dugme}<div id="tvIsi">${isiHtml(c, d)}</div></section>`;
  }
  function yarismaHtml(d, c) {
    const y = c && c.yarisma; if (!y) return "";
    const tablo = y.tablo || [], kaz = y.kazananlar || [], bitti = d.durum === "bitti" || d.durum === "iptal";
    const satir = (x, i, sag) => `<div class="tvx-sira${x.ben || x.kad === benimKad() ? " ben" : ""}"><span class="tvx-mad m${i + 1}">${i + 1}</span><b>${e(x.kad)}</b><span>${sag}</span></div>`;
    return `<section class="tvx-yar"><div class="tvx-havuz"><div style="flex:1;min-width:0"><b>${tl(y.odul)}</b><small>ödül havuzu · ilk üç: %50 · %30 · %20</small></div>
        <div style="text-align:right"><b style="font-size:22px;color:#fff">${n(y.puanim)}</b><small>senin puanın</small></div></div>
      <section class="kart" style="margin-top:8px">${bitti && kaz.length ? `<h2 style="font-size:16px;margin:0 0 4px">Kazananlar</h2>${kaz.map((x, i) => satir(x, i, `${n(x.puan)} puan${Number(x.tutar) > 0 ? " · " + tl(x.tutar) : ""}`)).join("")}`
        : `<h2 style="font-size:16px;margin:0 0 4px">Yarışma tablosu <span class="kucuk">${n(y.soru_sayisi)} soru</span></h2>${tablo.map((x, i) => satir(x, i, n(x.puan) + " puan")).join("") || bos(d.durum === "canli" ? "İlk soru gelince tablo dolacak." : "Yarışma yayın başlayınca başlar.")}`}</section></section>`;
  }
  const yorumSatir = (y, yon) => `<div class="tvx-y${y.ekranda ? " ekranda" : ""}"><span class="tvx-y-a" style="--h:${ton(y.kad)}">${e(baslik2(y.kad))}</span><span class="tvx-y-g">
      <b>${e(y.kad)}</b><small>${saatYaz(y.zaman)}</small>${y.soru ? '<span class="tvx-y-et">Soru</span>' : ""}${y.ekranda ? '<span class="tvx-y-et e">Ekranda</span>' : ""}<p>${e(y.metin)}</p>
      ${(yon && !y.ekranda) || y.benim ? `<span class="tvx-y-b">${yon && !y.ekranda ? `<button type="button" class="tvx-mini" onclick="tvYorumEkrana(${y.id})">Ekrana al</button>` : ""}${yon || y.benim ? `<button type="button" class="tvx-mini kirmizi" onclick="tvYorumGizle(${y.id})">Kaldır</button>` : ""}</span>` : ""}</span></div>`;
  function sorularHtml(c) {
    const l = (c && c.sorular) || [], yon = c && c.yonetici;
    if (!l.length) return "";
    return (KX() ? KX().bas("Öne çıkan sorular", "en çok desteklenen üstte") : "") + l.map(q => `<div class="tvx-soru"><p>${e(q.metin)}</p><small>${e(q.kad)} soruyor</small>
      <div class="tvx-y-b" style="display:flex;gap:6px;flex-wrap:wrap;margin-top:8px">${!q.benim && !yon ? `<button type="button" class="tvx-mini${q.destekledim ? " on" : ""}" ${q.destekledim ? "disabled" : `onclick="tvSoruDestek(${q.id})"`}>${q.destekledim ? "Destekledin" : "Ben de soruyorum"} · ${n(q.destek)}</button>` : `<span class="tvx-mini">${n(q.destek)} destek</span>`}
        ${yon ? `<button type="button" class="tvx-mini on" onclick="tvYorumEkrana(${q.id})">Ekrana al</button><button type="button" class="tvx-mini kirmizi" onclick="tvYorumGizle(${q.id})">Kaldır</button>` : ""}</div></div>`).join("");
  }
  function seyirciHtml(d, c) {
    const canli = d.durum === "canli";
    if (S && S.eski) return bos("Seyirci kürsüsü sunucu güncellemesinden sonra açılır.");
    const form = canli && !konusmaci(d) ? `<div class="tvx-yazk"><textarea id="tvYorum" maxlength="200" rows="2" placeholder="${d.tur === "acik_oturum" ? "Sorunu yaz; en çok desteklenenler ekrana çıkar…" : "Yorumunu yaz, kayan yazıda görünsün…"}" aria-label="Seyirci yorumu"></textarea>
        <label class="tvx-onay"><input type="checkbox" id="tvYorumSoru"${d.tur === "acik_oturum" ? " checked" : ""}> Soru olarak sor (sunucu ekrana alabilir, diğer izleyiciler destekler)</label>
        <div class="tv-iki"><button class="btn altin" id="tvYorumB" onclick="tvYorumYaz(${d.id})">Gönder</button>${c && !c.yonetici ? `<button class="btn ${c.soz && c.soz.istedim ? "ikinci" : "ikinci"}" id="tvSozB" onclick="tvSozIste(${d.id},${!(c.soz && c.soz.istedim)})">${c.soz && c.soz.istedim ? "Söz isteğini geri çek" : "Söz iste · canlı bağlan"}</button>` : ""}</div>
        ${c && c.soz && c.soz.istedim ? `<p class="kucuk" style="color:#FFD27A">Söz istedin; sunucu seni yayına alırsa stüdyoda konuşabilirsin.</p>` : ""}</div>` : "";
    const l = (S && S.yorumlar) || [];
    return `${form}<div id="tvSorular">${sorularHtml(c)}</div>${KX() ? KX().bas("Seyirci kürsüsü", n((c && c.yorum_sayi) || l.length) + " yorum") : ""}
      <div class="tvx-sey-akis" id="tvYorumAkis" data-n="${l.length}">${l.map(y => yorumSatir(y, c && c.yonetici)).join("") || bos(canli ? "Henüz yorum yok; ilk yorumu sen yaz." : "Bu yayında seyirci yorumu yok.")}</div>`;
  }
  function rejiCanliHtml(d, c) {
    if (!c || d.durum !== "canli") return "";
    const stud = (d.konuk_liste || []).filter(k => k.durum === "kabul"), kuy = (c.soz && c.soz.kuyruk) || [], sor = c.sorular || [];
    return `<h3>Stüdyodakiler (${stud.length}/6)</h3>${stud.map(k => `<div class="tvx-kisi-s"><span>${kisi(k)}</span><button type="button" class="tvx-mini kirmizi" onclick="tvKonukCikar(${d.id},'${e(k.kad)}')">Yayından al</button></div>`).join("") || '<p class="kucuk">Henüz konuk yok.</p>'}
      <h3>Canlı bağlantı için söz isteyenler (${kuy.length})</h3>${kuy.map(k => `<div class="tvx-kisi-s"><span>${kisi(k)} <span class="kucuk">${saatYaz(k.zaman)}</span></span><button type="button" class="tvx-mini on" onclick="tvSozVer(${d.id},'${e(k.kad)}')">Yayına al</button></div>`).join("") || '<p class="kucuk">İzleyiciler Seyirci sekmesinden söz isteyebilir.</p>'}
      ${sor.length ? `<h3>Öne çıkan seyirci soruları</h3>${sor.slice(0, 3).map(q => `<div class="tvx-kisi-s"><span>"${e(q.metin)}" <span class="kucuk">${e(q.kad)} · ${n(q.destek)} destek</span></span><button type="button" class="tvx-mini on" onclick="tvYorumEkrana(${q.id})">Ekrana al</button></div>`).join("")}` : ""}
      <h3>Reklam arası</h3><button class="btn ${c.reklam_arasi_hazir ? "altin" : "ikinci"}" ${c.reklam_arasi_hazir ? "" : "disabled"} onclick="tvReklamArasi(${d.id})">${c.reklam_arasi ? "Reklam arasındayız…" : c.reklam_arasi_hazir ? "Reklam arası ver (40 sn)" : (d.reklamlar || []).length ? "Reklam arası 8 dakikada bir" : "Onaylı reklam yok"}</button>
      ${c.anket && !c.anket.kapandi && kalanSn(c.anket.kapanis) > 0 ? `<button class="btn ikinci" style="margin-top:8px" onclick="tvAnketKapat(${c.anket.id})">Açık soruyu şimdi kapat</button>` : ""}`;
  }
  function rejiHtml(d, c) {
    const canli = d.durum === "canli", planli = d.durum === "planli", yar = d.tur === "yarisma";
    const secAlan = i => `<label class="tvx-dogru">${yar ? `<input type="radio" name="tvADogru" value="${i}"${i === 0 ? " checked" : ""} aria-label="Doğru cevap ${String.fromCharCode(65 + i)}">` : ""}<input type="text" id="tvASec${i}" maxlength="60" placeholder="${String.fromCharCode(65 + i)} seçeneği${i > 1 ? " (isteğe bağlı)" : ""}"></label>`;
    const sureler = yar ? [[15, "15 sn"], [20, "20 sn"], [30, "30 sn"], [45, "45 sn"], [60, "60 sn"]] : [[30, "30 sn"], [60, "1 dk"], [120, "2 dk"], [300, "5 dk"]];
    const anket = canli && !(S && S.eski) ? `<h3>${yar ? "Yarışma sorusu sor" : "Canlı anket aç"}</h3>
        <div class="tvx-hazir">${yar ? `<button type="button" class="tvx-mini on" onclick="tvSoruBankasi()">Soru bankasından getir</button>` : ""}${ANKET_HAZIR.map((x, i) => `<button type="button" class="tvx-mini" onclick="tvAnketHazir(${i})">${e(x[0])}</button>`).join("")}</div>
        <div class="alan" style="margin-top:8px"><label for="tvASoru">Soru</label><input id="tvASoru" maxlength="160" placeholder="${yar ? "Örn. TBMM kaç milletvekilinden oluşur?" : "Örn. Asgari ücrete zam yapılmalı mı?"}"></div>
        <div class="tvx-r-sec">${[0, 1, 2, 3].map(secAlan).join("")}</div>
        ${yar ? '<p class="kucuk" style="margin-top:6px">Doğru cevabın yanındaki yuvarlağı işaretle; izleyiciler göremez.</p>' : ""}
        <div class="alan" style="margin-top:8px"><label for="tvASure">Süre</label><select id="tvASure">${sureler.map((x, i) => `<option value="${x[0]}"${i === (yar ? 2 : 1) ? " selected" : ""}>${x[1]}</option>`).join("")}</select></div>
        <button class="btn altin" onclick="tvAnketAc(${d.id})">${yar ? "Soruyu yayına gönder" : "Anketi yayına gönder"}</button>` : canli ? "" : `<p class="kucuk" style="margin-top:12px">Anket, yarışma soruları, canlı bağlantı ve reklam arası yayın başlayınca burada açılır.</p>`;
    const odul = yar && d.kanal_sahibi && (canli || planli) && !(S && S.eski) ? `<h3>Ödül havuzu</h3><div class="alan"><label for="tvOdulEk">Kanal kasasından ekle (₺; havuz en çok 100.000 ₺)</label><input id="tvOdulEk" type="number" inputmode="numeric" min="1000" max="100000" step="1000"></div>
        <button class="btn ikinci" onclick="tvOdulKoy(${d.id})">Havuza ekle</button>` : "";
    return `<section class="kart tvx-reji" id="tvReji"><h2>Reji masası <small>yalnız sen görürsün</small></h2>
      <h3 style="margin-top:6px">Yayın yönetimi</h3>
      <div class="alan"><label for="tvKonukKad">Konuk çağır (kullanıcı adı, en çok 6 konuk)</label><input id="tvKonukKad" autocapitalize="off" maxlength="40"></div>
      <div class="tv-iki"><button class="btn ikinci" onclick="tvKonukDavet(${d.id})">Davet gönder</button>
        <button class="btn tehlike" onclick="tvBitir(${d.id},${planli})">${planli ? "Programı iptal et" : "Yayını bitir"}</button></div>
      <div id="tvRejiCanli">${rejiCanliHtml(d, c)}</div>${anket}${odul}</section>`;
  }

  /* ---- kısmi çizim (yalnız değişen parçalar; yazılan alanlara dokunmaz) ---- */
  function koy(id, html, anahtar) {
    const el = document.getElementById(id); if (!el) return;
    if (anahtar != null) { if (S.anahtar[id] === anahtar) return; S.anahtar[id] = anahtar; el.innerHTML = html; return; }
    if (el.innerHTML !== html) el.innerHTML = html;
  }
  function sahneAnahtar(d, c) {
    const a = c && c.anket, m = sonKonusma(d);
    return [d.durum, c && c.reklam_arasi ? "r" + c.reklam_arasi.bitis : "", a ? [a.id, a.kapandi, a.toplam, JSON.stringify(a.oylar), a.secimim, a.dogru, a.puanim].join(":") : "",
      c && c.ekranda ? "e" + c.ekranda.id : "", m ? m.id : "", c ? c.hatirlat : "", (d.izleyiciler || {}).toplam].join("|");
  }
  function parcaCiz() {
    if (!S || !document.getElementById("tvStudyo")) return;
    const d = S.d, c = S.c;
    const oda = document.getElementById("tvOda");
    if (oda && Number(oda.dataset.n) !== (d.mesajlar || []).length) {
      const dipte = oda.scrollHeight - oda.scrollTop - oda.clientHeight < 60;
      oda.innerHTML = odaHtml(d); oda.dataset.n = (d.mesajlar || []).length;
      if (dipte) oda.scrollTop = oda.scrollHeight;
    }
    koy("tvSayac", sayacHtml(d)); koy("tvIzl", izleyiciHtml(d)); koy("tvTepkiK", tepkiHtml(d)); koy("tvOyK", oyHtml(d));
    koy("tvSahne", sahneHtml(d, c), sahneAnahtar(d, c));
    koy("tvAltBant", altBantHtml(d));
    const ky = kayanHtml(d); if (S.kayan !== ky.k) { S.kayan = ky.k; koy("tvKayanI", ky.h); }
    koy("tvReyt", reytingChip(d, c));
    if (c) {
      const isi = document.getElementById("tvIsi"); if (isi) { const h = isiHtml(c, d); if (isi.innerHTML !== h) isi.innerHTML = h; }
      document.querySelectorAll("#tvStudyo [data-emo]").forEach(b => { const s = b.querySelector("small"), v = n((c.emoji || {})[b.dataset.emo] || 0); if (s && s.textContent !== v && !b.classList.contains("pat")) s.textContent = v; });
      koy("tvYarismaK", yarismaHtml(d, c));
      koy("tvSorular", sorularHtml(c));
      koy("tvRejiCanli", rejiCanliHtml(d, c));
      const ak = document.getElementById("tvYorumAkis");
      if (ak && Number(ak.dataset.n) !== S.yorumlar.length) {
        const dipte = ak.scrollHeight - ak.scrollTop - ak.clientHeight < 60;
        ak.innerHTML = S.yorumlar.map(y => yorumSatir(y, c.yonetici)).join("") || bos("Henüz yorum yok; ilk yorumu sen yaz."); ak.dataset.n = S.yorumlar.length;
        if (dipte) ak.scrollTop = ak.scrollHeight;
      }
      const rz = document.querySelector('[data-kx="tvs' + d.id + '"] button[data-k="seyirci"] i'); if (rz) rz.textContent = n(c.yorum_sayi || S.yorumlar.length);
      const iz = document.querySelector('[data-kx="tvs' + d.id + '"] button[data-k="izleyen"] i'); if (iz) iz.textContent = n((d.izleyiciler || {}).anlik || 0);
    }
  }
  // saniyelik sayaçlar: soru süresi, reklam arası, yayına kalan; süre dolunca bir kez tazeler
  function saniyeKur(id) {
    clearInterval(window._tvSaniye);
    window._tvSaniye = setInterval(() => {
      if (!document.getElementById("tvStudyo") || window._tvStudyoId !== id) { clearInterval(window._tvSaniye); return; }
      let bitti = false;
      document.querySelectorAll("#tvStudyo [data-tv-sn]").forEach(el => { const k = kalanSn(el.dataset.tvSn); if (k <= 0 && !el.dataset.biter) { el.dataset.biter = "1"; bitti = true; } el.textContent = k > 0 ? k + " sn" : "Süre bitti"; });
      document.querySelectorAll("#tvStudyo [data-tv-bar]").forEach(el => { el.style.width = Math.round(100 * kalanSn(el.dataset.tvBar) / Math.max(1, Number(el.dataset.tvSure) || 1)) + "%"; });
      document.querySelectorAll("#tvStudyo [data-tv-geri]").forEach(el => { const ms = new Date(el.dataset.tvGeri).getTime() - simdi(); el.textContent = kalan(ms); if (ms <= 0 && !el.dataset.biter) { el.dataset.biter = "1"; bitti = true; } });
      if (bitti && window._tvTaz) setTimeout(() => window._tvTaz(), 1300);
    }, 1000);
  }

  window.tvStudyoEkrani = async function (id, hazir, hazirC) {
    stil();
    if (window._tvStudyoId !== id || !document.getElementById("tvStudyo")) yukleniyor("TV yayını");
    let d = hazir, c = hazirC;
    const eskiSunucu = S && S.id === id && S.eski;
    if (!d) {
      try {
        [d, c] = await Promise.all([rpc("tv_detay", { p_program: id }),
          eskiSunucu ? Promise.resolve(false) : rpc("tv_canli", { p_program: id, p_mesaj: 0, p_yorum: 0 }).catch(err => /tv_canli/.test(String(err && err.message)) ? false : null)]);
      } catch (err) { return hataEkran("TV yayını", err); }
    }
    hazirla(d);
    window._tvStudyoId = id;
    durumKur(id, d, c === undefined ? (S && S.id === id ? S.c : null) : c, S);
    c = S.c;
    const canli = d.durum === "canli", planli = d.durum === "planli", acik = canli || planli;
    const yetkili = d.rolum === "sunucu" || d.kanal_sahibi;
    const reklamlar = d.reklamlar || [], benimRek = d.reklamlarim || [];
    const aktifRek = benimRek.some(r => r.durum === "bekliyor" || r.durum === "onay");
    const REK_DURUM = { bekliyor: "Onay bekliyor", onay: "Onaylandı", ret: "Reddedildi, bütçe iade edildi", iptal: "İptal edildi, bütçe iade edildi", yayinlandi: "Yayınlandı", iade: "Bütçe iade edildi" };
    const rolYazi = { sunucu: "Bu yayının sunucususun", konuk: "Bu yayında konuksun", davetli: "Bu programa davetlisin", sahip: "Kanalın sensin" }[d.rolum] || "";
    const diger = (c && c.diger || []).map(x => Number(x.id)), sira = diger.indexOf(id);
    const kumanda = canli && diger.length > 1 && sira >= 0;
    const once = kumanda ? diger[(sira - 1 + diger.length) % diger.length] : null, sonra = kumanda ? diger[(sira + 1) % diger.length] : null;
    const SEK = [["studyo", "Stüdyo"], ["seyirci", "Seyirci kürsüsü", c ? n(c.yorum_sayi || 0) : ""]];
    const akt = KX() ? KX().secili("tvs" + id, SEK, "studyo") : "studyo";
    const pano = (k, h) => KX() ? KX().pano("tvs" + id, k, akt, h) : h;
    const ky = kayanHtml(d); S.kayan = ky.k;
    iskelet(d.kanal || "TV yayını", `<div id="tvStudyo" class="tvx" data-imza="${e(imza(d))}">
      <section class="tvx-tv${canli ? " canli" : ""}${kumanda ? " kumanda" : ""}" id="tvTv" style="--h:${ton(d.kanal)}">
        <div class="tvx-ucan" id="tvUcan" data-v5-yok aria-hidden="true"></div>
        <div class="tvx-tv-ust"><button type="button" class="tvx-bug" onclick="tvKanalAc(${d.kanal_id})">${logo(d.kanal, "k")}<b>${e(d.kanal)}</b></button>
          ${c && !d.kanal_sahibi ? `<button type="button" class="tvx-chip${c.takip ? " takip" : ""}" onclick="tvTakip(${d.kanal_id},${!c.takip})">${c.takip ? "Takipte" : "+ Takip"}</button>` : ""}
          ${canli ? '<span class="tv-canli" style="margin:0">Canlı</span>' : `<span class="tvx-chip">${planli ? "Planlı" : d.durum === "iptal" ? "İptal" : "Bitti"}</span>`}</div>
        <div class="tvx-sahne-k">${kumanda ? `<button type="button" class="tvx-kum sol" aria-label="Önceki canlı yayın" onclick="tvZap(${once})">‹</button><button type="button" class="tvx-kum sag" aria-label="Sonraki canlı yayın" onclick="tvZap(${sonra})">›</button>` : ""}
          <div class="tvx-sahne" id="tvSahne" aria-live="polite">${sahneHtml(d, c)}</div></div>
        <div class="tvx-altbant" id="tvAltBant">${altBantHtml(d)}</div>
        <div class="tvx-kayan"><span class="tvx-ky-et">${canli ? "SEYİRCİ" : "BİLGİ"}</span><span class="tvx-ky-i" id="tvKayanI">${ky.h}</span></div>
        <div class="tvx-tv-alt"><p class="kucuk" id="tvSayac">${sayacHtml(d)}</p><div class="tvx-tv-bil"><span id="tvReyt">${reytingChip(d, c)}</span><span>${e(d.tur_ad)}${rolYazi ? " · " + rolYazi : ""} · ${planli ? "Başlangıç " + tarihSaat(d.bas) + (d.acik_uclu ? " · sunucu bitirene kadar" : " · bitiş " + saatYaz(d.bit)) : progZaman(d)}</span></div></div>
        ${reklamlar.length ? `<div class="tv-sponsor" style="padding:0 12px 12px;margin:0">Bu yayının reklamverenleri: ${reklamlar.map(r => e(r.marka)).join(" · ")}</div>` : ""}</section>
      <div id="tvEmojiK">${emojiHtml(d, c)}</div>
      ${d.rolum === "davetli" && acik ? `<section class="tvx-gelen"><h2>Bu programa konuk olarak davetlisin.</h2><p>Katılırsan yayın sırasında söz alabilirsin; izleyiciler seni oylayabilir.</p>
        <div class="tv-iki"><button class="btn altin" onclick="tvKonukYanit(${d.id},true)">Katılıyorum</button><button class="btn ikinci" onclick="tvKonukYanit(${d.id},false)">Katılamam</button></div></section>` : ""}
      <div id="tvYarismaK">${yarismaHtml(d, c)}</div>
      <div id="tvOyK">${oyHtml(d)}</div>
      <div id="tvTepkiK">${tepkiHtml(d)}</div>
      ${KX() ? KX().sekmeler("tvs" + id, SEK, akt, "#E23A40") : ""}
      ${pano("studyo", `<section class="kart"><div class="tv-oda" id="tvOda" data-n="${(d.mesajlar || []).length}" aria-live="polite">${odaHtml(d)}</div>
        ${canli && konusmaci(d) ? `<div class="tvx-yaz" style="margin-top:10px"><textarea class="tv-yaz" id="tvYaz" maxlength="600" rows="2" placeholder="${d.rolum === "sunucu" ? "Yayını yönet, soru sor…" : "Söz al…"}" aria-label="Yayına yaz"></textarea>
          <button class="btn altin" id="tvYazB" onclick="tvYaz(${d.id})">Gönder</button></div>` : canli ? `<p class="kucuk" style="margin-top:10px">Stüdyoda sunucu ve konuklar konuşur. Sen <b>Seyirci</b> sekmesinden yorum yazabilir, soru sorabilir, söz isteyip canlı bağlanabilirsin.</p>` : ""}</section>`)}
      ${pano("seyirci", `<section class="kart" id="tvSeyirciK">${seyirciHtml(d, c)}</section>`)}
      <section class="kart" id="tvIzl">${izleyiciHtml(d)}</section>
      ${yetkili && acik ? rejiHtml(d, c) : ""}
      ${benimRek.length ? `<section class="kart"><h2>Reklamım</h2>${benimRek.map(r => `<div class="tv-satir"><b>${e(r.marka)}</b> <span class="kucuk">${e(r.sirket || "cüzdanımdan")} · bütçe ${tl(r.butce)} · ${REK_DURUM[r.durum] || r.durum}${r.durum === "yayinlandi" ? " · ödenen " + tl(r.odenen) + ", iade " + tl(r.iade) : ""}</span>
          ${r.durum === "bekliyor" || (r.durum === "onay" && planli) ? `<button class="btn ikinci" onclick="tvReklamIptal(${r.id},${d.id})">Reklamı iptal et, bütçeyi geri al</button>` : ""}</div>`).join("")}</section>` : ""}
      ${acik && !d.kanal_sahibi && !aktifRek ? `<section class="kart"><details id="tvRekD" ontoggle="if(this.open)tvReklamKaynak(${d.id})"><summary style="cursor:pointer"><b>Bu programa reklam ver</b> <span class="kucuk">izleyici başına ${tl(d.izleyici_ucret)}</span></summary>
        <p class="alt" style="margin-top:8px">Bütçe peşin ayrılır; program bitince izleyici sayısı kadarı kanala ödenir, kalanı sana iade edilir. Kanal sahibi onaylayınca reklamın yayında ve reklam aralarında görünür; onaylanmazsa bütçenin tamamı geri döner.</p>
        <div class="alan"><label for="tvRMarka">Marka ya da ad</label><input id="tvRMarka" maxlength="40"></div>
        <div class="alan"><label for="tvRMetin">Reklam metni</label><input id="tvRMetin" maxlength="200"></div>
        <div class="alan"><label for="tvRButce">Bütçe (₺, 5.000 – 5.000.000)</label><input id="tvRButce" type="number" inputmode="numeric" min="5000" max="5000000" step="1000" oninput="tvReklamOzet(${Number(d.izleyici_ucret)})"></div>
        <div class="alan"><label for="tvRKaynak">Ödeme kaynağı</label><select id="tvRKaynak"><option value="">Cüzdanım</option></select></div>
        <div class="tvx-ozet" id="tvROzet"></div>
        <button class="btn altin" style="margin-top:8px" onclick="tvReklamVer(${d.id})">Reklam talebi gönder</button></details></section>` : ""}
    </div>`, { geri: true });
    const kok = document.getElementById("tvStudyo");
    if (!kok || kok.dataset.imza !== imza(d)) return;      // çizim ertelendi (oyuncu meşgul); zamanlayıcı yeniden dener
    S.anahtar = { tvSahne: sahneAnahtar(d, c) };
    const oda = $("#tvOda"); if (oda) oda.scrollTop = oda.scrollHeight;
    const ak = $("#tvYorumAkis"); if (ak) ak.scrollTop = ak.scrollHeight;
    const enter = (sec, fn) => { const ta = $(sec); if (ta) ta.onkeydown = ev => { if (ev.key === "Enter" && !ev.shiftKey && window.matchMedia && matchMedia("(pointer:fine)").matches) { ev.preventDefault(); fn(id); } }; };
    enter("#tvYaz", window.tvYaz); enter("#tvYorum", window.tvYorumYaz);
    saniyeKur(id);
    if (acik || d.oy_penceresi || (c && c.yarisma && d.durum === "bitti" && !(c.yarisma.kazananlar || []).length)) {
      const eskiTaz = async () => {
        let y; try { y = hazirla(await rpc("tv_detay", { p_program: id })); } catch (_) { return; }
        if (window._tvStudyoId !== id || !document.getElementById("tvStudyo")) return;
        const k = document.getElementById("tvStudyo");
        if (imza(y) !== k.dataset.imza && !$("#modal") && (y.durum !== S.d.durum || !yaziyor("tvStudyo"))) {
          if (y.durum !== S.d.durum) eylem();
          return window.tvStudyoEkrani(id, y, false);
        }
        S.d = y; S.sonMesaj = enBuyuk(y.mesajlar || []); parcaCiz();
      };
      const taz = async () => {
        if (window._tvStudyoId !== id || !document.getElementById("tvStudyo") || document.hidden) return;
        if (S.eski) return eskiTaz();
        let y;
        try { y = await rpc("tv_canli", { p_program: id, p_mesaj: S.sonMesaj, p_yorum: S.sonYorum }); }
        catch (err) { if (/tv_canli/.test(String(err && err.message))) { S.eski = true; return eskiTaz(); } return; }
        if (window._tvStudyoId !== id || !document.getElementById("tvStudyo")) return;
        const dg = y.durum !== S.d.durum || y.rolum !== S.d.rolum || (y.konuk_imza || "") !== konukImza(S.d) || Number(y.reklam_n) !== (S.d.reklamlar || []).length || !!y.oy_acik !== !!S.d.oy_acik;
        if (dg && !$("#modal") && (y.durum !== S.d.durum || !yaziyor("tvStudyo"))) {
          let tam; try { tam = hazirla(await rpc("tv_detay", { p_program: id })); } catch (_) { return; }
          if (window._tvStudyoId !== id) return;
          if (y.durum !== S.d.durum) eylem();
          return window.tvStudyoEkrani(id, tam, Object.assign(y, { mesajlar: [] }));
        }
        yerlestir(y); parcaCiz();
      };
      window._tvTaz = taz;
      const basaKalan = planli ? new Date(d.bas).getTime() - simdi() : null;
      const kalabalik = Number((d.izleyiciler || {}).anlik) > 300;
      if (window.CANLI && CANLI.izle) CANLI.izle({ anahtarlar: ["yayin:tv" + id], tazele: taz, hizliMs: canli ? (kalabalik ? 7000 : 4000) : 15000, yedekMs: canli ? (kalabalik ? 9000 : 6000) : 20000,
        yayilim: canli ? 1200 : 1500, pencereMs: 1200, sonraMs: basaKalan != null && basaKalan > 0 ? basaKalan + 900 : null });
      else D.canli = setInterval(taz, 6000);
    }
  };
  const studyoCalis = async (id, fn, basari) => { try { const r = await fn(); ozetSifirla(); if (basari) toast(basari); await window.tvStudyoEkrani(id, r && r.rolum ? r : null); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  // hafif işlem: sunucu yanıtından sonra yalnız canlı katmanı tazeler
  const hafif = async (fn, basari) => { try { const r = await fn(); if (basari) toast(basari); if (window._tvTaz) await window._tvTaz(); return r; } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvZap = nid => { if (!nid) return; eylem(); window.tvStudyoEkrani(Number(nid)); };
  window.tvYaz = async id => {
    const ta = $("#tvYaz"), b = $("#tvYazB"); if (!ta) return;
    const v = (ta.value || "").trim(); if (!v) return;
    if (b) b.disabled = true;
    try { await rpc("tv_yaz", { p_program: id, p_metin: v }); ta.value = ""; if (window._tvTaz) await window._tvTaz(); const oda = $("#tvOda"); if (oda) oda.scrollTop = oda.scrollHeight; }
    catch (err) { toast(hataCevir(err.message), true); }
    const b2 = $("#tvYazB"); if (b2) b2.disabled = false;
    const t2 = $("#tvYaz"); if (t2) t2.focus();
  };
  window.tvTepki = async (id, tur) => { try { const y = hazirla(await rpc("tv_tepki", { p_program: id, p_tur: tur })); if (S && S.id === id) { S.d.alkis = y.alkis; S.d.yuh = y.yuh; S.d.tepkim = y.tepkim; S.d.izleyiciler = y.izleyiciler || S.d.izleyiciler; parcaCiz(); } } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvOyla = async (id, kad) => { try { const y = hazirla(await rpc("tv_oyla", { p_program: id, p_kad: kad })); if (S && S.id === id) { S.d.oyum = y.oyum; S.d.konuk_liste = y.konuk_liste || S.d.konuk_liste; parcaCiz(); } toast("Oyun kaydedildi."); } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvEmoji = (tur, btn) => {
    if (!S) return;
    ucur(tur, 1, true);
    if (btn) { btn.classList.remove("pat"); void btn.offsetWidth; btn.classList.add("pat"); setTimeout(() => btn.classList.remove("pat"), 400);
      const s = btn.querySelector("small"); if (s) s.textContent = n((Number(String(s.textContent).replace(/\D/g, "")) || 0) + 1); }
    const gonder = t => { S.emojiSon = Date.now(); rpc("tv_emoji", { p_program: S.id, p_tur: t }).then(r => { if (r && r.tamam) S.gonderilen[t] = (S.gonderilen[t] || 0) + 1; }).catch(() => {}); };
    const ara = Date.now() - (S.emojiSon || 0);
    S.emojiSira = tur;
    if (ara >= 2000) gonder(tur);
    else if (!S.emojiBekle) S.emojiBekle = setTimeout(() => { S.emojiBekle = null; gonder(S.emojiSira); }, 2000 - ara);
  };
  window.tvYorumYaz = async id => {
    const ta = $("#tvYorum"), b = $("#tvYorumB"); if (!ta) return;
    const v = (ta.value || "").trim(); if (v.length < 2) return toast("Yorum en az 2 karakter olmalı.", true);
    const soru = !!($("#tvYorumSoru") && $("#tvYorumSoru").checked);
    if (b) b.disabled = true;
    try { await rpc("tv_yorum_yaz", { p_program: id, p_metin: v, p_soru: soru }); ta.value = ""; toast(soru ? "Sorun gönderildi; izleyiciler destekledikçe öne çıkar." : "Yorumun kayan yazıda."); if (window._tvTaz) await window._tvTaz(); }
    catch (err) { toast(hataCevir(err.message), true); }
    setTimeout(() => { const b2 = $("#tvYorumB"); if (b2) b2.disabled = false; }, 1500);
  };
  window.tvSoruDestek = yid => hafif(() => rpc("tv_yorum_destek", { p_yorum: yid }), "Desteğin eklendi.");
  window.tvYorumEkrana = yid => hafif(() => rpc("tv_yorum_ekrana", { p_yorum: yid }), "Ekrana alındı.");
  window.tvYorumGizle = async yid => { if (!await onayla("Yorumu kaldır", "Bu yorum seyirci kürsüsünden ve kayan yazıdan kaldırılacak.", "Kaldır", true)) return;
    try { await rpc("tv_yorum_gizle", { p_yorum: yid }); if (S) { S.yorumlar = S.yorumlar.filter(y => y.id !== yid); S.kayan = ""; } toast("Kaldırıldı."); if (window._tvTaz) await window._tvTaz(); parcaCiz(); } catch (err) { toast(hataCevir(err.message), true); } };
  window.tvSozIste = (id, ac) => hafif(async () => { const r = await rpc("tv_soz_iste", { p_program: id, p_ac: ac }); if (S && S.c) { S.c.soz = Object.assign({}, S.c.soz, { istedim: ac }); koy("tvSeyirciK", seyirciHtml(S.d, S.c)); } return r; },
    ac ? "Söz istedin; sunucu seni yayına alabilir." : "Söz isteğin geri çekildi.");
  window.tvSozVer = (id, kad) => studyoCalis(id, () => rpc("tv_soz_ver", { p_program: id, p_kad: kad }), kad + " yayına bağlandı.");
  window.tvKonukCikar = async (id, kad) => { if (!await onayla("Yayından al", `${e(kad)} stüdyodan çıkarılacak; artık yayına yazamaz.`, "Yayından al", true)) return; return studyoCalis(id, () => rpc("tv_konuk_cikar", { p_program: id, p_kad: kad }), kad + " stüdyodan ayrıldı."); };
  window.tvReklamArasi = id => hafif(() => rpc("tv_reklam_arasi", { p_program: id }), "Reklam arası: 40 saniye.");
  window.tvHatirlat = (id, ac) => hafif(async () => { const r = await rpc("tv_hatirlat", { p_program: id, p_ac: ac }); if (EK) { EK.hatirlat = (EK.hatirlat || []).filter(x => x !== id); if (ac) EK.hatirlat.push(id); } return r; },
    ac ? "Hatırlatma kuruldu: program başlayınca bildirim gelir." : "Hatırlatma kaldırıldı.");
  window.tvAnketOy = (aid, i) => hafif(async () => { const r = await rpc("tv_anket_oyla", { p_anket: aid, p_secim: i }); if (S && S.c && S.c.anket && S.c.anket.id === aid) { S.c.anket.secimim = i; koy("tvSahne", sahneHtml(S.d, S.c), "oy" + aid + ":" + i + ":" + Date.now()); } return r; });
  window.tvAnketKapat = aid => hafif(() => rpc("tv_anket_kapat", { p_anket: aid }), "Soru kapandı.");
  window.tvOdulKoy = id => { const el = $("#tvOdulEk"), t = Math.round(Number(el && el.value) || 0); if (t < 1000) return toast("En az 1.000 ₺ gir.", true); el.value = "";
    return hafif(() => rpc("tv_odul_koy", { p_program: id, p_tutar: t }), tl(t) + " ödül havuzuna eklendi."); };
  window.tvAnketHazir = i => { const x = ANKET_HAZIR[i]; if (!x) return; $("#tvASoru").value = x[0]; [0, 1, 2, 3].forEach(j => { const el = $("#tvASec" + j); if (el) el.value = x[j + 1] || ""; }); };
  window.tvSoruBankasi = () => {
    const kul = window._tvSoruKul || (window._tvSoruKul = []);
    let aday = SORU_BANKASI.map((_, i) => i).filter(i => kul.indexOf(i) < 0); if (!aday.length) { kul.length = 0; aday = SORU_BANKASI.map((_, i) => i); }
    const no = aday[Math.floor(Math.random() * aday.length)]; kul.push(no);
    const q = SORU_BANKASI[no], sec = q.slice(1).map((x, j) => [x, j === 0]).sort(() => Math.random() - 0.5);
    $("#tvASoru").value = q[0]; sec.forEach((x, j) => { const el = $("#tvASec" + j); if (el) el.value = x[0]; });
    const dj = sec.findIndex(x => x[1]); const r = document.querySelector('input[name="tvADogru"][value="' + dj + '"]'); if (r) r.checked = true;
  };
  window.tvAnketAc = async id => {
    const soru = ($("#tvASoru").value || "").trim(), sec = [0, 1, 2, 3].map(j => (($("#tvASec" + j) || {}).value || "").trim());
    const dolu = sec.map((x, j) => [x, j]).filter(x => x[0]);
    if (soru.length < 4) return toast("Soruyu yaz (en az 4 karakter).", true);
    if (dolu.length < 2) return toast("En az iki seçenek yaz.", true);
    const r = document.querySelector('input[name="tvADogru"]:checked');
    let dogru = null;
    if (document.querySelector('input[name="tvADogru"]')) {
      const dj = r ? Number(r.value) : -1; dogru = dolu.findIndex(x => x[1] === dj);
      if (dogru < 0) return toast("Doğru cevabın yanındaki yuvarlağı işaretle (dolu bir seçenek olmalı).", true);
    }
    try {
      await rpc("tv_anket_ac", { p_program: id, p_soru: soru, p_secenekler: dolu.map(x => x[0]), p_saniye: Number($("#tvASure").value) || 30, p_dogru: dogru });
      $("#tvASoru").value = ""; [0, 1, 2, 3].forEach(j => { const el = $("#tvASec" + j); if (el) el.value = ""; });
      toast(dogru != null ? "Soru yayında; süre başladı." : "Anket yayında."); eylem(); if (window._tvTaz) await window._tvTaz();
    } catch (err) { toast(hataCevir(err.message), true); }
  };
  window.tvKonukDavet = id => { const el = $("#tvKonukKad"), k = (el.value || "").trim(); if (!k) return toast("Kullanıcı adı gir.", true); el.value = ""; return studyoCalis(id, () => rpc("tv_konuk_davet", { p_program: id, p_kad: k }), "Davet gönderildi."); };
  window.tvBitir = async (id, planli) => {
    if (!await onayla(planli ? "Programı iptal et" : "Yayını bitir", planli ? "Program iptal edilecek; verilen reklam bütçeleri ve yarışma ödülü iade edilir." : "Yayın şimdi sona erecek; reklam gelirleri hesaplanacak, yarışma ödülleri dağıtılacak.", planli ? "İptal et" : "Bitir", true)) return;
    return studyoCalis(id, () => rpc("tv_bitir", { p_program: id }), planli ? "Program iptal edildi." : "Yayın sona erdi.");
  };
  window.tvReklamKaynak = async id => {
    const sec = $("#tvRKaynak"); if (!sec || sec.dataset.dolu) return;
    try {
      const k = await rpc("tv_reklam_kaynak", { p_program: id });
      sec.dataset.dolu = "1";
      sec.innerHTML = `<option value="">Cüzdanım (${tl(k.cuzdan)})</option>` + (k.sirketler || []).map(s => `<option value="${s.id}">${e(s.ad)} kasası (${tl(s.kasa)})</option>`).join("");
    } catch (_) {}
  };
  window.tvReklamOzet = birim => {
    const b = Math.round(Number(($("#tvRButce") || {}).value) || 0), o = $("#tvROzet"); if (!o) return;
    o.textContent = b >= 5000 && birim > 0 ? `Bu bütçe en çok ${Math.floor(b / birim).toLocaleString("tr-TR")} izleyiciyi karşılar; daha az izleyici olursa fark iade edilir.` : "";
  };
  window.tvReklamVer = async id => {
    const marka = ($("#tvRMarka").value || "").trim(), metin = ($("#tvRMetin").value || "").trim(), butce = Math.round(Number($("#tvRButce").value) || 0), kaynak = $("#tvRKaynak").value;
    if (marka.length < 2 || metin.length < 5) return toast("Marka en az 2, reklam metni en az 5 karakter olmalı.", true);
    if (butce < 5000) return toast("Reklam bütçesi en az 5.000 ₺ olmalı.", true);
    if (!await onayla("Reklam ver", `${tl(butce)} bütçe ${kaynak ? "şirket kasasından" : "cüzdanından"} ayrılacak. Kullanılmayan kısım program bitince iade edilir.`, "Talebi gönder")) return;
    try {
      const r = await rpc("tv_reklam_ver", { p_program: id, p_marka: marka, p_metin: metin, p_butce: butce, p_sirket: kaynak ? Number(kaynak) : null });
      ["tvRMarka", "tvRMetin", "tvRButce"].forEach(x => { const el = document.getElementById(x); if (el) el.value = ""; });
      toast("Reklam talebin kanal sahibine iletildi."); await window.tvStudyoEkrani(id, r);
    } catch (err) { toast(hataCevir(err.message), true); }
  };
  window.tvReklamIptal = async (rid, id) => { if (!await onayla("Reklamı iptal et", "Reklam talebin geri çekilecek ve bütçenin tamamı iade edilecek.", "İptal et", true)) return; return studyoCalis(id, () => rpc("tv_reklam_iptal", { p_reklam: rid }), "Reklam iptal edildi, bütçe iade edildi."); };
  void progKart;
})();
