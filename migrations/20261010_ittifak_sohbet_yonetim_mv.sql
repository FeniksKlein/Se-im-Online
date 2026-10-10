-- 2026-10-10 | İttifak sohbeti: yönetim, il başkanları ve milletvekilleri
-- Normal üyelerin mesaj okuması/yazması engellenir; mevcut mesajlar korunur.
begin;

CREATE OR REPLACE FUNCTION oyun.kanal_coz(p oyun.profiller, p_kanal text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  return case p_kanal
    when 'genel' then 'genel'
    when 'il' then 'il:' || p.il_id
    when 'belediye' then 'belediye:' || p.il_id
    when 'parti' then case when p.parti_id is null then null else 'parti:' || p.parti_id end
    when 'meclis' then 'meclis'
    when 'ittifak' then (
      select 'ittifak:' || u.ittifak_id
      from oyun.ittifak_uyeler u
      join oyun.partiler pa on pa.id = u.parti_id
      where u.parti_id = p.parti_id
        and not pa.kapali
        and (
          pa.gb = p.id
          or exists (
            select 1 from oyun.parti_gby g
            where g.parti_id = pa.id and g.user_id = p.id
          )
          or exists (
            select 1 from oyun.parti_teskilat_gorev tg
            where tg.parti_id = pa.id and tg.user_id = p.id and tg.aktif
          )
          or exists (
            select 1 from oyun.makamlar m
            where m.user_id = p.id and m.tur = 'mv' and m.bit is null
          )
        )
    )
    when 'kabine' then case when exists (
      select 1 from oyun.makamlar
      where user_id = p.id and bit is null and tur in ('cb','bakan')
    ) then 'kabine' end
    when 'grup' then case
      when oyun.aktif_mv_parti(p.id) is not null then 'grup:' || oyun.aktif_mv_parti(p.id)
      when exists (
        select 1 from oyun.partiler pa where pa.gb = p.id and pa.id = p.parti_id
      ) then 'grup:' || p.parti_id end
    when 'divan' then case when exists (
      select 1 from oyun.makamlar
      where user_id = p.id and bit is null and tur in ('tbmm','bskv','grup_bskv')
    ) then 'divan' end
    when 'yonetim' then (
      select 'yonetim:' || pa.id from oyun.partiler pa
      where pa.id = p.parti_id and not pa.kapali
        and (pa.gb = p.id or exists (
          select 1 from oyun.parti_gby g
          where g.parti_id = pa.id and g.user_id = p.id
        ))
    )
    else null end;
end $function$

CREATE OR REPLACE FUNCTION oyun.kanal_hata(kod text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select case kod
    when 'ittifak' then 'İttifak sohbetine yalnızca üye partilerin genel başkanları, yönetimi, il başkanları ve milletvekilleri girebilir.'
    when 'kabine' then 'Bakanlar Kurulu sohbetine yalnızca cumhurbaşkanı ve bakanlar girebilir.'
    when 'yonetim' then 'Parti yönetimi sohbetine yalnızca genel başkan ve genel başkan yardımcıları girebilir.'
    when 'grup' then 'Meclis grubu sohbetine yalnızca partinin milletvekilleri ve genel başkanı girebilir.'
    when 'divan' then 'Başkanlık Divanı sohbetine TBMM Başkanı, başkanvekilleri ve grup başkanvekilleri girebilir.'
    else 'Parti sohbeti için bir partiye üye olmalısın.' end
$function$

commit;
