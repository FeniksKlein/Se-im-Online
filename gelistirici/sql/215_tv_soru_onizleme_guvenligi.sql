-- TV soru bankası: reji ön izlemesinde her sorunun şık sırası rastgele, cevap anahtarı gösterilmez.
create or replace function public.tv_soru_listesi(p_program bigint,p_kategori text default null,p_zorluk integer default null)
returns jsonb language plpgsql security definer set search_path = '' as $f$
declare p oyun.profiller:=oyun.profilim(); pr oyun.tv_program; sonuc jsonb;
begin
 select * into pr from oyun.tv_program where id=p_program;
 if pr.id is null or pr.tur<>'yarisma' then raise exception 'Bilgi yarışması bulunamadı.'; end if;
 if not oyun.tv_yonetici_mi(pr,p.id) then raise exception 'Soru havuzunu yalnız sunucu veya kanal sahibi açabilir.'; end if;
 if pr.durum not in ('planli','canli') then raise exception 'Program tamamlandı.'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'id',x.id,'kategori',x.kategori,'zorluk',x.zorluk,'soru',x.soru,
   'secenekler',(select jsonb_agg(k.secenek order by k.karisik) from
        (select value as secenek, random() as karisik
         from jsonb_array_elements_text(x.secenekler)) k))), '[]'::jsonb)
 into sonuc from (
  select q.id,q.kategori,q.zorluk,q.soru,q.secenekler
    from oyun.tv_soru_havuzu q where q.aktif
    and (p_kategori is null or p_kategori='' or q.kategori=p_kategori)
    and (p_zorluk is null or q.zorluk=p_zorluk)
    and not exists(select 1 from oyun.tv_anket a where a.program_id=p_program and a.havuz_soru_id=q.id)
    order by random() limit 30
 ) x;
 return jsonb_build_object('sorular',sonuc,'toplam',(select count(*) from oyun.tv_soru_havuzu where aktif));
end $f$;
revoke all on function public.tv_soru_listesi(bigint,text,integer) from public,anon;
grant execute on function public.tv_soru_listesi(bigint,text,integer) to authenticated,service_role;