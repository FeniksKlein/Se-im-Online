-- Parti amblemi: yalnızca yetkili parti genel başkanı değiştirebilir.
-- Önceden kaydedilmiş parti amblemlerine, adaylara, ücretlere veya seçimlere dokunulmaz.
create table if not exists oyun.parti_amblem_gecmis(
 id bigint generated always as identity primary key,
 parti_id bigint not null references oyun.partiler(id),
 eski_amblem text not null,
 yeni_amblem text not null,
 degistiren uuid not null references auth.users(id),
 zaman timestamptz not null default now()
);
create index if not exists parti_amblem_gecmis_parti_idx on oyun.parti_amblem_gecmis(parti_id,zaman desc);
alter table oyun.parti_amblem_gecmis enable row level security;
revoke all on oyun.parti_amblem_gecmis from public,anon,authenticated;

create or replace function public.parti_amblem_degistir(p_amblem text)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare v_u uuid:=auth.uid(); v_p oyun.partiler; v_t timestamptz:=oyun.simdi();
begin
 if v_u is null then raise exception 'Oturum açmalısın';end if;
 select * into v_p from oyun.partiler
 where gb=v_u and not kapali for update;
 if not found then raise exception 'Amblemi yalnızca görevdeki parti genel başkanı değiştirebilir';end if;
 if p_amblem is null or p_amblem <> all (array['a_ayyildiz','a_yildiz','a_hilal','a_ucok','a_gul','a_lale','a_cinar','a_basak','a_gunes','a_dogangunes','a_mesale','a_kartal','a_kurt','a_aslan','a_at','a_boga','a_guvercin','a_yilan','a_ari','a_elma','a_anahtar','a_terazi','a_kalkan','a_cark','a_capa','a_dag','a_el','a_yildirim'])
 then raise exception 'Geçersiz parti amblemi seçimi';end if;
 if p_amblem=v_p.amblem then raise exception 'Parti zaten bu amblemi kullanıyor';end if;
 insert into oyun.parti_amblem_gecmis(parti_id,eski_amblem,yeni_amblem,degistiren,zaman)
 values(v_p.id,v_p.amblem,p_amblem,v_u,v_t);
 update oyun.partiler set amblem=p_amblem where id=v_p.id;
 perform oyun.olay('parti',v_p.kisa||' parti amblemini değiştirdi',null,v_p.id,v_t);
 return public.parti_detay(v_p.id);
end $f$;
revoke all on function public.parti_amblem_degistir(text) from public,anon;
grant execute on function public.parti_amblem_degistir(text) to authenticated;

-- Önceden çalışan aday ücretlendirmesinin net TL karşılığı: mevcut
-- çarpan (0–3) ve ilgili oyuncunun ili dikkate alınır.
-- Ücret değiştirme yetkisini mevcut public.parti_ucret_ayarla RPC'si denetler.
create or replace function public.parti_ucret_tarife(p_parti bigint)
returns jsonb language plpgsql security definer set search_path='' as $f$
declare v_uid uuid:=auth.uid();v_p oyun.partiler;v_il smallint;
 v_endeks numeric;v_katsayi numeric;
begin
 if v_uid is null then raise exception 'Oturum açmalısın';end if;
 select * into v_p from oyun.partiler where id=p_parti and not kapali;
 if not found then raise exception 'Parti bulunamadı';end if;
 select il_id into v_il from oyun.profiller where id=v_uid;
 select endeks into v_endeks from oyun.ulke where id=1;
 select case when mv>=14 then 3 when mv>=8 then 2 else 1 end
 into v_katsayi from oyun.iller where id=v_il;
 return jsonb_build_object('parti_id',v_p.id,'genel_baskan_miyim',v_p.gb=v_uid,
 'il', (select ad from oyun.iller where id=v_il),
 'carpanlar',v_p.aday_ucret,
 'taban',jsonb_build_object(
  'mv_on',round(5000*v_endeks),
  'bel_on',round(3000*v_endeks*coalesce(v_katsayi,1)),
  'cb_on',round(20000*v_endeks),
  'kurultay',round(10000*v_endeks)),
 'guncel',jsonb_build_object(
  'mv_on',oyun.aday_ucreti(v_p.id,'mv_on',v_il),
  'bel_on',oyun.aday_ucreti(v_p.id,'bel_on',v_il),
  'cb_on',oyun.aday_ucreti(v_p.id,'cb_on',v_il),
  'kurultay',oyun.aday_ucreti(v_p.id,'kurultay',v_il)));
end $f$;
revoke all on function public.parti_ucret_tarife(bigint) from public,anon;
grant execute on function public.parti_ucret_tarife(bigint) to authenticated;
