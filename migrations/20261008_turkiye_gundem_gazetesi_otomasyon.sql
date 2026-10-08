-- Otomatik haber motoru. Gercek kayitlar disinda haber uretmez.
-- 5 dakikada bir calisir; her olay kaynak_anahtar ile YALNIZCA bir kez yayinlanir.
create or replace function oyun.ajans_derle()
returns jsonb language plpgsql security definer set search_path='' as $f$
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
end $f$;
revoke all on function oyun.ajans_derle() from public,anon,authenticated;

-- Parti degisikligi ancak gerçekten olmuşsa bildirilir; önemli roller manşete çıkar.
create or replace function oyun.ajans_parti_degisim_trigger()
returns trigger language plpgsql set search_path='' as $f$
declare eski text; yeni text; onemli boolean; puan integer; why text;
begin
 if new.parti_id is not distinct from old.parti_id then return new;end if;
 if new.yasakli then return new;end if;
 select kisa into eski from oyun.partiler where id=old.parti_id;
 select kisa into yeni from oyun.partiler where id=new.parti_id;
 onemli:=exists(select 1 from oyun.partiler where gb=new.id)
      or exists(select 1 from oyun.parti_gby where user_id=new.id)
      or exists(select 1 from oyun.makamlar where user_id=new.id and bit is null)
      or exists(select 1 from oyun.adaylar where user_id=new.id);
 puan:=case when onemli then 91 else 49 end;
 why:=case when old.parti_id is null then 'siyasete parti üyeliğiyle katıldı'
   when new.parti_id is null then 'partisinden ayrıldı'
   else coalesce(eski,'eski partisinden')||' partisinden '||coalesce(yeni,'yeni partisine')||' partisine geçti' end;
 perform oyun.ajans_yayinla(
  'parti_degisim:'||new.id::text||':'||txid_current()::text,
  'siyaset',case when onemli then 'Siyasette dikkat çeken değişim: ' else 'Parti üyeliğinde değişiklik: ' end||new.kad,
  new.kad||' '||why||'.',
  new.kad||' adlı oyuncunun parti üyeliği değişti.'||E'\n\n'||
  'Önceki parti: '||coalesce(eski,'Partisiz')||E'\nYeni parti: '||
   coalesce(yeni,'Partisiz')||E'\n\n'||
  case when onemli then 'Oyuncunun mevcut veya geçmiş siyasi adaylık/yönetim kaydı nedeniyle bu değişiklik öne çıkarılmıştır.'
   else 'Bu değişiklik oyuncunun parti üyeliği kaydından doğrulanmıştır.' end,
  puan,new.parti_id,new.il_id,oyun.simdi());
 return new;
end $f$;
drop trigger if exists ajans_parti_degisimi on oyun.profiller;
create trigger ajans_parti_degisimi after update of parti_id on oyun.profiller
 for each row when (old.parti_id is distinct from new.parti_id)
 execute function oyun.ajans_parti_degisim_trigger();

-- Ekonomi ve parti disinda ittifak olusumu icin de otomatik haber.
create or replace function oyun.ajans_ittifak_trigger()
returns trigger language plpgsql set search_path='' as $f$
declare p text; itt text; hit bigint;pid bigint;op text;
begin
 if TG_OP='DELETE' then hit:=old.ittifak_id;pid:=old.parti_id;op:='ayrildi';
 else hit:=new.ittifak_id;pid:=new.parti_id;op:='katildi';end if;
 select kisa into p from oyun.partiler where id=pid;
 select ad into itt from oyun.ittifaklar where id=hit;
 if p is not null and itt is not null then
 perform oyun.ajans_yayinla('ittifak_'||op||':'||pid||':'||hit||':'||txid_current(),
 'ittifak',p||case when TG_OP='INSERT' then ' ittifaka katıldı' else ' ittifaktan ayrıldı' end,
 p||' partisinin '||itt||' ittifakındaki durumu değişti.',
 p||' partisinin '||itt||' ittifakıyla ilgili üyelik değişikliği oyun kayıtlarında doğrulandı.'||
 E'\n\n'||'Resmî seçimlerde ortak aday desteği ayrıca aday kaydı oluşturulduğunda açıklanır.',
 73,pid,null,oyun.simdi());
 end if;
 if TG_OP='DELETE' then return old;end if;
 return new;
end $f$;
drop trigger if exists ajans_ittifak_uyelik on oyun.ittifak_uyeler;
create trigger ajans_ittifak_uyelik after insert or delete on oyun.ittifak_uyeler
 for each row execute function oyun.ajans_ittifak_trigger();

-- Her 5 dakikada bir. Cron veri taramasi idempotenttir; haber tekrarlamaz.
select cron.schedule('turkiye-gundem-otomatik-gazete','*/5 * * * *',
 'select oyun.ajans_derle()');
