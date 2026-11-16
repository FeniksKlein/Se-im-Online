-- Oyun ici 3 uyeli bagimsiz mahkeme: 1. CB baskani, 2. Baro, 3. TBMM.
-- Adalet Bakani otomatik hakim olamaz; eski otomatik koltuk sadece mahkeme yonunden bosalir.
drop trigger if exists adalet_bakani_mahkeme_esitle on oyun.makamlar;
drop trigger if exists mahkeme_adalet_koru on oyun.mahkeme_uye;
alter table oyun.mahkeme_uye drop constraint if exists mahkeme_uye_kaynak_check;
alter table oyun.mahkeme_uye add constraint mahkeme_uye_kaynak_check check(kaynak in ('cb','baro','meclis'));
create table if not exists oyun.mahkeme_aday_riza (
 aday uuid primary key references oyun.profiller(id),aktif boolean not null default true,
 zaman timestamptz not null default now()
);
revoke all on oyun.mahkeme_aday_riza from public,anon,authenticated;
do $court$
declare v uuid;
begin
 select user_id into v from oyun.mahkeme_uye where sira=3 and kaynak='adalet';
 if v is not null then
  perform oyun.bildir(v,'Mahkeme reformu: Adalet Bakaninin otomatik yuksek mahkeme uyeligi kalkti. Bakanlik gorevin korunuyor.');
 end if;
 update oyun.mahkeme_uye set kaynak='baro',atayan=null where sira=2 and user_id is null;
 update oyun.mahkeme_uye set kaynak='meclis',user_id=null,atayan=null,bas=null,gorev_bit=null,bos_since=oyun.simdi() where sira=3 and kaynak='adalet';
 update oyun.mahkeme_uye set kaynak='meclis' where sira=3 and kaynak<>'meclis';
end $court$;
create or replace function oyun.adalet_bakani_mahkeme_esitle() returns void language plpgsql set search_path to '' as $f$
begin
 -- Otomatik yargi uyeligi sona erdi; mevcut bagimli fonksiyonlar icin bos uyumluluk islevi.
 return;
end $f$;
create or replace function public.mahkeme_aday_ol(p_acik boolean default true) returns jsonb language plpgsql security definer set search_path to '' as $f$
declare u uuid:=auth.uid(); eng text;
begin
 if u is null then raise exception 'Giris gerekli.';end if;
 if p_acik then
  eng:=oyun.yargic_uygunluk(u);
  if eng is not null then raise exception '%',eng;end if;
 end if;
 insert into oyun.mahkeme_aday_riza(aday,aktif,zaman) values(u,coalesce(p_acik,false),oyun.simdi())
 on conflict(aday) do update set aktif=excluded.aktif,zaman=excluded.zaman;
 return jsonb_build_object('tamam',true,'adayim',coalesce(p_acik,false));
end $f$;
revoke all on function public.mahkeme_aday_ol(boolean) from public,anon;
grant execute on function public.mahkeme_aday_ol(boolean) to authenticated;
create or replace function public.mahkeme_aday_listesi() returns jsonb language sql stable security definer set search_path to '' as $f$
 select coalesce(jsonb_agg(jsonb_build_object('kad',p.kad,'uygun',oyun.yargic_uygunluk(p.id) is null) order by p.kad),'[]'::jsonb)
 from oyun.mahkeme_aday_riza r join oyun.profiller p on p.id=r.aday where r.aktif and not p.yasakli;
$f$;
revoke all on function public.mahkeme_aday_listesi() from public,anon;
grant execute on function public.mahkeme_aday_listesi() to authenticated;
create or replace function public.baro_mahkeme_ata(p_kad text) returns jsonb language plpgsql security definer set search_path to '' as $f$
declare u uuid:=auth.uid(); v uuid; eng text;
begin
 if u is null or u is distinct from oyun.baro_baskan() or not oyun.baro_uyesi(u) then raise exception 'Yalniz baro baskani veya kanuni gecici baro yetkilisi atama yapabilir.';end if;
 select id into v from oyun.profiller where lower(kad)=lower(trim(p_kad)) and not yasakli;
 if v is null or not exists(select 1 from oyun.mahkeme_aday_riza where aday=v and aktif) then raise exception 'Kisi adaylik onayi vermemis veya bulunamadi.';end if;
 eng:=oyun.yargic_uygunluk(v);if eng is not null then raise exception '%',eng;end if;
 perform 1 from oyun.mahkeme_uye where sira=2 and user_id is null and kaynak='baro' for update;
 if not found then raise exception 'Baro uyeligine ait koltuk dolu.';end if;
 perform oyun.mahkeme_oturt(2,v,u,oyun.simdi());
 return jsonb_build_object('tamam',true,'kisi',oyun.kad(v),'sira',2);
end $f$;
revoke all on function public.baro_mahkeme_ata(text) from public,anon;
grant execute on function public.baro_mahkeme_ata(text) to authenticated;
create or replace function oyun.mahkeme_toplu_tick(t timestamp with time zone default oyun.simdi())
 returns void language plpgsql security definer set search_path to '' as $f$
begin
 -- Tarihe bagli gecici iki uyelik secimi yeni duzende kullanilmiyor.
 return;
end $f$;

CREATE OR REPLACE FUNCTION public.mahkeme_meclis_oy(p_sira integer, p_kad text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p oyun.profiller := oyun.profilim(); t timestamptz := oyun.simdi(); u oyun.profiller; engel text; n int;
begin
  if p_sira<>3 then raise exception 'TBMM yalnizca 3. mahkeme uyesini secebilir. 2. uye Baro yetkisindedir.'; end if;
  if not exists (select 1 from oyun.makamlar where user_id = p.id and tur = 'mv' and bit is null) then raise exception 'Yalnız milletvekilleri oy verebilir.'; end if;
  if exists (select 1 from oyun.mahkeme_uye where sira = p_sira and user_id is not null) then raise exception 'Bu koltuk dolu.'; end if;
  select * into u from oyun.profiller where lower(kad) = lower(trim(coalesce(p_kad, ''))) and not yasakli;
  if u.id is null then raise exception 'Aday bulunamadı.'; end if;
  if not exists(select 1 from oyun.mahkeme_aday_riza where aday=u.id and aktif) then raise exception 'Yargic adayi once kendi hesabindan adayligi kabul etmelidir.'; end if;
  engel := oyun.yargic_uygunluk(u.id);
  if engel is not null then raise exception '%', engel; end if;
  insert into oyun.mahkeme_meclis_oy(sira, vekil, aday, zaman) values (p_sira, p.id, u.id, t)
  on conflict (sira, vekil) do update set aday = excluded.aday, zaman = excluded.zaman;
  select count(*) into n from oyun.mahkeme_meclis_oy where sira = p_sira and aday = u.id
     and exists (select 1 from oyun.makamlar m where m.user_id = vekil and m.tur = 'mv' and m.bit is null);
  if n >= oyun.salt_cogunluk() then perform oyun.mahkeme_oturt(p_sira::smallint, u.id, null, t); end if;
  return jsonb_build_object('tamam', true, 'oy', n, 'gerekli', oyun.salt_cogunluk(), 'secildi', n >= oyun.salt_cogunluk());
end $function$;


CREATE OR REPLACE FUNCTION oyun.mahkeme_oturt(p_sira smallint, u uuid, p_atayan uuid, t timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  update oyun.mahkeme_uye set user_id = u, atayan = p_atayan, bas = t,
         gorev_bit = t + make_interval(days => (select gorev_gun from oyun.mahkeme_ayar)), bos_since = null where sira = p_sira;
  if p_sira = 1 then update oyun.adliye_makam set hakim = u, atayan = p_atayan, atama_at = t, degistirme_at = t where id = 1; end if;
  delete from oyun.mahkeme_meclis_oy where sira = p_sira;
  insert into oyun.adliye_atama_kayit(yapan, eski, yeni, gerekce, zaman)
  values (coalesce(p_atayan, u), null, u, case when p_sira = 1 then 'Cumhurbaşkanı ataması (mahkeme başkanı)' when p_sira=2 then 'Baro ataması' else 'TBMM seçimi' end, t);
  perform oyun.bildir(u, format('Yüksek Mahkeme %s. üyesi oldun. Görev süren %s gün; bu sürede partiye giremez, aday olamaz, başka makam alamazsın.',
                                 p_sira, (select gorev_gun from oyun.mahkeme_ayar)), t);
  perform oyun.olay('adliye', format('%s Yüksek Mahkeme %s. üyesi oldu (%s).', oyun.kad(u), p_sira,
                                      case when p_sira=1 then 'Cumhurbaşkanı ataması' when p_sira=2 then 'Baro ataması' else 'TBMM seçimi' end), null, null, t);
end $function$;


CREATE OR REPLACE FUNCTION oyun.mahkeme_tick()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare t timestamptz := oyun.simdi(); r record; dv oyun.adliye_davalar; n int := 0; a oyun.mahkeme_ayar; eng text; ab oyun.aym_basvuru;
begin
  if not pg_try_advisory_xact_lock(424245) then return 0; end if;
  select * into a from oyun.mahkeme_ayar;
  for r in select * from oyun.mahkeme_uye where user_id is not null and gorev_bit <= t loop
    perform oyun.mahkeme_indir(r.sira, null, 'Görev süresi doldu.', t); n := n + 1;
  end loop;
  for r in
    select u.sira, o.aday, count(*) c from oyun.mahkeme_uye u join oyun.mahkeme_meclis_oy o on o.sira = u.sira
     join oyun.makamlar m on m.user_id = o.vekil and m.tur = 'mv' and m.bit is null
     where false and u.user_id is null and u.kaynak = 'meclis' and u.bos_since <= t - interval '72 hours'
       AND NOT (EXISTS (SELECT 1 FROM oyun.secimler g WHERE g.tur='mv'
           AND (g.oy_bas AT TIME ZONE 'Europe/Istanbul')::date=date '2026-10-12')
         AND NOT EXISTS (SELECT 1 FROM oyun.mahkeme_toplu_secim s WHERE s.durum='bitti'))
     group by u.sira, o.aday having count(*) >= 3 order by u.sira, count(*) desc, min(o.zaman)
  loop
    if exists (select 1 from oyun.mahkeme_uye where sira = r.sira and user_id is null) and oyun.yargic_uygunluk(r.aday) is null then
      perform oyun.mahkeme_oturt(r.sira, r.aday, null, t); n := n + 1;
    end if;
  end loop;
  -- Dokunulmazlık: görevdeki Cumhurbaşkanı (ve yasa yürürlükteyse milletvekili) hakkındaki açık ceza davaları düşer
  for r in select d.id, d.davali, d.tur from oyun.adliye_davalar d where d.durum = 'acik' and d.davali is not null loop
    eng := oyun.dokunulmazlik_engel(r.davali, r.tur);
    if eng is not null then perform oyun.adliye_dokunulmazlik_dusur(r.id, eng, t); n := n + 1; end if;
  end loop;
  -- Karar süresi doldu ya da heyetin tamamı oy verdi (son oydan 2 saat geçti) ama çoğunluk yok:
  -- hiç üye yoksa süre işlemez; oy vermeyen varsa bir kez 24 saat ek süre; sonra CMK m.229/3 ile karar
  for dv in select * from oyun.adliye_davalar d where d.durum = 'acik' loop
    if (dv.karar_son is not null and dv.karar_son <= t)
       or (cardinality(oyun.dava_heyeti(dv)) > 0
           and (select count(*) from oyun.adliye_karar_oy o where o.dava_id = dv.id and o.uye = any(oyun.dava_heyeti(dv))) >= cardinality(oyun.dava_heyeti(dv))
           and (select max(o.zaman) from oyun.adliye_karar_oy o where o.dava_id = dv.id) <= t - interval '2 hours') then
      if cardinality(oyun.mahkeme_uyeleri()) = 0 then
        update oyun.adliye_davalar set karar_son = t + make_interval(hours => a.karar_saat) where id = dv.id;
      else
        perform oyun.adliye_sure_doldu(dv.id, t); n := n + 1;
      end if;
    end if;
  end loop;
  -- Karar süresinin son 12 saati: oy kullanmayan heyet üyelerine hatırlatma
  for dv in select * from oyun.adliye_davalar d where d.durum = 'acik' and not d.karar_hatirlatildi and d.karar_son is not null
              and d.karar_son - interval '12 hours' <= t and (d.savunma_geldi or d.savunma_son <= t) loop
    perform oyun.bildir(u, format('Yüksek Mahkeme hatırlatması: Adliye #%s için karar süresinin dolmasına 12 saatten az kaldı; gerekçeli oyunu kullan.', dv.id), t)
      from unnest(oyun.dava_heyeti(dv)) u where not exists (select 1 from oyun.adliye_karar_oy o where o.dava_id = dv.id and o.uye = u);
    update oyun.adliye_davalar set karar_hatirlatildi = true where id = dv.id;
  end loop;
  -- İstinaf jürisi süresi (çoğunluk yoksa bir kez yedeklerle ek tur)
  for r in select dava_id from oyun.adliye_istinaf where durum = 'acik' and bit <= t loop
    perform oyun.adliye_istinaf_sonuc(r.dava_id, t); n := n + 1;
  end loop;
  -- İstinaf oylamasının son 8 saati: oy kullanmayan jüri üyelerine hatırlatma
  for r in select dava_id from oyun.adliye_istinaf where durum = 'acik' and not hatirlatildi and bit - interval '8 hours' <= t loop
    perform oyun.bildir(j.user_id, format('Hatırlatma: Adliye #%s istinaf oylamasının bitmesine 8 saatten az kaldı. Kararı onayla ya da boz.', r.dava_id), t)
      from oyun.adliye_juri j where j.dava_id = r.dava_id and j.oy is null;
    update oyun.adliye_istinaf set hatirlatildi = true where dava_id = r.dava_id;
  end loop;
  -- Karar verilmiş ama istinaf süresi tanımsız kalmış dosya: istinaf süresi şimdi başlar, taraflara bildirilir
  for dv in select * from oyun.adliye_davalar d where d.durum = 'karar' and not coalesce(d.kesin, false) and d.istinaf_son is null
              and not exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id) loop
    update oyun.adliye_davalar set istinaf_son = t + make_interval(hours => a.istinaf_saat) where id = dv.id;
    perform oyun.bildir(x.id, format('Adliye #%s kararı: %s. İstinaf süresi şimdi başladı; %s saat içinde itiraz edilmezse karar kesinleşir.', dv.id, dv.karar, a.istinaf_saat), t)
      from (select dv.davaci id union select dv.davali where dv.davali is not null) x;
    perform oyun.olay('adliye', format('Adliye #%s kararı için %s saatlik istinaf süresi başladı.', dv.id, a.istinaf_saat), null, null, t);
    n := n + 1;
  end loop;
  for r in select d.id from oyun.adliye_davalar d where d.durum = 'karar' and not coalesce(d.kesin, false)
              and ((d.istinaf_son <= t and not exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id))
                   or exists (select 1 from oyun.adliye_istinaf i where i.dava_id = d.id and i.durum <> 'acik')) loop
    perform oyun.adliye_kesinlestir(r.id, t); n := n + 1;
  end loop;
  for r in select id from oyun.mahkeme_azil where durum = 'acik' and bit <= t loop perform oyun.mahkeme_azil_say(r.id, t); end loop;
  -- Anayasa Mahkemesi: son 12 saatte hatırlatma; süre dolunca ek süre ya da verilen oylarla karar
  for ab in select * from oyun.aym_basvuru where durum = 'acik' and not hatirlatildi and karar_son - interval '12 hours' <= t loop
    perform oyun.bildir(u, format('Anayasa Mahkemesi hatırlatması: "%s" kanunu başvurusunda karar süresinin dolmasına 12 saatten az kaldı; gerekçeli oyunu kullan.',
        (select k.baslik from oyun.kanunlar k where k.id = ab.kanun_id)), t)
      from unnest(oyun.mahkeme_uyeleri()) u where not exists (select 1 from oyun.aym_oy o where o.basvuru_id = ab.id and o.uye = u);
    update oyun.aym_basvuru set hatirlatildi = true where id = ab.id;
  end loop;
  for r in select id from oyun.aym_basvuru where durum = 'acik' and karar_son <= t loop
    perform oyun.aym_sure_doldu(r.id, t); n := n + 1;
  end loop;
  return n;
end $function$;

