
-- Cumhurbaşkanına özel aday araması; Başbakan yetkisine bağlı bakan aramasından bağımsız.
create or replace function public.cb_yardimcisi_adaylari(p_ara text default '')
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare p oyun.profiller:=oyun.profilim(); a text:=lower(btrim(coalesce(p_ara,'')));
begin
 perform oyun.cb_yardimcisi_yetkili(p);
 return coalesce((select jsonb_agg(x) from (
   select jsonb_build_object(
    'kad',pr.kad,
    'il',(select ad from oyun.iller where id=pr.il_id),
    'parti',oyun.parti_json(pr.parti_id),
    'statu',oyun.statu_ad(oyun.statu_basamak(oyun.kidem_puani(pr.id))),
    'bakanlik',(select b.ad from oyun.makamlar m join oyun.bakanliklar b on b.kod=m.bakanlik
      where m.user_id=pr.id and m.tur='bakan' and m.bit is null limit 1),
    'uygun',not exists(select 1 from oyun.makamlar m where m.user_id=pr.id and m.tur in ('cb','cb_yardimcisi') and m.bit is null)
       and not exists(select 1 from oyun.cb_yardimcisi_teklifleri v where v.aday=pr.id and v.durum='bekliyor'),
    'engel',case when exists(select 1 from oyun.makamlar m where m.user_id=pr.id and m.tur in ('cb','cb_yardimcisi') and m.bit is null)
       then 'Bu oyuncu cumhurbaşkanı veya yardımcısı' when exists(select 1 from oyun.cb_yardimcisi_teklifleri v where v.aday=pr.id and v.durum='bekliyor')
       then 'Zaten bekleyen bir teklifi var' else null end
   ) x
   from oyun.profiller pr
   where not pr.yasakli
   and (a='' or lower(pr.kad) like a||'%' or lower(pr.kad) like '%'||a||'%')
   order by (lower(pr.kad) like a||'%') desc, pr.son_gorulme desc nulls last
   limit 25
 ) q), '[]'::jsonb);
end $fn$;
revoke execute on function public.cb_yardimcisi_adaylari(text) from public,anon;
grant execute on function public.cb_yardimcisi_adaylari(text) to authenticated;
