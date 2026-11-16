-- 16.11.2026 · Kurucu dört parti ve ilk genel başkan seçimi
-- Oyun sıfırlanıp kurulum dosyası çalıştırıldığında oyun dört hazır partiyle başlar:
--   Halk Partisi (HP), Sosyal Demokrasi Partisi (SDP), Yeni Parti (YENİ), Muhafazakâr Türkiye Partisi (MTP).
-- Yeni parti kurmak başlangıçta kapalıdır (hesap yaşı ve statü şartı), oyuncular bu partilere üye olur.
-- İlk hafta partiler lidersizdir: kimse kendiliğinden ya da vekâleten genel başkan olmaz.
-- Genel başkanı üyeler seçer: aday başvurusu oyunun açılışından itibaren açıktır; oy verme 5. gün
-- 08:00-22:00 arasındadır; oy kullanmak için en geç 4. gün sonunda partiye üye olmak gerekir.
-- Seçilen genel başkan ilk hafta dolunca (8. günün başında) göreve başlar.
-- Canlı oyunda (oyuncu varken) bu dosya hiçbir partiyi, üyeyi ya da seçimi değiştirmez.

insert into oyun.tarife(kod,deger,birim,kategori,ad,aciklama,sira) values
 ('kurucu_gb_oy_gun',5,'gun','siyaset','Kurucu partilerde GB seçim günü','Oyun açılışından kaç gün sonra kurucu partilerde üyelerin genel başkanı seçeceği.',580),
 ('kurucu_gb_goreve_gun',8,'gun','siyaset','Kurucu partilerde GB göreve başlama günü','Seçilen genel başkanın göreve başladığı gün (ilk hafta lidersiz).',581)
on conflict (kod) do nothing;

create or replace function oyun.kurucu_kurultay_mi(s oyun.secimler)
returns boolean language sql immutable set search_path to '' as $$
  select s.tur='kurultay' and coalesce(s.ara_neden,'') in ('kurucu_ilk_kurultay','lansman_ilk_kurultay')
$$;

-- Parti kuruluş haftasında mı? (açık kurucu kurultayı ya da henüz başlamamış göreve başlama)
create or replace function oyun.kurucu_lidersiz_donem(p_parti bigint)
returns boolean language sql stable set search_path to '' as $$
  select exists(select 1 from oyun.secimler s
                 where s.tur='kurultay' and s.hedef_parti_id=p_parti and s.durum<>'tamam'
                   and coalesce(s.ara_neden,'') in ('kurucu_ilk_kurultay','lansman_ilk_kurultay'))
$$;

-- Kurucu kurultayları kur (idempotent). p_bas: oyunun açılış anı.
create or replace function oyun.kurucu_parti_kurultay_kur(p_bas timestamptz)
returns integer language plpgsql security definer set search_path to '' as $$
declare d date := (p_bas at time zone 'Europe/Istanbul')::date; pa record; n int := 0; dm text;
  oy int := coalesce((select deger from oyun.tarife where kod='kurucu_gb_oy_gun'),5)::int;
  gor int := coalesce((select deger from oyun.tarife where kod='kurucu_gb_goreve_gun'),8)::int;
begin
  perform set_config('oyun.takvim_kurali','1',true);
  for pa in select id from oyun.partiler where sistem and not kapali and gb is null order by id loop
    continue when exists(select 1 from oyun.secimler s where s.tur='kurultay' and s.hedef_parti_id=pa.id
                          and coalesce(s.ara_neden,'') in ('kurucu_ilk_kurultay','lansman_ilk_kurultay'));
    dm := 'kurucu-gb-'||pa.id||'-'||to_char(d,'YYYYMMDD');
    insert into oyun.secim_takvim_istisna(donem,neden,onaylayan)
    values(dm,'Kurucu partilerde ilk genel başkan seçimi: oy '||oy||'. gün, göreve başlama '||gor||'. gün (ilk hafta lidersiz)','Oyun sahibi (2026-11-16 kararı)')
    on conflict(donem) do nothing;
    insert into oyun.secimler(tur,donem,basvuru_bas,basvuru_bit,oy_bas,oy_bit,sonuc_at,goreve_bas,ara,hedef_parti_id,ara_neden)
    values('kurultay',dm,p_bas,oyun.tr_an(d+oy,8),oyun.tr_an(d+oy,8),oyun.tr_an(d+oy,22),oyun.tr_an(d+oy,22,30),
           oyun.tr_an(d+gor,0),true,pa.id,'kurucu_ilk_kurultay');
    n := n + 1;
  end loop;
  perform set_config('oyun.takvim_kurali','',true);
  return n;
end $$;
revoke all on function oyun.kurucu_parti_kurultay_kur(timestamptz) from public, anon, authenticated;

-- Kuruluş haftasında üyelik kesimi: oy gününden 24 saat önce (4. gün sonu)
do $p$
declare s text := pg_get_functiondef('oyun.onsecim_uyelik_kesim(oyun.secimler,bigint)'::regprocedure);
begin
  if position('kurucu_kurultay_mi' in s)=0 then
    s := replace(s, $x$    select case when s.tur in ('mv_on','cb_on','bel_on')$x$,
      $x$    select case when oyun.kurucu_kurultay_mi(s) then s.oy_bas - interval '24 hours'
                when s.tur in ('mv_on','cb_on','bel_on')$x$);
    if position('kurucu_kurultay_mi' in s)=0 then raise exception 'onsecim_uyelik_kesim yaması uygulanamadı'; end if;
    execute s;
  end if;
end $p$;

-- Kuruluş haftasında tek üyeli parti ya da vekâlet yoluyla kendiliğinden genel başkan olunmaz
do $p$
declare s text;
begin
  s := pg_get_functiondef('oyun.tek_uye_genel_baskan_duzelt(bigint)'::regprocedure);
  if position('kurucu_lidersiz_donem' in s)=0 then
    s := replace(s, $x$  if pa.id is null or pa.kapali then return; end if;$x$,
      $x$  if pa.id is null or pa.kapali then return; end if;
  -- Kurucu partiler ilk hafta lidersizdir; genel başkanı üyeler kurultayda seçer.
  if oyun.kurucu_lidersiz_donem(p_parti) then return; end if;$x$);
    if position('kurucu_lidersiz_donem' in s)=0 then raise exception 'tek_uye_genel_baskan_duzelt yaması uygulanamadı'; end if;
    execute s;
  end if;
  s := pg_get_functiondef('oyun.gb_vekil_otomatik(bigint,uuid,timestamptz)'::regprocedure);
  if position('kurucu_lidersiz_donem' in s)=0 then
    s := replace(s, $x$ if pa.id is null or pa.gb is not null then return null; end if;$x$,
      $x$ if pa.id is null or pa.gb is not null then return null; end if;
 if oyun.kurucu_lidersiz_donem(pa.id) then return null; end if;$x$);
    if position('kurucu_lidersiz_donem' in s)=0 then raise exception 'gb_vekil_otomatik yaması uygulanamadı'; end if;
    execute s;
  end if;
end $p$;

-- Kurucu kurultay aday çıkmadan biterse: lidersiz kalan kurucu partide yeni kurultay açılır
create or replace function oyun.kurucu_parti_gb_tick()
returns integer language plpgsql security definer set search_path to '' as $$
declare pa record; n int := 0; t timestamptz := oyun.simdi();
begin
  for pa in select p.id from oyun.partiler p
     where p.sistem and not p.kapali and p.gb is null
       and not oyun.kurucu_lidersiz_donem(p.id)
       and exists(select 1 from oyun.profiller x where x.parti_id=p.id and not coalesce(x.yasakli,false))
       and not exists(select 1 from oyun.secimler s where s.tur='kurultay' and s.durum<>'tamam' and (s.hedef_parti_id=p.id or not s.ara))
     limit 20 loop
    begin
      perform oyun.ara_secim_olustur('gb', pa.id, null, t);
      perform oyun.bildir(x.id, 'Partinde genel başkan seçilemedi; yeni kurultay açıldı. Aday olabilir, oy kullanabilirsin.', t)
        from oyun.profiller x where x.parti_id=pa.id and not coalesce(x.yasakli,false);
      n := n + 1;
    exception when others then raise warning 'kurucu_parti_gb_tick %: %', pa.id, sqlerrm;
    end;
  end loop;
  return n;
end $$;
revoke all on function oyun.kurucu_parti_gb_tick() from public, anon, authenticated;
insert into oyun.zamanlayici_adim(adim,komut,periyot_dk,ofset_dk,sira,aktif)
values('kurucu_parti_gb','select oyun.kurucu_parti_gb_tick()',60,23,126,true)
on conflict (adim) do update set komut=excluded.komut, periyot_dk=excluded.periyot_dk, aktif=true;

-- YENİ OYUN: sıfırlama sonrası kurulumda (hiç oyuncu yokken) dört kurucu parti ve kurultaylar.
-- Canlı oyunda (oyuncu varken) hiçbir şey yapmaz.
do $k$
declare bas timestamptz := oyun.simdi(); i record;
begin
  if exists(select 1 from oyun.profiller) then return; end if;
  -- Eski kurulumlardan kalan 5 sistem partisini dört kurucu partiye indir (yeni oyunda boşturlar)
  if (select count(*) from oyun.partiler where sistem) <> 4
     or exists(select 1 from oyun.partiler where sistem and kisa not in ('HP','SDP','YENİ','MTP')) then
    perform set_config('oyun.sifirlama','evet',true);
    delete from oyun.parti_teskilat where parti_id in (select id from oyun.partiler where sistem);
    delete from oyun.partiler where sistem and not exists(select 1 from oyun.profiller x where x.parti_id=partiler.id);
    insert into oyun.partiler(ad,kisa,renk,amblem,sistem,kurulus)
    select v.ad,v.kisa,v.renk,v.amblem,true,bas from (values
      ('Halk Partisi','HP','#c62828','a_ayyildiz'),
      ('Sosyal Demokrasi Partisi','SDP','#1565c0','a_guvercin'),
      ('Yeni Parti','YENİ','#ef8f00','a_basak'),
      ('Muhafazakâr Türkiye Partisi','MTP','#2e7d32','a_cinar')) v(ad,kisa,renk,amblem)
    where not exists(select 1 from oyun.partiler x where x.kisa=v.kisa and not x.kapali);
  end if;
  update oyun.partiler set gb=null, kurucu=null, gb_vekil=null, gb_vekil_bas=null, kurulus=bas, kurulus_bit=null
   where sistem and not kapali;
  insert into oyun.parti_teskilat(parti_id,il_id,kurulus,kuran,bedel,genel_merkez)
  select pa.id, il.id, bas, null, 0, il.id = 6 from oyun.partiler pa cross join oyun.iller il
   where pa.sistem and not pa.kapali
  on conflict (parti_id,il_id) do nothing;
  perform oyun.kurucu_parti_kurultay_kur(bas);
end $k$;
