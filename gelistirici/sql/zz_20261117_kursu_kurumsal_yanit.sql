-- 17.11.2026: Kurumsal Kürsü kimliğiyle yanıt ve alıntı yapma.
create or replace function public.kursu_kurumsal_ilisik_yaz(
  p_metin text, p_tur text, p_kimlik text, p_islem text, p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $kurum$
declare
  p oyun.profiller := oyun.profilim();
  yetki record;
  sonuc jsonb;
  yeni_id bigint;
begin
  if coalesce(p_islem,'') not in ('yanit','alinti') then
    raise exception 'Geçersiz kurumsal paylaşım türü.';
  end if;
  select * into yetki from oyun.kursu_kurum_yetkileri(p.id) y
  where y.tur=p_tur and y.kimlik=p_kimlik limit 1;
  if not found then raise exception 'Bu kurum adına paylaşım yapma yetkin yok veya görevin sona ermiş.'; end if;

  if p_islem='yanit' then
    sonuc := public.akis_yanit_yaz(p_id,p_metin);
  else
    sonuc := public.kursu_alinti(p_id,p_metin);
  end if;
  yeni_id := (sonuc->>'id')::bigint;
  update oyun.akis a
    set kurum_tur=yetki.tur,
        kurum_id=yetki.kimlik,
        kurum_ad=yetki.ad,
        kurum_rol=yetki.rol,
        parti_id=case when yetki.tur='parti' then yetki.kimlik::bigint else a.parti_id end,
        il_id=case when yetki.tur='belediye' then yetki.kimlik::smallint else a.il_id end
  where a.id=yeni_id and a.user_id=p.id;
  if not found then raise exception 'Kurumsal paylaşım kaydedilemedi.'; end if;
  return sonuc || jsonb_build_object('kurum', yetki.ad);
end $kurum$;

-- Alıntılanan gönderide de kurumun gerçek adı ve yetkili imzası görünür.
create or replace function oyun.kursu_alinti_json(p_id bigint)
returns jsonb language sql stable set search_path = '' as $kurum$
  select jsonb_build_object(
    'id',a.id,'kad',pr.kad,'unvan',oyun.unvan(a.user_id),
    'parti',oyun.parti_json(a.parti_id),
    'kurum',case when a.kurum_tur is not null then jsonb_build_object(
      'tur',a.kurum_tur,'kimlik',a.kurum_id,'ad',a.kurum_ad,'rol',a.kurum_rol) else null end,
    'metin',a.metin,'zaman',a.zaman)
  from oyun.akis a join oyun.profiller pr on pr.id=a.user_id
  where a.id=p_id and not a.gizli
$kurum$;

revoke all on function public.kursu_kurumsal_ilisik_yaz(text,text,text,text,bigint)
from public, anon;
grant execute on function public.kursu_kurumsal_ilisik_yaz(text,text,text,text,bigint)
to authenticated;
