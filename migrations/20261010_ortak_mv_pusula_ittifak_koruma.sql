-- Ortak MV listesi: sandık görünürlüğü ve ittifaktan ayrılınca geçersiz kılma.
create or replace function public.mv_ortak_liste_gorunum(p_secim bigint,p_il int)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',x.id,'lider_parti',x.lider_parti,'parti1',x.teklif_eden_parti,'parti2',x.ortak_parti,
  'lider', (select kisa from oyun.partiler where id=x.lider_parti),
  'ortaklar', (select string_agg(kisa,' + ' order by id) from oyun.partiler where id in(x.teklif_eden_parti,x.ortak_parti))
 ) order by x.id), '[]'::jsonb)
 from oyun.mv_ortak_listeler x
 where x.secim_id=p_secim and x.il_id=p_il and x.durum='kabul'
$$;
create or replace function oyun.mv_ortak_liste_ittifak_temizle()
returns trigger language plpgsql set search_path='' as $$
begin
 update oyun.mv_ortak_listeler x set durum='iptal',karar_at=oyun.simdi()
 where x.durum in('bekliyor','kabul')
  and old.parti_id in(x.teklif_eden_parti,x.ortak_parti)
  and exists(select 1 from oyun.secimler s where s.id=x.secim_id and s.durum='bekliyor' and s.oy_bas>oyun.simdi());
 return old;
end $$;
drop trigger if exists mv_ortak_liste_ittifak_temizle on oyun.ittifak_uyeler;
create trigger mv_ortak_liste_ittifak_temizle after delete on oyun.ittifak_uyeler
for each row execute function oyun.mv_ortak_liste_ittifak_temizle();
revoke all on function public.mv_ortak_liste_gorunum(bigint,int) from public,anon;
grant execute on function public.mv_ortak_liste_gorunum(bigint,int) to authenticated;
revoke all on function oyun.mv_ortak_liste_ittifak_temizle() from public,anon,authenticated;