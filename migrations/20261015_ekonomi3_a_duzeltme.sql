-- Canlıya uygulandı (2026-10-15, Supabase migration ekonomi3_*). Tekrar çalıştırılabilir.
begin;
-- 99a · EKONOMİ 3.0 — para birimi ve kritik düzeltmeler (2026-10-15)
-- Oyunun resmî kuru: 1 milyar kamu ₺ = oyun.pazar_tl_milyar() oyuncu ₺ (≈150.000 × fiyat endeksi).
-- Sorun: şirket vergileri (eko_vergi_tahsil) oyuncu ₺'sini doğrudan milyar ₺ olarak hazineye ekliyordu
-- (5.351 ₺ vergi → hazine 250 → 5.600 milyar). Bazı eski fonksiyonlar da 1e6 / 1e9 kullanıyordu.
-- İki kez çalıştırılabilir. Oyuncu verisine dokunmaz; yalnız hazine fazlası bir kez düşülür.

-- 1) Şirket vergileri hazineye doğru birimle girer
create or replace function oyun.eko_vergi_tahsil(p_sirket bigint, p_matrah text, p_baza numeric, p_kaynak text, p_kaynak_id bigint, p_oyuncu uuid default null::uuid)
 returns numeric language plpgsql security definer set search_path to ''
as $function$
declare v record; odenen numeric:=0; x numeric; tlm numeric:=oyun.pazar_tl_milyar();
begin
 if p_sirket is null or p_kaynak_id is null or p_matrah not in ('satis','kar','dagitim','sozlesme')
 then raise exception 'Vergi matrahi veya kaynak kimligi gecersiz.';end if;
 for v in select kod,oran from oyun.eko_vergi_turleri
 where matrah=p_matrah and aktif and oran>0 order by kod
 loop
   x:=round(case when v.kod='kdv' and p_matrah='satis'
   then greatest(0,p_baza)*v.oran/(100+v.oran)
   else greatest(0,p_baza)*v.oran/100 end);
   if x<=0 then continue;end if;
   insert into oyun.eko_vergi_hareket(sirket_id,oyuncu,kod,matrah,oran,tutar,kaynak,kaynak_id)
   values(p_sirket,p_oyuncu,v.kod,greatest(0,p_baza),v.oran,x,p_kaynak,p_kaynak_id)
   on conflict do nothing;
   if found then
      update oyun.ulke set hazine=hazine+x/tlm where id=1;
      odenen:=odenen+x;
   end if;
 end loop;
 return odenen;
end $function$;

-- 2) Hazine fazlasını bir kez düzelt (yalnız ilk çalıştırmada)
create table if not exists oyun.ekonomi3_kayit(kod text primary key, deger numeric, zaman timestamptz default now());
do $$
declare toplam numeric; tlm numeric:=oyun.pazar_tl_milyar();
begin
  if exists(select 1 from oyun.ekonomi3_kayit where kod='hazine_vergi_duzeltme') then return; end if;
  select coalesce(sum(tutar),0) into toplam from oyun.eko_vergi_hareket;
  update oyun.ulke set hazine = hazine - toplam + toplam/tlm where id=1;
  insert into oyun.ekonomi3_kayit(kod,deger) values('hazine_vergi_duzeltme', toplam - toplam/tlm);
end $$;

-- 3) Eski 1e6 / 1e9 dönüşümleri tek resmî kura çekilir
do $$
declare r record; d text; e text;
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname in ('oyun','public') and p.proname in
           ('eko_islem','mulk_kira_tahsil','piyango_bilet_al','tahvil_al','tahvil_portfoy',
            'belediye_is_tick','belediye_is_iptal','belediye_is_ihale_ac','kazikazan_oyna','piyasa_emir')
  loop
    d := pg_get_functiondef(r.oid);
    e := regexp_replace(d, '/\s*1000000000(\.0)?\M', '/oyun.pazar_tl_milyar()', 'g');
    e := regexp_replace(e, '\*\s*1000000000(\.0)?\M', '*oyun.pazar_tl_milyar()', 'g');
    e := regexp_replace(e, '/\s*1000000(\.0)?\M', '/oyun.pazar_tl_milyar()', 'g');
    if e <> d then execute e; end if;
  end loop;
end $$;

-- 4) Milli Piyango: gerçek usul — ikramiye bilet hasılatından, devir eden büyük ikramiye, amorti
--    Bilet 1.000 ₺: %50 ikramiye havuzu, %10 amorti, %40 hazine. Büyük ikramiye son 3 hane (1/1000);
--    kimse tutturamazsa ikramiye devreder. Son hane tutan bilet bedelini (amorti) geri alır.
--    Yeni dönem tabanı 100.000 ₺ (hazineden).
create or replace function oyun.piyango_guncelle()
 returns bigint language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare
 t timestamptz:=now(); bas timestamptz; curid bigint;
 prev record; winning integer; first_winner uuid; cnt int; per_ticket numeric;
 b record; roll numeric; taban numeric:=100000;
begin
 perform pg_advisory_xact_lock(77890011);
 bas:=timestamptz '2026-10-08 00:00:00+00'+floor(extract(epoch from (t-timestamptz '2026-10-08 00:00:00+00'))/604800)*interval '7 days';
 for prev in select * from oyun.piyango_donem where bitis<=t and not cekildi order by baslangic for update loop
   winning:=floor(random()*1000000)::int;
   select count(*) into cnt from oyun.piyango_bilet
     where donem_id=prev.id and mod(numara,1000)=mod(winning,1000);
   per_ticket:=case when cnt>0 then trunc(prev.ikramiye/cnt,0) else 0 end;
   first_winner:=null;
   if cnt>0 then
     for b in select id,user_id from oyun.piyango_bilet
       where donem_id=prev.id and mod(numara,1000)=mod(winning,1000) order by id loop
       insert into oyun.piyango_odul(bilet_id,donem_id,user_id,tutar)
         values(b.id,prev.id,b.user_id,per_ticket) on conflict do nothing;
       if found and per_ticket>0 then
         perform oyun.para_islem(b.user_id,per_ticket,'piyango','Milli Piyango büyük ikramiyesi',t);
         perform oyun.bildir(b.user_id, format('Milli Piyango büyük ikramiyesi sana çıktı: %s ₺!', oyun.tl(per_ticket)), t);
       end if;
       first_winner:=coalesce(first_winner,b.user_id);
     end loop;
     perform oyun.olay('ekonomi', format('Milli Piyango çekildi: büyük ikramiye %s ₺, %s bilete çıktı (son üç hane %s).',
        oyun.tl(prev.ikramiye), cnt, lpad(mod(winning,1000)::text,3,'0')), null, null, t);
   else
     perform oyun.olay('ekonomi', format('Milli Piyango çekildi, büyük ikramiye kimseye çıkmadı: %s ₺ devretti (son üç hane %s).',
        oyun.tl(prev.ikramiye), lpad(mod(winning,1000)::text,3,'0')), null, null, t);
   end if;
   -- amorti: son hanesi tutan (büyük ikramiye almayan) biletlere bilet bedeli
   for b in select id,user_id,bedel from oyun.piyango_bilet
       where donem_id=prev.id and mod(numara,10)=mod(winning,10) and mod(numara,1000)<>mod(winning,1000) loop
     insert into oyun.piyango_odul(bilet_id,donem_id,user_id,tutar) values(b.id,prev.id,b.user_id,b.bedel) on conflict do nothing;
     if found then perform oyun.para_islem(b.user_id,b.bedel,'piyango','Milli Piyango amortisi',t); end if;
   end loop;
   update oyun.piyango_donem set cekildi=true,kazanan_no=winning,kazanan=first_winner,
     kazanan_adet=cnt,cekilis_at=t where id=prev.id;
 end loop;
 select id into curid from oyun.piyango_donem where baslangic=bas;
 if curid is null then
   select case when kazanan_adet=0 then ikramiye else null end
     into roll from oyun.piyango_donem where bitis<=bas order by bitis desc limit 1;
   if roll is null then
     roll := taban;
     update oyun.ulke set hazine=hazine-taban/oyun.pazar_tl_milyar() where id=1;
   end if;
   insert into oyun.piyango_donem(baslangic,bitis,ikramiye)
      values(bas,bas+interval '7 days',roll)
      on conflict(baslangic) do update set baslangic=excluded.baslangic returning id into curid;
 end if;
 return curid;
end $function$;

create or replace function public.piyango_bilet_al(p_adet integer default 1)
 returns jsonb language plpgsql security definer set search_path to 'oyun', 'public', 'pg_temp'
as $function$
declare u uuid:=auth.uid(); d bigint; k int;
begin
 if u is null or not exists(select 1 from oyun.profiller where id=u) then raise exception 'Profil gerekli'; end if;
 if p_adet is null or p_adet<1 or p_adet>10 then raise exception 'Bir işlemde 1-10 bilet alınabilir.'; end if;
 d:=oyun.piyango_guncelle();
 perform oyun.para_islem(u,-1000*p_adet,'piyango','Milli piyango biletleri',now());
 for k in 1..p_adet loop
   insert into oyun.piyango_bilet(donem_id,user_id,numara,bedel)
   values(d,u,floor(random()*1000000)::int,1000);
 end loop;
 -- %50 ikramiye havuzu, %10 amorti için ayrılır (ödenene kadar dolaşımdan çıkar), %40 hazine
 update oyun.piyango_donem set bilet_sayisi=bilet_sayisi+p_adet,ikramiye=ikramiye+500*p_adet where id=d;
 update oyun.ulke set hazine=hazine+(400*p_adet)/oyun.pazar_tl_milyar() where id=1;
 return public.piyango_durum();
end $function$;

-- Açık dönemin ikramiyesi eski kuralla 1.000.000 tabanından başladı; yeni tabana çekilir (bir kez).
do $$
begin
  if exists(select 1 from oyun.ekonomi3_kayit where kod='piyango_taban') then return; end if;
  update oyun.piyango_donem set ikramiye = 100000 + bilet_sayisi*500 where not cekildi;
  insert into oyun.ekonomi3_kayit(kod,deger) values('piyango_taban',1);
end $$;

-- 5) Zamanlanmış işleri aynı dakikaya yığılmayacak şekilde kaydır (job startup timeout azalır)
do $$
declare r record;
begin
  if not exists(select 1 from pg_namespace where nspname='cron') then return; end if;
  for r in select * from (values
      ('belediye-hizmet-ihale','1-59/5'), ('meclis-arastirma','2-59/5'), ('siyasi-kurumlar','3-59/5'),
      ('turkiye-gundem-otomatik-gazete','4-59/5'), ('yuksek-mahkeme','0-59/5'),
      ('ekonomi-pazar','5-59/10'), ('eko_otomatik_uretim_kendi_tedarik','6-59/10'), ('uc-etkinlik-bitir','7-59/10'),
      ('eko-ticaret-periyodik','8-59/10'), ('ekonomi-2','9-59/10'), ('uc-kitap-satis','3-59/10'),
      ('gun-sonu','11-59/15'), ('belediye-sehir-bina-tick','13,43 * * * *'), ('bos-makam-firsat','17,47 * * * *'),
      ('ulke_krizi_sure_20261010','19 * * * *')) v(ad, sch)
  loop
    perform cron.alter_job(j.jobid, schedule := case when r.sch like '% %' then r.sch else r.sch||' * * * *' end)
      from cron.job j where j.jobname = r.ad;
  end loop;
end $$;

commit;
