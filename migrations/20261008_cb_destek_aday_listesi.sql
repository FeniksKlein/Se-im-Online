create or replace function public.cb_destek_secenekleri()
returns jsonb language plpgsql security definer set search_path='' as $f$
declare u uuid:=auth.uid(); s oyun.secimler; p oyun.profiller;
 t timestamptz:=oyun.simdi();
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 select * into p from oyun.profiller where id=u;
 select * into s from oyun.secimler where tur='cb' and durum='bekliyor'
  and basvuru_bas<=t and basvuru_bit>t
 order by ara desc,basvuru_bit limit 1;
 return jsonb_build_object('secim_id',s.id,
  'secenekler',coalesce((select jsonb_agg(jsonb_build_object(
     'parti_id',a.parti_id,'parti',pa.ad,'kisa',pa.kisa,'aday',pr.kad,
     'ittifak_ortagi',exists(select 1 from oyun.ittifak_uyeler x
      join oyun.ittifak_uyeler y on y.ittifak_id=x.ittifak_id
      where x.parti_id=p.parti_id and y.parti_id=a.parti_id))
     order by pa.kisa,pr.kad)
   from oyun.adaylar a join oyun.partiler pa on pa.id=a.parti_id and not pa.kapali
   join oyun.profiller pr on pr.id=a.user_id
   where a.secim_id=s.id and a.parti_id is not null and a.parti_id<>p.parti_id
     and not exists(select 1 from oyun.cb_kararlar k where k.donem=s.donem
       and k.parti_id=a.parti_id and k.yontem='destek')
  ),'[]'::jsonb));
end $f$;
revoke all on function public.cb_destek_secenekleri() from public,anon;
grant execute on function public.cb_destek_secenekleri() to authenticated;
