-- Mevcut sirketleri ve oyuncu hesaplarini degistirmeden tek islemde sirket kurup faaliyete bagla.
create or replace function public.sirket_kur_aktif(
 p_ad text, p_sektor text, p_sermaye numeric, p_urun text default null
) returns jsonb
language plpgsql security invoker set search_path to ''
as $$
declare v_kur jsonb; v_sirket bigint; v_grup text; v_tur text;
begin
 if auth.uid() is null then raise exception 'Giris yapmalisin.'; end if;
 if p_sektor not in ('tarim','sanayi','teknoloji','ticaret','insaat','medya','banka')
 then raise exception 'Bu tur icin ilgili kurulus ekranini kullan.'; end if;
 v_kur:=public.sirket_kur(p_ad,p_sektor,p_sermaye);
 v_sirket:=(v_kur->>'id')::bigint;
 if p_sektor in ('tarim','sanayi','teknoloji') then
  v_grup:=case when p_sektor='tarim' then 'gida'
                when p_sektor='teknoloji' then 'teknoloji'
                else coalesce(nullif(p_urun,''),'malzeme') end;
  if p_sektor='sanayi' and v_grup not in ('gida','teknoloji','malzeme')
   then raise exception 'Gecersiz uretim grubu.'; end if;
  perform public.eko_ticaret_islem('bagla',jsonb_build_object('sirket',v_sirket,'urun',v_grup));
  v_tur:='fabrika';
 elsif p_sektor='ticaret' then
  perform public.eko_ticaret_islem('bagla',jsonb_build_object('sirket',v_sirket));
  v_tur:='magaza';
 else
  v_tur:=p_sektor;
 end if;
 return jsonb_build_object('id',v_sirket,'tur',v_tur,'grup',v_grup,
 'mesaj','Sirket kuruldu; uygun sektor faaliyeti ayni islemde baslatildi.');
end $$;
revoke all on function public.sirket_kur_aktif(text,text,numeric,text) from public, anon;
grant execute on function public.sirket_kur_aktif(text,text,numeric,text) to authenticated;