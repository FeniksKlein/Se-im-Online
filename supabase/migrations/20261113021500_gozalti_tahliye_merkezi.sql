-- 13.11.2026 · Gözaltı ve Avukat ekranı için CB / İçişleri Bakanı ortak listesi ve tek tahliye kapısı.
-- Erken tahliye yalnız Cumhurbaşkanı ve İçişleri Bakanı içindir; işlem mevcut işlevlere yönlenir.

create or replace function public.gozalti_yetkili_liste()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); t timestamptz:=oyun.simdi();
begin
  if u is null or not (oyun.cb_mi(u) or oyun.bm_yetki(u,'icisleri') is not null) then
    return jsonb_build_object('yetkili',false,'gozaltilar','[]'::jsonb);
  end if;
  return jsonb_build_object('yetkili',true,'kota',oyun.yonetim_gozalti_kota_bilgi(u),
    'gozaltilar',coalesce((select jsonb_agg((x.j - 'avukat' - 'yetkili' - 'hedef') || jsonb_build_object(
        'hedef_kad',oyun.kad((x.j->>'hedef')::uuid),'avukat_kad',oyun.kad((x.j->>'avukat')::uuid),'yetkili_kad',oyun.kad((x.j->>'yetkili')::uuid))
        order by (x.j->>'bitis')) from (
      select oyun.gozalti_dosya('sokak',s.id) j from oyun.sokak_gozalti s where s.durum='aktif' and s.bitis>t
      union all select oyun.gozalti_dosya('icisleri',k.id) from oyun.icisleri_tedbir_v2 k where k.tur='gozalti' and k.durum in ('onay','itiraz') and k.bitis>t
      union all select oyun.gozalti_dosya('yonetim',y.id) from oyun.yonetim_tutuklama y where y.durum='aktif' and y.bitis>t) x),'[]'::jsonb));
end $$;

create or replace function public.gozalti_tahliye(p_kaynak text, p_id bigint, p_gerekce text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); g text:=btrim(coalesce(p_gerekce,''));
begin
  if u is null or not (oyun.cb_mi(u) or oyun.bm_yetki(u,'icisleri') is not null) then
    raise exception 'Gözaltını süresinden önce yalnız Cumhurbaşkanı veya İçişleri Bakanı sonlandırabilir'; end if;
  if char_length(g) not between 10 and 500 then raise exception 'Tahliye gerekçesi 10–500 karakter olmalı'; end if;
  if p_kaynak='sokak' then return public.sokak_cb_serbest_birak(p_id, g);
  elsif p_kaynak='icisleri' then return public.cb_icisleri_gozalti_serbest(p_id, g);
  elsif p_kaynak='yonetim' then return public.yonetim_tutuklama_serbest(p_id, g);
  end if;
  raise exception 'Geçersiz gözaltı türü';
end $$;

revoke all on function public.gozalti_yetkili_liste() from public, anon;
revoke all on function public.gozalti_tahliye(text,bigint,text) from public, anon;
grant execute on function public.gozalti_yetkili_liste(), public.gozalti_tahliye(text,bigint,text) to authenticated;
