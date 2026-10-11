-- 2026-10-11 | Oyuncular arasi sirket hissesi satis pazari.
-- Var olan ortakliklari, ilanlari, oyuncu bakiyelerini ve secimleri degistirmez.
begin;

create table if not exists oyun.sirket_hisse_ilanlari (
  id bigint generated always as identity primary key,
  sirket_id bigint not null references oyun.sirketler(id),
  satici uuid not null references auth.users(id),
  pay numeric not null check (pay > 0 and pay <= 100 and pay = round(pay, 6)),
  bedel numeric not null check (bedel >= 100 and bedel <= 1000000000 and bedel = round(bedel)),
  durum text not null default 'acik' check (durum in ('acik','satildi','iptal')),
  olusturma timestamptz not null default now(),
  kapanis timestamptz,
  alici uuid references auth.users(id)
);
create unique index if not exists sirket_hisse_tek_acik on oyun.sirket_hisse_ilanlari(sirket_id,satici) where durum='acik';
create index if not exists sirket_hisse_pazar_acik on oyun.sirket_hisse_ilanlari(olusturma desc) where durum='acik';
create index if not exists sirket_hisse_satici on oyun.sirket_hisse_ilanlari(satici,olusturma desc);
alter table oyun.sirket_hisse_ilanlari enable row level security;
revoke all on oyun.sirket_hisse_ilanlari from public,anon,authenticated;
revoke all on sequence oyun.sirket_hisse_ilanlari_id_seq from public,anon,authenticated;

do $$ begin
  if to_regprocedure('oyun.bosaltma_korumasi()') is not null then
    drop trigger if exists bosaltma_korumasi on oyun.sirket_hisse_ilanlari;
    create trigger bosaltma_korumasi before truncate on oyun.sirket_hisse_ilanlari
      for each statement execute function oyun.bosaltma_korumasi();
  end if;
end $$;

-- Ticaret gecmisine sirketin TAMAMI yerine kismi hisse devri de kaydedilebilir.
alter table oyun.ticaret_devir_kayit drop constraint if exists ticaret_devir_kayit_tur_check;
alter table oyun.ticaret_devir_kayit add constraint ticaret_devir_kayit_tur_check
  check (tur in ('mulk_devlet','sirket_tam','sirket_hisse'));

create or replace function public.sirket_hisse_pazar() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim();
begin
  return jsonb_build_object(
    'ilanlar', coalesce((select jsonb_agg(jsonb_build_object(
      'id', i.id, 'sirket_id',s.id, 'ad',s.ad, 'sektor',s.sektor,
      'satici', oyun.kad(i.satici), 'benim', i.satici=p.id,
      'pay',i.pay, 'bedel',i.bedel, 'zaman',i.olusturma
    ) order by i.olusturma desc)
    from oyun.sirket_hisse_ilanlari i
    join oyun.sirketler s on s.id=i.sirket_id and s.aktif
    join oyun.sirket_ortaklari o on o.sirket_id=i.sirket_id and o.user_id=i.satici
    where i.durum='acik' and o.pay >= i.pay), '[]'::jsonb),
    'benim', coalesce((select jsonb_agg(jsonb_build_object(
      'id',i.id, 'sirket_id',s.id, 'ad',s.ad,
      'pay',i.pay, 'bedel',i.bedel, 'durum',i.durum, 'zaman',i.olusturma
    ) order by i.olusturma desc)
    from oyun.sirket_hisse_ilanlari i join oyun.sirketler s on s.id=i.sirket_id
    where i.satici=p.id and i.durum='acik'), '[]'::jsonb),
    'cuzdan',coalesce((select para from oyun.cuzdan where user_id=p.id),0)
  );
end $$;

create or replace function public.sirket_hisse_ilan_ver(p_sirket bigint,p_pay numeric,p_bedel numeric)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); s oyun.sirketler; v_pay numeric; v_id bigint; v_borsa numeric := 0;
begin
  if p_pay is null or p_pay<=0 or p_pay>100 or p_pay<>round(p_pay,6) then
    raise exception 'Satilacak pay 0 ile 100 arasinda, en fazla 6 ondalikli olmali.';
  end if;
  if p_bedel is null or p_bedel<100 or p_bedel>1000000000 or p_bedel<>round(p_bedel) then
    raise exception 'Satis bedeli 100 ile 1.000.000.000 TL arasinda tam sayi olmali.';
  end if;
  perform pg_advisory_xact_lock(98763,hashtext(p_sirket::text));
  select * into s from oyun.sirketler where id=p_sirket for update;
  if s.id is null or not s.aktif or s.sektor='banka' then
    raise exception 'Sadece faal sirketlerinin hisselerini satabilirsin.';
  end if;
  select pay into v_pay from oyun.sirket_ortaklari where sirket_id=p_sirket and user_id=p.id for update;
  if v_pay is null or v_pay<p_pay then raise exception 'Sahip oldugun pay bu ilani karsilamiyor.'; end if;
  if exists(select 1 from oyun.sirket_hisse_ilanlari where sirket_id=p_sirket and satici=p.id and durum='acik') then
    raise exception 'Bu sirket icin acik hissen var. Once eski ilani kaldir.';
  end if;
  -- Borsa emri varsa ayni hisseler iki ayri pazarda birden vaat edilemez.
  if to_regclass('oyun.borsa_emir') is not null then
    execute 'select coalesce(sum(kalan),0) from oyun.borsa_emir where sirket_id=$1 and satici=$2 and durum=''acik'''
    into v_borsa using p_sirket,p.id;
  end if;
  if v_pay < p_pay + v_borsa then raise exception 'Borsadaki emirler dusuldugunde bu kadar payin kalmiyor.'; end if;
  -- Sirketin tamamini satma ilani ile hisse ilaninin cakismasini engelle.
  if s.satilik is not null then
    update oyun.sirketler set satilik=null where id=p_sirket;
  end if;
  insert into oyun.sirket_hisse_ilanlari(sirket_id,satici,pay,bedel)
  values (p_sirket,p.id,p_pay,p_bedel) returning id into v_id;
  return jsonb_build_object('tamam',true,'ilan_id',v_id);
end $$;

create or replace function public.sirket_hisse_ilan_iptal(p_ilan bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); i oyun.sirket_hisse_ilanlari;
begin
  select * into i from oyun.sirket_hisse_ilanlari where id=p_ilan;
  if i.id is null or i.satici<>p.id then raise exception 'Bu hisse ilani sana ait degil.'; end if;
  perform pg_advisory_xact_lock(98763,hashtext(i.sirket_id::text));
  select * into i from oyun.sirket_hisse_ilanlari where id=p_ilan for update;
  if i.durum<>'acik' then raise exception 'Bu ilan artik acik degil.'; end if;
  update oyun.sirket_hisse_ilanlari set durum='iptal',kapanis=oyun.simdi() where id=p_ilan;
  return jsonb_build_object('tamam',true);
end $$;

create or replace function public.sirket_hisse_ilan_al(p_ilan bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare p oyun.profiller := oyun.profilim(); i oyun.sirket_hisse_ilanlari;
        s oyun.sirketler; v_pay numeric; v_borsa numeric:=0; t timestamptz:=oyun.simdi();
begin
  select * into i from oyun.sirket_hisse_ilanlari where id=p_ilan;
  if i.id is null then raise exception 'Hisse ilani bulunamadi.'; end if;
  perform pg_advisory_xact_lock(98763,hashtext(i.sirket_id::text));
  select * into i from oyun.sirket_hisse_ilanlari where id=p_ilan for update;
  if i.durum<>'acik' then raise exception 'Bu ilan artik gecerli degil.'; end if;
  if i.satici=p.id then raise exception 'Kendi hissenin satin alimini yapamazsin.'; end if;
  select * into s from oyun.sirketler where id=i.sirket_id for update;
  if s.id is null or not s.aktif or s.sektor='banka' then raise exception 'Sirket satis icin faal degil.'; end if;
  -- Henuz hesaplanmamis kar once eski ortaklara yazilir.
  perform oyun.sirket_hesapla(i.sirket_id);
  if not exists (select 1 from oyun.sirketler where id=i.sirket_id and aktif) then
    raise exception 'Sirket artik faal degil.';
  end if;
  select pay into v_pay from oyun.sirket_ortaklari
  where sirket_id=i.sirket_id and user_id=i.satici for update;
  if to_regclass('oyun.borsa_emir') is not null then
    execute 'select coalesce(sum(kalan),0) from oyun.borsa_emir where sirket_id=$1 and satici=$2 and durum=''acik'''
    into v_borsa using i.sirket_id,i.satici;
  end if;
  if v_pay is null or v_pay < i.pay + v_borsa then
    raise exception 'Saticinin kullanilabilir hissesi yetersiz. Ilan guncellenmeli.';
  end if;
  perform oyun.para_islem(p.id,-i.bedel,'sirket',format('%s: %s hisse alimi (ilan #%s)',s.ad,i.pay,i.id),t);
  perform oyun.para_islem(i.satici,i.bedel,'sirket',format('%s: %s hisse satisi (ilan #%s)',s.ad,i.pay,i.id),t);
  -- %100 devrediliyorsa sifir payli ortak satiri olusturulmaz.
  if v_pay=i.pay then
    delete from oyun.sirket_ortaklari where sirket_id=i.sirket_id and user_id=i.satici;
  else
    update oyun.sirket_ortaklari set pay=pay-i.pay
      where sirket_id=i.sirket_id and user_id=i.satici;
  end if;
  insert into oyun.sirket_ortaklari(sirket_id,user_id,pay)
    values(i.sirket_id,p.id,i.pay)
    on conflict(sirket_id,user_id) do update set pay=oyun.sirket_ortaklari.pay+excluded.pay;
  update oyun.sirket_hisse_ilanlari set durum='satildi',alici=p.id,kapanis=t where id=i.id;
  update oyun.sirketler set satilik=null where id=i.sirket_id;
  -- Eski dogrudan tekliflerin ancak elde olmayan paylari devretmesini engelle.
  update oyun.sirket_teklif set durum='iptal' where sirket_id=i.sirket_id and satici=i.satici
    and durum='bekliyor' and pay > coalesce((select pay from oyun.sirket_ortaklari where sirket_id=i.sirket_id and user_id=i.satici),0);
  insert into oyun.ticaret_devir_kayit(tur,varlik_id,satici,alici,bedel,pay,zaman,aciklama)
    values('sirket_hisse',i.sirket_id,i.satici,p.id,i.bedel,i.pay,t,format('%s sirketinden %s pay devri',s.ad,i.pay));
  perform oyun.bildir(i.satici,format('%s sirketindeki %s hissen %s TL karsiliginda satildi.',s.ad,i.pay,oyun.tl(i.bedel)),t);
  perform oyun.bildir(p.id,format('%s sirketinden %s hisse aldin.',s.ad,i.pay),t);
  return jsonb_build_object('tamam',true,'sirket_id',i.sirket_id,'pay',i.pay,'bedel',i.bedel);
end $$;

revoke all on function public.sirket_hisse_pazar() from public,anon;
revoke all on function public.sirket_hisse_ilan_ver(bigint,numeric,numeric) from public,anon;
revoke all on function public.sirket_hisse_ilan_iptal(bigint) from public,anon;
revoke all on function public.sirket_hisse_ilan_al(bigint) from public,anon;
grant execute on function public.sirket_hisse_pazar() to authenticated;
grant execute on function public.sirket_hisse_ilan_ver(bigint,numeric,numeric) to authenticated;
grant execute on function public.sirket_hisse_ilan_iptal(bigint) to authenticated;
grant execute on function public.sirket_hisse_ilan_al(bigint) to authenticated;
commit;
