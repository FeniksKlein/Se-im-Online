
-- Kutunu Seç: iki uygun başvuru yeterli, rastgele veya yönetici tarafından başvuranlar arasından manuel seçilebilir.
-- Kanal sahibi/sunucu kendini seçemez, ödül geçmişi şartları korunur.
create or replace function public.tv_kutu_yarismaci_sec(p_program bigint, p_kad text default null)
returns jsonb language plpgsql security definer set search_path to '' as $fn$
declare
 v_profile oyun.profiller := oyun.profilim();
 v_program oyun.tv_program;
 v_game oyun.tv_kutu_oyun;
 v_channel oyun.tv_kanal;
 v_now timestamptz := oyun.simdi();
 v_choice uuid;
 v_valid integer := 0;
 v_method text;
begin
 perform oyun.tv_program_guncelle(p_program);
 select * into v_game from oyun.tv_kutu_oyun where program_id=p_program for update;
 if v_game.program_id is null then raise exception 'Kutunu Seç yarışması bulunamadı.'; end if;
 select * into v_program from oyun.tv_program where id=p_program;
 select * into v_channel from oyun.tv_kanal where id=v_game.kanal_id;
 if v_program.tur<>'kutunu_sec' or v_game.durum<>'basvuru'
    or v_program.durum<>'canli' or v_program.bit<=v_now
 then raise exception 'Yarışmacı yalnız başvurular açıkken ve canlı yayın sürerken seçilebilir.'; end if;
 if v_profile.id<>v_program.sunucu and v_profile.id<>v_channel.sahip
 then raise exception 'Yarışmacıyı sadece bu programın sunucusu veya kanal sahibi seçebilir.'; end if;
 select count(*) into v_valid
 from oyun.tv_kutu_basvuru b
 where b.program_id=p_program and b.user_id<>v_program.sunucu and b.user_id<>v_program.olusturan
   and oyun.tv_kutu_uygun(v_game.kanal_id,b.user_id);
 if v_valid<2 then raise exception 'Yarışma için en az 2 uygun başvuru gerekli. Şu anda % uygun başvuru var.',v_valid; end if;

 if p_kad is not null and btrim(p_kad)<>'' then
   select b.user_id into v_choice from oyun.tv_kutu_basvuru b
   join oyun.profiller p on p.id=b.user_id
   where b.program_id=p_program and p.kad=btrim(p_kad)
     and b.user_id<>v_program.sunucu and b.user_id<>v_program.olusturan
     and oyun.tv_kutu_uygun(v_game.kanal_id,b.user_id)
   limit 1;
   if v_choice is null then raise exception 'Seçilen oyuncu başvurmamış veya ödül şartlarına uygun değil.'; end if;
   v_method:='manuel_secim';
 else
   select b.user_id into v_choice from oyun.tv_kutu_basvuru b
   where b.program_id=p_program and b.user_id<>v_program.sunucu and b.user_id<>v_program.olusturan
     and oyun.tv_kutu_uygun(v_game.kanal_id,b.user_id)
   order by pg_catalog.gen_random_uuid() limit 1;
   if v_choice is null then raise exception 'Uygun yarışmacı bulunamadı.'; end if;
   v_method:='rastgele_secim';
 end if;
 update oyun.tv_kutu_oyun set durum='secim',yarismaci=v_choice,baslangic=v_now,son_hamle=v_now
  where program_id=p_program and durum='basvuru';
 if not found then raise exception 'Başka bir işlem yarışmacıyı zaten seçmiş.'; end if;
 insert into oyun.tv_kutu_hareket(program_id,user_id,islem,zaman)
  values(p_program,v_choice,v_method,v_now);
 insert into oyun.tv_mesaj(program_id,user_id,rol,metin,zaman)
  values(p_program,v_choice,'sistem',
   format('Kutunu Seç yarışmacısı %s belirlendi: %s. Şimdi kendi kutusunu seçebilir!',
   case when v_method='manuel_secim' then 'sunucu tarafından' else 'rastgele' end,oyun.kad(v_choice)),v_now);
 perform oyun.bildir(v_choice,format('Tebrikler! %s kanalındaki Kutunu Seç yarışmasına sen seçildin. TV stüdyosuna gir ve kutunu seç.',v_channel.ad),v_now);
 perform oyun.tv_sinyal(p_program);
 return public.tv_kutu_durum(p_program);
end $fn$;
revoke all on function public.tv_kutu_yarismaci_sec(bigint,text) from public,anon;
grant execute on function public.tv_kutu_yarismaci_sec(bigint,text) to authenticated,service_role;

-- Eski istemcideki rastgele seçim düğmesi çalışmaya devam etsin.
create or replace function public.tv_kutu_baslat(p_program bigint)
returns jsonb language sql security definer set search_path to '' as $fn$
 select public.tv_kutu_yarismaci_sec(p_program,null::text)
$fn$;
revoke all on function public.tv_kutu_baslat(bigint) from public,anon;
grant execute on function public.tv_kutu_baslat(bigint) to authenticated,service_role;

CREATE OR REPLACE FUNCTION public.tv_kutu_durum(p_program bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller:=oyun.profilim(); pr oyun.tv_program; g oyun.tv_kutu_oyun; k oyun.tv_kanal; t timestamptz:=oyun.simdi();
begin
 perform oyun.tv_program_guncelle(p_program);
 select * into g from oyun.tv_kutu_oyun where program_id=p_program;
 select * into pr from oyun.tv_program where id=p_program;
 if pr.id is null or pr.tur<>'kutunu_sec' or g.program_id is null then raise exception 'Kutunu Seç programı bulunamadı.'; end if;
 select * into k from oyun.tv_kanal where id=g.kanal_id;
 return jsonb_build_object(
 'program',p_program,'kanal',k.ad,'program_durum',pr.durum,'durum',g.durum,'simdi',t,
 'bas',pr.bas,'bit',pr.bit,'buyuk_odul',g.teminat,
 'basvuru_sayisi',(select count(*) from oyun.tv_kutu_basvuru b where b.program_id=p_program),
 'uygun_basvuru',(select count(*) from oyun.tv_kutu_basvuru bx where bx.program_id=p_program
    and bx.user_id<>pr.sunucu and bx.user_id<>pr.olusturan and oyun.tv_kutu_uygun(g.kanal_id,bx.user_id)),
 'minimum_basvuru',2,
 'secim_yontemi',(select max(h.islem) from oyun.tv_kutu_hareket h where h.program_id=p_program
    and h.islem in ('rastgele_secim','manuel_secim')) ,
 'basvurdum',exists(select 1 from oyun.tv_kutu_basvuru b where b.program_id=p_program and b.user_id=p.id),
 'uygun',oyun.tv_kutu_uygun(g.kanal_id,p.id) and p.id<>pr.sunucu and p.id<>pr.olusturan,
 'yonetici',p.id=k.sahip or p.id=pr.sunucu,'benim_siram',p.id=g.yarismaci,
 'yarismaci',case when g.yarismaci is not null then oyun.kad(g.yarismaci) end,
 'secilen',g.secilen,'acilan_sayi',coalesce(array_length(g.acilan,1),0),
 'teklif',g.teklif,'teklif_sayisi',g.teklif_sayisi,
 'asil_odul',g.asil_odul,'odenen',g.odenen,'iade',g.iade,
 'secilebilirler',(case when p.id=k.sahip or p.id=pr.sunucu then
  (select coalesce(jsonb_agg(s.kad order by s.zaman),'[]'::jsonb) from
    (select pp.kad,b.zaman from oyun.tv_kutu_basvuru b
    join oyun.profiller pp on pp.id=b.user_id
    where b.program_id=p_program and b.user_id<>pr.sunucu and b.user_id<>pr.olusturan
      and oyun.tv_kutu_uygun(g.kanal_id,b.user_id) order by b.zaman limit 100) s)
  else '[]'::jsonb end),
 'basvurular',(select coalesce(jsonb_agg(s.kad order by s.zaman),'[]'::jsonb) from
     (select pp.kad,b.zaman from oyun.tv_kutu_basvuru b
       join oyun.profiller pp on pp.id=b.user_id where b.program_id=p_program order by b.zaman limit 20) s),
 'kutular',(select jsonb_agg(jsonb_build_object(
     'no',i,'acik',i=any(g.acilan),'benim',i=g.secilen,
     'tutar',case when i=any(g.acilan) or g.durum='bitti' then g.degerler[i] end)
    order by i) from generate_series(1,16) i),
 'kalan_oduller',(select jsonb_agg(g.degerler[i] order by g.degerler[i] desc)
    from generate_series(1,16) i where not i=any(g.acilan))
 );
end $function$

