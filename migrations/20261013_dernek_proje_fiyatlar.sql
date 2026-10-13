
create or replace function public.dernek_proje_fiyatlar() returns jsonb language sql stable security definer set search_path = '' as $$
 select jsonb_build_object(
 'agac',greatest(100,round(250*coalesce((select endeks from oyun.ulke where id=1),1)/100)*100),
 'gida',greatest(100,round(650*coalesce((select endeks from oyun.ulke where id=1),1)/100)*100),
 'burs',greatest(100,round(2500*coalesce((select endeks from oyun.ulke where id=1),1)/100)*100),
 'hayvan',greatest(100,round(450*coalesce((select endeks from oyun.ulke where id=1),1)/100)*100),
 'temizlik',greatest(100,round(1200*coalesce((select endeks from oyun.ulke where id=1),1)/100)*100),
 'kultur',greatest(100,round(1800*coalesce((select endeks from oyun.ulke where id=1),1)/100)*100)
 )
$$;
revoke all on function public.dernek_proje_fiyatlar() from public,anon;
grant execute on function public.dernek_proje_fiyatlar() to authenticated;
