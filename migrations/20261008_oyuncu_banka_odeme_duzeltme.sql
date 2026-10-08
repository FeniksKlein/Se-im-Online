-- Eski 7 gunluk ve yeni saatlik mevduatlari ayni odeme mantigi ile tahsil et.
-- Banka satiri daima mevduat satirindan once kilitlenir. Cuzdan tam TL calisir.
create or replace function public.banka_mevduat_tahsil()
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();t timestamptz:=oyun.simdi(); b record; m oyun.banka_mevduat; odeme numeric;
begin
 if u is null then raise exception 'Oturum gerekli';end if;
 for b in select distinct banka_id from oyun.banka_mevduat
   where user_id=u and not kapandi and vade<=t order by banka_id loop
  perform 1 from oyun.sirketler where id=b.banka_id for update;
  for m in select * from oyun.banka_mevduat
    where banka_id=b.banka_id and user_id=u and not kapandi and vade<=t
    order by vade,id for update loop
    odeme:=round(m.anapara*(1+m.faiz/100));
    update oyun.sirketler set kasa=kasa-odeme
      where id=m.banka_id and kasa>=odeme;
    if found then
      perform oyun.para_islem(u,odeme,'mevduat',
        'Oyuncu bankasi vadeli mevduat ve faiz odemesi',t);
      update oyun.banka_mevduat set kapandi=true where id=m.id;
    end if;
  end loop;
 end loop;
 return jsonb_build_object('mevduatlar',coalesce((
  select jsonb_agg(jsonb_build_object('id',id,'banka',banka_id,
   'tutar',anapara,'faiz',faiz,'vade',vade,'odendi',kapandi,'iptal',iptal,
   'durum',case when iptal then 'anapara_iade' when kapandi then 'odendi'
    when vade<=t then 'banka_odeme_bekliyor' else 'vadede' end)
   order by id desc)
  from oyun.banka_mevduat where user_id=u),'[]'::jsonb));
end $$;
revoke all on function public.banka_mevduat_tahsil() from public,anon;
grant execute on function public.banka_mevduat_tahsil() to authenticated;
