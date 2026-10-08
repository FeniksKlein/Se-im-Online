-- Belediye gelisimine ek olarak, oyuncunun sehre gonderdigi para il belediyesinin gercek kasasina girer.
CREATE OR REPLACE FUNCTION public.serbest_bagis(p_tur text, p_id text, p_tutar numeric, p_aciklama text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=auth.uid(); p oyun.profiller; t timestamptz:=oyun.simdi();
 m numeric; tid bigint; v_id bigint; v_uuid uuid; hedef text;
 note text:=btrim(coalesce(p_aciklama,'')); c oyun.cuzdan; v_min numeric;
begin
 if u is null then raise exception 'Oturum açmalısın';end if;
 if p_tutar is null or p_tutar::text !~ '^[0-9]+(\.[0-9]+)?$'
   or p_tutar<>trunc(p_tutar) or p_tutar<1 then
   raise exception 'Bağış tutarı en az 1 TL, pozitif tam sayı olmalı';end if;
 m:=p_tutar;
 if length(note)>150 then raise exception 'Bağış notu en fazla 150 karakter';end if;
 select * into p from oyun.profiller where id=u;
 if not found or p.yasakli then raise exception 'Hesabın bağış yapmaya uygun değil';end if;
 perform oyun.takip_engel(u,'bağış yapamazsın');
 if p_tur not in ('oyuncu','parti','sirket','gazete','il','devlet') then raise exception 'Geçersiz bağış hedefi';end if;
 -- Para transferinin alıcısı bulunmadan göndericiden tahsilat yapılmaz.
 if p_tur='oyuncu' then
   select id,kad into v_uuid,hedef from oyun.profiller
    where lower(kad)=lower(btrim(coalesce(p_id,''))) and not yasakli limit 1;
   if v_uuid is null then raise exception 'Alıcı oyuncu bulunamadı';end if;
   if v_uuid=u then raise exception 'Kendine bağış yapamazsın';end if;
   if exists(select 1 from oyun.ayarlar where id=1 and coklu_kontrol)
     and exists(select 1 from oyun.bagli_hesaplar(u) b where b.id=v_uuid) then
      raise exception 'Aynı cihazdaki bağlı hesaplara bağış yapılamaz';end if;
   if oyun.engelli(v_uuid,u) then raise exception 'Bu oyuncu seni engelledi';end if;
 elsif p_tur in ('parti','sirket','gazete','il') then
   if p_id is null or p_id !~ '^[0-9]{1,15}$' then raise exception 'Geçerli hedef numarası gir';end if;
   v_id:=p_id::bigint;
   if p_tur='parti' then
     select ad into hedef from oyun.partiler where id=v_id and not kapali;
   elsif p_tur='sirket' then
     select ad into hedef from oyun.sirketler where id=v_id and aktif;
   elsif p_tur='gazete' then
     select ad into hedef from oyun.oyuncu_gazeteleri where id=v_id and aktif;
   else
     select ad into hedef from oyun.iller where id=v_id;
   end if;
   if hedef is null then raise exception 'Bağış yapılacak kurum bulunamadı';end if;
 else
   hedef:='Türkiye Cumhuriyeti Hazinesi';
 end if;
 -- Gonderenin bakiyesi oyun.para_islem tarafindan atomik ve kilitli UPDATE ile kontrol edilir.
 perform oyun.para_islem(u,-m,'bagis',left(hedef||' için bağış'||case when note<>'' then ': '||note else '' end,170),t);
 if p_tur='oyuncu' then
   perform oyun.para_islem(v_uuid,m,'bagis',left(p.kad||' tarafından bağış'||case when note<>'' then ': '||note else '' end,170),t);
   perform oyun.bildir(v_uuid,format('%s sana %s ₺ bağışladı.',p.kad,oyun.tl(m)),t);
 elsif p_tur='parti' then
   update oyun.partiler set kasa=kasa+m where id=v_id;
   insert into oyun.parti_hareket(parti_id,zaman,tutar,aciklama,tur)
     values(v_id,t,m,format('%s bağış yaptı',p.kad),'bagis');
 elsif p_tur='sirket' then
   update oyun.sirketler set kasa=kasa+m where id=v_id;
   insert into oyun.sirket_hareket(sirket_id,zaman,tutar,aciklama)
     values(v_id,t,m,p.kad||' oyuncusundan sermaye niteliğinde olmayan karşılıksız bağış');
 elsif p_tur='gazete' then
   update oyun.oyuncu_gazeteleri set kasa=kasa+m where id=v_id;
   insert into oyun.gazete_hareket(gazete_id,zaman,tutar,tur,aciklama)
     values(v_id,t,m,'bagis',p.kad||' bağış yaptı');
 elsif p_tur='il' then
   select asgari into v_min from oyun.ulke where id=1;
   update oyun.il_durum set kasa=kasa+m,gelisim=least(100,gelisim+0.005*m/greatest(1,v_min)) where il_id=v_id;
   insert into oyun.il_bagis_kayit(il_id,user_id,tutar,zaman) values(v_id::smallint,u,m,t);
 else
   update oyun.ulke set hazine=hazine+m where id=1;
 end if;
 insert into oyun.serbest_bagis_kayit(gonderen,alici_tur,alici_id,alici_adi,tutar,aciklama,zaman)
 values(u,p_tur,case when p_tur='oyuncu' then v_uuid::text when p_tur='devlet' then '1' else v_id::text end,hedef,m,nullif(note,''),t)
 returning id into tid;
 -- Kıdem kazanımı para miktarıyla sonsuz ölçeklenmez: bağıştan en fazla günlük 1 puan.
 select * into c from oyun.cuzdan where user_id=u for update;
 select asgari into v_min from oyun.ulke where id=1;
 update oyun.cuzdan
 set kidem=kidem+greatest(0,
   least(1,(coalesce(c.bagis_bugun,0)+m)/greatest(1,v_min))
    -least(1,coalesce(c.bagis_bugun,0)/greatest(1,v_min))),
   bagis_bugun=coalesce(bagis_bugun,0)+m where user_id=u;
 return jsonb_build_object('tamam',true,'id',tid,'gonderen',p.kad,
  'hedef',hedef,'hedef_tur',p_tur,'tutar',m,
  'kalan', (select para from oyun.cuzdan where user_id=u));
end $function$
;

-- Seçim beyannamesi haberini resmi kaynaktan bir kere yayinla, olay logundan ikincisini uretme.
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

 select count(*)-v_before into v_count from oyun.ajans_haberleri;
 return jsonb_build_object('tamam',true,'yeni_haber',v_count,
   'toplam',(select count(*) from oyun.ajans_haberleri));
end $function$
;

delete from oyun.ajans_haberleri h
using oyun.olaylar o
where h.kaynak_anahtar='olay:'||o.id
  and o.metin ilike '%beyannamesini açıkladı%'
  and exists(select 1 from oyun.parti_beyanname b
     where b.parti_id=o.parti_id and b.zaman>=o.zaman-interval '2 days');
