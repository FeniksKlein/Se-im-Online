-- Geniş gazete ekleri: meclis, kararnameler, referandum, ittifak, makam, şirket ve ekonomi raporu.
CREATE OR REPLACE FUNCTION oyun.ajans_derle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t timestamptz:=oyun.simdi();e record; v_count bigint; v_before bigint;
  kind text; ttl text; summary text; article text; pp integer; name text;
begin
 -- pg_cron ayni anda veya oyun motorunda cagrilsa bile yarisma olmaz.
 if not pg_try_advisory_xact_lock(82771,808) then
   return jsonb_build_object('tamam',true,'mesaj','Başka haber taraması sürüyor');
 end if;
 select count(*) into v_before from oyun.ajans_haberleri;

 -- Kamuya acik parti olaylari: ic oylamalarin/tuzuklerin gizli metinlerini alma.
 for e in
   select o.id,o.zaman,o.metin,o.parti_id,o.il_id,coalesce(p.kisa,'Parti') parti
   from oyun.olaylar o left join oyun.partiler p on p.id=o.parti_id
   where o.zaman>=t-interval '21 days'
     and not (o.metin ilike '%beyannamesini açıkladı%' and exists(
       select 1 from oyun.parti_beyanname b where b.parti_id=o.parti_id
       and b.zaman>=o.zaman-interval '2 days'))
     and (o.metin ilike '%beyannamesini açıkladı%'
      or o.metin ilike '%genel başkanlığını üstlendi%'
      or o.metin ilike '%adını%olarak değiştirdi%'
      or o.metin ilike '%adayını açıkladı%'
      or o.metin ilike '%adayını destekliyor%'
      or o.metin ilike '%parti amblemini değiştirdi%'
      or o.metin ilike '%genel başkan yardımcılığına atandı%')
   order by o.zaman,o.id
 loop
   kind:='siyaset';pp:=64;
   if e.metin ilike '%beyannamesini açıkladı%' then
     kind:='secim';pp:=90;ttl:=e.parti||' seçim beyannamesini yayımladı';
   elsif e.metin ilike '%genel başkanlığını üstlendi%' then
     ttl:=e.parti||' yönetiminde yeni genel başkan';pp:=86;
   elsif e.metin ilike '%adını%olarak değiştirdi%' then
     ttl:=e.parti||' siyasi kimliğini yeniledi';pp:=77;
   elsif e.metin ilike '%adayını açıkladı%' or e.metin ilike '%adayını destekliyor%' then
     kind:='adaylar';pp:=85;ttl:=e.parti||' adaylık konusunda karar açıkladı';
   elsif e.metin ilike '%genel başkan yardımcılığına atandı%' then
     ttl:=e.parti||' yönetim kadrosuna yeni atama';pp:=65;
   else
     ttl:=e.parti||' amblemini değiştirdi';pp:=60;
   end if;
   summary:=e.metin;
   article:='Türkiye Gündem haber merkezinin oyun içi resmî olay kaydına göre '||
     e.metin||E'\n\n'||
     'Bu gelişme '||to_char(e.zaman at time zone 'Europe/Istanbul','DD.MM.YYYY HH24:MI')||
     ' tarihinde kayda geçti. Haberdeki açıklama oyun verilerinden aktarılmıştır. '||
     'Seçim sonucu veya oy oranı konusunda henüz doğrulanmamış bir tahmin yapılmamıştır.';
   perform oyun.ajans_yayinla('olay:'||e.id,kind,ttl,summary,article,pp,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Parti beyannameleri: metin resmi tabloya kaydedildiyse tam metni de ver.
 for e in select b.parti_id,b.donem,b.zaman,b.metin,p.kisa,p.ad
   from oyun.parti_beyanname b join oyun.partiler p on p.id=b.parti_id
   where b.zaman>=t-interval '21 days' order by b.zaman
 loop
   ttl:=e.kisa||' '||e.donem||' seçim beyannamesini açıkladı';
   summary:=e.ad||' seçim vaat ve programını duyurdu.';
   article:=e.ad||' tarafından '||e.donem||' dönemi için seçim beyannamesi yayımlandı.'||
    E'\n\n'||case when nullif(btrim(coalesce(e.metin,'')),'') is not null
      then 'Beyanname açıklaması:'||E'\n'||e.metin
      else 'Yazılı beyanname özeti bulunmuyor; partinin oyun içi vaatleri kendi parti sayfasında incelenebilir.' end||
    E'\n\n'||'Bu bir parti açıklamasıdır; gazetenin desteği ya da görüşü değildir.';
   perform oyun.ajans_yayinla('beyanname:'||e.parti_id||':'||e.donem,'secim',ttl,summary,article,92,e.parti_id,null,e.zaman);
 end loop;

 -- Cumhurbaskani kararlari. Sadece KESIN ve gercek aday kaydi olan adaylar.
 for e in
  select k.donem,k.parti_id,k.yontem,k.destek_parti,k.zaman,
   p.kisa,p.ad,coalesce(h.kisa,'') hedef_kisa,
   a.user_id,pr.kad, a.id aday_id
  from oyun.cb_kararlar k
  join oyun.partiler p on p.id=k.parti_id
  join oyun.secimler s on s.tur='cb' and s.donem=k.donem
  left join oyun.partiler h on h.id=k.destek_parti
  left join lateral (
    select aa.id,aa.user_id from oyun.adaylar aa
    where aa.secim_id=s.id and aa.parti_id=case when k.yontem='destek' then k.destek_parti else k.parti_id end
    order by aa.id limit 1
  ) a on true
  left join oyun.profiller pr on pr.id=a.user_id
  where k.zaman>=t-interval '21 days' and a.id is not null
  order by k.zaman
 loop
  if e.yontem='destek' then
    ttl:=e.kisa||' Cumhurbaşkanlığında '||e.hedef_kisa||' adayını destekleyecek';
    summary:=e.kisa||', '||e.kad||' adlı gerçek oyuncunun ortak adaylığını destekleme kararı aldı.';
    kind:='ittifak';
    article:=e.ad||', '||e.donem||' Cumhurbaşkanlığı seçimi için '||
      e.hedef_kisa||' adayı '||e.kad||' lehine destek kararı açıkladı.'||
      E'\n\n'||'Destek veren partinin ayrıca ikinci bir Cumhurbaşkanı adayı bulunmuyor. '||
      'Seçmenler oylarını tek gerçek oyuncu adaya verecek.';
  else
    ttl:=e.kisa||' Cumhurbaşkanı adayını açıkladı: '||e.kad;
    summary:=e.ad||', Cumhurbaşkanı adayı olarak '||e.kad||' adlı oyuncunun ismini kesinleştirdi.';
    kind:='adaylar';
    article:=e.ad||', '||e.donem||' dönemi Cumhurbaşkanlığı seçiminde '||
      e.kad||' adlı oyuncuyu aday gösterdi.'||E'\n\n'||
      'Adayın ve varsa kendisini destekleyen partilerin ayrıntıları parti sayfasından takip edilebilir.';
  end if;
  perform oyun.ajans_yayinla('cb:'||e.donem||':'||e.parti_id||':'||e.yontem||':'||coalesce(e.aday_id::text,''),
      kind,ttl,summary,article,96,e.parti_id,null,e.zaman);
 end loop;

 -- Belediye kesin adaylari ilan edildikce il odakli haber.
 for e in
 select a.id,a.parti_id,a.il_id,a.basvuru_at,s.donem,p.kisa,p.ad,
   pr.kad,i.ad il
 from oyun.adaylar a join oyun.secimler s on s.id=a.secim_id and s.tur='bel'
 join oyun.partiler p on p.id=a.parti_id join oyun.profiller pr on pr.id=a.user_id
 left join oyun.iller i on i.id=a.il_id
 where a.basvuru_at>=t-interval '21 days'
 order by a.basvuru_at
 loop
  ttl:=e.il||' için '||e.kisa||' adayı: '||e.kad;
  summary:=e.ad||', '||e.il||' belediye başkanlığına '||e.kad||' adlı oyuncuyu aday gösterdi.';
  article:=summary||E'\n\n'||e.donem||' belediye seçiminde adaylık kesinleşti. '||
    'Oy verme ve seçim sonucuna ilişkin bilgiler oyundaki resmî takvimden takip edilmelidir.';
  perform oyun.ajans_yayinla('bel_aday:'||e.id,'adaylar',ttl,summary,article,73,e.parti_id,e.il_id,e.basvuru_at);
 end loop;

 -- Il bazinda ortak belediye baskan adayi desteği.
 for e in
 select b.secim_id,b.il_id,b.parti_id,b.hedef_parti_id,b.zaman,src.kisa src,
 target.kisa hedef, pr.kad, il.ad il
 from oyun.bel_aday_destek b
 join oyun.partiler src on src.id=b.parti_id
 join oyun.partiler target on target.id=b.hedef_parti_id
 join oyun.adaylar a on a.id=b.aday_id join oyun.profiller pr on pr.id=a.user_id
 join oyun.iller il on il.id=b.il_id
 where b.zaman>=t-interval '21 days'
 loop
   ttl:=e.il||' seçimi: '||e.src||' ile '||e.hedef||' ortak adayda buluştu';
   summary:=e.src||', '||e.il||' belediye seçiminde '||e.kad||
     ' adayını destekliyor.';
   article:=e.src||', '||e.hedef||' partisinin '||e.il||' belediye başkanı adayı '||e.kad||
      ' lehine destek kararı açıkladı.'||E'\n\n'||
      'Destek veren parti aynı ilde ayrı adayla yarışmıyor; seçmenler ortak adaya oy verecek.';
   perform oyun.ajans_yayinla('bel_destek:'||e.secim_id||':'||e.il_id||':'||e.parti_id||':'||e.hedef_parti_id,
      'ittifak',ttl,summary,article,88,e.parti_id,e.il_id,e.zaman);
 end loop;

 -- Genel baskanin tum oyunculara yaptigi ADAY tanitimlari; uyeye ozel yayinlar yayinlanmaz.
 for e in
 select a.id,a.parti_id,a.zaman,a.metin,p.kisa,p.ad,pr.kad
 from oyun.parti_aday_tanitim a
 join oyun.partiler p on p.id=a.parti_id
 join oyun.adaylar ad on ad.id=a.aday_id
 join oyun.profiller pr on pr.id=ad.user_id
 where a.kitle='herkes' and a.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' adayını kamuoyuna tanıttı: '||e.kad;
  summary:=e.ad||', adaylık sürecindeki '||e.kad||' için tanıtım duyurusu yayımladı.';
  article:=summary||E'\n\n'||'Partinin açıklaması:'||E'\n'||e.metin||
      E'\n\n'||'Bu metin ilgili partinin kendi tanıtım duyurusudur.';
  perform oyun.ajans_yayinla('aday_tanitim:'||e.id,'adaylar',ttl,summary,article,70,e.parti_id,null,e.zaman);
 end loop;

 -- Ekonomi: yüksek tutarlı bagislar kamuya acik parti kasa hareketlerinden.
 -- Her bagisi paylasmak yerine asgari ucretin 5 kati ustu haberlestirilir.
 for e in
 select h.id,h.parti_id,h.zaman,h.tutar,h.aciklama,p.kisa
 from oyun.parti_hareket h join oyun.partiler p on p.id=h.parti_id
 where h.tur='bagis' and h.tutar>=5*(select asgari from oyun.ulke where id=1)
 and h.zaman>=t-interval '21 days'
 loop
  ttl:=e.kisa||' kasasına önemli bağış: '||oyun.tl(e.tutar)||' ₺';
  summary:='Partinin mali kayıtlarında '||oyun.tl(e.tutar)||' ₺ bağış işlendi.';
  article:=summary||E'\n\n'||e.aciklama||
   E'\n\n'||'Bu tutar parti kasasına geçen oyun içi paradır.';
  perform oyun.ajans_yayinla('parti_bagis:'||e.id,'ekonomi',ttl,summary,article,68,e.parti_id,null,e.zaman);
 end loop;

 -- Secim sonuclari: kanitlanan resmî sonuc aciklamasi; sonucu olmayan secimi haber yapma.
 for e in
 select id,tur,donem,sonuc_at,sonuc from oyun.secimler
 where sonuc is not null and durum<>'bekliyor' and sonuc_at>=t-interval '21 days'
 loop
  ttl:=case e.tur when 'cb' then 'Cumhurbaşkanlığı' when 'mv' then 'Genel'
      when 'bel' then 'Belediye' else 'Ön' end||' seçiminin sonuçları açıklandı';
  summary:=e.donem||' dönemi için resmî seçim sonuçları yayımlandı.';
  article:=summary||E'\n\n'||'Ayrıntılı aday ve oy sonuçları için oyunun Seçimler bölümündeki sonuç ekranına bakın.';
  perform oyun.ajans_yayinla('secim_sonuc:'||e.id,'secim',ttl,summary,article,98,null,null,e.sonuc_at);
 end loop;


 -- TBMM: oneriler, onaylanan yasalar; oy sonucu ve yasama statüsü uydurulmaz.
 for e in
   select k.id,k.baslik,k.metin,k.teklif_parti,k.teklif_at,k.sonuc_at,k.durum,
     coalesce(pa.kisa,'TBMM') parti
   from oyun.kanunlar k left join oyun.partiler pa on pa.id=k.teklif_parti
   where k.teklif_at>=t-interval '21 days' or k.sonuc_at>=t-interval '21 days'
 loop
   if e.teklif_at>=t-interval '21 days' then
    ttl:='TBMM gündeminde yeni teklif: '||coalesce(e.baslik,'Kanun teklifi');
    summary:=e.parti||' kaynaklı kanun teklifi Meclis gündemine girdi.';
    article:=summary||E'\n\n'||coalesce(left(e.metin,1600),'Teklifin ayrıntıları Meclis kayıtlarında yer alıyor.')||
       E'\n\n'||'Teklifin kabul edildiği anlamına gelmez; oylama sonucunu takip ediniz.';
    perform oyun.ajans_yayinla('kanun_teklif:'||e.id,'meclis',ttl,summary,article,76,e.teklif_parti,null,e.teklif_at);
   end if;
   if e.sonuc_at>=t-interval '21 days' then
    ttl:='TBMM kararını verdi: '||coalesce(e.baslik,'Kanun teklifi');
    summary:=coalesce(e.baslik,'Teklif')||' hakkında resmî sonuç kaydedildi: '||coalesce(e.durum,'Sonuçlandı');
    article:=summary||E'\n\n'||'Meclis kanun kaydı bu sonuca göre güncellendi. '||
     'Oylama sayıları ve varsa yürürlük etkileri için Meclis bölümünü inceleyin.';
    perform oyun.ajans_yayinla('kanun_sonuc:'||e.id,'meclis',ttl,summary,article,91,e.teklif_parti,null,e.sonuc_at);
   end if;
 end loop;

 -- Cumhurbaşkanlığı kararnameleri.
 for e in
 select id,baslik,metin,zaman,durum,tur from oyun.kararnameler
 where zaman>=t-interval '21 days' order by zaman
 loop
  ttl:='Cumhurbaşkanlığı kararnamesi: '||coalesce(e.baslik,'Yeni düzenleme');
  summary:='Cumhurbaşkanlığı oyun yönetiminde yeni bir kararname kaydı oluşturuldu.';
  article:=summary||E'\n\n'||'Konu: '||coalesce(e.baslik,'Belirtilmedi')||
     E'\nDurum: '||coalesce(e.durum,'Kayıtlı')||
     E'\n\n'||coalesce(left(e.metin,1800),'Ayrıntılar devlet yönetimi bölümünde bulunabilir.');
  perform oyun.ajans_yayinla('kararname:'||e.id,'meclis',ttl,summary,article,85,null,null,e.zaman);
 end loop;

 -- Ulusal referandum duyurulari, kesinlesmis sonuclar.
 for e in
 select id,baslik,olusturma,sonuc,oy_bit,durum,evet,hayir
 from oyun.referandumlar where olusturma>=t-interval '21 days'
  or (oy_bit>=t-interval '21 days' and durum='sonuclandi')
 loop
  if e.olusturma>=t-interval '21 days' then
   ttl:='Referandum süreci: '||e.baslik;
   summary:='Oyunda yeni referandum ilan edildi.';
   perform oyun.ajans_yayinla('referandum_yeni:'||e.id,'secim',ttl,summary,
    summary||E'\n\n'||'Oylama tarihleri ve seçenekleri oyun içindeki referandum ekranında açıklanır.',
    87,null,null,e.olusturma);
  end if;
  if e.durum='sonuclandi' and e.oy_bit>=t-interval '21 days' then
   ttl:='Referandum sonuçlandı: '||e.baslik;
   summary:='Resmî referandum sonucu: '||coalesce(e.sonuc,'Sonuçlandı');
   article:=summary||E'\nEvet oyları: '||coalesce(e.evet,0)||E'\nHayır oyları: '||coalesce(e.hayir,0);
   perform oyun.ajans_yayinla('referandum_sonuc:'||e.id,'secim',ttl,summary,article,97,null,null,e.oy_bit);
  end if;
 end loop;

 -- Gercek ittifak kuruluslari.
 for e in
 select it.id,it.ad,it.kurulus,it.kurucu_parti,p.kisa
 from oyun.ittifaklar it left join oyun.partiler p on p.id=it.kurucu_parti
 where it.kurulus>=t-interval '21 days'
 loop
  ttl:='Siyasette yeni ittifak: '||e.ad;
  summary:=coalesce(e.kisa,'Bir siyasi parti')||' öncülüğünde '||e.ad||' ittifakı kuruldu.';
  article:=summary||E'\n\n'||'İttifak üyeleri ve ortak aday açıklamaları ilgili partilerin sayfalarında görülebilir.';
  perform oyun.ajans_yayinla('ittifak_kurulus:'||e.id,'ittifak',ttl,summary,article,80,e.kurucu_parti,null,e.kurulus);
 end loop;

 -- Onemli devlet gorevlerine getirilen oyuncular.
 for e in
 select m.id,m.tur,m.user_id,m.parti_id,m.bas,p.kad,coalesce(pa.kisa,'Partisiz') parti,
   il.ad il
 from oyun.makamlar m join oyun.profiller p on p.id=m.user_id
 left join oyun.partiler pa on pa.id=m.parti_id
 left join oyun.iller il on il.id=m.il_id
 where m.bas>=t-interval '21 days' and m.bit is null
 loop
   ttl:=e.kad||' yeni kamu görevine başladı';
   summary:=e.kad||' ('||e.parti||') oyuncusunun '||
    coalesce(e.il||' ili ','')||e.tur||' görevi kayıtlara geçti.';
   article:=summary||E'\n\n'||'Görevin başlangıcı oyun sistemindeki resmî makam kaydına dayanır.';
   perform oyun.ajans_yayinla('makam:'||e.id,'siyaset',ttl,summary,article,87,e.parti_id,null,e.bas);
 end loop;

 -- Yeni kurulan önemli işletmeler: ör. 500.000 TL+ sermaye.
 for e in
 select s.id,s.ad,s.sektor,s.sermaye,s.kurulus,p.kad from oyun.sirketler s
 join oyun.profiller p on p.id=s.kurucu
 where s.kurulus>=t-interval '21 days' and s.sermaye>=500000 and s.aktif
 loop
  ttl:='İş dünyasında yeni şirket: '||e.ad;
  summary:=e.kad||', '||e.ad||' adlı '||e.sektor||' işletmesini kurdu.';
  article:=summary||E'\n\n'||'Kayıtlı kuruluş sermayesi: '||oyun.tl(e.sermaye)||' ₺.'||
    E'\n\n'||'Sermaye tutarı geçmiş ya da gelecekteki kârı garanti etmez.';
  perform oyun.ajans_yayinla('sirket_kur:'||e.id,'ekonomi',ttl,summary,article,57,null,null,e.kurulus);
 end loop;

 -- Tarihli ulusal ekonomi raporu; mevcut resmi veriler dışında tahmin yok.
 for e in
 select gun,hazine,vergi,buyume,enflasyon,issizlik,memnuniyet
 from oyun.ulke_gecmis where gun>=((t at time zone 'Europe/Istanbul')::date-14)
 order by gun
 loop
  ttl:='Günlük ekonomi bülteni: '||to_char(e.gun,'DD.MM.YYYY');
  summary:='Enflasyon %'||coalesce(e.enflasyon::text,'—')||
    ', işsizlik %'||coalesce(e.issizlik::text,'—')||' olarak kayıtlara geçti.';
  article:='Türkiye Gündem ekonomi servisi, simülasyonun '||e.gun||' tarihli resmi verilerini derledi.'||
   E'\n\nEnflasyon: %'||coalesce(e.enflasyon::text,'—')||
   E'\nİşsizlik: %'||coalesce(e.issizlik::text,'—')||
   E'\nBüyüme: %'||coalesce(e.buyume::text,'—')||
   E'\nMemnuniyet: '||coalesce(e.memnuniyet::text,'—')||
   E'\nDevlet hazinesi: '||coalesce(oyun.tl(e.hazine),'—')||' ₺'||
   E'\n\n'||'Veriler simülasyonun geçmişte kaydedilmiş göstergeleridir; gerçek Türkiye ekonomisini temsil etmez.';
  perform oyun.ajans_yayinla('ekonomi_gun:'||e.gun,'ekonomi',ttl,summary,article,42,null,null,(e.gun::timestamp at time zone 'Europe/Istanbul')+interval '18 hours');
 end loop;


 select count(*)-v_before into v_count from oyun.ajans_haberleri;
 return jsonb_build_object('tamam',true,'yeni_haber',v_count,
   'toplam',(select count(*) from oyun.ajans_haberleri));
end $function$
;
